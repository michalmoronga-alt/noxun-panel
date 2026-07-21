# frozen_string_literal: true
# Testy VEPO CSV exportu (core/vepo_export.rb) — format podla SYSTEM/03 kontraktu.
# Uzamyka: obchodne hrubky, kody hran, rotaciu dekoru, ODPOCET ABS (prirez!),
# presne bajty CSV (force quotes, ';', CRLF, bez hlavicky), grouping + merge 18/36,
# chybne riadky mimo CSV, atomicky zapis davky s guardom cudzich suborov.
require_relative '../helper' unless defined?(NxTest)

module NxVepo
  module_function

  def vepo
    Noxun::Engine::VepoExport
  end

  MATS = {
    'K009_PW_DTDL_18' => { 'label' => 'K009 PW DTDL' },
    'K009_PW_DTDL_36' => { 'label' => 'K009 PW DTDL' },
    'HDF_WHITE_3'     => { 'label' => 'Biela HDF' }
  }.freeze
  EDGES = { 'ABS1' => 1.0, 'ABS2' => 2.0 }.freeze

  def vrow(over = {})
    {
      'names' => ['Bok'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0,
      'quantity' => 2, 'material_id' => 'K009_PW_DTDL_18', 'grain_direction' => 'length',
      'edges' => { 'L1' => 'ABS1', 'L2' => nil, 'W1' => nil, 'W2' => nil },
      'kde' => [{ 'owner_id' => 'CAB-1', 'quantity' => 2 }]
    }.merge(over)
  end

  def build(rows, over = {})
    args = { project: 'Kuchyňa Novák', materials: MATS, edge_thicknesses: EDGES,
             version: '9.9.9', generated_at: 'TEST-CAS', merge_18_36: true }.merge(over)
    vepo.build(rows, **args)
  end
end

NxTest.test('vepo: obchodne hrubky 18/36 pasma, zaokruhlenie, chybne <= 0') do
  v = NxVepo.vepo
  NxTest.assert_equal(18, v.commercial_thickness(18.0))
  NxTest.assert_equal(18, v.commercial_thickness(19.0))
  NxTest.assert_equal(18, v.commercial_thickness(19.1))
  NxTest.assert_equal(19, v.commercial_thickness(19.2))
  NxTest.assert_equal(36, v.commercial_thickness(36.0))
  NxTest.assert_equal(36, v.commercial_thickness(38.1))
  NxTest.assert_equal(25, v.commercial_thickness(25.0))
  NxTest.assert_equal(3, v.commercial_thickness(2.8))
  NxTest.assert_equal(nil, v.commercial_thickness(0))
  NxTest.assert_equal(nil, v.commercial_thickness(-5))
end

NxTest.test('vepo: kod dvojice hran z pritomnosti ABS (nie hrubky)') do
  v = NxVepo.vepo
  NxTest.assert_equal('', v.edge_code(nil, nil))
  NxTest.assert_equal('', v.edge_code('', nil))
  NxTest.assert_equal('—', v.edge_code('ABS1', nil))
  NxTest.assert_equal('—', v.edge_code(nil, 'ABS2'))
  NxTest.assert_equal('=', v.edge_code('ABS1', 'ABS2'))
end

NxTest.test('vepo: rotacia dekoru width prehodi rozmery AJ dvojice hran') do
  r = NxVepo.vrow('grain_direction' => 'width',
                  'edges' => { 'L1' => 'ABS1', 'L2' => nil, 'W1' => 'ABS2', 'W2' => nil })
  o = NxVepo.vepo.oriented(r)
  NxTest.assert_equal(560.0, o['length'])
  NxTest.assert_equal(720.0, o['width'])
  NxTest.assert_equal('ABS2', o['edges']['L1'], 'nova L1 = stara W1')
  NxTest.assert_equal('ABS1', o['edges']['W1'], 'nova W1 = stara L1')
  NxTest.assert_equal('length', o['grain_direction'])
  # bez rotacie sa nic nemeni (a vrati KOPIU edges, nie referenciu)
  same = NxVepo.vepo.oriented(NxVepo.vrow)
  NxTest.assert_equal(720.0, same['length'])
  NxTest.refute(same['edges'].equal?(NxVepo.vrow['edges']))
end

NxTest.test('vepo: rozmery su HOTOVE — ziadny odpocet ABS (oprava 20.7.); neznama ABS = chyba') do
  v = NxVepo.vepo
  r = NxVepo.vrow('edges' => { 'L1' => 'ABS1', 'L2' => 'ABS2', 'W1' => 'ABS2', 'W2' => nil })
  dims, err = v.finished_dimensions(r, NxVepo::EDGES)
  NxTest.assert_equal(nil, err)
  NxTest.assert_close(720.0, dims[0], 0.001, 'dlzka NEZMENENA aj s hranami — VEPO si odratava sam')
  NxTest.assert_close(560.0, dims[1], 0.001, 'sirka NEZMENENA')

  _, err2 = v.finished_dimensions(NxVepo.vrow('edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil }), NxVepo::EDGES)
  NxTest.assert(err2 && err2.include?('neznáma ABS'), "neznama ABS je integrity chyba, dostal #{err2.inspect}")
end

NxTest.test('vepo: rotacia dekoru vymeni rozmery aj kody hran — hodnoty ostanu hotove') do
  r = NxVepo.vrow('grain_direction' => 'width',
                  'edges' => { 'L1' => 'ABS1', 'L2' => nil, 'W1' => 'ABS2', 'W2' => nil })
  o = NxVepo.vepo.oriented(r)
  dims, err = NxVepo.vepo.finished_dimensions(o, NxVepo::EDGES)
  NxTest.assert_equal(nil, err)
  NxTest.assert_close(560.0, dims[0], 0.001, 'po rotacii dlzka = povodna sirka, bez odpoctu')
  NxTest.assert_close(720.0, dims[1], 0.001, 'po rotacii sirka = povodna dlzka, bez odpoctu')
end

NxTest.test('vepo: slug a project_slug (diakritika, prazdne, Windows rezervovane)') do
  v = NxVepo.vepo
  NxTest.assert_equal('kuchyna_novak', v.slug('Kuchyňa Novák'))
  NxTest.assert_equal('csz_123', v.slug('ČŠŽ---123'))
  NxTest.assert_equal('projekt', v.project_slug(''))
  NxTest.assert_equal('projekt', v.project_slug('***'))
  NxTest.assert_equal('projekt_con', v.project_slug('CON'))
  NxTest.assert_equal('projekt_lpt1', v.project_slug('LPT1'))
end

NxTest.test('vepo: CSV riadok — presne bajty (force quotes, ;, CRLF, bez hlavicky, cele mm)') do
  out = NxVepo.build([NxVepo.vrow])
  NxTest.assert_equal(1, out['groups'].length)
  g = out['groups'].first
  NxTest.assert_equal('kuchyna_novak_k009_pw_dtdl_18_36.csv', g['filename'])
  # sirka 560 = HOTOVY rozmer (ABS 1mm na L1 sa NEodratava — kod — to nesie)
  expected = "\"Bok\";\"720\";\"—\";\"560\";\"\";\"18\";\"2\";\"K009 PW DTDL\"\r\n"
  NxTest.assert_equal(expected, g['csv'], 'byte-for-byte format riadku')
  NxTest.assert_equal('UTF-8', g['csv'].encoding.name)
  NxTest.refute(g['csv'].start_with?("﻿"), 'ziadny BOM')
end

NxTest.test('vepo: merge 18+36 spaja do jedneho suboru, bez merge oddelene, HDF vzdy vlastny') do
  rows = [
    NxVepo.vrow,
    NxVepo.vrow('material_id' => 'K009_PW_DTDL_36', 'thickness' => 36.0, 'names' => ['Vystuha']),
    NxVepo.vrow('material_id' => 'HDF_WHITE_3', 'thickness' => 3.0, 'names' => ['Chrbat'],
                'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil })
  ]
  merged = NxVepo.build(rows)
  NxTest.assert_equal(2, merged['groups'].length, '18+36 spolu + HDF zvlast')
  m = merged['groups'].find { |g| g['tag'] == '18_36' }
  NxTest.assert_equal(2, m['rows'])
  NxTest.assert_equal(%w[K009_PW_DTDL_18 K009_PW_DTDL_36], m['material_ids'].sort)
  h = merged['groups'].find { |g| g['tag'] == '3' }
  NxTest.assert_equal('kuchyna_novak_biela_hdf_3.csv', h['filename'])

  split = NxVepo.build(rows, merge_18_36: false)
  NxTest.assert_equal(3, split['groups'].length)
  tags = split['groups'].map { |g| g['tag'] }.sort
  NxTest.assert_equal(%w[18 3 36], tags)
end

NxTest.test('vepo: chybne riadky idu do errors a LOGu, nie do CSV') do
  rows = [
    NxVepo.vrow,
    NxVepo.vrow('names' => ['Zly'], 'quantity' => 0),
    NxVepo.vrow('names' => ['BezMat'], 'material_id' => ''),
    NxVepo.vrow('names' => ['ZlaABS'], 'edges' => { 'L1' => 'FUJ', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  ]
  out = NxVepo.build(rows)
  NxTest.assert_equal(3, out['errors'].length)
  NxTest.assert_equal(1, out['total_rows'], 'len zdravy riadok exportuje')
  reasons = out['errors'].map { |e| e['reason'] }.join(' | ')
  NxTest.assert(reasons.include?('počet') && reasons.include?('materiál') && reasons.include?('neznáma ABS'))
  NxTest.assert(out['log_text'].include?('ZlaABS'), 'LOG menuje chybny dielec')
  NxTest.assert(out['errors'].find { |e| e['name'] == 'Zly' }['owners'].include?('CAB-1'))
end

NxTest.test('vepo: prazdne rows = ziadne skupiny; LOG existuje aj tak') do
  out = NxVepo.build([])
  NxTest.assert_equal([], out['groups'])
  NxTest.assert_equal(0, out['total_rows'])
  NxTest.assert(out['log_text'].include?('Skupiny exportu (0)'))
end

NxTest.test('vepo: LOG nesie projekt, verziu, datum, skupiny s ID, chyby aj KONTROLA, CRLF') do
  # V0.5 D: warnings param nahradeny validation (Validation.run vysledok). Sekcia
  # KONTROLA vypisuje message_sk poloziek + counts (nalez 5/9).
  validation = {
    'items' => [
      { 'severity' => 'red', 'category' => 'material', 'owner_id' => 'CAB-9',
        'part_key' => 'cabinet/side:left', 'message_sk' => 'Dielec „Bok“ (CAB-9) — materiál XY nie je v aktuálnom katalógu.',
        'stable_key' => 'material|CAB-9|cabinet/side:left' },
      { 'severity' => 'orange', 'category' => 'build', 'owner_id' => 'CAB-9',
        'part_key' => nil, 'message_sk' => 'CAB-9: testovacie varovanie',
        'stable_key' => 'build|CAB-9||orezane' }
    ],
    'counts' => { 'red' => 1, 'orange' => 1, 'total' => 2 }
  }
  out = NxVepo.build([NxVepo.vrow], validation: validation)
  log = out['log_text']
  ['Kuchyňa Novák', 'kuchyna_novak', '9.9.9', 'TEST-CAS',
   'kuchyna_novak_k009_pw_dtdl_18_36.csv', 'K009_PW_DTDL_18',
   'KONTROLA', '1 kritických', 'testovacie varovanie', 'CAB-9',
   'nie je v aktuálnom katalógu', '[RED]', '[ORANGE]'].each do |part|
    NxTest.assert(log.include?(part), "LOG ma obsahovat #{part.inspect}")
  end
  NxTest.assert(log.include?('neblokuje'), 'LOG pomenuje ze RED neblokuje export')
  NxTest.assert(log.include?("\r\n"), 'LOG konci riadky CRLF')
  NxTest.refute(log.gsub("\r\n", '').include?("\n"), 'ziadne osamele LF')
end

NxTest.test('vepo: LOG bez validacie = KONTROLA sekcia bez nalezov (headless kompat)') do
  out = NxVepo.build([NxVepo.vrow])
  NxTest.assert(out['log_text'].include?('KONTROLA'), 'sekcia KONTROLA je aj bez validacie')
  NxTest.assert(out['log_text'].include?('bez nálezov'), 'prazdna validacia = bez nalezov')
end

NxTest.test('vepo: nazov riadku — join mien, orezanie, fallback dielec; label fallback id') do
  v = NxVepo.vepo
  NxTest.assert_equal('A/B', v.row_name('names' => %w[A B]))
  NxTest.assert_equal('dielec', v.row_name('names' => []))
  long = v.row_name('names' => ['X' * 100])
  NxTest.assert(long.length <= 60)
  NxTest.assert_equal('NEZNAMY_ID', v.material_label('NEZNAMY_ID', NxVepo::MATS))
end

NxTest.test('vepo: write — atomicka davka, re-export vymeni obsah, guard cudzich suborov') do
  Dir.mktmpdir('vepo-test-') do |dir|
    out = NxVepo.build([NxVepo.vrow])
    target = NxVepo.vepo.write(out, dir)
    NxTest.assert_equal(File.join(dir, 'kuchyna_novak'), target)
    files = Dir.children(target).sort
    NxTest.assert_equal(['kuchyna_novak_export.log', 'kuchyna_novak_k009_pw_dtdl_18_36.csv'], files)
    csv_bytes = File.binread(File.join(target, 'kuchyna_novak_k009_pw_dtdl_18_36.csv'))
    NxTest.assert(csv_bytes.end_with?("\r\n"), 'subor konci CRLF')
    NxTest.refute(csv_bytes.start_with?("\xEF\xBB\xBF".b), 'ziadny BOM v subore')

    # re-export s inym materialom: stary CSV NESMIE prezit (audit B5)
    out2 = NxVepo.build([NxVepo.vrow('material_id' => 'HDF_WHITE_3', 'thickness' => 3.0,
                                     'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil })])
    NxVepo.vepo.write(out2, dir)
    files2 = Dir.children(target).sort
    NxTest.assert_equal(['kuchyna_novak_biela_hdf_3.csv', 'kuchyna_novak_export.log'], files2)

    # cudzi subor v cieli = zapis odmietnuty a nic sa nezmaze
    File.write(File.join(target, 'FOTKA.jpg'), 'x')
    NxTest.assert_raise('cudzie súbory') { NxVepo.vepo.write(out, dir) }
    NxTest.assert(File.exist?(File.join(target, 'FOTKA.jpg')), 'cudzi subor prezil')
    NxTest.assert(Dir.children(dir).none? { |c| c.include?('.tmp-') }, 'staging upratany')
    NxTest.assert(Dir.children(dir).none? { |c| c.include?('.old-') }, 'old swap upratany')
  end
end

NxTest.test('vepo: guard chrani aj CUDZIE csv/log bez nasho prefixu (GH P2)') do
  Dir.mktmpdir('vepo-test-') do |dir|
    out = NxVepo.build([NxVepo.vrow])
    target = NxVepo.vepo.write(out, dir)
    File.write(File.join(target, 'supplier.csv'), 'cudzi dodavatelsky subor')
    NxTest.assert_raise('cudzie súbory') { NxVepo.vepo.write(out, dir) }
    NxTest.assert(File.exist?(File.join(target, 'supplier.csv')), 'cudzi csv prezil')
    # nas subor s prefixom projektu guardom prejde
    File.delete(File.join(target, 'supplier.csv'))
    NxVepo.vepo.write(out, dir)
    NxTest.assert(File.exist?(File.join(target, 'kuchyna_novak_k009_pw_dtdl_18_36.csv')))
  end
end

NxTest.test('vepo: kolizia nazvov po slugu dostane sufix _2 — ziadny tichy prepis (GH P1)') do
  # dva ROZNE materialy, ktorych labely sa po slugu zleju ('Dub-A' aj 'Dub A'
  # -> 'dub_a') a rovnaka hrubka = rovnaky tag -> bez dedupu by druhy subor
  # prepisal prvy
  mats = { 'MAT_A' => { 'label' => 'Dub-A' }, 'MAT_B' => { 'label' => 'Dub A' } }
  rows = [
    NxVepo.vrow('material_id' => 'MAT_A', 'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }),
    NxVepo.vrow('material_id' => 'MAT_B', 'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil })
  ]
  out = NxVepo.build(rows, materials: mats, merge_18_36: false)
  fns = out['groups'].map { |g| g['filename'] }
  NxTest.assert_equal(2, out['groups'].length, 'dva materialy = dve skupiny')
  NxTest.assert_equal(fns.uniq.length, fns.length, "nazvy suborov musia byt unikatne: #{fns}")
  NxTest.assert(fns.any? { |f| f.end_with?('_2.csv') }, "kolizia dostane _2 sufix: #{fns}")
end

NxTest.test('vepo: 0 platnych riadkov -> write vytvori LEN LOG s dovodmi (GH P2)') do
  Dir.mktmpdir('vepo-test-') do |dir|
    out = NxVepo.build([NxVepo.vrow('names' => ['Rozbity'], 'quantity' => 0)])
    NxTest.assert_equal([], out['groups'])
    target = NxVepo.vepo.write(out, dir)
    files = Dir.children(target)
    NxTest.assert_equal(['kuchyna_novak_export.log'], files, 'len LOG subor')
    log = File.binread(File.join(target, 'kuchyna_novak_export.log'))
    NxTest.assert(log.include?('Rozbity'), 'LOG menuje chybny dielec')
  end
end
