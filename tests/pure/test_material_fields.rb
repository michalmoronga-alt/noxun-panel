# frozen_string_literal: true
# Testy D-42 PR A: nove volitelne polia kod + dodavatel (merge-safe), cena
# rozlisuje nezadana vs 0, vyrobca group-level, duplicitny kod guard.
require_relative '../helper' unless defined?(NxTest)

FMAT = Noxun::Engine::Materials

# ---------------------------------------------------------------------------
# code + supplier — volitelne, trim, prazdne vynechat, merge-safe
# ---------------------------------------------------------------------------

NxTest.test('mat-fields: normalize_sheet uklada code/supplier len ked su zadane (trim)') do
  s = FMAT.normalize_sheet('material_id' => 'M1', 'decor' => 'X', 'type' => 'DTDL',
                           'thickness' => 18, 'code' => '  K009 PW 36 ', 'supplier' => ' Demos ')
  NxTest.assert_equal('K009 PW 36', s['code'])
  NxTest.assert_equal('Demos', s['supplier'])
  s2 = FMAT.normalize_sheet('material_id' => 'M2', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18)
  NxTest.refute(s2.key?('code'), 'chybajuci kod sa neuklada')
  NxTest.refute(s2.key?('supplier'), 'chybajuci dodavatel sa neuklada')
  s3 = FMAT.normalize_sheet('material_id' => 'M3', 'decor' => 'X', 'type' => 'DTDL',
                            'thickness' => 18, 'code' => '   ')
  NxTest.refute(s3.key?('code'), 'prazdny (whitespace) kod sa neuklada = vymazane')
end

NxTest.test('mat-fields: normalize_edge uklada code/supplier rovnako') do
  e = FMAT.normalize_edge('abs_id' => 'E1', 'decor' => 'X', 'thickness' => 1.0,
                          'code' => 'ABS-1', 'supplier' => 'Demos')
  NxTest.assert_equal('ABS-1', e['code'])
  NxTest.assert_equal('Demos', e['supplier'])
  NxTest.refute(FMAT.normalize_edge('abs_id' => 'E2', 'decor' => 'X', 'thickness' => 1.0).key?('code'))
end

NxTest.test('mat-fields: merge-safe — stary payload bez kluca kod nezmaze existujuci') do
  # simulacia handle_save merge: existing.merge(data) kde data nema code
  existing = { 'material_id' => 'M1', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18.0,
               'code' => 'PONECHAT', 'supplier' => 'Demos' }
  data = { 'material_id' => 'M1', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18.0, 'price_per_m2' => 5 }
  merged = FMAT.normalize_sheet(existing.merge(data))
  NxTest.assert_equal('PONECHAT', merged['code'], 'kod z existing prezije merge')
  NxTest.assert_equal('Demos', merged['supplier'])
end

# ---------------------------------------------------------------------------
# cena: nezadana (nil) vs 0
# ---------------------------------------------------------------------------

NxTest.test('mat-fields: normalize_price rozlisuje nezadana / 0 / necislo') do
  NxTest.assert_equal(nil, FMAT.normalize_price(nil), 'nil = nezadana')
  NxTest.assert_equal(nil, FMAT.normalize_price(''), 'prazdny string = nezadana')
  NxTest.assert_equal(nil, FMAT.normalize_price('   '))
  NxTest.assert_equal(0.0, FMAT.normalize_price('0'), '0 je ZADANA nula')
  NxTest.assert_equal(12.5, FMAT.normalize_price('12,5'), 'ciarka OK')
  NxTest.assert_equal(nil, FMAT.normalize_price('abc'), 'necislo -> nil (NIE ticha 0)')
end

NxTest.test('mat-fields: normalize_sheet/edge cena nezadana => kluc CHYBA (nie 0.0)') do
  s = FMAT.normalize_sheet('material_id' => 'M1', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18)
  NxTest.refute(s.key?('price_per_m2'), 'bez ceny sa kluc neuklada')
  s2 = FMAT.normalize_sheet('material_id' => 'M2', 'decor' => 'X', 'type' => 'DTDL', 'thickness' => 18, 'price_per_m2' => 0)
  NxTest.assert_equal(0.0, s2['price_per_m2'], 'explicitna 0 sa ULOZI')
  e = FMAT.normalize_edge('abs_id' => 'E1', 'decor' => 'X', 'thickness' => 1.0)
  NxTest.refute(e.key?('price_per_bm'))
end

NxTest.test('mat-fields: validate_price — prazdna OK, zaporna/necislo chyba') do
  NxTest.assert(FMAT.validate_price(nil)[0], 'nezadana je platna')
  NxTest.assert(FMAT.validate_price('')[0])
  NxTest.assert(FMAT.validate_price('0')[0])
  NxTest.assert(FMAT.validate_price('12,5')[0])
  NxTest.refute(FMAT.validate_price('-1')[0], 'zaporna')
  NxTest.refute(FMAT.validate_price('abc')[0], 'necislo')
end

NxTest.test('mat-fields: validate_text_fields — prilis dlhy kod odmietnuty') do
  NxTest.assert(FMAT.validate_text_fields('code' => 'K009', 'supplier' => 'Demos')[0])
  NxTest.refute(FMAT.validate_text_fields('code' => ('x' * 200))[0], 'dlhy kod')
end

# ---------------------------------------------------------------------------
# vyrobca group-level + duplicitny kod
# ---------------------------------------------------------------------------

NxTest.test('mat-fields: set_decor_manufacturer meni celu skupinu + family') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  FMAT.upsert_sheet('material_id' => 'MG18', 'decor' => 'ManGrp', 'type' => 'DTDL', 'thickness' => 18)
  FMAT.upsert_sheet('material_id' => 'MG36', 'decor' => 'ManGrp', 'type' => 'DTDL', 'thickness' => 36)
  ok, count = FMAT.set_decor_manufacturer('ManGrp', 'Egger')
  NxTest.assert(ok)
  NxTest.assert_equal(2, count)
  NxTest.assert_equal('Egger', FMAT.sheet('MG18')['manufacturer'])
  NxTest.assert_equal('Egger ManGrp', FMAT.sheet('MG18')['family'], 'family sa aktualizuje')
  NxTest.assert_equal('Egger', FMAT.sheet('MG36')['manufacturer'])
  FMAT.delete_sheet('MG18'); FMAT.delete_sheet('MG36')
end

NxTest.test('mat-fields: code_conflicts — rovnaky kod+dodavatel, iny dodavatel nie, self out') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  FMAT.upsert_sheet('material_id' => 'CC1', 'decor' => 'CodeA', 'type' => 'DTDL', 'thickness' => 18,
                    'code' => 'SHARED', 'supplier' => 'Demos')
  FMAT.upsert_sheet('material_id' => 'CC2', 'decor' => 'CodeB', 'type' => 'DTDL', 'thickness' => 18,
                    'code' => 'shared', 'supplier' => 'DEMOS') # case-insensitive zhoda
  NxTest.assert_equal(['CC1', 'CC2'].sort, FMAT.code_conflicts('SHARED', 'Demos', 'sheet').sort)
  NxTest.assert_equal(['CC2'], FMAT.code_conflicts('SHARED', 'Demos', 'sheet', 'CC1'), 'self_id vynechany')
  NxTest.assert_equal([], FMAT.code_conflicts('SHARED', 'InyDodavatel', 'sheet'), 'iny dodavatel = ziadna kolizia')
  NxTest.assert_equal([], FMAT.code_conflicts('', 'Demos', 'sheet'), 'prazdny kod = ziadna kolizia')
  NxTest.assert_equal([], FMAT.code_conflicts('SHARED', 'Demos', 'edge'), 'edge druh nehľada v doskach')
  FMAT.delete_sheet('CC1'); FMAT.delete_sheet('CC2')
end

NxTest.test('mat-fields: batch NEuklada cenu (nezadana), farbu ano') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = FMAT.add_decor_batch('decor' => 'NoPriceBatch', 'thicknesses' => '18', 'abs_tokens' => '22/1')
  NxTest.assert(ok)
  NxTest.refute(FMAT.sheet(res['sheets'][0]).key?('price_per_m2'), 'batch doska bez ceny')
  NxTest.refute(FMAT.edge(res['edges'][0]).key?('price_per_bm'), 'batch ABS bez ceny')
  res['sheets'].each { |id| FMAT.delete_sheet(id) }
  res['edges'].each { |id| FMAT.delete_edge(id) }
end
