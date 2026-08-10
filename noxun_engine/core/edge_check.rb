# frozen_string_literal: true
# Noxun Engine — D-104/D-105: KONTROLA HRAN. Zvyraznenie stavu olepu priamo v
# modeli — zaverecna kontrola zakazky pred odoslanim do vyroby.
#
# ============================ TRI STAVY (D-105) ===============================
# Kazda hrana LEPITELNEHO dielca padne presne do jedneho stavu:
#   missing (cervena)  — PRAVIDLO ABS hranu ZIADA a paska CHYBA
#   extra   (fialova)  — pravidlo hranu NEziada a paska chyba (chrbat, sokel,
#                        zadne hrany polic… = „neolepene mimo pravidla")
#   taped   (zelena)   — paska JE (bez ohladu na pravidlo)
# Ziadny osobitny zoznam „roly bez olepu" NEEXISTUJE — jedina autorita toho, kde
# olep dava zmysel, je SADA PRAVIDIEL (AbsRules.thicknesses_for). Ked si
# pouzivatel pravidlo zmeni, kontrola ho nasleduje. Vedome rucne zrusena paska
# („bez ABS") padne do CERVENEJ — to je zmysel zaverecnej kontroly: ukaz vsetko,
# co pravidlo ziada a v modeli nie je, a rozhodne clovek (zamer D-104).
#
# CELY DIELEC sa preskoci vo VSETKYCH TROCH stavoch, ked:
#   - material NIE JE v katalogu (bez katalogovej pravdy sa neda nic dokazat —
#     semafor to uz hlasi ako RED „materiál nie je v aktuálnom katalógu"),
#   - material je UNI (neurceny — semafor hlasi ORANGE, pasky UNI zo zasady nema),
#   - material sa NELEPI (KOMPAKT, PD s postformingom) — Validation.abs_impossible?,
#     ta ista autorita ako v semafore aj v AbsRules.resolve_edges.
# KOMPAKT teda NIKDY nesvieti fialovo: nie je „neolepeny", len sa lepit neda.
# Paska MIMO katalogu sa berie ako paska (zelena) — semafor ju hlasi RED.
#
# ============================ CO SA NEDEJE ====================================
# ZIADNA mutacia modelu: kreslenie ide cez Sketchup::Overlay (SU 2023+) NAD
# modelom — ziadna operacia, ziadny undo krok, nic sa neuklada do .skp.
# Skenovanie je READ-ONLY (ziadny dedup tick — ten model meni).
#
# D-105 (lekcia D-103, PR #151): reakcia na ZMENU VYBERU je striktne read-only —
# NEvola Panel.push_selected, NEziada ScaleWatch.request_dedup a nespusta ziadnu
# operaciu; iba zahodi filter, poziada okno o cerstve cisla a prekresli pohlad.
# (Panel si svoj vlastny dedup pri sync-u vyberu ziada dalej — to je existujuca,
# D-103 overena cesta observera, ktorej sa D-105 vobec nedotyka.)
#
# ============================ VYKON ===========================================
# SKEN (254+ dielcov) bezi PRI ZAPNUTI a potom uz len ked sa zmenil MODEL
# (ModelObserver -> dirty, prepocet lazy v draw) alebo KATALOG (invalidate!).
# Zmena prepinaca ani zmena VYBERU sken NESPUSTA — prepocita sa iba lacny
# payload (filter + hotove GL polia). `draw` uz len posle predpocitane polia.
#
# ============================ ROZSAH ==========================================
# Sken vidi TOP-LEVEL korpusy/dosky (a ich priame dielce) — presne to iste, co
# vidi kusovnik (`Bom.collect`). Korpus vlozeny do groupy nie je v kusovniku ani
# vo VEPO, takze sa ani nezvyraznuje; je to vlastnost celeho produktu, nie tejto
# davky.
module Noxun
  module Engine
    module EdgeCheck
      EDGE_CODES = %w[L1 L2 W1 W2].freeze

      # Stavy hrany. Poradie = poradie v UI (rozbalovacie okno prepinacov).
      MISSING = 'missing'
      EXTRA   = 'extra'
      TAPED   = 'taped'
      STATES  = [MISSING, EXTRA, TAPED].freeze
      # Zelena sa kresli PRVA (tenka linka), cervena posledna — pri ostrom uhle
      # pohladu tak kriticky stav nikdy neprekryje informativny.
      DRAW_ORDER = [TAPED, EXTRA, MISSING].freeze

      # Posun plosky VON z telesa (mm) — bez neho by farba bojovala o hlbku
      # s plochou dielca (z-fighting).
      OUT_MM = 0.5
      # Farby su zrkadlom tokenov --nx-edge-* v ui/css/panel.css (svorka v okne
      # Vyroba musi mat PRESNE farbu plosky v modeli).
      COLORS = { MISSING => [226, 75, 74], EXTRA => [127, 119, 221],
                 TAPED => [29, 158, 117] }.freeze
      # Zelenych hran je na hotovej zakazke 400+ — plna ploska by bola necitatelna
      # mazanica, preto sa kresli LEN tenky obrys.
      OUTLINE_ONLY = [TAPED].freeze
      LINE_WIDTH = { MISSING => 2, EXTRA => 2, TAPED => 1 }.freeze

      OVERLAY_ID = 'noxun.engine.edge_check'
      OVERLAY_NAME = 'Noxun — kontrola hrán'

      # --- prepinace (D-105) ---------------------------------------------------
      # Nastavenie je vec POCITACA, nie zakazky — zije v %APPDATA%, NIKDY v .skp.
      SETTINGS_FILE = 'edge_check.json'
      SETTINGS_STD = 1
      SHOW_KEY = { MISSING => 'show_missing', EXTRA => 'show_extra', TAPED => 'show_taped' }.freeze
      SELECTED_ONLY_KEY = 'taped_selected_only'
      # Default: svieti len to, co je chyba (cervena). Zelena je „na vyziadanie"
      # a este aj vtedy len na oznacenych objektoch — inak zavali cely model.
      DEFAULT_OPTIONS = { 'show_missing' => true, 'show_extra' => false,
                          'show_taped' => false, SELECTED_ONLY_KEY => true }.freeze
      OPTION_KEYS = DEFAULT_OPTIONS.keys.freeze

      module_function

      # ================= CISTE ROZHODNUTIE (headless testovatelne) =============

      # Preskocit cely dielec? (material mimo katalogu / UNI / nelepitelny)
      def skip_part?(sheet)
        return true unless sheet.is_a?(Hash)
        return true if Validation.uni_sheet?(sheet)
        Validation.abs_impossible?(sheet)
      end

      # Rozdelenie hran dielca do troch stavov. record = {'edges' => {L1..W2 =>
      # abs_id|nil}}, sheet = katalogovy zaznam dosky (alebo nil), rule = mapa
      # pravidla roly ({'L1' => 1.0, ...} z AbsRules.thicknesses_for).
      # Preskoceny dielec vrati VSETKY tri stavy prazdne (nesvieti nijako).
      def classify_edges(record, sheet, rule)
        out = { MISSING => [], EXTRA => [], TAPED => [] }
        return out unless record.is_a?(Hash)
        return out if skip_part?(sheet)
        edges = record['edges'].is_a?(Hash) ? record['edges'] : {}
        r = rule.is_a?(Hash) ? rule : {}
        EDGE_CODES.each do |code|
          if blank?(edges[code])
            out[r.key?(code) ? MISSING : EXTRA] << code
          else
            out[TAPED] << code
          end
        end
        out
      end

      # D-104 kontrakt (ostava): kody hran, ktore pravidlo ziada a dielec ich nema.
      def flagged_edges(record, sheet, rule)
        classify_edges(record, sheet, rule)[MISSING]
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      # Pocet KUSOV dielca (snapshot moze niest quantity > 1 — jedna entita,
      # viac fyzickych kusov; kusovnik ich uz nasobi rovnako).
      def quantity_of(record)
        q = record.is_a?(Hash) ? record['quantity'].to_i : 1
        q < 1 ? 1 : q
      end

      # ================= PREPINACE: perzistencia (%APPDATA%) ===================

      def settings_dir
        return Materials.dir if defined?(Materials)
        File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
      end

      def settings_path
        File.join(settings_dir, SETTINGS_FILE)
      end

      # Ulozene prepinace. Poskodeny subor / cudzi typ hodnoty = DEFAULT
      # (nikdy vynimka, nikdy „nahodny" stav zvyraznenia).
      def settings
        raw = JsonFileStore.available?(settings_path) ? JsonFileStore.read(settings_path) : nil
        normalize_options(raw)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.settings')
        normalize_options(nil)
      end

      def normalize_options(raw)
        h = raw.is_a?(Hash) ? raw : {}
        DEFAULT_OPTIONS.each_with_object({}) do |(key, dflt), out|
          v = h[key]
          out[key] = v == true || v == false ? v : dflt
        end
      end

      # Aktualne prepinace (cache v pamati — subor sa necita per frame).
      def options
        @options ||= settings
      end

      # Prepnutie jedneho prepinaca. Autorita je TU (nie v HTML): neznamy kluc
      # ani nebooleovska hodnota sa NEZAPISU. Sken sa NESPUSTA — meni sa iba to,
      # co sa z hotovej cache kresli.
      def set_option(key, value)
        k = key.to_s
        return options unless OPTION_KEYS.include?(k)
        return options unless value == true || value == false
        next_opts = options.merge(k => value)
        write_settings(next_opts)
        @options = next_opts
        @payload = nil
        request_redraw(@model) if @overlay
        @options
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.set_option')
        options
      end

      def write_settings(opts)
        JsonFileStore.write(settings_path, normalize_options(opts).merge('std' => SETTINGS_STD))
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.write_settings')
        false
      end

      # ================= SKEN MODELU (SketchUp) ================================
      # Vlastny prechod modelom (NIE Bom.collect): overlay potrebuje KAZDY VYSKYT
      # dielca aj s jeho svetovou transformaciou. Kopie korpusu pred dedup tickom
      # zdielaju definiciu, takze ich vnorene dielce maju ROVNAKE persistent_id —
      # identitou vyskytu je preto dvojica (instancia korpusu, instancia dielca),
      # NIKDY pid. Filter „co je vyrobny dielec" zrkadli Bom.collect (core/bom.rb:
      # kind=part + manufactured=true + production_class=sheet; doska = kind=board
      # + manufactured=true).
      #
      # Vysledok: { 'occurrences' => [ {part:, owner:, qty:, unresolved:,
      #             'codes' => {stav => [kody]}, 'quads' => {stav => [4 body]} } ] }
      # Kody VSETKYCH troch stavov aj ich plosky sa pocitaju VZDY — prepinac potom
      # rozhoduje len o kresleni, takze jeho prepnutie nevyzaduje novy sken.
      def scan(model)
        out = { 'occurrences' => [] }
        return out unless model
        sheets = sheets_map
        rules = {}
        each_part(model) do |ent, tr, owner|
          cfg = Store.config(ent) || {}
          role = (Store.get(ent, 'role') || cfg['role']).to_s
          rule = (rules[role] ||= rule_for(role))
          codes = classify_edges(cfg, sheets[cfg['material_id'].to_s], rule)
          next if codes.values.all?(&:empty?)
          add_occurrence(out, ent, tr, role, cfg, codes, owner)
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.scan')
        out
      end

      # Jeden vyskyt dielca. Ked sa osi nedaju jednoznacne overit, dielec sa
      # NEKRESLI (D-88 zasada „radsej ziadna farba nez farba na zlej hrane") —
      # ale jeho hrany sa priznaju cez 'unresolved', aby okno nemlcalo.
      def add_occurrence(out, ent, tr, role, cfg, codes, owner)
        b = ent.definition.bounds
        lo = [Units.to_mm(b.min.x), Units.to_mm(b.min.y), Units.to_mm(b.min.z)]
        hi = [Units.to_mm(b.max.x), Units.to_mm(b.max.y), Units.to_mm(b.max.z)]
        box = [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]]
        prod = { 'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'] }
        ax = PartFaces.axes_for_snapshot(role, box, prod)
        occ = { 'part' => entity_id(ent), 'owner' => entity_id(owner || ent),
                'qty' => quantity_of(cfg), 'unresolved' => ax.nil?,
                'codes' => codes, 'quads' => { MISSING => [], EXTRA => [], TAPED => [] } }
        out['occurrences'] << occ
        return if ax.nil?
        STATES.each do |state|
          codes[state].each do |code|
            rect = PartFaces.face_rect_mm(code, lo, hi, ax, OUT_MM)
            next if rect.nil?
            occ['quads'][state] << rect.map { |p| Units.point(p[0], p[1], p[2]).transform(tr) }
          end
        end
      end

      def entity_id(ent)
        ent.respond_to?(:entityID) ? ent.entityID : nil
      rescue StandardError
        nil
      end

      # Prejde vyrobne dielce modelu; yielduje [entita, SVETOVA transformacia,
      # TOP-LEVEL vlastnik] (korpus pri vnorenom dielci, inak entita sama).
      def each_part(model)
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          case Store.kind(inst)
          when 'cabinet'
            base = inst.transformation
            inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
              yield(pi, base * pi.transformation, inst) if sheet_part?(pi)
            end
          when 'board'
            yield(inst, inst.transformation, inst) if Store.get(inst, 'manufactured') == true
          when 'part'
            yield(inst, inst.transformation, inst) if sheet_part?(inst)
          end
        end
      end

      def sheet_part?(ent)
        Store.kind(ent) == 'part' && Store.get(ent, 'manufactured') == true &&
          Store.get(ent, 'production_class').to_s == 'sheet'
      end

      def rule_for(role)
        defined?(AbsRules) ? AbsRules.thicknesses_for(role) : {}
      end

      def sheets_map
        return {} unless defined?(Materials)
        Materials.sheets.each_with_object({}) { |s, out| out[s['material_id'].to_s] = s }
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.sheets_map')
        {}
      end

      # ================= FILTER „LEN VYBRANE" (D-105) ==========================
      # Zelena sa (predvolene) kresli LEN na tom, co je prave oznacene — inak by
      # 400+ olepenych hran zavalilo cely model. Podporuje VIAC objektov naraz
      # (oznac cely sektor) a tri ciele: korpus (-> jeho dielce), doska, jeden
      # dielec vnutri korpusu.
      #
      # Codex audit BLOCKER 2: dielec vybraty VNUTRI korpusu je instancia z
      # DEFINICIE — dve kopie korpusu (pred dedup tickom) zdielaju definiciu,
      # takze ten isty `entityID` patri obom. Ktory VYSKYT je otvoreny, povie
      # LEN `model.active_path` (kontext editacie). Bez neho by sa vybrany dielec
      # rozsvietil vo vsetkych kopiach.
      def build_selection_filter(model)
        ids = {}
        ctx = nil
        if model && model.respond_to?(:selection)
          model.selection.each do |ent|
            eid = entity_id(ent)
            ids[eid] = true unless eid.nil?
          end
        end
        if model && model.respond_to?(:active_path)
          path = Array(model.active_path)
          ctx = entity_id(path.reverse.find { |i| !entity_id(i).nil? })
        end
        { 'ids' => ids, 'ctx' => ctx }
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.build_selection_filter')
        { 'ids' => {}, 'ctx' => nil }
      end

      def selection_filter(model = nil)
        @sel_filter ||= build_selection_filter(model || @model)
      end

      # Je vyskyt vo vybere? Vlastnik (korpus/doska) oznaceny v korene = vsetky
      # jeho dielce; dielec oznaceny vnutri = LEN vyskyt otvoreny v active_path.
      def occurrence_selected?(occ, filter)
        ids = filter['ids']
        return true if !occ['owner'].nil? && ids[occ['owner']]
        return false if occ['part'].nil? || !ids[occ['part']]
        ctx = filter['ctx']
        ctx.nil? || ctx == occ['owner']
      end

      def selection_empty?(model = nil)
        selection_filter(model)['ids'].empty?
      end

      # ================= PAYLOAD PRE KRESLENIE + CISLA =========================
      # Z hotovej scan cache + prepinacov + filtru vyrobi PREDPOCITANE GL polia a
      # deterministicke pocty. Prepocet bezi pri zmene cache / prepinaca / vyberu
      # — NIKDY per frame (Codex audit NOTE 7).
      #
      # 'counts' su per stav a pocitaju sa VZDY (aj pre vypnuty stav) — cislo
      # vedla prepinaca musi byt pravdive este predtym, nez ho pouzivatel zapne.
      # Zeleny pocet RESPEKTUJE „len vybrane".
      def view_payload
        return @payload if @payload
        cache = @cache
        return nil if cache.nil?
        opts = options
        filter = selection_filter
        fill = {}
        line = {}
        counts = {}
        STATES.each do |s|
          fill[s] = []
          line[s] = []
          counts[s] = 0
        end
        drawn = 0
        unresolved = 0
        multi = 0
        Array(cache['occurrences']).each do |occ|
          shown = false
          STATES.each do |state|
            codes = occ['codes'][state]
            next if codes.nil? || codes.empty?
            next unless state_in_scope?(state, occ, opts, filter)
            counts[state] += codes.length * occ['qty']
            next unless opts[SHOW_KEY[state]]
            if occ['unresolved']
              unresolved += codes.length * occ['qty']
              next
            end
            quads = occ['quads'][state] || []
            drawn += quads.length
            shown = true unless quads.empty?
            quads.each do |q|
              fill[state].concat(q) unless OUTLINE_ONLY.include?(state)
              line[state].concat(outline_points(q))
            end
          end
          multi += 1 if shown && occ['qty'] > 1
        end
        @payload = { 'fill' => fill, 'line' => line, 'counts' => counts,
                     'drawn' => drawn, 'unresolved' => unresolved, 'multi' => multi }
      end

      # Filter podla vyberu patri VYHRADNE zelenej (Michal 10.8.) — cervena a
      # fialova su chybove stavy a musia byt vidiet v celej zakazke.
      def state_in_scope?(state, occ, opts, filter)
        return true unless state == TAPED && opts[SELECTED_ONLY_KEY]
        occurrence_selected?(occ, filter)
      end

      # ================= ZIVOTNY CYKLUS OVERLAYU ===============================

      # Overlay API zije od SU 2023; starsi SketchUp funkciu jednoducho nema.
      def available?(model = nil)
        return false unless defined?(EdgeOverlay)
        m = model || active_model
        !m.nil? && m.respond_to?(:overlays)
      rescue StandardError
        false
      end

      # ZAPNUTE = mame overlay, patri TOMUTO modelu, je v nom zaregistrovany a
      # nie je NATIVNE vypnuty. Codex GH #152 P2: overlay sa da vypnut aj v
      # SketchUp paneli Overlays (Utilities) — vtedy ostane zaregistrovany, ale
      # prestane kreslit; okno by inak tvrdilo „zapnute" nad prazdnym modelom
      # a pocet by zamrzol (bez `draw` sa cache neprepocita).
      def active?(model = nil)
        m = model || active_model
        return false if @overlay.nil?
        return false unless same_model?(@model, m)
        overlay_live?(m)
      end

      def overlay_live?(model)
        return false if @overlay.nil?
        return false unless registered?(model)
        !@overlay.respond_to?(:enabled?) || @overlay.enabled? == true
      rescue StandardError
        false
      end

      def registered?(model)
        return true unless model.respond_to?(:overlays)
        model.overlays.to_a.include?(@overlay)
      rescue StandardError
        true
      end

      # Identita dokumentu: SketchUp vracia zvycajne ten isty objekt, ale po
      # File>Open/New sa meni — guid je zaloha pre pripad noveho Ruby obalu.
      def same_model?(a, b)
        return false if a.nil? || b.nil?
        return true if a.equal?(b)
        ga = a.respond_to?(:guid) ? a.guid.to_s : ''
        gb = b.respond_to?(:guid) ? b.guid.to_s : ''
        !ga.empty? && ga == gb
      rescue StandardError
        false
      end

      def toggle(model)
        active?(model) ? disable! : enable!(model)
      end

      # ZAPNUTIE. Codex audit BLOCKER 1 (D-104): odstraneny Sketchup::Overlay je
      # navzdy neplatny a NESMIE sa pridat druhykrat — pri kazdom zapnuti sa
      # preto tvori NOVA instancia a stara sa zahadzuje.
      def enable!(model)
        return ui_state(model) unless available?(model)
        disable! if @overlay
        drop_registered(model)
        ov = EdgeOverlay.new
        unless model.overlays.add(ov)
          Engine.log('D-104: overlay sa nepodarilo zaregistrovat (uz je pridany?)')
          return ui_state(model)
        end
        @overlay = ov
        @model = model
        @options = settings # cerstve prepinace z %APPDATA% pri kazdom zapnuti
        # Overlay si stav „zapnuty" pamata SketchUp (panel Overlays v Utilities).
        # Ked ho pouzivatel niekedy vypol, nasa registracia by sama nekreslila —
        # preto ho zapneme, ak to API dovoli (starsie verzie setter nemaju).
        begin
          ov.enabled = true if ov.respond_to?(:enabled=)
        rescue StandardError => e
          Engine.log_error(e, 'EdgeCheck.enable! overlay.enabled=')
        end
        attach_observer(model)
        attach_selection_observer(model)
        refresh!(model)
        ui_state(model)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.enable!')
        ui_state(model)
      end

      def disable!
        m = @model
        ov = @overlay
        @overlay = nil
        @model = nil
        @cache = nil
        @payload = nil
        @sel_filter = nil
        @dirty = false
        detach_observer(m)
        detach_selection_observer(m)
        remove_overlay(m, ov)
        invalidate(m)
        ui_state(m)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.disable!')
        ui_state(nil)
      end

      # Prepnutie/otvorenie ineho dokumentu: stav sa NEPRENASA ticho — zvyraznenie
      # patri modelu, v ktorom bolo zapnute (vzor notifikacii dialogov).
      def on_model_changed(model)
        return if @overlay.nil?
        return if !model.nil? && same_model?(@model, model)
        disable!
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.on_model_changed')
      end

      def remove_overlay(model, overlay)
        return unless overlay && model && model.respond_to?(:overlays)
        model.overlays.remove(overlay)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.remove_overlay')
      end

      # Poistka po reloade pluginu: overlay s NASIM id uz moze byt v modeli
      # zaregistrovany (stara instancia z predosleho behu) — `add` by inak zlyhal.
      def drop_registered(model)
        return unless model.respond_to?(:overlays)
        model.overlays.to_a.each do |o|
          next unless o.respond_to?(:overlay_id) && o.overlay_id.to_s == OVERLAY_ID
          model.overlays.remove(o)
        end
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.drop_registered')
      end

      # ================= CACHE + INVALIDACIA ===================================

      def refresh!(model = nil)
        m = model || @model
        return if m.nil?
        @cache = scan(m)
        @payload = nil
        @sel_filter = nil
        @dirty = false
        @cache
      end

      # Oznaci cache za starú BEZ modelovej transakcie (Codex GH #152 P2):
      # zmena KATALOGU (typ dosky, PD podtyp, pasky) meni, ktore hrany su
      # lepitelne, ale ziadny ModelObserver o nej nevie. Prepocet bezi lazy —
      # v najblizsom `ui_state` (push_state okna) alebo pri prekresleni.
      def invalidate!
        return unless @overlay
        @dirty = true
        @payload = nil
        request_redraw(@model)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.invalidate!')
      end

      # Volane z ModelObservera (commit/undo/redo/abort). V observeri sa NIC
      # neskenuje ani nemeni — len sa oznaci cache za stara a POZIADA sa o
      # prekreslenie; samotny prepocet bezi az v draw (mimo transakcie aj mimo
      # ScaleWatch guardu).
      def mark_dirty(model)
        return unless @overlay && same_model?(@model, model)
        @dirty = true
        @payload = nil
        request_redraw(model)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.mark_dirty')
      end

      # ZMENA VYBERU (D-105). KRITICKE (lekcia D-103, PR #151): tato cesta NESMIE
      # menit model — ziadna operacia, ziadny dedup, ziadny zapis. Sken sa
      # NEOPAKUJE: zahodi sa iba filter a payload (lacny prepocet), okno dostane
      # cerstve cisla a pohlad sa prekresli.
      def on_selection_changed(model = nil)
        return if @overlay.nil?
        m = model || @model
        return unless same_model?(@model, m)
        @sel_filter = nil
        @payload = nil
        request_selection_refresh(m)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.on_selection_changed')
      end

      # Codex audit BLOCKER 3: cislo v okne nesmie cakat na to, ci sa pohlad
      # nahodou prekresli — po zmene vyberu sa cerstvy stav posle VZDY. Bezi to
      # az v timeri (mimo observer callbacku) a burst eventov sa zlucuje.
      def request_selection_refresh(model)
        return if @sel_pending
        @sel_pending = true
        UI.start_timer(0, false) do
          begin
            @sel_pending = false
            if @overlay && same_model?(@model, model)
              notify_count_changed
              invalidate(model)
            end
          rescue StandardError => e
            Engine.log_error(e, 'EdgeCheck.request_selection_refresh')
          end
        end
      end

      # Samotny „dirty" flag prekreslenie NEZARUCUJE (nehybny pohlad draw nevola).
      # Vyziada sa preto explicitne — ale az PO observer callbacku (timer 0 s).
      def request_redraw(model)
        return if @redraw_pending
        @redraw_pending = true
        UI.start_timer(0, false) do
          begin
            @redraw_pending = false
            invalidate(model) if @overlay && same_model?(@model, model)
          rescue StandardError => e
            Engine.log_error(e, 'EdgeCheck.request_redraw')
          end
        end
      end

      def invalidate(model)
        return unless model && model.respond_to?(:active_view) && model.active_view
        model.active_view.invalidate
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.invalidate')
      end

      def attach_observer(model)
        return unless defined?(EdgeModelWatch)
        @observer ||= EdgeModelWatch.new
        begin
          model.remove_observer(@observer)
        rescue StandardError
          nil
        end
        model.add_observer(@observer)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.attach_observer')
      end

      def detach_observer(model)
        return unless model && @observer
        model.remove_observer(@observer)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.detach_observer')
      end

      def attach_selection_observer(model)
        return unless defined?(EdgeSelectionWatch)
        return unless model.respond_to?(:selection)
        @sel_observer ||= EdgeSelectionWatch.new
        begin
          model.selection.remove_observer(@sel_observer)
        rescue StandardError
          nil
        end
        model.selection.add_observer(@sel_observer)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.attach_selection_observer')
      end

      def detach_selection_observer(model)
        return unless model && @sel_observer && model.respond_to?(:selection)
        model.selection.remove_observer(@sel_observer)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.detach_selection_observer')
      end

      # ================= KRESLENIE =============================================

      # Vola ju Overlay#draw. Prepocet sa robi LAZY (len ked je cache stara) —
      # nikdy per frame. Body su predpocitane vo `view_payload`; tu uz len ideme
      # po stavoch a posielame hotove polia.
      def draw(view)
        model = view.respond_to?(:model) ? view.model : nil
        if @cache.nil? || @dirty
          refresh!(model || @model)
          notify_count_changed
        end
        payload = view_payload
        return if payload.nil?
        DRAW_ORDER.each { |state| draw_state(view, payload, state) }
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.draw')
        nil
      end

      def draw_state(view, payload, state)
        fill = payload['fill'][state]
        line = payload['line'][state]
        return if (fill.nil? || fill.empty?) && (line.nil? || line.empty?)
        view.drawing_color = Sketchup::Color.new(*COLORS[state])
        view.draw(GL_QUADS, fill) unless fill.nil? || fill.empty?
        view.line_width = LINE_WIDTH[state] || 2
        view.draw(GL_LINES, line) unless line.nil? || line.empty?
      end

      # Obrysove ciary quadu ako dvojice bodov (GL_LINES) — tenka linka drzi
      # plosku citatelnu aj pri ostrom uhle pohladu a pri zelenej je JEDINA kresba.
      def outline_points(quad)
        out = []
        4.times { |i| out << quad[i] << quad[(i + 1) % 4] }
        out
      end

      # Obal kresby (Codex audit BLOCKER 4 D-104): bez neho SketchUp kresbu mimo
      # obalu modelu orezava. Berie VSETKY tri stavy z celej scan cache (nie iba
      # prave viditelny payload) — zapnutie dalsieho stavu tak nikdy neskonci
      # orezanou kresbou (Codex audit D-105 FIX 6).
      def extents(model = nil)
        bb = Geom::BoundingBox.new
        m = model || @model
        bb.add(m.bounds) if m && m.respond_to?(:bounds)
        Array(@cache ? @cache['occurrences'] : []).each do |occ|
          STATES.each { |s| occ['quads'][s].each { |q| q.each { |p| bb.add(p) } } }
        end
        bb
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.extents')
        Geom::BoundingBox.new
      end

      # ================= STAV PRE OKNO =========================================

      # Tvar pre okno Vyroba. Cisla su VYHRADNE zo servera (JS si nic neprepocitava).
      def ui_state(model = nil)
        m = model || active_model
        on = active?(m)
        # Cislo v okne nesmie byt stare: ked je cache oznacena za starú (modelova
        # transakcia alebo zmena katalogu), prepocita sa TU — inak by okno cakalo
        # na najblizsie prekreslenie pohladu.
        refresh!(m) if on && (@cache.nil? || @dirty)
        p = on ? view_payload : nil
        { 'available' => available?(m), 'active' => on,
          'options' => options,
          'counts' => p ? p['counts'] : nil,
          # D-104 kompat: skalarny 'count' = pocet hran BEZ OLEPU podla pravidla.
          'count' => p ? p['counts'][MISSING] : nil,
          'drawn' => p ? p['drawn'] : nil,
          'unresolved' => p ? p['unresolved'] : nil,
          'multi' => p ? p['multi'] : nil,
          'selection_empty' => on ? selection_empty?(m) : nil }
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.ui_state')
        { 'available' => false, 'active' => false, 'options' => DEFAULT_OPTIONS.dup }
      end

      # Po prepocte (draw / zmena vyberu): okno Vyroba dostane cerstve cisla.
      # Burst eventov sa zluci do JEDNEHO pushu (timer + pending guard).
      def notify_count_changed
        return unless defined?(ProductionDialog)
        return if @notify_pending
        @notify_pending = true
        UI.start_timer(0, false) do
          begin
            @notify_pending = false
            ProductionDialog.push_edge_check
          rescue StandardError => e
            Engine.log_error(e, 'EdgeCheck.notify_count_changed')
          end
        end
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.notify_count_changed')
      end

      def active_model
        defined?(Sketchup) ? Sketchup.active_model : nil
      rescue StandardError
        nil
      end
    end
  end
end
