# frozen_string_literal: true
# Noxun Engine - Panel: toggle ghost zon. Sprava sablon (save/delete/apply/merge)
# sa V0.4.5 D2 PRESUNULA do samostatneho okna TemplatesDialog (ui/templates_dialog.rb)
# — v paneli ostal len rychly vyber sablony vo vkladacej karte (form.js).
# Cast modulu Panel (reopen) - zdiela ivary cez class << self.
module Noxun
  module Engine
    module Panel
      class << self
        def handle_toggle_zones(val)
          model = Sketchup.active_model
          visible = truthy?(val)
          Zones.set_visible(model, visible)
          model.active_view.invalidate if model.active_view
          set_status(visible ? 'Ghost zony zapnute.' : 'Ghost zony vypnute.')
        end

        # D-14: ulozenie OZNACENEHO korpusu ako sablony priamo z panela (in-panel
        # modal). Serverove guardy — HTML/CSS nie je ochrana: identita korpusu
        # (Codex F2 — oneskoreny zapis po prekliknuti sa zahodi), neprazdny nazov,
        # upsert false = chyba zapisu (Codex F7 — ziadny falosny uspech).
        def handle_save_template_as(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus — šablóna sa ukladá z neho.', true) if cab.nil?

          expected = data['cabinet_id'].to_s
          actual = Store.get(cab, 'cabinet_id').to_s
          if !expected.empty? && expected != actual
            return set_status('Výber sa medzitým zmenil — šablóna neuložená, skús znova.', true)
          end

          name = data['name'].to_s.strip
          return set_status('Prázdny názov — šablóna neuložená.', true) if name.empty?

          config = template_config_from(Store.config(cab) || {})
          unless TemplateStore.upsert(name, config)
            return set_status('Šablónu sa nepodarilo zapísať (disk/práva) — skús znova.', true)
          end

          push_templates                       # quick-pick v paneli
          TemplatesDialog.refresh_if_open      # Codex F3: zivy sync satelitu
          set_status("Šablóna \"#{name}\" uložená do knižnice.")
        end

      end
    end
  end
end
