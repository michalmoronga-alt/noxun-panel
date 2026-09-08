# frozen_string_literal: true
# KOV-F2 (9.9.2026) — EDITOR door guardov pravidla závesov (server + zrkadlo klienta).
#
# F1 dala pravidlu `bands` voliteľné kľúče (`width_plus`, `width_warn_over`,
# `weight_bands`, `finite`) a sekcia Pravidlá ich vedela LEN prečítať. F2 z nich
# robí formulár — a s formulárom prichádza otázka, čo sa smie uložiť.
#
# ČO SA OVERUJE:
#   1) BRÁNA hmotnostných pásiem (`weight_bands_problem`): prázdna tabuľka ·
#      pásmo bez kilogramov · dve pásma s rovnakou hmotnosťou. Chýbajúci kľúč
#      sa NEVALIDUJE (guard je voliteľný), vypnuté pravidlo tiež nie.
#   2) KRITÉRIUM VISÍ NA `kind`, nie na výstupe — `bands` pravidlo s iným
#      výstupom sa kontroluje rovnako (a `fit_series` s guardmi vôbec).
#   3) DELIACA ČIARA medzi normalizáciou a bránou: `width_plus`/`width_warn_over`
#      v neplatnom tvare `normalize_rules` ZAHODÍ (kontrakt F1), takže brána ich
#      nemá čo odmietať — do modelu sa nezmysel nedostane ani tak. Editor taký
#      tvar ani neposiela (prázdne pole = kontrola vypnutá, chýbajúci počet = 1).
#   4) POČET v hmotnostnom pásme sa nevaliduje: normalizácia riadok zahodí.
#      Keď vypadnú VŠETKY, ostane prázdna tabuľka — a tú brána chytí.
#   5) ZRKADLO KLIENTA: `ui/js/rules.js` pozná presne tie isté guard kľúče ako
#      `DOOR_GUARD_KEYS`, zbiera ich do pravidla a má tie isté tri kritériá;
#      paritu textov a verdiktov stráži `tests/fixtures/rules_validation_parity.json`.
#   6) ROUND-TRIP: pravidlo s guardmi prejde normalizáciou aj JSON snapshotom
#      bez zmeny; pravidlo BEZ guardov si žiadny kľúč nevymyslí.
#
# MUTÁCIE, ktoré táto sada chytá (každá by prázdnou sadou prešla):
#   M1 prázdna tabuľka hmotností prejde uložením   -> „hmotnostné pásma sú prázdne"
#   M2 pásmo bez kilogramov prejde                 -> „potrebuje kilogramy"
#   M3 duplicitná hmotnosť prejde                  -> „rovnakú hmotnosť"
#   M4 brána validuje aj chýbajúci kľúč            -> voliteľnosť guardu
#   M5 brána visí na `output == 'hinge'`           -> `bands` s iným výstupom
#   M6 vypnuté pravidlo sa začne kontrolovať       -> `enabled: false`
#   M7 poradie pásiem sa začne vynucovať           -> opačné poradie je OK
#   M8 editor prestane zbierať niektorý guard      -> zoznam kľúčov v rules.js
#   M9 klient prestane clampovať `add`/počet       -> zber v rules.js
#  M10 normalizácia začne držať neplatný guard     -> deliaca čiara (bod 3)
require_relative '../helper' unless defined?(NxTest)

require 'json'

module NxKovF2
  E  = Noxun::Engine
  HR = E::HardwareRules

  RULES_JS = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'rules.js')

  module_function

  # Pravidlo zavesov tak, ako ho zapise EDITOR (tabulka + vsetky styri guardy).
  def hinge_rule(over = {})
    { 'rule_id' => 'zavesy-podla-vysky', 'enabled' => true, 'output' => 'hinge',
      'kind' => 'bands', 'input' => 'height',
      'applies_to' => { 'role' => 'front_door' },
      'bands' => [{ 'max' => 849.0, 'quantity' => 2 }, { 'max' => nil, 'quantity' => 7 }],
      'finite' => true,
      'width_plus' => { 'over' => 600.0, 'add' => 1 },
      'width_warn_over' => 800.0,
      'weight_bands' => [{ 'max' => 7.7, 'quantity' => 2 }, { 'max' => 22.0, 'quantity' => 5 }] }
      .merge(over)
  end

  # Pravidlo BEZ jedineho guardu — presne to, co vidi stary citac.
  def plain_rule(over = {})
    { 'rule_id' => 'zavesy-podla-vysky', 'enabled' => true, 'output' => 'hinge',
      'kind' => 'bands', 'input' => 'height',
      'applies_to' => { 'role' => 'front_door' },
      'bands' => [{ 'max' => 849.0, 'quantity' => 2 }, { 'max' => nil, 'quantity' => 7 }] }
      .merge(over)
  end

  # To, co naozaj rozhoduje pri ULOZENI: normalizacia a AZ POTOM brana.
  def save_problems(rule)
    HR.rules_problems(HR.normalize_rules([rule]))
  end

  def message(rule)
    save_problems(rule).map { |p| p['message'] }.first.to_s
  end

  def stored(rule)
    HR.normalize_rules([rule]).first
  end

  def js
    @js ||= File.read(RULES_JS, encoding: 'UTF-8')
  end

  # Telo funkcie z rules.js (od `function <meno>(` po prvy uzatvarajuci
  # riadok s dvomi medzerami) — vzor `st3b2_rd_body` v sade ŠT-3b.
  def js_body(name)
    js[/function #{Regexp.escape(name)}\(.*?\n  \}\n/m].to_s
  end
end

# ============================================================================
# 1 — BRANA HMOTNOSTNYCH PASIEM
# ============================================================================

NxTest.test('KOV-F2 (1): PLATNA tabuľka hmotností sa uloží') do
  c = NxKovF2
  NxTest.assert_equal([], c.save_problems(c.hinge_rule), 'seedový tvar prejde bránou')
end

NxTest.test('KOV-F2 (1): PRÁZDNA tabuľka hmotností sa NEULOŽÍ') do
  c = NxKovF2
  msg = c.message(c.hinge_rule('weight_bands' => []))
  NxTest.assert(msg.include?('hmotnostné pásma sú prázdne'), "hláška povie ČO: #{msg}")
  NxTest.assert(msg.include?('Závesy'), 'a menuje pravidlo rečou stolára')
  NxTest.assert(msg.include?('zavesy-podla-vysky'), 'aj jednoznačnou identitou záznamu')
end

NxTest.test('KOV-F2 (1): pásmo hmotnosti BEZ kilogramov sa NEULOŽÍ') do
  c = NxKovF2
  # Prazdne pole v editore posiela klient ako `null` — riadok, ktory pouzivatel
  # VEDOME pridal, sa nezahadzuje ticho.
  msg = c.message(c.hinge_rule('weight_bands' => [{ 'max' => nil, 'quantity' => 2 }]))
  NxTest.assert(msg.include?('potrebuje kilogramy'), "hláška pomenuje chýbajúci údaj: #{msg}")
  NxTest.assert(msg.include?('väčšie ako 0'), 'aj to, čo je platná hodnota')
  # Nula a zaporna hodnota su TO ISTE — pasmo „do 0 kg" nechyti nic.
  [0, -5.0, 'abc'].each do |bad|
    NxTest.assert(c.message(c.hinge_rule('weight_bands' => [{ 'max' => bad, 'quantity' => 2 }]))
                   .include?('potrebuje kilogramy'), "aj `#{bad.inspect}`")
  end
end

NxTest.test('KOV-F2 (1): dve pásma s ROVNAKOU hmotnosťou sa NEULOŽIA') do
  c = NxKovF2
  msg = c.message(c.hinge_rule('weight_bands' => [{ 'max' => 7.7, 'quantity' => 2 },
                                                  { 'max' => 7.7, 'quantity' => 3 }]))
  NxTest.assert(msg.include?('rovnakú hmotnosť'), "druhý riadok by bol mŕtvy: #{msg}")
end

NxTest.test('KOV-F2 (1): PORADIE pásiem sa nevynucuje — server ich zoradí sám') do
  c = NxKovF2
  rule = c.hinge_rule('weight_bands' => [{ 'max' => 22.0, 'quantity' => 5 },
                                         { 'max' => 7.7, 'quantity' => 2 }])
  NxTest.assert_equal([], c.save_problems(rule), 'opačné poradie NIE JE chyba používateľa')
  NxTest.assert_equal([7.7, 22.0], c.stored(rule)['weight_bands'].map { |b| b['max'] },
                      'normalizácia ich zoradí podľa hmotnosti')
end

# ============================================================================
# 2 — VOLITELNOST GUARDU A ROZSAH KRITERIA
# ============================================================================

NxTest.test('KOV-F2 (2): pravidlo BEZ hmotnostných pásiem sa nevaliduje') do
  c = NxKovF2
  NxTest.assert_equal([], c.save_problems(c.plain_rule), 'starý tvar prejde ako doteraz')
  NxTest.assert_equal([], c.save_problems(c.hinge_rule.tap { |r| r.delete('weight_bands') }),
                      'a rovnako pravidlo s ostatnými guardmi bez hmotnostnej tabuľky')
  stored = c.stored(c.plain_rule)
  NxTest.assert_equal([], NxKovF2::HR::DOOR_GUARD_KEYS.select { |k| stored.key?(k) },
                      'normalizácia si guard nevymyslí — pravidlo bez guardov ostáva bez guardov')
end

NxTest.test('KOV-F2 (2): kritérium visí na `kind`, nie na výstupe pravidla') do
  c = NxKovF2
  other = c.hinge_rule('rule_id' => 'uchytky-pasma', 'output' => 'handle',
                       'weight_bands' => [{ 'max' => nil, 'quantity' => 2 }])
  NxTest.assert(c.message(other).include?('Úchytky'),
                'aj iné `bands` pravidlo s pokazenou tabuľkou sa odmietne')
  # `fit_series` guardy nikdy nepocita — validovat mu ich by znamenalo odmietnut
  # zaznam za pole, ktore sa nepouzije (rovnaka lekcia ako pri `bands` vs `series`).
  series = { 'rule_id' => 'vysuvy', 'output' => 'slide', 'kind' => 'fit_series',
             'enabled' => true, 'series' => [400.0],
             'weight_bands' => [{ 'max' => nil, 'quantity' => 2 }] }
  NxTest.assert_equal([], c.save_problems(series), '`fit_series` s guardmi prejde')
end

NxTest.test('KOV-F2 (2): VYPNUTÉ pravidlo sa nekontroluje (negeneruje nič)') do
  c = NxKovF2
  rule = c.hinge_rule('enabled' => false, 'weight_bands' => [])
  NxTest.assert_equal([], c.save_problems(rule), 'vypnutá tabuľka nikoho nezasiahne')
end

# ============================================================================
# 3 — DELIACA CIARA: CO ZAHODI NORMALIZACIA A CO ODMIETNE BRANA
# ============================================================================

NxTest.test('KOV-F2 (3): neplatný `width_plus`/`width_warn_over` normalizácia ZAHODÍ') do
  c = NxKovF2
  # Kontrakt F1 (radsej ziadny guard nez hadanie) sa NEMENI. Do modelu sa teda
  # nezmysel nedostane ani bez brany — a brana ho uz nema co odmietat.
  bad = c.stored(c.hinge_rule('width_plus' => { 'over' => 0, 'add' => 1 },
                              'width_warn_over' => 'x'))
  NxTest.refute(bad.key?('width_plus'), 'nekladná šírka = guard preč')
  NxTest.refute(bad.key?('width_warn_over'), 'nečíselná hranica = guard preč')
  NxTest.assert_equal([], NxKovF2::HR.rules_problems([bad]),
                      'a uloženie sa NEBLOKUJE — zapíše sa pravidlo bez tohto guardu')
  NxTest.assert_equal({ 'over' => 600.0, 'add' => 1 },
                      c.stored(c.hinge_rule('width_plus' => { 'over' => '600', 'add' => '1' }))['width_plus'],
                      'platný tvar sa typovo očistí (Float/Integer)')
end

NxTest.test('KOV-F2 (3): pásmo s neplatným POČTOM normalizácia zahodí, zvyšok tabuľky platí') do
  c = NxKovF2
  rule = c.hinge_rule('weight_bands' => [{ 'max' => 7.7, 'quantity' => 2 },
                                         { 'max' => 13.7, 'quantity' => 0 }])
  NxTest.assert_equal([], c.save_problems(rule), 'jeden pokazený riadok uloženie nezhodí')
  NxTest.assert_equal([7.7], c.stored(rule)['weight_bands'].map { |b| b['max'] },
                      'do modelu ide len použiteľný riadok')
  # Ked vypadnu VSETKY, ostane PRAZDNA tabulka — a tu brana chyti.
  all_bad = c.hinge_rule('weight_bands' => [{ 'max' => 7.7, 'quantity' => 0 }])
  NxTest.assert(c.message(all_bad).include?('prázdne'),
                'keď vypadnú všetky, uloženie sa odmietne')
end

NxTest.test('KOV-F2 (3): `weight_bands` v NESPRÁVNOM tvare normalizácia zmení na PRÁZDNE pole') do
  c = NxKovF2
  # Codex #330 kolo 1 (P2): hash/retazec/cislo v tomto kluci islo do panela tak,
  # ako prislo — a `.forEach` nad nim zhodil CELU sekciu Pravidla, teda aj
  # jedine miesto, kde sa taka hodnota da opravit. Normalizacia z kazdeho
  # takeho tvaru robi prazdne pole (editor tak vzdy dostane tabulku).
  [{ 'max' => 7.7 }, 'sedem', 7, true, nil].each do |bad|
    stored = c.stored(c.hinge_rule('weight_bands' => bad))
    NxTest.assert_equal([], stored['weight_bands'], "z tvaru #{bad.inspect} ostane prázdne pole")
  end
  # Data sa tym NESTRACAJU: pouzitelne pasmo je Hash v poli a to prezije.
  NxTest.assert_equal([7.7, 22.0], c.stored(c.hinge_rule)['weight_bands'].map { |b| b['max'] },
                      'platná tabuľka sa nedotkne')
  # A prazdna tabulka sa dalej NEULOZI — brana ostava tam, kde bola.
  NxTest.assert(c.message(c.hinge_rule('weight_bands' => { 'max' => 7.7 })).include?('prázdne'),
                'uloženie takého pravidla sa odmietne vetou (nezmysel v modeli neostane)')
end

NxTest.test('KOV-F2 (3): brána ostáva ČISTÁ funkcia bez IO a bez druhého volajúceho') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_rules.rb'),
                  encoding: 'UTF-8')
  body = src[/def weight_bands_problem\(rule\).*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo sa našlo')
  %w[write set_project_rules JsonFileStore Sketchup].each do |io|
    NxTest.refute(body.include?(io), "žiadne IO (#{io})")
  end
  code = src.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(2, code.scan(/weight_bands_problem/).length,
                      'definícia + JEDINÝ volajúci (`bands_problem`) — brána sa nevolá druhou cestou')
end

# ============================================================================
# 4 — ZRKADLO KLIENTA (ui/js/rules.js)
# ============================================================================

NxTest.test('KOV-F2 (4): editor pozná PRESNE tie guard kľúče, ktoré pozná server') do
  c = NxKovF2
  list = c.js[/var RD_GUARD_KEYS = \[(.*?)\];/m, 1].to_s
  NxTest.assert(!list.empty?, 'zoznam kľúčov v rules.js sa našiel')
  keys = list.scan(/'([a-z_]+)'/).flatten
  NxTest.assert_equal(NxKovF2::HR::DOOR_GUARD_KEYS.sort, keys.sort,
                      'klient si guard kľúče neopisuje vlastným slovníkom')
end

NxTest.test('KOV-F2 (4): zber formulára zapisuje KAŽDÝ guard a prázdne pole ho maže') do
  c = NxKovF2
  body = c.js_body('rdCollectGuards')
  NxTest.assert(!body.empty?, 'zberná funkcia existuje')
  NxKovF2::HR::DOOR_GUARD_KEYS.each do |key|
    NxTest.assert(body.include?("r.#{key} ") || body.include?("r.#{key} =") ||
                  body.include?("delete r.#{key}"),
                  "guard `#{key}` sa zbiera aj maže")
    NxTest.assert(body.include?("delete r.#{key}"),
                  "a prázdne pole ho z pravidla ODSTRÁNI (`#{key}`)")
  end
  NxTest.assert(body.include?("if (!box) return"),
                'pravidlo bez editora sa nedotýka — kľúče prežijú uloženie')
end

NxTest.test('KOV-F2 (4): klient CLAMPUJE, takže neposiela tvar, ktorý by server ticho zahodil') do
  c = NxKovF2
  body = c.js_body('rdCollectGuards')
  NxTest.assert(body.include?('over > 0'), 'nekladná šírka = kontrola vypnutá (nie neplatný guard)')
  NxTest.assert(body.include?('warn > 0'), 'a rovnako hranica varovania')
  NxTest.assert(body.include?('add < 1) ? 1 : add'), 'chýbajúci počet kusov = 1 (vzor výškových pásiem)')
  NxTest.assert(body.include?('q < 1) ? 1 : q'), 'aj počet v hmotnostnom pásme')
end

NxTest.test('KOV-F2 (4): klientska validácia má TIE ISTÉ tri kritériá') do
  c = NxKovF2
  body = c.js_body('rdWeightProblem')
  NxTest.assert(!body.empty?, 'zrkadlo v rules.js existuje')
  ['hmotnostné pásma sú prázdne', 'potrebuje kilogramy', 'rovnakú hmotnosť'].each do |bit|
    NxTest.assert(body.include?(bit), "kritérium „#{bit}“ pozná aj klient")
  end
  NxTest.assert(body.include?('rdWeightQtyOk'),
                'a riadky, ktoré server zahodí, klient nepočíta (inak by parita padla)')
  fixture = JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures',
                                           'rules_validation_parity.json'), encoding: 'UTF-8'))
  guard_cases = fixture['cases'].select { |x| JSON.generate(x['rules']).include?('weight_bands') }
  NxTest.assert(guard_cases.length >= 6,
                'a spoločná fixtúra parity nesie prípady guardov (inak by ich parita nestrážila)')
end

# ============================================================================
# 5 — ROUND-TRIP PRAVIDLA S GUARDMI
# ============================================================================

NxTest.test('KOV-F2 (5): pravidlo s guardmi prežije normalizáciu aj JSON snapshot') do
  c = NxKovF2
  once = c.stored(c.hinge_rule)
  again = NxKovF2::HR.normalize_rules(JSON.parse(JSON.generate([once]))).first
  NxTest.assert_equal(once, again, 'normalizácia je idempotentná a JSON nič nestratí')
  NxTest.assert_equal(true, once['finite'])
  NxTest.assert_equal({ 'over' => 600.0, 'add' => 1 }, once['width_plus'])
  NxTest.assert_equal(800.0, once['width_warn_over'])
  NxTest.assert_equal([[7.7, 2], [22.0, 5]], once['weight_bands'].map { |b| [b['max'], b['quantity']] })
end
