# frozen_string_literal: true
# Noxun Engine — QUIT TEST (H11a, F-01, package H11 §A6; nastroj pre H11c).
# Spusta ho `scripts\run_su_tests.ps1 -QuitProbe [-QuitMenu]` namiesto celej
# sady (su_runner.rb):
#
#   kopia ENGINEtests.skp -> Inspector + Studio otvorene -> ghost visi na kurzore
#   -> stopa do `quit_trace.txt` cez VOPRED otvoreny handle -> ulozenie run-kopie
#   -> `Sketchup.quit` (s -QuitMenu Subor > Koniec, `send_action` 57665).
#
# Instrumentacia zije VYHRADNE v tejto sonde (plugin ziadnu stopu nema): vlastny
# `AppObserver#onQuit` -> `on_quit`; obal `Panel.detach_observer` ->
# `hook:inspector:normal` a `StudioDialog.detach_stale_observer` ->
# `hook:studio:normal` (prvy krok hookov `set_on_closed`); obal
# `GhostTool.pop_tool` -> `pop:executed`. IO pocas ukoncovania je priznana
# testovacia vynimka (D3). PowerShell PO zaniku procesu vypise ZAZNAM (exit kod,
# poradie A/B, stopa) — nie branu; kriteria PASS/FAIL pre Z1 prepise H11c.
# Na 26.0.429 (H11a) hooky oboch okien prisli PRED on_quit (poradie B) cez
# `Sketchup.quit` aj Subor > Koniec, exit 0.
#
# BEZPECNOST: bezi VYHRADNE nad kopiou ENGINEtests*.skp (inak nic nerobi a NEukonci).

module NoxunQuitProbe
  OUT = ENV['NOXUN_SU_OUT'].to_s
  TRACE = ENV['NOXUN_QUIT_TRACE'].to_s
  MARKER = '=== KONIEC SUBORU ==='
  GHOST_PARAMS = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0 }.freeze

  # Vlastny observer sondy — LEN zapis udalosti (handle je otvoreny vopred).
  class QuitWatch < Sketchup::AppObserver
    def onQuit # rubocop:disable Naming/MethodName — SketchUp API
      NoxunQuitProbe.trace('on_quit')
    end
  end

  module PanelHook
    def detach_observer(*args, &blk)
      NoxunQuitProbe.trace('hook:inspector:normal')
      super
    end
  end

  module StudioHook
    def detach_stale_observer(*args, &blk)
      NoxunQuitProbe.trace('hook:studio:normal')
      super
    end
  end

  module PopHook
    def pop_tool(*args, &blk)
      r = super
      NoxunQuitProbe.trace('pop:executed') if r
      r
    end
  end

  module_function

  def e
    Noxun::Engine
  end

  def line(msg)
    File.open(OUT, 'a') { |f| f.puts(msg) }
  rescue StandardError
    nil
  end

  def finish(msg = nil)
    line(msg) if msg
    line(MARKER)
  end

  # Zapis cez vopred otvoreny handle; kazda chyba je izolovana.
  def trace(ev)
    fh = @fh
    fh.write("#{ev}\n") if fh && @armed
  rescue StandardError
    nil
  end

  def guard_model?(model)
    base = model ? model.path.to_s.tr('\\', '/').downcase.split('/').last.to_s : ''
    base.start_with?('enginetests')
  end

  def start
    File.write(OUT, "MARKER START #{Time.now} (su_quit_probe)\n")
    unless defined?(Noxun::Engine::Panel) && defined?(Noxun::Engine::GhostTool)
      return finish('FAIL: quit probe: plugin nie je nacitany — test nebezal')
    end

    model = Sketchup.active_model
    return finish("FAIL: quit probe: nespravny model '#{model && model.path}' — NEukoncujem") unless guard_model?(model)

    line("INFO: quit probe v SketchUpe #{Sketchup.version}, plugin #{e::VERSION}")
    UI.start_timer(2.0, false) { setup(model) }
  rescue StandardError => ex
    finish("FAIL: quit probe start: #{ex.class}: #{ex.message}")
  end

  def setup(model)
    e.reset_restart_latch! if e.respond_to?(:reset_restart_latch!)
    e::Panel.show
    e::StudioDialog.show
    payload = GHOST_PARAMS.merge('model_guid' => e::Panel.model_guid(model)).to_json
    e::Panel.handle_insert(payload)
    UI.start_timer(3.0, false) { arm_and_quit(model) }
  rescue StandardError => ex
    finish("FAIL: quit probe setup: #{ex.class}: #{ex.message}")
  end

  def arm_and_quit(model)
    ready = e::Panel.dialog_alive? && e::StudioDialog.dialog_alive? &&
            !e::GhostTool.session.nil? && !e::GhostTool.active_tool.nil? && e::GhostTool.active_tool.attached?
    line("#{ready ? 'PASS' : 'FAIL'}: quit probe: Inspector + Studio otvorene a ghost visi na kurzore")
    # D3: handle sa otvara TERAZ (pred ukoncenim), nie pri zapise.
    @fh = File.open(TRACE, 'a')
    @fh.sync = true
    @armed = true
    e::Panel.singleton_class.prepend(PanelHook)
    e::StudioDialog.singleton_class.prepend(StudioHook)
    e::GhostTool.singleton_class.prepend(PopHook)
    @watch = QuitWatch.new
    observed = Sketchup.add_observer(@watch) ? true : false
    line("#{observed ? 'PASS' : 'FAIL'}: quit probe: observer sondy (onQuit) zaregistrovany")
    trace(ready ? 'probe:ready' : 'probe:not_ready')
    saved = model.save ? true : false
    unless saved && !model.modified?
      stub = File.join(File.dirname(OUT), 'closing_stub.skp')
      saved = model.save(stub) ? true : false
    end
    trace(saved ? 'probe:saved' : 'probe:save_failed')
    line("#{saved ? 'PASS' : 'FAIL'}: quit probe: run-kopia ulozena (Sketchup.quit sa nebude pytat)")
    UI.start_timer(1.0, false) { quit_now }
  rescue StandardError => ex
    finish("FAIL: quit probe arm: #{ex.class}: #{ex.message}")
  end

  # `NOXUN_QUIT_VIA=menu` (prepinac `-QuitMenu`) = cesta pouzivatela Subor > Koniec
  # (Windows ID_APP_EXIT 57665 cez `send_action`); ked do 8 s nezaberie, poistka
  # `Sketchup.quit` (instancia nesmie ostat visiet). Inak priamo `Sketchup.quit`.
  def quit_now
    via_menu = ENV['NOXUN_QUIT_VIA'].to_s == 'menu'
    trace(via_menu ? 'probe:quit_menu' : 'probe:quit')
    finish("INFO: quit probe: #{via_menu ? 'Subor > Koniec (send_action 57665)' : 'Sketchup.quit'} — " \
           'verdikt robi run_su_tests.ps1 po zaniku procesu')
    if via_menu
      UI.start_timer(8.0, false) do
        trace('probe:fallback_quit')
        Sketchup.quit
      end
      Sketchup.send_action(57_665)
    else
      Sketchup.quit
    end
  rescue StandardError => ex
    finish("FAIL: quit probe quit: #{ex.class}: #{ex.message}")
  end
end

NoxunQuitProbe.start
