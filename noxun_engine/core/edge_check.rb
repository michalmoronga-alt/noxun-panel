# frozen_string_literal: true
# Noxun Engine — D-104: KONTROLA HRAN (light). Zvyraznenie LEPITELNYCH hran BEZ
# PASKY priamo v modeli — zaverecna kontrola olepov pred odoslanim zakazky.
#
# ============================ CO SA ZVYRAZNI ==================================
# Hrana dielca sa zvyrazni, prave ked:
#   1) PRAVIDLO ABS pre jeho rolu na tej hrane pasku ZIADA (AbsRules.thicknesses_for)
#   2) a dielec na nej ZIADNU pasku nema (edges[code] je prazdne).
# Ziadny osobitny zoznam „roly bez olepu" NEEXISTUJE — jedina autorita toho, kde
# olep dava zmysel, je SADA PRAVIDIEL. Dosledok: chrbat a sokel maju pravidlo
# prazdne, takze sa nezvyraznia nikdy; ked si pouzivatel pravidlo zmeni, kontrola
# ho nasleduje.
#
# CELY DIELEC sa preskoci, ked:
#   - material NIE JE v katalogu (bez katalogovej pravdy sa neda nic dokazat —
#     semafor to uz hlasi ako RED „materiál nie je v aktuálnom katalógu"),
#   - material je UNI (neurceny — semafor hlasi ORANGE, pasky UNI zo zasady nema),
#   - material sa NELEPI (KOMPAKT, PD s postformingom) — Validation.abs_impossible?,
#     ta ista autorita ako v semafore aj v AbsRules.resolve_edges.
# Vedome rucne zrusena paska („bez ABS") sa ZVYRAZNI — to je zmysel zaverecnej
# kontroly: ukaz vsetko, co pravidlo ziada a v modeli nie je, a rozhodne clovek.
# Paska MIMO katalogu sa NEzvyraznuje (paska tam je; semafor ju hlasi RED).
#
# ============================ CO SA NEDEJE ====================================
# ZIADNA mutacia modelu: kreslenie ide cez Sketchup::Overlay (SU 2023+) NAD
# modelom — ziadna operacia, ziadny undo krok, nic sa neuklada do .skp.
# Skenovanie je READ-ONLY (ziadny dedup tick — ten model meni).
#
# ============================ VYKON ===========================================
# Sken (254+ dielcov) bezi PRI ZAPNUTI a potom uz len ked sa model zmenil
# (ModelObserver nastavi „dirty", prepocet sa spravi LAZY v draw). Kreslenie je
# per frame LEN dve volania view.draw nad predpocitanymi bodmi.
module Noxun
  module Engine
    module EdgeCheck
      EDGE_CODES = %w[L1 L2 W1 W2].freeze
      # Posun plosky VON z telesa (mm) — bez neho by cervena bojovala o hlbku
      # s plochou dielca (z-fighting).
      OUT_MM = 0.5
      COLOR_RGB = [230, 25, 25].freeze
      OVERLAY_ID = 'noxun.engine.edge_check'
      OVERLAY_NAME = 'Noxun — hrany bez olepu'

      module_function

      # ================= CISTE ROZHODNUTIE (headless testovatelne) =============

      # Preskocit cely dielec? (material mimo katalogu / UNI / nelepitelny)
      def skip_part?(sheet)
        return true unless sheet.is_a?(Hash)
        return true if Validation.uni_sheet?(sheet)
        Validation.abs_impossible?(sheet)
      end

      # Kody hran na zvyraznenie. record = {'edges' => {L1..W2 => abs_id|nil}},
      # sheet = katalogovy zaznam dosky (alebo nil), rule = mapa pravidla roly
      # ({'L1' => 1.0, ...} z AbsRules.thicknesses_for).
      def flagged_edges(record, sheet, rule)
        return [] unless record.is_a?(Hash)
        return [] if skip_part?(sheet)
        edges = record['edges'].is_a?(Hash) ? record['edges'] : {}
        r = rule.is_a?(Hash) ? rule : {}
        EDGE_CODES.select { |c| r.key?(c) && blank?(edges[c]) }
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

      # ================= SKEN MODELU (SketchUp) ================================
      # Vlastny prechod modelom (NIE Bom.collect): overlay potrebuje KAZDY VYSKYT
      # dielca aj s jeho svetovou transformaciou. Kopie korpusu pred dedup tickom
      # zdielaju definiciu, takze ich vnorene dielce maju ROVNAKE persistent_id —
      # identitou vyskytu je preto dvojica (instancia korpusu, instancia dielca),
      # NIKDY pid. Filter „co je vyrobny dielec" zrkadli Bom.collect (core/bom.rb:
      # kind=part + manufactured=true + production_class=sheet; doska = kind=board
      # + manufactured=true).
      #
      # Vysledok:
      #   'count'      — pocet fyzickych hran bez olepu (nasobene quantity) = cislo pre cloveka
      #   'drawn'      — pocet realne nakreslenych plosok (jedna entita = jedna ploska)
      #   'unresolved' — hrany dielcov, ktorym sa NEDALO overit priradenie osi
      #   'multi'      — pocet dielcov s quantity > 1 medzi najdenymi (kvoli pravdivemu textu)
      #   'quads'      — pole stvoric Geom::Point3d vo svetovych suradniciach
      def scan(model)
        out = { 'count' => 0, 'drawn' => 0, 'unresolved' => 0, 'multi' => 0, 'quads' => [] }
        return out unless model
        sheets = sheets_map
        rules = {}
        each_part(model) do |ent, tr|
          cfg = Store.config(ent) || {}
          role = (Store.get(ent, 'role') || cfg['role']).to_s
          rule = (rules[role] ||= rule_for(role))
          codes = flagged_edges(cfg, sheets[cfg['material_id'].to_s], rule)
          next if codes.empty?
          qty = quantity_of(cfg)
          out['count'] += codes.length * qty
          out['multi'] += 1 if qty > 1
          add_quads(out, ent, tr, role, cfg, codes, qty)
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.scan')
        out
      end

      # Plosky jedneho dielca. Ked sa osi nedaju jednoznacne overit, dielec sa
      # NEKRESLI (D-88 zasada „radsej ziadna farba nez farba na zlej hrane") —
      # ale jeho hrany sa zapocitaju do 'unresolved', aby okno nemlcalo.
      def add_quads(out, ent, tr, role, cfg, codes, qty)
        b = ent.definition.bounds
        lo = [Units.to_mm(b.min.x), Units.to_mm(b.min.y), Units.to_mm(b.min.z)]
        hi = [Units.to_mm(b.max.x), Units.to_mm(b.max.y), Units.to_mm(b.max.z)]
        box = [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]]
        prod = { 'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'] }
        ax = PartFaces.axes_for_snapshot(role, box, prod)
        if ax.nil?
          out['unresolved'] += codes.length * qty
          return
        end
        codes.each do |code|
          rect = PartFaces.face_rect_mm(code, lo, hi, ax, OUT_MM)
          next if rect.nil?
          out['quads'] << rect.map { |p| Units.point(p[0], p[1], p[2]).transform(tr) }
          out['drawn'] += 1
        end
      end

      # Prejde vyrobne dielce modelu; yielduje [entita, SVETOVA transformacia].
      def each_part(model)
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          case Store.kind(inst)
          when 'cabinet'
            base = inst.transformation
            inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
              yield(pi, base * pi.transformation) if sheet_part?(pi)
            end
          when 'board'
            yield(inst, inst.transformation) if Store.get(inst, 'manufactured') == true
          when 'part'
            yield(inst, inst.transformation) if sheet_part?(inst)
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

      # ================= ZIVOTNY CYKLUS OVERLAYU ===============================

      # Overlay API zije od SU 2023; starsi SketchUp funkciu jednoducho nema.
      def available?(model = nil)
        return false unless defined?(EdgeOverlay)
        m = model || active_model
        !m.nil? && m.respond_to?(:overlays)
      rescue StandardError
        false
      end

      def active?(model = nil)
        m = model || active_model
        !@overlay.nil? && same_model?(@model, m)
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

      # ZAPNUTIE. Codex audit BLOCKER 1: odstraneny Sketchup::Overlay je navzdy
      # neplatny a NESMIE sa pridat druhykrat — pri kazdom zapnuti sa preto tvori
      # NOVA instancia a stara sa zahadzuje.
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
        attach_observer(model)
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
        @dirty = false
        detach_observer(m)
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
        @dirty = false
        @cache
      end

      # Volane z ModelObservera (commit/undo/redo/abort). V observeri sa NIC
      # neskenuje ani nemeni — len sa oznaci cache za stara a POZIADA sa o
      # prekreslenie; samotny prepocet bezi az v draw (mimo transakcie aj mimo
      # ScaleWatch guardu).
      def mark_dirty(model)
        return unless @overlay && same_model?(@model, model)
        @dirty = true
        request_redraw(model)
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.mark_dirty')
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

      # ================= KRESLENIE =============================================

      # Vola ju Overlay#draw. Prepocet sa robi LAZY (len ked je cache stara) —
      # nikdy per frame. Po prepocte sa oknu Vyroba posle cerstvy pocet.
      def draw(view)
        model = view.respond_to?(:model) ? view.model : nil
        if @cache.nil? || @dirty
          refresh!(model || @model)
          notify_count_changed
        end
        quads = @cache ? @cache['quads'] : nil
        return if quads.nil? || quads.empty?
        view.drawing_color = Sketchup::Color.new(*COLOR_RGB)
        view.draw(GL_QUADS, quads.flatten(1))
        view.line_width = 2
        view.draw(GL_LINES, outline_points(quads))
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.draw')
        nil
      end

      # Obrysove ciary quadov ako dvojice bodov (GL_LINES) — tenka linka drzi
      # plosku citatelnu aj pri ostrom uhle pohladu.
      def outline_points(quads)
        out = []
        quads.each do |q|
          4.times { |i| out << q[i] << q[(i + 1) % 4] }
        end
        out
      end

      # Obal kresby (Codex audit BLOCKER 4): bez neho SketchUp kresbu mimo obalu
      # modelu orezava. Spaja sa s obalom modelu — nase plosky su v nom aj tak.
      def extents(model = nil)
        bb = Geom::BoundingBox.new
        m = model || @model
        bb.add(m.bounds) if m && m.respond_to?(:bounds)
        (@cache ? @cache['quads'] : []).each { |q| q.each { |p| bb.add(p) } }
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
        c = on && @cache ? @cache : nil
        { 'available' => available?(m), 'active' => on,
          'count' => c ? c['count'] : nil, 'drawn' => c ? c['drawn'] : nil,
          'unresolved' => c ? c['unresolved'] : nil, 'multi' => c ? c['multi'] : nil }
      rescue StandardError => e
        Engine.log_error(e, 'EdgeCheck.ui_state')
        { 'available' => false, 'active' => false }
      end

      # Po prepocte v draw: okno Vyroba dostane cerstvy pocet (az mimo kreslenia).
      def notify_count_changed
        return unless defined?(ProductionDialog)
        UI.start_timer(0, false) do
          begin
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
