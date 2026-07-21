# frozen_string_literal: true
# Headless testy pre Noxun::Engine::Debug — read-only diagnostika musi byt nacitatelna
# a bezpecna AJ bez SketchUpu: report/model_info/selection_state/panel_state nesmu
# spadnut a musia vratit error-safe strukturu; entity_state cita NOXUN dict cez
# get_attribute fallback (FakeEntity nema attribute_dictionary) a prezije poskodene
# vstupy (neplatny JSON, non-string config, getter s vynimkou, chybajuca definicia).
require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'debug')

# Entita, ktorej get_attribute hodi vynimku — read_dict ju musi zniest (nález 14).
module NxTest
  class RaisingEntity
    def get_attribute(*)
      raise 'simulovana chyba get_attribute'
    end
  end
end

NxTest.test('debug: report headless vrati validny JSON so vsetkymi sekciami') do
  json = Noxun::Engine::Debug.report
  NxTest.assert(json.is_a?(String), 'report vracia String')
  data = JSON.parse(json)
  %w[engine_version timestamp model selection panel].each do |k|
    NxTest.assert(data.key?(k), "report chyba kluc #{k}")
  end
end

NxTest.test('debug: model_info headless je error-safe hash (bez SketchUpu)') do
  info = Noxun::Engine::Debug.model_info
  NxTest.assert(info.is_a?(Hash), 'model_info je Hash')
  NxTest.assert(info.key?(:error), 'headless model_info ma :error')
end

NxTest.test('debug: selection_state headless je error-safe') do
  st = Noxun::Engine::Debug.selection_state
  NxTest.assert(st.is_a?(Hash), 'selection_state je Hash')
  NxTest.assert(st.key?(:error), 'headless selection_state ma :error')
end

NxTest.test('debug: panel_state headless hlasi nenacitany Panel') do
  st = Noxun::Engine::Debug.panel_state
  NxTest.assert(st.is_a?(Hash), 'panel_state je Hash')
  NxTest.assert(st.key?(:error), 'headless panel_state ma :error (Panel nenacitany)')
end

NxTest.test('debug: entity_state cita NOXUN dict cez get_attribute fallback + config parse') do
  dict = Noxun::Engine::Store::DICT
  e = NxTest::FakeInstance.new(42)
  e.set_attribute(dict, 'kind', 'cabinet')
  e.set_attribute(dict, 'id', 'CAB-001')
  e.set_attribute(dict, 'config', '{"width":600.0}')
  st = Noxun::Engine::Debug.entity_state(e)
  NxTest.assert_equal('cabinet', st[:instance_attributes]['kind'])
  NxTest.assert_equal('CAB-001', st[:instance_attributes]['id'])
  NxTest.assert_equal(600.0, st[:instance_attributes]['config_parsed']['width'])
  NxTest.assert_equal(42, st[:entity_id])
end

NxTest.test('debug: entity_state pre poskodeny JSON config vrati chybu, nie vynimku') do
  dict = Noxun::Engine::Store::DICT
  e = NxTest::FakeInstance.new(7)
  e.set_attribute(dict, 'kind', 'board')
  e.set_attribute(dict, 'config', '{neplatny json')
  st = Noxun::Engine::Debug.entity_state(e)
  cfg = st[:instance_attributes]['config_parsed']
  NxTest.assert(cfg.is_a?(Hash), 'config_parsed je Hash aj pri poskodenom JSON')
  NxTest.assert(cfg.key?('error'), 'poskodeny config ma error')
end

NxTest.test('debug: entity_state pre non-string config vrati diagnosticku chybu') do
  dict = Noxun::Engine::Store::DICT
  e = NxTest::FakeInstance.new(8)
  e.set_attribute(dict, 'kind', 'board')
  e.set_attribute(dict, 'config', 12_345) # nie String
  st = Noxun::Engine::Debug.entity_state(e)
  cfg = st[:instance_attributes]['config_parsed']
  NxTest.assert(cfg.is_a?(Hash) && cfg.key?('error'), 'non-string config -> {error}')
end

NxTest.test('debug: entity_state bez definition metody hlasi :absent (headless FakeInstance)') do
  dict = Noxun::Engine::Store::DICT
  e = NxTest::FakeInstance.new(9)
  e.set_attribute(dict, 'kind', 'cabinet')
  st = Noxun::Engine::Debug.entity_state(e)
  NxTest.assert_equal(:absent, st[:definition_attributes])
end

NxTest.test('debug: entity_state znesie get_attribute, ktory hadze vynimku') do
  st = Noxun::Engine::Debug.entity_state(NxTest::RaisingEntity.new)
  NxTest.assert(st.is_a?(Hash), 'vrati hash, nespadne')
  NxTest.assert(st[:instance_attributes].nil?, 'zlyhany getter -> ziadne atributy (nil)')
end

NxTest.test('debug: entity_state pre nil a nepodporovany typ vrati error hash') do
  NxTest.assert(Noxun::Engine::Debug.entity_state(nil)[:error], 'nil -> error')
  NxTest.assert(Noxun::Engine::Debug.entity_state(42)[:error], 'Integer bez dict pristupu -> error')
end

NxTest.test('debug: report je JSON-safe aj pri symbolovych/:absent hodnotach') do
  # report ide cez json_safe; JSON.parse padne, ak by v strukture ostal symbol/objekt.
  json = Noxun::Engine::Debug.report
  data = JSON.parse(json)
  NxTest.assert(data['panel'].is_a?(Hash), 'panel sekcia je hash')
end

NxTest.test('debug: noxun_free? chodi cez definitions ako runner guard (Codex GH #63)') do
  dict = Noxun::Engine::Store::DICT
  inst = NxTest::FakeInstance.new(11)
  inst.set_attribute(dict, 'kind', 'cabinet')
  model = NxTest::FakeModel.new([NxTest::FakeDefinition.new([inst])])
  NxTest.assert_equal(false, Noxun::Engine::Debug.send(:noxun_free?, model))

  empty = NxTest::FakeModel.new([])
  NxTest.assert_equal(true, Noxun::Engine::Debug.send(:noxun_free?, empty))
end
