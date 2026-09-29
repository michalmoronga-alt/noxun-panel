# frozen_string_literal: true
# NP-2 (blok 2 · Narezovy plan): nastavenia prerezu, orezu a pridavku duplaku
# (SupplierSettings, verzia suboru 2 + dopredna brana) a Kontrola „nezmesti sa"
# cez SPOLOCNU pripravu s planom (SheetLayout.purchase_rect + fits_rect?).
# Package: SYSTEM/zdroje/bloky/NAREZ/PACKAGE_NP2_NASTAVENIA.md (+ nalezy auditu
# B1, B2, F3, F4, N5, N6 — maju prednost).
#
# Nastavenia sa testuju v IZOLOVANOM priecinku (`Materials.test_dir_override`,
# vzor R-11) — nikdy nad zivym %APPDATA%; preto VYHRADNE headless.
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'
require 'tmpdir'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') unless defined?(Noxun::Engine::StudioDialog)
  unless defined?(Noxun::Engine::SupplierSettingsDialog)
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog')
  end
end

module NxNp2
  E     = Noxun::Engine
  SS    = E::SupplierSettings
  VAL   = E::Validation
  SL    = E::SheetLayout
  MAT   = E::Materials
  STORE = E::JsonFileStore
  ROOT  = NxTest::ROOT

  CORRUPT = "{ toto uz nie je JSON\n"

  module_function

  def src(rel)
    File.read(File.join(ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
  end

  # Telo metody `def name` az po `end` na rovnakom odsadeni.
  def body(rel, name)
    s = src(rel)
    m = s.match(/^(\s*)def #{Regexp.escape(name)}(?=[\s(]).*?^\1end\b/m)
    m ? m[0] : ''
  end

  # --- sandbox nastaveni (vzor R-11) ----------------------------------------
  def with_sandbox
    prev = MAT.test_dir_override
    dir = Dir.mktmpdir('nx-np2-')
    MAT.test_dir_override = dir
    STORE.invalidate
    yield dir
  ensure
    MAT.test_dir_override = prev
    STORE.invalidate
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end

  def write_json(path, doc)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, JSON.pretty_generate(doc))
  end

  def disk
    JSON.parse(File.binread(SS.path))
  end

  # Dokument formatu 1 (pred NP-2): bez troch novych skalarov.
  def v1_doc(extra_sup = {})
    sup = { 'id' => 'default', 'name' => 'Noxun', 'rates' => { 'olep' => 0.9 },
            'stale_days' => 30, 'rounding_step' => 1.0, 'abs_reserve_pct' => 10.0,
            'montaz_m2_per_plate' => 5.8, 'cp_highlight_threshold' => 150.0 }.merge(extra_sup)
    { 'std' => 1, 'seed_version' => 1, 'active' => 'default', 'suppliers' => [sup] }
  end

  # --- Kontrola -------------------------------------------------------------
  SHEETS = {
    'DTD'   => { 'material_id' => 'DTD', 'type' => 'DTDL', 'thickness' => 18.0,
                 'sheet_size' => [2800.0, 2070.0], 'grain' => 'length' },
    'PD'    => { 'material_id' => 'PD', 'type' => 'PD', 'thickness' => 38.0,
                 'sheet_size' => [4100.0, 600.0], 'grain' => 'length' },
    'DUP36' => { 'material_id' => 'DUP36', 'type' => 'DTDL', 'thickness' => 36.0,
                 'sheet_size' => [2800.0, 2070.0], 'grain' => 'length', 'source_material_id' => 'DTD' },
    'UNI'   => { 'material_id' => 'UNI', 'type' => 'DTDL', 'thickness' => 18.0,
                 'sheet_size' => [2800.0, 2070.0], 'uni' => true },
    'NOFMT' => { 'material_id' => 'NOFMT', 'type' => 'DTDL', 'thickness' => 18.0 }
  }.freeze

  def edges(h = {})
    { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.merge(h)
  end

  def rec(over = {})
    { 'name' => 'Bok', 'part_key' => 'cabinet/side:left', 'owner_id' => 'CAB-1', 'pid' => 1,
      'role' => 'side_left', 'length' => 2785.0, 'width' => 500.0, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => 'DTD', 'grain_direction' => 'length',
      'edges' => edges }.merge(over)
  end

  def layout(trim: 10.0, dup: 10.0, kerf: 5.0, source: :file, et: {})
    { params: { 'kerf' => kerf, 'trim' => trim, 'dup_allowance' => dup }, source: source,
      edge_thicknesses: et }
  end

  def run(records, lay = layout, sheets: SHEETS, edges: nil)
    VAL.run({ records: records }, sheets: sheets, edges: edges, layout: lay)
  end

  def of(out, cat)
    out['items'].select { |i| i['category'] == cat }
  end
end

# ============================================================================
# 1) NASTAVENIA — skalare, rozsahy, desatinne cisla
# ============================================================================

NxTest.test('NP-2 nastavenia: seed 5/10/10, subor ma std 2') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    sup = NxNp2::SS.active
    NxTest.assert_close(5.0, sup['kerf_mm'], 1e-9)
    NxTest.assert_close(10.0, sup['trim_mm'], 1e-9)
    NxTest.assert_close(10.0, sup['dup_allowance_mm'], 1e-9)
    NxTest.assert_equal(2, NxNp2::SS::STD)
    NxTest.assert_equal(2, NxNp2.disk['std'], 'cisty seed sa zapise vo verzii 2')
    lp = NxNp2::SS.layout_params
    NxTest.assert_equal({ 'kerf' => 5.0, 'trim' => 10.0, 'dup_allowance' => 10.0 }, lp[:params])
    NxTest.assert_equal(:file, lp[:source])
  end
end

NxTest.test('NP-2 nastavenia: subor std 1 — skalare sa doplnia, PRVY zapis ho peciatkuje na std 2') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    NxNp2.write_json(NxNp2::SS.path, NxNp2.v1_doc)
    NxNp2::STORE.invalidate
    sup = NxNp2::SS.active
    NxTest.assert_close(5.0, sup['kerf_mm'], 1e-9)
    NxTest.assert_close(10.0, sup['trim_mm'], 1e-9)
    NxTest.assert_close(10.0, sup['dup_allowance_mm'], 1e-9)
    ok, errs, = NxNp2::SS.patch_active!('rounding_step' => 2.0)
    NxTest.assert(ok, errs.inspect)
    d = NxNp2.disk
    NxTest.assert_equal(2, d['std'], 'zapis MUSI peciatkovat aktualnu verziu (inak ostane navzdy 1)')
    NxTest.assert_close(10.0, d['suppliers'].first['trim_mm'], 1e-9, 'a novy kluc je na disku')
  end
end

NxTest.test('NP-2 nastavenia: desatinne s ciarkou aj bodkou; tri kluce sa NAOZAJ ulozia na disk') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    ok, errs, = NxNp2::SS.patch_active!('kerf_mm' => '4,4', 'trim_mm' => '12.5', 'dup_allowance_mm' => 7)
    NxTest.assert(ok, errs.inspect)
    s = NxNp2.disk['suppliers'].first
    NxTest.assert_close(4.4, s['kerf_mm'], 1e-9, 'ciarka')
    NxTest.assert_close(12.5, s['trim_mm'], 1e-9, 'bodka')
    NxTest.assert_close(7.0, s['dup_allowance_mm'], 1e-9)
    NxTest.assert_equal({ 'kerf' => 4.4, 'trim' => 12.5, 'dup_allowance' => 7.0 },
                        NxNp2::SS.layout_params[:params], 'layout_params cita ulozene hodnoty')
  end
end

NxTest.test('NP-2 nastavenia: hranice rozsahov — 0 a max prejdu, max+0,01 / zaporne / Infinity / text nie') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    { 'kerf_mm' => 10.0, 'trim_mm' => 50.0, 'dup_allowance_mm' => 30.0 }.each do |k, max|
      NxTest.assert(NxNp2::SS.patch_active!(k => 0).first, "#{k}: 0 prejde")
      NxTest.assert(NxNp2::SS.patch_active!(k => max).first, "#{k}: #{max} prejde")
      [max + 0.01, -1, 'Infinity', '1e400', 'abc', ''].each do |bad|
        ok, errs, status = NxNp2::SS.patch_active!(k => bad)
        NxTest.refute(ok, "#{k}: #{bad.inspect} sa MUSI odmietnut")
        NxTest.assert_equal(:invalid, status)
        NxTest.assert(errs.join.include?('hodnota mimo rozsahu'), errs.inspect)
      end
      NxTest.assert_close(max, NxNp2.disk['suppliers'].first[k], 1e-9, 'odmietnutie nic nezapisalo')
    end
  end
end

NxTest.test('NP-2 nastavenia: chyba rozsahu je LUDSKA (popis + jednotka + desatinna ciarka)') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    _ok, errs, = NxNp2::SS.patch_active!('kerf_mm' => 11)
    NxTest.assert_equal(['Prerez píly (hrúbka kotúča): hodnota mimo rozsahu 0–10 mm'], errs)
    _ok, errs, = NxNp2::SS.patch_active!('trim_mm' => -3)
    NxTest.assert_equal(['Orez okraja platne: hodnota mimo rozsahu 0–50 mm'], errs)
    _ok, errs, = NxNp2::SS.patch_active!('rounding_step' => 0)
    NxTest.assert_equal(['Zaokrúhlenie ponuky nahor na: hodnota mimo rozsahu 0,01–1000 €'], errs)
    NxTest.refute(errs.join.include?('rounding_step'), 'ziadny surovy kluc')
  end
end

NxTest.test('NP-2 nastavenia: zoznam skalarov je UZAVRETY — defaulty, rozsahy, normalizacia a popisy sedia') do
  ss = NxNp2::SS
  keys = ss::SCALAR_DEFAULTS.keys.sort
  NxTest.assert_equal(keys - ['stale_days'], ss::SCALAR_RANGES.keys.sort,
                      'kazdy skalar okrem dni ma rozsah (zabudnuty rozsah = patch ho ticho vynecha)')
  NxTest.assert_equal(keys, ss::SCALAR_LABELS.keys.sort, 'kazdy skalar ma ludsky popis pre chybu')
  norm = ss.normalize_supplier({ 'id' => 'x' })
  keys.each { |k| NxTest.assert(norm.key?(k), "normalize_supplier nesie #{k} (whitelist)") }
  NxTest.assert_equal(%w[kerf_mm trim_mm dup_allowance_mm], ss::LAYOUT_KEYS.values)
end

NxTest.test('NP-2 GUARD: zoznam skalarov Ruby (SCALAR_DEFAULTS) == JS (SS_SCALARS) — pole bez riadku by sa nedalo nastavit') do
  js = NxNp2.src('ui/js/studio_settings.js')
  block = js[/var SS_SCALARS = \[(.*?)\n  \];/m, 1].to_s
  NxTest.assert(!block.empty?, 'blok SS_SCALARS sa nasiel')
  js_keys = block.scan(/^\s*\['([a-z_0-9]+)',/).flatten
  NxTest.assert_equal(NxNp2::SS::SCALAR_DEFAULTS.keys.sort, js_keys.sort)
  # Poradie z mockupu D: tri nove riadky medzi „m² na platňu" a „Zaokrúhlenie".
  NxTest.assert_equal(%w[abs_reserve_pct montaz_m2_per_plate kerf_mm trim_mm dup_allowance_mm
                         rounding_step stale_days cp_highlight_threshold], js_keys)
  # Predrecenzia P3-3: chyba rozsahu hovori na serveri aj v klientovi TO ISTE —
  # popis a jednotka riadku == `SCALAR_LABELS`.
  js_meta = block.scan(/^\s*\['([a-z_0-9]+)', '([^']*)', '([^']*)'/).to_h { |k, l, u| [k, [l, u]] }
  NxTest.assert_equal(NxNp2::SS::SCALAR_LABELS.to_h { |k, v| [k, v] }, js_meta)
end

# ============================================================================
# 2) DOPREDNA BRANA (C4) — subor z novsieho pluginu
# ============================================================================

NxTest.test('NP-2 brana: subor std 3 — citanie ano, patch odmietnuty s dovodom, subor BAJTOVO nezmeneny') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    doc = NxNp2.v1_doc('trim_mm' => 20.0, 'buduce_pole' => 'x')
    doc['std'] = 3
    doc['suppliers'].first['standard_rows'] = [] # seed-merge by chcel riadky doplnit
    NxNp2.write_json(NxNp2::SS.path, doc)
    before = File.binread(NxNp2::SS.path)
    NxNp2::STORE.invalidate
    sup, source = NxNp2::SS.active_with_source
    NxTest.assert_close(20.0, sup['trim_mm'], 1e-9, 'zname polia sa CITAJU')
    NxTest.assert_equal(:newer_file, source)
    NxTest.assert_equal(:newer_file, NxNp2::SS.layout_params[:source])
    NxTest.assert_equal(before, File.binread(NxNp2::SS.path), 'seed-merge NEZAPISAL (riadky chybaju, subor stoji)')
    # Seed-merge sa o zapis do novsieho suboru ani NEPOKUSI (nie len „brana
    # ho zastavi") — inak by kazde nacitanie bralo zamok a logovalo odmietnutie.
    calls = 0
    orig = NxNp2::SS.method(:write)
    NxNp2::SS.define_singleton_method(:write) { |*a| calls += 1; orig.call(*a) }
    begin
      NxNp2::STORE.invalidate
      NxNp2::SS.load
    ensure
      NxNp2::SS.define_singleton_method(:write, orig)
    end
    NxTest.assert_equal(0, calls, 'citanie novsieho suboru nevola `write`')
    ok, errs, status = NxNp2::SS.patch_active!('kerf_mm' => 4.0)
    NxTest.refute(ok)
    NxTest.assert_equal(:write_failed, status)
    NxTest.assert(errs.join.include?('novší plugin'), errs.inspect)
    NxTest.assert(errs.join.include?('aktualizuj plugin'), 'veta hovori, co robit')
    NxTest.assert_equal(before, File.binread(NxNp2::SS.path), 'zapis odmietnuty — subor bajtovo ten isty')
    st = NxNp2::SS.settings_state(source)
    NxTest.assert_equal('newer', st['state'])
    NxTest.assert(st['reason'].include?('verzia súboru 3'), st['reason'])
  end
end

NxTest.test('NP-2 brana (audit F4): nahriata cache -> novsi subor na disku -> priame `write` = ODMIETNUTE') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    doc = NxNp2::SS.load # nahreje sekundovu cache verziou 2
    newer = NxNp2.v1_doc
    newer['std'] = 3
    File.binwrite(NxNp2::SS.path, JSON.pretty_generate(newer)) # BEZ invalidacie cache
    before = File.binread(NxNp2::SS.path)
    NxTest.refute(NxNp2::SS.write(doc), 'brana cita verziu CERSTVO pod zamkom')
    NxTest.assert(NxNp2::SS.write_block_reason.include?('novší plugin'))
    NxTest.assert_equal(before, File.binread(NxNp2::SS.path))
  end
end

NxTest.test('NP-2 brana: kazdy zapis peciatkuje std = STD (aj ked volajuci posle std 1)') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    NxTest.assert(NxNp2::SS.write(NxNp2.v1_doc), 'zapis prejde')
    NxTest.assert_equal(2, NxNp2.disk['std'])
  end
end

NxTest.test('NP-2 GUARD: poradie v `write` = zamok < degradovany < novsi < zapis (+ R-11/R-08 ostavaju)') do
  b = NxNp2.body('core/supplier_settings.rb', 'write')
  lock = b.index('with_catalog_lock')
  deg = b.index('degraded_write_blocked?')
  newer = b.index('newer_write_blocked?')
  wr = b.index('JsonFileStore.write(')
  NxTest.assert(lock && deg && newer && wr, b)
  NxTest.assert(lock < deg && deg < newer && newer < wr, 'poradie bran')
  NxTest.assert(b.include?("merge('std' => STD)"), 'peciatka verzie je PRIAMO v zapise')
  nb = NxNp2.body('core/supplier_settings.rb', 'newer_write_blocked?')
  NxTest.assert(nb.index('JsonFileStore.reload!') < nb.index('JsonFileStore.read'),
                'verzia sa cita CERSTVO (bez sekundovej cache)')
end

NxTest.test('NP-2 stav: ok / degraded (zaloha) / fallback (necitatelny subor) — payload aj layout_params') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    NxTest.assert_equal({ 'state' => 'ok', 'reason' => '' },
                        NxNp2::SS.settings_state(NxNp2::SS.active_with_source.last))
    # degraded: poskodeny primar + platna zaloha
    bak = NxNp2.v1_doc('trim_mm' => 25.0)
    bak['std'] = 2
    NxNp2.write_json("#{NxNp2::SS.path}.bak", bak)
    File.binwrite(NxNp2::SS.path, NxNp2::CORRUPT)
    NxNp2::STORE.invalidate
    lp = NxNp2::SS.layout_params
    NxTest.assert_equal(:backup, lp[:source])
    NxTest.assert_close(25.0, lp[:params]['trim'], 1e-9, 'cita sa zo zalohy')
    NxTest.assert_equal('degraded', NxNp2::SS.settings_state(:backup)['state'])
    # fallback: poskodeny primar BEZ zalohy
    FileUtils.rm_f("#{NxNp2::SS.path}.bak")
    File.binwrite(NxNp2::SS.path, NxNp2::CORRUPT)
    NxNp2::STORE.invalidate
    lp = NxNp2::SS.layout_params
    NxTest.assert_equal(:seed_fallback, lp[:source], 'povod sa NESTRATI v rescue `load`')
    NxTest.assert_equal({ 'kerf' => 5.0, 'trim' => 10.0, 'dup_allowance' => 10.0 }, lp[:params])
    st = NxNp2::SS.settings_state(:seed_fallback)
    NxTest.assert_equal('fallback', st['state'])
    NxTest.assert(st['reason'].include?('predvolené'))
  end
end

NxTest.test('NP-2 payload sekcie: nesie `settings_state` a `scalar_ranges` (rozsahy = serverova autorita)') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxNp2.with_sandbox do
    data = Noxun::Engine::SupplierSettingsDialog.settings_payload
    NxTest.assert(data.is_a?(Hash))
    NxTest.assert_equal('ok', data['settings_state']['state'])
    NxTest.assert_equal([0.0, 10.0], data['scalar_ranges']['kerf_mm'])
    NxTest.assert_equal([0.0, 50.0], data['scalar_ranges']['trim_mm'])
    NxTest.assert_equal([0.0, 30.0], data['scalar_ranges']['dup_allowance_mm'])
    NxTest.assert_equal([1.0, 3650.0], data['scalar_ranges']['stale_days'])
    NxTest.assert_close(5.0, data['supplier']['kerf_mm'], 1e-9)
  end
end

# ============================================================================
# 3) KONTROLA „nezmesti sa" — jedna pravda s planom (O9, C9, G4)
# ============================================================================

NxTest.test('NP-2 Kontrola: 2785 x 500 na DTD 2800 x 2070 pri oreze 10 = RED s pouzitelnou plochou; pri oreze 0 nic') do
  f = NxNp2
  out = f.run([f.rec], f.layout(trim: 10.0))
  over = f.of(out, 'oversize')
  NxTest.assert_equal(1, over.length)
  msg = over.first['message_sk']
  NxTest.assert(msg.include?('po oreze 10 mm (použiteľná plocha 2780 × 2050 mm)'), msg)
  NxTest.assert(msg.include?('na platňu 2800 × 2070 mm'), msg)
  NxTest.assert(msg.include?('hotový rozmer vrátane ABS'), 'audit N5: kontrola je opatrna a hovori to')
  NxTest.assert_equal('oversize|CAB-1|cabinet/side:left', over.first['stable_key'], 'kluc nalezu sa NEMENI')
  NxTest.assert_equal(0, f.of(f.run([f.rec], f.layout(trim: 0.0)), 'oversize').length)
  msg0 = f.of(f.run([f.rec('length' => 2900.0)], f.layout(trim: 0.0)), 'oversize').first['message_sk']
  NxTest.refute(msg0.include?('po oreze'), 'pri oreze 0 sa o oreze nehovori')
end

NxTest.test('NP-2 Kontrola: pracovna doska sa NEorezava (N9) — 4100 x 600 platna, dielec 4100 x 600 bez nalezu') do
  f = NxNp2
  out = f.run([f.rec('material_id' => 'PD', 'thickness' => 38.0, 'length' => 2400.0, 'width' => 600.0),
               f.rec('material_id' => 'PD', 'thickness' => 38.0, 'length' => 4100.0, 'width' => 600.0,
                     'part_key' => 'board/pd')], f.layout(trim: 10.0))
  NxTest.assert_equal(0, f.of(out, 'oversize').length, 'orez pri PD by 600 zmenil na 580 = falosny RED')
end

NxTest.test('NP-2 Kontrola: duplak 2765 x 580 -> vrstva 2785 x 600 sa nezmesti = JEDEN RED s prirezmi') do
  f = NxNp2
  dup = f.rec('material_id' => 'DUP36', 'thickness' => 36.0, 'length' => 2765.0, 'width' => 580.0,
              'material_source' => { 'material_id' => 'DTD', 'multiplier' => 2 })
  out = f.run([dup], f.layout(trim: 10.0, dup: 10.0))
  over = f.of(out, 'oversize')
  NxTest.assert_equal(1, over.length, 'duplak = jeden hotovy dielec, jeden nalez')
  msg = over.first['message_sk']
  NxTest.assert(msg.include?('duplák: 2 prírezy 2785 × 600 mm'), msg)
  NxTest.assert(msg.include?('(materiál DTD)'), 'platna je ZDROJ duplaku')
  NxTest.assert_equal(0, f.of(f.run([dup], f.layout(trim: 10.0, dup: 0.0)), 'oversize').length,
                      'bez pridavku sa 2765 x 580 zmesti do 2780 x 2050')
  # 3 vrstvy — text „3 prírezy"
  dup3 = dup.merge('material_source' => { 'material_id' => 'DTD', 'multiplier' => 3 })
  NxTest.assert(f.of(f.run([dup3]), 'oversize').first['message_sk'].include?('3 prírezy'))
end

NxTest.test('NP-2 Kontrola (predrecenzia P2-1): duplak s NEZNAMOU ABS — veta o prirezoch ostava (geometria odmietnutia nesie doubled/multiplier)') do
  f = NxNp2
  dup = f.rec('material_id' => 'DUP36', 'thickness' => 36.0, 'length' => 2765.0, 'width' => 580.0,
              'material_source' => { 'material_id' => 'DTD', 'multiplier' => 2 },
              'edges' => f.edges('L1' => 'NEZNAMA'))
  rect = f::SL.purchase_rect(dup, sheets: f::SHEETS, edge_thicknesses: {},
                             params: { 'kerf' => 5.0, 'trim' => 10.0, 'dup_allowance' => 10.0 })
  NxTest.assert_equal('vepo', rect['reason'], 'VEPO riadok odmietne (neznama ABS)')
  NxTest.assert_equal(true, rect['doubled'])
  NxTest.assert_equal(2, rect['multiplier'])
  over = f.of(f.run([dup], f.layout(et: {})), 'oversize')
  NxTest.assert_equal(1, over.length)
  NxTest.assert(over.first['message_sk'].include?('duplák: 2 prírezy 2785 × 600 mm'), over.first['message_sk'])
end

NxTest.test('NP-2 Kontrola (predrecenzia P3-4): orez a pouzitelna plocha s rovnakou presnostou ako nastavenia (2 desatinne)') do
  f = NxNp2
  msg = f.of(f.run([f.rec('length' => 2780.0)], f.layout(trim: 12.25)), 'oversize').first['message_sk']
  NxTest.assert(msg.include?('po oreze 12,25 mm (použiteľná plocha 2775,5 × 2045,5 mm)'), msg)
  NxTest.assert_equal('12,25', f::VAL.mm2(12.25))
  NxTest.assert_equal('4,4', f::VAL.mm2(4.4))
  NxTest.assert_equal('10', f::VAL.mm2(10.0))
end

NxTest.test('NP-2 Kontrola: dielec bez smeru sa OTOCI (2000 x 2500 bez nalezu), so smerom `length` RED') do
  f = NxNp2
  NxTest.assert_equal(0, f.of(f.run([f.rec('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => 'none')]),
                              'oversize').length)
  NxTest.assert_equal(0, f.of(f.run([f.rec('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => '')]),
                              'oversize').length, 'prazdny smer = obe polohy (dnesne pravidlo)')
  NxTest.assert_equal(1, f.of(f.run([f.rec('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => 'length')]),
                              'oversize').length)
  # grain 'width' = jedina vymena VEPO: 2500 x 2000 -> dlzka 2000, sirka 2500 > 2050
  NxTest.assert_equal(1, f.of(f.run([f.rec('length' => 2500.0, 'width' => 2000.0, 'grain_direction' => 'width')]),
                              'oversize').length)
end

NxTest.test('NP-2 Kontrola: sucasny drift + oversize = 2 RED (test_validation ostava); UNI a bez formatu nic') do
  f = NxNp2
  both = f.run([f.rec('thickness' => 16.0)])
  NxTest.assert_equal(%w[oversize thickness], both['items'].map { |i| i['category'] }.sort)
  NxTest.assert_equal(0, f.of(f.run([f.rec('material_id' => 'UNI', 'length' => 5000.0)]), 'oversize').length)
  NxTest.assert_equal(0, f.of(f.run([f.rec('material_id' => 'NOFMT', 'length' => 5000.0)]), 'oversize').length)
end

NxTest.test('NP-2 Kontrola (audit N5): hranicny dielec s ABS sa hlasi opatrne — hotovy rozmer vratane ABS') do
  f = NxNp2
  # 2782 hotovy s 2 mm ABS na oboch koncoch: doska by mala 2778 (zmestila by sa),
  # Kontrola porovnava hotovy rozmer (ABS neodpocitava) -> RED, veta to prizna.
  r = f.rec('length' => 2782.0, 'edges' => f.edges('L1' => 'ABS2', 'L2' => 'ABS2'))
  over = f.of(f.run([r], f.layout(et: { 'ABS2' => 2.0 })), 'oversize')
  NxTest.assert_equal(1, over.length)
  NxTest.assert(over.first['message_sk'].include?('hotový rozmer vrátane ABS'))
end

NxTest.test('NP-2 Kontrola: `edges: nil` ani chybajuce hrubky ABS nevypnu oversize (geometria bez ABS katalogu)') do
  f = NxNp2
  r = f.rec('edges' => f.edges('L1' => 'NEZNAMA'))
  NxTest.assert_equal(1, f.of(f.run([r], f.layout(et: {}), edges: nil), 'oversize').length)
  NxTest.assert_equal(1, f.of(f.run([r], f.layout(et: nil), edges: nil), 'oversize').length)
end

NxTest.test('NP-2 Kontrola (audit B1): neplatny vyrobny rozmer cez Bom.record -> Validation.run = RED `invalid_dims`') do
  f = NxNp2
  cfgs = [
    { 'length' => 3000.0, 'width' => 0.0 },
    { 'length' => 3000.0, 'width' => 0.4 },  # VEPO zaokruhli na 0 mm
    { 'length' => Float::NAN, 'width' => 500.0 }
  ]
  cfgs.each_with_index do |c, i|
    cfg = c.merge('thickness' => 18.0, 'quantity' => 1, 'material_id' => 'DTD', 'grain_direction' => 'length',
                  'edges' => {})
    r = Noxun::Engine::Bom.record(cfg, owner_id: 'CAB-1', name: 'Bok', part_key: "cabinet/p#{i}", role: 'side_left')
    out = f.run([r])
    inv = f.of(out, 'invalid_dims')
    NxTest.assert_equal(1, inv.length, "#{c.inspect}: dielec nesmie ostat bez RED")
    NxTest.assert_equal('red', inv.first['severity'])
    NxTest.assert_equal("invalid_dims|CAB-1|cabinet/p#{i}", inv.first['stable_key'])
    NxTest.assert(inv.first['message_sk'].include?('nedá objednať'), inv.first['message_sk'])
    NxTest.assert_equal(0, f.of(out, 'oversize').length)
  end
  # legacy volanie (bez layout:) tiez
  bad = Noxun::Engine::Bom.record({ 'length' => 3000.0, 'width' => 0.0, 'thickness' => 18.0, 'material_id' => 'DTD' },
                                  owner_id: 'CAB-1', name: 'Bok', part_key: 'p', role: 'side_left')
  legacy = Noxun::Engine::Validation.run({ records: [bad] }, sheets: NxNp2::SHEETS)
  NxTest.assert_equal(1, legacy['items'].count { |i| i['category'] == 'invalid_dims' })
end

NxTest.test('NP-2 Kontrola (audit B2): nastavenia z `:seed_fallback` = JEDEN ORANGE nalez bez dielca') do
  f = NxNp2
  out = f.run([f.rec, f.rec('part_key' => 'x')], f.layout(source: :seed_fallback))
  ls = f.of(out, 'layout_settings')
  NxTest.assert_equal(1, ls.length)
  NxTest.assert_equal('orange', ls.first['severity'])
  NxTest.assert(ls.first['owner_id'].nil?, 'nalez bez dielca')
  NxTest.assert(ls.first['message_sk'].include?('prerez 5 mm, orez 10 mm, prídavok dupláku 10 mm'),
                ls.first['message_sk'])
  NxTest.assert_equal(0, f.of(f.run([f.rec]), 'layout_settings').length, 'bezny subor nic')
end

NxTest.test('NP-2 Kontrola: legacy volanie bez `layout:` = orez 0 a bez pridavku (spravanie pred NP-2)') do
  f = NxNp2
  out = f::VAL.run({ records: [f.rec] }, sheets: f::SHEETS)
  NxTest.assert_equal(0, f.of(out, 'oversize').length)
  NxTest.assert(Noxun::Engine::Validation.fits_on_sheet?(2500.0, 250.0, 'length', 2800.0, 2070.0))
  NxTest.refute(Noxun::Engine::Validation.fits_on_sheet?(2500.0, 250.0, 'width', 2800.0, 2070.0))
  NxTest.assert(Noxun::Engine::Validation.fits_on_sheet?(2000.0, 2500.0, 'none', 2800.0, 2070.0))
end

# ============================================================================
# 4) DVAJA VOLAJUCI — jedna funkcia parametrov (payload aj klik na nalez)
# ============================================================================

NxTest.test('NP-2 GUARD: OBE volania `Validation.run` v jadre posielaju `layout: control_layout(emap)` nad tou istou mapou ABS') do
  pc = NxNp2.src('ui/production_core.rb')
  NxTest.assert_equal(2, pc.scan('Validation.run(').length)
  NxTest.assert_equal(2, pc.scan('layout: control_layout(emap)').length,
                      'jeden volajuci bez rovnakych parametrov = nalez po kliku „zmizne"')
  NxTest.assert_equal(2, pc.scan(/Validation\.run\(collected, sheets: [a-z_]+, edges: emap,/).length,
                      'hrubky ABS z TEJ ISTEJ uz nacitanej mapy (audit F3)')
  cl = NxNp2.body('ui/production_core.rb', 'control_layout')
  NxTest.assert(cl.include?('SupplierSettings.layout_params'), 'jediny zdroj parametrov')
  NxTest.refute(cl.include?('vepo_edge_thicknesses'), 'druhe citanie katalogu ABS by pri chybe zhodilo Kontrolu')
end

NxTest.test('NP-2 ProductionCore: control_payload cita orez z NASTAVENI; chyba katalogu ABS Kontrolu nezhodi (audit F3)') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  f = NxNp2
  pc = Noxun::Engine::ProductionCore
  NxNp2.with_sandbox do
    collected = { records: [f.rec] }
    NxTest.assert_equal(1, f.of(pc.control_payload(collected, sheets: f::SHEETS), 'oversize').length,
                        'predvoleny orez 10 -> 2785 sa nezmesti')
    NxTest.assert(NxNp2::SS.patch_active!('trim_mm' => 0).first)
    NxTest.assert_equal(0, f.of(pc.control_payload(collected, sheets: f::SHEETS), 'oversize').length,
                        'po ulozeni orezu 0 nalez zmizne')
    NxTest.assert(NxNp2::SS.patch_active!('trim_mm' => 10).first)
    # vyvolana chyba CITANIA katalogu ABS (nie len edges: nil)
    mat = Noxun::Engine::Materials
    orig = mat.method(:edges)
    mat.define_singleton_method(:edges) { |*_a| raise IOError, 'katalog ABS sa neda precitat' }
    begin
      out = pc.control_payload(collected, sheets: f::SHEETS)
      NxTest.assert_equal(1, f.of(out, 'oversize').length, 'rozmerova kontrola bezi dalej')
      lay = pc.control_layout(pc.edges_map)
      NxTest.assert_equal({}, lay[:edge_thicknesses])
    ensure
      mat.define_singleton_method(:edges, orig)
    end
    # Predrecenzia P3-6: zachranna vetva `control_layout` — chyba nastaveni
    # Kontrolu nezhodi; bezi s predvolenymi hodnotami a PRIZNA to.
    ss = NxNp2::SS
    orig_lp = ss.method(:layout_params)
    ss.define_singleton_method(:layout_params) { |*_a| raise IOError, 'nastavenia sa neda precitat' }
    begin
      lay = pc.control_layout({})
      NxTest.assert_equal(:seed_fallback, lay[:source])
      NxTest.assert_equal(Noxun::Engine::SheetLayout::PARAM_DEFAULTS, lay[:params])
      out = pc.control_payload(collected, sheets: f::SHEETS)
      NxTest.assert_equal(1, f.of(out, 'layout_settings').length, 'ORANGE nalez o predvolenych hodnotach')
      NxTest.assert_equal(1, f.of(out, 'oversize').length, 'Kontrola bezi s predvolenym orezom 10')
    ensure
      ss.define_singleton_method(:layout_params, orig_lp)
    end
    # oba volajuci dostanu IDENTICKE parametre z jednej funkcie
    a = pc.control_layout(nil)
    b = pc.control_layout(nil)
    NxTest.assert_equal(a, b)
    NxTest.assert_equal(:file, a[:source])
  end
end
