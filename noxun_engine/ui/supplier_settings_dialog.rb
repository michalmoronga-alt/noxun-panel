# frozen_string_literal: true
# Noxun Engine — NASTAVENIA: serverova autorita sekcii `sup` · `bset` · `about`.
#
# ŠT-4a: OKNO „Nastavenia rozpočtu" ZANIKLO (posledny satelit). Modul ostal —
# je to jedina autorita globalnych nastaveni dodavatela a NEPREMENUVA sa
# (audit #21, vzor MaterialsDialog/RulesDialog/TemplatesDialog): premenovanie
# by rozbilo kazdy `defined?` guard, kazdy test a kazdy odkaz v dokumentacii,
# pricom obsah modulu sa nemeni.
#
# ============================ CO SA TU EDITUJE ============================
# GLOBALNE nastavenia aktivneho dodavatela (%APPDATA%\NOXUN\Engine\
# supplier_settings.json) — sadzby sluzieb, rezimove hodnoty (€/€€/€€€),
# standardne koncove riadky, prah veku cien a krok zaokruhlenia. Do zakazky sa
# NEMRAZIA (rozhodnutie Michal 31.7.: rozpocet je pohyblivy obraz cien) —
# vsetko per zakazka drzi BudgetStore na modeli, ten sa tu NEDOTYKA.
#
# ============================== GUARDY ===================================
# 1) BASELINE REVIZIA (vzor rules_dialog/materials): sekcia dostava `revision`
#    aktivneho dodavatela a posiela ju spat pri ulozeni. Ina revizia = medzitym
#    to niekto zmenil -> zapis sa ODMIETNE a formular sa nacita nanovo (nikdy
#    tichy prepis cudzej zmeny). Baseline sa obnovuje AZ PRI USPESNOM zostaveni
#    payloadu (lekcia ŠT-3b-2c2 B4) — inak by sa server a klient rozisli.
# 2) VALIDACIA JE SERVEROVA — SupplierSettings.patch_active! je all-or-nothing
#    (validate-all pred zapisom); HTML `disabled`/`type=number` nie su ochrana.
# 3) Po uspesnom ulozeni sa STUDIO PREPOCITA (`refresh_studio`) — sadzby su
#    vstup rozpoctu, cisla by inak ostali stare. Do ŠT-4a to robilo okno
#    (`StudioDialog.refresh_if_open`); teraz je to TA ISTA cesta, len zvnutra.
#    HLASKA SA VETVI PODLA VYSLEDKU prepoctu (`refresh_and_report`, dlh 1b-A):
#    zapis do suboru a obnova obrazovky su DVE veci a hlaska nesmie potvrdzovat
#    tu druhu, ked neprebehla.
require 'json'

module Noxun
  module Engine
    module SupplierSettingsDialog
      # UZAVRETY whitelist akcii, ktore smie poslat SEKCIA. Klient posiela iba
      # MENO akcie — co sa smie zavolat, rozhoduje SERVER.
      #
      # `ready` v zozname NIE JE (a byt nemoze): Studio registruje callbacky pod
      # TYMI ISTYMI menami, takze `ready` by prepisal jeho vlastny. Prvotny stav
      # sekcie nesie `push_state` Studia pod klucom `settings`.
      #
      # Mena su prefixovane `ss_` — `save`/`reload` (mena z okna) su prilis
      # vseobecne na to, aby zili vedla akcii ostatnych sekcii v JEDNOM
      # priestore callbackov okna.
      # D-52b pridala TRI akcie updatera (sekcia `about`): kontrola verzie,
      # ulozenie distribucneho priecinka a samotna aktualizacia. Mena su
      # prefixovane `updater_` z toho isteho dovodu ako `ss_` — vsetky sekcie
      # Studia ziju v JEDNOM priestore callbackov okna.
      SECTION_ACTIONS = %w[ss_save ss_reload updater_check updater_set_dir updater_apply].freeze

      # --- D-52b: casovanie updatera ---------------------------------------
      # Kontrola verzie cita hlavicku loadera zo ZDROJA, ktory je typicky
      # sietovy share — odpojeny disk vie „viset" desiatky sekund. Preto
      # deadline: po nom sa vysledok uz nikdy nepouzije a sekcia povie, ze
      # zdroj neodpovedal. Bariera pred swapom caka na zatvorenie OBOCH okien.
      UPDATER_DEADLINE_S = 4.0
      UPDATER_POLL_S = 0.2
      UPDATER_BARRIER_S = 3.0
      UPDATER_BARRIER_POLL_S = 0.1
      # Codex #278 kolo 2 (P1): PRIPRAVA balika (manifest + kopirovanie stoviek
      # suborov zo share) je nerovnako dlha operacia — minuta je strop, po
      # ktorom je zdroj evidentne nedostupny a caka sa zbytocne.
      UPDATER_STAGE_S = 60.0
      UPDATER_STAGE_POLL_S = 0.25

      # Popisky a jednotky sadzieb sluzieb — poradie = poradie v sekcii (zhodne
      # s Budget::SERVICE_DEFS, aby sa nastavenie a rozpocet citali rovnako).
      RATE_LABELS = {
        'olep'           => ['Olepovanie ABS', '€/bm'],
        'porez'          => ['Porez platní', '€/platňa'],
        'duplaky'        => ['Lepenie duplákov', '€/ks'],
        'pd_opracovanie' => ['Opracovanie pracovnej dosky', '€ fix'],
        'montaz'         => ['Montáž', '€/m²']
      }.freeze

      class << self
        # --- TESTOVACIE SEAMY (D-52b) ----------------------------------------
        # Asynchronna kontrola verzie a bariera pred swapom stoja na TROCH
        # veciach z prostredia: hodiny, vlakno a timer (+ natívna hláška).
        # Headless sada ich nahradí, takze sa token, deadline aj bariera daju
        # overit bez SketchUpu a bez cakania v realnom case. V produkcii su
        # vsetky `nil` a kod ide standardnou cestou (vzor `Materials`
        # `test_dir_override`).
        attr_accessor :test_clock, :test_spawn, :test_schedule, :test_notify

        # --- vstup SEKCII (vzor RulesDialog.dispatch) ------------------------

        def dispatch(name, payload, sink)
          key = name.to_s
          return sink.call(status_script('Neznáma akcia nastavení.', true)) unless SECTION_ACTIONS.include?(key)

          with_client(sink) { run_section_action(key, payload) }
        rescue StandardError => e
          Engine.log_error(e, "SupplierSettingsDialog.dispatch #{name}")
          sink.call(status_script("Chyba: #{e.message}", true))
        end

        def run_section_action(key, payload)
          case key
          when 'ss_save'        then handle_save(payload)
          when 'ss_reload'      then handle_reload
          when 'updater_check'  then handle_updater_check
          when 'updater_set_dir' then handle_updater_set_dir(payload)
          when 'updater_apply'  then handle_updater_apply(payload)
          end
        end

        # Presmerovanie odpovedi na cas JEDNEHO volania. `ensure` je povinne:
        # vynimka v handleri nesmie nechat sink viset, inak by ho zdedila
        # NASLEDUJUCA odpoved a poslala ju do cudzieho kanala.
        def with_client(sink)
          prev = @client_sink
          @client_sink = sink
          yield
        ensure
          @client_sink = prev
        end

        # --- payload sekcii --------------------------------------------------
        #
        # JEDEN payload nesie VSETKY TRI sekcie nastaveni (`sup`/`bset`/`about`):
        # su to tri pohlady na ten isty maly dokument, takze druhy kanal by bol
        # drahsi nez cely payload. Model sa NEODOVZDAVA — nastavenia su
        # GLOBALNE (rovnako ako sablony).
        def settings_payload
          sup = SupplierSettings.active
          rev = SupplierSettings.revision(sup)
          data = {
            'version' => Engine::VERSION,
            'revision' => rev,
            'supplier' => sup,
            'modes' => SupplierSettings::MODES,
            'mode_labels' => SupplierSettings::MODE_LABELS,
            'rate_keys' => SupplierSettings::RATE_KEYS,
            'rate_labels' => RATE_LABELS,
            'standard_rows' => SupplierSettings.standard_rows(sup),
            'path' => SupplierSettings.path,
            'demos' => demos_info,
            'about' => about_info
          }
          # Baseline AZ PO uspesnom zostaveni (ŠT-3b-2c2 B4): ked telo spadne,
          # klient si drzi STARY stav — keby si server medzitym posunul baseline,
          # kazde ulozenie by sa uz navzdy odmietalo.
          @baseline_revision = rev
          data
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.settings_payload')
          nil
        end

        # Sekcia `sup` — „Dodávateľ / Demos". POCTIVO: dnes NEEXISTUJU ziadne
        # nastavenia vazby na Demos (ziadne prihlasenie, ziadne cenove pasmo,
        # ziadna DPH) — Demos je VEREJNY cennik a jedina jeho „nastavitelna"
        # vec je odstup dotazov, ktory je KONSTANTA slusneho spravania
        # (`DemosClient::CRAWL_DELAY_S`). Sekcia preto ukazuje STAV, nie
        # vymyslene polia, a vedie tam, kde vazba naozaj zije.
        def demos_info
          { 'crawl_delay_s' => demos_delay, 'stale_days' => SupplierSettings.scalar(SupplierSettings.active, 'stale_days') }
        end

        def demos_delay
          return nil unless defined?(DemosClient) && DemosClient.const_defined?(:CRAWL_DELAY_S)

          DemosClient::CRAWL_DELAY_S
        rescue StandardError
          nil
        end

        # Sekcia `about` — „O plugine". JEDEN OBSAH, DVA VSTUPY (kontrakt Š19):
        # markup stavia ZDIELANY `ui/js/about.js`, ktory pouziva aj koliesko
        # Inspectora. Server dava LEN data (verzia + kde ziju nastavenia).
        #
        # D-52b: k tomu pribudol stav UPDATERA — ale LEN to, co sa da zistit
        # BEZ dotyku zdroja (ulozena cesta, beziaca verzia, restart latch).
        # Kontrola verzie je EXPLICITNA akcia (`updater_check`, F5): tento
        # payload chodi pri KAZDEJ zmene modelu a siahat pri nom na sietovy
        # share by znamenalo zamrznute Studio pri kazdom posune skrinky.
        def about_info
          { 'version' => Engine::VERSION, 'dir' => appdata_dir, 'updater' => updater_info }
        end

        def updater_info
          return { 'enabled' => false } unless updater?

          { 'enabled' => true, 'source_dir' => Updater.source_dir,
            'current' => Engine::VERSION.to_s, 'locked' => Engine.restart_required? }
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.updater_info')
          { 'enabled' => false }
        end

        def appdata_dir
          return SupplierSettings.dir if SupplierSettings.respond_to?(:dir)

          ''
        rescue StandardError
          ''
        end

        # --- akcie -----------------------------------------------------------

        def handle_reload
          SupplierSettings.reload!
          # Rozpisane hodnoty zanikaju AZ TU (klient si ich cez pushe drzi —
          # plny push chodi pri kazdej zmene modelu, nielen po ulozeni).
          js('SS.saved()')
          # Aj tu sa menuje TLACIDLO, ktore v sekcii je (review #238 P3-3) —
          # vseobecne „skús to znova" clovek nema kam kliknut.
          refresh_and_report('Nastavenia načítané nanovo zo súboru.',
                             'Nastavenia sa načítali zo súboru, ale okno sa nepodarilo obnoviť — ' \
                             'hodnoty na obrazovke môžu byť staré. Klikni na Načítať nanovo.')
        end

        # Odmietnutie ZASTARANEHO formulara (revizia nesedi).
        #
        # Review #227 P1: klient drzi reviziu PRIPNUTU na stav, nad ktorym zacal
        # pisat — inak by plny push reviziu omladil, zamok by presiel a cudzia
        # zmena by zmizla bez slova. A odmietnutie MUSI rozpisane hodnoty
        # ZAHODIT (`SS.saved()`, presne ako to robilo okno): bez toho by prezili
        # push, prekryli cerstve cisla a DRUHY klik by ich ticho prepisal —
        # hlaska pritom tvrdi, ze formular je nacitany nanovo. Hlaska a
        # spravanie sa musia zhodovat (review #227 P1-2).
        def reject_stale
          js('SS.saved()')
          # Aj TATO hlaska tvrdi vysledok prepoctu („formulár je načítaný
          # nanovo"), takze sa vetvi rovnako ako potvrdzujuca (dlh 1b-A).
          refresh_and_report('Nastavenia sa medzitým zmenili — formulár je načítaný nanovo. ' \
                             'Skontroluj hodnoty a ulož znova.',
                             'Nastavenia sa medzitým zmenili, takže sa NIČ neuložilo — ' \
                             'a formulár sa nepodarilo načítať nanovo. Klikni na ' \
                             '„Načítať nanovo" a hodnoty zadaj znova.',
                             ok_error: true)
        end

        # Ulozenie: revizia -> patch (validate-all) -> prepocet Studia.
        # R-08: revizia sa od tejto davky kontroluje DVA razy — tu (lacne, kvoli
        # hlaske a rozpisanemu formularu) a este raz POD medziprocesovym zamkom
        # v `patch_active!`. Kontrola tu sama o sebe nestacila: medzi nou a
        # zapisom stihla druha instancia svoje sadzby ulozit a nas zapis ich
        # zmazal, hoci okno hlasilo uspech. Obe vetvy konfliktu preto koncia
        # v tej istej obsluhe (`reject_stale`) — jedna hlaska, jedno spravanie.
        def handle_save(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          rev = data['revision'].to_s
          return reject_stale if rev != SupplierSettings.revision(SupplierSettings.active)

          patch = data['patch'].is_a?(Hash) ? data['patch'] : {}
          ok, errors, status = SupplierSettings.patch_active!(patch, rev)
          # Cudzia zmena, ktora prisla AZ po lacnej kontrole vyssie (zachytil ju
          # az zamok) — rovnaka odpoved ako pri nej.
          return reject_stale if status == :conflict
          # Pri chybe sa formular ZAMERNE NEnacitava nanovo — pouzivatel by
          # prisiel o vsetky rozpisane hodnoty a videl by len hlasku. Nic sa
          # nezapisalo (patch je all-or-nothing), takze staci chybu ukazat.
          return set_status("Neuložené: #{Array(errors).join(' · ')}", true) unless ok

          # POTVRDENY zapis — az teraz smie klient zahodit rozpisane hodnoty.
          js('SS.saved()')
          # Sadzby su vstup rozpoctu — cisla Studia MUSIA byt cerstve. Je to TA
          # ISTA refresh cesta, aku mal satelit (kontrakt „KAZDE okno s cislami
          # zakazky je vo VSETKYCH refresh cestach"), len bezi zvnutra okna.
          # A ked ZLYHA, hlaska to MUSI povedat: zapis do suboru uz prebehol,
          # `SS.saved()` uz rozpis zahodil, takze na obrazovke ostanu STARE
          # cisla — „Rozpočet je prepočítaný." by nad nimi bolo klamstvo.
          # Hlaska smie menovat LEN tlacidlo, ktore v sekcii NAOZAJ je (review
          # #238 P2-1): lista `bset` ma „Načítať nanovo" a „Uložiť" — „Obnoviť"
          # zije v sekcii Rozpocet. Bez tej navigacie by clovek siahol po
          # „Načítať nanovo", ktore rozpisane hodnoty ZAHADZUJE.
          refresh_and_report('Nastavenia uložené. Rozpočet je prepočítaný.',
                             'Nastavenia sú ULOŽENÉ, ale rozpočet sa NEPREPOČÍTAL — ' \
                             'čísla Rozpočtu môžu byť staré. Otvor sekciu Rozpočet ' \
                             'a klikni na Obnoviť.')
        end

        # ============ D-52b: UPDATER V SEKCII „O PLUGINE" ====================
        #
        # VEDOMA ODCHYLKA od zapisaneho „sekcie `sup`/`about` su CITANIE":
        # `about` ma od tejto davky JEDINE zapisovatelne pole mimo `bset`
        # (cestu k distribucnemu prieciniku) a tlacidlo, ktore prepise subory
        # pluginu. Vyplyva to zo zadania D-52 („aktualizovat jednym klikom zo
        # sekcie O plugine"). Prvky sa preto renderuju VYHRADNE pre studiovy
        # vstup `nxAboutHtml` — koliesko Inspectora ich NEMA (mrtve tlacidlo
        # v druhom vstupe = D-78).
        #
        # JADRO (recovery, zamok, lease, manifest, swap, latch) je z D-52a
        # (`core/updater.rb`, ciste headless). Tato vrstva pridava LEN:
        #   * asynchronnu kontrolu verzie s deadline a tokenom (F5/F6),
        #   * BARIERU pred swapom — zavriet obe okna a POCKAT na ich
        #     `set_on_closed` (F10; CEF drzi subory z `ui/` a rename by zlyhal),
        #   * vysledok VYHRADNE natívne (`UI.messagebox`) — nikdy cez CEF.

        def updater?
          defined?(Updater) ? true : false
        end

        def updater_off
          set_status('Aktualizátor nie je načítaný — reštartuj SketchUp.', true)
        end

        # --- kontrola verzie (asynchronne, F5/F6) -----------------------------
        #
        # Hlavne vlakno NIKDY nesiaha na zdroj: citanie hlavicky loadera bezi vo
        # VLAKNE a v nom je LEN suborove I/O (ziadne `Sketchup.*`, ziadne `UI.*`,
        # ziadny zapis do stavu okna). Vysledok nasadzuje do UI vyhradne
        # hlavne vlakno z `UI.start_timer` pollu.
        def handle_updater_check
          return updater_off unless updater?

          dir = Updater.source_dir
          @updater_dir = dir
          seq = (@updater_seq = @updater_seq.to_i + 1)
          return push_updater('state' => 'idle', 'source_dir' => dir) if dir.empty?

          token = { 'seq' => seq, 'dir' => dir, 'dlg' => studio_token }
          push_updater('state' => 'checking', 'source_dir' => dir)
          entry = updater_worker(dir, Engine::VERSION.to_s)
          poll_updater_check(token, entry['box'], updater_now + UPDATER_DEADLINE_S)
          true
        end

        # JEDEN BEZIACI DOTAZ NA JEDNU CESTU (Codex #278 P2).
        #
        # Vlakno sa po deadline NEZABIJA (nad visiacim UNC sharom je `Thread#kill`
        # nespolahlivy), takze bez tejto evidencie by KAZDY navrat do sekcie
        # pridal dalsie zablokovane vlakno na tu istu mrtvu cestu — a tie by sa
        # hromadili az do restartu SketchUpu.
        #
        # ZIVY (visiaci) beh sa preto ZDIELA: novy dotaz na tu istu cestu sa len
        # PRIHLASI na jeho vysledok s VLASTNYM tokenom. HOTOVY beh sa naopak
        # zahadzuje — jeho vysledok je z ineho okamihu a share sa medzitym mohol
        # vratit, takze nova kontrola musi zdroj precitat NANOVO.
        def updater_worker(dir, current)
          reg = (@updater_workers ||= {})
          reg.delete_if { |_k, v| v['box']['done'] } # dobehnute behy sa nedrzia
          entry = reg[dir]
          if entry
            entry['reused'] = entry['reused'].to_i + 1
            return entry
          end

          box = { 'done' => false, 'result' => nil }
          entry = { 'box' => box, 'started_at' => updater_now, 'reused' => 0 }
          # VO VLAKNE JE LEN SUBOROVE I/O — ziadne `Sketchup.*`, ziadne `UI.*`,
          # ziadny zapis do stavu okna (guard test nad zdrojom to strazi).
          entry['thread'] = updater_spawn do
            begin
              box['result'] = Updater.check(dir, current)
            rescue StandardError => e
              box['result'] = { 'ok' => false, 'state' => 'error', 'available' => '',
                                'reason' => "zdroj sa nepodarilo prečítať (#{e.class})" }
            end
            box['done'] = true
          end
          reg[dir] = entry
          entry
        end

        # Jeden tik pollu. Re-armuje sa sam (`UI.start_timer` je jednorazovy).
        def poll_updater_check(token, box, deadline)
          return if updater_stale?(token) # medzitym prisiel novsi dotaz alebo sa zavrelo okno

          return deliver_updater_check(token, box['result']) if box['done']

          if updater_now >= deadline
            # Vlakno sa ZAMERNE NEZABIJA: `Thread#kill` nad citanim z odpojeneho
            # sietoveho disku je nespolahlivy. Beh sa OPUSTI a jeho neskora
            # odpoved zomrie na tokene — sekvencia sa tu zdvihne.
            @updater_seq = @updater_seq.to_i + 1
            return push_updater('state' => 'error', 'source_dir' => token['dir'],
                                'reason' => "zdroj neodpovedal do #{UPDATER_DEADLINE_S.round} s " \
                                            "(#{token['dir']}) — je pripojený?")
          end

          updater_schedule(UPDATER_POLL_S) { poll_updater_check(token, box, deadline) }
        end

        def deliver_updater_check(token, result)
          return if updater_stale?(token)

          r = result.is_a?(Hash) ? result : {}
          state = r['ok'] ? r['state'].to_s : 'error'
          # DOKLAD O KONTROLE (Codex #278 P1). `apply!` sa smie spustit VYHRADNE
          # nad tym, co uzivatel naozaj videl skontrolovane — preto si server
          # pamata (cesta, sekvencia, stav, instancia okna) a klient mu to pri
          # klike vracia. Bez toho by stacilo, aby druha instancia medzitym
          # ulozila INU cestu: potvrdenie by menovalo cestu A a nasadilo B.
          # `available` je sucastou dokladu (Codex #278 kolo 2, P1): balik na
          # share sa moze medzi kontrolou a potvrdenim VYMENIT a modal by
          # menoval inu verziu, nez aka by sa nasadila.
          @updater_check_ok = { 'dir' => token['dir'].to_s, 'token' => token['seq'],
                                'state' => state, 'dlg' => token['dlg'],
                                'available' => r['available'].to_s }
          push_updater('state' => state, 'source_dir' => token['dir'], 'token' => token['seq'],
                       'available' => r['available'].to_s, 'reason' => r['reason'].to_s)
        end

        # TOKEN = (cesta, instancia Studia, sekvencia). Neskora alebo cudzia
        # odpoved sa ZAHADZUJE: ukazovala by verziu ineho priecinka, prebila by
        # cerstvejsi dotaz alebo by kreslila do okna, ktore uz nezije.
        def updater_stale?(token)
          return true unless token.is_a?(Hash)
          return true if token['seq'] != @updater_seq
          return true if token['dir'].to_s != @updater_dir.to_s
          return true if token['dlg'] != studio_token

          false
        end

        def studio_token
          return nil unless defined?(StudioDialog) && StudioDialog.respond_to?(:instance_token)

          StudioDialog.instance_token
        rescue StandardError
          nil
        end

        # --- ulozenie cesty (F7/F11) -----------------------------------------
        # Cesta ma VLASTNY namespace `data-updater-edit` a VLASTNE ulozenie
        # (Enter / mini-tlacidlo) — pod `data-ss` a revizny zamok dodavatela
        # nepatri. Ulozenie rovno spusti novy check: po zmene priecinka je
        # predchadzajuci vysledok o inom mieste.
        def handle_updater_set_dir(payload)
          return updater_off unless updater?

          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          saved = Updater.set_source_dir(data['source_dir'].to_s)
          if saved.nil?
            reason = Updater.write_block_reason
            return set_status(reason.empty? ? 'Cestu sa nepodarilo uložiť — pozri Ruby konzolu.' : reason, true)
          end

          @updater_dir = saved
          # `req` je poradove cislo POZIADAVKY klienta (Codex #278 kolo 3, P2):
          # vracia sa nedotknute, aby klient poznal, KTOREMU ulozeniu potvrdenie
          # patri — ack starsieho ulozenia uz nesmie zahodit rozpis toho novsieho.
          push_updater('state' => 'idle', 'source_dir' => saved, 'saved' => true,
                       'req' => data['req'])
          set_status(saved.empty? ? 'Distribučný priečinok je zmazaný.' : "Priečinok uložený: #{saved}")
          handle_updater_check
        end

        # --- aktualizacia (F10) ----------------------------------------------
        #
        # Codex #278 (P1): klient posiela CESTU A TOKEN kontroly, ktorej vysledok
        # mal pred ocami. Bez toho stacilo, aby druha instancia SketchUpu (alebo
        # rucny zasah do `updater_settings.json`) medzitym ulozila INU cestu:
        # potvrdenie by menovalo cestu A a nasadila by sa B. Zhodovat sa musi
        # VSETKO — cesta z kliku, posledna USPESNA kontrola tejto instancie okna
        # a cesta, ktora je AKTUALNE ulozena.
        def handle_updater_apply(payload = nil)
          return updater_off unless updater?
          return set_status('Plugin je už aktualizovaný — reštartuj SketchUp.', true) if Engine.restart_required?
          # SINGLE-FLIGHT (Codex #278 kolo 2, P1). Dva rychle kliky (alebo dve
          # odoslania toho isteho potvrdenia) by naplanovali DVE bariery; druha
          # by po commite prvej bezala nad UZ VYMENENYMI subormi. Priznak sa
          # zapina PRED zatvorenim okien — teda skor, nez sa cokolvek stane.
          if @updater_apply_inflight
            return set_status('Aktualizácia už prebieha — počkaj na jej výsledok.', true)
          end

          dir = Updater.source_dir
          return set_status('Najprv zadaj distribučný priečinok a ulož ho.', true) if dir.empty?

          data = payload.is_a?(Hash) ? payload : (payload.nil? ? {} : JSON.parse(payload.to_s))
          reason = updater_apply_mismatch(data, dir)
          return set_status(reason, true) if reason

          # TOKEN JE JEDNORAZOVY: doklad o kontrole sa SPOTREBUJE. Druhe
          # odoslanie toho isteho potvrdenia tak nema com prejst ani vtedy, keby
          # priznak vyssie zlyhal.
          @updater_apply_expect = @updater_check_ok['available'].to_s
          @updater_check_ok = nil
          @updater_apply_inflight = true

          # Poradie je zavazne: hlaska este do ZIVEHO okna, potom zatvorenie,
          # a swap az ked obe okna naozaj dobehnu (`set_on_closed`).
          set_status('Zatváram okná pluginu — aktualizácia sa spustí po ich zatvorení…')
          close_plugin_dialogs
          await_dialogs_closed(dir, updater_now + UPDATER_BARRIER_S)
          true
        end

        # `nil` = klik smie prejst. Inak DOVOD odmietnutia (jedna hlaska pre
        # vsetky nezhody — pouzivatel ma spravit to iste: skontrolovat znova).
        RECHECK_MSG = 'Cesta k balíku sa medzitým zmenila — skontroluj znova (odíď zo sekcie ' \
                      'a vráť sa do nej) a až potom aktualizuj.'

        def updater_apply_mismatch(data, dir)
          ok = @updater_check_ok
          return RECHECK_MSG unless ok.is_a?(Hash)
          return RECHECK_MSG unless ok['state'].to_s == 'newer'
          return RECHECK_MSG unless ok['dir'].to_s == dir          # kontrola bola nad INOU cestou
          return RECHECK_MSG unless ok['dlg'] == studio_token      # a v INEJ instancii okna
          return RECHECK_MSG unless data['checked_path'].to_s == dir
          return RECHECK_MSG unless data['check_token'].to_i == ok['token'].to_i

          nil
        end

        def close_plugin_dialogs
          Panel.hide if defined?(Panel) && Panel.respond_to?(:hide)
          StudioDialog.hide if defined?(StudioDialog) && StudioDialog.respond_to?(:hide)
          true
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.close_plugin_dialogs')
          false
        end

        # `dialog_closed?` (nie `dialog_alive?`) — cakame na DOBEHNUTY
        # `set_on_closed`, nie na neviditelne okno: CEF moze este drzat subory
        # z `ui/` a rename priecinka by na Windows zlyhal.
        def dialogs_closed?
          [defined?(Panel) ? Panel : nil, defined?(StudioDialog) ? StudioDialog : nil]
            .compact.all? { |mod| mod.respond_to?(:dialog_closed?) ? mod.dialog_closed? : true }
        end

        def await_dialogs_closed(dir, deadline)
          # ODLOZENE CAKANIE MUSI ESTE RAZ OVERIT, ZE SA MEDZITYM NIC NESTALO
          # (Codex #278 kolo 2, P1): keby iny beh medzitym COMMITOL, tento by
          # spustil swap zo STAREHO Ruby nad UZ NOVYMI subormi. Rusi sa bez
          # zasahu — vysledok uz oznamil ten prvy beh.
          if Engine.restart_required?
            @updater_apply_inflight = false
            return false
          end

          return updater_run_apply(dir) if dialogs_closed?

          if updater_now >= deadline
            @updater_apply_inflight = false
            return updater_message('Aktualizácia sa NESPUSTILA — okná pluginu sa nepodarilo zavrieť ' \
                                   "do #{UPDATER_BARRIER_S.round} s. Zavri Inspector aj Štúdio ručne " \
                                   'a skús to znova. Na disku sa nič nezmenilo.')
          end

          updater_schedule(UPDATER_BARRIER_POLL_S) { await_dialogs_closed(dir, deadline) }
        end

        # Samotny swap. Vysledok ide VYHRADNE natívne — okna su v tomto bode
        # zavrete a po uspechu by nove HTML/JS bezalo proti starym callbackom.
        # DVE FAZY (Codex #278 kolo 2, P1). Do tejto opravy bezalo cele
        # `Updater.apply!` — teda aj manifest zdroja a kopirovanie stoviek
        # suborov zo share — SYNCHRONNE v `UI.start_timer` callbacku. Visiaci
        # UNC share tak zamrazil SketchUp na desiatky sekund a pouzivatel nemal
        # ako zasiahnut. Preto:
        #   * `Updater.prepare!` (manifest + staging do `.new` + validacia) bezi
        #     vo VLAKNE s vlastnym deadline — ziva generacia sa pri nom nedotyka,
        #     takze po zruseni je na disku presne to, co tam bolo;
        #   * `Updater.commit!` (renamey v Plugins) bezi v HLAVNOM vlakne, je to
        #     lokalna a rychla operacia.
        def updater_run_apply(dir)
          plugins = Engine.plugin_dir # `Engine.*` sa cita v HLAVNOM vlakne
          box = { 'done' => false, 'ticket' => nil, 'error' => nil }
          # VO VLAKNE JE LEN SUBOROVE I/O — ziadne `Sketchup.*`, ziadne `UI.*`,
          # ziadny zapis do stavu okna (guard test nad zdrojom to strazi).
          updater_spawn do
            begin
              box['ticket'] = Updater.prepare!(dir, plugins)
            rescue StandardError => e
              box['error'] = e
            end
            box['done'] = true
          end
          poll_updater_stage(box, updater_now + UPDATER_STAGE_S)
        end

        def poll_updater_stage(box, deadline)
          return updater_finish_apply(box) if box['done']

          if updater_now >= deadline
            # Vlakno sa NEZABIJA (nad visiacim sharom je to nespolahlive) —
            # opusti sa. Ziva generacia je nedotknuta; keby priprava predsa len
            # dobehla, jej `.new` a marker uprace boot recovery.
            @updater_apply_inflight = false
            return updater_message('Zdroj nedostupný — aktualizácia ZRUŠENÁ. Na disku sa nič ' \
                                   'nezmenilo a plugin beží ďalej v pôvodnej verzii. Keď sa zdroj ' \
                                   'vráti, reštartuj SketchUp a skús to znova.')
          end

          updater_schedule(UPDATER_STAGE_POLL_S) { poll_updater_stage(box, deadline) }
        end

        # Hlavne vlakno: overi VERZIU proti dokladu o kontrole a commitne.
        def updater_finish_apply(box)
          @updater_apply_inflight = false
          err = box['error']
          if err
            Engine.log_error(err, 'SupplierSettingsDialog.updater_prepare') unless err.is_a?(Updater::Refused)
            reason = err.is_a?(Updater::Refused) ? err.message : "#{err.class}: #{err.message}"
            return updater_message(updater_failure_text(reason))
          end

          ticket = box['ticket']
          mismatch = updater_version_mismatch(ticket)
          if mismatch
            Updater.abort_prepared!(ticket) # pripraveny `.new` ani marker neostanu
            return updater_message(mismatch)
          end

          res = Updater.commit!(ticket)
          note = res.is_a?(Hash) ? res['note'].to_s : ''
          msg = "Aktualizované na #{res.is_a?(Hash) ? res['to'] : '?'} — reštartuj SketchUp."
          msg = "#{msg}\n\n#{note}" unless note.empty?
          updater_message(msg)
        rescue Updater::Refused => e
          updater_message(updater_failure_text(e.message))
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.updater_run_apply')
          updater_message(updater_failure_text("#{e.class}: #{e.message}"))
        end

        # Codex #278 kolo 2 (P1): doklad o kontrole viaze aj VERZIU. Medzi
        # kontrolou a potvrdenim mohol niekto na share vymenit balik — modal
        # menoval X, ale pripravene je Y. Nainstalovat Y by znamenalo nasadit
        # nieco, co clovek nikdy neodsuhlasil.
        def updater_version_mismatch(ticket)
          want = @updater_apply_expect.to_s
          return nil if want.empty?

          got = (ticket.is_a?(Hash) ? ticket['to'] : nil).to_s
          return nil if got == want

          "Balík sa medzitým zmenil (#{want} → #{got}) — NIČ sa nenainštalovalo. " \
            'Skontroluj znova a potvrď to, čo naozaj chceš nasadiť.'
        end

        # Codex #278 (P2): „plugin ostal nezmenený" NIE JE pravda vzdy.
        # `abort_after_move!` ma DVE vetvy — pri USPESNOM rollbacku je na disku
        # presne to, co tam bolo (a latch sa zamerne NEZAPINA), ale pri ZLYHANOM
        # rollbacku ostavaju artefakty `.new`/`.old` aj marker, latch sa ZAPNE
        # a generaciu dorovna az boot recovery. Rozhoduje preto LATCH: je to
        # jediny priznak, ktory jadro po commite (a po zlyhanom rollbacku)
        # spolahlivo zapina.
        def updater_failure_text(reason)
          if Engine.restart_required?
            return "AKTUALIZÁCIA JE NEÚPLNÁ — REŠTARTUJ SketchUp, plugin sa pri štarte dorovná.\n\n" \
                   "Dôvod: #{reason}"
          end

          "Aktualizácia sa NEVYKONALA — plugin ostal nezmenený.\n\nDôvod: #{reason}"
        end

        def updater_message(text)
          hook = test_notify
          return hook.call(text) if hook

          ::UI.messagebox(text) if defined?(::UI) && ::UI.respond_to?(:messagebox)
          text
        end

        # --- prostredie (seamy) ----------------------------------------------
        def updater_now
          return test_clock.call.to_f if test_clock

          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def updater_spawn(&blk)
          return test_spawn.call(blk) if test_spawn

          Thread.new(&blk)
        end

        def updater_schedule(seconds, &blk)
          return test_schedule.call(seconds, blk) if test_schedule
          return nil unless defined?(::UI) && ::UI.respond_to?(:start_timer)

          ::UI.start_timer(seconds, false, &blk)
        end

        # Stav updatera do sekcie. `state`: idle | checking | newer | same |
        # older | error — texty sklada KLIENT (`nxUpdaterText`), server posiela
        # cisty stav a cisla.
        def push_updater(over = {})
          data = { 'enabled' => updater?, 'state' => 'idle', 'source_dir' => '',
                   'current' => Engine::VERSION.to_s, 'available' => '', 'reason' => '',
                   'locked' => (updater? ? Engine.restart_required? : false),
                   'saved' => false, 'req' => nil }.merge(over)
          js("SS.updater(#{data.to_json})")
        end

        # --- Ruby -> JS -------------------------------------------------------

        # Prijimac `SS.*` zije v `ui/js/studio_settings.js`, `#status` je uzol
        # `studio.html`. Text sklada SERVER (jedna autorita).
        def status_script(msg, error = false)
          "SS.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})"
        end

        def set_status(msg, error = false)
          js(status_script(msg, error))
        end

        # Odpoved ide TOMU, KTO sa pytal. Sink zije PRESNE jeden synchronny
        # callback sekcie (`with_client`); mimo neho je adresat jediny mozny:
        # okno Studio.
        def js(script)
          sink = @client_sink
          return sink.call(script) if sink

          studio_js(script)
        end

        # Kanal SEKCIE. `js` Studia je private (patri jeho kanalu), preto tenky
        # verejny most `settings_js` — vzor `StudioDialog.rules_js`.
        def studio_js(script)
          return false unless defined?(StudioDialog)

          StudioDialog.settings_js(script)
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.studio_js')
          false
        end

        # Prepocet + hlaska, ktora sa VETVI podla jeho VYSLEDKU (dlh 1b-A).
        #
        # Kazda hlaska tohto modulu tvrdi nieco o OBSAHU OKNA („Rozpočet je
        # prepočítaný.", „formulár je načítaný nanovo") — a to obstara az plny
        # push. Ten moze zlyhat (vynimka pri zostaveni payloadu, `execute_script`
        # do este nepripraveneho okna) a vtedy je jedina pravda: subor je
        # zapisany, obrazovka nie. Kym sa navratova hodnota ignorovala, hlaska
        # potvrdzovala prepocet, ktory neprebehol.
        #
        # `ok_error` je pre pripad, ked je aj USPESNA vetva cervena
        # (odmietnutie cudzou zmenou) — zlyhanie prepoctu je cervene vzdy.
        def refresh_and_report(ok_msg, fail_msg, ok_error: false)
          return set_status(ok_msg, ok_error) if refresh_studio

          set_status(fail_msg, true)
        end

        # Plny push Studia: sadzby menia CISLA zakazky (rozpocet, cenova
        # ponuka), takze generacia sa ZDVIHA — nie je to mutacia rozpoctu, ale
        # zmena vstupu vypoctu (vzor `price_refresh_after_proc`).
        #
        # Vracia BOOLEAN „klient to naozaj dostal": `refresh_if_open` vracia
        # vysledok `push_state` (teda `js`), `nil` pri zavretom okne a `nil` pri
        # zachytenej vynimke. Volajuci sa podla toho rozhoduje, co smie tvrdit.
        def refresh_studio(bump: true)
          return false unless defined?(StudioDialog)

          StudioDialog.refresh_if_open(bump: bump) ? true : false
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.refresh_studio')
          false
        end
      end
    end
  end
end
