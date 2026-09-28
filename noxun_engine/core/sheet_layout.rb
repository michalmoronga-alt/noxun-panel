# frozen_string_literal: true
# Noxun Engine — NP-1 (blok 2 · Narezovy plan): jadro vypoctu rozlozenia
# dielcov na platne. Package: SYSTEM/zdroje/bloky/NAREZ/PACKAGE_NP1_JADRO.md.
#
# CO TO JE: cisty Ruby vypocet (ziadny SketchUp, ziadny zapis), ktory z
# agregovanych riadkov kusovnika (Bom.compute[:rows]), zaznamov katalogu
# dosiek a troch parametrov (prerez, orez, pridavok duplaku) urci PER NAKUPNY
# MATERIAL deterministicke pasove (gilotinove) rozlozenie obdlznikov na
# platne: pocet platni, vyuzitie, polohy, najvacsi zvysok, nezaradene dielce
# a priznaky neuplnosti. Je to „rozlozenie heuristiky", NIE minimum — rezanie
# robi VEPO vlastnou optimalizaciou (N2); plan sluzi objednavke (N1).
#
# JEDNA PRAVDA S VEPO: riadok prijima `VepoExport.prepare_row` (tie iste
# vyradenia, ta ista jedina vymena pri grain 'width', to iste zaokruhlenie na
# cele mm). Plan NIC dalsie neotaca — ani dielec bez smeru dekoru (N8).
#
# JEDNA PRAVDA S KONTROLOU (NP-2): `purchase_rect` robi celu rozhodujucu
# pripravu nakupneho obdlznika (prijatie, zaokruhlenie, zdroj duplaku,
# pridavok, hrubka, format, orez podla typu) a `fits_rect?` jedinu nerovnost
# „zmesti sa na prazdnu platnu". Kontrola ich zavola nad zaznamom dielca a
# nesmie ziaden z tych krokov opakovat sama.
#
# V NP-1 sa modul NIKAM nenapaja (Studio, rozpocet ani exporty ho necitaju).
require 'json'

module Noxun
  module Engine
    module SheetLayout
      # Predvolene hodnoty (N3, N7) — NP-2 ich nahradi nastaveniami rozpoctu.
      DEFAULT_KERF = 5.0          # prerez (hrubka kotuca)
      DEFAULT_TRIM = 10.0         # orez okraja platne na KAZDEJ hrane
      DEFAULT_DUP_ALLOWANCE = 10.0 # pridavok vrstvy duplaku na KAZDU stranu
      PARAM_DEFAULTS = { 'kerf' => DEFAULT_KERF, 'trim' => DEFAULT_TRIM,
                         'dup_allowance' => DEFAULT_DUP_ALLOWANCE }.freeze
      # N6/N9: typy s hotovymi hranami — BEZ orezu. Vlastna konstanta modulu:
      # `Materials.format_in_identity?` je ta ista mnozina, ale iny vyznam
      # (identita variantu), preto sa nespaja.
      NO_TRIM_TYPES = %w[PD KOMPAKT ZASTENA].freeze
      # Dovody vyradenia RIADKA (pocitaju sa do `rejected_rows`).
      REJECT_REASONS = %w[vepo invalid_row zero_after_rounding].freeze
      # Dovody nezaradenia OBDLZNIKA (zoznam `unplaced`).
      UNPLACED_REASONS = %w[oversize needs_rotation no_usable_area].freeze

      module_function

      # Jedina tolerancia rozmerov (zhodna s Kontrolou nadrozmeru).
      def tol
        Validation::DIM_TOL
      end

      # --- verejne API --------------------------------------------------------

      # rows:   Bom.compute[:rows] (agregovane vyrobne riadky; kluc 'key').
      # sheets: ProductionCore.sheets_map ({material_id => cely zaznam dosky}).
      # edge_thicknesses: TA ISTA mapa, aku dostava VEPO ({abs_id => Float}).
      # params: {'kerf', 'trim', 'dup_allowance'} (String aj Symbol kluce;
      #         chybajuci alebo nil = predvolena hodnota).
      # blocked: nil | { all: '<dovod>' } | { material_id => '<dovod>' } —
      #         neplatne vyrobne data, ktore agregacia nevidi (audit F5);
      #         kto ho sklada, urci NP-3/NP-4.
      # Vysledok: pozri docs/architecture/outputs.md (odsek sheet_layout.rb).
      # Pre datovy problem NIKDY nevyhodi vynimku.
      def compute(rows, sheets:, edge_thicknesses:, params: {}, blocked: nil)
        sheets = {} unless sheets.is_a?(Hash)
        edge_thicknesses = {} unless edge_thicknesses.is_a?(Hash)
        prm, bad = normalize_params(params)
        invalid = !bad.empty?
        # Pri neplatnych parametroch sa riadky aj tak roztriedia do nakupnych
        # materialov (aby vysledok povedal, KTORE materialy su bez planu) —
        # chybne hodnoty sa na to nahradia predvolenymi, rozlozenie nevznikne.
        work = prm.each_with_object({}) { |(k, v), o| o[k] = v.nil? ? PARAM_DEFAULTS[k] : v }

        groups = {}
        without = []
        Array(rows).each do |raw|
          r = prepare_rect(raw, sheets, edge_thicknesses, work)
          mid = r['plan_material_id']
          if mid.nil?
            without << reject_entry(r)
            next
          end
          acc = groups[mid] ||= { rows: {}, rejected: [], conflicts: [], row_mids: [],
                                  thickness_conflict: false, duplak_link_missing: false }
          rmid = r['row_material_id'].to_s
          acc[:row_mids] << rmid unless rmid.empty? || acc[:row_mids].include?(rmid)
          collect_row(acc, r)
        end

        materials = groups.keys.sort.map do |mid|
          material_result(mid, groups[mid], sheets, work, invalid, blocked)
        end
        {
          'params' => prm, 'invalid_params' => bad,
          'rejected_without_material' => without.length,
          'rejected_without_material_rows' => sort_rejects(without),
          'materials' => materials
        }
      end

      # Spolocna priprava NAKUPNEHO obdlznika z hashu tvaru riadku kusovnika
      # ALEBO zaznamu dielca (length, width, thickness, quantity, material_id,
      # edges, grain_direction, material_source). Vrati hash:
      #   'ok'              — true = obdlznik je pripraveny,
      #   'reason'          — nil | invalid_params | invalid_row | vepo |
      #                       zero_after_rounding | duplak_link_missing |
      #                       thickness_conflict,
      #   'detail'          — text dovodu VEPO (presne ako v errors/LOGu),
      #   'material_id'     — material, na ktorom je GEOMETRIA (nakupny; pri
      #                       duplaku zdroj; pri duplak_link_missing material
      #                       riadku; nil = bez materialu),
      #   'plan_material_id'— material, ktoremu plan riadok pripise (pri duplaku
      #                       vzdy zdroj — aj pri chybajucej vazbe),
      #   'row_material_id' — material riadku,
      #   'l', 'w'          — rozmer obdlznika po zaokruhleni (a s pridavkom duplaku),
      #   'count'           — pocet obdlznikov (quantity, pri duplaku x nasobok; len pri ok),
      #   'grain'           — POVODNY smer dekoru (Kontrola: `rotation_allowed?`),
      #   'sheet_size', 'usable', 'trim', 'fallback', 'uni' — format materialu geometrie.
      # GEOMETRIA (l, w, usable, trim, grain) je vyplnena aj pri ok: false, ked
      # dovod s rozmermi nesuvisi (VEPO: neznama ABS, chybna hrubka, pocet;
      # thickness_conflict; duplak_link_missing — tam vrstva BEZ pridavku na
      # materiali riadku), aby Kontrola nadrozmeru hodnotila aj taky dielec.
      # Chyba pri invalid_row, zero_after_rounding, nekladnom rozmere a bez materialu.
      def purchase_rect(hash, sheets:, edge_thicknesses:, params: {})
        prm, bad = normalize_params(params)
        unless bad.empty?
          return { 'ok' => false, 'reason' => 'invalid_params', 'material_id' => nil, 'plan_material_id' => nil }
        end

        prepare_rect(hash, sheets.is_a?(Hash) ? sheets : {},
                     edge_thicknesses.is_a?(Hash) ? edge_thicknesses : {}, prm)
      end

      # „Zmesti sa na prazdnu platnu": l <= Lu + DIM_TOL && w <= Wu + DIM_TOL.
      # rect = vysledok `purchase_rect` (staci 'l', 'w', 'usable'). Plan vola
      # VZDY allow_rotation: false (N8); Kontrola allow_rotation:
      # rotation_allowed?(rect['grain']). Pri allow_rotation: true skusa obe
      # polohy. Nepouzitelna plocha alebo chybny rect = false (nikdy vynimka).
      def fits_rect?(rect, allow_rotation: false)
        return false unless rect.is_a?(Hash)

        l = finite_f(rect['l'])
        w = finite_f(rect['w'])
        u = rect['usable']
        return false if l.nil? || w.nil? || !u.is_a?(Array) || u.length != 2

        lu = finite_f(u[0])
        wu = finite_f(u[1])
        return false if lu.nil? || wu.nil? || !usable_area?(lu, wu)

        fit_one?(l, w, lu, wu) || (allow_rotation ? fit_one?(w, l, lu, wu) : false)
      end

      # Smie Kontrola nadrozmeru dielec otocit? Ano pre vsetko okrem smeru
      # 'length' a 'width' (dnesne spravanie `Validation.fits_on_sheet?`:
      # 'none', prazdny aj neznamy smer = obe polohy). Plan NEOTACA nikdy (N8) —
      # tato funkcia mu len hovori, ci nezaradeny dielec Kontrola hlasi.
      def rotation_allowed?(grain)
        !%w[length width].include?(grain.to_s)
      end

      # Dovod nezaradenia obdlznika v PLANE (nil = zmesti sa bez otocenia):
      #   no_usable_area — orez nenechal ziadnu plochu,
      #   needs_rotation — dielec, ktory smie Kontrola otocit (bez smeru) a
      #                    zmesti sa len otoceny (plan neotaca — N8; Kontrola
      #                    ho NEHLASI),
      #   oversize       — nezmesti sa ani v polohe, ktoru pripusta Kontrola
      #                    (to iste hlasi Kontrola).
      def unplaced_reason(rect)
        u = rect['usable']
        return 'no_usable_area' unless usable_area?(u[0].to_f, u[1].to_f)
        return nil if fits_rect?(rect, allow_rotation: false)
        return 'needs_rotation' if rotation_allowed?(rect['grain']) && fits_rect?(rect, allow_rotation: true)

        'oversize'
      end

      # --- parametre ----------------------------------------------------------

      # [params, zoznam_neplatnych]. Platna hodnota = realne konecne cislo >= 0.
      # Neplatna ostane v params ako nil a jej meno pride v zozname.
      def normalize_params(params)
        params = {} if params.nil?
        unless params.is_a?(Hash)
          return [PARAM_DEFAULTS.keys.to_h { |k| [k, nil] }, PARAM_DEFAULTS.keys.dup]
        end

        out = {}
        bad = []
        PARAM_DEFAULTS.each do |name, default|
          v = params.key?(name) ? params[name] : params[name.to_sym]
          if v.nil?
            out[name] = default
          elsif (f = nonneg_f(v))
            out[name] = f
          else
            out[name] = nil
            bad << name
          end
        end
        [out, bad]
      end

      def nonneg_f(v)
        return nil unless v.is_a?(Numeric) && v.real?

        f = v.to_f
        f.finite? && f >= 0 ? f : nil
      rescue StandardError
        nil
      end

      def finite_f(v)
        return nil unless v.is_a?(Numeric)

        f = v.to_f
        f.finite? ? f : nil
      rescue StandardError
        nil
      end

      # --- priprava obdlznika --------------------------------------------------

      # Format a orez nakupneho materialu. Format = SheetEstimate.sheet_size_for
      # (jedna pravda o fallbacku 2800x2070); poradie dvojice sa NENORMALIZUJE:
      # sheet_size[0] = dlzka platne = smer kresby dekoru (STANDARD §7.1).
      def frame(mid, sheets, trim_param)
        rec = sheets[mid]
        rec = nil unless rec.is_a?(Hash)
        size, fallback = SheetEstimate.sheet_size_for(rec && rec['sheet_size'])
        trim = NO_TRIM_TYPES.include?(Materials.canonical_type(rec && rec['type'])) ? 0.0 : trim_param
        { 'sheet_size' => size, 'fallback' => fallback, 'uni' => Materials.uni?(rec), 'trim' => trim,
          'usable' => [size[0] - 2 * trim, size[1] - 2 * trim] }
      end

      def prepare_rect(hash, sheets, edge_thicknesses, prm)
        return rejected(nil, nil, 'invalid_row', nil, []) unless hash.is_a?(Hash)

        names = row_names(hash)
        rmid = hash['material_id'].to_s
        pmid, doubled, mult, link_missing = purchase_material(hash, rmid, sheets)
        return rejected(pmid, rmid, 'invalid_row', nil, names) unless sane_input?(hash)

        prep = begin
          VepoExport.prepare_row(hash, edge_thicknesses)
        rescue StandardError
          nil
        end
        return rejected(pmid, rmid, 'invalid_row', nil, names) if prep.nil?

        # C1/N7: pridavok vrstvy duplaku az PO zaokruhleni (VEPO dostava
        # zaokruhleny hotovy rozmer). Pri chybajucej vazbe sa NEdomysla —
        # geometria je vrstva bez pridavku na materiali riadku.
        p2 = doubled ? 2 * prm['dup_allowance'] : 0.0
        geo_mid = link_missing ? rmid : pmid
        geo = { hash: hash, mid: geo_mid, p2: p2, sheets: sheets, prm: prm }
        unless prep['ok']
          # dovod VEPO (ABS, hrubka, pocet): geometria z tej istej orientacie
          # a zaokruhlenia; nekladny rozmer ci chybajuci material ju nemaju.
          dims = pmid && VepoExport.rounded_dims(VepoExport.oriented(hash))
          return with_geometry(rejected(pmid, rmid, 'vepo', prep['reason'], names), dims, geo)
        end

        l, w = prep['dims']
        return rejected(pmid, rmid, 'zero_after_rounding', nil, names) if l <= 0 || w <= 0
        # B2: katalog hovori „duplak", riadok vazbu nenesie — nedomyslat.
        if link_missing
          return with_geometry(rejected(pmid, rmid, 'duplak_link_missing', nil, names), [l, w], geo)
        end
        # B1: obchodna hrubka riadku vs. nakupny material. Vrstvy duplaku maju
        # hrubku ZDROJA (su z neho rezane), preto sa pri duplaku nekontroluju.
        if !doubled && thickness_conflict?(sheets[pmid], prep['commercial'])
          return with_geometry(rejected(pmid, rmid, 'thickness_conflict', nil, names), [l, w], geo)
        end

        qty = prep['row']['quantity'].to_i
        fr = frame(pmid, sheets, prm['trim'])
        fr.merge(
          'ok' => true, 'reason' => nil, 'detail' => nil, 'material_id' => pmid, 'plan_material_id' => pmid,
          'row_material_id' => rmid, 'l' => l + p2, 'w' => w + p2, 'count' => doubled ? qty * mult : qty,
          'quantity' => qty, 'multiplier' => doubled ? mult : 1, 'doubled' => doubled,
          'grain' => hash['grain_direction'].to_s, 'commercial' => prep['commercial'],
          'key_text' => key_text(hash, prep), 'names' => names
        )
      rescue StandardError
        rejected(nil, nil, 'invalid_row', nil, [])
      end

      # Doplni do odmietnutia geometriu (l, w, format, orez, smer) — len ked
      # su oba zaokruhlene rozmery kladne a material je znamy.
      def with_geometry(rej, dims, geo)
        return rej unless dims.is_a?(Array) && geo[:mid] && dims.all? { |d| d.positive? }

        rej.merge(frame(geo[:mid], geo[:sheets], geo[:prm]['trim']))
           .merge('material_id' => geo[:mid], 'l' => dims[0] + geo[:p2], 'w' => dims[1] + geo[:p2],
                  'grain' => geo[:hash]['grain_direction'].to_s)
      end

      # [nakupny material, duplak?, nasobok, chyba_vazba?]. Uplna vazba zo
      # snapshotu (stráz ako SheetEstimate: material_id + multiplier >= 2) ->
      # zdroj. Katalogovy duplak BEZ vazby v riadku -> zdroj z katalogu, ale
      # s priznakom (riadok sa nerozklada). Riadok bez materialu -> nil.
      def purchase_material(hash, rmid, sheets)
        return [nil, false, 1, false] if rmid.strip.empty?

        ms = hash['material_source']
        mult = begin
          ms.is_a?(Hash) ? ms['multiplier'].to_i : 0
        rescue StandardError
          0
        end
        return [ms['material_id'].to_s, true, mult, false] if mult >= 2 && !ms['material_id'].to_s.empty?

        rec = sheets[rmid]
        if Materials.duplak?(rec)
          return [rec['source_material_id'].to_s.strip, false, 1, true]
        end

        [rmid, false, 1, false]
      end

      # Ochrana vstupu planu (audit F4) — VEPO sa nemeni: nekonecne/NaN
      # rozmery ci hrubka a hrany mimo tvaru {kod => id} riadok vyradia.
      def sane_input?(hash)
        %w[length width thickness].each do |k|
          v = hash[k]
          next if v.nil? || v.is_a?(String)
          return false unless v.is_a?(Numeric) && v.to_f.finite?
        end
        e = hash['edges']
        e.nil? || e.is_a?(Hash)
      end

      def thickness_conflict?(rec, commercial)
        return false unless rec.is_a?(Hash)

        t = finite_f(rec['thickness'])
        return false if t.nil? || t <= 0

        VepoExport.commercial_thickness(t) != commercial
      end

      # Kanonicky text riadku = JSON.generate(row['key']) (Bom.row_key: same
      # cele cisla a retazce -> deterministicky). Hash bez kluca (zaznam
      # dielca, fixtura) dostane nahradny kluc z pripravenych udajov.
      def key_text(hash, prep)
        key = hash['key']
        return JSON.generate(key) if key.is_a?(Array)

        row = prep['row']
        e = prep['edges']
        ms = hash['material_source']
        JSON.generate([prep['dims'][0], prep['dims'][1], prep['commercial'], row['material_id'].to_s,
                       VepoExport::EDGE_CODES.map { |c| e[c].to_s }, hash['grain_direction'].to_s,
                       ms.is_a?(Hash) ? [ms['material_id'].to_s, ms['multiplier'].to_i] : nil])
      end

      def row_names(hash)
        names = Array(hash['names']).map(&:to_s).reject(&:empty?)
        names = [hash['name'].to_s] if names.empty? && !hash['name'].to_s.empty?
        names
      end

      def rejected(pmid, rmid, reason, detail, names)
        { 'ok' => false, 'reason' => reason, 'detail' => detail, 'material_id' => pmid,
          'plan_material_id' => pmid, 'row_material_id' => rmid, 'names' => names }
      end

      def reject_entry(r)
        { 'reason' => r['reason'], 'detail' => r['detail'], 'names' => Array(r['names']) }
      end

      def sort_rejects(list)
        list.sort_by { |e| [e['reason'].to_s, e['detail'].to_s, e['names'].join('/')] }
      end

      # --- skladanie per material ----------------------------------------------

      def collect_row(acc, r)
        case r['reason']
        when nil
          k = [r['key_text'], r['l'], r['w']]
          ent = acc[:rows][k] ||= { 'key' => r['key_text'], 'names' => [], 'l' => r['l'], 'w' => r['w'],
                                    'count' => 0, 'doubled' => r['doubled'], 'rect' => r }
          ent['count'] += r['count']
          r['names'].each { |n| ent['names'] << n unless ent['names'].include?(n) }
        when 'thickness_conflict', 'duplak_link_missing'
          acc[r['reason'] == 'thickness_conflict' ? :thickness_conflict : :duplak_link_missing] = true
          acc[:conflicts] << reject_entry(r)
        else
          acc[:rejected] << reject_entry(r)
        end
      end

      def material_result(mid, acc, sheets, work, invalid, blocked)
        fr = frame(mid, sheets, work['trim'])
        rows = acc[:rows].values.sort_by { |e| [e['key'], e['l'], e['w']] }
        rects = []
        rows.each_with_index do |e, idx|
          (1..e['count']).each { |n| rects << [e['l'], e['w'], e['key'], n, idx] }
        end
        # Uplne urcene radenie: w zostupne, l zostupne, kanonicky text, n.
        rects.sort_by! { |l, w, key, n, _i| [-w, -l, key, n] }

        unplaced = []
        layouts = []
        unless invalid
          fit = []
          rects.each do |rc|
            reason = unplaced_reason(rows[rc[4]]['rect'])
            reason ? unplaced << [rc[4], rc[3], reason] : fit << rc
          end
          layouts = pack(fit, fr['usable'][0], fr['usable'][1], work['kerf'])
        end

        area_sheet = fr['sheet_size'][0] * fr['sheet_size'][1]
        placed = layouts.sum { |s| s[:items].length }
        placed_area = layouts.sum { |s| s[:items].sum { |it| it[2] * it[3] } }
        blocked_reason = blocked_for(blocked, mid, acc[:row_mids])
        rejected_rows = acc[:rejected].length
        out = {
          'material_id' => mid, 'sheet_size' => fr['sheet_size'], 'usable' => fr['usable'], 'trim' => fr['trim'],
          'fallback' => fr['fallback'], 'uni' => fr['uni'], 'invalid_params' => invalid,
          'sheets' => layouts.length, 'placed_count' => placed,
          'rejected_rows' => rejected_rows, 'rejected' => sort_rejects(acc[:rejected]),
          'thickness_conflict' => acc[:thickness_conflict], 'duplak_link_missing' => acc[:duplak_link_missing],
          'conflicts' => sort_rejects(acc[:conflicts]), 'blocked' => blocked_reason,
          'doubled_pieces' => rows.select { |e| e['doubled'] }.sum { |e| e['count'] },
          'rows' => rows.map { |e| e.reject { |k, _| k == 'rect' } },
          'layouts' => layouts.map { |s| sheet_result(s, fr, work['kerf'], area_sheet) },
          'unplaced' => unplaced
        }
        out['utilization'] = pct(placed_area, layouts.length * area_sheet) unless layouts.empty?
        # C2: horna hranica LEN pri uplnom a spolahlivom plane.
        out['upper_bound'] = !fr['fallback'] && !fr['uni'] && !invalid && blocked_reason.nil? &&
                             !acc[:thickness_conflict] && !acc[:duplak_link_missing] &&
                             unplaced.empty? && rejected_rows.zero?
        out
      end

      def blocked_for(blocked, mid, row_mids)
        return nil unless blocked.is_a?(Hash)

        v = blocked[:all]
        return reason_text(v) unless v.nil? || v == false

        ([mid] + row_mids.sort).each do |id|
          b = blocked[id]
          return reason_text(b) unless b.nil? || b == false
        end
        nil
      end

      def reason_text(v)
        s = v.to_s.strip
        s.empty? ? 'blocked' : s
      end

      # --- rozlozenie (C6 — formalne, bez otacania) ---------------------------
      #
      # Platna = pasy {y, h, used_l, count} + vyska used_h. Pas je pruh cez celu
      # Lu, vyska pasu = w prveho (najvyssieho) obdlznika. First-fit:
      #  (1) platne v poradi, v nich pasy v poradi — prvy pas, kam sa obdlznik
      #      zmesti (w <= h, dlzka s prerezom pred nim <= Lu),
      #  (2) inak PRVA platna v poradi, kde sa zmesti novy pas,
      #  (3) inak nova platna.
      # Prerez len MEDZI dielcami v pase a MEDZI pasmi, nikdy pri orezanom
      # okraji. Rozlozenie je gilotinovo rezatelne (pozdlzne rezy medzi pasmi,
      # priecne v pase, dorez nizsich dielcov).
      # rects: [l, w, key, n, row_index]; vrati [{strips:, used_h:, items: [[idx, n, l, w, x, y]]}].
      def pack(rects, lu, wu, k)
        t = tol
        sheets = []
        rects.each do |l, w, _key, n, idx|
          next if place_in_strip(sheets, l, w, n, idx, lu, k, t)
          next if place_new_strip(sheets, l, w, n, idx, wu, k, t)

          s = { strips: [], used_h: 0.0, items: [] }
          sheets << s
          add_strip(s, 0.0, l, w, n, idx)
        end
        sheets
      end

      def place_in_strip(sheets, l, w, n, idx, lu, k, t)
        sheets.each do |s|
          s[:strips].each do |st|
            gap = st[:count].positive? ? k : 0.0
            next unless w <= st[:h] + t && st[:used_l] + gap + l <= lu + t

            x = st[:used_l] + gap
            st[:used_l] = x + l
            st[:count] += 1
            st[:items] << [x, w, l]
            s[:items] << [idx, n, l, w, x, st[:y]]
            return true
          end
        end
        false
      end

      def place_new_strip(sheets, l, w, n, idx, wu, k, t)
        sheets.each do |s|
          gap = s[:strips].empty? ? 0.0 : k
          next unless s[:used_h] + gap + w <= wu + t

          add_strip(s, s[:used_h] + gap, l, w, n, idx)
          return true
        end
        false
      end

      def add_strip(s, y, l, w, n, idx)
        s[:strips] << { y: y, h: w, used_l: l, count: 1, items: [[0.0, w, l]] }
        s[:used_h] = y + w
        s[:items] << [idx, n, l, w, 0.0, y]
      end

      def sheet_result(s, fr, k, area_sheet)
        area = s[:items].sum { |it| it[2] * it[3] }
        {
          'placements' => s[:items].map { |idx, n, _l, _w, x, y| [idx, n, rnd(x), rnd(y)] },
          'strips' => s[:strips].map { |st| [rnd(st[:y]), rnd(st[:h])] },
          'utilization' => pct(area, area_sheet),
          'offcut' => largest_offcut(s, fr['usable'][0], fr['usable'][1], k)
        }
      end

      # Najvacsi SAMOSTATNY zvysok z kandidatov (susedne odrezky sa nezlucuju):
      # spodok platne, koniec kazdeho pasu a priestor NAD kazdym nizsim
      # dielcom v pase (audit F9). Vyhrava plocha, potom mensie y, potom x.
      # Suradnice v pouzitelnej ploche (po oreze); [x, y, dlzka, sirka] | nil.
      def largest_offcut(s, lu, wu, k)
        t = tol
        cands = []
        cands << [0.0, s[:used_h] + k, lu, wu - s[:used_h] - k]
        s[:strips].each do |st|
          cands << [st[:used_l] + k, st[:y], lu - st[:used_l] - k, st[:h]]
          st[:items].each do |x, w, l|
            cands << [x, st[:y] + w + k, l, st[:h] - w - k]
          end
        end
        cands.select! { |c| c[2] > t && c[3] > t }
        best = cands.min_by { |c| [-(c[2] * c[3]), c[1], c[0]] }
        best&.map { |v| rnd(v) }
      end

      def usable_area?(lu, wu)
        lu > tol && wu > tol
      end

      def fit_one?(a, b, lu, wu)
        a <= lu + tol && b <= wu + tol
      end

      def pct(part, whole)
        return 0.0 unless whole.positive?

        (100.0 * part / whole).round(1)
      end

      def rnd(v)
        v.to_f.round(3)
      end
    end
  end
end
