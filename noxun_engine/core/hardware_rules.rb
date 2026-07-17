# frozen_string_literal: true
# Noxun Engine — pravidla kovania (V0.4 faza 1, standard sekcia 6.2 two-phase).
# CISTO Ruby (ziadne SketchUp API v evaluacii) — headless testovatelne.
#
# ============================ ARCHITEKTURA ============================
# Faza 1 = GENERICKE FLAGY: pravidla urcia TYP (leg/hinge/slide...) a POCET.
# Konkretny produkt/kod (variant_id) mapuje az faza 2 (V0.6 katalog).
#
# Ziadny univerzalny vypoctovy jazyk v JSON. Maly katalog Ruby VZOROV (kind),
# parametrizovanych JSON pravidlami:
#   fixed      — pevny pocet (nohy: 4)
#   bands      — pasma podla 1 vstupu, max je VRATANE (vyska cela <= 900 -> 2 panty)
#   fit_series — najvacsia hodnota radu <= (vstup - clearance); vysledok ide do
#                params['nominal_length'] (vysuv NL podla svetlej hlbky)
# Nova kategoria kovania = spravidla len novy JSON zaznam; novy kind az pri novej logike.
# VEDOME OBMEDZENIE fazy 1: vystup je vzdy production_class 'counted' (pocitane kusy).
# Dlzkove kovanie (gola profily = 'linear' s vyrobnou dlzkou) a polozky viazane na
# DVOJICU dielcov pridu s vlastnym kind — obalka polozky (params) ich unesie.
#
# ====================== ZDROJE PRAVIDIEL A UNDO =======================
# 1) GLOBALNA kniznica: %APPDATA%\NOXUN\Engine\hardware_rules.json (+.bak, seed pri
#    prvom spusteni) — je LEN default pre nove projekty.
# 2) PROJEKTOVY SNAPSHOT: NOXUN dict na MODELI, kluc 'hardware_rules' (vzor
#    Materials.project_defaults). Rebuild cita VYHRADNE snapshot — vysledok stavby
#    je reprodukovatelny z .skp suboru (iny pocitac, zmena globalu, kopie skriniek).
#    ensure_project_rules! zapisuje snapshot VNUTRI prebiehajucej operacie buildera,
#    takze undo vrati model aj pravidla konzistentne (Codex audit K2/K3).
#
# ============================ TVAR PRAVIDLA ===========================
# { "rule_id": "zavesy-podla-vysky", "enabled": true,
#   "applies_to": { "role": "front_door" },            # 'cabinet' alebo rola dielca
#   "output": "hinge",                                  # BuildPlan::GENERIC_TYPES
#   "kind": "bands", "input": "height",
#   "bands": [ {"max": 900, "quantity": 2}, ... {"max": null, "quantity": 5} ] }
# applies_to.role == 'cabinet' moze mat "support": ["legs","plinth"] — filter podla
# typu podopretia (Construction.support_type). Volitelne "params_from_context":
# {"height": "floor_height"} — deklarativne doplnenie params z kontextu korpusu.
#
# Vstup (input) pri role dielca: 'height'/'width' = prod rozmery dielca (vyska cela);
# ostatne kluce sa beru z kontextu korpusu (width/height/depth/floor_height/
# available_depth/available_height/available_width).
#
# ============================== OVERRIDE ==============================
# cfg[:hardware_overrides] (pole v configu korpusu, prezije rebuild ako part_overrides):
#   { "owner_part_key": null|"front:F1/wing:left", "generic_type": "hinge",
#     "rule_id": "zavesy-podla-vysky", "quantity": 6 }   alebo   "disabled": true
# Identita override = TROJICA (owner_part_key, generic_type, rule_id) — dve pravidla
# s rovnakym outputom na tom istom ownerovi su adresovatelne samostatne (audit K1).
# disabled vitazi nad quantity; posledny duplicitny match vyhrava (normalize deduplikuje).
# Polozka po override nesie source='manual' + rule_quantity (povodny pocet z pravidla).
require 'json'
require 'fileutils'

module Noxun
  module Engine
    module HardwareRules
      STD          = 1 # verzia formatu suboru pravidiel (doc: std/seed_version/rules)
      SEED_VERSION = 1 # verzia seed sady — buduce doplnanie novych default pravidiel (PR C)
      FILE         = 'hardware_rules.json'
      MODEL_KEY    = 'hardware_rules' # kluc snapshotu v NOXUN dict na modeli

      KINDS = %w[fixed bands fit_series].freeze

      # Kontextove kluce povolene ako input/params_from_context (dokumentacia tvaru ctx).
      CONTEXT_KEYS = %w[width height depth floor_height available_depth
                        available_height available_width].freeze

      SEED_RULES = [
        { 'rule_id' => 'nohy-zakladne', 'enabled' => true,
          'applies_to' => { 'role' => 'cabinet', 'support' => %w[legs plinth] },
          'output' => 'leg', 'kind' => 'fixed', 'quantity' => 4,
          'params_from_context' => { 'height' => 'floor_height' } },
        { 'rule_id' => 'zavesy-podla-vysky', 'enabled' => true,
          'applies_to' => { 'role' => 'front_door' },
          'output' => 'hinge', 'kind' => 'bands', 'input' => 'height',
          'bands' => [
            { 'max' => 900.0,  'quantity' => 2 },
            { 'max' => 1400.0, 'quantity' => 3 },
            { 'max' => 1900.0, 'quantity' => 4 },
            { 'max' => nil,    'quantity' => 5 }
          ] },
        { 'rule_id' => 'vysuvy-nl-podla-hlbky', 'enabled' => true,
          'applies_to' => { 'role' => 'drawer_front' },
          'output' => 'slide', 'kind' => 'fit_series', 'input' => 'available_depth',
          'series' => [270.0, 300.0, 350.0, 400.0, 450.0, 470.0, 500.0,
                       520.0, 550.0, 580.0, 620.0, 650.0],
          'clearance' => 10.0, 'quantity' => 1 }
      ].freeze

      module_function

      # --- globalna kniznica (%APPDATA%) — default pre nove projekty ----------

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita globalnu kniznicu ako normalizovane pole pravidiel. Poskodeny/chybajuci
      # subor -> seed (vzor AbsRules: fallback nikdy nevrati nil).
      def load
        ensure_seeded
        doc = JsonFileStore.read(path, copy: false)
        rules = doc.is_a?(Hash) ? doc['rules'] : nil
        return deep_copy(SEED_RULES) unless rules.is_a?(Array)
        normalize_rules(rules)
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.load') if defined?(Engine)
        deep_copy(SEED_RULES)
      end

      def ensure_seeded
        return if JsonFileStore.available?(path)
        write(deep_copy(SEED_RULES))
      end

      def write(rules)
        JsonFileStore.write(path, { 'std' => STD, 'seed_version' => SEED_VERSION,
                                    'rules' => normalize_rules(rules) })
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.write') if defined?(Engine)
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- projektovy snapshot (NOXUN dict na modeli) -------------------------

      # Pravidla projektu alebo nil, ak model snapshot nema (poskodeny JSON = nil + log).
      def project_rules(model)
        return nil unless model
        raw = model.get_attribute(Store::DICT, MODEL_KEY)
        return nil if raw.nil? || raw.to_s.strip.empty?
        doc = JSON.parse(raw.to_s)
        rules = doc.is_a?(Hash) ? doc['rules'] : nil
        rules.is_a?(Array) ? normalize_rules(rules) : nil
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.project_rules') if defined?(Engine)
        nil
      end

      # Vrati pravidla projektu; ak snapshot chyba, zapise don globalnu kniznicu.
      # VOLAT LEN vnutri otvorenej operacie (build/rebuild) — zapis je sucastou
      # undo kroku, ktory snapshot prvykrat potreboval.
      def ensure_project_rules!(model)
        existing = project_rules(model)
        return existing if existing
        rules = load
        set_project_rules(model, rules) if model
        rules
      end

      # Zapise projektovy snapshot (editor pravidiel / ensure). Volajuci drzi operaciu.
      def set_project_rules(model, rules)
        return false unless model
        doc = { 'std' => STD, 'seed_version' => SEED_VERSION, 'rules' => normalize_rules(rules) }
        model.set_attribute(Store::DICT, MODEL_KEY, doc.to_json)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HardwareRules.set_project_rules') if defined?(Engine)
        false
      end

      # --- evaluacia ----------------------------------------------------------

      # Vyhodnoti pravidla nad planom korpusu. CISTA funkcia (ziadne IO):
      #   cfg   — normalizovana konfiguracia korpusu (kvoli hardware_overrides)
      #   parts — ZIVE dielce planu (PO vyradeni degenerovanych — na mrtve celo
      #           nesmie vzniknut kovanie)
      #   ctx   — string-keyed kontext korpusu (CONTEXT_KEYS + 'support')
      #   rules — normalizovane pole pravidiel (projektovy snapshot / test injection)
      # Vrati { items: [hw string-keyed], warnings: [] }. Poradie deterministicke:
      # pravidla v poradi kniznice, dielce v poradi planu.
      def evaluate(cfg, parts, ctx, rules:)
        items = []
        warnings = []
        seen_ids = {}
        Array(rules).each do |rule|
          next unless rule.is_a?(Hash)
          rid = rule['rule_id'].to_s
          next if rid.empty?
          if seen_ids[rid]
            warnings << BuildPlan.warning('hardware_rule_duplicate',
                                          "Pravidlo kovania '#{rid}' je v knižnici viackrát — použité je prvé.",
                                          severity: 'info', data: { 'rule_id' => rid })
            next
          end
          seen_ids[rid] = true
          next if rule['enabled'] == false
          unless KINDS.include?(rule['kind'].to_s) && BuildPlan::GENERIC_TYPES.include?(rule['output'].to_s)
            warnings << BuildPlan.warning('hardware_rule_skipped',
                                          "Pravidlo kovania '#{rid}' má neznámy kind/output — preskočené (novšia verzia pravidiel?).",
                                          severity: 'info',
                                          data: { 'rule_id' => rid, 'kind' => rule['kind'].to_s,
                                                  'output' => rule['output'].to_s })
            next
          end
          apply_rule(rule, cfg, parts, ctx, items, warnings)
        end
        { items: apply_overrides(items, cfg[:hardware_overrides]), warnings: warnings }
      end

      # Aplikuje jedno pravidlo: korpusova uroven (owner nil) alebo per dielec roly.
      def apply_rule(rule, _cfg, parts, ctx, items, warnings)
        role = (rule['applies_to'] || {})['role'].to_s
        if role == 'cabinet'
          supports = Array((rule['applies_to'] || {})['support']).map(&:to_s)
          return if supports.any? && !supports.include?(ctx['support'].to_s)
          emit(rule, nil, ctx, nil, items, warnings)
        else
          parts.each do |pd|
            next unless pd[:role].to_s == role
            emit(rule, PartKeys.for_descriptor(pd), ctx, pd, items, warnings)
          end
        end
      end

      # Vypocita pocet + params a prida polozku (string kluce — JSON round-trip
      # cez config korpusu bez konverzii, ako warnings).
      def emit(rule, owner, ctx, pd, items, warnings)
        qty, params = compute(rule, ctx, pd, owner, warnings)
        return if qty.nil?
        params = params.merge(context_params(rule, ctx))
        items << {
          'owner_part_key'   => owner,
          'generic_type'     => rule['output'].to_s,
          'quantity'         => qty,
          'rule_id'          => rule['rule_id'].to_s,
          'variant_id'       => nil,
          'production_class' => 'counted',
          'manufactured'     => true,
          'params'           => params,
          'source'           => 'rule',
          'rule_quantity'    => qty
        }
      end

      # Vzory vypoctu. Vrati [quantity, params] alebo [nil, _] = polozka nevznikne.
      def compute(rule, ctx, pd, owner, warnings)
        case rule['kind'].to_s
        when 'fixed'
          [clamp_qty(rule['quantity']), {}]
        when 'bands'
          v = input_value(rule, ctx, pd, owner, warnings)
          return [nil, {}] if v.nil?
          band = Array(rule['bands']).find { |b| b['max'].nil? || v <= b['max'].to_f }
          if band.nil?
            warnings << BuildPlan.warning('hardware_rule_skipped',
                                          "Pravidlo '#{rule['rule_id']}' nemá pásmo pre hodnotu #{v.round(1)} — položka nevznikla.",
                                          part_key: owner, severity: 'info',
                                          data: { 'rule_id' => rule['rule_id'].to_s, 'value' => v })
            return [nil, {}]
          end
          [clamp_qty(band['quantity']), {}]
        when 'fit_series'
          v = input_value(rule, ctx, pd, owner, warnings)
          return [nil, {}] if v.nil?
          budget = v - rule['clearance'].to_f
          nl = Array(rule['series']).map(&:to_f).select { |s| s <= budget }.max
          if nl.nil?
            warnings << BuildPlan.warning('hardware_no_fit',
                                          "#{label_for(rule['output'])}: do svetlej hĺbky #{v.round(1)} mm sa nezmestí žiadna dĺžka z radu (rezerva #{rule['clearance'].to_f.round(1)} mm).",
                                          part_key: owner,
                                          data: { 'rule_id' => rule['rule_id'].to_s, 'available' => v,
                                                  'clearance' => rule['clearance'].to_f })
            return [nil, {}]
          end
          [clamp_qty(rule.fetch('quantity', 1)), { 'nominal_length' => nl }]
        end
      end

      # Hodnota vstupu: prod rozmery dielca (height/width cela) pred kontextom korpusu.
      def input_value(rule, ctx, pd, owner, warnings)
        input = rule['input'].to_s
        v =
          if pd && input == 'height'
            pd[:prod] && pd[:prod][:length]
          elsif pd && input == 'width'
            pd[:prod] && pd[:prod][:width]
          else
            ctx[input]
          end
        return v.to_f if v.is_a?(Numeric)
        warnings << BuildPlan.warning('hardware_rule_skipped',
                                      "Pravidlo '#{rule['rule_id']}' má neznámy vstup '#{input}' — preskočené.",
                                      part_key: owner, severity: 'info',
                                      data: { 'rule_id' => rule['rule_id'].to_s, 'input' => input })
        nil
      end

      # Deklarativne params z kontextu: {"height": "floor_height"} -> params['height']=ctx['floor_height'].
      def context_params(rule, ctx)
        map = rule['params_from_context']
        return {} unless map.is_a?(Hash)
        map.each_with_object({}) do |(target, source), out|
          v = ctx[source.to_s]
          out[target.to_s] = v.to_f if v.is_a?(Numeric)
        end
      end

      # Rucne zasahy z configu korpusu. Match = (owner, generic_type, rule_id);
      # disabled -> polozka von; quantity -> prepis + source 'manual' (rule_quantity ostava).
      def apply_overrides(items, overrides)
        list = Array(overrides).select { |ov| ov.is_a?(Hash) }
        return items if list.empty?
        items.filter_map do |it|
          ov = list.select { |o| override_match?(o, it) }.last
          next it unless ov
          next nil if ov['disabled'] == true
          q = clamp_qty(ov['quantity'])
          next it if q.nil?
          # ZAMERNE aj pri q == rule_quantity: kym zaznam existuje v configu, polozka
          # MUSI byt oznacena source 'manual' (UI ukaze reset). Inak by override splynul
          # s pravidlom, reset by zmizol a stale zaznam by necakane ozil pri buducej
          # zmene pravidla ci rozmerov (Codex review PR #24).
          it.merge('quantity' => q, 'source' => 'manual')
        end
      end

      def override_match?(ov, item)
        owner = ov.key?('owner_part_key') ? ov['owner_part_key'] : ov[:owner_part_key]
        owner = nil if owner.to_s.empty?
        owner == item['owner_part_key'] &&
          ov['generic_type'].to_s == item['generic_type'] &&
          ov['rule_id'].to_s == item['rule_id']
      end

      # --- normalizacia -------------------------------------------------------

      # Ocisti pole pravidiel: string kluce, cisla ako Float/Integer, bands sort
      # (null=∞ posledne), series sort+uniq bez nekladnych. Nezname kluce zachova
      # (forward-compat s buducimi verziami formatu).
      def normalize_rules(rules)
        Array(rules).filter_map do |rule|
          next nil unless rule.is_a?(Hash)
          r = deep_copy(stringify(rule))
          next nil if r['rule_id'].to_s.strip.empty?
          r['rule_id'] = r['rule_id'].to_s.strip
          r['enabled'] = r['enabled'] != false
          r['output'] = r['output'].to_s.strip
          r['kind'] = r['kind'].to_s.strip
          r['applies_to'] = r['applies_to'].is_a?(Hash) ? r['applies_to'] : {}
          r['quantity'] = clamp_qty(r['quantity']) || 1 if r.key?('quantity')
          if r['bands'].is_a?(Array)
            bands = r['bands'].select { |b| b.is_a?(Hash) && !clamp_qty(b['quantity']).nil? }
                              .map { |b| { 'max' => (b['max'].nil? ? nil : b['max'].to_f),
                                           'quantity' => clamp_qty(b['quantity']) } }
            r['bands'] = bands.sort_by { |b| b['max'].nil? ? Float::INFINITY : b['max'] }
          end
          if r['series'].is_a?(Array)
            r['series'] = r['series'].map(&:to_f).select(&:positive?).uniq.sort
          end
          r['clearance'] = r['clearance'].to_f if r.key?('clearance')
          r
        end
      end

      # Pocet vzdy Integer v <1, MAX_HW_QUANTITY>; nil pri nevalidnom vstupe.
      def clamp_qty(v)
        return nil if v.nil? || v.to_s.strip.empty?
        q = v.to_i
        return nil if q < 1
        [q, BuildPlan::MAX_HW_QUANTITY].min
      end

      def label_for(generic_type)
        { 'leg' => 'Nohy', 'hinge' => 'Závesy', 'slide' => 'Výsuv',
          'handle' => 'Úchytky', 'shelf_pin' => 'Podperky', 'connector' => 'Spojky' }[generic_type.to_s] || generic_type.to_s
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
