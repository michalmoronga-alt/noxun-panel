# frozen_string_literal: true
# Noxun Engine — NASTROJE-1 (T1b): UPRATANIE STARYCH INSTALACII Mower a Snaper.
#
# CO TO ROBI: pri boote odstrani z priecinka `Plugins` styri legacy ciele
# (`noxun_mower_loader.rb`, `Noxun_Mower/`, `snaper.rb`, `snaper/`) a zapamata
# si, ze dana instalacia je uz upratana.
#
# PRECO BOOT MIGRACIA A NIE UPDATER: pri aktualizacii (D-52) vykonava swap
# este STARY kod v pamati — novy `updater.rb` sa spusti az po restarte. Kod,
# ktory ma upratat legacy, teda musi bezat na ZACIATKU BOOTU noveho balika,
# nie v aktualizatore. Druhy kanal je instalator (`INSTALL_noxun_engine.ps1`),
# ktory maze tie iste styri cesty hned po skopirovani.
#
# CISTE JADRO (vzor `core/updater.rb`): ziadne `Sketchup.*` ani `UI.*`. Vsetky
# cesty prichadzaju ako PARAMETRE, hlasky su len KONSTANTY — o tom, ci a kde sa
# zobrazia, rozhoduje tenky boot hook v `main.rb`. Vdaka tomu bezi cela sada
# headless nad docasnym `Plugins` stromom.
#
# MARKER ZIJE MIMO SWAPOVANEHO STROMU (`%APPDATA%\NOXUN\Engine\legacy_cleanup.json`),
# nie v `Plugins`: aktualizacia D-52 cely strom pluginu vymiena, takze marker
# vnutri neho by sa pri kazdej aktualizacii stratil a migracia by sa spustala
# donekonecna. Kluc je NORMALIZOVANA cesta priecinka `Plugins` (Codex #288 kolo
# 3, P2) — jeden pocitac moze mat viac verzii SketchUpu, kazda ma vlastny
# `Plugins` a kazda sa musi upratat samostatne.
#
# ZLYHANIE NIE JE HOTOVO (audit 2 FIX 5): `FileUtils.rm_f` / `rm_rf` chybu
# POTLACIA a vratia sa bez vynimky. Preto sa po kazdom mazani OVERUJE, ci cesta
# naozaj zmizla, a kluc do markera sa zapise AZ po overenej nepritomnosti
# VSETKYCH STYROCH cielov. Zamknuty subor (beziaci SketchUp, antivirus,
# indexer) tak nezostane ticho oznaceny za upratany — migracia sa zopakuje pri
# dalsom boote.
require 'json'
require 'fileutils'

module Noxun
  module Engine
    module Tools
      module LegacyCleanup
        FILE = 'legacy_cleanup.json'
        STD = 1 # verzia formatu suboru (buduce migracie)

        # Presne styri ciele — zoznam je UZAVRETY a doslovny. Zmazat sa smie len
        # to, co tento plugin nahradil; ostatne legacy pluginy (Noxun_Pick,
        # V2fable, KOVANIE, vepo_exporter) sa odstavuju samostatne.
        TARGETS = %w[noxun_mower_loader.rb Noxun_Mower snaper.rb snaper].freeze

        # Hlasky su tu ako KONSTANTY (jadro nic nezobrazuje). Po uspesnom mazani
        # ostavaju legacy toolbary v pamati BEZIACEHO SketchUpu az do restartu —
        # preto veta hovori o restarte, nie o okamzitom vysledku.
        MSG_REMOVED = 'Staré pluginy Mower a Snaper boli odstránené — po reštarte SketchUpu ' \
                      'ostane jeden toolbar Noxun Nástroje.'
        MSG_FAILED  = 'Noxun Engine nedokázal odstrániť staré pluginy Mower/Snaper. Zavri ' \
                      'SketchUp a zmaž ich ručne (alebo spusti INSTALL_noxun_engine.ps1): '

        module_function

        # --- marker ------------------------------------------------------------
        # Rovnaka zlozka ako ostatne nastavenia pocitaca (tema, rozmerove rady,
        # cesta aktualizacie).
        def dir
          return Materials.dir if defined?(Materials) && Materials.respond_to?(:dir)

          ::File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
        end

        def path
          ::File.join(dir, FILE)
        end

        # Kluc = normalizovana cesta `Plugins`. Normalizaciu NEDUPLIKUJEME —
        # `Updater.normalize_path` uz riesi `\` vs `/`, koncove lomitko aj
        # korenove cesty (`G:/`, `//server/share`); Windows je navyse
        # case-insensitive, preto `downcase` (rovnako ako `Updater.same_path?`).
        def normalize_key(plugins_dir)
          Updater.normalize_path(plugins_dir).downcase
        end

        # Tolerantne citanie: chybajuci, poskodeny aj cudzi tvar suboru = ziadne
        # zaznamenane cesty. Migracia sa potom len ZOPAKUJE a to je bezpecne —
        # mazanie uz neexistujucich ciest je no-op.
        #
        # VEDOMA ODCHYLKA OD R-11 (degraded write block): pri poskodenom primare
        # s platnou `.bak` sa tu zapisy NEZASTAVUJU. Obsahom suboru je zoznam UZ
        # UPRATANYCH ciest — jeho strata znamena nanajvys jeden zbytocny (a
        # bezvysledny) prechod migracie, kym zastavenie zapisov by migraciu
        # nechalo bezat pri KAZDOM boote uz navzdy.
        def load_marker(marker_path)
          return {} unless JsonFileStore.available?(marker_path)

          raw = JsonFileStore.read(marker_path)
          done = raw.is_a?(Hash) ? raw['done'] : nil
          done.is_a?(Hash) ? done : {}
        rescue StandardError => e
          Engine.log_error(e, 'LegacyCleanup.load_marker')
          {}
        end

        # Zapis je UPLNA NAHRADA suboru (vzor `DimSeries.set`), preto musi byt
        # CELY cyklus CITAJ -> ZLUC -> ZAPIS pod jednym medziprocesovym zamkom
        # (R-08).
        #
        # Codex #295 kolo 1 (P2): povodne sa marker cital PRED zamkom. Dva
        # sucasne bootujuce procesy (dve okna SketchUpu, dve verzie so
        # zdielanym app-data) tak oba precitali STARY `done`, zamok ich zapisy
        # len zoradil — a neskorsi zapis prepisal marker BEZ kluca toho
        # druheho. Jednorazova garancia per Plugins cesta tym padla a ta
        # instalacia sa migrovala znova.
        #
        # `JsonFileStore.read` navyse drzi SEKUNDOVU cache (`CHECK_INTERVAL`),
        # ktora v tomto okne vrati snapshot spred cudzieho zapisu bez toho, aby
        # sa vobec pozrela na disk. Cudzi PROCES nasu cache neinvaliduje, takze
        # sa pred citanim pod zamkom vyslovne zahadzuje (`reload!`).
        #
        # Zlyhanie vracia FALSE — volajuci to musi priznat, nie vydat za uspech.
        def remember!(key, removed, marker_path)
          stamp = { 'at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
                    'removed' => Array(removed) }
          with_catalog_lock do
            JsonFileStore.reload!(marker_path) # cudzi zapis nasu cache nezmaze
            done = load_marker(marker_path)
            done[key] = stamp
            JsonFileStore.write(marker_path, 'std' => STD, 'done' => done)
          end
          true
        rescue StandardError => e
          Engine.log_error(e, 'LegacyCleanup.remember!')
          false
        end

        def with_catalog_lock(&blk)
          return Materials.with_catalog_lock(&blk) if defined?(Materials) && Materials.respond_to?(:with_catalog_lock)

          blk.call
        end

        # --- ciele -------------------------------------------------------------
        # `File.exist?` je TRUE aj pre priecinok, takze jedna metoda staci na
        # subor aj na zlozku. `File.symlink?` je tu kvoli visiacemu odkazu:
        # `exist?` ho nevidi, ale v `Plugins` by zostal lezat.
        def present?(target)
          ::File.exist?(target) || ::File.symlink?(target)
        end

        # `rm_rf` zmaze subor AJ priecinok a chyby POTLACI — preto je jedina
        # pravda az `present?` po nom (postkontrola nizsie).
        def remove(target)
          FileUtils.rm_rf(target)
          true
        rescue StandardError => e
          Engine.log_error(e, 'LegacyCleanup.remove')
          false
        end

        # --- migracia ----------------------------------------------------------
        # Vracia HASH (nikdy nevyhadzuje): volajuci z neho vie, ci sa nieco
        # zmazalo (hlaska o restarte), ci nieco zlyhalo (varovanie s cestami),
        # alebo ci sa vobec nic nedialo (skipped = ticho).
        #
        #   'state'   'skipped' | 'done' | 'failed' | 'error'
        #   'removed' mena skutocne odstranenych cielov
        #   'failed'  cesty, ktore po mazani ostali
        #   'stored'  podarilo sa zapisat marker?
        def run!(plugins_dir, marker_path: path)
          return result('error', reason: 'priečinok Plugins nie je zadaný') if plugins_dir.to_s.strip.empty?
          return result('error', reason: "priečinok #{plugins_dir} neexistuje") unless ::Dir.exist?(plugins_dir.to_s)

          key = normalize_key(plugins_dir)
          return result('skipped', key: key) if load_marker(marker_path).key?(key)

          removed = []
          failed = []
          TARGETS.each do |name|
            target = ::File.join(plugins_dir.to_s, name)
            was_there = present?(target)
            remove(target)
            # POSTKONTROLA — jediny dokaz, ze cesta naozaj zmizla.
            if present?(target)
              failed << target
            elsif was_there
              removed << name
            end
          end

          # Kluc sa zapise AZ po overenej nepritomnosti VSETKYCH cielov.
          return result('failed', removed: removed, failed: failed, key: key) unless failed.empty?

          stored = remember!(key, removed, marker_path)
          result('done', removed: removed, key: key, stored: stored)
        rescue StandardError => e
          # Migracia NIKDY nezhodi boot enginu — v najhorsom pripade sa zopakuje.
          Engine.log_error(e, 'LegacyCleanup.run!')
          result('error', reason: "#{e.class}: #{e.message}")
        end

        def result(state, removed: [], failed: [], key: '', stored: true, reason: '')
          { 'ok' => state == 'done' || state == 'skipped', 'state' => state,
            'removed' => removed, 'failed' => failed, 'plugins' => key,
            'stored' => stored, 'reason' => reason }
        end

        # Text pre pouzivatela (prazdny = niet co hlasit). Rozhodovanie je TU,
        # aby boot hook v `main.rb` ostal tenky a testovatelny bez SketchUpu.
        def message_for(res)
          return '' unless res.is_a?(Hash)

          case res['state']
          when 'done' then Array(res['removed']).empty? ? '' : MSG_REMOVED
          when 'failed' then MSG_FAILED + Array(res['failed']).join(', ')
          else ''
          end
        end
      end
    end
  end
end
