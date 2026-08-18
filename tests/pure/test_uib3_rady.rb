# frozen_string_literal: true
# Testy UI-B3 (N6) — ROZMEROVE RADY (core/dim_series.rb).
#
# Kontrolovane invarianty:
#   1) predvolena sada je uplna (kazdy kluc ma rad) a hodnoty su cele mm,
#   2) normalizacia je tolerantna, ale prisna: nezmysel a hodnoty mimo rozsahu
#      vypadnu, duplicity zaniknu, poradie je vzostupne, pocet je zastropovany,
#   3) PRAZDNY rad je platny vysledok (pouzivatel smie rad vypnut), ale
#      CHYBAJUCI kluc padne na default (vzor Engine.get_ui_theme),
#   4) chybajuci aj POSKODENY subor = predvolena sada (nikdy vynimka),
#   5) rady ziju v %APPDATA%\NOXUN\Engine\dim_series.json — NIKDY v modeli.
require_relative '../helper' unless defined?(NxTest)

UIB3 = Noxun::Engine::DimSeries

def uib3_reset_file!
  NxTest.skip!('katalogove/APPDATA testy bezia len headless') unless NxTest.headless?
  FileUtils.rm_f(UIB3.path)
  FileUtils.rm_f("#{UIB3.path}.bak")
  Noxun::Engine::JsonFileStore.invalidate(UIB3.path)
end

# --- 1) predvolena sada -------------------------------------------------------

NxTest.test('UI-B3: predvolena sada ma rad pre KAZDY kluc a same cele mm') do
  UIB3::KEYS.each do |key|
    list = UIB3::DEFAULTS[key]
    NxTest.assert(list.is_a?(Array) && !list.empty?, "kluc #{key} nema predvoleny rad")
    NxTest.assert(list.all? { |v| v.is_a?(Integer) && v.positive? }, "kluc #{key}: hodnoty musia byt cele mm")
    NxTest.assert_equal(list.sort, list, "kluc #{key}: predvoleny rad musi byt vzostupny")
  end
end

NxTest.test('UI-B3: schvalene predvolby z kontraktu UI 2.0') do
  NxTest.assert_equal([400, 450, 500, 600, 800, 900], UIB3::DEFAULTS['sirka'])
  NxTest.assert_equal([720, 820, 900], UIB3::DEFAULTS['vyska'])
  NxTest.assert_equal([320, 510, 560], UIB3::DEFAULTS['hlbka'])
  NxTest.assert_equal([100, 120, 150], UIB3::DEFAULTS['sokel'])
  # vyskovy rad ciel pouzije az UI-C3 — v subore je uz teraz (ziadna migracia)
  NxTest.assert_equal([140, 180, 280, 356], UIB3::DEFAULTS['vyska_cela'])
end

# --- 2) normalizacia ----------------------------------------------------------

NxTest.test('UI-B3: rad sa cisti — nezmysel von, duplicity prec, vzostupne') do
  out = UIB3.normalize_list([600, '450', 600.4, 'x', nil, true, 400, '', 450])
  NxTest.assert_equal([400, 450, 600], out)
end

NxTest.test('UI-B3: hodnoty mimo rozsahu sa ZAHADZUJU (nie orezavaju na hranicu)') do
  # Orezanie -50 na 10 by do ponuky vlozilo cislo, ktore pouzivatel nenapisal.
  NxTest.assert_equal([10, 3000], UIB3.normalize_list([0, -50, 9, 10, 3000, 3001, 999_999]))
end

NxTest.test('UI-B3: rad su CELE mm — desatinna bodka sa zaokruhli, ciarka je ODDELOVAC') do
  NxTest.assert_equal([451, 600], UIB3.normalize_list(['450.6', '600.2']))
  # Ciarka sa v hodnote NESMIE brat ako desatinna — v editore oddeluje hodnoty,
  # takze „450,6" by inak dalo 4506 alebo 450.6 podla nalady parsera.
  NxTest.assert_equal([], UIB3.normalize_list(['450,6']))
end

NxTest.test('UI-B3: rad je zastropovany poctom (dlhsia ponuka sa neda prehliadnut)') do
  many = (1..(UIB3::MAX_VALUES + 15)).map { |i| i * 10 }
  NxTest.assert_equal(UIB3::MAX_VALUES, UIB3.normalize_list(many).size)
end

NxTest.test('UI-B3: PRAZDNY rad je platny (rad sa da vypnut), NEPOLE padne na default') do
  NxTest.assert_equal([], UIB3.normalize_list([]))
  NxTest.assert_equal([], UIB3.normalize_list(%w[x y]), 'same nezmysly = prazdny rad')
  NxTest.assert_equal(nil, UIB3.normalize_list('600, 800'), 'retazec NIE JE rad')
  full = UIB3.normalize('sirka' => [500])
  NxTest.assert_equal([500], full['sirka'])
  NxTest.assert_equal(UIB3::DEFAULTS['vyska'], full['vyska'], 'chybajuci kluc = predvolba')
end

NxTest.test('UI-B3: neznamy kluc sa do vysledku nedostane') do
  out = UIB3.normalize('sirka' => [600], 'hlupost' => [1, 2])
  NxTest.assert_equal(UIB3::KEYS.sort, out.keys.sort)
end

# --- 3) perzistencia ----------------------------------------------------------

NxTest.test('UI-B3: bez suboru = predvolena sada') do
  uib3_reset_file!
  NxTest.assert_equal(UIB3.normalize(nil), UIB3.get)
end

NxTest.test('UI-B3: zapis a citanie — ulozi sa NORMALIZOVANA hodnota') do
  uib3_reset_file!
  stored = UIB3.set('sirka' => ['800', 600, 600, 'nic'], 'vyska' => [2000])
  NxTest.assert_equal([600, 800], stored['sirka'])
  NxTest.assert_equal([600, 800], UIB3.get['sirka'], 'po zapise sa cita to iste')
  NxTest.assert_equal([2000], UIB3.get['vyska'])
  NxTest.assert_equal(UIB3::DEFAULTS['hlbka'], UIB3.get['hlbka'], 'neposlany kluc ostal na predvolbe')
end

NxTest.test('UI-B3: zlyhanie zapisu vrati NIL — uspech sa nesmie hlasit falosne') do
  NxTest.skip!('katalogove/APPDATA testy bezia len headless') unless NxTest.headless?
  # Zapis do cesty, ktora sa neda vytvorit (existujuci SUBOR na mieste zlozky).
  blocker = File.join(Dir.mktmpdir('noxun-dimser-'), 'blok')
  File.binwrite(blocker, 'x')
  original = UIB3.method(:path)
  begin
    UIB3.define_singleton_method(:path) { File.join(blocker, 'dim_series.json') }
    NxTest.assert_equal(nil, UIB3.set('sirka' => [600]))
  ensure
    UIB3.define_singleton_method(:path, original)
  end
  NxTest.assert(UIB3.path.end_with?('dim_series.json'), 'povodna cesta sa vratila')
end

NxTest.test('UI-B3: poskodeny subor nezhodi panel — vrati predvolby') do
  uib3_reset_file!
  FileUtils.mkdir_p(UIB3.dir)
  File.binwrite(UIB3.path, '{ toto nie je JSON')
  Noxun::Engine::JsonFileStore.invalidate(UIB3.path)
  NxTest.assert_equal(UIB3.normalize(nil), UIB3.get)
end

NxTest.test('UI-B3: subor nesie verziu formatu a zije v %APPDATA%, nie v modeli') do
  uib3_reset_file!
  UIB3.set('sokel' => [100])
  raw = JSON.parse(File.binread(UIB3.path))
  NxTest.assert_equal(UIB3::STD, raw['std'])
  NxTest.assert(raw['series'].is_a?(Hash), 'rady su pod klucom series')
  NxTest.assert(UIB3.path.include?('NOXUN'), "cesta musi byt v NOXUN zlozke: #{UIB3.path}")
  NxTest.assert_equal('dim_series.json', File.basename(UIB3.path))
end

# --- 4) zdrojove guardy (zrkadlo Ruby <-> JS, ziadny zapis do modelu) ---------

NxTest.test('UI-B3 guard: JS zrkadlo radov ma rovnake predvolby aj limity') do
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'settings.js'), encoding: 'UTF-8')
  UIB3::DEFAULTS.each do |key, list|
    NxTest.assert(js.include?("#{key}: [#{list.join(', ')}]"),
                  "settings.js nema rovnaky predvoleny rad pre #{key}")
  end
  NxTest.assert(js.include?("MAX_VALUES = #{UIB3::MAX_VALUES}"), 'JS ma iny strop poctu hodnot')
  NxTest.assert(js.include?("MIN_MM = #{UIB3::MIN_MM}"), 'JS ma inu spodnu hranicu hodnot')
  NxTest.assert(js.include?("MAX_MM = #{UIB3::MAX_MM}"), 'JS ma iny rozsah hodnot')
end

NxTest.test('UI-B3 guard: nastavenia Inspectora nesiahaju na model') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_settings.rb'), encoding: 'UTF-8')
  NxTest.refute(src.include?('start_operation'), 'nastavenia pocitaca NIKDY neotvaraju operaciu')
  NxTest.refute(src.include?('Store.'), 'nastavenia pocitaca nezapisuju do NOXUN dictionary')
end

NxTest.test('UI-B3: sablona sa neulozi z CUDZIEHO dokumentu ani s cudzim typom') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates.rb'), encoding: 'UTF-8')
  body = src[/def handle_save_template_as.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'handler handle_save_template_as sa nenasiel')
  # ID skriniek sa naprie dokumentmi OPAKUJU — modal otvoreny nad jednym
  # dokumentom by po prepnuti ulozil skrinku z ineho (Codex audit BLOCKER 2).
  NxTest.assert(body.include?("data['model_guid'].to_s != model_guid(model)"),
                'chyba PRISNY guard dokumentu')
  # Typ je jedina vec, ktoru modal nastavuje — whitelist patri na server.
  NxTest.assert(src.include?("%w[lower upper].include?(want)"), 'typ sablony musi prejst whitelistom')
end

NxTest.test('UI-B3 guard: vyber dielcov je citanie + vyber pod suspend guardom') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'), encoding: 'UTF-8')
  body = src[/def handle_select_parts.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'handler handle_select_parts sa nenasiel')
  NxTest.refute(body.include?('start_operation'), 'oznacenie dielcov NESMIE otvorit operaciu (ziadny krok Spat)')
  NxTest.assert(body.include?('suspend_selection_sync'), 'zmena vyberu musi bezat pod suspend guardom')
  NxTest.assert(body.include?('model_guid'), 'asynchronny callback musi niest identitu dokumentu')
  NxTest.assert(body.include?('dedup: false'), 'refresh po vybere nesmie dedupovat (dedup MENI model)')
  # Codex #170 P1: server mohol flushnuty apply ODMIETNUT (material_preflight) —
  # vtedy sa vyber nevykona a zopakuje sa PRAVA pricina, nie hlaska o uspechu.
  NxTest.assert(body.include?('@last_apply_error'), 'chyba osetrenie odmietnuteho apply pred vyberom')
  cab = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'), encoding: 'UTF-8')
  NxTest.assert(cab.include?('@last_apply_error = pf[:error]'), 'odmietnuty apply sa musi zapamatat')
  NxTest.assert(cab.include?('@last_apply_error = nil'), 'uspesny apply musi priznak zmazat')
end

NxTest.test('UI-B3: informacny stlpec rata TIE ISTE dielce ako kusovnik (aj odpojene)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers.rb'), encoding: 'UTF-8')
  body = src[/def manufactured_parts.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'helper manufactured_parts sa nenasiel')
  # Bom.collect zbiera aj top-level `kind=part` (odpojeny/vytiahnuty dielec) —
  # bez toho by Inspector hlasil iny pocet nez kusovnik TEJ ISTEJ skrinky.
  NxTest.assert(body.include?('cab.definition.entities'), 'vnorene dielce sa musia ratat')
  NxTest.assert(body.include?('model.entities'), 'odpojene top-level dielce sa musia ratat tiez')
  NxTest.assert(body.include?("Store.get(e, 'cabinet_id').to_s == cid"), 'odpojeny dielec sa paruje cez cabinet_id')
end
