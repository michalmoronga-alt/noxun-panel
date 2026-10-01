# frozen_string_literal: true
# H3 (blok 9 HARDENING) — CHARAKTERIZACIA PRED ZASAHOM.
#
# PRECO: davka H3a meni LEN to, co okno Studia ukazuje (Kusovnik, Ponuka,
# Kontrola, Nakup kovania, Nastavenia rozpoctu). Zavazok bloku: vyrobne a cenove
# cisla sa NEMENIA. Tato sada vznikla nad mainom PRED zasahom a pripina dnesny
# tvar serverovych vstupov okna:
#   * `totals_payload` (suctovy riadok Kusovnika) — vratane `plates_min/max`
#     (sucet cez VSETKY polozky odhadu; okno ho po H3a uz nezobrazi, payload
#     ostava, PACKAGE_H3 §12 D2),
#   * `Validation.counts` s `cabinets`/`clean` (zelene cislo semaforu),
#   * `SupplierSettingsDialog.settings_payload` (kluce + revizia),
#   * `ProductionCore.hardware_labeled` nad pripadmi `kovh_golden`
#     (`label`, `params_label`, `breakdown` a vsetky povodne polia).
#
# Po zasahu musi ostat ZELENA. JEDINY dovoleny rozdiel su NOVE ADITIVNE kluce
# (`params_text`, `where` v generike, `effective` v nastaveniach) — test ich pred
# porovnanim vyberie; ich obsah overuje `test_h3_zobrazenie.rb`.
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'
require 'tmpdir'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') unless defined?(Noxun::Engine::StudioDialog)
  unless defined?(Noxun::Engine::SupplierSettingsDialog)
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog')
  end
end
require_relative 'test_kovh_golden' unless defined?(NxKovhGolden)

module NxH3Char
  E = Noxun::Engine

  # Nove aditivne kluce H3a — jediny dovoleny rozdiel oproti mainu.
  HW_ADDITIVE = %w[params_text where].freeze
  SETTINGS_ADDITIVE = %w[effective].freeze

  # Odtlacok z mainu c558b608 (v0.17.0): [label, params_label, quantity, pocet zaznamov breakdown]
  HW_PINNED = {
    'viac_skriniek' => [['Závesy', nil, 7, 3]],
    'per_owner' => [['Závesy', nil, 6, 3]],
    'code_by_nl' => [['Výsuv', nil, 1, 1], ['Výsuv', nil, 1, 1], ['Výsuv', nil, 2, 1]],
    'manual_d93' => [['Výsuv', nil, 2, 2]],
    'nemapovana' => [['Závesy', nil, 2, 1], ['Nohy', nil, 4, 1]],
    'chybajuci_kod' => [['Nohy', nil, 8, 2]],
    'seed_kniznica' => [['Závesy', nil, 5, 2], ['Nohy', nil, 4, 1], ['Podperky', nil, 4, 1],
                        ['Výsuv', nil, 1, 1], ['Výsuv', nil, 2, 1], ['Zavesenie na stenu', nil, 2, 1]]
  }.freeze

  SETTINGS_KEYS = %w[about demos mode_labels modes path rate_keys rate_labels revision
                     scalar_ranges settings_state standard_rows supplier version].freeze

  module_function

  def with_sandbox
    prev = E::Materials.test_dir_override
    dir = Dir.mktmpdir('nx-h3-')
    E::Materials.test_dir_override = dir
    E::JsonFileStore.invalidate
    yield dir
  ensure
    E::Materials.test_dir_override = prev
    E::JsonFileStore.invalidate
    begin
      FileUtils.remove_entry(dir)
    rescue StandardError
      nil
    end
  end
end

NxTest.test('H3 charakterizacia: totals_payload — sucty a odhad platni = sucet cez VSETKY polozky odhadu') do
  bom = { summary: { 'quantity' => 42, 'rows' => 17, 'm2_total' => 12.3456, 'bm_total' => 88.25 },
          sheets: [{ 'material_id' => 'A' }, { 'material_id' => 'B' }],
          edging: [{ 'abs_id' => 'E1' }] }
  estimate = [{ 'material_id' => 'A', 'count_min' => 1.1, 'count_max' => 1.3 },
              { 'material_id' => 'B', 'count_min' => 0.6, 'count_max' => 0.7 },
              { 'material_id' => 'DUP', 'count_min' => 0.5, 'count_max' => 0.6 }]
  t = Noxun::Engine::StudioDialog.send(:totals_payload, bom, estimate)
  NxTest.assert_equal({ 'parts' => 42, 'rows' => 17, 'm2' => 12.3456, 'bm' => 88.25,
                        'materials' => 2, 'edges' => 1, 'plates_min' => 2.2, 'plates_max' => 2.6 }, t,
                      'tvar aj hodnoty suctoveho riadku su odtlacok mainu (plates_* ostavaju v payloade)')
end

NxTest.test('H3 charakterizacia: Validation.counts nesie cabinets/clean (menovatel zeleneho chipu)') do
  items = [{ 'severity' => 'orange', 'owner_id' => 'CAB-1' },
           { 'severity' => 'orange', 'owner_id' => 'CAB-1' },
           { 'severity' => 'red', 'owner_id' => 'CAB-2' },
           { 'severity' => 'orange', 'owner_id' => nil }]
  ids = %w[CAB-1 CAB-2 CAB-3 CAB-4 CAB-5 CAB-6 CAB-7]
  c = Noxun::Engine::Validation.counts(items, cabinet_ids: ids, cabinets: 7)
  NxTest.assert_equal({ 'red' => 1, 'orange' => 3, 'total' => 4, 'cabinets' => 7, 'clean' => 5 }, c)
  NxTest.assert_equal({ 'red' => 1, 'orange' => 3, 'total' => 4 },
                      Noxun::Engine::Validation.counts(items), 'legacy volanie bez cabinet_ids sa nemeni')
end

NxTest.test('H3 charakterizacia: settings_payload — kluce a revizia (iba citanie)') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxH3Char.with_sandbox do
    ss = Noxun::Engine::SupplierSettings
    data = Noxun::Engine::SupplierSettingsDialog.settings_payload
    NxTest.assert(data.is_a?(Hash), 'payload sa zostavil')
    keys = data.keys - NxH3Char::SETTINGS_ADDITIVE
    NxTest.assert_equal(NxH3Char::SETTINGS_KEYS, keys.sort, 'kluce payloadu = odtlacok mainu (+ aditivne)')
    NxTest.assert_equal(ss.revision(ss.active), data['revision'], 'revizia = revizia aktivneho dodavatela')
    NxTest.assert_equal(%w[nizky standard vysoky], data['modes'], 'poradie rezimov')
    again = Noxun::Engine::SupplierSettingsDialog.settings_payload
    NxTest.assert_equal(data['revision'], again['revision'], 'opakovane zostavenie reviziu nemeni')
  end
end

NxKovhGolden::CASES.each do |name, kase|
  NxTest.test("H3 charakterizacia: hardware_labeled nad kovh_golden #{name} — povodne polia + label/params_label") do
    hw = Noxun::Engine::Bom.hardware_totals(kase['items'])
    before = Marshal.dump(hw)
    out = Noxun::Engine::ProductionCore.hardware_labeled({ hardware: hw })
    NxTest.assert_equal(before, Marshal.dump(hw), "#{name}: vstup sa nezmutoval")
    NxTest.assert_equal(hw.length, out.length, "#{name}: pocet poloziek")
    pinned = NxH3Char::HW_PINNED.fetch(name)
    NxTest.assert_equal(pinned.length, out.length, "#{name}: pocet poloziek = odtlacok")
    out.each_with_index do |g, i|
      base = g.reject { |k, _| NxH3Char::HW_ADDITIVE.include?(k) }
      want = hw[i].merge('label' => pinned[i][0], 'params_label' => pinned[i][1])
      NxTest.assert_equal(want, base, "#{name}[#{i}]: polozka = povodne polia + label + params_label")
      NxTest.assert_equal(pinned[i][2], g['quantity'], "#{name}[#{i}]: pocet kusov")
      NxTest.assert_equal(pinned[i][3], g['breakdown'].length, "#{name}[#{i}]: breakdown sa nezlucuje (klik-select)")
    end
  end
end
