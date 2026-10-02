# frozen_string_literal: true
# Noxun Engine — zivotny cyklus pluginu v procese SketchUpu (H11a, F-01).
#
# DNES JEDNA ULOHA, CISTY RUBY: NACITANIE SUBOROV PLUGINU. `require_part` nacita
# vnutorny subor Ruby `require` s ABSOLUTNOU cestou — rovnaka semantika na 2026.0
# aj 2026.2 (`Sketchup.require` chyby do 2026.1 prehltne a vrati true, od 2026.2
# ich prepusti). Chyba sa zapise a pokracuje sa dalsim suborom (diagnostika
# celeho rozsahu); `main.rb` potom init NESPUSTI a ukaze JEDNU hlasku — plugin
# je v tom okne SketchUpu vypnuty (rozhodnutie Michala Q1). Jedina podporovana
# obnova = restart SketchUpu. Plugin sa NESIFRUJE (ziadne `.rbe`/`.rbs` — Ruby
# `require` by ich nevedel nacitat; guard test). Chyba samotneho `main.rb`
# ostava v rezii SketchUpu (kontrakt sa tyka suborov nacitanych z validneho
# `main.rb`).
#
# Ukoncovanie SketchUpu (pad #1117 v 2026.2) tu ZATIAL nie je: quit test H11a na
# 26.0.429 ukazal, ze SketchUp zatvara okna pluginu PRED `AppObserver#onQuit`
# (poradie B), takze priznak z `onQuit` by hooky okien nezachytil. Riesenie je
# davka H11c (zalozny navrh Z1, vlastny audit).
#
# Tento subor sa nacitava AKO PRVY (bootstrap v `main.rb` s vlastnou chybovou
# vetvou) — preto nesmie zavisiet od ziadneho ineho suboru pluginu. Posledny
# riadok je sentinel `LOADED`: dokaz, ze sa subor vykonal cely.

module Noxun
  module Engine
    module AppLifecycle
      BACKTRACE_LINES = 6
      # Koren `Plugins` (tento subor je `<Plugins>/noxun_engine/core/`).
      PLUGINS_ROOT = File.expand_path('../..', __dir__)

      class << self
        # `path` = cesta pod korenom bez `.rb` (`noxun_engine/core/units`).
        # -> true (nacitany teraz) · false (uz bol nacitany) · nil (chyba —
        # zapisana do `record`, predvolene globalny zoznam). Nikdy nevyhodi
        # chybu nacitania (StandardError, ScriptError); Interrupt a spol. prejdu.
        def require_part(path, record: nil, root: PLUGINS_ROOT)
          require(File.join(root, "#{path}.rb"))
        rescue StandardError, ScriptError => e
          entry = { 'path' => path.to_s, 'class' => e.class.name, 'message' => e.message.to_s,
                    'backtrace' => Array(e.backtrace).first(BACKTRACE_LINES) }
          (record || failures) << entry
          log("CHYBA pri načítaní #{path}.rb: #{e.class}: #{e.message}")
          entry['backtrace'].each { |line| log("  #{line}") }
          nil
        end

        def failures
          @failures ||= []
        end

        def failed?
          !failures.empty?
        end

        # Jedna hlaska na proces (aj pri viacerych chybach a opakovanom volani).
        def announce_failures!
          return false if @announced || !failed?

          @announced = true
          msg = failure_message
          log(msg)
          ::UI.messagebox(msg) if defined?(::UI) && ::UI.respond_to?(:messagebox)
          true
        rescue StandardError => e
          log("announce_failures!: #{e.class}: #{e.message}")
          false
        end

        def failure_message
          first = failures.first || {}
          "Noxun Engine sa nenačítal celý — chyba v súbore #{first['path']}.rb (spolu #{failures.length}). " \
            'Plugin je v tomto okne SketchUpu vypnutý, aby nepracoval s chýbajúcimi časťami. ' \
            'Podrobnosti sú v Ruby konzole. Reštartuj SketchUp; ak to nepomôže, nainštaluj plugin znova.'
        end

        # LEN headless testy — v plugine to nikto nevola (guard).
        def reset_for_tests!
          @failures = []
          @announced = false
          true
        end

        private

        def log(msg)
          puts "[NOXUN::Engine] #{msg}"
        rescue StandardError
          nil
        end
      end
    end
  end
end

Noxun::Engine::AppLifecycle::LOADED = true unless Noxun::Engine::AppLifecycle.const_defined?(:LOADED, false)
