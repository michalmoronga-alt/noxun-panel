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
      SECTION_ACTIONS = %w[save_rules load_global merge_seed
                           reset_abs_override reset_hw_override].freeze

      # ŠT-3b-2a: poradie rol v read-only prehlade ABS pravidiel (korpus -> cela).
      # Poradie hashu z disku by sa menilo s kazdym seed-merge, takze ho urcuje
      # SERVER; rola z novsej verzie sa NEZAMLCI — pripoji sa na koniec.
      ABS_ROLE_ORDER = %w[side_left side_right top bottom shelf divider_v divider_h
                          back rail_front rail_back plinth front_door drawer_front
                          free_panel].freeze

      # Strop zoznamu rucnych zasahov (F15). „Použiť na podobné" vie vyrobit
      # desiatky riadkov naraz — nekonecny zoznam by zo sekcie spravil vypis.
      MAX_OVERRIDE_ROWS = 40

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
          # ŠT-3b-2b (Š17): „vrátiť na pravidlo" pri jantarovom riadku.
          when 'reset_abs_override' then handle_reset_abs(payload)
          when 'reset_hw_override'  then handle_reset_hw(payload)
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
        def rules_payload(model, collected = nil)
          project = HardwareRules.project_rules(model)
          rules = project || HardwareRules.load
          @baseline_guid  = model_guid(model)
          @baseline_rules = rules
          { 'version' => Engine::VERSION,
            'rules' => rules,
            'source' => project ? 'project' : 'global',
            'model_guid' => @baseline_guid,
            'cabinets' => cabinets(model).size,
            # ŠT-3b-2a: druha skupina sekcie — ABS pravidla podla ROLY dielca
            # (read-only prehlad) a jantarove riadky rucnych zasahov. Texty
            # sklada SERVER (jedna autorita nazvov), klient nic neprekladá.
            'abs' => abs_payload,
            'overrides' => overrides_payload(collected) }
        rescue StandardError => e
          # Zlyhanie sa NEZAMLCUJE: sekcia ostane bez dat a jedinou stopou
          # preco je tento zaznam (rovnaka lekcia ako `mat_payload`).
          Engine.log_error(e, 'RulesDialog.rules_payload')
          nil
        end

        # ================ ŠT-3b-2a: ABS podla roly + rucne zasahy ==============
        #
        # Poradie skupin v sekcii: ABS NAD kovanim (mockup Š17). Skupina ABS je
        # ZATIAL LEN NA CITANIE — editor pravidiel ABS v pluginu NEEXISTUJE
        # (ziadne okno, ziadny formular), a hint sekcie to musi priznat; opacny
        # dojem by posielal pouzivatela hladat nieco, co nie je (F8).
        #
        # ROZSAH PLATNOSTI (F9) je u kazdej skupiny INY a musi to byt vidiet:
        # kovanie = snapshot TOHTO projektu (.skp), ABS = GLOBALNE predvolby
        # v %APPDATA% spolocne pre vsetky zakazky. Preto ma kazda skupina
        # vlastny riadok zdroja.
        #
        # Read-only prehlad pravidiel ABS. VLASTNY rescue (F7): zlyhanie citania
        # globalneho suboru nesmie vziat cely payload — formular pravidiel
        # kovania s nim nema nic spolocne.
        def abs_payload
          # N20: `AbsRules.rules` ma VEDLAJSI EFEKT (ensure_seeded zapisuje subor).
          # Volat sa smie LEN mimo `model.start_operation` — zostavovanie payloadu
          # ziadna operacia nie je, ale kopirovat toto volanie do zapisovacej cesty
          # by znamenalo zapis na disk vnutri undo kroku.
          rules = AbsRules.load
          rules = {} unless rules.is_a?(Hash)
          order = ABS_ROLE_ORDER + (rules.keys.map(&:to_s) - ABS_ROLE_ORDER)
          rows = order.filter_map { |role| rules.key?(role) ? abs_rule_row(role, rules[role]) : nil }
          { 'rows' => rows,
            'source' => 'zdroj: globálne predvoľby (spoločné pre všetky zákazky) · ' \
                        'zmena neprestaví už postavené skrinky',
            'hint' => 'ABS pravidlá podľa roly zatiaľ nemajú editor — plugin ich len číta. ' \
                      'Hrany konkrétneho dielca sa menia v Inspectore (karta dielca) a taký ' \
                      'zásah sa nižšie ukáže ako override.' }
        rescue StandardError => e
          Engine.log_error(e, 'RulesDialog.abs_payload')
          { 'rows' => [], 'source' => 'ABS pravidlá sa nepodarilo načítať.', 'hint' => '' }
        end

        # Jeden riadok pravidla. N19: pravidlo ABS je HRUBKA (1,0 / 2,0 mm), NIE
        # konkretna paska — dekor sa dopocita z materialu dielca az pri stavbe.
        # Riadok preto nikdy nepise nazov ani kod pasky (klamal by pri kazdej
        # zmene materialu).
        def abs_rule_row(role, edges)
          labels = AbsRules.edge_labels(role)
          map = edges.is_a?(Hash) ? edges : {}
          present = AbsRules::EDGE_ORDER.select { |c| map[c] }
          row = { 'role' => role.to_s, 'label' => abs_role_label(role) }
          if present.empty?
            return row.merge('desc' => 'bez pravidla', 'value' => 'bez olepu')
          end

          ths = present.map { |c| map[c].to_f }.uniq
          if ths.length == 1
            desc = present.length == AbsRules::EDGE_ORDER.length ? 'všetky štyri hrany'
                                                                 : present.map { |c| labels[c] }.join(' · ')
            row.merge('desc' => desc, 'value' => "#{mm(ths.first)} mm")
          else
            row.merge('desc' => 'rôzne hrúbky podľa hrán',
                      'value' => present.map { |c| "#{labels[c]} #{mm(map[c].to_f)} mm" }.join(' · '))
          end
        end

        def abs_role_label(role)
          label = defined?(ProductionCore) ? ProductionCore.role_label(role) : ''
          label.to_s.empty? ? role.to_s : label
        end

        # --- jantarove riadky: EXISTENCIA rozhodnutia, nie jeho spravnost -----
        #
        # F11: riadok NEHOVORI o tom, ci je olep spravny (to je vec KONTROLY —
        # EdgeCheck a semafor); hovori, ze na tomto mieste rozhodol CLOVEK a
        # pravidlo sa neuplatni. Preto ziadna ⚠, ziadna semaforova bodka a
        # ziadny vstup do poctov Kontroly — len stitok „override".
        def overrides_payload(collected)
          man = collected.is_a?(Hash) ? collected[:manual_overrides] : nil
          man = {} unless man.is_a?(Hash)
          emap = defined?(ProductionCore) ? ProductionCore.edges_map : nil
          { 'abs' => override_group(Array(man['abs']).filter_map { |o| abs_override_row(o, emap) },
                                    'Dielce s ručne nastavenými hranami',
                                    'Tieto dielce majú hrany nastavené ručne v Inspectore — pravidlo ' \
                                    'podľa roly sa na ne neuplatní. Šípka vráti dielec na pravidlo ' \
                                    '(všetky štyri hrany naraz; jeden krok Späť to vráti). Jednu hranu ' \
                                    'vrátiš v karte dielca.'),
            'hardware' => override_group(Array(man['hardware']).filter_map { |o| hw_override_row(o) },
                                         'Skrinky s ručne nastaveným kovaním',
                                         'Toto kovanie nastavil človek v Inspectore — pravidlo podľa ' \
                                         'rozmerov sa naň neuplatní. Šípka vráti položku na pravidlo ' \
                                         '(zruší počet, vypnutie aj zámok dĺžky naraz; jeden krok ' \
                                         'Späť to vráti).') }
        rescue StandardError => e
          # F7: zber rucnych zasahov MUSI zlyhat sam za seba — inak by chyba
          # v jednom riadku zhodila formular pravidiel kovania vedla neho.
          Engine.log_error(e, 'RulesDialog.overrides_payload')
          { 'abs' => empty_override_group, 'hardware' => empty_override_group }
        end

        def empty_override_group
          { 'total' => 0, 'groups' => [], 'more' => 0, 'title' => '', 'note' => '', 'more_text' => '' }
        end

        # Zoskupenie po SKRINKACH + strop so suhrnom (F15).
        def override_group(rows, title, note)
          total = rows.length
          return empty_override_group if total.zero?

          shown = rows.first(MAX_OVERRIDE_ROWS)
          groups = []
          shown.each do |r|
            g = groups.find { |x| x['owner_id'] == r['owner_id'] }
            unless g
              g = { 'owner_id' => r['owner_id'], 'title' => owner_title(r), 'rows' => [] }
              groups << g
            end
            g['rows'] << r
          end
          more = total - shown.length
          { 'total' => total, 'groups' => groups, 'more' => more,
            'title' => "#{title} (#{total})", 'note' => note,
            'more_text' => more.zero? ? '' : "…a ďalších #{more} — zoznam je skrátený." }
        end

        def owner_title(row)
          id = row['owner_id'].to_s
          name = row['owner_name'].to_s.strip
          id = 'bez identity' if id.empty?
          name.empty? ? id : "#{id} · #{name}"
        end

        # Riadok ABS overridu. Zhrnutie sa sklada z TOHO, CO POUZIVATEL ULOZIL
        # (kluc `edges` v configu korpusu), nie z vyriesenych hran na entite —
        # inak by riadok tvrdil nieco ine, nez co sa da vratit.
        def abs_override_row(ov, edges_map)
          return nil unless ov.is_a?(Hash)

          edges = ov['edges']
          return nil unless edges.is_a?(Hash)

          role = ov['role'].to_s
          labels = AbsRules.edge_labels(role)
          parts = AbsRules::EDGE_ORDER.select { |c| edges.key?(c) }.map do |c|
            "#{labels[c]}: #{abs_edge_value(edges[c], edges_map)}"
          end
          return nil if parts.empty?

          name = ov['name'].to_s.strip
          # `kind` = adresa ZAPISOVEJ akcie riadku (ŠT-3b-2b). Klient z neho
          # vybera meno callbacku; co sa smie zavolat, rozhoduje whitelist.
          { 'kind' => 'abs',
            'owner_id' => ov['owner_id'].to_s, 'owner_name' => ov['owner_name'].to_s,
            'part_key' => ov['part_key'].to_s,
            'label' => name.empty? ? abs_role_label(role) : name,
            'desc' => 'ručne nastavené hrany',
            'value' => parts.join(' · ') }
        end

        # Hodnota jednej hrany. Prazdna/nil = vedome „bez olepu"; paska MIMO
        # katalogu vrati surove id (`ProductionCore.edge_label`) — radsej surove
        # id nez vymysleny nazov.
        def abs_edge_value(value, edges_map)
          id = value.to_s.strip
          return 'bez olepu' if id.empty?
          return id unless edges_map.is_a?(Hash) && defined?(ProductionCore)

          ProductionCore.edge_label(edges_map[id], id)
        end

        # Riadok overridu kovania. Zaznam nesie NEZAVISLE polia (D-93), takze
        # riadok vypise VSETKY, ktore su nastavene — prazdny zaznam sa nekresli.
        def hw_override_row(ov)
          return nil unless ov.is_a?(Hash)

          bits = []
          bits << 'vypnuté — nepočíta sa do súpisu' if ov['disabled'] == true
          bits << "počet #{ov['quantity'].to_i} ks" unless ov['quantity'].nil?
          bits << "dĺžka #{num(ov['nominal_length'])} mm" unless ov['nominal_length'].nil?
          return nil if bits.empty?

          pkey = ov['owner_part_key'].to_s
          part = ov['part_name'].to_s.strip
          part = abs_role_label(ov['part_role']) if part.empty? && !ov['part_role'].to_s.empty?
          { 'kind' => 'hw',
            'owner_id' => ov['owner_id'].to_s, 'owner_name' => ov['owner_name'].to_s,
            'part_key' => pkey,
            # Identita zaznamu je TROJICA — bez nej by sa reset nedal adresovat
            # (dve pravidla s rovnakym vystupom na tom istom ownerovi su
            # samostatne zaznamy).
            'generic_type' => ov['generic_type'].to_s, 'rule_id' => ov['rule_id'].to_s,
            'label' => HardwareRules.label_for(ov['generic_type']),
            'desc' => pkey.empty? ? 'ručne nastavené na skrinke' : "ručne nastavené · #{part}",
            'value' => bits.join(' · ') }
        end

        # mm po slovensky (desatinna CIARKA). ABS hrubky su 1,0 / 2,0 — desatinne
        # miesto sa NEZAOKRUHLUJE prec, aby sa „1,0 mm" nemylila s poctom kusov.
        def mm(value)
          f = value.to_f
          format('%.1f', f).tr('.', ',')
        end

        # Rozmer v mm (dlzka vysuvu): cele cislo BEZ desatinneho miesta —
        # „420,0 mm" by pri dlzke vyzeralo ako presnost, ktoru nikto nezadal.
        def num(value)
          f = value.to_f
          (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
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
          # Review #220 P2: identita dokumentu Z PAYLOADU je DRUHA vrstva nad
          # baseline — klient ju posiela z `RD_META.model_guid`, teda z toho
          # istého payloadu, ktorým bol formulár naplnený. Guard je lacný
          # a kryje aj prípad, keď by baseline z akéhokoľvek dôvodu prešiel.
          # Tolerantne (vzor `do_budget`): PRAZDNY udaj zo starsieho cachovaneho
          # DOM guard neblokuje, NEZHODNE ID ano.
          guid = data['model_guid'].to_s
          if !guid.empty? && guid != model_guid(model)
            refresh_studio(bump: false)
            return set_status('Model sa medzitým prepol — pravidlá sú načítané z tohto modelu. ' \
                              'Skontroluj a ulož znova.', true)
          end
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

        # ============ ŠT-3b-2b: „VRÁTIŤ NA PRAVIDLO" (jantarovy riadok) =======
        #
        # Klik na sipku v riadku ZAHODI rucne rozhodnutie a nechá platit pravidlo.
        # Potvrdenie sa NEPYTA — poistkou je JEDEN krok Spat (kontrakt mockupu),
        # a otazka pred kazdym klikom by z jednoduchej opravy urobila obrad.
        #
        # PRECO NOVA CESTA (nalezy 14/15 auditu): zapisove cesty Inspectora stoja
        # na OZNACENI v modeli (`find_cabinet`/`find_selected_part`) a po zapise
        # vyber prepisu. Zoznam v sekcii ale adresuje riadok IDENTITOU
        # (cabinet_id + part_key resp. + generic_type/rule_id) a vyber sa pri nom
        # menit NESMIE — pouzivatel moze mat oznacene nieco uplne ine.
        # ZDIELA sa TELO ZAPISU (`Panel.reset_part_edges!`, `Panel.merge_override`
        # s `:all`), nie okenne guardy — tie su per vstupny bod (audit B4).
        #
        # SPOLOCNY VSTUPNY GUARD oboch resetov. Vrati [model, cab, data], alebo
        # nil — a vtedy UZ POVEDAL preco a obnovil sekciu.
        def reset_context(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return reject_reset('Žiadny aktívny model.', refresh: false) if model.nil?

          # (1) GENERACIA OKNA — klik zo zastaraneho zoznamu (riadok medzitym
          #     zanikol alebo sa presunul) sa NEVYKONA. Vzor kliku v Kusovniku.
          gen = studio_generation
          if !gen.nil? && gen.positive? && data['gen'].to_i != gen
            return reject_reset('Zoznam sa medzitým prepočítal — obnovený, klikni znova.')
          end

          # (2) DOKUMENT — tolerantne na PRAZDNY udaj (starsi cachovany DOM),
          #     nezhodne id odmietame (vzor `handle_save`).
          guid = data['model_guid'].to_s
          if !guid.empty? && guid != model_guid(model)
            return reject_reset('Model sa medzitým prepol — sekcia je načítaná z tohto modelu.')
          end

          # (3) ADRESA je `cabinet_id`. Cerstva kopia skrinky moze mat este TO
          #     ISTE id (vlastne dostane az pri dedup tiku), takze kandidatov moze
          #     byt viac. Vtedy sa zapis ODMIETA: „vezmi prvu" by prepisala
          #     skrinku, na ktoru pouzivatel neklikol, a spustit dedup TU by
          #     otvorilo DRUHU operaciu — z jedneho kliku by boli dva kroky Spat.
          cid = data['owner_id'].to_s
          return reject_reset('Chýba identifikácia skrinky — zoznam je obnovený.') if cid.empty?

          cands = cabinets(model).select { |c| Store.get(c, 'cabinet_id').to_s == cid }
          return reject_reset("Skrinka #{cid} sa v modeli nenašla — zoznam je obnovený.") if cands.empty?

          if cands.length > 1
            return reject_reset("Skrinku #{cid} má v modeli viac kusov naraz (čerstvá kópia ešte nemá " \
                                'vlastné číslo) — nič sa nezmenilo. Klikni raz do modelu a skús znova.')
          end

          [model, cands.first, data]
        end

        # Odmietnutie: sekcia sa nacita nanovo BEZ zdvihu generacie (nic sa
        # nezapisalo, takze rozkliknute riadky inych sekcii maju ostat platne).
        def reject_reset(msg, refresh: true)
          refresh_studio(bump: false) if refresh
          set_status(msg, true)
          nil
        end

        # Generacia okna Studio (nil = okno nie je nacitane -> guard sa preskoci).
        def studio_generation
          return nil unless defined?(StudioDialog)

          StudioDialog.generation
        rescue StandardError
          nil
        end

        # --- ABS: cely olep dielca spat na pravidlo --------------------------
        #
        # Maze sa CELY kluc `edges` (kontrakt mockupu — riadok je o dielci, nie
        # o jednej hrane). Reset JEDNEJ hrany ostava v karte dielca („podľa
        # pravidla" v rozbalovacom menu hrany).
        def handle_reset_abs(payload)
          ctx = reset_context(payload)
          return if ctx.nil?

          model, cab, data = ctx
          pkey = data['part_key'].to_s
          return reject_reset('Chýba identifikácia dielca — zoznam je obnovený.') if pkey.empty?

          params = Panel.existing_params(cab)
          rk = Panel.canonical_part_key(params, pkey)
          ov = params['part_overrides']
          rec = ov.is_a?(Hash) ? ov[rk] : nil
          unless rec.is_a?(Hash) && rec['edges'].is_a?(Hash)
            # Riadok uz neplati (niekto ho medzitym vratil inou cestou). Nie je to
            # chyba pouzivatela — zoznam sa len obnovi.
            refresh_studio(bump: false)
            return set_status('Tento dielec už ručne nastavené hrany nemá — zoznam je obnovený.')
          end

          # Prestavba prekresluje VNORENE dielce. Ked v skrinke ziadny s tymto
          # klucom nie je, nemal by co prekreslit — a hlaska o uspechu by klamala.
          if Panel.find_part_by_role_key(cab, rk).nil?
            return reject_reset('Dielec sa v skrinke nenašiel — zoznam je obnovený.')
          end

          had_sel = model.selection.count.positive?
          Panel.reset_part_edges!(params, rk)
          CabinetBuilder.rebuild_many(model, [[cab, params]], op_name: 'NOXUN: ABS spat na pravidlo')

          cid = Store.get(cab, 'cabinet_id').to_s
          who = abs_part_label(cab, rk)
          msg = "#{cid} · #{who} — späť na pravidlo (#{abs_rule_result(cab, rk)}). " \
                'Jeden krok Späť to vráti.'
          msg += detached_twin_note(model, cid, rk)
          msg += selection_note(model, had_sel)
          set_status(msg)
          after_model_write(model)
        end

        # VYSLEDOK, nie len „override zrušený" (F13): po prestavbe sa cita
        # SNAPSHOT dielca — to iste, co ide do kusovnika a objednavky. Pri
        # kompakte/postformingu (potlacene defaulty) alebo dekore bez pasky
        # vyjde „bez olepu" a pouzivatel to vidi HNED, nie az vo vystupe.
        def abs_rule_result(cab, rk)
          part = Panel.find_part_by_role_key(cab, rk)
          cfg = part ? (Store.config(part) || {}) : {}
          edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : {}
          role = part ? Store.get(part, 'role').to_s : ''
          labels = AbsRules.edge_labels(role)
          taped = AbsRules::EDGE_ORDER.reject { |c| edges[c].to_s.strip.empty? }
          return 'podľa pravidla bez olepu' if taped.empty?

          "podľa pravidla: #{taped.map { |c| "#{labels[c].to_s.downcase} #{abs_thickness_text(edges[c])}" }
                                  .join(' · ')}"
        end

        # Hrubka pasky z katalogu; paska mimo katalogu = surove id (neklame).
        def abs_thickness_text(abs_id)
          rec = defined?(Materials) ? Materials.edge(abs_id) : nil
          rec && rec['thickness'] ? "#{mm(rec['thickness'])} mm" : abs_id.to_s
        end

        def abs_part_label(cab, rk)
          part = Panel.find_part_by_role_key(cab, rk)
          name = part ? Store.get(part, 'name').to_s.strip : ''
          return name unless name.empty?

          role = part ? Store.get(part, 'role').to_s : ''
          label = abs_role_label(role)
          label.to_s.empty? ? rk : label
        end

        # F14: odpojene dvojca. Override zije v korpuse a prestavba prekresli LEN
        # vnorene dielce — vytiahnuty dielec s tym istym klucom ostane po starom
        # (do vystupu ide jeho vlastny snapshot). TICHY uspech by poslal do
        # objednavky olep, ktory nikto na obrazovke nevidel.
        def detached_twin_note(model, cid, rk)
          return '' unless detached_twin?(model, cid, rk)

          ' POZOR: rovnaký dielec je aj vytiahnutý zo skrinky — ten sa neprestaval ' \
            'a do výstupu ide po starom.'
        end

        def detached_twin?(model, cid, rk)
          model.entities.grep(Sketchup::ComponentInstance).any? do |i|
            Store.kind(i) == 'part' && Store.get(i, 'cabinet_id').to_s == cid &&
              Store.get(i, 'part_key').to_s == rk
          end
        rescue StandardError => e
          Engine.log_error(e, 'RulesDialog.detached_twin?')
          false
        end

        # Vyber sa ZAMERNE nemeni (ziadny reselect) — pouzivatel moze mat
        # oznacene nieco uplne ine. Ked ho ale prestavba zhodila, prizna sa to.
        def selection_note(model, had_sel)
          had_sel && model.selection.count.zero? ? ' Výber v modeli sa prestavbou stratil.' : ''
        end

        # --- Kovanie: cely rucny zaznam spat na pravidlo ---------------------
        #
        # Maze sa CELY zaznam identity (owner_part_key, generic_type, rule_id) —
        # ekvivalent `field :all` v Inspectore, teda TO ISTE telo (`merge_override`).
        # Polia zaznamu su nezavisle (D-93), takze sa zrusia naraz vsetky: riadok
        # hovori o polozke, nie o jednom poli.
        def handle_reset_hw(payload)
          ctx = reset_context(payload)
          return if ctx.nil?

          model, cab, data = ctx
          gt = data['generic_type'].to_s
          rid = data['rule_id'].to_s
          return reject_reset('Chýba identifikácia položky kovania — zoznam je obnovený.') if gt.empty? || rid.empty?

          owner = Panel.present_str(data['part_key'])
          params = Panel.existing_params(cab)
          all = params['hardware_overrides'].is_a?(Array) ? params['hardware_overrides'] : []
          rec = all.select { |ov| Panel.ov_match?(ov, owner, gt, rid) }.last
          if rec.nil?
            refresh_studio(bump: false)
            return set_status('Toto kovanie už ručne nastavené nie je — zoznam je obnovený.')
          end

          # Dosledky sa hovoria PRED tym, nez zaniknu (zaznam uz potom neexistuje).
          note = hw_reset_note(model, rec, gt, rid)
          had_sel = model.selection.count.positive?
          params['hardware_overrides'] = Panel.merge_override(all, owner, gt, rid, :all, nil)
          CabinetBuilder.rebuild_many(model, [[cab, params]], op_name: 'NOXUN: kovanie spat na pravidlo')

          cid = Store.get(cab, 'cabinet_id').to_s
          who = HardwareRules.label_for(gt)
          msg = "#{cid} · #{who} — späť na pravidlo (#{hw_rule_result(cab, owner, gt, rid)}). " \
                'Jeden krok Späť to vráti.'
          msg += note
          msg += selection_note(model, had_sel)
          set_status(msg)
          after_model_write(model)
        end

        # VYSLEDOK zo SNAPSHOTU po prestavbe (F13) — kolko kusov dava pravidlo.
        # Ziadna polozka = pravidlo na tejto skrinke negeneruje nic (napr. je
        # vypnute); povedat to treba, inak by prazdny riadok vyzeral ako chyba.
        def hw_rule_result(cab, owner, gt, rid)
          items = Array((Store.config(cab) || {})['hardware']).select do |h|
            h.is_a?(Hash) && h['generic_type'].to_s == gt && h['rule_id'].to_s == rid &&
              (owner.nil? || h['owner_part_key'].to_s == owner.to_s)
          end
          qty = items.sum { |h| h['quantity'].to_i }
          qty.positive? ? "podľa pravidla: #{qty} ks" : 'podľa pravidla sa tu nepočíta nič'
        end

        # DVA dosledky, ktore pouzivatel z riadku nevidi (odpoved D auditu):
        #   * zrusenie „vypnuté" VRACIA polozku do supisu aj do NAKUPU — mení cenu,
        #   * zamok dlzky vysuvu MIMO dnesneho radu pravidla sa strati NENAVRATNE
        #     (ulozit sa da uz len hodnota z radu — `series_value?`).
        def hw_reset_note(model, rec, gt, rid)
          out = ''
          out += ' Položka sa vracia do súpisu aj do nákupu — mení cenu.' if rec['disabled'] == true
          nl = rec['nominal_length']
          if !nl.nil? && !Panel.series_value?(model, rid, gt, nl.to_f)
            out += " Zámok dĺžky #{num(nl)} mm sa stratil nenávratne — v rade pravidla už nie je, " \
                   'takže sa nedá zapísať znova.'
          end
          out
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
