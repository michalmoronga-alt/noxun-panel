# frozen_string_literal: true
# Noxun Engine — generator korpusu (dolna + horna). Regenerate pattern (standard sekcia 9):
# build (novy) a rebuild (clear definicie + build_into) — vzdy 1 Undo operacia.
# Geometriu (deskriptory dielcov) pocita CISTO Construction; tu sa len kresli (mm -> Length cez Units).
# Kazdy rebuild je obaleny ScaleWatch.guard, aby scale-observer neignoroval vlastne zmeny.
require 'json'

module Noxun
  module Engine
    module CabinetBuilder
      # Predvolby pre novy vklad. Dolna skrinka: dno POD bokmi (boky stoja na dne),
      # bez sokloveho panela (priestor pre nohy), korpus levituje o floor_height.
      LOWER_DEFAULTS = {
        type: 'lower', width: 600.0, height: 720.0, depth: 510.0, thickness: 18.0,
        floor_height: 100.0, shelves: 0, fronts: 'none',
        bottom_mode: 'under_sides', top_mode: 'full', back_mode: 'overlay', back_thickness: 3.0,
        plinth_mode: 'none', plinth_recess: 40.0,
        rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
      }.freeze

      # Horna skrinka: bez sokla (floor_height 0), dno aj vrch medzi bokmi (boky plna vyska),
      # chrbat default v drazke.
      UPPER_DEFAULTS = {
        type: 'upper', width: 600.0, height: 720.0, depth: 320.0, thickness: 18.0,
        floor_height: 0.0, shelves: 0, fronts: 'none',
        bottom_mode: 'between_sides', top_mode: 'full', back_mode: 'groove', back_thickness: 3.0,
        plinth_mode: 'none', plinth_recess: 40.0,
        rail_depth: 100.0, rails_orientation: 'flat', rails_top_offset: 0.0
      }.freeze

      # D-100: nazov skrinky. Zhoda s tymto vzorom = nazov POVAZUJEME za
      # nenastaveny (automaticky sa dopocitava zo sucasnych parametrov) — tak
      # ozivnu aj skrinky, ktore maju dnesny default zapeceny v configu, vratane
      # stareho bezdiakritickeho tvaru. Ruby /i pokryva aj velke Á.
      AUTO_NAME_RE = /\A(?:horn(?:a|á)|spodn(?:a|á))\s+skrinka\s+\d+\z/i
      NAME_MAX_LEN = 80 # JS zrkadlo: CAB_NAME_MAX v ui/js/core.js

      GAP_BETWEEN_CABS = 50.0    # medzera medzi korpusmi pri vkladani vedla seba
      UPPER_HANG_Z     = 1400.0  # vyska zavesenia hornej skrinky (Z pri vlozeni)

      # K1 / D-108: per-dielec SMER DEKORU ako vstup. Povolene hodnoty OVERRIDU
      # su LEN 'length'/'width' — „bez smeru" sa nenastavuje, to je vlastnost
      # MATERIALU. Chybajuci kluc = dedi z materialu (dnesne spravanie, stare
      # modely su platne bez jedineho zapisu). Neznama hodnota sa NIKDY ticho
      # neprelozi (enum guard v norm_overrides aj v zapisovej ceste panela).
      GRAIN_OVERRIDES = %w[length width].freeze

      # R-12 (blok 1d): VERZIA KONTRAKTU CONFIGU KORPUSU. Config je uzavrety
      # whitelist (`normalize` + `cabinet_config`), takze zakazka ulozena
      # NOVSIM pluginom by pri prestavbe ticho prisla o polia, ktore tato
      # verzia nepozna (`plan_schema` verzuje tranzientny plan a
      # `part_key_schema` len kluce dielcov — kompatibilitu CONFIGU nevyjadri
      # ani jeden). Marker sa zapisuje pri KAZDOM zapise configu a dopredny
      # guard (`guard_newer_config!`) odmietne prestavbu, ked je ulozene cislo
      # VYSSIE nez toto.
      #
      # DISCIPLINA BUMPU (SYSTEM/STANDARD.md 2.5): cislo sa zvysi pri KAZDOM
      # rozsireni whitelistu configu o pole, ktoreho TICHA STRATA by poskodila
      # vyrobu (nove pole konstrukcie, novy typ cela, nova rola). Cisto
      # odvodene/kozmeticke pole bump nevyzaduje.
      #
      # HISTORIA:
      #   1 = R-12 (zavedenie markera, 1d)
      #   2 = KOV-A1 — nove typy cela (`lift`/`fall`/`blind` -> roly flap /
      #       false_front) a nove polia polozky (`direction`, `wing_directions`,
      #       `opening_mode`, `drawer`). Ticha strata ktorehokolvek z nich by
      #       zmenila VYROBU (dielec by zmizol) alebo by zahodila smer, ktory
      #       pouzivatel vedome urcil — presne pripad z disciliny bumpu.
      #   3 = KOV-H1 — ad-hoc kovanie `hardware_manual[]` (polozka mimo setov
      #       viazana na skrinku alebo konkretny dielec). Ticha strata by
      #       ODOBRALA POLOZKU Z OBJEDNAVKY: starsi plugin by ju pri prvej
      #       prestavbe zmazal a nakup by bol NEUPLNY bez slova. K bumpu patri
      #       EXPORTNA brana (`Bom.collect` -> `newer_configs` ->
      #       `ProductionCore.export_blockers`): sama prestavbova brana
      #       nestacila — starsi plugin by zakazku so schemou 3 bez problemov
      #       VYEXPORTOVAL, len bez ad-hoc poloziek (audit #15 BLOCKER 3).
      #   4 = KOV-B1 — sety s KLASIFIKACIOU (`use_type`, `opening_mode`,
      #       `drawer_construction`, `manufacturer`, `series`, `active`)
      #       cestuju v SABLONACH (`hardware_set_defs`) a projektovy snapshot
      #       ma std 3. Starsi plugin by pri pouziti takej sablony zmrazil do
      #       .skp OREZANY set (klasifikacia prec) a nikto by uz nevedel, ze
      #       tam nieco bolo. Cislo sa prideluje SEKVENCNE podla poradia
      #       mergov (audit #17 FIX 5 — H1 vzala 3). K bumpu patria DVE brany:
      #       existujuci R-12 guard sablon (marker v `template_config_from`)
      #       odmietne sablonu z novsej verzie SPATNE, a nova
      #       `HardwareSets.assess_set_defs` chrani DOPREDU — definicie, ktore
      #       sa nedaju precitat bezstratovo, sa do modelu nezapisu vobec.
      CONFIG_SCHEMA = 4

      MIN = { width: 200.0, height: 200.0, depth: 150.0 }.freeze
      # D-45: povoleny rozsah hrubky korpusu (mm) — JEDINY zdroj pravdy pre clamp
      # v normalize, pre prevzatie hrubky z materialu aj pre projektovy guard.
      THICKNESS_RANGE = [6.0, 50.0].freeze

      # KOV-C2a: roly dielcov, ktore emituju RECEPTY zasuviek (`drawer_recipes.rb`).
      # V `BuildPlan::ROLES` este NIE SU — plan ich dostane az v C2b spolu
      # s bumpom `plan_schema`. Tu su preto ako RETAZCE (nie referencia na
      # `DrawerRecipes::ROLE_*`): `cabinet_builder` sa nacitava PRED
      # `drawer_recipes` a jednu doménovú pravdu drzi GUARD TEST, nie poradie
      # requirov (rovnaky vzor ako vazba `hardware_sets` <-> `Fronts`).
      DRAWER_ROLES = %w[drawer_bottom drawer_back box_side drawer_inner_front].freeze

      # Fallback farby SketchUp materialu, ak material_id nie je v katalogu (Materials preberie color).
      FALLBACK_RGB_KORPUS = [216, 196, 160].freeze
      FALLBACK_RGB_FRONT  = [245, 245, 245].freeze

      # --- KOV-H1: ad-hoc kovanie (`config['hardware_manual'][]`) -----------
      # UZAVRETY whitelist poli JEDNEJ polozky. Nic ine sa do configu nedostane.
      MANUAL_KEYS    = %w[id owner_part_key source code name unit price_eur_vat qty note].freeze
      # `catalog` = polozka katalogu (verime LEN kodu — nazov/MJ/cenu drzi server),
      # `free`    = volna polozka (nazov, MJ a cenu zadal pouzivatel).
      # `manual` tu VEDOME NIE JE — to je D-93 znamienko rucneho zasahu do
      # POCTU/dlzky setovej polozky (`config.hardware[].source`), uplne iny pojem
      # (audit #15 FIX 7). Ad-hoc kanal nesie `origin: 'adhoc'` az na riadku.
      MANUAL_SOURCES = %w[catalog free].freeze
      MANUAL_QTY_MAX = 999
      MANUAL_NOTE_MAX = 200

      # Odmietnutie ZAPISOVEJ cesty (ADD/EDIT z panela, `strict_owners: true`).
      # Citacia cesta (rebuild, legacy config) polozku len zahodi s logom —
      # prestavba nikdy nespadne na cudzom configu.
      ManualRejected = Class.new(StandardError)

      # DC scaletool bitova maska = uchopy na SKRYTIE (dogfood D-06, potvrdene 19.7.):
      # 120 = 8+16+32+64 (roviny XY/XZ/YZ + rohy) -> ostavaju CISTE osi X/Y/Z (1+2+4).
      # Povodna hodnota 7 z V0.2c skryvala presne opacne (osi prec, rohy ostali).
      SCALE_TOOL_MASK = 120
      FRONT_VALIDATION_VERSION = '0.3.1'

      # Tagy dielov (V0.2c) — hromadne hide cez nativny Tags panel. Default = Noxun/Korpus.
      PART_TAGS = {
        'back'         => 'Noxun/Chrbát',
        'front_door'   => 'Noxun/Čelá',
        'drawer_front' => 'Noxun/Čelá',
        # KOV-A1: vyklop/sklop (rola flap) a blenda (false_front) su tiez cela.
        'flap'         => 'Noxun/Čelá',
        'false_front'  => 'Noxun/Čelá',
        'shelf'        => 'Noxun/Vnútro',
        'divider_v'    => 'Noxun/Vnútro',
        'divider_h'    => 'Noxun/Vnútro'
      }.freeze
      PART_TAG_DEFAULT = 'Noxun/Korpus'
      HARDWARE_TAG     = 'Noxun/Kovanie'

      # Vizual noh (V0.4): generic valec — priemer/segmenty/odsadenie od hran korpusu.
      LEG_DIAMETER   = 50.0
      LEG_SEGMENTS   = 12
      LEG_INSET      = 60.0
      # Vizualny strop kreslenych noh — quantity v DATACH plati vzdy (supis), geometria
      # je proxy a nesmie polozit SketchUp pri poskodenom/extremnom pocte (audit D7).
      LEG_RENDER_MAX = 16

      # D-90 vizual uchytkoveho profilu (proxy): neutralny hlinikovy odtien +
      # odtlacok geometrie na definicii. PROFILE_GEOM_REV sa BUMPNE pri kazdej
      # zmene obrysu v FrontProfiles — stare definicie v ulozenych modeloch sa
      # tak pri najblizsom rebuilde prekreslia (recyklacia podla mena inak
      # zastaralu geometriu nikdy nezbadá).
      PROFILE_MATERIAL = 'NOXUN_PROFIL_HLINIK'
      PROFILE_RGB      = [176, 180, 184].freeze
      PROFILE_DICT     = 'NOXUN_PROFILE'
      PROFILE_GEOM_REV = 2
      # Krok kvantovania dlzky proxy (mm) — meno definicie, odtlacok aj kreslena
      # geometria pouzivaju ROVNAKU zaokruhlenu hodnotu (GH #145 P2). 0,01 mm je
      # pod toleranciou SketchUpu (0,0254 mm).
      PROFILE_LENGTH_STEP = 0.01

      # R-03 (blok 1d): tolerancia kontroly RIGIDNEHO vkladacieho transformu.
      # 1e-6 na skalarnych sucinoch je rádovo 1e-3 stupna skosenia — pod
      # rozlisenim SketchUpu, ale nad numerickym sumom skladania rotacii.
      RIGID_TOL = 1e-6

      # R-03: ZMRAZENY snapshot vkladu (prepare_insert -> commit_insert).
      # Drzi ho GHOST Tool medzi pohybom mysi a klikom, preto:
      #   * `config` je hlboka kopia s REKURZIVNYM freeze (vratane vnorenych
      #     hashov, poli aj stringov) — nikto ho po ceste ticho nezmeni,
      #   * plan si pamata DOKUMENT, z ktoreho vznikol, ako REFERENCIU na
      #     `Sketchup::Model` (nie `guid` — ten sa meni pri kazdom ulozeni,
      #     lekcia PR #261/#264), takze cross-document vklad sa da odmietnut,
      #   * ziadne ID, ziadna entita, ziadny Undo krok — tie vznikaju az v commite.
      class InsertPlan
        attr_reader :config, :home_z

        def initialize(model, config, home_z)
          @model = model
          @config = config
          @home_z = home_z
          freeze
        end

        # Patri plan TOMUTO dokumentu? Porovnava sa objekt modelu (identita
        # dokumentu v behu), nie jeho guid.
        def for_model?(model)
          !model.nil? && @model.equal?(model)
        end

        # Referencia na dokument planu (diagnostika; commit ju necita).
        def model_ref
          @model
        end
      end

      class << self
        # --- verejne API ----------------------------------------------------

        # Vlozi novy korpus. Dolna na Z=0 vedla existujucich; horna na Z=UPPER_HANG_Z. Vrati instanciu.
        # Korpus je VZDY top-level (model.entities) — nikdy do aktivneho edit kontextu (inak
        # by sa korpus vlozil do cudzieho komponentu). Preto najprv zavrieme edit kontext.
        # H2 (D-76): volitelny blok bezi v TEJ ISTEJ operacii PRED stavbou (vzor
        # rebuild_many) — zapis dat, ktore k novej skrinke patria (zmrazenie setov
        # kovania zo sablony). Vynimka v bloku zrusi CELU operaciu: ziadna skrinka,
        # ziadny zapis.
        # R-03: KOMPOZICIA sevu — spravanie vsetkych dnesnych volajucich je
        # NEZMENENE. `ensure_root_context` je PRVY krok (dnesne poradie: najprv
        # sa zavrie edit kontext, az potom sa normalizuje) — pri vynimke
        # z `normalize` musi pouzivatel skoncit v roote presne ako doteraz.
        # `commit_insert` si root este raz idempotentne overi.
        # `transform:` = FINALNA transformacia instancie (GHOST Tool poloha);
        # nil = dnesna cesta „vedla existujucich" (`next_x` + `home_z`).
        #
        # KOMPATIBILITA VOLANIA (review P2): pred R-03 nemal `build` ZIADNY
        # keyword parameter, takze Ruby 3 prevadzalo `build(model, type: 'lower',
        # width: 600)` na POZICNY hash. Holy `transform:` by taketo volania
        # rozbil (ArgumentError: unknown keyword). Preto je `params` VOLITELNY
        # a zvysne keywordy sa zbieraju do `**kw`: ked `params` chyba, pouziju
        # sa ONE ako parametre skrinky. Jedine REZERVOVANE meno je `transform`
        # — nie je to parameter korpusu (`normalize` ho nepozna), ale kto by ho
        # v params predsa len chcel, musi params poslat POZICNE. Params dvakrat
        # (pozicne AJ keywordmi) je chyba volajuceho, nie tiche zliatie.
        def build(model, params = nil, transform: nil, **kw, &block)
          if params.nil?
            params = kw
          elsif !kw.empty?
            raise ArgumentError,
                  "build: parametre skrinky prisli dvakrat — pozicne aj ako keywordy (#{kw.keys.join(', ')})"
          end
          ensure_root_context(model)
          commit_insert(model, prepare_insert(model, params), transform: transform, &block)
        end

        # R-03 FAZA 1: ciste PRIPRAVENIE vkladu. Vrati zmrazeny `InsertPlan`.
        #
        # KONTRAKT CISTOTY je uzko formulovany: ZIADNA mutacia modelu, entit,
        # ID ani Undo stacku. NIE je to vseobecna cistota — `normalize` cez
        # `Materials.normalized_abs_id` moze siahnut na KATALOG na disku
        # (seed pri prvom dotyku) a logovat; to je vedoma hranica R-03
        # (audit NOTE 7), nie sluby tohto sevu.
        # `ensure_root_context` sa TU NEVOLA — ghost hover nesmie pouzivatelovi
        # zatvarat otvoreny komponent (audit c).
        # `Construction.build_plan` sa sem NEPRESUVA: validacne chyby by sa
        # zobrazili pred hardware blokom a pred commit-time snapshotmi (audit e).
        # Opakovane volatelna — druhe „Vloz" je novy snapshot.
        def prepare_insert(model, params)
          cfg = deep_copy_cfg(normalize(params), freeze_result: true)
          home_z = cfg[:type] == 'upper' ? UPPER_HANG_Z : 0.0
          InsertPlan.new(model, cfg, home_z)
        end

        # R-03 FAZA 2: JEDINE miesto, kde vklad meni model. Poradie krokov je
        # sucastou kontraktu (audit BLOCKER 1, FIX 4, NOTE 9):
        #   1. guard identity DOKUMENTU — plan z ineho okna sa odmieta EST PRED
        #      zatvorenim edit kontextu (cross-document vklad nikdy),
        #   2. validacia explicitneho transformu — prijme sa LEN konecna
        #      pravotociva RIGIDNA transformacia; scale/skos/zrkadlo by
        #      vyrobili korpus, ktoreho geometria nezodpoveda configu, a scale
        #      observer by ho pod guardom ani nezachytil (ticha vyrobna chyba),
        #   3. `ensure_root_context` + KONTROLA postcondition — helper po
        #      vynimke/20 iteraciach vracia nil a pokracuje; bez kontroly by
        #      korpus skoncil v cudzom komponente,
        #   4. az teraz ID a poloha (`next_x`),
        #   5. jedna operacia + transparentny scale-lock follow-up, OBOJE vnutri
        #      `guarded` (BLOCKER 2 — zapis scale-lock atributov mimo guardu by
        #      cez `EntitiesObserver#onElementModified` zalozil oneskoreny dirty
        #      tik a transparentny presun ghost zon by zasiahol Undo).
        # H2 (D-76): volitelny blok bezi v TEJ ISTEJ operacii PRED stavbou
        # (zmrazenie setov kovania zo sablony). Vynimka v bloku rusi CELU
        # operaciu: ziadna skrinka, ziadny zapis.
        def commit_insert(model, plan, transform: nil)
          unless plan.is_a?(InsertPlan) && plan.for_model?(model)
            raise 'Pripravený vklad patrí inému dokumentu — skrinku vlož v okne, v ktorom si ju pripravil.'
          end
          # Review P1: `Geom::Transformation` je MUTOVATELNA (`set!`). Overit
          # objekt volajuceho a potom ho pouzit by bola diera medzi kontrolou
          # a pouzitim — sprievodny blok (H2) bezi v tej istej operacii a mohol
          # by transform prepisat na mierku UZ PO validacii; korpus by vznikol
          # zvacseny POD `guarded` guardom, takze by ho scale observer ani
          # nezachytil. Preto sa hned pri validacii vyrobi KANONICKY SNAPSHOT
          # z tych istych overenych 16 cisel a dalej sa pracuje VYHRADNE s nim.
          placement = transform.nil? ? nil : snapshot_insert_transform!(transform)

          ensure_root_context(model)
          unless root_context?(model)
            raise 'Nepodarilo sa zavrieť otvorený komponent — korpus by sa vložil doň. Ukonči editáciu (Esc) a skús znova.'
          end

          # Do stavby ide PRACOVNA (nezmrazena) kopia configu: `build_into`
          # cez `PartKeys.migrate_overrides` zdiela vnorene hashe overridov
          # a `resolve_part` v nich upratuje sticky `edge_warnings` in-place.
          # Plan musi ostat nemenny, dnesne spravanie stavby nezmenene.
          cfg = deep_copy_cfg(plan.config)
          cid = Ids.next_cabinet_id(model)
          tr = placement || Geom::Transformation.translation(Units.point(next_x(model), 0, plan.home_z))
          inst = nil
          # guarded: vlozenie je vlastna zmena pluginu. EntitiesObserver.onElementAdded (davkovany
          # na commit) tak vidi @rebuilding=true a novy korpus nepovazuje za kopiu (ziadny extra tick).
          guarded do
            model.start_operation('NOXUN: Vloz korpus', true)
            begin
              yield if block_given? # H2: sprievodny zapis v tej istej operacii
              cdef = model.definitions.add("NOXUN Korpus #{cid}")
              cdef.entities.clear!
              final = build_into(model, cdef, cfg, cid)
              inst = model.entities.add_instance(cdef, tr)
              write_cabinet_attrs(inst, cid, final)
              Zones.sync_ghost(model, inst) if defined?(Zones)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
            # D-40: scale zamok az PO commite vlozenia, v transparentnom follow-upe.
            # DC atribut v operacii, ktora entity VYTVARA, by pri commite cez DC
            # extension observer vypol dorucovanie selection eventov celemu modelu
            # (Inspector by visel na starom vybere az do zmeny edit kontextu).
            apply_scale_lock_op(model, inst)
          end
          ScaleWatch.attach_one(inst) if inst && defined?(ScaleWatch)
          inst
        end

        # R-03: hlboka kopia configu. `freeze_result: true` navyse REKURZIVNE
        # mrazi vysledok. Poradie je podstatne (audit FIX 3): najprv KOPIA,
        # az potom freeze — `enum_val` vracia `v.to_s`, co je pri Stringu TEN
        # ISTY objekt ako vstup volajuceho, takze priamy freeze by zmrazil
        # params volajuceho. Cudzie objekty (mimo Hash/Array/String) sa
        # nekopiruju ani nemrazia — Symbol, Numeric, nil a boolean su uz
        # nemenne a nic ine sa v configu nevyskytuje.
        def deep_copy_cfg(obj, freeze_result: false)
          case obj
          when Hash
            out = {}
            obj.each do |k, v|
              key = k.is_a?(String) ? k.dup : k
              key.freeze if freeze_result && key.is_a?(String)
              out[key] = deep_copy_cfg(v, freeze_result: freeze_result)
            end
            freeze_result ? out.freeze : out
          when Array
            out = obj.map { |v| deep_copy_cfg(v, freeze_result: freeze_result) }
            freeze_result ? out.freeze : out
          when String
            s = obj.dup
            freeze_result ? s.freeze : s
          else
            obj
          end
        end

        # R-03: je model naozaj v ROOT kontexte? `ensure_root_context` po
        # vynimke alebo po 20 iteraciach ticho vracia nil — commit sa na jeho
        # navratovu hodnotu nesmie spoliehat.
        def root_context?(model)
          path = model.active_path
          path.nil? || path.length.zero?
        rescue StandardError
          false
        end

        # R-03 (audit BLOCKER 1): prijmeme LEN konecnu pravotocivu RIGIDNU
        # transformaciu (rotacia + posun). Hlaska navadza — pri odmietnuti sa
        # NIC v modeli nezmenilo.
        def validate_insert_transform!(tr)
          return if rigid_transform?(tr)
          raise_bad_insert_transform!
        end

        # R-03 + review P1: validacia a SNAPSHOT v jednom kroku. `to_a` sa cita
        # PRAVE RAZ a kanonicka matica sa postavi z TYCH ISTYCH overenych cisel
        # — medzi kontrolou a pouzitim tak nie je zadna medzera, ktorou by sa
        # dala podstrcit ina hodnota (`Geom::Transformation#set!`).
        def snapshot_insert_transform!(tr)
          vals = tr.respond_to?(:to_a) ? Array(tr.to_a) : nil
          raise_bad_insert_transform! unless rigid_matrix?(vals)
          Geom::Transformation.new(vals.map(&:to_f))
        end

        def raise_bad_insert_transform!
          raise 'Poloha vkladu nie je platná — korpus sa smie položiť len otočením a posunutím ' \
                '(mierka, skosenie ani zrkadlenie nie sú povolené).'
        end

        # R-03: kontrola rigidity nad OBJEKTOM (duck-type — staci `to_a`).
        def rigid_transform?(tr)
          rigid_matrix?(tr.respond_to?(:to_a) ? Array(tr.to_a) : nil)
        end

        # R-03: CISTA kontrola rigidity nad 16 cislami. SketchUp uklada maticu
        # po STLPCOCH:
        #   [0..2] os X · [4..6] os Y · [8..10] os Z · [12..14] posun
        #   [3],[7],[11] perspektiva · [15] uniformny mierkovy DELITEL
        # Rigidita = jednotkove a navzajom kolme osi + determinant +1 (zaporny
        # = zrkadlo) + nulova perspektiva.
        # POZNAMKA k [15] (review P3a): moderny SketchUp drzi tento prvok
        # KANONICKY (1.0) a rovnomernu mierku premieta rovno do osi — na
        # `scaling(2)` staci kontrola jednotkovosti osi. Kontrola [15] je tu
        # ako ochrana pred NEKANONICKOU / legacy maticou (surove pole zostavene
        # rucne, matica zo starsieho suboru), ktora mierku nesie prave tam;
        # bez nej by taka matica presla ako „rigidna".
        def rigid_matrix?(m)
          return false unless m.is_a?(Array) && m.length == 16
          return false unless m.all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
          m = m.map(&:to_f)
          return false unless (m[15] - 1.0).abs <= RIGID_TOL
          return false unless [m[3], m[7], m[11]].all? { |v| v.abs <= RIGID_TOL }

          ax = [m[0], m[1], m[2]]
          ay = [m[4], m[5], m[6]]
          az = [m[8], m[9], m[10]]
          return false unless [ax, ay, az].all? { |v| (vec_dot(v, v) - 1.0).abs <= RIGID_TOL }
          return false unless vec_dot(ax, ay).abs <= RIGID_TOL &&
                              vec_dot(ax, az).abs <= RIGID_TOL &&
                              vec_dot(ay, az).abs <= RIGID_TOL

          (vec_dot(ax, vec_cross(ay, az)) - 1.0).abs <= RIGID_TOL
        end

        def vec_dot(a, b)
          (a[0] * b[0]) + (a[1] * b[1]) + (a[2] * b[2])
        end

        def vec_cross(a, b)
          [(a[1] * b[2]) - (a[2] * b[1]),
           (a[2] * b[0]) - (a[0] * b[2]),
           (a[0] * b[1]) - (a[1] * b[0])]
        end

        # Prestavia existujuci korpus. transform: volitelne nova cista transformacia (scale absorpcia).
        # op_name: nazov Undo operacie. Cele obalene guardom, aby scale-observer ignoroval vlastnu zmenu.
        # transparent: true = operacia sa pripoji k PREDCHADZAJUCEJ na undo stacku (observer reakcie
        # na pouzivatelov krok — scale absorpcia; 1x undo potom vrati oboje naraz).
        def rebuild(model, inst, params, transform: nil, op_name: 'NOXUN: Aplikuj zmeny', transparent: false)
          cid = Store.get(inst, 'cabinet_id')
          raise 'Vybrana instancia nie je NOXUN korpus.' if cid.nil?

          # KRITICKE (V0.2c bugfix): rebuild musi bezat v ABSOLUTNOM (root) rame.
          # Ak je uzivatel dvojklikom vnoreny v komponente, inst.transformation je
          # interpretovana v edit rame (relativna) a commit by korpus teleportoval
          # na origin. Zavretim edit kontextu citame/zapisujeme transformaciu spravne.
          ensure_root_context(model)

          cfg = normalize(params)
          guarded do
            model.start_operation(op_name, true, false, transparent)
            begin
              # Ak je definicia zdielana (kopia korpusu), osamostatni ju — inak by clear!/build
              # prepisal aj original. Standard 9.3: kopia sa da upravit nezavisle od originalu.
              rebuild_in_operation(model, inst, cfg, transform: transform)
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          inst
        end

        # Prestavi viac korpusov v JEDNEJ SketchUp operacii. Volitelny blok sa
        # vykona v tej istej operacii pred rebuildami (napr. zapis projektoveho
        # defaultu), takze chyba vrati naspat aj data aj geometriu.
        def rebuild_many(model, items, op_name: 'NOXUN: Hromadny prepocet')
          prepared = Array(items).map do |entry|
            inst, params = entry
            cid = Store.get(inst, 'cabinet_id')
            raise 'Jedna z instancii nie je NOXUN korpus.' if cid.nil?
            [inst, normalize(params)]
          end

          ensure_root_context(model)
          guarded do
            model.start_operation(op_name, true)
            begin
              yield if block_given?
              prepared.each { |inst, cfg| rebuild_in_operation(model, inst, cfg) }
              model.commit_operation
            rescue StandardError => e
              abort_safely(model)
              raise e
            end
          end
          prepared.map(&:first)
        end

        # Vnutorna cast rebuildu; volajuci uz musi mat otvorenu operaciu a guard.
        def rebuild_in_operation(model, inst, cfg, transform: nil)
          cid = Store.get(inst, 'cabinet_id')
          raise 'Vybrana instancia nie je NOXUN korpus.' if cid.nil?

          # D1 (audit B5, forward-compat): config z NOVSEJ verzie pluginu moze
          # niest genericky typ kovania, ktory tato verzia nepozna — plan
          # vznika nanovo, takze rebuild by polozky TICHO stratil (objednavka
          # by prisla o kovanie). Radsej jasne odmietnut; model sa da dalej
          # citat aj exportovat, len prestavba caka na aktualizaciu pluginu.
          guard_unknown_hardware!(inst)
          # R-12: to iste pre CELY config — novsi kontrakt configu (marker
          # `config_schema`) znamena polia, ktore tato verzia nepozna a
          # `normalize` by ich zahodila. Citanie, exporty, VEPO ani vyber sa
          # NEBLOKUJU — zastavi sa vyhradne PRESTAVBA.
          guard_newer_config!(inst)

          inst.make_unique if inst.definition.instances.size > 1
          cdef = inst.definition
          # 2B-1 (audit F8): duplak vazby zo SUCASNYCH snapshotov dielcov — na
          # stroji, ktoreho katalog duplak nepozna, by rebuild vazbu stratil.
          legacy_sources = collect_part_sources(cdef)
          cdef.entities.clear!
          final = build_into(model, cdef, cfg, cid, legacy_sources: legacy_sources)
          inst.transformation = transform if transform
          write_cabinet_attrs(inst, cid, final)
          apply_scale_lock(inst)
          Zones.sync_ghost(model, inst) if defined?(Zones)
          inst
        end

        # D1 (audit B5): neznamy generic_type v ulozenom config.hardware[]
        # ALEBO v klucoch hardware_sets (GH #126 P2) = model z novsej verzie
        # pluginu; prestavba sa odmieta (cista kontrola v BuildPlan).
        def guard_unknown_hardware!(inst)
          cfg = Store.config(inst)
          return unless cfg.is_a?(Hash)
          set_keys = cfg['hardware_sets'].is_a?(Hash) ? cfg['hardware_sets'].keys : nil
          unknown = BuildPlan.unknown_generic_types(cfg['hardware'], set_keys)
          return if unknown.empty?
          raise "Korpus nesie kovanie z novšej verzie Noxun (#{unknown.join(', ')}) — projekt vyžaduje novší plugin, prestavba by kovanie stratila."
        end

        # --- R-12: dopredny guard CONFIGU korpusu ---------------------------
        # Guard cita RAW ULOZENY config z ENTITY (`Store.config`), NIKDY nie
        # params z panela: klientsky payload prechadza cez CEF a cez uzavrete
        # whitelisty JS, takze marker v nom uz mohol vypadnut — autorita je
        # vyhradne to, co je v modeli.
        def guard_newer_config!(inst)
          cfg = Store.config(inst)
          return unless newer_config?(cfg)

          raise newer_config_message('Korpus', 'prestavba by nastavenia stratila')
        end

        # Marker configu ako Integer. Chybajuci marker = 0 (legacy korpus
        # spred R-12) a ten NIKDY neblokuje.
        def config_schema_of(cfg)
          return 0 unless cfg.is_a?(Hash)

          cfg['config_schema'].to_i
        end

        # Je ulozeny config z NOVSEJ verzie? Porovnanie je PRISNE vacsie —
        # rovnaka schema je kompatibilna, starsia (aj 0) tiez.
        def newer_config?(cfg)
          config_schema_of(cfg) > CONFIG_SCHEMA
        end

        # JEDINY textovy zdroj odmietnutia (rebuild, sablony, kopia,
        # ulozenie ako sablona) — pouzivatel ma vsade citat to iste.
        def newer_config_message(subject, consequence)
          "#{subject} je z novšej verzie Noxun — #{consequence}; projekt vyžaduje novší plugin."
        end

        # V0.2c fix #6: detekuje kopie korpusu (viac instancii so zdielanym cabinet_id) a kazdej
        # NOVSEJ pridelí nove cabinet_id + prestaví ju. rebuild spraví make_unique (osamostatni
        # zdielanu definiciu) a prepocita part_id, zony aj ghosty pod novym cid. Original zostane
        # netknuty. Vola sa z panel resolvera a scale observera ("sync tick"). Vrati prestavane inst.
        # Standard 2.3/9.3: "Kopia skrinky dostane nove cabinet_id."
        # transparent: true LEN ked volajuci VIE, ze predchadzajuca operacia je vlozenie kopie
        # (observer tick s cerstvym onElementAdded) — vtedy 1x undo vrati kopiu CELU.
        # Z panel sync cesty (push_selected) a inych kontextov = false: samostatny undo krok,
        # aby sa dedup neprilepil na nesuvisiacu poslednu akciu (Codex review PR #21).
        # fresh_ids (V0.4.7b, Codex audit + GH review P2): entityID mnozina PRAVE
        # pridanych entit. Ak je dana, spracuju sa IBA tieto duplikaty (transparentne
        # k pouzivatelovmu paste kroku); STARE duplicity sa v tomto ticku NEDOTKNU —
        # observer si na ne naplanuje follow-up tick (samostatne undo kroky). Inak by
        # miesana davka stale+fresh rozbila vazbu transparentneho undo na paste.
        def dedup_copies(model, transparent: false, fresh_ids: nil)
          return [] unless model
          dups = Ids.duplicate_cabinets(model)
          dups = dups.select { |i| i && i.valid? && fresh_ids.include?(i.entityID) } if fresh_ids
          return [] if dups.empty?
          # Root kontext ako v rebuild (Codex review PR #21): dedup moze bezat aj pocas
          # editacie komponentu — bez zatvorenia edit ramca by sa transformacia kopie
          # citala relativne a ghost zony by vznikli na zlom mieste.
          ensure_root_context(model)
          done = []
          dups.each do |inst|
            next unless inst && inst.valid?
            # R-12: kopia z NOVSEJ verzie sa PRESKOCI, cyklus ide dalej.
            # Prestavba pod novym ID by jej config orezala, ale vynimka
            # z `rebuild_in_operation` by dobehla az do rescue okolo CELEJ
            # metody — prva takato kopia by vyhladovala vsetky ostatne
            # (kompatibilne) duplicity a follow-up tik sa uz neplanuje.
            # PRIZNANY DOSLEDOK: kopia si necha ZDIELANE `cabinet_id`, takze
            # Kontrola drzi ORANGE `duplicate_identity` a zliate ID zastavi
            # nakupne/cenove exporty (brana P0-2). To je vedome — tichy orez
            # vyrobnych dat je horsi nez zastaveny export.
            if newer_config?(Store.config(inst))
              Engine.log('dedup: kopia korpusu je z novsej verzie Noxun — ID sa neprideluje') if defined?(Engine)
              next
            end
            new_cid = Ids.next_cabinet_id(model)
            trans = fresh_ids ? true : transparent
            # V0.3.4 undo fix (runner S2): prepis identity (standard 2.2: autorita = instancia)
            # + rebuild bezia v JEDNEJ operacii (transparentnej len pri cerstvej kopii, viz vyssie).
            # Predtym sa nove cid zapisovalo MIMO operacie a po undo ostaval nekonzistentny medzistav.
            guarded do
              model.start_operation('NOXUN: Kopia korpusu — nove ID', true, false, trans)
              begin
                Store.write(inst, { std: Store::STD, kind: 'cabinet', id: new_cid, cabinet_id: new_cid })
                params = config_to_params(Store.config(inst) || {})
                # KOV-H1 (audit FIX 10): tu vznika NOVA skrinka z existujucej —
                # jedine miesto (spolu s „Vlozit kopiu"), kde ad-hoc polozky
                # dostavaju vlastnu identitu. `normalize` ID NIKDY nemeni.
                rekey_hardware_manual(params)
                rebuild_in_operation(model, inst, normalize(params))
                model.commit_operation
              rescue StandardError => e
                abort_safely(model)
                raise e
              end
            end
            done << inst
            Engine.log("dedup: kopia korpusu dostala nove ID #{new_cid}") if defined?(Engine)
          end
          done
        rescue StandardError => e
          Engine.log_error(e, 'CabinetBuilder.dedup_copies') if defined?(Engine)
          []
        end

        # Zavrie vsetky otvorene edit konteksty tak, aby model.active_entities == model.entities.
        # Volane pred build/rebuild — pozri bugfix poznamku v rebuild. Bezpecne aj ked sme uz v roote.
        def ensure_root_context(model)
          guard = 0
          while model.active_path && model.active_path.length.positive? && guard < 20
            model.close_active
            guard += 1
          end
        rescue StandardError => e
          Engine.log_error(e, 'ensure_root_context') if defined?(Engine)
          nil
        end

        # --- jadro stavby ---------------------------------------------------

        # Postavi vsetky dielce + ghost zony do cdef podla planu z Construction. Vrati doplneny config.
        #
        # V0.3 materialy + ABS: kazdemu dielcu sa vyriesi VYSLEDNY material_id a ABS hrany cez retaz
        # (standard 7.2): pravidlove defaulty roly -> dedenie projekt->korpus -> part_override (viťazi).
        # Vysledok sa zapise do configu dielca (dielec vzdy nesie KONKRETNY material = "zaradeny" stav).
        def build_into(model, cdef, cfg, cid, legacy_sources: {})
          # Pravidla kovania = PROJEKTOVY snapshot (reprodukovatelnost z .skp — audit K2).
          # Prvy build ho zapise z globalnej kniznice; sme VNUTRI operacie volajuceho,
          # takze undo vrati model aj snapshot naraz.
          rules = defined?(HardwareRules) ? HardwareRules.ensure_project_rules!(model) : nil
          # D1b: rovnaka mechanika pre SETY kovania — prva stavba zmrazi
          # mapping + definicie z globalu (audit B2/F9; :invalid sa NEOPRAVUJE
          # ticho — ensure vtedy vrati nil a nic nezapise).
          # R-07: to iste plati pre NEKOMPATIBILNU globalnu kniznicu (novsia
          # verzia / neznamy tvar) — `ensure_project_state!` vtedy vrati nil,
          # takze sa do .skp NEZMRAZI orezany stav. Stavba bezi dalej, len bez
          # snapshotu; supis kovania to prizna ORANGE `library_incompatible`.
          HardwareSets.ensure_project_state!(model) if defined?(HardwareSets)
          plan = Construction.build_plan(cfg, cid, hardware_rules: rules) # validuje interne
          ents = cdef.entities
          tid = template_id_for(cfg[:type])

          # Efektivne korpusove materialy = korpus config, inak dedenie z projektovych defaultov (model).
          eff = effective_materials(model, cfg)
          eff_body  = eff['body']
          eff_front = eff['front']
          eff_back  = eff['back']
          overrides = PartKeys.migrate_overrides(cfg[:part_overrides], plan[:parts])
          cfg = cfg.merge(part_overrides: overrides, part_key_schema: PartKeys::SCHEMA)

          # 2A-3 (audit B2): pocas resolve_part sa zbieraju neuspechy/fallbacky
          # ABS pickera; po rozrieseni materialov sa PRIPOJA do planu a plan sa
          # RE-VALIDUJE — warning tak prezije retaz config -> Bom.collect ->
          # Validation.run (ORANGE KONTROLA). Pri SCHEMA 1 kolektor ostava
          # prazdny (resolve_edges legacy cesta nic nezbiera — dual-mode).
          abs_issues = []
          plan[:parts].each do |pd|
            next unless positive_box?(pd[:box]) # ochrana proti degenerovanym dielcom (uzke zony)
            resolved = resolve_part(pd, eff_body, eff_front, eff_back, overrides,
                                    abs_issues: abs_issues, legacy_sources: legacy_sources)
            add_part(model, ents, pd, resolved, cid, tid)
            # D-90: uchytkovy profil na hornej hrane cela — PROXY vizual v pasme
            # nad skratenym panelom (rovnaky kontrakt ako nohy, viz nizsie).
            render_front_profile(model, ents, pd, cid)
          end
          attach_abs_warnings!(plan, abs_issues)

          render_hardware(model, ents, plan[:hardware], cfg, cid)

          # V0.2c: ghost zony uz NEstoja v definicii korpusu, ale ako top-level skupina
          # (Zones.sync_ghost, volane z build/rebuild) — klik na zonu = 1 klik bez dvojkliku.
          merge_final(cfg, plan)
        end

        # 2A-3 (audit B2): kanonicke warnings z vyberu ABS do planu + re-validacia.
        # Volane az PO resolve slucke — Construction.build_plan validuje warnings
        # PRED resolve_part, taketo polozky by inak nikdy nepresli kontraktom.
        def attach_abs_warnings!(plan, issues)
          return plan if issues.nil? || issues.empty?
          plan[:warnings].concat(AbsRules.pick_warnings(issues))
          BuildPlan.validate!(plan)
          plan
        end

        # Vyriesi material + ABS hrany jedneho dielca cez stabilny part_key.
        # Renderovaci suffix a part_id ostavaju nezmenene; uz nie su datovym klucom override.
        # part_key je stabilny pri presune cela aj pri zmenach susednych zon;
        # role_key zostava iba kompatibilny nazov pola v sucasnom UI protokole.
        # abs_issues (2A-3, audit B2): kolektor neuspechov ABS pickera — polozky
        # {part_key:, name:, code:, reason:} pre agregaciu do plan[:warnings].
        # Hrany PREPISANE overridom (aj vedome nil) sa NEHLASIA — override je
        # rozhodnutie pouzivatela, warning by klamal.
        def resolve_part(pd, eff_body, eff_front, eff_back, overrides, abs_issues: nil, legacy_sources: {})
          part_key = PartKeys.for_descriptor(pd)
          ov = overrides[part_key].is_a?(Hash) ? overrides[part_key] : {}
          base_mat = base_material_for(pd[:role], pd[:material], eff_body, eff_front, eff_back)
          mat_id = present(ov['material_id']) || base_mat
          # Jeden lookup doskoveho materialu — pouzity na dekor (ABS) aj hrubkovu kontrolu (V0.3 FIX 2).
          sheet = (defined?(Materials) && mat_id) ? Materials.sheet(mat_id) : nil
          validate_material_thickness!(mat_id, sheet, pd)
          mat_source = material_source_for(mat_id, sheet, legacy_sources[part_key])
          decor = sheet && sheet['decor']
          # D-41 (audit FIX 10): picker sirky pasky dostava CIELOVU hrubku dielca —
          # katalogova hrubka sheetu ma prednost (cela 18/19 sa geometricky prisposobia
          # sheetu az v materialized_part, resolve_edges bezi skor).
          # V0.6 M-B1: pri UNI hrubku urcuje DIELEC (katalogova je len default
          # roly) + hardening M-B F6: 0.0 je truthy — nekladna katalogova
          # hrubka nesmie pickeru podhodit need=2 mm.
          uni_sheet = defined?(Materials) && Materials.uni?(sheet)
          part_th = abs_pick_thickness(sheet, pd[:prod][:thickness])
          picker_issues = abs_issues.nil? ? nil : []
          base_edges = if defined?(AbsRules)
                         AbsRules.resolve_edges(pd[:role], decor, part_th,
                                                sheet: sheet, collector: picker_issues)
                       else
                         empty_edges
                       end
          ov_edges = ov['edges'].is_a?(Hash) ? ov['edges'] : {}
          if picker_issues && !picker_issues.empty?
            picker_issues.each do |it|
              next if ov_edges.key?(it[:code]) # override vitazi — ziadny warning
              abs_issues << it.merge(part_key: part_key, name: pd[:name].to_s)
            end
          end
          # Codex GH #90 P1: sticky remapove dovody overridov (edge_warnings od
          # remap_part_edge_overrides!) — platia, kym hodnota hrany zodpoveda
          # zaznamu (uspesny fallback drzi svoje abs_id, stratena hrana nil);
          # uzivatelova zmena hrany zaznam zneplatni a TU sa aj uprace (prune
          # in-place — override hash ide do configu, upratanie prezije rebuild).
          ew = ov['edge_warnings']
          if ew.is_a?(Hash)
            ew.keys.each do |code|
              entry = ew[code]
              want = entry.is_a?(Hash) ? entry['abs_id'] : nil
              if ov_edges.key?(code) && ov_edges[code] == want
                abs_issues << { code: code, reason: entry['reason'].to_s,
                                part_key: part_key, name: pd[:name].to_s } if abs_issues
              else
                ew.delete(code)
              end
            end
            ov.delete('edge_warnings') if ew.empty?
          end
          edges = base_edges.merge(known_edges(ov_edges))
          grain = effective_grain(sheet, ov['grain_direction'])
          # V0.6 M-B1: UNI sheet_thickness sa NEexportuje (nil) — materialized_part
          # cela nepretvaruje na katalogovy default a vyrobny udaj drzi config.
          { part_key: part_key, role_key: part_key, material_id: mat_id, edges: edges,
            grain_direction: grain, sheet_thickness: (uni_sheet ? nil : (sheet && sheet['thickness'])),
            material_source: mat_source }
        end

        # K1 / D-108: JEDINA autorita EFEKTIVNEHO smeru dekoru dielca korpusu.
        # Retaz je `override -> material` a vysledok sa MATERIALIZUJE do snapshotu
        # dielca (add_part) — vystupy (kusovnik, VEPO, kontrola narezu, ABS) citaju
        # UZ LEN snapshot, nikdy zivy katalog ani `part_overrides`. Vdaka tomu drzi
        # odpojeny dielec aj stara zakazka presne to, s cim sa objednavala.
        #
        # ROTACIA SA TU NEROBI: rozmery v snapshote ostavaju GEOMETRICKE (pd[:prod]).
        # Vymenu dlzka<->sirka a dvojic hran robi VEPO (`VepoExport.oriented`) a
        # kontrola narezu (`Validation.fits_on_sheet?`) — presne ako doteraz. K1
        # meni JEDINE zdroj smeru, takze ziadny druhy swap nevznika.
        #
        # STALE OVERRIDE (kontrakt): ked material smer NEMA ('none' — napr. UNI
        # alebo jednofarebny dekor), override sa NEMAZE, len sa IGNORUJE (efekt
        # 'none'). Otacat kresbu, ktora neexistuje, by bola lož vo vyrobnych
        # datach; a mazanie by po docasnej zmene materialu zahodilo rozhodnutie
        # pouzivatela, ktore chcel mat spat.
        def effective_grain(sheet, override)
          base = sheet && sheet['grain'].to_s
          base = 'none' unless %w[length width none].include?(base)
          return base if base == 'none'
          ov = override.to_s
          GRAIN_OVERRIDES.include?(ov) ? ov : base
        end

        # D-41 (audit FIX 10) + D-102: JEDINA autorita hrubky, s ktorou sa pyta ABS
        # picker. Katalogova hrubka sheetu ma prednost pred hrubkou dielca (cela
        # 18/19 sa geometricky prisposobia sheetu az v materialized_part), UNI
        # material hrubku neurcuje (M-B1) a nekladna katalogova hrubka sa ignoruje
        # (M-B F6: 0.0 je truthy). Zdiela ju resolve_part aj karta dielca v paneli
        # — inak by panel ukazoval iny vysledok pravidla, nez postavi builder.
        def abs_pick_thickness(sheet, fallback_th)
          sheet_th = sheet && sheet['thickness'].to_f
          sheet_th = nil unless sheet_th && sheet_th.positive?
          uni = defined?(Materials) && Materials.uni?(sheet)
          (uni ? nil : sheet_th) || fallback_th
        end

        # 2B-1 (D-43): duplak vazba do snapshotu dielca. Ked katalog material
        # POZNA ako duplak, je autoritou (aktualne hodnoty vazby); inak sa
        # zachova vazba z predchadzajuceho snapshotu ROVNAKEHO materialu —
        # rebuild na stroji bez duplaku v katalogu (material mimo katalogu ALEBO
        # rovnake ID ako non-duplak — GH #94 P2 zrkadlo board cesty) nesmie
        # snapshot ticho zniciť (audit F8). Vazbu odstrani az vedoma zmena
        # materialu dielca (iny mat_id => legacy sa nepouzije).
        def material_source_for(mat_id, sheet, legacy)
          if defined?(Materials) && sheet && Materials.duplak?(sheet)
            return { 'material_id' => sheet['source_material_id'].to_s,
                     'multiplier' => sheet['source_multiplier'].to_i }
          end
          return nil unless legacy.is_a?(Hash) && legacy['material_id'].to_s == mat_id.to_s
          legacy['material_source']
        end

        # 2B-1 (audit F8): mapa part_key -> {material_id, material_source} zo
        # SUCASNYCH dielcov definicie (pred clear!). Cita sa LEN uplna vazba.
        def collect_part_sources(cdef)
          out = {}
          cdef.entities.grep(Sketchup::ComponentInstance).each do |e|
            next unless Store.kind(e) == 'part'
            cfg = Store.config(e)
            next unless cfg.is_a?(Hash)
            ms = cfg['material_source']
            next unless ms.is_a?(Hash) && !ms['material_id'].to_s.empty?
            key = Store.get(e, 'part_key').to_s
            next if key.empty?
            out[key] = { 'material_id' => cfg['material_id'].to_s, 'material_source' => ms }
          end
          out
        rescue StandardError => e
          Engine.log_error(e, 'collect_part_sources') if defined?(Engine)
          {}
        end

        # Katalogovy material s nespravnou hrubkou nesmie vytvorit rozpor medzi
        # geometriou a vyrobnymi datami. Legacy material mimo katalogu ponechavame.
        # Cela su specialny pripad: povolene varianty 18/19 mm upravia aj geometriu.
        def validate_material_thickness!(mat_id, sheet, pd)
          return unless mat_id && sheet
          # V0.6 M-B1: UNI je pracovny material — hrubku urcuje dielec, ziadny
          # drift sa nevynucuje (semafor hlasi ORANGE "material neurceny").
          return if defined?(Materials) && Materials.uni?(sheet)
          want = pd[:prod][:thickness].to_f
          have = sheet['thickness'].to_f
          return if thickness_ok_for?(pd[:role], want, have)
          # D-45: hlaska je posledna zachrana (bezne ju predbehnu panelove preflighty)
          # — pise sa v mm s ciarkou a NAVIGUJE, kde sa hrubka realne meni.
          raise "Materiál #{mat_id} má #{mm_txt(have)} mm, ale dielec #{pd[:suffix]} potrebuje #{mm_txt(want)} mm " \
                '— zmeň materiál celej skrinky (prevezme hrúbku) alebo hrúbku korpusu.'
        end

        # mm do hlasky (desatinna ciarka). Materials je jediny formatovac; bez neho
        # (teoreticky ciastocny load) sa pouzije surove cislo.
        def mm_txt(v)
          defined?(Materials) ? Materials.fmt_mm(v) : v.to_f.round(2).to_s
        end

        # Cela beru KATALOGOVU hrubku sveho materialu — geometriu, polohu pred
        # korpusom aj vyrobny udaj prepise materialized_part (D-45: 18,6 mm celo
        # je legitimne, natvrdo 18/19 bola pricina blokovaneho materialu). Hranicou
        # ostava rozumny rozsah doskoveho materialu; presna zhoda s konstrukcnou
        # hrubkou prejde vzdy (fallback pre nekatalogove/legacy hodnoty).
        # Ostatne dielce vyzaduju presnu zhodu s konstrukcnou hrubkou.
        def thickness_ok_for?(role, want, have)
          case role.to_s
          # KOV-A1: flap/false_front su cela ako kazde ine — beru katalogovu
          # hrubku sveho materialu (18 / 18,6 / 19 mm).
          when 'front_door', 'drawer_front', 'flap', 'false_front'
            thickness_in_range?(have) || (have - want).abs < 0.05
          # KOV-C2a: dielce zasuviek beru KATALOGOVU hrubku sveho materialu
          # rovnako ako cela — hrubka je VSTUP receptu, nie konstrukcna
          # konstanta korpusu. Ci je 18 mm pre Atiru pripustna, rozhoduje
          # `thickness_supported` receptu (conflict `drawer_thickness_unsupported`,
          # aktivuje C2b), nie tato funkcia. Roly drzi `DRAWER_ROLES` (guard test
          # ich porovnava s `DrawerRecipes::ROLE_*`).
          when *DRAWER_ROLES
            thickness_in_range?(have) || (have - want).abs < 0.05
          else
            (have - want).abs < 0.05
          end
        end

        # --- D-45: hrubka <-> material tela ---------------------------------
        # Deadlock „hrubka blokuje material, material blokuje hrubku" sa rozbija
        # dvoma smermi (oba pouzivaju TIETO ciste funkcie; Panel je len obalka):
        #   material -> hrubka: adopcia katalogovej hrubky (filozofia dosky)
        #   hrubka -> material: deterministicky auto-pick nahradneho materialu

        # Efektivne materialy korpusu po dedeni projekt->korpus (standard 7.2).
        # JEDINY zdroj pravdy — build_into aj Panel (remap, preflighty) citaju
        # toto. Params s string aj symbol klucmi (raw riesi oboje).
        def effective_materials(model, params)
          defaults = defined?(Materials) ? Materials.project_defaults(model) : {}
          {
            'body'  => present(raw(params, :material_id))       || defaults['default_material_id'],
            'front' => present(raw(params, :front_material_id)) || defaults['default_front_material_id'],
            'back'  => present(raw(params, :back_material_id))  || defaults['default_back_material_id'],
            # KOV-C2a: 4. kanal (dielce zasuviek). Uroven SKRINKY zatiaľ NEEXISTUJE
            # — config kluc pribudne v C2b spolu s bumpom `CONFIG_SCHEMA`, takze
            # tu sa vedome cita LEN projektova predvolba (s UNI 16 fallbackom).
            # Cita ju zatiaľ NIKTO: dielce zasuviek emituje az C2b.
            'drawer' => defaults['default_drawer_material_id']
          }
        end

        # Je hrubka v povolenom rozsahu korpusu (6–50 mm)? nil/necislo = nie.
        def thickness_in_range?(th)
          f = th.to_f
          return false unless f.finite? && f.positive?
          f >= THICKNESS_RANGE[0] - 0.001 && f <= THICKNESS_RANGE[1] + 0.001
        end

        # Zhoda hrubok v tolerancii dielca (rovnaka ako thickness_ok_for?).
        def thickness_eq?(a, b)
          (a.to_f - b.to_f).abs < 0.05
        end

        # D-45 (audit B6): DETERMINISTICKY vyber nahradnej dosky tela pre pozadovanu
        # hrubku `want`. `current` = katalogovy zaznam doterajsieho efektivneho
        # materialu (dekor + typ su kotva), `pool` = katalog dosiek.
        # Poradie: (a) rovnaky dekor A rovnaky typ (viac kandidatov = tie-break
        # material_id vzostupne), (b) PRAVE JEDEN kandidat rovnakeho typu,
        # (c) inak nic — volajuci odmietne zmenu a vypise kandidatov.
        # Vrati { pick: sheet|nil, candidates: [sheet...] } (kandidati = vsetky
        # dosky hladanej hrubky, zoradene material_id — zoznam do hlasky).
        # 2A-3 (audit F10): `schema` je PARAMETER (cista funkcia, ziadne
        # ambientne citanie katalogu — volajuci ju doda). Pri schema >= 2 su
        # kandidati LEN rovnaky group_id + rovnaka normalizovana NEPRAZDNA
        # struktura ako current; prazdna struktura = ZIADEN automaticky vyber;
        # bez zhody sa zmena odmietne (ziadny tichy skok na cudzi material).
        def pick_body_sheet(want, current, pool, schema: 1)
          w = want.to_f
          # V0.6 M-B1: skrinka NA UNI ostava na UNI pri kazdej hrubke — auto-pick
          # sa nespusta (UNI prijme lubovolnu hrubku; prepnut ju na realny
          # material smie len vedomy vyber, nie zmena hrubky).
          if defined?(Materials) && Materials.uni?(current)
            return { pick: current, candidates: [current] }
          end
          # GH P2: v tolerancii 0,05 moze byt viac roznych hrubok (18,56 vs 18,60) —
          # prve kriterium je NAJMENSI rozdiel od want, material_id je az tie-break.
          # V0.6 M-B1: UNI zaznamy NIE SU kandidati auto-picku (zmena hrubky
          # nesmie realny material ticho vymenit za pracovny).
          cands = Array(pool).select do |s|
            s.is_a?(Hash) && thickness_eq?(s['thickness'], w) &&
              !(defined?(Materials) && Materials.uni?(s))
          end.sort_by { |s| [(s['thickness'].to_f - w).abs, s['material_id'].to_s] }
          return { pick: nil, candidates: cands } if cands.empty?
          if defined?(Materials) && schema.to_i >= Materials::SCHEMA_GROUPS
            return { pick: pick_body_sheet_v2(cands, current), candidates: cands }
          end
          # GH P2: identita typu je case-insensitive (ako pri variantoch katalogu).
          type  = current ? current['type'].to_s.strip.upcase : ''
          decor = current ? current['decor'].to_s.strip.upcase : ''
          same_type = type.empty? ? [] : cands.select { |s| s['type'].to_s.strip.upcase == type }
          same_decor = decor.empty? ? [] : same_type.select { |s| s['decor'].to_s.strip.upcase == decor }
          pick = same_decor.first || (same_type.length == 1 ? same_type.first : nil)
          { pick: pick, candidates: cands }
        end

        # 2A-3 (audit F10): SCHEMA 2 vyber — tvrdy guard skupina + NEPRAZDNA
        # struktura; v ramci zhody preferencia rovnakeho typu, inak PRAVE JEDEN
        # kandidat (ziadny nahodny vyber). Vrati sheet alebo nil.
        def pick_body_sheet_v2(cands, current)
          return nil unless current.is_a?(Hash)
          st = Materials.identity_norm(current['structure'])
          return nil if st.empty? # prazdna struktura = neznama, ziadny auto vyber
          gk = Materials.record_group_key(current, Materials::SCHEMA_GROUPS)
          matches = cands.select do |s|
            Materials.record_group_key(s, Materials::SCHEMA_GROUPS) == gk &&
              Materials.identity_norm(s['structure']) == st
          end
          type = current['type'].to_s.strip.upcase
          same_type = matches.select { |s| s['type'].to_s.strip.upcase == type }
          same_type.first || (matches.length == 1 ? matches.first : nil)
        end

        # D-45/D-46: prevzatie KATALOGOVEJ hrubky materialu tela do params
        # (filozofia dosky). JEDINA implementacia — panel (adopt_body_thickness!)
        # aj projektova predvolba (classify_body_default_change) volaju TOTO;
        # hlasky si skladaju volajuci. params sa mutuju LEN pri :adopted.
        # Vrati [:same, nil] (netreba nic) / [:adopted, nil] /
        #       [:range, nil] (hrubka mimo 6–50) / [:blocked, [nazvy dielcov]].
        def adopt_thickness(params, sheet)
          # V0.6 M-B1: UNI material hrubku NIKDY nevnucuje — dielec/korpus si
          # drzi svoju (adopcia je no-op, D-46 ponuka sa nezobrazi).
          return [:same, nil] if defined?(Materials) && Materials.uni?(sheet)
          have = sheet.is_a?(Hash) ? sheet['thickness'].to_f : 0.0
          return [:same, nil] unless have.positive?
          old = params['thickness']
          return [:same, nil] if thickness_eq?(old, have)
          return [:range, nil] unless thickness_in_range?(have)
          params['thickness'] = have
          blocked = parts_blocking_thickness(params)
          unless blocked.empty?
            params['thickness'] = old # nic sa nemeni, kym konflikt trva
            return [:blocked, blocked]
          end
          [:adopted, nil]
        end

        # --- D-46: projektova predvolba TELA nad DEDIACIMI skrinkami ----------
        # Cista klasifikacia bez modelu a bez zapisu. TA ISTA funkcia stavia
        # dry-run ponuku aj finalne params davky — ponuka teda nemoze slubit nic
        # ine, nez apply spravi (audit F3).
        #
        # entries — [[cid, params, old_eff, ref], ...]; params su CERSTVE KOPIE
        #   (mutuju sa in-place: prevzata hrubka + preladene ABS overridy),
        #   old_eff = efektivne materialy skrinky PRED zmenou (dedenie este so
        #   STARYM defaultom), ref = referencia volajuceho (instancia) do jobs.
        # sheet / new_body_id — katalogovy zaznam a id NOVEHO materialu tela.
        #
        # params['material_id'] sa NIKDY nenastavuje — skrinka dalej DEDI.
        # Vrati { 'adopting' => [cid], 'recompute' => [cid],
        #         'blocked' => [[cid, :parts|:range, [nazvy dielcov]]],
        #         'jobs' => [[ref, params]], 'remap' => {'changed'=>n,'lost'=>[]} }
        def classify_body_default_change(entries, sheet, new_body_id)
          out = { 'adopting' => [], 'recompute' => [], 'blocked' => [], 'jobs' => [],
                  'remap' => { 'changed' => 0, 'lost' => [] } }
          Array(entries).each do |cid, params, old_eff, ref|
            id = cid.to_s
            state, blocked = adopt_thickness(params, sheet)
            if state == :blocked || state == :range
              out['blocked'] << [id, state == :blocked ? :parts : :range, Array(blocked)]
              next
            end
            (state == :adopted ? out['adopting'] : out['recompute']) << id
            eff = old_eff.is_a?(Hash) ? old_eff : {}
            # Dekor sa meni aj skrinkam, ktorym hrubka sedi — rucne ABS overridy
            # nasleduju material rovnako ako pri priamej zmene (D-41 FIX 5).
            remap = remap_part_edge_overrides!(params, eff, eff.merge('body' => new_body_id))
            out['remap']['changed'] += remap['changed'].to_i
            out['remap']['lost'].concat(Array(remap['lost']))
            out['jobs'] << [ref, params]
          end
          out
        end

        # D-45 (audit F8): dielce, ktore maju VLASTNY katalogovy material a ten by
        # pri aktualnych params (uz s novou hrubkou) hrubkovo nesedel. Nic sa
        # nemaze ani neprepisuje — volajuci zmenu ODMIETNE a dielce vymenuje.
        # Cela sem nespadnu (thickness_ok_for? im katalogovu hrubku povoluje).
        # Vrati pole mien dielcov (fallback part_key).
        def parts_blocking_thickness(params)
          ov = params.is_a?(Hash) ? params['part_overrides'] : nil
          return [] unless ov.is_a?(Hash) && !ov.empty? && defined?(Materials)
          return [] unless ov.any? { |_k, rec| rec.is_a?(Hash) && present(rec['material_id']) }
          parts = plan_parts_by_key(params)
          out = []
          ov.each do |rk, rec|
            next unless rec.is_a?(Hash)
            mid = present(rec['material_id'])
            next unless mid
            pd = parts[rk]
            next unless pd
            sheet = Materials.sheet(mid)
            next unless sheet # legacy material mimo katalogu sa nekontroluje
            next if Materials.uni?(sheet) # M-B1 F6: UNI override hrubku neblokuje
            next if thickness_ok_for?(pd[:role], pd[:prod][:thickness].to_f, sheet['thickness'].to_f)
            out << (pd[:name] || rk).to_s
          end
          out
        end

        # Base material dielca podla roly: cela -> front, chrbat -> back, ostatne -> body (korpus).
        # pd[:material] (:front/:korpus) z Construction je sekundarny signal (cela maju :front).
        def base_material_for(role, mat_sym, eff_body, eff_front, eff_back)
          case role.to_s
          when 'front_door', 'drawer_front', 'flap', 'false_front' then eff_front
          when 'back' then eff_back
          else mat_sym == :front ? eff_front : eff_body
          end
        end

        # --- D-41 PR C (audit FIX 5/7): centralne preladenie ABS overridov ------
        # Vola sa pri KAZDEJ zmene efektivneho materialu dielcov (material dielca,
        # material korpusu, projektova predvolba) PRED rebuildom. Pravidlove hrany
        # sa preladia samy (resolve_edges); toto riesi RUCNE overridy: paska
        # zladena so STARYM efektivnym dekorom nasleduje novy dekor, vedome
        # kontrastna/nil ostava.
        #
        # params      — NOVE params korpusu (part_overrides sa mutuju in-place)
        # old_eff/new_eff — {'body'=>id,'front'=>id,'back'=>id} efektivne materialy
        #   PRED/PO zmene (po dedeni projekt->korpus; audit FIX 7 — stary stav sa
        #   NEODVODZUJE z rec['material_id'], ale z base+override pred zmenou)
        # old_overrides — deep kopia overridov PRED zmenou (part material case);
        #   default = aktualne overridy (korpus/projekt case ich nemenia)
        # Vrati {'changed'=>pocet dielcov, 'lost'=>['Bok lavy L1', ...]}.
        def remap_part_edge_overrides!(params, old_eff, new_eff, old_overrides: nil)
          result = { 'changed' => 0, 'lost' => [] }
          ov = params['part_overrides']
          return result unless ov.is_a?(Hash) && !ov.empty? && defined?(Materials)
          # 2A-3 (audit F7): pri katalogu SCHEMA 2 ide remap so ZAZNAMAMI (stary
          # AJ novy sheet — skupina + struktura + universal); SCHEMA 1 = dnesny
          # textovy remap BEZ ZMENY.
          schema2 = Materials.catalog_schema >= Materials::SCHEMA_GROUPS
          old_ov = old_overrides.is_a?(Hash) ? old_overrides : ov
          parts = plan_parts_by_key(params)
          ov.each do |rk, rec|
            next unless rec.is_a?(Hash) && rec['edges'].is_a?(Hash)
            pd = parts[rk]
            next unless pd
            old_rec = old_ov[rk].is_a?(Hash) ? old_ov[rk] : {}
            old_mat = present(old_rec['material_id']) ||
                      base_material_for(pd[:role], pd[:material], old_eff['body'], old_eff['front'], old_eff['back'])
            new_mat = present(rec['material_id']) ||
                      base_material_for(pd[:role], pd[:material], new_eff['body'], new_eff['front'], new_eff['back'])
            new_sheet = Materials.sheet(new_mat)
            # Cielova hrubka: katalogova hrubka noveho sheetu (cela 18/19 sa jej
            # prisposobia — FIX 10), fallback konstrukcna hrubka dielca.
            # V0.6 M-B1: UNI cielova hrubka = hrubka DIELCA (katalogova je len
            # default roly, sirka pasky sa vybera podla realneho dielca).
            target = if new_sheet && !(defined?(Materials) && Materials.uni?(new_sheet))
                       new_sheet['thickness'].to_f
                     else
                       pd[:prod][:thickness].to_f
                     end
            target = target.positive? ? target : nil
            if schema2
              remapped, issues = Materials.remap_edges_v2(rec['edges'], Materials.sheet(old_mat),
                                                          new_sheet, target)
              lost = issues.reject { |n| n[:abs_id] }
                           .map { |n| "#{n[:code]}#{lost_suffix(n[:reason])}" }
            else
              remapped, lost = Materials.remap_edges(
                rec['edges'], Materials.decor_of(old_mat), new_sheet && new_sheet['decor'], target
              )
              issues = []
            end
            next unless remapped
            # GH #90 P2 (2. kolo): sticky zaznamy sa aktualizuju PER SPRACOVANA
            # hrana — nil hrany remap preskakuje a ich lost-warningy MUSIA
            # prezit (celoplosne delete by ich zahodilo, hoci hrana ostava
            # nevyriesena). Spracovana = mala hodnotu a zmenila sa / dostala issue.
            processed = rec['edges'].keys.select do |c|
              old_v = rec['edges'][c]
              !old_v.nil? && (remapped[c] != old_v || issues.any? { |n| n[:code] == c })
            end
            rec['edges'] = remapped
            ew = rec['edge_warnings'].is_a?(Hash) ? rec['edge_warnings'].dup : {}
            processed.each { |c| ew.delete(c) }
            issues.each do |n|
              ew[n[:code]] = { 'reason' => n[:reason].to_s, 'abs_id' => n[:abs_id] }
            end
            if ew.empty?
              rec.delete('edge_warnings')
            else
              rec['edge_warnings'] = ew
            end
            result['changed'] += 1
            lost.each { |code| result['lost'] << "#{pd[:name] || rk} #{code}" }
          end
          result
        end

        # 2A-3 (F8): dovetok k stratenej hrane v hlaske — kontrakt 0,4 vyzaduje
        # jasne "vyber rucne" (paska sa vedome NEnahradila automaticky).
        def lost_suffix(reason)
          return '' unless defined?(Materials)
          reason.to_s == Materials::REASON_ABS_04_MANUAL ? ' (0,4 mm — vyber ručne)' : ''
        end

        # Mapa part_key -> deskriptor dielca z planu (rola, hrubka, nazov).
        def plan_parts_by_key(params)
          cfg = normalize(params)
          Construction.build_plan(cfg)[:parts].each_with_object({}) do |pd, map|
            map[PartKeys.for_descriptor(pd)] = pd
          end
        rescue StandardError => e
          Engine.log_error(e, 'plan_parts_by_key') if defined?(Engine)
          {}
        end

        # V0.2c + D-06 fix: obmedzenie Scale uchopov na osove (X/Y/Z) cez DC "scaletool".
        # Zapisuje sa na instanciu AJ definiciu — SketchUp scale tool cita atribut
        # z DEFINICIE (dogfood pozorovanie: prvy Scale bez masky, druhy s nou).
        # Atribut NEovplyvnuje scale absorpciu (tá cita transformaciu, nie tento kluc).
        # D-40 (Codex audit F3): definicia PRVA (autorita pre Scale tool) a kazdy zapis
        # s vlastnym rescue — zlyhanie jedneho nesmie zhodit druhy.
        def apply_scale_lock(inst)
          return unless inst && inst.valid?
          d = inst.respond_to?(:definition) ? inst.definition : nil
          begin
            d.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s) if d && d.valid?
          rescue StandardError => e
            Engine.log_error(e, 'apply_scale_lock def') if defined?(Engine)
          end
          inst.set_attribute('dynamic_attributes', 'scaletool', SCALE_TOOL_MASK.to_s)
        rescue StandardError => e
          Engine.log_error(e, 'apply_scale_lock') if defined?(Engine)
          nil
        end

        # D-40: zamok v SAMOSTATNEJ TRANSPARENTNEJ operacii hned za vlozenim (prilepi
        # sa k nemu na undo stacku — 1x undo aj redo vrati oboje naraz). Overene
        # meranim (MCP bisekcia 21.7.2026): zapis dynamic_attributes v tej istej
        # operacii ako vznik definicie/instancie = mrtve selection eventy; zapis
        # v transparentnom follow-upe aj kopie/rebuildy existujucich entit = bezpecne.
        # POZOR (Codex audit B1): transparentnu operaciu NIKDY neabortovat — abort by
        # zrusil aj prilepene vlozenie (SketchUp API). Pri chybe sa commitne aj
        # ciastocny zapis; zamok dopise najblizsi rebuild (apply_scale_lock je
        # sucastou rebuild_in_operation).
        def apply_scale_lock_op(model, inst)
          return unless inst && inst.valid?
          return unless model.start_operation('NOXUN: Zamok scale', true, false, true)

          begin
            apply_scale_lock(inst)
          ensure
            model.commit_operation
          end
        end

        # --- pomocne stavbove ----------------------------------------------

        # Jeden dielec = vlastny komponent s NOXUN dict. Recyklacia definicie podla mena
        # (mena su per-korpus unikatne — obsahuju cid), aby rebuild neprodukoval osirotene definicie.
        # resolved: material, ABS, smer dekoru a katalogova hrubka (viz resolve_part).
        def add_part(model, parent_ents, pd, resolved, cid, tid)
          pd = materialized_part(pd, resolved)
          dname = "NOXUN #{cid} #{pd[:suffix]}"
          pdef = model.definitions[dname] || model.definitions.add(dname)
          pdef.entities.clear!
          sx, sy, sz = pd[:box]
          draw_box(pdef.entities, sx, sy, sz)
          ox, oy, oz = pd[:origin]
          inst = parent_ents.add_instance(pdef, Geom::Transformation.translation(Units.point(ox, oy, oz)))
          # SketchUp material z katalogu (nazov = material_id, farba z color) — vizual, nie vyrobna pravda.
          fallback = pd[:material] == :front ? FALLBACK_RGB_FRONT : FALLBACK_RGB_KORPUS
          inst.material = su_material(model, resolved[:material_id], fallback)
          # D-88: bocne plosky s vyriesenou ABS paskou dostanu farbu PASKY (velke
          # dekorove plochy ostavaju bez materialu = dedia material instancie).
          paint_edge_faces(model, pdef.entities, pd, resolved[:edges], resolved[:material_id])
          inst.layer = part_tag(model, pd[:role]) # tag dielca (Korpus/Chrbát/Čelá/Vnútro)
          pid = Ids.part_id(cid, pd[:suffix])
          # BuildPlan kontrakt: vyrobne zaradenie riadi DESKRIPTOR (default sheet/true/1) —
          # builder uz nic nenatvrdzuje; buduce 'counted'/'linear' dielce neprejdu ako doska.
          cfg_out = {
            length: pd[:prod][:length].round(2), width: pd[:prod][:width].round(2),
            thickness: pd[:prod][:thickness].round(2), quantity: pd.fetch(:quantity, 1),
            material_id: resolved[:material_id], grain_direction: resolved[:grain_direction] || 'none',
            edges: resolved[:edges]
          }
          # 2B-1 (D-43): duplak vazba je sucast VYROBNEHO snapshotu (standard 8.3)
          # — validacia bezi na materializovanom configu tesne pred zapisom
          # (audit F6: plan sa validuje pred resolve_part, tade vazba neprejde).
          if (ms = BuildPlan.validate_material_source!(resolved[:material_source], where: pd[:suffix].to_s))
            cfg_out[:material_source] = ms
          end
          Store.write(inst, {
            std: Store::STD, kind: 'part', id: pid, part_id: pid, cabinet_id: cid,
            template_id: tid, role: pd[:role], name: pd[:name],
            part_key_schema: PartKeys::SCHEMA, part_key: resolved[:part_key],
            role_key: resolved[:role_key], # kompatibilny alias pre sucasny panel
            manufactured: pd.fetch(:manufactured, true),
            production_class: pd.fetch(:production_class, 'sheet').to_s,
            config: cfg_out
          })
          inst
        end

        # --- vizual kovania (V0.4: zatial len nohy) --------------------------

        # Nakresli genericky vizual kategorii kovania s geometriou. PROXY kontrakt
        # (standard 6.3 + audit D6): zdroj pravdy supisu je config.hardware[] korpusu;
        # entita je len vizual — production_class 'none', manufactured false, aby ju
        # buduci kusovnik iterujuci entity NIKDY nezapocital (zavesy/vysuvy geometriu
        # nemaju vobec, cisla musia mat jeden domov).
        def render_hardware(model, parent_ents, hardware, cfg, cid)
          legs = Array(hardware).select { |h| h['generic_type'] == 'leg' }
          qty = legs.sum { |h| h['quantity'].to_i }
          return if qty < 1 || cfg[:floor_height].to_f <= 0

          dname = "NOXUN #{cid} LEGS"
          ldef = model.definitions[dname] || model.definitions.add(dname)
          ldef.entities.clear!
          draw_legs(ldef.entities, cfg, qty)
          inst = parent_ents.add_instance(ldef, Geom::Transformation.new)
          inst.layer = hardware_tag(model)
          Store.write(inst, {
            std: Store::STD, kind: 'hardware', id: "#{cid}-HW-LEG", part_id: "#{cid}-HW-LEG",
            cabinet_id: cid, role: 'leg',
            manufactured: false, production_class: 'none',
            config: { generic_type: 'leg', proxy: true, quantity: qty,
                      params: (legs.first ? legs.first['params'] : {}),
                      rule_id: (legs.first ? legs.first['rule_id'] : nil) }
          })
          inst
        rescue StandardError => e
          # Vizual nesmie zhodit rebuild — data (config.hardware) su uz ulozene.
          Engine.log_error(e, 'render_hardware') if defined?(Engine)
          nil
        end

        # Rozmiestnenie valcov pod dnom: 2 rady (predny/zadny) s odsadenim LEG_INSET;
        # plytky korpus / 1 ks -> 1 rad v strede hlbky. Predny rad berie prebytok
        # (ceil), rovnomerne po sirke. Kresli sa najviac LEG_RENDER_MAX valcov.
        def draw_legs(ents, cfg, qty)
          # D-37: nohy patria pod NOSNE dno (konstrukcna hlbka) — zadny rad nesmie
          # trcat pod nalozenym chrbtom (pri hrubke az 50 mm by visel vo vzduchu).
          w = cfg[:width]; d = Construction.carcass_depth(cfg); h = cfg[:floor_height]
          r = LEG_DIAMETER / 2.0
          count = [qty, LEG_RENDER_MAX].min
          # D-13/D-17 (Codex F4): pri prednom sokli predny rad noh posunut ZA dosku
          # sokla (recess + hrubka + polomer + vola) — proxy sa nesmie pretinat.
          front_y = LEG_INSET
          if cfg[:plinth_mode] == 'front'
            front_y = [front_y, cfg[:plinth_recess].to_f + cfg[:thickness].to_f + r + 5.0].max
          end
          two_rows = count > 1 && d > front_y + LEG_INSET + 2 * r
          rows =
            if two_rows
              front = (count / 2.0).ceil
              [[front_y, front], [d - LEG_INSET, count - front]].reject { |_, n| n < 1 }
            else
              [[d / 2.0, count]]
            end
          rows.each do |y, n|
            xs = leg_xs(w, n)
            xs.each { |x| draw_leg_cylinder(ents, x, y, r, h) }
          end
        end

        # X pozicie n noh v rade: 1 ks stred; inak rovnomerne od insetu po sirku-inset.
        def leg_xs(width, n)
          return [width / 2.0] if n == 1
          inset = [LEG_INSET, width / 2.0].min
          span = width - 2 * inset
          (0...n).map { |i| inset + span * i / (n - 1.0) }
        end

        def draw_leg_cylinder(ents, x, y, radius, height)
          edges = ents.add_circle(Units.point(x, y, 0), Geom::Vector3d.new(0, 0, 1),
                                  Units.mm(radius), LEG_SEGMENTS)
          face = ents.add_face(edges)
          return unless face
          face.reverse! if face.normal.z < 0
          face.pushpull(Units.mm(height))
        end

        def hardware_tag(model)
          model.layers[HARDWARE_TAG] || model.layers.add(HARDWARE_TAG)
        end

        # --- D-90: vizual uchytkoveho profilu na cele -----------------------
        #
        # PROXY kontrakt je ZHODNY s nohami (standard 6.3): kind 'hardware',
        # production_class 'none', manufactured false — zdroj pravdy supisu je
        # VYHRADNE config.hardware[] korpusu (pravidlo part_flag_length z PR 1),
        # geometria sa na cisla NIKDY nepyta.
        #
        # KOTVA (potvrdena Michalom 9.8. fotkou montaze):
        #   Y: zadna rovina profilu = zadna rovina cela (Y = 0), profil ide
        #      DOPREDU do Y = -depth; lico 18 mm cela tak presahuje o ~1,2 mm.
        #   Z: VRCH profilu = vrch POVODNEHO cela (vrch pasma = z + vyska riadku),
        #      profil siaha `height` nadol a spodnym „nosom" prekryva vrch
        #      skrateneho panelu o (height - reduction) = 1,419 mm — zamerne.
        #   X: dlzka rezu = sirka kridla (box[0]), zaciatok na origin[0].
        def render_front_profile(model, parent_ents, pd, cid)
          pl = profile_placement(pd)
          return nil unless pl

          pdef = profile_definition(model, pl)
          return nil unless pdef

          inst = parent_ents.add_instance(
            pdef, Geom::Transformation.translation(Units.point(pl[:x], 0.0, pl[:z_base]))
          )
          inst.material = ensure_material(model, PROFILE_MATERIAL, PROFILE_RGB)
          # D-116 (Michal 3.9.): tag VLASTNIKA, nie tag kovania. Uchytkovy profil
          # je zrasteny s celom — pri skryti tagu „Čelá" (pohlad dovnutra
          # skrinky) musi zmiznut S NIM, inak visi vo vzduchu. `pd[:role]` je
          # rola PANELU cela (front_door / drawer_front / flap / false_front) a
          # vsetky vedu cez PART_TAGS na „Noxun/Čelá"; profil vzniká LEN nad
          # celom (`profile_placement` inak vrati nil). VEDOMY DOSLEDOK: prepinac
          # tagu Kovanie uchytky uz neschova — patria k celu, nie k noham.
          # DATA proxy sa NEMENIA (kind hardware, role handle) — supis, nakup ani
          # dlzka rezu sa necitaju z tagu. Stare zakazky sa preznacia pri
          # najblizsej prestavbe (profil vzniká pri kazdom rebuilde nanovo).
          inst.layer = part_tag(model, pd[:role])
          hw_id = "#{cid}-HW-PROFILE-#{pd[:suffix]}"
          Store.write(inst, {
                        std: Store::STD, kind: 'hardware', id: hw_id, part_id: hw_id,
                        cabinet_id: cid, role: 'handle',
                        manufactured: false, production_class: 'none',
                        config: { generic_type: 'handle', proxy: true, quantity: 1,
                                  profile: pl[:profile], owner_part_key: pd[:part_key].to_s,
                                  params: { 'cut_length_mm' => pl[:length].round(2),
                                            'profile' => pl[:profile] } }
                      })
          inst
        rescue StandardError => e
          # Vizual NIKDY nezhodi rebuild — dielec aj data kovania uz stoja.
          Engine.log_error(e, 'render_front_profile') if defined?(Engine)
          nil
        end

        # Umiestnenie proxy z deskriptora dielca — CISTY vypocet bez SketchUp API
        # (kotva sa tak da overit headless). nil = dielec profil nema alebo je
        # zdegenerovany. z_base = spodok obrysu, z_top = vrch POVODNEHO cela.
        def profile_placement(pd)
          pid = FrontProfiles.of(pd)
          return nil unless pid
          band = pd[:profile_band]
          geo = FrontProfiles.geometry(pid)
          return nil unless band.is_a?(Hash) && geo

          length = quantize_profile_length(pd[:box][0])
          return nil unless length > BuildPlan::MIN_DIM

          z_top = band[:z].to_f + band[:h].to_f
          { profile: pid, geometry: geo, length: length, x: pd[:origin][0].to_f,
            z_top: z_top, z_base: z_top - geo[:height], depth: geo[:depth],
            def_name: profile_def_name(pid, length) }
        end

        # Meno definicie = (profil, dlzka). Dlzka je sucastou mena, takze rovnako
        # siroke kridla zdielaju jednu definiciu.
        # GH #145 P2: presnost MENA musi sedet s presnostou KRESLENEJ dlzky —
        # inak by dve dlzky, ktore sa zaokruhlia rovnako (296,500 a 296,504),
        # dostali to iste meno, ale rozny obsah, a druha stavba by prekreslila
        # zdielanu definiciu spatne aj vsetkym existujucim instanciam. Preto sa
        # dlzka KVANTUJE na PROFILE_LENGTH_STEP uz v profile_placement a meno,
        # odtlacok aj geometria pouzivaju TU ISTU hodnotu. Krok 0,01 mm je pod
        # toleranciou SketchUpu (0,0254 mm) — vizualne nerozoznatelny.
        def profile_def_name(pid, length)
          format('NOXUN_PROFILE_%s_L%.2f', pid.to_s.upcase, quantize_profile_length(length))
        end

        def quantize_profile_length(v)
          (v.to_f / PROFILE_LENGTH_STEP).round * PROFILE_LENGTH_STEP
        end

        # Definicia per (profil, dlzka) s recyklaciou podla mena — vzor dielcov.
        # Mena su GLOBALNE (nie per korpus): rovnako siroke kridla v celej zakazke
        # zdielaju jednu definiciu. Preto sa hotova definicia NEPREKRESLUJE nasilu;
        # prekresli sa len ked chyba, je prazdna alebo nesedi odtlacok geometrie
        # (zmena obrysu v novej verzii pluginu = PROFILE_GEOM_REV bump).
        def profile_definition(model, pl)
          dname = pl[:def_name]
          # Odtlacok drzi TU ISTU presnost ako meno (GH #145 P2) — zhodne meno
          # teda znamena zhodnu geometriu a definicia sa nikdy neprekresli „pod
          # rukami" instanciam ineho korpusu.
          stamp = "#{pl[:profile]}|#{PROFILE_GEOM_REV}|#{format('%.2f', pl[:length])}"
          pdef = model.definitions[dname]
          if pdef && pdef.entities.length.positive? &&
             pdef.get_attribute(PROFILE_DICT, 'geom').to_s == stamp
            return pdef
          end

          pdef ||= model.definitions.add(dname)
          pdef.entities.clear!
          face = draw_profile_section(pdef.entities, pl[:geometry], pl[:length])
          if face.nil?
            # Prierez sa nedal postavit (SketchUp odmietol face) — vizual odpada,
            # ale NIKDY ticho: dielec aj kovanie stoja, chyba patri do logu.
            Engine.log("profil #{pl[:profile]}: prierez sa nepodarilo postavit (#{dname})") if defined?(Engine)
            return nil
          end
          pdef.set_attribute(PROFILE_DICT, 'geom', stamp)
          pdef
        end

        # Prierez v rovine X=0 + pushpull po DLZKE do +X. Normala sa kontroluje
        # pred vytlacenim (rovnaky vzor ako draw_box/draw_leg_cylinder).
        # ORIENTACIA (D-90 fix, Michal 9.8.): v obryse je d=0 PREDNA strana
        # (nos), d=depth chrbat profilu — bod [d, v] -> [0, d - depth, v],
        # takze chrbat lici so zadnou rovinou cela (Y=0) a nos konci vpredu
        # na Y = -depth. Povodne mapovanie -d kreslilo profil zrkadlovo
        # (nos dozadu, ukazka realneho osadenia = foto v PR).
        def draw_profile_section(ents, geo, length)
          depth = geo[:depth].to_f
          pts = geo[:outline].map { |d, v| Units.point(0.0, d.to_f - depth, v.to_f) }
          face = ents.add_face(pts)
          return nil unless face
          face.reverse! if face.normal.x < 0
          face.pushpull(Units.mm(length))
          face
        end

        # Cela maju hrubku v osi Y. Ak katalog hovori 18/19 mm, upravime box,
        # polohu pred korpusom aj vyrobny udaj naraz.
        def materialized_part(pd, resolved)
          return pd unless %w[front_door drawer_front flap false_front].include?(pd[:role].to_s)
          th = resolved[:sheet_thickness].to_f
          return pd unless th.positive?

          out = pd.dup
          out[:box] = pd[:box].dup
          out[:origin] = pd[:origin].dup
          out[:prod] = pd[:prod].dup
          out[:box][1] = th
          out[:origin][1] = -th
          out[:prod][:thickness] = th
          out
        end

        # SketchUp vizualny material z katalogu (Materials). Fallback ak katalog nedostupny.
        def su_material(model, material_id, fallback_rgb)
          return Materials.ensure_su_material(model, material_id, fallback_rgb) if defined?(Materials)
          ensure_material(model, "NOXUN_#{material_id}", fallback_rgb)
        end

        def empty_edges
          { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
        end

        # Z override edges vezme len zname kluce (L1/L2/W1/W2); ZACHOVA aj nil (nil = "bez ABS"
        # explicitny override). Kluc chybajuci v override -> dedi z pravidla (base_edges).
        def known_edges(ov)
          out = {}
          return out unless ov.is_a?(Hash)
          %w[L1 L2 W1 W2].each { |k| out[k] = ov[k] if ov.key?(k) }
          out
        end

        # Belt-and-braces guard — degenerovane dielce filtruje uz plan (rovnaky prah
        # BuildPlan::MIN_DIM), sem sa dostat nemaju.
        def positive_box?(box)
          box && box.all? { |v| v.to_f > BuildPlan::MIN_DIM }
        end

        # Tag (layer) dielca podla roly — zabezpeci jeho existenciu. Hromadne hide v Tags paneli.
        def part_tag(model, role)
          name = PART_TAGS[role.to_s] || PART_TAG_DEFAULT
          model.layers[name] || model.layers.add(name)
        end

        # --- D-88: farba ABS pasky na bocnych plochach dielca ------------------
        #
        # Kontrakt mapovania hrana -> plocha je v core/part_faces.rb (osi nesie
        # deskriptor). Tu sa uz len VYSLEDOK resolve (resolved[:edges]) premieta
        # na plochy: hrana s paskou dostane material farby pasky, hrana bez pasky
        # (vedome nil, potlacene KOMPAKT/PD, ziadne pravidlo) ostava BEZ materialu
        # a dedi farbu dosky z instancie — presne ako doteraz.
        # Bezi VNUTRI existujuceho rebuildu (ziadna vlastna operacia, 1 undo) a
        # nikdy nezhodi stavbu: chyba sa zaloguje a dielec ostane jednofarebny.
        # Zdielane s BoardBuilder (doska ide tou istou cestou).
        def paint_edge_faces(model, ents, pd, edges, material_id)
          return unless edges.is_a?(Hash) && edges.any? { |_k, v| !v.nil? && !v.to_s.strip.empty? }
          return unless defined?(Materials)
          ax = PartFaces.verified_axes(pd)
          if ax.nil?
            Engine.log("D-88: dielec #{pd[:suffix]} nema overitelne osi — hrany sa nefarbia") if defined?(Engine)
            return
          end
          box = pd[:box]
          sheet_rgb = Materials.color_of(material_id)
          ents.grep(Sketchup::Face).each do |f|
            code = PartFaces.edge_code_for_center(face_center_mm(f), box, ax)
            next if code.nil?
            abs_id = edges[code]
            next if abs_id.nil? || abs_id.to_s.strip.empty?
            # Paska rovnakeho dekoru ako doska = ziadny vizualny rozdiel; material
            # sa vtedy vobec nevytvara (kniznica materialov modelu sa nezanasa).
            next if sheet_rgb && Materials.edge_color_of(abs_id) == sheet_rgb
            mat = Materials.ensure_su_edge_material(model, abs_id)
            next unless mat
            f.material = mat
            f.back_material = mat
          end
        rescue StandardError => e
          Engine.log_error(e, 'paint_edge_faces') if defined?(Engine)
          nil
        end

        # Stred plochy v mm lokalnych osiach definicie (geometria je v palcoch).
        def face_center_mm(face)
          c = face.bounds.center
          [Units.to_mm(c.x), Units.to_mm(c.y), Units.to_mm(c.z)]
        end

        # Box od (0,0,0) rozmerov sx,sy,sz (mm). Kontrola normaly pred pushpull.
        def draw_box(ents, sx, sy, sz)
          pts = [
            Units.point(0, 0, 0), Units.point(sx, 0, 0),
            Units.point(sx, sy, 0), Units.point(0, sy, 0)
          ]
          f = ents.add_face(pts)
          f.reverse! if f.normal.z < 0
          f.pushpull(Units.mm(sz))
          f
        end

        # --- config korpusu (standard sekcia 2.5) --------------------------

        def write_cabinet_attrs(inst, cid, cfg)
          Store.write(inst, {
            std: Store::STD, kind: 'cabinet', id: cid, cabinet_id: cid,
            template_id: template_id_for(cfg[:type]), role: 'cabinet', part_key_schema: PartKeys::SCHEMA,
            manufactured: false, production_class: 'reference',
            config: cabinet_config(cfg)
          })
          inst.name = "Korpus #{cid}"
          inst
        end

        def cabinet_config(cfg)
          {
            engine_version: Engine::VERSION,
            # R-12: marker kontraktu configu. Zapisuje sa VZDY a VZDY ako
            # AKTUALNA hodnota — `cabinet_config` je JEDINE miesto, kde config
            # korpusu vznika (build aj rebuild idu cez `write_cabinet_attrs`),
            # takze co je v modeli, to naozaj zodpoveda tomuto whitelistu.
            # Zamerne sa NEPREBERA z params: klientsky payload nie je autorita.
            config_schema: CONFIG_SCHEMA,
            part_key_schema: PartKeys::SCHEMA,
            plan_schema: cfg[:plan_schema] || BuildPlan::SCHEMA,
            warnings: cfg[:warnings].is_a?(Array) ? cfg[:warnings] : [],
            hardware: cfg[:hardware].is_a?(Array) ? cfg[:hardware] : [],
            type: cfg[:type],
            # D-100: uklada sa LEN rucny nazov (nil = zivy default z display_name).
            # Zapecenim defaultu by nazov prestal sledovat sirku/typ skrinky.
            name: manual_name(cfg),
            construction_preset: cfg[:type] == 'upper' ? 'noxun-upper-18' : 'noxun-lower-18',
            mode: 'parametric',
            width: cfg[:width], height: cfg[:height], depth: cfg[:depth],
            thickness: cfg[:thickness], floor_height: cfg[:floor_height],
            # ploche variant kluce = zdroj pravdy pre round-trip panela
            bottom_mode: cfg[:bottom_mode], top_mode: cfg[:top_mode], back_mode: cfg[:back_mode],
            back_thickness: cfg[:back_thickness],
            plinth_mode: cfg[:plinth_mode], plinth_recess: cfg[:plinth_recess],
            rail_depth: cfg[:rail_depth], rails_orientation: cfg[:rails_orientation],
            rails_top_offset: cfg[:rails_top_offset],
            # vnorene standardne objekty (odvodene)
            sides:   { thickness: cfg[:thickness], construction: 'sides_wrap' },
            bottom:  { mode: cfg[:bottom_mode], thickness: cfg[:thickness] },
            top:     { mode: cfg[:top_mode], thickness: cfg[:thickness],
                       rail_depth: cfg[:rail_depth], orientation: cfg[:rails_orientation],
                       top_offset: cfg[:rails_top_offset] },
            back:    { mode: cfg[:back_mode], thickness: cfg[:back_thickness] },
            support: support_descriptor(cfg),
            # V0.3 materialy — korpusove (nil = dedi z projektoveho defaultu, standard 7.2)
            # + part_overrides (per-dielec material/hrany, kluc = part_key, prezije rebuild).
            material_id: cfg[:material_id],
            front_material_id: cfg[:front_material_id],
            back_material_id: cfg[:back_material_id],
            part_overrides: cfg[:part_overrides].is_a?(Hash) ? cfg[:part_overrides] : {},
            hardware_overrides: cfg[:hardware_overrides].is_a?(Array) ? cfg[:hardware_overrides] : [],
            hardware_sets: cfg[:hardware_sets].is_a?(Hash) ? cfg[:hardware_sets] : {},
            # KOV-H1: ad-hoc polozky kovania (pole; prazdne = skrinka ziadne nema)
            hardware_manual: cfg[:hardware_manual].is_a?(Array) ? cfg[:hardware_manual] : [],
            available_width: cfg[:available_width],
            available_height: cfg[:available_height],
            available_depth: cfg[:available_depth],
            front_plane: cfg[:front_plane] || 0.0,
            wings: cfg[:wings],
            # V0.2b: strom zon (strukturny zdroj pravdy) + ploche zony (cache) + cela
            zone_tree: cfg[:zone_tree],
            zones: cfg[:zones],
            fronts: cfg[:fronts],
            front_items: cfg[:front_items]
          }
        end

        # Typ podopretia urcuje Construction.support_type (1 zdroj pravdy — citaju ho
        # aj pravidla kovania); tu sa len oblieka do config deskriptora.
        def support_descriptor(cfg)
          case Construction.support_type(cfg)
          when 'none'   then { type: 'none', height: 0.0 }
          when 'plinth' then { type: 'plinth', height: cfg[:floor_height], recess: cfg[:plinth_recess] }
          else               { type: 'legs', height: cfg[:floor_height] }
          end
        end

        # --- D-100: nazov skrinky -------------------------------------------
        # Automaticky nazov sa NEUKLADA — dopocitava sa zo SUCASNYCH parametrov,
        # takze zmena sirky ho opravi sama ("Spodna skrinka 700" pri sirke 900
        # bola trvala lez). Ulozeny je len RUCNY nazov (display_name ho vzdy
        # uprednostni). Vsetky metody citaju cfg s lubovolnym typom kluca —
        # volaju sa aj nad Store.config (stringy) aj nad normalize (symboly).

        def display_name(cfg)
          manual_name(cfg) || default_name(cfg)
        end

        # Ocisteny RUCNY nazov z configu, alebo nil (prazdny / automaticky vzor).
        def manual_name(cfg)
          sanitize_name(cfg.is_a?(Hash) ? raw(cfg, :name) : nil)
        end

        # JEDINA autorita ocistenia nazvu (callback panela ju vola pred zapisom).
        # nil = "bez rucneho nazvu" (= vrat sa na zivy default).
        def sanitize_name(value)
          s = value.to_s.gsub(/\s+/, ' ').strip
          s = nfc(s)
          s = s[0, NAME_MAX_LEN].to_s.strip
          return nil if s.empty? || auto_name?(s)

          s
        end

        def auto_name?(value)
          !(AUTO_NAME_RE =~ nfc(value.to_s.gsub(/\s+/, ' ').strip)).nil?
        end

        # Rozlozena diakritika (macOS/kopirovanie z webu) by vzor minula.
        def nfc(str)
          str.unicode_normalize(:nfc)
        rescue StandardError
          str
        end

        def default_name(cfg)
          w = (cfg.is_a?(Hash) ? raw(cfg, :width) : nil).to_f.round
          type = (cfg.is_a?(Hash) ? raw(cfg, :type) : nil).to_s
          type == 'upper' ? "Horná skrinka #{w}" : "Spodná skrinka #{w}"
        end

        def template_id_for(type)
          type == 'upper' ? 'base-upper-18' : 'base-lower-18'
        end

        def merge_final(cfg, plan)
          cfg.merge(
            plan_schema: plan[:schema],     # verzia tvaru planu (nezavisla od part_key_schema)
            warnings: plan[:warnings],      # nefatalne upozornenia — panel/vystupy ich zobrazia
            hardware: plan[:hardware],      # kovanie (V0.4+); tvar uz zavazny
            available_width: plan[:available][:width].round(2),
            available_height: plan[:available][:height].round(2),
            available_depth: plan[:available][:depth].round(2),
            front_plane: 0.0,
            wings: plan[:wings],
            zones: plan[:zones],
            zone_tree: plan[:zone_tree],
            front_items: plan[:front_items]
          )
        end

        # --- normalizacia parametrov ---------------------------------------

        def defaults_for(type)
          type == 'upper' ? UPPER_DEFAULTS : LOWER_DEFAULTS
        end

        def normalize(params)
          p = params || {}
          type = norm_type(p)
          d = defaults_for(type)
          fronts_cfg = Fronts.normalize_config(raw(p, :fronts))
          {
            type: type,
            width:  clampf(fetchf(p, :width,  d[:width]),  MIN[:width],  3000.0),
            height: clampf(fetchf(p, :height, d[:height]), MIN[:height], 3000.0),
            depth:  clampf(fetchf(p, :depth,  d[:depth]),  MIN[:depth],  2000.0),
            thickness: clampf(fetchf(p, :thickness, d[:thickness]), *THICKNESS_RANGE),
            floor_height: type == 'upper' ? 0.0 : clampf(fetchf(p, :floor_height, d[:floor_height]), 0.0, 500.0),
            bottom_mode: enum_val(p, :bottom_mode, %w[between_sides under_sides], d[:bottom_mode]),
            top_mode:    enum_val(p, :top_mode,    %w[full two_rails none],       d[:top_mode]),
            back_mode:   enum_val(p, :back_mode,   %w[overlay inset groove none], d[:back_mode]), # D-31: + none
            # hrubka chrbta ako Float mm (3 HDF / 18 pevny / ine); clamp 1..50
            back_thickness: clampf(fetchf(p, :back_thickness, d[:back_thickness]), 1.0, 50.0),
            plinth_mode: type == 'upper' ? 'none' : enum_val(p, :plinth_mode, %w[none front], d[:plinth_mode]),
            plinth_recess: clampf(fetchf(p, :plinth_recess, d[:plinth_recess]), 0.0, 300.0),
            # two_rails parametre (uplatnia sa len pri top_mode == 'two_rails')
            rail_depth: clampf(fetchf(p, :rail_depth, d[:rail_depth]), 20.0, 400.0),
            rails_orientation: enum_val(p, :rails_orientation, %w[flat upright], d[:rails_orientation]),
            rails_top_offset: clampf(fetchf(p, :rails_top_offset, d[:rails_top_offset]), 0.0, 500.0),
            # V0.2b: strom zon (police su per-zona) + cela (fixed/auto s lockmi)
            zone_tree: norm_zone_tree(p),
            fronts: fronts_cfg,
            # V0.3: korpusove materialy (nil = dedi z projektu) + part_overrides (per-dielec)
            material_id: present(raw(p, :material_id)),
            front_material_id: present(raw(p, :front_material_id)),
            back_material_id: present(raw(p, :back_material_id)),
            part_overrides: norm_overrides(raw(p, :part_overrides)),
            # V0.4 kovanie: rucne zasahy do poctov (pravidlo = default, override vitazi)
            hardware_overrides: prune_profile_overrides(
              prune_none_front_overrides(
                norm_hardware_overrides(raw(p, :hardware_overrides)), fronts_cfg
              ), fronts_cfg
            ),
            # V0.6 D1 (audit B1): cabinet override setov kovania — mapa
            # {generic_type => set_id}; bez round-tripu by ju rebuild zmazal.
            hardware_sets: norm_hardware_sets(raw(p, :hardware_sets)),
            # KOV-H1: ad-hoc polozky kovania mimo setov. CITACIA cesta
            # (`strict_owners: false`) — kluc vlastnika sa NIKDY nezahadzuje,
            # striktnu kontrolu robi panelova ADD/EDIT cesta PRED rebuildom.
            hardware_manual: norm_hardware_manual(raw(p, :hardware_manual)),
            part_key_schema: raw(p, :part_key_schema).to_i,
            # D-100: nazov prechadza cez JEDINU ocistovaciu cestu — stary
            # zapeceny default (aj bez diakritiky) sa tu zmeni na nil a skrinka
            # sa pri najblizsej prestavbe vrati na zivy nazov.
            name: sanitize_name(raw(p, :name))
          }
        end

        # Ocisti part_overrides na { part_key => { 'material_id'=>..|nil,
        # 'edges'=>{L1..W2}, 'grain_direction'=>'length'|'width' } }.
        # Zahodi prazdne / neplatne zaznamy. Zachova nil hrany (explicitne "bez ABS").
        def norm_overrides(raw_ov)
          return {} unless raw_ov.is_a?(Hash)
          out = {}
          raw_ov.each do |key, ov|
            next unless ov.is_a?(Hash)
            rec = {}
            mat = present(ov['material_id'] || ov[:material_id])
            rec['material_id'] = mat if mat
            # K1 / D-108: smer dekoru dielca. WHITELIST — do configu sa dostane
            # LEN 'length'/'width'; cokolvek ine (aj 'none' a hodnota z novsej
            # verzie) vypadne, aby sa neznamy vstup NIKDY nepreklopil na tichy
            # fallback vo vyrobnych datach. Chybajuci kluc = dedi z materialu.
            grain = (ov['grain_direction'] || ov[:grain_direction]).to_s
            rec['grain_direction'] = grain if GRAIN_OVERRIDES.include?(grain)
            edges = ov['edges'] || ov[:edges]
            if edges.is_a?(Hash)
              e = {}
              %w[L1 L2 W1 W2].each do |k|
                next unless edges.key?(k) || edges.key?(k.to_sym)
                v = edges.key?(k) ? edges[k] : edges[k.to_sym]
                v = present(v)
                v = Materials.normalized_abs_id(v) if v && defined?(Materials)
                e[k] = v # nil (bez ABS) alebo podporovane abs_id
              end
              rec['edges'] = e unless e.empty?
            end
            # Codex GH #90 P1: sticky remapove dovody (remap_part_edge_overrides!)
            # musia prezit normalize round-trip — bez passthrough by ich kazdy
            # rebuild zahodil. Sanitizacia: zname hrany, neprazdny reason,
            # abs_id string alebo nil (lost).
            ew = ov['edge_warnings'] || ov[:edge_warnings]
            if ew.is_a?(Hash)
              w = {}
              %w[L1 L2 W1 W2].each do |k|
                entry = ew[k] || ew[k.to_sym]
                next unless entry.is_a?(Hash)
                reason = (entry['reason'] || entry[:reason]).to_s
                next if reason.empty?
                w[k] = { 'reason' => reason,
                         'abs_id' => present(entry['abs_id'] || entry[:abs_id]) }
              end
              rec['edge_warnings'] = w unless w.empty?
            end
            out[key.to_s] = rec unless rec.empty?
          end
          out
        end

        # Ocisti hardware_overrides na pole { owner_part_key(nil|String), generic_type,
        # rule_id, quantity(1..MAX)? | disabled(true)? }. Identita = (owner, type, rule_id);
        # duplicitny zaznam -> POSLEDNY vyhrava (deduplikovane uz tu, config je cisty).
        # Zaznam bez quantity aj bez disabled je bezobsazny -> zahodi sa.
        # D1 (audit B1): cabinet override setov kovania. Kluc = 'generic_type'
        # alebo 'generic_type@owner_part_key' (H1a — vyber na urovni dielca),
        # hodnota = set_id alebo selector podla parametra. JEDINY parser tvaru
        # je HardwareSets.parse_mapping (audit BLOCKER 2); tu je CITACIA cesta,
        # takze neplatna polozka vypadne s logom (rebuild nikdy nespadne na
        # cudzom/legacy configu). Ze snapshot definiciu setu NESIE, gardi
        # zapisova cesta HardwareSets (audit B2), nie builder.
        def norm_hardware_sets(raw_map)
          return {} unless raw_map.is_a?(Hash)
          HardwareSets.normalize_mapping(raw_map, nil, allow_owner: true)
        end

        # D-93 (audit B2): polia zaznamu su NEZAVISLE — 'disabled' uz NESMIE
        # zahodit quantity ani nominal_length (zmena jedneho pola by inak ticho
        # zmazala ostatne rucne zasahy tej istej identity). Zaznam bez jedineho
        # obsahoveho pola je bezobsazny -> zahodi sa.
        def norm_hardware_overrides(raw_ov)
          return [] unless raw_ov.is_a?(Array)
          out = {}
          raw_ov.each do |ov|
            next unless ov.is_a?(Hash)
            owner = present(ov['owner_part_key'] || ov[:owner_part_key])
            next if owner && !PartKeys.valid?(owner)
            gt = (ov['generic_type'] || ov[:generic_type]).to_s.strip
            next unless BuildPlan::GENERIC_TYPES.include?(gt)
            rid = (ov['rule_id'] || ov[:rule_id]).to_s.strip
            next if rid.empty?

            rec = { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid }
            rec['disabled'] = true if truthy_flag(ov['disabled'] || ov[:disabled])
            q = (ov['quantity'] || ov[:quantity])
            qi = q.to_s.strip.empty? ? nil : q.to_i
            rec['quantity'] = [qi, BuildPlan::MAX_HW_QUANTITY].min if qi && qi >= 1
            # NL: JEDINA autorita tvaru je HardwareRules.override_nl (strict Float).
            nl = HardwareRules.override_nl(ov['nominal_length'] || ov[:nominal_length])
            rec['nominal_length'] = nl if nl
            next unless rec.key?('disabled') || rec.key?('quantity') || rec.key?('nominal_length')
            out[[owner, gt, rid]] = rec
          end
          out.values
        end

        # --- KOV-H1: ad-hoc kovanie -----------------------------------------
        #
        # Ocisti `hardware_manual` na pole poloziek s UZAVRETYM whitelistom
        # (`MANUAL_KEYS`). Polozka je „konkretne kovanie mimo setov" viazana na
        # skrinku (`owner_part_key` nil) alebo na KONKRETNY dielec.
        #
        # DVA REZIMY (audit #15 BLOCKER 4):
        #   `strict_owners: false` (default) = CITACIA cesta — rebuild, kopia,
        #     legacy config. Neplatna polozka VYPADNE s logom, kluc vlastnika sa
        #     NIKDY nezahadzuje (dielec mohol zaniknut; `Bom.collect` to prizna
        #     ako `owner_missing` a Validation da ORANGE, polozka ostava v nakupe).
        #   `strict_owners: true` = ZAPISOVA cesta z panela (ADD/EDIT). Vlastnik
        #     MUSI existovat v `plan_keys` a katalogovy kod MUSI byt v katalogu;
        #     inak sa ODMIETA CELA ZMENA (`ManualRejected`) — ziadny tichy drop.
        #
        # `strict_ids` (review #283 P2-A) ZUZUJE prisnost na KONKRETNE zaznamy.
        # Panel posiela v kazdom `collectAll()` CELY ulozeny zoznam (je to echo,
        # nie diff), takze bez tohto by sa NEZMENENE polozky validovali, akoby ich
        # pouzivatel prave pridal: po zmazani kodu z katalogu by sa odmietla kazda
        # dalsia editacia skrinky a zmazanie cela-vlastnika by neprelo vobec —
        # namiesto toho, aby polozka prezila ako `owner_missing` (BLOCKER 4).
        #   nil  = prisne sa kontroluje VSETKO (legacy volanie / „vsetko je nove")
        #   pole = prisne LEN tieto ID + kazdy zaznam BEZ ID (ten nemoze byt
        #          nezmenene echo — ulozene zaznamy ID vzdy maju)
        # Ktore ID to su, pocita cista `manual_strict_subset(stored, submitted)`.
        #
        # CENY (audit #15 BLOCKER 2): katalogova polozka cenu NEUKLADA NIKDY —
        # oceni ju ZIVY katalog pri expanzii ako kazdy iny riadok. V configu
        # ostava len `code` + snapshot `name`/`unit` pre pripad, ze kod
        # z katalogu zmizne. Cenu nesie VYHRADNE volna polozka.
        def norm_hardware_manual(raw, strict_owners: false, strict_ids: nil, plan_keys: nil)
          return [] unless raw.is_a?(Array)

          keys = plan_keys.nil? ? nil : Array(plan_keys).map(&:to_s)
          ids = strict_ids.nil? ? nil : Array(strict_ids).map(&:to_s)
          seen = {}
          raw.filter_map do |it|
            rec = manual_item(it, strict_owners && manual_strict?(it, ids), keys)
            next nil if rec.nil?

            # ID doplna normalize LEN ked chyba alebo koliduje; PRVY vyskyt si
            # svoje vzdy nechava (FIX 10 — prestavba nesmie prekluckovat ID).
            id = rec['id'].to_s
            id = '' if id.empty? || seen[id]
            rec['id'] = id.empty? ? next_manual_id(seen) : id
            seen[rec['id']] = true
            rec
          end
        end

        # KOV-H1 (audit #15 FIX 10): NOVE ID pre VSETKY ad-hoc polozky. Vola sa
        # VYHRADNE tam, kde z existujucej skrinky vznika NOVA (dedup kopii,
        # „Vlozit kopiu") — NIKDY z `normalize`/rebuildu. Prijima config aj
        # params (string aj symbolovy kluc); vstup MENI a vracia ho.
        def rekey_hardware_manual(cfg_or_params)
          return cfg_or_params unless cfg_or_params.is_a?(Hash)

          key = cfg_or_params.key?('hardware_manual') ? 'hardware_manual' : :hardware_manual
          list = cfg_or_params[key]
          return cfg_or_params unless list.is_a?(Array)

          seen = {}
          cfg_or_params[key] = list.map do |it|
            next it unless it.is_a?(Hash)

            copy = it.dup
            copy['id'] = next_manual_id(seen)
            seen[copy['id']] = true
            copy
          end
          cfg_or_params
        end

        # KOV-H1 (review #283 P2-A): ID zaznamov, ktore sa musia kontrolovat
        # PRISNE — teda NOVYCH a REALNE ZMENENYCH oproti ULOZENEMU zoznamu.
        # CISTA funkcia (ziadny model, ziadny katalog) — headless testovatelna.
        #
        # `stored`    = `config['hardware_manual']` PRED zmenou
        # `submitted` = surove pole z panela (echo celeho zoznamu + zmeny)
        #
        # Zaznam BEZ ID sa do zoznamu nedava — prisny je uz z definicie
        # (`manual_strict?`). Duplicitne ID v odoslanom zozname su prisne VZDY:
        # druhy taky zaznam je realne NOVA polozka (normalize mu prideli nove ID),
        # aj keby sa obsahom trafil do ulozeneho.
        def manual_strict_subset(stored, submitted)
          old = {}
          Array(stored).each do |rec|
            next unless rec.is_a?(Hash)

            id = manual_id(rec)
            old[id] = manual_fingerprint(rec) unless id.empty?
          end
          counts = Hash.new(0)
          Array(submitted).each do |rec|
            counts[manual_id(rec)] += 1 if rec.is_a?(Hash)
          end
          out = []
          Array(submitted).each do |rec|
            next unless rec.is_a?(Hash)

            id = manual_id(rec)
            next if id.empty?

            same = counts[id] == 1 && old.key?(id) && old[id] == manual_fingerprint(rec)
            out << id unless same
          end
          out.uniq
        end

        # Odtlacok OBSAHU polozky pre porovnanie „zmenila sa?".
        # `name`/`unit` KATALOGOVEJ polozky sa ZAMERNE NEPOROVNAVAJU: vlastni ich
        # SERVER (dopĺňa ich z katalogu podla kodu), takze premenovanie polozky
        # v katalogu by z kazdej nezmenenej polozky spravilo „upravenu" a zablokovalo
        # by dalsiu editaciu skrinky. Pri VOLNEJ polozke su to naopak udaje
        # POUZIVATELA — ich zmena JE editacia a kontroluje sa prisne.
        # Porovnava sa NORMALIZOVANA hodnota (nie surova), aby „2" a 2 neboli zmena.
        def manual_fingerprint(rec)
          src = mraw(rec, 'source').to_s.strip
          out = { 'owner' => present(mraw(rec, 'owner_part_key')), 'source' => src,
                  'code' => mraw(rec, 'code').to_s.strip,
                  'qty' => manual_qty(mraw(rec, 'qty')),
                  'price' => manual_price(rec)[0],
                  'note' => manual_note(mraw(rec, 'note')) }
          if src == 'free'
            out['name'] = mraw(rec, 'name').to_s.strip
            out['unit'] = manual_unit(mraw(rec, 'unit'))
          end
          out
        end

        # Ma sa TENTO zaznam kontrolovat prisne? `ids` nil = cely zoznam.
        def manual_strict?(raw, ids)
          return true if ids.nil?
          return true unless raw.is_a?(Hash)

          id = manual_id(raw)
          id.empty? || ids.include?(id)
        end

        # Jedna polozka -> ocisteny zaznam alebo nil (citacia cesta).
        # V strict rezime kazde odmietnutie VYHODI `ManualRejected`.
        def manual_item(raw, strict, plan_keys)
          return nil unless raw.is_a?(Hash)

          src = mraw(raw, 'source').to_s.strip
          return manual_drop(strict, 'ručná položka kovania má neznámy zdroj') unless MANUAL_SOURCES.include?(src)

          qty = manual_qty(mraw(raw, 'qty'))
          return manual_drop(strict, "množstvo ručnej položky musí byť celé číslo 1–#{MANUAL_QTY_MAX}") if qty.nil?

          owner = manual_owner(raw, strict, plan_keys)
          return nil if owner == :drop

          rec = { 'id' => manual_id(raw), 'owner_part_key' => owner, 'source' => src,
                  'qty' => qty, 'note' => manual_note(mraw(raw, 'note')) }
          src == 'catalog' ? manual_catalog(rec, raw, strict) : manual_free(rec, raw, strict)
        end

        # `catalog`: klientovi sa veri LEN kod (audit #15 FIX 12). Nazov a MJ
        # dopĺňa SERVER z katalogu; ked kod v katalogu nie je, pri ADD/EDIT sa
        # polozka odmieta (pouzi volnu), pri rebuilde ostava SNAPSHOT z configu,
        # aby polozka po zmazani kodu z katalogu nezmizla z objednavky.
        def manual_catalog(rec, raw, strict)
          code = mraw(raw, 'code').to_s.strip
          return manual_drop(strict, 'katalógová ručná položka nemá kód') if code.empty?

          rec['code'] = code
          item = defined?(HardwareCatalog) ? HardwareCatalog.find(code) : nil
          if item.is_a?(Hash)
            rec['name'] = item['name_sk'].to_s
            rec['unit'] = item['unit'].to_s
            return rec
          end
          if strict
            return manual_drop(true, "kód „#{code}“ nie je v katalógu kovania — pridaj ho ako voľnú položku")
          end

          rec['name'] = mraw(raw, 'name').to_s.strip
          unit = manual_unit(mraw(raw, 'unit'))
          return manual_drop(false, "ručná položka „#{code}“ má neplatnú mernú jednotku") if unit.nil?

          rec['unit'] = unit
          rec # cena sa pri katalogovej polozke NEUKLADA NIKDY (BLOCKER 2)
        end

        # `free`: nazov je povinny, MJ z `HardwareCatalog::UNITS`, cena Float
        # >= 0 konecna alebo nil („bez ceny"). Kod je VZDY prazdny — volna
        # polozka sa nesmie tvarit ako katalogovy kod (zliala by sa s nim).
        def manual_free(rec, raw, strict)
          name = mraw(raw, 'name').to_s.strip
          return manual_drop(strict, 'voľná ručná položka nemá názov') if name.empty?

          unit = manual_unit(mraw(raw, 'unit'))
          return manual_drop(strict, "voľná položka „#{name}“ má neplatnú mernú jednotku") if unit.nil?

          price, ok = manual_price(raw)
          return manual_drop(strict, "cena položky „#{name}“ musí byť nezáporné číslo") unless ok

          rec['code'] = ''
          rec['name'] = name
          rec['unit'] = unit
          rec['price_eur_vat'] = price unless price.nil?
          rec
        end

        # Vlastnik: nil (skrinka) alebo SYNTAKTICKY platny part_key. Pri ADD/EDIT
        # musi kluc existovat v aktualnom plane (audit #15 BLOCKER 4) — inak by
        # sa dala polozka zavesit na dielec, ktory nikdy neexistoval. Rebuild
        # kluc NIKDY nezahadzuje. -> nil | String | :drop
        def manual_owner(raw, strict, plan_keys)
          owner = present(mraw(raw, 'owner_part_key'))
          return nil if owner.nil?

          unless PartKeys.valid?(owner)
            manual_drop(strict, "ručná položka má neplatný kľúč dielca „#{owner}“")
            return :drop
          end
          if strict && !plan_keys.nil? && !plan_keys.include?(owner)
            manual_drop(true, "dielec „#{owner}“ v skrinke neexistuje — ručná položka sa nedá pripnúť")
          end
          owner
        end

        # Mnozstvo: CELE cislo 1..999. Desatinne cislo ani text neprejdu —
        # „2,5 kusa" je vzdy chyba vstupu, nie hodnota na zaokruhlenie.
        def manual_qty(raw)
          q = case raw
              when Integer then raw
              when Float   then (raw.finite? && (raw % 1).zero?) ? raw.to_i : nil
              when String  then (raw.strip.match?(/\A\d+\z/) ? raw.strip.to_i : nil)
              end
          return nil if q.nil? || q < 1 || q > MANUAL_QTY_MAX

          q
        end

        # MJ ide cez JEDINU autoritu (`HardwareCatalog.canonical_unit`) — MJ mimo
        # slovnika sa NEPREKLOPI na tichy default 'ks' (cena za balenie/meter by
        # sa tvarila ako cena za kus). nil = polozka sa odmieta.
        def manual_unit(raw)
          return nil unless defined?(HardwareCatalog)

          HardwareCatalog.canonical_unit(raw)
        end

        # -> [cena|nil, platne?]. nil cena = „nezadana" (NIKDY 0, standard §11.3).
        def manual_price(raw)
          return [nil, true] unless raw.key?('price_eur_vat') || raw.key?(:price_eur_vat)

          v = mraw(raw, 'price_eur_vat')
          return [nil, true] if v.nil? || v.to_s.strip.empty?

          f = defined?(Materials) ? Materials.normalize_price(v) : Float(v.to_s.tr(',', '.'))
          return [nil, false] if f.nil? || !f.is_a?(Numeric) || !f.to_f.finite? || f.to_f.negative?

          [f.to_f, true]
        rescue ArgumentError, TypeError
          [nil, false]
        end

        # ID musi byt bezpecny SEGMENT (vstupuje do kluca nakupneho riadku
        # `free:<cabinet_id>:<id>`) — `PartKeys.segment` je jedina autorita tvaru.
        def manual_id(raw)
          v = mraw(raw, 'id').to_s.strip
          v.empty? ? '' : PartKeys.segment(v)
        end

        def manual_note(raw)
          v = raw.to_s.strip
          v.length > MANUAL_NOTE_MAX ? v[0, MANUAL_NOTE_MAX] : v
        end

        # Nove ID polozky. Unikatne v ramci JEDNEJ skrinky (kluc riadku nesie aj
        # `cabinet_id`, takze zhoda naprie skrinkami nicomu nevadi).
        def next_manual_id(seen)
          @manual_id_seq = @manual_id_seq.to_i
          loop do
            @manual_id_seq += 1
            id = "H#{Time.now.to_i.to_s(36)}-#{@manual_id_seq.to_s(36)}-#{format('%04x', rand(0x10000))}"
            return id unless seen.key?(id)
          end
        end

        # Cita kluc v oboch tvaroch (config = stringy, panel payload = stringy,
        # testy niekedy symboly) — vzor `raw(p, key)`.
        def mraw(hash, key)
          hash.key?(key) ? hash[key] : hash[key.to_sym]
        end

        # Odmietnutie: strict = VYNIMKA (cela zmena padne), inak log + nil.
        def manual_drop(strict, message)
          raise ManualRejected, message if strict

          Engine.log("hardware_manual: polozka preskocena — #{message}") if defined?(Engine)
          nil
        end

        # D-18 (Codex audit F1): celo typu 'none' nema dielce — rucne zasahy kovania
        # viazane na jeho front id su mrtve zaznamy (UI by ukazovalo „vypnute" polozky
        # bez existujuceho dielca a pri neskorsom navrate na dvierka by zasah necakane
        # ozil). Pri normalizacii sa odstrania; zasahy ostatnych riadkov a korpusove
        # (owner nil) ostavaju nedotknute. Prune sa persistne prejavi cez merge_final.
        def prune_none_front_overrides(overrides, fronts_cfg)
          none_ids = (fronts_cfg['items'] || [])
                     .select { |it| it['type'] == 'none' }
                     .map { |it| it['id'].to_s }
          return overrides if none_ids.empty?
          overrides.reject do |ov|
            m = ov['owner_part_key'].to_s.match(%r{\Afront:([^/]+)/})
            m && none_ids.include?(m[1])
          end
        end

        # D-90 (Codex #144 P2): rucny zasah do kovania PROFILU zije len dovtedy,
        # kym celo profil MA. Po vypnuti profilu by zaznam ostal mrtvy — semafor
        # by hlasil ORANGE „Úchytky vypnuté" pre profil, ktory uz neexistuje, a
        # pri opatovnom zapnuti by necakane ozil (vzor prune_none_front_overrides).
        # Cielime VYHRADNE na rule_id profilovych SEED pravidiel — vlastne
        # premenovane pravidlo si pouzivatel spravuje sam.
        def prune_profile_overrides(overrides, fronts_cfg)
          ids = defined?(HardwareRules) ? HardwareRules.profile_rule_ids : []
          return overrides if ids.empty?
          no_profile = (fronts_cfg['items'] || [])
                       .reject { |it| FrontProfiles.of(it) }
                       .map { |it| it['id'].to_s }
          return overrides if no_profile.empty?
          overrides.reject do |ov|
            next false unless ids.include?(ov['rule_id'].to_s)
            m = ov['owner_part_key'].to_s.match(%r{\Afront:([^/]+)/})
            m && no_profile.include?(m[1])
          end
        end

        def truthy_flag(v)
          v == true || %w[true 1 yes].include?(v.to_s.downcase)
        end

        # zone_tree z params; ak chyba, ale je legacy 'shelves' -> koren so shelves; inak prazdny koren.
        def norm_zone_tree(p)
          zt = raw(p, :zone_tree)
          return ZoneTree.sanitize(zt) if zt.is_a?(Hash)
          sh = raw(p, :shelves)
          ZoneTree.default_tree(sh.nil? || sh.to_s.strip.empty? ? 0 : sh.to_i)
        end

        # Config (stored, string kluce) -> params pre normalize. Doplna spatnu kompatibilitu:
        # stare configy (bez zone_tree, fronts ako string, shelves top-level).
        def config_to_params(cfg)
          params = {
            'type' => cfg['type'] || 'lower',
            'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'thickness' => cfg['thickness'], 'floor_height' => cfg['floor_height'],
            'bottom_mode' => cfg['bottom_mode'] || legacy_bottom(cfg),
            'top_mode'    => cfg['top_mode']    || legacy_top(cfg),
            'back_mode'   => cfg['back_mode']   || legacy_back(cfg),
            'back_thickness' => cfg['back_thickness'] || legacy_back_thickness(cfg),
            'plinth_mode' => cfg['plinth_mode'] || legacy_plinth(cfg),
            'plinth_recess' => cfg['plinth_recess'] || 50.0,
            'rail_depth' => cfg['rail_depth'] || 100.0,
            'rails_orientation' => cfg['rails_orientation'] || 'flat',
            'rails_top_offset' => cfg['rails_top_offset'] || 0.0,
            # strom zon: novy config ho ma; stary korpus -> koren so starymi policami
            'zone_tree' => cfg['zone_tree'] || ZoneTree.default_tree((cfg['shelves'] || 0).to_i),
            # cela: novy config = hash; stary = string ('none'/'1'/'2'/'auto') -> Fronts.normalize
            'fronts' => cfg.key?('fronts') ? fronts_from_config(cfg) : nil,
            # V0.3 materialy. Marker V0.3 configu = pritomnost 'part_overrides'. Legacy korpusy (V0.2)
            # mali material_id/back_material_id ulozene NATVRDO (K009/HDF) — tie NEberieme ako korpusovy
            # override (nechame nil = dedi z projektu), aby projektovy default fungoval aj na starych.
            'material_id'       => v03?(cfg) ? cfg['material_id'] : nil,
            'front_material_id' => v03?(cfg) ? cfg['front_material_id'] : nil,
            'back_material_id'  => v03?(cfg) ? cfg['back_material_id'] : nil,
            'part_key_schema'   => cfg['part_key_schema'].to_i,
            'part_overrides'    => cfg['part_overrides'].is_a?(Hash) ? cfg['part_overrides'] : {},
            # V0.4 kovanie (pole neexistovalo pred V0.4 -> stare configy dostanu []).
            # POZN. buduci part_key schema bump: owner_part_key tychto zaznamov musi
            # prejst TOU ISTOU legacy->current mapou ako part_overrides (audit D5).
            'hardware_overrides' => cfg['hardware_overrides'].is_a?(Array) ? cfg['hardware_overrides'] : [],
            # V0.6 D1 (GH #126 P1): bez kopie by KAZDY rebuild zo stored configu
            # (scale absorpcia, ulozenie pravidiel, Nahradit UNI, panel akcie)
            # zahodil cabinet override setov kovania. H1a: ten isty parser ako
            # normalize — params uz opustaju config v platnom tvare.
            'hardware_sets' => norm_hardware_sets(cfg['hardware_sets']),
            # KOV-H1: ad-hoc polozky. Bez kopie by ich KAZDY rebuild zo stored
            # configu zahodil (rovnaka pasca ako `hardware_sets`, GH #126 P1).
            # ID sa TU nemenia — nova identita vznika VYHRADNE cez
            # `rekey_hardware_manual` v kopirovacich cestach (audit FIX 10).
            'hardware_manual' => (cfg['hardware_manual'].is_a?(Array) ? cfg['hardware_manual'] : []),
            'name' => cfg['name']
          }
          migrate_legacy_part_keys(params, cfg)
        end

        # Migracia sa robi podla POVODNEJ ulozenej konfiguracie este pred pouzivatelskou
        # zmenou. Tak sa spravne prenesie aj override cela, ktore sa nasledne presunie
        # alebo zostane po zmazani susedneho riadku.
        def migrate_legacy_part_keys(params, stored_cfg)
          return params if stored_cfg['part_key_schema'].to_i >= PartKeys::SCHEMA

          normalized = normalize(params)
          plan = Construction.build_plan(normalized)
          params['part_overrides'] = PartKeys.migrate_overrides(params['part_overrides'], plan[:parts])
          params['part_key_schema'] = PartKeys::SCHEMA
          params
        rescue StandardError => e
          Engine.log_error(e, 'migrate_legacy_part_keys') if defined?(Engine)
          params
        end

        # Marker V0.3 materialov. V0.2 korpusy part_overrides nemali.
        def v03?(cfg)
          cfg.key?('part_overrides')
        end

        # Pred V0.3.1 panel dovolil pevne cela nizsie ako Fronts::MIN_AUTO.
        # part_overrides nie je dostatocna hranica migracie, pretoze ho uz mala V0.3.0.
        def fronts_from_config(cfg)
          raw_fronts = cfg['fronts']
          return raw_fronts if version_at_least?(cfg['engine_version'], FRONT_VALIDATION_VERSION)
          Fronts.migrate_legacy_config(raw_fronts)
        end

        def version_at_least?(value, minimum)
          actual = value.to_s.split('.').first(3).map(&:to_i)
          target = minimum.to_s.split('.').first(3).map(&:to_i)
          actual.fill(0, actual.length...3)
          target.fill(0, target.length...3)
          (actual <=> target) >= 0
        end

        def legacy_back_thickness(cfg)
          (cfg['back'] && cfg['back']['thickness']) || Construction::BACK_THICKNESS_DEFAULT
        end

        def legacy_bottom(cfg)
          (cfg['bottom'] && cfg['bottom']['mode']) || 'between_sides'
        end

        def legacy_top(cfg)
          m = cfg['top'] && cfg['top']['mode']
          (m.nil? || m == 'full_panel') ? 'full' : m
        end

        def legacy_back(cfg)
          (cfg['back'] && cfg['back']['mode']) || 'overlay'
        end

        # Stary V0.1 korpus mal vzdy predny sokel (support.type='plinth'); horny ziadny.
        def legacy_plinth(cfg)
          return 'none' if (cfg['type'] || 'lower') == 'upper'
          sup = cfg['support']
          sup && sup['type'] == 'plinth' ? 'front' : (cfg['floor_height'].to_f > 0 ? 'front' : 'none')
        end

        # --- pomocne --------------------------------------------------------

        # V0.4.7b: pravy okraj pocita Placement (top-level cabinet + board, nikdy
        # ghost zony) — novy korpus sa vlozi aj vedla dosky, nie cez nu.
        def next_x(model)
          Placement.next_x(model, gap: GAP_BETWEEN_CABS)
        end

        def norm_type(p)
          (raw(p, :type)).to_s == 'upper' ? 'upper' : 'lower'
        end

        def enum_val(p, key, allowed, default)
          v = raw(p, key)
          allowed.include?(v.to_s) ? v.to_s : default
        end

        def ensure_material(model, name, rgb)
          mt = model.materials[name] || model.materials.add(name)
          mt.color = Sketchup::Color.new(*rgb)
          mt
        end

        def raw(p, key)
          v = p[key.to_s]
          v.nil? ? p[key] : v
        end

        # String hodnota alebo nil (prazdny/whitespace string -> nil). Pouzite pri material_id
        # dedeni (nil = "dedi z nadradenej urovne", standard 7.2).
        def present(v)
          return nil if v.nil?
          s = v.to_s.strip
          s.empty? ? nil : s
        end

        def fetchf(p, key, default)
          v = raw(p, key)
          return default if v.nil? || v.to_s.strip.empty?
          v.to_f
        end

        def clampf(v, lo, hi)
          v = v.to_f
          return lo if v < lo
          return hi if v > hi
          v
        end

        def guarded
          if defined?(ScaleWatch)
            ScaleWatch.guard { yield }
          else
            yield
          end
        end

        def abort_safely(model)
          model.abort_operation
        rescue StandardError
          nil
        end
      end
    end
  end
end
