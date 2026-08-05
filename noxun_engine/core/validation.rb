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
#            - ABS paska hrany MIMO KATALOGU (2A-2 audit F6: hrana referencuje
#              abs_id, ktore v aktualnom katalogu nie je — napr. po zmazani pri
#              migracii; kontrola bezi LEN ked volajuci ABS katalog dodal)
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
      CAT_ABS       = 'abs_missing' # RED — ABS paska hrany mimo katalogu (2A-2, F6)
      CAT_FRONT_ABS = 'front_abs'  # ORANGE
      CAT_PANEL_ABS = 'panel_abs'  # ORANGE
      CAT_HARDWARE  = 'hardware'   # ORANGE
      CAT_BUILD     = 'build'      # ORANGE — build warnings stavby (nalez 9: JEDINY kanon)
      CAT_UNI       = 'uni_material' # ORANGE — V0.6 M-B1: dielec na UNI (material neurceny)
      CAT_HW_UNMAPPED = 'hardware_unmapped' # ORANGE — V0.6 D1: genericky typ bez setu / NL mimo radu
      CAT_HW_CODE     = 'hardware_code'     # ORANGE — V0.6 D1: kod clena setu mimo katalogu
      # ORANGE — V0.6 E-b: upozornenia ROZPOCTU (riadok bez ceny/popisu, chybajuce
      # m2, nezapocitane spotrebice). Zrkadli Budget::CAT_BUDGET; vlastna
      # konstanta preto, ze validation.rb sa nacitava PRED budget.rb.
      CAT_BUDGET      = 'budget'

      SEVERITY_RANK = { RED => 0, ORANGE => 1 }.freeze

      HW_LABELS = {
        'leg' => 'Nohy', 'hinge' => 'Závesy', 'slide' => 'Výsuv',
        'handle' => 'Úchytky', 'shelf_pin' => 'Podperky', 'connector' => 'Spojky',
        'wall_hanger' => 'Zavesenie na stenu'
      }.freeze

      # H1a: slovenske nazvy parametrov pasiem — 4. PAD pre vety typu „nemá
      # pásmo pre výšku sokla". 1. pad (podmet vety, popisky editora) a tvar
      # „podľa …" drzi HardwareSets::PARAM_OPTIONS — jeden slovnik, dva pady.
      HW_PARAM_LABELS = {
        'height' => 'výšku sokla', 'front_height' => 'výšku čela',
        'nominal_length' => 'dĺžku', 'width' => 'šírku', 'depth' => 'hĺbku'
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
      # edges: { abs_id => zaznam } — katalog ABS pasok pre kontrolu abs_missing
      #   (2A-2, F6). nil = katalog NEDODANY, kontrola sa cela preskoci (legacy
      #   volania a existujuce testy bez zmeny spravania); prazdna mapa = kazde
      #   pouzite abs_id je mimo katalogu.
      #
      # hardware_expansion: vystup HardwareSets.expand (D1) — nil = kontrola
      #   setov sa cela preskoci (legacy volania bez zmeny spravania; vzor
      #   edges:). Z 'unmapped' vznika CAT_HW_UNMAPPED, z rows.missing
      #   CAT_HW_CODE — oba ORANGE, NIKDY neblokuju export.
      #
      # Vrati: { 'items' => [...deterministicky zoradene, deduplikovane...],
      #          'counts' => { 'red' => N, 'orange' => M, 'total' => N+M } }
      def run(collected, sheets: {}, edges: nil, hardware_expansion: nil)
        collected = {} unless collected.is_a?(Hash)
        smap = sheets.is_a?(Hash) ? sheets : {}
        emap = edges.is_a?(Hash) ? edges : nil
        items = []
        # V0.6 M-B1 (audit F4): dielce na UNI materiali — ich ABS build
        # warnings sa potlacaju (jedna jasna sprava "material neurceny"
        # namiesto trojiteho hluku o chybajucich paskach).
        # M-C (GH #118 P2): to iste pre NELEPITELNE materialy (kompakt /
        # PD postforming) — ulozene abs_* warnings zo starsich buildov by po
        # upgrade/zmene podtypu strasili, hoci olep neexistuje.
        uni_parts = {}
        Array(collected[:records]).each do |r|
          next unless r.is_a?(Hash)
          s = smap[r['material_id'].to_s]
          uni_parts["#{r['owner_id']}|#{r['part_key']}"] = true if uni_sheet?(s) || abs_impossible?(s)
        end
        Array(collected[:records]).each { |r| check_record(r, smap, emap, items) }
        Array(collected[:hardware_overrides]).each { |ov| check_hardware(ov, items) }
        check_hardware_expansion(hardware_expansion, items)
        Array(collected[:warnings]).each { |w| check_build(w, items, uni_parts) }
        items = sort_items(dedup(items))
        { 'items' => items, 'counts' => counts(items) }
      end

      # V0.6 E-b: KONTROLA + upozornenia ROZPOCTU v JEDNOM zozname.
      # Budget.check nezije v Validation.run zamerne (rozpocet nie je vyrobne
      # data a bezi nad HOTOVYM payloadom) — spajaju sa az tu, na urovni okna,
      # aby counts aj poradie mali NADALEJ jednu autoritu (nalez 11: JS si nic
      # neprepocitava). Rozpoctove polozky su VZDY ORANGE a NIKDY neblokuju
      # export; klik na ne neoznacuje entitu (owner_id je prazdny) — okno ich
      # smeruje do tabu Rozpocet.
      # control: vystup run(); budget_check: vystup Budget.check(payload)
      # -> { 'items' => [...], 'counts' => {...} } (novy hash, vstupy nedotknute)
      def with_budget(control, budget_check)
        base = control.is_a?(Hash) ? control : {}
        items = Array(base['items']).dup
        Array(budget_check).each do |b|
          next unless b.is_a?(Hash)
          items << budget_item(b)
        end
        merged = sort_items(dedup(items))
        { 'items' => merged, 'counts' => counts(merged) }
      end

      # Tvar riadku KONTROLY z rozpoctoveho upozornenia (E-a nesie 'message' a
      # 'stable_key'; okno cita 'message_sk' a 'category' ako vsade inde).
      def budget_item(warn)
        { 'severity' => ORANGE, 'category' => CAT_BUDGET,
          'owner_id' => nil, 'part_key' => nil, 'hw_key' => nil,
          'message_sk' => warn['message'].to_s,
          'stable_key' => warn['stable_key'].to_s,
          'budget_section' => warn['section'], 'budget_row_key' => warn['row_key'] }
      end

      # UNI rozpoznanie bez zavislosti na Materials (headless mapy) — zhodne
      # s Materials.uni? (rec['uni'] == true).
      def uni_sheet?(sheet)
        sheet.is_a?(Hash) && sheet['uni'] == true
      end

      # --- kontroly dielca ---------------------------------------------------

      def check_record(r, sheets, edges_catalog, items)
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
        elsif uni_sheet?(sheet)
          # V0.6 M-B1: UNI = material neurceny. JEDNA jasna ORANGE polozka;
          # drift/oversize/ABS kontroly sa NEHLASIA (katalogova hrubka aj
          # format su len pracovne defaulty, pasky UNI zo zasady nema).
          # D-83: riadok nesie aj ID UNI materialu, aby sa dalo „Nahradiť UNI…"
          # spustit priamo z KONTROLY. Hodnota ide zo SERVERA z CERSTVEHO
          # katalogoveho zaznamu (nie z klienta ani z part snapshotu) — okno
          # Materialy ju pred otvorenim modalu aj tak overuje znova.
          items << record_item(ORANGE, CAT_UNI, r,
                               "Dielec „#{disp_name(r)}“ (#{disp_owner(r)}) — materiál UNI " \
                               '(neurčený) — pred výrobou vyber reálny dekor (Nahradiť UNI…).',
                               extra: { 'uni_id' => sheet['material_id'].to_s })
          return
        elsif sheet
          check_thickness(r, role, sheet, items)
          check_oversize(r, sheet, items)
        end

        check_abs_catalog(r, edges_catalog, items) if edges_catalog
        check_abs(r, role, items, sheet)
      end

      # RED (2A-2, F6): hrana referencuje abs_id, ktore v aktualnom katalogu nie
      # je (napr. paska zmazana migraciou). Hodnoty edges su abs_id alebo nil
      # (builders/overridy ine tvary nezapisuju) — kontroluje sa LEN neprazdny
      # string; jedna polozka NA DIELEC (stable_key drzi vzor record_item).
      def check_abs_catalog(r, edges_catalog, items)
        edges = r['edges'].is_a?(Hash) ? r['edges'] : {}
        missing = EDGE_CODES.filter_map do |code|
          v = edges[code].to_s.strip
          v unless v.empty? || edges_catalog.key?(v)
        end.uniq.sort
        return if missing.empty?
        label = missing.map { |id| "„#{id}“" }.join(', ')
        noun = missing.length == 1 ? 'ABS páska' : 'ABS pásky'
        verb = missing.length == 1 ? 'nie je' : 'nie sú'
        items << record_item(RED, CAT_ABS, r,
                             "Dielec „#{disp_name(r)}“ (#{disp_owner(r)}) — #{noun} #{label} " \
                             "#{verb} v katalógu — skontroluj olepenie.")
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

      # D-45: pravidlo je JEDNO (CabinetBuilder) — semafor nesmie oznacit za chybne
      # to, co builder legitimne postavi (18,6 mm celo). Fallback (builder
      # nedostupny) drzi povodnu logiku vratane starych 18/19 variantov.
      def thickness_ok?(role, want, have)
        return CabinetBuilder.thickness_ok_for?(role, want, have) if defined?(CabinetBuilder)
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

      # M-C: typy, ktore sa ABS-om NELEPIA — kompakt (monoliticka hrana) a PD
      # s postformingom (hrany hotove z vyroby; konce lepi HPDB mimo ABS).
      # ORANGE "bez ABS" pri nich neSTRASI — nie je co skontrolovat. Chybajuci
      # sheet (material mimo katalogu) sa NEpotlaca (audit F6). Headless
      # dvojnik Materials.abs_default_suppression (vzor uni_sheet?).
      def abs_impossible?(sheet)
        return false unless sheet.is_a?(Hash)
        type = sheet['type'].to_s.strip.upcase
        return true if type == 'KOMPAKT'
        type == 'PD' && sheet['pd_edge_subtype'].to_s == 'postforming'
      end

      # ORANGE: celo bez ABS / volna doska bez ABS. Jedna polozka na dielec (part_key),
      # NIE per hrana (nalez 11).
      def check_abs(r, role, items, sheet = nil)
        return if abs_impossible?(sheet)
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

      # ORANGE (D1): sety kovania. Stable key nesie plnu identitu zdroja
      # (audit F7 — kategoria|korpus|vlastnik|generic|rule|set|kod): jedna
      # chybajuca polozka na 3 skrinkach = 3 klik-selectovatelne riadky.
      def check_hardware_expansion(exp, items)
        return unless exp.is_a?(Hash)
        Array(exp['unmapped']).each do |u|
          next unless u.is_a?(Hash)
          oid = u['cabinet_id'].to_s
          gt  = u['generic_type'].to_s
          opk = u['owner_part_key'].to_s
          sid = u['set_id'].to_s
          label = HW_LABELS[gt] || (gt.empty? ? 'kovanie' : gt)
          where = oid.empty? ? '—' : oid
          where += " · #{opk}" unless opk.empty?
          # H1a (audit FIX 9): pri pasmach nesie riadok AJ clena setu — dva
          # chybajuce pasma v jednom sete su DVA problemy (a dva klik-selecty).
          member = u['member_label'].to_s
          member = "člen #{u['member_index'].to_i + 1}" if member.empty? && u.key?('member_index')
          msg =
            case u['reason'].to_s
            when 'nl_missing'
              # GH #132 P2: bez zaokruhlenia — frakcna NL (419,6) je vedome
              # nemapovana; „NL 420" by ukazovalo na kod, ktory uz existuje.
              nl = u['nominal_length']
              nl_txt = nl.is_a?(Numeric) ? " NL #{HardwareSets.fmt_mm(nl)}" : ''
              "#{label} (#{where}): set „#{sid}“ nemá kód pre dĺžku#{nl_txt} — doplň rad setu."
            when 'param_band_missing'
              "#{label} (#{where}): set „#{sid}“ nemá pásmo pre #{param_txt(u)}" \
                "#{member.empty? ? '' : " (#{member})"} — doplň pásmo setu."
            when 'selector_unresolved'
              # H1b: parameter je tu PODMET vety — 1. pad („výška čela 300 mm
              # nespadá…"); „podľa + 4. pad" bola gramaticka chyba.
              "#{label} (#{where}): #{param_txt_nom(u)} nespadá do žiadneho pásma " \
                'predvoľby — doplň pásmo výberu setu.'
            when 'set_missing'
              "#{label} (#{where}): projekt odkazuje na set „#{sid}“, ktorý v projekte nie je — vyber set nanovo."
            when 'set_type_mismatch'
              # H2 (D-76): set zo sablony vs. vlastna definicia projektu — radsej
              # NIC ako tichy zly hardver (kody ineho typu kovania).
              "#{label} (#{where}): set „#{sid}“ je v projekte iného typu kovania — vyber set nanovo."
            else
              "#{label} (#{where}) nemá priradený set — kovanie je bez kódov (nenacenené)."
            end
          items << {
            'severity' => ORANGE, 'category' => CAT_HW_UNMAPPED,
            'owner_id' => oid, 'part_key' => (opk.empty? ? nil : opk), 'hw_key' => nil,
            'message_sk' => msg,
            'stable_key' => [CAT_HW_UNMAPPED, oid, opk, gt, u['rule_id'].to_s, sid,
                             u['reason'].to_s, u['member_index'].to_s].join('|')
          }
        end
        Array(exp['rows']).each do |row|
          next unless row.is_a?(Hash) && row['missing'] == true
          code = row['code'].to_s
          Array(row['sources']).each do |src|
            next unless src.is_a?(Hash)
            oid = src['cabinet_id'].to_s
            opk = src['owner_part_key'].to_s
            gt  = src['generic_type'].to_s
            items << {
              'severity' => ORANGE, 'category' => CAT_HW_CODE,
              'owner_id' => oid, 'part_key' => (opk.empty? ? nil : opk), 'hw_key' => nil,
              'message_sk' => "Kód #{code} zo setu „#{src['set_id']}“ nie je v katalógu kovania — bez názvu a ceny.",
              'stable_key' => [CAT_HW_CODE, oid, opk, gt, src['rule_id'].to_s,
                               src['set_id'].to_s, code].join('|')
            }
          end
        end
      end

      # „výšku sokla 150 mm" / „výšku čela (nezadaná)" — parameter + hodnota
      # v jednom citatelnom kuse (H1a FIX 9). 4. pad (predmet vety).
      def param_txt(u)
        param = u['param'].to_s
        name = HW_PARAM_LABELS[param] || (param.empty? ? 'parameter' : "parameter „#{param}“")
        param_value_txt(name, u['value'])
      end

      # 1. pad — parameter ako PODMET vety („výška čela 300 mm nespadá…").
      # Nazov berie zo slovnika HardwareSets (jedina autorita parametrov pasiem).
      def param_txt_nom(u)
        param_value_txt(HardwareSets.param_label(u['param']), u['value'])
      end

      # Cislo formatuje HardwareSets.fmt_mm — TEN ISTY tvar ako v CSV a v tabe
      # Kovanie (150 / 17,5), aby ta ista hodnota nikde nevyzerala inak.
      def param_value_txt(name, v)
        v.is_a?(Numeric) ? "#{name} #{HardwareSets.fmt_mm(v)} mm" : "#{name} (nezadaná)"
      end

      # ORANGE: build warning stavby (kategoria "stavba"). KONTROLA je JEDINY
      # kanonicky zoznam (nalez 9) — povodna sekcia "Upozornenia stavby" zmizla.
      # Build warnings maju owner_id a PRIPADNE part_key (owner_pid neexistuje).
      def check_build(w, items, uni_parts = {})
        return unless w.is_a?(Hash)
        oid  = w['owner_id'].to_s
        pkey = w['part_key'].to_s
        code = w['code'].to_s
        # V0.6 M-B1 (audit F4): ulozene ABS warnings dielca, ktory je AKTUALNE
        # na UNI, sa potlacaju — hlasi sa len CAT_UNI (jedna sprava, nie tri).
        return if code.start_with?('abs_') && uni_parts["#{oid}|#{pkey}"]
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

      # extra = volitelne DOPLNKOVE polia riadku (D-83 'uni_id'). Do stable_key
      # NEvstupuju — kluc je identita problemu a nesmie sa hnut, inak by sa
      # rozbil klik-select aj dedup.
      def record_item(severity, category, r, message, extra: nil)
        oid  = r['owner_id'].to_s
        pkey = r['part_key'].to_s
        item = {
          'severity' => severity, 'category' => category,
          'owner_id' => oid, 'part_key' => (pkey.empty? ? nil : pkey), 'hw_key' => nil,
          'message_sk' => message,
          'stable_key' => "#{category}|#{oid}|#{pkey}"
        }
        extra.is_a?(Hash) ? item.merge(extra) : item
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
