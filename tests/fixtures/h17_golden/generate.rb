# frozen_string_literal: true
# H17 / R0.3 — GENERATOR GOLDEN T0 spolocnej pripravy exportov.
#
# Odtlacok vznikol na NEZMENENOM kode (main `2114e1a3`, v0.17.28 — 1. commit
# davky H17a, plugin bez zmeny). Fixtura sa po H17a NEREGENERUJE — rozdiel je
# NALEZ, nie sum (package H17 §2: zmena golden po 1. commite = STOP). H17b smie
# pridat LEN pripady N1 samostatnym commitom (R8.4).
#
#   g1.json — G1 bajty sastnej cesty (cele texty CSV a LOG, XLSX SHA-256)
#   g2.json — G2 matica odmietnuti (spustac × export)
#   g3.json — G3 subeh dvoch spustacov (× export)
# Kazdy zaznam nesie aj PORADIE KROKOV (G4) a pocty citani datovych zdrojov.
#
# SPUSTA SA RUCNE (test ho NEVOLA — charakterizacia by inak „dokazovala" samu seba):
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h17_golden/generate.rb
require_relative '../../helper'

abort('NIE sandbox APPDATA!') unless ENV['APPDATA'].to_s.include?('noxun-tests-')

require 'json'
require_relative '../../pure/h17_harness'

module NxH17Gen
  DIR = __dir__

  module_function

  def put(name, obj)
    File.binwrite(File.join(DIR, "#{name}.json"), "#{JSON.pretty_generate(obj)}\n")
  end

  def run
    put('g1', NxH17.g1_snapshot)
    put('g2', NxH17.g2_snapshot)
    put('g3', NxH17.g3_snapshot)
    puts "OK: 3 golden subory v #{DIR}"
  end
end

NxH17Gen.run
