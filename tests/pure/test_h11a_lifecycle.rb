# frozen_string_literal: true
# Testy H11a (F-01, cast „ukoncovanie"): PRIPRAVA NA SKETCHUP 2026.2.
#
# CO SA DOKAZUJE:
#   T0a charakterizacia DNESNEJ cesty zatvorenia Inspectora (`cancel_session`)
#       — synchronne `view.invalidate` (+ `lock_inference` pri kresleni),
#       `UI.start_timer(0)` a v timeri PRAVE JEDEN `tools.pop_tool`.
#       Bezi pred zasahom aj po nom (ruchne zatvorenie sa nezmenilo).
require_relative '../helper' unless defined?(NxTest)

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
