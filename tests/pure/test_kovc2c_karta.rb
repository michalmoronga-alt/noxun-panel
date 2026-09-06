# frozen_string_literal: true
# KOV-C2c — UI ZASUVIEK: riadok karty cela, vety receptu, zastavujuci riadok Nakupu.
#
# CO SA OVERUJE
#   1) `Panel.front_drawer_payload` je CISTA projekcia nad ULOZENYM configom:
#      polozka vysuvu `source: 'recipe'` -> stav 'ok' + JEDEN riadok textu;
#      `drawer_conflicts` -> stav 'conflict' s vetou STAVBY (nikdy vlastnou);
#      config spred aktivacie receptov -> stav 'stale'. Server je AUTORITA:
#      panel z klasifikacie ani z kovania nic neodvodzuje a text neskladá.
#   2) `Recipes.explain_stored` sklada vety detailu z ULOZENYCH `params`
#      a z PRIPNUTEHO receptu — nie z prepocitanej geometrie. Neznamy alebo
#      nenacitatelny recept = PRAZDNY zoznam (karta radsej nekresli nic, nez
#      by tvrdila cislo, ktore nevie dokazat).
#   3) ORANGE odporucanie synchronizacie sa viaze na KONKRETNE celo
#      (`warnings[].data.front_id`), nie na skrinku.
#   4) Nemapovana polozka `drawer_kit_missing` nesie `blocks_export` — Nakup
#      podla nej kresli CERVENY riadok (zastavene su vsetky exporty vratane
#      VEPO), nie jantarove „nenacenene".
#   5) CHARAKTERIZACIA: zakazka BEZ klasifikovanej zasuvky ma payload prazdny
#      a nemapovana polozka bez receptu priznak `blocks_export` NEMA.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `drawer_card_row` vrati stav 'ok' aj ked je celo v `drawer_conflicts`
#      (RED text by zmizol a karta by ukazala cisla, ktore nevznikli).
#   2. `drawer_item_for` neporovnava `source` — vezme LEGACY `slide` polozku
#      a tvrdi o nej recept.
#   3. `drawer_sync_note` ignoruje `data.front_id` a vrati warning kazdemu celu.
#   4. `explain_stored` pri nenacitatelnom recepte vyhodi vynimku namiesto [].
#   5. `unmapped_entry` neoznaci receptovy dovod `blocks_export`.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva) — rovnaky
# vzor ako KOV-A2a sada.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  # `ProductionCore` cita sada 1b6b uz pred nami, ale poradie suborov nie je
  # kontrakt — sada si ho preto vypyta sama.
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
end

module NxKovC2c
  E = Noxun::Engine

  ATIRA = 'atira_sisy_v1'
  QUADRO = 'quadro_v6_sisy_v1'

  module_function

  # RESOLVED polozka cela tak, ako ju uklada `Fronts.layout` do `front_items`.
  def front(overrides = {})
    { 'id' => 'F2', 'type' => 'drawer_front', 'mode' => 'auto', 'height' => 175.0,
      'wings' => 'auto', 'wings_n' => 1, 'profile' => 'none',
      'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }.merge(overrides)
  end

  # ULOZENA polozka vysuvu z receptu (tvar `Construction.drawer_hardware_item`).
  def slide(params = {}, extra = {})
    { 'owner_part_key' => 'front:F2/panel', 'generic_type' => 'slide', 'quantity' => 1,
      'rule_id' => "recipe:#{ATIRA}", 'variant_id' => nil, 'production_class' => 'counted',
      'manufactured' => true, 'source' => 'recipe', 'rule_quantity' => 1,
      'params' => { 'recipe_id' => ATIRA, 'system' => 'atira', 'nominal_length' => 470.0,
                    'load' => 30.0, 'opening' => 'sisy', 'opening_mode' => 'classic',
                    'drawer_construction' => 'metal', 'height_variant' => 70 }.merge(params) }
      .merge(extra)
  end

  # ULOZENY config skrinky (schema 5 = po aktivacii receptov).
  def cfg(overrides = {})
    { 'config_schema' => E::CabinetBuilder::CONFIG_SCHEMA,
      'front_items' => [front], 'hardware' => [slide],
      'drawer_conflicts' => [], 'warnings' => [] }.merge(overrides)
  end

  def row(config, fid = 'F2')
    E::Panel.front_drawer_payload(config)[fid]
  end
end

module NxTest
  C2C = NxKovC2c
  # POZOR: `NxTest::E` uz zaviedla ina sada (test_insert_templates) a menny
  # priestor je ZDIELANY — druha definicia by ju prepisala. Engine sa preto
  # adresuje vyhradne cez modul tejto sady (`C2C::E`).

  # ============ 1) riadok karty: VYRIESENA zasuvka ==========================

  test('KOV-C2c: vyriesena zasuvka = JEDEN riadok so vsetkymi osami') do
    r = C2C.row(C2C.cfg)
    assert_equal 'ok', r['state']
    assert_equal 'Atira · H70 · NL 470 · 30 kg · SiSy · recept v1', r['text']
  end

  test('KOV-C2c: Quadro nesie vysku BOXU (nie H variant)') do
    p = { 'recipe_id' => C2C::QUADRO, 'system' => 'quadro_v6', 'nominal_length' => 450.0,
          'load' => 30.0, 'opening' => 'sisy', 'box_height' => 135.0 }
    hw = C2C.slide.merge('params' => p, 'rule_id' => "recipe:#{C2C::QUADRO}")
    r = C2C.row(C2C.cfg('hardware' => [hw]))
    assert_equal 'Quadro V6 · box 135 mm · NL 450 · 30 kg · SiSy · recept v1', r['text']
  end

  test('KOV-C2c: Tip-On sa v riadku menuje svojim menom') do
    r = C2C.row(C2C.cfg('hardware' => [C2C.slide('opening' => 'p2o',
                                                 'recipe_id' => 'atira_p2o_v1')]))
    assert r['text'].include?('Tip-On'), "cakam Tip-On, dostal #{r['text']}"
  end

  test('KOV-C2c: chybajuci udaj sa VYNECHA (nikdy sa nehada)') do
    hw = C2C.slide.merge('params' => { 'recipe_id' => C2C::ATIRA, 'system' => 'atira',
                                       'nominal_length' => 470.0, 'opening' => 'sisy' })
    r = C2C.row(C2C.cfg('hardware' => [hw]))
    assert_equal 'Atira · NL 470 · SiSy · recept v1', r['text']
  end

  test('KOV-C2c: rucny zamok dlzky ma vlastnu poznamku (ziadny chip — to je KOV-D)') do
    plain = C2C.row(C2C.cfg)
    assert plain['locked_note'].nil?, 'bez zamku ziadna poznamka'
    r = C2C.row(C2C.cfg('hardware' => [C2C.slide({}, 'locked' => true)]))
    assert r['locked_note'].to_s.include?('zamknutá'), "cakam vetu o zamku, dostal #{r['locked_note'].inspect}"
  end

  # ============ 2) riadok karty: KONFLIKT a MIGRACIA ========================

  test('KOV-C2c: konflikt NAHRADI hodnoty vetou STAVBY') do
    msg = 'Atira SiSy v1: hĺbka 275 mm, najkratšia NL 350 potrebuje 365 mm.'
    c = C2C.cfg('drawer_conflicts' => [{ 'front_id' => 'F2', 'code' => 'drawer_no_fit',
                                         'message' => msg, 'part_key' => 'front:F2/panel' }])
    r = C2C.row(c)
    assert_equal 'conflict', r['state']
    assert_equal msg, r['message']
    assert r['text'].nil?, 'pri konflikte sa hodnoty NEZOBRAZUJU'
  end

  test('KOV-C2c: konflikt vyhrava aj ked v configu este visi stara polozka') do
    c = C2C.cfg('drawer_conflicts' => [{ 'front_id' => 'F2', 'code' => 'drawer_no_fit',
                                         'message' => 'nezmestí sa', 'part_key' => 'front:F2/panel' }],
                'hardware' => [C2C.slide])
    assert_equal 'conflict', C2C.row(c)['state']
  end

  test('KOV-C2c: konflikt CUDZIEHO cela sa na toto celo nelepi') do
    c = C2C.cfg('drawer_conflicts' => [{ 'front_id' => 'F9', 'code' => 'drawer_no_fit',
                                         'message' => 'nezmestí sa', 'part_key' => 'front:F9/panel' }])
    assert_equal 'ok', C2C.row(c)['state']
  end

  test('KOV-C2c: config spred aktivacie receptov = stav `stale`') do
    old = C2C::E::CabinetBuilder::DRAWER_ACTIVATION_SCHEMA - 1
    c = C2C.cfg('config_schema' => old, 'hardware' => [])
    assert_equal 'stale', C2C.row(c)['state']
  end

  test('KOV-C2c: klasifikovane celo BEZ polozky a BEZ dovodu (nova schema) mlci') do
    assert_equal 'pending', C2C.row(C2C.cfg('hardware' => []))['state']
  end

  test('KOV-C2c: LEGACY polozka `slide` sa za recept NEVYDAVA') do
    legacy = C2C.slide.merge('source' => 'rule', 'rule_id' => 'vysuvy-nl-podla-hlbky')
    assert_equal 'pending', C2C.row(C2C.cfg('hardware' => [legacy]))['state']
  end

  # ============ 3) ORANGE odporucanie synchronizacie ========================

  test('KOV-C2c: sync warning sa viaze na KONKRETNE celo') do
    w = { 'code' => 'drawer_sync_recommended', 'severity' => 'warn',
          'message' => 'Zásuvka F2 (šírka 864 mm) vyžaduje synchronizáciu — pridaj set.',
          'part_key' => 'front:F2/panel', 'data' => { 'front_id' => 'F2', 'clear_width' => 864.0 } }
    r = C2C.row(C2C.cfg('warnings' => [w]))
    assert_equal w['message'], r['sync']
    other = w.merge('data' => { 'front_id' => 'F7' })
    assert C2C.row(C2C.cfg('warnings' => [other]))['sync'].nil?,
                'warning cudzieho cela sa sem nesmie dostat'
  end

  test('KOV-C2c: iny build warning riadok zasuvky neovplyvni') do
    w = { 'code' => 'abs_missing', 'message' => 'niečo iné', 'data' => { 'front_id' => 'F2' } }
    assert C2C.row(C2C.cfg('warnings' => [w]))['sync'].nil?
  end

  # ============ 4) vety detailu z ULOZENYCH parametrov ======================

  test('KOV-C2c: explain_stored menuje recept, vysku, NL aj nosnost') do
    lines = C2C::E::Recipes.explain_stored(C2C.slide['params'])
    assert_equal 4, lines.length
    assert lines[0].include?('Atira SiSy v1'), lines[0]
    assert lines[0].include?(C2C::ATIRA), lines[0]
    # min_clear_height varianta H70 je v datovom packu 105 mm
    assert_equal 'Výška H70: potrebná svetlá výška od 105 mm', lines[1]
    # rad H70 = 350..520, NL 470 potrebuje svetlu hlbku 485 mm
    assert_equal 'Dĺžka výsuvu NL 470 mm (rad 350–520 mm), potrebná svetlá hĺbka 485 mm', lines[2]
    assert_equal 'Nosnosť bunky: 30 kg', lines[3]
  end

  test('KOV-C2c: Quadro vysvetli vysku BOXU cez volu receptu') do
    p = { 'recipe_id' => C2C::QUADRO, 'system' => 'quadro_v6', 'nominal_length' => 450.0,
          'load' => 30.0, 'opening' => 'sisy', 'box_height' => 135.0 }
    lines = C2C::E::Recipes.explain_stored(p)
    assert_equal 'Výška boxu 135 mm (svetlá výška zóny − vôľa 40 mm)', lines[1]
    assert_equal 'Dĺžka výsuvu NL 450 mm (rad 350–550 mm), potrebná svetlá hĺbka 463 mm', lines[2]
  end

  test('KOV-C2c: neznamy recept = ZIADNE vety (nikdy vymyslene cislo)') do
    assert_equal [], C2C::E::Recipes.explain_stored({ 'recipe_id' => 'antaro_sisy_v1' })
    assert_equal [], C2C::E::Recipes.explain_stored({})
    assert_equal [], C2C::E::Recipes.explain_stored(nil)
  end

  test('KOV-C2c: karta nesie vety detailu, ktore vratil recept') do
    r = C2C.row(C2C.cfg)
    assert_equal C2C::E::Recipes.explain_stored(C2C.slide['params']), r['detail']
  end

  # ============ 5) NAKUP: zastavujuci riadok ================================

  test('KOV-C2c: receptovy dovod nesie `blocks_export` (Nakup ho kresli cerveno)') do
    it = { 'owner_id' => 'CAB-2', 'owner_part_key' => 'front:F2/panel', 'generic_type' => 'slide',
           'rule_id' => "recipe:#{C2C::ATIRA}", 'quantity' => 1, 'source' => 'recipe',
           'params' => { 'system' => 'atira', 'height_variant' => 70, 'nominal_length' => 470.0 } }
    u = C2C::E::HardwareSets.unmapped_entry(it, 'set-atira', 'nl_missing')
    assert_equal 'drawer_kit_missing', u['reason']
    assert_equal 'nl_missing', u['base_reason']
    assert u['blocks_export'] == true, 'receptova polozka MUSI zastavit exporty'
  end

  test('KOV-C2c: bezna nemapovana polozka `blocks_export` NEMA (charakterizacia)') do
    it = { 'owner_id' => 'CAB-2', 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
           'rule_id' => 'vysuvy-nl-podla-hlbky', 'quantity' => 2, 'source' => 'rule',
           'params' => { 'nominal_length' => 470.0 } }
    u = C2C::E::HardwareSets.unmapped_entry(it, 'set-x', 'nl_missing')
    assert_equal 'nl_missing', u['reason']
    assert u['blocks_export'].nil?, 'legacy polozka exporty nezastavuje'
  end

  # ============ 5b) KONTROLA: nalez zasuvky je klik-navigovatelny ===========
  #
  # C2c ziadnu NOVU navigaciu nestavia — dokazuje, ze RED riadky zasuvky idu
  # UZ EXISTUJUCOU cestou KOV-A2b (ceruzka -> vyber SKRINKY + otvorena karta
  # cela). Podmienkou je, aby `part_key` nalezu bol kluc PANELA CELA; keby
  # niesol kluc dielca zasuvky, ceruzka by otvorila kartu DIELCA a deep-link
  # by ticho zomrel.

  test('KOV-C2c: RED riadok zasuvky nesie kluc cela — ceruzka otvori jeho kartu') do
    iss = { 'code' => 'drawer_no_fit', 'severity' => 'red', 'owner_id' => 'CAB-2',
            'owner_pid' => 7, 'part_key' => 'front:F2/panel', 'front_id' => 'F2',
            'message' => 'Atira SiSy v1: nezmestí sa.', 'label' => 'Čelo F2' }
    item = C2C::E::Validation.drawer_conflict_item(iss)
    assert_equal 'red', item['severity']
    assert_equal 'F2', C2C::E::PartKeys.front_id(item['part_key'])
    assert item['message_sk'].include?('Čelo F2'), item['message_sk']
    assert item['message_sk'].include?('nezmestí sa'), item['message_sk']
    # ceruzka (focus) => vyber VLASTNIKA, nie vnoreneho dielca (KOV-A2b)
    tgt = C2C::E::ProductionCore.select_target_item(item, 'F2', true)
    assert tgt['part_key'].nil?, 'ceruzka musi vybrat SKRINKU, inak deep-link zomrie'
    plain = C2C::E::ProductionCore.select_target_item(item, 'F2', false)
    assert_equal 'front:F2/panel', plain['part_key']
  end

  test('KOV-C2c: RED riadok „nakup nenasiel kit" menuje system, NL aj napravu') do
    u = { 'reason' => 'drawer_kit_missing', 'base_reason' => 'nl_missing',
          'system' => 'atira', 'height_variant' => 70, 'nominal_length' => 470.0,
          'rule_id' => 'recipe:atira_sisy_v1' }
    item = C2C::E::Validation.drawer_kit_item(u, 'CAB-2 · front:F2/panel', 'set-atira',
                                              'front:F2/panel', 'slide', 'CAB-2')
    assert_equal 'red', item['severity']
    msg = item['message_sk']
    assert msg.include?('Atira'), msg
    assert msg.include?('H70'), msg
    assert msg.include?('NL 470'), msg
    assert msg.include?('VEPO'), msg
  end

  # ============ 6) charakterizacia: zakazka BEZ zasuviek ====================

  test('KOV-C2c: zakazka bez klasifikovanej zasuvky ma payload PRAZDNY') do
    door = C2C.front('id' => 'F1', 'type' => 'door', 'drawer' => nil, 'opening_mode' => nil)
    assert_equal({}, C2C::E::Panel.front_drawer_payload(C2C.cfg('front_items' => [door], 'hardware' => [])))
    assert_equal({}, C2C::E::Panel.front_drawer_payload({}))
  end

  test('KOV-C2c: zasuvka BEZ klasifikacie sa do payloadu nedostane') do
    bare = C2C.front('drawer' => {}, 'opening_mode' => nil)
    assert_equal({}, C2C::E::Panel.front_drawer_payload(C2C.cfg('front_items' => [bare], 'hardware' => [])))
  end

  # ============ 7) zdrojove guardy UI ======================================

  test('KOV-C2c: karta cita `front_drawer` ako VLASTNY kanal (nie cez front_slots)') do
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
    assert src.include?('frontDrawerOf(row.dataset.frontId)'),
                'frontCardHtml musi posielat zaznam zasuvky do view-modelu'
    bridge = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
    assert bridge.include?('frontDrawer = c.front_drawer'),
                'bridge musi mapu prebrat z payloadu (ziadne odvodzovanie)'
  end

  test('KOV-C2c: CSS riadku zasuvky je scopnute a pouziva len tokeny --nx-*') do
    css = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
    block = css.scan(/^\s*\.nx-inspector \.fcard \.(?:drow|ddet)[^\n]*$/).join("\n")
    assert block.include?('.drow'), 'pravidla riadku zasuvky musia byt scopnute pod .nx-inspector .fcard'
    hex = block.scan(/#[0-9a-fA-F]{3,8}\b/)
    assert_equal [], hex
  end
end
