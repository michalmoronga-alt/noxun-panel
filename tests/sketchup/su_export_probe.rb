# frozen_string_literal: true
# Sonda export testu (davka H19, blok 9 HARDENING): 4 exporty Studia bez okien nad KOPIOU
# zakazky. Nacitava ju `scripts/export_test.ps1` cez boot.rb (-RubyStartup) PRE KAZDY
# beh (K aj P) rovnaka — sonda nie je sucast pluginu a nemeni ho.
#
# Co robi: pocka na init pluginu, nahradi `UI.select_directory` / `UI.savepanel` (vrati
# vystupny priecinok, resp. `priecinok/<navrhnute meno>`; zaznamena startovaci priecinok),
# zlozi `expect` zo servera presne ako okno (`project_name`, `merge_18_36`, `name_source`),
# pri rozpocte a ponuke doplni `confirm_unpriced` podla `unpriced_count`, zavola
# `ProductionCore.do_*` (VEPO, CSV kovania, XLSX rozpoctu, XLSX ponuky) so `status`/`repush`
# do logu, zapise koncovy marker, model zavrie BEZ ulozenia a ukonci SketchUp.
#
# Log (UTF-8, jeden zaznam na riadok): INFO, `STATUS {json}`, `REPUSH {json}`,
# `PICKER {json}`, `FAIL: ...`. Chyba ktoregokolvek exportu (vynimka, ziadny novy subor)
# = `FAIL:` riadok => verdikt skriptu 1. Cervena veta statusu je len udalost na porovnanie.
# Env: NOXUN_EXPORT_OUT (vystupny priecinok), NOXUN_EXPORT_LOG (log), NOXUN_EXPORT_WORK
# (pracovny priecinok behu — poistka: model MUSI lezat v nom, inak sonda nic nevyexportuje).
require 'json'
require 'fileutils'

module NoxunExportProbe
  OUT = ENV['NOXUN_EXPORT_OUT'].to_s
  LOG = ENV['NOXUN_EXPORT_LOG'].to_s
  WORK = ENV['NOXUN_EXPORT_WORK'].to_s
  MARKER = '=== KONIEC SUBORU ==='
  METHODS = %w[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].freeze
  READY_TIMEOUT_S = 120
  POLL_S = 2.0
  GRACE_S = 4.0

  class << self
    def log(msg)
      File.open(LOG, 'a:UTF-8') { |f| f.puts(msg) }
    rescue StandardError
      nil
    end

    def event(kind, hash)
      log("#{kind} #{JSON.generate(hash)}")
    end

    def fail!(msg)
      log("FAIL: #{msg}")
    end

    # Plugin sa inicializuje v casovacoch po otvoreni modelu — cakame na jeho moduly
    # a otvoreny model (prototyp cakal pevnych 8 s).
    def ready?
      e = defined?(Noxun::Engine) ? Noxun::Engine : nil
      m = Sketchup.active_model
      !!(e && defined?(e::ProductionCore) && defined?(e::ExportSettings) && defined?(e::VERSION) &&
         m && !m.path.to_s.empty?)
    end

    def start
      t0 = Time.now
      @timer = UI.start_timer(POLL_S, true) do
        begin
          if ready?
            UI.stop_timer(@timer)
            UI.start_timer(GRACE_S, false) { run }
          elsif Time.now - t0 > READY_TIMEOUT_S
            UI.stop_timer(@timer)
            fail!("plugin sa nenacital do #{READY_TIMEOUT_S} s")
            finish
          end
        rescue StandardError => ex
          UI.stop_timer(@timer)
          fail!("start: #{ex.class}: #{ex.message}")
          finish
        end
      end
    end

    def stub_ui!
      probe = self
      UI.define_singleton_method(:select_directory) do |**kw|
        probe.event('PICKER', m: probe.current, api: 'select_directory', start: kw[:directory].to_s)
        OUT
      end
      UI.define_singleton_method(:savepanel) do |title, start, name|
        probe.event('PICKER', m: probe.current, api: 'savepanel', start: start.to_s, name: name.to_s, title: title.to_s)
        File.join(OUT, name.to_s)
      end
    end

    attr_reader :current

    def unpriced_count(pc, e, model)
      c = pc.send(:fresh_collect, model)
      bud = pc.send(:budget_payload, model, e::Bom.compute(c), c, nil,
                    pc.send(:hardware_expansion, model, c), pc.send(:sheets_map))
      pc.send(:unpriced_count, bud).to_i
    rescue StandardError => ex
      log("WARN: unpriced_count: #{ex.class}: #{ex.message}")
      0
    end

    def out_files
      Dir.glob('**/*', base: OUT).select { |p| File.file?(File.join(OUT, p)) }.sort
    end

    def run
      e = Noxun::Engine
      pc = e::ProductionCore
      es = e::ExportSettings
      model = Sketchup.active_model
      log("INFO: SketchUp #{Sketchup.version}, plugin #{e::VERSION}, model #{model.path}")
      unless !WORK.empty? && model.path.tr('\\', '/').start_with?(WORK.tr('\\', '/'))
        fail!("model nelezi v pracovnom priecinku behu (#{WORK}) - sonda nic neexportuje")
        return
      end
      stub_ui!
      project = es.project_name(model).to_s
      expect = { 'project' => project, 'merge' => es.merge_18_36, 'source' => es.name_source(model, project) }
      log("INFO: expect #{expect.inspect}")
      unpriced = unpriced_count(pc, e, model)
      log("INFO: unpriced #{unpriced}")
      METHODS.each { |m| run_export(pc, model, m, expect, unpriced) }
    rescue StandardError => ex
      fail!("sonda: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    ensure
      finish
    end

    def run_export(pc, model, name, expect, unpriced)
      @current = name
      before = out_files
      data = { 'gen' => 1, 'expect' => expect }
      data['confirm_unpriced'] = unpriced if unpriced > 0 && %w[do_budget_xlsx do_cp_xlsx].include?(name)
      # Cervena veta NIE JE chyba sondy (napr. „+ 3 nemapovane" pri uspesnom exporte) —
      # zapisuje sa a porovnava s druhou stranou ako kazda veta statusu.
      st = lambda do |msg, err = false|
        event('STATUS', m: name, err: err ? true : false, msg: msg.to_s)
      end
      rp = -> { event('REPUSH', m: name) }
      pc.send(name, model, data, generation: 1, status: st, repush: rp)
      fail!("#{name}: export nevytvoril ziadny subor") if (out_files - before).empty?
    rescue StandardError => ex
      fail!("#{name}: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    end

    # Marker je BRANA skriptu; model sa zavrie bez ulozenia (kopia, nic sa nezapisuje)
    # a SketchUp sa ukonci sam — proces nikto nezabija.
    def finish
      return if @finished

      @finished = true
      log(MARKER)
      UI.start_timer(3.0, false) do
        begin
          Sketchup.active_model.close(true)
        rescue StandardError
          nil
        end
        UI.start_timer(1.5, false) { Sketchup.quit }
      end
    end
  end
end

NoxunExportProbe.start
