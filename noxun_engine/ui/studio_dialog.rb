# frozen_string_literal: true
# Noxun Engine — ST-1a: okno STUDIO (skelet + sekcia Kusovnik).
#
# Studio je cielove JEDNO okno zakazky (kontrakt UI 2.0, sekcia ŠTÚDIO KONCEPT):
# navigacia vlavo, obsah sekcie vpravo. V davke ST-1a zije PRVA sekcia —
# KUSOVNIK (Š1–Š6) s pohladmi Dielce · Platne · ABS; ostatne polozky navigacie
# su PREMOSTENIA do dnesnych okien (audit #2), aby sa nikde neobjavilo mrtve
# tlacidlo bez vysvetlenia.
#
# Okno Vyroba, z ktoreho sa obsah stahoval, ZANIKLO v ŠT-1c PR B3 — Studio je
# odvtedy JEDINE okno vystupov zakazky. Co z toho vztahu ostalo:
#   - CISLA pocita zdielane jadro `ProductionCore` (jeden vypocet pre okno,
#     rail Inspectora aj exporty; druha kopia by sa casom rozisla a rozdiel by
#     sa ukazal az na vyrobnom vystupe),
#   - KANAL je vlastny (audit #3) — vlastny `@generation`, vlastny relay cez
#     panel (`NX.studioRelay*` -> `studio_do_select` / `studio_do_export`),
#     takze cudzi push nezhodi guard tohto okna,
#   - Studio do modelu ZAPISUJE cez sekciu Rozpocet a (od ŠT-2b) cez sekciu
#     Materialy — projektova predvolba a „Nahradiť UNI…" prestavaju skrinky
#     (1 mutacia = 1 krok Spat); klik iba vybera entity (pod
#     `Panel.suspend_selection_sync`, refresh panela s `dedup: false`) a nazov
#     projektu je nastavenie POCITACA v %APPDATA%, nie zakazky.
#
# ŠT-2b: zaniklo aj satelitne okno „Materiály projektu" — katalog materialov je
# odteraz VYHRADNE sekcia `mat` tohto okna. Serverova autorita katalogu ostava
# v module `MaterialsDialog` (nepremenovava sa, audit #21); toto okno je jej
# jediny vstup aj jediny adresat odpovedi (`mat_js`).
#
# ST-1a: zdielane ciste jadro nacitava loader (main.rb) EST PRED tymto suborom;
# headless pure testy si vsak `ui/studio_dialog.rb` requiruju samostatne —
# preto poistka nizsie.
require File.expand_path('production_core', __dir__) unless defined?(Noxun::Engine::ProductionCore)

module Noxun
  module Engine
    module StudioDialog
      DLG_KEY = 'noxun_engine_studio'

      # ZAVAZNY whitelist sekcii Studia. ŠT-1a priniesla Kusovnik, ŠT-1b
      # KONTROLU (`ctrl`), ŠT-1c PR A NAKUP KOVANIA (`buy`), ŠT-1c PR B1
      # ROZPOCET (`budget`), PR B2 CENOVU PONUKU (`offer`) a ŠT-2a MATERIALY
      # (`mat` — prva ziva polozka skupiny KATALOGY). JS zrkadla
      # (`studio.js`, `NXShell.STUDIO_SECTIONS`) su pohodlie, nie ochrana
      # (zhodu strazi guard test): autoritou je VZDY Ruby.
      # ŠT-3a-1 pridala KOVANIE (`hw` — druha ziva polozka skupiny KATALOGY).
      # ŠT-3b-1 pridala PRAVIDLÁ (`rules` — tretia ziva polozka skupiny KATALOGY).
      # ŠT-3c-1 pridala ŠABLÓNY (`tpl`), ŠT-4a NASTAVENIA (`sup` · `bset` ·
      # `about`) — poslednu skupinu navigacie. Tym su ZIVE VSETKY polozky
      # okrem Narezoveho planu (faza 2) a v okne nie je uz ziadne premostenie.
      SECTIONS = %w[bom ctrl buy budget offer mat hw rules tpl sup bset about].freeze

      # ŠT-2a/2b: akcie katalogu materialov, ktore smie poslat SEKCIA `mat`,
      # ziju v JEDINOM zozname — `MaterialsDialog::SECTION_ACTIONS`. Telo
      # kazdej z nich je tam (jedina autorita katalogu, audit #21 — modul sa
      # NEPREMENUVA aj ked jeho okno v ŠT-2b zaniklo); toto okno je JEDINY
      # vstup a odpoved si necha presmerovat cez `MaterialsDialog.dispatch`.
      # Druhy zoznam TU by sa casom rozisiel, preto sa cita az pri registracii
      # callbackov.

      # ŠT-1c PR B3: `PRODUCTION_BRIDGES` (premostenia do TABOV okna Vyroba)
      # ZANIKLI spolu s oknom — kusovnik, kontrola, nakup kovania, rozpocet aj
      # cenova ponuka su SEKCIAMI tohto okna, takze niet kam premostovat.

      # ŠT-4a: PREMOSTENIA ZANIKLI CELE — `WINDOW_BRIDGES`, `BRIDGE_STATUS`,
      # `do_bridge` aj `bridge_window`. Nastavenia boli POSLEDNY satelit, takze
      # niet kam premostovat: kazda polozka navigacie je odteraz bud SEKCIA
      # tohto okna, alebo (jediny Narezovy plan) `aria-disabled` s dovodom.
      # Predtym postupne zanikli: `mat` (ŠT-2a/2b) · `hw` (ŠT-3a) · `rules`
      # (ŠT-3b-1) · `tpl` (ŠT-3c-1) · `PRODUCTION_BRIDGES` (ŠT-1c PR B3).
      # Klientska strana (`bridge:` v NAV, `bridgeTo`, `.nbridge`, callback
      # `studio_bridge`) zanikla V TEJ ISTEJ davke — most bez oboch koncov by
      # bol mrtvy kod, ktory prezije prve „to sa este zide".

      # ŠT-2b: `MAT_BRIDGE_STATUS` (hlasky premostenia Z VNUTRA sekcie do okna
      # Materialy) ZANIKLO spolu s tym oknom — Demos toky aj „Nahradiť UNI…"
      # bezia v sekcii a niet kam premostovat.

      # --- INDIKATOR NEAKTUALNOSTI (tlacidlo „Obnoviť" zozltne) --------------
      #
      # Studio cisla NEPREPOCITAVA samo — kazdy prepocet je RUCNY („Obnoviť").
      # Do tejto davky sa nedalo poznat, ci uz su cisla v okne stare: model sa
      # medzitym mohol zmenit (prestavba z Inspectora, posun, Spat/Znova)
      # a okno vyzeralo uplne rovnako — dalo sa teda exportovat zo starych
      # cisel. Preto ma okno VLASTNY observer transakcii.
      #
      # KONTRAKT CALLBACKU (pravidla observerov + lekcia D-103): v callbacku sa
      # NIC nepocita, necita ani nezapisuje — LEN sa zdvihne epocha a naplanuje
      # latch (`UI.start_timer(0)`), takze burst commitov = jeden js do okna.
      # PanelModelObserver ani ScaleWatch sa NEDOTYKAJU: prvy pocuje len
      # Spat/Znova/Abort, druhy vedome filtruje vlastne prestavby — ani jeden
      # teda nevidi hlavny pripad (prestavba skrinky z Inspectora).
      #
      # Guard `defined?` je nutny: headless testy tento subor requiruju bez
      # SketchUpu (vzor `core/edge_overlay.rb`).
      if defined?(Sketchup::ModelObserver)
        class StudioModelWatch < Sketchup::ModelObserver
          def onTransactionCommit(model) # rubocop:disable Naming/MethodName — SketchUp API
            StudioDialog.on_model_txn(model)
          end

          def onTransactionUndo(model) # rubocop:disable Naming/MethodName — SketchUp API
            StudioDialog.on_model_txn(model)
          end

          def onTransactionRedo(model) # rubocop:disable Naming/MethodName — SketchUp API
            StudioDialog.on_model_txn(model)
          end

          # Abort je zadarmo (vzor EdgeModelWatch): zrusena operacia model vratila
          # do stavu, z ktoreho sa cisla nemusia rovnat tomu, co je v okne.
          def onTransactionAbort(model) # rubocop:disable Naming/MethodName — SketchUp API
            StudioDialog.on_model_txn(model)
          end
        end
      end

      class << self
        # `open_section` = deep-link (rail Štúdio, toolbar, N13 „Materiál").
        # `anchor` predvyplni hladanie sekcie (N13 posiela ID skrinky, audit #12).
        #
        # Sekcia sa NEPOSIELA hned — okno po `show` este nemusi mat nacitany
        # HTML, takze `execute_script` by prisiel do prazdna. Odklada sa a
        # spotrebuje ju NAJBLIZSI `push_state` (pri novom okne ho vyvola
        # `ready`, pri uz otvorenom ho volame priamo tu).
        def show(open_section: nil, anchor: nil)
          @pending_section = SECTIONS.include?(open_section.to_s) ? open_section.to_s : nil
          @pending_anchor = @pending_section ? anchor.to_s.strip : nil
          @pending_anchor = nil if @pending_anchor.to_s.empty?
          dlg = ensure_dialog
          # K2/D-87 (audit #14): zapamataný prepínač „Smer kresby" (%APPDATA%,
          # nastavenie počítača) sa obnoví PRED prvým push_state — inak by lišta
          # sekcie hlásila vypnuté a v modeli by sa kreslilo. Do ŠT-1b to robilo
          # okno Výroba; odkedy je prepínač tu, musí to robiť aj toto okno.
          restore_grain_check
          if dlg.visible?
            dlg.bring_to_front
            push_state
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.show')
        end

        def dialog_alive?
          !@dialog.nil? && @dialog.visible?
        rescue StandardError
          false
        end

        # ŠT-2b: ohlasil uz klient `ready`? Rozhoduje o tom, ci sa odlozena
        # poziadavka („Nahradiť UNI…") smie spustit HNED, alebo pocka na `ready`
        # callback — CEF `execute_script` pred nacitanim HTML potichu zahodi.
        def ready?
          @ready == true
        end

        # K2/D-87: obnova zapamataneho prepinaca kresby smeru. Chranene vlastnym
        # blokom — zlyhanie NESMIE zabranit otvoreniu okna.
        def restore_grain_check
          return unless defined?(GrainCheck)

          GrainCheck.restore!(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.restore_grain_check')
        end

        # Bezpecny refresh — volaju ho editor materialov, nastavenia, katalog
        # kovania aj prepocet cien (audit #10: Studio musi byt vo VSETKYCH
        # refresh cestach, inak by drzalo stare cisla).
        # ŠT-2a: `bump: false` = payload je PLNY, ale generacia sa NEDVIHA.
        # Pouziva ho katalogovy zapis (`MaterialsDialog.after_catalog_change`):
        # cisla sa menia, identita riadkov nie — pending klik ostava platny.
        def refresh_if_open(bump: true)
          return unless @dialog && @dialog.visible?

          push_state(bump: bump)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.refresh_if_open')
        end

        # EngineAppObserver: prepnutie/otvorenie modelu = nove data + NOVA
        # generacia (stary DOM klik sa odmietne genom, aj keby ID sedeli).
        def on_model_changed(model)
          return unless @dialog && @dialog.visible?

          # Novy dokument = NOVY observer a NOVA epocha. Epocha je zamerne per
          # dokument: pocet zmien v jednom dokumente nesmie rozhodovat o tom,
          # ci su neaktualne cisla toho druheho.
          #
          # Review #1: observer sa vesa na PODANY model, nie na `active_model`.
          # Vsetci ostatni odberatelia tohto broadcastu pracuju s podanym
          # modelom; keby toto okno siahlo po `active_model` v momente, ked este
          # nie je prepnuty (poradie observerov pri New/Open), observer by ostal
          # visiet na STAROM dokumente — a indikator by uz NIKDY nezozltol.
          attach_stale_observer(model || Sketchup.active_model)
          # ŠT-2a: novy dokument = novy modelovy kontext sekcie Materialy;
          # katalog sa posle CELY (jeho identita `row_rev` sa medzitym mohla
          # zmenit v inom okne a klient nema ako to vediet).
          @mat_full_pending = true
          # ŠT-3a-1: to iste pre katalog kovania — je sice GLOBALNY (nezavisi
          # od dokumentu), ale jeho `row_rev` mohlo medzitym zmenit ZIJUCE
          # okno „Katalóg kovania" a klient o tom nema ako vediet.
          @hw_full_pending = true
          push_state
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.on_model_changed')
        end

        # --- indikator neaktualnosti: callback, latch, porovnanie epoch -------
        #
        # Callback je PRAZDNY (viz kontrakt pri `StudioModelWatch`): zdvihne
        # epochu a naplanuje flush. Guard dokumentu sa overuje TU aj ZNOVA
        # v flushi (vzor `Panel.txn_model_ok?`) — udalost z ineho dokumentu
        # nesmie oznacit cisla aktivneho za neaktualne a dokument sa moze
        # prepnut aj MEDZI udalostou a timerom.
        def on_model_txn(model)
          return unless @dialog
          return unless txn_model_ok?(model)

          @epoch = @epoch.to_i + 1
          request_stale_flush(model)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.on_model_txn')
        end

        # Coalescing (vzor `Panel.request_txn_refresh`): burst commitov —
        # tahanie mysou, prestavba skrinky, viac Spat za sebou — je JEDEN
        # js do okna, nie jeden na kazdu transakciu.
        def request_stale_flush(model)
          return if @stale_pending

          # Review #6: zapadka sa zamyka AZ PO tom, co timer naozaj vznikol.
          # Keby `UI.start_timer` hodil vynimku (alebo ju hodilo cokolvek pred
          # nim), `@stale_pending` by ostalo natrvalo `true` a okno by uz do
          # zatvorenia NEPOSLALO ani jeden signal — tichy, trvaly vypadok.
          UI.start_timer(0, false) do
            begin
              @stale_pending = false
              flush_stale(model)
            rescue StandardError => e
              Engine.log_error(e, 'StudioDialog.request_stale_flush')
            end
          end
          @stale_pending = true
        rescue StandardError => e
          @stale_pending = false
          Engine.log_error(e, 'StudioDialog.request_stale_flush(plan)')
        end

        # POROVNANIE EPOCH je jadro celej veci: transakcie, ktore spustil SAM
        # prepocet okna, su v `@pushed_epoch` uz zapocitane (`push_state` si ju
        # uklada AZ PO zbere) — zapis rozpoctu teda tlacidlo nezozltne. Preto
        # ziadne volacie miesto nepotrebuje vynimku ani „suspend" prepinac.
        # (Od 1b-3 uz `fresh_collect` ziadnu vlastnu transakciu neotvara vobec —
        # zber je cisté citanie; porovnanie epoch tym stratilo JEDEN zo svojich
        # dvoch zdrojov self-tikov, druhy — rozpocet — ostava.)
        def flush_stale(model)
          return unless txn_model_ok?(model)
          return unless @dialog && @dialog.visible?
          return unless @epoch.to_i > @pushed_epoch.to_i

          js('if (window.NX && NX.markStale) NX.markStale();')
        end

        def txn_model_ok?(model)
          !model.nil? && model == @observer_model && model == Sketchup.active_model
        end

        # Lifecycle (vzor `EdgeCheck.attach_observer`): anti-double `remove -> add`
        # a KAZDY krok vlastny rescue — zlyhanie odvesenia nesmie preskocit
        # zavesenie (a naopak). Vola sa pri otvoreni okna a pri prepnuti modelu.
        def attach_stale_observer(model = nil)
          return unless defined?(StudioModelWatch)

          m = model || Sketchup.active_model
          return if m.nil?

          @stale_observer ||= StudioModelWatch.new
          detach_stale_observer if @observer_model && @observer_model != m
          begin
            m.remove_observer(@stale_observer)
          rescue StandardError
            nil
          end
          m.add_observer(@stale_observer)
          @observer_model = m
          reset_stale_epoch
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.attach_stale_observer')
        end

        # Zatvorene okno nema co znacit — observer sa odvesi a epocha padne na
        # nulu, takze dalsie otvorenie zacina cistym stavom (a prvy push mu aj
        # tak donesie cerstve cisla).
        def detach_stale_observer
          m = @observer_model
          begin
            m.remove_observer(@stale_observer) if m && @stale_observer
          rescue StandardError
            # Review #5: TICHO (rovnako ako v attachi). Odvesenie z uz zavreteho
            # dokumentu je OCAKAVANY stav (okno sa zatvara spolu s modelom) —
            # zaznam v logu by hlasil chybu tam, kde ziadna nie je.
            nil
          end
          @observer_model = nil
          reset_stale_epoch
        end

        def reset_stale_epoch
          @epoch = 0
          @pushed_epoch = 0
        end

        # --- relay z panela (audit #3) ---------------------------------------
        # Panel uz flushol rozpisane edity — az potom sa vybera/exportuje.
        # Telo je v ZDIELANOM jadre (`ProductionCore`), okno odovzdava LEN svoj
        # generacny token, svoj status a svoj refresh.

        def do_select(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_select(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        def do_export(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_export(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        # ŠT-1c PR A (Š7): CSV nakupneho zoznamu kovania z listy sekcie Nakup.
        # Telo je v `ProductionCore` (to iste, ake volal zaniknuty tab Kovanie)
        # — okno odovzdava LEN svoj generacny token, status a refresh.
        def do_hw_csv(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_hw_csv(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc, repush: repush_proc)
        end

        # --- ŠT-1c PR B1: sekcia ROZPOCET -----------------------------------
        #
        # JEDINA sekcia, ktora ZAPISUJE do modelu (1 mutacia = 1 krok Spat).
        # Vsetky tela su v `ProductionCore` — okno odovzdava LEN svoj generacny
        # token, svoj status, svoje echo a SVOJ REFRESH.
        #
        # GENERACNY KONTRAKT (audit #1): budget-iniciovany push ide s
        # `bump: false` — payload je PLNY (Kontrola dostane cerstve rozpoctove
        # ORANGE), ale generacia okna sa NEDVIHA. Mutacia rozpoctu nemeni
        # `rows`/`refs`, takze rozkliknuty riadok Kusovnika ani rozrobeny export
        # inej sekcie nesmie zastarat len preto, ze niekto prepisal sumu.
        # Ochranu proti zastaranemu ZAPISU drzi to, ze KAZDA ina zmena (model,
        # katalog, prepnutie dokumentu) generaciu bumpne ako doteraz — a mutacia
        # so starym `gen` sa odmietne.
        def do_budget(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_budget(Sketchup.active_model, data, generation: @generation,
                                                                status: status_proc,
                                                                repush: budget_repush_proc,
                                                                result: budget_result_proc)
        end

        # XLSX rozpoctu — flush handshake (rozpisany edit panela meni kusovnik,
        # teda aj platne, olep a montaz v rozpocte).
        def do_budget_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_budget_xlsx(Sketchup.active_model, data, generation: @generation,
                                                                     status: status_proc,
                                                                     repush: repush_proc)
        end

        # Zakaznicka cenova ponuka (XLSX) — od ŠT-1c PR B2 export SEKCIE
        # `offer` (vlastna sekcia Studia); telo je v jadre ako ostatne exporty.
        def do_cp_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_cp_xlsx(Sketchup.active_model, data, generation: @generation,
                                                                 status: status_proc,
                                                                 repush: repush_proc)
        end

        # --- ŠT-1b: sekcia KONTROLA -----------------------------------------
        # Vsetky telá su v `ProductionCore` (audit #5, #13) — okno odovzdava LEN
        # svoj generacny token, svoj status, svoj refresh a svoje echo. Model sa
        # NEMENI: overlaye kreslia NAD nim, nastavenie zije v %APPDATA%.

        # D-83 (Š9): „Nahradiť UNI…" pri naleze „materiál neurčený".
        def do_replace_uni(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.replace_uni(Sketchup.active_model, data, generation: @generation,
                                                                  status: status_proc,
                                                                  repush: repush_proc)
        end

        # Š10: „Zvýrazniť hrany" (telo tlacidla).
        def do_edge_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_edge_check(Sketchup.active_model, data, generation: @generation,
                                                                    status: status_proc,
                                                                    repush: repush_proc,
                                                                    echo: edge_echo_proc)
        end

        # Š10: 3-stavove nastavenie (rohovy trojuholnik) — TEN ISTY zdielany
        # komponent a ta ista serverova cesta ako rail Inspectora.
        def do_edge_check_option(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_edge_check_option(Sketchup.active_model, data, generation: @generation,
                                                                           status: status_proc,
                                                                           repush: repush_proc,
                                                                           echo: edge_echo_proc)
        end

        # Š10: „Smer kresby" (K2/D-87).
        def do_grain_check(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_grain_check(Sketchup.active_model, data, generation: @generation,
                                                                     status: status_proc,
                                                                     repush: repush_proc,
                                                                     grain_echo: grain_echo_proc)
        end

        # Maly echo push stavu prepinaca (bez prepoctu celej sekcie) — vola ho
        # `Engine.broadcast_edge_check` po prepnuti Z HOCIJAKEHO vstupneho bodu
        # (rail Inspectora aj lista tejto sekcie) aj EdgeCheck po prepocte cache.
        def push_edge_check(state = nil)
          return unless defined?(EdgeCheck)

          st = state || EdgeCheck.ui_state(Sketchup.active_model)
          js("if (window.NX && NX.setEdgeCheck) NX.setEdgeCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_edge_check')
        end

        def push_grain_check(state = nil)
          return unless defined?(GrainCheck)

          st = state || GrainCheck.ui_state(Sketchup.active_model)
          js("if (window.NX && NX.setGrainCheck) NX.setGrainCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_grain_check')
        end

        # To iste nastavenie ma DVA vstupne body (rail Inspectora · lista tejto
        # sekcie); tretim bolo okno Vyroba, ktore zaniklo v ŠT-1c PR B3.
        # Otvorenie na jednom zavrie druhy — na obrazovke nikdy nestoja dve
        # kopie tych istych prepinacov. Cisto zobrazovacie.
        def close_edge_menu
          js('if (window.NX && NX.closeEdgeMenu) NX.closeEdgeMenu();')
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.close_edge_menu')
        end

        # --- rucny prepocet okna („Obnoviť" v liste KAZDEJ sekcie) -----------
        # SMOKE 22.8.: klient si pred volanim nastavi hlasku „Prepočítavam…"
        # a NIKTO ju nezhodil — po dobehnutom prepocte v okne visela dalej
        # a vyzeralo to, ze sa okno zaseklo. Hlasku preto zhadzuje SERVER: on
        # jediny vie, ci prepocet dobehol. Plati pre VSETKY sekcie (jeden push
        # nesie kusovnik, kontrolu, nakup, rozpocet aj ponuku naraz).
        #
        # Rescue tu je ZAMERNE aj napriek spolocnemu rescue v `cb`: hlaska
        # „Prepočítavam…" nesmie ostat visiet ANI pri vynimke, a chybu treba mat
        # v logu s menom TEJTO cesty.
        #
        # Review #6: „Prepočítané." sa posiela LEN ked payload naozaj ODOSIEL.
        # `js` hltá výnimky `execute_script` (a mlčí, ked okno nezije), takze
        # `push_state` mohol skoncit BEZ toho, aby klient cokolvek dostal —
        # a server by mu napriek tomu potvrdil hotovo. Preto `js` (a s nim
        # `push_state`) vracia true/false a tato cesta sa podla toho rozhoduje:
        # server nesmie potvrdit, co neoveril.
        def do_refresh_bom
          # ŠT-3a-1: rucne „Obnoviť" je jedina cesta, ako si vypytat CERSTVY
          # katalog kovania (inak ho klient drzi a zmeny mu chodia echom).
          # Sekcia `hw` inak nema z modelu co prepocitavat — bez tohto by jej
          # tlacidlo klamalo.
          @hw_full_pending = true
          return unless push_state

          set_status('Prepočítané.')
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.do_refresh_bom')
          set_status("Prepočet zlyhal: #{e.message}", true)
        end

        # --- lista Kusovnika: nazov projektu + merge 18+36 (audit #1) --------
        # Obe hodnoty su nastavenim POCITACA (%APPDATA%), nie zakazky: ziadny
        # zapis do modelu a ziadny krok Spat.
        #
        # Zapis NEROBI plny `push_state` (review PR #193 P2): ten zdviha
        # `@generation`, takze prvy klik ci export hned po editacii nazvu (change
        # tesne pred clickom) by zarucene spadol na „Dáta okna sa medzitým
        # zmenili". Kusovnik sa pritom nezmenil — zmenila sa LISTA. Ide preto
        # cielene echo (vzor `push_edge_check`), ktore prepise len jej obsah
        # a generaciu NECHA TAK.
        def do_set_vepo_opts(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          unless data['gen'].to_i == @generation.to_i
            push_state if @dialog && @dialog.visible?
            return set_status('Okno sa medzitým prepočítalo — obnovené, skús znova.', true)
          end
          guid = data['model_guid'].to_s
          # Tolerantne ako `ProductionCore.do_budget`: prazdny udaj z klienta
          # (starsi cachovany DOM) guard neblokuje, nezhodne ID ano.
          if !guid.empty? && guid != ProductionCore.model_guid(model)
            push_state
            return set_status('Model sa medzitým prepol — obnovené, skús znova.', true)
          end

          msg = []
          if data.key?('project')
            name = ProductionCore.save_project_name(model, data['project'])
            msg << "Názov projektu: #{name}"
          end
          if data.key?('merge')
            merge = ProductionCore.save_merge_18_36(data['merge'] == true)
            msg << "18+36 spolu: #{merge ? 'zapnuté' : 'vypnuté'}"
          end
          return set_status('Nič sa nezmenilo.', true) if msg.empty?

          push_vepo_bar(model)
          set_status("#{msg.join(' · ')}. Platí pre všetky exporty.")
        end

        # Maly echo push LISTY sekcie (nazov projektu + merge). Nezdviha
        # generaciu a neprepocitava kusovnik — je to zobrazovacia synchronizacia
        # toho, co uz je zapisane.
        def push_vepo_bar(model = nil)
          m = model || Sketchup.active_model
          st = { 'project' => ProductionCore.project_name(m),
                 'default_project' => ProductionCore.default_project_name(m),
                 'merge_18_36' => ProductionCore.merge_18_36 }
          js("if (window.NX && NX.setVepoBar) NX.setVepoBar(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_vepo_bar')
        end

        # --- ŠT-2a: sekcia MATERIALY -----------------------------------------
        #
        # Kanal je zamerne DELENY na dve cesty:
        #   * KATALOGOVE ECHO (`push_mat_catalog`) — vzor `push_vepo_bar`:
        #     prepise LEN katalog v okne, NEPREPOCITAVA kusovnik a hlavne
        #     NEDVIHA generaciu. Katalogovy zapis nemeni model, takze rozkliknuty
        #     riadok Kusovnika ani rozrobeny export inej sekcie po nom nesmie
        #     zastarat (audit #4).
        #   * PLNY PUSH (`push_state`) — nesie modelovy kontext sekcie
        #     (predvolby, pocty, „Použité v projekte") a pri PRVOM pushi aj cely
        #     katalog. Zdvih generacie ostava na tom, co ho zasluzi: zmena
        #     modelu.
        def mat_actions
          defined?(MaterialsDialog) ? MaterialsDialog::SECTION_ACTIONS : []
        end

        def do_mat(name, payload)
          unless defined?(MaterialsDialog)
            return set_status('Katalóg materiálov nie je načítaný.', true)
          end

          MaterialsDialog.dispatch(name, payload, mat_sink)
        end

        # Adresat odpovedi: TOTO okno. `MaterialsDialog` posiela `MD.*`, `MDD.*`
        # a `NXDA.*` volania (status, katalog, potvrdenia, Demos eventy) — sekcia
        # ma presne tie iste prijimace, lebo bezi na TOM ISTOM
        # `js/proj_materials.js` + `demos_diff.js` + `demos_add.js`.
        def mat_sink
          ->(script) { js(script) }
        end

        # ŠT-2b: VEREJNY vstup pre `MaterialsDialog` mimo synchronneho volania
        # sekcie — asynchronne Demos emity dobiehaju z casovaca uz po navrate
        # z `dispatch`, takze sink neexistuje a jediny mozny adresat je toto
        # okno. `js` je private (patri kanalu okna), preto tento tenky most.
        def mat_js(script)
          js(script)
        end

        # ŠT-2b: odchod zo SEKCIE `mat`. Klient ho hlasi PRED prepnutim (vzor
        # `setVepoBar` — server sklada text, klient len oznamuje udalost);
        # server na to zrusi bezaci Demos fetch. Je to VEDOME rozhodnutie
        # dávky: dlhy beh je viazany na sekciu, nie na okno (dovod v
        # `MaterialsDialog#cancel_demos_on_leave`).
        def do_mat_leave(_payload = nil)
          return unless defined?(MaterialsDialog)

          MaterialsDialog.cancel_demos_on_leave
        end

        # Katalogove echo. Payload sa smie PODAT (after_catalog_change ho uz
        # zostavil — druhy `Materials.load` a druhy vypocet `row_rev` pre kazdy
        # zaznam by bol zbytocny).
        def push_mat_catalog(payload = nil)
          return unless defined?(MaterialsDialog)

          data = payload || MaterialsDialog.catalog_payload
          js("if (window.NX && NX.setMatCatalog) NX.setMatCatalog(#{data.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_mat_catalog')
        end

        # ŠT-2b: `push_mat_state` (`MD.init` do sekcie) ZANIKLO. Bolo to
        # PRECHODNE riesenie pre dve UI nad jednym katalogom — plny stav musel
        # dorazit aj do okna, ktore o zmenu nepoziadalo. Dnes je UI jedno
        # a modelovy kontext (predvolby, pocty, `used`) nesie `mat_payload`
        # v beznom `push_state`; druha cesta by znamenala druhy zdroj pravdy.

        # Modelovy kontext sekcie. `used` sa pocita z UZ zozbieraneho kusovnika
        # (audit #15) — okno Materialy na to malo vlastny `Ids` sken modelu
        # a v Studiu by to bol DRUHY prechod modelom pri KAZDOM prepocte.
        # Rozdiel oproti oknu je priznany a vedomy: sekcia rata to, co je
        # naozaj vo VYROBE (ten isty zdroj ako Kusovnik).
        def mat_payload(model, collected)
          # Mapy `material_id/abs_id => kluc skupiny` sa stavia RAZ (review #5):
          # obidve prechadzaju cely katalog a pocty aj rozpis su dva pohlady na
          # TEN ISTY zber — dva nezavisle prechody katalogom pri kazdom pushi by
          # boli zbytocne (a mohli by sa rozist, keby medzi nimi prisiel zapis).
          keys = Materials.decor_key_by_material_id
          abs_keys = Materials.decor_key_by_abs_id
          out = { 'project' => Materials.project_defaults(model),
                  'cabinets' => collected[:cabinets].to_i,
                  'model_guid' => ProductionCore.model_guid(model),
                  'used' => mat_used(collected, keys),
                  'used_ids' => mat_used_ids(collected),
                  'used_where' => mat_used_where(collected, keys, abs_keys) }
          # Cely katalog LEN pri prvom pushi okna a po prepnuti dokumentu;
          # inak ho drzi klient a zmeny mu chodia echom.
          out['catalog'] = MaterialsDialog.catalog_payload if @mat_full_pending && defined?(MaterialsDialog)
          out
        rescue StandardError => e
          # Review #1: zlyhanie sa NEZAMLCUJE. Sekcia ostane bez dat a jedina
          # stopa po tom, PRECO, je tento zaznam — zapadka `@mat_full_pending`
          # pritom ostava zdvihnuta, takze najblizsi push katalog dosle.
          Engine.log_error(e, 'StudioDialog.mat_payload')
          nil
        end

        # PICKER-2: skupina „Použité v projekte" vo VYHĽADÁVAČI predvolieb.
        # Vyhľadávač pýta ZOZNAM ID (rovnako ako v Inspectore), kým `used`
        # nesie počty pod kľúčom skupiny — to sú dva rôzne tvary a mapovať
        # jeden na druhý v kliente by znamenalo hádať. Berie sa to preto z TOHO
        # ISTÉHO zberu (`collected[:records]`, žiadny druhý prechod modelom)
        # a tvar je zhodný s panelovým `used_ids_payload`, takže obe okná majú
        # jeden a ten istý klientsky hook.
        #
        # Na rozdiel od `used_where` sa tu dielec BEZ `owner_id` nevyhadzuje:
        # tam ide o klikateľného vlastníka, tu o holú otázku „je tento materiál
        # v zákazke?" — a odpojený dielec v nej je.
        def mat_used_ids(collected)
          sheets = {}
          edges = {}
          Array(collected[:records]).each do |r|
            id = r['material_id'].to_s
            sheets[id] = true unless id.empty?
            e = r['edges'].is_a?(Hash) ? r['edges'] : {}
            e.each_value do |abs_id|
              aid = abs_id.to_s
              edges[aid] = true unless aid.empty?
            end
          end
          { 'sheets' => sheets.keys, 'edges' => edges.keys }
        end

        def mat_used(collected, key_by_id = nil)
          key_by_id ||= Materials.decor_key_by_material_id
          usage = Hash.new(0)
          Array(collected[:records]).each do |r|
            key = key_by_id[r['material_id']]
            next if key.nil? || key.empty?

            qty = r['quantity'].to_i
            usage[key] += qty.positive? ? qty : 1
          end
          usage
        end

        # ŠT-2d: „Kde sa používa" — ROZPIS toho isteho cisla, ktore uz nesie
        # `used`. Zdroj je ten isty (UZ zozbierany kusovnik, audit #15) a
        # prechod TEN ISTY — zoznam vlastnikov nie je druhy sken modelu, len
        # druhy pohlad na jeden.
        #
        # Tvar: { kluc skupiny => { 'owners' => [...], 'edges' => { abs_id => {…} } } }
        #   owners[] = { owner_id, parts, objects, roles (SK text zo servera),
        #                material_ids (co presne ma ten vlastnik z tejto
        #                skupiny — adresa pre klik „oko") },
        #   edges[id] = { parts, objects }.
        # Roly sklada SERVER (`ProductionCore.role_label`) — klient ziadny
        # preklad enumu rol nema a mat ho nema ani zacat.
        #
        # DVE CISLA, DVE OTAZKY (review #6): `parts` = KUSY (doska s
        # `quantity: 3` je 3 kusy do vyroby), `objects` = kolko ENTIT sa v
        # modeli naozaj oznaci. Pri dielcoch su rovnake, pri doskach nie —
        # a keby zoznam slubil „3 dielce" a stavovy riadok potom napisal
        # „Vybraných 1 položiek", vyzeralo by to ako chyba vyberu.
        def mat_used_where(collected, key_by_id = nil, abs_key_by_id = nil)
          key_by_id ||= Materials.decor_key_by_material_id
          abs_key_by_id ||= Materials.decor_key_by_abs_id
          out = {}
          Array(collected[:records]).each do |r|
            qty = r['quantity'].to_i
            qty = 1 unless qty.positive?
            mat_used_where_owner(out, key_by_id[r['material_id']], r, qty)
            mat_used_where_edges(out, abs_key_by_id, r, qty)
          end
          out.each_value { |g| g['owners'] = g['owners'].values }
          out
        end

        def mat_used_where_group(out, key)
          out[key] ||= { 'owners' => {}, 'edges' => {} }
        end

        def mat_used_where_owner(out, key, rec, qty)
          return if key.nil? || key.to_s.empty?

          oid = rec['owner_id'].to_s
          # Review #4: vlastnik BEZ IDENTITY sa nekresli. Riadok s prazdnym
          # `owner_id` (odpojeny dielec, ktory stratil `cabinet_id`) by po kliku
          # nemal co zuzit — server by dostal prazdne zuzenie a oznacil by cely
          # dekor. Dielec sa tym nestraca: v poctoch `used` aj v riadku „celej
          # skupiny" je dalej, len nema vlastny klikatelny riadok.
          return if oid.empty?

          g = mat_used_where_group(out, key)
          o = (g['owners'][oid] ||= { 'owner_id' => oid, 'parts' => 0, 'objects' => 0,
                                      'roles' => [], 'material_ids' => [] })
          o['parts'] += qty
          o['objects'] += 1
          label = ProductionCore.role_label(rec['role'])
          o['roles'] << label unless label.empty? || o['roles'].include?(label)
          mid = rec['material_id'].to_s
          o['material_ids'] << mid unless mid.empty? || o['material_ids'].include?(mid)
        end

        # Paska sa rata RAZ za dielec, aj ked je nou olepenych viac hran —
        # zoznam odpoveda na „kolko DIELCOV ma tuto pasku", nie na „kolko
        # hran".
        def mat_used_where_edges(out, abs_key_by_id, rec, qty)
          edges = rec['edges'].is_a?(Hash) ? rec['edges'] : {}
          seen = []
          edges.each_value do |abs_id|
            id = abs_id.to_s
            next if id.empty? || seen.include?(id)

            seen << id
            key = abs_key_by_id[id]
            next if key.nil? || key.to_s.empty?

            e = (mat_used_where_group(out, key)['edges'][id] ||= { 'parts' => 0, 'objects' => 0 })
            e['parts'] += qty
            e['objects'] += 1
          end
        end

        # --- ŠT-3a-1: sekcia KOVANIE (`hw`) ----------------------------------
        #
        # Kanal je ten isty vzor ako pri Materialoch:
        #   * KATALOGOVE ECHO (`push_hw_catalog`) — prepise LEN zoznam poloziek
        #     v okne, negeneruje prepocet a NEDVIHA generaciu,
        #   * PLNY PUSH (`push_state`) — nesie sety (menia nakupny zoznam)
        #     a pri prvom pushi aj cely katalog (`@hw_full_pending`).
        #
        # Telo kazdej akcie zije v `HardwareCatalogDialog` (modul sa
        # NEPREMENUVA — zanikne az jeho OKNO, v ŠT-3a-2); toto okno je jej
        # druhy vstup a odpoved si necha presmerovat cez `hw_sink`.
        def hw_actions
          defined?(HardwareCatalogDialog) ? HardwareCatalogDialog::SECTION_ACTIONS : []
        end

        def do_hw(name, payload)
          unless defined?(HardwareCatalogDialog)
            return set_status('Katalóg kovania nie je načítaný.', true)
          end

          HardwareCatalogDialog.dispatch(name, payload, hw_sink)
        end

        # Adresat odpovedi: TOTO okno. `HardwareCatalogDialog` posiela `MDH.*`
        # a `HWSETS.*` volania — sekcia ma presne tie iste prijimace, lebo bezi
        # na TOM ISTOM `js/hw_catalog.js` + `js/hw_sets.js`.
        def hw_sink
          ->(script) { js(script) }
        end

        # VEREJNY vstup pre `HardwareCatalogDialog` mimo synchronneho volania
        # sekcie (asynchronne vysledky overenia ceny a nahladu z Demosu
        # dobiehaju uz po navrate z `dispatch`). `js` je private, preto most.
        def hw_js(script)
          js(script)
        end

        # Odchod zo SEKCIE `hw`. Klient ho hlasi PRED prepnutim; server na to
        # zrusi beziaci fetch (vedome rozhodnutie — dovod v
        # `HardwareCatalogDialog#cancel_runs_on_leave`).
        def do_hw_leave(_payload = nil)
          return unless defined?(HardwareCatalogDialog)

          HardwareCatalogDialog.cancel_runs_on_leave
        end

        # Katalogove echo. Payload sa smie PODAT (`push_items` ho uz zostavil —
        # druhy vypocet `row_rev` pre kazdu polozku by bol zbytocny).
        def push_hw_catalog(payload = nil)
          return unless defined?(HardwareCatalogDialog)

          data = payload || HardwareCatalogDialog.items_payload
          js("if (window.NX && NX.setHwCatalog) NX.setHwCatalog(#{data.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_hw_catalog')
        end

        # ZOTAVOVACIE echo setov (review P1 #1). Posiela ho VYHRADNE
        # `HardwareCatalogDialog#resync_sets` po ODMIETNUTOM zapise — sekcia
        # potrebuje cerstvu `revision`, inak by dalsi zapis poslala so starym
        # odtlackom a zacyklila sa v konfliktoch. Po USPESNOM zapise chodia
        # sety plnym `push_state` (menia aj nakupny zoznam), takze tu sa
        # generacia NEDVIHA a kusovnik sa neprepocitava.
        def push_hw_sets(payload = nil)
          return unless defined?(HardwareCatalogDialog)

          data = payload || HardwareCatalogDialog.sets_payload
          js("if (window.NX && NX.setHwSets) NX.setHwSets(#{data.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.push_hw_sets')
        end

        # Payload sekcie. SETY chodia VZDY (su modelovym kontextom — snapshot
        # predvolieb zije na modeli a rozhoduje o nakupnom zozname); CELY
        # KATALOG len pri prvom pushi okna, po prepnuti dokumentu a po rucnom
        # „Obnoviť" — inak by sa `row_rev` kazdej polozky pocital pri KAZDOM
        # prepocte kusovnika (ta ista lekcia ako `@mat_full_pending`).
        def hw_payload(model)
          return nil unless defined?(HardwareCatalogDialog)

          # F4: sets_payload dostava NAS model — pri prepnuti dokumentu by
          # inak sekcia dostala predvolby STAREHO dokumentu vedla kusovnika
          # noveho (`Sketchup.active_model` sa v case broadcastu este
          # nemusel prepnut).
          out = { 'sets' => HardwareCatalogDialog.sets_payload(model),
                  'model_guid' => ProductionCore.model_guid(model) }
          out['catalog'] = HardwareCatalogDialog.state_payload if @hw_full_pending
          out
        rescue StandardError => e
          # Zlyhanie sa NEZAMLCUJE (rovnaka lekcia ako `mat_payload`): sekcia
          # ostane bez dat a jedinou stopou preco je tento zaznam. Zapadka
          # `@hw_full_pending` pritom ostava zdvihnuta.
          Engine.log_error(e, 'StudioDialog.hw_payload')
          nil
        end

        # --- ŠT-3b-1: sekcia PRAVIDLÁ (`rules`) ----------------------------
        #
        # Presun formulára okna „Pravidlá kovania" (Š17, skupina „Kovanie podľa
        # rozmerov"). Kanal je vzor `hw`, len JEDNODUCHSI: modul nema ziadny
        # asynchronny beh, takze netreba session token ani odchodovy hook.
        #
        # Stav sekcie chodi PLNYM pushom pod klucom `rules` — ziadna zapadka
        # (`full_pending`): pravidla su maly JSON (jednotky zaznamov, ziadne
        # `row_rev` per polozka ako katalog), takze plny payload pri kazdom
        # pushi je lacnejsi nez druhy kanal.
        def rules_actions
          defined?(RulesDialog) ? RulesDialog::SECTION_ACTIONS : []
        end

        def do_rules(name, payload)
          return set_status('Pravidlá kovania nie sú načítané.', true) unless defined?(RulesDialog)

          RulesDialog.dispatch(name, payload, rules_sink)
        end

        # Adresat odpovedi: TOTO okno. `RulesDialog` posiela `RD.*` volania —
        # sekcia ma presne tie iste prijimace, lebo bezi na TOM ISTOM
        # `js/rules.js`.
        def rules_sink
          ->(script) { js(script) }
        end

        # VEREJNY vstup pre `RulesDialog` mimo synchronneho volania sekcie
        # (`js` je private, patri kanalu okna) — vzor `hw_js`.
        def rules_js(script)
          js(script)
        end

        # ŠT-3b-2b: VEREJNY citatel generacie okna. `@generation` je private stav
        # KANALA okna, ale zapisove akcie SEKCIE ho potrebuju na ten isty guard,
        # aky ma klik v Kusovniku: klik zo ZASTARANEHO zoznamu (riadok, ktory uz
        # neplati) sa nesmie vykonat. Cita sa, nikdy nenastavuje — generaciu
        # zdviha VYHRADNE `push_state`.
        def generation
          @generation.to_i
        end

        # ŠT-3c-1, sekcia ŠABLÓNY (Š18). Kanal je vzor `rules`, len JEDNODUCHSI:
        # sablony su GLOBALNE (subor v %APPDATA%), takze payload nepotrebuje
        # model, sekcia nema ziadny asynchronny beh a po prepnuti dokumentu
        # netreba nic rusit.
        def tpl_actions
          defined?(TemplatesDialog) ? TemplatesDialog::SECTION_ACTIONS : []
        end

        def do_tpl(name, payload)
          return set_status('Šablóny nie sú načítané.', true) unless defined?(TemplatesDialog)

          TemplatesDialog.dispatch(name, payload, tpl_sink)
        end

        # Adresat odpovedi: TOTO okno. `TemplatesDialog` posiela `TPL.*` volania
        # — sekcia ma presne tie iste prijimace, lebo bezi na TOM ISTOM
        # `js/templates.js`.
        def tpl_sink
          ->(script) { js(script) }
        end

        # VEREJNY vstup pre `TemplatesDialog` mimo synchronneho volania sekcie
        # (`js` je private, patri kanalu okna) — vzor `rules_js`.
        def tpl_js(script)
          js(script)
        end

        # Payload sekcie. Model sa NEODOVZDAVA — sablony su globalne a s
        # dokumentom nemaju nic spolocne (jedina taka sekcia okna).
        def tpl_payload
          return nil unless defined?(TemplatesDialog)

          TemplatesDialog.tpl_payload
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.tpl_payload')
          nil
        end

        # ŠT-3b-2a: `collected` chodi TIEZ argumentom — jantarove riadky rucnych
        # zasahov sa citaju z UZ HOTOVEHO zberu (`manual_overrides`), takze sekcia
        # nespusta ziadny druhy sken modelu.
        def rules_payload(model, collected = nil)
          return nil unless defined?(RulesDialog)

          RulesDialog.rules_payload(model, collected)
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.rules_payload')
          nil
        end

        # ŠT-4a, sekcie NASTAVENIA (`sup` · `bset` · `about`, Š19). Kanal je
        # vzor `rules`, len JEDNODUCHSI: nastavenia su GLOBALNE (subor
        # v %APPDATA%), takze payload nepotrebuje model — rovnako ako sablony.
        def settings_actions
          defined?(SupplierSettingsDialog) ? SupplierSettingsDialog::SECTION_ACTIONS : []
        end

        def do_settings(name, payload)
          return set_status('Nastavenia nie su nacitane.', true) unless defined?(SupplierSettingsDialog)

          SupplierSettingsDialog.dispatch(name, payload, settings_sink)
        end

        # Adresat odpovedi: TOTO okno. `SupplierSettingsDialog` posiela `SS.*`
        # volania — sekcia ma presne tie iste prijimace, lebo bezi na TOM ISTOM
        # `js/studio_settings.js`.
        def settings_sink
          ->(script) { js(script) }
        end

        # Verejny most kanala sekcie (vzor `rules_js`) — `js` je private.
        def settings_js(script)
          js(script)
        end

        # Payload sekcii nastaveni. Model sa NEODOVZDAVA (nastavenia su
        # globalne); zlyhanie sa NEZAMLCUJE — sekcia dostane `nil` a povie to.
        def settings_payload
          return nil unless defined?(SupplierSettingsDialog)

          SupplierSettingsDialog.settings_payload
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.settings_payload')
          nil
        end

        private

        # Callbacky, ktorymi sa okno prihlasi do zdielaneho jadra.
        def status_proc
          ->(msg, error = false) { set_status(msg, error) }
        end

        def repush_proc
          -> { refresh_if_open }
        end

        # ŠT-1c PR B1 (audit #1): refresh po mutacii ROZPOCTU. Plny payload,
        # ale BEZ zdvihu generacie — inak by kazdy prepis sumy zneplatnil
        # rozkliknuty riadok Kusovnika a rozrobeny export inej sekcie.
        #
        # Review #3: JEDINA refresh cesta okna, ktora si nesmie dovolit vynimku.
        # `ProductionCore.do_budget` vola `repush` aj vo svojej rescue vetve —
        # keby prvy pokus vybuchol, druhy by uz bezal MIMO rescue, vyletel by
        # z callbacku a klient by nedostal payload; jeho fronta zapisov by
        # potom visela az do 6 s poistky (`BUD_BUSY_MS`).
        def budget_repush_proc
          lambda do
            push_state(bump: false) if @dialog && @dialog.visible?
          rescue StandardError => e
            Engine.log_error(e, 'StudioDialog.budget_repush')
          end
        end

        # Vysledok mutacie ide do okna PRED cerstvym payloadom — rozpisany
        # draft sa smie zavriet LEN pri uspechu (GH #138 P2).
        def budget_result_proc
          lambda do |op, ok|
            js("if (window.NX && NX.budgetResult) NX.budgetResult(#{op.to_s.to_json}, #{ok ? 'true' : 'false'});")
          end
        end

        # E-c „Prepočítať ceny": fazove okno riadi SERVER, toto je len echo do
        # TOHTO okna.
        def price_refresh_emit_proc
          ->(event) { js("if (window.NX && NX.priceRefresh) NX.priceRefresh(#{event.to_json});") }
        end

        # Zivotnost behu = TA ISTA instancia okna, z ktorej sa spustil (vzor
        # MaterialsDialog.demos_alive_proc): zavretie okna pocas fetchu a jeho
        # znovuotvorenie NESMIE opusteny beh „ozivit". Prepnutie MODELU beh
        # nezastavi — ceny idu do katalogu, ktory je globalny.
        def price_refresh_alive_proc(dlg)
          -> { !dlg.nil? && !@dialog.nil? && @dialog.equal?(dlg) && dlg.visible? }
        end

        # Po dobehnuti prepoctu: ceny sa zmenili GLOBALNE, takze cerstve cisla
        # potrebuje aj katalog materialov, panel a katalog kovania. Tento push
        # generaciu ZDVIHA (nie je to mutacia rozpoctu — zmenil sa katalog).
        #
        # ŠT-1c PR B3: okno Vyroba zo zoznamu vypadlo — zaniklo. Kontrakt
        # „KAZDE okno s cislami zakazky je vo VSETKYCH refresh cestach" plati
        # dalej: prepocet cien meni cisla GLOBALNE, takze cerstve data dostane
        # toto okno, katalog materialov, panel aj katalog kovania.
        def price_refresh_after_proc
          lambda do
            push_state
            # ŠT-2a/2b: cerstve ceny potrebuje aj SEKCIA Materialy tohto okna —
            # `push_state` vyssie nesie modelovy kontext, nie katalog.
            # (Vetva satelitneho okna tu zanikla spolu s nim v ŠT-2b.)
            push_mat_catalog
            Panel.push_materials if defined?(Panel)
            # ŠT-3a-1: `push_items` uz obsluhuje OBA ciele (okno + sekcia `hw`)
            # a vie si vypytat aj plny push Studia — ten sme ale prave spravili
            # sami, takze `refresh_studio: false` (inak by sa cely kusovnik
            # prepocital dvakrat za sebou).
            HardwareCatalogDialog.push_items(refresh_studio: false) if defined?(HardwareCatalogDialog)
          end
        end

        # Echo prepinacov (ŠT-1b): odmietnuta akcia musi vratit listu sekcie na
        # PRAVDIVY stav — bez prepoctu celej sekcie.
        def edge_echo_proc
          -> { push_edge_check }
        end

        def grain_echo_proc
          -> { push_grain_check }
        end

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Štúdio',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            # D-51/D-77: JEDNA PRAVDA je OBSAHOVY viewport 1060 × 640
            # (`NX_FIT_MIN` v studio.html) — navigacia 208 px + tabulka
            # kusovnika so 7 stlpcami a stlpcom akcii. Rozmery tu su
            # VONKAJSIE (obsah + ramik okna ≈ 16 × 40 px). Platia LEN pri
            # PRVOM otvoreni — zapamatane male okno dorovna `nx_fit`.
            width: 1076,
            height: 680,
            min_width: 1076,
            min_height: 520,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'studio.html'))
          # ŠT-2a (audit #8, vzor MaterialsDialog): HTML okna este NEBEZI —
          # `execute_script` poslany pred nacitanim CEF potichu ZAHODI. Priznak
          # sa zapne az v `ready` callbacku. Dnes ho nikto nekontroluje (kazdy
          # push ide reaktivne az po `ready`), ŠT-2b na nom postavi odlozenu
          # poziadavku „Nahradiť UNI…" v tomto okne.
          @ready = false
          # Prvy push po otvoreni musi niest CELY katalog materialov — sekcia
          # `mat` zacina s prazdnymi rukami (dalsie pushe uz len echo, audit #15).
          @mat_full_pending = true
          @hw_full_pending = true # ŠT-3a-1: to iste pre sekciu `hw`
          register_callbacks(@dialog) # pred show!
          # Bez vynulovania by dalsie otvorenie ozivilo referenciu na mrtve
          # okno a kazdy push by tichol na vynimke (audit #14).
          @dialog.set_on_closed do
            detach_stale_observer
            @ready = false
            @mat_full_pending = true # dalsie otvorenie zacina bez katalogu
            @hw_full_pending = true  # ŠT-3a-1: to iste pre katalog kovania
            # ŠT-2b: zatvorenim tohto okna zaniklo JEDINE UI katalogu — bezaci
            # Demos fetch sa zneplatni (ABA: nova instancia okna nesmie dostat
            # eventy starej) a odlozena poziadavka „Nahradiť UNI…" zomiera s nim.
            # Review #7: JEDNA cesta — `on_ui_closed` zahadzuje aj odlozenu
            # poziadavku „Nahradiť UNI…" (dve API na to iste by sa casom
            # rozisli a jedno by sa zabudlo zavolat).
            MaterialsDialog.on_ui_closed if defined?(MaterialsDialog)
            # ŠT-3a-1: to iste pre sekciu Kovanie — beziace overenie ceny
            # ci nahlad z Demosu uz nema komu prist (session bump, ABA guard).
            HardwareCatalogDialog.on_ui_closed if defined?(HardwareCatalogDialog)
            @dialog = nil
          end
          # Indikator neaktualnosti zije PRESNE tak dlho ako okno.
          attach_stale_observer(Sketchup.active_model)
          @dialog
        end

        def register_callbacks(dlg)
          Engine.register_dialog_fit(dlg, 'studio') # D-77 + UI-01 tema
          # ŠT-2b: `flush_pending_replace_uni` AZ ZA `push_state` — modal
          # „Nahradiť UNI…" potrebuje v kliente CELY katalog (hlada v nom
          # dlazdicu k `uni_id`) a deep-link na sekciu `mat`.
          cb(dlg, 'ready') do |_p|
            @ready = true
            push_state
            MaterialsDialog.flush_pending_replace_uni if defined?(MaterialsDialog)
          end
          # SMOKE 22.8.: NIE `push_state` priamo — po prepocte musi prist aj
          # hlaska, inak v okne navzdy visi klientske „Prepočítavam…".
          cb(dlg, 'refresh_bom')  { |_p| do_refresh_bom }
          # Š3: klik na riadok / oko = oznac v modeli, ceruzka = oznac + zdvihni
          # Inspector (`focus_inspector`). Obe cesty su ten isty handler.
          cb(dlg, 'nx_select')    { |p| handle_select(p) }
          cb(dlg, 'vepo_export')  { |p| handle_export(p) }
          # ŠT-1c PR A: CSV nakupneho zoznamu (lista sekcie Nakup kovania) —
          # ten isty flush handshake ako VEPO, len vlastnym kanalom Studia.
          cb(dlg, 'hw_csv_export') { |p| handle_hw_csv(p) }
          cb(dlg, 'studio_set_vepo_opts') { |p| do_set_vepo_opts(p) }
          # ŠT-1b, sekcia KONTROLA. Klik na riadok ide uz existujucou cestou
          # `nx_select` (nesie `problem_key`); tieto callbacky su akcie riadku
          # a lista sekcie. Ziadny flush handshake — nic z toho model nemeni.
          cb(dlg, 'replace_uni')          { |p| do_replace_uni(p) }
          cb(dlg, 'edge_check_toggle')    { |p| do_edge_check(p) }
          cb(dlg, 'edge_check_option')    { |p| do_edge_check_option(p) }
          # Otvorenie 3-stavoveho nastavenia zavrie jeho kopiu v raile
          # (nikdy dve naraz).
          cb(dlg, 'edge_menu_open')       { |_p| Engine.close_edge_menu(:studio) }
          cb(dlg, 'grain_check_toggle')   { |p| do_grain_check(p) }
          # ŠT-1c PR B1, sekcia ROZPOCET. Mutacia (`budget_mutate`) ide PRIAMO —
          # nie je to export a flush handshake by pri kazdom prepise sumy
          # zbytocne prehnal rozpisane edity panela. Oba XLSX exporty naopak
          # flush handshake MAJU (cisla harku musia sediet s modelom po flushi).
          cb(dlg, 'budget_mutate')   { |p| do_budget(p) }
          cb(dlg, 'budget_xlsx')     { |p| handle_budget_xlsx(p) }
          cb(dlg, 'cp_xlsx')         { |p| handle_cp_xlsx(p) }
          cb(dlg, 'budget_open_url') { |p| handle_budget_url(p) }
          # ŠT-4a: `budget_settings` (⚙ v liste Rozpoctu otvarala SATELIT) ZANIKLO —
          # sadzby su SEKCIA `bset` TOHTO okna, takze prepnutie je cisto klientske
          # (`studioGoSection('bset')`). Server o prepnuti sekcie vediet nemusi.
          # E-c: „Prepočítať ceny" — hromadne obnovenie cien z Demosu.
          cb(dlg, 'price_refresh')        { |p| handle_price_refresh(p) }
          cb(dlg, 'price_refresh_cancel') { |_p| ProductionCore.price_refresh_cancel(status: status_proc) }
          # ŠT-2a, sekcia MATERIALY. Mena callbackov su TIE ISTE ako v okne
          # Materialy — presunuty JS (`js/proj_materials.js`) tak vola presne
          # to, co volal doteraz, a nikde nevznika druha kopia payloadu.
          # Telo je v `MaterialsDialog`, sem chodi len odpoved (`mat_sink`).
          mat_actions.each { |name| cb(dlg, name) { |p| do_mat(name, p) } }
          # ŠT-2b: `mat_open_window` (premostenie do zaniknuteho okna) ZANIKLO.
          # Namiesto neho hlasi klient ODCHOD zo sekcie — bezaci Demos fetch
          # sa vtedy zrusi (vedome, viz `do_mat_leave`).
          cb(dlg, 'mat_leave')            { |p| do_mat_leave(p) }
          # ŠT-3a-1, sekcia KOVANIE. Mena callbackov su TIE ISTE, ake pouziva
          # okno „Katalóg kovania" — presunuty JS (`js/hw_catalog.js`,
          # `js/hw_sets.js`) tak vola presne to, co volal doteraz, a nikde
          # nevznika druha kopia payloadu. Telo je v `HardwareCatalogDialog`,
          # sem chodi len odpoved (`hw_sink`).
          hw_actions.each { |name| cb(dlg, name) { |p| do_hw(name, p) } }
          cb(dlg, 'hw_leave')             { |p| do_hw_leave(p) }
          # ŠT-3b-1, sekcia PRAVIDLÁ. Mena callbackov su TIE ISTE, ake
          # pouzivalo okno „Pravidlá kovania" — presunuty JS (`js/rules.js`)
          # tak vola presne to, co volal doteraz. Telo je v `RulesDialog`,
          # sem chodi len odpoved (`rules_sink`).
          rules_actions.each { |name| cb(dlg, name) { |p| do_rules(name, p) } }
          # ŠT-3c-1, sekcia ŠABLÓNY. Mena callbackov su TIE ISTE, ake pouzivalo
          # okno „Šablóny" (`tpl_apply`/`tpl_delete`/`tpl_capture`) + vlastny
          # PNG kanal sekcie (`tpl_preview`). Telo je v `TemplatesDialog`.
          tpl_actions.each { |name| cb(dlg, name) { |p| do_tpl(name, p) } }
          # ŠT-4a, sekcie NASTAVENIA. Mena su prefixovane `ss_` (`save`/`reload`
          # z okna by sa zrazili s callbackmi okna aj inych sekcii). Telo je
          # v `SupplierSettingsDialog`, sem chodi len odpoved (`settings_sink`).
          settings_actions.each { |name| cb(dlg, name) { |p| do_settings(name, p) } }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(studio): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'studio js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "studio cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # Klik z okna: cez panel (flush handshake) alebo priamo, ak panel nezije.
        # Relay ma VLASTNE meno (`studioRelay`), aby odpoved prisla do TOHTO
        # okna — kazdy klient ma vlastny `gen` a cudzi push by klik odmietol.
        def handle_select(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelay(#{data.to_json})")
          else
            do_select(data)
          end
        end

        def handle_export(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayExport(#{data.to_json})")
          else
            do_export(data)
          end
        end

        # ŠT-1c PR A: CSV kovania ide TYM ISTYM flush handshakom ako VEPO —
        # rozpisany edit panela meni pocty kovania, takze by sa objednavalo zo
        # starych cisel. Vlastny relay (`studioRelayHwCsv`), aby odpoved prisla
        # do TOHTO okna (kazde okno ma vlastny `gen`).
        def handle_hw_csv(payload)
          data = JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayHwCsv(#{data.to_json})")
          else
            do_hw_csv(data)
          end
        end

        # ŠT-1c PR B1: XLSX rozpoctu a zakaznicka cenova ponuka — TEN ISTY flush
        # handshake ako VEPO/CSV, vlastnym kanalom Studia (odpoved musi prist do
        # TOHTO okna; cudzi push by mu klik odmietol).
        #
        # Review PR #198 #7: payload sa berie TOLERANTNE (`Hash` alebo JSON
        # retazec) ako vsade inde v tomto subore. Ked panel nezije, vetva
        # `else` odovzdava uz ROZPARSOVANY Hash — a `JSON.parse(hash.to_s)` by
        # na nom spadol; rovnaka pastka by cakala na kazde volanie z testu ci
        # z ineho Ruby miesta.
        def handle_budget_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayBudget(#{data.to_json})")
          else
            do_budget_xlsx(data)
          end
        end

        def handle_cp_xlsx(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          if Panel.dialog_alive?
            Panel.js("NX.studioRelayCp(#{data.to_json})")
          else
            do_cp_xlsx(data)
          end
        end

        # ↗ v riadku rozpoctu — adresa sa dohladava v modeli podla ID polozky a
        # este raz sanitizuje (z klienta nechodi).
        def handle_budget_url(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.budget_open_url(Sketchup.active_model, data, status: status_proc)
        end

        # E-c: beh riadi SERVER (`core/price_refresh.rb`) — okno odovzdava svoje
        # echo, svoju zivotnost a svoje refresh cesty.
        def handle_price_refresh(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          ProductionCore.do_price_refresh(Sketchup.active_model, data,
                                          generation: @generation, status: status_proc,
                                          repush: repush_proc, emit: price_refresh_emit_proc,
                                          alive: price_refresh_alive_proc(@dialog),
                                          after: price_refresh_after_proc)
        end

        # Payload OKNA (sekcie Kusovnik + Kontrola). Cisla su TIE ISTE, ktore
        # nesie zdielane jadro (`ProductionCore`) — Studio nema vlastny vypocet a JS
        # si NIC neprepocitava (ani sumy, ani medzisucty skupin, ani counts).
        # JEDEN push nesie obe sekcie zamerne: prepnutie sekcie je cisto
        # zobrazovacie, takze nesmie chodit na server po data.
        # `bump: false` = ROZPOCTOVY push (audit #1). Payload je plny, ale
        # generacia okna sa NEDVIHA: mutacia rozpoctu nemeni `rows`/`refs`,
        # takze pending klik ci export inej sekcie ostava platny. Prvy push
        # generaciu zdvihne VZDY (gen 0 by sa rovnal „ziadne data").
        def push_state(bump: true)
          @generation = @generation.to_i + 1 if bump || @generation.to_i.zero?
          model = Sketchup.active_model
          collected = ProductionCore.fresh_collect(model)
          bom = Bom.compute(collected)
          smap = ProductionCore.sheets_map
          sheet_sizes = smap.each_with_object({}) { |(id, s), out| out[id] = s['sheet_size'] }
          # D-19: odhad platni per material — JEDEN vypocet pre kusovnik aj rozpocet.
          estimate = SheetEstimate.estimate(
            bom[:rows], sheet_sizes: sheet_sizes,
            uni_ids: smap.each_with_object({}) { |(id, s), out| out[id] = true if Materials.uni?(s) }
          )
          # ŠT-1b (audit #2): KONTROLA z TOHO ISTEHO cerstveho zberu a z TOHO
          # ISTEHO jadra (`ProductionCore`) — vratane upozorneni ROZPOCTU. Semafor
          # sekcie, badge navigacie aj suhrn exportu tak ukazuju JEDNO cislo.
          # (⚠ chip Inspectora je nieco ine — build warnings oznacenej skrinky;
          # do tejto sekcie len VEDIE deep-linkom.)
          # ŠT-1c PR B1: rozpocet uz nie je len zdroj ORANGE nalezov — je to
          # payload SEKCIE `budget` tohto okna. Pocita sa RAZ a slúzi obom
          # (Kontrola z neho berie svoje upozornenia), z uz hotoveho odhadu
          # platni — ziadny druhy vypocet.
          hw_exp = ProductionCore.hardware_expansion(model, collected)
          budget = ProductionCore.budget_payload(model, bom, collected, estimate, hw_exp, smap)
          control = ProductionCore.control_payload(collected, hardware_expansion: hw_exp,
                                                              budget: budget, sheets: smap)
          data = {
            version: Engine::VERSION,
            gen: @generation,
            model_title: (model.title.to_s.empty? ? 'Bez názvu' : model.title.to_s),
            model_guid: ProductionCore.model_guid(model),
            # Š2: riadky obohatene o `role_label` (server sklada aj tento text).
            rows: ProductionCore.rows_with_roles(bom[:rows], collected),
            sheets: bom[:sheets], edging: bom[:edging],
            # ŠT-1c PR A (Š7), sekcia NAKUP KOVANIA — presun tabu Kovanie 1:1.
            # `hardware_sets` = nakupny zoznam zo setov (rows/unmapped/summary
            # + stav snapshotu setov projektu: invalid = banner, missing =
            # global default); `hardware` = generika podla pravidiel, obohatena
            # o SERVEROVE texty `label` a `params_label` (audit #3 — obohatenie
            # zije v jadre, nie v okne). Zoznam sa POCITA UZ VYSSIE (`hw_exp`)
            # kvoli ORANGE nalezom Kontroly — ziadny druhy vypocet.
            hardware: ProductionCore.hardware_labeled(bom),
            hardware_sets: hw_exp,
            summary: bom[:summary],
            sheet_estimate: estimate,
            # Š1 sucty: KAZDE cislo suctoveho riadku pocita SERVER — JS si
            # neprepocitava ani m², ani odhad platni (vzor rozpoctu: klient
            # z payloadu LEN cita).
            totals: totals_payload(bom, estimate),
            # audit #4: popisky, farby a hrubky materialov/pasok zo SERVERA —
            # klient nema druhu pravdu o tom, ako sa material vola.
            materials_meta: ProductionCore.materials_meta(bom),
            edges_meta: ProductionCore.edges_meta(bom),
            # audit #1 + #16: nazov projektu aj merge chodia v KAZDOM pushi,
            # takze sa lista nikdy nerozide s tym, co plati pre exporty.
            vepo: { project: ProductionCore.project_name(model),
                    default_project: ProductionCore.default_project_name(model),
                    merge_18_36: ProductionCore.merge_18_36 },
            # ŠT-1b, sekcia KONTROLA (Š8–Š11). `counts` nesie aj ZELENE cislo
            # („skriniek bez nálezu") — JS si zo zoznamu NIC neprepocitava, ani
            # badge navigacie. Filter chipov je cisto zobrazovacia vec klienta.
            control: control['items'], counts: control['counts'],
            # ŠT-1c PR B1, sekcia ROZPOCET (Š12–Š13): cely rozpocet zakazky
            # (sekcie, sumy, vek cien, upozornenia, nahlad cenovej ponuky).
            # JS z neho LEN cita — ZIADNA suma sa v prehliadaci nepocita.
            budget: budget,
            # Š10: stav oboch prepinacov listy. Vypnuty prepinac nic neskenuje.
            edge_check: (defined?(EdgeCheck) ? EdgeCheck.ui_state(model) : nil),
            grain_check: (defined?(GrainCheck) ? GrainCheck.ui_state(model) : nil),
            # ŠT-2a, sekcia MATERIALY: modelovy kontext (predvolby projektu,
            # pocet skriniek, identita dokumentu a pocty „Použité v projekte").
            # KATALOG v nom je LEN pri prvom pushi okna a po prepnuti dokumentu
            # — inak ho klient drzi a zmeny mu chodia lacnym echom
            # (`push_mat_catalog`). Bez toho by KAZDY prepocet kusovnika
            # prepocitaval aj `row_rev` kazdeho zaznamu katalogu.
            mat: mat_payload(model, collected),
            # ŠT-3a-1, sekcia KOVANIE: sety (modelovy snapshot predvolieb)
            # a pri prvom pushi / po prepnuti dokumentu / po rucnom „Obnoviť"
            # aj cely katalog poloziek. Inak katalog drzi klient a zmeny mu
            # chodia lacnym echom (`push_hw_catalog`).
            hw: hw_payload(model),
            # ŠT-3b-1, sekcia PRAVIDLÁ: pravidla kovania projektu (alebo
            # globalne predvolby, kym projekt vlastne nema) + pocet skriniek,
            # ktore ulozenie prestavia. Maly JSON — chodi CELY pri kazdom pushi.
            # ŠT-3b-2a: navyse ABS pravidla podla roly (read-only) a jantarove
            # riadky rucnych zasahov — tie sa citaju z UZ HOTOVEHO `collected`.
            rules: rules_payload(model, collected),
            # ŠT-3c-1, sekcia ŠABLÓNY: kniznica sablon (korpusove + doskove)
            # s transientnym `preview_rev`. Model sa nepouziva — sablony su
            # GLOBALNE. Samotne PNG chodi vlastnym PULL kanalom (`tpl_preview`).
            tpl: tpl_payload,
            settings: settings_payload,
            # Deep-link: sekcia sa posiela PRAVE RAZ (inak by kazdy refresh
            # vratil pouzivatela tam, odkial medzitym odisiel).
            open_section: consume_pending_section,
            anchor: consume_pending_anchor
          }
          # Review #6: vysledok `js` sa PREPOSIELA — `do_refresh_bom` podla neho
          # rozhoduje, ci smie napisat „Prepočítané.". Ostatni volajuci ho
          # ignoruju (push do zavreteho okna nie je chyba).
          # SAMOLIECBA (review #1): okno prave pocita cisla z `model` — ak na nom
          # observer nevisi (zmeskany alebo zle nacasovany broadcast prepnutia
          # dokumentu), prevesi sa TERAZ. Bez toho by okno tichlo navzdy: cisla
          # by chodili z jedneho dokumentu a signal o zmene z ineho.
          attach_stale_observer(model) if @observer_model && @observer_model != model
          sent = js("NX.setStudio(#{data.to_json})")
          # EPOCHA „co uz je v okne". Uklada sa AZ TU — po `fresh_collect`
          # (od 1b-3 uz ciste citanie) aj po zapise rozpoctu,
          # takze vlastne ticky okna sa pohltia a tlacidlo po vlastnom
          # prepocte NEZOZLTNE. A LEN ked payload naozaj odosiel (review #6):
          # co klient nedostal, to v okne aktualne nie je.
          @pushed_epoch = @epoch.to_i if sent
          # Katalog materialov je v okne AZ TERAZ — dalsie pushe uz nesu len
          # modelovy kontext.
          #
          # Review #1: zapadka sa NESMIE gasit len preto, ze payload odosiel.
          # `mat_payload` ma vlastny rescue (vracia `nil`) a katalog v nom je
          # podmieneny — keby sa vtedy zapadka zhasla, sekcia Materialy by
          # ostala NAVZDY prazdna a BEZ hlasky: dalsie pushe uz katalog
          # neposielaju a echo prichadza az po cudzom zapise. Preto sa gasi
          # LEN vtedy, ked katalog v odoslanom payloade REALNE bol.
          @mat_full_pending = false if sent && data[:mat].is_a?(Hash) && data[:mat]['catalog']
          # ŠT-3a-1: ta ista lekcia pre katalog kovania — zapadka padne LEN
          # ked katalog v odoslanom payloade REALNE bol (`hw_payload` ma
          # vlastny rescue a vracia `nil`).
          @hw_full_pending = false if sent && data[:hw].is_a?(Hash) && data[:hw]['catalog']
          sent
        end

        # Sucty suctoveho riadku (Š1) a hlavicky pohladov Platne/ABS.
        # Odhad platni je ROZSAH (10–25 % prerez) — posiela sa oboma koncami,
        # aby klient nemusel nic zaokruhlovat ani scitavat.
        def totals_payload(bom, estimate)
          s = bom[:summary] || {}
          est = Array(estimate)
          { 'parts' => s['quantity'].to_i, 'rows' => s['rows'].to_i,
            'm2' => s['m2_total'].to_f, 'bm' => s['bm_total'].to_f,
            'materials' => Array(bom[:sheets]).length,
            'edges' => Array(bom[:edging]).length,
            'plates_min' => est.sum { |e| e['count_min'].to_f }.round(1),
            'plates_max' => est.sum { |e| e['count_max'].to_f }.round(1) }
        end

        # Jednorazove prevzatie deep-link sekcie (viz `show`).
        def consume_pending_section
          s = @pending_section
          @pending_section = nil
          SECTIONS.include?(s.to_s) ? s.to_s : nil
        end

        # Kotva sa spotrebuje spolu so sekciou — bez sekcie by nemala kam sadnut.
        def consume_pending_anchor
          a = @pending_anchor
          @pending_anchor = nil
          a.to_s.empty? ? nil : a.to_s
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        # Review #6: vracia, CI script naozaj odosiel klientovi. Mrtve okno aj
        # vynimka `execute_script` su tu tiche (a maju byt — push do zavreteho
        # okna nie je chyba), ale volajuci, ktory pouzivatelovi nieco POTVRDZUJE,
        # to musi vediet rozlisit.
        def js(script)
          return false unless @dialog && @dialog.visible?
          # ŠT-2a review #6: kym okno neohlasilo `ready`, jeho HTML EST NEBEZI
          # — CEF taky `execute_script` potichu ZAHODI. Doteraz to bolo
          # neviditelne (`js` vracal true, hoci klient nedostal nic), takze
          # napr. broadcast echo prepinaca hran tesne po otvoreni okna sa
          # tvarilo ako dorucene. Odteraz sa taky push priznane zahodi: `false`
          # znamena „klient to nedostal" a volajuci, ktory nieco POTVRDZUJE
          # (`do_refresh_bom`), sa podla toho vie rozhodnut. Prvy push posiela
          # sam `ready` callback — ten priznak zapina PRED nim.
          return false unless @ready

          @dialog.execute_script(script)
          true
        rescue StandardError => e
          Engine.log_error(e, 'StudioDialog.js')
          false
        end
      end
    end
  end
end
