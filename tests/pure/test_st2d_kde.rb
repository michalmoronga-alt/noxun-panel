# frozen_string_literal: true
# ŠT-2d — „Kde sa používa": SELEKTOR dielcov podľa materiálu/ABS + rozpis
# vlastníkov + jednorazová kotva sekcie `mat`.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. ADRESA VYBERU je `material_id` / `abs_id` a hlada sa v BOM — cize
#      v EFEKTIVNOM (snapshotovom) materiali dielca. Dielec, ktory material
#      iba DEDI po korpuse, sa MUSI oznacit tiez. Keby sa selektor postavil
#      na textovych menovkach dekorov (`used_material_ids` a spol., audit #14),
#      dedene dielce by vypadli — a pouzivatel by v modeli videl oznacenu
#      polovicu skrinky bez akejkolvek hlasky.
#   2. Jeden dekor ma spravidla VIAC hrubkovych variantov (18 aj 36 mm).
#      „Kde sa používa" sa pyta na CELU skupinu, takze kluc smie byt POLE.
#      Keby bral len retazec, klik by oznacil len jednu hrubku.
#   3. `owner_id` zuzuje vyber na JEDEN korpus/dosku — riadok zoznamu
#      vlastnikov musi oznacit presne svoje dielce, nie vsetky.
#   4. GEN GUARD: klik zo stareho DOM sa odmietne EST PRED tym, nez sa siahne
#      na model. (V teste je model `nil` — keby guard nedrzal, padlo by to.)
#   5. Rozpis vlastnikov (`mat_used_where`) vznika z UZ zozbieraneho kusovnika
#      — druhy sken modelu pri kazdom prepocte by okno spomalil presne tak,
#      ako to ŠT-2a uz raz odstranilo.
#   6. Kotva sekcie `mat` je JEDNORAZOVA — inak by sa detail dekoru otvaral
#      po kazdom refreshi znova, aj ked medzitym pouzivatel odisiel.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?

ST2D_CORE_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                          encoding: 'UTF-8')
ST2D_STUDIO_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                            encoding: 'UTF-8')
ST2D_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')

module NxSt2dFix
  module_function

  # Vyrobny snapshot dielca. `mat` je UZ ROZHODNUTY material (presne to, co
  # zapise builder aj pri dedeni po korpuse) — fixture tym zrkadli realitu:
  # v zazname NIE JE ziadna stopa po tom, ci material dielec dedi alebo ma
  # vlastny override.
  def rec(pid, owner, name, mat, edges = {}, role = 'shelf', qty = 1, th = 18.0)
    full = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.merge(edges)
    { 'name' => name, 'part_key' => "cabinet/#{name}", 'owner_id' => owner,
      'pid' => pid, 'role' => role, 'length' => 600.0, 'width' => 500.0,
      'thickness' => th, 'quantity' => qty, 'material_id' => mat,
      'grain_direction' => 'none', 'edges' => full }
  end

  # Zber tak, ako ho vracia `Bom.collect` (headless: fixture namiesto modelu).
  def collected(records)
    { records: records, hardware: [], hardware_overrides: [], cabinet_sets: {},
      placements: [], warnings: [], cabinets: 2, boards: 1 }
  end

  def bom(records)
    Noxun::Engine::Bom.compute(collected(records))
  end

  # DEDENY dielec (polica CAB-002) nesie ten isty rozhodnuty material ako
  # dielce s vlastnym override — presne to je pointa bodu 1.
  def sample
    [
      rec(11, 'CAB-001', 'Bok lavy',  'H3303_18', { 'L1' => 'ABS_H3303_22' }, 'side_left'),
      rec(12, 'CAB-001', 'Bok pravy', 'H3303_18', { 'L1' => 'ABS_H3303_22' }, 'side_right'),
      rec(13, 'CAB-001', 'Pracovna',  'H3303_36', {}, 'top'),
      rec(14, 'CAB-002', 'Polica',    'H3303_18', { 'W1' => 'ABS_H3303_22' }, 'shelf'),
      rec(15, 'CAB-002', 'Chrbat',    'HDF_3',    {}, 'back', 1, 3.0),
      rec(16, 'BOARD-9', 'Doska',     'H3303_36', { 'L2' => 'ABS_INY_22' }, 'free_panel')
    ]
  end
end

# --- 1) selektor podla MATERIALU --------------------------------------------

NxTest.test('ŠT-2d: `material_key` oznaci VSETKY dielce s tym materialom — aj DEDENY') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  pids = core.refs_for(bom, 'material_key' => 'H3303_18')
  NxTest.assert_equal([11, 12, 14], pids.sort)
  NxTest.assert(pids.include?(14),
                'polica CAB-002 material DEDI — v snapshote je rozhodnuty a MUSI sa oznacit')
end

NxTest.test('ŠT-2d: `material_key` smie byt POLE — dekor ma viac hrubkovych variantov') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  pids = core.refs_for(bom, 'material_key' => %w[H3303_18 H3303_36])
  NxTest.assert_equal([11, 12, 13, 14, 16], pids.sort)
end

NxTest.test('ŠT-2d: `owner_id` zuzi vyber na jedneho vlastnika (riadok zoznamu)') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  NxTest.assert_equal([11, 12],
                      core.refs_for(bom, 'material_key' => 'H3303_18', 'owner_id' => 'CAB-001').sort)
  NxTest.assert_equal([14],
                      core.refs_for(bom, 'material_key' => 'H3303_18', 'owner_id' => 'CAB-002'))
  NxTest.assert_equal([16],
                      core.refs_for(bom, 'material_key' => 'H3303_36', 'owner_id' => 'BOARD-9'),
                      'samostatna doska je vlastnik ako kazdy iny')
end

NxTest.test('ŠT-2d (audit #14): adresa je material_id, NIE textova menovka dekoru') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  # Keby selektor stal na dekorovych menovkach (`used_material_ids`), tento
  # dotaz by nieco vratil — a naopak dotaz na `material_id` by prisiel prazdny.
  NxTest.assert_equal([], core.refs_for(bom, 'material_key' => 'H3303'))
  NxTest.assert_equal([], core.refs_for(bom, 'material_key' => ''))
  NxTest.assert_equal([], core.refs_for(bom, 'material_key' => []))
end

# --- 2) selektor podla ABS ----------------------------------------------------

NxTest.test('ŠT-2d: `abs_key` oznaci dielce s danou paskou na KTOREJKOLVEK hrane') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  # 11/12 maju pasku na L1, 14 na W1 — hrana nerozhoduje.
  NxTest.assert_equal([11, 12, 14], core.refs_for(bom, 'abs_key' => 'ABS_H3303_22').sort)
  NxTest.assert_equal([16], core.refs_for(bom, 'abs_key' => 'ABS_INY_22'))
  NxTest.assert_equal([], core.refs_for(bom, 'abs_key' => 'ABS_NEEXISTUJE'))
end

NxTest.test('ŠT-2d: `abs_key` sa da zuzit na vlastnika rovnako ako material') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  NxTest.assert_equal([14], core.refs_for(bom, 'abs_key' => 'ABS_H3303_22', 'owner_id' => 'CAB-002'))
end

NxTest.test('ŠT-2d: stare kluce vyberu (riadok kusovnika, kovanie, pids) sa nezmenili') do
  core = Noxun::Engine::ProductionCore
  bom = NxSt2dFix.bom(NxSt2dFix.sample)
  row = bom[:rows].find { |r| r['material_id'] == 'HDF_3' }
  NxTest.assert_equal([15], core.refs_for(bom, 'parts_key' => row['key']))
  NxTest.assert_equal([7, 8], core.refs_for(bom, 'pids' => [7, 8, 7]))
end

NxTest.test('ŠT-2d: selektor cita BOM riadky (nie druhy zdroj pravdy o materiali)') do
  body = ST2D_CORE_SRC[/def refs_by_material.*?\n      end\n/m].to_s
  NxTest.assert(body.include?('bom[:rows]'), 'zdroj su riadky CERSTVEHO bomu')
  # Zdrojak BEZ komentarov: v komentaroch meno ZAMERNE ostava (vysvetluje,
  # PRECO sa tou cestou nejde).
  code = ST2D_CORE_SRC.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert(!code.include?('used_material_ids'),
                'jadro sa nesmie pytat textovych menoviek dekorov (audit #14)')
end

# --- 3) gen guard (klik zo stareho DOM) --------------------------------------

NxTest.test('ŠT-2d: klik so STAROU generaciou sa odmietne PRED siahnutim na model') do
  core = Noxun::Engine::ProductionCore
  msgs = []
  repushed = 0
  core.do_select(nil, { 'gen' => 3, 'material_key' => 'H3303_18' },
                 generation: 9,
                 status: ->(m, err = false) { msgs << [m.to_s, err] },
                 repush: -> { repushed += 1 })
  NxTest.assert_equal(1, repushed)
  NxTest.assert(msgs.length == 1 && msgs[0][1] == true, 'odmietnutie sa POVIE (nie tichy no-op)')
  NxTest.assert(msgs[0][0].include?('obnovili'), "hlaska o obnove dat, dostal som: #{msgs[0][0]}")
end

# --- 4) rozpis vlastnikov (`used_where`) -------------------------------------

module NxSt2dStub
  module_function

  # Docasne kluce skupin (v headless katalogu ziadne take zaznamy nie su —
  # sada testuje TVAR rozpisu, nie obsah seed katalogu).
  def with_keys(sheets, edges)
    m = Noxun::Engine::Materials
    m.singleton_class.class_eval do
      alias_method :nx_st2d_orig_sheets, :decor_key_by_material_id
      alias_method :nx_st2d_orig_edges, :decor_key_by_abs_id
      define_method(:decor_key_by_material_id) { sheets }
      define_method(:decor_key_by_abs_id) { edges }
    end
    yield
  ensure
    m.singleton_class.class_eval do
      alias_method :decor_key_by_material_id, :nx_st2d_orig_sheets
      alias_method :decor_key_by_abs_id, :nx_st2d_orig_edges
      remove_method :nx_st2d_orig_sheets
      remove_method :nx_st2d_orig_edges
    end
  end
end

NxTest.test('ŠT-2d: `used_where` rozpise vlastnikov, ich roly a adresu vyberu') do
  keys = { 'H3303_18' => 'GRP-A', 'H3303_36' => 'GRP-A', 'HDF_3' => 'GRP-B' }
  abs = { 'ABS_H3303_22' => 'GRP-A', 'ABS_INY_22' => 'GRP-C' }
  out = NxSt2dStub.with_keys(keys, abs) do
    Noxun::Engine::StudioDialog.mat_used_where(NxSt2dFix.collected(NxSt2dFix.sample))
  end
  a = out['GRP-A']
  NxTest.assert(!a.nil?, 'skupina dekoru je v rozpise')
  owners = a['owners'].sort_by { |o| o['owner_id'] }
  NxTest.assert_equal(%w[BOARD-9 CAB-001 CAB-002], owners.map { |o| o['owner_id'] })
  cab1 = owners.find { |o| o['owner_id'] == 'CAB-001' }
  NxTest.assert_equal(3, cab1['parts'], 'dva boky + pracovna doska')
  NxTest.assert_equal(['Bok ľavý', 'Bok pravý', 'Strop'], cab1['roles'],
                      'roly su SLOVENSKE TEXTY zo servera (klient preklad enumu nema)')
  NxTest.assert_equal(%w[H3303_18 H3303_36], cab1['material_ids'].sort,
                      'adresa oka = presne tie varianty, ktore ten vlastnik ma')
  cab2 = owners.find { |o| o['owner_id'] == 'CAB-002' }
  NxTest.assert_equal(%w[H3303_18], cab2['material_ids'],
                      'dedena polica ma v adrese svoj ROZHODNUTY material')
  NxTest.assert_equal({ 'ABS_H3303_22' => 3 }, a['edges'],
                      'paska sa rata za DIELEC, nie za hranu')
  NxTest.assert_equal(1, out['GRP-B']['owners'].length, 'chrbat je vlastny dekor')
  NxTest.assert_equal({ 'ABS_INY_22' => 1 }, out['GRP-C']['edges'],
                      'dekor pouzity LEN ako paska je v rozpise tiez')
  NxTest.assert_equal([], out['GRP-C']['owners'], 'a nema ziadneho doskoveho vlastnika')
end

NxTest.test('ŠT-2d: rozpis vznika z UZ zozbieraneho kusovnika (ziadny druhy sken)') do
  body = ST2D_STUDIO_SRC[/def mat_used_where\(collected\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('collected[:records]'), 'zdroj je ten isty zber ako Kusovnik')
  NxTest.assert(!body.include?('Ids.'), 'ziadny vlastny sken modelu (audit #15)')
  NxTest.assert(ST2D_STUDIO_SRC.include?("'used_where' => mat_used_where(collected)"),
                'rozpis chodi v `mat` payloade vedla poctov')
end

# --- 5) kotva sekcie `mat` ----------------------------------------------------

NxTest.test('ŠT-2d: kotva sa spotrebuje PRAVE RAZ (deep-link z karty dielca)') do
  dlg = Noxun::Engine::StudioDialog
  before = dlg.instance_variable_get(:@pending_anchor)
  begin
    dlg.instance_variable_set(:@pending_anchor, 'H3303_18')
    NxTest.assert_equal('H3303_18', dlg.send(:consume_pending_anchor))
    NxTest.assert(dlg.send(:consume_pending_anchor).nil?,
                  'druhy push uz kotvu nenesie — inak by sa detail otvaral po kazdom refreshi')
  ensure
    dlg.instance_variable_set(:@pending_anchor, before)
  end
end

NxTest.test('ŠT-2d: sekcia `mat` spotrebuje kotvu ako OTVORENIE DETAILU, nie ako filter') do
  NxTest.assert(ST2D_STUDIO_JS.include?("(studioSec === 'mat') ? anchorFilter(ST) : null"),
                'kotva sa aplikuje LEN so sekciou, do ktorej patri')
  NxTest.assert(ST2D_STUDIO_JS.include?("matOpenAnchor(ma)"),
                'a sekcia `mat` ju preklada na detail dekoru')
  NxTest.assert(ST2D_STUDIO_JS.include?("var a = (studioSec === 'bom') ? anchorFilter(ST) : null"),
                'kotva Kusovnika (N13 = ID skrinky) ostava nedotknuta')
end
