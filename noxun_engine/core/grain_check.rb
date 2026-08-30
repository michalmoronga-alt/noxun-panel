# frozen_string_literal: true
# Noxun Engine — K2 / D-87: SMER KRESBY V MODELI. Jeden pohlad na celu zakazku —
# po zapnuti sa na kazdy vyrobny dielec nakreslia rovnobezne ciary v smere
# kresby dekoru, takze rozdiel „blenda pozdlzne vs. dvere priecne" je vidiet na
# prvy pohlad, nie az po jednom dielci v kartach.
#
# Dovod existencie (incident 19.8.2026): v objednavke naostro mala tenka horna
# blenda pozdlznu kresbu a vysoke uzke dvere pod nou priecnu — a plugin to
# nevedel ani ukazat. K1 (D-108) dala smer per dielec ako VSTUP, K2 dava
# KONTROLU toho vstupu.
#
# ============================ ZDROJ SMERU (jedina autorita) ===================
# Kresli sa VYHRADNE z `grain_direction` v SNAPSHOTE dielca — z tej istej
# hodnoty, ktoru zapisal builder cez `CabinetBuilder.effective_grain`
# (override -> material). Katalog sa TU nikdy necita: dielec odpojeny od
# skrinky aj stara zakazka drzia svoj vlastny snapshot a musia sa zobrazit
# presne tak, ako pojdu do vyroby.
#   'length' — kresba bezi v smere VYROBNEJ DLZKY
#   'width'  — kresba bezi v smere VYROBNEJ SIRKY
#   'none'   — material kresbu NEMA (UNI, jednofarebny dekor) => dielec sa
#              PRESKOCI (nie je co kreslit; prazdna plocha je poctiva odpoved)
#
# ============================ GEOMETRIA =======================================
# Ktora os dielca je dlzka/sirka/hrubka NIE JE hadanie z rozmerov — je to udaj
# deskriptora (`PartFaces`); pri citani z modelu ho `axes_for_snapshot` odvodi
# z ROLY a OVERI proti kvadru. Ked sa osi overit nedaju, dielec sa NEKRESLI
# (zasada D-88 „radsej ziadna kresba nez kresba v zlom smere") a priznana je
# cez `unresolved`.
# Ciary sa kreslia na OBE velke (dekorove) plochy — kvader vidno raz zpredu,
# raz zozadu a overlay nema ako vediet, odkial sa pouzivatel pozera.
#
# ============================ FARBA (rozhodnutie K2) ==========================
# COLOR = #37474f (token --nx-ink-strong) — TMAVA NEUTRALNA.
#   - NIE cervena/oranzova/zelena: to su tri stavy olepu (EdgeCheck::COLORS) a
#     dva rozne pohlady na zakazku sa nesmu farebne miesat,
#   - NIE fialova: v modeli splyvala s modrym zvyraznenim vyberu aj s osami
#     (lekcia D-105, Michal 11.8.),
#   - NIE teal/tyrkysova: `--nx-select` (#107787) aj stav „olepene" (#1d9e75)
#     su prakticky ta ista rodina,
#   - NIE tmavomodra: to je len stmavena rodina vyberu SketchUpu.
# Tmava bridlicova ma silny kontrast na bielych a svetlych dekoroch (to je
# drviva vacsina vnutra korpusov) a proti jasnemu modremu zvyrazneniu vyberu
# je zjavne ina. VEDOMA SLABINA: na velmi tmavom dekore (wenge) kontrast klesa
# — ciary su vtedy citatelne skor tvarom nez farbou. Jedna farba to inak
# nezvladne a druha „svetla" farba by uz bola dalsi stav na rozlisovanie.
#
# ============================ CO SA NEDEJE ====================================
# ZIADNA mutacia modelu: kreslenie ide cez Sketchup::Overlay (SU 2023+) NAD
# modelom — ziadna operacia, ziadny undo krok, nic sa neuklada do .skp. Sken je
# READ-ONLY (ziadny dedup tik). Po vypnuti aj po zatvoreni Studia v modeli
# neostane NIC.
#
# ============================ ROZSAH ==========================================
# Sken vidi to iste, co kusovnik — dielce top-level korpusov, samostatne dosky
# a samostatne dielce. Prechod modelom sa NEKOPIRUJE: pouziva sa `each_part`
# z EdgeCheck, aby „co je vyrobny dielec" ostalo na JEDNOM mieste.
module Noxun
  module Engine
    module GrainCheck
      # Hodnoty, ktore sa daju nakreslit. 'none' tu zamerne NIE JE.
      GRAINS = %w[length width].freeze

      # Posun ciary VON z telesa (mm) — bez neho by bojovala o hlbku s dekorovou
      # plochou dielca (z-fighting). Mensie nez HoverEdge::OUT_MM (0,9), takze
      # zvyraznena hrana ostava nad kresbou.
      OUT_MM = 0.6
      COLOR = [55, 71, 79].freeze # #37474f = token --nx-ink-strong
      LINE_WIDTH = 2

      # Adaptivny rozostup: pocet ciar rastie s rozmerom NAPRIEC kresbou, takze
      # rozostup (span / (n + 1)) rastie tiez — na uzkej blende su 3 ciary, na
      # sirokom bocnom paneli 5. Vzdy 3..5: menej uz nevyzera ako smer, viac je
      # v modeli s 254 dielcami mazanica.
      COUNT_SMALL_MM = 200.0
      COUNT_MID_MM = 500.0

      # Ciara nedobieha az k hrane (6 % dlzky z kazdej strany) — kresba tak
      # zostane odlisitelna od geometrickych hran dielca.
      INSET_FRAC = 0.06

      OVERLAY_ID = 'noxun.engine.grain_check'
      OVERLAY_NAME = 'Noxun — smer kresby'

      # Prepinac je vec POCITACA, nie zakazky — zije v %APPDATA%, NIKDY v .skp
      # (vzor EdgeCheck D-105). Pamata sa, aby sa kontrola smeru nemusela
      # zapinat pri kazdom otvoreni Studia.
      #
      # VSTUPNE BODY su DVA (od v0.7.27): prepinac „Smer kresby" v Studiu
      # a tlacidlo „Kontrola kresby" v raile Inspectora. Oba idu tou istou
      # cestou `Engine.toggle_grain_check` a citaju ten isty `ui_state` —
      # ZIADNY druhy kanal a ziadna vlastna kopia stavu (vzor ABS kontroly).
      SETTINGS_FILE = 'grain_check.json'
      SETTINGS_STD = 1
      ACTIVE_KEY = 'active'

      module_function

      # ================= CISTE ROZHODNUTIA (headless testovatelne) =============

      # Smer, ktory sa da nakreslit, alebo nil (material bez kresby / neznama
      # hodnota). Cita VYHRADNE snapshot dielca.
      def drawable_grain(cfg)
        return nil unless cfg.is_a?(Hash)
        g = (cfg['grain_direction'] || cfg[:grain_direction]).to_s
        GRAINS.include?(g) ? g : nil
      end

      # Pocet ciar podla rozmeru NAPRIEC kresbou (mm).
      def line_count(span_mm)
        s = span_mm.to_f
        return 3 if s < COUNT_SMALL_MM
        return 4 if s < COUNT_MID_MM
        5
      end

      # Os, po ktorej ciary BEZIA, a os, po ktorej sa ROZOSTUPUJU:
      # [os_ciary, os_rozostupu] alebo nil. Vychadza z osi deskriptora — dlzka
      # a sirka su vyrobne udaje, nie „ta vacsia / ta mensia".
      def line_axes(ax, grain)
        return nil unless ax.is_a?(Hash) && GRAINS.include?(grain.to_s)
        t = ax[:thickness]
        line = grain.to_s == 'length' ? ax[:length] : ax[:width]
        return nil if t.nil? || line.nil? || t == line
        cross = ([0, 1, 2] - [t, line])
        cross.length == 1 ? [line, cross.first] : nil
      end

      # Usecky kresby v LOKALNYCH mm ako pole dvojic [[x,y,z], [x,y,z]].
      # lo/hi = protilahle rohy kvadra dielca (obal definicie), `out` = posun
      # VON z telesa. Kresli sa na OBE dekorove plochy (min aj max osi hrubky).
      # Prazdne pole = nekresli sa nic (bez osi, bez smeru, degenerovany kvader).
      def segments_mm(lo, hi, ax, grain, out = OUT_MM)
        axes = line_axes(ax, grain)
        return [] if axes.nil?
        return [] unless lo.is_a?(Array) && hi.is_a?(Array) && lo.length == 3 && hi.length == 3
        line, cross = axes
        thick = ax[:thickness]
        span = hi[cross].to_f - lo[cross].to_f
        run = hi[line].to_f - lo[line].to_f
        return [] unless span > 0.0 && run > 0.0
        n = line_count(span)
        a0 = lo[line].to_f + run * INSET_FRAC
        a1 = hi[line].to_f - run * INSET_FRAC
        segs = []
        [lo[thick].to_f - out, hi[thick].to_f + out].each do |depth|
          (1..n).each do |i|
            c = lo[cross].to_f + span * i / (n + 1).to_f
            segs << [point_at(thick, depth, cross, c, line, a0),
                     point_at(thick, depth, cross, c, line, a1)]
          end
        end
        segs
      end

      def entity_id(ent)
        ent.respond_to?(:entityID) ? ent.entityID : nil
      rescue StandardError
        nil
      end

      def point_at(ai, av, bi, bv, ci, cv)
        p = [0.0, 0.0, 0.0]
        p[ai] = av
        p[bi] = bv
        p[ci] = cv
        p
      end

      # ================= PREPINAC: perzistencia (%APPDATA%) ====================

      def settings_dir
        return Materials.dir if defined?(Materials)
        File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
      end

      def settings_path
        File.join(settings_dir, SETTINGS_FILE)
      end

      # Zapamatany stav prepinaca. Poskodeny subor / cudzi typ = false (nikdy
      # vynimka a nikdy „nahodne" zapnuta kresba nad cudzou zakazkou).
      def remembered?
        raw = JsonFileStore.available?(settings_path) ? JsonFileStore.read(settings_path) : nil
        raw.is_a?(Hash) && raw[ACTIVE_KEY] == true
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.remembered?')
        false
      end

      def remember!(value)
        JsonFileStore.write(settings_path, { ACTIVE_KEY => value == true, 'std' => SETTINGS_STD })
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.remember!')
        false
      end

      # ================= SKEN MODELU (SketchUp) ================================
      # Vysledok: { 'occurrences' => [ { 'unresolved' => bool, 'lines' => [Point3d…] } ],
      #             'skipped' => pocet dielcov bez kresby }
      # Body su UZ v SVETOVYCH suradniciach a v poradi pre GL_LINES — draw uz
      # nepocita nic.
      def scan(model)
        out = { 'occurrences' => [], 'skipped' => 0 }
        return out unless model && defined?(EdgeCheck)
        EdgeCheck.each_part(model) do |ent, tr, _owner|
          cfg = Store.config(ent) || {}
          grain = drawable_grain(cfg)
          if grain.nil?
            out['skipped'] += 1
            next
          end
          add_occurrence(out, ent, tr, cfg, grain)
        end
        out
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.scan')
        out
      end

      def add_occurrence(out, ent, tr, cfg, grain)
        role = (Store.get(ent, 'role') || cfg['role']).to_s
        b = ent.definition.bounds
        lo = [Units.to_mm(b.min.x), Units.to_mm(b.min.y), Units.to_mm(b.min.z)]
        hi = [Units.to_mm(b.max.x), Units.to_mm(b.max.y), Units.to_mm(b.max.z)]
        box = [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]]
        prod = { 'length' => cfg['length'], 'width' => cfg['width'], 'thickness' => cfg['thickness'] }
        ax = PartFaces.axes_for_snapshot(role, box, prod)
        # Identita VYSKYTU (nie persistent_id — kopie korpusu pred dedup tickom
        # ho zdielaju). Kresba ju nepotrebuje, ale diagnostika a in-SketchUp
        # testy ano: „ktora usecka patri ktoremu dielcu".
        occ = { 'part' => entity_id(ent), 'unresolved' => ax.nil?, 'lines' => [] }
        out['occurrences'] << occ
        return if ax.nil?
        segments_mm(lo, hi, ax, grain, OUT_MM).each do |a, z|
          occ['lines'] << Units.point(a[0], a[1], a[2]).transform(tr)
          occ['lines'] << Units.point(z[0], z[1], z[2]).transform(tr)
        end
      end

      # ================= PAYLOAD PRE KRESLENIE + CISLA =========================
      # Z hotovej scan cache spravi JEDNO ploche pole bodov (GL_LINES) a
      # deterministicke pocty. Bezi pri zmene cache, NIKDY per frame.
      def view_payload
        return @payload if @payload
        cache = @cache
        return nil if cache.nil?
        pts = []
        parts = 0
        unresolved = 0
        Array(cache['occurrences']).each do |occ|
          if occ['unresolved']
            unresolved += 1
            next
          end
          lines = occ['lines'] || []
          next if lines.empty?
          parts += 1
          pts.concat(lines)
        end
        @payload = { 'points' => pts, 'parts' => parts, 'lines' => pts.length / 2,
                     'unresolved' => unresolved, 'skipped' => cache['skipped'].to_i }
      end

      # ================= ZIVOTNY CYKLUS OVERLAYU ===============================

      # Overlay API zije od SU 2023; starsi SketchUp funkciu jednoducho nema.
      def available?(model = nil)
        return false unless defined?(GrainOverlay)
        m = model || active_model
        !m.nil? && m.respond_to?(:overlays)
      rescue StandardError
        false
      end

      # ZAPNUTE = mame overlay, patri TOMUTO modelu, je v nom zaregistrovany a
      # nie je NATIVNE vypnuty v paneli Overlays (Utilities) — vtedy by ostal
      # zaregistrovany, ale prestal kreslit (Codex #152 P2 pri D-104).
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

      # Identita dokumentu pre overlay lifecycle — TVAR AJ DOVODY su spolocne
      # s `EdgeCheck.same_model?` (tam je plne zdovodnenie). Skratene: `equal?`
      # ma prednost; zaloha vyzaduje ZHODNY guid A ZHODNU cestu, lebo guid je
      # obsah .skp suboru a dve sucasne otvorene KOPIE tej istej zakazky ho maju
      # rovnaky (review #267 kolo 3, P3) — bez cesty by prekrytie ostalo visiet
      # nad cudzim dokumentom.
      def same_model?(a, b)
        return false if a.nil? || b.nil?
        return true if a.equal?(b)
        ga = a.respond_to?(:guid) ? a.guid.to_s : ''
        gb = b.respond_to?(:guid) ? b.guid.to_s : ''
        return false if ga.empty? || ga != gb
        pa = a.respond_to?(:path) ? a.path.to_s : ''
        pb = b.respond_to?(:path) ? b.path.to_s : ''
        pa == pb
      rescue StandardError
        false
      end

      # Prepnutie + ZAPAMATANIE. Zapisuje sa VYSLEDNY stav (ked zapnutie zlyha,
      # nezapamata sa „zapnute" — inak by sa okno pri kazdom otvoreni pokusalo
      # obnovit nieco, co nefunguje).
      def toggle(model)
        active?(model) ? disable! : enable!(model)
        st = ui_state(model)
        remember!(st['active'] == true)
        st
      end

      # ZAPNUTIE. Odstraneny Sketchup::Overlay je navzdy neplatny a NESMIE sa
      # pridat druhykrat (Codex audit BLOCKER 1 pri D-104) — pri kazdom zapnuti
      # sa tvori NOVA instancia a stara sa zahadzuje.
      def enable!(model)
        return ui_state(model) unless available?(model)
        disable! if @overlay
        drop_registered(model)
        ov = GrainOverlay.new
        unless model.overlays.add(ov)
          Engine.log('K2: overlay smeru kresby sa nepodarilo zaregistrovat (uz je pridany?)')
          return ui_state(model)
        end
        @overlay = ov
        @model = model
        begin
          ov.enabled = true if ov.respond_to?(:enabled=)
        rescue StandardError => e
          Engine.log_error(e, 'GrainCheck.enable! overlay.enabled=')
        end
        attach_observer(model)
        refresh!(model)
        ui_state(model)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.enable!')
        ui_state(model)
      end

      def disable!
        m = @model
        ov = @overlay
        @overlay = nil
        @model = nil
        @cache = nil
        @payload = nil
        @dirty = false
        detach_observer(m)
        remove_overlay(m, ov)
        invalidate(m)
        ui_state(m)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.disable!')
        ui_state(nil)
      end

      # Obnovenie zapamataneho stavu pri otvoreni Studia. Prepinac je vec
      # POCITACA — zakazka o nom nevie. Zapamatany stav sa NEPREPISUJE (nie je
      # to pouzivatelov klik), takze zlyhanie obnovy nastavenie nezrusi.
      def restore!(model)
        return ui_state(model) unless remembered?
        return ui_state(model) if active?(model) || !available?(model)
        enable!(model)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.restore!')
        ui_state(model)
      end

      # Prepnutie/otvorenie ineho dokumentu: overlay patril STAREMU modelu,
      # takze sa vypina — ale zapamatany prepinac ostava (patri pocitacu).
      def on_model_changed(model)
        return if @overlay.nil?
        return if !model.nil? && same_model?(@model, model)

        disable!
        notify_state_changed
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.on_model_changed')
      end

      # Stav dostanu VSETKY okna, ktore prepinac zobrazuju — Studio aj rail
      # Inspectora (jeden zdroj stavu, dva vstupne body).
      def notify_state_changed
        Engine.broadcast_grain_check(ui_state(active_model))
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.notify_state_changed')
      end

      def remove_overlay(model, overlay)
        return unless overlay && model && model.respond_to?(:overlays)
        model.overlays.remove(overlay)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.remove_overlay')
      end

      # Poistka po reloade pluginu: overlay s NASIM id uz moze byt v modeli
      # zaregistrovany (stara instancia z predosleho behu) — `add` by zlyhal.
      def drop_registered(model)
        return unless model.respond_to?(:overlays)
        model.overlays.to_a.each do |o|
          next unless o.respond_to?(:overlay_id) && o.overlay_id.to_s == OVERLAY_ID
          model.overlays.remove(o)
        end
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.drop_registered')
      end

      # ================= CACHE + INVALIDACIA ===================================

      def refresh!(model = nil)
        m = model || @model
        return if m.nil?
        @cache = scan(m)
        @payload = nil
        @dirty = false
        @cache
      end

      # Volane z ModelObservera (commit/undo/redo/abort) — PRESTAVBA skrinky
      # zmeni smer aj geometriu dielcov. V observeri sa NIC neskenuje ani
      # nemeni; len sa oznaci cache za starú a poziada sa o prekreslenie,
      # samotny prepocet bezi az v `draw`.
      def mark_dirty(model)
        return unless @overlay && same_model?(@model, model)
        @dirty = true
        @payload = nil
        request_redraw(model)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.mark_dirty')
      end

      # Samotny „dirty" flag prekreslenie NEZARUCUJE (nehybny pohlad draw
      # nevola) — vyziada sa explicitne, ale az PO observer callbacku (timer 0).
      def request_redraw(model)
        return if @redraw_pending
        @redraw_pending = true
        UI.start_timer(0, false) do
          begin
            @redraw_pending = false
            invalidate(model) if @overlay && same_model?(@model, model)
          rescue StandardError => e
            Engine.log_error(e, 'GrainCheck.request_redraw')
          end
        end
      end

      def invalidate(model)
        return unless model && model.respond_to?(:active_view) && model.active_view
        model.active_view.invalidate
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.invalidate')
      end

      def attach_observer(model)
        return unless defined?(GrainModelWatch)
        @observer ||= GrainModelWatch.new
        begin
          model.remove_observer(@observer)
        rescue StandardError
          nil
        end
        model.add_observer(@observer)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.attach_observer')
      end

      def detach_observer(model)
        return unless model && @observer
        model.remove_observer(@observer)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.detach_observer')
      end

      # ================= KRESLENIE =============================================

      # Vola ju Overlay#draw. Prepocet je LAZY (len ked je cache stara) — nikdy
      # per frame; body su hotove vo `view_payload`.
      def draw(view)
        model = view.respond_to?(:model) ? view.model : nil
        if @cache.nil? || @dirty
          refresh!(model || @model)
          notify_count_changed
        end
        payload = view_payload
        return if payload.nil?
        pts = payload['points']
        return if pts.nil? || pts.empty?
        view.drawing_color = Sketchup::Color.new(*COLOR)
        view.line_width = LINE_WIDTH
        view.draw(GL_LINES, pts)
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.draw')
        nil
      end

      # Obal kresby — bez neho SketchUp kresbu mimo obalu modelu oreze (ciary su
      # posunute 0,6 mm von). Vzor D-104 BLOCKER 4.
      def extents(model = nil)
        bb = Geom::BoundingBox.new
        m = model || @model
        bb.add(m.bounds) if m && m.respond_to?(:bounds)
        Array(@cache ? @cache['occurrences'] : []).each do |occ|
          Array(occ['lines']).each { |p| bb.add(p) }
        end
        bb
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.extents')
        Geom::BoundingBox.new
      end

      # ================= STAV PRE OKNO =========================================

      # Tvar pre listu sekcie Kontrola v Studiu. Cisla su VYHRADNE zo servera (JS si nic
      # neprepocitava) a nesmu byt stare — pri oznacenej cache sa prepocitaju TU.
      def ui_state(model = nil)
        m = model || active_model
        on = active?(m)
        refresh!(m) if on && (@cache.nil? || @dirty)
        p = on ? view_payload : nil
        { 'available' => available?(m), 'active' => on,
          'parts' => p ? p['parts'] : nil,
          'lines' => p ? p['lines'] : nil,
          'skipped' => p ? p['skipped'] : nil,
          'unresolved' => p ? p['unresolved'] : nil }
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.ui_state')
        { 'available' => false, 'active' => false }
      end

      # Po prepocte (draw po prestavbe): Studio dostane cerstve cisla.
      # Burst eventov sa zluci do JEDNEHO pushu (timer + pending guard).
      def notify_count_changed
        return if @notify_pending
        @notify_pending = true
        UI.start_timer(0, false) do
          begin
            @notify_pending = false
            Engine.broadcast_grain_check
          rescue StandardError => e
            Engine.log_error(e, 'GrainCheck.notify_count_changed')
          end
        end
      rescue StandardError => e
        Engine.log_error(e, 'GrainCheck.notify_count_changed')
      end

      def active_model
        defined?(Sketchup) ? Sketchup.active_model : nil
      rescue StandardError
        nil
      end
    end
  end
end
