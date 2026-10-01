# frozen_string_literal: true
# H12 (blok 9 HARDENING, C-01) — GOLDEN CHARAKTERIZACIA typov skrinky PRED
# zavedenim registra `CabinetTypes` (package H12, R0.1–R0.3, §15 A3/A4).
#
# PRECO: H12 presuva ~75 vetiev „podla mena typu" do jedneho registra. Zavazok
# bloku 9 je BEZ ZMENY vyrobnych a cenovych cisel. Fixtury v
# `tests/fixtures/h12_golden/` vznikli z NEZMENENEHO mainu (prvy commit H12a,
# generator `tests/fixtures/h12_golden/generate.rb` sa spusta RUCNE) a tento
# test porovnava CERSTVY vypocet s nimi.
#
# CO SA ODTLACA:
#   * pripady R0.2 (dolna, horna, slot 60/45, rohova obe strany, neznamy
#     a chybajuci typ, stare configy) — `normalize`, CELY `build_plan`,
#     `cabinet_config(merge_final)` BEZ `engine_version`, podpora, kontext
#     pravidiel, otvor ciel, minima vysky/hlbky/sirky, nazov, sablona,
#     preset, `home_z`, kontext niky, vlastnik spotrebica, zaznam slotu,
#     suhrny sablony, klampy absorpcie scale, symbol blendy, ghost kluc;
#   * MATICA R2.1 — kazde rozhodovacie miesto jadra nad siedmimi vstupmi
#     (`lower upper dishwasher corner_blind tall nil ''`) so SUROVYM typom,
#     teda aj vetvy, kam sa normalizovany config nikdy nedostane.
#
# POROVNANIE: JSON retazec (`JSON.pretty_generate`) — porovnava aj PORADIE
# klucov (riziko §9: poradie klucov v configu = bajty v modeli). Fixtura sa
# NEREGENERUJE kvoli refaktoru — rozdiel je NALEZ (DoD H12: „golden fixtury
# nedotknute").
#
# In-SU cast (VEPO, kusovnik, rozpocet, nakup) je `run_h12` v su_runner.rb
# a jej fixtura `insu.json` — tu sa len overi, ze existuje (bez nej by beh
# v SketchUpe ticho zachytaval namiesto porovnania).
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  %w[actions_cabinet actions_templates actions_zones payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  # ScaleWatch (klampy absorpcie) — vzor `test_roha1_rohova.rb`: observer
  # triedy nad `Sketchup::*Observer` sa na chvilu podstrcia a hned upracu.
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

module NxH12Golden
  module_function

  E  = Noxun::Engine
  CB = E::CabinetBuilder
  CN = E::Construction

  DIR = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h12_golden')
  INSU = File.join(DIR, 'insu.json')
  SEED = 7 # pevny seed pravidiel do `merge_final` (golden nesmie zavisiet od behu)

  DOOR = { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] }.freeze
  DOOR2 = { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }] }.freeze
  DRAWER_DOOR = { 'items' => [
    { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 140.0, 'locked' => true },
    { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }
  ] }.freeze

  # Stary ulozeny config (V0.1) hornej skrinky BEZ `plinth_mode` — cesta
  # `config_to_params` -> `legacy_plinth` (R0.2 posledny pripad).
  LEGACY_UPPER = { 'type' => 'upper', 'width' => 600.0, 'height' => 720.0, 'depth' => 320.0,
                   'thickness' => 18.0, 'floor_height' => 0.0, 'support' => { 'type' => 'none' },
                   'shelves' => 1, 'fronts' => 'auto' }.freeze
  LEGACY_LOWER = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
                   'thickness' => 18.0, 'floor_height' => 100.0, 'support' => { 'type' => 'plinth' },
                   'shelves' => 0, 'fronts' => 'none' }.freeze
  LEGACY_UNTYPED = { 'width' => 500.0, 'height' => 720.0, 'depth' => 510.0, 'thickness' => 18.0,
                     'floor_height' => 100.0, 'fronts' => '1' }.freeze

  # R0.2 — min. 14 pripadov. Hodnota = parametre pre `normalize` (vstup
  # vkladu/prestavby); `legacy_*` idu cez `config_to_params` ako stara zakazka.
  CASES = {
    'lower_door' => { 'type' => 'lower', 'fronts' => DOOR },
    'lower_plinth_front' => { 'type' => 'lower', 'plinth_mode' => 'front', 'fronts' => DOOR },
    'lower_floor0' => { 'type' => 'lower', 'floor_height' => 0.0, 'fronts' => DOOR },
    'lower_800_drawer' => { 'type' => 'lower', 'width' => 800.0, 'plinth_mode' => 'front', 'fronts' => DRAWER_DOOR },
    'lower_setback_rails' => { 'type' => 'lower', 'back_setback' => 50.0, 'top_front_setback' => 30.0,
                               'back_mode' => 'rails', 'back_rail_height' => 120.0, 'fronts' => DOOR },
    'upper_door' => { 'type' => 'upper', 'fronts' => DOOR },
    'upper_2wings' => { 'type' => 'upper', 'width' => 800.0, 'floor_height' => 150.0,
                        'plinth_mode' => 'front', 'fronts' => DOOR2 },
    'slot_60' => { 'type' => 'dishwasher' },
    'slot_45' => { 'type' => 'dishwasher', 'dw_class' => 450, 'width' => 450.0, 'floor_height' => 150.0,
                   'back_setback' => 50.0 },
    'corner_left' => { 'type' => 'corner_blind' },
    'corner_right_500_100' => { 'type' => 'corner_blind', 'corner_side' => 'right', 'corner_door_w' => 500.0,
                                'corner_cr1' => 100.0 },
    'corner_shelves' => { 'type' => 'corner_blind', 'width' => 1200.0, 'shelves' => 2 },
    'unknown_tall' => { 'type' => 'tall', 'height' => 2100.0, 'fronts' => DOOR },
    'missing_type' => { 'width' => 500.0, 'fronts' => DOOR },
    'legacy_upper_config' => { legacy: LEGACY_UPPER },
    'legacy_lower_config' => { legacy: LEGACY_LOWER },
    'legacy_untyped_config' => { legacy: LEGACY_UNTYPED }
  }.freeze

  # R2.1 — vstupy matice predikatov (surovy typ).
  INPUTS = ['lower', 'upper', 'dishwasher', 'corner_blind', 'tall', nil, ''].freeze

  def rt(obj)
    JSON.parse(JSON.generate(obj))
  end

  def guard
    yield
  rescue StandardError => e
    { 'error' => "#{e.class}: #{e.message}" }
  end

  def params_of(spec)
    spec.key?(:legacy) ? CB.config_to_params(rt(spec[:legacy])) : rt(spec)
  end

  def fake_inst(cfg, kind = 'cabinet')
    inst = NxTest::FakeInstance.new(1)
    inst.set_attribute('NOXUN', 'kind', kind)
    inst.set_attribute('NOXUN', 'config', JSON.generate(cfg))
    inst
  end

  def ghost(cfg, home_z)
    gt = E::GhostTool
    plan = CB::InsertPlan.new(Object.new, cfg, home_z)
    mem = { anchor: gt::ANCHORS.first, z_mode: :locked, rotation_index: 0, lock_z: {} }
    s = gt::PlacementSession.new(model: Object.new, plan: plan, memory: mem)
    { 'type_key' => s.instance_variable_get(:@type_key), 'corner' => s.corner?,
      'lock_z' => s.instance_variable_get(:@lock_z), 'memory_lock_z' => mem[:lock_z] }
  end

  def snapshot(spec)
    params = params_of(spec)
    n = CB.normalize(params)
    th = CB.aux_part_thicknesses(params, nil)
    plan = CN.build_plan(n, 'CAB-001', part_thicknesses: th)
    merged = CB.merge_final(n, plan, SEED)
    conf = CB.cabinet_config(merged)
    conf.delete(:engine_version)
    stored = rt(conf)
    back = CB.config_to_params(stored)
    sw = E::ScaleWatch
    {
      'params' => params,
      'normalize' => n,
      'plan' => plan,
      'config' => conf,
      'config_roundtrip' => CB.normalize(back),
      'support_type' => CN.support_type(n),
      'hw_ctx' => CN.cabinet_hw_ctx(n),
      'front_opening' => CN.front_opening(n),
      'min_valid' => {
        'height' => guard { CN.min_valid_height(n, part_thicknesses: th) },
        'depth' => guard { CN.min_valid_depth(n, part_thicknesses: th) },
        'width' => guard { CN.min_valid_width(n, part_thicknesses: th) }
      },
      'names' => {
        'default' => CB.default_name(n), 'display' => CB.display_name(stored),
        'template_id' => CB.template_id_for(n[:type]), 'preset' => CB.construction_preset_for(n[:type])
      },
      'home_z' => CB.prepare_insert(nil, params).home_z,
      'appliance_context' => E::ApplianceChecks.context(stored),
      'owner_kind' => E::Bom.note_appliance_owner({}, 'CAB-001', 1, stored)['CAB-001']['kind'],
      'slot_record' => E::Bom.appliance_slot_record('CAB-001', 1, stored),
      'entity_kind' => E::ApplianceBinding.entity_kind(fake_inst(stored)),
      'tpl_expects' => E::TemplateStore.appliance_expects_summary(stored),
      'tpl_construction' => E::TemplateStore.construction_summary(stored),
      'direction_blind' => E::DirectionCheck.type_symbol('blind', n[:type]),
      'scale' => {
        'min' => %w[width height depth].to_h { |k| [k, sw.min_for(k, stored['type'])] },
        'depth' => guard { sw.clamp_depth(rt(back), 100.0, 'CAB-001', th) },
        'height' => guard { sw.clamp_height(rt(back), 50.0, 'CAB-001', th) },
        'corner_width' => guard { sw.clamp_corner_width(rt(back), 300.0, 'CAB-001', th) }
      },
      'ghost' => ghost(n, CB.prepare_insert(nil, params).home_z),
      'corner_thicknesses' => CB.corner_thicknesses(n, {})
    }
  end

  # Zakladny ulozeny config (dolna, po stavbe) — matica don vlozi surovy typ.
  def base_cfg
    n = CB.normalize('type' => 'lower', 'fronts' => DOOR)
    plan = CN.build_plan(n, 'CAB-001')
    CB.merge_final(n, plan, SEED).merge(
      dw_class: 600, dw_body_height: 820.0, dw_front_bottom: 100.0, dw_front_height: 778.0,
      corner_side: 'left', corner_door_w: 450.0, corner_cr1: 80.0, corner_cr2: 80.0,
      back_setback: 50.0, top_front_setback: 30.0, back_rail_height: 120.0, back_mode: 'rails'
    )
  end

  def matrix_row(t, base)
    stored = rt(CB.cabinet_config(base)).merge('type' => t)
    raw_sym = base.merge(type: t)
    pan = E::Panel
    {
      'defaults_for' => CB.defaults_for(t),
      'preset' => CB.construction_preset_for(t),
      'template_id' => CB.template_id_for(t),
      'default_name' => CB.default_name({ 'type' => t, 'width' => 600.0, 'dw_class' => 450 }),
      'auto_name_corner' => CB.auto_name?('Rohová skrinka 900', t),
      'auto_name_lower' => CB.auto_name?('Spodná skrinka 600', t),
      'sanitize_corner' => CB.sanitize_name('Rohová skrinka 900', t),
      'legacy_plinth' => CB.send(:legacy_plinth, { 'type' => t, 'floor_height' => 100.0 }),
      'config_to_params_type' => CB.config_to_params({ 'type' => t })['type'],
      'normalize_type' => CB.normalize({ 'type' => t })[:type],
      'cabinet_config' => guard { (c = CB.cabinet_config(raw_sym)).delete(:engine_version) && c },
      'home_z' => CB.prepare_insert(nil, { 'type' => t }).home_z,
      'corner_thicknesses' => CB.corner_thicknesses({ type: t }, {}),
      'support_type' => CN.support_type({ type: t, floor_height: 100.0, plinth_mode: 'front' }),
      'support_type_floor0' => CN.support_type({ type: t, floor_height: 0.0, plinth_mode: 'front' }),
      'hw_ctx_type' => CN.cabinet_hw_ctx(raw_sym)['cabinet_type'],
      'front_opening' => guard { CN.front_opening(raw_sym) },
      'corner_sym' => CN.corner?({ type: t }),
      'corner_str' => CN.corner?({ 'type' => t }),
      'setback_value' => CN.setback_value(raw_sym, :back_setback),
      'back_rails' => CN.back_rails?(raw_sym),
      'min_valid_depth' => guard { CN.min_valid_depth(raw_sym) },
      'min_valid_height' => guard { CN.min_valid_height(raw_sym) },
      'build_plan_parts' => guard { CN.build_plan(raw_sym, 'CAB-001')[:parts].map { |p| p[:part_key] } },
      'scale_min' => %w[width height depth].to_h { |k| [k, E::ScaleWatch.min_for(k, t)] },
      'appliance_context_empty' => E::ApplianceChecks.context(stored).empty?,
      'owner_kind' => E::Bom.note_appliance_owner({}, 'CAB-001', 1, stored)['CAB-001']['kind'],
      'slot_record_nil' => E::Bom.appliance_slot_record('CAB-001', 1, stored).nil?,
      'entity_kind' => E::ApplianceBinding.entity_kind(fake_inst(stored)),
      'tpl_expects' => E::TemplateStore.appliance_expects_summary(stored),
      'tpl_construction' => E::TemplateStore.construction_summary(stored),
      'direction_blind' => E::DirectionCheck.type_symbol('blind', t),
      'ghost' => ghost({ type: t, width: 600.0, height: 720.0, depth: 510.0, thickness: 18.0,
                         floor_height: 100.0, bottom_mode: 'under_sides' }, 0.0),
      # Panel (H12b ich napoji; odtlacok uz teraz — matica A2 obojsmerne).
      'apply_template_type' => (INPUTS + ['UPPER']).to_h do |w|
        cfg = t.nil? ? {} : { 'type' => t }
        msg = pan.apply_template_type!(cfg, w)
        [w.inspect, [msg, cfg['type']]]
      end,
      'corner_change_refusal' => INPUTS.to_h do |w|
        [w.inspect, pan.corner_change_refusal({ 'type' => t }, { 'type' => w })]
      end,
      'corner_side_refusal' => pan.corner_change_refusal({ 'type' => t, 'corner_side' => 'left' },
                                                         { 'corner_side' => 'right' })
    }
  end

  def matrix
    base = base_cfg
    INPUTS.to_h { |t| [t.inspect, matrix_row(t, base)] }
  end

  def pretty(obj)
    JSON.pretty_generate(rt(obj)) + "\n"
  end

  def case_path(name)
    File.join(DIR, "case_#{name}.json")
  end

  def matrix_path
    File.join(DIR, 'matrix.json')
  end
end

if NxTest.headless?
  NxH12Golden::CASES.each do |name, spec|
    NxTest.test("H12 golden: #{name} — plan, config a vetvy typu bez zmeny") do
      path = NxH12Golden.case_path(name)
      NxTest.assert(File.exist?(path), "chyba fixtura #{path} (generator tests/fixtures/h12_golden/generate.rb)")
      want = File.read(path, encoding: 'UTF-8').gsub("\r\n", "\n")
      got = NxH12Golden.pretty(NxH12Golden.snapshot(spec))
      NxTest.assert(got == want, "golden #{name} sa rozisiel s fixturou — vyrobne cisla alebo vetva typu sa zmenili")
    end
  end

  NxTest.test('H12 golden: matica 7 vstupov (lower upper dishwasher corner_blind tall nil "") bez zmeny') do
    want = File.read(NxH12Golden.matrix_path, encoding: 'UTF-8').gsub("\r\n", "\n")
    got = NxH12Golden.pretty(NxH12Golden.matrix)
    unless got == want
      w = JSON.parse(want)
      g = JSON.parse(got)
      diff = w.keys.flat_map do |t|
        (w[t].keys | g[t].to_h.keys).reject { |k| w[t][k] == g[t].to_h[k] }.map { |k| "#{t}.#{k}" }
      end
      NxTest.assert(false, "matica sa rozisla: #{diff.first(12).join(', ')}")
    end
  end
end

NxTest.test('H12 golden: in-SU fixtura insu.json existuje (run_h12 inak len zachytava)') do
  NxTest.assert(File.exist?(NxH12Golden::INSU), 'chyba tests/fixtures/h12_golden/insu.json — zachyti ju run_h12 na NEZMENENOM kode')
  data = JSON.parse(File.read(NxH12Golden::INSU, encoding: 'UTF-8'))
  NxTest.assert_equal(6, Array(data['cabinets']).length, 'insu.json nesie sest skriniek (§8)')
  %w[bom vepo_csv vepo_log purchase_csv expansion budget control].each do |k|
    NxTest.assert(data.key?(k), "insu.json nesie #{k}")
  end
  NxTest.refute(data['vepo_log'].to_s.include?('Verzia:'), 'LOG bez riadku Verzia: (§15 A4)')
  NxTest.assert(Array(data.dig('expansion', 'rows')).any?, 'nakup ma neprazdne mapovanie setov (§15 A3)')
end
