# frozen_string_literal: true
# Testy KOV-B1: TAXONOMIA VYROBCOV A RAD KOVANIA (core/hardware_taxonomy.rb).
#
# PRECO EXISTUJE: set aj polozka katalogu od KOV-B1 nesu `manufacturer` a
# (nepovinne) `series`. Bez jedneho zoznamu pripustnych mien by v katalogu za
# mesiac boli „Hettich" / „hettich" / „Hettch" a strom (KOV-B2) ani filtre
# (KOV-D) by na nich nesadli.
#
# Co tieto testy strazia (audit #17 BLOCKER 4 + FIX 10 / register R-35):
#   * matica stavov `:ok / :degraded / :read_only` (cudzi std, novsia schema,
#     neznamy tvar, duplicita, rada bez vyrobcu, poskodeny primar s `.bak`)
#     — a `load` z read-only NIKDY nevyda obsah ani seed;
#   * identita mena je CASE-INSENSITIVE a BEZ DIAKRITIKY (`Materials.slug`);
#   * rada patri PRESNE JEDNEMU vyrobcovi (slug rady je globalne unikatny);
#   * API je LEN create — `create_manufacturer!` / `create_series!` — s
#     reviziou (`:conflict`), fresh-read pod zamkom a `:write_failed` pri
#     zlyhanom zamku;
#   * seed sa doplna MERGE-SAFE, je idempotentny a nad read-only sa NEROBI;
#   * zamok naozaj serializuje DVA OS PROCESY (nie len monkeypatch).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

module NxB1Tax
  E     = Noxun::Engine
  TAX   = E::HardwareTaxonomy
  STORE = E::JsonFileStore
  MAT   = E::Materials

  module_function

  # --- sandbox ------------------------------------------------------------

  def with_taxonomy
    path = TAX.path
    before = (File.binread(path) if File.exist?(path))
    bak = (File.binread("#{path}.bak") if File.exist?("#{path}.bak"))
    yield path
  ensure
    if before then File.binwrite(path, before) else FileUtils.rm_f(path) end
    if bak then File.binwrite("#{path}.bak", bak) else FileUtils.rm_f("#{path}.bak") end
    STORE.invalidate(path)
    TAX.reset_state!
  end

  # Zapise dokument PRIAMO na disk (obide brany) a zhodi cache aj stav.
  def install(doc)
    FileUtils.mkdir_p(File.dirname(TAX.path))
    File.binwrite(TAX.path, doc.is_a?(String) ? doc : JSON.pretty_generate(doc))
    STORE.invalidate(TAX.path)
    TAX.reset_state!
    true
  end

  def wipe!
    FileUtils.rm_f(TAX.path)
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
  end

  def raw
    JSON.parse(File.binread(TAX.path))
  end

  def doc(mans, sers = [], over = {})
    { 'std' => TAX::STD, 'schema' => TAX::SCHEMA_CURRENT,
      'seed_version' => TAX::SEED_VERSION,
      'manufacturers' => mans.map { |n| { 'name' => n } },
      'series' => sers.map { |(n, m)| { 'name' => n, 'manufacturer' => m } } }.merge(over)
  end

  def with_broken_lock
    orig = MAT.method(:with_catalog_lock)
    MAT.define_singleton_method(:with_catalog_lock) do |&_blk|
      raise Errno::EACCES, 'materials.lock (test)'
    end
    yield
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end
end

# ============================================================================
# 1) SEED
# ============================================================================

NxTest.test('KOV-B1 taxonomia: prve pouzitie SEEDNE zoznam a je idempotentne') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.wipe!
    names = t::TAX.manufacturers.map { |m| m['name'] }
    NxTest.assert_equal(%w[Blum Grass Hettich Ostatné Strong], names,
                        'seed v1: vyrobcovia (poradie je deterministicke)')
    NxTest.assert_equal(%w[AVENTOS CLIP\ top LEGRABOX MERIVOBOX TANDEMBOX TIP-ON].sort,
                        t::TAX.series_of('Blum').map { |s| s['name'] }.sort)
    NxTest.assert_equal(t::TAX::SEED_VERSION, t.raw['seed_version'])
    NxTest.assert_equal(t::TAX::STD, t.raw['std'])
    before = File.binread(t::TAX.path)
    t::STORE.invalidate(t::TAX.path)
    t::TAX.load
    NxTest.assert_equal(before, File.binread(t::TAX.path),
                        'druhe pouzitie subor NEPREPISE (idempotentne)')
  end
end

NxTest.test('KOV-B1 taxonomia: seed-merge doplna LEN chybajuce a nic neprepisuje') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    # subor zo STARSIEHO seedu (seed_version 0) s vlastnym vyrobcom
    t.install(t.doc(['Hettich', 'Moja Firma'], [['Sensys', 'Hettich']], 'seed_version' => 0))
    names = t::TAX.manufacturers.map { |m| m['name'] }
    NxTest.assert(names.include?('Moja Firma'), 'pouzivatelsky vyrobca PREZIL')
    NxTest.assert(names.include?('Blum'), 'a chybajuci seed sa doplnil')
    NxTest.assert_equal(1, names.count('Hettich'), 'existujuci sa NEZDVOJIL')
    NxTest.assert_equal('Hettich', t::TAX.find_series('Sensys')['manufacturer'],
                        'vazba rady sa nemenila')
  end
end

NxTest.test('KOV-B1 taxonomia: nad READ-ONLY suborom sa seed NEROBI a `load` nevyda nic') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(['Cudzi'], [], 'std' => 'iny-system', 'seed_version' => 0))
    before = File.binread(t::TAX.path)
    NxTest.assert_equal(:read_only, t::TAX.state)
    NxTest.assert_equal({ 'manufacturers' => [], 'series' => [] }, t::TAX.load,
                        'PRAZDNO, nikdy seed (cudzie defaulty by prvy zapis zvecnil)')
    NxTest.assert_equal(before, File.binread(t::TAX.path), 'subor ostal BAJT NA BAJT')
  end
end

# ============================================================================
# 2) MATICA STAVOV
# ============================================================================

NxTest.test('KOV-B1 taxonomia: matica stavov (cudzi std, novsia schema, tvar, duplicita)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    cases = {
      foreign: t.doc(['Hettich'], [], 'std' => 'iny-system'),
      newer: t.doc(['Hettich'], [], 'schema' => t::TAX::SCHEMA_CURRENT + 1),
      unknown_shape: t.doc(['Hettich'], [], 'manufacturers' => [{ 'name' => 'Hettich', 'logo' => 'x' }]),
      duplicate: t.doc(%w[Hettich hettich])
    }
    cases.each do |code, document|
      t.install(document)
      NxTest.assert_equal(:read_only, t::TAX.state, "#{code}: musi byt read-only")
      NxTest.assert_equal(code, t::TAX.state_code, "#{code}: kod dovodu")
      NxTest.assert(!t::TAX.state_reason.empty?, "#{code}: dovod je SK veta")
      NxTest.assert_equal([], t::TAX.manufacturers, "#{code}: a nic sa nevyda")
    end
    # rada bez existujuceho vyrobcu = rozbita integrita
    t.install(t.doc(['Hettich'], [['Nova Pro', 'Grass']]))
    NxTest.assert_equal(:read_only, t::TAX.state)
    NxTest.assert_equal(:unknown_shape, t::TAX.state_code)
    NxTest.assert(t::TAX.state_reason.include?('bez výrobcu'), t::TAX.state_reason)
    # ta ista rada pod DVOMA vyrobcami = nejednoznacna identita
    # (`state_code` je VYSLEDOK poslednej kontroly — vyhodnocuje `state`)
    t.install(t.doc(%w[Hettich Blum], [['Sensys', 'Hettich'], ['sensys', 'Blum']]))
    NxTest.assert_equal(:read_only, t::TAX.state)
    NxTest.assert_equal(:duplicate, t::TAX.state_code, 'slug rady je GLOBALNE unikatny')
    # zdravy subor
    t.install(t.doc(%w[Hettich], [['Sensys', 'Hettich']]))
    NxTest.assert_equal(:ok, t::TAX.state)
    NxTest.assert_equal('', t::TAX.state_reason)
  end
end

NxTest.test('KOV-B1 taxonomia: poskodeny primar s platnou `.bak` = DEGRADED (cita, nezapisuje)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich], [['Sensys', 'Hettich']]))
    FileUtils.cp(t::TAX.path, "#{t::TAX.path}.bak")
    File.binwrite(t::TAX.path, '{ toto nie je JSON')
    t::STORE.invalidate(t::TAX.path)
    t::TAX.reset_state!
    NxTest.assert_equal(:degraded, t::TAX.state)
    NxTest.assert_equal(:degraded, t::TAX.state_code)
    NxTest.assert(t::TAX.write_blocked?, 'zapisy do SUBORU stoja')
    NxTest.refute(t::TAX.read_only?, 'ale obsah zalohy sa CITAT smie')
    NxTest.assert_equal(['Hettich'], t::TAX.manufacturers.map { |m| m['name'] },
                        'cita sa zaloha')
    NxTest.assert_equal([], t::TAX.check_classification('Hettich', 'Sensys'),
                        'a kontrola klasifikacie nad nou bezi')
    before = File.binread(t::TAX.path)
    NxTest.assert_equal(:write_failed, t::TAX.create_manufacturer!('Nova')[0])
    NxTest.assert_equal(before, File.binread(t::TAX.path), 'primar sa NEPREPISAL zalohou')
  end
end

NxTest.test('KOV-B1 taxonomia: chybajuci subor je CISTY stav, nie chyba') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.wipe!
    NxTest.assert_equal([:ok, nil, ''], t::TAX.assess_doc(nil))
    NxTest.assert_equal(:ok, t::TAX.state)
  end
end

# ============================================================================
# 3) IDENTITA MENA + INTEGRITA RADY
# ============================================================================

NxTest.test('KOV-B1 taxonomia: identita mena je CI a bez diakritiky') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich]))
    %w[Hettich hettich HETTICH HeTtIcH].each do |variant|
      NxTest.assert_equal('Hettich', t::TAX.find_manufacturer(variant)['name'],
                          "#{variant} je ten isty vyrobca")
      NxTest.assert_equal([:exists, { 'name' => 'Hettich' }], t::TAX.create_manufacturer!(variant),
                          "#{variant} sa uz NEZALOZI druhy raz")
    end
    # diakritika: „Ostatné" a „Ostatne" su to iste meno
    t.install(t.doc(['Ostatné']))
    NxTest.assert_equal(:exists, t::TAX.create_manufacturer!('ostatne')[0])
    NxTest.assert_equal('Ostatné', t::TAX.find_manufacturer('OSTATNE')['name'],
                        'zobrazuje sa PRVE zapisane znenie')
  end
end

NxTest.test('KOV-B1 taxonomia: rada patri PRESNE jednemu vyrobcovi') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich Blum], [['Sensys', 'Hettich']]))
    NxTest.assert_equal(:exists, t::TAX.create_series!('sensys', 'HETTICH')[0],
                        'ta ista rada pod TYM ISTYM vyrobcom = uz existuje')
    status, msg = t::TAX.create_series!('Sensys', 'Blum')
    NxTest.assert_equal(:invalid, status, 'pod INYM vyrobcom = chyba, nikdy tichy presun')
    NxTest.assert(msg.include?('Hettich'), "dovod MENUJE vlastnika: #{msg}")
    NxTest.assert_equal('Hettich', t::TAX.find_series('Sensys')['manufacturer'],
                        'a vazba sa NEZMENILA')
    NxTest.assert_equal(:invalid, t::TAX.create_series!('Nova Pro', 'Grass')[0],
                        'rada bez existujuceho vyrobcu sa nezalozi')
    NxTest.assert_equal([:ok, { 'name' => 'Quadro', 'manufacturer' => 'Hettich' }],
                        t::TAX.create_series!('Quadro', 'hettich'),
                        'vyrobca sa hlada CI a uklada sa jeho KANONICKY nazov')
  end
end

NxTest.test('KOV-B1 taxonomia: prazdne a nezmyselne mena sa odmietaju') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich]))
    NxTest.assert_equal(:invalid, t::TAX.create_manufacturer!('   ')[0])
    NxTest.assert_equal(:invalid, t::TAX.create_manufacturer!('---')[0], 'bez pismena a cislice')
    NxTest.assert_equal(:invalid, t::TAX.create_manufacturer!('x' * (t::TAX::MAX_NAME + 1))[0])
    NxTest.assert_equal(:invalid, t::TAX.create_series!('Sensys', '  ')[0], 'rada bez vyrobcu')
  end
end

# ============================================================================
# 4) check_classification (kontrakt pre sety aj katalog)
# ============================================================================

NxTest.test('KOV-B1 taxonomia: `check_classification` vracia pole {field, msg}') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich Blum], [['Sensys', 'Hettich']]))
    NxTest.assert_equal([], t::TAX.check_classification('', ''), 'nezaradene sa nekontroluje')
    NxTest.assert_equal([], t::TAX.check_classification('Hettich', ''), 'rada je volitelna')
    NxTest.assert_equal([], t::TAX.check_classification('hettich', 'SENSYS'), 'CI zhoda')
    bad = t::TAX.check_classification('Vymyslena', '')
    NxTest.assert_equal('manufacturer', bad.first['field'])
    NxTest.assert(bad.first['msg'].include?('Vymyslena'))
    bad2 = t::TAX.check_classification('Blum', 'Sensys')
    NxTest.assert_equal('series', bad2.first['field'])
    NxTest.assert(bad2.first['msg'].include?('Hettich'), bad2.inspect)
    bad3 = t::TAX.check_classification('Hettich', 'Neznama')
    NxTest.assert_equal('series', bad3.first['field'])
    NxTest.assert_equal([{ 'field' => 'manufacturer',
                           'msg' => 'rada „Sensys“ sa nedá priradiť bez výrobcu' }],
                        t::TAX.check_classification('', 'Sensys'))
  end
end

# ============================================================================
# 5) ZAMOK, REVIZIA, ZLYHANIE ZAPISU
# ============================================================================

NxTest.test('KOV-B1 taxonomia: revizia — cudzia zmena medzitym konci `:conflict`') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich]))
    doc, rev = t::TAX.load_with_revision
    NxTest.assert_equal(['Hettich'], doc['manufacturers'].map { |m| m['name'] })
    NxTest.assert_equal(:ok, t::TAX.create_manufacturer!('Blum', revision: rev)[0],
                        'pripnuta revizia sedi')
    NxTest.assert_equal([:conflict, nil], t::TAX.create_manufacturer!('Grass', revision: rev),
                        'ta ista (uz zastarana) revizia druhy raz neprejde')
    NxTest.assert_equal([:conflict, nil], t::TAX.create_series!('Tiomos', 'Hettich', revision: rev))
    NxTest.refute(t::TAX.manufacturers.map { |m| m['name'] }.include?('Grass'),
                  'a nic sa nezapisalo')
  end
end

NxTest.test('KOV-B1 taxonomia: NEZISKANY zamok konci `:write_failed`, nikdy tichym uspechom') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    t.install(t.doc(%w[Hettich]))
    before = File.binread(t::TAX.path)
    t.with_broken_lock do
      NxTest.assert_equal([:write_failed, nil], t::TAX.create_manufacturer!('Blum'))
      NxTest.assert_equal([:write_failed, nil], t::TAX.create_series!('Sensys', 'Hettich'))
      NxTest.refute(t::TAX.write([{ 'name' => 'X' }], []), '`write` = false')
    end
    NxTest.assert_equal(before, File.binread(t::TAX.path), 'subor sa nezmenil')
  end
end

NxTest.test('KOV-B1 taxonomia: zamok blokuje DRUHY PROCES (nie len monkeypatch)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  t = NxB1Tax
  t.with_taxonomy do
    # Jediny sposob, ako na Windows overit, ze `flock` naozaj serializuje dve
    # instancie: druhy OS proces si vezme ten isty sidecar `materials.lock`,
    # drzi ho, zapise a az potom pusti (vzor test_r08_zamky.rb sekcia 6).
    dir = t::MAT.dir
    FileUtils.mkdir_p(dir)
    t.install(t.doc(%w[Hettich]))
    cudzi = JSON.pretty_generate(t.doc(%w[Hettich OdProcesu]))
    ready = File.join(dir, 'b1tax_druhy_proces.ready')
    FileUtils.rm_f(ready)
    script = <<~RUBY
      dir, ready, payload = ARGV
      path = File.join(dir, 'hardware_taxonomy.json')
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
    pid = Process.spawn(RbConfig.ruby, '-e', script, dir, ready, cudzi)
    begin
      deadline = Time.now + 15
      sleep 0.05 until File.exist?(ready) || Time.now > deadline
      NxTest.assert(File.exist?(ready), 'druhy proces zamok drzi')
      NxTest.assert_equal(:ok, t::TAX.create_manufacturer!('Nas')[0], 'nas zapis presiel')
    ensure
      Process.waitpid(pid)
      FileUtils.rm_f(ready)
    end
    names = t::TAX.manufacturers.map { |m| m['name'] }
    NxTest.assert(names.include?('OdProcesu'),
                  "nas zapis POCKAL a cudzieho vyrobcu nechal zit: #{names.inspect}")
    NxTest.assert(names.include?('Nas'), 'a nas vyrobca sadol')
  end
end

# ============================================================================
# 6) KONTRAKT ZDROJA (mutacne guardy)
# ============================================================================

NxTest.test('KOV-B1 taxonomia: do suboru zapisuje JEDINE miesto a to POD zamkom') do
  src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_taxonomy.rb'))
            .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  NxTest.assert_equal(1, src.scan(/JsonFileStore\.write\(/).length,
                      'jeden zapisovatel = jedna brana')
  body = src[/^      def write\(.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo `write` sa naslo')
  NxTest.assert(body.include?('with_catalog_lock'), '`write` berie zamok')
  NxTest.assert(body.index('with_catalog_lock').to_i < body.index('JsonFileStore.write(').to_i,
                'a zapis je AZ POD nim')
  NxTest.assert(body.index('JsonFileStore.reload!').to_i < body.index('JsonFileStore.write(').to_i,
                'subor sa pod zamkom cita NANOVO (cachovane :ok nie je dokaz)')
  # rename/delete su MIMO V1 (R-35) — ich absencia je kontrakt, nie nedostatok
  NxTest.refute(src.include?('def rename_'), 'premenovanie vo V1 NEEXISTUJE')
  NxTest.refute(src.include?('def delete_'), 'mazanie vo V1 NEEXISTUJE')
  %w[create_manufacturer! create_series!].each do |m|
    door = src[/^      def #{Regexp.escape(m)}.*?\n      end\n/m].to_s
    NxTest.assert(!door.empty?, "telo `#{m}` sa naslo")
    lock = door.index('with_catalog_lock')
    check = door.index('revision != self.revision')
    NxTest.assert(lock && check, "#{m}: zamok aj kontrola revizie su v tele")
    NxTest.assert(lock < check, "#{m}: revizia sa porovnava AZ POD zamkom")
    NxTest.assert(door.include?('rescue StandardError'), "#{m}: zlyhany zamok neuletí ako vynimka")
  end
end
