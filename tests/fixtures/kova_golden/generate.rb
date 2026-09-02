# frozen_string_literal: true
# KOV-A1 — GENERATOR GOLDEN CHARAKTERIZACIE ciel.
#
# PRECO: KOV-A1 rozsiruje kontrakt cela (nove typy, nove polia, nove roly).
# Zavazok davky je, ze VYSTUPY EXISTUJUCICH ZAKAZIEK sa NEMENIA. Golden subory
# su odtlacok stavu z MAINU (pred zmenou) pre ~15 reprezentativnych configov;
# `tests/pure/test_kova_golden.rb` porovnava CERSTVY vypocet s nimi.
#
# SPUSTA SA RUCNE (test ho NEVOLA — inak by charakterizacia „dokazovala" samu
# seba):  C:/Ruby32-x64/bin/ruby.exe tests/fixtures/kova_golden/generate.rb
#
# Prepisuje `*.json` v tomto priecinku. Regenerovat sa smie IBA vtedy, ked je
# zmena vystupu VEDOMA a zdovodnena v PR — inak je rozdiel NALEZ, nie sum.
require_relative '../../helper'

require 'json'

module NxKovaGoldenGen
  E = Noxun::Engine

  DIR = __dir__

  module_function

  # Konfiguracie sa zdielaju s testom (jeden zdroj pravdy) — test ich nacita
  # z tohto suboru cez `require`.
  def cases
    NxKovaGolden::CASES
  end

  def run
    cases.each do |name, params|
      File.write(File.join(DIR, "#{name}.json"),
                 JSON.pretty_generate(NxKovaGolden.snapshot(params)) + "\n")
    end
    puts "OK: #{cases.length} golden suborov v #{DIR}"
  end
end

require_relative '../../pure/test_kova_golden' unless defined?(NxKovaGolden)
NxKovaGoldenGen.run if $PROGRAM_NAME == __FILE__
