# frozen_string_literal: true
# Noxun Engine — loader. LEN registracia SketchupExtension + recovery bootstrap.
# Jedine miesto s VERSION (drz v synchro s main.rb).
require 'sketchup.rb'
require 'extensions.rb'

module Noxun
  module Engine
    VERSION = '0.9.5'

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
# Ked nie je co robit (bezny start), su to PIAT stat volania a koniec — nulova
# rezia. Ked transakcia ostala nedokoncena, dorobi sa ALEBO vrati posledna
# KOMPLETNA generacia — VZDY strom AJ loader spolu (novy strom so starym
# loaderom je zakazany stav: `main.rb` fallback by hlasil staru verziu nad
# novym kodom).
#
# ROZHODUJE STAV DISKU, marker je len sprievodka:
#   * existuje `noxun_engine.new`  => krok 4 (nasadenie noveho stromu) NEPREBEHOL
#     => vracia sa STARA generacia;
#   * existuje `noxun_engine.old` a `.new` uz NIE => krok 4 PREBEHOL
#     => transakcia sa DOKONCI (loader + upratanie).
# Rename v ramci jedneho priecinka je atomicky, takze medzistav neexistuje.
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

      def self.recover!(plugins_dir)
        tree     = File.join(plugins_dir, TREE_NAME)
        tree_new = "#{tree}.new"
        tree_old = "#{tree}.old"
        ldr      = File.join(plugins_dir, LOADER_NAME)
        ldr_new  = "#{ldr}.new"
        ldr_old  = "#{ldr}.old"
        marker   = File.join(plugins_dir, MARKER_NAME)

        return false unless File.exist?(marker) || File.exist?(tree_new) ||
                            File.exist?(tree_old) || File.exist?(ldr_new) ||
                            File.exist?(ldr_old)

        require 'fileutils'
        # Ten isty zamok, aky drzi `Updater.apply!` — ked prave bezi swap v inom
        # procese, recovery sa NEPLETIE (a necaka).
        File.open(File.join(plugins_dir, LOCK_NAME), File::RDWR | File::CREAT, 0o644) do |f|
          return false unless f.flock(File::LOCK_EX | File::LOCK_NB)

          begin
            repair!(tree, tree_new, tree_old, ldr, ldr_new, ldr_old)
            FileUtils.rm_f(marker)
          ensure
            begin
              f.flock(File::LOCK_UN)
            rescue StandardError
              nil
            end
          end
        end
        puts '[NOXUN::Engine] nedokoncena aktualizacia dorovnana pri starte'
        true
      rescue StandardError => e
        puts "[NOXUN::Engine] recovery aktualizacie zlyhala: #{e.class}: #{e.message}"
        false
      end

      def self.repair!(tree, tree_new, tree_old, ldr, ldr_new, ldr_old)
        if Dir.exist?(tree_new) && (Dir.exist?(tree) || Dir.exist?(tree_old))
          keep_old!(tree, tree_new, tree_old, ldr, ldr_new, ldr_old)
        elsif Dir.exist?(tree_new)
          adopt_new!(tree, tree_new, ldr, ldr_new, ldr_old)
        elsif Dir.exist?(tree_old)
          if Dir.exist?(tree)
            keep_new!(tree, tree_old, ldr, ldr_new, ldr_old)
          else
            restore_old!(tree, tree_old, ldr, ldr_new, ldr_old)
          end
        else
          finish!(ldr, ldr_new, ldr_old)
        end
      end

      # `.new` este stoji => swap sa NEDOSTAL za krok 4. Plati STARA generacia.
      def self.keep_old!(tree, tree_new, tree_old, ldr, ldr_new, ldr_old)
        FileUtils.rm_rf(tree_new)
        if Dir.exist?(tree_old)
          FileUtils.rm_rf(tree) if Dir.exist?(tree)
          File.rename(tree_old, tree)
        end
        FileUtils.rm_f(ldr_new)
        restore_loader!(ldr, ldr_old)
      end

      # Strom aj `.old` chybaju — jedina KOMPLETNA generacia je pripraveny `.new`
      # (bol validovany pred krokom 3). Bez neho by plugin nemal co nacitat.
      def self.adopt_new!(tree, tree_new, ldr, ldr_new, ldr_old)
        File.rename(tree_new, tree)
        if File.exist?(ldr_new)
          FileUtils.rm_f(ldr_old)
          File.rename(ldr, ldr_old) if File.exist?(ldr)
          File.rename(ldr_new, ldr)
        end
        FileUtils.rm_f(ldr_old)
      end

      # Novy strom uz stoji na mieste => transakcia sa DOKONCI.
      def self.keep_new!(tree, tree_old, ldr, ldr_new, ldr_old)
        if File.exist?(ldr_new)
          FileUtils.rm_f(ldr_old)
          File.rename(ldr, ldr_old) if File.exist?(ldr)
          File.rename(ldr_new, ldr)
        elsif !File.exist?(ldr)
          # Nova generacia nema loader a `.rb.new` uz nie je — nedokoncitelna.
          # Vracia sa CELA stara generacia (strom aj loader).
          FileUtils.rm_rf(tree)
          File.rename(tree_old, tree)
          File.rename(ldr_old, ldr) if File.exist?(ldr_old)
          return
        end
        FileUtils.rm_rf(tree_old)
        FileUtils.rm_f(ldr_old)
      end

      # Strom zmizol, `.new` nie je — vracia sa STARA generacia.
      def self.restore_old!(tree, tree_old, ldr, ldr_new, ldr_old)
        File.rename(tree_old, tree)
        FileUtils.rm_f(ldr_new)
        restore_loader!(ldr, ldr_old)
      end

      # Ziadny `.new` ani `.old` strom — ostal len zvysok po staging/upratovani.
      def self.finish!(ldr, ldr_new, ldr_old)
        FileUtils.rm_f(ldr_new)
        File.rename(ldr_old, ldr) if !File.exist?(ldr) && File.exist?(ldr_old)
        FileUtils.rm_f(ldr_old)
      end

      # Loader STAREJ generacie sa vracia VZDY, ked existuje — inak by nad
      # vratenym starym stromom ostal novy loader (zakazany zmieseny stav).
      def self.restore_loader!(ldr, ldr_old)
        return unless File.exist?(ldr_old)

        FileUtils.rm_f(ldr)
        File.rename(ldr_old, ldr)
      end
    end
  end
end

Noxun::Engine::Boot.recover!(File.dirname(File.expand_path(__FILE__)))

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
