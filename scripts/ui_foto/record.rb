# frozen_string_literal: true
# Noxun Engine — NAHRAVKA Ruby->JS pre fotenie okien (scripts/ui_foto.ps1 -Record).
# NIE je sucast pluginu a do pluginu sa nenasadzuje. Spusta ho boot.rb, ktory
# vygeneruje ui_foto.ps1, cez `SketchUp.exe -RubyStartup boot.rb <KOPIA ENGINEtests.skp>`
# (overena slucka ako scripts/run_su_tests.ps1).
#
# Co robi (retaz UI.start_timer — medzi krokmi sa vracia riadenie SketchUpu, inak
# by nedobehli callbacky okien; `sleep` by ich zablokoval):
#   1. guard modelu (LEN ENGINEtests*.skp alebo neulozeny model bez NOXUN objektov),
#   2. na kopii modelu zmaze NOXUN skrinky/dosky a postavi ukazkovu kuchynu zo
#      sablon (4 dolne + 3 horne; chybajuca sablona -> nahradna podla typu),
#   3. obrazok modelu (model.png),
#   4. zapne zaznam `UI::HtmlDialog#execute_script` (prepend LEN v tejto instancii)
#      — kazdy skript Inspectora/Studia ide surovymi bajtmi do NNNN_<panel|studio>.js
#      (File.binwrite, NIE to_json: to_json pokazilo diakritiku), znacky
#      NNNN_mark_<nazov>.txt pred kazdym krokom: panel_open, panel_select_cab1,
#      studio_<sekcia> pre KAZDU sekciu StudioDialog::SECTIONS, end,
#   5. index.json (zoznam suborov) + meta.json, vysledok do NOXUN_UIFOTO_RESULT
#      s koncovym markerom; potom ulozi RUN-KOPIU modelu a ukonci SketchUp sam
#      (vzor -CloseWhenDone runnera; proces nikto nezabija).
require 'json'
require 'fileutils'

module NoxunUiFoto
  REC = ENV['NOXUN_UIFOTO_REC'].to_s
  RESULT = ENV['NOXUN_UIFOTO_RESULT'].to_s
  MARKER = '=== KONIEC SUBORU ==='
  # Ukazkova kuchyna (prototyp auditu 1.10.2026): [kandidati mena sablony, typ, sirka mm alebo nil].
  # Prve meno = sablona z realnej kniznice, dalsie = vstavany seed (-FactoryData).
  KITCHEN = [
    [['Drezová + šuflik', 'Drezova'], 'lower', 800.0],
    [['Umývačka 60'], 'lower', nil],
    [['Varná 3 šuflík', 'Varna doska'], 'lower', 600.0],
    [['Dolna klasik'], 'lower', 400.0],
    [['Horna klasik'], 'upper', 800.0],
    [['Horna klasik'], 'upper', 600.0],
    [['Horná základ', 'Horna klasik'], 'upper', 600.0]
  ].freeze
  BODY_MAT = 'W1100_ST30_DTDL_18'
  FRONT_MAT = 'F206_ST9_DTDL_18'
  FIRST_STUDIO_WAIT = 10.0 # prve otvorenie Studia: nacitanie HTML + velky push
  STEP_WAIT = 5.0          # dalsie sekcie (lenive doplnky: katalog kovania, nahlady sablon)

  @seq = 0
  @on = false
  @guard_ok = false
  @kitchen = []
  @cab1 = nil

  class << self
    def e
      Noxun::Engine
    end

    def line(text)
      File.open(RESULT, 'a') { |f| f.puts(text) }
    rescue StandardError
      nil
    end

    def info(text)
      line("INFO: #{text}")
    end

    def bad(text)
      line("FAIL: #{text}")
    end

    # --- zaznam -----------------------------------------------------------
    def dialog_kind(dlg)
      return 'panel' if defined?(e::Panel) && dlg.equal?(e::Panel.instance_variable_get(:@dialog))
      return 'studio' if defined?(e::StudioDialog) && dlg.equal?(e::StudioDialog.instance_variable_get(:@dialog))

      nil
    end

    def capture(dlg, script)
      return unless @on

      kind = dialog_kind(dlg)
      return unless kind

      @seq += 1
      File.binwrite(File.join(REC, format('%04d_%s.js', @seq, kind)), script.to_s.b)
    end

    def mark(name)
      @seq += 1
      File.binwrite(File.join(REC, format('%04d_mark_%s.txt', @seq, name)), name.to_s)
    end

    # --- retaz krokov -----------------------------------------------------
    def start
      File.write(RESULT, "MARKER START #{Time.now} (ui_foto record)\n")
      FileUtils.mkdir_p(REC)
      steps = [
        [1.0, -> { step_guard }],
        [1.0, -> { step_build }],
        [1.0, -> { step_model_image }],
        [7.0, -> { step_panel_open }],
        [5.0, -> { step_select }]
      ]
      sections.each_with_index do |s, i|
        steps << [i.zero? ? FIRST_STUDIO_WAIT : STEP_WAIT, -> { step_section(s) }]
      end
      steps << [2.0, -> { step_finish }]
      UI.start_timer(3.0, false) { run_step(steps, 0) }
    rescue StandardError => ex
      bad("start: #{ex.class}: #{ex.message}")
      end_and_close
    end

    # Koncovy marker + samozatvorenie VZDY spolu (Codex #434 P2): po markeri ui_foto.ps1
    # zmaze sentinel a uvolni deploy.lock — instancia, ktora by po chybe ostala zit,
    # by uz dalsiemu deployu nebranila. Pouziva ju kazda cesta, ktora marker pise.
    def end_and_close
      line(MARKER)
      return if @closing

      @closing = true
      begin
        UI.start_timer(2.0, false) { close_and_quit }
      rescue StandardError
        quit_now
      end
    end

    def run_step(steps, idx)
      return if idx >= steps.length

      wait, step = steps[idx]
      res = begin
        step.call
      rescue StandardError => ex
        bad("krok #{idx + 1}: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
        nil
      end
      if res == :abort
        step_finish
        return
      end
      UI.start_timer(wait, false) { run_step(steps, idx + 1) }
    end

    def sections
      defined?(e::StudioDialog::SECTIONS) ? e::StudioDialog::SECTIONS : []
    end

    def guard_model?(model)
      path = model ? model.path.to_s : ''
      base = path.tr('\\', '/').downcase.split('/').last.to_s
      return true if base.start_with?('enginetests')

      path.empty? && owners(model).empty?
    end

    def owners(model)
      out = []
      e::Ids.each_cabinet(model) { |i| out << i }
      e::Ids.each_board(model) { |i| out << i }
      out
    end

    def step_guard
      unless defined?(Noxun::Engine::CabinetBuilder)
        bad('Noxun Engine nie je nacitany')
        return :abort
      end
      model = Sketchup.active_model
      unless guard_model?(model)
        bad("nespravny model ('#{model && model.path}') — nahravka sa NEROBI (len ENGINEtests*.skp)")
        return :abort
      end
      @guard_ok = true
      info("verzia pluginu #{e::VERSION}, model '#{File.basename(model.path.to_s)}'")
      e::Panel.hide if e::Panel.respond_to?(:hide)
      e::StudioDialog.hide if e::StudioDialog.respond_to?(:hide)
      nil
    end

    def find_template(names, type)
      list = e::TemplateStore.load.select { |t| t['kind'] == 'cabinet' }
      names.each do |n|
        hit = list.find { |t| t['name'] == n }
        return hit if hit
      end
      list.find { |t| t['config'].is_a?(Hash) && t['config']['type'].to_s == type }
    end

    def material?(id)
      !e::Materials.sheet(id).nil?
    rescue StandardError
      false
    end

    def step_build
      model = Sketchup.active_model
      old = owners(model)
      unless old.empty?
        model.start_operation('ui_foto: upratanie kopie', true)
        old.each { |i| i.erase! if i.valid? }
        model.commit_operation
        info("zmazanych NOXUN objektov v kopii modelu: #{old.length}")
      end
      x = { 'lower' => 0.0, 'upper' => 0.0 }
      body = material?(BODY_MAT) ? BODY_MAT : nil
      front = material?(FRONT_MAT) ? FRONT_MAT : nil
      KITCHEN.each do |names, type, width|
        tpl = find_template(names, type)
        cfg = tpl ? JSON.parse(JSON.generate(tpl['config'])) : { 'type' => type, 'width' => width || 600.0 }
        cfg['width'] = width if width
        cfg['material_id'] = body if body
        cfg['front_material_id'] = front if front
        z = cfg['type'].to_s == 'upper' ? e::CabinetBuilder::UPPER_HANG_Z : 0.0
        key = cfg['type'].to_s == 'upper' ? 'upper' : 'lower'
        tr = Geom::Transformation.translation(e::Units.point(x[key], 0.0, z))
        begin
          inst = e::CabinetBuilder.build(model, cfg, transform: tr)
          @cab1 ||= inst
          @kitchen << "#{tpl ? tpl['name'] : "(bez sablony #{type})"} #{cfg['width'].to_f.round}"
        rescue StandardError => ex
          bad("skrinka #{names.first}: #{ex.class}: #{ex.message}")
        end
        x[key] += cfg['width'].to_f
      end
      info("kuchyna: #{@kitchen.join(' · ')} (korpus #{body || 'predvolba'}, cela #{front || 'predvolba'})")
      nil
    end

    def step_model_image
      model = Sketchup.active_model
      view = model.active_view
      bb = model.bounds
      unless bb.empty?
        d = bb.diagonal
        target = bb.center
        eye = target.offset(Geom::Vector3d.new(-0.55 * d, -1.25 * d, 0.6 * d))
        view.camera = Sketchup::Camera.new(eye, target, Geom::Vector3d.new(0, 0, 1))
        view.zoom_extents
      end
      ok = view.write_image(filename: File.join(REC, 'model.png'), width: 1400, height: 900,
                            antialias: true, transparent: false)
      info("obrazok modelu: #{ok ? 'model.png' : 'ZLYHAL (pokracujem)'}")
      nil
    rescue StandardError => ex
      info("obrazok modelu: #{ex.class}: #{ex.message} (pokracujem)")
      nil
    end

    def step_panel_open
      model = Sketchup.active_model
      model.selection.clear
      @on = true
      mark('panel_open')
      e::Panel.show
      nil
    end

    def step_select
      model = Sketchup.active_model
      mark('panel_select_cab1')
      model.selection.clear
      model.selection.add(@cab1) if @cab1 && @cab1.valid?
      bad('panel_select_cab1: ziadna skrinka na vyber') unless @cab1
      nil
    end

    def step_section(section)
      mark("studio_#{section}")
      e::StudioDialog.show(open_section: section)
      nil
    end

    def step_finish
      return if @finished

      @finished = true
      if @guard_ok
        mark('end')
        @on = false
        files = Dir.children(REC).select { |f| f =~ /\A\d+_/ }.sort
        File.binwrite(File.join(REC, 'index.json'), JSON.generate(files))
        n_panel = files.count { |f| f.end_with?('_panel.js') }
        n_studio = files.count { |f| f.end_with?('_studio.js') }
        meta = { 'version' => e::VERSION, 'time' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
                 'model' => File.basename(Sketchup.active_model.path.to_s), 'kitchen' => @kitchen,
                 'sections' => sections, 'files' => files.length, 'panel_scripts' => n_panel,
                 'studio_scripts' => n_studio }
        File.binwrite(File.join(REC, 'meta.json'), JSON.pretty_generate(meta))
        info("nahravka: #{files.length} suborov (panel #{n_panel}, studio #{n_studio}) -> #{REC}")
        bad('nahravka nema ziadny skript Inspectora') if n_panel.zero?
        bad('nahravka nema ziadny skript Studia') if n_studio.zero?
      end
      end_and_close
    rescue StandardError => ex
      bad("finish: #{ex.class}: #{ex.message}")
      end_and_close
    end

    # --- samozatvorenie (vzor -CloseWhenDone v scripts/run_su_tests.ps1) ---
    def close_and_quit
      e::Panel.hide if defined?(e::Panel) && e::Panel.respond_to?(:hide)
      e::StudioDialog.hide if defined?(e::StudioDialog) && e::StudioDialog.respond_to?(:hide)
      model = Sketchup.active_model
      saved = false
      if @guard_ok && model && !model.path.to_s.empty?
        begin
          saved = model.save ? true : false
        rescue StandardError
          saved = false
        end
      end
      model.close(true) if model && !saved && @guard_ok
      UI.start_timer(1.0, false) { quit_now }
    rescue StandardError
      UI.start_timer(1.0, false) { quit_now }
    end

    def quit_now
      model = Sketchup.active_model
      if model && model.modified? && @guard_ok
        begin
          model.save(File.join(File.dirname(RESULT), 'closing_stub.skp'))
        rescue StandardError
          nil
        end
      end
      Sketchup.quit
    rescue StandardError
      Sketchup.quit
    end
  end
end

# Zaznam Ruby->JS: prepend LEN v tejto (testovacej) instancii SketchUpu.
module NoxunUiFotoHook
  def execute_script(script)
    begin
      NoxunUiFoto.capture(self, script)
    rescue StandardError
      nil
    end
    super
  end
end
UI::HtmlDialog.prepend(NoxunUiFotoHook) unless UI::HtmlDialog.ancestors.include?(NoxunUiFotoHook)

NoxunUiFoto.start
