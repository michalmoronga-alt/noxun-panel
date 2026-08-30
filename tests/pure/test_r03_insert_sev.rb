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

  # FIXTURE pokryva VSETKY vetvy `normalize`, ktore stavaju vnorene struktury:
  # rozdelene zony s `cuts`, cela, ABS overridy vratane sticky `edge_warnings`,
  # rucne zasahy do kovania (pole) a sety kovania vratane SELECTORA (pasma).
  def params
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'bottom_mode' => +'under_sides',
      'zone_tree' => { 'id' => 'Z1', 'shelves' => 0,
                       'split' => { 'axis' => 'v', 'count' => 2,
                                    'cuts' => [{ 'size' => 280.0, 'locked' => true },
                                               { 'size' => nil, 'locked' => false }] },
                       'children' => [{ 'id' => 'Z1.1', 'shelves' => 1, 'children' => [] },
                                      { 'id' => 'Z1.2', 'shelves' => 0, 'children' => [] }] },
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
      'part_overrides' => {
        +'cabinet/side:left' => {
          'material_id' => 'K009_PW_DTDL_18',
          'edges' => { 'L1' => nil },
          'edge_warnings' => { 'L1' => { 'reason' => 'abs_04_manual', 'abs_id' => nil } }
        }
      },
      'hardware_overrides' => [{ 'owner_part_key' => nil, 'generic_type' => 'leg',
                                 'rule_id' => 'legs_default', 'quantity' => 6 }],
      'hardware_sets' => {
        'leg' => 'SET_NOHY',
        'hinge' => { 'param' => 'width',
                     'bands' => [{ 'min' => 0.0, 'max' => 600.0, 'set_id' => 'SET_A' },
                                 { 'min' => 601.0, 'max' => 1200.0, 'set_id' => 'SET_B' }] }
      } }
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
  NxTest.assert_raise('frozen') { plan.config[:zone_tree]['children'].first['shelves'] = 5 }
end

NxTest.test('R-03: zmrazenie plati na ROZDELENE zony — split aj pole cuts') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  split = plan.config[:zone_tree]['split']
  NxTest.assert(split.is_a?(Hash), 'fixture ma niest rozdelenu korenovu zonu')
  cuts = split['cuts']
  NxTest.assert_equal(2, cuts.length)
  NxTest.assert_raise('frozen') { split['count'] = 3 }
  NxTest.assert_raise('frozen') { cuts << { 'size' => nil, 'locked' => false } }
  NxTest.assert_raise('frozen') { cuts.first['size'] = 999.0 }
  NxTest.assert_raise('frozen') { cuts.first['locked'] = false }
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
  rec = ov['cabinet/side:left']
  NxTest.assert_raise('frozen') { ov['cabinet/side:left']['material_id'] = 'INE' }
  NxTest.assert_raise('frozen') { ov['nova/rola'] = {} }
  NxTest.assert_raise('frozen') { rec['edges']['L1'] = 'ABS_X' }
  # sticky remapove dovody su este o uroven hlbsie (resolve_part ich in-place
  # upratuje — o to viac musi PLAN ostat nedotknutelny)
  NxTest.assert_raise('frozen') { rec['edge_warnings']['L1']['reason'] = 'ine' }
  NxTest.assert_raise('frozen') { rec['edge_warnings']['L2'] = { 'reason' => 'x' } }
  NxTest.assert(plan.config[:bottom_mode].frozen?, 'stringovy enum ma byt zmrazeny')
  NxTest.assert_raise('frozen') { plan.config[:bottom_mode] << 'x' }
end

NxTest.test('R-03: kluc hasha je VLASTNA zmrazena kopia (part_key sa neda prepisat na mieste)') do
  p = NxR03.params
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, p)
  key = plan.config[:part_overrides].keys.first
  NxTest.assert_equal('cabinet/side:left', key)
  NxTest.assert(key.frozen?, 'stringovy kluc ma byt zmrazeny')
  NxTest.assert_raise('frozen') { key << '/hacknute' }
  NxTest.refute(key.equal?(p['part_overrides'].keys.first), 'plan ma drzat VLASTNU kopiu kluca')
end

NxTest.test('R-03: zmrazenie plati na hardware_overrides (pole aj jeho zaznamy)') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  hw = plan.config[:hardware_overrides]
  NxTest.assert(hw.is_a?(Array) && hw.length == 1, "fixture ma niest rucny zasah: #{hw.inspect}")
  NxTest.assert_raise('frozen') { hw << { 'generic_type' => 'leg' } }
  NxTest.assert_raise('frozen') { hw.first['quantity'] = 99 }
  NxTest.assert_raise('frozen') { hw.first['rule_id'] << 'x' }
end

NxTest.test('R-03: zmrazenie plati na hardware_sets VRATANE selectora (pasma)') do
  plan = NxR03::CB.prepare_insert(NxR03::TrapModel.new, NxR03.params)
  sets = plan.config[:hardware_sets]
  NxTest.assert_equal('SET_NOHY', sets['leg'])
  sel = sets['hinge']
  NxTest.assert(sel.is_a?(Hash) && sel['bands'].length == 2, "fixture ma niest selector: #{sel.inspect}")
  NxTest.assert_raise('frozen') { sets['leg'] = 'INY_SET' }
  NxTest.assert_raise('frozen') { sets['drawer'] = 'SET_X' }
  NxTest.assert_raise('frozen') { sel['param'] = 'height' }
  NxTest.assert_raise('frozen') { sel['bands'] << { 'min' => 0.0, 'max' => 1.0, 'set_id' => 'X' } }
  NxTest.assert_raise('frozen') { sel['bands'].first['set_id'] = 'SET_PODVRHNUTY' }
  NxTest.assert_raise('frozen') { sel['bands'].first['max'] = 5000.0 }
end

NxTest.test('R-03: params volajuceho ostanu NEMRAZENE a nezmenene (deep copy pred freeze)') do
  p = NxR03.params
  before = Marshal.load(Marshal.dump(p))
  NxR03::CB.prepare_insert(NxR03::TrapModel.new, p)
  NxTest.refute(p['bottom_mode'].frozen?, 'string volajuceho sa NESMIE zmrazit')
  NxTest.refute(p['zone_tree'].frozen?, 'hash volajuceho sa NESMIE zmrazit')
  NxTest.refute(p['fronts']['items'].frozen?, 'pole volajuceho sa NESMIE zmrazit')
  NxTest.refute(p['hardware_overrides'].frozen?, 'pole kovania volajuceho sa NESMIE zmrazit')
  NxTest.refute(p['hardware_sets']['hinge']['bands'].frozen?, 'pasma selectora volajuceho sa NESMU zmrazit')
  # POZOR: stringove kluce hasha mrazi SAM Ruby (`Hash#[]=` ich dedupuje),
  # takze na strane volajuceho sa kluce netestuju — testuje sa, ze plan drzi
  # VLASTNU kopiu kluca (test nizsie), nie ten isty objekt.
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

NxTest.test('R-03: NEKANONICKA matica s mierkou v prvku [15] sa odmieta') do
  # [15] je uniformny mierkovy DELITEL. Moderny SketchUp ho drzi kanonicky (1.0)
  # a rovnomernu mierku premieta rovno do osi — `scaling(2)` teda padne uz na
  # jednotkovosti osi. Tato kontrola je ochrana pred NEKANONICKOU / legacy
  # maticou (surove pole, matica zo starsieho suboru), ktora mierku nesie tam.
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0.5])
                ))
  # a kanonicky zapis toho isteho zvacsenia (mierka v osiach) tiez neprejde
  NxTest.refute(NxR03::CB.rigid_transform?(
                  NxR03::Tr.new([2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1])
                ))
end

NxTest.test('R-03: rigid_matrix? je cista funkcia nad 16 cislami (bez objektu)') do
  NxTest.assert(NxR03::CB.rigid_matrix?([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 5, 6, 7, 1]))
  NxTest.refute(NxR03::CB.rigid_matrix?(nil))
  NxTest.refute(NxR03::CB.rigid_matrix?([1, 0, 0]))
  NxTest.refute(NxR03::CB.rigid_matrix?(Array.new(16) { 'x' }))
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

NxTest.test('R-03/P1: snapshot transformu odmietne neregidnu maticu skor, nez cokolvek postavi') do
  # `Geom::Transformation` headless neexistuje — testujeme ODMIETACIU vetvu,
  # ktora bezi PRED zostavenim snapshotu. Kanonicka vetva je in-SU (`run_r03`).
  bad = NxR03::Tr.new([1, 0, 0, 0, 0.6, 0.8, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
  NxTest.assert_raise('Poloha vkladu') { NxR03::CB.snapshot_insert_transform!(bad) }
  NxTest.assert_raise('Poloha vkladu') { NxR03::CB.snapshot_insert_transform!(nil) }
end

NxTest.test('R-03/P2: keyword-hash volanie build(model, type:, width:) ostava platne') do
  # Pred R-03 nemal `build` ziadny keyword parameter, takze Ruby 3 taketo
  # volanie prevadzalo na POZICNY hash. Ked sa beh dostane az k zatvaraniu
  # edit kontextu, znamena to, ze keywordy sa spracovali ako params
  # (a NIE ako „unknown keyword" ArgumentError).
  m = NxR03::StuckModel.new
  NxTest.assert_raise('zavrieť otvorený komponent') do
    NxR03::CB.build(m, type: 'lower', width: 600.0, height: 720.0)
  end
  NxTest.assert(m.closes.positive?, 'build sa mal dostat az k zatvaraniu edit kontextu')
end

NxTest.test('R-03/P2: pozicny hash funguje dalej; params dvakrat = chyba volajuceho') do
  m = NxR03::StuckModel.new
  NxTest.assert_raise('zavrieť otvorený komponent') { NxR03::CB.build(m, NxR03.params) }
  m2 = NxR03::StuckModel.new
  err = NxTest.assert_raise('dvakrat') { NxR03::CB.build(m2, NxR03.params, width: 500.0) }
  NxTest.assert(err.is_a?(ArgumentError), "ocakavany ArgumentError, dostal #{err.class}")
  NxTest.assert_equal(0, m2.closes) # chyba padne PRED akymkolvek dotykom modelu
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
  body = src[/def build\(model, params = nil.*?\n        end/m].to_s
  NxTest.assert(!body.empty?, 'telo build sa nenaslo')
  NxTest.assert(body.index('ensure_root_context') < body.index('prepare_insert'),
                "ensure_root_context ma byt PRED prepare_insert: #{body}")
end

NxTest.test('R-03/P1: commit_insert pouziva SNAPSHOT, nie objekt volajuceho') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'))
  body = src[/def commit_insert\(model, plan.*?\n          inst\n        end/m].to_s
  NxTest.assert(!body.empty?, 'telo commit_insert sa nenaslo')
  NxTest.assert(body.include?('snapshot_insert_transform!'), 'commit ma robit snapshot transformu')
  # Za snapshotom uz `transform` (objekt volajuceho) nesmie nikam vstupovat —
  # jediny KODOVY riadok s nim je prave vyroba snapshotu (komentare sa nepocitaju).
  code = body.lines.reject { |l| l.strip.start_with?('#') }
  uses = code.select { |l| l =~ /\btransform\b/ }
  NxTest.assert_equal(2, uses.length, # signatura + riadok snapshotu
                      "objekt volajuceho sa smie pouzit LEN pri snapshote: #{uses.inspect}")
  NxTest.assert(uses.last.include?('snapshot_insert_transform!'),
                "posledne pouzitie `transform` ma byt snapshot: #{uses.last}")
  NxTest.assert(body.include?('placement ||'), 'dalej sa ma pouzivat VYHRADNE snapshot (placement)')
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
