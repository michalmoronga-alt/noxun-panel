# frozen_string_literal: true
# Noxun Engine — GHOST VKLADANIE (V1-04). Po „Vlozit" visi ghost skrinky na
# kurzore; klik ju polozi ako JEDNU realnu CAB v JEDNOM Undo kroku presne tam,
# kde bol ghost. Ghost je CISTA viewport grafika (`draw`) — ziadna docasna
# ComponentInstance, ziadna entita, ziadne ID a ziadny krok Spat pred klikom.
#
# Tri vrstvy v tomto subore:
#   GhostTool          — vlastnik NAJVIAC JEDNEJ session + ciste API pre panel
#   GhostTool::Calc    — CISTA matematika (kotvy, obalka, kanonicka matica,
#                        ray x rovina zamku). Ziadny SketchUp — testovatelne headless.
#   GhostTool::PlacementSession — stav vkladu (zmrazeny InsertPlan z R-03,
#                        kovanie zo sablony, sablonovy ref, stavovy automat)
#   GhostTool::Tool    — SketchUp Tool (draw/getExtents/mys/klavesy/lifecycle)
#
# ZASADY (audit 30.8.2026):
#   * JEDEN vlastnik session — kazdy koniec zivotneho cyklu rusi STARU session
#     PRED cimkolvek dalsim (druhe „Vlozit", zavretie Inspectora, prepnutie
#     dokumentu, onCancel 0/1/2, deactivate).
#   * Transform sa vzdy sklada NANOVO z celociselneho stavu (rotation_index % 4),
#     nikdy inkrementalnym nasobenim — osi su presne 0/±1 a `rigid_matrix?`
#     (R-03) ich prijme bez numerickeho sumu.
#   * V `draw` sa NIKDY nevola `Construction.build_plan` — obalka je 8 bodov
#     spocitanych RAZ zo zmrazeneho configu.
#   * Preflighty (D-45/D-76/material/zamky) bezia RAZ v `Panel.handle_insert`;
#     Tool ich NEOPAKUJE. Tool riesi polohu, nie vyrobne pravidla.
#   * Commit ide VYHRADNE cez sev R-03 `CabinetBuilder.commit_insert` — ziadny
#     vlastny zapis do modelu.
module Noxun
  module Engine
    module GhostTool
      # Poradie cyklovania kotiev (Alt): lava-dolna -> prava-dolna -> prava-horna -> lava-horna.
      ANCHORS = %i[fl_bottom fr_bottom fr_top fl_top].freeze
      ANCHOR_LABELS = {
        fl_bottom: 'ľavá dolná', fr_bottom: 'pravá dolná',
        fr_top: 'pravá horná', fl_top: 'ľavá horná'
      }.freeze
      Z_MODES = %i[locked free].freeze

      # GHOST-FB4: rozumny rozsah locknutej vysky (mm). Horna hranica je
      # „este nabytok" — nad 3 m uz nejde o skrinku, ale o preklep.
      LOCK_Z_MIN_MM = 0.0
      LOCK_Z_MAX_MM = 3000.0

      # Farby ghostu (GL). Zamerne NIE `EdgeCheck::COLORS` (tri stavy olepu) —
      # ghost hovori o polohe, nie o vyrobe. Obrys = neutralna tmava
      # (`--nx-ink-strong`), predna stena a kotva = rodina vyberu `--nx-select`.
      OUTLINE_RGB = [55, 71, 79].freeze     # #37474f
      FRONT_RGB   = [16, 119, 135].freeze   # --nx-select #107787
      ANCHOR_RGB  = [11, 86, 97].freeze     # --nx-select-strong #0B5661
      DIM_RGB     = [150, 158, 162].freeze  # nepolozitelny stav (stlmeny ghost)
      ANCHOR_ARM_MM = 60.0                  # rameno krizika aktivnej kotvy

      class << self
        # Aktivna session (najviac JEDNA v celom module) a jej Tool.
        attr_reader :session, :active_tool

        # --- GHOST-FB3: PAMAT NASTAVENI (per PROCES, nie per dokument) ------
        # Kotva, rotacia, rezim vysky a locknute vysky prezijú koniec session
        # a plati az do vypnutia SketchUpu. VEDOME sa NIKAM nezapisuje — ani na
        # disk, ani do modelu: je to pracovny navyk pri jednom sedeni, nie
        # udaj zakazky (inak by sa cudzia zakazka otvorila s cudzimi kotvami).
        # Locknute vysky su per TYP skrinky ('lower' / 'upper'); PRVA session
        # daneho typu si default vezme z `plan.home_z` (dolna 0, horna
        # `UPPER_HANG_Z` = 1400) — hodnota sa nikde neduplikuje.
        def memory
          @memory ||= { anchor: ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
        end

        # Naspat na tovarenske hodnoty (nova „prva session"). Pouzivaju testy
        # a teardown in-SU sady — v behu pluginu ju nikto nevola.
        def reset_memory!
          @memory = nil
        end

        # --- verejne API pre panel -----------------------------------------

        # Zalozi novu session nad ZMRAZENYM planom (R-03 `prepare_insert`) a
        # aktivuje Tool. Stara session sa rusi PRED vznikom novej.
        # `push_tool` (NIE `select_tool`) — po vlozeni sa pouzivatel vrati
        # k nastroju, ktory mal predtym.
        def start(model, plan, hardware: nil, template_ref: nil, note: nil)
          # Stara session KONCI PRED vznikom novej a jej nastroj sa popne
          # SYNCHRONNE — inak by nam odlozeny `pop_tool` zhodil prave
          # pushnuty novy nastroj (dva ghosty na stacku).
          cancel_session('nové vloženie', deferred: false)
          s = PlacementSession.new(model: model, plan: plan, hardware: hardware,
                                   template_ref: template_ref, note: note)
          @session = s
          model.tools.push_tool(Tool.new)
          # CEF si po navrate z HtmlDialog callbacku vezme fokus spat — bez
          # tohto by sipky a Esc nefungovali, kym pouzivatel neklikne do modelu.
          focus_model_soon
          push_state(s) # GHOST-FB4: pasik sa v paneli objavi so session
          s
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.start')
          @session = nil
          # Nastroj sa uz mohol pushnut (alebo aktivovat len ciastocne) — bez
          # tohto by visel na stacku bez session a pouzivatel by z neho vysiel
          # len prepnutim nastroja. `activate` sa preto registruje ako PRVE,
          # nech je co popnut aj pri chybe uprostred nej.
          end_tool(deferred: false)
          nil
        end

        # Zrusi beziacu session (idempotentne). Vracia true, ak sa naozaj nieco
        # zrusilo. Vola ju KAZDY koniec zivotneho cyklu — druhe „Vlozit",
        # zavretie Inspectora, prepnutie dokumentu, onCancel, deactivate.
        # `deferred:` = pop nastroja cez timer (volanie z Tool callbacku).
        def cancel_session(reason = nil, deferred: true)
          s = @session
          changed = false
          if s
            changed = s.cancel!(reason)
            # Slot sa uvolnuje aj nad `:committing` (review #268 P3-10): ked by
            # z commitu vybublala vynimka MIMO `StandardError`, session by
            # ostala navzdy „rozrobena" a drzala by slot az do restartu.
            @session = nil if s.terminal? || s.committing?
            invalidate_view(s.model)
          end
          end_tool(deferred: deferred)
          # GHOST-FB4: pasik v paneli zmizne s KAZDYM koncom session.
          push_state(nil) if changed || s
          changed
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.cancel_session')
          false
        end

        # Session skoncila uspesnym commitom — uvolni slot (nastroj konci
        # samostatne, po dokonceni klikovej cesty).
        def release_session(s)
          @session = nil if @session.equal?(s)
          push_state(nil) # GHOST-FB4: po vlozeni pasik zmizne
        end

        # --- GHOST-FB4: stav session do panela ------------------------------
        # Pasik je INFORMACNY a existuje LEN pocas session — panel si z neho
        # nic neodvodzuje ani nedopocitava, kazdy push ho cely prepise.
        def state_payload(s)
          return { 'active' => false } unless s && s.active?

          { 'active' => true, 'type' => s.type_key,
            'anchor' => s.anchor.to_s, 'anchor_label' => ANCHOR_LABELS[s.anchor].to_s,
            'rotation' => s.rotation_index * 90, 'z_mode' => s.z_mode.to_s,
            'lock_z' => s.lock_plane_z.to_f }
        end

        def push_state(s = @session)
          return unless defined?(Panel) && Panel.respond_to?(:push_ghost)

          Panel.push_ghost(state_payload(s))
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.push_state')
          nil
        end

        # Ukonci NAS nastroj PRESNE JEDNYM `pop_tool`. Idempotentne: pop
        # prebehne len ak je TEN ISTY nastroj este pripojeny.
        # POZOR: odlozeny pop si drzi KONKRETNU instanciu (nie `@active_tool`) —
        # inak by timer zalozeny starou session zhodil nastroj, ktory medzitym
        # pushlo druhe „Vlozit".
        def end_tool(deferred: true)
          t = @active_tool
          return false unless t && t.attached?

          if deferred
            UI.start_timer(0, false) { pop_tool(t) }
            true
          else
            pop_tool(t)
          end
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.end_tool')
          false
        end

        # `Sketchup::Tools#pop_tool` odoberie VRCH STACKU — nie konkretnu
        # instanciu. Ked medzitym niekto (iny extension, natívny nastroj)
        # pushol nastroj NAD nas, slepy pop by zhodil JEHO a ghost by ostal
        # visiet aktivny bez session (review #268 kolo 2, P2).
        # Preto sa pop vykona LEN ked sme naozaj navrchu; inak sa ukoncenie
        # ODLOZI (`request_finish!`) a dokona sa pri najblizsom `resume`
        # — teda presne vtedy, ked sa vrch stacku vrati k nam — alebo zanikne
        # s `deactivate`. `active_tool_id` sa na rozhodovanie NEPOUZIVA:
        # nemapuje sa spolahlivo na instanciu; „som navrchu" si drzime sami
        # z `activate` / `suspend` / `resume` / `deactivate`.
        def pop_tool(tool)
          return false unless tool && tool.attached?

          unless tool.on_top?
            tool.request_finish!
            return false
          end

          model = tool.model_ref || Sketchup.active_model
          @active_tool = nil if @active_tool.equal?(tool)
          tool.detach!
          model.tools.pop_tool
          true
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.pop_tool')
          false
        end

        # PRVA (a na Windows JEDINA spolahliva) obrana: File > New / Open.
        # Udalost sama o sebe znamena, ze dokument pod ghostom uz nie je ten,
        # v ktorom vklad zacal — ruší sa preto BEZPODMIENECNE, bez porovnavania
        # identity. Dovod (review #268 P2-2): Windows drzi JEDEN dokument na
        # proces a pri File>Open smie RECYKLOVAT ten isty `Sketchup::Model`
        # objekt; porovnanie objektom by vtedy vratilo „ten isty dokument"
        # a session by prezila do cudzej zakazky. Na `guid` sa spoliehat NEDA
        # (meni ho kazde ulozenie — Ctrl+S ghost rušiť nesmie).
        def on_document_replaced(reason = 'nový alebo otvorený dokument')
          return false unless @session

          cancel_session(reason)
        end

        # DRUHA obrana (macOS multi-dokument, `onActivateModel`): aktivacia
        # INEHO dokumentu. Tu uz identita zmysel ma — aktivacia TOHO ISTEHO
        # dokumentu (aj po ulozeni) ghost rušiť nesmie. Plan sa porovnava
        # OBJEKTOM modelu, nie guidom (lekcia #261/#264).
        def on_model_switched(model)
          s = @session
          return false unless s
          return false if model && s.plan.respond_to?(:for_model?) && s.plan.for_model?(model)

          cancel_session('prepnutý dokument')
        end

        def session_for?(model)
          s = @session
          !s.nil? && s.active? && s.plan.for_model?(model)
        end

        # --- Tool registracia (interne) -------------------------------------

        def register_tool(tool)
          @active_tool = tool
        end

        def unregister_tool(tool)
          @active_tool = nil if @active_tool.equal?(tool)
        end

        # --- geometria pre Tool aj testy ------------------------------------

        # FINALNA transformacia instancie pre danu session (SketchUp palce).
        # Nil, ak session nema platnu polohu.
        def world_transform(s)
          return nil unless s && s.last_point

          # GHOST-FB4: v zamku plati LOCKNUTA vyska session (`lock_plane_z`) —
          # default je domaca vyska typu (`plan.home_z`), ale pole v pasiku ju
          # smie prestavit a zmena plati OKAMZITE aj pre commit.
          vals = Calc.matrix(anchor: s.anchor_point_mm, picked: s.last_point,
                             rotation_index: s.rotation_index,
                             z_mode: s.z_mode, home_z: s.lock_plane_z)
          Geom::Transformation.new(to_inch_matrix(vals))
        end

        # 16 cisel s TRANSLACIOU prevedenou z mm na palce (rotacna cast je
        # bezrozmerna). Kanonicka matica prejde `CabinetBuilder.rigid_matrix?`.
        def to_inch_matrix(vals)
          out = vals.map(&:to_f)
          (12..14).each { |i| out[i] = out[i] / Units::MM_PER_INCH }
          out
        end

        # 8 rohov obalky ghostu vo SVETE (Geom::Point3d).
        def world_corners(s)
          tr = world_transform(s)
          return [] unless tr

          s.corners_mm.map { |p| tr * Units.point(p[0], p[1], p[2]) }
        end

        def world_anchor(s)
          tr = world_transform(s)
          return nil unless tr

          a = s.anchor_point_mm
          tr * Units.point(a[0], a[1], a[2])
        end

        # --- pomocne --------------------------------------------------------

        def invalidate_view(model)
          v = (model && model.respond_to?(:active_view) ? model.active_view : nil)
          v ||= (defined?(Sketchup) ? Sketchup.active_model.active_view : nil)
          v.invalidate if v
        rescue StandardError
          nil
        end

        def focus_model_soon
          UI.start_timer(0, false) do
            begin
              Sketchup.focus
            rescue StandardError
              nil
            end
          end
        rescue StandardError
          nil
        end

        def status_text(s)
          return '' unless s

          lock = s.z_mode == :locked ? "výška #{fmt_mm(s.lock_plane_z)} mm" : 'voľná výška'
          warn = s.placeable ? '' : ' · POLOHA NEČITATEĽNÁ — otoč pohľad'
          "Ghost: klik položí skrinku · ←/→ otočiť · Alt kotva · ↓ zámok výšky · ↑ voľná výška · Esc zruší " \
            "| kotva #{ANCHOR_LABELS[s.anchor]} · #{lock} · otočenie #{s.rotation_index * 90}°#{warn}"
        end

        def fmt_mm(v)
          f = v.to_f
          (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f)
        end
      end

      # =====================================================================
      # CISTA MATEMATIKA — ziadny SketchUp, ziadne jednotky mimo mm.
      # Vsetky vstupy aj vystupy su v JEDNEJ jednotke (mm); matica je linearna,
      # takze ta ista funkcia obsluzi aj palce, ak sa jednotky nemiesaju.
      # =====================================================================
      module Calc
        EPS = 1e-9
        # STRAZNIK DEGENEROVANYCH LUCOV (interne review #268, P2-1).
        # Holy `EPS` na zlozke smeru je MRTVY straznik: pri normalizovanom
        # vektore ho prejde aj luc jeden pixel pod horizontom (dz ~ 1e-4),
        # z coho vyjde parameter luca radovo 10^6 — a klik by polozil korpus
        # KILOMETRE od originu (`rigid_matrix?` translaciu nijako neobmedzuje).
        # Preto dve NEZAVISLE brany:
        #   MIN_SIN      — UHLOVA hranica sklonu luca voci rovine (sinus uhla);
        #                  1e-3 je ~0,057°, teda „takmer vodorovny pohlad"
        #   MAX_REACH_MM — ZDRAVOTNY STROP na vysledok (1 km od kamery aj od
        #                  originu modelu). Chrani AJ free rezim, kde inference
        #                  vie vratit bod na extremne vzdialenej geometrii.
        MIN_SIN = 1e-3
        MAX_REACH_MM = 1_000_000.0
        # Presne hodnoty cos/sin pre nasobky 90° — ziadny numericky sum,
        # `rigid_matrix?` (RIGID_TOL 1e-6) ich prijme bez rezervy.
        COS = [1.0, 0.0, -1.0, 0.0].freeze
        SIN = [0.0, 1.0, 0.0, -1.0].freeze

        module_function

        # Config planu ma symbolove kluce (`CabinetBuilder.normalize`), ale
        # tolerujeme aj stringove (config z modelu) — jeden citac pre oboje.
        def cfg_get(cfg, key)
          return nil unless cfg.respond_to?(:[])

          v = cfg[key]
          v.nil? ? cfg[key.to_s] : v
        end

        def cfg_num(cfg, key)
          cfg_get(cfg, key).to_f
        end

        def cfg_str(cfg, key)
          cfg_get(cfg, key).to_s
        end

        # ZAVAZNA tabulka kotiev (audit BLOCKER 4). Predna rovina korpusu je
        # VZDY lokalne Y = 0 — cela maju zaporne Y a do kotiev NEVSTUPUJU;
        # plinth recess ani presah cela rovinu Y = 0 nemenia.
        #
        #   dolna `under_sides`   -> spodok tela je DNO na Z = floor_height
        #   dolna `between_sides` -> boky stoja na zemi, spodok tela je Z = 0
        #   horna (oba varianty)  -> normalizovany floor_height 0 => Z = 0
        #     (UPPER_HANG_Z je SVETOVA vyska originu, nie lokalna kotva)
        def body_bottom_z(cfg)
          return 0.0 if cfg_str(cfg, :type) == 'upper'

          cfg_str(cfg, :bottom_mode) == 'under_sides' ? cfg_num(cfg, :floor_height) : 0.0
        end

        # Lokalne suradnice jednej kotvy [x, y, z] v mm.
        def anchor_point(cfg, anchor)
          w = cfg_num(cfg, :width)
          h = cfg_num(cfg, :height)
          bz = body_bottom_z(cfg)
          case anchor
          when :fr_bottom then [w, 0.0, bz]
          when :fr_top    then [w, 0.0, h]
          when :fl_top    then [0.0, 0.0, h]
          else                 [0.0, 0.0, bz] # :fl_bottom + fallback
          end
        end

        def anchor_points(cfg)
          ANCHORS.each_with_object({}) { |a, h| h[a] = anchor_point(cfg, a).freeze }
        end

        # 8 rohov obalky ghostu (mm): [0..w] x [0..depth] x [body_bottom..h].
        # Poradie je SUCASTOU kontraktu kreslenia (EDGES/FRONT_FACE nizsie).
        def envelope_points(cfg)
          w = cfg_num(cfg, :width)
          d = cfg_num(cfg, :depth)
          h = cfg_num(cfg, :height)
          z0 = body_bottom_z(cfg)
          [[0.0, 0.0, z0], [w, 0.0, z0], [w, d, z0], [0.0, d, z0],
           [0.0, 0.0, h],  [w, 0.0, h],  [w, d, h],  [0.0, d, h]]
        end

        def norm_rotation(k)
          k.to_i % 4
        end

        # Otocenie bodu okolo osi Z o k*90° (presne, bez Math.cos/sin).
        def rotate_z(pt, k)
          i = norm_rotation(k)
          c = COS[i]
          s = SIN[i]
          x = pt[0].to_f
          y = pt[1].to_f
          [(c * x) - (s * y), (s * x) + (c * y), pt[2].to_f]
        end

        # KANONICKA konstrukcia transformu (audit 9 + uzavretie 5).
        # Sklada sa VZDY NANOVO z celociselneho stavu — nikdy inkrementalne.
        #   free   : translation = picked − R(anchor)
        #   locked : translation.z = home_z NAPEVNO (lokalne Z kotvy sa
        #            NEODCITA — origin skrinky drzi domacu vysku svojho typu),
        #            X/Y = picked_xy − R(anchor)_xy
        # Vystup: 16 cisel v SketchUp poradi (po stlpcoch).
        def matrix(anchor:, picked:, rotation_index: 0, z_mode: :locked, home_z: 0.0)
          i = norm_rotation(rotation_index)
          c = COS[i]
          s = SIN[i]
          ra = rotate_z(anchor, i)
          tx = picked[0].to_f - ra[0]
          ty = picked[1].to_f - ra[1]
          tz = z_mode == :free ? (picked[2].to_f - ra[2]) : home_z.to_f
          [c,   s,   0.0, 0.0,
           -s,  c,   0.0, 0.0,
           0.0, 0.0, 1.0, 0.0,
           tx,  ty,  tz,  1.0]
        end

        # Priesecnik luca s VODOROVNOU rovinou zamku (audit BLOCKER 3 +
        # review #268 P2-1). Plati LEN ked su splnene VSETKY podmienky:
        #   * smer je konecny a nenulovy,
        #   * luc je voci rovine dostatocne SKLONENY (`MIN_SIN`) — takmer
        #     vodorovny pohlad polohu neurcuje,
        #   * parameter `t >= 0` (rovina lezi PRED kamerou),
        #   * vysledok je v ZDRAVOM dosahu (`MAX_REACH_MM`) — sikmy, ale este
        #     nie „vodorovny" luc inak vystreli bod kilometre od originu.
        # Inak nil — ghost drzi poslednu platnu polohu, `placeable = false`
        # a klik NECOMMITNE.
        def ray_plane(origin, direction, plane_z)
          return nil unless origin && direction

          d = [direction[0].to_f, direction[1].to_f, direction[2].to_f]
          return nil unless d.all?(&:finite?)

          len = Math.sqrt((d[0] * d[0]) + (d[1] * d[1]) + (d[2] * d[2]))
          return nil unless len.finite? && len > EPS
          # dz/len je SINUS uhla medzi lucom a rovinou — jednotka smeru sa tak
          # nemusi predpokladat (pickray vracia jednotkovy, testy nemusia).
          return nil unless (d[2] / len).abs > MIN_SIN

          oz = origin[2].to_f
          return nil unless oz.finite? && plane_z.to_f.finite?

          t = (plane_z.to_f - oz) / d[2]
          return nil unless t.finite? && t >= 0.0
          # Dlzka luca po rovinu (`t` je v jednotkach `d`, preto krat `len`).
          return nil unless (t * len) <= MAX_REACH_MM

          pt = [origin[0].to_f + (t * d[0]), origin[1].to_f + (t * d[1]), plane_z.to_f]
          sane_point?(pt) ? pt : nil
        end

        # ZDRAVOTNY STROP na KAZDU polohu ghostu — plati pre zamok aj pre free
        # inference. Poloha musi byt konecna a najviac `MAX_REACH_MM` od
        # originu modelu; inak sa ghost nesmie polozit (radsej ziadna poloha
        # nez korpus kilometre od zakazky).
        def sane_point?(pt)
          return false unless pt.is_a?(Array) && pt.length == 3
          return false unless pt.all? { |v| v.is_a?(Numeric) && v.to_f.finite? }

          pt.all? { |v| v.to_f.abs <= MAX_REACH_MM }
        end

        # GHOST-FB1 — HYBRID V ZAMKU: bod, ktory dal inference engine
        # (`InputPoint`), sa v zamku pouzije LEN na X/Y; Z prepise ZAMOK.
        # Vdaka tomu sa dolna skrinka prichyti na roh susednej skrinky, hoci
        # ten roh lezi 100 mm nad podlahou (sokel) — a origin pritom drzi
        # domacu vysku. Zdravotny strop plati na OBE podoby bodu: na surovy
        # bod z inference aj na vysledok so zamknutym Z.
        def lock_point(pt, plane_z)
          return nil unless sane_point?(pt)

          z = plane_z.to_f
          return nil unless z.finite?

          out = [pt[0].to_f, pt[1].to_f, z]
          sane_point?(out) ? out : nil
        end

        # GHOST-FB4: validacia rucne zadanej locknutej vysky (mm). Vracia
        # Float, alebo nil pri necisle / mimo rozsahu — volajuci vtedy
        # PONECHA staru hodnotu (nikdy nespadne na 0).
        def lock_z_value(raw)
          s = raw.to_s.strip.tr(',', '.')
          return nil if s.empty?
          return nil unless s =~ /\A[+-]?\d+(\.\d+)?\z/

          v = s.to_f
          return nil unless v.finite?
          return nil if v < LOCK_Z_MIN_MM || v > LOCK_Z_MAX_MM

          v
        end

        # Dalsia kotva v cykle (Alt). JEDNA metoda — pripadny TAB fallback
        # (Scope OUT tejto davky) by volal presne ju.
        def next_anchor(anchor, step = 1)
          i = ANCHORS.index(anchor) || 0
          ANCHORS[(i + step) % ANCHORS.length]
        end
      end

      # Hrany obalky (indexy do `Calc.envelope_points`) — 12 hran kvadra.
      EDGES = [[0, 1], [1, 2], [2, 3], [3, 0],
               [4, 5], [5, 6], [6, 7], [7, 4],
               [0, 4], [1, 5], [2, 6], [3, 7]].freeze
      # Predna stena (lokalne Y = 0) — zvyraznena, aby bolo vidno orientaciu.
      FRONT_FACE = [0, 1, 5, 4].freeze

      # =====================================================================
      # PlacementSession — stav JEDNEHO vkladu medzi „Vlozit" a klikom.
      # =====================================================================
      class PlacementSession
        attr_reader :model, :plan, :hardware, :template_ref, :note, :state,
                    :rotation_index, :anchor, :z_mode, :last_point, :corners_mm,
                    :anchors_mm, :cancel_reason, :hardware_note, :type_key

        def initialize(model:, plan:, hardware: nil, template_ref: nil, note: nil, memory: nil)
          @model = model
          @plan = plan
          @hardware = hardware
          @template_ref = template_ref
          @note = note.to_s
          @state = :active
          # GHOST-FB3: session STARTUJE Z PAMATE modulu (kotva, rotacia, rezim
          # vysky, locknute vysky) — do vypnutia SketchUpu si nastroj pamata,
          # ako s nim pouzivatel naposledy pracoval. Prva session v behu
          # dostane tovarenske hodnoty: lava dolna kotva, 0°, zamok.
          @memory = memory || GhostTool.memory
          @rotation_index = Calc.norm_rotation(@memory[:rotation_index])
          @anchor = ANCHORS.include?(@memory[:anchor]) ? @memory[:anchor] : ANCHORS.first
          # OBA typy startuju v ZAMKU svojej domacej vysky (horna nikdy
          # nestartuje vo free Z — zachovava dnesne spravanie buildera), kym
          # si pouzivatel v tomto behu nezvolil inak.
          @z_mode = Z_MODES.include?(@memory[:z_mode]) ? @memory[:z_mode] : :locked
          # Locknuta vyska je per TYP skrinky. Default sa NEDUPLIKUJE — berie
          # sa z planu (`home_z`: dolna 0, horna UPPER_HANG_Z = 1400).
          t = Calc.cfg_str(plan.config, :type)
          @type_key = t.empty? ? 'lower' : t
          store = (@memory[:lock_z] ||= {})
          store[@type_key] = plan.home_z.to_f unless store.key?(@type_key)
          @lock_z = store[@type_key].to_f
          # Obalka aj kotvy sa pocitaju RAZ zo ZMRAZENEHO configu (audit FIX 5)
          # — v `draw` sa uz nikdy nic neplanuje.
          @corners_mm = Calc.envelope_points(plan.config).map(&:freeze).freeze
          @anchors_mm = Calc.anchor_points(plan.config).freeze
          @last_point = nil
          @placeable = false
          @commit_started = false
          @stamp_attempted = false
          @hardware_note = ''
        end

        # --- stavovy automat (audit BLOCKER 2) ------------------------------
        # :active -> :committing -> :committed   (uspesny klik)
        # :active -> :cancelled                  (Esc / zavretie / prepnutie / iny nastroj)
        # Terminalne stavy su IDEMPOTENTNE — druhy klik ani druhy cancel uz nic nerobia.

        def active?
          @state == :active
        end

        def terminal?
          @state == :committed || @state == :cancelled
        end

        # Rozrobeny commit. Navonok sa nevyskytuje (commit je synchronny) —
        # okrem pripadu, ked z neho vybublala vynimka MIMO `StandardError`.
        # `cancel_session` podla toho uvolni slot (review #268 P3-10).
        def committing?
          @state == :committing
        end

        def placeable
          @placeable && !@last_point.nil?
        end
        alias placeable? placeable

        def cancel!(reason = nil)
          return false unless @state == :active

          @state = :cancelled
          @cancel_reason = reason.to_s
          true
        end

        # Vstup do commitu. Druhy (dvojity) klik vrati false — nikdy dve skrinky.
        def begin_commit!
          return false unless @state == :active
          return false if @commit_started

          @commit_started = true
          @state = :committing
          true
        end

        def mark_committed!
          return false unless @state == :committing

          @state = :committed
          true
        end

        # Commit ZLYHAL (validacia stavby, chyba sprievodneho bloku). V modeli
        # sa nic nezmenilo (`commit_insert` rusi celu operaciu), ale session
        # KONCI: preflighty uz prebehli a opakovany klik by zlyhal rovnako —
        # pouzivatel dostane hlasku a vlozenie zacne odznova.
        def mark_failed!(reason = nil)
          return false unless @state == :committing

          @state = :cancelled
          @cancel_reason = reason.to_s
          true
        end

        # Peciatka pouzitia sablony PRESNE RAZ a LEN po uspechu (audit FIX 8).
        def stamp_once!
          return false if @stamp_attempted

          @stamp_attempted = true
          yield if block_given?
          true
        end

        # --- stav polohy a ovladania ----------------------------------------

        def set_point(pt_mm, placeable = true)
          if pt_mm
            @last_point = [pt_mm[0].to_f, pt_mm[1].to_f, pt_mm[2].to_f].freeze
            @placeable = placeable ? true : false
          else
            # Degenerovany luc: ghost DRZI poslednu platnu polohu, len sa
            # nesmie polozit.
            @placeable = false
          end
          @placeable
        end

        # KAZDA zmena ovladania sa zapise aj do PAMATE modulu (GHOST-FB3) —
        # nasledujuca session zacne tam, kde tato skoncila.
        def rotate!(step)
          @rotation_index = Calc.norm_rotation(@rotation_index + step.to_i)
          @memory[:rotation_index] = @rotation_index
        end

        def cycle_anchor!(step = 1)
          @anchor = Calc.next_anchor(@anchor, step)
          @memory[:anchor] = @anchor
        end

        def set_z_mode!(mode)
          return false unless Z_MODES.include?(mode)
          return false if @z_mode == mode

          @z_mode = mode
          @memory[:z_mode] = mode
          true
        end

        # GHOST-FB4: rucne prestavena locknuta vyska (mm) pre TENTO typ
        # skrinky. Neplatny vstup NIC nemeni (stara hodnota drzi) — vracia
        # false a volajuci o tom povie v statuse.
        def set_lock_z!(raw)
          v = Calc.lock_z_value(raw)
          return false if v.nil?
          return false if (v - @lock_z).abs < 1e-9

          @lock_z = v
          (@memory[:lock_z] ||= {})[@type_key] = v
          true
        end

        # Rovina zamku vo svete (mm) — default je domaca vyska typu
        # (dolna 0, horna UPPER_HANG_Z), pole v Ghost pasiku ju smie prestavit.
        def lock_plane_z
          @lock_z.to_f
        end

        def anchor_point_mm
          @anchors_mm[@anchor] || Calc.anchor_point(@plan.config, @anchor)
        end

        # --- commit ---------------------------------------------------------
        # JEDINA zapisova cesta ghostu — sev R-03. Sprievodny blok (H2/D-76)
        # zmrazi sety kovania zo sablony v TEJ ISTEJ operacii.
        def commit!(transform)
          return nil unless begin_commit!

          inst = nil
          begin
            inst = CabinetBuilder.commit_insert(@model, @plan, transform: transform) do
              @hardware_note = Panel.ghost_freeze_hardware(@model, @hardware) if @hardware && defined?(Panel)
            end
          rescue StandardError => ex
            mark_failed!(ex.message)
            Engine.log_error(ex, 'GhostTool.commit')
            begin
              Panel.ghost_insert_failed(ex) if defined?(Panel)
            rescue StandardError => e2
              Engine.log_error(e2, 'GhostTool.commit (hlaska)')
            end
            GhostTool.release_session(self)
            return nil
          end

          mark_committed!
          # Vyber, refresh panela a peciatka su UZ MIMO operacie — ich zlyhanie
          # NESMIE zabranit zatvoreniu committed session (skrinka uz stoji).
          begin
            Panel.ghost_after_commit(@model, inst, self) if defined?(Panel)
          rescue StandardError => e3
            Engine.log_error(e3, 'GhostTool.commit (po vlozeni)')
          end
          GhostTool.release_session(self)
          inst
        end
      end

      # =====================================================================
      # Tool — SketchUp nastroj. KAZDY callback je obaleny (vynimka v Tool
      # callbacku sa ticho prehltne a nastroj by „zahadne" prestal kreslit).
      # =====================================================================
      class Tool
        attr_reader :model_ref

        def initialize
          @ip = nil
          @attached = false
          @on_top = false
          @finish_pending = false
          @model_ref = nil
          @session = nil # SVOJA session (priradi ju `activate`)
        end

        def attached?
          @attached
        end

        # Sme VRCH tool stacku? Drzime si to sami z `activate` / `suspend` /
        # `resume` / `deactivate` — SketchUp „ktory nastroj je navrchu"
        # spolahlivo neprezradi (`active_tool_id` sa na instanciu nemapuje)
        # a `pop_tool` odoberie vrch bez ohladu na to, kto o neho ziada.
        def on_top?
          @attached && @on_top
        end

        # Ukoncenie sa nedalo vykonat teraz (nie sme navrchu) — dokoncime ho
        # pri najblizsom `resume`.
        def request_finish!
          @finish_pending = true
        end

        def finish_pending?
          @finish_pending
        end

        # Nastroj uz nie je (alebo prave prestava byt) na stacku — dalsi
        # `pop_tool` z nasej strany je zakazany.
        def detach!
          @attached = false
          @on_top = false
        end

        # --- lifecycle ------------------------------------------------------

        # PORADIE JE ZAMERNE: registracia a `@attached` idu ako PRVE, aby sa
        # nastroj dal popnut aj vtedy, keby cokolvek nizsie zlyhalo (review
        # #268 P3-2). Model sa berie zo SESSION — `Sketchup.active_model` je
        # v momente aktivacie uz len domnienka (P3-8).
        def activate
          guarded('activate') do
            # JEDINE miesto, kde sa cita GLOBALNA session — nastroj sa tu na nu
            # VIAZE. Vsade inde uz cita `live_session` (SVOJU), takze stary
            # (suspendovany) ghost nikdy nekresli ani neobsluhuje session,
            # ktora patri NOVEMU ghostu.
            s = GhostTool.session
            @session = s
            @model_ref = (s && s.model) || Sketchup.active_model
            @attached = true
            @on_top = true
            GhostTool.register_tool(self)
            @ip = Sketchup::InputPoint.new
            refresh_status
            view = @model_ref.active_view
            view.invalidate if view
          end
        end

        # Prepnutie na INY nastroj chodi TADIALTO (nie cez onCancel) — session
        # konci. Odpojime sa PRED cancelom, aby `cancel_session` uz neplanoval
        # dalsi `pop_tool` (nastroj prave odchadza).
        def deactivate(view)
          guarded('deactivate') do
            @attached = false
            @on_top = false
            @finish_pending = false
            GhostTool.unregister_tool(self)
            GhostTool.cancel_session('nástroj skončil')
            Sketchup.status_text = ''
            view.invalidate if view
          end
        end

        # reason 0 = Esc · 1 = OPATOVNY vyber toho isteho nastroja · 2 = Undo
        # pocas nastroja. Vo vsetkych troch: session konci, undo sa NEBLOKUJE.
        def onCancel(reason, view)
          guarded('onCancel') do
            GhostTool.cancel_session(cancel_label(reason), deferred: true)
            view.invalidate if view
          end
          true
        end

        # Orbit / Pan (aj cudzi `push_tool` nad nas) — session DRZI, len uz
        # NIE SME VRCH stacku a nesmieme z neho nic odoberat.
        def suspend(view)
          guarded('suspend') do
            @on_top = false
            view.invalidate if view
          end
        end

        # Vrch stacku sa vratil k nam. Ak sme medzitym mali skoncit (session
        # zanikla, kym nad nami visel iny nastroj), dokoncime to TERAZ.
        # POPNEME SEBA, nie „aktivny nastroj" (review #268 kolo 3, P2):
        # po druhom „Vlozit" pocas SUSPENDOVANEHO ghostu je globalnym
        # nastrojom uz NOVY ghost, takze globalne `end_tool` by tento (stary)
        # nikdy neodstranilo a ostal by visiet ako vrch stacku bez session.
        # `GhostTool.pop_tool(self)` je viazany na INSTANCIU: overi, ze sme
        # naozaj navrchu (co `resume` prave garantuje), odoberie PRESNE nas
        # a registraciu noveho ghostu sa ani nedotkne.
        def resume(view)
          guarded('resume') do
            @on_top = true
            if @finish_pending
              @finish_pending = false
              finish_self_soon
            else
              refresh_status
            end
            view.invalidate if view
          end
        end

        # Odlozeny pop SEBA SAMEHO — `pop_tool` sa nesmie volat priamo z Tool
        # callbacku. Ked medzitym vrch stacku znova stratime, `pop_tool` si
        # `finish_pending` nastavi spat a dokonci sa pri dalsom `resume`.
        def finish_self_soon
          UI.start_timer(0, false) { GhostTool.pop_tool(self) }
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.Tool#finish_self_soon')
          nil
        end

        # --- mys ------------------------------------------------------------

        def onMouseMove(_flags, x, y, view)
          guarded('onMouseMove') do
            s = live_session
            next unless s && s.active?

            if s.z_mode == :locked
              pick_locked(s, x, y, view)
            else
              pick_free(s, x, y, view)
            end
            refresh_status
            view.invalidate if view
          end
        end

        def onLButtonDown(_flags, x, y, view)
          guarded('onLButtonDown') do
            s = live_session
            next unless s && s.active?

            # Poloha sa este raz precita z aktualnej pozicie kurzora — klik
            # bez predchadzajuceho pohybu mysou tak nie je slepy.
            s.z_mode == :locked ? pick_locked(s, x, y, view) : pick_free(s, x, y, view)
            unless s.placeable
              Sketchup.status_text = 'Poloha sa z tohto pohľadu nedá určiť — otoč pohľad (Esc zruší vloženie).'
              begin
                Panel.set_status('Z tohto pohľadu sa poloha nedá určiť — otoč pohľad a klikni znova.', true) if defined?(Panel)
              rescue StandardError
                nil
              end
              next
            end

            tr = GhostTool.world_transform(s)
            next unless tr

            s.commit!(tr)
            view.invalidate if view
            # Po commite (aj po neuspesnom) nastroj KONCI — jedno odlozene
            # `pop_tool` a pouzivatel je spat pri svojom povodnom nastroji.
            GhostTool.end_tool(deferred: true) if s.terminal?
          end
        end

        # --- klavesnica -----------------------------------------------------
        # Vlastnene klavesy vracaju true (Tool ich POHLTI), ostatne false.

        def onKeyDown(key, repeat, _flags, view)
          res = false
          guarded('onKeyDown') do
            s = live_session
            next unless s && s.active?

            owned = owned_key(key)
            next unless owned

            res = true
            # Repeat (drzana klavesa) NEMENI stav — reaguje sa na PRVY down.
            next if repeat.to_i > 1

            case owned
            when :left  then s.rotate!(-1)
            when :right then s.rotate!(1)
            when :down  then s.set_z_mode!(:locked)
            when :up    then s.set_z_mode!(:free)
            # GHOST-FB2: prepnutie kotvy NEMENI kliknuty bod — translacia sa
            # prepocita s NOVOU kotvou, takze skrinka „preskoci" tak, aby nova
            # kotva sadla pod kurzor. Jedno pravidlo pre cele ovladanie:
            # kotva je vzdy tam, kde je mys (a rotacia sa toci okolo nej).
            when :alt   then s.cycle_anchor!
            end
            refresh_status
            GhostTool.push_state(s) # GHOST-FB4: pasik drzi krok s klavesami
            view.invalidate if view
          end
          res
        end

        # Alt zachytavame AJ pri pusteni a vraciame true — minimalizuje to
        # aktivaciu menu-baru Windows. (TAB fallback je Scope OUT; cyklovanie
        # kotiev je jedna volatelna metoda `PlacementSession#cycle_anchor!`.)
        # Klavesu vlastnime LEN so ZIVOU session — symetria s `onKeyDown`
        # (review #268 P3-6): po commite/cancele uz nesmieme SketchUpu nic brat.
        def onKeyUp(key, _repeat, _flags, _view)
          res = false
          guarded('onKeyUp') do
            s = live_session
            res = !s.nil? && s.active? && !owned_key(key).nil?
          end
          res
        end

        # --- kreslenie ------------------------------------------------------

        def draw(view)
          guarded('draw') do
            s = live_session
            next unless s && s.active? && s.last_point

            # GHOST-FB1: NATÍVNE zvyraznenie snapu — presne to, co pouzivatel
            # pozna z Move (farebny bod rohu/stredu/hrany + tooltip). Kresli sa
            # v OBOCH rezimoch, lebo inference sa v oboch pyta; `display?`
            # rozhoduje SketchUp (bod na volnej ploche sa nekresli).
            draw_inference(view)

            pts = GhostTool.world_corners(s)
            next if pts.empty?

            dim = !s.placeable
            view.line_stipple = ''
            view.line_width = dim ? 1 : 2
            view.drawing_color = Sketchup::Color.new(*(dim ? DIM_RGB : OUTLINE_RGB))
            EDGES.each { |(a, b)| view.draw(GL_LINES, [pts[a], pts[b]]) }

            # Predna stena — bez nej sa orientacia ghostu neda precitat.
            view.line_width = dim ? 2 : 3
            view.drawing_color = Sketchup::Color.new(*(dim ? DIM_RGB : FRONT_RGB))
            view.draw(GL_LINE_LOOP, FRONT_FACE.map { |i| pts[i] })

            draw_anchor(view, s, dim)
          end
        end

        # Ghost smie visiet DALEKO mimo bounds modelu — bez toho by ho
        # SketchUp orezal.
        def getExtents # rubocop:disable Naming/MethodName — SketchUp API
          bb = Geom::BoundingBox.new
          begin
            s = live_session
            GhostTool.world_corners(s).each { |p| bb.add(p) } if s && s.active? && s.last_point
          rescue StandardError => e
            Engine.log_error(e, 'GhostTool.getExtents')
          end
          bb
        end

        # --- interne --------------------------------------------------------

        private

        # SVOJA a stale ZIVA session. Stary (suspendovany) ghost tak nikdy
        # nekresli ani neobsluhuje session NOVEHO ghostu — nastroj bez svojej
        # session je nemy: nekresli, nevlastni klavesy a klik ignoruje.
        def live_session
          s = GhostTool.session
          return nil unless s && s.equal?(@session) && s.active?

          s
        end

        # GHOST-FB1: `@ip.draw` + `view.tooltip` — vlastnu grafiku snapov si
        # NEKRESLIME (farby a tvary rohu/stredu/hrany su konvencia SketchUpu).
        # Bezi LEN so zivou session (volane z `draw` za guardom) a vlastny
        # rescue ma preto, aby chyba v tooltipe nezhodila kresbu ghostu.
        def draw_inference(view)
          ip = @ip
          return unless ip && ip.valid? && ip.display?

          ip.draw(view)
          view.tooltip = ip.tooltip
        rescue StandardError
          nil
        end

        def draw_anchor(view, s, dim)
          a = GhostTool.world_anchor(s)
          return unless a

          arm = Units.mm(ANCHOR_ARM_MM)
          view.line_width = dim ? 2 : 3
          view.drawing_color = Sketchup::Color.new(*(dim ? DIM_RGB : ANCHOR_RGB))
          [[arm, 0, 0], [0, arm, 0], [0, 0, arm]].each do |(dx, dy, dz)|
            view.draw(GL_LINES, [Geom::Point3d.new(a.x - dx, a.y - dy, a.z - dz),
                                 Geom::Point3d.new(a.x + dx, a.y + dy, a.z + dz)])
          end
        end

        # GHOST-FB1 — ZAMOK VYSKY JE HYBRID. Najprv sa pyta INFERENCE ENGINE
        # (`InputPoint.pick`) presne ako Move: ked snap sedi na REALNEJ
        # geometrii, zoberu sa z neho X/Y (roh / hrana / plocha existujucej
        # skrinky) a Z PREPISE ZAMOK. Bez toho nemalo vkladanie v zamku ZIADNE
        # prichytavanie — pri dolnej so soklom nebolo v rovine Z = 0 co chytit
        # a roh susednej skrinky lezi 720 mm nad nou. Fallback (prazdne miesto,
        # ziadna geometria pod kurzorom) je dnesny priesecnik luca s ROVINOU
        # ZAMKU (world ram, nie drawing axes), takze ghost sedi pod kurzorom aj
        # v uplne prazdnom modeli. Degenerovane guardy (MIN_SIN / MAX_REACH)
        # plati fallback; zdravotny strop plati OBOM.
        def pick_locked(s, x, y, view)
          pt = pick_ip_locked(s, x, y, view) || pick_ray_locked(s, x, y, view)
          s.set_point(pt, !pt.nil?)
        end

        # X/Y zo snapu, Z zo zamku. Nil = inference nedal snap na geometrii
        # (alebo bod nie je zdravy) a rozhoduje fallback.
        def pick_ip_locked(s, x, y, view)
          pos = pick_ip(x, y, view)
          return nil unless pos && ip_on_geometry?

          Calc.lock_point(to_mm_triplet(pos), s.lock_plane_z)
        end

        # ZAMOK berie z inference LEN snap na REALNEJ geometrii (vrchol, hrana,
        # plocha). „Volny" bod inference — teda bod na podlahovej rovine
        # KRESLENIA tam, kde nie je nic — by v zamku KLAMAL:
        #   * pri hornej skrinke lezi rovina zamku 1400 mm nad podlahou, takze
        #     X/Y z podlahy by ghost odsunuli od kurzora,
        #   * pri OTOCENYCH osiach kreslenia by ho odsunuli tiez (zamok ma
        #     drzat SVETOVY ram),
        #   * a v degenerovanom pohlade (rovina za kamerou, walk pohlad) by
        #     obisiel guardy `MIN_SIN` / `MAX_REACH` a spravil nepolozitelny
        #     stav polozitelnym.
        # Ked snap na geometrii nie je, rozhoduje priesecnik luca s rovinou
        # zamku — presne ako pred GHOST-FB.
        def ip_on_geometry?
          ip = @ip
          return false unless ip

          !(ip.vertex.nil? && ip.edge.nil? && ip.face.nil?)
        rescue StandardError
          false
        end

        def pick_ray_locked(s, x, y, view)
          ray = view.pickray(x, y)
          return nil unless ray

          origin = to_mm_triplet(ray[0])
          dir = [ray[1].x.to_f, ray[1].y.to_f, ray[1].z.to_f]
          Calc.ray_plane(origin, dir, s.lock_plane_z)
        end

        # Volna vyska: plny inference point SketchUpu. Aj tu plati ZDRAVOTNY
        # STROP (review #268 P2-1) — inference na extremne vzdialenej geometrii
        # by inak polozil korpus kilometre od zakazky.
        def pick_free(s, x, y, view)
          pos = pick_ip(x, y, view)
          pt = pos ? to_mm_triplet(pos) : nil
          pt = nil unless pt.nil? || Calc.sane_point?(pt)
          s.set_point(pt, !pt.nil?)
        end

        # JEDINE miesto, kde sa pyta inference engine — plati pre OBA rezimy,
        # takze `@ip` je v oboch cerstvy a `draw` z neho vie vykreslit natívne
        # zvyraznenie snapu aj tooltip (GHOST-FB1).
        def pick_ip(x, y, view)
          @ip ||= Sketchup::InputPoint.new
          @ip.pick(view, x, y)
          @ip.valid? ? @ip.position : nil
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.Tool#pick_ip')
          nil
        end

        def to_mm_triplet(pt)
          [Units.to_mm(pt.x), Units.to_mm(pt.y), Units.to_mm(pt.z)]
        end

        def owned_key(key)
          return :left  if vk(:VK_LEFT) == key
          return :right if vk(:VK_RIGHT) == key
          return :up    if vk(:VK_UP) == key
          return :down  if vk(:VK_DOWN) == key
          return :alt   if alt_key?(key)

          nil
        end

        def alt_key?(key)
          %i[VK_MENU VK_ALT].any? { |n| vk(n) == key }
        end

        def vk(name)
          Object.const_defined?(name) ? Object.const_get(name) : nil
        rescue StandardError
          nil
        end

        def cancel_label(reason)
          case reason.to_i
          when 1 then 'opätovný výber nástroja'
          when 2 then 'Späť počas vkladania'
          else 'Esc'
          end
        end

        def refresh_status
          Sketchup.status_text = GhostTool.status_text(live_session)
        rescue StandardError
          nil
        end

        def guarded(label)
          yield
        rescue StandardError => e
          Engine.log_error(e, "GhostTool.Tool##{label}")
          nil
        end
      end
    end
  end
end
