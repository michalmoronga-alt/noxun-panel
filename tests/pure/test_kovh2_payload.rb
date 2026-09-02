# frozen_string_literal: true
# KOV-H2 — SERVEROVÁ STRANA UI ad-hoc kovania.
#
# CO SA RIESI: dátovú vrstvu má KOV-H1, táto dávka k nej pridala UI. Server
# preto musí panelu dodať tri veci, ktoré si panel NESMIE odvodiť sám:
#   * `hardware_manual_view[]`   — riadok tak, ako sa kreslí (ŽIVÁ cena
#     z katalógu, popis vlastníka, priznané stavy „bez vlastníka" a „chýba
#     v katalógu"). Cena katalógovej položky sa v configu NEUKLADÁ (H1
#     BLOCKER 2), takže bez tohto payloadu by ju panel nemal odkiaľ vziať.
#   * `hardware_manual_owners[]` — ponuka „Patrí k" (čelá a zónové dielce
#     AKTUÁLNEHO plánu, nikdy surový kľúč).
#   * `NX.hwManualResult`        — odpoveď modalu. Zámok odosielania odomyká
#     VÝHRADNE volajúci (kontrakt D-15), takže server musí odpovedať v KAŽDEJ
#     vetve `handle_apply_all` — aj v tej, ktorá zápis ticho zahadzuje.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `manual_view_price` vracia pri katalogovej polozke SNAPSHOT z configu
#      namiesto ZIVEJ ceny katalogu,
#   2. `hardware_manual_view` pocita `owner_missing` bez planu (kazdy vlastnik mrtvy),
#   3. `hw_manual_search_result` vracia aj NEAKTIVNE polozky,
#   4. `decorate_source_owners` sklada popis bez `front_items` (surove id cela).
#
# UNDO, geometriu a spravanie nad ZIVYM modelom dokazuje in-SketchUp sekcia
# `run_kovh2` v tests/sketchup/su_runner.rb.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
end

module NxKovh2
  E   = Noxun::Engine
  P   = E::Panel
  CB  = E::CabinetBuilder
  CAT = E::HardwareCatalog

  module_function

  # Katalog v sandboxe (vzor `test_kovh1_adhoc.rb`): `hardware_manual_view` sa
  # katalogu PYTA na ZIVU cenu, takze sada potrebuje ZNAMY obsah.
  def catalog_ready!
    NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
    return true if @seeded

    CAT.create_item('item_code' => 'KOVH2-A', 'name_sk' => 'Rektifikačný uholník',
                    'category' => 'SPOJOVACI_MATERIAL', 'unit' => 'ks', 'price_eur_vat' => 1.14)
    CAT.create_item('item_code' => 'KOVH2-OFF', 'name_sk' => 'Zrušený uholník',
                    'category' => 'SPOJOVACI_MATERIAL', 'unit' => 'ks', 'price_eur_vat' => 9.9,
                    'active' => false)
    @seeded = true
  end

  def params(over = {})
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'zone_tree' => E::ZoneTree.default_tree(1),
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto',
                                  'wings' => '2' }] } }.merge(over)
  end

  # config skrinky tak, ako ho vidi `cabinet_payload` (front_items = resolved).
  def cfg(items, over = {})
    p = params
    plan = CB.plan_parts_by_key(p)
    { 'hardware_manual' => items,
      'front_items' => [{ 'id' => 'F1', 'type' => 'door', 'wings_n' => 2 }] }
      .merge(over)
      .merge('plan' => plan)
  end

  def plan
    CB.plan_parts_by_key(params)
  end

  def cat_item(over = {})
    { 'id' => 'H1', 'owner_part_key' => 'front:F1/wing:left', 'source' => 'catalog',
      'code' => 'KOVH2-A', 'name' => 'Starý názov zo snapshotu', 'unit' => 'ks',
      # STARY snapshot ceny v configu: `norm_hardware_manual` ho pri katalogovej
      # polozke NEUKLADA (H1 BLOCKER 2), ale zakazka z INEJ verzie ho niest moze
      # — a payload ho NESMIE pouzit ani vtedy.
      'price_eur_vat' => 99.0,
      'qty' => 2, 'note' => 'podľa priania' }.merge(over)
  end

  def free_item(over = {})
    { 'id' => 'H2', 'owner_part_key' => nil, 'source' => 'free', 'code' => '',
      'name' => 'Zámok Abloy', 'unit' => 'ks', 'price_eur_vat' => 12.5,
      'qty' => 1, 'note' => '' }.merge(over)
  end

  def view(items, over_cfg = {})
    c = { 'hardware_manual' => items,
          'front_items' => [{ 'id' => 'F1', 'type' => 'door', 'wings_n' => 2 }] }.merge(over_cfg)
    P.hardware_manual_view(c, plan, 'CAB-001')
  end

  def owners(over_cfg = {})
    c = { 'front_items' => [{ 'id' => 'F1', 'type' => 'door', 'wings_n' => 2 }] }.merge(over_cfg)
    P.hardware_manual_owners(c, plan)
  end

  def src(file)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', file), encoding: 'UTF-8')
  end
end

# --- 1) hardware_manual_view -------------------------------------------------

NxTest.test('KOV-H2: riadok ad-hoc polozky nesie ZIVU cenu katalogu, nie snapshot') do
  NxKovh2.catalog_ready!
  row = NxKovh2.view([NxKovh2.cat_item]).first
  NxTest.assert_equal 'KOVH2-A', row['code'], 'kod ide z configu'
  NxTest.assert_equal 'Rektifikačný uholník', row['name'],
                      'nazov je ZIVY z katalogu (nie snapshot „Starý názov zo snapshotu")'
  NxTest.assert_equal 1.14, row['price_eur_vat'],
                      'cena je ZIVA z katalogu — nikdy snapshot z configu (99,00 €)'
  NxTest.assert_equal 'ks', row['unit'], 'MJ tiez z katalogu'
  NxTest.assert_equal false, row['catalog_missing'], 'kod v katalogu je'
  NxTest.assert_equal 2, row['qty'], 'mnozstvo z configu'
  NxTest.assert_equal 'podľa priania', row['note'], 'aj poznamka'
end

NxTest.test('KOV-H2: volna polozka ma VLASTNU cenu a nazov (zadal ich clovek)') do
  NxKovh2.catalog_ready!
  row = NxKovh2.view([NxKovh2.free_item]).first
  NxTest.assert_equal 'Zámok Abloy', row['name'], 'nazov je pouzivatelov'
  NxTest.assert_equal 12.5, row['price_eur_vat'], 'a cena tiez'
  NxTest.assert_equal '', row['code'], 'kod NEMA (nesmie sa tvarit ako katalogova)'
  NxTest.assert_equal false, row['catalog_missing'], 'volna polozka v katalogu chybat nemoze'
end

NxTest.test('KOV-H2: zmiznuty kod = „chýba v katalógu" BEZ ceny (nikdy 0)') do
  NxKovh2.catalog_ready!
  row = NxKovh2.view([NxKovh2.cat_item('code' => 'NIET-V-KATALOGU')]).first
  NxTest.assert_equal true, row['catalog_missing'], 'stav sa PRIZNA'
  NxTest.assert(row['price_eur_vat'].nil?,
                'bez katalogu je cena NEZADANA — nikdy nula a nikdy stary snapshot z configu')
  NxTest.assert_equal 'Starý názov zo snapshotu', row['name'],
                      'nazov ostane zo SNAPSHOTU — inak by riadok stratil identitu'
end

NxTest.test('KOV-H2: popis vlastnika sklada SERVER a mrtvy vlastnik sa PRIZNA') do
  NxKovh2.catalog_ready!
  rows = NxKovh2.view([NxKovh2.cat_item,
                       NxKovh2.free_item,
                       NxKovh2.cat_item('id' => 'H3', 'owner_part_key' => 'front:F9/wing:left')])
  NxTest.assert_equal 'F1 · dvierka ľavé', rows[0]['owner_label'],
                      'popis je z PartKeys.human_label (JS nic neodvodzuje)'
  NxTest.assert_equal false, rows[0]['owner_missing'], 'dielec v plane je'
  NxTest.assert(rows[1]['owner_label'].nil?, 'polozka celej skrinky popis nema')
  NxTest.assert_equal false, rows[1]['owner_missing'],
                      'a `owner_missing` NIKDY nema (nema co chybat)'
  NxTest.assert_equal true, rows[2]['owner_missing'],
                      'dielec, ktory v plane NIE JE, sa prizna ORANGE stavom'
end

NxTest.test('KOV-H2: prazdny zoznam nestavia plan zbytocne') do
  NxTest.assert_equal [], NxKovh2.view([]), 'bez poloziek je view prazdne'
end

# --- 2) hardware_manual_owners ----------------------------------------------

NxTest.test('KOV-H2: ponuka „Patrí k" = cela skrinka + cela a zonove dielce') do
  list = NxKovh2.owners
  NxTest.assert_equal({ 'key' => nil, 'label' => 'celá skrinka' }, list.first,
                      'prva volba je vzdy cela skrinka')
  keys = list.map { |o| o['key'] }
  NxTest.assert(keys.include?('front:F1/wing:left'), 'kridla dvierok sa ponukaju')
  NxTest.assert(keys.include?('front:F1/wing:right'), 'obe')
  NxTest.assert(keys.any? { |k| k.to_s.start_with?('zone:') }, 'zonove dielce tiez')
  # Korpusove dielce sa NEPONUKAJU — „uholnik patri k lavemu boku" nie je
  # informacia, s ktorou by vyroba alebo nakup vedeli nieco robit.
  NxTest.refute(keys.any? { |k| k.to_s.start_with?('cabinet/') },
                'korpusove dielce (boky, dno, strop, chrbat, sokel) sa NEponukaju')
  labels = list.map { |o| o['label'] }
  NxTest.refute(labels.any? { |l| l.to_s.include?('/') || l.to_s.include?(':') },
                'v ponuke NIE JE surovy kluc — vyzeral by ako nazov a nepovedal by nic')
  NxTest.assert(labels.include?('F1 · dvierka ľavé'), 'popisy su ludske')
end

NxTest.test('KOV-H2: pri poskodenom plane ostava aspon cela skrinka') do
  list = Noxun::Engine::Panel.hardware_manual_owners({}, {})
  NxTest.assert_equal [{ 'key' => nil, 'label' => 'celá skrinka' }], list,
                      'prazdny plan = jedina volba, nikdy vynimka do payloadu'
end

# --- 3) hw_manual_search ------------------------------------------------------

NxTest.test('KOV-H2: hladanie vracia poradie zo servera, generaciu a total') do
  NxKovh2.catalog_ready!
  res = Noxun::Engine::Panel.hw_manual_search_result('KOVH2-A', 7)
  NxTest.assert_equal 7, res['gen'], 'generacia dotazu sa vracia nezmenena'
  NxTest.assert(res['items'].is_a?(Array), 'vysledky su pole')
  NxTest.assert_equal 'KOVH2-A', res['items'].first['code'], 'presna zhoda kodu je prva'
  NxTest.assert_equal 'Rektifikačný uholník', res['items'].first['name_sk'], 'aj s nazvom'
  NxTest.assert_equal 1.14, res['items'].first['price_eur_vat'], 'a so ZIVOU cenou'
  NxTest.assert(res['total'].is_a?(Integer), 'total je cislo (klient prizna orezanie)')
  NxTest.assert(res['total'] >= res['items'].length, 'a nikdy nie mensi nez pocet vratenych')
end

NxTest.test('KOV-H2: hladanie NEPONUKA neaktivne polozky') do
  NxKovh2.catalog_ready!
  res = Noxun::Engine::Panel.hw_manual_search_result('uholník', 1)
  codes = res['items'].map { |i| i['code'] }
  NxTest.assert(codes.include?('KOVH2-A'), 'aktivna polozka sa v ponuke najde')
  NxTest.refute(codes.include?('KOVH2-OFF'),
                'do zakazky sa nema dostat kod, ktory uz nikto neobjednava')
  # JEDINA vynimka je PRESNY kod — rovnako ako v katalogu Studia: kto ho pozna,
  # ma pravo ho vidiet (a serverova kontrola zapisu `active` aj tak nerieši).
  exact = Noxun::Engine::Panel.hw_manual_search_result('KOVH2-OFF', 2)
  NxTest.assert(exact['items'].map { |i| i['code'] }.include?('KOVH2-OFF'),
                'presny kod neaktivnu polozku najde (kontrakt `search_with_total`)')
end

NxTest.test('KOV-H2: hladanie vracia NAJVIAC 20 poloziek') do
  NxKovh2.catalog_ready!
  res = Noxun::Engine::Panel.hw_manual_search_result('', 1)
  NxTest.assert(res['items'].length <= 20, 'ponuka je orezana na 20 poloziek')
  NxTest.assert(NxKovh2.src('ui/panel/actions_hardware.rb').include?('MANUAL_SEARCH_TOP = 20'),
                'a strop je JEDNO cislo v zdroji (nie magicka konstanta v dvoch miestach)')
end

# --- 4) manual_op -> hwManualResult ------------------------------------------

module NxKovh2Js
  # Zachytenie `Panel.js` — server posiela odpoved modalu TOUTO cestou.
  def self.capture
    sc = Noxun::Engine::Panel.singleton_class
    out = []
    sc.send(:alias_method, :kovh2_orig_js, :js)
    sc.send(:define_method, :js) { |script| out << script }
    yield out
  ensure
    sc.send(:remove_method, :js)
    sc.send(:alias_method, :js, :kovh2_orig_js)
    sc.send(:remove_method, :kovh2_orig_js)
  end
end

NxTest.test('KOV-H2: `manual_op` prijima LEN znamu operaciu') do
  panel = Noxun::Engine::Panel
  NxTest.assert_equal({ 'kind' => 'add', 'id' => '' },
                      panel.manual_op('manual_op' => { 'kind' => 'add' }),
                      'pridanie ide bez id')
  NxTest.assert_equal({ 'kind' => 'edit', 'id' => 'H1' },
                      panel.manual_op('manual_op' => { 'kind' => 'edit', 'id' => 'H1' }),
                      'uprava nesie id')
  NxTest.assert(panel.manual_op({}).nil?, 'bezna zmena pola ziadnu operaciu nema')
  NxTest.assert(panel.manual_op('manual_op' => { 'kind' => 'drop' }).nil?,
                'neznamy druh operacie sa NEPRIJIMA (payload je verejny kanal)')
  NxTest.assert(panel.manual_op('manual_op' => 'add').nil?, 'ani iny tvar')
end

NxTest.test('KOV-H2: vysledok chodi modalu v OBOCH vetvach, bez operacie mlci') do
  panel = Noxun::Engine::Panel
  NxKovh2Js.capture do |calls|
    panel.push_manual_result(nil, true, 'nic')
    NxTest.assert_equal 0, calls.length,
                        'apply z formulara ziadny modal necaka — nic sa neposiela'
    panel.push_manual_result({ 'kind' => 'add', 'id' => '' }, true, 'Položka pridaná.')
    NxTest.assert_equal 1, calls.length, 'uspech sa ohlasi'
    NxTest.assert(calls[0].start_with?('NX.hwManualResult(true,'), 'ako `ok = true`')
    NxTest.assert(calls[0].include?('Položka pridaná.'), 's hlaskou')
    NxTest.assert(calls[0].include?('"kind":"add"'), 'a s operaciou, ktorej patri')
    panel.push_manual_result({ 'kind' => 'edit', 'id' => 'H1' }, false, 'Kód nie je v katalógu.')
    NxTest.assert(calls[1].start_with?('NX.hwManualResult(false,'),
                  'odmietnutie tiez — inak by modal ostal ZAMKNUTY navzdy')
  end
end

NxTest.test('KOV-H2: hlaska mazania menuje polozku') do
  panel = Noxun::Engine::Panel
  params = { 'hardware_manual' => [{ 'id' => 'H1', 'name' => 'Zámok Abloy' },
                                   { 'id' => 'H2', 'name' => '', 'code' => '93240' }] }
  del = ->(id) { panel.manual_removed_label(params, { 'kind' => 'delete', 'id' => id }) }
  NxTest.assert_equal 'Zámok Abloy', del.call('H1'), 'volna polozka sa menuje nazvom'
  NxTest.assert_equal '93240', del.call('H2'), 'katalogova aspon kodom'
  NxTest.assert(del.call('NIET').nil?, 'neznama polozka nazov NEVYMYSLA')
  NxTest.assert(panel.manual_removed_label(params, { 'kind' => 'add', 'id' => 'H1' }).nil?,
                'pri pridani sa nic nemenuje')
  # Regres z in-SketchUp behu: `manual_ok_msg` sa vola AJ pri beznom apply
  # z formulara (argumenty sa vyhodnocuju EAGERNE, takze skory navrat
  # `push_manual_result` sem nedosiahne) — bez guardu spadol KAZDY apply.
  NxTest.assert_equal '', panel.manual_ok_msg(nil), 'bez operacie je hlaska prazdna, nie vynimka'
  NxTest.assert_equal '', panel.manual_ok_msg(nil, 'X'), 'ani s nazvom polozky'
  NxTest.assert_equal 'Odstránená ručná položka „Zámok Abloy“.',
                      panel.manual_ok_msg({ 'kind' => 'delete', 'id' => 'H1' }, 'Zámok Abloy'),
                      'status povie, CO sa odstranilo (mazanie ide bez potvrdenia)'
end

NxTest.test('KOV-H2: KAZDA vetva `handle_apply_all` odpoveda modalu') do
  body = NxKovh2.src('ui/panel/actions_cabinet.rb')[/def handle_apply_all.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'telo handlera sa naslo')
  returns = body.scan(/^\s+return\b.*$/).map(&:strip)
  NxTest.assert(returns.length >= 5, "handler ma viac skorych navratov (#{returns.length})")
  returns.each do |line|
    NxTest.assert(line.include?('push_manual_result'),
                  "skory navrat „#{line}“ musi odpovedat modalu — zamok odomyka " \
                  'VYHRADNE volajuci (kontrakt D-15)')
  end
  NxTest.assert(body.include?('push_manual_result(op, true, manual_ok_msg(op, removed))'),
                'a uspesna cesta tiez')
  NxTest.assert(body.index('push_selected(model)') < body.rindex('push_manual_result'),
                'pri odmietnuti ide signal AZ PO pushi — panel sa vrati na ULOZENY stav')
end

# --- 5) povod nakupneho riadku ------------------------------------------------

NxTest.test('KOV-H2: kazdy zdroj nakupneho riadku dostane LUDSKY popis vlastnika') do
  # Id cela je GENEROVANY retazec — cislo „F1" vznika az POROVNANIM s resolved
  # celami TEJ skrinky. Preto je vo fixture generovane id: s celami musi vyjst
  # „F1", bez nich surove id.
  fid = 'Fmsi0wnix-1-3a3kxe'
  rows = [{ 'code' => 'KOVH2-A', 'quantity' => 6,
            'sources' => [{ 'cabinet_id' => 'CAB-2', 'owner_part_key' => "front:#{fid}/wing:left",
                            'origin' => 'adhoc', 'quantity' => 2 },
                          { 'cabinet_id' => 'CAB-2', 'owner_part_key' => nil,
                            'set_id' => 'uholniky', 'quantity' => 4 },
                          { 'cabinet_id' => 'CAB-9', 'owner_part_key' => "front:#{fid}/wing:left",
                            'set_id' => 'uholniky', 'quantity' => 1 }] }]
  collected = { cabinet_fronts: { 'CAB-2' => [{ 'id' => fid, 'type' => 'door', 'wings_n' => 2 }] } }
  Noxun::Engine::ProductionCore.decorate_source_owners(rows, collected)
  s = rows[0]['sources']
  NxTest.assert_equal 'F1 · dvierka ľavé', s[0]['owner_label'],
                      'popis sa sklada z resolved ciel TEJ skrinky'
  NxTest.assert(s[1]['owner_label'].nil?, 'kovanie celej skrinky vlastnika nema')
  NxTest.assert_equal "#{fid} · dvierka ľavé", s[2]['owner_label'],
                      'bez znamych ciel ostava SUROVE id cela — cislo „F1" sa NIKDY nehada'
end

NxTest.test('KOV-H2: zber nesie resolved cela per skrinka (aditivny kluc)') do
  bom = NxKovh2.src('core/bom.rb')
  NxTest.assert(bom.include?('cabinet_fronts[cid] ||='),
                'PRVA instancia vyhrava (zdielane cabinet_id je ina chyba)')
  NxTest.assert(bom.include?('cabinet_fronts: cabinet_fronts'), 'a kluc ide von zo zberu')
  compute = bom[/def compute.*?\n      end\n/m].to_s
  NxTest.refute(compute.include?('cabinet_fronts'),
                '`compute()` aditivny kluc IGNORUJE (tvar vystupu sa nemeni)')
end

NxTest.test('KOV-H2: nakupny CSV a rozpocet o `owner_label` nevedia') do
  budget = NxKovh2.src('core/budget.rb')
  hw = budget[/def hardware_section.*?\n      end\n/m].to_s
  NxTest.refute(hw.include?('owner_label'),
                'rozpocet zdroje necita — vystup zakazky sa nemeni ani o znak')
  core = NxKovh2.src('ui/production_core.rb')
  csv = core[/def hw_csv_rows.*?\n      end\n/m].to_s
  NxTest.refute(csv.include?('owner_label'), 'ani nakupny CSV') unless csv.empty?
end

# --- 6) zrkadla a registracia -------------------------------------------------

NxTest.test('KOV-H2: MJ v modali su ZRKADLOM serverovej HardwareCatalog::UNITS') do
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'),
                 encoding: 'UTF-8')
  block = js[/var HW_MANUAL_UNITS = \[(.*?)\];/m, 1].to_s
  NxTest.refute(block.empty?, 'zoznam MJ sa v paneli nasiel')
  codes = block.scan(/\['([a-z]+)',/).flatten
  NxTest.assert_equal Noxun::Engine::HardwareCatalog::UNITS, codes,
                      'MJ modalu sa NESMU rozist so serverovym slovnikom jednotiek'
end

NxTest.test('KOV-H2: callback hladania je registrovany a je CITACI') do
  panel = NxKovh2.src('ui/panel.rb')
  NxTest.assert(panel.include?("cb(dlg, 'hw_manual_search')"),
                'panel registruje kanal hladania')
  hw = NxKovh2.src('ui/panel/actions_hardware.rb')
  body = hw[/def handle_hw_manual_search.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'handler existuje')
  %w[rebuild start_operation push_selected set_status].each do |forbidden|
    NxTest.refute(body.include?(forbidden),
                  "hladanie je CITACIE — `#{forbidden}` v nom nema co robit")
  end
  NxTest.assert(body.include?('NX.hwManualSearchResult'), 'odpoved chodi vlastnym kanalom')
end

NxTest.test('KOV-H2: payload skrinky nesie obe projekcie a stavia plan RAZ') do
  pay = NxKovh2.src('ui/panel/payloads.rb')
  body = pay[/def cabinet_payload.*?\n        end\n/m].to_s
  NxTest.assert(body.include?("params['hardware_manual_view']"), 'view je v payloade')
  NxTest.assert(body.include?("params['hardware_manual_owners']"), 'aj ponuka vlastnikov')
  NxTest.assert_equal 1, body.scan('manual_plan_keys(params)').length,
                      'plan sa stavia RAZ pre oba kluce (je to cely build_plan)'
  form = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'),
                   encoding: 'UTF-8')
  %w[hardware_manual_view hardware_manual_owners].each do |key|
    NxTest.refute(form.include?(key),
                  "`collectAll` o `#{key}` NEVIE — projekcie sa nikdy nevracaju serveru")
  end
end
