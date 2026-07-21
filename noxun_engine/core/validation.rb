# frozen_string_literal: true
# Noxun Engine — V0.5 D: KONTROLNY SEMAFOR VYROBY (deterministicka validacia
# vyrobnych dat). CISTY modul (ziadne SketchUp API) — headless testovatelny;
# vstup je RAW zber Bom.collect (records so snapshotmi + raw hardware_overrides
# + build warnings) a katalog dosiek ako mapa. Ziadne prepocitavanie planu,
# ziadne citanie geometrie.
#
# DVE ZAVAZNOSTI (rozhodnutie Michal, V0.5 D):
#   RED    — takmer ista chyba vyroby:
#            - dielec s materialom MIMO KATALOGU (id nie je v aktualnom katalogu;
#              builder legacy materialy toleruje, preto to nie je fatalne pri stavbe)
#            - drift hrubky: hrubka dielca nesedi s katalogovou hrubkou materialu
#              (tolerancia ako builder ~0,05 mm; cela beru 18/19 mm variant)
#            - dielec sa NEZMESTI na format platne materialu (respektuje smer dekoru)
#   ORANGE — podozrenie na prehliadnutie:
#            - celo/dvierka (front_door/drawer_front) bez JEDINEJ ABS hrany
#            - volna doska (free_panel) bez ABS ("skontroluj — moze byt zamer")
#            - vypnute kovanie (hardware override disabled: true)
#            - build warnings stavby (kategoria "stavba")
#
# EXPORT SA NIKDY NEBLOKUJE (semafor VARUJE, nezakazuje) — tento modul len
# POPISUJE problemy; rozhodnutie o exporte je na pouzivatelovi.
#
# Kazda polozka nesie STABILNU IDENTITU problemu (stable_key = kategoria +
# owner_id + part_key|hw kluc), aby klik-select po flushi editov panela nasiel
# CERSTVE entity podla identity (nie podla PID, ktory rebuild meni). Server
# vypocita counts PRIAMO z finalneho (deduplikovaneho a zoradeneho) zoznamu.
module Noxun
  module Engine
    module Validation
      RED    = 'red'
      ORANGE = 'orange'

      # Tolerancia hrubkoveho driftu — ZHODNA s CabinetBuilder.thickness_ok_for?
      # (rozne prahy by vytvorili pasmo, kde builder dielec postavi a semafor ho
      # vzapati oznaci za chybny).
      THICKNESS_TOL = 0.05
      # Tolerancia zmestenia na platnu (mm) — Length konverzie + rezerva rezu.
      DIM_TOL = 0.1

      FRONT_ROLES = %w[front_door drawer_front].freeze
      PANEL_ROLE  = 'free_panel'
      EDGE_CODES  = %w[L1 L2 W1 W2].freeze

      # Kategorie (stabilne kluce; NEmenit — su sucastou stable_key a klik-selectu).
      CAT_MATERIAL  = 'material'   # RED
      CAT_THICKNESS = 'thickness'  # RED
      CAT_OVERSIZE  = 'oversize'   # RED
      CAT_FRONT_ABS = 'front_abs'  # ORANGE
      CAT_PANEL_ABS = 'panel_abs'  # ORANGE
      CAT_HARDWARE  = 'hardware'   # ORANGE
      CAT_BUILD     = 'build'      # ORANGE — build warnings stavby (nalez 9: JEDINY kanon)

      SEVERITY_RANK = { RED => 0, ORANGE => 1 }.freeze

      HW_LABELS = {
        'leg' => 'Nohy', 'hinge' => 'Závesy', 'slide' => 'Výsuv',
        'handle' => 'Úchytky', 'shelf_pin' => 'Podperky', 'connector' => 'Spojky'
      }.freeze

      module_function

      # collected: vystup Bom.collect —
      #   records: [ {name, part_key, owner_id, role, length, width, thickness,
      #               material_id, grain_direction, edges{L1..W2}} ... ]
      #   hardware_overrides: [ {owner_id, generic_type, rule_id, owner_part_key,
      #                          disabled} ... ]  (raw — disabled polozky su TU, v
      #                          config.hardware[] uz nie su, nalez 2)
      #   warnings: [ {code, message, owner_id, part_key} ... ]
      # sheets: { material_id => { 'thickness' => Float, 'sheet_size' => [l, w] } }
      #   (katalog dosiek; headless testy krmia mapu priamo, v SketchUpe Materials.sheets)
      #
      # Vrati: { 'items' => [...deterministicky zoradene, deduplikovane...],
      #          'counts' => { 'red' => N, 'orange' => M, 'total' => N+M } }
      def run(collected, sheets: {})
        collected = {} unless collected.is_a?(Hash)
        smap = sheets.is_a?(Hash) ? sheets : {}
        items = []
        Array(collected[:records]).each { |r| check_record(r, smap, items) }
        Array(collected[:hardware_overrides]).each { |ov| check_hardware(ov, items) }
        Array(collected[:warnings]).each { |w| check_build(w, items) }
        items = sort_items(dedup(items))
        { 'items' => items, 'counts' => counts(items) }
      end

      # --- kontroly dielca ---------------------------------------------------

      def check_record(r, sheets, items)
        return unless r.is_a?(Hash)
        mat  = r['material_id'].to_s
        role = r['role'].to_s
        sheet = mat.empty? ? nil : sheets[mat]

        # RED: materal mimo katalogu. NEsmieme tvrdit "zmazany" (nepreukazatelne,
        # nalez 7) — len "nie je v aktualnom katalogu". Ak material chyba, drift aj
        # zmestenie sa uz NEhlasia (nalez 10) — bez katalogovej pravdy nie su preukazatelne.
        if !mat.empty? && sheet.nil?
          items << record_item(RED, CAT_MATERIAL, r,
                               "Dielec „#{disp_name(r)}“ (#{disp_owner(r)}) — materiál #{mat} " \
                               'nie je v aktuálnom katalógu.')
        elsif sheet
          check_thickness(r, role, sheet, items)
          check_oversize(r, sheet, items)
        end

        check_abs(r, role, items)
      end

      # RED: hrubka dielca vs katalogova hrubka materialu (drift). Tolerancia a
      # vynimka ciel su ZHODNE s CabinetBuilder.thickness_ok_for?.
      def check_thickness(r, role, sheet, items)
        want = r['thickness'].to_f
        have = sheet['thickness'].to_f
        return if have <= 0
        return if thickness_ok?(role, want, have)
        items << record_item(RED, CAT_THICKNESS, r,
                             "Dielec „#{disp_name(r)}“ (#{disp_owner(r)}) — hrúbka #{fmt(want)} mm " \
                             "nesedí s hrúbkou materiálu #{r['material_id']} (#{fmt(have)} mm).")
      end

      def thickness_ok?(role, want, have)
        if FRONT_ROLES.include?(role)
          (have - 18.0).abs < THICKNESS_TOL || (have - 19.0).abs < THICKNESS_TOL ||
            (have - want).abs < THICKNESS_TOL
        else
          (have - want).abs < THICKNESS_TOL
        end
      end

      # RED: dielec sa nezmesti na format platne. Respektuje smer dekoru (nalez 3,
      # rovnaka logika ako VEPO oriented): grain none = obe otocenia; length/width =
      # LEN pripustna orientacia (dlzka pozdlz dekoru = pozdlz dlzky platne).
      def check_oversize(r, sheet, items)
        size = sheet['sheet_size']
        return unless size.is_a?(Array) && size.size == 2
        sl = size[0].to_f
        sw = size[1].to_f
        return unless sl > 0 && sw > 0
        return if fits_on_sheet?(r['length'].to_f, r['width'].to_f, r['grain_direction'].to_s, sl, sw)
        items << record_item(RED, CAT_OVERSIZE, r,
                             "Dielec „#{disp_name(r)}“ (#{disp_owner(r)}) #{fmt(r['length'])}×#{fmt(r['width'])} mm " \
                             "sa nezmestí na formát platne #{fmt(sl)}×#{fmt(sw)} mm (materiál #{r['material_id']}).")
      end

      def fits_on_sheet?(l, w, grain, sl, sw)
        case grain
        when PANEL_ROLE then fit_one(l, w, sl, sw) # nikdy — obrana; grain je length/width/none
        when 'width'    then fit_one(w, l, sl, sw)  # VEPO swap: dlzka pozdlz dekoru = povodna sirka
        when 'length'   then fit_one(l, w, sl, sw)
        else                 fit_one(l, w, sl, sw) || fit_one(w, l, sl, sw) # 'none' = obe otocenia
        end
      end

      def fit_one(a, b, sl, sw)
        a <= sl + DIM_TOL && b <= sw + DIM_TOL
      end

      # ORANGE: celo bez ABS / volna doska bez ABS. Jedna polozka na dielec (part_key),
      # NIE per hrana (nalez 11).
      def check_abs(r, role, items)
        return unless no_abs?(r)
        if FRONT_ROLES.include?(role)
          items << record_item(ORANGE, CAT_FRONT_ABS, r,
                               "Čelo „#{disp_name(r)}“ (#{disp_owner(r)}) nemá žiadnu ABS hranu — skontroluj olepenie.")
        elsif role == PANEL_ROLE
          items << record_item(ORANGE, CAT_PANEL_ABS, r,
                               "Voľná doska „#{disp_name(r)}“ (#{disp_owner(r)}) nemá ABS — skontroluj (môže byť zámer).")
        end
      end

      def no_abs?(r)
        edges = r['edges'].is_a?(Hash) ? r['edges'] : {}
        EDGE_CODES.none? { |c| present?(edges[c]) }
      end

      # --- kontroly kovania a stavby ----------------------------------------

      # ORANGE: vypnute kovanie. Realny stav je disabled: true (nie quantity 0 —
      # tu UI zakazuje), preto zber musi niest RAW hardware_overrides (nalez 2).
      def check_hardware(ov, items)
        return unless ov.is_a?(Hash) && ov['disabled'] == true
        oid = ov['owner_id'].to_s
        gt  = ov['generic_type'].to_s
        rid = ov['rule_id'].to_s
        # Codex GH #65 P2: owner_part_key MUSI byt v identite — dva vypnute
        # overridy s rovnakym generic_type+rule_id na roznych dielcoch (panty
        # dvoch kridel) su DVA problemy a klik ma oznacit konkretne celo.
        opk = ov['owner_part_key'].to_s
        label = HW_LABELS[gt] || (gt.empty? ? 'kovanie' : gt)
        where = oid.empty? ? '—' : oid
        where += " · #{opk}" unless opk.empty?
        items << {
          'severity' => ORANGE, 'category' => CAT_HARDWARE,
          'owner_id' => oid, 'part_key' => (opk.empty? ? nil : opk), 'hw_key' => nil,
          'message_sk' => "Kovanie „#{label}“ (#{where}) je vypnuté — skontroluj, či zámerne.",
          'stable_key' => "#{CAT_HARDWARE}|#{oid}|#{opk}|#{gt}|#{rid}"
        }
      end

      # ORANGE: build warning stavby (kategoria "stavba"). KONTROLA je JEDINY
      # kanonicky zoznam (nalez 9) — povodna sekcia "Upozornenia stavby" zmizla.
      # Build warnings maju owner_id a PRIPADNE part_key (owner_pid neexistuje).
      def check_build(w, items)
        return unless w.is_a?(Hash)
        oid  = w['owner_id'].to_s
        pkey = w['part_key'].to_s
        code = w['code'].to_s
        msg  = (w['message'] || w['code']).to_s
        text = msg.empty? ? 'Upozornenie stavby.' : msg
        text = "#{oid}: #{text}" unless oid.empty?
        items << {
          'severity' => ORANGE, 'category' => CAT_BUILD,
          'owner_id' => oid, 'part_key' => (pkey.empty? ? nil : pkey), 'hw_key' => nil,
          'message_sk' => text,
          # Codex GH #65 P2: sprava je sucastou kluca — viacero owner-level
          # warningov bez part_key/code (legacy string tvar) su ROZNE problemy;
          # dedup smie zlucit len uplne identicke. Sprava je deterministicka
          # (vznika z build planu), kluc ostava stabilny medzi prepoctami.
          'stable_key' => "#{CAT_BUILD}|#{oid}|#{pkey}|#{code}|#{msg}"
        }
      end

      # --- pomocne -----------------------------------------------------------

      def record_item(severity, category, r, message)
        oid  = r['owner_id'].to_s
        pkey = r['part_key'].to_s
        {
          'severity' => severity, 'category' => category,
          'owner_id' => oid, 'part_key' => (pkey.empty? ? nil : pkey), 'hw_key' => nil,
          'message_sk' => message,
          'stable_key' => "#{category}|#{oid}|#{pkey}"
        }
      end

      # Dedup podla stable_key — jeden problem (kategoria + vlastnik + kluc) = jeden
      # riadok = jedna jednotka (nalez 11). Poradie prveho vyskytu zachovane.
      def dedup(items)
        seen = {}
        items.select do |it|
          k = it['stable_key']
          next false if seen[k]

          seen[k] = true
        end
      end

      # Deterministicke poradie: RED pred ORANGE, potom vlastnik, kategoria, kluc.
      def sort_items(items)
        items.sort_by do |it|
          [SEVERITY_RANK[it['severity']] || 9, it['owner_id'].to_s, it['category'].to_s,
           (it['part_key'] || it['hw_key'] || '').to_s, it['stable_key'].to_s]
        end
      end

      # Counts PRIAMO z finalneho zoznamu — JS ich NIKDY neprepocitava (nalez 11).
      def counts(items)
        red = items.count { |it| it['severity'] == RED }
        orange = items.count { |it| it['severity'] == ORANGE }
        { 'red' => red, 'orange' => orange, 'total' => red + orange }
      end

      def present?(v)
        !v.nil? && !v.to_s.strip.empty?
      end

      def disp_name(r)
        n = r['name'].to_s.strip
        n.empty? ? 'dielec' : n
      end

      def disp_owner(r)
        o = r['owner_id'].to_s.strip
        o.empty? ? '—' : o
      end

      # Cele mm bez desatin ak su nulove, inak 1 desatinne miesto (slovenska ciarka).
      def fmt(v)
        f = v.to_f
        s = (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
        s
      end
    end
  end
end
