# frozen_string_literal: true
# Noxun Engine — Debug. READ-ONLY diagnostika pre bugcatch cez MCP execute_ruby.
#
# ZASADY (zavazne):
#   - NIKDY nezapisuje do modelu, ziadne start_operation, ziadny observer zasah.
#   - Ziadna vynimka NESMIE opustit metodu — chybove stavy su stringy v hashi.
#   - Nacitatelny AJ HEADLESS (testy bez SketchUpu): kazdy odkaz na Sketchup/UI/Panel
#     je LEN vnutri metod a chraneny defined?()/rescue. Ziadny top-level Sketchup kod.
#   - Vlastne zavislosti (json, time) — nespolieha sa na main.rb ani test helper.
#
# Pouzitie (v SketchUp Ruby konzole / MCP):
#   puts Noxun::Engine::Debug.report            # kompletny JSON dump stavu
#   Noxun::Engine::Debug.entity_state(sel.first) # konkretna entita
require 'json'
require 'time'

module Noxun
  module Engine
    module Debug
      # NOXUN dictionary — zdroj pravdy je Store::DICT; fallback konstanta pre headless
      # syntax check (kde Store nemusi byt nacitany).
      def self.dict_name
        defined?(Store) && defined?(Store::DICT) ? Store::DICT : 'NOXUN'
      end

      # Ploche skalarne kluce NOXUN dict (standard 2.1). Whitelist pre fallback cez
      # get_attribute (headless FakeEntity nema attribute_dictionary). V SketchUpe sa
      # pouzije attribute_dictionary a dostane VSETKY kluce vratane buducich.
      KNOWN_KEYS = %w[std kind id part_id part_key part_key_schema cabinet_id template_id
                      role role_key name manufactured production_class config].freeze

      module_function

      # --- verejne API -------------------------------------------------------

      # Zakladny stav aktivneho modelu. Headless / bez modelu -> {error:...}.
      def model_info
        m = active_model
        return { error: 'Sketchup nedostupny (headless alebo bez modelu)' } if m.nil?

        title = safe(:'model.title') { m.title.to_s }
        path  = safe(:'model.path') { m.path.to_s }
        {
          path: path,
          title: title,
          entity_count: safe(:entity_count) { m.entities.length },
          definitions_count: safe(:definitions_count) { m.definitions.length },
          sandbox: sandbox?(m, path)
        }
      rescue StandardError => e
        err(e)
      end

      # Dump NOXUN dictionary jednej entity (Group/ComponentInstance). config JSON
      # sa parsne do 'config_parsed'. Instancia a definicia su STRIKTNE oddelene
      # (standard 2.2: definicia = len template default, NIKDY sa nemerguje do instancie).
      def entity_state(entity)
        return { error: 'nil entita' } if entity.nil?
        unless entity.respond_to?(:get_attribute) || entity.respond_to?(:attribute_dictionary)
          return { error: "nepodporovany typ (bez dict pristupu): #{safe_class(entity)}" }
        end

        out = {
          class: safe_class(entity),
          entity_id: safe(:entity_id) { entity.entityID if entity.respond_to?(:entityID) },
          valid: safe(:valid) { entity.valid? if entity.respond_to?(:valid?) },
          instance_attributes: read_dict(entity)
        }
        if entity.respond_to?(:definition)
          defn = safe(:definition) { entity.definition }
          out[:definition_name] = safe(:'definition.name') { defn.name if defn.respond_to?(:name) } if defn
          out[:definition_attributes] = defn ? read_dict(defn) : nil
        else
          out[:definition_attributes] = :absent # headless / dielec bez definicie
        end
        out
      rescue StandardError => e
        err(e)
      end

      # Stav vyberu — VZDY pole entity_state pod klucom :entities. Prazdny vyber -> note.
      def selection_state
        m = active_model
        return { error: 'Sketchup nedostupny (headless alebo bez modelu)' } if m.nil?

        sel = safe(:selection) { m.selection.to_a }
        sel = [] unless sel.is_a?(Array)
        return { count: 0, entities: [], note: 'prazdny vyber' } if sel.empty?

        { count: sel.length, entities: sel.map { |e| entity_state(e) } }
      rescue StandardError => e
        err(e)
      end

      # Stav Inspector panela BEZ volania jeho logiky — len citanie modulovych ivarov
      # (class << self) cez instance_variable_get. Chybajuci ivar -> :absent.
      def panel_state
        return { error: 'Panel nenacitany (UI vrstva)' } unless defined?(Panel)

        {
          dialog_present: !ivar(Panel, :@dialog).nil?,
          dialog_visible: safe(:dialog_visible) { d = ivar(Panel, :@dialog); !d.nil? && d.visible? },
          insert_locks: ivar_or_absent(Panel, :@insert_locks),
          active_zone_id: ivar_or_absent(Panel, :@active_zone_id),
          observer_attached: !ivar(Panel, :@observer).nil?,
          observer_model: model_ref(ivar(Panel, :@observer_model)),
          suspend_selection_sync: ivar_or_absent(Panel, :@suspend_selection_sync)
        }
      rescue StandardError => e
        err(e)
      end

      # Jeden vstupny bod pre agenta — kompletny JSON dump. Nikdy nehodi vynimku:
      # cela struktura ide cez json_safe (symboly, neserializovatelne objekty, NaN/Inf
      # sa prevedu na bezpecny tvar) pred JSON.pretty_generate.
      def report
        data = {
          engine_version: engine_version,
          timestamp: safe(:timestamp) { Time.now.strftime('%Y-%m-%d %H:%M:%S') },
          model: model_info,
          selection: selection_state,
          panel: panel_state
        }
        JSON.pretty_generate(json_safe(data))
      rescue StandardError => e
        JSON.pretty_generate('error' => "#{e.class}: #{e.message}")
      end

      # --- interne pomocne ---------------------------------------------------

      # Aktivny model alebo nil (headless / API nedostupne / ziadny model).
      def active_model
        return nil unless defined?(Sketchup) && Sketchup.respond_to?(:active_model)

        Sketchup.active_model
      rescue StandardError
        nil
      end

      # Verzia pluginu z konstanty modulu Engine (headless stub ju definuje tiez).
      def engine_version
        return Engine::VERSION if defined?(Engine::VERSION)
        return VERSION if defined?(VERSION)

        'unknown'
      rescue StandardError
        'unknown'
      end

      # Konzervativna sandbox heuristika — zladena s guard_model? (tests/sketchup/
      # su_runner.rb): testovaci je (a) model ENGINEtests*.skp, alebo (b) NEULOZENY
      # model BEZ jedineho NOXUN korpusu/dosky. Pri nemoznosti overit -> false
      # (radsej falosne "nie sandbox" nez falosne zelena na zakazke).
      def sandbox?(model, path)
        base = path.to_s.tr('\\', '/').downcase.split('/').last.to_s
        return true if base.start_with?('enginetests')
        return false unless path.to_s.strip.empty? # ulozeny model != enginetests -> nie sandbox

        noxun_free?(model)
      rescue StandardError
        false
      end

      # Nema model (top-level) ziadny NOXUN korpus ani dosku? Lacny scan model.entities.
      def noxun_free?(model)
        return false unless model.respond_to?(:entities)

        model.entities.each do |e|
          next unless e.respond_to?(:get_attribute)

          k = e.get_attribute(dict_name, 'kind')
          return false if k == 'cabinet' || k == 'board'
        end
        true
      rescue StandardError
        false
      end

      # Precita NOXUN dict entity do Hashu (string kluce, JSON-safe hodnoty). Skusi
      # attribute_dictionary (vsetky kluce), fallback na get_attribute + KNOWN_KEYS.
      # config sa doplni ako 'config_parsed'. Prazdny/ziadny dict -> nil.
      def read_dict(entity)
        raw = dict_via_dictionary(entity) || dict_via_getters(entity)
        return nil if raw.nil? || raw.empty?

        raw['config_parsed'] = parse_config(raw['config']) if raw.key?('config')
        raw
      rescue StandardError => e
        err(e)
      end

      def dict_via_dictionary(entity)
        return nil unless entity.respond_to?(:attribute_dictionary)

        d = entity.attribute_dictionary(dict_name, false)
        return nil if d.nil?

        h = {}
        d.each_pair { |k, v| h[k.to_s] = json_safe(v) }
        h
      rescue StandardError
        nil
      end

      def dict_via_getters(entity)
        return nil unless entity.respond_to?(:get_attribute)

        h = {}
        KNOWN_KEYS.each do |k|
          v = entity.get_attribute(dict_name, k)
          h[k] = json_safe(v) unless v.nil?
        end
        h
      rescue StandardError
        nil
      end

      # config MUSI byt JSON string; nie-string aj poskodeny JSON sa zachovaju
      # diagnosticky (nie tichy rescue) ako {error, raw}.
      def parse_config(raw)
        return nil if raw.nil?
        return { 'error' => "config nie je String (#{raw.class})", 'raw' => raw.to_s[0, 200] } unless raw.is_a?(String)

        JSON.parse(raw)
      rescue StandardError => e
        { 'error' => "config parse: #{e.message}", 'raw' => raw.to_s[0, 200] }
      end

      # Lahka referencia na model (path/title stringy) — pre panel @observer_model.
      # NIKDY nevracia surovy Sketchup::Model (nie je JSON-safe).
      def model_ref(m)
        return nil if m.nil?

        {
          path: safe(:'ref.path') { m.path.to_s if m.respond_to?(:path) },
          title: safe(:'ref.title') { m.title.to_s if m.respond_to?(:title) }
        }
      rescue StandardError
        { error: 'model ref nedostupna' }
      end

      # instance_variable_get s rescue -> nil pri chybe.
      def ivar(obj, name)
        obj.instance_variable_get(name)
      rescue StandardError
        nil
      end

      # instance_variable_get, ale chybajuci ivar -> :absent (odlisi present-nil od chybajuceho).
      def ivar_or_absent(obj, name)
        return :absent unless obj.instance_variables.include?(name)

        obj.instance_variable_get(name)
      rescue StandardError
        :absent
      end

      # Prevedie lubovolnu hodnotu na JSON-serializovatelny tvar (symboly -> string,
      # neznamy objekt -> to_s, NaN/Infinity -> string). Chráni JSON.pretty_generate.
      def json_safe(v)
        case v
        when nil, true, false, String then v
        when Integer then v
        when Float then v.finite? ? v : v.to_s
        when Symbol then v.to_s
        when Array then v.map { |x| json_safe(x) }
        when Hash then v.each_with_object({}) { |(k, val), acc| acc[k.to_s] = json_safe(val) }
        else v.to_s
        end
      rescue StandardError
        begin
          v.to_s
        rescue StandardError
          '?'
        end
      end

      # Bezpecny wrapper — vrati hodnotu bloku, alebo popis chyby (string) namiesto vynimky.
      def safe(label = nil)
        yield
      rescue StandardError => e
        "err#{label ? "(#{label})" : ''}: #{e.class}: #{e.message}"
      end

      def safe_class(obj)
        obj.class.name
      rescue StandardError
        '?'
      end

      def err(e)
        { error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
