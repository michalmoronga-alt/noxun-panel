# frozen_string_literal: true
# KOV-E1a (9.9.2026) — VYKLOPY: DATA (katalog, sety, nove tvary clena, triedny
# kluc so systemom, owner `/flap`, brana uplnosti).
#
# Davka NEPRIDAVA pravidlo (to je E1b) — pridava DATA a KONTRAKT, ktory na ne
# pravidlo nasadne: 23 katalogovych riadkov AVENTOS, 6 seed setov, dva nove
# tvary clena setu (`code_by_param` = kod podla triedy, `quantity_from` = pocet
# z parametra polozky), klasifikacne pole `lift_system` a RED branu uplnosti
# `lift_set_incomplete`.
#
# CO SA OVERUJE:
#   1) KATALOG — 23 novych kodov (kategoria VYKLOPY, Blum, datum 9.9.2026),
#      identita 347827 / 13781 / 250831 sa NEMENI, migracia v3 -> v4 LEN doplna
#      a pouzivatelsku polozku NEPREPISE
#   2) SETY — 6 seed setov je platnych, KAZDY kod ma katalogovy riadok,
#      mechanizmus je PRVY clen, tmave sety maju tmave krytky/Tip-On
#   3) `code_by_param` — PRESNA zhoda kluca; chybajuca/neznama trieda =
#      NEVYRIESENY clen -> RED `lift_set_incomplete` s `blocks_export`
#      (a krytky sa NEVYDAJU ako „hotovy nakup")
#   4) `quantity_from` — 0 = ziadny riadok, 1 a 2 nasobia; chybajuca a necela
#      hodnota = nevyrieseny clen; `per: 'owner'` sa dvoma pravidlami NEZDVOJI
#   5) `lift_system` — POVINNY pri `use_type: 'lift'`, ZAKAZANY inde,
#      round-trip cez normalizaciu
#   6) TRIEDNY KLUC — treti segment znamena INE pri `slide` a pri `lift`;
#      `class:lift|tipon|hl_top` sa ODMIETA (HL top Tip-On neexistuje)
#   7) OWNER `/flap` — parse -> zapisova validacia -> resolver -> pruning
#      v JEDNOM kontrakte; `/panel` pri vyklope a `/flap` pri zasuvke sa odmieta
#   8) `MAPPING_ADDITIONS` — doplni 3 vyklopove kluce a NIKDY neprepise
#      existujucu volbu
#   9) STD a DOWNGRADE — obsah s novymi tvarmi dostane `STD_LIFT_FORMS`;
#      STARSI citac (simulovany `MEMBER_KEYS` bez novych klucov) taky set
#      ODMIETNE ako nekompatibilny — NIKDY ticha normalizacia na „tyc 1 ks"
#  10) CONFIG_SCHEMA 10 (owner mapovanie `…@front:<id>/flap` je perzistentna
#      hodnota, ktoru schema 9 nepozna)
#  11) GOLDEN — nakup EXISTUJUCICH zakaziek (zavesy, vysuvy, nohy nad seed
#      kniznicou) je CONTENT-identicky; ziadny vyklopovy kod v nom nepribudol
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1  `code_by_param` vezme „najblizsi" kod        -> presna zhoda kluca
#   M2  chybajuci kod triedy = ORANGE                -> RED + `blocks_export`
#   M3  clen s poctom 0 vyda riadok s mnozstvom 0    -> HL bez predlzenia
#   M4  chybajuca hodnota `quantity_from` = pocet 1  -> nevyrieseny clen
#   M5  `lift_system` je volitelny                   -> povinny pri vyklope
#   M6  `lift_system` sa da dat aj zasuvke           -> zakazany inde
#   M7  treti segment sa cita ako konstrukcia        -> `slide` vs. `lift`
#   M8  `class:lift|tipon|hl_top` sa ulozi           -> validacia ho odmietne
#   M9  owner `/flap` sa pri citani zahodi           -> round-trip + resolver
#   M10 mrtvy owner (zmazane celo) ostane v configu  -> pruning
#   M11 `MAPPING_ADDITIONS` prepise volbu uzivatela  -> add-if-absent
#   M12 nove tvary nezdvihnu `std`                   -> `STD_LIFT_FORMS`
#   M13 stary citac set ticho znormalizuje           -> odmietnutie
#   M14 seed prepise pouzivatelsku katalogovu polozku -> patch v3 -> v4
#   M15 `CONFIG_SCHEMA` ostane na 9                   -> owner `/flap` v configu
#   M16 seed vyklopov zmeni nakup starej zakazky      -> golden
require_relative '../helper' unless defined?(NxTest)

require 'json'
require 'fileutils'

module NxKovE1a
  E   = Noxun::Engine
  HWS = E::HardwareSets
  HWC = E::HardwareCatalog
  BP  = E::BuildPlan
  CB  = E::CabinetBuilder
  V   = E::Validation

  # 23 kodov, ktore davka pridava (zdroj: SEED_AVENTOS_v2_2026-09-09.md).
  NOVE_KODY = HWC::SEED_AVENTOS_V4
  # Kody, ktore v katalogu UZ BOLI a davka sa ich NESMIE dotknut.
  STARE_KODY = %w[347827 13781 250831].freeze

  SETY = %w[vyklop-hk-klasik vyklop-hk-klasik-tmavy
            vyklop-hk-tipon vyklop-hk-tipon-tmavy
            vyklop-hl-klasik vyklop-hl-klasik-tmavy].freeze

  module_function

  def seed_sets
    HWS.normalize_sets(HWS::SEED_SETS)
  end

  def set_def(sid)
    seed_sets.find { |s| s['set_id'] == sid }
  end

  # Projektovy stav s vybranymi setmi.
  def state(mapping, sids)
    defs = {}
    Array(sids).each { |sid| defs[sid] = set_def(sid) }
    { 'mapping' => mapping, 'sets' => defs }
  end

  # Polozka vyklopu tak, ako ju BUDE emitovat pravidlo `vyklopy-aventos` (E1b).
  # Tu ju sada sklada RUCNE — davka pravidlo este nema, ale kontrakt uz ano.
  def item(over = {})
    params = { 'use_type' => 'lift', 'opening_mode' => 'classic',
               'lift_system' => 'hk_top', 'lift_class' => '22K2300' }
    params.merge!(over.delete('params') || {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/flap',
      'generic_type' => 'lift', 'quantity' => 1, 'rule_id' => 'vyklopy-aventos',
      'source' => 'rule', 'params' => params }.merge(over)
  end

  def hl_item(over = {})
    p = { 'use_type' => 'lift', 'opening_mode' => 'classic', 'lift_system' => 'hl_top',
          'lift_class' => '22L2200', 'arm_class' => '22L3200',
          'rod_count' => 1, 'rod_extension' => 0 }
    p.merge!(over.delete('params') || {})
    item(over.merge('params' => p))
  end

  def codes(exp)
    exp['rows'].map { |r| [r['code'], r['quantity']] }.sort
  end

  def reasons(exp)
    exp['unmapped'].map { |u| u['reason'] }
  end

  # Vsetky kody, ktore pouzivaju SEED sety vyklopov.
  def lift_codes
    out = []
    HWS::SEED_SETS.select { |s| s['generic_type'] == 'lift' }.each do |s|
      Array(s['members']).each do |m|
        out << m['code'] if m['code']
        ((m['code_by_param'] || {})['codes'] || {}).each_value { |c| out << c }
      end
    end
    out.uniq
  end
end

# ============================================================================
# 1 — KATALOG
# ============================================================================

NxTest.test('KOV-E1a (1): katalog ma 23 novych kodov AVENTOS s cenou, MJ, URL a datumom') do
  c = NxKovE1a
  NxTest.assert_equal(23, c::NOVE_KODY.length, 'seed v2 pridava presne 23 kodov')
  by_code = {}
  c::HWC::SEED_ITEMS.each { |i| by_code[i['item_code']] = i }
  c::NOVE_KODY.each do |code|
    i = by_code[code]
    NxTest.assert(i, "kod #{code} chyba v seede")
    NxTest.assert_equal('VYKLOPY', i['category'], "#{code}: kategoria")
    NxTest.assert_equal('Blum', i['manufacturer'], "#{code}: vyrobca")
    NxTest.assert(%w[AVENTOS TIP-ON].include?(i['series']), "#{code}: rada")
    NxTest.assert(i['price_eur_vat'].is_a?(Float) && i['price_eur_vat'].positive?,
                  "#{code}: cena s DPH")
    NxTest.assert(c::HWC::UNITS.include?(i['unit']), "#{code}: MJ z enumu")
    NxTest.assert(i['demos_url'].to_s.start_with?('https://www.demos-trade.sk/'),
                  "#{code}: Demos URL")
    NxTest.assert_equal(c::HWC::SEED_PRICE_CHECKED_AT_V4, i['price_checked_at'],
                        "#{code}: datum overenia 9.9.2026")
  end
  # Poznamky nesu rozsah tam, kde ho seed ma (LF pri HK, KH + kg pri ramenach).
  NxTest.assert(by_code['347810']['notes'].include?('LF 420'), 'HK trieda nesie LF rozsah')
  NxTest.assert(by_code['507355']['notes'].include?('1,5–9 kg'), 'ramena nesu kg vratane uchytky')
  NxTest.assert(by_code['497007']['notes'].include?('čierna CS'), 'cierny Tip-On je MJ sada')
  NxTest.assert_equal('set', by_code['497007']['unit'], 'cierny Tip-On ma MJ sada (Demos)')
  NxTest.assert_equal('ks', by_code['250833']['unit'], 'seda Tip-On ma MJ ks (Demos)')
end

NxTest.test('KOV-E1a (1): 347827 · 13781 · 250831 ostavaju NEDOTKNUTE') do
  c = NxKovE1a
  by_code = {}
  c::HWC::SEED_ITEMS.each { |i| by_code[i['item_code']] = i }
  # Kody su v seede LEN RAZ (davka ich neduplikovala).
  c::STARE_KODY.each do |code|
    n = c::HWC::SEED_ROWS.count { |r| r[0] == code }
    NxTest.assert_equal(1, n, "#{code} je v manifeste prave raz")
    NxTest.refute(c::NOVE_KODY.include?(code), "#{code} NIE JE medzi novymi kodmi")
  end
  NxTest.assert_equal('ZAVESY', by_code['250831']['category'],
                      '250831 ostava v ZAVESOCH — davka kategoriu nemeni')
  NxTest.assert_equal(4.40, by_code['13781']['price_eur_vat'], 'cena prichytu sa nemeni')
  NxTest.assert_equal(c::HWC::SEED_PRICE_CHECKED_AT, by_code['13781']['price_checked_at'],
                      'a ani jeho datum overenia (7.9.)')
end

NxTest.test('KOV-E1a (1): migracia v3 -> v4 LEN doplna — pouzivatelsku polozku NEPREPISE') do
  c = NxKovE1a
  # Katalog „pred davkou": jeden AVENTOS kod uz zalozeny POUZIVATELOM (iny
  # nazov aj cena) a jeden chybajuci.
  moje = { 'item_code' => '347810', 'name_sk' => 'Moj vyklop', 'category' => 'OSTATNE',
           'unit' => 'ks', 'supplier' => 'Demos', 'price_eur_vat' => 1.23 }
  rec, = c::HWC.normalize_item(moje)
  items = [rec]
  c::HWC.apply_seed_patch_v4(items, c::HWC.seed_items_resolved(c::HWC::SEED_ITEMS))
  by_code = {}
  items.each { |i| by_code[i['item_code']] = i }
  NxTest.assert_equal('Moj vyklop', by_code['347810']['name_sk'],
                      'pouzivatelska polozka sa NEPREPISUJE')
  NxTest.assert_equal(1.23, by_code['347810']['price_eur_vat'], 'ani jej cena')
  NxTest.assert_equal(22, items.length - 1, 'zvysnych 22 kodov sa doplnilo')
  NxTest.assert(by_code.key?('507366'), 'predlzovaci diel tyce pribudol')
  NxTest.assert_equal(4, c::HWC::SEED_SET_VERSION, 'verzia sady bumpnuta na 4')
end

# ============================================================================
# 2 — SEED SETY
# ============================================================================

NxTest.test('KOV-E1a (2): 6 setov vyklopov je platnych a UPLNYCH') do
  c = NxKovE1a
  _norm, errs = c::HWS.validate_sets(c::HWS::SEED_SETS)
  NxTest.assert_equal([], errs, errs.inspect)
  have = c::HWS::SEED_SETS.map { |s| s['set_id'] }
  c::SETY.each { |sid| NxTest.assert(have.include?(sid), "seed set #{sid} chyba") }
  # KAZDY kod setu ma katalogovy riadok — inak by bol v Nakupe „bez ceny".
  by_code = {}
  c::HWC::SEED_ITEMS.each { |i| by_code[i['item_code']] = i }
  c.lift_codes.each { |code| NxTest.assert(by_code.key?(code), "kod #{code} nie je v katalogu") }
end

NxTest.test('KOV-E1a (2): mechanizmus je PRVY clen a tmavy set ma tmave diely') do
  c = NxKovE1a
  c::SETY.each do |sid|
    first = c.set_def(sid)['members'].first
    NxTest.assert(first['code_by_param'].is_a?(Hash),
                  "#{sid}: prvy clen je mechanizmus (kod podla triedy)")
    NxTest.assert_equal('lift_class', first['code_by_param']['param'], "#{sid}: podla triedy")
  end
  hk = c.set_def('vyklop-hk-klasik')['members'].map { |m| m['code'] }.compact
  hk_t = c.set_def('vyklop-hk-klasik-tmavy')['members'].map { |m| m['code'] }.compact
  NxTest.assert(hk.include?('347834') && !hk.include?('347835'), 'biely set ma biele krytky')
  NxTest.assert(hk_t.include?('347835') && !hk_t.include?('347834'), 'tmavy set ma tmave krytky')
  tip = c.set_def('vyklop-hk-tipon')['members'].map { |m| m['code'] }.compact
  tip_t = c.set_def('vyklop-hk-tipon-tmavy')['members'].map { |m| m['code'] }.compact
  NxTest.assert(tip.include?('250831'), 'Tip-On biela')
  NxTest.assert(tip_t.include?('497007'), 'Tip-On cierna v tmavom sete')
  hl = c.set_def('vyklop-hl-klasik')['members']
  NxTest.assert_equal('arm_class', hl[1]['code_by_param']['param'], 'ramena su druhy clen')
  tyc = hl.find { |m| m['code'] == '507365' }
  NxTest.assert_equal('rod_count', tyc['quantity_from'], 'tyc berie pocet z pravidla')
  NxTest.assert_equal('owner', tyc['per'], 'tyc je na CELO, nie na kus')
end

# ============================================================================
# 3 — `code_by_param` a BRANA UPLNOSTI
# ============================================================================

NxTest.test('KOV-E1a (3): kod podla triedy — PRESNA zhoda, nikdy sused') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hk_top' => 'vyklop-hk-klasik' }, ['vyklop-hk-klasik'])
  exp = c::HWS.expand([c.item], st)
  NxTest.assert_equal([['13781', 1], ['347810', 1], ['347834', 1]], c.codes(exp),
                      'trieda 22K2300 -> mechanizmus 347810 + prichyt + krytky')
  NxTest.assert_equal([], exp['unmapped'], exp['unmapped'].inspect)
  silny = c::HWS.expand([c.item('params' => { 'lift_class' => '22K2700' })], st)
  NxTest.assert_equal([['13781', 1], ['347812', 1], ['347834', 1]], c.codes(silny))
end

NxTest.test('KOV-E1a (3): NEZNAMA trieda = RED `lift_set_incomplete` so `blocks_export`') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hk_top' => 'vyklop-hk-klasik' }, ['vyklop-hk-klasik'])
  exp = c::HWS.expand([c.item('params' => { 'lift_class' => '22K9999' })], st)
  # Riadky ostatnych clenov v ZOZNAME ostavaju (vzor `drawer_kit_missing`) —
  # von sa ale NEDOSTANU: `blocks_export` zastavi nakup, rozpocet aj ponuku,
  # takze „krytky bez mechanizmu" NIKDY neopustia plugin.
  NxTest.assert_equal([['13781', 1], ['347834', 1]], c.codes(exp))
  u = exp['unmapped'].first
  NxTest.assert_equal(c::HWS::LIFT_SET_INCOMPLETE, u['reason'])
  NxTest.assert_equal('class_unmapped', u['base_reason'], 'povodny dovod cestuje dalej')
  NxTest.assert_equal(true, u['blocks_export'], 'RED zastavuje export')
  NxTest.assert_equal('lift_class', u['param'])
  NxTest.assert_equal('22K9999', u['value'])
end

NxTest.test('KOV-E1a (3): CHYBAJUCA trieda aj chybajuci set su ta ista RED brana') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hk_top' => 'vyklop-hk-klasik' }, ['vyklop-hk-klasik'])
  bez_triedy = c::HWS.expand([c.item('params' => { 'lift_class' => nil })], st)
  NxTest.assert_equal([c::HWS::LIFT_SET_INCOMPLETE], c.reasons(bez_triedy))
  NxTest.assert_equal(true, bez_triedy['unmapped'].first['blocks_export'],
                      'bez triedy sa nakup nevyda')
  # ZIADNE mapovanie -> `class_unmapped` sa povysi rovnako.
  bez_setu = c::HWS.expand([c.item], { 'mapping' => {}, 'sets' => {} })
  NxTest.assert_equal([c::HWS::LIFT_SET_INCOMPLETE], c.reasons(bez_setu))
  NxTest.assert_equal(true, bez_setu['unmapped'].first['blocks_export'])
end

NxTest.test('KOV-E1a (3): kod je v REGISTRI bran — zastavi nakup, VEPO nie') do
  c = NxKovE1a
  NxTest.assert(c::BP.hw_blockers.include?(c::HWS::LIFT_SET_INCOMPLETE),
                'register brán pozna vyklopovy kod')
  NxTest.assert(c::BP::HW_BLOCKER_LABELS[c::HWS::LIFT_SET_INCOMPLETE], 'kod ma vetu brany')
  NxTest.skip!('brana exportov zije v UI vrstve') unless defined?(Noxun::Engine::ProductionCore)
  pc = Noxun::Engine::ProductionCore
  exp = { 'unmapped' => [{ 'reason' => c::HWS::LIFT_SET_INCOMPLETE, 'cabinet_id' => 'CAB-9' }] }
  all = pc.hardware_blockers({ hardware_issues: [], hardware: [] }, exp)
  NxTest.assert_equal(1, all.length, all.inspect)
  NxTest.assert(all.first.include?('CAB-9'), all.first)
  NxTest.assert_equal([], pc.hardware_blockers({ hardware_issues: [] }, exp, scope: :kit),
                      'VEPO sa nezastavuje — geometria cela je spravna')
end

NxTest.test('KOV-E1a (3): Kontrola vysvetli neuplnu zostavu RED vetou') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hk_top' => 'vyklop-hk-klasik' }, ['vyklop-hk-klasik'])
  exp = c::HWS.expand([c.item('params' => { 'lift_class' => '22K9999' })], st)
  items = []
  c::V.check_hardware_expansion(exp, items)
  red = items.select { |i| i['severity'] == c::V::RED }
  NxTest.assert_equal(1, red.length, items.inspect)
  NxTest.assert_equal(c::V::CAT_HW_INCOMPLETE, red.first['category'])
  NxTest.assert_equal('front:F1/flap', red.first['part_key'], 'veta ukazuje na CELO')
  NxTest.assert(red.first['message_sk'].include?('Výklop'), red.first['message_sk'])
  NxTest.assert(red.first['message_sk'].include?('HK top'), 'veta menuje system')
  NxTest.assert(red.first['message_sk'].include?('mechanizmus'), 'aj clena, ktory chyba')
end

# ============================================================================
# 4 — `quantity_from`
# ============================================================================

NxTest.test('KOV-E1a (4): pocet z parametra — 0 NEVYDA riadok, 1 a 2 nasobia') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hl_top' => 'vyklop-hl-klasik' }, ['vyklop-hl-klasik'])
  uzka = c::HWS.expand([c.hl_item], st)
  NxTest.assert_equal([['13781', 1], ['507343', 1], ['507351', 1], ['507355', 1],
                       ['507365', 1]].sort, c.codes(uzka))
  NxTest.refute(c.codes(uzka).any? { |code, _| code == '507366' },
                'HL pod 1100 mm nema riadok predlzovacieho dielu VOBEC (ani s poctom 0)')
  siroka = c::HWS.expand([c.hl_item('params' => { 'rod_count' => 2, 'rod_extension' => 1 })], st)
  NxTest.assert_equal(2, siroka['rows'].find { |r| r['code'] == '507365' }['quantity'],
                      'KB >= 1100 -> 2 tyce')
  NxTest.assert_equal(1, siroka['rows'].find { |r| r['code'] == '507366' }['quantity'],
                      '+ predlzovaci diel')
  NxTest.assert_equal([], siroka['unmapped'])
end

NxTest.test('KOV-E1a (4): chybajuci alebo necely pocet = NEVYRIESENY clen (RED)') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hl_top' => 'vyklop-hl-klasik' }, ['vyklop-hl-klasik'])
  [{ 'rod_count' => nil }, { 'rod_count' => 1.5 }, { 'rod_count' => -1 },
   { 'rod_count' => 'dve' }].each do |bad|
    exp = c::HWS.expand([c.hl_item('params' => bad)], st)
    u = exp['unmapped'].find { |x| x['base_reason'] == c::HWS::QUANTITY_UNRESOLVED }
    NxTest.assert(u, "#{bad.inspect}: pocet sa NEDA urcit -> nevyrieseny clen")
    NxTest.assert_equal(c::HWS::LIFT_SET_INCOMPLETE, u['reason'], 'a pri vyklope je to RED')
    NxTest.assert_equal(true, u['blocks_export'])
    NxTest.assert_equal('rod_count', u['param'])
  end
end

NxTest.test('KOV-E1a (4): `per: owner` clen sa DVOMA pravidlami na jednom cele NEZDVOJI') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hl_top' => 'vyklop-hl-klasik' }, ['vyklop-hl-klasik'])
  dve = c::HWS.expand([c.hl_item, c.hl_item('rule_id' => 'moje-vyklopy')], st)
  NxTest.assert_equal(1, dve['rows'].find { |r| r['code'] == '507365' }['quantity'],
                      'tyc je na CELO — druhe pravidlo ju nezdvoji')
  NxTest.assert_equal(2, dve['rows'].find { |r| r['code'] == '507351' }['quantity'],
                      'mechanizmus (per unit) sa scitava normalne')
  ine_celo = c::HWS.expand([c.hl_item,
                            c.hl_item('owner_part_key' => 'front:F2/flap')], st)
  NxTest.assert_equal(2, ine_celo['rows'].find { |r| r['code'] == '507365' }['quantity'],
                      'INE celo = vlastna tyc')
end

# ============================================================================
# 5 — `lift_system`
# ============================================================================

NxTest.test('KOV-E1a (5): `lift_system` je POVINNY pri vyklope a ZAKAZANY inde') do
  c = NxKovE1a
  base = { 'set_id' => 'x', 'name' => 'X', 'use_type' => 'lift', 'opening_mode' => 'classic',
           'manufacturer' => 'Blum', 'members' => [{ 'code' => '13781' }] }
  _n, errs = c::HWS.validate_set(base)
  NxTest.assert(errs.first.to_s.include?('systém'), errs.inspect)
  norm, ok = c::HWS.validate_set(base.merge('lift_system' => 'hk_top'))
  NxTest.assert_equal([], ok)
  NxTest.assert_equal('hk_top', norm['lift_system'])
  NxTest.assert_equal('lift', norm['generic_type'], 'typ kovania je ODVODENY')
  _n2, errs2 = c::HWS.validate_set(base.merge('lift_system' => 'hx_top'))
  NxTest.assert(errs2.first.to_s.include?('neznámy systém'), errs2.inspect)
  zasuvka = { 'set_id' => 'z', 'name' => 'Z', 'use_type' => 'drawer', 'opening_mode' => 'classic',
              'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
              'lift_system' => 'hk_top', 'members' => [{ 'code' => '13781' }] }
  _n3, errs3 = c::HWS.validate_set(zasuvka)
  NxTest.assert(errs3.first.to_s.include?('len set na výklopy'), errs3.inspect)
end

NxTest.test('KOV-E1a (5): `lift_system` prezije citaciu normalizaciu (round-trip)') do
  c = NxKovE1a
  s = c.set_def('vyklop-hl-klasik')
  NxTest.assert_equal('hl_top', s['lift_system'], 'pole sa NEOREZALO')
  NxTest.assert(c::HWS::SET_KEYS.include?('lift_system'), 'whitelist ho pozna')
  NxTest.assert(c::HWS::SET_KEY_ORDER.include?('lift_system'), 'poradie klucov ho pozna')
  # Strata pola = STRATA klasifikacie (4. vrstva detektora).
  bez = JSON.parse(JSON.generate(s))
  NxTest.assert(c::HWS.classification_lost?([s], [bez.reject { |k, _| k == 'lift_system' }]),
                'zahodeny system = priznana strata')
end

# ============================================================================
# 6 — TRIEDNY KLUC
# ============================================================================

NxTest.test('KOV-E1a (6): treti segment znamena INE pri `slide` a pri `lift`') do
  c = NxKovE1a
  h = c::HWS
  NxTest.assert_equal('class:slide|tipon|metal', h.parse_class_key('class:slide|tipon|metal')[0])
  NxTest.assert_equal('class:lift|classic|hk_top', h.parse_class_key('class:lift|classic|hk_top')[0])
  NxTest.assert_equal('class:lift|tipon|hk_top', h.parse_class_key('class:lift|tipon|hk_top')[0])
  NxTest.assert_equal('class:lift|classic|hl_top', h.parse_class_key('class:lift|classic|hl_top')[0])
  # Konstrukcia zasuvky pri vyklope NIE JE system.
  NxTest.assert_equal(nil, h.parse_class_key('class:lift|classic|metal')[0],
                      '`metal` nie je system vyklopu')
  NxTest.assert_equal(nil, h.parse_class_key('class:slide|classic|hk_top')[0],
                      'a `hk_top` nie je konstrukcia zasuvky')
  NxTest.assert_equal(nil, h.parse_class_key('class:lift|classic')[0], 'vyklop bez systemu')
end

NxTest.test('KOV-E1a (6): `class:lift|tipon|hl_top` sa ODMIETA — HL top Tip-On neexistuje') do
  c = NxKovE1a
  canon, why = c::HWS.parse_class_key('class:lift|tipon|hl_top')
  NxTest.assert_equal(nil, canon)
  NxTest.assert(why.include?('HL top Tip-On'), why.to_s)
  NxTest.assert(c::HWS.incompatible_mapping_entry?('class:lift|tipon|hl_top', 'x'),
                'kniznica s takym klucom je pre citac NEZNAMY obsah')
  NxTest.refute(c::HWS::MAPPING_ADDITIONS.key?('class:lift|tipon|hl_top'),
                'a predvolba pre neho nevznikla')
end

NxTest.test('KOV-E1a (6): ponuka setov triedneho kluca filtruje aj SYSTEM') do
  c = NxKovE1a
  globals = c.seed_sets
  ids = lambda do |key|
    c::HWS.class_set_options(key, globals, {}, []).map { |o| o['set_id'] }.compact.sort
  end
  NxTest.assert_equal(%w[vyklop-hk-klasik vyklop-hk-klasik-tmavy],
                      ids.call('class:lift|classic|hk_top'),
                      'HK klasik: obe farby, ziadny HL a ziadny Tip-On')
  NxTest.assert_equal(%w[vyklop-hl-klasik vyklop-hl-klasik-tmavy],
                      ids.call('class:lift|classic|hl_top'))
  NxTest.assert_equal(%w[vyklop-hk-tipon vyklop-hk-tipon-tmavy],
                      ids.call('class:lift|tipon|hk_top'))
  # Zapisova brana: HL set na HK kluc neprejde.
  defs = {}
  globals.each { |s| defs[s['set_id']] = s }
  why = c::HWS.class_key_value_problem('class:lift|classic|hk_top', 'vyklop-hl-klasik', defs)
  NxTest.assert(why.to_s.include?('systém'), why.to_s)
  NxTest.assert_equal(nil,
                      c::HWS.class_key_value_problem('class:lift|classic|hk_top',
                                                     'vyklop-hk-klasik-tmavy', defs),
                      'tmavy set tej istej triedy prejde')
end

NxTest.test('KOV-E1a (6): NESULAD setu s polozkou = RED (HL set na HK cele)') do
  c = NxKovE1a
  st = c.state({ 'class:lift|classic|hk_top' => 'vyklop-hl-klasik' }, ['vyklop-hl-klasik'])
  exp = c::HWS.expand([c.item], st)
  NxTest.assert_equal([], c.codes(exp), 'ziadny riadok')
  u = exp['unmapped'].first
  NxTest.assert_equal(c::HWS::LIFT_SET_INCOMPLETE, u['reason'])
  NxTest.assert_equal('set_incompatible', u['base_reason'])
  NxTest.assert_equal('lift_system', u['detail'])
end

# ============================================================================
# 7 — OWNER `/flap`
# ============================================================================

NxTest.test('KOV-E1a (7): owner `front:<id>/flap` — parse, validacia, resolver, pruning') do
  c = NxKovE1a
  h = c::HWS
  key = 'class:lift|classic|hk_top@front:F1/flap'
  NxTest.assert_equal([key, nil], h.parse_class_key(key, allow_owner: true))
  NxTest.assert(h.owner_scoped_key?(key), 'kluc je viazany na dielec')
  NxTest.assert_equal(nil, h.parse_class_key(key)[0],
                      'owner kluc NIE JE povoleny v globalnej kniznici ani snapshote')
  # Dielec musi sediet TRIEDE: vyklop na `panel` a zasuvka na `flap` sa odmieta.
  NxTest.assert_equal(nil, h.parse_class_key('class:lift|classic|hk_top@front:F1/panel',
                                             allow_owner: true)[0])
  NxTest.assert_equal(nil, h.parse_class_key('class:slide|classic|metal@front:F1/flap',
                                             allow_owner: true)[0])
  NxTest.assert_equal(nil, h.parse_class_key("#{key.sub('/flap', '/wing:left')}",
                                             allow_owner: true)[0], 'iny dielec sa odmieta')
  # CITACIA normalizacia configu skrinky ho ZACHOVA...
  map = h.normalize_mapping({ key => 'vyklop-hk-klasik-tmavy' }, nil, allow_owner: true)
  NxTest.assert_equal({ key => 'vyklop-hk-klasik-tmavy' }, map, 'round-trip cez config')
  # ...a resolver ho uprednostni pred triednym klucom projektu.
  st = c.state({ 'class:lift|classic|hk_top' => 'vyklop-hk-klasik' },
               %w[vyklop-hk-klasik vyklop-hk-klasik-tmavy])
  exp = h.expand([c.item], st, cabinet_overrides: { 'CAB-1' => map })
  NxTest.assert(c.codes(exp).any? { |code, _| code == '347835' },
                'celo dostane TMAVE krytky z owner volby')
  # Pruning: ked celo zmizne, mrtvy vyber sa zahodi.
  NxTest.assert_equal({}, h.prune_missing_owners(map, ['F2']), 'zmazane celo = vyber prec')
  NxTest.assert_equal(map, h.prune_missing_owners(map, ['F1']), 'existujuce celo ostava')
end

NxTest.test('KOV-E1a (7): owner vyber vyklopu prezije normalizaciu configu skrinky') do
  c = NxKovE1a
  key = 'class:lift|classic|hk_top@front:F1/flap'
  fronts = { 'items' => [{ 'id' => 'F1', 'type' => 'lift' }] }
  cfg = c::CB.normalize('width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => fronts,
                        'hardware_sets' => { key => 'vyklop-hk-klasik-tmavy' })
  NxTest.assert_equal('vyklop-hk-klasik-tmavy', cfg[:hardware_sets][key],
                      'config drzi owner volbu vyklopu')
  # Ked celo zmizne, mrtvy vyber sa pri prestavbe ZAHODI (nikdy sa neoziví).
  bez = c::CB.normalize('width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [{ 'id' => 'F2', 'type' => 'lift' }] },
                        'hardware_sets' => { key => 'vyklop-hk-klasik-tmavy' })
  NxTest.assert_equal({}, bez[:hardware_sets], 'vyber na neexistujucom cele sa nedrzi')
end

# ============================================================================
# 8 — `MAPPING_ADDITIONS`
# ============================================================================

NxTest.test('KOV-E1a (8): tri vyklopove predvolby pribudnu a EXISTUJUCU volbu neprepisu') do
  c = NxKovE1a
  add = c::HWS::MAPPING_ADDITIONS
  NxTest.assert_equal('vyklop-hk-klasik', add['class:lift|classic|hk_top'])
  NxTest.assert_equal('vyklop-hk-tipon', add['class:lift|tipon|hk_top'])
  NxTest.assert_equal('vyklop-hl-klasik', add['class:lift|classic|hl_top'])
  add.each_key do |k|
    NxTest.assert(c::HWS.parse_class_key(k)[0], "predvolba #{k} musi byt platny triedny kluc")
  end
  # Vlastna volba pouzivatela sa NEPREPISE (add-if-absent).
  merged = c::HWS.add_mapping_seed(c.seed_sets, 'class:lift|classic|hk_top' => 'moj-vyklop')
  NxTest.assert_equal('moj-vyklop', merged['class:lift|classic|hk_top'], 'ruky prec')
  NxTest.assert_equal('vyklop-hl-klasik', merged['class:lift|classic|hl_top'],
                      'chybajuce kluce sa doplnili')
end

# ============================================================================
# 9 — STD MARKER a DOWNGRADE (FAIL-CLOSED)
# ============================================================================

NxTest.test('KOV-E1a (9): nove tvary zdvihnu `std` na 6 (obsahova detekcia)') do
  c = NxKovE1a
  sets = c.seed_sets
  mapping = c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
  NxTest.assert_equal(c::HWS::STD_LIFT_FORMS, c::HWS.snapshot_std(mapping, sets))
  NxTest.assert(c::HWS::STD_SUPPORTED.include?(c::HWS::STD_LIFT_FORMS),
                'marker je medzi podporovanymi')
  bez = sets.reject { |s| s['generic_type'] == 'lift' }
  NxTest.assert(c::HWS.snapshot_std(mapping, bez) < c::HWS::STD_LIFT_FORMS,
                'obsah BEZ vyklopov ostava na svojom nizsom marker — citatelnost sa neblokuje')
  NxTest.assert(c::HWS.lift_forms_present?(sets))
  NxTest.refute(c::HWS.lift_forms_present?(bez))
end

NxTest.test('KOV-E1a (9): STARSI citac set ODMIETNE — nikdy ticha „tyc 1 ks"') do
  c = NxKovE1a
  h = c::HWS
  hl = c.set_def('vyklop-hl-klasik')
  # Simulacia STARSIEHO pluginu: `MEMBER_KEYS` bez novych klucov (stary plugin
  # sa spustit neda, takze charakterizacia ide cez whitelist).
  orig = h::MEMBER_KEYS
  begin
    h.send(:remove_const, :MEMBER_KEYS)
    h.const_set(:MEMBER_KEYS, %w[per qty label code code_by_nl param_bands].freeze)
    NxTest.assert(h.incompatible_set?(hl),
                  'set s novym tvarom je pre starsi citac NEKOMPATIBILNY')
    status, lost = h.assess_set_defs([hl])
    NxTest.assert_equal(:lossy, status, 'sablona s takym setom sa ODMIETNE BEZ zapisu')
    NxTest.assert_equal(['vyklop-hl-klasik'], lost)
  ensure
    h.send(:remove_const, :MEMBER_KEYS)
    h.const_set(:MEMBER_KEYS, orig)
  end
  # TATO verzia ho, samozrejme, cita bez straty.
  NxTest.refute(h.incompatible_set?(hl))
  NxTest.assert_equal(:ok, h.assess_set_defs([hl])[0])
end

# ============================================================================
# 10 — CONFIG_SCHEMA
# ============================================================================

NxTest.test('KOV-E1a (10): owner mapovanie vyklopu si vyziadalo schemu 10') do
  c = NxKovE1a
  NxTest.assert_equal(10, c::CB::CONFIG_SCHEMA, 'KOV-E1a zdvihla schemu na 10')
  written = c::CB.cabinet_config(c::CB.normalize('width' => 600.0, 'height' => 720.0,
                                                 'depth' => 500.0))
  NxTest.assert_equal(10, written[:config_schema], 'marker sa zapisuje pri KAZDOM zapise')
  NxTest.assert(c::CB.newer_config?('config_schema' => 11), 'novsia schema sa neprestavuje')
  NxTest.refute(c::CB.newer_config?('config_schema' => 10))
  NxTest.assert_equal(9, c::CB::HINGE_ACTIVATION_SCHEMA,
                      'aktivacia zavesov sa bumpom NEHYBE (skrinky schemy 9 nie su „stare")')
end

# ============================================================================
# 11 — GOLDEN: existujuce zakazky sa NEMENIA
# ============================================================================

NxTest.test('KOV-E1a (11): nakup EXISTUJUCEJ zakazky je CONTENT-identicky') do
  c = NxKovE1a
  sets = {}
  c.seed_sets.each { |s| sets[s['set_id']] = s }
  st = { 'mapping' => c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS), 'sets' => sets }
  items = [
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/wing:single',
      'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy-podla-vysky',
      'source' => 'rule', 'params' => { 'use_type' => 'door', 'opening_mode' => 'classic' } },
    { 'owner_id' => 'CAB-1', 'owner_part_key' => nil, 'generic_type' => 'leg',
      'quantity' => 4, 'rule_id' => 'nohy-zakladne', 'source' => 'rule',
      'params' => { 'height' => 150.0 } },
    { 'owner_id' => 'CAB-1', 'owner_part_key' => nil, 'generic_type' => 'shelf_pin',
      'quantity' => 4, 'rule_id' => 'podperky', 'source' => 'rule', 'params' => {} }
  ]
  exp = c::HWS.expand(items, st)
  NxTest.assert_equal([['104717', 2], ['105408', 2], ['105425', 2], ['106412', 2],
                       ['306125', 4], ['367823', 4]], c.codes(exp),
                      'zavesy, nohy a podperky nakupuju presne ako pred davkou')
  NxTest.assert_equal([], exp['unmapped'])
  lift = c.lift_codes
  NxTest.refute(c.codes(exp).any? { |code, _| lift.include?(code) },
                'ziadny vyklopovy kod sa do starej zakazky nedostal')
end
