# frozen_string_literal: true
# Testy H10b/R-35 — DVE OKNA SKETCHUPU A ROZMEROVE RADY.
#
# Do H10b zapisoval panel rozmerove rady (`dim_series.json`, koliesko
# Inspectora) UPLNOU NAHRADOU: „Uložiť rady" posielalo VSETKYCH 5 radov tak,
# ako ich panel dostal pri otvoreni. Dve okna sa prebijali „posledny vyhrava"
# a zmena prveho zanikla bez slova (sonda P2: A prida 700 do sirok, B zmeni
# len hlbky -> 700 je prec).
#
# Co davka garantuje a co tieto testy overuju:
#   C   jedno okno — rady sa zapisu BAJTOVO rovnako ako doteraz;
#   B1  dva klienti — rozne rady sa zlucia, ten isty rad = konflikt a NIC sa
#       nezapise (ani nekonfliktne rady), bez zmeny bez zapisu, starsi DOM
#       (bez povodnych hodnot) = `:stale_client`, degradovany subor = brana;
#   B2  hranice zlucenia (R2.7) — vyprazdneny rad, chybajuci kluc v subore,
#       neznamy kluc od klienta aj v subore (dnesne obmedzenie, nie sluba);
#   B3  `handle_set_dim_series` — kazda vetva = text + prekreslenie editora;
#       strukturalne guardy (panel nevola `set(`, revizia AZ POD zamkom).
#
# MUTACIE overene proti tejto sade + `tests/js/test_h10b_rady.js` su v PR.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'
require 'tmpdir'
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_settings') if NxTest.headless?

module NxH10b
  E     = Noxun::Engine
  DIM   = E::DimSeries
  STORE = E::JsonFileStore

  module_function

  # Ulozi primar aj `.bak` radov, spusti blok a vrati PRESNY povodny stav.
  def with_file
    NxTest.skip!('katalogove/APPDATA testy bezia len headless') unless NxTest.headless?
    paths = [DIM.path, "#{DIM.path}.bak"]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    paths.each { |p| FileUtils.rm_f(p) }
    STORE.reload!(DIM.path)
    DIM.instance_variable_set(:@write_block_reason, '')
    yield
  ensure
    before&.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
    end
    STORE.reload!(DIM.path)
    DIM.instance_variable_set(:@write_block_reason, '')
  end

  def bytes(path = DIM.path)
    File.exist?(path) ? File.binread(path) : nil
  end

  def files
    [bytes(DIM.path), bytes("#{DIM.path}.bak")]
  end

  def defaults
    DIM.normalize(nil)
  end

  # Zdroj modulu bez rozdielu koncov riadkov (pracovna kopia CRLF, CI LF).
  def src(rel)
    File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel))
        .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  def body(rel, name, indent = 6)
    src(rel)[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end

  # Panel headless: stuby nasadene LEN pocas bloku (vzor NxR11PanelStub) —
  # zachyti status aj priznak prekreslenia editora.
  PANEL_STUBS = %i[parse push_ui_settings set_status].freeze

  def with_panel
    NxTest.skip!('handler panela sa testuje headless (v SketchUpe je Panel zivy)') unless NxTest.headless?
    panel = E::Panel
    orig = {}
    log = { status: nil, refill: [] }
    PANEL_STUBS.each { |m| orig[m] = panel.method(m) if panel.respond_to?(m) }
    panel.define_singleton_method(:parse) { |payload| JSON.parse(payload.to_s) }
    panel.define_singleton_method(:push_ui_settings) { |refill_editor: false| log[:refill] << refill_editor }
    panel.define_singleton_method(:set_status) { |msg, error = false| log[:status] = [msg, error] }
    yield panel, log
  ensure
    PANEL_STUBS.each do |m|
      if orig && orig[m]
        panel.define_singleton_method(m, orig[m])
      elsif panel
        panel.singleton_class.send(:remove_method, m) if panel.singleton_class.method_defined?(m)
      end
    end
  end

  def save(panel, series, base)
    payload = { 'series' => series }
    payload['base'] = base unless base == :none
    panel.handle_set_dim_series(JSON.generate(payload))
  end
end

# =============================================================================
# C · charakterizacia
# =============================================================================

NxTest.test('H10b C2: jedno okno — `set` zapise rady presne v dnesnom tvare') do
  r = NxH10b
  r.with_file do
    full = r.defaults.merge('sirka' => [400, 450, 500, 600, 700, 800, 900])
    stored = r::DIM.set(full)
    NxTest.assert_equal(r::DIM.normalize(full), stored, 'set vrati ulozene rady')
    want = JSON.pretty_generate('std' => r::DIM::STD, 'series' => r::DIM.normalize(full))
    NxTest.assert_equal(want, r.bytes, 'bajty = {std, series: normalize(rady)}')
  end
end

NxTest.test('H10b C2: `update!` jedneho radu zapise TIE ISTE bajty ako `set` celych radov') do
  r = NxH10b
  full = r.defaults.merge('sirka' => [400, 450, 500, 600, 700, 800, 900])
  want = nil
  r.with_file do
    r::DIM.set(full)
    want = r.bytes
  end
  r.with_file do
    status, series, keys = r::DIM.update!({ 'sirka' => full['sirka'] }, { 'sirka' => r::DIM::DEFAULTS['sirka'] })
    NxTest.assert_equal(:ok, status)
    NxTest.assert_equal(['sirka'], keys, 'zmeneny je len rad sirok')
    NxTest.assert_equal(r::DIM.normalize(full), series, 'vratene rady = ulozene')
    NxTest.assert_equal(want, r.bytes, 'jedno okno = bajtovo rovnaky subor')
  end
end

# =============================================================================
# B1 · dva klienti
# =============================================================================

NxTest.test('H10b B1: ROZNE rady z dvoch okien sa zlucia (sonda P2 uz nestrati 700)') do
  r = NxH10b
  r.with_file do
    seen = r::DIM.get # obe okna otvorili panel nad tymi istymi radmi
    sa, _, ka = r::DIM.update!({ 'sirka' => seen['sirka'] + [700] }, { 'sirka' => seen['sirka'] })
    NxTest.assert_equal([:ok, ['sirka']], [sa, ka], 'okno A ulozilo siroky')
    sb, series, kb = r::DIM.update!({ 'hlbka' => [300, 600] }, { 'hlbka' => seen['hlbka'] })
    NxTest.assert_equal([:ok, ['hlbka']], [sb, kb], 'okno B ulozilo hlbky BEZ konfliktu')
    NxTest.assert(series['sirka'].include?(700), "700 z okna A prezilo: #{series['sirka'].inspect}")
    NxTest.assert_equal([300, 600], series['hlbka'])
    disk = JSON.parse(File.binread(r::DIM.path))['series']
    NxTest.assert(disk['sirka'].include?(700) && disk['hlbka'] == [300, 600], 'na disku su obe zmeny')
  end
end

NxTest.test('H10b B1: TEN ISTY rad = konflikt a NEZAPISE SA NIC (ani nekonfliktny rad)') do
  r = NxH10b
  r.with_file do
    seen = r::DIM.get
    r::DIM.update!({ 'sokel' => [80, 100] }, { 'sokel' => seen['sokel'] })
    before = r.bytes
    status, current, keys = r::DIM.update!({ 'sokel' => [150, 200], 'hlbka' => [600] },
                                           { 'sokel' => seen['sokel'], 'hlbka' => seen['hlbka'] })
    NxTest.assert_equal(:conflict, status)
    NxTest.assert_equal(['sokel'], keys, 'konfliktny je LEN rad, ktory zmenilo ine okno')
    NxTest.assert_equal([80, 100], current['sokel'], 'vrati sa AKTUALNY ulozeny stav')
    NxTest.assert_equal(before, r.bytes, 'subor bajtovo nezmeneny — ani hlbky sa nezapisali')
  end
end

NxTest.test('H10b B1: cudzi zapis tesne pred zamkom (sekundova cache ho nevidi) = konflikt') do
  r = NxH10b
  r.with_file do
    r::DIM.set(r.defaults)
    seen = r::DIM.get # nahreje cache
    other = { 'std' => 1, 'series' => r.defaults.merge('sirka' => [555]) }
    orig = r::E::Materials.method(:with_catalog_lock)
    fired = false
    path = r::DIM.path
    r::E::Materials.define_singleton_method(:with_catalog_lock) do |&blk|
      unless fired
        fired = true
        File.binwrite("#{path}.tmp-other", JSON.pretty_generate(other))
        File.rename("#{path}.tmp-other", path)
      end
      orig.call(&blk)
    end
    begin
      status, current, keys = r::DIM.update!({ 'sirka' => [600] }, { 'sirka' => seen['sirka'] })
    ensure
      r::E::Materials.define_singleton_method(:with_catalog_lock, orig)
    end
    NxTest.assert(fired, 'druha instancia zapisala')
    NxTest.assert_equal([:conflict, ['sirka']], [status, keys], 'revizia sa porovnava proti CERSTVEMU suboru')
    NxTest.assert_equal([555], current['sirka'])
    NxTest.assert_equal([555], JSON.parse(File.binread(path))['series']['sirka'], 'cudzia hodnota prezila')
  end
end

NxTest.test('H10b B1: bez skutocnej zmeny sa NEZAPISUJE (ani subor nevznikne)') do
  r = NxH10b
  r.with_file do
    d = r::DIM::DEFAULTS
    status, series, keys = r::DIM.update!({ 'sirka' => d['sirka'].reverse.map(&:to_s) }, { 'sirka' => d['sirka'] })
    NxTest.assert_equal([:ok, []], [status, keys], 'rovnaky obsah po normalizacii = ziadna zmena')
    NxTest.assert_equal(r.defaults, series)
    NxTest.assert_equal(false, File.exist?(r::DIM.path), 'subor sa nevytvoril')
    r::DIM.set(r.defaults)
    mtime = File.mtime(r::DIM.path)
    bytes = r.bytes
    sleep 0.02
    r::DIM.update!({ 'vyska' => d['vyska'] }, { 'vyska' => d['vyska'] })
    NxTest.assert_equal([mtime, bytes], [File.mtime(r::DIM.path), r.bytes], 'existujuci subor sa neprepisal')
  end
end

NxTest.test('H10b B1: okno bez povodnych hodnot (starsi DOM) = :stale_client, nic sa nezapise') do
  r = NxH10b
  r.with_file do
    r::DIM.set(r.defaults)
    before = r.bytes
    stale = [:stale_client, nil, []]
    NxTest.assert_equal(stale, r::DIM.update!({ 'sirka' => [600] }, nil), 'chybajuce base')
    NxTest.assert_equal(stale, r::DIM.update!(r.defaults, nil), 'stary DOM posiela vsetkych 5 radov bez base')
    NxTest.assert_equal(stale, r::DIM.update!([600], {}), 'changes nie je Hash')
    NxTest.assert_equal(stale, r::DIM.update!({ 'sirka' => [600] }, {}), 'meneny rad nema povodnu hodnotu')
    NxTest.assert_equal(stale, r::DIM.update!({ 'sirka' => [600] }, { 'sirka' => nil }), 'povodna hodnota null')
    NxTest.assert_equal(stale, r::DIM.update!({ 'sirka' => [600] }, { 'sirka' => '400, 450' }), 'povodna hodnota nie je pole')
    NxTest.assert_equal(before, r.bytes, 'subor nedotknuty')
  end
end

NxTest.test('H10b B1: degradovany subor = :blocked aj bez povodnych hodnot (brana ide prva)') do
  r = NxH10b
  r.with_file do
    FileUtils.mkdir_p(r::DIM.dir)
    File.binwrite("#{r::DIM.path}.bak", JSON.generate('std' => 1, 'series' => { 'sirka' => [123] }))
    File.binwrite(r::DIM.path, '{ poskodene')
    r::E::JsonFileStore.invalidate(r::DIM.path)
    before = r.files
    NxTest.assert_equal([:blocked, nil, []], r::DIM.update!({ 'sirka' => [400] }, nil))
    NxTest.assert(r::DIM.write_block_reason.include?('poškoden'), 'dovod brany je k dispozicii')
    NxTest.assert_equal([:blocked, nil, []],
                        r::DIM.update!({ 'sirka' => [400] }, { 'sirka' => [123] }), 'aj so spravnou povodnou hodnotou')
    NxTest.assert_equal(before, r.files, 'primar ani zaloha sa nezmenili')
  end
end

NxTest.test('H10b B1: zlyhanie zapisu a nezikany zamok = :write_failed (nikdy uspech)') do
  r = NxH10b
  r.with_file do
    blocker = File.join(Dir.mktmpdir('noxun-h10b-'), 'blok')
    File.binwrite(blocker, 'x')
    original = r::DIM.method(:path)
    begin
      r::DIM.define_singleton_method(:path) { File.join(blocker, 'dim_series.json') }
      NxTest.assert_equal([:write_failed, nil, []],
                          r::DIM.update!({ 'sirka' => [600] }, { 'sirka' => r::DIM::DEFAULTS['sirka'] }))
    ensure
      r::DIM.define_singleton_method(:path, original)
    end
    orig = r::E::Materials.method(:with_catalog_lock)
    r::E::Materials.define_singleton_method(:with_catalog_lock) { |&_b| raise IOError, 'zamok katalogu sa nepodarilo ziskat' }
    begin
      NxTest.assert_equal([:write_failed, nil, []],
                          r::DIM.update!({ 'sirka' => [600] }, { 'sirka' => r::DIM::DEFAULTS['sirka'] }))
    ensure
      r::E::Materials.define_singleton_method(:with_catalog_lock, orig)
    end
    NxTest.assert_equal(false, File.exist?(r::DIM.path), 'nic sa nezapisalo')
  end
end

NxTest.test('H10b B1: necitatelny subor (prava) NEPREPISE rady predvolbami') do
  r = NxH10b
  r.with_file do
    r::DIM.set(r.defaults.merge('sirka' => [777]))
    before = r.bytes
    store = r::E::JsonFileStore
    orig = store.method(:read)
    store.define_singleton_method(:read) { |*_a, **_k| raise Errno::EACCES, 'dim_series.json' }
    begin
      result = r::DIM.update!({ 'hlbka' => [600] }, { 'hlbka' => r::DIM::DEFAULTS['hlbka'] })
    ensure
      store.define_singleton_method(:read, orig)
    end
    NxTest.assert_equal([:write_failed, nil, []], result, 'chyba citania = neuspech, nie predvolena sada')
    NxTest.assert_equal(before, r.bytes, 'siroky 777 ostali')
  end
end

# =============================================================================
# B2 · hranice zlucenia (R2.7)
# =============================================================================

NxTest.test('H10b B2: vyprazdneny rad [] je platna hodnota — zapise sa a zluci') do
  r = NxH10b
  r.with_file do
    seen = r::DIM.get
    r::DIM.update!({ 'sirka' => seen['sirka'] + [700] }, { 'sirka' => seen['sirka'] })
    status, series, keys = r::DIM.update!({ 'vyska_cela' => [] }, { 'vyska_cela' => seen['vyska_cela'] })
    NxTest.assert_equal([:ok, ['vyska_cela']], [status, keys])
    NxTest.assert_equal([], series['vyska_cela'], 'rad je vypnuty')
    NxTest.assert(series['sirka'].include?(700), 'cudzi rad ostal')
    NxTest.assert_equal([], JSON.parse(File.binread(r::DIM.path))['series']['vyska_cela'])
  end
end

NxTest.test('H10b B2: chybajuci kluc v subore sa cita ako predvoleny (zhoda s povodnou hodnotou)') do
  r = NxH10b
  r.with_file do
    FileUtils.mkdir_p(r::DIM.dir)
    File.binwrite(r::DIM.path, JSON.generate('std' => 1, 'series' => { 'sirka' => [500] }))
    r::E::JsonFileStore.invalidate(r::DIM.path)
    status, series, = r::DIM.update!({ 'hlbka' => [600] }, { 'hlbka' => r::DIM::DEFAULTS['hlbka'] })
    NxTest.assert_equal(:ok, status, 'chybajuci kluc = predvolba = povodna hodnota klienta')
    NxTest.assert_equal([500], series['sirka'])
    NxTest.assert_equal([600], series['hlbka'])
  end
end

NxTest.test('H10b B2: neznamy kluc od klienta sa ignoruje') do
  r = NxH10b
  r.with_file do
    status, series, keys = r::DIM.update!({ 'hlupost' => [1, 2] }, {})
    NxTest.assert_equal([:ok, []], [status, keys], 'iba neznamy kluc = ziadna zmena')
    NxTest.assert_equal(false, File.exist?(r::DIM.path), 'nic sa nezapisalo')
    status, series, keys = r::DIM.update!({ 'hlupost' => [1, 2], 'sokel' => [90] },
                                          { 'sokel' => r::DIM::DEFAULTS['sokel'] })
    NxTest.assert_equal([:ok, ['sokel']], [status, keys])
    NxTest.assert_equal(r::DIM::KEYS.sort, series.keys.sort)
    NxTest.refute(JSON.parse(File.binread(r::DIM.path))['series'].key?('hlupost'), 'neznamy kluc sa nezapisal')
  end
end

NxTest.test('H10b B2: neznamy kluc v SUBORE zapis zahodi (DNESNE OBMEDZENIE — ziadna ochrana novsieho formatu)') do
  # Tento test POTVRDZUJE obmedzenie, neslubuje ochranu: buduci kluc radov
  # je vlastna davka s branou `std` (R2.7).
  r = NxH10b
  r.with_file do
    FileUtils.mkdir_p(r::DIM.dir)
    File.binwrite(r::DIM.path, JSON.generate('std' => 2, 'series' => r.defaults.merge('buduci' => [1000])))
    r::E::JsonFileStore.invalidate(r::DIM.path)
    status, = r::DIM.update!({ 'sirka' => [600] }, { 'sirka' => r::DIM::DEFAULTS['sirka'] })
    NxTest.assert_equal(:ok, status)
    raw = JSON.parse(File.binread(r::DIM.path))
    NxTest.assert_equal(r::DIM::STD, raw['std'], 'zapise sa std 1')
    NxTest.refute(raw['series'].key?('buduci'), 'neznamy kluc zo suboru zanikol')
  end
end

# =============================================================================
# B3 · handler panela + strukturalne guardy
# =============================================================================

NxTest.test('H10b B3: handler — kazda vetva ma svoju hlasku a VZDY prekresli editor') do
  r = NxH10b
  d = r::DIM::DEFAULTS
  r.with_file do
    r.with_panel do |panel, log|
      r.save(panel, { 'sirka' => d['sirka'] + [700] }, { 'sirka' => d['sirka'] })
      NxTest.assert_equal(['Rozmerové rady uložené.', false], log[:status], ':ok so zmenou')

      r.save(panel, { 'vyska' => d['vyska'] }, { 'vyska' => d['vyska'] })
      NxTest.assert_equal(['Rozmerové rady sa nezmenili.', false], log[:status], ':ok bez zmeny')

      r.save(panel, { 'sirka' => [600], 'sokel' => [90] }, { 'sirka' => d['sirka'], 'sokel' => d['sokel'] })
      msg, err = log[:status]
      NxTest.assert_equal(true, err, 'konflikt je cerveny')
      NxTest.assert(msg.start_with?('Rozmerové rady (Šírky) medzitým zmenilo iné okno SketchUpu — nič sa neuložilo.'),
                    "konflikt povie KTORY rad (#{msg.inspect})")
      NxTest.assert(msg.include?('Editor ukazuje aktuálne uložené rady, zmenu zadaj znova.'), 'a co robit')
      NxTest.assert_equal(d['sokel'], r::DIM.get['sokel'], 'nekonfliktny rad sa nezapisal')

      r.save(panel, d, :none)
      NxTest.assert_equal(['Okno je z predošlej verzie pluginu — rozmerové rady sa neuložili. ' \
                           'Zavri a otvor panel znova.', true], log[:status], ':stale_client')
      NxTest.assert_equal([true] * 4, log[:refill], 'editor sa prekreslil po KAZDOM vysledku')
    end
  end
end

NxTest.test('H10b B3: handler — brana a zlyhanie zapisu') do
  r = NxH10b
  r.with_file do
    FileUtils.mkdir_p(r::DIM.dir)
    File.binwrite("#{r::DIM.path}.bak", JSON.generate('std' => 1, 'series' => { 'sirka' => [123] }))
    File.binwrite(r::DIM.path, '{ poskodene')
    r::E::JsonFileStore.invalidate(r::DIM.path)
    r.with_panel do |panel, log|
      r.save(panel, { 'sirka' => [400] }, { 'sirka' => [123] })
      msg, err = log[:status]
      NxTest.assert(err && msg.include?('poškoden'), ":blocked povie dovod brany (#{msg.inspect})")
      NxTest.assert_equal([true], log[:refill])
    end
  end
  r.with_file do
    orig = r::DIM.method(:update!)
    r::DIM.define_singleton_method(:update!) { |*_a| [:write_failed, nil, []] }
    begin
      r.with_panel do |panel, log|
        r.save(panel, { 'sirka' => [400] }, { 'sirka' => r::DIM::DEFAULTS['sirka'] })
        NxTest.assert_equal(['Rozmerové rady sa nepodarilo uložiť (disk/práva).', true], log[:status])
        NxTest.assert_equal([true], log[:refill])
      end
    ensure
      r::DIM.define_singleton_method(:update!, orig)
    end
  end
end

NxTest.test('H10b B3 guard: panel zapisuje LEN cez `update!` a vyhodnocuje `case`') do
  r = NxH10b
  src = r.src('ui/panel/actions_settings.rb')
  NxTest.refute(src.include?('DimSeries.set('), 'panel nesmie zapisovat uplnu nahradu radov')
  h = r.body('ui/panel/actions_settings.rb', 'handle_set_dim_series', 8)
  NxTest.assert(h.include?("DimSeries.update!(data['series'], data['base'])"), 'zapis po klucoch s povodnymi hodnotami')
  NxTest.assert(h.include?('case status'), 'vysledok sa vyhodnocuje cez case (:conflict je pravdivy)')
  NxTest.assert(h.index('push_ui_settings(refill_editor: true)').to_i < h.index('case status').to_i,
                'editor sa prekresli pri kazdom vysledku (pred vetvami)')
end

NxTest.test('H10b guard: `update!` — brana, starsi klient a cerstve citanie AZ POD zamkom, zapis cez `set`') do
  r = NxH10b
  b = r.body('core/dim_series.rb', 'update!')
  NxTest.refute(b.empty?, 'telo update! sa naslo')
  lock = b.index('with_catalog_lock')
  gate = b.index('degraded_write_blocked?')
  stale = b.index(':stale_client')
  reload = b.index('JsonFileStore.reload!')
  check = b.index('normalize_list(base[k]) != current[k]')
  write = b.index('set(merged)')
  NxTest.assert(lock && gate && stale && reload && check && write, 'vsetky kroky su v tele')
  NxTest.assert(lock < gate && gate < stale && stale < reload && reload < check && check < write,
                'poradie: zamok -> brana -> starsi klient -> reload -> konflikt -> zapis')
  NxTest.refute(b.include?('JsonFileStore.write('), 'jediny zapis modulu ostava v `set`')
end
