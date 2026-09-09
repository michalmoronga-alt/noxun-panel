# frozen_string_literal: true
# Testy prekladu detailu nekompatibilneho setu — `HardwareSets.incompatible_detail_sk`
# nad JEDINOU tabulkou `INCOMPATIBLE_DETAIL_SK` (fix v0.9.56).
#
# Pozadie: metoda mala v module DVE definicie (KOV-C2a tabulka + inline hash
# z KOV-D1a). Ruby ticho pouzije druhu, takze tabulka bola mrtvy kod a
# `height_selector` (pevny `set_id` pre zasuvku s vyskovym variantom) sa nikdy
# nepreložil — pouzivatel videl genericke „iná klasifikácia". Kazdy dalsi
# detail (KOV-F1, KOV-E1a) sa musel dopisovat na DVE miesta.
#
# Co fix slubuje (a co tieto testy strazia):
#   R1 JEDNA autorita: metoda vracia presne hodnoty tabulky, tabulka je
#      zmrazena, v zdrojaku je metoda aj tabulka definovana RAZ
#   R2 kazdy detail, ktory core vydava, ma VLASTNU vetu (nie fallback) a vety
#      su navzajom rozne; nesulady zo `set_incompatible_info` (zasuvka) sa
#      prelozia
#   R3 zachovane znenia, ktore sa zobrazovali doteraz (ucinna = druha
#      definicia): `system` = „iný systém zásuviek", fallback = „iná
#      klasifikácia"; `height_selector` pribudol
#   R4 `height_selector` end-to-end: pevny set_id pre Atiru = veta o vyske
#      v Nakupe (`unmapped_reason_sk`), v paneli (`explain`) aj v Kontrole
#      (`Validation.check_hardware_expansion`) — nikde „iná klasifikácia"
#   R5 uplnost: kazdy literalny/konstantny `'detail' => …` v hardware_sets.rb
#      ma vetu a tabulka nema kluc, ktory core nevydava
#
# MUTACIE (kazda overena rucne — po zaneseni chyby spadne uvedeny test):
#   M1 vratenie druhej (inline) definicie bez `height_selector` -> R1 (zdrojovy
#      guard) + R4 + AST guard v test_guards.rb
#   M2 fallback zmeneny na „nesedí klasifikácia setu" -> R3
#   M3 novy `{ 'detail' => 'novy_kluc' }` v core bez vety -> R5
require_relative '../helper' unless defined?(NxTest)

module NxIncompatDetail
  E   = Noxun::Engine
  HWS = E::HardwareSets
  V   = E::Validation
  SRC = File.join(NxTest::ROOT, 'noxun_engine', 'core', 'hardware_sets.rb')

  # Detaily, ktore core REALNE vydava (`set_incompatible_info` + vetvy pre
  # zaves a vyklop, `resolve_set_id`, brana typu v `expand`). Je to DRUHY,
  # nezavisly zapis zoznamu — R5 ho porovnava so zdrojakom aj s tabulkou.
  EMITTED = %w[opening_mode drawer_construction system height_variant height_selector
               use_type generic_type use_type_lift lift_system lift_system_missing].freeze

  module_function

  def seed_set(sid)
    HWS::SEED_SETS.find { |s| s['set_id'] == sid }
  end

  def state_of(sets, mapping)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'mapping' => mapping, 'sets' => by_id }
  end

  # Receptova polozka vysuvu Atira H70 (vzor NxC2a.drawer_item).
  def drawer_item(params = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'recipe:atira_sisy_v1',
      'params' => { 'opening_mode' => 'classic', 'drawer_construction' => 'metal',
                    'system' => 'atira', 'height_variant' => 70.0,
                    'nominal_length' => 470.0 }.merge(params),
      'source' => 'recipe' }
  end

  # Kluce detailu zapisane v zdrojaku ako literal alebo konstanta modulu
  # (`'detail' => 'x'` / `'detail' => KONSTANTA`). Premenna v slucke
  # (`'detail' => k`) sem nepatri — tie kluce kryje R2 behaviorálne.
  # Riadkove komentare sa vynechaju (priklad v komentari nie je emitovany
  # detail); literal s medzerou (`'set nevydal žiadnu položku'`, dovod
  # `members_skipped`) regex zamerne minie — cez preklad neprechadza.
  def source_detail_keys
    src = File.readlines(SRC, encoding: 'UTF-8').reject { |l| l =~ /\A\s*#/ }.join
    src.scan(/'detail'\s*=>\s*(?:'([a-z0-9_]+)'|([A-Z][A-Z0-9_]+))/).map do |lit, const|
      lit || HWS.const_get(const)
    end.uniq
  end
end

NxTest.test('incompatible_detail_sk (R1): JEDNA autorita — metoda cita tabulku, v zdrojaku je RAZ') do
  c = NxIncompatDetail
  tbl = c::HWS::INCOMPATIBLE_DETAIL_SK
  NxTest.assert(tbl.is_a?(Hash) && tbl.frozen?, 'tabulka je zmrazeny Hash')
  tbl.each do |k, v|
    NxTest.assert_equal(v, c::HWS.incompatible_detail_sk(k), "kluc #{k}")
    NxTest.assert_equal(v, c::HWS.incompatible_detail_sk(k.to_sym), "kluc #{k} ako symbol (to_s)")
  end
  src = File.read(c::SRC, encoding: 'UTF-8')
  NxTest.assert_equal(1, src.scan(/^\s*def incompatible_detail_sk\b/).length,
                      'incompatible_detail_sk musi byt definovana PRESNE RAZ — druhu by Ruby ticho uprednostnilo')
  NxTest.assert_equal(1, src.scan(/^\s*INCOMPATIBLE_DETAIL_SK\s*=/).length, 'tabulka je jedna')
end

NxTest.test('incompatible_detail_sk (R2): kazdy vydavany detail ma vlastnu vetu, ziadne dve rovnake') do
  c = NxIncompatDetail
  fb = c::HWS::INCOMPATIBLE_DETAIL_FALLBACK_SK
  texts = c::EMITTED.map do |d|
    t = c::HWS.incompatible_detail_sk(d)
    NxTest.refute(t == fb, "#{d}: nesmie padnut na fallback „#{fb}“")
    NxTest.assert(t.is_a?(String) && t.length > 5, "#{d}: veta existuje")
    t
  end
  NxTest.assert_equal(texts.length, texts.uniq.length, "vety sa nesmu zhodovat: #{texts.inspect}")
end

NxTest.test('incompatible_detail_sk (R2): kazdy nesulad zo set_incompatible_info (zasuvka) sa prelozi') do
  c = NxIncompatDetail
  set = c.state_of([c.seed_set('atira-biela-h70-sisy')], {})['sets']['atira-biela-h70-sisy']
  NxTest.assert(set, 'seed set Atira H70 SiSy existuje')
  cases = {
    'opening_mode' => c.drawer_item('opening_mode' => 'tipon'),
    'drawer_construction' => c.drawer_item('drawer_construction' => 'wood'),
    'system' => c.drawer_item('system' => 'quadro_v6'),
    'height_variant' => c.drawer_item('height_variant' => 176.0)
  }
  cases.each do |detail, item|
    info = c::HWS.send(:set_incompatible_info, item, set)
    NxTest.assert_equal(detail, info && info['detail'], "#{detail}: #{info.inspect}")
    NxTest.refute(c::HWS.incompatible_detail_sk(info['detail']) == c::HWS::INCOMPATIBLE_DETAIL_FALLBACK_SK,
                  "#{detail}: preklad chyba")
  end
  NxTest.assert_equal(nil, c::HWS.send(:set_incompatible_info, c.drawer_item, set),
                      'zhodna klasifikacia sedi')
end

NxTest.test('incompatible_detail_sk (R3): doterajsie znenia zostavaju, height_selector pribudol') do
  c = NxIncompatDetail
  NxTest.assert_equal('iný systém zásuviek', c::HWS.incompatible_detail_sk('system'),
                      'znenie z doteraz ucinnej definicie (nie „iný systém výsuvu")')
  NxTest.assert_equal('iná klasifikácia', c::HWS::INCOMPATIBLE_DETAIL_FALLBACK_SK)
  ['nieco-nezname', nil, '', :nieco].each do |d|
    NxTest.assert_equal('iná klasifikácia', c::HWS.incompatible_detail_sk(d), "fallback pre #{d.inspect}")
  end
  NxTest.assert_equal('výber setu nie je podľa výšky zásuvky', c::HWS.incompatible_detail_sk('height_selector'))
  NxTest.assert_equal('set nie je na dvierka', c::HWS.incompatible_detail_sk('use_type'))
  NxTest.assert_equal('set nie je na výklopy', c::HWS.incompatible_detail_sk('use_type_lift'))
  NxTest.assert_equal('set je iného typu kovania', c::HWS.incompatible_detail_sk('generic_type'))
end

NxTest.test('incompatible_detail_sk (R4): pevny set_id pre Atiru = veta o vyske v Nakupe, paneli aj Kontrole') do
  c = NxIncompatDetail
  # Projektove mapovanie s PEVNYM set_id namiesto vyskoveho selektora — presne
  # scenar, v ktorom `resolve_set_id` vracia detail `height_selector`.
  state = c.state_of([c.seed_set('atira-biela-h70-sisy')],
                     { 'class:slide|classic|metal' => 'atira-biela-h70-sisy' })
  item = c.drawer_item
  exp = c::HWS.expand([item], state)
  NxTest.assert_equal([], exp['rows'], 'ziadny riadok — pevny set sa neobjedna')
  u = exp['unmapped'].first
  NxTest.assert(u, 'polozka je nemapovana s dovodom')
  NxTest.assert_equal(['drawer_kit_missing', 'set_incompatible', 'height_selector'],
                      [u['reason'], u['base_reason'], u['detail']], u.inspect)
  nakup = c::HWS.unmapped_reason_sk(u)
  NxTest.assert(nakup.include?('podľa výšky zásuvky'), "Nakup: #{nakup}")
  NxTest.refute(nakup.include?('iná klasifikácia'), "Nakup nesmie byt genericky: #{nakup}")
  ex = c::HWS.explain(item, state)
  NxTest.assert(ex['problems'].any? { |p| p.to_s.include?('podľa výšky zásuvky') }, ex.inspect)
  items = []
  c::V.check_hardware_expansion(exp, items)
  red = items.select { |i| i['severity'] == c::V::RED }
  NxTest.assert_equal(1, red.length, items.inspect)
  msg = red.first['message_sk'].to_s
  NxTest.assert(msg.include?('podľa výšky zásuvky'), "Kontrola: #{msg}")
  NxTest.refute(msg.include?('iná klasifikácia'), "Kontrola nesmie byt genericka: #{msg}")
end

NxTest.test('incompatible_detail_sk (R5): uplnost — kazdy detail zo zdrojaku ma vetu a tabulka nema kluc navyse') do
  c = NxIncompatDetail
  tbl = c::HWS::INCOMPATIBLE_DETAIL_SK
  keys = c.source_detail_keys
  NxTest.assert(keys.length >= 5, "regex nasiel prilis malo klucov: #{keys.inspect}")
  missing = keys.reject { |k| tbl.key?(k) }
  NxTest.assert_equal([], missing, "detail bez vety (dopln INCOMPATIBLE_DETAIL_SK): #{missing.inspect}")
  # `opening_mode` a `drawer_construction` vydava aj slucka nad premennou `k`
  # (regex ju nevidi) — kryje ich R2 behaviorálne.
  known = (keys + %w[opening_mode drawer_construction]).uniq
  extra = tbl.keys - known
  NxTest.assert_equal([], extra, "veta pre kluc, ktory core nevydava: #{extra.inspect}")
  NxTest.assert_equal(c::EMITTED.sort, tbl.keys.sort, 'nezavisly zapis zoznamu detailov sedi s tabulkou')
end
