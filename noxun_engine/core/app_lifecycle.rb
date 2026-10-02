# frozen_string_literal: true
# Noxun Engine — zivotny cyklus pluginu v procese SketchUpu (H11a, F-01).
#
# DVE ULOHY, OBE CISTY RUBY:
#
# 1) UKONCOVANIE SKETCHUPU. SketchUp vola `set_on_closed` okien aj pri ukonceni
#    aplikacie a v 2026.2 `pop_tool` z takeho hooku konci padom (#1117). Jediny
#    oficialny signal ukoncovania je `AppObserver#onQuit` a poradie voci oknam
#    SketchUp negarantuje — na 26.0.429 (quit test H11a) prisli hooky okien PRED
#    `onQuit` (poradie B), takze priznak ich pri ukonceni NEzachyti (uzaver F-01
#    rozhodne overenie na 2026.2, H11c). `onQuit` preto LEN zdvihne
#    priznak; hooky okien pri nom NEvolaju SketchUp API — zneplatnia stav
#    v Ruby a skutocne upratanie (observery, prekrytie, pop nastroja) odlozia.
#    Ak sa ukaze, ze SketchUp bezi dalej (okno pluginu sa otvorilo, klik alebo
#    Esc v sirotskom nastroji), `confirm_running!` priznak zhodi a odlozene
#    upratanie dokonci. Ziadna ina udalost beh nepotvrdzuje.
#
# 2) NACITANIE SUBOROV PLUGINU. `require_part` nacita vnutorny subor Ruby
#    `require` s ABSOLUTNOU cestou — rovnaka semantika na 2026.0 aj 2026.2
#    (`Sketchup.require` chyby do 2026.1 prehltne, od 2026.2 ich prepusti).
#    Chyba sa zapise a pokracuje sa dalsim suborom (diagnostika celeho
#    rozsahu); `main.rb` potom init NESPUSTI a ukaze JEDNU hlasku. Jedina
#    podporovana obnova = restart SketchUpu. Plugin sa NESIFRUJE (ziadne
#    `.rbe`/`.rbs` — Ruby `require` by ich nevedel nacitat; guard test).
#    Chyba samotneho `main.rb` ostava v rezii SketchUpu (kontrakt sa tyka
#    suborov nacitanych z validneho `main.rb`).
#
# Tento subor sa nacitava AKO PRVY (bootstrap v `main.rb` s vlastnou chybovou
# vetvou) — preto nesmie zavisiet od ziadneho ineho suboru pluginu. Posledny
# riadok je sentinel `LOADED`: dokaz, ze sa subor vykonal cely.

module Noxun
  module Engine
    module AppLifecycle
      TRACE_MAX = 50
      BACKTRACE_LINES = 6
      # Koren `Plugins` (tento subor je `<Plugins>/noxun_engine/core/`).
      PLUGINS_ROOT = File.expand_path('../..', __dir__)
      QUIT_OBSERVER_LABEL = 'sledovanie ukončenia SketchUpu (quit observer)'

      class << self
        # LEN testy (in-SU quit test): kam sa okrem pamate zapisuje stopa.
        # V produkcii `nil` — ziadne IO pocas ukoncovania.
        attr_accessor :trace_sink

        # --- ukoncovanie -----------------------------------------------------

        def quitting?
          @quitting == true
        end

        # Vola LEN `QuitObserver#onQuit`: cisty Ruby stav + riadok konzoly.
        def mark_quitting!(source)
          @quitting = true
          @quit_source = source.to_s
          log("ukončovanie SketchUpu (#{@quit_source}) — okná pluginu sa pri zatvorení SketchUpu nedotknú")
          true
        end

        # Udalost, ktora pri ukoncovani NEPRIDE, dokazala, ze SketchUp bezi.
        # `sync: true` = odlozene bloky hned (otvorenie okna — mimo Tool
        # callbacku); `sync: false` = cez timer (klik/Esc v nastroji — z Tool
        # callbacku sa `pop_tool` volat nesmie). Bez priznaku nerobi nic.
        def confirm_running!(reason, sync: true)
          return false unless quitting?

          @quitting = false
          log("SketchUp beží ďalej (#{reason}) — dokončujem odložené upratanie okien")
          trace("running:#{reason}")
          blocks = deferred
          @deferred = []
          if sync
            run_deferred(blocks)
          else
            ::UI.start_timer(0, false) { run_deferred(blocks) }
          end
          true
        rescue StandardError => e
          log("confirm_running!: #{e.class}: #{e.message}")
          false
        end

        # Pri ukoncovani ulozi blok (SketchUp API v nom pocka na potvrdeny beh);
        # inak ho hned vykona. Stopa: `deferred:skip:<label>` = odlozene,
        # `deferred:run:<label>` = vykonane.
        def defer_until_running(label, &blk)
          return false unless blk

          if quitting?
            deferred << [label.to_s, blk]
            trace("deferred:skip:#{label}")
          else
            run_deferred([[label.to_s, blk]])
          end
          true
        end

        def deferred_labels
          deferred.map(&:first)
        end

        # Pamat poslednych TRACE_MAX udalosti + volitelny testovaci sink.
        # Chyba sinku je UPLNE izolovana (tok sa nemeni).
        def trace(event)
          ev = event.to_s
          (@trace ||= []) << ev
          @trace.shift while @trace.length > TRACE_MAX
          sink = @trace_sink
          if sink
            begin
              sink.call(ev)
            rescue StandardError
              nil
            end
          end
          ev
        end

        def trace_events
          (@trace ||= []).dup
        end

        # --- quit observer ---------------------------------------------------

        # Presne JEDNA registracia na proces. Ked je drzany observer uz
        # uspesne pridany, vrati sa bez novej registracie. Vymena observera
        # (iny objekt) najprv odpoji stary — ked sa to nepodari, aktivacia
        # sa ZASTAVI (dva observery = dve `onQuit`). Kazde zlyhanie = chyba
        # startu, `main.rb` potom init nespusti.
        def install!(app: default_app, observer: nil)
          return true if @observer_added && (observer.nil? || observer.equal?(@observer))

          obs = observer || @observer || new_quit_observer
          return startup_failed!(QUIT_OBSERVER_LABEL, 'SketchUp nemá AppObserver') if app.nil? || obs.nil?

          if @observer_added && @observer && !@observer.equal?(obs)
            removed = app.remove_observer(@observer)
            return startup_failed!(QUIT_OBSERVER_LABEL, 'predošlý observer sa nepodarilo odpojiť') unless removed

            @observer_added = false
          end
          return startup_failed!(QUIT_OBSERVER_LABEL, 'SketchUp observer neprijal') unless app.add_observer(obs)

          @observer = obs
          @observer_added = true
          true
        rescue StandardError => e
          startup_failed!(QUIT_OBSERVER_LABEL, "#{e.class}: #{e.message}")
        end

        def observer_installed?
          @observer_added == true
        end

        # --- nacitanie suborov -------------------------------------------------

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
          if first['startup']
            "Noxun Engine sa nespustil — #{first['path']} sa nepodarilo zaregistrovať. " \
              'Plugin je v tomto okne SketchUpu vypnutý. Podrobnosti sú v Ruby konzole. ' \
              'Reštartuj SketchUp; ak to nepomôže, nainštaluj plugin znova.'
          else
            "Noxun Engine sa nenačítal celý — chyba v súbore #{first['path']}.rb (spolu #{failures.length}). " \
              'Plugin je v tomto okne SketchUpu vypnutý, aby nepracoval s chýbajúcimi časťami. ' \
              'Podrobnosti sú v Ruby konzole. Reštartuj SketchUp; ak to nepomôže, nainštaluj plugin znova.'
          end
        end

        # LEN testy (headless a in-SU sada) — v plugine to nikto nevola (guard).
        # `boot: true` zahodi aj stav nacitania a registraciu observera.
        def reset_for_tests!(boot: false)
          @quitting = false
          @quit_source = nil
          @deferred = []
          @trace = []
          @trace_sink = nil
          return true unless boot

          @failures = []
          @announced = false
          @observer = nil
          @observer_added = false
          true
        end

        private

        def deferred
          @deferred ||= []
        end

        def run_deferred(blocks)
          blocks.each do |label, blk|
            trace("deferred:run:#{label}")
            begin
              blk.call
            rescue StandardError => e
              log("odložené upratanie #{label}: #{e.class}: #{e.message}")
            end
          end
        end

        def startup_failed!(what, detail)
          failures << { 'path' => what.to_s, 'class' => 'StartupError', 'message' => detail.to_s,
                        'backtrace' => [], 'startup' => true }
          log("CHYBA štartu: #{what} — #{detail}")
          false
        end

        def default_app
          defined?(::Sketchup) ? ::Sketchup : nil
        end

        def new_quit_observer
          defined?(QuitObserver) ? QuitObserver.new : nil
        end

        def log(msg)
          puts "[NOXUN::Engine] #{msg}"
        rescue StandardError
          nil
        end
      end

      # LEN Ruby stav — ziadne SketchUp API, timer, okno ani subor (FIX 4).
      if defined?(::Sketchup::AppObserver)
        class QuitObserver < ::Sketchup::AppObserver
          def onQuit # rubocop:disable Naming/MethodName — SketchUp API
            AppLifecycle.mark_quitting!('onQuit')
            AppLifecycle.trace('on_quit')
          rescue StandardError => e
            puts "[NOXUN::Engine] onQuit: #{e.class}: #{e.message}"
          end
        end
      end
    end
  end
end

Noxun::Engine::AppLifecycle::LOADED = true unless Noxun::Engine::AppLifecycle.const_defined?(:LOADED, false)
