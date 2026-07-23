# frozen_string_literal: true
# Testy D-41 PR C: centralne preladenie ABS pri zmene efektivneho materialu.
#   Materials.remap_edges — jedno jadro (doska + dielcove overridy)
#   CabinetBuilder.remap_part_edge_overrides! — traversal cez part_overrides
#     s realnymi part_key z planu (inherited<->override, foreign, lost, cela).
# Vsetko headless (APPDATA sandbox; seed katalog K009 PW / W1000).
require_relative '../helper' unless defined?(NxTest)

RMAT = Noxun::Engine::Materials
RCB  = Noxun::Engine::CabinetBuilder

# Docasny dekor s sirkovymi paskami 22/1 a 43/1 + doskami 18/36.
def rm_seed_decor(tag)
  ok, res = RMAT.add_decor_batch(
    'decor' => tag, 'manufacturer' => 'Test', 'type' => 'DTDL',
    'thicknesses' => '18, 36', 'abs_tokens' => '22/1, 43/1'
  )
  raise "seed #{tag} zlyhal: #{res.inspect}" unless ok
  res
end

def rm_cleanup(res)
  (res['sheets'] || []).each { |id| RMAT.delete_sheet(id) }
  (res['edges'] || []).each { |id| RMAT.delete_edge(id) }
end

# Zakladne params dolnej skrinky (normalize doplni zvysok).
def rm_params(overrides = {})
  { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
    'thickness' => 18.0, 'part_overrides' => overrides }
end

# part_key roly z planu (napr. side_left) — realny kluc, ziadne vymyslanie.
def rm_key_for(params, role)
  RCB.plan_parts_by_key(params).find { |_k, pd| pd[:role].to_s == role }&.first
end

# ---------------------------------------------------------------------------
# Materials.remap_edges (jadro)
# ---------------------------------------------------------------------------

NxTest.test('abs-remap: jadro premapuje zladene hrany so sirkou podla cielovej hrubky') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = rm_seed_decor('RemapJadro')
  begin
    edges = { 'L1' => 'ABS_K009_10', 'L2' => nil, 'W1' => 'ABS_W1000_10', 'W2' => 'ABS_K009_20' }
    out, lost = RMAT.remap_edges(edges, 'K009 PW', 'RemapJadro', 18.0)
    NxTest.assert_equal('ABS_REMAPJADRO_22X10', out['L1'], 'zladena 1,0 -> nova 22/1')
    NxTest.assert_equal(nil, out['L2'], 'nil (vedome bez ABS) sa nedotyka')
    NxTest.assert_equal('ABS_W1000_10', out['W1'], 'cudzi dekor (kontrast) ostava')
    NxTest.assert_equal(nil, out['W2'], '2,0 mm variant novy dekor nema -> nil')
    NxTest.assert_equal(['W2'], lost)
    NxTest.assert_equal(['L1', 'L2', 'W1', 'W2'], out.keys, 'kompletna mapa ostava')
  ensure
    rm_cleanup(res)
  end
end

NxTest.test('abs-remap: jadro nic nerobi pri rovnakom/chybajucom dekore alebo bez zhody') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal([nil, []], RMAT.remap_edges({ 'L1' => 'ABS_K009_10' }, 'K009 PW', 'K009 PW', 18.0))
  NxTest.assert_equal([nil, []], RMAT.remap_edges({ 'L1' => 'ABS_K009_10' }, nil, 'X', 18.0))
  NxTest.assert_equal([nil, []], RMAT.remap_edges(nil, 'K009 PW', 'X', 18.0))
  out, = RMAT.remap_edges({ 'L1' => 'ABS_W1000_10' }, 'K009 PW', 'W1000 ST9 Biela', 18.0)
  NxTest.assert_equal(nil, out, 'ziadna hrana stareho dekoru = nil (nic na prevod)')
end

# ---------------------------------------------------------------------------
# CabinetBuilder.remap_part_edge_overrides! (traversal)
# ---------------------------------------------------------------------------

NxTest.test('abs-remap: zmena base materialu preladi zladeny override, kontrast necha') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = rm_seed_decor('RemapBase')
  begin
    params = rm_params
    side = rm_key_for(params, 'side_left')
    NxTest.assert(side, 'plan ma side_left')
    params['part_overrides'] = {
      side => { 'edges' => { 'L1' => 'ABS_K009_10', 'W1' => 'ABS_W1000_10' } }
    }
    old_eff = { 'body' => 'K009_PW_DTDL_18', 'front' => 'W1000_DTDL_18', 'back' => 'HDF_WHITE_3' }
    new_eff = old_eff.merge('body' => res['sheets'][0]) # RemapBase DTDL 18
    result = RCB.remap_part_edge_overrides!(params, old_eff, new_eff)
    NxTest.assert_equal(1, result['changed'])
    NxTest.assert_equal([], result['lost'])
    edges = params['part_overrides'][side]['edges']
    NxTest.assert_equal('ABS_REMAPBASE_22X10', edges['L1'], '18 mm bok -> 22-ka noveho dekoru')
    NxTest.assert_equal('ABS_W1000_10', edges['W1'], 'kontrastna hrana ostava')
  ensure
    rm_cleanup(res)
  end
end

NxTest.test('abs-remap: inherited->override a override->inherit (audit FIX 7)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = rm_seed_decor('RemapOvr')
  begin
    params = rm_params
    side = rm_key_for(params, 'side_left')
    eff = { 'body' => 'K009_PW_DTDL_18', 'front' => 'W1000_DTDL_18', 'back' => 'HDF_WHITE_3' }

    # inherited -> override: stary stav BEZ material override (dedil K009),
    # novy override RemapOvr; hrana zladena so STARYM efektivnym dekorom K009.
    params['part_overrides'] = {
      side => { 'material_id' => res['sheets'][0], 'edges' => { 'L1' => 'ABS_K009_10' } }
    }
    old_overrides = { side => { 'edges' => { 'L1' => 'ABS_K009_10' } } }
    result = RCB.remap_part_edge_overrides!(params, eff, eff, old_overrides: old_overrides)
    NxTest.assert_equal(1, result['changed'])
    NxTest.assert_equal('ABS_REMAPOVR_22X10', params['part_overrides'][side]['edges']['L1'])

    # override -> inherit: stary override RemapOvr, novy stav dedi K009 base.
    params2 = rm_params(side => { 'edges' => { 'L1' => 'ABS_REMAPOVR_22X10' } })
    old_overrides2 = { side => { 'material_id' => res['sheets'][0], 'edges' => { 'L1' => 'ABS_REMAPOVR_22X10' } } }
    result2 = RCB.remap_part_edge_overrides!(params2, eff, eff, old_overrides: old_overrides2)
    NxTest.assert_equal(1, result2['changed'])
    NxTest.assert_equal('ABS_K009_10', params2['part_overrides'][side]['edges']['L1'],
                        'spat na dekor zdedeneho materialu')
  ensure
    rm_cleanup(res)
  end
end

NxTest.test('abs-remap: chybajuci variant -> nil + lost s menom dielca; neznamy kluc skip') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = rm_seed_decor('RemapLost')
  begin
    params = rm_params
    side = rm_key_for(params, 'side_left')
    params['part_overrides'] = {
      side => { 'edges' => { 'L1' => 'ABS_K009_20' } },   # 2,0 mm — novy dekor nema
      'neexistujuci-kluc' => { 'edges' => { 'L1' => 'ABS_K009_10' } }
    }
    old_eff = { 'body' => 'K009_PW_DTDL_18', 'front' => 'W1000_DTDL_18', 'back' => 'HDF_WHITE_3' }
    new_eff = old_eff.merge('body' => res['sheets'][0])
    result = RCB.remap_part_edge_overrides!(params, old_eff, new_eff)
    NxTest.assert_equal(1, result['changed'])
    NxTest.assert_equal(1, result['lost'].size)
    NxTest.assert(result['lost'][0].include?('L1'), result['lost'].inspect)
    NxTest.assert_equal(nil, params['part_overrides'][side]['edges']['L1'])
    NxTest.assert_equal('ABS_K009_10', params['part_overrides']['neexistujuci-kluc']['edges']['L1'],
                        'kluc mimo planu sa nedotyka')
  ensure
    rm_cleanup(res)
  end
end

NxTest.test('abs-remap: celo berie cielovu hrubku z noveho sheetu (18->36 target 43-ka)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = rm_seed_decor('RemapFront')
  begin
    params = rm_params
    params['fronts'] = '1' # legacy skratka = 1 dvierka auto (Fronts.legacy_string)
    front = rm_key_for(params, 'front_door')
    NxTest.assert(front, 'plan ma celo (fronts door)')
    params['part_overrides'] = { front => { 'edges' => { 'W1' => 'ABS_W1000_10' } } }
    old_eff = { 'body' => 'K009_PW_DTDL_18', 'front' => 'W1000_DTDL_18', 'back' => 'HDF_WHITE_3' }
    new_eff = old_eff.merge('front' => res['sheets'][1]) # RemapFront DTDL 36
    result = RCB.remap_part_edge_overrides!(params, old_eff, new_eff)
    NxTest.assert_equal(1, result['changed'])
    NxTest.assert_equal('ABS_REMAPFRONT_43X10', params['part_overrides'][front]['edges']['W1'],
                        '36 mm sheet -> 43-ka (nie 22)')
  ensure
    rm_cleanup(res)
  end
end
