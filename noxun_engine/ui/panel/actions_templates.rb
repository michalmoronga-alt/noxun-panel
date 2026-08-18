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

          # UI-B3 (Codex audit BLOCKER 2): PRISNY guard dokumentu. ID skriniek sa
          # naprie dokumentmi opakuju (kazdy model ma CAB-001), takze modal
          # otvoreny nad jednym dokumentom by po prepnuti ulozil skrinku z ineho.
          # Prazdny guid = okno bez dobehnuteho NX.init, nie „stary klient"
          # (rovnaka zasada ako handle_clear_selection).
          if data['model_guid'].to_s != model_guid(model)
            return set_status('Šablóna neuložená — panel patrí inému dokumentu.', true)
          end

          expected = data['cabinet_id'].to_s
          actual = Store.get(cab, 'cabinet_id').to_s
          if !expected.empty? && expected != actual
            return set_status('Výber sa medzitým zmenil — šablóna neuložená, skús znova.', true)
          end

          name = data['name'].to_s.strip
          return set_status('Prázdny názov — šablóna neuložená.', true) if name.empty?

          # H2 (D-76): model = zdroj ZMRAZENYCH definicii setov kovania.
          cab_cfg = Store.config(cab) || {}
          config = template_config_from(cab_cfg, model: model)
          hw_note = template_save_hardware_note(cab_cfg, config, model) # GH #133 P2
          type_note = apply_template_type!(config, data['type'])        # UI-B3 modal: Nazov + Typ
          unless TemplateStore.upsert(name, config)
            return set_status('Šablónu sa nepodarilo zapísať (disk/práva) — skús znova.', true)
          end

          push_templates                       # quick-pick v paneli
          TemplatesDialog.refresh_if_open      # Codex F3: zivy sync satelitu
          set_status("Šablóna \"#{name}\" uložená do knižnice.#{type_note}#{hw_note}")
        end

        # UI-B3: typ z mini-modalu „Uložiť ako šablónu". Typ je JEDINY udaj,
        # ktory sa v modale nastavuje nad ramec nazvu — riadi, pod ktorym typom
        # sa sablona ponuka pri vkladani (zoznam je typovo filtrovany).
        # Whitelist je TU (HTML nie je ochrana); chybajuca hodnota = typ skrinky
        # (spravanie ako doteraz). Rozdiel oproti skrinke sa POVIE nahlas —
        # ulozene rozmery a konstrukcia ostavaju z tejto skrinky, meni sa len
        # zaradenie sablony.
        def apply_template_type!(config, raw)
          want = raw.to_s.strip.downcase
          return '' unless %w[lower upper].include?(want)

          have = (config['type'] || 'lower').to_s
          config['type'] = want
          return '' if want == have

          " Uložená ako #{want == 'upper' ? 'HORNÁ' : 'DOLNÁ'} (rozmery a konštrukcia ostali z tejto skrinky)."
        end

      end
    end
  end
end
