# frozen_string_literal: true
# H12b (blok 9 HARDENING, C-01) — PANEL RUBY Z REGISTRA TYPOV + ADITIVNE KLUCE
# PAYLOADU (package H12 §6 R2.4, R2.5, R2.6; §15 A2).
#
# CO PLATI:
#   * panel (`ui/panel/*`) a `templates_dialog.rb` sa pytaju VLASTNOSTI
#     registra (`carcass?`, `corner?`, `fronts`, `zones`, `appliance_owner`,
#     `template_type`, `type_locked`, `limits`), nie mena typu — guard T3a
#     v `test_h12a_register.rb` skenuje od H12b aj `ui/`;
#   * typovy guard pouzitia sablony porovnava IDENTITU (A2): chybajuci typ =
#     dolna, `''` a neznamy typ ostavaju surove — `''` na dolnej je odmietnute;
#     slovo vo vete je oddelena normalizacia (neznamy/prazdny = „dolná");
#   * aditivne kluce pre JS (H12c ich zacne citat): `cabinet_types` v `NX.init`
#     (= `CabinetTypes.client_payload` = fixtura), `type_word` v zaznamoch
#     korpusovych sablon (obe cesty — vkladacia karta aj Studio), `type_scope`
#     v payloade Pravidiel kovania (veta rozsahu pravidla viazaneho na typ).
#
# Ze sa vysledky NEZMENILI, strazi golden `test_h12b_golden.rb` (panel.json)
# a `test_h12_golden.rb` (matrix.json); in-SU `run_h12b` overi akcie v modeli.
#
# MUTACIE (overene rucne pri davke, PR H12b) — kazda zhodi aspon jeden test:
#   B1 `slot_params?` cez `!on_floor?` (horna by stratila telo) · B2
#   `template_type_id` cez `id_or_default` (A2: '' by preslo na dolnu) · B3
#   `split_refusal` cez `zones != 'tree'` (slot by delenie odmietal) · B4
#   preflight sokla `dims[2] = 0` cez `!on_floor?` (horna) · B5 `init_defaults`
#   v inom poradi · B6 `TEMPLATE_TYPE_WORDS` z `label` · B7 `template_type_word`
#   aj pre dosku · B8 `type_scope_desc` cez `hits.any?` · B9 nove
#   `== 'dishwasher'` v `actions_appliance.rb` · B10 `corner_change_refusal`
#   zamok cez `!carcass?` · B11 `apply_template_type!` `have` cez `id_or_default` ·
#   B12 rozsah sirky preflightu bez `limits` slotu (zachyti az test rozsahov
#   preflightu nizsie) · B13 `template_config_from` komin a listy cez `on_floor?`
#   namiesto `carcass?`. Spolu 13 mutacii.
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  %w[actions_cabinet actions_templates actions_zones actions_appliance payloads sync].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog') unless defined?(Noxun::Engine::RulesDialog)
end

module NxH12b
  module_function

  E = Noxun::Engine
  CT = E::CabinetTypes
  FIXTURE = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h12_cabinet_types.json')
  INPUTS = ['lower', 'upper', 'dishwasher', 'corner_blind', 'tall', nil, ''].freeze

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def cfg(t)
    t.nil? ? {} : { 'type' => t }
  end
end

if NxTest.headless?
  # --- A2 · typovy guard sablon: identita, nie normalizacia ---------------------

  NxTest.test('H12b A2: typovy guard sablony — obojsmerna matica (prazdny, chybajuci, dolna, neznamy)') do
    td = NxH12b::E::TemplatesDialog
    ref = ->(cab, tpl) { td.template_type_refusal(NxH12b.cfg(cab), NxH12b.cfg(tpl)) }
    # Prejde: rovnaka identita; chybajuci typ = dolna (oba smery).
    [%w[lower lower], ['lower', nil], [nil, 'lower'], [nil, nil], ['', ''], %w[tall tall],
     %w[corner_blind corner_blind], %w[dishwasher dishwasher]].each do |cab, tpl|
      NxTest.assert(ref.call(cab, tpl).nil?, "#{cab.inspect} <- #{tpl.inspect} ma prejst")
    end
    # Odmietnute: '' NIE JE dolna (A2), neznamy NIE JE dolna — oba smery.
    [['lower', ''], ['', 'lower'], [nil, ''], ['', nil], %w[lower tall], %w[tall lower],
     ['tall', ''], ['', 'tall'], %w[lower upper], %w[upper lower], %w[lower dishwasher]].each do |cab, tpl|
      NxTest.refute(ref.call(cab, tpl).nil?, "#{cab.inspect} <- #{tpl.inspect} ma byt odmietnute")
    end
    # Slovo vo vete = normalizacia (oddelena funkcia): neznamy a prazdny = „dolná".
    NxTest.assert(ref.call('lower', '').include?('(dolná)'))
    NxTest.assert(ref.call('lower', 'tall').include?('(dolná)'))
    NxTest.assert(ref.call('lower', 'dishwasher').include?('(umývačka)'))
    NxTest.assert_equal('Šablóna je pre iný typ (horná) než označená skrinka — nepoužitá.', ref.call('lower', 'upper'))
  end

  NxTest.test('H12b A2: identita sablony NIE JE id_or_default (prazdny typ ostava prazdny)') do
    td = NxH12b::E::TemplatesDialog
    NxTest.assert_equal('', td.template_type_id('type' => ''))
    NxTest.assert_equal('lower', td.template_type_id({}))
    NxTest.assert_equal('lower', td.template_type_id(nil))
    NxTest.assert_equal('tall', td.template_type_id('type' => 'tall'))
    NxTest.refute(td.template_type_id('type' => '') == NxH12b::CT.id_or_default(''), 'A2: dve rozne funkcie')
    body = NxH12b.src('noxun_engine', 'ui', 'templates_dialog.rb')
    NxTest.assert(body.include?('template_type_refusal(Store.config(cab) || {}, tpl[\'config\'] || {})'),
                  'handle_apply vola cistu funkciu typoveho guardu')
  end

  # --- R2.5 · odvodene konstanty panela ------------------------------------------

  NxTest.test('H12b R2.5: slova a velke nazvy typu su odvodene z registra') do
    pan = NxH12b::E::Panel
    NxTest.assert_equal(NxH12b::CT::IDS, pan::TEMPLATE_TYPE_WORDS.keys)
    NxTest.assert_equal(NxH12b::CT::IDS.map { |id| NxH12b::CT.get(id)[:word] }, pan::TEMPLATE_TYPE_WORDS.values)
    NxTest.assert_equal(%w[lower upper], pan.singleton_class::TEMPLATE_SWITCH_TYPES)
    NxTest.assert_equal({ 'lower' => 'DOLNÁ', 'upper' => 'HORNÁ' }, pan.singleton_class::TEMPLATE_TYPE_LABELS)
  end

  NxTest.test('H12b R2.5: predikaty panela davaju PRESNE dnesne mnoziny nad 7 vstupmi') do
    pan = NxH12b::E::Panel
    set = ->(&blk) { NxH12b::INPUTS.select(&blk) }
    NxTest.assert_equal(['dishwasher'], set.call { |t| pan.send(:slot_params?, NxH12b.cfg(t)) })
    NxTest.assert_equal(['corner_blind'], set.call { |t| !pan.send(:corner_preflight_src, NxH12b.cfg(t), nil).nil? })
    NxTest.assert_equal(['corner_blind'], set.call { |t| !pan.send(:corner_preflight_src, {}, NxH12b.cfg(t)).nil? })
    # Zamok typu z/na rohovu: identita surova, zamok = type_locked aspon jedneho.
    NxH12b::INPUTS.each do |have|
      NxH12b::INPUTS.each do |want|
        got = !pan.corner_change_refusal(NxH12b.cfg(have), { 'type' => want }).nil?
        exp = want.to_s != have.to_s && [want.to_s, have.to_s].include?('corner_blind')
        NxTest.assert_equal(exp, got, "zmena typu #{have.inspect} -> #{want.inspect}")
      end
    end
  end

  NxTest.test('H12b R2.5: preflight ciel — rozsahy z limits typu (slot 300–1200 / 500–1200, inak 200–3000)') do
    pan = NxH12b::E::Panel
    gaps = { 'gap' => 3.0, 'gap_top' => 3.0, 'gap_bottom' => 3.0, 'gap_left' => 3.0, 'gap_right' => 3.0 }
    fronts = gaps.merge('items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }])
    msg = 'Rozmery skrinky sú mimo povoleného rozsahu.'
    pf = lambda do |t, w, h|
      res = pan.send(:front_preflight_result, { 'type' => t, 'width' => w, 'height' => h, 'floor_height' => 100.0,
                                                'dw_front_bottom' => 100.0, 'fronts' => fronts }, nil)
      Array(res['errors']).map { |e| e['message'] }.include?(msg)
    end
    NxTest.assert(pf.call('dishwasher', 1250.0, 820.0), 'slot sirka nad 1200 = mimo rozsahu')
    NxTest.assert(pf.call('dishwasher', 250.0, 820.0), 'slot sirka pod 300 = mimo rozsahu')
    NxTest.assert(pf.call('dishwasher', 600.0, 1300.0), 'slot vyska linky nad 1200 = mimo rozsahu')
    NxTest.refute(pf.call('dishwasher', 600.0, 820.0), 'slot 600 x 820 v rozsahu')
    %w[lower upper corner_blind tall].each do |t|
      NxTest.refute(pf.call(t, 1250.0, 1300.0), "#{t}: korpusovy rozsah 200–3000")
      NxTest.assert(pf.call(t, 3100.0, 720.0), "#{t}: nad 3000 = mimo rozsahu")
    end
  end

  # --- R2.6 · aditivne kluce payloadu -------------------------------------------

  NxTest.test('H12b R2.6: NX.init nesie cabinet_types = client_payload = fixtura; predvolby z DEFAULTS_BY_TYPE') do
    sync = NxH12b.src('noxun_engine', 'ui', 'panel', 'sync.rb')
    NxTest.assert(sync.include?('cabinet_types: CabinetTypes.client_payload,'), 'push_init posiela register')
    NxTest.assert(sync.include?('defaults: init_defaults(model),'), 'predvolby z jednej mapy')
    want = JSON.parse(File.read(NxH12b::FIXTURE, encoding: 'UTF-8'))
    NxTest.assert_equal(want, JSON.parse(JSON.generate(NxH12b::CT.client_payload)))
    pan = NxH12b::E::Panel
    orig = pan.method(:corner_insert_defaults)
    pan.define_singleton_method(:corner_insert_defaults) { |_m| { 'corner' => true } }
    begin
      d = pan.init_defaults(nil)
    ensure
      pan.define_singleton_method(:corner_insert_defaults, orig)
    end
    NxTest.assert_equal(NxH12b::CT::IDS, d.keys, 'poradie klucov = IDS')
    NxTest.assert_equal({ 'corner' => true }, d['corner_blind'], 'rohova cez corner_insert_defaults')
    NxTest.assert(d['upper'].equal?(Noxun::Engine::CabinetBuilder::UPPER_DEFAULTS))
  end

  NxTest.test('H12b R2.6: type_word — korpusova sablona slovo typu (obe cesty), doska bez kluca') do
    pan = NxH12b::E::Panel
    td = NxH12b::E::TemplatesDialog
    { 'lower' => 'dolná', 'upper' => 'horná', 'dishwasher' => 'umývačka', 'corner_blind' => 'rohová',
      'tall' => 'dolná', '' => 'dolná' }.each do |t, w|
      rec = { 'kind' => 'cabinet', 'name' => 'X', 'config' => { 'type' => t } }
      NxTest.assert_equal(w, pan.template_type_word(rec), "slovo pre #{t.inspect}")
      NxTest.assert_equal(w, td.tile_row(rec)['type_word'], "Studio dlazdica #{t.inspect}")
    end
    NxTest.assert_equal('dolná', pan.template_type_word('kind' => 'cabinet', 'config' => {}))
    board = { 'kind' => 'board', 'name' => 'D', 'config' => { 'length' => 700.0 } }
    NxTest.assert(pan.template_type_word(board).nil?)
    NxTest.refute(td.tile_row(board).key?('type_word'), 'doska kluc nedostane')
    list = pan.template_list
    NxTest.assert(list.any?, 'seed kniznica sablon je neprazdna')
    list.each do |r|
      if r['kind'] == 'cabinet'
        NxTest.assert_equal(NxH12b::CT.prop((r['config'] || {})['type'], :word), r['type_word'], "zaznam #{r['name']}")
      else
        NxTest.refute(r.key?('type_word'), "doska #{r['name']} bez slova typu")
      end
    end
  end

  NxTest.test('H12b R2.6: type_scope — veta rozsahu pravidla viazaneho na typ (zrkadlo rules.js rdRoleDesc)') do
    rd = NxH12b::E::RulesDialog
    rule = ->(role, types) { { 'rule_id' => "r-#{types.inspect}", 'applies_to' => { 'role' => role, 'cabinet_type' => types } } }
    NxTest.assert_equal('na hornú skrinku', rd.type_scope_desc(rule.call('cabinet', ['upper'])))
    NxTest.assert_equal('na spodnú skrinku', rd.type_scope_desc(rule.call('cabinet', ['lower'])))
    NxTest.assert_equal('na hornú skrinku', rd.type_scope_desc(rule.call('cabinet', %w[upper dishwasher])))
    NxTest.assert(rd.type_scope_desc(rule.call('cabinet', %w[upper lower])).nil?, 'obe = ziadna veta typu')
    NxTest.assert(rd.type_scope_desc(rule.call('cabinet', ['dishwasher'])).nil?)
    NxTest.assert(rd.type_scope_desc(rule.call('cabinet', [])).nil?)
    NxTest.assert(rd.type_scope_desc(rule.call('front_door', ['upper'])).nil?, 'len rola cabinet')
    NxTest.assert(rd.type_scope_desc('applies_to' => nil).nil?)
    seed = Noxun::Engine::HardwareRules::SEED_RULES
    map = rd.type_scope_map(seed)
    NxTest.assert_equal({ 'zavesenie-hornej-skrinky' => 'na hornú skrinku' }, map, 'seed: len pravidlo zavesov')
    body = NxH12b.src('noxun_engine', 'ui', 'rules_dialog.rb')
    NxTest.assert(body.include?("'type_scope' => type_scope_map(rules)"), 'rules_payload nesie type_scope')
    # „Načítať globálne" (push_global) nesie tu istu mapu nad GLOBALNYMI pravidlami.
    hr = Noxun::Engine::HardwareRules
    lib = seed.map { |r| JSON.parse(JSON.generate(r)) }
    lib << { 'rule_id' => 'len-v-globale', 'applies_to' => { 'role' => 'cabinet', 'cabinet_type' => ['lower'] } }
    sent = []
    saved = { hr => [:load, hr.method(:load)], rd => [:js, rd.method(:js)] }
    st = rd.method(:set_status)
    hr.define_singleton_method(:load) { |*_a| lib }
    rd.define_singleton_method(:js) { |s| sent << s }
    rd.define_singleton_method(:set_status) { |*_a| nil }
    begin
      rd.push_global
    ensure
      saved.each { |obj, (name, m)| obj.define_singleton_method(name, m) }
      rd.define_singleton_method(:set_status, st)
    end
    line = sent.find { |s| s.start_with?('RD.setRules(') }.to_s
    NxTest.assert(line.include?('if (window.RD && RD.setTypeScope) RD.setTypeScope('), 'push_global posiela type_scope (guard DOM)')
    got = JSON.parse(line[/RD\.setTypeScope\((\{.*?\})\);/, 1].to_s)
    NxTest.assert_equal({ 'zavesenie-hornej-skrinky' => 'na hornú skrinku', 'len-v-globale' => 'na spodnú skrinku' }, got,
                        'mapa nad globalnymi pravidlami (aj pravidlo, ktore projekt nema)')
    # H12c (T4): rules.js vety uz neskladá — prevzal ich zo servera (mapa
    # `type_scope`, `RD.setTypeScope`). Doslovnu zhodu s povodnym JS strazi
    # golden `tests/fixtures/h12_golden/js.json` (Studio) a parita fixtury
    # `type_scope.json` s `type_scope_map` (test_h12c_js.rb).
    js = NxH12b.src('noxun_engine', 'ui', 'js', 'rules.js')
    NxTest.refute(js.include?("return 'na hornú skrinku';") || js.include?("return 'na spodnú skrinku';"),
                  'okno vety rozsahu podla typu nesklada (len server)')
    NxTest.assert(js.include?('setTypeScope: function(map){'), 'prijimac „Načítať globálne" existuje')
  end
end
