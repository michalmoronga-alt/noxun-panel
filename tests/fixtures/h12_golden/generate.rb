# frozen_string_literal: true
# H12 — GENERATOR GOLDEN CHARAKTERIZACIE typov skrinky (package H12, R0.1).
#
# Spusta sa RUCNE a LEN nad NEZMENENYM kodom danej casti — test ho nevola,
# inak by charakterizacia „dokazovala" samu seba:
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h12_golden/generate.rb         # H12a: case_*.json + matrix.json
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h12_golden/generate.rb panel   # H12b: LEN panel.json
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h12_golden/generate.rb roles   # H12d: LEN roles.json
#
# Bez argumentu prepisuje `case_*.json` a `matrix.json` (prvy commit H12a);
# s argumentom `panel` LEN `panel.json` (prvy commit H12b — fixtury H12a sa
# nedotkne). `insu.json` zapisuje `run_h12` v SketchUpe (tests/sketchup/
# su_runner.rb), nie tento skript. Regenerovat sa smie IBA pri VEDOMEJ a v PR
# zdovodnenej zmene vystupu — pri refaktore H12 je kazdy rozdiel NALEZ.
require_relative '../../helper'
require_relative '../../pure/test_h12_golden' unless defined?(NxH12Golden)
require_relative '../../pure/test_h12b_golden' unless defined?(NxH12bGolden)
require_relative '../../pure/test_h12d_roles_golden' unless defined?(NxH12dGolden)

module NxH12GoldenGen
  module_function

  def run
    NxH12Golden::CASES.each do |name, spec|
      File.write(NxH12Golden.case_path(name), NxH12Golden.pretty(NxH12Golden.snapshot(spec)))
    end
    File.write(NxH12Golden.matrix_path, NxH12Golden.pretty(NxH12Golden.matrix))
    puts "OK: #{NxH12Golden::CASES.length} pripadov + matica v #{NxH12Golden::DIR}"
  end

  def run_panel
    File.write(NxH12bGolden::PATH, NxH12bGolden.pretty(NxH12bGolden.snapshot))
    puts "OK: panel golden v #{NxH12bGolden::PATH}"
  end

  def run_roles
    File.write(NxH12dGolden::PATH, NxH12dGolden.pretty(NxH12dGolden.snapshot))
    puts "OK: golden mien roli v #{NxH12dGolden::PATH}"
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.include?('panel') then NxH12GoldenGen.run_panel
  elsif ARGV.include?('roles') then NxH12GoldenGen.run_roles
  else NxH12GoldenGen.run
  end
end
