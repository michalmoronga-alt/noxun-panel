# frozen_string_literal: true
# H9 / R-37 — GENERATOR GOLDEN CHARAKTERIZACIE (T0b, T0d).
#
# PRECO: H9 meni citanie a zapis troch suborov nastaveni (dodavatel, ABS,
# kovanie). Zavazok davky: pri ZDRAVOM subore sa vyrobne ani cenove cisla
# nemenia. Existujuce golden (np4, ceny-m2, kova, kovh) stoja na seede
# a cestu CEZ SUBOR nedokazu — tieto odtlacky ju dokazuju:
#   plan_budget.json  — narezovy plan a rozpocet (prepinac ceny podla planu
#                       vypnuty aj zapnuty) s parametrami ZO SUBORU dodavatela,
#   <pripad>.json     — nakupne CSV kovania a VEPO CSV s hranami nad VLASTNYMI
#                       zdravymi subormi pravidiel ABS a kovania.
#
# Odtlacok vznikol na MAINE pred zasahom H9. Zavisi aj od seedu katalogu
# kovania, setov a pravidiel — ked sa niektory seed VEDOME zmeni, regeneruje
# sa a zdovodni v PR; inak je rozdiel NALEZ, nie sum.
#
# SPUSTA SA RUCNE (test ho NEVOLA):
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h9_golden/generate.rb
require_relative '../../helper'

require 'json'

require_relative '../../pure/test_r37_tvar_suborov' unless defined?(NxR37)

module NxR37Gen
  DIR = __dir__

  module_function

  def put(name, obj)
    File.write(File.join(DIR, "#{name}.json"), JSON.pretty_generate(obj) + "\n")
  end

  def run
    r = NxR37
    put('plan_budget', r.with_sandbox { r.plan_budget_from_file })
    r.json(r.t0d_snapshot(true)).each { |name, snap| put(name, snap) }
    puts "OK: #{r::T0D_CASES.length + 1} golden suborov v #{DIR}"
  end
end

NxR37Gen.run if $PROGRAM_NAME == __FILE__
