# frozen_string_literal: true
require_relative 'test_mr1b2_build_appearance'

# Skutocny dedup/Ids/Store/preflight nad doubles hranice modelovej operacie.
# Transparentny SketchUp Undo dokazuje osobitne su_runner, nie tento double.
module NxMRB2Dedup
  E = Noxun::Engine
  CB = E::CabinetBuilder
  module_function

  def isolated
    NxMRB2.isolated do |state|
      model = state[:model]
      source, bad, good = 3.times.map do |index|
        cabinet = NxMRB2Copy::Cabinet.new(model)
        cabinet.define_singleton_method(:entityID) { index + 1 }
        E::Store.write(cabinet, id: 'CAB-001')
        E::Store.write_config(cabinet, E::Store.config(cabinet).merge('part_key_schema' => E::PartKeys::SCHEMA))
        cabinet
      end
      material = NxMRB2.native(model)
      contexts = [bad, good].to_h { |cab| [cab, NxMRB2.context(cab, [NxMRB2.record(material)])] }
      calls = { starts: [], commits: 0, aborts: 0, captures: [], rebuilt: [], errors: [] }
      model.define_singleton_method(:definitions) { [NxTest::FakeDefinition.new(entities)] }
      operation_snapshot = nil
      model.define_singleton_method(:start_operation) do |*args|
        calls[:starts] << args
        operation_snapshot = entities.to_h { |cab| [cab, JSON.parse(JSON.generate(cab.dicts))] }
        true
      end
      model.define_singleton_method(:commit_operation) do
        calls[:commits] += 1
        operation_snapshot = nil
        true
      end
      model.define_singleton_method(:abort_operation) do
        calls[:aborts] += 1
        operation_snapshot.each { |cab, attrs| cab.dicts.replace(attrs) }
        operation_snapshot = nil
        true
      end
      capture = lambda do |_model, owner, target_id: nil|
        calls[:captures] << [owner, !operation_snapshot.nil?]
        raise E::BuildAppearance::CaptureError, 'test invalid source' if calls[:capture_error] == owner
        ctx = contexts.fetch(owner)
        target_id ? ctx.merge(target_id: target_id) : ctx
      end
      rebuild = lambda do |_model, owner, _cfg, appearance:|
        calls[:rebuilt] << owner
        NxTest.assert(!operation_snapshot.nil?, 'prepis ID aj rebuild musia byt v jednej operacii')
        NxTest.assert_equal('CAB-001', appearance[:owner_id], 'povodna identita ostava dokazom zdroja')
        NxTest.assert_equal(E::Store.get(owner, 'cabinet_id'), appearance[:target_id])
        E::BuildAppearance.validate_copy_source!(appearance, model: model, owner: owner)
        E::Store.write(owner, rebuilt: true)
        raise E::NativeAppearance::LoadError, 'test failure after write' if calls[:write_error] == owner
      end
      before = [source, bad].to_h { |cab| [cab, JSON.generate(cab.dicts)] }
      NxMRB2Copy.stub(E::BuildAppearance, :capture_cabinet, capture) do
        NxMRB2Copy.stub(CB, :normalize, ->(params) { params }) do
          NxMRB2Copy.stub(CB, :rebuild_in_operation, rebuild) do
            NxMRB2Copy.stub(E, :log_error, ->(*error) { calls[:errors] << error }) do
              yield model, source, bad, good, contexts, calls
              before.each { |cab, attrs| NxTest.assert_equal(attrs, JSON.generate(cab.dicts), 'povodny/odmietnuty korpus bez zmeny') }
              NxTest.assert_equal(0, model.materials.load_calls, 'preflight nesmie nacitat .skm')
              NxTest.assert_equal(1, model.materials.length, 'preflight nesmie vytvorit material')
            end
          end
        end
      end
    end
  end

  def dedup(model, bad, good)
    CB.dedup_copies(model, fresh_ids: [bad.entityID, good.entityID])
  end

  def assert_good(model, source, bad, good, calls)
    NxTest.assert_equal('CAB-001', E::Store.get(source, 'cabinet_id'))
    NxTest.assert_equal('CAB-001', E::Store.get(bad, 'cabinet_id'))
    NxTest.assert_equal('CAB-002', E::Store.get(good, 'cabinet_id'))
    NxTest.assert_equal([good], calls[:rebuilt])
    NxTest.assert_equal(1, calls[:starts].length, 'odmietnuta kopia neotvara operaciu')
    NxTest.assert_equal(true, calls[:starts].first[3], 'cerstva dobra kopia zachova transparentny paste krok')
    NxTest.assert_equal(1, calls[:commits])
    NxTest.assert_equal(0, calls[:aborts], 'znamy konflikt nesmie abortovat spolocny paste')
    NxTest.assert(calls[:captures].all? { |_cab, in_operation| !in_operation })
    NxTest.assert_equal([bad], E::Ids.duplicate_cabinets(model), 'zostava iba priznana konfliktna duplicita')
    NxTest.assert_equal(1, calls[:errors].length, "odmietnutie je zalogovane: #{calls[:errors].inspect}")
  end
end

NxTest.test('MR-B2 dedup: chyba capture prvej kopie nevyhladuje dalsiu cerstvu kopiu') do
  NxMRB2Dedup.isolated do |model, source, bad, good, _contexts, calls|
    calls[:capture_error] = bad
    NxTest.assert_equal([good], NxMRB2Dedup.dedup(model, bad, good))
    NxMRB2Dedup.assert_good(model, source, bad, good, calls)
  end
end

NxTest.test('MR-B2 dedup: unknown kanal prvej kopie sa odmietne pred transparentnou operaciou') do
  NxMRB2Dedup.isolated do |model, source, bad, good, contexts, calls|
    contexts[bad][:parts].values.first.first[:sheet][:state] = :unknown
    NxTest.assert_equal([good], NxMRB2Dedup.dedup(model, bad, good))
    NxMRB2Dedup.assert_good(model, source, bad, good, calls)
  end
end

NxTest.test('MR-B2 dedup: protected duplicitny part_key neprejde preflightom') do
  NxMRB2Dedup.isolated do |model, source, bad, good, contexts, calls|
    records = contexts[bad][:parts].values.first
    records << records.first.merge(role: 'iny_dielec')
    NxTest.assert_equal([good], NxMRB2Dedup.dedup(model, bad, good))
    NxMRB2Dedup.assert_good(model, source, bad, good, calls)
  end
end

NxTest.test('MR-B2 dedup: protected ABS cudzieho scope odmietne iba dotknutu kopiu') do
  NxMRB2Dedup.isolated do |model, source, bad, good, contexts, calls|
    # Ten isty platny handle, ale ABS snapshot odkazuje na iny katalogovy scope.
    rec = contexts[bad][:parts].values.first.first
    rec[:edges]['L1'] = { abs_id: 'FOREIGN-ABS', channel: rec[:sheet] }
    foreign = NxMRB2.row('FOREIGN-ABS', :edge, nil, ['GRP-OTHER', 'ST9'])
    original_edge = NxMRB2::M.method(:edge)
    NxMRB2Copy.stub(NxMRB2::M, :edge, ->(id) { id == 'FOREIGN-ABS' ? foreign : original_edge.call(id) }) do
      NxTest.assert_equal([good], NxMRB2Dedup.dedup(model, bad, good))
      NxMRB2Dedup.assert_good(model, source, bad, good, calls)
    end
  end
end

NxTest.test('MR-B2 dedup: necakana chyba po zapise ID abortuje a nepokracuje dalsou kopiou') do
  NxMRB2Dedup.isolated do |model, _source, bad, good, _contexts, calls|
    calls[:write_error] = bad
    before_good = JSON.generate(good.dicts)
    NxTest.assert_equal([], NxMRB2Dedup::CB.dedup_copies(model))
    NxTest.assert_equal([bad], calls[:rebuilt])
    NxTest.assert_equal(1, calls[:aborts])
    NxTest.assert_equal(0, calls[:commits])
    NxTest.assert_equal(before_good, JSON.generate(good.dicts))
    NxTest.assert_equal(1, calls[:errors].length, calls[:errors].inspect)
  end
end
