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

# UI vrstva (brany exportov) — headless nie je v require zozname helpera.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
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
end

# ============================================================================
# R4 — REGISTER BRAN
# ============================================================================

NxTest.test('KOV-C2b (R4): register ma 10 kodov a delí sa na stavbu (9) + nakup (1)') do
  c = NxC2bB
  NxTest.assert_equal(10, c::REC::DRAWER_BLOCKERS.length)
  NxTest.assert_equal(c::REC::CONFLICT_CODES, c::REC::DRAWER_BLOCKERS,
                      'register JE zoznam kodov konfliktov — ziadna druha kopia')
  NxTest.assert_equal(9, c::REC::BUILD_BLOCKERS.length)
  NxTest.assert_equal('drawer_kit_missing', c::REC::KIT_MISSING)
  NxTest.refute(c::REC::BUILD_BLOCKERS.include?(c::REC::KIT_MISSING))
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
