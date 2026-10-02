# frozen_string_literal: true
# H7a / R-38 — SUBOR NASTAVENI EXPORTU (`vepo_settings.json`: nazov zakazky,
# 18 + 36, posledny priecinok) ZLEHO TVARU alebo NECITATELNY sa nesmie ticho
# prepisat ani znicit dobru zalohu; kazdy zapis vracia vysledok a okno ho
# povie (package H7 §6 R-A1–R-A9, §15–§17).
#
# Rodina H9/R-37 (`HardwareRules.write_gate`, `JsonFileStore.degraded?`,
# `preserve_valid_backup`). Matica R-A2 (zavazna):
#   zdravy                                   -> subor,   zapisy :ok
#   chyba primar + dobra .bak                -> zaloha,  zapisy :ok (obnova)
#   necitatelny / zly tvar + dobra .bak      -> ZALOHA,  zapisy :blocked, subory nedotknute
#   necitatelny / nie-objekt BEZ dobrej .bak -> predvolene, zapisy :unreadable
#   objekt so zlym project_names / {} BEZ .bak -> ako dnes (samooprava), :ok
#   zamok / brana / citanie / blok           -> :failed, nic sa nepise
#   zlyha samotny zapis (premenovanie)       -> :failed, primar nezmeneny, .bak = doterajsi primar
#
# Sada:
#   T-A1 matica · T-A2 predikat · T-A3 brana · T-A4 fazy zapisu · T-A5 most
#   a prenos nazvu · T-A6 dve instancie · T-A7/T-A7b `refresh` a cache zalohy ·
#   T-A10 pocet pokusov prenosu a logov · T-A11 cakajuci nazov (+ veta po
#   4 exportoch). Okno (T-A8) a guardy (T-A9) su na konci sady.
# Mutacie M1–M24 (package §7, §15–§17) zabija tato sada spolu s T0
# (`test_h7a_golden.rb`) a prepojenymi testami `test_st1a_studio.rb`.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require_relative 'test_h7a_golden' unless defined?(NxH7G)

module NxH7A
  E     = Noxun::Engine
  PC    = E::ProductionCore
  STORE = E::JsonFileStore
  MAT   = E::Materials
  # Modul nastaveni exportu. Presun H7a z ProductionCore prepojil LEN tuto
  # konstantu a blok „API" (testy ochrany vznikli nad starym miestom).
  S     = E::ExportSettings

  GOOD = { 'project_names' => { 'c:/z/a.skp' => 'Zo zalohy' }, 'merge_18_36' => false,
           'last_dir' => 'D:/Zaloha' }.freeze
  PRIMARY = { 'project_names' => { 'c:/z/a.skp' => 'Primar' }, 'merge_18_36' => false,
              'last_dir' => 'D:/Primar' }.freeze
  BAD_SHAPES = ['[]', 'null', '"x"', '42', '{}', '{"project_names":[]}', '{"project_names":"x"}'].freeze
  UNREADABLE = '{"project_names": {'
  MODEL = Struct.new(:path, :guid)

  module_function

  # --- API (jedine miesto, ktore pozna modul) -----------------------------

  def path
    S.path
  end

  def read
    S.read
  end

  def save(attrs)
    S.save(attrs)
  end

  def update(&blk)
    S.update(&blk)
  end

  def refresh
    S.refresh
  end

  def save_last_dir(dir)
    S.save_last_dir(dir)
  end

  def last_dir
    S.last_dir
  end

  # --- sandbox ------------------------------------------------------------------

  def with_sandbox
    prev = MAT.test_dir_override
    dir = Dir.mktmpdir('nx-h7a-')
    MAT.test_dir_override = dir
    reset_state
    yield dir
  ensure
    MAT.test_dir_override = prev
    reset_state
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  def reset_state
    STORE.invalidate
    S::LAST_BLOCK[:reason] = nil
    S::ADOPT_RETRY.clear
  end

  # Zachyti `Engine.log` aj `Engine.log_error` (headless stub ich zahadzuje).
  def with_log
    logs = []
    sc = E.singleton_class
    sc.send(:alias_method, :h7a_orig_log, :log)
    sc.send(:alias_method, :h7a_orig_log_error, :log_error)
    sc.send(:define_method, :log) { |m| logs << m.to_s; nil }
    sc.send(:define_method, :log_error) { |e, c = nil| logs << "ERR[#{c}] #{e.class}: #{e.message}"; nil }
    yield logs
  ensure
    sc.send(:remove_method, :log)
    sc.send(:remove_method, :log_error)
    sc.send(:alias_method, :log, :h7a_orig_log)
    sc.send(:alias_method, :log_error, :h7a_orig_log_error)
    sc.send(:remove_method, :h7a_orig_log)
    sc.send(:remove_method, :h7a_orig_log_error)
  end

  # Pocita vzatia zamku (a volitelne podstrci chybu alebo „druhu instanciu").
  def with_lock_probe(before: nil, raise_error: nil)
    count = { n: 0 }
    orig = MAT.method(:with_catalog_lock)
    MAT.define_singleton_method(:with_catalog_lock) do |&blk|
      count[:n] += 1
      raise raise_error if raise_error

      before&.call
      orig.call(&blk)
    end
    yield count
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end

  def write_raw(file, content)
    FileUtils.mkdir_p(File.dirname(file))
    File.binwrite(file, content.is_a?(String) ? content : JSON.pretty_generate(content))
    STORE.invalidate
  end

  def bytes(file)
    File.exist?(file) ? File.binread(file) : nil
  end

  def snapshot
    [bytes(path), bytes("#{path}.bak")]
  end

  # Zapis „druhej instancie" priamo (iny proces nase dvere nepozna).
  def other_write(doc)
    STORE.write(path, doc)
  end

  def model(path = 'C:/Z/A.skp')
    MODEL.new(path, 'G')
  end

  # Neulozeny model s nazvom pod klucom sedenia, ktory nesie AJ zaloha
  # (dva zapisy: nazov, potom 18 + 36 — `.bak` = primar s nazvom).
  def named_unsaved(name)
    m = MODEL.new('', "U-#{name}")
    S.save_project_name(m, name)
    S.save_merge_18_36(false)
    m
  end

  # Vsetky zapisove funkcie modulu nad tym istym stavom -> { meno => [status, reason] }
  def all_writers(mdl)
    { 'save_project_name' => S.save_project_name(mdl, 'Novy nazov'),
      'save_merge_18_36' => S.save_merge_18_36(true),
      'last_dir' => save_last_dir('D:/Novy'),
      'update_project_names' => S.update_project_names { |m| m.merge('c:/z/x.skp' => 'X') } }
  end
end

# =============================================================================
# T-A2 PREDIKAT
# =============================================================================

NxTest.test('H7a T-A2: predikat tvaru — len kontajnery, {} a zly project_names su poskodenie') do
  ok = [{ 'merge_18_36' => false }, { 'project_names' => {} }, { 'last_dir' => 'x' }, NxH7A::GOOD,
        { 'project_names' => { 'a' => 1 }, 'merge_18_36' => 'nie' }] # hodnoty posudzuje normalizacia
  ok.each { |d| NxTest.assert(NxH7A::S.doc_shape_ok?(d), "zdravy tvar: #{d.inspect}") }
  bad = [[], nil, 'x', 42, {}, { 'project_names' => [] }, { 'project_names' => 'x' },
         { 'project_names' => nil }]
  bad.each { |d| NxTest.refute(NxH7A::S.doc_shape_ok?(d), "zly tvar: #{d.inspect}") }
  NxTest.assert_equal(:doc_shape_ok?, NxH7A::S.shape_check.name, 'shape_check = method(:doc_shape_ok?)')
end

# =============================================================================
# T-A1 MATICA R-A2
# =============================================================================

NxTest.test('H7a T-A1: zdravy subor — citanie zo suboru, vsetky zapisy :ok, .bak sa toci ako dnes') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::PRIMARY)
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    m = NxH7A.model
    NxTest.assert_equal('Primar', NxH7A::S.project_name(m))
    NxTest.refute(NxH7A::S.merge_18_36)
    NxTest.assert_equal('D:/Primar', NxH7A.last_dir)
    before = NxH7A.bytes(NxH7A.path)
    res = NxH7A.all_writers(m)
    res.each { |k, v| NxTest.assert_equal([:ok, ''], v, k) }
    NxTest.assert_equal('Novy nazov', NxH7A::S.project_name(m))
    NxTest.assert(NxH7A::S.merge_18_36)
    NxTest.assert_equal('D:/Novy', NxH7A.last_dir)
    NxTest.refute(NxH7A.bytes("#{NxH7A.path}.bak") == JSON.pretty_generate(NxH7A::GOOD), '.bak sa otocila')
    NxTest.refute(before == NxH7A.bytes(NxH7A.path))
  end
end

NxTest.test('H7a T-A1: chybajuci primar + dobra .bak — zaloha a zapis = OBNOVA (:ok)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    m = NxH7A.model
    NxTest.assert_equal('Zo zalohy', NxH7A::S.project_name(m))
    NxTest.refute(NxH7A::S.merge_18_36, '18 + 36 zo zalohy')
    NxTest.assert_equal('D:/Zaloha', NxH7A.last_dir)
    bak = NxH7A.bytes("#{NxH7A.path}.bak")
    NxTest.assert_equal([:ok, ''], NxH7A::S.save_merge_18_36(true))
    doc = JSON.parse(NxH7A.bytes(NxH7A.path))
    NxTest.assert_equal('Zo zalohy', doc['project_names']['c:/z/a.skp'], 'obnova zo zalohy + zmena')
    NxTest.assert_equal(true, doc['merge_18_36'])
    NxTest.assert_equal(bak, NxH7A.bytes("#{NxH7A.path}.bak"), 'zaloha ako dnes (bez primaru sa netoci)')
  end
end

NxTest.test('H7a T-A1: NECITATELNY primar + dobra .bak — zaloha, vsetky zapisy :blocked, subory nedotknute') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::UNREADABLE)
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    m = NxH7A.model
    NxTest.assert_equal('Zo zalohy', NxH7A::S.project_name(m))
    NxTest.refute(NxH7A::S.merge_18_36)
    before = NxH7A.snapshot
    reason = format(NxH7A::S::DEGRADED_REASON, NxH7A.path)
    NxH7A.all_writers(m).each { |k, v| NxTest.assert_equal([:blocked, reason], v, k) }
    NxTest.assert_equal(before, NxH7A.snapshot, 'primar aj .bak bajtovo nedotknute (dnes zapis presiel — S8)')
    NxTest.assert_equal('Zo zalohy', NxH7A::S.project_name(m), 'echo = zaloha')
  end
end

NxTest.test('H7a T-A1: ZLY TVAR (7 vstupov) + dobra .bak — citanie zo zalohy, zapisy :blocked, zaloha prezije') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A::BAD_SHAPES.each do |bad|
    NxH7A.with_sandbox do
      NxH7A.write_raw(NxH7A.path, bad)
      NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
      m = NxH7A.model
      NxTest.assert_equal('Zo zalohy', NxH7A::S.project_name(m), "#{bad}: nazov zo zalohy (dnes meno suboru)")
      NxTest.refute(NxH7A::S.merge_18_36, "#{bad}: 18 + 36 zo zalohy (dnes zlucenie — S9)")
      NxTest.assert_equal('D:/Zaloha', NxH7A.last_dir, bad)
      before = NxH7A.snapshot
      NxH7A.all_writers(m).each { |k, v| NxTest.assert_equal(:blocked, v.first, "#{bad} #{k}") }
      NxTest.assert_equal(before, NxH7A.snapshot, "#{bad}: subory nedotknute (dnes sa dobra zaloha niekedy znicila)")
    end
  end
end

NxTest.test('H7a T-A1: necitatelny alebo nie-objekt BEZ dobrej zalohy — predvolene a :unreadable (dnes ticho)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  cases = [[NxH7A::UNREADABLE, nil], ['[]', nil], ['null', nil], ['"x"', nil], ['42', nil],
           [NxH7A::UNREADABLE, '[]'], ['[]', NxH7A::UNREADABLE]]
  cases.each do |primary, bak|
    NxH7A.with_sandbox do
      NxH7A.write_raw(NxH7A.path, primary)
      NxH7A.write_raw("#{NxH7A.path}.bak", bak) if bak
      m = NxH7A.model
      NxTest.assert_equal('A', NxH7A::S.project_name(m), "#{primary}/#{bak}: predvoleny nazov")
      NxTest.assert(NxH7A::S.merge_18_36, "#{primary}/#{bak}: predvolene 18 + 36")
      before = NxH7A.snapshot
      reason = format(NxH7A::S::UNREADABLE_REASON, NxH7A.path)
      NxH7A.all_writers(m).each do |k, v|
        NxTest.assert_equal([:unreadable, reason], v, "#{primary}/#{bak} #{k}")
      end
      NxTest.assert_equal(before, NxH7A.snapshot, "#{primary}/#{bak}: nic sa nezapisalo")
    end
  end
end

NxTest.test('H7a T-A1: objekt so zlym project_names alebo {} BEZ zalohy — ako dnes (samooprava, :ok)') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  ['{}', '{"project_names":[],"merge_18_36":false}', '{"project_names":"x","last_dir":"D:/X"}'].each do |bad|
    NxH7A.with_sandbox do
      NxH7A.write_raw(NxH7A.path, bad)
      m = NxH7A.model
      doc = JSON.parse(bad)
      NxTest.assert_equal('A', NxH7A::S.project_name(m), "#{bad}: mapa prazdna")
      NxTest.assert_equal(doc['merge_18_36'] != false, NxH7A::S.merge_18_36, "#{bad}: ostatne kluce zo suboru")
      NxTest.assert_equal(doc['last_dir'], NxH7A.last_dir, bad)
      NxTest.assert_equal([:ok, ''], NxH7A::S.save_project_name(m, 'Opravene'), bad)
      NxTest.assert_equal('Opravene', NxH7A::S.project_name(m))
      NxTest.assert_equal(bad, NxH7A.bytes("#{NxH7A.path}.bak"), "#{bad}: .bak dostane zly primar (ako dnes)")
    end
  end
end

# =============================================================================
# T-A3 BRANA
# =============================================================================

NxTest.test('H7a T-A3: brana cita DISK, nie cache — poskodenie v okne cache zapis zastavi') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::PRIMARY)
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    NxTest.assert_equal('Primar', NxH7A::S.project_name(NxH7A.model), 'cache drzi zdravy primar')
    File.binwrite(NxH7A.path, '[]') # BEZ invalidacie cache
    state, why = NxH7A::S.write_gate
    NxTest.assert_equal(:degraded, state)
    NxTest.assert_equal(format(NxH7A::S::DEGRADED_REASON, NxH7A.path), why)
    NxTest.assert_equal(:blocked, NxH7A.save_last_dir('D:/X').first)
  end
end

NxTest.test('H7a T-A3: vynimka predikatu = :failed (fail-closed), subory nedotknute') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, '[]')
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    before = NxH7A.snapshot
    NxH7G.with_stubs(NxH7A::S, doc_shape_ok?: ->(_d) { raise ArgumentError, 'predikat (test)' }) do
      NxTest.assert_equal([:failed, NxH7A::S::FAILED_REASON], NxH7A.save_last_dir('D:/X'))
    end
    NxTest.assert_equal(before, NxH7A.snapshot)
  end
end

NxTest.test('H7a T-A3: JsonFileStore.write dostane predikat tvaru POZICNE') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    got = nil
    orig = NxH7A::STORE.method(:write)
    begin
      NxH7A::STORE.define_singleton_method(:write) { |*a| got = a; orig.call(*a) }
      NxTest.assert_equal([:ok, ''], NxH7A.save_last_dir('D:/X'))
    ensure
      NxH7A::STORE.define_singleton_method(:write, orig)
    end
    NxTest.assert_equal(3, got.length, 'tri pozicne argumenty')
    NxTest.assert_equal(:doc_shape_ok?, got[2].name, 'treti = shape_check')
  end
end

# =============================================================================
# T-A4 FAZY ZAPISU
# =============================================================================

NxTest.test('H7a T-A4: zamok -> :failed s logom faze lock; blok vyhodi -> :failed; nil -> :unchanged bez zapisu') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::PRIMARY)
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    before = NxH7A.snapshot
    NxH7A.with_log do |logs|
      NxH7A.with_lock_probe(raise_error: Errno::EACCES.new('materials.lock (test)')) do
        NxTest.assert_equal([:failed, NxH7A::S::FAILED_REASON], NxH7A.save_last_dir('D:/X'))
      end
      NxTest.assert(logs.any? { |l| l.include?('(lock)') }, "log nesie fazu lock: #{logs.inspect}")
      logs.clear
      res = NxH7A.update { |_f| raise 'blok (test)' }
      NxTest.assert_equal([:failed, NxH7A::S::FAILED_REASON], res)
      NxTest.assert(logs.any? { |l| l.include?('(block)') }, logs.inspect)
    end
    NxTest.assert_equal(before, NxH7A.snapshot)
    NxTest.assert_equal([:unchanged, ''], NxH7A.update { |_f| nil })
    NxTest.assert_equal(before, NxH7A.snapshot, 'nil = ziadny zapis ani otocenie .bak')
  end
end

NxTest.test('H7a T-A4: EACCES pri citani -> :failed; ParserError/nie-objekt bez zalohy -> :unreadable') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::PRIMARY)
    orig = NxH7A::STORE.method(:read)
    begin
      NxH7A::STORE.define_singleton_method(:read) { |*_a, **_k| raise Errno::EACCES, 'zdielanie (test)' }
      NxTest.assert_equal(:failed, NxH7A.save_last_dir('D:/X').first, 'I/O o zdravi suboru nehovori nic')
    ensure
      NxH7A::STORE.define_singleton_method(:read, orig)
    end
    NxH7A.write_raw(NxH7A.path, NxH7A::UNREADABLE)
    NxTest.assert_equal(:unreadable, NxH7A.save_last_dir('D:/X').first, 'ParserError')
    NxH7A.write_raw(NxH7A.path, '[]')
    NxTest.assert_equal(:unreadable, NxH7A.save_last_dir('D:/X').first, 'nie-objekt (NotObject)')
  end
end

NxTest.test('H7a T-A4 (§15 A7): zlyhane finalne premenovanie -> :failed, primar nezmeneny, .bak = doterajsi primar') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::PRIMARY)
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    p0 = NxH7A.bytes(NxH7A.path)
    target = File.expand_path(NxH7A.path)
    orig = File.method(:rename)
    begin
      File.define_singleton_method(:rename) do |a, b|
        raise Errno::EACCES, 'rename (test)' if File.expand_path(b) == target

        orig.call(a, b)
      end
      NxTest.assert_equal([:failed, NxH7A::S::FAILED_REASON], NxH7A.save_last_dir('D:/X'))
    ensure
      # `File.rename` je C metoda na singletone — vratit PRESNE povodnu
      # (remove_method by ju zmazal nadobro a dalsie sady by nezapisali nic).
      File.define_singleton_method(:rename, orig)
    end
    NxTest.assert_equal(p0, NxH7A.bytes(NxH7A.path), 'primar nezmeneny (atomova vymena)')
    NxTest.assert_equal(p0, NxH7A.bytes("#{NxH7A.path}.bak"), '.bak uz obsahuje kopiu doterajsieho primaru (R-11)')
  end
end

# =============================================================================
# T-A5 MOST A PRENOS NAZVU
# =============================================================================

NxTest.test('H7a T-A5: prenos pri :blocked most NEZAHODI a nazov ide zo zalohy; po obnove zapise a most spotrebuje') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.named_unsaved('Rozrobena')
    skey = NxH7A::S.project_key(m)
    NxTest.refute(NxH7A::S.remembered_session_key(m).empty?, 'most si kluc sedenia pamata')
    NxH7A.write_raw(NxH7A.path, NxH7A::UNREADABLE)
    m.path = 'C:/Zakazky/R1.skp'
    before = NxH7A.snapshot
    NxTest.assert_equal('Rozrobena', NxH7A::S.project_name(m), 'nazov zo zalohy (fallback)')
    NxTest.assert_equal(before, NxH7A.snapshot, 'prenos do poskodeneho suboru nezapisal')
    NxTest.assert_equal(skey, NxH7A::S.remembered_session_key(m), 'most ostal')
    # §16 B1: oprava = PREMENOVANIE (poskodeny subor ostane na rucnu obnovu)
    File.rename(NxH7A.path, File.join(File.dirname(NxH7A.path), 'vepo_settings.poskodeny.json'))
    NxH7A::STORE.invalidate
    NxTest.assert_equal('Rozrobena', NxH7A::S.project_name(m))
    doc = JSON.parse(NxH7A.bytes(NxH7A.path))
    NxTest.assert_equal('Rozrobena', doc['project_names']['c:/zakazky/r1.skp'], 'prenos zapisal na cestu')
    NxTest.refute(doc['project_names'].key?(skey), 'kluc sedenia zanikol')
    NxTest.assert_equal('', NxH7A::S.remembered_session_key(m), 'most sa spotreboval')
    NxTest.assert_equal(NxH7A::UNREADABLE,
                        File.binread(File.join(File.dirname(NxH7A.path), 'vepo_settings.poskodeny.json')),
                        'premenovany subor plugin necita ani neprepisuje')
  end
end

# =============================================================================
# T-A6 DVE INSTANCIE (R-A8)
# =============================================================================

NxTest.test('H7a T-A6: dve instancie — rozne kluce sa nestratia; poskodenie po nasom citani -> :blocked') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, NxH7A::PRIMARY)
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    # (a) druha instancia zapise iny kluc medzi nasim citanim a zapisom
    other = -> { NxH7A.other_write(JSON.parse(File.binread(NxH7A.path)).merge('druha' => 'X')) }
    NxH7A.with_lock_probe(before: other) do
      NxTest.assert_equal([:ok, ''], NxH7A.save_last_dir('D:/A'))
    end
    NxTest.assert_equal('X', NxH7A.read['druha'], '(a) zaznam druhej instancie prezil')
    NxTest.assert_equal('D:/A', NxH7A.last_dir)
    # (b) druha instancia subor POSKODI po nasom predzamkovom citani
    NxH7A::S.project_name(NxH7A.model)
    good_bak = NxH7A.bytes("#{NxH7A.path}.bak")
    NxH7A.with_lock_probe(before: -> { File.binwrite(NxH7A.path, '[]') }) do
      NxTest.assert_equal(:blocked, NxH7A.save_last_dir('D:/B').first, '(b) brana pod zamkom nad diskom')
    end
    NxTest.assert_equal('[]', File.binread(NxH7A.path), '(b) poskodeny primar nedotknuty')
    NxTest.assert_equal(good_bak, NxH7A.bytes("#{NxH7A.path}.bak"), '(b) zaloha nedotknuta')
    # (c) druha instancia poskodeny primar premenuje -> obnova zo zalohy
    NxH7A.with_lock_probe(before: -> { File.rename(NxH7A.path, "#{NxH7A.path}.poskodeny") }) do
      NxTest.assert_equal([:ok, ''], NxH7A.save_last_dir('D:/C'), '(c) obnova')
    end
    NxTest.assert_equal('D:/C', NxH7A.last_dir)
    # (d) zamok nedostupny
    NxH7A.with_lock_probe(raise_error: IOError.new('zamok (test)')) do
      NxTest.assert_equal(:failed, NxH7A.save_last_dir('D:/D').first, '(d)')
    end
  end
end

# =============================================================================
# T-A7 REFRESH A CACHE ZALOHY
# =============================================================================

NxTest.test('H7a T-A7: refresh po otoceni .bak druhou instanciou (do 1 s) vidi novu zalohu') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, '[]')
    NxH7A.write_raw("#{NxH7A.path}.bak", NxH7A::GOOD)
    m = NxH7A.model
    NxTest.assert_equal('Zo zalohy', NxH7A::S.project_name(m))
    File.binwrite("#{NxH7A.path}.bak",
                  JSON.pretty_generate('project_names' => { 'c:/z/a.skp' => 'Nova zaloha' }, 'pad' => 'x' * 30))
    NxTest.assert(NxH7A.refresh)
    NxTest.assert_equal('Nova zaloha', NxH7A::S.project_name(m), 'refresh zhodil aj cache zalohy')
  end
end

NxTest.test('H7a T-A7b (§15 A3): odmietnuty zapis zhodi cache zalohy — echo bez refresh vidi novu zalohu') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    NxH7A.write_raw(NxH7A.path, '[]')
    NxH7A.write_raw("#{NxH7A.path}.bak", 'project_names' => { 'c:/z/b.skp' => 'Old' }, 'merge_18_36' => false)
    m = NxH7A.model('C:/Z/B.skp')
    NxTest.assert_equal('Old', NxH7A::S.project_name(m))
    NxTest.refute(NxH7A::S.merge_18_36)
    File.binwrite("#{NxH7A.path}.bak", JSON.generate('project_names' => { 'c:/z/b.skp' => 'New' },
                                                     'merge_18_36' => true, 'pad' => 'x' * 20))
    NxTest.assert_equal(:blocked, NxH7A::S.save_merge_18_36(false).first)
    NxTest.assert_equal('New', NxH7A::S.project_name(m), 'echo nazvu = nova zaloha')
    NxTest.assert(NxH7A::S.merge_18_36, 'echo 18 + 36 = nova zaloha')
  end
end

# =============================================================================
# T-A10 POKUSY PRENOSU A LOGY (§15 A5, §16 B4/B6, §17 C3)
# =============================================================================

module NxH7A
  module_function

  # Ulozeny model, ktoreho nazov zije LEN pod klucom sedenia v zalohe;
  # primar poskodeny `corrupt`. -> model
  def pending_setup(corrupt)
    m = named_unsaved('Zakazka L')
    write_raw(path, corrupt)
    m.path = 'C:/Zakazky/L.skp'
    m
  end

  def count_logs(logs)
    { note: logs.count { |l| l.start_with?('export settings: zapis odmietnuty') },
      fallback: logs.count { |l| l.include?('pouzivam zalohu') } }
  end
end

NxTest.test('H7a T-A10: syntakticky poskodeny primar — 100x project_name = najviac 1 note, 2 fallback, 1 zamok') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.pending_setup('{"x":')
    NxH7A.with_log do |logs|
      NxH7A.with_lock_probe do |lock|
        100.times { NxTest.assert_equal('Zakazka L', NxH7A::S.project_name(m)) }
        c = NxH7A.count_logs(logs)
        NxTest.assert(c[:note] <= 1, "note_block #{c[:note]}x")
        NxTest.assert(c[:fallback] <= 2, "fallback log #{c[:fallback]}x")
        NxTest.assert(lock[:n] <= 1, "zamok #{lock[:n]}x")
        NxTest.assert_equal(1, lock[:n], 'prvy pokus prenosu prebehol')
        # oprava premenovanim -> zmena obsahu -> jeden novy pokus, ktory prejde
        File.rename(NxH7A.path, "#{NxH7A.path}.poskodeny")
        NxTest.assert_equal('Zakazka L', NxH7A::S.project_name(m))
        NxTest.assert_equal(2, lock[:n], 'novy pokus po zmene suborov')
        NxTest.assert_equal('Zakazka L', JSON.parse(File.binread(NxH7A.path))['project_names']['c:/zakazky/l.skp'])
        NxTest.refute(NxH7A::S.name_pending?(m))
      end
    end
  end
end

NxTest.test('H7a T-A10: variant zly tvar [] — rovnake obmedzenie pokusov') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.pending_setup('[]')
    NxH7A.with_log do |logs|
      NxH7A.with_lock_probe do |lock|
        50.times { NxH7A::S.project_name(m) }
        NxTest.assert_equal(1, lock[:n])
        NxTest.assert(NxH7A.count_logs(logs)[:note] <= 1)
      end
    end
  end
end

NxTest.test('H7a T-A10 (§16 B4): oprava obsahom ROVNAKEJ velkosti s vratenym mtime = novy pokus') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.named_unsaved('Zakazka L')
    good = File.binread(NxH7A.path)
    broken = "#{good[0..-2]} " # rovnaka dlzka, necitatelny (chyba zatvaracia zatvorka)
    NxH7A.write_raw(NxH7A.path, broken)
    m.path = 'C:/Zakazky/L.skp'
    stat = File.stat(NxH7A.path)
    NxH7A.with_lock_probe do |lock|
      NxH7A::S.project_name(m)
      NxTest.assert_equal(1, lock[:n])
      File.binwrite(NxH7A.path, good)
      File.utime(stat.atime, stat.mtime, NxH7A.path)
      NxTest.assert_equal(stat.size, File.size(NxH7A.path), 'rovnaka velkost')
      NxH7A::STORE.invalidate
      NxH7A::S.project_name(m)
      NxTest.assert_equal(2, lock[:n], 'obsahovy podpis zmenu rozpoznal (mtime + velkost nie)')
    end
    NxTest.assert_equal('Zakazka L', NxH7A.read['project_names']['c:/zakazky/l.skp'], 'prenos prebehol')
  end
end

NxTest.test('H7a T-A10 (§17 C3): seria refresh -> project_name nad nezmenenymi subormi = 1 pokus, 1 log') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.pending_setup('{"x":')
    NxH7A.with_log do |logs|
      NxH7A.with_lock_probe do |lock|
        20.times do
          NxH7A.refresh
          NxH7A::S.project_name(m)
        end
        NxTest.assert_equal(1, lock[:n], 'refresh pamat pokusov NEMAZE')
        NxTest.assert_equal(1, NxH7A.count_logs(logs)[:note])
      end
    end
  end
end

NxTest.test('H7a T-A10 (§16 B6): kluc pamate pokusov je zmrazena kopia aliasov') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.pending_setup('{"x":')
    NxH7A::S.project_name(m)
    keys = NxH7A::S::ADOPT_RETRY.keys
    NxTest.assert_equal(1, keys.length)
    NxTest.assert(keys.first.frozen? && keys.first[1].frozen?, 'kluc aj pole aliasov su zmrazene')
    NxTest.assert_equal('c:/zakazky/l.skp', keys.first[0])
    NxTest.assert_equal(NxH7A::S.session_keys_for(m).sort, keys.first[1])
  end
end

# =============================================================================
# T-A11 CAKAJUCI NAZOV (§15 A1)
# =============================================================================

module NxH7A
  module_function

  # Jeden export cez NxH7G stuby zberu (nazov a nastavenia skutocne).
  def export_status(method, mdl)
    msg = nil
    err = nil
    col = method == :do_export ? NxH7G.collected([NxH7G.record(1, 18.0)]) : NxH7G.collected([])
    Dir.mktmpdir('nx-h7a-exp-') do |dir|
      NxH7G.with_stubs(PC, NxH7G.collect_stubs(col)) do
        NxH7G.with_ui(dir, []) do
          PC.send(method, mdl, { 'gen' => 1 }, generation: 1,
                                               status: ->(t, e = false) { msg = t; err = e }, repush: -> {})
        end
      end
    end
    [msg.to_s, err]
  end
end

NxTest.test('H7a T-A11: cakajuci nazov — plati v sedeni, 4 exporty pripoja vetu, znovuotvorenie = meno suboru') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.pending_setup('{"x":')
    NxTest.assert_equal('Zakazka L', NxH7A::S.project_name(m))
    NxTest.assert(NxH7A::S.name_pending?(m), 'nazov caka na prenos')
    note = NxH7A::PC.pending_name_note(m)
    NxTest.assert(note.start_with?(' · pozor: názov zákazky sa zatiaľ neuložil k súboru'), note)
    NxTest.assert(note.include?(NxH7A.path) && note.include?('premenuj'), note)
    %i[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].each do |exp|
      msg, err = NxH7A.export_status(exp, m)
      NxTest.assert(msg.end_with?(note), "#{exp}: veta na konci statusu: #{msg}")
      NxTest.refute(err, "#{exp}: farba statusu bez zmeny")
    end
    reopened = NxH7A::MODEL.new('C:/Zakazky/L.skp', 'REOPEN')
    NxTest.assert_equal('L', NxH7A::S.project_name(reopened), 'bez opravy sa po znovuotvoreni strati (priznane)')
    # oprava v povodnom okne
    File.rename(NxH7A.path, File.join(File.dirname(NxH7A.path), 'vepo_settings.poskodeny.json'))
    NxH7A::STORE.invalidate
    NxTest.assert_equal('Zakazka L', NxH7A::S.project_name(m), 'dalsie citanie prenos zapise')
    NxTest.refute(NxH7A::S.name_pending?(m))
    NxTest.assert_equal('', NxH7A::PC.pending_name_note(m))
    again = NxH7A::MODEL.new('C:/Zakazky/L.skp', 'REOPEN-2')
    NxTest.assert_equal('Zakazka L', NxH7A::S.project_name(again), 'po oprave nazov ostane')
  end
end

NxTest.test('H7a T-A11: zdravy subor — name_pending? nikdy true, exporty bez vety') do
  NxTest.skip!('vyzaduje headless sandbox') unless NxTest.headless?
  NxH7A.with_sandbox do
    m = NxH7A.named_unsaved('Zdrava')
    NxTest.refute(NxH7A::S.name_pending?(m), 'neulozeny')
    m.path = 'C:/Zakazky/Zdrava.skp'
    NxTest.assert_equal('Zdrava', NxH7A::S.project_name(m))
    NxTest.refute(NxH7A::S.name_pending?(m), 'po prenose')
    NxTest.refute(NxH7A::S.name_pending?(NxH7A.model), 'bez nazvu')
    msg, = NxH7A.export_status(:do_hw_csv, m)
    NxTest.refute(msg.include?('pozor: názov zákazky'), msg)
  end
end

# =============================================================================
# T-A9 GUARDY (presun bez delegatov, jedine dvere, ziadna pravdivost)
# =============================================================================

module NxH7A
  ES_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'export_settings.rb'), encoding: 'UTF-8')
  MOVED = %i[vepo_settings_path vepo_settings vepo_settings_for_write update_vepo_settings save_vepo_settings
             refresh_vepo_settings project_names update_project_names normalize_project_path
             project_session_key session_key? remember_session_key forget_session_key remembered_session_key
             session_keys_for project_key project_name adopt_session_name effective_project_name
             default_project_name save_project_name merge_18_36 save_merge_18_36 name_pending?
             write_gate doc_shape_ok? shape_check note_block written?].freeze
  MOVED_CONSTS = %i[VEPO_SETTINGS_FILE PROJECT_NAMES_KEY PROJECT_NAME_MAX SESSION_KEY_PREFIX
                    SESSION_KEY_BRIDGE SESSION_BRIDGE_MAX ADOPT_RETRY LAST_BLOCK DEGRADED_REASON
                    UNREADABLE_REASON FAILED_REASON NotObject].freeze

  module_function

  def code(src)
    src.lines.map { |l| l.sub(/#.*$/, '') }.join
  end

  def body(src, name)
    src[/def #{Regexp.escape(name)}\b.*?\n      end\n/m].to_s
  end

  def plugin_rb_files
    Dir[File.join(NxTest::ROOT, 'noxun_engine', '{core,ui}', '**', '*.rb')]
  end
end

NxTest.test('H7a T-A9: ProductionCore po presune NEMA nastavenia exportu (ziadne delegaty ani konstanty)') do
  pc = NxH7A::PC
  left = NxH7A::MOVED.select { |m| pc.respond_to?(m) }
  NxTest.assert(left.empty?, "ProductionCore stale odpoveda na: #{left.join(', ')}")
  consts = NxH7A::MOVED_CONSTS.select { |c| pc.const_defined?(c, false) }
  NxTest.assert(consts.empty?, "ProductionCore stale ma konstanty: #{consts.join(', ')}")
  NxTest.assert(pc.respond_to?(:model_guid), 'model_guid ostava v ProductionCore')
  NxTest.assert(pc.respond_to?(:pending_name_note), 'veta po exporte je text exportu (ProductionCore)')
  es = NxH7A::S
  %i[path doc_shape_ok? shape_check read refresh write_gate update save written? project_names
     update_project_names normalize_project_path project_session_key session_key? remember_session_key
     forget_session_key remembered_session_key session_keys_for project_key effective_project_name
     default_project_name project_name save_project_name merge_18_36 save_merge_18_36 last_dir save_last_dir
     name_pending?].each { |m| NxTest.assert(es.respond_to?(m), "ExportSettings.#{m}") }
  NxTest.assert_equal('vepo_settings.json', es::FILE, 'meno suboru bez zmeny')
  NxTest.assert_equal('projekt', es::DEFAULT_PROJECT_NAME)
  NxTest.assert_equal(120, es::PROJECT_NAME_MAX)
  NxTest.assert_equal('guid:', es::SESSION_KEY_PREFIX)
end

NxTest.test('H7a T-A9: mimo export_settings.rb nikto necita vepo_settings ani VEPO_SETTINGS_FILE') do
  bad = NxH7A.plugin_rb_files.reject { |f| f.end_with?('export_settings.rb') }.select do |f|
    src = NxH7A.code(File.read(f, encoding: 'UTF-8'))
    src.match?(/\bvepo_settings\b(?!\.json|\.poskodeny)/) || src.include?('VEPO_SETTINGS_FILE')
  end
  NxTest.assert(bad.empty?, "druha cesta k suboru nastaveni: #{bad.map { |f| File.basename(f) }.join(', ')}")
end

NxTest.test('H7a T-A9: jedine dvere zapisu — zamok, brana, strikne citanie, zapis s predikatom tvaru') do
  src = NxH7A.code(NxH7A::ES_RB)
  NxTest.assert_equal(1, src.scan('JsonFileStore.write(').length, 'v module JEDINY zapis suboru')
  upd = NxH7A.body(NxH7A::ES_RB, 'update')
  NxTest.assert(upd.include?('JsonFileStore.write(path, fresh.merge(attrs), shape_check)'),
                'zapis v `update`, treti POZICNY argument = shape_check')
  i_lock = upd.index('Materials.with_catalog_lock')
  i_gate = upd.index('write_gate')
  i_read = upd.index('read_for_write')
  i_write = upd.index('JsonFileStore.write(')
  NxTest.assert(i_lock && i_gate && i_read && i_write && i_lock < i_gate && i_gate < i_read && i_read < i_write,
                'poradie zamok -> brana -> citanie -> zapis')
  NxTest.assert(NxH7A.body(NxH7A::ES_RB, 'save').include?('update { attrs }'), 'save ide cez update')
  NxTest.assert(NxH7A.body(NxH7A::ES_RB, 'update_project_names').include?('update do |settings|'),
                'mapa nazvov ide cez update')
  NxTest.assert(NxH7A.body(NxH7A::ES_RB, 'read').include?('JsonFileStore.read_valid('), 'read cita s tvarom')
  gate = NxH7A.body(NxH7A::ES_RB, 'write_gate')
  NxTest.assert(gate.include?('JsonFileStore.reload!("#{file}.bak")'), 'brana zhodi aj cache zalohy')
  NxTest.assert(gate.include?('JsonFileStore.degraded?(file, shape: shape_check)'), 'brana s tvarom')
end

NxTest.test('H7a T-A9: vysledok zapisu sa NIKDY nerozhoduje pravdivostou (ui/ a core/)') do
  writers = 'save_project_name|save_merge_18_36|save_last_dir|save|update|update_project_names'
  pre = /(?:\bif|\bunless|&&|\|\||!)\s*\(?\s*ExportSettings\.(?:#{writers})\b/
  post = /ExportSettings\.(?:#{writers})\b(?:\([^()\n]*\))?\s*(?:\?|&&|\|\|)/
  hits = NxH7A.plugin_rb_files.flat_map do |f|
    NxH7A.code(File.read(f, encoding: 'UTF-8')).lines.each_with_index.select do |l, _i|
      l.match?(pre) || l.match?(post)
    end.map { |l, i| "#{File.basename(f)}:#{i + 1}: #{l.strip}" }
  end
  NxTest.assert(hits.empty?, "pravdivost nad [status, reason]: #{hits.join(' | ')}")
end

NxTest.test('H7a T-A9: kluc sedenia sa presunom nezmenil — doc_token == ProductionCore.model_guid') do
  m = NxH7A::MODEL.new('', 'TOKEN')
  NxTest.assert_equal(NxH7A::PC.model_guid(m), NxH7A::S.doc_token(m))
  NxTest.assert_equal("guid:#{NxH7A::PC.model_guid(m)}", NxH7A::S.project_session_key(m))
  NxTest.assert_equal('', NxH7A::S.doc_token(nil))
  tok = NxH7A.body(NxH7A::ES_RB, 'doc_token')
  NxTest.assert(tok.include?('DocKey.key(model)') && tok.include?('rescue StandardError'), 'doc_token = model_guid')
  dk = Noxun::Engine::DocKey.singleton_class
  dk.send(:alias_method, :h7a_orig_key, :key)
  begin
    dk.send(:define_method, :key) { |_m| raise 'identita (test)' }
    NxTest.assert_equal('', NxH7A::S.project_session_key(m), 'chyba identity = prazdny kluc, nie vynimka')
  ensure
    dk.send(:remove_method, :key)
    dk.send(:alias_method, :key, :h7a_orig_key)
    dk.send(:remove_method, :h7a_orig_key)
  end
end

NxTest.test('H7a T-A9: nacitanie — main.rb aj helper poznaju modul (po materials/doc_key, pred production_core)') do
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  i_es = main.index("Sketchup.require 'noxun_engine/core/export_settings'")
  i_mat = main.index("Sketchup.require 'noxun_engine/core/materials'")
  i_dk = main.index("Sketchup.require 'noxun_engine/core/doc_key'")
  i_pc = main.index("Sketchup.require 'noxun_engine/ui/production_core'")
  NxTest.assert(i_es && i_mat && i_dk && i_pc && i_mat < i_es && i_dk < i_es && i_es < i_pc, 'poradie v main.rb')
  helper = File.read(File.join(NxTest::ROOT, 'tests', 'helper.rb'), encoding: 'UTF-8')
  NxTest.assert(helper.include?('core/export_settings'), 'helper ho nacita headless')
  dk = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'doc_key.rb'), encoding: 'UTF-8')
  NxTest.assert(dk.include?('ExportSettings.forget_session_key(model) if defined?(ExportSettings)'),
                'vymena dokumentu zahadzuje most v ExportSettings')
end
