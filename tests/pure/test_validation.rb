# frozen_string_literal: true
# V0.5 D: Validation.run — kontrolny semafor vyroby (RED/ORANGE). CISTY modul,
# fixtures krmia raw zber (records so snapshotmi + hardware_overrides + warnings)
# a katalog dosiek ako mapu priamo. Kazda kontrola: pozitivny + negativny pripad;
# navyse dedup, counts a determinizmus poradia.
require_relative '../helper' unless defined?(NxTest)

module NxValFix
  module_function

  V = Noxun::Engine::Validation

  # Katalog dosiek pre testy: 18/16/3 mm, format 2800x2070.
  SHEETS = {
    'K009_18' => { 'material_id' => 'K009_18', 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0], 'grain' => 'length' },
    'K009_16' => { 'material_id' => 'K009_16', 'thickness' => 16.0, 'sheet_size' => [2800.0, 2070.0], 'grain' => 'length' },
    'K_19'    => { 'material_id' => 'K_19',    'thickness' => 19.0, 'sheet_size' => [2800.0, 2070.0], 'grain' => 'length' },
    'HDF_3'   => { 'material_id' => 'HDF_3',   'thickness' => 3.0,  'sheet_size' => [2800.0, 2070.0], 'grain' => 'none' }
  }.freeze

  def edges(h = {})
    { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.merge(h)
  end

  def rec(over = {})
    { 'name' => 'Dielec', 'part_key' => 'cabinet/x', 'owner_id' => 'CAB-1', 'pid' => 1,
      'role' => 'shelf', 'length' => 500.0, 'width' => 400.0, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => 'K009_18', 'grain_direction' => 'length',
      'edges' => edges }.merge(over)
  end

  def run(records: [], hardware_overrides: [], warnings: [], sheets: SHEETS)
    V.run({ records: records, hardware_overrides: hardware_overrides, warnings: warnings },
          sheets: sheets)
  end

  def cats(out)
    out['items'].map { |i| i['category'] }
  end
end

NxTest.test('validation: material mimo katalogu = RED ("nie je v aktualnom katalogu", nie "zmazany")') do
  f = NxValFix
  out = f.run(records: [f.rec('material_id' => 'NEZNAMY', 'role' => 'side_left')])
  reds = out['items'].select { |i| i['severity'] == 'red' && i['category'] == 'material' }
  NxTest.assert_equal(1, reds.length)
  NxTest.assert(reds.first['message_sk'].include?('nie je v aktuálnom katalógu'))
  NxTest.refute(reds.first['message_sk'].downcase.include?('zmaz'), 'nesmie tvrdit "zmazany" (nepreukazatelne, nalez 7)')
  # negativny: material v katalogu = ziadny material problem
  NxTest.assert(f.cats(f.run(records: [f.rec('material_id' => 'K009_18')])).none? { |c| c == 'material' })
end

NxTest.test('validation: prazdny material NEni "mimo katalogu" (iny problem, riesi VEPO/kusovnik)') do
  f = NxValFix
  NxTest.assert(f.cats(f.run(records: [f.rec('material_id' => '')])).none? { |c| c == 'material' })
end

NxTest.test('validation: drift hrubky = RED; tolerancia ~0.05; cela beru 18/19 variant') do
  f = NxValFix
  # bok 18 mm na materiali 16 mm = drift
  out = f.run(records: [f.rec('thickness' => 18.0, 'material_id' => 'K009_16', 'role' => 'shelf')])
  drift = out['items'].select { |i| i['category'] == 'thickness' }
  NxTest.assert_equal(1, drift.length)
  NxTest.assert_equal('red', drift.first['severity'])
  NxTest.assert(drift.first['message_sk'].include?('nesedí'))
  # zhoda hrubky = ziadny drift; drift v tolerancii 0.04 mm = ok
  NxTest.assert(f.cats(f.run(records: [f.rec('thickness' => 18.0, 'material_id' => 'K009_18')])).none? { |c| c == 'thickness' })
  NxTest.assert(f.cats(f.run(records: [f.rec('thickness' => 18.04, 'material_id' => 'K009_18')])).none? { |c| c == 'thickness' })
  # celo 18 mm na materiali 19 mm = OK (variant, zhoda s builderom); bok NIE
  celo = f.run(records: [f.rec('thickness' => 18.0, 'material_id' => 'K_19', 'role' => 'front_door', 'edges' => f.edges('L1' => 'A'))])
  NxTest.assert(f.cats(celo).none? { |c| c == 'thickness' }, 'celo 18/19 variant je OK')
  bok = f.run(records: [f.rec('thickness' => 18.0, 'material_id' => 'K_19', 'role' => 'side_left')])
  NxTest.assert_equal(1, bok['items'].select { |i| i['category'] == 'thickness' }.length, 'bok 18 na 19 = drift')
end

NxTest.test('validation: oversize = RED; grain none skusa OBE otocenia') do
  f = NxValFix
  # 3000x400 grain length -> 3000 > 2800 = nezmesti
  out = f.run(records: [f.rec('length' => 3000.0, 'width' => 400.0, 'grain_direction' => 'length')])
  NxTest.assert_equal(1, out['items'].select { |i| i['category'] == 'oversize' }.length)
  # 2050x2500 grain none: length orientacia sirka 2500 > 2070 zle, ale otocenim
  # 2500 <= 2800 && 2050 <= 2070 -> zmesti sa
  none = f.run(records: [f.rec('length' => 2050.0, 'width' => 2500.0, 'grain_direction' => 'none')])
  NxTest.assert(f.cats(none).none? { |c| c == 'oversize' }, 'grain none: otocenim sa zmesti')
  # ten isty dielec grain length sa NEzmesti (sirka 2500 > 2070)
  len = f.run(records: [f.rec('length' => 2050.0, 'width' => 2500.0, 'grain_direction' => 'length')])
  NxTest.assert_equal(1, len['items'].select { |i| i['category'] == 'oversize' }.length)
  # vacsi v oboch smeroch = nezmesti ani otocenim
  big = f.run(records: [f.rec('length' => 3000.0, 'width' => 2500.0, 'grain_direction' => 'none')])
  NxTest.assert_equal(1, big['items'].select { |i| i['category'] == 'oversize' }.length)
  # normalny dielec = ziadny oversize
  NxTest.assert(f.cats(f.run(records: [f.rec('length' => 500.0, 'width' => 400.0)])).none? { |c| c == 'oversize' })
end

NxTest.test('validation: oversize respektuje smer dekoru width (rovnaka logika ako VEPO swap)') do
  f = NxValFix
  # grain width: VEPO prehodi dlzka<->sirka; dielec 2000x2500 -> 2500 ide na dlzku
  # platne (2500 <= 2800) && 2000 <= 2070 -> zmesti sa
  ok = f.run(records: [f.rec('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => 'width')])
  NxTest.assert(f.cats(ok).none? { |c| c == 'oversize' }, 'width swap: sirka ide na dlzku platne')
  # ten isty dielec grain length: sirka 2500 > 2070 = nezmesti
  bad = f.run(records: [f.rec('length' => 2000.0, 'width' => 2500.0, 'grain_direction' => 'length')])
  NxTest.assert_equal(1, bad['items'].select { |i| i['category'] == 'oversize' }.length)
end

NxTest.test('validation: celo/dvierka bez ABS = ORANGE (1 polozka na dielec, NIE per hrana)') do
  f = NxValFix
  out = f.run(records: [f.rec('role' => 'front_door', 'edges' => f.edges)])
  fronts = out['items'].select { |i| i['category'] == 'front_abs' }
  NxTest.assert_equal(1, fronts.length, 'jedna polozka na celo, nie 4 per hrana')
  NxTest.assert_equal('orange', fronts.first['severity'])
  NxTest.assert(fronts.first['message_sk'].include?('ABS'))
  # celo s aspon jednou hranou = OK
  NxTest.assert(f.cats(f.run(records: [f.rec('role' => 'drawer_front', 'edges' => f.edges('L1' => 'ABS1'))])).none? { |c| c == 'front_abs' })
  # bezny dielec (shelf) bez ABS = ZIADNY ABS problem (len cela/dosky)
  NxTest.assert(f.cats(f.run(records: [f.rec('role' => 'shelf', 'edges' => f.edges)])).none? { |c| c.to_s.include?('abs') })
end

NxTest.test('validation: volna doska bez ABS = ORANGE ("skontroluj — moze byt zamer")') do
  f = NxValFix
  out = f.run(records: [f.rec('role' => 'free_panel', 'owner_id' => 'BRD-001', 'part_key' => 'board/main', 'edges' => f.edges)])
  panels = out['items'].select { |i| i['category'] == 'panel_abs' }
  NxTest.assert_equal(1, panels.length)
  NxTest.assert_equal('orange', panels.first['severity'])
  NxTest.assert(panels.first['message_sk'].include?('môže byť zámer'))
  # doska s hranou = OK
  NxTest.assert(f.cats(f.run(records: [f.rec('role' => 'free_panel', 'edges' => f.edges('W1' => 'ABS1'))])).none? { |c| c == 'panel_abs' })
end

NxTest.test('validation: vypnute kovanie (disabled:true) = ORANGE; quantity override NIE je problem') do
  f = NxValFix
  ov = [{ 'owner_id' => 'CAB-1', 'generic_type' => 'leg', 'rule_id' => 'nohy', 'disabled' => true }]
  out = f.run(hardware_overrides: ov)
  hw = out['items'].select { |i| i['category'] == 'hardware' }
  NxTest.assert_equal(1, hw.length)
  NxTest.assert_equal('orange', hw.first['severity'])
  NxTest.assert(hw.first['message_sk'].include?('vypnuté'))
  NxTest.assert(hw.first['message_sk'].include?('Nohy'), 'ludsky label kovania')
  # quantity override (nie disabled) = ziadny problem
  ov2 = [{ 'owner_id' => 'CAB-1', 'generic_type' => 'leg', 'rule_id' => 'nohy', 'quantity' => 6 }]
  NxTest.assert(f.cats(f.run(hardware_overrides: ov2)).none? { |c| c == 'hardware' })
end

NxTest.test('validation: build warning = ORANGE kategoria stavba (jediny kanon, nalez 9)') do
  f = NxValFix
  warns = [{ 'code' => 'part_skipped_degenerate', 'message' => 'Polica orezaná', 'owner_id' => 'CAB-1', 'part_key' => 'zone:z1/shelf:0' }]
  out = f.run(warnings: warns)
  b = out['items'].select { |i| i['category'] == 'build' }
  NxTest.assert_equal(1, b.length)
  NxTest.assert_equal('orange', b.first['severity'])
  NxTest.assert(b.first['message_sk'].include?('Polica orezaná'))
  NxTest.assert_equal('zone:z1/shelf:0', b.first['part_key'], 'build warning nesie part_key ak ho ma')
end

NxTest.test('validation: material mimo katalogu POTLACI drift aj oversize toho isteho dielca (nalez 10)') do
  f = NxValFix
  out = f.run(records: [f.rec('material_id' => 'NEZNAMY', 'thickness' => 25.0, 'length' => 9999.0)])
  NxTest.assert(f.cats(out).include?('material'))
  NxTest.refute(f.cats(out).include?('thickness'), 'bez katalogovej pravdy sa drift nehlasi druhykrat')
  NxTest.refute(f.cats(out).include?('oversize'), 'bez formatu platne sa oversize nehlasi')
  NxTest.assert_equal(1, out['counts']['red'])
end

NxTest.test('validation: dielec v katalogu moze mat drift AJ oversize = 2 RED (rozne stable_key)') do
  f = NxValFix
  out = f.run(records: [f.rec('material_id' => 'K009_16', 'thickness' => 18.0, 'length' => 3000.0, 'role' => 'side_left')])
  NxTest.assert_equal(%w[oversize thickness], f.cats(out).sort)
  NxTest.assert_equal(2, out['counts']['red'])
  keys = out['items'].map { |i| i['stable_key'] }.uniq
  NxTest.assert_equal(2, keys.length, 'rozne stable_key pre rozne problemy toho isteho dielca')
end

NxTest.test('validation: dedup rovnakeho problemu, counts z FINALNEHO zoznamu') do
  f = NxValFix
  bad = f.rec('material_id' => 'NEZNAMY', 'part_key' => 'cabinet/side:left', 'owner_id' => 'CAB-1')
  out = f.run(records: [bad, bad.dup, bad.dup])
  NxTest.assert_equal(1, out['items'].select { |i| i['category'] == 'material' }.length, 'dedup: rovnaky stable_key = 1 polozka')
  NxTest.assert_equal(out['items'].count { |i| i['severity'] == 'red' }, out['counts']['red'])
  NxTest.assert_equal(out['items'].count { |i| i['severity'] == 'orange' }, out['counts']['orange'])
  NxTest.assert_equal(out['items'].length, out['counts']['total'])
end

NxTest.test('validation: RED pred ORANGE, poradie NEZAVISI od vstupneho poradia (determinizmus)') do
  f = NxValFix
  records = [
    f.rec('role' => 'front_door', 'owner_id' => 'CAB-2', 'part_key' => 'front:d/door', 'edges' => f.edges), # ORANGE
    f.rec('material_id' => 'NEZNAMY', 'owner_id' => 'CAB-1', 'part_key' => 'cabinet/side:left')             # RED
  ]
  a = f.run(records: records)
  b = f.run(records: records.reverse)
  NxTest.assert_equal(a['items'].map { |i| i['stable_key'] }, b['items'].map { |i| i['stable_key'] }, 'poradie stabilne')
  NxTest.assert_equal('red', a['items'].first['severity'], 'RED je prve')
  NxTest.assert_equal(1, a['counts']['red'])
  NxTest.assert_equal(1, a['counts']['orange'])
end

NxTest.test('validation: prazdny vstup = ziadne polozky, nulove counts') do
  out = NxValFix.run
  NxTest.assert_equal([], out['items'])
  NxTest.assert_equal({ 'red' => 0, 'orange' => 0, 'total' => 0 }, out['counts'])
end

NxTest.test('validation: chybajuci format platne = oversize sa NEhlasi (bez formatu neni pravda)') do
  f = NxValFix
  sheets = { 'NO_FMT' => { 'material_id' => 'NO_FMT', 'thickness' => 18.0, 'sheet_size' => nil } }
  out = f.run(records: [f.rec('material_id' => 'NO_FMT', 'length' => 9999.0)], sheets: sheets)
  NxTest.assert(f.cats(out).none? { |c| c == 'oversize' }, 'bez sheet_size sa zmestenie nekontroluje')
end

NxTest.test('validation: vypnute kovanie na DVOCH dielcoch = DVE polozky s part_key (Codex GH #65 P2)') do
  f = NxValFix
  ovs = [
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front/wing:p1', 'generic_type' => 'hinge', 'rule_id' => 'zavesy', 'disabled' => true },
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front/wing:p2', 'generic_type' => 'hinge', 'rule_id' => 'zavesy', 'disabled' => true }
  ]
  out = f.run(hardware_overrides: ovs)
  hw = out['items'].select { |i| i['category'] == 'hardware' }
  NxTest.assert_equal(2, hw.length)
  NxTest.assert_equal(%w[front/wing:p1 front/wing:p2], hw.map { |i| i['part_key'] }.sort)
  NxTest.assert_equal(2, hw.map { |i| i['stable_key'] }.uniq.length, 'stable_key musi rozlisit owner_part_key')
end

NxTest.test('validation: dva owner-level build warnings bez code = DVE polozky (Codex GH #65 P2)') do
  f = NxValFix
  ws = [
    { 'owner_id' => 'CAB-1', 'message' => 'Prve upozornenie stavby.' },
    { 'owner_id' => 'CAB-1', 'message' => 'Druhe upozornenie stavby.' }
  ]
  out = f.run(warnings: ws)
  build = out['items'].select { |i| i['category'] == 'build' }
  NxTest.assert_equal(2, build.length, 'rozne spravy sa nesmu dedupnut')
  # identicke spravy = 1 polozka (dedup dalej plati)
  out2 = f.run(warnings: [ws[0], ws[0].dup])
  NxTest.assert_equal(1, out2['items'].count { |i| i['category'] == 'build' })
end
