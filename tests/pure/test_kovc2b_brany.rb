# frozen_string_literal: true
# KOV-C2b — REGISTER BRAN, NAKUP (`drawer_kit_missing`), ULOZENY NOSIC
# konfliktov, SERVEROVE polia `drawer.system`/`recipe_refs` a CHARAKTERIZACIA
# (zakazka bez klasifikacie zasuvky je CONTENT-identicka).
#
# MUTACIE, ktore tato sada chyta:
#   M1 receptova polozka padne na genericke `slide` mapovanie
#      -> „nakup: receptova polozka NIKDY nepada na genericky `slide`"
#   M2 `drawer_kit_missing` neblokuje VEPO -> „VEPO ma branu LEN na chybajuci kit"
#   M3 `drawer_conflicts` neprezije config round-trip -> „ulozeny nosic…"
#   M4 klientsky payload prepise `recipe_refs` -> „serverove polia: forged payload…"
require_relative '../helper' unless defined?(NxTest)

# UI vrstva (brany exportov + dialog materialov) — headless nie je v require
# zozname helpera, takze si ju sada pyta sama (vzor `test_kovc2a_kanal_sety.rb`).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
end

module NxC2bB
  E   = Noxun::Engine
  REC = E::Recipes
  HWS = E::HardwareSets
  VAL = E::Validation
  PC  = E::ProductionCore
  CB  = E::CabinetBuilder
  CN  = E::Construction
  FR  = E::Fronts

  module_function

  # Receptova polozka vysuvu (presne taka, aku vydava `Construction`).
  def recipe_item(over = {})
    params = { 'recipe_id' => 'atira_sisy_v1', 'system' => 'atira',
               'height_variant' => 70.0, 'nominal_length' => 470.0, 'load' => 30.0,
               'opening' => 'sisy', 'opening_mode' => 'classic',
               'drawer_construction' => 'metal' }.merge(over.delete('params') || {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'recipe:atira_sisy_v1',
      'params' => params, 'source' => 'recipe' }.merge(over)
  end

  def legacy_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'vysuvy-nl-podla-hlbky',
      'params' => { 'nominal_length' => 470.0 }, 'source' => 'rule' }.merge(over)
  end

  # Nalez z ulozeneho nosica (`Bom.collect` -> `hardware_issues`).
  def issue(code, owner = 'CAB-1')
    { 'code' => code, 'severity' => 'red', 'owner_id' => owner,
      'part_key' => 'front:F1/panel', 'front_id' => 'F1',
      'message' => 'Zásuvka sa nedá vyriešiť.', 'label' => 'F1 · zásuvkové čelo' }
  end

  def expansion(unmapped)
    { 'rows' => [], 'unmapped' => unmapped }
  end

  def src(rel)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
  end

  def src_ui(rel)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', rel), encoding: 'UTF-8')
  end
end

# ============================================================================
# R4 — REGISTER BRAN
# ============================================================================

NxTest.test('KOV-C2b (R4): register ma 11 kodov — 10 z resolvera + 1 MIGRACNY') do
  c = NxC2bB
  NxTest.assert_equal(11, c::REC::DRAWER_BLOCKERS.length)
  NxTest.assert_equal(10, c::REC::CONFLICT_CODES.length, 'resolver produkuje 10')
  NxTest.assert_equal(c::REC::CONFLICT_CODES + ['drawer_stale'], c::REC::DRAWER_BLOCKERS,
                      '11. kod je MIGRACNY (`drawer_stale`) — resolver ho nevyraba')
  NxTest.assert_equal(9, c::REC::BUILD_BLOCKERS.length)
  NxTest.assert_equal('drawer_kit_missing', c::REC::KIT_MISSING)
  NxTest.assert_equal('drawer_stale', c::REC::STALE)
  NxTest.assert_equal(%w[drawer_kit_missing drawer_stale], c::REC::ALL_EXPORT_BLOCKERS,
                      'kody, ktore blokuju AJ VEPO')
  NxTest.refute(c::REC::BUILD_BLOCKERS.include?(c::REC::KIT_MISSING))
  NxTest.refute(c::REC::BUILD_BLOCKERS.include?(c::REC::STALE))
  # Kazdy kod ma slovensky nazov pre branu (inak by hlaska ukazala kod).
  c::REC::DRAWER_BLOCKERS.each do |code|
    NxTest.assert(c::REC::BLOCKER_LABELS[code].to_s.length > 5, "#{code}: chyba nazov")
  end
  # Retazec kodu nakupu sa nesmie rozist medzi modulmi.
  NxTest.assert_equal(c::REC::KIT_MISSING, c::HWS::DRAWER_KIT_MISSING)
  NxTest.assert(c::HWS::UNMAPPED_REASONS.include?(c::REC::KIT_MISSING))
end

NxTest.test('KOV-C2b (R4): KAZDY kod stavby zastavi CSV/rozpocet/ponuku, VEPO nie') do
  c = NxC2bB
  c::REC::BUILD_BLOCKERS.each do |code|
    collected = { hardware_issues: [c.issue(code)], hardware: [] }
    all = c::PC.drawer_blockers(collected, nil)
    NxTest.assert_equal(1, all.length, "#{code}: brana `all` zastavuje")
    NxTest.assert(all.first.include?(c::REC::BLOCKER_LABELS[code]), all.inspect)
    NxTest.assert(all.first.include?('CAB-1'), 'brana menuje skrinku')
    NxTest.assert_equal([], c::PC.drawer_blockers(collected, nil, scope: :kit),
                        "#{code}: VEPO branu nepotrebuje (geometria sa nevydala)")
    # Hotovy status ide cez ten isty `export_blockers`.
    NxTest.assert_equal(all, c::PC.export_blockers(drawer: all))
  end
end

NxTest.test('KOV-C2b (R4): `drawer_kit_missing` zastavi VSETKY exporty VRATANE VEPO') do
  c = NxC2bB
  exp = c.expansion([{ 'cabinet_id' => 'CAB-2', 'reason' => 'drawer_kit_missing',
                       'base_reason' => 'class_unmapped' }])
  %i[all kit].each do |scope|
    out = c::PC.drawer_blockers({ hardware_issues: [], hardware: [] }, exp, scope: scope)
    NxTest.assert_equal(1, out.length, "#{scope}: kit blokuje")
    NxTest.assert(out.first.include?('CAB-2'))
  end
  NxTest.assert_equal([], c::PC.drawer_blockers({ hardware_issues: [], hardware: [] },
                                                c.expansion([])),
                      'ziadny nemapovany riadok = ziadna blokada')
end

NxTest.test('KOV-C2b (R4): nedokazatelna expanzia pri receptovej polozke = fail-closed') do
  c = NxC2bB
  with_recipe = { hardware_issues: [], hardware: [c.recipe_item] }
  NxTest.assert(c::PC.drawer_expansion_unproven?(with_recipe, nil))
  NxTest.assert(c::PC.drawer_stop(with_recipe, nil).to_s.include?('kit zásuviek'))
  # Zakazka BEZ receptovych poloziek sa nemeni (legacy sprava ostava).
  legacy = { hardware_issues: [], hardware: [c.legacy_item] }
  NxTest.refute(c::PC.drawer_expansion_unproven?(legacy, nil))
  NxTest.assert_equal(nil, c::PC.drawer_stop(legacy, nil))
end

NxTest.test('KOV-C2b (R4): brana bezi PRED vyberom priecinka vo VSETKYCH styroch exportoch') do
  c = NxC2bB
  s = c.src('ui/production_core.rb')
  %w[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].each do |m|
    body = s[/def #{m}\b.*?\n      rescue StandardError/m].to_s
    next if body.empty?

    NxTest.assert(body.include?('drawer_stop'), "#{m}: chyba brana zasuviek")
    picker = body.index('UI.select_directory') || body.index('UI.savepanel')
    NxTest.assert(picker.nil? || body.index('drawer_stop') < picker,
                  "#{m}: brana musi padnut PRED vyberom suboru/priecinka")
  end
  NxTest.assert(s.include?('drawer_stop(collected, hw_exp, scope: :kit)'),
                'VEPO ma branu LEN na chybajuci kit')
end

# ============================================================================
# NAKUP — POVYSENIE NA RED
# ============================================================================

NxTest.test('KOV-C2b: receptova polozka bez triedneho mapovania = RED, NIKDY `slide`') do
  c = NxC2bB
  state = { 'mapping' => { 'slide' => 'vysuv-atira-biela-h70' },
            'sets' => { 'vysuv-atira-biela-h70' => { 'set_id' => 'vysuv-atira-biela-h70',
                                                     'generic_type' => 'slide', 'members' => [] } } }
  exp = c::HWS.expand([c.recipe_item], state)
  NxTest.assert_equal([], exp['rows'], 'H70 kit „len tak" sa neobjedna')
  u = exp['unmapped'].first
  NxTest.assert_equal(['drawer_kit_missing', 'class_unmapped'], [u['reason'], u['base_reason']])
  NxTest.assert_equal('atira', u['system'])
  NxTest.assert_close(70.0, u['height_variant'], 0.001)
  # Legacy polozka toho isteho typu ostava ORANGE a mapuje sa ako doteraz.
  lg = c::HWS.expand([c.legacy_item], state)
  NxTest.assert_equal([], lg['unmapped'], 'legacy vysuv sa namapoval cez genericky `slide`')
end

NxTest.test('KOV-C2b: RED riadok Kontroly menuje celo, system, vysku, NL aj dovod') do
  c = NxC2bB
  exp = c.expansion([{ 'cabinet_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
                       'generic_type' => 'slide', 'rule_id' => 'recipe:atira_sisy_v1',
                       'set_id' => 'atira-biela-h70-sisy', 'reason' => 'drawer_kit_missing',
                       'base_reason' => 'nl_missing', 'nominal_length' => 470.0,
                       'system' => 'atira', 'height_variant' => 70.0 }])
  items = c::VAL.run({ records: [], cabinets: 1 }, hardware_expansion: exp)['items']
  NxTest.assert_equal(1, items.length)
  it = items.first
  NxTest.assert_equal(['red', 'drawer_kit'], [it['severity'], it['category']])
  %w[CAB-1 Atira H70 470 kód VEPO].each do |needle|
    NxTest.assert(it['message_sk'].include?(needle), "chyba #{needle} vo vete: #{it['message_sk']}")
  end
  NxTest.assert_equal('front:F1/panel', it['part_key'])
end

NxTest.test('KOV-C2b: zamknuta receptova polozka nesie v nakupe znamienko rucneho zasahu') do
  c = NxC2bB
  row = {}
  c::HWS.note_manual(row, c.recipe_item('locked' => true), 1)
  NxTest.assert_equal(1, row['manual_quantity'])
  plain = {}
  c::HWS.note_manual(plain, c.recipe_item, 1)
  NxTest.assert_equal({}, plain, 'bez zamku ziadne znamienko')
end

# ============================================================================
# R4 — ULOZENY NOSIC KONFLIKTOV (config round-trip)
# ============================================================================

NxTest.test('KOV-C2b (R4): `drawer_conflicts` prezije config a vrati sa do Kontroly') do
  c = NxC2bB
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 250.0,
                        'fronts' => { 'items' => [{ 'type' => 'drawer_front', 'mode' => 'fixed',
                                                    'height' => 175.0, 'opening_mode' => 'classic',
                                                    'drawer' => { 'construction' => 'metal' } }] })
  plan = c::CN.build_plan(cfg, 'CAB-1')
  merged = c::CB.merge_final(cfg, plan)
  stored = c::CB.cabinet_config(merged)
  NxTest.assert_equal(1, stored[:drawer_conflicts].length, 'nosic je v ULOZENOM configu')
  NxTest.assert_equal('drawer_no_fit', stored[:drawer_conflicts].first['code'])
  # JSON round-trip (tak zije config v .skp) nesmie tvar zmenit.
  round = JSON.parse(JSON.generate(stored[:drawer_conflicts]))
  issues = c::E::Bom.drawer_conflict_issues('CAB-1', 42, round, [])
  NxTest.assert_equal(['drawer_no_fit'], issues.map { |i| i['code'] })
  NxTest.assert_equal(42, issues.first['owner_pid'])
  items = c::VAL.run({ records: [], cabinets: 1, hardware_issues: issues })['items']
  NxTest.assert_equal(['red', 'drawer'], [items.first['severity'], items.first['category']])
  NxTest.assert(items.first['message_sk'].include?('hĺbka'), items.first['message_sk'])
end

NxTest.test('KOV-C2b (R4): neznamy kod v ulozenom nosici sa PRESKOCI (config z novsej verzie)') do
  c = NxC2bB
  issues = c::E::Bom.drawer_conflict_issues('CAB-1', 1,
                                            [{ 'code' => 'drawer_future', 'front_id' => 'F1',
                                               'message' => 'x' }], [])
  NxTest.assert_equal([], issues)
end

# ============================================================================
# R6 — SCHEMA 5 A SERVEROVE POLIA
# ============================================================================

NxTest.test('KOV-C2b (R6): CONFIG_SCHEMA je 5 a forward guard odmietne novsi config') do
  c = NxC2bB
  NxTest.assert_equal(5, c::CB::CONFIG_SCHEMA)
  NxTest.refute(c::CB.newer_config?('config_schema' => 5), 'aktualna schema prejde')
  NxTest.assert(c::CB.newer_config?('config_schema' => 6), 'novsia sa odmietne')
  NxTest.refute(c::CB.newer_config?('config_schema' => 4), 'starsia je kompatibilna')
  # Downgrade: starsi plugin (schema 4) taku zakazku PRESTAVAT nesmie — a to je
  # jediny sposob, ako by z nej mohol ticho odobrat dielce zasuviek.
  inst = NxTest::FakeEntity.new
  inst.set_attribute(c::E::Store::DICT, 'config', JSON.generate('config_schema' => 6))
  NxTest.assert_raise(/novšej verzie/) { c::CB.guard_newer_config!(inst) }
end

NxTest.test('KOV-C2b (R6): `recipe_refs` a `system` prezitu normalizaciu BEZSTRATOVO') do
  c = NxC2bB
  raw = { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                        'height' => 175.0, 'opening_mode' => 'classic',
                        'drawer' => { 'construction' => 'metal', 'system' => 'atira',
                                      'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1',
                                                         'atira|p2o' => 'atira_p2o_v1',
                                                         'zly|kluc' => 'atira_sisy_v1',
                                                         'atira|sisy2' => 'x' } } }] }
  out = c::FR.normalize_config(raw)
  d = out['items'].first['drawer']
  NxTest.assert_equal('atira', d['system'])
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1', 'atira|p2o' => 'atira_p2o_v1' },
                      d['recipe_refs'], 'neplatne kluce/hodnoty vypadnu, platne ZOSTANU')
  # Druhy prechod nic nezmeni (idempotencia = prestavba ref nestrati).
  NxTest.assert_equal(d, c::FR.normalize_config(out)['items'].first['drawer'])
  # NEREGISTROVANY, ale tvarovo platny ref PREZIJE — inak by sa stav
  # `drawer_recipe_unknown` nikdy nedosiahol a starsi plugin by ticho pripol iny.
  unknown = c::FR.normalize_config('items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                                 'drawer' => { 'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v9' } } }])
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v9' },
                      unknown['items'].first['drawer']['recipe_refs'])
end

NxTest.test('KOV-C2b (R6): serverove polia — forged payload ulozenu mapu NEZMENI') do
  c = NxC2bB
  saved = c::FR.normalize_config('items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                               'mode' => 'fixed', 'height' => 175.0,
                                               'opening_mode' => 'classic',
                                               'drawer' => { 'construction' => 'metal',
                                                             'system' => 'atira',
                                                             'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } } }])
  forged = { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                           'height' => 175.0, 'opening_mode' => 'classic',
                           'drawer' => { 'construction' => 'metal', 'system' => 'quadro_v6',
                                         'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v9' } } }] }
  out = c::FR.reattach_server_drawer_fields(forged, saved)
  d = out['items'].first['drawer']
  NxTest.assert_equal('metal', d['construction'], 'klientska KLASIFIKACIA sa berie')
  NxTest.assert_equal('atira', d['system'], 'system je serverovy — podvrh sa zahodil')
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1' }, d['recipe_refs'])
  # Celo s NOVYM ID mapu nema (dostane ju az od servera pri prestavbe).
  fresh = { 'items' => [{ 'id' => 'F9', 'type' => 'drawer_front', 'mode' => 'fixed',
                          'height' => 175.0,
                          'drawer' => { 'construction' => 'metal',
                                        'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v9' } } }] }
  NxTest.assert_equal({ 'construction' => 'metal' },
                      c::FR.reattach_server_drawer_fields(fresh, saved)['items'].first['drawer'])
end

NxTest.test('KOV-C2b (R6): prestavba doplni CHYBAJUCE, ale UZ PRIPNUTE nikdy neprepise') do
  c = NxC2bB
  cfg = c::FR.normalize_config('items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                             'drawer' => { 'construction' => 'metal' } }])
  NxTest.assert(c::FR.write_drawer_fields!(cfg, [{ 'front_id' => 'F1', 'system' => 'atira',
                                                   'ref_key' => 'atira|sisy',
                                                   'recipe_id' => 'atira_sisy_v1' }]))
  NxTest.assert_equal({ 'construction' => 'metal', 'system' => 'atira',
                        'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } },
                      cfg['items'].first['drawer'])
  # Druhy zapis inej verzie sa IGNORUJE — zmena verzie je vyhradne akcia KOV-D.
  NxTest.refute(c::FR.write_drawer_fields!(cfg, [{ 'front_id' => 'F1', 'system' => 'quadro_v6',
                                                   'ref_key' => 'atira|sisy',
                                                   'recipe_id' => 'atira_sisy_v2' }]))
  NxTest.assert_equal('atira_sisy_v1', cfg['items'].first['drawer']['recipe_refs']['atira|sisy'])
end

NxTest.test('KOV-C2b (R6): PRVA stavba zapise ref do configu AJ do projekcie `front_items`') do
  c = NxC2bB
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                                    'mode' => 'fixed', 'height' => 175.0,
                                                    'opening_mode' => 'classic',
                                                    'drawer' => { 'construction' => 'metal' } }] })
  plan = c::CN.build_plan(cfg, 'CAB-1')
  out = c::CB.apply_drawer_writes(cfg, plan)
  want = { 'construction' => 'metal', 'system' => 'atira',
           'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } }
  NxTest.assert_equal(want, out[:fronts]['items'].first['drawer'], 'config ciel')
  stored = c::CB.cabinet_config(c::CB.merge_final(out, plan))
  NxTest.assert_equal(want, stored[:front_items].first['drawer'],
                      'projekcia `front_items` musi sediet UZ pri prvej stavbe')
  NxTest.assert_equal(want, stored[:fronts]['items'].first['drawer'])
end

NxTest.test('KOV-C2b (R6): navrat SiSy -> Tip-On -> SiSy vrati POVODNY pripnuty recept') do
  c = NxC2bB
  base = { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
           'drawer' => { 'construction' => 'metal' } }
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [base.merge('opening_mode' => 'classic')] })
  p1 = c::CN.build_plan(cfg, 'CAB-1')
  cfg = c::CB.apply_drawer_writes(cfg, p1)
  # prepnutie na Tip-On
  items = cfg[:fronts]['items'].map { |i| i.merge('opening_mode' => 'tipon') }
  cfg2 = cfg.merge(fronts: cfg[:fronts].merge('items' => items))
  cfg2 = c::CB.apply_drawer_writes(cfg2, c::CN.build_plan(cfg2, 'CAB-1'))
  refs = cfg2[:fronts]['items'].first['drawer']['recipe_refs']
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1', 'atira|p2o' => 'atira_p2o_v1' }, refs)
  # a spat na SiSy — mapa sa uz NEMENI
  items3 = cfg2[:fronts]['items'].map { |i| i.merge('opening_mode' => 'classic') }
  cfg3 = cfg2.merge(fronts: cfg2[:fronts].merge('items' => items3))
  cfg3 = c::CB.apply_drawer_writes(cfg3, c::CN.build_plan(cfg3, 'CAB-1'))
  NxTest.assert_equal(refs, cfg3[:fronts]['items'].first['drawer']['recipe_refs'])
end

NxTest.test('KOV-C2b (R6): sablona a cabinet_config prenesu `drawer_material_id` aj refs') do
  c = NxC2bB
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                        'drawer_material_id' => 'REALNY_16',
                        'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                                    'mode' => 'fixed', 'height' => 175.0,
                                                    'opening_mode' => 'classic',
                                                    'drawer' => { 'construction' => 'metal',
                                                                  'system' => 'atira',
                                                                  'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } } }] })
  NxTest.assert_equal('REALNY_16', cfg[:drawer_material_id], 'normalize kluc pozna')
  stored = c::CB.cabinet_config(cfg)
  NxTest.assert_equal('REALNY_16', stored[:drawer_material_id])
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1' },
                      stored[:fronts]['items'].first['drawer']['recipe_refs'])
  # config -> params -> config (kazdy rebuild zo stored configu)
  back = c::CB.normalize(c::CB.config_to_params(JSON.parse(JSON.generate(stored))))
  NxTest.assert_equal('REALNY_16', back[:drawer_material_id])
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1' },
                      back[:fronts]['items'].first['drawer']['recipe_refs'])
end

NxTest.test('KOV-C2b: `human_label` pozna vsetky styri dielce zasuvky') do
  pk = Noxun::Engine::PartKeys
  fronts = [{ 'id' => 'F1', 'type' => 'drawer_front' }]
  NxTest.assert_equal('F1 · dno zásuvky', pk.human_label('front:F1/drawer_bottom', fronts: fronts))
  NxTest.assert_equal('F1 · chrbát zásuvky', pk.human_label('front:F1/drawer_back', fronts: fronts))
  NxTest.assert_equal('F1 · vnútorné čelo zásuvky',
                      pk.human_label('front:F1/drawer_inner_front', fronts: fronts))
  NxTest.assert_equal('F1 · bok boxu ľavý', pk.human_label('front:F1/box_side:left', fronts: fronts))
  NxTest.assert_equal('F1 · bok boxu pravý', pk.human_label('front:F1/box_side:right', fronts: fronts))
  NxTest.assert_equal(1, Noxun::Engine::PartKeys::SCHEMA, 'part_key schema sa NEBUMPUJE')
end

# ============================================================================
# CHARAKTERIZACIA — ZAKAZKA BEZ KLASIFIKACIE SA NEZMENILA
# ============================================================================

NxTest.test('KOV-C2b: zakazka BEZ klasifikacie zasuvky je CONTENT-identicka') do
  c = NxC2bB
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [
                          { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0 },
                          { 'type' => 'door', 'mode' => 'auto' }
                        ] })
  pl = c::CN.build_plan(cfg, 'CAB-1')
  NxTest.assert_equal([], pl[:parts].select { |p| p[:material] == :drawer })
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]))
  NxTest.assert_equal([], Array(pl[:drawer_writes]))
  NxTest.refute(pl[:warnings].any? { |w| w['code'].to_s.start_with?('drawer_') ||
                                         w['code'] == 'legacy_slide_suppressed' })
  # Kovanie ostava z PRAVIDIEL a ziadna polozka nema `source: recipe`.
  NxTest.assert_equal([], pl[:hardware].select { |h| h['source'] == 'recipe' })
  NxTest.assert(pl[:hardware].any? { |h| h['rule_id'] == 'vysuvy-nl-podla-hlbky' },
                'legacy vysuv sa stale vydava')
  # Ulozeny config nesie nove kluce PRAZDNE (aditivne, ziadna zmena obsahu).
  stored = c::CB.cabinet_config(c::CB.merge_final(cfg, pl))
  NxTest.assert_equal([], stored[:drawer_conflicts])
  NxTest.assert_equal(nil, stored[:drawer_material_id])
end

NxTest.test('KOV-C2b: nemapovane dovody poloziek Z PRAVIDIEL ostavaju ORANGE') do
  c = NxC2bB
  exp = c.expansion([{ 'cabinet_id' => 'CAB-1', 'generic_type' => 'slide',
                       'owner_part_key' => 'front:F1/panel', 'rule_id' => 'vysuvy-nl-podla-hlbky',
                       'set_id' => 's1', 'reason' => 'nl_missing', 'nominal_length' => 419.6 }])
  items = c::VAL.run({ records: [], cabinets: 1 }, hardware_expansion: exp)['items']
  NxTest.assert_equal(['orange', 'hardware_unmapped'],
                      [items.first['severity'], items.first['category']])
end

# ============================================================================
# CODEX #304 KOLO 1 — opravy
# ============================================================================

NxTest.test('Codex #304 P1: zmena konstrukcie NEPRIPINA stary `system` (metal <-> wood)') do
  c = NxC2bB
  base = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
           'opening_mode' => 'classic' }
  saved = c::FR.normalize_config('items' => [base.merge(
    'drawer' => { 'construction' => 'metal', 'system' => 'atira',
                  'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } }
  )])
  # Pouzivatel prepol konstrukciu na drevo (system panel NEPOSIELA).
  wood = { 'items' => [base.merge('drawer' => { 'construction' => 'wood' })] }
  out = c::FR.reattach_server_drawer_fields(wood, saved)
  d = out['items'].first['drawer']
  NxTest.assert_equal(nil, d['system'], 'stary `system` by celo natrvalo zablokoval ako RED')
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1' }, d['recipe_refs'],
                      'mapa je klucovana system|otvaranie — pripina sa VZDY')
  # Stavba nad novou konstrukciou = Quadro, a doplni si vlastny zaznam.
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => out)
  cfg = c::CB.apply_drawer_writes(cfg, c::CN.build_plan(cfg, 'CAB-1'))
  d2 = cfg[:fronts]['items'].first['drawer']
  NxTest.assert_equal('quadro_v6', d2['system'])
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1',
                        'quadro_v6|sisy' => 'quadro_v6_sisy_v1' }, d2['recipe_refs'])
  # Navrat na kov vrati POVODNY pripnuty recept Atiry.
  back = { 'items' => [base.merge('drawer' => { 'construction' => 'metal' })] }
  out2 = c::FR.reattach_server_drawer_fields(back, cfg[:fronts])
  cfg2 = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0, 'fronts' => out2)
  cfg2 = c::CB.apply_drawer_writes(cfg2, c::CN.build_plan(cfg2, 'CAB-1'))
  d3 = cfg2[:fronts]['items'].first['drawer']
  NxTest.assert_equal('atira', d3['system'])
  NxTest.assert_equal('atira_sisy_v1', d3['recipe_refs']['atira|sisy'], 'povodna verzia ostala')
end

NxTest.test('Codex #304 P1: NEZMENENA konstrukcia si ulozeny `system` PONECHA') do
  c = NxC2bB
  item = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
           'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
  saved = c::FR.normalize_config('items' => [item.merge(
    'drawer' => { 'construction' => 'metal', 'system' => 'atira' }
  )])
  out = c::FR.reattach_server_drawer_fields({ 'items' => [item] }, saved)
  NxTest.assert_equal('atira', out['items'].first['drawer']['system'])
end

NxTest.test('Codex #304 P2: `recipe_refs` zaznam s NESEDIACIM klucom sa ZAHODI') do
  c = NxC2bB
  cfg = c::FR.normalize_config('items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                             'drawer' => { 'construction' => 'metal',
                                                           'recipe_refs' => {
                                                             'atira|sisy' => 'quadro_v6_p2o_v1',
                                                             'atira|p2o' => 'atira_p2o_v1'
                                                           } } }])
  NxTest.assert_equal({ 'atira|p2o' => 'atira_p2o_v1' },
                      cfg['items'].first['drawer']['recipe_refs'],
                      'kluc a recept musia hovorit o TOM ISTOM systeme aj otvarani')
  # A stavba potom pouzije SPRAVNY recept (stav `missing` -> surodenec/latest).
  full = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                         'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                                     'mode' => 'fixed', 'height' => 175.0,
                                                     'opening_mode' => 'classic',
                                                     'drawer' => { 'construction' => 'metal',
                                                                   'recipe_refs' => { 'atira|sisy' => 'quadro_v6_p2o_v1' } } }] })
  pl = c::CN.build_plan(full, 'CAB-1')
  NxTest.assert_equal([], Array(pl[:drawer_conflicts]), pl[:drawer_conflicts].inspect)
  NxTest.assert_equal('recipe:atira_sisy_v1',
                      pl[:hardware].find { |h| h['generic_type'] == 'slide' }['rule_id'],
                      'NIKDY cudzi recept')
end

NxTest.test('Codex #304 P1: sablona nesie `drawer_material_id` preserve-or-override') do
  c = NxC2bB
  target = { 'drawer_material_id' => 'MOJ_16', 'material_id' => 'TELO' }
  # LEGACY sablona (kluc NEMA) override skrinky NEZMAZE.
  legacy = c::E::TemplatesDialog.merge_template(target, { 'type' => 'lower' })
  NxTest.assert_equal('MOJ_16', legacy['drawer_material_id'])
  # Sablona s klucom ho PREPISE.
  withkey = c::E::TemplatesDialog.merge_template(target, { 'type' => 'lower',
                                                           'drawer_material_id' => 'SABLONA_18' })
  NxTest.assert_equal('SABLONA_18', withkey['drawer_material_id'])
end

NxTest.test('Codex #304 P2: delete guard rata `drawer_material_id` (skrinky aj sablony)') do
  c = NxC2bB
  NxTest.assert_equal(%w[material_id front_material_id back_material_id drawer_material_id],
                      c::E::Materials::CABINET_MATERIAL_KEYS,
                      'jeden zoznam pre model AJ sablony')
  used = Hash.new { |h, k| h[k] = [] }
  # Priama kontrola zbernej slucky nad sablonovym configom (bez TemplateStore).
  cfg = { 'drawer_material_id' => 'ZASUVKA_16' }
  c::E::Materials::CABINET_MATERIAL_KEYS.each do |k|
    v = cfg[k]
    used[v.to_s] << 'x' if v && !v.to_s.empty?
  end
  NxTest.assert_equal(['x'], used['ZASUVKA_16'], 'referencia sa zapocita')
end

# --- MIGRACNY kod `drawer_stale` -------------------------------------------

module NxC2bB
  module_function

  # Ulozeny config skrinky s danou schemou a (ne)klasifikovanou zasuvkou.
  # `over` = polia RESOLVED cela; LEGACY celo nesmie niest ZIADNE drawer pole
  # (ani `opening_mode`) — presne to je hranica `Recipes.classified?`.
  # Params skrinky tak, ako ich cita produkcia: normalize -> cabinet_config ->
  # JSON (model) -> config_to_params.
  def stored_params(over = {})
    cfg = CB.normalize({ 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0 }.merge(over))
    CB.config_to_params(JSON.parse(JSON.generate(CB.cabinet_config(cfg))))
  end

  def stale_cfg(schema, construction, over = {})
    item = { 'id' => 'F1', 'type' => 'drawer_front', 'height' => 175.0 }
    if construction
      item['opening_mode'] = 'classic'
      item['drawer'] = { 'construction' => construction }
    end
    { 'config_schema' => schema, 'front_items' => [item.merge(over)] }
  end
end

NxTest.test('Codex #304 P1: schema < 5 s klasifikovanou zasuvkou = RED `drawer_stale`') do
  c = NxC2bB
  iss = c::E::Bom.drawer_stale_issue('CAB-1', 7, c.stale_cfg(4, 'metal'))
  NxTest.assert_equal('drawer_stale', iss && iss['code'])
  NxTest.assert_equal(['red', 'CAB-1', 7, 'front:F1/panel'],
                      [iss['severity'], iss['owner_id'], iss['owner_pid'], iss['part_key']])
  NxTest.assert(iss['message'].include?('prestav'), iss['message'])
  # Aj legacy config BEZ markera (0) — klasifikacia existuje od schemy 2.
  NxTest.assert(c::E::Bom.drawer_stale_issue('CAB-1', 1, c.stale_cfg(0, 'wood')))
  # Schema 5 (uz prestavana) = ziadny nalez.
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 1, c.stale_cfg(5, 'metal')))
  # LEGACY zasuvka na schéme 4 (ZIADNE drawer pole) = ziadny nalez.
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 1, c.stale_cfg(4, nil)))
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 1, c.stale_cfg(4, 'other')),
                      'konstrukcia `other` ide legacy cestou aj po aktivacii')
end

NxTest.test('Codex #304 kolo 3 P1: CIASTOCNA klasifikacia na schéme 4 je tiez `drawer_stale`') do
  c = NxC2bB
  # LEN `opening_mode` (bez konstrukcie) — po prestavbe skonci `drawer_unclassified`,
  # takze pred nou nesmie byt zelena.
  half = c.stale_cfg(4, nil, 'opening_mode' => 'classic')
  NxTest.assert_equal('drawer_stale', c::E::Bom.drawer_stale_issue('CAB-1', 1, half)&.dig('code'),
                      'celo s polovicnou klasifikaciou branou prejst nesmie')
  # LEN `variant internal` — po prestavbe `drawer_internal_unsupported`.
  internal = c.stale_cfg(4, nil, 'drawer' => { 'variant' => 'internal' })
  NxTest.assert_equal('drawer_stale',
                      c::E::Bom.drawer_stale_issue('CAB-1', 1, internal)&.dig('code'),
                      'vnutorna zasuvka branou prejst nesmie')
  # Predikat je JEDEN — `Bom` aj `Recipes` hovoria to iste.
  NxTest.assert(c::REC.classified?(half['front_items'].first))
  NxTest.assert(c::REC.classified?(internal['front_items'].first))
  NxTest.refute(c::REC.classified?(c.stale_cfg(4, nil)['front_items'].first))
  NxTest.refute(c::REC.classified?(c.stale_cfg(4, 'other')['front_items'].first))
  NxTest.refute(c::REC.classified?('id' => 'F2', 'type' => 'door'), 'dvierka nikdy')
  # Po prestavbe (schema 5) su oba stavy zelene z pohladu MIGRACNEJ brany
  # (vlastny RED uz dava resolver).
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 1,
                                                        half.merge('config_schema' => 5)))
end

NxTest.test('Codex #304 P1: `drawer_stale` je RED v Kontrole a blokuje VSETKY exporty') do
  c = NxC2bB
  iss = c::E::Bom.drawer_stale_issue('CAB-1', 7, c.stale_cfg(4, 'metal'))
  items = c::VAL.run({ records: [], cabinets: 1, hardware_issues: [iss] })['items']
  NxTest.assert_equal(['red', 'drawer'], [items.first['severity'], items.first['category']])
  NxTest.assert(items.first['message_sk'].include?('neprestavíš'), items.first['message_sk'])
  collected = { hardware_issues: [iss], hardware: [] }
  %i[all kit].each do |scope|
    out = c::PC.drawer_blockers(collected, c.expansion([]), scope: scope)
    NxTest.assert_equal(1, out.length, "#{scope}: migracny kod zastavuje (aj VEPO)")
    NxTest.assert(out.first.include?('CAB-1'))
  end
  # Po prestavbe (schema 5) je zelene.
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 7, c.stale_cfg(5, 'metal')))
end

# --- UI 4. materialoveho kanala + preflight per system ----------------------

NxTest.test('Codex #304 P1: `TARGETS` pozna 4. kanal a JS mapovanie s nim sedi') do
  c = NxC2bB
  md = c::E::MaterialsDialog
  NxTest.assert_equal(%w[default_material_id default_front_material_id
                         default_back_material_id default_drawer_material_id].sort,
                      md::TARGETS.keys.sort)
  NxTest.assert_equal(['drawer_material_id', 'drawer_bottom', nil],
                      md::TARGETS['default_drawer_material_id'])
  # Kazdy kluc TARGETS musi mat riadok v Studiu aj v JS mape (inak by sa dal
  # nastavit len z konzoly, alebo by select po ponuke ostal na nepotvrdenom).
  html = c.src_ui('studio.html')
  js = c.src_ui(File.join('js', 'proj_materials.js'))
  md::TARGETS.each_key do |key|
    NxTest.assert(html.include?("onProjMaterial('#{key}'"), "#{key}: chyba riadok v Studiu")
    NxTest.assert(js.include?("#{key}: 'md_"), "#{key}: chyba v JS mape selectov")
  end
  NxTest.assert(html.include?('id="md_drawer"'), 'riadok „Zásuvky" v predvolbach projektu')
end

NxTest.test('Codex #304 P1: povolene hrubky su Z RECEPTU (Atira 16, Quadro 16/18)') do
  c = NxC2bB
  NxTest.assert_equal([16.0], c::REC.supported_thicknesses('atira'))
  NxTest.assert_equal([16.0, 18.0], c::REC.supported_thicknesses('quadro_v6'))
  NxTest.assert_equal([], c::REC.supported_thicknesses('antaro'), 'neznamy system = ziadna hrubka')
  NxTest.assert(c::REC.thickness_ok_for_system?('atira', 16.0))
  NxTest.refute(c::REC.thickness_ok_for_system?('atira', 18.0), 'Atira 18 mm neprijme')
  NxTest.assert(c::REC.thickness_ok_for_system?('quadro_v6', 18.0))
  NxTest.refute(c::REC.thickness_ok_for_system?('quadro_v6', 25.0))
end

NxTest.test('Codex #304 P1: preflight predvolby zasuviek menuje SYSTEM aj skrinky') do
  c = NxC2bB
  md = c::E::MaterialsDialog
  # Doska, ktoru neprijme ZIADEN system, sa neulozi vobec (ziadna ponuka).
  NxTest.refute(md.drawer_thickness_any_system?(25.0))
  NxTest.assert(md.drawer_thickness_any_system?(16.0))
  NxTest.assert(md.drawer_thickness_any_system?(18.0), 'Quadro 18 prijme')
  msg = md.drawer_reject_msg(25.0)
  NxTest.assert(msg.include?('16') && msg.include?('18'), msg)
  # Systemy skrinky sa citaju z ULOZENYCH ciel (legacy celo sa netyka).
  params = { 'fronts' => { 'items' => [
    { 'id' => 'F1', 'type' => 'drawer_front', 'opening_mode' => 'classic',
      'drawer' => { 'construction' => 'metal' } },
    { 'id' => 'F2', 'type' => 'drawer_front', 'opening_mode' => 'classic',
      'drawer' => { 'construction' => 'wood' } },
    { 'id' => 'F3', 'type' => 'door' }
  ] } }
  NxTest.assert_equal(%w[atira quadro_v6], md.drawer_systems_of(params).sort)
  NxTest.assert_equal([], md.drawer_systems_of('fronts' => { 'items' => [{ 'type' => 'door' }] }))
  # Veta ponuky menuje system AJ povolene hrubky.
  txt = md.drawer_systems_txt(['atira'])
  NxTest.assert(txt.include?('Atira') && txt.include?('16'), txt)
end

# ============================================================================
# CODEX #304 KOLO 3 — propagacia `drawer_material_id`
# ============================================================================

NxTest.test('Codex #304 kolo 3 P1: vkladaci stav nesie `drawer_material_id`') do
  c = NxC2bB
  js = c.src_ui(File.join('js', 'insert_state.js'))
  # JS kanal (zrkadlo serveroveho `normalize`) musi poznat VSETKY styri kanaly.
  NxTest.assert(js.include?("'drawer_material_id'"),
                'MATERIAL_KEYS bez 4. kanala = vlozena skrinka spadne na projektovu predvolbu')
  # Server: `normalize` kluc pozna, takze `build` z insert payloadu ho ulozi.
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                        'drawer_material_id' => 'ZO_SABLONY_18')
  NxTest.assert_equal('ZO_SABLONY_18', cfg[:drawer_material_id])
  NxTest.assert_equal('ZO_SABLONY_18', c::CB.cabinet_config(cfg)[:drawer_material_id])
  # A round-trip cez ULOZENY config (sablona -> vklad -> prestavba).
  back = c::CB.normalize(c::CB.config_to_params(JSON.parse(JSON.generate(c::CB.cabinet_config(cfg)))))
  NxTest.assert_equal('ZO_SABLONY_18', back[:drawer_material_id])
  # Prazdna hodnota = dedi z projektu (ziadny tichy default).
  NxTest.assert_equal(nil, c::CB.normalize('drawer_material_id' => '')[:drawer_material_id])
end

NxTest.test('Codex #304 kolo 3 P1: „Nahradiť UNI…" pozna 4. kanal') do
  c = NxC2bB
  ru = c::E::Materials
  NxTest.assert_equal('drawer', ru::RU_CAB_KEYS['drawer_material_id'])
  NxTest.assert_equal('default_drawer_material_id', ru.ru_project_key_for('drawer'))
  # Skrinka s EXPLICITNYM materialom zasuviek na UNI + skrinka, ktora kanal DEDI.
  uni = { 'material_id' => 'UNI_ZASUVKA_16', 'thickness' => 16.0, 'decor' => 'UNI' }
  target = { 'material_id' => 'BIELA_16', 'thickness' => 16.0, 'decor' => 'Biela' }
  # `cabinet_config` vracia SYMBOLOVE kluce; do modelu ide cez JSON, takze
  # `config_to_params` (a s nim cely `replace_uni`) cita STRINGY — round-trip
  # je preto sucast testu, nie kozmetika.
  explicit = c.stored_params('drawer_material_id' => 'UNI_ZASUVKA_16')
  inherit = c.stored_params
  eff_uni = { 'body' => 'K', 'front' => 'K', 'back' => 'K', 'drawer' => 'UNI_ZASUVKA_16' }
  scan = { 'cabs' => [['CAB-1', explicit, eff_uni, '{}', :ref1],
                      ['CAB-2', inherit, eff_uni, '{}', :ref2]],
           'boards' => [], 'model_guid' => 'G',
           'project' => { 'default_drawer_material_id' => 'UNI_ZASUVKA_16' } }
  out = ru.replace_uni_classify(scan, uni, target)
  NxTest.assert_equal({ 'default_drawer_material_id' => 'BIELA_16' }, out['project_writes'])
  NxTest.assert_equal(%w[CAB-1 CAB-2], out['recompute'].sort,
                      'explicitna AJ dediaca skrinka dostanu rebuild job')
  NxTest.assert_equal('BIELA_16', explicit['drawer_material_id'], 'explicitny kluc sa prepisal')
  NxTest.assert_equal([], out['blocked'], out['blocked'].inspect)
end

NxTest.test('Codex #304 kolo 3 P2: „Nahradiť UNI…" pouziva RECEPTOVY predikat') do
  c = NxC2bB
  ru = c::E::Materials
  # 25 mm doskou sa dielce zasuviek nedaju vyrobit (Atira 16, Quadro 16/18) —
  # ten isty predikat ako selektor v Studiu.
  NxTest.assert_equal(:drawer, ru.ru_project_target_issue('default_drawer_material_id', 25.0))
  NxTest.assert_equal(nil, ru.ru_project_target_issue('default_drawer_material_id', 16.0))
  NxTest.assert_equal(nil, ru.ru_project_target_issue('default_drawer_material_id', 18.0))
  NxTest.assert_equal(c::E::MaterialsDialog.drawer_thickness_any_system?(25.0),
                      ru.ru_project_target_issue('default_drawer_material_id', 25.0).nil?,
                      'JEDEN predikat pre obe cesty')
  # A skrinka s dielcami zasuviek sa na taku dosku nenahradi (blokovana).
  uni = { 'material_id' => 'UNI_ZASUVKA_16', 'thickness' => 16.0, 'decor' => 'UNI' }
  fat = { 'material_id' => 'DOSKA_25', 'thickness' => 25.0, 'decor' => 'Hruba' }
  params = c.stored_params('drawer_material_id' => 'UNI_ZASUVKA_16')
  scan = { 'cabs' => [['CAB-1', params, { 'drawer' => 'UNI_ZASUVKA_16' }, '{}', :ref]],
           'boards' => [], 'model_guid' => 'G', 'project' => {} }
  out = ru.replace_uni_classify(scan, uni, fat)
  NxTest.assert_equal([], out['jobs_cab'], 'ziadny job')
  NxTest.assert_equal(:drawer, out['blocked'].first && out['blocked'].first[1])
  NxTest.assert(ru.ru_blocked_line('CAB-1', :drawer, []).include?('zásuviek'),
                ru.ru_blocked_line('CAB-1', :drawer, []))
end
