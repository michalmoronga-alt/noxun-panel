# frozen_string_literal: true
# NP-4 — GENERATOR GOLDEN CHARAKTERIZACIE ROZPOCTU (vypnuty prepinac
# „ceny podla planu").
#
# PRECO: zavazok NP-4 je, ze zakazka s VYPNUTYM prepinacom (aj bez kluca)
# dava PRESNE dnesny rozpocet, XLSX rozpoctu aj harok cien ponuky. Golden
# subory su odtlacok stavu z MAINU PRED NP-4 (v0.15.3);
# `tests/pure/test_np4_golden.rb` porovnava cerstvy vypocet s nimi.
#
# SPUSTA SA RUCNE (test ho NEVOLA — inak by charakterizacia „dokazovala"
# samu seba):  C:/Ruby32-x64/bin/ruby.exe tests/fixtures/np4_golden/generate.rb
#
# Prepisuje `*.json` v tomto priecinku. Regenerovat sa smie IBA vtedy, ked je
# zmena vystupu VEDOMA a zdovodnena v PR — inak je rozdiel NALEZ, nie sum.
require_relative '../../helper'

require 'json'

module NxNp4GoldenGen
  DIR = __dir__

  module_function

  def run
    NxNp4Golden::CASES.each do |name, kase|
      snap = NxNp4Golden.roundtrip(NxNp4Golden.snapshot(kase))
      File.write(File.join(DIR, "#{name}.json"), JSON.pretty_generate(snap) + "\n")
    end
    puts "OK: #{NxNp4Golden::CASES.length} golden suborov v #{DIR}"
  end
end

require_relative '../../pure/test_np4_golden' unless defined?(NxNp4Golden)
NxNp4GoldenGen.run if $PROGRAM_NAME == __FILE__
