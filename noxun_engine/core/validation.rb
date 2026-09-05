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
#            - KOV-A1: dvierka s vedome NEURCENYM smerom otvarania
#              (`front_direction`, z aditivneho `hardware_issues`) — jediny RED,
#              ktory ZATIAL nema exportnu branu (O1/R-39; legacy configy bez
#              pola sa negatuju a nalez nikdy nedostanu)
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

      # KOV-A1: + flap (vyklop/sklop) a false_front (blenda) — ORANGE „celo bez
      # ABS" a hrubkove pravidlo ciel platia aj pre ne.
      FRONT_ROLES = %w[front_door drawer_front flap false_front].freeze
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
      # ORANGE — D-103: dva top-level kusy (skrinky/dosky) na IDENTICKOM mieste.
      # Typicky pozostatok po `*N` nasobeni kopii; nikdy sa nic nemaze automaticky
      # (paste-in-place je legitimny krok pouzivatela) — len sa ukaze a da vybrat.
      CAT_DUPLICATE   = 'duplicate_position'
      # ORANGE — 1b-3: dva top-level kusy so ZHODNYM ID (kopia, ktorej este nikto
      # nepridelil vlastnu identitu). Do 1b-3 to „Obnoviť" potichu opravovalo —
      # zapisovalo do modelu a robilo krok Späť pri obycajnom CITANI. Odteraz sa to
      # PRIZNA a opravu spusti az realna akcia zapisu (observer / zapis z panela).
      CAT_DUP_ID      = 'duplicate_identity'
      # RED — KOV-A1 (O1, R-39): dvierka s vedome NEURCENYM smerom otvarania
      # (= strana pantov). Nalez je LEN nalez: ZIADNA exportna brana. Smer dnes
      # nemeni ziadne vydane cislo (nakup ani rezy), brana pristane az s prvym
      # vystupom, ktory smer realne ponesie (D-95 vyrobne zadanie) — a je do
      # tej doby PRE-COMMITTED v SYSTEM/AUDIT_REGISTER.md (R-39).
      # LEGACY configy (kluc `direction` vobec nemaju) sem NIKDY nepridu —
      # `Fronts.direction_slots` im vrati stav nil a `Bom` z neho nalez netvori.
      CAT_FRONT_DIR   = 'front_direction'
      # RED — KOV-H1 (R-12 exportna brana): skrinka ma config z NOVSEJ verzie
      # pluginu. Na rozdiel od `front_direction` tento nalez EXPORTNU BRANU MA
      # (`ProductionCore.export_blockers` zastavi nakupny CSV, rozpocet aj
      # ponuku) — Kontrola ho ukazuje preto, aby to bolo vidno AJ BEZ pokusu
      # o export, teda skor, nez pouzivatel zacne rozpocet dolaďovat.
      CAT_NEWER_CFG   = 'newer_config'
      # ORANGE — KOV-H1: ad-hoc polozka kovania pripnuta na dielec, ktory
      # v skrinke UZ NIE JE. Polozka OSTAVA v nakupe (zahodit ju by znamenalo
      # ticho odobrat kus z objednavky) — len sa prizna, aby ju clovek vedel
      # prepnut na iny dielec alebo zmazat.
      CAT_HW_ADHOC    = 'hardware_adhoc'

      # Druh top-level kusu, ktory MA KOVANIE. Zdielana konstanta preto, ze
      # „skrinka vs. doska" nie je kozmetika textu: len pri skrinke zliatie
      # vlastnikov podpocita kovanie uctovane na vlastnika (`per: 'owner'`),
      # a prave to je od P0-HF-02 dovod ZASTAVIT nakupny/cenovy export.
      KIND_CABINET    = 'cabinet'

      # Tolerancie zhody umiestnenia. Artefakt nasobenia lezi PRESNE na tom istom
      # mieste (rovnaka transformacia), preto su prahy tesne — cielom je NULA
      # falosnych poplachov, nie odhalenie „skoro rovnakych" polôh.
      POS_TOL  = 0.001   # mm
      AXIS_TOL = 1.0e-6  # normalizovane osi (bezrozmerne)
      SIZE_TOL = 0.01    # mm — vonkajsie rozmery definicie

      SEVERITY_RANK = { RED => 0, ORANGE => 1 }.freeze

      HW_LABELS = {
        'leg' => 'Nohy', 'hinge' => 'Závesy', 'slide' => 'Výsuv',
        'handle' => 'Úchytky', 'shelf_pin' => 'Podperky', 'connector' => 'Spojky',
        'wall_hanger' => 'Zavesenie na stenu',
        'lift' => 'Výklop / sklop' # KOV-B1 (pravidla az KOV-E)
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
      #   hardware_issues: [ {code, severity, owner_id, owner_pid, part_key,
      #                       front_id, label} ... ]  (KOV-A1; nil/chybajuci =
      #                       kontrola sa preskoci — legacy volania bez zmeny)
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
      # placements (D-103): [{kind, owner_id, origin[3] mm, axes[9] normalizovane,
      #   size[3] mm}] z Bom.collect. nil = kontrola sa cela preskoci (legacy
      #   volania a existujuce testy bez zmeny spravania; vzor edges:).
      # identities (1b-3): [{kind, id}] z Bom.collect — jeden zaznam na INSTANCIU.
      #   nil = kontrola sa cela preskoci (legacy volania a headless testy bez
      #   identit; vzor placements:).
      def run(collected, sheets: {}, edges: nil, hardware_expansion: nil, placements: nil,
              identities: nil)
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
        check_hardware_issues(collected[:hardware_issues], items)
        check_newer_configs(collected[:newer_configs], items)
        check_hardware_manual(collected[:hardware_manual], items)
        check_hardware_expansion(hardware_expansion, items)
        check_placements(placements, items)
        check_identities(identities, items)
        Array(collected[:warnings]).each { |w| check_build(w, items, uni_parts) }
        items = sort_items(dedup(items))
        # ŠT-1b (Š8): MENOVATEL zeleneho cisla je SKUTOCNY pocet skriniek zo
        # zberu (`collected[:cabinets]`), NIE dlzka zoznamu ID z placements —
        # `Bom.add_placement` zaznam vynechava (prazdne ID, degenerovane rozmery)
        # a rovnake ID zbiera raz, takze poskodena skrinka alebo dve kopie s tym
        # istym ID by pocet skriniek TICHO ZMENSILI (nalez review #2).
        { 'items' => items,
          'counts' => counts(items, cabinet_ids: cabinet_ids(placements),
                                    cabinets: collected[:cabinets]) }
      end

      # ŠT-1b (Š8): ID top-level SKRINIEK, ktore sa daju spojit s nalezom.
      # Zdrojom su `placements` (Bom.collect). Je to VYHRADNE mnozina „ktore ID
      # patri skrinke" (nie pocet — ten je `collected[:cabinets]`).
      # nil = zoznam NEDODANY (legacy volania a headless testy bez placements):
      # vtedy sa zeleny pocet vobec nepocita a tvar counts sa NEMENI.
      def cabinet_ids(placements)
        return nil if placements.nil?

        Array(placements).each_with_object([]) do |p, out|
          next unless p.is_a?(Hash) && p['kind'].to_s == 'cabinet'

          id = p['owner_id'].to_s
          out << id unless id.empty? || out.include?(id)
        end
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
        # ŠT-1b: zelene cislo semaforu (skrinky bez nalezu) sa PRENASA z pôvodných
        # counts — rozpoctove polozky nemaju vlastnika, takze ho zmenit nemozu,
        # a druhy vypocet by potreboval placements, ktore sem uz nechodia.
        c = counts(merged)
        base_counts = base['counts'].is_a?(Hash) ? base['counts'] : {}
        %w[cabinets clean].each { |k| c[k] = base_counts[k] if base_counts.key?(k) }
        { 'items' => merged, 'counts' => c }
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

      # --- D-103: dva kusy na jednom mieste ---------------------------------

      # ORANGE: viac top-level NOXUN objektov ROVNAKEHO druhu s identickou
      # transformaciou aj vonkajsimi rozmermi. Vznika po `*N` nasobeni kopii
      # (pozri D-103) a je to TICHA chyba — kusovnik, VEPO aj rozpocet by
      # zdvojeny kus zapocitali bez jedineho varovania.
      # NIC sa nemaze automaticky: paste-in-place pred presunom je legitimny
      # postup, takze rozhodnutie ostava na cloveku (klik oznaci CELU skupinu).
      def check_placements(placements, items)
        return unless placements.is_a?(Array)
        coincident_groups(placements).each { |g| items << duplicate_item(g) }
      end

      # Deterministicke skupiny zhodne umiestnenych objektov. Vstup sa najprv
      # zoradi (kind, owner_id), takze poradie vystupu nezavisi od poradia entit
      # v modeli; porovnava sa kazdy kandidat proti PRVEMU clenovi skupiny.
      def coincident_groups(placements)
        list = placements.select { |p| usable_placement?(p) }
                         .sort_by { |p| [p['kind'].to_s, p['owner_id'].to_s] }
        taken = {}
        groups = []
        list.each_with_index do |a, i|
          next if taken[i]
          taken[i] = true
          grp = [a]
          list.each_with_index do |b, j|
            next if j <= i || taken[j]
            next unless same_placement?(a, b)
            taken[j] = true
            grp << b
          end
          groups << grp if grp.length > 1
        end
        groups
      end

      # Codex audit FIX 5: zaznam bez uplnych, konecnych a kladnych hodnot sa
      # NEPOROVNAVA — degenerovany/poskodeny objekt nesmie vyrobit falosny nalez.
      def usable_placement?(p)
        return false unless p.is_a?(Hash)
        return false if p['owner_id'].to_s.strip.empty?
        return false if p['kind'].to_s.strip.empty?
        return false unless num_vec?(p['origin'], 3) && num_vec?(p['axes'], 9) && num_vec?(p['size'], 3)
        Array(p['size']).all? { |v| v.to_f > 0.0 }
      end

      def num_vec?(v, len)
        a = v
        return false unless a.is_a?(Array) && a.length == len
        a.all? { |x| x.is_a?(Numeric) && x.to_f.finite? }
      end

      def same_placement?(a, b)
        return false unless a['kind'].to_s == b['kind'].to_s
        near_vec?(a['origin'], b['origin'], POS_TOL) &&
          near_vec?(a['axes'], b['axes'], AXIS_TOL) &&
          near_vec?(a['size'], b['size'], SIZE_TOL)
      end

      def near_vec?(x, y, tol)
        x.each_with_index.all? { |v, i| (v.to_f - y[i].to_f).abs <= tol }
      end

      # Jedna polozka na skupinu. Codex audit FIX 3: stable_key nesie DRUH aj
      # VSETKY zoradene ID — dve nezavisle kolizie sa nesmu zliat cez dedup.
      # FIX 4: 'dup_kind' + 'dup_owner_ids' su adresa klik-selectu (presne tie
      # top-level objekty, nikdy odpojene dielce so zhodnym vlastnikom).
      def duplicate_item(group)
        kind = group.first['kind'].to_s
        ids = group.map { |p| p['owner_id'].to_s }.sort
        noun = kind == 'cabinet' ? 'Skrinky' : 'Dosky'
        items_txt = ids.length == 2 ? ids.join(' a ') : "#{ids[0..-2].join(', ')} a #{ids[-1]}"
        { 'severity' => ORANGE, 'category' => CAT_DUPLICATE,
          'owner_id' => ids.first, 'part_key' => nil, 'hw_key' => nil,
          'dup_kind' => kind, 'dup_owner_ids' => ids,
          'message_sk' => "#{noun} #{items_txt} stoja na rovnakom mieste — pravdepodobne " \
                          'duplikát z kopírovania; skontroluj a prebytočnú zmaž.',
          'stable_key' => "#{CAT_DUPLICATE}|#{kind}|#{ids.join(',')}" }
      end

      # --- 1b-3: dva kusy s tym istym ID ------------------------------------

      # ORANGE: viac top-level NOXUN objektov ROVNAKEHO druhu so ZHODNYM ID.
      # Typicky cerstva kopia, ktorej observer este nestihol pridelit vlastnu
      # identitu (dedup tik ma 0,2 s debounce) — alebo kopia, ktora vznikla
      # v case, ked plugin nebezal.
      #
      # PRECO SA TO IBA PRIZNAVA (brana G bloku 1b): do 1b-3 to opravovalo samo
      # „Obnoviť" — a teda obycajne CITANIE zapisovalo do modelu a robilo krok
      # Späť. Oprava patri VYHRADNE zapisovej ceste (observer po kopirovani,
      # `Panel.push_selected` po zapise z panela); kontrola je od toho, aby to
      # ukazala, nie aby to potichu prestavala.
      #
      # DOSLEDOK V CISLACH sa hovori NAHLAS: zaznamy oboch kusov maju rovnake
      # `owner_id`, takze kusovnik ich zlieva do jedneho vlastnika a expanzia
      # setov kovania s `per: 'owner'` (napr. TipOn na dvierka) zapocita polozku
      # LEN RAZ. Tichy nalez by poslal do objednavky menej kovania.
      def check_identities(identities, items)
        duplicate_identities(identities).each { |kind, id, n| items << duplicate_id_item(kind, id, n) }
      end

      # ID, ktore si deli viac ako jeden kus -> [[kind, id, pocet], ...],
      # deterministicky zoradene. VEREJNE a je to JEDINY zdroj: nalezy Kontroly
      # z toho stavia `check_identities`, varovanie statusu exportov, ktore
      # `Validation.run` vobec nevolaju (nakupny zoznam kovania, XLSX rozpoctu
      # a cenovej ponuky — review 1b-3 P2-1), si ho pyta priamo. Dve nezavisle
      # implementacie toho isteho kriteria by sa casom rozisli.
      def duplicate_identities(identities)
        return [] unless identities.is_a?(Array)

        counts = {}
        identities.each do |rec|
          next unless rec.is_a?(Hash)

          kind = rec['kind'].to_s
          id = rec['id'].to_s
          next if kind.empty? || id.empty?

          counts[[kind, id]] = (counts[[kind, id]] || 0) + 1
        end
        counts.select { |_k, n| n > 1 }
              .sort_by { |(kind, id), _n| [kind, id] }
              .map { |(kind, id), n| [kind, id, n] }
      end

      # --- P0-HF-02: ktore duplicity ZLIEVAJU VLASTNIKOV KOVANIA ------------
      #
      # Podmnozina `duplicate_identities`, ktora sa tyka VYHRADNE SKRINIEK.
      # Expanzia setov deduplikuje clena `per: 'owner'` klucom z `owner_id`
      # (`HardwareSets.expand_members`), takze dve fyzicke skrinky so spolocnym
      # ID dostanu napr. TipOn LEN RAZ — nakupny zoznam, rozpocet aj cenova
      # ponuka by niesli ZNAMY PODPOCET. Doska taky dosledok nema (kovanie
      # nemá), preto do tejto mnoziny NEPATRI a export neblokuje.
      #
      # VEREJNE a je to JEDINY zdroj kriteria „blokuje zapis suboru" — cita ho
      # brana exportov `ProductionCore.export_blockers`. Rovnaka podmienka
      # rozhoduje aj o zneni nalezu v Kontrole (`duplicate_id_item`), takze
      # sa hlaska a brana nemozu rozist.
      def duplicate_owner_ids(identities)
        duplicate_identities(identities).select { |kind, _id, _n| kind == KIND_CABINET }
      end

      # Doplnok predchadzajucej: duplicity BEZ dosledku na kovanie (dosky).
      # Export ich neblokuje, ale kusovnik ich zlieva do jedneho vlastnika,
      # takze sa musia PRIZNAT — a nikdy nie textom o kovani (hlaska, ktora raz
      # klamala, sa prestane citat).
      def duplicate_plain_ids(identities)
        duplicate_identities(identities).reject { |kind, _id, _n| kind == KIND_CABINET }
      end

      # Adresa klik-selectu je TA ISTA ako pri D-103 (`dup_kind` + `dup_owner_ids`),
      # takze `pids_for_duplicate` sa znovupouziva bez jedineho riadku navyse —
      # klik oznaci VSETKY kusy, ktore si ID delia.
      # Dosledok sa hovori PODMIENENE (review 1b-3 P3-2, precedens CAT_MATERIAL):
      # zliatie vlastnikov v kusovniku plati vzdy, ale podpocitane kovanie LEN
      # vtedy, ked ma set clena uctovaneho na vlastnika. Bezpodmienecne tvrdenie
      # by pri sete bez takeho clena klamalo — a hlaska, ktora raz klamala, sa
      # prestane citat.
      def duplicate_id_item(kind, id, count)
        cab = kind == KIND_CABINET
        noun = cab ? 'Skrinky' : 'Dosky'
        follow = if cab
                   'Kusovník ich zlieva do jedného vlastníka a kovanie účtované na vlastníka ' \
                   '(napr. TipOn) sa započíta len raz.'
                 else
                   'Kusovník ich zlieva do jedného vlastníka.'
                 end
        { 'severity' => ORANGE, 'category' => CAT_DUP_ID,
          'owner_id' => id, 'part_key' => nil, 'hw_key' => nil,
          'dup_kind' => kind, 'dup_owner_ids' => [id],
          'message_sk' => "#{noun} s ID #{id} sú v modeli #{count}× — kópia ešte nedostala " \
                          "vlastné ID. #{follow} Identita sa opraví pri najbližšom zásahu " \
                          'do modelu (posuň kópiu alebo ju uprav v Inspectore).',
          'stable_key' => "#{CAT_DUP_ID}|#{kind}|#{id}" }
      end

      # --- KOV-A1: tvrde nalezy kovania (`hardware_issues` z Bom.collect) ----
      #
      # Aditivny kluc zberu; nil / chybajuci = kontrola sa cela preskoci (legacy
      # volania a headless testy bez neho, vzor `placements:`). V A1 sa spracuva
      # JEDINY kod — ostatne (KOV-C/D: drawer_no_fit, owner bez setu…) sa
      # ZAMERNE ignoruju, aby ich prve verzie neprepadli do Kontroly skor, nez
      # bude hotova ich brana.
      def check_hardware_issues(issues, items)
        Array(issues).each do |iss|
          next unless iss.is_a?(Hash)
          next unless iss['code'].to_s == 'front_direction_unset'

          items << front_direction_item(iss)
        end
      end

      # RED riadok „dvierka bez urceneho smeru". Znenie podla mockupu (scena 4):
      # menuje CELO (`label` zo servera — `PartKeys.human_label`) aj SKRINKU
      # a otvorene hovori, ze export zatial nezastavi.
      #
      # `owner_pid` je EXTRA pole MIMO `stable_key` (vzor `extra:` v
      # `record_item`): identita PROBLEMU je kategoria + vlastnik + dielec, aby
      # klik-select po prestavbe nasiel cerstvu entitu; `owner_pid` je len
      # adresa VYSKYTU pri duplicitnom `cabinet_id` (FIX 11).
      def front_direction_item(iss)
        oid = iss['owner_id'].to_s
        pkey = iss['part_key'].to_s
        label = iss['label'].to_s.strip
        label = pkey.empty? ? 'čelo' : pkey if label.empty?
        { 'severity' => RED, 'category' => CAT_FRONT_DIR,
          'owner_id' => oid, 'part_key' => (pkey.empty? ? nil : pkey), 'hw_key' => nil,
          'owner_pid' => iss['owner_pid'],
          'message_sk' => "Čelo #{label} (#{oid.empty? ? '—' : oid}) — smer otvárania je " \
                          '„Neurčený“. Smer = strana pántov; urči ho v karte čela. ' \
                          'Exporty to zatiaľ neblokuje (smer nemení žiadne dnešné číslo) — ' \
                          'zablokuje až výrobné zadanie, ktoré smer ponesie (D-95).',
          'stable_key' => "#{CAT_FRONT_DIR}|#{oid}|#{pkey}" }
      end

      # --- KOV-H1 (R-12 exportna brana): skrinka z NOVSEJ verzie -------------
      #
      # Aditivny kluc zberu (`newer_configs`); nil / chybajuci = kontrola sa
      # cela preskoci (legacy volania a headless testy bez neho, vzor
      # `placements:`). Na rozdiel od `front_direction` tento RED exportnu branu
      # MA — Kontrola ho ukazuje preto, aby sa o probleme vedelo skor, nez
      # pouzivatel dolaďuje rozpocet a naraz mu export odmietne vzniknut.
      # GHOST-D1: zaznam nesie DRUH (`kind: 'cabinet' | 'board'`), takze nalez
      # pomenuje „Skrinka"/„Doska". Holy String (legacy volania, headless testy)
      # sa cita ako skrinka. Zoznam blokovanych vystupov je UPLNY — od GHOST-D1
      # brana plati aj pre VEPO a kusovnik nad takym objektom je neuplny.
      # Vracia TROJICU `[kind, id, owner_pid]`. `owner_pid` (Codex #298 kolo 2)
      # je STRUKTUROVANA adresa entity — pri objekte BEZ vyrobneho ID je to
      # jediny udaj, podla ktoreho vie klik na nalez najst kus v modeli
      # (`id` je vtedy len ludsky retazec „bez ID (pid N)"). Legacy zaznam
      # (holy String) `owner_pid` nema — vtedy sa hlada podla ID ako doteraz.
      def newer_config_entry(raw)
        pid = nil
        if raw.is_a?(Hash)
          kind = (raw['kind'] || raw[:kind]).to_s
          id = (raw['id'] || raw[:id]).to_s.strip
          pid = raw['owner_pid'] || raw[:owner_pid]
        else
          kind = 'cabinet'
          id = raw.to_s.strip
        end
        [kind == 'board' ? 'board' : 'cabinet', id,
         (pid.is_a?(Integer) && pid.positive? ? pid : nil)]
      end

      def check_newer_configs(entries, items)
        Array(entries).each do |raw|
          kind, id, pid = newer_config_entry(raw)
          next if id.empty?

          subject = kind == 'board' ? 'Doska' : 'Skrinka'
          items << { 'severity' => RED, 'category' => CAT_NEWER_CFG,
                     'owner_id' => id, 'owner_pid' => pid, 'part_key' => nil, 'hw_key' => nil,
                     'message_sk' => "#{subject} #{id} je z novšej verzie Noxun — tento plugin jej " \
                                     'nastavenia nepozná celé. Kusovník je neúplný a exporty sa ' \
                                     'nevytvoria (VEPO, nákupný zoznam kovania, rozpočet, ' \
                                     'cenová ponuka); aktualizuj plugin.',
                     'stable_key' => "#{CAT_NEWER_CFG}|#{id}" }
        end
      end

      # --- KOV-H1: ad-hoc polozky kovania (`hardware_manual` z Bom.collect) ---
      #
      # Aditivny kluc zberu; nil / chybajuci = kontrola sa cela preskoci (vzor
      # `placements:`). V H1 ma JEDINY nalez: MRTVY VLASTNIK. Polozka ostava
      # v nakupe — nalez existuje preto, aby si clovek vsimol, ze uz nevie,
      # KAM kovanie patri (dielec zanikol pri zmene konstrukcie).
      def check_hardware_manual(manual, items)
        Array(manual).each do |it|
          next unless it.is_a?(Hash) && it['owner_missing'] == true

          oid = it['owner_id'].to_s
          pkey = it['owner_part_key'].to_s
          name = it['name'].to_s.strip
          name = it['code'].to_s.strip if name.empty?
          name = 'bez názvu' if name.empty?
          items << { 'severity' => ORANGE, 'category' => CAT_HW_ADHOC,
                     'owner_id' => oid, 'part_key' => nil, 'hw_key' => nil,
                     'owner_pid' => it['owner_pid'],
                     'message_sk' => "Ručná položka kovania „#{name}“ (#{oid.empty? ? '—' : oid}) " \
                                     'nemá vlastníka — dielec už neexistuje. Položka ostáva ' \
                                     'v nákupe; prepni ju na iný dielec alebo ju zmaž.',
                     'stable_key' => [CAT_HW_ADHOC, oid, pkey, it['id'].to_s].join('|') }
        end
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
            when 'length_unsupported'
              # R-06 (brana 1d): cena dlzkoveho kovania je za METER — nasobit ju
              # poctom KUSOV by dalo nespravne peniaze v nakupe aj v ponuke.
              # Veta preto povie AJ rozmer (co objednat) AJ co s tym.
              cut = u['params_label'].to_s.strip
              cut_txt = cut.empty? ? '' : " (#{cut})"
              "#{label} (#{where}): položka#{cut_txt} sa reže na dĺžku, ale set „#{sid}“ počíta kusy — " \
                'nie je nacenená. Dĺžkové kovanie sa zatiaľ do setu mapovať nedá — objednaj ho ručne.'
            when 'class_unmapped'
              # KOV-C2a: zasuvka si set vybera TRIEDNYM klucom a na genericky
              # `slide` NIKDY nepada (H70 kit k zasuvke H176 by bol zly nakup).
              # Veta preto navigje na EXISTUJUCU akciu, nie na „vyber set".
              "#{label} (#{where}): zásuvka nemá predvolený set pre svoje otváranie a konštrukciu — " \
                'otvor Pravidlá → Doplniť nové predvoľby.'
            when 'set_incompatible'
              # KOV-C2a: vybrany set klasifikaciou polozke nesedi (iny system,
              # ina vyska, ine otvaranie/konstrukcia, alebo override skrinky
              # nie je vyskovy selektor). NIKDY sa nesiahne po inom sete.
              "#{label} (#{where}): set „#{sid}“ nesedí so zásuvkou " \
                "(#{HardwareSets.incompatible_detail_sk(u['detail'])}) — uprav predvoľbu setu."
            when 'library_incompatible'
              # R-07 (brana 1d): globalna kniznica setov je z novsej verzie
              # alebo ma neznamy tvar — POUZIT sa nesmie (nakup z orezanych dat
              # by bol NEUPLNY a ticho). Projekt vlastne predvolby este nema.
              "#{label} (#{where}): knižnica setov kovania sa nedá bezpečne prečítať a projekt vlastné " \
                'predvoľby ešte nemá — kovanie je bez kódov (nenacenené). Aktualizuj plugin, alebo ' \
                'nastav predvoľby setov projektu v Štúdiu.'
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
          next unless row.is_a?(Hash)
          # KOV-H1: `catalog_missing` je TA ISTA pricina („kod nie je v katalogu")
          # s inym dosledkom — ad-hoc riadok ma SNAPSHOT nazvu, takze mu chyba
          # LEN cena. Riadok ide TOU ISTOU ORANGE cestou, len s vetou, ktora
          # menuje RUCNU polozku (a nie set, ktory ziadny nema).
          next unless row['missing'] == true || row['catalog_missing'] == true
          code = row['code'].to_s
          Array(row['sources']).each do |src|
            next unless src.is_a?(Hash)
            oid = src['cabinet_id'].to_s
            opk = src['owner_part_key'].to_s
            gt  = src['generic_type'].to_s
            adhoc = src['origin'].to_s == 'adhoc'
            msg = if adhoc
                    "Ručná položka „#{row['name_sk']}“ (kód #{code}, #{oid.empty? ? '—' : oid}) " \
                      'už nie je v katalógu kovania — v nákupe ostáva bez ceny.'
                  else
                    "Kód #{code} zo setu „#{src['set_id']}“ nie je v katalógu kovania — bez názvu a ceny."
                  end
            items << {
              'severity' => ORANGE, 'category' => CAT_HW_CODE,
              'owner_id' => oid, 'part_key' => (opk.empty? ? nil : opk), 'hw_key' => nil,
              'message_sk' => msg,
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
      #
      # ŠT-1b (Š8, audit #4): ked volajuci dodá ZOZNAM ID SKRINIEK, pribuda aj
      # ZELENE cislo semaforu — „skriniek bez nalezu" = pocet korpusov minus
      # tie, ktore v zozname nalezov figuruju ako vlastnik. Pocita ho SERVER
      # (klient si zo zoznamu nic neodvodzuje); rozpoctove polozky vlastnika
      # nemaju, takze zelene cislo neovplyvnuju.
      #
      # `cabinets:` je SKUTOCNY pocet skriniek zo zberu (`collected[:cabinets]`)
      # a je to MENOVATEL — `cabinet_ids` je len mnozina ID, ktore sa daju
      # spojit s nalezom, a moze byt MENSIA (kopie so zhodnym ID, skrinka bez ID
      # ci s degenerovanymi rozmermi placement nedostane). Bez neho sa pocet
      # odvodi zo zoznamu ID (spatna kompatibilita a headless testy).
      # Bez zoznamu (`cabinet_ids: nil`) je tvar counts PRESNE taky, aky bol.
      #
      # PRIJATY LIMIT (review #8): nalez „dva kusy na jednom mieste" nesie
      # owner_id PRVEHO vlastnika skupiny, takze zo skupiny „spini" zelene cislo
      # len jedna skrinka. Vedome sa nerozvadza — nalez aj tak vedie k oprave
      # celej skupiny a rozpad na viac vlastnikov by zmenil `stable_key`
      # (a s nim klik-select aj dedup).
      def counts(items, cabinet_ids: nil, cabinets: nil)
        red = items.count { |it| it['severity'] == RED }
        orange = items.count { |it| it['severity'] == ORANGE }
        out = { 'red' => red, 'orange' => orange, 'total' => red + orange }
        return out if cabinet_ids.nil?

        total = cabinets.nil? ? cabinet_ids.length : cabinets.to_i
        owners = items.map { |it| it['owner_id'].to_s }.reject(&:empty?).uniq
        dirty = cabinet_ids.count { |id| owners.include?(id) }
        # Menovatel a citatel su z dvoch zdrojov (pocet zo zberu, ID z placements),
        # takze zaporne cislo je teoreticky mozne — nikdy sa nezobrazi.
        out.merge('cabinets' => total, 'clean' => [total - dirty, 0].max)
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
