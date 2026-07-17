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

module Noxun
  module Engine
    module Materials
      STD  = 1
      FILE = 'materials.json'
      SUPPORTED_EDGE_THICKNESSES = [1.0, 2.0].freeze

      # Projektove default kluce v NOXUN dict na modeli (koren dedenia projekt->korpus->dielec).
      PROJECT_KEYS = %w[default_material_id default_front_material_id default_back_material_id].freeze
      PROJECT_FALLBACK = {
        'default_material_id'       => 'K009_PW_DTDL_18', # korpus (doska 18)
        'default_front_material_id' => 'W1000_DTDL_18',   # cela (biela celova 18)
        'default_back_material_id'  => 'HDF_WHITE_3'       # chrbat (HDF 3)
      }.freeze

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

      # Najde ABS variant daneho dekoru a hrubky (mm). Pouzite pri pravidlovych defaultoch:
      # hrubka ABS podla roly, dekor podla materialu dielca. Vrati abs_id alebo nil.
      def abs_for_decor(decor, thickness)
        return nil if decor.nil?
        th = thickness.to_f
        match = edges.find { |a| a['decor'] == decor && (a['thickness'].to_f - th).abs < 0.01 }
        match && match['abs_id']
      end

      # Dekor doskoveho materialu (pre napojenie ABS na rovnaky dekor). nil ak material nie je v katalogu.
      def decor_of(material_id)
        s = sheet(material_id)
        s && s['decor']
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

      # --- normalizacia zaznamov ----------------------------------------------

      def normalize_sheet(a)
        id = (a['material_id'] || a[:material_id]).to_s
        return nil if id.strip.empty?
        {
          'material_id' => id,
          'family'      => (a['family'] || a[:family]).to_s,
          'manufacturer' => (a['manufacturer'] || a[:manufacturer]).to_s,
          'decor'       => (a['decor'] || a[:decor]).to_s,
          'type'        => (a['type'] || a[:type]).to_s,
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
        {
          'abs_id'       => id,
          'decor'        => (a['decor'] || a[:decor]).to_s,
          'thickness'    => thickness,
          'price_per_bm' => (a['price_per_bm'] || a[:price_per_bm] || 0.0).to_f,
          'color'        => normalize_rgb(a['color'] || a[:color], [216, 196, 160])
        }
      end

      def normalize_pair(v, dflt)
        return dflt unless v.is_a?(Array) && v.size == 2
        [v[0].to_f, v[1].to_f]
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
