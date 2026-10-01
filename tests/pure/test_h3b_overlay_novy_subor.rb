# frozen_string_literal: true
# H3b (A-06) — chyba v logu po otvoreni noveho suboru.
#
# Sonda v SketchUpe 2026 (1.10.2026, kopia ENGINEtests.skp): Windows File/New
# vycisti dokument AJ jeho prekrytia, ale Ruby objekt modelu OSTAVA TEN ISTY
# (`equal?` true, `Model#valid?` true). Overlay modulu je potom zneplatneny
# (`Overlay#valid?` false) a `model.overlays.remove(ov)` hodi
# RuntimeError „invalid overlay". `on_model_changed` ho pre zhodny objekt
# nevypne, takze chyba vyskocila az pri dalsom zapnuti (obnova pri otvoreni
# Studia: restore! -> enable! -> disable! -> remove_overlay).
#
# Oprava = straz v `remove_overlay` troch modulov: zneplatneny overlay alebo
# zatvoreny dokument sa len zabudne; ZIVA chyba (platny overlay v platnom
# dokumente) ide do logu ako doteraz. Tieto testy stabuju model aj overlay
# (duck-typing), skutocne zneplatnenie overuje in-SU sekcia `run_h3b`.
require_relative '../helper' unless defined?(NxTest)

H3B_MODS = [Noxun::Engine::DirectionCheck, Noxun::Engine::EdgeCheck, Noxun::Engine::GrainCheck].freeze

class H3bOverlay
  attr_accessor :valid, :valid_raises

  def initialize(valid: true)
    @valid = valid
  end

  def valid?
    raise RuntimeError, 'valid? zlyhalo' if @valid_raises

    @valid
  end
end

# Overlay bez `valid?` (duck stub ako v ostatnych testoch) — straz ho NESMIE
# povazovat za zneplatneny.
class H3bOverlayNoValid; end

class H3bOverlays
  attr_reader :removed

  def initialize(model)
    @model = model
    @removed = []
  end

  def to_a
    raise RuntimeError, 'closed model' unless @model.valid?

    []
  end

  # Spravanie SketchUpu: zneplatneny overlay -> „invalid overlay";
  # `fail_with` = skutocna chyba ZIVEHO dokumentu.
  def remove(overlay)
    raise RuntimeError, 'closed model' unless @model.valid?
    raise RuntimeError, 'invalid overlay' if overlay.respond_to?(:valid?) && !overlay.valid?
    raise RuntimeError, @model.fail_with if @model.fail_with

    @removed << overlay
    true
  end
end

class H3bModel
  attr_accessor :valid, :fail_with
  attr_reader :overlays

  def initialize(valid: true)
    @valid = valid
    @overlays = H3bOverlays.new(self)
  end

  def valid?
    @valid
  end

  def remove_observer(_obs)
    false
  end

  def active_view
    nil
  end
end

# Zachyti Engine.log_error (a doplni broadcasty, ktore headless loader nema)
# len na dobu bloku — potom vrati povodne metody.
def h3b_capture
  eng = Noxun::Engine
  logs = []
  orig = eng.method(:log_error)
  added = %i[broadcast_direction_check broadcast_grain_check broadcast_edge_check].reject { |n| eng.respond_to?(n) }
  added.each { |n| eng.define_singleton_method(n) { |*_a| nil } }
  eng.define_singleton_method(:log_error) { |ex, ctx = nil| logs << [ctx.to_s, ex.message.to_s] }
  yield logs
ensure
  eng.define_singleton_method(:log_error, orig)
  added.each { |n| eng.singleton_class.send(:remove_method, n) }
end

def h3b_arm(mod, model, overlay)
  mod.instance_variable_set(:@overlay, overlay)
  mod.instance_variable_set(:@model, model)
  mod.instance_variable_set(:@observer, Object.new)
end

def h3b_reset(mod)
  %i[@overlay @model @observer @cache @payload].each { |v| mod.instance_variable_set(v, nil) }
end

H3B_MODS.each do |mod|
  name = mod.name.split('::').last

  NxTest.test("H3b #{name}: overlay zneplatneny File/New (model ten isty) — vypnutie NEZAPISE chybu") do
    m = H3bModel.new
    ov = H3bOverlay.new(valid: false)
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.disable!
      NxTest.assert_equal([], logs, "#{name}: log po File/New: #{logs.inspect}")
      NxTest.assert_equal([], m.overlays.removed, 'zneplatneny overlay sa nesmie odstranovat')
      NxTest.assert_equal(nil, mod.instance_variable_get(:@overlay), 'referencia overlayu ostala')
      NxTest.assert_equal(nil, mod.instance_variable_get(:@model), 'referencia modelu ostala')
      NxTest.assert_equal(false, mod.active?(m))
    end
  ensure
    h3b_reset(mod)
  end

  NxTest.test("H3b #{name}: prepnutie na iny dokument so zneplatnenym overlayom — ziadna chyba v logu") do
    m = H3bModel.new
    other = H3bModel.new
    ov = H3bOverlay.new(valid: false)
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.on_model_changed(other)
      NxTest.assert_equal([], logs, "#{name}: log pri prepnuti: #{logs.inspect}")
      NxTest.assert_equal(nil, mod.instance_variable_get(:@overlay))
      NxTest.assert_equal(false, mod.active?(other))
    end
  ensure
    h3b_reset(mod)
  end

  NxTest.test("H3b #{name}: zatvoreny dokument (Model#valid? false) — len zabudnut, bez logu") do
    m = H3bModel.new(valid: false)
    ov = H3bOverlay.new(valid: true)
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.disable!
      NxTest.assert_equal([], logs, "#{name}: log pri zatvorenom dokumente: #{logs.inspect}")
      NxTest.assert_equal(nil, mod.instance_variable_get(:@overlay))
    end
  ensure
    h3b_reset(mod)
  end

  NxTest.test("H3b #{name}: zivy dokument — overlay sa odstrani PRESNE raz, bez logu") do
    m = H3bModel.new
    ov = H3bOverlay.new(valid: true)
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.disable!
      NxTest.assert_equal([ov], m.overlays.removed, 'zivy overlay sa musi z modelu odstranit (raz)')
      NxTest.assert_equal([], logs)
    end
  ensure
    h3b_reset(mod)
  end

  NxTest.test("H3b #{name}: overlay bez valid? (starsi duck) sa odstranuje ako doteraz") do
    m = H3bModel.new
    ov = H3bOverlayNoValid.new
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.disable!
      NxTest.assert_equal([ov], m.overlays.removed)
      NxTest.assert_equal([], logs)
    end
  ensure
    h3b_reset(mod)
  end

  NxTest.test("H3b #{name}: skutocna chyba ZIVEHO dokumentu sa NEZAMLCI (log_error)") do
    m = H3bModel.new
    m.fail_with = 'remove zlyhal'
    ov = H3bOverlay.new(valid: true)
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.disable!
      NxTest.assert_equal([["#{name}.remove_overlay", 'remove zlyhal']], logs,
                          "#{name}: ziva chyba sa musi zapisat: #{logs.inspect}")
    end
  ensure
    h3b_reset(mod)
  end

  NxTest.test("H3b #{name}: vynimka samotneho valid? nie je „zneplatneny\" — ide do logu") do
    m = H3bModel.new
    ov = H3bOverlay.new(valid: true)
    ov.valid_raises = true
    h3b_capture do |logs|
      h3b_arm(mod, m, ov)
      mod.disable!
      NxTest.assert_equal(["#{name}.remove_overlay"], logs.map(&:first), logs.inspect)
      NxTest.assert_equal([], m.overlays.removed)
    end
  ensure
    h3b_reset(mod)
  end
end

NxTest.test('H3b: straz je v remove_overlay (nie plosny rescue, nie text vynimky); HoverEdge bez zmeny') do
  %w[direction_check edge_check grain_check].each do |f|
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', "#{f}.rb"), encoding: 'UTF-8')
    body = src[/def remove_overlay\(model, overlay\).*?\r?\n      end\r?\n/m].to_s
    NxTest.assert(body.include?('return if stale_overlay?(model, overlay)'), "#{f}: straz chyba")
    NxTest.assert(body.include?('Engine.log_error(e,'), "#{f}: ziva chyba sa uz nezapisuje")
    code = src.lines.reject { |l| l.strip.start_with?('#') }.join
    NxTest.refute(code.include?('invalid overlay'), "#{f}: rozlisovanie podla textu vynimky je zakazane (R-A06-3)")
  end
  hover = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hover_edge.rb'), encoding: 'UTF-8')
  NxTest.refute(hover.include?('stale_overlay?'), 'HoverEdge sa v H3b nemeni')
end
