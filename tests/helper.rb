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

    # D-34: Ids/resolvery filtruju neplatne entity (valid?); fake je vzdy ziva.
    def valid?
      true
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

    # D-34: Ids.each_of_kind preskakuje neplatne definicie (valid? guard).
    def valid?
      true
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
    core/part_faces
    core/json_file_store
    core/dim_series
    core/materials
    core/materials_catalog
    core/materials_decor
    core/materials_abs
    core/materials_project
    core/materials_migration
    core/materials_health
    core/demos/client
    core/demos/sitemap_cache
    core/demos/slug_matcher
    core/demos/product_parser
    core/demos/lookup
    core/demos/name_search
    core/demos/image_cache
    core/demos/family
    core/materials_demos_create
    core/materials_replace_uni
    core/abs_rules
    core/front_profiles
    core/hardware_rules
    core/hardware_catalog
    core/hardware_sets
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
    core/vepo_export
    core/sheet_estimate
    core/validation
    core/edge_check
    core/supplier_settings
    core/budget_store
    core/budget
    core/xlsx_writer
    core/cp_export
    core/price_refresh
  ].each { |rel| require File.join(NxTest::ROOT, 'noxun_engine', rel) }
end

# --- 2A-4b: legacy (SCHEMA 1) katalog pre dual-mode testy ----------------------
# Seedy su od cutoveru NATIVNE SCHEMA 2 — testy LEGACY spravania (batch 1/2,
# textovy picker, rename podla textu, patch/CRUD bez group_id) si instaluju
# PRESNU predcutoverovu podobu seedov. VYHRADNE headless (v SketchUpe by zapis
# siel do ziveho %APPDATA% katalogu — tam sa katalogove testy skipuju).
module NxTest
  LEGACY_SEED_CATALOG = {
    'std' => 1,
    'sheets' => [
      { 'material_id' => 'K009_PW_DTDL_18', 'family' => 'Kronospan K009 PW',
        'manufacturer' => 'Kronospan', 'decor' => 'K009 PW', 'type' => 'DTDL',
        'thickness' => 18.0, 'grain' => 'length', 'price_per_m2' => 12.5,
        'sheet_size' => [2800.0, 2070.0], 'color' => [198, 168, 122], 'production_class' => 'sheet' },
      { 'material_id' => 'K009_PW_DTDL_16', 'family' => 'Kronospan K009 PW',
        'manufacturer' => 'Kronospan', 'decor' => 'K009 PW', 'type' => 'DTDL',
        'thickness' => 16.0, 'grain' => 'length', 'price_per_m2' => 11.8,
        'sheet_size' => [2800.0, 2070.0], 'color' => [198, 168, 122], 'production_class' => 'sheet' },
      { 'material_id' => 'HDF_WHITE_3', 'family' => 'HDF biela',
        'manufacturer' => 'Kronospan', 'decor' => 'Biela HDF', 'type' => 'HDF',
        'thickness' => 3.0, 'grain' => 'none', 'price_per_m2' => 3.2,
        'sheet_size' => [2800.0, 2070.0], 'color' => [238, 236, 230], 'production_class' => 'sheet' },
      { 'material_id' => 'W1000_DTDL_18', 'family' => 'Egger W1000 ST9',
        'manufacturer' => 'Egger', 'decor' => 'W1000 ST9 Biela', 'type' => 'DTDL',
        'thickness' => 18.0, 'grain' => 'none', 'price_per_m2' => 13.9,
        'sheet_size' => [2800.0, 2070.0], 'color' => [246, 246, 244], 'production_class' => 'sheet' }
    ],
    'edges' => [
      { 'abs_id' => 'ABS_K009_10', 'decor' => 'K009 PW', 'thickness' => 1.0,
        'price_per_bm' => 0.55, 'color' => [198, 168, 122] },
      { 'abs_id' => 'ABS_K009_20', 'decor' => 'K009 PW', 'thickness' => 2.0,
        'price_per_bm' => 0.85, 'color' => [198, 168, 122] },
      { 'abs_id' => 'ABS_W1000_10', 'decor' => 'W1000 ST9 Biela', 'thickness' => 1.0,
        'price_per_bm' => 0.60, 'color' => [246, 246, 244] }
    ]
  }.freeze

  # Nainstaluje LEGACY seed katalog (marker 1) do APPDATA sandboxu — testy
  # dual-mode spravania bezia presne nad predcutoverovym stavom. Vola sa na
  # ZACIATKU test suboru (subory su sekvencne; kazdy si stav deklaruje sam).
  def self.install_legacy_catalog!
    return unless headless?
    mat = Noxun::Engine::Materials
    FileUtils.mkdir_p(mat.dir)
    payload = JSON.parse(JSON.generate(LEGACY_SEED_CATALOG))
    Noxun::Engine::JsonFileStore.write(mat.path, payload)
    FileUtils.rm_f("#{mat.path}.bak") # .bak z predoslych zapisov nesmie drzat marker 2
    Noxun::Engine::JsonFileStore.invalidate(mat.path)
    mat.reset_catalog_state!
    true
  end

  # Cerstvy SEED stav (od 2A-4b nativne SCHEMA 2) — zmaze katalog aj zalohy
  # v sandboxe a necha ho znovu seednut. Pre testy seed kontraktu.
  def self.install_fresh_seed_catalog!
    return unless headless?
    mat = Noxun::Engine::Materials
    FileUtils.rm_f(mat.path)
    FileUtils.rm_f("#{mat.path}.bak")
    FileUtils.rm_f(mat.pre_schema2_backup_path)
    Noxun::Engine::JsonFileStore.invalidate(mat.path)
    mat.reset_catalog_state!
    mat.reload! # prvy pristup seedne (SCHEMA 2)
    true
  end
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
