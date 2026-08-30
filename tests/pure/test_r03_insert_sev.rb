# frozen_string_literal: true
# R-03 (davka 1d): sev `prepare_insert` / `commit_insert` v CabinetBuilder.
#
# Co sa tu overuje:
#   * `prepare_insert` je CISTA voci modelu (ziadny dotyk na model-stub, ziadne
#     ID) a vrati REKURZIVNE zmrazeny plan — mrazenie sa dokazuje POKUSMI
#     O MUTACIU vnorenych struktur, nie holym `frozen?` (audit FIX 3),
#   * params volajuceho ostanu NEMRAZENE a nezmenene (deep copy PRED freeze),
#   * `commit_insert` odmieta cudzi dokument aj neregidny transform EST PRED
#     akymkolvek dotykom modelu, a odmietne stavbu, ked sa nepodarilo zavriet
#     edit kontext,
#   * validator rigidity je cista funkcia nad `to_a` (16 cisel) — testuje sa
#     bez SketchUpu duck-typed maticami.
#
# Geometria, poloha a Undo sa headless overit NEDAJU (vzor UI-C1c) — to je
# uloha in-SU sekcie `run_r03` v `tests/sketchup/su_runner.rb`.
require_relative '../helper' unless defined?(NxTest)

module NxR03
  CB = Noxun::Engine::CabinetBuilder

  # Model-stub, ktory NESMIE byt oslovený: kazde volanie metody sa zapamata
  # a hodi vynimku. Identita objektu (`equal?`) funguje bez method_missing.
  class TrapModel
    attr_reader :touched

    def initialize
      @touched = []
    end

    def respond_to_missing?(_name, _priv = false)
      true
    end

    def method_missing(name, *_args)
      @touched << name.to_s
      raise "model-stub bol dotknuty: #{name}"
    end
  end

  # Model, z ktoreho sa NEDA vystupit do rootu — `ensure_root_context` vycerpa
  # 20 iteracii a ticho skonci. `start_operation` stub NEMA: keby ho commit
  # zavolal, test spadne na NoMethodError (a to je tiez FAIL).
  class StuckModel
    attr_reader :closes

    def initialize
      @closes = 0
    end

    def active_path
      [:komponent]
    end

    def close_active
      @closes += 1
    end
  end

  # Duck-type matice: staci `to_a` so 16 cislami (stlpcove poradie SketchUpu).
  class Tr
    def initialize(arr)
      @arr = arr
    end

    def to_a
      @arr
    end
  end

  module_function

  def identity(tx = 0.0, ty = 0.0, tz = 0.0)
    Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, tx, ty, tz, 1])
  end

  # Otocenie o 90 stupnov okolo Z (stlpce = obrazy osi).
  def rot_z90
    Tr.new([0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 100, 0, 0, 1])
  end

  def params
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'bottom_mode' => +'under_sides',
      'zone_tree' => { 'id' => 'Z1', 'shelves' => 2, 'children' => [] },
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
      'part_overrides' => { 'cabinet/side:left' => { 'material_id' => 'K009_PW_DTDL_18' } } }
  end
end

# ---------------------------------------------------------------------------
# prepare_insert — cistota a zmrazenie
# ---------------------------------------------------------------------------

NxTest.test('R-03: prepare_insert sa modelu ANI NEDOTKNE (ziadne ID, ziadna entita)') do
  trap = NxR03::TrapModel.new
  plan = NxR03::CB.prepare_insert(trap, NxR03.params)
  NxTest.assert(plan.is_a?(Noxun::Engine::CabinetBuilder::InsertPlan), 'ocakavany InsertPlan')
  NxTest.assert_equal([], trap.touched)
end

NxTest.test('R-03: prepare_insert vydava config IDENTICKY s normalize (ziadna tichá zmena)') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  NxTest.assert_equal(NxR03::CB.normalize(NxR03.params), plan.config)
end

NxTest.test('R-03: home_z podla typu (lower 0, upper UPPER_HANG_Z)') do
  trap = NxR03::TrapModel.new
  NxTest.assert_close(0.0, NxR03::CB.prepare_insert(trap, NxR03.params).home_z)
  up = NxR03::CB.prepare_insert(trap, NxR03.params.merge('type' => 'upper'))
  NxTest.assert_close(NxR03::CB::UPPER_HANG_Z, up.home_z)
end

NxTest.test('R-03: plan je zmrazeny AJ VO VNUTRI — zone_tree sa neda zmenit') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  NxTest.assert(plan.frozen?, 'plan ma byt zmrazeny')
  NxTest.assert(plan.config.frozen?, 'config ma byt zmrazeny')
  NxTest.assert_raise('frozen') { plan.config[:zone_tree]['shelves'] = 9 }
  NxTest.assert_raise('frozen') { plan.config[:zone_tree]['children'] << { 'id' => 'X' } }
end

NxTest.test('R-03: zmrazenie plati na cela (pole items aj jeho zaznamy)') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  items = plan.config[:fronts]['items']
  NxTest.assert(items.is_a?(Array) && !items.empty?, 'ocakavane cela v plane')
  NxTest.assert_raise('frozen') { items << { 'id' => 'F2' } }
  NxTest.assert_raise('frozen') { items.first['mode'] = 'fixed' }
end

NxTest.test('R-03: zmrazenie plati na part_overrides aj na stringove hodnoty enumov') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  ov = plan.config[:part_overrides]
  NxTest.assert_raise('frozen') { ov['cabinet/side:left']['material_id'] = 'INE' }
  NxTest.assert_raise('frozen') { ov['nova/rola'] = {} }
  NxTest.assert(plan.config[:bottom_mode].frozen?, 'stringovy enum ma byt zmrazeny')
  NxTest.assert_raise('frozen') { plan.config[:bottom_mode] << 'x' }
end

NxTest.test('R-03: params volajuceho ostanu NEMRAZENE a nezmenene (deep copy pred freeze)') do
  p = NxR03.params
  before = Marshal.load(Marshal.dump(p))
  NxR03::CB.prepare_insert(NxR03::TrapModel.new, p)
  NxTest.refute(p['bottom_mode'].frozen?, 'string volajuceho sa NESMIE zmrazit')
  NxTest.refute(p['zone_tree'].frozen?, 'hash volajuceho sa NESMIE zmrazit')
  NxTest.refute(p['fronts']['items'].frozen?, 'pole volajuceho sa NESMIE zmrazit')
  NxTest.assert_equal(before, p)
end

NxTest.test('R-03: opakovane prepare_insert vydava NEZAVISLE snapshoty') do
  trap = NxR03::TrapModel.new
  a = NxR03::CB.prepare_insert(trap, NxR03.params)
  b = NxR03::CB.prepare_insert(trap, NxR03.params.merge('width' => 400.0))
  NxTest.assert(!a.config.equal?(b.config), 'snapshoty nesmu zdielat config')
  NxTest.assert_close(600.0, a.config[:width])
  NxTest.assert_close(400.0, b.config[:width])
end

# ---------------------------------------------------------------------------
# rigid_transform? — cisty validator
# ---------------------------------------------------------------------------

NxTest.test('R-03: rigidny transform = posun aj otocenie prejdu') do
  NxTest.assert(NxR03::CB.rigid_transform?(NxR03.identity), 'identita je rigidna')
  NxTest.assert(NxR03::CB.rigid_transform?(NxR03.identity(120.5, -30.0, 700.0)), 'posun je rigidny')
  NxTest.assert(NxR03::CB.rigid_transform?(NxR03.rot_z90), 'otocenie o 90 st. je rigidne')
end

NxTest.test('R-03: MIERKA v osi sa odmieta') do
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
                ))
end

NxTest.test('R-03: ROVNOMERNA mierka schovana v prvku [15] sa odmieta') do
  # Geom::Transformation.scaling(2) necha osi jednotkove a mierku da sem.
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0.5])
                ))
end

NxTest.test('R-03: SKOSENIE (jednotkove, ale nekolme osi) sa odmieta') do
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([1, 0, 0, 0, 0.6, 0.8, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
                ))
end

NxTest.test('R-03: ZRKADLO (lavotociva sustava) sa odmieta') do
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
                ))
end

NxTest.test('R-03: perspektiva, nekonecno a nezmysly sa odmietaju') do
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([1, 0, 0, 0.001, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
                ), 'perspektivny prvok')
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, Float::INFINITY, 0, 0, 1])
                ), 'nekonecny posun')
  NxTest.refute(NxR03::CB.rigid_transform?(NxR03::Tr.new([1, 0, 0])), 'kratke pole')
  NxTest.refute(NxR03::CB.rigid_transform?(nil), 'nil nie je matica')
  NxTest.refute(NxR03::CB.rigid_transform?('identita'), 'string nie je matica')
end

NxTest.test('R-03: validate_insert_transform! hlaskou NAVADZA') do
  err = NxTest.assert_raise('mierka') do
    NxR03::CB.validate_insert_transform!(
      NxR03::Tr.new([2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
    )
  end
  NxTest.assert(err.message.include?('Poloha vkladu'), "hlaska ma pomenovat polohu: #{err.message}")
  NxR03::CB.validate_insert_transform!(NxR03.rot_z90) # rigidny prejde bez vynimky
end

# ---------------------------------------------------------------------------
# commit_insert — odmietnutia PRED dotykom modelu
# ---------------------------------------------------------------------------

NxTest.test('R-03: plan z INEHO dokumentu sa odmietne bez dotyku modelu') do
  a = NxR03::TrapModel.new
  b = NxR03::TrapModel.new
  plan = NxR03::CB.prepare_insert(a, NxR03.params)
  NxTest.assert_raise('inému dokumentu') { NxR03::CB.commit_insert(b, plan) }
  NxTest.assert_equal([], a.touched)
  NxTest.assert_equal([], b.touched)
end

NxTest.test('R-03: commit_insert bez planu (cudzi objekt) sa odmietne rovnakou branou') do
  m = NxR03::TrapModel.new
  NxTest.assert_raise('inému dokumentu') { NxR03::CB.commit_insert(m, { width: 600.0 }) }
  NxTest.assert_equal([], m.touched)
end

NxTest.test('R-03: neregidny transform sa odmietne PRED zatvorenim edit kontextu') do
  m = NxR03::TrapModel.new
  plan = NxR03::CB.prepare_insert(m, NxR03.params)
  bad = NxR03::Tr.new([1.5, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
  NxTest.assert_raise('Poloha vkladu') { NxR03::CB.commit_insert(m, plan, transform: bad) }
  NxTest.assert_equal([], m.touched) # ziadny close_active, ziadna operacia
end

NxTest.test('R-03: zlyhane zatvorenie edit kontextu zastavi vklad PRED operaciou') do
  m = NxR03::StuckModel.new
  plan = NxR03::CB.prepare_insert(m, NxR03.params)
  NxTest.assert_raise('zavrieť otvorený komponent') { NxR03::CB.commit_insert(m, plan) }
  NxTest.assert_equal(20, m.closes) # helper vycerpal svoj guard a commit to zachytil
end

NxTest.test('R-03: root_context? cita active_path a vynimku berie ako NE-root') do
  cb = NxR03::CB
  root = Object.new
  def root.active_path
    nil
  end
  NxTest.assert(cb.root_context?(root), 'nil active_path = root')
  empty = Object.new
  def empty.active_path
    []
  end
  NxTest.assert(cb.root_context?(empty), 'prazdna cesta = root')
  boom = Object.new
  def boom.active_path
    raise 'model je prec'
  end
  NxTest.refute(cb.root_context?(boom), 'vynimka NIE JE root')
end

# ---------------------------------------------------------------------------
# Charakterizacia poradia (zdrojova kontrola — vzor test_r02_doc_guard)
# ---------------------------------------------------------------------------

NxTest.test('R-03: build zatvara edit kontext PRED prepare_insert (dnesne poradie chyb)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'))
  body = src[/def build\(model, params, transform:.*?\n        end/m].to_s
  NxTest.assert(!body.empty?, 'telo build sa nenaslo')
  NxTest.assert(body.index('ensure_root_context') < body.index('prepare_insert'),
                "ensure_root_context ma byt PRED prepare_insert: #{body}")
end

NxTest.test('R-03: scale-lock ostava VNUTRI guarded bloku, attach_one az mimo neho') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'))
  body = src[/def commit_insert\(model, plan.*?\n          inst\n        end/m].to_s
  NxTest.assert(!body.empty?, 'telo commit_insert sa nenaslo')
  guard_end = body.index("\n          end\n          ScaleWatch.attach_one")
  NxTest.assert(!guard_end.nil?, 'koniec guarded bloku sa nenasiel')
  NxTest.assert(body.index('apply_scale_lock_op') < guard_end,
                'apply_scale_lock_op musi byt VNUTRI guarded bloku (BLOCKER 2)')
end
