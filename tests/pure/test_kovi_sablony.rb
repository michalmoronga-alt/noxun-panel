# frozen_string_literal: true
# KOV-I: volba celeho kovania, pravdivy suhrn a zachovanie konstrukcie.
require_relative 'test_h2_sablony_kovanie'

module NxKovi
  E = Noxun::Engine
  HW_KEYS = %w[hardware_sets hardware_set_defs hardware_manual].freeze
  module_function

  def source
    { 'type' => 'lower', 'width' => 650.0, 'height' => 720.0, 'depth' => 560.0,
      'thickness' => 18.0, 'material_id' => 'MAT', 'front_material_id' => 'FRONT',
      'back_material_id' => 'BACK', 'drawer_material_id' => 'DRAWER',
      'part_overrides' => { 'cabinet/side:left' => { 'material_id' => 'PART' } },
      'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] },
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer',
                                'drawer' => { 'construction' => 'metal', 'system' => 'atira',
                                              'recipe_refs' => { 'atira|sisy' => 'atira_sisy_v1' } } }] },
      'hardware_sets' => { 'hinge' => 'zaves-klasik' },
      'hardware_overrides' => [{ 'rule_id' => 'r', 'generic_type' => 'slide',
                                'owner_part_key' => 'front:F1/panel', 'nominal_length' => 450 }],
      'hardware_manual' => [{ 'id' => 'KOVI-1', 'owner_part_key' => nil, 'source' => 'free',
                              'name' => 'Zámok', 'unit' => 'ks', 'price_eur_vat' => 10.0,
                              'qty' => 2, 'note' => '' }] }
  end

  def stub(mod, name, impl)
    original = mod.method(name)
    mod.define_singleton_method(name, impl)
    yield
  ensure
    mod.define_singleton_method(name, original)
  end
end

NxTest.test('KOV-I: vypnute kovanie vynecha vsetky tri kluce, konstrukcia a materialy ostanu') do
  source = NxKovi.source
  copy = Marshal.load(Marshal.dump(source))
  model = NxH2.project_with({ 'zaves-klasik' => NxH2.norm('zaves-klasik', 'hinge', 'SNAP') })
  yes = NxH2::PANEL.template_config_from(source, model: model, with_hardware: true)
  no = NxH2::PANEL.template_config_from(source, model: model, with_hardware: false)
  NxKovi::HW_KEYS.each { |k| NxTest.refute(no.key?(k), k) }
  NxTest.assert_equal(yes.reject { |k, _| NxKovi::HW_KEYS.include?(k) }, no)
  %w[material_id front_material_id back_material_id drawer_material_id].each do |k|
    NxTest.assert_equal(source[k], no[k], k)
  end
  NxTest.assert_equal(650.0, no['width'])
  NxTest.assert_equal(source['zone_tree'], no['zone_tree'])
  NxTest.assert_equal('atira', no['fronts']['items'].first['drawer']['system'])
  NxTest.assert_equal(source['fronts']['items'].first['drawer']['recipe_refs'],
                      no['fronts']['items'].first['drawer']['recipe_refs'])
  NxTest.refute(no.key?('part_overrides'))
  NxTest.refute(yes.key?('hardware_overrides'), 'R12 zamky nie su prenosne')
  NxTest.assert_equal(copy, source, 'ulozenie zdroj nemutuje')
ensure
  NxH2.wipe_library!
end

NxTest.test('KOV-I: zapnute je spatne kompatibilny default aj pre rucne polozky') do
  cfg = NxKovi.source
  model = NxH2.project_with({ 'zaves-klasik' => NxH2.norm('zaves-klasik', 'hinge', 'SNAP') })
  implicit = NxH2::PANEL.template_config_from(cfg, model: model)
  explicit = NxH2::PANEL.template_config_from(cfg, model: model, with_hardware: true)
  NxTest.assert_equal(implicit, explicit)
  NxTest.assert_equal('SNAP', explicit['hardware_set_defs']['zaves-klasik']['members'].first['code'])
  NxTest.assert_equal('Zámok', explicit['hardware_manual'].first['name'])
  NxTest.assert_equal(2.0, explicit['hardware_manual'].first['qty'])
ensure
  NxH2.wipe_library!
end

NxTest.test('KOV-I: vypnute kovanie sa nepokusi citat ani overovat zdroj kovania') do
  calls = 0
  NxKovi.stub(NxH2::PANEL, :add_template_hardware, ->(*) { calls += 1; raise 'necitat' }) do
    NxKovi.stub(NxH2::HWS, :normalize_mapping, ->(*) { calls += 1; raise 'neoverovat' }) do
      tc = NxH2::PANEL.template_config_from(NxKovi.source, model: Object.new, with_hardware: false)
      note = NxH2::PANEL.template_save_hardware_note(NxKovi.source, tc, Object.new, with_hardware: false)
      NxTest.assert_equal('', note)
    end
  end
  NxTest.assert_equal(0, calls, 'ani pokus skryty rescue vetvou')
end

NxTest.test('KOV-I: poskodeny snapshot odstrani aj rucne polozky a vysvetli ulozenie BEZ kovania') do
  NxH2.wipe_library!
  model = NxH2::Model.new('{ zly JSON')
  tc = NxH2::PANEL.template_config_from(NxKovi.source, model: model)
  NxKovi::HW_KEYS.each { |k| NxTest.refute(tc.key?(k), k) }
  NxTest.assert_equal(650.0, tc['width'])
  NxTest.assert_equal('MAT', tc['material_id'])
  note = NxH2::PANEL.template_save_hardware_note(NxKovi.source, tc, model)
  NxTest.assert(note.include?('Šablóna uložená BEZ kovania') && note.include?('poškodené'), note)
  NxTest.refute(NxKovi::E::TemplateStore.hardware_summary(tc)['has'])
ensure
  NxH2.wipe_library!
end

NxTest.test('KOV-I: nekompatibilna kniznica znamena bez celeho kovania a skutocny dovod') do
  NxH2.wipe_library!
  model = NxH2.project_with({ 'zaves-klasik' => NxH2.norm('zaves-klasik', 'hinge', 'SNAP') })
  NxKovi.stub(NxH2::HWS, :library_read_only?, -> { true }) do
    NxKovi.stub(NxH2::HWS, :library_state_reason, -> { 'aktualizuj plugin' }) do
      tc = NxH2::PANEL.template_config_from(NxKovi.source, model: model)
      NxKovi::HW_KEYS.each { |k| NxTest.refute(tc.key?(k), k) }
      note = NxH2::PANEL.template_save_hardware_note(NxKovi.source, tc, model)
      NxTest.assert(note.include?('BEZ kovania') && note.include?('aktualizuj plugin'), note)
    end
  end
ensure
  NxH2.wipe_library!
end

NxTest.test('KOV-I: prazdne chybajuce a chybne tvary nenesli badge len pre samotne definicie') do
  [nil, {}, { 'hardware_sets' => {}, 'hardware_manual' => [] },
   { 'hardware_sets' => [], 'hardware_manual' => {} },
   { 'hardware_set_defs' => { 'SET' => { 'name' => 'Samotna definicia' } } }].each do |cfg|
    NxTest.assert_equal({ 'has' => false, 'sets' => [], 'manual_count' => 0 },
                        NxKovi::E::TemplateStore.hardware_summary(cfg))
  end
end

NxTest.test('KOV-I: suhrn pouzije mena zo snapshotu a fallback na ID bez citania globalu') do
  cfg = { 'hardware_sets' => { 'hinge' => 'H', 'leg' => 'L' },
          'hardware_set_defs' => { 'H' => { 'name' => 'Klasik' } } }
  before = Marshal.load(Marshal.dump(cfg))
  NxKovi.stub(NxH2::HWS, :load, -> { raise 'suhrn nesmie citat global' }) do
    sum = NxKovi::E::TemplateStore.hardware_summary(cfg)
    NxTest.assert_equal(true, sum['has'])
    NxTest.assert_equal([{ 'generic_type' => 'hinge', 'label' => 'Závesy', 'set_name' => 'Klasik' },
                         { 'generic_type' => 'leg', 'label' => 'Nohy', 'set_name' => 'L' }], sum['sets'])
    NxTest.assert_equal(0, sum['manual_count'])
  end
  NxTest.assert_equal(before, cfg, 'suhrn zdroj nemutuje')
end

NxTest.test('KOV-I: triedne selektory pomenuju vsetky pasma bez duplicit') do
  selector = NxH2.selector('front_height',
                          [{ 'min' => 0, 'max' => 120, 'set_id' => 'A' },
                           { 'min' => 121, 'max' => 400, 'set_id' => 'B' }])
  cfg = { 'hardware_sets' => { 'class:slide|classic|metal' => selector, 'slide' => 'A' },
          'hardware_set_defs' => [{ 'set_id' => 'A', 'name' => 'Atira H70' },
                                  { 'set_id' => 'B', 'name' => 'Atira H144' }] }
  sum = NxKovi::E::TemplateStore.hardware_summary(cfg)
  NxTest.assert_equal(%w[slide slide], sum['sets'].map { |s| s['generic_type'] })
  NxTest.assert_equal(['Atira H70', 'Atira H144'], sum['sets'].map { |s| s['set_name'] })
end

NxTest.test('KOV-I: len rucne polozky maju badge a spolocny lahky suhrn pocet zachova') do
  store = NxKovi::E::TemplateStore
  manual = NxKovi.source['hardware_manual']
  NxTest.assert_equal({ 'has' => true, 'sets' => [], 'manual_count' => 1 },
                      store.hardware_summary('hardware_manual' => manual))
  NxTest.assert_equal({ 'has' => true, 'labels' => ['1 ručná položka'] },
                      store.hardware_tile_summary('hardware_manual' => manual))
  NxTest.assert_equal(['Závesy: H', '+2 ručné položky'],
                      store.hardware_tile_summary('hardware_sets' => { 'hinge' => 'H' },
                                                  'hardware_manual' => manual * 2)['labels'])
end

NxTest.test('KOV-I: explicitne bez setu sa prenasa a badge tuto volbu prizna') do
  cfg = { 'hardware_sets' => { 'hinge' => NxH2::HWS::MAPPING_NONE } }
  NxTest.assert_equal({ 'has' => true, 'labels' => ['Závesy: bez setu'] },
                      NxKovi::E::TemplateStore.hardware_tile_summary(cfg))
end

NxTest.test('KOV-I: vklad bez kovania nenesie override, pouzije projektovy set') do
  tc = NxH2::PANEL.template_config_from(NxKovi.source, with_hardware: false)
  NxTest.assert_equal([:ok, nil], NxH2::PANEL.take_insert_hardware!(tc))
  cfg = NxH2::CB.normalize(tc)
  NxTest.assert_equal({}, cfg[:hardware_sets])
  sid, = NxH2::HWS.resolve_set_id('hinge', {}, cfg[:hardware_sets], { 'hinge' => 'PROJEKT' })
  NxTest.assert_equal('PROJEKT', sid)
end

NxTest.test('KOV-I: aplikacia sablony bez kovania zachova kovanie existujucej skrinky') do
  target = { 'hardware_sets' => { 'hinge' => 'CIEL' },
             'hardware_manual' => NxKovi.source['hardware_manual'] }
  tc = NxH2::PANEL.template_config_from(NxKovi.source, with_hardware: false)
  merged = NxH2::TD.merge_template(target, tc)
  NxTest.assert_equal(target['hardware_sets'], merged['hardware_sets'])
  NxTest.assert_equal(target['hardware_manual'], merged['hardware_manual'])
end

NxTest.test('KOV-I: panel aj Studio maju zhodny odvodeny suhrn a subor ostava nezmeneny') do
  NxTest.skip!('globalne sablony len headless') unless NxTest.headless?
  store = NxKovi::E::TemplateStore
  name = '__KOVI_TRANSIENT__'
  cfg = { 'type' => 'lower', 'hardware_manual' => NxKovi.source['hardware_manual'] }
  NxTest.assert(store.upsert('cabinet', name, cfg))
  bytes = File.binread(store.path)
  rec = NxH2::PANEL.template_list(kind: 'cabinet', usage: false).find { |t| t['name'] == name }
  NxTest.assert_equal({ 'has' => true, 'labels' => ['1 ručná položka'] }, rec['hardware'])
  NxTest.assert_equal(rec['hardware'], NxH2::TD.tile_row(rec)['hardware'])
  rec['hardware']['labels'] << 'cudzia zmena'
  NxTest.refute(store.find('cabinet', name).key?('hardware'))
  NxTest.assert_equal(bytes, File.binread(store.path))
ensure
  store.delete('cabinet', name) if store && name
end

NxTest.test('KOV-I: nezname data zaznamu aj configu preziju normalizaciu bez novej schemy') do
  raw = { 'name' => 'Future', 'kind' => 'cabinet', 'future' => 8,
          'config' => { 'future_nested' => { 'k' => 9 } } }
  normalized = NxKovi::E::TemplateStore.normalize_list([raw]).first
  NxTest.assert_equal(raw, normalized)
  normalized['config']['future_nested']['k'] = 0
  NxTest.assert_equal(9, raw['config']['future_nested']['k'])
end

NxTest.test('KOV-I: save handler prenasa volbu do ulozenia aj hlasky') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine/ui/panel/actions_templates.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("with_hardware = data['with_hardware'] != false"), 'default pre starsi klient')
  NxTest.assert(src.include?('template_config_from(cab_cfg, model: model, with_hardware: with_hardware)'))
  NxTest.assert(src.include?('template_save_hardware_note(cab_cfg, config, model, with_hardware: with_hardware)'))
end
