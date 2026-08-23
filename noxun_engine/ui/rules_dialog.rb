# frozen_string_literal: true
# Noxun Engine — SERVEROVA AUTORITA PRAVIDIEL KOVANIA.
#
# ŠT-3b-1: satelitne okno „Pravidlá kovania" ZANIKLO (HtmlDialog, `DLG_KEY`,
# `rules.html`, polozka menu aj tlacidlo v paneli). Jedine UI pravidiel je
# odteraz SEKCIA `rules` v okne ŠTÚDIO. Modul sa pritom ZAMERNE NEPREMENUVA
# (vzor audit #21 zo ŠT-2a): zaniklo OKNO, nie serverova autorita — telo
# kazdej akcie aj vsetky guardy ziju dalej TU.
#
# ZDROJE A ZIVOTNY CYKLUS (audit K2/K3):
#   - Edituju sa PROJEKTOVE pravidla (snapshot v NOXUN dict na modeli). Ulozenie =
#     zapis snapshotu + prestavba VSETKYCH korpusov v JEDNEJ operacii (rebuild_many
#     s blokom) -> 1x undo vrati pravidla aj geometriu naraz.
#   - "Ulozit aj ako globalnu predvolbu" navyse zapise %APPDATA% kniznicu (default
#     pre NOVE projekty). Globalny zapis nie je sucast undo (je to preferencia).
#   - "Nacitat globalne predvolby" len naplni formular — plati az po Ulozit.
#
# ADRESAT odpovede (vzor ŠT-3a-2): pocas synchronneho volania sekcie ho drzi
# `with_client(sink)`, mimo neho ide vsetko do Studia (`StudioDialog.rules_js`).
# ZIADNE asynchronne behy tento modul nema — na rozdiel od katalogu kovania
# tu neexistuje fetch, ktory by dobiehal po navrate z `dispatch`, takze
# `run_target`/session token netreba.
require 'json'

module Noxun
  module Engine
    module RulesDialog
      # UZAVRETY whitelist akcii, ktore smie poslat SEKCIA `rules`. Klient
      # posiela iba MENO akcie — co sa smie zavolat, rozhoduje SERVER.
      #
      # `ready` v zozname NIE JE (a byt nemoze): Studio registruje callbacky
      # pod TYMI ISTYMI menami, takze `ready` by prepisal jeho vlastny.
      # Prvotny stav sekcie nesie `push_state` Studia pod klucom `rules`.
      SECTION_ACTIONS = %w[save_rules load_global merge_seed].freeze

      class << self
        # --- vstup SEKCIE `rules` (vzor HardwareCatalogDialog.dispatch) ------

        def dispatch(name, payload, sink)
          key = name.to_s
          unless SECTION_ACTIONS.include?(key)
            return sink.call(status_script('Neznáma akcia pravidiel kovania.', true))
          end

          with_client(sink) { run_section_action(key, payload) }
        rescue StandardError => e
          Engine.log_error(e, "RulesDialog.dispatch #{name}")
          sink.call(status_script("Chyba: #{e.message}", true))
        end

        def run_section_action(key, payload)
          case key
          when 'save_rules'  then handle_save(payload)
          when 'load_global' then push_global
          when 'merge_seed'  then handle_merge_seed # V0.6 D1b (audit F4)
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

        # --- Ruby -> JS -----------------------------------------------------
        #
        # ŠT-3b-1: `push_state` (`RD.init` do okna) ZANIKLO spolu s nim —
        # prvotny aj kazdy dalsi stav sekcie nesie `push_state` Studia pod
        # klucom `rules` (`rules_payload` nizsie).

        # Payload sekcie. Model chodi ARGUMENTOM (lekcia F4 zo ŠT-3a-2): pri
        # prepnuti dokumentu by inak sekcia dostala pravidla STAREHO dokumentu
        # vedla kusovnika noveho — `Sketchup.active_model` sa v case broadcastu
        # este nemusel prepnut.
        #
        # ZAPADKA (`full_pending`) sa tu ZAMERNE NEPOUZIVA: pravidla su maly
        # JSON (jednotky zaznamov, ziadne `row_rev` per polozka ako katalog),
        # takze plny payload pri kazdom pushi je lacnejsi nez druhy kanal.
        #
        # Pri KAZDOM zostaveni sa obnovi BASELINE — presne to, co robil
        # `push_state` okna: formular je platny len pre stav, z ktoreho bol
        # naplneny.
        def rules_payload(model)
          project = HardwareRules.project_rules(model)
          rules = project || HardwareRules.load
          @baseline_guid  = model_guid(model)
          @baseline_rules = rules
          { 'version' => Engine::VERSION,
            'rules' => rules,
            'source' => project ? 'project' : 'global',
            'model_guid' => @baseline_guid,
            'cabinets' => cabinets(model).size }
        rescue StandardError => e
          # Zlyhanie sa NEZAMLCUJE: sekcia ostane bez dat a jedinou stopou
          # preco je tento zaznam (rovnaka lekcia ako `mat_payload`).
          Engine.log_error(e, 'RulesDialog.rules_payload')
          nil
        end

        # ŠT-3b-1: identita dokumentu je `model.guid`, NIE `model.path`.
        # Cesta dva NEULOZENE modely nerozlisi (oba maju prazdny path) — a to
        # si priznaval uz povodny komentar okna. `guid` je ta ista autorita,
        # akou sa riadia vsetky ostatne zapisovacie cesty Studia.
        def model_guid(model)
          model ? model.guid.to_s : ''
        end

        # Formular je platny len pre stav, z ktoreho bol naplneny: ZHODA
        # DOKUMENTU (guid) + ZHODA aktualnych pravidiel modelu s baseline
        # (chyti undo snapshotu aj subeznu zmenu z inej cesty). Pri nezhode sa
        # nic nezapise a klient dostane cerstvy formular.
        def baseline_valid?(model)
          return false if model_guid(model) != @baseline_guid.to_s

          current = HardwareRules.project_rules(model) || HardwareRules.load
          current == @baseline_rules
        end

        # V0.6 D1b (audit F4): vedome doplnenie novych default pravidiel do
        # PROJEKTOVEHO snapshotu (nikdy sa nemerguje sam).
        # D-90 (Codex #144 P1): snapshot sa zapisuje V TEJ ISTEJ operacii ako
        # PRESTAVBA vsetkych skriniek — presne ako handle_save. Bez prestavby by
        # nove pravidlo sice bolo v snapshote, ale ulozene config.hardware[]
        # skriniek by ho nepoznali: kusovnik ani nakupny zoznam citaju SNAPSHOT
        # NA ENTITE, takze profil by do objednavky nikdy nedosiel (a warning
        # profile_rule_missing by z KONTROLY zmizol skor, nez sa problem vyriesil).
        def handle_merge_seed
          model = Sketchup.active_model
          return set_status('Žiadny aktívny model.', true) if model.nil?

          existing = HardwareRules.project_rules(model)
          if existing.nil?
            return set_status('Projekt ešte nemá vlastné pravidlá — preberá globálne (nie je čo dopĺňať).')
          end

          rules, added, refreshed = HardwareRules.project_seed_plan(existing)
          # ŠT-3b-1 (lekcia F8 zo ŠT-3a-2): NO-OP nerobi ZIADNY push. Nic sa
          # nezmenilo, takze plny prepocet kusovnika by bol zbytocny a zdvih
          # generacie by navyse zneplatnil rozkliknuty riadok Kusovnika
          # a rozrobeny export inej sekcie — po akcii, ktora NIC neurobila.
          if added.empty? && refreshed.empty?
            return set_status('Projekt už má všetky predvolené pravidlá v aktuálnom tvare.')
          end

          jobs = cabinets(model).map { |c| [c, CabinetBuilder.config_to_params(Store.config(c) || {})] }
          CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: doplnenie predvolenych pravidiel') do
            raise 'Predvolené pravidlá sa nepodarilo uložiť do projektu.' unless
              HardwareRules.set_project_rules(model, rules)
          end
          parts = []
          parts << "doplnené: #{added.join(', ')}" unless added.empty?
          parts << "obnovené: #{refreshed.join(', ')}" unless refreshed.empty?
          set_status("Predvolené pravidlá — #{parts.join(' · ')} · prestavaných #{jobs.size} skriniek.")
          after_model_write(model)
        end

        # ŠT-3b-1: `on_model_changed` ZANIKLO spolu s oknom (a s nim aj jeho
        # vetva v `scale_observer`). Modul uz ziadne UI nevlastni a ziadny
        # asynchronny beh nema, takze po prepnuti dokumentu netreba nic rusit
        # — sekciu obsluzi PLNY push Studia z toho isteho broadcastu
        # (`StudioDialog.on_model_changed` -> `rules_payload(model)`).

        def push_global
          js("RD.setRules(#{HardwareRules.load.to_json}, 'global')")
          set_status('Načítané globálne predvoľby — platia až po Uložiť.')
        end

        # Stavovy riadok sekcie: prijimac `RD.setStatus` je v tom istom
        # `js/rules.js`, ktory sekcia nacitava, a `#status` je uzol
        # `studio.html`. Text sklada SERVER (jedna autorita).
        def status_script(msg, error = false)
          "RD.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})"
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

        # Kanal SEKCIE. `js` Studia je private (patri jeho kanalu), preto
        # tenky verejny most `rules_js` — vzor `StudioDialog.hw_js`.
        def studio_js(script)
          return false unless defined?(StudioDialog)

          StudioDialog.rules_js(script)
        rescue StandardError => e
          Engine.log_error(e, 'RulesDialog.studio_js')
          false
        end

        # --- akcie ----------------------------------------------------------

        # Ulozi pravidla do projektu + prestavia vsetky korpusy (1 undo krok).
        def handle_save(payload)
          model = Sketchup.active_model
          unless baseline_valid?(model)
            # Formular sa nacita nanovo PLNYM pushom (nesie `rules`), takze
            # klient uvidi, co v projekte naozaj plati.
            refresh_studio(bump: false)
            return set_status('Aktívny model/pravidlá sa medzitým zmenili — formulár je načítaný nanovo. ' \
                              'Skontroluj a ulož znova.', true)
          end
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          rules = HardwareRules.normalize_rules(data['rules'])
          return set_status('Žiadne platné pravidlá — nič sa neuložilo.', true) if rules.empty?

          jobs = cabinets(model).map { |c| [c, CabinetBuilder.config_to_params(Store.config(c) || {})] }
          CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: pravidla kovania') do
            raise 'Pravidlá sa nepodarilo uložiť do projektu.' unless HardwareRules.set_project_rules(model, rules)
          end

          global_note = ''
          if data['also_global']
            global_note = HardwareRules.write(rules) ? ' + globálna predvoľba' : ' (globálny zápis zlyhal!)'
          end
          set_status("Pravidlá uložené do projektu#{global_note} — prestavaných #{jobs.size} skriniek.")
          after_model_write(model)
        end

        # ŠT-3b-1: po ZAPISE DO MODELU (ulozenie pravidiel aj doplnenie
        # predvolenych) musia cerstve cisla dostat OBAJA odberatelia:
        #   * PANEL — pravidla menia kovanie v sekcii Kovanie Inspectora,
        #   * ŠTÚDIO — prestavba VSETKYCH korpusov meni kusovnik, nakupny
        #     zoznam aj rozpocet, takze `bump: true` (rozkliknuty riadok
        #     zo starych cisel uz neplati).
        # Poradie je zavazne (vzor `refresh_studio_after_model_write`
        # v `materials_dialog.rb`): NAJPRV panel, az potom Studio — pripadny
        # dedup identity kopii je oneskoreny a jantarove „Obnoviť" by inak
        # zozltlo hned po vlastnom prepocte.
        def after_model_write(model)
          Panel.push_selected(model) if defined?(Panel)
          refresh_studio(bump: true)
        end

        def refresh_studio(bump: true)
          return unless defined?(StudioDialog)

          StudioDialog.refresh_if_open(bump: bump)
        rescue StandardError => e
          Engine.log_error(e, 'RulesDialog.refresh_studio')
        end

        def cabinets(model)
          out = []
          Ids.each_cabinet(model) { |i| out << i }
          out
        end
      end
    end
  end
end
