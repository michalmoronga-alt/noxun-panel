# frozen_string_literal: true
# H14 · T0b (R0.3) — CHARAKTERIZACIA serverovej strany sekcii Studia pred
# registrom `NXStudioSections` (package `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H14.md`).
#
# H14 meni LEN klienta (zoznamy sekcii v JS); Ruby sa nemeni — a tento test to
# dokazuje odtlackom zachytenym na NEZMENENOM kode (1. commit H14a):
#   1. `StudioDialog::SECTIONS` (whitelist a poradie) a jednorazovy deep-link
#      `consume_pending_section` (zname id, neznáme, prazdne, nil),
#   2. headless `push_state` nad malou syntetickou zakazkou so stubmi vstupov
#      (vzor `NxNp3Push`): PORADIE KLUCOV `NX.setStudio` a BAJTY JSON bez
#      `version` a `gen` (cas zmrazeny — rozpocet pocita vek cien).
# Fixtura `tests/fixtures/h14_golden/push_keys.json` sa NEREGENERUJE (generator
# `tests/fixtures/h14_golden/generate.rb` len na nezmenenom kode) — rozdiel je nalez.
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'
require 'tmpdir'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') unless defined?(Noxun::Engine::StudioDialog)
end

module NxH14Push
  E = Noxun::Engine
  GOLDEN = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h14_golden', 'push_keys.json')
  NOW = Time.utc(2026, 10, 1, 12, 0, 0)

  SHEETS = {
    'H18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1181',
               'manufacturer' => 'Egger', 'grain' => 'length', 'color' => [124, 90, 58], 'price_per_m2' => 36.5 },
    'W18' => { 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'decor' => 'W1000',
               'grain' => 'none', 'price_per_m2' => 26.9 }
  }.freeze
  EDGES = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.freeze

  class FakeModel < NxTest::FakeEntity
    def title
      'GOLDEN'
    end
  end

  module_function

  def collected
    recs = [
      ['Bok', 'side', 720.0, 560.0, 'H18', 'CAB-001'],
      ['Polica', 'shelf', 560.0, 530.0, 'W18', 'CAB-001'],
      ['Dno', 'bottom', 564.0, 560.0, 'H18', 'CAB-002']
    ].each_with_index.map do |(name, role, l, w, mid, owner), i|
      { 'name' => name, 'part_key' => "cabinet/#{role}:#{i}", 'owner_id' => owner, 'pid' => 100 + i, 'role' => role,
        'length' => l, 'width' => w, 'thickness' => 18.0, 'quantity' => 1, 'material_id' => mid,
        'grain_direction' => 'none', 'edges' => EDGES.dup }
    end
    { records: recs, hardware: [], hardware_overrides: [], cabinet_sets: {}, cabinet_set_conflicts: {},
      placements: [], warnings: [], identities: [], hardware_issues: [], cut_issues: [] }
  end

  def with_stubs(mod, map)
    saved = {}
    map.each do |name, fn|
      saved[name] = mod.method(name)
      mod.define_singleton_method(name, &fn)
    end
    yield
  ensure
    saved.each { |name, m| mod.define_singleton_method(name, m) }
  end

  def with_checks(mods, &blk)
    return blk.call if mods.empty?

    with_stubs(mods.first, ui_state: ->(*_a) { nil }) { with_checks(mods.drop(1), &blk) }
  end

  # Izolovane nastavenia dodavatela (vzor NP-3) — nikdy zivy %APPDATA%.
  def with_sandbox
    prev = E::Materials.test_dir_override
    dir = Dir.mktmpdir('nx-h14-')
    E::Materials.test_dir_override = dir
    E::JsonFileStore.invalidate
    yield
  ensure
    E::Materials.test_dir_override = prev
    E::JsonFileStore.invalidate
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  # -> payload `NX.setStudio` (Hash v poradi klucov, ako odisiel do okna).
  def push
    sd = E::StudioDialog
    pc = E::ProductionCore
    col = collected
    sent = nil
    model = FakeModel.new
    sk = Module.new
    sk.define_singleton_method(:active_model) { model }
    Object.const_set(:Sketchup, sk)
    stubs_sd = { js: ->(s) { sent = s; true }, mat_payload: ->(*_a) { nil }, hw_payload: ->(*_a) { nil },
                 appl_payload: ->(*_a) { nil }, rules_payload: ->(*_a) { nil }, tpl_payload: ->(*_a) { nil },
                 settings_payload: ->(*_a) { nil } }
    stubs_pc = { fresh_collect: ->(*_a) { col }, sheets_map: ->(*_a) { SHEETS },
                 edges_map: ->(*_a) { {} }, hardware_expansion: ->(*_a) { { 'rows' => [], 'unmapped' => [] } },
                 hardware_catalog_items: ->(*_a) { nil }, model_guid: ->(*_a) { 'G1' } }
    # H7a: nastavenia exportu ziju v `ExportSettings` (payload `vepo` bez zmeny).
    stubs_es = { project_name: ->(*_a) { 'GOLDEN' }, default_project_name: ->(*_a) { 'GOLDEN' },
                 merge_18_36: ->(*_a) { true } }
    checks = [E.const_defined?(:EdgeCheck) ? E::EdgeCheck : nil, E.const_defined?(:GrainCheck) ? E::GrainCheck : nil,
              E.const_defined?(:DirectionCheck) ? E::DirectionCheck : nil].compact
    with_sandbox do
      with_stubs(Time, now: -> { NOW }) do
        with_stubs(sd, stubs_sd) do
          with_stubs(pc, stubs_pc) do
            with_stubs(E::ExportSettings, stubs_es) do
              with_checks(checks) { sd.send(:push_state) }
            end
          end
        end
      end
    end
    JSON.parse(sent.to_s[/\ANX\.setStudio\((.*)\)\z/m, 1].to_s)
  ensure
    Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup, false)
  end

  # Jednorazovy deep-link: co z `@pending_section` spotrebuje najblizsi push.
  def consume_matrix
    sd = E::StudioDialog
    prev = sd.instance_variable_get(:@pending_section)
    inputs = sd::SECTIONS + ['xyz', '', 'BOM', ' bom', nil, :bom]
    inputs.each_with_object({}) do |v, out|
      sd.instance_variable_set(:@pending_section, v)
      first = sd.send(:consume_pending_section)
      second = sd.send(:consume_pending_section)
      out[v.inspect] = [first, second]
    end
  ensure
    sd.instance_variable_set(:@pending_section, prev)
  end

  # H7b (R-B11): `vepo` dostal na koniec nove kluce (zdroj nazvu, meno suboru,
  # mena exportov, cakajuci nazov) — fixtura sa NEREGENERUJE: porovnaju sa
  # 3 povodne kluce v povodnom poradi, nove pripina `test_h7b_nazov_zakazky.rb`.
  VEPO_T0_KEYS = %w[project default_project merge_18_36].freeze

  def snapshot
    data = push
    payload = data.reject { |k, _v| %w[version gen].include?(k) }
    if payload['vepo'].is_a?(Hash)
      payload = payload.merge('vepo' => payload['vepo'].select { |k, _v| VEPO_T0_KEYS.include?(k) })
    end
    { 'sections' => E::StudioDialog::SECTIONS, 'consume' => consume_matrix, 'keys' => data.keys,
      'payload' => payload }
  end

  def golden
    JSON.parse(File.read(GOLDEN, encoding: 'UTF-8'))
  end
end

NxTest.test('H14 T0b: StudioDialog::SECTIONS a jednorazovy deep-link sa nezmenili') do
  NxTest.skip!('headless: stub Sketchup') unless NxTest.headless?
  g = NxH14Push.golden
  NxTest.assert_equal(g['sections'], Noxun::Engine::StudioDialog::SECTIONS, 'whitelist a poradie sekcii')
  NxTest.assert(Noxun::Engine::StudioDialog::SECTIONS.frozen?, 'whitelist je zmrazeny')
  NxTest.assert_equal(g['consume'], NxH14Push.consume_matrix, 'consume_pending_section: zname id raz, ostatne nil')
end

NxTest.test('H14 T0b: headless push_state — poradie klucov NX.setStudio a bajty JSON bez version/gen') do
  NxTest.skip!('headless: stub Sketchup') unless NxTest.headless?
  g = NxH14Push.golden
  snap = NxH14Push.snapshot
  NxTest.assert_equal(g['keys'], snap['keys'], 'poradie klucov payloadu')
  NxTest.assert_equal(JSON.generate(g['payload']), JSON.generate(snap['payload']), 'bajty JSON payloadu (bez version, gen)')
end
