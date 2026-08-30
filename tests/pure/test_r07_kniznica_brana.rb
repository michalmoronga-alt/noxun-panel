# frozen_string_literal: true
# Testy 1d/R-07: KOMPATIBILITNA BRANA globalnej kniznice setov kovania.
#
# CO BOLO ZLE: `%APPDATA%\NOXUN\Engine\hardware_sets.json` je GLOBALNY, teda
# zdielaju ho VSETKY verzie pluginu na profile. Starsia verzia subor precitala,
# marker `std` NECITALA, neznamy tvar clena TICHO zahodila — a prvym zapisom
# stratu ZVECNILA (zapis navyse stampoval `std: 1` aj nad obsahom, ktory bez
# novsich tvarov citat NEJDE, takze marker klamal aj dopredu).
#
# CO PLATI TERAZ:
#   * kniznica ma STAV (`library_state`): `:ok` alebo `:read_only` + SK dovod;
#   * brana sa vyhodnocuje ZNOVA a POD ZAMKOM pred KAZDYM zapisom — cachovane
#     `:ok` nie je dokaz (druha instancia mohla subor medzitym nahradit);
#   * read-only kniznica sa NESMIE ani POUZIT: expanzia bez projektoveho
#     snapshotu skonci ORANGE `library_incompatible` a ziadna definicia sa
#     neskopiruje do .skp (`global_default_state` vrati nil);
#   * seed-merge sa nad read-only kniznicou NEROBI (subor ostane nedotknuty
#     a ani vratene data nenesu doplnene default sety);
#   * detektor straty je WHITELIST znamych klucov (nie pocty) a pouziva ho
#     rovnako kniznica aj projektovy snapshot (+ pocet CLENOV per set);
#   * `write` stampuje `std` podla OBSAHU (`snapshot_std`).
#
# PRIZNANE (NOTE 7 auditu): historicky subor so `std: 1` a obsahom, ktory uz
# vyzaduje 2, sa NEOPRAVUJE sam — marker sa povysi az prvym LEGITIMNYM
# zapisom. Bez mutacie sa subor nedotyka (a citat sa da dalej, std 1 je
# podporovana hodnota). Test to vyslovne odlisuje od naozaj plain obsahu.
#
# MIMO ROZSAHU: poskodeny primar s platnou `.bak` (degraded) je R-11 — tato
# davka mu nezavadza, len si necha miesto (dalsi kod dovodu v tej istej matici).
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxR07
  E     = Noxun::Engine
  HWS   = E::HardwareSets
  STORE = E::JsonFileStore
  MAT   = E::Materials
  PC    = E::ProductionCore
  VAL   = E::Validation

  module_function

  # --- sandbox ------------------------------------------------------------

  # Ulozi obsah suboru, spusti blok a vrati PRESNY povodny stav (vzor R-08).
  def with_library
    path = HWS.path
    before = (File.binread(path) if File.exist?(path))
    yield path
  ensure
    if before then File.binwrite(path, before) else FileUtils.rm_f(path) end
    FileUtils.rm_f("#{path}.bak")
    STORE.invalidate(path)
    HWS.reset_library_state!
  end

  # Zapise dokument PRIAMO na disk (obide brany) a zhodi cache aj stav.
  def install(doc)
    FileUtils.mkdir_p(File.dirname(HWS.path))
    File.binwrite(HWS.path, JSON.pretty_generate(doc))
    STORE.invalidate(HWS.path)
    HWS.reset_library_state!
    true
  end

  def raw
    JSON.parse(File.binread(HWS.path))
  end

  # Telo jednej metody zo zdroja (vzor `test_r08_zamky.rb`) — pre kontrakty
  # UI ciest, ktore sa headless zavolat nedaju (`Sketchup.active_model`).
  def method_src(rel, name, indent = 8)
    src = File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel))
              .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
    src[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end

  def bytes
    File.binread(HWS.path)
  end

  # „Druha instancia" zapise do suboru PRESNE RAZ tesne PRED tym, nez si
  # vezmeme zamok — teda do okna medzi nasim citanim a nasim zapisom
  # (vzor `test_r08_zamky.rb`). Cache sa ZAMERNE neinvaliduje: iny OS proces
  # nasu cache tiez nezhodi.
  def with_other_instance(path, payload)
    orig = MAT.method(:with_catalog_lock)
    fired = false
    MAT.define_singleton_method(:with_catalog_lock) do |&blk|
      unless fired
        fired = true
        tmp = "#{path}.tmp-other"
        File.binwrite(tmp, JSON.pretty_generate(payload))
        File.rename(tmp, path)
      end
      orig.call(&blk)
    end
    yield
    fired
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end

  # --- fixtury ------------------------------------------------------------

  def plain_set(sid = 'zaves-a', gt = 'hinge')
    { 'set_id' => sid, 'name' => sid, 'generic_type' => gt,
      'members' => [{ 'code' => 'KOD-1', 'per' => 'unit', 'qty' => 1 }] }
  end

  # Set s PASMAMI clena — obsah, ktory bez std 2 citat NEJDE.
  def bands_set(sid = 'nohy-pasma')
    { 'set_id' => sid, 'name' => sid, 'generic_type' => 'leg',
      'members' => [{ 'per' => 'unit', 'qty' => 1,
                      'param_bands' => { 'param' => 'height',
                                         'bands' => [{ 'min' => 17.0, 'max' => 21.0, 'code' => 'KLZ' }] } }] }
  end

  def doc(sets, mapping = {}, over = {})
    { 'std' => HWS::STD, 'seed_version' => HWS::SEED_VERSION,
      'sets' => sets, 'mapping' => mapping }.merge(over)
  end

  def model_with(state = nil)
    m = NxTest::FakeEntity.new
    m.set_attribute(E::Store::DICT, HWS::MODEL_KEY, state.to_json) if state
    m
  end

  def hinge_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy',
      'params' => {}, 'source' => 'rule' }.merge(over)
  end

  def collected(hardware, cabinet_sets = {})
    { records: [], hardware: hardware, hardware_overrides: [],
      cabinet_sets: cabinet_sets, cabinet_set_conflicts: {},
      placements: [], warnings: [], identities: [] }
  end
end

# --- 1) STD PODLA OBSAHU (bod 7 zadania) ------------------------------------

NxTest.test('R-07 round-trip: obsah s pásmami dostane std 2 a číta sa ako :ok') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set]))
    NxTest.assert(r::HWS.write([r.plain_set, r.bands_set], { 'hinge' => 'zaves-a' }),
                  'zapis nad zdravou kniznicou prejde')
    NxTest.assert_equal(r::HWS::STD_PARAM_FORMS, r.raw['std'],
                        'marker sa stampuje podla OBSAHU, nie konstantou')
    r::STORE.invalidate(r::HWS.path)
    r::HWS.reset_library_state!
    NxTest.assert_equal(:ok, r::HWS.library_state, 'vlastny zapis je vzdy citatelny')
    ids = r::HWS.load['sets'].map { |s| s['set_id'] }.sort
    NxTest.assert_equal(%w[nohy-pasma zaves-a], ids)
  end
end

NxTest.test('R-07: naozaj plain obsah ostáva std 1 (spätná čitateľnosť sa neblokuje)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set]))
    NxTest.assert(r::HWS.write([r.plain_set('zaves-b')], {}))
    NxTest.assert_equal(r::HWS::STD, r.raw['std'], 'bez pasiem a selectora = std 1')
  end
end

NxTest.test('R-07 (NOTE 7): historický std 1 s novým obsahom sa NEOPRAVUJE sám — až prvým zápisom') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    # Presne dnesny stav na disku: marker 1, ale obsah uz vyzaduje 2.
    r.install(r.doc([r.bands_set]))
    before = r.bytes
    NxTest.assert_equal(:ok, r::HWS.library_state, 'std 1 je podporovana hodnota — citame dalej')
    r::HWS.load
    NxTest.assert_equal(before, r.bytes, 'samotne citanie subor NEMENI (ziadna tichá migracia)')
    NxTest.assert(r::HWS.write([r.bands_set], {}), 'prvy legitimny zapis prejde')
    NxTest.assert_equal(r::HWS::STD_PARAM_FORMS, r.raw['std'],
                        'a marker sa pritom povysi PRIRODZENE (prepocet z obsahu)')
  end
end

# --- 2) DOWNGRADE GATE ------------------------------------------------------

NxTest.test('R-07 brána: knižnica z novšej verzie (std 3) je READ-ONLY s dôvodom') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set('cudzi')], {}, 'std' => 3))
    NxTest.assert(r::HWS.library_read_only?, 'novsi marker = read-only')
    NxTest.assert_equal(:newer, r::HWS.library_state_code)
    NxTest.assert(r::HWS.library_state_reason.include?('novšej verzie'),
                  "dovod hovori PRECO: #{r::HWS.library_state_reason.inspect}")
  end
end

NxTest.test('R-07 (FIX 3): nad read-only knižnicou sa seed-merge NEROBÍ — súbor ani dáta') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    # seed_version 0 = seed-merge by INAK dosypal vsetky SEED_SETS a spustil
    # migracie mapovania.
    r.install(r.doc([r.plain_set('cudzi')], {}, 'std' => 3, 'seed_version' => 0))
    before = r.bytes
    lib = r::HWS.load
    # Review P1-1: `load` z nekompatibilnej kniznice nevydá NIC — ani seed
    # (cudzie defaulty), ani orezany obsah suboru (na tom by sa volajuci
    # rozhodovali a prvy zapis by stratu zvecnil).
    NxTest.assert_equal({ 'sets' => [], 'mapping' => {} }, lib,
                        'load vracia PRAZDNO, nie seed ani orezany obsah')
    NxTest.assert_equal(before, r.bytes, 'a subor sa nedotkol (ziadny seed-merge)')
  end
end

NxTest.test('R-07 brána: nad read-only knižnicou sa ODMIETNE každý zápis') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set('cudzi')], { 'hinge' => 'cudzi' }, 'std' => 3))
    before = r.bytes
    NxTest.refute(r::HWS.write([r.plain_set], {}), 'write')
    NxTest.assert_equal(:write_failed, r::HWS.save_set!(r.plain_set)[0], 'save_set!')
    NxTest.assert_equal(:write_failed, r::HWS.delete_set!('cudzi')[0], 'delete_set!')
    NxTest.refute(r::HWS.set_global_mapping!('hinge', 'cudzi'), 'set_global_mapping!')
    NxTest.assert_equal(before, r.bytes, 'súbor novšej verzie ostal BAJT NA BAJT nedotknutý')
  end
end

# --- 3) BLOCKER 2: brána POD ZÁMKOM pred každým zápisom ---------------------

NxTest.test('R-07 (BLOCKER 2): cudzí súbor std 3 podsunutý PRED zámkom náš zápis ZASTAVÍ') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do |path|
    # 1) zdrava kniznica — modul si zapamata `:ok`
    r.install(r.doc([r.plain_set]))
    NxTest.assert_equal(:ok, r::HWS.library_state)
    r::STORE.read(path) # nahriata sekundova cache (stav beziaceho pluginu)

    # 2) druha instancia (novsi plugin) subor nahradi tesne PRED nasim zamkom
    cudzi = r.doc([r.plain_set('od-novsej')], {}, 'std' => 3)
    fired = r.with_other_instance(path, cudzi) do
      status, = r::HWS.save_set!(r.plain_set('nas-novy'))
      NxTest.assert_equal(:write_failed, status,
                          'cachovane :ok NIE JE dokaz — zapis sa odmietne')
    end
    NxTest.assert(fired, 'fixture: druha instancia naozaj zapisala')
    NxTest.assert_equal(3, r.raw['std'], 'subor novsej verzie ostal')
    NxTest.assert_equal(['od-novsej'], r.raw['sets'].map { |s| s['set_id'] },
                        'a nas set sa doN NEdostal')
    NxTest.assert(r::HWS.library_read_only?, 'stav modulu sa pritom OMLADIL na read-only')
  end
end

# --- 4) DETEKTOR STRATY = WHITELIST (FIX 4) ---------------------------------

NxTest.test('R-07 detektor: neznámy kľúč člena/setu = read-only (nie tiché orezanie)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  cases = {
    'neznamy kluc CLENA' => [{ 'code' => 'KOD-1', 'per' => 'unit', 'qty' => 1,
                               'per_length_mm' => 100 }],
    'neznamy kluc PASMA' => [{ 'per' => 'unit', 'qty' => 1,
                               'param_bands' => { 'param' => 'height',
                                                  'bands' => [{ 'min' => 1.0, 'max' => 2.0,
                                                                'code' => 'K', 'ratio' => 4 }] } }]
  }
  cases.each do |what, members|
    r.with_library do
      r.install(r.doc([r.plain_set.merge('members' => members)]))
      NxTest.assert(r::HWS.library_read_only?, "#{what}: kniznica musi byt read-only")
      NxTest.assert_equal(:unknown_shape, r::HWS.library_state_code, what)
    end
  end
  r.with_library do
    r.install(r.doc([r.plain_set.merge('display_order' => 3)]))
    NxTest.assert(r::HWS.library_read_only?, 'neznamy kluc SETU')
  end
  r.with_library do
    r.install(r.doc([r.plain_set('novy-typ', 'flap_stay')]))
    NxTest.assert(r::HWS.library_read_only?, 'neznamy generic_type (typ kovania novsej verzie)')
  end
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => { 'param' => 'front_height',
                                                  'bands' => [{ 'min' => 0.0, 'max' => 9.0,
                                                                'set_id' => 'zaves-a',
                                                                'fallback' => true }] } }))
    NxTest.assert(r::HWS.library_read_only?, 'neznamy kluc SELECTORA mapovania')
  end
end

NxTest.test('R-07 detektor: legacy konverzie hodnôt PREJDÚ (dopĺňaný per/qty, čísla)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    legacy = { 'set_id' => 'legacy', 'name' => 'Legacy', 'generic_type' => 'hinge',
               'members' => [{ 'code' => 104_717 },                       # bez per/qty, kod cislo
                             { 'code' => 'X', 'per' => 'owner', 'qty' => '2' }, # qty string
                             { 'per' => 'unit', 'qty' => 1,
                               'code_by_nl' => { '420' => 357_695 } }] }  # kod radu cislo
    r.install(r.doc([legacy]))
    NxTest.assert_equal(:ok, r::HWS.library_state,
                        'normalizacia hodnot tvar NEMENI — nie je to strata')
    NxTest.assert_equal(3, r::HWS.load['sets'].first['members'].length)
  end
end

# --- 5) PROJEKTOVY SNAPSHOT: pocet CLENOV + ten isty detektor ---------------

NxTest.test('R-07: snapshot, ktorému by normalizácia zahodila ČLENA, je :invalid') do
  r = NxR07
  good = { 'std' => 1, 'mapping' => { 'hinge' => 'zaves-a' },
           'sets' => { 'zaves-a' => r.plain_set } }
  NxTest.assert_equal(:ok, r::HWS.project_state_status(r.model_with(good))[0],
                      'zdravy snapshot ostava :ok (charakterizacia)')

  lossy = JSON.parse(good.to_json)
  # Druhy clen je nepouzitelny (`per` novsej verzie) — normalizacia by ho
  # ticho zahodila a POCET SETOV by sedel dalej.
  lossy['sets']['zaves-a']['members'] << { 'code' => 'KOD-2', 'per' => 'length', 'qty' => 1 }
  NxTest.assert_equal(:invalid, r::HWS.project_state_status(r.model_with(lossy))[0],
                      'stratený člen = :invalid (ORANGE), nikdy tiché orezanie')

  newer = JSON.parse(good.to_json)
  newer['sets']['zaves-a']['members'][0]['per_length_mm'] = 100
  NxTest.assert_equal(:invalid, r::HWS.project_state_status(r.model_with(newer))[0],
                      'neznámy kľúč člena = ten istý detektor ako pri knižnici')
end

# --- 6) BLOCKER 1: read-only globál sa nesmie POUŽIŤ ------------------------

NxTest.test('R-07 (BLOCKER 1): z read-only knižnice sa do modelu NEKOPÍRUJE nič') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }, 'std' => 3))
    NxTest.assert_equal({ 'sets' => [], 'mapping' => {} }, r::HWS.load,
                        'load z nekompatibilnej kniznice nevydá nic')
    NxTest.assert_equal(nil, r::HWS.global_default_state, 'global_default_state = nil')

    m = r.model_with
    NxTest.assert_equal(nil, r::HWS.ensure_project_state!(m), 'prva stavba nezmrazi orezany stav')
    NxTest.assert_equal(nil, m.get_attribute(r::E::Store::DICT, r::HWS::MODEL_KEY),
                      'a do .skp sa NIC nezapisalo')
    NxTest.refute(r::HWS.set_project_mapping!(m, 'hinge', 'zaves-a', [r.plain_set]),
                  'zmena predvolby bez snapshotu sa odmietne')
    NxTest.refute(r::HWS.add_project_sets!(m, [r.plain_set]), 'add_project_sets!')

    snap = { 'std' => 1, 'mapping' => {}, 'sets' => {} }
    res, = r::HWS.merge_project_sets_seed!(r.model_with(snap))
    NxTest.assert_equal(:blocked, res, 'doplnenie predvolieb ma VLASTNY dovod, nie „uz mas vsetko"')
  end
end

NxTest.test('R-07 (BLOCKER 1): súpis bez snapshotu = ORANGE library_incompatible, NIKDY počty z orezaných dát') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }, 'std' => 3))
    col = r.collected([r.hinge_item], 'CAB-1' => { 'hinge' => 'zaves-a' })
    exp = r::PC.hardware_expansion(r.model_with, col)
    NxTest.assert_equal([], exp['rows'], 'ziadny nacene(ny) riadok z nekompatibilnej kniznice')
    NxTest.assert_equal(1, exp['unmapped'].length)
    u = exp['unmapped'][0]
    NxTest.assert_equal('library_incompatible', u['reason'])
    NxTest.assert(u['reason_sk'].include?('knižnica setov'), u['reason_sk'].to_s)
    NxTest.assert(r::HWS::UNMAPPED_REASONS.include?('library_incompatible'),
                  'dovod patri do kanonickeho zoznamu')

    items = []
    r::VAL.check_hardware_expansion(exp, items)
    NxTest.assert_equal(1, items.length)
    NxTest.assert_equal(r::VAL::ORANGE, items[0]['severity'])
    NxTest.assert(items[0]['message_sk'].include?('Aktualizuj plugin'),
                  "semafor hovori, co s tym: #{items[0]['message_sk']}")
  end
end

NxTest.test('R-07: PLATNÝ projektový snapshot funguje aj pri read-only knižnici') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }, 'std' => 3))
    snap = { 'std' => 1, 'mapping' => { 'hinge' => 'zaves-a' },
             'sets' => { 'zaves-a' => r.plain_set } }
    exp = r::PC.hardware_expansion(r.model_with(snap), r.collected([r.hinge_item]))
    NxTest.assert_equal([], exp['unmapped'], 'zakazka so zmrazenymi setmi sa nakupuje dalej')
    NxTest.assert_equal(['KOD-1'], exp['rows'].map { |x| x['code'] })
    NxTest.assert_equal(2, exp['rows'][0]['quantity'])
  end
end

# --- 6b) REPRODUKCIE INTERNEHO REVIEW ---------------------------------------

NxTest.test('R-07 (P1-1): stav sa NECACHUJE — súbor vymenený po zdravom loade zastaví zápis do modelu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    # 1) zdravy load — modul aj volajuci videli `:ok`
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }))
    NxTest.assert_equal(:ok, r::HWS.library_state)
    NxTest.assert_equal(['zaves-a'], r::HWS.load['sets'].map { |s| s['set_id'] })

    # 2) subor medzitym nahradi novsia verzia (clen nesie pole, ktore nepozname)
    novsi = r.doc([r.plain_set.merge(
      'members' => [{ 'code' => 'KOD-1', 'per' => 'unit', 'qty' => 1, 'per_length_mm' => 100 }]
    )], { 'hinge' => 'zaves-a' })
    r.install(novsi)

    # 3) prva stavba skrinky: NESMIE zmrazit orezany stav do .skp
    m = r.model_with
    NxTest.assert_equal(nil, r::HWS.ensure_project_state!(m),
                        'zapamatane :ok sa NESMIE pouzit — kontrola je nad cerstvym suborom')
    NxTest.assert_equal(nil, m.get_attribute(r::E::Store::DICT, r::HWS::MODEL_KEY),
                        'do modelu sa NIC nezapisalo (inak by `per_length_mm` zmizlo navzdy)')

    # 4) a supis to prizna ORANGE, nie nacenenim orezanych dat
    exp = r::PC.hardware_expansion(m, r.collected([r.hinge_item]))
    NxTest.assert_equal([], exp['rows'])
    NxTest.assert_equal('library_incompatible', exp['unmapped'][0]['reason'])
  end
end

NxTest.test('R-07 (P1-2): strata ČLENA bez nového kľúča (novšia HODNOTA `per`) = read-only') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  # `per: 'length'` je ZNAMY kluc s NEZNAMOU hodnotou — whitelist ju prepusti,
  # citacia normalizacia clena zahodi. Chyti to az round-trip porovnanie.
  r.with_library do
    r.install(r.doc([r.plain_set.merge(
      'members' => [{ 'code' => 'KOD-1', 'per' => 'unit', 'qty' => 1 },
                    { 'code' => 'KOD-2', 'per' => 'length', 'qty' => 1 }]
    )]))
    NxTest.assert(r::HWS.library_read_only?, 'stratený člen = read-only')
    NxTest.assert_equal(:unknown_shape, r::HWS.library_state_code)
    NxTest.assert_equal(:write_failed, r::HWS.save_set!(r.plain_set('novy'))[0],
                        'a save_set! stratu NEZVECNI')
  end
  # P3-7a: necislny kluc RADU — clen prezije s KRATSIM radom, takze pocet
  # clenov sedi; strata je vidno az na pocte poloziek radu.
  r.with_library do
    r.install(r.doc([r.plain_set.merge(
      'members' => [{ 'per' => 'unit', 'qty' => 1,
                      'code_by_nl' => { '420' => 'A', 'stred' => 'B' } }]
    )]))
    NxTest.assert(r::HWS.library_read_only?, 'orezany rad NL = read-only')
  end
  # P3-7b: mapovanie s prazdnou hodnotou — parser hlasi chybu TVARU.
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => '' }))
    NxTest.assert(r::HWS.library_read_only?, 'prazdne set_id v mapovani = read-only')
  end
  # NEGATIVNA kontrola: mapovanie na UZ ZMAZANY set nie je strata (delete_set!
  # mapovanie ocistuje zamerne) — kniznica musi ostat pouzitelna.
  r.with_library do
    r.install(r.doc([r.plain_set], { 'leg' => 'davno-zmazany' }))
    NxTest.assert_equal(:ok, r::HWS.library_state,
                        'referencia na zmazany set NIE JE nekompatibilita')
  end
end

NxTest.test('R-07 (P2-3): panel dáva ROVNAKÝ dôvod ako súpis (žiadne „priraď set")') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }, 'std' => 3))
    # Skrinka MA override na set — panel ho pri read-only kniznici NEUPLATNI
    # (definicia by musela prist prave z tej kniznice), takze `explain` dostane
    # prazdne overridy a dovod `library_incompatible`. Presne to robi
    # `Panel.decorate_hardware_purchase` (struktura overena nizsie).
    ex = r::HWS.explain(r.hinge_item, nil, overrides: {},
                                           no_set_reason: 'library_incompatible')
    NxTest.assert_equal([], ex['members'])

    # Kontrolna vzorka: keby override ostal, panel by radil „set v projekte
    # chyba" — teda uplne inu pricinu nez supis.
    zle = r::HWS.explain(r.hinge_item, nil, overrides: { 'hinge' => 'zaves-a' })
    NxTest.assert(zle['problems'][0].include?('chýba'),
                  'fixture: neuplatneny override je jediny rozdiel')
    NxTest.assert(ex['problems'][0].include?('knižnica setov'),
                  "panel hovori o KNIZNICI, nie o chybajucom sete: #{ex['problems'].inspect}")
    exp = r::PC.hardware_expansion(r.model_with, r.collected([r.hinge_item]))
    NxTest.assert_equal(exp['unmapped'][0]['reason_sk'], ex['problems'][0],
                        'panel a supis maju DOSLOVA rovnaky text')
  end
  # Panelova cesta `decorate_hardware_purchase` pouziva `Sketchup.active_model`,
  # takze sa headless zavolat neda — jej KONTRAKT sa preto strazi nad zdrojom
  # (vzor `test_r08_zamky.rb`): overidy sa pri blokovanej kniznici NULUJU
  # a dovod sa posiela dalej.
  body = r.method_src('ui/panel/payloads.rb', 'decorate_hardware_purchase')
  NxTest.assert(body.include?('library_read_only?') && body.include?('blocked ? {} :'),
                'panel pri read-only kniznici override skrinky NEUPLATNI')
  ip = r.method_src('ui/panel/payloads.rb', 'item_purchase')
  NxTest.assert(ip.include?('library_incompatible'),
                'a posiela `no_set_reason` do explain')
end

NxTest.test('R-07 (P2-4): šablóna pri read-only knižnici — bez kovania a BEZ pádu vkladania') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }, 'std' => 3))
    m = r.model_with
    # Ukladanie sablony: mapovanie BEZ definicii sa ulozit NESMIE.
    NxTest.assert_equal(nil, r::HWS.template_set_defs(m, { 'hinge' => 'zaves-a' }),
                        'nil = volajuci ulozi sablonu BEZ kovania a nahlasi to')
    # Aplikacia sablony: vlastny stav, nie :failed (ten volajuci meni na vynimku
    # a zhodil by cele vkladanie skrinky).
    res = r::HWS.freeze_template_sets!(m, { 'hinge' => 'zaves-a' },
                                       { 'zaves-a' => r.plain_set })
    NxTest.assert_equal(:blocked, res['status'])
  end
end

NxTest.test('R-07 (P2-5): poškodený súbor BEZ zálohy ostáva SAMOOPRAVNÝ (ako na maine)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do |path|
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, '{ toto nie je JSON')
    FileUtils.rm_f("#{path}.bak")
    r::STORE.invalidate(path)
    r::HWS.reset_library_state!
    NxTest.assert_equal(:ok, r::HWS.library_state,
                        'bez zalohy nie je co stratit — ziadna slepa ulicka')
    NxTest.assert(r::HWS.load['sets'].any?, 'load vrati seed (spravanie mainu)')
    NxTest.assert_equal(:ok, r::HWS.save_set!(r.plain_set('novy'))[0],
                        'a prvy zapis subor SAMOOPRAVI')
    NxTest.assert(r.raw['sets'].any?, 'subor je zase platny JSON')
  end
  # So ZALOHOU, ktora sa tiez neda precitat, ostava read-only — a dovod menuje
  # CESTU, takze pouzivatel vie, co zmazat.
  r.with_library do |path|
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, '{ zle')
    File.binwrite("#{path}.bak", '{ tiez zle')
    r::STORE.invalidate(path)
    r::HWS.reset_library_state!
    NxTest.assert(r::HWS.library_read_only?)
    NxTest.assert_equal(:unreadable, r::HWS.library_state_code)
    NxTest.assert(r::HWS.library_state_reason.include?(path),
                  "dovod menuje subor: #{r::HWS.library_state_reason}")
  end
end

# --- 7) CHARAKTERIZACIA: zdrava kniznica sa sprava ako dnes -----------------

NxTest.test('R-07 charakterizácia: zdravá std-1 knižnica bez nových tvarov = správanie ako dnes') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  r = NxR07
  r.with_library do
    r.install(r.doc([r.plain_set], { 'hinge' => 'zaves-a' }))
    NxTest.assert_equal(:ok, r::HWS.library_state)
    NxTest.assert_equal('', r::HWS.library_state_reason)
    NxTest.assert_equal(['zaves-a'], r::HWS.load['sets'].map { |s| s['set_id'] },
                        'zdrava kniznica sa cita cela')
    state = r::HWS.global_default_state
    NxTest.assert_equal({ 'hinge' => 'zaves-a' }, state['mapping'])
    NxTest.assert_equal(['zaves-a'], state['sets'].keys)

    exp = r::PC.hardware_expansion(r.model_with, r.collected([r.hinge_item]))
    NxTest.assert_equal(['KOD-1'], exp['rows'].map { |x| x['code'] },
                        'bez snapshotu sa dalej cita global default')
    NxTest.assert_equal([], exp['unmapped'])

    # a ZAPISY beziaci nad zdravou kniznicou prechadzaju bez zmeny
    NxTest.assert_equal(:ok, r::HWS.save_set!(r.plain_set('novy'))[0])
    NxTest.assert_equal(:ok, r::HWS.set_global_mapping!('hinge', 'zaves-a'))
    NxTest.assert_equal(:ok, r::HWS.delete_set!('novy')[0])
  end
end
