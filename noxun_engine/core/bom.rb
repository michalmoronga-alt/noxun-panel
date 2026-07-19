# frozen_string_literal: true
# Noxun Engine — V0.5 A: kusovnik a supisy (BOM) z VYROBNYCH SNAPSHOTOV.
#
# Zdroj pravdy (standard 8.3 + Codex audit A/B1): snapshot na ENTITE —
# vnorene kind=part dielce korpusov a top-level kind=board dosky. Ziadne
# prepocitavanie planu, ziadne resolvery (hrubky/materialy/ABS su uz
# materializovane builderom vratane 18/19 cielov). Kovanie VYHRADNE
# z config.hardware[] korpusu (invariant — nikdy z geometrie/proxy).
# Warnings sa CITAJU ulozene z poslednej stavby (config['warnings']) —
# novy build_plan by pouzil globalne pravidla namiesto projektovych (F4).
#
# API (Codex F5 — collector oddeleny od cisteho vypoctu):
#   Bom.collect(model) -> {records:, hardware:, warnings:, cabinets:, boards:}
#   Bom.compute(collected) -> {rows:, sheets:, edging:, hardware:, warnings:, summary:}
# Headless testy krmia compute() zaznamami priamo (collect je tenky a vyzaduje SketchUp).
module Noxun
  module Engine
    module Bom
      EDGE_ORDER = %w[L1 L2 W1 W2].freeze
      L_EDGES = %w[L1 L2].freeze # pozdlzne hrany = dlzka dielca; W = sirka

      module_function

      # --- zber z modelu (tenky, SketchUp-only) ----------------------------

      def collect(model)
        records = []
        hardware = []
        warnings = []
        cabinets = 0
        boards = 0
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          case Store.kind(inst)
          when 'cabinet'
            cabinets += 1
            cid = Store.get(inst, 'cabinet_id').to_s
            ccfg = Store.config(inst) || {}
            Array(ccfg['hardware']).each { |h| hardware << h.merge('owner_id' => cid, 'owner_pid' => inst.persistent_id) }
            Array(ccfg['warnings']).each { |w| warnings << (w.is_a?(Hash) ? w.merge('owner_id' => cid) : { 'message' => w.to_s, 'owner_id' => cid }) }
            inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
              next unless Store.kind(pi) == 'part'
              next unless Store.get(pi, 'manufactured') == true
              next unless Store.get(pi, 'production_class').to_s == 'sheet'
              records << record(Store.config(pi) || {}, owner_id: cid,
                                name: Store.get(pi, 'name').to_s,
                                part_key: Store.get(pi, 'part_key').to_s,
                                pid: pi.persistent_id)
            end
          when 'board'
            boards += 1
            next unless Store.get(inst, 'manufactured') == true
            bcfg = Store.config(inst) || {}
            records << record(bcfg, owner_id: Store.get(inst, 'id').to_s,
                              name: (bcfg['name'] || 'Doska').to_s,
                              part_key: Store.get(inst, 'part_key').to_s,
                              pid: inst.persistent_id)
          when 'part'
            # Codex GH #47 P2: odpojeny/vytiahnuty vyrobny dielec priamo v modeli
            # (standard 01: detached dielce ostavaju citatelne pre BOM). Vlastnika
            # drzi povodne cabinet_id v atributoch.
            next unless Store.get(inst, 'manufactured') == true
            next unless Store.get(inst, 'production_class').to_s == 'sheet'
            records << record(Store.config(inst) || {},
                              owner_id: Store.get(inst, 'cabinet_id').to_s,
                              name: Store.get(inst, 'name').to_s,
                              part_key: Store.get(inst, 'part_key').to_s,
                              pid: inst.persistent_id)
          end
        end
        { records: records, hardware: hardware, warnings: warnings,
          cabinets: cabinets, boards: boards }
      end

      # Normalizovany zaznam zo snapshot configu (mm Float; edges mapa L1..W2 -> abs_id|nil).
      # pid = SketchUp persistent_id zdrojovej instancie (Codex B3 — jednoznacna adresa
      # pre klik-select aj pri docasne zdielanych ID pred dedup tickom); v headless
      # fixtures moze byt nil.
      def record(cfg, owner_id:, name:, part_key:, pid: nil)
        edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : {}
        {
          'name' => name, 'part_key' => part_key, 'owner_id' => owner_id, 'pid' => pid,
          'length' => cfg['length'].to_f, 'width' => cfg['width'].to_f,
          'thickness' => cfg['thickness'].to_f,
          'quantity' => [cfg['quantity'].to_i, 1].max,
          'material_id' => cfg['material_id'].to_s,
          'grain_direction' => (cfg['grain_direction'] || 'none').to_s,
          'edges' => EDGE_ORDER.each_with_object({}) { |c, out| out[c] = edges[c] }
        }
      end

      # --- cisty vypocet (headless) ----------------------------------------

      def compute(collected)
        records = Array(collected[:records])
        rows = aggregate_rows(records)
        {
          rows: rows,
          sheets: sheet_totals(records),
          edging: edging_totals(records),
          hardware: hardware_totals(Array(collected[:hardware])),
          warnings: Array(collected[:warnings]),
          summary: summary(collected, records, rows)
        }
      end

      # Agregacia podla VYROBNYCH parametrov (nie nazvu — zrkadlove dielce sa
      # zluia). Kluc: desatiny mm ako cele cisla (F6 — ziadne Float kluce).
      def aggregate_rows(records)
        groups = {}
        records.each do |r|
          key = row_key(r)
          g = groups[key] ||= { 'key' => key,
                                'length' => r['length'], 'width' => r['width'],
                                'thickness' => r['thickness'], 'material_id' => r['material_id'],
                                'edges' => r['edges'], 'grain_direction' => r['grain_direction'],
                                'quantity' => 0, 'names' => [], 'kde' => {}, 'refs' => [] }
          g['quantity'] += r['quantity']
          g['names'] << r['name'] unless r['name'].empty? || g['names'].include?(r['name'])
          g['kde'][r['owner_id']] = (g['kde'][r['owner_id']] || 0) + r['quantity']
          g['refs'] << { 'pid' => r['pid'], 'owner_id' => r['owner_id'] } # klik-select adresy (davka B)
        end
        groups.values.map do |g|
          g.merge('kde' => g['kde'].map { |oid, q| { 'owner_id' => oid, 'quantity' => q } })
        end.sort_by { |g| [g['material_id'], -g['length'], -g['width']] }
      end

      # Deterministicky kluc riadku — klik-select ho posiela NAMIESTO pids
      # (Codex GH #48 P2: flush editov rebuildne korpus a pids zomru; Ruby si
      # podla kluca najde CERSTVE refs po flushi).
      def row_key(r)
        [dmm(r['length']), dmm(r['width']), dmm(r['thickness']),
         r['material_id'], EDGE_ORDER.map { |c| r['edges'][c].to_s },
         r['grain_direction']]
      end

      # m2 per doskovy material — scitane z KAZDEHO zdrojoveho dielca (F6).
      def sheet_totals(records)
        out = {}
        records.each do |r|
          s = out[r['material_id']] ||= { 'material_id' => r['material_id'], 'm2' => 0.0, 'quantity' => 0 }
          s['m2'] += (r['length'] / 1000.0) * (r['width'] / 1000.0) * r['quantity']
          s['quantity'] += r['quantity']
        end
        out.values.each { |s| s['m2'] = s['m2'].round(3) }.sort_by { |s| s['material_id'] }
      end

      # bm per ABS material — L hrany = dlzka dielca, W hrany = sirka; x pocet.
      def edging_totals(records)
        out = {}
        records.each do |r|
          EDGE_ORDER.each do |code|
            abs_id = r['edges'][code]
            next if abs_id.nil? || abs_id.to_s.empty?
            mm = L_EDGES.include?(code) ? r['length'] : r['width']
            e = out[abs_id] ||= { 'abs_id' => abs_id, 'bm' => 0.0, 'edges' => 0 }
            e['bm'] += (mm / 1000.0) * r['quantity']
            e['edges'] += r['quantity']
          end
        end
        out.values.each { |e| e['bm'] = e['bm'].round(2) }.sort_by { |e| e['abs_id'] }
      end

      # Nakupne riadky kovania: generic_type + variant + PARAMS (Codex B2 —
      # nohy s roznou vyskou / vysuvy s roznou NL sa NESMU zliat); rule/source
      # ostava v breakdowne per korpus.
      def hardware_totals(items)
        out = {}
        items.each do |h|
          params = h['params'].is_a?(Hash) ? h['params'] : {}
          key = hw_key(h)
          g = out[key] ||= { 'key' => key,
                             'generic_type' => h['generic_type'].to_s,
                             'variant_id' => h['variant_id'],
                             'params' => params, 'quantity' => 0, 'breakdown' => [] }
          q = h['quantity'].to_i
          g['quantity'] += q
          g['breakdown'] << { 'owner_id' => h['owner_id'].to_s, 'owner_pid' => h['owner_pid'],
                              'rule_id' => h['rule_id'].to_s,
                              'source' => h['source'].to_s, 'quantity' => q,
                              'owner_part_key' => h['owner_part_key'] }
        end
        out.values.sort_by { |g| [g['generic_type'], params_signature(g['params'])] }
      end

      def params_signature(params)
        params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}=#{v.is_a?(Float) ? v.round(2) : v}" }.join('|')
      end

      def hw_key(h)
        params = h['params'].is_a?(Hash) ? h['params'] : {}
        [h['generic_type'].to_s, h['variant_id'].to_s, params_signature(params)]
      end

      # summary.rows = agregovane riadky; summary.quantity = suma kusov (N8).
      def summary(collected, records, rows)
        {
          'cabinets' => collected[:cabinets].to_i, 'boards' => collected[:boards].to_i,
          'records' => records.length, 'rows' => rows.length,
          'quantity' => records.sum { |r| r['quantity'] },
          'm2_total' => records.sum { |r| (r['length'] / 1000.0) * (r['width'] / 1000.0) * r['quantity'] }.round(3),
          'bm_total' => edging_totals(records).sum { |e| e['bm'] }.round(2),
          'hardware_quantity' => Array(collected[:hardware]).sum { |h| h['quantity'].to_i }
        }
      end

      # kluc v desatinach mm — stabilny voci Float driftu configov
      def dmm(v)
        (v.to_f * 10).round
      end
    end
  end
end
