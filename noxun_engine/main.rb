# frozen_string_literal: true
# Noxun Engine — main. Requires, menu, toolbar, logger.
require 'sketchup.rb'
require 'json'

module Noxun
  module Engine
    PLUGIN_DIR = File.dirname(__FILE__)
    # VERSION definuje loader (noxun_engine.rb); tu len fallback pri samostatnom reloade.
    VERSION = '0.7.2' unless defined?(VERSION)

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

    # --- D-77: okno sa nesmie otvorit odseknute -------------------------------
    # HtmlDialog si pamata poslednu velkost per `preferences_key`; `width`/
    # `height` v konstruktore plati LEN pri prvom otvoreni a `min_width`/
    # `min_height` chrania iba rucne zmensovanie. Ked teda okno raz ostalo male
    # (starsia verzia pluginu, omylom stiahnuty roh), otvara sa odseknute donekonecna.
    # Preto kazde okno po nacitani HTML ohlasi svoj viewport (ui/js/win_fit.js) a
    # tento callback ho cez `set_size` dorovna. JS je len merac — rozhodnutie
    # „rozumny rozmer" ostava tu: hodnoty mimo rozsahu sa zahodia.
    DIALOG_FIT_MIN_PX = 240   # mensie okno nema zmysel (a nie je to nas obsah)
    DIALOG_FIT_MAX_PX = 2600  # strop proti nezmyslu z JS (4K plocha + rezerva)

    # Registruje SPOLOCNE boot callbacky okna (`nx_fit` + UI-01 `nx_theme`).
    # Volat v register_callbacks — teda PRED show (kontrakt HtmlDialog,
    # docs/SKETCHUP_PRAVIDLA.md). Meno ostava historicke (D-77), aby sa
    # nemenilo 7 volani ani odkazy v dokumentacii.
    def self.register_dialog_fit(dlg, tag)
      register_dialog_theme(dlg, tag)
      dlg.add_action_callback('nx_fit') do |_ctx, w, h|
        begin
          tw = w.to_i
          th = h.to_i
          if tw.between?(DIALOG_FIT_MIN_PX, DIALOG_FIT_MAX_PX) &&
             th.between?(DIALOG_FIT_MIN_PX, DIALOG_FIT_MAX_PX)
            dlg.set_size(tw, th)
            log("#{tag}: okno dorovnane na #{tw}x#{th} px (D-77)")
          end
        rescue StandardError => e
          log_error(e, "#{tag} nx_fit")
        end
        next
      end
    end

    # --- UI-01: tema panela (NOXUN / Lucia) ----------------------------------
    # Tema je vec POCITACA, nie zakazky — zije v %APPDATA%\NOXUN\Engine\
    # ui_theme.json (vzor prepinacov EdgeCheck), NIKDY v .skp: Michal a Lucia
    # otvaraju tie iste zakazky a farba panela nesmie cestovat s modelom.
    # Tema prepina VYHRADNE vyberovu rodinu tokenov (--nx-select*, --nx-part-*);
    # vyznamove farby (danger/warn/ok/ABS/edge/semafor) sa nou NIKDY nemenia
    # (rozhodnutie O4, 15.8.2026 — docs/UI_DIZAJN.md sekcia Temy).
    # Konkretne hodnoty tokenov drzi JS (ui/js/win_fit.js) — Ruby posiela LEN
    # meno temy, aby paleta zila na jednom mieste s CSS.
    UI_THEMES = %w[noxun lucia].freeze
    UI_THEME_DEFAULT = 'noxun'
    UI_THEME_FILE = 'ui_theme.json'
    UI_THEME_STD = 1 # verzia formatu suboru (buduce migracie)

    def self.ui_theme_dir
      return Materials.dir if defined?(Materials) && Materials.respond_to?(:dir)

      File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
    end

    def self.ui_theme_path
      File.join(ui_theme_dir, UI_THEME_FILE)
    end

    # Neznama/prazdna hodnota = zakladna tema. Autorita whitelistu je TU
    # (nie v HTML) — presne ako pri EdgeCheck.set_option.
    def self.normalize_ui_theme(value)
      v = value.to_s.strip.downcase
      UI_THEMES.include?(v) ? v : UI_THEME_DEFAULT
    end

    # Ulozena tema. Chybajuci ani poskodeny subor NIKDY nezhodi otvaranie okna
    # — vrati sa zakladna tema.
    def self.get_ui_theme
      raw = JsonFileStore.available?(ui_theme_path) ? JsonFileStore.read(ui_theme_path) : nil
      normalize_ui_theme(raw.is_a?(Hash) ? raw['theme'] : nil)
    rescue StandardError => e
      log_error(e, 'Engine.get_ui_theme')
      UI_THEME_DEFAULT
    end

    # Zapis temy (UI prepinac pride v davke UI-B3; zatial len Ruby strana).
    # Neznama hodnota sa NEZAPISE — ulozi sa normalizovana. Zapisuje
    # JsonFileStore (atomicky + .bak).
    def self.set_ui_theme(value)
      theme = normalize_ui_theme(value)
      JsonFileStore.write(ui_theme_path, 'std' => UI_THEME_STD, 'theme' => theme)
      theme
    rescue StandardError => e
      log_error(e, 'Engine.set_ui_theme')
      UI_THEME_DEFAULT
    end

    # Registruje callback `nx_theme`: okno si po nacitani HTML vypyta temu
    # (ui/js/win_fit.js) a Ruby ju posle spat do JS. Rovnaky smer ako nx_fit —
    # `execute_script` pred `show` nefunguje, preto si okno pyta samo.
    def self.register_dialog_theme(dlg, tag)
      dlg.add_action_callback('nx_theme') do |_ctx, _payload|
        begin
          theme = get_ui_theme
          dlg.execute_script("if (window.nxThemeApply) nxThemeApply(#{theme.to_json});")
        rescue StandardError => e
          log_error(e, "#{tag} nx_theme")
        end
        next
      end
    end

    # --- UI-02: SketchUp toolbar ---------------------------------------------
    # Styri tlacidla podla kontraktu UI 2.0 (N4): logo (Inspector) · Studio ·
    # ABS kontrola hran (prepinac) · Vlozit skrinku. Toolbar NIE je novy modul —
    # zije v main.rb ako menu, s ktorym zdiela kazdy `UI::Command`.
    #
    # Zelezne pravidlo (lekcia D-103/D-105): z toolbaru sa do MODELU NEZAPISUJE.
    # Tlacidla len otvaraju okna a prepinaju zobrazenie — ziadny
    # `start_operation`, ziadny dedup, ziadna geometria.
    TOOLBAR_NAME = 'Noxun Engine'
    TOOLBAR_ICON_DIR = File.join(PLUGIN_DIR, 'ui', 'icons')

    # Ikona toolbaru: jedno SVG na oba rozmery (SketchUp na Windows si SVG
    # prepocita sam). Chybajuci subor tlacidlo nezhodi — ostane bez ikony.
    def self.toolbar_icon(cmd, file)
      path = File.join(TOOLBAR_ICON_DIR, file)
      return unless File.exist?(path)

      cmd.small_icon = path
      cmd.large_icon = path
    end

    # Validation proc bezi pri KAZDOM prekresleni UI — musi byt lacny a nesmie
    # nikdy vyhodit vynimku (zlyhanie by SketchUp opakoval donekonecna).
    def self.toolbar_state(&block)
      block.call ? MF_CHECKED : MF_UNCHECKED
    rescue StandardError
      MF_UNCHECKED
    end

    # Guard proti dvojitej registracii: pri reloade pluginu (`load main.rb`)
    # by inak pribudol dalsi rad rovnakych tlacidiel. Referenciu drzime aj
    # kvoli GC (rovnaky dovod ako pri HtmlDialogu).
    def self.install_toolbar
      return @toolbar if @toolbar

      tb = UI::Toolbar.new(TOOLBAR_NAME)

      cmd_panel = UI::Command.new('Inspector') { Panel.dialog_alive? ? Panel.hide : Panel.show }
      cmd_panel.tooltip = 'Inspector — panel Noxun Engine (znova zavrie)'
      cmd_panel.status_bar_text = 'Otvori alebo zavrie panel na vkladanie a upravu korpusov.'
      cmd_panel.set_validation_proc { toolbar_state { Panel.dialog_alive? } }
      toolbar_icon(cmd_panel, 'noxun_logo.svg')
      tb.add_item(cmd_panel)

      cmd_studio = UI::Command.new('Štúdio') { ProductionDialog.show }
      cmd_studio.tooltip = 'Štúdio — zatiaľ otvára okno Výroba (plné Štúdio príde v ďalšej fáze)'
      cmd_studio.status_bar_text = 'Kusovník, kontrola, rozpočet a výstupy zákazky.'
      toolbar_icon(cmd_studio, 'noxun_studio.svg')
      tb.add_item(cmd_studio)

      cmd_abs = UI::Command.new('ABS kontrola hrán') do
        next unless defined?(EdgeCheck)

        state = EdgeCheck.toggle(Sketchup.active_model)
        # D-105: okno Vyroba ma vlastne ovladanie hran (split tlacidlo so stavmi
        # a poctami). Prepnutie z toolbaru mu preto musi poslat NOVY stav —
        # inak by okno ostalo na starom (cesta ProductionDialog#do_edge_check
        # posiela push_edge_check rovnako). Defenzivne: pri zavretom okne sa
        # push ticho zahodi (`js` ma vlastny guard aj rescue).
        ProductionDialog.push_edge_check(state) if defined?(ProductionDialog)
      end
      cmd_abs.tooltip = 'ABS kontrola hrán — zvýrazní olep v modeli (prepínač)'
      cmd_abs.status_bar_text = 'Zapne/vypne farebné zvýraznenie olepu hrán. Nastavenie je v okne Výroba → Kontrola.'
      cmd_abs.set_validation_proc do
        if !defined?(EdgeCheck) || !EdgeCheck.available?
          MF_GRAYED
        else
          toolbar_state { EdgeCheck.active? }
        end
      end
      toolbar_icon(cmd_abs, 'noxun_abs.svg')
      tb.add_item(cmd_abs)

      cmd_insert = UI::Command.new('Vložiť skrinku') { Panel.show_insert }
      cmd_insert.tooltip = 'Vložiť skrinku — otvorí panel vo vkladacom režime'
      cmd_insert.status_bar_text = 'Otvori panel s vkladacou kartou (vyber v modeli sa zrusi).'
      toolbar_icon(cmd_insert, 'noxun_insert.svg')
      tb.add_item(cmd_insert)

      tb.restore
      @toolbar = tb
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
        install_toolbar # UI-02: logo · Studio · ABS kontrola · Vlozit

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
