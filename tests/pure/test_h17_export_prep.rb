# frozen_string_literal: true
# H17a — STRAZCOVIA spolocnej pripravy exportov `ExportPrep` (package
# `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H17.md` §6 R1–R6, §7 T1–T3).
#
#   R4 d  nacitanie: main.rb hned za ui/production_core, helper, subor pri
#         nacitani nevola nic mimo definicii
require_relative '../helper' unless defined?(NxTest)
require 'rbconfig'
require 'open3'

module NxH17P
  E = Noxun::Engine

  module_function

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def prep_src
    src('noxun_engine', 'ui', 'export_prep.rb')
  end
end

# =============================================================================
# R4 d NACITANIE
# =============================================================================

NxTest.test('H17 R4 d: main.rb nacita ui/export_prep HNED za ui/production_core, pred ui/studio_dialog') do
  parts = NxH17P.src('noxun_engine', 'main.rb').scan(/AppLifecycle\.require_part '([^']+)'/).flatten
  i = parts.index('noxun_engine/ui/export_prep')
  NxTest.assert(i, 'export_prep je v zozname casti main.rb')
  NxTest.assert_equal('noxun_engine/ui/production_core', parts[i - 1], 'hned za ui/production_core')
  NxTest.assert_equal('noxun_engine/ui/studio_dialog', parts[i + 1], 'pred ui/studio_dialog')
  NxTest.assert_equal(1, parts.count('noxun_engine/ui/export_prep'), 'prave raz')
end

NxTest.test('H17 R4 d: tests/helper.rb nacita ui/export_prep (S21 — nenacitany modul nesmie prejst naprazdno)') do
  NxTest.assert(NxH17P.src('tests', 'helper.rb').include?("require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'export_prep')"),
                'helper nacita export_prep')
  NxTest.assert(defined?(Noxun::Engine::ExportPrep), 'ExportPrep je po helperi definovany')
end

NxTest.test('H17 R4 d: export_prep.rb pri nacitani nevola nic mimo definicii (samostatny proces bez ProductionCore)') do
  NxTest.skip!('samostatny Ruby proces len headless') unless NxTest.headless?
  path = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'export_prep.rb')
  code = "require #{path.inspect}; e = Noxun::Engine; " \
         "puts [e.const_defined?(:ProductionCore), e::ExportPrep::KINDS.keys.join(',')].join('|')"
  out, err, st = Open3.capture3(RbConfig.ruby, '-e', code)
  NxTest.assert(st.success?, "nacitanie zlyhalo: #{err}")
  NxTest.assert_equal('false|vepo,hw_csv,budget,offer', out.strip, 'nacita sa bez ProductionCore')
end
