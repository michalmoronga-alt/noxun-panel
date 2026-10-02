# frozen_string_literal: true
# H15 — GENERATOR GOLDEN CHARAKTERIZACIE SEED DAT KOVANIA (package H15, R0).
#
# Spusta sa RUCNE a LEN nad NEZMENENYM kodom (prvy commit H15a) — test ho
# nevola, inak by charakterizacia „dokazovala" samu seba:
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h15_golden/generate.rb
#
# Prepisuje `*.json` v tomto priecinku. V H15a ani H15b sa NESPUSTA — rozdiel
# po presune dat je NALEZ. Regenerovat sa smie IBA pri VEDOMEJ zmene seedu
# (nova verzia seedu, zdovodnena v PR).
#
# §15 A1: pred zapisom overi, ze nakup G7 je UPLNY (mechanizmus/kit, ramena,
# tyce, ziadny konflikt, ziadny riadok mimo katalogu). Nesplnena podmienka =
# NIC sa nezapise a skript skonci chybou — neuplny nakup sa nesmie stat
# „spravnym" goldenom.
require_relative '../../helper'
require_relative '../../pure/test_h15_seed_golden' unless defined?(NxH15Golden)

module NxH15GoldenGen
  module_function

  def run
    g = NxH15Golden
    problems = g.purchase_problems
    unless problems.empty?
      warn "H15 golden NEZAPISANY — nakup G7 je neuplny:\n  #{problems.join("\n  ")}"
      exit 1
    end
    FileUtils.mkdir_p(g::DIR)
    g::JSON_FIXTURES.each do |name|
      File.binwrite(g.fixture_path("#{name}.json"), g.pretty(g.document(name)))
    end
    g::RAW_FIXTURES.each do |file, kind|
      File.binwrite(g.fixture_path(file), g.lf(g.raw(kind)))
    end
    puts "OK: #{g::JSON_FIXTURES.length + g::RAW_FIXTURES.length} golden suborov v #{g::DIR}"
  end
end

NxH15GoldenGen.run if $PROGRAM_NAME == __FILE__
