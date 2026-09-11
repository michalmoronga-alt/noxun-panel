# frozen_string_literal: true
# MR-1A: dalsi proces meni katalog, kym nativny exporter pripravuje subor.
# Obsah SKM tu neoverujeme: blok predstavuje uspesnu odpoved nativneho adaptera.
require_relative '../helper' unless defined?(NxTest)

module MR1APublishRace
  M = Noxun::Engine::Materials

  def self.with_catalog
    NxTest.skip!('izolovane katalogove testy len headless') unless NxTest.headless?
    previous = M.test_dir_override
    Dir.mktmpdir('mr1a-publish-race-') do |root|
      M.test_dir_override = root
      M.reset_catalog_state!
      payload = {
        'schema' => 2,
        'sheets' => [
          { 'material_id' => 'RACE_18', 'group_id' => 'GRP_RACE', 'decor' => 'RACE',
            'manufacturer' => 'Test', 'type' => 'DTDL', 'thickness' => 18.0,
            'structure' => 'ST9', 'grain' => 'length', 'color' => [100, 110, 120],
            'price_per_m2' => 10.0 }
        ],
        'edges' => [
          { 'abs_id' => 'RACE_ABS', 'group_id' => 'GRP_RACE', 'decor' => 'RACE',
            'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9',
            'color' => [100, 110, 120], 'price_per_bm' => 1.0 }
        ]
      }
      File.binwrite(M.path, JSON.generate(payload))
      Noxun::Engine::JsonFileStore.invalidate(M.path)
      yield
    ensure
      Noxun::Engine::JsonFileStore.invalidate(M.path)
      M.test_dir_override = previous
      M.reset_catalog_state!
    end
  end

  # Priamy diskovy zapis simuluje iny proces: nepouzije lokalnu cache ani lock depth.
  def self.concurrent_change
    fresh = JSON.parse(File.binread(M.path))
    yield fresh
    File.binwrite(M.path, JSON.generate(fresh))
  end
end

NxTest.test('mr1a: nova ABS pocas exportu zrusi publikaciu bez ciastocneho vzhladu') do
  MR1APublishRace.with_catalog do
    m = MR1APublishRace::M
    status, initial = m.appearance_scope('sheet', 'RACE_18')
    NxTest.assert_equal(:ok, status)
    generated_id = nil
    concurrent_bytes = nil
    outcome, = m.publish_appearance('sheet', 'RACE_18', baseline: initial['baseline'], mode: 'native') do |staging, descriptor, _scope|
      generated_id = descriptor['id']
      File.binwrite(staging, 'exporter-validated-native-fixture')
      MR1APublishRace.concurrent_change do |data|
        data['edges'] << data['edges'].first.merge('abs_id' => 'RACE_ABS_42', 'width' => 42.0)
      end
      concurrent_bytes = File.binread(m.path)
      true
    end
    NxTest.assert_equal(:stale, outcome)
    NxTest.assert_equal(concurrent_bytes, File.binread(m.path), 'cudzi novy variant musi prezit bajtovo')
    NxTest.refute(File.exist?(m.appearance_file(generated_id)), 'stale export sa nesmie publikovat')
    NxTest.refute(File.exist?(m.appearance_file(generated_id) + '.staging'), 'staging sa po odmietnuti odstrani')
    rows = JSON.parse(File.binread(m.path)).values_at('sheets', 'edges').flatten
    NxTest.assert(rows.none? { |row| row.key?('appearance') }, 'ziaden clen nesmie dostat ciastocny vzhlad')
  end
end

NxTest.test('mr1a: cena zmenena pocas exportu prezije spolocnu publikaciu dosky aj ABS') do
  MR1APublishRace.with_catalog do
    m = MR1APublishRace::M
    status, initial = m.appearance_scope('edge', 'RACE_ABS')
    NxTest.assert_equal(:ok, status)
    outcome, result = m.publish_appearance('edge', 'RACE_ABS', baseline: initial['baseline'], mode: 'native') do |staging, _descriptor, _scope|
      File.binwrite(staging, 'exporter-validated-native-fixture')
      MR1APublishRace.concurrent_change do |data|
        data['sheets'].first['price_per_m2'] = 19.75
        data['edges'].first['price_per_bm'] = 2.35
      end
      true
    end
    NxTest.assert_equal(:ok, outcome, result.inspect)
    actual = JSON.parse(File.binread(m.path))
    sheet = actual['sheets'].first
    edge = actual['edges'].first
    NxTest.assert_equal(19.75, sheet['price_per_m2'])
    NxTest.assert_equal(2.35, edge['price_per_bm'])
    NxTest.assert_equal(sheet['appearance'], edge['appearance'], 'ABS anchor publikuje aj pre dosky')
    NxTest.assert_equal('native', sheet['appearance']['mode'])
    NxTest.assert_equal([100, 110, 120], edge['color'], 'ulozeny vzhlad nemeni povodnu farbu')
    NxTest.assert(File.file?(m.appearance_file(sheet['appearance']['id'])))
  end
end
