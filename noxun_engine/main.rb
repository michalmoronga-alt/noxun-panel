# frozen_string_literal: true
# Noxun Engine — main. Requires, menu, toolbar, logger.
require 'sketchup.rb'
require 'json'

module Noxun
  module Engine
    PLUGIN_DIR = File.dirname(__FILE__)
    # VERSION definuje loader (noxun_engine.rb); tu len fallback pri samostatnom reloade.
    VERSION = '0.9.7' unless defined?(VERSION)

    def self.plugin_dir
      PLUGIN_DIR
    end

    # --- Logger --------------------------------------------------------------
    # Jednotny prefix [NOXUN::Engine]; ziadne hole puts v produkcnych cestach.
    def self.log(msg)
      puts "[NOXUN::Engine] #{msg}"
    end

    # `Engine.on_document_replaced` (vymena dokumentu = jedna udalost s jednym
    # zoznamom cleanupov) zije v `core/doc_key.rb` — tam, kde zije aj identita
    # dokumentu, a hlavne tam, odkial ho vie spustit headless sada (tento
    # subor je SketchUp loader, testy ho nenacitavaju).

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

    # Zapis temy. Neznama hodnota sa NEZAPISE — ulozi sa normalizovana.
    # Zapisuje JsonFileStore (atomicky + .bak).
    # Codex audit FIX 6: zlyhanie zapisu vracia NIL — volajuci to musi povedat
    # nahlas (tichy fallback by ohlasil uspech, ktory sa nestal).
    def self.set_ui_theme(value)
      theme = normalize_ui_theme(value)
      JsonFileStore.write(ui_theme_path, 'std' => UI_THEME_STD, 'theme' => theme)
      theme
    rescue StandardError => e
      log_error(e, 'Engine.set_ui_theme')
      nil
    end

    # UI-B3: prepnutie temy Z UI (koliesko Inspectora). Ulozi hodnotu a HNED ju
    # nasadi VSETKYM otvorenym oknam — inak by panel zmenil farbu a satelity
    # ostali na starej az do svojho dalsieho otvorenia.
    # Vracia ulozenu temu, alebo NIL ked sa zapis nepodaril; rozposiela sa vzdy
    # to, co NAOZAJ plati (pri zlyhani teda povodna tema — okna nikdy neukazuju
    # farbu, ktora nie je zapisana).
    def self.apply_ui_theme(value)
      theme = set_ui_theme(value)
      broadcast_ui_theme(theme || get_ui_theme)
      theme
    end

    # Zoznam ZIVYCH okien, ktore vedia temu nasadit. Plni ho
    # `register_dialog_theme` (teda kazde okno cez `register_dialog_fit`).
    def self.theme_dialogs
      @theme_dialogs ||= []
    end

    # Codex audit FIX 7: zavrete okno sa zo zoznamu VYHODI — referencia na mrtvy
    # dialog (aj s jeho callback closure) sa nesmie drzat. Cisti sa pri KAZDEJ
    # registracii aj pri kazdom rozoslani, takze opakovane otvaranie a zatvaranie
    # okien zoznam nenafukuje.
    def self.prune_theme_dialogs
      theme_dialogs.select! do |dlg|
        begin
          dlg.visible?
        rescue StandardError
          false
        end
      end
      theme_dialogs
    end

    def self.broadcast_ui_theme(theme)
      script = "if (window.nxThemeApply) nxThemeApply(#{theme.to_json});"
      prune_theme_dialogs.each do |dlg|
        begin
          dlg.execute_script(script)
        rescue StandardError
          nil # okno prave zaniklo — vypadne pri najblizsom cisteni
        end
      end
      theme
    rescue StandardError => e
      log_error(e, 'Engine.broadcast_ui_theme')
      theme
    end

    # Prihlasi okno na ZIVE prepnutie temy. Volaju to DVE miesta: registracia
    # callbackov (pred `show`) a samotny `nx_theme` po nacitani HTML — druhe
    # miesto je zamerne: medzi registraciou a zobrazenim okno este `visible?`
    # nie je, takze by ho cistenie mohlo vyhodit.
    def self.track_theme_dialog(dlg)
      theme_dialogs << dlg unless theme_dialogs.include?(dlg)
      dlg
    end

    # Registruje callback `nx_theme`: okno si po nacitani HTML vypyta temu
    # (ui/js/win_fit.js) a Ruby ju posle spat do JS. Rovnaky smer ako nx_fit —
    # `execute_script` pred `show` nefunguje, preto si okno pyta samo.
    # Okno sa zaroven zaradi medzi prijemcov ZIVEHO prepnutia temy (UI-B3).
    def self.register_dialog_theme(dlg, tag)
      prune_theme_dialogs # najprv von so zavretymi, az POTOM pridaj nove okno
      theme_dialogs.delete(dlg) # anti-double pri opatovnej registracii toho isteho okna
      track_theme_dialog(dlg)
      dlg.add_action_callback('nx_theme') do |_ctx, _payload|
        begin
          track_theme_dialog(dlg) # okno je nacitane a zive — nech dostane aj buduce prepnutia
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

    # --- UI-B1 (audit A2): zdielane prepnutie ABS kontroly hran ---------------
    # JEDINE miesto, kde sa zvyraznenie olepu prepina. Volaju ho VSETCI klienti —
    # toolbar (UI-02), rail Inspectora (UI-B1) aj lista sekcie Kontrola v okne
    # Studio (ŠT-1b) — aby sa spravanie nemohlo rozist a novy stav dostali
    # vsetky otvorene okna.
    # Ziadna operacia a ziadny zapis do modelu (lekcia D-103/D-105): EdgeCheck
    # je overlay NAD modelom, nie jeho obsah.
    def self.toggle_edge_check(model = nil)
      return nil unless defined?(EdgeCheck)

      state = EdgeCheck.toggle(model || Sketchup.active_model)
      broadcast_edge_check(state)
      state
    rescue StandardError => e
      log_error(e, 'Engine.toggle_edge_check')
      nil
    end

    # Rozoslanie stavu vsetkym oknam, ktore ho zobrazuju. Defenzivne: zavrete
    # ani nenacitane okno push nezhodi (kazdy `push_edge_check` ma vlastny guard).
    def self.broadcast_edge_check(state)
      # ŠT-1c PR B3: okno Vyroba zaniklo — prijimatelia su uz len DVAJA.
      # Lista sekcie Kontrola v okne Studio: bez nej by prepnutie z railu
      # nebolo v otvorenom Studiu vidiet.
      StudioDialog.push_edge_check(state) if defined?(StudioDialog)
      Panel.push_edge_check(state) if defined?(Panel)
    rescue StandardError => e
      log_error(e, 'Engine.broadcast_edge_check')
    end

    # --- v0.7.28: zdielane PREPNUTIE JEDNEHO STAVU (3-stavove nastavenie) ----
    # Presny protajsok `toggle_edge_check`: JEDINE miesto, kde sa prepina, ktory
    # stav olepu sa zvyrazni. Volaju ho OBA vstupne body — rohovy trojuholnik
    # v liste sekcie Kontrola okna Studio (ŠT-1b) aj rohovy trojuholnik v raile
    # Inspectora — takze sa nastavenie nemoze rozist a novy stav (aj s cerstvymi
    # poctami) dostanu obe okna.
    # Nastavenie zije v %APPDATA%, NIKDY v .skp: ziadna operacia, ziadny zapis
    # do modelu, ziadny krok Spat.
    # O platnosti kluca a striktnom booleane rozhoduje EdgeCheck.set_option.
    def self.set_edge_check_option(key, value)
      return nil unless defined?(EdgeCheck)

      EdgeCheck.set_option(key, value)
      state = EdgeCheck.ui_state(Sketchup.active_model)
      broadcast_edge_check(state)
      state
    rescue StandardError => e
      log_error(e, 'Engine.set_edge_check_option')
      nil
    end

    # To iste nastavenie sa da otvorit z DVOCH miest. Aby na obrazovke nikdy
    # nestali DVE kopie tych istych prepinacov, otvorenie na jednom mieste
    # zavrie to druhe. Je to CISTO zobrazovacia vec — ziadny stav, ziadny zapis
    # (`source` je okno, ktore prave otvorilo svoje).
    def self.close_edge_menu(source)
      # ŠT-1c PR B3: instancie su uz len DVE (okno Vyroba zaniklo) — lista
      # sekcie Kontrola v Studiu a roh ABS ikony v raile Inspectora.
      StudioDialog.close_edge_menu if source != :studio && defined?(StudioDialog)
      Panel.close_edge_menu if source != :panel && defined?(Panel)
    rescue StandardError => e
      log_error(e, 'Engine.close_edge_menu')
    end

    # --- K2/D-87: zdielane prepnutie KONTROLY KRESBY -------------------------
    # Presna kopia vzoru vyssie. JEDINE miesto, kde sa smer kresby prepina —
    # volaju ho VSETCI klienti: rail Inspectora aj lista sekcie Kontrola v okne
    # Studio. Dva vstupne body nesmu mat dva stavy: klik v raile musi byt vidiet
    # v otvorenom Studiu a naopak.
    # Ziadna operacia a ziadny zapis do modelu: GrainCheck je overlay NAD
    # modelom, nie jeho obsah (lekcia D-103/D-105).
    def self.toggle_grain_check(model = nil)
      return nil unless defined?(GrainCheck)

      state = GrainCheck.toggle(model || Sketchup.active_model)
      broadcast_grain_check(state)
      state
    rescue StandardError => e
      log_error(e, 'Engine.toggle_grain_check')
      nil
    end

    # `state = nil` je zamer: po PREPOCTE (prestavba pri zapnutej kresbe) sa
    # cerstve cisla nikde nedrzia a kazde okno si ich vypyta samo.
    def self.broadcast_grain_check(state = nil)
      # ŠT-1c PR B3: okno Vyroba zaniklo — prijimatelia su uz len DVAJA.
      StudioDialog.push_grain_check(state) if defined?(StudioDialog) # ŠT-1b: sekcia Kontrola
      Panel.push_grain_check(state) if defined?(Panel)
    rescue StandardError => e
      log_error(e, 'Engine.broadcast_grain_check')
    end

    # --- D-27: zdielane prepnutie VIDITELNOSTI TAGU MODELU ------------------
    # JEDINE miesto, kde sa viditelnost tagu prepina — volaju ho OBA vstupne
    # body: okno tagov v raile Inspectora aj checkbox „Zobraziť zóny (ghost)
    # v modeli" (cez `Zones.set_visible`). Dva vstupy nesmu mat dva stavy ani
    # dve undo semantiky.
    # Na rozdiel od kontroly hran a kresby (overlay NAD modelom, ziadny zapis)
    # je viditelnost tagu ULOZENA V .skp — `Tags.set_visible` ju preto zapisuje
    # v operacii = JEDEN krok Spat.
    def self.set_tag_visible(key, value, model = nil)
      return nil unless defined?(Tags)

      state = Tags.set_visible(model || Sketchup.active_model, key, value)
      broadcast_tags(state)
      state
    rescue StandardError => e
      log_error(e, 'Engine.set_tag_visible')
      nil
    end

    # Prijemca je zatial jeden (Inspector), ale zobrazuje stav na DVOCH
    # miestach (okno tagov v raile + checkbox ghost zon) — preto ide stav
    # broadcastom a panel si ziadnu vlastnu kopiu nedrzi.
    def self.broadcast_tags(state = nil)
      Panel.push_tags(state) if defined?(Panel)
    rescue StandardError => e
      log_error(e, 'Engine.broadcast_tags')
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

      # D-52a (B2): KAZDY vstupny bod pluginu ma restart latch. Po uspesnej
      # aktualizacii bezi v pamati STARY Ruby kod nad NOVYMI subormi — otvorene
      # okno by nacitalo nove HTML/JS proti starym callbackom. Guard je preto
      # PRIAMO v tele kazdeho prikazu (nie az v `Panel.show`), aby sa cez toolbar
      # nedal spustit ani prepinac prekrytia.
      cmd_panel = UI::Command.new('Inspector') do
        next if update_restart_pending?

        Panel.dialog_alive? ? Panel.hide : Panel.show
      end
      cmd_panel.tooltip = 'Inspector — panel Noxun Engine (znova zavrie)'
      cmd_panel.status_bar_text = 'Otvori alebo zavrie panel na vkladanie a upravu korpusov.'
      cmd_panel.set_validation_proc { toolbar_state { Panel.dialog_alive? } }
      toolbar_icon(cmd_panel, 'noxun_logo.svg')
      tb.add_item(cmd_panel)

      # ST-1a (audit #2): tlačidlo sa volá Štúdio a otvára ŠTÚDIO.
      # ŠT-1c PR B3: okno Výroba zaniklo — Štúdio je JEDINÉ okno výstupov
      # zákazky (Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka).
      cmd_studio = UI::Command.new('Štúdio') do
        next if update_restart_pending?

        StudioDialog.show
      end
      cmd_studio.tooltip = 'Štúdio — kusovník, kontrola, nákup kovania, rozpočet a cenová ponuka'
      cmd_studio.status_bar_text = 'Kusovník, kontrola, rozpočet, cenová ponuka a výstupy zákazky.'
      toolbar_icon(cmd_studio, 'noxun_studio.svg')
      tb.add_item(cmd_studio)

      # UI-B1 (audit A2): prepnutie ide cez ZDIELANU metodu Engine.toggle_edge_check
      # — tá zavola EdgeCheck.toggle a rozposle novy stav vsetkym oknam (Studio
      # ma prepinac v liste sekcie Kontrola, Inspector ikonu v raile; bez pushu
      # by obe ostali na starom stave).
      cmd_abs = UI::Command.new('ABS kontrola hrán') do
        next if update_restart_pending?

        toggle_edge_check
      end
      cmd_abs.tooltip = 'ABS kontrola hrán — zvýrazní olep v modeli (prepínač)'
      cmd_abs.status_bar_text = 'Zapne/vypne farebné zvýraznenie olepu hrán. Nastavenie je v Štúdiu → Kontrola.'
      cmd_abs.set_validation_proc do
        if !defined?(EdgeCheck) || !EdgeCheck.available?
          MF_GRAYED
        else
          toolbar_state { EdgeCheck.active? }
        end
      end
      toolbar_icon(cmd_abs, 'noxun_abs.svg')
      tb.add_item(cmd_abs)

      cmd_insert = UI::Command.new('Vložiť skrinku') do
        next if update_restart_pending?

        Panel.show_insert
      end
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
Sketchup.require 'noxun_engine/core/doc_key' # 1d/R-02b: stabilna identita dokumentu (pred vsetkymi identity guardmi)
Sketchup.require 'noxun_engine/core/ids'
Sketchup.require 'noxun_engine/core/store'
Sketchup.require 'noxun_engine/core/part_keys' # stabilna identita dielcov pre override a buduce vystupy
Sketchup.require 'noxun_engine/core/build_plan' # zavazny kontrakt planu (validator, warnings, hardware)
Sketchup.require 'noxun_engine/core/part_faces' # D-88: kontrakt hrana -> plocha kvadra (pred vsetkymi tvorcami deskriptorov)
Sketchup.require 'noxun_engine/core/json_file_store' # cache + bezpecny atomicky zapis JSON katalogov
Sketchup.require 'noxun_engine/core/dim_series'  # UI-B3 (N6): rozmerove rady panela (%APPDATA%, nastavenie pocitaca)
Sketchup.require 'noxun_engine/core/materials'   # V0.3 materialovy katalog (pred abs_rules)
Sketchup.require 'noxun_engine/core/updater'     # D-52a: jadro aktualizatora pluginu (po materials — pouziva with_catalog_lock)
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
Sketchup.require 'noxun_engine/core/ghost_tool'    # V1-04 GHOST vkladanie na klik (po cabinet_builder — pouziva sev R-03)
Sketchup.require 'noxun_engine/core/tags'          # D-27 viditelnost tagov modelu (po builderoch — cita ich konstanty mien)
Sketchup.require 'noxun_engine/core/templates'
Sketchup.require 'noxun_engine/core/template_previews' # UI-D2: PNG nahlady sablon (subor vedla templates.json)
Sketchup.require 'noxun_engine/core/bom'           # V0.5 A kusovnik/supisy zo snapshotov
Sketchup.require 'noxun_engine/core/usage_stats'   # D-25 merac pouzivania panela (lokalne pocitadla)
Sketchup.require 'noxun_engine/core/vepo_export'   # V0.5 C VEPO CSV export (prirezy z BOM)
Sketchup.require 'noxun_engine/core/sheet_estimate' # D-19 orientacny odhad platni
Sketchup.require 'noxun_engine/core/debug'         # read-only diagnostika stavu (bugcatch cez MCP)
Sketchup.require 'noxun_engine/core/validation'    # V0.5 D kontrolny semafor vyroby (RED/ORANGE)
Sketchup.require 'noxun_engine/core/edge_check'     # D-104 kontrola hran (po validation — zdiela jeho definicie UNI/nelepitelnych)
Sketchup.require 'noxun_engine/core/hover_edge'     # D-89a hrana pod kurzorom (pred edge_overlay — ten definuje jej Overlay triedu)
Sketchup.require 'noxun_engine/core/grain_check'    # K2/D-87 smer kresby (po edge_check — zdiela jeho prechod modelom; pred edge_overlay)
Sketchup.require 'noxun_engine/core/edge_overlay'   # D-104 Sketchup::Overlay + ModelObserver (SU 2023+, guardovane) + D-89a HoverEdgeOverlay + K2 GrainOverlay
Sketchup.require 'noxun_engine/core/supplier_settings' # V0.6 E-a: sadzby/rezimy/standardne riadky rozpoctu (globál)
Sketchup.require 'noxun_engine/core/budget_store'  # V0.6 E-a: data rozpoctu v zakazke (po store + supplier_settings)
Sketchup.require 'noxun_engine/core/budget'        # V0.6 E-a: vypocet rozpoctu (po bom/sheet_estimate/budget_store)
Sketchup.require 'noxun_engine/core/xlsx_writer'   # V0.6 E-b: pravy .xlsx bez gemov + Luciin harok rozpoctu
Sketchup.require 'noxun_engine/core/cp_export'     # V0.6 E-b2: cenova ponuka (view nad rozpoctom) + zakaznicky xlsx
Sketchup.require 'noxun_engine/core/price_refresh' # V0.6 E-c: hromadne obnovenie cien z Demosu (po demos/lookup + hardware_catalog)
# ŠT-1c PR B3: `ui/production_dialog.rb` (okno Vyroba) ZANIKOL — cely jeho
# obsah zije v okne Studio. Zdielane ciste jadro `production_core` ostava:
# je to autorita exportov, mutacii rozpoctu, prepinacov a textov (Studio aj
# rail Inspectora ho citaju). Nacita sa PRED oknom Studio, ktore ho vola.
Sketchup.require 'noxun_engine/ui/production_core'   # ST-1a: zdielane ciste jadro vystupov — PRED oknom Studio
Sketchup.require 'noxun_engine/ui/studio_dialog'     # ST-1a okno Studio (skelet + Kusovnik)
Sketchup.require 'noxun_engine/ui/panel'
Sketchup.require 'noxun_engine/ui/rules_dialog'     # V0.4 editor pravidiel kovania
Sketchup.require 'noxun_engine/ui/materials_dialog' # V0.4.5 D2 projektove predvolby materialov
Sketchup.require 'noxun_engine/ui/hardware_catalog_dialog' # V0.6 C-2: okno Katalog kovania
Sketchup.require 'noxun_engine/ui/supplier_settings_dialog' # ŠT-4a: serverova autorita sekcii Nastavenia (okno zaniklo)
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

# D-52a (B3): PROCESNY LEASE si zapisuje LOADER (`noxun_engine.rb`,
# `Boot.write_lease!`) hned na zaciatku bootu a POD ZAMKOM aktualizacie —
# NIE tu. Zapis az na konci `main.rb` by prisiel po nacitani celeho stromu,
# takze `Updater.apply!`, ktory prave bezi, by tento proces nemusel vidiet
# (Codex #277 kolo 2, P1).

      begin
        install_toolbar # UI-02: logo · Studio · ABS kontrola · Vlozit

        menu = UI.menu('Extensions').add_submenu('Noxun Engine')
        menu.add_item('Panel') { Panel.show }
        menu.add_item('Štúdio') { StudioDialog.show } # ST-1a
        # ŠT-1c PR B3: docasna polozka „Výroba" tu ZANIKLA spolu s oknom —
        # kusovnik, kontrola, nakup kovania, rozpocet aj cenova ponuka su
        # sekciami Studia.
        # ŠT-3b-1: okno „Pravidlá kovania" zaniklo — polozka menu ostava ako
        # zauzivana skratka, ale otvara SEKCIU Pravidla v Studiu.
        menu.add_item('Pravidlá kovania') { StudioDialog.show(open_section: 'rules') }
        # ŠT-2b: okno „Materiály projektu" zaniklo — polozka menu ostava ako
        # zauzivana skratka, ale otvara SEKCIU Materialy v Studiu.
        menu.add_item('Materiály projektu') { StudioDialog.show(open_section: 'mat') }
        # ŠT-3a-2: okno „Katalóg kovania" zaniklo — polozka menu ostava ako
        # zauzivana skratka, ale otvara SEKCIU Kovanie v Studiu.
        menu.add_item('Katalóg kovania') { StudioDialog.show(open_section: 'hw') }
        # ŠT-4a: okno „Nastavenia rozpočtu" ZANIKLO (posledny satelit) — polozka
        # menu ostava ako zauzivana skratka, ale otvara SEKCIU v Studiu.
        menu.add_item('Nastavenia rozpočtu') { StudioDialog.show(open_section: 'bset') }
        # ŠT-3c-1: zauzivana polozka ostava, ale otvara SEKCIU Sablony v Studiu
        # (satelitne okno Sablony zaniklo).
        menu.add_item('Šablóny') { StudioDialog.show(open_section: 'tpl') }

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
