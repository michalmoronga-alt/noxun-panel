# frozen_string_literal: true
# Testy M-C: PD hranova logika + Kompakt bez ABS + hustota per TYP.
#   Materials.density_for            — hustota z registra typov (UNI/iny = nil)
#   Materials.abs_default_suppression — kompakt/PD-postforming = :all
#   AbsRules.resolve_edges           — potlacene defaulty (rucne overridy nie)
#   Materials.validate_sheet_attrs / normalize_sheet / required_schema_for
#     — pd_edge_subtype: enum + typovy guard + SCHEMA 8
#   DemosFamily.verify_sheet         — mapping "Typ pracovnej dosky" (audit F3)
#   Validation.run                   — ORANGE "bez ABS" pri kompakt/postforming mlci
require_relative '../helper' unless defined?(NxTest)

MCM = Noxun::Engine::Materials
MCA = Noxun::Engine::AbsRules
MCV = Noxun::Engine::Validation
MCF = Noxun::Engine::DemosFamily

def mc_pd(over = {})
  { 'material_id' => 'PD_X', 'decor' => 'F800', 'type' => 'PD', 'thickness' => 38.0,
    'sheet_size' => [4100.0, 600.0] }.merge(over)
end

# ---------------------------------------------------------------------------
# hustota per TYP
# ---------------------------------------------------------------------------

NxTest.test('mc: density_for — register typov; UNI aj neznamy typ = nil') do
  NxTest.assert_close(680.0, MCM.density_for('type' => 'DTDL'))
  NxTest.assert_close(750.0, MCM.density_for('type' => 'mdf'), 0.01, 'case-insensitive')
  NxTest.assert_close(870.0, MCM.density_for('type' => 'HDF'))
  NxTest.assert_close(1350.0, MCM.density_for('type' => 'KOMPAKT'))
  NxTest.assert_close(680.0, MCM.density_for(mc_pd))
  NxTest.assert_equal(nil, MCM.density_for('type' => 'Preglejka'), 'iny typ = ziadna vymyslena vaha')
  NxTest.assert_equal(nil, MCM.density_for('type' => 'DTDL', 'uni' => true), 'UNI bez vahy')
  NxTest.assert_equal(nil, MCM.density_for(nil))
end

# ---------------------------------------------------------------------------
# potlacenie ABS defaultov
# ---------------------------------------------------------------------------

NxTest.test('mc: abs_default_suppression — kompakt a PD-postforming :all, ostatne nil') do
  NxTest.assert_equal(:all, MCM.abs_default_suppression('type' => 'KOMPAKT'))
  NxTest.assert_equal(:all, MCM.abs_default_suppression(mc_pd('pd_edge_subtype' => 'postforming')))
  NxTest.assert_equal(nil, MCM.abs_default_suppression(mc_pd('pd_edge_subtype' => 'abs')))
  NxTest.assert_equal(nil, MCM.abs_default_suppression(mc_pd), 'nezname data sa ticho nepotlacaju (audit B2)')
  NxTest.assert_equal(nil, MCM.abs_default_suppression('type' => 'DTDL'))
  NxTest.assert_equal(nil, MCM.abs_default_suppression(nil))
end

NxTest.test('mc: resolve_edges — kompakt/PD-postforming = ziadne defaulty; PD bez podtypu standard') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  ok, res = MCM.add_decor_batch(
    'batch_schema' => 3, 'decor' => 'F808', 'manufacturer' => 'Egger',
    'decor_name' => 'MC test', 'type' => 'DTDL', 'grain' => 'length', 'color' => [1, 2, 3],
    'sheet_variants' => [{ 'thickness' => 18.0, 'structure' => 'ST9' }],
    'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9' }]
  )
  raise res.inspect unless ok
  begin
    sheet18 = MCM.sheet(res['sheets'][0])
    # standard: free_panel dostane 1 pozdlznu pasku
    std = MCA.resolve_edges('free_panel', 'F808', 18.0, sheet: sheet18)
    NxTest.assert(std.values.any?, 'standardny default existuje (sanity)')
    # kompakt: nikdy nic
    komp = MCA.resolve_edges('free_panel', 'F808', 12.0,
                             sheet: sheet18.merge('type' => 'KOMPAKT'))
    NxTest.assert(komp.values.all?(&:nil?), 'kompakt bez defaultov')
    # PD postforming: nic (hrany hotove z vyroby + HPDB konce)
    pdp = MCA.resolve_edges('free_panel', 'F808', 38.0,
                            sheet: sheet18.merge('type' => 'PD', 'pd_edge_subtype' => 'postforming'))
    NxTest.assert(pdp.values.all?(&:nil?), 'PD postforming bez defaultov')
    # PD bez podtypu: standardna cesta (nezname sa nepotlaca). Hrubka dielca 18
    # — 38 by legitimne vypadla na sirke pasky (23 < 38+2), testujeme vetvu
    # potlacenia, nie sirkovy picker.
    pdn = MCA.resolve_edges('free_panel', 'F808', 18.0, sheet: sheet18.merge('type' => 'PD'))
    NxTest.assert(pdn.values.any?, 'PD bez podtypu drzi standardne defaulty')
  ensure
    (res['sheets'] || []).each { |id| MCM.delete_sheet(id) }
    (res['edges'] || []).each { |id| MCM.delete_edge(id) }
  end
end

# ---------------------------------------------------------------------------
# pd_edge_subtype: validacia + normalize + schema
# ---------------------------------------------------------------------------

NxTest.test('mc: validate_sheet_attrs — pd_edge_subtype len pre PD a len z enumu') do
  ok, = MCM.validate_sheet_attrs(mc_pd('pd_edge_subtype' => 'postforming'))
  NxTest.assert(ok)
  ok2, = MCM.validate_sheet_attrs(mc_pd('pd_edge_subtype' => 'abs'))
  NxTest.assert(ok2)
  ok3, = MCM.validate_sheet_attrs(mc_pd('pd_edge_subtype' => ''))
  NxTest.assert(ok3, 'prazdne = platne nezname')
  bad, msg = MCM.validate_sheet_attrs(mc_pd('pd_edge_subtype' => 'lamino'))
  NxTest.refute(bad)
  NxTest.assert(msg.include?('postforming alebo abs'), msg)
  bad2, msg2 = MCM.validate_sheet_attrs('decor' => 'X', 'type' => 'DTDL', 'thickness' => 18.0,
                                        'pd_edge_subtype' => 'postforming')
  NxTest.refute(bad2, 'pole na inom type sa odmieta (audit F5)')
  NxTest.assert(msg2.include?('pracovnej doske'), msg2)
end

NxTest.test('mc: normalize_sheet — pole prezije LEN pri PD; required_schema_for = 8') do
  rec = MCM.normalize_sheet(mc_pd('pd_edge_subtype' => 'postforming'))
  NxTest.assert_equal('postforming', rec['pd_edge_subtype'])
  rec2 = MCM.normalize_sheet(mc_pd('type' => 'DTDL', 'pd_edge_subtype' => 'postforming'))
  NxTest.refute(rec2.key?('pd_edge_subtype'), 'iny typ pole nezapise ani okruznou cestou')
  rec3 = MCM.normalize_sheet(mc_pd('pd_edge_subtype' => 'nezmysel'))
  NxTest.refute(rec3.key?('pd_edge_subtype'), 'mimo enumu sa nezapise')
  rec4 = MCM.normalize_sheet(mc_pd)
  NxTest.refute(rec4.key?('pd_edge_subtype'), 'chybajuce = bez kluca')
  NxTest.assert_equal(MCM::SCHEMA_PD_EDGE, MCM.required_schema_for([rec]), 'obsah pola = marker 8')
  NxTest.assert_equal(0, MCM.required_schema_for([rec4]), 'bez pola marker nestupa')
  NxTest.assert_equal(8, MCM::SCHEMA_CURRENT, 'SCHEMA_CURRENT bumpnuta s kodom')
end

# ---------------------------------------------------------------------------
# Demos mapping (audit F3)
# ---------------------------------------------------------------------------

NxTest.test('mc: verify_sheet — "Typ pracovnej dosky" -> pd_edge_subtype (Postforming/ine/chyba)') do
  url = 'https://www.demos-trade.sk/pracovna-doska-f800-st9-4100-600-38/'
  slug = Noxun::Engine::DemosSlugMatcher.slug_of(url)
  base = { 'ok' => true, 'price_vat' => 100.0, 'unit' => 'ks', 'image_url' => '' }
  params = { 'decor' => 'F800', 'structure' => 'ST9', 'thickness' => 38.0,
             'format' => [4100.0, 600.0], 'pd_type' => 'Postforming' }
  out = MCF.verify_sheet(base.merge('params' => params), params, slug, '514485', url, { 'kind' => 'sheet' })
  NxTest.assert_equal(nil, out['reason'], out.inspect)
  NxTest.assert_equal('PD', out['type'])
  NxTest.assert_equal('postforming', out['pd_edge_subtype'])
  p2 = params.merge('pd_type' => 'DTL')
  out2 = MCF.verify_sheet(base.merge('params' => p2), p2, slug, 'X', url, { 'kind' => 'sheet' })
  NxTest.assert_equal('abs', out2['pd_edge_subtype'], 'ina neprazdna hodnota = abs rovna hrana')
  p3 = params.merge('pd_type' => nil)
  out3 = MCF.verify_sheet(base.merge('params' => p3), p3, slug, 'X', url, { 'kind' => 'sheet' })
  NxTest.refute(out3.key?('pd_edge_subtype'), 'chybajuci parameter = bez pola (nedomysla sa)')
end

# ---------------------------------------------------------------------------
# semafor (audit F6)
# ---------------------------------------------------------------------------

NxTest.test('mc: semafor — "bez ABS" mlci pri kompakt/PD-postforming, NEmlci pri PD-abs ani mimo katalogu') do
  no_abs = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
  rec = { 'name' => 'Doska', 'part_key' => 'board/x', 'owner_id' => 'BRD-1', 'pid' => 1,
          'role' => 'free_panel', 'length' => 600.0, 'width' => 400.0, 'thickness' => 12.0,
          'quantity' => 1, 'material_id' => 'M1', 'edges' => no_abs }
  run = lambda do |sheet|
    MCV.run({ records: [rec], hardware_overrides: [], warnings: [] },
            sheets: sheet ? { 'M1' => sheet } : {})['items'].map { |i| i['category'] }
  end
  NxTest.refute(run.call('material_id' => 'M1', 'type' => 'KOMPAKT', 'thickness' => 12.0).include?('panel_abs'),
                'kompakt sa nelepi — ORANGE mlci')
  NxTest.refute(run.call('material_id' => 'M1', 'type' => 'PD', 'thickness' => 12.0,
                         'pd_edge_subtype' => 'postforming').include?('panel_abs'),
                'PD postforming — ORANGE mlci')
  NxTest.assert(run.call('material_id' => 'M1', 'type' => 'PD', 'thickness' => 12.0,
                         'pd_edge_subtype' => 'abs').include?('panel_abs'),
                'PD s ABS hranou sa kontroluje normalne')
  NxTest.assert(run.call('material_id' => 'M1', 'type' => 'DTDL', 'thickness' => 12.0).include?('panel_abs'),
                'bezna doska sa kontroluje')
  NxTest.assert(run.call(nil).include?('material'), 'chybajuci material = RED (potlacenie sa NEuplatni)')
end

NxTest.test('mc: semafor — ULOZENE abs_* build warnings mlcia pri nelepitelnom materiali (GH #118 P2)') do
  rec = { 'name' => 'Doska', 'part_key' => 'board/x', 'owner_id' => 'BRD-1', 'pid' => 1,
          'role' => 'free_panel', 'length' => 600.0, 'width' => 400.0, 'thickness' => 12.0,
          'quantity' => 1, 'material_id' => 'M1',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  warn = { 'code' => 'abs_no_structure', 'message' => 'Dielec bez pasky',
           'part_key' => 'board/x', 'owner_id' => 'BRD-1' }
  out = MCV.run({ records: [rec], hardware_overrides: [], warnings: [warn] },
                sheets: { 'M1' => { 'material_id' => 'M1', 'type' => 'KOMPAKT', 'thickness' => 12.0 } })
  NxTest.refute(out['items'].any? { |i| i['category'] == 'build' },
                'stary abs_ build warning na kompakte sa nezobrazuje')
  out2 = MCV.run({ records: [rec], hardware_overrides: [], warnings: [warn] },
                 sheets: { 'M1' => { 'material_id' => 'M1', 'type' => 'DTDL', 'thickness' => 12.0 } })
  NxTest.assert(out2['items'].any? { |i| i['category'] == 'build' },
                'na beznej doske warning ostava')
end

NxTest.test('d73: kompakt — format platne je identita variantu (920 a 650 su DVE dosky)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  NxTest.assert(MCM.format_in_identity?('KOMPAKT'), 'register flag')
  NxTest.assert(MCM.format_in_identity?('kompakt'), 'case-insensitive')
  item = { 'kind' => 'sheet', 'type' => 'KOMPAKT', 'thickness' => 12.0, 'structure' => 'ST9',
           'sheet_size' => [4100.0, 920.0], 'code' => '472102', 'price' => 785.59,
           'demos_url' => 'https://www.demos-trade.sk/kd-in-f206-st9-pietra-grigia-cierna-cj-cgs-4100-920-12/',
           'image_url' => '' }
  narrow = item.merge('sheet_size' => [4100.0, 650.0], 'code' => '472100',
                      'demos_url' => 'https://www.demos-trade.sk/kd-in-f206-st9-pietra-grigia-cierna-cj-cgs-4100-650-12/')
  created = []
  begin
    status, info = MCM.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F206', 'decor_name' => 'Pietra Grigia',
      'sheet_items' => [item, narrow], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status, info.inspect)
    created.concat(info['sheets'])
    NxTest.assert_equal(2, info['sheets'].size, 'dva formaty = dva varianty (Michalov smoke F206)')
    ids = info['sheets']
    NxTest.assert(ids.any? { |id| id.include?('4100X920') } && ids.any? { |id| id.include?('4100X650') },
                  "ID nesu format token: #{ids.inspect}")
    # rovnaky format druhykrat = skip (identita s formatom dedupuje spravne)
    status2, info2 = MCM.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F206', 'decor_name' => '',
      'sheet_items' => [item], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status2, info2.inspect)
    created.concat(info2['sheets'])
    NxTest.assert_equal(0, info2['sheets'].size)
    NxTest.assert_equal(1, Array(info2['skipped']).size)
    # kompakt bez formatu sa uz nezaklada (format = identita)
    status3, info3 = MCM.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F206', 'decor_name' => '',
      'sheet_items' => [item.merge('sheet_size' => nil, 'code' => '999999')], 'edge_items' => []
    )
    NxTest.assert_equal(:invalid, status3, info3.inspect)
    NxTest.assert(info3['detail'].to_s.include?('formát'), info3.inspect)
  ensure
    created.each { |id| MCM.delete_sheet(id) }
  end
end

NxTest.test('mc: ensure_edge_for_sheet — nelepitelny material pasku NEdotvara (GH #118 P2)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  # D-73: kompakt ma format v identite — batch variant ho nesie (sheet_size).
  ok, res = MCM.add_decor_batch(
    'batch_schema' => 3, 'decor' => 'K900', 'manufacturer' => 'Egger',
    'decor_name' => 'MC kompakt', 'type' => 'KOMPAKT', 'grain' => 'none', 'color' => [5, 5, 5],
    'sheet_variants' => [{ 'thickness' => 12.0, 'structure' => 'SM', 'sheet_size' => [4100.0, 650.0] }],
    'edge_variants' => []
  )
  raise res.inspect unless ok
  begin
    status, = MCM.ensure_edge_for_sheet(res['sheets'][0], client_schema: MCM::SCHEMA_CURRENT)
    NxTest.assert_equal(:abs_suppressed, status, 'kompakt = ziadna auto-paska')
  ensure
    (res['sheets'] || []).each { |id| MCM.delete_sheet(id) }
  end
end
