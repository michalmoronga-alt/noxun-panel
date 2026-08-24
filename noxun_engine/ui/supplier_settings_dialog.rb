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
      SECTION_ACTIONS = %w[ss_save ss_reload].freeze

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
          when 'ss_save'   then handle_save(payload)
          when 'ss_reload' then handle_reload
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
        def about_info
          { 'version' => Engine::VERSION, 'dir' => appdata_dir }
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
          refresh_studio
          set_status('Nastavenia načítané nanovo zo súboru.')
        end

        # Ulozenie: revizia -> patch (validate-all) -> prepocet Studia.
        def handle_save(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          current = SupplierSettings.revision(SupplierSettings.active)
          if data['revision'].to_s != current
            # Review #227 P1: klient drzi reviziu PRIPNUTU na stav, nad ktorym
            # zacal pisat — inak by plny push reviziu omladil, zamok by presiel
            # a cudzia zmena by zmizla bez slova. A odmietnutie MUSI rozpisane
            # hodnoty ZAHODIT (`SS.saved()`, presne ako to robilo okno): bez toho
            # by prezili push, prekryli cerstve cisla a DRUHY klik by ich ticho
            # prepisal — hlaska pritom tvrdi, ze formular je nacitany nanovo.
            # Hlaska a spravanie sa musia zhodovat (review #227 P1-2).
            js('SS.saved()')
            refresh_studio
            return set_status('Nastavenia sa medzitým zmenili — formulár je načítaný nanovo. ' \
                              'Skontroluj hodnoty a ulož znova.', true)
          end
          patch = data['patch'].is_a?(Hash) ? data['patch'] : {}
          ok, errors = SupplierSettings.patch_active!(patch)
          # Pri chybe sa formular ZAMERNE NEnacitava nanovo — pouzivatel by
          # prisiel o vsetky rozpisane hodnoty a videl by len hlasku. Nic sa
          # nezapisalo (patch je all-or-nothing), takze staci chybu ukazat.
          return set_status("Neuložené: #{Array(errors).join(' · ')}", true) unless ok

          # POTVRDENY zapis — az teraz smie klient zahodit rozpisane hodnoty.
          js('SS.saved()')
          # Sadzby su vstup rozpoctu — cisla Studia MUSIA byt cerstve. Je to TA
          # ISTA refresh cesta, aku mal satelit (kontrakt „KAZDE okno s cislami
          # zakazky je vo VSETKYCH refresh cestach"), len bezi zvnutra okna.
          refresh_studio
          set_status('Nastavenia uložené. Rozpočet je prepočítaný.')
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

        # Plny push Studia: sadzby menia CISLA zakazky (rozpocet, cenova
        # ponuka), takze generacia sa ZDVIHA — nie je to mutacia rozpoctu, ale
        # zmena vstupu vypoctu (vzor `price_refresh_after_proc`).
        def refresh_studio(bump: true)
          return unless defined?(StudioDialog)

          StudioDialog.refresh_if_open(bump: bump)
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.refresh_studio')
        end
      end
    end
  end
end
