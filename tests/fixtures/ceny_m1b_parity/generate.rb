# frozen_string_literal: true
# CENY-M1b (review #427) — generator fixtury parity prepoctu cien formulara
# „Overiť cenu ručne" (klient) so SERVEROM.
#
# Ocakavane hodnoty pocitaju VYHRADNE serverove funkcie:
#   platna -> €/m²: `Materials.manual_price_value(..., 'plate', ...)` (D3 centy
#                  + `plate_to_m2`) + `Materials.display_m2` (co ukaze bunka),
#   €/m² -> platna: `Budget.price_per_plate` (co ukaze Rozpocet).
# JS sada `tests/js/test_ceny_m1_manual.js` musi nad tou istou fixturou sediet
# na 100 %; Ruby sada `tests/pure/test_ceny_m1_manual.rb` overi, ze fixtura
# zodpoveda aktualnemu serveru (aby sa nerozisla).
#
# Spusta sa RUCNE (test generator NEVOLA):
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/ceny_m1b_parity/generate.rb
require_relative '../../helper'
require 'json'

module CenyM1bParity
  FORMATS = [[1000.0, 1000.0], [2000.0, 1000.0], [1000.0, 800.0], [2000.0, 800.0],
             [2800.0, 2070.0], [4100.0, 635.0], [4100.0, 640.0], [4100.0, 920.0],
             [3050.0, 1300.0], [2440.0, 1220.0]].freeze
  EXTRA = %w[1,005 2,675 31,005 179,90 0,125 10,015 2,01 57,33 199,99 123,455 4,995 1,015
             0,005 0,015 100,005 31,04 1000,00].freeze

  module_function

  def inputs
    all = (0..500).map { |c| format('%d,%02d', c / 100, c % 100) }
    all += (0..25_000).step(97).map { |c| format('%d,%02d', c / 100, c % 100) }
    (all + EXTRA).uniq
  end

  def money(v)
    format('%.2f', v).tr('.', ',')
  end

  # [plate->m2 text, m2->plate text] zo serverovych funkcii.
  def expected(text, fmt)
    m = Noxun::Engine::Materials
    rec = { 'material_id' => 'PARITY', 'sheet_size' => fmt }
    amount = m.normalize_price(text)
    _, value, = m.manual_price_value(rec, 'plate', text, amount)
    plate = Noxun::Engine::Budget.price_per_plate(amount, nil, fmt)
    [money(m.display_m2(value)), money(plate)]
  end

  def rows
    FORMATS.each_with_index.flat_map do |fmt, fi|
      inputs.map { |t| [fi, t] + expected(t, fmt) }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  out = { '_popis' => 'CENY-M1b: parita prepoctu formulara „Overiť cenu ručne" so serverom. ' \
                      'rows = [index formatu, vstup, €/m² z ceny za platnu (display_m2), ' \
                      'cena platne z €/m² (Budget.price_per_plate)]. Generator: generate.rb.',
          'formats' => CenyM1bParity::FORMATS, 'rows' => CenyM1bParity.rows }
  File.write(File.join(__dir__, 'cases.json'), JSON.generate(out) + "\n")
  puts "rows: #{out['rows'].size}"
end
