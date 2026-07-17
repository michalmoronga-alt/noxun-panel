# frozen_string_literal: true
# Noxun Engine — sklad sablon korpusov. Perzistencia JSON v %APPDATA%\NOXUN\Engine\
# + .bak zaloha pri zapise (pattern z DC Control). Sablona = meno + konstrukcny config
# (BEZ id/cabinet_id) — typ, rozmery, konstrukcia, delenie zon, cela.
require 'json'
require 'fileutils'

module Noxun
  module Engine
    module TemplateStore
      STD  = 1
      FILE = 'templates.json'

      module_function

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita pole { 'name' => ..., 'config' => {...} }. Pri prvom spusteni zapise predvolene.
      def load
        ensure_seeded
        data = JsonFileStore.read(path, copy: false)
        list = data['templates']
        JsonFileStore.deep_copy(list.is_a?(Array) ? list : build_predefined)
      rescue StandardError => e
        Engine.log_error(e, 'TemplateStore.load')
        build_predefined
      end

      def find(name)
        load.find { |t| t['name'] == name }
      end

      # Prida/prepise sablonu podla mena. Vrati true.
      def upsert(name, config)
        list = load.reject { |t| t['name'] == name }
        list << { 'name' => name.to_s, 'config' => config }
        write_list(list)
      end

      def delete(name)
        write_list(load.reject { |t| t['name'] == name })
      end

      # --- perzistencia --------------------------------------------------------

      def ensure_seeded
        return if JsonFileStore.available?(path)
        write_list(build_predefined)
      end

      # Zapis so zalohou: existujuci subor -> .bak, novy cez .tmp + atomicky rename.
      def write_list(list)
        JsonFileStore.write(path, { 'std' => STD, 'templates' => list })
      rescue StandardError => e
        Engine.log_error(e, 'TemplateStore.write_list')
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- predvolene sablony (konstrukcne presety) ---------------------------

      def build_predefined
        [
          tpl('Dolna klasik', lower_base('top_mode' => 'two_rails', 'rails_orientation' => 'flat')),
          tpl('Drezova',      lower_base('top_mode' => 'two_rails', 'rails_orientation' => 'upright')),
          tpl('Varna doska',  lower_base('top_mode' => 'two_rails', 'rails_orientation' => 'flat',
                                         'rails_top_offset' => 20.0)),
          tpl('Horna klasik', upper_base('back_mode' => 'groove'))
        ]
      end

      def tpl(name, config)
        { 'name' => name, 'config' => config }
      end

      def lower_base(overrides = {})
        base = {
          'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'thickness' => 18.0,
          'floor_height' => 100.0, 'bottom_mode' => 'under_sides', 'top_mode' => 'full',
          'back_mode' => 'overlay', 'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 50.0,
          'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
          'zone_tree' => ZoneTree.default_tree(0), 'fronts' => Fronts.empty_config
        }
        base.merge(overrides)
      end

      def upper_base(overrides = {})
        base = {
          'type' => 'upper', 'width' => 600.0, 'height' => 720.0, 'depth' => 320.0, 'thickness' => 18.0,
          'floor_height' => 0.0, 'bottom_mode' => 'between_sides', 'top_mode' => 'full',
          'back_mode' => 'groove', 'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 50.0,
          'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
          'zone_tree' => ZoneTree.default_tree(0), 'fronts' => Fronts.empty_config
        }
        base.merge(overrides)
      end
    end
  end
end
