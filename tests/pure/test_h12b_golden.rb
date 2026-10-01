# frozen_string_literal: true
# H12b (blok 9 HARDENING, C-01) — GOLDEN CHARAKTERIZACIA PANELA (Ruby) PRED
# napojenim `ui/panel/*` a `templates_dialog.rb` na register `CabinetTypes`
# (package H12 §6 R0.3, R2.4, R2.5; §15 A2).
#
# H12a uz odtlacila `apply_template_type!` a `corner_change_refusal` (matica
# v `matrix.json`). Tu pribuda ZVYSOK rozhodovacich miest panela nad siedmimi
# vstupmi (`lower upper dishwasher corner_blind tall nil ''`):
#   * `actions_cabinet` — preflight ciel (slot / rohova / korpus, vkladanie aj
#     oznacena skrinka), `slot_params?`, polia sablony (slot, rohova), odmietnutia
#     ciel slotu a rohovej, veta rohovej sablony, prepinac strany rohovej;
#   * `actions_templates` — ocakavania sablony (vlastnik spotrebica);
#   * `actions_zones` — odmietnutie delenia zony (rohova);
#   * `actions_appliance` — vlastnik spotrebica (cil, montaz, ocakavania);
#   * `payloads` — `slot_payload`, kresba rohovej, `template_config_from`;
#   * `sync` — predvolby typov do `NX.init` (poradie klucov JSON);
#   * `templates_dialog` — typovy guard pouzitia sablony OBOJSMERNE (A2: `''`,
#     chybajuci typ, `lower`, neznamy neprazdny — kazdy proti kazdemu) a veta
#     rohovej sablony; slovo typu vo vete.
#
# Fixtura `tests/fixtures/h12_golden/panel.json` vznikla na NEZMENENOM kode
# (prvy commit H12b, generator `generate.rb`) a NEREGENERUJE sa — rozdiel je
# NALEZ. Akcie, ktore inak siahaju do modelu, sa volaju so STUBMI (vyber,
# sklad sablon, status) a zastavia sa `throw` hned za typovou vetvou.
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  %w[actions_cabinet actions_templates actions_zones actions_appliance payloads sync].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  unless defined?(Noxun::Engine::ScaleWatch)
    su = Module.new
    %w[EntityObserver EntitiesObserver AppObserver].each { |c| su.const_set(c, Class.new) }
    Object.const_set(:Sketchup, su)
    begin
      require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer')
    ensure
      Object.send(:remove_const, :Sketchup)
    end
  end
end

module NxH12bGolden
  module_function

  E  = Noxun::Engine
  CB = E::CabinetBuilder
  CN = E::Construction

  PATH = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h12_golden', 'panel.json')
  INPUTS = ['lower', 'upper', 'dishwasher', 'corner_blind', 'tall', nil, ''].freeze
  SEED = 7
  PASS = 'PRESLO TYPOVOU VETVOU'
  CORNER_STUB = { 'stub' => 'corner_insert_defaults' }.freeze

  DOOR = { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }.freeze
  GAPS = { 'gap' => 3.0, 'gap_top' => 3.0, 'gap_bottom' => 3.0, 'gap_left' => 3.0, 'gap_right' => 3.0 }.freeze
  TWO_DOORS = GAPS.merge('items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' },
                                     { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }]).freeze
  ONE_DOOR = GAPS.merge('items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }]).freeze
  EXTRA = { 'dw_class' => 600, 'dw_body_height' => 820.0, 'dw_front_bottom' => 100.0,
            'corner_side' => 'right', 'corner_door_w' => 500.0, 'corner_cr1' => 100.0, 'corner_cr2' => 80.0 }.freeze

  def rt(obj)
    JSON.parse(JSON.generate(obj))
  end

  def guard
    yield
  rescue StandardError => e
    { 'error' => "#{e.class}: #{e.message}" }
  end

  # `t` nil = kluc `type` CHYBA (nie `"type": null`).
  def typed(hash, t)
    h = rt(hash)
    t.nil? ? h.delete('type') : h['type'] = t
    h
  end

  # Docasne nahradi metodu objektu (modul Panel, TemplatesDialog, sklad…)
  # a po bloku ju vrati aj s viditelnostou.
  def with_stubs(stubs)
    saved = stubs.map do |obj, name, _impl|
      sc = obj.singleton_class
      vis = if sc.private_method_defined?(name) then :private
            elsif sc.protected_method_defined?(name) then :protected
            else :public
            end
      # Metoda nemusi byt headless nacitana (napr. `resolvers.rb`) — po bloku zmizne.
      [obj, name, obj.respond_to?(name, true) ? obj.method(name) : nil, vis]
    end
    stubs.each { |obj, name, impl| obj.define_singleton_method(name, &impl) }
    yield
  ensure
    Array(saved).each do |obj, name, orig, vis|
      if orig
        obj.define_singleton_method(name, orig)
        obj.singleton_class.send(vis, name)
      else
        obj.singleton_class.send(:remove_method, name)
      end
    end
  end

  # Akcie si beru `Sketchup.active_model` — headless sa na chvilu podstrci.
  def with_sketchup
    defined = Object.const_defined?(:Sketchup)
    unless defined
      su = Module.new
      su.define_singleton_method(:active_model) { :h12b_model }
      Object.const_set(:Sketchup, su)
    end
    yield
  ensure
    Object.send(:remove_const, :Sketchup) if !defined && Object.const_defined?(:Sketchup)
  end

  def fake_inst(cfg, cid = 'CAB-001')
    inst = NxTest::FakeInstance.new(1)
    inst.set_attribute('NOXUN', 'kind', 'cabinet')
    inst.set_attribute('NOXUN', 'cabinet_id', cid)
    inst.set_attribute('NOXUN', 'config', JSON.generate(cfg))
    inst.define_singleton_method(:persistent_id) { 4242 }
    inst
  end

  # Ulozeny config dolnej po stavbe + polia slotu aj rohovej; typ surovy.
  def stored_base
    @stored_base ||= begin
      n = CB.normalize('type' => 'lower', 'fronts' => DOOR)
      plan = CN.build_plan(n, 'CAB-001')
      conf = CB.cabinet_config(CB.merge_final(n, plan, SEED))
      conf.delete(:engine_version)
      rt(conf).merge(EXTRA)
    end
  end

  def stored(t)
    typed(stored_base, t)
  end

  def preflight_data(t)
    typed({ 'width' => 900.0, 'height' => 720.0, 'floor_height' => 100.0, 'fronts' => ONE_DOOR,
            'revision' => 1, 'insert_session' => 1 }.merge(EXTRA), t)
  end

  def tpl_cfg(t)
    typed({ 'width' => 600.0, 'fronts' => TWO_DOORS, 'appliance_expects' => ['oven'] }.merge(EXTRA), t)
  end

  # Stub-lambda bezi so `self` = stubovany objekt — hodnoty sa pripravia VONKU.
  def with_tpl(cfg, &blk)
    json = JSON.generate('kind' => 'cabinet', 'name' => 'X', 'config' => cfg)
    with_stubs([[E::TemplateStore, :find, ->(*_a) { JSON.parse(json) }]], &blk)
  end

  # Typovy guard `TemplatesDialog.handle_apply`: status (odmietnutie) alebo
  # PASS (preslo typom aj vetou rohovej — zastavene `throw` pred prestavbou).
  def tpl_apply(cab_cfg, tpl_cfg)
    td = E::TemplatesDialog
    cab = fake_inst(cab_cfg)
    status = nil
    json = JSON.generate('kind' => 'cabinet', 'name' => 'X', 'config' => tpl_cfg)
    out = with_sketchup do
      with_stubs([[E::TemplateStore, :find, ->(*_a) { JSON.parse(json) }],
                  [E::Panel, :selected_cabinets, ->(_m) { [cab] }],
                  [E::Panel, :existing_params, ->(_c) { throw :h12b_pass, PASS }],
                  [td, :set_status, ->(msg, _err = false) { status = msg }]]) do
        catch(:h12b_pass) do
          td.handle_apply({ 'template' => 'X' }.to_json)
          status
        end
      end
    end
    out
  end

  # Prepinac strany rohovej: veta „len rohova" alebo PASS (zastavene pred
  # zrkadlenim — `Construction.corner_side` hned za typovou vetvou).
  def corner_side(cab_cfg)
    pan = E::Panel
    cab = fake_inst(cab_cfg)
    status = nil
    with_sketchup do
      with_stubs([[pan, :parse, ->(p) { JSON.parse(p) }],
                  [pan, :foreign_document?, ->(*_a) { false }],
                  [pan, :corner_side_target, ->(*_a) { cab }],
                  [E::ScaleWatch, :flush_pending!, ->(_m) { true }],
                  [pan, :set_status, ->(msg, _err = false) { status = msg }],
                  [pan, :push_selected, ->(*_a, **_k) { nil }],
                  [pan, :js, ->(_s) { nil }],
                  [CN, :corner_side, ->(_p) { throw :h12b_pass, PASS }]]) do
        catch(:h12b_pass) do
          pan.handle_corner_side({ 'cabinet_id' => 'CAB-001', 'corner_side' => 'left' }.to_json)
          status
        end
      end
    end
  end

  def appliance(cab_cfg)
    pan = E::Panel
    cab = fake_inst(cab_cfg)
    target = guard { pan.send(:appliance_cabinet_target, cab, {}) }
    mount = with_stubs([[pan, :find_cabinet, ->(_m) { cab }]]) do
      guard { pan.send(:appliance_mount_target, :h12b_model, { 'cabinet_id' => 'CAB-999' }).last }
    end
    kind = nil
    with_stubs([[pan, :appliance_expects_entity, ->(_m, _i, k, *_r) { kind = k }]]) do
      pan.send(:appliance_expects_cabinet, :h12b_model, cab, {})
    end
    { 'cabinet_target' => target, 'mount_msg' => mount, 'expects_kind' => kind }
  end

  # Predvolby do `NX.init` (sync.rb). Po H12b ich sklada `Panel.init_defaults`;
  # pred nim boli literal v `push_init` — ten isty JSON (poradie klucov).
  def init_defaults
    pan = E::Panel
    if pan.respond_to?(:init_defaults)
      with_stubs([[pan, :corner_insert_defaults, ->(_m) { CORNER_STUB }]]) { pan.init_defaults(:h12b_model) }
    else
      { lower: CB::LOWER_DEFAULTS, upper: CB::UPPER_DEFAULTS, dishwasher: CB::DISHWASHER_DEFAULTS,
        corner_blind: CORNER_STUB }
    end
  end

  def row(t)
    pan = E::Panel
    data = preflight_data(t)
    st = stored(t)
    ins_src = pan.send(:corner_preflight_src, data, nil)
    {
      'slot_params' => pan.send(:slot_params?, typed({}, t)),
      'corner_src_insert' => !ins_src.nil?,
      'corner_src_stored' => !pan.send(:corner_preflight_src, {}, st).nil?,
      'opening_cfg' => pan.send(:preflight_opening_cfg, data, ins_src, [900.0, 720.0, 100.0]),
      'preflight_insert' => guard { pan.send(:front_preflight_result, data, nil) },
      'preflight_stored' => guard { pan.send(:front_preflight_result, data, st) },
      'slot_fronts_refusal' => pan.send(:slot_fronts_refusal, typed({}, t), TWO_DOORS),
      'corner_fronts_refusal' => pan.send(:corner_fronts_refusal, typed({ 'corner_side' => 'left' }, t), TWO_DOORS),
      'template_slot_fields' => with_tpl(tpl_cfg(t)) do
        pan.send(:apply_template_slot_fields!, { 'type' => 'lower', 'width' => 600.0 }, %w[cabinet X])
      end,
      'corner_template_refusal' => with_tpl(tpl_cfg(t)) { pan.send(:corner_template_refusal, %w[cabinet X]) },
      'template_expects' => begin
        cfg = typed({}, t)
        [pan.send(:apply_template_expects!, cfg, ['oven']), cfg]
      end,
      'split_refusal' => guard { pan.send(:split_refusal, { cab: fake_inst(st), path: [] }) },
      'appliance' => appliance(st),
      'slot_payload' => guard { pan.send(:slot_payload, st) },
      'corner_preview' => guard { pan.send(:corner_preview_json, CB.config_to_params(st), {}) },
      'template_config_from' => guard { pan.template_config_from(st) },
      'corner_side' => corner_side(st),
      'tpl_dialog_corner_refusal' => INPUTS.to_h do |w|
        [w.inspect, E::TemplatesDialog.corner_template_apply_refusal(st, tpl_cfg(w))]
      end,
      # A2: OBOJSMERNA matica typoveho guardu — riadok = typ SKRINKY,
      # stlpec = typ SABLONY (`''`, chybajuci, `lower`, neznamy…).
      'tpl_dialog_apply' => INPUTS.to_h { |w| [w.inspect, tpl_apply(st, typed(tpl_cfg(w), w))] }
    }
  end

  def snapshot
    {
      'template_type_words' => E::Panel::TEMPLATE_TYPE_WORDS,
      'init_defaults' => init_defaults,
      'rows' => INPUTS.to_h { |t| [t.inspect, row(t)] }
    }
  end

  def pretty(obj)
    JSON.pretty_generate(rt(obj)) + "\n"
  end
end

if NxTest.headless?
  NxTest.test('H12b golden: panel Ruby nad 7 vstupmi (preflight, sablony, zony, spotrebic, payloady, typovy guard) bez zmeny') do
    path = NxH12bGolden::PATH
    NxTest.assert(File.exist?(path), "chyba fixtura #{path} (generator tests/fixtures/h12_golden/generate.rb)")
    want = File.read(path, encoding: 'UTF-8').gsub("\r\n", "\n")
    got = NxH12bGolden.pretty(NxH12bGolden.snapshot)
    unless got == want
      w = JSON.parse(want)
      g = JSON.parse(got)
      diff = (w['rows'] || {}).keys.flat_map do |t|
        (w['rows'][t].keys | g['rows'][t].to_h.keys).reject { |k| w['rows'][t][k] == g['rows'][t].to_h[k] }
                                                   .map { |k| "#{t}.#{k}" }
      end
      diff += %w[template_type_words init_defaults].reject { |k| w[k] == g[k] }
      NxTest.assert(false, "panel golden sa rozisiel: #{diff.first(12).join(', ')}")
    end
  end
end
