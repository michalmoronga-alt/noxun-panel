# frozen_string_literal: true
# Testy KOV-D2b: ZAMKY OSI — UI, SERVEROVA STRANA. Karta cela dostava TEN ISTY
# stav osi ako sekcia Kovanie (jeden zdroj) + identitu zapisu, aby sa z nej
# dalo zamykat a odomykat.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 `front_drawer[fid]` nesie `axes` — a je to TA ISTA mapa, ktoru dostava
#      polozka vysuvu (`drawer_axes_map`); ziadny druhy vypocet
#   R2 `front_drawer[fid]` nesie `lock` = identitu zapisu (owner_part_key,
#      generic_type `slide`, rule_id `recipe:<id>`, cabinet_id) — panel si ju
#      NESKLADA, `recipe:<id>` pozna len server
#   R3 konfliktna zasuvka dostava chipy tiez (prave z nej sa musi dat odomknut)
#   R4 lahky push (`front_drawer_refresh`) nesie to iste, co plny push — inak
#      by zmena mapovania v Studiu zmazala zamky z otvorenej karty
#   R5 charakterizacia: zakazka BEZ klasifikovanej zasuvky ma payload PRESNE
#      taky, aky mala pred davkou (ziadne nove kluce, ziadny plan navyse)
#   R6 recept sa nacitava RAZ — `drawer_axes_index` dava stav aj identitu
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
#   M1 `attach_front_drawer_axes` sklada `axes` znovu (nie z indexu)
#      -> „KOV-D2b (R1): karta a sekcia Kovanie citaju JEDEN objekt"
#   M2 `lock.rule_id` sa sklada z `front_id` namiesto receptu
#      -> „KOV-D2b (R2): identita zapisu je RECEPTOVA a ide zo servera"
#   M3 lahky push vrati holy `front_drawer_payload` (bez osi)
#      -> „KOV-D2b (R4): lahky push nesie stav osi TIEZ"
# Codex #313 kolo 1 (P2-1 — odpoved cakajucemu modalu):
#   M4 vetva handlera skonci len `set_status` (modal ostane zamknuty navzdy)
#      -> „KOV-D2b (P2-1): KAZDA vetva handlera odpoveda cakajucemu modalu"
#   M5 `push_axis_result` posiela odpoved aj BEZ tokenu
#      -> „KOV-D2b (P2-1): odpoved sa posiela LEN k tokenu a nesie ho spat"
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxD2b
  module_function

  def e
    Noxun::Engine
  end

  def cb
    e::CabinetBuilder
  end

  def panel
    e::Panel
  end

  OWNER = 'front:F1/panel'
  RID   = 'recipe:atira_sisy_v1'
  CAB   = 'CAB-1'

  # Zakazka je ZHODNA s fixturou D2a (spodna skrinka 900x720x500, jedno
  # zasuvkove celo F1) — cisla (H70, NL 470) tak sedia s tym, co Michal vidi.
  def params(front_height: 175.0, depth: 500.0, front: {})
    item = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
             'height' => front_height, 'opening_mode' => 'classic',
             'drawer' => { 'construction' => 'metal' } }.merge(front)
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => depth,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [item] } }
  end

  # Zakazka BEZ zasuvky — charakterizacia (payload sa nesmie zmenit).
  def params_door
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed',
                                  'height' => 600.0, 'opening_mode' => 'classic' }] } }
  end

  def ov(fields, rid = RID, owner = OWNER)
    [{ 'owner_part_key' => owner, 'generic_type' => 'slide', 'rule_id' => rid }.merge(fields)]
  end

  def cfg_for(par, overrides = [])
    norm = cb.normalize(par.merge('hardware_overrides' => overrides))
    plan = e::Construction.build_plan(norm, CAB,
                                      part_thicknesses: cb.drawer_thicknesses(norm, {}))
    JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(norm, plan))))
  end

  # Payload karty PRESNE tak, ako ho sklada plny push (`cabinet_payload`):
  # riadok zasuvky D1b + stav osi D2b nad TYM ISTYM indexom.
  def card_for(par, overrides = [])
    cfg = cfg_for(par, overrides)
    index = panel.drawer_axes_index(cfg, cb.config_to_params(cfg))
    [cfg, index, panel.attach_front_drawer_axes(panel.front_drawer_payload(cfg), index, CAB)]
  end
end

# ============================================================================
# R1 + R2 — KARTA CELA DOSTANE STAV OSI A IDENTITU ZAPISU
# ============================================================================

NxTest.test('KOV-D2b (R1): karta a sekcia Kovanie citaju JEDEN objekt') do
  c = NxD2b
  _cfg, index, card = c.card_for(c.params)
  row = card['F1']
  NxTest.assert(row.is_a?(Hash), card.inspect)
  NxTest.assert_equal('ok', row['state'], 'vyriesena zasuvka ostava riadkom C2c')
  NxTest.assert(row['axes'].equal?(index['by_owner'][c::OWNER]),
                'karta dostava TU ISTU instanciu, nie druhy vypocet toho isteho')
  NxTest.assert_equal('auto', row['axes']['height']['state'])
  NxTest.assert_equal([70], row['axes']['height']['options'])
  NxTest.assert_equal([350.0, 420.0, 470.0], row['axes']['nl']['options'])
end

NxTest.test('KOV-D2b (R2): identita zapisu je RECEPTOVA a ide zo servera') do
  c = NxD2b
  _cfg, _index, card = c.card_for(c.params)
  lock = card['F1']['lock']
  NxTest.assert_equal({ 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
                        'rule_id' => c::RID, 'cabinet_id' => c::CAB }, lock,
                      'presne to, co ocakava `handle_set_hardware_override`')
end

NxTest.test('KOV-D2b (R2): Quadro nedostane os `height` ani na karte') do
  c = NxD2b
  _cfg, _index, card = c.card_for(c.params(front: { 'drawer' => { 'construction' => 'wood' } }))
  ax = card['F1']['axes']
  NxTest.refute(ax.key?('height'), 'chip vysky sa pri Quadre nema z coho nakreslit')
  NxTest.assert_equal('auto', ax['nl']['state'])
  NxTest.assert_equal('recipe:quadro_v6_sisy_v1', card['F1']['lock']['rule_id'],
                      'identita ukazuje na PRIPNUTY recept toho cela')
end

NxTest.test('KOV-D2b (R1): zamknuta os prichadza na kartu ako `locked`') do
  c = NxD2b
  _cfg, _index, card = c.card_for(c.params, c.ov('height_variant' => 70))
  NxTest.assert_equal('locked', card['F1']['axes']['height']['state'])
  NxTest.assert_equal(70, card['F1']['axes']['height']['value'],
                      'hodnota do zapisu ide z payloadu, nie z textu riadku')
end

# ============================================================================
# R3 — KONFLIKTNA ZASUVKA
# ============================================================================

NxTest.test('KOV-D2b (R3): konfliktna karta nesie chipy aj identitu (cesta von)') do
  c = NxD2b
  cfg, _index, card = c.card_for(c.params, c.ov('height_variant' => 176))
  NxTest.assert_equal(nil, Array(cfg['hardware']).find { |h| h['source'] == 'recipe' },
                      'fail-closed: polozka vysuvu nevznikla')
  row = card['F1']
  NxTest.assert_equal('conflict', row['state'], 'riadok ostava cervenym dovodom stavby')
  NxTest.assert_equal('conflict', row['axes']['height']['state'])
  NxTest.assert(!row['axes']['height']['message'].to_s.empty?,
                'os v konflikte MA hlasku (invariant D2a)')
  NxTest.assert_equal('height', row['axes']['nl']['blocked_by'],
                      'NL sa nema z coho ponukat, kym neplati vyska')
  NxTest.assert_equal(c::RID, row['lock']['rule_id'],
                      'odomknut sa musi dat aj karta BEZ emitovanej polozky')
end

NxTest.test('KOV-D2b (R3): navrh nahrady prichadza na kartu z receptu') do
  c = NxD2b
  _cfg, _index, card = c.card_for(c.params, c.ov('height_variant' => 70,
                                                 'nominal_length' => 620.0))
  nl = card['F1']['axes']['nl']
  NxTest.assert_equal('conflict', nl['state'])
  NxTest.assert_close(470.0, nl['proposal'], 0.001, 'hodnota tlacidla „Nahradiť za"')
  NxTest.assert_equal('locked', card['F1']['axes']['height']['state'], 'druhy zamok ostava')
end

# ============================================================================
# R4 — LAHKY PUSH
# ============================================================================

NxTest.test('KOV-D2b (R4): lahky push nesie stav osi TIEZ') do
  c = NxD2b
  cfg = c.cfg_for(c.params, c.ov('height_variant' => 70))
  light = c.panel.front_drawer_refresh(cfg, c::CAB)
  _cfg2, _index, full = c.card_for(c.params, c.ov('height_variant' => 70))
  NxTest.assert_equal(full['F1']['axes'], light['F1']['axes'],
                      'inak by zmena mapovania v Studiu zmazala zamky z otvorenej karty')
  NxTest.assert_equal(full['F1']['lock'], light['F1']['lock'])
end

# ============================================================================
# R5 — CHARAKTERIZACIA (zakazka bez zasuviek)
# ============================================================================

NxTest.test('KOV-D2b (R5): zakazka BEZ zasuvky ma payload nezmeneny') do
  c = NxD2b
  cfg = c.cfg_for(c.params_door)
  before = c.panel.front_drawer_payload(cfg)
  index = c.panel.drawer_axes_index(cfg, c.cb.config_to_params(cfg))
  NxTest.assert_equal({}, index['by_owner'], 'ziadna os = ziadny stav')
  NxTest.assert_equal({}, index['idents'], 'ziadna os = ziadna identita')
  NxTest.assert_equal(before, c.panel.attach_front_drawer_axes(before, index, c::CAB),
                      'dvierkova zakazka sa D2b nedotkla')
  NxTest.assert_equal(before, c.panel.front_drawer_refresh(cfg, c::CAB),
                      'ani cez lahky push')
end

NxTest.test('KOV-D2b (R5): `stale` zaznam ostava BEZ osi') do
  c = NxD2b
  # Skrinka ulozena PRED aktivaciou receptov: schema je nizsia A polozka
  # vysuvu v configu chyba. Karta ma povedat „prestav skrinku", nie ponukat
  # zamky nad polozkou, ktora neexistuje.
  cfg = c.cfg_for(c.params)
  cfg['config_schema'] = c.cb::DRAWER_ACTIVATION_SCHEMA - 1
  cfg['hardware'] = []
  row = c.panel.front_drawer_payload(cfg)['F1']
  NxTest.assert_equal('stale', row['state'])
  NxTest.refute(row.key?('axes'), 'stary zaznam nema co zamykat')
end

# ============================================================================
# P2-1 — ODPOVED CAKAJUCEMU MODALU NAHRADY (korelacny token)
# ============================================================================
#
# Kostra D-15: zapis okno NEZATVARA — zatvorit ho smie az volajuci, ked server
# zapis POTVRDI. Server preto musi odpovedat v KAZDEJ vetve, a to tokenom,
# ktory mu klient poslal (vzor KOV-H2 `manual_token`).

# Zachytenie serveroveho kanala. Alias + navrat je JEDINY bezpecny sposob:
# `js` aj `set_status` su SKUTOCNE metody panela, takze `remove_method` bez
# obnovy by ich zmazal aj vsetkym nasledujucim sadam (vzor `NxKovh2Js`).
module NxD2bJs
  def self.capture(*names)
    sc = Noxun::Engine::Panel.singleton_class
    out = { js: [], status: [] }
    names.each { |m| sc.send(:alias_method, :"d2b_orig_#{m}", m) }
    sc.send(:define_method, :js) { |script| out[:js] << script } if names.include?(:js)
    if names.include?(:set_status)
      sc.send(:define_method, :set_status) { |msg, err = false| out[:status] << [msg, err] }
    end
    yield out
  ensure
    names.each do |m|
      sc.send(:remove_method, m)
      sc.send(:alias_method, m, :"d2b_orig_#{m}")
      sc.send(:remove_method, :"d2b_orig_#{m}")
    end
  end
end

NxTest.test('KOV-D2b (P2-1): token je uzavrety tvar — String/Integer, orezany') do
  c = NxD2b
  NxTest.assert_equal('a7', c.panel.axis_token('a7'))
  NxTest.assert_equal('12', c.panel.axis_token(12), 'cele cislo je platny token')
  NxTest.assert_equal(nil, c.panel.axis_token(nil), 'bez tokenu ziadne okno neceka')
  NxTest.assert_equal(nil, c.panel.axis_token(''), 'prazdny retazec nie je token')
  NxTest.assert_equal(nil, c.panel.axis_token({ 'x' => 1 }),
                      'do `execute_script` sa nesmie dostat lubovolny objekt')
  NxTest.assert_equal(nil, c.panel.axis_token(['a']))
  max = c.panel.singleton_class::AXIS_TOKEN_MAX
  NxTest.assert_equal(max, c.panel.axis_token('x' * 100).length,
                      'token sa oreze na pevnu dlzku')
end

NxTest.test('KOV-D2b (P2-1): odpoved sa posiela LEN k tokenu a nesie ho spat') do
  c = NxD2b
  NxD2bJs.capture(:js) do |out|
    c.panel.push_axis_result(nil, false, 'nieco')
    NxTest.assert_equal([], out[:js], 'klik na chip ziadne okno neceka — nic sa neposiela')
    c.panel.push_axis_result('a3', false, 'Návrh sa medzitým zmenil.')
    NxTest.assert_equal(1, out[:js].length)
    NxTest.assert(out[:js].first.start_with?('NX.hwAxResult(false,'), out[:js].first)
    NxTest.assert(out[:js].first.include?('"a3"'),
                  'echo nesie TOKEN — inak by odpoved nemal komu patrit')
    NxTest.assert(out[:js].first.include?('Návrh sa medzitým zmenil.'),
                  'a dovod, ktory sa ukaze V MODALI')
    c.panel.push_axis_result('a4', true, '')
    NxTest.assert(out[:js].last.start_with?('NX.hwAxResult(true,'), out[:js].last)
  end
end

NxTest.test('KOV-D2b (P2-1): odmietnutie odomkne modal aj bez vlastneho statusu') do
  c = NxD2b
  NxD2bJs.capture(:js, :set_status) do |out|
    c.panel.axis_fail('a9', 'Najprv označ NOXUN korpus.')
    NxTest.assert_equal([['Najprv označ NOXUN korpus.', true]], out[:status])
    NxTest.assert_equal(1, out[:js].length, 'a modal dostane odpoved TIEZ')
    out[:status].clear
    out[:js].clear
    # `foreign_document?` si status nastavuje sam — druhy by ten prvy prekryl.
    c.panel.axis_fail('a9', 'Kovanie sa nezmenilo.', status: false)
    NxTest.assert_equal([], out[:status], 'status uz nastavil volajuci')
    NxTest.assert_equal(1, out[:js].length, 'modal sa aj tak odomkne')
  end
end

NxTest.test('KOV-D2b (P2-1): KAZDA vetva handlera odpoveda cakajucemu modalu') do
  c = NxD2b
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_set_hardware_override.*?\n        end\n/m].to_s
  NxTest.assert(body.include?("tok = axis_token(data['ax_token'])"),
                'token sa cita PRED prvym navratom')
  NxTest.refute(body.include?('return set_status('),
                'ziadna vetva nesmie skoncit len statusom — modal by ostal zamknuty navzdy')
  NxTest.assert(body.include?("push_axis_result(tok, true, '')"),
                'uspech sa hlasi AZ za `push_selected` (panel je vtedy prekresleny)')
  NxTest.assert(body.rindex("push_axis_result(tok, true, '')") > body.rindex('push_selected(model)'),
                'poradie: najprv prekreslenie, potom „modal sa smie zavriet"')
end

# ============================================================================
# R6 — INDEX (jeden prechod, jedno nacitanie receptu)
# ============================================================================

NxTest.test('KOV-D2b (R6): `drawer_axes_map` ostava tvarom `owner -> osi`') do
  c = NxD2b
  cfg = c.cfg_for(c.params)
  par = c.cb.config_to_params(cfg)
  NxTest.assert_equal(c.panel.drawer_axes_index(cfg, par)['by_owner'],
                      c.panel.drawer_axes_map(cfg, par),
                      'kontrakt D2a (a in-SU scenar `run_kovd2a`) sa nemeni')
end

NxTest.test('KOV-D2b (R6): identita NEPOTREBUJE druhe citanie receptu') do
  c = NxD2b
  cfg = c.cfg_for(c.params)
  par = c.cb.config_to_params(cfg)
  index = c.panel.drawer_axes_index(cfg, par)
  map = c.panel.front_drawer_payload(cfg)
  loads = 0
  orig = c.e::Recipes.method(:load)
  c.e::Recipes.define_singleton_method(:load) do |*args, **kw|
    loads += 1
    orig.call(*args, **kw)
  end
  begin
    c.panel.attach_front_drawer_axes(map, index, c::CAB)
  ensure
    c.e::Recipes.define_singleton_method(:load, orig)
  end
  NxTest.assert_equal(0, loads,
                      '`Recipes.load` cita subor a overuje odtlacok — druhy prechod kvoli ' \
                      'identite by bol druhy diskovy pristup na KAZDY push panela')
end
