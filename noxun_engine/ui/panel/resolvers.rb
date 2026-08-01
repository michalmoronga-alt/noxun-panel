# frozen_string_literal: true
# Noxun Engine - Panel: hladanie v modeli (korpus, zona) + parsovanie a drobne helpery.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- resolvery -------------------------------------------------------
        # Najde NOXUN korpus vo vybere: priamo (kind=cabinet), alebo z dielca/zony cez cabinet_id.
        # D-34 (audit B4a): vyber moze pocas erase okna niest NEPLATNE entity —
        # citanie atributov zmazanej entity pada (TypeError), preto valid? filter.
        def find_cabinet(model)
          sel = model.selection.to_a.select(&:valid?)
          return nil if sel.empty?

          direct = sel.find { |e| Store.kind(e) == 'cabinet' }
          return direct if direct

          part = sel.find { |e| Store.noxun?(e) && Store.get(e, 'cabinet_id') }
          return nil unless part

          find_cabinet_by_id(model, Store.get(part, 'cabinet_id'))
        end

        def find_cabinet_by_id(model, cid)
          return nil if cid.nil?

          Ids.each_cabinet(model) do |inst|
            return inst if Store.get(inst, 'cabinet_id') == cid
          end
          nil
        end

        # Samostatna doska vo vybere (V0.4.7c). Korpus ma v Inspectore prednost —
        # volajuci najprv skusa find_cabinet; doska sa riesi az ked je nil.
        def find_board(model)
          model.selection.to_a.find { |e| e.valid? && Store.kind(e) == 'board' }
        end

        def find_board_by_id(model, bid)
          return nil if bid.nil?

          Ids.each_board(model) do |inst|
            return inst if Store.get(inst, 'id') == bid
          end
          nil
        end

        # Zona vo vybere (klik na ghost). Testovatelne aj priamo cez find_zone_in([entita]).
        def find_selected_zone(model)
          find_zone_in(model.selection.to_a)
        end

        def find_zone_in(entities)
          z = entities.find { |e| e.valid? && Store.kind(e) == 'zone' }
          return nil unless z

          cfg = Store.config(z) || {}
          { 'zone_id' => Store.get(z, 'id'), 'cabinet_id' => Store.get(z, 'cabinet_id'),
            'width' => cfg['width'], 'height' => cfg['height'], 'depth' => cfg['depth'],
            'shelves' => cfg['shelves'] }
        end

        def parse(payload)
          return {} if payload.nil? || payload.to_s.strip.empty?

          v = JSON.parse(payload)
          v.is_a?(Hash) ? v : { 'value' => v }
        rescue JSON::ParserError
          { 'value' => payload }
        end

        def zone_path(zid)
          m = zid.to_s.match(/-Z([\d.]+)$/)
          return [1] unless m

          m[1].split('.').map(&:to_i)
        end

        def cabinet_id_from_zone(zid)
          m = zid.to_s.match(/^(CAB-\d+)-Z/)
          m ? m[1] : nil
        end

        def short_zone(zid)
          m = zid.to_s.match(/-Z([\d.]+)$/)
          m ? "Z#{m[1]}" : zid
        end

        def belongs?(zid, cab)
          return false if zid.nil? || cab.nil?

          cabinet_id_from_zone(zid) == Store.get(cab, 'cabinet_id')
        end

        def select_only(model, inst)
          suspend_selection_sync do
            model.selection.clear
            model.selection.add(inst)
          end
        end

        def part_count(inst)
          return 0 unless inst && inst.respond_to?(:definition)

          inst.definition.entities.grep(Sketchup::ComponentInstance).count do |e|
            Store.kind(e) == 'part'
          end
        end

        def truthy?(val)
          %w[true 1 yes].include?(val.to_s.downcase)
        end

        # --- D-49: duplak automaticky — virtualna hodnota selectu -------------
        # "duplak2:<source_id>" (resp. duplak3:) -> realne material_id. Bezi na
        # ZACIATKU handlerov (audit F4) — PRED ABS kontrolami, hrubkovymi guardmi
        # aj efektivnymi materialmi; poskodena/zastarana hodnota = ciste
        # odmietnutie (volajuci spravi UI resync), ziadny ciastocny zapis.
        # Katalogovy zapis bezi MIMO modeloveho undo (vedomy kontrakt ensure_*
        # ciest — Spat vrati model, globalna polozka ostava; hlaska to hovori).
        # Vrati [real_id | povodna hodnota, note | nil] alebo [nil, chyba].
        def resolve_virtual_material(value)
          m = value.to_s.match(/\Aduplak([23]):(.+)\z/)
          return [value, nil] unless m
          status, rec = Materials.ensure_duplak_for(m[2], m[1].to_i)
          case status
          when :ok
            # F5: novy zaznam musi byt v selectoch SKOR, nez sa posle payload
            # objektu — inak sa select po rebuilde zobrazi prazdny.
            push_materials
            [rec['material_id'],
             " Duplák #{fmt_mm(rec['thickness'])} mm pripravený v katalógu (globálna položka — krok Späť ju neodstráni)."]
          when :exists_regular
            # B2: identitu drzi KUPOVANA doska — pouzije sa ona, nie duplak.
            push_materials
            if rec
              [rec['material_id'], " Hrúbku #{fmt_mm(rec['thickness'])} mm už drží kupovaná doska — použila sa tá."]
            else
              [nil, 'Duplák sa nedá pripraviť — obnov okno.']
            end
          when :catalog_read_only
            [nil, 'Katalóg je len na čítanie — duplák sa teraz nedá vytvoriť.']
          else
            [nil, rec.is_a?(String) ? rec : 'Duplák sa nedá pripraviť — obnov okno.']
          end
        end

      end
    end
  end
end
