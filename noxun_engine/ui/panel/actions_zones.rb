# frozen_string_literal: true
# Noxun Engine - Panel: akcie zon (split, shelves, clean, field, select + apply_zone_mod).
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- akcie: zony -----------------------------------------------------
        def handle_split_zone(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac zonu (klik na ghost alebo v strome).', true) if zid.empty?
          axis = data['axis']; count = data['count'].to_i
          apply_zone_mod(zid) { |tree, path| ZoneTree.set_split!(tree, path, axis, count) }
          set_status("Zona #{short_zone(zid)} rozdelena #{axis == 'h' ? 'vodorovne' : 'zvisle'} na #{count}.")
        end

        def handle_set_zone_shelves(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac zonu.', true) if zid.empty?
          n = data['count'].to_i
          apply_zone_mod(zid) { |tree, path| ZoneTree.set_shelves!(tree, path, n) }
          set_status("Zona #{short_zone(zid)}: #{n} polic.")
        end

        def handle_clean_zone(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac zonu.', true) if zid.empty?
          apply_zone_mod(zid) { |tree, path| ZoneTree.clear_zone!(tree, path) }
          set_status("Zona #{short_zone(zid)} vycistena.")
        end

        # V0.2c: nastav presny rozmer pola v delenej zone + zamok (split lock). zone_id = RODICOVSKA
        # (delena) zona; index = poradie pola (0..count-1); size mm (prazdne = auto), locked bool.
        # fix #5: ak UI posle kompletny 'cuts' layout (rozmery vsetkych poli), ulozime ho naraz —
        # zadany rozmer bez locku sa tak NEstrati (proporcny prepocet az pri resize korpusu).
        def handle_set_zone_field(payload)
          data = parse(payload)
          zid = data['zone_id'].to_s
          return set_status('Najprv oznac delenu zonu.', true) if zid.empty?
          index = data['index'].to_i
          size = data['size']
          locked = truthy?(data['locked'])
          cuts = data['cuts']
          if cuts.is_a?(Array)
            apply_zone_mod(zid) { |tree, path| ZoneTree.set_field_cuts!(tree, path, cuts) }
          else
            apply_zone_mod(zid) { |tree, path| ZoneTree.set_field!(tree, path, index, size, locked) }
          end
          set_status("Pole #{index + 1}: #{size.to_s.strip.empty? ? 'auto' : "#{size.to_f.round} mm"}#{locked ? ' 🔒' : ''} — prestavané ✓.")
        end

        # V0.2c obojsmerna sync: klik na zonu v 2D nahlade -> zvyrazni jej ghost v modeli.
        def handle_select_zone(payload)
          model = Sketchup.active_model
          zid = parse(payload)['zone_id'].to_s
          @active_zone_id = zid.empty? ? nil : zid
          return if zid.empty?
          cid = cabinet_id_from_zone(zid)
          sub = Zones.find_zone_group(model, cid, zid)
          if sub && sub.valid?
            # Len zvyraznenie ghostu v modeli — panel uz o aktivnej zone vie (poslal ju), preto
            # potlacime observer, nech clear/add nevynuluje selectedCabId ani aktivnu zonu.
            suspend_selection_sync do
              model.selection.clear
              model.selection.add(sub)
            end
          end
        rescue StandardError => e
          Engine.log_error(e, 'handle_select_zone')
        end

        # Spolocny postup: nacitaj korpus zony, uprav strom, rebuild, oznac korpus, pushni.
        def apply_zone_mod(zone_id)
          model = Sketchup.active_model
          cid = cabinet_id_from_zone(zone_id)
          cab = find_cabinet_by_id(model, cid)
          raise 'Korpus zony sa nenasiel.' if cab.nil?

          params = existing_params(cab)
          tree = ZoneTree.sanitize(params['zone_tree'] || ZoneTree.default_tree(0))
          path = zone_path(zone_id)
          yield(tree, path)
          params['zone_tree'] = tree
          # Cela mutacia je NASA (rebuild + reselect). Observer potlacime, aby medzikroky
          # (clear/add korpusu, erase klik-nuteho ghostu) neposlali NX.clearSelected() a nevynulovali
          # selectedCabId v paneli. Aktivnu zonu drzime cez rebuild -> panel sa jej po resyncu drzi tiez.
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params)
            @active_zone_id = zone_id
            reselect(model, cab) # klik-nuty ghost je po rebuilde zmazany -> vyber korpus nanovo
          end
          push_selected(model) # PRESNE jeden resync panela (loadSelected s aktivnou zonou)
          cab
        end

      end
    end
  end
end
