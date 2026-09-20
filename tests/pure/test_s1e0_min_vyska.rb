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

  # Postavil by sa tento config pri danej vyske? Pytame sa TOU ISTOU cestou,
  # ktorou ide rebuild — cely `build_plan` (validate! + zony + police + cela +
  # kontrakt planu), nie len jeden z jeho krokov.
  def buildable?(cfg, height)
    cn.build_plan(cfg.merge(height: height), 'CAB-TEST')
    true
  rescue StandardError
    false
  end

  # Zony s policami pre konfiguraciu, ktora padala az na `validate_shelves!`.
  def with_shelves(count)
    { 'zone_tree' => { 'id' => 'Z1', 'shelves' => count, 'children' => [] } }
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

NxTest.test('S1-E0 (Codex #374 P1): CONFIG_SCHEMA je aspon 15 a nizka skrinka nesie aktualny marker') do
  # PRECO BUMP, ked nepribudlo pole: starsi plugin (schema 14) ma MIN[:height]
  # = 200, takze by skrinku 80-199 mm pri prvej prestavbe KLAMPOL na 200 —
  # zmenil by vysku bokov, chrbta aj ciel a nikto by to nezbadal, kym by
  # dielce neprisli z pily. Disciplina bumpu (STANDARD 2.5) hovori o TICHEJ
  # ZMENE VYROBY, nie o novom poli.
  # S1-E: cislo uz nie je pripnute na 15 (dalsie davky bumpuju dalej) —
  # kontroluje sa, ze S1-E0 bump NEZMIZOL a ze sa marker naozaj zapisuje.
  NxTest.assert(NxS1E0.cb::CONFIG_SCHEMA >= 15, 'schema configu je po S1-E0 aspon pätnastka')
  stored = NxS1E0.stored(NxS1E0.low_lower)
  NxTest.assert_equal(NxS1E0.cb::CONFIG_SCHEMA, stored['config_schema'],
                      'ulozeny config nizkej skrinky nesie AKTUALNY marker')
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
  NxTest.assert(NxS1E0.cb.newer_config?(stored.merge('config_schema' => NxS1E0.cb::CONFIG_SCHEMA + 1)),
                'config z novsej verzie sa dalej blokuje')
end

NxTest.test('S1-E0 (Codex #374 P1): sablona nizkej skrinky nesie AKTUALNY marker') do
  # Sablona je STRATOVA cesta BEZ rebuildu — keby marker nenesla, starsi plugin
  # by z nej postavil skrinku klampnutu na 200 a bez jedineho varovania.
  tc = Noxun::Engine::Panel.template_config_from(NxS1E0.stored(NxS1E0.low_lower))
  NxTest.assert_equal(NxS1E0.cb::CONFIG_SCHEMA, tc['config_schema'],
                      'sablonovy whitelist stampuje aktualny marker')
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

# ---------------------------------------------------------------------------
# 3b) Config-aware spodna hranica pre absorpciu scale (Codex #375 P2)
# ---------------------------------------------------------------------------

NxTest.test('S1-E0 (Codex #375 P2): min_valid_height je NAJNIZSIA vyska, pri ktorej by PRESTAVBA PRESLA') do
  # Sila testu je v druhej polovici: o milimeter nizsie uz musi byt odmietnutie.
  # Inak by funkcia mohla vracat hocijake „dost velke" cislo a tvarit sa spravne.
  # Kolo 2 (Codex #375): sondou je CELY `build_plan`, nie len `validate!` —
  # preto su v matici aj police a cela, ktore padaju AZ ZA validaciou obalky.
  [
    { 'floor_height' => 100.0 },                                    # dolna so soklom
    { 'floor_height' => 0.0 },                                      # korpus na dorovnanie
    { 'floor_height' => 150.0, 'thickness' => 25.0 },               # hruby material
    { 'floor_height' => 500.0 },                                    # maximalny sokel
    { 'floor_height' => 100.0, 'top_mode' => 'none' },              # bez vrchu
    { 'floor_height' => 100.0, 'top_mode' => 'two_rails' },         # dve vystuhy naplocho
    { 'floor_height' => 0.0, 'top_mode' => 'two_rails',
      'rails_orientation' => 'upright', 'rail_depth' => 100.0 },    # vystuhy na hranu
    { 'floor_height' => 100.0, 'top_mode' => 'two_rails',
      'rails_orientation' => 'upright', 'rail_depth' => 400.0,
      'rails_top_offset' => 200.0 },                                # extremne vystuhy
    { 'floor_height' => 0.0 }.merge(NxS1E0.with_shelves(1)),        # JEDNA polica
    { 'floor_height' => 100.0 }.merge(NxS1E0.with_shelves(2)),      # dve police + sokel
    { 'floor_height' => 0.0 }.merge(NxS1E0.with_shelves(4))         # styri police
  ].each do |over|
    cfg = NxS1E0.low_lower(over)
    h = NxS1E0.cn.min_valid_height(cfg)
    NxTest.assert(NxS1E0.buildable?(cfg, h), "#{over.inspect}: vyska #{h} sa musi dat postavit")
    NxTest.refute(NxS1E0.buildable?(cfg, h - 1.0),
                  "#{over.inspect}: vyska #{h - 1} uz prejst NESMIE (inak to nie je minimum)")
    NxTest.assert_equal(h, h.round.to_f, "#{over.inspect}: vysledok je cely milimeter")
  end
end

NxTest.test('S1-E0 (Codex #375 kolo 2 P2): JEDNA polica dvihne minimum z 80 na 94') do
  # Nalez kola 2: skrinka s policou klampla na 80 (vnutro 44), `validate!`
  # to prepustil a padlo to az na `ZoneTree.validate_shelves!` — absorpcia
  # skoncila rejectom a pouzivatel dostal spat povodnych 720 mm.
  # Polica potrebuje 18 (dielec) + 2 x 20 (dve pole) = 58 mm svetla,
  # takze 58 + dno 18 + strop 18 = 94.
  cfg = NxS1E0.low_lower({ 'floor_height' => 0.0 }.merge(NxS1E0.with_shelves(1)))
  NxTest.assert_close(94.0, NxS1E0.cn.min_valid_height(cfg), 0.01)
  NxTest.refute(NxS1E0.buildable?(cfg, 80.0), 'na 80 mm by prestavba padla na policu')
  NxTest.assert(NxS1E0.buildable?(cfg, 94.0), 'na 94 mm uz skrinka stoji')
  # A `validate!` SAM by 80 mm prepustil — presne to bola diera.
  c80 = cfg.merge(height: 80.0)
  NxTest.assert(NxS1E0.cn.interior_dims(c80)[:avail_h] > NxS1E0.cn::MIN_AVAIL_H,
                'obalka je v poriadku — chyba je az v zonach, preto sonda musi byt cely plan')
end

NxTest.test('S1-E0 (Codex #375 kolo 2 P2): minimum rata aj s CELAMI (profil uchytky)') do
  # Cela padaju vo `Fronts.layout` (profil zabera z panela), teda tiez AZ ZA
  # `validate!`. Pevne celo 300 mm sa do 80 mm skrinky nezmesti.
  cfg = NxS1E0.low_lower('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door',
                                                     'height' => 300.0, 'wings' => '1' }] })
  h = NxS1E0.cn.min_valid_height(cfg)
  NxTest.assert(NxS1E0.buildable?(cfg, h), "vyska #{h} sa musi dat postavit aj s celom")
  NxTest.refute(NxS1E0.buildable?(cfg, h - 1.0), "vyska #{h - 1} uz nie")
end

NxTest.test('S1-E0 (Codex #375 kolo 2 P2): nepostavitelny config vrati GEOMETRICKE minimum, nie strop') do
  # 6 polic potrebuje 6 x 18 + 7 x 20 = 248 mm svetla — to sa do legalneho
  # rozsahu zmesti, takze sa hlada dalej. Test strazi opacny extrem: ked by
  # neprosla ani maximalna vyska, funkcia nesmie vratit 3000 (klamp na strop
  # by bol horsi nez odmietnutie) — vrati startovaciu hranicu a rebuild padne
  # vlastnou hlaskou.
  many = NxS1E0.low_lower({ 'floor_height' => 0.0 }.merge(NxS1E0.with_shelves(6)))
  h = NxS1E0.cn.min_valid_height(many)
  NxTest.assert_close(284.0, h, 0.01, '6 polic: 248 svetla + dno 18 + strop 18')
  NxTest.assert(NxS1E0.buildable?(many, h))
  # Hranicny zamok zon: zamknute pole sirsie nez korpus sa nepostavi NIKDY.
  bad = NxS1E0.low_lower('zone_tree' => { 'id' => 'Z1', 'shelves' => 0,
                                          'split' => { 'axis' => 'v',
                                                       'cuts' => [{ 'size' => 5000.0, 'locked' => true },
                                                                  { 'size' => 5000.0, 'locked' => true }] },
                                          'children' => [{ 'id' => 'Z2', 'shelves' => 0, 'children' => [] },
                                                         { 'id' => 'Z3', 'shelves' => 0, 'children' => [] }] })
  NxTest.refute(NxS1E0.buildable?(bad, 3000.0), 'taky config sa nepostavi ani na strope')
  NxTest.assert(NxS1E0.cn.min_valid_height(bad) < 100.0,
                'vrati sa geometricke minimum, nie strop rozsahu')
end

NxTest.test('S1-E0 (Codex #375 P2): dolna so soklom 100 a hrubkou 18 ma minimum 147 mm') do
  # 100 (sokel) + 2 x 18 (dno a strop) + 11 (vnutro tesne nad hranicou 10) = 147.
  cfg = NxS1E0.low_lower('floor_height' => 100.0)
  NxTest.assert_close(147.0, NxS1E0.cn.min_valid_height(cfg), 0.01)
  NxTest.assert_close(11.0, NxS1E0.cn.avail_at(cfg, 147.0), 0.01, 'vnutro 11 mm je tesne NAD hranicou')
end

NxTest.test('S1-E0 (Codex #375 P2): bez sokla je minimum POD hranicou 80 — rozhoduje MIN') do
  # Absorpcia berie prisnejsie z dvoch: `MIN['height']` a `min_valid_height`.
  # Pri sokli 0 je geometricke minimum 47 mm, takze rozhoduje absolutnych 80.
  cfg = NxS1E0.low_lower('floor_height' => 0.0)
  NxTest.assert_close(47.0, NxS1E0.cn.min_valid_height(cfg), 0.01)
  NxTest.assert(NxS1E0.cb::MIN[:height] > NxS1E0.cn.min_valid_height(cfg),
                'pri nulovom sokli je tvrdsie absolutne minimum 80 mm')
end

NxTest.test('S1-E0 (Codex #375 P2): absorpcia scale klampuje CONFIG-AWARE, nie na hole MIN') do
  # `scale_observer.rb` sa headless nenacitava (potrebuje zive SketchUp API),
  # takze sa strazi ZDROJ: vyska musi ist cez `clamp_height`, ktory berie
  # `Construction.min_valid_height`. Spravanie nad zivym modelom dokazuje
  # in-SU sekcia `run_s1e0` (bod e).
  src = NxS1E0.src('noxun_engine', 'core', 'scale_observer.rb')
  NxTest.assert(src.include?("params['height'] = clamp_height(params,"),
                'vyska ide cez config-aware clamp')
  NxTest.assert(src.include?('Construction.min_valid_height'),
                'a ten cita najnizsiu PLATNU vysku z Construction')
  NxTest.refute(src.include?("clamp_min('height'"),
                'stary klamp vysky na hole MIN uz v absorpcii nie je')
end

NxTest.test('S1-E0 (Codex #375 P2): panel berie PRAZDNY sokel ako predvolbu typu, nie ako nulu') do
  # Ruby `normalize` dosadi za prazdne pole PREDVOLBU typu (dolna skrinka ma
  # sokel 100 mm). Keby panel ratal s nulou, vyska 90 by presla cervenou
  # kontrolou a padla az na serveri — teda presne to, comu ma zabranit.
  # Parita je STRUKTURNA: panel cita cisla, ktore mu server posiela.
  NxTest.assert_close(100.0, NxS1E0.cb::LOWER_DEFAULTS[:floor_height], 0.01,
                      'dolna skrinka ma predvoleny sokel 100 mm')
  NxTest.assert_close(0.0, NxS1E0.cb::UPPER_DEFAULTS[:floor_height], 0.01,
                      'horna skrinka sokel nema')
  sync = NxS1E0.src('noxun_engine', 'ui', 'panel', 'sync.rb')
  NxTest.assert(sync.include?('lower: CabinetBuilder::LOWER_DEFAULTS'),
                'server posiela do panela PRIAMO svoje predvolby (ziadna druha tabulka)')
  NxTest.assert(sync.include?('upper: CabinetBuilder::UPPER_DEFAULTS'))
  js = NxS1E0.form_js
  NxTest.assert(js.include?("cabFieldOrDefault('floor_height')"),
                'krizova kontrola cita sokel cez predvolbu, nie cez `|| 0`')
  NxTest.assert(js.include?("cabFieldOrDefault('thickness')"),
                'a hrubku rovnako')
  NxTest.assert(js.include?('DEFAULTS[getType()]'),
                'zdrojom predvolieb je payload servera')
end

NxTest.test('S1-E0 (Codex #375 P2): hranicu vnutra drzi JEDNA konstanta (MIN_AVAIL_H)') do
  NxTest.assert_close(10.0, NxS1E0.cn::MIN_AVAIL_H, 0.01)
  src = NxS1E0.src('noxun_engine', 'core', 'construction.rb')
  NxTest.assert(src.include?('interior[:avail_h] <= MIN_AVAIL_H'),
                'validate! pouziva konstantu, nie literal — inak by sa rozisla s hladanim')
  js = NxS1E0.form_js
  NxTest.assert(js.include?('var MIN_AVAIL_H = 10.0'),
                'panel zrkadli to iste cislo (form.js MIN_AVAIL_H)')
end

NxTest.test('S1-E0 R3: dve vystuhy v nizkom korpuse su odmietnute (D-80 rezerva)') do
  NxTest.assert_raise(/nizke na vystuhy|nízke na výstuhy/i) do
    NxS1E0.cn.build_plan(
      NxS1E0.low_lower('height' => 80.0, 'floor_height' => 25.0, 'top_mode' => 'two_rails'),
      'CAB-S1E0-7'
    )
  end
end
