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

# ---------------------------------------------------------------------------
# D-42 PR C: patch protokol inline buniek (audit BLOCKER 1)
# ---------------------------------------------------------------------------

NxTest.test('mat-patch: ok — whitelist pole sa zapise, identita a ostatne polia nedotknute') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  FMAT.upsert_sheet('material_id' => 'PT_18', 'decor' => 'Patch Test', 'type' => 'DTDL',
                    'thickness' => 18, 'grain' => 'width', 'code' => 'STARY')
  begin
    rev = FMAT.record_rev(FMAT.sheet('PT_18'))
    status, = FMAT.patch_record('sheet', 'PT_18', { 'code' => 'NOVY', 'thickness' => 99, 'decor' => 'Hack' }, row_rev: rev)
    NxTest.assert_equal(:ok, status)
    back = FMAT.sheet('PT_18')
    NxTest.assert_equal('NOVY', back['code'])
    NxTest.assert_close(18.0, back['thickness'], 0.01, 'identita sa patchom NIKDY nemeni')
    NxTest.assert_equal('Patch Test', back['decor'])
    NxTest.assert_equal('width', back['grain'], 'nepatchovane pole prezilo')
  ensure
    FMAT.delete_sheet('PT_18')
  end
end

NxTest.test('mat-patch: conflict pri starom row_rev; bez row_rev prejde (stary klient)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  FMAT.upsert_edge('abs_id' => 'PT_E10', 'decor' => 'Patch Test E', 'thickness' => 1.0, 'width' => 22)
  begin
    stary_rev = FMAT.record_rev(FMAT.edge('PT_E10'))
    FMAT.patch_record('edge', 'PT_E10', { 'supplier' => 'Demos' }, row_rev: stary_rev)
    status, = FMAT.patch_record('edge', 'PT_E10', { 'code' => 'X' }, row_rev: stary_rev)
    NxTest.assert_equal(:conflict, status, 'riadok sa medzitym zmenil')
    NxTest.assert_equal(nil, FMAT.edge('PT_E10')['code'], 'konfliktny patch sa NEzapisal')
    status2, = FMAT.patch_record('edge', 'PT_E10', { 'code' => 'X' })
    NxTest.assert_equal(:ok, status2, 'bez row_rev guard preskoceny (spatna kompatibilita)')
  ensure
    FMAT.delete_edge('PT_E10')
  end
end

NxTest.test('mat-patch: invalid cena / prazdny patch / neznamy zaznam / vymazanie hodnoty') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  FMAT.upsert_sheet('material_id' => 'PT2_18', 'decor' => 'Patch Test 2', 'type' => 'DTDL',
                    'thickness' => 18, 'code' => 'MAZAT', 'price_per_m2' => 5)
  begin
    NxTest.assert_equal(:invalid, FMAT.patch_record('sheet', 'PT2_18', { 'price_per_m2' => 'abc' })[0])
    NxTest.assert_equal(:invalid, FMAT.patch_record('sheet', 'PT2_18', { 'thickness' => 20 })[0], 'len identita = ziadne editovatelne pole')
    NxTest.assert_equal(:not_found, FMAT.patch_record('sheet', 'NEEXISTUJE', { 'code' => 'X' })[0])
    NxTest.assert_equal(:ok, FMAT.patch_record('sheet', 'PT2_18', { 'code' => '', 'price_per_m2' => '' })[0])
    back = FMAT.sheet('PT2_18')
    NxTest.refute(back.key?('code'), 'prazdna hodnota pole VYMAZE')
    NxTest.refute(back.key?('price_per_m2'), 'prazdna cena = nezadana (kluc prec)')
  ensure
    FMAT.delete_sheet('PT2_18')
  end
end

NxTest.test('mat-patch: duplicitny kod vyzaduje potvrdenie (allow_duplicate_code)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  FMAT.upsert_sheet('material_id' => 'PD1_18', 'decor' => 'PatchDup A', 'type' => 'DTDL',
                    'thickness' => 18, 'code' => 'SPOLOCNY', 'supplier' => 'Demos')
  FMAT.upsert_sheet('material_id' => 'PD2_18', 'decor' => 'PatchDup B', 'type' => 'DTDL',
                    'thickness' => 18, 'supplier' => 'Demos')
  begin
    status, hits = FMAT.patch_record('sheet', 'PD2_18', { 'code' => 'spolocny' })
    NxTest.assert_equal(:code_conflict, status)
    NxTest.assert_equal(['PD1_18'], hits)
    NxTest.assert_equal(nil, FMAT.sheet('PD2_18')['code'], 'bez potvrdenia sa nezapisal')
    status2, = FMAT.patch_record('sheet', 'PD2_18', { 'code' => 'spolocny' }, allow_duplicate_code: true)
    NxTest.assert_equal(:ok, status2)
    NxTest.assert_equal('spolocny', FMAT.sheet('PD2_18')['code'])
  ensure
    FMAT.delete_sheet('PD1_18')
    FMAT.delete_sheet('PD2_18')
  end
end

# ---------------------------------------------------------------------------
# D-42 PR C: strukturovana davka (audit BLOCKER 5 — typ per variant)
# ---------------------------------------------------------------------------

NxTest.test('mat-batch-c: sheet_variants s typom per variant (PD 38 vedla DTDL) + edge_variants') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = FMAT.add_decor_batch(
    'decor' => 'ChipBatch', 'type' => 'DTDL',
    'sheet_variants' => [{ 'thickness' => '18' }, { 'type' => 'PD', 'thickness' => '38' }],
    'edge_variants' => [{ 'width' => '22', 'thickness' => '1' }, { 'width' => '43', 'thickness' => '2' }]
  )
  begin
    NxTest.assert(ok, "batch mal prejst: #{res.inspect}")
    NxTest.assert_equal(2, res['sheets'].size)
    NxTest.assert_equal(2, res['edges'].size)
    types = res['sheets'].map { |id| FMAT.sheet(id)['type'] }.sort
    NxTest.assert_equal(%w[DTDL PD], types, 'typ per variant v JEDNEJ davke')
    NxTest.assert_equal(22.0, FMAT.edge(res['edges'][0])['width'])
  ensure
    bt = res.is_a?(Hash) ? res : {}
    (bt['sheets'] || []).each { |id| FMAT.delete_sheet(id) }
    (bt['edges'] || []).each { |id| FMAT.delete_edge(id) }
  end
end

NxTest.test('mat-batch-c: mix cipov a textu sa zluci, dedup cez identitu, zla hodnota rusi davku') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = FMAT.add_decor_batch(
    'decor' => 'ChipMix', 'type' => 'DTDL', 'thicknesses' => '18, 36',
    'sheet_variants' => [{ 'thickness' => 18 }],   # duplicita s textom -> 1 zaznam
    'edge_variants' => [{ 'width' => 22, 'thickness' => 1 }]
  )
  begin
    NxTest.assert(ok)
    NxTest.assert_equal(2, res['sheets'].size, '18 z cipu aj textu = jeden variant')
    ok2, err2 = FMAT.add_decor_batch('decor' => 'ChipBad',
                                     'edge_variants' => [{ 'width' => 5, 'thickness' => 1 }])
    NxTest.refute(ok2, 'sirka mimo rozsahu rusi CELU davku')
    NxTest.assert(err2.include?('10–200'), err2.to_s)
    ok3, = FMAT.add_decor_batch('decor' => 'ChipBad2',
                                'sheet_variants' => [{ 'thickness' => 0 }])
    NxTest.refute(ok3, 'nulova hrubka variantu rusi davku')
  ensure
    bt = res.is_a?(Hash) ? res : {}
    (bt['sheets'] || []).each { |id| FMAT.delete_sheet(id) }
    (bt['edges'] || []).each { |id| FMAT.delete_edge(id) }
  end
end

# ---------------------------------------------------------------------------
# D-42 PR B: dekory pouzite v aktivnom modeli (pas "Pouzite v projekte")
# ---------------------------------------------------------------------------

NxTest.test('mat-fields: model_decor_usage cita part/board snapshoty, BEZ sablon a predvolieb') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  st = Noxun::Engine::Store
  FMAT.upsert_sheet('material_id' => 'MDU_18', 'decor' => 'MDU Dekor', 'type' => 'DTDL', 'thickness' => 18)
  begin
    p1 = NxTest::FakeInstance.new(11)
    st.write(p1, { kind: 'part', id: 'CAB-001-A', config: { 'material_id' => 'MDU_18' } })
    p2 = NxTest::FakeInstance.new(12)
    st.write(p2, { kind: 'part', id: 'CAB-001-B', config: { 'material_id' => 'MDU_18' } })
    board = NxTest::FakeInstance.new(13)
    # Codex GH #75: doska s quantity 3 = 3 kusy (nie 1 entita)
    st.write(board, { kind: 'board', id: 'BRD-001', config: { 'material_id' => 'MDU_18', 'quantity' => 3 } })
    cudzi = NxTest::FakeInstance.new(14)
    st.write(cudzi, { kind: 'part', id: 'CAB-001-C', config: { 'material_id' => 'MIMO_KATALOGU' } })
    cab = NxTest::FakeInstance.new(15)
    st.write(cab, { kind: 'cabinet', cabinet_id: 'CAB-001', config: { 'material_id' => 'MDU_18' } })
    model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([p1, p2, board, cudzi, cab])])
    # sablona s tym istym materialom NESMIE zvysit pocet (nie je "pouzitie v projekte")
    Noxun::Engine::TemplateStore.upsert('mdu-test-tpl', 'material_id' => 'MDU_18')
    usage = FMAT.model_decor_usage(model)
    NxTest.assert_equal(5, usage['MDU Dekor'], '2 dielce + doska s quantity 3 (korpus/cudzi material sa neratahju)')
    NxTest.assert_equal(0, usage['MIMO_KATALOGU'], 'material mimo katalogu nema dekor (default 0)')
    NxTest.refute(usage.keys.include?('MIMO_KATALOGU'), 'a nevytvara kluc v mape')
    NxTest.assert_equal({}, FMAT.model_decor_usage(nil), 'bez modelu prazdna mapa')
  ensure
    Noxun::Engine::TemplateStore.delete('mdu-test-tpl')
    FMAT.delete_sheet('MDU_18')
  end
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
