# frozen_string_literal: true
# Testy cisto vypoctovych metod CabinetBuilder (normalize, config_to_params,
# legacy migracie, resolve_part retaz, cabinet_config). Ziadna geometria/model.
require_relative '../helper' unless defined?(NxTest)

# ---------------------------------------------------------------------------
# normalize
# ---------------------------------------------------------------------------

NxTest.test('builder: normalize bez params vrati lower defaulty') do
  cb = Noxun::Engine::CabinetBuilder
  cfg = cb.normalize(nil)
  NxTest.assert_equal('lower', cfg[:type])
  NxTest.assert_close(600.0, cfg[:width])
  NxTest.assert_close(720.0, cfg[:height])
  NxTest.assert_close(510.0, cfg[:depth])
  NxTest.assert_close(18.0, cfg[:thickness])
  NxTest.assert_close(100.0, cfg[:floor_height])
  NxTest.assert_equal('under_sides', cfg[:bottom_mode])
  NxTest.assert_equal('full', cfg[:top_mode])
  NxTest.assert_equal('overlay', cfg[:back_mode])
  NxTest.assert_close(3.0, cfg[:back_thickness])
  NxTest.assert_equal('none', cfg[:plinth_mode])
  NxTest.assert_close(40.0, cfg[:plinth_recess])
  NxTest.assert_close(100.0, cfg[:rail_depth])
  NxTest.assert_equal('flat', cfg[:rails_orientation])
  NxTest.assert_close(0.0, cfg[:rails_top_offset])
  NxTest.assert_equal(nil, cfg[:material_id])
  NxTest.assert_equal(nil, cfg[:front_material_id])
  NxTest.assert_equal(nil, cfg[:back_material_id])
  NxTest.assert_equal({}, cfg[:part_overrides])
  NxTest.assert_equal(0, cfg[:part_key_schema])
  NxTest.assert(cfg[:fronts].is_a?(Hash), 'fronts ma byt kanonicky hash')
  NxTest.assert_equal([], cfg[:fronts]['items'])
  NxTest.assert(cfg[:zone_tree].is_a?(Hash), 'zone_tree ma byt hash')
  NxTest.assert_equal('Z1', cfg[:zone_tree]['id'])
  NxTest.assert_equal(0, cfg[:zone_tree]['shelves'])
end

NxTest.test('builder: normalize upper defaulty + vynutene floor_height/plinth') do
  cb = Noxun::Engine::CabinetBuilder
  cfg = cb.normalize('type' => 'upper', 'floor_height' => 250, 'plinth_mode' => 'front')
  NxTest.assert_equal('upper', cfg[:type])
  NxTest.assert_close(320.0, cfg[:depth]) # upper default hlbka
  NxTest.assert_equal('between_sides', cfg[:bottom_mode])
  NxTest.assert_equal('groove', cfg[:back_mode])
  # upper NEMA sokel ani podstavec - vstupy sa ignoruju
  NxTest.assert_close(0.0, cfg[:floor_height])
  NxTest.assert_equal('none', cfg[:plinth_mode])
end

NxTest.test('builder: normalize clampuje rozmery na realne hranice') do
  cb = Noxun::Engine::CabinetBuilder
  cfg = cb.normalize('width' => 5000, 'height' => 1, 'depth' => 5000,
                     'thickness' => 1, 'back_thickness' => 0.2,
                     'plinth_recess' => 999, 'rail_depth' => 5, 'rails_top_offset' => 900)
  NxTest.assert_close(3000.0, cfg[:width])       # max 3000
  NxTest.assert_close(200.0, cfg[:height])       # MIN[:height]
  NxTest.assert_close(2000.0, cfg[:depth])       # max 2000
  NxTest.assert_close(6.0, cfg[:thickness])      # min 6
  NxTest.assert_close(1.0, cfg[:back_thickness]) # min 1
  NxTest.assert_close(300.0, cfg[:plinth_recess])
  NxTest.assert_close(20.0, cfg[:rail_depth])    # min 20
  NxTest.assert_close(500.0, cfg[:rails_top_offset])

  cfg2 = cb.normalize('width' => 10, 'depth' => 10, 'thickness' => 200,
                      'floor_height' => -50, 'rail_depth' => 999)
  NxTest.assert_close(200.0, cfg2[:width])   # MIN[:width]
  NxTest.assert_close(150.0, cfg2[:depth])   # MIN[:depth]
  NxTest.assert_close(50.0, cfg2[:thickness]) # max 50
  NxTest.assert_close(0.0, cfg2[:floor_height]) # min 0 (lower)
  NxTest.assert_close(400.0, cfg2[:rail_depth]) # max 400
  cfg3 = cb.normalize('floor_height' => 900)
  NxTest.assert_close(500.0, cfg3[:floor_height]) # max 500
end

NxTest.test('builder: normalize neplatne enumy padnu na defaulty') do
  cb = Noxun::Engine::CabinetBuilder
  cfg = cb.normalize('bottom_mode' => 'xxx', 'top_mode' => 'xxx', 'back_mode' => 'xxx',
                     'rails_orientation' => 'xxx', 'plinth_mode' => 'xxx')
  NxTest.assert_equal('under_sides', cfg[:bottom_mode])
  NxTest.assert_equal('full', cfg[:top_mode])
  NxTest.assert_equal('overlay', cfg[:back_mode])
  NxTest.assert_equal('flat', cfg[:rails_orientation])
  NxTest.assert_equal('none', cfg[:plinth_mode])
  # platne hodnoty preziju
  cfg2 = cb.normalize('top_mode' => 'two_rails', 'back_mode' => 'groove',
                      'rails_orientation' => 'upright')
  NxTest.assert_equal('two_rails', cfg2[:top_mode])
  NxTest.assert_equal('groove', cfg2[:back_mode])
  NxTest.assert_equal('upright', cfg2[:rails_orientation])
  # norm_type: len presne 'upper' je upper (case-sensitive), symbolove kluce funguju
  NxTest.assert_equal('lower', cb.normalize('type' => 'UPPER')[:type])
  NxTest.assert_equal('upper', cb.normalize(type: 'upper')[:type])
end

NxTest.test('builder: normalize prazdny string -> default, legacy shelves/fronts string') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert_close(600.0, cb.normalize('width' => '')[:width])
  NxTest.assert_close(450.0, cb.normalize(width: '450')[:width])
  # legacy shelves -> koren zone_tree so shelves
  cfg = cb.normalize('shelves' => 3)
  NxTest.assert_equal(3, cfg[:zone_tree]['shelves'])
  # legacy fronts string -> kanonicky hash s 1 door polozkou
  cfg2 = cb.normalize('fronts' => '2')
  items = cfg2[:fronts]['items']
  NxTest.assert_equal(1, items.size)
  NxTest.assert_equal('door', items[0]['type'])
  NxTest.assert_equal('auto', items[0]['mode'])
  NxTest.assert_equal('2', items[0]['wings'])
end

# ---------------------------------------------------------------------------
# config_to_params (legacy V0.1 vetvy)
# ---------------------------------------------------------------------------

NxTest.test('builder: config_to_params prelozi legacy V0.1 vnorene hashe na ploche kluce') do
  cb = Noxun::Engine::CabinetBuilder
  legacy = {
    'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
    'thickness' => 18.0, 'floor_height' => 100.0,
    'bottom' => { 'mode' => 'under_sides' },
    'top' => { 'mode' => 'full_panel' },          # stary nazov -> 'full'
    'back' => { 'mode' => 'inset', 'thickness' => 5.0 },
    'support' => { 'type' => 'plinth' },
    'shelves' => 2,
    'fronts' => '2',
    'material_id' => 'K009_PW_DTDL_18'            # legacy natvrdo - NEprebera sa
  }
  params = cb.config_to_params(legacy)
  NxTest.assert_equal('under_sides', params['bottom_mode'])
  NxTest.assert_equal('full', params['top_mode'])
  NxTest.assert_equal('inset', params['back_mode'])
  NxTest.assert_close(5.0, params['back_thickness'])
  NxTest.assert_equal('front', params['plinth_mode']) # support.type == 'plinth'
  NxTest.assert_close(50.0, params['plinth_recess'])  # default bez ulozenej hodnoty
  # legacy shelves -> zone_tree koren
  NxTest.assert_equal(2, params['zone_tree']['shelves'])
  # legacy fronts string prejde migraciou na hash, wings '2' prezije
  NxTest.assert(params['fronts'].is_a?(Hash), 'fronts sa maju znormalizovat na hash')
  NxTest.assert_equal('2', params['fronts']['items'][0]['wings'])
  # legacy config bez part_overrides = V0.2 -> materialy sa NEpreberaju (dedia z projektu)
  NxTest.assert_equal(nil, params['material_id'])
  # migracia part klucov bumpla schemu
  NxTest.assert_equal(Noxun::Engine::PartKeys::SCHEMA, params['part_key_schema'])
end

NxTest.test('builder: config_to_params legacy plinth/back_thickness fallbacky') do
  cb = Noxun::Engine::CabinetBuilder
  # bez support: lower s floor_height > 0 -> historicky vzdy predny sokel
  NxTest.assert_equal('front', cb.config_to_params('type' => 'lower', 'floor_height' => 100.0)['plinth_mode'])
  NxTest.assert_equal('none', cb.config_to_params('type' => 'lower', 'floor_height' => 0.0)['plinth_mode'])
  NxTest.assert_equal('none', cb.config_to_params('type' => 'upper')['plinth_mode'])
  # bez back hashu -> konstrukcny default hrubky chrbta
  p = cb.config_to_params({})
  NxTest.assert_close(Noxun::Engine::Construction::BACK_THICKNESS_DEFAULT, p['back_thickness'])
  NxTest.assert_equal('between_sides', p['bottom_mode']) # legacy_bottom default
  NxTest.assert_equal('overlay', p['back_mode'])          # legacy_back default
  NxTest.assert_equal(nil, p['fronts'])                   # bez kluca 'fronts' -> nil (default doplni normalize)
end

NxTest.test('builder: v03? marker riadi preberanie korpusovych materialov') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.refute(cb.v03?({}), 'config bez part_overrides nie je V0.3')
  NxTest.assert(cb.v03?('part_overrides' => {}), 'part_overrides je marker V0.3')
  v03 = { 'type' => 'lower', 'part_overrides' => {}, 'part_key_schema' => 1,
          'material_id' => 'M1', 'front_material_id' => 'M2', 'back_material_id' => 'M3' }
  params = cb.config_to_params(v03)
  NxTest.assert_equal('M1', params['material_id'])
  NxTest.assert_equal('M2', params['front_material_id'])
  NxTest.assert_equal('M3', params['back_material_id'])
end

NxTest.test('builder: version_at_least? porovnava zlozky numericky') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert(cb.version_at_least?('0.3.1', '0.3.1'))
  NxTest.assert(cb.version_at_least?('0.3.2', '0.3.1'))
  NxTest.refute(cb.version_at_least?('0.3.0', '0.3.1'))
  # numericky, nie lexikograficky: '0.10.0' > '0.9.0'
  NxTest.assert(cb.version_at_least?('0.10.0', '0.9.0'))
  # kratsie verzie sa doplnia nulami
  NxTest.assert(cb.version_at_least?('1.0', '0.3.1'))
  NxTest.refute(cb.version_at_least?(nil, '0.3.1')) # chybajuca verzia = 0.0.0
end

NxTest.test('builder: config_to_params migruje fronts len pod hranicou verzie') do
  cb = Noxun::Engine::CabinetBuilder
  fronts = { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 5.0 }] }
  base = { 'type' => 'lower', 'fronts' => fronts, 'part_overrides' => {}, 'part_key_schema' => 1 }
  # stara verzia: pevne celo pod MIN_AUTO sa prehodi na auto
  old = cb.config_to_params(base.merge('engine_version' => '0.3.0'))
  NxTest.assert_equal('auto', old['fronts']['items'][0]['mode'])
  NxTest.assert_equal(nil, old['fronts']['items'][0]['height'])
  # >= 0.3.1: fronts sa vratia nezmenene (validacia uz bezala pri ulozeni)
  cur = cb.config_to_params(base.merge('engine_version' => '0.3.1'))
  NxTest.assert_equal('fixed', cur['fronts']['items'][0]['mode'])
  NxTest.assert_close(5.0, cur['fronts']['items'][0]['height'])
end

# ---------------------------------------------------------------------------
# migrate_legacy_part_keys
# ---------------------------------------------------------------------------

NxTest.test('builder: migrate_legacy_part_keys prelozi suffix kluce a bumpne schemu') do
  cb = Noxun::Engine::CabinetBuilder
  params = { 'type' => 'lower',
             'part_overrides' => { 'SIDE-L' => { 'material_id' => 'MAT-X' } },
             'part_key_schema' => 0 }
  out = cb.migrate_legacy_part_keys(params, {}) # stored bez schemy -> migruje
  NxTest.assert_equal(Noxun::Engine::PartKeys::SCHEMA, out['part_key_schema'])
  NxTest.assert_equal({ 'cabinet/side:left' => { 'material_id' => 'MAT-X' } }, out['part_overrides'])
  NxTest.refute(out['part_overrides'].key?('SIDE-L'), 'stary suffix kluc ma zmiznut')
end

NxTest.test('builder: migrate_legacy_part_keys s aktualnou schemou nemeni params') do
  cb = Noxun::Engine::CabinetBuilder
  params = { 'type' => 'lower',
             'part_overrides' => { 'SIDE-L' => { 'material_id' => 'MAT-X' } },
             'part_key_schema' => 0 }
  out = cb.migrate_legacy_part_keys(params, { 'part_key_schema' => Noxun::Engine::PartKeys::SCHEMA })
  NxTest.assert(out.equal?(params), 'ma vratit ten isty objekt bez zmeny')
  NxTest.assert(out['part_overrides'].key?('SIDE-L'), 'kluce ostavaju netknute')
  NxTest.assert_equal(0, out['part_key_schema'])
end

NxTest.test('builder: migrate_legacy_part_keys rescue ticho vrati povodne params') do
  cb = Noxun::Engine::CabinetBuilder
  # height 200 + floor_height 500 preziju clamp, ale build_plan interne padne
  # (sokel >= vyska korpusu) -> rescue vetva vrati params BEZ migracie a BEZ bumpu.
  params = { 'type' => 'lower', 'height' => 200, 'floor_height' => 500,
             'part_overrides' => { 'SIDE-L' => { 'material_id' => 'MAT-X' } },
             'part_key_schema' => 0 }
  out = cb.migrate_legacy_part_keys(params, {})
  NxTest.assert(out.equal?(params), 'rescue ma vratit povodny objekt')
  NxTest.assert(out['part_overrides'].key?('SIDE-L'), 'override ostava pod starym klucom')
  NxTest.assert_equal(0, out['part_key_schema'], 'schema sa pri chybe NEbumpne')
end

# ---------------------------------------------------------------------------
# thickness / material pomocniky (cisto vypoctove, bez katalogu)
# ---------------------------------------------------------------------------

NxTest.test('builder: thickness_ok_for? cela 18/19, ostatne presna zhoda') do
  cb = Noxun::Engine::CabinetBuilder
  # cela: katalogove varianty 18 aj 19 mm prejdu vzdy
  NxTest.assert(cb.thickness_ok_for?('front_door', 18.0, 18.0))
  NxTest.assert(cb.thickness_ok_for?('front_door', 18.0, 19.0))
  NxTest.assert(cb.thickness_ok_for?('drawer_front', 19.0, 18.0))
  NxTest.refute(cb.thickness_ok_for?('front_door', 18.0, 16.0))
  # ostatne roly: tolerancia len 0.05 mm
  NxTest.assert(cb.thickness_ok_for?('shelf', 18.0, 18.0))
  NxTest.assert(cb.thickness_ok_for?('shelf', 18.0, 18.04))
  NxTest.refute(cb.thickness_ok_for?('shelf', 18.0, 18.06))
  NxTest.refute(cb.thickness_ok_for?('shelf', 18.0, 19.0))
  NxTest.refute(cb.thickness_ok_for?('side_left', 18.0, 16.0))
end

NxTest.test('builder: validate_material_thickness! raise pri rozpore, legacy prejde') do
  cb = Noxun::Engine::CabinetBuilder
  pd = { suffix: 'SHELF-1', role: 'shelf', prod: { thickness: 18.0 } }
  # bez materialu / material mimo katalogu (sheet nil) -> ziadna kontrola
  NxTest.assert_equal(nil, cb.validate_material_thickness!(nil, nil, pd))
  NxTest.assert_equal(nil, cb.validate_material_thickness!('LEGACY_X', nil, pd))
  # katalogovy material s inou hrubkou -> slovenska chyba
  e = NxTest.assert_raise('potrebuje 18.0 mm') do
    cb.validate_material_thickness!('K009_PW_DTDL_16', { 'thickness' => 16.0 }, pd)
  end
  NxTest.assert(e.message.include?('ma 16.0 mm'), 'sprava ma obsahovat realnu hrubku')
  # celo s 19 mm variantom prejde (geometria sa prisposobi)
  fpd = { suffix: 'DOOR-1', role: 'front_door', prod: { thickness: 18.0 } }
  NxTest.assert_equal(nil, cb.validate_material_thickness!('X_19', { 'thickness' => 19.0 }, fpd))
end

NxTest.test('builder: base_material_for mapuje roly na efektivne materialy') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert_equal('F', cb.base_material_for('front_door', :front, 'B', 'F', 'Z'))
  NxTest.assert_equal('F', cb.base_material_for('drawer_front', :front, 'B', 'F', 'Z'))
  NxTest.assert_equal('Z', cb.base_material_for('back', :korpus, 'B', 'F', 'Z'))
  NxTest.assert_equal('B', cb.base_material_for('side_left', :korpus, 'B', 'F', 'Z'))
  NxTest.assert_equal('B', cb.base_material_for('shelf', :korpus, 'B', 'F', 'Z'))
  # nezname roly: rozhoduje sekundarny signal material symbol
  NxTest.assert_equal('F', cb.base_material_for('nova_rola', :front, 'B', 'F', 'Z'))
  NxTest.assert_equal('B', cb.base_material_for('nova_rola', :korpus, 'B', 'F', 'Z'))
end

NxTest.test('builder: materialized_part prisposobi celo katalogovej hrubke') do
  cb = Noxun::Engine::CabinetBuilder
  pd = { role: 'front_door', box: [497.0, 18.0, 300.0], origin: [2.0, -18.0, 100.0],
         prod: { length: 300.0, width: 497.0, thickness: 18.0 } }
  out = cb.materialized_part(pd, { sheet_thickness: 19.0 })
  NxTest.assert_close(19.0, out[:box][1])
  NxTest.assert_close(-19.0, out[:origin][1])
  NxTest.assert_close(19.0, out[:prod][:thickness])
  # povodny deskriptor sa NEmutuje
  NxTest.assert_close(18.0, pd[:box][1])
  NxTest.assert_close(-18.0, pd[:origin][1])
  # nie-celo a chybajuca katalogova hrubka -> nezmenene (ten isty objekt)
  spd = { role: 'shelf', box: [500.0, 490.0, 18.0], origin: [18.0, 0.0, 118.0],
          prod: { thickness: 18.0 } }
  NxTest.assert(cb.materialized_part(spd, { sheet_thickness: 19.0 }).equal?(spd))
  NxTest.assert(cb.materialized_part(pd, { sheet_thickness: nil }).equal?(pd))
end

NxTest.test('builder: known_edges berie len zname kluce a zachova explicitny nil') do
  cb = Noxun::Engine::CabinetBuilder
  out = cb.known_edges('L1' => nil, 'W2' => 'ABS_X', 'ZZ' => 'junk')
  NxTest.assert_equal({ 'L1' => nil, 'W2' => 'ABS_X' }, out)
  NxTest.assert(out.key?('L1'), 'explicitny nil (bez ABS) musi prezit ako kluc')
  refute_keys = cb.known_edges(nil)
  NxTest.assert_equal({}, refute_keys)
  NxTest.assert_equal({}, cb.known_edges('nie hash'))
end

# ---------------------------------------------------------------------------
# resolve_part retaz (potrebuje seed katalogu Materials/AbsRules v APPDATA sandboxe)
# ---------------------------------------------------------------------------

NxTest.test('builder: resolve_part - override > korpus, ABS podla dekoru materialu') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  pd = { part_key: 'zone:Z1/shelf:1', suffix: 'SHELF-1-1', role: 'shelf', material: :korpus,
         prod: { length: 564.0, width: 490.0, thickness: 18.0 } }
  # bez override: korpusovy material + ABS predna hrana v dekore K009
  res = cb.resolve_part(pd, 'K009_PW_DTDL_18', 'W1000_DTDL_18', 'HDF_WHITE_3', {})
  NxTest.assert_equal('zone:Z1/shelf:1', res[:part_key])
  NxTest.assert_equal(res[:part_key], res[:role_key]) # kompatibilny alias
  NxTest.assert_equal('K009_PW_DTDL_18', res[:material_id])
  NxTest.assert_equal({ 'L1' => 'ABS_K009_10', 'L2' => nil, 'W1' => nil, 'W2' => nil }, res[:edges])
  NxTest.assert_equal('length', res[:grain_direction])
  NxTest.assert_close(18.0, res[:sheet_thickness])
  # override materialu vyhrava a prehodi aj dekor ABS
  ov = { 'zone:Z1/shelf:1' => { 'material_id' => 'W1000_DTDL_18' } }
  res2 = cb.resolve_part(pd, 'K009_PW_DTDL_18', 'W1000_DTDL_18', 'HDF_WHITE_3', ov)
  NxTest.assert_equal('W1000_DTDL_18', res2[:material_id])
  NxTest.assert_equal('ABS_W1000_10', res2[:edges]['L1'])
  NxTest.assert_equal('none', res2[:grain_direction])
end

NxTest.test('builder: resolve_part - explicitny nil v override hrane vypne ABS z pravidla') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  pd = { part_key: 'front:F1/wing:single', suffix: 'DOOR-1', role: 'front_door', material: :front,
         prod: { length: 300.0, width: 496.0, thickness: 18.0 } }
  ov = { 'front:F1/wing:single' => { 'edges' => { 'L1' => nil } } }
  res = cb.resolve_part(pd, 'K009_PW_DTDL_18', 'W1000_DTDL_18', 'HDF_WHITE_3', ov)
  # pravidlo cela = ABS dookola; L1 explicitne vypnuta, zvysok dedi z pravidla
  NxTest.assert_equal(nil, res[:edges]['L1'])
  NxTest.assert_equal('ABS_W1000_10', res[:edges]['L2'])
  NxTest.assert_equal('ABS_W1000_10', res[:edges]['W1'])
  NxTest.assert_equal('ABS_W1000_10', res[:edges]['W2'])
  # legacy material mimo katalogu: ziadna kontrola hrubky, ziadne ABS, grain none
  res2 = cb.resolve_part(pd, 'K009_PW_DTDL_18', 'LEGACY_X', 'HDF_WHITE_3', {})
  NxTest.assert_equal('LEGACY_X', res2[:material_id])
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }, res2[:edges])
  NxTest.assert_equal('none', res2[:grain_direction])
  NxTest.assert_equal(nil, res2[:sheet_thickness])
end

NxTest.test('builder: resolve_part - projektovy fallback cez Materials.project_defaults') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  materials = Noxun::Engine::Materials
  # prazdny model -> PROJECT_FALLBACK (koren dedenia projekt -> korpus -> dielec)
  defaults = materials.project_defaults(NxTest::FakeEntity.new)
  NxTest.assert_equal('K009_PW_DTDL_18', defaults['default_material_id'])
  NxTest.assert_equal('W1000_DTDL_18', defaults['default_front_material_id'])
  NxTest.assert_equal('HDF_WHITE_3', defaults['default_back_material_id'])
  # nastaveny projektovy default prebije fallback
  fake = NxTest::FakeEntity.new
  fake.set_attribute(Noxun::Engine::Store::DICT, 'default_material_id', 'W1000_DTDL_18')
  NxTest.assert_equal('W1000_DTDL_18', materials.project_defaults(fake)['default_material_id'])
  # retaz ako v build_into: korpus nil -> projektovy default; chrbat bez ABS pravidla
  eff_body = cb.present(nil) || defaults['default_material_id']
  NxTest.assert_equal('K009_PW_DTDL_18', eff_body)
  pd = { part_key: 'cabinet/back', suffix: 'BACK', role: 'back', material: :korpus,
         prod: { length: 600.0, width: 620.0, thickness: 3.0 } }
  res = cb.resolve_part(pd, eff_body, defaults['default_front_material_id'],
                        defaults['default_back_material_id'], {})
  NxTest.assert_equal('HDF_WHITE_3', res[:material_id])
  NxTest.assert_equal({ 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }, res[:edges])
  NxTest.assert_close(3.0, res[:sheet_thickness])
end

# ---------------------------------------------------------------------------
# norm_overrides (siaha na katalog cez Materials.normalized_abs_id)
# ---------------------------------------------------------------------------

NxTest.test('builder: norm_overrides - neznamy abs_id sa ulozi ako explicitne bez ABS') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  # v0.3.3 (PR #12): normalized_abs_id NErobi migraciu podla dekoru - neznamy id -> nil,
  # ktory sa zachova ako explicitny override 'bez ABS' (kluc ostava v edges).
  out = cb.norm_overrides('k' => { 'edges' => { 'L1' => 'NEEXISTUJE' } })
  NxTest.assert_equal({ 'k' => { 'edges' => { 'L1' => nil } } }, out)
  NxTest.assert(out['k']['edges'].key?('L1'), 'explicitny nil musi ostat ako kluc')
  # platny abs_id zo seed katalogu prezije, symbolove kluce sa znormalizuju
  out2 = cb.norm_overrides('k' => { material_id: 'M1', edges: { L1: 'ABS_K009_10' } })
  NxTest.assert_equal({ 'k' => { 'material_id' => 'M1', 'edges' => { 'L1' => 'ABS_K009_10' } } }, out2)
end

NxTest.test('builder: norm_overrides zahodi prazdne a neplatne zaznamy') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert_equal({}, cb.norm_overrides(nil))
  NxTest.assert_equal({}, cb.norm_overrides('nie hash'))
  out = cb.norm_overrides('a' => {}, 'b' => 'nie hash',
                          'c' => { 'material_id' => '   ' },
                          'd' => { 'edges' => 'nie hash' })
  NxTest.assert_equal({}, out)
end

# ---------------------------------------------------------------------------
# norm_hardware_overrides (V0.4 kovanie — cisto vypoctove, bez katalogu)
# ---------------------------------------------------------------------------

NxTest.test('builder: norm_hardware_overrides cisti tvar a zahadzuje neplatne') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert_equal([], cb.norm_hardware_overrides(nil))
  NxTest.assert_equal([], cb.norm_hardware_overrides('nie pole'))
  out = cb.norm_hardware_overrides([
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy-zakladne', 'quantity' => 6 },
    { owner_part_key: 'front:F1/wing:left', generic_type: 'hinge', rule_id: 'r1', disabled: 'true' },
    { 'generic_type' => 'ufo', 'rule_id' => 'r2', 'quantity' => 2 },       # neznamy typ -> von
    { 'generic_type' => 'leg', 'rule_id' => '', 'quantity' => 2 },          # bez rule_id -> von
    { 'generic_type' => 'leg', 'rule_id' => 'r3' },                         # bez quantity/disabled -> von
    { 'owner_part_key' => 'SIDE-L', 'generic_type' => 'leg', 'rule_id' => 'r4', 'quantity' => 2 }, # zly owner
    { 'generic_type' => 'slide', 'rule_id' => 'r5', 'quantity' => 100_000 } # clamp na max
  ])
  NxTest.assert_equal(3, out.length, "cakal som 3 platne zaznamy, mam #{out.inspect}")
  NxTest.assert_equal({ 'owner_part_key' => nil, 'generic_type' => 'leg',
                        'rule_id' => 'nohy-zakladne', 'quantity' => 6 }, out[0])
  NxTest.assert_equal({ 'owner_part_key' => 'front:F1/wing:left', 'generic_type' => 'hinge',
                        'rule_id' => 'r1', 'disabled' => true }, out[1], 'symbolove kluce sa znormalizuju')
  NxTest.assert_equal(Noxun::Engine::BuildPlan::MAX_HW_QUANTITY, out[2]['quantity'])
end

NxTest.test('builder: norm_hardware_overrides — posledny duplicitny zaznam vyhrava') do
  cb = Noxun::Engine::CabinetBuilder
  out = cb.norm_hardware_overrides([
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'r', 'quantity' => 5 },
    { 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'r', 'disabled' => true }
  ])
  NxTest.assert_equal(1, out.length, 'duplicitna identita sa deduplikuje')
  NxTest.assert_equal(true, out[0]['disabled'], 'posledny zaznam vyhrava')
end

NxTest.test('builder: hardware_overrides preziju round-trip config_to_params -> normalize') do
  cb = Noxun::Engine::CabinetBuilder
  ov = [{ 'owner_part_key' => nil, 'generic_type' => 'leg',
          'rule_id' => 'nohy-zakladne', 'quantity' => 6 }]
  cfg = cb.normalize('hardware_overrides' => ov)
  NxTest.assert_equal(ov, cfg[:hardware_overrides])
  stored = JSON.parse(JSON.generate(cb.cabinet_config(cfg)))
  NxTest.assert_equal(ov, stored['hardware_overrides'], 'zapis do configu bez zmeny')
  params = cb.config_to_params(stored.merge('part_key_schema' => Noxun::Engine::PartKeys::SCHEMA))
  NxTest.assert_equal(ov, params['hardware_overrides'], 'citanie z configu bez zmeny')
  NxTest.assert_equal(ov, cb.normalize(params)[:hardware_overrides], 'druhy normalize identicky')
end

NxTest.test('builder: D-24 material/ABS + hardware overridy preziju rebuild 1->1 (round-trip configu)') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  cn = Noxun::Engine::Construction
  params = {
    'type' => 'lower',
    'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '1' }] },
    'part_overrides' => { 'front:F1/wing:single' => { 'material_id' => 'W1000_DTDL_18',
                                                      'edges' => { 'L1' => nil } } },
    'hardware_overrides' => [{ 'owner_part_key' => 'front:F1/wing:single', 'generic_type' => 'hinge',
                               'rule_id' => 'zavesy-podla-vysky', 'quantity' => 5 }],
    'part_key_schema' => Noxun::Engine::PartKeys::SCHEMA
  }
  cfg = cb.normalize(params)
  plan = cn.build_plan(cfg, 'CAB-001')
  # simulacia rebuildu: merge_final -> cabinet_config -> JSON (NOXUN dict) ->
  # config_to_params -> normalize -> novy plan. Identita wing:single sa NEMENI,
  # takze overridy najdu svoj dielec aj po druhom kole.
  stored = JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(cfg, plan))))
  cfg2 = cb.normalize(cb.config_to_params(stored))
  NxTest.assert_equal({ 'material_id' => 'W1000_DTDL_18', 'edges' => { 'L1' => nil } },
                      cfg2[:part_overrides]['front:F1/wing:single'], 'part_override prezil round-trip')
  plan2 = cn.build_plan(cfg2, 'CAB-001')
  hinge = plan2[:hardware].find { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal(5, hinge['quantity'], 'manualny pocet zavesov prezil rebuild')
  NxTest.assert_equal('manual', hinge['source'])
  NxTest.assert_equal('front:F1/wing:single', hinge['owner_part_key'])
  pd = plan2[:parts].find { |p| p[:part_key] == 'front:F1/wing:single' }
  res = cb.resolve_part(pd, 'K009_PW_DTDL_18', 'K009_PW_DTDL_18', 'HDF_WHITE_3', cfg2[:part_overrides])
  NxTest.assert_equal('W1000_DTDL_18', res[:material_id], 'material override sa aplikuje na kridlo')
  NxTest.assert_equal(nil, res[:edges]['L1'], 'ABS override (bez ABS) drzi')
  NxTest.assert_equal('ABS_W1000_10', res[:edges]['L2'], 'ostatne hrany dedia z pravidla cela')
end

NxTest.test('builder: D-24 material/ABS + hardware overridy preziju rebuild 2->2 (wing:left)') do
  NxTest.skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
  cb = Noxun::Engine::CabinetBuilder
  cn = Noxun::Engine::Construction
  params = {
    'type' => 'lower', 'width' => 900.0,
    'fronts' => { 'edge_limit_off' => true,
                  'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '2' }] },
    'part_overrides' => { 'front:F1/wing:left' => { 'material_id' => 'W1000_DTDL_18' } },
    'hardware_overrides' => [{ 'owner_part_key' => 'front:F1/wing:left', 'generic_type' => 'hinge',
                               'rule_id' => 'zavesy-podla-vysky', 'disabled' => true }],
    'part_key_schema' => Noxun::Engine::PartKeys::SCHEMA
  }
  cfg = cb.normalize(params)
  stored = JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(cfg, cn.build_plan(cfg, 'CAB-001')))))
  cfg2 = cb.normalize(cb.config_to_params(stored))
  NxTest.assert_equal({ 'material_id' => 'W1000_DTDL_18' },
                      cfg2[:part_overrides]['front:F1/wing:left'], 'override laveho kridla prezil')
  NxTest.assert_equal(true, cfg2[:fronts]['edge_limit_off'],
                      'D-22: zamok presahov prezil builder round-trip (sablony/rebuild)')
  plan2 = cn.build_plan(cfg2, 'CAB-002')
  hinges = plan2[:hardware].select { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal(['front:F1/wing:right'], hinges.map { |h| h['owner_part_key'] },
                      'disabled override laveho kridla drzi, prave kridlo ma zavesy')
  keys = plan2[:parts].map { |p| p[:part_key] }
  NxTest.assert(keys.include?('front:F1/wing:left') && keys.include?('front:F1/wing:right'),
                'obidve kridla existuju s povodnou identitou')
end

NxTest.test('builder: D-18 normalize odstrani hardware_overrides cela typu none (Codex F1)') do
  cb = Noxun::Engine::CabinetBuilder
  ov = [
    { 'owner_part_key' => 'front:F1/wing:single', 'generic_type' => 'hinge',
      'rule_id' => 'zavesy-podla-vysky', 'disabled' => true },              # F1 -> none = von
    { 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
      'rule_id' => 'vysuvy-nl-podla-hlbky', 'quantity' => 2 },              # F1 -> none = von (aj panel tvar)
    { 'owner_part_key' => 'front:F2/wing:left', 'generic_type' => 'hinge',
      'rule_id' => 'zavesy-podla-vysky', 'quantity' => 3 },                 # F2 je door = ostava
    { 'owner_part_key' => nil, 'generic_type' => 'leg',
      'rule_id' => 'nohy-zakladne', 'quantity' => 6 }                       # korpusovy = ostava
  ]
  fronts = { 'items' => [
    { 'id' => 'F1', 'type' => 'none', 'mode' => 'fixed', 'height' => 200 },
    { 'id' => 'F2', 'type' => 'door', 'wings' => '2' }
  ] }
  cfg = cb.normalize('fronts' => fronts, 'hardware_overrides' => ov)
  owners = cfg[:hardware_overrides].map { |o| o['owner_part_key'] }
  NxTest.assert_equal(['front:F2/wing:left', nil], owners,
                      "zasahy none riadku maju byt prec, mam: #{cfg[:hardware_overrides].inspect}")

  # Bez none riadkov prune nezasahuje (stare configy nezmenene).
  cfg2 = cb.normalize('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door' }] },
                      'hardware_overrides' => ov)
  NxTest.assert_equal(4, cfg2[:hardware_overrides].length, 'bez none ostava vsetko')
end

# ---------------------------------------------------------------------------
# cabinet_config + merge_final
# ---------------------------------------------------------------------------

NxTest.test('builder: cabinet_config nesie verziu, schemu a je JSON-ovatelny') do
  cb = Noxun::Engine::CabinetBuilder
  cfg = cb.normalize({})
  plan = Noxun::Engine::Construction.build_plan(cfg, 'CAB-001')
  final = cb.merge_final(cfg, plan)
  c = cb.cabinet_config(final)
  NxTest.assert_equal(Noxun::Engine::VERSION, c[:engine_version])
  NxTest.refute(c[:engine_version].to_s.empty?, 'engine_version nesmie byt prazdna')
  NxTest.assert_equal(Noxun::Engine::PartKeys::SCHEMA, c[:part_key_schema])
  NxTest.assert_equal('lower', c[:type])
  NxTest.assert_equal('noxun-lower-18', c[:construction_preset])
  NxTest.assert_equal('Spodna skrinka 600', c[:name])
  NxTest.assert_equal('legs', c[:support][:type]) # lower + floor_height bez sokloveho panela
  NxTest.assert_close(100.0, c[:support][:height])
  NxTest.assert_equal({}, c[:part_overrides])
  # merge_final zapisal vysledky planu
  NxTest.assert_close(564.0, c[:available_width])   # 600 - 2*18
  NxTest.assert_close(584.0, c[:available_height])  # 702 - 118
  NxTest.assert_close(507.0, c[:available_depth])   # D-37 overlay: d - bt (hlbka je celkova)
  NxTest.assert_close(0.0, c[:front_plane])
  NxTest.assert_equal(0, c[:wings])
  NxTest.assert_equal([], c[:front_items])
  NxTest.assert_equal(1, c[:zones].size) # koren bez delenia = 1 zona
  NxTest.assert(c[:zone_tree].is_a?(Hash), 'zone_tree ma byt hash')
  # config musi prezit JSON round-trip (uklada sa ako JSON string v NOXUN dicte)
  parsed = JSON.parse(JSON.generate(c))
  NxTest.assert_equal('lower', parsed['type'])
  NxTest.assert_close(600.0, parsed['width'])
  NxTest.assert_equal('legs', parsed['support']['type'])
end

NxTest.test('builder: cabinet_config upper - preset, meno a support none') do
  cb = Noxun::Engine::CabinetBuilder
  c = cb.cabinet_config(cb.normalize('type' => 'upper'))
  NxTest.assert_equal('noxun-upper-18', c[:construction_preset])
  NxTest.assert_equal('Horna skrinka 600', c[:name])
  NxTest.assert_equal('none', c[:support][:type])
  NxTest.assert_close(0.0, c[:support][:height])
  # lower s plinth_mode front -> soklovy panel s odsadenim
  c2 = cb.cabinet_config(cb.normalize('plinth_mode' => 'front'))
  NxTest.assert_equal('plinth', c2[:support][:type])
  NxTest.assert_close(100.0, c2[:support][:height])
  NxTest.assert_close(40.0, c2[:support][:recess])
end

# ---------------------------------------------------------------------------
# nizkourovnove helpery
# ---------------------------------------------------------------------------

NxTest.test('builder: clampf/fetchf/present helpery') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert_close(10.0, cb.clampf(5, 10, 20))
  NxTest.assert_close(20.0, cb.clampf(25, 10, 20))
  NxTest.assert_close(15.0, cb.clampf('15', 10, 20))
  # fetchf: nil/prazdny string -> default; string kluc ma prednost pred symbolom
  NxTest.assert_close(7.0, cb.fetchf({ 'w' => '' }, :w, 7.0))
  NxTest.assert_close(7.0, cb.fetchf({}, :w, 7.0))
  NxTest.assert_close(12.5, cb.fetchf({ w: '12.5' }, :w, 7.0))
  NxTest.assert_close(1.0, cb.fetchf({ 'w' => '1', w: '2' }, :w, 7.0))
  # present: whitespace -> nil, inak orezany string
  NxTest.assert_equal(nil, cb.present(nil))
  NxTest.assert_equal(nil, cb.present(''))
  NxTest.assert_equal(nil, cb.present('   '))
  NxTest.assert_equal('x', cb.present(' x '))
  NxTest.assert_equal('5', cb.present(5))
end
