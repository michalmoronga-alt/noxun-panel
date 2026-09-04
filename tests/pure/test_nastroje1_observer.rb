# frozen_string_literal: true
# NASTROJE-1 (T1a): BARIERA observera pred mutaciou nastroja + RIGIDITA cache.
#
# Co sa tu overuje:
#   * `ScaleWatch.flush_pending!` dovedie observer do POKOJA (ziadny timer,
#     prazdne fronty) — inak by jeho odlozeny tik prilepil transparentny dedup
#     na krok pouzivatela, ktory s nim nema nic spolocne;
#   * follow-up po najdenej STARSEJ duplicite nesie KONKRETNY dokument
#     (`@requested`) — holy `schedule` by dalsiu iteraciu poslal na `@last_model`,
#     teda mozno na uplne iny otvoreny subor (audit 4 BLOCKER);
#   * pri dosiahnutom strope bariera vrati `false` a fronty NECHA na pokoji;
#   * `remember_transform` (a cez neho `attach_one`) uklada LEN RIGIDNU maticu —
#     sikma matica ma osi dlzky 1, takze `scaled?` ju prepusti (audit 2/3 FIX 2).
#
# PRECO STUBY: `core/scale_observer.rb` sa v `tests/helper.rb` NENACITAVA (jeho
# triedy dedia zo `Sketchup::*Observer`). Stuby ziju PRIAMO v
# `Noxun::Engine::ScaleWatch` — Ruby ich najde lexikalne skor nez globalne
# konstanty, takze ich vidi len tento subor a `test_r01_observer_multimodel.rb`
# (rovnaky vzor). V SketchUpe by testy siahali na ZIVY observer, preto sa tam
# preskocia.
require_relative '../helper' unless defined?(NxTest)

unless NxTest::IN_SKETCHUP
  module Noxun
    module Engine
      module ScaleWatch
        module Sketchup
          class EntityObserver; end
          class EntitiesObserver; end
          class AppObserver; end
          class ComponentInstance; end

          class << self
            attr_accessor :nx_platform, :nx_active_model

            def platform
              @nx_platform ||= :platform_win
            end

            def active_model
              @nx_active_model
            end

            def add_observer(_obs)
              true
            end

            def remove_observer(_obs)
              true
            end
          end
        end

        module UI
          class << self
            # Debounce sa NESPUSTA — bariera si `process_dirty` vola sama.
            def start_timer(_sec, _repeat = false)
              @nx_timer_id = (@nx_timer_id || 0) + 1
            end

            def stop_timer(_id)
              true
            end
          end
        end
      end
    end
  end

  require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer')
end

module NxTools1Fix
  module_function

  SW = Noxun::Engine::ScaleWatch

  def sw
    SW
  end

  # Kolekcia entit dokumentu — observer si na nu vesia EntitiesObserver.
  class FakeEntities
    def add_observer(_obs)
      true
    end

    def remove_observer(_obs)
      true
    end

    def each(&_block)
      nil
    end
  end

  class FakeModel < NxTest::FakeModel
    attr_reader :guid, :entities

    def initialize(instances = [], guid = "guid-#{rand(1 << 32)}")
      super([NxTest::FakeDefinition.new(instances)])
      @guid = guid
      @entities = FakeEntities.new
    end
  end

  # Matica ako duck-type `Geom::Transformation` — staci `to_a`.
  class FakeTransform
    def initialize(values)
      @values = values
    end

    def to_a
      @values
    end
  end

  class FakeInst < NxTest::FakeInstance
    attr_reader :model
    attr_accessor :transformation

    def initialize(entity_id, model, kind = 'cabinet', transform = nil)
      super(entity_id)
      @model = model
      @transformation = transform || FakeTransform.new(NxTools1Fix::IDENTITY_M)
      set_attribute('NOXUN', 'kind', kind)
    end

    def add_observer(_obs)
      true
    end

    def remove_observer(_obs)
      true
    end
  end

  # Stlpcova matica SketchUpu: [0..2] os X · [4..6] os Y · [8..10] os Z · [12..14] posun.
  IDENTITY_M = [1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0].freeze

  # SIKMA matica: vsetky osi maju dlzku 1 (takze `scaled?` ju NEZACHYTI),
  # ale X a Y nie su kolme — skalarny sucin 0.5.
  SHEAR_M = [1.0, 0.0, 0.0, 0.0,
             0.5, Math.sqrt(0.75), 0.0, 0.0,
             0.0, 0.0, 1.0, 0.0,
             0.0, 0.0, 0.0, 1.0].freeze

  def reset!
    %i[@dirty @added @requested @prune_models @stable_transforms].each do |iv|
      sw.instance_variable_set(iv, {})
    end
    sw.instance_variable_set(:@timer, nil)
    sw.instance_variable_set(:@last_model, nil)
    sw.instance_variable_set(:@rebuilding, false)
  end

  def ivar(name)
    sw.instance_variable_get(name)
  end

  def headless_only
    NxTest.skip!('headless-only: v SketchUpe by test siahal na zivy observer') unless NxTest.headless?
  end

  # Docasna vymena singleton metody observera (sonda). VZDY v ensure spat.
  def with_stub(name, impl)
    original = sw.method(name)
    sw.define_singleton_method(name, impl)
    yield
  ensure
    sw.define_singleton_method(name) { |*args| original.call(*args) }
  end
end

NxTest.test('NASTROJE-1: bez rozrobenej prace je bariera okamzity no-op') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  NxTest.refute(f.sw.pending?, 'cisty observer nema co spracovat')
  NxTest.assert_equal(true, f.sw.flush_pending!(nil))
  NxTest.assert_equal(nil, f.ivar(:@timer))
  f.reset!
end

NxTest.test('NASTROJE-1: bariera dovedie observer do POKOJA — timer nil, fronty prazdne') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  a = f::FakeModel.new
  b = f::FakeModel.new
  # DVA dokumenty s poziadavkou (macOS) — pokoj sa nesmie vyhlasit podla jedneho.
  f.sw.request_dedup(a)
  f.sw.request_dedup(b)
  NxTest.assert_equal(2, f.ivar(:@requested).length)
  NxTest.assert(f.ivar(:@timer), 'debounce timer musi bezat')
  gen = f.ivar(:@generation).to_i

  NxTest.assert_equal(true, f.sw.flush_pending!(a))
  NxTest.assert_equal(nil, f.ivar(:@timer), 'bariera musi timer ZASTAVIT (inak dobehne po operacii)')
  NxTest.assert(f.ivar(:@generation).to_i > gen, 'generacia sa musi zvysit — prezivsi callback nesmie nic spustit')
  NxTest.assert(f.ivar(:@requested).empty?, 'fronta poziadaviek ostala neprazdna')
  NxTest.refute(f.sw.pending?, 'po bariere nesmie ostat nic rozrobene')
  f.reset!
end

NxTest.test('NASTROJE-1: pokoj sa vyhlasi az ked su prazdne fronty VSETKYCH druhov') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  m = f::FakeModel.new
  f.sw.instance_variable_set(:@prune_models, { m.object_id => m })
  NxTest.assert(f.sw.pending?, 'poziadavka o upratanie po erase je tiez rozrobena praca')
  f.reset!
  f.sw.instance_variable_set(:@dirty, { [1, 2] => nil })
  NxTest.assert(f.sw.pending?)
  f.reset!
  f.sw.instance_variable_set(:@added, { [1, 2] => nil })
  NxTest.assert(f.sw.pending?)
  f.reset!
  f.sw.instance_variable_set(:@timer, 42)
  NxTest.assert(f.sw.pending?, 'naplanovany timer sam o sebe znamena rozrobenu pracu')
  f.reset!
end

NxTest.test('NASTROJE-1: follow-up po starsej duplicite nesie KONKRETNY dokument') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  a = f::FakeModel.new
  b = f::FakeModel.new
  f.sw.instance_variable_set(:@last_model, b) # posledny znamy dokument je INY
  fresh = f::FakeInst.new(5, a)
  f.sw.instance_variable_set(:@added, { [a.object_id, 5] => fresh })

  seen = []
  cb = Noxun::Engine::CabinetBuilder
  ids = Noxun::Engine::Ids
  orig_dedup = cb.method(:dedup_copies)
  orig_dups = ids.method(:duplicate_cabinets)
  begin
    # Dedup cerstvej kopie prebehne, ale v dokumente ostane STARA duplicita.
    cb.define_singleton_method(:dedup_copies) { |*_a, **_k| [] }
    ids.define_singleton_method(:duplicate_cabinets) { |_m| [fresh] }
    f.with_stub(:schedule, lambda {
      seen << (f.ivar(:@requested) || {}).values.dup
      nil
    }) { f.sw.process_dirty }
  ensure
    cb.define_singleton_method(:dedup_copies) { |*args, **kw| orig_dedup.call(*args, **kw) }
    ids.define_singleton_method(:duplicate_cabinets) { |*args| orig_dups.call(*args) }
  end

  NxTest.assert_equal(1, seen.length, 'follow-up sa mal naplanovat prave raz')
  NxTest.assert(seen.first.include?(a),
                'model musi byt v @requested UZ PRED schedule — inak dalsia iteracia ' \
                'spracuje @last_model, teda cudzi dokument')
  NxTest.refute(seen.first.include?(b), 'do fronty sa nesmie dostat nedotknuty dokument')
  f.reset!
end

NxTest.test('NASTROJE-1: strop iteracii vrati false a fronty NECHA na pokoji') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  runs = [0]
  # Observer, ktory si donekonecna planuje pracu — bariera to musi vzdat,
  # nie sa zacyklit; a rozrobenu pracu nesmie zahodit (nastroj len odmietne).
  f.with_stub(:process_dirty, lambda {
    runs[0] += 1
    f.sw.instance_variable_set(:@requested, { 1 => :model_a })
    f.sw.instance_variable_set(:@prune_models, { 2 => :model_b })
    f.sw.schedule
    nil
  }) do
    f.sw.instance_variable_set(:@requested, { 1 => :model_a })
    NxTest.assert_equal(false, f.sw.flush_pending!(nil))
  end

  NxTest.assert_equal(Noxun::Engine::ScaleWatch::FLUSH_MAX_ITERATIONS, runs[0])
  NxTest.refute(f.ivar(:@requested).empty?, '@requested sa pri strope nesmie stratit')
  NxTest.refute(f.ivar(:@prune_models).empty?, '@prune_models sa pri strope nesmie stratit')
  NxTest.assert(f.ivar(:@timer), 'rozrobena praca ostava naplanovana — nastroj len odmietne')
  f.reset!
end

NxTest.test('NASTROJE-1: cache stabilnych transformacii berie LEN rigidnu maticu') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  m = f::FakeModel.new
  rigid = f::FakeInst.new(1, m, 'cabinet', f::FakeTransform.new(f::IDENTITY_M))
  shear = f::FakeInst.new(2, m, 'cabinet', f::FakeTransform.new(f::SHEAR_M))

  # Presne to, co stara podmienka `unless scaled?` prepustila: osi maju dlzku 1.
  NxTest.refute(f.sw.scaled?(shear.transformation), 'sikma matica ma osi dlzky 1 — `scaled?` ju nechyti')
  NxTest.refute(Noxun::Engine::CabinetBuilder.rigid_matrix?(f::SHEAR_M), 'a rigidna nie je')

  f.sw.remember_transform(rigid)
  f.sw.remember_transform(shear)
  cache = f.ivar(:@stable_transforms)
  NxTest.assert(cache.key?([m.object_id, 1]), 'rigidna poloha sa zapamatat MUSI')
  NxTest.refute(cache.key?([m.object_id, 2]),
                'sikmy stav sa nesmie „potvrdit" — odmietnuty scale by don korpus vratil')
  f.reset!
end

NxTest.test('NASTROJE-1: attach_one si rigiditu overi tou istou cestou') do
  f = NxTools1Fix
  f.headless_only
  f.reset!
  m = f::FakeModel.new
  f.sw.attach_one(f::FakeInst.new(3, m, 'cabinet', f::FakeTransform.new(f::IDENTITY_M)))
  f.sw.attach_one(f::FakeInst.new(4, m, 'cabinet', f::FakeTransform.new(f::SHEAR_M)))
  cache = f.ivar(:@stable_transforms)
  NxTest.assert(cache.key?([m.object_id, 3]))
  NxTest.refute(cache.key?([m.object_id, 4]))
  f.reset!
end
