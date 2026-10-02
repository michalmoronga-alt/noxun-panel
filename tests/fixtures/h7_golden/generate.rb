# frozen_string_literal: true
# H7a / R-38 — GENERATOR GOLDEN CHARAKTERIZACIE (T0a–T0c).
#
# Odtlacok vznikol na MAINE pred zasahom H7a (`18f45933`, v0.17.19): mena
# a nadpisy exportov, bajty suboru nastaveni exportu po kazdom kroku zapisu
# a pomenovanie styroch exportov end-to-end. Fixtura sa NEREGENERUJE —
# H7a ani H7b mena exportov pri zdravom subore nemenia, takze rozdiel je
# NALEZ, nie sum.
#
# SPUSTA SA RUCNE (test ho NEVOLA — charakterizacia by inak „dokazovala" samu seba):
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h7_golden/generate.rb
require_relative '../../helper'

abort('NIE sandbox APPDATA!') unless ENV['APPDATA'].to_s.include?('noxun-tests-')

require 'json'

require_relative '../../pure/test_h7a_golden' unless defined?(NxH7G)

module NxH7GGen
  DIR = __dir__

  module_function

  def put(name, obj)
    File.write(File.join(DIR, "#{name}.json"), JSON.pretty_generate(obj) + "\n")
  end

  def run
    g = NxH7G
    put('names', g.json(g.names_snapshot))
    put('bytes', g.json(g.bytes_snapshot))
    put('exports', g.json(g.exports_snapshot))
    puts "OK: 3 golden subory v #{DIR}"
  end
end

NxH7GGen.run
