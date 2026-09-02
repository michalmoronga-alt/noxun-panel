# frozen_string_literal: true
# Noxun Engine - Panel: Ruby->JS (push_init, push_selected, push_templates, set_status, js).
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- Ruby -> JS ------------------------------------------------------
        def push_init
          model = Sketchup.active_model
          cab = find_cabinet(model)
          # V0.4.7c: aj uz oznacena DOSKA pri otvoreni panela (Codex audit c, blocker B) —
          # priorita korpus -> doska -> nic, rovnaka ako push_selected.
          board = cab.nil? ? find_board(model) : nil
          # Codex #168 P2 (3. kolo): pociatocny payload musi byt ZRKADLOM
          # push_selected — inak sa panel pri otvoreni sprava inak nez pri
          # kazdom dalsom pushi:
          #   * bez model_guid by mala prva identita prazdny dokument a PRVE
          #     bezne echo by vyzeralo ako novy vyber (kontext by skocil na Korpus),
          #   * bez part_card by panel nad uz oznacenym DIELCOM otvoril rezim
          #     skrinky — bez docasnej polozky raily a bez karty dielca.
          initial = if cab
                      p = cabinet_payload(cab)
                      p['model_guid'] = model_guid(model)
                      part = find_selected_part(model)
                      p['part_card'] = part ? part_card_payload(model, cab, part) : nil
                      p
                    elsif board
                      p = board_payload(board)
                      p['model_guid'] = model_guid(model)
                      p
                    end
          data = {
            version: Engine::VERSION, # UI zobrazuje verziu odtialto — ziadny hardcode v HTML
            # ŠT-4a: priecinok nastaveni pre ZDIELANY obsah „O plugine" (js/about.js).
            # Do ŠT-4a stala cesta natvrdo v HTML — teraz ju dava server, takze sa
            # nemoze rozist so skutocnostou (a je to TA ISTA veta v oboch vstupoch).
            appdata_dir: about_dir,
            defaults: {
              lower: CabinetBuilder::LOWER_DEFAULTS,
              upper: CabinetBuilder::UPPER_DEFAULTS
            },
            # D-27: viditelnost NOXUN tagov v modeli — JEDEN stav pre okno
            # tagov v raile aj pre checkbox „Zobraziť zóny (ghost)". Samostatne
            # pole `zones_visible` tym zaniklo (dva zdroje jednej pravdy).
            tags: tags_state,
            # UI-D2 (Codex #181 P1): aj PRVY payload nesie `preview_rev` — inak by
            # panel po otvoreni povazoval vsetky sablony za bezobrazkove, o nahlad
            # by si nepovedal a fotky by naskocili az po nesuvisiacom push_templates.
            templates: template_list(previews: true),
            materials: materials_payload, # V0.3 katalog (dosky + ABS) pre selecty
            # (projektove predvolby zobrazuje okno MaterialsDialog — D2)
            selected: initial,
            selected_kind: cab ? 'cabinet' : (board ? 'board' : 'none'),
            # D-39 (audit B5): zamky vkladacej karty z Ruby pamate — preziju
            # zatvorenie panela; JS ich obnovi pri kazdom otvoreni (push_init).
            insert_locks: insert_locks,
            # D-90: ponuka uchytkovych profilov (id/nazov/skratenie) — JEDINY
            # zdroj je registry FrontProfiles, JS si ziadny zoznam nedrzi.
            front_profiles: FrontProfiles.options,
            # UI-B1 (audit A2): stav ABS kontroly hran pre ikonu v raile. PULL
            # pri otvoreni panela; dalsie zmeny chodia pushom (push_edge_check)
            # z panela, z toolbaru aj zo Studia. CISTE CITANIE.
            edge_check: edge_check_state,
            # K2/D-87: stav kontroly smeru kresby pre druhu funkcnu ikonu raily.
            # Ten isty vzor ako `edge_check` — PULL pri otvoreni panela, dalsie
            # zmeny pushom (z raily aj zo Studia). CISTE CITANIE.
            grain_check: grain_check_state,
            # KOV-A2b: stav symbolov smeru otvarania pre tretiu funkcnu ikonu
            # raily. Ten isty vzor ako `grain_check` — PULL pri otvoreni panela,
            # dalsie zmeny pushom (z raily aj zo Studia). CISTE CITANIE.
            direction_check: direction_check_state,
            # UI-B3 (koliesko): nastavenia POCITACA — rozmerove rady (N6) pre
            # ponuky pri rozmeroch a meno aktualnej temy pre prepinac vzhladu.
            # Nie su to data zakazky (ziju v %APPDATA%, nikdy v .skp).
            ui_settings: ui_settings_payload,
            # Identita dokumentu pre stavovy stroj panela aj pre identity guardy
            # asynchronnych callbackov (Codex #168 P2).
            model_guid: model_guid(model)
          }
          js("NX.init(#{data.to_json})")
        end

        # ŠT-4a: priecinok, v ktorom ziju nastavenia POCITACA — jedina veta
        # obsahu „O plugine", ktora sa da povedat NEPRESNE. Autoritou je ten isty
        # helper, ktory pouziva sklad nastaveni; ked nie je nacitany, obsah padne
        # na kontraktovu cestu v `js/about.js` (nikdy sa nezobrazi prazdno).
        def about_dir
          return SupplierSettings.dir if defined?(SupplierSettings) && SupplierSettings.respond_to?(:dir)

          ''
        rescue StandardError => e
          Engine.log_error(e, 'Panel.about_dir')
          ''
        end

        # UI-B1: stav zvyraznenia olepu pre rail. Nedostupny/nenacitany EdgeCheck
        # (SketchUp bez Overlay API) = ikona zosedne, panel sa tym nezhodi.
        def edge_check_state
          return { 'available' => false, 'active' => false } unless defined?(EdgeCheck)

          EdgeCheck.ui_state(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.edge_check_state')
          { 'available' => false, 'active' => false }
        end

        # Maly echo push stavu hran (bez prepoctu panela) — vzor
        # StudioDialog#push_edge_check. Vola ho Engine.broadcast_edge_check
        # (klik z panela, z toolbaru aj zo Studia) a EdgeCheck po prepocte.
        def push_edge_check(state = nil)
          return unless dialog_alive?

          st = state || edge_check_state
          js("if (window.NX && NX.setEdgeCheck) NX.setEdgeCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_edge_check')
        end

        # v0.7.28: zatvorenie rohoveho 3-stavoveho nastavenia v raile. Vola ho
        # Engine.close_edge_menu, ked pouzivatel otvoril TO ISTE nastavenie
        # v Studiu — dve kopie tych istych prepinacov na obrazovke naraz
        # by len mylili. Cisto zobrazovacie: ziadny stav, ziadny zapis.
        def close_edge_menu
          return unless dialog_alive?

          js('if (window.NX && NX.closeEdgeMenu) NX.closeEdgeMenu();')
        rescue StandardError => e
          Engine.log_error(e, 'Panel.close_edge_menu')
        end

        # D-27: viditelnost NOXUN tagov v modeli. CISTE CITANIE (`Tags.state`
        # nikdy netvori ani neprepina tag). Nenacitany modul = prazdny stav,
        # panel sa tym nezhodi — okno tagov je vtedy proste prazdne.
        def tags_state(model = nil)
          return { 'rows' => [], 'hidden' => 0 } unless defined?(Tags)

          Tags.state(model || Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.tags_state')
          { 'rows' => [], 'hidden' => 0 }
        end

        # Protajsok `push_edge_check`. Vola ho `Engine.broadcast_tags` (klik
        # v okne tagov aj checkbox ghost zon) a KAZDY `push_selected` — tag
        # sa da skryt aj natívnym oknom Tags a vratit cez Späť/Znova, o com
        # by sa panel inak nedozvedel (Codex audit BLOCKER 1).
        # `dialog_alive?` sa tu NEKONTROLUJE zamerne (rovnaky dovod ako pri
        # `push_part_card`): stav tagov je citanie siedmich vrstiev, teda
        # lacnejsie nez guard sam, samotne odoslanie uz strazi `js` — a guard
        # navyse robil metodu nepozorovatelnou pre in-SketchUp testy.
        def push_tags(state = nil)
          st = state || tags_state
          js("if (window.NX && NX.setTags) NX.setTags(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_tags')
        end

        # K2/D-87: stav kontroly smeru kresby pre rail. Nedostupny/nenacitany
        # GrainCheck (SketchUp bez Overlay API) = ikona zosedne, panel sa tym
        # nezhodi. Cisla sklada VYHRADNE server (`GrainCheck.ui_state`).
        def grain_check_state
          return { 'available' => false, 'active' => false } unless defined?(GrainCheck)

          GrainCheck.ui_state(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.grain_check_state')
          { 'available' => false, 'active' => false }
        end

        # Protajsok StudioDialog#push_grain_check. Vola ho
        # Engine.broadcast_grain_check (klik z raily aj zo Studia) a
        # GrainCheck po prepocte cache (prestavba pri zapnutej kresbe).
        def push_grain_check(state = nil)
          return unless dialog_alive?

          st = state || grain_check_state
          js("if (window.NX && NX.setGrainCheck) NX.setGrainCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_grain_check')
        end

        # KOV-A2b: stav symbolov smeru otvarania pre rail. Nedostupny/nenacitany
        # DirectionCheck (SketchUp bez Overlay API) = ikona zosedne, panel sa tym
        # nezhodi. Cisla sklada VYHRADNE server (`DirectionCheck.ui_state`).
        def direction_check_state
          return { 'available' => false, 'active' => false } unless defined?(DirectionCheck)

          DirectionCheck.ui_state(Sketchup.active_model)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.direction_check_state')
          { 'available' => false, 'active' => false }
        end

        # Protajsok StudioDialog#push_direction_check. Vola ho
        # Engine.broadcast_direction_check (klik z raily aj zo Studia) a
        # DirectionCheck po prepocte cache (prestavba pri zapnutych symboloch).
        def push_direction_check(state = nil)
          return unless dialog_alive?

          st = state || direction_check_state
          js("if (window.NX && NX.setDirectionCheck) NX.setDirectionCheck(#{st.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_direction_check')
        end

        # KOV-A2b DEEP-LINK: klik na RED nález „smer otvárania" v Kontrole
        # (Studio) uz oznacil dielec v modeli — toto navyse otvori jeho KARTU
        # CELA v Inspectorovi. Server si o tom NIC nepamata: posiela sa jediny
        # udaj (ID cela) a rozhodnutie „prepni kontext, otvor kartu, doscrolluj"
        # robi klient. Zavrety Inspector = neposiela sa nic.
        def push_focus_front(front_id)
          fid = front_id.to_s
          return if fid.empty?
          return unless dialog_alive?

          js("if (window.NX && NX.focusFront) NX.focusFront(#{fid.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_focus_front')
        end

        # dedup: false = refresh po programovom selecte zo Studia (V0.5 B,
        # Codex B2) — vyber NESMIE mutovat model (dedup meni ID a stavia).
        #
        # D-103 (9.8.2026, ziva reprodukcia): sync vyberu uz dedup NEVYKONAVA, len si
        # ho VYZIADA u observera. Doteraz tu bezala vlastna netransparentna operacia
        # PRIAMO v selection evente — teda hned po pouzivatelovej kopirovacej operacii
        # (Move+Ctrl s otvorenym Inspectorom). Stala sa vrcholom undo stacku a ked
        # pouzivatel dopisal `*4`, Move nastroj svoju operaciu PREPISAL (interne undo
        # + nove kopie) — undo vsak trafilo NASU operaciu, povodna kopia prezila a
        # nasobenie polozilo dalsiu na to iste miesto: dve dosky na jednom mieste =
        # dva dielce v kusovniku, VEPO aj rozpocte. Observer to spravi o 0,2 s neskor
        # TRANSPARENTNE (splynie s krokom pouzivatela), co je overene bezpecne.
        # Kartu s novym ID doplni observer sam (refresh_panel po dedupe).
        def push_selected(model, dedup: true)
          ScaleWatch.request_dedup(model) if dedup && defined?(ScaleWatch)
          # D-27 (Codex audit BLOCKER 1): viditelnost tagov chodi s KAZDYM
          # pushom vyberu — tou istou cestou bezi Späť/Znova (D-101),
          # prepnutie dokumentu aj obycajna zmena vyberu. Bez toho by po
          # vratení skrytia ostala ikona raily, okno tagov aj checkbox zon
          # na opacnom stave, nez je v modeli.
          push_tags(tags_state(model))
          # ŠT-3c-1: vetva „dialog Sablony sleduje vyber" ZANIKLA spolu s oknom.
          # Sekcia `tpl` Studia vyber NESLEDUJE (audit N27): tlacidla su vzdy
          # aktivne a verdikt („nic nie je oznacene", „iny typ") dava SERVER
          # pri kliku — vzor `capture_preview_for`, pravidlo D-78.
          zone = find_selected_zone(model)
          cab = find_cabinet(model)
          if cab.nil?
            @active_zone_id = nil
            # V0.4.7c: doska ma vlastnu kartu; korpus ma v Inspectore prednost.
            board = find_board(model)
            if board
              bp = board_payload(board)
              bp['model_guid'] = model_guid(model)
              return js("NX.loadBoard(#{bp.to_json})")
            end
            # Codex #168 P2 (3. kolo): AJ prazdny vyber nesie identitu dokumentu.
            # Prepnutie do dokumentu bez vyberu inak nechalo panel na guide
            # STAREHO modelu a ABS prepinac by kazdy klik odmietal ako nezhodu.
            return js("NX.clearSelected(#{model_guid(model).to_json})")
          end
          az = if zone && zone['cabinet_id'] == Store.get(cab, 'cabinet_id')
                 zone['zone_id']
               elsif belongs?(@active_zone_id, cab)
                 @active_zone_id
               end
          @active_zone_id = az
          payload = cabinet_payload(cab)
          payload['active_zone'] = az
          payload['model_guid'] = model_guid(model)
          # V0.3: ak je vo vybere DIELEC (kind=part), priloz kartu dielca (ABS/materialovy editor).
          part = find_selected_part(model)
          payload['part_card'] = part ? part_card_payload(model, cab, part) : nil
          js("NX.loadSelected(#{payload.to_json})")
        end

        # UI-B1 (Codex #168 P2, 2. kolo): IDENTITA DOKUMENTU. ID objektov su
        # jedinecne LEN v ramci modelu (Ids.next_board_id pocita od zaciatku
        # v kazdom dokumente), takze dva otvorene dokumenty bezne obsahuju
        # BRD-001 aj CAB-001. Bez identity by:
        #   * prepnutie dokumentu vyzeralo pre panel ako ECHO push tej istej
        #     identity (kontext by ostal na starom mieste namiesto resetu),
        #   * oneskoreny callback (krizik dosky, ABS prepinac) trafil CUDZI
        #     dokument. Zrkadlo ProductionCore#model_guid.
        #
        # 1d/R-02b: hodnotou uz NIE JE Model#guid (ten SketchUp meni pri
        # KAZDOM ulozeni — Ctrl+S do 400 ms po uprave pola vyzeral ako
        # prepnutie dokumentu a debounced edit sa zahodil), ale stabilny
        # token DocKey viazany na objekt modelu. Meno metody aj pola
        # `model_guid` na drote ostava — kontrakt R-02 sa nemeni.
        def model_guid(model = nil)
          m = model || Sketchup.active_model
          m ? DocKey.key(m) : ''
        rescue StandardError
          ''
        end

        # R-02: JEDINY GUARD IDENTITY DOKUMENTU pre ZAPISOVE handlery panela
        # (vklad skrinky aj dosky, apply, premenovanie, kovanie, karta dosky).
        # Vrati true = payload patri INEMU dokumentu a volajuci ZAPIS ODMIETNE.
        #
        # PRECO: callback HtmlDialogu je asynchronny a panel je JEDEN pre vsetky
        # otvorene dokumenty. ID objektov su pritom jedinecne LEN v ramci modelu
        # (CAB-001 aj BRD-001 su v kazdom projekte), takze echo `cabinet_id` /
        # `board_id` prepnutie dokumentu NEZACHYTI — oneskoreny klik by prestaval
        # rovnomennu skrinku v cudzej zakazke. Z pluginu sa objednava realna
        # zakazka, takze taky zapis je vyrobne riziko, nie kozmeticky detail.
        #
        # PRISNE porovnanie (vzor `handle_tag_visible`, `handle_edge_option`,
        # `zone_ctx`, `handle_set_part_grain`): prazdny guid NIE JE starsi klient
        # — je to okno bez dobehnuteho NX.init, a to nesmie zapisovat nikam.
        # A rovnako PRAZDNY KLUC SERVERA (DocKey nevedel dokument precitat)
        # zapis zastavi — '' == '' by inak pustilo zapis bez identity na oboch
        # stranach (Codex audit R-02b, BLOCKER 1: fail-closed plati obojsmerne).
        # Samotne porovnanie robi `DocKey.foreign?` — TEN ISTY porovnavac ako
        # vsetky ostatne guardy (review #267 P3-2), aby fail-closed nebolo
        # vysadou tejto jednej cesty.
        # Hlaska je NAHLAS (nie tiche zahodenie ako pri echu vyberu): prepnutie
        # dokumentu je zriedkave a pouzivatel musi vediet, ze sa zmena neulozila.
        # `what` = co sa NEstalo, v 1. pade ('Skrinka sa nevložila').
        def foreign_document?(data, model, what)
          return false if model && !DocKey.foreign?(data['model_guid'], model)

          Engine.log("#{what}: model_guid #{data['model_guid'].inspect} nesedi s aktivnym dokumentom — zapis zahodeny")
          set_status("#{what} — panel patrí inému dokumentu. Klikni do okna zákazky a skús znova.", true)
          true
        end

        # UI-D2: zoznam nesie aj `preview_rev` — dlaydica podla neho vie, ci
        # ma o PNG vobec ziadat (a JS podla neho cachuje). Samotny obrazok ide
        # samostatnym kanalom nizsie.
        def push_templates
          js("NX.setTemplates(#{template_list(previews: true).to_json})")
        end

        # ŠT-3c-2 (review #226 P2): PREMENOVANIE musí prehodiť aj to, čo má
        # vkladacia karta panela ZVOLENÉ. Karta drží šablónu MENOM
        # (`NXInsert.state.template` / `boardTemplate`) — samotný `push_templates`
        # prestavia dlaždice, ale voľbu nechá na starom mene, ktoré už neexistuje:
        # vloženie by potom išlo s neplatnou identitou (bez pečiatky použitia) a po
        # prekreslení karty by ticho spadlo na predvolené rozmery. Volá sa PRED
        # `push_templates`, aby prestavané dlaždice už vyznačili tú správnu.
        def push_template_renamed(kind, old_name, new_name)
          js("NX.renameTemplate(#{kind.to_s.to_json}, #{old_name.to_s.to_json}, "              "#{new_name.to_s.to_json})")
        end

        # UI-D2: PULL kanal nahladu. Panel si vypyta PNG pre (kind, name, rev)
        # RAZ — data URI je radovo vacsie nez zvysok zoznamu a poslat ho pri
        # kazdom `push_templates` by z kazdeho refreshu spravilo stovky kB.
        # Vzor `nx_used_ids` (D-85): ciste citanie na VYZIADANIE, ziadny render
        # karty, ziadny dotyk modelu. `rev` sa vracia SPAT nezmenene, aby si
        # JS odpoved priradil k spravnej verzii (medzitym mohol prist novy
        # nahlad); `png: nil` = bez nahladu — dlazdica ostane na scheme a JS
        # si to zacachuje, takze sa nepyta dokola.
        def push_template_preview(payload)
          return unless dialog_alive?

          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s
          name = data['name'].to_s
          return if name.empty?

          out = { 'kind' => kind, 'name' => name, 'rev' => data['rev'].to_s,
                  'png' => TemplatePreviews.data_uri(kind, name) }
          js("NX.setTemplatePreview(#{out.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_template_preview')
        end

        # D-05: zivy refresh katalogu materialov v paneli po CRUD v satelitnom okne
        # (BEZ push_init — nesmie resetovat rozpisany formular).
        def push_materials
          js("NX.setMaterials(#{materials_payload.to_json})")
          push_part_card
        end

        # ŠT-2a (review #3): KATALOGOVY ZAPIS Z INSPECTORA (dovytvorena ABS
        # paska D-41, automaticky duplak D-49) ma JEDINU fan-out cestu —
        # `MaterialsDialog.after_catalog_change`. Doteraz si tieto miesta
        # posielali refresh samy (`push_materials` + `MaterialsDialog.push_state`)
        # a odvtedy, co katalog ma DVE UI, to bola diera: sekcia Materialy
        # v Studiu o novej paske nevedela a hlavne jej ostal STARY `catalog_rev`
        # — najblizsi zapis z nej by server odmietol hlaskou „Katalóg sa
        # medzitým zmenil". Fan-out okrem toho zneplatnuje cache kontroly hran
        # a obnovuje cisla Studia; kopirovat to na kazde volacie miesto by
        # znamenalo, ze na jednom z nich to casom bude chybat.
        #
        # Fallback je poctivy: bez nacitaneho satelitu (headless, ciastocny
        # load) sa aspon obnovi panel — mlcanie by bolo horsie.
        def broadcast_catalog_change
          return MaterialsDialog.after_catalog_change if defined?(MaterialsDialog)

          push_materials
        end

        # K1 (Codex #185 kolo 2, P2): CERSTVY payload karty dielca po zmene
        # KATALOGU. `NX.setMaterials` kartu prekresluje z CACHOVANEHO payloadu,
        # takze vsetko, co sklada SERVER, by ostalo stare az do dalsieho prekliku
        # vyberu — segment „Smer dekoru" by ostal ZAMKNUTY na materiali, ktoremu
        # prave pribudol smer (alebo naopak ponukal otacanie tam, kde uz nie je
        # co otacat), a rovnako by zamrzli texty hran D-102.
        #
        # Je to CISTE CITANIE (vzor `push_used_ids`): ziadna operacia, ziadny
        # dedup, ziadny zapis do modelu (lekcia D-103). Ked vo vybere dielec nie
        # je, NEPOSIELA sa nic — `renderPartCard(null)` by kartu schoval a
        # zmena katalogu nesmie prepnut rezim panela.
        # `dialog_alive?` sa tu NEKONTROLUJE zamerne (na rozdiel od
        # `push_used_ids`, ktory nim obchadza drahy scan modelu): payload jednej
        # karty je citanie configu jedneho dielca — lacnejsie nez katalog, ktory
        # `push_materials` postavil o riadok vyssie — a samotne odoslanie uz
        # strazi `js`. Guard navyse robil metodu nepozorovatelnou pre testy.
        def push_part_card
          model = Sketchup.active_model
          return if model.nil?

          cab = find_cabinet(model)
          part = cab ? find_selected_part(model) : nil
          return if part.nil?

          payload = part_card_payload(model, cab, part)
          return if payload.nil?

          # Identitu dokumentu nesie obalka push_selected; tento push je
          # samostatny, takze si ju musi doniest sam (JS ju cita pri zapise).
          payload['model_guid'] = model_guid(model)
          js("NX.setPartCard(#{payload.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_part_card')
        end

        # D-85 (Codex #167 P2): SAMOTNY odvodeny zoznam „Použité v projekte" pre
        # otvoreny combobox — bez katalogu, bez prekreslenia karty (rozpisany
        # formular sa nesmie dotknut, vzor push_materials/setHardwareSets).
        # Vola sa na VYZIADANIE z panela (callback nx_used_ids pri otvoreni
        # ponuky), nie z push_selected: scan modelu je prilis draha vec na to,
        # aby bezala pri kazdom kliku vo vybere. Cita sa iba (Materials.used_*)
        # — ziadna operacia, ziadny zapis, ziadny undo krok (lekcia D-103).
        def push_used_ids
          return unless dialog_alive?

          js("NX.setUsedIds(#{used_ids_payload.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_used_ids')
        end

        # D-75 (H1b): zivy refresh PONUKY setov kovania po zmene v okne Katalog
        # kovania. Obnovi LEN moznosti selectov (NX.setHardwareSets) — ziadny
        # push_selected: ten resetuje rozpracovany formular a navyse dedup-uje
        # kopie, cize by zmena v satelitnom okne siahla na MODEL.
        # Cita sa iba (find_cabinet + config) — bez operacie, bez zapisu.
        #
        # D-92 (audit BLOCKER 2): payload nesie AJ nakupny rozpis poloziek
        # (set -> kody -> nazvy). Bez neho by sekcia Kovanie po zmene setu,
        # kodu ci nazvu polozky ukazovala stary nakup az do prekliku vyberu.
        # Riadky sa NEPREKRESLUJU — JS meni len sekundarne riadky (rozpisany
        # pocet aj vyber setu ostavaju). 'items' nesie identitu polozky
        # (owner_part_key + generic_type + rule_id), aby ich JS spároval.
        def push_hardware_sets
          return unless dialog_alive?

          model = Sketchup.active_model
          cab = model ? find_cabinet(model) : nil
          data =
            if cab.nil?
              { 'cabinet_id' => nil, 'options' => [], 'items' => [] }
            else
              cfg = Store.config(cab) || {}
              items = hardware_items_payload(cfg)
              { 'cabinet_id' => Store.get(cab, 'cabinet_id'),
                'options' => hardware_set_options(cfg, items),
                'items' => items.map { |h| hardware_purchase_row(h) }.compact }
            end
          js("NX.setHardwareSets(#{data.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_hardware_sets')
        end

        # D-92: minimalny tvar pre zivy refresh — identita riadku + to, co sa
        # v nom meni. Nic viac (payload chodi po kazdej zmene katalogu).
        def hardware_purchase_row(item)
          return nil unless item.is_a?(Hash)

          { 'owner_part_key' => item['owner_part_key'], 'generic_type' => item['generic_type'],
            'rule_id' => item['rule_id'], 'owner_label' => item['owner_label'],
            'purchase' => item['purchase'] }
        end

        # GHOST-FB4: Ghost pasik vkladacej karty — stav BEZIACEJ session
        # (kotva, rotacia, rezim vysky, locknuta vyska). Pasik NIE JE trvalou
        # sucastou panela (vertikalny priestor je vzacny): `active = false`
        # ho schova a presne to chodi pri kazdom konci session. Panel si z neho
        # nic neodvodzuje — kazdy push stav CELY prepise.
        def push_ghost(state)
          js("NX.setGhost(#{(state || { 'active' => false }).to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_ghost')
        end

        def set_status(msg, error = false)
          js("NX.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        # Status doplneny o pocet BuildPlan upozorneni z posledneho planu korpusu.
        # Nefatalne stavy (orezane vystuhy, preskocene police...) tak uz nie su neviditelne.
        def status_with_warnings(cab, msg)
          warns = cab && cab.valid? ? ((Store.config(cab) || {})['warnings'] || []) : []
          msg = "#{msg} · #{warns.size} #{warn_word(warns.size)}" unless warns.empty?
          set_status(msg)
        end

        def warn_word(n)
          return 'upozornenie' if n == 1
          n < 5 ? 'upozornenia' : 'upozorneni'
        end

        def js(script)
          return unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.js')
        end

        # V0.5 B: relay handshake satelitnych okien potrebuje vediet, ci panel zije.
        def dialog_alive?
          !!(@dialog && @dialog.visible?)
        end

      end
    end
  end
end
