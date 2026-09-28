# frozen_string_literal: true
# ROH-B2 · K3 — KRESBA ROHOVEJ ZOSTAVY, klavesa strany dveri pri vkladani (blok 8).
# Package: SYSTEM/archiv/bloky/ROHOVA/PACKAGE_ROHB2.md (mockup C, B · Čelá, O12, A).
#
# CO PLATI:
#   * KRESBU pocita server: `Panel.corner_preview_json` = `Construction.corner_parts`
#     nad `CabinetBuilder.normalize` (ta ista autorita ako stavba) — dielce
#     zostavy v celnom pohlade su PRESNE plan (obe strany), koty dverovej casti
#     a CR 1, `fits`/`need` = `corner_fit_width`, `door_w` = `Fronts.resolve_layout`,
#     `stats` = vsetky dielce zostavy; iny typ = nil, zly vstup = nil (nepadne);
#   * preflight: kresba zo ZIVYCH poli (strana z ulozeneho configu, D/CR v rozsahu
#     zo formulara, inak posledny platny zdroj — ta ista funkcia ako otvor);
#   * payload oznacenej: `corner_preview` len pri rohovej (parita ostatnych typov);
#   * GHOST: klavesa D vlastni LEN ghost rohovej pri umiestnovani a len ju
#     OHLASI panelu (`Panel.ghost_corner_side_key`) — zrkadlo robi karta;
#     pasik a status nesu stranu; prevesenie (`keep_point`) prevezme polohu.
#
# MUTACIE (overene pri davke, report):
#   M6 `corner_side_key?` bez podmienky rohovej -> „klavesa D len pri rohovej"
#   M7 `start` bez prevzatia polohy             -> „prevesenie drzi polohu"
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet actions_templates payloads sync resolvers].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
end

module NxRohB2
  module_function

  E  = Noxun::Engine
  CB = E::CabinetBuilder
  CN = E::Construction
  PN = E::Panel
  GT = E::GhostTool

  FRONTS = { 'gap' => 3.0, 'gap_top' => 2.0, 'gap_bottom' => 2.0, 'gap_left' => 2.0, 'gap_right' => 2.0,
             'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }.freeze

  def params(over = {})
    { 'type' => 'corner_blind', 'width' => 1100.0, 'height' => 720.0, 'depth' => 510.0, 'thickness' => 18.0,
      'floor_height' => 100.0, 'corner_side' => 'left', 'corner_door_w' => 450.0, 'corner_cr1' => 80.0,
      'corner_cr2' => 80.0, 'fronts' => JSON.parse(JSON.generate(FRONTS)) }.merge(over)
  end

  def stored(over = {})
    JSON.parse(JSON.generate(CB.cabinet_config(CB.normalize(params(over)))))
  end

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  # Dielce zostavy z PLANU stavby (celny pohlad: X a Z obdlznika).
  def plan_rects(p, pt = {})
    CN.build_plan(CB.normalize(p), 'CAB-1', part_thicknesses: pt)[:parts]
      .select { |pd| CN::CORNER_ROLES.include?(pd[:role]) }
      .to_h { |pd| [pd[:role], [pd[:origin][0], pd[:origin][0] + pd[:box][0], pd[:origin][2], pd[:origin][2] + pd[:box][2]].map { |v| v.to_f.round(2) }] }
  end

  def rects(cp)
    cp['parts'].to_h { |p| [p['role'], p.values_at('x0', 'x1', 'z0', 'z1')] }
  end

  class FakeTools
    attr_reader :pushed

    def initialize
      @pushed = []
    end

    def push_tool(t)
      @pushed << t
    end

    def pop_tool; end
  end

  class FakeModel
    attr_reader :tools

    def initialize
      @tools = FakeTools.new
    end

    def path
      'C:/tmp/rohb2.skp'
    end
  end

  # Stub singleton metod (vzor test_rohb1_strana.rb; chybajuce sa po teste zmazu).
  def with_stubs(entries)
    saved = []
    entries.each do |(mod, name, impl)|
      sc = mod.singleton_class
      had = sc.method_defined?(name) || sc.private_method_defined?(name)
      saved << [sc, name, had ? sc.instance_method(name) : nil]
      sc.send(:define_method, name, &impl)
    end
    yield
  ensure
    saved.reverse_each do |(sc, name, orig)|
      orig ? sc.send(:define_method, name, orig) : sc.send(:remove_method, name)
    end
  end

  # Spusti `handle_ghost_corner_side` s podstrcenym prostredim.
  #   live   = session, ktora visi na kurzore (alebo nil)
  #   insert = co spravi `handle_insert` (lambda nad logom), foreign = cudzi dokument
  # -> [log, session po volani]
  def ghost_switch(model:, live:, insert:, foreign: false)
    log = []
    su = Module.new
    su.define_singleton_method(:active_model) { model }
    prev = GT.session
    GT.instance_variable_set(:@session, live)
    stubs = [
      [PN, :set_status, ->(msg, err = false) { log << [:status, msg, err] }],
      [PN, :js, ->(script) { log << [:js, script] }],
      [PN, :handle_insert, ->(payload, keep_point: false) { log << [:insert, keep_point]; insert.call(payload, log) }]
    ]
    Object.const_set(:Sketchup, su)
    begin
      with_stubs(stubs) do
        payload = { 'model_guid' => foreign ? 'CUDZI' : E::DocKey.key(model), 'type' => 'corner_blind',
                    'corner_side' => 'right' }
        PN.handle_ghost_corner_side(payload.to_json)
      end
      [log, GT.session]
    ensure
      Object.send(:remove_const, :Sketchup)
      GT.instance_variable_set(:@session, prev)
    end
  end

  def fresh_memory
    { anchor: GT::ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
  end

  def session(cfg_over = {}, model: Object.new)
    cfg = CB.normalize(params(cfg_over))
    GT::PlacementSession.new(model: model, plan: CB::InsertPlan.new(model, cfg, 0.0), memory: fresh_memory)
  end

  # Docasna nahrada `Panel.ghost_corner_side_key` (zaznam volani).
  def with_key_spy
    calls = []
    sc = PN.singleton_class
    sc.send(:alias_method, :nx_b2_orig_key, :ghost_corner_side_key)
    sc.send(:define_method, :ghost_corner_side_key) { |side| calls << side }
    begin
      yield calls
    ensure
      sc.send(:alias_method, :ghost_corner_side_key, :nx_b2_orig_key)
      sc.send(:remove_method, :nx_b2_orig_key)
    end
  end
end

# ============================================================================
# 1. KRESBA ZOSTAVY = PLAN STAVBY
# ============================================================================

NxTest.test('ROH-B2: kresba zostavy = dielce planu stavby (dvere vlavo aj vpravo), poradie kreslenia') do
  %w[left right].each do |side|
    p = NxRohB2.params('corner_side' => side)
    cp = NxRohB2::PN.corner_preview_json(p, {})
    NxTest.assert_equal(%w[corner_blind_panel corner_rail cr_front cr_side], cp['parts'].map { |x| x['role'] },
                        "#{side}: blenda vzadu, potom vystuha a CR listy (vystuha zavesov je za dverami)")
    plan = NxRohB2.plan_rects(p)
    cp['parts'].each do |part|
      NxTest.assert_equal(plan[part['role']], part.values_at('x0', 'x1', 'z0', 'z1'),
                          "#{side}: #{part['role']} = plan stavby na mm")
    end
    NxTest.assert_equal(side, cp['side'])
  end
  l = NxRohB2.rects(NxRohB2::PN.corner_preview_json(NxRohB2.params, {}))
  NxTest.assert_equal([450.0, 1082.0, 118.0, 702.0], l['corner_blind_panel'], 'blenda D…W−t, vnutro dno…strop')
  NxTest.assert_equal([[548.0, 566.0], [452.0, 530.0], [530.0, 548.0]],
                      [l['corner_rail'][0, 2], l['cr_front'][0, 2], l['cr_side'][0, 2]], 'vystuha, CR 1 (od okraja pri rohu), CR 2')
end

NxTest.test('ROH-B2: koty dverovej casti a CR 1 (zrkadlene), sirka dveri, pocet a plocha zostavy') do
  cp = NxRohB2::PN.corner_preview_json(NxRohB2.params, {})
  NxTest.assert_equal([[0.0, 450.0, '450'], [450.0, 530.0, '80']], cp['dims'].map { |d| d.values_at('x0', 'x1', 'label') })
  cr = NxRohB2::PN.corner_preview_json(NxRohB2.params('corner_side' => 'right'), {})
  NxTest.assert_equal([[650.0, 1100.0, '450'], [570.0, 650.0, '80']], cr['dims'].map { |d| d.values_at('x0', 'x1', 'label') },
                      'dvere vpravo: koty od pravého boku')
  NxTest.assert_equal(446.0, cp['door_w'], 'sirka dveri = 450 − 2 − 2')
  g = NxRohB2.params
  g['fronts']['gap_left'] = 0.0
  NxTest.assert_equal(448.0, NxRohB2::PN.corner_preview_json(g, {})['door_w'], 'vonkajsi okraj 0 -> 448')
  NxTest.assert_equal(5, cp['stats']['count'], 'odhad: 5 dielcov zostavy (aj vystuha zavesov)')
  plan = NxRohB2::CN.build_plan(NxRohB2::CB.normalize(NxRohB2.params), 'CAB-1')[:parts]
                    .select { |pd| NxRohB2::CN::CORNER_ROLES.include?(pd[:role]) }
  area = (plan.sum { |pd| pd[:prod][:length] * pd[:prod][:width] } / 1_000_000.0).round(3)
  NxTest.assert_equal(area, cp['stats']['area'], 'plocha = vyrobne rozmery planu')
  NxTest.assert(cp['parts'].first['title'].include?('632 × 584'), 'bublina nesie rozmery dielca')
end

NxTest.test('ROH-B2: nezmestena zostava — fits false a najmensia sirka (aj s CR 2 z 19 mm)') do
  cp = NxRohB2::PN.corner_preview_json(NxRohB2.params('width' => 560.0), {})
  NxTest.assert_equal([false, 584.0], cp.values_at('fits', 'need'))
  NxTest.assert_equal([true, 584.0], NxRohB2::PN.corner_preview_json(NxRohB2.params('width' => 584.0), {}).values_at('fits', 'need'),
                      'presne na hranici sa zmesti')
  pt = { NxRohB2::CN::CR_PART_KEYS[1] => 19.0 }
  c19 = NxRohB2::PN.corner_preview_json(NxRohB2.params('width' => 584.0), pt)
  NxTest.assert_equal([false, 585.0], c19.values_at('fits', 'need'), 'CR 2 z 19 mm: 585')
  NxTest.assert_equal(NxRohB2.plan_rects(NxRohB2.params('width' => 900.0), pt)['cr_side'],
                      NxRohB2.rects(NxRohB2::PN.corner_preview_json(NxRohB2.params('width' => 900.0), pt))['cr_side'],
                      'hrubka CR 2 z mapy hrubok = plan')
end

NxTest.test('ROH-B2: strop z vystuh zmeni vysku blendy (interior), iny typ a zly vstup = nil') do
  full = NxRohB2.rects(NxRohB2::PN.corner_preview_json(NxRohB2.params, {}))['corner_blind_panel']
  rails = NxRohB2.rects(NxRohB2::PN.corner_preview_json(NxRohB2.params('top_mode' => 'two_rails', 'rails_orientation' => 'upright'), {}))['corner_blind_panel']
  NxTest.assert(rails[3] < full[3], 'dve vystuhy: blenda konci pod nimi (ako plan)')
  NxTest.assert_equal(NxRohB2.plan_rects(NxRohB2.params('top_mode' => 'two_rails', 'rails_orientation' => 'upright'))['corner_blind_panel'], rails)
  NxTest.assert_equal(nil, NxRohB2::PN.corner_preview_json(NxRohB2.params('type' => 'lower'), {}), 'dolna kresbu nema')
  NxTest.assert_equal(nil, NxRohB2::PN.corner_preview_json(nil, {}), 'bez vstupu nil')
  bad = NxRohB2.params
  bad['fronts'] = { 'items' => 'x', 'gap_left' => 'hore' }
  cp = NxRohB2::PN.corner_preview_json(bad, {})
  NxTest.assert(cp.nil? || cp['parts'].length == 4, 'poskodene cela nezhodia kresbu (normalize) ani panel')
end

# ============================================================================
# 2. PREFLIGHT A PAYLOAD
# ============================================================================

NxTest.test('ROH-B2: preflight — strana z ULOZENEHO configu, D/CR zive v rozsahu, inak posledny platny zdroj') do
  pn = NxRohB2::PN
  st = NxRohB2.stored('corner_side' => 'right', 'corner_cr1' => 90.0)
  data = { 'type' => 'corner_blind', 'width' => 1200.0, 'height' => 720.0, 'floor_height' => 100.0,
           'corner_side' => 'left', 'corner_door_w' => 500.0, 'corner_cr1' => 60.0, 'corner_cr2' => 999.0,
           'top_mode' => 'two_rails', 'material_id' => 'CUDZI', 'fronts' => JSON.parse(JSON.generate(NxRohB2::FRONTS)) }
  p = pn.corner_preview_params(data, st, st, { 't' => 25.0 })
  NxTest.assert_equal(['right', 1200.0, 500.0, 60.0, 80.0, 25.0, 'two_rails'],
                      p.values_at('corner_side', 'width', 'corner_door_w', 'corner_cr1', 'corner_cr2', 'thickness', 'top_mode'),
                      'strana ulozena, D/CR 1 zive, CR 2 mimo rozsahu = ulozene, hrubka z ctx, strop zivy')
  NxTest.refute(p['material_id'] == 'CUDZI', 'oznacena: material zo ULOZENEHO configu, nie z payloadu')
  ins = pn.corner_preview_params(data.merge('corner_side' => 'right'), nil, data.merge('corner_side' => 'right'), { 't' => 18.0 })
  NxTest.assert_equal(%w[right CUDZI], ins.values_at('corner_side', 'material_id'), 'vkladanie: strana a materialy z karty')
  cp = pn.corner_preflight_preview(data, st, nil, { 't' => 18.0, 'th2' => 18.0 })
  NxTest.assert_equal('right', cp['side'])
  NxTest.assert_equal([700.0, 1200.0, '500'], cp['dims'][0].values_at('x0', 'x1', 'label'), 'ziva sirka 1200 a D 500 vpravo')
  NxTest.assert_equal(nil, pn.corner_preflight_preview(data.merge('type' => 'lower'), nil, nil, { 't' => 18.0 }), 'dolna nic')
  NxTest.assert_equal(nil, pn.corner_preflight_preview(data, st, nil, nil), 'bez ucinnych hrubok nic')
  # Otvor dveri a kresba stoja na tom istom D (ta ista funkcia).
  NxTest.assert_equal(pn.preflight_door_w(data, st), p['corner_door_w'])
  NxTest.assert_equal(450.0, pn.preflight_door_w(data.merge('corner_door_w' => 900.0), st), 'D mimo rozsahu = ulozene')
  # Predrecenzia P3-1: VKLADANIE s neplatnou dverovou castou (pole cervene) —
  # otvor dveri aj kresba zostavy stoja na TOM ISTOM cisle (orezanom do rozsahu).
  %w[left right].each do |side|
    ins = data.merge('corner_side' => side, 'corner_door_w' => 900.0, 'cabinet_id' => '', 'insert_session' => 1,
                     'revision' => 1, 'width' => 1500.0)
    op = pn.front_preflight_result(ins)['opening']
    cp = pn.corner_preflight_preview(ins, nil, nil, { 't' => 18.0, 'th2' => 18.0 })
    door = cp['dims'][0]
    NxTest.assert_equal([op['x0'], op['x0'] + op['w']], door.values_at('x0', 'x1'),
                        "#{side}: otvor dveri = kota dverovej casti v kresbe (ziadne prekrytie)")
    NxTest.assert_equal(800.0, op['w'], "#{side}: 900 mimo rozsahu -> 800 (ten isty `norm_corner_mm` ako stavba)")
  end
  garbage = data.merge('corner_door_w' => 'x', 'cabinet_id' => '', 'insert_session' => 1, 'revision' => 1)
  NxTest.assert_equal(450.0, pn.preflight_door_w(garbage, garbage), 'vkladanie s necislom = predvolba 450')
end

NxTest.test('ROH-B2: zdroj — kresba v odpovedi preflightu len s prijatymi rozmermi, payload len pri rohovej') do
  ac = NxRohB2.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  hf = ac[/def handle_front_preflight\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(hf.include?("cp = res['opening'] ? corner_preflight_preview(data, stored, model, ctx) : nil"),
                'kresba len ked preflight rozmery prijal')
  NxTest.assert(hf.index("res['corner_preview'] = cp if cp") < hf.index('NX.frontPreflight'), 'ide v tej istej odpovedi')
  pl = NxRohB2.src('noxun_engine', 'ui', 'panel', 'payloads.rb')
  NxTest.assert(pl.include?("params['corner_preview'] = corner_preview_stored(entity_model(cab), cfg) if Construction.corner?(cfg)"),
                'payload oznacenej: kluc len pri rohovej')
  st = NxRohB2::PN.corner_preview_stored(nil, NxRohB2.stored('corner_side' => 'right'))
  NxTest.assert_equal('right', st['side'], 'ulozeny stav oznacenej rohovej')
  NxTest.assert_equal(NxRohB2.rects(NxRohB2::PN.corner_preview_json(NxRohB2.params('corner_side' => 'right'), {})),
                      NxRohB2.rects(st), 'ulozeny stav = ta ista kresba')
end

# ============================================================================
# 3. GHOST — klavesa strany dveri, pasik, prevesenie
# ============================================================================

NxTest.test('ROH-B2: ghost rohovej — strana zo zmrazeneho planu v pasiku a statuse, iny typ bez zmeny') do
  s = NxRohB2.session
  NxTest.assert(s.corner?, 'rohova session')
  pay = NxRohB2::GT.state_payload(s)
  NxTest.assert_equal(['left', 'dvere vľavo'], pay.values_at('corner_side', 'corner_label'))
  NxTest.assert_equal('dvere vpravo', NxRohB2::GT.state_payload(NxRohB2.session({ 'corner_side' => 'right' }))['corner_label'])
  st = NxRohB2::GT.status_text(s)
  NxTest.assert(st.include?('D strana dverí') && st.include?('| dvere vľavo · kotva'), 'status: klavesa aj stav')
  low = NxRohB2.session({ 'type' => 'lower', 'width' => 600.0 })
  NxTest.refute(low.corner?)
  lp = NxRohB2::GT.state_payload(low)
  NxTest.refute(lp.key?('corner_side') || lp.key?('corner_label'), 'dolna: pasik bez klucov rohovej')
  NxTest.refute(NxRohB2::GT.status_text(low).include?('dverí'), 'dolna: status bez zmeny')
end

NxTest.test('ROH-B2: klavesa D len pri ghoste rohovej — ohlasi stranu panelu, nic nezrkadli sama') do
  gt = NxRohB2::GT
  s = NxRohB2.session
  low = NxRohB2.session({ 'type' => 'lower', 'width' => 600.0 })
  tool = gt::Tool.new
  NxTest.assert_equal(68, gt::CORNER_SIDE_KEY, 'D = kod 68')
  NxTest.assert(tool.send(:corner_side_key?, s, 68), 'rohova + D')
  NxTest.refute(tool.send(:corner_side_key?, low, 68), 'dolna: D nie je nasa')
  NxTest.refute(tool.send(:corner_side_key?, s, 69), 'ine pismeno nie')
  prev = gt.session
  begin
    NxRohB2.with_key_spy do |calls|
      gt.instance_variable_set(:@session, s)
      tool.instance_variable_set(:@session, s)
      NxTest.assert_equal(true, tool.onKeyDown(68, 1, 0, nil), 'D pri rohovej = pohltena')
      NxTest.assert_equal(['left'], calls, 'panelu ide strana, ktoru ghost PRAVE nesie')
      NxTest.assert_equal(true, tool.onKeyDown(68, 2, 0, nil), 'drzana klavesa pohltena')
      NxTest.assert_equal(1, calls.length, '… ale neprepina znova')
      NxTest.assert_equal(true, tool.onKeyUp(68, 1, 0, nil), 'pustenie D tiez nase')
      NxTest.assert_equal('left', s.corner_side, 'session sama nic nezrkadli (robi to karta)')
      gt.instance_variable_set(:@session, low)
      tool.instance_variable_set(:@session, low)
      NxTest.assert_equal(false, tool.onKeyDown(68, 1, 0, nil), 'dolna: D ide SketchUpu')
      NxTest.assert_equal(false, tool.onKeyUp(68, 1, 0, nil))
      NxTest.assert_equal(1, calls.length, 'dolna nic neohlasi')
      NxTest.assert_equal(false, gt.request_corner_side(low))
    end
  ensure
    gt.instance_variable_set(:@session, prev)
  end
end

NxTest.test('ROH-B2: prevesenie ghostu (keep_point) prevezme polohu, bezne „Vložiť" nie') do
  gt = NxRohB2::GT
  m = NxRohB2::FakeModel.new
  prev_session = gt.session
  begin
    old = NxRohB2.session({}, model: m)
    old.set_point([120.0, 340.0, 0.0], true)
    gt.instance_variable_set(:@session, old)
    plan_r = NxRohB2::CB::InsertPlan.new(m, NxRohB2::CB.normalize(NxRohB2.params('corner_side' => 'right')), 0.0)
    s = gt.start(m, plan_r, keep_point: true)
    NxTest.assert(!s.nil? && s.active?, 'nova session')
    NxTest.assert_equal([[120.0, 340.0, 0.0], true], [s.last_point, s.placeable], 'poloha a polozitelnost prevzate')
    NxTest.assert_equal([:cancelled, 'right'], [old.state, s.corner_side], 'stara skoncila, nova nesie novu stranu')
    s2 = gt.start(m, plan_r)
    NxTest.assert_equal(nil, s2.last_point, 'bezne „Vložiť" polohu NEDEDI (spravanie bez zmeny)')
    other = NxRohB2.session({}, model: Object.new)
    other.set_point([1.0, 2.0, 0.0], true)
    gt.instance_variable_set(:@session, other)
    NxTest.assert_equal(nil, gt.start(m, plan_r, keep_point: true).last_point, 'iny dokument polohu nededi')
  ensure
    gt.cancel_session('test', deferred: false)
    gt.instance_variable_set(:@session, prev_session)
    gt.reset_memory!
  end
end

NxTest.test('ROH-B2 (predrecenzia P3-4): handle_ghost_corner_side — cudzi dokument, neziva session, odmietnuty vklad, uspech') do
  m = NxRohB2::FakeModel.new
  gt = NxRohB2::GT
  nope = ->(_p, _log) {}
  statuses = ->(log) { log.select { |l| l[0] == :status }.map { |l| [l[1], l[2]] } }
  begin
    # Cudzi dokument (R-02): nic sa nevola, ghost zije dalej.
    live = NxRohB2.session({}, model: m)
    log, after = NxRohB2.ghost_switch(model: m, live: live, insert: nope, foreign: true)
    NxTest.refute(log.any? { |l| l[0] == :insert }, 'cudzi dokument: vklad sa nevola')
    NxTest.assert(statuses.call(log).any? { |s| s[0].include?('panel patrí inému dokumentu') && s[1] }, 'hlasi sa nahlas')
    NxTest.assert(after.equal?(live) && live.active?, 'ghost nedotknuty')
    # Ziadna ziva session / dolna / iny dokument: veta „Rohová už nevisí na kurzore".
    [nil, NxRohB2.session({ 'type' => 'lower', 'width' => 600.0 }, model: m), NxRohB2.session({}, model: Object.new)].each do |s|
      log, = NxRohB2.ghost_switch(model: m, live: s, insert: nope)
      NxTest.refute(log.any? { |l| l[0] == :insert }, "#{s ? s.type_key : 'bez session'}: vklad sa nevola")
      NxTest.assert(statuses.call(log).any? { |x| x[0].start_with?('Rohová už nevisí na kurzore') && x[1] },
                    "#{s ? s.type_key : 'bez session'}: veta a chyba")
    end
    # Vklad payload ODMIETNE (nova session nevznikla): stary ghost konci, veta povie preco.
    live = NxRohB2.session({}, model: m)
    refuse = ->(_p, lg) { lg << [:status, 'Chyba: zamitnute', true] }
    log, after = NxRohB2.ghost_switch(model: m, live: live, insert: refuse)
    NxTest.assert_equal([[:insert, true]], log.select { |l| l[0] == :insert }, 'ide cestou „Vložiť" s prevzatou polohou')
    NxTest.assert_equal([:cancelled, nil], [live.state, after], 'stary ghost :cancelled a slot je volny')
    NxTest.assert(statuses.call(log).last[0].include?('Strana dverí sa neprepla') && statuses.call(log).last[1],
                  'posledna veta: strana sa neprepla, vloz znova')
    # Uspech: nova ziva session = nic sa neruší, ziadna chybova veta navyse.
    live = NxRohB2.session({}, model: m)
    fresh = NxRohB2.session({ 'corner_side' => 'right' }, model: m)
    ok_ins = ->(_p, _lg) { gt.instance_variable_set(:@session, fresh) }
    log, after = NxRohB2.ghost_switch(model: m, live: live, insert: ok_ins)
    NxTest.assert(after.equal?(fresh) && fresh.active?, 'nova session ostava')
    NxTest.refute(statuses.call(log).any? { |s| s[0].include?('neprepla') }, 'ziadna chybova veta')
  ensure
    gt.reset_memory!
  end
end

NxTest.test('ROH-B2: zdroj — prevesenie ide cestou „Vložiť", pri zlyhani ghost konci; callback je registrovany') do
  ac = NxRohB2.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  h = ac[/def handle_ghost_corner_side\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(h.index('foreign_document?') < h.index('handle_insert(payload, keep_point: true)'), 'identita dokumentu prva (R-02)')
  NxTest.assert(h.include?('old.corner?') && h.include?('old.plan.for_model?(model)'), 'len ziva rohova session v tomto dokumente')
  NxTest.assert(h.index('handle_insert(payload, keep_point: true)') < h.index("GhostTool.cancel_session('strana dverí sa neprepla'"),
                'nezalozeny novy ghost = stary sa zrusi (karta uz ukazuje novu stranu)')
  NxTest.refute(h.include?('start_operation'), 'prevesenie nic nezapisuje (0 krokov Spat)')
  NxTest.assert(NxRohB2.src('noxun_engine', 'ui', 'panel.rb').include?("cb(dlg, 'ghost_corner_side')  { |p| handle_ghost_corner_side(p) }"))
  sy = NxRohB2.src('noxun_engine', 'ui', 'panel', 'sync.rb')
  NxTest.assert(sy.include?('js("NX.ghostCornerSide(#{side.to_s.to_json})")'), 'klavesa ide do panela ako strana (JSON)')
end
