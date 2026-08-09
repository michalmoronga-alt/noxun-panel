# frozen_string_literal: true
# D-103: zachytna siet „dva kusy na jednom mieste" v kontrolnom semafore.
# Cisty modul (Validation) — fixtures krmia `placements` presne v tvare, aky
# zbiera Bom.collect (mm Float, normalizovane osi, vonkajsie rozmery definicie).
# Pokryte: pozitivny pripad, hranica epsilonu (tesne pod/nad), rozne druhy,
# legitimne odlisne pozicie, orientacia, rozmery, guardy vstupu, stabilny kluc,
# klik-adresa skupiny, dedup a to, ze bez `placements:` sa nemeni NIC.
require_relative '../helper' unless defined?(NxTest)

module NxD103Fix
  module_function

  V = Noxun::Engine::Validation

  IDENTITY_AXES = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0].freeze

  def place(id, kind: 'board', origin: [1000.0, 0.0, 0.0], axes: IDENTITY_AXES,
            size: [400.0, 300.0, 18.0])
    { 'kind' => kind, 'owner_id' => id, 'origin' => origin.dup,
      'axes' => axes.dup, 'size' => size.dup }
  end

  def run(placements)
    V.run({ records: [], hardware_overrides: [], warnings: [] },
          sheets: {}, placements: placements)
  end

  def dups(out)
    out['items'].select { |i| i['category'] == V::CAT_DUPLICATE }
  end
end

NxTest.test('D-103: dve dosky na identickom mieste = 1 ORANGE nalez (nikdy RED, nikdy sa nic nemaze)') do
  f = NxD103Fix
  out = f.run([f.place('BRD-002'), f.place('BRD-003')])
  d = f.dups(out)
  NxTest.assert_equal(1, d.length)
  NxTest.assert_equal('orange', d.first['severity'])
  NxTest.assert(d.first['message_sk'].include?('BRD-002 a BRD-003'))
  NxTest.assert(d.first['message_sk'].include?('na rovnakom mieste'))
  # export sa nikdy neblokuje — semafor len varuje
  NxTest.assert_equal(0, out['counts']['red'])
  NxTest.assert_equal(1, out['counts']['orange'])
end

NxTest.test('D-103: legitimne odlisne pozicie = ziadny nalez (nasobenie po 200 mm)') do
  f = NxD103Fix
  places = [0.0, 200.0, 400.0, 600.0, 800.0].each_with_index.map do |dx, i|
    f.place(format('BRD-%03d', i + 1), origin: [1000.0 + dx, 0.0, 0.0])
  end
  NxTest.assert_equal(0, f.dups(f.run(places)).length)
end

NxTest.test('D-103: hranica epsilonu — 0,001 mm este zhoda, 0,002 mm uz nie') do
  f = NxD103Fix
  on_edge = f.run([f.place('BRD-002'), f.place('BRD-003', origin: [1000.001, 0.0, 0.0])])
  NxTest.assert_equal(1, f.dups(on_edge).length, 'presne na tolerancii = stale ta ista poloha')
  over = f.run([f.place('BRD-002'), f.place('BRD-003', origin: [1000.002, 0.0, 0.0])])
  NxTest.assert_equal(0, f.dups(over).length, 'nad toleranciou = dva rozne kusy, ziadny poplach')
end

NxTest.test('D-103: rozny DRUH sa nikdy nespari (skrinka a doska v jednom bode)') do
  f = NxD103Fix
  out = f.run([f.place('BRD-002', kind: 'board'), f.place('CAB-001', kind: 'cabinet')])
  NxTest.assert_equal(0, f.dups(out).length)
end

NxTest.test('D-103: dve skrinky na jednom mieste = nalez so slovenskym „Skrinky"') do
  f = NxD103Fix
  d = f.dups(f.run([f.place('CAB-002', kind: 'cabinet', size: [600.0, 720.0, 510.0]),
                    f.place('CAB-003', kind: 'cabinet', size: [600.0, 720.0, 510.0])]))
  NxTest.assert_equal(1, d.length)
  NxTest.assert(d.first['message_sk'].start_with?('Skrinky CAB-002 a CAB-003'))
  NxTest.assert_equal('cabinet', d.first['dup_kind'])
end

NxTest.test('D-103: ina ORIENTACIA pri rovnakom bode nie je duplikat (otoceny kus)') do
  f = NxD103Fix
  rotated = [0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0] # otocenie o 90 stupnov okolo Z
  NxTest.assert_equal(0, f.dups(f.run([f.place('BRD-002'), f.place('BRD-003', axes: rotated)])).length)
  # ...ale zanedbatelna odchylka osi (pod 1e-6) zhodu nerozbije
  near = [1.0, 5.0e-7, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
  NxTest.assert_equal(1, f.dups(f.run([f.place('BRD-002'), f.place('BRD-003', axes: near)])).length)
end

NxTest.test('D-103: ine ROZMERY pri rovnakom bode nie su duplikat (rozne dosky nad sebou)') do
  f = NxD103Fix
  NxTest.assert_equal(0, f.dups(f.run([f.place('BRD-002'),
                                       f.place('BRD-003', size: [500.0, 300.0, 18.0])])).length)
end

NxTest.test('D-103: TRI kusy na jednom mieste = JEDEN nalez o celej skupine') do
  f = NxD103Fix
  d = f.dups(f.run([f.place('BRD-002'), f.place('BRD-003'), f.place('BRD-004')]))
  NxTest.assert_equal(1, d.length)
  NxTest.assert_equal(%w[BRD-002 BRD-003 BRD-004], d.first['dup_owner_ids'])
  NxTest.assert(d.first['message_sk'].include?('BRD-002, BRD-003 a BRD-004'))
end

NxTest.test('D-103: dve NEZAVISLE kolizie = dva riadky (dedup ich nesmie zliat)') do
  f = NxD103Fix
  out = f.run([f.place('BRD-002'), f.place('BRD-003'),
               f.place('BRD-007', origin: [5000.0, 0.0, 0.0]),
               f.place('BRD-008', origin: [5000.0, 0.0, 0.0])])
  d = f.dups(out)
  NxTest.assert_equal(2, d.length)
  NxTest.assert_equal(d.map { |i| i['stable_key'] }.uniq.length, 2)
end

NxTest.test('D-103: stable_key nesie druh aj zoradene ID a nezavisi od poradia vstupu') do
  f = NxD103Fix
  a = f.dups(f.run([f.place('BRD-003'), f.place('BRD-002')])).first
  b = f.dups(f.run([f.place('BRD-002'), f.place('BRD-003')])).first
  NxTest.assert_equal('duplicate_position|board|BRD-002,BRD-003', a['stable_key'])
  NxTest.assert_equal(a['stable_key'], b['stable_key'])
  NxTest.assert_equal(a['message_sk'], b['message_sk'])
  # klik-adresa = cela skupina, nie len prvy clen
  NxTest.assert_equal(%w[BRD-002 BRD-003], a['dup_owner_ids'])
  NxTest.assert_equal('BRD-002', a['owner_id'])
  NxTest.assert(a['part_key'].nil?, 'nalez patri celym objektom, nie dielcu')
end

NxTest.test('D-103: guardy vstupu — bez ID, s nekonecnym cislom, s nulovym rozmerom sa NEPOROVNAVA') do
  f = NxD103Fix
  bad = [
    [f.place(''), f.place('')],                                   # bez identity
    [f.place('BRD-002', size: [0.0, 300.0, 18.0]),
     f.place('BRD-003', size: [0.0, 300.0, 18.0])],               # degenerovana definicia
    [f.place('BRD-002', origin: [Float::INFINITY, 0.0, 0.0]),
     f.place('BRD-003', origin: [Float::INFINITY, 0.0, 0.0])],    # nekonecno
    [f.place('BRD-002').merge('axes' => [1.0, 0.0, 0.0]),
     f.place('BRD-003').merge('axes' => [1.0, 0.0, 0.0])],        # neuplne osi
    [f.place('BRD-002').merge('origin' => nil), f.place('BRD-003').merge('origin' => nil)],
    [f.place('BRD-002', kind: ''), f.place('BRD-003', kind: '')]
  ]
  bad.each_with_index do |places, i|
    NxTest.assert_equal(0, f.dups(f.run(places)).length, "poskodeny vstup #{i} nesmie hlasit nic")
  end
  # ...a poskodeny zaznam nesmie zhodit ani zvysok zoznamu
  mixed = f.run([f.place('BRD-002', size: [0.0, 0.0, 0.0]),
                 f.place('BRD-007', origin: [5000.0, 0.0, 0.0]),
                 f.place('BRD-008', origin: [5000.0, 0.0, 0.0])])
  NxTest.assert_equal(1, f.dups(mixed).length)
end

NxTest.test('D-103: bez `placements:` sa kontrola cela preskoci (legacy volania nedotknute)') do
  v = Noxun::Engine::Validation
  out = v.run({ records: [], hardware_overrides: [], warnings: [] }, sheets: {})
  NxTest.assert_equal(0, out['items'].length)
  # aj vyslovne nil / nespravny typ = ticho preskocene
  NxTest.assert_equal(0, v.run({}, sheets: {}, placements: nil)['items'].length)
  NxTest.assert_equal(0, v.run({}, sheets: {}, placements: 'nezmysel')['items'].length)
end
