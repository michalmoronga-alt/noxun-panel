# frozen_string_literal: true
# Testy 2A-4b: OSTRY CUTOVER katalogu na SCHEMA 2 — boot_cutover! matica
# (audit O4 + F11), seedy nativne SCHEMA 2 (F9 + O3), universal cez patch
# (PATCHABLE rozsirenie + F7 vetvy), labely s kolizou vyrobcov (F10) a
# server-side pocet nepouzitelnych pasok pre banner (O2).
#
# Vsetko headless nad APPDATA sandboxom helpera; kazdy test si stav katalogu
# instaluje a v ensure VRACIA (vzor a4_with_catalog z test_2a4a_hardening).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

# Panel labely (sheet_label/abs_label/label_ctx) ziju v ui/panel/payloads.rb —
# reopen modulu Panel bez SketchUp zavislosti pri load (metody volaju len
# Materials), preto sa da pouzit aj headless.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')

B4MAT = Noxun::Engine::Materials
B4STORE = Noxun::Engine::JsonFileStore
B4PANEL = Noxun::Engine::Panel

# Sandbox (vzor a4_with_catalog): nainstaluje dane bajty (nil = subor chyba),
# zmaze .bak/predmigracnu zalohu/hold flag a po bloku vsetko PRESNE vrati.
def b4_with_catalog(bytes)
  path = B4MAT.path
  FileUtils.mkdir_p(B4MAT.dir)
  files = [path, "#{path}.bak", B4MAT.pre_schema2_backup_path, B4MAT.migration_hold_path]
  saved = files.to_h { |f| [f, File.exist?(f) ? File.binread(f) : nil] }
  side_glob = [File.join(B4MAT.dir, 'materials.rolledback-*.json'),
               File.join(B4MAT.dir, 'materials.corrupted-*.json')]
  side_before = side_glob.flat_map { |g| Dir[g] }
  bytes.nil? ? FileUtils.rm_f(path) : File.binwrite(path, bytes)
  FileUtils.rm_f("#{path}.bak")
  FileUtils.rm_f(B4MAT.pre_schema2_backup_path)
  FileUtils.rm_f(B4MAT.migration_hold_path)
  B4STORE.invalidate(path)
  B4MAT.reset_catalog_state!
  yield
ensure
  saved.each { |f, b| b ? File.binwrite(f, b) : FileUtils.rm_f(f) }
  (side_glob.flat_map { |g| Dir[g] } - side_before).each { |f| FileUtils.rm_f(f) }
  B4STORE.invalidate(path)
  B4MAT.reset_catalog_state!
end

def b4_legacy_seed_bytes
  JSON.pretty_generate(JSON.parse(JSON.generate(NxTest::LEGACY_SEED_CATALOG))).b
end

# SCHEMA 2 katalog: dve skupiny s ROVNAKYM cislom K111 (Egger + Kronospan =
# kolizia labelov), unikatna U750, pasky so strukturou / bez struktury /
# universal — podklad pre patch, labely aj banner count.
def b4_schema2_data
  {
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'EG_K111_18', 'group_id' => 'GRP-EG-K111', 'manufacturer' => 'Egger',
        'decor' => 'K111', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 2, 3], 'production_class' => 'sheet' },
      { 'material_id' => 'KR_K111_18', 'group_id' => 'GRP-KR-K111', 'manufacturer' => 'Kronospan',
        'decor' => 'K111', 'structure' => 'PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [4, 5, 6], 'production_class' => 'sheet' },
      { 'material_id' => 'EG_U750_18', 'group_id' => 'GRP-EG-U750', 'manufacturer' => 'Egger',
        'decor' => 'U750', 'decor_name' => 'Taupe šedá', 'structure' => 'ST9', 'type' => 'DTDL',
        'thickness' => 18.0, 'grain' => 'length', 'color' => [7, 8, 9], 'production_class' => 'sheet' }
    ],
    'edges' => [
      { 'abs_id' => 'ABS_EG_K111', 'group_id' => 'GRP-EG-K111', 'decor' => 'K111',
        'structure' => 'ST9', 'thickness' => 1.0, 'width' => 23.0, 'color' => [1, 2, 3] },
      { 'abs_id' => 'ABS_BEZ_1', 'group_id' => 'GRP-EG-U750', 'decor' => 'U750',
        'thickness' => 1.0, 'width' => 23.0, 'color' => [7, 8, 9] },
      { 'abs_id' => 'ABS_BEZ_2', 'group_id' => 'GRP-KR-K111', 'decor' => 'K111',
        'thickness' => 1.0, 'color' => [4, 5, 6] },
      { 'abs_id' => 'ABS_UNI_X', 'group_id' => 'GRP-EG-U750', 'decor' => 'U750',
        'thickness' => 1.0, 'width' => 43.0, 'universal' => true, 'color' => [7, 8, 9] }
    ]
  }
end

def b4_schema2_bytes
  JSON.pretty_generate(b4_schema2_data).b
end

def b4_disk
  JSON.parse(File.binread(B4MAT.path))
end

# ---------------------------------------------------------------------------
# boot_cutover! — matica (audit O4 + F11)
# ---------------------------------------------------------------------------

NxTest.test('2a4b boot: fresh stav = :not_found, NIC sa nezapisuje (seed flow bezi az pri pristupe)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(nil) do
    NxTest.assert_equal(:not_found, B4MAT.boot_cutover!)
    NxTest.refute(File.exist?(B4MAT.path), 'boot NIKDY neseeduje')
    NxTest.assert_equal(:ok, B4MAT.catalog_state)
    B4MAT.catalog # seed flow (bod 6): prvy pristup seedne NATIVNE SCHEMA 2
    NxTest.assert_equal(2, JSON.parse(File.binread(B4MAT.path))['schema'].to_i)
  end
end

NxTest.test('2a4b boot: legacy katalog sa OSTRO zmigruje (zaloha + marker 2 + stav :ok)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    NxTest.assert_equal(:migrated, B4MAT.boot_cutover!)
    NxTest.assert_equal(2, B4MAT.catalog_schema, 'katalog nesie marker 2')
    NxTest.assert_equal(:ok, B4MAT.catalog_state)
    NxTest.assert(File.exist?(B4MAT.pre_schema2_backup_path), 'predmigracna zaloha existuje')
    NxTest.assert_equal(b4_legacy_seed_bytes, File.binread(B4MAT.pre_schema2_backup_path).b,
                        'zaloha je bajtova kopia povodiny')
    k = B4MAT.sheet('K009_PW_DTDL_18')
    NxTest.assert_equal('K009', k['decor'])
    NxTest.assert_equal('PW', k['structure'])
    # Migrovany katalog a cerstvy seed zdielaju group_id_for autoritu — skupiny sedia.
    NxTest.assert_equal(B4MAT.group_id_for('Kronospan', 'K009'), k['group_id'])
    # Druhy boot uz nemigruje (marker 2 kompletny).
    NxTest.assert_equal(:schema2, B4MAT.boot_cutover!)
  end
end

NxTest.test('2a4b boot: hold flag = migracia sa RAZ preskoci a flag sa zmaze (B2)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    B4MAT.write_migration_hold!
    NxTest.assert_equal(:hold, B4MAT.boot_cutover!)
    NxTest.refute(File.exist?(B4MAT.migration_hold_path), 'hold sa konzumuje (zmaze)')
    NxTest.assert_equal(1, B4MAT.catalog_schema, 'katalog OSTAVA legacy (ziadna migracia)')
    NxTest.assert_equal(:ok, B4MAT.catalog_state, 'assess bezal — legacy je :ok')
    # Dalsi start (bez holdu) migruje normalne.
    NxTest.assert_equal(:migrated, B4MAT.boot_cutover!)
    NxTest.assert_equal(2, B4MAT.catalog_schema)
  end
end

NxTest.test('2a4b boot: :undecidable = katalog OSTAVA legacy, dual-mode BEZI, mutacie sa NEZAMYKAJU') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  data = JSON.parse(JSON.generate(NxTest::LEGACY_SEED_CATALOG))
  data['sheets'][0]['structure'] = 'PW' # hybridny kluc v legacy zazname => undecidable
  bytes = JSON.pretty_generate(data).b
  b4_with_catalog(bytes) do
    NxTest.assert_equal(:undecidable, B4MAT.boot_cutover!)
    NxTest.assert_equal(bytes, File.binread(B4MAT.path).b, 'atomicky NO-OP — subor nedotknuty')
    NxTest.assert_equal(1, B4MAT.catalog_schema)
    NxTest.assert_equal(:ok, B4MAT.catalog_state, 'NIE read-only (standard: nerozhodnutelne = NO-OP, nie porucha)')
    NxTest.refute(B4MAT.catalog_read_only?)
    NxTest.assert(B4MAT.upsert_sheet('material_id' => 'B4_TMP', 'decor' => 'B4 Tmp',
                                     'type' => 'DTDL', 'thickness' => 18.0),
                  'mutacie v dual-mode bezia dalej')
    NxTest.assert(B4MAT.delete_sheet('B4_TMP'))
  end
end

NxTest.test('2a4b boot: hybrid marker 2 = :read_only (mutacie zamknute), poskodeny JSON tiez') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  hybrid = b4_schema2_data
  hybrid['sheets'][0].delete('group_id')
  b4_with_catalog(JSON.pretty_generate(hybrid).b) do
    NxTest.assert_equal(:read_only, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.catalog_read_only?)
    NxTest.refute(B4MAT.upsert_sheet('material_id' => 'X', 'decor' => 'X', 'type' => 'DTDL',
                                     'thickness' => 18.0), 'mutacia v read-only neprejde')
  end
  b4_with_catalog('xx{rozbite'.b) do
    NxTest.assert_equal(:read_only, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.catalog_read_only?)
    NxTest.assert_equal('xx{rozbite'.b, File.binread(B4MAT.path).b, 'subor nedotknuty')
  end
end

NxTest.test('2a4b boot: kompletna SCHEMA 2 = :schema2 (nic sa nedeje), rollback slucka funguje') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    NxTest.assert_equal(:migrated, B4MAT.boot_cutover!)
    # Rollback (tlacidlo v okne Materialy): zaloha sa nasadi + hold flag.
    ok, report = B4MAT.restore_pre_schema2!
    NxTest.assert(ok, report.inspect)
    NxTest.assert_equal(1, B4MAT.catalog_schema, 'katalog je spat legacy')
    NxTest.assert(B4MAT.migration_hold?, 'hold flag zapisany')
    # Boot po rollbacku: hold drzi (skip), dalsi boot migruje znova.
    NxTest.assert_equal(:hold, B4MAT.boot_cutover!)
    NxTest.assert_equal(1, B4MAT.catalog_schema)
    NxTest.assert_equal(:migrated, B4MAT.boot_cutover!)
    NxTest.assert_equal(2, B4MAT.catalog_schema)
  end
end

# ---------------------------------------------------------------------------
# Seedy nativne SCHEMA 2 (audit F9 + O3)
# ---------------------------------------------------------------------------

NxTest.test('2a4b seeds: marker 2, deterministicke group_id, struktury z nazvov, decor_name') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  parsed = b4_disk
  NxTest.assert_equal(2, parsed['schema'].to_i, 'panensky seed nesie marker 2')
  NxTest.assert(B4MAT.schema2_complete?(parsed['sheets'], parsed['edges']), 'kazdy zaznam ma group_id')
  k18 = B4MAT.sheet('K009_PW_DTDL_18')
  k16 = B4MAT.sheet('K009_PW_DTDL_16')
  ke10 = B4MAT.edge('ABS_K009_10')
  NxTest.assert_equal('K009', k18['decor'])
  NxTest.assert_equal('PW', k18['structure'])
  NxTest.assert_equal(B4MAT.group_id_for('Kronospan', 'K009'), k18['group_id'],
                      'group_id z rovnakej autority ako migracia (group_id_for)')
  NxTest.assert_equal(k18['group_id'], k16['group_id'])
  NxTest.assert_equal(k18['group_id'], ke10['group_id'], 'doska a paska zdielaju skupinu')
  w = B4MAT.sheet('W1000_DTDL_18')
  NxTest.assert_equal(%w[W1000 ST9 Biela], [w['decor'], w['structure'], w['decor_name']])
  hdf = B4MAT.sheet('HDF_WHITE_3')
  NxTest.assert_equal('Biela HDF', hdf['decor'])
  NxTest.assert_equal(nil, hdf['structure'], 'HDF biela je vedome bez struktury')
end

NxTest.test('2a4b seeds: pasky nesu strukturu dosky, universal NIE (O3) — picker funguje HNED') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  B4MAT.edges.each do |a|
    NxTest.refute(a['universal'] == true, "seed paska #{a['abs_id']} nesmie byt universal (O3)")
    NxTest.refute(a['structure'].to_s.strip.empty?, "seed paska #{a['abs_id']} nesie strukturu")
  end
  NxTest.assert_equal(0, B4MAT.unusable_edges_count, 'fresh install nema nepouzitelne pasky (banner 0)')
  # K009 picker (abs_for_sheet, vetva A — presna struktura) hned po instalacii:
  k = B4MAT.sheet('K009_PW_DTDL_18')
  NxTest.assert_equal(['ABS_K009_10', nil], B4MAT.abs_for_sheet(k, :jednotka, 18.0))
  NxTest.assert_equal(['ABS_K009_20', nil], B4MAT.abs_for_sheet(k, :dvojka, 18.0))
  w = B4MAT.sheet('W1000_DTDL_18')
  NxTest.assert_equal(['ABS_W1000_10', nil], B4MAT.abs_for_sheet(w, :jednotka, 18.0))
end

# ---------------------------------------------------------------------------
# Universal cez patch_record (PATCHABLE rozsirenie + F7 vetvy)
# ---------------------------------------------------------------------------

NxTest.test('2a4b patch: universal true/false cez patch_record — merge-safe kluc, identita nedotknuta') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_schema2_bytes) do
    rec = B4MAT.edge('ABS_BEZ_2')
    NxTest.assert_equal(2, B4MAT.unusable_edges_count, 'ABS_BEZ_1 + ABS_BEZ_2 (universal ABS_UNI_X sa nerata)')
    status, = B4MAT.patch_record('edge', 'ABS_BEZ_2', { 'universal' => true },
                                 row_rev: B4MAT.record_rev(rec))
    NxTest.assert_equal(:ok, status)
    fresh = B4MAT.edge('ABS_BEZ_2')
    NxTest.assert_equal(true, fresh['universal'])
    NxTest.assert_equal('GRP-KR-K111', fresh['group_id'], 'identita sa patchom nemeni')
    NxTest.assert_equal(1, B4MAT.unusable_edges_count, 'oznacena paska z banneru zmizla')
    # Vypnutie: false hodnotu normalize kluc ODSTRANI (merge-safe, ziadne false v JSON).
    status2, = B4MAT.patch_record('edge', 'ABS_BEZ_2', { 'universal' => false },
                                  row_rev: B4MAT.record_rev(fresh))
    NxTest.assert_equal(:ok, status2)
    back = B4MAT.edge('ABS_BEZ_2')
    NxTest.refute(back.key?('universal'), 'false = kluc prec')
    NxTest.assert_equal(2, B4MAT.unusable_edges_count)
  end
end

NxTest.test('2a4b patch: universal vetvy zlyhania — :conflict (staly rev) a :catalog_read_only') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_schema2_bytes) do
    status, = B4MAT.patch_record('edge', 'ABS_BEZ_2', { 'universal' => true }, row_rev: 'staly-rev')
    NxTest.assert_equal(:conflict, status)
    NxTest.refute(B4MAT.edge('ABS_BEZ_2').key?('universal'), 'konflikt = ziadny zapis')
  end
  hybrid = b4_schema2_data
  hybrid['sheets'][0].delete('group_id')
  b4_with_catalog(JSON.pretty_generate(hybrid).b) do
    B4MAT.assess_catalog!
    status, = B4MAT.patch_record('edge', 'ABS_BEZ_2', { 'universal' => true })
    NxTest.assert_equal(:catalog_read_only, status)
  end
end

# ---------------------------------------------------------------------------
# Labely (audit F10): struktura + vyrobca LEN pri kolizii cisla dekoru
# ---------------------------------------------------------------------------

NxTest.test('2a4b labely: struktura v labeli, vyrobca LEN pri kolizii, univ. priznak ABS') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_schema2_bytes) do
    ctx = B4PANEL.label_ctx
    NxTest.refute(ctx.nil?, 'SCHEMA 2 ma label kontext')
    # K111 maju dvaja vyrobcovia -> label nesie vyrobcu; U750 je unikat -> bez vyrobcu.
    NxTest.assert_equal('Egger K111 ST9 · DTDL 18 mm', B4PANEL.sheet_label(B4MAT.sheet('EG_K111_18'), ctx))
    NxTest.assert_equal('Kronospan K111 PW · DTDL 18 mm', B4PANEL.sheet_label(B4MAT.sheet('KR_K111_18'), ctx))
    NxTest.assert_equal('U750 ST9 Taupe šedá · DTDL 18 mm', B4PANEL.sheet_label(B4MAT.sheet('EG_U750_18'), ctx))
    # ABS: struktura + sirka/hrubka; kolizia cez skupinu (ABS vyrobcu nenesie);
    # universal priznak "univ." len v SCHEMA 2.
    NxTest.assert_equal('Egger K111 ST9 23/1 mm', B4PANEL.abs_label(B4MAT.edge('ABS_EG_K111'), ctx))
    NxTest.assert_equal('Kronospan K111 1.0 mm', B4PANEL.abs_label(B4MAT.edge('ABS_BEZ_2'), ctx))
    NxTest.assert_equal('U750 43/1 mm · univ.', B4PANEL.abs_label(B4MAT.edge('ABS_UNI_X'), ctx))
  end
end

NxTest.test('2a4b labely: SCHEMA 1 labely su PRESNE dnesne (ctx nil, dual-mode)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    NxTest.assert_equal(nil, B4PANEL.label_ctx, 'legacy katalog nema label kontext')
    NxTest.assert_equal('K009 PW · DTDL 18 mm', B4PANEL.sheet_label(B4MAT.sheet('K009_PW_DTDL_18')))
    NxTest.assert_equal('K009 PW 1.0 mm', B4PANEL.abs_label(B4MAT.edge('ABS_K009_10')))
  end
end

# ---------------------------------------------------------------------------
# Banner count (audit O2): server-side pocet nepouzitelnych pasok
# ---------------------------------------------------------------------------

NxTest.test('2a4b banner: unusable_edges_count — SCHEMA 1 vzdy 0; SCHEMA 2 bez struktury a bez universal') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    NxTest.assert_equal(0, B4MAT.unusable_edges_count, 'legacy picker strukturu nepozna — banner 0')
  end
  b4_with_catalog(b4_schema2_bytes) do
    NxTest.assert_equal(2, B4MAT.unusable_edges_count,
                        'bez struktury a bez universal = 2 (ABS_BEZ_1, ABS_BEZ_2); universal sa nerata')
  end
end

# ---------------------------------------------------------------------------
# GH #93 kolo 1
# ---------------------------------------------------------------------------

NxTest.test('2a4b: GH P1 — VEPO exportny label je stabilny cez migraciu a NEZLIEVA struktury') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  legacy = JSON.pretty_generate(
    'std' => 1,
    'sheets' => [{ 'material_id' => 'K1', 'decor' => 'K009 PW', 'type' => 'DTDL',
                   'thickness' => 18.0, 'grain' => 'length', 'color' => [1, 1, 1],
                   'production_class' => 'sheet' }],
    'edges' => []
  ).b
  migrated = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'K1', 'group_id' => 'GRP-A', 'manufacturer' => 'Kronospan',
        'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'K2', 'group_id' => 'GRP-A', 'manufacturer' => 'Kronospan',
        'decor' => 'K009', 'structure' => 'BS', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  require_relative '../../noxun_engine/ui/production_dialog' unless defined?(Noxun::Engine::ProductionDialog)
  pd = Noxun::Engine::ProductionDialog
  b4_with_catalog(legacy) do
    NxTest.assert_equal('K009 PW DTDL', pd.send(:vepo_materials)['K1']['label'],
                        'legacy label = presne dnesny tvar')
  end
  b4_with_catalog(migrated) do
    mats = pd.send(:vepo_materials)
    NxTest.assert_equal('K009 PW DTDL', mats['K1']['label'],
                        'zmigrovany zaznam reprodukuje POVODNY exportny text (cutover nemeni CSV/subory)')
    NxTest.assert_equal('K009 BS DTDL', mats['K2']['label'],
                        'ina struktura = INY bucket (nezlievaju sa)')
  end
  # GH #93 P1 (2. kolo): decor_name je SUCAST povodneho textu — bez neho by sa
  # export W1000 zmenil; kolizia labelu dvoch skupin dostava prefix vyrobcu.
  named = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'W1', 'group_id' => 'GRP-W', 'manufacturer' => 'Egger',
        'decor' => 'W1000', 'structure' => 'ST9', 'decor_name' => 'Biela', 'type' => 'DTDL',
        'thickness' => 18.0, 'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'C1', 'group_id' => 'GRP-EG', 'manufacturer' => 'Egger',
        'decor' => 'K111', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'C2', 'group_id' => 'GRP-KR', 'manufacturer' => 'Kronospan',
        'decor' => 'K111', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  b4_with_catalog(named) do
    mats = pd.send(:vepo_materials)
    NxTest.assert_equal('W1000 ST9 Biela DTDL', mats['W1']['label'],
                        'decor_name je sucast exportneho labelu (legacy text drzi)')
    NxTest.assert_equal('Egger K111 ST9 DTDL', mats['C1']['label'], 'kolizia = prefix vyrobcu')
    NxTest.assert_equal('Kronospan K111 ST9 DTDL', mats['C2']['label'])
  end
  # GH #93 P2 (3. kolo): dve skupiny TOHO ISTEHO vyrobcu zlozia rovnaky text
  # ("K009 PW"+"" vs "K009"+"PW") — druhe kolo pridava skupinovy sufix.
  patological = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'P1', 'group_id' => 'GRP-AAA', 'manufacturer' => 'Egger',
        'decor' => 'K009 PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'P2', 'group_id' => 'GRP-BBB', 'manufacturer' => 'Egger',
        'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  b4_with_catalog(patological) do
    mats = pd.send(:vepo_materials)
    NxTest.refute(mats['P1']['label'] == mats['P2']['label'],
                  "ani rovnaky vyrobca nesmie zliat buckety (#{mats['P1']['label']})")
    NxTest.assert(mats['P1']['label'].include?('GRP-AAA'))
    NxTest.assert(mats['P2']['label'].include?('GRP-BBB'))
  end
end

NxTest.test('2a4b: GH P2 — set_decor_name meni nazov atomicky celej skupine (identita nedotknuta)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  data = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [{ 'material_id' => 'S1', 'group_id' => 'GRP-N', 'manufacturer' => 'Egger',
                   'decor' => 'H1180', 'decor_name' => 'Preklep', 'structure' => 'ST37',
                   'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'length',
                   'color' => [1, 1, 1], 'production_class' => 'sheet' }],
    'edges' => [{ 'abs_id' => 'E1', 'group_id' => 'GRP-N', 'decor' => 'H1180',
                  'decor_name' => 'Preklep', 'structure' => 'ST37', 'thickness' => 1.0,
                  'width' => 23.0, 'color' => [1, 1, 1] }]
  ).b
  b4_with_catalog(data) do
    ok, n = B4MAT.set_decor_name('GRP-N', 'Dub Halifax prírodný')
    NxTest.assert(ok, n.inspect)
    NxTest.assert_equal(2, n, 'doska aj paska atomicky')
    NxTest.assert_equal('Dub Halifax prírodný', B4MAT.sheet('S1')['decor_name'])
    NxTest.assert_equal('Dub Halifax prírodný', B4MAT.edge('E1')['decor_name'])
    NxTest.assert_equal('H1180', B4MAT.sheet('S1')['decor'], 'identita (cislo) nedotknuta')
    ok2, = B4MAT.set_decor_name('GRP-N', '')
    NxTest.assert(ok2)
    NxTest.refute(B4MAT.sheet('S1').key?('decor_name'), 'prazdny nazov kluc odstrani')
    okx, err = B4MAT.set_decor_name('GRP-CHYBA', 'X')
    NxTest.refute(okx)
    NxTest.assert(err.include?('nenašla'), err.to_s)
  end
end

NxTest.test('2a4b: GH P1 kolo 4 — PD varianty s inym formatom maju ODDELENE VEPO buckety') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  require_relative '../../noxun_engine/ui/production_dialog' unless defined?(Noxun::Engine::ProductionDialog)
  data = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'PD1', 'group_id' => 'GRP-F', 'manufacturer' => 'Egger',
        'decor' => 'F800', 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0],
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'PD2', 'group_id' => 'GRP-F', 'manufacturer' => 'Egger',
        'decor' => 'F800', 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 920.0],
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  b4_with_catalog(data) do
    mats = Noxun::Engine::ProductionDialog.send(:vepo_materials)
    NxTest.refute(mats['PD1']['label'] == mats['PD2']['label'],
                  "PD formaty sa nesmu zliat (#{mats['PD1']['label']})")
    NxTest.assert(mats['PD1']['label'].include?('4100') && mats['PD1']['label'].include?('600'))
    NxTest.assert(mats['PD2']['label'].include?('920'))
  end
end

NxTest.test('2a4b: GH P2 kolo 4 — prazdny legacy katalog sa pri boote povysi na SCHEMA 2') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  empty_legacy = JSON.pretty_generate('std' => 1, 'sheets' => [], 'edges' => []).b
  b4_with_catalog(empty_legacy) do
    NxTest.assert_equal(:empty_promoted, B4MAT.boot_cutover!)
    NxTest.assert_equal(2, B4MAT.catalog_schema, 'marker 2 zapisany')
    NxTest.assert_equal(:schema2, B4MAT.boot_cutover!, 'dalsi boot uz nic nerobi')
  end
end

NxTest.test('2a4b: GH P2 kolo 4 — poskodena predmigracna zaloha = viditelny cutover_issue (nie len log)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    File.binwrite(B4MAT.pre_schema2_backup_path, 'xx{poskodene')
    NxTest.assert_equal(:backup_corrupt, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.cutover_issue.to_s.include?('poškodená'),
                  "cutover_issue nesie dovod: #{B4MAT.cutover_issue.inspect}")
    state, = B4MAT.assess_catalog!
    NxTest.assert_equal(:ok, state, 'katalog bezi dalej (nie read-only)')
    # uspesny boot dovod cisti
    FileUtils.rm_f(B4MAT.pre_schema2_backup_path)
    NxTest.assert_equal(:migrated, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.cutover_issue.nil?, 'uspesny cutover dovod vycisti')
  end
end

NxTest.test('2a4b: GH kolo 5 — PD sufix drzi desatiny (%g) a empty promote je CAS-chraneny') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  require_relative '../../noxun_engine/ui/production_dialog' unless defined?(Noxun::Engine::ProductionDialog)
  data = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'PDA', 'group_id' => 'GRP-F', 'manufacturer' => 'Egger',
        'decor' => 'F800', 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.1, 600.0],
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'PDB', 'group_id' => 'GRP-F', 'manufacturer' => 'Egger',
        'decor' => 'F800', 'type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.2, 600.0],
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  b4_with_catalog(data) do
    mats = Noxun::Engine::ProductionDialog.send(:vepo_materials)
    NxTest.refute(mats['PDA']['label'] == mats['PDB']['label'],
                  "sub-mm formaty sa nesmu zliat (#{mats['PDA']['label']})")
    NxTest.assert(mats['PDA']['label'].include?('4100.1'), mats['PDA']['label'])
  end
  # empty promote CAS: cudzi zapis medzi :empty reportom a zamkom prezije
  empty_legacy = JSON.pretty_generate('std' => 1, 'sheets' => [], 'edges' => []).b
  b4_with_catalog(empty_legacy) do
    # simulacia: pred bootom niekto zapisal prvy zaznam (cache o nom nevie)
    filled = JSON.pretty_generate(
      'std' => 1,
      'sheets' => [{ 'material_id' => 'C1', 'decor' => 'Cudzi Dekor', 'type' => 'DTDL',
                     'thickness' => 18.0, 'grain' => 'length', 'color' => [1, 1, 1],
                     'production_class' => 'sheet' }],
      'edges' => []
    ).b
    B4MAT.catalog # warm cache nad prazdnym
    File.binwrite(B4MAT.path, filled)
    status = B4MAT.boot_cutover!
    NxTest.assert_equal(:migrated, status, 'zmena pod bootom = retry migracia, nie prazdny prepis')
    NxTest.refute(B4MAT.sheet('C1').nil?, 'cudzi zaznam PREZIL (zmigrovany, nie zahodeny)')
  end
end

NxTest.test('2a4b: GH P2 kolo 6 — necakany pad cutoveru = viditelny issue + reassess (:error, nie len log)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  b4_with_catalog(b4_legacy_seed_bytes) do
    orig = B4MAT.method(:migrate_to_schema2!)
    begin
      B4MAT.define_singleton_method(:migrate_to_schema2!) { |**_k| raise IOError, 'subor zmizol (test)' }
      NxTest.assert_equal(:error, B4MAT.boot_cutover!)
    ensure
      B4MAT.define_singleton_method(:migrate_to_schema2!, orig)
    end
    NxTest.assert(B4MAT.cutover_issue.to_s.include?('neočakávane'),
                  "issue nesie dovod: #{B4MAT.cutover_issue.inspect}")
    NxTest.assert_equal(:ok, B4MAT.catalog_state, 'katalog (nedotknuty legacy) bezi dalej')
    # dalsi boot bez stubu funguje normalne a issue vycisti
    NxTest.assert_equal(:migrated, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.cutover_issue.nil?)
  end
end

NxTest.test('2a4b: GH kolo 8 — panel labely deteguju koliziu zo ZLOZENEHO textu (+group sufix pri tvrdej)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  data = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'A1', 'group_id' => 'GRP-AAA', 'manufacturer' => 'Egger',
        'decor' => 'K009 PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'A2', 'group_id' => 'GRP-BBB', 'manufacturer' => 'Egger',
        'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  b4_with_catalog(data) do
    ctx = B4PANEL.send(:label_ctx)
    l1 = B4PANEL.send(:sheet_label, B4MAT.sheet('A1'), ctx)
    l2 = B4PANEL.send(:sheet_label, B4MAT.sheet('A2'), ctx)
    NxTest.refute(l1 == l2, "zlozeny text z roznych skupin sa musi rozlisit (#{l1})")
    NxTest.assert(l1.include?('GRP-AAA') || l2.include?('GRP-BBB'),
                  'tvrda kolizia (rovnaky vyrobca) nesie group sufix')
  end
end

NxTest.test('2a4b: GH kolo 8 — migracia odmieta znackovu skupinu len s paskami (vyrobca by sa stratil)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  data = JSON.parse(JSON.generate(NxTest::LEGACY_SEED_CATALOG))
  data['sheets'] = data['sheets'].reject { |s| s['decor'] == 'K009 PW' } # K009 ostane edge-only
  bytes = JSON.pretty_generate(data).b
  b4_with_catalog(bytes) do
    NxTest.assert_equal(:undecidable, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.cutover_issue.to_s.include?('len ABS pásky') || B4MAT.cutover_issue.to_s.include?('len ABS pasky'),
                  "dovod menuje edge-only znackovu skupinu: #{B4MAT.cutover_issue.inspect}")
    NxTest.assert_equal(bytes, File.binread(B4MAT.path).b, 'atomicky NO-OP')
  end
end

NxTest.test('2a4b: GH kolo 9 — display nesie ludsky zaklad, ked label ma disambiguator') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  require_relative '../../noxun_engine/ui/production_dialog' unless defined?(Noxun::Engine::ProductionDialog)
  data = JSON.pretty_generate(
    'std' => 1, 'schema' => 2,
    'sheets' => [
      { 'material_id' => 'C1', 'group_id' => 'GRP-EG', 'manufacturer' => 'Egger',
        'decor' => 'K111', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'C2', 'group_id' => 'GRP-KR', 'manufacturer' => 'Kronospan',
        'decor' => 'K111', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' },
      { 'material_id' => 'U1', 'group_id' => 'GRP-U', 'manufacturer' => 'Egger',
        'decor' => 'U750', 'structure' => 'ST9', 'type' => 'DTDL', 'thickness' => 18.0,
        'grain' => 'length', 'color' => [1, 1, 1], 'production_class' => 'sheet' }
    ],
    'edges' => []
  ).b
  b4_with_catalog(data) do
    mats = Noxun::Engine::ProductionDialog.send(:vepo_materials)
    NxTest.assert_equal('K111 ST9 DTDL', mats['C1']['display'],
                        'disambiguovany label nesie ludsky display')
    NxTest.assert(mats['C1']['label'].include?('Egger'))
    NxTest.refute(mats['U1'].key?('display'), 'bez disambiguatora display netreba (label = ludsky)')
  end
end

NxTest.test('2a4b: GH kolo 10 — retry neuspech je viditelny + batch v3 marker re-check pod zamkom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  # a) retry po zmene pod bootom vrati :undecidable -> cutover_issue nastaveny
  empty_legacy = JSON.pretty_generate('std' => 1, 'sheets' => [], 'edges' => []).b
  b4_with_catalog(empty_legacy) do
    bad = JSON.parse(JSON.generate(NxTest::LEGACY_SEED_CATALOG))
    bad['sheets'][0]['structure'] = 'PW' # hybrid v legacy = undecidable
    B4MAT.catalog # warm cache nad prazdnym
    File.binwrite(B4MAT.path, JSON.pretty_generate(bad).b)
    NxTest.assert_equal(:undecidable, B4MAT.boot_cutover!)
    NxTest.assert(B4MAT.cutover_issue.to_s.include?('nerozhodnuteľné'),
                  "retry neuspech je viditelny: #{B4MAT.cutover_issue.inspect}")
  end
  # b) batch v3 odmietne zapis, ked sa katalog POD zamkom vratil na legacy
  b4_with_catalog(JSON.pretty_generate(b4_schema2_data).b) do
    B4MAT.catalog # warm cache (schema 2 pohlad)
    File.binwrite(B4MAT.path, b4_legacy_seed_bytes) # "rollback z ineho procesu"
    ok, err = B4MAT.add_decor_batch(
      'batch_schema' => 3, 'decor' => 'K999', 'manufacturer' => 'Egger',
      'type' => 'DTDL', 'grain' => 'length', 'color' => [1, 2, 3],
      'sheet_variants' => [{ 'thickness' => 18.0, 'structure' => 'ST9' }],
      'edge_variants' => []
    )
    NxTest.refute(ok, 'v3 zapis do legacy suboru sa odmietne (ziadny hybrid)')
    NxTest.assert(err.include?('vrátil na pôvodný formát'), err.to_s)
    NxTest.assert_equal(b4_legacy_seed_bytes, File.binread(B4MAT.path).b, 'subor nedotknuty')
  end
end
