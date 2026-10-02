# frozen_string_literal: true
# Testy H11a (F-01, cast „ukoncovanie"): PRIPRAVA NA SKETCHUP 2026.2.
#
# CO SA DOKAZUJE:
#   T0a charakterizacia DNESNEJ cesty zatvorenia Inspectora (`cancel_session`)
#       — synchronne `view.invalidate` (+ `lock_inference` pri kresleni),
#       `UI.start_timer(0)` a v timeri PRAVE JEDEN `tools.pop_tool`.
#       Bezi pred zasahom aj po nom (rucne zatvorenie sa nezmenilo).
#   T1  priznak `quitting?`, potvrdenie behu (sync hned / async cez timer),
#       odlozene bloky (chyba jedneho nezastavi ostatne), stopa so stropom 50,
#       testovaci sink izolovany od toku, `reset_for_tests!` len v definicii.
#   T2  `invalidate_session!` = cisty Ruby (0 volani API, ziadny timer), vrati
#       sirotsky nastroj; `pop_tool` pri ukoncovani sa ODLOZI a az potvrdenie
#       behu popne PRAVE RAZ.
#   T3  `install!` — 3x = jedna registracia a jedno dorucenie `onQuit`;
#       add false / vynimka = chyba startu; vymena observera s neuspesnym
#       odpojenim aktivaciu zastavi (D1).
#   T7  text: hooky Inspectora a Studia (vetva `quitting?` bez SketchUp API,
#       `@dialog = nil` vzdy), `onQuit` bez API/IO, `ensure_dialog` potvrdi beh
#       pred oknom, klik/Esc ako prve, `install!` je brana initu.
#
# MUTACIE (vysledok v PR davky H11a):
#   M1 hook bez vetvy `quitting?`            -> T7 Inspector (+ in-SU Q2)
#   M2 vetva bez `invalidate_session!`       -> T7 (+ in-SU Q3: klik commitne)
#   M3 odlozeny blok bez `if @dialog.nil?`   -> T7 (+ in-SU Q5)
#   M4 `pop_tool` bez poistky                -> T2 (+ in-SU Q6)
#   M5 `pop_tool` pri ukoncovani bez odlozenia -> T2 (+ in-SU Q4)
#   M6 `confirm_running!` z `onMouseMove`    -> T7
#   M7 `onQuit` cita `active_model`          -> T7
#   M8 `install!` 2x registruje              -> T3
#   M14 `@dialog = nil` vo vnutri podmienky  -> T7 (+ D-52b bariera)
require_relative '../helper' unless defined?(NxTest)
require 'stringio'

module NxH11a
  module_function

  def gt
    Noxun::Engine::GhostTool
  end

  # Zaznam volani SketchUp API (duck typing, ziadny SketchUp).
  def calls
    @calls ||= []
  end

  def reset_calls!
    @calls = []
  end

  class FakeView
    def lock_inference(*)
      NxH11a.calls << 'view.lock_inference'
    end

    def invalidate
      NxH11a.calls << 'view.invalidate'
    end
  end

  class FakeTools
    def pop_tool
      NxH11a.calls << 'model.tools.pop_tool'
    end
  end

  class FakeModel
    def active_view
      NxH11a.calls << 'model.active_view'
      FakeView.new
    end

    def tools
      FakeTools.new
    end
  end

  class FakeSession
    attr_reader :model

    def initialize(model, drawing)
      @model = model
      @drawing = drawing
      @state = :active
    end

    def cancel!(_reason = nil)
      return false unless @state == :active

      @state = :cancelled
      true
    end

    def terminal?
      @state == :cancelled
    end

    def committing?
      false
    end

    def drawing?
      @drawing
    end

    def active?
      @state == :active
    end
  end

  class FakeTool
    attr_reader :model_ref

    def initialize(model)
      @model_ref = model
      @attached = true
    end

    def attached?
      @attached
    end

    def on_top?
      @attached
    end

    def detach!
      @attached = false
    end

    def request_finish!; end
  end

  # Headless nema `UI` — stub timery ZBIERA (nespusta), test ich odpali sam.
  def with_ui
    had = Object.const_defined?(:UI)
    return yield([]) if had

    timers = []
    ui = Module.new
    ui.define_singleton_method(:start_timer) do |_s, _r = false, &blk|
      NxH11a.calls << 'UI.start_timer'
      timers << blk
      timers.length
    end
    Object.const_set(:UI, ui)
    begin
      yield(timers)
    ensure
      Object.send(:remove_const, :UI)
    end
  end

  # Zavesi fake ghost (session + nastroj) a po bloku VZDY uprace modul.
  def with_ghost(drawing: false)
    m = FakeModel.new
    s = FakeSession.new(m, drawing)
    t = FakeTool.new(m)
    gt.instance_variable_set(:@session, s)
    gt.instance_variable_set(:@active_tool, t)
    yield(s, t, m)
  ensure
    gt.instance_variable_set(:@session, nil)
    gt.instance_variable_set(:@active_tool, nil)
  end
end

# --- T0a: charakterizacia dnesneho rucneho zatvorenia --------------------------

NxTest.test('H11a T0a: rucne zatvorenie Inspectora (cancel_session) — API synchronne + 1 pop v timeri') do
  NxTest.skip!('stub UI len headless') unless NxTest.headless?
  [false, true].each do |drawing|
    NxH11a.with_ui do |timers|
      NxH11a.with_ghost(drawing: drawing) do |s, t, _m|
        NxH11a.reset_calls!
        r = NxH11a.gt.cancel_session('zatvorený Inspector')
        NxTest.assert(r, "cancel_session vratil #{r.inspect} (drawing=#{drawing})")
        sync = NxH11a.calls.dup
        NxTest.assert(sync.include?('view.invalidate'), "synchronne view.invalidate (drawing=#{drawing}): #{sync.inspect}")
        NxTest.assert_equal(drawing, sync.include?('view.lock_inference'),
                            "lock_inference len pri kresleni (drawing=#{drawing}): #{sync.inspect}")
        NxTest.assert_equal(1, sync.count('UI.start_timer'), "jeden timer popu: #{sync.inspect}")
        NxTest.refute(sync.include?('model.tools.pop_tool'), 'pop NIE synchronne')
        NxTest.assert(s.terminal?, 'session zrusena')
        NxTest.assert(NxH11a.gt.session.nil?, 'slot session uvolneny')
        NxH11a.reset_calls!
        timers.each(&:call)
        NxTest.assert_equal(['model.tools.pop_tool'], NxH11a.calls, 'v timeri PRAVE JEDEN pop')
        NxTest.refute(t.attached?, 'nastroj odpojeny')
      end
    end
  end
end

# --- T1: priznak a stopa --------------------------------------------------------

module NxH11a
  module_function

  def lc
    Noxun::Engine::AppLifecycle
  end

  def quiet
    old = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = old
  end

  # Kazdy test zacina a konci s cistym stavom ukoncovania (nikdy v SketchUpe).
  def fresh
    NxTest.skip!('meni stav ukoncovania — len headless') unless NxTest.headless?
    lc.reset_for_tests!(boot: true)
    yield
  ensure
    lc.reset_for_tests!(boot: true) if NxTest.headless?
  end

  def src(*parts)
    File.binread(File.join(NxTest::ROOT, *parts)).force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  # Telo metody (`def name` az po `end` na rovnakom odsadeni).
  def method_body(text, name, indent)
    pad = ' ' * indent
    text[/^#{pad}def #{Regexp.escape(name)}.*?\n#{pad}end\n/m].to_s
  end

  class FakeApp
    attr_reader :observers, :adds, :removes

    def initialize(add: true, remove: true)
      @add = add
      @remove = remove
      @observers = []
      @adds = 0
      @removes = 0
    end

    def add_observer(obs)
      @adds += 1
      raise 'add vybuchol' if @add == :raise
      return false unless @add

      @observers << obs
      true
    end

    def remove_observer(obs)
      @removes += 1
      raise 'remove vybuchol' if @remove == :raise
      return false unless @remove

      !@observers.delete(obs).nil?
    end

    def quit!
      @observers.each(&:onQuit)
    end
  end

  class CountingObserver
    attr_reader :quits

    def initialize
      @quits = 0
    end

    def onQuit # rubocop:disable Naming/MethodName
      @quits += 1
      NxH11a.lc.mark_quitting!('onQuit')
    end
  end
end

NxTest.test('H11a T1: priznak ukoncovania, potvrdenie behu a odlozene bloky') do
  NxH11a.fresh do
    lc = NxH11a.lc
    NxTest.refute(lc.quitting?, 'na zaciatku SketchUp bezi')
    NxTest.refute(lc.confirm_running!('bez priznaku', sync: true), 'bez priznaku nic')
    ran = []
    lc.defer_until_running('hned') { ran << :hned }
    NxTest.assert_equal([:hned], ran, 'bez ukoncovania sa blok vykona hned')
    NxH11a.quiet { lc.mark_quitting!('test') }
    NxTest.assert(lc.quitting?)
    lc.defer_until_running('a') { ran << :a }
    lc.defer_until_running('b') { raise 'blok b' }
    lc.defer_until_running('c') { ran << :c }
    NxTest.assert_equal(%w[a b c], lc.deferred_labels, 'pri ukoncovani sa bloky odlozia')
    NxTest.assert_equal([:hned], ran, 'odlozene bloky este nebezali')
    NxTest.assert(NxH11a.quiet { lc.confirm_running!('okno', sync: true) })
    NxTest.refute(lc.quitting?, 'priznak dole')
    NxTest.assert_equal(%i[hned a c], ran, 'chyba bloku b nezastavi c')
    NxTest.assert_equal([], lc.deferred_labels, 'zoznam sa vyprazdnil')
    NxTest.assert_equal(%w[deferred:run:hned deferred:skip:a deferred:skip:b deferred:skip:c running:okno
                           deferred:run:a deferred:run:b deferred:run:c], lc.trace_events)
  end
end

NxTest.test('H11a T1: stopa ma strop 50, sink sa vola len ked je nastaveny a jeho chyba je izolovana') do
  NxH11a.fresh do
    lc = NxH11a.lc
    60.times { |i| lc.trace("e#{i}") }
    NxTest.assert_equal(50, lc.trace_events.length)
    NxTest.assert_equal('e10', lc.trace_events.first)
    got = []
    lc.trace_sink = ->(ev) { got << ev }
    lc.trace('s1')
    lc.trace_sink = ->(_ev) { raise IOError, 'disk plny' }
    NxTest.assert_equal('s2', lc.trace('s2'), 'chyba sinku tok nemeni')
    NxTest.assert_equal(['s1'], got)
    NxTest.assert_equal('s2', lc.trace_events.last)
  end
end

NxTest.test('H11a T1: confirm_running!(sync: false) ide cez timer') do
  NxH11a.fresh do
    lc = NxH11a.lc
    NxH11a.with_ui do |timers|
      ran = []
      NxH11a.quiet { lc.mark_quitting!('t') }
      lc.defer_until_running('x') { ran << :x }
      NxH11a.quiet { lc.confirm_running!('klik', sync: false) }
      NxTest.refute(lc.quitting?, 'priznak dole hned')
      NxTest.assert_equal([], ran, 'blok este nebezal (timer)')
      NxTest.assert_equal(1, timers.length)
      timers.each(&:call)
      NxTest.assert_equal([:x], ran)
    end
  end
end

NxTest.test('H11a T1: reset_for_tests! v plugine nikto nevola (len definicia)') do
  hits = Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')].flat_map do |f|
    File.binread(f).force_encoding(Encoding::UTF_8).lines.each_with_index.select do |l, _i|
      l.sub(/#.*$/, '').include?('reset_for_tests!')
    end.map { |_l, i| "#{File.basename(f)}:#{i + 1}" }
  end
  NxTest.assert_equal(1, hits.length, "len definicia: #{hits.inspect}")
  NxTest.assert(hits.first.start_with?('app_lifecycle.rb'), hits.inspect)
end

# --- T2: zneplatnenie session a poistka popu ------------------------------------

NxTest.test('H11a T2: invalidate_session! — cisty Ruby, 0 volani API, vrati sirotsky nastroj') do
  NxTest.skip!('stub UI len headless') unless NxTest.headless?
  NxH11a.with_ui do |timers|
    NxH11a.with_ghost(drawing: true) do |s, t, _m|
      NxH11a.reset_calls!
      orphan = NxH11a.gt.invalidate_session!('zatvorený Inspector')
      NxTest.assert(orphan.equal?(t), 'vratil sirotsky nastroj')
      NxTest.assert(s.terminal?, 'session zrusena')
      NxTest.assert(NxH11a.gt.session.nil?, 'slot uvolneny')
      NxTest.assert_equal([], NxH11a.calls, "ziadne SketchUp API: #{NxH11a.calls.inspect}")
      NxTest.assert_equal([], timers, 'ziadny timer')
      NxTest.assert(t.attached?, 'nastroj sa NEpopol')
    end
  end
end

NxTest.test('H11a T2: pop_tool pri ukoncovani sa odlozi; potvrdenie sync popne 1x, async cez timer') do
  NxH11a.fresh do
    NxH11a.with_ui do |timers|
      NxH11a.with_ghost do |_s, t, _m|
        lc = NxH11a.lc
        NxH11a.quiet { lc.mark_quitting!('t') }
        NxH11a.reset_calls!
        NxTest.refute(NxH11a.gt.pop_tool(t), 'pop pri ukoncovani vrati false')
        NxTest.assert_equal([], NxH11a.calls, '0x tools.pop_tool')
        NxTest.assert(t.attached?)
        NxTest.assert_equal(['ghost pop'], lc.deferred_labels)
        NxTest.assert(lc.trace_events.include?('pop:deferred'))
        NxH11a.quiet { lc.confirm_running!('okno', sync: true) }
        NxTest.assert_equal(['model.tools.pop_tool'], NxH11a.calls, 'sync potvrdenie = 1 pop')
        NxTest.refute(t.attached?)
        NxTest.assert(lc.trace_events.include?('pop:executed'))
      end
      NxH11a.with_ghost do |_s, t, _m|
        lc = NxH11a.lc
        NxH11a.quiet { lc.mark_quitting!('t') }
        NxH11a.gt.pop_tool(t)
        NxH11a.reset_calls!
        timers.clear
        NxH11a.quiet { lc.confirm_running!('klik', sync: false) }
        NxTest.assert_equal(['UI.start_timer'], NxH11a.calls, 'async potvrdenie = timer, pop este nie')
        timers.each(&:call)
        NxTest.assert_equal(['UI.start_timer', 'model.tools.pop_tool'], NxH11a.calls)
        NxTest.refute(t.attached?)
      end
    end
  end
end

# --- T3: quit observer ------------------------------------------------------------

NxTest.test('H11a T3: install! 3x = PRAVE JEDNA registracia, onQuit doruceny raz') do
  NxH11a.fresh do
    lc = NxH11a.lc
    app = NxH11a::FakeApp.new
    obs = NxH11a::CountingObserver.new
    3.times { NxTest.assert(lc.install!(app: app, observer: obs)) }
    NxTest.assert(lc.install!(app: app), 'aj bez observera = uz zaregistrovany')
    NxTest.assert_equal(1, app.adds, 'add_observer prave raz')
    NxTest.assert_equal(1, app.observers.length)
    NxTest.assert(lc.observer_installed?)
    NxH11a.quiet { app.quit! }
    NxTest.assert_equal(1, obs.quits, 'onQuit doruceny prave raz')
    NxTest.assert(lc.quitting?)
    NxTest.refute(lc.failed?)
  end
end

NxTest.test('H11a T3: add_observer false / vynimka = install! false + chyba startu') do
  [false, :raise].each do |mode|
    NxH11a.fresh do
      lc = NxH11a.lc
      r = NxH11a.quiet { lc.install!(app: NxH11a::FakeApp.new(add: mode), observer: NxH11a::CountingObserver.new) }
      NxTest.refute(r, "install! pri add=#{mode}")
      NxTest.assert(lc.failed?, 'chyba startu zapisana')
      NxTest.refute(lc.observer_installed?)
      NxTest.assert(lc.failures.first['startup'])
      NxTest.assert(lc.failure_message.include?('Reštartuj SketchUp'))
    end
  end
end

NxTest.test('H11a T3: vymena observera — remove false / vynimka zastavi aktivaciu (D1)') do
  [false, :raise].each do |mode|
    NxH11a.fresh do
      lc = NxH11a.lc
      app = NxH11a::FakeApp.new(remove: mode)
      NxTest.assert(lc.install!(app: app, observer: NxH11a::CountingObserver.new))
      r = NxH11a.quiet { lc.install!(app: app, observer: NxH11a::CountingObserver.new) }
      NxTest.refute(r, "druhy observer pri remove=#{mode}")
      NxTest.assert(lc.failed?)
      NxTest.assert_equal(1, app.adds, 'druhy observer sa NEpridal (dva by dorucili dve onQuit)')
    end
  end
end

NxTest.test('H11a T3: vymena observera s uspesnym remove = stale jedna registracia') do
  NxH11a.fresh do
    lc = NxH11a.lc
    app = NxH11a::FakeApp.new
    o1 = NxH11a::CountingObserver.new
    o2 = NxH11a::CountingObserver.new
    lc.install!(app: app, observer: o1)
    NxTest.assert(lc.install!(app: app, observer: o2))
    NxTest.assert_equal([o2], app.observers)
    NxH11a.quiet { app.quit! }
    NxTest.assert_equal([0, 1], [o1.quits, o2.quits])
  end
end

# --- T7: text hookov, onQuit, ensure_dialog, nastroja a initu ---------------------

NxTest.test('H11a T7: hook Inspectora — pri ukoncovani len trace/invalidate/defer, @dialog = nil vzdy') do
  panel = NxH11a.src('noxun_engine', 'ui', 'panel.rb')
  hook = panel[/@dialog\.set_on_closed do\n.*?\n          end\n/m].to_s
  NxTest.refute(hook.empty?, 'hook Inspectora sa nenasiel')
  q = hook[/if AppLifecycle\.quitting\?\n(.*?)\n            else\n/m, 1].to_s
  NxTest.refute(q.empty?, 'hook nema vetvu `quitting?`')
  code = q.lines.map { |l| l.sub(/#.*$/, '').strip }.reject(&:empty?)
  outside = code.take_while { |l| !l.start_with?('AppLifecycle.defer_until_running') }
  NxTest.assert_equal(["AppLifecycle.trace('hook:inspector:quitting')",
                       "orphan = defined?(GhostTool) ? GhostTool.invalidate_session!('zatvorený Inspector') : nil"],
                      outside, 'pred odlozenim len stopa a zneplatnenie')
  block = q[/defer_until_running\('Inspector'\) do\n(.*?)\n              end/m, 1].to_s
  NxTest.assert(block.include?('detach_observer if @dialog.nil?'), 'odlozene odvesenie len bez noveho okna')
  NxTest.assert(block.include?('GhostTool.pop_tool(orphan)'), 'pop viazany na instanciu')
  last = hook.lines.map(&:strip).reject { |l| l.empty? || l == 'end' }.last.to_s
  NxTest.assert(last.start_with?('@dialog = nil'), "@dialog = nil MIMO podmienky, posledne (#{last})")
  normal = hook[/            else\n(.*?)\n            end\n/m, 1].to_s
  NxTest.assert(normal.include?("AppLifecycle.trace('hook:inspector:normal')") &&
                normal.include?('detach_observer') && normal.include?("GhostTool.cancel_session('zatvorený Inspector')"),
                'normalna vetva = dnesne spravanie')
end

NxTest.test('H11a T7: hook Studia — pri ukoncovani len trace + defer, resety a @dialog = nil vzdy') do
  studio = NxH11a.src('noxun_engine', 'ui', 'studio_dialog.rb')
  hook = studio[/@dialog\.set_on_closed do\n.*?\n          end\n/m].to_s
  q = hook[/if AppLifecycle\.quitting\?\n(.*?)\n            else\n/m, 1].to_s
  code = q.lines.map { |l| l.sub(/#.*$/, '').strip }.reject(&:empty?)
  NxTest.assert_equal(["AppLifecycle.trace('hook:studio:quitting')",
                       "AppLifecycle.defer_until_running('Štúdio') { detach_stale_observer if @dialog.nil? }"], code)
  after = hook[/\n            end\n(.*)\z/m, 1].to_s
  ['@ready = false', 'MaterialsDialog.on_ui_closed', 'HardwareCatalogDialog.on_ui_closed',
   'ApplianceDialog.on_ui_closed', '@dialog = nil'].each do |frag|
    NxTest.assert(after.include?(frag), "#{frag} musi byt MIMO podmienky")
  end
  normal = hook[/            else\n(.*?)\n            end\n/m, 1].to_s
  NxTest.assert(normal.include?("AppLifecycle.trace('hook:studio:normal')") && normal.include?('detach_stale_observer'))
end

NxTest.test('H11a T7: pri ukoncovani ziadny pop_tool ani cancel_session mimo odlozeneho bloku') do
  %w[ui/panel.rb ui/studio_dialog.rb].each do |rel|
    text = NxH11a.src('noxun_engine', *rel.split('/'))
    hook = text[/@dialog\.set_on_closed do\n.*?\n          end\n/m].to_s
    q = hook[/if AppLifecycle\.quitting\?\n(.*?)\n            else\n/m, 1].to_s
    NxTest.refute(q.empty?, "#{rel}: vetva quitting? chyba")
    q = q.lines.map { |l| l.sub(/#.*$/, '') }.join
    outside = q.sub(/defer_until_running\([^)]*\) (?:do\n.*?\n              end|\{[^}]*\})/m, '')
    NxTest.refute(outside.include?('pop_tool') || outside.include?('cancel_session') ||
                  outside.include?('detach') || outside.include?('HoverEdge'),
                  "#{rel}: pri ukoncovani priame SketchUp upratanie")
  end
end

NxTest.test('H11a T7: onQuit = len Ruby stav (ziadne API, timer, okno ani subor)') do
  life = NxH11a.src('noxun_engine', 'core', 'app_lifecycle.rb')
  body = life[/def onQuit.*?\n          end\n/m].to_s
  NxTest.refute(body.empty?, 'onQuit sa nenasiel')
  code = body.lines.map { |l| l.sub(/#.*$/, '') }.join
  %w[active_model tools overlays selection visible? start_timer messagebox File IO open write].each do |bad|
    NxTest.refute(code.include?(bad), "onQuit nesmie obsahovat #{bad}")
  end
  NxTest.assert(code.include?("AppLifecycle.mark_quitting!('onQuit')") && code.include?("AppLifecycle.trace('on_quit')"))
  mq = NxH11a.method_body(life, 'mark_quitting!(source)', 8)
  NxTest.refute(mq.empty?, 'mark_quitting! sa nenasiel')
  %w[Sketchup UI. File IO start_timer].each { |bad| NxTest.refute(mq.include?(bad), "mark_quitting! nesmie #{bad}") }
  tr = NxH11a.method_body(life, 'trace(event)', 8)
  %w[File IO Sketchup UI.].each { |bad| NxTest.refute(tr.include?(bad), "trace nesmie #{bad} (len testovaci sink)") }
  NxTest.assert_equal(2, life.scan(/@trace_sink\s*=[^=]/).length + life.scan('attr_accessor :trace_sink').length,
                      'sink nastavuje len test (attr_accessor) a reset_for_tests! (nil)')
end

NxTest.test('H11a T7: ensure_dialog oboch okien potvrdi beh PRED vytvorenim okna') do
  { %w[ui panel.rb] => 'Inspector', %w[ui studio_dialog.rb] => 'Štúdio' }.each do |path, name|
    body = NxH11a.method_body(NxH11a.src('noxun_engine', *path), 'ensure_dialog', 8)
    i = body.index('AppLifecycle.confirm_running!(')
    NxTest.assert(i && i < body.index('UI::HtmlDialog.new'), "#{name}: confirm_running! pred HtmlDialog.new")
    NxTest.assert(body.include?('sync: true'), "#{name}: synchronne")
  end
end

NxTest.test('H11a T7: onLButtonDown a onCancel potvrdia beh AKO PRVE; onMouseMove/deactivate/resume nie') do
  gt = NxH11a.src('noxun_engine', 'core', 'ghost_tool.rb')
  { 'onLButtonDown' => 'klik v nástroji', 'onCancel' => 'Esc v nástroji' }.each do |m, reason|
    body = gt[/^        def #{m}\(.*?\n        end\n/m].to_s
    first = body.lines[1..].to_a.map { |l| l.sub(/#.*$/, '').strip }.reject(&:empty?).first.to_s
    NxTest.assert(first.start_with?("AppLifecycle.confirm_running!('#{reason}', sync: false)"),
                  "#{m}: prvy prikaz je potvrdenie behu (#{first})")
  end
  NxTest.assert(gt[/^        def onCancel\(.*?\n        end\n/m].to_s.include?('reason.to_i.zero?'), 'onCancel len Esc (reason 0)')
  %w[onMouseMove deactivate resume suspend activate].each do |m|
    body = gt[/^        def #{m}\b.*?\n        end\n/m].to_s
    NxTest.refute(body.empty?, "#{m} sa nenasiel")
    NxTest.refute(body.include?('confirm_running!'), "#{m} beh NEpotvrdzuje")
  end
end

NxTest.test('H11a T7: install! je PRVY krok initu; init len pri celom plugine') do
  main = NxH11a.src('noxun_engine', 'main.rb')
  gate = NxH11a.method_body(main, 'self.init_allowed?', 4)
  NxTest.assert(gate.include?('!AppLifecycle.failed? && AppLifecycle.install!'), 'brana: chyby + registracia')
  NxTest.assert(gate.include?('AppLifecycle.announce_failures! unless @init_allowed'), 'hlaska pri zablokovani')
  i_gate = main.index('if !file_loaded?(__FILE__) && init_allowed?')
  NxTest.assert(i_gate, 'init je za branou')
  NxTest.assert(i_gate < main.index('Materials.boot_cutover!', i_gate.to_i), 'install! pred prvym krokom initu')
  NxTest.assert_equal(1, main.scan('Materials.boot_cutover!').length)
end
