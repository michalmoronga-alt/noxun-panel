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
#   Bom.collect(model) -> {records:, hardware:, hardware_overrides:, manual_overrides:,
#                          cabinet_sets:, cabinet_set_conflicts:, placements:, identities:,
#                          hardware_issues:, warnings:, cabinets:, boards:}
#   Bom.compute(collected) -> {rows:, sheets:, edging:, hardware:, warnings:, summary:}
# Headless testy krmia compute() zaznamami priamo (collect je tenky a vyzaduje SketchUp).
#
# V0.5 D (kontrolny semafor): collect ADITIVNE nesie `role` v kazdom zazname (z entity)
# a raw `hardware_overrides` (owner_id/owner_pid + disabled) — Validation.run z toho
# stavia zoznam problemov. compute() tieto polia IGNORUJE (tvar vystupu nezmeneny,
# BuildPlan SCHEMA nedotknuta, ziadna migracia).
#
# ŠT-3b-2a (audit F6/F16): `manual_overrides` = RUCNE ZASAHY POUZIVATELA sparovane
# s REALNYMI dielcami — { 'abs' => [...], 'hardware' => [...] }. Sekcia Pravidlá
# z nich kresli jantarove riadky. Zbiera sa v TOM ISTOM prechode z UZ nacitaneho
# `ccfg` (ziadny druhy sken modelu) a `compute()` ho — ako ostatne aditivne kluce
# — IGNORUJE. Kluc je aditivny: kto ho nepozna, nic nestrati.
#   PRECO PAROVANIE (audit B2/F14): `PartKeys.migrate_overrides` zachovava kluce
#   dielcov, ktore uz v pláne NEEXISTUJU (zmenena konstrukcia) — a `hardware_overrides`
#   s nesediacim `owner_part_key` sa ticho neaplikuju. Taky zaznam sa preto NEKRESLI
#   (nikto by nevedel, k comu patri); paruje sa VYHRADNE s VNORENYM vyrobnym dielcom
#   toho isteho korpusu — override zije v korpuse a odpojene dvojca by prestavba
#   aj tak neprekreslila.
#
# KOV-A1 (audit #14 BLOCKER 1 + FIX 11): `hardware_issues` = novy ADITIVNY kluc
# s TVRDYMI nalezmi kovania. V A1 ma jediny kod `front_direction_unset` (dvierka
# s vedome NEURCENYM smerom otvarania). Kluc je aditivny: `compute()` ho — ako
# ostatne aditivne kluce — IGNORUJE, takze kusovnik, nakup ani ceny sa nemenia
# ani o cislo. Jediny citatel je `Validation.run` (RED kategoria `front_direction`,
# ZIADNA exportna brana — brana je pre-committed v AUDIT_REGISTER R-39 a pristane
# az s prvym vystupom, ktory smer realne spotrebuje, D-95).
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
        hardware_overrides = []
        manual_overrides = { 'abs' => [], 'hardware' => [] }
        hardware_issues = [] # KOV-A1: tvrde nalezy kovania (zatial len smer dvierok)
        newer_configs = []   # KOV-H1 (R-12 exportna brana): ID skriniek z NOVSEJ verzie
        cabinet_sets = {}
        # R-34 (review #262 P1): `cabinet_sets` ma na ID JEDEN slot — pozri
        # `note_cabinet_sets`. `seen` drzi mapu PRVEJ instancie toho ID (nil =
        # instancia ziadny override nemala), `conflicts` ID, kde sa instancie
        # rozisli a nakupne KODY su preto neiste.
        cabinet_sets_seen = {}
        cabinet_set_conflicts = {}
        warnings = []
        placements = [] # D-103: umiestnenie top-level skriniek/dosiek (zachytna siet duplicit)
        # 1b-3: IDENTITA kazdej top-level skrinky/dosky — jeden zaznam na INSTANCIU.
        # Dve instancie s tym istym ID = duplicitna identita (kopia pred dedup tikom).
        # Zber je CISTE CITANIE: zaznamenava sa, NEOPRAVUJE sa (oprava = observer,
        # pozri komentar `fresh_collect` v production_core.rb).
        identities = []
        cabinets = 0
        boards = 0
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          case Store.kind(inst)
          when 'cabinet'
            cabinets += 1
            cid = Store.get(inst, 'cabinet_id').to_s
            add_placement(placements, inst, 'cabinet', cid)
            add_identity(identities, 'cabinet', cid)
            ccfg = Store.config(inst) || {}
            # KOV-H1 (audit #15 BLOCKER 3): R-12 chranil LEN prestavbu — starsi
            # plugin by zakazku so schemou z novsej verzie bez problemov
            # VYEXPORTOVAL, len bez toho, comu nerozumie (napr. bez ad-hoc
            # kovania), a nakup by bol NEUPLNY bez slova. Zber to preto priznava
            # ADITIVNYM klucom; branu drzi `ProductionCore.export_blockers`
            # (nakupny CSV + rozpocet + ponuka; VEPO nie) a Kontrola RED riadok.
            # `compute()` kluc — ako ostatne aditivne — IGNORUJE.
            newer_configs << cid if !cid.empty? && !newer_configs.include?(cid) &&
                                    defined?(CabinetBuilder) && CabinetBuilder.newer_config?(ccfg)
            Array(ccfg['hardware']).each { |h| hardware << h.merge('owner_id' => cid, 'owner_pid' => inst.persistent_id) }
            # V0.5 D (nalez 2): RAW hardware_overrides — disabled:true polozka je
            # UZ VYRADENA z config.hardware[] pri vyhodnoteni pravidiel, takze semafor
            # "vypnute kovanie" ju vie zistit LEN z povodneho zaznamu. owner_id/owner_pid
            # = adresa korpusu pre klik-select.
            Array(ccfg['hardware_overrides']).each do |ov|
              next unless ov.is_a?(Hash)
              hardware_overrides << ov.merge('owner_id' => cid, 'owner_pid' => inst.persistent_id)
            end
            # V0.6 D1: cabinet override setov kovania (mapa generic_type=>set_id)
            # — expanzia setov ju berie per korpus (audit B1/F6). Aditivne pole,
            # compute() ho ignoruje.
            # KOV-A1: smerove nalezy sa citaju z ULOZENEHO `front_items` (resolved
            # cela) — presne ako kovanie z `config.hardware[]`: ZIADNE
            # prepocitavanie planu, ziadne citanie geometrie.
            hardware_issues.concat(
              front_direction_issues(cid, inst.persistent_id, ccfg['front_items'])
            )
            cs = ccfg['hardware_sets']
            note_cabinet_sets(cid, (cs.is_a?(Hash) && !cs.empty? ? cs : nil),
                              cabinet_sets, cabinet_sets_seen, cabinet_set_conflicts)
            Array(ccfg['warnings']).each { |w| warnings << (w.is_a?(Hash) ? w.merge('owner_id' => cid) : { 'message' => w.to_s, 'owner_id' => cid }) }
            # ŠT-3b-2a: mapa VNORENYCH dielcov korpusu (part_key -> zaznam) sa
            # stavia POPRI zbere — je to jediny podklad, proti ktoremu sa daju
            # sparovat rucne zasahy (nizsie), a nestoji ziadny dalsi prechod.
            nested = {}
            inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
              next unless Store.kind(pi) == 'part'
              next unless Store.get(pi, 'manufactured') == true
              next unless Store.get(pi, 'production_class').to_s == 'sheet'
              rec = record(Store.config(pi) || {}, owner_id: cid,
                           name: Store.get(pi, 'name').to_s,
                           part_key: Store.get(pi, 'part_key').to_s,
                           role: Store.get(pi, 'role').to_s,
                           pid: pi.persistent_id)
              records << rec
              key = rec['part_key'].to_s
              nested[key] = rec unless key.empty? || nested.key?(key)
            end
            collect_manual_overrides(manual_overrides, ccfg, cid, nested)
          when 'board'
            boards += 1
            # D-103: umiestnenie sa zbiera PRED filtrom manufactured — duplicitna
            # doska je duplicitna aj ked sa (docasne) nevyraba.
            add_placement(placements, inst, 'board', Store.get(inst, 'id').to_s)
            # 1b-3: identita sa zbiera TIEZ pred filtrom manufactured — zdielane ID
            # je chyba identity aj vtedy, ked sa doska (docasne) nevyraba.
            add_identity(identities, 'board', Store.get(inst, 'id').to_s)
            next unless Store.get(inst, 'manufactured') == true
            bcfg = Store.config(inst) || {}
            bid = Store.get(inst, 'id').to_s
            # 2A-3 (audit B2): warnings poslednej stavby DOSKY — doteraz sa
            # zbierali len z korpusov a warning vyberu ABS by sa pri samostatnej
            # doske stratil pred semaforom (config -> collect -> Validation.run).
            Array(bcfg['warnings']).each do |w|
              warnings << (w.is_a?(Hash) ? w.merge('owner_id' => bid) : { 'message' => w.to_s, 'owner_id' => bid })
            end
            records << record(bcfg, owner_id: bid,
                              name: (bcfg['name'] || 'Doska').to_s,
                              part_key: Store.get(inst, 'part_key').to_s,
                              role: (Store.get(inst, 'role') || bcfg['role']).to_s,
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
                              role: Store.get(inst, 'role').to_s,
                              pid: inst.persistent_id)
          end
        end
        { records: records, hardware: hardware, hardware_overrides: hardware_overrides,
          manual_overrides: manual_overrides,
          cabinet_sets: cabinet_sets, cabinet_set_conflicts: cabinet_set_conflicts,
          placements: placements, identities: identities,
          hardware_issues: hardware_issues, newer_configs: newer_configs,
          warnings: warnings, cabinets: cabinets, boards: boards }
      end

      # KOV-A1: nalezy „dvierka bez urceneho smeru" jedneho korpusu.
      #
      # CISTA funkcia (ziadny SketchUp objekt) — headless testovatelna; `collect`
      # jej dodava uz nacitane `ccfg['front_items']`, takze nevznika druhy sken
      # modelu. Aplikovatelnost rozhoduje VYHRADNE `Fronts.direction_slots`
      # (jedina definicia, audit #14 BLOCKER 3) a nalez vznika VYHRADNE pri
      # stave `unset`:
      #   nil (kluc v configu chyba) = LEGACY -> ziadny nalez, NIKDY
      #   'left'/'right'             = vyriesene -> ziadny nalez
      #
      # `owner_pid` (FIX 11) je `persistent_id` KONKRETNEJ instancie — pri dvoch
      # skrinkach so zdielanym `cabinet_id` je to jediny udaj, ktorym sa da
      # ukazat, KTORA z nich smer nema. Do `stable_key` nalezu NEVSTUPUJE
      # (identita problemu je kategoria + vlastnik + dielec), nesie sa vedla.
      def front_direction_issues(owner_id, owner_pid, front_items)
        items = front_items.is_a?(Array) ? front_items : []
        out = []
        items.each do |item|
          next unless item.is_a?(Hash)

          Fronts.direction_slots(item).each do |slot|
            next unless slot[:state].to_s == 'unset'

            out << { 'code' => 'front_direction_unset', 'severity' => 'red',
                     'owner_id' => owner_id.to_s, 'owner_pid' => owner_pid,
                     'part_key' => slot[:part_key].to_s,
                     'front_id' => item['id'].to_s,
                     'label' => PartKeys.human_label(slot[:part_key], fronts: items).to_s }
          end
        end
        out
      end

      # R-34 (review #262 P1): `cabinet_sets` je mapa ID => override setov, teda
      # na jedno ID JEDEN slot. Ked si dve fyzicke skrinky delia `cabinet_id`,
      # posledna prepise prvu — a `resolve_set_id` potom aplikuje TU JEDNU mapu
      # na OBE (kluc je `owner_id`). Ked sa instancie rozisli, nie su neiste len
      # POCTY (to riesi dedup `per: 'owner'`), ale rovno KODY v nakupe, rozpocte
      # aj v ponuke — a to sa uz nedokaze ani vyvratit. Take ID sa preto priznava
      # ako konflikt a brana exportov (`ProductionCore.dup_partition`) ho blokuje.
      # ZHODNE mapy (bezna kopia skrinky) konflikt NIE su — vysledok je rovnaky
      # nech vyhra ktorakolvek, takze blokovat ich by bolo falosne pozitivne.
      #
      # Zaznam nesie KLUCE, v ktorych sa instancie rozisli (review #262 P2):
      # rozdiel v type, ktory si skrinka vobec nemapuje, nikoho nepomyli —
      # relevanciu rozhoduje az brana (`ProductionCore.dup_partition`), lebo
      # az ona vidi polozky kovania. `conflicts` je mapa ID => zoznam klucov.
      # Porovnava sa proti PRVEJ videnej instancii; ked su si vsetky rovne,
      # rovna sa jej kazda, takze jedno porovnanie staci.
      # `map` = override mapa instancie alebo nil (instancia ziadny nema).
      def note_cabinet_sets(cid, map, cabinet_sets, seen, conflicts)
        cabinet_sets[cid] = map if map
        unless seen.key?(cid)
          seen[cid] = map
          return
        end
        diff = differing_override_keys(seen[cid], map)
        return if diff.empty?
        cur = (conflicts[cid] ||= [])
        diff.each { |k| cur << k unless cur.include?(k) }
        cur.sort!
      end

      # Kluce, v ktorych sa dve override mapy nezhoduju — vratane tych, ktore
      # jedna z nich VOBEC NEMA (chybajuci override je tiez rozdiel: expanzia by
      # na tu instanciu pouzila cudzi zaznam namiesto projektoveho mapovania).
      # Kluc sa TRIMUJE — expanzia ho vidi az po `normalize_cabinet_overrides`
      # (parser kluce strippuje), takze neorezany zapis by sa v brane netrafil
      # do kluca, ktory sa realne pouzije.
      def differing_override_keys(a, b)
        ah = a.is_a?(Hash) ? a : {}
        bh = b.is_a?(Hash) ? b : {}
        (ah.keys | bh.keys).select { |k| ah[k] != bh[k] }.map { |k| k.to_s.strip }
      end

      # 1b-3: jeden zaznam na INSTANCIU (nie na ID) — pocet zaznamov s tym istym
      # ID je presne pocet instancii, ktore si ho delia. Prazdne ID sa zahadzuje:
      # „bez ID" je ina chyba (poskodeny objekt) a dva take kusy nie su duplicitna
      # identita. Ziadny SketchUp objekt sa neuklada — zaznam je cisty JSON tvar.
      def add_identity(out, kind, id)
        s = id.to_s.strip
        return if s.empty?

        out << { 'kind' => kind.to_s, 'id' => s }
      end

      # ŠT-3b-2a: RUCNE ZASAHY jedneho korpusu sparovane s jeho VNORENYMI dielcami.
      #
      # ABS (audit B1): autorita je PRITOMNOST kluca `edges` v zazname
      # `part_overrides[part_key]` — presne to, co zapisovacia cesta panela maze,
      # ked sa dielec vracia „na pravidlo". POROVNANIE HODNOT by bola tretia pravda
      # o hranach a klamalo by pri kazdej zmene katalogu; config ENTITY dielca navyse
      # nesie VYRIESENY snapshot hran VZDY, takze ako override sa citat NESMIE.
      #   Dosky (kind=board) tu zamerne nie su: `board_builder` uklada vyriesenu mapu
      #   hran vzdy, takze jej pritomnost o rucnom zasahu nehovori NIC.
      #
      # KOVANIE: zaznam s prazdnym `owner_part_key` patri celemu korpusu (paruje sa
      # vzdy); zaznam s konkretnym klucom LEN ked taky dielec naozaj existuje.
      def collect_manual_overrides(out, ccfg, cid, nested)
        # Nazov korpusu do nadpisu skupiny, aby sa dala skrinka najst aj bez
        # klikania. MUSI to byt `display_name`, NIE `ccfg['name']`: D-100 uklada
        # do configu LEN RUCNY nazov (nil = zivy default podla typu a sirky),
        # takze surovy kluc je pri vacsine skriniek PRAZDNY a v zozname by ostalo
        # hole „CAB-004". `display_name` da presne to, co pouzivatel vidi v paneli.
        cab_name = if defined?(CabinetBuilder)
                     CabinetBuilder.display_name(ccfg).to_s
                   else
                     ccfg['name'].to_s
                   end
        ov = ccfg['part_overrides']
        if ov.is_a?(Hash)
          ov.each do |pkey, rec|
            next unless rec.is_a?(Hash) && rec['edges'].is_a?(Hash)
            part = nested[pkey.to_s]
            next if part.nil?

            # 1b-4 (D4): zaznam nesie PRESNE to, z coho sa kresli jantarovy
            # riadok. `material_id` aj `pid` boli MRTVE polia — `abs_override_row`
            # ich necita a citat ich ani nema z coho: riadok hovori o rozhodnuti
            # cloveka (nie o materiali) a adresa „oka" je zamerne IDENTITA
            # (owner_id + part_key), nie persistent_id („žiadne pids z DOM",
            # `rdSelectOverride` v `js/rules.js`). Pole, ktore nikto necita,
            # zvadza buduci kod postavit sa na nu — a `pid` by to bola priam
            # pozvanka obist prave tu identitnu cestu.
            out['abs'] << { 'owner_id' => cid, 'owner_name' => cab_name, 'part_key' => pkey.to_s,
                            'role' => part['role'].to_s, 'name' => part['name'].to_s,
                            'edges' => rec['edges'].dup }
          end
        end
        Array(ccfg['hardware_overrides']).each do |hov|
          next unless hov.is_a?(Hash)

          pkey = hov['owner_part_key'].to_s
          part = pkey.empty? ? nil : nested[pkey]
          next if !pkey.empty? && part.nil?

          out['hardware'] << hov.merge('owner_id' => cid, 'owner_name' => cab_name,
                                       'part_role' => part ? part['role'].to_s : '',
                                       'part_name' => part ? part['name'].to_s : '')
        end
      end

      # D-103: umiestnenie top-level NOXUN objektu pre kontrolu „dva kusy na
      # jednom mieste" (zachytna siet po `*N` nasobeni kopii). Zbiera sa VYHRADNE
      # to, co sa da porovnavat: pozicia v mm (Units — jedina autorita prevodu),
      # NORMALIZOVANE osi (orientacia bez scale) a vonkajsie rozmery definicie.
      # Codex audit FIX 5: nepouzitelny zaznam sa radsej NEZBIERA (chybajuce ID,
      # nekonecne/NaN cisla, degenerovana definicia) — falosny ORANGE by bol
      # horsi nez ziadny; zhoda musi byt preukazatelna, nie odhadnuta.
      def add_placement(out, inst, kind, owner_id)
        return if owner_id.to_s.strip.empty?
        tr = inst.transformation
        o = tr.origin
        b = inst.definition.bounds
        origin = [Units.to_mm(o.x), Units.to_mm(o.y), Units.to_mm(o.z)].map(&:to_f)
        size = [Units.to_mm(b.width), Units.to_mm(b.height), Units.to_mm(b.depth)].map(&:to_f)
        axes = [tr.xaxis, tr.yaxis, tr.zaxis].map do |v|
          n = v.length.to_f
          return if n <= 0.0 || !n.finite?
          [v.x / n, v.y / n, v.z / n].map(&:to_f)
        end.flatten
        return unless (origin + size + axes).all? { |v| v.is_a?(Float) && v.finite? }
        return if size.any? { |v| v <= 0.0 }
        out << { 'kind' => kind.to_s, 'owner_id' => owner_id.to_s,
                 'origin' => origin, 'axes' => axes, 'size' => size }
      rescue StandardError => e
        Engine.log_error(e, 'Bom.add_placement') if defined?(Engine)
        nil
      end

      # Normalizovany zaznam zo snapshot configu (mm Float; edges mapa L1..W2 -> abs_id|nil).
      # pid = SketchUp persistent_id zdrojovej instancie (Codex B3 — jednoznacna adresa
      # pre klik-select aj pri docasne zdielanych ID pred dedup tickom); v headless
      # fixtures moze byt nil.
      # role (V0.5 D, nalez 1): rola dielca sa CITA Z ENTITY (na instancii dielca aj
      # dosky existuje ploche NOXUN/role) — kontrola ciel/dosiek bez ABS ju potrebuje.
      # Odvodenie z nazvu/part_key by bolo krehke a je zakazane.
      def record(cfg, owner_id:, name:, part_key:, role: '', pid: nil)
        edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : {}
        out = {
          'name' => name, 'part_key' => part_key, 'owner_id' => owner_id, 'pid' => pid,
          'role' => role.to_s,
          'length' => cfg['length'].to_f, 'width' => cfg['width'].to_f,
          'thickness' => cfg['thickness'].to_f,
          'quantity' => [cfg['quantity'].to_i, 1].max,
          'material_id' => cfg['material_id'].to_s,
          'grain_direction' => (cfg['grain_direction'] || 'none').to_s,
          'edges' => EDGE_ORDER.each_with_object({}) { |c, out2| out2[c] = edges[c] }
        }
        # 2B-1 (D-43): duplak vazba zo snapshotu — odhad platni cez nu preleje
        # plochu do ZDROJOVEHO materialu (nakupny pohlad). Cita sa LEN uplny tvar.
        ms = cfg['material_source']
        if ms.is_a?(Hash) && !ms['material_id'].to_s.empty? && ms['multiplier'].to_i >= 2
          out['material_source'] = { 'material_id' => ms['material_id'].to_s,
                                     'multiplier' => ms['multiplier'].to_i }
        end
        out
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
          # 2B-1: vazba je v kluci — riadok skupiny ju len zrkadli (vsetky zdrojove
          # zaznamy skupiny ju maju zhodnu).
          g['material_source'] = r['material_source'] if r['material_source']
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
        # 2B-1 (audit F7): duplak vazba patri do kluca — dielce s rovnakym
        # material_id ale roznym snapshotom vazby (katalog sa zmenil medzi
        # rebuildmi) sa NESMU zmiesat do jedneho riadku, odhad by ich nevedel
        # rozpocitat. Bez vazby je prvok nil = klucovo neutralny.
        ms = r['material_source']
        [dmm(r['length']), dmm(r['width']), dmm(r['thickness']),
         r['material_id'], EDGE_ORDER.map { |c| r['edges'][c].to_s },
         r['grain_direction'],
         ms ? [ms['material_id'].to_s, ms['multiplier'].to_i] : nil]
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
          row = { 'owner_id' => h['owner_id'].to_s, 'owner_pid' => h['owner_pid'],
                  'rule_id' => h['rule_id'].to_s,
                  'source' => h['source'].to_s, 'quantity' => q,
                  'owner_part_key' => h['owner_part_key'] }
          # D-93: pri rucne zamknutej NL nesie riadok AJ hodnotu automatu
          # (nil = automat nevedel) + hotovy slovensky popis pre tooltip.
          if h.key?('rule_nominal_length')
            rnl = h['rule_nominal_length']
            row['rule_nominal_length'] = rnl.is_a?(Numeric) ? rnl.to_f : nil
            row['manual_note'] = manual_note(row['rule_nominal_length'])
          end
          g['breakdown'] << row
        end
        out.values.sort_by { |g| [g['generic_type'], params_signature(g['params'])] }
      end

      # D-93: JEDINA autorita textu znamienka „ručne prepísané" (JS ho len vypise).
      def manual_note(rule_nl)
        auto = rule_nl.is_a?(Numeric) ? "#{fmt_mm(rule_nl)} mm" : 'nezmestí sa'
        "ručne prepísaná dĺžka (automat: #{auto})"
      end

      # Cele mm bez desatin, inak 1 desatinne miesto (slovenska ciarka) —
      # ten isty tvar ako HardwareRules.fmt_mm (Bom je cisty, bez zavislosti).
      def fmt_mm(v)
        f = v.to_f
        (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
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
