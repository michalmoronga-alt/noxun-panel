# frozen_string_literal: true
# Noxun Engine — V0.6 E-b: satelitne okno NASTAVENIA (sadzby rozpoctu).
#
# ============================ CO SA TU EDITUJE ============================
# GLOBALNE nastavenia aktivneho dodavatela (%APPDATA%\NOXUN\Engine\
# supplier_settings.json) — sadzby sluzieb, rezimove hodnoty (€/€€/€€€),
# standardne koncove riadky, prah veku cien a krok zaokruhlenia. Do zakazky sa
# NEMRAZIA (rozhodnutie Michal 31.7.: rozpocet je pohyblivy obraz cien) —
# vsetko per zakazka drzi BudgetStore na modeli, ten sa tu NEDOTYKA.
#
# ============================== GUARDY ===================================
# 1) BASELINE REVIZIA (vzor rules_dialog/materials): okno si pri otvoreni
#    zapamata `revision` aktivneho dodavatela a posiela ju spat pri ulozeni.
#    Ina revizia = medzitym to niekto zmenil -> zapis sa ODMIETNE a formular sa
#    nacita nanovo (nikdy tichy prepis cudzej zmeny).
# 2) VALIDACIA JE SERVEROVA — SupplierSettings.patch_active! je all-or-nothing
#    (validate-all pred zapisom); HTML `disabled`/`type=number` nie su ochrana.
# 3) Po uspesnom ulozeni sa OTVORENE okno Vyroba prepocita (refresh_if_open) —
#    sadzby su vstup rozpoctu, cisla by inak ostali stare.
require 'json'

module Noxun
  module Engine
    module SupplierSettingsDialog
      DLG_KEY = 'noxun_engine_supplier_settings'

      # Popisky a jednotky sadzieb sluzieb — poradie = poradie v okne (zhodne
      # s Budget::SERVICE_DEFS, aby sa nastavenie a rozpocet citali rovnako).
      RATE_LABELS = {
        'olep'           => ['Olepovanie ABS', '€/bm'],
        'porez'          => ['Porez platní', '€/platňa'],
        'duplaky'        => ['Lepenie duplákov', '€/ks'],
        'pd_opracovanie' => ['Opracovanie pracovnej dosky', '€ fix'],
        'montaz'         => ['Montáž', '€/m²']
      }.freeze

      class << self
        def show
          dlg = ensure_dialog
          if dlg.visible?
            dlg.bring_to_front
            push_state
          else
            dlg.show
          end
          dlg
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.show')
        end

        private

        def ensure_dialog
          return @dialog if @dialog

          @dialog = UI::HtmlDialog.new(
            dialog_title: 'Noxun Engine — Nastavenia rozpočtu',
            preferences_key: DLG_KEY,
            scrollable: true,
            resizable: true,
            width: 620,
            height: 620,
            min_width: 460,
            min_height: 360,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          @dialog.set_file(File.join(Engine.plugin_dir, 'ui', 'supplier_settings.html'))
          register_callbacks(@dialog) # pred show!
          @dialog.set_on_closed { @dialog = nil }
          @dialog
        end

        def register_callbacks(dlg)
          cb(dlg, 'ready')    { |_p| push_state }
          cb(dlg, 'save')     { |p| handle_save(p) }
          cb(dlg, 'reload')   { |_p| handle_reload }
          dlg.add_action_callback('js_error') do |_ctx, msg|
            begin
              Engine.log("JS(settings): #{msg}")
            rescue StandardError => e
              Engine.log_error(e, 'settings js_error')
            end
            next
          end
        end

        def cb(dlg, name)
          dlg.add_action_callback(name) do |_ctx, *args|
            begin
              yield(args.first)
            rescue StandardError => e
              Engine.log_error(e, "settings cb #{name}")
              set_status("Chyba: #{e.message}", true)
            end
            next
          end
        end

        # --- Ruby -> JS ------------------------------------------------------

        def push_state
          sup = SupplierSettings.active
          @baseline_revision = SupplierSettings.revision(sup)
          data = {
            version: Engine::VERSION,
            revision: @baseline_revision,
            supplier: sup,
            modes: SupplierSettings::MODES,
            mode_labels: SupplierSettings::MODE_LABELS,
            rate_keys: SupplierSettings::RATE_KEYS,
            rate_labels: RATE_LABELS,
            standard_rows: SupplierSettings.standard_rows(sup)
          }
          js("SS.init(#{data.to_json})")
        end

        def handle_reload
          SupplierSettings.reload!
          push_state
          set_status('Nastavenia načítané nanovo zo súboru.')
        end

        # Ulozenie: revizia -> patch (validate-all) -> refresh okna + Vyroby.
        def handle_save(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          current = SupplierSettings.revision(SupplierSettings.active)
          if data['revision'].to_s != current
            push_state
            return set_status('Nastavenia sa medzitým zmenili — formulár je načítaný nanovo. ' \
                              'Skontroluj hodnoty a ulož znova.', true)
          end
          patch = data['patch'].is_a?(Hash) ? data['patch'] : {}
          ok, errors = SupplierSettings.patch_active!(patch)
          # Pri chybe sa formular ZAMERNE NEnacitava nanovo — pouzivatel by
          # prisiel o vsetky rozpisane hodnoty a videl by len hlasku. Nic sa
          # nezapisalo (patch je all-or-nothing), takze staci chybu ukazat.
          return set_status("Neuložené: #{Array(errors).join(' · ')}", true) unless ok
          push_state
          # Sadzby su vstup rozpoctu — otvorene okno Vyroba musi ukazat nove cisla.
          ProductionDialog.refresh_if_open if defined?(ProductionDialog)
          set_status('Nastavenia uložené. Rozpočet v okne Výroba je prepočítaný.')
        end

        def set_status(msg, error = false)
          js("SS.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})")
        end

        def js(script)
          return unless @dialog && @dialog.visible?

          @dialog.execute_script(script)
        rescue StandardError => e
          Engine.log_error(e, 'SupplierSettingsDialog.js')
        end
      end
    end
  end
end
