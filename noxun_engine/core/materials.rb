# frozen_string_literal: true
# Noxun Engine — materialovy katalog (standard sekcia 7). Perzistencia JSON v
# %APPDATA%\NOXUN\Engine\materials.json + .bak zaloha pri zapise (pattern z templates.rb).
#
# Dve triedy zaznamov v jednom katalogu:
#   sheets — doskove materialy (variant = dekor + typ + hrubka; standard 7.1). production_class sheet.
#   edges  — ABS pasky (variant = dekor + hrubka ABS; standard 7.5).
#
# Materialovy katalog NIE je SketchUp textura. Je to katalogovy zaznam. SketchUp material
# vytvarame LEN na vizual (ensure_su_material) — nazov = material_id, farba z pola color.
# Vyrobny material dielca je ulozeny v jeho NOXUN/config['material_id'] (standard 7.3).
#
# Projektove defaulty (dedenie, standard 7.2) ziju v NOXUN dict na MODELI (project_defaults).
#
# Modul Materials je od V0.5.1 rozdeleny (mechanicky split) do 5 suborov — vsetky
# otvaraju ten isty `module Noxun::Engine::Materials` s module_function, takze
# volania Materials.xyz ostavaju rovnake bez ohladu na fyzicky subor:
#   materials.rb          — TENTO subor: cesty/perzistencia, citanie katalogu,
#                            SketchUp vizualny material, normalizacia zaznamov
#                            a zdielane helpery pouzivane vo viacerych ostatnych suboroch.
#   materials_catalog.rb  — CRUD, validacia + generovanie ID, scan pouzitia, D-42 patch protokol, seed.
#   materials_decor.rb    — D-41 dekor = kluc skupiny, dovytvorenie ABS pasky, batch "Novy dekor".
#   materials_abs.rb      — ABS podla dekoru (picker, pravidlove defaulty, remap).
#   materials_project.rb  — projektove defaulty na modeli + pouzitie dekorov v projekte.
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

      # D-44 (audit F6): povoleny rozsah rozmeru platne (mm) — JEDINA autorita
      # pouzivana formularom (validate_sheet_attrs) AJ batchom "Novy dekor".
      # Dva rozne rozsahy = dva rozne pravdy, preto konstanta.
      SHEET_SIZE_RANGE = (500.0..5000.0)
      # D-44 (audit B2): NAVRH formatu platne podla typu dosky pre nove varianty
      # v batchi. DTDL/MDF/HDF maju de facto standard 2800x2070; PD (pracovna
      # doska) ma sirok vela a lisia sa per vyrobca -> ziadny navrh = vedome
      # zadanie. Neznamy typ = nil. Navrh je len PREDVYPLNENIE viditelneho pola
      # (viditelne = potvrdene odoslanim) — server neuklada neovereny default.
      TYPE_FORMAT_HINTS = {
        'DTDL' => [2800.0, 2070.0],
        'MDF'  => [2800.0, 2070.0],
        'HDF'  => [2800.0, 2070.0],
        'PD'   => nil
      }.freeze
      # D-44: typy ponukane v naseptavaci aj ked ich katalog este neobsahuje
      # (typ ostava volny string — toto NIE JE enum, len navrhy).
      SEED_TYPES = %w[DTDL PD MDF HDF kompakt].freeze

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

      # --- normalizacia zaznamov ----------------------------------------------

      # D-41 (audit BLOCKER 1): 'decor' je kluc vazby material<->ABS — pri KAZDOM
      # zapise sa trimuje, aby Ruby presna zhoda sedela s JS zhodou (normDecor trim).
      def normalize_sheet(a)
        id = (a['material_id'] || a[:material_id]).to_s
        return nil if id.strip.empty?
        out = {
          'material_id' => id,
          'family'      => (a['family'] || a[:family]).to_s.strip,
          'manufacturer' => (a['manufacturer'] || a[:manufacturer]).to_s.strip,
          'decor'       => (a['decor'] || a[:decor]).to_s.strip,
          'type'        => (a['type'] || a[:type]).to_s.strip,
          'thickness'   => (a['thickness'] || a[:thickness]).to_f,
          'grain'       => (a['grain'] || a[:grain] || 'none').to_s,
          'price_per_m2' => normalize_price(a['price_per_m2'] || a[:price_per_m2]),
          'sheet_size'  => normalize_pair(a['sheet_size'] || a[:sheet_size]),
          'color'       => normalize_rgb(a['color'] || a[:color], [216, 196, 160]),
          'production_class' => 'sheet'
        }
        # D-42: cena ako nil-alebo-Float — kluc sa uklada LEN ked je cena ZADANA
        # (rozlisenie "nezadana" vs "0", audit FIX 11). Nil sa do JSON neuklada.
        out.delete('price_per_m2') if out['price_per_m2'].nil?
        # D-44 (audit B2): format platne je rovnako VOLITELNY — server nikdy
        # neuklada neovereny default 2800x2070 ako DATA. Chybajuci format =
        # odhad platni pouzije fallback A OZNACI ho, semafor "nezmesti sa" o nom
        # mlci (namiesto merania proti vymyslenemu formatu).
        out.delete('sheet_size') if out['sheet_size'].nil?
        put_opt(out, 'code', a['code'] || a[:code])
        put_opt(out, 'supplier', a['supplier'] || a[:supplier])
        out
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
          'price_per_bm' => normalize_price(a['price_per_bm'] || a[:price_per_bm]),
          'color'        => normalize_rgb(a['color'] || a[:color], [216, 196, 160])
        }
        out.delete('price_per_bm') if out['price_per_bm'].nil?
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
        put_opt(out, 'code', a['code'] || a[:code])       # D-42 dodavatelsky/katalogovy kod
        put_opt(out, 'supplier', a['supplier'] || a[:supplier]) # D-42 preferovany dodavatel
        out
      end

      # D-42: volitelne string pole (code/supplier) — ulozi sa LEN ked ma hodnotu
      # (trim). Prazdne/nil sa NEpridava do hashu — legacy zaznam bez kluca ostava
      # cisty a "vymazane" pole (prazdny string z UI) sa realne odstrani.
      def put_opt(out, key, raw)
        v = raw.to_s.strip
        out[key] = v unless v.empty?
      end

      # D-42 (audit FIX 11): cena rozlisuje "nezadana" (nil) od "0". Nil/prazdny
      # vstup -> nil (kluc sa neulozi). Necislo -> nil (NIE ticha 0 z "abc".to_f).
      # Cislo (aj 0) -> Float. Zaporne prejde tvarom, odmietne ho validator.
      def normalize_price(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?
        Float(raw.to_s.tr(',', '.'))
      rescue StandardError
        nil
      end

      # D-19 (Codex F4): to_f by z "abc" spravilo 0.0 a odhad platni by delil
      # nulou — nekladny/neciselny prvok znamena, ze format NIE JE zadany.
      # D-44: vracia nil (nie default) — kluc sa potom vobec neulozi (audit B2).
      def normalize_pair(v)
        return nil unless v.is_a?(Array) && v.size == 2
        l = pair_num(v[0])
        w = pair_num(v[1])
        l && w ? [l, w] : nil
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

      # --- zdielane helpery (pouzivane vo viacerych materials_*.rb suboroch) ---
      # Davka split V0.5.1: tieto nizkourovnove helpery vola CRUD/validacia AJ
      # dekorova/batch logika (v roznych suboroch) — ostavaju spolocne v jadre.

      # Sirka pasky ako Float alebo nil (legacy univerzalna).
      def edge_width(rec)
        v = rec && rec['width']
        v.nil? ? nil : v.to_f
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

      # --- D-44: navrhy do naseptavacov (datalist) -----------------------------
      # Zoznam stavia SERVER a posiela ho v payloade (push_state/push_catalog) —
      # JS ho len renderuje (jedna autorita, ziadne zbieranie z DOM).

      # Trim, prazdne von, dedup CASE-INSENSITIVE (prvy vyskyt urcuje tvar —
      # do katalogu sa zapisuje AS-TYPED, navrh len ponuka existujuci zapis),
      # stabilne zoradene abecedne case-insensitive (tie-break presnym tvarom,
      # aby poradie neviselo na poradi zaznamov v subore).
      def string_suggestions(values)
        seen = {}
        values.each do |raw|
          v = raw.to_s.strip
          next if v.empty?
          k = v.downcase
          seen[k] = v unless seen.key?(k)
        end
        seen.values.sort_by { |v| [v.downcase, v] }
      end

      # Vyrobcovia pouzivani v katalogu (vyrobca je vlastnost dekoru = dosky).
      def manufacturer_suggestions
        string_suggestions(sheets.map { |s| s['manufacturer'] })
      end

      # Typy dosiek z katalogu + seed typy (katalog ide prvy, takze si drzi
      # vlastny zapis tvaru pri kolizii velkosti pismen).
      def type_suggestions
        string_suggestions(sheets.map { |s| s['type'] } + SEED_TYPES)
      end

      # Hranice formatu platne do hlasky — z JEDNEJ konstanty (formular aj batch).
      def sheet_size_range_label
        "#{fmt_mm(SHEET_SIZE_RANGE.first)}–#{fmt_mm(SHEET_SIZE_RANGE.last)}"
      end

      def unique_id(base, taken_upcased)
        return base unless taken_upcased.include?(base.upcase)
        n = 2
        n += 1 while taken_upcased.include?("#{base.upcase}-#{n}")
        "#{base}-#{n}"
      end
    end
  end
end
