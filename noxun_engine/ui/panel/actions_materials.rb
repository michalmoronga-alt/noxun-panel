# frozen_string_literal: true
# Noxun Engine - Panel: materialy OZNACENEJ skrinky (korpusovy override dedenia).
# Projektove predvolby sa V0.4.5 D2 PRESUNULI do okna MaterialsDialog
# (ui/materials_dialog.rb) — panel uz projektove selecty nema.
# Cast modulu Panel (reopen) - zdiela ivary cez class << self.
module Noxun
  module Engine
    module Panel
      class << self
        # Korpusovy material (override projektu). which: body/front/back; prazdna hodnota = dedi.
        # D-41 PR C: pred rebuildom sa preladia RUCNE ABS overridy dielcov, ktore boli
        # zladene so starym efektivnym dekorom (centralny remap — audit FIX 5).
        # D-45: material TELA riadi hrubku korpusu (filozofia dosky) — hrubka sa
        # prevezme z katalogu a vsetko ide v JEDNOM rebuilde (1 undo krok, audit N11).
        def handle_set_cabinet_material(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?
          data = parse(payload)
          # D-45 (audit F9): oneskoreny callback po prekliknuti nesmie zasiahnut iny
          # korpus — echo s cudzim cabinet_id sa TICHO zahodi (vzor actions_parts).
          return if stale_cabinet_echo?(cab, data, 'material korpusu')
          key = { 'body' => 'material_id', 'front' => 'front_material_id', 'back' => 'back_material_id' }[data['which'].to_s]
          return set_status('Neznamy material korpusu.', true) unless key
          value = present_str(data['value'])
          params = existing_params(cab)
          # D-49 (audit F4 + GH #116 P2): virtualna polozka — najprv PROBE
          # hrubkovych guardov BEZ zapisu (blokovana zmena nesmie nechat
          # nepouzity globalny duplak v katalogu), az potom ensure+rozriesenie.
          duplak_note = ''
          if value && (probe = virtual_duplak_probe(value))
            return set_status(probe['error'], true) if probe['error']
            if key == 'material_id'
              test = JsonFileStore.deep_copy(params)
              state, names = CabinetBuilder.adopt_thickness(test, probe)
              if state == :blocked
                set_status("Duplák #{fmt_mm(probe['thickness'])} mm sa nedá použiť — dielce s vlastným materiálom inej hrúbky: #{Array(names).join(', ')}. Katalóg sa nezmenil.", true)
                return push_selected(model)
              elsif state == :range
                set_status("Hrúbka dupláku #{fmt_mm(probe['thickness'])} mm je mimo rozsahu korpusu. Katalóg sa nezmenil.", true)
                return push_selected(model)
              end
            end
          end
          if value
            value, dnote = resolve_virtual_material(value)
            unless value
              set_status(dnote, true)
              return push_selected(model) # select spat na ulozeny material
            end
            duplak_note = dnote.to_s
          end
          old_eff = effective_materials(model, params)
          params[key] = value
          new_eff = effective_materials(model, params)
          # D-45 (audit B5): prazdna hodnota = zrusenie override = dedenie z projektu,
          # preto hrubku berieme z EFEKTIVNEHO materialu, nie z odoslanej hodnoty.
          th_note = ''
          if key == 'material_id'
            sheet = Materials.sheet(new_eff['body'])
            adopt = sheet && adopt_body_thickness!(params, sheet)
            if adopt && adopt[:error]
              set_status(adopt[:error], true)
              push_selected(model) # UI resync — select sa vrati na ulozeny material
              return
            end
            th_note = adopt ? adopt[:note] : ''
          end
          remap = CabinetBuilder.remap_part_edge_overrides!(params, old_eff, new_eff)
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: material korpusu')
            reselect(model, cab)
          end
          set_status("Materiál korpusu #{value ? 'nastavený' : 'dedí z projektu'}.#{th_note}#{remap_note(remap)}#{duplak_note}")
          push_selected(model)
        end

        # Efektivne materialy korpusu po dedeni projekt->korpus (vstup pre remap).
        # Jadro zije v CabinetBuilder (JEDEN zdroj pravdy s build_into) — tu ostava
        # nazov, ktory volaju dialogy.
        def effective_materials(model, params)
          CabinetBuilder.effective_materials(model, params)
        end

        # Kratke slovenske hlasenie o preladeni ABS (prazdne ak sa nic nemenilo).
        def remap_note(remap)
          return '' unless remap.is_a?(Hash) && remap['changed'].to_i.positive?
          note = " ABS hrany prevedené na nový dekor (#{remap['changed']}× dielec)."
          note += " Bez náhrady: #{remap['lost'].join(', ')}." unless remap['lost'].empty?
          note
        end

        # UI-B1 (audit A2): ABS kontrola hran z raily Inspectora. Prepnutie robi
        # ZDIELANA Engine.toggle_edge_check — presne tá istá cesta ako toolbar
        # (UI-02) aj okno Vyroba (D-105), takze sa spravanie nemoze rozist a
        # novy stav dostanu vsetky otvorene okna naraz.
        # ZIADNY zapis do modelu, ziadna operacia, ziadny undo krok — EdgeCheck
        # je overlay NAD modelom (lekcia D-103).
        # IDENTITY GUARD DOKUMENTU (Codex #168 P2, 2. kolo): callback HtmlDialogu
        # je asynchronny — ak pouzivatel medzitym prepol dokument, prepinac by
        # zapol overlay v CUDZOM modeli. Rovnaky guard ma D-105 v okne Vyroba.
        def handle_edge_toggle(payload = nil)
          model = Sketchup.active_model
          unless defined?(EdgeCheck) && EdgeCheck.available?(model)
            push_edge_check
            return set_status('Zvýraznenie hrán vyžaduje SketchUp 2023 alebo novší.', true)
          end

          want = payload ? parse(payload)['model_guid'].to_s : ''
          unless want.empty? || want == model_guid(model)
            push_edge_check
            return set_status('Model sa medzitým prepol — stav obnovený, klikni znova.', true)
          end

          state = Engine.toggle_edge_check(model)
          set_status(edge_toggle_status(state))
        end

        # Kratke potvrdenie do statusu panela. Podrobne nastavenie stavov
        # (chyba / mimo pravidla / olepene) zostava v okne Vyroba — rail je len
        # prepinac (3-stavove nastavenie pride neskor).
        def edge_toggle_status(state)
          st = state.is_a?(Hash) ? state : {}
          return 'Zvýraznenie hrán vypnuté — v modeli nič neostalo.' unless st['active']

          counts = st['counts'].is_a?(Hash) ? st['counts'] : {}
          "Zvýraznenie hrán zapnuté — #{counts['missing'].to_i} chýba podľa pravidla " \
            "(nastavenie stavov je v okne Výroba → Kontrola)."
        end

      end
    end
  end
end
