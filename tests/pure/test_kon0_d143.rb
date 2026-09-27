# frozen_string_literal: true
# KON-0 · D-143 — CHRBAT V DRAZKE DO NAREZU V PLNOM ROZMERE (blok 7 KONŠTRUKCIA).
#
# CO BOLO ZLE: chrbat v drazke (predvolba hornej skrinky) isiel do narezu, VEPO
# aj ceny v rozmere MODELU — horna 600 x 720 dala chrbat 564 x 684, hoci v dielni
# sa chrbat v drazke reze vacsi (zrezat sa da, prilepit nie — Michal 26.9.2026).
#
# CO PLATI TERAZ:
#   * deskriptor aj snapshot chrbta v drazke nesu `cut_size` = plny rozmer
#     skrinky w x (h - s) v osiach `prod`; `box` = `prod` = geometria sa NEMENIA,
#   * kazdy chrbat nesie znacku povodu `back_mode` (aj samostatny kus vie, odkial je),
#   * vsetky vyrobne vystupy citaju `cut_size` cez JEDINE miesto (`Bom.record` /
#     `Bom.cut_dims`) — kusovnik, format platne, VEPO, plocha rozpoctu, plocha
#     skrinky v Inspectore, texty „výrobne" karty dielca; hmotnost ostava z geometrie,
#   * JEDNA vyrobna brana D-143 (`Bom::CUT_BLOCKERS`): poskodeny `cut_size`,
#     olepeny chrbat v drazke, neuplny snapshot, zastarana skrinka -> RED
#     v Kontrole A tvrdy stop VSETKYCH STYROCH exportov pred vyberom suboru,
#   * samostatny stary chrbat bez znacky = ORANGE, export ide (Michal 27.9.2026),
#   * `CONFIG_SCHEMA` 19, aktivacna schema D-143 = 19.
#
# MUTACIE, ktore tato sada chyta (overene rucne pri davke, PR popis):
#   M1 citatel ignoruje `cut_size` (`Bom.record` vrati geometriu)
#      -> „retaz snapshot -> kusovnik -> format -> VEPO -> plocha"
#   M2 zastaranost podla `cut_size` namiesto schemy
#      -> „zastarana skrinka: rozhoduje SCHEMA, nie pritomnost cut_size"
#   M3 ABS vynimka bez RED (olepeny groove chrbat bez nalezu)
#      -> „chrbat v drazke s ABS: bez cut_size a RED"
require_relative '../helper' unless defined?(NxTest)
require 'tmpdir'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet sync resolvers payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
end

module NxKon0
  module_function

  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  CN  = E::Construction
  BP  = E::BuildPlan
  BOM = E::Bom
  VAL = E::Validation
  PC  = E::ProductionCore
  SC  = PC.singleton_class

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def plan(params)
    CN.build_plan(CB.normalize(params), 'CAB-001')
  end

  def back(plan)
    plan[:parts].find { |pd| pd[:role] == 'back' }
  end

  # Snapshot chrbta v TOM tvare, v akom ho zapise builder (`add_part`) a vrati
  # `Store.config` (JSON round-trip: stringove kluce).
  def snapshot(pd, edges: nil)
    e = edges || { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
    out = { 'length' => pd[:prod][:length].round(2), 'width' => pd[:prod][:width].round(2),
            'thickness' => pd[:prod][:thickness].round(2), 'quantity' => 1,
            'material_id' => 'HDF_WHITE_3', 'grain_direction' => 'none', 'edges' => e }
    out['back_mode'] = pd[:back_mode] if pd[:back_mode]
    cut = CB.snapshot_cut_size(pd, e)
    out['cut_size'] = { 'length' => cut[:length], 'width' => cut[:width] } if cut
    out
  end

  def upper_back_snapshot(edges: nil)
    snapshot(back(plan('type' => 'upper')), edges: edges)
  end

  def rec(cfg, owner: 'CAB-001', pid: 11, role: 'back')
    BOM.record(cfg, owner_id: owner, name: 'Chrbat', part_key: 'cabinet/back', role: role, pid: pid)
  end

  def issues(cfg, standalone: false, owner: 'CAB-001', role: 'back')
    BOM.cut_issues_for(cfg, rec(cfg, owner: owner, role: role), owner_pid: nil, standalone: standalone)
  end

  def codes(list)
    Array(list).map { |i| i['code'] }
  end

  def stale_cfg(extra = {})
    { 'config_schema' => 18, 'back_mode' => 'groove', 'width' => 600.0, 'height' => 720.0,
      'floor_height' => 0.0 }.merge(extra)
  end

  # --- stuby exportov (vzor test_p0hf_brany.rb) ------------------------------
  def with_stubs(overrides)
    names = overrides.keys
    names.each do |name|
      SC.send(:alias_method, :"k0_orig_#{name}", name)
      SC.send(:define_method, name, &overrides[name])
    end
    yield
  ensure
    names.each do |name|
      SC.send(:remove_method, name)
      SC.send(:alias_method, name, :"k0_orig_#{name}")
      SC.send(:remove_method, :"k0_orig_#{name}")
    end
  end

  def with_ui(target, calls)
    ui = Module.new
    ui.define_singleton_method(:savepanel) do |_title, _dir, _name|
      calls << :savepanel
      target
    end
    ui.define_singleton_method(:select_directory) do |**_kw|
      calls << :select_directory
      File.dirname(target)
    end
    Object.const_set(:UI, ui)
    yield
  ensure
    Object.send(:remove_const, :UI) if Object.const_defined?(:UI, false)
  end

  def collected(cut_issues)
    { records: [], hardware: [], hardware_overrides: [], cabinet_sets: {},
      cabinet_set_conflicts: {}, placements: [], warnings: [], identities: [],
      hardware_issues: [], cut_issues: cut_issues }
  end

  def stubs(col)
    exp = { 'rows' => [{ 'code' => 'X', 'quantity' => 1, 'sources' => [] }], 'unmapped' => [] }
    bud = { 'totals' => { 'total' => 1.0, 'unknown_count_in_total' => 0 },
            'cp_preview' => { 'total' => 1.0, 'rows' => [], 'assembly' => 1.0,
                              'assembly_negative' => false, 'consistent' => true, 'diff' => 0.0 } }
    { refresh_vepo_settings: ->(*_a) {},
      vepo_settings: ->(*_a) { {} },
      save_vepo_settings: ->(*_a) { true },
      project_name: ->(*_a) { 'Test' },
      fresh_collect: ->(*_a) { col },
      sheets_map: ->(*_a) { {} },
      hardware_expansion: ->(*_a) { exp },
      budget_payload: ->(*_a) { bud },
      vepo_materials: ->(*_a) { {} },
      vepo_edge_thicknesses: ->(*_a) { {} },
      vepo_edge_decors: ->(*_a) { {} },
      vepo_sheet_decors: ->(*_a) { {} } }
  end

  # -> [sprava, chyba?, subory v priecinku, volania pickera]
  def run_export(method, col, dir)
    msg = nil
    err = nil
    calls = []
    with_stubs(stubs(col)) do
      with_ui(File.join(dir, 'out.file'), calls) do
        PC.send(method, :model, { 'gen' => 1 }, generation: 1,
                                                status: ->(m, e = false) { msg = m; err = e },
                                                repush: -> {})
      end
    end
    [msg, err, Dir.children(dir).sort, calls]
  end

  EXPORTS = %i[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].freeze
end

# ============================================================================
# 1. DESKRIPTOR A VALIDATOR PLANU
# ============================================================================

NxTest.test('D-143: horna 600 x 720 — chrbat v drazke nesie cut_size 600 x 720, geometria 564 x 684') do
  pd = NxKon0.back(NxKon0.plan('type' => 'upper'))
  NxTest.assert_equal('groove', pd[:back_mode])
  NxTest.assert_close(600.0, pd[:cut_size][:length])
  NxTest.assert_close(720.0, pd[:cut_size][:width])
  # geometria sa NEMENI (model ukazuje chrbat v drazke)
  NxTest.assert_close(564.0, pd[:prod][:length])
  NxTest.assert_close(684.0, pd[:prod][:width])
  NxTest.assert_equal([pd[:prod][:length], pd[:prod][:thickness], pd[:prod][:width]], pd[:box],
                      'box = prod (PartFaces/AppearanceMapping — D-88/MR-3A)')
end

NxTest.test('D-143: overlay / inset nesu LEN znacku povodu, ziadny cut_size; none ziadny dielec') do
  %w[overlay inset].each do |mode|
    pd = NxKon0.back(NxKon0.plan('type' => 'lower', 'back_mode' => mode))
    NxTest.assert_equal(mode, pd[:back_mode])
    NxTest.refute(pd.key?(:cut_size), "#{mode}: bez cut_size")
  end
  NxTest.assert_equal(nil, NxKon0.back(NxKon0.plan('type' => 'lower', 'back_mode' => 'none')))
end

NxTest.test('D-143: cut_size = w x (h - s) aj pri dolnej skrinke so soklom a groove') do
  pd = NxKon0.back(NxKon0.plan('type' => 'lower', 'back_mode' => 'groove', 'width' => 800.0,
                               'height' => 820.0, 'floor_height' => 100.0))
  NxTest.assert_close(800.0, pd[:cut_size][:length])
  NxTest.assert_close(720.0, pd[:cut_size][:width], 0.01, 'od spodku dna po vrch = h - s')
  NxTest.assert(pd[:cut_size][:length] >= pd[:prod][:length] && pd[:cut_size][:width] >= pd[:prod][:width])
end

NxTest.test('D-143: BuildPlan odmietne poskodeny cut_size / back_mode (pritomne pole = uplne a platne)') do
  good = NxKon0.back(NxKon0.plan('type' => 'upper'))
  bad = [
    [{ length: 'x', width: 720.0 }, 'cut_size length'],
    [{ length: 600.0, width: 0 }, 'cut_size width'],
    [{ length: -1.0, width: 720.0 }, 'cut_size length'],
    [{ length: Float::NAN, width: 720.0 }, 'cut_size length'],
    [{ length: 500.0, width: 720.0 }, 'mensi nez geometria'],
    ['600x720', 'neplatny cut_size']
  ]
  bad.each do |cut, pat|
    pd = good.merge(cut_size: cut)
    NxTest.assert_raise(pat) { NxKon0::BP.validate_part!(pd, {}) }
  end
  NxTest.assert_raise('back_mode') { NxKon0::BP.validate_part!(good.merge(back_mode: 'drazka'), {}) }
  side = NxKon0.plan('type' => 'upper')[:parts].find { |p| p[:role] == 'side_left' }
  NxTest.assert_raise('nie je chrbat') { NxKon0::BP.validate_part!(side.merge(back_mode: 'groove'), {}) }
  NxTest.assert_equal(7, NxKon0::BP::SCHEMA, 'aditivny volitelny kluc — KON-0 SCHEMA nebumpla (7 = ROH-A1, roly rohovej)')
end

# ============================================================================
# 2. SNAPSHOT (builder) A RETAZ CITATELOV
# ============================================================================

NxTest.test('D-143: builder zapise cut_size LEN neolepenemu dielcu') do
  pd = NxKon0.back(NxKon0.plan('type' => 'upper'))
  none = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
  NxTest.assert_equal({ length: 600.0, width: 720.0 }, NxKon0::CB.snapshot_cut_size(pd, none))
  NxTest.assert_equal(nil, NxKon0::CB.snapshot_cut_size(pd, none.merge('W2' => 'ABS1')),
                      'olepeny chrbat v drazke rozmer do narezu NEDOSTANE')
  NxTest.assert_equal({ length: 600.0, width: 720.0 }, NxKon0::CB.snapshot_cut_size(pd, none.merge('L1' => '')),
                      'prazdny retazec = bez ABS')
  inset = NxKon0.back(NxKon0.plan('type' => 'lower', 'back_mode' => 'inset'))
  NxTest.assert_equal(nil, NxKon0::CB.snapshot_cut_size(inset, none))
end

NxTest.test('D-143 (M1): retaz snapshot -> kusovnik -> format platne -> VEPO -> plocha (600 x 720)') do
  cfg = NxKon0.upper_back_snapshot
  r = NxKon0.rec(cfg)
  NxTest.assert_close(600.0, r['length'])
  NxTest.assert_close(720.0, r['width'])
  NxTest.assert_close(564.0, r['geo_length'])
  NxTest.assert_close(684.0, r['geo_width'])
  NxTest.assert_equal(true, r['cut_size'])

  out = NxKon0::BOM.compute(records: [r, NxKon0.rec(cfg, owner: 'CAB-002', pid: 12)])
  row = out[:rows].first
  NxTest.assert_equal(1, out[:rows].length, 'dva rovnake chrbty = jeden riadok')
  NxTest.assert_close(600.0, row['length'])
  NxTest.assert_close(720.0, row['width'])
  NxTest.assert_equal(2, row['quantity'])
  NxTest.assert_close(0.864, out[:sheets].first['m2'], 0.0005, '2 x 0,432 m2 (nie 2 x 0,386)')

  # plocha pre rozpocet a ponuku ide z riadkov BOM
  est = Noxun::Engine::SheetEstimate.estimate(out[:rows], sheet_sizes: { 'HDF_WHITE_3' => [2800.0, 2070.0] })
  NxTest.assert_close(0.864, est.first['m2'], 0.0005)

  # VEPO: rozmer do narezu v CSV
  res = Noxun::Engine::VepoExport.build(out[:rows], project: 'T', materials: { 'HDF_WHITE_3' => { 'label' => 'HDF' } },
                                                     version: 't', generated_at: 't')
  csv = res['groups'].first['csv']
  NxTest.assert(csv.include?('"600";""') && csv.include?('"720";""'), "VEPO 600 x 720: #{csv}")
  NxTest.refute(csv.include?('"564"'), 'rozmer modelu do VEPO nejde')

  # format platne: 564 x 684 by sa zmestil na 650 x 710, 600 x 720 nie
  ctrl = NxKon0::VAL.run({ records: [r] }, sheets: { 'HDF_WHITE_3' => { 'thickness' => 3.0,
                                                                        'sheet_size' => [650.0, 710.0] } })
  NxTest.assert(ctrl['items'].any? { |i| i['category'] == NxKon0::VAL::CAT_OVERSIZE },
                'kontrola formatu platne pocita s vacsim polotovarom')
end

NxTest.test('D-143: cut_size sa uplatni PRED otocenim podla dekoru (priecny dekor = 720 x 600)') do
  cfg = NxKon0.upper_back_snapshot.merge('grain_direction' => 'width')
  rows = NxKon0::BOM.compute(records: [NxKon0.rec(cfg)])[:rows]
  o = Noxun::Engine::VepoExport.oriented(rows.first)
  NxTest.assert_close(720.0, o['length'])
  NxTest.assert_close(600.0, o['width'])
end

NxTest.test('D-143: hmotnost ostava z GEOMETRIE (odrezok sa nevazi)') do
  cfg = NxKon0.upper_back_snapshot
  smap = { 'HDF_WHITE_3' => { 'density' => 800.0 } }
  dens, = Noxun::Engine::Materials.density_or_fallback(smap['HDF_WHITE_3'])
  geo = Noxun::Engine::Materials.weight_kg(564.0, 684.0, 3.0, dens)
  cut = Noxun::Engine::Materials.weight_kg(600.0, 720.0, 3.0, dens)
  kg = NxKon0::BOM.weight_totals([cfg], smap)['kg']
  NxTest.assert_close(geo.round(2), kg, 0.01)
  NxTest.refute((cut.round(2) - kg).abs < 0.005, 'nie rozmer do narezu')
end

NxTest.test('D-143: chybajuci cut_size = geometria (overlay, stare zakazky) — bez nalezu') do
  pd = NxKon0.back(NxKon0.plan('type' => 'lower'))
  cfg = NxKon0.snapshot(pd)
  r = NxKon0.rec(cfg)
  NxTest.assert_close(pd[:prod][:length], r['length'])
  NxTest.refute(r.key?('cut_size'))
  NxTest.assert_equal([], NxKon0.issues(cfg))
end

# ============================================================================
# 3. NALEZY A BRANA
# ============================================================================

NxTest.test('D-143: poskodeny cut_size -> geometria + RED (akykolvek dielec)') do
  base = NxKon0.upper_back_snapshot
  [{ 'length' => 'x', 'width' => 720.0 }, { 'length' => 600.0, 'width' => 0 },
   { 'length' => 500.0, 'width' => 720.0 }, 'zle', nil].each do |cut|
    cfg = base.merge('cut_size' => cut)
    r = NxKon0.rec(cfg)
    NxTest.assert_close(564.0, r['length'], 0.01, "#{cut.inspect}: geometria")
    NxTest.assert_equal(true, r['cut_invalid'])
    NxTest.assert(NxKon0.codes(NxKon0.issues(cfg)).include?(NxKon0::BOM::CUT_INVALID), cut.inspect)
  end
  side = { 'length' => 720.0, 'width' => 320.0, 'cut_size' => { 'length' => 1.0, 'width' => 1.0 } }
  NxTest.assert_equal([NxKon0::BOM::CUT_INVALID], NxKon0.codes(NxKon0.issues(side, role: 'side_left')))
end

NxTest.test('D-143 (M3): chrbat v drazke s ABS (override aj pravidlo) -> bez cut_size a RED') do
  cfg = NxKon0.upper_back_snapshot(edges: { 'L1' => nil, 'L2' => 'ABS_X', 'W1' => nil, 'W2' => nil })
  NxTest.refute(cfg.key?('cut_size'), 'builder rozmer do narezu nezapise')
  NxTest.assert_equal([NxKon0::BOM::BACK_EDGED], NxKon0.codes(NxKon0.issues(cfg)))
  # zdroj hrany (rucny override / pravidlo olepu pre rolu back) je pre snapshot
  # jedno — rozhoduje UCINNA hrana; aj samostatny kus ostava chraneny
  NxTest.assert_equal([NxKon0::BOM::BACK_EDGED], NxKon0.codes(NxKon0.issues(cfg, standalone: true)))
  NxTest.assert(NxKon0::BOM::CUT_BLOCKERS.include?(NxKon0::BOM::BACK_EDGED))
end

NxTest.test('D-143: neolepeny groove chrbat so znackou bez cut_size = neuplny snapshot (RED)') do
  cfg = NxKon0.upper_back_snapshot
  cfg.delete('cut_size')
  NxTest.assert_equal([NxKon0::BOM::BACK_INCOMPLETE], NxKon0.codes(NxKon0.issues(cfg)))
end

NxTest.test('D-143 (Codex #401 P1): aktualna groove skrinka + chrbat bez znacky aj cut_size = neuplny zaznam') do
  owner = NxKon0.stale_cfg('config_schema' => 19)
  lost = NxKon0.upper_back_snapshot.reject { |k, _| %w[cut_size back_mode].include?(k) }
  b = NxKon0::BOM
  list = b.cut_issues_for(lost, NxKon0.rec(lost), owner_pid: 7, owner_cfg: owner)
  NxTest.assert_equal([b::BACK_INCOMPLETE], NxKon0.codes(list), 'snapshot stratil nove polia — RED, nie geometria')
  NxTest.assert(b::CUT_BLOCKERS.include?(b::BACK_INCOMPLETE), 'a brana stoji')
  NxTest.refute(NxKon0::PC.cut_stop(NxKon0.collected(list)).nil?)
  # poskodena znacka: to iste
  bad = lost.merge('back_mode' => 42)
  NxTest.assert_equal([b::BACK_INCOMPLETE],
                      NxKon0.codes(b.cut_issues_for(bad, NxKon0.rec(bad), owner_cfg: owner)))
  # legacy zapis rezimu vlastnika (`back.mode`) sa cita rovnako
  legacy_owner = { 'config_schema' => 19, 'back' => { 'mode' => 'groove' } }
  NxTest.assert_equal([b::BACK_INCOMPLETE],
                      NxKon0.codes(b.cut_issues_for(lost, NxKon0.rec(lost), owner_cfg: legacy_owner)))
  # olepeny chrbat bez znacky v aktualnej groove skrinke = olepena hrana
  edged = lost.merge('edges' => { 'L1' => 'A', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  NxTest.assert_equal([b::BACK_EDGED], NxKon0.codes(b.cut_issues_for(edged, NxKon0.rec(edged), owner_cfg: owner)))
  # uplny snapshot v aktualnej skrinke = ziadny nalez; zastarana (schema 18) ani overlay vlastnik nie
  NxTest.assert_equal([], b.cut_issues_for(NxKon0.upper_back_snapshot, NxKon0.rec(NxKon0.upper_back_snapshot),
                                           owner_cfg: owner))
  NxTest.assert_equal([], b.cut_issues_for(lost, NxKon0.rec(lost), owner_cfg: NxKon0.stale_cfg),
                      'schema 18 riesi zastaranost skrinky, nie dielec')
  NxTest.assert_equal([], b.cut_issues_for(lost, NxKon0.rec(lost),
                                           owner_cfg: NxKon0.stale_cfg('config_schema' => 19, 'back_mode' => 'overlay')))
  # zber posiela config vlastnika pri VNORENOM dielci
  src = NxKon0.src('noxun_engine', 'core', 'bom.rb')
  NxTest.assert(src.include?('cut_issues_for(pcfg, rec, owner_pid: inst.persistent_id, owner_cfg: ccfg)'))
end

NxTest.test('D-143: samostatny chrbat — novy so znackou chraneny, stary bez znacky ORANGE') do
  fresh = NxKon0.upper_back_snapshot
  NxTest.assert_equal([], NxKon0.issues(fresh, standalone: true), 'novy odpojeny chrbat so cut_size = OK')
  NxTest.assert_close(600.0, NxKon0.rec(fresh)['length'], 0.01, 'a do narezu ide v plnom rozmere')
  old = fresh.reject { |k, _| %w[cut_size back_mode].include?(k) }
  list = NxKon0.issues(old, standalone: true)
  NxTest.assert_equal([NxKon0::BOM::BACK_ORIGIN], NxKon0.codes(list))
  NxTest.assert_equal('orange', list.first['severity'])
  NxTest.refute(NxKon0::BOM::CUT_BLOCKERS.include?(NxKon0::BOM::BACK_ORIGIN), 'ORANGE export nezastavi')
  NxTest.assert_equal([], NxKon0.issues(old), 'vnoreny stary chrbat riesi zastaranost skrinky, nie dielec')
end

NxTest.test('D-143 (M2): zastarana skrinka — rozhoduje SCHEMA, nie pritomnost cut_size') do
  b = NxKon0::BOM
  NxTest.assert(b.back_stale?(NxKon0.stale_cfg))
  NxTest.refute(b.back_stale?(NxKon0.stale_cfg('config_schema' => 19)), 'prestavana = OK (aj s ABS bez cut_size)')
  NxTest.refute(b.back_stale?(NxKon0.stale_cfg('back_mode' => 'overlay')))
  # legacy zapis `back.mode` bez plocheho kluca (audit FIX 4)
  legacy = { 'back' => { 'mode' => 'groove', 'thickness' => 3.0 } }
  NxTest.assert(b.back_stale?(legacy), 'legacy config bez markera schemy = 0 < 19')
  NxTest.refute(b.back_stale?({ 'back' => { 'mode' => 'overlay' } }))
  NxTest.refute(b.back_stale?({}), 'chybajuci chrbat = overlay (config_to_params)')
  NxTest.assert_equal('groove', b.stored_back_mode(legacy))
  # plochy kluc ma prednost (ta ista semantika ako `config_to_params`)
  NxTest.refute(b.back_stale?({ 'back_mode' => 'inset', 'back' => { 'mode' => 'groove' } }))
  NxTest.assert(b.back_stale?(NxKon0.stale_cfg('config_schema' => '18')), 'ciselny string schemy (R-12)')
  NxTest.refute(b.back_stale?(NxKon0.stale_cfg('config_schema' => '19')))
  # pokazeny atribut zber nezhodi
  NxTest.refute(b.back_stale?({ 'back' => ['groove'] }))
  iss = b.back_stale_issue('CAB-7', 70, NxKon0.stale_cfg)
  NxTest.assert_equal([b::BACK_STALE, 'red', true], [iss['code'], iss['severity'], iss['rebuild_stale']])
  NxTest.assert(iss['message'].include?('600 × 720') && iss['message'].include?('CAB-7'), iss['message'])
  NxTest.assert_equal(nil, b.back_stale_issue('CAB-8', 80, NxKon0.stale_cfg('config_schema' => 19)))
end

NxTest.test('D-143: Kontrola — RED pre blokujuce kody, ORANGE pre stary samostatny chrbat, klik na skrinku') do
  b = NxKon0::BOM
  list = [b.back_stale_issue('CAB-1', 5, NxKon0.stale_cfg)]
  list.concat(NxKon0.issues(NxKon0.upper_back_snapshot(edges: { 'L1' => 'A', 'L2' => nil, 'W1' => nil, 'W2' => nil }),
                            owner: 'CAB-2'))
  old = NxKon0.upper_back_snapshot.reject { |k, _| %w[cut_size back_mode].include?(k) }
  list.concat(NxKon0.issues(old, standalone: true, owner: 'CAB-3'))
  items = NxKon0::VAL.run({ records: [], cut_issues: list })['items']
    .select { |i| i['category'] == NxKon0::VAL::CAT_BACK_CUT }
  NxTest.assert_equal(3, items.length)
  sev = items.map { |i| [i['owner_id'], i['severity']] }.sort
  NxTest.assert_equal([%w[CAB-1 red], %w[CAB-2 red], %w[CAB-3 orange]], sev)
  st = items.find { |i| i['owner_id'] == 'CAB-1' }
  NxTest.assert_equal([nil, 5, 'rebuild_stale'], [st['part_key'], st['owner_pid'], st['fix']])
  NxTest.assert_equal(nil, items.find { |i| i['owner_id'] == 'CAB-2' }['fix'])
  # nezavisle od katalogu a predcasneho navratu pre UNI
  uni = { 'U' => { 'uni' => true, 'thickness' => 3.0 } }
  items2 = NxKon0::VAL.run({ records: [], cut_issues: list }, sheets: uni)['items']
  NxTest.assert_equal(3, items2.count { |i| i['category'] == NxKon0::VAL::CAT_BACK_CUT })
  NxTest.assert_equal([], NxKon0::VAL.run({ records: [] })['items'], 'chybajuci kluc = kontrola sa preskoci')
end

NxTest.test('D-143: brana — jedna veta na kod v poradi registra, ORANGE neblokuje') do
  b = NxKon0::BOM
  pc = NxKon0::PC
  NxTest.assert_equal(nil, pc.cut_stop(NxKon0.collected([])))
  old = NxKon0.upper_back_snapshot.reject { |k, _| %w[cut_size back_mode].include?(k) }
  NxTest.assert_equal(nil, pc.cut_stop(NxKon0.collected(NxKon0.issues(old, standalone: true))),
                      'stary samostatny chrbat export NEZASTAVI (rozhodnutie Michal 27.9.)')
  list = [b.back_stale_issue('CAB-1', 1, NxKon0.stale_cfg), b.back_stale_issue('CAB-2', 2, NxKon0.stale_cfg)]
  list.concat(NxKon0.issues(NxKon0.upper_back_snapshot.merge('cut_size' => 'x'), owner: 'CAB-5'))
  msg = pc.cut_stop(NxKon0.collected(list))
  NxTest.assert(msg.include?('NEVYKONAL') && msg.include?('nevytvoril'), msg)
  NxTest.assert(msg.index('poškodený rozmer') < msg.index('zo staršej verzie'), "poradie registra: #{msg}")
  NxTest.assert(msg.include?('CAB-1, CAB-2') && msg.include?('CAB-5'), msg)
end

if NxTest.headless?
  # Kazdy blokujuci dovod x kazdy zo styroch exportov: NULA volani pickera
  # a NULA suborov na disku (nestaci test farby — audit FIX 3).
  NxTest.test('D-143 (FIX 3): kazdy blokujuci dovod x kazdy export — picker ani zapis sa nestanu') do
    b = NxKon0::BOM
    edged = NxKon0.upper_back_snapshot(edges: { 'L1' => 'A', 'L2' => nil, 'W1' => nil, 'W2' => nil })
    incomplete = NxKon0.upper_back_snapshot.reject { |k, _| k == 'cut_size' }
    reasons = {
      b::CUT_INVALID => NxKon0.issues(NxKon0.upper_back_snapshot.merge('cut_size' => { 'length' => 1 })),
      b::BACK_EDGED => NxKon0.issues(edged),
      b::BACK_INCOMPLETE => NxKon0.issues(incomplete),
      b::BACK_STALE => [b.back_stale_issue('CAB-1', 1, NxKon0.stale_cfg)],
      # D-144 (KON-A): ten isty register brany.
      b::BACK_RAIL_STALE => [b.back_rail_stale_issue('CAB-1', 1, NxKon0.stale_cfg(
        'config_schema' => 19, 'back_mode' => 'inset', 'top_mode' => 'two_rails', 'rails_orientation' => 'upright'
      ))]
    }
    NxTest.assert_equal(b::CUT_BLOCKERS.sort, reasons.keys.sort, 'test pokryva cely register')
    reasons.each do |code, list|
      NxTest.assert_equal([code], NxKon0.codes(list))
      NxKon0::EXPORTS.each do |m|
        Dir.mktmpdir('nx-kon0-') do |dir|
          msg, err, files, calls = NxKon0.run_export(m, NxKon0.collected(list), dir)
          NxTest.assert_equal([], calls, "#{code} x #{m}: picker sa nesmie otvorit")
          NxTest.assert_equal([], files, "#{code} x #{m}: ziadny subor")
          NxTest.assert(err && msg.to_s.include?('NEVYKONAL'), "#{code} x #{m}: #{msg}")
        end
      end
    end
  end

  NxTest.test('D-143: ORANGE stary samostatny chrbat VEPO nezastavi (picker sa otvori)') do
    old = NxKon0.upper_back_snapshot.reject { |k, _| %w[cut_size back_mode].include?(k) }
    Dir.mktmpdir('nx-kon0-') do |dir|
      _msg, _err, _files, calls = NxKon0.run_export(:do_export,
                                                    NxKon0.collected(NxKon0.issues(old, standalone: true)), dir)
      NxTest.assert_equal([:select_directory], calls)
    end
  end
end

NxTest.test('D-143: brana je vo VSETKYCH STYROCH exportoch hned po zbere a PRED pickerom') do
  s = NxKon0.src('noxun_engine', 'ui', 'production_core.rb')
  %w[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].each do |m|
    body = s[/def #{m}\b.*?\n      rescue StandardError/m].to_s
    NxTest.refute(body.empty?, m)
    i_col = body.index('fresh_collect(model)')
    i_cut = body.index('cut_stop(collected)')
    picker = body.index('UI.select_directory') || body.index('UI.savepanel')
    NxTest.assert(i_cut && i_col < i_cut && i_cut < picker, "#{m}: poradie zber -> brana D-143 -> picker")
    NxTest.assert(i_cut < (body.index('hardware_expansion(') || picker), "#{m}: brana pred expanziou")
  end
end

NxTest.test('D-143 (Codex #401 P2): nalez samostatneho chrbta nesie PID zdrojoveho kusu') do
  old = NxKon0.upper_back_snapshot.reject { |k, _| %w[cut_size back_mode].include?(k) }
  list = [NxKon0::BOM.cut_issues_for(old, NxKon0.rec(old, pid: 101), standalone: true),
          NxKon0::BOM.cut_issues_for(old, NxKon0.rec(old, pid: 102), standalone: true)].flatten
  items = NxKon0::VAL.run({ records: [], cut_issues: list })['items']
                     .select { |i| i['category'] == NxKon0::VAL::CAT_BACK_CUT }
  NxTest.assert_equal([101, 102], items.map { |i| i['pid'] }.sort, 'dva riadky, kazdy so svojim PID')
end

# Stub SketchUp tried pre `ProductionCore.pids_for_problem` (vzor
# test_ghost_d1_dosky.rb — stub zije VNUTRI modulu; znovuotvorenie tried je
# neskodne, ked uz existuju).
unless NxTest::IN_SKETCHUP
  module Noxun
    module Engine
      module ProductionCore
        module Sketchup
          class ComponentInstance; end
          class Model; end
        end
      end
    end
  end
end

if NxTest.headless?
  NXK0_SU = Noxun::Engine::ProductionCore::Sketchup
  NXK0_ROOT = NXK0_SU::Model.new

  class NxK0FakePart < NXK0_SU::ComponentInstance
    attr_reader :persistent_id, :parent

    def initialize(pid, cid, pkey, root: true)
      super()
      @persistent_id = pid
      @attrs = { 'kind' => 'part', 'cabinet_id' => cid, 'part_key' => pkey }
      @parent = root ? NXK0_ROOT : Object.new
    end

    def valid?
      true
    end

    def get_attribute(_dict, key, default = nil)
      @attrs.fetch(key, default)
    end
  end

  class NxK0FakeModel
    attr_reader :entities

    def initialize(entities)
      @entities = entities
    end

    def find_entity_by_persistent_id(pid)
      @entities.find { |e| e.persistent_id == pid }
    end
  end

  NxTest.test('D-143 (Codex #401 P2): klik na samostatny chrbat oznaci TEN kus, nie vsetky zhodne') do
    a = NxK0FakePart.new(101, 'CAB-001', 'cabinet/back')
    b = NxK0FakePart.new(102, 'CAB-001', 'cabinet/back')
    model = NxK0FakeModel.new([a, b])
    pc = NxKon0::PC
    base = { 'category' => NxKon0::VAL::CAT_BACK_CUT, 'owner_id' => 'CAB-001', 'part_key' => 'cabinet/back' }
    NxTest.assert_equal([102], pc.pids_for_problem(model, base.merge('pid' => 102)))
    NxTest.assert_equal([101], pc.pids_for_problem(model, base.merge('pid' => 101)))
    # vnoreny dielec PID-om neadresuje (plati vseobecna vetva, fail-open)
    nested = NxK0FakePart.new(103, 'CAB-001', 'cabinet/back', root: false)
    NxTest.assert_equal(nil, pc.standalone_part_entity(NxK0FakeModel.new([nested]), 103))
    NxTest.assert_equal(nil, pc.standalone_part_entity(model, nil))
    NxTest.assert_equal(nil, pc.standalone_part_entity(model, 999))
  end
end

# ============================================================================
# 4. SCHEMA A KOMPATIBILITA
# ============================================================================

NxTest.test('D-143: CONFIG_SCHEMA 19+ + aktivacna schema 19 + HISTORIA + dopredna brana') do
  cb = NxKon0::CB
  # KON-A zvysila schemu na 20 — D-143 plati od 19 VRATANE (aktivacna ostava).
  NxTest.assert(cb::CONFIG_SCHEMA >= 19, "CONFIG_SCHEMA #{cb::CONFIG_SCHEMA}")
  NxTest.assert_equal(19, cb::BACK_CUT_ACTIVATION_SCHEMA)
  NxTest.assert_equal([5, 9, 11], [cb::DRAWER_ACTIVATION_SCHEMA, cb::HINGE_ACTIVATION_SCHEMA, cb::LIFT_ACTIVATION_SCHEMA],
                      'starsie aktivacne konstanty sa nehybu')
  NxTest.assert(NxKon0.src('noxun_engine', 'core', 'cabinet_builder.rb').include?('#  19 = D-143'),
                'HISTORIA musi povedat, PRECO sa bumplo')
  NxTest.assert(cb.newer_config?({ 'config_schema' => cb::CONFIG_SCHEMA + 1 }), 'novsi config prestavbu zastavi')
  NxTest.refute(cb.newer_config?({ 'config_schema' => 19 }))
  NxTest.assert(cb.cabinet_config(cb.normalize('type' => 'upper'))[:config_schema] >= 19,
                'stavba zapisuje schemu >= 19 — prestavana skrinka prestane byt zastarana')
end

# ============================================================================
# 5. INSPECTOR — plocha skrinky a karta dielca
# ============================================================================

if NxTest.headless?
  NxTest.test('D-143 (FIX 6): plocha skrinky v Inspectore = rozmer do narezu, hmotnost z geometrie') do
    panel = Noxun::Engine::Panel
    psc = panel.singleton_class
    part = NxTest::FakeEntity.new
    Noxun::Engine::Store.write(part, kind: 'part', config: NxKon0.upper_back_snapshot)
    psc.send(:alias_method, :k0_orig_mp, :manufactured_parts)
    psc.send(:alias_method, :k0_orig_ws, :weight_sheets_map)
    psc.send(:define_method, :manufactured_parts) { |_cab| [part] }
    psc.send(:define_method, :weight_sheets_map) { { 'HDF_WHITE_3' => { 'density' => 800.0 } } }
    begin
      st = panel.cabinet_stats(:cab)
      NxTest.assert_close(0.432, st['parts_area_m2'], 0.0005, '600 x 720 = 0,432 m2 (nie 0,386)')
      dens, = Noxun::Engine::Materials.density_or_fallback({ 'density' => 800.0 })
      geo = Noxun::Engine::Materials.weight_kg(564.0, 684.0, 3.0, dens)
      NxTest.assert_close(geo.round(2), st['weight_kg'], 0.01)
    ensure
      psc.send(:remove_method, :manufactured_parts)
      psc.send(:alias_method, :manufactured_parts, :k0_orig_mp)
      psc.send(:remove_method, :k0_orig_mp)
      psc.send(:remove_method, :weight_sheets_map)
      psc.send(:alias_method, :weight_sheets_map, :k0_orig_ws)
      psc.send(:remove_method, :k0_orig_ws)
    end
  end

  NxTest.test('D-143 (FIX 5): karta dielca — „Do nárezu" a texty „výrobne" v rozmere do narezu') do
    panel = Noxun::Engine::Panel
    cfg = NxKon0.upper_back_snapshot
    cp = panel.part_cut_payload(cfg)
    NxTest.assert_equal('600 × 720', cp['cut_text'])
    NxTest.assert(cp['cut_title'].include?('zrezať do drážky') && cp['cut_title'].include?('564 × 684'), cp['cut_title'])
    NxTest.assert(cp['model_title'].include?('600 × 720'))
    NxTest.assert_equal({}, panel.part_cut_payload(cfg.reject { |k, _| k == 'cut_size' }), 'bez cut_size nic')
    NxTest.assert_equal({}, panel.part_cut_payload(cfg.merge('cut_size' => 'x')), 'poskodeny udaj riadok nedostane')
    # priecny dekor v snapshote, material bez smeru -> hint hovori VYROBNY tvar 720 x 600
    gp = panel.part_grain_payload(cfg.merge('grain_direction' => 'width', 'material_id' => 'NEEXISTUJE'), {})
    NxTest.assert(gp['grain_hint'].to_s.include?('720×600'), "hint: #{gp['grain_hint']}")
    NxTest.refute(gp['grain_hint'].to_s.include?('684'), 'nie rozmer modelu')
  end
end

# ============================================================================
# 6. HROMADNA PRESTAVBA — plan (zapis overuje in-SU)
# ============================================================================

NxTest.test('D-143 (NOTE 7): plan prestavby — len zastarane, odpojene a nezname kovanie sa vymenuju') do
  pc = NxKon0::PC
  entries = [
    pc.back_stale_entry('CAB-1', NxKon0.stale_cfg, false),
    pc.back_stale_entry('CAB-2', NxKon0.stale_cfg('config_schema' => 19), false),
    pc.back_stale_entry('CAB-3', NxKon0.stale_cfg, true),
    pc.back_stale_entry('CAB-4', NxKon0.stale_cfg('hardware' => [{ 'generic_type' => 'zzz_neznamy' }]), false)
  ]
  plan = pc.back_stale_plan(entries)
  NxTest.assert_equal(['CAB-1'], plan['jobs'].map { |e| e['id'] })
  NxTest.assert_equal(3, plan['stale'])
  NxTest.assert_equal(%w[CAB-3 CAB-4], plan['skipped'].map(&:first))
  NxTest.assert(pc.back_stale_done_msg(plan).include?('Prestavané zastarané skrinky: 1'))
  NxTest.assert(pc.back_stale_done_msg(plan).include?('CAB-3 (' + Noxun::Engine::Ids::DETACHED_PART_REASON))
  empty = pc.back_stale_plan([entries[1]])
  NxTest.assert(pc.back_stale_empty_msg(empty).include?('nič sa neprestavovalo'))
end

NxTest.test('D-143: zapis hromadnej prestavby zije v Paneli (brana 1b-3) a ide jednou operaciou') do
  s = NxKon0.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  body = s[/def back_rebuild_stale\(.*?\n        rescue StandardError/m].to_s
  NxTest.refute(body.empty?)
  %w[data['gen'] flush_blocked DocKey.foreign? flush_pending! back_stale_scan rebuild_many push_selected].each do |tok|
    NxTest.assert(body.include?(tok), "chyba #{tok}")
  end
  NxTest.assert(body.index('flush_pending!') < body.index('back_stale_scan'),
                'vyber zastaranych skriniek AZ po ustaleni observera')
  pc = NxKon0.src('noxun_engine', 'ui', 'production_core.rb')
  NxTest.refute(pc.include?('CabinetBuilder.rebuild_many(model, jobs, op_name: \'NOXUN: Prestaviť'),
                'citacie jadro nezapisuje')
end

NxTest.test('D-143 vyber: oznaceny DIELEC prestavanej skrinky sa vrati (karta dielca ostane) — vzor D-131') do
  s = NxKon0.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  body = s[/def back_rebuild_stale\(.*?\n        rescue StandardError/m].to_s
  NxTest.assert(body.include?('rebuilt_selected ? find_selected_part(model) : nil'),
                'dielec sa hlada LEN pri prestavanej skrinke')
  NxTest.assert(body.include?('canonical_part_key(existing_params(selected), part_identity(selected, part))'),
                'navrat ide cez stabilny part_key (entity po prestavbe zaniknu)')
  NxTest.assert(body.index('find_selected_part') < body.index('rebuild_many'),
                'dielec sa zisti PRED prestavbou')
  NxTest.assert(body.index('focus_part(model, selected, part_key)') > body.index('rebuild_many'),
                'a fokus sa vrati AZ PO nej')
  NxTest.assert(body.include?('reselect(model, selected)'), 'bez dielca sa oznaci skrinka ako doteraz')
end
