# frozen_string_literal: true
# Testy 1d/R-08: MEDZIPROCESOVY ZAMOK zvysnych globalnych katalogov.
#
# Pat suborov v %APPDATA%\NOXUN\Engine sa menilo sposobom
# „precitaj -> uprav -> zapis" BEZ zamku (a kontrola revizie sedela MIMO
# neho): hardware_sets.json · hardware_rules.json · abs_rules.json ·
# dim_series.json · supplier_settings.json. Dve instancie SketchUpu zdielaju
# jeden %APPDATA%, takze zmena tej PRVEJ zanikla bez slova.
#
# Co davka garantuje a co tieto testy overuju:
#   * kazdy zapis bezi pod JEDNYM sidecar zamkom (`materials.lock`, vzor
#     1b-6c) a subor sa POD NIM cita NANOVO — cudzi zapis, ktory prisiel
#     medzi nasim citanim a nasim zapisom, PREZIJE;
#   * kontrola REVIZIE (sety, nastavenia dodavatela) bezi UZ POD zamkom;
#   * seedovanie ma DVOJITY check (rychly + pod zamkom), takze oneskoreny
#     seeder neprepise realnu zmenu;
#   * zlyhany zamok NIKDY nehlasi uspech a NIKDY nezmeni kniznicu na seed;
#   * zamok naozaj serializuje DVA OS PROCESY (nie len monkeypatch).
#
# PRIZNANY ZVYSOK (audit 1d #3/#6): globalne pravidla kovania a rozmerove
# rady su UPLNA NAHRADA obsahu bez revizie — zamok ich zapisy serializuje,
# ale dve sucasne otvorene okna sa nad nimi stale prebijaju „posledny
# vyhrava". Register to vedie ako samostatnu polozku (R-35); tieto testy
# preto pri nich NETVRDIA, ze cudzia hodnota prezila.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

module NxR08
  E    = Noxun::Engine
  MAT  = E::Materials
  STORE = E::JsonFileStore
  HWS  = E::HardwareSets
  HR   = E::HardwareRules
  ABS  = E::AbsRules
  DIM  = E::DimSeries
  SS   = E::SupplierSettings

  module_function

  # Zdroje modulov (mutacne/strukturalne guardy). Konce riadkov sa normalizuju
  # — pracovna kopia repa je CRLF, CI checkout LF.
  def src(rel)
    File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel))
        .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  # Telo jednej metody zo zdroja (od `def <meno>` po prvy `end` na jej urovni).
  def body(rel, name, indent = 6)
    # `\b` po `!` v mene metody nefunguje (`save_set!(` — nasleduje nesplna
    # znak), preto explicitna negativna dopredna kontrola.
    src(rel)[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end

  # Ulozi obsah suborov, spusti blok a vrati PRESNY povodny stav — ziadny
  # test nesmie ovplyvnit tie dalsie (kniznice su globalny sandbox subor).
  def with_files(*paths)
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    yield
  ensure
    before.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
      FileUtils.rm_f("#{p}.bak")
      STORE.invalidate(p)
    end
  end

  # „Druha instancia" zapise do suboru PRESNE RAZ, tesne PRED tym, nez si
  # vezmeme zamok — teda presne v okne medzi nasim citanim a nasim zapisom,
  # ktore ma zamok zavriet. Jednorazovost je podstatna: realny druhy proces
  # sa do UZ DRZANEHO zamku nedostane.
  #
  # Zapisuje sa PRIAMO na disk (tmp + rename) a cache `JsonFileStore` sa
  # ZAMERNE NEinvaliduje: iny OS proces nasu cache tiez nezhodi, takze bez
  # `reload!` POD zamkom by sme cudziu zmenu vobec nevideli (sekundove okno
  # `CHECK_INTERVAL` vracia ulozenu hodnotu bez pohladu na subor).
  def other_instance_write(path, payload)
    FileUtils.mkdir_p(File.dirname(path))
    tmp = "#{path}.tmp-other"
    File.binwrite(tmp, JSON.pretty_generate(payload))
    File.rename(tmp, path)
  end

  # Nahreje sekundovu cache `JsonFileStore` — presne ten stav, v akom je
  # bezici plugin, ked druha instancia siahne na subor.
  def warm_cache(path)
    STORE.read(path)
  end

  def with_other_instance(path, payload)
    orig = MAT.method(:with_catalog_lock)
    fired = false
    writer = method(:other_instance_write)
    MAT.define_singleton_method(:with_catalog_lock) do |&blk|
      unless fired
        fired = true
        writer.call(path, payload)
      end
      orig.call(&blk)
    end
    yield
    fired
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end

  # Zamok sa neda vziat (prava profilu, I/O).
  def with_broken_lock
    orig = MAT.method(:with_catalog_lock)
    MAT.define_singleton_method(:with_catalog_lock) do |&_blk|
      raise Errno::EACCES, 'materials.lock (test)'
    end
    yield
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end

  # --- fixtury ------------------------------------------------------------

  def set_def(id, name = id)
    { 'set_id' => id, 'name' => name, 'generic_type' => 'hinge',
      'members' => [{ 'code' => 'KOD-1', 'qty' => 1 }] }
  end

  def sets_doc(sets, mapping = {})
    { 'std' => HWS::STD, 'seed_version' => HWS::SEED_VERSION,
      'sets' => HWS.normalize_sets(sets), 'mapping' => mapping }
  end

  # Kniznica pravidiel pod STARSIM seed_version -> load spusti seed-merge.
  def rules_doc(rules, version = 0)
    { 'std' => HR::STD, 'seed_version' => version,
      'rules' => HR.normalize_rules(rules) }
  end

  def abs_doc(rules, version = 0)
    { 'std' => ABS::STD, 'seed_version' => version, 'rules' => rules }
  end
end

# --- 1. hardware_sets: zapis druhej instancie prezije nas zapis --------------

NxTest.test('R-08 sety: set ulozeny druhou instanciou PREZIJE nase save_set!') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::HWS.path) do
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('nas-zaklad')]))
    r::STORE.invalidate(r::HWS.path)
    r.warm_cache(r::HWS.path)
    fired = r.with_other_instance(r::HWS.path,
                                  r.sets_doc([r.set_def('nas-zaklad'), r.set_def('od-druhej')])) do
      status, = r::HWS.save_set!(r.set_def('nas-novy'))
      NxTest.assert_equal(:ok, status, 'nas zapis presiel')
    end
    NxTest.assert(fired, 'fixture: druha instancia naozaj zapisala')
    ids = r::HWS.load['sets'].map { |s| s['set_id'] }
    NxTest.assert(ids.include?('od-druhej'),
                  "set druhej instancie prezil nas zapis: #{ids.inspect}")
    NxTest.assert(ids.include?('nas-novy'), 'a nas set sadol')
  end
end

NxTest.test('R-08 sety: revizia sa porovnava POD zamkom (cudzia zmena = conflict, subor nedotknuty)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::HWS.path) do
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('nas-zaklad')]))
    r::STORE.invalidate(r::HWS.path)
    baseline = r::HWS.revision
    cudzi = r.sets_doc([r.set_def('nas-zaklad'), r.set_def('od-druhej')])
    r.warm_cache(r::HWS.path)
    r.with_other_instance(r::HWS.path, cudzi) do
      status, = r::HWS.save_set!(r.set_def('nas-novy'), revision: baseline)
      NxTest.assert_equal(:conflict, status,
                          'zastarany formular sa ODMIETNE (kontrola je uz pod zamkom)')
    end
    ids = r::HWS.load['sets'].map { |s| s['set_id'] }
    NxTest.assert(ids.include?('od-druhej') && !ids.include?('nas-novy'),
                  "cudzi obsah ostal cely a nas sa NEZAPISAL: #{ids.inspect}")
  end
end

NxTest.test('R-08 sety: delete_set! aj globalne mapovanie citaju subor NANOVO pod zamkom') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::HWS.path) do
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('a'), r.set_def('b')]))
    r::STORE.invalidate(r::HWS.path)
    r.warm_cache(r::HWS.path)
    r.with_other_instance(r::HWS.path,
                          r.sets_doc([r.set_def('a'), r.set_def('b'), r.set_def('od-druhej')])) do
      status, = r::HWS.delete_set!('b')
      NxTest.assert_equal(:ok, status)
    end
    ids = r::HWS.load['sets'].map { |s| s['set_id'] }
    NxTest.assert(ids.include?('od-druhej'), 'cudzi set prezil mazanie ineho setu')
    NxTest.refute(ids.include?('b'), 'a nase mazanie sadlo')

    # Globalne mapovanie: cudzi zapis mapuje INY typ — nas zapis ho nesmie zmazat.
    cudzi = r.sets_doc([r.set_def('a'), r.set_def('od-druhej')], { 'leg' => 'od-druhej' })
    r.warm_cache(r::HWS.path)
    r.with_other_instance(r::HWS.path, cudzi) do
      NxTest.assert_equal(:ok, r::HWS.set_global_mapping!('hinge', 'a'))
    end
    map = r::HWS.load['mapping']
    NxTest.assert_equal('a', map['hinge'], 'nase mapovanie sadlo')
    NxTest.assert_equal('od-druhej', map['leg'], 'a mapovanie druhej instancie prezilo')
  end
end

NxTest.test('R-08 sety: payload nesie KNIZNICU a REVIZIU z toho isteho stavu suboru') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Audit 1d #4: kym sa citali dvoma volaniami, cudzi zapis medzi nimi vyrobil
  # payload so STARYMI setmi a NOVOU reviziou — taky formular presiel guardom
  # a prepisal zmenu, ktoru pouzivatel nikdy nevidel.
  r = NxR08
  r.with_files(r::HWS.path) do
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('nas-zaklad')]))
    r::STORE.invalidate(r::HWS.path)
    lib = nil
    rev = nil
    r.warm_cache(r::HWS.path)
    r.with_other_instance(r::HWS.path,
                          r.sets_doc([r.set_def('nas-zaklad'), r.set_def('od-druhej')])) do
      lib, rev = r::HWS.load_with_revision
    end
    ids = lib['sets'].map { |s| s['set_id'] }
    NxTest.assert(ids.include?('od-druhej'), "payload uz vidi cudzi zapis: #{ids.inspect}")
    NxTest.assert_equal(r::HWS.revision, rev, 'a revizia patri PRESNE k tomuto obsahu')
  end
end

# --- 2. hardware_rules a abs_rules: seed-merge je read-modify-write ----------

NxTest.test('R-08 pravidla kovania: seed-merge nezmaze pravidlo druhej instancie') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::HR.path) do
    nase = { 'rule_id' => 'nase-pravidlo', 'output' => 'hinge', 'kind' => 'fixed', 'quantity' => 1 }
    cudzie = { 'rule_id' => 'od-druhej', 'output' => 'leg', 'kind' => 'fixed', 'quantity' => 4 }
    # seed_version 0 => load MUSI spustit seed-merge (a teda zapis)
    r::STORE.write(r::HR.path, r.rules_doc([nase]))
    r::STORE.invalidate(r::HR.path)
    fired = r.with_other_instance(r::HR.path, r.rules_doc([nase, cudzie])) do
      r::HR.load
    end
    NxTest.assert(fired, 'fixture: druha instancia naozaj zapisala')
    ids = r::HR.load.map { |x| x['rule_id'] }
    NxTest.assert(ids.include?('od-druhej'),
                  "pravidlo druhej instancie prezilo seed-merge: #{ids.inspect}")
    NxTest.assert(ids.include?('nase-pravidlo'), 'a nase ostalo')
    NxTest.assert(ids.include?('podperky-policove'), 'seed sa naozaj doplnil')
  end
end

NxTest.test('R-08 ABS pravidla: self-heal nezmaze rolu, ktoru zapisala druha instancia') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::ABS.path) do
    r::STORE.write(r::ABS.path, r.abs_doc({ 'shelf' => { 'L1' => 2.0 } }))
    r::STORE.invalidate(r::ABS.path)
    cudzie = r.abs_doc({ 'shelf' => { 'L1' => 2.0 }, 'free_panel' => { 'L2' => 2.0 } })
    fired = r.with_other_instance(r::ABS.path, cudzie) { r::ABS.load }
    NxTest.assert(fired, 'fixture: druha instancia naozaj zapisala')
    rules = r::ABS.load
    NxTest.assert_equal(2.0, rules['free_panel']['L2'],
                        'rola druhej instancie prezila normalizaciu aj seed-merge')
    NxTest.assert_equal(2.0, rules['shelf']['L1'], 'a nasa ostala')
  end
end

# --- 3. supplier_settings: patch aj revizia pod zamkom -----------------------

NxTest.test('R-08 nastavenia: patch_active! nezmaze sadzbu, ktoru zapisala druha instancia') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::SS.path) do
    r::SS.reload!
    doc = r::SS.load
    sup = r::SS.supplier_by_id(doc, doc['active'])
    sup['rates']['olep'] = 9.99
    fired = r.with_other_instance(r::SS.path, r::SS.normalize(doc)) do
      ok, = r::SS.patch_active!('rates' => { 'montaz' => 42.5 })
      NxTest.assert(ok, 'nas patch presiel')
    end
    NxTest.assert(fired, 'fixture: druha instancia naozaj zapisala')
    r::SS.reload!
    active = r::SS.active
    NxTest.assert_close(9.99, r::SS.rate(active, 'olep').to_f, 0.001,
                        'sadzba druhej instancie prezila nas patch')
    NxTest.assert_close(42.5, r::SS.rate(active, 'montaz').to_f, 0.001, 'a nasa sadla')
  end
end

NxTest.test('R-08 nastavenia: zastarana revizia = :conflict UZ V JADRE (nie az v okne)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::SS.path) do
    r::SS.reload!
    before = File.binread(r::SS.path)
    ok, errors, status = r::SS.patch_active!({ 'rates' => { 'montaz' => 77.0 } }, 'stara-revizia')
    NxTest.refute(ok, 'zapis nad cudzim stavom sa NEUDEJE')
    NxTest.assert_equal(:conflict, status, 'a volajuci sa dozvie PRECO')
    NxTest.assert(Array(errors).first.to_s.include?('medzitým'), 'hlaska pomenuje cudziu zmenu')
    NxTest.assert_equal(before, File.binread(r::SS.path), 'subor je BAJT-nezmeneny')
    # Bez revizie (interne volania, testy) sa kontrola nerobi.
    ok2, _e, status2 = r::SS.patch_active!('rates' => { 'montaz' => 77.0 })
    NxTest.assert(ok2 && status2 == :ok, 'bez revizie patch normalne prejde')
  end
end

# --- 4. seedovanie: DVOJITY check (audit 1d #2) ------------------------------

NxTest.test('R-08 seed: oneskoreny seeder NEPREPISE realnu zmenu druhej instancie') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Instancia B zisti „subor chyba", zastavi sa; instancia A medzitym seedne
  # a ulozi REALNU zmenu; B potom vezme zamok — a bez DRUHEHO checku by ju
  # naslepo prepisala seedom.
  r = NxR08
  r.with_files(r::HWS.path) do
    FileUtils.rm_f(r::HWS.path)
    FileUtils.rm_f("#{r::HWS.path}.bak")
    r::STORE.invalidate(r::HWS.path)
    # Cache sa TU nenahrieva zamerne — subor este neexistuje a `ensure_seeded`
    # sa aj tak riadi `available?` (cisty `File.exist?`, mimo cache).
    fired = r.with_other_instance(r::HWS.path, r.sets_doc([r.set_def('od-druhej')])) do
      r::HWS.ensure_seeded
    end
    NxTest.assert(fired, 'fixture: druha instancia subor naozaj vytvorila')
    ids = r::HWS.load['sets'].map { |s| s['set_id'] }
    NxTest.assert(ids.include?('od-druhej'),
                  "seeder cudzi obsah NEPREPISAL: #{ids.inspect}")
  end
end

# --- 5. zlyhany zamok NIKDY nehlasi uspech (a nikdy nevrati seed) -----------

NxTest.test('R-08: NEZISKANY zamok konci NEUSPECHOM v KAZDEJ zapisovej ceste') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR08
  r.with_files(r::HWS.path, r::HR.path, r::ABS.path, r::DIM.path, r::SS.path) do
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('nas-zaklad')]))
    r::STORE.invalidate(r::HWS.path)
    before = File.binread(r::HWS.path)
    r.with_broken_lock do
      NxTest.refute(r::HWS.write([r.set_def('x')], {}), 'HardwareSets.write = false')
      status, = r::HWS.save_set!(r.set_def('x'))
      NxTest.assert_equal(:write_failed, status, 'save_set! = :write_failed')
      status2, = r::HWS.delete_set!('nas-zaklad')
      NxTest.assert_equal(:write_failed, status2, 'delete_set! = :write_failed')
      NxTest.assert_equal(false, r::HWS.set_global_mapping!('hinge', 'nas-zaklad'),
                          'set_global_mapping! = false')
      NxTest.refute(r::HR.write([{ 'rule_id' => 'x' }]), 'HardwareRules.write = false')
      NxTest.refute(r::ABS.write({ 'shelf' => { 'L1' => 1.0 } }), 'AbsRules.write = false')
      NxTest.assert_equal(nil, r::DIM.set('sirka' => [500]), 'DimSeries.set = nil')
      NxTest.refute(r::SS.write(r::SS.seed_doc), 'SupplierSettings.write = false')
      okp, _e, statusp = r::SS.patch_active!('rates' => { 'montaz' => 1.0 })
      NxTest.refute(okp, 'patch_active! neuspel')
      NxTest.assert_equal(:write_failed, statusp, 'a povie, ze slo o zlyhany zapis')
    end
    NxTest.assert_equal(before, File.binread(r::HWS.path), 'a v subore sa NIC nezmenilo')
  end
end

NxTest.test('R-08: pri zlyhanom zamku sa kniznica NEZMENI na seed (citanie ostava pravdive)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Seed-merge cesta bezi POD zamkom. Keby jej vynimka prepadla do vonkajsieho
  # rescue `load`, pouzivatel by namiesto SVOJEJ kniznice videl seed —
  # a najblizsi uspesny zapis by ju tym aj zvecnil.
  r = NxR08
  r.with_files(r::HWS.path, r::HR.path) do
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('moj-jediny')]))
    r::STORE.invalidate(r::HWS.path)
    nase = { 'rule_id' => 'nase-pravidlo', 'output' => 'hinge', 'kind' => 'fixed', 'quantity' => 1 }
    r::STORE.write(r::HR.path, r.rules_doc([nase]))
    r::STORE.invalidate(r::HR.path)
    r.with_broken_lock do
      ids = r::HWS.load['sets'].map { |s| s['set_id'] }
      NxTest.assert(ids.include?('moj-jediny'), "kniznica setov ostala vlastna: #{ids.inspect}")
      rids = r::HR.load.map { |x| x['rule_id'] }
      NxTest.assert(rids.include?('nase-pravidlo'), "pravidla ostali vlastne: #{rids.inspect}")
    end
  end
end

# --- 6. REALNY dvojprocesovy flock ------------------------------------------

NxTest.test('R-08: zamok blokuje DRUHY PROCES (nie len monkeypatch)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  # Jediny sposob, ako na Windows overit, ze `flock` naozaj serializuje dve
  # instancie: druhy OS proces si vezme ten isty sidecar `.lock`, drzi ho,
  # zapise a az potom pusti. Nas `save_set!` musi POCKAT a jeho set precitat.
  r = NxR08
  r.with_files(r::HWS.path) do
    dir = r::MAT.dir
    FileUtils.mkdir_p(dir)
    r::STORE.write(r::HWS.path, r.sets_doc([r.set_def('nas-zaklad')]))
    r::STORE.invalidate(r::HWS.path)
    cudzi_json = JSON.pretty_generate(r.sets_doc([r.set_def('nas-zaklad'), r.set_def('od-procesu')]))
    ready = File.join(dir, 'r08_druhy_proces.ready')
    FileUtils.rm_f(ready)
    script = <<~RUBY
      dir, ready, payload = ARGV
      path = File.join(dir, 'hardware_sets.json')
      File.open(File.join(dir, 'materials.lock'), 'a') do |f|
        f.flock(File::LOCK_EX)
        File.binwrite(ready, 'ok')
        sleep 1.2 # kriticka sekcia druhej instancie
        tmp = path + '.tmp-child'
        File.binwrite(tmp, payload)
        File.rename(tmp, path)
        f.flock(File::LOCK_UN)
      end
    RUBY
    pid = Process.spawn(RbConfig.ruby, '-e', script, dir, ready, cudzi_json)
    begin
      deadline = Time.now + 15
      sleep 0.05 until File.exist?(ready) || Time.now > deadline
      NxTest.assert(File.exist?(ready), 'druhy proces zamok drzi')
      status, = r::HWS.save_set!(r.set_def('nas-novy'))
      NxTest.assert_equal(:ok, status, 'nas zapis presiel')
    ensure
      Process.waitpid(pid)
      FileUtils.rm_f(ready)
    end
    ids = r::HWS.load['sets'].map { |s| s['set_id'] }
    NxTest.assert(ids.include?('od-procesu'),
                  "nas zapis pockal na druhy proces a jeho set nechal zit: #{ids.inspect}")
    NxTest.assert(ids.include?('nas-novy'), 'a nas set sadol')
  end
end

# --- 7. mutacne / strukturalne guardy ---------------------------------------

NxTest.test('R-08 (mutacia): KAZDY zapis do %APPDATA% katalogu bezi pod zamkom') do
  # Mutacia „zamok odstraneny" / „jeden zapisovatel ostal mimo": do kazdeho
  # z piatich suborov sa zapisuje PRESNE z jedneho miesta a to je zamknute.
  r = NxR08
  {
    'core/hardware_sets.rb' => 'write',
    'core/hardware_rules.rb' => 'write',
    'core/abs_rules.rb' => 'write',
    'core/dim_series.rb' => 'set',
    'core/supplier_settings.rb' => 'write'
  }.each do |rel, meth|
    source = r.src(rel)
    writes = source.scan(/JsonFileStore\.write\(/).length
    NxTest.assert_equal(1, writes, "#{rel}: do suboru zapisuje JEDINE miesto")
    door = r.body(rel, meth)
    NxTest.assert(!door.empty?, "#{rel}: telo `#{meth}` sa naslo")
    NxTest.assert(door.include?('with_catalog_lock'), "#{rel}: `#{meth}` berie zamok")
    NxTest.assert(door.include?('JsonFileStore.write('),
                  "#{rel}: a zapis je PRIAMO v nom (ziadna obchadzka)")
  end
end

NxTest.test('R-08 (mutacia): kontrola revizie je AZ POD zamkom, nie pred nim') do
  # Mutacia „revision check pred zamkom": presne to bol povodny TOCTOU nalez.
  r = NxR08
  {
    ['core/hardware_sets.rb', 'save_set!'] => 'revision != self.revision',
    ['core/hardware_sets.rb', 'delete_set!'] => 'revision != self.revision',
    ['core/hardware_sets.rb', 'set_global_mapping!'] => 'revision != self.revision'
  }.each do |(rel, meth), needle|
    door = r.body(rel, meth)
    NxTest.assert(!door.empty?, "#{rel}: telo `#{meth}` sa naslo")
    lock = door.index('with_catalog_lock')
    check = door.index(needle)
    NxTest.assert(lock && check, "#{meth}: zamok aj kontrola revizie su v tele")
    NxTest.assert(lock < check, "#{meth}: kontrola revizie bezi AZ POD zamkom")
    NxTest.assert(door.index('JsonFileStore.reload!').to_i < check,
                  "#{meth}: a porovnava sa proti CERSTVEMU suboru")
  end
  locked = r.body('core/supplier_settings.rb', 'patch_active_locked!')
  NxTest.assert(locked.include?('self.revision(sup)'),
                'patch_active_locked!: revizia sa berie z dokumentu precitaneho POD zamkom')
  door = r.body('core/supplier_settings.rb', 'patch_active!')
  NxTest.assert(door.index('with_catalog_lock').to_i < door.index('patch_active_locked!').to_i,
                'patch_active!: telo bezi az pod zamkom')
end

NxTest.test('R-08 (mutacia): seedovanie ma DVOJITY check a rescue nehlasi uspech') do
  # Mutacia „rescue prehltne uspech": kazda zapisova cesta musi mat rescue,
  # ktory konci NEUSPECHOM (false / :write_failed / nil), nie `true`.
  r = NxR08
  %w[core/hardware_sets.rb core/hardware_rules.rb core/abs_rules.rb
     core/supplier_settings.rb].each do |rel|
    door = r.body(rel, 'ensure_seeded')
    NxTest.assert(!door.empty?, "#{rel}: telo `ensure_seeded` sa naslo")
    NxTest.assert_equal(2, door.scan(/JsonFileStore\.available\?/).length,
                        "#{rel}: rychly check PRED zamkom + druhy POD nim")
    NxTest.assert(door.index('with_catalog_lock').to_i < door.rindex('JsonFileStore.available?').to_i,
                  "#{rel}: druhy check je uz POD zamkom")
    NxTest.assert(door.include?('rescue StandardError'),
                  "#{rel}: zlyhany zamok neuletí ako vynimka")
    NxTest.refute(door[/rescue StandardError.*\z/m].to_s.include?('true'),
                  "#{rel}: a rescue vetva NEHLASI uspech")
  end
end

NxTest.test('R-08 (review #258 kolo 2): konflikt globalneho mapovania ZAHODI rozpisany editor pasiem') do
  # Draft editora pasiem si reviziu PRIPINA pri otvoreni a plny push ho
  # ZAMERNE nechava zit. Keby po odmietnuti ostal otvoreny, kazdy dalsi klik
  # na „Ulozit vyber" by poslal TU ISTU zastaranu reviziu a konfliktoval by
  # donekonecna — hoci hlaska tvrdi „obnovene, vyber znova".
  r = NxR08
  door = r.body('ui/hardware_catalog_dialog.rb', 'handle_map_global', 8)
  NxTest.assert(!door.empty?, 'telo `handle_map_global` sa naslo')
  conflict = door.index('status == :conflict')
  NxTest.assert(conflict, 'konfliktova vetva existuje')
  NxTest.assert(door.index('HWSETS.mapConflict').to_i > conflict,
                'a v nej sa rozpisany editor pasiem ZAHADZUJE')
  NxTest.assert(door.index('after_sets_change').to_i < conflict,
                'sekcia sa najprv obnovi cerstvym payloadom, az potom sa draft zahodi')
  js = r.src('ui/js/hw_sets.js')
  NxTest.assert(js.include?('mapConflict: function(key)'), 'klient prijimac ma')
  NxTest.assert(js[/mapConflict: function\(key\)\{.*?\n    \}/m].to_s.include?('delete HWS_SEL[key]'),
                'a naozaj draft zahadza (nie len prekresluje)')
  # Pripnutie revizie (kolo 1, P1) — bez neho by bola cela vetva zbytocna.
  NxTest.assert(js.include?('hwsPinRev('), 'draft si reviziu pripina pri otvoreni')
  NxTest.assert(js.include?('hwsMapRev(pinnedRev'), 'a Ulozit posiela PRIPNUTU, nie cerstvu')
end

NxTest.test('R-08 (mutacia): vsetkych pat katalogov zdiela priecinok Materials') do
  # Mutacia „zamok inde nez data": kym si tri moduly ratali `dir` samy,
  # `test_dir_override` presmeroval zamok do sandboxu, ale zapis ostal
  # v ZIVOM %APPDATA% — izolovany in-SU test tak upravoval realne pravidla.
  r = NxR08
  [r::HWS, r::HR, r::ABS, r::DIM, r::SS].each do |mod|
    NxTest.assert_equal(r::MAT.dir, mod.dir, "#{mod}: zdielany priecinok katalogov")
  end
  %w[core/hardware_rules.rb core/abs_rules.rb core/supplier_settings.rb].each do |rel|
    NxTest.assert(r.body(rel, 'dir').include?('Materials.dir'),
                  "#{rel}: `dir` sa pyta Materials (a teda aj test_dir_override)")
  end
end
