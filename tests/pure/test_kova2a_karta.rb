# frozen_string_literal: true
# KOV-A2a — KARTA CELA: serverova projekcia `front_slots` + zdrojove guardy UI.
#
# CO SA OVERUJE
#   1) `Panel.front_slots_payload` je CISTA projekcia nad ulozenym
#      `front_items`: mapa `front_id -> [{ wing, part_key, state }]` z JEDINEJ
#      definicie aplikovatelnosti smeru (`Fronts.direction_slots`, KOV-A1).
#      Server je tym AUTORITA na otazku „kde sa smer pyta" — panel si ju
#      z poctu kridiel neodvodzuje. LEGACY zaznam (bez `wings_n`) da PRAZDNE
#      pole, takze stara zakazka nikdy nedostane smerovy riadok.
#   2) `state` prechadza NEZMENENY: nil = legacy (kluc v configu nie je),
#      'unset' = vedome neurcene, 'left'/'right' = vyriesene. Payload NIC
#      nedopĺňa — inak by legacy zakazka dostala RED nalez.
#   3) Zdrojove guardy UI: rozbalovacka typu zanikla, karta ma vsetkych sest
#      dlazdic, sprite ma nove symboly, CSS karty pouziva VYHRADNE tokeny
#      `--nx-*` a je scopnute (v paneli uz ziju ine `.segrow` a `.inforow`),
#      nahlad vyberá symbol cez ciste funkcie core.js (ziadne odvodzovanie
#      strany zo `wings`).
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `front_slots_payload` doplni `state` na 'unset', ked v polozke chyba.
#   2. `front_slots_payload` cita surove `wings` namiesto `wings_n`.
#   3. `frontCardModel` kresli smerovy riadok aj bez slotov (odvodi si ho).
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva) — rovnaky
# vzor ako R-12 / KOV-A1 sada.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxKovA2a
  E = Noxun::Engine
  UI = File.join(NxTest::ROOT, 'noxun_engine', 'ui')

  module_function

  def src(rel)
    File.read(File.join(UI, rel), encoding: 'UTF-8')
  end

  # RESOLVED polozka cela tak, ako ju uklada `Fronts.layout` do `front_items`.
  def item(overrides = {})
    { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => 300.0,
      'wings' => 'auto', 'wings_n' => 1, 'profile' => 'none' }.merge(overrides)
  end
end

module NxTest
  A2 = NxKovA2a

  # ==================== 1) `front_slots` payload ============================

  test('KOV-A2a: 1 kridlo ma slot `single` s NEZMENENYM stavom') do
    { nil => nil, 'unset' => 'unset', 'left' => 'left', 'right' => 'right' }.each do |stored, want|
      it = stored.nil? ? A2.item : A2.item('direction' => stored)
      out = A2::E::Panel.front_slots_payload([it])
      assert_equal(['F1'], out.keys, 'kluc mapy je ID cela')
      assert_equal([{ 'wing' => 'single', 'part_key' => 'front:F1/wing:single', 'state' => want }],
                   out['F1'], "stav #{stored.inspect} prejde payloadom nezmeneny")
    end
  end

  test('KOV-A2a: dvojkridlo sa na smer NEPYTA (krajne kridla su odvodene)') do
    out = A2::E::Panel.front_slots_payload([A2.item('wings_n' => 2, 'direction' => 'left')])
    assert_equal([], out['F1'], 'prazdne pole = „tu sa otazka nekladie"')
  end

  test('KOV-A2a: 3 a 4 kridla maju sloty len na STREDNE kridla') do
    out3 = A2::E::Panel.front_slots_payload(
      [A2.item('wings_n' => 3, 'wing_directions' => { 'p2' => 'unset' })]
    )
    assert_equal([{ 'wing' => 'p2', 'part_key' => 'front:F1/wing:p2', 'state' => 'unset' }], out3['F1'])
    out4 = A2::E::Panel.front_slots_payload(
      [A2.item('wings_n' => 4, 'wing_directions' => { 'p3' => 'right' })]
    )
    assert_equal([{ 'wing' => 'p2', 'part_key' => 'front:F1/wing:p2', 'state' => nil },
                  { 'wing' => 'p3', 'part_key' => 'front:F1/wing:p3', 'state' => 'right' }],
                 out4['F1'], 'neurcene stredne kridlo si NIC nedomysli')
  end

  test('KOV-A2a: efektivny pocet kridiel rozhoduje, nie surove `wings`') do
    # Auto nad 600 mm da dve kridla — payload musi ist z `wings_n` (co plati),
    # nie z `wings` ('auto'). Inak by sa dvojkridlo pytalo na stranu pantov.
    out = A2::E::Panel.front_slots_payload([A2.item('wings' => 'auto', 'wings_n' => 2)])
    assert_equal([], out['F1'])
    out1 = A2::E::Panel.front_slots_payload([A2.item('wings' => '2', 'wings_n' => 1)])
    assert_equal(['single'], out1['F1'].map { |s| s['wing'] },
                 'surove `wings` sa NECITA — plati efektivny pocet z planu')
  end

  test('KOV-A2a: ne-dvierka nemaju sloty ZIADNE') do
    %w[drawer_front lift fall blind none].each do |t|
      out = A2::E::Panel.front_slots_payload([A2.item('type' => t, 'direction' => 'left')])
      assert_equal([], out['F1'], "#{t} sa na stranu pantov nepyta")
    end
  end

  test('KOV-A2a: LEGACY `front_items` (pred D-07, bez `wings_n`) da prazdne sloty') do
    legacy = { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => 300.0, 'wings' => '1' }
    assert_equal([], A2::E::Panel.front_slots_payload([legacy])['F1'],
                 'stara zakazka nedostane smerovy riadok z tejto cesty')
  end

  test('KOV-A2a: payload je ODOLNY a NIC nezapisuje') do
    assert_equal({}, A2::E::Panel.front_slots_payload(nil), 'chybajuce cela = prazdna mapa')
    assert_equal({}, A2::E::Panel.front_slots_payload([]), 'ziadne cela = prazdna mapa')
    assert_equal({}, A2::E::Panel.front_slots_payload(['nezmysel', nil]), 'poskodeny zaznam sa preskoci')
    assert_equal({}, A2::E::Panel.front_slots_payload([{ 'type' => 'door', 'wings_n' => 1 }]),
                 'zaznam bez ID nema ako byt adresovany')
    src = A2.item
    frozen = src.dup
    A2::E::Panel.front_slots_payload([src])
    assert_equal(frozen, src, 'vstupna polozka ostava NEDOTKNUTA')
  end

  test('KOV-A2a: viac ciel = mapa podla ID (poradie zoznamu sa nepouziva)') do
    out = A2::E::Panel.front_slots_payload(
      [A2.item('id' => 'F1', 'type' => 'drawer_front'),
       A2.item('id' => 'F2', 'wings_n' => 1, 'direction' => 'unset')]
    )
    assert_equal(%w[F1 F2], out.keys.sort)
    assert_equal([], out['F1'])
    assert_equal('unset', out['F2'].first['state'])
  end

  test('KOV-A2a: `cabinet_payload` posiela `front_slots` vedla `front_items`') do
    s = File.read(File.join(A2::UI, 'panel', 'payloads.rb'), encoding: 'UTF-8')
    assert(s.include?("params['front_slots'] = front_slots_payload(cfg['front_items'])"),
           'sloty sa pocitaju z TEJ ISTEJ cache, ktoru cita nahlad')
    assert(s.include?('Fronts.direction_slots(it)'),
           'a VYHRADNE cez jedinu definiciu aplikovatelnosti (KOV-A1)')
  end

  # ==================== 2) zdrojove guardy UI ===============================

  test('KOV-A2a GUARD: rozbalovacka typu zanikla, typ zije v datasete riadku') do
    f = A2.src('js/form.js')
    refute(f.include?('class="ftype"'), 'select typu uz v riadku nie je')
    refute(f.include?(".querySelector('.ftype')"), 'a nikto ho uz necita')
    assert(f.include?("row.dataset.frontType = item.type || 'door';"),
           'typ zije v datasete (vzor D-90 `profile`)')
    assert(f.include?("var type = r.dataset.frontType || 'door';"),
           'collectFronts ho cita odtial')
    assert(f.include?('class="ftname"'), 'jeho miesto zabralo tlacidlo karty')
    assert(f.include?('aria-expanded'), 'stav karty nesie aria-expanded')
  end

  test('KOV-A2a GUARD: karta zije v `.frow` a je NAJVIAC JEDNA') do
    f = A2.src('js/form.js')
    assert(f.include?('var openFrontCardId = null;'),
           'otvorena karta sa drzi cez IDENTITU cela, nie cez index riadku')
    assert(f.include?("openFrontCardId = (openFrontCardId === fid) ? null : fid;"),
           'opatovny klik kartu zbali')
    assert(f.include?('if (openFrontCardId && !frontRowById(openFrontCardId)) openFrontCardId = null;'),
           'po prestavbe riadkov sa stav ocisti (celo uz v zozname byt nemusi)')
    refute(f.include?('cardEl.style.display'), 'karta sa NEskryva CSS-kom, naozaj zanika')
  end

  test('KOV-A2a GUARD: „neurcene" vyraba VYHRADNE core.js') do
    c = A2.src('js/core.js')
    assert(c.include?("var FRONT_DIR_UNSET = 'unset';"), 'jediny literal v klientskom kode')
    %w[frontExtraOnTypeChange frontExtraOnWings frontExtraOnSegrow].each do |fn|
      assert(c.include?("function #{fn}("), "vyrobca #{fn} zije v core.js")
    end
    f = A2.src('js/form.js')
    %w[frontExtraOnTypeChange(frontExtraOf(row) frontExtraOnWings(frontExtraOf(row)
       frontExtraOnSegrow(frontExtraOf(row)].each do |call|
      assert(f.include?(call), "form.js meni dormant polia cez #{call}…, nie sam")
    end
    # Kazda zmena ide POVODNOU cestou — ziadny novy callback servera.
    %w[onFrontTile onFrontSeg onFrontWings].each do |h|
      body = f[/function #{h}\(.*?\n  \}/m].to_s
      refute(body.empty?, "#{h} sa nenasla")
      assert(body.include?('onField();'), "#{h} ide cez onField -> collectFronts -> apply_all")
      refute(body.include?('sketchup.'), "#{h} NEMA vlastny callback servera")
    end
  end

  test('KOV-A2a GUARD: nahlad vybera symbol cez ciste funkcie, stranu neodvodzuje') do
    p = A2.src('js/preview.js')
    assert(p.include?('frontWingSymbols(cols.length, frontSlotsFor(it.id))'),
           'symboly kridiel idu zo SLOTOV servera')
    assert(p.include?('var tsym = frontTypeSymbol(it.type);'), 'typy cez mapu, nie cez vetvy')
    refute(p.match?(/direction\s*===\s*'/), 'preview stav smeru vobec neinterpretuje')
    refute(p.match?(/['"]unset['"]/), 'a literal neurceneho stavu nepozna')
  end

  test('KOV-A2a GUARD: nove symboly su v sprite a v zozname UI_DIZAJN') do
    icons = A2.src('js/icons.js')
    doc = File.read(File.join(NxTest::ROOT, 'docs', 'UI_DIZAJN.md'), encoding: 'UTF-8')
    %w[front-lift front-fall front-blind dir-left dir-right dir-unset].each do |i|
      assert(icons.include?("'#{i}':"), "sprite nema ikonu '#{i}'")
      assert(doc.include?("`#{i}`"), "docs/UI_DIZAJN.md §4 nepozna ikonu '#{i}'")
    end
    # Vyklop/sklop/blenda uz NEMAJU fallback `front` (A1 provizorium).
    f = A2.src('js/form.js')
    assert(f.include?("lift: 'front-lift', fall: 'front-fall', blind: 'front-blind'"),
           'mapa typ -> ikona nesie vlastne symboly')
  end

  test('KOV-A2a GUARD: CSS karty pouziva VYHRADNE tokeny a je scopnute') do
    css = A2.src('css/panel.css').gsub(%r{/\*.*?\*/}m, ' ')
    rules = css.scan(/(^|\})\s*([^{}]+?)\s*\{([^{}]*)\}/m).select do |_pre, sel, _body|
      sel.include?('.fcard') || sel.include?('.ftname') || sel.include?('.fbadge')
    end
    assert(rules.length > 10, 'pravidla karty sa nasli')
    rules.each do |_pre, sel, body|
      refute(body.match?(/#[0-9a-fA-F]{3,8}\b/),
             "`#{sel.strip}` ma natvrdo zapisany hex — karta musi ist cez tokeny --nx-*")
    end
    # `.segrow` a `.inforow` v paneli UZ ZIJU s inym vzhladom — bez scopu by sa
    # dva vizualne jazyky bili.
    rules.each do |_pre, sel, _body|
      next unless sel.include?('.segrow') || sel.include?('.inforow') || sel.include?('.typetile')

      assert(sel.include?('.nx-inspector'), "`#{sel.strip}` musi byt scopnute pod .nx-inspector")
    end
  end
end
