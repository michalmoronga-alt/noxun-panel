# frozen_string_literal: true
require_relative 'test_cela_b_profily'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine/ui/production_core')
  require File.join(NxTest::ROOT, 'noxun_engine/ui/panel/actions_cabinet')
  require File.join(NxTest::ROOT, 'noxun_engine/ui/panel/payloads')
  require File.join(NxTest::ROOT, 'noxun_engine/ui/templates_dialog')
end

NxTest.test('CELA-B: blokovany vyber oznami problem v povodnom okne a model necita') do
  status = []; pushed = 0
  Noxun::Engine::ProductionCore.do_select(nil, { 'gen' => 7, 'flush_blocked' => true }, generation: 7,
    status: ->(*v) { status << v }, repush: -> { pushed += 1 })
  NxTest.assert_equal(0, pushed)
  NxTest.assert_equal(1, status.length)
  NxTest.assert(status.first.first.include?('Výber sa nevykonal'))
  NxTest.assert_equal(true, status.first.last)
end

NxTest.test('CELA-B: sablona zo Studia ide cez flush a po nom kontroluje povodny vyber aj dokument') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine/ui/studio_dialog.rb'), encoding: 'UTF-8')
  mod = Module.new
  %w[handle_tpl do_tpl_after_flush].each do |name|
    body = src[/        def #{name}\(.*?\n        end\n/m]
    NxTest.assert(body, "#{name} existuje")
    mod.module_eval("extend self\n#{body}")
  end
  model = Struct.new(:path).new('test.skp')
  cab = { 'cabinet_id' => 'CAB-A' }
  selection = [cab]; alive = true; sent = []; applied = []; status = []
  panel = Module.new
  panel.define_singleton_method(:dialog_alive?) { alive }
  panel.define_singleton_method(:selected_cabinets) { |_m| selection }
  panel.define_singleton_method(:js) { |s| sent << s }
  su = Module.new; su.define_singleton_method(:active_model) { model }
  store = Module.new; store.define_singleton_method(:get) { |item, key| item[key] }
  { Panel: panel, Sketchup: su, Store: store, DocKey: Noxun::Engine::DocKey,
    TemplatesDialog: Noxun::Engine::TemplatesDialog,
    ProductionCore: Noxun::Engine::ProductionCore }.each { |key, value| mod.const_set(key, value) }
  mod.define_singleton_method(:do_tpl) { |name, payload| applied << [name, JSON.parse(payload)] }
  mod.define_singleton_method(:tpl_sink) { ->(s) { status << s } }
  payload = { 'template' => 'Test' }.to_json
  mod.handle_tpl('tpl_apply', payload)
  NxTest.assert_equal([], applied)
  data = JSON.parse(sent.first.sub('NX.studioRelayTemplate(', '').sub(/\)\z/, ''))
  NxTest.assert_equal('CAB-A', data['cabinet_id'])
  mod.do_tpl_after_flush(data.merge('flush_blocked' => true))
  mod.do_tpl_after_flush(data.merge('model_guid' => 'foreign'))
  selection = [{ 'cabinet_id' => 'CAB-B' }]; mod.do_tpl_after_flush(data)
  NxTest.assert_equal([], applied)
  NxTest.assert_equal(3, status.length)
  selection = [cab]; mod.do_tpl_after_flush(data)
  NxTest.assert_equal([['tpl_apply', { 'template' => 'Test' }]], applied)
  alive = false; mod.handle_tpl('tpl_apply', payload)
  NxTest.assert_equal(2, applied.length)
  NxTest.assert(src.include?('cb(dlg, name) { |p| handle_tpl(name, p) }'), 'skutocny callback pouziva vstup s flushom')
end

NxTest.test('CELA-B: preflight panela vrati identity aj sloty bez modelu a odmietne chybne cisla') do
  c = NxCelaB
  f = c::F.normalize_config(c.config('door', 'free', 'wings' => '3'))
  data = { 'fronts' => f, 'width' => 600.0, 'height' => 720.0, 'floor_height' => 0.0,
           'model_guid' => 'doc', 'cabinet_id' => '', 'insert_session' => 9, 'revision' => 21 }
  out = c::E::Panel.front_preflight_result(data)
  NxTest.refute(out['valid'])
  NxTest.assert_equal(21, out['revision'])
  NxTest.assert_equal('p2', out['slots']['F1']['slots'][0]['wing'])
  [nil, '600x', false, Float::INFINITY].each do |bad|
    out = c::E::Panel.front_preflight_result(data.merge('width' => bad))
    NxTest.refute(out['valid'])
    NxTest.assert_equal(9, out['insert_session'])
  end
end

