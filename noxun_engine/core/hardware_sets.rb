# frozen_string_literal: true
# Noxun Engine — V0.6 D1: sety kovania (mapovanie genericky typ -> zoznam Demos kodov).
#
# ============================ ARCHITEKTURA ============================
# Faza 2 kovania (standard 6.2): pravidla (hardware_rules) daju GENERIKU
# (hinge x6 s ownerom, slide s params.nominal_length...), set ju prelozi na
# KODY katalogu (hardware_catalog) s pomermi. Set NIE JE polozka katalogu —
# je to mapovacie pravidlo (zamknute rozhodnutie, debata 2.8.2026,
# SYSTEM/09_POJMY.md "Kovanie — sety").
#
# TVAR SETU:
#   { "set_id": "zaves-klasik",            # slug identita, NEMENNA
#     "name": "Záves KLASIK (Sensys 110°)",
#     "generic_type": "hinge",             # BuildPlan::GENERIC_TYPES
#     "members": [
#       { "code": "104717", "per": "unit",  "qty": 1, "label": "záves" },
#       { "code": "250831", "per": "owner", "qty": 1, "label": "TipOn" },
#       { "per": "unit", "qty": 1, "code_by_nl": { "420": "357695" } } ] }
#
# Clen setu (audit F10 — prisnejsie nez BuildPlan params kontrakt):
#   per  'unit'  -> celkovy pocet = quantity polozky * qty (zaves: 4 kody 1:1:1:1)
#   per  'owner' -> qty NA VLASTNIKA polozky bez ohladu na quantity (TipOn 1x
#                   na dvierka aj pri 2-5 zavesoch); dedup (cabinet, owner,
#                   set, code) — dve pravidla na jednom vlastnikovi nesmu
#                   zdvojit clena (audit B3)
#   code XOR code_by_nl — rad podla params['nominal_length'] (vysuvy; fit_series
#   NL uz pocita). Kluc mapy = cele mm ako string ("420"); NL mimo mapy =
#   nemapovane (ORANGE), NIKDY sa neberie susedny kod (audit F10).
#
# ====================== ZDROJE A REPRODUKOVATELNOST ===================
# 1) GLOBALNA kniznica %APPDATA%\NOXUN\Engine\hardware_sets.json (+.bak, seed) =
#    default pre NOVE projekty: { std, seed_version, sets: [], mapping: {} }.
# 2) PROJEKTOVY SNAPSHOT: NOXUN dict na MODELI, kluc 'hardware_sets' —
#    { std, mapping: {generic_type => set_id}, sets: {set_id => definicia} }.
#    Snapshot drzi mapping ∪ VSETKY overridnute sety (audit B2 — zapis
#    cabinet override vklada definiciu setu do snapshotu v TEJ ISTEJ
#    operacii). Zmena globalnych setov NIKDY ticho nemeni stary projekt.
#    Stavy citania (audit F9): chybajuci snapshot = :missing (legitimne len
#    novy projekt -> ensure zapise global default), poskodeny = :invalid
#    (ORANGE, bez mapovania — NIKDY tichy fallback na dnesny global).
# 3) Cabinet override: config kluc 'hardware_sets' = {generic_type => set_id}
#    (round-trip cez normalize/cabinet_config — audit B1).
#
# Expand je CISTA funkcia (ziadne IO/SketchUp) — headless testovatelna;
# vstup = raw hardware z Bom.collect (s owner_id), NIE agregovany BOM
# (audit F6 — per-owner clen potrebuje vlastnika).
require 'json'

module Noxun
  module Engine
    module HardwareSets
      STD          = 1
      SEED_VERSION = 1
      FILE         = 'hardware_sets.json'
      MODEL_KEY    = 'hardware_sets' # kluc snapshotu v NOXUN dict na modeli

      PER_KINDS = %w[unit owner].freeze

      # Seed sety = zavery debaty 2.8.2026 (09_POJMY "Kovanie — sety");
      # kody = SYSTEM/zdroje/SEED_KATALOG_2026-07.md §2. Atira rad nesie LEN
      # dolozene kody (420/470) — ostatne NL = ORANGE, kody doplni Michal/D2.
      SEED_SETS = [
        { 'set_id' => 'zaves-klasik', 'name' => 'Záves KLASIK (Sensys 110° SiSy)',
          'generic_type' => 'hinge',
          'members' => [
            { 'code' => '104717', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' },
            { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
            { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
            { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' }
          ] },
        { 'set_id' => 'zaves-p2o', 'name' => 'Záves P2O + TipOn (bez tlmenia)',
          'generic_type' => 'hinge',
          'members' => [
            { 'code' => '245723', 'per' => 'unit', 'qty' => 1, 'label' => 'záves P2O' },
            { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
            { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
            { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' },
            { 'code' => '250831', 'per' => 'owner', 'qty' => 1, 'label' => 'TipOn na dvierka' }
          ] },
        { 'set_id' => 'nohy-klzak-17', 'name' => 'Klzák s rektifikáciou 17 mm',
          'generic_type' => 'leg',
          'members' => [{ 'code' => '82744', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'nohy-axilo-150', 'name' => 'Noha AXILO 150 mm',
          'generic_type' => 'leg',
          'members' => [{ 'code' => '367823', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'vysuv-atira-biela-h70', 'name' => 'Atira biela H70 (rad podľa NL)',
          'generic_type' => 'slide',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '420' => '357695', '470' => '357696' } }
          ] },
        { 'set_id' => 'zavesenie-bystrica', 'name' => 'Zavesenie na stenu „Bystrica"',
          'generic_type' => 'wall_hanger',
          'members' => [{ 'code' => '93240', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'podperky-police', 'name' => 'Podperka policová 7/5',
          'generic_type' => 'shelf_pin',
          'members' => [{ 'code' => '306125', 'per' => 'unit', 'qty' => 1 }] }
      ].freeze

      # Default mapovanie novych projektov: handle/connector vedome BEZ setu
      # (uchytky sa v D neriesia — Michal 2.8.; connector pravidlo neexistuje).
      SEED_MAPPING = {
        'hinge'       => 'zaves-klasik',
        'leg'         => 'nohy-klzak-17',
        'slide'       => 'vysuv-atira-biela-h70',
        'wall_hanger' => 'zavesenie-bystrica',
        'shelf_pin'   => 'podperky-police'
      }.freeze

      module_function

      # --- globalna kniznica (%APPDATA%) --------------------------------------

      def dir
        Materials.dir # zdielany %APPDATA%/NOXUN/Engine (+ test_dir_override)
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita globalnu kniznicu { 'sets' => [], 'mapping' => {} }. Poskodeny/
      # chybajuci subor -> seed (fallback nikdy nevrati nil). Seed-merge ako
      # HardwareRules: novsi SEED_VERSION doplni CHYBAJUCE set_id (bez prepisu
      # pouzivatelskych uprav) — plati LEN pre global; projektovy snapshot sa
      # NIKDY nemeni sam.
      def load
        ensure_seeded
        doc = JsonFileStore.read(path, copy: false)
        sets = doc.is_a?(Hash) ? normalize_sets(doc['sets']) : []
        mapping = doc.is_a?(Hash) ? normalize_mapping(doc['mapping'], sets) : {}
        return { 'sets' => deep_copy(SEED_SETS), 'mapping' => SEED_MAPPING.dup } if sets.empty?
        merged, changed = merge_seed(sets, doc['seed_version'].to_i)
        if changed && write(merged, mapping)
          Engine.log('hardware sets: globalna kniznica doplnena o nove default sety') if defined?(Engine)
        end
        { 'sets' => merged, 'mapping' => mapping }
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.load') if defined?(Engine)
        { 'sets' => deep_copy(SEED_SETS), 'mapping' => SEED_MAPPING.dup }
      end

      def merge_seed(sets, from_version)
        return [sets, false] if from_version >= SEED_VERSION
        have = {}
        sets.each { |s| have[s['set_id']] = true }
        missing = SEED_SETS.reject { |s| have[s['set_id']] }
        [sets + normalize_sets(missing), true]
      end

      def ensure_seeded
        return if JsonFileStore.available?(path)
        write(deep_copy(SEED_SETS), SEED_MAPPING.dup)
      end

      def write(sets, mapping)
        norm = normalize_sets(sets)
        JsonFileStore.write(path, { 'std' => STD, 'seed_version' => SEED_VERSION,
                                    'sets' => norm,
                                    'mapping' => normalize_mapping(mapping, norm) })
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.write') if defined?(Engine)
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- projektovy snapshot (NOXUN dict na modeli) --------------------------

      # Stav snapshotu (audit F9): [:ok, state] | [:missing, nil] | [:invalid, nil].
      # :invalid NIKDY nesmie viest na globalnu kniznicu — volajuci mapuje na
      # ORANGE "sety projektu su poskodene" a expanzia bezi bez mapovania.
      def project_state_status(model)
        return [:missing, nil] unless model
        raw = model.get_attribute(Store::DICT, MODEL_KEY)
        return [:missing, nil] if raw.nil? || raw.to_s.strip.empty?
        doc = JSON.parse(raw.to_s)
        return [:invalid, nil] unless doc.is_a?(Hash)
        sets_map = doc['sets'].is_a?(Hash) ? doc['sets'] : nil
        mapping  = doc['mapping'].is_a?(Hash) ? doc['mapping'] : nil
        return [:invalid, nil] if sets_map.nil? || mapping.nil?
        sets = normalize_sets(sets_map.values)
        by_id = {}
        sets.each { |s| by_id[s['set_id']] = s }
        [:ok, { 'mapping' => normalize_mapping(mapping, sets), 'sets' => by_id }]
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.project_state_status') if defined?(Engine)
        [:invalid, nil]
      end

      # Snapshot projektu alebo nil (missing AJ invalid — na rozlisenie sluzi
      # project_state_status; citacie cesty bez modelu nemaju co mapovat).
      def project_state(model)
        status, state = project_state_status(model)
        status == :ok ? state : nil
      end

      # Vrati snapshot; ak chyba, zapise global default (mapping + namapovane
      # sety). VOLAT LEN vnutri otvorenej operacie (vzor ensure_project_rules!).
      # :invalid sa NEOPRAVUJE ticho — vrati nil, UI ponukne vedomu obnovu.
      def ensure_project_state!(model)
        status, state = project_state_status(model)
        return state if status == :ok
        return nil if status == :invalid
        lib = load
        by_id = {}
        lib['sets'].each { |s| by_id[s['set_id']] = s }
        mapping = {}
        sets = {}
        lib['mapping'].each do |gt, sid|
          next unless by_id[sid]
          mapping[gt] = sid
          sets[sid] = by_id[sid]
        end
        state = { 'mapping' => mapping, 'sets' => sets }
        write_project_state(model, state) if model
        state
      end

      # Zapise snapshot (volajuci drzi operaciu — undo vrati model aj sety).
      def write_project_state(model, state)
        return false unless model
        sets = state['sets'].is_a?(Hash) ? state['sets'] : {}
        doc = { 'std' => STD,
                'mapping' => state['mapping'].is_a?(Hash) ? state['mapping'] : {},
                'sets' => sets }
        model.set_attribute(Store::DICT, MODEL_KEY, doc.to_json)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HardwareSets.write_project_state') if defined?(Engine)
        false
      end

      # Zmeni projektove mapovanie JEDNEHO generickeho typu. set_def = plna
      # definicia (z globalu/editora) — vlozi sa do snapshotu v tom istom
      # zapise (audit B2: snapshot drzi kazdy referencovany set). set_id nil =
      # typ sa odmapuje (definicia v snapshote ostava pre historiu overridov).
      # Volajuci drzi operaciu.
      def set_project_mapping!(model, generic_type, set_id, set_def = nil)
        status, state = project_state_status(model)
        return false unless status == :ok || status == :missing
        state ||= { 'mapping' => {}, 'sets' => {} }
        gt = generic_type.to_s
        return false if gt.empty?
        if set_id.nil? || set_id.to_s.strip.empty?
          state['mapping'].delete(gt)
        else
          sid = set_id.to_s.strip
          norm = normalize_sets([set_def]).first
          return false if norm.nil? || norm['set_id'] != sid || norm['generic_type'] != gt
          state['mapping'][gt] = sid
          state['sets'][sid] = norm
        end
        write_project_state(model, state)
      end

      # Vlozi/aktualizuje definiciu setu v snapshote BEZ zmeny mapovania
      # (cabinet override na nenamapovany set — audit B2). Volajuci drzi operaciu.
      def add_project_set!(model, set_def)
        status, state = project_state_status(model)
        return false unless status == :ok || status == :missing
        state ||= { 'mapping' => {}, 'sets' => {} }
        norm = normalize_sets([set_def]).first
        return false if norm.nil?
        state['sets'][norm['set_id']] = norm
        write_project_state(model, state)
      end

      # --- expanzia (cista funkcia, audit F6) ----------------------------------

      # hardware_items: RAW polozky z Bom.collect — string kluce + 'owner_id'
      #   (cabinet id); owner_part_key/generic_type/quantity/rule_id/params.
      # state: projektovy snapshot {'mapping','sets'} alebo nil (= nic nemapuje).
      # cabinet_overrides: { cabinet_id => { generic_type => set_id } } z configov.
      # catalog: pole poloziek HardwareCatalog.items alebo mapa code=>item.
      # Vrati { 'rows' => [...], 'unmapped' => [...], 'summary' => {...} } —
      # deterministicke poradie (kategoria podla HardwareCatalog::CATEGORIES,
      # potom kod); ceny s DPH; nil cena = nezadana, subtotal nil, NIKDY 0.
      def expand(hardware_items, state, cabinet_overrides: {}, catalog: nil)
        mapping = state.is_a?(Hash) && state['mapping'].is_a?(Hash) ? state['mapping'] : {}
        sets    = state.is_a?(Hash) && state['sets'].is_a?(Hash) ? state['sets'] : {}
        lookup  = catalog_lookup(catalog)
        rows = {}
        unmapped = []
        owner_seen = {}
        Array(hardware_items).each do |it|
          next unless it.is_a?(Hash)
          gt  = it['generic_type'].to_s
          cid = it['owner_id'].to_s
          qty = it['quantity'].to_i
          next if gt.empty? || qty < 1
          sid = resolve_set_id(gt, cid, cabinet_overrides, mapping)
          if sid.nil?
            unmapped << unmapped_entry(it, nil, 'no_set')
            next
          end
          set = sets[sid]
          if set.nil?
            unmapped << unmapped_entry(it, sid, 'set_missing')
            next
          end
          expand_members(it, set, qty, rows, unmapped, owner_seen, lookup)
        end
        finalize(rows, unmapped)
      end

      # Poradie: cabinet override -> projektove mapovanie -> nil.
      def resolve_set_id(generic_type, cabinet_id, cabinet_overrides, mapping)
        ov = cabinet_overrides.is_a?(Hash) ? cabinet_overrides[cabinet_id] : nil
        sid = ov.is_a?(Hash) ? ov[generic_type] : nil
        sid = mapping[generic_type] if sid.nil? || sid.to_s.strip.empty?
        sid = sid.to_s.strip
        sid.empty? ? nil : sid
      end

      def expand_members(it, set, qty, rows, unmapped, owner_seen, lookup)
        sid = set['set_id']
        Array(set['members']).each do |m|
          code = member_code(m, it)
          if code == :nl_missing
            unmapped << unmapped_entry(it, sid, 'nl_missing')
            next
          end
          next if code.nil?
          m_qty = m['qty'].to_i
          total =
            if m['per'] == 'owner'
              # audit B3: 1x na (korpus, vlastnik, set, kod) — druhe pravidlo
              # s rovnakym vlastnikom TipOn nezdvoji.
              key = [it['owner_id'].to_s, it['owner_part_key'].to_s, sid, code].join('|')
              next if owner_seen[key]
              owner_seen[key] = true
              m_qty
            else
              qty * m_qty
            end
          add_row(rows, code, total, it, sid, lookup)
        end
      end

      # Kod clena: pevny 'code' alebo rad 'code_by_nl' podla params.nominal_length.
      # Vrati String | nil (clen sa preskoci — nevalidny) | :nl_missing (ORANGE).
      def member_code(member, it)
        if member['code_by_nl'].is_a?(Hash)
          params = it['params'].is_a?(Hash) ? it['params'] : {}
          nl = params['nominal_length']
          return :nl_missing unless nl.is_a?(Numeric) && nl.to_f.finite?
          code = member['code_by_nl'][Integer(nl.round).to_s]
          return :nl_missing if code.nil? || code.to_s.strip.empty?
          code.to_s.strip
        else
          c = member['code'].to_s.strip
          c.empty? ? nil : c
        end
      end

      def add_row(rows, code, quantity, it, sid, lookup)
        row = rows[code] ||= { 'code' => code, 'quantity' => 0, 'sources' => [] }
        row['quantity'] += quantity
        row['sources'] << {
          'cabinet_id' => it['owner_id'].to_s,
          'owner_part_key' => (it['owner_part_key'].nil? ? nil : it['owner_part_key'].to_s),
          'generic_type' => it['generic_type'].to_s,
          'rule_id' => it['rule_id'].to_s,
          'set_id' => sid,
          'quantity' => quantity
        }
        row_join(row, lookup)
      end

      def row_join(row, lookup)
        item = lookup[row['code'].downcase]
        if item.nil?
          row['missing'] = true
          row['name_sk'] = nil
          row['category'] = nil
          row['unit'] = nil
          row['price_eur_vat'] = nil
        else
          row['missing'] = false
          row['name_sk'] = item['name_sk']
          row['category'] = item['category']
          row['unit'] = item['unit']
          row['price_eur_vat'] = item['price_eur_vat']
        end
        row
      end

      def unmapped_entry(it, sid, reason)
        params = it['params'].is_a?(Hash) ? it['params'] : {}
        {
          'cabinet_id' => it['owner_id'].to_s,
          'owner_part_key' => (it['owner_part_key'].nil? ? nil : it['owner_part_key'].to_s),
          'generic_type' => it['generic_type'].to_s,
          'rule_id' => it['rule_id'].to_s,
          'quantity' => it['quantity'].to_i,
          'set_id' => sid,
          'reason' => reason,
          'nominal_length' => (params['nominal_length'].is_a?(Numeric) ? params['nominal_length'].to_f : nil)
        }
      end

      # Zoradenie + medzisucty. Cena nil = "nezadana" (subtotal nil, nikdy 0 —
      # audit N11); summary total scitava LEN zname ceny a nesie pocet neznamych.
      def finalize(rows, unmapped)
        cat_rank = {}
        if defined?(HardwareCatalog)
          HardwareCatalog::CATEGORIES.each_with_index { |c, i| cat_rank[c] = i }
        end
        list = rows.values.sort_by do |r|
          [r['missing'] ? 1 : 0, cat_rank.fetch(r['category'], 98) || 98, r['code']]
        end
        total = 0.0
        unknown = 0
        list.each do |r|
          price = r['price_eur_vat']
          if price.is_a?(Numeric) && r['missing'] == false
            r['subtotal_eur_vat'] = (price.to_f * r['quantity']).round(2)
            total += r['subtotal_eur_vat']
          else
            r['subtotal_eur_vat'] = nil
            unknown += 1
          end
        end
        {
          'rows' => list,
          'unmapped' => unmapped,
          'summary' => { 'rows' => list.length,
                         'quantity' => list.sum { |r| r['quantity'] },
                         'total_eur_vat' => total.round(2),
                         'unknown_prices' => unknown,
                         'unmapped' => unmapped.length }
        }
      end

      def catalog_lookup(catalog)
        out = {}
        if catalog.is_a?(Hash)
          catalog.each { |k, v| out[k.to_s.strip.downcase] = v if v.is_a?(Hash) }
        else
          Array(catalog).each do |item|
            next unless item.is_a?(Hash)
            code = item['item_code'].to_s.strip.downcase
            out[code] = item unless code.empty?
          end
        end
        out
      end

      # --- normalizacia a validacia (audit F10) --------------------------------

      # Ocisti pole setov; nevalidny set/clen sa ZAHADZUJE (log), nie polovicato
      # opravuje. Kody VZDY String (JSON cisla by znicili uvodne nuly), qty
      # kladny Integer, per enum, code XOR code_by_nl, owner bez NL mapy.
      def normalize_sets(sets)
        seen = {}
        Array(sets).filter_map do |set|
          next nil unless set.is_a?(Hash)
          s = deep_copy(stringify(set))
          sid = s['set_id'].to_s.strip
          next nil if sid.empty? || seen[sid]
          gt = s['generic_type'].to_s.strip
          next nil unless BuildPlan::GENERIC_TYPES.include?(gt)
          members = normalize_members(s['members'])
          next nil if members.empty?
          seen[sid] = true
          { 'set_id' => sid,
            'name' => (s['name'].to_s.strip.empty? ? sid : s['name'].to_s.strip),
            'generic_type' => gt,
            'members' => members }
        end
      end

      def normalize_members(members)
        Array(members).filter_map do |m|
          next nil unless m.is_a?(Hash)
          mm = stringify(m)
          per = mm['per'].to_s.strip
          per = 'unit' if per.empty?
          next nil unless PER_KINDS.include?(per)
          qty = mm['qty'].nil? ? 1 : mm['qty'].to_i
          next nil if qty < 1
          qty = [qty, BuildPlan::MAX_HW_QUANTITY].min
          has_code = !mm['code'].to_s.strip.empty?
          has_map  = mm['code_by_nl'].is_a?(Hash) && !mm['code_by_nl'].empty?
          next nil if has_code == has_map # XOR: prave jedno z dvojice
          next nil if has_map && per == 'owner' # rad je per jednotka (vysuvy)
          out = { 'per' => per, 'qty' => qty }
          label = mm['label'].to_s.strip
          out['label'] = label unless label.empty?
          if has_code
            out['code'] = mm['code'].to_s.strip
          else
            map = {}
            mm['code_by_nl'].each do |k, v|
              nl = begin
                Integer(k.to_s.strip, 10)
              rescue ArgumentError, TypeError
                nil
              end
              code = v.to_s.strip
              next if nl.nil? || nl < 1 || code.empty?
              map[nl.to_s] = code
            end
            next nil if map.empty?
            out['code_by_nl'] = map
          end
          out
        end
      end

      # Mapovanie: len zname genericke typy; set_id neprazdny String. Vazbu na
      # existujuci set kontroluje volajuci (global write prijme mapovanie len
      # na sety kniznice; snapshot si konzistenciu drzi cez set_project_mapping!).
      def normalize_mapping(mapping, sets = nil)
        return {} unless mapping.is_a?(Hash)
        ids = sets.nil? ? nil : sets.map { |s| s['set_id'] }
        out = {}
        mapping.each do |gt, sid|
          g = gt.to_s.strip
          s = sid.to_s.strip
          next unless BuildPlan::GENERIC_TYPES.include?(g)
          next if s.empty?
          next if ids && !ids.include?(s)
          out[g] = s
        end
        out
      end

      def stringify(h)
        h.each_with_object({}) do |(k, v), out|
          out[k.to_s] = v.is_a?(Hash) ? stringify(v) : v
        end
      end

      def deep_copy(obj)
        JsonFileStore.deep_copy(obj)
      end
    end
  end
end
