# frozen_string_literal: true
# Testy D-44: rychle pickery (navrhy vyrobcu/typu), format platne pri NOVYCH
# variantoch batchu "Novy dekor" (batch_schema 2) a guard prazdneho vyrobcu.
#
# Kontext: batch doteraz format platne nezadaval a normalize_sheet dosadil
# default 2800x2070 — odhad platni aj semafor potom tvarili, ze format je
# overeny (Codex P2 pri seede). Teraz: format ide rovno z davky, chybajuci sa
# NEUKLADA (ostava fallback s priznakom v odhade) a nic sa neinterpretuje ticho.
# Vsetko headless (APPDATA sandbox).
require_relative '../helper' unless defined?(NxTest)

# 2A-4b: seedy su nativne SCHEMA 2 — tento subor overuje DUAL-MODE (legacy)
# spravanie, preto si ako prvy krok instaluje predcutoverovy legacy katalog
# (registrovany setup test — testy bezia sekvencne v poradi registracie).
NxTest.test('d44 setup: legacy SCHEMA 1 katalog (dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_legacy_catalog!, 'legacy katalog sa nenainstaloval')
  NxTest.assert_equal(1, Noxun::Engine::Materials.catalog_schema, 'sandbox ma byt SCHEMA 1')
end

D44MAT = Noxun::Engine::Materials

def d44_cleanup(result)
  return unless result.is_a?(Hash)
  (result['sheets'] || []).each { |id| D44MAT.delete_sheet(id) }
  (result['edges'] || []).each { |id| D44MAT.delete_edge(id) }
end

# Skratka: davka schema 2 s jednym dekorom (vlastne varianty v opts).
def d44_batch(decor, variants, extra = {})
  D44MAT.add_decor_batch(
    { 'batch_schema' => 2, 'decor' => decor, 'sheet_variants' => variants }.merge(extra)
  )
end

NxTest.test('D-44: format platne z davky sa ulozi, bez formatu sa kluc NEUKLADA') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = d44_batch('D44 Format', [
                        { 'type' => 'DTDL', 'thickness' => 18, 'sheet_size' => [2800, 2050] },
                        { 'type' => 'PD', 'thickness' => 38 }
                      ])
  NxTest.assert(ok, "davka mala prejst: #{res.inspect}")
  NxTest.assert_equal(2, res['sheets'].size)
  dtdl = D44MAT.sheets.find { |s| s['decor'] == 'D44 Format' && s['type'] == 'DTDL' }
  pd = D44MAT.sheets.find { |s| s['decor'] == 'D44 Format' && s['type'] == 'PD' }
  NxTest.assert_equal([2800.0, 2050.0], dtdl['sheet_size'])
  # audit B2: PD bez formatu NESMIE dostat ticho default 2800x2070
  NxTest.refute(pd.key?('sheet_size'), "PD ma mat kluc sheet_size prec: #{pd.inspect}")
  d44_cleanup(res)
end

NxTest.test('D-44: zmiesana davka (1 platny + 1 chybny format) NEZAPISE nic') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  before = D44MAT.catalog_revision
  ok, err = d44_batch('D44 Mixed', [
                        { 'type' => 'DTDL', 'thickness' => 18, 'sheet_size' => [2800, 2070] },
                        { 'type' => 'DTDL', 'thickness' => 36, 'sheet_size' => [2800, 0] }
                      ])
  NxTest.refute(ok, 'chybny format rusi CELU davku')
  NxTest.assert(err.include?('Formát platne'), err.to_s)
  NxTest.assert_equal(before, D44MAT.catalog_revision, 'ziadny zapis pri chybe')
  NxTest.assert_equal(nil, D44MAT.find_sheet_variant('D44 Mixed', 'DTDL', 18.0), 'ani prvy variant')
end

NxTest.test('D-44: hranice rozsahu formatu 499/500/5000/5001 (zhoda s formularom)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.refute(d44_batch('D44 Rng A', [{ 'thickness' => 18, 'sheet_size' => [499, 2070] }])[0], '499 pod rozsahom')
  NxTest.refute(d44_batch('D44 Rng B', [{ 'thickness' => 18, 'sheet_size' => [2800, 5001] }])[0], '5001 nad rozsahom')
  ok_lo, lo = d44_batch('D44 Rng C', [{ 'thickness' => 18, 'sheet_size' => [500, 5000] }])
  NxTest.assert(ok_lo, "hranice vratane: #{lo.inspect}")
  NxTest.assert_equal([500.0, 5000.0], D44MAT.sheet(lo['sheets'][0])['sheet_size'])
  # ta ista konstanta strazi aj formular jednotliveho materialu
  NxTest.refute(D44MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 18,
                                            'sheet_size' => [499, 2070])[0], 'formular: 499 pod rozsahom')
  NxTest.assert(D44MAT.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 18,
                                            'sheet_size' => [500, 5000])[0], 'formular: hranice vratane')
  NxTest.assert_equal(500.0, D44MAT::SHEET_SIZE_RANGE.first)
  NxTest.assert_equal(5000.0, D44MAT::SHEET_SIZE_RANGE.last)
  d44_cleanup(lo)
end

NxTest.test('D-44: Infinity/NaN vo formate = chyba (ziadny tichy fallback)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  before = D44MAT.catalog_revision
  NxTest.refute(d44_batch('D44 Inf', [{ 'thickness' => 18, 'sheet_size' => [Float::INFINITY, 2070] }])[0], 'Infinity')
  NxTest.refute(d44_batch('D44 Nan', [{ 'thickness' => 18, 'sheet_size' => [2800, Float::NAN] }])[0], 'NaN')
  NxTest.refute(d44_batch('D44 Str', [{ 'thickness' => 18, 'sheet_size' => ['2800abc', 2070] }])[0], 'necislo')
  NxTest.refute(d44_batch('D44 One', [{ 'thickness' => 18, 'sheet_size' => [2800] }])[0], 'polovicny par')
  NxTest.assert_equal(before, D44MAT.catalog_revision, 'ziadny z pokusov nezapisal')
end

NxTest.test('D-44: nehashova polozka variantov = chyba davky (legacy ju preskoci)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, err = d44_batch('D44 Junk', ['18', { 'thickness' => 18 }])
  NxTest.refute(ok, 'schema 2: poskodena polozka rusi davku')
  NxTest.assert(err.include?('Poškodená'), err.to_s)
  ok2, err2 = D44MAT.add_decor_batch('batch_schema' => 2, 'decor' => 'D44 JunkAbs',
                                     'edge_variants' => [42, { 'width' => 22, 'thickness' => 1 }])
  NxTest.refute(ok2, 'schema 2: poskodena ABS polozka rusi davku')
  NxTest.assert(err2.include?('Poškodená'), err2.to_s)
  # LEGACY (bez batch_schema) sa sprava po starom — ticho preskoci
  ok3, res3 = D44MAT.add_decor_batch('decor' => 'D44 Junk Legacy',
                                     'sheet_variants' => ['18', { 'thickness' => 18 }])
  NxTest.assert(ok3, "legacy klient nesmie dostat chybu: #{res3.inspect}")
  NxTest.assert_equal(1, res3['sheets'].size)
  d44_cleanup(res3)
end

NxTest.test('D-44: legacy payload (bez batch_schema) ignoruje sheet_size a NEPADA') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = D44MAT.add_decor_batch(
    'decor' => 'D44 Legacy', 'thicknesses' => '18',
    'sheet_variants' => [{ 'type' => 'PD', 'thickness' => 38, 'sheet_size' => [9999, 1] }]
  )
  NxTest.assert(ok, "legacy davka mala prejst bez chyby: #{res.inspect}")
  NxTest.assert_equal(2, res['sheets'].size)
  pd = D44MAT.find_sheet_variant('D44 Legacy', 'PD', 38.0)
  # legacy vetva format NEPOZNA — nepreberie ho ani ked ho payload nesie
  # (a nedosadi ziadny default; audit B2 plati pre obe vetvy)
  NxTest.refute(pd.key?('sheet_size'), "legacy format ignoruje: #{pd.inspect}")
  d44_cleanup(res)
end

NxTest.test('D-44: dva varianty rovnakeho typ+hrubka (aj s roznym formatom) = chyba') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  before = D44MAT.catalog_revision
  ok, err = d44_batch('D44 Dup', [
                        { 'type' => 'PD', 'thickness' => 38, 'sheet_size' => [4100, 600] },
                        { 'type' => 'PD', 'thickness' => 38, 'sheet_size' => [4100, 900] }
                      ])
  NxTest.refute(ok, 'identita variantu ostava dekor+typ+hrubka — dve sirky PD su V0.6')
  NxTest.assert(err.include?('dvakrát'), err.to_s)
  NxTest.assert_equal(before, D44MAT.catalog_revision, 'ziadny zapis')
end

NxTest.test('D-44: konflikt textoveho pola a cipu (rovnaky typ+hrubka) = chyba') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, err = d44_batch('D44 TextChip', [{ 'thickness' => 18, 'sheet_size' => [2800, 2050] }],
                      'thicknesses' => '18')
  NxTest.refute(ok, 'ziadne ticha vyhra prveho zaznamu')
  NxTest.assert(err.include?('dvakrát'), err.to_s)
  # dva rovnake zapisy z TEXTOVEHO pola ostavaju tichym dedupom (nesu ziadny format)
  ok2, res2 = d44_batch('D44 TextText', [], 'thicknesses' => '18, 18')
  NxTest.assert(ok2, "textovy dedup ostava: #{res2.inspect}")
  NxTest.assert_equal(1, res2['sheets'].size)
  d44_cleanup(res2)
end

NxTest.test('D-44: case variacie typu su TEN ISTY variant (dtdl vs DTDL)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, err = d44_batch('D44 Case', [
                        { 'type' => 'DTDL', 'thickness' => 18, 'sheet_size' => [2800, 2070] },
                        { 'type' => 'dtdl', 'thickness' => 18 }
                      ])
  NxTest.refute(ok, 'identita typu je case-insensitive — v schema 2 je to duplicita')
  NxTest.assert(err.include?('dvakrát'), err.to_s)
  # legacy: ta ista dvojica sa ticho zdedupuje (dnesne spravanie, prvy vyhrava)
  ok2, res2 = D44MAT.add_decor_batch('decor' => 'D44 Case L', 'sheet_variants' => [
                                       { 'type' => 'DTDL', 'thickness' => 18 },
                                       { 'type' => 'dtdl', 'thickness' => 18 }
                                     ])
  NxTest.assert(ok2)
  NxTest.assert_equal(1, res2['sheets'].size, 'legacy dedup ostava')
  d44_cleanup(res2)
end

NxTest.test('D-44: neznamy typ s formatom prejde (typ NIE JE enum)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = d44_batch('D44 Novy Typ', [{ 'type' => 'kompakt', 'thickness' => 12,
                                         'sheet_size' => [4100, 1300] }])
  NxTest.assert(ok, "vlastny typ ma prejst: #{res.inspect}")
  rec = D44MAT.sheet(res['sheets'][0])
  NxTest.assert_equal('kompakt', rec['type'])
  NxTest.assert_equal([4100.0, 1300.0], rec['sheet_size'])
  d44_cleanup(res)
end

NxTest.test('D-44: prazdny vyrobca bez flagu sa ODMIETNE, s flagom zmaze skupinu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = d44_batch('D44 Man', [{ 'thickness' => 18 }], 'manufacturer' => 'Egger')
  NxTest.assert(ok)
  bad_ok, bad_err = D44MAT.set_decor_manufacturer('D44 Man', '')
  NxTest.refute(bad_ok, 'prazdna hodnota nesmie ticho zmazat vyrobcu skupine')
  NxTest.assert(bad_err.include?('Zmazať výrobcu'), bad_err.to_s)
  NxTest.assert_equal('Egger', D44MAT.sheet(res['sheets'][0])['manufacturer'], 'vyrobca ostal')
  set_ok, = D44MAT.set_decor_manufacturer('D44 Man', 'Kronospan')
  NxTest.assert(set_ok)
  NxTest.assert_equal('Kronospan', D44MAT.sheet(res['sheets'][0])['manufacturer'])
  clr_ok, = D44MAT.set_decor_manufacturer('D44 Man', '', clear: true)
  NxTest.assert(clr_ok, 's explicitnym flagom vymazanie prejde')
  NxTest.assert_equal('', D44MAT.sheet(res['sheets'][0])['manufacturer'])
  d44_cleanup(res)
end

NxTest.test('D-44: navrhy pre naseptavace — trim, ci-dedup, stabilne poradie') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  vals = ['  Egger ', 'egger', '', nil, 'Kronospan', 'kastamonu', 'Egger']
  NxTest.assert_equal(%w[Egger kastamonu Kronospan], D44MAT.string_suggestions(vals),
                      'prvy tvar vyhrava, poradie abecedne case-insensitive')
  NxTest.assert_equal(D44MAT.string_suggestions(vals.reverse.map(&:itself)).sort,
                      D44MAT.string_suggestions(vals).sort, 'poradie vstupu nemeni obsah')
  # katalogove navrhy: vyrobcovia zo seedu + seed typy vzdy v ponuke
  mans = D44MAT.manufacturer_suggestions
  NxTest.assert(mans.include?('Egger') && mans.include?('Kronospan'), mans.inspect)
  NxTest.refute(mans.include?(''), 'prazdne von')
  types = D44MAT.type_suggestions
  %w[DTDL PD MDF HDF].each { |t| NxTest.assert(types.include?(t), "typ #{t} chyba: #{types.inspect}") }
  NxTest.assert_equal(types.uniq { |t| t.downcase }.size, types.size, 'ziadne case duplicity')
end

NxTest.test('D-44: navrh formatu podla typu — DTDL/MDF/HDF ano, PD vedome prazdne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal([2800.0, 2070.0], D44MAT::TYPE_FORMAT_HINTS['DTDL'])
  NxTest.assert_equal([2800.0, 2070.0], D44MAT::TYPE_FORMAT_HINTS['MDF'])
  NxTest.assert_equal([2800.0, 2070.0], D44MAT::TYPE_FORMAT_HINTS['HDF'])
  NxTest.assert_equal(nil, D44MAT::TYPE_FORMAT_HINTS['PD'], 'PD sirok je vela — vedome zadanie')
  NxTest.assert_equal(nil, D44MAT::TYPE_FORMAT_HINTS['kompakt'], 'neznamy typ = bez navrhu')
end
