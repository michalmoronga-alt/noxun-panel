# frozen_string_literal: true
# Testy 2A-4a: server hardening pred cutoverom katalogu na SCHEMA 2
# (audit B1/B2/B3/B4 + F5/F6/F7).
#
# KONTRAKT DAVKY: assess_catalog!/restore_pre_schema2! nevola ziadna produkcna
# cesta (boot flow = 2A-4b) — testy ich spustaju VYHRADNE nad izolovanou
# kopiou katalogu (APPDATA sandbox helpera). Bez behu assess je stav :ok
# a spravanie sa nemeni ani o vlas (dual-mode).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

A4MAT = Noxun::Engine::Materials
A4STORE = Noxun::Engine::JsonFileStore

def a4_legacy_bytes
  JSON.pretty_generate(
    'std' => 1,
    'sheets' => [
      { 'material_id' => 'L18', 'decor' => 'Legacy Dekor', 'manufacturer' => 'Firma',
        'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length', 'color' => [1, 2, 3],
        'production_class' => 'sheet' }
    ],
    'edges' => [
      { 'abs_id' => 'LE10', 'decor' => 'Legacy Dekor', 'thickness' => 1.0, 'color' => [1, 2, 3] }
    ]
  ).b
end

# SCHEMA 2 katalog s DVOMA skupinami rovnakeho cisla dekoru (K009 u Kronospanu
# aj Eggeru — standard 7.1: dve rozne skupiny) + tretia unikatna (Egger U750).
def a4_schema2_data
  {
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'KR_K009_18', 'group_id' => 'GRP-KRONO', 'manufacturer' => 'Kronospan',
        'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 2, 3], 'production_class' => 'sheet' },
      { 'material_id' => 'EG_K009_18', 'group_id' => 'GRP-EGGER', 'manufacturer' => 'Egger',
        'decor' => 'K009', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [4, 5, 6], 'production_class' => 'sheet' },
      { 'material_id' => 'EG_U750_18', 'group_id' => 'GRP-U750', 'manufacturer' => 'Egger',
        'decor' => 'U750', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [7, 8, 9], 'production_class' => 'sheet' }
    ],
    'edges' => [
      { 'abs_id' => 'ABS_KR_K009', 'group_id' => 'GRP-KRONO', 'decor' => 'K009',
        'structure' => 'PW', 'thickness' => 1.0, 'width' => 23.0, 'color' => [1, 2, 3] },
      { 'abs_id' => 'ABS_EG_K009', 'group_id' => 'GRP-EGGER', 'decor' => 'K009',
        'structure' => 'ST9', 'thickness' => 1.0, 'width' => 23.0, 'color' => [4, 5, 6] }
    ]
  }
end

def a4_schema2_bytes
  JSON.pretty_generate(a4_schema2_data).b
end

# Hybrid: marker 2, ale jeden zaznam BEZ group_id (audit B1).
def a4_hybrid_bytes
  data = a4_schema2_data
  data['sheets'][0].delete('group_id')
  JSON.pretty_generate(data).b
end

# Sandbox: nainstaluje dane bajty (nil = subor chyba) ako katalog, zmaze .bak,
# predmigracnu zalohu aj hold flag a vsetko po bloku vrati PRESNE. Odlozene
# subory (rolledback/corrupted), ktore vznikli POCAS testu, sa upracu.
# Modulovy stav katalogu sa resetuje pred aj po (ziadny leak medzi testami).
def a4_with_catalog(bytes)
  path = A4MAT.path
  FileUtils.mkdir_p(A4MAT.dir)
  files = [path, "#{path}.bak", A4MAT.pre_schema2_backup_path, A4MAT.migration_hold_path]
  saved = files.to_h { |f| [f, File.exist?(f) ? File.binread(f) : nil] }
  side_glob = [File.join(A4MAT.dir, 'materials.rolledback-*.json'),
               File.join(A4MAT.dir, 'materials.corrupted-*.json')]
  side_before = side_glob.flat_map { |g| Dir[g] }
  bytes.nil? ? FileUtils.rm_f(path) : File.binwrite(path, bytes)
  FileUtils.rm_f("#{path}.bak")
  FileUtils.rm_f(A4MAT.pre_schema2_backup_path)
  FileUtils.rm_f(A4MAT.migration_hold_path)
  A4STORE.invalidate(path)
  A4MAT.reset_catalog_state!
  yield
ensure
  saved.each { |f, b| b ? File.binwrite(f, b) : FileUtils.rm_f(f) }
  (side_glob.flat_map { |g| Dir[g] } - side_before).each { |f| FileUtils.rm_f(f) }
  A4STORE.invalidate(path)
  A4MAT.reset_catalog_state!
end

def a4_disk
  JSON.parse(File.binread(A4MAT.path))
end

def a4_disk_sheet(id)
  a4_disk['sheets'].find { |s| s['material_id'] == id }
end

# ---------------------------------------------------------------------------
# assess_catalog! — matica stavov (B1 + F5)
# ---------------------------------------------------------------------------

NxTest.test('2A-4a assess: panensky stav = :ok a seed bezi ako doteraz') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(nil) do
    NxTest.assert_equal([:ok, nil], A4MAT.assess_catalog!)
    NxTest.assert_equal(:ok, A4MAT.catalog_state)
    A4MAT.catalog
    NxTest.assert(File.exist?(A4MAT.path), 'panensky stav seedne (fresh flow nezmeneny)')
  end
end

NxTest.test('2A-4a assess: legacy marker 1 aj kompletna SCHEMA 2 = :ok') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_legacy_bytes) do
    NxTest.assert_equal([:ok, nil], A4MAT.assess_catalog!)
    NxTest.assert_equal([:ok, nil], A4MAT.assess_catalog!, 'idempotentne')
  end
  a4_with_catalog(a4_schema2_bytes) do
    NxTest.assert_equal([:ok, nil], A4MAT.assess_catalog!)
    NxTest.refute(A4MAT.catalog_read_only?)
  end
end

NxTest.test('2A-4a assess: hybrid marker 2 aj novsi marker = :read_only s dovodom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_hybrid_bytes) do
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.include?('hybrid'), reason.inspect)
    NxTest.assert_equal(reason, A4MAT.catalog_state_reason)
  end
  # 2B-1: marker 3 (duplak) uz tato verzia POZNA — "novsia neznama" je 4.
  newer = JSON.parse(a4_legacy_bytes).merge('schema' => A4MAT::SCHEMA_CURRENT + 1)
  a4_with_catalog(JSON.pretty_generate(newer).b) do
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.include?('novšej schéme'), reason.inspect)
  end
end

NxTest.test('2A-4a assess: poskodeny JSON bez pouzitelnej zalohy = :read_only, subor nedotknuty') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog('xx{rozbite'.b) do
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.include?('poškodený'), reason.inspect)
    NxTest.assert_equal('xx{rozbite'.b, File.binread(A4MAT.path).b, 'poskodeny subor sa NEMAZE ani neseeduje')
    NxTest.assert(A4MAT.sheets.is_a?(Array), 'citanie bezi dalej (seedy v pamati)')
  end
end

NxTest.test('2A-4a assess F5: chybajuci primar + platny .bak = obnova, potom posudenie') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(nil) do
    File.binwrite("#{A4MAT.path}.bak", a4_legacy_bytes)
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:ok, state, reason.inspect)
    NxTest.assert_equal(a4_legacy_bytes, File.binread(A4MAT.path), 'primar = bajty .bak (atomicka obnova)')
    NxTest.assert(File.exist?("#{A4MAT.path}.bak"), '.bak sa nemaze')
  end
  a4_with_catalog(nil) do
    File.binwrite("#{A4MAT.path}.bak", a4_schema2_bytes)
    NxTest.assert_equal([:ok, nil], A4MAT.assess_catalog!, 'obnoveny kompletny SCHEMA 2 katalog = :ok')
    NxTest.assert_equal(2, A4MAT.catalog_schema)
  end
  a4_with_catalog(nil) do
    File.binwrite("#{A4MAT.path}.bak", 'zz{necitatelne')
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.include?('.bak'), reason.inspect)
    NxTest.refute(File.exist?(A4MAT.path), 'z necitatelnej zalohy sa NIC nenasadzuje')
  end
end

NxTest.test('2A-4a assess F5: poskodeny primar + platny .bak = obnova z .bak, torzo odlozene bokom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog('xx{rozbite'.b) do
    File.binwrite("#{A4MAT.path}.bak", a4_legacy_bytes)
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:ok, state, reason.inspect)
    NxTest.assert_equal(a4_legacy_bytes, File.binread(A4MAT.path), 'primar obnoveny zo zalohy')
    corrupted = Dir[File.join(A4MAT.dir, 'materials.corrupted-*.json')]
    NxTest.assert_equal(1, corrupted.length, 'poskodene bajty sa odlozia (ziadna strata stopy)')
    NxTest.assert_equal('xx{rozbite'.b, File.binread(corrupted.first).b)
  end
end

NxTest.test('2A-4a assess: poskodeny primar AJ .bak = :read_only bez znicenia suborov') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog('xx{rozbite'.b) do
    File.binwrite("#{A4MAT.path}.bak", 'yy{tiez zle')
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.include?('.bak'), reason.inspect)
    NxTest.assert_equal('xx{rozbite'.b, File.binread(A4MAT.path).b, 'primar nedotknuty')
    NxTest.assert_equal('yy{tiez zle', File.binread("#{A4MAT.path}.bak"), '.bak nedotknuty')
  end
end

NxTest.test('2A-4a assess: chybajuci katalog s predmigracnou zalohou = :read_only, seed sa NESPUSTI') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(nil) do
    File.binwrite(A4MAT.pre_schema2_backup_path, a4_legacy_bytes)
    # seed guard NEZAVISI od assess — aj bez neho sa panenskost overuje suborom
    A4MAT.catalog
    NxTest.refute(File.exist?(A4MAT.path), 'seed nesmie zamaskovat obnovitelne data (ani bez assess)')
    state, reason = A4MAT.assess_catalog!
    NxTest.assert_equal(:read_only, state)
    NxTest.assert(reason.include?('predmigračná'), reason.inspect)
    A4MAT.catalog
    NxTest.refute(File.exist?(A4MAT.path), 'ani po assess ziadny seed')
    NxTest.assert(A4MAT.sheets.is_a?(Array), 'citanie funguje (seedy v pamati)')
  end
end

# ---------------------------------------------------------------------------
# read-only vynucovanie (B4) + navrat do :ok po oprave
# ---------------------------------------------------------------------------

NxTest.test('2A-4a read-only: kazdy mutacny vstup odmietne, subor bajtovo nezmeneny, citanie bezi') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_hybrid_bytes) do
    A4MAT.assess_catalog!
    NxTest.assert(A4MAT.catalog_read_only?)
    before = File.binread(A4MAT.path)
    NxTest.refute(A4MAT.upsert_sheet('material_id' => 'NOVY_18', 'decor' => 'Novy',
                                     'type' => 'DTDL', 'thickness' => 18.0), 'upsert_sheet')
    NxTest.refute(A4MAT.upsert_edge('abs_id' => 'NOVA_ABS', 'decor' => 'Novy',
                                    'thickness' => 1.0), 'upsert_edge')
    NxTest.refute(A4MAT.delete_sheet('KR_K009_18'), 'delete_sheet')
    NxTest.refute(A4MAT.delete_edge('ABS_KR_K009'), 'delete_edge')
    ok, err = A4MAT.rename_decor('K009', 'K010', group_id: 'GRP-EGGER')
    NxTest.refute(ok, 'rename_decor')
    NxTest.assert(err.include?('len na čítanie'), err)
    ok2, err2 = A4MAT.set_decor_manufacturer('K009', 'Iny', group_id: 'GRP-EGGER')
    NxTest.refute(ok2, 'set_decor_manufacturer')
    NxTest.assert(err2.include?('len na čítanie'), err2)
    ok3, err3 = A4MAT.add_decor_batch('decor' => 'X', 'thicknesses' => '18')
    NxTest.refute(ok3, 'add_decor_batch')
    NxTest.assert(err3.include?('len na čítanie'), err3)
    NxTest.assert_equal([:catalog_read_only, nil],
                        A4MAT.ensure_edge_for_sheet('KR_K009_18', client_schema: 2))
    NxTest.assert_equal([:catalog_read_only, nil],
                        A4MAT.patch_record('sheet', 'KR_K009_18', { 'code' => 'X' }))
    NxTest.refute(A4MAT.write(A4MAT.load), 'hlbkovy guard priamo v zapisovej ceste (write_unlocked)')
    NxTest.assert_equal(before, File.binread(A4MAT.path), 'subor bajtovo nezmeneny')
    NxTest.assert_equal(3, A4MAT.sheets.length, 'citanie bezi dalej — model funguje')
  end
end

NxTest.test('2A-4a read-only: po oprave suboru novy assess vrati :ok a mutacie bezia') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_hybrid_bytes) do
    A4MAT.assess_catalog!
    NxTest.assert(A4MAT.catalog_read_only?)
    data = a4_disk
    data['sheets'].each { |s| s['group_id'] = 'GRP-FIX' if s['group_id'].to_s.strip.empty? }
    File.binwrite(A4MAT.path, JSON.pretty_generate(data))
    A4STORE.invalidate(A4MAT.path)
    state, = A4MAT.assess_catalog!
    NxTest.assert_equal(:ok, state, 'oprava + reassess = koniec nudzoveho rezimu')
    NxTest.assert(A4MAT.upsert_sheet('material_id' => 'PO_OPRAVE_18', 'decor' => 'Novy',
                                     'type' => 'DTDL', 'thickness' => 18.0,
                                     'group_id' => 'GRP-NOVA', 'structure' => 'XX'),
                  'mutacie po oprave bezia')
  end
end

# ---------------------------------------------------------------------------
# restore_pre_schema2! + migration hold (B2)
# ---------------------------------------------------------------------------

NxTest.test('2A-4a restore: uspech — primar = zaloha, rolledback odlozeny, hold flag zapisany') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    File.binwrite(A4MAT.pre_schema2_backup_path, a4_legacy_bytes)
    ok, report = A4MAT.restore_pre_schema2!
    NxTest.assert(ok, report.inspect)
    NxTest.assert_equal(a4_legacy_bytes, File.binread(A4MAT.path), 'primar = bajty predmigracnej zalohy')
    NxTest.assert_equal(a4_legacy_bytes, File.binread(A4MAT.pre_schema2_backup_path),
                        'predmigracna zaloha ostava nedotknuta (nikdy sa nemaze)')
    rolled = report['rolledback']
    NxTest.assert(rolled && File.exist?(rolled), 'odlozeny subor existuje')
    NxTest.assert(File.basename(rolled).start_with?('materials.rolledback-'), rolled.to_s)
    NxTest.assert_equal(a4_schema2_bytes, File.binread(rolled), 'odlozene = povodny primar (nemazat!)')
    NxTest.assert(A4MAT.migration_hold?, 'hold flag zapisany')
    hold = JSON.parse(File.binread(A4MAT.migration_hold_path))
    NxTest.assert_equal(true, hold['until_restart'], 'tvar flagu: until_restart true')
    NxTest.assert_equal(1, A4MAT.catalog_schema, 'katalog je spat na legacy')
    NxTest.assert_equal(:ok, A4MAT.catalog_state, 'obnoveny legacy katalog = mutacie povolene')
    NxTest.assert(A4MAT.upsert_sheet('material_id' => 'PO_ROLLBACKU_18', 'decor' => 'Novy',
                                     'type' => 'DTDL', 'thickness' => 18.0),
                  'katalog je hned pouzitelny')
  end
end

NxTest.test('2A-4a restore: chybajuca zaloha = [false, dovod] bez zasahu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    ok, err = A4MAT.restore_pre_schema2!
    NxTest.refute(ok)
    NxTest.assert(err.include?('neexistuje'), err)
    NxTest.assert_equal(a4_schema2_bytes, File.binread(A4MAT.path), 'primar bez zasahu')
    NxTest.refute(A4MAT.migration_hold?, 'ziadny hold flag')
    NxTest.assert_equal([], Dir[File.join(A4MAT.dir, 'materials.rolledback-*.json')])
  end
end

NxTest.test('2A-4a restore: poskodena/nelegacy zaloha = [false, dovod] bez zasahu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    ['xx{zle', '{}', 'null', a4_schema2_bytes].each do |zly|
      File.binwrite(A4MAT.pre_schema2_backup_path, zly)
      ok, err = A4MAT.restore_pre_schema2!
      NxTest.refute(ok, "zaloha '#{zly[0, 12]}' nie je legacy katalog")
      NxTest.assert(err.include?('nie je platný legacy'), err)
      NxTest.assert_equal(a4_schema2_bytes, File.binread(A4MAT.path), 'primar bez zasahu')
      NxTest.refute(A4MAT.migration_hold?, 'hold flag sa nezapisal')
      NxTest.assert_equal([], Dir[File.join(A4MAT.dir, 'materials.rolledback-*.json')],
                          'ziadny rolledback subor')
    end
  end
end

NxTest.test('2A-4a hold: jednorazovost — 1. boot preskoci a zmaze, 2. boot uz miguje normalne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    File.binwrite(A4MAT.pre_schema2_backup_path, a4_legacy_bytes)
    ok, = A4MAT.restore_pre_schema2!
    NxTest.assert(ok)
    NxTest.assert(A4MAT.migration_hold?)
    # simulacia "1. boot" (2A-4b): check-and-consume v jednom kroku
    NxTest.assert_equal(true, A4MAT.consume_migration_hold!, '1. start: hold existoval — migracia sa preskoci')
    NxTest.refute(A4MAT.migration_hold?, 'flag je zmazany')
    # simulacia "2. boot": ziadne potlacenie — migracia by uz bezala normalne
    NxTest.assert_equal(false, A4MAT.consume_migration_hold!, '2. start: ziadny hold')
  end
end

NxTest.test('2A-4a restore: funguje aj z read-only stavu (nudzova cesta) a stav sa vrati na :ok') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog('xx{rozbite'.b) do
    File.binwrite(A4MAT.pre_schema2_backup_path, a4_legacy_bytes)
    A4MAT.assess_catalog!
    NxTest.assert(A4MAT.catalog_read_only?, 'poskodeny katalog bez .bak = nudzovy rezim')
    ok, report = A4MAT.restore_pre_schema2!
    NxTest.assert(ok, report.inspect)
    NxTest.assert_equal(:ok, A4MAT.catalog_state, 'obnova = oprava, mutacie sa odomknu')
    NxTest.assert_equal(a4_legacy_bytes, File.binread(A4MAT.path))
    NxTest.assert_equal('xx{rozbite'.b, File.binread(report['rolledback']).b,
                        'poskodeny primar odlozeny, nie zmazany')
  end
end

# ---------------------------------------------------------------------------
# skupinove operacie cez group_id (B3)
# ---------------------------------------------------------------------------

NxTest.test('2A-4a B3: rename_decor cez group_id meni VYHRADNE jednu skupinu; text viacznacny odmietne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    ok, err = A4MAT.rename_decor('K009', 'K999')
    NxTest.refute(ok, 'text matchujuci dve skupiny sa musi odmietnut')
    NxTest.assert(err.include?('viaceré skupiny'), err)
    NxTest.assert(err.include?('Egger') && err.include?('Kronospan'), "dovod menuje vyrobcov: #{err}")
    ok2, count = A4MAT.rename_decor('', 'K010', group_id: 'GRP-KRONO')
    NxTest.assert(ok2, count.inspect)
    NxTest.assert_equal(2, count, 'doska + paska skupiny Kronospan')
    out = a4_disk
    NxTest.assert_equal('K010', a4_disk_sheet('KR_K009_18')['decor'])
    NxTest.assert_equal('K010', out['edges'].find { |a| a['abs_id'] == 'ABS_KR_K009' }['decor'])
    NxTest.assert_equal('K009', a4_disk_sheet('EG_K009_18')['decor'], 'cudzia skupina NEDOTKNUTA')
    NxTest.assert_equal('K009', out['edges'].find { |a| a['abs_id'] == 'ABS_EG_K009' }['decor'])
    NxTest.assert_equal('GRP-KRONO', a4_disk_sheet('KR_K009_18')['group_id'],
                        'group_id sa pri rename NIKDY neprepocitava')
    # po zjednoznacneni funguje textovy fallback (legacy volanie klienta 1)
    ok3, count3 = A4MAT.rename_decor('K009', 'K011')
    NxTest.assert(ok3, count3.inspect)
    NxTest.assert_equal(2, count3, 'jednoznacny text = skupina Egger')
    NxTest.assert_equal('K011', a4_disk_sheet('EG_K009_18')['decor'])
    NxTest.assert_equal('K010', a4_disk_sheet('KR_K009_18')['decor'], 'Kronospan ostal K010')
    NxTest.refute(A4MAT.rename_decor('', 'X', group_id: 'GRP-NEEXISTUJE')[0], 'neznamy group_id')
  end
end

NxTest.test('2A-4a B3: rename guardy — kolizia u vyrobcu, near-match, iny vyrobca OK, case-fix OK') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    ok, err = A4MAT.rename_decor('', 'K009', group_id: 'GRP-U750')
    NxTest.refute(ok, 'Egger uz K009 ma — zlucenie skupin sa premenovanim nerobi')
    NxTest.assert(err.include?('zlúčenie'), err)
    ok2, err2 = A4MAT.rename_decor('', 'k 009', group_id: 'GRP-U750')
    NxTest.refute(ok2, 'near-match u toho isteho vyrobcu')
    NxTest.assert(err2.include?('len zápisom'), err2)
    ok3, = A4MAT.rename_decor('', 'U750', group_id: 'GRP-KRONO')
    NxTest.assert(ok3, 'rovnaky text u INEHO vyrobcu = legalne dve skupiny')
    NxTest.assert_equal('U750', a4_disk_sheet('KR_K009_18')['decor'])
    NxTest.assert_equal('U750', a4_disk_sheet('EG_U750_18')['decor'], 'povodna U750 skupina nedotknuta')
    ok4, = A4MAT.rename_decor('', 'u750', group_id: 'GRP-U750')
    NxTest.assert(ok4, 'oprava zapisu VLASTNEJ skupiny (case-fix) prejde')
    NxTest.assert_equal('u750', a4_disk_sheet('EG_U750_18')['decor'])
  end
end

NxTest.test('2A-4a B3: set_decor_manufacturer cez group_id + kolizia obchodnej identity skupiny') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_schema2_bytes) do
    ok0, err0 = A4MAT.set_decor_manufacturer('K009', 'Firma')
    NxTest.refute(ok0, 'viacznacny text sa odmietne')
    NxTest.assert(err0.include?('viaceré skupiny'), err0)
    ok, count = A4MAT.set_decor_manufacturer('', 'Firma', group_id: 'GRP-KRONO')
    NxTest.assert(ok, count.inspect)
    NxTest.assert_equal(1, count, '1 doska skupiny Kronospan')
    out = a4_disk
    kr = a4_disk_sheet('KR_K009_18')
    NxTest.assert_equal(%w[Firma], [kr['manufacturer']])
    NxTest.assert_equal('Firma K009', kr['family'])
    NxTest.assert_equal('Egger', a4_disk_sheet('EG_K009_18')['manufacturer'], 'cudzia skupina nedotknuta')
    NxTest.refute(out['edges'].find { |a| a['abs_id'] == 'ABS_KR_K009' }.key?('manufacturer'),
                  'paska vyrobcu NIKDY nenesie')
    ok2, err2 = A4MAT.set_decor_manufacturer('', 'Egger', group_id: 'GRP-KRONO')
    NxTest.refute(ok2, 'Egger + K009 uz existuje — identita skupiny by sa zdvojila')
    NxTest.assert(err2.include?('už existuje'), err2)
    ok3, = A4MAT.set_decor_manufacturer('U750', 'Nova Firma')
    NxTest.assert(ok3, 'jednoznacny textovy fallback funguje')
    NxTest.assert_equal('Nova Firma', a4_disk_sheet('EG_U750_18')['manufacturer'])
    # skupina len s paskou nema dosku, ktora by vyrobcu niesla
    data = a4_disk
    data['edges'] << { 'abs_id' => 'ABS_SOLO', 'group_id' => 'GRP-SOLO', 'decor' => 'SOLO',
                       'thickness' => 1.0, 'color' => [1, 2, 3] }
    File.binwrite(A4MAT.path, JSON.pretty_generate(data))
    A4STORE.invalidate(A4MAT.path)
    ok4, err4 = A4MAT.set_decor_manufacturer('', 'Firma', group_id: 'GRP-SOLO')
    NxTest.refute(ok4)
    NxTest.assert(err4.include?('nemá dosky'), err4)
  end
end

NxTest.test('2A-4a B3: model_decor_usage v SCHEMA 2 agreguje per group_id (skupiny sa nemiesaju)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  st = Noxun::Engine::Store
  a4_with_catalog(a4_schema2_bytes) do
    p1 = NxTest::FakeInstance.new(41)
    st.write(p1, { kind: 'part', id: 'CAB-4A-A', config: { 'material_id' => 'KR_K009_18' } })
    p2 = NxTest::FakeInstance.new(42)
    st.write(p2, { kind: 'part', id: 'CAB-4A-B', config: { 'material_id' => 'EG_K009_18' } })
    board = NxTest::FakeInstance.new(43)
    st.write(board, { kind: 'board', id: 'BRD-4A', config: { 'material_id' => 'EG_K009_18', 'quantity' => 3 } })
    model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([p1, p2, board])])
    usage = A4MAT.model_decor_usage(model)
    NxTest.assert_equal(1, usage['GRP-KRONO'], 'Kronospan len vlastne kusy')
    NxTest.assert_equal(4, usage['GRP-EGGER'], 'Egger: 1 dielec + doska 3 ks')
    NxTest.refute(usage.key?('K009'), 'ziadne zlievanie pod textom dekoru')
  end
end

# ---------------------------------------------------------------------------
# patch_record atomicita (F7)
# ---------------------------------------------------------------------------

NxTest.test('2A-4a F7: patch_record rev check bezi nad CERSTVYM diskom — stale cache neprejde') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_legacy_bytes) do
    old_rev = A4MAT.record_rev(A4MAT.sheet('L18')) # nacita a zoteplí cache
    # cudzi proces zmeni subor PRIAMO na disku — cache o tom nevie (ziadny
    # invalidate; CHECK_INTERVAL drzi stary pohlad ~1 s = presne okno F7)
    data = a4_disk
    data['sheets'][0]['supplier'] = 'Cudzi'
    File.binwrite(A4MAT.path, JSON.pretty_generate(data))
    status, = A4MAT.patch_record('sheet', 'L18', { 'code' => 'MOJ' }, row_rev: old_rev)
    NxTest.assert_equal(:conflict, status, 'rev z predkonfliktneho pohladu = :conflict (nie tichy prepis)')
    NxTest.assert_equal('Cudzi', a4_disk_sheet('L18')['supplier'], 'cudzia zmena nedotknuta')
    NxTest.refute(a4_disk_sheet('L18').key?('code'), 'ziadny zapis pri konflikte')
    # cerstvy rev z disku prejde a merge bezi nad cerstvym zaznamom
    fresh_rev = A4MAT.record_rev(a4_disk_sheet('L18'))
    status2, = A4MAT.patch_record('sheet', 'L18', { 'code' => 'MOJ' }, row_rev: fresh_rev)
    NxTest.assert_equal(:ok, status2)
    rec = a4_disk_sheet('L18')
    NxTest.assert_equal(%w[MOJ Cudzi], [rec['code'], rec['supplier']],
                        'patch + cudzia zmena spolu (merge nad cerstvym obsahom)')
  end
end

# ---------------------------------------------------------------------------
# :conflict reklasifikacia migracie (F6)
# ---------------------------------------------------------------------------

NxTest.test('2A-4a F6: cudzia kompletna SCHEMA 2 pri CAS = :already s reloadom, ziadny zapis') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_legacy_bytes) do
    foreign = a4_schema2_bytes
    rep = A4MAT.migrate_to_schema2!(before_write: -> { File.binwrite(A4MAT.path, foreign) })
    NxTest.assert_equal(:already, rep[:status], rep.inspect)
    NxTest.assert_equal(foreign, File.binread(A4MAT.path), 'cudzi novsi stav sa NEPREPISE')
    NxTest.assert_equal(2, A4MAT.catalog_schema, 'cache je invalidovana (reload) — marker cita 2')
    NxTest.refute(File.exist?(A4MAT.pre_schema2_backup_path), ':already z konfliktu zalohu nevytvara')
  end
end

NxTest.test('2A-4a F6: konflikt so STALE legacy obsahom = jeden retry zmigruje NOVY obsah') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_legacy_bytes) do
    fired = [false]
    hook = lambda do
      next if fired[0]
      fired[0] = true
      data = JSON.parse(a4_legacy_bytes)
      data['sheets'][0]['price_per_m2'] = 55.5
      File.binwrite(A4MAT.path, JSON.pretty_generate(data))
    end
    rep = A4MAT.migrate_to_schema2!(before_write: hook)
    NxTest.assert_equal(:ok, rep[:status], rep.inspect)
    out = a4_disk
    NxTest.assert_equal(2, out['schema'], 'retry zmigroval')
    NxTest.assert_equal(55.5, a4_disk_sheet('L18')['price_per_m2'],
                        'zmigroval sa NOVY obsah (cudzia zmena zachovana, ziadna recyklacia planu)')
    backup = JSON.parse(File.binread(A4MAT.pre_schema2_backup_path))
    NxTest.assert_equal(55.5, backup['sheets'][0]['price_per_m2'],
                        'predmigracna zaloha = obsah, ktory sa realne migroval')
  end
end

NxTest.test('2A-4a F6: dvojity konflikt = :conflict, posledna cudzia zmena nedotknuta') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_legacy_bytes) do
    calls = [0]
    hook = lambda do
      calls[0] += 1
      data = JSON.parse(a4_legacy_bytes)
      data['sheets'][0]['price_per_m2'] = 100.0 + calls[0]
      File.binwrite(A4MAT.path, JSON.pretty_generate(data))
    end
    rep = A4MAT.migrate_to_schema2!(before_write: hook)
    NxTest.assert_equal(:conflict, rep[:status], rep.inspect)
    NxTest.assert_equal(2, calls[0], 'presne dva pokusy (jeden retry, ziadna slucka)')
    out = a4_disk
    NxTest.refute(out.key?('schema') && out['schema'].to_i >= 2, 'katalog ostal legacy')
    NxTest.assert_equal(102.0, a4_disk_sheet('L18')['price_per_m2'], 'posledny cudzi zapis nedotknuty')
    NxTest.refute(File.exist?(A4MAT.pre_schema2_backup_path), 'konflikt zalohu nevytvara')
  end
end

# ---------------------------------------------------------------------------
# GH #92 kolo 1 (3x P1)
# ---------------------------------------------------------------------------

NxTest.test('2a4a: GH P1 — platny JSON s nevalidnym legacy tvarom = :read_only (ziadne tiche seedy)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ['{}', '{"std": 1, "sheets": "nie-pole", "edges": []}'].each do |zly|
    a4_with_catalog(zly.b) do
      state, reason = A4MAT.assess_catalog!
      NxTest.assert_equal(:read_only, state, "tvar '#{zly[0, 25]}' nesmie byt :ok")
      NxTest.assert(reason.to_s.include?('tvar'), reason.to_s)
      NxTest.refute(A4MAT.upsert_sheet('material_id' => 'X', 'decor' => 'X', 'type' => 'DTDL',
                                       'thickness' => 18.0), 'mutacie zamknute')
      NxTest.assert_equal(zly, File.binread(A4MAT.path), 'subor bajtovo nedotknuty (ziadne seedy)')
    end
  end
end

NxTest.test('2a4a: GH P1 — mutator vidi cerstvy obsah (cudzi zapis pred zamkom prezije upsert)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a4_with_catalog(a4_legacy_bytes) do
    A4MAT.catalog # warm cache
    raw = JSON.parse(File.binread(A4MAT.path))
    raw['sheets'] << { 'material_id' => 'CUDZI_18', 'decor' => 'Cudzi Dekor', 'type' => 'DTDL',
                       'thickness' => 18.0, 'grain' => 'length', 'color' => [9, 9, 9],
                       'production_class' => 'sheet' }
    File.binwrite(A4MAT.path, JSON.pretty_generate(raw))
    NxTest.assert(A4MAT.upsert_sheet('material_id' => 'NOVY_18', 'decor' => 'Novy Dekor',
                                     'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
                                     'color' => [1, 1, 1]), 'upsert presiel')
    after = JSON.parse(File.binread(A4MAT.path))
    ids = after['sheets'].map { |s| s['material_id'] }
    NxTest.assert(ids.include?('CUDZI_18'), 'cudzi zapis PREZIL upsert (fresh load pod zamkom)')
    NxTest.assert(ids.include?('NOVY_18'))
  end
end

NxTest.test('2a4a: GH P1 — rollback obnovi aj .bak (stale SCHEMA 2 zaloha nemoze zvratit rollback)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  s2 = JSON.pretty_generate(a4_schema2_data).b
  a4_with_catalog(s2) do
    File.binwrite(A4MAT.pre_schema2_backup_path, a4_legacy_bytes)
    File.binwrite("#{A4MAT.path}.bak", s2) # stale post-migracna zaloha
    ok, rep = A4MAT.restore_pre_schema2!
    NxTest.assert(ok, rep.inspect)
    NxTest.assert_equal(a4_legacy_bytes, File.binread("#{A4MAT.path}.bak"),
                        '.bak je po rollbacku legacy (sucast transakcie)')
    quarantined = Dir[File.join(A4MAT.dir, 'materials.json.bak.pre-rollback-*.json')]
    NxTest.assert_equal(1, quarantined.length, 'stara .bak odlozena, nie zmazana')
    NxTest.assert_equal(s2, File.binread(quarantined[0]))
    # a assess po "strate" primaru uz NEobnovi schema 2
    FileUtils.rm_f(A4MAT.path)
    A4STORE.invalidate(A4MAT.path)
    state, = A4MAT.assess_catalog!
    NxTest.assert_equal(:ok, state, 'obnova z .bak da LEGACY katalog (rollback drzi)')
    NxTest.assert(A4MAT.catalog_schema < 2, 'primar obnoveny z legacy .bak')
    quarantined.each { |f| FileUtils.rm_f(f) }
  end
end

NxTest.test('2a4a: GH P1 kolo 2 — zapis do novsej schemy sa odmieta aj BEZ behu assess (backstop v write)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  # 2B-1: marker 3 uz tato verzia pozna a pise don — backstop chrani od 4 vyssie.
  s4 = JSON.pretty_generate(a4_schema2_data.merge('schema' => A4MAT::SCHEMA_CURRENT + 1)).b
  a4_with_catalog(s4) do
    # ZIADNY assess — stav je :ok default (proces, ktory o novsej scheme nevie)
    NxTest.refute(A4MAT.upsert_sheet('material_id' => 'X18', 'decor' => 'X', 'type' => 'DTDL',
                                     'thickness' => 18.0, 'grain' => 'length', 'group_id' => 'GX'),
                  'mutacia do novsej schemy katalogu sa odmietne backstopom v zapise')
    NxTest.assert_equal(s4, File.binread(A4MAT.path), 'subor bajtovo nedotknuty')
  end
end

NxTest.test('2a4a: GH P1 kolo 2 — pad PRED vymenou primaru necha migrovany stav neporuseny (staging poradie)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  s2 = JSON.pretty_generate(a4_schema2_data).b
  a4_with_catalog(s2) do
    File.binwrite(A4MAT.pre_schema2_backup_path, a4_legacy_bytes)
    File.binwrite("#{A4MAT.path}.bak", s2)
    orig = A4MAT.method(:deploy_bytes)
    begin
      # pad presne pri nasadzovani PRIMARU (posledny krok)
      A4MAT.define_singleton_method(:deploy_bytes) do |target, bytes|
        raise IOError, 'disk full (test)' if target == A4MAT.path
        orig.call(target, bytes)
      end
      ok, msg = A4MAT.restore_pre_schema2!
      NxTest.refute(ok, "rollback musi ohlasit neuspech: #{msg.inspect}")
    ensure
      A4MAT.define_singleton_method(:deploy_bytes, orig)
    end
    NxTest.assert_equal(s2, File.binread(A4MAT.path), 'primar OSTAL migrovany (pad pred vymenou)')
    NxTest.assert_equal(a4_legacy_bytes, File.binread("#{A4MAT.path}.bak"),
                        '.bak uz je legacy — smer rollbacku, nie zvrat')
    state, = A4MAT.assess_catalog!
    NxTest.assert_equal(:ok, state, 'migrovany katalog bezi dalej')
    Dir[File.join(A4MAT.dir, 'materials.json.bak.pre-rollback-*.json')].each { |f| FileUtils.rm_f(f) }
    Dir[File.join(A4MAT.dir, 'materials.rolledback-*.json')].each { |f| FileUtils.rm_f(f) }
  end
end
