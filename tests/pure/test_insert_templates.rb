# frozen_string_literal: true
# Davka Vkladanie (D-32/D-33) — headless testy:
#   1) IMUTABILITA SABLON (audit N11): seed sa dokonci PRED snapshotom JSON;
#      insert zo sablony (mutacia vratenej kopie + normalize) NESMIE zmenit
#      subor sablon na disku ani hodnoty v store (TemplateStore vracia deep copy).
#   2) PRESNA KOPIA (B3, datova cast): config_to_params nesie VSETKO, co
#      handle_insert_copy potrebuje — materialy, part_overrides,
#      hardware_overrides, cela, zony, nazov (build z tychto params = kopia).
# SketchUp cast (skutocny insert + erase) bezi v tests/sketchup/su_runner.rb.
require_relative '../helper'

module NxTest
  E = Noxun::Engine

  test('sablony N11: seed pred snapshotom, insert zo sablony subor nemeni') do
    skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?

    E::TemplateStore.reload!            # cisty cache nad testovacim APPDATA
    list = E::TemplateStore.load        # seed sa dokonci TU (ensure_seeded)
    assert(list.length >= 4, 'seed predvolenych sablon')
    snapshot = File.binread(E::TemplateStore.path) # snapshot AZ PO seede (N11)

    tpl = E::TemplateStore.find('Dolna klasik')
    assert(!tpl.nil?, 'sablona Dolna klasik existuje')

    # "Insert zo sablony": payload vznika z config sablony; pouzivatel/normalize
    # ho lubovolne mutuje — vratane VNORENYCH struktur (zone_tree, fronts).
    params = tpl['config']
    params['width'] = 999.0
    params['zone_tree']['shelves'] = 4 if params['zone_tree'].is_a?(Hash)
    (params['fronts']['items'] ||= []) << { 'id' => 'FX', 'type' => 'door' } if params['fronts'].is_a?(Hash)
    cfg = E::CabinetBuilder.normalize(params)
    assert_close(999.0, cfg[:width], 0.01, 'normalize vidi mutovane params')

    # Store aj disk ostavaju netknute: load vracia deep copy, insert NIC nezapisuje.
    fresh = E::TemplateStore.find('Dolna klasik')
    assert_close(600.0, fresh['config']['width'], 0.01, 'store drzi povodnu sirku 600')
    assert_equal(0, fresh['config']['zone_tree']['shelves'].to_i, 'store drzi povodne zony')
    assert_equal([], fresh['config']['fronts']['items'] || [], 'store drzi povodne cela')
    assert_equal(snapshot, File.binread(E::TemplateStore.path),
                 'templates.json byte-nezmeneny (insert/edit sablonu NIKDY neprepise)')
  end

  test('sablony N11: upsert ineho mena nemeni existujuce zaznamy') do
    skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?

    E::TemplateStore.reload!
    before = E::TemplateStore.find('Horna klasik')
    E::TemplateStore.upsert('N11 docasna', { 'type' => 'lower', 'width' => 450.0 })
    after = E::TemplateStore.find('Horna klasik')
    assert_equal(before, after, 'cudzi upsert nezmenil existujucu sablonu')
    E::TemplateStore.delete('N11 docasna')
    assert(E::TemplateStore.find('N11 docasna').nil?, 'docasna sablona uprataná')
  end

  test('kopia B3: config_to_params nesie materialy, overridy, cela, zony aj nazov') do
    stored = {
      'type' => 'lower', 'width' => 640.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'bottom_mode' => 'under_sides', 'top_mode' => 'two_rails', 'back_mode' => 'overlay',
      'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 40.0,
      'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
      'name' => 'Drezova A',
      'material_id' => 'K009_PW_DTDL_18', 'front_material_id' => 'FRONT_W_18',
      'back_material_id' => 'HDF_WHITE_3',
      'part_key_schema' => Noxun::Engine::PartKeys::SCHEMA,
      'part_overrides' => { 'cabinet/side:left' => { 'material_id' => 'K009_PW_DTDL_18',
                                                     'edges' => { 'L1' => 'ABS_K009_10' } } },
      'hardware_overrides' => [{ 'owner_part_key' => nil, 'generic_type' => 'leg',
                                 'rule_id' => 'legs_default', 'quantity' => 6 }],
      'fronts' => { 'split_axis' => 'height', 'gap' => 3.0, 'items' => [
        { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }
      ] },
      'zone_tree' => { 'id' => 'Z1', 'shelves' => 2, 'children' => [] }
    }
    p1 = E::CabinetBuilder.config_to_params(stored)
    assert_equal('K009_PW_DTDL_18', p1['material_id'], 'kopia nesie material korpusu')
    assert_equal('FRONT_W_18', p1['front_material_id'], 'kopia nesie material ciel')
    assert_equal('HDF_WHITE_3', p1['back_material_id'], 'kopia nesie material chrbta')
    assert_equal('Drezova A', p1['name'], 'kopia nesie nazov')
    assert(p1['part_overrides'].key?('cabinet/side:left'), 'kopia nesie part_overrides')
    assert_equal(6, p1['hardware_overrides'][0]['quantity'], 'kopia nesie hardware_overrides')
    assert_equal(1, p1['fronts']['items'].length, 'kopia nesie cela')
    assert_equal(2, p1['zone_tree']['shelves'].to_i, 'kopia nesie strom zon')

    # Roundtrip stability: params -> normalize -> params sa uz nemenia (kopia kopie = kopia).
    cfg = E::CabinetBuilder.normalize(p1)
    json_cfg = JSON.parse(JSON.generate(cfg)) # simulacia zapisu configu na instanciu
    p2 = E::CabinetBuilder.config_to_params(json_cfg)
    %w[type width height depth thickness material_id front_material_id back_material_id name].each do |k|
      assert_equal(p1[k], p2[k], "roundtrip drzi #{k}")
    end
    assert_equal(p1['part_overrides'], p2['part_overrides'], 'roundtrip drzi part_overrides')
    assert_equal(p1['hardware_overrides'], p2['hardware_overrides'], 'roundtrip drzi hardware_overrides')
  end
end
