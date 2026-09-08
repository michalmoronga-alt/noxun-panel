# frozen_string_literal: true
# KOV-W (8.9.2026) — HMOTNOSŤ DIELCOV A ČIEL: jeden vzorec, ťažší odhad, priznaný stav.
#
# Závesy (KOV-F) a výklopy (KOV-E) potrebujú hmotnosť čela; Inspector má od UI 2.0
# prázdny riadok „Hmotnosť" (D-125). Hustota per TYP materiálu už existovala
# (`Materials::TYPE_REGISTRY`), nikto z nej ale nič nepočítal.
#
# Rozhodnutie Michala 8.9.2026: dielec s neznámou hustotou (UNI, typ bez hustoty,
# materiál mimo katalógu) sa zo súčtu NIKDY nevynechá — ráta sa ŤAŽŠIE (najvyššia
# hustota doskového typu v registri okrem kompaktu) a stav sa prizná.
#
# Co sa overuje:
#   1) `Materials.weight_kg` — jediný vzorec (mm × kg/m³ / 1e9), nezaokrúhľuje;
#      nekladný vstup = 0.0 (degenerovaný dielec váhu nemá)
#   2) `fallback_density` = max hustota registra OKREM kompaktu; číslo NIE JE
#      literál — zdrojový guard nad všetkými miestami, kde sa hmotnosť počíta
#   3) `build_plan(materials:)` anotuje KAŽDÝ dielec (`weight_kg`, `weight_estimated`)
#      vrátane dielcov zásuviek; fallback dá PRESNE JEDEN warning na skrinku
#      (nie na dielec) so zoznamom dotknutých part_key
#   4) **HRÚBKA kopíruje skutočnú materializáciu** (Codex #328 P2 + Sol audit 1):
#      čelo sa ráta z KATALÓGOVEJ hrúbky kanála/overridu (18,6 / 19 / 25 mm), nie
#      z placeholderu 18 mm v deskriptore; pri UNI materiáli ostáva hrúbka DIELCA,
#      lebo builder ju pri UNI neprepisuje (M-B1)
#   5) charakterizácia starých volajúcich: `build_plan` BEZ `materials` nemá ani
#      kľúče, ani warning (migrácia identity a panelové resolvery sa nemenia)
#   6) per-part override materiálu má prednosť pred kanálom — aj keď je bez hustoty
#   7) `material_channel` je JEDINÉ miesto pravdy o materiálovom kanáli:
#      `CabinetBuilder.base_material_for` cez neho vyberá TÚ ISTÚ dosku ako pred
#      KOV-W (charakterizácia nad každou rolou × každým signálom)
#   8) `HardwareRules` vstup `weight` — pásmové pravidlo počíta z hmotnosti čela;
#      bez anotácie (plán bez materiálov) položka NEVZNIKNE + info warning
#   9) `Bom.weight_totals` — súčet cez `quantity`, UNI aj materiál mimo katalógu
#      sú ODHAD (nikdy vynechaný dielec)
#  10) Kontrola: warning o hmotnosti vzniká LEN za dielce, ktoré UNI NIE SÚ (UNI
#      hlási `uni_material`) — filtruje PLÁN, Kontrola nič nepotláča, takže to isté
#      vidí aj zvonček Inspectora nad uloženými warningmi
#  11) Inspector (D-125): payload skrinky nesie `weight_kg` + `weight_estimated_*`
#      a berie ich z `Bom.weight_totals` (zdrojový guard; živý beh je in-SU)
#  12) REGRESIA: hmotnosť sa neukladá do modelu (snapshot dielca ani `merge_final`
#      nemajú `weight_*`), `Bom.row_key` sa nezmenil, plán ostáva na svojej schéme
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1  vzorec delí 1e6 namiesto 1e9              -> „jeden vzorec"
#   M2  `fallback_density` berie aj KOMPAKT       -> ťažký odhad by bol 1350
#   M3  hustota 870 napísaná ako literál          -> zdrojový guard
#   M4  dielec bez hustoty sa zo súčtu vynechá    -> `estimated_parts` a súčet
#   M5  warning per DIELEC namiesto per skrinka   -> „presne jeden warning"
#   M6  anotácia beží aj bez `materials`          -> charakterizácia starých volajúcich
#   M7  per-part override prehliadnutý            -> precedencia overridu
#   M8  `base_material_for` má vlastný `case`     -> guard jedného miesta pravdy
#   M9  `input_value` nepozná `weight`            -> pásmové pravidlo nad čelom
#   M10 čelo sa ráta z placeholderu 18 mm         -> čelo 2000 × 600 z MDF 25
#   M11 UNI berie katalógovú hrúbku               -> UNI dielec 25 mm ostáva na 25
#   M12 warning vzniká aj za UNI dielce           -> počty nálezov Kontroly
#   M13 hmotnosť pretečie do snapshotu/configu    -> regresné guardy zápisu
#   M14 `Bom.row_key` sa rozšíri o hmotnosť       -> charakterizácia kľúča riadku
require_relative '../helper' unless defined?(NxTest)

module NxKovW
  E   = Noxun::Engine
  M   = E::Materials
  CN  = E::Construction
  CB  = E::CabinetBuilder
  BOM = E::Bom
  HR  = E::HardwareRules
  V   = E::Validation
  BP  = E::BuildPlan

  CORE = File.join(NxTest::ROOT, 'noxun_engine', 'core')
  CN_RB  = File.read(File.join(CORE, 'construction.rb'))
  CB_RB  = File.read(File.join(CORE, 'cabinet_builder.rb'))
  BOM_RB = File.read(File.join(CORE, 'bom.rb'))
  RES_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers.rb'))

  module_function

  # Katalogovy zaznam kanala/overridu tak, ako ho stava `CabinetBuilder.sheet_weight_info`.
  def mat(thickness, density, uni = false)
    { 'thickness' => thickness, 'density' => density, 'uni' => uni }
  end
end

module NxKovW
  # Hustoty kanalov = realne cisla registra (DTDL/MDF/HDF), nie vymyslene;
  # hrubky = to, co v testovacej skrinke naozaj stoji (telo 18, chrbat 3 HDF,
  # celo placeholder 18, zasuvka 16 = `DRAWER_DEFAULT_THICKNESS`).
  CH = { 'body' => mat(18.0, 680.0), 'front' => mat(18.0, 750.0),
         'back' => mat(3.0, 870.0), 'drawer' => mat(16.0, 680.0) }.freeze
  MAT = { 'channels' => CH, 'parts' => {} }.freeze
  # Ten isty katalog, ale ziadny typ nema hustotu (napr. same „ine" dosky).
  NO_DENS = { 'channels' => CH.each_with_object({}) { |(k, v), o| o[k] = v.merge('density' => nil) },
              'parts' => {} }.freeze

  module_function

  def cfg(over = {})
    CB.normalize({ 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
                   'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '1' }] } }.merge(over))
  end

  def drawer_cfg
    CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                 'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                             'mode' => 'fixed', 'height' => 175.0,
                                             'opening_mode' => 'classic',
                                             'drawer' => { 'construction' => 'metal' } }] })
  end

  def plan(materials = MAT, over = {}, rules: [])
    CN.build_plan(cfg(over), 'CAB-1', hardware_rules: rules, materials: materials)
  end

  # Kanaly s inou hustotou/hrubkou cela (vzor: MDF 25 mm).
  def channels(front)
    { 'channels' => CH.merge('front' => front), 'parts' => {} }
  end

  def weight_warnings(pl)
    Array(pl[:warnings]).select { |w| w['code'] == 'weight_density_unknown' }
  end

  def part(pl, key)
    pl[:parts].find { |p| p[:part_key] == key }
  end

  def door(pl)
    pl[:parts].find { |p| p[:role] == 'front_door' }
  end

  # Holy deskriptor pre priame testy anotacie (bez stavby celej skrinky).
  def desc(role, mat_sym, l, w, th, key = 'p1')
    { part_key: key, role: role, material: mat_sym, name: 'Dielec', suffix: 'X',
      prod: { length: l, width: w, thickness: th } }
  end

  # Anotuje dane deskriptory a vrati [dielce, warningy].
  def annotate(parts, materials)
    ws = []
    CN.annotate_weights!(parts, materials, ws)
    [parts, ws]
  end

  # Telo pomenovanej metody zo zdrojaku (vzor test_1b3_citanie) — pre zdrojove guardy.
  def body(src, name, indent)
    pad = ' ' * indent
    src[/#{pad}def #{Regexp.escape(name)}.*?\n#{pad}end\n/m].to_s
  end

  # Vsetky hustoty registra ako holé cisla — ziadna z nich nesmie stat v kode,
  # ktory hmotnost pocita (jedina autorita je TYPE_REGISTRY).
  def density_literals
    M::TYPE_REGISTRY.each_with_object([]) do |(_, entry), out|
      next unless entry['density']

      d = entry['density'].to_f
      out << format('%g', d)
      out << format('%.1f', d)
    end.uniq
  end

  # Charakterizacia PREDKOVA `base_material_for` (stav pred KOV-W, doslovne).
  def legacy_base_material(role, mat_sym, body_m, front_m, back_m, drawer_m)
    case role.to_s
    when 'front_door', 'drawer_front', 'flap', 'false_front' then front_m
    when 'back' then back_m
    when *CB::DRAWER_ROLES then drawer_m || body_m
    else
      next_val = mat_sym == :drawer ? (drawer_m || body_m) : nil
      next_val || (mat_sym == :front ? front_m : body_m)
    end
  end
end

# ---------------------------------------------------------------------------
# 1) VZOREC
# ---------------------------------------------------------------------------

NxTest.test('KOV-W: hmotnosť = dĺžka × šírka × hrúbka [mm] × hustota [kg/m3] / 1e9') do
  m = NxKovW::M
  NxTest.assert_close(7.344, m.weight_kg(1000.0, 600.0, 18.0, 680.0), 0.0001,
                      'DTD 18 mm, 1000 x 600')
  NxTest.assert_close(5.832, m.weight_kg(600.0, 720.0, 18.0, 750.0), 0.0001,
                      'MDF 18 mm celo 600 x 720')
  # NEZAOKRUHLUJE — zaokruhlenie patri az zobrazeniu.
  NxTest.assert(m.weight_kg(333.0, 333.0, 18.0, 680.0).to_s.length > 6)
end

NxTest.test('KOV-W: nekladný/neplatný vstup nedá zápornú ani NaN hmotnosť (0.0)') do
  m = NxKovW::M
  [[0.0, 600.0, 18.0, 680.0], [1000.0, -1.0, 18.0, 680.0], [1000.0, 600.0, 18.0, nil],
   [nil, nil, nil, nil], [1000.0, 600.0, 18.0, 0.0]].each do |args|
    NxTest.assert_equal(0.0, m.weight_kg(*args), "vstup #{args.inspect}")
  end
end

# ---------------------------------------------------------------------------
# 2) TAZSI ODHAD — fallback hustota
# ---------------------------------------------------------------------------

NxTest.test('KOV-W: `fallback_density` = najvyššia hustota doskového typu OKREM kompaktu') do
  m = NxKovW::M
  want = m::TYPE_REGISTRY.reject { |k, _| k == 'KOMPAKT' }
                         .filter_map { |_, v| v['density']&.to_f }.max
  NxTest.assert_equal(want, m.fallback_density)
  NxTest.assert(m.fallback_density < m::TYPE_REGISTRY['KOMPAKT']['density'].to_f,
                'kompakt je vedome mimo — inak by odhad bol takmer dvojnásobný')
  NxTest.assert(m.fallback_density > m::TYPE_REGISTRY['DTDL']['density'].to_f,
                'odhad je ŤAŽŠÍ než bežná doska')
  NxTest.assert_equal(%w[KOMPAKT], m::FALLBACK_DENSITY_SKIP_TYPES)
end

NxTest.test('KOV-W: `density_or_fallback` — UNI aj neznámy záznam sú ODHAD, nie nula') do
  m = NxKovW::M
  NxTest.assert_equal([680.0, false], m.density_or_fallback('type' => 'DTDL'))
  NxTest.assert_equal([m.fallback_density, true], m.density_or_fallback(nil))
  NxTest.assert_equal([m.fallback_density, true], m.density_or_fallback('uni' => true, 'type' => 'DTDL'))
  NxTest.assert_equal([m.fallback_density, true], m.density_or_fallback('type' => 'ine-sklo'))
end

NxTest.test('KOV-W GUARD: hustota sa NIKDE nepíše ako literál (jediná autorita = TYPE_REGISTRY)') do
  k = NxKovW
  lits = k.density_literals
  NxTest.assert(lits.include?('870') && lits.include?('1350'), "guard nemeria prazdno: #{lits.inspect}")
  {
    'annotate_weights!' => k.body(k::CN_RB, 'annotate_weights!', 6),
    'part_materials' => k.body(k::CB_RB, 'part_materials', 8),
    'sheet_weight_info' => k.body(k::CB_RB, 'sheet_weight_info', 8),
    'weight_totals' => k.body(k::BOM_RB, 'weight_totals', 6),
    'cabinet_stats' => k.body(k::RES_RB, 'cabinet_stats', 8)
  }.each do |name, src|
    NxTest.assert(!src.empty?, "#{name}: telo metody sa naslo")
    lits.each do |lit|
      NxTest.assert(!src.include?(lit), "#{name} nesmie niesť literál hustoty #{lit}")
    end
  end
end

# ---------------------------------------------------------------------------
# 3) ANOTACIA PLANU
# ---------------------------------------------------------------------------

NxTest.test('KOV-W: s `materials` má KAŽDÝ dielec plánu hmotnosť a žiadny nie je odhad') do
  k = NxKovW
  pl = k.plan
  NxTest.assert(pl[:parts].length >= 5, 'skrinka s čelom má dielce')
  pl[:parts].each do |pd|
    NxTest.assert(pd[:weight_kg].is_a?(Float) && pd[:weight_kg].positive?,
                  "#{pd[:part_key]}: weight_kg = #{pd[:weight_kg].inspect}")
    NxTest.assert_equal(false, pd[:weight_estimated], "#{pd[:part_key]}: nie je odhad")
  end
  NxTest.assert_equal([], k.weight_warnings(pl), 'známa hustota = žiadny warning')
end

NxTest.test('KOV-W: hmotnosť dielca sedí s prod rozmermi a hustotou JEHO kanála') do
  k = NxKovW
  pl = k.plan
  side = k.part(pl, 'cabinet/side:left')
  back = k.part(pl, 'cabinet/back')
  door = k.door(pl)
  [[side, k::CH['body']], [back, k::CH['back']], [door, k::CH['front']]].each do |pd, rec|
    NxTest.assert(!pd.nil?, 'dielec je v pláne')
    want = k::M.weight_kg(pd[:prod][:length], pd[:prod][:width], pd[:prod][:thickness], rec['density'])
    NxTest.assert_close(want, pd[:weight_kg], 0.000001,
                        "#{pd[:part_key]}: kanál #{k::CN.material_channel(pd[:role], pd[:material])}")
  end
  # Chrbat (HDF 870) je iny kanal nez telo — keby anotacia brala vsade telo,
  # tento rozdiel by zmizol.
  NxTest.assert(k::CH['back']['density'] != k::CH['body']['density'])
end

NxTest.test('KOV-W: bez hustôt je KAŽDÝ dielec odhad a warning je PRESNE JEDEN na skrinku') do
  k = NxKovW
  pl = k.plan(k::NO_DENS)
  NxTest.assert(pl[:parts].all? { |p| p[:weight_estimated] == true }, 'všetky dielce sú odhad')
  ws = k.weight_warnings(pl)
  NxTest.assert_equal(1, ws.length, 'jeden warning na SKRINKU, nie na dielec')
  w = ws.first
  NxTest.assert_equal('warn', w['severity'])
  NxTest.assert_equal(nil, w['part_key'], 'warning je korpusový')
  NxTest.assert_equal(pl[:parts].map { |p| p[:part_key] }.sort, w['data']['parts'].sort)
  NxTest.assert_equal(k::M.fallback_density, w['data']['density'])
  NxTest.assert(w['message'].include?('ťažšie'), "hláška priznáva ťažší odhad: #{w['message']}")
  # Kazdy dielec ma NEJAKU vahu — odhad nikdy nevynecha kus.
  NxTest.assert(pl[:parts].all? { |p| p[:weight_kg].positive? })
end

NxTest.test('KOV-W: hláška vie skloňovať (1 dielca / N dielcov)') do
  k = NxKovW
  one = k.plan({ 'channels' => k::CH, 'parts' => { 'cabinet/back' => k.mat(3.0, nil) } })
  NxTest.assert(k.weight_warnings(one).first['message'].include?('1 dielca'),
                k.weight_warnings(one).first['message'])
  many = k.plan(k::NO_DENS)
  NxTest.assert(k.weight_warnings(many).first['message'].match?(/\d+ dielcov/),
                k.weight_warnings(many).first['message'])
end

NxTest.test('KOV-W: plán BEZ `materials` nemá ani kľúče, ani warning (starí volajúci)') do
  k = NxKovW
  pl = k::CN.build_plan(k.cfg, 'CAB-1')
  pl[:parts].each do |pd|
    NxTest.assert(!pd.key?(:weight_kg), "#{pd[:part_key]}: žiadny weight_kg")
    NxTest.assert(!pd.key?(:weight_estimated), "#{pd[:part_key]}: žiadny weight_estimated")
  end
  NxTest.assert_equal([], k.weight_warnings(pl))
  # A plan aj tak prejde kontraktom (aditivne kluce validator neobmedzuje).
  NxTest.assert_equal(pl, k::BP.validate!(pl))
end

NxTest.test('KOV-W: anotovaný plán prejde `BuildPlan.validate!` (žiadny bump schémy)') do
  k = NxKovW
  pl = k.plan
  NxTest.assert_equal(pl, k::BP.validate!(pl))
  NxTest.assert_equal(k::BP::SCHEMA, pl[:schema], 'tvar ULOŽENÝCH dát sa nemení')
end

NxTest.test('KOV-W: per-part override materiálu PREBÍJA kanál — aj keď hustotu nemá') do
  k = NxKovW
  # 1) override s VLASTNOU hustotou (kompakt) — dielec nie je odhad, ale je tazsi
  heavy = k.plan({ 'channels' => k::CH, 'parts' => { 'cabinet/back' => k.mat(3.0, 1350.0) } })
  back = k.part(heavy, 'cabinet/back')
  want = k::M.weight_kg(back[:prod][:length], back[:prod][:width], back[:prod][:thickness], 1350.0)
  NxTest.assert_close(want, back[:weight_kg], 0.000001)
  NxTest.assert_equal(false, back[:weight_estimated])
  NxTest.assert_equal([], k.weight_warnings(heavy))
  # 2) override BEZ hustoty — override existuje, takze kanal sa NEPOUZIJE
  est = k.plan({ 'channels' => k::CH, 'parts' => { 'cabinet/back' => k.mat(3.0, nil) } })
  back2 = k.part(est, 'cabinet/back')
  NxTest.assert_equal(true, back2[:weight_estimated], 'override bez hustoty = odhad, nie kanál')
  NxTest.assert_close(k::M.weight_kg(back2[:prod][:length], back2[:prod][:width],
                                     back2[:prod][:thickness], k::M.fallback_density),
                      back2[:weight_kg], 0.000001)
  ws = k.weight_warnings(est)
  NxTest.assert_equal(1, ws.length)
  NxTest.assert_equal(['cabinet/back'], ws.first['data']['parts'], 'warning menuje LEN dotknutý dielec')
  NxTest.assert(k.part(est, 'cabinet/side:left')[:weight_estimated] == false, 'ostatné dielce sú presné')
end

NxTest.test('KOV-W: dielce ZÁSUVKY dostanú hmotnosť z kanála `drawer`') do
  k = NxKovW
  pl = k::CN.build_plan(k.drawer_cfg, 'CAB-1', materials: k::MAT)
  dr = pl[:parts].select { |p| p[:material] == :drawer }
  NxTest.assert(dr.length >= 2, "dielce zásuvky sú v pláne (#{dr.length})")
  dr.each do |pd|
    NxTest.assert_equal(k::CN::CHANNEL_DRAWER, k::CN.material_channel(pd[:role], pd[:material]))
    want = k::M.weight_kg(pd[:prod][:length], pd[:prod][:width], pd[:prod][:thickness],
                          k::CH['drawer']['density'])
    NxTest.assert_close(want, pd[:weight_kg], 0.000001, pd[:part_key])
    NxTest.assert_equal(false, pd[:weight_estimated])
  end
end

NxTest.test('KOV-W: anotuje sa CELÝ zoznam — dielec zásuvky s per-part overridom má SVOJU hustotu') do
  k = NxKovW
  base = k::CN.build_plan(k.drawer_cfg, 'CAB-1', materials: k::MAT)
  key = base[:parts].find { |p| p[:material] == :drawer }[:part_key]
  # Kompaktny override JEDNEHO dielca zasuvky (dvojnasobna hustota kanala).
  pl = k::CN.build_plan(k.drawer_cfg, 'CAB-1',
                        materials: { 'channels' => k::CH, 'parts' => { key => k.mat(16.0, 1350.0) } })
  pd = k.part(pl, key)
  NxTest.assert(!pd.nil?, "dielec #{key} je v pláne")
  NxTest.assert_close(k::M.weight_kg(pd[:prod][:length], pd[:prod][:width], pd[:prod][:thickness], 1350.0),
                      pd[:weight_kg], 0.000001, 'override zásuvkového dielca platí')
  NxTest.assert(pd[:weight_kg] > k.part(base, key)[:weight_kg],
                'ťažší materiál = ťažší dielec (anotácia beží aj nad `drawer[:parts]`)')
  NxTest.assert(pl[:parts].all? { |p| p[:weight_kg].to_f.positive? },
                'žiadny dielec plánu neostal bez hmotnosti')
end

# ---------------------------------------------------------------------------
# 4) HRUBKA = SKUTOCNA MATERIALIZACIA (Codex #328 P2, Sol audit 1)
# ---------------------------------------------------------------------------

NxTest.test('KOV-W: čelo sa ráta z KATALÓGOVEJ hrúbky, nie z placeholderu 18 mm') do
  k = NxKovW
  # Celo 2000 x 600 z MDF 25 mm: 2000 x 600 x 25 x 750 / 1e9 = 22,5 kg.
  # Z placeholderu 18 mm by vyslo 16,2 kg — presne nalez Codex #328 P2.
  parts, = k.annotate([k.desc('front_door', :front, 2000.0, 600.0, 18.0)],
                      'channels' => { 'front' => k.mat(25.0, 750.0) }, 'parts' => {})
  NxTest.assert_close(22.5, parts.first[:weight_kg], 0.0001, 'hrubé čelo = 22,5 kg')
  NxTest.assert(parts.first[:weight_kg] > 20.0, 'nie 16,2 kg z placeholderu')
  # Deskriptor sa NEMENI — geometria aj `prod` ostavaju, ako ich postavil plan.
  NxTest.assert_equal(18.0, parts.first[:prod][:thickness], '`prod` sa nemení')
end

NxTest.test('KOV-W: hrubšie čelo mení hmotnosť aj v CELOM pláne (kanál `front`)') do
  k = NxKovW
  thin = k.door(k.plan)
  thick = k.door(k.plan(k.channels(k.mat(25.0, 750.0))))
  NxTest.assert_close(thin[:weight_kg] * (25.0 / 18.0), thick[:weight_kg], 0.000001,
                      'hmotnosť rastie presne v pomere hrúbok')
  NxTest.assert_equal(18.0, thick[:prod][:thickness], 'plán čela stále nesie placeholder')
  # Ostatne dielce sa nehnu — hrubka je vec KANALA, nie celej skrinky.
  NxTest.assert_close(k.part(k.plan, 'cabinet/side:left')[:weight_kg],
                      k.part(k.plan(k.channels(k.mat(25.0, 750.0))), 'cabinet/side:left')[:weight_kg],
                      0.000001)
end

NxTest.test('KOV-W: UNI materiál hrúbku dielca NEPREPISUJE (builder ju tiež nechá)') do
  k = NxKovW
  fb = k::M.fallback_density
  # UNI zaznam s katalogovou hrubkou 18, ale dielec je 25 mm hruby ->
  # 1000 x 600 x 25 x 870 / 1e9 = 13,05 kg (nie 9,396 z katalogovych 18 mm).
  parts, = k.annotate([k.desc('side_left', :korpus, 1000.0, 600.0, 25.0)],
                      'channels' => { 'body' => k.mat(18.0, nil, true) }, 'parts' => {})
  NxTest.assert_close(13.05, parts.first[:weight_kg], 0.0001, 'UNI ostáva na hrúbke dielca')
  NxTest.assert_equal(true, parts.first[:weight_estimated], 'UNI hustotu nemá = odhad')
  NxTest.assert_close(1000.0 * 600.0 * 25.0 * fb / 1e9, parts.first[:weight_kg], 0.0001)
  # Kontrolna vzorka: TEN ISTY zaznam bez priznaku UNI uz katalogovu hrubku vezme.
  known, = k.annotate([k.desc('side_left', :korpus, 1000.0, 600.0, 25.0)],
                      'channels' => { 'body' => k.mat(18.0, nil, false) }, 'parts' => {})
  NxTest.assert_close(1000.0 * 600.0 * 18.0 * fb / 1e9, known.first[:weight_kg], 0.0001)
end

NxTest.test('KOV-W: bez katalógovej hrúbky (materiál mimo katalógu) platí hrúbka dielca') do
  k = NxKovW
  parts, = k.annotate([k.desc('shelf', :korpus, 800.0, 400.0, 22.0)],
                      'channels' => { 'body' => k.mat(nil, 680.0) }, 'parts' => {})
  NxTest.assert_close(k::M.weight_kg(800.0, 400.0, 22.0, 680.0), parts.first[:weight_kg], 0.000001)
  # Nekladna/poskodena hrubka v zazname sa ignoruje rovnako ako chybajuca.
  broken, = k.annotate([k.desc('shelf', :korpus, 800.0, 400.0, 22.0)],
                       'channels' => { 'body' => k.mat(0.0, 680.0) }, 'parts' => {})
  NxTest.assert_close(parts.first[:weight_kg], broken.first[:weight_kg], 0.000001)
end

NxTest.test('KOV-W: príznak odhadu rozlíši UNI od SKUTOČNÉHO materiálu s tou istou hustotou') do
  k = NxKovW
  fb = k::M.fallback_density
  uni, = k.annotate([k.desc('back', nil, 800.0, 700.0, 3.0)],
                    'channels' => { 'back' => k.mat(3.0, nil, true) }, 'parts' => {})
  hdf, = k.annotate([k.desc('back', nil, 800.0, 700.0, 3.0)],
                    'channels' => { 'back' => k.mat(3.0, fb) }, 'parts' => {})
  NxTest.assert_close(uni.first[:weight_kg], hdf.first[:weight_kg], 0.000001,
                      'rovnaká hustota = rovnaké číslo')
  NxTest.assert_equal([true, false], [uni.first[:weight_estimated], hdf.first[:weight_estimated]],
                      'ale skutočný HDF NIE JE odhad — príznak sa nesmie stratiť')
end

# ---------------------------------------------------------------------------
# 5) MATERIALOVY KANAL — jedno miesto pravdy
# ---------------------------------------------------------------------------

NxTest.test('KOV-W: `material_channel` dá pre KAŽDÚ rolu × signál TÚ ISTÚ dosku ako pred KOV-W') do
  k = NxKovW
  eff = %w[BODY FRONT BACK DRAWER]
  k::BP::ROLES.each do |role|
    [nil, :korpus, :front, :drawer, :concrete].each do |sym|
      want = k.legacy_base_material(role, sym, *eff)
      got = k::CB.base_material_for(role, sym, *eff)
      NxTest.assert_equal(want, got, "rola #{role} / signál #{sym.inspect}")
      NxTest.assert(k::CN::CHANNELS.include?(k::CN.material_channel(role, sym)),
                    "#{role}: kanál je zo slovníka")
    end
  end
  # Bez `eff_drawer` (starsi volajuci) spadne kanal zasuviek na telo — presne ako predtym.
  NxTest.assert_equal('BODY', k::CB.base_material_for('drawer_bottom', :drawer, 'BODY', 'F', 'B'))
end

NxTest.test('KOV-W GUARD: `base_material_for` nemá vlastný zoznam rolí (číta Construction)') do
  k = NxKovW
  src = k.body(k::CB_RB, 'base_material_for', 8)
  NxTest.assert(src.include?('Construction.material_channel'), 'kanál sa pýta Construction')
  %w[front_door drawer_front false_front DRAWER_ROLES].each do |lit|
    NxTest.assert(!src.include?(lit), "druhý opísaný zoznam rolí (#{lit}) by sa rozišiel")
  end
end

NxTest.test('KOV-W GUARD: builder posiela plánu hrúbku AJ hustotu AJ príznak UNI') do
  k = NxKovW
  src = k.body(k::CB_RB, 'sheet_weight_info', 8)
  NxTest.assert(!src.empty?, 'metóda existuje')
  %w[thickness density uni].each do |key|
    NxTest.assert(src.include?("'#{key}'"), "záznam nesie #{key}")
  end
  NxTest.assert(src.include?('Materials.uni?'), 'UNI sa pýta jedinej autority')
  NxTest.assert(src.include?('Materials.density_for'), 'hustota ide cez register typov')
  NxTest.assert(k.body(k::CB_RB, 'part_materials', 8).include?('sheet_weight_info'),
                'kanály aj overridy stavia TÁ ISTÁ funkcia')
end

# ---------------------------------------------------------------------------
# 6) PRAVIDLA KOVANIA — vstup `weight`
# ---------------------------------------------------------------------------

module NxKovW
  # Umele pravidlo: lahke celo = 2 zavesy, tazke = 4. Ziadne SEED pravidlo
  # vstup `weight` zatial nepouziva (to pride s F/E) — testuje sa kanal, nie seed.
  WEIGHT_RULE = [{ 'rule_id' => 'test-hmotnost-cela', 'enabled' => true,
                   'applies_to' => { 'role' => 'front_door' },
                   'output' => 'hinge', 'kind' => 'bands', 'input' => HR::INPUT_WEIGHT,
                   'bands' => [{ 'max' => 2.0, 'quantity' => 2 },
                               { 'max' => nil, 'quantity' => 4 }] }].freeze
end

NxTest.test('KOV-W: pásmové pravidlo počíta z HMOTNOSTI čela (vstup `weight`)') do
  k = NxKovW
  NxTest.assert_equal('weight', k::HR::INPUT_WEIGHT)
  # Celo 616 x 596 x 18: pri 750 kg/m3 = 4,96 kg (nad pasmom 2) -> 4 zavesy.
  heavy = k.plan(k::MAT, {}, rules: k::WEIGHT_RULE)
  hinge = heavy[:hardware].find { |h| h['generic_type'] == 'hinge' }
  NxTest.assert(!hinge.nil?, 'položka vznikla')
  NxTest.assert_equal(4, hinge['quantity'], 'ťažké čelo = horné pásmo')
  # To iste celo z lahsieho materialu (200 kg/m3 = 1,32 kg) -> spodne pasmo.
  light = k.plan(k.channels(k.mat(18.0, 200.0)), {}, rules: k::WEIGHT_RULE)
  NxTest.assert_equal(2, light[:hardware].find { |h| h['generic_type'] == 'hinge' }['quantity'])
end

NxTest.test('KOV-W: hrubšie čelo prehodí pásmo závesov (hrúbka ide do rozhodnutia)') do
  k = NxKovW
  # 18 mm celo pri 200 kg/m3 = 1,32 kg (spodne pasmo); to iste celo z 25 mm
  # dosky = 1,84 kg. Pri prahu 1,5 kg musia pasma vyjst ROZDIELNE — dokaz, ze
  # hrubka nie je len kozmetika, ale vstup pravidiel kovania.
  rule = [k::WEIGHT_RULE.first.merge('bands' => [{ 'max' => 1.5, 'quantity' => 2 },
                                                 { 'max' => nil, 'quantity' => 4 }])]
  thin = k.plan(k.channels(k.mat(18.0, 200.0)), {}, rules: rule)
  thick = k.plan(k.channels(k.mat(25.0, 200.0)), {}, rules: rule)
  NxTest.assert_equal(2, thin[:hardware].find { |h| h['generic_type'] == 'hinge' }['quantity'])
  NxTest.assert_equal(4, thick[:hardware].find { |h| h['generic_type'] == 'hinge' }['quantity'])
end

NxTest.test('KOV-W: plán BEZ materiálov pošle pravidlo `weight` existujúcou cestou „neznámy vstup"') do
  k = NxKovW
  pl = k::CN.build_plan(k.cfg, 'CAB-1', hardware_rules: k::WEIGHT_RULE)
  NxTest.assert_equal([], pl[:hardware].select { |h| h['generic_type'] == 'hinge' },
                      'položka NEVZNIKNE (radšej nič než vymyslený počet)')
  skipped = pl[:warnings].select { |w| w['code'] == 'hardware_rule_skipped' }
  NxTest.assert_equal(1, skipped.length)
  NxTest.assert_equal('info', skipped.first['severity'])
  NxTest.assert_equal('weight', skipped.first['data']['input'])
end

# ---------------------------------------------------------------------------
# 7) SUCET NAD VYROBNYMI ZAZNAMAMI (Inspector, kusovnik)
# ---------------------------------------------------------------------------

module NxKovW
  SHEETS = {
    'DTD_18' => { 'material_id' => 'DTD_18', 'type' => 'DTDL', 'thickness' => 18.0 },
    'MDF_18' => { 'material_id' => 'MDF_18', 'type' => 'MDF', 'thickness' => 18.0 },
    'UNI_18' => { 'material_id' => 'UNI_18', 'type' => 'DTDL', 'uni' => true }
  }.freeze

  module_function

  def rec(mid, len, wid, th, qty = 1)
    { 'material_id' => mid, 'length' => len, 'width' => wid, 'thickness' => th, 'quantity' => qty }
  end
end

NxTest.test('KOV-W: `Bom.weight_totals` sčíta cez `quantity` a odhad nepočíta') do
  k = NxKovW
  out = k::BOM.weight_totals([k.rec('DTD_18', 1000.0, 600.0, 18.0, 2),
                              k.rec('MDF_18', 600.0, 720.0, 18.0)], k::SHEETS)
  NxTest.assert_close(7.344 * 2 + 5.832, out['kg'], 0.01)
  NxTest.assert_equal(0, out['estimated_parts'])
  NxTest.assert_equal(nil, out['estimated_density'], 'bez odhadu sa hustota neuvádza')
  NxTest.assert_equal(out['kg'], out['kg'].round(2), 'zaokrúhlené na 2 desatinné')
end

NxTest.test('KOV-W: voľná doska s `quantity > 1` sa počíta celá (kusy, nie riadky)') do
  k = NxKovW
  one = k::BOM.weight_totals([k.rec('DTD_18', 1200.0, 600.0, 18.0)], k::SHEETS)
  five = k::BOM.weight_totals([k.rec('DTD_18', 1200.0, 600.0, 18.0, 5)], k::SHEETS)
  NxTest.assert_close(one['kg'] * 5, five['kg'], 0.01, 'päť kusov = päťnásobok')
  NxTest.assert_equal(0, five['estimated_parts'], 'známa hustota = žiadny odhad')
  # Poskodena/chybajuca `quantity` sa berie ako 1 kus (nikdy 0 = ticho).
  NxTest.assert_close(one['kg'], k::BOM.weight_totals(
    [{ 'material_id' => 'DTD_18', 'length' => 1200.0, 'width' => 600.0, 'thickness' => 18.0 }],
    k::SHEETS
  )['kg'], 0.01)
end

NxTest.test('KOV-W: UNI aj materiál mimo katalógu sú ODHAD — dielec sa NEVYNECHÁ') do
  k = NxKovW
  fb = k::M.fallback_density
  out = k::BOM.weight_totals([k.rec('DTD_18', 1000.0, 600.0, 18.0),
                              k.rec('UNI_18', 1000.0, 600.0, 18.0, 3),
                              k.rec('MIMO_KATALOGU', 1000.0, 600.0, 18.0),
                              k.rec('', 1000.0, 600.0, 18.0)], k::SHEETS)
  want = k::M.weight_kg(1000.0, 600.0, 18.0, 680.0) +
         (k::M.weight_kg(1000.0, 600.0, 18.0, fb) * 5)
  NxTest.assert_close(want, out['kg'], 0.01)
  NxTest.assert_equal(5, out['estimated_parts'], 'počítajú sa KUSY (3 + 1 + 1), nie riadky')
  NxTest.assert_equal(fb, out['estimated_density'])
end

NxTest.test('KOV-W: bez katalógu (prázdna mapa) beží všetko na ťažšom odhade, nie na nule') do
  k = NxKovW
  out = k::BOM.weight_totals([k.rec('DTD_18', 1000.0, 600.0, 18.0)], {})
  NxTest.assert_close(k::M.weight_kg(1000.0, 600.0, 18.0, k::M.fallback_density), out['kg'], 0.01)
  NxTest.assert_equal(1, out['estimated_parts'])
  NxTest.assert_equal({ 'kg' => 0.0, 'estimated_parts' => 0, 'estimated_density' => nil },
                      k::BOM.weight_totals([], k::SHEETS), 'skrinka bez dielcov = 0 (Inspector z toho spraví „—")')
end

# ---------------------------------------------------------------------------
# 8) KONTROLA — jeden problem, jedna veta
# ---------------------------------------------------------------------------

module NxKovW
  module_function

  def wrec(mid, part_key)
    { 'owner_id' => 'CAB-1', 'part_key' => part_key, 'material_id' => mid, 'role' => 'side_left',
      'name' => part_key, 'length' => 700.0, 'width' => 500.0, 'thickness' => 18.0,
      'quantity' => 1, 'edges' => { 'L1' => 'ABS', 'L2' => 'ABS', 'W1' => 'ABS', 'W2' => 'ABS' } }
  end

  # Hmotnostne warningy, ktore PLAN naozaj vyda pre dane materialove zaznamy
  # (integracia: ziadne rucne pisany warning, ide o ten isty kod ako v stavbe).
  def plan_weight_warnings(specs)
    parts = specs.each_with_index.map do |(key, rec), i|
      [key, rec, desc('side_left', :korpus, 700.0, 500.0, 18.0, key), i]
    end
    materials = { 'channels' => { 'body' => mat(18.0, 680.0) },
                  'parts' => parts.to_h { |key, rec, _, _| [key, rec] } }
    _, ws = annotate(parts.map { |_, _, pd, _| pd }, materials)
    ws.map { |w| w.merge('owner_id' => 'CAB-1') }
  end

  def build_items(records, warnings)
    V.run({ records: records, hardware_overrides: [], warnings: warnings },
          sheets: SHEETS)['items'].select { |i| i['category'] == V::CAT_BUILD }
  end

  def weight_items(items)
    items.select { |i| i['message_sk'].to_s.include?('Hmotnos') }
  end
end

NxTest.test('KOV-W Kontrola: skrinka s UNI dielcom nemá o hmotnosti ANI JEDEN nález') do
  k = NxKovW
  ws = k.plan_weight_warnings([['cabinet/side:left', k.mat(18.0, nil, true)]])
  NxTest.assert_equal([], ws, 'plán warning za UNI dielec vôbec NEVYDÁ')
  items = k.build_items([k.wrec('UNI_18', 'cabinet/side:left')], ws)
  NxTest.assert_equal([], k.weight_items(items), 'Kontrola teda nemá čo hlásiť')
  # A UNI sa hlasi svojou vlastnou (jednou) vetou — nalez sa nestratil.
  uni = k::V.run({ records: [k.wrec('UNI_18', 'cabinet/side:left')],
                   hardware_overrides: [], warnings: ws },
                 sheets: k::SHEETS)['items'].select { |i| i['category'] == k::V::CAT_UNI }
  NxTest.assert_equal(1, uni.length, 'ostáva presne jedno „materiál neurčený"')
end

NxTest.test('KOV-W Kontrola: typ BEZ hustoty (nie UNI) dá PRESNE JEDEN ORANGE') do
  k = NxKovW
  ws = k.plan_weight_warnings([['cabinet/side:left', k.mat(18.0, nil, false)]])
  NxTest.assert_equal(1, ws.length, 'plán vydá jeden warning na skrinku')
  items = k.weight_items(k.build_items([k.wrec('DTD_18', 'cabinet/side:left')], ws))
  NxTest.assert_equal(1, items.length, 'a Kontrola z neho spraví jeden riadok')
  NxTest.assert_equal(k::V::ORANGE, items.first['severity'])
end

NxTest.test('KOV-W Kontrola: v mixovanej skrinke menuje warning LEN ne-UNI dielce') do
  k = NxKovW
  ws = k.plan_weight_warnings([['cabinet/side:left', k.mat(18.0, nil, true)],
                               ['cabinet/side:right', k.mat(18.0, nil, false)]])
  NxTest.assert_equal(1, ws.length)
  NxTest.assert_equal(['cabinet/side:right'], ws.first['data']['parts'],
                      'UNI dielec v zozname NIE JE (hlási ho `uni_material`)')
  NxTest.assert(ws.first['message'].include?('1 dielca'), "počet je 1: #{ws.first['message']}")
  items = k.weight_items(k.build_items([k.wrec('UNI_18', 'cabinet/side:left'),
                                        k.wrec('DTD_18', 'cabinet/side:right')], ws))
  NxTest.assert_equal(1, items.length, 'jeden ORANGE za ne-UNI dielec')
end

NxTest.test('KOV-W GUARD: Kontrola hmotnostný warning NEFILTRUJE (filter je v pláne)') do
  k = NxKovW
  src = File.read(File.join(k::CORE, 'validation.rb'))
  NxTest.assert(!src.include?('weight_parts_all_uni?'),
                'druhý filter v Kontrole by zvonček Inspectora (uložené warningy) obišiel')
  # Co je ULOZENE, to Kontrola aj ukaze — aj ked je dielec medzitym na UNI.
  ws = k.plan_weight_warnings([['cabinet/side:left', k.mat(18.0, nil, false)]])
  items = k.weight_items(k.build_items([k.wrec('UNI_18', 'cabinet/side:left')], ws))
  NxTest.assert_equal(1, items.length, 'uložený warning sa nezahadzuje')
end

# ---------------------------------------------------------------------------
# 9) INSPECTOR (D-125)
# ---------------------------------------------------------------------------

NxTest.test('KOV-W GUARD: payload skrinky nesie `weight_*` a berie ich z `Bom.weight_totals`') do
  k = NxKovW
  src = k.body(k::RES_RB, 'cabinet_stats', 8)
  NxTest.assert(src.include?('Bom.weight_totals'), 'jeden vzorec — Inspector si nič neopisuje')
  %w[weight_kg weight_estimated_parts weight_estimated_density].each do |key|
    NxTest.assert(src.include?("'#{key}'"), "payload nesie #{key}")
  end
  # Aj zachranna vetva (rescue) musi kluce vratit — inak by JS dostal undefined
  # a riadok by ostal zatuchnuty na cudzej hodnote.
  NxTest.assert_equal(2, src.scan("'weight_kg'").length, 'kľúče sú aj v rescue vetve')
end

# ---------------------------------------------------------------------------
# 10) REGRESIA — hmotnost je TRANZIENTNA (nikdy v modeli ani vo vystupoch)
# ---------------------------------------------------------------------------

NxTest.test('KOV-W REGRESIA: hmotnosť sa NEZAPISUJE do snapshotu dielca ani do configu skrinky') do
  k = NxKovW
  add_part = k.body(k::CB_RB, 'add_part', 8)
  merge_final = k.body(k::CB_RB, 'merge_final', 8)
  NxTest.assert(!add_part.empty? && !merge_final.empty?, 'obe metódy sa našli')
  [['add_part', add_part], ['merge_final', merge_final]].each do |name, src|
    NxTest.assert(!src.include?('weight'), "#{name}: do modelu nesmie ísť žiadny `weight_*` kľúč")
  end
  # A kluce planu, ktore `merge_final` kopiruje, su MENOVITE (nie `plan.merge`).
  NxTest.assert(!merge_final.include?('plan.each'), 'kopíruje sa menovitý zoznam kľúčov')
end

NxTest.test('KOV-W REGRESIA: `Bom.row_key` sa nezmenil — hmotnosť riadky nerozdeľuje') do
  k = NxKovW
  base = k.rec('DTD_18', 1000.0, 600.0, 18.0, 2).merge(
    'edges' => { 'L1' => 'A', 'L2' => nil, 'W1' => nil, 'W2' => nil }, 'grain_direction' => 'none'
  )
  with_weight = base.merge('weight_kg' => 7.344, 'weight_estimated' => false)
  NxTest.assert_equal(k::BOM.row_key(base), k::BOM.row_key(with_weight),
                      'dva rovnaké dielce sa nesmú rozpadnúť na dva riadky')
  NxTest.assert_equal(7, k::BOM.row_key(base).length, 'kľúč má stále 7 prvkov')
  NxTest.assert(!k.body(k::BOM_RB, 'row_key', 6).include?('weight'), 'v kľúči nie je hmotnosť')
end

NxTest.test('KOV-W REGRESIA: anotácia NEMENÍ `prod` ani rozmery dielcov') do
  k = NxKovW
  plain = k::CN.build_plan(k.cfg, 'CAB-1')
  annotated = k.plan(k.channels(k.mat(25.0, 750.0)))
  NxTest.assert_equal(plain[:parts].map { |p| [p[:part_key], p[:prod], p[:box], p[:origin]] },
                      annotated[:parts].map { |p| [p[:part_key], p[:prod], p[:box], p[:origin]] },
                      'geometria a výrobné rozmery sú bajt na bajt tie isté')
  NxTest.assert_equal(plain[:parts].length, annotated[:parts].length)
end
