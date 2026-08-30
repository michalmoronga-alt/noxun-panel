# frozen_string_literal: true
# GHOST VKLADANIE (V1-04) — CISTA cast: matematika kotiev/transformu a stavovy
# automat session. Bez SketchUpu, bez modelu, bez entit.
#
# Co sa overuje:
#   1) ZAVAZNA tabulka kotiev (audit BLOCKER 4) — predna rovina je vzdy Y = 0,
#      spodok tela podla variantu dna, horna skrinka vzdy od Z = 0
#   2) kanonicka konstrukcia transformu — 4 rotacie x 4 kotvy x oba typy:
#      kotva ostava PRESNE na kliknutom bode (free), zamok drzi origin na
#      `home_z` a lokalne Z kotvy sa NEODCITA, prechody locked/free nemenia X/Y
#   3) kazda matica prejde `CabinetBuilder.rigid_matrix?` (R-03) a je vzdy
#      skladana NANOVO z celociselneho stavu (rotacia 4x = identita)
#   4) degenerovane luce (|dz| pod EPS, t < 0, nekonecne cisla) = nil
#   5) stavovy automat session — idempotentne konce, druhy klik = no-op,
#      peciatka sablony PRESNE raz
#   6) obalka ghostu (8 bodov) a poradie cyklovania kotiev
require_relative '../helper' unless defined?(NxTest)

module NxGhost
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

  # Config planu (symbolove kluce ako `CabinetBuilder.normalize`).
  def cfg(extra = {})
    { type: 'lower', width: 600.0, height: 720.0, depth: 510.0, thickness: 18.0,
      floor_height: 100.0, bottom_mode: 'under_sides' }.merge(extra)
  end

  def upper_cfg(extra = {})
    cfg({ type: 'upper', floor_height: 0.0, depth: 320.0, bottom_mode: 'between_sides' }.merge(extra))
  end

  # Fake dokument — plan porovnava identitu OBJEKTOM, nie guidom.
  def plan(config = cfg, home_z = 0.0, model = Object.new)
    e::CabinetBuilder::InsertPlan.new(model, config, home_z)
  end

  # GHOST-FB3: session startuje z PAMATE modulu. Testy si preto dodavaju
  # VLASTNU (cerstvu) pamat — inak by si scenare navzajom prepisovali kotvu,
  # rotaciu aj rezim vysky. Modulovu pamat overuje samostatny scenar nizsie.
  def fresh_memory
    { anchor: gt::ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
  end

  def session(config = cfg, home_z = 0.0, **kw)
    kw[:memory] = fresh_memory unless kw.key?(:memory)
    gt::PlacementSession.new(model: Object.new, plan: plan(config, home_z), **kw)
  end

  def hang
    Noxun::Engine::CabinetBuilder::UPPER_HANG_Z
  end

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  # Fake tool stack — `pop_tool` len POCITA. Realny SketchUp odoberie VRCH
  # stacku bez ohladu na to, kto o to ziada; presne to sa tu meria.
  class FakeTools
    attr_reader :pops

    def initialize
      @pops = 0
    end

    def pop_tool
      @pops += 1
    end
  end

  class FakeModel
    attr_reader :tools

    def initialize
      @tools = FakeTools.new
    end
  end

  # Tool bez SketchUpu: nastavime len priznaky, ktore `pop_tool` cita.
  def fake_tool(model, attached: true, on_top: true)
    t = gt::Tool.new
    t.instance_variable_set(:@model_ref, model)
    t.instance_variable_set(:@attached, attached)
    t.instance_variable_set(:@on_top, on_top)
    t
  end

  # Headless nema `UI` — pre testy odlozeneho popu ho na chvilu nahradime
  # modulom, ktory timer vykona OKAMZITE (inak by sa `resume` cesta nedala
  # dokazat spravanim, len grepom zdrojaku).
  def with_immediate_timer
    had = Object.const_defined?(:UI)
    return yield if had

    ui = Module.new do
      def self.start_timer(_delay, _repeat = false)
        yield
      end
    end
    Object.const_set(:UI, ui)
    begin
      yield
    ensure
      Object.send(:remove_const, :UI)
    end
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
end

# --- 1) ZAVAZNA tabulka kotiev ---------------------------------------------

NxTest.test('ghost: kotvy dolnej `under_sides` — spodok tela je DNO na floor_height') do
  c = NxGhost.cfg(bottom_mode: 'under_sides', floor_height: 100.0)
  a = NxGhost.calc.anchor_points(c)
  NxTest.assert_equal([0.0, 0.0, 100.0], a[:fl_bottom])
  NxTest.assert_equal([600.0, 0.0, 100.0], a[:fr_bottom])
  NxTest.assert_equal([0.0, 0.0, 720.0], a[:fl_top])
  NxTest.assert_equal([600.0, 0.0, 720.0], a[:fr_top])
end

NxTest.test('ghost: kotvy dolnej `between_sides` — boky stoja na zemi, spodok je Z = 0') do
  c = NxGhost.cfg(bottom_mode: 'between_sides', floor_height: 100.0)
  a = NxGhost.calc.anchor_points(c)
  NxTest.assert_equal([0.0, 0.0, 0.0], a[:fl_bottom])
  NxTest.assert_equal([600.0, 0.0, 0.0], a[:fr_bottom])
  NxTest.assert_equal([600.0, 0.0, 720.0], a[:fr_top])
end

NxTest.test('ghost: horna skrinka ma OBA varianty dna od Z = 0 (UPPER_HANG_Z je svetova vyska, nie kotva)') do
  %w[under_sides between_sides].each do |bm|
    c = NxGhost.upper_cfg(bottom_mode: bm)
    a = NxGhost.calc.anchor_points(c)
    NxTest.assert_equal([0.0, 0.0, 0.0], a[:fl_bottom], "horna #{bm}: spodna kotva nie je na Z = 0")
    NxTest.assert_equal([0.0, 0.0, c[:height]], a[:fl_top], "horna #{bm}: horna kotva nie je na vyske korpusu")
    NxTest.assert_equal([c[:width], 0.0, c[:height]], a[:fr_top], "horna #{bm}: prava horna kotva nesedi")
  end
  # Poistka: aj keby config hornej niesol floor_height (normalize ho nuluje),
  # kotva ostava na Z = 0 — typ vitazi nad hodnotou.
  a = NxGhost.calc.anchor_points(NxGhost.upper_cfg(floor_height: 150.0, bottom_mode: 'under_sides'))
  NxTest.assert_equal(0.0, a[:fl_bottom][2])
end

NxTest.test('ghost: predna rovina korpusu je VZDY lokalne Y = 0 (cela do kotiev nevstupuju)') do
  [NxGhost.cfg, NxGhost.cfg(plinth_mode: 'front', plinth_recess: 40.0), NxGhost.upper_cfg].each do |c|
    NxGhost.calc.anchor_points(c).each_value do |p|
      NxTest.assert_equal(0.0, p[1], "kotva mimo prednej roviny: #{p.inspect}")
    end
  end
end

NxTest.test('ghost: obalka je 8 bodov [0..w] x [0..depth] x [spodok tela..h]') do
  pts = NxGhost.calc.envelope_points(NxGhost.cfg)
  NxTest.assert_equal(8, pts.length)
  NxTest.assert_equal([0.0, 600.0], pts.map { |p| p[0] }.uniq.sort)
  NxTest.assert_equal([0.0, 510.0], pts.map { |p| p[1] }.uniq.sort)
  NxTest.assert_equal([100.0, 720.0], pts.map { |p| p[2] }.uniq.sort)
  # Predna stena (indexy FRONT_FACE) lezi cela na Y = 0 — kontrakt kreslenia.
  NxGhost.gt::FRONT_FACE.each { |i| NxTest.assert_equal(0.0, pts[i][1]) }
  # 12 hran kvadra, ziadna zdvojena
  NxTest.assert_equal(12, NxGhost.gt::EDGES.length)
  NxTest.assert_equal(12, NxGhost.gt::EDGES.map(&:sort).uniq.length)
end

# --- 2) + 3) kanonicky transform -------------------------------------------

NxTest.test('ghost: FREE — kotva ostava PRESNE na kliknutom bode pri vsetkych 4 rotaciach a 4 kotvach') do
  [NxGhost.cfg, NxGhost.upper_cfg].each do |c|
    picked = [1234.5, -678.25, 321.75]
    NxGhost.gt::ANCHORS.each do |anchor|
      a = NxGhost.calc.anchor_point(c, anchor)
      (0..3).each do |k|
        m = NxGhost.calc.matrix(anchor: a, picked: picked, rotation_index: k, z_mode: :free, home_z: 0.0)
        got = NxGhost.apply(m, a)
        3.times do |i|
          NxTest.assert_close(picked[i], got[i], 1e-9,
                              "free #{c[:type]}/#{anchor}/k=#{k}: os #{i} sa neposadila na kliknuty bod")
        end
      end
    end
  end
end

NxTest.test('ghost: ZAMOK — origin drzi home_z a lokalne Z kotvy sa NEODCITA') do
  c = NxGhost.cfg # spodna kotva ma lokalne Z = 100 (floor_height)
  picked = [800.0, 200.0, 0.0]
  NxGhost.gt::ANCHORS.each do |anchor|
    a = NxGhost.calc.anchor_point(c, anchor)
    (0..3).each do |k|
      m = NxGhost.calc.matrix(anchor: a, picked: picked, rotation_index: k, z_mode: :locked, home_z: 0.0)
      NxTest.assert_close(0.0, m[14], 1e-9, "dolna #{anchor}/k=#{k}: origin nie je na home_z")
      # Kotva sa v zamku posadi na home_z + jej LOKALNE Z (to je zmysel zamku typu).
      NxTest.assert_close(a[2], NxGhost.apply(m, a)[2], 1e-9)
    end
  end
  up = NxGhost.upper_cfg
  hang = Noxun::Engine::CabinetBuilder::UPPER_HANG_Z
  a = NxGhost.calc.anchor_point(up, :fl_bottom)
  m = NxGhost.calc.matrix(anchor: a, picked: picked, rotation_index: 2, z_mode: :locked, home_z: hang)
  NxTest.assert_close(hang, m[14], 1e-9, 'horna: origin nevisi na UPPER_HANG_Z')
end

NxTest.test('ghost: ZAMOK berie X/Y z kliknuteho bodu presne ako FREE (prechod locked/free X a Y nemeni)') do
  c = NxGhost.cfg
  picked = [1500.0, -420.0, 950.0]
  NxGhost.gt::ANCHORS.each do |anchor|
    a = NxGhost.calc.anchor_point(c, anchor)
    (0..3).each do |k|
      lm = NxGhost.calc.matrix(anchor: a, picked: picked, rotation_index: k, z_mode: :locked, home_z: 0.0)
      fm = NxGhost.calc.matrix(anchor: a, picked: picked, rotation_index: k, z_mode: :free, home_z: 0.0)
      NxTest.assert_close(fm[12], lm[12], 1e-9, "k=#{k}: prechod zamku zmenil X")
      NxTest.assert_close(fm[13], lm[13], 1e-9, "k=#{k}: prechod zamku zmenil Y")
      NxTest.assert(lm[14] != fm[14] || (a[2] - picked[2]).abs < 1e-9,
                    'zamok a free maju rovnake Z, hoci kotva nelezi na kliknutom bode')
    end
  end
end

NxTest.test('ghost: kazda matica prejde CabinetBuilder.rigid_matrix? (R-03)') do
  c = NxGhost.cfg
  cb = Noxun::Engine::CabinetBuilder
  NxGhost.gt::ANCHORS.each do |anchor|
    a = NxGhost.calc.anchor_point(c, anchor)
    (0..3).each do |k|
      %i[locked free].each do |mode|
        m = NxGhost.calc.matrix(anchor: a, picked: [10.0, 20.0, 30.0], rotation_index: k,
                                z_mode: mode, home_z: 0.0)
        NxTest.assert(cb.rigid_matrix?(m), "matica #{anchor}/k=#{k}/#{mode} nie je rigidna: #{m.inspect}")
        # Osi su PRESNE 0/±1 — ziadny numericky sum zo skladania rotacii.
        NxTest.assert(m[0, 12].all? { |v| [0.0, 1.0, -1.0].include?(v) },
                      "rotacna cast nie je presna: #{m[0, 12].inspect}")
      end
    end
  end
end

NxTest.test('ghost: rotacia sa sklada NANOVO — 4 kroky vpravo su identita, smer je ∓90°') do
  s = NxGhost.session
  NxTest.assert_equal(0, s.rotation_index)
  4.times { s.rotate!(1) }
  NxTest.assert_equal(0, s.rotation_index, 'styri kroky vpravo nevratili povodnu rotaciu')
  s.rotate!(-1)
  NxTest.assert_equal(3, s.rotation_index, 'sipka vlavo ma tocit o −90°')
  # Presnost sa nezhorsuje ani po mnohych krokoch (index, nie nasobenie matic).
  40.times { s.rotate!(1) }
  m = NxGhost.calc.matrix(anchor: [0.0, 0.0, 0.0], picked: [0.0, 0.0, 0.0],
                          rotation_index: s.rotation_index)
  NxTest.assert(Noxun::Engine::CabinetBuilder.rigid_matrix?(m))
end

# --- 4) degenerovane luce ---------------------------------------------------

NxTest.test('ghost: ray x rovina zamku — degenerovane pripady vracaju nil') do
  c = NxGhost.calc
  # vodorovny pohlad (|dz| pod EPS)
  NxTest.assert(c.ray_plane([0.0, 0.0, 500.0], [1.0, 0.0, 0.0], 0.0).nil?, 'vodorovny luc mal vratit nil')
  NxTest.assert(c.ray_plane([0.0, 0.0, 500.0], [1.0, 0.0, 1e-12], 0.0).nil?, 'takmer vodorovny luc mal vratit nil')
  # rovina ZA kamerou (t < 0)
  NxTest.assert(c.ray_plane([0.0, 0.0, 500.0], [0.0, 0.0, 1.0], 0.0).nil?, 'rovina za kamerou mala vratit nil')
  # horna rovina UPPER_HANG_Z s kamerou NAD nou pozerajucou hore
  NxTest.assert(c.ray_plane([0.0, 0.0, 2000.0], [0.0, 0.0, 1.0], 1400.0).nil?)
  # nekonecne / nan vstupy
  NxTest.assert(c.ray_plane([0.0, 0.0, Float::INFINITY], [0.0, 0.0, -1.0], 0.0).nil?)
  NxTest.assert(c.ray_plane([0.0, 0.0, 500.0], [0.0, 0.0, Float::NAN], 0.0).nil?)
  NxTest.assert(c.ray_plane(nil, [0.0, 0.0, -1.0], 0.0).nil?)
end

NxTest.test('ghost: SIKMY ale nedegenerovany luc — takmer vodorovny pohlad NIE JE poloha') do
  c = NxGhost.calc
  # WALK pohlad z vysky 1500 mm, jeden pixel pod horizontom: `dz` je rádovo
  # 1e-4, holy EPS 1e-9 by to prepustil a `t` by vyslo ~1,5e7 mm — klik by
  # polozil korpus 15 km od originu. Uhlova brana to musi utnut.
  NxTest.assert(c.ray_plane([0.0, 0.0, 1500.0], [1.0, 0.0, -1e-4], 0.0).nil?,
                'takmer vodorovny luc (sin 1e-4) mal vratit nil')
  # Nenormalizovany smer: rozhoduje POMER, nie velkost zlozky.
  NxTest.assert(c.ray_plane([0.0, 0.0, 1500.0], [1000.0, 0.0, -0.1], 0.0).nil?,
                'nenormalizovany takmer vodorovny luc mal vratit nil')
  # Uhol UZ prejde (sin 1,2e-3), ale vysledok je 1,25 km od kamery —
  # zdravotny strop ho musi zastavit (druha, nezavisla brana).
  NxTest.assert(c.ray_plane([0.0, 0.0, 1500.0], [1.0, 0.0, -1.2e-3], 0.0).nil?,
                'luc mimo zdravy dosah (1,25 km) mal vratit nil')
  # Hranicna kontrola: strop plati aj na SURADNICE vysledku.
  NxTest.assert(!c.sane_point?([2_000_000.0, 0.0, 0.0]), 'bod 2 km od originu nie je zdravy')
  NxTest.assert(!c.sane_point?([0.0, Float::INFINITY, 0.0]))
  NxTest.assert(!c.sane_point?([0.0, 0.0]))
  NxTest.assert(c.sane_point?([80_000.0, 45_000.0, 0.0]), 'bezna zakazka musi prejst')
end

NxTest.test('ghost: ray x rovina zamku — platny luc trafi rovinu presne') do
  pt = NxGhost.calc.ray_plane([100.0, 200.0, 1000.0], [1.0, 2.0, -2.0], 0.0)
  NxTest.assert(!pt.nil?, 'platny luc vratil nil')
  NxTest.assert_close(600.0, pt[0], 1e-9)
  NxTest.assert_close(1200.0, pt[1], 1e-9)
  NxTest.assert_close(0.0, pt[2], 1e-9)
  # horna rovina zdola nahor je platna, kym lezi PRED kamerou
  up = NxGhost.calc.ray_plane([0.0, 0.0, 0.0], [0.0, 0.0, 1.0], 1400.0)
  NxTest.assert_close(1400.0, up[2], 1e-9)
end

# --- 5) stavovy automat session --------------------------------------------

NxTest.test('ghost session: startuje ACTIVNA, v ZAMKU a na prvej kotve (oba typy)') do
  s = NxGhost.session
  NxTest.assert(s.active?)
  NxTest.assert_equal(:locked, s.z_mode)
  NxTest.assert_equal(:fl_bottom, s.anchor)
  NxTest.assert(!s.placeable, 'session bez polohy nesmie byt polozitelna')
  up = NxGhost.session(NxGhost.upper_cfg, Noxun::Engine::CabinetBuilder::UPPER_HANG_Z)
  NxTest.assert_equal(:locked, up.z_mode, 'horna skrinka nesmie startovat vo free Z')
  NxTest.assert_close(Noxun::Engine::CabinetBuilder::UPPER_HANG_Z, up.lock_plane_z, 0.01)
end

NxTest.test('ghost session: cancel je IDEMPOTENTNY a terminalny') do
  s = NxGhost.session
  NxTest.assert(s.cancel!('Esc'), 'prvy cancel mal zabrat')
  NxTest.assert(s.terminal? && !s.active?)
  NxTest.assert(!s.cancel!('Esc'), 'druhy cancel uz nesmie nic robit')
  NxTest.assert(!s.begin_commit!, 'zrusena session sa nesmie dat commitnut')
end

NxTest.test('ghost session: druhy klik je NO-OP (dvojklik nikdy dve skrinky)') do
  s = NxGhost.session
  NxTest.assert(s.begin_commit!, 'prvy klik mal otvorit commit')
  NxTest.assert(!s.begin_commit!, 'druhy klik musi byt no-op')
  NxTest.assert(!s.cancel!('Esc'), 'cancel pocas commitu nesmie prepisat stav')
  NxTest.assert(s.mark_committed!)
  NxTest.assert(s.terminal?)
  NxTest.assert(!s.mark_committed!, 'druhe potvrdenie commitu je no-op')
  NxTest.assert(!s.begin_commit!)
end

NxTest.test('ghost session: zlyhany commit KONCI session (v modeli sa nic nezmenilo)') do
  s = NxGhost.session
  s.begin_commit!
  NxTest.assert(s.mark_failed!('Fronts.validate_layout!'))
  NxTest.assert(s.terminal?)
  NxTest.assert_equal('Fronts.validate_layout!', s.cancel_reason)
  NxTest.assert(!s.begin_commit!)
end

NxTest.test('ghost session: peciatka sablony PRESNE raz') do
  s = NxGhost.session
  hits = 0
  NxTest.assert(s.stamp_once! { hits += 1 })
  NxTest.assert(!s.stamp_once! { hits += 1 }, 'peciatka sa nesmie zopakovat')
  NxTest.assert_equal(1, hits)
end

NxTest.test('ghost session: degenerovany luc drzi POSLEDNU platnu polohu a zakazuje polozenie') do
  s = NxGhost.session
  s.set_point([100.0, 200.0, 0.0], true)
  NxTest.assert(s.placeable)
  NxTest.assert_equal([100.0, 200.0, 0.0], s.last_point)
  s.set_point(nil, false)
  NxTest.assert(!s.placeable, 'po degenerovanom luci sa nesmie dat polozit')
  NxTest.assert_equal([100.0, 200.0, 0.0], s.last_point, 'ghost mal drzat poslednu platnu polohu')
end

# --- 6) kotvy a rezimy vysky -----------------------------------------------

NxTest.test('ghost: Alt cykluje kotvy v poradi lava-dolna → prava-dolna → prava-horna → lava-horna') do
  NxTest.assert_equal(%i[fl_bottom fr_bottom fr_top fl_top], NxGhost.gt::ANCHORS)
  s = NxGhost.session
  got = [s.anchor]
  3.times do
    s.cycle_anchor!
    got << s.anchor
  end
  NxTest.assert_equal(%i[fl_bottom fr_bottom fr_top fl_top], got)
  s.cycle_anchor!
  NxTest.assert_equal(:fl_bottom, s.anchor, 'cyklus sa musi uzavriet')
end

NxTest.test('ghost: rezim vysky prijme len locked/free a hlasi ZMENU') do
  s = NxGhost.session
  NxTest.assert(!s.set_z_mode!(:locked), 'nastavenie rovnakeho rezimu nie je zmena')
  NxTest.assert(s.set_z_mode!(:free))
  NxTest.assert_equal(:free, s.z_mode)
  NxTest.assert(!s.set_z_mode!(:bogus), 'neznamy rezim sa nesmie nastavit')
  NxTest.assert_equal(:free, s.z_mode)
end

NxTest.test('ghost: obalka aj kotvy sa pocitaju RAZ zo zmrazeneho configu (ziadny plan v draw slucke)') do
  s = NxGhost.session
  NxTest.assert(s.corners_mm.frozen? && s.corners_mm.all?(&:frozen?))
  NxTest.assert(s.anchors_mm.frozen?)
  NxTest.assert_equal(8, s.corners_mm.length)
  NxTest.assert_equal([0.0, 0.0, 100.0], s.anchor_point_mm)
  s.cycle_anchor!
  NxTest.assert_equal([600.0, 0.0, 100.0], s.anchor_point_mm)
end

# --- 7) sev v paneli (zdrojove invarianty) ----------------------------------

NxTest.test('ghost sev: handle_insert UZ NESTAVIA — pripravi plan a zavesi ghost') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'), encoding: 'UTF-8')
  body = src[/def handle_insert\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'handle_insert sa nenasiel')
  NxTest.assert(!body.include?('CabinetBuilder.build('),
                'handle_insert stavia priamo — skrinka ma vzniknut az klikom cez commit_insert')
  NxTest.assert(body.include?('CabinetBuilder.prepare_insert') && body.include?('GhostTool.start'),
                'handle_insert nepripravuje plan / nezaklada ghost session')
  # Preflighty bezia PRED zalozenim session (Tool ich uz neopakuje).
  %w[insert_thickness_preflight material_preflight take_insert_hardware!].each do |pre|
    NxTest.assert(body.index(pre) < body.index('GhostTool.start'),
                  "#{pre} musi bezat PRED zalozenim ghost session")
  end
  # Tri sevy panela existuju a commit ich vola.
  %w[ghost_freeze_hardware ghost_insert_failed ghost_after_commit].each do |m|
    NxTest.assert(src.include?("def #{m}"), "Panel.#{m} chyba")
  end
  # Zakazy sa meraju nad KODOM, nie nad komentarmi (komentar o zakaze by inak
  # sam zhodil test).
  gt = File.readlines(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'ghost_tool.rb'), encoding: 'UTF-8')
           .reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert(gt.include?('CabinetBuilder.commit_insert'),
                'ghost commituje inak nez sevom R-03')
  NxTest.assert(!gt.include?('add_instance') && !gt.include?('start_operation'),
                'ghost si nesmie robit vlastny zapis do modelu')
  NxTest.assert(!gt.include?('Construction.build_plan'),
                'ghost nesmie planovat v draw slucke')
  NxTest.assert(gt.include?('push_tool') && !gt.include?('select_tool'),
                'ghost sa musi aktivovat push_tool (select_tool by zahodil povodny nastroj)')
end

NxTest.test('ghost: File>New / File>Open rusia session BEZPODMIENECNE (Windows recykluje Model objekt)') do
  gt = NxGhost.gt
  model = Object.new
  s = gt.instance_variable_get(:@session)
  begin
    gt.instance_variable_set(:@session, gt::PlacementSession.new(model: model, plan: NxGhost.plan(NxGhost.cfg, 0.0, model)))
    live = gt.session
    # Poistka identity by tu vratila „ten isty dokument" — a session by
    # prezila do inej zakazky. Udalost o novom/otvorenom dokumente ju musi
    # zrusit bez ohladu na identitu.
    NxTest.assert(gt.on_model_switched(model) == false,
                  'aktivacia toho isteho dokumentu session rušiť NESMIE (Ctrl+S)')
    NxTest.assert(live.active?, 'session mala prezit aktivaciu toho isteho dokumentu')
    NxTest.assert(gt.on_document_replaced('test') == true, 'New/Open musi session zrusit')
    NxTest.assert(live.terminal? && gt.session.nil?, 'po New/Open nesmie ostat ziadna session')
    NxTest.assert(gt.on_document_replaced('test') == false, 'druhe New/Open uz nema co rusit')
  ensure
    gt.instance_variable_set(:@session, s)
  end
end

NxTest.test('ghost tool: pop NEODOBERIE cudzi nastroj, ked nie sme vrch stacku') do
  gt = NxGhost.gt
  model = NxGhost::FakeModel.new
  # Situacia: pocas ghostu pushol nad nas nastroj niekto iny (iny extension
  # v `onTransactionCommit`). `pop_tool` SketchUpu odoberie VRCH — slepy pop by
  # zhodil JEHO a ghost by ostal visiet aktivny bez session.
  t = NxGhost.fake_tool(model, attached: true, on_top: false)
  prev = gt.instance_variable_get(:@active_tool)
  begin
    gt.instance_variable_set(:@active_tool, t)
    NxTest.assert(gt.pop_tool(t) == false, 'pop nesmie prejst, kym nie sme navrchu')
    NxTest.assert_equal(0, model.tools.pops, 'cudzi nastroj sa NESMIE odobrat')
    NxTest.assert(t.attached?, 'nas nastroj ostava na stacku')
    NxTest.assert(t.finish_pending?, 'ukoncenie sa ma ODLOZIT, nie zahodit')
    NxTest.assert(gt.instance_variable_get(:@active_tool).equal?(t),
                  'nastroj sa nesmie odregistrovat, kym naozaj neskoncil')
    # Vrch stacku sa vratil k nam -> pop uz prejde a odoberie PRAVE JEDEN.
    t.instance_variable_set(:@on_top, true)
    NxTest.assert(gt.pop_tool(t) == true)
    NxTest.assert_equal(1, model.tools.pops)
    NxTest.assert(!t.attached? && !t.on_top?, 'po pope uz nie sme na stacku')
    NxTest.assert(gt.instance_variable_get(:@active_tool).nil?)
    # Idempotencia: druhy pop toho isteho nastroja uz nic neodoberie.
    NxTest.assert(gt.pop_tool(t) == false)
    NxTest.assert_equal(1, model.tools.pops)
  ensure
    gt.instance_variable_set(:@active_tool, prev)
  end
end

NxTest.test('ghost tool: resume s odlozenym koncom popne SEBA a LEN seba (nie „aktivny nastroj")') do
  gt = NxGhost.gt
  model = NxGhost::FakeModel.new
  # Presna situacia z review #268 kola 3: stary ghost je SUSPENDOVANY (cudzi
  # nastroj nad nim), medzitym pride druhe „Vlozit" — nova session, NOVY
  # nastroj sa stane `@active_tool`. Ked cudzi nastroj skonci, stary ghost
  # dostane `resume` a MUSI sa odstranit SAM. Globalne `end_tool` by uz
  # starú instanciu nepoznalo a stary ghost by ostal vrchom stacku bez session.
  old_tool = NxGhost.fake_tool(model, attached: true, on_top: false)
  new_tool = NxGhost.fake_tool(NxGhost::FakeModel.new, attached: true, on_top: true)
  prev = gt.instance_variable_get(:@active_tool)
  begin
    gt.instance_variable_set(:@active_tool, old_tool)
    NxTest.assert(gt.pop_tool(old_tool) == false, 'suspendovany nastroj sa popnut nesmie')
    NxTest.assert(old_tool.finish_pending?)
    # druhe „Vlozit": novy nastroj prepise globalnu registraciu
    gt.instance_variable_set(:@active_tool, new_tool)
    NxGhost.with_immediate_timer { old_tool.resume(nil) }
    NxTest.assert(!old_tool.attached?, 'stary ghost sa pri resume MUSI odstranit sam')
    NxTest.assert_equal(1, model.tools.pops, 'stary ghost popol PRESNE raz')
    NxTest.assert(!old_tool.finish_pending?)
    NxTest.assert(gt.instance_variable_get(:@active_tool).equal?(new_tool),
                  'novy ghost sa tym NESMIE dotknut (ani registracia, ani stack)')
    NxTest.assert_equal(0, new_tool.model_ref.tools.pops, 'novy ghost sa nesmie popnut')
    NxTest.assert(new_tool.attached? && new_tool.on_top?)
  ensure
    gt.instance_variable_set(:@active_tool, prev)
  end
end

NxTest.test('ghost tool: resume nepopne, kym sme medzitym znova stratili vrch (odlozi to znova)') do
  gt = NxGhost.gt
  model = NxGhost::FakeModel.new
  t = NxGhost.fake_tool(model, attached: true, on_top: false)
  prev = gt.instance_variable_get(:@active_tool)
  begin
    gt.instance_variable_set(:@active_tool, t)
    t.request_finish!
    # `resume` nas da navrch, ale kym „timer" bezi, znova nas zhodi `suspend`.
    NxGhost.with_immediate_timer do
      t.instance_variable_set(:@on_top, true)
      t.instance_variable_set(:@finish_pending, false)
      t.suspend(nil) # cudzi nastroj sa vratil nad nas EST PRED popom
      t.finish_self_soon
    end
    NxTest.assert_equal(0, model.tools.pops, 'nesmieme popnut cudzi nastroj')
    NxTest.assert(t.attached?)
    NxTest.assert(t.finish_pending?, 'ukoncenie sa ma ODLOZIT znova, nie stratit')
  ensure
    gt.instance_variable_set(:@active_tool, prev)
  end
end

NxTest.test('ghost tool: suspend/resume drzia priznak „som navrchu"') do
  gt = NxGhost.gt
  t = NxGhost.fake_tool(NxGhost::FakeModel.new)
  NxTest.assert(t.on_top?)
  t.suspend(nil)
  NxTest.assert(!t.on_top?, 'suspend (Orbit/Pan alebo cudzi push_tool) nas zhodi z vrchu')
  t.request_finish!
  t.resume(nil)
  NxTest.assert(t.on_top?, 'resume nas vracia na vrch')
  NxTest.assert(!t.finish_pending?, 'odlozene ukoncenie sa pri resume spotrebuje')
  # `deactivate` odlozene ukoncenie zahadzuje — nastroj uz odchadza sam.
  t2 = NxGhost.fake_tool(NxGhost::FakeModel.new)
  t2.request_finish!
  t2.deactivate(nil)
  NxTest.assert(!t2.attached? && !t2.on_top? && !t2.finish_pending?)
end

NxTest.test('ghost session: slot sa uvolni aj nad rozrobenym commitom') do
  gt = NxGhost.gt
  model = Object.new
  s = gt.instance_variable_get(:@session)
  begin
    live = gt::PlacementSession.new(model: model, plan: NxGhost.plan(NxGhost.cfg, 0.0, model))
    gt.instance_variable_set(:@session, live)
    live.begin_commit! # simuluje commit prerušený vynimkou MIMO StandardError
    NxTest.assert(live.committing?)
    gt.cancel_session('mrtva session', deferred: false)
    NxTest.assert(gt.session.nil?, 'rozrobena session nesmie drzat slot navzdy')
  ensure
    gt.instance_variable_set(:@session, s)
  end
end

NxTest.test('ghost sev: New/Open vetva AppObservera rusi session pred prepnutim observerov') do
  sel = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'), encoding: 'UTF-8')
  obs = sel[/class PanelAppObserver.*?\n      end\n/m].to_s
  NxTest.assert(!obs.empty?, 'PanelAppObserver sa nenasiel')
  %w[onNewModel onOpenModel].each do |ev|
    body = obs[/def #{ev}\(model\)(.*?)\n        end/m, 1].to_s
    NxTest.assert(body.include?('GhostTool.on_document_replaced'),
                  "#{ev} nerusi ghost session bezpodmienecne")
    NxTest.assert(body.index('GhostTool.on_document_replaced') < body.index('Panel.on_model_switched'),
                  "#{ev}: cancel ghostu musi bezat PRED prepnutim observerov")
  end
  # `onActivateModel` ostava na IDENTITE — aktivacia toho isteho dokumentu
  # (aj po Ctrl+S) ghost rušiť nesmie.
  act = obs[/def onActivateModel\(model\)(.*?)\n        end/m, 1].to_s
  NxTest.assert(!act.include?('on_document_replaced'),
                'onActivateModel nesmie rušiť bezpodmienecne — Ctrl+S ghost drzi')
end

NxTest.test('ghost sev: iné spôsoby vkladania (kópia, doska) session ukončia') do
  cab = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'), encoding: 'UTF-8')
  copy = cab[/def handle_insert_copy\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(copy.include?('GhostTool.cancel_session'), 'handle_insert_copy nerusi ghost session')
  NxTest.assert(copy.index('GhostTool.cancel_session') < copy.index('CabinetBuilder.build'),
                'kopia musi zrusit ghost PRED stavbou')
  brd = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_board.rb'), encoding: 'UTF-8')
  ins = brd[/def handle_insert_board\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(ins.include?('GhostTool.cancel_session'), 'handle_insert_board nerusi ghost session')
  NxTest.assert(ins.index('GhostTool.cancel_session') < ins.index('BoardBuilder.build'),
                'vlozenie dosky musi zrusit ghost PRED stavbou')
end

NxTest.test('ghost sev: poznamka preflightov ide do statusu PRAVE RAZ (po vlozeni)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'), encoding: 'UTF-8')
  ins = src[/def handle_insert\(payload\).*?\n        end\n/m].to_s
  after = src[/def ghost_after_commit\(model, inst, session\).*?\n        end\n/m].to_s
  NxTest.assert(after.include?('session.note'), 'ghost_after_commit nevypisuje poznamku preflightov')
  # Status pri zaveseni ghostu poznamku UZ neopakuje — inak by ju pouzivatel
  # videl dvakrat (raz predcasne).
  status = ins[/set_status\('Skrinka visí na kurzore.*?\)\n/m].to_s
  NxTest.assert(!status.include?('note'), 'poznamka sa vypisuje uz pri zaveseni ghostu — bola by dvakrat')
end

NxTest.test('ghost sev: zavretie Inspectora a prepnutie dokumentu session RUSIA') do
  panel = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
  hook = panel[/set_on_closed do.*?\n          end\n/m].to_s
  NxTest.assert(hook.include?('GhostTool.cancel_session'),
                'close hook panela nerusi ghost session')
  sel = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'), encoding: 'UTF-8')
  body = sel[/def on_model_switched\(model\).*?\n        end\n/m].to_s
  NxTest.assert(body.index('GhostTool.on_model_switched') < body.index('return unless @dialog'),
                'ghost sa musi zrusit aj pri ZAVRETOM paneli — cancel patri PRED guard @dialog')
end

NxTest.test('ghost sev: loader nacita modul AZ PO cabinet_builder (pouziva sev R-03)') do
  main = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  NxTest.assert(main.index("core/cabinet_builder'") < main.index("core/ghost_tool'"),
                'ghost_tool sa nacitava pred cabinet_builderom')
end

# --- 8) GHOST-FB (smoke feedback 31.8.2026) --------------------------------
# FB-1 hybrid v zamku · FB-2 kotva pod kurzorom · FB-3 pamat nastaveni ·
# FB-4 Ghost pasik (stav do panela + validacia rucnej vysky).

NxTest.test('ghost FB-1: v ZAMKU sa z inference bodu berie LEN X/Y, Z prepise zamok') do
  c = NxGhost.calc
  # Roh susednej skrinky lezi 720 mm nad podlahou — zamok ho stiahne na svoju rovinu.
  NxTest.assert_equal([1600.0, 300.0, 0.0], c.lock_point([1600.0, 300.0, 720.0], 0.0))
  # Horna skrinka: ta ista mechanika na rovine UPPER_HANG_Z.
  NxTest.assert_equal([1600.0, 300.0, 1400.0], c.lock_point([1600.0, 300.0, 90.0], 1400.0))
  # Rucne prestavena vyska zamku (FB-4) je pre hybrid obycajna rovina.
  NxTest.assert_equal([10.0, 20.0, 20.0], c.lock_point([10.0, 20.0, 999.0], 20.0))
end

NxTest.test('ghost FB-1: ZDRAVOTNY STROP plati aj na bod z inference (nie len na fallback luc)') do
  c = NxGhost.calc
  NxTest.assert(c.lock_point([2_000_000.0, 0.0, 0.0], 0.0).nil?, 'bod 2 km od originu nesmie byt polohou')
  NxTest.assert(c.lock_point([0.0, Float::INFINITY, 0.0], 0.0).nil?)
  NxTest.assert(c.lock_point([0.0, 0.0], 0.0).nil?, 'neuplny bod nie je poloha')
  NxTest.assert(c.lock_point(nil, 0.0).nil?)
  NxTest.assert(c.lock_point([1.0, 2.0, 3.0], Float::NAN).nil?, 'nezdrava rovina zamku nesmie prejst')
  NxTest.assert(c.lock_point([1.0, 2.0, 3.0], 2_000_000.0).nil?, 'rovina kilometre vysoko nie je poloha')
end

NxTest.test('ghost FB-2: prepnutie kotvy polozi NOVU kotvu pod kurzor (4 kotvy x 4 rotacie x oba rezimy)') do
  [[NxGhost.cfg, 0.0], [NxGhost.upper_cfg, NxGhost.hang]].each do |(c, home)|
    picked = [1500.0, 250.0, 640.0]
    %i[locked free].each do |mode|
      (0..3).each do |k|
        s = NxGhost.session(c, home)
        s.set_point(picked, true)
        k.times { s.rotate!(1) }
        s.set_z_mode!(mode)
        4.times do
          a = s.anchor_point_mm
          m = NxGhost.calc.matrix(anchor: a, picked: s.last_point, rotation_index: s.rotation_index,
                                  z_mode: s.z_mode, home_z: s.lock_plane_z)
          got = NxGhost.apply(m, a)
          NxTest.assert_close(picked[0], got[0], 1e-9,
                              "#{c[:type]}/#{mode}/k=#{k}/#{s.anchor}: kotva nie je pod kurzorom (X)")
          NxTest.assert_close(picked[1], got[1], 1e-9,
                              "#{c[:type]}/#{mode}/k=#{k}/#{s.anchor}: kotva nie je pod kurzorom (Y)")
          # Vo volnej vyske sadne kotva aj na Z kurzora; v zamku drzi origin
          # locknutu vysku (to je zmysel zamku — Z sa vedome NEsleduje).
          NxTest.assert_close(picked[2], got[2], 1e-9, 'free: kotva nesadla na Z kurzora') if mode == :free
          NxTest.assert_close(s.lock_plane_z, m[14], 1e-9, 'zamok: origin nedrzi locknutu vysku') if mode == :locked
          s.cycle_anchor!
        end
      end
    end
  end
end

NxTest.test('ghost FB-3: druha session ZDEDI kotvu, rotaciu, rezim aj locknute vysky') do
  mem = NxGhost.fresh_memory
  s1 = NxGhost.session(NxGhost.cfg, 0.0, memory: mem)
  s1.rotate!(1)
  s1.cycle_anchor!
  s1.set_z_mode!(:free)
  NxTest.assert(s1.set_lock_z!('250'))
  s2 = NxGhost.session(NxGhost.cfg, 0.0, memory: mem)
  NxTest.assert_equal(1, s2.rotation_index, 'rotacia sa nezdedila')
  NxTest.assert_equal(:fr_bottom, s2.anchor, 'kotva sa nezdedila')
  NxTest.assert_equal(:free, s2.z_mode, 'rezim vysky sa nezdedil')
  NxTest.assert_close(250.0, s2.lock_plane_z, 1e-9, 'locknuta vyska sa nezdedila')
  # Locknuta vyska je per TYP: horna si drzi svoju (default UPPER_HANG_Z).
  up = NxGhost.session(NxGhost.upper_cfg, NxGhost.hang, memory: mem)
  NxTest.assert_close(NxGhost.hang, up.lock_plane_z, 1e-9, 'horna prebrala vysku dolnej')
  NxTest.assert(up.set_lock_z!('1500'))
  s3 = NxGhost.session(NxGhost.cfg, 0.0, memory: mem)
  NxTest.assert_close(250.0, s3.lock_plane_z, 1e-9, 'zmena hornej prepisala dolnu')
  # PRVA session v behu = tovarenske hodnoty.
  fresh = NxGhost.session(NxGhost.cfg, 0.0)
  NxTest.assert_equal(0, fresh.rotation_index)
  NxTest.assert_equal(:fl_bottom, fresh.anchor)
  NxTest.assert_equal(:locked, fresh.z_mode)
  NxTest.assert_close(0.0, fresh.lock_plane_z, 1e-9)
end

NxTest.test('ghost FB-3: modulova pamat zije PER PROCES a reset ju vrati na defaulty') do
  gt = NxGhost.gt
  gt.reset_memory!
  begin
    m = gt.memory
    NxTest.assert_equal(:fl_bottom, m[:anchor])
    NxTest.assert_equal(:locked, m[:z_mode])
    NxTest.assert_equal(0, m[:rotation_index])
    NxTest.assert_equal({}, m[:lock_z])
    # Session BEZ vlastnej pamate pisze do modulovej (to je bezna cesta pluginu).
    s = gt::PlacementSession.new(model: Object.new, plan: NxGhost.plan)
    s.rotate!(1)
    s.cycle_anchor!
    s.set_lock_z!('120')
    NxTest.assert_equal(1, gt.memory[:rotation_index])
    NxTest.assert_equal(:fr_bottom, gt.memory[:anchor])
    NxTest.assert_close(120.0, gt.memory[:lock_z]['lower'], 1e-9)
    gt.reset_memory!
    NxTest.assert_equal(0, gt.memory[:rotation_index])
    NxTest.assert_equal({}, gt.memory[:lock_z])
  ensure
    gt.reset_memory!
  end
end

NxTest.test('ghost FB-4: validacia locknutej vysky — cislo v mm, rozsah 0..3000') do
  c = NxGhost.calc
  NxTest.assert_close(20.0, c.lock_z_value('20'), 1e-9)
  NxTest.assert_close(1400.5, c.lock_z_value('1400,5'), 1e-9, 'ciarka je desatinny oddelovac')
  NxTest.assert_close(1400.5, c.lock_z_value(' 1400.5 '), 1e-9)
  NxTest.assert_close(0.0, c.lock_z_value('0'), 1e-9)
  NxTest.assert_close(3000.0, c.lock_z_value('3000'), 1e-9)
  NxTest.assert_close(850.0, c.lock_z_value(850.0), 1e-9, 'Float z Ruby strany musi prejst')
  [nil, '', '   ', 'abc', '12abc', '-1', '3001', '1e3', '1/2', '--5'].each do |bad|
    NxTest.assert(c.lock_z_value(bad).nil?, "#{bad.inspect} nesmie prejst ako vyska")
  end
end

NxTest.test('ghost FB-4: neplatna vyska NIC nemeni; platna sa premietne do transformu aj do pamate') do
  mem = NxGhost.fresh_memory
  s = NxGhost.session(NxGhost.cfg, 0.0, memory: mem)
  NxTest.assert_close(0.0, s.lock_plane_z, 1e-9, 'dolna startuje na domacej vyske 0')
  NxTest.assert(!s.set_lock_z!('abc'), 'necislo sa nesmie prijat')
  NxTest.assert(!s.set_lock_z!('4000'), 'hodnota mimo rozsahu sa nesmie prijat')
  NxTest.assert_close(0.0, s.lock_plane_z, 1e-9, 'po neplatnom vstupe ma drzat STARA hodnota')
  NxTest.assert(s.set_lock_z!('20'))
  NxTest.assert_close(20.0, s.lock_plane_z, 1e-9)
  NxTest.assert(!s.set_lock_z!('20'), 'rovnaka hodnota nie je zmena')
  NxTest.assert_close(20.0, mem[:lock_z]['lower'], 1e-9, 'zmena sa nezapisala do pamate')
  a = s.anchor_point_mm
  m = NxGhost.calc.matrix(anchor: a, picked: [500.0, 100.0, 0.0], rotation_index: 0,
                          z_mode: :locked, home_z: s.lock_plane_z)
  NxTest.assert_close(20.0, m[14], 1e-9, 'zamok neposadil origin na rucne zadanu vysku')
  # Horna skrinka startuje na 1400 (850 pracovna vyska + 550 zastena).
  up = NxGhost.session(NxGhost.upper_cfg, NxGhost.hang, memory: NxGhost.fresh_memory)
  NxTest.assert_close(1400.0, up.lock_plane_z, 1e-9)
end

NxTest.test('ghost FB-4: stav pasika nesie kotvu, otocenie, rezim aj vysku — koniec session ho SCHOVA') do
  gt = NxGhost.gt
  s = NxGhost.session
  s.rotate!(1)
  s.cycle_anchor!
  p = gt.state_payload(s)
  NxTest.assert_equal(true, p['active'])
  NxTest.assert_equal('lower', p['type'])
  NxTest.assert_equal('fr_bottom', p['anchor'])
  NxTest.assert_equal('pravá dolná', p['anchor_label'])
  NxTest.assert_equal(90, p['rotation'])
  NxTest.assert_equal('locked', p['z_mode'])
  NxTest.assert_close(0.0, p['lock_z'], 1e-9)
  # Pasik NIE JE trvalou castou panela — bez session a po jej konci je prec.
  NxTest.assert_equal({ 'active' => false }, gt.state_payload(nil))
  s.cancel!('Esc')
  NxTest.assert_equal({ 'active' => false }, gt.state_payload(s))
  up = NxGhost.session(NxGhost.upper_cfg, NxGhost.hang)
  NxTest.assert_equal('upper', gt.state_payload(up)['type'])
  NxTest.assert_close(1400.0, gt.state_payload(up)['lock_z'], 1e-9)
end

NxTest.test('ghost sev FB: hybrid sa pyta inference PRVY, kresli natívne snapy a nic neuklada') do
  gt_src = NxGhost.src('noxun_engine', 'core', 'ghost_tool.rb')
  body = gt_src[/def pick_locked\(s, x, y, view\)(.*?)\n        end/m, 1].to_s
  NxTest.assert(!body.empty?, 'pick_locked sa nenasiel')
  NxTest.assert(body.include?('pick_ip_locked') && body.include?('pick_ray_locked'),
                'zamok nie je hybrid (inference + fallback rovina)')
  NxTest.assert(body.index('pick_ip_locked') < body.index('pick_ray_locked'),
                'inference sa musi pytat PRVA — fallback rovina je az druha')
  # BRANA: v zamku vyhrava inference LEN so snapom na REALNEJ geometrii.
  # „Volny" bod inference (podlahova rovina KRESLENIA) by odsunul hornu
  # skrinku od kurzora, pokazil zamok pri otocenych osiach a obisiel guardy
  # degenerovanych pohladov (MIN_SIN / MAX_REACH) — merane in-SU 3/6/8/8b.
  ipl = gt_src[/def pick_ip_locked\(s, x, y, view\)(.*?)\n        end/m, 1].to_s
  NxTest.assert(ipl.include?('ip_on_geometry?'),
                'zamok berie aj volny bod inference — obisiel by guardy degenerovanych pohladov')
  gate = gt_src[/def ip_on_geometry\?(.*?)\n        end/m, 1].to_s
  NxTest.assert(gate.include?('ip.vertex') && gate.include?('ip.edge') && gate.include?('ip.face'),
                'brana snapu sa nepyta na realnu geometriu (vrchol/hrana/plocha)')
  draw = gt_src[/def draw\(view\)(.*?)\n        end\n/m, 1].to_s
  NxTest.assert(draw.include?('draw_inference'), 'draw nekresli natívne zvyraznenie snapu')
  di = gt_src[/def draw_inference\(view\)(.*?)\n        end/m, 1].to_s
  NxTest.assert(di.include?('ip.draw(view)') && di.include?('view.tooltip'),
                'zvyraznenie snapu nejde natívnou cestou (ip.draw + tooltip)')
  NxTest.assert(di.include?('ip.display?'), 'snap sa ma kreslit len ked ho SketchUp chce zobrazit')
  # ZIADNE ukladanie nastaveni — pamat zije v procese, nie na disku ani v modeli.
  code = File.readlines(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'ghost_tool.rb'), encoding: 'UTF-8')
             .reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert(!code.include?('File.') && !code.include?('set_attribute') && !code.include?('write_defaults'),
                'ghost si nastavenia nesmie ukladat na disk ani do modelu')
end

NxTest.test('ghost sev FB: pole vysky ma guard identity dokumentu a pasik nie je trvalou castou panela') do
  cab = NxGhost.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  h = cab[/def handle_ghost_lock_z\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(!h.empty?, 'handle_ghost_lock_z chyba')
  NxTest.assert(h.index('foreign_document?') < h.index('GhostTool.session'),
                'guard identity dokumentu musi bezat PRED zmenou stavu session (R-02)')
  NxTest.assert(h.include?('GhostTool.push_state'), 'po zmene sa pasik neprekresli')
  panel = NxGhost.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.assert(panel.include?("cb(dlg, 'ghost_lock_z')"), 'callback pola vysky nie je registrovany')
  sync = NxGhost.src('noxun_engine', 'ui', 'panel', 'sync.rb')
  NxTest.assert(sync.include?('def push_ghost') && sync.include?('NX.setGhost'),
                'push stavu ghostu do panela chyba')
  html = NxGhost.src('noxun_engine', 'ui', 'panel.html')
  bar = html[/<div id="ghostBar"[^>]*>/].to_s
  NxTest.assert(!bar.empty?, 'Ghost pasik v paneli chyba')
  NxTest.assert(bar.include?('hidden'),
                'pasik musi startovat SKRYTY — vertikalny priestor panela je vzacny')
  NxTest.assert(html.include?('js/ghost_bar.js'), 'ghost_bar.js sa nenacitava')
  js = NxGhost.src('noxun_engine', 'ui', 'js', 'ghost_bar.js')
  NxTest.assert(js.include?('nxDocPayload'), 'pole vysky posiela payload bez identity dokumentu')
  NxTest.assert(js.include?('#i-info') == false, 'ikonu kresli HTML sprite, nie JS')
end

NxTest.test('ghost: prevod matice mm -> palce sa dotkne LEN translacie') do
  m = NxGhost.calc.matrix(anchor: [0.0, 0.0, 0.0], picked: [254.0, 0.0, 0.0],
                          rotation_index: 1, z_mode: :free, home_z: 0.0)
  inch = NxGhost.gt.to_inch_matrix(m)
  NxTest.assert_equal(m[0, 12], inch[0, 12], 'rotacna cast je bezrozmerna — nesmie sa menit')
  NxTest.assert_close(10.0, inch[12], 1e-9, '254 mm ma byt 10 palcov')
  NxTest.assert_equal(1.0, inch[15])
  NxTest.assert(Noxun::Engine::CabinetBuilder.rigid_matrix?(inch))
end
