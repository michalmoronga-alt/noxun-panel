# frozen_string_literal: true
# Noxun Engine — SERVEROVA AUTORITA KATALOGU MATERIALOV.
#
# ŠT-2b: satelitne okno „Materiály projektu" ZANIKLO (HtmlDialog, `DLG_KEY`,
# `proj_materials.html`, menu polozka aj panelove tlacidlo). Jedine UI katalogu
# je odteraz SEKCIA `mat` v okne ŠTÚDIO. Modul sa pritom ZAMERNE NEPREMENUVA
# (audit #21): zaniklo OKNO, nie serverova autorita — telo kazdej katalogovej
# akcie, vsetky guardy (schema, `catalog_rev`, `row_rev`), Demos konektor aj
# „Nahradiť UNI…" ziju dalej TU. Zmenil sa jediny detail: ADRESAT odpovede.
#
#   * pocas synchronneho volania sekcie ho drzi `with_client(sink)`,
#   * mimo neho (asynchronne Demos emity, refresh cesty zvonku) ide vsetko do
#     Studia cez `StudioDialog.mat_js` — druhe okno uz neexistuje.
#
# Projektove predvolby su per MODEL (NOXUN dict, `Materials.project_defaults`);
# katalog je GLOBALNY (%APPDATA%). Logika projektoveho defaultu sa V0.4.5 D2
# presunula sem z Panel (`handle_set_project_material`) — panel ju uz nevola.
require 'json'

module Noxun
  module Engine
    module MaterialsDialog
      # key -> [config kluc korpusu, rola pre hrubkovu kontrolu, pole hrubky]
      # (presunute z Panel::PROJECT_MATERIAL_TARGETS — jediny pouzivatel je tento dialog)
      TARGETS = {
        'default_material_id'       => ['material_id', 'side_left', 'thickness'],
        'default_front_material_id' => ['front_material_id', 'front_door', nil],
        'default_back_material_id'  => ['back_material_id', 'back', 'back_thickness']
      }.freeze

      # --- sekcia MATERIALY v Studiu (ŠT-2a kanal, ŠT-2b uplny presun) -------
      #
      # Zoznam je UZAVRETY whitelist: klient (Studio) posiela iba MENO akcie,
      # co sa smie zavolat rozhoduje SERVER (HTML ani JS nie su ochrana).
      #
      # ŠT-2b: pribudli VSETKY toky, ktore v ŠT-2a este drzali dlhy beh viazany
      # na instanciu satelitneho okna — Demos lookup/apply, „Pridať z Demosu"
      # (rodina + naseptavac) a dvojica `replace_uni_preview`/`replace_uni_apply`.
      # Ich zivotnost sa presunula na SEKCIU (`demos_alive_proc` +
      # `cancel_demos_on_leave`), takze premostenie do okna zaniklo spolu s nim.
      SECTION_ACTIONS = %w[
        set_project_material
        update_sheet delete_sheet create_duplak
        update_edge delete_edge
        add_decor_batch rename_decor set_decor_name set_decor_manufacturer set_decor_color
        save_decor
        patch_sheet patch_edge
        delete_preflight restore_pre_schema2
        open_demos_url open_search_url
        demos_lookup demos_manual_url demos_apply demos_cancel
        demos_name_search demos_family demos_family_create demos_family_cancel
        replace_uni_preview replace_uni_apply
      ].freeze

      class << self
        # Vykona akciu katalogu v mene SEKCIE `mat`. `sink` je proc, ktory
        # dostane hotovy JS retazec a posle ho tomu, KTO sa pytal. Volanie je
        # synchronne, takze sink zije presne jeden callback — asynchronne
        # pokracovanie (Demos fetch) uz ide default cestou do Studia.
        def dispatch(name, payload, sink)
          key = name.to_s
          unless SECTION_ACTIONS.include?(key)
            return sink.call("MD.setStatus(#{'Neznáma akcia katalógu.'.to_json}, true)")
          end

          with_client(sink) { run_section_action(key, payload) }
        end

        def run_section_action(key, payload)
          case key
          when 'set_project_material'    then handle_set_project_material(payload)
          when 'update_sheet'            then handle_save_sheet(payload)
          when 'delete_sheet'            then handle_delete_sheet(payload)
          when 'create_duplak'           then handle_create_duplak(payload)
          when 'update_edge'             then handle_save_edge(payload)
          when 'delete_edge'             then handle_delete_edge(payload)
          when 'add_decor_batch'         then handle_add_decor_batch(payload)
          when 'rename_decor'            then handle_rename_decor(payload)
          when 'set_decor_name'          then handle_set_decor_name(payload)
          when 'set_decor_manufacturer'  then handle_set_decor_manufacturer(payload)
          when 'set_decor_color'         then handle_set_decor_color(payload)
          when 'save_decor'              then handle_save_decor(payload)
          when 'patch_sheet'             then handle_patch(payload, 'sheet')
          when 'patch_edge'              then handle_patch(payload, 'edge')
          when 'delete_preflight'        then handle_delete_preflight(payload)
          when 'restore_pre_schema2'     then handle_restore_backup(payload)
          when 'open_demos_url'          then handle_open_demos_url(payload)
          when 'open_search_url'         then handle_open_search_url(payload)
          # ŠT-2b: Demos toky. Su ASYNCHRONNE — dispatch len STARTUJE beh
          # a hned sa vracia; emity dobiehaju z `UI.start_timer` uz BEZ sinku,
          # takze `js` ich posle do Studia (jedine zive UI katalogu).
          when 'demos_lookup'            then handle_demos_lookup(payload)
          when 'demos_manual_url'        then handle_demos_manual(payload)
          when 'demos_apply'             then handle_demos_apply(payload)
          when 'demos_cancel'            then handle_demos_cancel
          when 'demos_name_search'       then handle_demos_name_search(payload)
          when 'demos_family'            then handle_demos_family(payload)
          when 'demos_family_create'     then handle_demos_family_create(payload)
          when 'demos_family_cancel'     then handle_demos_family_cancel
          when 'replace_uni_preview'     then handle_replace_uni_preview(payload)
          when 'replace_uni_apply'       then handle_replace_uni_apply(payload)
          end
        end

        # Presmerovanie odpovedi na cas jedneho volania. `ensure` je povinne:
        # vynimka v handleri nesmie nechat sink viset, inak by ho zdedila
        # NASLEDUJUCA (aj asynchronna) odpoved a poslala ju do mrtveho kanala.
        def with_client(sink)
          prev = @client_sink
          @client_sink = sink
          yield
        ensure
          @client_sink = prev
        end
        # --- ŠT-2b: ZIVOTNY CYKLUS (okno zaniklo, ostava sekcia) -------------
        #
        # Modul uz nevlastni ziadny HtmlDialog. To, co predtym riesil
        # `set_on_closed` satelitu, teraz hlasi Studio:
        #   * `on_ui_closed`   — zatvorene okno Studio (ABA guard: nova
        #     instancia okna NESMIE dostat eventy behu, ktory patril starej),
        #   * `cancel_demos_on_leave` — odchod zo SEKCIE `mat` pocas dlheho
        #     behu (vedome rozhodnutie ŠT-2b, viz `demos_alive_proc`).

        # Zatvorene Studio = ziadne UI katalogu. Bezaci Demos fetch sa zneplatni
        # (session bump) a odlozena poziadavka „Nahradiť UNI…" zomiera s nim.
        def on_ui_closed
          demos_bump_session
          demos_forget_runs
          @pending_replace_uni = nil
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.on_ui_closed')
        end

        # VEDOME ROZHODNUTIE ŠT-2b (audit #5): dlhy beh Demosu je viazany na
        # SEKCIU, nie len na okno. Odchod do Kusovnika pocas stahovania beh
        # ZRUSI — a povie to nahlas. Alternativa (nechat bezat na pozadi) by
        # znamenala, ze sa modal po navrate otvori sam nad inou sekciou alebo
        # ze zapis dobehne bez toho, aby ho niekto videl; potvrdzovaci dialog
        # pri kazdom prepnuti sekcie by zas otravoval. Zrusenie je jednoduche
        # a PREDVIDATELNE.
        #
        # Hlasku posiela LEN vtedy, ked naozaj nieco bezalo — inak by kazde
        # prepnutie sekcie prepisalo stav okna zbytocnou vetou.
        def cancel_demos_on_leave
          return unless @demos_running

          demos_bump_session
          demos_forget_runs
          set_status('Sťahovanie z Demosu zrušené — opustil si sekciu Materiály.')
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.cancel_demos_on_leave')
        end

        # Serverovy stav dlhych behov (proposal store, rodina, baseline row_rev).
        # Session token uz bumpol volajuci — toto je upratanie po nom.
        def demos_forget_runs
          @demos_running = false
          @demos_family = nil
          @demos_proposals = {}
          @demos_base_revs = {}
        end

        # --- Ruby -> JS -----------------------------------------------------
        #
        # ŠT-2b: `push_state` (PLNY stav s `MD.init`) a `state_payload` ZANIKLI
        # spolu s oknom. Modelovy kontext sekcie — projektove predvolby, pocet
        # skriniek, identita dokumentu a pas „Použité v projekte" — nesie UZ
        # payload Studia (`StudioDialog#mat_payload`), a ten ho rata z UZ
        # zozbieraneho kusovnika. S oknom preto zmizol aj DRUHY sken modelu
        # (`Materials.model_decor_usage`), ktory tento subor robil pri kazdom
        # plnom pushi (review ŠT-2a #4). Ostava JEDNA cesta: katalogove echo.

        # LEN katalogova cast (po zapise do katalogu) — ziadny scan modelu,
        # modelovy kontext (predvolby/pouzite) v JS ostava (audit FIX 13).
        def push_catalog
          js("MD.setCatalog(#{catalog_payload.to_json})")
        end

        def catalog_payload
          {
            materials: Panel.materials_payload,               # katalog dosiek pre selecty
            catalog: full_catalog_payload,                    # D-05: plne zaznamy pre spravu
            protected_ids: Materials::PROTECTED_SHEET_IDS,
            catalog_rev: Materials.catalog_revision,          # D-41: baseline guard formularov
            # 2A-1 (audit F10): SCHEMA katalogu. Klient ju vracia v KAZDEJ mutacii
            # — po migracii na SCHEMA 2 server odmietne zapis zo stareho okna.
            catalog_schema: Materials.catalog_schema,
            # 2A-4b (audit B4/O1): nudzovy rezim katalogu — okno ukaze vyrazny
            # read-only banner s dovodom + tlacidlo obnovy predmigracnej zalohy.
            catalog_state: Materials.catalog_state.to_s,
            catalog_state_reason: Materials.catalog_state_reason.to_s,
            # 2A-4b (audit O2): pocet ABS pasok bez struktury a bez universal —
            # picker ich nevyberie. Pocita VYHRADNE server; banner sa ukazuje
            # pri KAZDOM otvoreni/refreshi, kym pocet nie je 0.
            unusable_edges: Materials.unusable_edges_count,
            # GH #93 P2 (4. kolo): dovod nevykonaneho cutoveru (poskodena
            # predmigracna zaloha / nerozhodnutelne polozky) — VIDITELNY banner,
            # nie len log; katalog pritom bezi dalej (nie read-only).
            cutover_issue: Materials.respond_to?(:cutover_issue) ? Materials.cutover_issue.to_s : '',
            # GH #93 P2 (10. kolo): rollback tlacidlo aj pri zdravom katalogu —
            # ukazuje sa len ked predmigracna zaloha realne existuje.
            pre_schema2_backup: File.exist?(Materials.pre_schema2_backup_path),
            # D-44: naseptavace (vyrobca/typ) a navrhy formatu platne stavia
            # SERVER — JS ich len renderuje. Ide s KAZDYM katalogovym echom,
            # takze novy vyrobca/typ je v navrhoch hned po zapise.
            suggest: { manufacturers: Materials.manufacturer_suggestions,
                       types: Materials.type_suggestions },
            # D-97 (audit F4): KANONICKE typy z registra ako SAMOSTATNE pole.
            # `suggest.types` mieša aj volne typy z katalogu — po ulozeni
            # preklepu „KD" by uz nikdy nebol „neznamy" a upozornenie by zmizlo.
            # Typ ostava volny string (D-67/D-68); toto je LEN podklad hlasky.
            known_types: Materials::SEED_TYPES,
            format_hints: Materials::TYPE_FORMAT_HINTS
          }
        end

        # D-42 (audit BLOCKER 4): stabilna identita modelu (guid). Projektove
        # predvolby su per-MODEL; oneskoreny callback po prepnuti dokumentu nesmie
        # ulozit predvolbu vybranu v modeli A do prave aktivneho modelu B.
        def model_guid(model)
          model && model.respond_to?(:guid) ? model.guid.to_s : ''
        rescue StandardError
          ''
        end

        # D-41 (audit FIX 15): zapis nad starsim stavom katalogu sa odmietne —
        # klient posiela catalog_rev z posledneho init; nesulad = medzitym pisal
        # niekto iny (batch, druhe okno). Prazdny rev = stary klient (CEF cache),
        # guard sa preskoci (spatna kompatibilita, single-writer limit trva).
        def revision_ok?(data)
          rev = data['catalog_rev'].to_s
          return true if rev.empty? || rev == Materials.catalog_revision
          set_status('Katalóg sa medzitým zmenil — zoznamy sa obnovili, over a ulož znova.', true)
          push_catalog
          false
        end

        # 2A-1 (audit F10): guard mutacii proti STAREMU oknu. Po migracii katalogu
        # na SCHEMA 2 (dekorove skupiny, struktura) nesmie zapisovat klient, ktory
        # o novych poliach nevie — jeho payload by identitu variantu zahodil.
        # V SCHEMA 1 sa nedeje NIC (spatna kompatibilita: prazdna hodnota prejde).
        # Rozhodnutie je na serveri (Materials.schema_write_allowed?) — tu ostava
        # len hlaska a refresh sekcie.
        def schema_ok?(data)
          return true if Materials.schema_write_allowed?(data['catalog_schema'])
          # ŠT-2b: text uz nesmie posielat do okna, ktore neexistuje — obnovu
          # katalogu robi „Obnoviť" v liste sekcie (alebo tento push).
          set_status('Katalóg je v novom formáte — obnov Štúdio (Obnoviť) a potom ulož.', true)
          push_catalog
          false
        end

        # Spolocny vstupny guard katalogovych mutacii (schema pred baseline).
        def catalog_write_ok?(data)
          schema_ok?(data) && revision_ok?(data)
        end

        # Plne zaznamy katalogu (sprava potrebuje vsetky polia — panelovy
        # materials_payload je zamerne zuzeny). label = ten isty odvodeny text.
        # D-42 PR C: row_rev = odtlacok SUROVEHO zaznamu (bez labelu) — baseline
        # inline patchu per riadok. Pocita sa PRED merge labelu (server porovnava
        # proti zaznamu v katalogu, nie proti payloadovej ozdobe).
        def full_catalog_payload
          cat = Materials.load
          ctx = Panel.label_ctx # 2A-4b: kolizie cisla dekoru raz pre cely payload
          {
            'sheets' => cat['sheets'].map { |s|
              extra = { 'label' => Panel.sheet_label(s, ctx), 'row_rev' => Materials.record_rev(s) }
              # V0.6 M-A2 (audit BLOCKER 1): dlazdica dostava VYHRADNE lokalny
              # subor z DemosImageCache — remote URL do CEF nikdy nejde (throttle
              # /allowlist by obisiel). Bez suboru = fallback farba.
              if !s['image_url'].to_s.empty? && (local = DemosImageCache.local_for(s['image_url']))
                extra['image_file'] = local
              end
              s.merge(extra)
            },
            'edges' => cat['edges'].map { |a|
              a.merge('label' => Panel.abs_label(a, ctx), 'row_rev' => Materials.record_rev(a))
            }
          }
        end

        # D-42 PR C (audit BLOCKER 1): inline patch bunky. Konflikt riadku =
        # cerstve data + hlaska (rozpisana bunka sa NEuklada nad cudziu zmenu);
        # duplicitny kod = flag do JS, dalsi flush tej istej bunky posle
        # potvrdenie (zrkadlo formularoveho allow_duplicate_code).
        def handle_patch(payload, kind)
          data = JSON.parse(payload.to_s)
          # 2A-1: baseline riadku (row_rev) strazi cudziu zmenu ZAZNAMU, nie
          # prepnutie schemy katalogu — schema guard preto plati aj pre bunky.
          return unless schema_ok?(data)
          patch = data['patch'].is_a?(Hash) ? data['patch'] : {}
          status, extra = Materials.patch_record(
            kind, data['id'].to_s, patch,
            row_rev: data['row_rev'], allow_duplicate_code: !!data['allow_duplicate_code']
          )
          case status
          when :ok
            after_catalog_change
            set_status('Uložené.')
          when :conflict
            set_status('Riadok medzitým zmenil niekto iný — hodnoty sa obnovili, uprav znova.', true)
            push_catalog
          when :code_conflict
            set_status("Kód už používa #{extra.size}× (#{extra.first(3).join(', ')}…). Ulož znova pre potvrdenie duplicity.", true)
            js("MD.flagDuplicatePatch(#{kind.to_json}, #{data['id'].to_json})")
          when :not_found
            set_status('Záznam sa nenašiel — katalóg sa obnovil.', true)
            push_catalog
          when :invalid
            set_status(extra || 'Neplatná hodnota.', true)
            push_catalog
          when :catalog_read_only
            # 2A-4b (audit F7 UI): aj nudzovy rezim vrati UI podla SERVERA —
            # universal toggle/bunka sa nesmie tvarit, ze zapis presiel.
            set_status(Materials.catalog_read_only_message, true)
            push_catalog
          else
            # :write_failed — checkbox/bunka sa VRATI podla servera (F7).
            set_status('Uloženie zlyhalo.', true)
            push_catalog
          end
        end

        # --- 2A-4b (audit B2/B4): obnova predmigracnej zalohy -----------------
        # Tlacidlo v read-only banneri (potvrdenie robi modal v okne — NIE
        # UI.messagebox). Uspech = katalog je spat legacy + hold flag zabezpeci,
        # ze najblizsi start SketchUpu migraciu RAZ preskoci.
        def handle_restore_backup(_payload)
          ok, result = Materials.restore_pre_schema2!
          return set_status(result, true) unless ok
          # GH #93 P2 (4. kolo): rollback meni CELY katalog — refresh musia
          # dostat aj panel a otvorene okno Studio (rovnako ako bezna mutacia),
          # inak by drzali predrollbackovy SCHEMA 2 obsah.
          after_catalog_change
          set_status('Katalóg obnovený z predmigračnej zálohy. Pri najbližšom štarte SketchUpu sa migrácia jednorazovo preskočí.')
        end

        def set_status(msg, error = false)
          js("MD.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        # ŠT-2b: odpoved ide TOMU, KTO sa pytal. Sink zije PRESNE jeden
        # synchronny callback sekcie (`with_client`); mimo neho — refresh cesty
        # zvonku aj ASYNCHRONNE Demos emity, ktore dobiehaju z casovaca uz po
        # navrate z `dispatch` — je adresat JEDINY mozny: okno Studio.
        def js(script)
          sink = @client_sink
          return sink.call(script) if sink

          studio_js(script)
        end

        # Jedine zive UI katalogu. Studio nacitava loader (`main.rb`) EST PRED
        # tymto suborom; `defined?` je poistka pre headless testy, ktore si
        # tento subor requiruju samostatne.
        def studio_js(script)
          return false unless defined?(StudioDialog)

          StudioDialog.mat_js(script)
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.studio_js')
          false
        end

        # Volane z EngineAppObserver (`scale_observer`). Od ŠT-2b tento modul uz
        # ziadne UI nevlastni — refresh sekcie robi Studio samo
        # (`StudioDialog.on_model_changed`). Ostava tu VYHRADNE zivotny cyklus
        # serverovych behov: cudzi dokument nesmie dostat vysledky behu, ktory
        # patril predoslemu.
        def on_model_changed(_model)
          demos_bump_session # B-2b: prepnuty model rusi bezaci Demos lookup
          demos_forget_runs
          @pending_replace_uni = nil # D-83: poziadavka patrila PREDOSLEMU modelu
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.on_model_changed')
        end

        # --- V0.6 B-2b: Demos lookup / apply (audit BLOCKER 5/6, FIX 13/14) ---
        # Session token je MONOTONNE Ruby cislo — jedina autorita zivotnosti
        # lookupu. Bump: novy lookup, cancel, ZATVORENIE STUDIA (`on_ui_closed`),
        # ODCHOD ZO SEKCIE `mat` (`cancel_demos_on_leave`), prepnuty model.
        # JS generation sa NEpouziva (close/reopen ABA). Proposal store zije
        # TU (server) — apply berie hodnoty z neho, JS posiela len flagy.

        def demos_bump_session
          @demos_session = @demos_session.to_i + 1
        end

        # Zaznamy skupiny podla kluca dlazdice ('g:<group_id>' | 'd:<decor>' —
        # zrkadlo mdGroupKeyOf v JS; server filtruje SVOJ katalog, klientskym
        # zoznamom ID sa neveri).
        def demos_group_records(group_key)
          key = group_key.to_s
          cat = Materials.load
          sel =
            if key.start_with?('g:')
              gid = key[2..]
              ->(r) { r['group_id'].to_s == gid }
            elsif key.start_with?('d:')
              dec = key[2..]
              ->(r) { r['decor'].to_s.strip == dec }
            end
          return [] unless sel
          cat['sheets'].select(&sel) + cat['edges'].select(&sel)
        end

        # ŠT-2b (audit #5): zivotnost dlheho behu. Do ŠT-2a visela na INSTANCII
        # satelitneho okna; teraz na SESSION TOKENE — a ten zhasina KAZDA
        # udalost, po ktorej uz vysledok nema komu prist:
        #   * zatvorenie Studia (`on_ui_closed` — ABA: nova instancia okna nesmie
        #     dostat eventy behu, ktory patril starej),
        #   * ODCHOD ZO SEKCIE `mat` (`cancel_demos_on_leave` — vedome
        #     rozhodnutie: beh sa zrusi a povie sa to, viz tam),
        #   * prepnutie dokumentu, cancel, novy beh.
        # Druha podmienka je „je vobec kam kreslit" — mrtve Studio znamena
        # ziadny dalsi fetch (throttle 3 s / zaznam je drahy).
        def demos_alive_proc(session)
          lambda do
            @demos_session.to_i == session &&
              defined?(StudioDialog) && StudioDialog.dialog_alive?
          end
        end

        # Emit: proposal matche sa odkladaju do @demos_proposals (apply z nich
        # cita hodnoty); kazdy event ide do MDD.event so session echom.
        def demos_emit_proc(session)
          lambda do |event|
            if event['type'] == 'proposal'
              p = event['proposal']
              if p.is_a?(Hash) && p['status'] == 'match'
                (@demos_proposals ||= {})[[p['kind'].to_s, p['record_id'].to_s]] = p
              end
            end
            # Terminalny event = beh dobehol; `cancel_demos_on_leave` uz nema
            # co rusit (a nema o com hlasit).
            @demos_running = false if %w[complete error].include?(event['type'].to_s)
            js("MDD.event(#{event.merge('session' => session).to_json})")
          end
        end

        def handle_demos_lookup(payload)
          data = JSON.parse(payload.to_s)
          return unless schema_ok?(data) # okno musi poznat format katalogu (GH #97 P1)
          recs = demos_group_records(data['group_key'])
          return set_status('Skupina sa nenašla — katalóg sa obnovil.', true) if recs.empty?
          demos_bump_session
          @demos_proposals = {}
          # GH #98 P2: baseline riadkov z CASU LOOKUPU — apply pouzije TIETO
          # row_rev (nie cerstve z klienta): proposal overeny proti staremu
          # zaznamu nesmie po push_catalog refreshi potichu prepisat cudziu
          # zmenu; kolizia skonci :conflict a treba novy lookup.
          @demos_base_revs = {}
          recs.each do |r|
            kind = r['abs_id'].to_s.empty? ? 'sheet' : 'edge'
            id = kind == 'edge' ? r['abs_id'].to_s : r['material_id'].to_s
            @demos_base_revs[[kind, id]] = Materials.record_rev(r)
          end
          session = @demos_session
          @demos_running = true # ŠT-2b: odchod zo sekcie takyto beh ZRUSI
          DemosLookup.run(recs, alive: demos_alive_proc(session),
                                emit: demos_emit_proc(session))
        end

        # FIX 13: manualna URL je priama cesta (bez sitemap). NEbumpuje session
        # — doplna proposal do BEZIACEHO kontextu modalu (miss/ambiguous riadok).
        # GH #98 P2: complete MANUALU sa preklada na 'manual_done' — terminalny
        # stav modalu patri VYHRADNE skupinovemu behu (manual popri bezacej
        # retazi nesmie zapnut Apply a tvarit sa, ze skupina je hotova).
        def handle_demos_manual(payload)
          data = JSON.parse(payload.to_s)
          return unless schema_ok?(data)
          kind = data['kind'].to_s == 'edge' ? 'edge' : 'sheet'
          rec = demos_find_record(kind, data['record_id'].to_s)
          return set_status('Záznam sa nenašiel — katalóg sa obnovil.', true) unless rec
          session = @demos_session.to_i
          id = kind == 'edge' ? rec['abs_id'].to_s : rec['material_id'].to_s
          (@demos_base_revs ||= {})[[kind, id]] = Materials.record_rev(rec)
          manufacturer = demos_group_manufacturer(rec)
          @demos_running = true
          group_emit = demos_emit_proc(session)
          manual_emit = lambda do |event|
            event = event.merge('type' => 'manual_done') if event['type'] == 'complete'
            group_emit.call(event)
          end
          DemosLookup.manual(rec, data['url'].to_s,
                             alive: demos_alive_proc(session),
                             emit: manual_emit,
                             manufacturer: manufacturer)
        end

        def demos_find_record(kind, id)
          cat = Materials.load
          if kind == 'edge'
            cat['edges'].find { |e| e['abs_id'] == id }
          else
            cat['sheets'].find { |s| s['material_id'] == id }
          end
        end

        # Vyrobca SKUPINY zaznamu (GH #97 P1) — ABS paska ho nenesie, odvodi sa
        # zo sheet clenov jej skupiny (group_id, fallback decor).
        def demos_group_manufacturer(rec)
          man = rec['manufacturer'].to_s.strip
          return man unless man.empty?
          cat = Materials.load
          gid = rec['group_id'].to_s
          dec = rec['decor'].to_s.strip
          member = cat['sheets'].find do |s|
            if !gid.empty?
              s['group_id'].to_s == gid && !s['manufacturer'].to_s.strip.empty?
            else
              s['decor'].to_s.strip == dec && !s['manufacturer'].to_s.strip.empty?
            end
          end
          member ? member['manufacturer'].to_s.strip : nil
        end

        # GH #98 P2: chybova hlaska ide AJ do modalu ('msg' -> #mddStatus) —
        # #status stranky je pod fixed scrimom modalu a pouzivatel by dovod
        # neuspesneho zapisu nevidel; set_status ostava pre stav po zavreti.
        def demos_fail(payload_hash, msg)
          js("MDD.fail(#{payload_hash.merge('msg' => msg).to_json})")
          set_status(msg, true)
        end

        def handle_demos_apply(payload)
          data = JSON.parse(payload.to_s)
          unless catalog_write_ok?(data)
            return js("MDD.fail(#{{ 'msg' => 'Katalóg sa zmenil — zavri rozpis a skús znova.' }.to_json})")
          end
          # GH #98 P2: row_rev VYHRADNE zo serveroveho baseline z casu lookupu
          # (@demos_base_revs) — klientske row_rev sa ignoruju. Zaznam zmeneny
          # od lookupu = :conflict a treba NOVY lookup (proposal bol overeny
          # proti staremu stavu; cerstvy rev z push_catalog ho nesmie ozivit).
          items = Materials.demos_items_from_accepts(data['accepts'], @demos_proposals || {},
                                                     @demos_base_revs || {})
          if items.empty?
            return demos_fail({}, 'Nie je čo zapísať — nič nie je zaškrtnuté.')
          end
          status, report = Materials.apply_demos_batch(items, catalog_rev: data['catalog_rev'].to_s)
          case status
          when :ok
            demos_bump_session
            @demos_running = false
            @demos_proposals = {}
            @demos_base_revs = {}
            after_catalog_change
            js("MDD.done(#{report.to_json})")
            set_status("Aktualizované z Demosu: #{report['applied'].length} záznamov.")
          when :stale_catalog, :conflict, :not_found
            # FIX 14: atomicky rezim — modal OSTAVA, vinnik sa oznaci; zaznamy
            # sa medzitym zmenili => navrhy su neplatne, treba NOVY lookup.
            demos_fail({ 'status' => status.to_s, 'id' => report['id'] },
                       'Neaktualizované nič — záznamy sa medzitým zmenili. Spusti Aktualizovať z Demosu znova.')
            push_catalog
          when :code_conflict
            demos_fail({ 'status' => 'code_conflict', 'id' => report['id'] },
                       "Neaktualizované nič — kód by sa zdvojil (#{Array(report['detail']).first(3).join(', ')}).")
          when :catalog_read_only
            demos_fail({}, Materials.catalog_read_only_message)
          else # :invalid, :duplak, :write_failed
            demos_fail({ 'status' => status.to_s, 'id' => report['id'] },
                       "Neaktualizované nič — #{report['detail'] || 'položka sa nedá zapísať'}.")
            push_catalog
          end
        end

        def handle_demos_cancel
          demos_bump_session
          @demos_running = false
          set_status('Aktualizácia z Demosu zrušená.')
        end

        # --- V0.6 M-A2: modal "Pridat z Demosu" -------------------------------
        # Family store zije TU (audit BLOCKER 2): server drzi hlavicku + polozky
        # z load_family; JS posiela LEN iid vybranych poloziek. Store je viazany
        # na session (bump pri cancel/close/model switch/novom lookupe ho
        # zneplatni) — create so starou rodinou sa odmietne.

        # Zive navrhy nazvoveho hladania. Ziadny session bump (pisanie nesmie
        # rusit nic bezace); gen echo strazi poradie vysledkov v JS (F10).
        # Chybajuca sitemap cache -> jednorazovy zdielany refresh (single-flight
        # DemosLookup.start_refresh) + stavova hlaska; po dobehnuti JS zopakuje
        # aktualny dotaz (refresh_done).
        def handle_demos_name_search(payload)
          data = JSON.parse(payload.to_s)
          gen = data['gen'].to_i
          if DemosSitemapCache.load.nil?
            # ŠT-2b: zivotnost dorobenia sitemapy je TA ISTA ako pri lookupe —
            # session token (zhasne ho zatvorenie Studia, odchod zo sekcie aj
            # prepnutie dokumentu). Refresh je pritom ZDIELANY single-flight,
            # takze sa tu NEbumpuje: pisanie do naseptavaca nesmie zrusit nic,
            # co uz bezi.
            session = @demos_session.to_i
            alive = demos_alive_proc(session)
            js("NXDA.suggest(#{{ 'gen' => gen, 'refreshing' => true }.to_json})")
            DemosLookup.start_refresh do |ok, err|
              next unless alive.call
              if ok
                js("NXDA.suggest(#{{ 'refresh_done' => true }.to_json})")
              else
                js("NXDA.fail(#{{ 'msg' => "Zoznam produktov sa nepodarilo stiahnuť: #{err}" }.to_json})")
              end
            end
            return
          end
          hits = DemosNameSearch.search_cached(data['query'].to_s)
          js("NXDA.suggest(#{{ 'gen' => gen, 'hits' => hits }.to_json})")
        end

        # Nacitanie rodiny dekoru zo stranky. Novy beh = nova session (stary
        # lookup/create umiera); family store sa plni AZ z family eventu a LEN
        # ak session stale plati (oneskoreny event stareho behu store neprepise).
        def handle_demos_family(payload)
          data = JSON.parse(payload.to_s)
          demos_bump_session
          @demos_family = nil
          @demos_running = true # ŠT-2b: dlhy beh viazany na sekciu
          session = @demos_session
          emit = demos_family_emit(session)
          DemosFamily.load_family(data['url'].to_s,
                                  alive: demos_alive_proc(session),
                                  emit: emit)
        end

        # Emit wrapper family/create eventov: family event odklada rodinu do
        # store (server autorita), complete uspesneho create robi katalogove
        # echo PRED forwardom (JS complete skace na detail — potrebuje cerstvy
        # katalog v okne).
        def demos_family_emit(session)
          lambda do |event|
            if event['type'] == 'family' && @demos_session.to_i == session
              @demos_family = { 'session' => session,
                                'header' => event['header'], 'items' => event['items'] }
              # M-A3b D-59: informativne oznacenie poloziek, ktorych kod uz
              # v katalogu je (rovnaky druh + dodavatel Demos/prazdny) — LEN
              # zobrazenie, do family STORE ide povodny zoznam (autorita
              # dedupu je variantova identita pri zapise).
              flagged = Array(event['items']).map do |it|
                kind = it['kind'].to_s
                next it unless %w[sheet edge].include?(kind)
                Materials.demos_code_known?(kind, it['code']) ? it.merge('in_catalog' => true) : it
              end
              event = event.merge('items' => flagged,
                                  'existing' => demos_family_existing?(event['header']))
            end
            if event['type'] == 'complete' && event['ok'] && event['result'].is_a?(Hash)
              @demos_family = nil
              after_catalog_change
              set_status("Skupina založená z Demosu (#{Array(event['result']['sheets']).length + Array(event['result']['edges']).length} položiek).")
            end
            # Review #1 (P2): DLHY BEH konci aj eventom `family` — vtedy je
            # rodina stiahnuta a dalej sa uz LEN kliká vo vybere. Bez toho by
            # odchod zo sekcie po nacitani rodiny (alebo po NEUSPESNOM create)
            # falosne hlasil „Sťahovanie z Demosu zrušené…", hoci uz nic nebezalo.
            # `complete` pokryva create (uspesny aj neuspesny), `error` pad behu.
            @demos_running = false if %w[family complete error].include?(event['type'].to_s)
            js("NXDA.event(#{event.merge('session' => session).to_json})")
          end
        end

        # Skupina s identitou hlavicky (vyrobca + cislo dekoru) uz v katalogu
        # existuje? UI hint "pridavam do existujucej skupiny" (server aj tak
        # resolvuje pri zapise — toto je len zobrazenie).
        def demos_family_existing?(header)
          return false unless header.is_a?(Hash)
          want = Materials.group_identity_key(header['manufacturer'], header['decor'])
          Materials.sheets.any? { |s| Materials.group_identity_key(s['manufacturer'], s['decor']) == want } ||
            false
        rescue StandardError
          false
        end

        # Zalozenie: server berie polozky VYHRADNE z family store (iid vyber),
        # session sa NEbumpuje (create bezi v aktualnej); po :ok complete emit
        # wrapper bumpne tym, ze store zmaze a katalog echo posle.
        def handle_demos_family_create(payload)
          data = JSON.parse(payload.to_s)
          unless catalog_write_ok?(data)
            return js("NXDA.fail(#{{ 'msg' => 'Katalóg sa medzitým zmenil — zavri „Pridať z Demosu“ a skús znova.' }.to_json})")
          end
          family = @demos_family
          unless family.is_a?(Hash) && family['session'].to_i == @demos_session.to_i
            return js("NXDA.fail(#{{ 'msg' => 'Rodina už nie je načítaná (Štúdio/model sa medzitým zmenili) — začni odznova.' }.to_json})")
          end
          session = @demos_session
          @demos_running = true
          DemosFamily.create(family['header'], family['items'], Array(data['iids']),
                             alive: demos_alive_proc(session),
                             emit: demos_family_emit(session))
        end

        def handle_demos_family_cancel
          demos_bump_session
          @demos_family = nil
          @demos_running = false
        end

        # M-A3b D-60 (audit BLOCKER 2): URL sa NIKDY neberie z klienta — klient
        # posiela len kind+id, zaznam sa cita z katalogu a URL prechadza
        # cerstvym sanitize tesne pred otvorenim (poskodeny zaznam sa neotvori).
        def handle_open_demos_url(payload)
          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s == 'edge' ? 'edge' : 'sheet'
          url = Materials.demos_open_target(kind, data['id'].to_s)
          return set_status('Záznam nemá platnú väzbu na Demos.', true) unless url
          UI.openURL(url)
        end

        # D-74: otvorenie ZHODY naseptavaca — URL pochadza zo serverovej sitemap
        # cache, ale otvara sa VZDY cez cerstvy sanitize (allowlist demos-trade;
        # klientske echo nie je autorita — vzor D-60).
        def handle_open_search_url(payload)
          data = JSON.parse(payload.to_s)
          clean, err = Demos.sanitize_url(data['url'].to_s)
          return set_status("Adresa sa nedá otvoriť#{err ? ": #{err}" : ''}.", true) unless clean
          UI.openURL(clean)
        end

        # --- V0.6 M-A2 (audit F9): preflight mazania variantu ------------------
        # Server zostavi variantovo PRESNY rozpis (label, kod, cena, pouzitie
        # v aktivnom modeli, ochrany) — modal ho ukaze pred potvrdenim. Finalny
        # delete ide existujucimi callbackmi, ktore VSETKY guardy vyhodnotia
        # znova (preflight je informacia, nie autorita).
        def handle_delete_preflight(payload)
          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s == 'edge' ? 'edge' : 'sheet'
          id = data['id'].to_s
          rec = demos_find_record(kind, id)
          return set_status('Záznam sa nenašiel — katalóg sa obnovil.', true) unless rec
          model = Sketchup.active_model
          used = if kind == 'edge'
                   Materials.used_abs_ids(model)[id] || []
                 else
                   Materials.used_material_ids(model)[id] || []
                 end
          info = {
            'kind' => kind, 'id' => id,
            'label' => (kind == 'edge' ? Panel.abs_label(rec, Panel.label_ctx) : Panel.sheet_label(rec, Panel.label_ctx)),
            'code' => rec['code'].to_s, 'supplier' => rec['supplier'].to_s,
            'price' => (kind == 'edge' ? rec['price_per_bm'] : rec['price_per_m2']),
            'demos_url' => rec['demos_url'].to_s,
            'used' => used.uniq.first(6), 'used_count' => used.size,
            'protected' => (kind == 'sheet' && Materials::PROTECTED_SHEET_IDS.include?(id)),
            'duplak_deps' => (kind == 'sheet' ? Materials.duplak_dependents(id).first(3) : [])
          }
          js("MD.confirmDelete(#{info.to_json})")
        end

        # --- D-83 / ŠT-2b: „Nahradiť UNI…" v JEDNOM okne --------------------
        # Vstup zo zdielaneho jadra `ProductionCore.replace_uni` (to uz overilo
        # gen, model a ze uni_id JE UNI) — teda z KONTROLY, ktora je sekciou
        # TOHO ISTEHO okna. Do ŠT-2a to bola cesta do satelitu; teraz je to
        # prepnutie sekcie na `mat` + otvorenie modalu.
        #
        # Poziadavka sa NEPOSIELA slepo hned: pri zatvorenom okne CEF
        # `execute_script` pred nacitanim HTML potichu zahodi, a aj pri
        # otvorenom okne musi modalu predchadzat `push_state` (klient
        # potrebuje CELY katalog, aby k `uni_id` nasiel dlazdicu). Preto sa
        # ODLOZI a spusti ju:
        #   * hned za `show` — ak okno uz bezalo a ohlasilo `ready` (`show`
        #     v tom pripade sam posiela `push_state` s deep-linkom na sekciu),
        #   * inak `ready` callback Studia, hned po jeho prvom `push_state`.
        # Je JEDNORAZOVA a zomiera so zatvorenim Studia aj s prepnutim modelu.
        # Vrati true, ak sa okno podarilo otvorit/aktivovat.
        def request_replace_uni(uni_id, model)
          return false unless defined?(StudioDialog)

          req = { 'uni_id' => uni_id.to_s, 'model_guid' => model_guid(model) }
          live = StudioDialog.dialog_alive? && StudioDialog.ready?
          # Deep-link na sekciu `mat`: bez neho by sa modal otvoril nad
          # Kontrolou (kotva modalov `#matModalRoot` je mimo tela sekcie).
          #
          # Review #8: poziadavka sa odklada AZ PO tom, co sa okno naozaj
          # otvorilo — inak by po zlyhanom `show` (alebo po vynimke v nom)
          # ostala visiet a modal by vystrelil pri NAJBLIZSOM otvoreni Studia,
          # ktore si ho nikto nevyziadal. Z toho isteho dovodu ju `rescue`
          # zahadzuje.
          return false unless StudioDialog.show(open_section: 'mat')

          @pending_replace_uni = req
          flush_pending_replace_uni if live
          true
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.request_replace_uni')
          @pending_replace_uni = nil
          false
        end

        # Spusti odlozenu poziadavku — s CERSTVYM overenim (audit F5): medzi
        # klikom v Kontrole a vykreslenim sekcie sa mohol prepnut model alebo
        # zmenit katalog. Neplatna poziadavka konci stavovou hlaskou, modal sa
        # neotvori.
        def flush_pending_replace_uni
          req = @pending_replace_uni
          return unless req

          @pending_replace_uni = nil # jednorazova aj vo vetve odmietnutia
          model = Sketchup.active_model
          if req['model_guid'].to_s != model_guid(model)
            return set_status('Model sa medzitým prepol — „Nahradiť UNI…“ sa nespustilo.', true)
          end
          uni = Materials.sheet(req['uni_id'].to_s)
          unless uni && Materials.uni?(uni)
            return set_status('Materiál sa medzitým zmenil — „Nahradiť UNI…“ sa nespustilo.', true)
          end
          js("MD.openReplaceUni(#{req['uni_id'].to_s.to_json})")
        end

        # --- V0.6 M-B2: „Nahradit UNI…" --------------------------------------
        # Preview aj apply stavaju plan TOU ISTOU dvojicou scan+classify
        # (materials_replace_uni.rb) — ponuka nemoze slubit nic ine, nez apply
        # spravi. Potvrdenie sa viaze kanonickym ODTLACKOM planu (audit B1):
        # zmena configov, katalogu ci modelu medzi ponukou a potvrdenim = stale.
        def handle_replace_uni_preview(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return push_catalog if ru_stale_model?(data, model)
          plan, err = replace_uni_plan(model, data['uni_id'], data['target_id'])
          return set_status(err, true) if err
          if Materials.replace_uni_empty?(plan)
            uni = Materials.sheet(data['uni_id'].to_s)
            label = uni ? uni['decor'].to_s : 'UNI'
            return js("MD.replaceUniOffer(#{{ 'empty' => "#{label} sa v projekte nepoužíva — niet čo nahradiť." }.to_json})")
          end
          unless plan['blocked'].empty?
            return js("MD.replaceUniOffer(#{{ 'blocked' => plan['summary']['blocked'] }.to_json})")
          end
          js("MD.replaceUniOffer(#{{ 'summary' => plan['summary'],
                                     'pending' => ru_pending(model, data, plan) }.to_json})")
        end

        def handle_replace_uni_apply(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          return push_catalog if ru_stale_model?(data, model)
          confirm = data['confirm']
          return set_status('Potvrdenie nahradenia je neúplné — otvor rozpis znova.', true) unless confirm.is_a?(Hash)
          plan, err = replace_uni_plan(model, confirm['uni_id'], confirm['target_id'])
          return set_status(err, true) if err
          return set_status('UNI sa v projekte už nepoužíva — niet čo nahradiť.', true) if Materials.replace_uni_empty?(plan)
          unless plan['blocked'].empty?
            set_status('Stav sa medzitým zmenil — nahradenie je teraz blokované.', true)
            return js("MD.replaceUniOffer(#{{ 'blocked' => plan['summary']['blocked'] }.to_json})")
          end
          fresh = ru_pending(model, confirm, plan)
          unless Materials.replace_uni_pending_ok?(confirm, fresh)
            set_status('Stav sa medzitým zmenil — skontroluj rozpis znova a potvrď nanovo.')
            return js("MD.replaceUniOffer(#{{ 'summary' => plan['summary'], 'pending' => fresh,
                                              'stale' => true }.to_json})")
          end
          # Board joby KOMPLET pripravene PRED operaciou (audit F4): overena
          # identita, normalizovany config, validacia — pad az po start_operation
          # by nechal rozrobenu davku.
          board_jobs = plan['jobs_board'].map do |inst, merged|
            cfg = BoardBuilder.normalize(merged)
            BoardBuilder.validate_config!(cfg)
            [inst, BoardBuilder.board_id!(inst), cfg]
          end
          selected = Panel.find_cabinet(model)
          Panel.suspend_selection_sync do
            # Zapisy predvolieb + dosky VNUTRI jedinej operacie rebuildov —
            # 1 undo vrati geometriu, dosky aj modelove defaulty naraz.
            CabinetBuilder.rebuild_many(model, plan['jobs_cab'], op_name: 'NOXUN: Nahradiť UNI') do
              plan['project_writes'].each do |k, v|
                raise 'Projektovú predvoľbu sa nepodarilo uložiť.' unless Materials.set_project_default(model, k, v)
              end
              board_jobs.each { |inst, bid, cfg| BoardBuilder.rebuild_in_operation(model, inst, bid, cfg) }
            end
            Panel.reselect(model, selected) if selected && selected.valid?
          end
          set_status(ru_done_msg(plan['summary']))
          # ŠT-2b: predvolby uz nesu DVE UI — nesie ich `mat` payload Studia,
          # ktory dorazi z `refresh_studio_after_model_write` nizsie.
          Panel.push_selected(model) # refresh Inspectora (selecty, karta dielca/dosky)
          refresh_studio_after_model_write
        end

        # ŠT-2a (audit #4): DVE cesty tohto suboru menia MODEL — projektova
        # predvolba a „Nahradiť UNI…". Obe prestavaju skrinky, takze Studio
        # musi dostat PLNY push AJ so zdvihom generacie: kusovnik, kontrola aj
        # rozpocet su po nich naozaj ine cisla a stary klik sa uz odmietnut MA.
        # (Katalogovy zapis je opak — ten ide s `bump: false`, viz
        # `after_catalog_change`.)
        #
        # Poradie (nota #20): AZ ZA `Panel.push_selected`. Ten cez
        # `ScaleWatch.request_dedup` moze naplanovat opravu identity kopii;
        # keby push sla pred nim, jantarove „Obnoviť" by hned po prepocte
        # znovu zozltlo. Overene: dedup otvara operaciu LEN ked naozaj nieco
        # meni — vtedy je jantar pravdivy a `dedup: false` by len zahodil
        # opravu, ktoru prave tato (hromadna) prestavba potrebuje.
        def refresh_studio_after_model_write
          StudioDialog.refresh_if_open if defined?(StudioDialog)
        rescue StandardError => e
          Engine.log_error(e, 'MaterialsDialog.refresh_studio_after_model_write')
        end

        # Spolocna stavba planu: guardy katalogu/zaznamov -> scan -> klasifikacia.
        # Vrati [plan, nil] alebo [nil, chybova hlaska].
        def replace_uni_plan(model, uni_id, target_id)
          if Materials.catalog_state == :read_only
            return [nil, 'Katalóg je v núdzovom režime len na čítanie — nahradenie počká, kým sa katalóg neobnoví.']
          end
          uni = Materials.sheet(uni_id.to_s)
          return [nil, 'UNI materiál sa nenašiel v katalógu.'] unless uni && Materials.uni?(uni)
          target = Materials.sheet(target_id.to_s)
          return [nil, 'Cieľový materiál sa nenašiel v katalógu — obnov Štúdio.'] unless target
          return [nil, 'Cieľom nahradenia nemôže byť ďalší UNI materiál.'] if Materials.uni?(target)
          scan = Materials.replace_uni_scan(model, uni['material_id'])
          [Materials.replace_uni_classify(scan, uni, target), nil]
        end

        def ru_stale_model?(data, model)
          data.key?('model_guid') && !data['model_guid'].to_s.empty? &&
            data['model_guid'].to_s != model_guid(model)
        end

        def ru_pending(model, data, plan)
          { 'model_guid' => model_guid(model), 'uni_id' => data['uni_id'].to_s,
            'target_id' => data['target_id'].to_s,
            'catalog_rev' => Materials.catalog_revision, 'digest' => plan['digest'] }
        end

        def ru_done_msg(s)
          cabs_n = s['adopting_n'].to_i + s['recompute_n'].to_i
          msg = +"UNI nahradené za #{s['target_label']}"
          parts = []
          parts << "#{cabs_n} skriniek (#{s['adopting_n']} prevzalo hrúbku #{Panel.fmt_mm(s['target_th'])} mm)" if cabs_n.positive?
          parts << "#{s['boards'].size} dosiek" unless s['boards'].empty?
          parts << "predvoľby: #{s['project'].join(', ')}" unless s['project'].empty?
          msg << ' — ' << parts.join(', ') unless parts.empty?
          msg << '.'
          abs = s['abs'] || {}
          msg << " ABS hrany prevedené (#{abs['changed']}×)." if abs['changed'].to_i.positive?
          msg << " Bez náhrady: #{Array(abs['lost']).join(', ')}." if abs['lost_n'].to_i.positive?
          msg
        end

        # --- akcia ----------------------------------------------------------

        # Projektovy default materialu (koren dedenia, standard 7.2). Vsetky korpusy,
        # ktore dany material DEDIA (nemaju vlastny override), sa prepocitaju atomicky
        # v jednej Undo operacii. Presunute z Panel (V0.4.5 D2) — povodna logika
        # vratane hrubkovej kontroly nekompatibilnych skriniek.
        def handle_set_project_material(payload)
          model = Sketchup.active_model
          data = JSON.parse(payload.to_s)
          # D-42 (audit BLOCKER 4): predvolba patri modelu, z ktoreho ju pouzivatel
          # vybral. Ak sa medzitym prepol dokument, echo s cudzim guidom sa zahodi
          # (UI sa uz obnovilo cez on_model_changed) — nie ticho do zleho modelu.
          if data.key?('model_guid') && !data['model_guid'].to_s.empty? &&
             data['model_guid'].to_s != model_guid(model)
            Engine.log("projektova predvolba zahodena — echo modelu #{data['model_guid']} nesedi s aktivnym")
            return push_catalog
          end
          key = data['key'].to_s
          value = Panel.present_str(data['value'])
          target = TARGETS[key]
          return set_status('Neznámy projektový materiál.', true) unless target && value

          sheet = Materials.sheet(value)
          return set_status('Vybraný materiál sa nenašiel v katalógu.', true) unless sheet

          cfg_key, role, thickness_key = target

          # Predvolba musi sediet aj s hrubkami NOVEJ skrinky (Codex PR #29): kontrola
          # nizsie prejde len existujuce dediace skrinky — v novom modeli (alebo ked
          # vsetky maju override) by presiel nekompatibilny default (napr. HDF 3 ako
          # korpus) a najblizsi vklad by spadol pri stavbe. Ine hrubky = material na
          # konkretnej skrinke (override), nie projektova predvolba.
          have = sheet['thickness'].to_f
          new_ok =
            case key
            when 'default_material_id'
              # D-45: korpusova predvolba sa uz NEPOROVNAVA s konstantou 18 —
              # vklad sa hrubke materialu prisposobi (insert_thickness_preflight).
              # Strazi sa uz len rozsah, v ktorom korpus vie stat (HDF 3 = stop).
              CabinetBuilder.thickness_in_range?(have)
            when 'default_back_material_id'
              # chrbat ma v UI dve podporovane hrubky (HDF 3 / pevny 18) — obe legalne
              [3.0, 18.0].any? { |t| CabinetBuilder.thickness_ok_for?(role, t, have) }
            else
              CabinetBuilder.thickness_ok_for?(role, Fronts::FRONT_THICKNESS.to_f, have)
            end
          unless new_ok
            return set_status(project_thickness_msg(key, value, have), true)
          end
          selected = Panel.find_cabinet(model)
          affected = Panel.all_cabinets(model).select do |cabinet|
            Panel.present_str(Panel.existing_params(cabinet)[cfg_key]).nil?
          end

          # D-41 PR C (audit FIX 5): projektova predvolba meni efektivny material
          # VSETKYCH dediacich skriniek — rucne ABS overridy zladene so starym
          # dekorom sa preladia (stary default este plati, novy je len v `value`).
          eff_key = { 'default_material_id' => 'body', 'default_front_material_id' => 'front',
                      'default_back_material_id' => 'back' }[key]
          # Snapshot PRED zapisom: baseline kontraktu potvrdenia aj hodnota, na
          # ktoru sa vrati select pri odmietnuti/ponuke.
          old_default = Materials.project_defaults(model)[key].to_s

          if key == 'default_material_id'
            # --- D-46: KORPUS. Dediacim skrinkam sa hrubka nemeni ticho, ale ani
            # sa uz neodmieta natvrdo — pouzivatel dostane presny rozpis a jedno
            # potvrdenie; vsetko potom prebehne v JEDNOM undo kroku.
            plan = body_change_plan(model, affected, sheet, value)
            unless plan['blocked'].empty?
              # Blokujuce dielce sa neprelozia ani potvrdenim — ziadna ponuka
              # (audit F3: nesluboval by sa krok, ktory sa neda vykonat).
              set_status(blocked_cabs_msg(have, plan['blocked']), true)
              return reset_project_select(key, old_default)
            end
            unless plan['adopting'].empty?
              fresh = { 'model_guid' => model_guid(model), 'key' => key, 'value' => value,
                        'old_default' => old_default,
                        'adopting_ids' => plan['adopting'], 'recompute_ids' => plan['recompute'] }
              unless Materials.pending_default_ok?(data['confirm'], fresh)
                return offer_body_change(fresh, have, stale: !data['confirm'].nil?)
              end
            end
            jobs = plan['jobs']
            remap_changed = plan['remap']['changed'].to_i
            remap_lost = plan['remap']['lost']
            adopted_n = plan['adopting'].size
            recomputed_n = plan['recompute'].size
          else
            incompatible = affected.select do |cabinet|
              params = Panel.existing_params(cabinet)
              # D-31 (GH P2): skrinka BEZ chrbta dielec back vobec nema — jej ulozena
              # hrubka (napr. HDF 3) nesmie blokovat zmenu projektoveho chrbta na 18.
              next false if key == 'default_back_material_id' && params['back_mode'] == 'none'
              # V0.6 M-B1: UNI predvolba prijme kazdu hrubku dediacich skriniek.
              next false if Materials.uni?(sheet)
              want = thickness_key ? params[thickness_key].to_f : Fronts::FRONT_THICKNESS
              !CabinetBuilder.thickness_ok_for?(role, want, sheet['thickness'].to_f)
            end
            unless incompatible.empty?
              # D-45: hrubka existujucich DEDIACICH skriniek sa NESMIE zmenit ticho
              # (predvolba by prepisala hotovu vyrobu) — hlaska navedie, co s tym.
              ids = incompatible.map { |cabinet| Store.get(cabinet, 'cabinet_id') }.join(', ')
              return set_status("Materiál #{value} (#{Panel.fmt_mm(have)} mm) má nekompatibilnú hrúbku pre: #{ids}. " \
                                'Nastav ho priamo tým skrinkám (prevezmú hrúbku) alebo im najprv zmeň hrúbku korpusu.', true)
            end

            remap_changed = 0
            remap_lost = []
            adopted_n = 0
            recomputed_n = affected.size
            jobs = affected.map do |cabinet|
              p = Panel.existing_params(cabinet)
              old_eff = Panel.effective_materials(model, p)
              new_eff = old_eff.merge(eff_key => value)
              remap = CabinetBuilder.remap_part_edge_overrides!(p, old_eff, new_eff)
              remap_changed += remap['changed'].to_i
              remap_lost.concat(remap['lost'])
              [cabinet, p]
            end
          end

          Panel.suspend_selection_sync do
            # Zapis predvolby je VNUTRI operacie rebuildov (audit N8) — 1 undo
            # vrati geometriu skriniek AJ modelovy default naraz.
            CabinetBuilder.rebuild_many(model, jobs, op_name: 'NOXUN: projektovy material') do
              raise 'Projektový materiál sa nepodarilo uložiť.' unless Materials.set_project_default(model, key, value)
            end
            Panel.reselect(model, selected) if selected && selected.valid?
          end
          msg = saved_msg(adopted_n, recomputed_n, have)
          msg += " ABS hrany prevedené na nový dekor (#{remap_changed}× dielec)." if remap_changed.positive?
          msg += " Bez náhrady: #{remap_lost.join(', ')}." unless remap_lost.empty?
          set_status(msg)
          # ŠT-2b: predvolby nesie `mat` payload Studia (push nizsie).
          Panel.push_selected(model) # refresh Inspectora (korpusove selecty, karta dielca)
          refresh_studio_after_model_write
        end

        # --- D-46: predvolba korpusu s inou hrubkou ---------------------------

        # PLNY dry-run nad CERSTVYMI kopiami params vsetkych dediacich skriniek.
        # Ta ista funkcia stavia ponuku aj finalne params davky (CabinetBuilder
        # .classify_body_default_change) — pri ponuke sa vysledok len zahodi,
        # do modelu sa nezapisuje NIC.
        def body_change_plan(model, affected, sheet, value)
          entries = affected.map do |cab|
            params = Panel.existing_params(cab) # cerstva kopia z modelu
            [Store.get(cab, 'cabinet_id').to_s, params,
             Panel.effective_materials(model, params), cab]
          end
          CabinetBuilder.classify_body_default_change(entries, sheet, value)
        end

        # Ponuka na potvrdenie: select sa v UI VRATI na skutocny default a pod nim
        # sa zobrazi lista Potvrdiť/Zrušiť. Pending kontrakt (fresh) sa posiela
        # klientovi a pri potvrdeni pride CELY spat — server ho znovu overi.
        def offer_body_change(fresh, have, stale: false)
          msg = confirm_msg(fresh['adopting_ids'].size, fresh['recompute_ids'].size, have)
          msg = "Stav sa medzitým zmenil — #{msg}" if stale
          set_status(msg)
          js("MD.confirmDefault(#{{ 'key' => fresh['key'], 'current' => fresh['old_default'],
                                    'message' => msg, 'pending' => fresh }.to_json})")
        end

        # UI resync po odmietnuti: select nesmie zostat na materiali, ktory sa
        # neulozil (JS ho vrati na skutocny default a zahodi pending).
        def reset_project_select(key, current)
          js("MD.resetProject(#{{ 'key' => key, 'current' => current }.to_json})")
        end

        # Pocty skriniek v spravnom slovenskom tvare (1 / 2–4 / 5+).
        def cabs_phrase(count, tense)
          few = count >= 2 && count <= 4
          noun = count == 1 ? 'skrinka' : (few ? 'skrinky' : 'skriniek')
          verb = if tense == :future
                   few ? 'prevezmú' : 'prevezme'
                 else
                   count == 1 ? 'prevzala' : (few ? 'prevzali' : 'prevzalo')
                 end
          "#{count} #{noun} #{verb}"
        end

        def confirm_msg(adopting, recompute, have)
          msg = "#{cabs_phrase(adopting, :future)} hrúbku #{Panel.fmt_mm(have)} mm"
          msg += " (prepočítajú sa aj ďalšie: #{recompute})" if recompute.positive?
          "#{msg} — potvrď nižšie."
        end

        def saved_msg(adopted, recomputed, have)
          return "Predvoľba uložená — prepočítaných #{recomputed} skriniek." if adopted.zero?
          msg = "Predvoľba uložená — #{cabs_phrase(adopted, :past)} hrúbku #{Panel.fmt_mm(have)} mm"
          msg += ", prepočítaných #{recomputed}" if recomputed.positive?
          "#{msg}."
        end

        # Blokujuce skrinky: "CAB-001: Polica 1, Bok Ľ; CAB-003: Bok P"
        # (konzistentne s D-45 Panel.blocked_parts_msg).
        def blocked_cabs_msg(have, blocked)
          list = blocked.first(3).map do |cid, reason, parts|
            reason == :range ? "#{cid}: mimo rozsahu hrúbky korpusu" : "#{cid}: #{parts.first(4).join(', ')}"
          end.join('; ')
          list += " a ďalšie (#{blocked.length - 3})" if blocked.length > 3
          "Hrúbku #{Panel.fmt_mm(have)} mm blokujú dielce s vlastným materiálom inej hrúbky — #{list}. " \
            'Vráť im materiál na dedený (alebo im vyber materiál tejto hrúbky) a skús znova. ' \
            'Predvoľba sa nezmenila.'
        end

        # D-45: hlaska odmietnutej projektovej predvolby — per rolu (vysvetli PRECO).
        def project_thickness_msg(key, value, have)
          lo = Panel.fmt_mm(CabinetBuilder::THICKNESS_RANGE[0])
          hi = Panel.fmt_mm(CabinetBuilder::THICKNESS_RANGE[1])
          case key
          when 'default_material_id'
            "Materiál #{value} (#{Panel.fmt_mm(have)} mm) je mimo rozsahu hrúbky korpusu (#{lo}–#{hi} mm) — " \
              'ako predvoľbu korpusu ho nastaviť nejde. Tenké dosky sú materiál chrbta alebo konkrétneho dielca.'
          when 'default_back_material_id'
            "Materiál #{value} (#{Panel.fmt_mm(have)} mm) nesedí s podporovanými hrúbkami chrbta (3 alebo 18 mm)."
          else
            "Materiál #{value} (#{Panel.fmt_mm(have)} mm) je mimo rozsahu hrúbky čela (#{lo}–#{hi} mm)."
          end
        end

        # D-42: zmena vyrobcu CELEJ dekorovej skupiny (audit FIX 7 — vyrobca nie je
        # per-variant). Atomicky, ID zaznamov sa nemenia.
        def handle_set_decor_manufacturer(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          # D-44 (audit F9): prazdna hodnota vymaze vyrobcu LEN s explicitnym
          # flagom z tlacidla "Zmazať výrobcu" — omyl pri naseptavaci sa odmietne.
          clear = !!data['clear_manufacturer']
          # 2A-4b (audit B3): klient posiela group_id — v SCHEMA 2 sa skupina
          # identifikuje nim (text dekoru je len fallback pre stare okna).
          ok, result = Materials.set_decor_manufacturer(data['decor'], data['manufacturer'],
                                                        clear: clear, group_id: data['group_id'])
          return set_status(result, true) unless ok
          after_catalog_change
          decor = data['decor'].to_s.strip
          set_status(clear ? "Výrobca dekoru #{decor} zmazaný (#{result} dosiek)."
                           : "Výrobca dekoru #{decor} nastavený (#{result} dosiek).")
        end

        # D-82: farba CELEJ dekorovej skupiny (dosky aj pasky) — vzor
        # handle_set_decor_manufacturer. Variantove formulare farbu uz nemaju;
        # jedina cesta zmeny je tento skupinovy control v hlavicke detailu.
        def handle_set_decor_color(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          ok, result = Materials.set_decor_color(data['decor'], data['color'],
                                                 group_id: data['group_id'])
          return set_status(result, true) unless ok
          after_catalog_change
          decor = data['decor'].to_s.strip
          set_status("Farba dekoru #{decor} zmenená (#{result} záznamov).")
        end

        # --- ŠT-2c 2c-2a: D-69 jednotny editor dekoru -------------------------
        #
        # JEDNA akcia na CELY formular „Upraviť…" (identita skupiny + riadky
        # dosiek + riadky ABS). Guardy si tu NEROBIME: `catalog_write_ok?` by
        # brany (read-only, schema, baseline) vyhodnotil MIMO zamku a medzi
        # kontrolou a zapisom by sa katalog stihol zmenit. Cely kontrakt —
        # vratane `base_rev` a `row_rev` KAZDEHO riadku — bezi POD zamkom
        # v `Materials.save_decor` (audit ŠT-2c, body 3 a 4).
        #
        # Klientove prijimace su tri, aby modal vedel, CO ma urobit s rozpisanym
        # formularom: `MD.editSaved` (zatvor), `MD.editErrors` (chyby k poliam,
        # okno OSTAVA), `MD.editBlocked` (odomkni — hodnoty ostavaju, katalog
        # sa medzitym obnovil).
        def handle_save_decor(payload)
          data = JSON.parse(payload.to_s)
          status, info = Materials.save_decor(data)
          info = {} unless info.is_a?(Hash)
          case status
          when :ok
            after_catalog_change
            set_status(save_decor_status(info))
            js('MD.editSaved()')
          when :invalid
            # Vsetky chyby NARAZ — modal ich rozsvieti pri poliach a ostava
            # otvoreny s hodnotami (pouzivatel ma opravit cislo, nie pisat
            # formular znova).
            js("MD.editErrors(#{Array(info['errors']).to_json})")
            set_status('Formulár sa neuložil — oprav zvýraznené polia.', true)
          when :code_conflict
            hits = Array(info['hits'])
            set_status("Kód „#{info['code']}“ už používa #{hits.size}× (#{hits.first(3).join(', ')}…). Ulož znova pre potvrdenie duplicity.", true)
            js('MD.editDuplicateCode()')
          when :stale, :conflict
            # Katalog sa medzitym zmenil: cerstve data + hodnoty v modáli
            # OSTAVAJU (kontrakt D-15 — odmietnuty zapis nesmie zmazat formular).
            set_status(info['message'] || 'Katalóg sa medzitým zmenil — over hodnoty a ulož znova.', true)
            push_catalog
            js('MD.editBlocked()')
          when :catalog_read_only
            set_status(info['message'] || Materials.catalog_read_only_message, true)
            js('MD.editBlocked()')
          else
            set_status(info['message'] || 'Uloženie katalógu zlyhalo.', true)
            js('MD.editBlocked()')
          end
        end

        def save_decor_status(info)
          parts = []
          created = Array(info['created'])
          updated = Array(info['updated'])
          parts << "#{created.size}× nový variant" unless created.empty?
          parts << "#{updated.size}× upravený variant" unless updated.empty?
          msg = parts.empty? ? 'Dekor uložený — bez zmien vo variantoch.' : "Dekor uložený: #{parts.join(' + ')}."
          skipped = Array(info['skipped'])
          msg += " Preskočené (už existujú): #{skipped.join(', ')}." unless skipped.empty?
          msg
        end

        # --- D-05: sprava katalogu (Codex audit davky 2 zapracovany) ----------
        # Zapis je single-writer kompromis (atomicky rename + .bak; bez locku medzi
        # SketchUp procesmi — vedome akceptovane, katalog edituje jeden pouzivatel).

        # Formularovy save je od zaniku create cesty VYHRADNE EDIT existujuceho
        # zaznamu. Create (akcia add_sheet) ZANIKOL: z UI bol nedosiahnutelny
        # (formular sa otvara len s id; novy dekor/variant = batch v3) a payload
        # formulara nenesie group_id, takze nad SCHEMA >= 2 by zapis skoncil na
        # write_unlocked completeness guarde len s generickym "Ulozenie zlyhalo".
        def handle_save_sheet(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          # 2B-1 (audit F4): duplak vznika VYHRADNE cez create_duplak (vlastne
          # validacie zdroja) — podvrhnute source_* polia v beznom save sa
          # zahadzuju, inak by vytvorili "duplak" bez kompatibilnych guardov.
          data.delete('source_material_id')
          data.delete('source_multiplier')
          ok, err = Materials.validate_sheet_attrs(data)
          return set_status(err, true) unless ok
          # 2B-2 (GH #95 P2): rub vyzaduje skupinovu schemu — v legacy katalogu
          # (hold/nerozhodnutelna migracia) by zapis so SCHEMA 4 targetom padol
          # na group_id kontrole s generickou hlaskou. Jasne NIE s navodom.
          if !data['back_decor'].to_s.strip.empty? &&
             Materials.catalog_schema < Materials::SCHEMA_GROUPS
            return set_status('Rub zásteny vyžaduje katalóg po migrácii na skupiny (2A) — dokonči migráciu, potom rub doplň.', true)
          end
          th = data['thickness'].to_s.tr(',', '.').to_f

          id = data['material_id'].to_s
          existing = Materials.sheet(id)
          unless existing
            return set_status('Materiál sa nenašiel — nový záznam sa pridáva cez „+ variant" alebo „Pridať materiál ručne".', true)
          end
          # GH #103 P2: UNI formularovy edit nesmie obist inline patch guard —
          # nakupne polia (kod/dodavatel/cena) sa pri UNI odmietaju aj tu.
          if (uni_err = Materials.uni_edit_error(existing, data))
            return set_status(uni_err, true)
          end
          # 2B-1: duplak nema editovatelne polia — vsetko derivuje zo zdroja.
          if (dup_err = Materials.duplak_edit_error(existing))
            return set_status(dup_err, true)
          end
          # Hrubka existujuceho variantu je NEMENNA (hrubka definuje variant;
          # zatvorene projekty sa neskontroluju — zmena by im rozbila rebuild).
          if (existing['thickness'].to_f - th).abs > 0.01
            return set_status('Hrúbka definuje variant — pre inú hrúbku pridaj nový materiál.', true)
          end
          # D-41 (audit FIX 12): dekor je identita skupiny a riadi vazbu na ABS —
          # pri edite je NEMENNY; premenovanie celej skupiny je samostatna akcia.
          if data.key?('decor') && data['decor'].to_s.strip != existing['decor'].to_s
            return set_status('Dekor je identita skupiny — premenuj celú skupinu (Premenovať dekor), nie jeden záznam.', true)
          end
          # D-42 (audit BLOCKER 3): typ je sucast variant identity — pri edite je
          # NEMENNY (zrkadlo hrubky/dekoru). Iny typ = novy variant. Duplicitna
          # kontrola uz NESTACI — zmena typu sa vobec nepripusti.
          if data.key?('type') && data['type'].to_s.strip.upcase != existing['type'].to_s.strip.upcase
            return set_status('Typ dosky definuje variant — pre iný typ pridaj nový materiál.', true)
          end
          # D-42 (audit FIX 7): vyrobca je vlastnost DEKORU (skupiny) — jednotlivy
          # variant ho nemeni; zmena celej skupiny je samostatna akcia.
          if data.key?('manufacturer') && data['manufacturer'].to_s.strip != existing['manufacturer'].to_s.strip
            return set_status('Výrobca je vlastnosť dekoru — zmeň ho pre celú skupinu, nie jeden záznam.', true)
          end
          # 2A-1 (standard 7.1): v SCHEMA 2 je identita variantu pri edite
          # NEMENNA aj v novych poliach — struktura, kotva skupiny a pri type
          # PD aj FORMAT platne. Iny format = novy variant (F800 PD 38 4100x600
          # a 4100x920 su dve rozne dosky), nie prepis existujuceho.
          if (err = Materials.identity_edit_error(data, existing))
            return set_status(err, true)
          end
          # 2B-2 (F11): first-fill MENI identitu (prazdne -> hodnota) — nova
          # identita nesmie narazit na existujuci variant (dup check, ktory
          # pri bezych editoch nebezi, lebo identita je nemenna).
          candidate = existing.merge(data)
          if Materials.catalog_schema >= Materials::SCHEMA_GROUPS &&
             (dup = Materials.find_sheet_variant(candidate['decor'], candidate['type'], th,
                                                 candidate['structure'], candidate['sheet_size'],
                                                 group_id: candidate['group_id'],
                                                 manufacturer: candidate['manufacturer'],
                                                 back_decor: candidate['back_decor'],
                                                 back_structure: candidate['back_structure'])) &&
             dup['material_id'] != id
            return set_status("Doplnená identita koliduje s existujúcim variantom (#{dup['material_id']}).", true)
          end

          # D-42 (audit FIX 8): duplicitny kod v ramci dosiek a rovnakeho dodavatela
          # sa nezapise potichu — vyzaduje potvrdenie (allow_duplicate_code).
          conflict = maybe_code_conflict(data, 'sheet', id)
          return conflict if conflict

          # D-19 (Codex F5): payload sa MERGUJE s existujucim zaznamom — klient,
          # ktory nove pole (napr. sheet_size) neposle, ho nesmie ticho resetnut
          # na default cez normalize_sheet.
          rec = existing.merge(data).merge('material_id' => id, 'thickness' => th)
          # D-44 (GH P2): edit s prazdnymi polami formatu = vedome VYMAZANIE —
          # bez explicitneho flagu by merge stary sheet_size ticho podrzal a stav
          # "bez overeneho formatu" by sa pri existujucom zazname nedal dosiahnut.
          rec.delete('sheet_size') if data['clear_sheet_size']
          rec.delete('clear_sheet_size')
          # M-A3e D-71: rucna vazba na dodavatela — cerstvy sanitize (zly host/
          # tvar = save ODMIETNUTY), prazdne pole = vedome zmazanie vazby; zmena
          # alebo zmazanie rusi price_checked_at (cena uz nie je overena).
          if data.key?('demos_url')
            st, val, invalidate = Materials.manual_demos_url(data['demos_url'],
                                                             existing['demos_url'])
            return set_status(val, true) if st == :invalid
            val ? rec['demos_url'] = val : rec.delete('demos_url')
            rec.delete('price_checked_at') if invalidate
          end
          # D-98 (audit B2): zmena ALEBO vymazanie dekoru u dodavatela rusi datum
          # overenia ceny rovnako ako zmena adresy — cena, kod aj URL ostavaju,
          # ale uz nie su overene voci tomu, co dodavatel vedie pod novym cislom.
          if data.key?('supplier_decor') &&
             data['supplier_decor'].to_s.strip != existing['supplier_decor'].to_s.strip
            rec.delete('price_checked_at')
          end
          # 2B-1: edit zdroja drzi zdielane polia duplakov v synchre (format/
          # grain/farba) v JEDNOM atomickom zapise.
          saved = Materials.upsert_sheet_with_duplak_sync(rec)
          return set_status('Uloženie katalógu zlyhalo.', true) unless saved
          after_catalog_change
          set_status("Materiál #{id} upravený.")
        end

        # D-42 (audit FIX 8): ak payload nesie kod a existuje kolizia (rovnaky kod
        # + dodavatel v tom istom druhu) a klient nepotvrdil allow_duplicate_code,
        # vrati status-hlasku (a NEuklada). Inak nil (pokracuj). JS warning sa da
        # obist, autorita je server.
        def maybe_code_conflict(data, kind, self_id)
          code = data['code'].to_s.strip
          return nil if code.empty? || data['allow_duplicate_code']
          hits = Materials.code_conflicts(code, data['supplier'], kind, self_id)
          return nil if hits.empty?
          set_status("Kód „#{code}“ už používa #{hits.size}× (#{hits.first(3).join(', ')}…). Ulož znova pre potvrdenie duplicity.", true)
          js("MD.flagDuplicateCode(#{kind.to_json})")
          'CONFLICT'
        end

        def handle_delete_sheet(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          id = data['material_id'].to_s
          if Materials::PROTECTED_SHEET_IDS.include?(id)
            return set_status('Tento materiál je systémová predvoľba nových projektov — nedá sa zmazať.', true)
          end
          used = Materials.used_material_ids(Sketchup.active_model)[id]
          if used && !used.empty?
            sample = used.uniq.first(3).join(', ')
            return set_status("Materiál #{id} sa používa (#{used.size}×: #{sample}…) — chráni výrobné dáta, nemažem. Pozor: zatvorené projekty sa nedajú skontrolovať.", true)
          end
          # 2B-1: zdroj duplaku sa nemaze (hlaska tu, server backstop v
          # delete_sheet pod zamkom — audit F3).
          deps = Materials.duplak_dependents(id)
          unless deps.empty?
            return set_status("Na dosku sa odkazuje duplák #{deps.first(3).join(', ')} — najprv zmaž duplák.", true)
          end
          return set_status('Zmazanie zlyhalo.', true) unless Materials.delete_sheet(id)
          after_catalog_change
          set_status("Materiál #{id} zmazaný. (Zatvorené projekty sa nedajú skontrolovať — ak ho niektorý používal, dielec oň príde pri najbližšom prepočte.)")
        end

        # 2B-1 (D-43): vytvorenie duplaku — server berie LEN zdroj + nasobic,
        # vsetko ostatne deriva create_duplak_sheet pod zamkom (audit F3/F4).
        def handle_create_duplak(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          state, info = Materials.create_duplak_sheet(data['source_material_id'], data['source_multiplier'])
          case state
          when :ok
            after_catalog_change
            set_status("Duplák pridaný (#{info['material_id']}) — kupuje sa zdrojová #{info['source_material_id']}.")
          when :duplicate
            set_status("Variant s touto identitou už v katalógu je (#{info}).", true)
          when :catalog_read_only
            set_status('Katalóg je len na čítanie — mutácie sú zamknuté.', true)
          when :write_failed
            set_status('Uloženie katalógu zlyhalo.', true)
          else
            set_status(info.to_s, true)
          end
        end

        # EDIT existujucej pasky — create (akcia add_edge) zanikol spolu s
        # add_sheet (rovnaky dovod: z UI nedosiahnutelny, payload bez group_id
        # by nad SCHEMA >= 2 padol na write guarde; nove pasky = batch v3).
        def handle_save_edge(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          ok, err = Materials.validate_edge_attrs(data)
          return set_status(err, true) unless ok
          th = data['thickness'].to_s.tr(',', '.').to_f
          id = data['abs_id'].to_s
          existing = Materials.edge(id)
          unless existing
            return set_status('ABS páska sa nenašla — nová páska sa pridáva cez „+ variant" (dávka dekoru).', true)
          end
          # Hrubka ABS je pri edite NEMENNA (zrkadlo sheet guardu, Codex GH #39):
          # ID nesie hrubku (_10/_20) a dielce ju drzia len cez ID — zmena by ich
          # potichu prepla na inu hranu a ID by klamalo.
          if (existing['thickness'].to_f - th).abs > 0.01
            return set_status('Hrúbka definuje ABS variant — pre inú hrúbku pridaj novú pásku.', true)
          end
          # D-41 (audit FIX 12): dekor nemenny pri edite (identita skupiny).
          if data.key?('decor') && data['decor'].to_s.strip != existing['decor'].to_s
            return set_status('Dekor je identita skupiny — premenuj celú skupinu (Premenovať dekor), nie jeden záznam.', true)
          end
          # 2A-1: struktura/skupina su v SCHEMA 2 identita — pri edite nemenne.
          if (err = Materials.identity_edit_error(data, existing))
            return set_status(err, true)
          end
          # D-41 (audit FIX 12+13): sirka je sucast variant identity — pri edite
          # NEMENNA a payload ju nesmie ani ticho zmazat (stary CEF klient bez
          # pola width): MERGE s existujucim zaznamom (vzor sheet D-19) + sirka
          # sa VZDY berie z existujuceho zaznamu.
          rec = existing.merge(data).merge('abs_id' => id, 'thickness' => th)
          if existing.key?('width')
            rec['width'] = existing['width']
          else
            rec.delete('width')
          end
          # D-42 (audit FIX 8): duplicitny kod ABS (rovnaky dodavatel) -> potvrdenie.
          conflict = maybe_code_conflict(data, 'edge', id)
          return conflict if conflict
          # M-A3e D-71: rucna vazba pasky — rovnaky kontrakt ako doska.
          if data.key?('demos_url')
            st, val, invalidate = Materials.manual_demos_url(data['demos_url'],
                                                             existing['demos_url'])
            return set_status(val, true) if st == :invalid
            val ? rec['demos_url'] = val : rec.delete('demos_url')
            rec.delete('price_checked_at') if invalidate
          end
          return set_status('Uloženie katalógu zlyhalo.', true) unless Materials.upsert_edge(rec)
          after_catalog_change
          set_status("ABS #{id} upravená.")
        end

        def handle_delete_edge(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          id = data['abs_id'].to_s
          used = Materials.used_abs_ids(Sketchup.active_model)[id]
          if used && !used.empty?
            sample = used.uniq.first(3).join(', ')
            return set_status("ABS #{id} sa používa (#{used.size}×: #{sample}…) — nemažem.", true)
          end
          return set_status('Zmazanie zlyhalo.', true) unless Materials.delete_edge(id)
          after_catalog_change
          set_status("ABS #{id} zmazaná.")
        end

        # D-41 PR B: batch "Novy dekor" — parse+validacia+zapis su CELE na serveri
        # (Materials.add_decor_batch, 1 atomicky write; audit FIX 14). JS len
        # posiela surove texty poli.
        def handle_add_decor_batch(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          ok, result = Materials.add_decor_batch(data)
          return set_status(result, true) unless ok
          after_catalog_change
          parts = []
          parts << "#{result['sheets'].size}× doska" unless result['sheets'].empty?
          parts << "#{result['edges'].size}× ABS" unless result['edges'].empty?
          msg = "Dekor #{data['decor'].to_s.strip}: vytvorené #{parts.join(' + ')}."
          msg += " Preskočené (už existujú): #{result['skipped'].join(', ')}." unless result['skipped'].empty?
          msg += ' Ceny doplň úpravou jednotlivých položiek.'
          set_status(msg)
        end

        # D-41 PR B: premenovanie dekoru CELEJ skupiny (audit FIX 12 — edit
        # jednotlivca dekor nemeni; ID zaznamov sa nemenia, modely o nic neprídu).
        # GH #93 P2: nazov skupiny (decor_name) — zobrazovacia vlastnost,
        # atomicky celej skupine cez group_id.
        def handle_set_decor_name(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          ok, result = Materials.set_decor_name(data['group_id'], data['name'])
          return set_status(result, true) unless ok
          after_catalog_change
          label = data['name'].to_s.strip
          set_status(label.empty? ? "Názov skupiny vymazaný (#{result} záznamov)." : "Názov skupiny: #{label} (#{result} záznamov).")
        end

        def handle_rename_decor(payload)
          data = JSON.parse(payload.to_s)
          return unless catalog_write_ok?(data)
          # 2A-4b (audit B3): group_id od klienta — SCHEMA 2 meni VYHRADNE
          # zaznamy danej skupiny (rovnake cislo u ineho vyrobcu sa nedotkne).
          ok, result = Materials.rename_decor(data['old_decor'], data['new_decor'],
                                              group_id: data['group_id'])
          return set_status(result, true) unless ok
          after_catalog_change
          set_status("Dekor premenovaný na #{data['new_decor'].to_s.strip} (#{result} záznamov).")
        end

        # Po kazdej zmene katalogu: cerstvy katalog do sekcie Materialy + zivy
        # katalog v paneli (NX.setMaterials — BEZ resetu formulara panela).
        def after_catalog_change
          # D-42 (audit FIX 13): katalogovy zapis NEskenuje model — pouzite
          # dekory a predvolby sa zapisom do katalogu nemenia.
          #
          # ŠT-2b: UI je JEDNO (sekcia `mat` Studia), takze aj echo je JEDNO.
          # Ide ZAMERNE mimo `js`: pocas akcie sekcie by `js` poslal echo cez
          # sink, cize tomu istemu oknu — ale asynchronny Demos apply bezi UZ
          # BEZ sinku a musi trafit rovnaky kanal. Jedna cesta = jeden vysledok
          # bez ohladu na to, odkial zapis prisiel.
          StudioDialog.push_mat_catalog(catalog_payload) if defined?(StudioDialog)
          Panel.push_materials if defined?(Panel)
          # D-104 (Codex GH #152 P2): katalogovy zapis NIE JE modelova transakcia,
          # takze ModelObserver zvyraznenia hran o nom nevie — a pritom prave
          # zmena typu/podtypu dosky (napr. PD abs <-> postforming) meni, ktore
          # hrany su lepitelne. Cache sa preto oznaci za starú TU; prepocet bezi
          # lazy (refresh Studia nizsie / najblizsie prekreslenie).
          EdgeCheck.invalidate! if defined?(EdgeCheck)
          # D-19 (Codex F3): otvorene okno s cislami zakazky by inak drzalo
          # stary odhad platni (format sa prave mohol zmenit).
          # ŠT-1c PR B3: vetva okna Vyroba tu zanikla spolu s oknom.
          # ST-1a: Studio — skupiny Kusovnika nesu farbu, nazov a hrubku
          # PRIAMO z katalogu.
          # ŠT-2a (audit #4): payload je PLNY, ale generacia sa NEDVIHA. Zapis
          # do katalogu nemeni `rows` ani `refs` (dielec drzi svoje
          # `material_id`) — rozkliknuty riadok Kusovnika ani rozrobeny export
          # inej sekcie preto nesmie zastarat len preto, ze niekto opravil cenu.
          # Vzor je rozpoctovy push (`budget_repush_proc`).
          StudioDialog.refresh_if_open(bump: false) if defined?(StudioDialog)
        end
      end
    end
  end
end
