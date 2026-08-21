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
    end
  end
end
