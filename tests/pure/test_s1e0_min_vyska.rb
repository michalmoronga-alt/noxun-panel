# frozen_string_literal: true
# S1-E0 — MINIMALNA VYSKA KORPUSU 80 mm (korpus na dorovnanie nad umyvackou).
#
# Michalovo hlasenie (20.9.2026, debata S1): „nad umyvackou ostava po liniu
# linky casto len 80-110 mm; vyplnam to nizkym korpusom na dorovnanie (napr.
# 90 mm) — plugin ma pod 200 nepusti."
#
# PRECO GUARD TEST A NIE KLIKANIE:
#   1) JEDNA HODNOTA, TRI MIESTA. Spodnu hranicu vysky drzia tri nezavisle
#      zapisy: `CabinetBuilder::MIN` (normalize = autorita configu),
#      `ScaleWatch::MIN` (absorpcia scale ulohou nastroja Mierka) a
#      `LIMITS.height` v `ui/js/form.js` (cervene pole v Inspectore).
#      Priamu referenciu neumoznuje ani jedna dvojica: `scale_observer` sa
#      nacitava PRED `cabinet_builder` (main.rb) a JS Ruby konstantu nevidi.
#      Ked sa cisla rozidu, vznikne PASMO, v ktorom panel hodnotu pusti a
#      builder ju ticho klampne (alebo naopak) — presne ten druh rozdielu,
#      ktory sa v modeli objavi az ako zly rozmer vo vyrobe.
#   2) SIRKA A HLBKA SA NEMENIA. Test ich fixuje spolu s vyskou, aby sa
#      „odomknutie" pri buducej uprave nerozlialo na rozmery, ktore
#      konstrukcny zmysel nemaju.
require_relative '../helper' unless defined?(NxTest)

# Headless: `ui/*.rb` nie su v require zozname helpera (UI vrstva) — sablonovy
# whitelist `Panel.template_config_from` si ich sada dotiahne sama, aby
# nezavisela od poradia suborov v behu (vzor `test_r12_config_schema.rb`).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates')
end

module NxS1E0
  module_function

  def cb
    Noxun::Engine::CabinetBuilder
  end

  def src(*rel)
    File.read(File.join(NxTest::ROOT, *rel), encoding: 'UTF-8')
  end

  def form_js
    @form_js ||= src('noxun_engine', 'ui', 'js', 'form.js')
  end

  # Spodne hranice z `scale_observer.rb` sa citaju zo ZDROJA, nie z konstanty:
  # `core/scale_observer.rb` sa v `tests/helper.rb` NENACITAVA (potrebuje zive
  # SketchUp API) a kvoli jednej konstante nema zmysel stavat stuby. Rovnaky
  # vzor ako `test_kova2b_smer_overlay.rb`, ktory ten isty subor cita textovo.
  def observer_min
    line = src('noxun_engine', 'core', 'scale_observer.rb')[/^\s*MIN\s*=\s*\{(.*?)\}\.freeze/, 1].to_s
    NxTest.assert(!line.empty?, 'v scale_observer.rb sa nenasla konstanta MIN')
    line.scan(/'(\w+)'\s*=>\s*(-?[\d.]+)/).to_h { |key, value| [key, value.to_f] }
  end

  # Vytiahne z `form.js` dvojicu [min, max] pre pole `id` zo zoznamu LIMITS.
  # Zamerne cita SUROVY text (nie JS runtime) — guard ma padnut aj vtedy, ked
  # by niekto cislo prepisal a JS sada sa nespustila.
  def cn
    Noxun::Engine::Construction
  end

  # Nizky korpus na dorovnanie: dolny 600 x 90 x 560 BEZ sokla (stoji na
  # umyvacke, nie na zemi) — presne to, co Michal kladie pod liniu linky.
  def low_lower(over = {})
    cb.normalize({ 'type' => 'lower', 'width' => 600.0, 'height' => 90.0, 'depth' => 560.0,
                   'thickness' => 18.0, 'floor_height' => 0.0 }.merge(over))
  end

  def low_upper(over = {})
    cb.normalize({ 'type' => 'upper', 'width' => 600.0, 'height' => 80.0, 'depth' => 320.0,
                   'thickness' => 18.0 }.merge(over))
  end

  # Vrati [min_box_zlozka, kluce dielcov] — plan uz presiel `BuildPlan.validate!`
  # (vola ho `build_plan` na konci), takze staci pozriet na cisla.
  def plan_dims(plan)
    plan[:parts].flat_map { |pd| Array(pd[:box]).map(&:to_f) }
  end

  # Config tak, ako ho zapise JEDINY zapisovy bod (`cabinet_config`) — teda
  # vratane markera `config_schema`. Cez JSON round-trip, presne ako to prezije
  # cesta do modelu (vzor `NxR12.stored_config`).
  def stored(cfg)
    JSON.parse(cb.cabinet_config(cfg).to_json)
  end

  def js_limit(id)
    block = form_js[/var\s+LIMITS\s*=\s*\{(.*?)\};/m, 1].to_s
    NxTest.assert(!block.empty?, 'v form.js sa nenasiel zoznam LIMITS')
    m = block.match(/\b#{id}\s*:\s*\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]/)
    NxTest.assert(m, "v LIMITS chyba pole #{id}")
    [m[1].to_f, m[2].to_f]
  end
end

# ---------------------------------------------------------------------------
# 1) Parita troch miest (R1)
# ---------------------------------------------------------------------------

NxTest.test('S1-E0 R1: builder MIN ma vysku 80, sirku 200 a hlbku 150') do
  NxTest.assert_close(80.0, NxS1E0.cb::MIN[:height])
  NxTest.assert_close(200.0, NxS1E0.cb::MIN[:width])
  NxTest.assert_close(150.0, NxS1E0.cb::MIN[:depth])
end

NxTest.test('S1-E0 R1: ScaleWatch MIN je ZRKADLOM builder MIN (string kluce)') do
  NxTest.assert_equal(NxS1E0.cb::MIN.transform_keys(&:to_s), NxS1E0.observer_min,
                      'absorpcia scale klampuje na ine cislo nez normalize — ' \
                      'tahanie uchopom a Inspector by dali iny rozmer')
end

NxTest.test('S1-E0 R1: LIMITS vo form.js sedia s Ruby MIN (dolna hranica)') do
  { width: 200.0, height: 80.0, depth: 150.0 }.each do |id, expected|
    lo, = NxS1E0.js_limit(id)
    NxTest.assert_close(expected, lo, 0.01,
                        "form.js LIMITS.#{id} dolna hranica #{lo} != Ruby MIN #{expected}")
    NxTest.assert_close(NxS1E0.cb::MIN[id], lo, 0.01, "form.js LIMITS.#{id} vs CabinetBuilder::MIN")
  end
end

NxTest.test('S1-E0 R1: LIMITS vo form.js sedia s clampom normalize (horna hranica)') do
  # Horne hranice ziju v `normalize` ako literaly (3000/3000/2000) — panel ich
  # musi mat rovnake, inak by pole pustilo hodnotu, ktoru builder oreze.
  { width: 3000.0, height: 3000.0, depth: 2000.0 }.each do |id, expected|
    _, hi = NxS1E0.js_limit(id)
    NxTest.assert_close(expected, hi, 0.01, "form.js LIMITS.#{id} horna hranica")
    clamped = NxS1E0.cb.normalize(id.to_s => (expected + 500))[id]
    NxTest.assert_close(expected, clamped, 0.01, "normalize klampuje #{id} na #{expected}")
  end
end

# ---------------------------------------------------------------------------
# 2) normalize — klampovanie vysky (R2: kontrakt configu sa NEMENI)
# ---------------------------------------------------------------------------

NxTest.test('S1-E0: normalize klampuje vysku na 80 a 90 prijme') do
  cb = NxS1E0.cb
  NxTest.assert_close(80.0, cb.normalize('height' => 50)[:height], 0.01, 'vyska 50 -> 80')
  NxTest.assert_close(80.0, cb.normalize('height' => 79.9)[:height], 0.01, 'vyska tesne pod hranicou -> 80')
  NxTest.assert_close(80.0, cb.normalize('height' => 80)[:height], 0.01, 'hranicna hodnota prejde nedotknuta')
  NxTest.assert_close(90.0, cb.normalize('height' => 90)[:height], 0.01, 'korpus na dorovnanie 90 mm prejde')
  NxTest.assert_close(90.0, cb.normalize('type' => 'upper', 'height' => 90)[:height], 0.01,
                      'to iste plati pre hornu skrinku')
end

NxTest.test('S1-E0 R1: sirka a hlbka sa NEODOMKLI (200 / 150)') do
  cfg = NxS1E0.cb.normalize('width' => 100, 'depth' => 100, 'height' => 90)
  NxTest.assert_close(200.0, cfg[:width], 0.01, 'sirka dalej klampuje na 200')
  NxTest.assert_close(150.0, cfg[:depth], 0.01, 'hlbka dalej klampuje na 150')
end

NxTest.test('S1-E0: nizky korpus NEPRIDAVA ziadne pole do configu') do
  # Zmenil sa PRIPUSTNY ROZSAH hodnoty, nie tvar configu — ziadna migracia,
  # ziadny novy whitelist. Bump schemy (nizsie) je tu kvoli TICHEJ ZMENE
  # VYROBY u starsieho pluginu, nie kvoli novemu poľu.
  NxTest.assert_equal(NxS1E0.cb.normalize('height' => 900).keys.sort,
                      NxS1E0.cb.normalize('height' => 90).keys.sort,
                      'nizky korpus ma PRESNE tie iste kluce ako bezny')
end

NxTest.test('S1-E0 (Codex #374 P1): CONFIG_SCHEMA je 15 a nizka skrinka ho nesie') do
  # PRECO BUMP, ked nepribudlo pole: starsi plugin (schema 14) ma MIN[:height]
  # = 200, takze by skrinku 80-199 mm pri prvej prestavbe KLAMPOL na 200 —
  # zmenil by vysku bokov, chrbta aj ciel a nikto by to nezbadal, kym by
  # dielce neprisli z pily. Disciplina bumpu (STANDARD 2.5) hovori o TICHEJ
  # ZMENE VYROBY, nie o novom poli.
  NxTest.assert_equal(15, NxS1E0.cb::CONFIG_SCHEMA, 'schema configu je po S1-E0 pätnastka')
  stored = NxS1E0.stored(NxS1E0.low_lower)
  NxTest.assert_equal(15, stored['config_schema'], 'ulozeny config nizkej skrinky nesie marker 15')
  NxTest.assert_close(90.0, stored['height'], 0.01, 'a nizku vysku')
end

NxTest.test('S1-E0 (Codex #374 P1): starsi plugin (schema 14) nizku skrinku PRESTAVAT ODMIETNE') do
  # Simulacia starsieho pluginu: jeho `newer_config?` je presne toto porovnanie
  # proti VLASTNEJ (nizsej) konstante. Bez bumpu by 14 >= 15 neplatilo, guard
  # by mlcal a klamp na 200 by prebehol ticho.
  stored = NxS1E0.stored(NxS1E0.low_lower)
  NxTest.assert(NxS1E0.cb.config_schema_of(stored) > 14,
                'skrinka postavena touto verziou je pre schemu 14 NOVSIA — prestavba sa odmietne')
  # A TATO verzia svoj vlastny config odmietat nesmie.
  NxTest.refute(NxS1E0.cb.newer_config?(stored), 'vlastny config prechadza bez blokady')
  NxTest.assert(NxS1E0.cb.newer_config?(stored.merge('config_schema' => 16)),
                'config z novsej verzie sa dalej blokuje')
end

NxTest.test('S1-E0 (Codex #374 P1): sablona nizkej skrinky nesie marker 15') do
  # Sablona je STRATOVA cesta BEZ rebuildu — keby marker nenesla, starsi plugin
  # by z nej postavil skrinku klampnutu na 200 a bez jedineho varovania.
  tc = Noxun::Engine::Panel.template_config_from(NxS1E0.stored(NxS1E0.low_lower))
  NxTest.assert_equal(15, tc['config_schema'], 'sablonovy whitelist stampuje aktualny marker')
end

NxTest.test('S1-E0: HISTORIA bumpu ma zapisany dovod cisla 15 (disciplina STANDARD 2.5)') do
  hist = NxS1E0.src('noxun_engine', 'core', 'cabinet_builder.rb')[/HISTORIA:.*?CONFIG_SCHEMA = /m].to_s
  NxTest.assert(hist.include?('15 = S1-E0'), 'cislo 15 ma v komentari svoj dovod')
  NxTest.assert(hist.include?('newer_config?'), 'a menuje dopredu branu, ktora k bumpu patri')
end

NxTest.test('S1-E0: aktivacne schemy zasuviek, zavesov a vyklopov bump NEPRESUNUL') do
  # Bump na 15 nesmie spravit zo skriniek schemy 14 „nemigrovane" — rovnaky
  # dovod, pre ktory maju tieto tri konstanty vlastny zivot.
  NxTest.assert_equal(5, NxS1E0.cb::DRAWER_ACTIVATION_SCHEMA)
  NxTest.assert_equal(9, NxS1E0.cb::HINGE_ACTIVATION_SCHEMA)
  NxTest.assert_equal(11, NxS1E0.cb::LIFT_ACTIVATION_SCHEMA)
end

# ---------------------------------------------------------------------------
# 3) Geometria nizkeho korpusu (R3) — plan bez zapornych dielcov
# ---------------------------------------------------------------------------

NxTest.test('S1-E0 R3: dolny 600 x 90 x 560 bez sokla da plan bez zapornych dielcov') do
  plan = NxS1E0.cn.build_plan(NxS1E0.low_lower, 'CAB-S1E0-1')
  keys = plan[:parts].map { |pd| pd[:part_key].to_s }
  %w[cabinet/side:left cabinet/side:right cabinet/bottom cabinet/top cabinet/back].each do |k|
    NxTest.assert(keys.include?(k), "nizky korpus ma dielec #{k}")
  end
  NxTest.assert(NxS1E0.plan_dims(plan).all?(&:positive?), 'ziadny dielec nema nekladny rozmer')
  NxTest.refute(plan[:warnings].any? { |w| w['code'] == 'part_skipped_degenerate' },
                'ziadny dielec sa nepreskakuje ako degenerovany')
  NxTest.assert_close(54.0, plan[:available][:height], 0.01, 'svetla vyska 90 - 18 - 18 = 54')
end

NxTest.test('S1-E0 R3: horny 600 x 80 x 320 da plan bez zapornych dielcov') do
  plan = NxS1E0.cn.build_plan(NxS1E0.low_upper, 'CAB-S1E0-2')
  NxTest.assert(NxS1E0.plan_dims(plan).all?(&:positive?), 'ziadny dielec nema nekladny rozmer')
  NxTest.assert_close(44.0, plan[:available][:height], 0.01, 'svetla vyska 80 - 18 - 18 = 44')
  NxTest.assert_close(0.0, NxS1E0.low_upper[:floor_height], 0.01, 'horna skrinka sokel nema')
end

NxTest.test('S1-E0 R3: vsetky konstrukcne predvolby vrchu/dna/chrbta drzia kladne rozmery') do
  # Kombinacie, ktore v nizkom korpuse realne hrozia (dno pod bokmi x chrbat
  # v drazke x vrch bez dosky). Ziadna z nich nesmie vyrobit zaporny dielec.
  %w[under_sides between_sides].each do |bottom|
    %w[full none].each do |top|
      %w[overlay inset groove none].each do |back|
        cfg = NxS1E0.low_lower('bottom_mode' => bottom, 'top_mode' => top, 'back_mode' => back)
        plan = NxS1E0.cn.build_plan(cfg, 'CAB-S1E0-3')
        NxTest.assert(NxS1E0.plan_dims(plan).all?(&:positive?),
                      "#{bottom}/#{top}/#{back}: vsetky rozmery kladne")
      end
    end
  end
end

NxTest.test('S1-E0 R3: sokel VYSSI nez korpus sa odmietne zrozumitelnou hlaskou') do
  # Vyska je CELKOVA vratane sokla (semantika sa NEMENI): dolna skrinka 90 mm
  # s predvolenym soklom 100 mm ziadne vnutro nema. Builder to odmietne a panel
  # to ukaze cervenym polom UZ PRED apply (`form.js` cabinetHeightError).
  NxTest.assert_raise(/sokel|Vnutorna vyska/i) do
    NxS1E0.cn.build_plan(NxS1E0.low_lower('floor_height' => 100.0), 'CAB-S1E0-4')
  end
end

NxTest.test('S1-E0 R4: police v nizkom korpuse sa ODMIETNU s hlaskou, nikdy tichym nezmyslom') do
  # Dnesne spravanie (ZoneTree.validate_shelves!) sa touto davkou NEMENI —
  # zona 54 mm potrebuje na jednu policu 18 + 2 x 20 = 58 mm. Charakterizacia:
  # ked sa to niekedy zmeni na warning, nech to test povie nahlas.
  NxTest.assert_raise(/prilis nizka na 1 polic/) do
    NxS1E0.cn.build_plan(
      NxS1E0.low_lower('zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] }),
      'CAB-S1E0-5'
    )
  end
end

NxTest.test('S1-E0 R4: nizky korpus BEZ polic (default) prejde a zona je jedna') do
  plan = NxS1E0.cn.build_plan(NxS1E0.low_lower, 'CAB-S1E0-6')
  NxTest.assert_equal(0, NxS1E0.low_lower[:zone_tree]['shelves'], 'default je 0 polic')
  NxTest.assert_equal(1, Array(plan[:zones]).length, 'vnutro je jedna zona')
end

NxTest.test('S1-E0 R3: dve vystuhy v nizkom korpuse su odmietnute (D-80 rezerva)') do
  NxTest.assert_raise(/nizke na vystuhy|nízke na výstuhy/i) do
    NxS1E0.cn.build_plan(
      NxS1E0.low_lower('height' => 80.0, 'floor_height' => 25.0, 'top_mode' => 'two_rails'),
      'CAB-S1E0-7'
    )
  end
end
