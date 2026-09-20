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
