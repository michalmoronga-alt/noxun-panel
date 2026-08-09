# frozen_string_literal: true
# Noxun Engine — materialovy katalog: CRUD sekcia dosiek/pasok, validacia +
# generovanie ID, scan pouzitia (delete/edit guard), D-42 patch protokol
# inline buniek, V0.6 B-2a atomicky Demos apply a seed predvolenych zaznamov.
# Cast modulu Materials (mechanicky split materials.rb, V0.5.1) — pozri
# materials.rb pre prehlad.

require 'time' # B-2a: price_checked_at (ISO8601) — vlastny require, nie tranzitivny

module Noxun
  module Engine
    module Materials
      module_function

      # --- CRUD (UI sprava katalogu je V0.5; teraz staci citanie + seed + zaklad zapisu) -------
      # 2A-4a (audit B4): kazdy vstup ma vlastny read-only guard (rychle NIE bez
      # loadu); hlbkova poistka je v write_unlocked — aj cesta, ktora by guard
      # obisla, konci na zapisovej ceste.

      # GH #92 P1: kazdy RMW mutator bezi CELY pod zamkom s cerstvym loadom
      # (stale snapshot by prepisal subezny cudzi zapis — vzor batch v3/ensure).
      def upsert_sheet(attrs)
        return false if catalog_read_only?
        rec = normalize_sheet(attrs)
        return false if rec.nil?
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          enforce_group_color!(rec, data, :sheet) # D-82: farbu drzi skupina, nie payload
          data['sheets'] = data['sheets'].reject { |m| m['material_id'] == rec['material_id'] } + [rec]
          write_unlocked(data)
        end
      end

      def upsert_edge(attrs)
        return false if catalog_read_only?
        rec = normalize_edge(attrs)
        return false if rec.nil?
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          enforce_group_color!(rec, data, :edge) # D-82: farbu drzi skupina, nie payload
          data['edges'] = data['edges'].reject { |a| a['abs_id'] == rec['abs_id'] } + [rec]
          write_unlocked(data)
        end
      end

      def delete_sheet(id)
        return false if catalog_read_only?
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          # 2B-1 (audit F3): zdroj duplaku sa nemaze — kontrola POD zamkom nad
          # cerstvymi datami (UI hlasku stavia duplak_dependents, toto je
          # server backstop proti TOCTOU okno medzi kontrolou a zapisom).
          return false if data['sheets'].any? { |m| m['source_material_id'].to_s == id.to_s }
          data['sheets'] = data['sheets'].reject { |m| m['material_id'] == id }
          write_unlocked(data)
        end
      end

      def delete_edge(id)
        return false if catalog_read_only?
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          data['edges'] = data['edges'].reject { |a| a['abs_id'] == id }
          write_unlocked(data)
        end
      end

      # --- 2B-1 (D-43): duplak — variant zdvojeny zo zdrojovej dosky -----------
      # Duplak ma JEDINE vlastne vstupy: zdroj + nasobic. Vsetko ostatne (typ,
      # struktura, grain, farba, format platne, skupina) sa KOPIRUJE zo zdroja
      # pri vytvoreni a na duplaku je nemenne; editovatelne zdielane polia
      # (format non-PD, grain, farba) drzi v synchre upsert_sheet_with_duplak_sync.
      # Hrubka = nasobic x hrubka zdroja (derivovana, ziadny volny vstup).
      # code/supplier/cena sa NEprenasaju — duplak sa nekupuje (kupuje sa zdroj);
      # kupovana hotova doska rovnakej hrubky je BEZNY variant, nie duplak.

      # Atomicke vytvorenie duplaku (audit F3: vsetky guardy POD zamkom nad
      # cerstvym obsahom disku). Vrati [:ok, rec] | [:invalid, msg] |
      # [:duplicate, id] | [:write_failed, nil] | [:catalog_read_only, nil].
      def create_duplak_sheet(source_id, multiplier)
        return [:catalog_read_only, nil] if catalog_read_only?
        mult = multiplier.to_s.match?(/\A\d+\z/) ? multiplier.to_i : nil
        unless mult && DUPLAK_MULTIPLIERS.include?(mult)
          return [:invalid, "Násobič dupláku musí byť #{DUPLAK_MULTIPLIERS.join(' alebo ')}."]
        end
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          if catalog_schema < SCHEMA_GROUPS
            return [:invalid, 'Duplák vyžaduje katalóg v skupinovej schéme (po migrácii 2A).']
          end
          data = load
          source = data['sheets'].find { |s| s['material_id'] == source_id.to_s }
          return [:invalid, 'Zdrojová doska sa v katalógu nenašla — obnov okno.'] unless source
          if duplak?(source)
            return [:invalid, 'Zdroj je sám duplák — reťazenie duplákov nie je povolené.']
          end
          # D-49 (audit B1): UNI nie je vyrobny material — "UNI duplak" by nakazil
          # cely system (semafor, Nahradit UNI, supisy). Guard POD zamkom.
          if uni?(source)
            return [:invalid, 'Duplák sa robí z reálnych dosiek — UNI materiál nemá duplák.']
          end
          # 2B-2 (GH #95 P2): duplak je korpusovy koncept (lepene DTDL/MDF) —
          # typy s formatom v identite (PD, zastena) sa nelepia; duplak by
          # navyse nezvladol first-fill rubu zdroja (immutable kopie by sa
          # rozisli s identitou zdroja). Server zakazuje, UI to ani neponuka.
          # D-49 (GH #116 P2): pozitivny guard cez register (body_candidate) —
          # HDF/KOMPAKT/custom typy sa nelepia tiez (3 mm HDF x2 nie je 6 mm
          # korpusova doska); predtym ich negativny zoznam prepustil.
          unless body_candidate_type?(source['type'])
            return [:invalid, 'Duplák sa robí z korpusových dosiek (DTDL/MDF) — iné typy sa nelepia.']
          end
          rec = duplak_record_from(source, mult)
          if (dup = data['sheets'].find { |s| identity_keys_tolerant?(sheet_identity_key(rec), sheet_identity_key(s)) })
            return [:duplicate, dup['material_id']]
          end
          rec['material_id'] = generate_sheet_id(rec['decor'], rec['type'], rec['thickness'],
                                                 structure: rec['structure'], sheet_size: rec['sheet_size'],
                                                 taken: data['sheets'].map { |s| s['material_id'].to_s.upcase })
          # D-82: duplak je novy variant TEJ ISTEJ skupiny — farbu dedi po nej
          # (duplak_record_from ju kopiruje zo zdroja, toto je poistka aj pre
          # zdroj s chybajucou/poskodenou farbou).
          data['sheets'] += [enforce_group_color!(normalize_sheet(rec), data, :sheet)]
          # Prvy duplak LAZY zdvihne marker na 3 — starsie verzie pluginu by
          # source_* polia pri zapise zahodili (write_unlocked ich odmietne).
          data['schema'] = SCHEMA_DUPLAK
          return [:write_failed, nil] unless write_unlocked(data)
          [:ok, rec]
        end
      end

      # Derivovany zaznam duplaku zo zdroja (bez ID — to prideluje volajuci
      # pod zamkom). Kopiruje sa vsetko zdielane; nakupne polia sa vynechaju.
      # D-49 (audit B1): ani UNI flagy, ani Demos vazba — duplak sa nekupuje,
      # "Aktualizovat z Demosu" by inak fetchoval zdrojovu 18-ku na duplak a
      # zdedene uni:true by z duplaku spravilo pracovny material.
      # D-98 (audit F5): ani `supplier_decor` — duplak sa NEKUPUJE, takze
      # dodavatelov alias dekoru nema komu sluzit; zdedeny by navyse tvrdil,
      # ze duplak ma vlastnu produktovu stranku u dodavatela.
      def duplak_record_from(source, mult)
        rec = source.reject do |k, _|
          %w[material_id code supplier price_per_m2 supplier_decor
             uni uni_role demos_url price_checked_at].include?(k)
        end
        rec['thickness'] = (source['thickness'].to_f * mult).round(2)
        rec['source_material_id'] = source['material_id'].to_s
        rec['source_multiplier'] = mult
        rec
      end

      # --- D-49: duplak automaticky ----------------------------------------
      # JEDINA vstupna brana automatiky (select "36 (duplak)" aj buduce cesty).
      # Idempotentne: existujuci duplak (zdroj, nasobic) sa vrati bez zapisu.
      # Kolizia identity s KUPOVANOU doskou (bezna 36-ka toho isteho dekoru) =
      # :exists_regular — kupovana doska sa NIKDY nevydava za duplak (audit B2);
      # volajuci ju smie pouzit ako obycajny material, ale bez source vazby.
      # Vrati [:ok, rec] | [:exists_regular, rec] | [:invalid, msg] |
      #        [:write_failed, nil] | [:catalog_read_only, nil].
      def ensure_duplak_for(source_id, multiplier)
        existing = duplak_dependents(source_id)
                   .find { |s| s['source_multiplier'].to_i == multiplier.to_i }
        return [:ok, existing] if existing
        status, res = create_duplak_sheet(source_id, multiplier)
        case status
        when :ok then [:ok, res]
        when :duplicate
          rec = sheet(res)
          if rec && duplak?(rec) && rec['source_material_id'].to_s == source_id.to_s
            [:ok, rec] # sub-tolerancna kolizia identity ineho duplaku toho isteho zdroja
          else
            [:exists_regular, rec]
          end
        else
          [status, res]
        end
      end

      # D-49: zdroje, ktorym sa v selectoch ponuka VIRTUALNA polozka
      # "(duplak x2)". Cita katalog; ponuka sa len ked:
      #   - zdroj je realna KORPUSOVA doska (body_candidate register = DTDL/MDF;
      #     GH #116 P2 — HDF/KOMPAKT/custom sa nelepia, negativny filter ich pustal),
      #   - duplak (zdroj, 2) este neexistuje,
      #   - identitu zdvojenej hrubky NEDRZI kupovana doska (audit B2 — ta ma
      #     prednost a virtualna ponuka by ju obisla).
      # Vrati pole zdrojovych zaznamov (poradie katalogu).
      def duplak_offer_sources(multiplier = 2)
        sheets.select do |s|
          next false if uni?(s) || duplak?(s)
          next false unless body_candidate_type?(s['type'])
          next false if duplak_dependents(s['material_id'])
                        .any? { |d| d['source_multiplier'].to_i == multiplier }
          probe = duplak_record_from(s, multiplier)
          key = sheet_identity_key(probe)
          next false if sheets.any? { |o| identity_keys_tolerant?(sheet_identity_key(o), key) }
          true
        end
      end

      # Duplaky ukazujuce na dany zdroj (delete guard + UI vypis). Cita katalog.
      def duplak_dependents(source_id)
        sheets.select { |s| s['source_material_id'].to_s == source_id.to_s }
              .map { |s| s['material_id'] }
      end

      # Edit hlaska pre duplak (save_sheet aj patch): duplak nema editovatelne
      # polia — vsetko je derivovane zo zdroja alebo zakazane (nakupne polia).
      def duplak_edit_error(existing)
        return nil unless duplak?(existing)
        "Duplák sa odvodzuje zo zdrojovej dosky #{existing['source_material_id']} — uprav zdrojovú (alebo duplák zmaž a vytvor nový)."
      end

      # Upsert zdrojovej dosky + synchro zdielanych editovatelnych poli na jej
      # duplakoch (format platne, grain, farba) v JEDNOM atomickom zapise.
      # Identity polia (typ/struktura/hrubka/skupina) su na zdroji nemenne,
      # takze duplaky sa nikdy nerozidu v identite.
      def upsert_sheet_with_duplak_sync(attrs)
        rec = normalize_sheet(attrs)
        return false if rec.nil?
        return false if catalog_read_only?
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          enforce_group_color!(rec, data, :sheet) # D-82: farbu drzi skupina, nie payload
          data['sheets'] = data['sheets'].reject { |m| m['material_id'] == rec['material_id'] } + [rec]
          data['sheets'] = data['sheets'].map do |s|
            next s unless s['source_material_id'].to_s == rec['material_id']
            synced = s.merge('grain' => rec['grain'], 'color' => rec['color'])
            if rec.key?('sheet_size')
              synced['sheet_size'] = rec['sheet_size']
            else
              synced.delete('sheet_size')
            end
            synced
          end
          write_unlocked(data)
        end
      end

      # 2A-4a (audit B1/B4): seed smie LEN skutocne panensky stav. Poskodeny
      # primar (existuje -> available?), zaloha .bak alebo predmigracna zaloha
      # znamenaju OBNOVITELNE data — seed by ich zamaskoval. Read-only rezim
      # seed tiez nikdy nespusta.
      # 2A-4b (audit F9): panensky stav sa seeduje NATIVNE v SCHEMA 2 (marker 2)
      # — fresh install uz nikdy nemigruje.
      def ensure_seeded
        return if JsonFileStore.available?(path)
        return if catalog_read_only?
        return if File.exist?(pre_schema2_backup_path)
        write({ 'sheets' => seed_sheets, 'edges' => seed_edges, 'schema' => SCHEMA_GROUPS })
      end

      # --- davka 2: validacia + generovanie ID + scan pouzitia -----------------
      # (Codex audit: normalize NIE je validator — server-side vrstva pre CRUD UI.)

      # Zvaliduje atributy doskoveho materialu z formulara. Vrati [ok, chyba].
      def validate_sheet_attrs(a)
        decor = (a['decor'] || a[:decor]).to_s.strip
        type  = (a['type'] || a[:type]).to_s.strip
        return [false, 'Dekor je povinný.'] if decor.empty?
        return [false, 'Typ dosky je povinný (DTDL/MDF/HDF…).'] if type.empty?
        th = a['thickness'] || a[:thickness]
        return [false, 'Hrúbka musí byť kladné číslo.'] unless th.is_a?(Numeric) ? th.positive? : th.to_s.strip.match?(/\A\d+([.,]\d+)?\z/) && th.to_s.tr(',', '.').to_f.positive?
        grain = (a['grain'] || a[:grain] || 'none').to_s
        return [false, 'Smer dekoru musí byť length/width/none.'] unless GRAINS.include?(grain)
        ok_p, err_p = validate_price(a['price_per_m2'] || a[:price_per_m2])
        return [false, err_p] unless ok_p
        ok_t, err_t = validate_text_fields(a)
        return [false, err_t] unless ok_t
        rgb = a['color'] || a[:color]
        if rgb && !(rgb.is_a?(Array) && rgb.size == 3 && rgb.all? { |c| c.to_i.between?(0, 255) })
          return [false, 'Farba musí byť RGB 0–255.']
        end
        # D-19: format platne je volitelny — ak je poslany, musia to byt dve
        # cisla v SHEET_SIZE_RANGE (striktne — nie ticha oprava, Codex F4).
        # D-44 (audit F6): rozsah zdiela s batchom cez konstantu.
        ss = a['sheet_size'] || a[:sheet_size]
        if ss
          valid = ss.is_a?(Array) && ss.size == 2 &&
                  ss.all? { |x| (n = pair_num(x)) && SHEET_SIZE_RANGE.cover?(n) }
          return [false, "Formát platne musí byť dve čísla #{sheet_size_range_label} mm."] unless valid
        end
        # 2B-2 (F12): rub patri VYHRADNE obojstrannemu typu (ZASTENA) a
        # struktura rubu nesmie prist bez cisla rubu — server, nie UI.
        bd = (a['back_decor'] || a[:back_decor]).to_s.strip
        bs = (a['back_structure'] || a[:back_structure]).to_s.strip
        if (!bd.empty? || !bs.empty?) && !double_sided_type?(type)
          return [false, 'Rubový dekor má len zástena — pre iné typy pole nepatrí.']
        end
        return [false, 'Štruktúra rubu vyžaduje číslo rubového dekoru.'] if bd.empty? && !bs.empty?
        return [false, "Rubový dekor je príliš dlhý (max #{CODE_MAX})."] if bd.length > CODE_MAX
        return [false, "Štruktúra rubu je príliš dlhá (max #{CODE_MAX})."] if bs.length > CODE_MAX
        # D-72 (GH #119 P1): protitahovy priznak — len zastena a NIKDY s rubom.
        if flag_true?(a['single_sided'] || a[:single_sided])
          unless double_sided_type?(type)
            return [false, 'Protiťahová (jednostranná) je len zástena.']
          end
          unless bd.empty? && bs.empty?
            return [false, 'Protiťahová zástena nemôže mať rubový dekor.']
          end
        end
        # M-C (audit F5): hranova uprava patri VYHRADNE typu PD a len z enumu;
        # chybajuca hodnota je platne "nezname" (server, nie UI).
        pe = (a['pd_edge_subtype'] || a[:pd_edge_subtype]).to_s.strip
        unless pe.empty?
          unless identity_norm(type) == 'PD'
            return [false, 'Hranová úprava (postforming/ABS) patrí len pracovnej doske.']
          end
          unless PD_EDGE_SUBTYPES.include?(pe)
            return [false, 'Hranová úprava musí byť postforming alebo abs.']
          end
        end
        # D-98 (audit F3): alias dekoru u dodavatela — volitelny kratky text,
        # NIKDY na zastene (obojstranny dekor ma vlastnu semantiku lica/rubu).
        sd = (a['supplier_decor'] || a[:supplier_decor]).to_s.strip
        unless sd.empty?
          if double_sided_type?(type)
            return [false, 'Zástena dekor u dodávateľa nemá — strany určuje líce a rub.']
          end
          return [false, "Dekor u dodávateľa je príliš dlhý (max #{CODE_MAX})."] if sd.length > CODE_MAX
        end
        [true, nil]
      end

      # D-42: cena je VOLITELNA (nezadana = prazdna/nil). Ak je zadana, musi byt
      # nezaporne konecne cislo — necislo ("abc") sa ODMIETNE (nie ticha 0).
      CODE_MAX = 120
      def validate_price(raw)
        return [true, nil] if raw.nil? || raw.to_s.strip.empty?
        f = begin
          Float(raw.to_s.tr(',', '.'))
        rescue StandardError
          nil
        end
        return [false, 'Cena musí byť číslo (alebo prázdna).'] unless f && f.finite?
        return [false, 'Cena nesmie byť záporná.'] if f.negative?
        [true, nil]
      end

      # --- 2A-1: guardy SCHEMA 2 (rozhodnutie na SERVERI, dialog je len obal) --

      # Smie klient s danou schemou zapisovat do katalogu? Po migracii na
      # SCHEMA 2 nie — stare okno (CEF cache) o novych identitnych poliach nevie
      # a jeho payload by ich zahodil. V SCHEMA 1 prejde vsetko (spatna
      # kompatibilita: prazdna/chybajuca hodnota od stareho klienta).
      def schema_write_allowed?(client_schema)
        server = catalog_schema
        return true if server < SCHEMA_GROUPS
        client_schema.to_i >= server
      end

      # Identitne polia SCHEMA 2 su pri EDITE nemenne (standard 7.1/7.5):
      # struktura povrchu, kotva skupiny a pri type PD aj FORMAT platne
      # (F800 PD 38 4100x600 a 4100x920 su dva varianty, nie jeden prepisany).
      # V SCHEMA 1 vracia VZDY nil — polia sa vtedy len nesu (dual-mode).
      # Vrati hlasku pre pouzivatela alebo nil.
      def identity_edit_error(attrs, existing)
        return nil if catalog_schema < SCHEMA_GROUPS
        return nil unless attrs.is_a?(Hash) && existing.is_a?(Hash)
        if attrs.key?('structure') &&
           identity_norm(attrs['structure']) != identity_norm(existing['structure'])
          return 'Štruktúra povrchu definuje variant — pre inú štruktúru pridaj nový variant.'
        end
        if attrs.key?('group_id')
          new_gid = attrs['group_id'].to_s.strip
          old_gid = existing['group_id'].to_s.strip
          # GH P2: prazdna hodnota NEsmie kotvu ticho vymazat (merge+normalize
          # by kluc zahodili) — clear group_id je rovnaka zmena identity ako presun.
          if new_gid != old_gid && !(new_gid.empty? && old_gid.empty?)
            return 'Dekorová skupina je identita záznamu — presun medzi skupinami sa nerobí úpravou variantu.'
          end
        end
        # 2B-2 (F11): rub zasteny je identita — VYPLNENY je nemenny; PRAZDNY na
        # existujucom zazname smie byt doplneny jednorazovo (first-fill —
        # legacy zasteny spred 2B-2 by sa inak nedali nikdy skompletizovat).
        # Dup kontrolu first-fillu robi volajuci (handle_save_sheet) — tu sa
        # posudzuje len nemennost.
        if double_sided_type?(existing['type'])
          # D-72 (GH #119 P1): protitahovy zaznam rub NIKDY nedostane —
          # first-fill by ho premenil na INY (obojstranny) produkt so
          # zachovanym kodom/cenou/URL jednostranneho.
          if existing['single_sided'] == true &&
             ((attrs.key?('back_decor') && !identity_norm(attrs['back_decor']).empty?) ||
              (attrs.key?('back_structure') && !identity_norm(attrs['back_structure']).empty?))
            return 'Protiťahová zástena rub nemá — obojstranná je iný produkt, pridaj nový variant.'
          end
          old_bd = identity_norm(existing['back_decor'])
          if attrs.key?('back_decor') && !old_bd.empty? &&
             identity_norm(attrs['back_decor']) != old_bd
            return 'Rubový dekor definuje variant — pre iný rub pridaj nový variant.'
          end
          old_bs = identity_norm(existing['back_structure'])
          if attrs.key?('back_structure') && !old_bs.empty? &&
             identity_norm(attrs['back_structure']) != old_bs
            return 'Štruktúra rubu definuje variant — pre inú pridaj nový variant.'
          end
        end
        # 2B-2 (F10): format v identite riadi register flag (PD + ZASTENA).
        return nil unless format_in_identity?(existing['type'])
        changed_size = attrs.key?('sheet_size') &&
                       size_key(attrs['sheet_size']) != size_key(existing['sheet_size'])
        # GH P2: clear na zazname BEZ formatu je no-op (editor posiela flag pri
        # prazdnych poliach vzdy) — odmietat len skutocnu zmenu identity.
        clear_real = attrs['clear_sheet_size'] && !size_key(existing['sheet_size']).nil?
        # 2B-2 (F11): doplnenie formatu na zazname BEZ formatu je first-fill
        # (povoleny), zmena/clear existujuceho formatu je zmena identity.
        changed_real = changed_size && !size_key(existing['sheet_size']).nil?
        if clear_real || changed_real
          return 'Formát platne definuje variant — pre iný formát pridaj nový variant.'
        end
        nil
      end

      # D-42: kod a dodavatel su volitelne kratke texty (limit proti zneuzitiu).
      CP_NAZOV_MAX = 200

      def validate_text_fields(a)
        %w[code supplier].each do |k|
          v = (a[k] || a[k.to_sym]).to_s
          return [false, "Pole #{k == 'code' ? 'Kód' : 'Dodávateľ'} je príliš dlhé (max #{CODE_MAX})."] if v.length > CODE_MAX
        end
        # E-b2: obchodny nazov je dlhsi (celu vetu pise Michal), ale nie neobmedzeny.
        cp = (a['cp_nazov'] || a[:cp_nazov]).to_s
        return [false, "Obchodný názov je príliš dlhý (max #{CP_NAZOV_MAX})."] if cp.length > CP_NAZOV_MAX

        [true, nil]
      end

      def validate_edge_attrs(a)
        decor = (a['decor'] || a[:decor]).to_s.strip
        return [false, 'Dekor ABS je povinný.'] if decor.empty?
        th = (a['thickness'] || a[:thickness]).to_s.tr(',', '.').to_f
        # 2A-3 (audit B1): povolene hrubky su schema-aware (SCHEMA 1 = {1;2},
        # SCHEMA 2 = obchodne hodnoty) — hlaska ich vymenuje z jednej autority.
        unless supported_edge_thickness?(th)
          return [false, "Hrúbka ABS musí byť #{edge_thickness_options_label} mm."]
        end
        ok_p, err_p = validate_price(a['price_per_bm'] || a[:price_per_bm])
        return [false, err_p] unless ok_p
        ok_t, err_t = validate_text_fields(a)
        return [false, err_t] unless ok_t
        # D-41: sirka volitelna (legacy univerzalna paska); ak je zadana, musi byt
        # konecne cislo v EDGE_WIDTH_RANGE (audit FIX 13).
        w_raw = a['width'] || a[:width]
        unless w_raw.nil? || w_raw.to_s.strip.empty?
          w = begin
            Float(w_raw.to_s.tr(',', '.'))
          rescue StandardError
            nil
          end
          unless w && w.finite? && EDGE_WIDTH_RANGE.cover?(w)
            return [false, 'Šírka ABS musí byť číslo 10–200 mm (alebo prázdna).']
          end
        end
        [true, nil]
      end

      # --- scan pouzitia (delete/edit guard; Codex audit blocker 2) -------------
      # Prejde AKTIVNY model (defaulty na modeli, configy korpusov vratane
      # part_overrides, instancie dielcov, dosky) + GLOBALNE SABLONY. Zatvorene
      # .skp subory sa skontrolovat NEDAJU — hlaska pouzivatela na to upozorni;
      # korpus so zmiznutym materialom prezije ako legacy (data ostanu), doska
      # by pri rebuilde spadla — preto je guard prisny.
      def used_material_ids(model)
        used = Hash.new { |h, k| h[k] = [] }
        PROJECT_KEYS.each do |k|
          v = model_default(model, k)
          used[v.to_s] << 'projektová predvoľba' if v && !v.to_s.empty?
        end
        collect_model_usage(model, used) if model && defined?(Ids)
        collect_template_usage(used)
        used
      end

      def collect_model_usage(model, used)
        Ids.each_of_kind(model, 'cabinet') do |inst|
          cid = Store.get(inst, 'cabinet_id') || Store.get(inst, 'id')
          cfg = Store.config(inst) || {}
          %w[material_id front_material_id back_material_id].each do |k|
            v = cfg[k]
            used[v.to_s] << cid if v && !v.to_s.empty?
          end
          ov = cfg['part_overrides']
          next unless ov.is_a?(Hash)
          ov.each_value do |rec|
            next unless rec.is_a?(Hash)
            v = rec['material_id']
            used[v.to_s] << cid if v && !v.to_s.empty?
          end
        end
        %w[part board].each do |kind|
          Ids.each_of_kind(model, kind) do |inst|
            cfg = Store.config(inst) || {}
            v = cfg['material_id']
            used[v.to_s] << (Store.get(inst, 'id') || kind) if v && !v.to_s.empty?
          end
        end
      end

      def collect_template_usage(used)
        return unless defined?(TemplateStore)
        TemplateStore.load.each do |t|
          cfg = t['config'] || {}
          %w[material_id front_material_id back_material_id].each do |k|
            v = cfg[k]
            used[v.to_s] << "šablóna #{t['name']}" if v && !v.to_s.empty?
          end
        end
      rescue StandardError
        nil
      end

      # ABS pouzitie: edges v configoch dielcov a dosiek + part_overrides korpusov.
      def used_abs_ids(model)
        used = Hash.new { |h, k| h[k] = [] }
        return used unless model && defined?(Ids)
        %w[part board].each do |kind|
          Ids.each_of_kind(model, kind) do |inst|
            cfg = Store.config(inst) || {}
            e = cfg['edges']
            next unless e.is_a?(Hash)
            e.each_value { |v| used[v.to_s] << (Store.get(inst, 'id') || kind) if v && !v.to_s.empty? }
          end
        end
        Ids.each_of_kind(model, 'cabinet') do |inst|
          cid = Store.get(inst, 'cabinet_id') || Store.get(inst, 'id')
          ov = (Store.config(inst) || {})['part_overrides']
          next unless ov.is_a?(Hash)
          ov.each_value do |rec|
            e = rec.is_a?(Hash) ? rec['edges'] : nil
            next unless e.is_a?(Hash)
            e.each_value { |v| used[v.to_s] << cid if v && !v.to_s.empty? }
          end
        end
        used
      end

      # D-42 (audit FIX 8): duplicitny KOD nie je tvrda chyba, ale nakupne riziko —
      # presna (normalizovana) zhoda kodu v ramci ROVNAKEHO druhu (sheet/edge) a
      # dodavatela sa hlasi a vyzaduje potvrdenie (allow_duplicate_code). Kod NIE
      # je variant identity. Vrati pole ID kolidujucich zaznamov (bez self_id).
      # (Split V0.5.1: presunute z povodnej D-41 sekcie — jediny volajuci je patch_record nizsie.)
      def code_conflicts(code, supplier, kind, self_id = nil)
        c = code.to_s.strip.downcase
        return [] if c.empty?
        sup = supplier.to_s.strip.downcase
        records = kind == 'edge' ? edges : sheets
        idk = kind == 'edge' ? 'abs_id' : 'material_id'
        records.select do |r|
          r[idk] != self_id &&
            r['code'].to_s.strip.downcase == c &&
            r['supplier'].to_s.strip.downcase == sup
        end.map { |r| r[idk] }
      end

      # --- D-42 PR C: bezpecny PATCH protokol inline buniek (audit BLOCKER 1) --
      # Bunka posiela LEN menene pole + row_rev (odtlacok riadku z payloadu).
      # Server: whitelist mutable poli (identita sa patchom NIKDY nemeni),
      # merge s CERSTVYM zaznamom pred validaciou, baseline per RIADOK (nie
      # globalny catalog_rev — ina bunka/iny zaznam nekoliduje zbytocne).
      # 2A-4b: 'universal' na ABS je VLASTNOST VYBERU, nie identita (standard
      # 7.5) — toggle v karte skupiny ho meni patchom; false hodnotu
      # normalize_edge kluc odstrani (merge-safe).
      # E-b2: `cp_nazov` je OBCHODNY nazov pre cenovu ponuku — nie identita,
      # nie nakupny udaj; patchom sa da kedykolvek prepisat aj vymazat.
      # D-98: `supplier_decor` (dekor u dodavatela) je rovnaka trieda ako kod —
      # obchodny udaj, nie identita; patchom sa da prepisat aj vymazat. Zmena
      # vsak MENI dokaz identity voci stranke dodavatela, preto s nou padne
      # price_checked_at (audit B2 — nizsie v patch_record).
      PATCHABLE = {
        'sheet' => %w[code supplier price_per_m2 cp_nazov supplier_decor],
        'edge'  => %w[code supplier price_per_bm universal]
      }.freeze

      # Odtlacok JEDNEHO zaznamu (baseline dirty riadku; posiela sa v payloade).
      def record_rev(rec)
        Digest::SHA1.hexdigest(JSON.generate(rec))[0, 12]
      end

      # Aplikuje patch na zaznam. Vrati [:ok, nil] | [:not_found, nil] |
      # [:conflict, nil] (riadok sa medzitym zmenil) | [:invalid, chyba] |
      # [:code_conflict, [id...]] (duplicitny kod bez potvrdenia) |
      # [:write_failed, nil] | [:catalog_read_only, nil] (nudzovy rezim 2A-4a).
      #
      # 2A-4a (audit F7): CELY read-compare-modify-write bezi pod JEDNYM
      # with_catalog_lock nad CERSTVYM obsahom disku — dva procesy s tym istym
      # row_rev sa uz nemozu navzajom prepisat (druhy dostane :conflict).
      # Invalidate PRED citanim, aby cache (CHECK_INTERVAL ~1 s) neklamala
      # o cudzom zapise tesne pred zamkom; record_rev porovnanie bezi vnutri.
      def patch_record(kind, id, patch, row_rev: nil, allow_duplicate_code: false)
        return [:catalog_read_only, nil] if catalog_read_only?
        idk = kind == 'edge' ? 'abs_id' : 'material_id'
        listk = kind == 'edge' ? 'edges' : 'sheets'
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          records = data[listk]
          existing = records.find { |r| r[idk] == id }
          return [:not_found, nil] unless existing
          if row_rev && !row_rev.to_s.empty? && row_rev.to_s != record_rev(existing)
            return [:conflict, nil]
          end
          # 2B-1 (audit F4): duplak nema ANI patchovatelne polia — nakupny kod,
          # dodavatel a cena patria zdroju (duplak sa nekupuje).
          if kind == 'sheet' && (dup_err = duplak_edit_error(existing))
            return [:invalid, dup_err]
          end
          # V0.6 M-B1: UNI nema nakupne polia (universal toggle na ABS sa
          # UNI netyka — uni je len sheet pole).
          if kind == 'sheet' && (uni_err = uni_edit_error(existing, patch))
            return [:invalid, uni_err]
          end
          clean = patch.is_a?(Hash) ? patch.select { |k, _| PATCHABLE.fetch(kind, []).include?(k) } : {}
          return [:invalid, 'Žiadne editovateľné pole.'] if clean.empty?
          merged = existing.merge(clean)
          # D-98 (audit B2): zmena ALEBO vymazanie aliasu dekoru u dodavatela
          # rusi datum overenia ceny — cena/kod/URL ostavaju, ale ako NEOVERENE
          # (rovnaky kontrakt ako zmena demos_url vo formulari). Autorita je
          # server: klient datum nikdy neposiela.
          if clean.key?('supplier_decor') &&
             clean['supplier_decor'].to_s.strip != existing['supplier_decor'].to_s.strip
            merged.delete('price_checked_at')
          end
          ok, err = kind == 'edge' ? validate_edge_attrs(merged) : validate_sheet_attrs(merged)
          return [:invalid, err] unless ok
          # Codex GH #76: dup kontrola bezi pri zmene kodu AJ dodavatela — patch
          # LEN dodavatela vie inak vytvorit existujuci par kod+dodavatel potichu.
          if (clean.key?('code') || clean.key?('supplier')) && !allow_duplicate_code
            code_val = clean.key?('code') ? clean['code'] : existing['code']
            unless code_val.to_s.strip.empty?
              sup = clean.key?('supplier') ? clean['supplier'] : existing['supplier']
              hits = code_conflicts(code_val, sup, kind, id)
              return [:code_conflict, hits] unless hits.empty?
            end
          end
          # Zapis priamo do dat v ruke (ziadny druhy load cez upsert) — rovnaka
          # semantika ako upsert: normalize + reject stareho ID + append.
          rec = kind == 'edge' ? normalize_edge(merged) : normalize_sheet(merged)
          return [:invalid, 'Záznam sa nedá uložiť.'] if rec.nil?
          data[listk] = records.reject { |r| r[idk] == id } + [rec]
          return [:write_failed, nil] unless write(data)
          [:ok, nil]
        end
      end

      # --- V0.6 B-2a: atomicky zapis Demos aktualizacie (audit B6) -------------
      # items: [{'kind'=>'sheet'|'edge','id'=>,'row_rev'=>,
      #          'fields'=>{'code'=>?, 'price'=>?, 'price_confirmed'=>bool?,
      #                     'demos_url'=>?}}]
      # Polia SKLADA Ruby dialog z VLASTNEHO proposal store (server autorita —
      # JS posiela len accept flagy); tu sa aj tak vsetko znovu validuje.
      # Kontrakty:
      #   - ALL-OR-NOTHING: preflight VSETKYCH poloziek pred prvym zapisom;
      #     akykolvek fail = ziadny zapis, report menuje vinnika (NOTE 17).
      #   - catalog_rev sa porovnava VNUTRI zamku nad cerstvym diskom.
      #   - supplier 'Demos' sa zapisuje LEN spolu s prijatym kodom (FIX 11 —
      #     price-only aktualizacia nesmie ticho prepisat dodavatela).
      #   - price_checked_at generuje SERVER a LEN pri potvrdenej cene: prijata
      #     nova hodnota ALEBO 'price_confirmed' (cena na strane Demosu
      #     nezmenena). Kod-only apply datum overenia NEMENI (FIX 10).
      #   - demos_url prechadza Demos.sanitize_url (vazba kod+URL, standard 7.1).
      #   - duplicity kod+dodavatel sa kontroluju v SIMULOVANOM FINALNOM stave
      #     (FIX 12): dve polozky davky s rovnakym novym kodom sa uvidia; parom
      #     nedotknutym touto davkou sa existujuce duplicity nevycitaju.
      # -> [:ok, {'applied'=>[id...],'fields_written'=>n}]
      #  | [:catalog_read_only|:stale_catalog|:invalid|:not_found|:conflict|
      #     :code_conflict|:duplak|:write_failed, {'id'=>?, 'detail'=>?}]
      def apply_demos_batch(items, catalog_rev:)
        return [:catalog_read_only, {}] if catalog_read_only?
        list = items.is_a?(Array) ? items : nil
        return [:invalid, { 'detail' => 'prázdna dávka' }] if list.nil? || list.empty?
        seen = {}
        list.each do |it|
          return [:invalid, { 'detail' => 'neplatná položka dávky' }] unless it.is_a?(Hash)
          kind = it['kind'].to_s
          # Neznamy kind sa NIKDY neinterpretuje implicitne ako sheet (FIX 12).
          return [:invalid, { 'detail' => "neznámy druh záznamu „#{kind}“" }] unless %w[sheet edge].include?(kind)
          id = it['id'].to_s
          return [:invalid, { 'detail' => 'položka bez id' }] if id.empty?
          key = "#{kind}|#{id}"
          return [:invalid, { 'id' => id, 'detail' => 'duplicitná položka dávky' }] if seen[key]
          seen[key] = true
          f = it['fields']
          return [:invalid, { 'id' => id, 'detail' => 'položka bez polí' }] unless f.is_a?(Hash)
        end
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          unless catalog_rev.to_s == catalog_revision
            return [:stale_catalog, { 'detail' => 'katalóg sa medzitým zmenil' }]
          end
          data = load
          stamp = Time.now.utc.iso8601
          merged_by_key = {}
          # Preflight 1: existencia, row_rev, duplak, validacia zluceneho zaznamu.
          list.each do |it|
            kind = it['kind'].to_s
            idk = kind == 'edge' ? 'abs_id' : 'material_id'
            records = data[kind == 'edge' ? 'edges' : 'sheets']
            id = it['id'].to_s
            existing = records.find { |r| r[idk] == id }
            return [:not_found, { 'id' => id }] unless existing
            if it['row_rev'].to_s.empty? || it['row_rev'].to_s != record_rev(existing)
              return [:conflict, { 'id' => id }]
            end
            if kind == 'sheet' && duplak?(existing)
              return [:duplak, { 'id' => id, 'detail' => 'duplák nemá nákupné polia' }]
            end
            patch, err = demos_patch_for(existing, it['fields'], kind, stamp)
            return [:invalid, { 'id' => id, 'detail' => err }] if err
            return [:invalid, { 'id' => id, 'detail' => 'položka nič nemení' }] if patch.empty?
            merged = existing.merge(patch)
            ok, verr = kind == 'edge' ? validate_edge_attrs(merged) : validate_sheet_attrs(merged)
            return [:invalid, { 'id' => id, 'detail' => verr }] unless ok
            # GH #97 P2: duplicitny par sa vycita LEN polozkam, ktore par
            # code+supplier realne MENIA — price-only refresh na zazname s
            # existujucou (vedome povolenou) duplicitou nesmie zamrznut.
            pair = ->(r) { [r['code'].to_s.strip.downcase, r['supplier'].to_s.strip.downcase] }
            merged_by_key[[kind, id]] = { 'merged' => merged, 'fields' => patch.length,
                                          'pair_changed' => pair.call(existing) != pair.call(merged) }
          end
          # Preflight 2 (FIX 12): duplicity kod+dodavatel v SIMULOVANOM stave —
          # menene zaznamy s kodom sa porovnaju proti vsetkym ostatnym (vratane
          # ostatnych poloziek davky po zmene).
          %w[sheet edge].each do |kind|
            idk = kind == 'edge' ? 'abs_id' : 'material_id'
            final = data[kind == 'edge' ? 'edges' : 'sheets'].map do |r|
              entry = merged_by_key[[kind, r[idk].to_s]]
              entry ? entry['merged'] : r
            end
            pairs = {}
            final.each do |r|
              c = r['code'].to_s.strip.downcase
              next if c.empty?
              (pairs["#{c}|#{r['supplier'].to_s.strip.downcase}"] ||= []) << r[idk].to_s
            end
            merged_by_key.each do |(mkind, mid), entry|
              next unless mkind == kind
              next unless entry['pair_changed'] # GH #97 P2: nedotknuty par sa nevycita
              rec = entry['merged']
              c = rec['code'].to_s.strip.downcase
              next if c.empty?
              hits = pairs["#{c}|#{rec['supplier'].to_s.strip.downcase}"].reject { |x| x == mid }
              return [:code_conflict, { 'id' => mid, 'detail' => hits }] unless hits.empty?
            end
          end
          # Zapis: normalize + reject + append, VSETKO naraz, jeden write.
          fields_written = 0
          merged_by_key.each do |(kind, id), entry|
            idk = kind == 'edge' ? 'abs_id' : 'material_id'
            listk = kind == 'edge' ? 'edges' : 'sheets'
            rec = kind == 'edge' ? normalize_edge(entry['merged']) : normalize_sheet(entry['merged'])
            return [:invalid, { 'id' => id, 'detail' => 'záznam sa nedá uložiť' }] if rec.nil?
            data[listk] = data[listk].reject { |r| r[idk] == id } + [rec]
            fields_written += entry['fields']
          end
          return [:write_failed, {}] unless write_unlocked(data)
          [:ok, { 'applied' => merged_by_key.keys.map { |(_, id)| id },
                  'fields_written' => fields_written }]
        end
      end

      # B-2b: accepts (LEN flagy z UI) + proposal store (SERVER) -> items pre
      # apply_demos_batch. Hodnoty vyhradne zo store — klientovi sa neveri ani
      # kod, ani cena, ani URL (audit BLOCKER 6 / server autorita). Polozka bez
      # proposalu alebo bez realneho pola sa VYNECHA (nie je chyba — UI mohlo
      # ukazat checkbox, ktory server medzicasom nevie podlozit).
      # GH #98 P2: row_rev VYHRADNE z base_revs (baseline z CASU LOOKUPU, drzi
      # ho dialog) — klientske row_rev sa nepouziva: proposal overeny proti
      # staremu zaznamu by s cerstvym rev po refreshi potichu prepisal cudziu
      # zmenu. Polozka bez baseline sa vynecha.
      def demos_items_from_accepts(accepts, store, base_revs = nil)
        items = []
        Array(accepts).each do |a|
          next unless a.is_a?(Hash)
          kind = a['kind'].to_s
          id = a['id'].to_s
          p = store.is_a?(Hash) ? store[[kind, id]] : nil
          next unless p.is_a?(Hash)
          base_rev = base_revs.is_a?(Hash) ? base_revs[[kind, id]].to_s : a['row_rev'].to_s
          next if base_rev.empty?
          fields = {}
          if a['code'] == true
            code_new = p.dig('code', 'new').to_s
            code_old = p.dig('code', 'old').to_s
            # zhodny kod sa neposiela znovu (flag z UI nie je dokaz zmeny)
            fields['code'] = code_new if !code_new.empty? && code_new != code_old
          end
          if a['price'] == true && p['price'].is_a?(Hash)
            if p['price']['unchanged'] == true
              fields['price_confirmed'] = true
            elsif p['price']['new']
              fields['price'] = p['price']['new']
            end
          end
          next if fields.empty?
          fields['demos_url'] = p['url'] unless p['url'].to_s.empty?
          items << { 'kind' => kind, 'id' => id, 'row_rev' => base_rev,
                     'fields' => fields }
        end
        items
      end

      # Patch JEDNEJ polozky z accept poli. -> [patch, nil] | [nil, chyba].
      # code -> code + supplier 'Demos' (vazba FIX 11); price -> price_per_*;
      # price alebo price_confirmed -> price_checked_at (server stamp);
      # demos_url -> po sanitize (kazdy uspesny apply drzi vazbu na produkt).
      def demos_patch_for(existing, fields, kind, stamp)
        patch = {}
        price_key = kind == 'edge' ? 'price_per_bm' : 'price_per_m2'
        if fields.key?('code')
          code = fields['code'].to_s.strip
          return [nil, 'prijatý kód je prázdny'] if code.empty?
          patch['code'] = code
          patch['supplier'] = 'Demos'
        end
        price_confirmed = fields['price_confirmed'] == true
        if fields.key?('price')
          price = normalize_price(fields['price'])
          return [nil, 'prijatá cena nie je číslo'] if price.nil?
          return [nil, 'prijatá cena musí byť kladná'] unless price.positive?
          patch[price_key] = price
          price_confirmed = true
        end
        patch['price_checked_at'] = stamp if price_confirmed
        if fields.key?('demos_url')
          clean, err = Demos.sanitize_url(fields['demos_url'])
          return [nil, "adresa produktu: #{err}"] unless clean
          patch['demos_url'] = clean
        end
        # price_confirmed bez zmeny ceny: povoleny patch len s timestampom
        # (cena na Demose nezmenena — obnovuje sa datum overenia, FIX 10).
        [patch, nil]
      end

      # --- seed (V0.6 M-B1 = nativne UNI sada; predtym 2A-4b SCHEMA 2) ---------
      # Fresh install zacina s 5 UNI pracovnymi materialmi (mockup s0): tvorba
      # oslobodena od materialov, realne dekory pridu z Demosu (M-A).
      # ID prvych troch su PRESNE povodne seed ID (opaque, navzdy nemenne —
      # PROJECT_FALLBACK aj stare modely sa viazu na ne; fallback tak na fresh
      # instalacii ukazuje priamo na UNI bez zmeny konstant). Seed ABS pasky
      # ZANIKLI (audit M-B: UNI pasky nema — olep sa riesi az s realnym dekorom).
      #
      # UNI zaznam NIKDY nenesie nakupne polia (code/supplier/cena/demos_url/
      # image_url) — je to pracovny material bez zavazku; strazi to aj
      # duplak_edit_error vzor v patchi (uni_edit_error).

      # Definicia UNI sady na JEDNOM mieste: [id, decor(=nazov), rola, hrubka,
      # farba]. Pouziva ju fresh seed AJ jednorazove doplnenie do existujucich
      # katalogov (ensure_uni_records!) — obe cesty daju identicke zaznamy.
      UNI_SEED = [
        ['K009_PW_DTDL_18', 'Korpus UNI', 'body',   18.0, [169, 169, 178]],
        ['W1000_DTDL_18',   'Čelo UNI',   'front',  18.0, [125, 167, 217]],
        ['UNI_DEKOR2_18',   'Dekor2 UNI', 'decor2', 18.0, [143, 191, 159]],
        ['HDF_WHITE_3',     'HDF UNI',    'hdf',     3.0, [217, 201, 154]],
        ['UNI_DOSKA_18',    'Doska UNI',  'board',  18.0, [201, 167, 217]]
      ].freeze

      def uni_seed_record(id, decor, role, thickness, color)
        {
          'material_id' => id, 'family' => decor, 'manufacturer' => '',
          'decor' => decor, 'group_id' => group_id_for('', decor),
          'type' => 'DTDL', 'thickness' => thickness, 'grain' => 'none',
          'sheet_size' => [2800.0, 2070.0], 'color' => color,
          'production_class' => 'sheet', 'uni' => true, 'uni_role' => role
        }
      end

      def seed_sheets
        UNI_SEED.map { |args| uni_seed_record(*args) }
      end

      def seed_edges
        []
      end

      # V0.6 M-B1: jednorazove DOPLNENIE UNI sady do EXISTUJUCEHO katalogu.
      # Audit M-B BLOCKER 1: zivy katalog sa NIKDY neprepisuje in-place (K009/
      # W1000/HDF mohli byt pouzivatelom pretavene na realne materialy) — UNI
      # zaznamy sa APPENDUJU s vlastnymi UNI_* ID; kolizia ID/dekoru = polozka
      # sa preskoci (nikdy neprepise). Marker subor drzi jednorazovost (aj ked
      # pouzivatel UNI zaznamy vedome zmaze, nevratia sa).
      # Volane z main.rb bootu (vlastny chraneny blok, vzor boot_cutover!).
      UNI_APPEND_IDS = {
        'body' => 'UNI_KORPUS_18', 'front' => 'UNI_CELO_18',
        'decor2' => 'UNI_DEKOR2_18', 'hdf' => 'UNI_HDF_3', 'board' => 'UNI_DOSKA_18'
      }.freeze

      def uni_marker_path
        File.join(dir, 'uni_seed.done')
      end

      def ensure_uni_records!
        return :done if File.exist?(uni_marker_path)
        return :skip if catalog_read_only?
        # Legacy (pred-cutover) katalog nema skupinovu identitu — pocka na
        # migraciu (marker sa nezapise, skusi sa dalsi start).
        return :skip if catalog_schema < SCHEMA_GROUPS
        added = []
        with_catalog_lock do
          JsonFileStore.invalidate(path)
          data = load
          return :skip if catalog_schema_on_disk < SCHEMA_GROUPS
          taken_ids = data['sheets'].map { |s| s['material_id'].to_s.upcase }
          taken_decors = data['sheets'].map { |s| decor_norm_key(s['decor']) } +
                         data['edges'].map { |e| decor_norm_key(e['decor']) }
          UNI_SEED.each do |(_seed_id, decor, role, thickness, color)|
            id = UNI_APPEND_IDS[role]
            next if taken_ids.include?(id.to_s.upcase)
            next if taken_decors.include?(decor_norm_key(decor))
            data['sheets'] << normalize_sheet(uni_seed_record(id, decor, role, thickness, color))
            added << id
          end
          if added.empty? || write_unlocked(data)
            write_uni_marker
            added.empty? ? :noop : :added
          else
            :write_failed
          end
        end
      rescue StandardError => e
        Engine.log_error(e, 'Materials.ensure_uni_records!') if defined?(Engine)
        :error
      end

      def write_uni_marker
        JsonFileStore.write(uni_marker_path, 'done_at' => Time.now.utc.iso8601)
      rescue StandardError
        nil
      end

      # V0.6 M-B1 (vzor duplak_edit_error): UNI zaznam nema nakupne polia —
      # patch/edit kodu, dodavatela ci ceny sa odmieta na SERVERI.
      def uni_edit_error(rec, patch = nil)
        return nil unless uni?(rec)
        # GH #103 P2: formular posiela nakupne kluce VZDY (aj prazdne) —
        # zasah je len NEPRAZDNA hodnota; nil patch = konzervativne odmietnut.
        if patch.is_a?(Hash)
          # M-A3e D-71: demos_url je nakupne pole — UNI vazbu na dodavatela nema.
          # D-98: alias dekoru u dodavatela patri do tej istej triedy.
          touched = %w[code supplier price_per_m2 price_per_bm demos_url supplier_decor].any? do |k|
            patch.key?(k) && !patch[k].to_s.strip.empty?
          end
          return nil unless touched
        end
        'UNI je pracovný materiál bez nákupných polí — kód/cenu dostane až reálny materiál.'
      end

      # GH #103 P2: patri skupina UNI zaznamu? ABS pasky sa v UNI skupine
      # nesmu tvorit ZIADNOU cestou (batch, formular) — server autorita.
      def uni_group?(group_id, decor = nil)
        gid = group_id.to_s.strip
        dec = decor.to_s.strip
        sheets.any? do |s|
          next false unless uni?(s)
          (!gid.empty? && s['group_id'].to_s == gid) ||
            (gid.empty? && !dec.empty? && s['decor'].to_s.strip == dec)
        end
      end
    end
  end
end
