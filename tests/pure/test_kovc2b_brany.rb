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

# UI vrstva (brany exportov + sablony) — headless nie je v require zozname
# helpera, takze si ju sada pyta sama (vzor `test_kovc2a_kanal_sety.rb`).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
end

# Hrubky VSETKYCH roli jedneho cela + bodova zmena (vstup `build_plan`).
NxC2bD_TH = lambda do |over = {}|
  Noxun::Engine::CabinetBuilder::DRAWER_ROLES.each_with_object({}) do |role, acc|
    acc[Noxun::Engine::PartKeys.front('F1', role)] = 16.0
  end.merge(over)
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

  # Zasuvkove celo danej konstrukcie (metal -> Atira, wood -> Quadro V6).
  def drawer_front(construction = 'metal', id = 'F1')
    { 'id' => id, 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
      'opening_mode' => 'classic', 'drawer' => { 'construction' => construction } }
  end

  def stored_params_with(construction, over = {})
    stored_params({ 'fronts' => { 'items' => [drawer_front(construction)] } }.merge(over))
  end

  # Params skrinky tak, ako ich cita produkcia: normalize -> cabinet_config ->
  # JSON (model) -> config_to_params.
  def stored_params(over = {})
    cfg = CB.normalize({ 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0 }.merge(over))
    CB.config_to_params(JSON.parse(JSON.generate(CB.cabinet_config(cfg))))
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

NxTest.test('KOV-C2b (R6): aktivacia zasuviek je na schéme 5 a forward guard odmietne novsi config') do
  c = NxC2bB
  # KOV-D1a: `CONFIG_SCHEMA` sa medzitym posunula na 6 (owner triedny kluc).
  # C2b strazi VLASTNU konstantu — aktivacia receptov ostava na 5, inak by sa
  # kazda skrinka schemy 5 zrazu tvarila ako nemigrovana (`drawer_stale`).
  NxTest.assert_equal(5, c::CB::DRAWER_ACTIVATION_SCHEMA)
  cur = c::CB::CONFIG_SCHEMA
  NxTest.assert(cur >= 5, 'aktualna schema nikdy neklesne pod aktivaciu zasuviek')
  NxTest.refute(c::CB.newer_config?('config_schema' => cur), 'aktualna schema prejde')
  NxTest.assert(c::CB.newer_config?('config_schema' => cur + 1), 'novsia sa odmietne')
  NxTest.refute(c::CB.newer_config?('config_schema' => cur - 1), 'starsia je kompatibilna')
  # Downgrade: starsi plugin taku zakazku PRESTAVAT nesmie — a to je jediny
  # sposob, ako by z nej mohol ticho odobrat dielce zasuviek.
  inst = NxTest::FakeEntity.new
  inst.set_attribute(c::E::Store::DICT, 'config', JSON.generate('config_schema' => cur + 1))
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

# KOV-D1a (Astra #20 B4) PREPISAL kontrakt tohto testu. V C sa NESEDIACI zaznam
# ZAHADZOVAL a stavba isla na surodenca/latest — to je ale TICHA ZMENA FYZIKY
# uz postavenej zakazky (poskodeny pin sa po vydani v2 sam „upgraduje").
# Od D1a zaznam PREZIJE a stavba ho prizna ako RED bez dielcov. Cudzi recept sa
# nepouzije ani teraz — to je jadro povodneho nalezu Codex #304 P2 a strazi ho
# druha polovica testu.
NxTest.test('KOV-D1a (B4): `recipe_refs` zaznam s NESEDIACIM klucom = RED, nie tichy surodenec') do
  c = NxC2bB
  cfg = c::FR.normalize_config('items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                             'drawer' => { 'construction' => 'metal',
                                                           'recipe_refs' => {
                                                             'atira|sisy' => 'quadro_v6_p2o_v1',
                                                             'atira|p2o' => 'atira_p2o_v1'
                                                           } } }])
  NxTest.assert_equal({ 'atira|sisy' => 'quadro_v6_p2o_v1', 'atira|p2o' => 'atira_p2o_v1' },
                      cfg['items'].first['drawer']['recipe_refs'],
                      'PRITOMNY zaznam sa nezahadzuje — o platnosti rozhoduje `active_ref`')
  NxTest.assert_equal([:unknown, 'quadro_v6_p2o_v1'],
                      c::REC.active_ref(cfg['items'].first['drawer']['recipe_refs'], 'atira', 'sisy'),
                      'nesediaci pin je NEPLATNY, nie chybajuci')
  # A stavba je RED bez dielcov aj bez vysuvu — NIKDY cudzi recept, NIKDY tichy latest.
  full = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                         'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                                     'mode' => 'fixed', 'height' => 175.0,
                                                     'opening_mode' => 'classic',
                                                     'drawer' => { 'construction' => 'metal',
                                                                   'recipe_refs' => { 'atira|sisy' => 'quadro_v6_p2o_v1' } } }] })
  pl = c::CN.build_plan(full, 'CAB-1')
  NxTest.assert_equal(['drawer_recipe_unknown'], Array(pl[:drawer_conflicts]).map { |x| x['code'] })
  NxTest.assert_equal(nil, pl[:hardware].find { |h| h['generic_type'] == 'slide' },
                      'ziadny vysuv (fail-closed)')
  NxTest.assert_equal([], pl[:parts].select { |p| c::CB::DRAWER_ROLES.include?(p[:role].to_s) },
                      'ani jeden dielec zasuvky')
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

# ============================================================================
# CODEX #304 KOLO 3 — propagacia `drawer_material_id`
# ============================================================================

NxTest.test('KOV-C2b: `drawer_material_id` prezije normalize -> config -> params') do
  c = NxC2bB
  # Serverovy kanal 4. materialu: `normalize` kluc pozna, takze ho `build`
  # (vklad) aj `rebuild` ulozia a prestavba ho neztrati. UI kanala (vkladacia
  # karta, vyber v Studiu, „Nahradit UNI…") je v SAMOSTATNOM PR.
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

# ============================================================================
# CODEX #304 (zredukovany PR) — OSIROTENY RUCNY ZASAH sa da zrusit
# ============================================================================

module NxC2bB
  module_function

  # Skrinka so zasuvkou a s legacy NL overridom (D-93 identita trojice).
  def orphan_cfg(over = {})
    front = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
              'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }
    CB.normalize({ 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                   'fronts' => { 'items' => [front] } }.merge(over))
  end

  # Legacy zaznam `hardware_overrides` na zasuvkovom cele.
  def slide_override(over = {})
    [{ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
       'rule_id' => 'vysuvy-nl-podla-hlbky' }.merge(over)]
  end

  # ULOZENY config po stavbe (to, z coho panel stavia payload Kovania).
  def built_config(cfg)
    plan = CN.build_plan(cfg, 'CAB-1')
    stored = CB.cabinet_config(CB.apply_drawer_writes(CB.merge_final(cfg, plan), plan))
    [JSON.parse(JSON.generate(stored)), plan]
  end

  # Presne to, co robi `Panel.hardware_overrides_payload` — klasifikator zije
  # v `HardwareRules` (ciste, headless nacitatelne), panel uz len mapuje.
  def orphan_rows(stored)
    owners = Array(stored['drawer_conflicts']).map { |c| c['part_key'].to_s }
    Array(stored['hardware_overrides']).map do |ov|
      kind = E::HardwareRules.override_orphan_kind(ov, stored['hardware'], owners)
      kind ? ov.merge('orphan' => true, 'orphan_kind' => kind) : ov
    end
  end
end

NxTest.test('Codex #304 P1: rucny POCET na zasuvke = osiroteny zaznam v payloade Kovania') do
  c = NxC2bB
  cfg = c.orphan_cfg('hardware_overrides' => c.slide_override('quantity' => 2))
  stored, plan = c.built_config(cfg)
  # Fail-closed: ZIADNA polozka vysuvu (ani receptova, ani legacy) — takze bez
  # osiroteneho zoznamu by zaznam v paneli nemal kde byt.
  NxTest.assert_equal('drawer_override_invalid', plan[:drawer_conflicts].first['code'])
  NxTest.assert_equal([], plan[:hardware].select { |h| h['generic_type'] == 'slide' })

  row = c.orphan_rows(stored).first
  NxTest.assert_equal([true, 'invalid'], [row['orphan'], row['orphan_kind']],
                      'zaznam MUSI byt v osirotenom zozname')
  NxTest.assert_equal(['front:F1/panel', 'slide', 'vysuvy-nl-podla-hlbky'],
                      [row['owner_part_key'], row['generic_type'], row['rule_id']],
                      'identita trojice, ktorou ho panel resetuje')
  # Hlaska konfliktu odkazuje PRESNE na ten riadok.
  NxTest.assert(plan[:drawer_conflicts].first['message'].include?('neplatný ručný zásah'),
                plan[:drawer_conflicts].first['message'])
end

NxTest.test('Codex #304 P1: RESET zaznamu odstrani konflikt (zelene)') do
  c = NxC2bB
  # Serverova akcia `reset` odstrani CELY zaznam — prestavba nad ocistenym
  # configom uz konflikt nevyda a zasuvka dostane dielce aj vysuv.
  after = c::CN.build_plan(c.orphan_cfg('hardware_overrides' => []), 'CAB-1')
  NxTest.assert_equal([], Array(after[:drawer_conflicts]), after[:drawer_conflicts].inspect)
  NxTest.assert_equal(1, after[:hardware].count { |h| h['generic_type'] == 'slide' },
                      'zasuvka zase dostane svoj vysuv')
  NxTest.assert_equal(2, after[:parts].count { |pd| pd[:material] == :drawer })
  # Retaz „riadok -> serverova akcia -> zaznam prec" je kontrakt, nie nahoda.
  js = c.src_ui(File.join('js', 'hardware.js'))
  NxTest.assert(js.include?("onHwOrphanReset(this)"), 'riadok ponuka zrusenie')
  NxTest.assert(js.include?("function onHwOrphanReset(btn){ hwSend(hwPayload(btn, { reset: true })); }"),
                'a posiela EXISTUJUCU serverovu akciu `reset`')
  NxTest.assert(js.include?("if (ov.orphan === true) return true;"),
                'o osirotenosti rozhoduje SERVER')
  act = c.src_ui(File.join('panel', 'actions_hardware.rb'))
  NxTest.assert(act.include?("return [:all, nil, nil] if truthy?(data['reset'])"),
                '`reset` zahadzuje CELY zaznam')
  pay = c.src_ui(File.join('panel', 'payloads.rb'))
  NxTest.assert(pay.include?("HardwareRules.override_orphan_kind(ov, items, owners)"),
                'payload panela klasifikuje kazdy zaznam')
end

NxTest.test('Codex #304 P1: osiroteny je AJ `disabled` a AJ zamok NL mimo radu') do
  c = NxC2bB
  # (a) vypnuta polozka na zasuvke — `orphan_kind` je `disabled` (vypnutie je
  #     silnejsi popis nez konflikt: naprava je „obnoviť", zaznam nic ine nenesie)
  off = c.orphan_cfg('hardware_overrides' => c.slide_override('disabled' => true))
  stored_off, plan_off = c.built_config(off)
  NxTest.assert_equal('drawer_override_invalid', plan_off[:drawer_conflicts].first['code'])
  row_off = c.orphan_rows(stored_off).first
  NxTest.assert_equal([true, 'disabled'], [row_off['orphan'], row_off['orphan_kind']],
                      'vypnuty zaznam sa v paneli objavi (doterajsie D-92 spravanie)')
  # (b) zamok NL mimo radu (400 nie je v rade H70) — zaznam nesie LEN dlzku,
  #     takze bez tejto vetvy by v paneli nebol vobec.
  nl = c.orphan_cfg('hardware_overrides' => c.slide_override('nominal_length' => 400.0))
  stored_nl, plan_nl = c.built_config(nl)
  NxTest.assert_equal('nl_lock_invalid', plan_nl[:drawer_conflicts].first['code'])
  row_nl = c.orphan_rows(stored_nl).first
  NxTest.assert_equal([true, 'invalid'], [row_nl['orphan'], row_nl['orphan_kind']])
  NxTest.assert(plan_nl[:drawer_conflicts].first['message'].include?('neplatný ručný zásah'))
end

NxTest.test('Codex #304 P1: bezny rucny zasah osiroteny NIE JE') do
  c = NxC2bB
  # Zamok 420 je V RADE — polozka vznikne, zaznam sa kresli PRI nej.
  cfg = c.orphan_cfg('hardware_overrides' => c.slide_override('nominal_length' => 420.0))
  stored, plan = c.built_config(cfg)
  NxTest.assert_equal([], Array(plan[:drawer_conflicts]))
  row = c.orphan_rows(stored).first
  NxTest.refute(row.key?('orphan'), 'zaznam so zivou polozkou do zoznamu NEPATRI')
  # D-92 spravanie ostava: `disabled` bez polozky je `disabled`, nie `invalid`.
  hr = c::E::HardwareRules
  legacy = { 'owner_part_key' => 'front:F9/wing:single', 'generic_type' => 'hinge',
             'rule_id' => 'zavesy', 'disabled' => true }
  NxTest.assert_equal('disabled', hr.override_orphan_kind(legacy, [], []))
  NxTest.assert_equal(nil, hr.override_orphan_kind(legacy, [legacy], []),
                      'so zivou polozkou to osiroteny zaznam nie je')
  NxTest.assert_equal(nil, hr.override_orphan_kind({ 'owner_part_key' => 'front:F9/panel',
                                                     'generic_type' => 'slide',
                                                     'rule_id' => 'x', 'quantity' => 3 }, [], []),
                      'rucny pocet BEZ konfliktu nie je osiroteny (legacy spravanie)')
end

# ============================================================================
# CODEX #304 — ZLA HRUBKA OVERRIDU DIELCA ZASUVKY (16,03 mm)
# ============================================================================

NxTest.test('Codex #304 P1: recept ma pre celo PRESNE dane hrubky (bez tolerancie)') do
  c = NxC2bB
  front = { 'id' => 'F1', 'type' => 'drawer_front', 'opening_mode' => 'classic',
            'drawer' => { 'construction' => 'metal' } }
  recipe, allowed = c::REC.thicknesses_for(front, 'drawer_bottom')
  NxTest.assert_equal([16.0], allowed, 'Atira dno: iba 16 mm')
  NxTest.assert(c::REC.label(recipe).include?('Atira'), c::REC.label(recipe))
  # 16,03 je V TOLERANCII pickera (0,05), ale recept ju NEPOZNA — presna zhoda.
  NxTest.refute(allowed.any? { |v| (v - 16.03).abs < 1e-9 },
                'presna zhoda: 16,03 nie je 16')
  NxTest.assert(c::CB.thickness_ok_for?('drawer_bottom', 16.0, 16.03),
                'stary guard (rozsah dosky) by ju PUSTIL — preto vlastna vetva')
  # Drevo pripusta 16 aj 18, ostatne roly ma tiez.
  wood = { 'id' => 'F1', 'type' => 'drawer_front', 'opening_mode' => 'classic',
           'drawer' => { 'construction' => 'wood' } }
  _r2, w_allowed = c::REC.thicknesses_for(wood, 'box_side')
  NxTest.assert_equal([16.0, 18.0], w_allowed)
  # Legacy celo a rola mimo receptu = ziadny guard (nic sa nevymysla).
  NxTest.assert_equal(nil, c::REC.thicknesses_for({ 'id' => 'F1', 'type' => 'door' }, 'drawer_bottom'))
  NxTest.assert_equal(nil, c::REC.thicknesses_for(front, 'box_side'), 'Atira boky nevyraba')
end

NxTest.test('Codex #304 P1: `pick_ref` je JEDINA pravda o aktivnom recepte') do
  c = NxC2bB
  # pripnuty -> presne ten; chybajuci -> surodenec rovnakej verzie; neznamy -> nil
  NxTest.assert_equal('atira_sisy_v1',
                      c::REC.pick_ref({ 'atira|sisy' => 'atira_sisy_v1' }, 'atira', 'sisy'))
  NxTest.assert_equal('quadro_v6_sisy_v1',
                      c::REC.pick_ref({ 'atira|sisy' => 'atira_sisy_v1' }, 'quadro_v6', 'sisy'),
                      'surodenec ROVNAKEJ verzie')
  NxTest.assert_equal('atira_p2o_v1', c::REC.pick_ref(nil, 'atira', 'p2o'), 'inak najnovsi')
  NxTest.assert_equal(nil, c::REC.pick_ref({ 'atira|sisy' => 'atira_sisy_v9' }, 'atira', 'sisy'),
                      'neznamy ref = nevieme, ktory recept plati')
  # Stavba cita TU ISTU funkciu.
  src = c.src(File.join('core', 'construction.rb'))
  NxTest.assert(src.include?('Recipes.pick_ref(refs_map, key[:system], key[:opening])'),
                'Construction pouziva JEDINU implementaciu')
end

NxTest.test('Codex #304 P1: zly override hrubky dielca = fail-closed konflikt') do
  c = NxC2bB
  # Presne scenar z nalezu: 16,03 mm na dne zasuvky Atira.
  th = NxC2bD_TH.call('front:F1/drawer_bottom' => 16.03)
  cfg = c.orphan_cfg('part_overrides' => { 'front:F1/drawer_bottom' => { 'material_id' => 'X_1603' } })
  plan = c::CN.build_plan(cfg, 'CAB-1', part_thicknesses: th)
  NxTest.assert_equal('drawer_thickness_unsupported', plan[:drawer_conflicts].first['code'])
  NxTest.assert_equal([], plan[:parts].select { |pd| pd[:material] == :drawer },
                      'dielce zmizli — override patri zaniknutemu dielcu')
  NxTest.assert_equal([], plan[:hardware].select { |h| h['generic_type'] == 'slide' })
  # Guard panela ho preto NESMIE ulozit — retaz je kontrakt.
  src = c.src(File.join('ui', 'panel', 'actions_parts.rb'))
  NxTest.assert(src.include?('drawer_part_material_conflict(params, rk, sheet)'),
                'guard bezi v `part_material_conflict`')
  NxTest.assert(src.index('drawer_part_material_conflict(params, rk, sheet)') <
                src.index('return nil if Materials.uni?(sheet)'),
                'a bezi PRED UNI vetvou aj pred `thickness_ok_for?`')
  NxTest.assert(src.include?('Recipes.thicknesses_for(item, role)'),
                'meria proti AKTIVNEMU receptu cela')
end

NxTest.test('Codex #304 P1: osiroteny materialovy override ma cestu von') do
  c = NxC2bB
  # ZIVY TVAR DAT: normalize -> build_plan S HRUBKAMI (18 mm override na dne)
  # -> merge_final -> cabinet_config -> JSON (model). Presne to, co po zlej
  # prestavbe lezi na entite a co cita panel.
  cfg = c.orphan_cfg('part_overrides' => {
                       'front:F1/drawer_bottom' => { 'material_id' => 'DOSKA_18' }
                     })
  th = NxC2bD_TH.call('front:F1/drawer_bottom' => 18.0)
  plan = c::CN.build_plan(cfg, 'CAB-1', part_thicknesses: th)
  stored = JSON.parse(JSON.generate(c::CB.cabinet_config(c::CB.merge_final(cfg, plan))))
  NxTest.assert_equal('drawer_thickness_unsupported', stored['drawer_conflicts'].first['code'])
  NxTest.assert_equal('front:F1/panel', stored['drawer_conflicts'].first['part_key'])

  rows = c::CB.orphan_drawer_part_overrides(stored)
  NxTest.assert_equal(1, rows.length, "osiroteny zaznam MUSI byt v zozname: #{rows.inspect}")
  NxTest.assert_equal(['front:F1/drawer_bottom', 'drawer_bottom', 'F1', 'front:F1/panel',
                       'DOSKA_18'],
                      rows.first.values_at('part_key', 'role', 'front_id', 'owner_part_key',
                                           'material_id'))
  NxTest.assert(c::CB.orphan_drawer_part_override?(stored, 'front:F1/drawer_bottom'))

  # ANTI-REGRESIA (in-SU FAIL #304): plan BEZ `part_thicknesses` stavia s UNI 16
  # fallbackom, takze prave ten dielec v nom „zije" — preto sa na osirotenost
  # NESMIE pytat planu. Tento riadok fixuje dovod, nie implementaciu.
  NxTest.assert(c::CB.plan_parts_by_key(c::CB.config_to_params(stored))
                     .key?('front:F1/drawer_bottom'),
                'plan bez hrubok dielec EVIDUJE — a prave to bola pricina FAILu')

  # Ziva zasuvka (bez konfliktu) do zoznamu NEPATRI — override sa meni na karte.
  ok_cfg = c.orphan_cfg('part_overrides' => {
                          'front:F1/drawer_bottom' => { 'material_id' => 'DOSKA_16' }
                        })
  ok_plan = c::CN.build_plan(ok_cfg, 'CAB-1', part_thicknesses: NxC2bD_TH.call)
  ok_stored = JSON.parse(JSON.generate(c::CB.cabinet_config(c::CB.merge_final(ok_cfg, ok_plan))))
  NxTest.assert_equal([], Array(ok_stored['drawer_conflicts']))
  NxTest.assert_equal([], c::CB.orphan_drawer_part_overrides(ok_stored))
  NxTest.refute(c::CB.orphan_drawer_part_override?(ok_stored, 'front:F1/drawer_bottom'))

  # Override na INOM (nezasuvkovom) dielci sa zoznamu netyka ani pri konflikte.
  other = JSON.parse(JSON.generate(stored))
  other['part_overrides'] = { 'cabinet/side:left' => { 'material_id' => 'DOSKA_18' } }
  NxTest.assert_equal([], c::CB.orphan_drawer_part_overrides(other))
  # A ani override na cele INEHO cela, ktore v konflikte nie je.
  foreign = JSON.parse(JSON.generate(stored))
  foreign['part_overrides'] = { 'front:F9/drawer_bottom' => { 'material_id' => 'DOSKA_18' } }
  NxTest.assert_equal([], c::CB.orphan_drawer_part_overrides(foreign))

  # `drawer_part_role` pozna LEN roly zasuviek (aj `box_side:left`).
  NxTest.assert_equal('box_side', c::CB.drawer_part_role('front:F1/box_side:left'))
  NxTest.assert_equal(nil, c::CB.drawer_part_role('front:F1/panel'))
  NxTest.assert_equal(nil, c::CB.drawer_part_role('zone:Z1/shelf:1'))

  # Retaz do UI: panel z toho robi riadok, JS ho kresli, server ho resetuje.
  pay = c.src(File.join('ui', 'panel', 'payloads.rb'))
  NxTest.assert(pay.include?('CabinetBuilder.orphan_drawer_part_overrides(cfg)'),
                'payload cita AUTORITU, nie prepocitany plan')
  act = c.src(File.join('ui', 'panel', 'actions_parts.rb'))
  NxTest.assert(act.include?('CabinetBuilder.orphan_drawer_part_override?(cfg, rk)'),
                'serverovy reset overuje TO ISTE')
  NxTest.assert(act.include?('ov.delete(rk)'), 'reset = ODSTRANENIE override')
  pnl = c.src(File.join('ui', 'panel.rb'))
  NxTest.assert(pnl.include?("cb(dlg, 'reset_part_override')"), 'akcia je registrovana')
  js = c.src_ui(File.join('js', 'hardware.js'))
  NxTest.assert(js.include?('sketchup.reset_part_override'), 'riadok vola tu akciu')

  # Po odstraneni override je zasuvka ZELENA.
  after = c::CN.build_plan(c.orphan_cfg('part_overrides' => {}), 'CAB-1')
  NxTest.assert_equal([], Array(after[:drawer_conflicts]))
  NxTest.assert_equal(2, after[:parts].count { |pd| pd[:material] == :drawer })
end

# ============================================================================
# KOV-C2b-M — MATERIALOVY KANAL ZASUVIEK (UI, preflight, hromadne cesty)
# ============================================================================

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
  # Klasifikovane cela sa citaju z ULOZENYCH ciel (legacy celo sa netyka).
  params = { 'fronts' => { 'items' => [
    { 'id' => 'F1', 'type' => 'drawer_front', 'opening_mode' => 'classic',
      'drawer' => { 'construction' => 'metal' } },
    { 'id' => 'F2', 'type' => 'drawer_front', 'opening_mode' => 'classic',
      'drawer' => { 'construction' => 'wood' } },
    { 'id' => 'F3', 'type' => 'door' }
  ] } }
  NxTest.assert_equal(%w[F1 F2], md.drawer_fronts_of(params).map { |it| it['id'] })
  NxTest.assert_equal([], md.drawer_fronts_of('fronts' => { 'items' => [{ 'type' => 'door' }] }))
  # Veta ponuky menuje RECEPT cela AJ jeho povolene hrubky.
  atira = params['fronts']['items'][0]
  NxTest.assert_equal(nil, md.drawer_front_reject(atira, 16.0), 'Atira 16 mm prijme')
  txt = md.drawer_front_reject(atira, 18.0)
  NxTest.assert(txt.include?('Atira') && txt.include?('SiSy') && txt.include?('16'), txt.to_s)
  NxTest.assert_equal(nil, md.drawer_front_reject({ 'id' => 'F3', 'type' => 'door' }, 25.0),
                      'legacy celo preflight NEBLOKUJE')
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
  NxTest.assert_equal(nil, ru.ru_project_target_issue('default_drawer_material_id', 18.0),
                      'zakazka bez zasuviek: staci, ze hrubku pozna aspon jeden system')
  NxTest.assert_equal(c::E::MaterialsDialog.drawer_thickness_any_system?(25.0),
                      ru.ru_project_target_issue('default_drawer_material_id', 25.0).nil?,
                      'JEDEN predikat pre obe cesty')
  # A skrinka s dielcami zasuviek sa na taku dosku nenahradi (blokovana).
  uni = { 'material_id' => 'UNI_ZASUVKA_16', 'thickness' => 16.0, 'decor' => 'UNI' }
  fat = { 'material_id' => 'DOSKA_25', 'thickness' => 25.0, 'decor' => 'Hruba' }
  params = c.stored_params_with('metal', 'drawer_material_id' => 'UNI_ZASUVKA_16')
  scan = { 'cabs' => [['CAB-1', params, { 'drawer' => 'UNI_ZASUVKA_16' }, '{}', :ref]],
           'boards' => [], 'model_guid' => 'G', 'project' => {} }
  out = ru.replace_uni_classify(scan, uni, fat)
  NxTest.assert_equal([], out['jobs_cab'], 'ziadny job')
  NxTest.assert_equal(:drawer, out['blocked'].first && out['blocked'].first[1])
  NxTest.assert(ru.ru_blocked_line('CAB-1', :drawer, []).include?('zásuviek'),
                ru.ru_blocked_line('CAB-1', :drawer, []))
end

NxTest.test('Codex #304 kolo 4 P1: predvolba sa meria systemom KAZDEHO cela zakazky') do
  c = NxC2bB
  ru = c::E::Materials
  # 18 mm pozna Quadro, ale NIE Atira. V ATIROVEJ zakazke sa preto predvolba
  # zasuviek na 18 mm nesmie prepisat — spravila by RED z kazdej zasuvky.
  atira = [c.drawer_front('metal')]
  quadro = [c.drawer_front('wood', 'F2')]
  NxTest.assert_equal(:drawer, ru.ru_project_target_issue('default_drawer_material_id', 18.0, atira),
                      'recept atiroveho cela 18 mm neprijme')
  NxTest.assert_equal(nil, ru.ru_project_target_issue('default_drawer_material_id', 18.0, quadro))
  NxTest.assert_equal(nil, ru.ru_project_target_issue('default_drawer_material_id', 16.0,
                                                      atira + quadro),
                      '16 mm prijmu OBA recepty')
  NxTest.assert_equal(:drawer,
                      ru.ru_project_target_issue('default_drawer_material_id', 18.0, atira + quadro),
                      'zmiesana zakazka: staci JEDNO celo, ktoreho recept hrubku neprijme')
  # A cez CELU klasifikaciu: scan s Atirou -> 18 mm predvolba blokovana.
  uni = { 'material_id' => 'UNI_ZASUVKA_16', 'thickness' => 16.0, 'decor' => 'UNI' }
  t18 = { 'material_id' => 'BIELA_18', 'thickness' => 18.0, 'decor' => 'Biela' }
  scan = { 'cabs' => [['CAB-1', c.stored_params_with('metal'), { 'drawer' => 'UNI_ZASUVKA_16' },
                       '{}', :ref]],
           'boards' => [], 'model_guid' => 'G',
           'project' => { 'default_drawer_material_id' => 'UNI_ZASUVKA_16' } }
  out = ru.replace_uni_classify(scan, uni, t18)
  NxTest.assert_equal({}, out['project_writes'], 'predvolba sa NEPREPISALA')
  NxTest.assert_equal('projektová predvoľba', out['blocked'].first && out['blocked'].first[0])
  # Ta ista nahrada v DREVENEJ zakazke prejde.
  scan2 = { 'cabs' => [['CAB-1', c.stored_params_with('wood'), { 'drawer' => 'UNI_ZASUVKA_16' },
                        '{}', :ref]],
            'boards' => [], 'model_guid' => 'G',
            'project' => { 'default_drawer_material_id' => 'UNI_ZASUVKA_16' } }
  out2 = ru.replace_uni_classify(scan2, uni, t18)
  NxTest.assert_equal({ 'default_drawer_material_id' => 'BIELA_18' }, out2['project_writes'])
end

NxTest.test('Codex #304 kolo 4 P1: UNI LEN v override dielca zasuvky sa neprepasuje') do
  c = NxC2bB
  ru = c::E::Materials
  uni = { 'material_id' => 'UNI_ZASUVKA_16', 'thickness' => 16.0, 'decor' => 'UNI' }
  fat = { 'material_id' => 'DOSKA_25', 'thickness' => 25.0, 'decor' => 'Hruba' }
  # Skrinka DEDI kanal (ziadny `drawer_material_id`), ale DIELEC dna ma vlastny
  # UNI material — `roles_now` rolu `drawer` teda vobec nenesie a genericky
  # rozsah doskoveho materialu by 25 mm ticho prepustil.
  params = c.stored_params_with('metal',
                                'part_overrides' => {
                                  'front:F1/drawer_bottom' => { 'material_id' => 'UNI_ZASUVKA_16' }
                                })
  NxTest.assert_equal('UNI_ZASUVKA_16',
                      params['part_overrides']['front:F1/drawer_bottom']['material_id'],
                      'override prezil round-trip configu')
  scan = { 'cabs' => [['CAB-1', params, { 'drawer' => 'BIELA_16' }, '{}', :ref]],
           'boards' => [], 'model_guid' => 'G', 'project' => {} }
  out = ru.replace_uni_classify(scan, uni, fat)
  NxTest.assert_equal([], out['jobs_cab'], 'ziadny job — 25 mm sa na dno zasuvky nedostane')
  NxTest.assert_equal(:drawer, out['blocked'].first && out['blocked'].first[1])
  NxTest.assert(ru.ru_blocked_line('CAB-1', :drawer, ['Atira']).include?('Atira'),
                'hlaska menuje SYSTEM, ktory hrubku neprijal')
  # Ten isty override, ale cielova doska 16 mm -> prejde.
  ok16 = { 'material_id' => 'BIELA_16', 'thickness' => 16.0, 'decor' => 'Biela' }
  params2 = c.stored_params_with('metal',
                                 'part_overrides' => {
                                   'front:F1/drawer_bottom' => { 'material_id' => 'UNI_ZASUVKA_16' }
                                 })
  scan2 = { 'cabs' => [['CAB-1', params2, { 'drawer' => 'BIELA_16' }, '{}', :ref]],
            'boards' => [], 'model_guid' => 'G', 'project' => {} }
  out2 = ru.replace_uni_classify(scan2, uni, ok16)
  NxTest.assert_equal(1, out2['jobs_cab'].length)
  NxTest.assert_equal('BIELA_16',
                      params2['part_overrides']['front:F1/drawer_bottom']['material_id'])
end

NxTest.test('Codex #304 kolo 4 P1: `ru_drawer_key_front` pozna LEN roly zasuviek') do
  ru = NxC2bB::E::Materials
  NxTest.assert_equal('F1', ru.ru_drawer_key_front('front:F1/drawer_bottom'))
  NxTest.assert_equal('F2', ru.ru_drawer_key_front('front:F2/box_side:left'))
  NxTest.assert_equal(nil, ru.ru_drawer_key_front('front:F1/panel'), 'celo nie je dielec zasuvky')
  NxTest.assert_equal(nil, ru.ru_drawer_key_front('cabinet/side:left'))
  NxTest.assert_equal(nil, ru.ru_drawer_key_front('zone:Z1/shelf:1'))
end

NxTest.test('Codex #304 kolo 4 P1: vklad odmietne nekompatibilny material zasuviek') do
  c = NxC2bB
  # `handle_insert` bez SketchUpu spustit nevieme — testuje sa PREFLIGHT,
  # ktory je cista funkcia nad payloadom (model = nil => projektove predvolby
  # padnu na UNI 16 fallback).
  md = c::E::MaterialsDialog
  mats = c::E::Materials
  atira = { 'fronts' => { 'items' => [c.drawer_front('metal')] } }
  wood  = { 'fronts' => { 'items' => [c.drawer_front('wood')] } }
  # UNI 16 fallback vyhovuje obom systemom.
  NxTest.assert_equal(nil, md.drawer_material_issue(atira, nil))
  NxTest.assert_equal(nil, md.drawer_material_issue(wood, nil))
  # Skrinka BEZ klasifikovanej zasuvky sa preflightu netyka nikdy.
  NxTest.assert_equal(nil, md.drawer_material_issue(
                             { 'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door' }] },
                               'drawer_material_id' => 'NEEXISTUJE' }, nil))
  # 18 mm doska (Quadro ju pozna, Atira nie) — potrebujeme ju v katalogu.
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  sheet18 = mats.sheets.find { |sh| (sh['thickness'].to_f - 18.0).abs < 0.01 && !mats.uni?(sh) } ||
            mats.sheets.find { |sh| (sh['thickness'].to_f - 18.0).abs < 0.01 }
  NxTest.skip!('katalog nema 18 mm dosku') if sheet18.nil?
  id18 = sheet18['material_id']
  msg = md.drawer_material_issue(atira.merge('drawer_material_id' => id18), nil)
  NxTest.assert(msg.to_s.include?('Atira'), "Atira 18 mm musi odmietnut: #{msg.inspect}")
  NxTest.assert(msg.to_s.include?('Nič sa nevložilo'), msg.to_s)
  NxTest.assert_equal(nil, md.drawer_material_issue(wood.merge('drawer_material_id' => id18), nil),
                      'Quadro 18 mm prijme')
end

# ============================================================================
# CODEX #305 KOLO 1 — preflight podla AKTIVNEHO receptu CELA
# ============================================================================

NxTest.test('Codex #305 P2: preflight cita recept CELA, nie „najnovsi recept systemu"') do
  c = NxC2bB
  # Fixtura: system ma DVE vydane verzie s ROZNYMI hrubkami. Celo je pripnute
  # na v1 (16 mm), `latest_for` by dalo v2 (18 mm) — presne ten rozdiel, ktory
  # per-systemovy preflight prehliadol.
  dir = File.join(Dir.tmpdir, "nx_recipes_#{Process.pid}_#{rand(9999)}")
  FileUtils.mkdir_p(dir)
  begin
    src = JSON.parse(File.read(File.join(c::REC::DIR, 'atira_sisy_v1.json'), encoding: 'UTF-8'))
    v2 = JSON.parse(JSON.generate(src))
    v2['recipe_id'] = 'atira_sisy_v2'
    v2['version'] = 2 if v2.key?('version')
    v2['thickness_supported'] = { 'drawer_bottom' => [18], 'drawer_back' => [18] }
    File.write(File.join(dir, 'atira_sisy_v1.json'), JSON.pretty_generate(src))
    File.write(File.join(dir, 'atira_sisy_v2.json'), JSON.pretty_generate(v2))
    reg = { 'atira_sisy_v1' => c::REC.file_digest(File.join(dir, 'atira_sisy_v1.json')),
            'atira_sisy_v2' => c::REC.file_digest(File.join(dir, 'atira_sisy_v2.json')) }
    File.write(File.join(dir, 'RELEASED.json'), JSON.pretty_generate(reg))

    # Kontrola fixtury: `latest_for` je v2, systemovy prienik teda 18 mm.
    NxTest.assert_equal('atira_sisy_v2', c::REC.latest_for('atira', 'sisy', dir: dir))
    NxTest.assert_equal([18.0], c::REC.supported_thicknesses('atira', dir: dir),
                        'per-SYSTEM priblizenie cita NAJNOVSI recept')

    pinned = { 'id' => 'F1', 'type' => 'drawer_front', 'opening_mode' => 'classic',
               'drawer' => { 'construction' => 'metal',
                             'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } } }
    recipe, allowed = c::REC.thicknesses_for_front(pinned, dir: dir)
    NxTest.assert_equal('atira_sisy_v1', recipe[:recipe_id], 'plati PRIPNUTY recept')
    NxTest.assert_equal([16.0], allowed, 'a jeho hrubky, nie hrubky najnovsej verzie')
    NxTest.assert(c::REC.thickness_ok_for_front?(pinned, 16.0, dir: dir))
    NxTest.refute(c::REC.thickness_ok_for_front?(pinned, 18.0, dir: dir),
                  '18 mm by per-systemovy preflight PUSTIL — per-celo ho zastavi')

    # Celo BEZ pripnutia dostane surodenca/najnovsi -> v2 (18 mm).
    fresh = { 'id' => 'F2', 'type' => 'drawer_front', 'opening_mode' => 'classic',
              'drawer' => { 'construction' => 'metal' } }
    NxTest.assert_equal([18.0], c::REC.thicknesses_for_front(fresh, dir: dir)[1])
  ensure
    FileUtils.rm_rf(dir)
  end
end

NxTest.test('Codex #305 P2: recept cela rozhoduje aj podla OTVARANIA') do
  c = NxC2bB
  # `supported_thicknesses(system)` cita PRVE otvaranie zo `OPENINGS` (sisy).
  # Tip-On celo ma vlastny recept — preflight ho musi menovat, inak by hlaska
  # ukazovala cudzie cislo aj cudzi nazov.
  sisy = c.drawer_front('metal')
  tipon = { 'id' => 'F2', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
            'opening_mode' => 'tipon', 'drawer' => { 'construction' => 'metal' } }
  NxTest.assert_equal('atira_sisy_v1', c::REC.thicknesses_for_front(sisy)[0][:recipe_id])
  NxTest.assert_equal('atira_p2o_v1', c::REC.thicknesses_for_front(tipon)[0][:recipe_id],
                      'Tip-On celo ma VLASTNY recept')
  md = c::E::MaterialsDialog
  NxTest.assert(md.drawer_front_reject(tipon, 18.0).to_s.include?('Tip-On'),
                md.drawer_front_reject(tipon, 18.0).to_s)
  # Legacy / neznamy ref preflight NEBLOKUJE — jeho stav rieši stavba.
  unknown = { 'id' => 'F3', 'type' => 'drawer_front', 'opening_mode' => 'classic',
              'drawer' => { 'construction' => 'metal',
                            'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v9' } } }
  NxTest.assert_equal(nil, c::REC.thicknesses_for_front(unknown))
  NxTest.assert(c::REC.thickness_ok_for_front?(unknown, 25.0), 'neznamy recept = nechaj stavbe')
end

NxTest.test('Codex #305 P2: „Nahradiť UNI…" meria recept KAZDEHO dotknuteho cela') do
  c = NxC2bB
  ru = c::E::Materials
  # Tip-On celo (recept `atira_p2o_v1`) — blokacia MUSI menovat jeho recept.
  tipon = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
            'opening_mode' => 'tipon', 'drawer' => { 'construction' => 'metal' } }
  params = c.stored_params('fronts' => { 'items' => [tipon] },
                           'drawer_material_id' => 'UNI_ZASUVKA_16')
  uni = { 'material_id' => 'UNI_ZASUVKA_16', 'thickness' => 16.0, 'decor' => 'UNI' }
  t18 = { 'material_id' => 'BIELA_18', 'thickness' => 18.0, 'decor' => 'Biela' }
  scan = { 'cabs' => [['CAB-1', params, { 'drawer' => 'UNI_ZASUVKA_16' }, '{}', :ref]],
           'boards' => [], 'model_guid' => 'G',
           'project' => { 'default_drawer_material_id' => 'UNI_ZASUVKA_16' } }
  out = ru.replace_uni_classify(scan, uni, t18)
  NxTest.assert_equal({}, out['project_writes'], 'predvolba sa NEPREPISALA')
  NxTest.assert_equal(:drawer, out['blocked'].last && out['blocked'].last[1])
  NxTest.assert(Array(out['blocked'].last[2]).any? { |n| n.include?('Tip-On') },
                out['blocked'].inspect)
  # Cela sa zbieraju CELE, nie len ich systemy.
  NxTest.assert_equal(['F1'], ru.ru_scan_drawer_fronts(scan).map { |it| it['id'] })
  NxTest.assert_equal(['F1'], ru.ru_drawer_fronts_affected(params, ['drawer'], [])
                                .map { |it| it['id'] })
end

NxTest.test('Codex #305 P2: tvrde odmietnutie VRATI select na ulozenu predvolbu') do
  c = NxC2bB
  src = c.src_ui('materials_dialog.rb')
  body = src[/def handle_set_project_material.*?unless new_ok.*?\n          end/m].to_s
  NxTest.assert(body.include?('reset_project_select(key, Materials.project_defaults(model)[key].to_s)'),
                'bez resetu by select ostal na ODMIETNUTEJ hodnote')
  NxTest.assert(body.include?('set_status(project_thickness_msg(key, value, have), true)'),
                'a hlaska ostava')
  # `reset_project_select` posiela JS kanal, ktory select vrati na `current`.
  NxTest.assert(src.include?("js(\"MD.resetProject("), 'existujuci kanal, ziadny novy')
end
