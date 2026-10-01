# frozen_string_literal: true
# H3a (blok 9 HARDENING) — zavadzajuce udaje v okne Studia: SERVEROVA strana.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. `HardwareSets.params_text` — ludske parametre generiky („NL 470 mm ·
#      výška čela 150 mm") v PEVNOM poradi; neznamy kluc sa nestrati.
#      `params_label` (CSV kovania + vety Kontroly) sa NEMENI.
#   2. `ProductionCore.hardware_where` — zluceny povod pre stlpec „Kde": dve
#      zasuvky tej istej skrinky = jeden zaznam ×2, rucna sa NIKDY nezleje
#      s pravidlovou, poradie prveho vyskytu. Zlucuje SERVER (studio.js
#      nesmie scitavat — guard ŠT-1a).
#   3. `ProductionCore.hardware_sets_labeled` — SK popisok kategorie pre okno,
#      VSTUP sa NEMUTUJE (ten isty `hw_exp` cita plan, Rozpocet aj Kontrola)
#      a CSV kovania z toho isteho `exp` je pred aj po volani BAJTOVO rovnake.
#   4. `effective` v payloade Nastaveni = presne `SupplierSettings.rate` /
#      `row_rate` (aj seed pri chybajucom zaklade) a citanie reviziu nemeni.
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

module NxH3Z
  E = Noxun::Engine
  STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'), encoding: 'UTF-8')
  CORE_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'), encoding: 'UTF-8')

  module_function

  def with_sandbox
    prev = E::Materials.test_dir_override
    dir = Dir.mktmpdir('nx-h3z-')
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

  def bd(owner, qty, source = 'rule', note = nil)
    h = { 'owner_id' => owner, 'quantity' => qty, 'source' => source, 'owner_pid' => 7 }
    h['manual_note'] = note if note
    h
  end
end

# --- 1) params_text ---------------------------------------------------------

NxTest.test('H3a params_text: matica R-A04-2 (poradie, slovnik, fmt_mm)') do
  hs = Noxun::Engine::HardwareSets
  NxTest.assert_equal('NL 470 mm · výška čela 150 mm',
                      hs.params_text('nominal_length' => 470.0, 'front_height' => 150.0))
  NxTest.assert_equal('NL 470 mm · výška čela 150 mm',
                      hs.params_text('front_height' => 150.0, 'nominal_length' => 470.0),
                      'poradie je PEVNE, nie poradie klucov v hashi')
  NxTest.assert_equal('dvierka · klasické otváranie', hs.params_text('use_type' => 'door', 'opening_mode' => 'classic'))
  NxTest.assert_equal('dvierka · Tip-On', hs.params_text('use_type' => 'door', 'opening_mode' => 'tipon'))
  NxTest.assert_equal('výška sokla 100 mm', hs.params_text('height' => 100.0))
  NxTest.assert_equal('rez 597 mm', hs.params_text('cut_length_mm' => 597.0, 'profile' => 'UKW'),
                      'rez = HardwareRules.params_label, profil sa nevypisuje')
  NxTest.assert_equal('NL 302,5 mm', hs.params_text(nominal_length: 302.5), 'symbolove kluce, SK ciarka bez zaokruhlenia')
  NxTest.assert_equal('zásuvka · kovové bočnice', hs.params_text('use_type' => 'drawer', 'drawer_construction' => 'metal'))
  NxTest.assert_equal(nil, hs.params_text({}), 'prazdny hash = nil')
  NxTest.assert_equal(nil, hs.params_text(nil), 'nil = nil')
  NxTest.assert_equal(nil, hs.params_text('use_type' => 'other', 'opening_mode' => 'other'),
                      '`other` sa vynecha (neuplatnuje sa)')
  NxTest.assert_equal(nil, hs.params_text('nominal_length' => nil, 'height' => ' '), 'kluc bez hodnoty sa vynecha')
end

NxTest.test('H3a params_text: vyklop, neznama trieda a neznamy kluc (nic sa nestrati)') do
  hs = Noxun::Engine::HardwareSets
  NxTest.assert_equal('výklop · HK top (veko) · stabilizačné tyče 2 · s predĺžením tyče · mechanizmus HK-S',
                      hs.params_text('use_type' => 'lift', 'lift_system' => 'hk_top', 'lift_class' => 'HK-S',
                                     'rod_count' => 2, 'rod_extension' => 1))
  NxTest.assert_equal('výklop · HL top (paralelný zdvih) · stabilizačné tyče 1 · mechanizmus HL1 · ramená A2',
                      hs.params_text('use_type' => 'lift', 'lift_system' => 'hl_top', 'lift_class' => 'HL1',
                                     'arm_class' => 'A2', 'rod_count' => 1, 'rod_extension' => 0),
                      'rod_extension 0 sa vynecha')
  NxTest.assert_equal('xyz', hs.params_text('use_type' => 'xyz'), 'neznama hodnota triedy = surova (bez vymyslenych slov)')
  NxTest.assert_equal('NL 470 mm · parameter „aaa“ b · parameter „zzz“ 5',
                      hs.params_text('zzz' => 5, 'nominal_length' => 470, 'aaa' => 'b'),
                      'neznamy kluc idiomom param_label, zoradeny podla kluca, na konci')
end

NxTest.test('H3a params_text: params_label sa NEMENI (CSV kovania a Kontrola)') do
  hr = Noxun::Engine::HardwareRules
  NxTest.assert_equal('rez 597 mm', hr.params_label('cut_length_mm' => 597.0))
  NxTest.assert_equal(nil, hr.params_label('nominal_length' => 470.0), 'mimo dlzkoveho priznaku stale nil')
end

# --- 2) where ---------------------------------------------------------------

NxTest.test('H3a where: zlucenie podla (vlastnik, rucne, popis) v poradi prveho vyskytu') do
  core = Noxun::Engine::ProductionCore
  f = NxH3Z
  NxTest.assert_equal([{ 'owner_id' => 'CAB-003', 'quantity' => 2, 'manual' => false, 'manual_note' => nil }],
                      core.hardware_where([f.bd('CAB-003', 1), f.bd('CAB-003', 1)]),
                      'dve pravidlove polozky CAB-003 = jedna ×2')
  out = core.hardware_where([f.bd('CAB-2', 1, 'manual', 'ručne (automat: 470 mm)'), f.bd('CAB-2', 1)])
  NxTest.assert_equal(2, out.length, 'rucna a pravidlova tej istej skrinky sa NEZLEJU')
  NxTest.assert_equal([true, false], out.map { |w| w['manual'] })
  NxTest.assert_equal('ručne (automat: 470 mm)', out[0]['manual_note'])
  diff = core.hardware_where([f.bd('CAB-2', 1, 'manual', 'A'), f.bd('CAB-2', 2, 'manual', 'B'),
                              f.bd('CAB-2', 3, 'manual', 'A')])
  NxTest.assert_equal([['A', 4], ['B', 2]], diff.map { |w| [w['manual_note'], w['quantity']] },
                      'rozne popisy oddelene, rovnaky zluceny')
  order = core.hardware_where([f.bd('CAB-9', 1), f.bd('CAB-1', 2), f.bd('CAB-9', 3)])
  NxTest.assert_equal([['CAB-9', 4], ['CAB-1', 2]], order.map { |w| [w['owner_id'], w['quantity']] },
                      'poradie PRVEHO vyskytu')
  NxTest.assert_equal([], core.hardware_where(nil), 'bez breakdownu prazdne pole')
end

NxTest.test('H3a hardware_labeled: params_text + where pribudli, breakdown ostal (klik-select)') do
  core = Noxun::Engine::ProductionCore
  f = NxH3Z
  g = { 'key' => 'K', 'generic_type' => 'slide', 'quantity' => 2,
        'params' => { 'nominal_length' => 470.0, 'front_height' => 302.0 },
        'breakdown' => [f.bd('CAB-003', 1), f.bd('CAB-003', 1)] }
  before = Marshal.dump(g)
  out = core.hardware_labeled({ hardware: [g] }).first
  NxTest.assert_equal(before, Marshal.dump(g), 'vstup sa nezmutoval')
  NxTest.assert_equal('NL 470 mm · výška čela 302 mm', out['params_text'])
  NxTest.assert_equal([{ 'owner_id' => 'CAB-003', 'quantity' => 2, 'manual' => false, 'manual_note' => nil }],
                      out['where'])
  NxTest.assert_equal(g['breakdown'], out['breakdown'], 'breakdown s owner_pid ostava nedotknuty')
  NxTest.assert_equal(nil, out['params_label'], 'params_label = povodna hodnota (D-90)')
end

# --- 3) hardware_sets_labeled ----------------------------------------------

NxTest.test('H3a hardware_sets_labeled: kategorie, missing bez popisku, neznamy kod = kod, nil = nil') do
  core = Noxun::Engine::ProductionCore
  exp = { 'rows' => [{ 'code' => '1', 'category' => 'ZAVESY' },
                     { 'code' => '2', 'category' => 'SPOJOVACI_MATERIAL' },
                     { 'code' => '3', 'category' => 'XYZ' },
                     { 'code' => 'X', 'missing' => true, 'category' => 'NOHY' },
                     'nezmysel'],
          'unmapped' => [{ 'generic_type' => 'hinge' }, { 'generic_type' => 'mystery' }],
          'summary' => { 'total_eur_vat' => 1.0 }, 'state_status' => 'ok' }
  out = core.hardware_sets_labeled(exp)
  NxTest.assert_equal(['Závesy', 'Spojovací materiál', 'XYZ'], out['rows'][0..2].map { |r| r['category_label'] })
  NxTest.assert_equal(['ZAVESY', 'SPOJOVACI_MATERIAL', 'XYZ'], out['rows'][0..2].map { |r| r['category'] },
                      'kod kategorie ostava (identita, CSV)')
  NxTest.refute(out['rows'][3].key?('category_label'), 'polozka mimo katalogu popisok nedostane')
  NxTest.assert_equal('nezmysel', out['rows'][4], 'nehashovy riadok prejde nedotknuty')
  NxTest.assert_equal(%w[Závesy mystery], out['unmapped'].map { |u| u['label'] }, 'SK typ nemapovanej polozky')
  NxTest.assert_equal(exp['summary'], out['summary'], 'ostatne kluce bez zmeny')
  NxTest.assert_equal(nil, core.hardware_sets_labeled(nil))
  NxTest.assert_equal(nil, core.hardware_sets_labeled('x'))
  NxTest.refute(core.hardware_sets_labeled({ 'state_status' => 'invalid' }).key?('rows'),
                'chybajuce rows sa nedoplnaju (aditivne)')
end

NxKovhGolden::CASES.each do |name, kase|
  NxTest.test("H3a hardware_sets_labeled nad kovh_golden #{name}: vstup nezmutovany, CSV bajtovo rovnake") do
    exp = NxKovhGolden.expand_of(kase)
    csv_before = Noxun::Engine::HardwareSets.purchase_csv(exp, project: 'GOLDEN', generated_at: '2026-09-03 00:00')
    dump = Marshal.dump(exp)
    out = Noxun::Engine::ProductionCore.hardware_sets_labeled(exp)
    NxTest.assert_equal(dump, Marshal.dump(exp), "#{name}: hw_exp sa NEZMUTOVAL (cita ho plan, Rozpocet, Kontrola)")
    csv_after = Noxun::Engine::HardwareSets.purchase_csv(exp, project: 'GOLDEN', generated_at: '2026-09-03 00:00')
    NxTest.assert_equal(csv_before, csv_after, "#{name}: CSV kovania z toho isteho exp bajtovo rovnake")
    NxTest.assert_equal(NxKovhGolden.golden(name)['csv'], csv_after, "#{name}: a rovnake ako golden")
    NxTest.assert_equal(exp['rows'].length, out['rows'].length, "#{name}: pocet riadkov")
  end
end

NxTest.test('H3a: okno cita NEMUTUJUCU kopiu, CSV kovania si nakup pocita nanovo') do
  NxTest.assert(NxH3Z::STUDIO_RB.include?('hardware_sets: ProductionCore.hardware_sets_labeled(hw_exp)'),
                'payload Studia ide cez hardware_sets_labeled')
  NxTest.refute(NxH3Z::STUDIO_RB.include?('category_label'), 'popisky sklada JADRO, nie okno')
  body = NxH3Z::CORE_RB[/def do_hw_csv.*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'telo do_hw_csv sa naslo')
  NxTest.refute(body.include?('hardware_sets_labeled'), 'CSV kovania popisky okna nepouziva')
end

# --- 4) effective v nastaveniach -------------------------------------------

NxTest.test('H3a effective: = SupplierSettings.rate / row_rate pre kazdy kluc a rezim; revizia bez zmeny') do
  NxTest.skip!('zapisuje do sandboxu nastaveni') unless NxTest.headless?
  NxH3Z.with_sandbox do
    ss = Noxun::Engine::SupplierSettings
    path = ss.path
    # Prve zostavenie v prazdnom sandboxe moze zalozit seed subor (to je stare
    # spravanie `active`, nie H3a) — porovnava sa az DRUHE zostavenie.
    Noxun::Engine::SupplierSettingsDialog.settings_payload
    existed = File.exist?(path)
    bytes = existed ? File.binread(path) : nil
    data = Noxun::Engine::SupplierSettingsDialog.settings_payload
    sup = ss.active
    eff = data['effective']
    NxTest.assert(eff.is_a?(Hash), 'payload nesie effective')
    ss::RATE_KEYS.each do |k|
      ss::MODES.each do |m|
        NxTest.assert_equal(ss.rate(sup, k, m), eff['rates'][k][m], "rate #{k}/#{m}")
      end
    end
    ss.standard_rows(sup).each do |row|
      ss::MODES.each do |m|
        NxTest.assert_equal(ss.row_rate(sup, row, m), eff['rows'][row['key']][m], "row #{row['key']}/#{m}")
      end
    end
    NxTest.assert_equal(ss.revision(sup), data['revision'], 'revizia sa citanim nezmenila')
    NxTest.assert_equal(existed, File.exist?(path), 'citanie subor nezalozilo ani nezmazalo')
    NxTest.assert_equal(bytes, File.binread(path), 'subor nastaveni bajtovo rovnaky') if existed
  end
end

NxTest.test('H3a effective: chybajuci zaklad v subore = seed (porez 17), nie prazdna bunka (S20)') do
  ss = Noxun::Engine::SupplierSettings
  sup = { 'rates' => { 'olep' => 0.9 }, 'mode_values' => { 'montaz' => { 'vysoky' => 20.0 } },
          'standard_rows' => [] }
  eff = Noxun::Engine::SupplierSettingsDialog.effective_rates(sup)
  NxTest.assert_equal(17.0, eff['rates']['porez']['standard'], 'porez bez zakladu = seed 17')
  NxTest.assert_equal(ss.rate(sup, 'porez', 'nizky'), eff['rates']['porez']['nizky'])
  NxTest.assert_equal(20.0, eff['rates']['montaz']['vysoky'], 'rezimova hodnota vyhrava')
  NxTest.assert_equal(%w[nizky standard vysoky], eff['rates']['olep'].keys, 'rezimy v poradi MODES')
end
