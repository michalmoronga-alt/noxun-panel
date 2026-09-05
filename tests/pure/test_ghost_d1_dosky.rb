# frozen_string_literal: true
# GHOST-D1 — GHOST PRE DOSKY, ZAKLAD. CISTA cast: tabulka kotiev a obalka
# dosky, cyklus umiestnenia, subjekt/interakcia session, pamat per subjekt,
# zmrazeny `BoardPlan` a kontrakt configu dosky (`BOARD_CONFIG_SCHEMA`).
# Bez SketchUpu, bez modelu, bez entit.
#
# Co sa overuje (a preco to nie je klikanie):
#   1) ZAVAZNA tabulka kotiev 3 orientacie x 4 kotvy — kotva sa meria proti
#      TRANSFORMU (kde skonci kliknuty bod), nie proti druhemu helperu;
#      chyba v nej by dosku polozila inam, nez pouzivatel klikol,
#   2) obalka per orientacia — `draw` z nej kresli a `getExtents` ju vracia,
#   3) subjekt a interakcia su EXPLICITNE a pamat je per [subjekt, interakcia]:
#      skrinka a doska si nesmu prepisat kotvu ani rotaciu,
#   4) ORIENTACIA zije LEN v session (startuje z karty) a ↑/↓ ju cyklia,
#   5) ZMRAZENY plan: zmena katalogu PO priprave uz vyrobny snapshot nezmeni,
#   6) kontrakt configu dosky — marker v KAZDOM zapise, forward-version
#      odmietnutie na VSETKYCH citacich cestach (mutacie, sablony, vystupy).
require_relative '../helper' unless defined?(NxTest)

module NxD1
  module_function

  def e
    Noxun::Engine
  end

  def gt
    e::GhostTool
  end

  def calc
    e::GhostTool::Calc
  end

  def bb
    e::BoardBuilder
  end

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  # Normalizovany config dosky (symbolove kluce, ako `BoardBuilder.normalize`).
  def cfg(extra = {})
    { role: 'free_panel', name: 'Doska', length: 800.0, width: 600.0, thickness: 18.0,
      material_id: 'MAT_D1', grain_direction: 'length',
      edges: { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
      quantity: 1, orientation: 'leziaca' }.merge(extra)
  end

  # Zmrazeny plan dosky BEZ katalogu — na geometriu a stavovy automat staci.
  def plan(config = cfg, orientation = nil, model = Object.new, template_ref = nil)
    o = orientation || config[:orientation].to_s
    e::BoardBuilder::BoardPlan.new(model, config, bb.board_config(config), o, template_ref)
  end

  # Cerstva pamat — inak by si scenare navzajom prepisovali kotvu a rotaciu.
  def fresh_memory
    { anchor: gt::ANCHORS.first, rotation_index: 0 }
  end

  def session(config = cfg, orientation: nil, memory: nil, **kw)
    gt::PlacementSession.new(model: Object.new, plan: plan(config, orientation),
                             subject: :board, memory: memory || fresh_memory,
                             orientation: orientation || config[:orientation], **kw)
  end

  # Aplikuje 16-cislovu maticu na lokalny bod (stlpcove poradie SketchUpu).
  def apply(m, pt)
    x = pt[0].to_f
    y = pt[1].to_f
    z = pt[2].to_f
    [(m[0] * x) + (m[4] * y) + (m[8] * z) + m[12],
     (m[1] * x) + (m[5] * y) + (m[9] * z) + m[13],
     (m[2] * x) + (m[6] * y) + (m[10] * z) + m[14]]
  end

  # Docasny katalog: `Materials.sheet` vracia nase zaznamy. Original sa
  # ALIASUJE (nie prepisuje) — `class << self` metodu by inak nebolo z coho
  # obnovit a nasledne sady by bezali nad stubom.
  def with_catalog(sheets)
    sc = e::Materials.singleton_class
    sc.send(:alias_method, :sheet_nxd1_orig, :sheet)
    sc.send(:define_method, :sheet) { |id| sheets[id.to_s] }
    yield
  ensure
    sc.send(:alias_method, :sheet, :sheet_nxd1_orig)
    sc.send(:remove_method, :sheet_nxd1_orig)
  end

  def sheet(id, thickness, extra = {})
    { 'material_id' => id, 'thickness' => thickness, 'decor' => 'DEK',
      'grain' => 'length' }.merge(extra)
  end
end

# ---------------------------------------------------------------------------
# 1) ZAVAZNA tabulka kotiev (3 orientacie x 4 kotvy) a obalka
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 kotvy: `leziaca` (X = dlzka, Y = sirka, Z = hrubka)') do
  a = NxD1.calc.board_anchor_points(NxD1.cfg, 'leziaca')
  NxTest.assert_equal([0.0, 0.0, 0.0], a[:fl_bottom])
  NxTest.assert_equal([800.0, 0.0, 0.0], a[:fr_bottom])
  NxTest.assert_equal([800.0, 0.0, 18.0], a[:fr_top])
  NxTest.assert_equal([0.0, 0.0, 18.0], a[:fl_top])
end

NxTest.test('GHOST-D1 kotvy: `stojaca` (X = dlzka, Y = hrubka, Z = sirka)') do
  a = NxD1.calc.board_anchor_points(NxD1.cfg, 'stojaca')
  NxTest.assert_equal([0.0, 0.0, 0.0], a[:fl_bottom])
  NxTest.assert_equal([800.0, 0.0, 0.0], a[:fr_bottom])
  NxTest.assert_equal([800.0, 0.0, 600.0], a[:fr_top])
  NxTest.assert_equal([0.0, 0.0, 600.0], a[:fl_top])
end

NxTest.test('GHOST-D1 kotvy: `na_stenu` ma TU ISTU tabulku ako `stojaca` (zdielana matica)') do
  NxTest.assert_equal(NxD1.calc.board_anchor_points(NxD1.cfg, 'stojaca'),
                      NxD1.calc.board_anchor_points(NxD1.cfg, 'na_stenu'))
  # Rozdiel je VYHRADNE v configu — nikdy nie v geometrii (STANDARD 8.3).
  NxTest.assert_equal(NxD1.calc.board_envelope_points(NxD1.cfg, 'stojaca'),
                      NxD1.calc.board_envelope_points(NxD1.cfg, 'na_stenu'))
end

NxTest.test('GHOST-D1 kotvy: ID a poradie ALT cyklu su ZHODNE so skrinkou') do
  NxTest.assert_equal(%i[fl_bottom fr_bottom fr_top fl_top], NxD1.gt::ANCHORS)
  NxD1.calc::BOARD_ANCHOR_TABLE.each do |o, row|
    NxTest.assert_equal(NxD1.gt::ANCHORS, row.keys, "#{o}: tabulka ma vsetky kotvy v poradi skrinky")
  end
  # „Predna" plocha je pri VSETKYCH orientaciach rovina Y = 0 (ako pri skrinke).
  NxD1.calc::BOARD_ANCHOR_TABLE.each_value do |row|
    row.each_value { |spec| NxTest.assert_equal(:zero, spec[1], 'kotva lezi na prednej ploche Y = 0') }
  end
end

NxTest.test('GHOST-D1 obalka: rozmery per orientacia (kvader v ramci UMIESTNENEJ dosky)') do
  { 'leziaca' => [800.0, 600.0, 18.0],
    'stojaca' => [800.0, 18.0, 600.0],
    'na_stenu' => [800.0, 18.0, 600.0] }.each do |o, (x, y, z)|
    pts = NxD1.calc.board_envelope_points(NxD1.cfg, o)
    NxTest.assert_equal(8, pts.length, "#{o}: obalka ma 8 rohov")
    NxTest.assert_equal([0.0, 0.0, 0.0], pts[0], "#{o}: prvy roh je lokalny pociatok")
    NxTest.assert_equal([x, y, z], [pts.map { |p| p[0] }.max, pts.map { |p| p[1] }.max,
                                    pts.map { |p| p[2] }.max], "#{o}: rozmery obalky")
    # Poradie je SUCASTOU kontraktu kreslenia — predna stena su indexy 0,1,5,4.
    NxD1.gt::FRONT_FACE.each { |i| NxTest.assert_equal(0.0, pts[i][1], "#{o}: predna stena lezi na Y = 0") }
  end
end

NxTest.test('GHOST-D1 kotvy: neznama orientacia kresbu nezhodi (spadne na leziacu)') do
  NxTest.assert_equal(NxD1.calc.board_anchor_points(NxD1.cfg, 'leziaca'),
                      NxD1.calc.board_anchor_points(NxD1.cfg, 'zavesena'))
end

# ---------------------------------------------------------------------------
# 2) NEZAVISLY DOKAZ: zvolena kotva sadne PRESNE na kliknuty bod
#    (transform vs. kliknuty bod — nie helper vs. helper)
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1: kotva COMMITNUTEJ dosky sadne na kliknuty bod — 3 orientacie x 4 kotvy x 4 rotacie') do
  picked = [1234.5, -678.25, 912.75]
  %w[leziaca stojaca na_stenu].each do |o|
    NxD1.gt::ANCHORS.each do |anchor|
      4.times do |rot|
        a = NxD1.calc.board_anchor_point(NxD1.cfg, o, anchor)
        m = NxD1.calc.matrix(anchor: a, picked: picked, rotation_index: rot, z_mode: :free)
        got = NxD1.apply(m, a)
        3.times do |i|
          NxTest.assert_close(picked[i], got[i], 1e-9,
                              "#{o}/#{anchor}/#{rot * 90}°: zlozka #{i} sadla na kliknuty bod")
        end
        NxTest.assert(Noxun::Engine::CabinetBuilder.rigid_matrix?(m),
                      "#{o}/#{anchor}/#{rot * 90}°: matica je rigidna (R-03)")
      end
    end
  end
end

NxTest.test('GHOST-D1: doska sa kladie plne v XYZ — Z kliknuteho bodu sa NEZAMYKA') do
  s = NxD1.session
  NxTest.assert_equal(:free, s.z_mode, 'doska nema rezim zamku vysky')
  NxTest.assert_close(0.0, s.lock_plane_z, 1e-9, 'rovina zamku sa pri doske nepouziva')
  NxTest.refute(s.set_z_mode!(:locked), 'zamok vysky sa doske nastavit NEDA')
  NxTest.assert_equal(:free, s.z_mode, 'a rezim sa nezmenil')
end

# ---------------------------------------------------------------------------
# 3) SUBJEKT + INTERAKCIA + pamat per subjekt
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1: subjekt a interakcia su EXPLICITNE (nie odvodene z planu)') do
  s = NxD1.session
  NxTest.assert_equal(:board, s.subject)
  NxTest.assert_equal(:placement, s.interaction)
  NxTest.assert(s.board? && !s.cabinet? && s.placement?)
  NxTest.assert_equal(%i[cabinet board], NxD1.gt::SUBJECTS)
  NxTest.assert_equal(%i[placement], NxD1.gt::INTERACTIONS, 'D2 sem pridá `drawing`')
  # Neznamy subjekt sa NEPREBERIE — session by inak citala obalku zleho typu.
  cab = { type: 'lower', width: 600.0, height: 720.0, depth: 510.0,
          thickness: 18.0, floor_height: 100.0, bottom_mode: 'under_sides' }
  bad = NxD1.gt::PlacementSession.new(
    model: Object.new,
    plan: Noxun::Engine::CabinetBuilder::InsertPlan.new(Object.new, cab, 0.0),
    subject: :assembly, interaction: :drawing,
    memory: { anchor: NxD1.gt::ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
  )
  NxTest.assert_equal(:cabinet, bad.subject, 'neznamy subjekt spadne na skrinku')
  NxTest.assert_equal(:placement, bad.interaction, 'a neznama interakcia na umiestnovanie')
end

NxTest.test('GHOST-D1 pamat: skrinka a doska maju VLASTNU (kotva a rotacia sa nepomiesaju)') do
  NxD1.gt.reset_memory!
  cab = NxD1.gt.memory(:cabinet)
  brd = NxD1.gt.memory(:board)
  NxTest.refute(cab.equal?(brd), 'dva NEZAVISLE hashe')
  NxTest.assert(cab.key?(:z_mode) && cab.key?(:lock_z), 'skrinka drzi aj rezim vysky a locknute vysky')
  NxTest.assert_equal(%i[anchor rotation_index].sort, brd.keys.sort,
                      'doska drzi LEN rotaciu a kotvu (orientacia zije v session)')
  # Skrinka -> doska -> skrinka: kazdy subjekt si pamata SVOJE.
  cab[:rotation_index] = 2
  cab[:anchor] = :fr_top
  brd[:rotation_index] = 1
  brd[:anchor] = :fl_top
  NxTest.assert_equal(2, NxD1.gt.memory(:cabinet)[:rotation_index], 'skrinka drzi svoju rotaciu')
  NxTest.assert_equal(:fr_top, NxD1.gt.memory(:cabinet)[:anchor], 'a svoju kotvu')
  NxTest.assert_equal(1, NxD1.gt.memory(:board)[:rotation_index], 'doska drzi svoju rotaciu')
  NxTest.assert_equal(:fl_top, NxD1.gt.memory(:board)[:anchor], 'a svoju kotvu')
  NxD1.gt.reset_memory!
  NxTest.assert_equal(0, NxD1.gt.memory(:board)[:rotation_index], 'reset vrati tovarenske hodnoty')
end

NxTest.test('GHOST-D1 pamat: nova session dosky startuje tam, kde predosla skoncila') do
  mem = NxD1.fresh_memory
  s1 = NxD1.session(memory: mem)
  s1.rotate!(1)
  s1.cycle_anchor!
  s2 = NxD1.session(memory: mem)
  NxTest.assert_equal(1, s2.rotation_index, 'rotacia prezila')
  NxTest.assert_equal(:fr_bottom, s2.anchor, 'kotva prezila')
end

# ---------------------------------------------------------------------------
# 4) ORIENTACIA: zije v session, startuje z karty, cykli ↑/↓
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 orientacia: cyklus je leziaca -> stojaca -> na_stenu -> leziaca') do
  c = NxD1.calc
  NxTest.assert_equal('stojaca', c.next_board_orientation('leziaca'))
  NxTest.assert_equal('na_stenu', c.next_board_orientation('stojaca'))
  NxTest.assert_equal('leziaca', c.next_board_orientation('na_stenu'))
  # ↓ ide opacne
  NxTest.assert_equal('na_stenu', c.next_board_orientation('leziaca', -1))
  NxTest.assert_equal('leziaca', c.next_board_orientation('stojaca', -1))
  # Slovnik je zdielany s BoardBuilderom — jedna autorita, ziadny drift.
  NxTest.assert_equal(NxD1.bb::ORIENTATIONS, c::BOARD_AXES.keys)
end

NxTest.test('GHOST-D1 orientacia: ↑ prepocita obalku AJ kotvy (doska sa kladie uz otocena)') do
  s = NxD1.session(orientation: 'leziaca')
  NxTest.assert_equal([0.0, 0.0, 18.0], s.anchors_mm[:fl_top], 'leziaca: horna kotva na hrubke')
  NxTest.assert(s.cycle_orientation!(1), 'zmena nastala')
  NxTest.assert_equal('stojaca', s.orientation)
  NxTest.assert_equal([0.0, 0.0, 600.0], s.anchors_mm[:fl_top], 'stojaca: horna kotva na sirke')
  NxTest.assert_equal(600.0, s.corners_mm.map { |p| p[2] }.max, 'a obalka je vysoka ako sirka dosky')
end

NxTest.test('GHOST-D1 orientacia: KAZDA nova session ju cita z KARTY, nie z pamate') do
  mem = NxD1.fresh_memory
  s1 = NxD1.session(orientation: 'leziaca', memory: mem)
  s1.cycle_orientation!(1)
  s1.cycle_orientation!(1)
  NxTest.assert_equal('na_stenu', s1.orientation, 'v session sa orientacia zmenila')
  NxTest.refute(mem.key?(:orientation), 'do pamate modulu sa NEZAPISALA')
  # Predvolena sablona „stojaca" po predoslej lezicej session:
  s2 = NxD1.session(NxD1.cfg(orientation: 'stojaca'), orientation: 'stojaca', memory: mem)
  NxTest.assert_equal('stojaca', s2.orientation, 'nova session startuje z hodnoty karty')
end

NxTest.test('GHOST-D1 orientacia: neznama hodnota z karty session NEZHODI (spadne na leziacu)') do
  s = NxD1.session(orientation: 'zavesena')
  NxTest.assert_equal('leziaca', s.orientation)
end

NxTest.test('GHOST-D1: skrinka umiestnenie NEMA (↑/↓ ostavaju rezimom vysky)') do
  cab = { type: 'lower', width: 600.0, height: 720.0, depth: 510.0,
          thickness: 18.0, floor_height: 100.0, bottom_mode: 'under_sides' }
  s = NxD1.gt::PlacementSession.new(
    model: Object.new,
    plan: Noxun::Engine::CabinetBuilder::InsertPlan.new(Object.new, cab, 0.0),
    memory: { anchor: NxD1.gt::ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
  )
  NxTest.assert_equal(:cabinet, s.subject)
  NxTest.refute(s.cycle_orientation!(1), 'skrinke sa orientacia cyklit NEDA')
  NxTest.assert(s.set_z_mode!(:free), 'skrinke rezim vysky funguje dalej')
  NxTest.assert_equal('', s.orientation_label, 'a pasik pri nej umiestnenie nekresli')
end

# ---------------------------------------------------------------------------
# 5) PASIK: payload nesie subjekt, interakciu a umiestnenie
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 pasik: payload dosky nesie subjekt aj umiestnenie s popiskom') do
  s = NxD1.session(orientation: 'stojaca')
  p = NxD1.gt.state_payload(s)
  NxTest.assert_equal('board', p['subject'])
  NxTest.assert_equal('placement', p['interaction'])
  NxTest.assert_equal('stojaca', p['orientation'])
  NxTest.assert_equal('Nastojato', p['orientation_label'])
  NxTest.assert_equal('board', p['type'])
end

NxTest.test('GHOST-D1 status: doska ma vlastnu napovedu (umiestnenie, nie zamok vysky)') do
  s = NxD1.session(orientation: 'stojaca')
  s.set_point([0.0, 0.0, 0.0])
  txt = NxD1.gt.status_text(s)
  NxTest.assert(txt.include?('položí dosku'), txt)
  NxTest.assert(txt.include?('↑/↓ umiestnenie'), txt)
  NxTest.assert(txt.include?('nastojato'), txt)
  NxTest.refute(txt.include?('zámok výšky'), 'zamok vysky sa doske neponuka')
end

# ---------------------------------------------------------------------------
# 6) ZMRAZENY PLAN + kontrakt configu dosky
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 plan: `BoardPlan` je zmrazeny a viazany na DOKUMENT (nie na guid)') do
  m = Object.new
  pl = NxD1.bb::BoardPlan.new(m, NxD1.cfg.freeze, NxD1.bb.board_config(NxD1.cfg).freeze, 'leziaca')
  NxTest.assert(pl.frozen?, 'plan sam je zmrazeny')
  NxTest.assert(pl.for_model?(m), 'patri svojmu dokumentu')
  NxTest.refute(pl.for_model?(Object.new), 'cudzi dokument odmieta')
  NxTest.refute(pl.for_model?(nil), 'a nil tiez')
end

NxTest.test('GHOST-D1 plan: `prepare_insert` vyriesi katalog RAZ — neskorsia zmena snapshot NEMENI') do
  NxTest.skip!('vyzaduje katalogovy sandbox') unless NxTest.headless?
  before = { 'MAT_D1' => NxD1.sheet('MAT_D1', 18.0) }
  after  = { 'MAT_D1' => NxD1.sheet('MAT_D1', 36.0, 'source_material_id' => 'MAT_SRC',
                                                    'source_multiplier' => 2) }
  params = { 'material_id' => 'MAT_D1', 'length' => 800.0, 'width' => 600.0,
             'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  plan = nil
  NxD1.with_catalog(before) { plan = NxD1.bb.prepare_insert(Object.new, params) }
  snap = plan.stored_config
  NxTest.assert_close(18.0, snap[:thickness], 0.001, 'plan nesie hrubku z casu pripravy')
  NxTest.assert(snap.frozen?, 'zapisovy snapshot je zmrazeny')
  NxTest.assert(plan.config.frozen?, 'aj normalizovany config')
  # Katalog sa medzi pripravou a klikom ZMENIL (ina hrubka + duplak vazba).
  NxD1.with_catalog(after) do
    fresh = NxD1.bb.board_config(NxD1.bb.normalize(params))
    NxTest.assert_close(36.0, fresh[:thickness], 0.001, 'kontrola: katalog sa naozaj zmenil')
    NxTest.assert(fresh.key?(:material_source), 'a duplak vazba by pribudla')
    NxTest.assert_close(18.0, plan.stored_config[:thickness], 0.001,
                        'ZMRAZENY plan si zmenu katalogu NEVSIMNE')
    NxTest.refute(plan.stored_config.key?(:material_source), 'ani duplak vazbu nedostane')
  end
end

NxTest.test('GHOST-D1 sev: `commit_insert` pise config Z PLANU (ziadne druhe citanie katalogu)') do
  s = NxD1.src('noxun_engine', 'core', 'board_builder.rb')
  body = s[/def commit_insert\(model, plan, transform:, orientation: nil\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'sev sa nasiel')
  NxTest.assert(body.include?('plan.stored_config'), 'config ide zo zmrazeneho planu')
  NxTest.refute(body.include?('normalize('), 'commit uz NENORMALIZUJE')
  NxTest.refute(body.include?('board_config('), 'ani nestavia config nanovo')
  NxTest.assert(body.include?('write_board_attrs(model, inst, bid, cfg, config: stored)'),
                'snapshot z planu ide az na entitu')
  # Poradie kontraktu R-03: identita dokumentu -> orientacia -> transform ->
  # root kontext -> ID -> operacia.
  NxTest.assert(body.index('for_model?(model)') < body.index('snapshot_insert_transform!'),
                'identita dokumentu sa overuje PRED transformom')
  NxTest.assert(body.index('snapshot_insert_transform!') < body.index('ensure_root!'),
                'transform sa overuje PRED zatvorenim edit kontextu')
  NxTest.assert(body.index('ensure_root!') < body.index('Ids.next_board_id'),
                'ID vznika az po root kontexte')
  # Vlozenie MUSI bezat vo vlastnej pomenovanej operacii (jeden krok Spat).
  NxTest.assert(body.include?('model.start_operation('), 'commit otvara VLASTNU operaciu')
  NxTest.assert(body.include?('model.commit_operation'), 'a commituje ju')
  NxTest.assert(body.index('Ids.next_board_id') < body.index('start_operation'),
                'ID vznika este pred operaciou')
  NxTest.assert(body.include?('guarded do'), 'operacia aj follow-up bezia pod ScaleWatch.guard')
  NxTest.assert(body.include?('apply_scale_lock_op(model, inst)'),
                'transparentny scale-lock follow-up ostava (DC pasca, D-40)')
  NxTest.assert(body.index('model.commit_operation') < body.index('apply_scale_lock_op'),
                'follow-up bezi AZ PO commite vytvaracej operacie')
  NxTest.assert(body.include?('abort_operation') || body.include?('abort_safely'),
                'vytvaracia operacia sa pri chybe rusi')
end

NxTest.test('GHOST-D1 sev: `prepare_insert` NEZATVARA edit kontext (ghost hover nesmie do modelu)') do
  s = NxD1.src('noxun_engine', 'core', 'board_builder.rb')
  body = s[/def prepare_insert\(model, params, template_ref: nil\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'priprava sa nasla')
  NxTest.refute(body.include?('ensure_root!'), 'priprava edit kontext nezatvara')
  NxTest.refute(body.include?('start_operation'), 'ani neotvara operaciu')
  NxTest.refute(body.include?('next_board_id'), 'ani neprideluje ID')
end

NxTest.test('GHOST-D1 config: marker `BOARD_CONFIG_SCHEMA` je v KAZDOM zapise configu dosky') do
  c = NxD1.bb.board_config(NxD1.cfg)
  NxTest.assert_equal(NxD1.bb::BOARD_CONFIG_SCHEMA, c[:config_schema])
  NxTest.assert_equal(1, NxD1.bb::BOARD_CONFIG_SCHEMA, 'zavedenie markera = 1 (dnesny tvar)')
end

NxTest.test('GHOST-D1 config: vyssia schema = „novsi config", rovnaka a starsia su OK') do
  NxTest.refute(NxD1.bb.newer_config?({}), 'chybajuci marker (legacy doska) NEBLOKUJE')
  NxTest.refute(NxD1.bb.newer_config?('config_schema' => 0))
  NxTest.refute(NxD1.bb.newer_config?('config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA))
  NxTest.assert(NxD1.bb.newer_config?('config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA + 1))
  NxTest.assert(NxD1.bb.newer_config?(config_schema: NxD1.bb::BOARD_CONFIG_SCHEMA + 1),
                'symbolove kluce tiez (config z normalize)')
  NxTest.assert_raise(/novšej verzie/) do
    NxD1.bb.guard_newer_config!('config_schema' => 99)
  end
  NxTest.assert_equal(nil, NxD1.bb.guard_newer_config!('config_schema' => 1), 'kompatibilny prejde')
end

NxTest.test('GHOST-D1 config: kontrakt dosky je NEZAVISLY od kontraktu korpusu') do
  # Dva SAMOSTATNE kontrakty — cisla sa nikdy neporovnavaju medzi sebou
  # (doska so schemou 1 je aktualna, hoci korpus je na 4). Kazdy builder cita
  # VYHRADNE svoj marker; zamena by dosky ticho zablokovala alebo prepustila.
  NxTest.assert_equal(1, NxD1.bb::BOARD_CONFIG_SCHEMA)
  NxTest.assert_equal(4, Noxun::Engine::CabinetBuilder::CONFIG_SCHEMA)
  bsrc = NxD1.src('noxun_engine', 'core', 'board_builder.rb')
  guard = bsrc[/def newer_config\?\(cfg\).*?\n        end\n/m].to_s
  NxTest.assert(guard.include?('BOARD_CONFIG_SCHEMA'), 'doska sa meria svojim markerom')
  NxTest.refute(guard.include?('CabinetBuilder::CONFIG_SCHEMA'), 'a NIKDY kabinetovym')
  # Aktualna doska prejde, doska z novsej verzie nie — bez ohladu na to,
  # co je cislo korpusu.
  NxTest.refute(NxD1.bb.newer_config?('config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA))
  NxTest.assert(NxD1.bb.newer_config?('config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA + 1))
  NxTest.assert(Noxun::Engine::CabinetBuilder.newer_config?(
                  'config_schema' => Noxun::Engine::CabinetBuilder::CONFIG_SCHEMA + 1
                ), 'korpus si strazi svoje')
end

NxTest.test('GHOST-D1 brana: mutacne cesty dosky citaju RAW config PRED normalize') do
  bbsrc = NxD1.src('noxun_engine', 'core', 'board_builder.rb')
  reb = bbsrc[/def rebuild\(model, inst, params.*?\n        end\n/m].to_s
  NxTest.assert(reb.index('guard_newer_config!') < reb.index('normalize(merged)'),
                'rebuild: brana bezi nad RAW configom pred normalizaciou')
  NxTest.assert(reb.index('guard_newer_config!') < reb.index('start_operation'),
                'a pred otvorenim operacie (model ostava nedotknuty)')
  rio = bbsrc[/def rebuild_in_operation\(model, inst, bid, cfg, transform: nil\).*?\n        end\n/m].to_s
  NxTest.assert(rio.index('guard_newer_config!') < rio.index('inst.make_unique'),
                'rebuild_in_operation: brana pred kazdou mutaciou (davkove cesty)')

  ru = NxD1.src('noxun_engine', 'core', 'materials_replace_uni.rb')
  NxTest.assert(ru.include?("out['blocked'] << [bid, :board_schema, []]"),
                '„Nahradiť UNI": doska vyssej schemy ide do blocked planu')
  NxTest.assert(ru.index("out['blocked'] << [bid, :board_schema, []]") < ru.index('ru_deep_copy(cfg)'),
                'a to PRED akoukolvek pracou s configom')
  md = NxD1.src('noxun_engine', 'ui', 'materials_dialog.rb')
  NxTest.assert(md.include?("unless plan['blocked'].empty?"),
                'apply je all-or-nothing — neprazdny blocked zastavi CELU nahradu')

  # Codex #298 P2: brana zapisovych ciest KARTY stoji vo VSTUPNEJ brane
  # (`guarded_board`), nie az pri prestavbe — `handle_set_board_material` totiz
  # PRED rebuildom zapisuje do GLOBALNEHO KATALOGU (`resolve_virtual_material` ->
  # `ensure_duplak_for`, `ensure_missing_abs`), co sa uz nedá vrátiť.
  ab = NxD1.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')
  gb = ab[/def guarded_board\(data\).*?\n        end\n/m].to_s
  NxTest.assert(gb.include?('BoardBuilder.newer_config?'), 'vstupna brana karty pozna schemu')
  NxTest.assert(gb.index('BoardBuilder.newer_config?') < gb.index('[model, board]'),
                'a odmietne EST PRED tym, nez volajuci cokolvek spravi')
  mat = ab[/def handle_set_board_material\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(mat.index('guarded_board(data)') < mat.index('resolve_virtual_material'),
                'material: brana bezi PRED dovytvorenim duplaku v katalogu')
  NxTest.assert(mat.index('guarded_board(data)') < mat.index('ensure_missing_abs'),
                'material: brana bezi PRED dovytvorenim ABS pasky v katalogu')
  bulk = ab[/def handle_set_board_edges_all\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(bulk.index('guarded_board(data)') < bulk.index('ensure_missing_abs'),
                'olep vsetkych 4: brana bezi PRED zapisom do katalogu')
  ori = ab[/def handle_set_board_orientation\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(ori.include?('guarded_board(data)'), 'orientacia ide cez tu istu vstupnu branu')
end

NxTest.test('GHOST-D1 brana: doskova sablona z novsej verzie sa NEVLOZI a NEOPECIATKUJE') do
  ab = NxD1.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')
  ins = ab[/def handle_insert_board\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(ins.include?('newer_template_refusal'), 'vkladanie dosky MA downgrade branu sablony')
  NxTest.assert(ins.index('newer_template_refusal') < ins.index('BoardBuilder.prepare_insert'),
                'brana bezi PRED pripravou planu')
  NxTest.assert(ins.index('newer_template_refusal') < ins.index('GhostTool.start'),
                'a pred zalozenim session (ziadna session, ziadna peciatka)')
  at = NxD1.src('noxun_engine', 'ui', 'panel', 'actions_templates.rb')
  ref = at[/def newer_template_refusal\(ref, consequence\).*?\n        end\n/m].to_s
  NxTest.assert(ref.include?('BoardBuilder.newer_config?'), 'doskova sablona ma vlastny marker')
  NxTest.assert(ref.include?("kind.to_s == 'board'"), 'a rozhoduje DRUH zaznamu')
end

# ---------------------------------------------------------------------------
# 7) PECIATKA a BARIERA
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 peciatka: `stamp_once!` je PRESNE raz a LEN po uspesnom commite') do
  s = NxD1.session
  calls = 0
  # Esc: session zomrie bez commitu — peciatka sa NEVOLA (volajuci je
  # `ghost_after_commit_board`, ktory pri zrusenej session nebezi).
  NxTest.assert(s.cancel!('Esc'))
  NxTest.assert_equal(0, calls, 'Esc peciatku nezapise')
  # Po uspesnom commite: prve volanie zapise, druhe (dvojklik) uz nie.
  s2 = NxD1.session
  NxTest.assert(s2.stamp_once! { calls += 1 })
  NxTest.refute(s2.stamp_once! { calls += 1 }, 'druhy pokus je no-op')
  NxTest.assert_equal(1, calls)
end

NxTest.test('GHOST-D1 peciatka: `template_ref` nesie SESSION (nie synchronna cesta)') do
  s = NxD1.gt::PlacementSession.new(model: Object.new, plan: NxD1.plan, subject: :board,
                                    memory: NxD1.fresh_memory, template_ref: %w[board Zástena])
  NxTest.assert_equal(%w[board Zástena], s.template_ref)
  ab = NxD1.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')
  after = ab[/def ghost_after_commit_board\(model, inst, session\).*?\n        end\n/m].to_s
  NxTest.assert(after.include?('session.stamp_once!'), 'peciatka az po commite, cez stamp_once!')
end

NxTest.test('GHOST-D1 bariera: `flush_pending! == false` vrati :blocked bez akejkolvek stopy') do
  s = NxD1.session
  s.set_point([100.0, 200.0, 300.0])
  # Realny modul sa NEPREKRYVA — metoda sa len docasne ALIASUJE (prekrytie
  # konstantou by observer vzalo aj nasledujucim sadam).
  sc = Noxun::Engine::ScaleWatch.singleton_class
  sc.send(:alias_method, :flush_pending_nxd1_orig, :flush_pending!)
  sc.send(:define_method, :flush_pending!) { |_m = nil| false }
  begin
    NxTest.assert_equal(:blocked, s.commit!(:fake_transform), 'sev vrati EXPLICITNY :blocked')
    NxTest.assert(s.active?, 'session ZOSTAVA v stave umiestnovania')
    NxTest.refute(s.terminal?, 'nie je terminalna')
    NxTest.refute(s.committing?, 'a NIKDY neskonci falosne ako :committed')
    NxTest.assert_equal(nil, s.cancel_reason, 'a nic sa nezrusilo')
  ensure
    sc.send(:alias_method, :flush_pending!, :flush_pending_nxd1_orig)
    sc.send(:remove_method, :flush_pending_nxd1_orig)
  end
  NxTest.assert(Noxun::Engine::ScaleWatch.flush_pending!(nil), 'original je spat (pokoj = true)')
end

# In-SU beh 2 (#298): sonda hlasila, ze observer NIE JE v pokoji na vstupe do
# `commit_insert`. Sonda merala zle (hola konstanta v `define_method` bloku ->
# nil), ale ORDER kontrakt si zasluzi vlastny headless dokaz — bez neho by sa
# to zistilo az v SketchUpe. Meria sa PRESNE to, co ma platit: medzi barierou
# a otvorenim vytvaracej operacie NESMIE nic observer znovu naarmovat.
NxTest.test('GHOST-D1 bariera: medzi barierou a commitom observer UZ NIKTO nenaarmuje') do
  sw = Noxun::Engine::ScaleWatch.singleton_class
  bb = Noxun::Engine::BoardBuilder.singleton_class
  order = []
  seen_pending = :NEBEZALO
  queue = [:cakajuca_praca] # observer MA co robit, inak by test nic nemeral

  sw.send(:alias_method, :flush_pending_ord_orig, :flush_pending!)
  sw.send(:alias_method, :pending_ord_orig, :pending?)
  sw.send(:alias_method, :request_dedup_ord_orig, :request_dedup)
  bb.send(:alias_method, :commit_insert_ord_orig, :commit_insert)
  begin
    # Stub observera: `flush_pending!` frontu vyprazdni (dosiahne pokoj),
    # `request_dedup` ju znovu naplni — presne ako `push_selected` v paneli.
    sw.send(:define_method, :flush_pending!) { |_m = nil| order << :flush; queue.clear; true }
    sw.send(:define_method, :pending?) { !queue.empty? }
    sw.send(:define_method, :request_dedup) { |_m| order << :request_dedup; queue << :dedup; nil }
    # Stub sevu: zaznamena stav observera PRESNE na vstupe (= tesne pred tym,
    # nez by sa otvorila vytvaracia operacia).
    watch = Noxun::Engine::ScaleWatch
    bb.send(:define_method, :commit_insert) do |_model, _plan, transform:, orientation: nil|
      order << :commit_insert
      seen_pending = watch.pending?
      :fake_board
    end

    s = NxD1.session
    s.set_point([100.0, 200.0, 300.0])
    NxTest.assert(Noxun::Engine::ScaleWatch.pending?, 'vychodisko: observer MA pracu')
    s.commit!(:fake_transform)

    NxTest.assert_equal(false, seen_pending,
                        'na vstupe do sevu je observer v POKOJI (bariera dobehla a nikto ju nezrusil)')
    NxTest.assert_equal(%i[flush commit_insert], order.first(2),
                        "bariera bezi PRVA a hned za nou sev — poradie: #{order.inspect}")
    NxTest.refute(order[0...order.index(:commit_insert)].include?(:request_dedup),
                  'PRED sevom sa observer nesmie znovu naarmovat (ziadny push panela)')
  ensure
    sw.send(:alias_method, :flush_pending!, :flush_pending_ord_orig)
    sw.send(:alias_method, :pending?, :pending_ord_orig)
    sw.send(:alias_method, :request_dedup, :request_dedup_ord_orig)
    bb.send(:alias_method, :commit_insert, :commit_insert_ord_orig)
    %i[flush_pending_ord_orig pending_ord_orig request_dedup_ord_orig].each { |m| sw.send(:remove_method, m) }
    bb.send(:remove_method, :commit_insert_ord_orig)
  end
end

NxTest.test('GHOST-D1 bariera: preflighty sevu su LEN CITANIE (nic, co by observer naarmovalo)') do
  s = NxD1.src('noxun_engine', 'core', 'board_builder.rb')
  body = s[/def commit_insert\(model, plan, transform:, orientation: nil\).*?\n        end\n/m].to_s
  pre = body[0...body.index('guarded do')].to_s
  NxTest.assert(!pre.empty?, 'preflightova cast sevu sa nasla')
  # `ensure_root!` (close_active) a `Ids.next_board_id` (sken atributov) su
  # jedine, co tu bezi — ani jedno nezapisuje do entit.
  %w[Panel. push_selected request_dedup select_only push_state notify_ set_attribute].each do |bad|
    NxTest.refute(pre.include?(bad), "preflight sevu nesmie volat `#{bad}` (naarmoval by observer)")
  end
  gt = NxD1.src('noxun_engine', 'core', 'ghost_tool.rb')
  cm = gt[/def commit!\(transform\).*?\n        end\n/m].to_s
  head = cm[0...cm.index('commit_subject!(transform)')].to_s
  %w[Panel. push_state push_selected request_dedup].each do |bad|
    NxTest.refute(head.include?(bad), "medzi barierou a sevom nesmie byt `#{bad}`")
  end
  # Push panela patri AZ za commit (dnes `ghost_after_commit`).
  NxTest.assert(cm.index('commit_subject!(transform)') < cm.index('Panel.ghost_after_commit'),
                'refresh panela bezi AZ PO commite')
end

NxTest.test('GHOST-D1 bariera: bezi PRED `begin_commit!` (poradie v zdrojaku)') do
  s = NxD1.src('noxun_engine', 'core', 'ghost_tool.rb')
  body = s[/def commit!\(transform\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('settle_observer!'), 'commit MA barieru observera')
  NxTest.assert(body.index('settle_observer!') < body.index('begin_commit!'),
                'bariera je PRED vstupom do commitu')
  NxTest.assert(body.include?('return :blocked unless settle_observer!'))
  st = s[/def settle_observer!.*?\n        end\n/m].to_s
  NxTest.assert(st.include?('ScaleWatch.flush_pending!'), 'bariera vola explicitne API observera')
end

# ---------------------------------------------------------------------------
# 8) SEV SUBJEKTU + kabinetove callbacky odmietnute
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 sev: commit ide podla SUBJEKTU (orientacia SAMOSTATNYM argumentom)') do
  s = NxD1.src('noxun_engine', 'core', 'ghost_tool.rb')
  body = s[/def commit_subject!\(transform\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('BoardBuilder.commit_insert(@model, @plan, transform: transform, orientation: @orientation)'),
                'doska: orientacia zo SESSION ide samostatne (z matice sa odvodit neda)')
  NxTest.assert(body.include?('CabinetBuilder.commit_insert(@model, @plan, transform: transform)'),
                'skrinka: sev R-03 nezmeneny')
end

NxTest.test('GHOST-D1: `ghost_lock_z` je pre board session ODMIETNUTY (kontrola subjektu)') do
  s = NxD1.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  body = s[/def handle_ghost_lock_z\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('unless s.cabinet?'), 'rozhoduje SUBJEKT session, nie „je aktivna"')
  NxTest.assert(body.index('unless s.cabinet?') < body.index('Calc.lock_z_value'),
                'a odmietnutie pride pred akymkolvek citanim hodnoty')
  # JS pole sa pre dosku ani neposiela (dvojita obrana; sada test_ghost_d1_pasik.js).
  js = NxD1.src('noxun_engine', 'ui', 'js', 'ghost_bar.js')
  NxTest.assert(js.include?("if (nxGhostSubject(nxGhostState) === 'board') return;"),
                'klient pole vysky pre dosku neposiela')
end

# Codex #298 P2: STANDARD 8.3 slubuje READ-ONLY kartu s vysvetlenim. Server je
# jedina autorita — payload nesie priznak aj TEXT, klient si neodvodzuje nic.
NxTest.test('GHOST-D1 karta: payload dosky z NOVSEJ verzie nesie priznak aj vysvetlenie') do
  NxTest.skip!('payloads.rb sa headless nacita zvlast') unless NxTest.headless?
  pay = Noxun::Engine::Panel
  NxTest.assert_equal({}, pay.board_newer_flag({}), 'legacy doska priznak NEMA')
  NxTest.assert_equal({}, pay.board_newer_flag('config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA),
                      'aktualna doska tiez nie')
  flag = pay.board_newer_flag('config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA + 1)
  NxTest.assert_equal(true, flag['newer_config'], 'vyssia schema priznak MA')
  note = flag['newer_config_note'].to_s
  NxTest.assert(note.include?('novšej verzie'), note)
  NxTest.assert(note.include?('nedá upraviť'), "hlaska povie, ze karta je read-only: #{note}")
  NxTest.assert(note.include?('Aktualizuj plugin'), "a kam ist: #{note}")
  # Jazyk je slovencina a symboly patria do sprite — v texte ziadne emoji.
  NxTest.refute(note.match?(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/), 'hlaska je bez emoji')
  # Priznak sa PRIMIESAVA do board_payload (jedno miesto, aditivne polia).
  src = NxD1.src('noxun_engine', 'ui', 'panel', 'payloads.rb')
  body = src[/def board_payload\(inst\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('board_newer_flag(cfg)'), 'board_payload priznak posiela')
  # POZOR (mutacia 10): hladat `applyBoardReadOnly(bc)` v CELOM subore nestaci —
  # vyhovel by uz jej vlastnej DEFINICII. Meria sa VOLANIE vo vnutri
  # `renderBoardCard`, teda ze zamok naozaj bezi pri kazdom prekresleni karty.
  js = NxD1.src('noxun_engine', 'ui', 'js', 'board_card.js')
  render = js[/function renderBoardCard\(bc\)\{.*?\n  \}\n/m].to_s
  NxTest.assert(!render.empty?, 'renderBoardCard sa nasla')
  NxTest.assert(render.include?('applyBoardReadOnly(bc);'), 'karta zamok APLIKUJE pri prekresleni')
  NxTest.assert(render.index('nxComboSync(box)') < render.index('applyBoardReadOnly(bc);'),
                'zamok bezi AZ NAKONIEC (prebije vsetko, co karta vyssie odomkla)')
  NxTest.assert(js.include?('function applyBoardReadOnly(bc)'), 'a funkcia existuje')
end

NxTest.test('GHOST-D1: karta Dosky ma v D1 JEDNO tlacidlo — `draw_board` NIE JE whitelistovany') do
  panel = NxD1.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.refute(panel.include?('draw_board'), 'callback kreslenia (D2) sa v D1 neregistruje')
  NxTest.assert(panel.include?("cb(dlg, 'insert_board')"), 'vkladanie ostava jediny doskovy vstup')
end

# ---------------------------------------------------------------------------
# 9) MARKER V PERZISTOVANYCH ZAZNAMOCH SABLON (seed / upsert / migracia)
#    Testuje sa NACITANY zaznam zo suboru, nie umelo oznacena fixture.
# ---------------------------------------------------------------------------

module NxD1Tpl
  TS = Noxun::Engine::TemplateStore
  JFS = Noxun::Engine::JsonFileStore

  module_function

  def reset!
    [TS.path, Noxun::Engine::TemplateUsage.path].each do |p|
      FileUtils.rm_f(p)
      FileUtils.rm_f("#{p}.bak")
      JFS.invalidate(p)
    end
  end

  def write_raw!(payload)
    FileUtils.mkdir_p(TS.dir)
    File.binwrite(TS.path, JSON.generate(payload))
    FileUtils.rm_f("#{TS.path}.bak")
    JFS.invalidate(TS.path)
  end

  def raw
    JSON.parse(File.binread(TS.path))
  end

  def schema_of(name)
    rec = TS.find('board', name)
    rec && rec['config']['config_schema']
  end

  # Doskovy zaznam v tvare std 3 (s orientaciou, BEZ markera schemy).
  def std3(name, extra = {})
    { 'name' => name, 'kind' => 'board',
      'config' => { 'material_id' => nil, 'length' => 800.0, 'width' => 600.0,
                    'thickness' => 18.0, 'grain_direction' => 'length',
                    'orientation' => 'leziaca', 'type' => 'board' }.merge(extra) }
  end
end

NxTest.test('GHOST-D1 sablony: SEED cerstvej instalacie nesie marker (citany zo SUBORU)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD1Tpl.reset!
  NxD1Tpl::TS.load # cerstva instalacia: seed + zapis
  %w[Diel Pracovná\ doska Zástena].each do |name|
    NxTest.assert_equal(NxD1.bb::BOARD_CONFIG_SCHEMA, NxD1Tpl.schema_of(name),
                        "#{name}: seed zapisal marker")
  end
  # A rovnako je marker aj v SUBORE na disku (nie len v nacitanej mape).
  boards = NxD1Tpl.raw['templates'].select { |t| t['kind'] == 'board' }
  NxTest.assert_equal(3, boards.length)
  NxTest.assert(boards.all? { |t| t['config']['config_schema'] == NxD1.bb::BOARD_CONFIG_SCHEMA },
                'marker je perzistovany')
end

NxTest.test('GHOST-D1 sablony: UPSERT bez markera je ODMIETNUTY (nie „legacy" zapis)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD1Tpl.reset!
  NxD1Tpl::TS.load
  NxTest.assert_equal(false, NxD1Tpl::TS.upsert('board', 'Bez markera', 'length' => 500.0),
                      'zapis bez markera neprejde')
  NxTest.assert_equal(nil, NxD1Tpl::TS.find('board', 'Bez markera'), 'a zaznam nevznikol')
  NxTest.assert_equal(false, NxD1Tpl::TS.upsert('board', 'Nula', 'config_schema' => 0),
                      'nula nie je marker')
  # So SPRAVNYM markerom prejde a marker je v NACITANOM zazname.
  NxTest.assert_equal(true, NxD1Tpl::TS.upsert('board', 'S markerom',
                                               'length' => 500.0, 'width' => 400.0,
                                               'config_schema' => NxD1.bb::BOARD_CONFIG_SCHEMA))
  NxTest.assert_equal(NxD1.bb::BOARD_CONFIG_SCHEMA, NxD1Tpl.schema_of('S markerom'))
  # KORPUSOVA sablona sa touto branou NEDOTKNE (ma vlastny kontrakt).
  NxTest.assert_equal(true, NxD1Tpl::TS.upsert('cabinet', 'Bez markera', 'type' => 'lower'))
end

# Codex #298 P1 (in-SU FAIL ŠT-3c-1): zapis doskovej sablony BEZ markera sa
# odmietne — takze KAZDY volajuci v repe ho musi niest. Grep je tu preto, aby
# sa dalsia fixture nedostala do maina a nezhodila sekciu az v SketchUpe.
NxTest.test('GHOST-D1 sablony: ZIADNY volajuci `upsert(board, …)` v repe nie je bez markera') do
  root = NxTest::ROOT
  files = Dir[File.join(root, 'noxun_engine', '**', '*.rb')] +
          Dir[File.join(root, 'tests', '**', '*.rb')]
  offenders = []
  files.each do |f|
    next if f.end_with?('test_ghost_d1_dosky.rb') # scenare brany nizsie testuju PRAVE odmietnutie

    # Komentare sa vyhadzuju — `templates.rb` v nich cituje volanie ako priklad.
    code = File.read(f, encoding: 'UTF-8').lines.reject { |l| l =~ /\A\s*#/ }.join
    code.scan(/upsert\(\s*'board'.{0,400}?\)\n/m) do |snippet|
      next if snippet.include?('config_schema') || snippet.include?('BOARD_CONFIG_SCHEMA')
      next if snippet.include?('board_cfg') # helper, ktory marker nesie

      offenders << "#{File.basename(f)}: #{snippet.strip[0, 70]}"
    end
  end
  NxTest.assert_equal([], offenders, 'doskovy upsert bez markera by sklad ODMIETOL')
end

NxTest.test('GHOST-D1 sablony: MIGRACIA std 3 -> 4 dopise marker existujucim doskam') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD1Tpl.reset!
  NxD1Tpl.write_raw!({ 'std' => 3,
                       'templates' => [NxD1Tpl.std3('Diel'),
                                       NxD1Tpl.std3('Z novšej', 'config_schema' => 99),
                                       { 'name' => 'Dolna klasik', 'kind' => 'cabinet',
                                         'config' => { 'type' => 'lower' } }] })
  NxD1Tpl::TS.load
  NxTest.assert_equal(NxD1Tpl::TS::STD, NxD1Tpl.raw['std'], 'marker suboru sa posunul')
  NxTest.assert_equal(NxD1.bb::BOARD_CONFIG_SCHEMA, NxD1Tpl.schema_of('Diel'),
                      'zaznam bez markera dostal DNESNY tvar (1)')
  NxTest.assert_equal(99, NxD1Tpl.schema_of('Z novšej'),
                      'EXPLICITNA hodnota z novsej verzie ostava NEDOTKNUTA')
  cab = NxD1Tpl::TS.find('cabinet', 'Dolna klasik')
  NxTest.refute(cab['config'].key?('config_schema'), 'korpusovej sablony sa migracia netyka')
  # Migrovany zaznam z NOVSEJ verzie sa uz nevlozi — brana ho odmietne.
  NxTest.assert(NxD1.bb.newer_config?(NxD1Tpl::TS.find('board', 'Z novšej')['config']),
                'doskova sablona so schemou 99 je „novsi config"')
  NxTest.refute(NxD1.bb.newer_config?(NxD1Tpl::TS.find('board', 'Diel')['config']),
                'migrovana doskova sablona prejde')
ensure
  # Kniznica ostava po tejto sade v CERSTVOM (nasejdenom) stave — dalsie sady
  # ju citaju ako pri novej instalacii.
  if NxTest.headless?
    NxD1Tpl.reset!
    NxD1Tpl::TS.load
  end
end

# ---------------------------------------------------------------------------
# 10) VYROBNE VYSTUPY: doska vyssej schemy zastavi VSETKY z nich
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D1 vystupy: zaznam `newer_configs` nesie DRUH a rozlisi Skrinku od Dosky') do
  bom = Noxun::Engine::Bom
  list = []
  bom.note_newer_config(list, 'cabinet', 'CAB-001')
  bom.note_newer_config(list, 'board', 'BRD-002')
  bom.note_newer_config(list, 'board', 'BRD-002') # duplicita sa nezapise
  bom.note_newer_config(list, 'board', '')        # prazdne ID sa nezapise
  NxTest.assert_equal([{ 'kind' => 'cabinet', 'id' => 'CAB-001' },
                       { 'kind' => 'board', 'id' => 'BRD-002' }], list)

  items = []
  Noxun::Engine::Validation.check_newer_configs(list, items)
  NxTest.assert_equal(2, items.length)
  NxTest.assert(items[0]['message_sk'].start_with?('Skrinka CAB-001'), items[0]['message_sk'])
  NxTest.assert(items[1]['message_sk'].start_with?('Doska BRD-002'), items[1]['message_sk'])
  # Zoznam blokovanych vystupov je UPLNY (kusovnik aj VEPO, nielen tri cenove).
  %w[Kusovník VEPO nákupný rozpočet ponuka].each do |w|
    NxTest.assert(items[1]['message_sk'].include?(w), "hlaska menuje #{w}: #{items[1]['message_sk']}")
  end
  NxTest.assert_equal('red', items[1]['severity'], 'novsia schema je RED')
  NxTest.assert_equal('newer_config|BRD-002', items[1]['stable_key'])
end

NxTest.test('GHOST-D1 vystupy: brana exportov menuje druh aj VSETKY blokovane vystupy') do
  pc = Noxun::Engine::ProductionCore
  b = pc.export_blockers(newer: [{ 'kind' => 'board', 'id' => 'BRD-002' }])
  NxTest.assert_equal(1, b.length)
  NxTest.assert(b.first.include?('Doska BRD-002'), b.first)
  %w[kusovník VEPO nákup rozpočet ponuka].each do |w|
    NxTest.assert(b.first.include?(w), "brana menuje #{w}: #{b.first}")
  end
  # Zmiesany zoznam + strop na tri (jedno znenie pre vsetky zoznamy ID).
  mixed = pc.export_blockers(newer: [{ 'kind' => 'cabinet', 'id' => 'CAB-001' },
                                     { 'kind' => 'board', 'id' => 'BRD-002' },
                                     { 'kind' => 'board', 'id' => 'BRD-003' },
                                     { 'kind' => 'board', 'id' => 'BRD-004' }])
  NxTest.assert(mixed.first.include?('Skrinka CAB-001') && mixed.first.include?('Doska BRD-002'),
                mixed.first)
  NxTest.assert(mixed.first.include?('a ďalšie 1'), "strop na tri: #{mixed.first}")
  # Legacy tvar (holy String) sa dalej cita ako skrinka.
  NxTest.assert(pc.export_blockers(newer: %w[CAB-009]).first.include?('Skrinka CAB-009'))
  NxTest.assert_equal([], pc.export_blockers(newer: []), 'cista zakazka nema dovod')
end

NxTest.test('GHOST-D1 vystupy: zber prizna dosku z novsej verzie EST PRED filtrom manufactured') do
  bom = NxD1.src('noxun_engine', 'core', 'bom.rb')
  brd = bom[/when 'board'(.*?)when 'part'/m, 1].to_s
  NxTest.assert(!brd.empty?, 'vetva dosky sa nasla')
  NxTest.assert(brd.include?("note_newer_config(newer_configs, 'board', newer_address(inst, bid))"),
                'zber dosku z novsej verzie PRIZNAVA (a to aj bez vyrobneho ID)')
  NxTest.assert(brd.index("note_newer_config(newer_configs, 'board', newer_address(inst, bid))") <
                brd.index("next unless Store.get(inst, 'manufactured') == true"),
                'brana bezi PRED filtrom manufactured (fail-closed)')
end

# Codex #298 P1: entita `kind: board` s VYSSOU schemou, ale CHYBAJUCIM alebo
# poskodenym `id`, sa dalej podiela na `records` (zname polia), takze VEPO
# a ostatne vystupy by pokracovali s TICHO orezanym novsim configom. Blocker
# preto nesmie zaniknut spolu s ID — dostane STABILNU adresu entity.
NxTest.test('GHOST-D1 vystupy: blocker PREZIJE aj bez vyrobneho ID (stabilna adresa entity)') do
  bom = Noxun::Engine::Bom
  ent = Struct.new(:persistent_id, :entityID).new(987_654, 42) # rubocop:disable Naming/VariableName
  NxTest.assert_equal('BRD-002', bom.newer_address(ent, 'BRD-002'), 'ID ma prednost')
  NxTest.assert_equal('BRD-002', bom.newer_address(ent, '  BRD-002  '), 'a orezava sa')
  addr = bom.newer_address(ent, '')
  NxTest.assert_equal('bez ID (pid 987654)', addr, 'bez ID sa pouzije persistent_id')
  NxTest.assert_equal(addr, bom.newer_address(ent, nil), 'nil aj prazdny retazec su to iste')

  # A takyto zaznam sa NAOZAJ dostane do zoznamu (`note_newer_config` ho uz nezahodi)
  # a prejde celou retazou az k hlaske Kontroly aj k brane exportov.
  list = []
  bom.note_newer_config(list, 'board', addr)
  NxTest.assert_equal([{ 'kind' => 'board', 'id' => addr }], list, 'blocker sa NEZAHADZUJE')
  items = []
  Noxun::Engine::Validation.check_newer_configs(list, items)
  NxTest.assert_equal(1, items.length, 'Kontrola nalez ukaze')
  NxTest.assert(items.first['message_sk'].start_with?("Doska #{addr}"), items.first['message_sk'])
  b = Noxun::Engine::ProductionCore.export_blockers(newer: list)
  NxTest.assert_equal(1, b.length, 'a export sa zastavi')
  NxTest.assert(b.first.include?("Doska #{addr}"), b.first)

  # Entita bez `persistent_id` (starsie API / fake) spadne na `entityID`.
  old = Struct.new(:entityID).new(7) # rubocop:disable Naming/VariableName
  NxTest.assert_equal('bez ID (pid 7)', bom.newer_address(old, ''))
  NxTest.assert_equal('bez ID (pid ?)', bom.newer_address(Object.new, ''), 'a bez oboch sa nespadne')
end

NxTest.test('GHOST-D1 vystupy: to iste plati pre SKRINKU bez cabinet_id') do
  bom = NxD1.src('noxun_engine', 'core', 'bom.rb')
  NxTest.assert(bom.include?("note_newer_config(newer_configs, 'cabinet', newer_address(inst, cid))"),
                'kabinetova vetva ma tu istu poistku (rovnaka trieda chyby)')
end

NxTest.test('GHOST-D1 vystupy: VEPO uz vynimku NEMA — brana bezi PRED vyberom priecinka') do
  pc = NxD1.src('noxun_engine', 'ui', 'production_core.rb')
  body = pc[/def do_export\(model, data, generation:, status:, repush:\).*?\n      def /m].to_s
  NxTest.assert(body.include?('newer_stop = newer_config_stop(collected)'), 'VEPO ma branu')
  NxTest.assert(body.index('newer_config_stop') < body.index('UI.select_directory'),
                'brana bezi PRED vyberom priecinka (picker sa ani neotvori)')
  NxTest.assert(body.index('fresh_collect(model)') < body.index('newer_config_stop'),
                'a nad CERSTVYM zberom')
  NxTest.assert_equal(4, pc.scan('newer_stop = newer_config_stop(collected)').length,
                      'branu maju VSETKY STYRI exporty')
end
