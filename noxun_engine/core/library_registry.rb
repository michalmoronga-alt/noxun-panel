# frozen_string_literal: true
# Noxun Engine — H16 (C-04, priprava D-48): SUPIS KNIZNIC A ULOZISK MIMO MODELU.
#
# Ciste DATA: co plugin uklada na disk mimo zakazky (.skp), kde, pod akym
# zamkom, s akou verziou dat, s akymi prilohami, kto to zapisuje a ci sa to
# pri D-48 ZDIELA medzi pocitacmi (Michal <-> Lucia) alebo ostava len tomuto
# PC. Nic nekopiruje, necita disk a nemeni ziadnu cestu ani spravanie — cesty
# pocitaju moduly samy (`resolver`), register nesie len NOVE fakty.
#
# AUTORITA KLASIFIKACIE pre D-48: Odoslat / Aktualizovat (SYNC-0..3) postavi
# zoznam prenasanych suborov z tohto registra, nikdy z vypisu priecinka (v koreni
# mozu byt cudzie subory — `OUTSIDE['dev_tools']`). SYNC-0 ho rozsiri o vynutenie
# (`JsonFileStore` odmietne neregistrovany subor) a hacky (`assess_import`) —
# dnes NIE (mení spravanie, vlastny audit).
#
# ZMENA `sync` (zdielat / len tento PC) = ROZHODNUTIE MICHALA (test pripina
# zdielanu mnozinu). NOVE ULOZISKO = riadok tu + scenar „Nove ulozisko na
# pocitaci" v `docs/architecture/rozsirovacie-body.md` (cesta cez
# `Materials.dir`, verzia v STANDARD §13.1, riadok v `docs/architecture/
# kniznice.md`, krok v bezci prveho behu, pocet zapisovych miest v teste).
# Guard: `tests/pure/test_h16_kniznice.rb`.
#
# Riadok `ENTRIES` (String kluce, poradie = supis v `kniznice.md`):
#   key        jedinecny snake_case
#   file       relativne ku korenu; priecinok konci '/'; forenzne zalohy = glob
#              (`File.fnmatch` s FNM_EXTGLOB)
#   kind       KINDS — kniznica · prilohy · nastavenie · cache · znacka · zaloha
#   sync       'shared' (D-48 prenasa) | 'local' (len tento PC)
#   resolver   'Modul.metoda' vracajuca absolutnu cestu (alebo nil)
#   lock       meno zamku z LOCKS (nil pri lock_mode self/none)
#   lock_mode  module (modul berie zamok sam) · caller (drzi ho volajuci) ·
#              mixed (cast zapisov bez neho) · self (subor zamyka sam seba) · none
#   versions   konstanty verzie v zapise STANDARD §13.1 („Subory na pocitaci")
#   bak        true = zapis cez `JsonFileStore.write` (vedla vznika `.bak`)
#   of / attachments  prilohy <-> kniznica (obojsmerne)
#   children   priecinok: vzory FINALNYCH suborov (D-48 prenasa len tie)
#   transient  vzory docasnych mien (nikdy sa neprenasaju)
#   writers    subory so zapisom (cesty od korena repa)
#   outputs    true = obsah meni kusovnik, VEPO, kovanie alebo ceny
#   note       kratka veta (povinna pri outputs + local)
module Noxun
  module Engine
    module LibraryRegistry
      KINDS = %w[library attachments setting cache marker backup].freeze
      SYNCS = %w[shared local].freeze
      LOCK_MODES = %w[module caller mixed self none].freeze
      # Docasne mena atomickeho zapisu `JsonFileStore` (primar aj `.bak`).
      STORE_TRANSIENT = %w[.tmp-* .bak.tmp-*].freeze
      # Primitiva zapisu bez vlastneho ulozista (zapisuju za volajuceho).
      PRIMITIVES = %w[noxun_engine/core/json_file_store.rb].freeze

      # Zamkove subory v koreni -> metoda, ktora vrati ich cestu.
      LOCKS = {
        'materials.lock' => 'Materials.catalog_lock_path',
        'hardware_catalog.lock' => 'HardwareCatalog.lock_path',
        'templates.json.lock' => 'TemplateStore.lock_path',
        'template_usage.json.lock' => 'TemplateUsage.lock_path',
        'appliances.json.lock' => 'ApplianceCatalog.lock_path',
        'usage_stats.json.lock' => 'UsageStats.lock_path'
      }.freeze

      CORE = 'noxun_engine/core/'
      private_constant :CORE

      def self.deep_freeze(obj)
        case obj
        when Hash then obj.each_value { |v| deep_freeze(v) }
        when Array then obj.each { |v| deep_freeze(v) }
        end
        obj.freeze
      end
      private_class_method :deep_freeze

      # Zostavi riadok; `.tmp-*` atomickeho zapisu doplni pri `bak` sam.
      def self.row(key, file, kind, sync, resolver: nil, lock: nil, lock_mode: 'none', versions: [], bak: false,
                   of: nil, attachments: [], children: [], transient: [], writers: [], outputs: false, note: '')
        transient += STORE_TRANSIENT.map { |s| "#{file}#{s}" } if bak
        deep_freeze('key' => key, 'file' => file, 'kind' => kind, 'sync' => sync, 'resolver' => resolver,
                    'lock' => lock, 'lock_mode' => lock_mode, 'versions' => versions, 'bak' => bak,
                    'of' => of, 'attachments' => attachments, 'children' => children,
                    'transient' => transient, 'writers' => writers, 'outputs' => outputs, 'note' => note)
      end
      private_class_method :row

      ENTRIES = deep_freeze([
        # --- kniznice a ich prilohy (D-48: Odoslat / Aktualizovat) ------------------
        row('materials', 'materials.json', 'library', 'shared', resolver: 'Materials.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[Materials::STD Materials::SCHEMA_CURRENT],
            bak: true, attachments: %w[appearances], outputs: true,
            writers: %W[#{CORE}materials.rb #{CORE}materials_health.rb], note: 'katalog dosiek a ABS'),
        row('appearances', 'appearances/', 'attachments', 'shared', lock: 'materials.lock', lock_mode: 'module',
            of: 'materials', children: %w[*.skm], transient: %w[*.skm.staging],
            writers: %W[#{CORE}materials_appearance.rb #{CORE}materials_native_appearance.rb],
            note: 'nemenne subory vzhladu <uuid>.skm, odkaz appearance.id v katalogu'),
        row('abs_rules', 'abs_rules.json', 'library', 'shared', resolver: 'AbsRules.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[AbsRules::STD AbsRules::SEED_VERSION],
            bak: true, outputs: true, writers: %W[#{CORE}abs_rules.rb], note: 'pravidla ABS hran podla roly'),
        row('hardware_rules', 'hardware_rules.json', 'library', 'shared', resolver: 'HardwareRules.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[HardwareRules::STD HardwareRules::SEED_VERSION],
            bak: true, outputs: true, writers: %W[#{CORE}hardware_rules.rb], note: 'pravidla kovania'),
        row('hardware_catalog', 'hardware_catalog.json', 'library', 'shared', resolver: 'HardwareCatalog.path',
            lock: 'hardware_catalog.lock', lock_mode: 'module',
            versions: %w[HardwareCatalog::SCHEMA_CURRENT HardwareCatalog::SEED_SET_VERSION],
            bak: true, outputs: true, writers: %W[#{CORE}hardware_catalog.rb],
            note: 'katalog poloziek kovania; vlastny zamok, nevnara sa s materials.lock'),
        row('hardware_taxonomy', 'hardware_taxonomy.json', 'library', 'shared', resolver: 'HardwareTaxonomy.path',
            lock: 'materials.lock', lock_mode: 'module',
            versions: %w[HardwareTaxonomy::SCHEMA_CURRENT HardwareTaxonomy::SEED_VERSION],
            bak: true, outputs: true, writers: %W[#{CORE}hardware_taxonomy.rb], note: 'vyrobcovia a rady kovania'),
        row('hardware_sets', 'hardware_sets.json', 'library', 'shared', resolver: 'HardwareSets.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[HardwareSets::STD HardwareSets::SEED_VERSION],
            bak: true, outputs: true, writers: %W[#{CORE}hardware_sets.rb], note: 'sety kovania'),
        row('templates', 'templates.json', 'library', 'shared', resolver: 'TemplateStore.path',
            lock: 'templates.json.lock', lock_mode: 'module', versions: %w[TemplateStore::STD],
            bak: true, attachments: %w[template_previews], outputs: true, writers: %W[#{CORE}templates.rb],
            note: 'sablony skriniek a dosiek'),
        row('template_previews', 'template_previews/', 'attachments', 'shared', resolver: 'TemplatePreviews.dir',
            lock: 'templates.json.lock', lock_mode: 'caller', of: 'templates',
            children: %w[*-*-????????????????.png], transient: %w[*.png.new tmp/capture-*.png],
            writers: %W[#{CORE}template_previews.rb],
            note: 'nahlady <druh>-<slug>-<sha16>.png; meno z druhu a mena = rovnake na oboch PC'),
        row('supplier_settings', 'supplier_settings.json', 'library', 'shared', resolver: 'SupplierSettings.path',
            lock: 'materials.lock', lock_mode: 'module',
            versions: %w[SupplierSettings::STD SupplierSettings::SEED_VERSION],
            bak: true, outputs: true, writers: %W[#{CORE}supplier_settings.rb],
            note: 'sadzby a riadky rozpoctu (Nastavenia rozpoctu)'),
        row('appliances', 'appliances.json', 'library', 'shared', resolver: 'ApplianceCatalog.path',
            lock: 'appliances.json.lock', lock_mode: 'module',
            versions: %w[ApplianceCatalog::STD ApplianceCatalog::SEED_VERSION],
            bak: true, attachments: %w[appliance_files], outputs: true, writers: %W[#{CORE}appliance_catalog.rb],
            note: 'katalog spotrebicov'),
        row('appliance_files', 'appliances/', 'attachments', 'shared', resolver: 'ApplianceCatalog.attachments_root',
            lock: 'appliances.json.lock', lock_mode: 'module', of: 'appliances',
            children: %w[*/*_*.*], transient: %w[*/*.tmp], writers: %W[#{CORE}appliance_catalog.rb],
            note: 'listy spotrebicov <uuid>/<uuid>_<slug>.<ext>; v zazname relativne meno'),
        # --- nastavenia tohto pocitaca --------------------------------------------------
        row('dim_series', 'dim_series.json', 'setting', 'local', resolver: 'DimSeries.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[DimSeries::STD], bak: true,
            writers: %W[#{CORE}dim_series.rb], note: 'rozmerove rady poli Inspectora — kazdy PC svoje (Michal 2.10.)'),
        row('export_settings', 'vepo_settings.json', 'setting', 'local', resolver: 'ExportSettings.path',
            lock: 'materials.lock', lock_mode: 'module', bak: true, outputs: true,
            writers: %W[#{CORE}export_settings.rb],
            note: 'zmiesany: nazvy zakaziek (kluc = cesta .skp), posledny priecinok a 18 + 36 (meni subory VEPO) — ' \
                  'kazdy PC svoje (Michal 2.10.)'),
        row('template_usage', 'template_usage.json', 'setting', 'local', resolver: 'TemplateUsage.path',
            lock: 'template_usage.json.lock', lock_mode: 'module', versions: %w[TemplateUsage::STD], bak: true,
            writers: %W[#{CORE}templates.rb], note: 'naposledy pouzite sablony tohto PC'),
        row('ui_theme', 'ui_theme.json', 'setting', 'local', resolver: 'Engine.ui_theme_path',
            versions: %w[Engine::UI_THEME_STD], bak: true, writers: %w[noxun_engine/main.rb],
            note: 'tema okien (Michal / Lucia)'),
        row('edge_check', 'edge_check.json', 'setting', 'local', resolver: 'EdgeCheck.settings_path',
            versions: %w[EdgeCheck::SETTINGS_STD], bak: true, writers: %W[#{CORE}edge_check.rb],
            note: 'prepinac kontroly hran'),
        row('grain_check', 'grain_check.json', 'setting', 'local', resolver: 'GrainCheck.settings_path',
            versions: %w[GrainCheck::SETTINGS_STD], bak: true, writers: %W[#{CORE}grain_check.rb],
            note: 'prepinac kontroly kresby'),
        row('direction_check', 'direction_check.json', 'setting', 'local', resolver: 'DirectionCheck.settings_path',
            versions: %w[DirectionCheck::SETTINGS_STD], bak: true, writers: %W[#{CORE}direction_check.rb],
            note: 'prepinac smeru otvarania'),
        row('updater_settings', 'updater_settings.json', 'setting', 'local', resolver: 'Updater.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[Updater::STD], bak: true,
            writers: %W[#{CORE}updater.rb], note: 'cesta k distribucii aktualizacii'),
        row('usage_stats', 'usage_stats.json', 'setting', 'local', resolver: 'UsageStats.path',
            lock: 'usage_stats.json.lock', lock_mode: 'module', versions: %w[UsageStats::SCHEMA], bak: true,
            writers: %W[#{CORE}usage_stats.rb], note: 'merac pouzivania panela'),
        # --- cache (da sa znova stiahnut) ----------------------------------------------
        row('demos_sitemap', 'demos_sitemap.json', 'cache', 'local', resolver: 'DemosSitemapCache.path', bak: true,
            writers: %W[#{CORE}demos/sitemap_cache.rb], note: 'zoznam produktov Demosu'),
        row('textures', 'textures/', 'cache', 'local', resolver: 'DemosImageCache.dir',
            children: %w[??????????_*], transient: %w[*.tmp[0-9]*], writers: %W[#{CORE}demos/image_cache.rb],
            note: 'obrazky dekorov — stahuju sa len pri zalozeni skupiny'),
        # --- technicke znacky ------------------------------------------------------------
        row('legacy_cleanup', 'legacy_cleanup.json', 'marker', 'local', resolver: 'Tools::LegacyCleanup.path',
            lock: 'materials.lock', lock_mode: 'module', versions: %w[LegacyCleanup::STD], bak: true,
            writers: %w[noxun_engine/tools/legacy_cleanup.rb], note: 'kluc = cesta Plugins tohto PC'),
        row('migration_hold', 'migration_hold.json', 'marker', 'local', resolver: 'Materials.migration_hold_path',
            lock: 'materials.lock', lock_mode: 'mixed', transient: %w[migration_hold.json.tmp-*],
            writers: %W[#{CORE}materials_health.rb], note: 'jednorazova; mazanie bez zamku'),
        row('uni_seed', 'uni_seed.done', 'marker', 'local', resolver: 'Materials.uni_marker_path',
            lock: 'materials.lock', lock_mode: 'caller', bak: true,
            writers: %W[#{CORE}materials_catalog.rb #{CORE}materials_health.rb],
            note: 'aj „seed vedome zmazany — nevracat"'),
        row('drawer_uni_seed', 'drawer_uni_seed.done', 'marker', 'local', resolver: 'Materials.drawer_uni_marker_path',
            lock: 'materials.lock', lock_mode: 'caller', bak: true, writers: %W[#{CORE}materials_catalog.rb],
            note: 'aj „seed vedome zmazany — nevracat"'),
        row('demos_throttle', 'demos_throttle.lock', 'marker', 'local', resolver: 'Demos.throttle_path',
            lock_mode: 'self', writers: %W[#{CORE}demos/client.rb], note: 'cas posledneho dopytu na Demos'),
        # --- technicke zalohy ------------------------------------------------------------
        row('materials_pre_schema2', 'materials.pre-schema-2.json', 'backup', 'local',
            resolver: 'Materials.pre_schema2_backup_path', lock: 'materials.lock', lock_mode: 'caller',
            transient: %w[materials.pre-schema-2.json.tmp-*], writers: %W[#{CORE}materials.rb],
            note: 'predmigracna zaloha katalogu'),
        row('materials_forensic', 'materials.{corrupted,rolledback,json.bak.pre-rollback}-*.json', 'backup', 'local',
            lock: 'materials.lock', lock_mode: 'caller', transient: %w[materials.*.json.tmp-*],
            writers: %W[#{CORE}materials_health.rb], note: 'forenzne kopie pri obnove a rollbacku')
      ])

      # Mimo korena — D-48 sa ich netyka (supis kvoli uplnosti). `names` =
      # literaly a kluce, ktore guard v kode najde; `writers` = subory so
      # zapisom na disk (pri `ui_memory` JS subory s localStorage).
      OUTSIDE = deep_freeze([
        { 'key' => 'plugin_install', 'where' => 'priecinok Plugins',
          'names' => %w[noxun_engine.update.json noxun_engine.update.lock noxun_engine.leases],
          'writers' => %W[noxun_engine.rb #{CORE}updater.rb noxun_engine/tools/legacy_cleanup.rb],
          'reason' => 'instalacia a aktualizacia pluginu (Updater D-52)' },
        { 'key' => 'plugin_data', 'where' => 'noxun_engine/data/recipes/',
          'names' => %w[RELEASED.json], 'writers' => [],
          'reason' => 'data pluginu len na citanie — prichadzaju s aktualizaciou' },
        { 'key' => 'exports', 'where' => 'priecinok alebo subor, ktory vybral pouzivatel',
          'names' => [], 'writers' => %W[#{CORE}vepo_export.rb #{CORE}xlsx_writer.rb noxun_engine/ui/production_core.rb],
          'reason' => 'vystupy zakazky (VEPO, CSV, XLSX), nie kniznica' },
        { 'key' => 'temp', 'where' => 'Dir.mktmpdir, Sketchup.temp_dir',
          'names' => %w[preview.png working.skm.staging],
          'writers' => %w[noxun_engine/ui/materials_appearance_dialog.rb noxun_engine/ui/appliance_dialog.rb],
          'reason' => 'docasne subory, po pouziti zanikaju' },
        { 'key' => 'ui_memory', 'where' => 'localStorage okien (CEF profil SketchUpu)',
          'names' => %w[nxsec_* nx_bom_cols nx_bom_groups nx_studio_nav nx_budget_vat nx_hw_shelfpins_open
                        nx_np_closed nx_recent_decor nx_recent_abs noxun.tpl.with_hardware],
          'writers' => %w[boot budget form hardware nx_combo sheet_layout studio].map { |f| "noxun_engine/ui/js/#{f}.js" },
          'reason' => 'pamat okna tohto PC (zbalenia, stlpce, posledne dekory); nxsec_* sklada shell.js' },
        { 'key' => 'dialog_prefs', 'where' => 'SketchUp preferences_key',
          'names' => %w[noxun_engine_panel noxun_engine_studio noxun_engine_tools_zmove], 'writers' => [],
          'reason' => 'velkost a poloha okien si pamata SketchUp' },
        { 'key' => 'model', 'where' => '.skp, slovnik NOXUN na modeli',
          'names' => [], 'writers' => [], 'reason' => 'cestuje so zakazkou' },
        { 'key' => 'dev_tools', 'where' => 'koren %APPDATA%\\NOXUN\\Engine (cudzi subor)',
          'names' => %w[agent_register_videne.txt], 'writers' => %w[scripts/start_okna.ps1],
          'reason' => 'nastroj agentov, nie plugin — D-48 subory mimo registra ignoruje' }
      ])

      module_function

      # JEDINY koren vsetkych riadkov (%APPDATA%\NOXUN\Engine; testy cez override).
      def root
        Materials.dir
      end

      def entries
        ENTRIES
      end

      def keys
        ENTRIES.map { |r| r['key'] }
      end

      # Riadok podla kluca (String alebo Symbol); neznamy = nil.
      def get(key)
        return nil if key.nil?

        ENTRIES.find { |r| r['key'] == key.to_s }
      end

      def shared
        ENTRIES.select { |r| r['sync'] == 'shared' }
      end

      # Absolutna cesta riadku bez lomky na konci; glob = nil.
      def path(key)
        r = get(key)
        return nil if r.nil? || r['file'].match?(/[*?{\[]/)

        File.join(root, r['file'].chomp('/'))
      end
    end
  end
end
