# frozen_string_literal: true
# CENY-M2 — ZLATY TEST B: zakazka so SKLOM a DOSKOU bez formatu (C12 + C14).
#
# PRECO: M2 meni cenu materialu bez platneho formatu — od rozhodnutia Michala
# C14 (30.9.2026, Q2 „áno, aj bežná doska", vetva R1a) skla AJ beznej dosky:
# uz sa nepocitaju ako fiktivna platna 2800 × 2070, ale podla skutocnej plochy
# dielcov bez odpadu. Odtlacok `tests/fixtures/ceny_m2_golden/pre_glass.json`
# vznikol RAZ nad mainom po CENY-M1b PRED prvou zmenou kodu M2 (samostatny
# commit „golden pred M2"). Test porovna cerstvy vypocet s nim a rozdiel
# dovoli LEN na VYMENOVANYCH cestach s PRESNYMI cislami z package (S22, vetva
# R1a): sklo 0,90 × 41,50 = 37,35 € (predtym 240,53), DTD bez formatu NOF
# s duplakom 1,53 × 31,20 = 47,74 € (predtym 180,84), medzisucet Materialu
# 889,91 → 553,63, raw 2406,14 → 2069,86, SPOLU 2407 → 2070 (zaokruhlenie
# 0,14); porez 7 a montaz 40,6 sa nemenia; sklo aj NOF v ponuke vypadnu zo
# samostatnych riadkov. Kazda ina zmena odtlacku je NALEZ, nie sum.
require_relative '../helper' unless defined?(NxTest)
require_relative '../fixtures/ceny_m2_golden/fixture'

module NxCenyM2GoldenTest
  module_function

  def diff(a, b, path, out)
    if a.is_a?(Hash) && b.is_a?(Hash)
      (a.keys | b.keys).each { |k| diff(a[k], b[k], path + [k.to_s], out) }
    elsif a.is_a?(Array) && b.is_a?(Array) && a.length == b.length
      a.each_index { |i| diff(a[i], b[i], path + [i.to_s], out) }
    elsif a != b
      out << [path.join('.'), a, b]
    end
    out
  end

  # Presne ocakavane zmeny: cesta => [pred, po]. Poradie riadkov Materialu:
  # 0 H18 · 1 H25 · 2 NOF · 3 NOP · 4 SK4 · 5 UNI; sekcia 7 = zaokruhlenie.
  AREA_NOTE = 'formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)'
  FALLBACK = 'formát 2800×2070 mm · formát platne nie je v katalógu — odhad podľa 2800×2070'
  EXPECT = {
    'payload.sections.0.rows.4.mj' => %w[PLATŇA M2],
    'payload.sections.0.rows.4.mnozstvo' => [1, 0.9],
    'payload.sections.0.rows.4.cena_mj' => [240.53, 41.5],
    'payload.sections.0.rows.4.spolu' => [240.53, 37.35],
    'payload.sections.0.rows.4.spolu_auto' => [240.53, 37.35],
    'payload.sections.0.rows.4.poznamka' => ["0,9 m² · #{FALLBACK}", AREA_NOTE],
    'payload.sections.0.rows.4.estimated' => [true, false],
    'payload.sections.0.rows.4.qty_basis' => [nil, 'area'],
    'payload.sections.0.rows.4.estimate_qty' => [nil, 1],
    'payload.sections.0.rows.3.mj' => %w[PLATŇA M2],
    'payload.sections.0.rows.3.mnozstvo' => [1, 0.12],
    'payload.sections.0.rows.3.poznamka' => ["0,12 m² · #{FALLBACK}", AREA_NOTE],
    'payload.sections.0.rows.3.estimated' => [true, false],
    'payload.sections.0.rows.3.qty_basis' => [nil, 'area'],
    'payload.sections.0.rows.3.estimate_qty' => [nil, 1],
    # R1a (C14): DTD bez formatu NOF so zdrojovym duplakom (1,05 + 0,24 × 2 = 1,53 m²).
    'payload.sections.0.rows.2.mj' => %w[PLATŇA M2],
    'payload.sections.0.rows.2.mnozstvo' => [1, 1.53],
    'payload.sections.0.rows.2.cena_mj' => [180.84, 31.2],
    'payload.sections.0.rows.2.spolu' => [180.84, 47.74],
    'payload.sections.0.rows.2.spolu_auto' => [180.84, 47.74],
    'payload.sections.0.rows.2.poznamka' => ["1,53 m² · #{FALLBACK} · vrátane 1 ks duplákov (0,48 m²)",
                                             "#{AREA_NOTE} · vrátane 1 ks duplákov (0,48 m²)"],
    'payload.sections.0.rows.2.estimated' => [true, false],
    'payload.sections.0.rows.2.qty_basis' => [nil, 'area'],
    'payload.sections.0.rows.2.estimate_qty' => [nil, 1],
    'payload.sections.0.subtotal' => [889.91, 553.63],
    'payload.sections.7.rows.0.cena_mj' => [0.86, 0.14],
    'payload.sections.7.rows.0.spolu' => [0.86, 0.14],
    'payload.sections.7.rows.0.spolu_auto' => [0.86, 0.14],
    'payload.sections.7.subtotal' => [0.86, 0.14],
    'payload.totals.raw_total' => [2406.14, 2069.86],
    'payload.totals.rounding' => [0.86, 0.14],
    'payload.totals.total' => [2407.0, 2070.0],
    'payload.totals.total_novat' => [1956.91, 1682.93],
    'payload.totals.subtotals.materials' => [889.91, 553.63],
    'payload.totals.subtotals.rounding' => [0.86, 0.14],
    'payload.cp_preview.total' => [2407.0, 2070.0],
    'payload.cp_preview.budget_total' => [2407.0, 2070.0],
    'payload.cp_preview.assembly' => [348.09, 432.46],
    'payload.cp_preview.separate_count' => [4, 2],
    'budget_xlsx.rows.5.3.v' => %w[PLATŇA M2],
    'budget_xlsx.rows.5.4.v' => [1.0, 1.53],
    'budget_xlsx.rows.5.5.v' => [180.84, 31.2],
    'budget_xlsx.rows.5.6.v' => [180.84, 47.74],
    'budget_xlsx.rows.6.3.v' => %w[PLATŇA M2],
    'budget_xlsx.rows.6.4.v' => [1.0, 0.12],
    'budget_xlsx.rows.7.3.v' => %w[PLATŇA M2],
    'budget_xlsx.rows.7.4.v' => [1.0, 0.9],
    'budget_xlsx.rows.7.5.v' => [240.53, 41.5],
    'budget_xlsx.rows.7.6.v' => [240.53, 37.35],
    'budget_xlsx.rows.9.6.v' => [889.91, 553.63],
    'budget_xlsx.rows.31.5.v' => [0.86, 0.14],
    'budget_xlsx.rows.31.6.v' => [0.86, 0.14],
    'budget_xlsx.rows.33.6.v' => [2407.0, 2070.0]
  }.freeze

  # Cesty, ktore sa menia ako CELOK a overuju sa nizsie zvlast: blok `stale`,
  # aditivne kluce riadkov (stav rucnej ceny, ikona odkazu), preusporiadanie
  # kandidatov ponuky (sklo a NOF klesnu pod prah), riadky ponuky a jej harok
  # XLSX, nazov polozky XLSX (nesie poznamku R4).
  STRUCTURAL = [
    /\Apayload\.stale(\.|\z)/,
    /\Apayload\.sections\.[01]\.rows\.\d+\.(product_link|demos_link|price_check)(\.|\z)/,
    /\Apayload\.cp_preview\.candidates\.[123]\.(source_key|label|amount|state|suggested)\z/,
    /\Apayload\.cp_preview\.rows\z/,
    /\Acp_price_sheet\.rows\z/,
    /\Abudget_xlsx\.rows\.[567]\.1\.v\z/
  ].freeze
end

NxTest.test('CENY-M2 golden B: sklo a DTD bez formatu (R1a) — zmena LEN na vymenovanych cestach s presnymi cislami (S22)') do
  g = NxCenyM2Golden
  t = NxCenyM2GoldenTest
  pre = g.load_pre
  now = g.roundtrip(g.snapshot)
  seen = {}
  t.diff(pre, now, [], []).each do |path, a, b|
    next if t::STRUCTURAL.any? { |re| re.match?(path) }
    exp = t::EXPECT[path]
    NxTest.assert(exp, "neocakavana zmena odtlacku: #{path} #{a.inspect} -> #{b.inspect}")
    next unless exp
    NxTest.assert_equal(exp, [a, b], path)
    seen[path] = true
  end
  NxTest.assert_equal(t::EXPECT.keys.sort, seen.keys.sort, 'vsetky ocakavane zmeny nastali')
  mats = now['payload']['sections'][0]['rows']
  NxTest.assert_equal([%w[H18 H25 NOF NOP SK4 UNI]], [mats.map { |r| r['material_id'] }], 'poradie riadkov (indexy EXPECT)')
  NxTest.assert_equal(['PLATŇA', 1, nil], mats[5].values_at('mj', 'mnozstvo', 'qty_basis'), 'UNI ostava odhadom platni')
  svc = now['payload']['sections'].find { |s| s['key'] == 'services' }['rows']
  NxTest.assert_equal([7, 40.6], [svc.find { |r| r['key'] == 'service:porez' }['mnozstvo'],
                                  svc.find { |r| r['key'] == 'service:montaz' }['mnozstvo']], 'porez a montaz bez zmeny')
  xl = now['budget_xlsx']['rows']
  NxTest.assert(xl[7][1]['v'].start_with?('Číre SKLO 4 mm · ' + t::AREA_NOTE), 'XLSX: nazov skla nesie poznamku R4')
  NxTest.assert(xl[6][1]['v'].start_with?('Zrkadlo SKLO 4 mm · ' + t::AREA_NOTE), 'XLSX: nazov zrkadla nesie poznamku R4')
  NxTest.assert(xl[5][1]['v'].start_with?('K001 DTDL 18 mm · ' + t::AREA_NOTE), 'XLSX: nazov dosky nesie „(bez odpadu)"')
  cp = now['payload']['cp_preview']
  sk = cp['candidates'].find { |x| x['source_key'] == 'material:SK4' }
  NxTest.assert_equal([37.35, 'zostava', false], sk.values_at('amount', 'state', 'suggested'), 'sklo v ponuke pod prahom')
  nof = cp['candidates'].find { |x| x['source_key'] == 'material:NOF' }
  NxTest.assert_equal([47.74, 'zostava', false], nof.values_at('amount', 'state', 'suggested'), 'NOF v ponuke pod prahom')
  NxTest.assert_equal(%w[material:H18 material:H25],
                      cp['rows'].select { |r| r['kind'] == 'item' }.map { |r| r['source_key'] }, 'samostatne riadky ponuky')
  NxTest.assert_equal(432.46, cp['rows'].find { |r| r['kind'] == 'assembly' }['cena'], 'zostava prevzala sklo aj NOF')
  counts = now['payload']['stale']['counts']
  NxTest.assert_equal([1, 5, 1, 0, 5, 5, 6],
                      counts.values_at('stale', 'manual', 'fresh', 'manual_hardware', 'manual_materials', 'manual_pending', 'attention'),
                      'stale: H18 Demos stara, 5 rucnych (UNI a duplak mimo scanu)')
  NxTest.assert_equal(%w[H18 E43 H25 NOF NOP SK4], now['payload']['stale']['items'].map { |i| i['id'] }, 'poradie zoznamu')
end
