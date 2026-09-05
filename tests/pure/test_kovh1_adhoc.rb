# frozen_string_literal: true
# KOV-H1 — AD-HOC KOVANIE (dátová vrstva).
#
# CO SA RIESI: ku skrinke, čelu alebo zónovému dielcu sa dá pridať KONKRÉTNA
# položka kovania MIMO setov (`config['hardware_manual'][]`) a objaví sa
# v nákupe, rozpočte aj v cenovej ponuke s jasným pôvodom. UI príde v KOV-H2 —
# táto dávka je LEN kontrakt, zber, expanzia, ceny a brány.
#
# ROZHODNUTIA AUDITU #15, ktoré sada dokazuje:
#   B1 — ŽIADNY nový zápisový kanál: pole ide `collectAll()` -> `apply_all` ->
#        `normalize` -> rebuild, `cabinet_config` stampuje `CONFIG_SCHEMA` 3.
#   B2 — katalógová položka sa oceňuje ŽIVOU cenou katalógu (v configu je len
#        kód + snapshot názvu/MJ); cena sa pri nej NEUKLADÁ NIKDY. Voľná
#        položka má vlastný riadok a cenu zo snapshotu.
#   B3 — R-12 EXPORTNÁ brána: zákazka zo schémy vyššej než tejto verzie
#        zastaví nákupný CSV, rozpočet aj ponuku (VEPO nie).
#   B4 — vlastník sa kontroluje STRIKTNE len pri ADD/EDIT; rebuild kľúč nikdy
#        nezahodí a mŕtvy vlastník je ORANGE nález, nie tichá strata položky.
#   FIX 7  — ad-hoc kanál NIKDY nejde cez `note_manual` (to je D-93).
#   FIX 10 — nové ID len pri vzniku novej skrinky (`rekey_hardware_manual`).
#   FIX 12 — klientovi sa verí LEN kód; názov a MJ dopĺňa server z katalógu.
#   FIX 13 — nákupný CSV bez nového stĺpca (bajtovú identitu drží
#            `tests/pure/test_kovh_golden.rb`).
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `config_to_params` pole `hardware_manual` neprenasa (vypadne z jednej
#      z round-trip ciest),
#   2. snapshot cena KATALOGOVEJ polozky sa uklada a pouzije v nakupe,
#   3. ad-hoc polozka ide cez `note_manual` (zapocita sa do `manual_quantity`),
#   4. `rekey_hardware_manual` sa vola z `normalize` (prestavba prekluckuje ID).
#
# GEOMETRIU, UNDO a spravanie nad ZIVYM modelom dokazuje in-SketchUp sekcia
# `run_kovh1` v tests/sketchup/su_runner.rb.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
end

module NxKovh1
  E   = Noxun::Engine
  CB  = E::CabinetBuilder
  HS  = E::HardwareSets
  CAT = E::HardwareCatalog

  module_function

  # --- katalog v sandboxe --------------------------------------------------
  #
  # `norm_hardware_manual` sa katalogu PYTA (FIX 12: nazov a MJ dopĺňa server),
  # takze sada potrebuje ZNAMY obsah katalogu. V SketchUpe by zapis siel do
  # ziveho %APPDATA% — tam sa katalogove testy preskakuju (vzor `test_2a1`).
  def catalog_ready!
    NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
    return true if @seeded

    CAT.create_item('item_code' => 'KOVH-A', 'name_sk' => 'Záves Clip Top 110°',
                    'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 3.42)
    CAT.create_item('item_code' => 'KOVH-B', 'name_sk' => 'Výsuv Quadro 470',
                    'category' => 'VYSUVY', 'unit' => 'par', 'price_eur_vat' => 18.9)
    @seeded = true
  end

  # --- fixtury -------------------------------------------------------------

  def base(over = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto',
                                  'wings' => '1' }] } }.merge(over)
  end

  def cat_item(over = {})
    { 'id' => 'H1', 'owner_part_key' => nil, 'source' => 'catalog', 'code' => 'KOVH-A',
      'qty' => 2, 'note' => '' }.merge(over)
  end

  def free_item(over = {})
    { 'id' => 'H2', 'owner_part_key' => nil, 'source' => 'free', 'name' => 'Zámok Abloy',
      'unit' => 'ks', 'price_eur_vat' => 12.5, 'qty' => 1, 'note' => '' }.merge(over)
  end

  def norm(raw, **kw)
    CB.norm_hardware_manual(raw, **kw)
  end

  # Sada setov s JEDNYM clenom kodu KOVH-A — na dokaz ZLIATIA ad-hoc polozky
  # so setovym riadkom rovnakeho kodu.
  def state
    set = HS.normalize_sets([{ 'set_id' => 'zaves', 'generic_type' => 'hinge',
                               'members' => [{ 'code' => 'KOVH-A', 'per' => 'unit', 'qty' => 1 }] }]).first
    { 'mapping' => { 'hinge' => 'zaves' }, 'sets' => { 'zaves' => set } }
  end

  def hw_item(over = {})
    { 'owner_id' => 'CAB-001', 'owner_part_key' => nil, 'generic_type' => 'hinge',
      'quantity' => 2, 'rule_id' => 'zavesy-podla-vysky', 'source' => 'rule',
      'params' => {} }.merge(over)
  end

  def catalog_list
    CAT.items
  end

  # Ad-hoc polozky tak, ako ich vidi expanzia (po zbere).
  def collected_manual(items, owner_id: 'CAB-001', nested: {})
    E::Bom.manual_items_for(owner_id, 11, items, nested)
  end

  def expand(items, manual, over = {})
    HS.expand(items, state, catalog: catalog_list, manual_items: manual, **over)
  end

  def row(exp, code)
    Array(exp['rows']).find { |r| r['code'].to_s == code.to_s }
  end

  def free_row(exp, name)
    Array(exp['rows']).find { |r| r['free'] == true && r['name_sk'].to_s == name }
  end

  def src(file)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', file), encoding: 'UTF-8')
  end

  # --- harness exportov (vzor `test_p0hf_brany.rb`) -------------------------
  #
  # Zamerne VLASTNA kopia: testovacie subory sa nacitavaju v abecednom poradi
  # a spoliehat sa na helper z INEHO suboru by z poradia urobilo skryty kontrakt.
  PC = E::ProductionCore
  SC = PC.singleton_class

  def with_stubs(overrides)
    names = overrides.keys
    names.each do |name|
      SC.send(:alias_method, :"kovh1_orig_#{name}", name)
      SC.send(:define_method, name, &overrides[name])
    end
    yield
  ensure
    names.each do |name|
      SC.send(:remove_method, name)
      SC.send(:alias_method, name, :"kovh1_orig_#{name}")
      SC.send(:remove_method, :"kovh1_orig_#{name}")
    end
  end

  # Fake `UI` LEN na cas testu. POCITA volania `savepanel` — brana ma export
  # zastavit PRED nim, takze „picker sa ani neotvoril" je sucast dokazu.
  def with_ui(target, calls)
    ui = Module.new
    ui.define_singleton_method(:savepanel) do |_t, _d, _n|
      calls << :savepanel
      target
    end
    ui.define_singleton_method(:select_directory) do |**_kw|
      calls << :select_directory
      target
    end
    Object.const_set(:UI, ui)
    yield
  ensure
    Object.send(:remove_const, :UI) if Object.const_defined?(:UI, false)
  end

  # Zber s JEDNOU skrinkou z NOVSEJ verzie + jeden nakupny riadok, aby brana
  # nemerala prazdno („niet co exportovat" je iny dovod nez blokada).
  def newer_collected(newer = ['CAB-004'])
    { records: [], hardware: [], hardware_overrides: [], cabinet_sets: {},
      cabinet_set_conflicts: {}, placements: [], warnings: [], identities: [],
      hardware_manual: [], newer_configs: newer }
  end

  def export_stubs(collected, rows: [{ 'code' => 'KOVH-A', 'quantity' => 2, 'sources' => [] }])
    exp = { 'rows' => rows, 'unmapped' => [] }
    budget = { 'totals' => { 'total' => 100.0, 'unknown_count_in_total' => 0 },
               'cp_preview' => { 'total' => 100.0, 'rows' => [], 'assembly' => 10.0,
                                 'assembly_negative' => false, 'consistent' => true, 'diff' => 0.0 } }
    { refresh_vepo_settings: ->(*_a) {}, vepo_settings: ->(*_a) { {} },
      save_vepo_settings: ->(*_a) { true }, project_name: ->(*_a) { 'Test' },
      fresh_collect: ->(*_a) { collected }, sheets_map: ->(*_a) { {} },
      hardware_expansion: ->(*_a) { exp }, budget_payload: ->(*_a) { budget } }
  end

  # -> [status, chyba?, subory v priecinku, volania pickera]
  def run_export(method, collected, file_name, rows: nil)
    msg = nil
    err = nil
    calls = []
    files = nil
    stubs = rows.nil? ? export_stubs(collected) : export_stubs(collected, rows: rows)
    Dir.mktmpdir('nx-kovh1-') do |dir|
      with_stubs(stubs) do
        with_ui(File.join(dir, file_name), calls) do
          PC.send(method, :model, { 'gen' => 1 }, generation: 1,
                                  status: ->(m, e = false) { msg = m; err = e },
                                  repush: -> {})
        end
      end
      files = Dir.children(dir).sort
    end
    [msg, err, files, calls]
  end
end

# =============================================================================
# 1. KONTRAKT CONFIGU — normalizacia
# =============================================================================

NxTest.test('KOV-H1: whitelist — do configu sa dostanu LEN zname polia polozky') do
  NxKovh1.catalog_ready!
  out = NxKovh1.norm([NxKovh1.cat_item('cudzie_pole' => 'x', 'price_eur_vat' => 99.0)])
  NxTest.assert_equal(1, out.length)
  NxTest.assert_equal([], out.first.keys - Noxun::Engine::CabinetBuilder::MANUAL_KEYS,
                      "cudzie kluce sa do configu nedostanu: #{out.first.keys.inspect}")
  # B2/FIX 12: cena sa pri KATALOGOVEJ polozke NEUKLADA NIKDY — oceni ju zivy
  # katalog. Ulozeny snapshot ceny je presne ta pasca, pre ktoru padol povodny
  # navrh (dve ceny na jednom nakupnom riadku).
  NxTest.refute(out.first.key?('price_eur_vat'),
                "katalogova polozka cenu NEUKLADA: #{out.first.inspect}")
end

NxTest.test('KOV-H1 (FIX 12): nazov a MJ katalogovej polozky dopĺňa SERVER, nie klient') do
  NxKovh1.catalog_ready!
  out = NxKovh1.norm([NxKovh1.cat_item('name' => 'PODVRHNUTY NAZOV', 'unit' => 'bal')])
  NxTest.assert_equal('Záves Clip Top 110°', out.first['name'], 'nazov z katalogu, nie z payloadu')
  NxTest.assert_equal('ks', out.first['unit'], 'MJ z katalogu, nie z payloadu')
end

NxTest.test('KOV-H1: mnozstvo je CELE cislo 1..999 — inak polozka vypadne') do
  NxKovh1.catalog_ready!
  [0, -1, 1000, 2.5, 'dva', nil, ''].each do |bad|
    NxTest.assert_equal([], NxKovh1.norm([NxKovh1.cat_item('qty' => bad)]),
                        "qty #{bad.inspect} sa nesmie dostat do configu")
  end
  NxTest.assert_equal(1, NxKovh1.norm([NxKovh1.cat_item('qty' => '3')]).first['qty'] && 1)
  NxTest.assert_equal(3, NxKovh1.norm([NxKovh1.cat_item('qty' => '3')]).first['qty'],
                      'ciselny retazec je platny vstup (CEF posiela stringy)')
  NxTest.assert_equal(999, NxKovh1.norm([NxKovh1.cat_item('qty' => 999)]).first['qty'])
end

NxTest.test('KOV-H1: neznamy zdroj a neplatna MJ = polozka vypadne (ziadny tichy default)') do
  NxKovh1.catalog_ready!
  NxTest.assert_equal([], NxKovh1.norm([NxKovh1.cat_item('source' => 'manual')]),
                      "'manual' je D-93 znamienko, NIE ad-hoc zdroj (FIX 7)")
  NxTest.assert_equal([], NxKovh1.norm([NxKovh1.cat_item('source' => 'buduci_zdroj')]),
                      'zdroj z novsej verzie sa nepreklopi na tichy fallback')
  NxTest.assert_equal([], NxKovh1.norm([NxKovh1.free_item('unit' => 'kus')]),
                      'MJ mimo HardwareCatalog::UNITS = odmietnutie, NIKDY tiche „ks“')
  NxTest.assert_equal([], NxKovh1.norm([NxKovh1.free_item('name' => '  ')]),
                      'volna polozka bez nazvu je neobjednatelna')
end

NxTest.test('KOV-H1: volna polozka — cena Float >= 0 alebo nil, kod VZDY prazdny') do
  NxKovh1.catalog_ready!
  with = NxKovh1.norm([NxKovh1.free_item]).first
  NxTest.assert_equal(12.5, with['price_eur_vat'])
  NxTest.assert_equal('', with['code'], 'volna polozka sa NESMIE tvarit ako katalogovy kod')

  without = NxKovh1.norm([NxKovh1.free_item('price_eur_vat' => nil)]).first
  NxTest.refute(without.key?('price_eur_vat'), 'nezadana cena = kluc chyba (NIKDY 0)')

  no_key = NxKovh1.free_item
  no_key.delete('price_eur_vat')
  NxTest.refute(NxKovh1.norm([no_key]).first.key?('price_eur_vat'), 'chybajuci kluc = bez ceny')

  [-1.0, 'abc'].each do |bad|
    NxTest.assert_equal([], NxKovh1.norm([NxKovh1.free_item('price_eur_vat' => bad)]),
                        "cena #{bad.inspect} je chyba vstupu, nie hodnota na opravu")
  end
  # Kod poslany klientom sa pri volnej polozke IGNORUJE (inak by sa zliala
  # s katalogovym riadkom a dostala cudziu cenu).
  NxTest.assert_equal('', NxKovh1.norm([NxKovh1.free_item('code' => 'KOVH-A')]).first['code'])
end

NxTest.test('KOV-H1: poznamka sa oreze na 200 znakov') do
  NxKovh1.catalog_ready!
  out = NxKovh1.norm([NxKovh1.cat_item('note' => 'x' * 500)]).first
  NxTest.assert_equal(200, out['note'].length)
end

NxTest.test('KOV-H1 (FIX 10): ID sa DOPLNA len ked chyba alebo koliduje — existujuce sa NEMENI') do
  NxKovh1.catalog_ready!
  out = NxKovh1.norm([NxKovh1.cat_item('id' => 'MOJE'),
                      NxKovh1.cat_item('id' => ''),
                      NxKovh1.cat_item('id' => 'MOJE')]) # kolizia s prvou
  NxTest.assert_equal('MOJE', out[0]['id'], 'PRVY vyskyt si svoje ID drzi')
  NxTest.refute(out[1]['id'].to_s.empty?, 'chybajuce ID sa doplni')
  NxTest.refute(out[2]['id'] == 'MOJE', 'kolidujuce ID dostane nove')
  NxTest.assert_equal(3, out.map { |i| i['id'] }.uniq.length, 'ID su v skrinke unikatne')
  # ID je bezpecny SEGMENT — vstupuje do kluca nakupneho riadku.
  NxTest.assert_equal('a_b', NxKovh1.norm([NxKovh1.cat_item('id' => 'a/b')]).first['id'])
end

NxTest.test('KOV-H1 (FIX 10): `rekey_hardware_manual` meni ID LEN ked ho niekto zavola') do
  NxKovh1.catalog_ready!
  items = NxKovh1.norm([NxKovh1.cat_item('id' => 'H1'), NxKovh1.free_item('id' => 'H2')])
  again = NxKovh1.norm(items)
  NxTest.assert_equal(%w[H1 H2], again.map { |i| i['id'] },
                      'normalize (rebuild) ID NIKDY neprekluckuje')

  params = { 'hardware_manual' => items }
  Noxun::Engine::CabinetBuilder.rekey_hardware_manual(params)
  fresh = params['hardware_manual']
  NxTest.refute(fresh.map { |i| i['id'] }.include?('H1'), 'kopia dostane VLASTNU identitu')
  NxTest.assert_equal(2, fresh.map { |i| i['id'] }.uniq.length)
  NxTest.assert_equal(items.map { |i| i['name'] }, fresh.map { |i| i['name'] },
                      'obsah polozky sa pri prekluceni NEMENI')
  NxTest.assert_equal(%w[H1 H2], items.map { |i| i['id'] }, 'zdroj ostal nedotknuty (kopia poli)')

  # A `normalize` `rekey` NEVOLA — inak by kazda prestavba menila identitu.
  NxTest.refute(NxKovh1.src('core/cabinet_builder.rb')[/def normalize\(params\).*?^        end/m]
                  .to_s.include?('rekey_hardware_manual'),
                '`normalize` nesmie prekluckovat ID (mutacia 4)')
end

# =============================================================================
# 2. STRIKTNY VLASTNIK (B4)
# =============================================================================

NxTest.test('KOV-H1 (B4): vlastnik sa kontroluje STRIKTNE len pri ADD/EDIT') do
  NxKovh1.catalog_ready!
  dead = NxKovh1.cat_item('owner_part_key' => 'front:F9/panel')
  keys = ['front:F1/wing:single']

  # CITACIA cesta (rebuild): kluc sa NIKDY nezahadzuje — dielec mohol zaniknut
  # a polozka ma ostat v objednavke (nalez je ORANGE, nie tiche mazanie).
  kept = NxKovh1.norm([dead])
  NxTest.assert_equal('front:F9/panel', kept.first['owner_part_key'])
  NxTest.assert_equal('front:F9/panel',
                      NxKovh1.norm([dead], strict_owners: false, plan_keys: keys).first['owner_part_key'])

  # ZAPISOVA cesta: odmietnutie CELEJ zmeny, ziadny tichy drop.
  err = nil
  begin
    NxKovh1.norm([dead], strict_owners: true, plan_keys: keys)
  rescue Noxun::Engine::CabinetBuilder::ManualRejected => e
    err = e.message
  end
  NxTest.assert(err.to_s.include?('front:F9/panel'), "hlaska menuje dielec: #{err.inspect}")

  live = NxKovh1.cat_item('owner_part_key' => 'front:F1/wing:single')
  NxTest.assert_equal(1, NxKovh1.norm([live], strict_owners: true, plan_keys: keys).length,
                      'zivy dielec prejde')
  NxTest.assert_equal(1, NxKovh1.norm([NxKovh1.cat_item], strict_owners: true, plan_keys: keys).length,
                      'polozka BEZ vlastnika (patri skrinke) prejde vzdy')
end

NxTest.test('KOV-H1 (B4/FIX 12): kod mimo katalogu — ADD odmietne, rebuild zachova SNAPSHOT') do
  NxKovh1.catalog_ready!
  gone = NxKovh1.cat_item('code' => 'ZMIZNUTY', 'name' => 'Starý kód', 'unit' => 'ks')

  err = nil
  begin
    NxKovh1.norm([gone], strict_owners: true, plan_keys: [])
  rescue Noxun::Engine::CabinetBuilder::ManualRejected => e
    err = e.message
  end
  NxTest.assert(err.to_s.include?('ZMIZNUTY') && err.to_s.include?('voľnú'),
                "pri pridani sa odmietne a poradi volnu polozku: #{err.inspect}")

  kept = NxKovh1.norm([gone]).first
  NxTest.assert_equal('Starý kód', kept['name'], 'rebuild drzi snapshot nazvu')
  NxTest.assert_equal('ks', kept['unit'])
  NxTest.refute(kept.key?('price_eur_vat'), 'ani vtedy sa cena neuklada')
end

# --- review #283 P2-A: PRISNE LEN NOVE A ZMENENE ----------------------------
#
# Panel posiela v KAZDOM `collectAll()` cely ulozeny zoznam (echo, nie diff).
# Keby sa prisne kontroloval CELY, po zmiznuti kodu z katalogu by neprešla
# ziadna dalsia editacia skrinky a zmazanie cela-vlastnika by sa odmietlo
# namiesto toho, aby polozka prezila ako `owner_missing` (BLOCKER 4).

NxTest.test('KOV-H1 (P2-A): `manual_strict_subset` — prisne LEN nove a REALNE zmenene zaznamy') do
  NxKovh1.catalog_ready!
  cb = Noxun::Engine::CabinetBuilder
  stored = NxKovh1.norm([NxKovh1.cat_item('id' => 'H1'), NxKovh1.free_item('id' => 'H2')])

  NxTest.assert_equal([], cb.manual_strict_subset(stored, stored),
                      'nezmenene echo nema co kontrolovat prisne')
  # Ciselny retazec z CEF nie je zmena — porovnava sa NORMALIZOVANA hodnota.
  echo = stored.map { |i| i.merge('qty' => i['qty'].to_s) }
  NxTest.assert_equal([], cb.manual_strict_subset(stored, echo), '„2“ a 2 nie je zmena')

  edited = stored.map { |i| i['id'] == 'H1' ? i.merge('qty' => 5) : i }
  NxTest.assert_equal(['H1'], cb.manual_strict_subset(stored, edited), 'zmeneny pocet = prisne')
  moved = stored.map { |i| i['id'] == 'H2' ? i.merge('owner_part_key' => 'front:F1/wing:single') : i }
  NxTest.assert_equal(['H2'], cb.manual_strict_subset(stored, moved), 'zmeneny vlastnik = prisne')
  renamed = stored.map { |i| i['id'] == 'H2' ? i.merge('name' => 'Iný zámok') : i }
  NxTest.assert_equal(['H2'], cb.manual_strict_subset(stored, renamed),
                      'nazov VOLNEJ polozky je udaj pouzivatela — zmena = prisne')

  # ...ale nazov KATALOGOVEJ polozky vlastni server: premenovanie v katalogu
  # nesmie z nezmenenej polozky spravit „upravenu" (a zablokovat editaciu).
  cat_renamed = stored.map { |i| i['id'] == 'H1' ? i.merge('name' => 'Iný názov z katalógu') : i }
  NxTest.assert_equal([], cb.manual_strict_subset(stored, cat_renamed),
                      'nazov katalogovej polozky do odtlacku NEPATRI')

  added = stored + [NxKovh1.free_item('id' => 'H3', 'name' => 'Nová')]
  NxTest.assert_equal(['H3'], cb.manual_strict_subset(stored, added), 'nova polozka = prisne')
  dup = stored + [stored.first.dup]
  NxTest.assert_equal(['H1'], cb.manual_strict_subset(stored, dup),
                      'duplicitne ID = realne NOVA polozka, teda prisne')
  NxTest.assert_equal([], cb.manual_strict_subset(stored, [NxKovh1.free_item('id' => '')]),
                      'zaznam BEZ ID sa do zoznamu nedava — prisny je uz z definicie')
end

NxTest.test('KOV-H1 (P2-A): nezmenena polozka prejde aj ked jej kod z katalogu ZMIZOL') do
  NxKovh1.catalog_ready!
  gone = NxKovh1.norm([NxKovh1.cat_item('code' => 'ZMIZNUTY', 'name' => 'Starý kód', 'unit' => 'ks')])
  NxTest.assert_equal(1, gone.length, 'predpoklad: polozka je v ulozenom configu')

  # Bez zuzenia by tu padla vynimka a KAZDA dalsia editacia skrinky by zlyhala.
  out = NxKovh1.norm(gone, strict_owners: true, strict_ids: [], plan_keys: [])
  NxTest.assert_equal(1, out.length, 'nezmenene echo prejde tolerantnou cestou')
  NxTest.assert_equal('Starý kód', out.first['name'], 'a drzi snapshot')

  # Ta ista polozka ako NOVA (alebo prave zmenena) sa odmieta dalej.
  err = nil
  begin
    NxKovh1.norm(gone, strict_owners: true, strict_ids: gone.map { |i| i['id'] }, plan_keys: [])
  rescue Noxun::Engine::CabinetBuilder::ManualRejected => e
    err = e.message
  end
  NxTest.assert(err.to_s.include?('ZMIZNUTY'), "zmenena polozka sa kontroluje prisne: #{err.inspect}")
end

NxTest.test('KOV-H1 (P2-A): mrtvy vlastnik NEBLOKUJE zmenu, ked sa polozka nemenila') do
  NxKovh1.catalog_ready!
  owner = 'front:F1/wing:single'
  stored = NxKovh1.norm([NxKovh1.free_item('owner_part_key' => owner)])

  # Zmazanie cela: kluc uz v plane NIE JE, ale polozka sa nemenila -> prejde
  # a kluc si ZACHOVA (`Bom.collect` z neho spravi `owner_missing`).
  out = NxKovh1.norm(stored, strict_owners: true, strict_ids: [], plan_keys: [])
  NxTest.assert_equal(1, out.length, 'zmazanie cela-vlastnika zmenu NEODMIETA')
  NxTest.assert_equal(owner, out.first['owner_part_key'], 'kluc sa NIKDY nezahadzuje')

  # Nova polozka na mrtvom dielci sa odmieta aj nadalej.
  err = nil
  begin
    NxKovh1.norm([NxKovh1.free_item('id' => 'H9', 'owner_part_key' => owner)],
                 strict_owners: true, strict_ids: ['H9'], plan_keys: [])
  rescue Noxun::Engine::CabinetBuilder::ManualRejected => e
    err = e.message
  end
  NxTest.assert(err.to_s.include?(owner), "nova polozka na mrtvom dielci sa odmieta: #{err.inspect}")
end

NxTest.test('KOV-H1 (P2-A): panelova cesta posiela ZUZENY zoznam, nie cely') do
  src = NxKovh1.src('ui/panel/actions_cabinet.rb')
  NxTest.assert(src.include?("strict_ids = CabinetBuilder.manual_strict_subset(params['hardware_manual'], raw)"),
                'preflight porovnava odoslany zoznam s ULOZENYM')
  NxTest.assert(src.index('manual_strict_subset') < src.index("params['hardware_manual'] = raw"),
                'a robi to PRED prepisom ulozeneho zoznamu (inak by porovnaval sam so sebou)')
  NxTest.assert(src.include?('strict_ids: strict_ids'), 'a zuzenie naozaj odovzdava')
end

# =============================================================================
# 3. ROUND-TRIP STYROCH CIEST + CONFIG_SCHEMA
# =============================================================================

NxTest.test('KOV-H1 (B1): pole prezije normalize -> cabinet_config -> config_to_params') do
  NxKovh1.catalog_ready!
  cb = Noxun::Engine::CabinetBuilder
  items = [NxKovh1.cat_item, NxKovh1.free_item]
  cfg = cb.normalize(NxKovh1.base('hardware_manual' => items))
  NxTest.assert_equal(2, cfg[:hardware_manual].length, 'normalize pole pozna')

  stored = cb.cabinet_config(cfg)
  NxTest.assert_equal(2, stored[:hardware_manual].length, 'cabinet_config ho uklada')
  NxTest.assert_equal(cb::CONFIG_SCHEMA, stored[:config_schema])

  # Cez JSON round-trip (tak, ako to prezije .skp) a spat do params.
  json = JSON.parse(JSON.generate(stored))
  params = cb.config_to_params(json)
  NxTest.assert_equal(2, params['hardware_manual'].length,
                      'config_to_params pole prenasa (mutacia 1)')
  back = cb.normalize(params)
  NxTest.assert_equal(items.map { |i| i['id'] }, back[:hardware_manual].map { |i| i['id'] },
                      'ID prezili cely round-trip nezmenene')
  NxTest.assert_equal(12.5, back[:hardware_manual].last['price_eur_vat'],
                      'cena VOLNEJ polozky prezila')
end

NxTest.test('KOV-H1: polozky cestuju SO SABLONOU; legacy sablona ich cielu NEZMAZE') do
  NxKovh1.catalog_ready!
  cb = Noxun::Engine::CabinetBuilder
  cfg = JSON.parse(JSON.generate(cb.cabinet_config(
                                   cb.normalize(NxKovh1.base('hardware_manual' => [NxKovh1.free_item]))
                                 )))
  tc = Noxun::Engine::Panel.template_config_from(cfg)
  NxTest.assert_equal(1, tc['hardware_manual'].length, 'sablonovy whitelist pole nesie')
  NxTest.assert_equal('Zámok Abloy', tc['hardware_manual'].first['name'])

  # `merge_template` je vzor D-13: kluc, ktory sablona NEMA, sa berie z CIELA.
  src = NxKovh1.src('ui/templates_dialog.rb')
  NxTest.assert(src.include?("merged['hardware_manual'] = target_params['hardware_manual'] " \
                             "unless tpl_config.key?('hardware_manual')"),
                'legacy sablona (bez kluca) nesmie polozky ciela zmazat')
end

NxTest.test('KOV-H1 (R-12): CONFIG_SCHEMA je >= 3 a sada R-12 ostava zelena') do
  cb = Noxun::Engine::CabinetBuilder
  NxTest.assert(cb::CONFIG_SCHEMA >= 3, "schema configu #{cb::CONFIG_SCHEMA} < 3")
  NxTest.assert(cb.newer_config?('config_schema' => cb::CONFIG_SCHEMA + 1))
  NxTest.refute(cb.newer_config?('config_schema' => cb::CONFIG_SCHEMA))
  NxTest.refute(cb.newer_config?({}), 'legacy config (0) NIKDY neblokuje')
end

# =============================================================================
# 4. JS PASS-THROUGH GUARD (bez defaultov)
# =============================================================================

NxTest.test('KOV-H1 (FIX 9): JS posiela `hardware_manual` LEN ako echo — ziadny `|| []`') do
  form = NxKovh1.src('ui/js/form.js')
  NxTest.assert(form.include?('if (hwManual) c.hardware_manual = hwManual;'),
                'collectAll posiela kluc len ked ho payload mal')
  NxTest.refute(form.match?(/hardware_manual\s*=\s*[^;]*\|\|\s*\[\]/),
                'ziadny default, ktory by kluc MATERIALIZOVAL')

  bridge = NxKovh1.src('ui/js/bridge.js')
  NxTest.assert(bridge.include?('hwManual = Array.isArray(c.hardware_manual) ? c.hardware_manual : null;'),
                'payload bez kluca = null (nie prazdne pole)')
  NxTest.assert(bridge.scan('hwManual = null;').length >= 2,
                'odchod z korpusu pamat vycisti (doska aj prazdny vyber)')

  ins = NxKovh1.src('ui/js/insert_state.js')
  NxTest.assert(ins.include?("var HARDWARE_LIST_KEYS = ['hardware_manual'];"),
                'polove kluce kovania maju vlastny zoznam (plainMap vracia pre pole null)')
  NxTest.refute(ins.match?(/hardware_manual\s*:\s*\[\]/), 'ziadny prazdny default v insert stave')

  act = NxKovh1.src('ui/js/actions.js')
  NxTest.assert(act.include?('delete p.hardware_manual;'),
                'vklad nesmie zdedit polozky OZNACENEJ skrinky')
  NxTest.assert(act.include?('NXInsert.HARDWARE_LIST_KEYS.forEach'),
                'polozky sablony sa do insert payloadu prenasaju')
end

# =============================================================================
# 5. R-12 EXPORTNA BRANA (B3)
# =============================================================================

NxTest.test('KOV-H1/GHOST-D1 (B3): `newer_configs` zastavi VSETKY STYRI exporty (aj VEPO)') do
  pc = Noxun::Engine::ProductionCore
  NxTest.assert_equal([], pc.export_blockers, 'cista zakazka nema dovod')
  NxTest.assert_equal([], pc.export_blockers(newer: []))

  b = pc.export_blockers(newer: %w[CAB-004 CAB-007])
  NxTest.assert_equal(1, b.length, b.inspect)
  NxTest.assert(b.first.include?('CAB-004') && b.first.include?('CAB-007'), b.first)
  NxTest.assert(b.first.include?('aktualizuj plugin'), "kam ist: #{b.first}")

  many = pc.export_blockers(newer: %w[A B C D E])
  NxTest.assert(many.first.include?('a ďalšie 2'), "strop na tri ID: #{many.first}")

  # Hlaska TVRDEJ brany hovori, ze subor NEVZNIKOL.
  NxTest.assert(pc.export_blocked_status(b).include?('nevytvoril'))

  # GHOST-D1: druh objektu je v hlaske — „Skrinka" vs. „Doska".
  NxTest.assert(b.first.include?('Skrinka CAB-004'), "druh pred ID: #{b.first}")
  bd = pc.export_blockers(newer: [{ 'kind' => 'board', 'id' => 'BRD-002' }])
  NxTest.assert(bd.first.include?('Doska BRD-002'), "doska je pomenovana ako doska: #{bd.first}")
  NxTest.assert(bd.first.include?('VEPO'), "zoznam blokovanych vystupov je uplny: #{bd.first}")

  # GHOST-D1: branu vola PRAVE STYRI exporty (VEPO uz vynimku nema) a PRAVE
  # cez jedno miesto (`newer_config_stop`), aby sa nedala v jednom zabudnut.
  src = NxKovh1.src('ui/production_core.rb')
  NxTest.assert_equal(4, src.scan('newer_stop = newer_config_stop(collected)').length,
                      'styri exporty: VEPO, nakupny CSV, rozpocet XLSX, ponuka XLSX')
  NxTest.assert_equal(1, src.scan('newer: newer_configs(collected)').length,
                      'jedine miesto, kde sa `newer:` sklada — `newer_config_stop`')
end

NxTest.test('KOV-H1 (B3): `Bom.collect` nesie ID skriniek z NOVSEJ verzie (aditivny kluc)') do
  # `collect` vyzaduje SketchUp; overuje sa zdrojova cesta + `Validation` nad
  # tym istym klucom (in-SU sekcia `run_kovh1` to skusa nad zivym modelom).
  bom = NxKovh1.src('core/bom.rb')
  # GHOST-D1: zaznam nesie DRUH, zapisuje ho jeden helper (skrinka aj doska).
  NxTest.assert(bom.include?("note_newer_config(newer_configs, 'cabinet', *newer_address(inst, cid))"),
                'zber kluc plni pre skrinku')
  NxTest.assert(bom.include?("note_newer_config(newer_configs, 'board', *newer_address(inst, bid))"),
                'a pre dosku')
  NxTest.assert(bom.include?('newer_configs: newer_configs'), 'a vracia ho')

  items = []
  Noxun::Engine::Validation.check_newer_configs(%w[CAB-004 CAB-004b], items)
  NxTest.assert_equal(2, items.length)
  NxTest.assert_equal('red', items.first['severity'], 'novsia schema je RED')
  NxTest.assert_equal('newer_config', items.first['category'])
  NxTest.assert(items.first['message_sk'].start_with?('Skrinka CAB-004'), 'legacy String = skrinka')
  NxTest.assert(items.first['message_sk'].include?('aktualizuj plugin'))
  NxTest.assert_equal([], [].tap { |o| Noxun::Engine::Validation.check_newer_configs(nil, o) },
                      'chybajuci kluc (legacy volanie) = ziadny nalez')
end

NxTest.test('KOV-H1 (B3): pri novsej scheme SUBOR NEVZNIKNE — cielovy priecinok ostane prazdny') do
  NxTest.skip!('exportne testy bezia len headless (fake UI)') unless NxTest.headless?
  { do_hw_csv: 'kovanie.csv', do_budget_xlsx: 'rozpocet.xlsx', do_cp_xlsx: 'ponuka.xlsx' }
    .each do |method, name|
    msg, err, files, calls = NxKovh1.run_export(method, NxKovh1.newer_collected, name)
    NxTest.assert_equal([], files, "#{method}: neuplny vystup nesmie vzniknut")
    NxTest.assert_equal([], calls, "#{method}: picker sa ani neotvoril")
    NxTest.assert(err, "#{method}: status je cerveny")
    NxTest.assert(msg.include?('CAB-004'), "#{method}: hlaska menuje skrinku — #{msg}")
    NxTest.assert(msg.include?('nevytvoril'), "#{method}: a hovori, ze subor NEVZNIKOL — #{msg}")
  end
end

NxTest.test('KOV-H1 (review #283 P2-B): brana padne aj ked zakazka NEEXPANDUJE ani jeden riadok') do
  NxTest.skip!('exportne testy bezia len headless (fake UI)') unless NxTest.headless?
  # Skrinka z novsej verzie nemusi dat ani jeden ZNAMY nakupny riadok. Skory
  # navrat „model nema kovanie" ju predtym prekryl a pouzivatel sa nedozvedel
  # ani ID skriniek, ani to, ze ma aktualizovat plugin.
  { do_hw_csv: 'kovanie.csv', do_budget_xlsx: 'rozpocet.xlsx', do_cp_xlsx: 'ponuka.xlsx' }
    .each do |method, name|
    msg, err, files, calls = NxKovh1.run_export(method, NxKovh1.newer_collected, name, rows: [])
    NxTest.assert_equal([], files, "#{method}: subor nesmie vzniknut")
    NxTest.assert_equal([], calls, "#{method}: picker sa ani neotvoril")
    NxTest.assert(err, "#{method}: status je cerveny")
    NxTest.assert(msg.include?('CAB-004'), "#{method}: hlaska MENUJE skrinku — #{msg}")
    NxTest.assert(msg.include?('aktualizuj plugin'), "#{method}: a hovori, co s tym — #{msg}")
    NxTest.refute(msg.include?('niet čo exportovať'),
                  "#{method}: skory navrat branu uz NEPREDBIEHA — #{msg}")
  end
end

NxTest.test('KOV-H1 (B3): bez novsej schemy tie iste exporty prebehnu (brana nemeri prazdno)') do
  NxTest.skip!('exportne testy bezia len headless (fake UI)') unless NxTest.headless?
  _msg, err, files, calls = NxKovh1.run_export(:do_hw_csv, NxKovh1.newer_collected([]), 'kovanie.csv')
  NxTest.assert_equal(['kovanie.csv'], files, 'platny vystup sa brat nesmie')
  NxTest.assert_equal([:savepanel], calls)
  NxTest.refute(err)
end

# =============================================================================
# 6. EXPANZIA
# =============================================================================

NxTest.test('KOV-H1 (B2): katalogova ad-hoc polozka sa ZLIEVA so setovym riadkom — jedna cena') do
  NxKovh1.catalog_ready!
  manual = NxKovh1.collected_manual(NxKovh1.norm([NxKovh1.cat_item('qty' => 3)]))
  exp = NxKovh1.expand([NxKovh1.hw_item], manual)
  r = NxKovh1.row(exp, 'KOVH-A')
  NxTest.assert_equal(5, r['quantity'], '2 zo setu + 3 rucne = jeden riadok')
  NxTest.assert_equal(3.42, r['price_eur_vat'], 'ZIVA cena katalogu (nie snapshot)')
  NxTest.assert_equal(17.1, r['subtotal_eur_vat'], '5 x 3,42')
  NxTest.assert_equal(3, r['adhoc_quantity'], 'riadok prizna, kolko z neho je rucne')
  NxTest.assert_equal(r['quantity'], r['sources'].sum { |s| s['quantity'].to_i },
                      'invariant: Σ zdrojov = mnozstvo riadku')
  adhoc = r['sources'].find { |s| s['origin'] == 'adhoc' }
  NxTest.assert(adhoc, 'ad-hoc zdroj je rozpoznatelny podla `origin`')
  NxTest.assert_equal([nil, nil, nil], [adhoc['generic_type'], adhoc['rule_id'], adhoc['set_id']],
                      'ad-hoc polozka ZIADNY set ani pravidlo nema')
  NxTest.assert_equal('H1', adhoc['manual_id'])
end

NxTest.test('KOV-H1 (FIX 7): ad-hoc kanal NIKDY nejde cez `note_manual` (D-93 sa nedotkne)') do
  NxKovh1.catalog_ready!
  manual = NxKovh1.collected_manual(NxKovh1.norm([NxKovh1.cat_item]))
  r = NxKovh1.row(NxKovh1.expand([NxKovh1.hw_item], manual), 'KOVH-A')
  NxTest.assert_equal(0, r['manual_quantity'], 'ad-hoc sa NEZAPOCITAVA do D-93 (mutacia 3)')
  NxTest.assert_equal(nil, r['manual_note'], 'a nedostane ani D-93 znamienko')

  # D-93 polozka (`source: 'manual'`) sa naopak sprava presne ako doteraz.
  d93 = NxKovh1.hw_item('source' => 'manual', 'quantity' => 1)
  r2 = NxKovh1.row(NxKovh1.expand([d93], manual), 'KOVH-A')
  NxTest.assert_equal(1, r2['manual_quantity'], 'D-93 znamienko ostava nedotknute')
end

NxTest.test('KOV-H1: volna polozka = VLASTNY riadok s cenou zo snapshotu') do
  NxKovh1.catalog_ready!
  items = NxKovh1.norm([NxKovh1.free_item, NxKovh1.free_item('id' => 'H3', 'name' => 'Bez ceny',
                                                             'price_eur_vat' => nil, 'qty' => 2)])
  exp = NxKovh1.expand([NxKovh1.hw_item], NxKovh1.collected_manual(items))
  r = NxKovh1.free_row(exp, 'Zámok Abloy')
  NxTest.assert(r, 'volna polozka ma vlastny riadok')
  NxTest.assert_equal('', r['code'], 'bez kodu — s nicim sa zliat nemoze')
  NxTest.assert_equal('free:CAB-001:H2', r['free_key'])
  NxTest.assert_equal(false, r['missing'], 'volna polozka NIKDY nie je „mimo katalogu“')
  NxTest.assert_equal(12.5, r['subtotal_eur_vat'], 'cena x pocet zo snapshotu')

  bez = NxKovh1.free_row(exp, 'Bez ceny')
  NxTest.assert_equal(nil, bez['price_eur_vat'])
  NxTest.assert_equal(nil, bez['subtotal_eur_vat'], 'neznama cena NIKDY nie je 0 (§11.3)')
  NxTest.assert_equal(2, bez['quantity'])
  NxTest.assert(exp['summary']['unknown_prices'].to_i.positive?, 'suhrn to prizna')

  # Poradie riadkov je DETERMINISTICKE aj ked maju obe volne polozky prazdny kod.
  order = 5.times.map do
    NxKovh1.expand([NxKovh1.hw_item], NxKovh1.collected_manual(items))['rows']
           .map { |x| x['free_key'] || x['code'] }
  end
  NxTest.assert_equal(1, order.uniq.length, "poradie riadkov kolise: #{order.uniq.inspect}")
end

NxTest.test('KOV-H1 (FIX 6): kod, ktory z katalogu ZMIZOL — `catalog_missing`, nie `missing`') do
  NxKovh1.catalog_ready!
  gone = NxKovh1.norm([NxKovh1.cat_item('code' => 'ZMIZNUTY', 'name' => 'Starý kód', 'unit' => 'ks')])
  exp = NxKovh1.expand([], NxKovh1.collected_manual(gone))
  r = NxKovh1.row(exp, 'ZMIZNUTY')
  NxTest.assert_equal(true, r['catalog_missing'])
  NxTest.assert_equal(false, r['missing'], 'riadok MA nazov — v ponuke sa nesmie preskocit')
  NxTest.assert_equal('Starý kód', r['name_sk'], 'nazov zo snapshotu')
  NxTest.assert_equal('ks', r['unit'])
  NxTest.assert_equal(nil, r['price_eur_vat'], 'bez ceny')
  NxTest.assert_equal(nil, r['subtotal_eur_vat'], 'a teda ani medzisucet (mutacia 2)')

  # Setovy riadok bez katalogu sa sprava PRESNE ako doteraz (`missing`).
  set_only = NxKovh1.expand([NxKovh1.hw_item], [])
  NxTest.assert_equal(false, NxKovh1.row(set_only, 'KOVH-A')['missing'])
end

NxTest.test('KOV-H1: pomocny snapshot v riadku nezostava — payload nesie len hotove polia') do
  NxKovh1.catalog_ready!
  exp = NxKovh1.expand([], NxKovh1.collected_manual(NxKovh1.norm([NxKovh1.cat_item])))
  NxTest.refute(NxKovh1.row(exp, 'KOVH-A').key?('adhoc_snapshot'),
                'pomocna zbierka do payloadu nepatri (vzor `manual_auto`)')
end

# =============================================================================
# 7. ZBER, KONTROLA, DUPLICITY
# =============================================================================

NxTest.test('KOV-H1 (B4): `Bom.manual_items_for` prizna MRTVEHO vlastnika, polozku nezahodi') do
  NxKovh1.catalog_ready!
  items = NxKovh1.norm([NxKovh1.cat_item('owner_part_key' => 'front:F1/wing:single'),
                        NxKovh1.cat_item('id' => 'H9', 'owner_part_key' => 'front:F9/panel'),
                        NxKovh1.free_item])
  out = Noxun::Engine::Bom.manual_items_for('CAB-001', 77, items,
                                            { 'front:F1/wing:single' => {} })
  NxTest.assert_equal(3, out.length, 'ziadna polozka sa nestrati')
  NxTest.assert_equal([false, true, false], out.map { |i| i['owner_missing'] },
                      'mrtvy je LEN ten, ktoreho dielec v skrinke nie je')
  NxTest.assert_equal(%w[CAB-001 CAB-001 CAB-001], out.map { |i| i['owner_id'] })
  NxTest.assert_equal(77, out.first['owner_pid'], 'adresa KONKRETNEJ instancie')
  NxTest.assert_equal([], Noxun::Engine::Bom.manual_items_for('CAB-001', 1, nil, {}),
                      'skrinka bez poloziek = prazdno')
end

NxTest.test('KOV-H1: Kontrola — ORANGE „bez vlastnika“ (polozka ostava v nakupe)') do
  items = [{ 'id' => 'H1', 'owner_id' => 'CAB-001', 'owner_pid' => 5, 'owner_missing' => true,
             'owner_part_key' => 'front:F9/panel', 'source' => 'free', 'name' => 'Zámok Abloy' },
           { 'id' => 'H2', 'owner_id' => 'CAB-001', 'owner_missing' => false, 'name' => 'Iná' }]
  out = []
  Noxun::Engine::Validation.check_hardware_manual(items, out)
  NxTest.assert_equal(1, out.length, 'nalez ma LEN mrtvy vlastnik')
  it = out.first
  NxTest.assert_equal('orange', it['severity'])
  NxTest.assert_equal('hardware_adhoc', it['category'])
  NxTest.assert_equal('CAB-001', it['owner_id'])
  NxTest.assert_equal(nil, it['part_key'], 'klik-select mieri na SKRINKU (dielec uz nie je)')
  NxTest.assert(it['message_sk'].include?('Zámok Abloy'), it['message_sk'])
  NxTest.assert(it['message_sk'].include?('ostáva'), "polozka sa NEMAZE: #{it['message_sk']}")
  NxTest.assert_equal([], [].tap { |o| Noxun::Engine::Validation.check_hardware_manual(nil, o) },
                      'chybajuci kluc (legacy volanie) = ziadny nalez')
end

NxTest.test('KOV-H1: Kontrola — kod ad-hoc polozky mimo katalogu menuje RUCNU polozku') do
  NxKovh1.catalog_ready!
  gone = NxKovh1.norm([NxKovh1.cat_item('code' => 'ZMIZNUTY', 'name' => 'Starý kód', 'unit' => 'ks')])
  exp = NxKovh1.expand([], NxKovh1.collected_manual(gone))
  out = []
  Noxun::Engine::Validation.check_hardware_expansion(exp, out)
  NxTest.assert_equal(1, out.length, out.inspect)
  NxTest.assert_equal('orange', out.first['severity'])
  NxTest.assert_equal('hardware_code', out.first['category'], 'ide EXISTUJUCOU ORANGE cestou')
  NxTest.assert(out.first['message_sk'].include?('Ručná položka'), out.first['message_sk'])
  NxTest.assert(out.first['message_sk'].include?('ZMIZNUTY'), out.first['message_sk'])
end

NxTest.test('KOV-H1: ad-hoc zdroje su PER INSTANCIU — dup brana ich len VAROVA') do
  NxKovh1.catalog_ready!
  pc = Noxun::Engine::ProductionCore
  manual = NxKovh1.collected_manual(NxKovh1.norm([NxKovh1.cat_item]))
  exp = NxKovh1.expand([], manual)
  col = { records: [], hardware: [], hardware_overrides: [], cabinet_sets: {},
          cabinet_set_conflicts: {}, placements: [], warnings: [],
          identities: [{ 'kind' => 'cabinet', 'id' => 'CAB-001' }] * 2 }
  blocking, warn = pc.dup_partition(col, exp)
  NxTest.assert_equal([], blocking,
                      'ad-hoc polozky sa neuctuju na vlastnika — cislo objednavky je spravne')
  NxTest.assert_equal([['cabinet', 'CAB-001', 2]], warn, 'ale zliate ID sa prizna')
  NxTest.assert_equal([], pc.export_blockers(dups: blocking), 'export sa nezastavi')
end

# =============================================================================
# 8. ROZPOCET A PONUKA
# =============================================================================

NxTest.test('KOV-H1 (FIX 8): rozpocet nesie povod, volny riadok ma VLASTNY kluc a je mimo stale-scan') do
  NxKovh1.catalog_ready!
  items = NxKovh1.norm([NxKovh1.cat_item('qty' => 3), NxKovh1.free_item,
                        NxKovh1.free_item('id' => 'H3', 'name' => 'Druhá voľná')])
  exp = NxKovh1.expand([NxKovh1.hw_item], NxKovh1.collected_manual(items))
  bud = Noxun::Engine::Budget.compute({ records: [], hardware: [] }, {}, {},
                                      hardware_expansion: exp,
                                      hardware_catalog: NxKovh1.catalog_list)
  rows = bud['sections'].find { |s| s['key'] == 'hardware' }['rows']
  NxTest.assert_equal(rows.length, rows.map { |r| r['key'] }.uniq.length,
                      'kluce riadkov su unikatne (volne by inak mali vsetky `hw:`)')
  cat = rows.find { |r| r['kod'] == 'KOVH-A' }
  NxTest.assert_equal('adhoc', cat['origin'], 'riadok so rucnym prispevkom prizna povod')
  NxTest.assert_equal(17.1, cat['spolu'], 'a ocenuje sa ZIVOU cenou katalogu')
  free = rows.find { |r| r['nazov'] == 'Zámok Abloy' }
  NxTest.assert_equal(true, free['free'])
  NxTest.assert_equal('hw:free:CAB-001:H2', free['key'])
  NxTest.assert_equal(12.5, free['spolu'], 'volna polozka sa do rozpoctu ZAPOCITA')

  stale_ids = Array(bud['stale']['items']).map { |i| i['id'] }
  NxTest.refute(stale_ids.include?(''), 'volne polozky (bez kodu) do stale-scanu nepatria')
end

NxTest.test('KOV-H1: cenova ponuka volny riadok NEPRESKOCI (ma nazov)') do
  NxKovh1.catalog_ready!
  items = NxKovh1.norm([NxKovh1.free_item])
  exp = NxKovh1.expand([NxKovh1.hw_item], NxKovh1.collected_manual(items))
  spec = Noxun::Engine::CpExport.specification([], hardware_expansion: exp)
  labels = spec['categories'].flat_map { |c| c['items'] }
  NxTest.assert(labels.include?('Zámok Abloy'), "volna polozka je v specifikacii: #{labels.inspect}")
end
