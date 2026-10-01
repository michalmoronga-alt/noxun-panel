# frozen_string_literal: true
# Testy H10a/R-35 — DVE OKNA SKETCHUPU A GLOBALNE PRAVIDLA KOVANIA.
#
# Do H10a zapisovalo okno Pravidla globalnu kniznicu (`hardware_rules.json`,
# „aj ako globálnu predvoľbu") UPLNOU NAHRADOU bez revizie: dve okna, ktore si
# pravidla nacitali sucasne, sa prebijali „posledny vyhrava" a zmena prveho
# zanikla bez slova (sonda P1).
#
# C · CHARAKTERIZACIA (prvy commit vetvy, zelena na `main`): pri jednom okne
# sa globalna kniznica zapise BAJTOVO rovnako ako doteraz.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

module NxH10a
  E     = Noxun::Engine
  HR    = E::HardwareRules
  STORE = E::JsonFileStore
  MAT   = E::Materials

  module_function

  # Ulozi primar aj `.bak` kniznice, spusti blok a vrati PRESNY povodny stav.
  def with_lib
    paths = [HR.path, "#{HR.path}.bak"]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    STORE.reload!(HR.path)
    yield
  ensure
    before.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
    end
    STORE.reload!(HR.path)
  end

  def bytes(path = HR.path)
    File.exist?(path) ? File.binread(path) : nil
  end

  # Pravidla s jednou zmenou (prepnute `enabled` pravidla s danym vystupom).
  def toggled(output, base = HR::SEED_RULES)
    HR.normalize_rules(base).map do |r|
      r['output'] == output ? r.merge('enabled' => r['enabled'] == false) : r
    end
  end
end

# --- C1: jedno okno — zapis kniznice bajtovo ako doteraz ---------------------

NxTest.test('H10a C1: jedno okno — `write` zapise kniznicu presne v dnesnom tvare') do
  r = NxH10a
  r.with_lib do
    rules = r.toggled('leg')
    NxTest.assert(r::HR.write(rules), 'zapis prebehol')
    want = JSON.pretty_generate('std' => r::HR::STD, 'seed_version' => r::HR::SEED_VERSION,
                                'rules' => r::HR.normalize_rules(rules))
    NxTest.assert_equal(want, r.bytes, 'bajty = {std, seed_version, normalize_rules(rules)}')
  end
end
