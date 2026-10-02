# frozen_string_literal: true
# H16 — GENERATOR GOLDEN PRVEHO BEHU (package H16, R0 / §15 A5).
#
# Spusta sa RUCNE a LEN nad kodom PRED zasahom H16 (prvy commit davky) — test
# ho nevola, inak by charakterizacia „dokazovala" samu seba:
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h16_golden/generate.rb
#
# Vola TEN ISTY bezec ako test (`tests/h16_first_use.rb`, samostatny proces)
# a zapise `first_use.json`: zoradeny zoznam suborov korena po prvom behu,
# SHA-256 DETERMINISTICKYCH suborov (ostatne nesu cas, datum alebo cestu —
# len existencia) a mapu subor -> zamok drzany v okamihu zapisu.
#
# V H16 sa NEREGENERUJE — rozdiel po zasahu je NALEZ (STOP). Regenerovat sa
# smie IBA pri VEDOMEJ zmene obsahu prveho behu (novy subor, seed), zdovodnene
# v PR.
require 'json'
require 'rbconfig'
require 'fileutils'

module NxH16GoldenGen
  DIR = __dir__
  FILE = File.join(DIR, 'first_use.json')
  RUNNER = File.expand_path('../../h16_first_use.rb', __dir__)
  # Subory, ktorych obsah je pri prvom behu rovnaky na kazdom PC a v kazdom
  # case (overene dvoma behmi v samostatnych procesoch). NIE su tu:
  # `appliances.json` (peciatky seedu), `legacy_cleanup.json` (cesta Plugins
  # + cas), `*.done` (`done_at`), `usage_stats.json` (datum) a zamky (prazdne).
  DETERMINISTIC = %w[
    materials.json abs_rules.json hardware_rules.json hardware_catalog.json hardware_taxonomy.json
    hardware_sets.json templates.json supplier_settings.json dim_series.json dim_series.json.bak
    updater_settings.json updater_settings.json.bak edge_check.json grain_check.json direction_check.json
    template_usage.json
  ].freeze

  module_function

  def run_once
    out = IO.popen([RbConfig.ruby, RUNNER], err: File::NULL, &:read).to_s
    line = out.lines.find { |l| l.start_with?('NXH16_JSON=') }
    raise "bezec H16 nevratil vysledok:\n#{out}" unless line

    JSON.parse(line.sub('NXH16_JSON=', ''))
  end

  def document(run)
    missing = DETERMINISTIC - run['files']
    raise "prvy beh nevyrobil #{missing.join(', ')}" unless missing.empty?

    { 'files' => run['files'],
      'sha' => DETERMINISTIC.sort.to_h { |f| [f, run['sha'][f]] },
      'locks_at_write' => run['locks_at_write'] }
  end

  def run
    a = document(run_once)
    b = document(run_once)
    raise 'dva behy bezca sa lisia — golden by nebol opakovatelny' unless a == b

    FileUtils.mkdir_p(DIR)
    File.binwrite(FILE, "#{JSON.pretty_generate(a)}\n")
    puts "OK: #{a['files'].length} suborov, #{a['sha'].length} SHA -> #{FILE}"
  end
end

NxH16GoldenGen.run if $PROGRAM_NAME == __FILE__
