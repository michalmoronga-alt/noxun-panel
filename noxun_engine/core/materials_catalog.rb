# frozen_string_literal: true
# Noxun Engine — materialovy katalog: CRUD sekcia dosiek/pasok, validacia +
# generovanie ID, scan pouzitia (delete/edit guard), D-42 patch protokol
# inline buniek a seed predvolenych zaznamov. Cast modulu Materials
# (mechanicky split materials.rb, V0.5.1) — pozri materials.rb pre prehlad.

module Noxun
  module Engine
    module Materials
      module_function

      # --- CRUD (UI sprava katalogu je V0.5; teraz staci citanie + seed + zaklad zapisu) -------

      def upsert_sheet(attrs)
        rec = normalize_sheet(attrs)
        return false if rec.nil?
        data = load
        data['sheets'] = data['sheets'].reject { |m| m['material_id'] == rec['material_id'] } + [rec]
        write(data)
      end

      def upsert_edge(attrs)
        rec = normalize_edge(attrs)
        return false if rec.nil?
        data = load
        data['edges'] = data['edges'].reject { |a| a['abs_id'] == rec['abs_id'] } + [rec]
        write(data)
      end

      def delete_sheet(id)
        data = load
        data['sheets'] = data['sheets'].reject { |m| m['material_id'] == id }
        write(data)
      end

      def delete_edge(id)
        data = load
        data['edges'] = data['edges'].reject { |a| a['abs_id'] == id }
        write(data)
      end

      def ensure_seeded
        return if JsonFileStore.available?(path)
        write({ 'sheets' => seed_sheets, 'edges' => seed_edges })
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
        if attrs.key?('group_id') && !attrs['group_id'].to_s.strip.empty? &&
           attrs['group_id'].to_s.strip != existing['group_id'].to_s.strip
          return 'Dekorová skupina je identita záznamu — presun medzi skupinami sa nerobí úpravou variantu.'
        end
        return nil unless pd_type?(existing['type'])
        changed_size = attrs.key?('sheet_size') &&
                       size_key(attrs['sheet_size']) != size_key(existing['sheet_size'])
        if attrs['clear_sheet_size'] || changed_size
          return 'Formát PD definuje variant — pre iný formát pridaj nový variant.'
        end
        nil
      end

      # D-42: kod a dodavatel su volitelne kratke texty (limit proti zneuzitiu).
      def validate_text_fields(a)
        %w[code supplier].each do |k|
          v = (a[k] || a[k.to_sym]).to_s
          return [false, "Pole #{k == 'code' ? 'Kód' : 'Dodávateľ'} je príliš dlhé (max #{CODE_MAX})."] if v.length > CODE_MAX
        end
        [true, nil]
      end

      def validate_edge_attrs(a)
        decor = (a['decor'] || a[:decor]).to_s.strip
        return [false, 'Dekor ABS je povinný.'] if decor.empty?
        th = (a['thickness'] || a[:thickness]).to_s.tr(',', '.').to_f
        return [false, 'Hrúbka ABS musí byť 1,0 alebo 2,0 mm.'] unless supported_edge_thickness?(th)
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
      PATCHABLE = {
        'sheet' => %w[code supplier price_per_m2],
        'edge'  => %w[code supplier price_per_bm]
      }.freeze

      # Odtlacok JEDNEHO zaznamu (baseline dirty riadku; posiela sa v payloade).
      def record_rev(rec)
        Digest::SHA1.hexdigest(JSON.generate(rec))[0, 12]
      end

      # Aplikuje patch na zaznam. Vrati [:ok, nil] | [:not_found, nil] |
      # [:conflict, nil] (riadok sa medzitym zmenil) | [:invalid, chyba] |
      # [:code_conflict, [id...]] (duplicitny kod bez potvrdenia) | [:write_failed, nil].
      def patch_record(kind, id, patch, row_rev: nil, allow_duplicate_code: false)
        records = kind == 'edge' ? edges : sheets
        idk = kind == 'edge' ? 'abs_id' : 'material_id'
        existing = records.find { |r| r[idk] == id }
        return [:not_found, nil] unless existing
        if row_rev && !row_rev.to_s.empty? && row_rev.to_s != record_rev(existing)
          return [:conflict, nil]
        end
        clean = patch.is_a?(Hash) ? patch.select { |k, _| PATCHABLE.fetch(kind, []).include?(k) } : {}
        return [:invalid, 'Žiadne editovateľné pole.'] if clean.empty?
        merged = existing.merge(clean)
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
        saved = kind == 'edge' ? upsert_edge(merged) : upsert_sheet(merged)
        return [:write_failed, nil] unless saved
        [:ok, nil]
      end

      # --- seed (predvolene zaznamy podla zadania V0.3) ------------------------

      # Doskove materialy: K009 PW dub 18/16, HDF biela 3, W1000 biela celova 18.
      def seed_sheets
        [
          {
            'material_id' => 'K009_PW_DTDL_18', 'family' => 'Kronospan K009 PW',
            'manufacturer' => 'Kronospan', 'decor' => 'K009 PW', 'type' => 'DTDL',
            'thickness' => 18.0, 'grain' => 'length', 'price_per_m2' => 12.5,
            'sheet_size' => [2800.0, 2070.0], 'color' => [198, 168, 122], 'production_class' => 'sheet'
          },
          {
            'material_id' => 'K009_PW_DTDL_16', 'family' => 'Kronospan K009 PW',
            'manufacturer' => 'Kronospan', 'decor' => 'K009 PW', 'type' => 'DTDL',
            'thickness' => 16.0, 'grain' => 'length', 'price_per_m2' => 11.8,
            'sheet_size' => [2800.0, 2070.0], 'color' => [198, 168, 122], 'production_class' => 'sheet'
          },
          {
            'material_id' => 'HDF_WHITE_3', 'family' => 'HDF biela',
            'manufacturer' => 'Kronospan', 'decor' => 'Biela HDF', 'type' => 'HDF',
            'thickness' => 3.0, 'grain' => 'none', 'price_per_m2' => 3.2,
            'sheet_size' => [2800.0, 2070.0], 'color' => [238, 236, 230], 'production_class' => 'sheet'
          },
          {
            'material_id' => 'W1000_DTDL_18', 'family' => 'Egger W1000 ST9',
            'manufacturer' => 'Egger', 'decor' => 'W1000 ST9 Biela', 'type' => 'DTDL',
            'thickness' => 18.0, 'grain' => 'none', 'price_per_m2' => 13.9,
            'sheet_size' => [2800.0, 2070.0], 'color' => [246, 246, 244], 'production_class' => 'sheet'
          }
        ]
      end

      # ABS pasky: podporujeme iba realne pouzivane hrubky 1.0 a 2.0 mm.
      def seed_edges
        [
          { 'abs_id' => 'ABS_K009_10', 'decor' => 'K009 PW', 'thickness' => 1.0,
            'price_per_bm' => 0.55, 'color' => [198, 168, 122] },
          { 'abs_id' => 'ABS_K009_20', 'decor' => 'K009 PW', 'thickness' => 2.0,
            'price_per_bm' => 0.85, 'color' => [198, 168, 122] },
          { 'abs_id' => 'ABS_W1000_10', 'decor' => 'W1000 ST9 Biela', 'thickness' => 1.0,
            'price_per_bm' => 0.60, 'color' => [246, 246, 244] }
        ]
      end
    end
  end
end
