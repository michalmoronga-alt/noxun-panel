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

      # GHOST-D1: SUBJEKT session — CO visi na kurzore. Subjekt urcuje obalku,
      # kotvy, klavesy aj sev commitu; klasicky tok skrinky sa NEMENI.
      SUBJECTS = %i[cabinet board].freeze
      # GHOST-D1: INTERAKCIA session — AKO sa subjekt kladie. Je to EXPLICITNY
      # rozlisovac (nie hadanie podla pritomnosti fazy): `placement` = 1. klik
      # commituje. GHOST-D2: `drawing` = klik je POCIATOK a nasleduju dva tahy
      # (dlzka, sirka) s meracim polom.
      INTERACTIONS = %i[placement drawing].freeze
      DEFAULT_INTERACTION = :placement

      # GHOST-D2: FAZY KRESLENIA. `:origin` = pred klikom pociatku (LEN tu sa
      # menia orientacia a rotacia), `:length` = hlada sa SMER v rovine Z
      # pociatku, `:width` = meria sa po PEVNEJ lokalnej osi, `:done` = obe
      # hodnoty su znama a commit moze prebehnut.
      DRAW_PHASES = %i[origin length width done].freeze
      # Ktory rozmer patri ktorej faze — data, nie kod.
      DRAW_PHASE_DIM = { length: :length, width: :width }.freeze

      # GHOST-FB4: rozumny rozsah locknutej vysky (mm). Horna hranica je
      # „este nabytok" — nad 3 m uz nejde o skrinku, ale o preklep.
      LOCK_Z_MIN_MM = 0.0
      LOCK_Z_MAX_MM = 3000.0

      # Farby ghostu (GL). Zamerne NIE `EdgeCheck::COLORS` (tri stavy olepu) —
      # ghost hovori o polohe, nie o vyrobe. Obrys = neutralna tmava
      # (`--nx-ink-strong`), kotva = rodina vyberu `--nx-select`.
      # PREDNA STENA (fix v0.8.25, Michalov zivy test): povodny tmavy teal
      # `--nx-select` (#107787) sa v modeli MIESAL s tmavym obrysom a s ciernymi
      # hranami geometrie — orientaciu ghostu sa nedalo precitat. Je preto
      # JASNA ZELENA: ta v modeli nekoliduje s nicim (obrys je siva, kotva teal),
      # je citatelna na bielom pozadi aj v tmavej scene a je to jedina farba
      # ghostu, ktora ma „krical". Zostava LINKA (GL_LINE_LOOP) — ghost nema
      # ziadnu vypln, takze niet co dalsie zosvetlovat.
      OUTLINE_RGB = [55, 71, 79].freeze     # #37474f
      FRONT_RGB   = [0, 200, 90].freeze     # jasna zelena #00C85A
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
        #
        # GHOST-D1: pamat je KLUCOVANA DVOJICOU [subjekt, interakcia]. Skrinka
        # a doska maju odlisne ovladanie (doska nema rezim vysky, ma orientaciu)
        # a buduce kreslenie dosky (D2) ma PEVNY pociatok, takze pamatana kotva
        # placementu doň nesmie presiakuť. ORIENTACIA v pamati NEZIJE — kazda
        # nova session ju cita z karty Dosky (karta ju nastavuje pri kazdej
        # materializacii, aj zo sablony).
        def memory(subject = :cabinet, interaction = DEFAULT_INTERACTION)
          s = SUBJECTS.include?(subject) ? subject : :cabinet
          i = INTERACTIONS.include?(interaction) ? interaction : DEFAULT_INTERACTION
          store = (@memory ||= {})
          store[[s, i]] ||= default_memory(s)
        end

        # Tovarenske hodnoty pamate per subjekt. Skrinka drzi aj rezim vysky
        # a locknute vysky PER TYP; doska LEN rotaciu a kotvu.
        def default_memory(subject)
          return { anchor: ANCHORS.first, rotation_index: 0 } if subject == :board

          { anchor: ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
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
        def start(model, plan, hardware: nil, template_ref: nil, note: nil,
                  subject: :cabinet, interaction: DEFAULT_INTERACTION, orientation: nil,
                  locks: nil)
          # Stara session KONCI PRED vznikom novej a jej nastroj sa popne
          # SYNCHRONNE — inak by nam odlozeny `pop_tool` zhodil prave
          # pushnuty novy nastroj (dva ghosty na stacku).
          cancel_session('nové vloženie', deferred: false)
          s = PlacementSession.new(model: model, plan: plan, hardware: hardware,
                                   template_ref: template_ref, note: note,
                                   subject: subject, interaction: interaction,
                                   orientation: orientation, locks: locks)
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
            # GHOST-D2: natívny zámok inferencie (Shift) sa uvolnuje pri
            # KAZDOM konci session, nie az v `Tool#deactivate`. Ten totiz
            # pride az PO `pop_tool` — a ked nastroj prave nie je vrchom
            # stacku, `pop_tool` sa ODLOZI a zamok by na view visel dalej
            # (napr. vymena dokumentu s drzanym Shiftom). Odomyka sa LEN pre
            # kreslenie: iba ono zamyka, takze cudzi zamok pouzivatela
            # (iny nastroj pod nami) sa nesmie zhodit.
            release_inference(s) if s.respond_to?(:drawing?) && s.drawing?
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

          # GHOST-D1: `subject` + `interaction` + `orientation` — pasik podla
          # nich rozhoduje, CO kresli (doska nema ovladace vysky, ma umiestnenie).
          out = { 'active' => true, 'type' => s.type_key,
                  'subject' => s.subject.to_s, 'interaction' => s.interaction.to_s,
                  'anchor' => s.anchor.to_s, 'anchor_label' => ANCHOR_LABELS[s.anchor].to_s,
                  'rotation' => s.rotation_index * 90, 'z_mode' => s.z_mode.to_s,
                  'lock_z' => s.lock_plane_z.to_f,
                  'orientation' => s.orientation.to_s,
                  'orientation_label' => s.orientation_label }
          # GHOST-D2: pasik kreslenia ukazuje FAZU a jej hodnotu (ziadne
          # ovladace vysky ani kotvy — pociatok je pevny).
          if s.drawing?
            out['phase'] = s.draw_phase.to_s
            out['phase_label'] = s.draw_phase_label
            out['phase_value'] = s.draw_phase_value
            out['phase_locked'] = s.draw_phase_locked?
          end
          out
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

          # GHOST-D2: kreslenie ma VLASTNU maticu — rotacia okolo Z o uhol
          # smeroveho vektora, pociatok uz nesie posun zaporneho 2. tahu.
          # Pred klikom pociatku plati este placement matica (doska visi na
          # kurzore v kanonickom smere), aby nahlad nezmizol.
          if s.drawing? && s.draw_started?
            vals = s.draw_matrix_vals
            return nil unless vals

            return Geom::Transformation.new(to_inch_matrix(vals))
          end

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

        # GHOST-D2: uvolnenie natívneho zámku inferencie pre session, ktora
        # ho mohla drzat (kreslenie). Bezargumentove `lock_inference`
        # odomyka; volanie je idempotentne a nikdy nesmie zhodit cancel.
        def release_inference(s)
          m = s.respond_to?(:model) ? s.model : nil
          v = m && m.respond_to?(:active_view) ? m.active_view : nil
          return false unless v && v.respond_to?(:lock_inference)

          v.lock_inference
          true
        rescue StandardError
          false
        end

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

          warn = s.placeable ? '' : ' · POLOHA NEČITATEĽNÁ — otoč pohľad'
          return draw_status_text(s, warn) if s.drawing?

          if s.board?
            # GHOST-D1: doska nema rezim vysky (prichytava sa plne v XYZ) —
            # miesto neho ma UMIESTNENIE, ktore cykli ↑/↓.
            return 'Ghost: klik položí dosku · ←/→ otočiť · ↑/↓ umiestnenie · Alt kotva · Esc zruší ' \
                   "| kotva #{ANCHOR_LABELS[s.anchor]} · #{s.orientation_label.to_s.downcase} · " \
                   "otočenie #{s.rotation_index * 90}°#{warn}"
          end

          lock = s.z_mode == :locked ? "výška #{fmt_mm(s.lock_plane_z)} mm" : 'voľná výška'
          "Ghost: klik položí skrinku · ←/→ otočiť · Alt kotva · ↓ zámok výšky · ↑ voľná výška · Esc zruší " \
            "| kotva #{ANCHOR_LABELS[s.anchor]} · #{lock} · otočenie #{s.rotation_index * 90}°#{warn}"
        end

        def fmt_mm(v)
          f = v.to_f
          (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f)
        end

        # GHOST-D2: status kreslenia. Faza 0 este pripusta ←/→ a ↑/↓, od kliku
        # pociatku uz nie (jedna hranica) — hlaska to hovori priamo.
        def draw_status_text(s, warn = '')
          case s.draw_phase
          when :origin
            'Kreslenie dosky: klik určí počiatok · ←/→ otočiť · ↑/↓ umiestnenie · Esc zruší ' \
              "| #{s.orientation_label.to_s.downcase} · otočenie #{s.rotation_index * 90}°#{warn}"
          when :length, :width
            dim = s.draw_dim
            val = s.draw_phase_value
            over = s.draw_over_limit
            note = if over
                     " · #{Calc.dim_limit_message(dim)} (ťah #{Calc.fmt_dim(over)} mm orezaný)"
                   else
                     ''
                   end
            "#{Calc.dim_label(dim)}: ťahaj myšou alebo napíš číslo a Enter · prázdny Enter = hodnota karty " \
              "(#{Calc.fmt_dim(s.draw_card_value(dim))} mm) · Shift drží smer · Esc zruší " \
              "| #{Calc.fmt_dim(val)} mm#{note}#{warn}"
          else
            'Kreslenie dosky — klikni a doska sa vloží.'
          end
        end
      end

      # GHOST-D2: hlaska po ZAMKNUTYCH klavesach (od kliku pociatku). Zije na
      # MODULE (nie v `class << self`) — konstanta v singleton triede by sa
      # `GhostTool::DRAW_KEYS_LOCKED_MSG` necitala.
      DRAW_KEYS_LOCKED_MSG = 'Orientáciu a rotáciu meň PRED kliknutím počiatku — rovina aj os ťahu ' \
                             'závisia od nich (Esc zruší a začni znova).'

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

        # =================================================================
        # GHOST-D1 — DOSKA. Doska sa do sveta kladie UZ OTOCENA (orientacia je
        # transformacia instancie NAD polohou ghostu), takze obalka aj kotvy sa
        # pocitaju v ramci UMIESTNENEJ dosky.
        # =================================================================

        # ZAVAZNA tabulka rozmerovych osi (package GHOST-D1): ktory VYROBNY
        # rozmer lezi na ktorej lokalnej osi umiestnenej dosky.
        #   leziaca  -> X = dlzka, Y = sirka,  Z = hrubka
        #   stojaca  -> X = dlzka, Y = hrubka, Z = sirka  (doska stoji na hrane)
        #   na_stenu -> TA ISTA tabulka ako stojaca (STANDARD 8.3: zdielana
        #               matica, rozdiel je len v configu — nikdy nie bboxom)
        # Hodnoty su NAZVY rozmerov, nie cisla — je to data, nie kod.
        BOARD_AXES = {
          'leziaca'  => %i[length width thickness].freeze,
          'stojaca'  => %i[length thickness width].freeze,
          'na_stenu' => %i[length thickness width].freeze
        }.freeze
        BOARD_DEFAULT_ORIENTATION = 'leziaca'

        # ZAVAZNA tabulka kotiev dosky (package GHOST-D1). ID aj poradie ALT
        # cyklu su ZHODNE so skrinkou (`ANCHORS`: fl_bottom -> fr_bottom ->
        # fr_top -> fl_top) a „predna" plocha je plocha s NIZSOU lokalnou Y
        # (rovina Y = 0), presne ako pri skrinke. Suradnice su LOKALNE
        # (v ramci umiestnenej dosky) a zapisane NAZVAMI rozmerov:
        #   leziaca  (L, W, T): (0,0,0) · (L,0,0) · (L,0,T) · (0,0,T)
        #   stojaca  (L, T, W): (0,0,0) · (L,0,0) · (L,0,W) · (0,0,W)
        #   na_stenu           : ta ista tabulka ako stojaca
        BOARD_ANCHOR_TABLE = {
          'leziaca' => {
            fl_bottom: %i[zero zero zero].freeze,
            fr_bottom: %i[length zero zero].freeze,
            fr_top:    %i[length zero thickness].freeze,
            fl_top:    %i[zero zero thickness].freeze
          }.freeze,
          'stojaca' => {
            fl_bottom: %i[zero zero zero].freeze,
            fr_bottom: %i[length zero zero].freeze,
            fr_top:    %i[length zero width].freeze,
            fl_top:    %i[zero zero width].freeze
          }.freeze,
          'na_stenu' => {
            fl_bottom: %i[zero zero zero].freeze,
            fr_bottom: %i[length zero zero].freeze,
            fr_top:    %i[length zero width].freeze,
            fl_top:    %i[zero zero width].freeze
          }.freeze
        }.freeze

        # Neznama orientacia (config z novsej verzie) sa TU nepreklasifikuje
        # ticho do modelu — sem sa uz dostane len hodnota, ktoru pustil
        # `BoardBuilder.norm_orientation`; fallback je poistka kresby.
        def norm_board_orientation(orientation)
          o = orientation.to_s
          BOARD_AXES.key?(o) ? o : BOARD_DEFAULT_ORIENTATION
        end

        def board_dim(cfg, name)
          name == :zero ? 0.0 : cfg_num(cfg, name)
        end

        # 8 rohov obalky dosky (mm) v poradi kontraktu kreslenia (EDGES /
        # FRONT_FACE) — rovnaka schema ako `envelope_points` skrinky.
        def board_envelope_points(cfg, orientation)
          ax = BOARD_AXES[norm_board_orientation(orientation)]
          x = board_dim(cfg, ax[0])
          y = board_dim(cfg, ax[1])
          z = board_dim(cfg, ax[2])
          [[0.0, 0.0, 0.0], [x, 0.0, 0.0], [x, y, 0.0], [0.0, y, 0.0],
           [0.0, 0.0, z],   [x, 0.0, z],   [x, y, z],   [0.0, y, z]]
        end

        def board_anchor_point(cfg, orientation, anchor)
          row = BOARD_ANCHOR_TABLE[norm_board_orientation(orientation)]
          spec = row[anchor] || row[ANCHORS.first]
          spec.map { |n| board_dim(cfg, n) }
        end

        def board_anchor_points(cfg, orientation)
          ANCHORS.each_with_object({}) { |a, h| h[a] = board_anchor_point(cfg, orientation, a).freeze }
        end

        # Cyklus umiestnenia (↑/↓): leziaca -> stojaca -> na_stenu -> leziaca.
        # Poradie je poradim klucov tabulky osi — jeden zdroj pravdy.
        def next_board_orientation(orientation, step = 1)
          list = BOARD_AXES.keys
          i = list.index(norm_board_orientation(orientation)) || 0
          list[(i + step.to_i) % list.length]
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

        # =================================================================
        # GHOST-D2 — KRESLENIE DOSKY NA ROZMER. Cista matematika dvoch tahov:
        # faza 1 HLADA SMER v rovine Z pociatku, faza 2 MERIA po PEVNEJ osi.
        # Ziadny SketchUp; vsetko v mm.
        # =================================================================

        # Presnost prijatej hodnoty (mm). Rovnaka ako `board_config`, aby
        # nahlad, config aj geometria niesli TU ISTU hodnotu.
        DIM_ROUND = 2
        # Popisky rozmerov do meracieho pola a statusu.
        DIM_LABELS = { length: 'Dĺžka', width: 'Šírka' }.freeze
        # Zalozne limity, ked `BoardBuilder` este nie je nacitany (harness).
        FALLBACK_DIM_LIMITS = { length: [10.0, 5000.0], width: [10.0, 3000.0] }.freeze
        # Tolerancia axis snapu 1. tahu (POMOCKA, nie obmedzenie): smer blizsi
        # nez 3° k svetovej osi sa na nu prilepi. 45° tah sa nesnapne — presne
        # to overuje test sikmeho tahu.
        AXIS_SNAP_SIN = Math.sin(3.0 * Math::PI / 180.0)
        # Svetove osi, na ktore sa 1. tah smie prilepit (v rovine tahu).
        SNAP_AXES = [[1.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
                     [0.0, 1.0, 0.0], [0.0, -1.0, 0.0]].freeze
        # Kluce zamkov, ktore smu prist z karty (whitelist payloadu `draw_board`).
        DRAW_LOCK_KEYS = %i[length width].freeze

        # --- rozmery: parser, limity, zaokruhlenie -------------------------

        # VLASTNY parser meracieho pola. UPLNA zhoda po `strip`: cislo (bodka
        # aj ciarka) s volitelnym `mm`. NIKDY `String#to_l` ani `to_f` na
        # surovy text — `to_l` na slovenskom Windows padne pri bodke a bez
        # jednotky si vezme sablonu modelu, `to_f` by z „abc2400xyz" spravilo
        # 0.0 a z „2400mmjunk" 2400.0. Vracia Float mm zaokruhleny na 0,01,
        # alebo nil (= neplatny vstup, faza ostava).
        DIM_TEXT_RE = /\A\s*(\d+(?:[.,]\d+)?)\s*(?:mm)?\s*\z/i.freeze

        def parse_mm(text)
          return nil if text.nil?

          m = DIM_TEXT_RE.match(text.to_s.strip)
          return nil unless m

          v = m[1].tr(',', '.').to_f
          return nil unless v.finite?

          round_mm(v)
        end

        # Presnost prijatej hodnoty. Plati pre KAZDY zdroj rozmeru (pisane
        # cislo, zamok, hodnota karty aj tah mysou).
        def round_mm(v)
          f = v.to_f
          return nil unless f.finite?

          f.round(DIM_ROUND)
        end

        # Limity rozmeru z `BoardBuilder::LIMITS` — JEDEN zdroj pravdy s
        # `normalize`, inak by nahlad ukazal 6000 a model dostal 5000.
        def dim_limits(key)
          k = key.to_sym
          if defined?(BoardBuilder) && BoardBuilder.const_defined?(:LIMITS)
            lim = BoardBuilder::LIMITS[k]
            return [lim[0].to_f, lim[1].to_f] if lim
          end
          (FALLBACK_DIM_LIMITS[k] || FALLBACK_DIM_LIMITS[:length]).map(&:to_f)
        end

        def dim_ok?(key, mm)
          v = mm.to_f
          return false unless v.finite?

          lo, hi = dim_limits(key)
          v >= lo && v <= hi
        end

        # Orezanie NAHLADU na limit (tah mysou nad limit ukaze limit, nie
        # 6000). Klik mimo limitu sa odmieta samostatne — orezany nahlad
        # nie je prijatim hodnoty.
        def dim_clamp(key, mm)
          v = mm.to_f
          return nil unless v.finite?

          lo, hi = dim_limits(key)
          return round_mm(lo) if v < lo
          return round_mm(hi) if v > hi

          round_mm(v)
        end

        def dim_label(key)
          DIM_LABELS[key.to_sym] || DIM_LABELS[:length]
        end

        def dim_limit_message(key)
          lo, hi = dim_limits(key)
          "#{dim_label(key)} musí byť od #{lo.round} do #{hi.round} mm."
        end

        # --- zamky faz z karty ---------------------------------------------

        # WHITELIST payloadu `draw_board`. Prijme LEN `length`/`width`,
        # hodnotu ako Float mm, a UZ PRI STARTE ju overi proti limitom —
        # zamknuta faza sa preskakuje, takze neplatna hodnota by sa inak
        # dostala az do geometrie. Vracia [hash, chyba_alebo_nil]; chyba =
        # session sa NESPUSTI.
        def draw_locks(raw)
          return [{}, nil] unless raw.is_a?(Hash)

          out = {}
          DRAW_LOCK_KEYS.each do |k|
            v = raw.key?(k) ? raw[k] : raw[k.to_s]
            next if v.nil?
            # Zamok je CISLO z karty (`locksFlat`), nie text ani Boolean.
            return [{}, "#{dim_label(k)} zamknutá na karte nie je číslo — kreslenie sa nespustilo."] unless v.is_a?(Numeric)

            mm = round_mm(v)
            return [{}, "#{dim_label(k)} zamknutá na karte nie je číslo — kreslenie sa nespustilo."] if mm.nil?
            unless dim_ok?(k, mm)
              return [{}, "#{dim_limit_message(k)} Zamknutá hodnota #{fmt_dim(mm)} mm je mimo — kreslenie sa nespustilo."]
            end

            out[k] = mm
          end
          [out, nil]
        end

        # Cislo do statusu / meracieho pola. Slovenske zobrazenie: desatinna
        # CIARKA a bez zbytocnej koncovej nuly (parser prijima oboje).
        def fmt_dim(v)
          f = v.to_f
          return '' unless f.finite?
          return f.round.to_s if (f - f.round).abs < 0.005

          format('%.2f', f).sub(/0\z/, '').tr('.', ',')
        end

        # --- geometria faz --------------------------------------------------

        def vec_len(v)
          Math.sqrt((v[0].to_f * v[0].to_f) + (v[1].to_f * v[1].to_f) + (v[2].to_f * v[2].to_f))
        end

        def normalize_vec(v)
          return nil unless v.is_a?(Array) && v.length == 3
          return nil unless v.all? { |c| c.is_a?(Numeric) && c.to_f.finite? }

          len = vec_len(v)
          return nil unless len.finite? && len > EPS

          [v[0].to_f / len, v[1].to_f / len, v[2].to_f / len]
        end

        def vec_dot(a, b)
          (a[0].to_f * b[0].to_f) + (a[1].to_f * b[1].to_f) + (a[2].to_f * b[2].to_f)
        end

        # FAZA 1 — SMEROVY VEKTOR. Rovina 1. tahu je VODOROVNA rovina
        # Z = Z pociatku pre VSETKY orientacie (dlzka je vodorovna aj pri
        # stojacej doske), takze zo vzdialenosti pociatok -> kurzor ostane
        # LEN vodorovna zlozka. Nil = nulovy vektor (kurzor sa nepohol) —
        # volajuci potom pouzije KANONICKY smer, nikdy nulu.
        def horizontal_dir(origin, point)
          return nil unless origin && point

          normalize_vec([point[0].to_f - origin[0].to_f, point[1].to_f - origin[1].to_f, 0.0])
        end

        # Vodorovna dlzka 1. tahu (mm) — rovnaka projekcia ako `horizontal_dir`.
        def horizontal_length(origin, point)
          return 0.0 unless origin && point

          dx = point[0].to_f - origin[0].to_f
          dy = point[1].to_f - origin[1].to_f
          l = Math.sqrt((dx * dx) + (dy * dy))
          l.finite? ? l : 0.0
        end

        # POMOCKA (vzor archivneho Ghost 2.0): smer blizsi nez `AXIS_SNAP_SIN`
        # k svetovej osi sa na nu prilepi. Nie je to obmedzenie — sikmy tah
        # ostava sikmy (test 45°).
        def axis_snap(dir)
          d = normalize_vec(dir)
          return nil unless d

          best = nil
          best_sin = nil
          SNAP_AXES.each do |ax|
            dot = vec_dot(d, ax)
            next if dot <= 0.0
            # sinus odchylky od osi (vektory su jednotkove)
            s = Math.sqrt([1.0 - (dot * dot), 0.0].max)
            if best_sin.nil? || s < best_sin
              best_sin = s
              best = ax
            end
          end
          return d if best.nil? || best_sin > AXIS_SNAP_SIN

          [best[0], best[1], best[2]]
        end

        # KANONICKY smer = lokalna +X podla rotacie session (←/→ vo faze 0).
        # Pouzije sa, ked je smerovy vektor NULOVY (cislo napisane hned, obe
        # fazy zamknute) — nulovy vektor sa NIKDY nedostane do transformacie.
        def canonical_dir_x(rotation_index)
          i = norm_rotation(rotation_index)
          [COS[i], SIN[i], 0.0]
        end

        # FAZA 2 — PEVNA os merania sirky v ramci UMIESTNENEJ dosky:
        #   leziaca             -> vodorovna kolmica na 1. tah (Z x dir_x)
        #   stojaca / na_stenu  -> svetova +Z (sirka je vyska pilastra)
        # Vracia jednotkovy vektor, alebo nil pri degenerovanom `dir_x`.
        def board_measure_axis(orientation, dir_x)
          o = norm_board_orientation(orientation)
          return [0.0, 0.0, 1.0] unless o == BOARD_DEFAULT_ORIENTATION

          d = normalize_vec(dir_x)
          return nil unless d

          # Z x d — vodorovna, pravotociva ku dvojici (d, Z).
          normalize_vec([-d[1], d[0], 0.0])
        end

        # Znamienkova projekcia bodu na priamku (mm). Zaporna hodnota = 2. tah
        # ide na opacnu stranu; POCIATOK sa vtedy posunie o −sirka po tej istej
        # osi a osi ostavaju pravotocive (ziadne obratenie `dir_y`).
        def project_on_axis(origin, axis, point)
          return nil unless origin && point

          a = normalize_vec(axis)
          return nil unless a

          v = [point[0].to_f - origin[0].to_f, point[1].to_f - origin[1].to_f,
               point[2].to_f - origin[2].to_f]
          return nil unless v.all?(&:finite?)

          p = vec_dot(v, a)
          p.finite? ? p : nil
        end

        # FALLBACK FAZY 2 vo VOLNOM PRIESTORE: najblizsi bod PRIAMKY
        # (pociatok + s*os) k lucu z kamery. Premietnutie z vodorovnej roviny
        # by pri zvislej sirke pilastra dalo konstantnu vysku, preto sa meria
        # proti lucu — s TYM ISTYM kontraktom degeneracie ako `ray_plane`:
        #   * konecne a nenulove vektory,
        #   * UHLOVY PRAH medzi lucom a osou (takmer rovnobezny luc =
        #     takmer nulovy menovatel -> vysledok odleti alebo zmeni
        #     znamienko sirky),
        #   * parameter luca `t >= 0` (polpriamka OD kamery, nie za nou),
        #   * vysledok v zdravom dosahu (`MAX_REACH_MM`).
        # Nil = faza NEPOKROCI a status to povie.
        def ray_axis_point(ray_origin, ray_dir, line_origin, line_axis)
          return nil unless ray_origin && line_origin

          d = normalize_vec(ray_dir)
          a = normalize_vec(line_axis)
          return nil unless d && a

          # sin uhla medzi lucom a osou; |d x a| pri jednotkovych vektoroch
          cross = [(d[1] * a[2]) - (d[2] * a[1]),
                   (d[2] * a[0]) - (d[0] * a[2]),
                   (d[0] * a[1]) - (d[1] * a[0])]
          sin_ang = vec_len(cross)
          return nil unless sin_ang.finite? && sin_ang > MIN_SIN

          w0 = [ray_origin[0].to_f - line_origin[0].to_f,
                ray_origin[1].to_f - line_origin[1].to_f,
                ray_origin[2].to_f - line_origin[2].to_f]
          return nil unless w0.all?(&:finite?)

          b = vec_dot(d, a)
          denom = 1.0 - (b * b) # = sin^2, uz overene proti MIN_SIN
          return nil unless denom.finite? && denom > EPS

          dw = vec_dot(d, w0)
          aw = vec_dot(a, w0)
          t = ((b * aw) - dw) / denom
          s = (aw - (b * dw)) / denom
          return nil unless t.finite? && s.finite?
          return nil unless t >= 0.0
          return nil unless t <= MAX_REACH_MM

          pt = [line_origin[0].to_f + (s * a[0]),
                line_origin[1].to_f + (s * a[1]),
                line_origin[2].to_f + (s * a[2])]
          sane_point?(pt) ? pt : nil
        end

        # KANONICKA transformacia KRESLENEJ dosky. Rotacia je okolo svetovej
        # osi Z o uhol smeroveho vektora (`dir_x` je jednotkovy a vodorovny),
        # takze matica je ortonormalna a PRAVOTOCIVA — `rigid_matrix?` (R-03)
        # ju prijme. Pociatok uz nesie posun zaporneho 2. tahu.
        # Vystup: 16 cisel v SketchUp poradi (po stlpcoch), mm.
        def draw_matrix(origin:, dir_x:)
          d = normalize_vec([dir_x[0], dir_x[1], 0.0])
          return nil unless d && origin && sane_point?(origin)

          c = d[0]
          s = d[1]
          [c,   s,   0.0, 0.0,
           -s,  c,   0.0, 0.0,
           0.0, 0.0, 1.0, 0.0,
           origin[0].to_f, origin[1].to_f, origin[2].to_f, 1.0]
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
                    :rotation_index, :anchor, :z_mode, :last_point,
                    :anchors_mm, :cancel_reason, :hardware_note, :type_key,
                    :subject, :interaction, :orientation

        def initialize(model:, plan:, hardware: nil, template_ref: nil, note: nil, memory: nil,
                       subject: :cabinet, interaction: DEFAULT_INTERACTION, orientation: nil,
                       locks: nil)
          @model = model
          @plan = plan
          @hardware = hardware
          @template_ref = template_ref
          @note = note.to_s
          @state = :active
          # GHOST-D1: subjekt a interakcia su EXPLICITNE (neodvodzuju sa z tvaru
          # planu ani z pritomnosti fazy) — riadia obalku, kotvy, klavesy,
          # payload pasika aj sev commitu.
          @subject = SUBJECTS.include?(subject) ? subject : :cabinet
          @interaction = INTERACTIONS.include?(interaction) ? interaction : DEFAULT_INTERACTION
          # GHOST-D2: kreslenie existuje LEN pre dosku — skrinka spadne spat
          # na umiestnovanie (jej sev ani obalka fazy nepoznaju).
          @interaction = DEFAULT_INTERACTION if @interaction == :drawing && @subject != :board
          # GHOST-FB3: session STARTUJE Z PAMATE modulu (kotva, rotacia, rezim
          # vysky, locknute vysky) — do vypnutia SketchUpu si nastroj pamata,
          # ako s nim pouzivatel naposledy pracoval. Prva session v behu
          # dostane tovarenske hodnoty: lava dolna kotva, 0°, zamok.
          # GHOST-D1: pamat je per [subjekt, interakcia] — skrinka a doska si
          # navzajom kotvu ani rotaciu neprepisuju.
          @memory = memory || GhostTool.memory(@subject, @interaction)
          @rotation_index = Calc.norm_rotation(@memory[:rotation_index])
          @anchor = ANCHORS.include?(@memory[:anchor]) ? @memory[:anchor] : ANCHORS.first
          @last_point = nil
          @placeable = false
          @commit_started = false
          @stamp_attempted = false
          @hardware_note = ''
          # Orientacia prichadza z KARTY (payload `insert_board`) — session je
          # jej jediny drzitel; do pamate modulu sa NEZAPISUJE.
          @orientation = orientation
          # GHOST-D2: CISELNY snapshot zamkov karty (`locksFlat('board')`),
          # uz zvalidovany volajucim proti `BoardBuilder::LIMITS`. Zamky ziju
          # LEN v session — do vyrobneho configu sa NIKDY nedostanu.
          @draw_locks = normalize_locks(locks)
          board? ? init_board! : init_cabinet!
          init_draw! if drawing?
        end

        # --- subjekt ---------------------------------------------------------

        def board?
          @subject == :board
        end

        def cabinet?
          @subject == :cabinet
        end

        def placement?
          @interaction == :placement
        end

        def drawing?
          @interaction == :drawing
        end

        # =================================================================
        # GHOST-D2 — FAZOVY AUTOMAT KRESLENIA
        #   :origin -> klik urci POCIATOK (pevna kotva `fl_bottom`)
        #   :length -> hlada sa SMER v rovine Z pociatku (dlzka = |vektor|)
        #   :width  -> meria sa po PEVNEJ osi (leziaca vodorovne, stojaca +Z)
        #   :done   -> obe hodnoty su znama, commit moze prebehnut
        # Zamknuta faza sa PRESKAKUJE; ked sa preskoci faza dlzky, smer je
        # KANONICKY (lokalna +X podla rotacie session).
        # =================================================================

        attr_reader :draw_phase, :draw_origin, :draw_dir_x, :draw_length_mm,
                    :draw_width_mm, :draw_locks

        # Pociatok kreslenia je PEVNY (`fl_bottom`) a pamatanu kotvu
        # placementu IGNORUJE — ALT v kresleni nema vyznam.
        def init_draw!
          @anchor = ANCHORS.first
          @draw_phase = :origin
          @draw_origin = nil
          @draw_dir_x = nil
          @draw_locked_dir = nil
          @draw_length_mm = nil
          @draw_width_mm = nil
          @draw_preview_length = nil
          @draw_preview_width = nil
          @draw_over_limit = nil
          @draw_canonical = false
          @draw_width_sign = 1.0
        end

        def normalize_locks(raw)
          return {} unless raw.is_a?(Hash)

          out = {}
          Calc::DRAW_LOCK_KEYS.each do |k|
            v = raw.key?(k) ? raw[k] : raw[k.to_s]
            next unless v.is_a?(Numeric)

            mm = Calc.round_mm(v)
            out[k] = mm if mm && Calc.dim_ok?(k, mm)
          end
          out
        end

        def draw_locked?(dim)
          @draw_locks.key?(dim.to_sym)
        end

        def draw_started?
          drawing? && !@draw_origin.nil?
        end

        def draw_ready?
          drawing? && @draw_phase == :done &&
            !@draw_origin.nil? && !@draw_dir_x.nil? &&
            !@draw_length_mm.nil? && !@draw_width_mm.nil?
        end

        # Bol smer 1. tahu KANONICKY (nulovy vektor / preskocena faza)?
        # Status to hovori pouzivatelovi.
        def draw_canonical_dir?
          @draw_canonical ? true : false
        end

        # Rozmer, ktory AKTUALNA faza meria (nil mimo faz merania).
        def draw_dim
          DRAW_PHASE_DIM[@draw_phase]
        end

        def draw_phase_label
          d = draw_dim
          d ? Calc.dim_label(d) : ''
        end

        def draw_phase_locked?
          d = draw_dim
          !d.nil? && draw_locked?(d)
        end

        # ZIVA hodnota aktualnej fazy (nahlad) — do pasika aj meracieho pola.
        def draw_phase_value
          case @draw_phase
          when :length then (@draw_preview_length || @draw_length_mm)
          when :width  then (@draw_preview_width || @draw_width_mm)
          end
        end

        # Hodnota KARTY pre danu fazu (prazdny Enter ju vedome prevezme).
        def draw_card_value(dim)
          Calc.round_mm(Calc.cfg_num(@plan.config, dim.to_sym))
        end

        # KLIK POCIATKU. Pociatok je bod, ktory ghost prave drzi (plne XYZ
        # prichytenie ako pri umiestnovani). Vrati novy stav fazy.
        def begin_draw!(pt_mm)
          return false unless drawing? && @draw_phase == :origin
          return false unless pt_mm && Calc.sane_point?(pt_mm)

          @draw_origin = [pt_mm[0].to_f, pt_mm[1].to_f, pt_mm[2].to_f].freeze
          @last_point = @draw_origin
          advance_draw!(:origin)
          true
        end

        # Posun na dalsiu NEZAMKNUTU fazu. Zamknuta faza sa vyplni hodnotou
        # zamku; pri preskocenej faze dlzky je smer KANONICKY.
        def advance_draw!(from)
          phase = from
          if phase == :origin
            phase = :length
            if draw_locked?(:length)
              apply_canonical_dir!
              @draw_length_mm = @draw_locks[:length]
              phase = :width
            end
          elsif phase == :length
            phase = :width
          elsif phase == :width
            phase = :done
          end
          if phase == :width && draw_locked?(:width)
            @draw_width_mm = @draw_locks[:width]
            @draw_width_sign = 1.0
            phase = :done
          end
          @draw_phase = phase
          reset_phase_preview!
          phase
        end

        # Zmena fazy: nahlad predoslej fazy zanika a ZAMOK SMERU sa VZDY
        # uvolnuje (zamok z 1. fazy nesmie obmedzit 2.). Priznak kanonickeho
        # smeru ani znamienko sirky sa TU NEMENIA — patria uz POTVRDENEJ
        # hodnote, nie nahladu.
        def reset_phase_preview!
          @draw_preview_length = nil
          @draw_preview_width = nil
          @draw_over_limit = nil
          @draw_locked_dir = nil
        end

        # Smer bez tahu = lokalna +X podla rotacie session (←/→ vo faze 0).
        # NULOVY vektor sa NIKDY nedostane do transformacie.
        def apply_canonical_dir!
          @draw_dir_x = Calc.canonical_dir_x(@rotation_index).freeze
          @draw_canonical = true
          @draw_dir_x
        end

        # ZIVY NAHLAD 1. fazy: smer + dlzka z bodu pod kurzorom. Nulovy tah
        # necha smer nedotknuty (kanonicky sa dosadi az pri POTVRDENI).
        # `over_limit` = tah presiahol limit -> nahlad OREZANY, status hlasi.
        def preview_length!(pt_mm, snap: true)
          return false unless drawing? && @draw_phase == :length

          if @draw_locked_dir
            # SHIFT: smer je ZAMKNUTY — pohyb kurzora ho uz nesmie zmenit,
            # meria sa LEN priemet na zamknuty smer.
            @draw_dir_x = @draw_locked_dir
            @draw_canonical = false
            proj = Calc.project_on_axis(@draw_origin, @draw_locked_dir, pt_mm)
            raw = proj.nil? ? 0.0 : [proj, 0.0].max
          else
            dir = Calc.horizontal_dir(@draw_origin, pt_mm)
            dir = Calc.axis_snap(dir) if dir && snap
            if dir
              @draw_dir_x = dir.freeze
              @draw_canonical = false
            end
            raw = Calc.horizontal_length(@draw_origin, pt_mm)
          end
          store_preview(:length, raw)
        end

        # ZIVY NAHLAD 2. fazy: znamienkovy priemet na PEVNU os. Zaporny tah
        # posunie POCIATOK (osi ostavaju pravotocive) — riesi to transformacia.
        def preview_width!(signed_mm)
          return false unless drawing? && @draw_phase == :width
          return false if signed_mm.nil?

          @draw_width_sign = signed_mm.to_f.negative? ? -1.0 : 1.0
          store_preview(:width, signed_mm.to_f.abs)
        end

        # Poloha sa z tohto pohladu nedala urcit (degenerovany luc) — ghost
        # DRZI poslednu platnu polohu, len sa nesmie polozit. `set_point` sa
        # v kresleni pouzit neda: `@last_point` je POCIATOK, nie kurzor.
        def set_placeable!(flag)
          @placeable = flag ? true : false
        end

        def store_preview(dim, raw)
          v = Calc.round_mm(raw)
          return false if v.nil?

          @draw_over_limit = Calc.dim_ok?(dim, v) ? nil : v
          shown = Calc.dim_clamp(dim, v)
          if dim == :length
            @draw_preview_length = shown
          else
            @draw_preview_width = shown
          end
          true
        end

        # Presiahol ZIVY tah limit? (nahlad je orezany, klik sa odmietne)
        def draw_over_limit
          @draw_over_limit
        end

        # POTVRDENIE fazy (klik / cislo + Enter / prazdny Enter / zamok).
        # Limit sa overuje PRED posunom fazy pre KAZDY zdroj rozmeru.
        # Vracia true = faza sa posunula, false = hodnota odmietnuta.
        # `typed:` = hodnota prisla ZO VSTUPU (napisane cislo, hodnota karty
        # pri prazdnom Enteri), nie z projekcie kurzora.
        def confirm_draw!(dim, mm, sign: nil, typed: false)
          return false unless drawing?
          return false unless draw_dim == dim.to_sym

          v = Calc.round_mm(mm)
          return false if v.nil? || !Calc.dim_ok?(dim, v)

          if dim.to_sym == :length
            # Rotaciu okolo Z urcuje smerovy vektor v okamihu POTVRDENIA.
            # NULOVY vektor sa NIKDY nedostane do transformacie — namiesto
            # neho plati KANONICKY smer (lokalna +X podla rotacie session).
            apply_canonical_dir! if @draw_dir_x.nil?
            @draw_length_mm = v
          else
            # Znamienko nesie MYS; napisane cislo, hodnota karty aj zamok
            # znamenaju vzdy KLADNY smer (inak by stary tah prezil do textu).
            @draw_width_sign = sign.to_f unless sign.nil?
            @draw_width_mm = v
          end
          # Codex #299 P2: NAPISANE cislo (a hodnota karty pri prazdnom
          # Enteri) urcuje rozmer UPLNE — projekcia kurzora doň uz nevstupuje.
          # Ked teda degenerovany pohlad (takmer rovnobezny luc, rovina za
          # kamerou) predtym oznacil session za NEUMIESTNITELNU, cislo ju
          # znova umiestnitelnou UROBI: inak by pouzivatel musel hybat mysou
          # a klikat v presne tej situacii, ktoru mal cislom obist. Pociatok
          # je uz kliknuty a smer je bud z tahu, alebo KANONICKY, takze
          # transformacia je plne urcena.
          set_placeable!(true) if typed
          advance_draw!(@draw_phase)
          true
        end

        # Znamienko posledneho 2. tahu (−1 = doska rastie na opacnu stranu).
        def draw_width_sign
          @draw_width_sign.nil? ? 1.0 : @draw_width_sign
        end

        # SHIFT: zamkne SMER, ktory je prave na obrazovke. Zamknuty smer plati
        # aj vo VOLNOM PRIESTORE — fallback sa nan premietne, takze pohyb
        # kurzora po zamknuti smer dosky uz nezmeni.
        def lock_draw_dir!(dir = nil)
          return false unless drawing? && @draw_phase == :length

          d = Calc.normalize_vec(dir || @draw_dir_x || Calc.canonical_dir_x(@rotation_index))
          return false unless d

          @draw_locked_dir = [d[0], d[1], 0.0]
          @draw_locked_dir = Calc.normalize_vec(@draw_locked_dir)
          return false unless @draw_locked_dir

          @draw_locked_dir.freeze
          @draw_dir_x = @draw_locked_dir
          true
        end

        def release_draw_dir!
          @draw_locked_dir = nil
          true
        end

        def draw_locked_dir
          @draw_locked_dir
        end

        # POCIATOK POUZITY V TRANSFORMACII. Zaporny 2. tah posunie pociatok
        # o −sirka po osi merania; osi ostavaju PRAVOTOCIVE (ziadne obratenie
        # `dir_y`, Codex #288 P1).
        def draw_placement_origin
          return nil unless @draw_origin && @draw_dir_x

          w = @draw_width_mm || @draw_preview_width
          return @draw_origin if w.nil? || draw_width_sign >= 0.0

          ax = Calc.board_measure_axis(@orientation, @draw_dir_x)
          return @draw_origin unless ax

          [@draw_origin[0] - (ax[0] * w), @draw_origin[1] - (ax[1] * w),
           @draw_origin[2] - (ax[2] * w)]
        end

        # 16 cisel transformacie kreslenej dosky (mm). Nil = este niet smeru.
        def draw_matrix_vals
          dir = @draw_dir_x || (@draw_phase == :origin ? nil : Calc.canonical_dir_x(@rotation_index))
          o = draw_placement_origin
          return nil unless dir && o

          Calc.draw_matrix(origin: o, dir_x: dir)
        end

        # Rozmery ZIVEHO nahladu — obalka sa kresli z NICH, nie zo zmrazeneho
        # configu (ten drzi hodnoty karty). Nezname rozmery drzia hodnotu
        # karty, aby bola doska citatelna uz pri prvom tahu.
        def draw_preview_dims
          { length: @draw_length_mm || @draw_preview_length || draw_card_value(:length),
            width: @draw_width_mm || @draw_preview_width || draw_card_value(:width),
            thickness: Calc.cfg_num(@plan.config, :thickness) }
        end

        # Obalka ZIVEHO nahladu (8 rohov, mm) — `draw` aj `getExtents`.
        def draw_corners_mm
          Calc.board_envelope_points(draw_preview_dims, @orientation)
        end

        # Obalka ghostu. Pri UMIESTNOVANI je zmrazena (spocitana RAZ zo
        # zmrazeneho configu), pri KRESLENI sa meni s kazdym tahom — preto
        # jeden citac pre oboje (`draw`, `getExtents`, `world_corners`).
        def corners_mm
          drawing? ? draw_corners_mm : @corners_mm
        end

        # GHOST-D1: doska sa prichytava PLNE V XYZ (`pick_free` semantika) —
        # ziadny zamok vysky z pamate skrinky, inak by roh hornej skrinky
        # skoncil na zamknutej vyske. Orientacia zije LEN v session a kazda
        # nova ju cita z karty Dosky.
        def init_board!
          o = @orientation = norm_orientation(@orientation)
          @z_mode = :free
          @lock_z = 0.0
          @type_key = 'board'
          refresh_board_geometry!(o)
        end

        def init_cabinet!
          # OBA typy startuju v ZAMKU svojej domacej vysky (horna nikdy
          # nestartuje vo free Z — zachovava dnesne spravanie buildera), kym
          # si pouzivatel v tomto behu nezvolil inak.
          @z_mode = Z_MODES.include?(@memory[:z_mode]) ? @memory[:z_mode] : :locked
          # Locknuta vyska je per TYP skrinky. Default sa NEDUPLIKUJE — berie
          # sa z planu (`home_z`: dolna 0, horna UPPER_HANG_Z = 1400).
          t = Calc.cfg_str(@plan.config, :type)
          @type_key = t.empty? ? 'lower' : t
          store = (@memory[:lock_z] ||= {})
          store[@type_key] = @plan.home_z.to_f unless store.key?(@type_key)
          @lock_z = store[@type_key].to_f
          # Obalka aj kotvy sa pocitaju RAZ zo ZMRAZENEHO configu (audit FIX 5)
          # — v `draw` sa uz nikdy nic neplanuje.
          @corners_mm = Calc.envelope_points(@plan.config).map(&:freeze).freeze
          @anchors_mm = Calc.anchor_points(@plan.config).freeze
        end

        # Obalka aj kotvy dosky zavisia od ORIENTACIE — prepocitavaju sa pri
        # jej zmene (↑/↓), inak ostavaju zmrazene ako pri skrinke.
        def refresh_board_geometry!(o)
          @corners_mm = Calc.board_envelope_points(@plan.config, o).map(&:freeze).freeze
          @anchors_mm = Calc.board_anchor_points(@plan.config, o).freeze
        end

        def norm_orientation(o)
          s = o.to_s
          Calc::BOARD_AXES.key?(s) ? s : Calc::BOARD_DEFAULT_ORIENTATION
        end

        # Popisok umiestnenia do pasika a statusu (prazdny pre skrinku).
        def orientation_label
          return '' unless board?

          if defined?(BoardBuilder)
            lbl = BoardBuilder::ORIENTATION_LABELS[@orientation.to_s]
            return lbl.to_s unless lbl.nil?
          end
          @orientation.to_s
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

        # Rezim vysky ma LEN skrinka — doska sa prichytava plne v XYZ.
        def set_z_mode!(mode)
          return false if board?
          return false unless Z_MODES.include?(mode)
          return false if @z_mode == mode

          @z_mode = mode
          @memory[:z_mode] = mode
          true
        end

        # GHOST-D1: cyklus UMIESTNENIA dosky (↑/↓). Meni obalku aj kotvy —
        # doska sa do sveta kladie uz otocena. Do pamate modulu sa NEZAPISUJE:
        # orientacia patri karte, nie pracovnemu navyku nastroja.
        def cycle_orientation!(step = 1)
          return false unless board?

          o = Calc.next_board_orientation(@orientation, step)
          return false if o == @orientation

          @orientation = o
          refresh_board_geometry!(o)
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
          return @anchors_mm[@anchor] if @anchors_mm[@anchor]

          board? ? Calc.board_anchor_point(@plan.config, @orientation, @anchor)
                 : Calc.anchor_point(@plan.config, @anchor)
        end

        # --- commit ---------------------------------------------------------
        # JEDINA zapisova cesta ghostu — sev SUBJEKTU (R-03 pre skrinku,
        # GHOST-D1 pre dosku). Sprievodny blok (H2/D-76) zmrazi sety kovania
        # zo sablony v TEJ ISTEJ operacii.
        #
        # BARIERA PRED MUTACIOU (GHOST-D1): `ScaleWatch.flush_pending!` bezi
        # PRED `begin_commit!` — cakajuca kopia/scale by sa inak prilepila
        # k vlozeniu a poskodila Redo. Pri `false` (limit AJ vynimka — API ich
        # nerozlisuje) sa vracia EXPLICITNY `:blocked`: session ZOSTAVA v stave
        # umiestnovania a nevzniklo ziadne ID, geometria, krok Spat ani peciatka.
        def commit!(transform)
          return :blocked unless settle_observer!
          return nil unless begin_commit!

          inst = nil
          begin
            inst = commit_subject!(transform)
          rescue StandardError => ex
            mark_failed!(ex.message)
            Engine.log_error(ex, 'GhostTool.commit')
            begin
              Panel.ghost_insert_failed(ex, self) if defined?(Panel)
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

        # GHOST-D2: plan, ktory ide do commitu. Umiestnovanie pouzije plan
        # zmrazeny PRED startom ghostu; kreslenie z neho ODVODI novy zmrazeny
        # plan s nakreslenymi rozmermi (`BoardBuilder.replan` — bez opatovneho
        # citania katalogu, vyrobny snapshot ostava). `replan` NIC nemutuje,
        # takze smie bezat az za barierou observera.
        def commit_plan
          return @plan unless drawing? && draw_ready?

          BoardBuilder.replan(@plan, length: @draw_length_mm, width: @draw_width_mm)
        end

        # Sev podla SUBJEKTU. Doske ide orientacia SAMOSTATNYM argumentom —
        # `stojaca` a `na_stenu` vedome zdielaju maticu (STANDARD 8.3), takze
        # z transformacie sa odvodit neda.
        def commit_subject!(transform)
          if board?
            BoardBuilder.commit_insert(@model, commit_plan, transform: transform, orientation: @orientation)
          else
            CabinetBuilder.commit_insert(@model, @plan, transform: transform) do
              @hardware_note = Panel.ghost_freeze_hardware(@model, @hardware) if @hardware && defined?(Panel)
            end
          end
        end

        # Observer do POKOJA pred otvorenim vlastnej operacie. `true` aj ked
        # ScaleWatch v tomto behu neexistuje (headless harness).
        def settle_observer!
          return true unless defined?(ScaleWatch) && ScaleWatch.respond_to?(:flush_pending!)

          ScaleWatch.flush_pending!(@model) ? true : false
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.settle_observer!')
          false
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
          # GHOST-D2: meracie pole sa rozhoduje UZ TU, nie v `activate` —
          # SketchUp smie zavolat `enableVCB?` EST PRED aktivaciou a vtedy by
          # nezmrazena hodnota nechala Measurements na cely zivot nastroja
          # vypnute. `Tool.new` vznika v `GhostTool.start` HNED za priradenim
          # session, takze globalna session je tu uz ta spravna.
          s = GhostTool.session
          @vcb = !s.nil? && s.respond_to?(:drawing?) && s.drawing?
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
            # GHOST-D2: meracie pole je zapnute pocas CELEHO zivota nastroja
            # (probe 5.9.: fazovo podmienene `enableVCB?` by Measurements po
            # aktivacii nechalo vypnute a pisane rozmery by po prvom kliku
            # neprisli). Hodnota vznikla uz v `initialize` — TU sa len potvrdi
            # nad session, na ktoru sa nastroj naozaj naviazal.
            @vcb = !s.nil? && s.respond_to?(:drawing?) && s.drawing? unless s.nil?
            refresh_status
            refresh_vcb
            view = @model_ref.active_view
            view.invalidate if view
          end
        end

        # GHOST-D2: `true` = SketchUp zapne pole Measurements a posle nam
        # `onUserText` / `onReturn`. Hodnota je zmrazena z `activate`.
        def enableVCB? # rubocop:disable Naming/MethodName — SketchUp API
          @vcb ? true : false
        end

        # Prepnutie na INY nastroj chodi TADIALTO (nie cez onCancel) — session
        # konci. Odpojime sa PRED cancelom, aby `cancel_session` uz neplanoval
        # dalsi `pop_tool` (nastroj prave odchadza).
        def deactivate(view)
          guarded('deactivate') do
            # GHOST-D2: natívny zamok inferencie sa uvolnuje AKO PRVE — zamok
            # z drzaneho Shiftu nesmie prezit nastroj (visel by aj natívnym
            # nastrojom, ktore prídu po nas).
            release_inference!(view)
            @ip_origin = nil
            @attached = false
            @on_top = false
            @finish_pending = false
            GhostTool.unregister_tool(self)
            GhostTool.cancel_session('nástroj skončil')
            Sketchup.status_text = ''
            clear_vcb
            view.invalidate if view
          end
        end

        # reason 0 = Esc · 1 = OPATOVNY vyber toho isteho nastroja · 2 = Undo
        # pocas nastroja. Vo vsetkych troch: session konci, undo sa NEBLOKUJE.
        def onCancel(reason, view)
          guarded('onCancel') do
            # GHOST-D2: Esc / Undo / opatovny vyber = koniec CELEJ session
            # (0 krokov Spat, bez peciatky) a zamok inferencie sa uvolni.
            release_inference!(view)
            GhostTool.cancel_session(cancel_label(reason), deferred: true)
            clear_vcb
            view.invalidate if view
          end
          true
        end

        # Orbit / Pan (aj cudzi `push_tool` nad nas) — session DRZI, len uz
        # NIE SME VRCH stacku a nesmieme z neho nic odoberat.
        def suspend(view)
          guarded('suspend') do
            # GHOST-D2: Orbit/Pan nad nami — zamok inferencie sa uvolni (inak
            # by po navrate drzal smer, ktory uz nikto nedrzi).
            release_inference!(view)
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
            release_inference!(view)
            @on_top = true
            if @finish_pending
              @finish_pending = false
              finish_self_soon
            else
              refresh_status
              refresh_vcb
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

            @mx = x
            @my = y
            if s.drawing? && s.draw_started?
              track_draw(s, x, y, view)
            else
              pick_point(s, x, y, view)
            end
            refresh_status
            refresh_vcb
            GhostTool.push_state(s) if s.drawing?
            view.invalidate if view
          end
        end

        def onLButtonDown(_flags, x, y, view)
          guarded('onLButtonDown') do
            s = live_session
            next unless s && s.active?

            @mx = x
            @my = y
            # GHOST-D2: v kresleni klik NEcommituje hned — najprv urci
            # pociatok, potom potvrdzuje fazy. Commit robi az posledna faza.
            if s.drawing?
              next unless draw_click(s, x, y, view)
            end

            # Poloha sa este raz precita z aktualnej pozicie kurzora — klik
            # bez predchadzajuceho pohybu mysou tak nie je slepy.
            pick_point(s, x, y, view) unless s.drawing?
            commit_session(s, view)
          end
        end

        # JEDINA cesta z Toolu do commitu — vola ju klik aj potvrdenie
        # meracieho pola (`onUserText` / `onReturn` v poslednej faze).
        def commit_session(s, view)
          unless s.placeable
            Sketchup.status_text = 'Poloha sa z tohto pohľadu nedá určiť — otoč pohľad (Esc zruší vloženie).'
            begin
              Panel.set_status('Z tohto pohľadu sa poloha nedá určiť — otoč pohľad a klikni znova.', true) if defined?(Panel)
            rescue StandardError
              nil
            end
            return false
          end

          tr = GhostTool.world_transform(s)
          return false unless tr

          res = s.commit!(tr)
          # GHOST-D1: `:blocked` = bariera observera nedosiahla pokoj. Nic
          # sa nezapisalo, session ZIJE dalej — pouzivatel skusi klik znova.
          if res == :blocked
            blocked_status(s)
            view.invalidate if view
            return false
          end
          view.invalidate if view
          # Po commite (aj po neuspesnom) nastroj KONCI — jedno odlozene
          # `pop_tool` a pouzivatel je spat pri svojom povodnom nastroji.
          GhostTool.end_tool(deferred: true) if s.terminal?
          true
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
            # SHIFT je vynimka: drzanie klavesy je jeho CELY vyznam, ale
            # zamykat sa ma raz (opakovany down uz nic nemeni).
            next if repeat.to_i > 1

            # GHOST-D2: SHIFT = HOLD-TO-LOCK natívnej inferencie. Plati vo
            # VSETKYCH fazach kreslenia; v skrinke ani v umiestnovani dosky
            # vyznam nema (klavesu vtedy nevlastnime).
            if owned == :shift
              next lock_inference!(s, view)
            end

            if s.drawing?
              next unless draw_key(s, owned, view)

              refresh_status
              refresh_vcb
              GhostTool.push_state(s)
              view.invalidate if view
              next
            end

            case owned
            when :left  then s.rotate!(-1)
            when :right then s.rotate!(1)
            # GHOST-D1: ↑/↓ znamenaju pri doske CYKLUS UMIESTNENIA (leziaca ->
            # stojaca -> na_stenu), nie rezim vysky — doska sa prichytava plne
            # v XYZ a vlastnost „ako lezi" je jej vyrobne citatelna vlastnost.
            when :down  then s.board? ? board_orientation!(s, -1) : s.set_z_mode!(:locked)
            when :up    then s.board? ? board_orientation!(s, 1)  : s.set_z_mode!(:free)
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
        def onKeyUp(key, _repeat, _flags, view)
          res = false
          guarded('onKeyUp') do
            s = live_session
            owned = s.nil? || !s.active? ? nil : owned_key(key)
            res = !owned.nil?
            # GHOST-D2: pustenie Shiftu ODOMKNE inferenciu (hold-to-lock).
            next unless owned == :shift

            release_inference!(view)
            refresh_status
            view.invalidate if view
          end
          res
        end

        # --- meracie pole (GHOST-D2) ----------------------------------------

        # PISANA hodnota. Parser je VLASTNY (`Calc.parse_mm`) — `String#to_l`
        # na slovenskom Windows padne pri bodke a bez jednotky si vezme
        # sablonu modelu, `to_f` by z „abc2400xyz" spravilo 0.0. Neplatny
        # text ani hodnota mimo limitu fazu NEPOSUNU (vzor Trimble
        # `99_sphere_tool`: `UI.beep` + status, nastroj nepadne).
        def onUserText(text, view) # rubocop:disable Naming/MethodName — SketchUp API
          guarded('onUserText') do
            s = live_session
            next unless s && s.active? && s.drawing?

            dim = s.draw_dim
            next if dim.nil? # faza 0 pisane cislo IGNORUJE

            mm = Calc.parse_mm(text)
            if mm.nil?
              draw_status_beep("Zadaj číslo v mm (napr. 2400 alebo 600,5) — „#{text.to_s.strip}“ sa neprijalo.")
              next
            end
            unless Calc.dim_ok?(dim, mm)
              draw_status_beep("#{Calc.dim_limit_message(dim)} Hodnota #{Calc.fmt_dim(mm)} mm sa neprijala.")
              next
            end

            # Napisane cislo znamena VZDY kladny smer 2. tahu.
            next unless s.confirm_draw!(dim, mm, sign: 1.0, typed: true)

            commit_session(s, view) if after_draw_step(s, view)
          end
        end

        # PRAZDNY Enter (probe 5.9.: `onUserText` vtedy NEPRIDE, SketchUp vola
        # `onReturn`; konstanta `VK_RETURN` v API NEEXISTUJE). Je to VEDOMA
        # akcia: prevezme hodnotu KARTY pre TUTO fazu a status to povie.
        def onReturn(view) # rubocop:disable Naming/MethodName — SketchUp API
          guarded('onReturn') do
            s = live_session
            next unless s && s.active? && s.drawing?

            dim = s.draw_dim
            next if dim.nil? # faza 0 Enter IGNORUJE

            mm = s.draw_card_value(dim)
            unless mm && Calc.dim_ok?(dim, mm)
              draw_status_beep("#{Calc.dim_limit_message(dim)} Hodnota karty sa neprijala.")
              next
            end
            next unless s.confirm_draw!(dim, mm, sign: 1.0, typed: true)

            card_taken_status(dim, mm)
            commit_session(s, view) if after_draw_step(s, view)
          end
          true
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
          # GHOST-D2 (vzor archivneho Ghost 2.0): pri ZVISLEJ osi 2. tahu
          # (pilaster) sa sirka meria proti PRIAMKE, nie proti scene — body
          # inference na podlahe by klamali, preto sa v tejto faze nekreslia.
          return if vertical_width_phase?

          ip.draw(view)
          view.tooltip = ip.tooltip
        rescue StandardError
          nil
        end

        def vertical_width_phase?
          s = live_session
          return false unless s && s.drawing? && s.draw_phase == :width

          ax = Calc.board_measure_axis(s.orientation, s.draw_dir_x)
          !ax.nil? && ax[2].abs > 0.5
        rescue StandardError
          false
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
        # GHOST-D1: JEDEN vstup do prichytavania. Doska nema zamok vysky —
        # ide vzdy `pick_free` (plne XYZ s inferenciou), takze sa prichyti aj
        # na ZVYSENY roh skrinky. Skrinka ostava nezmenena.
        def pick_point(s, x, y, view)
          if s.z_mode == :locked
            pick_locked(s, x, y, view)
          else
            pick_free(s, x, y, view)
          end
        end

        # GHOST-D1: zmena umiestnenia dosky. Pasik aj karta Dosky sa
        # aktualizuju z pushu session (`push_state` nizsie v onKeyDown).
        def board_orientation!(s, step)
          s.cycle_orientation!(step)
        end

        # =================================================================
        # GHOST-D2 — KRESLENIE: klavesy, kliky, sledovanie tahu, meracie pole
        # =================================================================

        # Klavesy v kresleni. ←/→ a ↑/↓ platia LEN vo faze 0 (pred klikom
        # pociatku): rovina 1. tahu aj os 2. tahu zavisia od orientacie, takze
        # zmena uprostred by rozpracovane rozmery preniesla do inej sustavy.
        # Od kliku pociatku su ZAMKNUTE — klavesu POHLTIME (`true` uz vratil
        # volajuci) a povieme preco. ALT v kresleni vyznam NEMA (pociatok je
        # pevna kotva `fl_bottom`), len sa pohlti kvoli menu liste Windows.
        # Vracia true = stav sa zmenil a treba prekreslit.
        def draw_key(s, owned, _view)
          return false if owned == :alt

          unless s.draw_phase == :origin
            draw_locked_keys_status
            return false
          end

          case owned
          when :left  then s.rotate!(-1)
          when :right then s.rotate!(1)
          when :down  then board_orientation!(s, -1)
          when :up    then board_orientation!(s, 1)
          else return false
          end
          true
        end

        def draw_locked_keys_status
          Sketchup.status_text = GhostTool::DRAW_KEYS_LOCKED_MSG
          begin
            Panel.set_status(GhostTool::DRAW_KEYS_LOCKED_MSG, true) if defined?(Panel)
          rescue StandardError
            nil
          end
          nil
        end

        # KLIK v kresleni. Vracia true LEN vtedy, ked su obe hodnoty zname a
        # volajuci ma pokracovat commitom.
        def draw_click(s, x, y, view)
          case s.draw_phase
          when :origin
            # Pociatok sa berie z PLNEHO XYZ prichytenia (ako umiestnovanie) —
            # doska tak zacne presne na rohu skrinky, aj na zvysenom.
            pick_point(s, x, y, view)
            unless s.placeable && s.last_point
              draw_status_beep('Poloha počiatku sa z tohto pohľadu nedá určiť — otoč pohľad.')
              return false
            end

            s.begin_draw!(s.last_point)
            # KOPIA REALNE pickovaneho bodu pociatku — natívny zámok smeru
            # (Shift) potrebuje DVA skutocne InputPointy; syntetický
            # `InputPoint.new(pt)` podla probe 5.9. nezamyka.
            capture_origin_ip!
            after_draw_step(s, view)
          when :length, :width
            # Klik potvrdzuje hodnotu, ktoru prave ukazuje NAHLAD.
            track_draw(s, x, y, view)
            dim = s.draw_dim
            if s.draw_over_limit
              draw_status_beep("#{Calc.dim_limit_message(dim)} Klik mimo limitu sa neprijal.")
              return false
            end
            val = s.draw_phase_value
            sign = dim == :width ? s.draw_width_sign : nil
            unless val && s.confirm_draw!(dim, val, sign: sign)
              draw_status_beep("#{Calc.dim_limit_message(dim)} Hodnota sa neprijala — ťahaj ďalej alebo napíš číslo.")
              return false
            end
            after_draw_step(s, view)
          else
            true
          end
        end

        # Po kazdom posune fazy: status, meracie pole, pasik, prekreslenie.
        # `true` = faza je `:done` a volajuci ma commitovat.
        def after_draw_step(s, view)
          release_inference!(view)
          refresh_status
          refresh_vcb
          GhostTool.push_state(s)
          view.invalidate if view
          s.draw_phase == :done
        end

        # Prazdny Enter je VEDOMA akcia — pouzivatel musi vediet, ze sa prevzala
        # hodnota z karty (nie z tahu).
        def card_taken_status(dim, mm)
          msg = "#{Calc.dim_label(dim)} #{Calc.fmt_dim(mm)} mm prevzatá z karty (prázdny Enter)."
          begin
            Panel.set_status(msg) if defined?(Panel)
          rescue StandardError
            nil
          end
          begin
            Sketchup.status_text = msg
          rescue StandardError
            nil
          end
          nil
        end

        def draw_status_beep(msg)
          begin
            UI.beep
          rescue StandardError
            nil
          end
          begin
            Sketchup.status_text = msg
          rescue StandardError
            nil
          end
          begin
            Panel.set_status(msg, true) if defined?(Panel)
          rescue StandardError
            nil
          end
          nil
        end

        # ZIVE SLEDOVANIE TAHU. Faza 1 hlada SMER v rovine Z pociatku, faza 2
        # MERIA po pevnej osi — dve ROZDIELNE geometrie, nie jedna s prepinacom.
        def track_draw(s, x, y, view)
          case s.draw_phase
          when :length then track_length(s, x, y, view)
          when :width  then track_width(s, x, y, view)
          else s.set_placeable!(true)
          end
        end

        # FAZA 1: kurzor sa premieta do VODOROVNEJ roviny Z = Z pociatku.
        # Brana volneho priestoru (vzor dnesneho ghostu): pouzije sa LEN
        # REALNA geometricka inferencia (vertex/hrana/plocha) — alebo bod so
        # ZAMKNUTOU inferenciou (Shift) — inak priesecnik luca s rovinou
        # s PLNYM guardom (`t >= 0` / konecne / `MIN_SIN` / `MAX_REACH_MM`).
        def track_length(s, x, y, view)
          o = s.draw_origin
          pt = draw_plane_point(s, x, y, view, o[2])
          if pt.nil?
            s.set_placeable!(false)
            return false
          end

          s.set_placeable!(true)
          s.preview_length!(pt)
        end

        def draw_plane_point(s, x, y, view, plane_z)
          pos = pick_ip(x, y, view)
          if pos && (ip_on_geometry? || inference_locked?(view))
            p = to_mm_triplet(pos)
            flat = [p[0], p[1], plane_z.to_f]
            return flat if Calc.sane_point?(flat)
          end
          # `s` sa tu necita — parameter drzi symetriu s `draw_axis_point`.
          _ = s
          pick_ray_plane(x, y, view, plane_z)
        end

        # FAZA 2: meria sa po PEVNEJ osi (leziaca = vodorovna kolmica na
        # 1. tah, stojaca/na_stenu = svetova +Z). Premietnutie z vodorovnej
        # roviny by pri zvislej sirke pilastra dalo KONSTANTNU vysku, preto
        # je vo volnom priestore fallbackom najblizsi bod luca a PRIAMKY osi.
        def track_width(s, x, y, view)
          o = s.draw_origin
          axis = Calc.board_measure_axis(s.orientation, s.draw_dir_x)
          if axis.nil?
            s.set_placeable!(false)
            return false
          end

          pt = draw_axis_point(s, x, y, view, o, axis)
          if pt.nil?
            s.set_placeable!(false)
            return false
          end

          proj = Calc.project_on_axis(o, axis, pt)
          if proj.nil?
            s.set_placeable!(false)
            return false
          end

          s.set_placeable!(true)
          s.preview_width!(proj)
        end

        def draw_axis_point(_s, x, y, view, origin, axis)
          pos = pick_ip(x, y, view)
          if pos && (ip_on_geometry? || inference_locked?(view))
            p = to_mm_triplet(pos)
            return p if Calc.sane_point?(p)
          end
          ray = view.pickray(x, y)
          return nil unless ray

          r_origin = to_mm_triplet(ray[0])
          r_dir = [ray[1].x.to_f, ray[1].y.to_f, ray[1].z.to_f]
          Calc.ray_axis_point(r_origin, r_dir, origin, axis)
        end

        # --- natívny zamok inferencie (Shift) -------------------------------

        # HOLD-TO-LOCK: zamkne inferenciu, ktoru SketchUp prave drzi. Zaroven
        # si zapamatame SMER — zamknuty smer musi platit aj vo VOLNOM
        # PRIESTORE, kde fallback ide cez `pickray` (bez toho by pohyb kurzora
        # po zamknuti smer dosky zmenil).
        def lock_inference!(s, view)
          return nil unless view

          begin
            native_lock(s, view)
          rescue StandardError => e
            Engine.log_error(e, 'GhostTool.Tool#lock_inference!')
          end
          s.lock_draw_dir! if s.drawing?
          refresh_status
          view.invalidate
          nil
        end

        # NATÍVNY zámok. Vo faze HLADANIA SMERU zamykame PRIAMKU pociatok ->
        # kurzor dvojicou InputPointov (vzor Trimble LineTool) — presne to
        # znamena „drz smer". Probe 5.9. ukazal, ze SYNTETICKE body
        # (`InputPoint.new(pt)`) nezamykaju; `@ip_origin` je preto KOPIA
        # REALNE pickovaneho bodu z kliku pociatku (`InputPoint#copy!`), nie
        # bod poskladany zo suradnic. Ked dvojica nie je k dispozicii (alebo
        # sme vo faze merania sirky), zamyka sa jednobodovo.
        # POZOR: ked kurzor nema ziadnu natívnu inferenciu (volny bod v
        # prazdnom priestore), SketchUp NEZAMKNE — smer vtedy drzi VLASTNY
        # zamok session (`lock_draw_dir!`), preto sa oba pouzivaju spolu.
        def native_lock(s, view)
          if s.drawing? && s.draw_phase == :length &&
             @ip_origin && @ip_origin.valid? && @ip && @ip.valid?
            view.lock_inference(@ip, @ip_origin)
          elsif @ip && @ip.valid?
            view.lock_inference(@ip)
          end
        end

        # Bod POCIATKU ako REALNY InputPoint (kopia, nie novy z suradnic).
        # Zije len pocas kreslenia; `deactivate` ho zahodi.
        def capture_origin_ip!
          return nil unless @ip && @ip.valid?

          @ip_origin ||= Sketchup::InputPoint.new
          @ip_origin.copy!(@ip)
          @ip_origin
        rescue StandardError => e
          Engine.log_error(e, 'GhostTool.Tool#capture_origin_ip!')
          @ip_origin = nil
        end

        def release_inference!(view)
          s = GhostTool.session
          s.release_draw_dir! if s.respond_to?(:drawing?) && s.drawing?
          return nil unless view

          begin
            view.lock_inference if view.respond_to?(:lock_inference)
          rescue StandardError => e
            Engine.log_error(e, 'GhostTool.Tool#release_inference!')
          end
          nil
        end

        def inference_locked?(view)
          return false unless view && view.respond_to?(:inference_locked?)

          view.inference_locked? ? true : false
        rescue StandardError
          false
        end

        # --- meracie pole (VCB) ---------------------------------------------

        def refresh_vcb
          return nil unless @vcb

          s = live_session
          return clear_vcb unless s && s.drawing?

          dim = s.draw_dim
          if dim.nil?
            Sketchup.vcb_label = ''
            Sketchup.vcb_value = ''
            return nil
          end
          Sketchup.vcb_label = "#{Calc.dim_label(dim)} (mm)"
          v = s.draw_phase_value
          Sketchup.vcb_value = v.nil? ? '' : Calc.fmt_dim(v)
          nil
        rescue StandardError
          nil
        end

        def clear_vcb
          return nil unless @vcb

          Sketchup.vcb_label = ''
          Sketchup.vcb_value = ''
          nil
        rescue StandardError
          nil
        end

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
          pick_ray_plane(x, y, view, s.lock_plane_z)
        end

        def pick_ray_plane(x, y, view, plane_z)
          ray = view.pickray(x, y)
          return nil unless ray

          origin = to_mm_triplet(ray[0])
          dir = [ray[1].x.to_f, ray[1].y.to_f, ray[1].z.to_f]
          Calc.ray_plane(origin, dir, plane_z)
        end

        # Volna vyska: plny inference point SketchUpu. Aj tu plati ZDRAVOTNY
        # STROP (review #268 P2-1) — inference na extremne vzdialenej geometrii
        # by inak polozil korpus kilometre od zakazky.
        def pick_free(s, x, y, view)
          pos = pick_ip(x, y, view)
          pt = pos ? to_mm_triplet(pos) : nil
          pt = nil unless pt.nil? || Calc.sane_point?(pt)
          # GHOST-D1: doska v UPLNE PRAZDNOM modeli (InputPoint nedal nic)
          # sadne na ROVINU Z = 0 — ten isty guardovany priesecnik luca ako
          # pri zamku (MIN_SIN / t >= 0 / MAX_REACH). Skrinka fallback NEMA:
          # jej volny rezim ostava presne taky, aky bol.
          pt = pick_ray_plane(x, y, view, 0.0) if pt.nil? && s.board?
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
          # GHOST-D2: Shift vlastnime LEN v kresleni — v umiestnovani (skrinka
          # aj doska) sa sprava presne ako doteraz (SketchUp si ho spracuje sam).
          return :shift if drawing_session? && vk(:VK_SHIFT) == key

          nil
        end

        def drawing_session?
          s = live_session
          !s.nil? && s.drawing?
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

        # GHOST-D1: bariera observera nedosiahla pokoj — v modeli sa NIC
        # nezmenilo a session ZIJE. Hlaska je rovnaka v statusbare aj v paneli.
        def blocked_status(s)
          msg = 'Plugin ešte dokončuje predchádzajúcu zmenu — o chvíľu klikni znova ' \
                '(nič sa nevložilo).'
          begin
            Sketchup.status_text = msg
          rescue StandardError
            nil
          end
          begin
            Panel.set_status(msg, true) if defined?(Panel)
          rescue StandardError
            nil
          end
          GhostTool.push_state(s)
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
