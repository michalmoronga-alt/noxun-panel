# frozen_string_literal: true
# Noxun Engine — NEMENNE RECEPTY ZASUVIEK (KOV-C, rez C1).
#
# CISTO Ruby: ziadne SketchUp API, ziadny zapis do modelu, ziadny zapis na disk.
# Modul cita VYHRADNE datove packy z `noxun_engine/data/recipes/` a pocita z nich
# geometriu zasuvky. Stavbu (`Construction.build_plan`), config ani vystupy v C1
# NEOVPLYVNUJE — zapojenie je uloha rezu C2.
#
# ========================== ZASADY (Michal 5.9.2026) ==========================
# 1) Explicitne NEMENNE recepty pre konkretne systemy (Atira, Quadro V6, neskor
#    dalsie). Ziadny univerzalny resolver pre hypoteticke systemy.
# 2) Fyzika je v recepte, objednavacie kody su v setoch (KOV-B). Dve vrstvy,
#    kazda s jednou zodpovednostou.
# 3) Nakup NIKDY nemeni fyzicky navrh: rad NL v recepte = rad, ktory Noxun
#    realne kupuje. Ziadne kandidatske NL, ziadny fallback.
# 4) EB je PEVNE per recept (Atira 10.5, Quadro 23). Zmena hrubky boku meni len
#    svetlu sirku, z ktorej sa dielce pocitaju — engine nikdy nehlada iny runner
#    (KD -> EB mapa NEEXISTUJE).
# 5) System je EXPLICITNA hodnota `drawer.system` popri `construction`.
# 6) Malo stavov, kazde pravidlo auditovatelne z JEDNEHO JSON suboru.
#
# ============================== NEMENNOST =====================================
# `data/recipes/RELEASED.json` = register `{ recipe_id => sha256 }`. `load` cita
# VYHRADNE registrovane recepty a odtlacok suboru MUSI sediet — nezhoda = chyba,
# NIKDY tichy default. Oprava alebo rozsirenie = NOVY subor `_v2`; vydane verzie
# sa nikdy nemazu ani nemenia (reprodukovatelnost starych zakaziek bez snapshotu).
#
# Odtlacok sa pocita nad obsahom suboru s NORMALIZOVANYMI koncami riadkov
# (CRLF -> LF) a bez BOM. Repo bezi s `core.autocrlf=true`, takze Windows
# checkout ma CRLF a Linux CI LF — surovy bajtovy hash by v CI padal.
#
# ============================ NAZOV RECEPTU ===================================
# `recipe_id` == "<system>_<opening>_v<version>" (validuje sa pri nacitani).
# Verzia sa parsuje z KONCA (`quadro_v6_sisy_v1` -> system `quadro_v6`).
#
# ============================== TVARY DAT =====================================
# Recept po `load`: top-level kluce a `constants` su SYMBOLY; datove mapy
# (`height_variants`, `nl_series_by_height`, `min_depth_by_nl`, `load_by_cell`
# `by_nl`/`by_height_nl`, `thickness_supported`, `abs`, `source`) ostavaju
# STRING-keyed — kluce su cisla vysok/NL alebo mena roli dielcov.
#
# `resolve` vracia symbolove kluce; `hardware_params` su string-keyed (tvar
# `params` polozky kovania v BuildPlan — C2 z nich sklada polozku vysuvu).
require 'json'
require 'digest'

module Noxun
  module Engine
    module Recipes
      # Chyba dat receptu (chybajuci subor, zly odtlacok, neplatna schema).
      # Vzdy hlasna — tichy default je zakazany zasadou 3.
      class RecipeError < StandardError; end

      DIR           = File.expand_path(File.join(__dir__, '..', 'data', 'recipes'))
      RELEASED_FILE = 'RELEASED.json'

      # NEMENNOST PLATI OD AKTIVACIE (jedina vedoma vynimka, KOV-C2a 5.9.2026).
      # Recepty v1 vydal C1, ale ZIADEN projekt na nich este nestoji — resolver
      # sa z `build_plan` nevola (to zapina az C2b), takze v modeli neexistuje
      # geometria, ktoru by oprava zmenila. Datova chyba v rade `atira_sisy_v1`
      # (H144 mala NL 620, lenze kit 357755 je PTO = Tip-On; pre SiSy H144/620
      # kit NEEXISTUJE — sonda #12) sa preto opravila NA MIESTE aj s prepocitanym
      # odtlackom v registri. Od chvile, ked recept postavi prvy dielec, plati
      # nemennost bez vynimky: oprava = NOVY subor `_v2`, stary sa NIKDY nemeni.

      SYSTEMS  = %w[atira quadro_v6].freeze
      OPENINGS = %w[sisy p2o].freeze
      FAMILIES = %w[metal_box wood_undermount].freeze

      # Mapovanie klasifikacie cela (KOV-A) na osi receptu.
      CONSTRUCTION_TO_SYSTEM = { 'metal' => 'atira', 'wood' => 'quadro_v6' }.freeze
      OPENING_MODE_TO_OPENING = { 'classic' => 'sisy', 'tipon' => 'p2o' }.freeze

      # Register kodov konfliktov (package KOV-C, brana `DRAWER_BLOCKERS`).
      # C1 ich len PRODUKUJE; zapojenie do `export_blockers` je uloha C2.
      CONFLICT_CODES = %w[
        drawer_unclassified drawer_no_fit drawer_obstruction
        drawer_internal_unsupported drawer_thickness_unsupported
        drawer_kd_unsupported drawer_recipe_unknown nl_lock_invalid
        drawer_override_invalid drawer_kit_missing
      ].freeze

      # Jediny kod, ktory vznika az v NAKUPE (receptova polozka bez setu alebo
      # bez kodu pre svoju NL). Dielce v modeli OSTAVAJU (fyzika je spravna),
      # ale rez na NL bez kitu tej NL je nepouzitelny — preto blokuje AJ VEPO.
      KIT_MISSING = 'drawer_kit_missing'

      # MIGRACNY kod (Codex #304 kolo 1 P1). NEVYRABA ho resolver — vznika pri
      # CITANI modelu (`Bom.collect`): skrinka ulozena PRED aktivaciou receptov
      # (config schema < 5) ma klasifikovanu zasuvku, takze v .skp NIE SU
      # receptove dielce a vysuv je legacy. Kusovnik aj VEPO by boli NEUPLNE
      # a ticho — preto blokuje VSETKY exporty. Napravou je PRESTAVBA skrinky.
      STALE = 'drawer_stale'

      # KOV-C2b: REGISTER BRANY (11 kodov). `export_blockers` cita CELY tento
      # zoznam — ziadny kod z neho nesmie prejst do vydaneho suboru.
      # 10 kodov produkuje resolver (`CONFLICT_CODES`), 11. je MIGRACNY.
      DRAWER_BLOCKERS = (CONFLICT_CODES + [STALE]).freeze

      # Konflikty STAVBY (9): fail-closed, ziadne dielce ani polozka. Blokuju
      # nakupny CSV, rozpocet a cenovu ponuku; VEPO chrani prave to, ze sa
      # geometria vobec nevydala (niet co rezat).
      BUILD_BLOCKERS = (CONFLICT_CODES - [KIT_MISSING]).freeze

      # Kody, pri ktorych by boli NEUPLNE aj REZACIE data — blokuju AJ VEPO.
      ALL_EXPORT_BLOCKERS = [KIT_MISSING, STALE].freeze

      # Kratky slovensky nazov dovodu pre BRANU EXPORTU. Plnu vetu (ktora
      # hodnota kde nesedi) nesie nalez Kontroly; brana menuje LEN pricinu
      # a skrinky. KAZDY kod registra tu MUSI mat zaznam — strazi to guard test.
      BLOCKER_LABELS = {
        'drawer_unclassified'         => 'zásuvka nie je klasifikovaná',
        'drawer_no_fit'               => 'zásuvka sa do skrinky nezmestí',
        'drawer_obstruction'          => 'v riadku zásuvky je polica alebo priečka',
        'drawer_internal_unsupported' => 'vnútorná zásuvka sa zatiaľ nevyrába',
        'drawer_thickness_unsupported' => 'materiál zásuvky má nepodporovanú hrúbku',
        'drawer_kd_unsupported'       => 'hrúbka boku skrinky nie je pre systém podporovaná',
        'drawer_recipe_unknown'       => 'zásuvka používa recept, ktorý plugin nepozná',
        'nl_lock_invalid'             => 'ručne zamknutá dĺžka výsuvu neplatí',
        'drawer_override_invalid'     => 'ručný zásah do výsuvu zásuvky je neplatný',
        KIT_MISSING                   => 'nákup nenašiel kit výsuvu k postaveným dielcom',
        STALE                         => 'zásuvka je klasifikovaná ešte spred aktivovania receptov'
      }.freeze

      # Identita NL zamku v `hardware_overrides` (D-93). Zamok = existencia
      # platneho pola `nominal_length`; `rule_id` smie byt legacy pravidlo aj
      # receptova identita `recipe:<recipe_id>` (migraciu robi C2).
      LOCK_GENERIC_TYPE   = 'slide'
      LOCK_LEGACY_RULE_ID = 'vysuvy-nl-podla-hlbky'

      # Roly dielcov, ktore recepty emituju. `box_side` / `drawer_inner_front`
      # do `BuildPlan::ROLES` pridava az C2 (C1 plan nemeni).
      ROLE_BOTTOM      = 'drawer_bottom'
      ROLE_BACK        = 'drawer_back'
      ROLE_BOX_SIDE    = 'box_side'
      ROLE_INNER_FRONT = 'drawer_inner_front'
      # Vsetky roly, ktore recepty emituju — zhodne s `BuildPlan::ROLES` novou
      # stvoricou aj s `CabinetBuilder::DRAWER_ROLES` (guard test to porovnava).
      PART_ROLES = [ROLE_BOTTOM, ROLE_BACK, ROLE_BOX_SIDE, ROLE_INNER_FRONT].freeze

      # Najmensi vyrobitelny rozmer — zdiela sa s planom (jediny prah v systeme).
      MIN_DIM = 0.01

      module_function

      # --- register a nacitanie ------------------------------------------------

      # Register vydanych receptov: { recipe_id => sha256 hex }.
      def released(dir: DIR)
        path = File.join(dir, RELEASED_FILE)
        raise RecipeError, "Register receptov #{RELEASED_FILE} chyba (#{dir})." unless File.file?(path)

        data = parse_json(path)
        raise RecipeError, "Register #{RELEASED_FILE} musi byt objekt." unless data.is_a?(Hash)

        data.each do |id, sha|
          raise RecipeError, "Register: kluc #{id.inspect} nie je platne recipe_id." unless parse_id(id)
          raise RecipeError, "Register: odtlacok pre #{id} nie je sha256 hex." unless sha.is_a?(String) && sha =~ /\A[0-9a-f]{64}\z/
        end
        data
      end

      # Nacita VYDANY recept. Odmietne neregistrovany id, chybajuci subor,
      # nesediaci odtlacok aj neplatnu schemu (vzdy vynimka, nikdy default).
      def load(recipe_id, dir: DIR)
        id = recipe_id.to_s
        reg = released(dir: dir)
        raise RecipeError, "Recept #{id} nie je v registri vydanych receptov." unless reg.key?(id)

        path = File.join(dir, "#{id}.json")
        raise RecipeError, "Subor receptu #{id}.json chyba (#{dir})." unless File.file?(path)

        actual = file_digest(path)
        unless actual == reg[id]
          raise RecipeError,
                "Recept #{id}: odtlacok suboru nesedi s registrom (#{actual[0, 12]} vs #{reg[id][0, 12]}) — " \
                'vydany recept sa nikdy nemeni, oprava = novy subor _v2.'
        end
        validate!(parse_json(path), id)
      end

      # Inventar VSETKYCH suborov v priecinku receptov okrem registra — pouziva
      # ho test nemennosti: mnozina suborov MUSI sediet s mnozinou klucov registra.
      # ZAMERNE sa NEFILTRUJE cez `parse_id` (Codex #302 kolo 1 P2): subor s menom,
      # ktore parser nepozna (`antaro_sisy_v1.json`), je prave ten pripad, ktory ma
      # test odhalit — odfiltrovanie by ho ticho prepasovalo.
      def inventory(dir: DIR)
        Dir.glob(File.join(dir, '*.json')).map { |p| File.basename(p, '.json') }
           .reject { |b| b == File.basename(RELEASED_FILE, '.json') }
           .sort
      end

      # Najnovsia vydana verzia pre kombinaciu system|otvaranie, alebo nil.
      def latest_for(system, opening, dir: DIR)
        best = nil
        released(dir: dir).each_key do |id|
          p = parse_id(id)
          next unless p && p[:system] == system.to_s && p[:opening] == opening.to_s
          best = p if best.nil? || p[:version] > best[:version]
        end
        best && best[:id]
      end

      # Surodenec ROVNAKEJ verzie pre inu kombinaciu system|otvaranie (alebo nil).
      # Prepnutie klasifikacie tak nikdy ticho nepovysi pripnuty recept.
      def sibling(recipe_id, system, opening, dir: DIR)
        p = parse_id(recipe_id)
        return nil unless p

        want = "#{system}_#{opening}_v#{p[:version]}"
        released(dir: dir).key?(want) ? want : nil
      end

      # Stav AKTIVNEHO zaznamu mapy `drawer.recipe_refs` (system|opening -> id):
      #   [:missing, nil]   — zaznam chyba (C2 doplni `latest_for`/`sibling`)
      #   [:known, id]      — zaznam existuje a je vydany -> pouzi presne ten
      #   [:unknown, id]    — zaznam existuje, ale plugin ho nepozna -> RED
      def active_ref(refs_map, system, opening, dir: DIR)
        return [:missing, nil] unless refs_map.is_a?(Hash)

        key = "#{system}|#{opening}"
        id = refs_map[key] || refs_map[key.to_sym]
        return [:missing, nil] unless id.is_a?(String) && !id.strip.empty?

        released(dir: dir).key?(id) ? [:known, id] : [:unknown, id]
      end

      # --- klasifikacia cela ---------------------------------------------------

      # Rozhodovacia tabulka „ktory recept pre toto celo" (package KOV-C C1).
      # Vstup = RESOLVED polozka cela (`front_items`), string kluce.
      #   [:legacy, nil]                 — resolver sa NEVOLA (CONTENT-identicka
      #                                    legacy cesta): iny typ nez zasuvka,
      #                                    zasuvka bez JEDINEHO drawer pola,
      #                                    alebo `construction other`
      #   [:ok, {system:, opening:}]     — construction AJ opening_mode su tu
      #   [:conflict, kod, hlaska]       — ciastocna klasifikacia / nesulad
      #                                    system-konstrukcia / vnutorna zasuvka
      #                                    (kod je VZDY z CONFLICT_CODES; hlaska
      #                                    je slovenska veta pre Kontrolu v C2)
      def recipe_key_for(front_item)
        return [:legacy, nil] unless front_item.is_a?(Hash)
        return [:legacy, nil] unless front_item['type'].to_s == 'drawer_front'

        drawer = front_item['drawer'].is_a?(Hash) ? front_item['drawer'] : {}
        construction = str_or_nil(drawer['construction'])
        variant      = str_or_nil(drawer['variant'])
        explicit_sys = str_or_nil(drawer['system'])
        opening_mode = str_or_nil(front_item['opening_mode'])

        # Legacy: ziadne z klasifikacnych poli neexistuje -> nedotknute stare celo.
        # `variant` sa RATA MEDZI NE (Codex #302 kolo 1 P2): celo, ktore nesie LEN
        # `variant internal`, je klasifikovane — nesmie prepadnut do legacy cesty
        # skor, nez sa vnutorna zasuvka prizna.
        return [:legacy, nil] if construction.nil? && opening_mode.nil? && explicit_sys.nil? && variant.nil?
        # `other` = konstrukcia mimo receptov -> legacy cesta (nie chyba).
        return [:legacy, nil] if construction == 'other'
        # Vnutorna zasuvka: V1 ju vie len klasifikovat.
        if variant == 'internal'
          return [:conflict, 'drawer_internal_unsupported',
                  'Vnútorná zásuvka: V1 ju vie iba klasifikovať — dielce ani výsuv sa nevyrábajú.']
        end

        if construction && opening_mode
          expected = CONSTRUCTION_TO_SYSTEM[construction]
          opening = OPENING_MODE_TO_OPENING[opening_mode]
          if expected.nil? || opening.nil?
            return [:conflict, 'drawer_unclassified',
                    'Zásuvka nie je klasifikovaná: konštrukcia alebo spôsob otvárania má neznámu hodnotu.']
          end
          # Explicitny `system` je hodnota z configu (stale/podvrhnuty payload).
          # NIKDY neprepise mapu konstrukcie (Codex #302 kolo 1 P2): kov je Atira,
          # drevo Quadro — nesulad je RED, nie tiche prepnutie systemu.
          if explicit_sys && explicit_sys != expected
            return [:conflict, 'drawer_unclassified',
                    "Zásuvka nie je klasifikovaná: systém „#{explicit_sys}\" nezodpovedá konštrukcii " \
                    "„#{construction}\" (očakávaný #{expected})."]
          end

          return [:ok, { system: expected, opening: opening }]
        end

        # Polia sa edituju NEZAVISLE — ciastocna klasifikacia je RED, nikdy
        # sa nedopĺňa druha polovica (Codex #301 kolo 3 P1).
        [:conflict, 'drawer_unclassified',
         'Zásuvka je klasifikovaná len spolovice — chýba konštrukcia alebo spôsob otvárania.']
      end

      # Je celo KLASIFIKOVANE ako zasuvka (= resolver sa nan vztahuje)?
      # JEDINY predikat — cita ho `recipe_key_for` aj migracna brana
      # `Bom.drawer_stale_issue` (Codex #304 kolo 3 P1). Druhy, uzsi predikat
      # (napr. „construction je metal|wood") by prepasoval CIASTOCNU
      # klasifikaciu, ktora po prestavbe skonci `drawer_unclassified`, a
      # `variant internal`, ktora skonci `drawer_internal_unsupported`.
      def classified?(front_item)
        recipe_key_for(front_item).first != :legacy
      end

      # --- resolve -------------------------------------------------------------

      # Jedna vyska + jedna NL + dielce + parametre polozky vysuvu.
      #   recipe           — vysledok `load`
      #   ctx              — vysledok `Construction.context_for`
      #   part_thicknesses — { rola => mm } VSTUP (C2 ho berie z materialoveho
      #                      kanala :drawer PRED stavbou planu), nie odvodeny
      #   overrides        — pole zaznamov `hardware_overrides` (NL zamok)
      # Vracia:
      #   { height_variant, box_height, nl, load, parts, hardware_params,
      #     conflicts, explain }
      # ATOMICITA: akykolvek konflikt -> parts = [] a hardware_params = {}.
      def resolve(recipe, ctx, part_thicknesses, overrides = [])
        out = { height_variant: nil, box_height: nil, nl: nil, load: nil,
                parts: [], hardware_params: {}, conflicts: [], explain: [] }
        th = normalize_thicknesses(part_thicknesses)

        # (1) hrubka boku korpusu (KD)
        kd = ctx[:side_thickness].to_f
        unless recipe[:kd_supported].any? { |v| same?(v, kd) }
          return fail_with(out, 'drawer_kd_unsupported',
                           "#{label(recipe)}: hrúbka boku #{fmt(kd)} mm nie je podporovaná " \
                           "(#{recipe[:kd_supported].map { |v| fmt(v) }.join(' · ')} mm).")
        end

        # (2) hrubky vyrabanych dielcov
        bad = recipe[:thickness_supported].reject do |role, allowed|
          t = th[role]
          t && allowed.any? { |v| same?(v, t) }
        end
        unless bad.empty?
          detail = bad.map { |role, allowed| "#{role_label(role)} #{th[role] ? "#{fmt(th[role])} mm" : 'neurčená'} (povolené #{allowed.map { |v| fmt(v) }.join(', ')})" }
          return fail_with(out, 'drawer_thickness_unsupported',
                           "#{label(recipe)}: nepodporovaná hrúbka dielca — #{detail.join(' · ')}.")
        end

        # (3) prekazky v riadku (police, priecky)
        obstructions = Array(ctx[:obstructions])
        unless obstructions.empty?
          names = obstructions.map { |o| role_label(o[:role].to_s) }.uniq.join(', ')
          return fail_with(out, 'drawer_obstruction',
                           "#{label(recipe)}: riadok zásuvky pretína #{names} — zásuvka sa nedá postaviť.")
        end

        clear_h = ctx[:clear_height].to_f
        clear_w = ctx[:clear_width].to_f
        clear_d = ctx[:clear_depth].to_f

        # (4) JEDNA vyska
        if atira?(recipe)
          variant = pick_height_variant(recipe, clear_h)
          if variant.nil?
            lowest = recipe[:height_variants].values.map { |v| v[:min_clear_height] }.min
            return fail_with(out, 'drawer_no_fit',
                             "#{label(recipe)}: svetlá výška #{fmt(clear_h)} mm nestačí ani na najnižší variant " \
                             "(potrebných #{fmt(lowest)} mm).")
          end
          out[:height_variant] = variant[:height]
          out[:explain] << "Výška: H#{variant[:height]} (svetlá #{fmt(clear_h)} ≥ #{fmt(variant[:min_clear_height])})"
        else
          c = recipe[:constants]
          box_h = clear_h - c[:box_clearance].to_f
          front_back = box_h - th[ROLE_BOTTOM].to_f - c[:bottom_offset].to_f
          if front_back < c[:min_front_back_height].to_f
            return fail_with(out, 'drawer_no_fit',
                             "#{label(recipe)}: svetlá výška #{fmt(clear_h)} mm dáva box #{fmt(box_h)} mm a čelo/chrbát " \
                             "#{fmt(front_back)} mm (minimum #{fmt(c[:min_front_back_height])} mm).")
          end
          out[:box_height] = box_h
          out[:explain] << "Výška boxu: #{fmt(box_h)} (svetlá #{fmt(clear_h)} − vôľa #{fmt(c[:box_clearance])})"
        end

        # (5) JEDNA NL — najdlhsia z radu TEJ vysky, ktora sa zmesti do hlbky.
        #     Porovnanie je INKLUZIVNE nad NEZAOKRUHLENOU hodnotou, bez EPS.
        series = series_for(recipe, out[:height_variant])
        nl = series.select { |v| min_depth(recipe, v) <= clear_d }.max
        if nl.nil?
          shortest = series.min
          return fail_with(out, 'drawer_no_fit',
                           "#{label(recipe)}: hĺbka #{fmt(clear_d)} mm, najkratšia NL #{fmt(shortest)} potrebuje " \
                           "#{fmt(min_depth(recipe, shortest))} mm.")
        end

        # (6) NL zamok z hardware_overrides — nikdy tichá zmena.
        lock = lock_value(recipe, ctx, overrides)
        if lock
          in_series = series.any? { |v| same?(v, lock) }
          fits = in_series && min_depth(recipe, lock) <= clear_d
          unless fits
            reason = in_series ? "potrebuje hĺbku #{fmt(min_depth(recipe, lock))} mm (svetlá #{fmt(clear_d)} mm)" : 'nie je v rade tejto výšky'
            return fail_with(out, 'nl_lock_invalid',
                             "#{label(recipe)}: ručne zamknutá dĺžka #{fmt(lock)} mm #{reason} — " \
                             'zámok sa nikdy nemení automaticky.')
          end
          nl = lock
          out[:explain] << "NL: #{fmt(nl)} (ručný zámok)"
        else
          rad = out[:height_variant] ? "rad H#{out[:height_variant]} " : 'rad '
          longer = series.select { |v| v > nl }.min
          tail = longer ? "; #{fmt(longer)} potrebuje #{fmt(min_depth(recipe, longer))}" : ''
          out[:explain] << "NL: #{fmt(nl)} (#{rad}#{fmt(series.min)}–#{fmt(series.max)}, " \
                           "hĺbka #{fmt(clear_d)} ≥ #{fmt(min_depth(recipe, nl))}#{tail})"
        end
        out[:nl] = nl

        # (7) nosnost bunky (informacia pre nakup, geometriu nemeni)
        out[:load] = load_for(recipe, out[:height_variant], nl)

        # (8) dielce
        parts = if atira?(recipe)
                  atira_parts(recipe, clear_w, nl, th, out[:height_variant])
                else
                  quadro_parts(recipe, clear_w, nl, out[:box_height], th)
                end

        # (9) kazdy rozmer kazdeho dielca >= MIN_DIM (jediny neplatny = no_fit)
        invalid = parts.find { |p| [p[:width], p[:height], p[:thickness]].any? { |v| v.to_f <= MIN_DIM } }
        if invalid
          return fail_with(out, 'drawer_no_fit',
                           "#{label(recipe)}: dielec #{role_label(invalid[:role])} by mal nekladný rozmer " \
                           "(#{fmt(invalid[:width])} × #{fmt(invalid[:height])} mm) — zásuvka sa nedá vyrobiť.")
        end

        out[:parts] = parts
        out[:hardware_params] = {
          'recipe_id' => recipe[:recipe_id], 'system' => recipe[:system],
          'height_variant' => out[:height_variant], 'box_height' => out[:box_height],
          'nominal_length' => nl, 'load' => out[:load], 'opening' => recipe[:opening]
        }
        out[:explain] << "Nosnosť: #{fmt(out[:load])} kg"
        out
      end

      # --- pomocne (verejne, cita ich C2 aj testy) ------------------------------

      def atira?(recipe)
        recipe[:system] == 'atira'
      end

      # Rad NL pre danu vysku (Atira) alebo jediny rad receptu (Quadro).
      def series_for(recipe, height_variant)
        return recipe[:nl_series] unless atira?(recipe)

        recipe[:nl_series_by_height][height_variant.to_s] || []
      end

      # Minimalna hlbka korpusu pre NL (EXPLICITNA tabulka, nie vzorec).
      def min_depth(recipe, nl)
        v = recipe[:min_depth_by_nl][key_num(nl)]
        raise RecipeError, "Recept #{recipe[:recipe_id]}: chyba min_depth pre NL #{nl}." if v.nil?

        v
      end

      # Nosnost bunky: by_height_nl -> by_nl -> default.
      def load_for(recipe, height_variant, nl)
        lb = recipe[:load_by_cell]
        if height_variant
          v = lb[:by_height_nl]["#{height_variant}/#{key_num(nl)}"]
          return v if v
        end
        lb[:by_nl][key_num(nl)] || lb[:default]
      end

      # KOV-C2b: hrubky, ktore system PRIJME pre VSETKY svoje vyrabane dielce
      # (PRIENIK cez roly — jeden materialovy kanal krmi vsetky roly naraz, takze
      # hrubka dobra len pre dno by pri Quadre aj tak padla na boku). Cita sa
      # z NAJNOVSIEHO vydaneho receptu systemu; neznamy system = [].
      # CISTA funkcia — pouziva ju preflight projektovej predvolby zasuviek.
      def supported_thicknesses(system, dir: DIR)
        id = OPENINGS.filter_map { |o| latest_for(system, o, dir: dir) }.first
        return [] if id.nil?

        lists = load(id, dir: dir)[:thickness_supported].values.map { |l| Array(l).map(&:to_f) }
        return [] if lists.empty?

        lists.reduce { |acc, l| acc.select { |v| l.any? { |x| same?(x, v) } } }.uniq.sort
      end

      def thickness_ok_for_system?(system, mm, dir: DIR)
        th = supported_thicknesses(system, dir: dir)
        !th.empty? && th.any? { |v| same?(v, mm) }
      end

      # Prijme hrubku ASPON JEDEN vydany system? JEDINY predikat pre VSETKY
      # cesty, ktorymi sa da nastavit material zasuviek (Codex #304 kolo 3 P2):
      # selektor predvolby v Studiu (`MaterialsDialog`) aj hromadne „Nahradit
      # UNI…" (`ru_project_target_issue`). Dva rozne predikaty by znamenali, ze
      # ta ista doska prejde jednou cestou a druhou nie.
      def thickness_ok_for_any_system?(mm, dir: DIR)
        SYSTEMS.any? { |sys| thickness_ok_for_system?(sys, mm, dir: dir) }
      end

      # Vsetky hrubky, ktore pozna aspon jeden vydany system (do hlasok).
      def all_supported_thicknesses(dir: DIR)
        SYSTEMS.flat_map { |sys| supported_thicknesses(sys, dir: dir) }.uniq.sort
      end

      # Odporucanie synchronizacnej tyce (P2O nad prahom sirky). C1 hodnotu len
      # pocita — ORANGE warning zapaja C2.
      def sync_recommended?(recipe, clear_width)
        recipe[:opening] == 'p2o' && clear_width.to_f >= recipe[:sync_min_width].to_f
      end

      # --- vnutorne ------------------------------------------------------------

      # Atira: presne 2 vyrabane dielce — dno + dreveny chrbat.
      #   LB   = svetla sirka niky
      #   dno    (LB - 2*EB - 51.5) x (NL + 10)
      #   chrbat (LB - 2*EB - 63)   x rear_height varianta
      def atira_parts(recipe, clear_w, nl, th, height_variant)
        c = recipe[:constants]
        eb = recipe[:eb].to_f
        rear_h = recipe[:height_variants][height_variant.to_s][:rear_height]
        [
          part(recipe, ROLE_BOTTOM, clear_w - (2 * eb) - c[:bottom_width_offset], nl + c[:bottom_length_plus], th),
          part(recipe, ROLE_BACK, clear_w - (2 * eb) - c[:rear_width_offset], rear_h, th)
        ]
      end

      def quadro_parts(recipe, clear_w, nl, box_h, th)
        c = recipe[:constants]
        skw = clear_w - c[:box_width_offset].to_f
        fb_h = box_h - th[ROLE_BOTTOM].to_f - c[:bottom_offset].to_f
        [
          part(recipe, ROLE_BOX_SIDE, nl, box_h, th, side: 'left'),
          part(recipe, ROLE_BOX_SIDE, nl, box_h, th, side: 'right'),
          part(recipe, ROLE_BOTTOM, skw, nl, th),
          part(recipe, ROLE_INNER_FRONT, skw, fb_h, th),
          part(recipe, ROLE_BACK, skw, fb_h, th)
        ]
      end

      def part(recipe, role, width, height, th, side: nil)
        p = { role: role, width: width.to_f, height: height.to_f,
              thickness: th[role].to_f, abs: (recipe[:abs][role] || {}) }
        p[:side] = side if side
        p
      end

      # Najvyssi variant, ktoreho `min_clear_height` sa zmesti (inkluzivne, bez EPS).
      def pick_height_variant(recipe, clear_h)
        recipe[:height_variants].map { |k, v| v.merge(height: k.to_i) }
               .sort_by { |v| -v[:height] }
               .find { |v| v[:min_clear_height].to_f <= clear_h }
      end

      # Rovnaky kontrakt ako `HardwareRules.override_nominal_length`:
      # `disabled` VITAZI — vypnuty zaznam zamok NENESIE (Codex #302 kolo 1 P2),
      # inak by vypnuta polozka riadila NL dielcov. Ako polozka s `disabled`
      # naklada receptova cesta (RED `drawer_override_invalid`) rozhoduje C2.
      def lock_value(recipe, ctx, overrides)
        owner = ctx[:owner_part_key]
        rule_ids = [LOCK_LEGACY_RULE_ID, "recipe:#{recipe[:recipe_id]}"]
        rec = Array(overrides).reverse.find do |ov|
          next false unless ov.is_a?(Hash)
          next false if get(ov, 'disabled') == true
          next false unless get(ov, 'generic_type').to_s == LOCK_GENERIC_TYPE
          next false unless rule_ids.include?(get(ov, 'rule_id').to_s)
          next false if owner && get(ov, 'owner_part_key').to_s != owner.to_s

          nl_value(get(ov, 'nominal_length'))
        end
        rec && nl_value(get(rec, 'nominal_length'))
      end

      def nl_value(v)
        return nil unless v.is_a?(Numeric)

        f = v.to_f
        f.finite? && f.positive? ? f : nil
      end

      def get(hash, key)
        hash.key?(key) ? hash[key] : hash[key.to_sym]
      end

      def normalize_thicknesses(raw)
        out = {}
        (raw.is_a?(Hash) ? raw : {}).each do |k, v|
          out[k.to_s] = v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : nil
        end
        out
      end

      def fail_with(out, code, message)
        out[:conflicts] << { code: code, message: message }
        out[:parts] = []
        out[:hardware_params] = {}
        out
      end

      def same?(a, b)
        (a.to_f - b.to_f).abs < 1e-9
      end

      def label(recipe)
        "#{system_label(recipe[:system])} #{recipe[:opening] == 'p2o' ? 'Tip-On' : 'SiSy'} v#{recipe[:version]}"
      end

      def system_label(system)
        { 'atira' => 'Atira', 'quadro_v6' => 'Quadro V6' }[system.to_s] || system.to_s
      end

      def role_label(role)
        { ROLE_BOTTOM => 'dno', ROLE_BACK => 'chrbát', ROLE_BOX_SIDE => 'bok boxu',
          ROLE_INNER_FRONT => 'vnútorné čelo', 'shelf' => 'policu',
          'divider_h' => 'vodorovnú priečku', 'divider_v' => 'zvislú priečku' }[role.to_s] || role.to_s
      end

      # Cislo do textu po slovensky: bez zbytocnych nul, desatinna CIARKA.
      def fmt(v)
        f = v.to_f
        s = (f - f.round).abs < 1e-9 ? f.round.to_s : format('%.2f', f).sub(/0+\z/, '').sub(/\.\z/, '')
        s.tr('.', ',')
      end

      # Kluc ciselnej mapy v JSONe ("470", nie "470.0").
      def key_num(v)
        f = v.to_f
        (f - f.round).abs < 1e-9 ? f.round.to_s : f.to_s
      end

      def str_or_nil(v)
        return nil unless v.is_a?(String)

        s = v.strip
        s.empty? ? nil : s
      end

      def parse_json(path)
        JSON.parse(File.read(path, encoding: 'UTF-8'))
      rescue JSON::ParserError => e
        raise RecipeError, "#{File.basename(path)}: neplatny JSON (#{e.message})."
      end

      # Odtlacok suboru s normalizovanymi koncami riadkov (viz hlavicka).
      def file_digest(path)
        raw = File.read(path, mode: 'rb').to_s
        raw = raw.sub(/\A\xEF\xBB\xBF/n, '')
        Digest::SHA256.hexdigest(raw.gsub("\r\n", "\n"))
      end

      # "atira_sisy_v1" -> { id:, system:, opening:, version: } alebo nil.
      def parse_id(id)
        s = id.to_s
        m = /\A(.+)_(#{OPENINGS.join('|')})_v(\d+)\z/.match(s)
        return nil unless m
        return nil unless SYSTEMS.include?(m[1])

        { id: s, system: m[1], opening: m[2], version: m[3].to_i }
      end

      # --- validacia schemy ----------------------------------------------------
      #
      # Chybajuce pole alebo bunka = ODMIETNUTIE CELEHO receptu. Ziadne
      # doplnanie defaultov, ziadne ignorovanie neznameho tvaru.
      def validate!(raw, id)
        raise RecipeError, "Recept #{id}: koren musi byt objekt." unless raw.is_a?(Hash)

        r = {}
        %w[recipe_id system family opening mounting rear_type].each do |k|
          v = raw[k]
          raise RecipeError, "Recept #{id}: chyba textove pole '#{k}'." unless v.is_a?(String) && !v.empty?

          r[k.to_sym] = v
        end
        raise RecipeError, "Recept #{id}: recipe_id '#{r[:recipe_id]}' nesedi s nazvom suboru." unless r[:recipe_id] == id
        raise RecipeError, "Recept #{id}: neznamy system '#{r[:system]}'." unless SYSTEMS.include?(r[:system])
        raise RecipeError, "Recept #{id}: nezname otvaranie '#{r[:opening]}'." unless OPENINGS.include?(r[:opening])
        raise RecipeError, "Recept #{id}: nezname family '#{r[:family]}'." unless FAMILIES.include?(r[:family])
        raise RecipeError, "Recept #{id}: mounting musi byt 'slide_on'." unless r[:mounting] == 'slide_on'
        raise RecipeError, "Recept #{id}: rear_type musi byt 'wooden'." unless r[:rear_type] == 'wooden'

        r[:version] = pos_int!(raw['version'], id, 'version')
        parsed = parse_id(id)
        unless parsed && parsed[:system] == r[:system] && parsed[:opening] == r[:opening] && parsed[:version] == r[:version]
          raise RecipeError, "Recept #{id}: nazov nesedi s poliami system/opening/version."
        end

        r[:eb] = pos_num!(raw['eb'], id, 'eb')
        r[:sync_min_width] = pos_num!(raw['sync_min_width'], id, 'sync_min_width')
        r[:kd_supported] = num_list!(raw['kd_supported'], id, 'kd_supported')
        r[:thickness_supported] = thickness_map!(raw['thickness_supported'], id, r[:family])
        r[:constants] = constants!(raw['constants'], id, r[:system])
        r[:abs] = abs_map!(raw['abs'], id, r[:thickness_supported].keys)
        r[:load_by_cell] = load_by_cell!(raw['load_by_cell'], id)
        r[:source] = raw['source'].is_a?(Hash) ? raw['source'] : (raise RecipeError, "Recept #{id}: chyba mapa 'source'.")
        r[:formula_doc] = raw['formula_doc'].is_a?(Hash) ? raw['formula_doc'] : {}

        series = validate_series!(raw, r, id)
        r[:min_depth_by_nl] = min_depth_map!(raw['min_depth_by_nl'], id, series)
        r
      end

      # Vysky a rady NL. Atira MUSI mat height_variants + nl_series_by_height;
      # Quadro MUSI mat nl_series a height_variants nesmie mat (system bez
      # vyskovych variantov). Vracia mnozinu VSETKYCH NL v receptoch.
      def validate_series!(raw, r, id)
        if r[:system] == 'atira'
          raise RecipeError, "Recept #{id}: system atira vyzaduje 'height_variants'." unless raw['height_variants'].is_a?(Hash)
          raise RecipeError, "Recept #{id}: system atira nesmie mat 'nl_series' (rady su per vyska)." if raw.key?('nl_series')

          hv = {}
          raw['height_variants'].each do |k, v|
            raise RecipeError, "Recept #{id}: kluc vysky '#{k}' musi byt cislo." unless k.to_s =~ /\A\d+\z/
            raise RecipeError, "Recept #{id}: variant #{k} musi byt objekt." unless v.is_a?(Hash)

            hv[k.to_s] = {
              rear_height: pos_num!(v['rear_height'], id, "height_variants.#{k}.rear_height"),
              min_clear_height: pos_num!(v['min_clear_height'], id, "height_variants.#{k}.min_clear_height"),
              railing: nonneg_num!(v['railing'], id, "height_variants.#{k}.railing")
            }
          end
          raise RecipeError, "Recept #{id}: 'height_variants' je prazdne." if hv.empty?

          r[:height_variants] = hv
          raise RecipeError, "Recept #{id}: chyba 'nl_series_by_height'." unless raw['nl_series_by_height'].is_a?(Hash)

          by_h = {}
          raw['nl_series_by_height'].each do |k, v|
            raise RecipeError, "Recept #{id}: rad NL pre neznamu vysku '#{k}'." unless hv.key?(k.to_s)

            by_h[k.to_s] = num_list!(v, id, "nl_series_by_height.#{k}")
          end
          missing = hv.keys - by_h.keys
          raise RecipeError, "Recept #{id}: chybaju rady NL pre vysky #{missing.join(', ')}." unless missing.empty?

          r[:nl_series_by_height] = by_h
          r[:nl_series] = nil
          by_h.values.flatten.uniq.sort
        else
          if raw.key?('height_variants') || raw.key?('nl_series_by_height')
            raise RecipeError, "Recept #{id}: system #{r[:system]} nema vyskove varianty — 'height_variants' je zakazane."
          end

          r[:nl_series] = num_list!(raw['nl_series'], id, 'nl_series')
          r[:height_variants] = nil
          r[:nl_series_by_height] = nil
          r[:nl_series].uniq.sort
        end
      end

      def constants!(raw, id, system)
        raise RecipeError, "Recept #{id}: chyba 'constants'." unless raw.is_a?(Hash)

        keys = system == 'atira' ? %w[bottom_width_offset rear_width_offset bottom_length_plus] : %w[box_width_offset bottom_offset box_clearance min_front_back_height]
        out = {}
        keys.each { |k| out[k.to_sym] = pos_num!(raw[k], id, "constants.#{k}") }
        out
      end

      # Roly, ktore recept danej rodiny vyraba — PRESNA mnozina, nie minimum.
      # Chybajuca aj prebytocna rola = odmietnutie receptu UZ PRI NACITANI
      # (Codex #302 kolo 1 P2): recept bez `drawer_back` by inak presiel a chyba
      # by vyplavala az ako `drawer_no_fit` nad hotovou zakazkou.
      FAMILY_ROLES = {
        'metal_box' => [ROLE_BOTTOM, ROLE_BACK].freeze,
        'wood_undermount' => [ROLE_BOTTOM, ROLE_BOX_SIDE, ROLE_INNER_FRONT, ROLE_BACK].freeze
      }.freeze

      def thickness_map!(raw, id, family)
        raise RecipeError, "Recept #{id}: chyba 'thickness_supported'." unless raw.is_a?(Hash) && !raw.empty?

        want = FAMILY_ROLES[family]
        raise RecipeError, "Recept #{id}: nezname family '#{family}'." if want.nil?

        got = raw.keys.map(&:to_s).sort
        unless got == want.sort
          raise RecipeError,
                "Recept #{id}: 'thickness_supported' musi mat PRESNE roly rodiny #{family} " \
                "(#{want.sort.join(', ')}), dostal #{got.join(', ')}."
        end

        out = {}
        raw.each { |role, list| out[role.to_s] = num_list!(list, id, "thickness_supported.#{role}") }
        out
      end

      def abs_map!(raw, id, roles)
        raise RecipeError, "Recept #{id}: chyba 'abs'." unless raw.is_a?(Hash)

        missing = roles - raw.keys.map(&:to_s)
        raise RecipeError, "Recept #{id}: 'abs' nema roly #{missing.join(', ')}." unless missing.empty?

        out = {}
        raw.each do |role, spec|
          raise RecipeError, "Recept #{id}: abs.#{role} musi byt objekt." unless spec.is_a?(Hash)

          h = {}
          spec.each { |edge, v| h[edge.to_sym] = pos_num!(v, id, "abs.#{role}.#{edge}") }
          out[role.to_s] = h
        end
        out
      end

      def load_by_cell!(raw, id)
        raise RecipeError, "Recept #{id}: chyba 'load_by_cell'." unless raw.is_a?(Hash)

        out = { default: pos_num!(raw['default'], id, 'load_by_cell.default'), by_nl: {}, by_height_nl: {} }
        %w[by_nl by_height_nl].each do |k|
          v = raw[k]
          raise RecipeError, "Recept #{id}: load_by_cell.#{k} musi byt objekt." unless v.is_a?(Hash)

          v.each { |cell, num| out[k.to_sym][cell.to_s] = pos_num!(num, id, "load_by_cell.#{k}.#{cell}") }
        end
        out
      end

      def min_depth_map!(raw, id, series)
        raise RecipeError, "Recept #{id}: chyba 'min_depth_by_nl'." unless raw.is_a?(Hash)

        out = {}
        raw.each { |nl, v| out[nl.to_s] = pos_num!(v, id, "min_depth_by_nl.#{nl}") }
        missing = series.map { |nl| key_num(nl) } - out.keys
        raise RecipeError, "Recept #{id}: 'min_depth_by_nl' nema bunky pre NL #{missing.join(', ')}." unless missing.empty?

        out
      end

      def num_list!(raw, id, field)
        raise RecipeError, "Recept #{id}: '#{field}' musi byt neprazdne pole cisel." unless raw.is_a?(Array) && !raw.empty?

        raw.map { |v| pos_num!(v, id, field) }
      end

      def pos_num!(v, id, field)
        raise RecipeError, "Recept #{id}: '#{field}' musi byt kladne konecne cislo (#{v.inspect})." unless v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive?

        v.to_f
      end

      def nonneg_num!(v, id, field)
        raise RecipeError, "Recept #{id}: '#{field}' musi byt nezaporne konecne cislo (#{v.inspect})." unless v.is_a?(Numeric) && v.to_f.finite? && v.to_f >= 0

        v.to_f
      end

      def pos_int!(v, id, field)
        raise RecipeError, "Recept #{id}: '#{field}' musi byt kladne cele cislo (#{v.inspect})." unless v.is_a?(Integer) && v.positive?

        v
      end
    end
  end
end
