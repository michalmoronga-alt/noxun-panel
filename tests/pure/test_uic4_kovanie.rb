# frozen_string_literal: true
# UI-C4 — KOVANIE: kontrakt kontextu Kovanie (boxy podla vlastnika + znacky nahladu).
#
# Co sa tu strazi (a preco to nestaci overit klikanim):
#   1) Kontext ma TRI skupiny v zavaznom poradi (Polozky · Sety · Pravidla) a
#      kostra je STATICKA — JS pise len obsah dvoch kontajnerov.
#   2) Hlavicka boxu je TLACIDLO a je SURODENEC tela boxu, nie jeho predok —
#      klik na select/zamok v boxe sa k nej preto nema ako dostat (silnejsie nez
#      stopPropagation, ktore by sa dalo zabudnut pri kazdom novom ovladaci).
#   3) Oznacenie vlastnika v modeli je CISTE CITANIE + zmena vyberu: ziadna
#      operacia, ziadny zapis, ziadny krok Spat (lekcia D-103) a PRISNY guard
#      dokumentu aj skrinky (callback HtmlDialogu je asynchronny).
#   4) Panel po oznaceni ZAMERNE NEPUSHA — box, z ktoreho sa klikalo, nesmie
#      pouzivatelovi zmiznut pod rukami (identita vyberu je autoritou rezimu).
#   5) Preklik „naviazané kovanie" z kontextu Cela (UI-C3) doskoci na BOX
#      vlastnika — kluc skupiny sklada JEDNA funkcia pre render aj pre skok.
require_relative '../helper' unless defined?(NxTest)

UIC4_PANEL_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
UIC4_HW_JS      = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
UIC4_FORM_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
UIC4_PREVIEW_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'preview.js'), encoding: 'UTF-8')
UIC4_BOOT_JS    = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'boot.js'), encoding: 'UTF-8')
UIC4_CSS        = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
UIC4_PANEL_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
UIC4_SEL_RB     = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'), encoding: 'UTF-8')

# Telo handlera oznacenia vlastnika — kontroly nizsie musia mierit PRESNE nan.
UIC4_HANDLER = UIC4_SEL_RB[/def handle_select_hw_owner.*?\n        end\n/m].to_s

# --- 1) kostra kontextu Kovanie ---------------------------------------------

NxTest.test('UI-C4: kontext Kovanie ma tri skupiny v zavaznom poradi') do
  keys = UIC4_PANEL_HTML.scan(/data-key="([a-z_]+)" data-s4="kovanie"/).flatten
  NxTest.assert_equal(%w[hwitems hwsets hwrules], keys,
                      'Položky -> Sety -> Pravidlá (poradie je kontrakt)')
end

NxTest.test('UI-C4: kostra je STATICKA — JS pise len obsah dvoch kontajnerov') do
  NxTest.assert(UIC4_PANEL_HTML.include?('id="hwRows"'), 'kontajner poloziek zije v HTML')
  NxTest.assert(UIC4_PANEL_HTML.include?('id="hwSetRows"'), 'kontajner setov zije v HTML')
  # Sety sa odstahovali z konca zoznamu poloziek do vlastnej skupiny — zivy push
  # (D-75) musi obnovovat selecty v OBOCH kontajneroch, inak by novy set typu
  # v skupine Sety ostal neviditelny az do dalsieho oznacenia skrinky.
  NxTest.assert(UIC4_HW_JS.include?("['hwRows', 'hwSetRows'].forEach"),
                'refreshHardwareSets obnovuje selecty v oboch kontajneroch')
end

# --- 2) box vlastnika --------------------------------------------------------

NxTest.test('UI-C4: hlavicka boxu je TLACIDLO a nesie part_key vlastnikov') do
  NxTest.assert(UIC4_HW_JS.include?('class="hwbox" data-group='),
                'box nesie kluc svojej skupiny (ciel skoku aj hoveru)')
  NxTest.assert(UIC4_HW_JS.include?('data-keys="'),
                'box nesie part_key vsetkych svojich vlastnikov — to oznaci klik')
  NxTest.assert(UIC4_HW_JS.include?('<button type="button" class="hwboxh"'),
                'hlavicka je nativne tlacidlo (klavesnica + citacka), nie div s role')
  NxTest.assert(UIC4_HW_JS.include?('onclick="onHwOwnerPick(this)"'), 'klik ma vlastnu cestu')
end

NxTest.test('UI-C4: klik na hlavicku ma FLUSH handshake (Codex #179 P2)') do
  # Rozpisany edit caka 400 ms. Keby timer dobehol AZ PO vybere, `handle_apply_all`
  # by skrinku prestaval a `finish_cab` by reselectol CELY korpus — vlastnik,
  # ktoreho pouzivatel prave klikol, by sa ticho stratil. Vzor `onInfoParts`.
  body = UIC4_HW_JS[/function onHwOwnerPick.*?\n  \}/m].to_s
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('flushCabinetEditsNow()'), 'rozpisany edit ide na server PRED vyberom')
  NxTest.assert(body.include?('!validateFields()'), 'neplatne pole akciu ZASTAVI (flush by ju neaplikoval)')
  NxTest.assert(body.index('!validateFields()') < body.index('nx_select_hw_owner'),
                'kontrola aj flush bezia PRED odoslanim vyberu')
end

NxTest.test('UI-C4: hlavicka je SURODENEC tela boxu — ovladace sa k nej nedostanu') do
  # Silnejsie nez stopPropagation: klik na select setu, zamok NL ci pole poctu
  # bubla k `.hwboxb`, a ten hlavicku NEOBSAHUJE. Ziadny buduci ovladac v boxe
  # preto nemusi na stopPropagation pamatat.
  tpl = UIC4_HW_JS[/return '<div class="hwbox".*?<\/div>';/m].to_s
  NxTest.assert(!tpl.empty?, 'sablona boxu sa nasla')
  NxTest.assert(tpl.include?('</button>') && tpl.include?('<div class="hwboxb">'),
                'hlavicka sa uzavrie PRED telom boxu')
  NxTest.assert(tpl.index('</button>') < tpl.index('<div class="hwboxb">'),
                'telo boxu nie je vnutri hlavicky (inak by klik na select spustil vyber)')
end

NxTest.test('UI-C4: trieda boxu je `.hwbox` — `.hwown` ostava popisom v RIADKU') do
  # Mockup pouzival `.hwown` pre box, lenze tou triedou je uz oznaceny popis
  # vlastnika vnutri riadku (V0.4). Dva vyznamy jednej triedy by sa poprali.
  NxTest.assert(UIC4_CSS.include?('.hwbox {'), 'box ma vlastnu triedu')
  NxTest.assert(UIC4_CSS.include?('.hwrow .hwown'), 'popis v riadku si `.hwown` ponechava')
  NxTest.refute(UIC4_CSS.match?(/^\s*\.hwown\s*[{,]/), 'ziadne globalne pravidlo `.hwown` (kolizia)')
end

# --- 3) oznacenie vlastnika v modeli ----------------------------------------

NxTest.test('UI-C4: oznacenie vlastnika je CISTE CITANIE — ziadna operacia, ziadny zapis') do
  NxTest.assert(!UIC4_HANDLER.empty?, 'handler existuje')
  NxTest.refute(UIC4_HANDLER.include?('start_operation'),
                'zmena vyberu nesmie otvorit operaciu (prazdny krok Spat — lekcia D-103)')
  NxTest.refute(UIC4_HANDLER.include?('set_attribute'), 'do modelu sa nic nezapisuje')
  NxTest.refute(UIC4_HANDLER.include?('request_dedup'), 'dedup MENI model — z UI akcie nikdy')
  NxTest.assert(UIC4_HANDLER.include?('suspend_selection_sync'),
                'nasa vlastna selekcia bezi pod suspend guardom')
  NxTest.assert(UIC4_PANEL_RB.include?("cb(dlg, 'nx_select_hw_owner')"), 'callback je zaregistrovany')
end

NxTest.test('UI-C4: guard dokumentu aj skrinky je PRISNY (callback je asynchronny)') do
  NxTest.assert(UIC4_HANDLER.include?("data['model_guid'].to_s != model_guid(model)"),
                'cudzi dokument sa odmietne (ID skriniek sa naprie dokumentmi opakuju)')
  NxTest.assert(UIC4_HANDLER.include?("Store.get(cab, 'cabinet_id').to_s != data['cabinet_id'].to_s"),
                'medzitym oznacena INA skrinka = panel sa len zosuladi')
  NxTest.assert(UIC4_HANDLER.include?('refresh_after_stale(model)'),
                'zastarany klik nic nepresuva')
end

NxTest.test('UI-C4: panel po oznaceni ZAMERNE nepusha (box nesmie zmiznut pod rukami)') do
  NxTest.refute(UIC4_HANDLER.include?('push_selected(model)'),
                'push by pri oznacenom DIELCI prepol panel na kartu Dielec')
  # Prazdne `part_keys` = box Skrinka: vtedy sa oznaci cely korpus (reselect si
  # suspend guard drzi sam) a panel je s vyberom aj tak v sulade.
  NxTest.assert(UIC4_HANDLER.include?('reselect(model, cab)'),
                'box Skrinka oznaci cely korpus existujucou cestou')
end

NxTest.test('UI-C4: dielce sa hladaju podla part_key v ROVNAKOM rozsahu ako kusovnik') do
  body = UIC4_SEL_RB[/def parts_by_keys.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'pomocna funkcia existuje')
  NxTest.assert(body.include?('manufactured_parts(cab)'),
                'rozsah = vnorene AJ odpojene dielce (zdielany filter s kusovnikom)')
  NxTest.assert(body.include?("Store.get(p, 'part_key')"),
                'kovanie sa viaze na part_key, nie na entitu ani PID')
  NxTest.assert(UIC4_HANDLER.include?('Dielec sa v modeli nenašiel'),
                'nenajdeny dielec sa PRIZNA — nikdy tiche nic')
end

NxTest.test('UI-C4: odmietnuty edit sa oznacenim NEPREKRYJE (Codex #179 P2)') do
  # `@last_apply_error` je JEDINA sprava o tom, preco sa rozpisana uprava
  # nezapisala. Hlasit nad nou uspech oznacenia by ju prekrylo — a nespotrebovany
  # priznak by sa neskor ozval pri kliku „Dielcov" k uprave, ktora uz nie je
  # vidiet. Rovnaky guard ma `handle_select_parts`.
  NxTest.assert(UIC4_HANDLER.include?('if @last_apply_error'), 'priznak sa kontroluje')
  NxTest.assert(UIC4_HANDLER.include?('@last_apply_error = nil'), 'a SPOTREBUJE (dalsi klik prejde)')
  NxTest.assert(UIC4_HANDLER.include?('najprv oprav úpravu'), 'pouzivatel dostane povodny dovod')
  # Poradie je kontrakt: guard musi bezat PRED akoukolvek zmenou vyberu.
  NxTest.assert(UIC4_HANDLER.index('if @last_apply_error') < UIC4_HANDLER.index('suspend_selection_sync'),
                'guard bezi PRED zmenou vyberu, nie po nej')
end

NxTest.test('UI-C4: ciastocne najdeny box status NEZAKLAME (Codex #179 P2)') do
  # Box moze niest viac klucov (obe kridla, vsetky police vo „Vnútre"). Ked sa
  # cast nenajde, vyber sa NEODMIETA (dve kridla z troch su stale to, co
  # pouzivatel chcel), ale status sa pyta OZNACENYCH dielcov a chybajuce
  # POMENUJE — inak by hlasil uspech pre nieco, co v modeli nie je.
  NxTest.assert(UIC4_HANDLER.include?("parts.map { |p| Store.get(p, 'part_key').to_s }.uniq"),
                'status sa pyta oznacenych dielcov, nie ziadanych klucov')
  NxTest.assert(UIC4_HANDLER.include?('missing = keys - found'), 'chybajuce kluce sa dopocitaju')
  NxTest.assert(UIC4_HANDLER.include?('Nenašlo sa:'), 'a POMENUJU sa v statuse')
  NxTest.assert(UIC4_HANDLER.include?('set_status(msg, !missing.empty?)'),
                'ciastocny vysledok sa oznaci ako upozornenie, nie ako cisty uspech')
end

# --- 4) znacky kovania v nahlade --------------------------------------------

NxTest.test('UI-C4: znacka v nahlade nesie vlastnika a klik ho oznaci') do
  NxTest.assert(UIC4_PREVIEW_JS.include?("data-owner=\"'+esc(m.owner||'')+'\""),
                'znacka nesie owner_part_key — ziadne nove data, len uz prijaty kluc')
  NxTest.assert(UIC4_PREVIEW_JS.include?('nxHwMarkPick(hm.getAttribute(\'data-owner\')'),
                'klik na znacku ide na vyber vlastnika (nie len status ako v UI-B2)')
  NxTest.assert(UIC4_HW_JS.include?('function nxHwMarkPick'), 'funkcia zije pri kovani, nie v nahlade')
  NxTest.assert(UIC4_HW_JS.include?("NX.setStatus(tip || '', false)"),
                'bez boxu ostava povodne spravanie (popis polozky) — nikdy sa nemlci')
end

NxTest.test('UI-C4: hover box <-> znacka je OBOJSMERNY a bezi CSS triedou') do
  # Codex #179 P2: prvé znenie prisvietilo len smer box -> znacka. Zvyraznenie
  # nasadzuje JEDNA funkcia na OBE strany naraz, takze sa smery nemozu rozist.
  NxTest.assert(UIC4_HW_JS.include?('function hwPaintHover'), 'obe strany nasadzuje jedna funkcia')
  paint = UIC4_HW_JS[/function hwPaintHover.*?\n  \}/m].to_s
  NxTest.assert(paint.include?('g.hwmk'), 'nasadzuje sa na znacky v nahlade')
  NxTest.assert(paint.include?('hwBoxByGroup(groupKey)'), 'aj na box vlastnika')
  NxTest.assert(UIC4_HW_JS.include?('function hwHoverByOwner'),
                'nahlad o konvencii boxov nevie — pyta sa jedneho miesta pravdy')
  NxTest.assert(UIC4_PREVIEW_JS.include?('hwHoverByOwner(m.getAttribute(\'data-owner\')'),
                'hover nad ZNACKOU prisvieti box jej vlastnika (druhy smer)')
  NxTest.assert(UIC4_PREVIEW_JS.include?('hwClearHover()'),
                'prekreslenie nahladu zvyraznenie zhasne (uzly zaniknu)')
  NxTest.assert(UIC4_HW_JS.include?("box.dataset.hwHoverBound = '1'"),
                'delegacia sa viaze RAZ na staticky kontajner (boxy sa prestavuju)')
  NxTest.assert(UIC4_BOOT_JS.include?('bindHwOwnerHover()'), 'delegacia sa naozaj pripaja pri starte')
  NxTest.assert(UIC4_CSS.include?('#preview g.hwmk.hov circle'),
                'zvyraznenie prebija prezentacne atributy znacky (vzor D-23)')
  NxTest.assert(UIC4_CSS.include?('.hwbox.hov > .hwboxh'), 'a box ma svoj hover stav')
  NxTest.refute(paint.include?('renderPreview'), 'hover NIKDY nekresli nahlad nanovo (lekcia D-23)')
end

# --- 5) preklik z kontextu Cela (UI-C3) -------------------------------------

NxTest.test('UI-C4: preklik „naviazané kovanie" doskoci na BOX vlastnika') do
  NxTest.assert(UIC4_HW_JS.include?('function hwFrontGroup'),
                'kluc boxu cela sklada JEDNA funkcia (render aj skok)')
  NxTest.assert(UIC4_FORM_JS.include?('hwBoxByGroup(hwFrontGroup(fid))'),
                'skok z riadku cela pouziva TU ISTU konvenciu ako render')
  NxTest.assert(UIC4_FORM_JS.include?('hwFlash(target)'), 'ciel skoku sa kratko prisvieti')
  NxTest.assert(UIC4_FORM_JS.include?("setViewContext('kovanie')"), 'klik vedie tam, kam ukazuje (N13)')
  NxTest.assert(UIC4_CSS.include?('.hwbox.hwfocus'), 'prisvietenie boxu ma svoj styl')
end
