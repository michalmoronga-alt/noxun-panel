# frozen_string_literal: true
# Testy KOV-D3a: UPGRADE RECEPTU — JEDNO CELO, JADRO (latentny ramec).
#
# V repe su LEN recepty v1 a ziadny dovod na v2, preto sa cely ramec overuje
# nad FIXTURNYM registrom `tests/fixtures/recipes_d3a` (vzor C1). Produkcny
# register aj `data/recipes/` ostavaju NEDOTKNUTE — strazi to vlastny guard.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 akcia meni PRESNE JEDEN zaznam mapy `recipe_refs` jedneho cela; overuje
#      ocakavany stary ref, vydany ciel, rovnaky system aj otvaranie a VYSSIU
#      verziu (ziadny downgrade)
#   R2 PREFLIGHT pred zapisom TYMI ISTYMI funkciami ako stavba (hrubky, oba
#      zamky po preadresovani `recipe:<v1>` -> `recipe:<v2>`, `resolve`,
#      expanzia setu) — konflikt alebo chybajuci kit = NEULOZI SA NIC
#   R4 `pick_ref` pri mape s VIAC verziami = najnizsia dostupna surodenecka
#      verzia LEN z VALIDOVANYCH zaznamov
#   R5 `release_note` = volitelne pole schemy, prenesene do nacitaneho receptu
#   R6 fixturny register + guard „produkcny register bez v2"; testovaci seam
#      pre priecinok receptov (`Recipes.with_test_dir`)
#
# FIXTURNY REGISTER (`tests/fixtures/recipes_d3a`):
#   atira_sisy_v1      BAJTOVA kopia produkcneho receptu (odtlacok sedi)
#   atira_sisy_v2      dobry ciel: chrbat H144 120 mm, dno o 4 mm uzsie
#   atira_sisy_v3      hrubky len 18 mm -> preflight odmietne 16 mm zasuvku
#   atira_sisy_v4      rad H144 konci na 420 -> zamknuta NL 470 v nom neplati
#   atira_sisy_v5      rad H144 len NL 620 -> sety k nej nemaju kod (kit)
#   quadro_v6_sisy_v2  ciel INEHO systemu (nikdy sa neprijme)
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M1 `Recipes.upgrade?` pripusti rovnaku/nizsiu verziu (`>` -> `>=`)
#      -> „KOV-D3a (R1): rovnaka ani nizsia verzia neprejde — ziadny downgrade"
#   M2 `drawer_upgrade_prepare` vynecha preflight
#      -> „KOV-D3a (R2): nesediaca hrubka cieloveho receptu = ZIADNY zapis"
#   M3 `pick_ref` berie surodenca aj z NEPLATNEHO zaznamu mapy
#      -> „KOV-D3a (R4): neplatny zaznam mapy vyber surodenca NEOVPLYVNI"
#   M4 `readdress_recipe_locks` preadresovany zaznam nepripoji (zamok sa strati)
#      -> „KOV-D3a (R2): uspesny upgrade PREADRESUJE zamky aj s hodnotami"
require_relative '../helper' unless defined?(NxTest)
require 'tmpdir'

# Panelove akcie nie su v require zozname helpera (vzor KOV-D1a/D2a).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware')
end

module NxD3a
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

  FIX = File.join(NxTest::ROOT, 'tests', 'fixtures', 'recipes_d3a')
  OWNER = 'front:F1/panel'
  V1 = 'atira_sisy_v1'
  V2 = 'atira_sisy_v2'

  def rid(id)
    "recipe:#{id}"
  end

  # --- fixturne registre pre `pick_ref` (C1 vzor: vlastny tmpdir + odtlacky) --
  #
  # Telo receptu sa klonuje z PRODUKCNEHO packu podla systemu (Atira =
  # metal_box, Quadro = wood_undermount) — schema sa validuje prisne, takze
  # vymysleny fragment by neprešiel.
  def body_for(id)
    p = r.parse_id(id)
    base = JSON.parse(File.read(File.join(r::DIR, "#{p[:system]}_sisy_v1.json"), encoding: 'UTF-8'))
    base.merge('recipe_id' => id, 'opening' => p[:opening], 'version' => p[:version])
  end

  def with_reg(ids)
    Dir.mktmpdir('noxun-kovd3a-') do |d|
      reg = {}
      ids.each do |id|
        raw = "#{JSON.pretty_generate(body_for(id))}\n"
        File.write(File.join(d, "#{id}.json"), raw)
        reg[id] = Digest::SHA256.hexdigest(raw.gsub("\r\n", "\n"))
      end
      File.write(File.join(d, 'RELEASED.json'), "#{JSON.pretty_generate(reg)}\n")
      yield d
    end
  end

  # --- zakazka: spodna skrinka 900x720, jedno zasuvkove celo F1 (Atira SiSy) --
  #
  # `refs` sa pinuje EXPLICITNE — inak by `pick_ref` nad fixturnym registrom
  # siahol po `latest_for` (v5) a fixtura by merala iny recept, nez o com je test.
  def params(front_height: 175.0, depth: 500.0, refs: { 'atira|sisy' => V1 },
             overrides: [], extra_front: nil)
    drawer = { 'construction' => 'metal', 'system' => 'atira' }
    drawer['recipe_refs'] = refs if refs
    items = [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
               'height' => front_height, 'opening_mode' => 'classic', 'drawer' => drawer }]
    items << extra_front if extra_front
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => depth,
      'thickness' => 18.0, 'floor_height' => 100.0, 'hardware_overrides' => overrides,
      'fronts' => { 'items' => items } }
  end

  # ULOZENY config skrinky presne tak, ako ho po stavbe vidi panel (vzor D2a).
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

  # Akcia upgradu nad fixturnym registrom. Model je `nil` — headless nema
  # SketchUp dokument, takze sety sa citaju z globalnej kniznice (`:missing`),
  # presne ako ich cita nakup v zakazke bez snapshotu.
  # -> [prep|nil, chyba|nil]
  def upgrade(cfg, to, from: V1, front_id: 'F1')
    r.with_test_dir(FIX) do
      panel.drawer_upgrade_prepare(nil, cab_with(cfg),
                                   'front_id' => front_id, 'from' => from, 'to' => to)
    end
  end

  def refs_of(par, front_id = 'F1')
    it = Array(par['fronts']['items']).find { |i| i['id'].to_s == front_id }
    it['drawer']['recipe_refs']
  end

  def lock(fields, rule = rid(V1), owner = OWNER)
    { 'owner_part_key' => owner, 'generic_type' => 'slide', 'rule_id' => rule }.merge(fields)
  end

  def slide(cfg)
    Array(cfg['hardware']).find { |h| h['source'].to_s == 'recipe' }
  end
end

# ============================================================================
# R6 — FIXTURNY REGISTER, GUARD PRODUKCIE, TESTOVACI SEAM
# ============================================================================

NxTest.test('KOV-D3a (R6): PRODUKCNY register nema ziadnu v2+ — latentny ramec zije LEN v testoch') do
  c = NxD3a
  reg = c.r.released
  NxTest.assert_equal(%w[atira_p2o_v1 atira_sisy_v1 quadro_v6_p2o_v1 quadro_v6_sisy_v1],
                      reg.keys.sort, 'produkcny register sa zmenil')
  reg.each_key do |id|
    NxTest.assert_equal(1, c.r.parse_id(id)[:version],
                        "produkcny register nesmie niest #{id} — v2 vznika az s realnou datovou zmenou")
    # `load` overuje ODTLACOK: register v1 sa touto davkou NEMENI.
    NxTest.assert(c.r.load(id)[:release_note].nil?, "#{id} nesmie mat release_note")
  end
end

NxTest.test('KOV-D3a (R6): fixturny register nesie v2 a jeho v1 je OBSAHOVO produkcny recept') do
  c = NxD3a
  reg = c.r.released(dir: NxD3a::FIX)
  NxTest.assert(reg.key?('atira_sisy_v2'), 'fixtura musi niest cielovu v2')
  NxTest.assert_equal(reg.keys.sort, c.r.inventory(dir: NxD3a::FIX),
                      'fixturny inventar musi sediet s registrom')
  fix = c.r.load(NxD3a::V1, dir: NxD3a::FIX)
  prod = c.r.load(NxD3a::V1)
  NxTest.assert_equal(prod, fix, 'fixturny v1 sa musi rovnat produkcnemu (inak fixtura meria iny recept)')
end

NxTest.test('KOV-D3a (R6): testovaci seam prepina priecinok a VZDY ho vrati') do
  c = NxD3a
  NxTest.assert_equal(c.r::DIR, c.r.active_dir, 'default je produkcny priecinok')
  c.r.with_test_dir(NxD3a::FIX) do
    NxTest.assert_equal(NxD3a::FIX, c.r.active_dir)
    NxTest.assert_equal('atira_sisy_v2', c.r.load('atira_sisy_v2')[:recipe_id],
                        'bez `dir:` sa cita fixturny register')
  end
  NxTest.assert_equal(c.r::DIR, c.r.active_dir, 'po bloku sa priecinok vracia')
  begin
    c.r.with_test_dir(NxD3a::FIX) { raise 'boom' }
  rescue StandardError
    nil
  end
  NxTest.assert_equal(c.r::DIR, c.r.active_dir, 'priecinok sa vracia AJ po vynimke')
end

# ============================================================================
# R4 — `pick_ref` PRI MAPE S VIAC VERZIAMI
# ============================================================================

NxTest.test('KOV-D3a (R4): surodenec = NAJNIZSIA dostupna verzia, nezavisle od poradia klucov') do
  c = NxD3a
  ids = %w[atira_sisy_v1 atira_sisy_v2 atira_p2o_v1 atira_p2o_v2]
  c.with_reg(ids) do |d|
    a = { 'atira|sisy' => 'atira_sisy_v2', 'quadro_v6|sisy' => 'quadro_v6_sisy_v1' }
    b = { 'quadro_v6|sisy' => 'quadro_v6_sisy_v1', 'atira|sisy' => 'atira_sisy_v2' }
    # Zaznam quadro v1 dava surodenca `atira_p2o_v1`, zaznam atira v2 dava
    # `atira_p2o_v2` — vitazi NIZSIA verzia, a to v OBOCH poradiach.
    NxTest.assert_equal('atira_p2o_v1', c.r.pick_ref(a, 'atira', 'p2o', dir: d))
    NxTest.assert_equal('atira_p2o_v1', c.r.pick_ref(b, 'atira', 'p2o', dir: d))
  end
end

NxTest.test('KOV-D3a (R4): neplatny zaznam mapy vyber surodenca NEOVPLYVNI') do
  c = NxD3a
  c.with_reg(%w[atira_sisy_v1 atira_sisy_v2 atira_p2o_v1 atira_p2o_v2]) do |d|
    # Kluc `quadro_v6|sisy` nesie atirovsky ref — je to POSKODENY pin (D1a
    # `:unknown`). Surodenca z neho nikdy nesmie vzniknut. Poskodeny zaznam
    # tu ukazuje na NIZSIU verziu, takze keby sa ratal, PREBIL by platny —
    # bez toho by test prehltol aj vyber, ktory poskodeny pin zapocital.
    map = { 'atira|sisy' => 'atira_sisy_v2', 'quadro_v6|sisy' => 'atira_sisy_v1' }
    NxTest.assert_equal('atira_p2o_v2', c.r.pick_ref(map, 'atira', 'p2o', dir: d))
    # A opacne: poskodeny pin nesmie prebit ani vyssou verziou.
    map2 = { 'atira|sisy' => 'atira_sisy_v1', 'quadro_v6|sisy' => 'atira_sisy_v2' }
    NxTest.assert_equal('atira_p2o_v1', c.r.pick_ref(map2, 'atira', 'p2o', dir: d))
  end
end

NxTest.test('KOV-D3a (R4): charakterizacia — jediny zaznam da surodenca TEJ ISTEJ verzie') do
  c = NxD3a
  c.with_reg(%w[atira_sisy_v1 atira_sisy_v2 atira_p2o_v1 atira_p2o_v2]) do |d|
    NxTest.assert_equal('atira_p2o_v2',
                        c.r.pick_ref({ 'atira|sisy' => 'atira_sisy_v2' }, 'atira', 'p2o', dir: d))
    # Prazdna mapa = NAJNOVSI vydany (spravanie pred davkou sa nemeni).
    NxTest.assert_equal('atira_p2o_v2', c.r.pick_ref({}, 'atira', 'p2o', dir: d))
  end
end

# ============================================================================
# R5 — `release_note`
# ============================================================================

NxTest.test('KOV-D3a (R5): release_note sa prenesie do nacitaneho receptu, v1 ho nema') do
  c = NxD3a
  v2 = c.r.load(NxD3a::V2, dir: NxD3a::FIX)
  NxTest.assert(v2[:release_note].is_a?(String) && !v2[:release_note].empty?, v2[:release_note].inspect)
  NxTest.assert(v2[:release_note].include?('chrbát'), v2[:release_note])
  NxTest.assert(c.r.load(NxD3a::V1, dir: NxD3a::FIX)[:release_note].nil?, 'v1 pole vynechava')
end

NxTest.test('KOV-D3a (R5): pritomne, ale nepouzitelne release_note = odmietnutie CELEHO receptu') do
  c = NxD3a
  base = JSON.parse(File.read(File.join(c.r::DIR, 'atira_sisy_v1.json'), encoding: 'UTF-8'))
  [123, '', '   ', 'x' * (c.r::RELEASE_NOTE_MAX + 1)].each do |bad|
    NxTest.assert_raise('release_note') do
      c.r.validate!(base.merge('release_note' => bad), NxD3a::V1)
    end
  end
  # Hranica: presne max znakov este prejde a text sa OREZE.
  ok = c.r.validate!(base.merge('release_note' => "  #{'x' * c.r::RELEASE_NOTE_MAX}  "), NxD3a::V1)
  NxTest.assert_equal(c.r::RELEASE_NOTE_MAX, ok[:release_note].length)
end

# ============================================================================
# R1 — AKCIA UPGRADU (identita, ciel, smer)
# ============================================================================

NxTest.test('KOV-D3a (R1): `Recipes.upgrade?` = jedina pravda o smere upgradu') do
  c = NxD3a
  NxTest.assert(c.r.upgrade?('atira_sisy_v1', 'atira_sisy_v2'))
  NxTest.refute(c.r.upgrade?('atira_sisy_v2', 'atira_sisy_v2'), 'rovnaka verzia nie je upgrade')
  NxTest.refute(c.r.upgrade?('atira_sisy_v2', 'atira_sisy_v1'), 'downgrade nikdy')
  NxTest.refute(c.r.upgrade?('atira_sisy_v1', 'quadro_v6_sisy_v2'), 'iny system nikdy')
  NxTest.refute(c.r.upgrade?('atira_sisy_v1', 'atira_p2o_v2'), 'ine otvaranie nikdy')
  NxTest.refute(c.r.upgrade?('atira_sisy_v1', 'nezmysel'), 'neparsovatelny ciel nikdy')
end

NxTest.test('KOV-D3a (R1): nesediaci ocakavany stary ref = odmietnutie („stav sa medzitym zmenil")') do
  c = NxD3a
  cfg = c.cfg_for(c.params)
  prep, err = c.upgrade(cfg, NxD3a::V2, from: 'atira_sisy_v4')
  NxTest.assert(prep.nil?, 'pri nesediacom `from` sa nesmie nic pripravit')
  NxTest.assert(err.to_s.include?('medzitým zmenil'), err.to_s)
end

NxTest.test('KOV-D3a (R1): chybajuci aj poskodeny zaznam mapy = odmietnutie (upgrade ich neopravuje)') do
  c = NxD3a
  # `:missing` — celo bez mapy (pin doplni az stavba).
  missing = c.cfg_for(c.params)
  missing['front_items'][0]['drawer'].delete('recipe_refs')
  missing['fronts']['items'][0]['drawer'].delete('recipe_refs')
  _, err = c.upgrade(missing, NxD3a::V2, from: '')
  NxTest.assert(err.to_s.include?('medzitým zmenil'), err.to_s)

  # `:unknown` — pin je pritomny, ale plugin ho nepozna (RED, vlastna naprava).
  broken = c.cfg_for(c.params(refs: { 'atira|sisy' => 'atira_sisy_v9' }))
  _, err2 = c.upgrade(broken, NxD3a::V2, from: 'atira_sisy_v9')
  NxTest.assert(err2.to_s.include?('medzitým zmenil'), err2.to_s)
end

NxTest.test('KOV-D3a (R1): nevydany ciel = odmietnutie') do
  c = NxD3a
  _, err = c.upgrade(c.cfg_for(c.params), 'atira_sisy_v9')
  NxTest.assert(err.to_s.include?('nie je vydaná'), err.to_s)
end

NxTest.test('KOV-D3a (R1): ciel INEHO systemu alebo otvarania = odmietnutie') do
  c = NxD3a
  _, err = c.upgrade(c.cfg_for(c.params), 'quadro_v6_sisy_v2')
  NxTest.assert(err.to_s.include?('toho istého systému'), err.to_s)
end

NxTest.test('KOV-D3a (R1): rovnaka ani nizsia verzia neprejde — ziadny downgrade') do
  c = NxD3a
  _, same = c.upgrade(c.cfg_for(c.params), NxD3a::V1)
  NxTest.assert(same.to_s.include?('novšiu verziu'), same.to_s)

  down = c.cfg_for(c.params(refs: { 'atira|sisy' => NxD3a::V2 }))
  _, err = c.upgrade(down, NxD3a::V1, from: NxD3a::V2)
  NxTest.assert(err.to_s.include?('novšiu verziu'), err.to_s)
end

NxTest.test('KOV-D3a (R1): uspech meni PRESNE JEDEN zaznam mapy — ostatne refs ostavaju') do
  c = NxD3a
  # Druhy kluc mapy (ine otvaranie) je PRITOMNY, ale upgradu sa netyka.
  refs = { 'atira|sisy' => NxD3a::V1, 'atira|p2o' => 'atira_p2o_v1' }
  cfg = c.cfg_for(c.params(refs: refs))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(err.nil?, err.to_s)
  NxTest.assert_equal({ 'atira|sisy' => NxD3a::V2, 'atira|p2o' => 'atira_p2o_v1' },
                      c.refs_of(prep[:params]))
  NxTest.assert_equal(NxD3a::V2, prep[:recipe][:recipe_id])
  # ULOZENY config skrinky sa NEMENI — zapis robi az prestavba.
  NxTest.assert_equal(refs, cfg['fronts']['items'][0]['drawer']['recipe_refs'])
end

NxTest.test('KOV-D3a (R1): upgrade sa tyka LEN adresovaneho cela — druha zasuvka ostava na v1') do
  c = NxD3a
  f2 = { 'id' => 'F2', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
         'opening_mode' => 'classic',
         'drawer' => { 'construction' => 'metal', 'system' => 'atira',
                       'recipe_refs' => { 'atira|sisy' => NxD3a::V1 } } }
  cfg = c.cfg_for(c.params(extra_front: f2))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(err.nil?, err.to_s)
  NxTest.assert_equal({ 'atira|sisy' => NxD3a::V2 }, c.refs_of(prep[:params], 'F1'))
  NxTest.assert_equal({ 'atira|sisy' => NxD3a::V1 }, c.refs_of(prep[:params], 'F2'),
                      'druhe celo si drzi svoju verziu')
end

NxTest.test('KOV-D3a (R1): dormantne zamky INYCH receptov sa nedotknu') do
  c = NxD3a
  other = c.lock({ 'nominal_length' => 350.0 }, c.rid('atira_p2o_v1'))
  cfg = c.cfg_for(c.params(overrides: [other]))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(err.nil?, err.to_s)
  NxTest.assert_equal([other], prep[:params]['hardware_overrides'],
                      'zamok ineho receptu ostava presne taky, aky bol')
end

# ============================================================================
# R2 — PREFLIGHT (hrubky, zamky, resolve, kit)
# ============================================================================

NxTest.test('KOV-D3a (R2): nesediaca hrubka cieloveho receptu = ZIADNY zapis') do
  c = NxD3a
  lock = c.lock('nominal_length' => 470.0)
  cfg = c.cfg_for(c.params(front_height: 220.0, overrides: [lock]))
  prep, err = c.upgrade(cfg, 'atira_sisy_v3')
  NxTest.assert(prep.nil?, 'preflight musi zastavit upgrade PRED zapisom')
  NxTest.assert(err.to_s.include?('nepodporovaná hrúbka'), err.to_s)
  # V modeli ostava v1 aj povodny zamok.
  NxTest.assert_equal({ 'atira|sisy' => NxD3a::V1 }, cfg['fronts']['items'][0]['drawer']['recipe_refs'])
  NxTest.assert_equal([lock], cfg['hardware_overrides'])
end

NxTest.test('KOV-D3a (R2): konflikt zamku po preadresovani = odmietnutie, zamok ostava na v1') do
  c = NxD3a
  # NL 470 je v rade H144 receptu v1, ale v4 rad skracuje na 350/420.
  lock = c.lock('nominal_length' => 470.0)
  cfg = c.cfg_for(c.params(front_height: 220.0, overrides: [lock]))
  NxTest.assert_equal(144, c.slide(cfg)['params']['height_variant'], 'predpoklad: zasuvka stoji na H144')
  prep, err = c.upgrade(cfg, 'atira_sisy_v4')
  NxTest.assert(prep.nil?)
  NxTest.assert(err.to_s.include?('nie je v rade H144'), err.to_s)
  NxTest.assert_equal([lock], cfg['hardware_overrides'], 'povodny zamok ostava nedotknuty')
end

NxTest.test('KOV-D3a (R2): chybajuci kit vysuvu = odmietnutie (nakup ide TOU ISTOU expanziou)') do
  c = NxD3a
  # Hlbsia skrinka (700) -> NL 620 z radu v5 sa zmesti, ale set k nej kod nema.
  cfg = c.cfg_for(c.params(front_height: 220.0, depth: 700.0))
  prep, err = c.upgrade(cfg, 'atira_sisy_v5')
  NxTest.assert(prep.nil?)
  NxTest.assert(err.to_s.include?('kit výsuvu'), err.to_s)
  NxTest.assert(err.to_s.include?('620'), err.to_s)
end

NxTest.test('KOV-D3a (R2): kolidujuci override na CIELOVOM rule_id s inou hodnotou = odmietnutie') do
  c = NxD3a
  src = c.lock('nominal_length' => 470.0)
  dst = c.lock({ 'nominal_length' => 350.0 }, c.rid(NxD3a::V2))
  cfg = c.cfg_for(c.params(front_height: 220.0, overrides: [src, dst]))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(prep.nil?, 'kolizia sa nikdy nezlucuje ticho')
  NxTest.assert(err.to_s.include?('iný ručný zásah'), err.to_s)
end

NxTest.test('KOV-D3a (R2): dormantny zamok na cielovom rule_id BEZ protajsku = odmietnutie') do
  c = NxD3a
  # Na v1 zamok nie je, na v2 lezi davno zabudnuty. Zlucenie by ho ticho
  # AKTIVOVALO — fail-closed: upgrade sa neuklada.
  dst = c.lock({ 'height_variant' => 70 }, c.rid(NxD3a::V2))
  cfg = c.cfg_for(c.params(front_height: 220.0, overrides: [dst]))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(prep.nil?)
  NxTest.assert(err.to_s.include?('iný ručný zásah'), err.to_s)
end

NxTest.test('KOV-D3a (R2): uspesny upgrade PREADRESUJE zamky aj s hodnotami') do
  c = NxD3a
  src = c.lock('nominal_length' => 470.0, 'height_variant' => 144)
  cfg = c.cfg_for(c.params(front_height: 220.0, overrides: [src]))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(err.nil?, err.to_s)
  ov = prep[:params]['hardware_overrides']
  NxTest.assert_equal(1, ov.length, ov.inspect)
  NxTest.assert_equal(c.rid(NxD3a::V2), ov[0]['rule_id'], 'zamok patri NOVEJ verzii')
  NxTest.assert_equal(470.0, ov[0]['nominal_length'], 'hodnota NL sa zachovava')
  NxTest.assert_equal(144, ov[0]['height_variant'], 'hodnota vysky sa zachovava')
  NxTest.assert_equal(NxD3a::OWNER, ov[0]['owner_part_key'])
end

NxTest.test('KOV-D3a (R2): totozny zaznam na cielovom rule_id nie je kolizia (idempotencia)') do
  c = NxD3a
  src = c.lock('nominal_length' => 470.0)
  dst = c.lock({ 'nominal_length' => 470.0 }, c.rid(NxD3a::V2))
  cfg = c.cfg_for(c.params(front_height: 220.0, overrides: [src, dst]))
  prep, err = c.upgrade(cfg, NxD3a::V2)
  NxTest.assert(err.nil?, err.to_s)
  ov = prep[:params]['hardware_overrides']
  NxTest.assert_equal(1, ov.length, "duplicita identity sa nesmie zdvojit: #{ov.inspect}")
  NxTest.assert_equal(470.0, ov[0]['nominal_length'])
end

# ============================================================================
# CHARAKTERIZACIA — zakazka BEZ upgradu sa nemeni
# ============================================================================

NxTest.test('KOV-D3a: zakazka BEZ upgradu stavia aj nakupuje presne ako pred davkou') do
  c = NxD3a
  cfg = c.cfg_for(c.params(front_height: 220.0))
  sl = c.slide(cfg)
  NxTest.assert_equal(NxD3a::V1, sl['params']['recipe_id'])
  NxTest.assert_equal(144, sl['params']['height_variant'])
  NxTest.assert_equal(470.0, sl['params']['nominal_length'])
  NxTest.assert_equal([], Array(cfg['drawer_conflicts']))
  parts = Array(cfg['front_items']).length
  NxTest.assert_equal(1, parts, 'fixtura ma jedno celo')
  # Nakup: prave jeden kit vysuvu, ziadna nemapovana polozka.
  state, err = c.panel.drawer_upgrade_sets_state(nil)
  NxTest.assert(err.nil?, err.to_s)
  exp = c.e::HardwareSets.expand([sl.merge('owner_id' => 'CAB-1')], state,
                                 catalog: c.e::HardwareCatalog.items)
  NxTest.assert_equal([], Array(exp['unmapped']), 'zasuvka bez upgradu ma kit')
  NxTest.assert_equal(1, Array(exp['rows']).length, exp['rows'].inspect)
end
