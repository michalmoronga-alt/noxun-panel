# frozen_string_literal: true
# Noxun Engine — loader. LEN registracia SketchupExtension + recovery bootstrap.
# Jedine miesto s VERSION (drz v synchro s main.rb).
require 'sketchup.rb'
require 'extensions.rb'

module Noxun
  module Engine
    VERSION = '0.9.24'

    class << self
      # Drzime kvoli UI::Notification (potrebuje registrovany extension objekt).
      attr_accessor :extension
    end
  end
end

# --- D-52a: RECOVERY BOOTSTRAP AKTUALIZACIE -----------------------------------
# Bezi PRED nacitanim stromu (`noxun_engine/main`), lebo strom po pade uprostred
# swapu MOZE CHYBAT — kod, ktory ho oprava, sa z neho nesmie nacitavat. Preto
# tato sekcia zije v loaderi a je UMYSELNE sebestacna: ziadny `Sketchup.*`,
# ziadny modul pluginu, len `File`/`FileUtils`.
#
# Bezny start je jeden `flock`, zapis stopy procesu (`lease`) a pat `File.exist?`
# volani — zanedbatelna rezia.
#
# ZELEZNE PRAVIDLO (Codex #277 P1): STROM NA DISKU MUSI ZODPOVEDAT LOADERU,
# KTORY SA PRAVE VYKONAVA. Recovery bezi ZVNUTRA loadera, ktory SketchUp uz
# nacital — takze „dokoncit dopredu" (nasadit novy loader na disk a pokracovat
# starym kodom nad novym stromom) je ZAKAZANE. Preto:
#   * `.new` strom este stoji  => krok 4 NEPREBEHOL   => vrat STARU generaciu;
#   * `.rb.new` este stoji     => vykonava sa STARY loader => ROLLBACK stromu
#                                 na `.old` (nikdy nie dokoncenie dopredu);
#   * `.old` ostal a `.rb.new` uz nie => vykonava sa NOVY loader => dokonci
#                                 upratanie.
# Rename v ramci jedneho priecinka je atomicky, takze medzistav neexistuje.
# Ked po oprave verzia stromu NESEDI s verziou vykonavaneho loadera, extension
# sa NEZAREGISTRUJE a pouzivatel dostane pokyn restartovat.
#
# ZAMOK (Codex #277 P1, spresnene v kole 2): zamok sa berie VZDY — aj ked na
# disku nie su ziadne artefakty. `apply!` ho drzi uz od chvile, ked len POCITA
# manifest zdroja, teda davno pred vznikom prveho `.new` suboru; boot, ktory by
# sa v tom okne pozrel len na artefakty, by nic nenasiel a updater by mu strom
# vymenil pod rukami. Ked zamok ani po kratkom cakani nepride, plugin sa
# NENACITA. Pod tym istym zamkom si boot zapise aj svoj `lease` — updater tak
# novy proces vidi hned, ako zamok pusti (nie az po nacitani celeho stromu);
# zlyhanie zapisu lease je FAIL-CLOSED a plugin sa tiez nenacita.
#
# Kontrakt s `core/updater.rb`: logika recovery zije LEN TU a modul ju
# NEDUPLIKUJE (guard test `test_d52a_updater.rb` to strazi). Modul pri starte
# aktualizacie iba ODMIETNE bezat, ked marker existuje.
module Noxun
  module Engine
    module Boot
      TREE_NAME   = 'noxun_engine'
      LOADER_NAME = 'noxun_engine.rb'
      MARKER_NAME = 'noxun_engine.update.json'
      LOCK_NAME   = 'noxun_engine.update.lock'

      LOCK_WAIT_SECONDS = 5.0 # kratke bezpecne cakanie na cudziu transakciu
      LOCK_POLL = 0.2
      VERSION_RE = /^[ \t]*VERSION\s*=\s*'([^']*)'/.freeze

      # Vysledok bootu — cita ho koniec tohto suboru (a headless testy).
      class << self
        attr_accessor :status
      end

      BUSY_MESSAGE = 'Noxun Engine sa práve aktualizuje v inom okne SketchUpu. ' \
                     'Zavri toto okno a spusti SketchUp znova, keď aktualizácia dobehne.'
      RESTART_MESSAGE = 'Noxun Engine bol aktualizovaný. Reštartuj SketchUp — ' \
                        'plugin sa v tomto okne zámerne nenačítal.'
      BROKEN_MESSAGE = 'Noxun Engine nedokázal dorovnať nedokončenú aktualizáciu. ' \
                       'Reštartuj SketchUp; ak to nepomôže, spusti INSTALL_noxun_engine.ps1.'
      MARKER_MESSAGE = 'Noxun Engine dorovnal nedokončenú aktualizáciu, ale nedokázal zmazať ' \
                       'stopu po nej (noxun_engine.update.json v priečinku Plugins). Kým tam ' \
                       'leží, ďalšia aktualizácia sa nespustí — zmaž ten súbor alebo oprav ' \
                       'práva k priečinku Plugins.'

      LEASES_DIR = 'noxun_engine.leases'

      LEASE_MESSAGE = 'Noxun Engine si nedokázal zapísať stopu procesu do priečinka Plugins ' \
                      "(#{LEASES_DIR}). Bez nej by aktualizácia nevidela ostatné okná SketchUpu, " \
                      'takže sa plugin zámerne nenačítal — oprav práva k priečinku Plugins.'

      # :idle    — nic sa nedialo (bezny start)
      # :done    — transakcia dorovnana a strom sedi s vykonavanym loaderom
      # :busy    — aktualizacia prave bezi v inom procese
      # :restart — disk je v poriadku, ale NEZODPOVEDA tomuto loaderu
      # :error   — opravu alebo zapis lease sa nepodarilo dokoncit
      #
      # ZAMOK SA BERIE VZDY (Codex #277 kolo 2), aj ked ziadne artefakty na disku
      # nie su: `apply!` drzi zamok uz od chvile, ked len POCITA manifest zdroja
      # — teda DAVNO predtym, nez vznikne prvy `.new` subor. Boot, ktory by sa
      # v tom okne pozrel len na artefakty, by nic nenasiel, nacital strom a
      # updater by mu ho o par sekund vymenil pod rukami.
      #
      # LEASE SA ZAPISUJE TU, na ZACIATKU bootu a POD ZAMKOM — nie az na konci
      # `main.rb`. Updater tak novy proces uvidi hned, ako zamok pusti, a nie az
      # potom, ako doleze cely strom. Zlyhanie zapisu je FAIL-CLOSED: bez lease
      # by nas cudzia aktualizacia nevidela, takze sa plugin radsej nenacita.
      def self.recover!(plugins_dir)
        paths = paths_for(plugins_dir)
        require 'fileutils'
        status = with_lock(paths[:lock]) do
          begin
            done = if pending?(paths)
                     repair!(paths)
                     # Codex #277 kolo 4 (P2): `rm_f` chybu POTLACI. Marker,
                     # ktory prezije, je pritom trvala brzda — kazdy dalsi
                     # `apply!` sa o neho zastavi hlaskou o nedokoncenej
                     # transakcii. Preto sa vysledok OVERUJE na disku.
                     begin
                       FileUtils.rm_f(paths[:marker])
                     rescue StandardError => e
                       puts "[NOXUN::Engine] marker sa neda zmazat: #{e.class}: #{e.message}"
                     end
                     File.exist?(paths[:marker]) ? :marker_stuck : :done
                   else
                     :idle
                   end
            if done == :marker_stuck
              :marker_stuck
            elsif !write_lease!(paths)
              :lease_failed
            elsif generation_matches?(paths)
              done
            else
              # Codex #277 kolo 3 (P1): kontrola bezi VZDY, aj ked na disku uz
              # ziadne artefakty nie su. Presne to je stav po cakani na zamok:
              # cudzi proces medzitym update DOKONCIL a upratal, takze
              # `pending?` je false — ale NAS loader v pamati je stary a strom
              # na disku novy. Bez tejto kontroly by sa zaregistroval nad cudzou
              # generaciou.
              :restart
            end
          rescue StandardError => e
            puts "[NOXUN::Engine] recovery aktualizacie zlyhala: #{e.class}: #{e.message}"
            :error
          end
        end
        puts "[NOXUN::Engine] stav aktualizacie pri starte: #{status}" unless status == :idle
        status
      rescue StandardError => e
        puts "[NOXUN::Engine] recovery aktualizacie zlyhala: #{e.class}: #{e.message}"
        :error
      end

      def self.paths_for(plugins_dir)
        tree = File.join(plugins_dir, TREE_NAME)
        ldr  = File.join(plugins_dir, LOADER_NAME)
        { dir: plugins_dir, tree: tree, tree_new: "#{tree}.new", tree_old: "#{tree}.old",
          ldr: ldr, ldr_new: "#{ldr}.new", ldr_old: "#{ldr}.old",
          marker: File.join(plugins_dir, MARKER_NAME),
          lock: File.join(plugins_dir, LOCK_NAME),
          leases: File.join(plugins_dir, LEASES_DIR) }
      end

      # Stopa ZIVEHO procesu. Format musi ostat zhodny s `Updater.write_lease!`
      # (`<pid>.lease` v `noxun_engine.leases`) — strazi guard test.
      def self.write_lease!(p)
        FileUtils.mkdir_p(p[:leases])
        File.binwrite(File.join(p[:leases], "#{Process.pid}.lease"),
                      %({"std":1,"pid":#{Process.pid},"at":"#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')}"}))
        true
      rescue StandardError => e
        puts "[NOXUN::Engine] lease sa neda zapisat: #{e.class}: #{e.message}"
        false
      end

      def self.pending?(p)
        File.exist?(p[:marker]) || File.exist?(p[:tree_new]) || File.exist?(p[:tree_old]) ||
          File.exist?(p[:ldr_new]) || File.exist?(p[:ldr_old])
      end

      # Zamok drzi bezici `apply!`. Kratko pockame (swap je otazka sekund);
      # ked ho ani potom nedostaneme, je to `:busy` a plugin sa NENACITA.
      def self.with_lock(lock_path)
        File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |f|
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + LOCK_WAIT_SECONDS
          got = false
          loop do
            got = f.flock(File::LOCK_EX | File::LOCK_NB)
            break if got
            break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep(LOCK_POLL)
          end
          return :busy unless got

          begin
            yield
          ensure
            begin
              f.flock(File::LOCK_UN)
            rescue StandardError
              nil
            end
          end
        end
      end

      # Codex #277 kolo 3 (P1): o tom, ci loader na disku uz patri NOVEJ
      # generacii, rozhoduje jeho OBSAH (VERSION), nie pritomnost `.rb.new`.
      # Od kola 3 sa zaloha loadera robi KOPIOU, takze `.rb` existuje v kazdom
      # okamihu a pritomnost suborov by stav nerozlisila spolahlivo.
      def self.repair!(p)
        if Dir.exist?(p[:tree_new])
          keep_old!(p)          # krok 4 neprebehol
        elsif Dir.exist?(p[:tree_old])
          if loader_matches_tree?(p)
            finish_new!(p)      # na disku uz je NOVY loader — dokonci upratanie
          else
            rollback_tree!(p)   # na disku je STARY loader — nikdy nedokoncuj dopredu
          end
        else
          finish_leftovers!(p)
        end
      end

      # Sedi loader NA DISKU so stromom NA DISKU? `nil` verzia (necitatelny
      # subor, chybajuce VERSION) sa berie ako NESEDI — rollback je bezpecnejsi
      # nez dokoncenie dopredu.
      def self.loader_matches_tree?(p)
        lv = version_of(p[:ldr])
        tv = version_of(File.join(p[:tree], 'main.rb'))
        !lv.nil? && !tv.nil? && lv == tv
      end

      def self.version_of(file)
        return nil unless File.file?(file)

        head = File.open(file, 'rb') { |f| f.read(8192) }.to_s
        head.force_encoding(Encoding::UTF_8)[VERSION_RE, 1]
      rescue StandardError
        nil
      end

      # `.new` este stoji => plati STARA generacia (strom aj loader).
      def self.keep_old!(p)
        if Dir.exist?(p[:tree_old])
          rm_quiet(p[:tree]) if Dir.exist?(p[:tree])
          File.rename(p[:tree_old], p[:tree])
        elsif !Dir.exist?(p[:tree])
          # Strom aj `.old` chybaju — jedina kompletna generacia je pripraveny
          # `.new` (validovany pred krokom 3). Nasadi sa, ale tomuto loaderu uz
          # nemusi zodpovedat: `generation_matches?` potom vypyta restart.
          File.rename(p[:tree_new], p[:tree])
          adopt_loader!(p)
          rm_quiet(p[:ldr_old])
          return
        end
        rm_quiet(p[:tree_new])
        rm_quiet(p[:ldr_new])
        restore_loader!(p)
      end

      # Strom uz je NOVY, ale `.rb.new` este ceka => loader v pamati je STARY.
      # Dokoncit dopredu by dalo zakazanu kombinaciu stary loader / novy strom,
      # preto sa strom VRACIA na `.old`.
      def self.rollback_tree!(p)
        if Dir.exist?(p[:tree_old])
          rm_quiet(p[:tree_new])
          File.rename(p[:tree], p[:tree_new]) if Dir.exist?(p[:tree])
          File.rename(p[:tree_old], p[:tree])
          rm_quiet(p[:tree_new])
        end
        rm_quiet(p[:ldr_new])
        restore_loader!(p)
      end

      # `.old` ostal, `.rb.new` uz nie => vykonava sa NOVY loader nad NOVYM
      # stromom. Ostava upratat predchadzajucu generaciu.
      def self.finish_new!(p)
        unless Dir.exist?(p[:tree])
          File.rename(p[:tree_old], p[:tree]) # strom chyba — vrat, co mame
          restore_loader!(p)
          return
        end
        rm_quiet(p[:tree_old])
        rm_quiet(p[:ldr_old])
      end

      # Ziadny `.new` ani `.old` strom — ostal len zvysok po staging/upratovani.
      # Zmieseny stav (loader jednej generacie nad stromom druhej) sa tu este da
      # zachranit, ked `.rb.old` patri k stromu, ktory na disku lezi.
      def self.finish_leftovers!(p)
        rm_quiet(p[:ldr_new])
        File.rename(p[:ldr_old], p[:ldr]) if !File.exist?(p[:ldr]) && File.exist?(p[:ldr_old])
        if !loader_matches_tree?(p) && File.file?(p[:ldr_old]) &&
           version_of(p[:ldr_old]) == version_of(File.join(p[:tree], 'main.rb'))
          File.rename(p[:ldr_old], p[:ldr]) # atomicky prepis, ziadne mazanie
        end
        rm_quiet(p[:ldr_old])
      end

      # Loader STAREJ generacie sa vracia, ked na disku este nie je.
      #
      # Codex #277 kolo 3 (P1): NIC sa pritom NEMAZE. `File.rename` cielovy
      # subor prepise atomicky (Windows MoveFileExW s REPLACE_EXISTING, POSIX
      # rename(2)), takze `Plugins` nie su ani na okamih bez bootovatelneho
      # `noxun_engine.rb`. Ked uz spravny loader na mieste je, nerobi sa nic.
      def self.restore_loader!(p)
        if File.file?(p[:ldr_old]) &&
           (!File.file?(p[:ldr]) || version_of(p[:ldr]) != version_of(p[:ldr_old]))
          File.rename(p[:ldr_old], p[:ldr])
        end
        # Zaloha sa uprace az KED je na mieste pouzitelny loader.
        rm_quiet(p[:ldr_old]) if File.file?(p[:ldr])
      end

      # Nasadenie pripraveneho loadera. Zaloha ide KOPIOU a nova verzia
      # atomickym prepisom — rovnaky dovod ako pri `restore_loader!`.
      def self.adopt_loader!(p)
        return unless File.file?(p[:ldr_new])

        rm_quiet(p[:ldr_old])
        FileUtils.cp(p[:ldr], p[:ldr_old]) if File.file?(p[:ldr])
        File.rename(p[:ldr_new], p[:ldr])
      end

      # Mazanie je KOZMETIKA — zvysok uprace najblizsi boot. Zlyhanie preto
      # NESMIE zhodit strukturalnu opravu (a spravit z pluginu mrtvolu).
      def self.rm_quiet(path)
        FileUtils.rm_rf(path)
        true
      rescue StandardError
        false
      end

      # Sedi strom s loaderom, ktory sa PRAVE VYKONAVA? `Engine::VERSION` je
      # definovana vyssie v tomto subore, takze je to verzia beziaceho kodu.
      # Blokuje sa LEN DOKAZANY nesulad. Ked sa verzia stromu zistit NEDA
      # (chybajuci alebo necitatelny `main.rb`), nie je to dovod nenacitat
      # plugin — o chybajucom strome povie SketchUp sam pri `Sketchup.require`
      # a tvrdy zakaz by z kozmetickej priciny spravil mrtvy plugin.
      def self.generation_matches?(p)
        tv = version_of(File.join(p[:tree], 'main.rb'))
        return true if tv.nil?

        tv == Noxun::Engine::VERSION
      end

      def self.announce(status)
        msg = case status
              when :busy then BUSY_MESSAGE
              when :restart then RESTART_MESSAGE
              when :lease_failed then LEASE_MESSAGE
              when :marker_stuck then MARKER_MESSAGE
              else BROKEN_MESSAGE
              end
        puts "[NOXUN::Engine] #{msg}"
        ::UI.messagebox(msg) if defined?(::UI) && ::UI.respond_to?(:messagebox)
      rescue StandardError
        nil
      end
    end
  end
end

# Stav recovery rozhoduje, ci sa plugin vobec smie nacitat. `:busy` (cudzia
# aktualizacia bezi), `:restart` (strom nesedi s tymto loaderom) a `:error`
# (opravu sa nepodarilo dokoncit) NAcitanie zastavia — inak by SketchUp bezal
# nad zmiesanou generaciou.
Noxun::Engine::Boot.status = Noxun::Engine::Boot.recover!(File.dirname(File.expand_path(__FILE__)))

if %i[busy restart error lease_failed marker_stuck].include?(Noxun::Engine::Boot.status)
  Noxun::Engine::Boot.announce(Noxun::Engine::Boot.status)
else
  module Noxun
    module Engine
      unless defined?(@loaded)
        ex = SketchupExtension.new('Noxun Engine', 'noxun_engine/main')
        ex.description = 'Nabytkarsky system Noxun — parametricke korpusy, zony a cela, materialy a ABS s dekorovymi skupinami, pravidla kovania, kusovnik a VEPO export s kontrolou.'
        ex.version     = VERSION
        ex.creator     = 'Noxun Forge'
        ex.copyright   = 'Noxun Forge © 2026'
        self.extension = ex
        Sketchup.register_extension(ex, true)
        @loaded = true
      end
    end
  end
end
