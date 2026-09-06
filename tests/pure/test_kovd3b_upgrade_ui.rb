# frozen_string_literal: true
# Testy KOV-D3b: UPGRADE RECEPTU — UI (ponuka, dopad na TOTO celo, potvrdenie).
#
# V repe su LEN recepty v1 a ziadny dovod na v2, takze v plugine sa ponuka
# NIKDY neukaze. Cely ramec sa preto overuje nad FIXTURNYM registrom (vzor D3a,
# test seam `Recipes.with_test_dir`); produkcny register ostava NEDOTKNUTY
# a strazi to vlastny charakterizacny test.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 payload `front_drawer[fid].upgrade` vznikne LEN ked pre PRIPNUTY recept
#      naozaj existuje VYDANA vyssia verzia; inak kluc CHYBA (payload je
#      zhodny s D3a) — ziadny novy vertikalny blok bez v2
#   R2 dopad na TOTO celo (vyska, NL, rozmery dielcov, zamky, kit) sklada
#      SERVER a berie ho z TOHO ISTEHO nasucho postaveneho stavu, ktory by sa
#      aj zapisal; odmietnuty preflight = `ok: false` + dovod a NIC sa nezapise
#   R4 zapisova aj citacia cesta odpovedaju CAKAJUCEMU modalu tokenom
#      v KAZDEJ vetve (inak by okno ostalo zamknute navzdy)
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
#   M1 `drawer_upgrade_offer` vynecha kontrolu `Recipes.upgrade?`
#      -> „KOV-D3b (R1): ponuka NEVZNIKNE, ked je pripnuty recept uz najnovsi"
#   M2 ponuka sa pripaja aj zaznamu, ktoreho stav nie je `ok`
#      -> „KOV-D3b (R1): konfliktna zasuvka ponuku NEDOSTANE"
#   M3 `drawer_upgrade_impact` cita cielove cisla z ULOZENEHO configu (nie
#      z preflightu) -> „KOV-D3b (R2): dopad ukazuje CIELOVE cisla…"
#   M4 `push_upgrade_impact` posiela odpoved aj BEZ tokenu
#      -> „KOV-D3b (R4): odpoved sa posiela LEN k tokenu a nesie ho spat"
require_relative '../helper' unless defined?(NxTest)
require 'tmpdir'

# Panelove akcie nie su v require zozname helpera (vzor KOV-D1a/D2a/D3a).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware')
end

module NxD3b
  module_function

  def e
    Noxun::Engine
  end

  def r
    e::Recipes
  end

  def cb
    e::CabinetBuilder
  end

  def panel
    e::Panel
  end

  # Zdrojova fixtura je registrom D3a (6 receptov) — v nom je `latest_for`
  # rovny v5, co je zamerne ZLY ciel. Testy ponuky si preto stavaju VLASTNY
  # register s presne tolkymi receptami, kolko scenar potrebuje; subory sa
  # kopiruju BAJT PO BAJTE, takze odtlacky z povodneho registra platia dalej
  # (vydany recept sa nikdy nemeni).
  SRC = File.join(NxTest::ROOT, 'tests', 'fixtures', 'recipes_d3a')
  OWNER = 'front:F1/panel'
  V1 = 'atira_sisy_v1'
  V2 = 'atira_sisy_v2'
  BAD = 'atira_sisy_v3'   # hrubky len 18 mm -> preflight odmietne

  def rid(id)
    "recipe:#{id}"
  end

  # Recept sa berie z fixtury D3a, a ked tam nie je (produkcna v1 Quadra),
  # z PRODUKCNEHO priecinka — v oboch pripadoch BAJT PO BAJTE aj s odtlackom
  # z prislusneho registra, takze `load` odtlacok overi bez vynimky.
  def source_of(id)
    File.file?(File.join(SRC, "#{id}.json")) ? SRC : r::DIR
  end

  def with_reg(ids)
    Dir.mktmpdir('noxun-kovd3b-') do |d|
      reg = {}
      ids.each do |id|
        src = source_of(id)
        File.binwrite(File.join(d, "#{id}.json"), File.binread(File.join(src, "#{id}.json")))
        reg[id] = r.released(dir: src).fetch(id)
      end
      File.write(File.join(d, 'RELEASED.json'), "#{JSON.pretty_generate(reg)}\n")
      yield d
    end
  end

  # Zakazka s QUADRO zasuvkou (dreveny box) — vydava PAT dielcov, z toho
  # `box_side` DVAKRAT (vlavo a vpravo) a vysku nesie `box_height`, nie
  # `height_variant`.
  def quadro_params(front_height: 220.0, refs: { 'quadro_v6|sisy' => 'quadro_v6_sisy_v1' })
    drawer = { 'construction' => 'wood', 'system' => 'quadro_v6' }
    drawer['recipe_refs'] = refs if refs
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
      'thickness' => 18.0, 'floor_height' => 100.0, 'hardware_overrides' => [],
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                                  'height' => front_height, 'opening_mode' => 'classic',
                                  'drawer' => drawer }] } }
  end

  # Register, v ktorom je v2 NAJNOVSIA — presne stav, ktory ponuku vydava.
  def with_v2
    with_reg([V1, V2]) { |d| r.with_test_dir(d) { yield d } }
  end

  # --- zakazka: spodna skrinka 900x720, jedno zasuvkove celo F1 (Atira SiSy) --
  #
  # Celo 220 mm je zamerne: pusta variant H144, v ktorom sa fixturna v1 a v2
  # naozaj lisia (chrbat 144 -> 120 mm). Pri nizsom cele by vysiel H70, kde je
  # chrbat v oboch verziach rovnaky a test by nic nedokazal.
  def params(front_height: 220.0, depth: 500.0, refs: { 'atira|sisy' => V1 }, overrides: [])
    drawer = { 'construction' => 'metal', 'system' => 'atira' }
    drawer['recipe_refs'] = refs if refs
    items = [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
               'height' => front_height, 'opening_mode' => 'classic', 'drawer' => drawer }]
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => depth,
      'thickness' => 18.0, 'floor_height' => 100.0, 'hardware_overrides' => overrides,
      'fronts' => { 'items' => items } }
  end

  # ULOZENY config skrinky presne tak, ako ho po stavbe vidi panel (vzor D3a).
  def cfg_for(par)
    norm = cb.normalize(par)
    plan = e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: cb.drawer_thicknesses(norm, {}))
    JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(norm, plan))))
  end

  def cab_with(cfg)
    inst = NxTest::FakeEntity.new
    inst.set_attribute(e::Store::DICT, 'config', JSON.generate(cfg))
    inst
  end

  def lock(fields, rule = rid(V1), owner = OWNER)
    { 'owner_part_key' => owner, 'generic_type' => 'slide', 'rule_id' => rule }.merge(fields)
  end

  # Zaznam karty (`front_drawer[fid]`) vratane ponuky — presne to, co dostane
  # panel v plnom pushi.
  def card(cfg, fid = 'F1', cab_id = 'CAB-1')
    map = panel.front_drawer_payload(cfg)
    panel.attach_front_drawer_upgrade(map, cfg, cab_id)[fid]
  end

  # Dopad nasucho — model je `nil` (headless nema SketchUp dokument), sety sa
  # citaju z globalnej kniznice presne ako ich cita nakup bez snapshotu.
  # -> [impact|nil, chyba|nil]
  def impact(cfg, to, from: V1, front_id: 'F1')
    cab = cab_with(cfg)
    prep, err = panel.drawer_upgrade_prepare(nil, cab,
                                             'front_id' => front_id, 'from' => from, 'to' => to)
    return [nil, err] if err

    [panel.drawer_upgrade_impact(nil, cab, prep), nil]
  end
end

# ============================================================================
# R1 — PONUKA V PAYLOADE KARTY
# ============================================================================

NxTest.test('KOV-D3b (R1): BEZ vydanej vyssej verzie payload NEMA kluc `upgrade`') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  row = c.card(cfg)
  NxTest.assert_equal('ok', row['state'], 'zasuvka sa musi vyriesit, inak test meria nieco ine')
  NxTest.refute(row.key?('upgrade'),
                'v produkcii ziadna v2 neexistuje — karta nesmie dostat ZIADNY novy blok')
  # Charakterizacia: zaznam je presne ten, ktory vydala D3a.
  NxTest.assert_equal(c.panel.front_drawer_payload(cfg)['F1'], row,
                      'payload bez v2 sa od D3a nelisi ani o kluc')
end

NxTest.test('KOV-D3b (R1): s vydanou v2 nesie zaznam ponuku aj identitu zapisu') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    up = c.card(cfg)['upgrade']
    NxTest.assert(up.is_a?(Hash), up.inspect)
    NxTest.assert_equal(true, up['available'])
    NxTest.assert_equal(NxD3b::V1, up['from'], 'stary ref je PRIPNUTY recept, nie „najnizsi"')
    NxTest.assert_equal(NxD3b::V2, up['to'])
    NxTest.assert_equal('v2', up['to_label'])
    NxTest.assert(up['release_note'].include?('chrbát'),
                  "autorska poznamka vydania patri do ponuky: #{up['release_note'].inspect}")
    # Identitu zapisu sklada SERVER (rovnaka zasada ako `lock` v D2b) — panel
    # by inak musel vediet, ktore celo zaznam opisuje.
    NxTest.assert_equal('CAB-1', up['cabinet_id'])
    NxTest.assert_equal('F1', up['front_id'])
  end
end

NxTest.test('KOV-D3b (R1): ponuka NEVZNIKNE, ked je pripnuty recept uz najnovsi') do
  c = NxD3b
  cfg = c.cfg_for(c.params(refs: { 'atira|sisy' => NxD3b::V2 }))
  c.with_v2 do
    NxTest.refute(c.card(cfg).key?('upgrade'),
                  'v2 nad v2 nie je upgrade — `Recipes.upgrade?` je jedina autorita smeru')
  end
end

NxTest.test('KOV-D3b (R1): poskodeny ani chybajuci pin ponuku nedostanu') do
  c = NxD3b
  c.with_v2 do
    # `:unknown` — hodnota hovori o inom systeme, nez jej kluc (D1a).
    bad = c.cfg_for(c.params(refs: { 'atira|sisy' => 'quadro_v6_sisy_v1' }))
    NxTest.refute(c.card(bad).to_h.key?('upgrade'),
                  'poskodeny pin je RED `drawer_recipe_unknown` s vlastnou cestou napravy')
    # `:missing` — zaznam mapy este nie je; doplni ho stavba, nie upgrade.
    miss = c.cfg_for(c.params(refs: nil))
    row = c.card(miss)
    NxTest.refute(row.to_h.key?('upgrade'), row.inspect)
  end
end

NxTest.test('KOV-D3b (R1): konfliktna zasuvka ponuku NEDOSTANE') do
  c = NxD3b
  # Zamknuta NL 620 v rade H144 neexistuje -> fail-closed konflikt zo stavby.
  cfg = c.cfg_for(c.params(overrides: [c.lock('nominal_length' => 620.0)]))
  c.with_v2 do
    row = c.card(cfg)
    NxTest.assert_equal('conflict', row['state'], 'test potrebuje naozaj konfliktnu zasuvku')
    NxTest.refute(row.key?('upgrade'),
                  'tabulka dopadu porovnava TERAJSI stav s cielovym — konflikt ziadny nema')
  end
end

NxTest.test('KOV-D3b (R1): prazdna mapa zaznamov sa nedotkne (zakazka bez zasuviek)') do
  c = NxD3b
  NxTest.assert_equal({}, c.panel.attach_front_drawer_upgrade({}, {}, 'CAB-1'))
  NxTest.assert_equal(nil, c.panel.attach_front_drawer_upgrade(nil, {}, 'CAB-1'))
end

# ============================================================================
# R2 — DOPAD NA TOTO CELO
# ============================================================================

NxTest.test('KOV-D3b (R2): dopad ukazuje CIELOVE cisla dielcov z NASUCHO postaveneho stavu') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    imp, err = c.impact(cfg, NxD3b::V2)
    NxTest.assert(err.nil?, err.to_s)
    # Chrbat: v1 ma H144 rear_height 144, v2 uz 120 -> vyska dielca sa MENI.
    back = Array(imp['parts']).find { |p| p['role'] == 'drawer_back' }
    NxTest.assert(back, imp['parts'].inspect)
    NxTest.assert_equal(144.0, back['from'][1], 'terajsi chrbat je z v1')
    NxTest.assert_equal(120.0, back['to'][1], 'cielovy chrbat je z v2 (nie z ulozeneho configu)')
    NxTest.assert_equal('chrbát', back['label'], 'popisok roly dava server, panel ho neskladá')
    # Dno: v2 ma `bottom_width_offset` o 4 mm vacsi -> dno je o 4 mm uzsie.
    bot = Array(imp['parts']).find { |p| p['role'] == 'drawer_bottom' }
    NxTest.assert_equal((bot['from'][0] - 4.0).round(2), bot['to'][0],
                        "#{bot['from'].inspect} -> #{bot['to'].inspect}")
    # Vyska aj NL sa v tejto dvojici NEMENIA — a dopad to musi POVEDAT
    # (rovnaka hodnota na oboch stranach), nie zamlcat.
    NxTest.assert_equal(imp['height']['from'], imp['height']['to'], imp['height'].inspect)
    NxTest.assert_equal(imp['nl']['from'], imp['nl']['to'], imp['nl'].inspect)
    NxTest.assert(imp['height']['to'].to_i.positive?, imp['height'].inspect)
    NxTest.assert_equal(NxD3b::V1, imp['from'])
    NxTest.assert_equal(NxD3b::V2, imp['to'])
    NxTest.assert(imp['release_note'].to_s.include?('chrbát'), imp['release_note'].inspect)
    # `to_title` = PLNY nazov do hlavicky okna; kratke `to_label` („v2") je
    # v PONUKE karty. Dva rozne texty = dva rozne kluce.
    NxTest.assert(imp['to_title'].to_s.include?('v2') && imp['to_title'] != 'v2',
                  imp['to_title'].inspect)
  end
end

NxTest.test('KOV-D3b (R2): zamok sa v dopade priznava ako PRENESENY s rovnakou hodnotou') do
  c = NxD3b
  cfg = c.cfg_for(c.params(overrides: [c.lock('nominal_length' => 420.0)]))
  c.with_v2 do
    imp, err = c.impact(cfg, NxD3b::V2)
    NxTest.assert(err.nil?, err.to_s)
    NxTest.assert_equal([{ 'axis' => 'nl', 'value' => 420.0, 'kept' => true }], imp['locks'])
    NxTest.assert_equal(420.0, imp['nl']['from'], 'zamknuta NL plati aj TERAZ')
    NxTest.assert_equal(420.0, imp['nl']['to'], 'a po prechode drzi rovnaku hodnotu')
  end
end

NxTest.test('KOV-D3b (R2): bez zamku je zoznam prazdny (nic sa neprenasa)') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    imp, = c.impact(cfg, NxD3b::V2)
    NxTest.assert_equal([], imp['locks'])
  end
end

NxTest.test('KOV-D3b (R2): kit sa uvadza kodmi z TEJ ISTEJ expanzie ako nakup') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    imp, = c.impact(cfg, NxD3b::V2)
    kit = imp['kit']
    NxTest.assert(kit['from'].is_a?(Array) && kit['to'].is_a?(Array), kit.inspect)
    # Vyska ani NL sa nemenia, takze kit ostava ten isty — a dopad to hovori.
    NxTest.assert_equal(kit['from'], kit['to'], kit.inspect)
  end
end

NxTest.test('KOV-D3b (R2): odmietnuty preflight = ziadny dopad, len dovod') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  before = JSON.generate(cfg)
  c.with_reg([NxD3b::V1, NxD3b::BAD]) do |d|
    c.r.with_test_dir(d) do
      imp, err = c.impact(cfg, NxD3b::BAD)
      NxTest.assert(imp.nil?, 'pri odmietnuti sa potvrdenie NEPONUKNE')
      NxTest.assert(err.to_s.include?('nesadne'), err.inspect)
    end
  end
  NxTest.assert_equal(before, JSON.generate(cfg), 'citacia cesta nezapisala NIC')
end

NxTest.test('KOV-D3b (R2): dopad sklada cisla z PREPARE, nie z druheho vypoctu') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    cab = c.cab_with(cfg)
    prep, err = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                         'from' => NxD3b::V1, 'to' => NxD3b::V2)
    NxTest.assert(err.nil?, err.to_s)
    # `side` = CIELOVY stav, ktory postavil preflight; presne ten sa aj zapise
    # (`params`). Keby dopad ratal ciel znova, tato rovnost by nic nedokazovala
    # — preto sa porovnava PROTI ZAPISOVANEMU stavu.
    imp = c.panel.drawer_upgrade_impact(nil, cab, prep)
    NxTest.assert_equal(prep[:side][:params]['nominal_length'], imp['nl']['to'])
    NxTest.assert_equal(prep[:side][:params]['height_variant'], imp['height']['to'])
    NxTest.assert_equal(prep[:side][:codes], imp['kit']['to'])
    # Dielce su v `side` klucovane `part_key` (Quadro vydava `box_side` dvakrat).
    to_back = prep[:side][:parts]['front:F1/drawer_back']
    NxTest.assert_equal(to_back[:dims],
                        Array(imp['parts']).find { |p| p['role'] == 'drawer_back' }['to'])
    NxTest.assert_equal(NxD3b::V2, prep[:params]['fronts']['items'][0]['drawer']['recipe_refs']['atira|sisy'],
                        'a je to naozaj ten config, ktory by sa zapisal')
  end
end

# ============================================================================
# R4 — ODPOVED CAKAJUCEMU MODALU (korelacny token)
# ============================================================================

# Zachytenie serveroveho kanala. Alias + navrat je JEDINY bezpecny sposob:
# `js` aj `set_status` su SKUTOCNE metody panela (vzor `NxD2bJs`).
module NxD3bJs
  def self.capture(*names)
    sc = Noxun::Engine::Panel.singleton_class
    out = { js: [], status: [] }
    names.each { |m| sc.send(:alias_method, :"d3b_orig_#{m}", m) }
    sc.send(:define_method, :js) { |script| out[:js] << script } if names.include?(:js)
    if names.include?(:set_status)
      sc.send(:define_method, :set_status) { |msg, err = false| out[:status] << [msg, err] }
    end
    yield out
  ensure
    names.each do |m|
      sc.send(:remove_method, m)
      sc.send(:alias_method, m, :"d3b_orig_#{m}")
      sc.send(:remove_method, :"d3b_orig_#{m}")
    end
  end
end

NxTest.test('KOV-D3b (R4): odpoved sa posiela LEN k tokenu a nesie ho spat') do
  c = NxD3b
  NxD3bJs.capture(:js) do |out|
    c.panel.push_upgrade_result(nil, false, 'nieco')
    c.panel.push_upgrade_impact(nil, false, 'nieco')
    NxTest.assert_equal([], out[:js], 'bez tokenu ziadne okno neceka — nic sa neposiela')
    c.panel.push_upgrade_result('u3', false, 'Stav zásuvky sa medzitým zmenil.')
    NxTest.assert(out[:js].first.start_with?('NX.hwUpgradeResult(false,'), out[:js].first)
    NxTest.assert(out[:js].first.include?('"u3"'), out[:js].first)
    NxTest.assert(out[:js].first.include?('Stav zásuvky sa medzitým zmenil.'), out[:js].first)
    c.panel.push_upgrade_result('u4', true, '')
    NxTest.assert(out[:js].last.start_with?('NX.hwUpgradeResult(true,'), out[:js].last)
  end
end

NxTest.test('KOV-D3b (R4): citaci kanal je VLASTNY a odmietnutie nesie dovod') do
  c = NxD3b
  NxD3bJs.capture(:js) do |out|
    c.panel.push_upgrade_impact('u9', false, 'Cieľ nesadne.')
    NxTest.assert(out[:js].first.start_with?('NX.hwUpgradeImpact('), out[:js].first)
    NxTest.assert(out[:js].first.include?('"ok":false'), out[:js].first)
    NxTest.assert(out[:js].first.include?('Cieľ nesadne.'), out[:js].first)
    NxTest.assert(out[:js].first.include?('"u9"'), out[:js].first)
    out[:js].clear
    c.panel.push_upgrade_impact('u9', true, nil, 'height' => { 'from' => 144, 'to' => 144 })
    NxTest.assert(out[:js].first.include?('"ok":true'), out[:js].first)
    NxTest.refute(out[:js].first.include?('reason'), 'pri uspechu sa dovod neposiela')
    NxTest.assert(out[:js].first.include?('"height"'), out[:js].first)
    out[:js].clear
    # Kluc rozhodnutia sa nastavuje AZ NAKONIEC — obsah dopadu ho neprepise.
    c.panel.push_upgrade_impact('u9', true, nil, 'ok' => false)
    NxTest.assert(out[:js].first.include?('"ok":true'), out[:js].first)
  end
end

NxTest.test('KOV-D3b (R4): odmietnutie odomkne modal aj bez vlastneho statusu') do
  c = NxD3b
  NxD3bJs.capture(:js, :set_status) do |out|
    c.panel.upgrade_fail('u1', 'Najprv označ NOXUN korpus.')
    NxTest.assert_equal([['Najprv označ NOXUN korpus.', true]], out[:status])
    NxTest.assert_equal(1, out[:js].length, 'a modal dostane odpoved TIEZ')
    out[:status].clear
    out[:js].clear
    # `foreign_document?` si status nastavuje sam — druhy by ten prvy prekryl.
    c.panel.upgrade_fail('u1', 'Verzia receptu sa nezmenila.', status: false)
    NxTest.assert_equal([], out[:status], 'status uz nastavil volajuci')
    NxTest.assert_equal(1, out[:js].length, 'modal sa aj tak odomkne')
  end
end

NxTest.test('KOV-D3b (R4): KAZDA vetva oboch handlerov odpoveda cakajucemu oknu') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_upgrade_drawer_recipe.*?\n        end\n/m].to_s
  NxTest.assert(body.include?("tok = axis_token(data['up_token'])"),
                'token sa cita PRED prvym navratom')
  NxTest.refute(body.include?('return set_status('),
                'ziadna vetva nesmie skoncit len statusom — modal by ostal zamknuty navzdy')
  NxTest.assert(body.rindex("push_upgrade_result(tok, true, '')") > body.rindex('push_selected(model)'),
                'poradie: najprv prekreslenie, potom „modal sa smie zavriet"')

  read = src[/def handle_drawer_upgrade_impact.*?\n        end\n/m].to_s
  NxTest.assert(read.include?("tok = axis_token(data['up_token'])"), read)
  NxTest.refute(read.include?('return set_status('), read)
  NxTest.refute(read.include?('start_operation') || read.include?('CabinetBuilder.rebuild'),
                'citaci callback NESMIE zapisat do modelu ani otvorit operaciu')
  NxTest.assert_equal(6, read.scan('push_upgrade_impact(').length,
                      'kazda vetva citacieho callbacku odpoveda (4 odmietnutia + uspech + rescue)')
  # Zdielany `cb` wrapper vynimku zachyti a napise status — lenze modal odomyka
  # VYHRADNE volajuci (kontrakt D-15), takze bez odpovede by ostal zamknuty
  # navzdy a tlacidlo ponuky mrtve. Obe cesty preto maju vlastny rescue.
  NxTest.assert(body.include?('rescue StandardError') && read.include?('rescue StandardError'),
                'aj vynimka musi cakajucemu oknu odpovedat')
end

NxTest.test('KOV-D3b: registracia oboch callbackov v paneli') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("cb(dlg, 'upgrade_drawer_recipe')"),
                'D3a akciu nechala neregistrovanu — D3b ju ma zapojit')
  NxTest.assert(src.include?("cb(dlg, 'drawer_upgrade_impact')"), 'citaci callback dopadu')
end

# ============================================================================
# ZRKADLA A GUARDY
# ============================================================================

NxTest.test('KOV-D3b: osi zamku v dopade sedia s polami overridu aj s osami payloadu') do
  c = NxD3b
  sc = c.panel.singleton_class
  map = sc::UPGRADE_LOCK_AXES
  NxTest.assert_equal(%w[height nl], map.keys,
                      'kluce su OSI payloadu (`drawer_axes`) — inak by tabulka menovala inu os')
  NxTest.assert_equal([], map.values - sc::OVERRIDE_FIELDS,
                      'hodnoty musia byt polia, ktore zapis naozaj pozna')
end

NxTest.test('KOV-D3b: produkcny register sa touto davkou NEZMENIL') do
  c = NxD3b
  reg = c.r.released
  NxTest.assert_equal(%w[atira_p2o_v1 atira_sisy_v1 quadro_v6_p2o_v1 quadro_v6_sisy_v1],
                      reg.keys.sort, 'produkcny register sa zmenil')
  reg.each_key do |id|
    NxTest.assert_equal(1, c.r.parse_id(id)[:version],
                        "#{id}: v2 vznika az s realnou datovou zmenou, nie s UI davkou")
  end
end

# ============================================================================
# P1 (Codex #315 kolo 1) — ODTLACOK POTVRDENEHO NAHLADU
# ============================================================================
#
# Payload zapisu nesie len refy a identitu, takze medzi „ukáž dopad" a „Prejsť"
# sa skrinka moze zmenit (rozmery, materialy, mapovanie, Spat/Redo) a server by
# zapisal INY dopad, nez ktory pouzivatel potvrdil. `from` to nechyti — ten
# strazi len PRIPNUTY RECEPT.

NxTest.test('KOV-D3b (P1): nezmeneny stav = odtlacok sedi a zapis prejde') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    cab = c.cab_with(cfg)
    prep, err = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                         'from' => NxD3b::V1, 'to' => NxD3b::V2)
    NxTest.assert(err.nil?, err.to_s)
    imp = c.panel.drawer_upgrade_impact(nil, cab, prep)
    fp = c.panel.drawer_upgrade_fingerprint(cab, prep, imp)
    NxTest.assert(fp.is_a?(String) && fp.length == 32, fp.inspect)
    NxTest.assert_equal(nil,
                        c.panel.drawer_upgrade_preview_problem(nil, cab, prep, 'fingerprint' => fp),
                        'nad NEZMENENOU skrinkou musi zapis prejst')
    # Odtlacok je STABILNY: druhy vypocet nad tym istym stavom da to iste.
    imp2 = c.panel.drawer_upgrade_impact(nil, cab, prep)
    NxTest.assert_equal(fp, c.panel.drawer_upgrade_fingerprint(cab, prep, imp2))
  end
end

NxTest.test('KOV-D3b (P1): ZMENA skrinky medzi nahladom a zapisom = odmietnutie') do
  c = NxD3b
  c.with_v2 do
    # 1) nahlad nad povodnou skrinkou
    old = c.cab_with(c.cfg_for(c.params))
    prep, = c.panel.drawer_upgrade_prepare(nil, old, 'front_id' => 'F1',
                                                     'from' => NxD3b::V1, 'to' => NxD3b::V2)
    fp = c.panel.drawer_upgrade_fingerprint(old, prep,
                                            c.panel.drawer_upgrade_impact(nil, old, prep))

    # 2) medzitym sa skrinka zmenila (hlbka 500 -> 400 = INE dielce aj NL)
    changed = c.cfg_for(c.params(depth: 400.0))
    before = JSON.generate(changed)
    cab2 = c.cab_with(changed)
    prep2, err = c.panel.drawer_upgrade_prepare(nil, cab2, 'front_id' => 'F1',
                                                           'from' => NxD3b::V1, 'to' => NxD3b::V2)
    NxTest.assert(err.nil?, "zmenena skrinka sa musi dat postavit, inak test meria ine: #{err}")
    msg = c.panel.drawer_upgrade_preview_problem(nil, cab2, prep2, 'fingerprint' => fp)
    NxTest.assert(msg.to_s.include?('medzitým'),
                  "stary odtlacok nad novym stavom musi PADNUT: #{msg.inspect}")
    NxTest.assert_equal(before, JSON.generate(changed), 'overenie nezapisalo NIC')

    # A naopak: cerstvy odtlacok nad tym istym novym stavom prejde.
    fp2 = c.panel.drawer_upgrade_fingerprint(cab2, prep2,
                                             c.panel.drawer_upgrade_impact(nil, cab2, prep2))
    NxTest.assert_equal(nil, c.panel.drawer_upgrade_preview_problem(nil, cab2, prep2,
                                                                    'fingerprint' => fp2))
    NxTest.assert(fp != fp2, 'ina skrinka = iny odtlacok')
  end
end

NxTest.test('KOV-D3b (P1): CHYBAJUCI odtlacok je odmietnutie (fail-closed)') do
  c = NxD3b
  cfg = c.cfg_for(c.params)
  c.with_v2 do
    cab = c.cab_with(cfg)
    prep, = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                     'from' => NxD3b::V1, 'to' => NxD3b::V2)
    NxTest.assert(c.panel.drawer_upgrade_preview_problem(nil, cab, prep, {}).to_s.include?('medzitým'),
                  'zapis smie prist VYHRADNE z potvrdeneho nahladu')
    NxTest.assert(c.panel.drawer_upgrade_preview_problem(
      nil, cab, prep, 'fingerprint' => ''
    ).to_s.include?('medzitým'))
    NxTest.assert(c.panel.drawer_upgrade_preview_problem(
      nil, cab, prep, 'fingerprint' => 'cudzi'
    ).to_s.include?('medzitým'))
  end
end

NxTest.test('KOV-D3b (P1): ked payload nesie odtlacok, aj ZLYHANY PREFLIGHT hlasi „stav sa zmenil"') do
  c = NxD3b
  # In-SU beh nad `615a92f`: scenar zmensil hlbku tak, ze na novom stave uz
  # neplatil zamok NL — zapis odmietol PREFLIGHT a pouzivatel dostal jeho
  # SUROVY text („ručne zamknutá dĺžka 470 mm potrebuje hĺbku 485 mm…").
  # Lenze to je veta o stave, ktory NIKDY nevidel: on potvrdzoval nahlad nad
  # POVODNOU skrinkou. Odpoved musi byt ta ista ako pri nesediacom odtlacku.
  base = c.panel.singleton_class::UPGRADE_STALE_PREVIEW
  NxTest.assert_equal(base, c.panel.upgrade_stale_reason(nil), 'bez dovodu ostava hlaska sama')
  NxTest.assert_equal(base, c.panel.upgrade_stale_reason('   '))
  msg = c.panel.upgrade_stale_reason('Nová verzia receptu na túto zásuvku nesadne: hrúbka.')
  NxTest.assert(msg.start_with?(base.chomp('.')),
                "hlavna sprava ostava veta o zmene stavu: #{msg.inspect}")
  NxTest.assert(msg.include?('medzitým') && msg.include?('hrúbka'),
                "dovod sa PRIPOJI, nie nahradi: #{msg.inspect}")

  # Zdrojovy guard poradia: bez odtlacku ostava surovy dovod (cesta z testov
  # a in-SU sekcie D3a), s odtlackom sa prevedie na stale hlasku.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_upgrade_drawer_recipe.*?\n        rescue StandardError/m].to_s
  NxTest.assert(body.include?("from_preview = !present_str(data['fingerprint']).nil?"), body)
  NxTest.assert(body.include?('return upgrade_fail(tok, err) unless from_preview'),
                'bez odtlacku sa dovod NEPREPISUJE')
  NxTest.assert(body.include?('upgrade_fail(tok, upgrade_stale_reason(err))'),
                's odtlackom je odpoved JEDNA veta')
end

NxTest.test('KOV-D3b (P1): ODMIETNUTA cesta neotvori operaciu (ziadny krok Spat)') do
  c = NxD3b
  # In-SU beh nad `615a92f` hlasil aj „odmietnutie nenechalo ZIADNY krok Spat".
  # Bola to CHYBA SCENARA (marker lezal PRED prestavbou hlbky, takze `undo`
  # zrusil prestavbu, nie marker) — nie produktovy bug. Tento test to drzi
  # deterministicky: cela odmietnuta cesta (preflight AJ nesediaci odtlacok)
  # nesmie zavolat `CabinetBuilder.rebuild`, jedine miesto v tomto handleri,
  # ktore operaciu otvara.
  cfg = c.cfg_for(c.params)
  before = JSON.generate(cfg)
  c.with_v2 do
    cab = c.cab_with(cfg)
    prep, = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                     'from' => NxD3b::V1, 'to' => NxD3b::V2)
    builds = NxD3bOps.count do
      # (a) nesediaci odtlacok
      NxTest.assert(c.panel.drawer_upgrade_preview_problem(nil, cab, prep,
                                                           'fingerprint' => 'cudzi'))
      # (b) chybajuci odtlacok
      NxTest.assert(c.panel.drawer_upgrade_preview_problem(nil, cab, prep, {}))
      # (c) preflight nad cielom, ktory nesadne
      _p, e2 = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                        'from' => NxD3b::V1, 'to' => NxD3b::BAD)
      NxTest.assert(!e2.nil?)
    end
    NxTest.assert_equal(0, builds,
                        "odmietnutie NESMIE prestavat skrinku (#{builds} volani `rebuild`)")
  end
  NxTest.assert_equal(before, JSON.generate(cfg), 'a config skrinky ostava bajtovo rovnaky')
end

NxTest.test('KOV-D3b (P1): dopad NESIE odtlacok, ktory klient len vracia') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware.rb'),
                  encoding: 'UTF-8')
  read = src[/def handle_drawer_upgrade_impact.*?\n        end\n/m].to_s
  NxTest.assert(read.include?("impact['fingerprint'] = drawer_upgrade_fingerprint"),
                'citaci callback musi odtlacok POSLAT — inak ho klient nema odkial vratit')
  body = src[/def handle_upgrade_drawer_recipe.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('drawer_upgrade_preview_problem'),
                'zapisova cesta musi odtlacok OVERIT')
  NxTest.assert(body.index('drawer_upgrade_preview_problem') < body.index('CabinetBuilder.rebuild'),
                'overenie musi byt PRED zapisom, nie po nom')
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'),
                 encoding: 'UTF-8')
  NxTest.assert(js.include?('fingerprint: String((HW_UP.impact && HW_UP.impact.fingerprint)'),
                'klient odtlacok LEN vracia — nic z neho neskladá')
end

# ============================================================================
# P2 (Codex #315 kolo 1) — QUADRO: DVA BOKY BOXU A VYSKA BOXU
# ============================================================================

NxTest.test('KOV-D3b (P2): QUADRO ma v dopade OBA boky boxu (kluc je part_key, nie rola)') do
  c = NxD3b
  v1 = 'quadro_v6_sisy_v1'
  v2 = 'quadro_v6_sisy_v2'
  c.with_reg([v1, v2]) do |d|
    c.r.with_test_dir(d) do
      cab = c.cab_with(c.cfg_for(c.quadro_params))
      prep, err = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                           'from' => v1, 'to' => v2)
      NxTest.assert(err.nil?, err.to_s)
      imp = c.panel.drawer_upgrade_impact(nil, cab, prep)
      sides = Array(imp['parts']).select { |p| p['role'] == 'box_side' }
      NxTest.assert_equal(2, sides.length,
                          "Quadro vydava DVA boky — mapa klucovana rolou by jeden zahodila: #{imp['parts'].inspect}")
      NxTest.assert_equal(5, Array(imp['parts']).length, 'a spolu PAT dielcov')
      NxTest.assert_equal(['bok boxu — pravý', 'bok boxu — ľavý'].sort,
                          sides.map { |p| p['label'] }.sort,
                          'oba riadky musia byt rozlisitelne')
      NxTest.assert(sides.all? { |p| Array(p['to']).length == 3 }, sides.inspect)
    end
  end
end

NxTest.test('KOV-D3b (P2): QUADRO vysku nesie `box_height` (nie H variant)') do
  c = NxD3b
  v1 = 'quadro_v6_sisy_v1'
  v2 = 'quadro_v6_sisy_v2'
  c.with_reg([v1, v2]) do |d|
    c.r.with_test_dir(d) do
      cab = c.cab_with(c.cfg_for(c.quadro_params))
      prep, = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1', 'from' => v1, 'to' => v2)
      h = c.panel.drawer_upgrade_impact(nil, cab, prep)['height']
      NxTest.assert_equal('box', h['kind'], "Quadro nema `height_variant`: #{h.inspect}")
      NxTest.assert(h['from'].is_a?(Numeric) && h['to'].is_a?(Numeric),
                    "bez toho by modal ukazal prazdnu vysku: #{h.inspect}")
    end
  end
end

NxTest.test('KOV-D3b (P2): ATIRA vysku nesie ako H variant') do
  c = NxD3b
  c.with_v2 do
    cab = c.cab_with(c.cfg_for(c.params))
    prep, = c.panel.drawer_upgrade_prepare(nil, cab, 'front_id' => 'F1',
                                                     'from' => NxD3b::V1, 'to' => NxD3b::V2)
    h = c.panel.drawer_upgrade_impact(nil, cab, prep)['height']
    NxTest.assert_equal('variant', h['kind'], h.inspect)
    NxTest.assert_equal(144, h['to'].to_i, h.inspect)
  end
end

# ============================================================================
# P2 (Codex #315 kolo 1) — REGISTER RECEPTOV SA CITA RAZ ZA PUSH
# ============================================================================

# Pocitadlo PRESTAVIEB. `CabinetBuilder.rebuild` je jedine miesto zapisovej
# cesty upgradu, ktore otvara `start_operation` — ked ho odmietnuta vetva
# nezavola, nemohla vzniknut ani polozka undo stacku.
module NxD3bOps
  def self.count
    sc = Noxun::Engine::CabinetBuilder.singleton_class
    n = 0
    sc.send(:alias_method, :d3b_orig_rebuild, :rebuild)
    sc.send(:define_method, :rebuild) { |*_a, **_kw| n += 1 }
    yield
    n
  ensure
    sc.send(:remove_method, :rebuild)
    sc.send(:alias_method, :rebuild, :d3b_orig_rebuild)
    sc.send(:remove_method, :d3b_orig_rebuild)
  end
end

module NxD3bIo
  # Pocitadlo REALNYCH citani `RELEASED.json` (z cache sa vracia skor).
  def self.count
    sc = Noxun::Engine::Recipes.singleton_class
    n = 0
    sc.send(:alias_method, :d3b_orig_parse_json, :parse_json)
    sc.send(:define_method, :parse_json) do |path|
      n += 1 if File.basename(path.to_s) == 'RELEASED.json'
      d3b_orig_parse_json(path)
    end
    yield
    n
  ensure
    sc.send(:remove_method, :parse_json)
    sc.send(:alias_method, :parse_json, :d3b_orig_parse_json)
    sc.send(:remove_method, :d3b_orig_parse_json)
  end
end

NxTest.test('KOV-D3b (P2): ponuka cita register RAZ, aj ked ma skrinka viac zasuviek') do
  c = NxD3b
  # Tri zasuvkove cela — bez zdielania by kazde spustilo `active_ref`
  # + `latest_for` (a s v2 aj `load` s odtlackom) samostatne.
  items = %w[F1 F2 F3].map do |fid|
    { 'id' => fid, 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 220.0,
      'opening_mode' => 'classic',
      'drawer' => { 'construction' => 'metal', 'system' => 'atira',
                    'recipe_refs' => { 'atira|sisy' => NxD3b::V1 } } }
  end
  par = c.params
  par['height'] = 1200.0
  par['fronts'] = { 'items' => items }
  cfg = c.cfg_for(par)
  c.with_v2 do
    map = c.panel.front_drawer_payload(cfg)
    NxTest.assert_equal(3, map.keys.length, 'test potrebuje TRI zasuvky')
    reads = NxD3bIo.count { c.panel.attach_front_drawer_upgrade(map, cfg, 'CAB-1') }
    NxTest.assert_equal(1, reads,
                        "register sa smie precitat RAZ za prechod, nie per zasuvka (#{reads})")
    NxTest.assert(map.values.all? { |row| row['upgrade'].is_a?(Hash) },
                  'a vsetky tri zasuvky musia ponuku dostat')
  end
end

NxTest.test('KOV-D3b (P2): cache registra NEPREZIJE blok (zmena medzi pushmi sa prejavi)') do
  c = NxD3b
  NxTest.assert_equal(nil, c.r.instance_variable_get(:@register_cache),
                      'mimo bloku sa nekesuje nic')
  c.r.with_register_cache do
    NxTest.assert(c.r.instance_variable_get(:@register_cache).is_a?(Hash))
    c.r.released
    c.r.released
  end
  NxTest.assert_equal(nil, c.r.instance_variable_get(:@register_cache),
                      'po bloku cache zaniká — dalsi push cita register znova')
  begin
    c.r.with_register_cache { raise 'boom' }
  rescue StandardError
    nil
  end
  NxTest.assert_equal(nil, c.r.instance_variable_get(:@register_cache),
                      'cache zaniká AJ po vynimke')
end

NxTest.test('KOV-D3b (P2): poskodeny register sa NEZAKESUJE ako platny') do
  c = NxD3b
  Dir.mktmpdir('noxun-kovd3b-bad-') do |d|
    File.write(File.join(d, 'RELEASED.json'), "{\"nieco\": \"zle\"}\n")
    c.r.with_register_cache do
      2.times do
        raised = begin
          c.r.released(dir: d)
          false
        rescue c.r::RecipeError
          true
        end
        NxTest.assert(raised, 'poskodeny register musi padnut POKAZDE, nie len prvykrat')
      end
    end
  end
end
