# frozen_string_literal: true
# CENY-M2 — ZAKAZKA ZLATEHO TESTU B (sklo aj doska bez formatu). Jedna definicia
# pre generator odtlacku (`generate_pre.rb`) aj test (`tests/pure/test_ceny_m2_golden.rb`).
#
# Obsah = fixtura sondy package CENY-M2 (`sonda_m2.rb`, S22): sklo SK4 (typ SKLO)
# 0,9 m² à 41,50 €/m², sklo bez ceny NOP, DTD bez formatu NOF so zdrojovym
# duplakom D36 (od C14 / R1a ide podla plochy: 1,05 + 0,24 × 2 = 1,53 m²), UNI
# (ostava odhadom platni), H18 (Demos, stara cena), H25 (rucna doska s formatom),
# ABS Demos aj rucna.
require 'json'

module NxCenyM2Golden
  E = Noxun::Engine
  NOW = Time.utc(2026, 9, 30, 12)
  DIR = __dir__

  SHEETS = {
    'H18' => { 'decor' => 'H1180', 'type' => 'DTDL', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0],
               'price_per_m2' => 24.9, 'demos_url' => 'https://www.demos-trade.sk/p/h1180',
               'price_checked_at' => (NOW - (40 * 86_400)).iso8601 },
    'H25' => { 'decor' => 'H1180', 'type' => 'DTDL', 'thickness' => 25.0, 'sheet_size' => [2800.0, 2070.0],
               'price_per_m2' => 179.9 / 5.796 },
    'SK4' => { 'decor' => 'Číre', 'type' => 'SKLO', 'thickness' => 4.0, 'price_per_m2' => 41.5 },
    'NOF' => { 'decor' => 'K001', 'type' => 'DTDL', 'thickness' => 18.0, 'price_per_m2' => 31.2 },
    'NOP' => { 'decor' => 'Zrkadlo', 'type' => 'SKLO', 'thickness' => 4.0 },
    'UNI' => { 'decor' => 'UNI', 'type' => 'DTDL', 'thickness' => 18.0, 'uni' => true },
    'D36' => { 'decor' => 'K001 dup', 'type' => 'DTDL', 'thickness' => 36.0, 'source_material_id' => 'NOF',
               'source_multiplier' => 2 }
  }.freeze

  EDGES = {
    'E23' => { 'decor' => 'H1180', 'width' => 23.0, 'thickness' => 1.0, 'price_per_bm' => 0.62,
               'demos_url' => 'https://www.demos-trade.sk/p/e', 'price_checked_at' => (NOW - (2 * 86_400)).iso8601 },
    'E43' => { 'decor' => 'H1180', 'width' => 43.0, 'thickness' => 0.8, 'price_per_bm' => 0.39 }
  }.freeze

  EDGING = [{ 'abs_id' => 'E23', 'bm' => 40.0 }, { 'abs_id' => 'E43', 'bm' => 8.0 }].freeze

  module_function

  def row(mid, len, wid, qty, extra = {})
    { 'material_id' => mid, 'length' => len, 'width' => wid, 'quantity' => qty }.merge(extra)
  end

  def rows
    [
      row('H18', 2000.0, 560.0, 8), row('H25', 800.0, 500.0, 2),
      row('SK4', 600.0, 500.0, 3),  # 0,9 m² skla
      row('NOF', 700.0, 500.0, 3),  # 1,05 m² DTD bez formatu
      row('D36', 600.0, 400.0, 1, 'material_source' => { 'material_id' => 'NOF', 'multiplier' => 2 }),
      row('NOP', 400.0, 300.0, 1),  # sklo bez ceny aj formatu
      row('UNI', 700.0, 500.0, 2)
    ]
  end

  def estimate
    E::SheetEstimate.estimate(rows, sheet_sizes: SHEETS.transform_values { |s| s['sheet_size'] },
                                    uni_ids: { 'UNI' => true })
  end

  def payload(state = {})
    E::Budget.compute({ rows: rows, edging: EDGING }, state, E::SupplierSettings.seed_supplier,
                      sheets: SHEETS, edges: EDGES, sheet_estimate: estimate, now: NOW)
  end

  def snapshot(state = {})
    p = payload(state)
    { 'payload' => p,
      'budget_xlsx' => E::BudgetXlsx.sheet(p, project: 'GoldenB', now: NOW),
      'cp_price_sheet' => E::CpXlsx.price_sheet(p['cp_preview'], project: 'GoldenB', now: NOW) }
  end

  def roundtrip(obj)
    JSON.parse(JSON.generate(obj))
  end

  def load_pre
    JSON.parse(File.read(File.join(DIR, 'pre_glass.json'), encoding: 'UTF-8'))
  end
end
