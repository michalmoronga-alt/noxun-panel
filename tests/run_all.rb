# frozen_string_literal: true
# Noxun Engine — spustac celej headless sady.
#   lokalne / CI:  ruby tests/run_all.rb        (exit 1 pri pade)
#   v SketchUpe:   load '.../tests/run_all.rb'  (JSON sumar v Ruby konzole, bez exit)
require_relative 'helper'

Dir[File.join(__dir__, 'pure', 'test_*.rb')].sort.each { |f| require f }

ok = NxTest.run!
exit(ok ? 0 : 1) unless NxTest::IN_SKETCHUP
