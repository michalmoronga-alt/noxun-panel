# frozen_string_literal: true
# Noxun Engine — main. Requires, menu, toolbar, logger.
require 'sketchup.rb'
require 'json'

module Noxun
  module Engine
    PLUGIN_DIR = File.dirname(__FILE__)
    # VERSION definuje loader (noxun_engine.rb); tu len fallback pri samostatnom reloade.
    VERSION = '0.4.7' unless defined?(VERSION)

    def self.plugin_dir
      PLUGIN_DIR
    end

    # --- Logger --------------------------------------------------------------
    # Jednotny prefix [NOXUN::Engine]; ziadne hole puts v produkcnych cestach.
    def self.log(msg)
      puts "[NOXUN::Engine] #{msg}"
    end

    def self.log_error(e, context = nil)
      log("#{context ? "#{context}: " : ''}#{e.class}: #{e.message}")
      bt = e.respond_to?(:backtrace) ? e.backtrace : nil
      bt.first(4).each { |line| puts "  #{line}" } if bt
      nil
    end
  end
end

# Vnutorne subory — Sketchup.require (funguje aj so sifrovanymi .rbe).
# Poradie: pure moduly (shelves/fronts/zone_tree) pred construction; templates po builderi.
Sketchup.require 'noxun_engine/core/units'
Sketchup.require 'noxun_engine/core/ids'
Sketchup.require 'noxun_engine/core/store'
Sketchup.require 'noxun_engine/core/part_keys' # stabilna identita dielcov pre override a buduce vystupy
Sketchup.require 'noxun_engine/core/build_plan' # zavazny kontrakt planu (validator, warnings, hardware)
Sketchup.require 'noxun_engine/core/json_file_store' # cache + bezpecny atomicky zapis JSON katalogov
Sketchup.require 'noxun_engine/core/materials'   # V0.3 materialovy katalog (pred abs_rules)
Sketchup.require 'noxun_engine/core/abs_rules'   # V0.3 ABS pravidla (pouziva Materials)
Sketchup.require 'noxun_engine/core/hardware_rules' # V0.4 pravidla kovania (pred construction)
Sketchup.require 'noxun_engine/modules/shelves'
Sketchup.require 'noxun_engine/modules/fronts'
Sketchup.require 'noxun_engine/core/zone_tree'
Sketchup.require 'noxun_engine/core/zones'
Sketchup.require 'noxun_engine/core/construction'
Sketchup.require 'noxun_engine/core/scale_observer'
Sketchup.require 'noxun_engine/core/cabinet_builder'
Sketchup.require 'noxun_engine/core/board_builder' # V0.4.7 samostatna doska (cista cast)
Sketchup.require 'noxun_engine/core/templates'
Sketchup.require 'noxun_engine/ui/panel'
Sketchup.require 'noxun_engine/ui/rules_dialog'     # V0.4 editor pravidiel kovania
Sketchup.require 'noxun_engine/ui/materials_dialog' # V0.4.5 D2 projektove predvolby materialov
Sketchup.require 'noxun_engine/ui/templates_dialog' # V0.4.5 D2 sprava sablon

module Noxun
  module Engine
    unless file_loaded?(__FILE__)
      begin
        cmd = UI::Command.new('Noxun Engine — Panel') { Panel.show }
        cmd.tooltip = 'Noxun Engine — Panel'
        cmd.status_bar_text = 'Otvori panel na vkladanie a upravu parametrickych korpusov.'
        icon = File.join(PLUGIN_DIR, 'icons', 'panel.svg')
        if File.exist?(icon)
          cmd.small_icon = icon
          cmd.large_icon = icon
        end

        toolbar = UI::Toolbar.new('Noxun Engine')
        toolbar.add_item(cmd)
        toolbar.restore

        menu = UI.menu('Extensions').add_submenu('Noxun Engine')
        menu.add_item('Panel') { Panel.show }
        menu.add_item('Pravidlá kovania') { RulesDialog.show }
        menu.add_item('Materiály projektu') { MaterialsDialog.show }
        menu.add_item('Šablóny') { TemplatesDialog.show }

        # Scale observer — attach na existujuce korpusy + AppObserver pre buduce modely.
        ScaleWatch.install

        log("nacitany v#{VERSION}")
      rescue => e
        log_error(e, 'main.rb init')
      end
      file_loaded(__FILE__)
    end
  end
end
