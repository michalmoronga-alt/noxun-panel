# frozen_string_literal: true
# Noxun Engine — D-89 (a): HRANA POD KURZOROM. Hover nad hranou v karte dielca
# (alebo dosky) rozsvieti ZODPOVEDAJUCU hranu priamo v MODELI.
#
# ============================ ZASADY ============================
# * Je to POHLAD, nie data. Kresli sa cez Sketchup::Overlay NAD modelom —
#   ziadna geometria, ziadna operacia, ziadny krok Spat a nic sa neuklada do
#   .skp (lekcia D-103, presne vzor D-104/D-105).
# * NIC SA NEHLADA. Zvyraznuje sa hrana toho dielca, ktory je PRAVE VYBRATY v
#   modeli — karta dielca je jeho zrkadlo, takze iny objekt sa zvyraznit nema
#   ako. Ziadny scan modelu, jedna ploska, nulova cena.
# * Geometria hrany ide cez ZDIELANY kontrakt `PartFaces` (ten isty, akym
#   kresli D-104) — kod hrany L1/L2/W1/W2 -> stena kvadra. Ked sa osi dielca
#   nedaju jednoznacne overit, NEKRESLI SA NIC (zasada „radsej ziadna farba
#   nez farba na zlej hrane").
# * Zmizne pri odchode kurzora (`hide`), pri prepnuti dokumentu aj pri zatvoreni
#   panela (`release`).
#
# Cely SketchUp obal (`HoverEdgeOverlay`) zije v core/edge_overlay.rb pod
# guardom `defined?(Sketchup::Overlay)` — na starsom SketchUpe a v headless
# testoch trieda vobec nevznikne, `available?` vrati false a zvysok pluginu
# bezi nezmeneny.
module Noxun
  module Engine
    module HoverEdge
      OVERLAY_ID = 'noxun.engine.hover_edge'
      OVERLAY_NAME = 'Noxun — hrana pod kurzorom'

      # --nx-select (firemna teal). Vyber/zvyraznenie, NIE stav olepu — preto
      # sa zamerne NEberie z `EdgeCheck::COLORS` (tie tri farby hovoria o olepe
      # a miesat sa nesmu).
      COLOR = [16, 119, 135].freeze

      # Posun plosky VON z telesa (mm). O kus viac nez `EdgeCheck::OUT_MM`
      # (0,5) — hover musi byt vidno aj vtedy, ked na tej istej hrane uz svieti
      # kontrola olepu.
      OUT_MM = 0.9

      LINE_WIDTH = 2
      CODES = %w[L1 L2 W1 W2].freeze

      @overlay = nil
      @model = nil
      @quad = nil

      module_function

      # Overlay API prislo v SketchUp 2023; starsi SketchUp funkciu nema.
      def available?(model = nil)
        return false unless defined?(HoverEdgeOverlay)
        m = model || active_model
        !m.nil? && m.respond_to?(:overlays)
      rescue StandardError
        false
      end

      # Kod hrany -> zvyraznenie v modeli. Prazdny/neznamy kod = zhasnutie.
      # Vracia true, ked sa naozaj nieco kresli.
      def show(model, code)
        return false unless available?(model)
        return hide(model) unless CODES.include?(code.to_s)

        target = target_part(model)
        return hide(model) if target.nil?

        quad = quad_for(target[0], target[1], code.to_s)
        return hide(model) if quad.nil?

        ensure_overlay(model)
        @quad = quad
        invalidate(model)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HoverEdge.show')
        false
      end

      # Zhasnutie (odchod kurzora, prekreslenie karty). Overlay ostava
      # zaregistrovany — kresli prazdno, takze nasledujuci hover nemusi
      # registrovat novy (add/remove pri kazdom pohybe mysou je zbytocna praca).
      def hide(model = nil)
        return false if @quad.nil?
        @quad = nil
        invalidate(model || @model)
        false
      rescue StandardError => e
        Engine.log_error(e, 'HoverEdge.hide')
        false
      end

      # Uplne odpojenie: zatvorenie panela, prepnutie dokumentu. Odstraneny
      # Sketchup::Overlay je navzdy neplatny (BLOCKER 1 z D-104), preto sa pri
      # dalsom zvyrazneni tvori NOVA instancia.
      def release
        m = @model
        ov = @overlay
        @overlay = nil
        @model = nil
        @quad = nil
        remove_overlay(m, ov)
        invalidate(m)
        true
      rescue StandardError => e
        Engine.log_error(e, 'HoverEdge.release')
        false
      end

      # Kresli ju Overlay#draw. Ziadny prepocet — quad je hotovy z `show`.
      def draw(view)
        q = @quad
        return if q.nil? || q.length != 4
        view.drawing_color = Sketchup::Color.new(*COLOR)
        view.draw(GL_QUADS, q)
        view.line_width = LINE_WIDTH
        view.draw(GL_LINES, outline_points(q))
      rescue StandardError => e
        Engine.log_error(e, 'HoverEdge.draw')
        nil
      end

      # Bez extents SketchUp kresbu mimo obalu modelu oreze (ploska je posunuta
      # von) — rovnaky dovod ako pri D-104.
      def extents(model = nil)
        bb = Geom::BoundingBox.new
        m = model || @model
        bb.add(m.bounds) if m && m.respond_to?(:bounds)
        Array(@quad).each { |p| bb.add(p) }
        bb
      rescue StandardError
        Geom::BoundingBox.new
      end

      # ---- vnutro -----------------------------------------------------------

      # Dielec, o ktorom hovori karta panela = to, co je PRAVE VYBRATE.
      # -> [entita, SVETOVA transformacia] alebo nil.
      # `edit_transform` je transformacia otvoreneho kontextu (dvojklik do
      # skrinky), takze vnoreny dielec dostane spravne svetove suradnice bez
      # hladania cesty instanciami.
      def target_part(model)
        return nil unless model.respond_to?(:selection)
        sel = model.selection.to_a.select { |e| e.respond_to?(:valid?) && e.valid? }
        ent = sel.find { |e| Store.kind(e) == 'part' } || sel.find { |e| Store.kind(e) == 'board' }
        return nil if ent.nil? || !ent.respond_to?(:definition)
        [ent, world_transform(model, ent)]
      rescue StandardError
        nil
      end

      def world_transform(model, ent)
        base = model.respond_to?(:edit_transform) ? model.edit_transform : nil
        base ? base * ent.transformation : ent.transformation
      rescue StandardError
        ent.transformation
      end

      # Ploska hrany vo svetovych suradniciach. Zrkadlo `EdgeCheck.add_occurrence`
      # pre JEDINU hranu — rovnaky kontrakt os/strana, rovnaka tolerancia.
      def quad_for(ent, tr, code)
        cfg = Store.config(ent) || {}
        role = (Store.get(ent, 'role') || cfg['role']).to_s
        b = ent.definition.bounds
        lo = [Units.to_mm(b.min.x), Units.to_mm(b.min.y), Units.to_mm(b.min.z)]
        hi = [Units.to_mm(b.max.x), Units.to_mm(b.max.y), Units.to_mm(b.max.z)]
        box = [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]]
        prod = { 'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'] }
        ax = PartFaces.axes_for_snapshot(role, box, prod)
        return nil if ax.nil?
        rect = PartFaces.face_rect_mm(code, lo, hi, ax, OUT_MM)
        return nil if rect.nil?
        rect.map { |p| Units.point(p[0], p[1], p[2]).transform(tr) }
      rescue StandardError => e
        Engine.log_error(e, 'HoverEdge.quad_for')
        nil
      end

      def ensure_overlay(model)
        return true if @overlay && same_model?(@model, model) && registered?(model)
        release
        ov = HoverEdgeOverlay.new
        unless model.overlays.add(ov)
          Engine.log('D-89a: overlay hrany sa nepodarilo zaregistrovat')
          return false
        end
        begin
          ov.enabled = true if ov.respond_to?(:enabled=)
        rescue StandardError => e
          Engine.log_error(e, 'HoverEdge.ensure_overlay enabled=')
        end
        @overlay = ov
        @model = model
        true
      end

      def registered?(model)
        return true unless model.respond_to?(:overlays)
        model.overlays.to_a.include?(@overlay)
      rescue StandardError
        true
      end

      def remove_overlay(model, overlay)
        return unless model && overlay && model.respond_to?(:overlays)
        model.overlays.remove(overlay)
      rescue StandardError
        nil
      end

      def same_model?(a, b)
        return false if a.nil? || b.nil?
        return true if a.equal?(b)
        ga = a.respond_to?(:guid) ? a.guid.to_s : ''
        gb = b.respond_to?(:guid) ? b.guid.to_s : ''
        !ga.empty? && ga == gb
      rescue StandardError
        false
      end

      def outline_points(quad)
        out = []
        4.times { |i| out << quad[i] << quad[(i + 1) % 4] }
        out
      end

      def invalidate(model)
        return unless model && model.respond_to?(:active_view) && model.active_view
        model.active_view.invalidate
      rescue StandardError
        nil
      end

      def active_model
        defined?(Sketchup) ? Sketchup.active_model : nil
      rescue StandardError
        nil
      end
    end
  end
end
