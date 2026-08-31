# frozen_string_literal: true
# Testy 1d/R-11: DEGRADOVANY globalny subor (poskodeny primar + platna `.bak`).
#
# CO BOLO ZLE: `JsonFileStore.read_primary_or_backup` pri poskodenom primare
# TICHO precita zalohu. Volajuci nad datami ZALOHY pracoval dalej a jeho
# najblizsi zapis prepisal primar obsahom odvodenym od STARSEJ zalohy —
# vsetko medzi zalohou a poskodenim zmizlo bez slova. Spravny vzor mal len
# `HardwareCatalog.assess!` (GH #99 P1: citaj zo zalohy, ZAPISY zastav);
# pat dalsich volajucich ho nemalo: hardware_sets · hardware_rules ·
# abs_rules · dim_series · supplier_settings.
#
# CO PLATI TERAZ:
#   * `JsonFileStore.degraded?(path)` = primar EXISTUJE a NEPARSUJE sa
#     a zaroven EXISTUJE parsovatelna `.bak`. Chybajuci primar s platnou
#     zalohou degraded NIE JE; poskodeny primar BEZ zalohy tiez nie
#     (spravanie volajucich sa nemeni — samoopravny prvy zapis);
#   * cita PRIAMO z disku, BEZ sekundovej cache `JsonFileStore.read`;
#   * I/O chyba (prava, sharing violation) NIE JE `false` — vyleti ako
#     vynimka a skonci v rescue vetve volajuceho ako NEUSPESNY zapis;
#   * kazdy z 5 volajucich ma bránu na JEDNOM mieste svojej zapisovej cesty
#     a vola ju POD ZAMKOM tesne pred zapisom (cachovany stav nie je dokaz);
#   * CITACIA cesta sa NEMENI — `.bak` recovery ostava;
#   * kniznica setov (hardware_sets) ma degraded ako VLASTNY stav: obsah
#     zalohy sa smie citat AJ pouzit (zmrazenie do projektu, projektove
#     predvolby), zakazane su VYHRADNE zapisy do globalneho SUBORU.
#
# PRIZNANY ZVYSOK: TOCTOU okno voci zapisovatelom, ktori `materials.lock`
# ignoruju (rucny editor, antivirus) — uzavrel by ho az CAS/podpis tesne pred
# rename. Vedome sa neriesi.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'

# Handler panela (rozmerove rady) je UI vrstva — headless ho treba nacitat
# rucne. V SketchUpe je Panel uz ZIVY a stuby nizsie by mu prepisali metody,
# preto tam tato skupina testov skipne.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_settings') if NxTest.headless?

# Simulacia I/O CHYBY (prava, sharing violation) na konkretnej ceste. Patch je
# TRVALY, ale INERTNY — bez nastaveneho `NxR11.boom_path` len deleguje.
# `degraded?` sa nesmie tvarit, ze nedostupny subor je zdravy primar.
unless File.respond_to?(:nx_r11_binread)
  class << File
    alias_method :nx_r11_binread, :binread

    def binread(path, *args)
      boom = defined?(NxR11) ? NxR11.boom_path : nil
      raise Errno::EACCES, path.to_s if boom && File.expand_path(path.to_s) == boom

      nx_r11_binread(path, *args)
    end
  end
end

module NxR11
  E     = Noxun::Engine
  STORE = E::JsonFileStore
  MAT   = E::Materials
  HWS   = E::HardwareSets
  HR    = E::HardwareRules
  ABS   = E::AbsRules
  DIM   = E::DimSeries
  SS    = E::SupplierSettings

  CORRUPT = "{ toto uz nie je JSON\n"

  class << self
    # Cesta, na ktorej `File.binread` simuluje I/O chybu (nie ParserError).
    attr_accessor :boom_path
  end

  module_function

  # --- sandbox ------------------------------------------------------------

  # Vsetkych 5 modulov pocita `dir` cez `Materials.dir`, takze jeden override
  # presmeruje data AJ sidecar zamok do izolovaneho priecinka. Testy sa tak
  # NIKDY nedotknu zivych katalogov pouzivatela (plati aj v SketchUpe, kde
  # helper APPADATA nepresmeruje).
  def with_sandbox
    prev = MAT.test_dir_override
    dir = Dir.mktmpdir('nx-r11-')
    MAT.test_dir_override = dir
    STORE.invalidate
    HWS.reset_library_state!
    yield dir
  ensure
    MAT.test_dir_override = prev
    NxR11.boom_path = nil
    STORE.invalidate
    HWS.reset_library_state!
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  def write_json(path, doc)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, JSON.pretty_generate(doc))
  end

  # Poskodeny primar + PLATNA zaloha (presne degraded stav). Cache sa zhodi,
  # aby citacia cesta sla naozaj na disk.
  def make_degraded(path, backup_doc)
    write_json("#{path}.bak", backup_doc)
    File.binwrite(path, CORRUPT)
    STORE.invalidate(path)
    HWS.reset_library_state!
  end

  # --- specifikacia 5 volajucich -----------------------------------------
  #
  # Kazdy modul: kde zije · co ma byt v zalohe · ako sa cita · ako sa zapisuje
  # · ako vyzera NEUSPECH zapisu · odkial si volajuci vezme DOVOD.
  def specs
    [
      { name: 'abs_rules', path: ABS.path,
        backup: { 'std' => 1, 'seed_version' => ABS::SEED_VERSION,
                  'rules' => { 'shelf' => { 'L1' => 2.0 } } },
        read: -> { ABS.load['shelf'] }, expect: { 'L1' => 2.0 },
        write: -> { ABS.write('shelf' => { 'L1' => 1.0 }) },
        failed: ->(r) { r == false },
        reason: -> { ABS.write_block_reason } },
      { name: 'hardware_rules', path: HR.path,
        backup: { 'std' => 1, 'seed_version' => HR::SEED_VERSION,
                  'rules' => [JSON.parse(JSON.generate(HR::SEED_RULES.first))] },
        read: -> { HR.load.map { |r| r['rule_id'] } },
        expect: [HR::SEED_RULES.first['rule_id']],
        write: -> { HR.write([]) },
        failed: ->(r) { r == false },
        reason: -> { HR.write_block_reason } },
      { name: 'dim_series', path: DIM.path,
        backup: { 'std' => 1, 'series' => { 'sirka' => [123] } },
        read: -> { DIM.get['sirka'] }, expect: [123],
        write: -> { DIM.set('sirka' => [400]) },
        failed: ->(r) { r.nil? },
        reason: -> { DIM.write_block_reason } },
      { name: 'supplier_settings', path: SS.path,
        backup: JSON.parse(JSON.generate(degraded_supplier_doc)),
        read: -> { SS.active['rates']['olep'] }, expect: 9.99,
        write: -> { SS.write(SS.seed_doc) },
        failed: ->(r) { r == false },
        reason: -> { SS.write_block_reason } },
      { name: 'hardware_sets', path: HWS.path,
        backup: { 'std' => 1, 'seed_version' => HWS::SEED_VERSION,
                  'sets' => [JSON.parse(JSON.generate(HWS::SEED_SETS.first))], 'mapping' => {} },
        read: -> { HWS.load['sets'].length }, expect: 1,
        write: -> { HWS.write([], {}) },
        failed: ->(r) { r == false },
        reason: -> { HWS.library_state_reason } }
    ]
  end

  # Nastavenia dodavatela s ROZPOZNATELNOU hodnotou (sadzba olepu 9,99).
  def degraded_supplier_doc
    sup = SS.seed_supplier
    sup['rates']['olep'] = 9.99
    { 'std' => 1, 'seed_version' => SS::SEED_VERSION, 'active' => 'default', 'suppliers' => [sup] }
  end

  # Telo metody zo zdroja (vzor test_r08_zamky) — strukturalne guardy.
  def body(rel, name, indent = 6)
    src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel))
              .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
    src[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end
end

# Minimalny obal panela pre BEHAVIOR test hlasky (headless). V SketchUpe sa
# tato skupina skipne — tam je Panel zivy a stuby by mu prepisali metody.
#
# Stuby sa nasadzuju AZ POCAS testu a hned sa aj vracaju spat: `Panel` je
# reopen modul, ktory si dokladajú aj ine testovacie subory (`sync.rb`
# a spol.), takze staticky definovany stub by sa dal prepisat neskorsim
# requirom — a test by potom meral cudziu implementaciu.
module NxR11PanelStub
  STUBBED = %i[parse push_ui_settings set_status].freeze

  class << self
    attr_accessor :last_status

    def with_panel
      panel = Noxun::Engine::Panel
      orig = {}
      STUBBED.each { |m| orig[m] = panel.method(m) if panel.respond_to?(m) }
      panel.define_singleton_method(:parse) { |payload| JSON.parse(payload.to_s) }
      panel.define_singleton_method(:push_ui_settings) { |refill_editor: false| refill_editor }
      panel.define_singleton_method(:set_status) do |msg, error = false|
        NxR11PanelStub.last_status = [msg, error]
      end
      @last_status = nil
      yield panel
    ensure
      STUBBED.each do |m|
        if orig[m]
          panel.define_singleton_method(m, orig[m])
        else
          panel.singleton_class.send(:remove_method, m)
        end
      end
    end
  end
end

# ==========================================================================
# 1) `JsonFileStore.degraded?` — pravdivostna tabulka
# ==========================================================================

NxTest.test('R-11: degraded? je PRAVE poskodeny primar + platna zaloha') do
  NxR11.with_sandbox do |dir|
    p = File.join(dir, 'x.json')
    store = NxR11::STORE

    NxTest.assert_equal(false, store.degraded?(p), 'ziadny subor: nie je co degradovat')

    File.binwrite("#{p}.bak", '{"a":1}')
    NxTest.assert_equal(false, store.degraded?(p),
                        'CHYBAJUCI primar s platnou zalohou NIE JE degraded (zhodne s HardwareCatalog.assess!)')

    File.binwrite(p, '{"a":2}')
    NxTest.assert_equal(false, store.degraded?(p), 'zdravy primar + zaloha = ok')

    File.binwrite(p, NxR11::CORRUPT)
    NxTest.assert_equal(true, store.degraded?(p), 'poskodeny primar + platna zaloha = DEGRADED')

    File.binwrite(p, '')
    NxTest.assert_equal(true, store.degraded?(p), 'prazdny primar sa neparsuje = degraded')

    File.binwrite("#{p}.bak", NxR11::CORRUPT)
    NxTest.assert_equal(false, store.degraded?(p),
                        'poskodena ZALOHA nie je z coho citat — degraded to nie je')

    FileUtils.rm_f("#{p}.bak")
    NxTest.assert_equal(false, store.degraded?(p),
                        'poskodeny primar BEZ zalohy: spravanie ostava ako na maine (samooprava)')
  end
end

NxTest.test('R-11: degraded? obchadza sekundovu cache JsonFileStore') do
  NxR11.with_sandbox do |dir|
    p = File.join(dir, 'cache.json')
    NxR11::STORE.write(p, 'a' => 1)
    NxR11::STORE.write(p, 'a' => 2) # druhy zapis vyrobi platnu `.bak`
    NxTest.assert_equal({ 'a' => 2 }, NxR11::STORE.read(p), 'cache je NAHRIATA cerstvou hodnotou')

    File.binwrite(p, NxR11::CORRUPT) # iny proces subor poskodil
    NxTest.assert_equal(true, NxR11::STORE.degraded?(p),
                        'brana MUSI vidiet disk — cachovana hodnota spred poskodenia nie je dokaz')
  end
end

NxTest.test('R-11: I/O chyba z degraded? VYLETI (false = „smies zapisat")') do
  NxR11.with_sandbox do |dir|
    p = File.join(dir, 'io.json')
    File.binwrite(p, NxR11::CORRUPT)
    File.binwrite("#{p}.bak", '{"a":1}')
    NxR11.boom_path = File.expand_path(p)
    raised = begin
      NxR11::STORE.degraded?(p)
      nil
    rescue SystemCallError => e
      e
    end
    NxTest.assert(raised.is_a?(Errno::EACCES),
                  "nedostupny subor MUSI vyhodit vynimku, nie vratit false (#{raised.inspect})")
  end
end

NxTest.test('R-11: I/O chyba konci ako NEUSPESNY zapis, nie ako povolenie') do
  NxR11.with_sandbox do
    path = NxR11::ABS.path
    NxR11.make_degraded(path, 'std' => 1, 'seed_version' => NxR11::ABS::SEED_VERSION,
                              'rules' => { 'shelf' => { 'L1' => 2.0 } })
    before = File.binread(path)
    NxR11.boom_path = File.expand_path(path)
    NxTest.assert_equal(false, NxR11::ABS.write('shelf' => { 'L1' => 1.0 }),
                        'vynimka z brany sa v zapisovej ceste zmeni na NEUSPECH')
    NxR11.boom_path = nil
    NxTest.assert_equal(before, File.binread(path), 'a subor sa nedotkne')
  end
end

# ==========================================================================
# 2) Pat volajucich: citanie zo zalohy · zapis odmietnuty · primar nedotknuty
# ==========================================================================

NxR11.specs.each do |raw_spec|
  NxTest.test("R-11: #{raw_spec[:name]} — poskodeny primar + zaloha = citam, nezapisujem") do
    NxR11.with_sandbox do
      spec = NxR11.specs.find { |s| s[:name] == raw_spec[:name] }
      path = spec[:path]
      NxR11.make_degraded(path, spec[:backup])
      corrupt_bytes = File.binread(path)
      backup_bytes = File.binread("#{path}.bak")

      NxTest.assert_equal(spec[:expect], spec[:read].call,
                          "#{spec[:name]}: citanie dalej vracia obsah ZALOHY (.bak recovery sa nemeni)")

      result = spec[:write].call
      NxTest.assert(spec[:failed].call(result),
                    "#{spec[:name]}: zapis MUSI zlyhat (dostal #{result.inspect})")
      NxTest.assert(spec[:reason].call.include?('poškoden'),
                    "#{spec[:name]}: volajuci sa dozvie KONKRETNY dovod (#{spec[:reason].call.inspect})")
      NxTest.assert_equal(corrupt_bytes, File.binread(path),
                          "#{spec[:name]}: primar ostal BAJTOVO nedotknuty")
      NxTest.assert_equal(backup_bytes, File.binread("#{path}.bak"),
                          "#{spec[:name]}: a zaloha tiez (nic sa neprepisalo dokola)")
    end
  end

  NxTest.test("R-11: #{raw_spec[:name]} — po zmazani poskodeneho primaru zapis ZNOVA funguje") do
    NxR11.with_sandbox do
      spec = NxR11.specs.find { |s| s[:name] == raw_spec[:name] }
      path = spec[:path]
      NxR11.make_degraded(path, spec[:backup])
      FileUtils.rm_f(path)
      NxR11::STORE.invalidate(path)
      NxR11::HWS.reset_library_state!

      result = spec[:write].call
      NxTest.assert(!spec[:failed].call(result),
                    "#{spec[:name]}: naprava je zmazat JEDEN subor — potom sa zapisuje normalne")
      NxTest.assert_equal(false, NxR11::STORE.degraded?(path), "#{spec[:name]}: a stav je znova zdravy")
    end
  end

  NxTest.test("R-11: #{raw_spec[:name]} — poskodeny primar BEZ zalohy sa sprava ako na maine") do
    NxR11.with_sandbox do
      spec = NxR11.specs.find { |s| s[:name] == raw_spec[:name] }
      path = spec[:path]
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, NxR11::CORRUPT)
      NxR11::STORE.invalidate(path)
      NxR11::HWS.reset_library_state!

      NxTest.assert_equal(false, NxR11::STORE.degraded?(path), "#{spec[:name]}: bez zalohy to degraded NIE JE")
      result = spec[:write].call
      NxTest.assert(!spec[:failed].call(result),
                    "#{spec[:name]}: prvy zapis subor SAMOOPRAVI (dnesne spravanie sa nemeni)")
    end
  end
end

# ==========================================================================
# 3) hardware_sets — degraded je VLASTNY stav (citat a pouzit ANO, zapisat NIE)
# ==========================================================================

NxTest.test('R-11: degradovana kniznica setov ma stav :degraded (nie :read_only)') do
  NxR11.with_sandbox do
    NxR11.make_degraded(NxR11::HWS.path,
                        'std' => 1, 'seed_version' => NxR11::HWS::SEED_VERSION,
                        'sets' => [JSON.parse(JSON.generate(NxR11::HWS::SEED_SETS.first))],
                        'mapping' => {})
    NxTest.assert_equal(:degraded, NxR11::HWS.library_state, 'vlastny kod dovodu v tej istej matici')
    NxTest.assert_equal(:degraded, NxR11::HWS.library_state_code, 'kod je :degraded')
    NxTest.assert_equal(false, NxR11::HWS.library_read_only?,
                        'read-only NIE — obsah zalohy je POUZITELNY (na rozdiel od kniznice z novsej verzie)')
    NxTest.assert_equal(true, NxR11::HWS.library_write_blocked?, 'ale do SUBORU sa zapisat nesmie')
    NxTest.assert(NxR11::HWS.library_state_reason.include?('záloha'),
                  'dovod povie, ze sa cita zaloha')
  end
end

NxTest.test('R-11: degradovana kniznica sa DA precitat a POUZIT na projekt') do
  NxR11.with_sandbox do
    set = JSON.parse(JSON.generate(NxR11::HWS::SEED_SETS.first))
    NxR11.make_degraded(NxR11::HWS.path,
                        'std' => 1, 'seed_version' => NxR11::HWS::SEED_VERSION,
                        'sets' => [set], 'mapping' => { set['generic_type'] => set['set_id'] })
    lib = NxR11::HWS.load
    NxTest.assert_equal(1, lib['sets'].length, 'read_library vracia data zo ZALOHY, nie prazdno')
    NxTest.assert_equal(set['set_id'], lib['sets'].first['set_id'], 'a je to naozaj set zo suboru')

    state = NxR11::HWS.global_default_state
    NxTest.assert(!state.nil?,
                  'zmrazenie do projektu sa POVOLUJE — zapisuje sa do MODELU, nie do poskodeneho suboru')
    NxTest.assert_equal(1, state['sets'].keys.length, 'a snapshot dostane namapovanu definiciu')
  end
end

NxTest.test('R-11: globalne zapisy do kniznice setov su odmietnute s dovodom') do
  NxR11.with_sandbox do
    set = JSON.parse(JSON.generate(NxR11::HWS::SEED_SETS.first))
    path = NxR11::HWS.path
    NxR11.make_degraded(path, 'std' => 1, 'seed_version' => NxR11::HWS::SEED_VERSION,
                              'sets' => [set], 'mapping' => {})
    before = File.binread(path)

    status, reason = NxR11::HWS.save_set!(set)
    NxTest.assert_equal(:write_failed, status, 'save_set! odmietnuty')
    NxTest.assert(reason.to_s.include?('poškoden'), "a nesie dovod (#{reason.inspect})")

    dstatus, dreason = NxR11::HWS.delete_set!(set['set_id'])
    NxTest.assert_equal(:write_failed, dstatus, 'delete_set! odmietnuty')
    NxTest.assert(dreason.to_s.include?('poškoden'), 'aj s dovodom')

    NxTest.assert_equal(false, NxR11::HWS.set_global_mapping!(set['generic_type'], set['set_id']),
                        'globalne mapovanie odmietnute')
    NxTest.assert_equal(before, File.binread(path), 'primar ostal bajtovo nedotknuty')
  end
end

NxTest.test('R-11: seed-merge nad degradovanou kniznicou NEZAPISE') do
  NxR11.with_sandbox do
    set = JSON.parse(JSON.generate(NxR11::HWS::SEED_SETS.first))
    path = NxR11::HWS.path
    # `seed_version` 0 = seed-merge by chcel doplnit chybajuce default sety.
    NxR11.make_degraded(path, 'std' => 1, 'seed_version' => 0, 'sets' => [set], 'mapping' => {})
    before = File.binread(path)
    NxR11::HWS.load
    NxTest.assert_equal(before, File.binread(path),
                        'seed-merge je tiez zapis — brana ho zastavi (inak by primar prepisal obsah zo zalohy)')
  end
end

# ==========================================================================
# 4) UI: pouzivatel sa dozvie KONKRETNY dovod, nie „zlyhalo"
# ==========================================================================

NxTest.test('R-11 UI: nastavenia dodavatela hlasia dovod, nie „nepodarilo sa uložiť"') do
  NxR11.with_sandbox do
    NxR11.make_degraded(NxR11::SS.path, NxR11.degraded_supplier_doc)
    ok, errors, status = NxR11::SS.patch_active!('rates' => { 'olep' => 1.23 })
    NxTest.assert_equal(false, ok, 'zapis sa neuskutocnil')
    NxTest.assert_equal(:write_failed, status, 'a je to zlyhanie zapisu')
    NxTest.assert(errors.first.to_s.include?('poškoden'),
                  "okno ukaze KONKRETNU vetu (#{errors.inspect})")
  end
end

NxTest.test('R-11 UI: rozmerove rady hlasia dovod, nie „disk/práva"') do
  NxTest.skip!('handler panela sa testuje headless (v SketchUpe je Panel zivy)') unless NxTest.headless?

  NxR11.with_sandbox do
    NxR11.make_degraded(NxR11::DIM.path, 'std' => 1, 'series' => { 'sirka' => [123] })
    NxR11PanelStub.with_panel do |panel|
      panel.handle_set_dim_series(JSON.generate('series' => { 'sirka' => [400] }))
    end
    msg, err = NxR11PanelStub.last_status
    NxTest.assert_equal(true, err, 'status je chybovy')
    NxTest.assert(msg.to_s.include?('poškoden'), "a povie DOVOD, nie „disk/práva\" (#{msg.inspect})")
    NxTest.assert_equal(false, msg.to_s.include?('uložené'), 'a rozhodne nehlasi uspech')
  end
end

# ==========================================================================
# 5) Strukturalne guardy — brana MUSI zostat pod zamkom a fail-closed
# ==========================================================================

NxTest.test('R-11: brana bezi POD ZAMKOM (nie pred nim)') do
  [['core/abs_rules.rb', 'write'], ['core/hardware_rules.rb', 'write'],
   ['core/dim_series.rb', 'set'], ['core/supplier_settings.rb', 'write']].each do |rel, meth|
    b = NxR11.body(rel, meth)
    NxTest.assert(!b.empty?, "#{rel}: telo #{meth} sa nenaslo")
    lock = b.index('with_catalog_lock')
    guard = b.index('degraded_write_blocked?')
    write = b.index('JsonFileStore.write')
    NxTest.assert(lock && guard && write, "#{rel}: chyba zamok/brana/zapis")
    NxTest.assert(lock < guard && guard < write,
                  "#{rel}: poradie musi byt zamok -> brana -> zapis (cachovany stav nie je dokaz)")
  end

  hw = NxR11.body('core/hardware_sets.rb', 'write')
  lock = hw.index('with_catalog_lock')
  reload = hw.index('JsonFileStore.reload!')
  guard = hw.index('assess_library(')
  NxTest.assert(lock && reload && guard && lock < reload && reload < guard,
                'hardware_sets: stav sa cita NANOVO pod zamkom az pred zapisom')
end

NxTest.test('R-11: degraded? rescue-uje LEN ParserError a ENOENT') do
  b = NxR11.body('core/json_file_store.rb', 'json_state')
  NxTest.assert(b.include?('rescue JSON::ParserError') && b.include?('rescue Errno::ENOENT'),
                'definovane odpovede: poskodeny obsah a chybajuci subor')
  NxTest.assert_equal(false, b.include?('rescue StandardError'),
                      'siroky rescue by z I/O chyby spravil „smies zapisat" — presne opacny zaver')
  d = NxR11.body('core/json_file_store.rb', 'degraded?')
  NxTest.assert_equal(false, d.include?('rescue'), 'degraded? sama ziadnu vynimku nezhltne')
  NxTest.assert_equal(false, d.include?('cache'), 'a necita cez cache — verdikt musi byt z disku')
end

NxTest.test('R-11: UI hlasky citaju dovod z modulu (nie vlastny preklad)') do
  rules = NxR11.body('ui/rules_dialog.rb', 'handle_save', 8)
  NxTest.assert(rules.include?('HardwareRules.write_block_reason'),
                'okno Pravidla si vypyta dovod globalneho zapisu')
  settings = NxR11.body('ui/panel/actions_settings.rb', 'handle_set_dim_series', 8)
  NxTest.assert(settings.include?('DimSeries.write_block_reason'),
                'panel si vypyta dovod pri rozmerovych radoch')
  dlg = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog.rb'))
            .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  %w[handle_set_save handle_set_delete handle_map_global].each do |m|
    b = dlg[/^        def #{m}.*?\n        end\n/m].to_s
    NxTest.assert(b.include?('library_write_blocked?'),
                  "#{m}: globalny zapis sa pyta na ZAPISOVU branu (degraded aj read_only)")
  end
end
