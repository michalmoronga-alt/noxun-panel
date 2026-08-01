# frozen_string_literal: true
# Testy D-49: duplak automaticky — serverova brana automatiky.
#   Materials.ensure_duplak_for     — idempotencia, guardy, kolizia s kupovanou
#   Materials.duplak_offer_sources  — komu sa ponuka virtualna polozka
#   Materials.duplak_record_from    — ocista zdedenych poli (audit B1)
# Panelovy resolver (resolve_virtual_material) a selecty overuje su_runner /
# Michalov smoke — tu je cista katalogova logika.
require_relative '../helper' unless defined?(NxTest)

NxTest.test('d49 setup: cerstvy SCHEMA 2 seed katalog') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
end

D49M = Noxun::Engine::Materials

def d49_seed(decor = 'K200', ths = [18.0])
  ok, res = D49M.add_decor_batch(
    'batch_schema' => 3, 'decor' => decor, 'manufacturer' => 'Kronospan',
    'decor_name' => 'Test dub', 'type' => 'DTDL', 'grain' => 'length',
    'color' => [20, 30, 40],
    'sheet_variants' => ths.map { |t| { 'thickness' => t, 'structure' => 'PW' } },
    'edge_variants' => []
  )
  raise "seed #{decor} zlyhal: #{res.inspect}" unless ok
  res
end

def d49_cleanup(*results)
  results.compact.each do |res|
    # duplaky (zavisle na zdrojoch) mazat PRED zdrojmi
    Array(res['duplaks']).each { |id| D49M.delete_sheet(id) }
    (res['sheets'] || []).each { |id| D49M.delete_sheet(id) }
    (res['edges'] || []).each { |id| D49M.delete_edge(id) }
  end
end

NxTest.test('d49: ensure_duplak_for — vytvori, ocisti zdedene polia, druhy raz vrati TEN ISTY') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d49_seed
  res['duplaks'] = []
  begin
    src_id = res['sheets'][0]
    # zdroju pridame Demos vazbu, nech ocista ma co chytat (audit B1)
    st_p, = D49M.patch_record('sheet', src_id, { 'code' => '111222', 'supplier' => 'Demos' })
    NxTest.assert_equal(:ok, st_p, 'patch zdroja presiel')
    status, rec = D49M.ensure_duplak_for(src_id, 2)
    NxTest.assert_equal(:ok, status, rec.inspect)
    res['duplaks'] << rec['material_id']
    NxTest.assert_close(36.0, rec['thickness'])
    NxTest.assert_equal(src_id, rec['source_material_id'])
    NxTest.assert_equal(2, rec['source_multiplier'])
    %w[code supplier price_per_m2 uni uni_role demos_url price_checked_at].each do |k|
      NxTest.refute(rec.key?(k), "duplak nesmie zdedit #{k}")
    end
    status2, rec2 = D49M.ensure_duplak_for(src_id, 2)
    NxTest.assert_equal(:ok, status2)
    NxTest.assert_equal(rec['material_id'], rec2['material_id'], 'idempotencia — ziadny druhy zaznam')
    NxTest.assert_equal(1, D49M.duplak_dependents(src_id).size)
  ensure
    d49_cleanup(res)
  end
end

NxTest.test('d49: ensure_duplak_for — UNI a duplak zdroj su odmietnute') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  status, msg = D49M.ensure_duplak_for('UNI_DOSKA_18', 2)
  NxTest.assert_equal(:invalid, status)
  NxTest.assert(msg.to_s.include?('UNI'), msg.inspect)
  res = d49_seed('K201')
  res['duplaks'] = []
  begin
    st1, rec = D49M.ensure_duplak_for(res['sheets'][0], 2)
    NxTest.assert_equal(:ok, st1)
    res['duplaks'] << rec['material_id']
    st2, msg2 = D49M.ensure_duplak_for(rec['material_id'], 2)
    NxTest.assert_equal(:invalid, st2, 'duplak z duplaku nie')
    NxTest.assert(msg2.to_s.include?('duplák'), msg2.inspect)
  ensure
    d49_cleanup(res)
  end
end

NxTest.test('d49: kolizia s KUPOVANOU 36-kou = :exists_regular, nikdy sa nevydava za duplak (audit B2)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d49_seed('K202', [18.0, 36.0]) # kupovana 36-ka tej istej identity
  res['duplaks'] = []
  begin
    src = res['sheets'].find { |id| (D49M.sheet(id)['thickness'].to_f - 18.0).abs < 0.01 }
    bought = res['sheets'].find { |id| (D49M.sheet(id)['thickness'].to_f - 36.0).abs < 0.01 }
    status, rec = D49M.ensure_duplak_for(src, 2)
    NxTest.assert_equal(:exists_regular, status)
    NxTest.assert_equal(bought, rec['material_id'], 'vrati sa kupovana doska')
    NxTest.refute(D49M.duplak?(rec), 'kupovana doska NIE JE duplak')
    NxTest.assert_equal(0, D49M.duplak_dependents(src).size, 'ziadny zapis do katalogu')
  ensure
    d49_cleanup(res)
  end
end

NxTest.test('d49: duplak_offer_sources — UNI/duplak/PD/pokryte zdroje vypadnu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  plain = d49_seed('K203')             # eligible
  covered = d49_seed('K204')           # dostane duplak -> vypadne
  bought = d49_seed('K205', [18.0, 36.0]) # kupovana 36 -> vypadne (B2)
  covered['duplaks'] = []
  begin
    st, drec = D49M.ensure_duplak_for(covered['sheets'][0], 2)
    NxTest.assert_equal(:ok, st)
    covered['duplaks'] << drec['material_id']
    ids = D49M.duplak_offer_sources(2).map { |s| s['material_id'] }
    NxTest.assert(ids.include?(plain['sheets'][0]), 'cisty zdroj sa ponuka')
    NxTest.refute(ids.include?(covered['sheets'][0]), 'zdroj s duplakom sa uz neponuka')
    bought18 = bought['sheets'].find { |id| (D49M.sheet(id)['thickness'].to_f - 18.0).abs < 0.01 }
    NxTest.refute(ids.include?(bought18), 'zdroj s kupovanou 36-kou sa neponuka (B2)')
    NxTest.refute(ids.include?('UNI_DOSKA_18'), 'UNI sa neponuka')
    NxTest.refute(ids.include?(drec['material_id']), 'duplak nie je zdroj')
  ensure
    d49_cleanup(plain, covered, bought)
  end
end

NxTest.test('d49: HDF/KOMPAKT nie su duplak zdroje — ponuka aj create ich odmietnu (GH #116 P2)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  ok, res = D49M.add_decor_batch(
    'batch_schema' => 3, 'decor' => 'H300', 'manufacturer' => 'Kronospan',
    'decor_name' => 'Biela HDF test', 'type' => 'HDF', 'grain' => 'none',
    'color' => [240, 240, 240],
    'sheet_variants' => [{ 'thickness' => 3.0, 'structure' => 'SM' }], 'edge_variants' => []
  )
  raise "seed HDF zlyhal: #{res.inspect}" unless ok
  begin
    hdf_id = res['sheets'][0]
    NxTest.refute(D49M.duplak_offer_sources(2).map { |s| s['material_id'] }.include?(hdf_id),
                  'HDF sa v ponuke neobjavi (3 mm x2 nie je korpusova doska)')
    status, msg = D49M.ensure_duplak_for(hdf_id, 2)
    NxTest.assert_equal(:invalid, status, 'server backstop plati aj pre priamu hodnotu')
    NxTest.assert(msg.to_s.include?('DTDL/MDF'), msg.inspect)
  ensure
    d49_cleanup(res)
  end
end
