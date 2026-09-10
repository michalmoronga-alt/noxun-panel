# frozen_string_literal: true
# KOV-G2 (10.9.2026) — „SET NOH VIDITELNY PRI VKLADANI A V KORPUSE" (D-111).
#
# CO SA RIESI: G1a priniesla DATA (set „Nohy podľa výšky sokla", prichyt sokla)
# a G1b PRAVIDLA (4/6 podla sirky, prichyt od sokla 55 mm). Zistit, AKE nohy
# skrinka dostane, sa vsak dalo az v Nakupe — predvolba setu zila schovana
# v Predvolbach projektu (D-111). Tato davka pridava JEDEN riadok, ktory to
# povie uz PRI VKLADANI a potom pri sokli v Korpuse.
#
# CO SA OVERUJE:
#   1) `HardwareSets.legs_summary` — SK veta z vysledku `explain`:
#      klzak (sokel 17) · AXILO + platnicka + prichyty (1200/100) · zona
#      20-55 mm ako `warn` s vetou KONTROLY · horna skrinka ako `none`
#   2) ZLIATIE dovodov — set noh ma pri sokli 40 mm DVA nemapovane zaznamy
#      (noha aj platnicka), riadok panela ma povedat JEDNU vetu
#   3) SKRATENIE nazvov — z katalogoveho (objednavacieho) nazvu sa iba ODOBERA
#      (vyrobca + objednavacie cislo, koncova zatvorka); nic sa neprepisuje
#   4) `Construction.cabinet_hw_ctx` — JEDEN slovnik korpusoveho kontextu
#      (`build_plan` si ho MERGUJE, ziadna druha kopia) a `evaluate` nad nim
#      s `parts = []` vyda LEN korpusove pravidla
#   5) `Panel.legs_preview_summary` — cesta vkladacej karty: rovnaky text ako
#      pre ULOZENU skrinku, ziadny cabinet override (skrinka neexistuje)
#   6) `insert_legs_preview` — CITACI callback: `gen` sa vracia nezmenena,
#      payload je UZAVRETY (`INSERT_LEGS_KEYS`), handler NEZAPISUJE do modelu
#      a odpoved chodi kanalom `NX.insertLegsPreview`
#   7) `cabinet_payload` nesie `legs_summary` z UZ ROZPISANYCH poloziek
#      (`legs_summary_from_purchase`) — riadok a rozklik polozky sa nerozidu
#   8) `GhostTool.state_payload` nesie `legs_short`/`legs_tone` LEN pre skrinku
#      (doska nikdy) a suhrn sa pocita RAZ za session
#   9) (Codex #339 kolo 1 N1) KOVANIE ZO SABLONY — nahlad sa pyta PROSPEKTIVNEHO
#      stavu setov (projekt + definicie, ktore v nom este nie su; projekt
#      vyhrava), mapovanie ide TOU ISTOU branou ako vklad
#  10) (Codex #339 kolo 1 N2/N4/N5) ZIVOTNY CYKLUS RIADKU — doskova vetva karty
#      ho resetuje, lahky push (`push_hardware_sets`) nesie cerstvu vetu
#      a zmena setov/pravidiel POCAS ghost session zneplatni memo pasika
#
# MUTACIE (kazda overena spustenim — po zaneseni chyby spadnu uvedene testy):
#   M1 `legs_problems` prestane zlievat zaznamy podla priciny (kluc = cely
#      zaznam vratane `member_label`)
#      -> „(2): sokel 40 mm — JEDNA veta, nie dve"
#   M2 `legs_item_text` pripaja dalsie cleny plnym katalogovym nazvom
#      (namiesto LABELU setu)
#      -> „(1): 1200/100 — sest noh AXILO, platnicka a dva prichyty"
#   M3 `state_payload` posiela `legs_short` aj pre DOSKU (podmienka `cabinet?`
#      v `legs_summary_for` zanikne)
#      -> „(8): pasik DOSKY o nohach nehovori"
#   M4 `insert_legs_preview_result` posle do `normalize` CELY payload
#      (whitelist `INSERT_LEGS_KEYS` sa nepouzije)
#      -> „(6): payload nahladu je UZAVRETY"
#   M5 `cabinet_payload` sklada `legs_summary` vlastnym volanim `legs_summary`
#      nad `cfg['hardware']` (druhy rozpis vedla `purchase`)
#      -> „(7): payload skrinky sklada riadok z UZ ROZPISANYCH poloziek"
#   M6 `state_with_template_sets` vrati stav nezmeneny (definicie sablony sa
#      do nahladu nedostanu)
#      -> „(9): prospektivny stav…" + „(9): nahlad ukaze SET ZO SABLONY…"
#   M7 `cabinet_set_overrides` cita LEN stringovy kluc (`normalize` dava symboly)
#      -> „(9): nahlad ukaze SET ZO SABLONY…", „(9): mapovanie BEZ definicie…",
#         „(9): callback nesie kovanie sablony…"
#   M8 `push_hardware_sets` prestane prikladat `legs_summary` (a hook zneplatnenia)
#      -> „(10): lahky push nesie CERSTVY riadok Noh (N4)" + „(10): hooky…"
#   M9 `PlacementSession#invalidate_legs_summary!` memo nezahodi
#      -> „(10): zmena mapovania POCAS session prepocita suhrn pasika"
#
# Ghost pasik, riadok v karte a undo dokazuje in-SketchUp sekcia `run_kovg`.
require_relative '../helper' unless defined?(NxTest)

require 'json'

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers') # `parse`
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware')
end

module NxKovG2
  E   = Noxun::Engine
  HWS = E::HardwareSets
  HR  = E::HardwareRules
  CB  = E::CabinetBuilder
  CON = E::Construction

  module_function

  def src(rel)
    File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel))
        .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  def method_src(rel, name, indent = 8)
    src(rel)[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end

  # Telo JS funkcie (form.js ma odsadenie 2) — kontrakt „kto koho vola" sa
  # v Node sade overit neda: `materializeInsertBoardCard` nie je exportovana
  # a jej stubovanie by overovalo stub, nie kartu.
  def js_func_src(rel, name, indent = 2)
    src(rel)[/^#{' ' * indent}function #{Regexp.escape(name)}\(.*?
#{' ' * indent}\}
/m].to_s
  end

  def cfg(width: 900.0, fh: 100.0, type: 'lower', plinth: 'none')
    CB.normalize('type' => type, 'width' => width, 'floor_height' => fh,
                 'plinth_mode' => plinth)
  end

  # KATALOG AKO FIXTURE. Sada bezi v jednom procese s ostatnymi (`run_all.rb`)
  # a tie si do sandboxu katalogu pisu vlastne polozky — text riadku by potom
  # zavisel od poradia sad. Nazvy su presne tie, ktore ma seed katalogu
  # (KOV-G1a), takze sa overuje aj SKRATENIE objednavacieho nazvu.
  CATALOG = [
    { 'item_code' => '272212', 'name_sk' => 'STRONG Klzák s rektifikáciou, výška 17mm, šedá' },
    { 'item_code' => '9078', 'name_sk' => 'Häfele 637.76.353 noha AXILO H100' },
    { 'item_code' => '9079',
      'name_sk' => 'Häfele 637.76.333 platnička AXILO 79×92×2,5 mm čierna' },
    { 'item_code' => '950',
      'name_sk' => 'Häfele 637.38.054 príchyt sokla AXILO (k drevenému soklu)' }
  ].freeze

  # SABLONOVY set noh (Codex #339 kolo 1 N1): najjednoduchsi mozny — jeden clen
  # s pevnym kodom klzaka. V projekte NIE JE, takze nahlad ho musi vziat
  # z definicii, ktore prichadzaju so sablonou.
  TPL_SET_ID = 'kovg2-sablona-nohy'
  TPL_SET = { 'set_id' => TPL_SET_ID, 'name' => 'Nohy zo šablóny',
              'generic_type' => 'leg',
              'members' => [{ 'per' => 'unit', 'qty' => 1, 'label' => 'noha',
                              'code' => '272212' }] }.freeze
  TPL_MAP = { 'leg' => TPL_SET_ID }.freeze

  # Globalna kniznica setov ako projektovy stav NA CITANIE — presne to, co
  # panelu vrati `hardware_read_state` pri projekte bez snapshotu.
  def state
    lib = HWS.load
    sets = {}
    lib['sets'].each { |s| sets[s['set_id']] = s }
    { 'mapping' => lib['mapping'], 'sets' => sets }
  end

  # Polozky kovania korpusu zo SEED pravidiel (nikdy z kniznice pouzivatela —
  # sada musi byt nezavisla od toho, co ma na PC).
  def items(over = {})
    c = cfg(**over)
    hw = HR.evaluate(c, [], CON.cabinet_hw_ctx(c), rules: HR::SEED_RULES)
    hw[:items]
  end

  def summary(over = {})
    HWS.legs_summary(HWS.legs_items(items(over)), state, catalog: CATALOG)
  end

  # To iste, ale nad ZIVYM katalogom pocitaca — na porovnanie s panelovou
  # cestou (tá katalog fixture nepozna).
  def summary_live(over = {})
    HWS.legs_summary(HWS.legs_items(items(over)), state, catalog: E::HardwareCatalog.items)
  end

  # Tie iste polozky, ale rozpisane TAK, ako ich panel posiela karte
  # (`decorate_hardware_purchase` vesa na polozku kluc `purchase`).
  def decorated(over = {}, catalog = CATALOG)
    lookup = HWS.catalog_lookup(catalog)
    st = state
    HWS.legs_items(items(over)).map do |h|
      h.merge('purchase' => HWS.explain(h, st, overrides: {}, lookup: lookup))
    end
  end

  # Panelovy `hardware_read_state` sa pyta `Sketchup.active_model` — headless
  # taky objekt nie je, preto sa na cas testu nahradi CITANIM GLOBALNEJ
  # kniznice (presne stav `:missing`, teda „projekt snapshot este nema").
  # `st` je ZIVY objekt — scenar N5 doň počas session zapisuje (zmena
  # projektoveho mapovania v subezne otvorenom Studiu).
  def with_read_state(st = state)
    sc = E::Panel.singleton_class
    sc.send(:alias_method, :kovg2_orig_read_state, :hardware_read_state)
    sc.send(:define_method, :hardware_read_state) { [:missing, st] }
    yield st
  ensure
    sc.send(:remove_method, :hardware_read_state)
    sc.send(:alias_method, :hardware_read_state, :kovg2_orig_read_state)
    sc.send(:remove_method, :kovg2_orig_read_state)
  end

  # Callback `insert_legs_preview_result` sa pyta `Sketchup.active_model`.
  # Headless taka konstanta neexistuje, takze cela cesta konci v `rescue` —
  # scenar N1 potrebuje overit jej NORMALNU vetvu, preto si na cas testu
  # poziciava prazdnu atrapu (model je `nil`, teda presne to, s cim pracuje
  # `legs_preview_summary` v ostatnych scenaroch). `NxTest::IN_SKETCHUP` sa
  # pocita pri nacitani helpera, takze sa tym NEZMENI.
  def with_sketchup
    return yield if Object.const_defined?(:Sketchup)

    mod = Module.new do
      def self.active_model
        nil
      end
    end
    Object.const_set(:Sketchup, mod)
    begin
      yield
    ensure
      Object.send(:remove_const, :Sketchup)
    end
  end

  # Zachytenie `Panel.js` — odpoved callbacku ide TOUTO cestou.
  def capture_js
    sc = E::Panel.singleton_class
    out = []
    sc.send(:alias_method, :kovg2_orig_js, :js)
    sc.send(:define_method, :js) { |script| out << script }
    yield out
  ensure
    sc.send(:remove_method, :js)
    sc.send(:alias_method, :js, :kovg2_orig_js)
    sc.send(:remove_method, :kovg2_orig_js)
  end
end

# --- 1) legs_summary: SK veta z vysledku explain -------------------------------

NxTest.test('KOV-G2 (1): sokel 17 mm — styri klzaky, ZIADNA platnicka') do
  s = NxKovG2.summary(width: 900.0, fh: 17.0)
  NxTest.assert_equal 'ok', s['tone'], 'set pasmo 17-20 mm ma — ziadne upozornenie'
  NxTest.assert(s['text'].start_with?('4× '), "styri nohy pri sirke 900: #{s['text']}")
  NxTest.assert(s['text'].include?('Klzák'), "a je to klzak, nie AXILO: #{s['text']}")
  NxTest.refute(s['text'].include?('platnička'),
                'platnicka ma v pasme 17-20 sentinel `none` — v texte nema co robit')
  NxTest.assert_equal 'nohy-podla-sokla', s['set_id'], 'riadok vie, ktory set plati'
end

NxTest.test('KOV-G2 (1): 1200/100 — sest noh AXILO, platnicka a dva prichyty') do
  s = NxKovG2.summary(width: 1200.0, fh: 100.0)
  NxTest.assert_equal 'ok', s['tone'], 'vsetko namapovane'
  NxTest.assert_equal '6× noha AXILO H100 + platnička · 2× príchyt sokla AXILO', s['text'],
                      'pocet zo sirky (G1b), kod z vysky sokla (G1a), prichyt vlastnou polozkou'
end

NxTest.test('KOV-G2 (1): horna skrinka a skrinka bez sokla — „bez nôh"') do
  up = NxKovG2.summary(type: 'upper')
  NxTest.assert_equal 'none', up['tone'], 'horna skrinka nohy nema'
  NxTest.assert_equal 'bez nôh', up['text'], 'a text to povie jednym slovom'
  NxTest.assert_equal 'none', NxKovG2.summary(fh: 0.0)['tone'],
                      'sokel 0 = skrinka stoji na zemi, ziadne nohy'
end

NxTest.test('KOV-G2 (1): prazdny vstup nikdy nespadne') do
  NxTest.assert_equal 'none', Noxun::Engine::HardwareSets.legs_summary([], nil)['tone']
  NxTest.assert_equal 'none', Noxun::Engine::HardwareSets.legs_summary(nil, nil)['tone']
  NxTest.assert_equal 'none', Noxun::Engine::HardwareSets.legs_summary_from_purchase([])['tone']
end

# --- 2) zona 20-55 mm: JANTAROVY ton a JEDNA veta ------------------------------

NxTest.test('KOV-G2 (2): sokel 40 mm — JEDNA veta, nie dve') do
  s = NxKovG2.summary(width: 900.0, fh: 40.0)
  NxTest.assert_equal 'warn', s['tone'], 'vedome nepokryta zona 20-55 mm je jantarova'
  NxTest.assert(s['text'].include?('40 mm'), "veta menuje vysku sokla: #{s['text']}")
  NxTest.assert(s['text'].include?('nohy-podla-sokla'), 'a set, ktoremu pasmo chyba')
  NxTest.refute(s['text'].include?(' · '),
                "noha aj platnicka maju TU ISTU pricinu — riadok povie jednu vetu: #{s['text']}")
end

NxTest.test('KOV-G2 (2): veta je PRESNE ta, ktoru ukaze Kontrola') do
  legs = NxKovG2.decorated(width: 900.0, fh: 40.0)
  raw = Array(legs.first['purchase']['unmapped']).first
  NxTest.assert(raw.is_a?(Hash), 'PREMISA: rozpis nesie SUROVY zaznam nalezu')
  NxTest.assert_equal Noxun::Engine::HardwareSets.unmapped_reason_sk(raw),
                      NxKovG2.summary(width: 900.0, fh: 40.0)['text'],
                      'ziadny druhy preklad dovodu — riadok a Kontrola hovoria to iste'
end

NxTest.test('KOV-G2 (2): pasik ma text OREZANY, karta nie') do
  s = NxKovG2.summary(width: 900.0, fh: 40.0)
  max = Noxun::Engine::HardwareSets::LEGS_SHORT_MAX
  NxTest.assert(s['short'].length <= max, "pasik je JEDEN riadok (#{s['short'].length} > #{max})")
  NxTest.assert(s['text'].length > s['short'].length, 'karta nesie cele znenie')
end

# --- 3) skratenie katalogovych nazvov -----------------------------------------

NxTest.test('KOV-G2 (3): z nazvu sa iba ODOBERA, nikdy neprepisuje') do
  t = ->(n) { Noxun::Engine::HardwareSets.legs_trim_name(n) }
  NxTest.assert_equal 'noha AXILO H100', t.call('Häfele 637.76.353 noha AXILO H100'),
                      'vyrobca + objednavacie cislo odchadzaju'
  NxTest.assert_equal 'príchyt sokla AXILO',
                      t.call('Häfele 637.38.054 príchyt sokla AXILO (k drevenému soklu)'),
                      'a koncova zatvorka tiez'
  NxTest.assert_equal 'STRONG Klzák s rektifikáciou, výška 17mm, šedá',
                      t.call('STRONG Klzák s rektifikáciou, výška 17mm, šedá'),
                      'nazov BEZ objednavacieho cisla ostava CELY — vyska a farba su podstatne'
  NxTest.assert_equal '', t.call(nil), 'chybajuci nazov = prazdno (volajuci prizna kod)'
end

NxTest.test('KOV-G2 (3): kod MIMO katalogu sa PRIZNA, nikdy nezmizne') do
  item = { 'generic_type' => 'leg', 'quantity' => 4, 'rule_id' => 'r', 'params' => {} }
  purchase = { 'set_id' => 's', 'set_name' => 'Set', 'members' => [
    { 'code' => 'XX-999', 'name' => nil, 'missing' => true, 'qty' => 4, 'per' => 'unit',
      'label' => 'noha' }
  ], 'problems' => [], 'unmapped' => [] }
  s = Noxun::Engine::HardwareSets.legs_summary_from_purchase([item.merge('purchase' => purchase)])
  NxTest.assert_equal 'ok', s['tone'], 'kod mimo katalogu nie je nemapovana polozka'
  NxTest.assert(s['text'].include?('XX-999'), "objednat ho treba, takze ho text nesie: #{s['text']}")
end

# --- 4) cabinet_hw_ctx: JEDEN slovnik -----------------------------------------

NxTest.test('KOV-G2 (4): korpusovy kontext ma vsetky kluce, ktore pravidla noh citaju') do
  ctx = NxKovG2::CON.cabinet_hw_ctx(NxKovG2.cfg(width: 1200.0, fh: 100.0))
  NxTest.assert_equal 1200.0, ctx['width'], 'sirka rozhoduje o POCTE noh (G1b)'
  NxTest.assert_equal 100.0, ctx['floor_height'], 'vyska sokla o KODE (G1a)'
  NxTest.assert_equal 'legs', ctx['support'], 'podopretie rozhoduje o prichyte'
  NxTest.assert_equal 'lower', ctx['cabinet_type'], 'a typ korpusu o platnosti pravidla'
  up = NxKovG2::CON.cabinet_hw_ctx(NxKovG2.cfg(type: 'upper'))
  NxTest.assert_equal 'none', up['support'], 'horna skrinka nema co podopierat'
end

NxTest.test('KOV-G2 (4): `build_plan` si kontext MERGUJE — ziadna druha kopia') do
  body = NxKovG2.method_src('core/construction.rb', 'build_plan', 6)
  NxTest.refute(body.empty?, 'PREMISA: telo `build_plan` sa naslo')
  NxTest.assert(body.include?('cabinet_hw_ctx(cfg).merge('),
                'korpusovu cast kontextu drzi JEDNA funkcia')
  NxTest.refute(body.include?("'support' => support_type(cfg)"),
                'druhy slovnik by sa casom rozisiel s nahladom vkladacej karty')
end

NxTest.test('KOV-G2 (4): `evaluate` s `parts = []` vyda LEN korpusove pravidla') do
  types = NxKovG2.items(width: 1200.0, fh: 100.0).map { |i| i['generic_type'] }.uniq.sort
  NxTest.assert_equal %w[leg plinth_clip], types,
                      'bez dielcov nevznikne zaves ani vysuv — presne to nahlad potrebuje'
  NxTest.assert(NxKovG2.items(width: 1200.0, fh: 100.0).all? { |i| i['owner_part_key'].nil? },
                'korpusove polozky nemaju vlastnika (rola `cabinet`)')
end

# --- 5) cesta vkladacej karty --------------------------------------------------

NxTest.test('KOV-G2 (5): nahlad vkladania dava TEN ISTY text ako ulozena skrinka') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  NxKovG2.with_read_state do
    got = Noxun::Engine::Panel.legs_preview_summary(nil, NxKovG2.cfg(width: 1200.0, fh: 100.0))
    NxTest.assert_equal NxKovG2.summary_live(width: 1200.0, fh: 100.0)['text'], got['text'],
                        'karta a vkladanie sa rozist NESMU'
    NxTest.assert_equal 'ok', got['tone']
  end
end

NxTest.test('KOV-G2 (5): horna skrinka si nahlad ani nevypyta katalog') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  NxKovG2.with_read_state do
    got = Noxun::Engine::Panel.legs_preview_summary(nil, NxKovG2.cfg(type: 'upper'))
    NxTest.assert_equal 'none', got['tone'], 'horna skrinka nohy nema'
  end
  body = NxKovG2.method_src('ui/panel/actions_hardware.rb', 'legs_preview_summary')
  NxTest.assert(body.index('return HardwareSets.legs_summary_from_purchase([]) if items.empty?') <
                body.index('hardware_read_state'),
                'skratka je PRED citanim stavu setov a katalogu')
end

NxTest.test('KOV-G2 (5): nahlad cita vyber setu z CONFIGU — ta ista mapa ako karta skrinky') do
  body = NxKovG2.method_src('ui/panel/actions_hardware.rb', 'legs_preview_summary')
  NxTest.assert(body.include?('overrides = blocked ? {} : cabinet_set_overrides(cfg)'),
                'vyber setu (zo sablony alebo zo zmrazeneho planu) ide TOU ISTOU cestou ako v karte')
  NxTest.assert(body.include?('item_purchase(h, status, state, overrides, lookup'),
                'a rozpisuje ho ta ista funkcia (jeden vyklad nakupu)')
end

NxTest.test('KOV-G2 (5): override mapa sa cita v OBOCH tvaroch kluca') do
  # Ulozeny config ma kluce STRINGOVE, `CabinetBuilder.normalize` (nahlad
  # aj zmrazeny plan ghostu) SYMBOLOVE — jeden tvar by nahlad oslepil.
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  want = { 'leg' => 'nohy-vlastne' }
  NxTest.assert_equal want,
                      Noxun::Engine::Panel.cabinet_set_overrides('hardware_sets' => want)
  NxTest.assert_equal want,
                      Noxun::Engine::Panel.cabinet_set_overrides(hardware_sets: want)
  NxTest.assert_equal({}, Noxun::Engine::Panel.cabinet_set_overrides({}))
end

# --- 6) callback insert_legs_preview: CITACI kanal -----------------------------

NxTest.test('KOV-G2 (6): callback je registrovany a odpoveda kanalom NX.insertLegsPreview') do
  NxTest.assert(NxKovG2.src('ui/panel.rb').include?("cb(dlg, 'insert_legs_preview')"),
                'panel callback registruje PRED `show` (vzor `hw_manual_search`)')
  body = NxKovG2.method_src('ui/panel/actions_hardware.rb', 'handle_insert_legs_preview')
  NxTest.assert(body.include?('NX.insertLegsPreview('), 'odpoved chodi svojim kanalom')
  NxTest.refute(body.include?('start_operation'), 'CITACIA cesta — ziadna operacia')
end

NxTest.test('KOV-G2 (6): payload nahladu je UZAVRETY') do
  # Konstanta zije v `class << self` panela (vzor `MANUAL_SEARCH_TOP`).
  keys = Noxun::Engine::Panel.singleton_class::INSERT_LEGS_KEYS
  NxTest.assert_equal %w[type width floor_height plinth_mode], keys,
                      'nahlad je pohlad na ROZMERY — nic ine sa do `normalize` nedostane'
  body = NxKovG2.method_src('ui/panel/actions_hardware.rb', 'insert_legs_preview_result')
  NxTest.assert(body.include?('INSERT_LEGS_KEYS.include?(k.to_s)'),
                'whitelist sa naozaj pouzije (nie len deklaruje)')
  NxTest.refute(body.include?('Store.set') || body.include?('set_attribute'),
                'nahlad NEUKLADA nic')
end

NxTest.test('KOV-G2 (6): `gen` sa vracia nezmenena aj v degradovanej vetve') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  res = Noxun::Engine::Panel.insert_legs_preview_result('gen' => 7, 'width' => 1200.0,
                                                        'floor_height' => 100.0,
                                                        'type' => 'lower')
  NxTest.assert_equal 7, res['gen'],
                      'bez generacie by pomalsie kolo prepisalo cerstvejsi vysledok'
  NxTest.assert(%w[ok warn none].include?(res['tone']), 'ton je vzdy zo znameho slovnika')
end

NxTest.test('KOV-G2 (6): handler odosle odpoved cez `js` a nikdy nespadne') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  NxKovG2.capture_js do |out|
    Noxun::Engine::Panel.handle_insert_legs_preview({ 'gen' => 3, 'type' => 'lower',
                                                      'width' => 900.0,
                                                      'floor_height' => 100.0 }.to_json)
    NxTest.assert_equal 1, out.length, 'prave jedna odpoved'
    NxTest.assert(out.first.start_with?('NX.insertLegsPreview('), 'svojim kanalom')
    NxTest.assert(out.first.include?('"gen":3'), 'a s generaciou dotazu')
  end
end

# --- 7) payload oznacenej skrinky ---------------------------------------------

NxTest.test('KOV-G2 (7): payload skrinky sklada riadok z UZ ROZPISANYCH poloziek') do
  body = NxKovG2.method_src('ui/panel/payloads.rb', 'cabinet_payload')
  NxTest.assert(body.include?("params['legs_summary'] = HardwareSets.legs_summary_from_purchase"),
                'riadok Noh a rozklik polozky v Kovani citaju TEN ISTY rozpis')
  NxTest.refute(body.include?('HardwareSets.legs_summary('),
                'druhy rozpis by premapoval katalog a mohol by sa rozist')
end

NxTest.test('KOV-G2 (7): rozpis z payloadu dava ten isty text ako priama cesta') do
  from_purchase = Noxun::Engine::HardwareSets.legs_summary_from_purchase(
    NxKovG2.decorated(width: 1200.0, fh: 100.0)
  )
  NxTest.assert_equal NxKovG2.summary(width: 1200.0, fh: 100.0), from_purchase,
                      'dve cesty, jedna veta'
end

NxTest.test('KOV-G2 (7): polozka BEZ rozpisu sa PRIZNA, nie zamlci') do
  item = { 'generic_type' => 'leg', 'quantity' => 4, 'rule_id' => 'r' }
  s = Noxun::Engine::HardwareSets.legs_summary_from_purchase([item])
  NxTest.assert_equal 'warn', s['tone'], 'skrinka nohy MA — „bez nôh" by klamalo'
  NxTest.assert_equal Noxun::Engine::HardwareSets::LEGS_NO_PURCHASE_SK, s['text']
end

# --- 8) ghost pasik ------------------------------------------------------------

NxTest.test('KOV-G2 (8): pasik SKRINKY nesie `legs_short` a `legs_tone`') do
  body = NxKovG2.method_src('core/ghost_tool.rb', 'state_payload')
  NxTest.assert(body.include?("out['legs_short']") && body.include?("out['legs_tone']"),
                'aditivne kluce (starsi panel ich ignoruje)')
  NxTest.assert(body.include?('legs = s.legs_summary'),
                'hodnotu drzi SESSION — pocita sa RAZ, nie pri kazdej sipke')
end

NxTest.test('KOV-G2 (8): pasik DOSKY o nohach nehovori') do
  body = NxKovG2.method_src('core/ghost_tool.rb', 'legs_summary_for')
  NxTest.assert(body.include?('s.cabinet?'), 'doska ani kreslenie nohy nemaju')
  NxTest.assert(body.include?("sum['tone'].to_s != 'none'"),
                'a „bez nôh" segment nekresli vobec (vertikalny priestor pasika)')
end

NxTest.test('KOV-G2 (8): suhrn pasika je LENIVY a drzi sa do konca session') do
  src = NxKovG2.src('core/ghost_tool.rb')
  NxTest.assert(src.include?('@legs_summary = :unset'), 'sentinel „este sa nepocitalo"')
  NxTest.assert(src.include?('@legs_summary = GhostTool.legs_summary_for(self) if @legs_summary == :unset'),
                'druhy push uz nesiaha na pravidla, sety ani katalog')
end

# --- 9) Codex #339 kolo 1 N1: KOVANIE ZO SABLONY V NAHLADE ---------------------
#
# Vkladacia karta so sablonou, ktora nesie vlastny set noh, ukazovala PROJEKTOVU
# predvolbu — a po kliku skrinka dostala set zo sablony. Nahlad sa preto pyta
# PROSPEKTIVNEHO stavu: projektovy snapshot + definicie, ktore v nom este nie su.

NxTest.test('KOV-G2 (9): prospektivny stav = projekt + sety, ktore v nom este nie su') do
  st = NxKovG2.state
  before = st['sets'].keys.length
  out = NxKovG2::HWS.state_with_template_sets(st, NxKovG2::TPL_MAP, [NxKovG2::TPL_SET])
  NxTest.assert(out['sets'].key?(NxKovG2::TPL_SET_ID), 'set zo sablony do stavu pribudol')
  NxTest.assert_equal before, st['sets'].keys.length,
                      'vstupny stav sa NEMUTUJE (cista funkcia)'
  NxTest.assert_equal st, NxKovG2::HWS.state_with_template_sets(st, NxKovG2::TPL_MAP, nil),
                      'bez definicii sa stav nemeni (vklad bez sablony)'
end

NxTest.test('KOV-G2 (9): PROJEKT vyhrava — sablona existujuci set neprepise') do
  st = NxKovG2.state
  sid = st['sets'].keys.first
  NxTest.assert(sid, 'PREMISA: kniznica ma aspon jeden set')
  mine = st['sets'][sid]
  fake = mine.merge('name' => 'Zo sablony')
  out = NxKovG2::HWS.state_with_template_sets(st, { mine['generic_type'] => sid }, [fake])
  NxTest.assert_equal mine, out['sets'][sid],
                      'prepis by zmenil UZ POSTAVENE skrinky zakazky (vzor freeze_template_sets!)'
end

NxTest.test('KOV-G2 (9): typovy nesulad sa do stavu nedostane') do
  st = NxKovG2.state
  bad = NxKovG2::TPL_SET.merge('generic_type' => 'hinge')
  out = NxKovG2::HWS.state_with_template_sets(st, NxKovG2::TPL_MAP, [bad])
  NxTest.refute(out['sets'].key?(NxKovG2::TPL_SET_ID),
                'definicia ineho typu sa nezmrazi ani pri vklade — nahlad musi hovorit to iste')
end

NxTest.test('KOV-G2 (9): nahlad ukaze SET ZO SABLONY, nie projektovu predvolbu') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  NxKovG2.with_read_state do
    cfg = NxKovG2::CB.normalize('type' => 'lower', 'width' => 1200.0, 'floor_height' => 100.0,
                                'hardware_sets' => NxKovG2::TPL_MAP)
    got = Noxun::Engine::Panel.legs_preview_summary(nil, cfg, set_defs: [NxKovG2::TPL_SET])
    NxTest.assert_equal NxKovG2::TPL_SET_ID, got['set_id'],
                        'karta a ghost musia slubit to, co skrinka po kliku naozaj dostane'
    NxTest.assert_equal 'ok', got['tone'], 'set je citatelny — ziadne upozornenie'
    NxTest.refute(got['text'].include?('AXILO H100'),
                  "sablona nohu MENI, projektova predvolba uz neplati: #{got['text']}")
    plain = Noxun::Engine::Panel.legs_preview_summary(nil, NxKovG2.cfg(width: 1200.0, fh: 100.0))
    NxTest.assert(plain['text'] != got['text'], 'a bez sablony ostava predvolba projektu')
  end
end

NxTest.test('KOV-G2 (9): mapovanie BEZ definicie neprepadne na predvolbu projektu') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  NxKovG2.with_read_state do
    cfg = NxKovG2::CB.normalize('type' => 'lower', 'width' => 1200.0, 'floor_height' => 100.0,
                                'hardware_sets' => NxKovG2::TPL_MAP)
    got = Noxun::Engine::Panel.legs_preview_summary(nil, cfg)
    NxTest.assert_equal 'warn', got['tone'],
                        'set, ktory projekt nema, je NALEZ — ticho ukazat cudzie nohy by klamalo'
  end
end

NxTest.test('KOV-G2 (9): brana kovania sablony je TA ISTA ako pri vklade') do
  hw = { 'hardware_sets' => NxKovG2::TPL_MAP, 'hardware_set_defs' => [NxKovG2::TPL_SET],
         'width' => 1200.0, 'zone_tree' => { 'x' => 1 } }
  map, defs = Noxun::Engine::Panel.insert_legs_template_hw(hw)
  NxTest.assert_equal NxKovG2::TPL_MAP, map, 'mapovanie prejde `read_template_mapping`'
  NxTest.assert_equal [NxKovG2::TPL_SET], defs, 'definicie prejdu `assess_set_defs`'
  NxTest.assert_equal [{}, nil], Noxun::Engine::Panel.insert_legs_template_hw({}),
                      'bez sablony sa nic nepodava'
  NxTest.assert_equal [{}, nil],
                      Noxun::Engine::Panel.insert_legs_template_hw('hardware_sets' => 'nezmysel'),
                      'necitatelne mapovanie vklad ODMIETNE — nahlad si z neho nic nevymysla'
  bad = Noxun::Engine::Panel.insert_legs_template_hw('hardware_sets' => NxKovG2::TPL_MAP,
                                                     'hardware_set_defs' => 'nezmysel')
  NxTest.assert_equal [NxKovG2::TPL_MAP, nil], bad, 'necitatelne definicie sa zahodia cele'
end

NxTest.test('KOV-G2 (9): callback nesie kovanie sablony az do vysledku') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  NxKovG2.with_sketchup do
    NxKovG2.with_read_state do
      res = Noxun::Engine::Panel.insert_legs_preview_result(
        'gen' => 9, 'type' => 'lower', 'width' => 1200.0, 'floor_height' => 100.0,
        'hardware_sets' => NxKovG2::TPL_MAP, 'hardware_set_defs' => [NxKovG2::TPL_SET],
        'material_id' => 'CUDZI-KLUC'
      )
      NxTest.assert_equal 9, res['gen'], 'generacia dotazu sa vracia nezmenena'
      NxTest.assert_equal NxKovG2::TPL_SET_ID, res['set_id'],
                          'set zo sablony sa dostal az do odpovede'
    end
  end
end

NxTest.test('KOV-G2 (9): pasik ghostu podava definicie setov zo SESSION') do
  body = NxKovG2.method_src('core/ghost_tool.rb', 'legs_summary_for')
  NxTest.assert(body.include?("set_defs: (hw.is_a?(Hash) ? hw['defs'] : nil)"),
                'definicie sa zmrazia az v commite — pasik ich musi podat sam')
end

# --- 10) Codex #339 kolo 1 N2/N4/N5: ZIVOTNY CYKLUS RIADKU A PASIKA -----------
#
# Riadok patri VYHRADNE dolnej skrinke (doskova karta ho resetuje), lahky push
# nesie jeho CERSTVU vetu a suhrn v pasiku je MEMO za session — sety, mapovanie,
# pravidla aj katalog sa daju zmenit v subezne otvorenom Studiu PRAVE POCAS nej
# a platia pre commit. Bez zneplatnenia by pasik tesne pred klikom slubil ine nohy.

NxTest.test('KOV-G2 (10): zmena mapovania POCAS session prepocita suhrn pasika') do
  NxTest.skip!('panelova cesta bezi len headless') unless NxTest.headless?
  gt = Noxun::Engine::GhostTool
  st = NxKovG2.state
  st['sets'] = st['sets'].merge(NxKovG2::TPL_SET_ID => NxKovG2::TPL_SET)
  NxKovG2.with_read_state(st) do
    cfg = NxKovG2.cfg(width: 1200.0, fh: 100.0)
    plan = Noxun::Engine::CabinetBuilder::InsertPlan.new(Object.new, cfg, 0.0)
    s = gt::PlacementSession.new(model: Object.new, plan: plan)
    first = gt.state_payload(s)['legs_short'].to_s
    NxTest.assert(!first.empty?, "PREMISA: pasik skrinky suhrn nesie (#{first})")
    # „Studio" zmeni projektovu predvolbu setu noh POCAS session.
    st['mapping'] = st['mapping'].merge('leg' => NxKovG2::TPL_SET_ID)
    NxTest.assert_equal first, gt.state_payload(s)['legs_short'].to_s,
                        'memo drzi — inak by kazda sipka siahla na pravidla, sety aj katalog'
    NxTest.assert(gt.invalidate_legs_summary!(s), 'hook zneplatnenia session pozna')
    after = gt.state_payload(s)['legs_short'].to_s
    NxTest.assert(after != first,
                  "po zneplatneni hovori pasik to, co skrinka po kliku dostane (#{after})")
  end
end

NxTest.test('KOV-G2 (10): zneplatnenie sa pyta SUBJEKTU a nikdy nespadne') do
  gt = Noxun::Engine::GhostTool
  NxTest.assert_equal false, gt.invalidate_legs_summary!(nil), 'bez session nie je co rusit'
  body = NxKovG2.method_src('core/ghost_tool.rb', 'invalidate_legs_summary!')
  NxTest.assert(body.include?('s.active?') && body.include?('s.cabinet?'),
                'doska ani ukoncena session suhrn noh nemaju')
  NxTest.assert(body.include?('push_state(s)'), 'pasik sa prekresli v tom istom kroku')
end

NxTest.test('KOV-G2 (10): hooky zneplatnenia stoja tam, kde sa o zmene uz vie') do
  sync = NxKovG2.method_src('ui/panel/sync.rb', 'push_hardware_sets')
  NxTest.assert(sync.include?('GhostTool.invalidate_legs_summary!'),
                'sety, mapovanie a katalog chodia lahkym pushom')
  rules = NxKovG2.method_src('ui/rules_dialog.rb', 'after_model_write')
  NxTest.assert(rules.include?('GhostTool.invalidate_legs_summary!'),
                'pravidla kovania koncia TOUTO cestou (uz MIMO operacie prestavby)')
end

NxTest.test('KOV-G2 (10): lahky push nesie CERSTVY riadok Noh (N4)') do
  sync = NxKovG2.method_src('ui/panel/sync.rb', 'push_hardware_sets')
  NxTest.assert(sync.include?("'legs_summary' => HardwareSets.legs_summary_from_purchase(items)"),
                'inak by veta riadku drzala staru expanziu az do dalsieho oznacenia skrinky')
  NxTest.refute(sync.include?('HardwareSets.legs_summary('),
                'ziadny druhy rozpis — polozky uz maju kluc `purchase`')
end

NxTest.test('KOV-G2 (10): DOSKOVA vetva vkladacej karty riadok Noh RESETUJE (N2)') do
  body = NxKovG2.js_func_src('ui/js/form.js', 'materializeInsertBoardCard')
  NxTest.refute(body.empty?, 'PREMISA: telo `materializeInsertBoardCard` sa naslo')
  NxTest.assert(body.include?('nxLegsInsertReset()'),
                'bez neho ostal v doskovej karte visiet text NOH poslednej dolnej skrinky')
end
