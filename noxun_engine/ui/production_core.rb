# frozen_string_literal: true
# Noxun Engine — ST-1a PR A: ZDIELANE CISTE JADRO okna Vyroba (a od davky
# ST-1a aj okna Studio).
#
# Preco vlastny modul: kusovnik, supisy platni/ABS a VEPO export sa stahuju
# z okna Vyroba do noveho okna Studio. Obe okna musia citat TIE ISTE cisla —
# dve kopie tych istych pomocnikov by sa casom rozisli (a rozdiel by sa
# prejavil az na vyrobnom vystupe).
#
# ZAVAZNE PRAVIDLO MODULU: ziadny OKENNY STAV. Sem NEPATRI `@dialog`,
# `@generation` ani `@pending_*` — to su veci konkretneho okna. Vsetko tu je
# cista funkcia alebo citanie katalogu/modelu: rovnaky vstup = rovnaky vystup,
# ziadny zapis do modelu, ziadny undo krok.
#
# `ProductionDialog` si ponechava TENKE OBALY s povodnymi menami a signaturami
# (vratane privatnosti) — panel, pure testy aj in-SketchUp runner tieto metody
# volaju presne takto a refactor sa ich nesmie dotknut.
module Noxun
  module Engine
    module ProductionCore
      VEPO_SETTINGS_FILE = 'vepo_settings.json'

      module_function

      # --- VEPO nastavenia (V0.5 C) ---------------------------------------

      # Fallback na defaulty pri poskodenom subore (audit F9) — export nikdy
      # nesmie zablokovat okno kvoli nastaveniam.
      def vepo_settings
        path = File.join(Materials.dir, VEPO_SETTINGS_FILE)
        return {} unless JsonFileStore.available?(path)
        data = JsonFileStore.read(path)
        data.is_a?(Hash) ? data : {}
      rescue StandardError
        {}
      end

      def save_vepo_settings(attrs)
        path = File.join(Materials.dir, VEPO_SETTINGS_FILE)
        JsonFileStore.write(path, vepo_settings.merge(attrs))
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.save_vepo_settings')
      end

      # --- VEPO labely materialov ------------------------------------------

      # VEPO stlpec material: dekor + typ (hrubka je vlastny stlpec); fallback
      # family, fallback material_id. Tvar mapy definuje audit F7.
      #
      # 2A-4b (audit F8 + GH #93 P1): 'label' je EXPORTNY label — grouping +
      # nazov suboru + CSV stlpec. INVARIANT nie je "decor+typ", ale STABILNY
      # TEXT pre te iste realne data: migracia rozdelila "K009 PW" na cislo
      # "K009" + strukturu "PW", takze exportny label MUSI byt zlozeny
      # decor+structure+typ — zmigrovany zaznam da presne povodny text
      # ("K009 PW DTDL") a dve struktury toho isteho cisla sa NEZLEJU do
      # jedneho VEPO bucketu. Legacy zaznam (bez struktury) = dnesny tvar.
      # Strazi zlaty test (legacy fixture == zmigrovana fixture, bajtovo).
      # decor_name ide VYHRADNE do 'display' (zobrazovaci/LOG label).
      # GH #93 P1 (2. kolo): label sklada AJ decor_name — legacy "W1000 ST9
      # Biela" sa migruje na cislo+strukturu+NAZOV, takze bez nazvu by sa
      # export zmenil ("W1000 ST9 DTDL" != "W1000 ST9 Biela DTDL"). Kolizia
      # labelu MEDZI roznymi skupinami (rovnake cislo+struktura+typ dvoch
      # vyrobcov — len SCHEMA 2 stav bez legacy precedensu) dostava prefix
      # vyrobcu, aby sa buckety nezliali.
      def vepo_materials
        labeled = Materials.sheets.map { |s| [s, vepo_base_label(s)] }
        # 1. kolo: kolizia medzi skupinami -> prefix vyrobcu.
        labeled = vepo_disambiguate(labeled) do |s, l|
          [s['manufacturer'].to_s.strip, l].reject(&:empty?).join(' ')
        end
        # GH #93 P2 (3. kolo): aj PO prefixe mozu dve skupiny TOHO ISTEHO
        # vyrobcu zlozit rovnaky text ("K009 PW"+"" vs "K009"+"PW") — druhe
        # kolo pridava stabilny skupinovy sufix, aby sa VEPO buckety nezliali.
        labeled = vepo_disambiguate(labeled) do |s, l|
          "#{l} [#{vepo_group_key(s)}]"
        end
        # GH #93 P1 (4. kolo): kolizia VNUTRI skupiny — dva PD varianty s inym
        # formatom (4100×600 vs 4100×920) maju rovnaky label aj group_key;
        # format je sucast identity PD variantu, do labelu ide pri kolizii.
        labeled = vepo_disambiguate_variants(labeled)
        # Finalna poistka (GH #93 5. kolo): ak by po vsetkych kolach ostala
        # kolizia, rozhodne material_id — bucket sa NIKDY nesmie zliat.
        labeled = vepo_disambiguate(labeled) { |s, l| "#{l} [#{s['material_id']}]" }
        labeled.each_with_object({}) do |(s, l), out|
          entry = { 'label' => l }
          # GH #93 P2 (9. kolo): ked label nesie technicke disambiguatory
          # (vyrobca/skupina/format/ID), LOG ukazuje LUDSKY zaklad cez
          # 'display' — inak by display_labels cesta VepoExportu nikdy nezila.
          human = vepo_base_label(s)
          entry['display'] = human unless human.empty? || human == l
          out[s['material_id']] = entry
        end
      end

      # Ludsky zaklad labelu (cislo struktura nazov typ; fallback family/id) —
      # zdiela ho kompozicia exportneho labelu aj 'display' pre LOG.
      def vepo_base_label(s)
        # 2B-2: rub zasteny patri do labelu VZDY (obchodna identita produktu
        # — Demos vzor "Zastena K551/K552"; bez neho by sa dva ruby zliali).
        back = s['back_decor'].to_s.strip
        back = "/#{[back, s['back_structure'].to_s.strip].reject(&:empty?).join(' ')}" unless back.empty?
        label = [s['decor'], s['structure'], s['decor_name'], s['type'], back]
                .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        label = s['family'].to_s.strip if label.empty?
        label = s['material_id'].to_s if label.empty?
        label
      end

      # Kolizia labelu medzi VARIANTMI (rovnaka skupina): zaznamu s formatom
      # v identite (PD + ZASTENA — 2B-2 flag F10) sa prida "D×S" (cele mm) —
      # identita zakazuje uplne duplicity, takze vysledok je unikatny.
      def vepo_disambiguate_variants(labeled)
        by_label = labeled.group_by { |(_s, l)| l }
        labeled.map do |(s, l)|
          next [s, l] unless by_label[l].length > 1 && Materials.format_in_identity?(s['type'])
          fmt = Materials.size_key(s['sheet_size'])
          # GH #93 P1 (5. kolo): format su mm Floaty — .round by zlial 4100.1
          # a 4100.2; %g drzi normalizovanu presnost size_key (round(2)) a
          # rozne kluce daju VZDY rozny text.
          fmt ? [s, "#{l} #{fmt.map { |x| format('%g', x) }.join('×')}"] : [s, l]
        end
      end

      # Jedno kolo rozlisenia labelov: label zdielany VIACERYMI skupinami sa
      # prepise blokom (zaznamy tej istej skupiny dostanu rovnaky vysledok),
      # unikatne labely sa nemenia.
      def vepo_disambiguate(labeled)
        groups_per = labeled.group_by { |(_s, l)| l }.transform_values do |same|
          same.map { |(r, _l)| vepo_group_key(r) }.uniq
        end
        labeled.map do |(s, l)|
          groups_per[l].length > 1 ? [s, yield(s, l)] : [s, l]
        end
      end

      # Kluc skupiny pre koliznu kontrolu labelu (group_id, fallback vyrobca).
      def vepo_group_key(s)
        gid = s['group_id'].to_s.strip
        gid.empty? ? "man:#{s['manufacturer'].to_s.strip}" : gid
      end

      def vepo_edge_thicknesses
        Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a['thickness'].to_f }
      end

      # Default nazvu projektu z ULOZENEHO suboru (audit F10 — nie z titulku).
      def default_project_name(model)
        p = model.path.to_s
        p.empty? ? 'projekt' : File.basename(p, '.*')
      end

      # --- ST-1a: nazov projektu je SERVEROVA autorita (audit #1) -----------
      #
      # Do ST-1a zil nazov projektu v INPUTE okna Vyroba a kazdy export si ho
      # bral z DOM (`data['project']`). Odkedy su okna DVE, je to pasca: kto
      # prepise nazov v Studiu, exportuje z Vyroby pod inym menom (a naopak) —
      # dva vystupy tej istej zakazky by sa volali rozne.
      #
      # Preto nazov zije v `vepo_settings.json` pod mapou `project_names`
      # (kluc = `model_guid`). Je to nastavenie POCITACA, presne ako
      # `last_dir`/`merge_18_36`: ziadny zapis do modelu, ziadny krok Spat.
      # VSETKY styri exporty (VEPO, CSV kovania, XLSX rozpoctu, XLSX cenovej
      # ponuky) citaju `project_name(model)` — z klienta uz nazov neprichadza.
      PROJECT_NAMES_KEY = 'project_names'
      PROJECT_NAME_MAX = 120 # strop proti nezmyslu z JS (nazov ide do mena suboru)

      def project_names
        v = vepo_settings[PROJECT_NAMES_KEY]
        v.is_a?(Hash) ? v : {}
      end

      # Ulozeny nazov, inak default zo suboru zakazky. Model bez guid (a teda
      # bez identity) ma vzdy default — inak by si dva dokumenty prepisovali
      # ten isty zaznam.
      def project_name(model)
        guid = model_guid(model)
        saved = guid.empty? ? nil : project_names[guid]
        s = saved.to_s.strip
        s.empty? ? default_project_name(model) : s
      end

      # Zapis nazvu. Prazdna hodnota (aj hodnota zhodna s defaultom) zaznam
      # ZMAZE — pomenovanie sa vtedy vrati na nazov .skp suboru a premenovanie
      # suboru sa v okne prejavi samo. Vracia nazov, ktory PLATI po zapise.
      def save_project_name(model, name)
        guid = model_guid(model)
        return project_name(model) if guid.empty?

        s = name.to_s.strip[0, PROJECT_NAME_MAX].to_s.strip
        map = project_names.dup
        if s.empty? || s == default_project_name(model)
          map.delete(guid)
        else
          map[guid] = s
        end
        save_vepo_settings(PROJECT_NAMES_KEY => map)
        project_name(model)
      end

      # „18 a 36 mm do jedneho suboru" — GLOBALNE nastavenie (audit #1: ostava
      # take, ake bolo). Default je zapnute.
      def merge_18_36
        vepo_settings['merge_18_36'] != false
      end

      def save_merge_18_36(value)
        save_vepo_settings('merge_18_36' => (value == true))
        merge_18_36
      end

      # --- Mapy katalogov + identita modelu --------------------------------

      # Stabilna identita modelu — zrkadlo MaterialsDialog.model_guid (oneskoreny
      # klik po prepnuti dokumentu nesmie otvorit modal nad inym projektom).
      def model_guid(model)
        model && model.respond_to?(:guid) ? model.guid.to_s : ''
      rescue StandardError
        ''
      end

      # Katalog dosiek ako mapa pre Validation.run ({ material_id => sheet }).
      def sheets_map
        return {} unless defined?(Materials)

        Materials.sheets.each_with_object({}) { |s, out| out[s['material_id']] = s }
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.sheets_map')
        {}
      end

      # Katalog ABS pasok ako mapa pre Validation.run ({ abs_id => zaznam }) —
      # 2A-2 (F6): kontrola abs_missing (hrana s paskou mimo katalogu). Pri
      # chybe vraciame nil (= kontrola sa preskoci), NIE prazdnu mapu — tá by
      # falosne oznacila vsetky olepene hrany.
      def edges_map
        return nil unless defined?(Materials)

        Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a }
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.edges_map')
        nil
      end

      # --- Vyberove resolvery (klik v okne -> entity v modeli) --------------

      # Nalez 4: PID cielov semaforovej polozky sa hladaju v CERSTVOM modeli podla
      # STABILNEJ identity (owner_id + part_key). Bez part_key = korpus/doska ako
      # celok (vypnute kovanie, korpusove build warning). Vnorene dielce sa vyberaju
      # cez persistent_id (rovnaka cesta ako refs_for).
      def pids_for_problem(model, item)
        # D-103 (Codex audit FIX 4): nalez „dva kusy na jednom mieste" ma VLASTNU
        # adresu — presne tie top-level objekty daneho druhu. Vseobecna vetva nizsie
        # by pri korpuse pribalila aj odpojene dielce s tym istym cabinet_id.
        return pids_for_duplicate(model, item) if item['category'].to_s == Validation::CAT_DUPLICATE

        oid = item['owner_id'].to_s
        pkey = item['part_key'].to_s
        out = []
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          case Store.kind(inst)
          when 'cabinet'
            next unless Store.get(inst, 'cabinet_id').to_s == oid

            if pkey.empty?
              out << inst.persistent_id
            else
              found = []
              inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
                next unless Store.kind(pi) == 'part'
                found << pi.persistent_id if Store.get(pi, 'part_key').to_s == pkey
              end
              # Codex GH #65 P2: build warning moze mierit na dielec, ktory NEBOL
              # postaveny (part_skipped_degenerate, shelf_skipped_shallow_zone) —
              # ziadna entita s tym klucom neexistuje. Fallback: oznac vlastnika
              # (cely korpus), nie prazdny vyber s hlaskou o zmene zoznamu.
              out.concat(found.empty? ? [inst.persistent_id] : found)
            end
          when 'board'
            # Doska JE vlastnik — part_key sa nefiltruje (warning na dosku
            # oznaci dosku aj pri kluci nepostaveneho detailu).
            out << inst.persistent_id if Store.get(inst, 'id').to_s == oid
          when 'part'
            if Store.get(inst, 'cabinet_id').to_s == oid && (pkey.empty? || Store.get(inst, 'part_key').to_s == pkey)
              out << inst.persistent_id
            end
          end
        end
        out.compact.uniq
      end

      # D-103: klik na nalez o zhodnom umiestneni oznaci CELU skupinu (obe/vsetky
      # zhodne umiestnene skrinky ci dosky), aby pouzivatel videl, co presne mazat.
      # Identita je (dup_kind + dup_owner_ids) — zbierana zo SERVERA, klient ju
      # neposiela; hlada sa VYHRADNE medzi top-level objektmi daneho druhu.
      def pids_for_duplicate(model, item)
        kind = item['dup_kind'].to_s
        ids = Array(item['dup_owner_ids']).map(&:to_s).reject(&:empty?)
        return [] if kind.empty? || ids.empty?

        id_key = kind == 'cabinet' ? 'cabinet_id' : 'id'
        out = []
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          next unless Store.kind(inst).to_s == kind
          out << inst.persistent_id if ids.include?(Store.get(inst, id_key).to_s)
        end
        out.compact.uniq
      end

      # Refs podla kluca z CERSTVEHO bomu; fallback pids (SU testy/kompat).
      def refs_for(bom, data)
        if data['parts_key']
          row = bom[:rows].find { |r| r['key'] == data['parts_key'] }
          row ? row['refs'].map { |x| x['pid'] } : []
        elsif data['hw_key']
          g = bom[:hardware].find { |x| x['key'] == data['hw_key'] }
          g ? g['breakdown'].map { |b| b['owner_pid'] } : []
        else
          Array(data['pids'])
        end.compact.uniq
      end

      # --- Zber modelu (ST-1a PR B) ----------------------------------------

      # Cerstvy RAW zber s dedup tickom (Codex GH #48 P2: cerstve kopie mozu
      # zdielat ID — rovnaky sync tick ako push_selected, inak BOM zlieva
      # vlastnikov a klik-select je nejednoznacny). JEDEN collect pre kusovnik,
      # semafor aj VEPO (nalez 5) — compute/Validation citaju TEN ISTY zber.
      def fresh_collect(model)
        CabinetBuilder.dedup_copies(model) if defined?(CabinetBuilder)
        BoardBuilder.dedup_copies(model) if defined?(BoardBuilder)
        Bom.collect(model)
      end

      # V0.6 D1b: nakupny zoznam kovania. Stav snapshotu setov (audit F9):
      # :ok = snapshot projektu · :missing = projekt este sety nezmrazil ->
      # global default LEN NA CITANIE (okna su read-only; zmrazi ho az prva
      # stavba/zmena predvolby) · :invalid = NIC sa nemapuje (vsetko unmapped
      # ORANGE) + banner, NIKDY tichy fallback na dnesny global.
      def hardware_expansion(model, collected)
        status, state = HardwareSets.project_state_status(model)
        if status == :missing
          lib = HardwareSets.load
          by_id = {}
          lib['sets'].each { |s| by_id[s['set_id']] = s }
          state = { 'mapping' => lib['mapping'], 'sets' => by_id }
        end
        exp = HardwareSets.expand(
          Array(collected[:hardware]), state,
          cabinet_overrides: collected[:cabinet_sets].is_a?(Hash) ? collected[:cabinet_sets] : {},
          catalog: HardwareCatalog.items
        )
        # H1b (audit FIX 9 UI): dovod dostane SK text uz na SERVERI — tab
        # Kovanie aj CSV citaju to iste 'reason_sk' (JS ziadny vlastny preklad
        # enumu nema).
        exp['unmapped'] = Array(exp['unmapped']).map do |u|
          u.is_a?(Hash) ? u.merge('reason_sk' => HardwareSets.unmapped_reason_sk(u)) : u
        end
        exp.merge('state_status' => status.to_s)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.hardware_expansion')
        nil
      end

      # Suhrn KONTROLY do statusu okna/exportu (nalez 6: RED neblokuje export).
      def control_suffix(control)
        c = control.is_a?(Hash) ? (control['counts'] || {}) : {}
        return '' if c['total'].to_i.zero?

        " · KONTROLA: #{c['red'].to_i}× RED, #{c['orange'].to_i}× ORANGE (v LOGu)"
      end

      # --- ST-1a (audit #4): popisky materialov pre skupiny Kusovnika -------
      #
      # Skupina kusovnika ma v Studiu farebnu vzorku, ludsky nazov dekoru a
      # hrubku. Ziadny z tychto udajov v BOM riadku NIE JE (riadok nesie
      # `material_id`), takze by si ich klient musel dopytovat z katalogu —
      # a mal by tak DRUHU pravdu o tom, ako sa material vola. Preto ich
      # sklada SERVER, presne ako slovenske labely kovania.
      #
      # `color` je katalogove pole `[r, g, b]` (nie CSS retazec) — prevod na
      # hex robi klient, ktory farbu aj kresli.
      def materials_meta(bom)
        smap = sheets_map
        ids = []
        Array(bom[:rows]).each { |r| ids << row_value(r, 'material_id').to_s }
        Array(bom[:sheets]).each { |s| ids << row_value(s, 'material_id').to_s }
        ids.reject(&:empty?).uniq.each_with_object({}) do |id, out|
          sheet = smap[id]
          out[id] = { 'label' => material_label(sheet, id),
                      'color' => catalog_color(sheet),
                      'th' => sheet ? sheet['thickness'].to_f : nil,
                      'uni' => !sheet.nil? && Materials.uni?(sheet) }
        end
      end

      # To iste pre ABS pasky (pohlad ABS): popis, farba a dekor, ku ktoremu
      # paska patri. Bez toho by supis pasok ukazoval len `abs_id`.
      def edges_meta(bom)
        emap = edges_map || {}
        Array(bom[:edging]).each_with_object({}) do |e, out|
          id = row_value(e, 'abs_id').to_s
          next if id.empty? || out.key?(id)

          rec = emap[id]
          out[id] = { 'label' => edge_label(rec, id), 'color' => catalog_color(rec),
                      'decor' => rec ? rec['decor'].to_s : '',
                      'th' => rec ? rec['thickness'].to_f : nil,
                      'width' => (rec && rec['width'] ? rec['width'].to_f : nil),
                      'code' => rec ? rec['code'].to_s : '' }
        end
      end

      # --- ST-1a (Š2): volitelny stlpec „Rola" ------------------------------
      #
      # BOM riadok rolu NENESIE (agreguje sa podla vyrobnych parametrov, nie
      # podla roly — zrkadlove dielce sa zliavaju zamerne). Rola vsak V ZAZNAME
      # je (`Bom.record` ju cita z entity), takze sa da doplnit READ-ONLY
      # obohatenim: zaznamy sa zoskupia TYM ISTYM `Bom.row_key`, akym vznikli
      # riadky, a k riadku sa priradi zoznam rol. Menit kluc agregacie by zmenilo
      # kusovnik AJ VEPO — to sa kvoli jednemu volitelnemu stlpcu nerobi.
      #
      # Slovensky text sklada SERVER (jedna autorita nazvov, JS ziadny preklad
      # enumu nema — vzor `HardwareRules.label_for`).
      ROLE_LABELS = {
        'side_left' => 'Bok ľavý', 'side_right' => 'Bok pravý',
        'top' => 'Strop', 'bottom' => 'Dno', 'back' => 'Chrbát',
        'shelf' => 'Polica', 'divider_v' => 'Zvislá priečka', 'divider_h' => 'Vodorovná priečka',
        'rail_front' => 'Výstuha predná', 'rail_back' => 'Výstuha zadná',
        'plinth' => 'Sokel', 'front_door' => 'Dvierka', 'drawer_front' => 'Čelo zásuvky',
        'free_panel' => 'Voľná doska'
      }.freeze

      def role_label(role)
        r = role.to_s
        ROLE_LABELS[r] || (r.empty? ? '' : r)
      end

      def row_roles(collected)
        Array(collected[:records]).each_with_object({}) do |r, out|
          next unless r.is_a?(Hash)

          key = Bom.row_key(r)
          list = (out[key] ||= [])
          label = role_label(r['role'])
          list << label unless label.empty? || list.include?(label)
        end
      end

      # Riadky kusovnika obohatene o `role_label` (Š2). Parovanie ide cez
      # RUBY hash (kluc riadku je POLE — v JSON by sa uz neparovalo), takze
      # klient dostane hotovy text priamo v riadku.
      def rows_with_roles(rows, collected)
        roles = row_roles(collected)
        Array(rows).map do |r|
          next r unless r.is_a?(Hash)

          list = roles[r['key']]
          list.nil? || list.empty? ? r : r.merge('role_label' => list.join(' · '))
        end
      end

      # BOM riadky chodia raz so String, raz so Symbol klucmi (Bom.compute vs
      # to_json cesta) — jedno miesto, kde sa to rozhoduje.
      def row_value(row, key)
        return nil unless row.is_a?(Hash)

        row[key].nil? ? row[key.to_sym] : row[key]
      end

      # Ludsky nazov dekoru pre UI (NIE exportny label — ten sklada
      # `vepo_base_label` a nesie navyse typ aj disambiguatory).
      def material_label(sheet, id)
        return id if sheet.nil?

        txt = [sheet['decor'], sheet['structure'], sheet['decor_name']]
              .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        txt = sheet['family'].to_s.strip if txt.empty?
        txt.empty? ? id : txt
      end

      def edge_label(rec, id)
        return id if rec.nil?

        dims = [rec['width'], rec['thickness']].compact.map { |v| format('%g', v.to_f) }
        base = rec['decor'].to_s.strip
        base = id if base.empty?
        dims.length == 2 ? "#{base} #{dims[0]}×#{dims[1]}" : base
      end

      # Katalogova farba ako [r, g, b]; chybajuca/poskodena = nil (klient vtedy
      # nekresli ziadnu vzorku — radsej nic nez nahodna farba).
      def catalog_color(rec)
        c = rec.is_a?(Hash) ? rec['color'] : nil
        c.is_a?(Array) && c.length == 3 ? c.map(&:to_i) : nil
      end

      # --- ST-1a PR B: zdielane telo EXPORTU a VYBERU ----------------------
      #
      # Obe okna (Vyroba aj Studio) robia presne to iste — len s vlastnym
      # `generation` a vlastnym statusom. Preto telo zije TU a okno odovzdava
      # svoj stav EXPLICITNE:
      #   generation — okenny generacny token (B4 guard stareho DOM kliku),
      #   status     — ->(msg, error) do TOHO okna,
      #   repush     — -> { } cerstvy payload TOMU oknu (ak zije).
      # Dva takmer rovnake exporty by sa casom rozisli a rozdiel by sa ukazal
      # az na vyrobnom vystupe.

      # V0.5 C: export VEPO — vstup po relay z panela (edity flushnute) alebo
      # priamo (panel nezije). Poradie: gen check -> flush guard -> vyber
      # priecinka -> CERSTVY BOM -> build -> atomicky zapis -> ulozit settings.
      def do_export(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Dáta okna sa medzitým zmenili — skús export znova.', true)
        end
        if data['flush_blocked']
          return status.call('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
        end

        settings = vepo_settings
        last = settings['last_dir']
        start_dir = last.is_a?(String) && File.directory?(last) ? last : nil
        dir = UI.select_directory(title: 'Priečinok pre VEPO export', directory: start_dir)
        return status.call('Export zrušený.') if dir.nil? || dir.to_s.empty?

        # Nalez 5: JEDEN cerstvy RAW zber -> nad nim compute AJ Validation.run;
        # validaciu EXPLICITNE odovzdame do build (prefix statusu + sekcia
        # KONTROLA v LOGu z TOHO ISTEHO vysledku).
        collected = fresh_collect(model)
        bom = Bom.compute(collected)
        control = Validation.run(collected, sheets: sheets_map, edges: edges_map,
                                 hardware_expansion: hardware_expansion(model, collected),
                                 placements: collected[:placements])
        # audit #1: nazov projektu aj merge su SERVEROVE — z DOM uz nechodia.
        merge = merge_18_36
        result = VepoExport.build(
          bom[:rows],
          project: project_name(model),
          materials: vepo_materials,
          edge_thicknesses: vepo_edge_thicknesses,
          validation: control,
          version: Engine::VERSION,
          generated_at: Time.now.strftime('%Y-%m-%d %H:%M'),
          merge_18_36: merge
        )
        if result['groups'].empty? && result['errors'].empty?
          return status.call('Niet čo exportovať — model nemá výrobné dielce.', true)
        end

        # GH P2: aj ked su VSETKY riadky chybne, LOG s dovodmi sa MUSI zapisat
        # (inak by diagnostika chybala presne pri uplne zlyhanom exporte).
        target = VepoExport.write(result, dir)
        # Nalez 6: KONTROLA nikdy neblokuje export; jej suhrn ide do statusu.
        ctrl = control_suffix(control)
        save_vepo_settings('last_dir' => dir)
        if result['groups'].empty?
          return status.call("Export nevytvoril žiadny CSV — #{result['errors'].length} chybných riadkov. " \
                             "Dôvody v LOGu: #{target}#{ctrl}", true)
        end

        err = result['errors'].empty? ? '' : " · #{result['errors'].length} vyradených riadkov (viď LOG)"
        status.call("VEPO export hotový: #{result['groups'].length} súborov, #{result['total_rows']} riadkov " \
                    "(#{result['total_pieces']} ks) → #{target}#{err}#{ctrl}", !result['errors'].empty?)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_export')
        status.call("Chyba exportu: #{e.message}", true)
      end

      # Vstup pre relay z panela (B1): panel uz flushol edity, mozeme vyberat.
      # Klik nesie KLUC riadku, nie pids (Codex GH #48 P2: flush mohol korpus
      # rebuildnut a stare pids zomreli) — refs sa hladaju v CERSTVOM zbere.
      #
      # `focus_inspector` (ST-1a, Š3 ceruzka): po vybere sa Inspector zdvihne
      # dopredu, aby sa dielec dal rovno upravit. Vyber sa tym NEMENI a do
      # modelu sa nezapisuje nic.
      def do_select(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i # B4: stale klik (iny model/stary DOM)
          repush.call
          return
        end

        collected = fresh_collect(model)
        # Nalez 4: semafor klik nesie STABILNY kluc problemu; validacia sa po
        # flushi editov PREPOCITA NANOVO a entity sa dohladaju podla identity
        # (owner_id + part_key), nie podla PID (rebuild ho meni).
        if data['problem_key']
          # GH #127 P2: klik-resolve MUSI ratat s rovnakym vstupom ako
          # push_state — bez hardware_expansion by sa stable kluce novych
          # ORANGE (hardware_unmapped/hardware_code) nikdy nenasli.
          item = Validation.run(collected, sheets: sheets_map, edges: edges_map,
                                hardware_expansion: hardware_expansion(model, collected),
                                placements: collected[:placements])['items']
                           .find { |it| it['stable_key'] == data['problem_key'] }
          if item.nil?
            repush.call
            return status.call('Kontrola sa medzitým zmenila — obnovené, klikni znova.', true)
          end
          pids = pids_for_problem(model, item)
        else
          pids = refs_for(Bom.compute(collected), data)
        end
        targets = pids.filter_map do |pid|
          ent = model.find_entity_by_persistent_id(pid.to_i)
          ent if ent && ent.valid? && ent.respond_to?(:definition)
        end
        if targets.empty?
          # riadok/polozka medzitym zanikol (flush editov zmenil rozmery/model) —
          # obnov data, nech pouzivatel klikne na aktualny riadok
          repush.call
          return status.call('Zoznam sa medzitým zmenil — obnovené, klikni znova.', true)
        end

        Panel.suspend_selection_sync do
          sel = model.selection
          sel.clear
          targets.each { |t| sel.add(t) }
        end
        Panel.push_selected(model, dedup: false) # B2: ziadna mutacia pri selecte
        focus = data['focus_inspector'] == true && Panel.dialog_alive?
        Panel.bring_to_front if focus
        status.call("Vybraných #{targets.length} položiek v modeli." \
                    "#{focus ? ' Inspector je vpredu — dielec sa dá hneď upraviť.' : ''}")
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_select')
        status.call("Chyba výberu: #{e.message}", true)
      end
    end
  end
end
