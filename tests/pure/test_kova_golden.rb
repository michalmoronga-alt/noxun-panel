# frozen_string_literal: true
# KOV-A1 — GOLDEN CHARAKTERIZACIA ciel (dokaz „vystupy existujucich zakaziek
# su CONTENT-identicke").
#
# CO SA OVERUJE: pre 15 reprezentativnych konfiguracii ciel (dvierka 1-4 kridla,
# auto okolo 600 mm, zasuvkove celo fixed+locked, riadok „Bez cela", profil
# UKW-7 na dvojkridle, legacy STRING fronts 'auto'/'2'/'none', mix fixed/auto,
# horna skrinka) sa CERSTVY vypocet porovnava s ODTLACKOM z MAINU:
#   * `Fronts.normalize_config` (kanonicky config)
#   * `Construction.build_plan` -> `parts` (suffix, part_key, role, name,
#     material, box, origin, prod, axes, profile), `hardware`, `warnings`,
#     `front_items`, `wings`
#
# Subory `tests/fixtures/kova_golden/*.json` vznikli PRED zmenami KOV-A1
# (generator `tests/fixtures/kova_golden/generate.rb`, spusta sa RUCNE).
# Rozdiel = NALEZ, nie sum: aditivna davka nesmie zmenit ani jedno cislo
# uz postavitelnej zakazky. Ked je zmena vedoma, regeneruje sa a zdovodni v PR.
#
# POROVNANIE: cez JSON round-trip (symboly -> stringy) a Float na 3 desatinne
# miesta — inak by sa porovnavali reprezentacie, nie hodnoty.
require_relative '../helper' unless defined?(NxTest)

require 'json'

module NxKovaGolden
  E  = Noxun::Engine
  CB = E::CabinetBuilder

  FIXTURES = File.join(NxTest::ROOT, 'tests', 'fixtures', 'kova_golden')

  # Zaklad spodnej skrinky — jedine, co sa medzi pripadmi meni, je `fronts`
  # (a pri par pripadoch sirka/typ), aby bol rozdiel v goldene citatelny.
  def self.base(over = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 100.0 }.merge(over)
  end

  def self.door(over = {})
    { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => nil,
      'locked' => false, 'wings' => 'auto' }.merge(over)
  end

  def self.items(*list)
    { 'items' => list }
  end

  CASES = {
    # --- dvierka: pocet kridiel EXPLICITNE (1/2/3/4) ------------------------
    'door_1wing'  => base('fronts' => items(door('wings' => '1'))),
    'door_2wings' => base('fronts' => items(door('wings' => '2'))),
    'door_3wings' => base('fronts' => items(door('wings' => '3'))),
    'door_4wings' => base('fronts' => items(door('wings' => '4'))),
    # --- wings 'auto' okolo hranice AUTO_TWO_ABOVE (600 mm) ----------------
    # POZOR: hranica plati na CELNY OTVOR (`opening_w = sirka - 2*gap_sides`),
    # nie na sirku korpusu — pri gap_sides 2 mm je zlom az na sirke 604 mm.
    # Preto su tu OBE: sirky z package (599/601 — obe stale 1 kridlo) aj
    # sirka 605 (otvor 601 mm), ktora hranicu SKUTOCNE prekroci.
    'auto_w599' => base('width' => 599.0, 'fronts' => items(door)),
    'auto_w601' => base('width' => 601.0, 'fronts' => items(door)),
    'auto_w605' => base('width' => 605.0, 'fronts' => items(door)),
    # --- zasuvkove celo fixed + locked -------------------------------------
    'drawer_fixed_locked' => base('fronts' => items(
      { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
        'height' => 140.0, 'locked' => true }
    )),
    # --- riadok „Bez cela" v rade (D-18) ------------------------------------
    'none_row_in_stack' => base('fronts' => items(
      { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 140.0, 'locked' => true },
      { 'id' => 'F2', 'type' => 'none', 'mode' => 'fixed', 'height' => 120.0, 'locked' => true },
      door('id' => 'F3')
    )),
    # --- profil UKW-7 na dvojkridle (D-90) ----------------------------------
    'profile_ukw7_2wings' => base('fronts' => items(
      door('wings' => '2', 'mode' => 'fixed', 'height' => 500.0, 'locked' => true, 'profile' => 'ukw7')
    )),
    # --- legacy STRING fronts (V0.1/V0.2) -----------------------------------
    'legacy_string_auto' => base('fronts' => 'auto'),
    'legacy_string_2'    => base('fronts' => '2'),
    'legacy_string_none' => base('fronts' => 'none'),
    # --- mix fixed/auto -----------------------------------------------------
    'mix_fixed_auto' => base('fronts' => items(
      { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 140.0, 'locked' => true },
      { 'id' => 'F2', 'type' => 'drawer_front', 'mode' => 'auto' },
      door('id' => 'F3', 'wings' => '2')
    )),
    # --- horna skrinka ------------------------------------------------------
    'upper_cabinet' => base('type' => 'upper', 'height' => 720.0, 'depth' => 320.0,
                            'floor_height' => 0.0,
                            'fronts' => items(door('wings' => '2')))
  }.freeze

  module_function

  # Rekurzivny prevod na cisty JSON tvar + zaokruhlenie Floatov (reprezentacia
  # Floatu sa medzi behmi lisi na poslednom bite, hodnota nie).
  def norm(value)
    case value
    when Hash  then value.each_with_object({}) { |(k, v), out| out[k.to_s] = norm(v) }
    when Array then value.map { |v| norm(v) }
    when Float then value.round(3)
    when Symbol then value.to_s
    else value
    end
  end

  PART_FIELDS = %i[suffix part_key role name material box origin prod axes profile].freeze

  def part_row(pd)
    PART_FIELDS.each_with_object({}) { |k, out| out[k.to_s] = norm(pd[k]) }
  end

  # Odtlacok jednej konfiguracie. VSETKO ide cez `norm` — golden subor je tak
  # bajtovo porovnatelny s cerstvym vypoctom.
  def snapshot(params)
    cfg  = CB.normalize(params)
    plan = E::Construction.build_plan(cfg)
    {
      'normalize_config' => norm(E::Fronts.normalize_config(params['fronts'])),
      'parts' => plan[:parts].map { |pd| part_row(pd) },
      'hardware' => norm(plan[:hardware]),
      'warnings' => norm(plan[:warnings]),
      'front_items' => norm(plan[:front_items]),
      'wings' => plan[:wings]
    }
  end

  def golden_path(name)
    File.join(FIXTURES, "#{name}.json")
  end

  def golden(name)
    JSON.parse(File.read(golden_path(name)))
  end
end

NxKovaGolden::CASES.each_key do |name|
  NxTest.test("KOV-A1 golden: #{name} — vystup je zhodny s odtlackom z mainu") do
    g = NxKovaGolden
    path = g.golden_path(name)
    NxTest.assert(File.file?(path), "chyba golden subor #{path} (spusti tests/fixtures/kova_golden/generate.rb)")
    want = g.golden(name)
    have = g.snapshot(g::CASES[name])
    %w[normalize_config wings hardware warnings front_items].each do |key|
      NxTest.assert_equal(want[key], have[key], "#{name}: kluc '#{key}' sa rozisiel s goldenom")
    end
    NxTest.assert_equal(want['parts'].length, have['parts'].length, "#{name}: iny pocet dielcov")
    want['parts'].each_with_index do |wp, i|
      NxTest.assert_equal(wp, have['parts'][i], "#{name}: dielec ##{i + 1} (#{wp['suffix']}) sa rozisiel s goldenom")
    end
  end
end

NxTest.test('KOV-A1 golden: sada pokryva vsetky ulozene fixtures (ziadny osirely subor)') do
  files = Dir[File.join(NxKovaGolden::FIXTURES, '*.json')].map { |p| File.basename(p, '.json') }.sort
  NxTest.assert_equal(NxKovaGolden::CASES.keys.sort, files,
                      'zoznam golden suborov nesedi so zoznamom pripadov CASES')
end
