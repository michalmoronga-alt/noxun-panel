# frozen_string_literal: true
# H12d (blok 9 HARDENING, C-05) — MENA ROLI NA JEDNOM MIESTE (package H12 §6
# R4.1–R4.4, guard T3f, mutacia M16).
#
#   * `PartKeys::ROLE_LABELS` je JEDINA tabulka zobrazovacich mien roli;
#     pokryva kazdu rolu `BuildPlan::ROLES` okrem rezervovanych a nic navyse,
#   * `ProductionCore::ROLE_LABELS`/`role_label` su alias a delegacia (Kusovnik,
#     Studio a prehlad ABS bez zmeny), `ZONE_PART_LABELS`/`DRAWER_PART_LABELS`
#     su odvodene, `Panel::BOARD_ROLE_LABELS` zanikla,
#   * payload karty dielca nesie `role_label` (hotovy text pre JS),
#   * v `ui/js` nie je mapa mien roli ani funkcia `roleLabel` (T3f),
#   * INE tvary mien (`Recipes.role_label` — vety hlasok) sa nemenia (R4.4).
# Bajty mien drzi golden `test_h12d_roles_golden.rb` (fixtura `roles.json`).
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxH12d
  module_function

  E = Noxun::Engine
  # Roly, ktore plan nevydava (rezerva slovnika) — meno nemaju, vypisu sa surovo.
  RESERVED = %w[cover_panel gola_profile].freeze

  def src(rel)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
  end

  def js_files
    Dir[File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', '*.js')].sort
  end
end

NxTest.test('H12d R4.4 / T3f: PartKeys::ROLE_LABELS pokryva kazdu rolu planu (okrem rezervovanych) a nic navyse') do
  labels = NxH12d::E::PartKeys::ROLE_LABELS
  roles = NxH12d::E::BuildPlan::ROLES
  (roles - NxH12d::RESERVED).each do |r|
    NxTest.assert(labels[r].is_a?(String) && !labels[r].empty?,
                  "rola #{r} nema zobrazovacie meno — doplnit do PartKeys::ROLE_LABELS (mapa rozsirovacie-body.md, scenar 2)")
    NxTest.refute(labels[r] == r, "rola #{r}: meno nesmie byt surovy identifikator")
  end
  NxH12d::RESERVED.each do |r|
    NxTest.assert(roles.include?(r), "#{r} je stale rola slovnika")
    NxTest.refute(labels.key?(r), "#{r}: rezervovana rola meno nema (plan ju nevydava)")
  end
  NxTest.assert_equal([], labels.keys - roles, 'ROLE_LABELS nesie len roly planu')
  NxTest.assert(labels.frozen?, 'tabulka je zamrznuta')
end

NxTest.test('H12d R4.1: ProductionCore je alias a delegacia — druha tabulka mien neexistuje') do
  e = NxH12d::E
  NxTest.assert(e::ProductionCore::ROLE_LABELS.equal?(e::PartKeys::ROLE_LABELS), 'ProductionCore::ROLE_LABELS = ten isty objekt')
  (e::BuildPlan::ROLES + ['neznama', '', nil, :shelf]).each do |r|
    NxTest.assert_equal(e::PartKeys.role_label(r), e::ProductionCore.role_label(r), "role_label #{r.inspect}")
  end
  pc = NxH12d.src('ui/production_core.rb')
  NxTest.refute(pc.include?("'side_left' =>"), 'production_core.rb nesmie niest vlastnu mapu mien roli')
  NxTest.assert(pc.include?('ROLE_LABELS = PartKeys::ROLE_LABELS'), 'alias na jedinu tabulku')
end

NxTest.test('H12d R4.2: ZONE_PART_LABELS a DRAWER_PART_LABELS su odvodene, BOARD_ROLE_LABELS zanikla') do
  pk = NxH12d::E::PartKeys
  pk::ZONE_PART_LABELS.each { |r, l| NxTest.assert_equal(pk::ROLE_LABELS.fetch(r), l, "zona #{r}") }
  pk::DRAWER_PART_LABELS.each do |r, l|
    full = pk::ROLE_LABELS.fetch(r)
    NxTest.assert_equal(full[0].downcase + full[1..], l, "zasuvka #{r}: male prve pismeno")
  end
  NxTest.assert_equal(%w[shelf divider_v divider_h], pk::ZONE_PART_LABELS.keys)
  NxTest.assert_equal(%w[drawer_bottom drawer_back drawer_inner_front], pk::DRAWER_PART_LABELS.keys)
  src = NxH12d.src('core/part_keys.rb')
  NxTest.assert_equal(1, src.scan("'dno zásuvky'").length + src.scan("'Dno zásuvky'").length,
                      'meno dna zasuvky je v part_keys.rb raz (tabulka), nie kopia v odvodenej mape')
  NxTest.refute(NxH12d::E::Panel.const_defined?(:BOARD_ROLE_LABELS), 'Panel::BOARD_ROLE_LABELS zanikla')
  NxTest.refute(NxH12d.src('ui/panel/payloads.rb').include?('BOARD_ROLE_LABELS'), 'ziadna zmienka v payloads.rb')
end

NxTest.test('H12d R4.3: payload karty dielca nesie role_label (meno ako v Kusovniku)') do
  NxTest.skip!('payload potrebuje Store fake') unless NxTest.headless?
  e = NxH12d::E
  cab = NxTest::FakeInstance.new(7101)
  e::Store.write(cab, { std: e::Store::STD, kind: 'cabinet', cabinet_id: 'CAB-901', config: {} })
  { 'top' => 'Strop', 'drawer_bottom' => 'Dno zásuvky', 'cover_panel' => 'cover_panel', 'neznama' => 'neznama' }.each_with_index do |(role, want), i|
    part = NxTest::FakeInstance.new(7200 + i)
    e::Store.write(part, { std: e::Store::STD, kind: 'part', role: role, name: 'Vrch', part_key: "cabinet/x#{i}",
                           config: { 'length' => 600.0, 'width' => 560.0, 'thickness' => 18.0, 'edges' => {} } })
    pay = e::Panel.part_card_payload(nil, cab, part)
    NxTest.assert(pay.is_a?(Hash), "payload karty pre #{role} vznikol")
    NxTest.assert_equal(want, pay['role_label'], "#{role}: role_label")
    NxTest.assert_equal(role, pay['role'], "#{role}: surova rola ostava (isFront, hrany)")
    NxTest.assert_equal('Vrch', pay['name'], 'vyrobny nazov dielca sa nemeni')
  end
end

NxTest.test('H12d T3f: v ui/js nie je mapa mien roli ani funkcia roleLabel') do
  # Kluce, ktore su LEN rolami dielcov — `top`/`bottom`/`back` su aj strany
  # hran a `drawer_front`/`flap`/`false_front` aj typy cela (FRONT_TYPE_LABEL).
  shared = %w[top bottom back drawer_front flap false_front]
  only = NxH12d::E::BuildPlan::ROLES - shared
  map_re = /\b(#{only.join('|')})\s*:\s*['"]/
  NxH12d.js_files.each do |f|
    js = File.read(f, encoding: 'UTF-8')
    name = File.basename(f)
    NxTest.refute(js.match?(/function\s+roleLabel\b/), "#{name}: JS funkcia roleLabel zanikla — meno roly sklada server")
    hit = js[map_re]
    NxTest.assert(hit.nil?, "#{name}: JS mapa mien roli (#{hit}) — meno roly patri do PartKeys::ROLE_LABELS, karta cita `role_label`")
  end
  pc = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'part_card.js'), encoding: 'UTF-8')
  NxTest.assert(pc.include?('pc.role_label || pc.role'), 'karta dielca cita meno roly zo servera')
  br = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
  NxTest.assert(br.include?('sel.name || sel.role_label || sel.role'), 'polozka raily cita meno roly zo servera')
end

NxTest.test('H12d R4.4: ine tvary mien (vety hlasok zasuviek) sa nemenia') do
  rec = NxH12d::E::Recipes
  { 'drawer_bottom' => 'dno', 'drawer_back' => 'chrbát', 'box_side' => 'bok boxu', 'drawer_inner_front' => 'vnútorné čelo',
    'shelf' => 'policu', 'divider_h' => 'vodorovnú priečku', 'divider_v' => 'zvislú priečku' }.each do |role, want|
    NxTest.assert_equal(want, rec.role_label(role), "Recipes.role_label #{role} (akuzativ do viet)")
  end
end
