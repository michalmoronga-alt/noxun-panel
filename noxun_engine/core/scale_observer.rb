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
          @app_observer ||= EngineAppObserver.new
          safe { Sketchup.remove_observer(@app_observer) }
          Sketchup.add_observer(@app_observer)
          n = attach_all(Sketchup.active_model)
          Engine.log("ScaleWatch nainstalovany (attachnute korpusy: #{n})")
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.install')
        end

        # Attach entity observer na vsetky existujuce korpusy v modeli (initial scan / re-attach).
        def attach_all(model)
          return 0 unless model
          @entity_observer ||= CabinetEntityObserver.new
          n = 0
          Ids.each_cabinet(model) { |inst| attach_one(inst); n += 1 }
          n
        end

        # Attach na jednu korpus instanciu (volane aj builderom po vlozeni noveho korpusu).
        def attach_one(inst)
          return unless inst && inst.valid?
          @entity_observer ||= CabinetEntityObserver.new
          safe { inst.remove_observer(@entity_observer) } # anti-double
          inst.add_observer(@entity_observer)
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
        def notify_change(entity)
          return if @rebuilding
          return unless entity && entity.valid?
          return unless Store.kind(entity) == 'cabinet'
          return unless scaled?(entity.transformation)
          @dirty ||= {}
          @dirty[entity.entityID] = entity
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_change')
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
          dirty.each_value do |inst|
            absorb(inst) if inst && inst.valid?
          rescue StandardError => e
            Engine.log_error(e, 'ScaleWatch.absorb')
          end
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
          CabinetBuilder.rebuild(model, inst, params,
                                 transform: clean, op_name: 'Noxun: prepočet po zmene veľkosti')

          Engine.log("scale absorb #{cid}: #{base_w.round}x#{base_h.round}x#{base_d.round} -> " \
                     "#{new_w.round}x#{new_h.round}x#{new_d.round} (f=#{sx.round(3)},#{sy.round(3)},#{sz.round(3)})")
        end

        def clamp_min(key, val, cid)
          m = MIN[key]
          return val if m.nil? || val >= m
          Engine.log("scale absorb #{cid}: #{key} #{val.round} < min #{m.round} — clampujem na #{m.round}")
          m
        end

        # Cisty transform: povodny origin + rotacia, BEZ scale (normalizovane osi).
        def clean_transform(tr)
          Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)
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
      end

      # AppObserver — re-attach entity observera na existujuce korpusy pri zmene modelu.
      class EngineAppObserver < Sketchup::AppObserver
        def onNewModel(model)
          ScaleWatch.attach_all(model)
        end

        def onOpenModel(model)
          ScaleWatch.attach_all(model)
        end

        def onActivateModel(model)
          ScaleWatch.attach_all(model)
        end
      end
    end
  end
end
