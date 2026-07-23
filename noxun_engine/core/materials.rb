# frozen_string_literal: true
# Noxun Engine — materialovy katalog (standard sekcia 7). Perzistencia JSON v
# %APPDATA%\NOXUN\Engine\materials.json + .bak zaloha pri zapise (pattern z templates.rb).
#
# Dve triedy zaznamov v jednom subore:
#   sheets — doskove materialy (variant = dekor + typ + hrubka; standard 7.1). production_class sheet.
#   edges  — ABS pasky (variant = dekor + hrubka ABS; standard 7.5).
#
# Materialovy katalog NIE je SketchUp textura. Je to katalogovy zaznam. SketchUp material
# vytvarame LEN na vizual (ensure_su_material) — nazov = material_id, farba z pola color.
# Vyrobny material dielca je ulozeny v jeho NOXUN/config['material_id'] (standard 7.3).
#
# Projektove defaulty (dedenie, standard 7.2) ziju v NOXUN dict na MODELI (project_defaults).
require 'json'
require 'fileutils'
require 'digest'

module Noxun
  module Engine
    module Materials
      STD  = 1
      FILE = 'materials.json'
      SUPPORTED_EDGE_THICKNESSES = [1.0, 2.0].freeze
      # D-41: sirka ABS pasky (mm). Volitelne pole 'width' na edge zazname —
      # legacy pasky bez sirky su "univerzalne" (pouzitelne pre kazdu hrubku).
      # Picker vyzaduje presah sirky nad hrubku dielca (olep + orez).
      EDGE_WIDTH_RANGE = (10.0..200.0)
      WIDTH_MARGIN = 2.0
      # Standardne sirky pre automaticke dovytvorenie pasky (PR C create-missing):
      # najmensia >= hrubka+MARGIN; mimo standardov sa auto-tvorba odmietne.
      AUTO_WIDTHS = [22.0, 43.0].freeze

      # Projektove default kluce v NOXUN dict na modeli (koren dedenia projekt->korpus->dielec).
      PROJECT_KEYS = %w[default_material_id default_front_material_id default_back_material_id].freeze
      PROJECT_FALLBACK = {
        'default_material_id'       => 'K009_PW_DTDL_18', # korpus (doska 18)
        'default_front_material_id' => 'W1000_DTDL_18',   # cela (biela celova 18)
        'default_back_material_id'  => 'HDF_WHITE_3'       # chrbat (HDF 3)
      }.freeze
      # Davka 2 (Codex audit, blocker 1): fallback ID su NEDELETOVATELNE — novy model
      # ich pouzije aj bez ulozenych atributov; zmazanie by rozbilo prvy vklad.
      PROTECTED_SHEET_IDS = PROJECT_FALLBACK.values.freeze
      GRAINS = %w[length width none].freeze

      module_function

      # --- cesty / perzistencia ------------------------------------------------

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita cely katalog { 'sheets' => [...], 'edges' => [...] }. Pri prvom spusteni seedne.
      def load
        JsonFileStore.deep_copy(catalog)
      end

      # Interny read-only pohlad pre lookupy pocas rebuildu. JsonFileStore ho drzi
      # v pamati a subor kontroluje nanajvys raz za CHECK_INTERVAL.
      def catalog
        ensure_seeded
        data = JsonFileStore.read(path, copy: false)
        sheet_records = data['sheets'].is_a?(Array) ? data['sheets'] : seed_sheets
        raw_edges = data['edges'].is_a?(Array) ? data['edges'] : seed_edges
        edge_records = raw_edges.select do |item|
          item.is_a?(Hash) && supported_edge_thickness?(item['thickness'])
        end

        if edge_records != raw_edges
          if write({ 'sheets' => sheet_records, 'edges' => edge_records }) && defined?(Engine)
            Engine.log('materialy: ABS katalog bol obmedzeny na hrubky 1/2 mm')
          end
        end

        {
          'sheets' => sheet_records,
          'edges'  => edge_records
        }
      rescue StandardError => e
        Engine.log_error(e, 'Materials.load') if defined?(Engine)
        { 'sheets' => seed_sheets, 'edges' => seed_edges }
      end

      def sheets
        catalog['sheets']
      end

      def edges
        catalog['edges']
      end

      # Doskovy material podla material_id (alebo nil).
      def sheet(id)
        return nil if id.nil?
        sheets.find { |m| m['material_id'] == id }
      end

      # ABS paska podla abs_id (alebo nil).
      def edge(id)
        return nil if id.nil?
        edges.find { |a| a['abs_id'] == id }
      end

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

      # Zapis so zalohou: existujuci subor -> .bak, novy cez .tmp + atomicky rename (ako templates.rb).
      def write(data)
        payload = { 'std' => STD, 'sheets' => data['sheets'], 'edges' => data['edges'] }
        JsonFileStore.write(path, payload)
      rescue StandardError => e
        Engine.log_error(e, 'Materials.write') if defined?(Engine)
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- ABS podla dekoru (pravidlove defaulty, standard 7.5) ----------------

      # Najde ABS variant daneho dekoru a hrubky ABS (mm), volitelne pre cielovu
      # hrubku dielca (vyber sirky pasky). Vrati abs_id alebo nil.
      # D-41: deterministicky picker (audit BLOCKER 2 — NIKDY uzsia paska):
      #   s hrubkou dielca: najmensia sirka >= hrubka+WIDTH_MARGIN -> legacy bez
      #     sirky (univerzalna) -> nil (ziadna vyhovujuca; volajuci ohlasi).
      #   bez hrubky (defenzivny fallback): legacy bez sirky -> najsirsia
      #     (siroku mozno orezat, uzka nepokryje).
      # Tie-break vzdy abs_id vzostupne (audit FIX 11 — stabilne poradie nezavisle
      # od poradia zaznamov v subore).
      def abs_for_decor(decor, thickness, part_thickness = nil)
        rec = pick_edge_variant(edge_candidates(decor, thickness), part_thickness)
        rec && rec['abs_id']
      end

      # Kandidati: pasky presne zhodneho dekoru a hrubky ABS, zoradene abs_id.
      def edge_candidates(decor, thickness)
        return [] if decor.nil?
        th = thickness.to_f
        edges.select { |a| a['decor'] == decor && (a['thickness'].to_f - th).abs < 0.01 }
             .sort_by { |a| a['abs_id'].to_s }
      end

      # Cisty vyber varianty z kandidatov (testovatelne bez katalogu).
      def pick_edge_variant(cands, part_thickness = nil)
        return nil if cands.empty?
        widthless = cands.select { |a| edge_width(a).nil? }
        widthed   = cands.reject { |a| edge_width(a).nil? }
        if part_thickness
          need = part_thickness.to_f + WIDTH_MARGIN
          fit = widthed.select { |a| edge_width(a) >= need - 0.001 }
                       .min_by { |a| [edge_width(a), a['abs_id'].to_s] }
          fit || widthless.first
        else
          widthless.first || widthed.max_by { |a| [edge_width(a), a['abs_id'].to_s] }
        end
      end

      # Sirka pasky ako Float alebo nil (legacy univerzalna).
      def edge_width(rec)
        v = rec && rec['width']
        v.nil? ? nil : v.to_f
      end

      # D-41 PR C (audit FIX 5): JEDNO jadro preladenia mapy hran {code=>abs_id|nil}
      # zo stareho dekoru na novy — pouzivaju ho doska AJ dielcove overridy.
      # Meni LEN pasky presne zhodne so starym dekorom; cudzi dekor = vedoma
      # kontrastna volba a nil = vedome "bez ABS" — tie sa NIKDY nedotknu.
      # target_thickness = cielova hrubka dielca (vyber sirky novej pasky).
      # Vrati [nova_mapa alebo nil (nic na prevod), pole hran bez nahrady].
      def remap_edges(edges_hash, old_decor, new_decor, target_thickness = nil)
        return [nil, []] unless edges_hash.is_a?(Hash) && old_decor && new_decor && old_decor != new_decor
        out = edges_hash.dup
        changed = false
        lost = []
        out.each_key do |code|
          aid = out[code]
          next if aid.nil?
          rec = edge(aid)
          next unless rec && rec['decor'] == old_decor
          new_aid = abs_for_decor(new_decor, rec['thickness'], target_thickness)
          lost << code if new_aid.nil?
          out[code] = new_aid
          changed = true
        end
        [changed ? out : nil, lost]
      end

      # Dekor doskoveho materialu (pre napojenie ABS na rovnaky dekor). nil ak material nie je v katalogu.
      def decor_of(material_id)
        s = sheet(material_id)
        s && s['decor']
      end

      # --- D-41: dekor = kluc skupiny (audit BLOCKER 1) -------------------------
      # Vazba material<->ABS bezi cez PRESNY string 'decor' (trim pri zapise robi
      # normalize_*). Preklepy chytame near-match guardom: novy dekor, ktory sa od
      # existujuceho lisi len velkostou pismen/medzerami, sa odmietne s presnym tvarom.

      # Normalizovany kluc na porovnanie "skoro rovnakych" dekorov. Medzery sa
      # odstranuju UPLNE (Codex GH #70: "U702ST9" vs "U702 ST9" je ten isty
      # preklep ako dvojita medzera — kolaps na jednu by ho prepustil).
      def decor_norm_key(d)
        d.to_s.gsub(/\s+/, '').downcase
      end

      # Existujuci dekor, ktory sa s danym zhoduje na norm kluci, ale NIE presne
      # (preklep/iny zapis). Vrati existujuci string alebo nil.
      def decor_conflict(decor)
        want = decor.to_s.strip
        key = decor_norm_key(want)
        return nil if key.empty?
        all_decors.find { |d| d != want && decor_norm_key(d) == key }
      end

      def all_decors
        (sheets.map { |s| s['decor'].to_s } + edges.map { |a| a['decor'].to_s }).uniq
      end

      # Variant identity lookupy (dup guard pri create; audit FIX 16):
      # sheet = dekor + typ (case-insensitive) + hrubka; edge = dekor + sirka + hrubka.
      def find_sheet_variant(decor, type, thickness)
        d = decor.to_s.strip
        t = type.to_s.strip.upcase
        th = thickness.to_f
        sheets.find do |s|
          s['decor'].to_s == d && s['type'].to_s.strip.upcase == t &&
            (s['thickness'].to_f - th).abs < 0.01
        end
      end

      def find_edge_variant(decor, width, thickness)
        d = decor.to_s.strip
        th = thickness.to_f
        w = width.nil? || width.to_s.strip.empty? ? nil : width.to_s.tr(',', '.').to_f
        edges.find do |a|
          next false unless a['decor'].to_s == d && (a['thickness'].to_f - th).abs < 0.01
          aw = edge_width(a)
          w.nil? ? aw.nil? : (aw && (aw - w).abs < 0.01)
        end
      end

      # Atomicke premenovanie dekoru CELEJ skupiny (sheets + edges, 1 zapis).
      # ID zaznamov sa NIKDY nemenia (modely drzia vazbu cez id) — meni sa len text.
      # Merge do existujucej skupiny je povoleny, len ak nevzniknu duplicitne
      # varianty. Vrati [true, pocet] alebo [false, chyba].
      def rename_decor(old_decor, new_decor)
        from = old_decor.to_s.strip
        to = new_decor.to_s.strip
        return [false, 'Dekor je povinný.'] if from.empty? || to.empty?
        return [false, 'Nový názov je rovnaký.'] if from == to
        conflict = decor_conflict(to)
        if conflict && conflict != from
          return [false, "Názov sa líši od existujúceho „#{conflict}“ len zápisom — použi presný tvar."]
        end
        data = load
        changed = 0
        %w[sheets edges].each do |k|
          data[k].each do |r|
            next unless r['decor'].to_s == from
            r['decor'] = to
            changed += 1
          end
        end
        return [false, 'Dekor sa nenašiel.'] if changed.zero?
        dup = dup_variant_in(data)
        return [false, "Premenovaním by vznikli duplicitné varianty (#{dup}) — zlúčenie nie je možné."] if dup
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, changed]
      end

      # Prva duplicitna variant identity v datach (popis) alebo nil.
      def dup_variant_in(data)
        s = data['sheets'].group_by { |r| [r['decor'].to_s, r['type'].to_s.strip.upcase, r['thickness'].to_f.round(2)] }
                          .find { |_, v| v.size > 1 }
        return "#{s[0][0]} #{s[0][1]} #{s[0][2]} mm" if s
        e = data['edges'].group_by { |r| [r['decor'].to_s, edge_width(r)&.round(2), r['thickness'].to_f.round(2)] }
                         .find { |_, v| v.size > 1 }
        e && "ABS #{e[0][0]} #{e[0][1] ? "#{e[0][1]}/" : ''}#{e[0][2]} mm"
      end

      # Kratky odtlacok obsahu katalogu — baseline guard okna (audit FIX 15):
      # formular ulozeny nad starsim stavom sa odmietne, klient si vypyta refresh.
      def catalog_revision
        Digest::SHA1.hexdigest(JSON.generate(catalog))[0, 12]
      end

      # --- D-41 PR C2: dovytvorenie chybajucej pasky (modal "Vytvorit a pokracovat") --

      # Standardna sirka pasky pre hrubku dielca: najmensia z AUTO_WIDTHS s presahom
      # >= WIDTH_MARGIN; mimo standardov nil (audit BLOCKER 4 — ziadne porusenie
      # presahu, auto-tvorba sa radsej odmietne).
      def auto_width_for(thickness)
        th = thickness.to_f
        AUTO_WIDTHS.find { |w| w >= th + WIDTH_MARGIN - 0.001 }
      end

      # Zabezpeci 1,0 mm pasku dekoru daneho sheetu pouzitelnu pre jeho hrubku.
      # SERVEROVA autorita modalu (JS checku sa neveri — audit BLOCKER 3): stav sa
      # overi znova a zapis bezi az po vsetkych kontrolach (audit FIX 8). Katalogovy
      # zapis je MIMO model undo — volajuci to hlasi pouzivatelovi (NOTE 9).
      # Vrati [:exists|:created, abs_id] alebo [:no_sheet|:no_standard_width|:write_failed, nil].
      def ensure_edge_for_sheet(material_id)
        s = sheet(material_id)
        return [:no_sheet, nil] unless s
        th = s['thickness'].to_f
        existing = abs_for_decor(s['decor'], 1.0, th.positive? ? th : nil)
        return [:exists, existing] if existing
        width = auto_width_for(th)
        return [:no_standard_width, nil] unless width
        rec = {
          'abs_id' => generate_edge_id(s['decor'], 1.0, width), 'decor' => s['decor'],
          'thickness' => 1.0, 'width' => width, 'price_per_bm' => 0.0, 'color' => s['color']
        }
        return [:write_failed, nil] unless upsert_edge(rec)
        [:created, rec['abs_id']]
      end

      # --- D-41 PR B: batch "Novy dekor" (audit FIX 14) -------------------------
      # Cely vstup sa NAJPRV parsuje a validuje do pamate; JEDINY chybny token
      # zrusi celu davku BEZ zapisu. Existujuce IDENTICKE varianty sa preskocia
      # (report), vsetko nove sa zapise JEDNYM Materials.write. ID sa generuju
      # proti kumulativnemu taken zoznamu (katalog + uz pripravene polozky davky).
      #
      # attrs: decor, manufacturer, type, grain, color([r,g,b]),
      #        thicknesses (string "18, 36"), abs_tokens (string "22/1, 43/1, 43/2")
      # Vrati [true, {sheets:[id...], edges:[id...], skipped:[popis...]}] alebo [false, chyba].
      def add_decor_batch(attrs)
        decor = (attrs['decor'] || attrs[:decor]).to_s.strip
        return [false, 'Dekor je povinný.'] if decor.empty?
        # Preklep guard: near-match s INYM presnym tvarom = stop. Presna zhoda =
        # legitimne doplnanie variantov do existujucej skupiny ("+ variant").
        if (near = decor_conflict(decor))
          return [false, "Dekor sa líši od existujúceho „#{near}“ len zápisom — použi presný tvar."]
        end
        manufacturer = (attrs['manufacturer'] || attrs[:manufacturer]).to_s.strip
        existing_man = sheets.find { |s| s['decor'] == decor && !s['manufacturer'].to_s.strip.empty? }
        if existing_man && !manufacturer.empty? && existing_man['manufacturer'].to_s.strip != manufacturer
          return [false, "Skupina #{decor} už má výrobcu #{existing_man['manufacturer']} — dva výrobcovia v jednej skupine nie sú dovolené."]
        end
        type = (attrs['type'] || attrs[:type]).to_s.strip
        type = 'DTDL' if type.empty?
        grain = (attrs['grain'] || attrs[:grain] || 'length').to_s
        return [false, 'Smer dekoru musí byť length/width/none.'] unless GRAINS.include?(grain)
        color = normalize_rgb(attrs['color'] || attrs[:color], [216, 196, 160])

        ok_th, ths = parse_number_list(attrs['thicknesses'] || attrs[:thicknesses])
        return [false, ths] unless ok_th
        ok_abs, abs_list = parse_abs_tokens(attrs['abs_tokens'] || attrs[:abs_tokens])
        return [false, abs_list] unless ok_abs
        return [false, 'Zadaj aspoň jednu hrúbku dosky alebo ABS pásku.'] if ths.empty? && abs_list.empty?

        data = load
        taken = (data['sheets'].map { |s| s['material_id'].to_s.upcase } +
                 data['edges'].map { |a| a['abs_id'].to_s.upcase })
        created_sheets = []
        created_edges = []
        skipped = []

        # Dedup v ramci davky s TOLERANCIOU 0.01 mm (Codex GH #71: 18 a 18.004 su
        # ten isty variant — exact uniq by pustil duplicitne zaznamy s -2 ID).
        seen_ths = []
        ths.each do |th|
          next if seen_ths.any? { |t| (t - th).abs < 0.01 }
          seen_ths << th
          if find_sheet_variant(decor, type, th)
            skipped << "#{type} #{fmt_mm(th)}"
            next
          end
          base = "#{slug(decor)}_#{slug(type)}_#{thickness_token(th)}"
          id = unique_id(base, taken)
          taken << id.upcase
          data['sheets'] << normalize_sheet(
            'material_id' => id, 'family' => "#{manufacturer} #{decor}".strip,
            'manufacturer' => manufacturer, 'decor' => decor, 'type' => type,
            'thickness' => th, 'grain' => grain, 'price_per_m2' => 0.0, 'color' => color
          )
          created_sheets << id
        end

        seen_abs = []
        abs_list.each do |(w, th)|
          next if seen_abs.any? { |(pw, pt)| (pw - w).abs < 0.01 && (pt - th).abs < 0.01 }
          seen_abs << [w, th]
          if find_edge_variant(decor, w, th)
            skipped << "ABS #{fmt_mm(w)}/#{fmt_mm(th)}"
            next
          end
          base = "ABS_#{slug(decor)}_#{thickness_token(w)}X#{(th * 10).round}"
          id = unique_id(base, taken)
          taken << id.upcase
          data['edges'] << normalize_edge(
            'abs_id' => id, 'decor' => decor, 'thickness' => th,
            'width' => w, 'price_per_bm' => 0.0, 'color' => color
          )
          created_edges << id
        end

        if created_sheets.empty? && created_edges.empty?
          return [false, "Všetky zadané varianty už v katalógu sú (#{skipped.join(', ')})."]
        end
        return [false, 'Zápis katalógu zlyhal.'] unless write(data)
        [true, { 'sheets' => created_sheets, 'edges' => created_edges, 'skipped' => skipped }]
      end

      # "18, 36" -> [18.0, 36.0]. Desatiny LEN bodkou — ciarka je oddelovac poloziek.
      # NEJEDNOZNACNY je iba vzor cislo,JEDNA cifra bez medzery a bez pokracovania
      # (18,5) — to je takmer iste desatinna ciarka a vrati JASNU chybu (ziadna
      # ticha interpretacia — vzor D-19). Kompaktne zoznamy 18,36 aj 18.5,36 su
      # legalne (Codex GH #71: oddelovac bez medzery nesmie zhodit davku).
      def parse_number_list(raw)
        s = raw.to_s.strip
        return [true, []] if s.empty?
        if (amb = s[/\d+,\d(?![\d.])/])
          return [false, "Nejednoznačný zápis „#{amb}“ — desatiny píš bodkou (18.5), položky oddeľuj čiarkou."]
        end
        out = []
        s.split(',').each do |tok|
          t = tok.strip
          next if t.empty?
          f = begin
            Float(t)
          rescue StandardError
            nil
          end
          return [false, "Hrúbka „#{t}“ nie je kladné číslo."] unless f && f.finite? && f.positive?
          out << f
        end
        [true, out]
      end

      # "22/1, 43/1, 43/2" -> [[22.0, 1.0], [43.0, 1.0], [43.0, 2.0]].
      # Sirka povinna (nove pasky su sirkove; univerzalne = legacy zaznamy),
      # hrubka ABS len 1/2 mm, desatiny bodkou. Ziadny predbezny ciarkovy guard
      # (Codex GH #71: 22/1,43/1 je legalny kompakt) — desatinnu ciarku chyti
      # formatova kontrola tokenu (22,5/1 -> tokeny "22" a "5/1", oba bez zmyslu).
      def parse_abs_tokens(raw)
        s = raw.to_s.strip
        return [true, []] if s.empty?
        out = []
        s.split(',').each do |tok|
          t = tok.strip
          next if t.empty?
          m = t.match(%r{\A(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)\z})
          return [false, "ABS „#{t}“ zapíš ako šírka/hrúbka (napr. 22/1, desatiny bodkou)."] unless m
          w = m[1].to_f
          th = m[2].to_f
          return [false, "Šírka ABS „#{t}“ musí byť 10–200 mm."] unless EDGE_WIDTH_RANGE.cover?(w)
          return [false, "Hrúbka ABS „#{t}“ musí byť 1 alebo 2 mm."] unless supported_edge_thickness?(th)
          out << [w, th]
        end
        [true, out]
      end

      # 18.0 -> "18", 18.5 -> "18.5" (labely/reporty).
      def fmt_mm(v)
        f = v.to_f
        f == f.round ? f.round.to_s : f.to_s
      end

      # --- SketchUp vizualny material z katalogu -------------------------------

      # Vytvori/najde SketchUp material s nazvom = material_id a farbou z katalogu (pole color [r,g,b]).
      # Nahrada za natvrdo NOXUN_korpus/NOXUN_front. Fallback farba ak material nie je v katalogu.
      def ensure_su_material(model, material_id, fallback_rgb = [216, 196, 160])
        name = (material_id && !material_id.to_s.empty?) ? material_id.to_s : 'NOXUN_material'
        rgb = color_of(material_id) || fallback_rgb
        mt = model.materials[name] || model.materials.add(name)
        mt.color = Sketchup::Color.new(*rgb)
        mt
      rescue StandardError => e
        Engine.log_error(e, 'Materials.ensure_su_material') if defined?(Engine)
        model.materials[material_id.to_s] || model.materials.add('NOXUN_material')
      end

      # Farba doskoveho materialu ([r,g,b]) z katalogu, alebo nil (potom fallback).
      def color_of(material_id)
        s = sheet(material_id)
        return nil unless s && s['color'].is_a?(Array) && s['color'].size == 3
        s['color'].map(&:to_i)
      end

      # --- projektove defaulty (dedenie: koren; NOXUN dict na modeli) -----------

      # Vrati 3 projektove defaulty (default/front/back material_id). Chybajuce -> PROJECT_FALLBACK.
      def project_defaults(model)
        out = {}
        PROJECT_KEYS.each do |k|
          v = model_default(model, k)
          out[k] = (v.nil? || v.to_s.strip.empty?) ? PROJECT_FALLBACK[k] : v.to_s
        end
        out
      end

      def model_default(model, key)
        return nil unless model
        model.get_attribute(Store::DICT, key)
      rescue StandardError
        nil
      end

      # Nastavi jeden projektovy default na modeli (1 undo krok obali volajuci).
      def set_project_default(model, key, value)
        return false unless model && PROJECT_KEYS.include?(key.to_s)
        v = value.to_s.strip
        model.set_attribute(Store::DICT, key.to_s, v)
        true
      rescue StandardError => e
        Engine.log_error(e, 'Materials.set_project_default') if defined?(Engine)
        false
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
        price = a['price_per_m2'] || a[:price_per_m2] || 0
        return [false, 'Cena nesmie byť záporná.'] if price.to_s.tr(',', '.').to_f.negative?
        rgb = a['color'] || a[:color]
        if rgb && !(rgb.is_a?(Array) && rgb.size == 3 && rgb.all? { |c| c.to_i.between?(0, 255) })
          return [false, 'Farba musí byť RGB 0–255.']
        end
        # D-19: format platne je volitelny — ak je poslany, musia to byt dve
        # cisla 500..5000 mm (striktne — nie ticha oprava, Codex F4).
        ss = a['sheet_size'] || a[:sheet_size]
        if ss
          valid = ss.is_a?(Array) && ss.size == 2 &&
                  ss.all? { |x| (n = pair_num(x)) && n.between?(500.0, 5000.0) }
          return [false, 'Formát platne musí byť dve čísla 500–5000 mm.'] unless valid
        end
        [true, nil]
      end

      def validate_edge_attrs(a)
        decor = (a['decor'] || a[:decor]).to_s.strip
        return [false, 'Dekor ABS je povinný.'] if decor.empty?
        th = (a['thickness'] || a[:thickness]).to_s.tr(',', '.').to_f
        return [false, 'Hrúbka ABS musí byť 1,0 alebo 2,0 mm.'] unless supported_edge_thickness?(th)
        price = a['price_per_bm'] || a[:price_per_bm] || 0
        return [false, 'Cena nesmie byť záporná.'] if price.to_s.tr(',', '.').to_f.negative?
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

      # Slug pre technicke ID: transliteracia diakritiky (NFD + odstranenie znamienok),
      # upcase, [A-Z0-9] bloky spojene '_'. 'Dub Halifax prírodný' -> 'DUB_HALIFAX_PRIRODNY'.
      def slug(value)
        s = value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
        s.upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
      end

      # Token hrubky do ID: cele mm ako '18'; desatinne '18P5' (18.5 nesmie vyzerat ako 19).
      def thickness_token(th)
        f = th.to_s.tr(',', '.').to_f
        (f % 1).zero? ? f.to_i.to_s : format('%gP%d', f.floor, ((f % 1) * 10).round).sub('P0', '')
      end

      # Vygeneruje volne material_id: SLUG(decor)_SLUG(type)_TOKEN(th); kolizie
      # (case-insensitive) dostanu -2/-3... ID sa NIKDY negeneruje pri edite.
      def generate_sheet_id(decor, type, thickness)
        base = "#{slug(decor)}_#{slug(type)}_#{thickness_token(thickness)}"
        unique_id(base, sheets.map { |s| s['material_id'].to_s.upcase })
      end

      # D-41: paska so sirkou dostane ID s tokenom sirky PRED hrubkou
      # (ABS_U702_ST9_22X10 = sirka 22, hrubka 1,0). Bez sirky stary format
      # (ABS_U702_ST9_10). Existujuce ID sa NIKDY negeneruju znova.
      def generate_edge_id(decor, thickness, width = nil)
        th_token = (thickness.to_s.tr(',', '.').to_f * 10).round.to_s
        base = if width.nil? || width.to_s.strip.empty?
                 "ABS_#{slug(decor)}_#{th_token}"
               else
                 "ABS_#{slug(decor)}_#{thickness_token(width)}X#{th_token}"
               end
        unique_id(base, edges.map { |a| a['abs_id'].to_s.upcase })
      end

      def unique_id(base, taken_upcased)
        return base unless taken_upcased.include?(base.upcase)
        n = 2
        n += 1 while taken_upcased.include?("#{base.upcase}-#{n}")
        "#{base}-#{n}"
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

      # --- normalizacia zaznamov ----------------------------------------------

      # D-41 (audit BLOCKER 1): 'decor' je kluc vazby material<->ABS — pri KAZDOM
      # zapise sa trimuje, aby Ruby presna zhoda sedela s JS zhodou (normDecor trim).
      def normalize_sheet(a)
        id = (a['material_id'] || a[:material_id]).to_s
        return nil if id.strip.empty?
        {
          'material_id' => id,
          'family'      => (a['family'] || a[:family]).to_s.strip,
          'manufacturer' => (a['manufacturer'] || a[:manufacturer]).to_s.strip,
          'decor'       => (a['decor'] || a[:decor]).to_s.strip,
          'type'        => (a['type'] || a[:type]).to_s.strip,
          'thickness'   => (a['thickness'] || a[:thickness]).to_f,
          'grain'       => (a['grain'] || a[:grain] || 'none').to_s,
          'price_per_m2' => (a['price_per_m2'] || a[:price_per_m2] || 0.0).to_f,
          'sheet_size'  => normalize_pair(a['sheet_size'] || a[:sheet_size], [2800.0, 2070.0]),
          'color'       => normalize_rgb(a['color'] || a[:color], [216, 196, 160]),
          'production_class' => 'sheet'
        }
      end

      def normalize_edge(a)
        id = (a['abs_id'] || a[:abs_id]).to_s
        return nil if id.strip.empty?
        thickness = (a['thickness'] || a[:thickness]).to_f
        return nil unless supported_edge_thickness?(thickness)
        out = {
          'abs_id'       => id,
          'decor'        => (a['decor'] || a[:decor]).to_s.strip,
          'thickness'    => thickness,
          'price_per_bm' => (a['price_per_bm'] || a[:price_per_bm] || 0.0).to_f,
          'color'        => normalize_rgb(a['color'] || a[:color], [216, 196, 160])
        }
        # D-41: 'width' kluc sa uklada LEN ked ma hodnotu — legacy zaznam bez
        # kluca = univerzalna paska (ziadne nil kluce v JSON).
        w_raw = a['width'] || a[:width]
        unless w_raw.nil? || w_raw.to_s.strip.empty?
          w = begin
            Float(w_raw.to_s.tr(',', '.'))
          rescue StandardError
            nil
          end
          out['width'] = w if w && w.finite? && w.positive?
        end
        out
      end

      # D-19 (Codex F4): to_f by z "abc" spravilo 0.0 a odhad platni by delil
      # nulou — nekladny/nečíselny prvok znamena CELY par default.
      def normalize_pair(v, dflt)
        return dflt unless v.is_a?(Array) && v.size == 2
        l = pair_num(v[0])
        w = pair_num(v[1])
        l && w ? [l, w] : dflt
      end

      def pair_num(v)
        f = begin
          Float(v)
        rescue StandardError, TypeError
          nil
        end
        f && f.positive? && f.finite? ? f : nil
      end

      def supported_edge_thickness?(value)
        SUPPORTED_EDGE_THICKNESSES.include?(value.to_f)
      end

      # Povoli iba ABS, ktore realne existuje v aktivnom katalogu 1/2 mm.
      def normalized_abs_id(id)
        value = id.to_s.strip
        return nil if value.empty?
        edge(value) ? value : nil
      end

      def normalize_rgb(v, dflt)
        return dflt unless v.is_a?(Array) && v.size == 3
        v.map(&:to_i)
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
