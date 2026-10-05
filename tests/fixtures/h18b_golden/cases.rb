# frozen_string_literal: true
# H18b R0: jeden vstup matice; PRED vzniklo na c6bba0b, pred editom pluginu.
require_relative '../h18_golden/cases'
require_relative '../../../noxun_engine/ui/templates_dialog'
require 'digest'

module NxH18b
  HS = NxH18::HS
  E = NxH18::E
  P = NxH18::P
  DIR = __dir__
  BASE = 'c6bba0b96d96efc63b0f90c9083e77b66bd98d52'
  module_function

  def copy(x) = NxH18.copy(x)
  def definitions
    HS.normalize_sets(copy(HS::SEED_SETS) + [
      { 'set_id' => 'moj-zaves', 'name' => 'Môj záves', 'generic_type' => 'hinge',
        'members' => [{ 'code' => 'X1', 'per' => 'unit', 'qty' => 1 }] },
      { 'set_id' => 'blum-tipon', 'name' => 'Blum Tip-On záves', 'generic_type' => 'hinge',
        'use_type' => 'door', 'opening_mode' => 'tipon', 'manufacturer' => 'Blum', 'series' => 'Tip-On',
        'members' => [{ 'code' => 'B1', 'per' => 'unit', 'qty' => 1 }] }
    ]).to_h { |s| [s['set_id'], s] }
  end
  def state = { 'sets' => definitions, 'mapping' => NxH18.seed_mapping }
  def kinds
    d = NxH18
    [ ['tipon', d.door('tipon', 'front:F1/wing:single')],
      ['classic', d.door('classic', 'front:F1/wing:left')],
      ['fall', d.door('classic', 'front:F1/flap')],
      ['legacy_door', d.item('hinge', 'front:F1/wing:single')],
      ['quadro', d.item('slide', 'front:F1/panel', { 'opening_mode' => 'classic', 'drawer_construction' => 'wood', 'system' => 'quadro_v6' })],
      ['atira', d.slide('front:F1/panel')],
      ['legacy_slide', d.item('slide', 'front:F1/panel')],
      ['hk', d.item('lift', 'front:F1/flap', { 'use_type' => 'lift', 'opening_mode' => 'classic', 'lift_system' => 'hk_top' })],
      ['no_system', d.item('lift', 'front:F1/flap', { 'use_type' => 'lift', 'opening_mode' => 'classic' })],
      ['legacy_lift', d.item('lift', 'front:F1/flap')],
      ['leg', d.item('leg', 'zone:Z1')]]
  end
  def values = ['zaves-p2o', 'zaves-klasik', 'moj-zaves', 'blum-tipon', 'vysuv-quadro-v6-sisy', HS::MAPPING_NONE, nil, '']
  def maps(owner)
    [{}, { 'hinge' => 'moj-zaves' }, { 'class:hinge|tipon' => 'zaves-p2o' },
     { "hinge@#{owner}" => 'moj-zaves' }, { 'hinge@front:F1/flap' => 'zaves-klasik' },
     { 'slide@front:F1/panel' => 'vysuv-quadro-v6-sisy' },
     { 'class:slide|classic|metal@front:F1/panel' => HS::MAPPING_ADDITIONS['class:slide|classic|metal'] },
     { "hinge@#{owner}" => '' }]
  end
  def cases
    kinds.flat_map do |name, item|
      [nil, item['owner_part_key']].flat_map do |owner|
        values.each_with_index.flat_map do |value, vi|
          maps(item['owner_part_key']).each_with_index.flat_map do |map, mi|
            [false, true].map do |known|
              { 'id' => "#{name}/#{owner ? 'owner' : 'cab'}/v#{vi}/m#{mi}/#{known}",
                'kind' => name, 'item' => item, 'owner' => owner, 'value' => copy(value), 'map' => copy(map), 'known' => known }
            end
          end
        end
      end
    end
  end
  def apply(c)
    HS.apply_cabinet_override({ 'hardware' => [c['item']], 'hardware_sets' => c['map'] },
                             c['item']['generic_type'], c['owner'], c['value'], known_sets: c['known'] ? definitions : nil)
  end
  # Dedup zachova plnych 2816 kombinacii pod limitom 300 kB.
  def packed
    pool = []
    indexes = cases.map do |c|
      value = apply(c)
      i = pool.index(value)
      i || (pool << value; pool.length - 1)
    end
    { 'base' => BASE, 'pool' => pool, 'indexes' => indexes }
  end
  def fixture(name) = JSON.parse(File.read(File.join(DIR, name + '.json')))
  def baseline
    f = fixture('zapis_pred')
    f['indexes'].map { |i| f['pool'][i] }
  end
  def cabinet(name)
    fronts = case name
             when 'TIP1' then [{ 'id' => 'F1', 'type' => 'door', 'wings' => '1', 'opening_mode' => 'tipon' }]
             when 'CLS2' then [{ 'id' => 'F1', 'type' => 'door', 'wings' => '2' }]
             when 'FALL' then [{ 'id' => 'F1', 'type' => 'fall' }]
             when 'MIX' then [{ 'id' => 'F1', 'type' => 'door', 'wings' => '1', 'mode' => 'fixed', 'height' => 900.0, 'opening_mode' => 'tipon' },
                              { 'id' => 'F2', 'type' => 'door', 'wings' => '2' }]
             end
    cfg = E::CabinetBuilder.normalize('width' => 900.0, 'height' => 2100.0, 'depth' => 500.0,
                                      'fronts' => { 'items' => fronts })
    plan = E::Construction.build_plan(cfg, 'CAB-1', hardware_rules: E::HardwareRules.normalize_rules(copy(E::HardwareRules::SEED_RULES)))
    # Rovnako ako ulozeny config/BOM: pravidlove polozky z planu este owner_id nemaju.
    cfg.merge('cabinet_id' => 'CAB-1', 'hardware' => plan[:hardware].map { |it| it.merge('owner_id' => 'CAB-1') })
  end
  def scenarios
    [ ['R1','TIP1',{},'blum-tipon',true], ['R2','TIP1',{'hinge@front:F1/wing:single'=>'moj-zaves'},'blum-tipon',true],
      ['R3','TIP1',{'hinge@front:F1/wing:single'=>'moj-zaves'},'',true], ['R4','CLS2',{'hinge'=>'moj-zaves'},'zaves-klasik',true],
      ['R5','FALL',{},'zaves-klasik',true], ['R6','TIP1',{},'zaves-klasik',true],
      ['R7','MIX',{'hinge'=>'moj-zaves'},'blum-tipon',true], ['R8','MIX',{},'zaves-p2o',false] ].map do |id, name, map, value, owner|
      cfg = cabinet(name).merge('hardware_sets' => map)
      key = owner ? cfg['hardware'].find { |it| it['generic_type'] == 'hinge' }.fetch('owner_part_key') : nil
      { 'id' => id, 'cfg' => cfg, 'owner' => key, 'value' => value }
    end
  end
  def expansion(cfg, map)
    HS.expand(cfg['hardware'], state, cabinet_overrides: { 'CAB-1' => map }, catalog: NxH18.catalog)
  end
  def scenario(c)
    cfg = c['cfg']
    result = HS.apply_cabinet_override(cfg, 'hinge', c['owner'], c['value'], known_sets: definitions)
    map = result[0] == :ok ? result[1] : cfg['hardware_sets']
    normalized = E::CabinetBuilder.norm_hardware_sets(map, cfg['fronts'])
    refs = result[0] == :ok ? result[2].map { |sid| definitions[sid] } : []
    { 'result' => result, 'normalized' => normalized, 'before' => expansion(cfg, cfg['hardware_sets']),
      'after' => expansion(cfg, normalized), 'status' => result[0] == :ok ? P.hw_set_status_msg('hinge', c['owner'], c['value'], refs) : result[1] }
  end
  def purchases = scenarios.to_h { |c| [c['id'], scenario(c)] }
  def payloads
    scenarios.select { |c| %w[R1 R2 R4].include?(c['id']) }.to_h do |c|
      result = scenario(c)
      cfg = c['cfg'].merge('hardware_sets' => result['normalized'])
      context = { 'status' => 'ok', 'state' => state }
      payload = NxH18.context(context) { P.hardware_set_options(cfg, cfg['hardware']) }
      [c['id'], { 'owner' => c['owner'], 'value' => c['value'], 'payload' => payload }]
    end
  end
  GUARDED = {
    'noxun_engine/core/hardware_sets.rb' => %w[override_class_key classified_value_problem parse_class_key resolve_mapping_value resolve_mapping_source],
    'noxun_engine/core/cabinet_builder.rb' => %w[norm_hardware_sets],
    'noxun_engine/ui/panel/actions_hardware.rb' => %w[handle_set_hardware_set]
  }.freeze
  def hashes
    GUARDED.each_with_object({}) do |(file, names), out|
      src = File.read(File.join(NxTest::ROOT, file)).gsub("\r\n", "\n")
      names.each do |name|
        indent = src[/^( +)def #{name}\b/, 1]
        body = src[/^#{indent}def #{name}\b.*?^#{indent}end\n/m]
        # R2 meni len komentar parsera; executable telo zostava pripnute.
        code = body.lines.reject { |line| line.lstrip.start_with?('#') }.join
        out[file + '#' + name] = Digest::SHA256.hexdigest(code)
      end
    end
  end
end
