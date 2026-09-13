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
#   M2 — `fronts_grain_plan` da kazdej skrinke vlastnu operaciu (jobs po jednom
#        volani rebuildu) -> „plan: VSETKY skrinky su v JEDNOM zozname jobs"
#   M3 — neznama hodnota `grain` prejde na server -> „guard: neznamy smer sa ODMIETNE"
#   M4 — `__inherit__` nechá prazdny zaznam v `part_overrides` -> „inherit: prazdny
#        zaznam ZANIKA"
require_relative '../helper' unless defined?(NxTest)

D131PC = Noxun::Engine::ProductionCore
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

NxTest.test('D-131 rozsah: zasuvkove celo je `panel`') do
  keys, unresolved = D131PC.front_grain_keys([d131_item('F1', 'drawer_front')])
  NxTest.assert_equal(['front:F1/panel'], keys)
  NxTest.refute(unresolved, 'resolved polozka nie je nerozlustena')
end

NxTest.test('D-131 rozsah: vyklop AJ sklop maju kanonicky kluc `flap`') do
  lift, = D131PC.front_grain_keys([d131_item('F1', 'lift')])
  fall, = D131PC.front_grain_keys([d131_item('F1', 'fall')])
  NxTest.assert_equal(['front:F1/flap'], lift)
  NxTest.assert_equal(['front:F1/flap'], fall, 'sklop ma TEN ISTY kluc ako vyklop (KOV-A1)')
end

NxTest.test('D-131 rozsah: blenda je `blind`') do
  keys, = D131PC.front_grain_keys([d131_item('F1', 'blind')])
  NxTest.assert_equal(['front:F1/blind'], keys)
end

NxTest.test('D-131 rozsah: dvierka daju kluc KAZDEMU kridlu (1 / 2 / 3)') do
  one, = D131PC.front_grain_keys([d131_item('F1', 'door', 1)])
  two, = D131PC.front_grain_keys([d131_item('F1', 'door', 2)])
  three, = D131PC.front_grain_keys([d131_item('F1', 'door', 3)])
  NxTest.assert_equal(['front:F1/wing:single'], one)
  NxTest.assert_equal(['front:F1/wing:left', 'front:F1/wing:right'], two)
  NxTest.assert_equal(['front:F1/wing:p1', 'front:F1/wing:p2', 'front:F1/wing:p3'], three)
end

NxTest.test('D-131 rozsah: „Bez čela" (none) dielec nema — nie je co otacat') do
  keys, unresolved = D131PC.front_grain_keys([d131_item('F1', 'none')])
  NxTest.assert_equal([], keys)
  NxTest.refute(unresolved, 'prazdna nika NIE JE chyba')
end

NxTest.test('D-131 rozsah: viac riadkov ciel v jednej skrinke = vsetky kluce') do
  keys, = D131PC.front_grain_keys([d131_item('F1', 'drawer_front'),
                                   d131_item('F2', 'none'),
                                   d131_item('F3', 'door', 2)])
  NxTest.assert_equal(['front:F1/panel', 'front:F3/wing:left', 'front:F3/wing:right'], keys)
end

NxTest.test('D-131 fail-visible: dvierka BEZ `wings_n` = nerozlustene (pocet sa NEHADA)') do
  keys, unresolved = D131PC.front_grain_keys([{ 'id' => 'F1', 'type' => 'door' }])
  NxTest.assert_equal([], keys, 'z nerozlustenej skrinky nejde ZIADEN kluc')
  NxTest.assert(unresolved, 'skrinka sa ma preskocit a vymenovat')
end

NxTest.test('D-131 rozsah: chybajuce `front_items` = skrinka bez ciel') do
  keys, unresolved = D131PC.front_grain_keys(nil)
  NxTest.assert_equal([], keys)
  NxTest.refute(unresolved)
end

# ---------------------------------------------------------------------------
# 2) ZAPIS OVERRIDU
# ---------------------------------------------------------------------------

NxTest.test('D-131 zapis: `width` PREPISE existujuci override') do
  params = { 'part_overrides' => { 'front:F1/panel' => { 'grain_direction' => 'length' } } }
  n = D131PC.front_grain_write!(params, ['front:F1/panel'], 'width')
  NxTest.assert_equal(1, n)
  NxTest.assert_equal('width', params['part_overrides']['front:F1/panel']['grain_direction'])
end

NxTest.test('D-131 zapis: celo, ktore uz ma pozadovany smer, sa NEta (0 zmien)') do
  params = { 'part_overrides' => { 'front:F1/panel' => { 'grain_direction' => 'width' } } }
  NxTest.assert_equal(0, D131PC.front_grain_write!(params, ['front:F1/panel'], 'width'))
end

NxTest.test('D-131 inherit: prazdny zaznam ZANIKA (kluc aj cely zaznam)') do
  params = { 'part_overrides' => { 'front:F1/panel' => { 'grain_direction' => 'width' } } }
  n = D131PC.front_grain_write!(params, ['front:F1/panel'], D131PC::FRONT_GRAIN_INHERIT)
  NxTest.assert_equal(1, n)
  NxTest.assert_equal({}, params['part_overrides'], 'prazdny zaznam sa ma odstranit')
end

NxTest.test('D-131 inherit: zaznam s ABS hranami PREZIJE (maze sa LEN grain_direction)') do
  rec = { 'grain_direction' => 'width', 'edges' => { 'L1' => 'ABS_X' } }
  params = { 'part_overrides' => { 'front:F1/panel' => rec } }
  D131PC.front_grain_write!(params, ['front:F1/panel'], D131PC::FRONT_GRAIN_INHERIT)
  NxTest.assert_equal({ 'edges' => { 'L1' => 'ABS_X' } },
                      params['part_overrides']['front:F1/panel'],
                      'ABS override dielca sa hromadnou kresbou NESMIE stratit')
end

NxTest.test('D-131 zapis: korpusove overridy a zvysok configu ostanu BAJTOVO nezmenene') do
  other = { 'cabinet/side:left' => { 'edges' => { 'W1' => 'ABS_A' } },
            'zone:Z1/shelf:1' => { 'material_id' => 'DUB18' } }
  before = Marshal.dump(other)
  params = { 'part_overrides' => other.merge('front:F1/panel' => {}) }
  D131PC.front_grain_write!(params, ['front:F1/panel'], 'length')
  after = other.select { |k, _| k != 'front:F1/panel' }
  NxTest.assert_equal(before, Marshal.dump(after), 'cudzie overridy sa nesmu ani dotknut')
  NxTest.assert_equal('length', params['part_overrides']['front:F1/panel']['grain_direction'])
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
  NxTest.assert_equal(0, D131PC.front_grain_summary([ent])['count'],
                      'tlacidlo nesmie slubit viac, nez akcia spravi')
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
# 5) SERVEROVE GUARDY AKCIE
# ---------------------------------------------------------------------------

NxTest.test('D-131 guard: stara generacia = obnova okna, ZIADNY zapis') do
  sink = d131_sink
  D131PC.fronts_grain_all(D131FakeModel.new, { 'gen' => 3, 'grain' => 'width' },
                          generation: 7, status: d131_status(sink), repush: d131_repush(sink))
  NxTest.assert_equal(1, sink[:repush], 'okno sa ma obnovit')
  NxTest.assert(sink[:status][0][1], 'hlaska je chybova')
  NxTest.assert(sink[:status][0][0].include?('prepočítalo'), sink[:status].inspect)
end

NxTest.test('D-131 guard: cudzi dokument = obnova okna, ZIADNY zapis') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  sink = d131_sink
  D131PC.fronts_grain_all(model, { 'gen' => 1, 'grain' => 'width', 'model_guid' => 'CUDZI' },
                          generation: 1, status: d131_status(sink), repush: d131_repush(sink))
  NxTest.assert_equal(1, sink[:repush])
  NxTest.assert(sink[:status][0][0].include?('prepol'), sink[:status].inspect)
end

NxTest.test('D-131 guard: PRAZDNY model_guid od klienta zapis ZASTAVI (prisny rezim)') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  sink = d131_sink
  D131PC.fronts_grain_all(model, { 'gen' => 1, 'grain' => 'width' },
                          generation: 1, status: d131_status(sink), repush: d131_repush(sink))
  NxTest.assert(sink[:status][0][1], 'zapis je ZASTAVENY (nie tolerantny rezim)')
end

NxTest.test('D-131 guard: neznamy smer sa ODMIETNE (ziadny fallback, ziadna obnova)') do
  D131DK.reset! if D131DK.respond_to?(:reset!)
  model = D131FakeModel.new
  guid = D131DK.key(model)
  sink = d131_sink
  D131PC.fronts_grain_all(model, { 'gen' => 2, 'grain' => 'diagonal', 'model_guid' => guid },
                          generation: 2, status: d131_status(sink), repush: d131_repush(sink))
  NxTest.assert_equal(0, sink[:repush], 'nie je co obnovovat — stav okna plati')
  NxTest.assert(sink[:status][0][1], 'hlaska je chybova')
  NxTest.assert(sink[:status][0][0].include?('Neznámy'), sink[:status].inspect)
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
  NxTest.assert(msg.include?('priečna') && msg.include?('12 čiel') && msg.include?('5 skriniek'), msg)
  NxTest.assert(msg.include?('1 krok Späť'), msg)
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
