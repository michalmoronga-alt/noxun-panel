# frozen_string_literal: true
# ŠT-1c PR B2 — sekcia CENOVÁ PONUKA (Š14–Š15) + D-15 modal kostra.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. ZRKADLA whitelistu sekcii. Autoritou je RUBY (`StudioDialog::SECTIONS`);
#      `studio.js` aj `shell.js` maju vlastnu kopiu kvoli pohodliu — keby sa
#      rozisli, deep-link do novej sekcie by ticho vypadol uz v paneli.
#   2. KONTRAKT D-15 MODALU (audit #9). Komponent `js/nx_modal.js` spravuje LEN
#      modaly, ktore si ho vyziadaju. Fazove okno prepoctu cien (`#budPrModal`)
#      ho NEPREBERA — vo faze `run` sa Escapom zavriet NESMIE (beh by ostal
#      visiet bez okna). A Escape Studia (ecMenu) MUSI byt podmieneny „ziadny
#      modal otvoreny": oba listenery visia na `document` a `stopPropagation`
#      medzi nimi nefunguje.
#   3. Odmietnuty zapis (audit #10) modal NEZATVARA — zatvara ho VYHRADNE
#      `budgetResult(op, true)`.
#   4. PRESUN, NIE KOPIA — nahlad cenovej ponuky zmizol z tela Rozpoctu (ostal
#      po nom tenky preklik) a jej export sa presunul do listy sekcie `offer`.
#   5. Poradie skriptov: `nx_modal.js` PRED `studio.js` aj `budget.js`.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?

S1C2_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
S1C2_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
S1C2_BUDGET_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'),
                           encoding: 'UTF-8')
S1C2_MODAL_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'nx_modal.js'),
                           encoding: 'UTF-8')
S1C2_SHELL_JS  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'),
                           encoding: 'UTF-8')
S1C2_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# --- 1) `offer` je SEKCIA a jej zrkadla sedia --------------------------------

NxTest.test('ŠT-1c B2: `offer` je SEKCIA Studia — zrkadla whitelistu sedia vo VSETKYCH TROCH') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = S1C2_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = S1C2_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert_equal(%w[bom ctrl buy budget offer], rb, 'Ruby je autorita zoznamu')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell, 'a shell.js (panel) tiez')
end

NxTest.test('ŠT-1c B2: navigacia vedie na ZIVU sekciu — klientsky `goto` zanikol') do
  nav = S1C2_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  NxTest.refute(nav.empty?, 'navigacia sa nasla')
  NxTest.assert(nav.include?("{ id: 'offer',  ic: 'file-text',       t: 'Cenová ponuka' }"),
                'polozka je ZIVA sekcia (ziadny `goto`, ziadne premostenie)')
  NxTest.refute(nav.include?('goto:'), 'preklik do CASTI inej sekcie uz v navigacii nie je')
  NxTest.refute(S1C2_STUDIO_JS.include?('it.goto'),
                'a ani jeho vetva v `onNav` (mrtvy kod by prezil davku)')
  NxTest.assert(S1C2_STUDIO_JS.include?("offer: { t: 'Cenová ponuka',"),
                'sekcia ma vlastnu hlavicku a hint')
  NxTest.assert(S1C2_STUDIO_JS.include?("offer: 'Prepočítavam cenovú ponuku…'"),
                'a vlastny text pri Obnovit (inak by hlasila kusovnik)')
end

# --- 2) presun, nie kopia ----------------------------------------------------

NxTest.test('ŠT-1c B2: nahlad CP sa PRESUNUL — v tele Rozpoctu ostal len preklik') do
  NxTest.refute(S1C2_BUDGET_JS.include?('Cenová ponuka — náhľad'),
                'zbalitelny nahlad vnutri Rozpoctu zanikol (ziadna druha kopia tabulky)')
  NxTest.assert(S1C2_BUDGET_JS.include?('function budCpLinkHtml'),
                'ostal po nom TENKY preklik do sekcie Ponuka')
  NxTest.assert(S1C2_BUDGET_JS.include?('function budOfferHtml'), 'telo sekcie Ponuka existuje')
  NxTest.assert(S1C2_BUDGET_JS.include?('function budOfferToolsHtml'), 'a jej lista tiez')
  # Export cenovej ponuky patri sekcii, ktora dokument vyraba (kontrakt §3).
  tools = S1C2_BUDGET_JS[/function budToolsHtml\(b\)\{.*?\n  \}/m].to_s
  NxTest.refute(tools.empty?, 'lista Rozpoctu sa nasla')
  NxTest.refute(tools.include?('data-bud="cp"'),
                'export cenovej ponuky uz v liste Rozpoctu NIE JE')
  otools = S1C2_BUDGET_JS[/function budOfferToolsHtml\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(otools.include?('data-bud="cp"'), 'zato v liste sekcie Ponuka ano')
  NxTest.refute(otools.include?('data-bud="vat"'),
                'prepinac DPH sa NEZDVOJIL (dve miesta by ukazovali iny stav)')
  NxTest.assert(otools.include?('id="refreshBtn"'),
                'sekcia ma vlastnu cestu k cerstvym cislam (ponuka zo starych rozmerov = chyba)')
end

NxTest.test('ŠT-1c B2 (Š14): ponuka nesie per-riadok „samostatne" aj priznany placeholder') do
  NxTest.assert(S1C2_BUDGET_JS.include?("data-bud=\"cp_sep\""),
                'per-riadok prepinac „samostatne" existuje')
  # Je to TA ISTA mutacia, aku mala sipka v nahlade — 1 zmena = 1 krok Spat.
  NxTest.assert(S1C2_BUDGET_JS.include?("budSend('cp_group', { source_key: t.getAttribute('data-source'),"),
                'a posiela `cp_group` (ziadna nova serverova cesta)')
  NxTest.assert(S1C2_BUDGET_JS.include?('function budOfferWireHtml'),
                'DOCX/PDF je PRIZNANY wireframe (D-78: ziadne mrtve tlacidlo bez dovodu)')
  NxTest.assert(S1C2_BUDGET_JS.include?('po V1 — vedomý placeholder'), 'a povie, ze pride po V1')
  # Š15: chybajuca cena sa doplna PRI ZDROJI — v Rozpocte, nie v ponuke.
  NxTest.assert(S1C2_BUDGET_JS.include?("data-bud=\"to_budget\""),
                'jantarovy guard podhodnotenej ponuky VEDIE do Rozpoctu')
end

# --- 3) D-15 modal: kontrakt (audit #9 + #10) --------------------------------

NxTest.test('ŠT-1c B2 (audit #9): `#budPrModal` zdielanu kostru NEPREBERA') do
  pr = S1C2_BUDGET_JS[/function budPrModalHtml.*?function budPrStart/m].to_s
  NxTest.refute(pr.empty?, 'fazove okno prepoctu cien sa naslo')
  NxTest.refute(pr.include?('NXModal'),
                'kresli si vlastny markup — vo faze `run` sa Escapom zavriet NESMIE')
  # Komponent ho SMIE spomenut (kontrakt musi byt napisany nahlas), ale nesmie
  # sa ho dotknut: kazdy jeho vyskyt v subore je KOMENTAR.
  touching = S1C2_MODAL_JS.lines.select { |l| l.include?('budPrModal') }
                          .reject { |l| l.strip.start_with?('//') }
  NxTest.assert_equal([], touching, 'komponent sa `#budPrModal` nikde nedotyka')
end

NxTest.test('ŠT-1c B2 (audit #9): Escape Studia sa podmienuje otvorenym modalom') do
  NxTest.assert(S1C2_STUDIO_JS.include?("ev.key === 'Escape' && ecMenuOpen && !nxModalOpen()"),
                'Escape zatvara `ecMenu` LEN vtedy, ked nezije D-15 modal')
  NxTest.assert(S1C2_STUDIO_JS.include?('function nxModalOpen'),
                'a otazka ma jedno miesto (nie tri kopie podmienky)')
  NxTest.assert(S1C2_MODAL_JS.include?("if (ev.key === 'Escape'){ close(); return; }"),
                'komponent si Escape rieši sam — kazdy vo svojom listeneri')
end

NxTest.test('ŠT-1c B2 (audit #10): odmietnuty zapis modal NEZATVARA') do
  res = S1C2_BUDGET_JS[/NX\.budgetResult = function.*?\n    \};/m].to_s
  NxTest.refute(res.empty?, 'prijimac vysledku mutacie sa nasiel')
  NxTest.assert(res.include?('if (ok) budCloseDraft();'),
                'modal zatvara VYHRADNE potvrdeny zapis')
  NxTest.refute(res.include?('BUD_DRAFT = null;'),
                'ziadne tiche vynulovanie hodnot mimo `budCloseDraft`')
  # Komponent zatvorenie po odoslani NEROBI — je to rozhodnutie volajuceho.
  submit = S1C2_MODAL_JS[/function submit\(\)\{.*?\n    \}/m].to_s
  NxTest.refute(submit.include?('close()'),
                'odoslanie modal nezatvara — server ho moze odmietnut')
end

NxTest.test('ŠT-1c B2: D-15 kostra je ZDIELANY komponent (vzor edge_menu.js)') do
  NxTest.assert(S1C2_MODAL_JS.include?('global.NXModal = API;'),
                'komponent sa registruje globalne — ako NXEdgeMenu')
  NxTest.assert(S1C2_MODAL_JS.include?('module.exports = API'), 'a da sa testovat aj v Node')
  %w[mhead mbody mfoot nxscrim].each do |cls|
    NxTest.assert(S1C2_MODAL_JS.include?("class=\"#{cls}\"") || S1C2_MODAL_JS.include?("\"#{cls}"),
                  "kostra nesie cast `#{cls}` (mockup)")
    NxTest.assert(S1C2_STUDIO_HTML.include?(".#{cls} "),
                  "a ma k nej styl v studio.html")
  end
  # Kolizia mien: `panel.css` uz `.nxmodal` pouziva pre SCRIM starsich modalov.
  NxTest.assert(S1C2_MODAL_JS.include?('class="nxmcard'),
                'karta sa vola `.nxmcard` — `.nxmodal` je v panel.css uz obsadene')
  # Kotva modalu zije MIMO tela sekcie — prekreslenie rozpoctu ju nezhodi.
  NxTest.assert(S1C2_STUDIO_HTML.include?('<div id="nxModalRoot"></div>'),
                'okno ma kotvu modalov mimo `#secbody`')
end

NxTest.test('ŠT-1c B2: poradie skriptov — nx_modal.js PRED studio.js aj budget.js') do
  modal_at = S1C2_STUDIO_HTML.index('js/nx_modal.js')
  studio_at = S1C2_STUDIO_HTML.index('js/studio.js')
  budget_at = S1C2_STUDIO_HTML.index('js/budget.js')
  NxTest.assert(!modal_at.nil?, 'komponent je v studio.html')
  NxTest.assert(modal_at < studio_at, 'pred studio.js (Escape handler sa ho pyta)')
  NxTest.assert(modal_at < budget_at, 'aj pred budget.js (otvara nim pridavacky)')
end

# --- 4) inline draft zanikol -------------------------------------------------

NxTest.test('ŠT-1c B2 (Š13): inline draft v tele sekcie ZANIKOL') do
  %w[budDraftHtml budTypeless bud_dpopis bud_dtyp draft_ok draft_cancel].each do |dead|
    NxTest.refute(S1C2_BUDGET_JS.include?(dead),
                  "zvysok inline draftu `#{dead}` uz v kode nie je")
  end
  NxTest.assert(S1C2_BUDGET_JS.include?('function budDraftFields'),
                'polia draftu su CISTA funkcia (kostru kresli komponent)')
  NxTest.assert(S1C2_BUDGET_JS.include?('function budOpenDraft'), 'a otvara ich jedno miesto')
  # Validacia ostava serverova — klient strazi LEN povinne pole.
  NxTest.assert(S1C2_BUDGET_JS.include?('function budDraftMissing'),
                'povinne pole si klient overi (aby zbytocne nechodil do Ruby)')
end

# --- 5) relay retaz exportu cenovej ponuky (review #7) -----------------------

NxTest.test('ŠT-1c B2 (review #7): oba XLSX handlery beru payload TOLERANTNE') do
  %w[handle_budget_xlsx handle_cp_xlsx].each do |m|
    body = S1C2_STUDIO_RB[/def #{m}\(payload\).*?\n        end\n/m].to_s
    NxTest.refute(body.empty?, "#{m} sa nasiel")
    NxTest.assert(body.include?('payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)'),
                  "#{m}: Hash aj JSON retazec (vetva bez panela odovzdava uz Hash)")
  end
  # Relay vetva musi ist do TOHTO okna — cudzi push by mu klik odmietol.
  NxTest.assert(S1C2_STUDIO_RB.include?('NX.studioRelayCp('), 'cenova ponuka ide vlastnym relayom')
  NxTest.assert(Noxun::Engine::StudioDialog.respond_to?(:do_cp_xlsx),
                'a telo je verejne (vola ho relay z panela)')
end
