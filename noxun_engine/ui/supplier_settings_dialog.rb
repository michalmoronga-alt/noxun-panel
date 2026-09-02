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
      # D-52b1 pridala DVE akcie updatera (sekcia `about`): kontrolu verzie
      # a ulozenie distribucneho priecinka. Mena su prefixovane `updater_`
      # z toho isteho dovodu ako `ss_` — vsetky sekcie Studia ziju v JEDNOM
      # priestore callbackov okna.
      #
      # SAMOTNA AKTUALIZACIA (`updater_apply`) je VEDOME MIMO tejto davky —
      # bariera okien, priprava balika vo vlakne a commit su D-52b2. V tejto
      # davke sa cesta nastavi a verzia OVERI; tlacidlo „Aktualizovať" je
      # `aria-disabled` s dovodom (D-78: nedostupna akcia sa hlasi, nemlci).
      SECTION_ACTIONS = %w[ss_save ss_reload updater_check updater_set_dir].freeze

      # --- D-52b1: casovanie kontroly verzie -------------------------------
      # Kontrola cita hlavicku loadera zo ZDROJA, ktory je typicky sietovy
      # share — odpojeny disk vie „viset" desiatky sekund. Preto deadline: po
      # nom sa vysledok uz nikdy nepouzije a sekcia povie, ze zdroj neodpovedal.
      UPDATER_DEADLINE_S = 4.0
      UPDATER_POLL_S = 0.2

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
        # Asynchronna kontrola verzie stoji na TROCH veciach z prostredia:
        # hodiny, vlakno a timer. Headless sada ich nahradí, takze sa token aj
        # deadline daju overit bez SketchUpu a bez cakania v realnom case.
        # V produkcii su vsetky `nil` a kod ide standardnou cestou (vzor
        # `Materials` `test_dir_override`).
        attr_accessor :test_clock, :test_spawn, :test_schedule

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
        # JADRO (recovery, zamok, lease, manifest, staging, swap, latch) je
        # z D-52a (`core/updater.rb`, ciste headless; od tejto davky rozdelene
        # na `prepare!` + `commit!`). Tato vrstva pridava LEN:
        #   * pole distribucneho priecinka s vlastnym ulozenim (F7/F11),
        #   * asynchronnu kontrolu verzie s deadline a tokenom (F5/F6),
        #   * DOKLAD o kontrole, z ktoreho bude vychadzat D-52b2.
        #
        # SAMOTNE APLIKOVANIE JE MIMO TEJTO DAVKY (D-52b2): bariera okien,
        # priprava balika vo vlakne, commit a natívne hlasky vysledku.

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
