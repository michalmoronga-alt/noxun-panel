# frozen_string_literal: true
# Noxun Engine — V0.6 M-A: atomicke zalozenie dekorovej skupiny z Demosu.
# Cast modulu Materials (vzor splitu materials.rb) — vola ju DemosFamily.create
# PO dokonceni vsetkych sietovych fetchov.
#
# Audit M-A BLOCKER 3: varianty AJ nakupne polia (kod/cena/URL/obrazok) vznikaju
# v JEDNEJ transakcii pod JEDNYM catalog lockom s JEDNYM write_unlocked —
# ziadny dvojzapis (v3 batch + apply), po ktorom by skupina mohla ostat
# poloprazdna. Vstupne polozky su uz OVERENE proti finalnym strankam
# (DemosFamily.verify — brand + dekor + slug typu), tu sa aj tak vsetko znovu
# validuje (server autorita, JS/orchestrator sa neveri).
#
# Kontrakty:
#   - ALL-OR-NOTHING: akakolvek nevalidna polozka = ziadny zapis.
#   - Existujuci variant (dedup) = 'skipped' — demos polia sa mu NEPREPISUJU
#     (MVP; aktualizacia existujucich = "Aktualizovat z Demosu").
#   - price_checked_at generuje SERVER a LEN pri zapisanej cene.
#   - duplicity kod+dodavatel sa kontroluju v SIMULOVANOM finalnom stave
#     (vzor apply_demos_batch preflight 2) — vycitaju sa LEN novym zaznamom.
#   - nova znackova skupina bez dosky = chyba (vyrobcu nesie doska, 7.5).

module Noxun
  module Engine
    module Materials
      module_function

      # attrs: {'manufacturer','decor','decor_name',
      #   'sheet_items'=>[{'type','thickness','structure','sheet_size',
      #                    'code','price','demos_url','image_url'}],
      #   'edge_items'=>[{'width','thickness','structure',
      #                   'code','price','demos_url'}]}
      # -> [:ok, {'group_id','sheets'=>[id],'edges'=>[id],'skipped'=>[label]}]
      #  | [:catalog_read_only|:invalid|:code_conflict|:write_failed, {'detail'=>}]
      def create_group_from_demos(attrs)
        return [:catalog_read_only, { 'detail' => catalog_read_only_message }] if catalog_read_only?
        a = attrs.is_a?(Hash) ? attrs : {}
        manufacturer = a['manufacturer'].to_s.strip
        decor = a['decor'].to_s.strip
        decor_name = a['decor_name'].to_s.strip
        if manufacturer.empty? || decor.empty?
          return [:invalid, { 'detail' => 'chýba výrobca alebo číslo dekoru zo stránky' }]
        end
        sheet_items = a['sheet_items'].is_a?(Array) ? a['sheet_items'] : []
        edge_items = a['edge_items'].is_a?(Array) ? a['edge_items'] : []
        if sheet_items.empty? && edge_items.empty?
          return [:invalid, { 'detail' => 'prázdny výber' }]
        end

        with_catalog_lock do
          JsonFileStore.invalidate(path)
          # Demos create je funkcia noveho katalogu — legacy (pred-migracny)
          # katalog ju nedostane (marker cerstvo pod zamkom, vzor v3 batchu).
          if catalog_schema_on_disk < SCHEMA_GROUPS
            return [:invalid, { 'detail' => 'katalóg je v pôvodnom formáte — zakladanie z Demosu vyžaduje nový katalóg' }]
          end
          ok_g, group = resolve_batch_group(manufacturer, decor, decor_name,
                                            prefer_existing_name: true)
          return [:invalid, { 'detail' => group }] unless ok_g
          if group['new'] && sheet_items.empty?
            return [:invalid, { 'detail' => 'nová skupina potrebuje aspoň jednu dosku (výrobcu nesie doska) — vyber aj dosku' }]
          end
          gid = group['group_id']
          gname = group['decor_name']
          data = load
          # GH #101 P2: nazov je vlastnost SKUPINY — ak existujuci clen skupiny
          # nazov nema (napr. skupina zalozena bez neho) a davka ho nesie,
          # doplni sa VSETKYM clenom v TEJ ISTEJ transakcii; skupina nikdy
          # neskonci s nekonzistentnym decor_name naprieč zaznamami.
          if !group['new'] && !gname.empty?
            (data['sheets'] + data['edges']).each do |r|
              next unless r['group_id'].to_s == gid
              r['decor_name'] = gname if r['decor_name'].to_s.strip.empty?
            end
          end
          stamp = Time.now.utc.iso8601
          taken = (data['sheets'].map { |s| s['material_id'].to_s.upcase } +
                   data['edges'].map { |e| e['abs_id'].to_s.upcase })
          created_sheets = []
          created_edges = []
          new_ids = {}
          skipped = []
          # GH #101 P1: dedup aj PROTI DAVKE SAMEJ — find_*_variant vidi len
          # katalog z disku, nie zaznamy prave pridavane do data. Dve polozky
          # vyberu s rovnakou identitou (dve Demos URL toho isteho variantu)
          # su chyba davky (vzor v3: ziadny tichy prvy-vyhrava).
          batch_sheet_keys = []
          batch_edge_keys = []

          sheet_items.each do |it|
            item = it.is_a?(Hash) ? it : {}
            vt = item['type'].to_s.strip
            th = strict_num(item['thickness'])
            unless !vt.empty? && th && th.positive?
              return [:invalid, { 'detail' => "doska „#{item['code']}“ nemá platný typ/hrúbku" }]
            end
            ok_size, size = parse_variant_size(item['sheet_size'], vt, th)
            return [:invalid, { 'detail' => size }] unless ok_size
            if format_in_identity?(vt) && size.nil?
              return [:invalid, { 'detail' => "variant #{vt} #{fmt_mm(th)} potrebuje formát platne (súčasť identity)" }]
            end
            code = item['code'].to_s.strip
            return [:invalid, { 'detail' => 'doska bez kódu sortimentu' }] if code.empty?
            structure = item['structure'].to_s.strip
            want = sheet_identity_key({ 'decor' => decor, 'type' => vt, 'thickness' => th,
                                        'structure' => structure, 'sheet_size' => size,
                                        'group_id' => gid, 'manufacturer' => manufacturer },
                                      SCHEMA_GROUPS)
            if batch_sheet_keys.any? { |k| identity_keys_tolerant?(k, want) }
              return [:invalid, { 'detail' => "dve vybrané položky sú ten istý variant (#{v3_sheet_label('type' => vt, 'structure' => structure, 'thickness' => th)}) — odškrtni jednu" }]
            end
            batch_sheet_keys << want
            if find_sheet_variant(decor, vt, th, structure, size,
                                  group_id: gid, manufacturer: manufacturer)
              skipped << v3_sheet_label('type' => vt, 'structure' => structure, 'thickness' => th)
              next
            end
            src = {
              'material_id' => generate_sheet_id(decor, vt, th, structure: structure,
                                                 sheet_size: size, taken: taken,
                                                 schema: SCHEMA_GROUPS),
              'family' => "#{manufacturer} #{decor}".strip,
              'manufacturer' => manufacturer, 'decor' => decor, 'type' => vt,
              'thickness' => th, 'grain' => 'length', 'sheet_size' => size,
              'group_id' => gid, 'decor_name' => gname, 'structure' => structure,
              'code' => code, 'supplier' => 'Demos',
              'price_per_m2' => normalize_price(item['price']),
              'demos_url' => sanitized_demos_url(item['demos_url']),
              'image_url' => item['image_url']
            }
            src['price_checked_at'] = stamp if src['price_per_m2']
            ok_v, verr = validate_sheet_attrs(src)
            return [:invalid, { 'detail' => verr }] unless ok_v
            rec = normalize_sheet(src)
            return [:invalid, { 'detail' => 'doska sa nedá uložiť' }] if rec.nil?
            taken << rec['material_id'].upcase
            data['sheets'] << rec
            created_sheets << rec['material_id']
            new_ids[rec['material_id']] = true
          end

          edge_items.each do |it|
            item = it.is_a?(Hash) ? it : {}
            w = strict_num(item['width'])
            th = strict_num(item['thickness'])
            unless w && EDGE_WIDTH_RANGE.cover?(w)
              return [:invalid, { 'detail' => "šírka ABS „#{item['width']}“ musí byť 10–200 mm" }]
            end
            unless th && supported_edge_thickness?(th, SCHEMA_GROUPS)
              return [:invalid, { 'detail' => "hrúbka ABS „#{item['thickness']}“ musí byť #{edge_thickness_options_label(SCHEMA_GROUPS)} mm" }]
            end
            code = item['code'].to_s.strip
            return [:invalid, { 'detail' => 'ABS páska bez kódu sortimentu' }] if code.empty?
            structure = item['structure'].to_s.strip
            want = edge_identity_key({ 'decor' => decor, 'width' => w, 'thickness' => th,
                                       'structure' => structure, 'group_id' => gid },
                                     SCHEMA_GROUPS)
            if batch_edge_keys.any? { |k| identity_keys_tolerant?(k, want) }
              return [:invalid, { 'detail' => "dve vybrané pásky sú ten istý variant (ABS #{v3_edge_label('width' => w, 'thickness' => th, 'structure' => structure)}) — odškrtni jednu" }]
            end
            batch_edge_keys << want
            if find_edge_variant(decor, w, th, structure, group_id: gid)
              skipped << "ABS #{v3_edge_label('width' => w, 'thickness' => th, 'structure' => structure)}"
              next
            end
            src = {
              'abs_id' => generate_edge_id(decor, th, w, structure: structure, taken: taken),
              'decor' => decor, 'thickness' => th, 'width' => w,
              'group_id' => gid, 'decor_name' => gname, 'structure' => structure,
              'code' => code, 'supplier' => 'Demos',
              'price_per_bm' => normalize_price(item['price']),
              'demos_url' => sanitized_demos_url(item['demos_url'])
            }
            src['price_checked_at'] = stamp if src['price_per_bm']
            ok_v, verr = validate_edge_attrs(src)
            return [:invalid, { 'detail' => verr }] unless ok_v
            rec = normalize_edge(src)
            return [:invalid, { 'detail' => 'ABS páska sa nedá uložiť' }] if rec.nil?
            taken << rec['abs_id'].upcase
            data['edges'] << rec
            created_edges << rec['abs_id']
            new_ids[rec['abs_id']] = true
          end

          if created_sheets.empty? && created_edges.empty?
            # Vsetko uz v katalogu je — legitimne (nie chyba), ziadny zapis.
            return [:ok, { 'group_id' => gid, 'sheets' => [], 'edges' => [],
                           'skipped' => skipped }]
          end

          # Duplicity kod+dodavatel v SIMULOVANOM finalnom stave — vycitaju sa
          # LEN zaznamom tejto davky (existujuce vedome duplicity nekolabuju).
          if (conflict = demos_create_code_conflict(data, new_ids))
            return [:code_conflict, { 'detail' => conflict }]
          end

          return [:write_failed, {}] unless write_unlocked(data)
          [:ok, { 'group_id' => gid, 'sheets' => created_sheets,
                  'edges' => created_edges, 'skipped' => skipped }]
        end
      end

      # demos_url pre create: sanitize alebo nil (polozka bez URL vazby je
      # legalna — normalize kluc vynecha; kod/cena ostavaju).
      def sanitized_demos_url(raw)
        return nil if raw.to_s.strip.empty?
        clean, = Demos.sanitize_url(raw)
        clean
      end

      # M-A3b D-59: kod polozky rodiny uz v katalogu je? INFORMATIVNY UX flag
      # (riadok sa oznaci, checkbox ostava aktivny — rozhodnutie Michal 1.8.
      # po audite: zamknutie by pri kolizii kodov blokovalo legitimnu polozku).
      # Autoritou dedupu ostava variantova identita pri zapise (skipped).
      # Match: rovnaky druh + kod (ci) + dodavatel Demos alebo prazdny.
      def demos_code_known?(kind, code)
        c = code.to_s.strip.downcase
        return false if c.empty?
        list = kind == 'edge' ? edges : sheets
        list.any? do |r|
          r['code'].to_s.strip.downcase == c &&
            ['', 'demos'].include?(r['supplier'].to_s.strip.downcase)
        end
      end

      # M-A3b D-60 (audit BLOCKER 2): cielova URL "Otvorit u dodavatela" —
      # VYHRADNE zo zaznamu katalogu a VZDY cez cerstvy sanitize (genericke
      # save cesty demos_url nevaliduju — poskodeny/cudzi zaznam sa neotvori).
      def demos_open_target(kind, id)
        rec = kind == 'edge' ? edge(id) : sheet(id)
        return nil unless rec
        raw = rec['demos_url'].to_s
        return nil if raw.empty?
        clean, = Demos.sanitize_url(raw)
        clean
      end

      # M-A3e D-71: rucne zadana vazba z formulara variantu (ceruzka).
      # Vrati [:ok, clean|nil, invalidate] | [:invalid, msg].
      #   prazdny vstup  -> [:ok, nil, true ak vazba existovala]  (vedome zmazanie)
      #   zly host/tvar  -> [:invalid, ...]                        (save sa ODMIETNE)
      #   platna adresa  -> [:ok, clean, true ak je to INY produkt nez doteraz]
      # invalidate = price_checked_at prestava platit (cena nie je overena voci
      # novej/ziadnej adrese — vzor HW katalogu). Audit FIX 3: porovnava sa
      # KANONICKY produkt (host+cesta bez query/fragmentu a koncovej lomky) —
      # dopisane ?utm ci lomka nie su zmena vazby a datum overenia preziju;
      # ULOZI sa vzdy sanitize vystup tak, ako ho pouzivatel dal.
      def manual_demos_url(raw, existing_url)
        s = raw.to_s.strip
        if s.empty?
          return [:ok, nil, !existing_url.to_s.strip.empty?]
        end
        clean, err = Demos.sanitize_url(s)
        return [:invalid, "adresa nie je produktová stránka demos-trade.sk (#{err})"] unless clean
        prev, = Demos.sanitize_url(existing_url.to_s)
        [:ok, clean, canonical_demos_product(clean) != canonical_demos_product(prev)]
      end

      # Kanonicka identita produktu za URL — LEN na porovnanie (nie na zapis).
      def canonical_demos_product(url)
        return nil if url.to_s.empty?
        uri = URI.parse(url)
        "#{uri.host.to_s.downcase}#{uri.path.to_s.chomp('/')}"
      rescue StandardError
        url
      end

      # Pary kod+dodavatel po zapise davky; konflikt = par s 2+ zaznamami,
      # z ktorych aspon jeden je NOVY. Vrati zoznam id vinnikov alebo nil.
      def demos_create_code_conflict(data, new_ids)
        [%w[sheets material_id], %w[edges abs_id]].each do |(listk, idk)|
          pairs = {}
          data[listk].each do |r|
            c = r['code'].to_s.strip.downcase
            next if c.empty?
            (pairs["#{c}|#{r['supplier'].to_s.strip.downcase}"] ||= []) << r[idk].to_s
          end
          pairs.each_value do |ids|
            next unless ids.length > 1
            return ids if ids.any? { |id| new_ids[id] }
          end
        end
        nil
      end
    end
  end
end
