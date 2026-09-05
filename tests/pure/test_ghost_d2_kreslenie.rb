# frozen_string_literal: true
# GHOST-D2 — KRESLENIE DOSKY NA ROZMER (Ghost 2.0). CISTA cast: parser
# meracieho pola, limity pre VSETKY zdroje rozmeru, fazovy automat dvoch
# tahov, geometria faz (rovina 1. tahu, pevna os 2. tahu, degeneracie),
# pravotocivost zaporneho tahu, whitelist zamkov a `BoardBuilder.replan`.
# Bez SketchUpu, bez modelu, bez entit.
#
# Co sa overuje (a preco to nie je klikanie):
#   1) PARSER — `String#to_l` na slovenskom Windows padne pri bodke a bez
#      jednotky si vezme sablonu modelu, `to_f` by z „abc2400xyz" spravilo
#      0.0 a z „2400mmjunk" 2400.0; jedina obrana je UPLNA zhoda,
#   2) LIMITY pre KAZDY zdroj rozmeru (pisane cislo, zamok, hodnota karty,
#      tah mysou) — inak `normalize` ticho oreze a nahlad ukaze 6000, kym
#      model dostane 5000,
#   3) FAZOVY AUTOMAT so vsetkymi 4 kombinaciami zamkov — zamknuta faza sa
#      preskakuje a pri preskocenej faze dlzky je smer KANONICKY,
#   4) GEOMETRIA: faza 1 HLADA SMER v rovine Z pociatku (ziadna projekcia
#      na „lokalnu os" — os este neexistuje), faza 2 MERIA po PEVNEJ osi;
#      NULOVY vektor sa NIKDY nedostane do transformacie,
#   5) DEGENERACIE lucov z OBOCH stran (takmer rovnobezny pohlad, rovina za
#      kamerou, zdravy dosah) — bez nich by doska odletela alebo by zmenila
#      znamienko sirky,
#   6) `replan` = novy ZMRAZENY plan s finalnymi rozmermi, ktory ZACHOVA
#      vyrobny snapshot (katalog sa uz necita) a spravne rozlisi explicitny
#      a automaticky nazov.
require_relative '../helper' unless defined?(NxTest)

module NxGD2
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

  def cfg(extra = {})
    { role: 'free_panel', name: 'Doska', length: 800.0, width: 600.0, thickness: 18.0,
      material_id: 'MAT_D2', grain_direction: 'length',
      edges: { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
      quantity: 1, orientation: 'leziaca' }.merge(extra)
  end

  def plan(config = cfg, orientation = nil, model = Object.new, template_ref = nil, auto_name = false)
    o = orientation || config[:orientation].to_s
    bb::BoardPlan.new(model, config, bb.board_config(config), o, template_ref, auto_name)
  end

  def fresh_memory
    { anchor: gt::ANCHORS.first, rotation_index: 0 }
  end

  # Session v rezime KRESLENIA. `locks` uz presli whitelistom (`draw_locks`).
  def session(config = cfg, orientation: nil, locks: nil, rotation: 0, memory: nil)
    mem = memory || fresh_memory
    mem[:rotation_index] = rotation
    gt::PlacementSession.new(model: Object.new, plan: plan(config, orientation),
                             subject: :board, interaction: :drawing, memory: mem,
                             orientation: orientation || config[:orientation], locks: locks)
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

  def near?(a, b, tol = 0.01)
    (a.to_f - b.to_f).abs <= tol
  end

  def vec_near?(v, x, y, z, tol = 1e-6)
    near?(v[0], x, tol) && near?(v[1], y, tol) && near?(v[2], z, tol)
  end

  def with_catalog(sheets)
    sc = e::Materials.singleton_class
    sc.send(:alias_method, :sheet_nxd2_orig, :sheet)
    sc.send(:define_method, :sheet) { |id| sheets[id.to_s] }
    yield
  ensure
    sc.send(:alias_method, :sheet, :sheet_nxd2_orig)
    sc.send(:remove_method, :sheet_nxd2_orig)
  end

  def sheet(id, thickness, extra = {})
    { 'material_id' => id, 'thickness' => thickness, 'decor' => 'DEK',
      'grain' => 'length' }.merge(extra)
  end
end

# ---------------------------------------------------------------------------
# 1) PARSER MERACIEHO POLA — uplna zhoda po `strip`
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 parser: cele cislo, desatinna bodka aj CIARKA') do
  NxTest.assert_equal(2400.0, NxGD2.calc.parse_mm('2400'))
  NxTest.assert_equal(600.5, NxGD2.calc.parse_mm('600.5'))
  NxTest.assert_equal(600.5, NxGD2.calc.parse_mm('600,5'), 'slovenska klavesnica pise CIARKU')
end

NxTest.test('GHOST-D2 parser: `mm` je volitelne a NEZAVISI na velkosti pismen') do
  NxTest.assert_equal(2400.0, NxGD2.calc.parse_mm('2400mm'))
  NxTest.assert_equal(2400.0, NxGD2.calc.parse_mm('2400 mm'))
  NxTest.assert_equal(2400.0, NxGD2.calc.parse_mm('2400MM'))
  NxTest.assert_equal(2400.0, NxGD2.calc.parse_mm('  2400 Mm  '), 'medzery po oboch stranach')
end

NxTest.test('GHOST-D2 parser: prefix, sufix, tilda a `;` su NEPLATNE (nie „skoro dobre")') do
  # `to_f` by z tychto spravilo cisla — presne to je dovod vlastneho parsera.
  ['abc2400xyz', '2400mmjunk', '~600', '600;18', '600 18', '', '   ', 'mm',
   '-600', '+600', '1e3', '600.', '.5', '600,,5', '600mm2'].each do |bad|
    NxTest.assert_equal(nil, NxGD2.calc.parse_mm(bad), "„#{bad}" + '" sa NESMIE prijat')
  end
end

NxTest.test('GHOST-D2 parser: hodnota sa zaokruhli na 0,01 mm UZ PRI PRIJATI') do
  NxTest.assert_equal(600.12, NxGD2.calc.parse_mm('600,123'), 'nahlad = config = geometria')
  NxTest.assert_equal(600.13, NxGD2.calc.parse_mm('600,125'))
  NxTest.assert_equal(600.12, NxGD2.calc.round_mm(600.1234))
end

NxTest.test('GHOST-D2 parser: `String#to_l` ani `to_f` sa na SUROVY text nevolaju') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  body = s[/def parse_mm\(text\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'parser sa nasiel')
  NxTest.refute(body.include?('.to_l'), '`to_l` na slovenskom Windows padne pri bodke')
  NxTest.assert(body.include?('DIM_TEXT_RE.match'), 'rozhoduje UPLNA zhoda regexu')
end

# ---------------------------------------------------------------------------
# 2) LIMITY — pre VSETKY zdroje rozmeru, PRED posunom fazy
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 limity: hranice dlzky (9 / 10 / 5000 / 5001) a sirky (3000 / 3001)') do
  NxTest.refute(NxGD2.calc.dim_ok?(:length, 9.0))
  NxTest.assert(NxGD2.calc.dim_ok?(:length, 10.0), 'dolna hranica PATRI dnu')
  NxTest.assert(NxGD2.calc.dim_ok?(:length, 5000.0), 'horna hranica PATRI dnu')
  NxTest.refute(NxGD2.calc.dim_ok?(:length, 5001.0))
  NxTest.assert(NxGD2.calc.dim_ok?(:width, 3000.0))
  NxTest.refute(NxGD2.calc.dim_ok?(:width, 3001.0))
  NxTest.refute(NxGD2.calc.dim_ok?(:width, 9.0))
end

NxTest.test('GHOST-D2 limity: zdroj pravdy je `BoardBuilder::LIMITS` (ziadna kopia cisel)') do
  NxTest.assert_equal(NxGD2.bb::LIMITS[:length].map(&:to_f), NxGD2.calc.dim_limits(:length))
  NxTest.assert_equal(NxGD2.bb::LIMITS[:width].map(&:to_f), NxGD2.calc.dim_limits(:width))
end

NxTest.test('GHOST-D2 limity: tah nad limit sa v NAHLADE OREZE (klik ho odmietne zvlast)') do
  NxTest.assert_equal(5000.0, NxGD2.calc.dim_clamp(:length, 6000.0))
  NxTest.assert_equal(10.0, NxGD2.calc.dim_clamp(:length, 1.0))
  NxTest.assert_equal(3000.0, NxGD2.calc.dim_clamp(:width, 9999.0))
end

NxTest.test('GHOST-D2 limity: hlaska nesie ROZSAH aj nazov rozmeru') do
  msg = NxGD2.calc.dim_limit_message(:length)
  NxTest.assert(msg.include?('Dĺžka') && msg.include?('10') && msg.include?('5000'), msg)
  NxTest.assert(NxGD2.calc.dim_limit_message(:width).include?('Šírka'))
end

NxTest.test('GHOST-D2 limity: PISANE cislo mimo limitu fazu NEPOSUNIE') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  NxTest.assert_equal(:length, s.draw_phase)
  NxTest.refute(s.confirm_draw!(:length, 6000.0), '6000 mm je nad limitom')
  NxTest.assert_equal(:length, s.draw_phase, 'faza OSTAVA')
  NxTest.assert_equal(nil, s.draw_length_mm, 'a hodnota sa nezapisala')
  NxTest.assert(s.confirm_draw!(:length, 2400.0))
  NxTest.assert_equal(:width, s.draw_phase)
  NxTest.assert_equal(2400.0, s.draw_length_mm)
end

NxTest.test('GHOST-D2 limity: ZAMOK mimo limitu session NESPUSTI (whitelist `draw_locks`)') do
  locks, err = NxGD2.calc.draw_locks('length' => 6000)
  NxTest.assert_equal({}, locks)
  NxTest.assert(!err.nil? && err.include?('5000'), err.to_s)
  locks2, err2 = NxGD2.calc.draw_locks('width' => 5)
  NxTest.assert_equal({}, locks2)
  NxTest.assert(!err2.nil?, 'sirka pod limitom tiez odmieta start')
end

# ---------------------------------------------------------------------------
# 3) WHITELIST ZAMKOV — payload `draw_board`
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 zamky: whitelist prepusti LEN `length` a `width`') do
  locks, err = NxGD2.calc.draw_locks('length' => 800, 'width' => 600,
                                    'thickness' => 25, 'height' => 700, 'evil' => 1)
  NxTest.assert_equal(nil, err)
  NxTest.assert_equal({ length: 800.0, width: 600.0 }, locks, 'cudzie kluce sa TICHO zahadzuju')
end

NxTest.test('GHOST-D2 zamky: nezamknuty kluc v mape CHYBA (ziadny prevod na Boolean)') do
  locks, = NxGD2.calc.draw_locks('length' => 800)
  NxTest.assert_equal({ length: 800.0 }, locks)
  NxTest.refute(locks.key?(:width), 'nezamknuta sirka sa neposiela vobec')
  empty, err = NxGD2.calc.draw_locks({})
  NxTest.assert_equal([{}, nil], [empty, err])
end

NxTest.test('GHOST-D2 zamky: NECISLO (text aj Boolean) session NESPUSTI') do
  ['800', true, false, nil.to_s, []].each do |bad|
    next if bad.nil?

    locks, err = NxGD2.calc.draw_locks('length' => bad)
    NxTest.assert_equal({}, locks, "„#{bad.inspect}" + '" nie je cislo')
    NxTest.assert(!err.nil?, "„#{bad.inspect}" + '" musi dat chybu')
  end
end

NxTest.test('GHOST-D2 zamky: cudzi tvar payloadu (nie Hash) = ZIADNE zamky, ziadna chyba') do
  [nil, 'x', 42, []].each do |raw|
    NxTest.assert_equal([{}, nil], NxGD2.calc.draw_locks(raw))
  end
end

NxTest.test('GHOST-D2 zamky: do VYROBNEHO configu sa NIKDY nedostanu') do
  s = NxGD2.session(locks: { length: 1200.0, width: 500.0 })
  s.begin_draw!([0.0, 0.0, 0.0])
  NxTest.assert_equal(:done, s.draw_phase, 'obe fazy zamknute = commit hned')
  p2 = NxGD2.bb.replan(s.plan, length: s.draw_length_mm, width: s.draw_width_mm)
  NxTest.refute(p2.stored_config.key?(:locks), 'zapisovy config zamky nenesie')
  NxTest.refute(p2.config.key?(:locks))
  NxTest.refute(p2.stored_config.to_s.include?('lock'), 'ani v inej podobe')
end

# ---------------------------------------------------------------------------
# 4) FAZOVY AUTOMAT — vsetky 4 kombinacie zamkov
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 automat: BEZ zamkov — pociatok -> dlzka -> sirka -> hotovo') do
  s = NxGD2.session
  NxTest.assert_equal(:origin, s.draw_phase)
  NxTest.assert_equal(:drawing, s.interaction)
  NxTest.assert(s.drawing? && !s.placement?)
  s.begin_draw!([100.0, 200.0, 0.0])
  NxTest.assert_equal(:length, s.draw_phase)
  s.confirm_draw!(:length, 2400.0)
  NxTest.assert_equal(:width, s.draw_phase)
  s.confirm_draw!(:width, 600.0)
  NxTest.assert_equal(:done, s.draw_phase)
  NxTest.assert(s.draw_ready?)
end

NxTest.test('GHOST-D2 automat: ZAMKNUTA DLZKA — faza dlzky sa PRESKOCI, smer je KANONICKY') do
  s = NxGD2.session(locks: { length: 900.0 })
  s.begin_draw!([0.0, 0.0, 0.0])
  NxTest.assert_equal(:width, s.draw_phase, '1. tah odpadol')
  NxTest.assert_equal(900.0, s.draw_length_mm)
  NxTest.assert(s.draw_canonical_dir?, 'smer je kanonicky (lokalna +X podla rotacie)')
  NxTest.assert(NxGD2.vec_near?(s.draw_dir_x, 1.0, 0.0, 0.0))
end

NxTest.test('GHOST-D2 automat: ZAMKNUTA SIRKA — 2. tah odpadne a commit pride po dlzke') do
  s = NxGD2.session(locks: { width: 450.0 })
  s.begin_draw!([0.0, 0.0, 0.0])
  NxTest.assert_equal(:length, s.draw_phase)
  s.confirm_draw!(:length, 1000.0)
  NxTest.assert_equal(:done, s.draw_phase)
  NxTest.assert_equal(450.0, s.draw_width_mm)
end

NxTest.test('GHOST-D2 automat: OBE zamknute — klik pociatku hned commituje') do
  s = NxGD2.session(locks: { length: 1200.0, width: 500.0 })
  s.begin_draw!([50.0, 60.0, 70.0])
  NxTest.assert_equal(:done, s.draw_phase)
  NxTest.assert_equal([1200.0, 500.0], [s.draw_length_mm, s.draw_width_mm])
  NxTest.assert(s.draw_ready?)
end

NxTest.test('GHOST-D2 automat: CISLO BEZ POHYBU MYSOU -> kanonicky smer podla rotacie') do
  # Rotacia 1 = +90°, teda lokalna +X mieri po svetovej +Y.
  s = NxGD2.session(rotation: 1)
  s.begin_draw!([0.0, 0.0, 0.0])
  NxTest.assert_equal(nil, s.draw_dir_x, 'pred potvrdenim este smer NIE JE')
  s.confirm_draw!(:length, 2400.0)
  NxTest.assert(s.draw_canonical_dir?)
  NxTest.assert(NxGD2.vec_near?(s.draw_dir_x, 0.0, 1.0, 0.0), s.draw_dir_x.inspect)
end

NxTest.test('GHOST-D2 automat: NULOVY vektor sa NIKDY nedostane do transformacie') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  # Kurzor sa nepohol: nahlad dostal PRESNE pociatok.
  s.preview_length!([0.0, 0.0, 0.0])
  NxTest.assert_equal(nil, s.draw_dir_x, 'nulovy tah smer NENASTAVI')
  s.confirm_draw!(:length, 2400.0)
  m = s.draw_matrix_vals
  NxTest.assert(!m.nil?, 'matica existuje')
  NxTest.assert(NxGD2.near?((m[0] * m[0]) + (m[1] * m[1]), 1.0, 1e-9), 'a jej os X je JEDNOTKOVA')
end

NxTest.test('GHOST-D2 automat: Esc/zrusenie nechava session BEZ zapisu (terminalny stav)') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.confirm_draw!(:length, 2400.0)
  NxTest.assert(s.cancel!('Esc'))
  NxTest.assert(s.terminal? && !s.active?)
  NxTest.refute(s.cancel!('Esc'), 'druhy cancel je no-op')
end

NxTest.test('GHOST-D2 peciatka: Esc v HOCIKTOREJ faze sablonu NEOPECIATKUJE') do
  calls = 0
  # Rozkreslena doska (pociatok + dlzka) — pouzivatel to vzda Esc-om.
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.confirm_draw!(:length, 2400.0)
  NxTest.assert(s.cancel!('Esc'))
  NxTest.assert_equal(0, calls, 'Esc peciatku NEZAPISE (volajuci pri zrusenej session nebezi)')
  # A jedina cesta k peciatke je post-commit handler — nie start ani cancel.
  ab = NxGD2.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')
  draw = ab[/def handle_draw_board\(payload\).*?\n        end\n/m].to_s
  NxTest.refute(draw.include?('stamp'), 'start kreslenia peciatku NEZAPISUJE')
  after = ab[/def ghost_after_commit_board\(model, inst, session\).*?\n        end\n/m].to_s
  NxTest.assert(after.include?('session.stamp_once!'), 'peciatka az po USPESNOM commite')
  # `stamp_once!` je aj tu presne raz.
  s2 = NxGD2.session
  NxTest.assert(s2.stamp_once! { calls += 1 })
  NxTest.refute(s2.stamp_once! { calls += 1 }, 'druhy pokus je no-op')
  NxTest.assert_equal(1, calls)
end

NxTest.test('GHOST-D2 bariera: `flush_pending! == false` vrati :blocked aj pri kresleni') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.confirm_draw!(:length, 2400.0)
  s.confirm_draw!(:width, 600.0, sign: 1.0)
  NxTest.assert(s.draw_ready?)
  sc = NxGD2.e::ScaleWatch.singleton_class
  sc.send(:alias_method, :flush_nxgd2_orig, :flush_pending!)
  sc.send(:define_method, :flush_pending!) { |_m| false }
  begin
    NxTest.assert_equal(:blocked, s.commit!(:fake_transform), 'bariera zastavila commit')
    NxTest.assert(s.active?, 'session ZIJE dalej (pouzivatel skusi klik znova)')
    NxTest.assert_equal(:done, s.draw_phase, 'a rozkreslene rozmery ostali')
  ensure
    sc.send(:alias_method, :flush_pending!, :flush_nxgd2_orig)
    sc.send(:remove_method, :flush_nxgd2_orig)
  end
end

NxTest.test('GHOST-D2 automat: `drawing` je vyhradene DOSKE (skrinka spadne na placement)') do
  cab = { type: 'lower', width: 600.0, height: 720.0, depth: 510.0,
          thickness: 18.0, floor_height: 100.0, bottom_mode: 'under_sides' }
  s = NxGD2.gt::PlacementSession.new(
    model: Object.new,
    plan: Noxun::Engine::CabinetBuilder::InsertPlan.new(Object.new, cab, 0.0),
    subject: :cabinet, interaction: :drawing, memory: { anchor: :fl_bottom, z_mode: :locked,
                                                        rotation_index: 0, lock_z: {} }
  )
  NxTest.assert_equal(:placement, s.interaction, 'skrinka kreslenie NEPOZNA')
  NxTest.refute(s.drawing?)
end

# ---------------------------------------------------------------------------
# 5) GEOMETRIA FAZY 1 — smer v rovine Z pociatku
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 faza 1: smer je VODOROVNY aj ked kurzor lezi vyssie') do
  d = NxGD2.calc.horizontal_dir([0.0, 0.0, 0.0], [1000.0, 0.0, 800.0])
  NxTest.assert(NxGD2.vec_near?(d, 1.0, 0.0, 0.0), 'zvisla zlozka do smeru NEVSTUPUJE')
  NxTest.assert_equal(1000.0, NxGD2.calc.horizontal_length([0.0, 0.0, 0.0], [1000.0, 0.0, 800.0]))
end

NxTest.test('GHOST-D2 faza 1: SIKMY tah 45° dava rotaciu 45° (ziadna projekcia na „lokalnu os")') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([1000.0, 1000.0, 0.0])
  d = s.draw_dir_x
  NxTest.assert(NxGD2.near?(d[0], Math.sqrt(0.5), 1e-6) && NxGD2.near?(d[1], Math.sqrt(0.5), 1e-6),
                "smer 45° ostal 45° (#{d.inspect})")
  NxTest.assert(NxGD2.near?(s.draw_phase_value, Math.sqrt(2.0) * 1000.0, 0.02), s.draw_phase_value.to_s)
end

NxTest.test('GHOST-D2 faza 1: axis snap je POMOCKA — pritiahne 1°, 45° necha tak') do
  # 1° od osi X: snap na presnu os.
  a = Math.tan(1.0 * Math::PI / 180.0) * 1000.0
  d1 = NxGD2.calc.axis_snap(NxGD2.calc.horizontal_dir([0.0, 0.0, 0.0], [1000.0, a, 0.0]))
  NxTest.assert(NxGD2.vec_near?(d1, 1.0, 0.0, 0.0), "1° sa prilepilo na os (#{d1.inspect})")
  d45 = NxGD2.calc.axis_snap([1.0, 1.0, 0.0])
  NxTest.assert(NxGD2.near?(d45[0], Math.sqrt(0.5), 1e-9), '45° sa NEPRILEPILO')
  # 10° je uz mimo tolerancie — pomocka nesmie brat volnost.
  b = Math.tan(10.0 * Math::PI / 180.0) * 1000.0
  d10 = NxGD2.calc.axis_snap(NxGD2.calc.horizontal_dir([0.0, 0.0, 0.0], [1000.0, b, 0.0]))
  NxTest.refute(NxGD2.vec_near?(d10, 1.0, 0.0, 0.0), '10° ostava sikme')
end

NxTest.test('GHOST-D2 faza 1: nulovy vektor vrati nil (a NIE nahodny smer)') do
  NxTest.assert_equal(nil, NxGD2.calc.horizontal_dir([5.0, 5.0, 0.0], [5.0, 5.0, 900.0]),
                      'ciste zvisly tah vodorovny smer NEDAVA')
  NxTest.assert_equal(nil, NxGD2.calc.horizontal_dir(nil, [1.0, 1.0, 0.0]))
end

# ---------------------------------------------------------------------------
# 6) GEOMETRIA FAZY 2 — pevna os per orientacia + pravotocivost
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 faza 2: LEZIACA meria po vodorovnej kolmici, STOJACA po svetovej +Z') do
  dir = [1.0, 0.0, 0.0]
  NxTest.assert(NxGD2.vec_near?(NxGD2.calc.board_measure_axis('leziaca', dir), 0.0, 1.0, 0.0),
                'leziaca: Z x dir_x')
  NxTest.assert(NxGD2.vec_near?(NxGD2.calc.board_measure_axis('stojaca', dir), 0.0, 0.0, 1.0),
                'stojaca: vyska pilastra ide hore')
  NxTest.assert_equal(NxGD2.calc.board_measure_axis('stojaca', dir),
                      NxGD2.calc.board_measure_axis('na_stenu', dir),
                      'na_stenu zdiela os so stojacou (rozdiel je len v configu)')
end

NxTest.test('GHOST-D2 faza 2: os leziacej sa OTACA so smerom 1. tahu') do
  ax = NxGD2.calc.board_measure_axis('leziaca', [0.0, 1.0, 0.0])
  NxTest.assert(NxGD2.vec_near?(ax, -1.0, 0.0, 0.0), ax.inspect)
end

NxTest.test('GHOST-D2 faza 2: znamienkovy priemet rozlisi obe strany') do
  o = [0.0, 0.0, 0.0]
  ax = [0.0, 1.0, 0.0]
  NxTest.assert_equal(600.0, NxGD2.calc.project_on_axis(o, ax, [10.0, 600.0, 0.0]))
  NxTest.assert_equal(-600.0, NxGD2.calc.project_on_axis(o, ax, [10.0, -600.0, 0.0]))
end

NxTest.test('GHOST-D2 pravotocivost: ZAPORNY 2. tah posunie POCIATOK, osi ostavaju pravotocive') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([1000.0, 0.0, 0.0])
  s.confirm_draw!(:length, 1000.0)
  s.preview_width!(-600.0) # tah na opacnu stranu
  s.confirm_draw!(:width, 600.0, sign: s.draw_width_sign)
  o = s.draw_placement_origin
  NxTest.assert(NxGD2.vec_near?(o, 0.0, -600.0, 0.0, 0.01), "pociatok sa posunul o −sirka (#{o.inspect})")
  m = s.draw_matrix_vals
  # Osi matice: X = dir_x, Y = Z x X, Z = +Z; determinant +1 (pravotociva).
  NxTest.assert(NxGD2.vec_near?([m[0], m[1], m[2]], 1.0, 0.0, 0.0), 'os X ostala smerom tahu')
  NxTest.assert(NxGD2.vec_near?([m[4], m[5], m[6]], 0.0, 1.0, 0.0), 'os Y sa NEOBRATILA')
  NxTest.assert(NxGD2.vec_near?([m[8], m[9], m[10]], 0.0, 0.0, 1.0))
end

NxTest.test('GHOST-D2 pravotocivost: KLADNY 2. tah pociatok NEPOSUNIE') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.confirm_draw!(:length, 1000.0)
  s.preview_width!(600.0)
  s.confirm_draw!(:width, 600.0, sign: s.draw_width_sign)
  NxTest.assert(NxGD2.vec_near?(s.draw_placement_origin, 0.0, 0.0, 0.0, 0.01))
end

NxTest.test('GHOST-D2 pravotocivost: PISANE cislo znamena vzdy KLADNY smer') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.confirm_draw!(:length, 1000.0)
  s.preview_width!(-600.0)       # stary tah bol zaporny
  s.confirm_draw!(:width, 600.0, sign: 1.0) # ale cislo je kladne
  NxTest.assert(NxGD2.vec_near?(s.draw_placement_origin, 0.0, 0.0, 0.0, 0.01),
                'stary zaporny tah do napisanej hodnoty NEPRESIAKNE')
end

NxTest.test('GHOST-D2 matica: kanonicka transformacia je RIGIDNA a pravotociva (R-03)') do
  [0, 1, 2, 3].each do |rot|
    dir = NxGD2.calc.canonical_dir_x(rot)
    m = NxGD2.calc.draw_matrix(origin: [123.0, -45.0, 67.0], dir_x: dir)
    NxTest.assert(Noxun::Engine::CabinetBuilder.rigid_matrix?(m), "rotacia #{rot * 90}°")
  end
  # Aj SIKMY smer (45°) musi prejst — inak by sa nakreslena doska nedala vlozit.
  m45 = NxGD2.calc.draw_matrix(origin: [0.0, 0.0, 0.0], dir_x: [Math.sqrt(0.5), Math.sqrt(0.5), 0.0])
  NxTest.assert(Noxun::Engine::CabinetBuilder.rigid_matrix?(m45), 'sikmy smer 45°')
end

NxTest.test('GHOST-D2 matica: kliknuty POCIATOK je lokalna (0,0,0) dosky') do
  s = NxGD2.session
  s.begin_draw!([500.0, 300.0, 720.0])
  s.preview_length!([1500.0, 300.0, 720.0])
  s.confirm_draw!(:length, 1000.0)
  s.confirm_draw!(:width, 600.0, sign: 1.0)
  pt = NxGD2.apply(s.draw_matrix_vals, [0.0, 0.0, 0.0])
  NxTest.assert(NxGD2.vec_near?(pt, 500.0, 300.0, 720.0, 0.01), pt.inspect)
  # A protilahly roh lezi presne o dlzku/sirku dalej.
  far = NxGD2.apply(s.draw_matrix_vals, [1000.0, 600.0, 0.0])
  NxTest.assert(NxGD2.vec_near?(far, 1500.0, 900.0, 720.0, 0.01), far.inspect)
end

# ---------------------------------------------------------------------------
# 7) DEGENERACIE — fallback `pickray` -> rovina (faza 1) a -> os (faza 2)
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 fallback faza 1: priesecnik luca s rovinou Z pociatku (zdieľany guard D1)') do
  pt = NxGD2.calc.ray_plane([0.0, 0.0, 1000.0], [0.0, 0.0, -1.0], 720.0)
  NxTest.assert(NxGD2.vec_near?(pt, 0.0, 0.0, 720.0, 0.01), pt.inspect)
end

NxTest.test('GHOST-D2 fallback faza 1: rovina ZA KAMEROU sa odmietne (`t >= 0`)') do
  NxTest.assert_equal(nil, NxGD2.calc.ray_plane([0.0, 0.0, 1000.0], [0.0, 0.0, 1.0], 720.0),
                      'luc mieri HORE, rovina je pod kamerou')
end

NxTest.test('GHOST-D2 fallback faza 1: takmer rovnobezny pohlad z OBOCH stran = nil') do
  eps = 1e-5
  NxTest.assert_equal(nil, NxGD2.calc.ray_plane([0.0, 0.0, 1000.0], [1.0, 0.0, -eps], 720.0))
  NxTest.assert_equal(nil, NxGD2.calc.ray_plane([0.0, 0.0, 400.0], [1.0, 0.0, eps], 720.0))
end

NxTest.test('GHOST-D2 fallback faza 2: najblizsi bod luca a PRIAMKY osi (zvisla os pilastra)') do
  # Kamera vpredu, luc vodorovne dozadu; os je zvisla priamka cez pociatok.
  pt = NxGD2.calc.ray_axis_point([0.0, -2000.0, 900.0], [0.0, 1.0, 0.0],
                                [0.0, 0.0, 0.0], [0.0, 0.0, 1.0])
  NxTest.assert(!pt.nil?, 'bod na osi existuje')
  NxTest.assert(NxGD2.vec_near?(pt, 0.0, 0.0, 900.0, 0.01), pt.inspect)
end

NxTest.test('GHOST-D2 fallback faza 2: TAKMER ROVNOBEZNY luc s osou = nil (z OBOCH stran)') do
  eps = 1e-5
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, 0.0, -2000.0], [eps, 0.0, 1.0],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]),
                      'luc zdola takmer po osi')
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, 0.0, 2000.0], [eps, 0.0, -1.0],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]),
                      'a to iste zhora')
end

NxTest.test('GHOST-D2 fallback faza 2: luc SMEROM OD osi (`t < 0`) sa odmietne') do
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, -2000.0, 900.0], [0.0, -1.0, 0.0],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]),
                      'os lezi ZA kamerou')
end

NxTest.test('GHOST-D2 fallback faza 2: vysledok mimo zdraveho dosahu sa odmietne') do
  far = NxGD2.calc::MAX_REACH_MM * 10.0
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, -far, far], [0.0, 1.0, 0.0],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]))
end

NxTest.test('GHOST-D2 fallback faza 2: nulovy alebo nekonecny vstup = nil (ziadny NaN v modeli)') do
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, 0.0, 0.0], [0.0, 0.0, 0.0],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]))
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, 0.0, 0.0], [0.0, 1.0, Float::NAN],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]))
  NxTest.assert_equal(nil, NxGD2.calc.ray_axis_point([0.0, -100.0, 0.0], [0.0, 1.0, 0.0],
                                                    [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]))
end

NxTest.test('GHOST-D2: OTOCENE drawing axes na fazy NEVPLYVAJU (vsetko je svetovy ram)') do
  # Cela matematika faz pracuje so SVETOVYMI suradnicami (mm) — v kode sa
  # nikde necitaju `model.axes`. Regresia by znamenala, ze doska pri otocenych
  # osiach kreslenia odskoci od kurzora (presne to zmerala in-SU sada D1).
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  body = s[/# GHOST-D2 — KRESLENIE DOSKY NA ROZMER.*?def draw_matrix\(origin:, dir_x:\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'sekcia D2 sa nasla')
  NxTest.refute(body.include?('.axes'), 'ziadne citanie drawing axes')
end

# ---------------------------------------------------------------------------
# 8) OBALKA NAHLADU pocas fazy
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 obalka: nahlad rastie s TAHOM (nie zo zmrazeneho configu)') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([1500.0, 0.0, 0.0])
  xs = s.corners_mm.map { |p| p[0] }
  NxTest.assert(NxGD2.near?(xs.max, 1500.0, 0.02), "obalka ma dlzku tahu (#{xs.max})")
  # Sirka este nie je znama -> plati hodnota KARTY (doska je citatelna hned).
  ys = s.corners_mm.map { |p| p[1] }
  NxTest.assert(NxGD2.near?(ys.max, 600.0, 0.02), "sirka drzi hodnotu karty (#{ys.max})")
end

NxTest.test('GHOST-D2 obalka: STOJACA doska ma sirku na osi Z (pilaster)') do
  s = NxGD2.session(NxGD2.cfg(orientation: 'stojaca'), orientation: 'stojaca')
  s.begin_draw!([0.0, 0.0, 0.0])
  s.confirm_draw!(:length, 600.0)
  s.preview_width!(2200.0)
  zs = s.corners_mm.map { |p| p[2] }
  NxTest.assert(NxGD2.near?(zs.max, 2200.0, 0.02), "vyska pilastra rastie po Z (#{zs.max})")
  ys = s.corners_mm.map { |p| p[1] }
  NxTest.assert(NxGD2.near?(ys.max, 18.0, 0.02), "a hrubka ostava na Y (#{ys.max})")
end

NxTest.test('GHOST-D2 obalka: tah nad limit sa v nahlade OREZE a session to prizna') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([6000.0, 0.0, 0.0])
  NxTest.assert_equal(5000.0, s.draw_phase_value, 'nahlad ukaze LIMIT, nie 6000')
  NxTest.assert_equal(6000.0, s.draw_over_limit, 'ale session vie, ze tah je mimo')
end

# ---------------------------------------------------------------------------
# 9) SHIFT — zamknuty SMER drzi aj vo volnom priestore
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 Shift: po zamknuti uz pohyb kurzora SMER nezmeni') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([1000.0, 0.0, 0.0])
  NxTest.assert(s.lock_draw_dir!, 'Shift zamkol aktualny smer')
  before = s.draw_dir_x.dup
  # Kurzor odbehol o 60° — smer sa NESMIE pohnut.
  s.preview_length!([500.0, 866.0, 0.0])
  NxTest.assert(NxGD2.vec_near?(s.draw_dir_x, before[0], before[1], before[2], 1e-9),
                "smer drzi (#{s.draw_dir_x.inspect})")
  # A dlzka je PRIEMET na zamknuty smer, nie vzdialenost kurzora.
  NxTest.assert(NxGD2.near?(s.draw_phase_value, 500.0, 0.02), s.draw_phase_value.to_s)
end

NxTest.test('GHOST-D2 Shift: zamok sa uvolni pri ZMENE FAZY (nesmie obmedzit 2. tah)') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([1000.0, 0.0, 0.0])
  s.lock_draw_dir!
  NxTest.assert(!s.draw_locked_dir.nil?)
  s.confirm_draw!(:length, 1000.0)
  NxTest.assert_equal(nil, s.draw_locked_dir, 'zmena fazy zamok VZDY pusti')
end

NxTest.test('GHOST-D2 Shift: `release_draw_dir!` je idempotentny (Esc, deactivate, suspend)') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.lock_draw_dir!([1.0, 0.0, 0.0])
  NxTest.assert(s.release_draw_dir!)
  NxTest.assert(s.release_draw_dir!, 'druhe uvolnenie nic nerozbije')
  NxTest.assert_equal(nil, s.draw_locked_dir)
end

# In-SU beh #299: `inference_locked?` bol po Shifte FALSE. Natívny zámok
# potrebuje bod so SKUTOCNOU inferenciou; vo faze HLADANIA SMERU je spravnou
# natívnou operaciou zamok PRIAMKY pociatok -> kurzor, teda DVOJICA REALNYCH
# InputPointov (vzor Trimble LineTool). Syntetické body podla probe 5.9.
# nezamykaju, preto sa pociatok KOPIRUJE z realne pickovaneho bodu.
NxTest.test('GHOST-D2 Shift: vo faze SMERU zamyka PRIAMKU pociatok -> kurzor (dva REALNE body)') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  body = s[/def native_lock\(s, view\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'native_lock sa nasla')
  NxTest.assert(body.include?('s.draw_phase == :length'), 'dvojbodovy zamok patri faze SMERU')
  NxTest.assert(body.include?('view.lock_inference(@ip, @ip_origin)'), 'zamyka sa PRIAMKA')
  NxTest.assert(body.include?('view.lock_inference(@ip)'), 'inde jednobodovy zamok')
  cap = s[/def capture_origin_ip!.*?\n        end\n/m].to_s
  NxTest.assert(cap.include?('@ip_origin.copy!(@ip)'),
                'pociatok je KOPIA realne pickovaneho bodu, nie `InputPoint.new(pt)`')
  NxTest.refute(cap.include?('InputPoint.new(@'), 'ziadny synteticky bod zo suradnic')
  click = s[/def draw_click\(s, x, y, view\).*?\n          when :length, :width/m].to_s
  NxTest.assert(click.include?('capture_origin_ip!'), 'kopia vznikne pri kliku POCIATKU')
  deact = s[/def deactivate\(view\).*?\n        end\n/m].to_s
  NxTest.assert(deact.include?('@ip_origin = nil'), 'a s nastrojom zanikne')
end

# In-SU beh #299 (FAIL „GHOST suspend"): `Tool#deactivate` pride az PO
# `pop_tool` — a ked nastroj nie je vrchom stacku, pop sa ODLOZI. Zamok
# inferencie by dovtedy na view VISEL (vymena dokumentu s drzanym Shiftom).
NxTest.test('GHOST-D2 Shift: zamok pusti UZ `cancel_session`, nielen `deactivate`') do
  view = Class.new do
    attr_reader :unlocked

    def initialize
      @unlocked = false
    end

    # Bezargumentove volanie = ODOMKNUTIE (SketchUp API).
    def lock_inference(*args)
      @unlocked = args.empty?
      true
    end
  end.new
  model = Class.new do
    attr_reader :view

    def initialize(v)
      @view = v
    end

    def active_view
      @view
    end
  end.new(view)

  s = NxGD2.gt::PlacementSession.new(model: model, plan: NxGD2.plan, subject: :board,
                                     interaction: :drawing, memory: NxGD2.fresh_memory,
                                     orientation: 'leziaca')
  NxTest.assert(s.drawing?)
  NxTest.assert(NxGD2.gt.release_inference(s), 'uvolnenie prebehlo')
  NxTest.assert(view.unlocked, 'a bolo to BEZARGUMENTOVE `lock_inference` = odomknutie')
  # Cudzi zamok pouzivatela (session, ktora nikdy nezamykala) sa NEZHADZUJE.
  src = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  cancel = src[/def cancel_session\(reason = nil, deferred: true\).*?\n        end\n/m].to_s
  NxTest.assert(cancel.include?('release_inference(s) if s.respond_to?(:drawing?) && s.drawing?'),
                'odomyka sa LEN po kresleni (umiestnovanie nikdy nezamyka)')
  NxTest.assert(cancel.index('release_inference(s)') < cancel.index('end_tool'),
                'a este PRED (odlozenym) ukoncenim nastroja')
end

NxTest.test('GHOST-D2 Shift: `release_inference` nepadne na modeli bez view (headless)') do
  s = NxGD2.session
  NxTest.assert_equal(false, NxGD2.gt.release_inference(s), 'ziadne view = ziadne odomknutie, ziadna vynimka')
end

NxTest.test('GHOST-D2 Shift: Tool uvolnuje zamok vo VSETKYCH koncoch (lifecycle)') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  %w[deactivate onCancel suspend resume].each do |cb|
    body = s[/def #{cb}\(.*?\n        end\n/m].to_s
    NxTest.assert(body.include?('release_inference!'), "#{cb} uvolnuje zamok inferencie")
  end
  up = s[/def onKeyUp\(.*?\n        end\n/m].to_s
  NxTest.assert(up.include?('release_inference!'), 'pustenie Shiftu odomyka (hold-to-lock)')
end

# ---------------------------------------------------------------------------
# 10) KLAVESY — jedna hranica pri kliku pociatku
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 klavesy: ←/→ a ↑/↓ platia LEN vo faze 0') do
  s = NxGD2.session
  NxTest.assert(s.cycle_orientation!(1), 'pred klikom umiestnenie ide')
  s.rotate!(1)
  NxTest.assert_equal(1, s.rotation_index)
  s.begin_draw!([0.0, 0.0, 0.0])
  # Od kliku pociatku klavesy riadi Tool — session ich uz nedostane.
  body = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')[/def draw_key\(s, owned, _view\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'draw_key sa nasla')
  NxTest.assert(body.include?("unless s.draw_phase == :origin"), 'hranica je klik POCIATKU')
  NxTest.assert(body.include?('draw_locked_keys_status'), 'a povie preco')
  NxTest.assert(body.include?("return false if owned == :alt"), 'ALT v kresleni vyznam NEMA')
end

NxTest.test('GHOST-D2 klavesy: hlaska zamknutych klaves hovori CO robit') do
  msg = NxGD2.gt::DRAW_KEYS_LOCKED_MSG
  NxTest.assert(msg.include?('PRED') && msg.include?('počiatku'), msg)
end

NxTest.test('GHOST-D2 klavesy: Shift vlastnime LEN v kresleni (skrinka nezmenena)') do
  body = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')[/def owned_key\(key\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('drawing_session? && vk(:VK_SHIFT) == key'),
                'v umiestnovani si Shift spracuje SketchUp sam')
end

# ---------------------------------------------------------------------------
# 11) MERACIE POLE — `enableVCB?`, `onUserText`, `onReturn`
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 VCB: `enableVCB?` je ZMRAZENE uz pri vzniku nastroja (nie fazovo)') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  # SketchUp smie zavolat `enableVCB?` EST PRED `activate` — hodnota preto
  # vznika uz v `initialize`, inak by Measurements ostali vypnute nastalo.
  init = s[/def initialize\n          \@ip = nil.*?\n        end\n/m].to_s
  NxTest.assert(init.include?('@vcb = !s.nil? && s.respond_to?(:drawing?) && s.drawing?'),
                'hodnota vznikne uz pri vzniku nastroja')
  vcb = s[/def enableVCB\?.*?\n        end\n/m].to_s
  NxTest.assert(vcb.include?('@vcb ? true : false'), 'a uz sa nemeni')
  NxTest.refute(vcb.include?('draw_phase'), 'fazovo podmienene by nechalo Measurements vypnute')
end

NxTest.test('GHOST-D2 VCB: prazdny Enter ide cez `onReturn` (VK_RETURN v API NEEXISTUJE)') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  NxTest.assert(s.include?('def onReturn(view)'), 'prazdny Enter ma vlastny callback')
  # Konstanta `VK_RETURN` v SketchUp API NEEXISTUJE (probe 5.9.) — kod ju
  # nesmie CITAT. V komentari sa smie spominat, preto sa hlada volanie.
  NxTest.refute(s.include?('vk(:VK_RETURN)'), 'VK_RETURN sa v SketchUp API necita')
  NxTest.refute(s.include?('VK_RETURN =='), 'ani sa neporovnava s kodom klavesy')
  body = s[/def onReturn\(view\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('s.draw_card_value(dim)'), 'prevezme hodnotu KARTY pre TUTO fazu')
  NxTest.assert(body.include?('next if dim.nil?'), 'faza 0 Enter IGNORUJE')
  NxTest.assert(body.include?('card_taken_status'), 'a status to povie (vedoma akcia)')
end

# Codex #299 P2: cislo ma OBIST necitatelnu projekciu, nie na nej uviaznut.
NxTest.test('GHOST-D2 VCB: NAPISANE cislo urobi session umiestnitelnou aj po DEGENEROVANOM luci') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  # Degenerovany pohlad: `track_length` neurcil polohu -> session je
  # NEUMIESTNITELNA a klik by neprešiel.
  s.set_placeable!(false)
  NxTest.refute(s.placeable, 'vychodisko: poloha z tohto pohladu necitatelna')
  NxTest.assert(s.confirm_draw!(:length, 2400.0, sign: 1.0, typed: true), 'cislo sa prijalo')
  NxTest.assert_equal(:width, s.draw_phase, 'faza POKROCILA')
  NxTest.assert(s.placeable, 'a session je znova UMIESTNITELNA (cislo urcuje rozmer uplne)')
  s.set_placeable!(false)
  NxTest.assert(s.confirm_draw!(:width, 600.0, sign: 1.0, typed: true))
  NxTest.assert_equal(:done, s.draw_phase)
  NxTest.assert(s.placeable, 'commit prejde bez pohybu mysou')
  NxTest.assert(s.draw_ready? && !s.draw_matrix_vals.nil?, 'transformacia je plne urcena')
end

NxTest.test('GHOST-D2 VCB: potvrdenie MYSOU priznak umiestnitelnosti NEPREPISUJE') do
  s = NxGD2.session
  s.begin_draw!([0.0, 0.0, 0.0])
  s.preview_length!([1000.0, 0.0, 0.0])
  s.set_placeable!(false) # degenerovany luc tesne pred klikom
  NxTest.assert(s.confirm_draw!(:length, 1000.0), 'hodnota z NAHLADU sa prijala')
  NxTest.refute(s.placeable, 'ale klik ostava odmietnuty — poloha je stale necitatelna')
end

NxTest.test('GHOST-D2 VCB: obe VCB cesty posielaju `typed: true`') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  ut = s[/def onUserText\(text, view\).*?\n        end\n/m].to_s
  NxTest.assert(ut.include?('typed: true'), 'napisane cislo')
  ret = s[/def onReturn\(view\).*?\n        end\n/m].to_s
  NxTest.assert(ret.include?('typed: true'), 'prazdny Enter (hodnota karty)')
  click = s[/def draw_click\(s, x, y, view\).*?\n        end\n/m].to_s
  NxTest.refute(click.include?('typed: true'), 'klik mysou priznak NEPOSIELA')
end

# Codex #299 P2: bez stvrteho argumentu `pick` nedostane SketchUp referencny
# bod a neponukne relativne inferencie („on axis from point").
NxTest.test('GHOST-D2 inferencia: obe fazy podavaju REFERENCNY bod do `InputPoint#pick`') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  pick = s[/def pick_ip\(x, y, view, ref = nil\).*?\n        end\n/m].to_s
  NxTest.assert(!pick.empty?, 'pick_ip prijima referenciu')
  NxTest.assert(pick.include?('@ip.pick(view, x, y, ref)'), 'a podava ju ako 4. argument')
  NxTest.assert(pick.include?('!ref.equal?(@ip)'), 'nikdy nie sam seba')
  ref = s[/def draw_ref_ip\(s\).*?\n        end\n/m].to_s
  NxTest.assert(ref.include?('when :length then @ip_origin'), 'faza 1: referencia = POCIATOK')
  NxTest.assert(ref.include?('when :width  then @ip_length || @ip_origin'),
                'faza 2: koniec dlzky (ak vznikol klikom), inak pociatok')
  plane = s[/def draw_plane_point\(s, x, y, view, plane_z\).*?\n        end\n/m].to_s
  NxTest.assert(plane.include?('pick_ip(x, y, view, draw_ref_ip(s))'), 'faza 1 ju posiela')
  axis = s[/def draw_axis_point\(s, x, y, view, origin, axis\).*?\n        end\n/m].to_s
  NxTest.assert(axis.include?('pick_ip(x, y, view, draw_ref_ip(s))'), 'faza 2 tiez')
  # UMIESTNOVANIE (skrinka aj doska) referenciu NEDAVA — jeho spravanie sa nemeni.
  free = s[/def pick_free\(s, x, y, view\).*?\n        end\n/m].to_s
  NxTest.assert(free.include?('pick_ip(x, y, view)'), 'volny rezim ostal bez referencie')
  lock = s[/def pick_ip_locked\(s, x, y, view\).*?\n        end\n/m].to_s
  NxTest.assert(lock.include?('pick_ip(x, y, view)'), 'zamok vysky tiez')
end

NxTest.test('GHOST-D2 inferencia: referencne body su KOPIE realnych pickov, nie syntetické') do
  s = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')
  len = s[/def capture_length_ip!.*?\n        end\n/m].to_s
  NxTest.assert(len.include?('@ip_length.copy!(@ip)'), 'koniec dlzky je KOPIA pickovaneho bodu')
  click = s[/def draw_click\(s, x, y, view\).*?\n        end\n/m].to_s
  NxTest.assert(click.include?("capture_length_ip! if dim == :length"),
                'a vznika LEN pri potvrdeni dlzky KLIKOM')
  deact = s[/def deactivate\(view\).*?\n        end\n/m].to_s
  NxTest.assert(deact.include?('@ip_length = nil'), 's nastrojom zanika')
end

NxTest.test('GHOST-D2 VCB: hodnota karty pre fazu je z ZMRAZENEHO planu') do
  s = NxGD2.session(NxGD2.cfg(length: 1234.56, width: 789.01))
  NxTest.assert_equal(1234.56, s.draw_card_value(:length))
  NxTest.assert_equal(789.01, s.draw_card_value(:width))
end

NxTest.test('GHOST-D2 VCB: `onUserText` odmietne neplatny text aj hodnotu mimo limitu') do
  body = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')[/def onUserText\(text, view\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('Calc.parse_mm(text)'), 'vlastny parser')
  NxTest.assert(body.include?('Calc.dim_ok?(dim, mm)'), 'limit PRED posunom fazy')
  NxTest.assert(body.include?('draw_status_beep'), 'UI.beep + status (vzor 99_sphere_tool)')
  NxTest.assert(body.include?('next if dim.nil?'), 'faza 0 pisane cislo IGNORUJE')
  NxTest.assert(body.include?('sign: 1.0'), 'napisane cislo je vzdy kladny smer')
end

NxTest.test('GHOST-D2 VCB: label fazy je „Dĺžka (mm)" / „Šírka (mm)"') do
  NxTest.assert_equal('Dĺžka', NxGD2.calc.dim_label(:length))
  NxTest.assert_equal('Šírka', NxGD2.calc.dim_label(:width))
  body = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')[/def refresh_vcb.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('Sketchup.vcb_label = "#{Calc.dim_label(dim)} (mm)"'), body)
end

# ---------------------------------------------------------------------------
# 12) `BoardBuilder.replan` — odvodeny ZMRAZENY plan
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 replan: novy plan je ZMRAZENY a nesie NOVE rozmery') do
  p1 = NxGD2.plan
  p2 = NxGD2.bb.replan(p1, length: 2400.0, width: 600.0)
  NxTest.assert(p2.is_a?(NxGD2.bb::BoardPlan) && !p2.equal?(p1), 'vznikol NOVY plan')
  NxTest.assert(p2.config.frozen? && p2.stored_config.frozen?, 'a je zmrazeny')
  NxTest.assert_equal([2400.0, 600.0], [p2.config[:length], p2.config[:width]])
  NxTest.assert_equal([2400.0, 600.0], [p2.stored_config[:length], p2.stored_config[:width]])
  NxTest.assert_equal([800.0, 600.0], [p1.config[:length], p1.config[:width]], 'povodny plan sa NEZMENIL')
end

NxTest.test('GHOST-D2 replan: vyrobny snapshot ostava — katalog sa uz NECITA') do
  sheets = { 'MAT_D2' => NxGD2.sheet('MAT_D2', 18.0) }
  p1 = nil
  NxGD2.with_catalog(sheets) { p1 = NxGD2.plan(NxGD2.cfg) }
  before = p1.stored_config.dup
  # Katalog sa medzi pripravou a klikom ZMENIL — nakreslena doska musi
  # dostat POVODNY material a povodnu hrubku.
  p2 = NxGD2.with_catalog('MAT_D2' => NxGD2.sheet('MAT_D2', 36.0, 'decor' => 'INY')) do
    NxGD2.bb.replan(p1, length: 2400.0, width: 600.0)
  end
  NxTest.assert_equal(before[:material_id], p2.stored_config[:material_id])
  NxTest.assert_equal(before[:thickness], p2.stored_config[:thickness], 'hrubka zo SNAPSHOTU')
  NxTest.assert_equal(before[:edges], p2.stored_config[:edges])
  NxTest.assert_equal(before[:grain_direction], p2.stored_config[:grain_direction])
  NxTest.assert_equal(before[:config_schema], p2.stored_config[:config_schema], 'marker prezil')
end

NxTest.test('GHOST-D2 replan: AUTOMATICKY nazov sa prepocita z NOVYCH rozmerov') do
  auto = NxGD2.plan(NxGD2.cfg(name: 'Doska 800×600'), nil, Object.new, nil, true)
  p2 = NxGD2.bb.replan(auto, length: 2400.0, width: 600.0)
  NxTest.assert_equal('Doska 2400×600', p2.config[:name])
  NxTest.assert_equal('Doska 2400×600', p2.stored_config[:name], 'aj v zapisovom tvare')
end

NxTest.test('GHOST-D2 replan: EXPLICITNY nazov ostava (pouzivatel ho napisal)') do
  expl = NxGD2.plan(NxGD2.cfg(name: 'Pracovná doska kuchyňa'), nil, Object.new, nil, false)
  p2 = NxGD2.bb.replan(expl, length: 2400.0, width: 600.0)
  NxTest.assert_equal('Pracovná doska kuchyňa', p2.config[:name])
  NxTest.assert_equal('Pracovná doska kuchyňa', p2.stored_config[:name])
end

NxTest.test('GHOST-D2 replan: `prepare_insert` rozlisi explicitny a automaticky nazov') do
  sheets = { 'MAT_D2' => NxGD2.sheet('MAT_D2', 18.0) }
  NxGD2.with_catalog(sheets) do
    model = Object.new
    # POZOR (Ruby 3): `prepare_insert` ma keyword `template_ref:`, takze holy
    # hash bez zatvoriek by sa poslal ako KEYWORDS — params ide v `{}`.
    auto = NxGD2.bb.prepare_insert(model, { 'material_id' => 'MAT_D2', 'length' => 800, 'width' => 600 })
    NxTest.assert(auto.auto_name?, 'bez nazvu = automaticky')
    NxTest.assert_equal('Doska 800×600', auto.config[:name])
    expl = NxGD2.bb.prepare_insert(model, { 'material_id' => 'MAT_D2', 'name' => 'Blenda' })
    NxTest.refute(expl.auto_name?, 'napisany nazov = explicitny')
    blank = NxGD2.bb.prepare_insert(model, { 'material_id' => 'MAT_D2', 'name' => '   ' })
    NxTest.assert(blank.auto_name?, 'same medzery su PRAZDNY nazov')
  end
end

NxTest.test('GHOST-D2 replan: rozmery sa OREZU na LIMITY a zaokruhlia na 0,01 mm') do
  p2 = NxGD2.bb.replan(NxGD2.plan, length: 6000.0, width: 600.126)
  NxTest.assert_equal(5000.0, p2.config[:length], 'nad limit sa nikdy nedostane do modelu')
  NxTest.assert_equal(600.13, p2.config[:width])
  NxTest.assert_equal(600.13, p2.stored_config[:width], 'nahlad = config = geometria')
end

NxTest.test('GHOST-D2 replan: identita dokumentu, orientacia a sablona prezivaju') do
  model = Object.new
  ref = { 'kind' => 'board', 'name' => 'Zástena' }
  p1 = NxGD2.plan(NxGD2.cfg(orientation: 'stojaca'), 'stojaca', model, ref)
  p2 = NxGD2.bb.replan(p1, length: 600.0, width: 2200.0)
  NxTest.assert(p2.for_model?(model), 'plan patri TOMU ISTEMU dokumentu')
  NxTest.refute(p2.for_model?(Object.new), 'a cudziemu nie')
  NxTest.assert_equal('stojaca', p2.orientation)
  NxTest.assert_equal(ref, p2.template_ref, 'peciatka sablony sa nesie dalej')
end

NxTest.test('GHOST-D2 replan: cudzi objekt (nie BoardPlan) sa ODMIETNE') do
  NxTest.assert_raise(/pripravená doska/i) { NxGD2.bb.replan({ length: 1 }, length: 100.0, width: 100.0) }
end

NxTest.test('GHOST-D2 commit: kreslenie berie ODVODENY plan, umiestnovanie ZMRAZENY') do
  body = NxGD2.src('noxun_engine', 'core', 'ghost_tool.rb')[/def commit_plan.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('return @plan unless drawing? && draw_ready?'), body)
  NxTest.assert(body.include?('BoardBuilder.replan(@plan, length: @draw_length_mm, width: @draw_width_mm)'), body)
end

# ---------------------------------------------------------------------------
# 13) CALLBACK `draw_board` — poradie guardov (R-02)
# ---------------------------------------------------------------------------

NxTest.test('GHOST-D2 callback: `draw_board` je SAMOSTATNY a serverom whitelistovany') do
  panel = NxGD2.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.assert(panel.include?("cb(dlg, 'draw_board')"), 'kreslenie ma vlastny callback')
  NxTest.assert(panel.include?("cb(dlg, 'insert_board')"), 'vkladanie (D1) ostava')
end

NxTest.test('GHOST-D2 callback: poradie doc guard -> sablona -> zamky -> prepare -> session') do
  body = NxGD2.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')[
    /def handle_draw_board\(payload\).*?\n        end\n/m
  ].to_s
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  i_doc = body.index('foreign_document?')
  i_tpl = body.index('take_template_ref!')
  i_lock = body.index('draw_locks')
  i_prep = body.index('BoardBuilder.prepare_insert')
  i_sess = body.index('GhostTool.start')
  NxTest.assert(!i_doc.nil? && i_doc < i_tpl, 'identita DOKUMENTU je UPLNE PRVA (R-02)')
  NxTest.assert(i_tpl < i_lock && i_lock < i_prep && i_prep < i_sess, 'poradie je kontrakt')
  NxTest.assert(body.include?('interaction: :drawing'), 'session je kreslenie')
  NxTest.assert(body.include?('locks: locks'), 'a nesie zvalidovane zamky')
end

NxTest.test('GHOST-D2 callback: neplatny zamok session NESPUSTI') do
  body = NxGD2.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')[
    /def handle_draw_board\(payload\).*?\n        end\n/m
  ].to_s
  NxTest.assert(body.include?('return set_status(lock_err, true) if lock_err'), body)
  NxTest.assert(body.index('lock_err') < body.index('BoardBuilder.prepare_insert'),
                'odmietnutie pride PRED pripravou planu')
end

NxTest.test('GHOST-D2 callback: whitelist parametrov karty je JEDEN pre vklad aj kreslenie') do
  src = NxGD2.src('noxun_engine', 'ui', 'panel', 'actions_board.rb')
  NxTest.assert(src.include?('BOARD_INSERT_PARAM_KEYS'), 'whitelist je pomenovana konstanta')
  # Obe vkladacie cesty citaju TEN ISTY whitelist — inak by sa rozisli.
  NxTest.assert_equal(2, src.scan('params = board_insert_params(data)').length,
                      'vklad (D1) aj kreslenie (D2) idu cez jeden whitelist')
  # `actions_board.rb` sa v headless behu nenacitava (Panel je SketchUp
  # vrstva), preto sa whitelist cita zo ZDROJA — podstatne je, ze `locks`
  # v nom NIE SU: do `normalize` sa zamky nesmu dostat NIKDY.
  keys = src[/BOARD_INSERT_PARAM_KEYS = %w\[(.*?)\]/m].to_s
  NxTest.assert(!keys.empty?, 'whitelist sa nasiel')
  NxTest.refute(keys.include?('locks'), 'zamky sa do `normalize` NIKDY nedostanu')
  NxTest.assert(keys.include?('orientation') && keys.include?('material_id'), keys)
end
