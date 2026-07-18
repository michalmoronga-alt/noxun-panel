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

      end
    end
  end
end
