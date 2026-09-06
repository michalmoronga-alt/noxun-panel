# frozen_string_literal: true
# Testy KOV-D4: UI DROBNOSTI — adresa riadku Kovania v naleze Kontroly,
# `owner_label` v tabulke „Bez kódov" a PRAVIDLO PAMATE pri prechode na dvierka.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 nalez, ktory ma v Kovani konkretny riadok, nesie jeho ADRESU
#      (`data` = owner_part_key + generic_type + rule_id + orphan). Adresu
#      sklada SERVER; klient si ju NEODVODZUJE a `stable_key` sa nemeni
#      (dedup a klik-select ostavaju nedotknute).
#   R2 nemapovana polozka („Bez kódov") nesie LUDSKY popis vlastnika z TOHO
#      ISTEHO zdroja ako nakupne riadky (`PartKeys.human_label`); identita
#      (`cabinet_id + owner_part_key`), dedup, `blocks_export` ani CSV/VEPO
#      sa nemenia.
#   R3 PAMAT pri prechode zasuvka -> dvierka -> zasuvka:
#      (a) pamat patri ROVNAKEMU ID cela (nove ID = ziadna pamat),
#      (b) zamok ostava viazany na SVOJ recept — pri navrate na TEN ISTY
#          recept sa znovu validuje, pri INOM (zmena otvarania) ostava
#          DORMANTNY a NIKDY sa nezobrazi ako aktivny.
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
#   M1 `drawer_conflict_target` vrati adresu aj pri VIACERYCH zasahoch vlastnika
#      -> „KOV-D4 (R1): pri VIACERYCH zasahoch vlastnika sa adresa NEHADA"
#   M2 `hw_target` doplni adresu aj bez `rule_id` (prazdny retazec)
#      -> „KOV-D4 (R1): neuplna identita = ziadna adresa"
#   M3 `attach_override_axes` prilepi osi KAZDEMU receptovemu zaznamu
#      -> „KOV-D4 (R3): DORMANTNY zamok ineho receptu chipy NEDOSTANE"
#   M4 `owner_label` vstupi do identity nemapovaneho zaznamu
#      -> „KOV-D4 (R2): `owner_label` je ADITIVNY — identita sa nemeni"
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxD4
  module_function

  def e
    Noxun::Engine
  end

  def v
    e::Validation
  end

  def pc
    e::ProductionCore
  end

  def panel
    e::Panel
  end

  def cb
    e::CabinetBuilder
  end

  OWNER = 'front:F1/panel'
  RID   = 'recipe:atira_sisy_v1'
  RID2  = 'recipe:atira_p2o_v1'

  def lock(rule_id = RID, owner = OWNER, extra = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => owner, 'generic_type' => 'slide',
      'rule_id' => rule_id }.merge(extra)
  end

  # Ulozeny `drawer_conflicts` zaznam tak, ako ho `Bom.collect` prelozi na
  # `hardware_issues` (tvar je kontrakt KOV-C2b).
  def issue(code = 'drawer_override_invalid', owner = OWNER)
    { 'code' => code, 'severity' => 'red', 'owner_id' => 'CAB-1', 'owner_pid' => 7,
      'part_key' => owner, 'front_id' => 'F1', 'label' => 'F1 · zásuvkové čelo',
      'message' => 'Zásuvka má vypnutú položku výsuvu.' }
  end

  def items_for(collected, expansion = nil)
    v.run(collected, hardware_expansion: expansion)['items']
  end

  def find(items, category)
    items.find { |it| it['category'] == category }
  end

  # Nemapovany zaznam expanzie (tvar `HardwareSets.unmapped_entry`).
  def unmapped(extra = {})
    { 'cabinet_id' => 'CAB-1', 'owner_part_key' => OWNER, 'generic_type' => 'slide',
      'rule_id' => RID, 'quantity' => 1, 'set_id' => 'atira-h70', 'reason' => 'nl_missing',
      'nominal_length' => 470.0 }.merge(extra)
  end

  # --- fixtury pamate (rovnaka zakazka ako KOV-D2a) -------------------------
  def params(front = {})
    item = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
             'height' => 175.0, 'opening_mode' => 'classic',
             'drawer' => { 'construction' => 'metal' } }.merge(front)
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [item] } }
  end

  def cfg_for(par, overrides = [])
    norm = cb.normalize(par.merge('hardware_overrides' => overrides))
    plan = e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: cb.drawer_thicknesses(norm, {}))
    JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(norm, plan))))
  end

  def index_for(cfg)
    panel.drawer_axes_index(cfg, cb.config_to_params(cfg))
  end

  def csv_for(unmapped)
    e::HardwareSets.purchase_csv({ 'rows' => [], 'unmapped' => unmapped, 'summary' => {} },
                                 project: 'T', generated_at: 'X')
  end
end

# ============================================================================
# R1 — ADRESA RIADKU KOVANIA V NALEZE
# ============================================================================

NxTest.test('KOV-D4 (R1): vypnute kovanie nesie adresu OSIROTENEHO riadku') do
  c = NxD4
  ov = [c.lock('nohy-standard', '', 'disabled' => true, 'generic_type' => 'leg')]
  it = c.find(c.items_for(hardware_overrides: ov), 'hardware')
  NxTest.refute(it.nil?, 'nalez o vypnutom kovani existuje')
  NxTest.assert_equal({ 'owner_part_key' => '', 'generic_type' => 'leg',
                        'rule_id' => 'nohy-standard', 'orphan' => true },
                      it['data'],
                      'vypnuty zasah NEMA zivu polozku — v Kovani je to osiroteny riadok')
  NxTest.assert_equal('hardware|CAB-1||leg|nohy-standard', it['stable_key'],
                      'adresa je ADITIVNA — `stable_key` (a s nim dedup aj klik-select) sa nemeni')
end

NxTest.test('KOV-D4 (R1): nenacenena polozka a chybajuci kit miria na ZIVY riadok') do
  c = NxD4
  soft = c.find(c.items_for({}, 'unmapped' => [c.unmapped]), 'hardware_unmapped')
  NxTest.assert_equal({ 'owner_part_key' => NxD4::OWNER, 'generic_type' => 'slide',
                        'rule_id' => NxD4::RID, 'orphan' => false },
                      soft['data'],
                      'nenacenena polozka v Kovani ZIJE — chyba jej len kod')

  kit = c.unmapped('reason' => 'drawer_kit_missing', 'base_reason' => 'nl_missing',
                   'system' => 'atira', 'height_variant' => 70)
  red = c.find(c.items_for({}, 'unmapped' => [kit]), 'drawer_kit')
  NxTest.assert_equal('red', red['severity'], 'chybajuci kit je RED (dielce su postavene)')
  NxTest.assert_equal(false, red['data']['orphan'],
                      'polozka vysuvu existuje — ceruzka mieri na nu, nie na osiroteny zaznam')
  NxTest.assert_equal(NxD4::RID, red['data']['rule_id'], 'a adresa nesie receptove pravidlo')
end

NxTest.test('KOV-D4 (R1): konflikt zasuvky mieri na JEDINY zasah vlastnika') do
  c = NxD4
  items = c.items_for(hardware_issues: [c.issue], hardware_overrides: [c.lock])
  it = c.find(items, 'drawer')
  NxTest.refute(it.nil?, 'RED konflikt zasuvky existuje')
  NxTest.assert_equal({ 'owner_part_key' => NxD4::OWNER, 'generic_type' => 'slide',
                        'rule_id' => NxD4::RID, 'orphan' => true },
                      it['data'],
                      'veta posiela do Kovania na riadok „neplatný ručný zásah" — a ceruzka tam trafi')
  NxTest.assert_equal('drawer|CAB-1|front:F1/panel|drawer_override_invalid', it['stable_key'],
                      'identita problemu sa adresou NEMENI')
end

# M1
NxTest.test('KOV-D4 (R1): pri VIACERYCH zasahoch vlastnika sa adresa NEHADA') do
  c = NxD4
  two = [c.lock(NxD4::RID), c.lock(NxD4::RID2)]
  it = c.find(c.items_for(hardware_issues: [c.issue], hardware_overrides: two), 'drawer')
  NxTest.refute(it.key?('data'),
                'dormantny zamok vedla aktualneho = server nevie, ktory riadok pali; ' \
                'prisvietit ten druhy je horsie nez neprisvietit nic')
  none = c.find(c.items_for(hardware_issues: [c.issue]), 'drawer')
  NxTest.refute(none.key?('data'), 'a bez zasahu tiez ziadna adresa')
end

# M2
NxTest.test('KOV-D4 (R1): neuplna identita = ziadna adresa') do
  c = NxD4
  NxTest.assert_equal(nil, c.v.hw_target('front:F1/panel', 'slide', '', orphan: true),
                      'bez `rule_id` sa riadok adresovat neda')
  NxTest.assert_equal(nil, c.v.hw_target('front:F1/panel', '', 'x', orphan: true),
                      'ani bez typu kovania')
  NxTest.assert_equal({ 'owner_part_key' => '', 'generic_type' => 'leg',
                        'rule_id' => 'r', 'orphan' => false },
                      c.v.hw_target(nil, 'leg', 'r', orphan: false),
                      'PRAZDNY vlastnik je platna adresa — kovanie CELEJ skrinky')
end

NxTest.test('KOV-D4 (R1): server prepisuje adresu, klient si ju nedomysla') do
  pc = NxD4.pc
  full = { 'data' => { 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
                       'rule_id' => 'recipe:x', 'orphan' => true } }
  NxTest.assert_equal({ 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
                        'rule_id' => 'recipe:x', 'orphan' => true },
                      pc.hw_focus_target(full), 'uplna adresa prejde')
  NxTest.assert_equal(false,
                      pc.hw_focus_target('data' => { 'generic_type' => 'leg', 'rule_id' => 'r' })['orphan'],
                      '`orphan` je STRIKTNE true/false (chybajuce = ziva polozka)')
  NxTest.assert_equal(nil, pc.hw_focus_target('part_key' => 'front:F1/panel'),
                      'nalez BEZ `data` sa sprava presne ako pred D4')
  NxTest.assert_equal(nil, pc.hw_focus_target(nil), 'poskodena polozka nespadne')
  NxTest.assert_equal(nil, pc.hw_focus_target('data' => { 'rule_id' => 'r' }),
                      'neuplna adresa sa zahodi uz tu')
end

NxTest.test('KOV-D4 (R1): ceruzka na riadok Kovania vybera VLASTNIKA (ako pri celach)') do
  pc = NxD4.pc
  item = { 'owner_id' => 'CAB-1', 'owner_pid' => 42, 'part_key' => 'zone:z1/shelf:1' }
  hw = { 'owner_part_key' => 'zone:z1/shelf:1', 'generic_type' => 'shelf_pin',
         'rule_id' => 'podperky', 'orphan' => true }
  got = pc.select_target_item(item, nil, true, hw)
  NxTest.assert_equal(nil, got['part_key'],
                      'sekcia Kovanie zije LEN nad oznacenou SKRINKOU — vnoreny dielec by ju vypol')
  NxTest.assert_equal(42, got['owner_pid'], 'scope na konkretnu instanciu ostava')
  NxTest.assert_equal(item, pc.select_target_item(item, nil, false, hw),
                      'obycajny klik (bez ceruzky) oznaci DIELEC ako doteraz')
  NxTest.assert_equal(item, pc.select_target_item(item, nil, true, nil),
                      'a nalez bez adresy tiez')
end

NxTest.test('KOV-D4 (R1): veta po ceruzke priznava, ci je ciel osiroteny zasah') do
  pc = NxD4.pc
  orph = pc.hw_focus_status(1, 'orphan' => true)
  NxTest.assert(orph.include?('Vybraná skrinka'), orph)
  NxTest.assert(orph.include?('ručného zásahu'), orph)
  live = pc.hw_focus_status(2, 'orphan' => false)
  NxTest.assert(live.include?('Vybraných 2 skriniek'), live)
  NxTest.assert(live.include?('riadok položky'), live)
end

D4_PCORE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb')).freeze
D4_SYNC  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb')).freeze
D4_BRIDGE = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js')).freeze

NxTest.test('KOV-D4 (R1): kanal deep-linku nic nezapisuje a mlci pri zavretom Inspectorovi') do
  push = D4_SYNC[/def push_focus_hardware.*?\n        end\n/m].to_s
  NxTest.refute(push.empty?, 'kanal musi existovat')
  NxTest.assert(push.include?('dialog_alive?'), 'zavrety Inspector nedostane nic')
  NxTest.assert(push.include?('NX.focusHardware'), 'klientska cesta')
  NxTest.refute(push.include?('Store.set'), 'deep-link nic nezapisuje')
  NxTest.assert(push.include?("target['rule_id'].to_s.empty?"),
                'neuplna adresa sa neposiela vobec')
  NxTest.assert(D4_BRIDGE.include?('focusHardware:'), 'a klient ma kanal zaregistrovany')

  sel = D4_PCORE[/def do_select.*?\n      end\n/m].to_s
  i_hw = sel.index('if focus && hw_row')
  i_front = sel.index('if focus && front_id')
  NxTest.assert(i_hw && i_front, 'obe vetvy musia existovat')
  NxTest.assert(i_hw < i_front,
                'pri kovani je cielom RIADOK, nie karta cela — inak by ho karta prekryla')
end

# ============================================================================
# R2 — `owner_label` V TABULKE „BEZ KÓDOV"
# ============================================================================

NxTest.test('KOV-D4 (R2): popis vlastnika sklada TEN ISTY zdroj ako nakupne riadky') do
  pc = NxD4.pc
  fronts = [{ 'id' => 'F1', 'index' => 1, 'type' => 'drawer_front' }]
  by_cab = pc.front_index(cabinet_fronts: { 'CAB-1' => fronts })
  NxTest.assert_equal(fronts, by_cab['CAB-1'], 'index je mapa skrinka -> resolved cela zo zberu')
  NxTest.assert_equal('F1 · zásuvkové čelo',
                      pc.owner_label_for(NxD4::OWNER, 'CAB-1', by_cab),
                      'popis je `PartKeys.human_label` — ta ista funkcia ako pri nakupe (KOV-H2)')
  NxTest.assert_equal(nil, pc.owner_label_for(nil, 'CAB-1', by_cab),
                      'kovanie CELEJ skrinky vlastnika nema')
  NxTest.assert_equal('Fmsi0wnix-1-3a3kxe · zásuvkové čelo',
                      pc.owner_label_for('front:Fmsi0wnix-1-3a3kxe/panel', 'CAB-9', {}),
                      'bez zberu ciel ostava v popise SUROVE ID — cislo „F1" sa NIKDY nehada')
end

NxTest.test('KOV-D4 (R2): „Bez kódov" dostava popis vlastnika na SERVERI') do
  c = NxD4
  raw = c.unmapped('cabinet_id' => 'CAB-1',
                   'owner_part_key' => 'front:Fmsi0wnix-1-3a3kxe/panel')
  fronts = [{ 'id' => 'Fmsi0wnix-1-3a3kxe', 'index' => 1, 'type' => 'drawer_front' }]
  out = c.pc.decorate_unmapped([raw], cabinet_fronts: { 'CAB-1' => fronts })
  NxTest.assert_equal(1, out.length, 'charakterizacia: pocet zaznamov sa NEMENI')
  NxTest.assert_equal('F1 · zásuvkové čelo', out.first['owner_label'],
                      'JS uz nemusi kreslit surovy kluc')
  NxTest.assert_equal(raw['owner_part_key'], out.first['owner_part_key'],
                      'identita (surovy kluc) OSTAVA v datach')
  NxTest.assert_equal(raw['cabinet_id'], out.first['cabinet_id'], 'aj skrinka')
  NxTest.refute(out.first['reason_sk'].to_s.empty?, 'SK dovod chodi dalej (H1b)')
  stop = c.pc.decorate_unmapped([c.unmapped('blocks_export' => true)], {}).first
  NxTest.assert_equal(true, stop['blocks_export'], 'exportna brana ostava nedotknuta')
  NxTest.assert_equal([], c.pc.decorate_unmapped(nil, {}), 'prazdny zoznam nespadne')
end

# M4
NxTest.test('KOV-D4 (R2): `owner_label` je ADITIVNY — identita sa nemeni') do
  c = NxD4
  plain = c.unmapped
  labeled = c.unmapped('owner_label' => 'F1 · zásuvkové čelo')
  a = c.find(c.items_for({}, 'unmapped' => [plain]), 'hardware_unmapped')
  b = c.find(c.items_for({}, 'unmapped' => [labeled]), 'hardware_unmapped')
  NxTest.assert_equal(a['stable_key'], b['stable_key'],
                      'popis do identity nalezu NEVSTUPUJE (inak by sa rozbil dedup aj klik)')
  NxTest.assert_equal(a['message_sk'], b['message_sk'], 'ani do vety semafora')

  csv = c.csv_for([labeled])
  NxTest.refute(csv.include?('F1 · zásuvkové čelo'),
                'CSV nakupu ma pevne stlpce — popis doň nepretiekol')
  NxTest.assert(csv.include?(NxD4::OWNER), 'v CSV ostava SUROVY kluc (identita objednavky)')
  NxTest.assert_equal(c.csv_for([plain]), csv,
                      'CSV je so `owner_label` aj bez neho ZNAK PO ZNAKU to iste')
end

# ============================================================================
# R3 — PAMAT PRI PRECHODE NA DVIERKA
# ============================================================================

NxTest.test('KOV-D4 (R3): pamat patri ROVNAKEMU ID cela — nove ID ju nedostane') do
  f = NxD4.e::Fronts
  saved = { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                          'drawer' => { 'construction' => 'metal', 'system' => 'atira',
                                        'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } } }] }
  # Prechod na DVIERKA: panel posle celo BEZ serverovych poli (nikdy ich neposiela).
  door = f.reattach_server_drawer_fields(
    { 'items' => [{ 'id' => 'F1', 'type' => 'door' }] }, saved
  )
  keep = door['items'].first['drawer']
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1' }, keep['recipe_refs'],
                      'pripnuta verzia receptu prezije prechod na dvierka (to iste ID cela)')

  back = f.reattach_server_drawer_fields(
    { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                    'drawer' => { 'construction' => 'metal' } }] }, saved
  )
  NxTest.assert_equal({ 'atira|sisy' => 'atira_sisy_v1' },
                      back['items'].first['drawer']['recipe_refs'],
                      'a pri navrate na zasuvku plati TEN ISTY recept (ziadna tichá zmena geometrie)')

  fresh = f.reattach_server_drawer_fields(
    { 'items' => [{ 'id' => 'F2', 'type' => 'drawer_front',
                    'drawer' => { 'construction' => 'metal' } }] }, saved
  )
  NxTest.refute(fresh['items'].first.fetch('drawer', {}).key?('recipe_refs'),
                'NOVE ID cela pamat NEDEDI — recept mu pripne az stavba')
end

NxTest.test('KOV-D4 (R3): zamok plati LEN pre SVOJ recept (dormantny sa nepouzije)') do
  c = NxD4
  r = c.e::Recipes
  rec = r.load('atira_sisy_v1')
  ctx = { clear_width: 864.0, clear_height: 175.0, clear_depth: 497.0,
          side_thickness: 18.0, obstructions: [], owner_part_key: NxD4::OWNER }
  own = [c.lock(NxD4::RID, NxD4::OWNER, 'nominal_length' => 420.0)]
  other = [c.lock(NxD4::RID2, NxD4::OWNER, 'nominal_length' => 420.0)]
  NxTest.assert_equal(420.0, r.lock_value(rec, ctx, own),
                      'zamok TOHTO receptu plati (a pri navrate sa znovu validuje stavbou)')
  NxTest.assert_equal(nil, r.lock_value(rec, ctx, other),
                      'zamok INEHO receptu (zmena otvarania) je DORMANTNY — nikdy sa nepouzije')
  NxTest.assert_equal(nil, r.height_lock_value(rec, ctx,
                                               [c.lock(NxD4::RID2, NxD4::OWNER,
                                                       'height_variant' => 70)]),
                      'to iste plati pre vyskovy zamok')
end

# M3
NxTest.test('KOV-D4 (R3): DORMANTNY zamok ineho receptu chipy NEDOSTANE') do
  c = NxD4
  index = { 'by_owner' => { NxD4::OWNER => { 'nl' => { 'state' => 'locked', 'value' => 420.0 } } },
            'idents' => { 'F1' => { 'owner_part_key' => NxD4::OWNER, 'generic_type' => 'slide',
                                    'rule_id' => NxD4::RID } } }
  rows = c.panel.attach_override_axes(
    [c.lock(NxD4::RID), c.lock(NxD4::RID2), c.lock('nohy-standard', '')], index
  )
  NxTest.refute(rows[0]['axes'].nil?, 'zaznam PRIPNUTEHO receptu chipy dostane')
  NxTest.assert_equal(nil, rows[1]['axes'],
                      'dormantny zamok ineho receptu by chipmi ukazoval stav CUDZIEHO receptu, ' \
                      'kym zapis by isiel na jeho vlastny `rule_id`')
  NxTest.assert_equal(nil, rows[2]['axes'], 'a nereceptove kovanie osi nema vobec')
  NxTest.assert_equal(NxD4::RID2, rows[1]['rule_id'],
                      'zaznam OSTAVA v zozname (riadok osiroteneho zasahu ho ukaze aj s „zrušiť")')
end

NxTest.test('KOV-D4 (R3): nad REALNYM configom dostane chipy len aktualny recept') do
  c = NxD4
  cfg = c.cfg_for(c.params, [c.lock(NxD4::RID, NxD4::OWNER, 'nominal_length' => 420.0),
                             c.lock(NxD4::RID2, NxD4::OWNER, 'nominal_length' => 520.0)])
  index = c.index_for(cfg)
  NxTest.assert_equal(NxD4::RID, index['idents']['F1']['rule_id'],
                      'celo je `classic` -> pripnuty je SiSy recept')
  rows = c.panel.attach_override_axes(cfg['hardware_overrides'], index)
  by_rule = rows.each_with_object({}) { |r, o| o[r['rule_id']] = r }
  NxTest.assert_equal(420.0, by_rule[NxD4::RID]['axes']['nl']['value'],
                      'chipy ukazuju zamok PRIPNUTEHO receptu')
  NxTest.assert_equal(nil, by_rule[NxD4::RID2]['axes'],
                      'zamok Tip-On receptu ostava dormantny — ziadny chip `locked`')
end
