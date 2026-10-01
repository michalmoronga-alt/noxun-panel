# frozen_string_literal: true
# Testy H11b (F-02): MINIMUM SKETCHUP 2026.
#
# CO SA DOKAZUJE:
#   * loader v SketchUpe starsom ako 2026 plugin NEZAREGISTRUJE, stav bootu je
#     `:unsupported`, hlaska spomina 2026 aj zistenu verziu a na disku NEVZNIKNE
#     ani lease, ani zamok (kontrola bezi PRED recovery);
#   * 2026.0, 2026.2 aj 2027 sa nacitaju ako doteraz;
#   * nezistitelna verzia (chyba metoda, nezmysel, vynimka, odporujuce si
#     zdroje) = FAIL-OPEN: plugin sa nacita a do konzoly ide riadok;
#   * ciselne `version_number` je hlavny zdroj, retazec len zaloha (N6);
#   * kontrola zije MIMO `module Boot` (ta nesmie volat SketchUp API);
#   * v styroch prekrytiach uz nie su verzijne poistky z cias pred 2023.0;
#   * instalator (`-ResolveOnly`) vyberie 2026, inak najnovsi >= 2026, starsie
#     odmietne a `NOXUN_INSTALL_DEST` ani v resolve rezime nic nevytvori.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   MB1 gate `> 26` namiesto `>= 26`        -> „26.0.429 / 26.2.243 sa nacitaju"
#   MB2 fail-closed pri neznamej verzii      -> „neznama verzia = fail-open"
#   MB3 gate az po `recover!`                -> „starsi SketchUp: ani lease, ani zamok"
#   MB4 gate vo vnutri `module Boot`         -> „kontrola zije mimo module Boot"
#   MB5 spat `respond_to?(:enabled=)`        -> „v prekrytiach nie su verzijne poistky"
#   MB6 instalator bez filtra >= 2026        -> „instalator: {2022, 2024} = chyba"
#   MB7 `NOXUN_INSTALL_DEST` ignorovany      -> „instalator: NOXUN_INSTALL_DEST"
#
# Subprocesove testy bezia len headless (v SketchUpe `RbConfig.ruby` nie je
# samostatny interpreter) a vyhradne nad TEMP sandboxom.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require 'rbconfig'
require 'open3'

module NxH11b
  LOADER_SRC = File.binread(File.join(NxTest::ROOT, 'noxun_engine.rb'))
  LOADER_TEXT = LOADER_SRC.dup.force_encoding(Encoding::UTF_8)
  VERSION = LOADER_TEXT[/^\s*VERSION\s*=\s*'([^']+)'/, 1]

  module_function

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    path
  end

  # `methods` = Ruby kod tiel metod stubu `Sketchup` (nic = bez metod verzie).
  # Vrati hash: status, registered, message, raw a priznaky lease/lock na disku.
  def boot(version_code = '')
    root = File.realpath(Dir.mktmpdir('nx-h11b-')).tr('\\', '/')
    begin
      plugins = File.join(root, 'plugins')
      write(File.join(plugins, 'noxun_engine.rb'), LOADER_SRC)
      write(File.join(plugins, 'noxun_engine', 'main.rb'),
            "module Noxun\n  module Engine\n    VERSION = '#{VERSION}' unless defined?(VERSION)\n  end\nend\n")
      stubs = File.join(root, 'stubs')
      write(File.join(stubs, 'sketchup.rb'), <<~RUBY)
        module Sketchup
          def self.register_extension(*)
            $nx_registered = true
          end
          #{version_code}
        end
        module UI
          def self.messagebox(msg)
            $nx_messages << msg
          end
        end
      RUBY
      write(File.join(stubs, 'extensions.rb'),
            "class SketchupExtension\n  attr_accessor :description, :version, :creator, :copyright\n" \
            "  def initialize(*); end\nend\n")
      script = File.join(root, 'boot.rb')
      write(script, <<~RUBY)
        $LOAD_PATH.unshift(#{stubs.inspect})
        $nx_registered = false
        $nx_messages = []
        load #{File.join(plugins, 'noxun_engine.rb').inspect}
        puts "NX_STATUS=\#{Noxun::Engine::Boot.status}"
        puts "NX_REGISTERED=\#{$nx_registered ? 1 : 0}"
        puts "NX_MESSAGES=\#{$nx_messages.length}"
        puts "NX_MESSAGE=\#{$nx_messages.first}"
      RUBY
      out = IO.popen([RbConfig.ruby, script], err: %i[child out], &:read).to_s.force_encoding(Encoding::UTF_8)
      leases = File.join(plugins, 'noxun_engine.leases')
      { 'raw' => out,
        'status' => out[/^NX_STATUS=(.*)$/, 1].to_s,
        'registered' => out[/^NX_REGISTERED=(\d)$/, 1].to_s == '1',
        'messages' => out[/^NX_MESSAGES=(\d+)$/, 1].to_i,
        'message' => out[/^NX_MESSAGE=(.*)$/, 1].to_s,
        'lease' => Dir.exist?(leases) && !Dir.children(leases).empty?,
        'lock' => File.exist?(File.join(plugins, 'noxun_engine.update.lock')) }
    ensure
      FileUtils.rm_rf(root)
    end
  end

  # Realisticky stub: retazec aj cislo vo formate `XXYZZZZZZZ`.
  def su(version)
    major, minor, build = version.split('.').map(&:to_i)
    number = (major * 100_000_000) + (minor * 10_000_000) + build
    "def self.version; #{version.inspect}; end\n  def self.version_number; #{number}; end"
  end

  def unknown_logged?(out)
    out['raw'].include?('verziu SketchUpu sa nepodarilo zistit')
  end

  # --- instalator -------------------------------------------------------------

  def shell
    return @shell if defined?(@shell)

    @shell = %w[pwsh powershell].find do |exe|
      begin
        _o, st = Open3.capture2e(exe, '-NoProfile', '-Command', 'exit 0')
        st.success?
      rescue SystemCallError
        false
      end
    end
  end

  # `years` = rocniky `SketchUp YYYY/SketchUp/Plugins` v docasnom APPDATA.
  def resolve(years, override: nil)
    root = File.realpath(Dir.mktmpdir('nx-h11b-ps-'))
    begin
      appdata = File.join(root, 'appdata')
      FileUtils.mkdir_p(appdata)
      years.each { |y| FileUtils.mkdir_p(File.join(appdata, 'SketchUp', "SketchUp #{y}", 'SketchUp', 'Plugins')) }
      env = { 'APPDATA' => appdata, 'NOXUN_INSTALL_DEST' => nil }
      override_path = override ? File.join(root, override) : nil
      env['NOXUN_INSTALL_DEST'] = override_path if override_path
      script = File.join(NxTest::ROOT, 'INSTALL_noxun_engine.ps1')
      out, st = Open3.capture2e(env, shell, '-NoProfile', '-ExecutionPolicy', 'Bypass',
                                '-File', script, '-ResolveOnly')
      out = out.force_encoding(Encoding::UTF_8)
      { 'raw' => out, 'exit' => st.exitstatus,
        'dest' => out[/^NOXUN_DEST=(.*?)\r?$/, 1].to_s,
        'override_exists' => override_path ? File.exist?(override_path) : nil,
        'appdata' => appdata, 'override_path' => override_path }
    ensure
      FileUtils.rm_rf(root)
    end
  end

  def norm(path)
    path.to_s.tr('\\', '/').downcase
  end
end

# --- loader: starsi SketchUp --------------------------------------------------

NxTest.test('H11b: SketchUp 2024 a 2025 = plugin sa nenacita, jedna hlaska, ani lease, ani zamok') do
  NxTest.skip!('boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  { '24.0.594' => '2024', '25.0.660' => '2025' }.each do |ver, year|
    out = NxH11b.boot(NxH11b.su(ver))
    NxTest.assert_equal('unsupported', out['status'], "#{ver}: #{out['raw']}")
    NxTest.refute(out['registered'], "#{ver}: plugin sa nesmie zaregistrovat")
    NxTest.assert_equal(1, out['messages'], "#{ver}: ma byt PRAVE JEDNA hlaska")
    NxTest.assert(out['message'].include?('SketchUp 2026 alebo novší'), "#{ver}: hlaska nespomina minimum: #{out['message']}")
    NxTest.assert(out['message'].include?(ver) && out['message'].include?(year),
                  "#{ver}: hlaska nespomina zistenu verziu: #{out['message']}")
    NxTest.refute(out['lease'], "#{ver}: nepodporovany SketchUp si zapisal lease (gate az po recovery?)")
    NxTest.refute(out['lock'], "#{ver}: nepodporovany SketchUp siahol na zamok aktualizacie")
  end
end

# --- loader: podporovany SketchUp ----------------------------------------------

NxTest.test('H11b: SketchUp 26.0.429, 26.2.243 a 27.0.1 sa nacitaju ako doteraz') do
  NxTest.skip!('boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  %w[26.0.429 26.2.243 27.0.1].each do |ver|
    out = NxH11b.boot(NxH11b.su(ver))
    NxTest.assert_equal('idle', out['status'], "#{ver}: #{out['raw']}")
    NxTest.assert(out['registered'], "#{ver}: plugin sa musi zaregistrovat")
    NxTest.assert_equal(0, out['messages'], "#{ver}: ziadna hlaska")
    NxTest.assert(out['lease'], "#{ver}: podporovany SketchUp si zapisuje lease ako doteraz")
    NxTest.refute(NxH11b.unknown_logged?(out), "#{ver}: verzia je znama, log o neznamej verzii nepatri")
  end
end

# --- loader: fail-open ---------------------------------------------------------

NxTest.test('H11b: neznama verzia = fail-open (nacita sa) + riadok v konzole') do
  NxTest.skip!('boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  {
    'bez metod verzie' => '',
    'retazec abc' => "def self.version; 'abc'; end",
    'prazdny retazec' => "def self.version; ''; end",
    'retazec vyhodi' => "def self.version; raise 'sonda'; end",
    'oba zdroje vyhodia' => "def self.version; raise 'a'; end\n  def self.version_number; raise 'b'; end",
    'cislo 0 a retazec nic' => "def self.version_number; 0; end",
    # Iny format cisla v buducej verzii: zdroje si odporuju => nevieme => nacitat.
    'zdroje si odporuju' => "def self.version; '27.0.1'; end\n  def self.version_number; 270_000_001; end"
  }.each do |name, code|
    out = NxH11b.boot(code)
    NxTest.assert_equal('idle', out['status'], "#{name}: #{out['raw']}")
    NxTest.assert(out['registered'], "#{name}: pri neznamej verzii sa plugin musi nacitat (fail-open)")
    NxTest.assert_equal(0, out['messages'], "#{name}: ziadna hlaska")
    NxTest.assert(NxH11b.unknown_logged?(out), "#{name}: chyba riadok o nezistenej verzii")
  end
end

NxTest.test('H11b: ciselne version_number je hlavny zdroj, retazec len zaloha (N6)') do
  NxTest.skip!('boot potrebuje samostatny Ruby proces') unless NxTest.headless?
  # Len cislo (retazec chyba): 2024 => odmietnut, 2026 => nacitat.
  only24 = NxH11b.boot('def self.version_number; 2400000594; end')
  NxTest.assert_equal('unsupported', only24['status'], only24['raw'])
  only26 = NxH11b.boot('def self.version_number; 2600000429; end')
  NxTest.assert_equal('idle', only26['status'], only26['raw'])
  NxTest.refute(NxH11b.unknown_logged?(only26), 'samotne cislo je znama verzia')
  # Cislo zlyha => zaloha retazec.
  fall = NxH11b.boot("def self.version; '24.0.594'; end\n  def self.version_number; raise 'sonda'; end")
  NxTest.assert_equal('unsupported', fall['status'], fall['raw'])
  NxTest.refute(fall['registered'])
end

# --- staticke strazcovia --------------------------------------------------------

NxTest.test('H11b: kontrola minima zije MIMO module Boot a bezi PRED recovery') do
  src = NxH11b::LOADER_TEXT
  boot_code = src[/module Boot\b.*?\n    end\n/m].to_s.lines.map { |l| l.sub(/#.*$/, '') }.join
  NxTest.refute(boot_code.empty?, 'recovery sekcia sa v loaderi nenasla')
  NxTest.refute(boot_code.include?('version_number') || boot_code.include?('SketchupMinimum'),
                'kontrola minima nesmie byt vo vnutri module Boot (ta nesmie volat SketchUp API)')
  NxTest.assert(src =~ /^    MIN_SKETCHUP_MAJOR = 26$/, 'loader musi niest MIN_SKETCHUP_MAJOR = 26')
  check_at = src.index('Noxun::Engine::SketchupMinimum.check')
  recover_at = src.index('Noxun::Engine::Boot.recover!(')
  NxTest.assert(check_at && recover_at && check_at < recover_at, 'kontrola minima musi bezat PRED recovery')
  # Instalator a loader hovoria o tom istom minime.
  ps1 = File.binread(File.join(NxTest::ROOT, 'INSTALL_noxun_engine.ps1')).force_encoding(Encoding::UTF_8)
  NxTest.assert(ps1 =~ /^\$MinSketchupYear = 2026$/, 'instalator a loader maju rozne minimum')
end

NxTest.test('H11b: v prekrytiach nie su verzijne poistky spred SketchUpu 2023') do
  %w[edge_check grain_check direction_check hover_edge].each do |name|
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', "#{name}.rb"), encoding: 'UTF-8')
    %w[respond_to?(:enabled?) respond_to?(:enabled=) respond_to?(:overlay_id)].each do |guard|
      NxTest.refute(src.include?(guard), "#{name}.rb stale obsahuje #{guard} (minimum je 2026)")
    end
  end
end

# --- instalator ------------------------------------------------------------------

NxTest.test('H11b: instalator -ResolveOnly vyberie 2026, inak najnovsi >= 2026, starsie odmietne') do
  NxTest.skip!('potrebuje samostatny proces PowerShellu') unless NxTest.headless?
  NxTest.skip!('pwsh ani powershell nie je k dispozicii') unless NxH11b.shell

  r = NxH11b.resolve([2024, 2026, 2027])
  NxTest.assert_equal(0, r['exit'], r['raw'])
  NxTest.assert(NxH11b.norm(r['dest']).end_with?('sketchup 2026/sketchup/plugins'),
                "{2024, 2026, 2027} ma vybrat 2026: #{r['raw']}")

  r = NxH11b.resolve([2024, 2027])
  NxTest.assert_equal(0, r['exit'], r['raw'])
  NxTest.assert(NxH11b.norm(r['dest']).end_with?('sketchup 2027/sketchup/plugins'),
                "{2024, 2027} ma vybrat 2027: #{r['raw']}")

  r = NxH11b.resolve([2022, 2024])
  NxTest.assert_equal(1, r['exit'], "{2022, 2024} musi skoncit chybou: #{r['raw']}")
  NxTest.assert(r['raw'].include?('Noxun Engine potrebuje SketchUp 2026 alebo novsi'), r['raw'])
  NxTest.assert(r['dest'].empty?, 'pri chybe sa ciel nevypisuje')

  r = NxH11b.resolve([])
  NxTest.assert_equal(1, r['exit'], "prazdne APPDATA musi skoncit chybou: #{r['raw']}")
  NxTest.assert(r['raw'].include?('Noxun Engine potrebuje SketchUp 2026 alebo novsi'), r['raw'])
end

NxTest.test('H11b: instalator NOXUN_INSTALL_DEST = presne ta cesta a resolve nic nevytvori (D4)') do
  NxTest.skip!('potrebuje samostatny proces PowerShellu') unless NxTest.headless?
  NxTest.skip!('pwsh ani powershell nie je k dispozicii') unless NxH11b.shell

  r = NxH11b.resolve([2022], override: 'neexistuje/Plugins')
  NxTest.assert_equal(0, r['exit'], r['raw'])
  NxTest.assert_equal(NxH11b.norm(r['override_path']), NxH11b.norm(r['dest']),
                      "NOXUN_INSTALL_DEST ma vyhrat bez kontroly rocnika: #{r['raw']}")
  NxTest.assert(r['raw'].include?('NOXUN_DEST_OVERRIDE=1'), r['raw'])
  NxTest.assert_equal(false, r['override_exists'], '-ResolveOnly vytvoril priecinok z NOXUN_INSTALL_DEST')
end
