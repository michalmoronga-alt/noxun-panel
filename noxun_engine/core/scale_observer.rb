# frozen_string_literal: true
# Noxun Engine — scale observer. Zachyti zmenu velkosti NOXUN korpusu nastrojom
# Scale a prestavi korpus na nove rozmery so spravnymi hrubkami (absorpcia scale do configu).
#
# Vzor observer managementu prevzaty z KOVANIE (main.rb): AppObserver re-attach na
# open/new/activate model, singleton observery, bezpecny detach pred attach, debounce
# cez UI.start_timer + monotonny generation counter, guard flag proti vlastnym zmenam.
#
# KRITICKE guardy:
#   @rebuilding  — observer ignoruje zmeny, ktore sposobil sam plugin (rebuild/insert).
#   debounce     — rychle tahanie Scale nespusti N rebuildov, prebehne 1 po ustaleni.
#   begin/rescue — vynimka v observeri = ticho mrtvy observer, preto vsetko obalene + log.
module Noxun
  module Engine
    module ScaleWatch
      SCALE_TOL = 0.001  # tolerancia: dlzka osi != 1.0 => scale
      DEBOUNCE  = 0.2    # s — cakanie na ustalenie po poslednej zmene
      MIN = { 'width' => 200.0, 'height' => 200.0, 'depth' => 150.0 }.freeze

      class << self
        # --- instalacia -----------------------------------------------------
        def install
          @entity_observer ||= CabinetEntityObserver.new
          @entities_observer ||= CabinetEntitiesObserver.new
          @app_observer ||= EngineAppObserver.new
          @stable_transforms = {}
          safe { Sketchup.remove_observer(@app_observer) }
          Sketchup.add_observer(@app_observer)
          n = attach_all(Sketchup.active_model)
          # KRITICKE: entities observer (zachytava KOPIE) treba pripojit aj pri instale —
          # nie len v AppObserver eventoch (open/new). Bez tohto po starte SketchUpu
          # (alebo ak event nepride) kopie nedostanu nove ID a ich zony nesleduju presun.
          attach_entities(Sketchup.active_model)
          Engine.log("ScaleWatch nainstalovany (attachnute korpusy: #{n})")
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.install')
        end

        # Attach entity observer na vsetky existujuce korpusy A DOSKY v modeli (V0.4.7d)
        # + entities observer na model.entities (zachytenie kopii). Initial scan /
        # re-attach (install, open/new/activate).
        def attach_all(model)
          return 0 unless model
          @entity_observer ||= CabinetEntityObserver.new
          attach_entities(model)
          n = 0
          DEDUP_KINDS.each do |kind|
            Ids.each_of_kind(model, kind) { |inst| attach_one(inst); n += 1 }
          end
          n
        end

        # Attach entities observer na model.entities — zachyti PRIDANIE novych entit, hlavne
        # KOPII korpusu (Ctrl+C/V, Move+Ctrl), ktore nededia per-instancny EntityObserver.
        # Bezpecny re-attach (remove pred add) — idempotentne, reload-safe (bez dvojiteho attachu).
        def attach_entities(model)
          return unless model
          @entities_observer ||= CabinetEntitiesObserver.new
          safe { model.entities.remove_observer(@entities_observer) } # anti-double
          model.entities.add_observer(@entities_observer)
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.attach_entities')
        end

        # Attach na jednu instanciu (korpus/doska; volane aj buildermi po vlozeni).
        # V0.4.7d (Codex audit d, blocker 1): transform sa NEuklada ako stabilny,
        # ak uz nesie scale — cerstvo attachnuta ESTE NEabsorbovana kopia (paste +
        # scale v jednom ticku) by inak pri neskorsom rejecte obnovila skalovany
        # stav. Stabilny transform zapise az uspesna absorpcia / cisty stav.
        def attach_one(inst)
          return unless inst && inst.valid?
          @entity_observer ||= CabinetEntityObserver.new
          safe { inst.remove_observer(@entity_observer) } # anti-double
          inst.add_observer(@entity_observer)
          remember_transform(inst) unless scaled?(inst.transformation)
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.attach_one')
        end

        # --- guard (vlastne rebuildy nesmu spustit observer) ---------------
        def guard
          prev = @rebuilding
          @rebuilding = true
          yield
        ensure
          @rebuilding = prev
        end

        def rebuilding?
          @rebuilding ? true : false
        end

        # --- volane z observera --------------------------------------------
        # Zmena korpusu/dosky (V0.4.7d): scale -> absorpcia (rebuild), inak
        # (move/rotate) -> korpus presunie ghost zony, doska si len zapamata transform.
        # Rozlisenie scale/move sa robi az v process_dirty (po ustaleni transformacie).
        def notify_change(entity)
          return if @rebuilding
          return unless entity && entity.valid?
          return unless DEDUP_KINDS.include?(Store.kind(entity).to_s)
          @dirty ||= {}
          @dirty[entity.entityID] = entity
          @last_model = (entity.model rescue nil) || @last_model # fix #8: model pre prune
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_change')
        end

        # Zmazanie entity (napr. korpusu) -> pri najblizsom tiku upraceme osirotene ghost skupiny.
        # fix #8: model nesieme z eventu (pri erase je Sketchup.active_model v multi-model nespolahlivy).
        def notify_erase(model = nil)
          return if @rebuilding
          @need_prune = true
          @erase_model = model || @erase_model || @last_model
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_erase')
        end

        # Pridanie entity do model.entities — zachyti KOPIU korpusu alebo DOSKY
        # (Ctrl+C/V, Move+Ctrl). Kopia dedi NOXUN atributy (zdielane id) ale NEdedi
        # per-instancny EntityObserver — bez spracovania by ostala so zdielanou identitou.
        # Debounced spracovanie (process_dirty): dedup (nove id; korpus aj vlastne ghosty)
        # + attach per-instancneho observera (len korpusy; dosky ho v b nemaju).
        # Guard: vlastne vlozenie (CabinetBuilder/BoardBuilder.build) je guardnute, takze
        # onElementAdded (davkovany na commit) tu vidi @rebuilding=true a ignoruje ho.
        DEDUP_KINDS = %w[cabinet board].freeze

        def notify_added(entity)
          return if @rebuilding
          return unless entity.is_a?(Sketchup::ComponentInstance) && entity.valid?
          return unless DEDUP_KINDS.include?(Store.kind(entity).to_s)
          @added ||= {}
          @added[entity.entityID] = entity
          @last_model = (entity.model rescue nil) || @last_model # fix #8: model pre dedup/prune
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_added')
        end

        # Debounce + generation counter: kazda zmena posunie generaciu a restartuje timer;
        # spusti sa iba posledny naplanovany tick.
        def schedule
          @generation = (@generation || 0) + 1
          gen = @generation
          safe { UI.stop_timer(@timer) } if @timer
          @timer = UI.start_timer(DEBOUNCE, false) do
            begin
              if gen == @generation
                @timer = nil
                process_dirty
              end
            rescue StandardError => e
              Engine.log_error(e, 'ScaleWatch timer')
            end
          end
        end

        def process_dirty
          dirty = @dirty || {}
          @dirty = {}
          added = @added || {}
          @added = {}
          need_prune = @need_prune
          @need_prune = false
          erase_model = @erase_model
          @erase_model = nil

          # fix #6 + kopie: kopia korpusu (zdielane cabinet_id) -> nove ID + vlastne ghosty, este
          # pred spracovanim dirty. Spusti sa aj z onElementAdded (kopia Ctrl+C/V), nielen z move
          # existujuceho. Multi-model (Codex PR#6): v jednom debounce okne mozu prist instancie
          # z viacerych dokumentov (macOS) — dedup/attach bezi pre KAZDY dotknuty model zvlast.
          touched_models = (dirty.values + added.values)
                           .select { |i| i && i.valid? }.map(&:model).compact.uniq
          touched_models = [erase_model || @last_model].compact if touched_models.empty?
          added_models = added.values.select { |i| i && i.valid? }.map(&:model).compact.uniq

          touched_models.each do |mdl|
            # Transparentny dedup LEN pre entity, ktore v TOMTO ticku realne pribudli
            # (onElementAdded) — vtedy je predchadzajuca operacia ich paste/move a 1x undo
            # vrati kopiu celu. V0.4.7b (Codex audit + GH review P2): pri cerstvych
            # entitach sa v tomto ticku spracuju VYHRADNE ony (transparent drzi priamo
            # na paste operacii); pripadne STARE duplicity v tom istom okne sa odlozia
            # na follow-up tick (schedule) a spracuju sa ako samostatne undo kroky.
            fresh_copy = added_models.include?(mdl)
            fresh_ids = added.values.select { |i| i && i.valid? && (i.model rescue nil) == mdl }
                             .map(&:entityID)
            if fresh_ids.empty?
              CabinetBuilder.dedup_copies(mdl) if defined?(CabinetBuilder)
              BoardBuilder.dedup_copies(mdl) if defined?(BoardBuilder)
            else
              CabinetBuilder.dedup_copies(mdl, fresh_ids: fresh_ids) if defined?(CabinetBuilder)
              BoardBuilder.dedup_copies(mdl, fresh_ids: fresh_ids) if defined?(BoardBuilder)
              stale = defined?(Ids) &&
                      (Ids.duplicate_cabinets(mdl) + Ids.duplicate_boards(mdl))
                      .any? { |i| i && i.valid? }
              # Follow-up bezpecny proti slucke: dalsi tick pride s prazdnym added
              # (fresh_ids prazdne) -> stale sa spracuju vetvou vyssie a schedule
              # sa uz nevola.
              schedule if stale
            end
            # Kopie zachytene cez onElementAdded nemaju vlastny per-instancny EntityObserver
            # (kopia ho nededi). Po dedupe (novy cabinet_id + ghosty cez rebuild->sync_ghost)
            # im observer pripojime, aby ich buduci move/scale spustil ghost sync.
            # attach_all je idempotentne (iteruje len korpusy — dosky observer v b nemaju).
            attach_all(mdl) if fresh_copy
          end

          dirty.each_value do |inst|
            next unless inst && inst.valid?
            m = inst.model # fix #8: model per dirty instancia (nie Sketchup.active_model)
            board = Store.kind(inst) == 'board'
            if scaled?(inst.transformation)
              board ? absorb_board(inst) : absorb(inst) # scale -> rebuild (korpus aj sync ghostov)
            elsif board
              remember_transform(inst) # move/rotate dosky — ziadne ghosty
            else
              move_ghost_op(m, inst) # move/rotate korpusu -> len presun ghost skupin
              remember_transform(inst)
            end
          rescue StandardError => e
            if inst && inst.valid? && scaled?(inst.transformation)
              reject_scale(inst, e)
            else
              Engine.log_error(e, 'ScaleWatch.process_dirty')
            end
          end
          if need_prune
            # GH P2: cisty delete (bez predoslych change/add eventov) moze mat vsetky
            # tri zdroje nil — fallback na aktivny model (Windows = jediny dokument;
            # refresh_panel aj prune maju vlastne multi-model guardy).
            prune_model = erase_model || @last_model || touched_models.first || Sketchup.active_model
            prune_ghosts(prune_model)
            # D-34 (audit B4b): po ustaleni erase VZDY resync panela — zmazanie
            # oznacenej skrinky nemusi vystrelit selection event a Inspector by
            # visel na mrtvych datach. push_selected pri prazdnom/neplatnom vybere
            # posle NX.clearSelected -> rezim vkladania + reset karty (audit B2).
            # Model je zachyteny z eventu PRED invalidaciou entity (fix #8);
            # refresh_panel ma multi-model guard (len aktivny dokument).
            refresh_panel(prune_model)
          end
        end

        # Presun ghost zon za korpusom (bez rebuildu). TRANSPARENTNA operacia (fix #3): 4. param
        # transparent=true pripoji tento krok k predchadzajucej (user-ovej move) operacii, takze
        # 1x undo vrati korpus AJ ghosty naraz — nie zvlast.
        def move_ghost_op(model, inst)
          return unless defined?(Zones)
          model.start_operation('Noxun: presun zon', true, false, true)
          Zones.move_ghost(model, inst)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation rescue nil
          Engine.log_error(e, 'ScaleWatch.move_ghost_op')
        end

        # Upratanie osirotenych ghostov po zmazani korpusu. TRANSPARENTNA operacia (fix #3):
        # pripoji sa k user-ovej delete operacii -> 1x undo vrati korpus aj ghosty konzistentne.
        def prune_ghosts(model)
          return unless defined?(Zones) && model
          model.start_operation('Noxun: uprac zony', true, false, true)
          Zones.prune_orphans(model)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation rescue nil
          Engine.log_error(e, 'ScaleWatch.prune_ghosts')
        end

        # --- detekcia scale -------------------------------------------------
        # Scale = dlzky STLPCOV matice (to_a) delene w (a[15]) — NEZAVISLE od rotacie.
        # POZOR: tr.xaxis/yaxis/zaxis vracaju NORMALIZOVANY smer (dlzka vzdy 1), scale v nich
        # nie je — preto sa cita priamo z matice, inak by scale nikdy nebol detegovany.
        def scale_factors(tr)
          a = tr.to_a
          w = a[15]
          w = 1.0 if w.nil? || w.abs < 1e-9
          sx = Math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]) / w
          sy = Math.sqrt(a[4] * a[4] + a[5] * a[5] + a[6] * a[6]) / w
          sz = Math.sqrt(a[8] * a[8] + a[9] * a[9] + a[10] * a[10]) / w
          return nil if near_one?(sx) && near_one?(sy) && near_one?(sz)
          [sx, sy, sz]
        end

        def scaled?(tr)
          !scale_factors(tr).nil?
        end

        def near_one?(v)
          (v - 1.0).abs < SCALE_TOL
        end

        # --- absorpcia scale do configu ------------------------------------
        def absorb(inst)
          model = inst.model
          cfg = Store.config(inst)
          return unless cfg
          f = scale_factors(inst.transformation)
          return unless f
          sx, sy, sz = f # X=sirka, Y=hlbka, Z=vyska (lokalne osi korpusu)

          base_w = cfg['width'].to_f
          base_h = cfg['height'].to_f
          base_d = cfg['depth'].to_f
          cid = cfg['cabinet_id'] || Store.get(inst, 'cabinet_id')

          new_w = clamp_min('width',  (base_w * sx).round.to_f, cid)
          new_h = clamp_min('height', (base_h * sz).round.to_f, cid)
          new_d = clamp_min('depth',  (base_d * sy).round.to_f, cid)

          params = CabinetBuilder.config_to_params(cfg)
          params['width']  = new_w
          params['height'] = new_h
          params['depth']  = new_d

          clean = clean_transform(inst.transformation)
          # V0.3.4 undo fix (runner S1): TRANSPARENTNA operacia — absorpcia sa pripoji
          # k pouzivatelovmu Scale kroku. 1x undo vrati scale AJ absorpciu naraz (predtym
          # undo vratil len absorpciu, observer videl scaled transform a absorboval znova
          # — undo "bojoval" s pouzivatelom).
          # ZNAMY okrajovy race (Codex review PR #21): debounce bezi 0.2 s — ak pouzivatel
          # stihne MEDZITYM commitnut inu operaciu, absorpcia sa prilepi na nu (API nevie
          # nahliadnut do undo stacku). Dosledok pri undo tej operacie: vrati sa aj absorpcia,
          # observer scaled stav zdetekuje a znova absorbuje TRANSPARENTNE k povodnemu Scale
          # — system konverguje do spravneho zlucenia sam; obetou je redo historia daneho kroku.
          # Vedome akceptovane: okno 0.2 s, zriedkave; netransparentna alternativa = trvalo
          # rozbite undo po scale (povodny stav pred fixom).
          CabinetBuilder.rebuild(model, inst, params,
                                 transform: clean, op_name: 'Noxun: prepočet po zmene veľkosti',
                                 transparent: true)
          remember_transform(inst)
          refresh_panel(model) # V0.4.7e: karta uz neukazuje stare rozmery do reselect-u

          Engine.log("scale absorb #{cid}: #{base_w.round}x#{base_h.round}x#{base_d.round} -> " \
                     "#{new_w.round}x#{new_h.round}x#{new_d.round} (f=#{sx.round(3)},#{sy.round(3)},#{sz.round(3)})")
        end

        # Panel po absorpcii ukazoval STARE rozmery az do reselect-u (znama medzera
        # od V0.4.5) — obnovi sa standardnym sync tickom; bez otvoreneho panela no-op.
        # Multi-model guard (Codex GH #36): debounced absorpcia na POZADOVOM modeli
        # (macOS viac dokumentov) nesmie prepisat Inspector aktivneho dokumentu.
        def refresh_panel(model)
          return unless model == Sketchup.active_model
          Panel.push_selected(model) if defined?(Panel)
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.refresh_panel')
        end

        def clamp_min(key, val, cid)
          m = MIN[key]
          return val if m.nil? || val >= m
          Engine.log("scale absorb #{cid}: #{key} #{val.round} < min #{m.round} — clampujem na #{m.round}")
          m
        end

        # --- absorpcia scale DOSKY (V0.4.7d) --------------------------------
        # Lokalne osi dosky su vyrobna pravda: X=length, Y=width, Z=thickness.
        # Absorbuju sa LEN X/Y; hrubku RIADI katalogovy material — Z faktor sa
        # zahodi a rebuild vrati geometriu hrubky na config hodnotu (pouzivatel
        # dostane nemodalny status, ziadny messagebox z observera).
        # POZOR (Codex audit d): pri neuniformnom GLOBALNOM scale sikmo natocenej
        # dosky vznika shear — stlpce matice prestanu byt kolme a osi sa miesaju.
        # Taky transform sa NEabsorbuje (reject) — absorpcia by vyrobila nezmysel.
        def absorb_board(inst)
          model = inst.model
          cfg = Store.config(inst)
          return unless cfg
          tr = inst.transformation
          f = scale_factors(tr)
          return unless f
          raise 'Doska je skosena neuniformnym scale — zmena velkosti sa neda prevziat.' if sheared?(tr)
          sx, sy, sz = f
          bid = Store.get(inst, 'id')

          lim = BoardBuilder::LIMITS
          new_l = (cfg['length'].to_f * sx).round.to_f.clamp(lim[:length][0], lim[:length][1])
          new_w = (cfg['width'].to_f * sy).round.to_f.clamp(lim[:width][0], lim[:width][1])
          clamped = ((cfg['length'].to_f * sx).round.to_f != new_l) || ((cfg['width'].to_f * sy).round.to_f != new_w)

          clean = clean_transform(tr)
          # TRANSPARENTNA operacia — absorpcia sa pripoji k pouzivatelovmu Scale
          # kroku (1x undo vrati oboje; rovnaky vzor + debounce kompromis ako
          # korpusova absorb, viz komentar tam).
          BoardBuilder.rebuild(model, inst, { 'length' => new_l, 'width' => new_w },
                               transform: clean, op_name: 'NOXUN: Prepocet dosky po zmene velkosti',
                               transparent: true)
          remember_transform(inst)
          refresh_panel(model) # V0.4.7e: karta dosky sa obnovi hned po absorpcii

          if (sz - 1.0).abs >= SCALE_TOL
            notify_user("Hrúbku dosky #{bid} určuje materiál — ostáva #{cfg['thickness'].to_f.round(1)} mm.")
          elsif clamped
            notify_user("Rozmer dosky #{bid} bol orezaný na povolený rozsah.")
          end
          Engine.log("scale absorb #{bid}: #{cfg['length'].to_f.round}x#{cfg['width'].to_f.round} -> " \
                     "#{new_l.round}x#{new_w.round} (f=#{sx.round(3)},#{sy.round(3)},#{sz.round(3)})")
        end

        # Shear detekcia: ocistene (normalizovane) osi musia byt navzajom kolme.
        def sheared?(tr, tol = 0.001)
          x = tr.xaxis.normalize
          y = tr.yaxis.normalize
          z = tr.zaxis.normalize
          x.dot(y).abs > tol || x.dot(z).abs > tol || y.dot(z).abs > tol
        end

        # Nemodalne oznamenie z observera: SketchUp status bar (vzdy) + panel status
        # (ak je otvoreny). Modal z asynchronneho observera je zle UX.
        def notify_user(msg)
          Sketchup.status_text = msg
          Panel.set_status(msg) if defined?(Panel)
        rescue StandardError
          nil
        end

        # Cisty transform: povodny origin + rotacia, BEZ scale (normalizovane osi).
        def clean_transform(tr)
          Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)
        end

        # Ak validacia rebuildu odmietne Scale, vratime presne poslednu stabilnu
        # polohu/rotaciu/velkost. Transparentna operacia sa pripoji k pouzivatelovmu
        # Scale kroku, takze model ani vyrobne data nezostanu v rozpornom stave.
        # V0.4.7d: typove rozvetvenie \u2014 doska nema ghosty a identita je v 'id';
        # doskova hlaska je NEMODALNA (status), korpusovy messagebox ostava.
        def reject_scale(inst, error)
          model = inst.model
          board = Store.kind(inst) == 'board'
          restore = stable_transform(inst) || clean_transform(inst.transformation)
          guard do
            model.start_operation('Noxun: zrusena neplatna zmena velkosti', true, false, true)
            begin
              inst.transformation = restore
              Zones.move_ghost(model, inst) if !board && defined?(Zones)
              model.commit_operation
            rescue StandardError => restore_error
              model.abort_operation rescue nil
              Engine.log_error(restore_error, 'ScaleWatch.reject_scale restore')
              return false
            end
          end
          remember_transform(inst)
          Engine.log_error(error, 'ScaleWatch.scale rejected')
          if board
            notify_user("Zmena ve\u013ekosti dosky #{Store.get(inst, 'id')} bola zru\u0161en\u00e1: #{error.message}")
          else
            cid = Store.get(inst, 'cabinet_id')
            UI.messagebox("Zmena ve\u013ekosti skrinky #{cid} bola zru\u0161en\u00e1, preto\u017ee by vytvorila neplatn\u00fa kon\u0161trukciu.\n\n#{error.message}")
          end
          true
        rescue StandardError => notify_error
          Engine.log_error(notify_error, 'ScaleWatch.reject_scale notify')
          false
        end

        def remember_transform(inst)
          return unless inst && inst.valid?
          @stable_transforms ||= {}
          @stable_transforms[transform_key(inst)] = inst.transformation.to_a.dup
        end

        def stable_transform(inst)
          values = @stable_transforms && @stable_transforms[transform_key(inst)]
          values && Geom::Transformation.new(values)
        end

        def transform_key(inst)
          [inst.model.object_id, inst.entityID]
        end

        def safe
          yield
        rescue StandardError
          nil
        end
      end

      # EntityObserver na korpus instancii — onChangeEntity pri kazdej zmene entity (vratane Scale).
      class CabinetEntityObserver < Sketchup::EntityObserver
        def onChangeEntity(entity)
          ScaleWatch.notify_change(entity)
        end

        # Zmazanie korpusu -> upraceme jeho ghost zony (osirotene top-level skupiny).
        # fix #8: nesieme model z eventu. Po erase je entity uz neplatna (entity.model by hodilo),
        # preto len ak je este valid?; inak notify_erase padne na @last_model (posledny znamy model).
        def onEraseEntity(entity)
          m = (entity.valid? ? entity.model : nil) rescue nil
          ScaleWatch.notify_erase(m)
        end
      end

      # EntitiesObserver na model.entities — zachyti PRIDANIE korpusu do modelu (hlavne kopie).
      # Nova instancia z kopie (Ctrl+C/V, Move+Ctrl) nededi per-instancny EntityObserver, takze
      # bez tohto by jej presun nespustil ghost sync a zony by ostali na mieste originalu.
      # onElementAdded je davkovany na commit operacie -> pri vlastnom builde (guardnutom) vidi
      # @rebuilding=true a ignoruje ho (ziadne dvojite spracovanie vlastnych vkladov).
      class CabinetEntitiesObserver < Sketchup::EntitiesObserver
        def onElementAdded(_entities, entity)
          ScaleWatch.notify_added(entity)
        end

        # FALLBACK pre zmeny korpusov (move/rotate/scale) NEZAVISLY od per-instancneho
        # EntityObservera — ten sa na kopiu nemusi stihnut/podarit attachnut (Ctrl+V, undo/redo,
        # reload). notify_change si sam odfiltruje ne-korpusy (kind != cabinet) a ma @rebuilding
        # guard, takze vlastne rebuildy/ghost presuny slucku nespustia.
        def onElementModified(_entities, entity)
          ScaleWatch.notify_change(entity)
        end
      end

      # AppObserver — re-attach entity/entities observerov na korpusy pri zmene modelu.
      # DOLEZITE: okrem per-instancnych observerov (attach_all) treba pripojit aj entities
      # observer (attach_entities) — bez neho nefunguju kopie ani fallback zmien.
      # Navyse notifikuje otvorene dialogy viazane na model (RulesDialog) — formular
      # sa nad novym aktivnym modelom nacita nanovo (Codex review PR #26, P1).
      class EngineAppObserver < Sketchup::AppObserver
        def onNewModel(model)
          model_switched(model)
        end

        def onOpenModel(model)
          model_switched(model)
        end

        def onActivateModel(model)
          model_switched(model)
        end

        private

        def model_switched(model)
          ScaleWatch.attach_all(model)
          ScaleWatch.attach_entities(model)
          RulesDialog.on_model_changed(model) if defined?(RulesDialog)
          MaterialsDialog.on_model_changed(model) if defined?(MaterialsDialog)
          ProductionDialog.on_model_changed(model) if defined?(ProductionDialog) # V0.5 B (nova generacia dat)
        end
      end
    end
  end
end
