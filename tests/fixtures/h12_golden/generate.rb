# frozen_string_literal: true
# H12 — GENERATOR GOLDEN CHARAKTERIZACIE typov skrinky (package H12, R0.1).
#
# Spusta sa RUCNE a LEN nad NEZMENENYM mainom (prvy commit H12a) — test ho
# nevola, inak by charakterizacia „dokazovala" samu seba:
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h12_golden/generate.rb
#
# Prepisuje `case_*.json` a `matrix.json` v tomto priecinku. `insu.json`
# zapisuje `run_h12` v SketchUpe (tests/sketchup/su_runner.rb), nie tento
# skript. Regenerovat sa smie IBA pri VEDOMEJ a v PR zdovodnenej zmene
# vystupu — pri refaktore H12 je kazdy rozdiel NALEZ.
require_relative '../../helper'
require_relative '../../pure/test_h12_golden' unless defined?(NxH12Golden)

module NxH12GoldenGen
  module_function

  def run
    NxH12Golden::CASES.each do |name, spec|
      File.write(NxH12Golden.case_path(name), NxH12Golden.pretty(NxH12Golden.snapshot(spec)))
    end
    File.write(NxH12Golden.matrix_path, NxH12Golden.pretty(NxH12Golden.matrix))
    puts "OK: #{NxH12Golden::CASES.length} pripadov + matica v #{NxH12Golden::DIR}"
  end
end

NxH12GoldenGen.run if $PROGRAM_NAME == __FILE__
