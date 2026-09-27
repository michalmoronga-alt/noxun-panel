# frozen_string_literal: true
# ROH-A1 · K3 — JADRO ROHOVEJ SKRINKY (blok 8, typ `corner_blind`).
# Package: SYSTEM/zdroje/bloky/ROHOVA/PACKAGE_ROHA1.md (v2, po audite navrhu).
#
# CO PLATI:
#   * novy typ `corner_blind` = dolna skrinka + rohova zostava na prednej
#     rovine: blenda korpusova, vystuha zavesov, CR 1, CR 2, rohova vystuha;
#     dvere vlavo aj vpravo (zrkadlo `x' = W − x − box[0]`, korpus sa nemeni);
#   * polia `corner_side` / `corner_door_w` / `corner_cr1` / `corner_cr2`
#     (prisne parsovanie, clamp, zapis LEN pri rohovej);
#   * ucinne hrubky CR 1/CR 2 PRED planom (celovy kanal, override, UNI = 18)
#     — ta ista mapa pre stavbu, pomocne plany aj sondy;
#   * jedny dvierka s jednym kridlom (R6), predvoleny smer pri rohu (R7),
#     medzera pri rohu 1–20, bez priecok, police za blendou `max(20, t)`;
#   * CONFIG_SCHEMA 22, BuildPlan SCHEMA 7, ABS SEED_VERSION 6.
#
# MUTACIE (overene rucne pri davke, report/PR):
#   M1 hrubka CR 2 z placeholdera namiesto sondy   -> „pomocne plany W 582"
#   M2 zrkadlo bez `− box[0]`                       -> „geometria oboch stran"
#   M3 smer R7 aj pri `unset`                        -> „smer: unset ostava"
#   M4 delenie zony povolene                          -> „delenie zon odmietnute"
#   M5 zmena strany cez sablonu povolena              -> „sablona inej strany"
#   M6 CR mimo FRONT_MATERIAL_ROLES                   -> „roly v zoznamoch"
#   M7 nova rola bez bumpu seedu ABS                  -> „ABS seed 6: merge"
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet actions_templates actions_zones payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog') unless defined?(Noxun::Engine::RulesDialog)
  # ScaleWatch (klamp sirky) — vzor `test_kona_komin.rb`: observer triedy
  # nad `Sketchup::*Observer` sa na chvilu podstrcia a hned upracu.
  unless defined?(Noxun::Engine::ScaleWatch)
    su = Module.new
    %w[EntityObserver EntitiesObserver AppObserver].each { |c| su.const_set(c, Class.new) }
    Object.const_set(:Sketchup, su)
    begin
      require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer')
    ensure
      Object.send(:remove_const, :Sketchup)
    end
  end
end

module NxRohA1
  module_function

  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  CN  = E::Construction
  BP  = E::BuildPlan
  PF  = E::PartFaces
  ABS = E::AbsRules
  BOM = E::Bom

  # DC „Rohová" (sonda 27.9.2026): 1100 x 862, sokel 150, t 18, dvere 450,
  # CR 80 + 80, medzery L 2 / P 2 (polovica DC 4) / H 5 / D 0.
  DC_FRONTS = { 'gap_top' => 5.0, 'gap_bottom' => 0.0, 'gap_left' => 2.0, 'gap_right' => 2.0 }.freeze
  KEYS = { panel: 'cabinet/corner_panel', hinge: 'cabinet/hinge_rail', cr1: 'cabinet/cr:1',
           cr2: 'cabinet/cr:2', rail: 'cabinet/corner_rail' }.freeze

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def params(over = {})
    { 'type' => 'corner_blind', 'width' => 1100.0, 'height' => 862.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 150.0, 'fronts' => DC_FRONTS.dup }.merge(over)
  end

  def cfg(over = {})
    CB.normalize(params(over))
  end

  # Pozicne argumenty (hash so string klucmi by Ruby 3 inak bral ako keywordy).
  def plan(over = {}, cid = 'CAB-001', thicknesses = nil)
    CN.build_plan(cfg(over), cid, part_thicknesses: thicknesses)
  end

  def part(pl, key)
    pl[:parts].find { |pd| pd[:part_key] == key }
  end

  def stored(over = {})
    JSON.parse(JSON.generate(CB.cabinet_config(cfg(over))))
  end

  def vec(a)
    a.map { |v| v.to_f.round(3) }
  end

  # NEZAVISLE prepisanie tabulky package (bod 3) — dvere vlavo; dvere vpravo
  # zrkadlo `x' = W − x − box[0]`. Dno pod bokmi, plny strop: z_lo = s + t,
  # z_hi = h − t.
  def expected(w:, h: 862.0, s: 150.0, t: 18.0, d:, c1:, c2:, gc:, th1: 18.0, th2: 18.0,
               gt: 5.0, gb: 0.0, side: 'left')
    z_lo = s + t
    hh = (h - t) - z_lo
    zf0 = s + gb
    hf = (h - s) - gt - gb
    rows = {
      KEYS[:panel] => [[w - t - d, t, hh], [d, 0.0, z_lo]],
      KEYS[:hinge] => [[t, 80.0, hh], [d - t, 0.0, z_lo]],
      KEYS[:cr1] => [[c1 - gc, th1, hf], [d + gc, -th1, zf0]],
      KEYS[:cr2] => [[th2, c2 - gc + th1, hf], [d + c1, -(c2 - gc + th1), zf0]],
      KEYS[:rail] => [[t, c2 + th1, h - s], [d + c1 + th2, -(c2 + th1), s]]
    }
    return rows unless side == 'right'

    rows.transform_values { |box, org| [box, [w - org[0] - box[0], org[1], org[2]]] }
  end

  def fronts_for(side, gc)
    side == 'right' ? DC_FRONTS.merge('gap_left' => gc, 'gap_right' => 2.0) : DC_FRONTS.merge('gap_right' => gc)
  end

  # Docasna nahrada katalogu (Materials.sheet) — zaznamy hrubok celoveho
  # materialu bez zasahu do sandboxu. Vzdy sa vrati povodna metoda.
  def with_sheets(map)
    mat = E::Materials
    sc = mat.singleton_class
    orig = mat.method(:sheet).unbind
    sc.send(:define_method, :sheet) { |id| map[id] }
    yield
  ensure
    sc.send(:define_method, :sheet, orig)
  end

  SHEETS = {
    'F18' => { 'material_id' => 'F18', 'thickness' => 18.0 },
    'F186' => { 'material_id' => 'F186', 'thickness' => 18.6 },
    'F19' => { 'material_id' => 'F19', 'thickness' => 19.0 },
    'F16' => { 'material_id' => 'F16', 'thickness' => 16.0 },
    'HDF3' => { 'material_id' => 'HDF3', 'thickness' => 3.0 },
    'UNI' => { 'material_id' => 'UNI', 'thickness' => 25.0, 'uni' => true }
  }.freeze

  def reset_abs_file!
    path = ABS.path
    FileUtils.rm_f(path)
    FileUtils.rm_f("#{path}.bak")
    E::JsonFileStore.invalidate(path)
  end

  def with_abs_catalog
    mat = E::Materials
    path = mat.path
    before = File.exist?(path) ? File.binread(path) : nil
    NxTest.install_legacy_catalog!
    reset_abs_file!
    yield
  ensure
    if before
      File.binwrite(path, before)
    else
      FileUtils.rm_f(path)
    end
    FileUtils.rm_f("#{path}.bak")
    E::JsonFileStore.invalidate(path)
    mat.reset_catalog_state!
    reset_abs_file!
  end

  # Vyrobny zaznam (vzor snapshotu dielca) -> `Bom.record`.
  def records(pl, owner)
    pl[:parts].map do |pd|
      res = CB.resolve_part(pd, 'K009_PW_DTDL_18', 'W1000_DTDL_18', 'HDF_WHITE_3', {})
      snap = { 'length' => pd[:prod][:length], 'width' => pd[:prod][:width],
               'thickness' => pd[:prod][:thickness], 'quantity' => 1,
               'material_id' => res[:material_id], 'edges' => res[:edges],
               'grain_direction' => res[:grain_direction] }
      BOM.record(snap, owner_id: owner, name: pd[:name], part_key: pd[:part_key], role: pd[:role])
    end
  end

  def fake_cab(cfg_hash)
    inst = NxTest::FakeInstance.new(4242)
    E::Store.write(inst, { kind: 'cabinet', cabinet_id: 'CAB-042', config: cfg_hash })
    inst
  end
end

# ============================================================================
# 1. TYP A POLIA (kontrakt)
# ============================================================================

NxTest.test('ROH-A1: typ `corner_blind` je v TYPES a normalize ho prijme (neznamy typ dalej = lower)') do
  NxTest.assert(NxRohA1::CB::TYPES.include?('corner_blind'))
  NxTest.assert_equal('corner_blind', NxRohA1.cfg[:type])
  NxTest.assert_equal('lower', NxRohA1::CB.normalize('type' => 'rohova')[:type])
  NxTest.assert_equal('corner_blind', NxRohA1::CB::CORNER_TYPE)
  NxTest.assert_equal('corner_blind', NxRohA1::CN::CORNER_TYPE)
end

NxTest.test('ROH-A1: predvolby rohovej = dolna + 1100 + jeden riadok dvierok + polia rohovej') do
  d = NxRohA1::CB::CORNER_DEFAULTS
  low = NxRohA1::CB::LOWER_DEFAULTS
  NxTest.assert_equal(1100.0, d[:width])
  %i[height depth thickness floor_height bottom_mode top_mode back_mode back_thickness plinth_mode].each do |k|
    NxTest.assert_equal(low[k], d[k], "konstrukcia ako dolna: #{k}")
  end
  NxTest.assert_equal(['door'], d[:fronts]['items'].map { |i| i['type'] })
  NxTest.assert_equal(['left', 450.0, 80.0, 80.0], d.values_at(:corner_side, :corner_door_w, :corner_cr1, :corner_cr2))
  NxTest.assert_equal(d, NxRohA1::CB.defaults_for('corner_blind'))
  c = NxRohA1::CB.normalize('type' => 'corner_blind')
  NxTest.assert_equal([1100.0, 'left', 450.0, 80.0, 80.0], c.values_at(:width, :corner_side, :corner_door_w,
                                                                       :corner_cr1, :corner_cr2))
  NxTest.assert_equal('legs', NxRohA1::CN.support_type(c), 'podpora ako dolna (nohy)')
end

NxTest.test('ROH-A1: polia rohovej — clamp, prisne parsovanie (necislo = predvolba, nie 0), strana enum') do
  cb = NxRohA1::CB
  c = cb.normalize(NxRohA1.params('corner_side' => 'hore', 'corner_door_w' => 10.0,
                                  'corner_cr1' => 999.0, 'corner_cr2' => '120'))
  NxTest.assert_equal(['left', 250.0, 250.0, 120.0], c.values_at(:corner_side, :corner_door_w, :corner_cr1, :corner_cr2))
  bad = cb.normalize(NxRohA1.params('corner_door_w' => '450oops', 'corner_cr1' => Float::NAN,
                                    'corner_cr2' => { 'x' => 1 }, 'corner_side' => 'right'))
  NxTest.assert_equal(['right', 450.0, 80.0, 80.0], bad.values_at(:corner_side, :corner_door_w, :corner_cr1, :corner_cr2),
                      'poskodena hodnota = predvolba pola')
  NxTest.assert_equal(800.0, cb.normalize(NxRohA1.params('corner_door_w' => 5000))[:corner_door_w])
  NxTest.assert_equal(50.0, cb.normalize(NxRohA1.params('corner_cr2' => -3))[:corner_cr2])
  NxTest.assert_equal({ corner_door_w: [250.0, 800.0], corner_cr1: [50.0, 250.0], corner_cr2: [50.0, 250.0] },
                      cb::CORNER_RANGES)
end

NxTest.test('ROH-A1: polia sa zapisuju LEN pri rohovej a round-trip ich drzi (prestavba, kopia, scale)') do
  st = NxRohA1.stored('corner_side' => 'right', 'corner_door_w' => 600.0, 'corner_cr1' => 120.0, 'corner_cr2' => 90.0)
  NxTest.assert_equal(['right', 600.0, 120.0, 90.0], st.values_at(*%w[corner_side corner_door_w corner_cr1 corner_cr2]))
  NxTest.assert_equal('noxun-corner-blind', st['construction_preset'])
  NxTest.assert_equal(22, st['config_schema'])
  again = NxRohA1::CB.normalize(NxRohA1::CB.config_to_params(st))
  NxTest.assert_equal(['right', 600.0, 120.0, 90.0], again.values_at(:corner_side, :corner_door_w, :corner_cr1, :corner_cr2),
                      'config -> params -> normalize nic nestrati')
  low = JSON.parse(JSON.generate(NxRohA1::CB.cabinet_config(NxRohA1::CB.normalize('type' => 'lower'))))
  NxRohA1::CB::CORNER_KEYS.each { |k| NxTest.refute(low.key?(k.to_s), "dolna nema #{k}") }
  NxTest.assert_equal('corner-blind-18', NxRohA1::CB.template_id_for('corner_blind'))
end

NxTest.test('ROH-A1: auto nazov „Rohová skrinka W" sleduje sirku (nie je rucny)') do
  cb = NxRohA1::CB
  NxTest.assert_equal('Rohová skrinka 1100', cb.default_name('type' => 'corner_blind', 'width' => 1100.0))
  NxTest.assert(cb.auto_name?('Rohová skrinka 1100', 'corner_blind'))
  NxTest.assert(cb.auto_name?('Rohova skrinka 900', 'corner_blind'), 'aj bez diakritiky')
  NxTest.assert_equal(nil, cb.sanitize_name('Rohová skrinka 1100', 'corner_blind'), 'zapeceny default sa neulozi')
  NxTest.assert_equal('Roh pri okne', cb.sanitize_name('Roh pri okne', 'corner_blind'))
  # Rohova s auto nazvom -> po zmene sirky sa premenuje podla novej sirky.
  n = cb.normalize('type' => 'corner_blind', 'width' => 900.0, 'name' => 'Rohová skrinka 1100')
  NxTest.assert_equal(nil, n[:name], 'rohova: zapeceny auto nazov sa zahodi')
  NxTest.assert_equal('Rohová skrinka 900', cb.display_name(n), 'rohova: nazov sleduje novu sirku')
end

NxTest.test('ROH-A1 (predrecenzia P3-1): rucny „Rohová skrinka N" na NEROHOVEJ skrinke sa nestrati') do
  cb = NxRohA1::CB
  %w[lower upper dishwasher].each do |t|
    NxTest.refute(cb.auto_name?('Rohová skrinka 1100', t), "#{t}: „Rohová skrinka 1100“ je rucny nazov")
    NxTest.assert_equal('Rohová skrinka 1100', cb.sanitize_name('Rohová skrinka 1100', t))
  end
  NxTest.refute(cb.auto_name?('Rohová skrinka 1100'), 'bez typu = nie je auto (bezpecna strana)')
  # Dolna zo zakazky pred K3 s rucnym nazvom -> zmena sirky -> nazov ostane.
  n = cb.normalize('type' => 'lower', 'width' => 900.0, 'name' => 'Rohová skrinka 1100')
  NxTest.assert_equal('Rohová skrinka 1100', n[:name], 'dolna: rucny nazov prezije normalize')
  NxTest.assert_equal('Rohová skrinka 1100', cb.display_name(n), 'dolna: zobrazeny nazov ostane')
  st = JSON.parse(JSON.generate(cb.cabinet_config(n)))
  NxTest.assert_equal('Rohová skrinka 1100', cb.manual_name(st), 'dolna: rucny nazov prezije ulozenie')
  # Spravanie „Horná/Spodná" sa nemeni — su automaticke na kazdom type.
  NxTest.assert(cb.auto_name?('Spodná skrinka 600', 'lower'))
  NxTest.assert(cb.auto_name?('Spodná skrinka 600', 'corner_blind'))
  NxTest.assert(cb.auto_name?('Horná skrinka 600'))
end

# ============================================================================
# 2. GEOMETRIA (tabulka package bod 3, obe strany)
# ============================================================================

NxTest.test('ROH-A1: geometria DC „Rohová" — presne cisla sondy (dvere vlavo aj vpravo)') do
  { 'left' => { panel: 450.0, hinge: 432.0, cr1: 452.0, cr2: 530.0, rail: 548.0, door: 2.0 },
    'right' => { panel: 18.0, hinge: 650.0, cr1: 570.0, cr2: 552.0, rail: 534.0, door: 652.0 } }.each do |side, xs|
    pl = NxRohA1.plan('corner_side' => side)
    xs.each do |k, x|
      pd = k == :door ? NxRohA1.part(pl, 'front:F1/wing:single') : NxRohA1.part(pl, NxRohA1::KEYS[k])
      NxTest.assert(pd, "#{side}: dielec #{k}")
      NxTest.assert_close(x, pd[:origin][0], 0.001, "#{side}: #{k} x")
    end
    NxTest.assert_equal([632.0, 18.0, 676.0], NxRohA1.vec(NxRohA1.part(pl, NxRohA1::KEYS[:panel])[:box]))
    NxTest.assert_equal([78.0, 18.0, 707.0], NxRohA1.vec(NxRohA1.part(pl, NxRohA1::KEYS[:cr1])[:box]))
    NxTest.assert_equal([18.0, 96.0, 707.0], NxRohA1.vec(NxRohA1.part(pl, NxRohA1::KEYS[:cr2])[:box]))
    NxTest.assert_equal([18.0, 98.0, 712.0], NxRohA1.vec(NxRohA1.part(pl, NxRohA1::KEYS[:rail])[:box]))
    NxTest.assert_close(-98.0, NxRohA1.part(pl, NxRohA1::KEYS[:rail])[:origin][1], 0.001)
    door = NxRohA1.part(pl, 'front:F1/wing:single')
    NxTest.assert_equal([446.0, 707.0], [door[:box][0].round(3), door[:box][2].round(3)], "#{side}: dvere 446 x 707")
  end
end

NxTest.test('ROH-A1: geometria plánu oboch strán = tabuľka package pre maticu W / D / CR / gC') do
  cases = [
    { w: 1100.0, d: 450.0, c1: 80.0, c2: 80.0, gc: 2.0 },
    { w: 900.0, d: 300.0, c1: 50.0, c2: 120.0, gc: 1.0 },
    { w: 1300.0, d: 600.0, c1: 120.0, c2: 50.0, gc: 10.0 },
    { w: 1300.0, d: 300.0, c1: 120.0, c2: 120.0, gc: 10.0 },
    { w: 900.0, d: 450.0, c1: 50.0, c2: 50.0, gc: 1.0 },
    { w: 900.0, d: 600.0, c1: 120.0, c2: 80.0, gc: 2.0 }
  ]
  n = 0
  cases.each do |c|
    %w[left right].each do |side|
      pl = NxRohA1.plan('width' => c[:w], 'corner_door_w' => c[:d], 'corner_cr1' => c[:c1], 'corner_cr2' => c[:c2],
                        'corner_side' => side, 'fronts' => NxRohA1.fronts_for(side, c[:gc]))
      NxRohA1.expected(**c, side: side).each do |key, (box, org)|
        pd = NxRohA1.part(pl, key)
        NxTest.assert(pd, "#{c.inspect}/#{side}: chyba #{key}")
        NxTest.assert_equal(NxRohA1.vec(box), NxRohA1.vec(pd[:box]), "#{c.inspect}/#{side}: #{key} box")
        NxTest.assert_equal(NxRohA1.vec(org), NxRohA1.vec(pd[:origin]), "#{c.inspect}/#{side}: #{key} origin")
        n += 1
      end
      # Dvere v otvore dverovej casti: x = x0 + lava medzera (vonku 2 pri
      # dverach vlavo, pri rohu gC pri dverach vpravo), sirka D − obe medzery.
      door = NxRohA1.part(pl, 'front:F1/wing:single')
      x0 = side == 'right' ? c[:w] - c[:d] : 0.0
      left_gap = side == 'right' ? c[:gc] : 2.0
      NxTest.assert_close(x0 + left_gap, door[:origin][0], 0.001, "#{c.inspect}/#{side}: dvere x")
      NxTest.assert(side == 'right' ? door[:origin][0] - c[:gc] >= NxRohA1.part(pl, NxRohA1::KEYS[:cr1])[:origin][0] + NxRohA1.part(pl, NxRohA1::KEYS[:cr1])[:box][0] - 1e-6
                                   : door[:origin][0] + door[:box][0] + c[:gc] <= NxRohA1.part(pl, NxRohA1::KEYS[:cr1])[:origin][0] + 1e-6,
                    "#{c.inspect}/#{side}: dvere sa s CR 1 neprekryvaju (medzera gC na kazdej strane osi)")
      NxTest.assert_close(c[:d] - 2.0 - c[:gc], door[:box][0], 0.001, "#{c.inspect}/#{side}: dvere sirka")
    end
  end
  NxTest.assert_equal(60, n, '6 kombinacii x 2 strany x 5 dielcov')
end

NxTest.test('ROH-A1: korpus rohovej je presne dolna skrinka (zrkadlo meni LEN rohovu zostavu)') do
  corner = %w[corner_blind_panel hinge_rail corner_rail cr_front cr_side]
  lo = NxRohA1::CN.build_plan(NxRohA1::CB.normalize(NxRohA1.params('type' => 'lower')), 'CAB-001')
  %w[left right].each do |side|
    pl = NxRohA1.plan('corner_side' => side)
    body = pl[:parts].reject { |pd| corner.include?(pd[:role]) || pd[:role] == 'front_door' }
    ref = lo[:parts].reject { |pd| pd[:role] == 'front_door' }
    NxTest.assert_equal(ref.map { |pd| [pd[:part_key], NxRohA1.vec(pd[:box]), NxRohA1.vec(pd[:origin])] },
                        body.map { |pd| [pd[:part_key], NxRohA1.vec(pd[:box]), NxRohA1.vec(pd[:origin])] },
                        "#{side}: boky, dno, strop, chrbat ako dolna")
  end
end

NxTest.test('ROH-A1: materialy, osi, nazvy a roly dielcov zostavy') do
  pl = NxRohA1.plan
  want = {
    NxRohA1::KEYS[:panel] => ['corner_blind_panel', :korpus, 'Blenda rohova', NxRohA1::PF::AXES_FRONT],
    NxRohA1::KEYS[:hinge] => ['hinge_rail', :korpus, 'Vystuha zavesov', NxRohA1::PF::AXES_UPRIGHT],
    NxRohA1::KEYS[:rail] => ['corner_rail', :korpus, 'Vystuha rohova', NxRohA1::PF::AXES_UPRIGHT],
    NxRohA1::KEYS[:cr1] => ['cr_front', :front, 'CR lista 1', NxRohA1::PF::AXES_FRONT],
    NxRohA1::KEYS[:cr2] => ['cr_side', :front, 'CR lista 2', NxRohA1::PF::AXES_UPRIGHT]
  }
  want.each do |key, (role, mat, name, axes)|
    pd = NxRohA1.part(pl, key)
    NxTest.assert_equal([role, mat, name, axes], [pd[:role], pd[:material], pd[:name], pd[:axes]], key)
    NxTest.assert(NxRohA1::PF.verified_axes(pd), "#{key}: osi sedia s box/prod")
  end
  NxTest.assert_equal(7, pl[:schema])
end

NxTest.test('ROH-A1: otvor ciel = dverova cast (x0 0 alebo W − D); ine typy bez zmeny') do
  cn = NxRohA1::CN
  NxTest.assert_equal({ x0: 0.0, w: 450.0, z0: 150.0, h: 712.0 }, cn.front_opening(NxRohA1.cfg))
  NxTest.assert_equal({ x0: 650.0, w: 450.0, z0: 150.0, h: 712.0 }, cn.front_opening(NxRohA1.cfg('corner_side' => 'right')))
  NxTest.assert_equal({ x0: 550.0, w: 450.0, z0: 150.0, h: 712.0 },
                      cn.front_opening(NxRohA1.cfg('corner_side' => 'right', 'width' => 1000.0)), 'viazane na pravy okraj')
  low = NxRohA1::CB.normalize(NxRohA1.params('type' => 'lower'))
  NxTest.assert_equal({ x0: 0.0, w: 1100.0, z0: 150.0, h: 712.0 }, cn.front_opening(low))
end

NxTest.test('ROH-A1: pri zmene sirky rastie LEN slepa cast (dverova cast a CR su absolutne)') do
  a = NxRohA1.plan('width' => 1100.0)
  b = NxRohA1.plan('width' => 1300.0)
  %i[hinge cr1 cr2 rail].each do |k|
    NxTest.assert_equal(NxRohA1.part(a, NxRohA1::KEYS[k])[:origin], NxRohA1.part(b, NxRohA1::KEYS[k])[:origin], "vlavo #{k}")
  end
  NxTest.assert_close(200.0, NxRohA1.part(b, NxRohA1::KEYS[:panel])[:box][0] - NxRohA1.part(a, NxRohA1::KEYS[:panel])[:box][0])
  ra = NxRohA1.plan('width' => 1100.0, 'corner_side' => 'right')
  rb = NxRohA1.plan('width' => 1300.0, 'corner_side' => 'right')
  %i[hinge cr1 cr2 rail].each do |k|
    NxTest.assert_close(200.0, NxRohA1.part(rb, NxRohA1::KEYS[k])[:origin][0] - NxRohA1.part(ra, NxRohA1::KEYS[k])[:origin][0],
                        0.001, "vpravo #{k} ide s pravym okrajom")
  end
end

# ============================================================================
# 3. UCINNE HRUBKY CR (krizovy audit C1/G2, audit A1 FIX 2)
# ============================================================================

NxTest.test('ROH-A1: hrubky CR z celoveho kanala 18 / 18,6 / 19, override CR 2, UNI a mimo rozsahu = 18') do
  NxRohA1.with_sheets(NxRohA1::SHEETS) do
    cb = NxRohA1::CB
    { 'F18' => 18.0, 'F186' => 18.6, 'F19' => 19.0, 'UNI' => 18.0, 'HDF3' => 18.0, nil => 18.0 }.each do |mid, th|
      c = NxRohA1.cfg('front_material_id' => mid)
      got = cb.corner_thicknesses(c, cb.effective_materials(nil, c))
      NxTest.assert_equal({ 'cabinet/cr:1' => th, 'cabinet/cr:2' => th }, got, "celovy #{mid.inspect}")
    end
    c = NxRohA1.cfg('front_material_id' => 'F19', 'part_overrides' => { 'cabinet/cr:2' => { 'material_id' => 'F16' } })
    got = cb.corner_thicknesses(c, cb.effective_materials(nil, c))
    NxTest.assert_equal({ 'cabinet/cr:1' => 19.0, 'cabinet/cr:2' => 16.0 }, got, 'override dielca prebije kanal')
    NxTest.assert_equal({}, cb.corner_thicknesses(cb.normalize('type' => 'lower'), {}), 'ine typy prazdna mapa')
    # Plan z tychto hrubok: CR 1 hrubka 19 v Y, CR 2 hrubka 16 v X, geometria ich pouzije.
    pl = NxRohA1.plan({ 'front_material_id' => 'F19',
                        'part_overrides' => { 'cabinet/cr:2' => { 'material_id' => 'F16' } } },
                      'CAB-001', got)
    NxRohA1.expected(w: 1100.0, d: 450.0, c1: 80.0, c2: 80.0, gc: 2.0, th1: 19.0, th2: 16.0).each do |key, (box, org)|
      pd = NxRohA1.part(pl, key)
      NxTest.assert_equal([NxRohA1.vec(box), NxRohA1.vec(org)], [NxRohA1.vec(pd[:box]), NxRohA1.vec(pd[:origin])], key)
    end
    NxTest.assert_close(19.0, NxRohA1.part(pl, NxRohA1::KEYS[:cr1])[:prod][:thickness])
    NxTest.assert_close(16.0, NxRohA1.part(pl, NxRohA1::KEYS[:cr2])[:prod][:thickness])
  end
end

NxTest.test('ROH-A1: CR nie su v materialized_part a maju toleranciu ciel v thickness_ok_for?') do
  cb = NxRohA1::CB
  pd = NxRohA1.part(NxRohA1.plan, NxRohA1::KEYS[:cr2])
  NxTest.assert_equal(pd, cb.materialized_part(pd, { sheet_thickness: 19.0 }), 'CR 2 sa po plane NEPREPISUJE')
  %w[cr_front cr_side].each do |role|
    [18.0, 18.6, 19.0, 25.0].each { |th| NxTest.assert(cb.thickness_ok_for?(role, 18.0, th), "#{role} #{th}") }
    NxTest.refute(cb.thickness_ok_for?(role, 18.0, 3.0), "#{role}: 3 mm nie je celovy material")
  end
  %w[corner_blind_panel hinge_rail corner_rail].each do |role|
    NxTest.refute(cb.thickness_ok_for?(role, 18.0, 19.0), "#{role}: korpus = presna zhoda")
  end
  # Ziadny druhy vypocet hrubky: stavba ide cez JEDNU mapu.
  body = NxRohA1.src('noxun_engine', 'core', 'cabinet_builder.rb')[/def build_into.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('part_thicknesses: plan_thicknesses(cfg, eff)'), 'stavba ide cez JEDNU mapu hrubok')
end

NxTest.test('ROH-A1 (audit A1 FIX 2): pomocne plany s CR 2 16 mm pri W 582 (ABS remap aj sondy)') do
  NxRohA1.with_sheets(NxRohA1::SHEETS) do
    cb = NxRohA1::CB
    cn = NxRohA1::CN
    p582 = NxRohA1.params('width' => 582.0, 'part_overrides' => { 'cabinet/cr:2' => { 'material_id' => 'F16' } })
    th = cb.aux_part_thicknesses(p582, nil)
    NxTest.assert_equal({ 'cabinet/cr:1' => 18.0, 'cabinet/cr:2' => 16.0 }, th)
    keys = cb.plan_parts_by_key(p582).keys
    NxTest.assert(keys.include?('cabinet/cr:2') && keys.include?('cabinet/side:left'),
                  "premapovanie ABS vidi dielce (#{keys.length})")
    c = cb.normalize(p582)
    NxTest.assert_equal(582.0, cn.min_valid_width(c, part_thicknesses: th), 'sonda sirky = skutocna stavba')
    NxTest.assert_equal(584.0, cn.min_valid_width(c), 's placeholderom 18 by sonda vratila 584')
    NxTest.assert(cn.min_valid_height(c, part_thicknesses: th) < 862.0, 'sonda vysky nad W 582 prejde')
    NxTest.assert_equal(150.0, cn.min_valid_depth(c, part_thicknesses: th), 'sonda hlbky nad W 582 prejde')
    NxTest.assert_raise('nezmestí') { cn.build_plan(c) }
  end
  scale = NxRohA1.src('noxun_engine', 'core', 'scale_observer.rb')
  absorb = scale[/def absorb\(inst\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(absorb.include?('CabinetBuilder.aux_part_thicknesses(params, model)'), 'absorpcia pocita hrubky RAZ')
  %w[clamp_corner_width(params, new_w, cid, th) clamp_depth(params, new_d, cid, th)
     clamp_height(params, (base_h * sz).round.to_f, cid, th)].each do |call|
    NxTest.assert(absorb.include?(call), "sonda dostava hrubky: #{call}")
  end
end

# ============================================================================
# 4. ODMIETNUTIA (validate! + akcie panela)
# ============================================================================

NxTest.test('ROH-A1: medzera pri rohu 1–20 mm (0 / −10 / 25 odmietnute v stavbe, 1 a 20 prejdu)') do
  %w[left right].each do |side|
    [0.0, -10.0, 25.0].each do |gc|
      NxTest.assert_raise('Medzera dverí pri rohu musí byť 1–20 mm.') do
        NxRohA1.plan('corner_side' => side, 'fronts' => NxRohA1.fronts_for(side, gc))
      end
    end
    [1.0, 20.0].each { |gc| NxRohA1.plan('corner_side' => side, 'fronts' => NxRohA1.fronts_for(side, gc)) }
  end
  # Vonkajsia medzera ostava volna (aj presah).
  NxRohA1.plan('fronts' => NxRohA1::DC_FRONTS.merge('gap_left' => -10.0))
end

NxTest.test('ROH-A1: rohova zostava sa musi zmestit (D + c1 + th2 + t <= W − t)') do
  NxTest.assert_raise('Rohová zostava sa do šírky 583 mm nezmestí') { NxRohA1.plan('width' => 583.0) }
  NxRohA1.plan('width' => 584.0)
  NxTest.assert_raise('aspoň 804 mm') do
    NxRohA1.plan('width' => 800.0, 'corner_door_w' => 600.0, 'corner_cr1' => 150.0)
  end
end

NxTest.test('ROH-A1 (C4): vystuha zavesov pred chrbtom — komin 85 + vlozeny chrbat 18 zdvihne min. hlbku') do
  over = { 'back_setback' => 85.0, 'back_mode' => 'inset', 'back_thickness' => 18.0 }
  NxTest.assert_raise('Výstuha závesov (80 mm)') { NxRohA1.plan(over.merge('depth' => 170.0)) }
  NxTest.assert_equal(183.0, NxRohA1::CN.min_valid_depth(NxRohA1.cfg(over)), '85 + 18 + 80 = 183')
  low = NxRohA1::CB.normalize(NxRohA1.params(over.merge('type' => 'lower')))
  NxTest.assert_equal(150.0, NxRohA1::CN.min_valid_depth(low), 'dolnej sa minimum nemeni')
end

NxTest.test('ROH-A1 (R6): cela — normalize vynuti jeden riadok dvierok, stavba odmietne poruseny config') do
  cb = NxRohA1::CB
  c = NxRohA1.cfg('fronts' => { 'items' => [{ 'id' => 'Fx7', 'type' => 'drawer_front' },
                                            { 'id' => 'Fd2', 'type' => 'door', 'mode' => 'fixed', 'height' => 300.0,
                                              'wings' => '2', 'profile' => 'ukw7', 'direction' => 'left' },
                                            { 'id' => 'F3', 'type' => 'door' }] })
  it = c[:fronts]['items']
  NxTest.assert_equal(1, it.length)
  NxTest.assert_equal(%w[Fd2 door auto 1 left], [it[0]['id'], it[0]['type'], it[0]['mode'], it[0]['wings'], it[0]['direction']],
                      'ostane PRVY riadok door (ID, smer zachovane), vynuti auto + 1 kridlo')
  NxTest.assert_equal(nil, it[0]['height'])
  none = NxRohA1.cfg('fronts' => { 'items' => [] })
  NxTest.assert_equal(%w[F1 door], none[:fronts]['items'].map { |i| i.values_at('id', 'type') }.flatten, 'chybajuce = F1')
  NxTest.assert(NxRohA1.cfg[:fronts]['items'].first.key?('direction'), 'nova rohova dostane smer (R7)')
  # Otvor 700 (dverova cast 700) by pri `wings auto` dal 2 kridla — invariant drzi 1.
  wide = NxRohA1.plan('corner_door_w' => 700.0)
  NxTest.assert_equal(1, wide[:parts].count { |pd| pd[:role] == 'front_door' }, 'jedno kridlo aj pri 700')
  # Config mimo normalize (sablona, rucny zasah) stavba ODMIETNE.
  [[{ 'id' => 'F1', 'type' => 'door' }, { 'id' => 'F2', 'type' => 'door' }],
   [{ 'id' => 'F1', 'type' => 'drawer_front' }],
   [{ 'id' => 'F1', 'type' => 'door', 'wings' => '2' }],
   [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 400.0 }]].each do |items|
    bad = NxRohA1.cfg
    bad[:fronts] = bad[:fronts].merge('items' => Noxun::Engine::Fronts.normalize_items(items))
    NxTest.assert_raise('jedny dvierka') { NxRohA1::CN.build_plan(bad, 'CAB-001') }
    NxTest.assert_equal(Noxun::Engine::Construction::CORNER_FRONTS_MSG,
                        Noxun::Engine::Panel.corner_fronts_refusal({ 'type' => 'corner_blind' },
                                                                   { 'items' => items }),
                        "akcie ciel odmietnu #{items.inspect}")
  end
  NxTest.assert(cb.corner_fronts_ok?(NxRohA1.cfg[:fronts]))
end

NxTest.test('ROH-A1 (R6): akcie ciel — povolene zmeny prejdu, medzera pri rohu mimo rozsahu nie') do
  pan = Noxun::Engine::Panel
  st = { 'type' => 'corner_blind', 'corner_side' => 'left' }
  ok = { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1',
                       'direction' => 'left', 'profile' => 'ukw7' }], 'gap_right' => 3.0, 'gap_top' => 4.0 }
  NxTest.assert_equal(nil, pan.corner_fronts_refusal(st, ok), 'smer, profil, medzery v rozsahu')
  NxTest.assert_equal(Noxun::Engine::Construction::CORNER_GAP_MSG,
                      pan.corner_fronts_refusal(st, ok.merge('gap_right' => 0.0)))
  NxTest.assert_equal(nil, pan.corner_fronts_refusal(st, ok.merge('gap_left' => -5.0)), 'vonkajsia medzera volna')
  NxTest.assert_equal(Noxun::Engine::Construction::CORNER_GAP_MSG,
                      pan.corner_fronts_refusal(st.merge('corner_side' => 'right'), ok.merge('gap_left' => 25.0)),
                      'pri dverach vpravo je rohova medzera `gap_left`')
  NxTest.assert_equal(nil, pan.corner_fronts_refusal({ 'type' => 'lower' }, { 'items' => [] }), 'dolna bez zmeny')
end

NxTest.test('ROH-A1 (R6, C2): delenie zon rohovej odmietnute (stavba aj akcia zon)') do
  split = { 'split' => { 'axis' => 'v', 'count' => 2 }, 'children' => [{}, {}] }
  NxTest.assert_raise('bez priečok') { NxRohA1.plan('zone_tree' => split) }
  NxTest.assert_raise('bez priečok') { NxRohA1.plan('zone_tree' => split.merge('split' => { 'axis' => 'h', 'count' => 2 })) }
  NxRohA1.plan('zone_tree' => { 'shelves' => 3 }) # police su v poriadku
  cab = NxRohA1.fake_cab(NxRohA1.stored)
  msg = Noxun::Engine::Panel.split_refusal({ cab: cab, path: [1], cabinet_id: 'CAB-042', zone_id: 'CAB-042-Z1' })
  NxTest.assert_equal(Noxun::Engine::Construction::CORNER_ZONES_MSG, msg)
end

# ============================================================================
# 5. POLICE (audit A1 BLOCKER 1) A ORANGE VYREZ
# ============================================================================

NxTest.test('ROH-A1 (BLOCKER 1): polica nepretina blendu — odsadenie max(20, t) pri t 18 / 25 / 36, obe strany') do
  [18.0, 25.0, 36.0].each do |t|
    %w[left right].each do |side|
      pl = NxRohA1.plan('thickness' => t, 'corner_side' => side, 'zone_tree' => { 'shelves' => 2 })
      blend = NxRohA1.part(pl, NxRohA1::KEYS[:panel])
      shelves = pl[:parts].select { |pd| pd[:role] == 'shelf' }
      NxTest.assert_equal(2, shelves.length, "t #{t}/#{side}: 2 police")
      shelves.each do |sh|
        NxTest.assert(sh[:origin][1] >= blend[:origin][1] + blend[:box][1] - 1e-6,
                      "t #{t}/#{side}: polica (y #{sh[:origin][1]}) za blendou (#{blend[:box][1]})")
        NxTest.assert_close([20.0, t].max, sh[:origin][1], 1e-6, "t #{t}: odsadenie")
      end
    end
  end
  # Dolna skrinka pri t 25 ostava na 20 (golden plan sa nehne).
  low = NxRohA1::CN.build_plan(NxRohA1::CB.normalize(NxRohA1.params('type' => 'lower', 'thickness' => 25.0,
                                                                    'zone_tree' => { 'shelves' => 1 })), 'CAB-1')
  NxTest.assert_close(20.0, low[:parts].find { |pd| pd[:role] == 'shelf' }[:origin][1], 1e-9)
end

NxTest.test('ROH-A1: ORANGE „výrez robí dielňa" pri policiach rohovej (jeden na skrinku), bez polic nic') do
  pl = NxRohA1.plan('zone_tree' => { 'shelves' => 3 })
  w = pl[:warnings].select { |x| x['code'] == 'corner_shelf_notch' }
  NxTest.assert_equal(1, w.length)
  NxTest.assert_equal('Polica prechádza výstuhou závesov — výrez 18 × 60 mm robí dielňa.', w.first['message'])
  NxTest.assert_equal('cabinet/hinge_rail', w.first['part_key'])
  NxTest.assert_equal([], NxRohA1.plan[:warnings].select { |x| x['code'] == 'corner_shelf_notch' })
  t25 = NxRohA1.plan('thickness' => 25.0, 'zone_tree' => { 'shelves' => 1 })[:warnings].find { |x| x['code'] == 'corner_shelf_notch' }
  NxTest.assert(t25['message'].include?('25 × 55 mm'), t25['message'])
  res = Noxun::Engine::Validation.run({ warnings: [w.first.merge('owner_id' => 'CAB-001')] })
  NxTest.assert_equal(['orange'], res['items'].map { |i| i['severity'] }, 'Kontrola: ORANGE')
end

# ============================================================================
# 6. SMER PANTOV (R7) — jedina vynimka z O1
# ============================================================================

NxTest.test('ROH-A1 (R7): chybajuci smer = pri rohu (vlavo -> panty vpravo, vpravo -> vlavo); unset/left/right sa nemenia') do
  NxTest.assert_equal('right', NxRohA1.cfg[:fronts]['items'].first['direction'], 'dvere vlavo: panty pri rohu vpravo')
  NxTest.assert_equal('left', NxRohA1.cfg('corner_side' => 'right')[:fronts]['items'].first['direction'])
  %w[unset left right].each do |dir|
    %w[left right].each do |side|
      c = NxRohA1.cfg('corner_side' => side,
                      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'direction' => dir }] })
      NxTest.assert_equal(dir, c[:fronts]['items'].first['direction'], "#{side}: vedoma volba #{dir} ostava")
    end
  end
  # Dolna skrinka smer NIKDY nedostane (O1).
  low = NxRohA1::CB.normalize('type' => 'lower', 'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door' }] })
  NxTest.refute(low[:fronts]['items'].first.key?('direction'), 'dolna: ziadny default smeru')
end

NxTest.test('ROH-A1 (R7) PIN: jedina heuristika smeru v plugine — `CORNER_HINGE_SIDE` cez `corner_hinge_side` len v `corner_fronts!`') do
  root = File.join(NxTest::ROOT, 'noxun_engine')
  files = Dir[File.join(root, '**', '*.rb')] + Dir[File.join(root, 'ui', 'js', '*.js')]
  users = files.select { |p| File.read(p, encoding: 'UTF-8').match?(/CORNER_HINGE_SIDE|corner_hinge_side/) }
               .map { |p| p.sub("#{root}/", '') }
  NxTest.assert_equal(['core/cabinet_builder.rb'], users, 'heuristika zije v JEDNOM subore')
  cb = NxRohA1.src('noxun_engine', 'core', 'cabinet_builder.rb')
  NxTest.assert_equal(2, cb.scan(/corner_hinge_side\(/).length, 'definicia + JEDINE volanie')
  body = cb[/def corner_fronts!\(fronts_cfg, side\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?("item['direction'] = corner_hinge_side(side) unless item.key?('direction')"),
                'doplni sa LEN chybajuci kluc')
  NxTest.assert_equal({ 'left' => 'right', 'right' => 'left' }, NxRohA1::CB::CORNER_HINGE_SIDE)
end

# ============================================================================
# 7. OCHRANY — typ, strana, sablony, vlozenie zo sablony
# ============================================================================

NxTest.test('ROH-A1 (G1, C5): zmena typu z/na rohovu a strany rohovej je odmietnuta; bez poli sa hodnoty drzia') do
  pan = Noxun::Engine::Panel
  corner = NxRohA1::CB.config_to_params(NxRohA1.stored('corner_door_w' => 500.0))
  NxTest.assert_equal(pan::CORNER_TYPE_MSG, pan.corner_change_refusal(corner, { 'type' => 'lower' }))
  NxTest.assert_equal(pan::CORNER_TYPE_MSG, pan.corner_change_refusal({ 'type' => 'lower' }, { 'type' => 'corner_blind' }))
  NxTest.assert_equal(nil, pan.corner_change_refusal({ 'type' => 'lower' }, { 'type' => 'upper' }), 'dolna/horna ako doteraz')
  NxTest.assert_equal(pan::CORNER_SIDE_MSG, pan.corner_change_refusal(corner, { 'corner_side' => 'right' }))
  NxTest.assert_equal(nil, pan.corner_change_refusal(corner, { 'corner_side' => 'left', 'type' => 'corner_blind' }))
  # handle_apply: panel polia rohovej NEPOSIELA (C6) -> ulozene ostanu (D 500 ostane 500).
  data = { 'type' => 'corner_blind', 'width' => 1200.0 }
  params = corner.dup
  pan::PARAM_KEYS.each { |k| params[k] = data[k] if data.key?(k) }
  c = NxRohA1::CB.normalize(params)
  NxTest.assert_equal([1200.0, 500.0, 'left'], c.values_at(:width, :corner_door_w, :corner_side))
  NxTest.assert(%w[corner_side corner_door_w corner_cr1 corner_cr2].all? { |k| pan::PARAM_KEYS.include?(k) })
  src = NxRohA1.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  body = src[/def handle_apply\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(body.index('corner_change_refusal') < body.index('PARAM_KEYS.each'), 'odmietnutie PRED prepisom')
  all = src[/def handle_apply_all\(payload\).*?\n        ensure\n/m].to_s
  NxTest.assert(all.include?('corner_fronts_refusal') && all.include?('corner_change_refusal'), 'auto-apply chranene')
  NxTest.assert(src[/def handle_apply_fronts\(payload\).*?\n        end\n/m].to_s.include?('corner_fronts_refusal'))
end

NxTest.test('ROH-A1: sablona rohovej — typ zamknuty, ina strana a poruseny invariant odmietnute, rovnaka strana prejde') do
  pan = Noxun::Engine::Panel
  td = Noxun::Engine::TemplatesDialog
  cfg = { 'type' => 'corner_blind' }
  NxTest.assert_equal('', pan.apply_template_type!(cfg, 'lower'))
  NxTest.assert_equal('corner_blind', cfg['type'], '„Uložiť ako šablónu" typ rohovej neprepne')
  cab = NxRohA1.stored
  tpl = pan.template_config_from(cab)
  NxTest.assert_equal(%w[left 450.0 80.0 80.0], tpl.values_at(*%w[corner_side corner_door_w corner_cr1 corner_cr2]).map(&:to_s))
  NxTest.assert_equal(nil, td.corner_template_apply_refusal(cab, tpl), 'rovnaka strana prejde')
  NxTest.assert_equal(pan::CORNER_SIDE_MSG, td.corner_template_apply_refusal(cab, tpl.merge('corner_side' => 'right')))
  bad = tpl.merge('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door' }, { 'id' => 'F2', 'type' => 'door' }] })
  NxTest.assert(td.corner_template_apply_refusal(cab, bad).to_s.include?('jedny dvierka'))
  # Merge: chybajuci kluc = hodnota ciela.
  target = NxRohA1::CB.config_to_params(NxRohA1.stored('corner_cr2' => 120.0))
  merged = td.merge_template(target, tpl.reject { |k, _| k == 'corner_cr2' })
  NxTest.assert_equal(120.0, merged['corner_cr2'], 'stara sablona bez kluca necha CR 2 ciela')
  NxTest.assert_equal(80.0, td.merge_template(target, tpl)['corner_cr2'], 'sablona s klucom ho prepise')
  low = pan.template_config_from(JSON.parse(JSON.generate(NxRohA1::CB.cabinet_config(NxRohA1::CB.normalize('type' => 'lower')))))
  NxRohA1::CB::CORNER_KEYS.each { |k| NxTest.refute(low.key?(k.to_s), "sablona dolnej bez #{k}") }
end

NxTest.test('ROH-A1 (audit A1 FIX 3): sablona uložiť -> vložiť nesie vpravo / 600 / 120 / 90') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  ts = Noxun::Engine::TemplateStore
  pan = Noxun::Engine::Panel
  name = '__ROHA1_TEST_SABLONA__'
  src = NxRohA1.stored('corner_side' => 'right', 'corner_door_w' => 600.0, 'corner_cr1' => 120.0, 'corner_cr2' => 90.0,
                       'width' => 1300.0)
  begin
    ts.delete('cabinet', name) if ts.find('cabinet', name)
    ts.upsert('cabinet', name, pan.template_config_from(src))
    # Formular polia rohovej neposiela — vkladaci payload ma len beznu konstrukciu.
    params = { 'type' => 'corner_blind', 'width' => 1300.0, 'height' => 862.0, 'depth' => 510.0,
               'thickness' => 18.0, 'floor_height' => 150.0 }
    pan.apply_template_slot_fields!(params, ['cabinet', name])
    c = NxRohA1::CB.normalize(params)
    NxTest.assert_equal(['corner_blind', 'right', 600.0, 120.0, 90.0],
                        c.values_at(:type, :corner_side, :corner_door_w, :corner_cr1, :corner_cr2))
    NxTest.assert_equal(nil, pan.corner_template_refusal(['cabinet', name]), 'zdrava sablona sa nevkladanie neodmieta')
    # Sablona s porusenym invariantom sa ODMIETNE (nie ticho oreze).
    rec = ts.find('cabinet', name)['config']
    ts.upsert('cabinet', name, rec.merge('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front' }] }))
    NxTest.assert(pan.corner_template_refusal(['cabinet', name]).to_s.include?('jedny dvierka'))
  ensure
    ts.delete('cabinet', name) if ts.find('cabinet', name)
  end
  body = NxRohA1.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')[/def handle_insert\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(body.index('apply_template_slot_fields!') < body.index('corner_template_refusal') &&
                body.index('corner_template_refusal') < body.index('prepare_insert'), 'kontrola PRED ghostom')
end

NxTest.test('ROH-A1: kopie (panel, Mower, natívna) prenasaju polia cez config_to_params') do
  %w[noxun_engine/ui/panel/actions_cabinet.rb noxun_engine/tools/mower.rb noxun_engine/core/cabinet_builder.rb].each do |rel|
    NxTest.assert(NxRohA1.src(*rel.split('/')).include?('config_to_params'), "#{rel}: kopia ide cez config_to_params")
  end
  params = NxRohA1::CB.config_to_params(NxRohA1.stored('corner_side' => 'right', 'corner_cr1' => 60.0))
  NxRohA1::CB.rekey_hardware_manual(params)
  NxRohA1::CB.strip_appliance_refs!(params)
  NxTest.assert_equal(['right', 60.0], NxRohA1::CB.normalize(params).values_at(:corner_side, :corner_cr1))
end

# ============================================================================
# 8. PREFLIGHT OTVORU CIEL (audit A1 NOTE 5)
# ============================================================================

NxTest.test('ROH-A1 (NOTE 5): serverovy preflight otvoru — rohova so zivou sirkou a ulozenou stranou; ostatne bez zmeny') do
  pan = Noxun::Engine::Panel
  fronts = { 'gap' => 3.0, 'gap_top' => 5.0, 'gap_bottom' => 0.0, 'gap_left' => 2.0, 'gap_right' => 2.0,
             'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1', 'direction' => 'right' }] }
  data = { 'type' => 'corner_blind', 'width' => 1200.0, 'height' => 862.0, 'floor_height' => 150.0,
           'fronts' => fronts, 'revision' => 1 }
  %w[left right].each do |side|
    stored = NxRohA1.stored('corner_side' => side)
    res = pan.front_preflight_result(data, stored)
    NxTest.assert_equal(true, res['valid'], "#{side}: #{res['errors'].inspect}")
    NxTest.assert_equal(1, res['items'].first['wings_n'], "#{side}: otvor 450 = 1 kridlo")
    res2 = pan.front_preflight_result(data.merge('fronts' => fronts.merge(side == 'right' ? { 'gap_left' => 0.0 } : { 'gap_right' => 0.0 })), stored)
    NxTest.assert_equal(false, res2['valid'], "#{side}: medzera pri rohu 0 odmietnuta")
  end
  # Otvor 450 pri zivej sirke 1200 vpravo = x0 750 (Construction.front_opening).
  op = pan.preflight_opening_cfg(data, NxRohA1.stored('corner_side' => 'right'), [1200.0, 862.0, 150.0])
  NxTest.assert_equal({ x0: 750.0, w: 450.0, z0: 150.0, h: 712.0 }, NxRohA1::CN.front_opening(op))
  # Dolna skrinka: otvor cez celu sirku (tie iste cisla ako predtym bez `opening`).
  low = data.merge('type' => 'lower', 'width' => 700.0,
                   'fronts' => fronts.merge('items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => 'auto' }]))
  NxTest.assert_equal(2, pan.front_preflight_result(low)['items'].first['wings_n'], 'dolna 700 = 2 kridla ako doteraz')
  NxTest.assert_equal(pan.front_preflight_result(low)['items'],
                      Noxun::Engine::Fronts.preflight(low['fronts'], 700.0, 862.0, 150.0)['items'],
                      'dolna: vysledok zhodny s preflightom bez otvoru')
end

# ============================================================================
# 9. ROLY VO VSETKYCH ZOZNAMOCH + ABS SEED 6
# ============================================================================

NxTest.test('ROH-A1: nove roly prechadzaju vsetkymi uzavretymi zoznamami') do
  e = Noxun::Engine
  roles = e::Construction::CORNER_ROLES
  NxTest.assert_equal(%w[corner_blind_panel hinge_rail cr_front cr_side corner_rail], roles)
  roles.each do |r|
    NxTest.assert(e::BuildPlan::ROLES.include?(r), "BuildPlan::ROLES #{r}")
    NxTest.assert(e::AbsRules::EDGE_LABELS.key?(r), "EDGE_LABELS #{r}")
    NxTest.assert(e::AbsRules::SEED_RULES.key?(r), "SEED_RULES #{r}")
    NxTest.assert(e::PartFaces::ROLE_AXES.key?(r), "ROLE_AXES #{r}")
    NxTest.refute(e::PartFaces::STANDING_ROLES.include?(r), "#{r}: nie je stojaca (neobracia L1/L2)")
    NxTest.refute(e::ProductionCore.role_label(r) == r, "ROLE_LABELS #{r}")
    NxTest.assert(e::RulesDialog::ABS_ROLE_ORDER.include?(r), "ABS_ROLE_ORDER #{r}")
  end
  %w[cr_front cr_side].each do |r|
    NxTest.assert(e::Construction::FRONT_MATERIAL_ROLES.include?(r), "#{r}: celovy kanal (R4)")
    NxTest.assert_equal('F', e::CabinetBuilder.base_material_for(r, :korpus, 'B', 'F', 'Z'), "#{r}: celovy material")
    NxTest.assert(e::Validation::FRONT_ROLES.include?(r), "#{r}: ORANGE bez ABS")
    NxTest.assert(e::CpExport::FRONT_ROLES.include?(r), "#{r}: v ponuke dvierka")
    NxTest.assert_equal('Noxun/Čelá', e::CabinetBuilder::PART_TAGS[r])
    NxTest.refute(e::HardwareRules::FRONT_ROLES.include?(r), "#{r}: nie je celo pre vysuvy")
  end
  %w[corner_blind_panel hinge_rail corner_rail].each do |r|
    NxTest.refute(e::Construction::FRONT_MATERIAL_ROLES.include?(r), "#{r}: korpus (blenda VZDY z korpusu)")
    NxTest.assert_equal('B', e::CabinetBuilder.base_material_for(r, :korpus, 'B', 'F', 'Z'))
    NxTest.assert_equal(nil, e::CabinetBuilder::PART_TAGS[r], "#{r}: tag Korpus (default)")
  end
  NxTest.assert_equal('dvierka', e::CpExport.material_category({ 'type' => 'DTDL' }, 'cr_side'), 'CR v ponuke = dvierka')
  NxTest.assert_equal('vnutorne_korpusy', e::CpExport.material_category({ 'type' => 'DTDL' }, 'hinge_rail'))
end

NxTest.test('ROH-A1: ABS — labely, seed podla DC a edge_sides (CR 1 a blenda = celna mapa, audit A1 FIX 4)') do
  ar = Noxun::Engine::AbsRules
  NxTest.assert_equal({}, ar::SEED_RULES['corner_blind_panel'])
  NxTest.assert_equal({ 'L2' => 1.0 }, ar::SEED_RULES['hinge_rail'])
  NxTest.assert_equal({ 'L1' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, ar::SEED_RULES['corner_rail'])
  %w[cr_front cr_side].each do |r|
    NxTest.assert_equal({ 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, ar::SEED_RULES[r], "#{r} dookola")
  end
  %w[cr_front corner_blind_panel].each do |r|
    NxTest.assert_equal(ar::EDGE_SIDES_FRONT, ar.edge_sides(r), "#{r}: L1 vlavo, W2 hore")
    NxTest.assert_equal({ 'L1' => 'Ľavá', 'L2' => 'Pravá', 'W1' => 'Dolná', 'W2' => 'Horná' }, ar.edge_labels(r))
  end
  %w[hinge_rail corner_rail cr_side].each do |r|
    NxTest.assert_equal(ar::EDGE_SIDES_LYING, ar.edge_sides(r), "#{r}: ako bok")
    NxTest.assert_equal({ 'L1' => 'Predná', 'L2' => 'Zadná', 'W1' => 'Dolná', 'W2' => 'Horná' }, ar.edge_labels(r))
  end
  # Suhlas fyzickej hrany, popisku a strany karty: CR 1 L1 = plocha na min X = „Ľavá" = 'left'.
  pl = NxRohA1.plan
  cr1 = NxRohA1.part(pl, NxRohA1::KEYS[:cr1])
  ax = Noxun::Engine::PartFaces.verified_axes(cr1)
  NxTest.assert_equal([0, :min], Noxun::Engine::PartFaces.rect_axis_side('L1', ax, 'cr_front'), 'L1 = min X')
  NxTest.assert_equal([2, :max], Noxun::Engine::PartFaces.rect_axis_side('W2', ax, 'cr_front'), 'W2 = vrch')
  rail = NxRohA1.part(pl, NxRohA1::KEYS[:rail])
  NxTest.assert_equal([1, :min], Noxun::Engine::PartFaces.rect_axis_side('L1', Noxun::Engine::PartFaces.verified_axes(rail), 'corner_rail'),
                      'rohova vystuha L1 = predna (min Y)')
  hinge = NxRohA1.part(pl, NxRohA1::KEYS[:hinge])
  NxTest.assert_equal([1, :max], Noxun::Engine::PartFaces.rect_axis_side('L2', Noxun::Engine::PartFaces.verified_axes(hinge), 'hinge_rail'),
                      'vystuha zavesov L2 = zadna (viditelna zvnutra)')
end

NxTest.test('ROH-A1: ABS seed 6 — merge doplni roly rohovej na existujucom PC, vlastne pravidla ostanu') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  abs = NxRohA1::ABS
  NxTest.assert_equal(6, abs::SEED_VERSION)
  NxRohA1.reset_abs_file!
  corner = Noxun::Engine::Construction::CORNER_ROLES
  custom = abs::SEED_RULES.reject { |r, _| corner.include?(r) }.merge('shelf' => { 'L1' => 2.0 })
  Noxun::Engine::JsonFileStore.write(abs.path, { 'std' => 1, 'seed_version' => 5, 'rules' => custom })
  Noxun::Engine::JsonFileStore.invalidate(abs.path)
  got = abs.load
  corner.each { |r| NxTest.assert_equal(abs::SEED_RULES[r], got[r], "#{r} doplnena") }
  NxTest.assert_equal({ 'L1' => 2.0 }, got['shelf'], 'vlastne pravidlo ostalo')
  NxTest.assert_equal(6, Noxun::Engine::JsonFileStore.read(abs.path)['seed_version'])
  NxRohA1.reset_abs_file!
end

# ============================================================================
# 10. VYSTUPY — KUSOVNIK, VEPO, KOVANIE
# ============================================================================

NxTest.test('ROH-A1: kusovnik a VEPO — dielce zostavy, CR z celoveho s ABS dookola, nazvy <= 20') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  NxRohA1.with_abs_catalog do
    vepo = Noxun::Engine::VepoExport
    pl = NxRohA1.plan({}, 'CAB-021')
    recs = NxRohA1.records(pl, 'CAB-021')
    by_name = ->(n) { recs.find { |r| r['name'] == n } }
    cr1 = by_name.call('CR lista 1')
    NxTest.assert_equal('W1000_DTDL_18', cr1['material_id'], 'CR z celoveho kanala')
    NxTest.assert(%w[L1 L2 W1 W2].all? { |c| !cr1['edges'][c].nil? }, "CR 1 dookola #{cr1['edges'].inspect}")
    bl = by_name.call('Blenda rohova')
    NxTest.assert_equal('K009_PW_DTDL_18', bl['material_id'], 'blenda z korpusu')
    NxTest.assert(bl['edges'].values.all?(&:nil?), 'blenda bez ABS')
    hr = by_name.call('Vystuha zavesov')
    NxTest.assert_equal([nil, 'ABS_K009_10', nil, nil], hr['edges'].values_at('L1', 'L2', 'W1', 'W2'), 'vystuha zavesov L2')
    rows = NxRohA1::BOM.aggregate_rows(recs)
    names = rows.map { |r| vepo.row_name(r) }
    names.each { |n| NxTest.assert(n.length <= vepo::NAME_MAX, "VEPO #{n.inspect} <= 20") }
    %w[Blenda\ roh Vyst\ zav Vyst\ roh].each do |short|
      NxTest.assert(names.any? { |n| n.start_with?(short) }, "VEPO skratka #{short} (#{names.inspect})")
    end
    NxTest.assert(names.any? { |n| n.start_with?('CR 1') }, "CR vo VEPO (#{names.inspect})")
  end
  { 'Blenda rohova' => 'Blenda roh', 'Vystuha zavesov' => 'Vyst zav', 'Vystuha rohova' => 'Vyst roh',
    'CR lista 1' => 'CR 1', 'CR lista 2' => 'CR 2' }.each do |full, short|
    NxTest.assert_equal(short, Noxun::Engine::VepoExport.short_name(full))
  end
  NxTest.assert(NxRohA1.src('SYSTEM', 'VEPO_KONTRAKT.md').include?('Vyst zav'), 'VEPO_KONTRAKT menuje skratky rohovej')
end

NxTest.test('ROH-A1 (R5): kovanie ako dolna — nohy 6 pri 1100, zavesy 2 na dvierkach, nic na rohovej zostave') do
  pl = NxRohA1.plan
  hw = pl[:hardware]
  legs = hw.select { |h| h['generic_type'] == 'leg' }.sum { |h| h['quantity'].to_i }
  NxTest.assert_equal(6, legs, 'nohy podla sirky 1100')
  hinges = hw.select { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal([['front:F1/wing:single', 2]], hinges.map { |h| [h['owner_part_key'], h['quantity']] },
                      'zavesy len na dvierkach 707 mm')
  NxTest.refute(hw.any? { |h| h['generic_type'] == 'wall_hanger' }, 'Bystrica len hornej')
  NxTest.refute(hw.any? { |h| h['owner_part_key'].to_s.start_with?('cabinet/cr', 'cabinet/corner', 'cabinet/hinge') },
                'rohova zostava kovanie nema (ziadny rohovy mechanizmus)')
  NxTest.assert_equal(4, NxRohA1.plan('width' => 900.0)[:hardware].select { |h| h['generic_type'] == 'leg' }.sum { |h| h['quantity'].to_i })
end

# ============================================================================
# 11. SCHEMY, SCALE, REGISTRE
# ============================================================================

NxTest.test('ROH-A1: schemy CONFIG 22 · BuildPlan 7 · ABS seed 6 (+ HISTORIA), STD sablon sa nemeni') do
  cb = NxRohA1::CB
  NxTest.assert_equal(22, cb::CONFIG_SCHEMA)
  NxTest.assert(NxRohA1.src('noxun_engine', 'core', 'cabinet_builder.rb').include?('#  22 = ROH-A1 · K3'), 'HISTORIA')
  NxTest.assert_equal(7, NxRohA1::BP::SCHEMA)
  NxTest.assert(NxRohA1.src('noxun_engine', 'core', 'build_plan.rb').include?('7 = ROH-A1 · K3'))
  NxTest.assert_equal(6, NxRohA1::ABS::SEED_VERSION)
  NxTest.assert_equal(7, Noxun::Engine::TemplateStore::STD, 'sablony bez bumpu STD')
  NxTest.assert(cb.newer_config?({ 'config_schema' => 23 }))
  NxTest.refute(cb.newer_config?({ 'config_schema' => 22 }))
  NxTest.assert(cb.config_schema_of(NxRohA1.stored) > 21, 'plugin schemy 21 rohovu neprestavi (sklopil by ju na dolnu)')
  NxTest.assert_equal([5, 9, 11, 19, 20], [cb::DRAWER_ACTIVATION_SCHEMA, cb::HINGE_ACTIVATION_SCHEMA,
                                           cb::LIFT_ACTIVATION_SCHEMA, cb::BACK_CUT_ACTIVATION_SCHEMA,
                                           cb::BACK_RAIL_ACTIVATION_SCHEMA], 'aktivacne schemy sa nehybu')
end

NxTest.test('ROH-A1 (G9): min_valid_width — sonda cez plan, obe strany, CR 19; ine typy = typove minimum') do
  NxRohA1.with_sheets(NxRohA1::SHEETS) do
    cn = NxRohA1::CN
    cb = NxRohA1::CB
    %w[left right].each do |side|
      c = NxRohA1.cfg('corner_side' => side, 'front_material_id' => 'F19')
      th = cb.corner_thicknesses(c, cb.effective_materials(nil, c))
      NxTest.assert_equal(585.0, cn.min_valid_width(c, part_thicknesses: th), "#{side}: 450 + 80 + 19 + 36")
      NxTest.assert_equal(584.0, cn.min_valid_width(c), "#{side}: bez hrubok placeholder 18")
    end
  end
  NxTest.assert_equal(200.0, NxRohA1::CN.min_valid_width(NxRohA1::CB.normalize('type' => 'lower')), 'dolna bez sondy')
  NxTest.assert_equal(NxRohA1::CB::CORNER_MIN_WIDTH, NxRohA1::CN.min_valid_width(NxRohA1.cfg), 'konstanta = sonda predvolieb')
  sw = NxRohA1.src('noxun_engine', 'core', 'scale_observer.rb')
  body = sw[/def absorb\(inst\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(body.index('clamp_corner_width') < body.index('clamp_depth(params'), 'sirka PRED hlbkou')
  NxTest.assert(body.index('clamp_depth(params') < body.index('clamp_height(params'), 'hlbka PRED vyskou')
  NxTest.assert(body.include?('Construction.corner?(cfg)'), 'klamp sirky len pri rohovej')
  NxTest.refute(body.include?('flush_pending!'), 'absorpcia nevola barieru')
  NxTest.assert(body.include?('transparent: true'), 'jeden transparentny rebuild')
end

NxTest.test('ROH-A1 (G9): ScaleWatch.clamp_corner_width — klamp + nemodalna veta; platna sirka bez vety') do
  sw = Noxun::Engine::ScaleWatch
  params = NxRohA1::CB.config_to_params(NxRohA1.stored)
  w, note = sw.clamp_corner_width(params, 400.0, 'CAB-009')
  NxTest.assert_equal(584.0, w)
  NxTest.assert_equal('Šírka rohovej skrinky CAB-009 je pri tejto rohovej zostave najmenej 584 mm — nastavená na 584.', note)
  NxTest.assert_equal([900.0, nil], sw.clamp_corner_width(params, 900.0, 'CAB-009'))
  pr = NxRohA1::CB.config_to_params(NxRohA1.stored('corner_side' => 'right'))
  NxTest.assert_equal(584.0, sw.clamp_corner_width(pr, 300.0, 'CAB-010')[0], 'dvere vpravo tiez')
end

NxTest.test('ROH-A1: JS registre typu a roli (zdroj) — CAB_TYPES, NX_TYPE_LABEL, TYPE_LIMITS, sablony, karta, pravidla') do
  js = ->(f) { NxRohA1.src('noxun_engine', 'ui', 'js', f) }
  NxTest.assert(js.call('core.js').include?("corner_blind: 'Rohová'"), 'NX_TYPE_LABEL')
  lim = js.call('form.js')[/corner_blind:\s*\{\s*width:\s*\[(\d+),\s*(\d+)\]/, 1].to_f
  NxTest.assert_equal(NxRohA1::CB::CORNER_MIN_WIDTH, lim, 'TYPE_LIMITS min sirka = CORNER_MIN_WIDTH')
  NxTest.assert(js.call('templates.js').include?("corner_blind: 'rohová'"), 'TPL_TYPE_WORDS')
  NxTest.assert_equal('rohová', Noxun::Engine::Panel::TEMPLATE_TYPE_WORDS['corner_blind'])
  core = js.call('core.js')
  block = core[/var\s+CONSTRUCTION_FIELDS\s*=\s*\[(.*?)\];/m, 1].to_s
  NxRohA1::CB::CORNER_KEYS.each do |k|
    NxTest.refute(block.include?("id:'#{k}'"), "C6: #{k} nie je v CONSTRUCTION_FIELDS (bez ovladaca by islo null)")
  end
  NxTest.assert(js.call('part_card.js').include?("pc.role === 'cr_front'"), 'isFront pozna CR')
  NxTest.assert_equal(Noxun::Engine::CabinetBuilder::CORNER_DEFAULTS,
                      Noxun::Engine::CabinetBuilder.defaults_for('corner_blind'))
  sync = NxRohA1.src('noxun_engine', 'ui', 'panel', 'sync.rb')
  NxTest.assert(sync.include?('corner_blind: CabinetBuilder::CORNER_DEFAULTS'), 'DEFAULTS pre JS')
end
