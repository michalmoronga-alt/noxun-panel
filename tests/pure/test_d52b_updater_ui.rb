# frozen_string_literal: true
# Testy D-52b: UI VRSTVA AKTUALIZATORA (sekcia „O plugine" v Studiu).
#
# Jadro (recovery, zamok, lease, manifest, swap, latch) ma vlastnu sadu
# (`test_d52a_updater.rb`). Tato sada strazi to, co k nemu pridala UI vrstva —
# a to su presne tri veci, ktore sa klikanim overit NEDAJU:
#
#   1. ASYNCHRONNA KONTROLA VERZIE. Zdroj je typicky sietovy share: odpojeny
#      disk vie „viset" desiatky sekund. Kontrola preto bezi vo vlakne
#      s deadline a hlavne vlakno na nu NECAKA. Klikanim sa to overi az vtedy,
#      ked niekomu zamrzne SketchUp — a vtedy uz je neskoro.
#   2. TOKEN. Odpoved, ktora dobehne po deadline, po zmene priecinka alebo do
#      INEJ instancie okna, sa MUSI zahodit. Inak by sekcia ukazala verziu
#      celkom ineho priecinka a pouzivatel by aktualizoval „naslepo".
#   3. BARIERA PRED SWAPOM. CEF drzi otvorene subory z `ui/`, takze rename
#      priecinka by na Windows zlyhal. Swap smie zacat AZ VTEDY, ked dobehne
#      `set_on_closed` OBOCH okien — nie ked prestanu byt viditelne.
#      A vysledok ide VYHRADNE natívne: okna su vtedy zavrete a po uspechu by
#      nove HTML bezalo proti starym callbackom.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. bariera preskocena (`handle_updater_apply` vola `updater_run_apply`
#      priamo) -> „D-52b: bariera — swap NEZACNE, kym su okna otvorene";
#   2. vysledok cez CEF (`set_status` namiesto `UI.messagebox`)
#      -> „D-52b: vysledok aktualizacie ide VYHRADNE natívne" (+ guard nad zdrojom);
#   3. token sa neoveruje (neskora odpoved sa nasadi)
#      -> „D-52b: NESKORA odpoved sa zahadzuje" a „…z INEHO priecinka…";
#   4. deadline chyba (poll caka donekonecna)
#      -> „D-52b: visiace I/O neblokuje a po deadline pride hlaska";
#   5. check bezi zo `settings_payload`
#      -> „D-52b: payload sekcie NESIAHA na zdroj";
#   6. (#278 P1) `updater_apply_mismatch` vzdy pusti
#      -> „swap nad CUDZO ZMENENOU cestou sa ODMIETNE" + „…BEZ kontroly…";
#   7. (#278 P2) hlaska sa nevetvi podla restart latchu
#      -> „pri ZLYHANOM rollbacku hlaska NEtvrdi „nezmenený"";
#   8. (#278 P2) evidencia beziacich dotazov zrusena (kazdy check spawne vlakno)
#      -> „tri kontroly TEJ ISTEJ visiacej cesty = JEDNO vlakno";
#   9. (#278 P2) zdiela sa aj HOTOVY beh (vysledok sa recykluje)
#      -> „DOBEHNUTY beh sa nezdiela — dalsia kontrola cita NANOVO".
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog') if NxTest.headless?

D52B_SUP_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog.rb'),
                        encoding: 'UTF-8')
D52B_ABOUT_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'about.js'),
                          encoding: 'UTF-8')
D52B_SETTINGS_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio_settings.js'),
                             encoding: 'UTF-8')
D52B_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')

module NxD52b
  E = Noxun::Engine
  SD = E::SupplierSettingsDialog

  module_function

  # Vlakno, ktore NIC NESPUSTI — „visiace I/O". Telo si test spusti sam
  # (alebo nikdy, ked skuma deadline).
  class FakeThread
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def run_now!
      @body.call
    end
  end

  # Prostredie sekcie: fake hodiny, fake vlakno, fronta timerov a odchytene
  # natívne hlasky. Vracia handle, cez ktory test posuva cas a spusta timery.
  class Env
    attr_reader :sent, :notices, :pending, :threads
    attr_accessor :now

    def initialize
      @sent = []
      @notices = []
      @pending = []
      @threads = []
      @now = 100.0
      @sink = ->(script) { @sent << script.to_s }
    end

    def sink
      @sink
    end

    def install!
      SD.test_clock = -> { @now }
      SD.test_spawn = lambda do |blk|
        t = FakeThread.new(blk)
        @threads << t
        t
      end
      SD.test_schedule = ->(sec, blk) { @pending << [sec, blk] }
      SD.test_notify = ->(text) { @notices << text.to_s }
      # ASYNCHRONNA odpoved uz NEMA sink (`with_client` zije presne jeden
      # synchronny callback) — ide kanalom okna. Tu je jeho odchytavac; bez
      # neho by sada merala len synchronnu cast a token by sa nedal overit.
      sink = @sink
      E::StudioDialog.singleton_class.send(:alias_method, :nx_d52b_orig_sjs, :settings_js)
      E::StudioDialog.singleton_class.send(:define_method, :settings_js) do |script|
        sink.call(script)
        true
      end
      # `Engine.plugin_dir` zije v `main.rb` (SketchUp) — headless ho nahradime
      # cestou, ktora sa nikdy nepouzije (`Updater.apply!` je stubnuty).
      return if E.respond_to?(:plugin_dir)

      @fake_plugin_dir = true
      E.singleton_class.send(:define_method, :plugin_dir) { 'C:/fake/Plugins/noxun_engine' }
    end

    def uninstall!
      SD.test_clock = nil
      SD.test_spawn = nil
      SD.test_schedule = nil
      SD.test_notify = nil
      sc = E::StudioDialog.singleton_class
      sc.send(:remove_method, :settings_js)
      sc.send(:alias_method, :settings_js, :nx_d52b_orig_sjs)
      sc.send(:remove_method, :nx_d52b_orig_sjs)
      E.singleton_class.send(:remove_method, :plugin_dir) if @fake_plugin_dir
      @fake_plugin_dir = false
    end

    # Jeden tik timera (naposledy naplanovany callback).
    def tick!
      job = @pending.shift
      return false unless job

      job[1].call
      true
    end

    # Posledny `SS.updater(...)` ako Hash — to, co naozaj prislo do sekcie.
    def last_updater
      raw = @sent.reverse.find { |s| s.start_with?('SS.updater(') }
      return nil unless raw

      JSON.parse(raw.sub(/\ASS\.updater\(/, '').sub(/\)\z/, ''))
    end

    def statuses
      @sent.select { |s| s.start_with?('SS.setStatus(') }
    end
  end

  def with_env
    env = Env.new
    env.install!
    prev_dlg = E::StudioDialog.instance_variable_get(:@dialog)
    E::StudioDialog.instance_variable_set(:@dialog, nil)
    # Doklad o kontrole ani evidencia vlakien nesmu pretiect medzi testami.
    SD.instance_variable_set(:@updater_check_ok, nil)
    SD.instance_variable_set(:@updater_workers, nil)
    begin
      yield env
    ensure
      env.uninstall!
      E::StudioDialog.instance_variable_set(:@dialog, prev_dlg)
    end
  end

  # Stub `Updater.check` — sada nesmie siahat na disk ani na sietovy share.
  def with_check(result)
    calls = []
    sc = E::Updater.singleton_class
    sc.send(:alias_method, :nx_d52b_orig_check, :check)
    sc.send(:define_method, :check) do |dir, current|
      calls << [dir, current]
      result.is_a?(Proc) ? result.call(dir, current) : result
    end
    yield calls
  ensure
    sc.send(:remove_method, :check)
    sc.send(:alias_method, :check, :nx_d52b_orig_check)
    sc.send(:remove_method, :nx_d52b_orig_check)
  end

  # Stub `Updater.apply!` — NIKDY sa v tejto sade nesmie dotknut disku.
  def with_apply(result)
    calls = []
    sc = E::Updater.singleton_class
    sc.send(:alias_method, :nx_d52b_orig_apply, :apply!)
    sc.send(:define_method, :apply!) do |dir, plugin_dir|
      calls << [dir, plugin_dir]
      # `Proc` = scenar s VEDLAJSIM UCINKOM (napr. zlyhany rollback, ktory
      # zapina restart latch a az potom vyhodi `Refused`).
      next result.call(dir, plugin_dir) if result.is_a?(Proc)
      raise result if result.is_a?(Exception)

      result
    end
    yield calls
  ensure
    sc.send(:remove_method, :apply!)
    sc.send(:alias_method, :apply!, :nx_d52b_orig_apply)
    sc.send(:remove_method, :nx_d52b_orig_apply)
  end

  # Ulozena cesta bez dotyku %APPDATA%.
  def with_source_dir(dir)
    sc = E::Updater.singleton_class
    sc.send(:alias_method, :nx_d52b_orig_src, :source_dir)
    sc.send(:define_method, :source_dir) { dir }
    yield
  ensure
    sc.send(:remove_method, :source_dir)
    sc.send(:alias_method, :source_dir, :nx_d52b_orig_src)
    sc.send(:remove_method, :nx_d52b_orig_src)
  end

  # DOKLAD O USPESNEJ KONTROLE (Codex #278 P1). Bez neho `updater_apply`
  # odmietne — server aktualizuje LEN nad tym, co uzivatel naozaj videl
  # skontrolovane. Vracia payload v tvare, aky posiela klient.
  def arm_check!(dir, state = 'newer')
    token = SD.instance_variable_get(:@updater_seq).to_i + 1
    SD.instance_variable_set(:@updater_seq, token)
    SD.instance_variable_set(:@updater_dir, dir)
    SD.instance_variable_set(:@updater_check_ok,
                             { 'dir' => dir, 'token' => token, 'state' => state,
                               'dlg' => SD.studio_token })
    { 'checked_path' => dir, 'check_token' => token }.to_json
  end

  # Fake okno: `close` iba zaznamena. `set_on_closed` (a s nim vynulovanie
  # referencie) simuluje test SAM — presne o to v bariere ide.
  class FakeDialog
    attr_reader :closes

    def initialize
      @closes = 0
    end

    def close
      @closes += 1
    end

    def visible?
      true
    end
  end
end

# --- 1) KONTRAKT SEKCIE ------------------------------------------------------

NxTest.test('D-52b: whitelist sekcie pozna PRESNE tri akcie updatera') do
  actions = Noxun::Engine::SupplierSettingsDialog::SECTION_ACTIONS
  NxTest.assert_equal(%w[ss_save ss_reload updater_check updater_set_dir updater_apply], actions,
                      'presna rovnost — klient posiela LEN meno, co sa smie zavolat rozhoduje SERVER')
  NxTest.assert(actions.frozen?, 'zoznam je uzavrety')
end

NxTest.test('D-52b: neznama akcia updatera sa ODMIETNE') do
  NxD52b.with_env do |env|
    Noxun::Engine::SupplierSettingsDialog.dispatch('updater_run', '{}', env.sink)
    NxTest.assert(env.sent.any? { |s| s.include?('Neznáma akcia') }, 'whitelist plati aj pre `updater_*`')
  end
end

NxTest.test('D-52b: payload sekcie NESIAHA na zdroj (check je EXPLICITNA akcia)') do
  NxD52b.with_check('ok' => true, 'state' => 'newer', 'available' => '9.9.9') do |calls|
    NxD52b.with_source_dir('X:/dist') do
      info = Noxun::Engine::SupplierSettingsDialog.about_info
      NxTest.assert_equal([], calls,
                          'plny push chodi pri KAZDEJ zmene modelu — nesmie citat zo sietoveho share')
      NxTest.assert(info['updater'].is_a?(Hash), 'ale stav updatera v payloade JE')
      NxTest.assert_equal('X:/dist', info['updater']['source_dir'], 'ulozena cesta (lokalny %APPDATA%)')
      NxTest.assert_equal(Noxun::Engine::VERSION.to_s, info['updater']['current'], 'aj beziaca verzia')
      NxTest.assert(info['updater'].key?('locked'), 'a stav restart latchu')
    end
  end
end

# --- 2) ASYNCHRONNY CHECK: visiace I/O, deadline, token ----------------------

NxTest.test('D-52b: visiace I/O NEBLOKUJE a po deadline pride hlaska s cestou') do
  NxD52b.with_env do |env|
    NxD52b.with_check(->(_d, _c) { raise 'test: vlakno sa nikdy nespusti' }) do |_calls|
      NxD52b.with_source_dir('X:/hanging') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_check', '{}', env.sink)

        # Hlavne vlakno sa VRATILO — a to je cely zmysel: nic sa necaka.
        NxTest.assert_equal('checking', env.last_updater['state'], 'sekcia hned povie, ze kontroluje')
        NxTest.assert_equal(1, env.threads.length, 'citanie zdroja bezi vo VLAKNE')
        NxTest.assert_equal(1, env.pending.length, 'a vysledok si vypytal TIMER (nie cakanie)')

        # Vlakno „visi" — kazdy tik pred deadline len prearmuje poll.
        env.now += 1.0
        env.tick!
        NxTest.assert_equal('checking', env.last_updater['state'], 'pred deadline sa nic nemeni')
        NxTest.assert_equal(1, env.pending.length, 'poll sa prearmoval')

        env.now += 10.0
        env.tick!
        state = env.last_updater
        NxTest.assert_equal('error', state['state'], 'po deadline je to CHYBA, nie ticho')
        NxTest.assert(state['reason'].include?('X:/hanging'), "hlaska nesie CESTU: #{state['reason']}")
        NxTest.assert(state['reason'].include?('neodpovedal'), 'aj dovod')
        NxTest.assert_equal([], env.pending, 'a poll uz nepokracuje')
      end
    end
  end
end

NxTest.test('D-52b: hotove vlakno doruci vysledok checku do sekcie') do
  NxD52b.with_env do |env|
    NxD52b.with_check('ok' => true, 'state' => 'newer', 'current' => '0.9.10',
                      'available' => '0.9.11', 'reason' => '') do |calls|
      NxD52b.with_source_dir('X:/dist') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_check', '{}', env.sink)
        env.threads.first.run_now! # vlakno dobehlo
        env.tick!
        state = env.last_updater
        NxTest.assert_equal('newer', state['state'], 'trojstav ide zo zdielaneho jadra (Updater.classify)')
        NxTest.assert_equal('0.9.11', state['available'], 'aj dostupna verzia')
        NxTest.assert_equal('X:/dist', state['source_dir'], 'a priecinok, ktoreho sa vysledok tyka')
        NxTest.assert_equal([['X:/dist', Noxun::Engine::VERSION.to_s]], calls,
                            'jadro dostalo ULOZENU cestu a BEZIACU verziu')
      end
    end
  end
end

NxTest.test('D-52b: NESKORA odpoved sa zahadzuje (token = sekvencia)') do
  NxD52b.with_env do |env|
    NxD52b.with_source_dir('X:/dist') do
      sd = Noxun::Engine::SupplierSettingsDialog
      sd.instance_variable_set(:@updater_seq, 7)
      sd.instance_variable_set(:@updater_dir, 'X:/dist')
      stale = { 'seq' => 6, 'dir' => 'X:/dist', 'dlg' => nil } # starsi dotaz
      env.sent.clear
      sd.poll_updater_check(stale, { 'done' => true, 'result' => { 'ok' => true, 'state' => 'newer' } },
                            env.now + 10)
      NxTest.assert_equal([], env.sent, 'odpoved na PREKONANY dotaz sa do sekcie nedostane')

      fresh = { 'seq' => 7, 'dir' => 'X:/dist', 'dlg' => nil }
      sd.poll_updater_check(fresh, { 'done' => true, 'result' => { 'ok' => true, 'state' => 'same' } },
                            env.now + 10)
      NxTest.assert_equal('same', env.last_updater['state'], 'aktualna odpoved prejde')
    end
  end
end

NxTest.test('D-52b: odpoved z INEHO priecinka a do INEJ instancie okna sa zahadzuje') do
  NxD52b.with_env do |env|
    NxD52b.with_source_dir('Y:/ine') do
      sd = Noxun::Engine::SupplierSettingsDialog
      sd.instance_variable_set(:@updater_seq, 3)
      sd.instance_variable_set(:@updater_dir, 'Y:/ine')
      done = { 'done' => true, 'result' => { 'ok' => true, 'state' => 'newer', 'available' => '9.9.9' } }

      env.sent.clear
      sd.poll_updater_check({ 'seq' => 3, 'dir' => 'X:/stara', 'dlg' => nil }, done, env.now + 10)
      NxTest.assert_equal([], env.sent, 'odpoved o INOM priecinku by klamala o tom, co sa nasadi')

      # Okno sa medzitym zavrelo a otvorilo — token nesie identitu INSTANCIE.
      Noxun::Engine::StudioDialog.instance_variable_set(:@dialog, NxD52b::FakeDialog.new)
      sd.poll_updater_check({ 'seq' => 3, 'dir' => 'Y:/ine', 'dlg' => nil }, done, env.now + 10)
      NxTest.assert_equal([], env.sent, 'ani odpoved patriaca ZANIKNUTEJ instancii okna')
      Noxun::Engine::StudioDialog.instance_variable_set(:@dialog, nil)
    end
  end
end

NxTest.test('D-52b: prazdna cesta check NESPUSTA (nie je co citat)') do
  NxD52b.with_env do |env|
    NxD52b.with_check('ok' => true, 'state' => 'newer') do |calls|
      NxD52b.with_source_dir('') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_check', '{}', env.sink)
        NxTest.assert_equal([], calls, 'jadro sa nevola')
        NxTest.assert_equal([], env.threads, 'ziadne vlakno')
        NxTest.assert_equal('idle', env.last_updater['state'], 'sekcia si vypyta cestu')
      end
    end
  end
end

# --- 3) BARIERA PRED SWAPOM --------------------------------------------------

NxTest.test('D-52b: bariera — swap NEZACNE, kym su okna otvorene') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true, 'state' => 'done', 'from' => '0.9.10', 'to' => '0.9.11',
                      'note' => '') do |calls|
      NxD52b.with_source_dir('X:/dist') do
        dlg = NxD52b::FakeDialog.new
        Noxun::Engine::StudioDialog.instance_variable_set(:@dialog, dlg)
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', NxD52b.arm_check!('X:/dist'), env.sink)

        NxTest.assert_equal(1, dlg.closes, 'okno dostalo pokyn zavriet sa')
        NxTest.assert_equal([], calls, 'ale swap NEBEZI — `set_on_closed` este nedobehol')
        NxTest.assert_equal(1, env.pending.length, 'caka sa TIMEROM, nikdy blokujuco')

        env.now += 0.2
        env.tick!
        NxTest.assert_equal([], calls, 'kym referencia okna zije, swap sa nespusti')

        # `set_on_closed` dobehol (v produkcii vynuluje referenciu okna).
        Noxun::Engine::StudioDialog.instance_variable_set(:@dialog, nil)
        env.now += 0.2
        env.tick!
        NxTest.assert_equal(1, calls.length, 'AZ TERAZ sa spusti swap')
        NxTest.assert_equal('X:/dist', calls.first.first, 'a to z ulozeneho priecinka')
      end
    end
  end
end

NxTest.test('D-52b: nezavrete okna po limite = ZRUSENIE s natívnou hlaskou') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true, 'to' => '0.9.11', 'note' => '') do |calls|
      NxD52b.with_source_dir('X:/dist') do
        Noxun::Engine::StudioDialog.instance_variable_set(:@dialog, NxD52b::FakeDialog.new)
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', NxD52b.arm_check!('X:/dist'), env.sink)
        6.times do
          env.now += 1.0
          env.tick!
        end
        NxTest.assert_equal([], calls, 'swap sa NIKDY nespustil nad otvorenym oknom')
        NxTest.assert_equal(1, env.notices.length, 'pouzivatel dostal natívnu hlasku')
        NxTest.assert(env.notices.first.include?('NESPUSTILA'), env.notices.first.to_s)
        NxTest.assert(env.notices.first.include?('nič nezmenilo'), 'a vie, ze disk je nedotknuty')
        Noxun::Engine::StudioDialog.instance_variable_set(:@dialog, nil)
      end
    end
  end
end

NxTest.test('D-52b: vysledok aktualizacie ide VYHRADNE natívne') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true, 'state' => 'done', 'from' => '0.9.10', 'to' => '0.9.11',
                      'note' => '') do |_calls|
      NxD52b.with_source_dir('X:/dist') do
        env.sent.clear
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', NxD52b.arm_check!('X:/dist'), env.sink)
        NxTest.assert_equal(1, env.notices.length, 'uspech oznamuje natívna hlaska')
        NxTest.assert(env.notices.first.include?('0.9.11'), 'menuje nasadenu verziu')
        NxTest.assert(env.notices.first.include?('reštartuj'), 'a ziada restart')
        NxTest.refute(env.sent.any? { |s| s.include?('Aktualizované') },
                      'a NIKDY cez CEF — okna su v tom bode zavrete a nove HTML by bezalo ' \
                      'proti starym callbackom')
      end
    end
  end
end

NxTest.test('D-52b: ODMIETNUTIE nesie presny dovod z jadra') do
  NxD52b.with_env do |env|
    refused = Noxun::Engine::Updater::Refused.new('beží ďalšia inštancia SketchUpu (PID 42) — zavri ostatné okná')
    NxD52b.with_apply(refused) do |calls|
      NxD52b.with_source_dir('X:/dist') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', NxD52b.arm_check!('X:/dist'), env.sink)
        NxTest.assert_equal(1, calls.length, 'swap sa pokusil')
        NxTest.assert_equal(1, env.notices.length, 'a odmietnutie je natívna hlaska')
        NxTest.assert(env.notices.first.include?('PID 42'), "presny dovod: #{env.notices.first}")
        NxTest.assert(env.notices.first.include?('nezmenený'), 'a povie, ze plugin ostal nedotknuty')
      end
    end
  end
end

NxTest.test('D-52b: bez zadaneho priecinka sa aktualizacia nespusti') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true) do |calls|
      NxD52b.with_source_dir('') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', '{}', env.sink)
        NxTest.assert_equal([], calls, 'jadro sa nevola')
        NxTest.assert(env.statuses.any? { |s| s.include?('distribučný priečinok') }, 'sekcia povie preco')
      end
    end
  end
end

NxTest.test('D-52b: po uspesnej aktualizacii latch dalsi pokus zastavi') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true) do |calls|
      NxD52b.with_source_dir('X:/dist') do
        Noxun::Engine.restart_required!
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', '{}', env.sink)
        NxTest.assert_equal([], calls, 'druha aktualizacia nad starym Ruby kodom sa NESPUSTI')
        NxTest.assert(env.statuses.any? { |s| s.include?('reštartuj') }, 'sekcia ziada restart')
      ensure
        Noxun::Engine.reset_restart_latch!
      end
    end
  end
end

# --- 3b) DOKLAD O KONTROLE (Codex #278 P1) -----------------------------------

NxTest.test('D-52b (#278 P1): swap nad CUDZO ZMENENOU cestou sa ODMIETNE') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true, 'to' => 'x', 'note' => '') do |calls|
      # Uzivatel skontroloval cestu A a videl „novsia verzia"…
      payload = NxD52b.arm_check!('A:/stara')
      # …ale medzitym DRUHA INSTANCIA ulozila do `updater_settings.json` cestu B.
      NxD52b.with_source_dir('B:/nova') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', payload, env.sink)
        NxTest.assert_equal([], calls,
                            'swap sa NESPUSTIL — inak by potvrdenie menovalo A a nasadilo B')
        NxTest.assert(env.statuses.any? { |s| s.include?('medzitým zmenila') },
                      "sekcia povie, ze treba skontrolovat znova: #{env.statuses.inspect}")
      end
    end
  end
end

NxTest.test('D-52b (#278 P1): swap BEZ kontroly a so STARYM tokenom sa ODMIETNE') do
  NxD52b.with_env do |env|
    NxD52b.with_apply('ok' => true, 'to' => 'x', 'note' => '') do |calls|
      NxD52b.with_source_dir('X:/dist') do
        sd = Noxun::Engine::SupplierSettingsDialog

        # (a) ziadna kontrola — klient si token vymyslel
        sd.instance_variable_set(:@updater_check_ok, nil)
        sd.dispatch('updater_apply', { 'checked_path' => 'X:/dist', 'check_token' => 1 }.to_json, env.sink)
        NxTest.assert_equal([], calls, 'bez ULOZENEHO dokladu o kontrole sa neaktualizuje')

        # (b) doklad je, ale token je z PREKONANEJ kontroly
        NxD52b.arm_check!('X:/dist')
        stale = { 'checked_path' => 'X:/dist', 'check_token' => 0 }.to_json
        sd.dispatch('updater_apply', stale, env.sink)
        NxTest.assert_equal([], calls, 'stary token neprejde')

        # (c) kontrola skoncila stavom `same` — tlacidlo bolo neaktivne, klik
        #     mohol prist len z upraveneho DOM
        NxD52b.arm_check!('X:/dist', 'same')
        ok_payload = { 'checked_path' => 'X:/dist',
                       'check_token' => sd.instance_variable_get(:@updater_check_ok)['token'] }.to_json
        sd.dispatch('updater_apply', ok_payload, env.sink)
        NxTest.assert_equal([], calls, 'server neverí klientovi, ze bola novsia verzia')

        # (d) VSETKO sedi -> prejde (dokaz, ze guard nie je „vzdy odmietni")
        good = NxD52b.arm_check!('X:/dist')
        sd.dispatch('updater_apply', good, env.sink)
        NxTest.assert_equal(1, calls.length, 'zhodny doklad aktualizaciu PUSTI')
      end
    end
  end
end

# --- 3c) ZLYHANY ROLLBACK (Codex #278 P2) ------------------------------------

NxTest.test('D-52b (#278 P2): pri ZLYHANOM rollbacku hlaska NEtvrdi „nezmenený"') do
  NxD52b.with_env do |env|
    # Presne to, co robi `abort_after_move!`, ked sa generaciu vratit NEPODARI:
    # zapne latch, necha artefakty a vyhodi `Refused`.
    boom = lambda do |_src, _dir|
      Noxun::Engine.restart_required!
      raise Noxun::Engine::Updater::Refused,
            'loader sa nedá vymeniť (Errno::EACCES) a vrátenie zmien zlyhalo — REŠTARTUJ SketchUp'
    end
    NxD52b.with_apply(boom) do |calls|
      NxD52b.with_source_dir('X:/dist') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', NxD52b.arm_check!('X:/dist'), env.sink)
        NxTest.assert_equal(1, calls.length, 'swap sa pokusil')
        msg = env.notices.first.to_s
        NxTest.refute(msg.include?('nezmenený'),
                      "hlaska nesmie tvrdit, ze plugin ostal nezmeneny: #{msg}")
        NxTest.assert(msg.include?('NEÚPLNÁ'), "priznava neuplnu aktualizaciu: #{msg}")
        NxTest.assert(msg.include?('REŠTARTUJ'), 'a ziada restart (boot recovery generaciu dorovna)')
        NxTest.assert(msg.include?('Errno::EACCES'), 'presny dovod z jadra ostava')
      ensure
        Noxun::Engine.reset_restart_latch!
      end
    end
  end
end

NxTest.test('D-52b (#278 P2): pri USPESNOM rollbacku hlaska „nezmenený" OSTAVA') do
  NxD52b.with_env do |env|
    refused = Noxun::Engine::Updater::Refused.new(
      'priečinok pluginu sa nedá presunúť (Errno::EACCES) — zavri SketchUp a skús znova'
    )
    NxD52b.with_apply(refused) do |_calls|
      NxD52b.with_source_dir('X:/dist') do
        Noxun::Engine.reset_restart_latch!
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_apply', NxD52b.arm_check!('X:/dist'), env.sink)
        msg = env.notices.first.to_s
        NxTest.assert(msg.include?('nezmenený'), "bez latchu je disk naozaj nedotknuty: #{msg}")
        NxTest.refute(msg.include?('NEÚPLNÁ'), 'a o restart sa nepyta zbytocne')
      end
    end
  end
end

# --- 3d) JEDEN BEZIACI DOTAZ NA JEDNU CESTU (Codex #278 P2) ------------------

NxTest.test('D-52b (#278 P2): tri kontroly TEJ ISTEJ visiacej cesty = JEDNO vlakno') do
  NxD52b.with_env do |env|
    NxD52b.with_check(->(_d, _c) { raise 'test: vlakno visi' }) do |_calls|
      NxD52b.with_source_dir('X:/hanging') do
        sd = Noxun::Engine::SupplierSettingsDialog
        3.times { sd.dispatch('updater_check', '{}', env.sink) }
        NxTest.assert_equal(1, env.threads.length,
                            'visiaci beh sa ZDIELA — inak by kazdy navrat do sekcie pridal ' \
                            'dalsie zablokovane vlakno na mrtvu cestu')
        NxTest.assert_equal('checking', env.last_updater['state'], 'a sekcia stale hlasi kontrolu')
      end

      # INA cesta je INY beh — zdielat sa smie len rovnaka.
      NxD52b.with_source_dir('Y:/ina') do
        Noxun::Engine::SupplierSettingsDialog.dispatch('updater_check', '{}', env.sink)
        NxTest.assert_equal(2, env.threads.length, 'druha cesta dostane vlastne vlakno')
      end
    end
  end
end

NxTest.test('D-52b (#278 P2): DOBEHNUTY beh sa nezdiela — dalsia kontrola cita NANOVO') do
  NxD52b.with_env do |env|
    NxD52b.with_check('ok' => true, 'state' => 'newer', 'available' => '9.9.9') do |calls|
      NxD52b.with_source_dir('X:/dist') do
        sd = Noxun::Engine::SupplierSettingsDialog
        sd.dispatch('updater_check', '{}', env.sink)
        env.threads.first.run_now!
        env.tick!
        NxTest.assert_equal('newer', env.last_updater['state'], 'prva kontrola dobehla')

        sd.dispatch('updater_check', '{}', env.sink)
        NxTest.assert_equal(2, env.threads.length,
                            'share sa mohol medzitym zmenit — hotovy vysledok sa NERECYKLUJE')
        env.threads.last.run_now!
        NxTest.assert_equal(2, calls.length, 'a zdroj sa naozaj cita NANOVO')
      end
    end
  end
end

# --- 4) ULOZENIE CESTY -------------------------------------------------------

NxTest.test('D-52b: ulozenie cesty ide VLASTNYM storom a rovno spusti check') do
  NxTest.skip!('zapisuje do %APPDATA% — v SketchUpe je zdielana so zivym pluginom') unless NxTest.headless?

  NxD52b.with_env do |env|
    NxD52b.with_check('ok' => true, 'state' => 'same', 'available' => '0.9.10') do |calls|
      Noxun::Engine::SupplierSettingsDialog.dispatch(
        'updater_set_dir', { 'source_dir' => 'C:\\balik\\noxun\\' }.to_json, env.sink
      )
      NxTest.assert_equal('C:/balik/noxun', Noxun::Engine::Updater.source_dir,
                          'cesta sa ulozila a NORMALIZOVALA (lomitka, koncovy oddelovac)')
      saved = env.sent.map { |s| s }.find { |s| s.include?('"saved":true') }
      NxTest.assert(saved, 'klient dostal POTVRDENIE — az tam smie zahodit rozpisanu cestu')
      NxTest.assert(saved.include?('C:/balik/noxun'), 'aj s tvarom, ktory je naozaj ulozeny')
      env.threads.first.run_now!
      env.tick!
      NxTest.assert_equal([['C:/balik/noxun', Noxun::Engine::VERSION.to_s]], calls,
                          'ulozenie rovno overi verziu v NOVOM priecinku')
      Noxun::Engine::Updater.set_source_dir('')
    end
  end
end

# --- 5) GUARDY NAD ZDROJOM (mutacie) -----------------------------------------

NxTest.test('D-52b: bariera je JEDINA cesta k swapu (guard nad zdrojom)') do
  body = D52B_SUP_RB[/def handle_updater_apply.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, '`handle_updater_apply` sa v zdrojaku nenasla — uprav guard test')
  NxTest.assert(body.include?('close_plugin_dialogs'), 'najprv sa zavru obe okna')
  NxTest.assert(body.include?('await_dialogs_closed'), 'a potom sa CAKA na ich `set_on_closed`')
  NxTest.refute(body.include?('updater_run_apply'),
                'swap sa NIKDY nespusta priamo z akcie — CEF by drzal subory z `ui/`')

  await = D52B_SUP_RB[/def await_dialogs_closed.*?\n        end\n/m].to_s
  NxTest.assert(await.include?('dialogs_closed?'), 'bariera sa pyta na ZATVORENE okna')
  closed = D52B_SUP_RB[/def dialogs_closed\?.*?\n        end\n/m].to_s
  NxTest.assert(closed.include?('dialog_closed?'),
                'a to cez `dialog_closed?` — `dialog_alive?` hovori len o VIDITELNOSTI')
  %w[Panel StudioDialog].each do |mod|
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui',
                              mod == 'Panel' ? 'panel.rb' : 'studio_dialog.rb'), encoding: 'UTF-8')
    NxTest.assert(src.include?('def dialog_closed?'), "#{mod} ma predikat bariery")
    NxTest.assert(src[/def dialog_closed\?.*?\n        end\n/m].to_s.include?('@dialog.nil?'),
                  "#{mod}.dialog_closed? cita DOBEHNUTY `set_on_closed`, nie viditelnost")
  end
end

NxTest.test('D-52b: vysledok swapu sa do CEF nedostane (guard nad zdrojom)') do
  body = D52B_SUP_RB[/def updater_run_apply.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, '`updater_run_apply` sa v zdrojaku nenasla — uprav guard test')
  NxTest.refute(body.include?('set_status'), 'vysledok nikdy nejde do stavoveho riadku okna')
  NxTest.refute(body.include?('push_updater'), 'ani do sekcie')
  NxTest.refute(body.include?('js('), 'ani inym CEF kanalom')
  NxTest.assert(body.scan(/updater_message/).length >= 3,
                'vsetky tri vetvy (uspech, odmietnutie, vynimka) koncia natívnou hlaskou')
  msg = D52B_SUP_RB[/def updater_message.*?\n        end\n/m].to_s
  NxTest.assert(msg.include?('::UI.messagebox'), 'a natívna hlaska je `UI.messagebox`')
end

NxTest.test('D-52b: vlakno robi LEN suborove I/O') do
  # Vlakno spusta `updater_worker` (evidencia JEDNEHO behu na cestu, #278 P2).
  body = D52B_SUP_RB[/def updater_worker.*?\n        end\n/m].to_s
  thread_body = body[/updater_spawn do.*?\n          end\n/m].to_s
  NxTest.refute(thread_body.empty?, 'telo vlakna sa nenaslo — uprav guard test')
  NxTest.assert(thread_body.include?('Updater.check'), 'vlakno cita hlavicku loadera zo zdroja')
  %w[Sketchup. ::UI. push_updater js( set_status].each do |forbidden|
    NxTest.refute(thread_body.include?(forbidden),
                  "vo vlakne nesmie byt `#{forbidden}` — do UI sa zapisuje VYHRADNE z timera")
  end
end

NxTest.test('D-52b: updater prvky su LEN v studiovom vstupe „O plugine"') do
  NxTest.assert(D52B_ABOUT_JS.include?('function nxAboutHtml(info, updater)'),
                'zdielany builder dostava stav updatera DRUHYM argumentom')
  NxTest.assert(D52B_ABOUT_JS.include?("(updater ? nxUpdaterHtml(updater) : '')"),
                'a bez neho sa updater NEKRESLI (koliesko Inspectora ho nepoda)')
  bridge = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
  NxTest.assert(bridge.include?("nxAboutFill('cfgAbout'"), 'koliesko plni obsah tym istym builderom')
  NxTest.refute(bridge.include?('updater'), 'a o updateri nevie')
  NxTest.assert(D52B_SETTINGS_JS.include?('nxAboutFill(host, SS_STATE ? SS_STATE.about : null, updMerged())'),
                'sekcia Studia stav updatera PODAVA')

  # F7: vlastny namespace, nikdy `data-ss`.
  NxTest.assert(D52B_ABOUT_JS.include?('data-updater-edit="source_dir"'), 'pole cesty ma vlastny namespace')
  NxTest.refute(D52B_ABOUT_JS.include?('data-ss'), 'a NIE `data-ss` (revizny zamok dodavatela)')

  # D-78: nedostupna akcia je `aria-disabled`, nikdy HTML `disabled`.
  NxTest.assert(D52B_ABOUT_JS.include?("aria-disabled=\"true\""), 'neaktivne tlacidlo je aria-disabled')
  NxTest.refute(D52B_ABOUT_JS.match?(/\sdisabled[\s=>]/), 'HTML `disabled` sa nepouziva')
end

NxTest.test('D-52b: check spusta VSTUP do sekcie — OBA vstupy') do
  # Navigacia aj deep-link: dve miesta v `studio.js`, obe volaju ten isty hook.
  NxTest.assert_equal(2, D52B_STUDIO_JS.scan(/ssOnAboutEnter\(\)/).length,
                      'hook je v OBOCH vstupoch do sekcie (navigacia + deep-link)')
  NxTest.assert(D52B_SETTINGS_JS.include?("updSend('updater_check'"), 'hook posiela explicitny check')
  enter = D52B_SETTINGS_JS[/function ssOnAboutEnter\(\).*?\n  \}/m].to_s
  NxTest.assert(enter.include?('UPD = null'), 'a stary vysledok patril inemu vstupu — zahadza sa')
  NxTest.refute(D52B_SUP_RB[/def settings_payload.*?\n        end\n/m].to_s.include?('updater_check'),
                'payload check NESPUSTA')
end
