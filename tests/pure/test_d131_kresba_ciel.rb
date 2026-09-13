# frozen_string_literal: true
# Testy D-131 — HROMADNA KRESBA CIEL ZAKAZKY (ProductionCore).
#
# PRECO tato sada existuje: smer dekoru sa do 13.9.2026 dal nastavit LEN po
# jednom dielci (K1/D-108). D-131 pridava hromadnu cestu nad CELOU zakazkou —
# a hromadna cesta nesmie zaviest DRUHY kontrakt: zapisuje sa PRESNE ten isty
# override `part_overrides[<kluc cela>]['grain_direction']`.
#
# ZAVAZNY KONTRAKT, ktory tu zamykame (porusenie = zle objednany dielec):
#   1) ROZSAH: LEN fyzicke cela (dvierka vratane kazdeho kridla, zasuvkove
#      celo, vyklop/sklop, blenda). „Bez čela" (`none`) NIE, korpusove dielce
#      NIE, dosky NIE, dielce zasuviek NIE.
#   2) TVAR KLUCOV sa NEOPISUJE druhykrat — sklada ich `Fronts.panels_for`.
#      Druhy parser by sa casom rozisiel a override by ticho sadol na dielec,
#      ktory v plane neexistuje.
#   3) ENUM: zapise sa LEN 'length'/'width'; `__inherit__` override MAZE
#      (a prazdny zaznam zanika). Neznama hodnota = ODMIETNUTY zapis, NIKDY
#      tichy fallback.
#   4) FAIL-VISIBLE: skrinka z NOVSEJ verzie (R-12) sa preskoci a VYMENUJE;
#      nerozlustena polozka (dvierka bez `wings_n`) tiez — pocet kridiel sa
#      NEHADA.
#   5) NIC INE sa nedotkne: korpusove overridy (ABS, material dielca) aj cely
#      zvysok configu ostavaju BAJTOVO nezmenene.
#   6) 0 ciel = ZIADNA operacia (a teda ziadny krok Späť).
#
# MUTACIE OVERENE proti tejto sade (kazda ju zhodi):
#   M1 — akcia zapise aj celu typu `none`  -> „rozsah: „Bez čela" (none) dielec nema"
#   M2 — `fronts_grain_plan` vrati kazdu skrinku vo VLASTNOM zozname jobs
#        -> „plan: VSETKY skrinky su v JEDNOM zozname jobs". (Ze je z toho aj
#        jedna OPERACIA, drzi in-SU marker `run_d131` — headless sada tu meri
#        TVAR planu, SketchUp operacie nemá kde spustit.)
#   M3 — neznama hodnota `grain` prejde na server -> „guard: neznamy smer sa ODMIETNE"
#   M4 — `__inherit__` nechá prazdny zaznam v `part_overrides` -> „inherit: prazdny
#        zaznam ZANIKA"
#   M5 — zber ide `Ids.each_cabinet` (globalne, aj vnorene skrinky)
#        -> „zber: zakazka je TOP-LEVEL `model.entities`"
#   M6 — odmietava vetva neposle `repush` -> guardy v sekcii 5 (tlacidlo by
#        v kliente navzdy viselo na „Prestavujem…")
#   M7 — skrinka s ODPOJENYM dielcom sa prestava -> „odpojeny dielec: plan ju
#        do prestavby NEPUSTI" (v modeli by vznikol DVOJNIK)
require_relative '../helper' unless defined?(NxTest)

# UI vrstva — headless nie je v require zozname helpera, takze si ju sada pyta
# sama (vzor `test_kovc2b_brany.rb`). ZAPISOVA cesta zije v `MaterialsDialog`
# (brana 1b-3 — `production_core.rb` je CITACIA cesta a nesmie si vyziadat
# dedup), cisty plan a suhrn v `ProductionCore`.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog')
end

D131PC = Noxun::Engine::ProductionCore
D131MD = Noxun::Engine::MaterialsDialog
D131CB = Noxun::Engine::CabinetBuilder
D131DK = Noxun::Engine::DocKey

# Resolved celo (`config['front_items']`) — presne to, co uklada builder.
def d131_item(id, type, wings_n = 1)
  { 'id' => id, 'type' => type, 'mode' => 'auto', 'height' => nil,
    'wings_n' => wings_n, 'profile' => 'none' }
end

def d131_cfg(items, overrides = {}, extra = {})
  { 'front_items' => items, 'part_overrides' => overrides }.merge(extra)
end

# Stub modelu pre identity guardy (vzor `DkFakeModel` v test_doc_key.rb).
class D131FakeModel
  attr_accessor :path, :guid

  def initialize
    @path = 'C:/Zakazky/D131.skp'
    @guid = 'G-D131'
  end

  def valid?
    true
  end
end

# Zachytavac hlasok a pushov okna.
def d131_sink
  { status: [], repush: 0 }
end

def d131_status(sink)
  ->(msg, err = false) { sink[:status] << [msg, err] }
end

def d131_repush(sink)
  -> { sink[:repush] += 1 }
end

# ---------------------------------------------------------------------------
# 1) ROZSAH A TVAR KLUCOV
# ---------------------------------------------------------------------------

# Zoznam `part_key`-ov (sada ich porovnava, legacy suffix ma vlastne testy).
def d131_keys(items)
  parts, unresolved = D131PC.front_grain_keys(items)
  [parts.map { |p| p['key'] }, unresolved]
end

NxTest.test('D-131 rozsah: zasuvkove celo je `panel`') do
  keys, unresolved = d131_keys([d131_item('F1', 'drawer_front')])
  NxTest.assert_equal(['front:F1/panel'], keys)
  NxTest.refute(unresolved, 'resolved polozka nie je nerozlustena')
end

NxTest.test('D-131 rozsah: vyklop AJ sklop maju kanonicky kluc `flap`') do
  lift, = d131_keys([d131_item('F1', 'lift')])
  fall, = d131_keys([d131_item('F1', 'fall')])
  NxTest.assert_equal(['front:F1/flap'], lift)
  NxTest.assert_equal(['front:F1/flap'], fall, 'sklop ma TEN ISTY kluc ako vyklop (KOV-A1)')
end

NxTest.test('D-131 rozsah: blenda je `blind`') do
  keys, = d131_keys([d131_item('F1', 'blind')])
  NxTest.assert_equal(['front:F1/blind'], keys)
end

NxTest.test('D-131 rozsah: dvierka daju kluc KAZDEMU kridlu (1 / 2 / 3)') do
  one, = d131_keys([d131_item('F1', 'door', 1)])
  two, = d131_keys([d131_item('F1', 'door', 2)])
  three, = d131_keys([d131_item('F1', 'door', 3)])
  NxTest.assert_equal(['front:F1/wing:single'], one)
  NxTest.assert_equal(['front:F1/wing:left', 'front:F1/wing:right'], two)
  NxTest.assert_equal(['front:F1/wing:p1', 'front:F1/wing:p2', 'front:F1/wing:p3'], three)
end

NxTest.test('D-131 rozsah: „Bez čela" (none) dielec nema — nie je co otacat') do
  keys, unresolved = d131_keys([d131_item('F1', 'none')])
  NxTest.assert_equal([], keys)
  NxTest.refute(unresolved, 'prazdna nika NIE JE chyba')
end

NxTest.test('D-131 rozsah: viac riadkov ciel v jednej skrinke = vsetky kluce') do
  keys, = d131_keys([d131_item('F1', 'drawer_front'),
                     d131_item('F2', 'none'),
                     d131_item('F3', 'door', 2)])
  NxTest.assert_equal(['front:F1/panel', 'front:F3/wing:left', 'front:F3/wing:right'], keys)
end

NxTest.test('D-131 fail-visible: dvierka BEZ `wings_n` = nerozlustene (pocet sa NEHADA)') do
  keys, unresolved = d131_keys([{ 'id' => 'F1', 'type' => 'door' }])
  NxTest.assert_equal([], keys, 'z nerozlustenej skrinky nejde ZIADEN kluc')
  NxTest.assert(unresolved, 'skrinka sa ma preskocit a vymenovat')
end

NxTest.test('D-131 rozsah: chybajuce `front_items` = skrinka bez ciel') do
  keys, unresolved = d131_keys(nil)
  NxTest.assert_equal([], keys)
  NxTest.refute(unresolved)
end

# ---------------------------------------------------------------------------
# 2) ZAPIS OVERRIDU
# ---------------------------------------------------------------------------

# Dielec tak, ako ho dava `front_grain_keys` (dnesny kluc + legacy suffix).
def d131_part(key = 'front:F1/panel', legacy = 'DRW-1')
  { 'key' => key, 'legacy' => legacy }
end

NxTest.test('D-131 zapis: `width` PREPISE existujuci override') do
  params = { 'part_overrides' => { 'front:F1/panel' => { 'grain_direction' => 'length' } } }
  n = D131PC.front_grain_write!(params, [d131_part], 'width')
  NxTest.assert_equal(1, n)
  NxTest.assert_equal('width', params['part_overrides']['front:F1/panel']['grain_direction'])
end

NxTest.test('D-131 zapis: celo, ktore uz ma pozadovany smer, sa NEta (0 zmien)') do
  params = { 'part_overrides' => { 'front:F1/panel' => { 'grain_direction' => 'width' } } }
  NxTest.assert_equal(0, D131PC.front_grain_write!(params, [d131_part], 'width'))
end

NxTest.test('D-131 inherit: prazdny zaznam ZANIKA (kluc aj cely zaznam)') do
  params = { 'part_overrides' => { 'front:F1/panel' => { 'grain_direction' => 'width' } } }
  n = D131PC.front_grain_write!(params, [d131_part], D131PC::FRONT_GRAIN_INHERIT)
  NxTest.assert_equal(1, n)
  NxTest.assert_equal({}, params['part_overrides'], 'prazdny zaznam sa ma odstranit')
end

NxTest.test('D-131 inherit: zaznam s ABS hranami PREZIJE (maze sa LEN grain_direction)') do
  rec = { 'grain_direction' => 'width', 'edges' => { 'L1' => 'ABS_X' } }
  params = { 'part_overrides' => { 'front:F1/panel' => rec } }
  D131PC.front_grain_write!(params, [d131_part], D131PC::FRONT_GRAIN_INHERIT)
  NxTest.assert_equal({ 'edges' => { 'L1' => 'ABS_X' } },
                      params['part_overrides']['front:F1/panel'],
                      'ABS override dielca sa hromadnou kresbou NESMIE stratit')
end

NxTest.test('D-131 zapis: korpusove overridy a zvysok configu ostanu BAJTOVO nezmenene') do
  other = { 'cabinet/side:left' => { 'edges' => { 'W1' => 'ABS_A' } },
            'zone:Z1/shelf:1' => { 'material_id' => 'DUB18' } }
  before = Marshal.dump(other)
  params = { 'part_overrides' => other.merge('front:F1/panel' => {}) }
  D131PC.front_grain_write!(params, [d131_part], 'length')
  after = other.select { |k, _| k != 'front:F1/panel' }
  NxTest.assert_equal(before, Marshal.dump(after), 'cudzie overridy sa nesmu ani dotknut')
  NxTest.assert_equal('length', params['part_overrides']['front:F1/panel']['grain_direction'])
end

# --- LEGACY SLOT (stara skrinka spred `part_key`) ---------------------------
# Override pod RENDEROVACIM suffixom prezije az do najblizsej prestavby, kde ho
# zmigruje `CabinetBuilder.normalize`. Kym zije, MUSI ho riadok VIDIET a akcia
# PREBIT — inak by „Podľa materiálu" override nezrusilo (migracia by starú
# hodnotu vratila do hry) a riadok by hlasil „podľa materiálu" pri zapisanom
# smere (review #365, P3).

NxTest.test('D-131 legacy: smer pod RENDEROVACIM suffixom sa v suhrne VIDI') do
  ent = D131PC.front_grain_entry('CAB-001',
                                 d131_cfg([d131_item('F1', 'drawer_front')],
                                          'DRW-1' => { 'grain_direction' => 'width' }))
  NxTest.assert_equal({ 'length' => 0, 'width' => 1, 'inherit' => 0 },
                      D131PC.front_grain_summary([ent])['by'],
                      'stara skrinka NESMIE hlasit „podľa materiálu", ked override MA')
end

NxTest.test('D-131 legacy: dnesny kluc vyhrava nad legacy suffixom') do
  ent = D131PC.front_grain_entry('CAB-001',
                                 d131_cfg([d131_item('F1', 'drawer_front')],
                                          'front:F1/panel' => { 'grain_direction' => 'length' },
                                          'DRW-1' => { 'grain_direction' => 'width' }))
  NxTest.assert_equal({ 'length' => 1, 'width' => 0, 'inherit' => 0 },
                      D131PC.front_grain_summary([ent])['by'])
end

NxTest.test('D-131 legacy: „Podľa materiálu" zmaze smer aj z LEGACY zaznamu') do
  params = { 'part_overrides' => { 'DRW-1' => { 'grain_direction' => 'width',
                                                'edges' => { 'L1' => 'ABS_X' } } } }
  n = D131PC.front_grain_write!(params, [d131_part], D131PC::FRONT_GRAIN_INHERIT)
  NxTest.assert_equal(1, n, 'zmena legacy slotu sa RATA ako zmena')
  NxTest.assert_equal({ 'DRW-1' => { 'edges' => { 'L1' => 'ABS_X' } } },
                      params['part_overrides'],
                      'ABS legacy zaznamu prezije, smer nie')
end

NxTest.test('D-131 legacy: zapis ide na DNESNY kluc a legacy smer zhasne') do
  params = { 'part_overrides' => { 'DRW-1' => { 'grain_direction' => 'length' } } }
  D131PC.front_grain_write!(params, [d131_part], 'width')
  NxTest.assert_equal({ 'front:F1/panel' => { 'grain_direction' => 'width' } },
                      params['part_overrides'],
                      'po migracii nesmie ostat druha (stara) hodnota')
end

# ---------------------------------------------------------------------------
# 3) SUHRN PRE RIADOK STUDIA
# ---------------------------------------------------------------------------

NxTest.test('D-131 suhrn: count/cabinets/by nad TROMI configmi') do
  entries = [
    D131PC.front_grain_entry('CAB-001', d131_cfg([d131_item('F1', 'door', 2)],
                                                 'front:F1/wing:left' => { 'grain_direction' => 'width' })),
    D131PC.front_grain_entry('CAB-002', d131_cfg([d131_item('F1', 'drawer_front'),
                                                  d131_item('F2', 'drawer_front')],
                                                 'front:F1/panel' => { 'grain_direction' => 'length' })),
    D131PC.front_grain_entry('CAB-003', d131_cfg([d131_item('F1', 'none')]))
  ]
  s = D131PC.front_grain_summary(entries)
  NxTest.assert_equal(4, s['count'], '2 kridla + 2 zasuvkove cela; skrinka bez ciel sa neta')
  NxTest.assert_equal(2, s['cabinets'], 'skrinka bez ciel sa do poctu NERATA')
  NxTest.assert_equal({ 'length' => 1, 'width' => 1, 'inherit' => 2 }, s['by'])
  NxTest.assert_equal([], s['skipped'], 'nic sa nepreskocilo')
end

NxTest.test('D-131 suhrn: neznama hodnota v configu sa rata ako `inherit` (nikdy vlastna skupina)') do
  ent = D131PC.front_grain_entry('CAB-001',
                                 d131_cfg([d131_item('F1', 'drawer_front')],
                                          'front:F1/panel' => { 'grain_direction' => 'diagonal' }))
  NxTest.assert_equal({ 'length' => 0, 'width' => 0, 'inherit' => 1 },
                      D131PC.front_grain_summary([ent])['by'])
end

NxTest.test('D-131 suhrn: skrinka z NOVSEJ verzie sa do cisla v tlacidle NERATA') do
  newer = d131_cfg([d131_item('F1', 'drawer_front')], {},
                   'config_schema' => D131CB::CONFIG_SCHEMA + 5)
  ent = D131PC.front_grain_entry('CAB-009', newer)
  NxTest.assert(ent['newer'], 'marker novsej schemy sa musi rozpoznat')
  out = D131PC.front_grain_summary([ent])
  NxTest.assert_equal(0, out['count'], 'tlacidlo nesmie slubit viac, nez akcia spravi')
  NxTest.assert_equal([{ 'id' => 'CAB-009', 'why' => 'novšia verzia pluginu' }], out['skipped'],
                      'preskocena skrinka sa v suhrne PRIZNA (inak by riadok hlasil „Žiadne čelá")')
end

NxTest.test('D-131 suhrn: config BEZ `front_items` je STARA skrinka, nie skrinka bez ciel') do
  ent = D131PC.front_grain_entry('CAB-005', { 'part_overrides' => {} })
  NxTest.assert(ent['legacy'], 'chybajuci zoznam resolved ciel sa musi rozpoznat')
  out = D131PC.front_grain_summary([ent])
  NxTest.assert_equal(0, out['count'])
  NxTest.assert_equal('CAB-005', out['skipped'][0]['id'])
  NxTest.assert(out['skipped'][0]['why'].to_s.include?('prestav'), out['skipped'].inspect)
end

NxTest.test('D-131 suhrn: PRAZDNY `front_items` je platna odpoved (skrinka cela nema)') do
  ent = D131PC.front_grain_entry('CAB-006', d131_cfg([]))
  NxTest.refute(ent['legacy'], 'prazdne pole NIE JE stara skrinka')
  NxTest.assert_equal([], D131PC.front_grain_summary([ent])['skipped'])
end

NxTest.test('D-131 odpojeny dielec: skrinka sa PRESKOCI a vymenuje (nikdy polovicny zapis)') do
  # Dielec vytiahnuty na koren modelu ide do kusovnika PO SVOJOM, ale
  # `rebuild_many` prestava LEN vnorene dielce — zapis by vyrobil DVOJNIKA
  # (vnoreny dielec s novym smerom, odpojeny so starym).
  ent = D131PC.front_grain_entry('CAB-004', d131_cfg([d131_item('F1', 'drawer_front')]))
  ent['detached'] = true
  why = D131PC.front_grain_skip_reason(ent)
  NxTest.assert(why.to_s.include?('odpojený'), why.inspect)
  out = D131PC.front_grain_summary([ent])
  NxTest.assert_equal(0, out['count'], 'do cisla v tlacidle sa neráta')
  NxTest.assert_equal([{ 'id' => 'CAB-004', 'why' => why }], out['skipped'])
end

NxTest.test('D-131 odpojeny dielec: plan ju do prestavby NEPUSTI') do
  ent = d131_entry('CAB-004', d131_cfg([d131_item('F1', 'drawer_front')]), :a)
  ent['detached'] = true
  plan = D131PC.fronts_grain_plan([ent], 'width')
  NxTest.assert_equal([], plan['jobs'])
  NxTest.assert_equal('CAB-004', plan['skipped'][0]['id'])
end

NxTest.test('D-131 odpojeny dielec: suhrn aj plan pouzivaju TU ISTU funkciu dovodu') do
  # Dva zoznamy dovodov by sa casom rozisli a tlacidlo by hovorilo nieco ine
  # nez akcia. Kazdy dovod, ktory vie dat `front_grain_skip_reason`, musi
  # rovnako vypadnut zo suhrnu aj z planu.
  %w[newer detached legacy unresolved].each do |flag|
    ent = D131PC.front_grain_entry('CAB-00X', d131_cfg([d131_item('F1', 'drawer_front')]))
    ent[flag] = true
    ent['ref'] = :x
    ent['params'] = { 'part_overrides' => {} }
    why = D131PC.front_grain_skip_reason(ent)
    NxTest.assert(why, "#{flag} musi mat dovod")
    NxTest.assert_equal([{ 'id' => 'CAB-00X', 'why' => why }],
                        D131PC.front_grain_summary([ent])['skipped'], flag)
    NxTest.assert_equal([{ 'id' => 'CAB-00X', 'why' => why }],
                        D131PC.fronts_grain_plan([ent], 'width')['skipped'], flag)
  end
end

NxTest.test('D-131 zber: odpojeny dielec sa hlada v TOM ISTOM prechode korenom') do
  # Mapa `cabinet_id => pocet odpojenych` vznika RAZ na zber (nie per skrinka)
  # a vlastnika berie z atributu `cabinet_id` — presne ako `Bom.collect`.
  NxTest.assert(D131_SCAN_SRC.include?("when 'part'") && D131_SCAN_SRC.include?('detached'),
                'zber musi odpojene dielce zisťovat sam')
  NxTest.assert(D131_SCAN_SRC.include?("Store.get(inst, 'manufactured') == true"),
                'ratat sa smu LEN vyrobne dielce')
end

# ---------------------------------------------------------------------------
# 4) PLAN HROMADNEHO ZAPISU
# ---------------------------------------------------------------------------

def d131_entry(id, cfg, ref)
  ent = D131PC.front_grain_entry(id, cfg)
  ent['ref'] = ref
  ent['params'] = { 'part_overrides' => (cfg['part_overrides'] || {}) }
  ent
end

NxTest.test('D-131 plan: VSETKY skrinky su v JEDNOM zozname jobs (jedna operacia)') do
  entries = [d131_entry('CAB-001', d131_cfg([d131_item('F1', 'door', 2)]), :a),
             d131_entry('CAB-002', d131_cfg([d131_item('F1', 'drawer_front')]), :b)]
  plan = D131PC.fronts_grain_plan(entries, 'width')
  NxTest.assert_equal(2, plan['jobs'].length, 'dve skrinky = DVE polozky jedneho zoznamu')
  NxTest.assert_equal(%i[a b], plan['jobs'].map(&:first))
  NxTest.assert_equal(3, plan['count'])
  NxTest.assert_equal(2, plan['cabinets'])
  NxTest.assert_equal([], plan['skipped'])
end

NxTest.test('D-131 plan: skrinka z NOVSEJ verzie sa preskoci a VYMENUJE (nikdy tichy drop)') do
  newer = d131_cfg([d131_item('F1', 'drawer_front')], {},
                   'config_schema' => D131CB::CONFIG_SCHEMA + 5)
  plan = D131PC.fronts_grain_plan([d131_entry('CAB-009', newer, :x)], 'width')
  NxTest.assert_equal([], plan['jobs'], 'do prestavby sa NEDOSTANE')
  NxTest.assert_equal(1, plan['skipped'].length)
  NxTest.assert_equal('CAB-009', plan['skipped'][0]['id'])
  NxTest.assert(plan['skipped'][0]['why'].to_s.include?('novšia'), 'dovod je v hlaske')
end

NxTest.test('D-131 plan: nerozlustene dvierka sa preskocia a VYMENUJU') do
  cfg = d131_cfg([{ 'id' => 'F1', 'type' => 'door' }])
  plan = D131PC.fronts_grain_plan([d131_entry('CAB-007', cfg, :x)], 'length')
  NxTest.assert_equal([], plan['jobs'])
  NxTest.assert_equal('CAB-007', plan['skipped'][0]['id'])
end

NxTest.test('D-131 plan: 0 ciel = ziadny job a count 0 (volajuci NEOTVORI operaciu)') do
  plan = D131PC.fronts_grain_plan([d131_entry('CAB-001', d131_cfg([d131_item('F1', 'none')]), :a)],
                                  'width')
  NxTest.assert_equal(0, plan['count'])
  NxTest.assert_equal([], plan['jobs'])
  NxTest.assert_equal([], plan['skipped'], 'skrinka bez ciel NIE JE preskocena chyba')
end

NxTest.test('D-131 plan: skrinka, ktora uz smer MA, do prestavby nejde (ziadny zbytocny rebuild)') do
  cfg = d131_cfg([d131_item('F1', 'drawer_front')],
                 'front:F1/panel' => { 'grain_direction' => 'width' })
  plan = D131PC.fronts_grain_plan([d131_entry('CAB-001', cfg, :a)], 'width')
  NxTest.assert_equal(1, plan['count'], 'celo sa do POCTU rata (stav je spravny)')
  NxTest.assert_equal([], plan['jobs'], 'ale prestavovat sa nema co')
end

# ---------------------------------------------------------------------------
# 5) SERVEROVE GUARDY AKCIE (zapisova cesta `MaterialsDialog`)
# ---------------------------------------------------------------------------
#
# KAZDA odmietavá vetva MUSI poslať `repush` — plny push okna je JEDINA cesta,
# ktorou sa v kliente odomkne tlacidlo. Bez neho by po odmietnutom kliku navzdy
# visel text „Prestavujem…" (review #365, P2).

def d131_call(model, data, sink, generation: 1)
  D131MD.fronts_grain_all(model, data, generation: generation,
                                       status: d131_status(sink), repush: d131_repush(sink))
end

NxTest.test('D-131 guard: stara generacia = obnova okna, ZIADNY zapis') do
  sink = d131_sink
  d131_call(D131FakeModel.new, { 'gen' => 3, 'grain' => 'width' }, sink, generation: 7)
  NxTest.assert_equal(1, sink[:repush], 'okno sa ma obnovit (a tlacidlo odomknut)')
  NxTest.assert(sink[:status][0][1], 'hlaska je chybova')
  NxTest.assert(sink[:status][0][0].include?('prepočítalo'), sink[:status].inspect)
end

NxTest.test('D-131 guard: rozpisana zmena v Inspectore zapis ZASTAVI (flush handshake)') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  sink = d131_sink
  d131_call(model, { 'gen' => 1, 'grain' => 'width', 'model_guid' => D131DK.key(model),
                     'flush_blocked' => true }, sink)
  NxTest.assert_equal(1, sink[:repush], 'aj odmietnutie odomkne tlacidlo')
  NxTest.assert(sink[:status][0][1], 'hlaska je chybova')
  NxTest.assert(sink[:status][0][0].include?('Inspektore') || sink[:status][0][0].include?('Inspectore'),
                sink[:status].inspect)
end

NxTest.test('D-131 guard: cudzi dokument = obnova okna, ZIADNY zapis') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  sink = d131_sink
  d131_call(model, { 'gen' => 1, 'grain' => 'width', 'model_guid' => 'CUDZI' }, sink)
  NxTest.assert_equal(1, sink[:repush])
  NxTest.assert(sink[:status][0][0].include?('prepol'), sink[:status].inspect)
end

NxTest.test('D-131 guard: PRAZDNY model_guid od klienta zapis ZASTAVI (prisny rezim)') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  sink = d131_sink
  d131_call(model, { 'gen' => 1, 'grain' => 'width' }, sink)
  NxTest.assert(sink[:status][0][1], 'zapis je ZASTAVENY (nie tolerantny rezim)')
  NxTest.assert_equal(1, sink[:repush])
end

NxTest.test('D-131 guard: neznamy smer sa ODMIETNE (ziadny fallback)') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  sink = d131_sink
  d131_call(model, { 'gen' => 2, 'grain' => 'diagonal', 'model_guid' => D131DK.key(model) },
            sink, generation: 2)
  NxTest.assert(sink[:status][0][1], 'hlaska je chybova')
  NxTest.assert(sink[:status][0][0].include?('Neznámy'), sink[:status].inspect)
  NxTest.assert_equal(1, sink[:repush], 'aj odmietnuty enum odomkne tlacidlo')
end

NxTest.test('D-131 guard: BEZ modelu sa nic nedeje, ale tlacidlo sa odomkne') do
  sink = d131_sink
  d131_call(nil, { 'gen' => 1, 'grain' => 'width' }, sink)
  NxTest.assert(sink[:status][0][1])
  NxTest.assert_equal(1, sink[:repush])
end

# ---------------------------------------------------------------------------
# 6) ZBER: TOP-LEVEL ZAKAZKA A FAIL-SAFE
# ---------------------------------------------------------------------------

D131_PC_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                        encoding: 'UTF-8')
D131_SCAN_SRC = D131_PC_SRC[/def front_grain_scan.*?\n      end\n/m].to_s

NxTest.test('D-131 zber: zakazka je TOP-LEVEL `model.entities` (ako `Bom.collect`)') do
  NxTest.assert(D131_SCAN_SRC.include?('model.entities.grep(Sketchup::ComponentInstance)'),
                'zber musi ist rovnakou cestou ako kusovnik')
  # `Ids.each_cabinet` hlada GLOBALNE cez `model.definitions` a nasiel by aj
  # korpus VNORENY v cudzom komponente — ten v zakazke nie je a prestavba by
  # ho zmenila vo VSETKYCH vyskytoch zdielanej definicie (Codex #365, P1).
  NxTest.refute(D131_SCAN_SRC.include?('all_cabinets') || D131_SCAN_SRC.include?('each_cabinet'),
                'globalny zber cez definicie sem NEPATRI')
end

NxTest.test('D-131 zber: zlyhanie vracia nil, NIE prazdny zoznam') do
  # Prazdny zoznam by klient precital ako „v zakazke nie su cela" a tlacidlo by
  # tvarilo, ze nie je co robit. nil = „stav nedostupny" (vzor `mat_payload`).
  broken = Object.new
  def broken.entities
    raise 'model je prec'
  end
  NxTest.assert_equal(nil, D131PC.front_grain_scan(broken))
  NxTest.assert_equal(nil, D131PC.front_grain_state(broken))
end

NxTest.test('D-131 zber: bez modelu je zoznam prazdny (nie chyba)') do
  NxTest.assert_equal([], D131PC.front_grain_scan(nil))
end

NxTest.test('D-131 zapis: ZAPISOVA cesta NEZIJE v jadre vystupov (brana 1b-3)') do
  # `production_core.rb` je CITACIA cesta: nesmie otvarat operaciu ani si
  # vyziadat dedup. Prestavba (`rebuild_many`) preto zije v `MaterialsDialog`
  # vedla „Nahradiť UNI…" — s VYCHODZIM dedupom, lebo `rebuild_in_operation`
  # vola `make_unique` (review #365, P2).
  NxTest.refute(D131_PC_SRC.include?('fronts_grain_apply'),
                'zapisova cast sa do jadra vystupov nesmie vratit')
  NxTest.assert(D131MD.respond_to?(:fronts_grain_all),
                'MaterialsDialog.fronts_grain_all musi byt PUBLIC (vola ju obal okna)')
  NxTest.assert(Noxun::Engine::StudioDialog.respond_to?(:do_fronts_grain_all),
                'StudioDialog.do_fronts_grain_all musi byt PUBLIC (relay z panel.rb)')
end

NxTest.test('D-131 guard: enum pusti LEN length/width/__inherit__') do
  NxTest.assert_equal(%w[length width], D131CB::GRAIN_OVERRIDES,
                      'hromadna cesta stoji na TOM ISTOM enume ako karta dielca')
  NxTest.assert_equal('__inherit__', D131PC::FRONT_GRAIN_INHERIT,
                      'sentinel dedenia je zhodny s `Panel.handle_set_part_grain`')
end

# ---------------------------------------------------------------------------
# 6) HLASKY
# ---------------------------------------------------------------------------

NxTest.test('D-131 hlaska: uspech menuje smer, pocty aj JEDEN krok Späť') do
  msg = D131PC.fronts_grain_done_msg('width', { 'count' => 12, 'cabinets' => 5, 'skipped' => [] })
  NxTest.assert(msg.include?('priečna') && msg.include?('12 čiel') && msg.include?('5 skrinkách'), msg)
  NxTest.assert(msg.include?('1 krok Späť'), msg)
end

NxTest.test('D-131 hlaska: jedno celo v jednej skrinke sa sklonuje spravne') do
  msg = D131PC.fronts_grain_done_msg('length', { 'count' => 1, 'cabinets' => 1, 'skipped' => [] })
  NxTest.assert(msg.include?('1 čelo v 1 skrinke'), msg)
end

NxTest.test('D-131 hlaska: preskocene skrinky su V HLASKE (nikdy tichy drop)') do
  msg = D131PC.fronts_grain_done_msg('length',
                                     { 'count' => 2, 'cabinets' => 1,
                                       'skipped' => [{ 'id' => 'CAB-009', 'why' => 'novšia verzia pluginu' }] })
  NxTest.assert(msg.include?('CAB-009'), msg)
end

NxTest.test('D-131 hlaska: prazdna zakazka to povie rovno') do
  msg = D131PC.fronts_grain_empty_msg({ 'skipped' => [] })
  NxTest.assert(msg.include?('nie sú žiadne čelá'), msg)
end
