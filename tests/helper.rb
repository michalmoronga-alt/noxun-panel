# frozen_string_literal: true
# Noxun Engine — testovaci harness (headless, bez SketchUpu).
#
# BEZPECNOST: pred nacitanim modulov presmeruje %APPDATA% do docasnej zlozky,
# aby testy NIKDY nesiahli na realne katalogy v %APPDATA%\NOXUN\Engine
# (materials.json, abs_rules.json, templates.json). V SketchUp procese sa
# APPDATA NEMENI (zdielal by ju zivy plugin) — testy zavisle od katalogov
# sa tam preskocia cez `NxTest.skip! ... unless NxTest.headless?`.
#
# Harness je cisty Ruby (ziadne gemy) — bezi headless (CI, lokalne ruby)
# aj vnutri SketchUpu (load 'tests/run_all.rb' v test okne).

require 'json'
require 'tmpdir'
require 'fileutils'

module NxTest
  IN_SKETCHUP = defined?(Sketchup) ? true : false
  ROOT = File.expand_path('..', __dir__)

  def self.headless?
    !IN_SKETCHUP
  end
end

unless NxTest::IN_SKETCHUP
  ENV['APPDATA'] = File.join(Dir.mktmpdir('noxun-tests-'), 'AppData')
  FileUtils.mkdir_p(ENV['APPDATA'])
end

# Realna verzia pluginu z loadera — stub aj guard test ju porovnavaju s main.rb.
module NxTest
  LOADER_VERSION = File.read(File.join(ROOT, 'noxun_engine.rb'))[/VERSION\s*=\s*'([^']+)'/, 1].to_s
end

# --- Stub Noxun::Engine (logger + verzia) — LEN headless; v SketchUpe je realny.
unless NxTest::IN_SKETCHUP
  module Noxun
    module Engine
      VERSION = NxTest::LOADER_VERSION unless defined?(VERSION)

      def self.log(_msg)
        nil
      end

      def self.log_error(_e, _context = nil)
        nil
      end
    end
  end
end

# --- Fake objekty pre store.rb / ids.rb (ziadny mock SketchUp API — len duck-typing).
module NxTest
  class FakeEntity
    attr_reader :dicts

    def initialize
      @dicts = Hash.new { |h, k| h[k] = {} }
    end

    def set_attribute(dict, key, value)
      @dicts[dict][key] = value
    end

    def get_attribute(dict, key, default = nil)
      @dicts[dict].fetch(key, default)
    end
  end

  class FakeInstance < FakeEntity
    attr_reader :entityID # rubocop:disable Naming/MethodName — zrkadli SketchUp API

    def initialize(entity_id)
      super()
      @entityID = entity_id
    end
  end

  class FakeDefinition
    attr_reader :instances

    def initialize(instances, image: false, group: false)
      @instances = instances
      @image = image
      @group = group
    end

    def image?
      @image
    end

    def group?
      @group
    end
  end

  class FakeModel
    attr_reader :definitions

    def initialize(definitions)
      @definitions = definitions
    end
  end
end

# --- Nacitanie testovanych modulov (zavislosti pred zavislymi; NIE presne poradie
# main.rb — store/ids su tu az za vypoctovymi modulmi). Bez SketchUp suborov.
# V SketchUpe su uz nacitane pluginom — nenacitavame druhykrat.
unless NxTest::IN_SKETCHUP
  %w[
    core/part_keys
    core/build_plan
    core/json_file_store
    core/materials
    core/abs_rules
    core/hardware_rules
    modules/shelves
    modules/fronts
    core/zone_tree
    core/construction
    core/store
    core/ids
    core/templates
    core/usage_stats
    core/cabinet_builder
    core/board_builder
    core/bom
  ].each { |rel| require File.join(NxTest::ROOT, 'noxun_engine', rel) }
end

# --- Mini assert framework -----------------------------------------------------
module NxTest
  Failure = Class.new(StandardError)
  Skip    = Class.new(StandardError)

  @tests = []

  class << self
    attr_reader :tests

    # Registracia testu: NxTest.test('modul: co overuje') { ...asserty... }
    def test(name, &block)
      @tests << [name, block]
    end

    def skip!(reason)
      raise Skip, reason
    end

    def assert(cond, msg = 'assert zlyhal')
      raise Failure, msg unless cond
    end

    def refute(cond, msg = 'refute zlyhal')
      assert(!cond, msg)
    end

    def assert_equal(expected, actual, msg = nil)
      assert(expected == actual, msg || "ocakavane #{expected.inspect}, dostal #{actual.inspect}")
    end

    # Porovnanie floatov s toleranciou (default 0.01 mm) — nikdy presne ==.
    # POZOR na signaturu: sprava je az 4. argument (3. je tolerancia).
    def assert_close(expected, actual, tol = 0.01, msg = nil)
      raise ArgumentError, "assert_close: tolerancia musi byt cislo, dostal #{tol.inspect} (sprava patri na 4. miesto)" unless tol.is_a?(Numeric)

      ok = actual.is_a?(Numeric) && (expected.to_f - actual.to_f).abs <= tol
      assert(ok, msg || "ocakavane ~#{expected} (tolerancia #{tol}), dostal #{actual.inspect}")
    end

    # pattern: String = substring, Regexp = match. Slovenske spravy matchovat
    # SUBSTRINGOM (nie celou vetou) — texty sa mozu menit.
    def assert_raise(pattern = nil)
      begin
        yield
      rescue Failure, Skip
        raise
      rescue StandardError => e
        if pattern
          matched = pattern.is_a?(Regexp) ? (e.message =~ pattern) : e.message.include?(pattern.to_s)
          assert(matched, "vynimka nematchuje #{pattern.inspect}: #{e.class}: #{e.message}")
        end
        return e
      end
      raise Failure, "ocakavana vynimka#{pattern ? " (#{pattern.inspect})" : ''} nenastala"
    end

    # Spusti vsetky testy, vypise JSON sumar, vrati true/false.
    def run!
      passed = 0
      skipped = 0
      failures = []
      @tests.each do |name, block|
        block.call
        passed += 1
      rescue Skip
        skipped += 1
      rescue Failure => e
        failures << { 'test' => name, 'msg' => e.message }
      rescue StandardError => e
        failures << { 'test' => name, 'msg' => "#{e.class}: #{e.message} @ #{Array(e.backtrace).first}" }
      end
      summary = { 'passed' => passed, 'failed' => failures.size, 'skipped' => skipped, 'failures' => failures }
      puts JSON.pretty_generate(summary)
      failures.empty?
    end
  end
end
