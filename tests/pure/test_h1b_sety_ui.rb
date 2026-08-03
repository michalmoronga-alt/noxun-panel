# frozen_string_literal: true
# Testy V0.6 H1b: serverova cast UI setov kovania — slovnik parametrov pasiem
# (jedina autorita ponuky editora), KRATKY SK dovod nemapovanej polozky
# (tab Kovanie + CSV citaju TEN ISTY text) a nemapovana sekcia nakupneho CSV
# s dovodom. Okna (payloady, callbacky) potrebuju SketchUp — testuje sa to,
# co je ciste.
require_relative '../helper' unless defined?(NxTest)

module NxH1b
  HWS = Noxun::Engine::HardwareSets

  module_function

  def unmapped(reason, over = {})
    { 'cabinet_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'rule_id' => 'r1', 'quantity' => 1,
      'set_id' => 'moj-set', 'reason' => reason, 'nominal_length' => nil }.merge(over)
  end
end

# --- 1) slovnik parametrov ----------------------------------------------------

NxTest.test('H1b slovnik: PARAM_OPTIONS je jedina autorita ponuky parametrov pasiem') do
  hws = NxH1b::HWS
  keys = hws::PARAM_OPTIONS.map { |o| o['key'] }
  NxTest.assert_equal(%w[height front_height], keys, 'nohy podla sokla + bocnice podla vysky cela')
  hws::PARAM_OPTIONS.each do |o|
    NxTest.assert(!o['label'].to_s.empty? && !o['by'].to_s.empty?, "#{o['key']} ma oba pady")
  end
  NxTest.assert_equal('výška sokla', hws.param_label('height'))
  NxTest.assert_equal('podľa výšky čela', hws.param_by('front_height'))
  # neznamy parameter (starsi/novsi snapshot) sa NIKDY nestrati v texte
  NxTest.assert(hws.param_label('depth').include?('depth'))
  NxTest.assert(hws.param_by('depth').include?('depth'))
end

NxTest.test('H1b formát čísla: 150 / 17,5 — rovnaký v semafore, CSV aj v UI') do
  hws = NxH1b::HWS
  NxTest.assert_equal('150', hws.fmt_mm(150.0))
  NxTest.assert_equal('17,5', hws.fmt_mm(17.5))
  NxTest.assert_equal('0', hws.fmt_mm(0))
  # GH #132 P2: text NIKDY nezaokruhluje — 419,6 nie je 420 a 120,25 nie je
  # 120,3 (inak hlaska posiela doplnit pasmo/kod, ktory uz existuje).
  NxTest.assert_equal('419,6', hws.fmt_mm(419.6))
  NxTest.assert_equal('120,25', hws.fmt_mm(120.25))
  # Validation pouziva TU ISTU funkciu (jeden tvar cisla vsade)
  u = NxH1b.unmapped('param_band_missing', 'param' => 'height', 'value' => 17.5,
                     'member_index' => 0)
  items = []
  Noxun::Engine::Validation.check_hardware_expansion({ 'unmapped' => [u] }, items)
  NxTest.assert(items[0]['message_sk'].include?('17,5 mm'), 'semafor formatuje rovnako')
end

# --- 2) kratky SK dovod (tab Kovanie + CSV) -----------------------------------

NxTest.test('H1b dôvody: každý reason má krátky SK text s parametrom aj členom') do
  hws = NxH1b::HWS
  band = hws.unmapped_reason_sk(NxH1b.unmapped('param_band_missing',
                                               'param' => 'height', 'value' => 150.0,
                                               'member_index' => 0, 'member_label' => 'noha'))
  NxTest.assert(band.include?('výška sokla 150 mm'), 'parameter aj hodnota')
  NxTest.assert(band.include?('mimo pásiem'), 'co sa stalo')
  NxTest.assert(band.include?('(noha)'), 'identita clena — dva clena su dva problemy')

  # bez labelu sa clen pomenuje poradim (index je 0-based)
  idx = hws.unmapped_reason_sk(NxH1b.unmapped('param_band_missing', 'param' => 'height',
                                              'value' => 150.0, 'member_index' => 1))
  NxTest.assert(idx.include?('(člen 2)'))

  # chybajuca hodnota != mimo pasiem
  bez = hws.unmapped_reason_sk(NxH1b.unmapped('param_band_missing', 'param' => 'height',
                                              'value' => nil, 'member_index' => 0))
  NxTest.assert(bez.include?('nie je známa'), 'nezadany parameter ma vlastny text')

  sel = hws.unmapped_reason_sk(NxH1b.unmapped('selector_unresolved',
                                              'param' => 'front_height', 'value' => 300.0))
  NxTest.assert(sel.include?('výška čela 300 mm'))
  NxTest.assert(sel.include?('predvoľby'), 'pasmo chyba PREDVOLBE, nie setu')

  nl = hws.unmapped_reason_sk(NxH1b.unmapped('nl_missing', 'nominal_length' => 450.0))
  NxTest.assert(nl.include?('NL 450'))
  # GH #132 P2: frakcna NL je VEDOME nemapovana (rad ma presne celociselne
  # kluce) — text ju nesmie zaokruhlit na existujuci kluc radu.
  frak = hws.unmapped_reason_sk(NxH1b.unmapped('nl_missing', 'nominal_length' => 419.6))
  NxTest.assert(frak.include?('NL 419,6'), 'frakcna NL sa nezaokruhli na 420')
  items = []
  Noxun::Engine::Validation.check_hardware_expansion(
    { 'unmapped' => [NxH1b.unmapped('nl_missing', 'nominal_length' => 419.6)] }, items
  )
  NxTest.assert(items[0]['message_sk'].include?('NL 419,6'), 'semafor rovnako')
  NxTest.assert(hws.unmapped_reason_sk(NxH1b.unmapped('set_missing')).include?('moj-set'))
  NxTest.assert(hws.unmapped_reason_sk(NxH1b.unmapped('no_set')).include?('nemá priradený set'))
  # neznamy (novsi) dovod nesmie skoncit prazdnym textom
  NxTest.assert(!hws.unmapped_reason_sk(NxH1b.unmapped('nieco_nove')).empty?)
  NxTest.assert_equal('', hws.unmapped_reason_sk(nil), 'nil vstup bezpecny')
end

# --- 3) nakupne CSV: sekcia NEMAPOVANE nesie dovod -----------------------------

NxTest.test('H1b CSV: nemapovaná sekcia má dôvod s parametrom (bez neho sa nedalo opraviť)') do
  hws = NxH1b::HWS
  exp = { 'rows' => [], 'summary' => { 'quantity' => 0, 'total_eur_vat' => 0.0 },
          'unmapped' => [
            NxH1b.unmapped('param_band_missing', 'generic_type' => 'leg',
                           'owner_part_key' => nil, 'param' => 'height',
                           'value' => 150.0, 'member_index' => 0, 'quantity' => 4),
            NxH1b.unmapped('selector_unresolved', 'param' => 'front_height', 'value' => 300.0)
          ] }
  csv = hws.purchase_csv(exp, project: 'H1b', generated_at: '2026-08-04')
  NxTest.assert(csv.include?('"dôvod"'), 'sekcia pomenuva stlpec')
  NxTest.assert(csv.include?('výška sokla 150 mm'), 'pasmo clena aj s hodnotou')
  NxTest.assert(csv.include?('výška čela 300 mm'), 'selector aj s hodnotou')
  leg = csv.lines.find { |l| l.start_with?('"leg"') }
  NxTest.assert(!leg.nil? && leg.include?('"4"'), 'pocet ostava v riadku')
end
