# frozen_string_literal: true
# Testy D-25 merac pouzivania panela (core/usage_stats.rb): cista merge logika
# (nove kluce, prirastky, first_seen nemenne, neznane polia JSON zachovane),
# sanitizacia payloadu (ne-ciselne county, nevalidne typy, kluce, strop) a
# record round-trip cez APPDATA sandbox (headless only — helper presmeroval
# ENV['APPDATA'], takze sa NIKDY nesiaha na realny %APPDATA%\NOXUN\Engine).
require_relative '../helper' unless defined?(NxTest)

# ============================ merge (cista logika) =============================

NxTest.test('usage_stats: merge do prazdneho stavu zalozi schemu + datumy') do
  us = Noxun::Engine::UsageStats
  out = us.merge({}, { 'width' => 2, 'tab:zony' => 1 }, today: '2026-07-20')
  NxTest.assert_equal(1, out['schema'])
  NxTest.assert_equal('2026-07-20', out['first_seen'])
  NxTest.assert_equal('2026-07-20', out['last_seen'])
  NxTest.assert_equal({ 'width' => 2, 'tab:zony' => 1 }, out['counts'])
end

NxTest.test('usage_stats: merge pricitava existujuce a pridava nove kluce') do
  us = Noxun::Engine::UsageStats
  existing = { 'schema' => 1, 'first_seen' => '2026-07-01', 'last_seen' => '2026-07-10',
               'counts' => { 'width' => 5, 'height' => 1 } }
  out = us.merge(existing, { 'width' => 3, 'sec:fronts' => 2 }, today: '2026-07-20')
  NxTest.assert_equal(8, out['counts']['width'])
  NxTest.assert_equal(1, out['counts']['height'])
  NxTest.assert_equal(2, out['counts']['sec:fronts'])
end

NxTest.test('usage_stats: first_seen sa po vzniku NEMENI, last_seen sa aktualizuje') do
  us = Noxun::Engine::UsageStats
  existing = { 'schema' => 1, 'first_seen' => '2026-07-01', 'last_seen' => '2026-07-10',
               'counts' => {} }
  out = us.merge(existing, { 'width' => 1 }, today: '2026-07-20')
  NxTest.assert_equal('2026-07-01', out['first_seen'])
  NxTest.assert_equal('2026-07-20', out['last_seen'])
end

NxTest.test('usage_stats: nevalidny first_seen v subore -> nahradi ho dnesok') do
  us = Noxun::Engine::UsageStats
  [nil, 42, 'kedysi', '2026-7-1'].each do |bad|
    out = us.merge({ 'first_seen' => bad }, { 'width' => 1 }, today: '2026-07-20')
    NxTest.assert_equal('2026-07-20', out['first_seen'], "first_seen pre #{bad.inspect}")
  end
end

NxTest.test('usage_stats: neznane top-level polia JSON preziju merge (forward kompat)') do
  us = Noxun::Engine::UsageStats
  existing = { 'schema' => 1, 'first_seen' => '2026-07-01', 'last_seen' => '2026-07-10',
               'counts' => { 'width' => 1 }, 'poznamka' => 'buduce pole', 'extra' => { 'x' => 1 } }
  out = us.merge(existing, { 'width' => 1 }, today: '2026-07-20')
  NxTest.assert_equal('buduce pole', out['poznamka'])
  NxTest.assert_equal({ 'x' => 1 }, out['extra'])
  NxTest.assert_equal(2, out['counts']['width'])
end

NxTest.test('usage_stats: ne-ciselne county v existujucom subore sa pri merge zahodia') do
  us = Noxun::Engine::UsageStats
  existing = { 'counts' => { 'width' => 'vela', 'height' => 2, 'depth' => [1] } }
  out = us.merge(existing, { 'width' => 1 }, today: '2026-07-20')
  NxTest.assert_equal(1, out['counts']['width']) # 'vela' zahodene, pocita sa od prirastku
  NxTest.assert_equal(2, out['counts']['height'])
  NxTest.refute(out['counts'].key?('depth'), 'ne-ciselny count nema prezit')
end

NxTest.test('usage_stats: merge s nevalidnym existing (nie Hash) zacne od nuly') do
  us = Noxun::Engine::UsageStats
  [nil, [], 'text'].each do |bad|
    out = us.merge(bad, { 'width' => 1 }, today: '2026-07-20')
    NxTest.assert_equal({ 'width' => 1 }, out['counts'], "counts pre existing #{bad.inspect}")
    NxTest.assert_equal('2026-07-20', out['first_seen'])
  end
end

# ============================ sanitize_counts ==================================

NxTest.test('usage_stats: sanitize zahodi nevalidny payload (nie Hash)') do
  us = Noxun::Engine::UsageStats
  [nil, [], 'text', 42].each do |bad|
    NxTest.assert_equal({}, us.sanitize_counts(bad), "payload #{bad.inspect}")
  end
end

NxTest.test('usage_stats: sanitize hodnoty — cele cisla ano, ostatne von') do
  us = Noxun::Engine::UsageStats
  raw = { 'a' => 3, 'b' => 2.6, 'c' => '7', 'd' => 'abc', 'e' => nil, 'f' => [1],
          'g' => 0, 'h' => -5, 'i' => Float::NAN, 'j' => Float::INFINITY }
  out = us.sanitize_counts(raw)
  NxTest.assert_equal({ 'a' => 3, 'b' => 3, 'c' => 7 }, out)
end

NxTest.test('usage_stats: sanitize kluce — prazdny a predlhy kluc von, symbol na string') do
  us = Noxun::Engine::UsageStats
  raw = { '' => 5, ('x' * 200) => 5, sym_key: 2 }
  out = us.sanitize_counts(raw)
  NxTest.assert_equal({ 'sym_key' => 2 }, out)
end

NxTest.test('usage_stats: strop pocitadla plati pre prirastok aj sucet') do
  us = Noxun::Engine::UsageStats
  cap = Noxun::Engine::UsageStats::MAX_COUNT
  NxTest.assert_equal({ 'a' => cap }, us.sanitize_counts({ 'a' => cap + 99 }))
  out = us.merge({ 'counts' => { 'a' => cap - 1 } }, { 'a' => 10 }, today: '2026-07-20')
  NxTest.assert_equal(cap, out['counts']['a'])
end

# ============================ record (round-trip) ==============================

NxTest.test('usage_stats: record round-trip — dva flushe sa scitaju v subore') do
  NxTest.skip! 'zapisove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  us = Noxun::Engine::UsageStats
  FileUtils.rm_f(us.path)
  FileUtils.rm_f("#{us.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(us.path)
  NxTest.assert_equal(true, us.record({ 'width' => 2, 'tab:zony' => 1 }))
  NxTest.assert_equal(true, us.record({ 'width' => 1 }))
  data = JSON.parse(File.binread(us.path))
  NxTest.assert_equal(1, data['schema'])
  NxTest.assert_equal(3, data['counts']['width'])
  NxTest.assert_equal(1, data['counts']['tab:zony'])
  NxTest.assert(data['first_seen'].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/), 'first_seen ma byt datum')
end

NxTest.test('usage_stats: record NEMENI first_seen existujuceho suboru') do
  NxTest.skip! 'zapisove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  us = Noxun::Engine::UsageStats
  store = Noxun::Engine::JsonFileStore
  FileUtils.rm_f(us.path)
  FileUtils.rm_f("#{us.path}.bak")
  store.invalidate(us.path)
  store.write(us.path, { 'schema' => 1, 'first_seen' => '2026-01-01',
                         'last_seen' => '2026-01-01', 'counts' => { 'width' => 1 } })
  NxTest.assert_equal(true, us.record({ 'width' => 1 }))
  data = JSON.parse(File.binread(us.path))
  NxTest.assert_equal('2026-01-01', data['first_seen'])
  NxTest.assert_equal(2, data['counts']['width'])
end

NxTest.test('usage_stats: record s nevalidnym/prazdnym payloadom vrati false a nezapise') do
  NxTest.skip! 'zapisove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  us = Noxun::Engine::UsageStats
  FileUtils.rm_f(us.path)
  FileUtils.rm_f("#{us.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(us.path)
  NxTest.assert_equal(false, us.record(nil))
  NxTest.assert_equal(false, us.record([]))
  NxTest.assert_equal(false, us.record({}))
  NxTest.assert_equal(false, us.record({ 'x' => 'abc' })) # sanitizacia vyprazdni
  NxTest.refute(File.exist?(us.path), 'prazdny flush nesmie zalozit subor')
end

NxTest.test('usage_stats: subor s NOVSOU schemou sa neprepisuje (forward kompat)') do
  NxTest.skip! 'zapisove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  us = Noxun::Engine::UsageStats
  store = Noxun::Engine::JsonFileStore
  FileUtils.rm_f(us.path)
  FileUtils.rm_f("#{us.path}.bak")
  store.invalidate(us.path)
  future = { 'schema' => 2, 'first_seen' => '2026-01-01', 'last_seen' => '2026-01-01',
             'counts' => { 'novy_format' => { 'n' => 5 } } }
  store.write(us.path, future)
  NxTest.assert_equal(false, us.record({ 'width' => 1 }))
  NxTest.assert_equal(future, JSON.parse(File.binread(us.path)), 'subor novsej verzie musi ostat nedotknuty')
end

NxTest.test('usage_stats: record cita cerstvo z disku (zapis mimo cache neprehliadne)') do
  NxTest.skip! 'zapisove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  us = Noxun::Engine::UsageStats
  store = Noxun::Engine::JsonFileStore
  FileUtils.rm_f(us.path)
  FileUtils.rm_f("#{us.path}.bak")
  store.invalidate(us.path)
  NxTest.assert_equal(true, us.record({ 'width' => 1 }))
  # simulacia zapisu z INEJ instancie SketchUpu: priamy zapis na disk obislo
  # cache (1 s okno) — with_lock musi invalidovat a nacitat cerstvy stav.
  raw = JSON.parse(File.binread(us.path))
  raw['counts']['width'] = 10
  File.binwrite(us.path, JSON.generate(raw))
  NxTest.assert_equal(true, us.record({ 'width' => 1 }))
  data = JSON.parse(File.binread(us.path))
  NxTest.assert_equal(11, data['counts']['width'], 'cudzi prirastok nesmie byt stratenym updateom')
end

NxTest.test('usage_stats: record prezije poskodeny subor (rescue -> zacne odznova)') do
  NxTest.skip! 'zapisove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  us = Noxun::Engine::UsageStats
  FileUtils.rm_f(us.path)
  FileUtils.rm_f("#{us.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(us.path)
  FileUtils.mkdir_p(us.dir)
  File.binwrite(us.path, '{ toto nie je json')
  Noxun::Engine::JsonFileStore.invalidate(us.path)
  NxTest.assert_equal(true, us.record({ 'width' => 1 }))
  data = JSON.parse(File.binread(us.path))
  NxTest.assert_equal(1, data['counts']['width'])
end
