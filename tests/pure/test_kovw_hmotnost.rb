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
#   3) `build_plan(densities:)` anotuje KAŽDÝ dielec (`weight_kg`, `weight_estimated`)
#      vrátane dielcov zásuviek; fallback dá PRESNE JEDEN warning na skrinku
#      (nie na dielec) so zoznamom dotknutých part_key
#   4) charakterizácia starých volajúcich: `build_plan` BEZ `densities` nemá ani
#      kľúče, ani warning (migrácia identity a panelové resolvery sa nemenia)
#   5) per-part override hustoty má prednosť pred kanálom — aj keď je nil
#   6) `material_channel` je JEDINÉ miesto pravdy o materiálovom kanáli:
#      `CabinetBuilder.base_material_for` cez neho vyberá TÚ ISTÚ dosku ako pred
#      KOV-W (charakterizácia nad každou rolou × každým signálom)
#   7) `HardwareRules` vstup `weight` — pásmové pravidlo počíta z hmotnosti čela;
#      bez anotácie (plán bez hustôt) položka NEVZNIKNE + info warning
#   8) `Bom.weight_totals` — súčet cez `quantity`, UNI aj materiál mimo katalógu
#      sú ODHAD (nikdy vynechaný dielec)
#   9) Kontrola: hmotnostný warning sa nad UNI dielcami POTLAČÍ (UNI už hlási
#      `uni_material`), ale ostáva viditeľný, keď je medzi nimi typ bez hustoty
#  10) Inspector (D-125): payload skrinky nesie `weight_kg` + `weight_estimated_*`
#      a berie ich z `Bom.weight_totals` (zdrojový guard; živý beh je in-SU)
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1  vzorec delí 1e6 namiesto 1e9              -> „jeden vzorec"
#   M2  `fallback_density` berie aj KOMPAKT       -> ťažký odhad by bol 1350
#   M3  hustota 870 napísaná ako literál          -> zdrojový guard
#   M4  dielec bez hustoty sa zo súčtu vynechá    -> `estimated_parts` a súčet
#   M5  warning per DIELEC namiesto per skrinka   -> „presne jeden warning"
#   M6  anotácia beží aj bez `densities`          -> charakterizácia starých volajúcich
#   M7  per-part override nil prehliadnutý        -> precedencia overridu
#   M8  `base_material_for` má vlastný `case`     -> guard jedného miesta pravdy
#   M9  `input_value` nepozná `weight`            -> pásmové pravidlo nad čelom
#   M10 Kontrola potlačí warning aj pri type bez hustoty -> mixovaná skrinka
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

  # Hustoty kanalov = realne cisla registra (DTDL/MDF/HDF), nie vymyslene.
  CH = { 'body' => 680.0, 'front' => 750.0, 'back' => 870.0, 'drawer' => 680.0 }.freeze
  DENS = { 'channels' => CH, 'parts' => {} }.freeze
  NO_DENS = { 'channels' => { 'body' => nil, 'front' => nil, 'back' => nil, 'drawer' => nil },
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

  def plan(densities = DENS, over = {}, rules: [])
    CN.build_plan(cfg(over), 'CAB-1', hardware_rules: rules, densities: densities)
  end

  def weight_warnings(pl)
    Array(pl[:warnings]).select { |w| w['code'] == 'weight_density_unknown' }
  end

  def part(pl, key)
    pl[:parts].find { |p| p[:part_key] == key }
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
    'part_densities' => k.body(k::CB_RB, 'part_densities', 8),
    'sheet_density' => k.body(k::CB_RB, 'sheet_density', 8),
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

NxTest.test('KOV-W: s `densities` má KAŽDÝ dielec plánu hmotnosť a žiadny nie je odhad') do
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
  door = pl[:parts].find { |p| p[:role] == 'front_door' }
  [[side, k::CH['body']], [back, k::CH['back']], [door, k::CH['front']]].each do |pd, dens|
    NxTest.assert(!pd.nil?, 'dielec je v pláne')
    want = k::M.weight_kg(pd[:prod][:length], pd[:prod][:width], pd[:prod][:thickness], dens)
    NxTest.assert_close(want, pd[:weight_kg], 0.000001,
                        "#{pd[:part_key]}: kanál #{k::CN.material_channel(pd[:role], pd[:material])}")
  end
  # Chrbat (HDF 870) je iny kanal nez telo — keby anotacia brala vsade telo,
  # tento rozdiel by zmizol.
  NxTest.assert(k::CH['back'] != k::CH['body'])
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
  one = k.plan({ 'channels' => k::CH, 'parts' => { 'cabinet/back' => nil } })
  NxTest.assert(k.weight_warnings(one).first['message'].include?('1 dielca'),
                k.weight_warnings(one).first['message'])
  many = k.plan(k::NO_DENS)
  NxTest.assert(k.weight_warnings(many).first['message'].match?(/\d+ dielcov/),
                k.weight_warnings(many).first['message'])
end

NxTest.test('KOV-W: plán BEZ `densities` nemá ani kľúče, ani warning (starí volajúci)') do
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

NxTest.test('KOV-W: per-part override hustoty PREBÍJA kanál — aj keď je nil') do
  k = NxKovW
  # 1) override s VLASTNOU hustotou (kompakt) — dielec nie je odhad, ale je tazsi
  heavy = k.plan({ 'channels' => k::CH, 'parts' => { 'cabinet/back' => 1350.0 } })
  back = k.part(heavy, 'cabinet/back')
  want = k::M.weight_kg(back[:prod][:length], back[:prod][:width], back[:prod][:thickness], 1350.0)
  NxTest.assert_close(want, back[:weight_kg], 0.000001)
  NxTest.assert_equal(false, back[:weight_estimated])
  NxTest.assert_equal([], k.weight_warnings(heavy))
  # 2) override BEZ hustoty (nil) — override existuje, takze kanal sa NEPOUZIJE
  est = k.plan({ 'channels' => k::CH, 'parts' => { 'cabinet/back' => nil } })
  back2 = k.part(est, 'cabinet/back')
  NxTest.assert_equal(true, back2[:weight_estimated], 'nil override = odhad, nie kanál')
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
  pl = k::CN.build_plan(k.drawer_cfg, 'CAB-1', densities: k::DENS)
  dr = pl[:parts].select { |p| p[:material] == :drawer }
  NxTest.assert(dr.length >= 2, "dielce zásuvky sú v pláne (#{dr.length})")
  dr.each do |pd|
    NxTest.assert_equal(k::CN::CHANNEL_DRAWER, k::CN.material_channel(pd[:role], pd[:material]))
    want = k::M.weight_kg(pd[:prod][:length], pd[:prod][:width], pd[:prod][:thickness], k::CH['drawer'])
    NxTest.assert_close(want, pd[:weight_kg], 0.000001, pd[:part_key])
    NxTest.assert_equal(false, pd[:weight_estimated])
  end
end

# ---------------------------------------------------------------------------
# 4) MATERIALOVY KANAL — jedno miesto pravdy
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

# ---------------------------------------------------------------------------
# 5) PRAVIDLA KOVANIA — vstup `weight`
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
  heavy = k.plan(k::DENS, {}, rules: k::WEIGHT_RULE)
  hinge = heavy[:hardware].find { |h| h['generic_type'] == 'hinge' }
  NxTest.assert(!hinge.nil?, 'položka vznikla')
  NxTest.assert_equal(4, hinge['quantity'], 'ťažké čelo = horné pásmo')
  # To iste celo z lahsieho materialu (200 kg/m3 = 1,32 kg) -> spodne pasmo.
  light = k.plan({ 'channels' => k::CH.merge('front' => 200.0), 'parts' => {} }, {},
                 rules: k::WEIGHT_RULE)
  NxTest.assert_equal(2, light[:hardware].find { |h| h['generic_type'] == 'hinge' }['quantity'])
end

NxTest.test('KOV-W: plán BEZ hustôt pošle pravidlo `weight` existujúcou cestou „neznámy vstup"') do
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
# 6) SUCET NAD VYROBNYMI ZAZNAMAMI (Inspector, kusovnik)
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
# 7) KONTROLA — jeden problem, jedna veta
# ---------------------------------------------------------------------------

module NxKovW
  module_function

  def wrec(mid, part_key)
    { 'owner_id' => 'CAB-1', 'part_key' => part_key, 'material_id' => mid, 'role' => 'side_left',
      'name' => part_key, 'length' => 700.0, 'width' => 500.0, 'thickness' => 18.0,
      'quantity' => 1, 'edges' => { 'L1' => 'ABS', 'L2' => 'ABS', 'W1' => 'ABS', 'W2' => 'ABS' } }
  end

  def weight_warning(parts)
    { 'code' => 'weight_density_unknown', 'severity' => 'warn', 'owner_id' => 'CAB-1',
      'part_key' => nil, 'message' => 'Hmotnosť je odhad.', 'data' => { 'parts' => parts } }
  end

  def build_items(records, warning)
    V.run({ records: records, hardware_overrides: [], warnings: [warning] },
          sheets: SHEETS)['items'].select { |i| i['category'] == V::CAT_BUILD }
  end
end

NxTest.test('KOV-W Kontrola: nad SAMÝMI UNI dielcami sa hmotnostný warning potlačí') do
  k = NxKovW
  items = k.build_items([k.wrec('UNI_18', 'cabinet/side:left')],
                        k.weight_warning(['cabinet/side:left']))
  NxTest.assert_equal([], items, 'UNI už hlási `uni_material` — druhá veta o tom istom nie')
  # Dokaz, ze guard nemeria prazdno: TEN ISTY warning nad znamym materialom vidiet.
  seen = k.build_items([k.wrec('DTD_18', 'cabinet/side:left')],
                       k.weight_warning(['cabinet/side:left']))
  NxTest.assert_equal(1, seen.length)
  NxTest.assert_equal(NxKovW::V::ORANGE, seen.first['severity'])
end

NxTest.test('KOV-W Kontrola: typ bez hustoty (nie UNI) ostáva viditeľný aj v mixovanej skrinke') do
  k = NxKovW
  items = k.build_items([k.wrec('UNI_18', 'cabinet/side:left'),
                         k.wrec('DTD_18', 'cabinet/side:right')],
                        k.weight_warning(['cabinet/side:left', 'cabinet/side:right']))
  NxTest.assert_equal(1, items.length, 'aspoň jeden nie-UNI dielec = warning ostáva')
end

NxTest.test('KOV-W Kontrola: warning bez zoznamu dielcov sa NEPOTLAČÍ (radšej veta navyše)') do
  k = NxKovW
  w = k.weight_warning([])
  items = k.build_items([k.wrec('UNI_18', 'cabinet/side:left')], w)
  NxTest.assert_equal(1, items.length)
end

# ---------------------------------------------------------------------------
# 8) INSPECTOR (D-125)
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
