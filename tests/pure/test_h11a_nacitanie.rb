# frozen_string_literal: true
# Testy H11a (F-01, cast „nacitanie"): SUBORY PLUGINU S JEDNOU HLASKOU.
#
# CO SA DOKAZUJE:
#   T4 `AppLifecycle.require_part` nad SKUTOCNYMI subormi v TEMP: RuntimeError,
#      NameError, SyntaxError aj LoadError sa zapisu (s logom) a nic nevyhodi;
#      ok = true, znova = false; Interrupt PREJDE; vlastny `record:` nezaspini
#      globalny zoznam; `announce_failures!` 2x = 1 hlaska s prvou cestou,
#      poctom a vetou „Reštartuj SketchUp".
#   T5 subprocess SKUTOCNEHO `main.rb` + `core/app_lifecycle.rb` nad docasnym
#      stromom so stub subormi a stub `sketchup.rb`: chyba casti = vsetky
#      casti skusene, 1 hlaska, init NEbezi; vsetko ok = init bezi a 0 hlasok;
#      chybajuci / pokazeny / nedokonceny bootstrap = 1 hlaska o zakladnom
#      subore a 0 casti; neprijaty quit observer = hlaska a init NEbezi.
#   T6 staticky: zoznam 91 + 14 casti a poradie = zmrazena kopia z mainu
#      b2427ef1, kazda cesta existuje, ziadne `Sketchup.require 'noxun_engine/`
#      ani `.rbe`/`.rbs`.
#
# MUTACIE (vysledok v PR davky H11a):
#   M9  init bezi pri `install!` false        -> T5g
#   M10 `require_part` chyta len StandardError -> T4 (SyntaxError/LoadError)
#   M11 init bezi pri chybach                  -> T5a/T5b
#   M12 bootstrap bez vlastnej vetvy           -> T5d/T5e
#   M13 hlaska pri kazdej chybe                -> T4 (2x announce), T5a
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require 'stringio'
require 'rbconfig'
require 'json'

module NxH11aLoad
  # Zmrazeny zoznam casti `main.rb` a `ui/panel.rb` (poradie!) z mainu b2427ef1
  # (v0.17.21). Novy subor pluginu = vedome doplnenie TU aj v `main.rb`.
  MAIN_PARTS = %w[
    core/units core/doc_key core/ids core/store core/part_keys core/build_plan core/cabinet_types
    core/part_faces core/json_file_store core/dim_series core/materials core/materials_appearance
    core/materials_native_appearance core/materials_build_appearance core/appearance_mapping
    core/materials_apply_appearance core/updater core/materials_catalog core/materials_decor
    core/materials_abs core/materials_project core/materials_migration core/materials_health
    core/demos/client core/demos/sitemap_cache core/demos/slug_matcher core/demos/product_parser
    core/demos/lookup core/demos/name_search core/demos/image_cache core/demos/family
    core/materials_demos_create core/materials_replace_uni core/abs_rules core/front_profiles
    core/hardware_rules core/hardware_catalog core/appliance_catalog core/hardware_taxonomy
    core/hardware_sets core/drawer_recipes modules/shelves modules/fronts core/zone_tree core/zones
    core/construction core/scale_observer core/placement core/cabinet_builder core/board_builder
    core/ghost_tool core/tags core/templates core/template_previews core/appliance_checks core/bom
    core/usage_stats core/vepo_export core/sheet_estimate core/debug core/validation core/sheet_layout
    core/edge_check core/hover_edge core/grain_check core/direction_check core/edge_overlay
    core/supplier_settings core/export_settings core/budget_store core/appliance_binding core/budget
    core/xlsx_writer core/cp_export core/price_refresh ui/production_core ui/studio_dialog ui/panel
    ui/rules_dialog ui/materials_dialog ui/materials_appearance_dialog ui/hardware_catalog_dialog
    ui/appliance_dialog ui/supplier_settings_dialog ui/templates_dialog tools/mower_calc
    tools/snap_calc tools/legacy_cleanup tools/tools tools/mower tools/snaper
  ].map { |p| "noxun_engine/#{p}" }.freeze
  PANEL_PARTS = %w[
    actions_cabinet actions_zones actions_templates actions_materials actions_parts actions_hardware
    actions_board actions_appliance actions_usage actions_settings sync resolvers payloads selection
  ].map { |p| "noxun_engine/ui/panel/#{p}" }.freeze
  PART_RE = /AppLifecycle\.require_part '([^']+)'/.freeze

  module_function

  def lc
    Noxun::Engine::AppLifecycle
  end

  def src(*parts)
    File.binread(File.join(NxTest::ROOT, *parts)).force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    path
  end

  def quiet
    old = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = old
  end

  # Docasny UI s messageboxom (headless UI nema).
  def with_messagebox
    return yield([]) if Object.const_defined?(:UI)

    msgs = []
    ui = Module.new
    ui.define_singleton_method(:messagebox) { |m| msgs << m }
    Object.const_set(:UI, ui)
    begin
      yield(msgs)
    ensure
      Object.send(:remove_const, :UI)
    end
  end

  # --- T5 subprocess --------------------------------------------------------

  STUB_SKETCHUP = <<~'RUBY'
    $nx_msgs = []
    $nx_menu = 0
    $nx_obs = []
    def file_loaded?(_f)
      false
    end

    def file_loaded(_f)
      nil
    end
    module Sketchup
      class AppObserver; end
      def self.add_observer(obs)
        return false if ENV['NX_ADD_OBSERVER'] == 'false'

        $nx_obs << obs
        true
      end

      def self.remove_observer(_obs)
        true
      end

      def self.status_text=(_t); end
    end
    module UI
      def self.messagebox(msg)
        $nx_msgs << msg
      end

      def self.menu(_name)
        $nx_menu += 1
        Menu.new
      end

      class Menu
        def add_submenu(_n)
          Menu.new
        end

        def add_item(*)
          1
        end
      end

      class Toolbar
        def initialize(*); end
        def add_item(*); end
        def restore; end
      end

      class Command
        attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
        def initialize(*); end
        def set_validation_proc; end
      end
    end
  RUBY

  # Vrati hash z behu `main.rb` v samostatnom Ruby. `mode` riadi poruchu.
  def boot(mode = :ok)
    root = File.realpath(Dir.mktmpdir('nx-h11a-')).tr('\\', '/')
    begin
      plugins = File.join(root, 'plugins')
      write(File.join(plugins, 'noxun_engine', 'main.rb'), File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb')))
      life = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'app_lifecycle.rb'))
      life_path = File.join(plugins, 'noxun_engine', 'core', 'app_lifecycle.rb')
      case mode
      when :bootstrap_missing then nil
      when :bootstrap_syntax then write(life_path, "#{life}\ndef nx_broken(\n")
      when :bootstrap_no_sentinel
        write(life_path, life.force_encoding(Encoding::UTF_8).sub(/^Noxun::Engine::AppLifecycle::LOADED.*$/, ''))
      else write(life_path, life)
      end
      MAIN_PARTS.each do |part|
        body = "$nx_parts << #{part.inspect}\n"
        if part == 'noxun_engine/core/abs_rules'
          body += "raise 'T5 porucha casti'\n" if mode == :part_raise
          body = "def nx_broken(\n" if mode == :part_syntax
        end
        write(File.join(plugins, "#{part}.rb"), body)
      end
      stubs = File.join(root, 'stubs')
      write(File.join(stubs, 'sketchup.rb'), STUB_SKETCHUP)
      script = write(File.join(root, 'boot.rb'), <<~RUBY)
        require 'json'
        $LOAD_PATH.unshift(#{stubs.inspect})
        $nx_parts = []
        begin
          load #{File.join(plugins, 'noxun_engine', 'main.rb').inspect}
        rescue ScriptError, StandardError => e
          puts "NX_RAISED=\#{e.class}: \#{e.message}"
        end
        fails = defined?(Noxun::Engine::AppLifecycle) && Noxun::Engine::AppLifecycle.respond_to?(:failures) ? Noxun::Engine::AppLifecycle.failures : nil
        puts 'NX_JSON=' + JSON.generate('parts' => $nx_parts, 'msgs' => $nx_msgs, 'menu' => $nx_menu,
                                        'obs' => $nx_obs.length, 'failures' => fails)
      RUBY
      env = { 'NX_ADD_OBSERVER' => (mode == :observer_false ? 'false' : 'true') }
      out = IO.popen(env, [RbConfig.ruby, script], err: %i[child out], &:read).to_s.force_encoding(Encoding::UTF_8)
      json = out[/^NX_JSON=(.*)$/, 1]
      res = json ? JSON.parse(json) : {}
      res.merge('raw' => out, 'init' => out.include?('boot_cutover'), 'raised' => out[/^NX_RAISED=(.*)$/, 1])
    ensure
      FileUtils.rm_rf(root)
    end
  end
end

# --- T4: require_part nad skutocnymi subormi ----------------------------------

NxTest.test('H11a T4: require_part — chyby suboru sa zapisu, nic nevyhodi, ok/znova = true/false') do
  dir = Dir.mktmpdir('nx-h11a-t4-')
  begin
    {
      'ok' => "$nx_h11a_t4 = ($nx_h11a_t4 || 0) + 1\n",
      'boom' => "raise 'T4 porucha'\n",
      'name' => "NxH11aNeexistuje.volaj\n",
      'syn' => "def nx_h11a_broken(\n"
    }.each { |n, body| NxH11aLoad.write(File.join(dir, "#{n}.rb"), body) }
    rec = []
    before = NxH11aLoad.lc.failures.dup
    res = NxH11aLoad.quiet do
      %w[ok ok boom name syn missing].map { |n| NxH11aLoad.lc.require_part(n, record: rec, root: dir) }
    end
    NxTest.assert_equal([true, false, nil, nil, nil, nil], res, 'ok -> true, znova -> false, chyby -> nil')
    NxTest.assert_equal(%w[RuntimeError NameError SyntaxError LoadError], rec.map { |r| r['class'] })
    NxTest.assert_equal(%w[boom name syn missing], rec.map { |r| r['path'] })
    NxTest.assert(rec.all? { |r| !r['message'].empty? && r['backtrace'].length <= 6 }, 'sprava + najviac 6 riadkov')
    NxTest.assert_equal(before, NxH11aLoad.lc.failures, '`record:` nezaspinil globalny zoznam')
    NxTest.assert_equal(1, $nx_h11a_t4, 'ok.rb sa vykonal PRAVE RAZ')
  ensure
    FileUtils.rm_rf(dir)
  end
end

NxTest.test('H11a T4: require_part — chyba sa zaloguje (konzola) a Interrupt PREJDE') do
  dir = Dir.mktmpdir('nx-h11a-t4b-')
  begin
    NxH11aLoad.write(File.join(dir, 'boom2.rb'), "raise 'T4 log'\n")
    NxH11aLoad.write(File.join(dir, 'intr.rb'), "raise Interrupt\n")
    old = $stdout
    buf = StringIO.new
    $stdout = buf
    begin
      NxH11aLoad.lc.require_part('boom2', record: [], root: dir)
    ensure
      $stdout = old
    end
    NxTest.assert(buf.string.include?('boom2.rb') && buf.string.include?('RuntimeError'), "log chyby: #{buf.string}")
    passed = false
    begin
      NxH11aLoad.lc.require_part('intr', record: [], root: dir)
    rescue Interrupt
      passed = true
    end
    NxTest.assert(passed, 'Interrupt musi prejst (rescue len StandardError + ScriptError)')
  ensure
    FileUtils.rm_rf(dir)
  end
end

NxTest.test('H11a T4: announce_failures! — 2x volanie = 1 hlaska s prvou cestou, poctom a restartom') do
  NxTest.skip!('meni stav nacitania — len headless') unless NxTest.headless?
  lc = NxH11aLoad.lc
  begin
    lc.reset_for_tests!(boot: true)
    NxH11aLoad.with_messagebox do |msgs|
      NxTest.refute(lc.announce_failures!, 'bez chyb ziadna hlaska')
      dir = Dir.mktmpdir('nx-h11a-t4c-')
      begin
        NxH11aLoad.write(File.join(dir, 'a.rb'), "raise 'a'\n")
        NxH11aLoad.write(File.join(dir, 'b.rb'), "def x(\n")
        NxH11aLoad.quiet do
          lc.require_part('a', root: dir)
          lc.require_part('b', root: dir)
        end
      ensure
        FileUtils.rm_rf(dir)
      end
      NxTest.assert(lc.failed?, 'zaznamy su v globalnom zozname')
      r1 = NxH11aLoad.quiet { lc.announce_failures! }
      r2 = NxH11aLoad.quiet { lc.announce_failures! }
      NxTest.assert(r1 && !r2, 'druhe volanie nic neukaze')
      NxTest.assert_equal(1, msgs.length, "presne JEDNA hlaska (#{msgs.length})")
      m = msgs.first.to_s
      NxTest.assert(m.include?('a.rb') && m.include?('spolu 2') && m.include?('Reštartuj SketchUp') &&
                    m.include?('vypnutý'), "text hlasky: #{m}")
    end
  ensure
    lc.reset_for_tests!(boot: true)
  end
end

# --- T5: subprocess skutocneho main.rb -----------------------------------------

def nx_h11a_t5_skip!
  NxTest.skip!('subprocess len headless') unless NxTest.headless?
end

NxTest.test('H11a T5a: chyba casti (raise) — vsetky casti skusene, 1 hlaska, init NEbezi') do
  nx_h11a_t5_skip!
  r = NxH11aLoad.boot(:part_raise)
  NxTest.assert(r['raised'].nil?, "main.rb nesmie vyhodit: #{r['raised']}")
  NxTest.assert_equal(NxH11aLoad::MAIN_PARTS, r['parts'], 'skusili sa VSETKY casti v poradi')
  NxTest.assert_equal(1, r['msgs'].length, "jedna hlaska: #{r['msgs'].inspect}")
  NxTest.assert(r['msgs'].first.to_s.include?('noxun_engine/core/abs_rules.rb'), r['msgs'].first.to_s)
  NxTest.refute(r['init'], "init nesmie bezat: #{r['raw']}")
  NxTest.assert_equal(0, r['menu'], 'UI.menu nevolane')
  NxTest.assert_equal(0, r['obs'], 'pri chybe sa observer ani neregistruje')
end

NxTest.test('H11a T5b: syntax chyba casti — ostatne casti nacitane, 1 hlaska, init NEbezi') do
  nx_h11a_t5_skip!
  r = NxH11aLoad.boot(:part_syntax)
  NxTest.assert(r['raised'].nil?, "main.rb nesmie vyhodit: #{r['raised']}")
  NxTest.assert_equal(NxH11aLoad::MAIN_PARTS - ['noxun_engine/core/abs_rules'], r['parts'])
  NxTest.assert_equal(['SyntaxError'], Array(r['failures']).map { |f| f['class'] })
  NxTest.assert_equal(1, r['msgs'].length)
  NxTest.refute(r['init'], 'init nesmie bezat')
  NxTest.assert_equal(0, r['menu'])
end

NxTest.test('H11a T5c: vsetko ok — init bezi, 0 hlasok, observer zaregistrovany 1x') do
  nx_h11a_t5_skip!
  r = NxH11aLoad.boot(:ok)
  NxTest.assert(r['raised'].nil?, "main.rb nesmie vyhodit: #{r['raised']}")
  NxTest.assert_equal(NxH11aLoad::MAIN_PARTS, r['parts'])
  NxTest.assert_equal([], r['msgs'])
  NxTest.assert(r['init'], "init MUSI bezat: #{r['raw']}")
  NxTest.assert_equal(1, r['menu'], 'menu sa vytvorilo')
  NxTest.assert_equal(1, r['obs'], 'quit observer zaregistrovany raz')
end

{ 'd' => :bootstrap_missing, 'e' => :bootstrap_syntax, 'f' => :bootstrap_no_sentinel }.each do |k, mode|
  NxTest.test("H11a T5#{k}: bootstrap #{mode} — 1 hlaska o zakladnom subore, 0 casti, init NEbezi") do
    nx_h11a_t5_skip!
    r = NxH11aLoad.boot(mode)
    NxTest.assert(r['raised'].nil?, "main.rb nesmie vyhodit: #{r['raised']}")
    NxTest.assert_equal([], r['parts'], 'ziadna cast sa neskusila')
    NxTest.assert_equal(1, r['msgs'].length, "jedna hlaska: #{r['msgs'].inspect}")
    NxTest.assert(r['msgs'].first.to_s.include?('core/app_lifecycle.rb'), r['msgs'].first.to_s)
    NxTest.refute(r['init'], 'init nesmie bezat')
    NxTest.assert_equal(0, r['menu'])
  end
end

NxTest.test('H11a T5g: quit observer neprijaty (add_observer false) — hlaska, init NEbezi') do
  nx_h11a_t5_skip!
  r = NxH11aLoad.boot(:observer_false)
  NxTest.assert_equal(NxH11aLoad::MAIN_PARTS, r['parts'], 'casti sa nacitali vsetky')
  NxTest.assert_equal(1, r['msgs'].length, "jedna hlaska: #{r['msgs'].inspect}")
  NxTest.assert(r['msgs'].first.to_s.include?('quit observer'), r['msgs'].first.to_s)
  NxTest.refute(r['init'], 'init nesmie bezat')
  NxTest.assert_equal(0, r['menu'])
end

# --- T6: staticky zoznam --------------------------------------------------------

NxTest.test('H11a T6: zoznam casti main.rb (91) a panel.rb (14) = zmrazena kopia, poradie sedi') do
  main = NxH11aLoad.src('noxun_engine', 'main.rb')
  panel = NxH11aLoad.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.assert_equal(91, NxH11aLoad::MAIN_PARTS.length)
  NxTest.assert_equal(NxH11aLoad::MAIN_PARTS, main.scan(NxH11aLoad::PART_RE).flatten)
  NxTest.assert_equal(NxH11aLoad::PANEL_PARTS, panel.scan(NxH11aLoad::PART_RE).flatten)
end

NxTest.test('H11a T6: kazda cast existuje; ziadne Sketchup.require stromu ani .rbe/.rbs') do
  (NxH11aLoad::MAIN_PARTS + NxH11aLoad::PANEL_PARTS).each do |part|
    NxTest.assert(File.file?(File.join(NxTest::ROOT, "#{part}.rb")), "chyba subor #{part}.rb")
  end
  offenders = Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')].select do |f|
    File.binread(f).force_encoding(Encoding::UTF_8).lines.any? { |l| l.sub(/#.*$/, '').include?("Sketchup.require 'noxun_engine/") }
  end
  NxTest.assert(offenders.empty?, "Sketchup.require stromu: #{offenders.inspect}")
  enc = Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.{rbe,rbs}')]
  NxTest.assert(enc.empty?, "plugin sa nesifruje — Ruby require .rbe/.rbs nenacita: #{enc.inspect}")
end

NxTest.test('H11a T6: bootstrap ide PRED zoznamom a ma vlastnu chybovu vetvu bez AppLifecycle') do
  main = NxH11aLoad.src('noxun_engine', 'main.rb')
  boot = main[/def self\.bootstrap_lifecycle!.*?\n    end\n/m].to_s
  NxTest.refute(boot.empty?, 'bootstrap_lifecycle! chyba')
  NxTest.assert(boot.include?('rescue StandardError, ScriptError'), 'vlastna chybova vetva (aj ScriptError)')
  NxTest.assert(boot.include?('LOADED'), 'kontrola sentinelu')
  failed = main[/def self\.bootstrap_failed!.*?\n    end\n/m].to_s
  NxTest.refute(failed.include?('AppLifecycle'), 'chybova vetva nesmie zavisiet od AppLifecycle')
  NxTest.assert(main.index('if bootstrap_lifecycle!') < main.index("AppLifecycle.require_part 'noxun_engine/core/units'"),
                'zoznam casti je VNUTRI podmienky bootstrapu')
  life = NxH11aLoad.src('noxun_engine', 'core', 'app_lifecycle.rb')
  NxTest.assert(life.strip.lines.last.start_with?('Noxun::Engine::AppLifecycle::LOADED = true'),
                'sentinel je posledny riadok suboru')
  code = life.lines.map { |l| l.sub(/#.*$/, '') }.join
  NxTest.refute(code =~ /^\s*(require|load)\s+['"]|require_relative|Sketchup\.require/,
                'bootstrap nesmie nacitavat ine subory pluginu')
end
