# frozen_string_literal: true
# Noxun Engine - DocKey: STABILNA identita dokumentu pre identity guardy.
#
# PRECO EXISTUJE (davka 1d/R-02b, priznany zvysok R-02/#264): vsetky identity
# guardy (Panel.foreign_document?, zony, tagy, Studio, Rules baseline, okno
# kovania) aj JS zrkadlo (nxModelGuid) stali na Sketchup::Model#guid — lenze
# SketchUp guid MENI pri KAZDOM ulozeni (dokumentovane pri PROJECT_NAMES_KEY
# v production_core.rb a v AUDIT_REGISTER R-04). Ctrl+S do ~400 ms po uprave
# pola panela tak vyzeral ako prepnutie dokumentu: debounced edit sa zahodil
# a nxDropDocState zmazal rozpisany stav. Tento modul je JEDINY zdroj hodnoty
# `model_guid` v payloadoch — meno pola na drote ostava (kontrakt R-02 sa
# nemeni), meni sa len hodnota.
#
# KONTRAKT IDENTITY: token rotuje UDALOSTOU vymeny dokumentu (`invalidate`
# z `onNewModel`/`onOpenModel`), NIE zivotom Ruby objektu.
#
# POZOR — TOTO JE OPRAVA POVODNEHO NAVRHU (review #267 P1-1). Prva verzia
# stala na predpoklade „File > Open vyrobi novy `Sketchup::Model` objekt,
# Windows stary ZNICI". Ten predpoklad je NEPRAVDIVY a repo to uz vie na
# inom mieste: **Windows drzi jeden dokument na proces a pri File > Open
# smie RECYKLOVAT ten isty `Model` objekt** (auditovane pri GHOST vkladani —
# `ui/panel/selection.rb` PanelAppObserver, `docs/architecture/construction.md`,
# review #268 P2-2, in-SU scenar GHOST 10). Na recyklovanom objekte by cache
# klucovana `object_id` + `equal?` vratila novemu dokumentu STARY token a
# padli by VSETKY TRI obrany R-02 naraz: `nxSetModelGuid` by zmenu nezbadal
# (rovnaka hodnota => ziadne `nxDropDocState`), zachytena identita v bufferi
# by sedela a `foreign_document?` by zapis PUSTIL — oneskoreny apply by ticho
# pristal v prave otvorenej cudzej zakazke. Preto sa na zanik objektu
# nespoliehame a rotujeme UDALOSTOU.
#
# CO rotaciu spusta a co NIE:
#   * `onNewModel` / `onOpenModel` -> `invalidate` = NOVA identita. Vzdy.
#   * `onActivateModel` NIE — na macOS je to prepnutie medzi UZ otvorenymi
#     dokumentmi; kazdy z nich ma vlastny objekt, svoj token si drzi a
#     rotacia pri navrate by klientovi zahodila drafty.
#   * ULOZENIE (Ctrl+S), PRVE ulozenie ani Save As NErotuju — ziadny observer
#     sa nekona a je to stale ten isty rozrobeny dokument; presne to je cela
#     pointa davky. (Codex audit R-02b, BLOCKER 3: rotacia BEZ udalosti nema
#     spolahlivu resync cestu ku klientom — sekcia Materialy drzi identitu az
#     do plneho payloadu, takze by sa po rotacii odmietala donekonecna.
#     Kopia .skp suboru nebezpeci nie je: otvara sa cez `onOpenModel`.)
#
#     SAVE AS VYSLOVNE (namietka Codex kola 3, ZAMIETNUTA): Save As je
#     POKRACOVANIE TOHO ISTEHO dokumentu — identicky obsah, len ina cesta.
#     **Edit naplanovany PRED Save As sa aplikuje do premenovaneho suboru —
#     a je to ZIADUCE, je to ten isty dokument.** Rotacia identity pri Save As
#     by vratila presne povodny bug R-02: rozpisana uprava panela by sa pri
#     ulozeni ticho zahodila ako „patri inemu dokumentu". Ziaden dokument
#     sa pritom nevymiena — z povodneho suboru sa nestane druhe otvorene
#     okno, takze niet komu identitu prekrizit.
#
# `invalidate` volaju OBA AppObservery pluginu — `Panel::PanelAppObserver`
# (existuje len s otvorenym Inspectorom, ale rotuje PRED `on_model_switched`,
# teda pred pushom do panela) aj `ScaleWatch::EngineAppObserver` (instaluje sa
# bezpodmienecne pri nacitani pluginu a notifikuje Studio a dialogy). Hookovat
# len JEDEN observer by dieru nechalo: samotny Panel nekryje Studio otvorene
# bez Inspectora, a samotny ScaleWatch sa moze spustit AZ PO tom, co panel
# pushol stary token.
#
# Poradie observerov SketchUp negarantuje a dvojita rotacia NIE JE neskodna
# (review delty #267, P2-N1): callbacky observerov NIE SU len oznamenie, ony
# rovno NOTIFIKUJU KLIENTOV, takze medzi dve rotacie sa vmesti `key` a hodnota
# sa zapecie do UZ odoslaneho pushu — Studio by dostalo token A, panel token B.
# Ohranicenie „JEDEN event = JEDEN token" preto drzi `Engine.on_document_replaced`
# nizsie (RUBY TICK), NIE `invalidate` sam. Detail je pri nom.
#
# NIKDY sa NEZAPISUJE do modelu ani .skp (zamietnuta alternativa "token v
# NOXUN dictionary"): zapis pri otvoreni panela by zaspinil cisty dokument
# (dirty flag + undo krok + zakaz zapisov z push ciest, lekcia D-103) a token
# v subore by prezil kopiu zakazky — dve kopie by niesli TU ISTU identitu
# a guard by ich nerozoznal. Runtime token zije len v pamati procesu, co
# nevadi: panel po starte SketchUpu aj tak zacina cerstvym NX.init.
#
# Registry drzi SILNU referenciu na model (presny vzor SESSION_KEY_BRIDGE,
# production_core.rb): `equal?` odzbrojuje recyklaciu object_id po GC — je to
# DRUHA poistka pod udalostnou rotaciou, nie hlavny mechanizmus. Ziadny strop
# na ZIVE dokumenty (Codex audit R-02b, BLOCKER 2: vytlaceny zivy dokument by
# po navrate dostal novy token a nxSetModelGuid by zahodil drafty).
#
# UPRATOVANIE a jeho PRIZNANY dopad (review #267 P3-1): `prune_dead` maze
# VYHRADNE zaznam, ktory sa preukazatelne neda pouzit (`valid?` == false).
# OVERENE v realnom SketchUpe 2026 (in-SU sekcia DOCKEY to probne vola a
# vysledok vypisuje): `Sketchup::Model#valid?` TAM JE a nad zivym modelom vracia
# true — upratovanie teda na cielovej platforme funguje. Metoda vsak NIE JE
# v dokumentacii API garantovana pre vsetky verzie, preto test ostava fail-safe:
# ked chyba alebo hodi, zaznam sa PODRZI. Dopad na takom (hypotetickom) builde
# priznavame: registry by cez sedenie iba rastla a drzala silnu referenciu na
# zavrete `Model` wrappery — par desiatok bajtov na vymenu dokumentu (radovo
# desiatky za sedenie), vsetko mizne s procesom. Alternativa `WeakRef` bola
# zamietnuta: `equal?` nad odzbrojenym WeakRef hodi `WeakRef::RefError`, cim
# by sa z upratovania stal zdroj vynimiek v NAJKRITICKEJSEJ ceste (identita
# pred zapisom), a GC by nam navyse mohol zaznam vziat POCAS zivota dokumentu
# — teda presne to prekrstenie, ktoremu sa cela davka vyhyba.
require 'securerandom'

module Noxun
  module Engine
    # VYMENA DOKUMENTU = JEDNA UDALOST S JEDNYM ZOZNAMOM CLEANUPOV
    # (1d/R-02b, review delty #267 P2-GLM + review v2 P2-1).
    #
    # Zije TU (a nie v `main.rb`), aby ho headless sada vedela naozaj SPUSTIT —
    # `main.rb` je SketchUp loader a testy ho nenacitavaju. Je to Engine-level
    # koordinator, nie sucast DocKey: DocKey je len jeden z jeho cleanupov.
    #
    # KTO to vola: OBA AppObservery pluginu z `onNewModel`/`onOpenModel` —
    # NIKDY z `onActivateModel` (macOS prepnutie medzi UZ otvorenymi
    # dokumentmi) a nikdy pri ulozeni. MUSI bezat PRED notifikaciou klientov,
    # inak stihne odist push so starym udajom.
    #
    # CO uprataava: kazdu pamat viazanu na OBJEKT modelu, ktoru neupratuje
    # vlastna zdokumentovana cesta (viz `document_cleanups`).
    #
    # OHRANICENIE UDALOSTI = RUBY TICK. Poradie observerov SketchUp
    # negarantuje a ich callbacky NIE SU len oznamenie — ony rovno notifikuju
    # klientov, takze medzi dva cleanupy sa vmesti `DocKey.key` a hodnota sa
    # zapecie do UZ odoslaneho pushu (Studio by dostalo token A, panel token B;
    # prvy klik v Studiu by v SPRAVNOM dokumente skoncil falosnym „model sa
    # prepol" a `hw_sets.js` by zahodil projektove drafty druhykrat). Preto
    # sa cely blok spusti RAZ za tick: druhy observer toho isteho eventu vidi
    # otvorenu udalost a vrati sa. Nulovy timer zavrie udalost pri najblizsom
    # prechode message loopom — teda urcite az PO vsetkych observeroch jedneho
    # eventu a urcite PRED dalsim File>New/Open (ten vyzaduje akciu uzivatela).
    #
    # PRECO NIE „epocha z modelu": medziverzia skusala znacku odvodenu
    # z `Model#guid` a bola to DIERA (review v2, P2-1) — guid je OBSAH .skp
    # SUBORU, takze KOPIA zakazky nesie ten isty guid, kym sa neulozi. Otvorenie
    # kopie nad recyklovanym objektom by dalo zhodnu znacku, rotacia by sa
    # vynechala a novy dokument by zdedil identitu stareho. Tick ziadnu hodnotu
    # z modelu necita, takze tuto triedu dier nema.
    DOC_EVENT_MAX_S = 1.0 # poistka, viz `document_event_open?`

    class << self
      def on_document_replaced(model)
        return if document_event_open?

        open_document_event
        document_cleanups(model)
        nil
      end

      # Koniec ticku vymeny dokumentu. V SketchUpe ho vola nulovy timer;
      # headless (a in-SU scenare, ktore chcu odsimulovat DVA eventy) ho
      # volaju priamo. Je to SEAM, nie testovacia barlicka — robi presne to,
      # co timer, a nic navyse.
      def end_document_event
        @doc_event_open = false
        @doc_event_at = nil
        nil
      end

      private

      # Zoznam pamati, ktore vymena dokumentu upratuje. KAZDA pamat viazana na
      # `object_id` + `equal?`, ktoru NEUPRATUJE vlastna zdokumentovana cesta,
      # sem patri — inak sa na nu zabudne (presne to sa stalo mostu nazvu
      # zakazky, review #267 P2-GLM).
      #
      # VEDOME MIMO (maju vlastnu, zdokumentovanu cestu):
      #   * `GhostTool` session — rusi ju `GhostTool.on_document_replaced`
      #     priamo v observeroch, lebo potrebuje vlastnu hlasku a poradie voci
      #     nastrojovemu stacku (`docs/architecture/construction.md`).
      #   * `ScaleWatch` cache transformacii (`@stable_transforms`) — cisti ju
      #     `forget_detached_models` v `model_switched`, este stale cez guid
      #     ako detektor. Je to VEDOMA HRANICA (rozhodnutie R-04): staveme
      #     nizko — zastarany zaznam v cache znamena nanajvys menej presny
      #     navrat po odmietnutom Scale, nie zapis do cudzieho dokumentu.
      #
      # Kazdy krok je osetreny ZVLAST: vymena dokumentu uz prebehla, vratit sa
      # neda, takze zlyhanie jedneho cleanupu nesmie zastavit ostatne.
      def document_cleanups(model)
        begin
          DocKey.invalidate(model)
        rescue StandardError => e
          log_error(e, 'on_document_replaced/DocKey') if respond_to?(:log_error)
        end
        begin
          ProductionCore.forget_session_key(model) if defined?(ProductionCore)
        rescue StandardError => e
          log_error(e, 'on_document_replaced/SESSION_KEY_BRIDGE') if respond_to?(:log_error)
        end
      end

      def open_document_event
        @doc_event_open = true
        @doc_event_at = monotonic_now
        schedule_document_event_end
      end

      # POISTKA proti zaseknutej udalosti. Keby timer nikdy nedosiel (chybajuce
      # `UI`, vynimka v bloku), otvorena udalost by uz NIKDY nepustila dalsiu
      # rotaciu — a to je presne navrat P1 (novy dokument so starou identitou).
      # Zaseknuta udalost sa preto po `DOC_EVENT_MAX_S` povazuje za zavretu.
      # Nikdy to nie je hlavny mechanizmus: observery jedneho eventu bezia
      # mikrosekundy po sebe, dva realne eventy delí akcia uzivatela.
      def document_event_open?
        return false unless @doc_event_open
        return true unless @doc_event_at
        return true if (monotonic_now - @doc_event_at) <= DOC_EVENT_MAX_S

        end_document_event
        false
      end

      def schedule_document_event_end
        if defined?(UI) && UI.respond_to?(:start_timer)
          UI.start_timer(0, false) { Engine.end_document_event }
        end
        # Bez SketchUp UI (headless harness) sa nic neplanuje — udalost zavrie
        # `end_document_event` volany testom, prip. poistka vyssie.
      rescue StandardError => e
        log_error(e, 'on_document_replaced/timer') if respond_to?(:log_error)
        end_document_event
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rescue StandardError
        Time.now.to_f
      end
    end

    module DocKey
      TOKEN_PREFIX = 'nxdoc-'

      class << self
        # Stabilny kluc dokumentu. Prazdny retazec = "ziadna identita":
        # PRISNE guardy taky payload odmietnu a `foreign_document?` odmieta
        # aj zapis, ked prazdny kluc vyda SERVER (fail-closed, Codex audit
        # R-02b BLOCKER 1) - preto sa '' vracia pri nil/ne-modelovom objekte
        # aj pri akejkolvek chybe, a NIKDY sa nesmie vyrobit token pre
        # objekt, ktory sa nepodarilo precitat.
        def key(model)
          return '' unless model && model.respond_to?(:path)

          oid = model.object_id
          entry = registry[oid]
          unless entry && entry[:ref].equal?(model)
            prune_dead
            entry = { ref: model, token: fresh_token }
            registry[oid] = entry
          end
          entry[:token]
        rescue StandardError => e
          Engine.log_error(e, 'DocKey.key') if Engine.respond_to?(:log_error)
          ''
        end

        # JEDINY porovnavac identity dokumentu pre VSETKY guardy (review #267
        # P3-2). Vracia true = payload sa NESMIE zapisat.
        #
        # FAIL-CLOSED NA STRANE SERVERA plati BEZ VYNIMKY: ked sa identita
        # aktivneho dokumentu neda precitat (`key` vrati ''), zapis konci —
        # inak by `'' == ''` pustilo zapis „do niecoho, co nevieme pomenovat".
        # Pred tymto helperom bola tato poistka len v `Panel.foreign_document?`
        # a ~20 priamych porovnani v dialogoch a handleroch ju obchadzalo.
        #
        # `tolerate_blank_client:` je JEDINY povoleny rozdiel medzi guardmi a
        # je VEDOMY (nie vedlajsi produkt tvaru vyrazu, ako doteraz):
        #   * false (default, PRISNY) — payload BEZ identity je okno bez
        #     dobehnuteho `NX.init` a to nesmie zapisovat nikam.
        #   * true (TOLERANTNY) — pouzivaju cesty Studia a Materialov, kde
        #     starsi cachovany DOM identitu este nenesie a odmietnutie by
        #     pouzivatelovi zablokovalo okno; kryje ich generacny/optimisticky
        #     zamok. Server bez identity zapis zastavi aj TU.
        def foreign?(claimed, model, tolerate_blank_client: false)
          current = key(model)
          return true if current.empty?

          asked = claimed.to_s
          return false if tolerate_blank_client && asked.empty?

          asked != current
        end

        # VYMENA DOKUMENTU — zahodi identitu naviazanu na TENTO objekt, takze
        # najblizsie `key` vyda cerstvy token. Volat VYHRADNE cez
        # `Engine.on_document_replaced` (ten drzi ohranicenie udalosti).
        #
        # BEZPODMIENECNE. Maze sa podla `object_id`, lebo prave RECYKLOVANY
        # objekt je ten nebezpecny pripad (Windows, File > Open): novy dokument
        # by inak zdedil zaznam stareho. Ked objekt v registry nie je (macOS —
        # naozaj novy objekt), je to lacny no-op.
        #
        # ZIADNA podmienka tu byt NESMIE. Medziverzia skusala „epochu" odvodenu
        # z `Model#guid` a bola to DIERA (review v2, P2-1): guid je OBSAH .skp
        # SUBORU — kopia zakazky nesie TEN ISTY guid, kym sa neulozi. File > Open
        # kopie nad recyklovanym objektom by teda dal zhodny stamp, rotacia by
        # sa vynechala a novy dokument by zdedil identitu stareho — teda CELY
        # povodny nalez P1 spat, len tichsie. To iste platilo pre re-open toho
        # isteho suboru (revert) a pre Untitled -> Untitled.
        # Ohranicenie „jeden event = jeden token" preto NEROBI hodnota z modelu,
        # ale RUBY TICK v `Engine.on_document_replaced`.
        def invalidate(model)
          return false unless model

          registry.delete(model.object_id)
          prune_dead
          true
        rescue StandardError => e
          Engine.log_error(e, 'DocKey.invalidate') if Engine.respond_to?(:log_error)
          false
        end

        # Test-only: cisty stav medzi testami (registry je process-wide).
        def reset!
          @registry = {}
        end

        private

        def registry
          @registry ||= {}
        end

        # Uprace zaznamy zaniknutych dokumentov. Mazat sa smie LEN istota:
        # chyba/absencia `valid?` znamena "radsej podrzat" - omylom zmazany
        # ZIVY zaznam by dokument po navrate prekrstil (presne pasca, ktorej
        # sa vyhybame); podrzany mrtvy je len par bajtov do konca sedenia.
        def prune_dead
          registry.delete_if { |_oid, entry| dead?(entry[:ref]) }
        end

        def dead?(ref)
          ref.respond_to?(:valid?) && ref.valid? == false
        rescue StandardError
          false
        end

        # Globalne unikatny aj NAPRIEC sedeniami: ProductionCore persistuje
        # `guid:<hodnota>` kluce neulozenych zakaziek do vepo_settings.json
        # (project_names) - deterministicky citac by po restarte kolidoval
        # a nazov cudzieho neulozeneho projektu by sa objavil na dnesnom.
        def fresh_token
          "#{TOKEN_PREFIX}#{SecureRandom.hex(12)}"
        end

      end
    end
  end
end
