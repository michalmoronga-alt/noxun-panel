# frozen_string_literal: true
# Noxun Engine — main. Requires, menu, toolbar, logger.
require 'sketchup.rb'
require 'json'

module Noxun
  module Engine
    PLUGIN_DIR = File.dirname(__FILE__)
    # VERSION definuje loader (noxun_engine.rb); tu len fallback pri samostatnom reloade.
    VERSION = '0.5.60' unless defined?(VERSION)

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
Sketchup.require 'noxun_engine/core/part_faces' # D-88: kontrakt hrana -> plocha kvadra (pred vsetkymi tvorcami deskriptorov)
Sketchup.require 'noxun_engine/core/json_file_store' # cache + bezpecny atomicky zapis JSON katalogov
Sketchup.require 'noxun_engine/core/materials'   # V0.3 materialovy katalog (pred abs_rules)
Sketchup.require 'noxun_engine/core/materials_catalog' # V0.5.1 split: CRUD/validacia/scan/patch/seed
Sketchup.require 'noxun_engine/core/materials_decor'    # V0.5.1 split: D-41 dekor = kluc skupiny + batch
Sketchup.require 'noxun_engine/core/materials_abs'      # V0.5.1 split: ABS podla dekoru (picker, remap)
Sketchup.require 'noxun_engine/core/materials_project'  # V0.5.1 split: projektove defaulty + usage
Sketchup.require 'noxun_engine/core/materials_migration' # 2A-2: dormantna migracia na SCHEMA 2 (standard 7.1)
Sketchup.require 'noxun_engine/core/materials_health'   # 2A-4a: stav katalogu (read-only rezim), obnova z .bak, rollback
Sketchup.require 'noxun_engine/core/demos/client'        # V0.6-B: async siet (allowlist, robots, throttle)
Sketchup.require 'noxun_engine/core/demos/sitemap_cache' # V0.6-B: cache produktovych URL (48k, refresh na pokyn)
Sketchup.require 'noxun_engine/core/demos/slug_matcher'  # V0.6-B: identita zaznamu -> produktova URL
Sketchup.require 'noxun_engine/core/demos/product_parser' # V0.6-B: HTML -> kod/ceny/parametre/rodina
Sketchup.require 'noxun_engine/core/demos/lookup'        # V0.6 B-2a: orchestrator lookupu (po materials — pouziva duplak?/identity_norm)
Sketchup.require 'noxun_engine/core/demos/name_search'   # V0.6 M-A: offline nazvove hladanie v sitemap cache
Sketchup.require 'noxun_engine/core/demos/image_cache'   # V0.6 M-A: lokalna cache obrazkov dekorov (BLOCKER 1 — ziadne remote img v CEF)
Sketchup.require 'noxun_engine/core/demos/family'        # V0.6 M-A: rodina dekoru zo stranky + orchestrator zalozenia
Sketchup.require 'noxun_engine/core/materials_demos_create' # V0.6 M-A: atomicke zalozenie skupiny z Demosu (1 lock, 1 zapis)
Sketchup.require 'noxun_engine/core/materials_replace_uni'  # V0.6 M-B2: „Nahradit UNI…" (scan+klasifikacia+odtlacok planu)
Sketchup.require 'noxun_engine/core/abs_rules'   # V0.3 ABS pravidla (pouziva Materials)
Sketchup.require 'noxun_engine/core/front_profiles' # D-90 uchytkove profily ciel (pred fronts/hardware_rules)
Sketchup.require 'noxun_engine/core/hardware_rules' # V0.4 pravidla kovania (pred construction)
Sketchup.require 'noxun_engine/core/hardware_catalog' # V0.6 C-1: katalog kovania (po materials/demos — pouziva slug, normalize_price, Demos.fetch)
Sketchup.require 'noxun_engine/core/hardware_sets' # V0.6 D1: sety kovania (po build_plan/hardware_catalog — GENERIC_TYPES, CATEGORIES; pred validation/ui)
Sketchup.require 'noxun_engine/modules/shelves'
Sketchup.require 'noxun_engine/modules/fronts'
Sketchup.require 'noxun_engine/core/zone_tree'
Sketchup.require 'noxun_engine/core/zones'
Sketchup.require 'noxun_engine/core/construction'
Sketchup.require 'noxun_engine/core/scale_observer'
Sketchup.require 'noxun_engine/core/placement'      # V0.4.7b umiestnovanie (top-level cabinet+board)
Sketchup.require 'noxun_engine/core/cabinet_builder'
Sketchup.require 'noxun_engine/core/board_builder' # V0.4.7 samostatna doska
Sketchup.require 'noxun_engine/core/templates'
Sketchup.require 'noxun_engine/core/bom'           # V0.5 A kusovnik/supisy zo snapshotov
Sketchup.require 'noxun_engine/core/usage_stats'   # D-25 merac pouzivania panela (lokalne pocitadla)
Sketchup.require 'noxun_engine/core/vepo_export'   # V0.5 C VEPO CSV export (prirezy z BOM)
Sketchup.require 'noxun_engine/core/sheet_estimate' # D-19 orientacny odhad platni
Sketchup.require 'noxun_engine/core/debug'         # read-only diagnostika stavu (bugcatch cez MCP)
Sketchup.require 'noxun_engine/core/validation'    # V0.5 D kontrolny semafor vyroby (RED/ORANGE)
Sketchup.require 'noxun_engine/core/edge_check'     # D-104 kontrola hran (po validation — zdiela jeho definicie UNI/nelepitelnych)
Sketchup.require 'noxun_engine/core/edge_overlay'   # D-104 Sketchup::Overlay + ModelObserver (SU 2023+, guardovane)
Sketchup.require 'noxun_engine/core/supplier_settings' # V0.6 E-a: sadzby/rezimy/standardne riadky rozpoctu (globál)
Sketchup.require 'noxun_engine/core/budget_store'  # V0.6 E-a: data rozpoctu v zakazke (po store + supplier_settings)
Sketchup.require 'noxun_engine/core/budget'        # V0.6 E-a: vypocet rozpoctu (po bom/sheet_estimate/budget_store)
Sketchup.require 'noxun_engine/core/xlsx_writer'   # V0.6 E-b: pravy .xlsx bez gemov + Luciin harok rozpoctu
Sketchup.require 'noxun_engine/core/cp_export'     # V0.6 E-b2: cenova ponuka (view nad rozpoctom) + zakaznicky xlsx
Sketchup.require 'noxun_engine/core/price_refresh' # V0.6 E-c: hromadne obnovenie cien z Demosu (po demos/lookup + hardware_catalog)
Sketchup.require 'noxun_engine/ui/production_dialog' # V0.5 B okno Vyroba
Sketchup.require 'noxun_engine/ui/panel'
Sketchup.require 'noxun_engine/ui/rules_dialog'     # V0.4 editor pravidiel kovania
Sketchup.require 'noxun_engine/ui/materials_dialog' # V0.4.5 D2 projektove predvolby materialov
Sketchup.require 'noxun_engine/ui/hardware_catalog_dialog' # V0.6 C-2: okno Katalog kovania
Sketchup.require 'noxun_engine/ui/supplier_settings_dialog' # V0.6 E-b: okno Nastavenia rozpoctu
Sketchup.require 'noxun_engine/ui/templates_dialog' # V0.4.5 D2 sprava sablon

module Noxun
  module Engine
    unless file_loaded?(__FILE__)
      # 2A-4b (audit O4 + F11): jednorazovy boot cutover katalogu materialov na
      # SCHEMA 2 — VLASTNY chraneny blok MIMO hlavneho begin/rescue inicializacie
      # (zlyhanie migracie NESMIE zhodit menu/toolbar/observer). Ziadny
      # UI.messagebox (O1) — vysledok ide do logu, pouzivatelsky stav ukazuje
      # okno Materialy (read-only banner / banner nepouzitelnych pasok).
      begin
        Materials.boot_cutover!
      rescue StandardError => e
        log_error(e, 'boot_cutover')
      end

      # V0.6 M-B1: jednorazove doplnenie UNI sady do existujuceho katalogu
      # (fresh install ju ma v seede). Vlastny chraneny blok — zlyhanie nesmie
      # zhodit boot; marker subor drzi jednorazovost.
      begin
        Materials.ensure_uni_records!
      rescue StandardError => e
        log_error(e, 'ensure_uni_records')
      end

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
        menu.add_item('Katalóg kovania') { HardwareCatalogDialog.show } # V0.6 C-2
        menu.add_item('Nastavenia rozpočtu') { SupplierSettingsDialog.show } # V0.6 E-b
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
