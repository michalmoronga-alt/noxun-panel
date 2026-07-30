# frozen_string_literal: true
# Noxun Engine — materialovy katalog: JEDNORAZOVA migracia na SCHEMA 2 (davka
# 2A-2, standard 7.1). Cast modulu Materials (rovnaky module_function vzor ako
# ostatne materials_*.rb) — pozri materials.rb pre prehlad.
#
# DORMANTNY ENGINE (kontrakt davky 2A-2): tuto migraciu NEVOLA ziadna produkcna
# cesta — ziadne menu, ziadny auto-run pri boote. Existuje len Ruby API
# `Materials.migrate_to_schema2!` + testy nad izolovanymi kopiami katalogu.
# Ostry cutover (auto-run + MD_CLIENT_SCHEMA=2 + seedy v schema 2) je az 2A-4.
#
# Principy (zavazne nalezy Codex auditu B1/B3 + F4/F5/F8/F9 + O1-O8):
#   - SUROVE citanie suboru (File.binread + JSON.parse) — NIKDY nie cez
#     load/catalog (load seeduje a normalizery ticho menia data).
#   - Explicitna KANONICKA mapa (Michal schvalil 30.7.2026); heuristika je len
#     fallback s reportom. Kluce mapy = identity_norm(decor) zivych zaznamov.
#   - JEDINA nerozhodnutelna polozka = atomicky NO-OP celej migracie (ziadny
#     ciastocny/hybridny zapis; report vypise dovody).
#   - group_id je deterministicky OPAQUE hash obchodnej identity skupiny a po
#     vzniku NAVZDY zmrazeny — buduce rename skupiny ho NIKDY neprepocitava.
#   - Ostry beh: nemenna predmigracna zaloha (existujuca platna sa NEprepisuje)
#     -> CAS kontrola bajtov (subezna zmena z ineho procesu = :conflict)
#     -> atomicky zapis so schema markerom 2 -> reload cache.
require 'digest'

module Noxun
  module Engine
    module Materials
      # --- 2A-2: KANONICKA migracna mapa (Michal 30.7.2026 — nemenit) ----------
      # Kluc = identity_norm(decor) dnesneho zaznamu (O5). Hodnota = cielove
      # skupinove polia; PRAZDNA/chybajuca hodnota znamena "kluc sa NEZAPISE"
      # (FIX 11, O3 — ziadny text "vlastny" do dat). 'manufacturer' sa aplikuje
      # LEN na doskach, na ABS NIKDY (FIX 7, O2). Obidva HALIFAX kluce cielia na
      # TU ISTU skupinu (vlastny . Halifax Tabakovy) => spolocny group_id.
      MIGRATION_MAP = {
        'K009 PW' => { 'manufacturer' => 'Kronospan', 'decor' => 'K009', 'structure' => 'PW' },
        'BIELA HDF' => { 'manufacturer' => 'Kronospan', 'decor' => 'Biela HDF' },
        'W1000 ST9 BIELA' => { 'manufacturer' => 'Egger', 'decor' => 'W1000',
                               'decor_name' => 'Biela', 'structure' => 'ST9' },
        'U750 ST9 TAUPE ŠEDÁ' => { 'manufacturer' => 'Egger', 'decor' => 'U750',
                                   'decor_name' => 'Taupe šedá', 'structure' => 'ST9' },
        'H1180 ST37 DUB HALIFAX PRÍRODNÝ' => { 'manufacturer' => 'Egger', 'decor' => 'H1180',
                                               'decor_name' => 'Dub Halifax prírodný',
                                               'structure' => 'ST37' },
        '5981 MG CASHMERE' => { 'manufacturer' => 'Kronospan', 'decor' => '5981',
                                'decor_name' => 'Cashmere', 'structure' => 'MG' },
        'BIELA KORPUS' => { 'decor' => 'Biela korpus' },
        'UNI' => { 'decor' => 'UNI' },
        'HALIFAX TABAKOVÝ PD' => { 'decor' => 'Halifax Tabakový' },
        'HALIFAX TABAKOVÝ' => { 'decor' => 'Halifax Tabakový' }
      }.freeze

      # Jedine mazane ID migracie (osirotena paska bez dosky — Michal schvalil).
      # FIX 5: pred mazanim sa overuje OBSAH zaznamu (viz delete_expectation_ok?)
      # — iny obsah pod tym istym ID = NEROZHODNUTELNA polozka, nie slepy zasah.
      MIGRATION_DELETE_EDGE_IDS = ['ABS_PRACOVNA_DOSKA_10'].freeze

      # Merge Halifaxu: PD doska bola pred D-44 zalozena ako DTDL (obchadzka).
      # Dostane typ PD => format platne [4200, 600] sa stava sucastou identity
      # variantu (O8). ID zaznamu sa NEMENI.
      MIGRATION_RETYPE = { 'HALIFAX_TABAKOVY_PD_DTDL_38' => 'PD' }.freeze

      # Polia SCHEMA 2, ktore sa v LEGACY zazname nesmu vyskytovat (hybrid =
      # rucne ohnuty subor => undecidable; 'universal' je vedomy 2A-1 priznak
      # vyberu a hybridom nie je).
      MIGRATION_HYBRID_KEYS = %w[group_id structure decor_name].freeze

      # Salt hashu skupiny (O6). NIKDY nemenit — zmena by prepocitala group_id
      # existujucich katalogov a rozbila vazby.
      GROUP_ID_SALT = 'noxun-group-v2'

      module_function

      # Deterministicky OPAQUE identifikator skupiny (O6): rovnaky vysledok
      # v dry-run aj ostro, na kazdom stroji. 16 hex znakov = 64 bitov; kolizie
      # navyse strazi register_migration_group (prakticky nemozne, kontrola lacna).
      def group_id_for(manufacturer, decor)
        digest = Digest::SHA256.hexdigest(
          "#{GROUP_ID_SALT}|#{identity_norm(manufacturer)}|#{identity_norm(decor)}"
        )
        "GRP-#{digest[0, 16].upcase}"
      end

      # Jednorazova migracia katalogu SCHEMA 1 -> SCHEMA 2.
      #   dry_run: true  = len report, ziadny subor sa nezmeni (ani zaloha).
      #   before_write   = VYHRADNE testy (CAS scenar): lambda zavolana tesne
      #                    pred CAS kontrolou; produkcia NIKDY neposiela.
      # Vrati report (symbol kluce):
      #   { status:, dry_run:, groups: [{group_id:, manufacturer:, decor:,
      #     decor_name:, sheets:, edges:}], fallback: [{id:, decor:, group_id:}],
      #     deleted: [id], retyped: [id], reasons: [text], warnings: [text] }
      # Statusy: :ok | :not_found | :empty | :already | :invalid_schema2 |
      #   :newer_schema | :undecidable | :backup_corrupt | :backup_failed |
      #   :conflict | :write_failed
      def migrate_to_schema2!(dry_run: false, before_write: nil)
        report = { status: :ok, dry_run: !!dry_run, groups: [], fallback: [],
                   deleted: [], retyped: [], reasons: [], warnings: [] }
        file = path
        # O4: chybajuci subor NIKDY neseeduje a nic nezapisuje.
        return report.merge(status: :not_found) unless File.exist?(file)

        original_bytes = File.binread(file)
        parsed = parse_migration_json(original_bytes, report)
        return report unless parsed

        gate = migration_schema_gate(parsed)
        return report.merge(status: gate) if gate

        sheets_raw = parsed['sheets']
        edges_raw = parsed['edges']
        unless sheets_raw.is_a?(Array) && edges_raw.is_a?(Array)
          report[:status] = :undecidable
          report[:reasons] << 'sheets/edges nie su polia zaznamov'
          return report
        end
        return report.merge(status: :empty) if sheets_raw.empty? && edges_raw.empty?

        reasons = []
        validate_legacy_records(sheets_raw, edges_raw, reasons)
        check_delete_expectations(edges_raw, reasons)
        check_retype_expectations(sheets_raw, reasons)
        plan = reasons.empty? ? build_migration_plan(sheets_raw, edges_raw, reasons) : nil
        unless reasons.empty?
          report[:status] = :undecidable
          report[:reasons] = reasons
          return report
        end

        report[:groups] = plan[:groups]
        report[:fallback] = plan[:fallback]
        report[:deleted] = plan[:deleted]
        report[:retyped] = plan[:retyped]
        # O7: best-effort vyuzitie mazanych ID (model + sablony) — LEN varovanie,
        # neblokuje; mimo SketchUpu (pure testy) sekcia ticho chyba.
        report[:warnings] = deleted_usage_warnings(plan[:deleted])
        return report if dry_run

        # a) nemenna predmigracna zaloha (FIX 4): existujuca PLATNA sa neprepisuje.
        backup = ensure_pre_schema2_backup
        return report.merge(status: backup) unless backup == :ok

        before_write.call if before_write # VYHRADNE testy — CAS scenar
        # b) CAS kontrola (BLOCKER 3): subezna zmena z CEF/druheho procesu sa
        #    NESMIE prepisat — bajty musia sediet s prvym citanim.
        return report.merge(status: :conflict) if File.binread(file) != original_bytes

        # c) atomicky zapis so schema markerom 2 (write cita schemu z hashu,
        #    FIX 10) + invalidacia cache.
        ok = write('sheets' => plan[:sheets], 'edges' => plan[:edges],
                   'schema' => SCHEMA_GROUPS)
        return report.merge(status: :write_failed) unless ok
        reload!
        report
      end

      # --- krok 1: surove citanie -------------------------------------------

      def parse_migration_json(bytes, report)
        parsed = JSON.parse(bytes)
        return parsed if parsed.is_a?(Hash)
        report[:status] = :undecidable
        report[:reasons] << 'materials.json nema tvar objektu {sheets, edges}'
        nil
      rescue StandardError => e
        report[:status] = :undecidable
        report[:reasons] << "materials.json nie je platny JSON: #{e.message}"
        nil
      end

      # --- krok 2: schema brana (FIX 9) -------------------------------------

      # Vrati status-symbol, ktory migraciu ukonci, alebo nil (pokracuj).
      def migration_schema_gate(parsed)
        marker = migration_schema_marker(parsed)
        return :newer_schema if marker > SCHEMA_GROUPS
        return nil if marker < SCHEMA_GROUPS
        schema2_complete?(parsed['sheets'], parsed['edges']) ? :already : :invalid_schema2
      end

      # Marker zo suboru — rovnaka semantika ako catalog_schema (chybajuci/
      # poskodeny = 1), ale nad UZ naparsovanym surovym obsahom.
      def migration_schema_marker(parsed)
        n = parsed['schema'].to_i
        n >= SCHEMA_LEGACY ? n : SCHEMA_LEGACY
      rescue StandardError
        SCHEMA_LEGACY
      end

      # Marker 2 je poctivy len vtedy, ked KAZDY zaznam nesie group_id.
      def schema2_complete?(sheets_raw, edges_raw)
        return false unless sheets_raw.is_a?(Array) && edges_raw.is_a?(Array)
        (sheets_raw + edges_raw).all? do |rec|
          rec.is_a?(Hash) && !rec['group_id'].to_s.strip.empty?
        end
      end

      # --- krok 3: surova validacia zaznamov (FIX 5, BEZ normalize_*) --------

      def validate_legacy_records(sheets_raw, edges_raw, reasons)
        seen = {}
        sheets_raw.each_with_index do |rec, i|
          validate_legacy_record(rec, "sheets[#{i}]", 'material_id', seen, reasons) do |r, label|
            reasons << "#{label}: typ nie je text" unless r['type'].is_a?(String)
            if r.key?('sheet_size') && !migration_pair?(r['sheet_size'])
              reasons << "#{label}: sheet_size musi byt dvojica kladnych cisel"
            end
          end
        end
        seen = {}
        edges_raw.each_with_index do |rec, i|
          validate_legacy_record(rec, "edges[#{i}]", 'abs_id', seen, reasons) do |r, label|
            if r.key?('width') && !migration_positive?(r['width'])
              reasons << "#{label}: width musi byt kladne cislo"
            end
          end
        end
      end

      # Spolocna kostra: Hash, neprazdne unikatne ID, neprazdny dekor, kladna
      # konecna hrubka, ziadny SCHEMA 2 hybrid. Specifika druhu doda blok.
      def validate_legacy_record(rec, pos_label, id_key, seen, reasons)
        unless rec.is_a?(Hash)
          reasons << "#{pos_label}: nie je zaznam"
          return
        end
        id = rec[id_key].to_s.strip
        label = id.empty? ? pos_label : id
        if id.empty?
          reasons << "#{label}: prazdne #{id_key}"
        elsif seen[id.upcase]
          reasons << "#{label}: duplicitne #{id_key}"
        else
          seen[id.upcase] = true
        end
        reasons << "#{label}: prazdny dekor" if rec['decor'].to_s.strip.empty?
        reasons << "#{label}: hrubka musi byt kladne cislo" unless migration_positive?(rec['thickness'])
        hybrid = MIGRATION_HYBRID_KEYS.select { |k| rec.key?(k) }
        reasons << "#{label}: legacy zaznam uz nesie SCHEMA 2 polia (#{hybrid.join(', ')})" if hybrid.any?
        yield(rec, label)
      end

      def migration_positive?(v)
        v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive?
      end

      def migration_pair?(v)
        v.is_a?(Array) && v.size == 2 && v.all? { |x| migration_positive?(x) }
      end

      # --- krok 3b: ocakavania delete/retype (FIX 5) -------------------------

      # Chybajuce ID = nie je co mazat/retypovat (katalog sa mohol vyvijat) —
      # preskoci sa. PRITOMNE ID s inym obsahom = undecidable, nie slepy zasah.
      def check_delete_expectations(edges_raw, reasons)
        MIGRATION_DELETE_EDGE_IDS.each do |id|
          rec = edges_raw.find { |r| r.is_a?(Hash) && r['abs_id'].to_s == id }
          next unless rec
          ok = identity_norm(rec['decor']) == 'PRACOVNA DOSKA' &&
               edge_width(rec).nil? &&
               migration_close?(rec['thickness'], 1.0)
          next if ok
          reasons << "#{id}: obsah nesedi s ocakavanim mazania (dekor 'Pracovna doska', bez sirky, 1,0 mm)"
        end
      end

      def check_retype_expectations(sheets_raw, reasons)
        MIGRATION_RETYPE.each_key do |id|
          rec = sheets_raw.find { |r| r.is_a?(Hash) && r['material_id'].to_s == id }
          next unless rec
          ok = identity_norm(rec['type']) == 'DTDL' &&
               migration_close?(rec['thickness'], 38.0) &&
               identity_keys_tolerant?(size_key(rec['sheet_size']), size_key([4200.0, 600.0]))
          next if ok
          reasons << "#{id}: obsah nesedi s ocakavanim retype DTDL->PD (38 mm, format 4200x600)"
        end
      end

      def migration_close?(value, want)
        value.is_a?(Numeric) && (value.to_f - want).abs <= 0.01
      end

      # --- krok 4-8: transformacia + validacia celku -------------------------

      # Vrati plan { sheets:, edges:, groups:, fallback:, deleted:, retyped: }.
      # KAZDY problem ide do reasons — volajuci pri neprazdnych reasons plan
      # zahodi (atomicky no-op, ziadny ciastocny zapis).
      def build_migration_plan(sheets_raw, edges_raw, reasons)
        deleted = edges_raw.select { |r| MIGRATION_DELETE_EDGE_IDS.include?(r['abs_id'].to_s) }
                           .map { |r| r['abs_id'].to_s }
        kept_edges = edges_raw.reject { |r| MIGRATION_DELETE_EDGE_IDS.include?(r['abs_id'].to_s) }
        fallback_map = migration_fallback_targets(sheets_raw, kept_edges, reasons)
        registry = {}
        fallback = []
        retyped = []
        out_sheets = sheets_raw.map do |rec|
          migrate_record(rec, sheet: true, fallback_map: fallback_map, registry: registry,
                         fallback: fallback, retyped: retyped, reasons: reasons)
        end
        out_edges = kept_edges.map do |rec|
          migrate_record(rec, sheet: false, fallback_map: fallback_map, registry: registry,
                         fallback: fallback, retyped: retyped, reasons: reasons)
        end
        migration_near_match_guard(registry, reasons)
        check_variant_identities(out_sheets, out_edges, reasons)
        {
          sheets: out_sheets, edges: out_edges, deleted: deleted, retyped: retyped,
          fallback: fallback, groups: migration_groups_report(registry)
        }
      end

      # Fallback skupiny (FIX 8): zaznamy MIMO mapy s ROVNAKYM identity_norm
      # dekoru zdielaju JEDNU skupinu (nie group_id per riadok). Dekor = cely
      # trimnuty povodny text; vyrobca z pola zaznamu (len dosky). Rozny presny
      # zapis alebo dvaja vyrobcovia v jednej skupine = undecidable (ziadne
      # tiche hadanie).
      def migration_fallback_targets(sheets_raw, kept_edges, reasons)
        groups = {}
        collect = lambda do |rec, sheet|
          key = identity_norm(rec['decor'])
          next if MIGRATION_MAP.key?(key)
          g = groups[key] ||= { texts: [], manufacturers: [] }
          text = rec['decor'].to_s.strip
          g[:texts] << text unless g[:texts].include?(text)
          next unless sheet
          man = rec['manufacturer'].to_s.strip
          next if man.empty? || g[:manufacturers].any? { |m| identity_norm(m) == identity_norm(man) }
          g[:manufacturers] << man
        end
        sheets_raw.each { |r| collect.call(r, true) }
        kept_edges.each { |r| collect.call(r, false) }
        out = {}
        groups.each do |key, g|
          if g[:texts].length > 1
            reasons << "dekor mimo mapy '#{g[:texts].join("' vs '")}': rovnaka identita s roznym zapisom" \
                       ' — zjednot zapis pred migraciou'
          elsif g[:manufacturers].length > 1
            reasons << "dekor mimo mapy '#{g[:texts].first}': dva vyrobcovia v jednej skupine" \
                       " (#{g[:manufacturers].join(', ')})"
          else
            out[key] = { 'manufacturer' => g[:manufacturers].first.to_s, 'decor' => g[:texts].first }
          end
        end
        out
      end

      # Transformacia JEDNEHO zaznamu do KOPIE (original sa nikdy nemutuje):
      # group_id + prepis dekoru + doplnenie skupinovych poli podla mapy/fallbacku.
      # OSTATNYCH poli (color, grain, family, price_*, code, supplier,
      # production_class, width, sheet_size...) sa NEDOTYKA — testy overuju 1:1.
      def migrate_record(rec, sheet:, fallback_map:, registry:, fallback:, retyped:, reasons:)
        copy = rec.dup
        id = (sheet ? rec['material_id'] : rec['abs_id']).to_s
        if sheet && (new_type = MIGRATION_RETYPE[id])
          copy['type'] = new_type
          retyped << id
        end
        key = identity_norm(rec['decor'])
        target = MIGRATION_MAP[key]
        from_fallback = target.nil?
        target ||= fallback_map[key]
        return copy if target.nil? # fallback skupina uz padla na reason — plan sa aj tak zahodi
        gid = register_migration_group(target, registry, reasons)
        copy['group_id'] = gid
        copy['decor'] = target['decor']
        apply_migration_field(copy, 'decor_name', target['decor_name'])
        apply_migration_field(copy, 'structure', target['structure'])
        # FIX 7 / O2: vyrobca LEN na doskach — ABS zaznam ho NIKDY nenesie.
        apply_migration_field(copy, 'manufacturer', target['manufacturer']) if sheet
        registry[gid][sheet ? :sheets : :edges] += 1
        fallback << { id: id, decor: target['decor'], group_id: gid } if from_fallback
        copy
      end

      # Prazdna hodnota kluc NEZAPISUJE — vynecha/odstrani ho (FIX 11, O3).
      def apply_migration_field(copy, key, value)
        v = value.to_s.strip
        if v.empty?
          copy.delete(key)
        else
          copy[key] = v
        end
      end

      # Register skupin: bijekcia group_id <-> normalizovana obchodna identita
      # (FIX 8) + zhodne PRESNE polia skupiny na vsetkych zaznamoch (FIX 7 —
      # mapovana a fallback skupina s rovnakou identitou sa smu zliat len pri
      # uplne zhodnych poliach).
      def register_migration_group(target, registry, reasons)
        identity = group_identity_key(target['manufacturer'], target['decor'])
        gid = group_id_for(target['manufacturer'], target['decor'])
        entry = registry[gid]
        if entry.nil?
          registry[gid] = { identity: identity, manufacturer: target['manufacturer'].to_s,
                            decor: target['decor'].to_s, decor_name: target['decor_name'].to_s,
                            sheets: 0, edges: 0 }
        elsif entry[:identity] != identity
          reasons << "kolizia group_id #{gid}: '#{entry[:decor]}' vs '#{target['decor']}'"
        elsif entry[:manufacturer] != target['manufacturer'].to_s ||
              entry[:decor] != target['decor'].to_s ||
              entry[:decor_name] != target['decor_name'].to_s
          reasons << "skupina #{gid} ('#{entry[:decor]}'): nejednotne polia skupiny — zjednot zapis pred migraciou"
        end
        gid
      end

      # Near-match guard (FIX 8): dve ROZNE cielove skupiny, ktore by po
      # normalizacii BEZ medzier splynuli (vzor decor_conflict), su undecidable.
      def migration_near_match_guard(registry, reasons)
        entries = registry.values
        entries.each_with_index do |a, i|
          entries[(i + 1)..].each do |b|
            next unless decor_norm_key(a[:manufacturer]) == decor_norm_key(b[:manufacturer]) &&
                        decor_norm_key(a[:decor]) == decor_norm_key(b[:decor])
            reasons << "skupiny '#{a[:decor]}' a '#{b[:decor]}' sa lisia len zapisom (medzery/pisom)" \
                       ' — zjednot zapis pred migraciou'
          end
        end
      end

      # Krok 8: identity variantov EXPLICITNE v SCHEMA 2 (schema parameter
      # NAPEVNO — dup_variant_in cita schemu SUBORU, ktora je este 1, preto sa
      # tu NESMIE pouzit). PD bez formatu je nerozhodnutelny variant (O8).
      def check_variant_identities(out_sheets, out_edges, reasons)
        out_sheets.each do |r|
          next unless r.is_a?(Hash) && pd_type?(r['type'])
          next unless size_key(r['sheet_size']).nil?
          reasons << "#{r['material_id']}: PD variant bez formatu platne (format je sucast identity)"
        end
        migration_dup_pairs(out_sheets) { |r| sheet_identity_key(r, SCHEMA_GROUPS) }.each do |a, b|
          reasons << "duplicitna identita variantu dosky: #{a['material_id']} vs #{b['material_id']}"
        end
        migration_dup_pairs(out_edges) { |r| edge_identity_key(r, SCHEMA_GROUPS) }.each do |a, b|
          reasons << "duplicitna identita ABS variantu: #{a['abs_id']} vs #{b['abs_id']}"
        end
      end

      # Tolerancne parove porovnanie klucov (GH P2 vzor tolerant_dup; male n).
      def migration_dup_pairs(rows)
        keyed = rows.select { |r| r.is_a?(Hash) }.map { |r| [r, yield(r)] }
        out = []
        keyed.each_with_index do |(rec, key), i|
          keyed[(i + 1)..].each do |(other, other_key)|
            out << [rec, other] if identity_keys_tolerant?(key, other_key)
          end
        end
        out
      end

      # Report skupin — deterministicke poradie (identita, nie poradie suboru).
      def migration_groups_report(registry)
        registry.map do |gid, g|
          { group_id: gid, manufacturer: g[:manufacturer], decor: g[:decor],
            decor_name: g[:decor_name], sheets: g[:sheets], edges: g[:edges] }
        end.sort_by { |g| [identity_norm(g[:manufacturer]), identity_norm(g[:decor])] }
      end

      # --- krok 10a: zaloha (FIX 4) ------------------------------------------

      # :ok = zaloha existuje platna alebo prave vznikla; :backup_corrupt =
      # existujuca zaloha sa neda citat (NEprepisujeme — posledny predmigracny
      # stav sa nesmie stratit); :backup_failed = tvorba zlyhala.
      def ensure_pre_schema2_backup
        target = pre_schema2_backup_path
        if File.exist?(target)
          begin
            JSON.parse(File.binread(target))
            return :ok
          rescue StandardError
            return :backup_corrupt
          end
        end
        write_pre_schema2_backup! ? :ok : :backup_failed
      end

      # --- krok 11: best-effort vyuzitie mazanych ID (O7) --------------------

      # Vrati varovania o pouziti mazanych pasok v AKTUALNOM modeli a sablonach.
      # LEN informacia do reportu — migraciu nikdy neblokuje. Mimo SketchUpu
      # (pure testy) vrati [] bez padu.
      def deleted_usage_warnings(deleted_ids)
        return [] if deleted_ids.empty?
        return [] unless defined?(Sketchup) && Sketchup.respond_to?(:active_model)
        model = Sketchup.active_model
        return [] unless model
        out = []
        usage = defined?(Ids) && defined?(Store) ? used_abs_ids(model) : {}
        deleted_ids.each do |id|
          owners = Array(usage[id]).uniq
          out << "mazana paska #{id} sa pouziva v modeli: #{owners.join(', ')}" unless owners.empty?
          tpl = migration_template_edge_usage(id)
          out << "mazana paska #{id} sa pouziva v sablonach: #{tpl.join(', ')}" unless tpl.empty?
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'Materials.deleted_usage_warnings') if defined?(Engine)
        []
      end

      def migration_template_edge_usage(abs_id)
        return [] unless defined?(TemplateStore)
        hits = []
        TemplateStore.load.each do |t|
          ov = (t['config'] || {})['part_overrides']
          next unless ov.is_a?(Hash)
          used = ov.each_value.any? do |rec|
            e = rec.is_a?(Hash) ? rec['edges'] : nil
            e.is_a?(Hash) && e.each_value.any? { |v| v.to_s == abs_id }
          end
          hits << "sablona #{t['name']}" if used
        end
        hits
      rescue StandardError
        []
      end
    end
  end
end
