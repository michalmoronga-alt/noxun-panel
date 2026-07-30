# frozen_string_literal: true
# Testy 2A-2: dormantny migracny engine katalogu na SCHEMA 2.
#
# KONTRAKT DAVKY: migraciu nevola ziadna produkcna cesta — testy ju spustaju
# VYHRADNE nad izolovanou kopiou katalogu (APPDATA sandbox helpera + vlastny
# save/restore suboru). Fixture je verna replika ziveho katalogu (10 sheets +
# 13 edges, presne decor stringy vratane trailing spaces) — kluce kanonickej
# mapy sa overuju testom na fixture, nie odhadom (O5).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

A2MAT = Noxun::Engine::Materials
A2STORE = Noxun::Engine::JsonFileStore
A2VAL = Noxun::Engine::Validation
A2FIXTURE = File.join(NxTest::ROOT, 'tests', 'fixtures', 'materials_legacy_v1.json')

def a2_fixture_bytes
  File.binread(A2FIXTURE)
end

def a2_fixture_data
  JSON.parse(a2_fixture_bytes)
end

# Nainstaluje dane bajty ako katalogovy subor sandboxu, zmaze pripadnu
# predmigracnu zalohu a po bloku vrati PRESNY povodny stav (subor aj zalohu) —
# ziadny test nesmie ovplyvnit tie dalsie.
def a2_with_catalog(bytes)
  path = A2MAT.path
  FileUtils.mkdir_p(A2MAT.dir)
  before = File.exist?(path) ? File.binread(path) : nil
  backup = A2MAT.pre_schema2_backup_path
  backup_before = File.exist?(backup) ? File.binread(backup) : nil
  File.binwrite(path, bytes)
  A2STORE.invalidate(path)
  FileUtils.rm_f(backup)
  yield
ensure
  if before then File.binwrite(path, before) else FileUtils.rm_f(path) end
  if backup_before then File.binwrite(backup, backup_before) else FileUtils.rm_f(backup) end
  A2STORE.invalidate(path)
end

# Varianta fixture: parse -> uprava blokom -> pretty JSON bajty. Vracia BINARY
# string (.b), aby porovnania s File.binread nikdy nepadli na encodingu
# (json gem force-encoduje vstup parse in-place — pasca z vyvoja tejto sady).
def a2_variant(data = a2_fixture_data)
  yield data
  JSON.pretty_generate(data).b
end

def a2_sheet_of(data, id)
  data['sheets'].find { |s| s['material_id'] == id }
end

def a2_edge_of(data, id)
  data['edges'].find { |a| a['abs_id'] == id }
end

# Docasny SCHEMA 2 marker nad seedovanym sandbox katalogom (vzor a1_with_schema2;
# vlastna kopia — subor testov musi bezat aj samostatne).
def a2_with_schema2_marker
  path = A2MAT.path
  A2MAT.catalog # seed, aby subor existoval
  before = File.binread(path)
  A2STORE.write(path, JSON.parse(before).merge('schema' => 2))
  yield
ensure
  if before
    File.binwrite(path, before)
    A2STORE.invalidate(path)
  end
end

# ---------------------------------------------------------------------------
# kanonicka mapa — kluce presne z identity_norm zivych dat (O5)
# ---------------------------------------------------------------------------

NxTest.test('2A-2: kluce mapy = identity_norm dekorov fixture (ziadny odhad diakritiky)') do
  data = a2_fixture_data
  NxTest.assert_equal(10, data['sheets'].length, 'fixture replika: 10 dosiek')
  NxTest.assert_equal(13, data['edges'].length, 'fixture replika: 13 pasok')
  decors = (data['sheets'] + data['edges']).map { |r| r['decor'] }.uniq
  unmapped = decors.reject { |d| A2MAT::MIGRATION_MAP.key?(A2MAT.identity_norm(d)) }
  NxTest.assert_equal(['Pracovna doska'], unmapped,
                      'mimo mapy smie ostat LEN dekor mazanej pasky (ziadny fallback na zivych datach)')
  # zamky presnych klucov s diakritikou (Ruby upcase je Unicode-aware)
  NxTest.assert_equal('U750 ST9 TAUPE ŠEDÁ', A2MAT.identity_norm('U750 ST9 Taupe šedá'))
  NxTest.assert_equal('H1180 ST37 DUB HALIFAX PRÍRODNÝ', A2MAT.identity_norm('H1180 ST37 Dub Halifax prírodný'))
  NxTest.assert_equal('HALIFAX TABAKOVÝ PD', A2MAT.identity_norm('Halifax Tabakový PD '),
                      'trailing space z zivych dat mizne normalizaciou')
  NxTest.assert_equal('HALIFAX TABAKOVÝ', A2MAT.identity_norm('Halifax Tabakový '))
  # obidva HALIFAX kluce cielia na TU ISTU skupinu (merge)
  NxTest.assert_equal(A2MAT::MIGRATION_MAP['HALIFAX TABAKOVÝ PD']['decor'],
                      A2MAT::MIGRATION_MAP['HALIFAX TABAKOVÝ']['decor'])
  NxTest.assert_equal(['ABS_PRACOVNA_DOSKA_10'], A2MAT::MIGRATION_DELETE_EDGE_IDS)
  NxTest.assert_equal({ 'HALIFAX_TABAKOVY_PD_DTDL_38' => 'PD' }, A2MAT::MIGRATION_RETYPE)
end

NxTest.test('2A-2: group_id_for — deterministicky opaque GRP- hash, case/medzery nerozhoduju') do
  gid = A2MAT.group_id_for('Kronospan', 'K009')
  NxTest.assert(gid.match?(/\AGRP-[0-9A-F]{16}\z/), "tvar group_id: #{gid}")
  NxTest.assert_equal(gid, A2MAT.group_id_for(' kronospan ', 'k009'), 'identita cez identity_norm')
  NxTest.refute(gid == A2MAT.group_id_for('Egger', 'K009'), 'rovnake cislo dvoch vyrobcov = dve skupiny')
  NxTest.refute(gid == A2MAT.group_id_for('', 'K009'), 'vlastna skupina bez vyrobcu je ina identita')
  NxTest.assert_equal(A2MAT.group_id_for('', 'Halifax Tabakový'),
                      A2MAT.group_id_for(nil, ' halifax tabakový '), 'stabilny aj pre vlastne skupiny')
end

# ---------------------------------------------------------------------------
# stastna cesta (ostry beh) + idempotencia
# ---------------------------------------------------------------------------

NxTest.test('2A-2: stastna cesta — transformacia 1:1 podla schvalenej mapy') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  original = a2_fixture_bytes
  a2_with_catalog(original) do
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:ok, rep[:status], rep[:reasons].inspect)
    NxTest.assert_equal(['ABS_PRACOVNA_DOSKA_10'], rep[:deleted])
    NxTest.assert_equal(['HALIFAX_TABAKOVY_PD_DTDL_38'], rep[:retyped])
    NxTest.assert_equal([], rep[:fallback], 'zive data nemaju fallback')
    NxTest.assert_equal([], rep[:warnings], 'mimo SketchUpu sa vyuzitie modelu nescanuje')
    NxTest.assert_equal(9, rep[:groups].length, 'mapa da 9 skupin (Halifax merge)')

    out = JSON.parse(File.binread(A2MAT.path))
    NxTest.assert_equal(2, out['schema'], 'subor nesie SCHEMA marker 2')
    NxTest.assert_equal(1, out['std'], 'std ostava')
    orig = a2_fixture_data # NIE JSON.parse(original) — parse by original force-encodol

    # VSETKY ID zachovane okrem zmazanej pasky
    NxTest.assert_equal(orig['sheets'].map { |s| s['material_id'] },
                        out['sheets'].map { |s| s['material_id'] }, 'ID a poradie dosiek 1:1')
    NxTest.assert_equal(orig['edges'].map { |a| a['abs_id'] } - ['ABS_PRACOVNA_DOSKA_10'],
                        out['edges'].map { |a| a['abs_id'] }, 'z pasok zmizlo LEN schvalene ID')

    # kazdy zaznam ma group_id v GRP tvare
    (out['sheets'] + out['edges']).each do |r|
      NxTest.assert(r['group_id'].to_s.match?(/\AGRP-[0-9A-F]{16}\z/),
                    "zaznam #{r['material_id'] || r['abs_id']} bez group_id")
    end

    # K009: pasky zdielaju group_id s doskami; struktura PW; dekor K009
    k18 = a2_sheet_of(out, 'K009_PW_DTDL_18')
    k16 = a2_sheet_of(out, 'K009_PW_DTDL_16')
    ke1 = a2_edge_of(out, 'ABS_K009_10')
    ke2 = a2_edge_of(out, 'ABS_K009_20')
    NxTest.assert_equal('K009', k18['decor'])
    NxTest.assert_equal('PW', k18['structure'])
    NxTest.assert_equal('Kronospan', k18['manufacturer'])
    NxTest.refute(k18.key?('decor_name'), 'K009 nema zobrazovaci nazov — kluc sa NEZAPISUJE')
    NxTest.assert_equal(k18['group_id'], k16['group_id'])
    NxTest.assert_equal(k18['group_id'], ke1['group_id'], 'paska zdiela group_id s doskou')
    NxTest.assert_equal(k18['group_id'], ke2['group_id'])
    NxTest.assert_equal('PW', ke1['structure'], 'struktura skupiny aj na paske')

    # Halifax merge: PD doska aj paska = JEDNA skupina; typ PD; format v identite
    pd = a2_sheet_of(out, 'HALIFAX_TABAKOVY_PD_DTDL_38')
    he = a2_edge_of(out, 'ABS_HALIFAX_TABAKOVY_10')
    NxTest.assert_equal('PD', pd['type'], 'retype DTDL->PD')
    NxTest.assert_equal('Halifax Tabakový', pd['decor'], 'trailing space prec')
    NxTest.assert_equal('Halifax Tabakový', he['decor'])
    NxTest.assert_equal(pd['group_id'], he['group_id'], 'merge = spolocny group_id')
    NxTest.assert_equal([4200.0, 600.0], pd['sheet_size'], 'format PD ostava (sucast identity)')
    key = A2MAT.sheet_identity_key(pd, 2)
    NxTest.assert_equal([4200.0, 600.0], key.last, 'PD identita v SCHEMA 2 nesie format')
    NxTest.refute(pd.key?('manufacturer'), 'vlastna skupina: prazdny vyrobca kluc NEZAPISUJE')

    # skupiny podla mapy (vyrobca/cislo/nazov/struktura)
    u750 = a2_sheet_of(out, 'U750_ST9_TAUPE_SEDA_DTDL_18')
    NxTest.assert_equal(%w[Egger U750], [u750['manufacturer'], u750['decor']])
    NxTest.assert_equal('Taupe šedá', u750['decor_name'])
    NxTest.assert_equal('ST9', u750['structure'])
    h1180 = a2_sheet_of(out, 'H1180_ST37_DUB_HALIFAX_PRIRODNY_DTDL_18P6')
    NxTest.assert_equal(%w[Egger H1180], [h1180['manufacturer'], h1180['decor']])
    NxTest.assert_equal('Dub Halifax prírodný', h1180['decor_name'])
    NxTest.assert_equal('ST37', h1180['structure'])
    c5981 = a2_sheet_of(out, '5981_MG_CASHMERE_DTDL_18')
    NxTest.assert_equal(%w[Kronospan 5981], [c5981['manufacturer'], c5981['decor']])
    NxTest.assert_equal('Cashmere', c5981['decor_name'])
    NxTest.assert_equal('MG', c5981['structure'])
    w1000 = a2_sheet_of(out, 'W1000_DTDL_18')
    NxTest.assert_equal(%w[W1000 Biela ST9], [w1000['decor'], w1000['decor_name'], w1000['structure']])
    hdf = a2_sheet_of(out, 'HDF_WHITE_3')
    NxTest.assert_equal(%w[Kronospan], [hdf['manufacturer']])
    NxTest.assert_equal('Biela HDF', hdf['decor'])
    NxTest.refute(hdf.key?('structure'), 'skupina bez struktury kluc nedostane')

    # vyrobca NIKDY na paskach; prazdne skupinove kluce sa NEZAPISUJU
    out['edges'].each do |a|
      NxTest.refute(a.key?('manufacturer'), "paska #{a['abs_id']} nesmie niest vyrobcu")
    end
    %w[BIELA_KORPUS_DTDL_18 UNI_DTDL_18].each do |id|
      s = a2_sheet_of(out, id)
      NxTest.refute(s.key?('manufacturer'), "#{id}: vlastna skupina bez vyrobcu")
      NxTest.refute(s.key?('decor_name') || s.key?('structure'), "#{id}: prazdne kluce sa nezapisuju")
    end

    # ostatne polia zaznam po zazname 1:1 (okrem menenych klucov)
    managed_sheet = %w[group_id decor decor_name structure manufacturer type]
    orig['sheets'].each do |os|
      ns = a2_sheet_of(out, os['material_id'])
      (os.keys - managed_sheet).each do |kk|
        NxTest.assert_equal(os[kk], ns[kk], "#{os['material_id']}: pole #{kk} sa nesmie zmenit")
      end
      NxTest.assert_equal([], ns.keys - os.keys - managed_sheet,
                          "#{os['material_id']}: ziadne necakane nove kluce")
      unless A2MAT::MIGRATION_RETYPE.key?(os['material_id'])
        NxTest.assert_equal(os['type'], ns['type'], "#{os['material_id']}: typ bez retype nemenny")
      end
    end
    managed_edge = %w[group_id decor decor_name structure]
    (orig['edges'] - [a2_edge_of(orig, 'ABS_PRACOVNA_DOSKA_10')]).each do |oa|
      na = a2_edge_of(out, oa['abs_id'])
      (oa.keys - managed_edge).each do |kk|
        NxTest.assert_equal(oa[kk], na[kk], "#{oa['abs_id']}: pole #{kk} sa nesmie zmenit")
      end
      NxTest.assert_equal([], na.keys - oa.keys - managed_edge,
                          "#{oa['abs_id']}: ziadne necakane nove kluce")
    end

    # report skupin: pocty sedia (K009 2+2, Halifax 1+1, 5981 1+3)
    by_decor = rep[:groups].each_with_object({}) { |g, h| h[g[:decor]] = g }
    NxTest.assert_equal([2, 2], [by_decor['K009'][:sheets], by_decor['K009'][:edges]])
    NxTest.assert_equal([1, 1], [by_decor['Halifax Tabakový'][:sheets], by_decor['Halifax Tabakový'][:edges]])
    NxTest.assert_equal([1, 3], [by_decor['5981'][:sheets], by_decor['5981'][:edges]])
    NxTest.assert_equal(k18['group_id'], by_decor['K009'][:group_id], 'report a data zdielaju group_id')

    # nemenna predmigracna zaloha = bajtova kopia povodiny
    NxTest.assert_equal(original, File.binread(A2MAT.pre_schema2_backup_path))
    NxTest.assert_equal(2, A2MAT.catalog_schema, 'catalog_schema cita novy marker')

    # idempotencia: druhy beh = :already, obsah bez zmeny
    after = File.binread(A2MAT.path)
    rep2 = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:already, rep2[:status])
    NxTest.assert_equal(after, File.binread(A2MAT.path), 'druhy beh subor nemeni')
    NxTest.assert_equal(original, File.binread(A2MAT.pre_schema2_backup_path), 'zaloha ostava povodna')
  end
end

NxTest.test('2A-2: dry_run — plny report, subor aj zaloha nedotknute') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  original = a2_fixture_bytes
  a2_with_catalog(original) do
    rep = A2MAT.migrate_to_schema2!(dry_run: true)
    NxTest.assert_equal(:ok, rep[:status], rep[:reasons].inspect)
    NxTest.assert_equal(true, rep[:dry_run])
    NxTest.assert_equal(9, rep[:groups].length, 'report plny aj v dry_run')
    NxTest.assert_equal(['ABS_PRACOVNA_DOSKA_10'], rep[:deleted])
    NxTest.assert_equal(['HALIFAX_TABAKOVY_PD_DTDL_38'], rep[:retyped])
    NxTest.assert_equal(original, File.binread(A2MAT.path), 'subor bajtovo nezmeneny')
    NxTest.refute(File.exist?(A2MAT.pre_schema2_backup_path), 'dry_run zalohu NEVYTVARA (FIX 4)')
    NxTest.assert_equal(1, A2MAT.catalog_schema, 'katalog ostal legacy')
    # dry-run a ostry beh zdielaju group_id (deterministicky hash, O6)
    gid_dry = rep[:groups].find { |g| g[:decor] == 'K009' }[:group_id]
    NxTest.assert_equal(gid_dry, A2MAT.group_id_for('Kronospan', 'K009'))
  end
end

# ---------------------------------------------------------------------------
# NO-OP scenare (atomicita — jedina polozka = nic sa nezapise)
# ---------------------------------------------------------------------------

def a2_expect_noop(bytes, status, reason_part = nil)
  a2_with_catalog(bytes) do
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(status, rep[:status], "cakany #{status}: #{rep.inspect}")
    if reason_part
      NxTest.assert(rep[:reasons].any? { |r| r.include?(reason_part) },
                    "dovod '#{reason_part}' chyba: #{rep[:reasons].inspect}")
    end
    NxTest.assert_equal(bytes, File.binread(A2MAT.path), 'subor musi ostat bajtovo nezmeneny')
    NxTest.refute(File.exist?(A2MAT.pre_schema2_backup_path), 'no-op zalohu nevytvara (FIX 4)')
  end
end

NxTest.test('2A-2 no-op: kolizia identity variantu po transformacii') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bytes = a2_variant do |d|
    dup = JSON.parse(JSON.generate(a2_sheet_of(d, 'K009_PW_DTDL_18')))
    dup['material_id'] = 'K009_PW_DTDL_18B'
    d['sheets'] << dup # rovnaka skupina+typ+hrubka+struktura => dup identita v SCHEMA 2
  end
  a2_expect_noop(bytes, :undecidable, 'duplicitna identita variantu dosky')
end

NxTest.test('2A-2 no-op: PD variant bez formatu platne') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bytes = a2_variant do |d|
    d['sheets'] << { 'material_id' => 'FALL_PD_38', 'decor' => 'Fallback PD',
                     'type' => 'PD', 'thickness' => 38.0 }
  end
  a2_expect_noop(bytes, :undecidable, 'PD variant bez formatu')
end

NxTest.test('2A-2 no-op: hybridny legacy zaznam so SCHEMA 2 polom') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bytes = a2_variant { |d| a2_sheet_of(d, 'UNI_DTDL_18')['group_id'] = 'GRP-RUCNY' }
  a2_expect_noop(bytes, :undecidable, 'SCHEMA 2 polia')
end

NxTest.test('2A-2 no-op: mazane ID s inym obsahom (FIX 5 — ziadny slepy zasah)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bytes = a2_variant { |d| a2_edge_of(d, 'ABS_PRACOVNA_DOSKA_10')['thickness'] = 2.0 }
  a2_expect_noop(bytes, :undecidable, 'ocakavanim mazania')
end

NxTest.test('2A-2 no-op: retype ID s inym typom/formatom (FIX 5)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bytes = a2_variant { |d| a2_sheet_of(d, 'HALIFAX_TABAKOVY_PD_DTDL_38')['sheet_size'] = [4100.0, 600.0] }
  a2_expect_noop(bytes, :undecidable, 'ocakavanim retype')
  bytes2 = a2_variant { |d| a2_sheet_of(d, 'HALIFAX_TABAKOVY_PD_DTDL_38')['type'] = 'MDF' }
  a2_expect_noop(bytes2, :undecidable, 'ocakavanim retype')
end

# ---------------------------------------------------------------------------
# heuristicky fallback (zaznam mimo mapy)
# ---------------------------------------------------------------------------

NxTest.test('2A-2: fallback — vlastna skupina s reportom; rovnaky dekor = JEDNA skupina (FIX 8)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  bytes = a2_variant do |d|
    d['sheets'] << { 'material_id' => 'FALL_A_DTDL_18', 'decor' => 'Fallback Dekor',
                     'manufacturer' => 'Firma', 'type' => 'DTDL', 'thickness' => 18.0 }
    d['edges'] << { 'abs_id' => 'ABS_FALL_A_10', 'decor' => 'Fallback Dekor', 'thickness' => 1.0 }
  end
  a2_with_catalog(bytes) do
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:ok, rep[:status], rep[:reasons].inspect)
    NxTest.assert_equal(%w[ABS_FALL_A_10 FALL_A_DTDL_18], rep[:fallback].map { |f| f[:id] }.sort,
                        'kazdy fallback zaznam je v reporte')
    gids = rep[:fallback].map { |f| f[:group_id] }.uniq
    NxTest.assert_equal(1, gids.length, 'rovnaky identity_norm dekor = JEDNA fallback skupina')
    out = JSON.parse(File.binread(A2MAT.path))
    fs = a2_sheet_of(out, 'FALL_A_DTDL_18')
    fe = a2_edge_of(out, 'ABS_FALL_A_10')
    NxTest.assert_equal(fs['group_id'], fe['group_id'])
    NxTest.assert_equal('Fallback Dekor', fs['decor'], 'fallback dekor = cely trimnuty povodny text')
    NxTest.assert_equal('Firma', fs['manufacturer'], 'vyrobca z pola zaznamu (len doska)')
    NxTest.refute(fe.key?('manufacturer'), 'fallback paska vyrobcu nedostane')
    grp = rep[:groups].find { |g| g[:decor] == 'Fallback Dekor' }
    NxTest.assert_equal([1, 1], [grp[:sheets], grp[:edges]])
    NxTest.assert_equal(10, rep[:groups].length, '9 mapovanych + 1 fallback skupina')
  end
end

# ---------------------------------------------------------------------------
# schema brany (FIX 9) + prazdny/chybajuci katalog (O4)
# ---------------------------------------------------------------------------

NxTest.test('2A-2 brany: marker 2 bez group_id / marker 2 kompletny / marker 3') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  invalid2 = a2_variant { |d| d['schema'] = 2 }
  a2_expect_noop(invalid2, :invalid_schema2)
  already = a2_variant do |d|
    d['schema'] = 2
    (d['sheets'] + d['edges']).each { |r| r['group_id'] = 'GRP-HOTOVO' }
  end
  a2_with_catalog(already) do
    NxTest.assert_equal(:already, A2MAT.migrate_to_schema2![:status])
    NxTest.assert_equal(already, File.binread(A2MAT.path))
  end
  newer = a2_variant { |d| d['schema'] = 3 }
  a2_expect_noop(newer, :newer_schema)
end

NxTest.test('2A-2 brany: chybajuci subor = :not_found BEZ seedu; prazdny katalog = :empty') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a2_with_catalog(a2_fixture_bytes) do
    FileUtils.rm_f(A2MAT.path)
    A2STORE.invalidate(A2MAT.path)
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:not_found, rep[:status])
    NxTest.refute(File.exist?(A2MAT.path), 'migracia NESMIE seedovat (O4)')
  end
  empty = JSON.pretty_generate({ 'std' => 1, 'sheets' => [], 'edges' => [] })
  a2_expect_noop(empty, :empty)
  broken = '{"std": 1, "sheets": ['
  a2_expect_noop(broken, :undecidable, 'nie je platny JSON')
end

# ---------------------------------------------------------------------------
# CAS (BLOCKER 3) + zaloha (FIX 4)
# ---------------------------------------------------------------------------

NxTest.test('2A-2: CAS — subezna zmena suboru medzi citanim a zapisom = :conflict bez zapisu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  original = a2_fixture_bytes
  competitor = a2_variant { |d| a2_sheet_of(d, 'UNI_DTDL_18')['price_per_m2'] = 9.9 }
  a2_with_catalog(original) do
    rep = A2MAT.migrate_to_schema2!(before_write: -> { File.binwrite(A2MAT.path, competitor) })
    NxTest.assert_equal(:conflict, rep[:status])
    NxTest.assert_equal(competitor, File.binread(A2MAT.path),
                        'subezna zmena NESMIE byt prepisana migraciou')
    NxTest.assert_equal(1, A2MAT.catalog_schema, 'marker ostal legacy')
    # Codex GH P1: CAS bezi pod zamkom PRED zalohou — neuspesny beh (:conflict)
    # nevytvori ZIADEN subor (ani zalohu; zalohovat cudzi novsi stav by bolo zle)
    NxTest.refute(File.exist?(A2MAT.pre_schema2_backup_path), ':conflict zalohu nevytvara')
  end
end

NxTest.test('2A-2: zaloha — existujuca platna sa NEPREPISE; poskodena = :backup_corrupt') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  original = a2_fixture_bytes
  a2_with_catalog(original) do
    stara = '{"note": "stara predmigracna zaloha"}'
    File.binwrite(A2MAT.pre_schema2_backup_path, stara)
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:ok, rep[:status], rep[:reasons].inspect)
    NxTest.assert_equal(stara, File.binread(A2MAT.pre_schema2_backup_path),
                        'platna zaloha ostava nedotknuta (FIX 4)')
    NxTest.assert_equal(2, A2MAT.catalog_schema, 'beh pokracoval a zmigroval')
  end
  a2_with_catalog(original) do
    File.binwrite(A2MAT.pre_schema2_backup_path, 'xx{poskodene')
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:backup_corrupt, rep[:status])
    NxTest.assert_equal(original, File.binread(A2MAT.path), 'stop bez zapisu')
    NxTest.assert_equal('xx{poskodene', File.binread(A2MAT.pre_schema2_backup_path),
                        'poskodena zaloha sa neprepisuje (posledny predmigracny stav)')
  end
end

NxTest.test('2A-2: zamok katalogu (GH P1) — migracia aj bezny zapis bezia pod flock v dir katalogu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a2_with_catalog(a2_fixture_bytes) do
    FileUtils.rm_f(A2MAT.catalog_lock_path)
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:ok, rep[:status], rep[:reasons].inspect)
    NxTest.assert(File.exist?(A2MAT.catalog_lock_path), 'kriticka sekcia vytvorila zamkovy subor')
    NxTest.assert_equal(A2MAT.dir, File.dirname(A2MAT.catalog_lock_path),
                        'zamok zije vedla katalogu (test_dir_override presmeruje aj jeho)')
    NxTest.assert(A2MAT.write(A2MAT.catalog), 'bezny zapis pod zamkom funguje dalej')
  end
end

NxTest.test('2A-2: write guard (GH P1 2. kolo) — stale legacy payload sa do SCHEMA 2 suboru nezapise') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a2_with_catalog(a2_fixture_bytes) do
    stale = A2MAT.catalog # mutatorov load PRED migraciou (legacy, bez group_id)
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:ok, rep[:status], rep[:reasons].inspect)
    migrated = File.binread(A2MAT.path)
    NxTest.refute(A2MAT.write(stale), 'zapis legacy poli do katalogu SCHEMA 2 sa odmietne')
    NxTest.assert_equal(migrated, File.binread(A2MAT.path), 'subor ostal bajtovo migrovany (ziadny hybrid)')
    NxTest.assert(A2MAT.write(A2MAT.catalog), 'UPLNY schema 2 payload (po reload) prejde')
  end
end

NxTest.test('2A-2: write guard — cerstvy marker z disku bije stale cache (ziadny downgrade markera)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a2_with_catalog(a2_fixture_bytes) do
    stale = A2MAT.catalog # cache drzi legacy pohlad
    # "iny proces" zmigruje subor NA DISKU — cache o tom nevie (ziadny invalidate)
    migrated = a2_variant do |d|
      d['schema'] = 2
      (d['sheets'] + d['edges']).each { |r| r['group_id'] = 'GRP-TESTCACHE0000001' }
    end
    File.binwrite(A2MAT.path, migrated)
    NxTest.refute(A2MAT.write(stale), 'stale legacy payload odmietnuty aj so stale cache')
    NxTest.assert_equal(2, JSON.parse(File.binread(A2MAT.path))['schema'],
                        'marker na disku ostal 2 (cache ho nezhodila na 1)')
  end
end

NxTest.test('2A-2: zamok je reentrantny (vnorene volanie sa nezablokuje samo o seba)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a2_with_catalog(a2_fixture_bytes) do
    inner = A2MAT.with_catalog_lock { A2MAT.with_catalog_lock { :vnorene_ok } }
    NxTest.assert_equal(:vnorene_ok, inner)
    NxTest.assert(A2MAT.with_catalog_lock { A2MAT.write(A2MAT.catalog) },
                  'write vnutri drzaneho zamku prejde (depth counter)')
  end
end

NxTest.test('2A-2: retype vyzaduje aj zdrojovy dekor (GH P1 2. kolo) — premenovany zaznam = undecidable') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  original = a2_variant { |d| a2_sheet_of(d, 'HALIFAX_TABAKOVY_PD_DTDL_38')['decor'] = 'Premenovany dekor PD' }
  a2_with_catalog(original) do
    rep = A2MAT.migrate_to_schema2!
    NxTest.assert_equal(:undecidable, rep[:status])
    NxTest.assert(rep[:reasons].any? { |r| r.include?('HALIFAX_TABAKOVY_PD_DTDL_38') && r.include?('retype') },
                  "dovod menuje retype ocakavanie: #{rep[:reasons].inspect}")
    NxTest.assert_equal(original, File.binread(A2MAT.path), 'atomicky no-op')
  end
end

NxTest.test('2A-2: pad zapisu = :write_failed s reportom, ziadna uletena vynimka (GH P2 2. kolo)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  a2_with_catalog(a2_fixture_bytes) do
    store = Noxun::Engine::JsonFileStore
    orig = store.method(:write)
    begin
      store.define_singleton_method(:write) { |*_a| raise IOError, 'disk full (test)' }
      rep = A2MAT.migrate_to_schema2!
      NxTest.assert_equal(:write_failed, rep[:status], 'I/O pad sa prelozi na status, nie vynimku')
    ensure
      store.define_singleton_method(:write, orig)
    end
    NxTest.assert_equal(a2_fixture_bytes, File.binread(A2MAT.path), 'katalog ostal legacy nedotknuty')
  end
end

# ---------------------------------------------------------------------------
# BLOCKER 2: guard ensure cesty (schema klienta vs schema katalogu)
# ---------------------------------------------------------------------------

NxTest.test('2A-2: ensure_edge_for_sheet — katalog SCHEMA 2 + stary klient = :schema_read_only bez zapisu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  A2MAT.catalog # seed sandboxu
  # dnesny stav (schema 1): guard MLCI a sprava sa presne ako doteraz
  status, abs_id = A2MAT.ensure_edge_for_sheet('K009_PW_DTDL_18')
  NxTest.assert_equal(:exists, status, 'schema 1: dnesne spravanie nezmenene ani o chlp')
  NxTest.assert_equal('ABS_K009_10', abs_id)
  a2_with_schema2_marker do
    before = File.binread(A2MAT.path)
    NxTest.assert_equal([:schema_read_only, nil], A2MAT.ensure_edge_for_sheet('K009_PW_DTDL_18'),
                        'stary klient (default legacy) po migracii pasku nevytvori')
    NxTest.assert_equal([:schema_read_only, nil],
                        A2MAT.ensure_edge_for_sheet('K009_PW_DTDL_18', client_schema: 1))
    NxTest.assert_equal(before, File.binread(A2MAT.path), 'guard bezi PRED akymkolvek zapisom')
    st2, abs2 = A2MAT.ensure_edge_for_sheet('K009_PW_DTDL_18', client_schema: 2)
    NxTest.assert_equal(:exists, st2, 'novy klient prejde')
    NxTest.assert_equal('ABS_K009_10', abs2)
  end
end

# ---------------------------------------------------------------------------
# FIX 6: RED abs_missing v kontrolnom semafore
# ---------------------------------------------------------------------------

def a2_val_record(over = {})
  { 'name' => 'Dielec', 'part_key' => 'cabinet/x', 'owner_id' => 'CAB-1', 'pid' => 1,
    'role' => 'shelf', 'length' => 500.0, 'width' => 400.0, 'thickness' => 18.0,
    'quantity' => 1, 'material_id' => 'K1', 'grain_direction' => 'length',
    'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }.merge(over)
end

A2_VAL_SHEETS = { 'K1' => { 'material_id' => 'K1', 'thickness' => 18.0,
                            'sheet_size' => [2800.0, 2070.0] } }.freeze

NxTest.test('2A-2 validation: abs_id mimo katalogu = RED abs_missing (1 polozka na dielec)') do
  rec = a2_val_record('edges' => { 'L1' => 'ABS_GONE_10', 'L2' => 'ABS_OK_10',
                                   'W1' => 'ABS_GONE_10', 'W2' => nil })
  out = A2VAL.run({ records: [rec] }, sheets: A2_VAL_SHEETS,
                  edges: { 'ABS_OK_10' => { 'abs_id' => 'ABS_OK_10' } })
  items = out['items'].select { |i| i['category'] == 'abs_missing' }
  NxTest.assert_equal(1, items.length, 'jedna polozka na dielec, nie per hrana')
  NxTest.assert_equal('red', items.first['severity'])
  NxTest.assert(items.first['message_sk'].include?('ABS páska'), items.first['message_sk'])
  NxTest.assert(items.first['message_sk'].include?('ABS_GONE_10'))
  NxTest.assert(items.first['message_sk'].include?('nie je v katalógu'))
  NxTest.assert_equal(1, out['counts']['red'])
  # dve rozne chybajuce pasky na jednom dielci = stale JEDNA polozka s oboma ID
  rec2 = a2_val_record('edges' => { 'L1' => 'ABS_GONE_10', 'L2' => 'ABS_GONE2_20',
                                    'W1' => nil, 'W2' => nil })
  out2 = A2VAL.run({ records: [rec2] }, sheets: A2_VAL_SHEETS, edges: {})
  items2 = out2['items'].select { |i| i['category'] == 'abs_missing' }
  NxTest.assert_equal(1, items2.length)
  NxTest.assert(items2.first['message_sk'].include?('ABS_GONE_10') &&
                items2.first['message_sk'].include?('ABS_GONE2_20'), items2.first['message_sk'])
  NxTest.assert(items2.first['message_sk'].include?('nie sú'), 'mnozne cislo pri viacerych paskach')
end

NxTest.test('2A-2 validation: abs_missing NIKDY bez dodaneho ABS katalogu (edges: nil = dnesne spravanie)') do
  rec = a2_val_record('edges' => { 'L1' => 'ABS_GONE_10', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  out = A2VAL.run({ records: [rec] }, sheets: A2_VAL_SHEETS)
  NxTest.assert(out['items'].none? { |i| i['category'] == 'abs_missing' },
                'bez ABS katalogu sa kontrola cela preskoci — ziadna regresia existujucich volani')
  # paska V katalogu = ziadny problem; prazdne hodnoty sa ignoruju
  out2 = A2VAL.run({ records: [a2_val_record('edges' => { 'L1' => 'ABS_OK_10', 'L2' => '',
                                                          'W1' => nil, 'W2' => nil })] },
                   sheets: A2_VAL_SHEETS, edges: { 'ABS_OK_10' => {} })
  NxTest.assert(out2['items'].none? { |i| i['category'] == 'abs_missing' })
  NxTest.assert_equal(0, out2['counts']['total'])
end

NxTest.test('2A-2 validation: abs_missing je nezavisle od materialu a deterministicke') do
  # dielec s materialom MIMO katalogu A zaroven chybajucou paskou = 2 RED
  rec = a2_val_record('material_id' => 'NEZNAMY',
                      'edges' => { 'L1' => 'ABS_GONE_10', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  out = A2VAL.run({ records: [rec] }, sheets: A2_VAL_SHEETS, edges: {})
  cats = out['items'].map { |i| i['category'] }.sort
  NxTest.assert_equal(%w[abs_missing material], cats)
  NxTest.assert_equal(2, out['counts']['red'])
  # dedup + stabilne poradie nezavisle od poradia vstupu
  a = A2VAL.run({ records: [rec, rec.dup] }, sheets: A2_VAL_SHEETS, edges: {})
  NxTest.assert_equal(2, a['items'].length, 'rovnaky stable_key = 1 polozka')
  b = A2VAL.run({ records: [rec.dup, rec] }, sheets: A2_VAL_SHEETS, edges: {})
  NxTest.assert_equal(a['items'].map { |i| i['stable_key'] }, b['items'].map { |i| i['stable_key'] })
end
