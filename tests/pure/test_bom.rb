# frozen_string_literal: true
# V0.5 A: Bom.compute — kusovnik/supisy z vyrobnych snapshotov (bez SketchUpu).
# Fixtures krmia compute() zaznamami priamo (collect je tenky SketchUp zberac).
require_relative '../helper' unless defined?(NxTest)

module NxBomFix
  module_function

  def rec(owner, name, len, wid, th, mat, edges = {}, qty = 1, grain = 'length')
    full = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.merge(edges)
    { 'name' => name, 'part_key' => "cabinet/#{name.downcase.tr(' ', '_')}",
      'owner_id' => owner, 'length' => len.to_f, 'width' => wid.to_f,
      'thickness' => th.to_f, 'quantity' => qty, 'material_id' => mat,
      'grain_direction' => grain, 'edges' => full }
  end

  def hw(owner, type, qty, params = {}, rule = 'r1', source = 'rule', variant = nil)
    { 'owner_id' => owner, 'generic_type' => type, 'quantity' => qty,
      'params' => params, 'rule_id' => rule, 'source' => source,
      'variant_id' => variant, 'owner_part_key' => nil }
  end
end

NxTest.test('bom: zrkadlove dielce rovnakych parametrov sa zluia, kde je strukturovane') do
  f = NxBomFix
  # 2 skrinky, kazda 2 boky rovnakych parametrov + 1 dno ineho rozmeru
  recs = [
    f.rec('CAB-001', 'Bok lavy',  720, 510, 18, 'K009', { 'L1' => 'ABS1' }),
    f.rec('CAB-001', 'Bok pravy', 720, 510, 18, 'K009', { 'L1' => 'ABS1' }),
    f.rec('CAB-002', 'Bok lavy',  720, 510, 18, 'K009', { 'L1' => 'ABS1' }),
    f.rec('CAB-002', 'Bok pravy', 720, 510, 18, 'K009', { 'L1' => 'ABS1' }),
    f.rec('CAB-001', 'Dno', 564, 510, 18, 'K009')
  ]
  out = Noxun::Engine::Bom.compute(records: recs, hardware: [], warnings: [], cabinets: 2, boards: 0)
  NxTest.assert_equal(2, out[:rows].length)
  boky = out[:rows].find { |r| r['quantity'] == 4 }
  NxTest.assert(!boky.nil?, 'zlucene boky qty 4')
  NxTest.assert_equal(%w[Bok\ lavy Bok\ pravy], boky['names'].sort)
  kde = boky['kde'].sort_by { |k| k['owner_id'] }
  NxTest.assert_equal([{ 'owner_id' => 'CAB-001', 'quantity' => 2 },
                       { 'owner_id' => 'CAB-002', 'quantity' => 2 }], kde)
  # V0.5 B: klik-select adresy — 1 ref na kazdy zdrojovy zaznam
  NxTest.assert_equal(4, boky['refs'].length)
  NxTest.assert(boky['refs'].all? { |r| r.key?('pid') && r.key?('owner_id') }, 'refs nesu pid+owner')
end

NxTest.test('bom: rozdielne hrany alebo hrubka NEzluia (vyrobne parametre v kluci)') do
  f = NxBomFix
  recs = [
    f.rec('CAB-001', 'Polica', 564, 500, 18, 'K009', { 'L1' => 'ABS1' }),
    f.rec('CAB-001', 'Polica', 564, 500, 18, 'K009', { 'L1' => 'ABS2' }), # ina ABS
    f.rec('CAB-001', 'Polica', 564, 500, 19, 'K009', { 'L1' => 'ABS1' })  # ina hrubka (celo 19)
  ]
  out = Noxun::Engine::Bom.compute(records: recs, hardware: [], warnings: [], cabinets: 1, boards: 0)
  NxTest.assert_equal(3, out[:rows].length)
end

NxTest.test('bom: float drift v ramci 0.1 mm sa zluci (kluc v desatinach mm)') do
  f = NxBomFix
  recs = [
    f.rec('CAB-001', 'Dno', 564.0, 510.0, 18.0, 'K009'),
    f.rec('CAB-002', 'Dno', 564.0004, 509.9996, 18.0, 'K009')
  ]
  out = Noxun::Engine::Bom.compute(records: recs, hardware: [], warnings: [], cabinets: 2, boards: 0)
  NxTest.assert_equal(1, out[:rows].length)
  NxTest.assert_equal(2, out[:rows].first['quantity'])
end

NxTest.test('bom: m2 a bm sa scitavaju zo VSETKYCH zdrojovych dielcov') do
  f = NxBomFix
  recs = [
    # doska 1000x500, qty 2 -> 1.0 m2; L1+L2 ABS1 -> 2*1.0m*2ks = 4.0 bm
    f.rec('BRD-001', 'Krycia doska', 1000, 500, 18, 'K009',
          { 'L1' => 'ABS1', 'L2' => 'ABS1' }, 2),
    # dielec 600x400 qty 1 -> 0.24 m2; W1 ABS1 0.4 bm; iny material W1000
    f.rec('CAB-001', 'Chrbat vypln', 600, 400, 18, 'W1000', { 'W1' => 'ABS1' })
  ]
  out = Noxun::Engine::Bom.compute(records: recs, hardware: [], warnings: [], cabinets: 1, boards: 1)
  k009 = out[:sheets].find { |s| s['material_id'] == 'K009' }
  w1000 = out[:sheets].find { |s| s['material_id'] == 'W1000' }
  NxTest.assert_close(1.0, k009['m2'])
  NxTest.assert_equal(2, k009['quantity'])
  NxTest.assert_close(0.24, w1000['m2'])
  abs1 = out[:edging].find { |e| e['abs_id'] == 'ABS1' }
  NxTest.assert_close(4.4, abs1['bm']) # 2 hrany x 1.0 m x 2 ks + 0.4
  NxTest.assert_equal(5, abs1['edges']) # 2 hrany x 2 ks + 1
  NxTest.assert_close(1.24, out[:summary]['m2_total'])
  NxTest.assert_close(4.4, out[:summary]['bm_total'])
end

NxTest.test('bom: kovanie sa deli podla generic_type + params (Codex B2), breakdown drzi zdroj') do
  f = NxBomFix
  hw = [
    f.hw('CAB-001', 'leg', 4, { 'height' => 100.0 }),
    f.hw('CAB-002', 'leg', 6, { 'height' => 100.0 }, 'nohy-zakladne', 'manual'),
    f.hw('CAB-003', 'leg', 4, { 'height' => 150.0 }),                 # ina vyska = iny riadok
    f.hw('CAB-001', 'slide', 2, { 'nominal_length' => 450.0 }),
    f.hw('CAB-002', 'slide', 2, { 'nominal_length' => 500.0 })        # ina NL = iny riadok
  ]
  out = Noxun::Engine::Bom.compute(records: [], hardware: hw, warnings: [], cabinets: 3, boards: 0)
  NxTest.assert_equal(4, out[:hardware].length)
  legs100 = out[:hardware].find { |g| g['generic_type'] == 'leg' && g['params']['height'] == 100.0 }
  NxTest.assert_equal(10, legs100['quantity'])
  manual = legs100['breakdown'].find { |b| b['source'] == 'manual' }
  NxTest.assert_equal('CAB-002', manual['owner_id'])
  NxTest.assert_equal(6, manual['quantity'])
  NxTest.assert_equal(18, out[:summary]['hardware_quantity'])
end

NxTest.test('bom: warnings prechadzaju ulozene s owner_id, summary pocty sedia') do
  f = NxBomFix
  recs = [f.rec('CAB-001', 'Dno', 564, 510, 18, 'K009', {}, 1),
          f.rec('BRD-001', 'Doska', 800, 600, 18, 'K009', {}, 3)]
  warns = [{ 'code' => 'part_skipped_degenerate', 'message' => 'test', 'owner_id' => 'CAB-001' }]
  out = Noxun::Engine::Bom.compute(records: recs, hardware: [], warnings: warns, cabinets: 1, boards: 1)
  NxTest.assert_equal(1, out[:warnings].length)
  NxTest.assert_equal('CAB-001', out[:warnings].first['owner_id'])
  s = out[:summary]
  NxTest.assert_equal(1, s['cabinets'])
  NxTest.assert_equal(1, s['boards'])
  NxTest.assert_equal(2, s['records'])
  NxTest.assert_equal(2, s['rows'])
  NxTest.assert_equal(4, s['quantity']) # 1 + 3 ks
end
