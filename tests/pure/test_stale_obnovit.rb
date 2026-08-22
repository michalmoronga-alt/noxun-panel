# frozen_string_literal: true
# Jantarovy indikator neaktualnosti tlacidla „Obnoviť" v okne ŠTÚDIO (22.8.).
#
# CO to riesi: Studio cisla neprepocitava samo — kym sa nestlaci „Obnoviť",
# visia v nom cisla z posledneho prepoctu. Model sa medzitym mohol zmenit
# (prestavba skrinky z Inspectora, posun, Spat/Znova) a okno vyzeralo uplne
# rovnako — dalo sa teda exportovat VEPO, objednavku aj cenovu ponuku zo
# starych cisel.
#
# Observer sa headless spustit neda (potrebuje zivy SketchUp) — plne scenare
# su v tests/sketchup/su_runner.rb (sekcia `run_stale`, pocitadla vstupov).
# Tu su STATICKE guardy na kontrakt, ktory sa nesmie stratit pri buducej
# uprave studio_dialog.rb / studio.js / budget.js.
require_relative '../helper' unless defined?(NxTest)

module NxStale
  RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')
  JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'), encoding: 'UTF-8')
  BUD = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'), encoding: 'UTF-8')
  HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'), encoding: 'UTF-8')
  MAIN = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')

  def self.body(src, sig)
    src[/#{Regexp.escape(sig)}.*?\n        end\n/m].to_s
  end
end

# --- 1) observer: 4 hooky a NIC INE ------------------------------------------

NxTest.test('STALE: StudioModelWatch pokryva commit, undo, redo aj abort') do
  NxTest.assert(NxStale::RB.include?('class StudioModelWatch < Sketchup::ModelObserver'),
                'observer chyba — okno by o zmenach v modeli vobec nevedelo')
  # Bez guardu by tento subor v headless testoch spadol uz pri nacitani
  # (Sketchup tam neexistuje) — vzor core/edge_overlay.rb.
  NxTest.assert(NxStale::RB.include?('if defined?(Sketchup::ModelObserver)'),
                'trieda je pod guardom dostupnosti SketchUp API')
  %w[onTransactionCommit onTransactionUndo onTransactionRedo onTransactionAbort].each do |cb|
    NxTest.assert(NxStale::RB.include?("def #{cb}(model)"), "chyba callback #{cb}")
  end
  # PanelModelObserver pocuje LEN Spat/Znova/Abort a ScaleWatch vedome filtruje
  # vlastne prestavby — hlavny pripad (prestavba skrinky z Inspectora) by teda
  # cez ne neprisiel. Preto ma okno VLASTNY observer a tie dva ostavaju nedotknute.
  klass = NxStale::RB[/class StudioModelWatch.*?\n        end\n      end/m].to_s
  NxTest.assert_equal(4, klass.scan('StudioDialog.on_model_txn(model)').length,
                      'kazdy hook konci v TOM ISTOM tenkom handleri')
end

NxTest.test('STALE: callback je PRAZDNY — ziadne citanie ani zapis modelu') do
  body = NxStale.body(NxStale::RB, 'def on_model_txn(model)')
  NxTest.refute(body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('@epoch = @epoch.to_i + 1'), 'callback LEN zdvihne epochu')
  NxTest.assert(body.include?('request_stale_flush(model)'), 'a naplanuje odlozeny flush')
  # Lekcia D-103: co v observer kontexte siahne na model, stane sa vrcholom
  # undo stacku hned po pouzivatelovom kroku.
  %w[push_state fresh_collect start_operation commit_operation Store\. Bom\. collect
     ProductionCore dedup_copies set_attribute].each do |forbidden|
    NxTest.refute(body.match?(/#{forbidden}/),
                  "v callbacku sa NESMIE objavit #{forbidden} — observer nic nepocita ani nezapisuje")
  end
end

NxTest.test('STALE: latch zluci burst commitov do JEDNEHO js') do
  body = NxStale.body(NxStale::RB, 'def request_stale_flush(model)')
  NxTest.refute(body.empty?, 'latch sa nasiel')
  NxTest.assert(body.include?('return if @stale_pending'),
                'dalsia udalost pocas pending uz dalsi timer nepridava (vzor Panel.request_txn_refresh)')
  NxTest.assert(body.include?('UI.start_timer(0, false)'),
                'flush bezi az MIMO observer kontextu')
  # Review #6: zapadka sa zamyka AZ PO tom, co timer vznikol — inak by vynimka
  # z `UI.start_timer` nechala okno TICHE az do zatvorenia.
  NxTest.assert(body.index('UI.start_timer(0, false)') < body.index('@stale_pending = true'),
                'zapadka sa zamyka az za planovanim timera')
  NxTest.assert(body.match?(/rescue StandardError => e\n\s*@stale_pending = false/),
                'a pri zlyhani sa OTVARA spat (ziadny trvaly tichy vypadok)')
end

# --- 2) POROVNANIE EPOCH (jadro riesenia self-tickov) ------------------------

NxTest.test('STALE: flush posiela markStale LEN ked je epocha NOVSIA nez pushnuta') do
  body = NxStale.body(NxStale::RB, 'def flush_stale(model)')
  NxTest.refute(body.empty?, 'flush sa nasiel')
  NxTest.assert(body.include?('return unless txn_model_ok?(model)'),
                'guard dokumentu sa overuje ZNOVA tesne pred pushom')
  NxTest.assert(body.include?('return unless @dialog && @dialog.visible?'),
                'do zavreteho okna sa neposiela nic')
  NxTest.assert(body.include?('return unless @epoch.to_i > @pushed_epoch.to_i'),
                'JADRO: vlastne ticky okna (dedup kopii, zapis rozpoctu) sa pohltia samy')
  NxTest.assert(body.include?('NX.markStale'), 'a klientovi ide JEDINY jednoduchy signal')
  # Guard sa overuje DVAKRAT (v callbacku aj v flushi) — dokument sa moze
  # prepnut medzi udalostou a timerom.
  NxTest.assert_equal(2, NxStale::RB.scan(/return unless txn_model_ok\?\(model\)/).length)
  guard = NxStale.body(NxStale::RB, 'def txn_model_ok?(model)')
  NxTest.assert(guard.include?('@observer_model') && guard.include?('Sketchup.active_model'),
                "dvojity model guard chyba: #{guard}")
end

NxTest.test('STALE: push_state si epochu uklada AZ PO zbere a LEN po odoslani') do
  push = NxStale::RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.refute(push.empty?, 'push_state sa nasiel')
  NxTest.assert(push.include?('@pushed_epoch = @epoch.to_i if sent'),
                'epocha „co uz je v okne" sa zapisuje LEN po OVEREN0M odoslani payloadu')
  collect_at = push.index('ProductionCore.fresh_collect(model)')
  mark_at = push.index('@pushed_epoch = @epoch.to_i if sent')
  NxTest.assert(!collect_at.nil? && !mark_at.nil? && collect_at < mark_at,
                'zapis epochy je AZ ZA `fresh_collect` — inak by vlastny dedup kopii ' \
                'nechal tlacidlo vecne jantarove')
end

# --- 3) lifecycle: attach / detach / prepnutie dokumentu ---------------------

NxTest.test('STALE: observer zije presne tak dlho ako okno') do
  ens = NxStale.body(NxStale::RB, 'def ensure_dialog')
  NxTest.assert(ens.include?('attach_stale_observer(Sketchup.active_model)'),
                'otvorenie okna observer zavesi')
  closed = NxStale::RB[/@dialog\.set_on_closed do.*?\n          end\n/m].to_s
  NxTest.assert(closed.include?('detach_stale_observer'), 'zatvorenie okna ho odvesi')
  chg = NxStale.body(NxStale::RB, 'def on_model_changed(model)')
  # Review #1: PODANY model, nie `active_model` — pri zlom nacasovani broadcastu
  # by observer ostal visiet na starom dokumente a indikator by uz nikdy
  # nezozltol. `active_model` je tu len zaloha, ked broadcast model nenesie.
  NxTest.assert(chg.include?('attach_stale_observer(model || Sketchup.active_model)'),
                'prepnutie dokumentu observer PREVESI na PODANY model (epocha je per dokument)')
  # Druha poistka: okno, ktore pocita cisla z ineho modelu, nez na akom visi
  # observer, sa prevesi samo (zmeskany broadcast tak nie je trvaly vypadok).
  push = NxStale::RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  NxTest.assert(push.include?('attach_stale_observer(model) if @observer_model && @observer_model != model'),
                'push_state ma SAMOLIECBU — prevesi observer na model, z ktoreho prave pocita')
  NxTest.assert(push.index('attach_stale_observer(model) if') < push.index('sent = js('),
                'a robi to PRED odoslanim payloadu (epocha sa nuluje spolu s prevesenim)')
  att = NxStale.body(NxStale::RB, 'def attach_stale_observer(model = nil)')
  NxTest.assert(att.include?('m.remove_observer(@stale_observer)') && att.include?('m.add_observer(@stale_observer)'),
                'anti-double: remove PRED add (vzor EdgeCheck.attach_observer)')
  NxTest.assert(att.index('m.remove_observer') < att.index('m.add_observer'),
                'a v tomto poradi — inak by udalost prisla dvakrat')
  NxTest.assert(att.include?('rescue StandardError'),
                'zlyhanie odvesenia nesmie preskocit zavesenie (kazdy krok vlastny rescue)')
  det = NxStale.body(NxStale::RB, 'def detach_stale_observer')
  NxTest.assert(det.include?('reset_stale_epoch'), 'detach nuluje epochu')
  # Review #5: odvesenie z uz zavreteho dokumentu je OCAKAVANY stav — do logu
  # nepatri (rovnako ako v attachi).
  NxTest.refute(det.include?('log_error'),
                'zlyhanie odvesenia sa hlta TICHO (nie je to chyba)')
  reset = NxStale.body(NxStale::RB, 'def reset_stale_epoch')
  NxTest.assert(reset.include?('@epoch = 0') && reset.include?('@pushed_epoch = 0'),
                'nuluju sa OBE — inak by nove okno zacalo s cudzim rozdielom')
end

NxTest.test('STALE: ziadny Engine broadcast — vsetko zije v StudioDialog') do
  # Vedome: epocha ma JEDNEHO vlastnika. Broadcast by znamenal druhy zdroj
  # pravdy o tom, ci su cisla v okne stare.
  %w[notify_model_dirty push_stale broadcast_stale].each do |sym|
    NxTest.refute(NxStale::MAIN.include?(sym), "main.rb nema vediet o `#{sym}`")
  end
end

# --- 4) klient: JEDEN markup na 5 miestach ----------------------------------

NxTest.test('STALE: tlacidlo „Obnoviť" ma JEDEN markup pre vsetkych 5 mist') do
  NxTest.assert(NxStale::JS.include?('function refreshBtnHtml(stale, tip, attrs)'),
                'zdielany helper existuje')
  NxTest.assert_equal(1, NxStale::JS.scan(/id="refreshBtn"/).length,
                      'markup tlacidla je v celom studio.js PRAVE RAZ (5 kopii = 5 miest, ' \
                      'kde by sa jantar casom rozisiel)')
  # V budget.js smie `id="refreshBtn"` zit PRAVE RAZ — v NUDZOVEJ vetve mosta
  # (review #4): ked by helper zo studio.js nebol dostupny (parse chyba, zle
  # poradie skriptov), sekcie Rozpocet a Ponuka nesmu prist o JEDINU cestu
  # k cerstvym cislam. Lista sekcie ho nikdy nekresli priamo.
  NxTest.assert_equal(1, NxStale::BUD.scan(/id="refreshBtn"/).length,
                      'budget.js si vlastnu kopiu tlacidla nekresli — okrem nudzovej vetvy')
  bridge = NxStale::BUD[/function budRefreshBtnHtml\(tip\)\{.*?\n  \}/m].to_s
  NxTest.assert(bridge.include?('id="refreshBtn"'),
                'a ta jedna kopia je PRAVE v nudzovej vetve mosta')
  NxTest.refute(bridge.include?('nxstale'),
                'nudzove tlacidlo je NEUTRALNE — bez helpera nie je z coho jantar odvodit')
  # 3 volania v studio.js (Kusovnik, Kontrola, Nakup) + 2 v budget.js
  # (Rozpocet, Ponuka) = 5 mist, jeden markup.
  # `-1` = samotna definicia funkcie; zvysok su volacie miesta.
  NxTest.assert_equal(3, NxStale::JS.scan(/refreshBtnHtml\(/).length - 1,
                      'studio.js kresli tlacidlo v troch sekciach')
  NxTest.assert_equal(2, NxStale::BUD.scan(/budRefreshBtnHtml\('/).length,
                      'budget.js v dvoch (Rozpocet + Ponuka)')
  NxTest.assert_equal(1, NxStale::JS.scan(/t\.closest\('#refreshBtn'\)/).length,
                      'a vsetky idu JEDNYM handlerom (ziadna druha serverova cesta)')
end

NxTest.test('STALE: tooltip PRIZNAVA sirku signalu') do
  NxTest.assert(NxStale::JS.include?('V modeli nastali zmeny od posledného prepočtu'),
                'tooltip povie, PRECO je tlacidlo jantarove')
  NxTest.assert(NxStale::JS.include?('Platí pre akúkoľvek zmenu v dokumente, aj mimo skriniek.'),
                'a poctivo prizna, ze signal je sirsi nez kusovnik ' \
                '(posun cudzieho objektu cisla nezmeni)')
end

NxTest.test('STALE: stav zhadzuje VYHRADNE plny payload, echa nie') do
  set = NxStale::JS[/setStudio: function\(data\)\{.*?\n    \},/m].to_s
  NxTest.refute(set.empty?, 'setStudio sa nasiel')
  NxTest.assert(set.include?('staleFlag = false'), 'plny payload = cerstve cisla, jantar padá')
  NxTest.assert(set.index('staleFlag = false') < set.index('render()'),
                'a to PRED renderom — inak by lista este raz nakreslila jantar')
  # Echa nesu CISLA (lista VEPO, prepinace hran/kresby, vysledok zapisu
  # rozpoctu) — nesmu teda tvrdit, ze okno je aktualne.
  %w[setVepoBar setEdgeCheck setGrainCheck].each do |echo|
    body = NxStale::JS[/#{echo}: function\([^)]*\)\{.*?\n    \},/m].to_s
    NxTest.refute(body.include?('staleFlag'), "echo #{echo} stav NEZHADZUJE")
  end
  NxTest.refute(NxStale::BUD[/budgetResult: function.*?\n    \}/m].to_s.include?('staleFlag'),
                'ani echo vysledku zapisu rozpoctu')
  mark = NxStale::JS[/markStale: function\(\)\{.*?\n    \},/m].to_s
  NxTest.assert(mark.include?('renderTools()'), 'markStale prekresli LEN listu sekcie')
  NxTest.refute(mark.include?('renderBody') || mark.include?('render()'),
                'zoznam ani tabulka sa nedotykaju — su to stale tie iste cisla')
end

NxTest.test('STALE: jantar ide cez --nx-warn tokeny a ZIADNA zelena') do
  css = NxStale::HTML[/\.sectools \.ghostbtn\.bstalebtn,[^{]*\{[^}]*\}/m].to_s
  NxTest.assert(css.include?('.nxstale'), 'jantarove „Obnoviť" ma pravidlo')
  NxTest.assert(css.include?('--nx-warn'), 'farba ide vyhradne cez jantarove tokeny')
  NxTest.refute(css.match?(/green|--nx-ok|#[0-9a-fA-F]{6}/),
                'ziadna zelena ani vlastna farba — vyznamove farby ostavaju semaforu Kontroly')
end
