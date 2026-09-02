# frozen_string_literal: true
# KOV-H1 — GENERATOR GOLDEN CHARAKTERIZACIE NAKUPU KOVANIA.
#
# PRECO: KOV-H1 pridava do `HardwareSets.expand` druhy kanal (ad-hoc polozky)
# a rozsiruje riadky o `origin`/`free`. Zavazok davky je, ze zakazka BEZ
# ad-hoc poloziek dava PRESNE dnesny nakup a BAJTOVO dnesny CSV. Golden subory
# su odtlacok stavu z MAINU (pred zmenou); `tests/pure/test_kovh_golden.rb`
# porovnava cerstvy vypocet s nimi.
#
# SPUSTA SA RUCNE (test ho NEVOLA — inak by charakterizacia „dokazovala" samu
# seba):  C:/Ruby32-x64/bin/ruby.exe tests/fixtures/kovh_golden/generate.rb
#
# Prepisuje `*.json` v tomto priecinku. Regenerovat sa smie IBA vtedy, ked je
# zmena vystupu VEDOMA a zdovodnena v PR — inak je rozdiel NALEZ, nie sum.
require_relative '../../helper'

require 'json'

module NxKovhGoldenGen
  DIR = __dir__

  module_function

  # Konfiguracie sa zdielaju s testom (jeden zdroj pravdy) — test ich nacita
  # z tohto suboru cez `require`.
  def cases
    NxKovhGolden::CASES
  end

  def run
    cases.each do |name, kase|
      File.write(File.join(DIR, "#{name}.json"),
                 JSON.pretty_generate(NxKovhGolden.snapshot(kase)) + "\n")
    end
    puts "OK: #{cases.length} golden suborov v #{DIR}"
  end
end

require_relative '../../pure/test_kovh_golden' unless defined?(NxKovhGolden)
NxKovhGoldenGen.run if $PROGRAM_NAME == __FILE__
