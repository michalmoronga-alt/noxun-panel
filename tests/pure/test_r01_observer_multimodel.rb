# frozen_string_literal: true
# R-01 + R-04 (davka 1d): multi-model bezpecnost ScaleWatch.
#
# Co sa tu overuje: udalosti observera nesu v kluci AJ dokument, nie hole
# `entityID` — dva dokumenty v JEDNOM debounce okne (macOS) si udalosti
# neprepisu. Prune poziadavky su MNOZINA modelov (vzor `@requested`, D-103),
# vratane kombinacie „znamy dokument + neznamy erase". A cache
# `@stable_transforms` ma cistiace cesty (R-04) s identitou dokumentu podla
# `guid`, nie `object_id`.
#
# PRECO STUBY A PRECO SU LOKALNE: `core/scale_observer.rb` sa v `tests/helper.rb`
# NENACITAVA — jeho triedy dedia zo `Sketchup::*Observer`. GLOBALNY stub
# `Sketchup`/`UI` sa tu spravit NESMIE: `defined?(UI) && UI.respond_to?(:start_timer)`
# prepne demos klienta do asynchronnej vetvy a 43 cudzich testov spadne (overene).
# Stuby preto ziju PRIAMO v `Noxun::Engine::ScaleWatch` — Ruby ich najde
# lexikalnym vyhladavanim konstant skor nez globalne, takze vidi ich VYHRADNE
# tento jeden subor.
# V SketchUpe by testy siahali na ZIVY observer (aj na jeho debounce timer),
# preto sa tam cele preskocia.
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
            # Debounce sa v testoch NESPUSTA — scenare kontroluju stav front,
            # nie vysledok tiku (ten patri in-SketchUp sade CHAR).
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

module NxR01Fix
  module_function

  SW = Noxun::Engine::ScaleWatch

  def sw
    SW
  end

  # Duck-typing instancia korpusu/dosky. Dedi zo stubu `Sketchup::ComponentInstance`
  # — `notify_added` na tento typ testuje.
  class FakeInst < (NxTest::IN_SKETCHUP ? Object : SW::Sketchup::ComponentInstance)
    attr_reader :entityID # rubocop:disable Naming/MethodName — zrkadli SketchUp API
    attr_accessor :model

    def initialize(entity_id, model, kind = 'cabinet')
      super()
      @entityID = entity_id
      @model = model
      @dicts = { 'NOXUN' => { 'kind' => kind } }
    end

    def valid?
      true
    end

    def get_attribute(dict, key, default = nil)
      (@dicts[dict] || {}).fetch(key, default)
    end

    def set_attribute(dict, key, value)
      (@dicts[dict] ||= {})[key] = value
    end
  end

  # Dokument s `guid` (skutocny Sketchup::Model ho ma) a s definiciami,
  # cez ktore chodi hladanie zivych instancii.
  class FakeModel < NxTest::FakeModel
    attr_reader :guid

    def initialize(instances, guid)
      super([NxTest::FakeDefinition.new(instances)])
      @guid = guid
    end
  end

  # Dokument, ktoreho citanie definicii PADA (zatvarany/rozbity dokument).
  class BrokenModel < FakeModel
    def definitions
      raise 'dokument uz nie je citatelny'
    end
  end

  def model(instances = [], guid = "guid-#{rand(1 << 32)}")
    FakeModel.new(instances, guid)
  end

  # Cisty stav observera pred kazdym scenarom (a upratanie po nom).
  def reset!
    %i[@dirty @added @requested @prune_models @stable_transforms].each do |iv|
      sw.instance_variable_set(iv, {})
    end
    sw.instance_variable_set(:@last_model, nil)
    sw.instance_variable_set(:@rebuilding, false)
    sw.instance_variable_set(:@active_doc_guid, nil)
    SW::Sketchup.nx_platform = :platform_win unless NxTest::IN_SKETCHUP
    SW::Sketchup.nx_active_model = nil unless NxTest::IN_SKETCHUP
  end

  def ivar(name)
    sw.instance_variable_get(name) || {}
  end

  def headless_only
    NxTest.skip!('headless-only: v SketchUpe by test siahal na zivy observer') unless NxTest.headless?
  end
end

NxTest.test('R-01: dva dokumenty s ROVNAKYM entityID v jednom debounce okne — ziadna udalost sa nestrati') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  m1 = f.model
  m2 = f.model
  # entityID je LOKALNE pre model — dva dokumenty ho mavaju rovnake.
  a = f::FakeInst.new(7, m1)
  b = f::FakeInst.new(7, m2)
  f.sw.notify_change(a)
  f.sw.notify_change(b)
  dirty = f.ivar(:@dirty)
  NxTest.assert_equal(2, dirty.length, 'kolizia entityID nesmie prepisat udalost druheho dokumentu')
  NxTest.assert(dirty.values.include?(a) && dirty.values.include?(b))
  NxTest.assert(dirty.key?([m1.object_id, 7]) && dirty.key?([m2.object_id, 7]),
                'kluc udalosti musi niest aj dokument')
  # ...a v RAMCI jedneho dokumentu sa ta ista entita stale dedupuje na 1 zaznam
  f.sw.notify_change(a)
  NxTest.assert_equal(2, f.ivar(:@dirty).length, 'dedup v ramci dokumentu musi ostat')
  f.reset!
end

NxTest.test('R-01: to iste plati pre PRIDANIE (kopie) — @added je kluckovane dokumentom') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  m1 = f.model
  m2 = f.model
  a = f::FakeInst.new(11, m1, 'board')
  b = f::FakeInst.new(11, m2, 'board')
  f.sw.notify_added(a)
  f.sw.notify_added(b)
  added = f.ivar(:@added)
  NxTest.assert_equal(2, added.length, 'kopia v druhom dokumente nesmie prepisat prvu')
  NxTest.assert(added.key?([m1.object_id, 11]) && added.key?([m2.object_id, 11]))
  f.reset!
end

NxTest.test('R-01: prune poziadavky su MNOZINA modelov — dva erasy v dvoch dokumentoch sa nezlejú') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  m1 = f.model
  m2 = f.model
  f.sw.notify_erase(m1)
  f.sw.notify_erase(m2)
  pending = f.ivar(:@prune_models)
  NxTest.assert_equal(2, pending.length, 'jediny slot @erase_model by druhy dokument prepisal')
  NxTest.assert_equal([m1, m2].sort_by(&:object_id), pending.values.compact.sort_by(&:object_id))
  # ...a oba sa naozaj dostanu medzi ciele upratovania
  targets = f.sw.prune_targets(pending, [])
  NxTest.assert_equal(2, targets.length)
  NxTest.assert(targets.include?(m1) && targets.include?(m2))
  f.reset!
end

NxTest.test('R-01: ZNAMY dokument + NEZNAMY erase — sentinel sa nestrati (Codex audit BLOCKER 3)') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  m1 = f.model
  m2 = f.model
  f.sw.notify_erase(m1)
  f.sw.notify_erase(nil) # entita uz neplatna — dokument sa nedal zistit
  pending = f.ivar(:@prune_models)
  NxTest.assert_equal(2, pending.length, 'sentinel nesmie prepisat znamy dokument ani naopak')
  NxTest.assert(pending.values.compact == [m1], 'sentinel nepredstiera konkretny model')
  # Fallback sentinelu sa PRIDA k mnozine, nie az ked je prazdna.
  f.sw.instance_variable_set(:@last_model, m2)
  targets = f.sw.prune_targets(pending, [])
  NxTest.assert_equal(2, targets.length, 'znamy A aj fallback za neznamy B musia byt v cieloch')
  NxTest.assert(targets.include?(m1) && targets.include?(m2))
  # Ked fallback ukaze na TEN ISTY dokument, ciel je jeden (ziadne dvojite upratovanie).
  f.sw.instance_variable_set(:@last_model, m1)
  NxTest.assert_equal([m1], f.sw.prune_targets(pending, []))
  # Bez jedinej poziadavky sa neupratuje nic.
  NxTest.assert_equal([], f.sw.prune_targets({}, [m1]))
  f.reset!
end

NxTest.test('R-04: erase tick pusti z cache zaznamy zmazanych entit, cudzi dokument nechá tak') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  live = f::FakeInst.new(3, nil)
  mdl = f.model([live])
  live.model = mdl
  mid = f.sw.model_key(mdl)
  f.sw.instance_variable_set(:@stable_transforms,
                             { [mid, 3] => [1], [mid, 99] => [2], [12_345, 3] => [3] })
  f.sw.forget_dead_transforms(mdl)
  keys = f.ivar(:@stable_transforms).keys
  NxTest.assert(keys.include?([mid, 3]), 'ziva skrinka si zaznam musi udrzat')
  NxTest.refute(keys.include?([mid, 99]), 'zaznam zmazanej entity musi zmiznut')
  NxTest.assert(keys.include?([12_345, 3]), 'cudzi dokument sa erase tikom NEupratuje')
  f.reset!
end

NxTest.test('R-04: upratovanie je bezpecne — prazdna cache, cudzie kluce a rozbity dokument neprebehnu ani nepadnu') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  # (a) ked cache pre tento dokument nema ziadny kluc, model sa vobec nechodi citat
  broken = f::BrokenModel.new([], 'guid-broken')
  f.sw.instance_variable_set(:@stable_transforms, { [12_345, 1] => [1] })
  f.sw.forget_dead_transforms(broken)
  NxTest.assert_equal(1, f.ivar(:@stable_transforms).length)
  # (b) ked kluce ma, ale citanie dokumentu PADNE, vynimka sa nesmie dostat von
  #     (Codex audit FIX 5: inak by vzala aj ostatne ciele toho isteho tiku)
  f.sw.instance_variable_set(:@stable_transforms, { [f.sw.model_key(broken), 1] => [1] })
  f.sw.forget_dead_transforms(broken)
  NxTest.assert_equal(1, f.ivar(:@stable_transforms).length, 'pri chybe sa cache nemeni')
  f.reset!
end

NxTest.test('R-04: INY dokument cisti cache LEN na Windows (SDI) — macOS vetva sa jej nedotkne') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  mdl = f.model([], 'guid-A')
  novy = f.model([], 'guid-B') # File > New: na Windows nahradil jediny dokument procesu
  fresh = { [mdl.object_id, 1] => [1], [12_345, 1] => [2], [12_345, 5] => [3] }
  f.sw.instance_variable_set(:@stable_transforms, fresh.dup)
  # `install` seeduje guid aktivneho dokumentu — tu sa to simuluje
  f.sw.instance_variable_set(:@active_doc_guid, mdl.guid)
  f.sw.forget_detached_models(mdl) # ten isty dokument — nic sa nedeje
  NxTest.assert_equal(3, f.ivar(:@stable_transforms).length, 'ten isty dokument cache nemaze')
  f.sw.forget_detached_models(novy) # iny guid = iny dokument
  NxTest.assert_equal(0, f.ivar(:@stable_transforms).length,
                      'Windows: predosly dokument uz neexistuje, cela cache ide prec')
  # PRVE prepnutie po starte (kolo 2, P2): aj ked sa nie je s cim porovnat,
  # zaznamy prave zaniknuteho dokumentu NESMU prezit — `attach_all` cache
  # noveho dokumentu naplni hned za tymto volanim.
  f.reset!
  f.sw.instance_variable_set(:@stable_transforms, fresh.dup)
  f.sw.forget_detached_models(novy)
  NxTest.assert_equal(0, f.ivar(:@stable_transforms).length,
                      'prve prepnutie po starte nesmie nechat zaniknuty dokument v cache')
  # macOS: dokument v pozadi ZIJE (moze mat rozbehnuty debounce) — nemazat
  # (Codex audit BLOCKER 1: inak by odmietnuty scale prisiel o presnu polohu).
  f.reset!
  f.sw.instance_variable_set(:@stable_transforms, fresh.dup)
  NxR01Fix::SW::Sketchup.nx_platform = :platform_osx
  f.sw.forget_detached_models(mdl)
  f.sw.forget_detached_models(novy)
  NxTest.assert_equal(3, f.ivar(:@stable_transforms).length, 'macOS: cache ostava nedotknuta')
  f.reset!
end

NxTest.test('R-04: kluc cache NESMIE stat na `guid` — ten sa meni pri kazdom ULOZENI (review #261 P1)') do
  f = NxR01Fix
  f.headless_only
  f.reset!
  mdl = f.model([], 'guid-PRED-ULOZENIM')
  inst = f::FakeInst.new(42, mdl)
  key_before = f.sw.transform_key(inst)
  NxTest.assert_equal([mdl.object_id, 42], key_before)
  # Ctrl+S: SketchUp zmeni `Model#guid` (zdokumentovane v test_st1a_studio.rb),
  # ale je to TEN ISTY dokument aj ta ista entita — kluc sa meniť NESMIE,
  # inak by zapamatane polohy po ulozeni zmizli a upratovanie ich uz nenajde.
  mdl.instance_variable_set(:@guid, 'guid-PO-ULOZENI')
  NxTest.assert_equal(key_before, f.sw.transform_key(inst),
                      'ulozenie dokumentu nesmie zneplatnit zapamatane polohy')
  # ...a upratovanie na ten kluc stale dosiahne
  f.sw.instance_variable_set(:@stable_transforms, { key_before => [1] })
  f.sw.forget_dead_transforms(mdl)
  NxTest.assert_equal(0, f.ivar(:@stable_transforms).length,
                      'po zmene guid sa zaznam mrtvej entity musi dat stale zmazat')
  NxTest.assert(f.sw.model_key(nil).nil?)
  f.reset!
end
