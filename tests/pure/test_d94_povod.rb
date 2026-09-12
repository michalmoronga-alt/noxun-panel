# frozen_string_literal: true
# D-94 — „NÁKUP S PÔVODOM": STRÁŽCA INVARIANTU ZDROJOV + adresa klik-selectu.
#
# CO SA RIESI: rozklik pôvodu v sekcii Nákup ukazuje, z ktorých skriniek, setov
# a ručných položiek nákupný riadok vznikol — a sčítava ich. Ak by sa `sources`
# a `quantity` riadku rozišli, používateľ by videl rozpis, ktorý NESEDÍ so
# súčtom, podľa ktorého objednáva. Preto je invariant
#
#     Σ sources[].quantity == row['quantity']
#
# regresne strážený nad `HardwareSets.expand` (čistá funkcia) pre KAŽDÝ riadok
# a pre všetky kanály, ktoré riadok vedia naplniť: členy `per: 'unit'`,
# členy `per: 'owner'` (aj ich dedup cez dve pravidlá na tom istom vlastníkovi),
# viac skriniek s tým istým kódom, katalógová ad-hoc položka zliata do setového
# riadku aj voľná položka s vlastným riadkom.
#
# HRANICA (vedomá): invariant sa NEBETÓNUJE pre POMEROVÉ členy — tie prídu až
# s D-109 (R-05, po V1) a môžu priniesť necelé množstvá alebo iný spôsob
# zaokrúhlenia. Táto sada stráži PÔDU, na ktorej D-109 bude stavať: dnešné
# kanály (unit · owner · adhoc · free) musia sedieť do kusa, aby sa pri D-109
# dalo povedať, čo je nová vlastnosť a čo regresia.
#
# Druhá polovica sady je ADRESA KLIK-SELECTU zo zdroja (`source_ref`):
# `source_select_item` je čistá funkcia (zdroj -> dvojica owner_id/part_key,
# ktorej rozumie EXISTUJÚCI `pids_for_problem`) a `source_focus_status` skladá
# vetu statusu. Samotný resolver `pids_for_source` potrebuje živý model —
# dokazuje ho in-SketchUp sekcia `run_d94` (tests/sketchup/su_runner.rb).
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `add_row` pripocita mnozstvo do riadku, ale zdroj nezapise,
#   2. `adhoc_source` posiela mnozstvo 0 (zdroj bez kusov),
#   3. `source_select_item` mapuje `cabinet_id` na `part_key` (prehodene kluce).
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
end

module NxD94
  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  HS  = E::HardwareSets
  CAT = E::HardwareCatalog
  PC  = E::ProductionCore

  module_function

  # Katalog v sandboxe (vzor `test_kovh1_adhoc.rb`): `norm_hardware_manual` sa
  # katalogu PYTA na nazov a MJ, takze sada potrebuje ZNAMY obsah. V SketchUpe
  # by zapis siel do ziveho %APPDATA% — tam sa katalogove testy preskakuju.
  def catalog_ready!
    NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
    return true if @seeded

    CAT.create_item('item_code' => 'D94-A', 'name_sk' => 'D94 záves',
                    'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 3.0)
    CAT.create_item('item_code' => 'D94-B', 'name_sk' => 'D94 tlmič',
                    'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 5.0)
    @seeded = true
  end

  # Set s OBOMA sposobmi uctovania: `unit` (na kus) aj `owner` (raz na
  # vlastnika) — prave ich kombinacia je miesto, kde sa suctu najlahsie
  # rozide zdroj s mnozstvom (dedup `per: 'owner'` zliava do UZ VYDANEHO zdroja).
  def state
    set = HS.normalize_sets([{ 'set_id' => 'd94-zaves', 'generic_type' => 'hinge',
                               'members' => [{ 'code' => 'D94-A', 'per' => 'unit', 'qty' => 2 },
                                             { 'code' => 'D94-B', 'per' => 'owner',
                                               'qty' => 1 }] }]).first
    { 'mapping' => { 'hinge' => 'd94-zaves' }, 'sets' => { 'd94-zaves' => set } }
  end

  def hw_item(over = {})
    { 'owner_id' => 'CAB-001', 'owner_part_key' => 'front:F1/wing:single',
      'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy-podla-vysky',
      'source' => 'rule', 'params' => {} }.merge(over)
  end

  def cat_item(over = {})
    { 'id' => 'H1', 'owner_part_key' => nil, 'source' => 'catalog', 'code' => 'D94-A',
      'qty' => 3, 'note' => '' }.merge(over)
  end

  def free_item(over = {})
    { 'id' => 'H2', 'owner_part_key' => 'front:F1/wing:single', 'source' => 'free',
      'name' => 'D94 zámok', 'unit' => 'ks', 'price_eur_vat' => 9.0, 'qty' => 2,
      'note' => '' }.merge(over)
  end

  def manual(items, owner_id)
    E::Bom.manual_items_for(owner_id, 11, CB.norm_hardware_manual(items), {})
  end

  def expand(items, manual_items)
    HS.expand(items, state, catalog: CAT.items, manual_items: manual_items)
  end

  # ZAKAZKA, na ktorej sa sada meria: dve skrinky s tym istym setom (ten isty
  # kod z dvoch miest), v CAB-001 este DRUHE pravidlo na TOM ISTOM vlastnikovi
  # (dedup `per: 'owner'`), ad-hoc katalogova polozka v CAB-002 (zliatie do
  # setoveho riadku) a volna polozka v CAB-001 (vlastny riadok).
  def scenario
    items = [hw_item,
             hw_item('rule_id' => 'zavesy-tipon', 'quantity' => 1),
             hw_item('owner_id' => 'CAB-002', 'quantity' => 3)]
    mitems = manual([cat_item], 'CAB-002') + manual([free_item], 'CAB-001')
    expand(items, mitems)
  end

  def rows(exp)
    Array(exp && exp['rows'])
  end

  def row(exp, code)
    rows(exp).find { |r| r['code'].to_s == code.to_s }
  end
end

# =============================================================================
# 1. INVARIANT Σ zdrojov == mnozstvo riadku
# =============================================================================

NxTest.test('D-94: KAZDY nakupny riadok sedi so suctom svojich zdrojov') do
  NxD94.catalog_ready!
  exp = NxD94.scenario
  list = NxD94.rows(exp)
  NxTest.assert(list.length >= 3, "zakazka ma dat aspon 3 riadky — #{list.map { |r| r['code'] }.inspect}")
  list.each do |r|
    label = r['free_key'] || r['code']
    srcs = Array(r['sources'])
    NxTest.assert(!srcs.empty?, "riadok #{label} bez zdrojov — rozklik povodu by nemal co ukazat")
    NxTest.assert_equal(r['quantity'], srcs.sum { |s| s['quantity'].to_i },
                        "riadok #{label}: Σ zdrojov sa rozisla s mnozstvom riadku")
  end
end

NxTest.test('D-94: KAZDY zdroj nesie pouzitelnu adresu a kladny pocet') do
  NxD94.catalog_ready!
  NxD94.rows(NxD94.scenario).each do |r|
    label = r['free_key'] || r['code']
    Array(r['sources']).each do |s|
      NxTest.assert(s['cabinet_id'].is_a?(String) && !s['cabinet_id'].empty?,
                    "zdroj riadku #{label} bez `cabinet_id` — klik by nemal kam viest")
      NxTest.assert(s['quantity'].is_a?(Integer) && s['quantity'].positive?,
                    "zdroj riadku #{label} ma nepouzitelny pocet: #{s['quantity'].inspect}")
      NxTest.assert(s.key?('owner_part_key'),
                    "zdroj riadku #{label} nema kluc vlastnika (nil = cela skrinka, ale kluc TAM JE)")
    end
  end
end

NxTest.test('D-94: ten isty kod z DVOCH skriniek da JEDEN riadok s dvoma adresami') do
  NxD94.catalog_ready!
  r = NxD94.row(NxD94.scenario, 'D94-A')
  NxTest.assert(r, 'setovy riadok kodu D94-A existuje')
  cabs = Array(r['sources']).map { |s| s['cabinet_id'] }.uniq.sort
  NxTest.assert_equal(%w[CAB-001 CAB-002], cabs, 'zdroje menuju OBE skrinky')
  # 2 (CAB-001 zavesy) + 1 (CAB-001 tipon) + 3 (CAB-002) = 6 kusov x qty 2
  # + 3 ks ad-hoc polozky zliatej do toho isteho riadku.
  NxTest.assert_equal(15, r['quantity'], 'sucet setovych kusov aj ad-hoc dokopy')
  NxTest.assert_equal(3, r['adhoc_quantity'], 'riadok prizna, kolko z neho je rucne')
  NxTest.assert_equal(r['quantity'], Array(r['sources']).sum { |s| s['quantity'].to_i },
                      'invariant plati aj pri ZLIATI ad-hoc polozky so setovym riadkom')
end

NxTest.test('D-94: dedup clena `per: owner` NEROZBIJE sucet (zdroj pohltil duplikat)') do
  NxD94.catalog_ready!
  r = NxD94.row(NxD94.scenario, 'D94-B')
  NxTest.assert(r, 'riadok clena uctovaneho na vlastnika existuje')
  # CAB-001 ma DVE pravidla na TOM ISTOM vlastnikovi — clen `per: 'owner'` sa
  # vyda RAZ; CAB-002 je iny vlastnik, takze prida svoj kus.
  NxTest.assert_equal(2, r['quantity'], 'jeden kus na vlastnika, dvaja vlastnici')
  NxTest.assert_equal(2, Array(r['sources']).length, 'a prave dva zdroje')
  NxTest.assert_equal(r['quantity'], Array(r['sources']).sum { |s| s['quantity'].to_i },
                      'invariant plati aj po dedupe')
  pohltil = Array(r['sources']).find { |s| s['per_owner'] == true }
  NxTest.assert(pohltil, 'zdroj, ktory duplikat pohltil, to PRIZNA (`per_owner`)')
end

NxTest.test('D-94: volna polozka ma vlastny riadok a JEDEN zdroj so svojim poctom') do
  NxD94.catalog_ready!
  r = NxD94.rows(NxD94.scenario).find { |x| x['free'] == true }
  NxTest.assert(r, 'volna polozka ma vlastny riadok')
  NxTest.assert_equal(2, r['quantity'])
  NxTest.assert_equal(1, Array(r['sources']).length)
  NxTest.assert_equal(r['quantity'], Array(r['sources']).sum { |s| s['quantity'].to_i })
  NxTest.assert_equal('front:F1/wing:single', Array(r['sources']).first['owner_part_key'],
                      'a nesie kluc vlastnika, na ktory sa da kliknut')
end

NxTest.test('D-94: skrinka BEZ kovania nevyda ani riadok, ani zdroj') do
  NxD94.catalog_ready!
  exp = NxD94.expand([], [])
  NxTest.assert_equal([], NxD94.rows(exp), 'ziadne riadky')
  NxTest.assert_equal(0, exp['summary']['rows'], 'a suhrn to hovori tiez')
end

NxTest.test('D-94: zdroj kovania CELEJ skrinky nesie `owner_part_key` = nil') do
  NxD94.catalog_ready!
  # Ad-hoc polozka bez vlastnika = kovanie celej skrinky. JS z toho kresli
  # „celá skrinka" a klik oznaci KORPUS — preto to musi byt nil, nie prazdny
  # retazec (ten by sa od kluca dielca nedal odlisit az v klientovi).
  exp = NxD94.expand([], NxD94.manual([NxD94.cat_item('qty' => 1)], 'CAB-003'))
  s = Array(NxD94.row(exp, 'D94-A')['sources']).first
  NxTest.assert_equal(nil, s['owner_part_key'], 'nil = kovanie patri celej skrinke')
  NxTest.assert_equal('CAB-003', s['cabinet_id'])
  NxTest.assert_equal(1, s['quantity'])
end

# =============================================================================
# 2. ADRESA KLIK-SELECTU ZO ZDROJA (`source_ref`)
# =============================================================================

NxTest.test('D-94: zdroj sa prelozi na adresu, ktorej rozumie EXISTUJUCI resolver') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  it = NxD94::PC.source_select_item('cabinet_id' => 'CAB-3',
                                   'owner_part_key' => 'front:F1/wing:left')
  NxTest.assert_equal({ 'owner_id' => 'CAB-3', 'part_key' => 'front:F1/wing:left' }, it,
                      'dvojica (owner_id, part_key) — presne to, co berie `pids_for_problem`')
  cela = NxD94::PC.source_select_item('cabinet_id' => 'CAB-3', 'owner_part_key' => nil)
  NxTest.assert_equal('', cela['part_key'],
                      'kovanie celej skrinky = PRAZDNY kluc (resolver oznaci korpus)')
  NxTest.assert_equal({ 'owner_id' => '', 'part_key' => '' }, NxD94::PC.source_select_item(nil),
                      'nezmysel na vstupe nevyrobi adresu (vyber sa nevykona)')
end

NxTest.test('D-94: veta statusu po kliku na zdroj CELEJ skrinky hovori o SKRINKE') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  one = NxD94::PC.source_focus_status(1, 'CAB-3', true)
  NxTest.assert(one.include?('skrinka CAB-3'), "veta menuje skrinku — #{one}")
  NxTest.assert(one.include?('Inspector je vpredu'), "a priznava deep-link — #{one}")
  NxTest.assert(!NxD94::PC.source_focus_status(1, 'CAB-3', false).include?('Inspector'),
                'bez zdvihnutia Inspectora sa o nom NEKLAME')
  # Dve skrinky so ZDIELANYM `cabinet_id` sa oznacia OBE (vedomy dosledok
  # zdielaneho resolvera) — veta to musi priznat, inak pouzivatel hlada chybu.
  two = NxD94::PC.source_focus_status(2, 'CAB-3', true)
  NxTest.assert(two.include?('2 kusov s ID CAB-3'), "mnozne cislo prizna zdielane ID — #{two}")
  # Zdroj s KLUCOM dielca menuje polozky (skrinka sa necela neoznacila).
  part = NxD94::PC.source_focus_status(3, nil, false)
  NxTest.assert(part.include?('Vybraných 3 položiek'), "veta o polozkach — #{part}")
end

NxTest.test('D-94 (Codex #361 P2): ZAVRETY Inspector sa prizna, nie zamlci') do
  NxTest.skip!('UI vrstva sa nacitava len headless') unless NxTest.headless?
  # `do_select` Inspector NIKDY NEOTVARA (konvencia Š3 ceruzky) — len ho
  # zdvihne. Ked si ho okno vypytalo (`focus_inspector`) a je zavrety, klik
  # oznaci v modeli a inak sa VIDITELNE nestane nic; bez tejto vety by tooltip
  # zdroja slubil Inspector a pouzivatel by hladal chybu.
  dead = NxD94::PC.source_focus_status(1, 'CAB-3', false, true)
  NxTest.assert(dead.include?('skrinka CAB-3'), "vyber sa aj tak stal — #{dead}")
  NxTest.assert(dead.include?('Inspector nie je otvorený'), "a zavrete okno sa PRIZNA — #{dead}")
  # To iste pri zdroji s klucom cela (tam je veta o polozkach).
  part = NxD94::PC.source_focus_status(2, nil, false, true)
  NxTest.assert(part.include?('Vybraných 2 položiek'), "veta o polozkach ostava — #{part}")
  NxTest.assert(part.include?('Inspector nie je otvorený'), "a dovetok tiez — #{part}")
  # Ked sa Inspector NEZIADAL, o Inspectorovi sa NEHOVORI vobec.
  NxTest.assert(!NxD94::PC.source_focus_status(1, 'CAB-3', false, false).include?('Inspector'),
                'nevypytany Inspector sa v statuse nespomina')
  NxTest.assert_equal(' Inspector je vpredu.', NxD94::PC.source_focus_suffix(true, false),
                      'zivy zdvihnuty Inspector vyhrava nad ziadostou')
  NxTest.assert_equal('', NxD94::PC.source_focus_suffix(false, false))
end

NxTest.test('D-94: `pids_for_source` NEDUPLIKUJE resolver — vola `pids_for_problem`') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                  encoding: 'UTF-8')
  body = src[/def pids_for_source.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'metoda existuje')
  NxTest.assert(body.include?('pids_for_problem('),
                'telo je ZDIELANE s nalezmi Kontroly (druha kopia by sa casom rozisla)')
  NxTest.assert(body.include?('select_target_item('),
                'a pri deep-linku vybera VLASTNIKA tou istou funkciou ako KOV-A2b')
end
