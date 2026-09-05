# frozen_string_literal: true
# Noxun Engine — modul cela (fronts) s LOCKMI. Standard sekcia 5.3.
# Cela stoja PRED korpusom (zaporne Y), delene na vysku, poradie ODSPODU nahor (F1 dole).
# Rezim polozky: 'fixed' (pevna vyska) alebo 'auto' (rovnomerne si rozdelia zvysok).
# 'locked' = fixed, ktore sa nemeni pri auto prepocte (priznak pre UI a buduci auto-fit).
# Typy riadkov: 'door' / 'drawer_front' / 'lift' / 'fall' / 'blind' / 'none'
# (D-18 „Bez cela" — riadok drzi vysku v rade ako celo, ale panel sa NEgeneruje =
# otvorena nika; POZOR: structured items[].type 'none' != legacy STRING config
# fronts='none', ktory znamena ziadne cela).
# KOV-A1: 'lift' (vyklop) a 'fall' (sklop) -> rola `flap`; 'blind' (blenda) ->
# rola `false_front`. Oba maju ROVNAKU panelovu matematiku ako zasuvkove celo
# (1 panel cez cely otvor, wings_n 1). UI ich spristupni az KOV-A2 — dovtedy
# vznikaju len cez config/API, ale kontrakt, builder aj vystupy ich uz poznaju.
# Cisto vypoctovy modul (mm Float) — vrati hotove deskriptory dielcov (box/origin/material).
module Noxun
  module Engine
    module Fronts
      # Zakladna hrubka pre cisty vypocet. Builder ju pri znamom katalogovom
      # materiali nahradi skutocnou hrubkou variantu (18 alebo 19 mm).
      FRONT_THICKNESS = 18.0
      GAP_DEFAULT     = 3.0   # skara medzi celami (zvislo) aj medzi kridlami dvierok
      GAP_EDGE        = 2.0   # skara hore/dole/po stranach
      GAP_MAX         = 50.0  # D-07: medzera medzi celami 0..GAP_MAX
      EDGE_LIMIT      = 100.0 # D-07: okraje v -EDGE_LIMIT..+EDGE_LIMIT (zaporne = presah cez obrys)
      # D-22: odomknuty limit okrajov (edge_limit_off=true) — velke presahy pre
      # obklady/pilastre. Medzera medzi celami (0..GAP_MAX) sa NEODOMYKA.
      EDGE_LIMIT_UNLOCKED = 2000.0
      AUTO_TWO_ABOVE  = 600.0 # nad touto sirkou celneho otvoru auto dvierka = 2 kridla
      MIN_AUTO        = 10.0  # ochrana: auto celo nikdy < 10 mm
      # D-90: najmensi ROZUMNY panel pod uchytkovym profilom (mm). Pod nim sa
      # hlasi warning (existujuci kanal warnings planu) — dvierka 100 mm vysoke
      # so 36 mm profilom su takmer iste omyl, ale NIE su nemozne (zaklopka).
      # Pod BuildPlan::MIN_DIM uz panel neexistuje -> tvrdy raise (profil bez
      # panelu nesmie ticho prejst ako dnesne degeneraty).
      MIN_PROFILE_PANEL = 70.0

      # --- KOV-A1: kontrakt typov a smerovych poli ----------------------------
      #
      # TYPY riadku. `lift`/`fall`/`blind` pribudli v KOV-A1; neznamy typ sa
      # (ako doteraz) sklopi na 'door' — config z novsej verzie tak nespadne,
      # len sa zobrazi konzervativne.
      TYPES = %w[door drawer_front lift fall blind none].freeze
      # Typy s rolou `flap` (jeden panel, smer vyklapania nesie `flap_dir`).
      FLAP_TYPES = %w[lift fall].freeze
      # Typy, ktore NEMAJU uchytkovy profil (D-90 profilove pravidlo pozna len
      # dvierka a zasuvkove celo — profil na vyklope by vyrobil falosny
      # `profile_rule_missing`; profil na pohyblivych celach je KOV-E/F).
      PROFILELESS_TYPES = %w[none lift fall blind].freeze
      # Smer otvarania = STRANA PANTOV (Michal 3.9.2026): 'left' = panty vlavo.
      # TROJSTAV (audit #14 BLOCKER 1): kluc CHYBA = legacy (ziadny nalez, NIKDY
      # sa nedoplna) · 'unset' = pouzivatel vedome nechal neurcene (RED) ·
      # 'left'/'right' = vyriesene. `unset` vznika VYHRADNE pouzivatelskou
      # akciou (KOV-A2) alebo z POSKODENEJ hodnoty (fail-visible, nizsie).
      DIRECTIONS = %w[left right unset].freeze
      # 3/4-kridlove dvierka (audit #14 BLOCKER 2, Michal 3.9. — variant a):
      # KRAJNE kridla su ODVODENE (p1 = panty vlavo, posledne = panty vpravo,
      # nic sa neuklada), STREDNE maju vlastny trojstav. p2 plati pri 3 aj 4
      # kridlach, p3 len pri 4; ine kluce sa zahadzuju.
      WING_DIRECTION_KEYS = %w[p2 p3].freeze
      # Sposob otvarania. Chybajuci kluc = legacy (citatelia neskor = classic);
      # NEPLATNA hodnota -> kluc PREC (na rozdiel od smeru tu ziadny „neurcene"
      # stav neexistuje, takze nie je co priznavat).
      OPENING_MODES = %w[classic tipon].freeze
      # Klasifikacia zasuvky (audit #14 BLOCKER 4). Chybajuci kluc = stav
      # „neklasifikovane" — NIKDY sa nedoplna `metal`+`standard`. Pod-polia sa
      # whitelistuju NEZAVISLE; hash bez jedineho platneho pod-pola -> kluc prec.
      DRAWER_CONSTRUCTIONS = %w[metal wood other].freeze
      DRAWER_VARIANTS      = %w[standard internal].freeze
      # KOV-C2b: EXPLICITNY system zasuvky (zasada 5) — hodnota zije popri
      # konstrukcii, server ju pri prestavbe doplni podla konstrukcie a zapise.
      DRAWER_SYSTEMS       = %w[atira quadro_v6].freeze
      # KOV-C2b: mapa pripnutych receptov `"<system>|<otvaranie>" => recipe_id`.
      # Kluc je UZAVRETY (systemy x otvarania), hodnota MUSI mat tvar
      # `<system>_<otvaranie>_v<cislo>`. Ci je recept naozaj VYDANY, sa TU
      # NEOVERUJE a je to vedome (fail-closed vyklad KOV-C2b): register receptov
      # je datovy pack, ktory sa medzi verziami LISI, a keby normalizacia
      # neregistrovany ref ticho zahodila, `Recipes.active_ref` by nikdy
      # nevratila stav `[:unknown, id]` a stary projekt by sa pri starsom plugine
      # TICHO prepol na `latest_for` — teda prave ta ticha zmena geometrie,
      # ktorej ma nemennost zabranit. Neznamy (ale tvarovo platny) ref preto
      # PREZIJE normalizaciu a stavba ho prizna ako RED `drawer_recipe_unknown`.
      RECIPE_REF_KEY_RE = /\A(#{DRAWER_SYSTEMS.join('|')})\|(sisy|p2o)\z/.freeze
      RECIPE_ID_RE      = /\A(#{DRAWER_SYSTEMS.join('|')})_(sisy|p2o)_v\d+\z/.freeze
      # Polia, ktore su DORMANT (audit #14 BLOCKER 3): v configu sa drzia VZDY
      # bez ohladu na aktualny typ a pocet kridiel, takze po navrate na
      # dvierka/1 kridlo sa ulozena hodnota obnovi. Aplikovatelnost urcuje
      # VYHRADNE `direction_slots` z efektivneho `wings_n`.
      DORMANT_KEYS = %w[direction wing_directions opening_mode drawer].freeze

      module_function

      # fronts_cfg: canonical hash (viz normalize_config) alebo legacy string ('none'/'1'/'2'/'auto') alebo nil.
      # width/height/floor_height/thickness = rozmery korpusu (mm).
      # Vrati: { parts:[deskriptory], items:[resolved s reÁlnymi vyskami],
      #          wings:Integer, warnings:[BuildPlan.warning] }.
      # D-90: warnings su kanonicky kanal planu (Construction ich pripoji do
      # plan[:warnings]) — nefatalne upozornenia matematiky ciel.
      def layout(fronts_cfg, width, height, floor_height, _thickness)
        cfg = normalize_config(fronts_cfg)
        # D-07: rozsahy medzier platia VZDY (aj bez ciel) — neplatne hodnoty sa
        # nesmu ulozit cez externy callback a vybuchnut az po pridani cela.
        validate_gap_ranges!(cfg)
        items = cfg['items']
        return { parts: [], items: [], wings: 0, warnings: [], bounds: {} } if items.nil? || items.empty?

        gap = cfg['gap']; gt = cfg['gap_top']; gb = cfg['gap_bottom']; gs = cfg['gap_sides']
        n = items.size
        opening_w = width - 2 * gs
        total_v = height - floor_height # celny otvor po vyske (od spodnej hrany tela po vrch)

        fixed_sum = items.select { |it| it['mode'] == 'fixed' }
                         .map { |it| it['height'].to_f }.reduce(0.0, :+)
        auto_count = items.count { |it| it['mode'] == 'auto' }
        remaining = total_v - gt - gb - (n - 1) * gap - fixed_sum
        validate_layout!(cfg, opening_w, total_v, fixed_sum, auto_count)
        auto_h = auto_count.zero? ? 0.0 : remaining / auto_count

        parts = []
        resolved = []
        warnings = []
        # KOV-C1: ADITIVNY kanal NEZAOKRUHLENYCH hranic riadkov ciel
        # ({ front_id => { z0, z1, height } }). `items` (= ulozeny `front_items`)
        # ostavaju NEDOTKNUTE — dalej nesu `round(2)`. Recepty zasuviek
        # porovnavaju svetlu vysku inkluzivne a bez EPS, takze zaokruhlena
        # hodnota by ticho povolila zasuvku, ktora sa nezmesti.
        bounds = {}
        total_wings = 0
        z = floor_height + gb
        items.each_with_index do |it, i|
          idx = i + 1
          h = it['mode'] == 'fixed' ? it['height'].to_f : auto_h
          validate_profile!(it, idx, h, warnings)
          panels = panels_for(it, idx, gs, opening_w, z, h, gap)
          total_wings += panels.size if it['type'] == 'door'
          parts.concat(panels)
          res = {
            'id' => it['id'] || "F#{idx}", 'type' => it['type'], 'mode' => it['mode'],
            'height' => h.round(2), 'locked' => !!it['locked'], 'wings' => it['wings'],
            'wings_n' => (it['type'] == 'door' ? panels.size : 1), # D-07: efektivny pocet kridiel pre nahlad
            # D-90: profil riadku ide aj do resolved itemu (nahlad/UI v PR 2).
            'profile' => it['profile'] || FrontProfiles::NONE,
            'z' => z.round(2)
          }
          # KOV-A1 (audit #14 FIX 6): `front_items` je SIESTA projekcia configu —
          # cache v ulozenom configu, ktoru cita nahlad, `human_label` aj
          # `Bom.collect`. Nove polia musia prejst aj tadiaj, ale VYHRADNE ako
          # pass-through: co v polozke NIE JE, sa tu NEVYMYSLI.
          DORMANT_KEYS.each { |k| res[k] = it[k] if it.key?(k) }
          # `flap_dir` je ODVODENY z typu (nie je to default smeru dvierok —
          # trojstav O1 sa tyka STRANY PANTOV, toto je smer vyklapania).
          res['flap_dir'] = (it['type'] == 'fall' ? 'down' : 'up') if FLAP_TYPES.include?(it['type'])
          resolved << res
          bounds[res['id']] = { z0: z.to_f, z1: (z + h).to_f, height: h.to_f }
          z += h + gap
        end
        { parts: parts, items: resolved, wings: total_wings, warnings: warnings, bounds: bounds }
      end

      # --- KOV-A1: JEDINA definicia „kde sa smer pyta" ------------------------
      #
      # Vstup je RESOLVED polozka cela (`front_items`, teda vystup `layout`),
      # NIE surova polozka configu — aplikovatelnost rozhoduje EFEKTIVNY pocet
      # kridiel `wings_n` (auto okolo 600 mm), nie surove `wings` (audit #14
      # BLOCKER 3). Vracia zoznam slotov:
      #   [{ wing: 'single'|'p2'|'p3', part_key: String, state: nil|'unset'|'left'|'right' }]
      # kde `state` nil = LEGACY (pole v configu vobec nie je -> ZIADNY nalez).
      #
      # Pravidlo (Michal 3.9.2026, variant a):
      #   1 kridlo  -> jeden slot `single` so scalarnym `direction`
      #   2 kridla  -> [] (odvodene: lave = panty vlavo, prave = panty vpravo)
      #   3 kridla  -> stredne kridlo p2
      #   4 kridla  -> stredne kridla p2 a p3
      #   ne-dvierka (zasuvka, vyklop, sklop, blenda, „Bez cela") -> []
      #
      # CISTA funkcia (ziadne IO) — citaju ju `Bom.collect` (A1), overlay aj
      # karta cela (A2). Nikde inde sa o aplikovatelnosti smeru NEROZHODUJE.
      # Neznamy/chybajuci `wings_n` (velmi stary ulozeny config) = 0 -> [],
      # cize legacy zakazka nikdy nedostane nalez z tejto cesty.
      def direction_slots(item)
        return [] unless item.is_a?(Hash) && item['type'].to_s == 'door'
        front_id = item['id'].to_s
        case item['wings_n'].to_i
        when 1
          [{ wing: 'single', part_key: PartKeys.front(front_id, 'wing', 'single'),
             state: item['direction'] }]
        when 3
          [wing_direction_slot(front_id, 'p2', item)]
        when 4
          [wing_direction_slot(front_id, 'p2', item), wing_direction_slot(front_id, 'p3', item)]
        else
          []
        end
      end

      # Slot STREDNEHO kridla — stav zije v `wing_directions`, nie v scalarnom
      # `direction` (ten pri viackridlovych dvierkach ostava dormant a NECITA sa).
      def wing_direction_slot(front_id, wing, item)
        wd = item['wing_directions']
        { wing: wing, part_key: PartKeys.front(front_id, 'wing', wing),
          state: (wd.is_a?(Hash) ? wd[wing] : nil) }
      end

      # D-90: kontrola vysky panelu POD profilom (po vypocte realnej vysky riadku).
      # Riadkova matematika sa nemeni — profil zabera hornych `reduction` mm riadku.
      #   panel <= BuildPlan::MIN_DIM  -> raise (panel by neexistoval)
      #   panel <  MIN_PROFILE_PANEL   -> warning (postavi sa, ale skoro iste omyl)
      def validate_profile!(item, idx, h, warnings)
        red = FrontProfiles.reduction(item['profile'])
        return if red <= 0.0 || item['type'] == 'none'
        panel_h = h.to_f - red
        pname = FrontProfiles.name(item['profile']) || 'Profil'
        if panel_h <= BuildPlan::MIN_DIM
          raise "Čelo #{idx} s profilom je príliš nízke: #{pname} zaberá #{fmt_mm(red)} mm " \
                "z výšky #{fmt_mm(h)} mm a na panel nezostane nič. Zväčši výšku čela alebo vypni profil."
        end
        return if panel_h >= MIN_PROFILE_PANEL
        warnings << BuildPlan.warning(
          'profile_panel_low',
          "Čelo #{idx}: po odčítaní profilu (#{pname}, #{fmt_mm(red)} mm) zostáva panel " \
          "#{fmt_mm(panel_h)} mm — skontroluj, či je to zámer.",
          data: { 'front_id' => (item['id'] || "F#{idx}").to_s, 'panel_height' => panel_h.round(2),
                  'profile' => item['profile'].to_s }
        )
      end

      # Cele mm bez desatin, inak 1 desatinne miesto (slovenska ciarka) — hlasky.
      def fmt_mm(v)
        f = v.to_f
        (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
      end

      # Panely jedneho cela. drawer_front / lift / fall / blind = 1 panel;
      # door = 1..4 kridla podla wings (D-24).
      # D-07: medzera medzi kridlami = cfg gap (predtym natvrdo GAP_DEFAULT).
      # D-24 IDENTITA (audit blocker): suffix recykluje SketchUp definiciu a tvori
      # part_id (cabinet_builder add_part); part_key nesie overridy a kovanie.
      # Stare tvary MUSIA ostat byte-identicke: 1 kridlo DOOR-N + wing:single,
      # 2 kridla DOOR-N-L/R + wing:left/right ("lave/prave"). NOVE 3/4 kridla maju
      # vlastny rad DOOR-N-P1..P4 + wing:p1..p4 (unikatne suffixy aj kluce).
      # D-18 'none' (Bez cela) = ZIADNE panely: riadok drzi vysku v rade presne ako
      # skutocne celo (rovnaka matematika fixed/auto/lock, z-postup pokracuje), ale
      # dielec nevznikne — otvorena nika v rade ciel. VEDOME ROZHODNUTIE: medzery
      # voci susedom ostavaju ako pri cele (ziadna specialna vetva), takze realny
      # otvor je opticky vacsi o susedne skary. Bez dielcov nevznikne ani kovanie
      # (HardwareRules iteruje dielce planu podla roly) ani polozky kusovnika/VEPO.
      #
      # D-90 PROFIL: riadkova matematika sa NEMENI (vyska riadku h, pozicia z,
      # medzery) — skracuje sa PANEL: panel_h = h - reduction, panel ostava na z
      # (cela sa kladu odspodu, hornych `reduction` mm riadku zaberie profil).
      # Kazde kridlo ma vlastny profil dlzky = sirka kridla.
      def panels_for(item, idx, gs, opening_w, z, h, gap = GAP_DEFAULT)
        return [] if item['type'] == 'none'
        front_id = item['id'].to_s
        front_id = "F#{idx}" if front_id.empty?
        prof = FrontProfiles.normalize(item['profile'])
        red = FrontProfiles.reduction(prof)
        ph = h - red # vyska PANELU (bez pasma profilu)
        band = red.positive? ? { z: (z + ph).round(2), h: red } : nil
        if item['type'] == 'drawer_front'
          [box_desc("DRW-#{idx}", PartKeys.front(front_id, 'panel'),
                    'drawer_front', "Zasuvkove celo #{idx}", gs, opening_w, z, ph,
                    profile: prof, profile_band: band)]
        elsif FLAP_TYPES.include?(item['type'])
          # KOV-A1 (audit #14 BLOCKER 5): vyklop aj sklop maju KANONICKY kluc
          # `front:F#/flap` — `front:F#/panel` by kolidoval so zasuvkovym celom
          # a override by po prepnuti typu ticho preskocil na iny dielec.
          [box_desc("FLAP-#{idx}", PartKeys.front(front_id, 'flap'),
                    'flap', "#{item['type'] == 'fall' ? 'Sklop' : 'Výklop'} #{idx}",
                    gs, opening_w, z, ph, profile: prof, profile_band: band)]
        elsif item['type'] == 'blind'
          [box_desc("BLIND-#{idx}", PartKeys.front(front_id, 'blind'),
                    'false_front', "Blenda #{idx}", gs, opening_w, z, ph,
                    profile: prof, profile_band: band)]
        else
          wings = resolve_wings(item['wings'], opening_w)
          case wings
          when 2
            dw = (opening_w - gap) / 2.0
            [
              box_desc("DOOR-#{idx}-L", PartKeys.front(front_id, 'wing', 'left'),
                       'front_door', "Dvierka #{idx} lave", gs, dw, z, ph,
                       profile: prof, profile_band: band),
              box_desc("DOOR-#{idx}-R", PartKeys.front(front_id, 'wing', 'right'),
                       'front_door', "Dvierka #{idx} prave", gs + dw + gap, dw, z, ph,
                       profile: prof, profile_band: band)
            ]
          when 3, 4
            # sirka kridla = (otvor - medzery medzi kridlami) / n; x postupuje o (dw + gap)
            dw = (opening_w - (wings - 1) * gap) / wings
            (1..wings).map do |i|
              box_desc("DOOR-#{idx}-P#{i}", PartKeys.front(front_id, 'wing', "p#{i}"),
                       'front_door', "Dvierka #{idx} kridlo #{i}/#{wings}",
                       gs + (i - 1) * (dw + gap), dw, z, ph,
                       profile: prof, profile_band: band)
            end
          else
            [box_desc("DOOR-#{idx}", PartKeys.front(front_id, 'wing', 'single'),
                      'front_door', "Dvierka #{idx}", gs, opening_w, z, ph,
                      profile: prof, profile_band: band)]
          end
        end
      end

      # Deskriptor dielca cela — box [sirka, hrubka, vyska], origin pred korpusom (Y = -hrubka).
      # h = vyska PANELU (uz po odcitani profilu). D-90 metadata:
      #   :profile       — id profilu ('none' = bez profilu)
      #   :profile_band  — { z:, h: } pasmo profilu nad panelom (vizual, PR 2)
      # ABS sa profilom NEMENI (Michal 9.8.): hrana pod profilom sa v praxi
      # olepuje normalne — profil sa nasuva na hotovu olepenu hranu.
      def box_desc(suffix, part_key, role, name, x, wdt, z, h, profile: FrontProfiles::NONE, profile_band: nil)
        ft = FRONT_THICKNESS
        desc = {
          suffix: suffix, part_key: part_key, role: role, name: name, material: :front,
          box: [wdt, ft, h], origin: [x, -ft, z],
          prod: { length: h.round(2), width: wdt.round(2), thickness: ft },
          # D-88: celo ma dlzku ZVISLE (Z), sirku v X a hrubku v Y — viz kontrakt
          # v core/part_faces.rb (mapovanie hrana -> plocha kvadra).
          axes: PartFaces::AXES_FRONT,
          profile: profile
        }
        desc[:profile_band] = profile_band if profile_band
        desc
      end

      # D-24: '3'/'4' su vyhradne RUCNA volba — auto ostava 1/2 podla AUTO_TWO_ABOVE
      # (automatika nikdy nevyrobi 3/4 kridla, stare skrinky sa nemenia).
      def resolve_wings(wings, opening_w)
        case wings.to_s
        when '1' then 1
        when '2' then 2
        when '3' then 3
        when '4' then 4
        else opening_w > AUTO_TWO_ABOVE ? 2 : 1
        end
      end

      # D-07: rozsahy medzier — medzera medzi celami 0..GAP_MAX; okraje
      # +-EDGE_LIMIT (zaporne = presah cez obrys korpusu). POZN. semantika
      # okraja hore: cela sa kladu ODSPODU (z = floor + gap_bottom); gap_top
      # posuva geometriu len cez AUTO cela (dopocitavaju zvysok) a pri
      # fixed-only zostave funguje ako rezerva/limit vo fit validacii.
      # D-22: edge_limit_off=true odomkne okraje na +-EDGE_LIMIT_UNLOCKED
      # (obklady/pilastre). Backend je AUTORITA — UI limity su len pohodlie;
      # medzera medzi celami ostava 0..GAP_MAX bez ohladu na zamok.
      def validate_gap_ranges!(cfg)
        gap = cfg['gap'].to_f
        if gap.negative? || gap > GAP_MAX
          raise "Medzera medzi celami musi byt 0 az #{GAP_MAX.to_i} mm."
        end
        limit = truthy(cfg['edge_limit_off']) ? EDGE_LIMIT_UNLOCKED : EDGE_LIMIT
        [['hore', cfg['gap_top'].to_f], ['dole', cfg['gap_bottom'].to_f],
         ['po stranach', cfg['gap_sides'].to_f]].each do |label, v|
          next if v.abs <= limit
          raise "Okraj cel #{label} musi byt v rozsahu -#{limit.to_i} az +#{limit.to_i} mm."
        end
      end

      # Backendova ochrana pred geometriou mimo korpusu. UI ma vlastne kontroly,
      # ale ulozeny/legacy config alebo externy callback ich moze obist.
      def validate_layout!(cfg, opening_w, total_v, fixed_sum, auto_count)
        gap = cfg['gap'].to_f
        gt = cfg['gap_top'].to_f
        gb = cfg['gap_bottom'].to_f
        gs = cfg['gap_sides'].to_f
        items = cfg['items'] || []

        # D-18 (Codex audit F2): sirkovy limit plati len pre riadky, ktore realne
        # generuju panely — none-only zostava zaberie iba vysku (nika), extremne
        # bocne okraje ju nesmu zhodit.
        has_panels = items.any? { |it| it['type'] != 'none' }
        raise 'Cela sa nezmestia na sirku korpusu.' if has_panels && opening_w < MIN_AUTO
        # D-07 (Codex GH P2) + D-24: viackridlove dvierka — kridlo nesmie klesnut
        # pod MIN_AUTO (velka medzera/okraje by inak dali zaporne kridlo, ktore by
        # construction ticho vyradil a korpus by sa ulozil bez dvierok).
        # Sirka kridla pre resolved n: (opening_w - (n-1)*gap) / n; n=1 pokryva
        # uz sirkovy limit vyssie (kridlo = cely otvor).
        items.each_with_index do |it, i|
          next unless it['type'] == 'door'
          n = resolve_wings(it['wings'], opening_w)
          next if n < 2
          next if (opening_w - (n - 1) * gap) / n >= MIN_AUTO
          raise "Kridla dvierok #{i + 1} sa nezmestia — zmensi medzeru medzi celami alebo bocne okraje."
        end

        items.each_with_index do |it, i|
          next unless it['mode'] == 'fixed'
          next if it['height'].to_f >= MIN_AUTO
          raise "Pevna vyska cela #{i + 1} musi byt aspon #{MIN_AUTO.to_i} mm."
        end

        required = gt + gb + ([items.size - 1, 0].max * gap) + fixed_sum + (auto_count * MIN_AUTO)
        return if required <= total_v + 0.01

        raise "Cela sa nezmestia do vysky korpusu. Potrebuju aspon #{required.round(1)} mm, dostupnych je #{total_v.round(1)} mm."
      end

      # --- normalizacia configu ------------------------------------------------
      # Prijme nil / legacy String / Hash. Vrati kanonicky string-keyed hash pre ulozenie.
      def normalize_config(raw)
        return empty_config if raw.nil?
        return legacy_string(raw) if raw.is_a?(String)

        h = raw
        {
          'split_axis' => 'height',
          'gap'        => num(h['gap'] || h[:gap], GAP_DEFAULT),
          'gap_top'    => num(h['gap_top'] || h[:gap_top], GAP_EDGE),
          'gap_bottom' => num(h['gap_bottom'] || h[:gap_bottom], GAP_EDGE),
          'gap_sides'  => num(h['gap_sides'] || h[:gap_sides], GAP_EDGE),
          # D-22: stav zamku okrajov je sucast kanonickeho configu (round-trip cez
          # ulozeny korpus AJ sablony); default false = zamknute +-EDGE_LIMIT.
          'edge_limit_off' => truthy(h['edge_limit_off'] || h[:edge_limit_off]),
          'items'      => normalize_items(h['items'] || h[:items] || [])
        }
      end

      # Jednorazova kompatibilita pre V0.1/V0.2 korpusy. Stare konfiguracie
      # mohli obsahovat fyzicky nepouzitelne pevne celo mensie ako MIN_AUTO.
      # V0.3 konfiguracie tymto neprechadzaju a neplatna nova hodnota sa odmietne.
      def migrate_legacy_config(raw)
        cfg = normalize_config(raw)
        cfg['items'].each do |item|
          next unless item['mode'] == 'fixed' && item['height'].to_f < MIN_AUTO
          item.merge!('mode' => 'auto', 'height' => nil, 'locked' => false)
        end
        cfg
      end

      def normalize_items(items)
        used_ids = {}
        next_id = 1
        Array(items).each_with_index.map do |it, _i|
          requested_id = (it['id'] || it[:id]).to_s.strip
          front_id = requested_id.empty? ? nil : PartKeys.segment(requested_id)
          if front_id.nil? || used_ids[front_id]
            next_id += 1 while used_ids["F#{next_id}"]
            front_id = "F#{next_id}"
            next_id += 1
          end
          used_ids[front_id] = true

          type = (it['type'] || it[:type]).to_s
          type = 'door' unless TYPES.include?(type) # D-18: + none; KOV-A1: + lift/fall/blind
          hraw = it['height'] || it[:height]
          has_h = !(hraw.nil? || hraw.to_s.strip.empty?)
          mode = (it['mode'] || it[:mode]).to_s
          mode = has_h ? 'fixed' : 'auto' unless %w[fixed auto].include?(mode)
          mode = 'auto' if mode == 'fixed' && !has_h # fixed bez vysky nema zmysel -> auto
          wings = (it['wings'] || it[:wings] || 'auto').to_s
          wings = 'auto' unless %w[1 2 3 4 auto].include?(wings) # D-24: + 3/4 (rucna volba)
          # D-90: uchytkovy profil. Kluc smie chybat (starsi config = 'none',
          # ziadna migracia); neznamu hodnotu (aj z novsej verzie) normalize
          # sklopi na 'none'. Riadok "Bez cela" profil nema — nie je na com.
          profile = FrontProfiles.normalize(it['profile'] || it[:profile])
          # KOV-A1 (vedomy limit): profil ma zmysel len na dvierkach a zasuvke —
          # D-90 profilove pravidlo ine roly nepozna a `profile_rule_missing` by
          # hlasil chybu, ktora nie je chybou pouzivatela.
          profile = FrontProfiles::NONE if PROFILELESS_TYPES.include?(type)
          out = {
            'id' => front_id,
            'type' => type,
            'mode' => mode,
            'height' => has_h ? hraw.to_f : nil,
            'locked' => truthy(it['locked'] || it[:locked]) && mode == 'fixed',
            'wings' => (type == 'door' ? wings : 1),
            'profile' => profile
          }
          # KOV-A1 DORMANT polia: kluc sa do vystupu dostane LEN ked ho vstup
          # naozaj nesie v platnom tvare — chybajuci kluc sa NIKDY nedoplna
          # (inak by legacy zakazka dostala RED smerovy nalez, ktory si nikto
          # nevypytal). Drzia sa BEZ OHLADU na typ riadku: prepnutie dvierok na
          # zasuvku a spat nesmie ulozeny smer zahodit.
          dir = norm_direction(it['direction'] || it[:direction])
          out['direction'] = dir if dir
          wdir = norm_wing_directions(it['wing_directions'] || it[:wing_directions])
          out['wing_directions'] = wdir if wdir
          om = norm_enum(it['opening_mode'] || it[:opening_mode], OPENING_MODES)
          out['opening_mode'] = om if om
          drw = norm_drawer(it['drawer'] || it[:drawer])
          out['drawer'] = drw if drw
          out
        end
      end

      # --- KOV-A1: normalizacia smerovych a klasifikacnych poli ---------------

      # Smer otvarania (strana pantov) ako TROJSTAV. Vracia nil = „kluc sa do
      # configu vobec nedostane" (legacy), inak 'left'/'right'/'unset'.
      #   nil / prazdny retazec  -> nil  (legacy; TOTO je jedina cesta, ako sa
      #                                   pole moze stratit — a je vedoma)
      #   'left' / 'right'       -> hodnota
      #   iny NEPRAZDNY STRING   -> 'unset' (FAIL-VISIBLE: poskodena hodnota,
      #                             hodnota z novsej verzie ci preklep sa PRIZNA
      #                             ako neurcene, nikdy sa NEHADA strana)
      #   iny TYP (cislo, true, pole) -> nil — nie je to smer a nikdy nim nebol;
      #                             materializovat z neho `unset` by vyrobilo
      #                             RED nalez z poskodeneho suboru bez informacie.
      def norm_direction(raw)
        return nil unless raw.is_a?(String)
        v = raw.strip
        return nil if v.empty?
        DIRECTIONS.include?(v) ? v : 'unset'
      end

      # Smery STREDNYCH kridiel 3/4-kridlovych dvierok. Povolene kluce su LEN
      # p2/p3; prazdny vysledok = kluc sa do configu nedostane.
      def norm_wing_directions(raw)
        return nil unless raw.is_a?(Hash)
        out = {}
        WING_DIRECTION_KEYS.each do |k|
          v = norm_direction(raw[k] || raw[k.to_sym])
          out[k] = v if v
        end
        out.empty? ? nil : out
      end

      # Klasifikacia zasuvky. Pod-polia su NEZAVISLE (samotna konstrukcia bez
      # variantu je platny stav); hash bez jedineho platneho pod-pola -> nil.
      def norm_drawer(raw)
        return nil unless raw.is_a?(Hash)
        out = {}
        c = norm_enum(raw['construction'] || raw[:construction], DRAWER_CONSTRUCTIONS)
        out['construction'] = c if c
        v = norm_enum(raw['variant'] || raw[:variant], DRAWER_VARIANTS)
        out['variant'] = v if v
        # KOV-C2b: system + mapa pripnutych receptov. Obe polia su SERVEROVE
        # (panel ich neposiela; `strip_server_drawer_fields` ich z klientskeho
        # payloadu zahadzuje), ale normalizacia ich musi BEZSTRATOVO preniest —
        # inak by ich prestavba, sablona aj Copy/Paste ticho zmazali.
        s = norm_enum(raw['system'] || raw[:system], DRAWER_SYSTEMS)
        out['system'] = s if s
        refs = norm_recipe_refs(raw['recipe_refs'] || raw[:recipe_refs])
        out['recipe_refs'] = refs if refs
        out.empty? ? nil : out
      end

      # Mapa `"<system>|<otvaranie>" => recipe_id`. Neplatny kluc alebo hodnota
      # mimo tvaru = zaznam prec (nikdy sa NEHADA); prazdna mapa = kluc prec.
      def norm_recipe_refs(raw)
        return nil unless raw.is_a?(Hash)
        out = {}
        raw.each do |k, v|
          key = k.to_s.strip
          next unless RECIPE_REF_KEY_RE.match?(key)
          id = v.to_s.strip
          next unless RECIPE_ID_RE.match?(id)
          out[key] = id
        end
        out.empty? ? nil : out
      end

      # --- KOV-C2b: SERVEROVE polia klasifikacie zasuvky ----------------------
      #
      # `drawer.system` a `drawer.recipe_refs` su AUTORITA SERVERA. Klientsky
      # payload panela nahradza `params['fronts']` VCELKU (Codex #301 kolo 3 P1),
      # takze stale alebo podvrhnute cela by ulozenu mapu prepisali alebo
      # vymazali — a s nou by sa ticho zmenila pripnuta verzia receptu, teda
      # GEOMETRIA uz postavenej zakazky.
      #
      # Preto DVE cesty (Astra #19 B2), nie jedna normalizacia:
      #   (i)  klientsky payload -> `reattach_server_drawer_fields` (tu):
      #        polia sa z prichadzajucich ciel ZAHODIA a ULOZENE sa pripoja
      #        spat PODLA ID CELA. Celo s NOVYM ID mapu nema (a ma ju dostat az
      #        od servera pri prestavbe);
      #   (ii) ulozeny config -> `normalize_config` ich zachova BEZSTRATOVO.
      #
      # CISTA funkcia: vracia NOVY normalizovany config, vstupy nemutuje.
      SERVER_DRAWER_KEYS = %w[system recipe_refs].freeze

      def reattach_server_drawer_fields(incoming, saved)
        cfg = normalize_config(incoming)
        stored = server_drawer_fields(saved)
        cfg['items'].each do |it|
          drawer = it['drawer'].is_a?(Hash) ? it['drawer'] : {}
          drawer = drawer.reject { |k, _| SERVER_DRAWER_KEYS.include?(k) }
          keep = stored[it['id'].to_s]
          drawer = drawer.merge(keep) if keep
          if drawer.empty?
            it.delete('drawer')
          else
            it['drawer'] = drawer
          end
        end
        cfg
      end

      # { front_id => { 'system' =>…, 'recipe_refs' =>… } } z ULOZENEHO configu.
      def server_drawer_fields(saved)
        out = {}
        Array(normalize_config(saved)['items']).each do |it|
          d = it['drawer']
          next unless d.is_a?(Hash)
          keep = d.select { |k, _| SERVER_DRAWER_KEYS.include?(k) }
          out[it['id'].to_s] = keep unless keep.empty?
        end
        out
      end

      # Zapise SERVEROVE polia klasifikacie do NORMALIZOVANEHO configu ciel
      # (in-place). Jediny zapisovy kanal — builder ho vola v TEJ ISTEJ
      # operacii ako geometriu, takze Undo vrati oboje naraz.
      #   writes = [{ 'front_id' =>…, 'system' =>…, 'ref_key' =>…, 'recipe_id' =>… }]
      # Vrati true, ak sa config naozaj zmenil.
      def write_drawer_fields!(fronts_cfg, writes)
        return false unless fronts_cfg.is_a?(Hash) && fronts_cfg['items'].is_a?(Array)

        changed = false
        Array(writes).each do |w|
          next unless w.is_a?(Hash)
          it = fronts_cfg['items'].find { |i| i.is_a?(Hash) && i['id'].to_s == w['front_id'].to_s }
          next if it.nil?

          drawer = it['drawer'].is_a?(Hash) ? it['drawer'] : {}
          # Zapis je vyhradne DOPLNENIE CHYBAJUCEHO. Uz ulozeny system ani uz
          # pripnuty recept sa TU NIKDY neprepisuju — zmena verzie je vyhradne
          # explicitna akcia KOV-D (Codex #301 kolo 1 + 2 P1), a nesediaci
          # system je RED `drawer_unclassified`, nie tiche prepnutie.
          sys = norm_enum(w['system'], DRAWER_SYSTEMS)
          if sys && drawer['system'].nil?
            drawer['system'] = sys
            changed = true
          end
          key = w['ref_key'].to_s
          rid = w['recipe_id'].to_s
          if RECIPE_REF_KEY_RE.match?(key) && RECIPE_ID_RE.match?(rid)
            refs = drawer['recipe_refs'].is_a?(Hash) ? drawer['recipe_refs'] : {}
            if refs[key].nil?
              refs[key] = rid
              drawer['recipe_refs'] = refs
              changed = true
            end
          end
          it['drawer'] = drawer unless drawer.empty?
        end
        changed
      end

      # Uzavrety zoznam hodnot: mimo zoznamu (aj prazdne/iny typ) -> nil = kluc
      # sa do configu nedostane. ZIADNY default sa nedoplna.
      def norm_enum(raw, allowed)
        return nil unless raw.is_a?(String)
        v = raw.strip
        allowed.include?(v) ? v : nil
      end

      # Legacy V0.1/V0.2a: door_mode none/1/2/auto -> 1 door celo auto vyska (alebo ziadne).
      def legacy_string(s)
        v = s.to_s
        return empty_config if v.strip.empty? || %w[none 0].include?(v)
        wings = %w[1 2].include?(v) ? v : 'auto'
        empty_config.merge('items' => [
          { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => nil, 'locked' => false,
            'wings' => wings, 'profile' => FrontProfiles::NONE }
        ])
      end

      def empty_config
        { 'split_axis' => 'height', 'gap' => GAP_DEFAULT, 'gap_top' => GAP_EDGE,
          'gap_bottom' => GAP_EDGE, 'gap_sides' => GAP_EDGE,
          'edge_limit_off' => false, 'items' => [] }
      end

      def num(v, dflt)
        v.nil? || v.to_s.strip.empty? ? dflt : v.to_f
      end

      def truthy(v)
        %w[true 1 yes].include?(v.to_s.downcase)
      end
    end
  end
end
