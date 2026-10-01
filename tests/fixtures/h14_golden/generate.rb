# frozen_string_literal: true
# H14 · T0b (R0.3) — GENERATOR serverovej charakterizacie sekcii Studia.
#
# Spusta sa RUCNE a LEN nad NEZMENENYM kodom (1. commit H14a) — test ho nevola,
# inak by charakterizacia „dokazovala" samu seba:
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/h14_golden/generate.rb
#
# Prepisuje `push_keys.json` (whitelist sekcii, matica `consume_pending_section`,
# poradie klucov a obsah `NX.setStudio` bez `version`/`gen`). JS golden
# (`g*.json`) pise `generate.js`. Pri refaktore H14 je kazdy rozdiel NALEZ.
require_relative '../../helper'
require_relative '../../pure/test_h14_studio_sekcie' unless defined?(NxH14Push)

if $PROGRAM_NAME == __FILE__
  File.write(NxH14Push::GOLDEN, JSON.pretty_generate(NxH14Push.snapshot) + "\n")
  puts "OK: #{NxH14Push::GOLDEN}"
end
