# frozen_string_literal: true
# S1-C — OCAKAVANY SPOTREBIC (`appliance_expects[]`) A ORANGE BEZ SPOTREBICA.
#
# CO BOLO ZLE: sablona vedela ulozit konstrukciu skrinky, ale nie to, ZE do nej
# patri rura. Skrinka vlozena z „chladnickovej skrine" vyzerala hotova, hoci
# v nej ziadna chladnicka nebola — a Kontrola o tom nemala co povedat.
#
# CO PLATI TERAZ:
#   * OCAKAVANIA ZIJU NA JEDNOM MIESTE — `config['appliance_expects']`
#     (Astra C1). Zaznam sablony ziadny novy kluc NEMA, takze `TemplateStore
#     ::STD` ostava 5 a kniznica sa starsim pluginom nezamyka (C2).
#   * DOKAZ SPLNENIA je TEN ISTY obojsmerny dokaz ako pri `bound` (C3):
#     polozka musi mat za vlastnika tu entitu A entita musi niest jej `item_id`.
#     Ani recyklovane ID vlastnika, ani osirely zaznam v refs dokazom nie je.
#   * ZAPIS BEZ PRESTAVBY pecatkuje schemu (C4): `write_config_keys!` v JEDNEJ
#     operacii pod `guarded`, inak by `normalize` kluc pri najblizsej prestavbe
#     starej skrinky ticho zahodil.
#   * OCAKAVAT sa da len to, co sa k tomu kusu smie aj PRIRADIT (C5) — jedna
#     matica pre vazbu aj pre ocakavanie; slot ocakava VZDY presne umyvacku.
#
# PRECO GUARD TESTY A NIE KLIKANIE: nalez „spotrebič nevybraný" stoji na
# dokaze vazby, ktory je rozdeleny medzi polozku zakazky a config entity.
# Kazda skratka na jednej strane (ID, kategoria) vyrobi bud falosne ticho,
# alebo falosny poplach — a oboje si pouzivatel vsimne az pri objednavke.
require_relative '../helper' unless defined?(NxTest)

# Headless: `ui/*.rb` nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_appliance')
end

module NxS1C
  module_function

  E     = Noxun::Engine
  AB    = E::ApplianceBinding
  AC    = E::ApplianceCatalog
  BS    = E::BudgetStore
  BOM   = E::Bom
  CB    = E::CabinetBuilder
  BB    = E::BoardBuilder
  VAL   = E::Validation
  TS    = E::TemplateStore
  TD    = E::TemplatesDialog
  PANEL = E::Panel
  STORE = E::Store

  # Fake dokument (vzor `test_s1b1_vazba.rb`) — pocita operacie, takze sa da
  # overit „nezmeneny vysledok = ZIADNY krok Spat".
  class FakeModel < NxTest::FakeEntity
    attr_reader :ops, :committed, :aborted

    def initialize
      super
      @ops = []
      @committed = 0
      @aborted = 0
    end

    def path
      ''
    end

    def active_path
      nil
    end

    def start_operation(name, _disable_ui = false, _next_transparent = false, _transparent = false)
      @ops << name
      true
    end

    def commit_operation
      @committed += 1
      true
    end

    def abort_operation
      @aborted += 1
      true
    end
  end

  class FakeInst < NxTest::FakeEntity
    attr_reader :persistent_id

    def initialize(pid)
      super()
      @persistent_id = pid
    end
  end

  def cabinet(id, pid, type: 'lower', refs: nil, expects: nil, schema: 16)
    inst = FakeInst.new(pid)
    cfg = { 'config_schema' => schema, 'type' => type, 'width' => 600.0, 'height' => 720.0,
            'depth' => 560.0, 'thickness' => 18.0, 'floor_height' => 100.0,
            'bottom_mode' => 'between_sides', 'top_mode' => 'two_rails',
            'back_mode' => 'inset', 'back_thickness' => 5.0 }
    cfg['appliance_refs'] = refs if refs
    cfg['appliance_expects'] = expects if expects
    STORE.write(inst, { kind: 'cabinet', cabinet_id: id, config: cfg })
    inst
  end

  def board(id, pid, expects: nil, schema: 2)
    inst = FakeInst.new(pid)
    cfg = { 'config_schema' => schema, 'role' => 'worktop', 'name' => 'Doska',
            'length' => 2400.0, 'width' => 600.0, 'thickness' => 38.0 }
    cfg['appliance_expects'] = expects if expects
    STORE.write(inst, { kind: 'board', id: id, manufactured: true, config: cfg })
    inst
  end

  def cfg_of(inst)
    STORE.config(inst) || {}
  end

  def ref(item_id, category)
    { 'item_id' => item_id, 'category' => category }
  end

  # Polozka zakazky (minimalny tvar, aky cita zber aj dokaz vazby).
  def item(id, category, owner_kind, owner_id, name = 'Model')
    { 'id' => id, 'typ' => category, 'nazov' => name,
      'owner' => { 'kind' => owner_kind, 'id' => owner_id } }
  end

  # Mapa vlastnikov PRESNE tak, ako ju stavia `Bom.collect`.
  def owners(*entries)
    entries.each_with_object({}) do |(id, pid, cfg, kind), out|
      BOM.note_appliance_owner(out, id, pid, cfg, kind: kind)
    end
  end

  # Zaznamy zberu + Kontrola cez REALNU cestu (`Validation.run`).
  def control(items, owner_map)
    VAL.run({ records: [], appliances: BOM.appliance_records(items, owner_map) })
  end

  def missing_keys(res)
    Array(res['items']).map { |i| i['stable_key'].to_s }.select { |k| k.include?('|missing|') }
  end

  def with_stubs(entries)
    saved = []
    entries.each do |(mod, name, impl)|
      sc = mod.singleton_class
      saved << [sc, name, sc.instance_method(name)]
      sc.send(:define_method, name, &impl)
    end
    yield
  ensure
    saved.reverse_each { |(sc, name, orig)| sc.send(:define_method, name, orig) }
  end

  def scan_stub(cabinets: [], boards: [], detached: {})
    [E::Ids, :top_level_scan,
     lambda { |_model|
       { 'cabinets' => cabinets, 'boards' => boards, 'detached' => Hash.new(0).merge(detached) }
     }]
  end

  def src(*rel)
    File.read(File.join(NxTest::ROOT, *rel), encoding: 'UTF-8')
  end

  # Telo metody zo zdroja (guard testy poradia — vzor `test_d100_nazvy.rb`).
  def body_of(source, name)
    source[/def #{Regexp.escape(name)}\b.*?\n        end\n/m].to_s
  end
end

# ---------------------------------------------------------------------------
# 1) MATICA A VALIDACIA VSTUPU (C5, C8)
# ---------------------------------------------------------------------------

NxTest.test('S1-C (C5): ocakavat sa da LEN to, co sa k tomu kusu smie priradit') do
  ab = NxS1C::AB
  NxTest.assert_equal(%w[fridge oven microwave], ab.expectable_categories('cabinet'))
  NxTest.assert_equal(%w[hob sink], ab.expectable_categories('board'))
  NxTest.assert_equal(%w[dishwasher], ab.expectable_categories('slot'),
                      'slot ocakava VZDY presne umyvacku')
  # Digestor a „iné" nemaju fyzickeho vlastnika, takze ich nikto ocakavat nemoze.
  %w[hood other].each do |cat|
    NxTest.refute(ab.expectable?('cabinet', cat), cat)
    NxTest.refute(ab.expectable?('board', cat), cat)
  end
  # A matica ocakavani sa NEMOZE rozist s maticou vlastnikov — je to tabulka.
  ab::OWNER_MATRIX.each do |cat, kinds|
    kinds.each do |kind|
      NxTest.assert(ab.expectable?(kind, cat), "#{cat} -> #{kind}")
    end
  end
end

NxTest.test('S1-C (C8): `nil` ani ne-pole NIE JE „zruš očakávania"') do
  [nil, 'oven', 0, { 'oven' => true }].each do |raw|
    list, err = NxS1C::AB.validate_expects(raw, 'cabinet')
    NxTest.assert(list.nil?, raw.inspect)
    NxTest.assert_equal(NxS1C::AB::MSG_EXPECTS_INPUT, err)
  end
  # EXPLICITNE prazdne pole je legitimne zrusenie.
  list, err = NxS1C::AB.validate_expects([], 'cabinet')
  NxTest.assert(err.nil?)
  NxTest.assert_equal([], list)
end

NxTest.test('S1-C (C8): neznamy kod a kod mimo matice sa ODMIETNU s hlaskou') do
  list, err = NxS1C::AB.validate_expects(%w[oven nieco_nove], 'cabinet')
  NxTest.assert(list.nil?)
  NxTest.refute(err.to_s.empty?, 'hlaska menuje, PRECO to nejde')
  # Kanonicky kod, ktory k tomuto druhu NEPATRI (drez na skrinku).
  l2, e2 = NxS1C::AB.validate_expects(%w[sink], 'cabinet')
  NxTest.assert(l2.nil?)
  NxTest.assert(e2.include?('Drez'), e2.to_s)
  # Slot: ziadne ine ocakavanie sa nastavit neda.
  l3, e3 = NxS1C::AB.validate_expects(%w[oven], 'slot')
  NxTest.assert(l3.nil?)
  NxTest.assert(e3.include?('umývačku'), e3.to_s)
end

NxTest.test('S1-C (C8): dedup + KANONICKE poradie (preskupeny zoznam je ten isty stav)') do
  list, = NxS1C::AB.validate_expects(%w[microwave oven oven], 'cabinet')
  NxTest.assert_equal(%w[oven microwave], list,
                      'poradie je poradie kategorii katalogu, nie poradie klikania')
  again, = NxS1C::AB.validate_expects(%w[oven microwave], 'cabinet')
  NxTest.assert_equal(list, again, 'to iste zadanie -> ten isty zoznam (inak by vznikol krok Spat)')
end

# ---------------------------------------------------------------------------
# 2) DOKAZ SPLNENIA (C3)
# ---------------------------------------------------------------------------

NxTest.test('S1-C (C3): splnene je LEN to, co dokazu OBE strany vazby') do
  ab = NxS1C::AB
  entry = { 'kind' => 'cabinet', 'id' => 'CAB-3', 'refs' => [NxS1C.ref('I-1', 'oven')] }
  items = [NxS1C.item('I-1', 'oven', 'cabinet', 'CAB-3')]
  NxTest.assert_equal(%w[oven], ab.bound_categories(entry, items))

  # RECYKLOVANE ID: polozka ukazuje na CAB-3, ale dnesna CAB-3 vazbu nenesie.
  recycled = { 'kind' => 'cabinet', 'id' => 'CAB-3', 'refs' => [] }
  NxTest.assert_equal([], ab.bound_categories(recycled, items),
                      'samotne ID vlastnika dokazom NIE JE')

  # OSIRELE refs: entita nesie zaznam, polozka uz neexistuje.
  NxTest.assert_equal([], ab.bound_categories(entry, []),
                      'samotna `category` v refs dokazom NIE JE')

  # ZLY DRUH: skrinkovy zaznam na entite, ktora je dnes SLOT s tym istym cislom.
  slot_entry = { 'kind' => 'slot', 'id' => 'CAB-3', 'refs' => [NxS1C.ref('I-1', 'oven')] }
  NxTest.assert_equal([], ab.bound_categories(slot_entry, items), 'druh musi sediet')
end

# Codex #385 kolo 1 (P2): Inspector a Kontrola MUSIA citat TU ISTU mnozinu
# splnenych kategorii. Kym panel veril samotnej `category` v refs, sirota mu
# riadok „očakáva" POTLACILA — Kontrola pritom (spravne) hlasila
# `appliance_missing` a pouzivatel nemal kde ho vybavit.
NxTest.test('S1-C (P2): sirota ani recyklovany ref riadok „očakáva" NEPOTLACIA') do
  # (a) OSIRELY ref: entita nesie zaznam, polozka uz v rozpocte NIE JE.
  cfg = { 'type' => 'lower', 'width' => 600.0, 'height' => 2076.0, 'depth' => 560.0,
          'thickness' => 18.0, 'floor_height' => 100.0,
          'appliance_expects' => %w[oven],
          'appliance_refs' => [NxS1C.ref('ZOMBIE', 'oven')] }
  rows = NxS1C::PANEL.appliance_rows('cabinet', cfg, [], nil, owner_id: 'CAB-3')
  exp = rows.find { |r| r['state'] == 'expected' }
  NxTest.refute(exp.nil?, "riadok ocakavania MUSI byt: #{rows.map { |r| r['state'] }.inspect}")
  NxTest.assert_equal('oven', exp['category'])
  NxTest.assert(exp.key?('options'), 'a ponuka vyberu modelu je v nom')

  # (b) RECYKLOVANE ID: polozka tvrdi CAB-3, ale TATO CAB-3 jej `item_id` nenesie.
  cfg2 = cfg.merge('appliance_refs' => [])
  items = [NxS1C.item('I-1', 'oven', 'cabinet', 'CAB-3')]
  rows2 = NxS1C::PANEL.appliance_rows('cabinet', cfg2, items, nil, owner_id: 'CAB-3')
  NxTest.assert(rows2.any? { |r| r['state'] == 'expected' },
                'bez zaznamu na entite nie je co povazovat za splnene')

  # (c) PLATNA vazba riadok POTLACI — obe strany dokazu sedia.
  cfg3 = cfg.merge('appliance_refs' => [NxS1C.ref('I-1', 'oven')])
  rows3 = NxS1C::PANEL.appliance_rows('cabinet', cfg3, items, nil, owner_id: 'CAB-3')
  NxTest.refute(rows3.any? { |r| r['state'] == 'expected' },
                'splnene ocakavanie riadok nepotrebuje')

  # A TO ISTE hovori Kontrola nad tou istou fixturou — jedna mnozina, dva citatelia.
  res = NxS1C.control([], NxS1C.owners(['CAB-3', 303, cfg, nil]))
  NxTest.assert_equal(['appliance|CAB-3|missing|oven'], NxS1C.missing_keys(res),
                      'Kontrola pri osirelom refs nalez DAVA — panel musel ponuknut vyber')
end

NxTest.test('S1-C (C3): zber hlasi `expected_missing` aj pri recyklovanom ID a osirelych refs') do
  # (a) recyklovane ID — polozka tvrdi CAB-3, entita CAB-3 vazbu nenesie
  own = NxS1C.owners(['CAB-3', 103, { 'type' => 'lower', 'appliance_expects' => %w[oven] }, nil])
  recs = NxS1C::BOM.appliance_records([NxS1C.item('I-1', 'oven', 'cabinet', 'CAB-3')], own)
  states = recs.map { |r| r['state'] }
  NxTest.assert(states.include?('owner_missing'), states.inspect)
  NxTest.assert(states.include?('expected_missing'),
                'ocakavanie NIE JE splnene — polozka visi v prazdne')

  # (b) osirele refs — entita nesie zaznam kategorie, polozka uz neexistuje
  own2 = NxS1C.owners(['CAB-4', 104,
                       { 'type' => 'lower', 'appliance_expects' => %w[oven],
                         'appliance_refs' => [NxS1C.ref('ZOMBIE', 'oven')] }, nil])
  recs2 = NxS1C::BOM.appliance_records([], own2)
  NxTest.assert_equal(%w[expected_missing], recs2.map { |r| r['state'] },
                      'refs bez polozky ocakavanie nesplnia')
end

# ---------------------------------------------------------------------------
# 3) KONTROLA — ORANGE `appliance_missing` PER KATEGORIU (R5)
# ---------------------------------------------------------------------------

NxTest.test('S1-C (R5): nalez je PER NESPLNENU KATEGORIU (rura + mikro, jedna viazana)') do
  cfg = { 'type' => 'lower', 'appliance_expects' => %w[oven microwave],
          'appliance_refs' => [NxS1C.ref('I-OVEN', 'oven')] }
  own = NxS1C.owners(['CAB-5', 105, cfg, nil])
  res = NxS1C.control([NxS1C.item('I-OVEN', 'oven', 'cabinet', 'CAB-5')], own)
  NxTest.assert_equal(['appliance|CAB-5|missing|microwave'], NxS1C.missing_keys(res),
                      'splnena rura nalez nema, chybajuca mikrovlnka ANO')
  row = Array(res['items']).find { |i| i['stable_key'].to_s.include?('missing') }
  NxTest.assert_equal('orange', row['severity'])
  NxTest.assert_equal('appliance', row['category'])
  NxTest.assert_equal('CAB-5', row['owner_id'], 'klik oznaci SKRINKU (vlastnika poznáme)')
  NxTest.assert_equal(105, row['owner_pid'], 'a PID, lebo ID sa recykluju')
  NxTest.assert(row['message_sk'].include?('mikrovlnku'), row['message_sk'])
  NxTest.assert(row['message_sk'].start_with?('Skrinka CAB-5'), row['message_sk'])
  NxTest.assert(row['message_sk'].include?('očakávanie zruš'),
                'veta hovori OBE cesty von')
end

NxTest.test('S1-C (R5): DVE nesplnene kategorie = DVA riadky (vlastny `stable_key`)') do
  cfg = { 'type' => 'lower', 'appliance_expects' => %w[oven microwave] }
  res = NxS1C.control([], NxS1C.owners(['CAB-5', 105, cfg, nil]))
  keys = NxS1C.missing_keys(res)
  NxTest.assert_equal(%w[appliance|CAB-5|missing|oven appliance|CAB-5|missing|microwave].sort,
                      keys.sort)
  NxTest.assert_equal(keys.uniq.length, keys.length, 'dedup nesmie zliat dve veci na opravu')
end

NxTest.test('S1-C (R5): SLOT bez modelu je nalez `appliance_missing dishwasher`') do
  cfg = { 'type' => 'dishwasher', 'dw_class' => 600, 'width' => 600.0, 'height' => 870.0 }
  res = NxS1C.control([], NxS1C.owners(['CAB-7', 107, cfg, 'slot']))
  NxTest.assert_equal(['appliance|CAB-7|missing|dishwasher'], NxS1C.missing_keys(res),
                      'slot ocakava umyvacku aj BEZ `appliance_expects` — je to jeho zmysel')
  row = Array(res['items']).find { |i| i['stable_key'].to_s.include?('missing') }
  NxTest.assert(row['message_sk'].start_with?('Slot umývačky CAB-7'), row['message_sk'])
end

NxTest.test('S1-C (R5): splnene ocakavanie nalez NEDAVA a badge ho rata') do
  cfg = { 'type' => 'lower', 'appliance_expects' => %w[oven],
          'appliance_refs' => [NxS1C.ref('I-1', 'oven')] }
  own = NxS1C.owners(['CAB-5', 105, cfg, nil])
  res = NxS1C.control([NxS1C.item('I-1', 'oven', 'cabinet', 'CAB-5')], own)
  NxTest.assert_equal([], NxS1C.missing_keys(res))

  # BADGE: existujuca cesta `counts` rata aj tento nalez.
  bad = NxS1C.control([], NxS1C.owners(['CAB-9', 109,
                                        { 'type' => 'lower',
                                          'appliance_expects' => %w[fridge] }, nil]))
  NxTest.assert_equal(1, bad['counts']['orange'])
  NxTest.assert_equal(1, bad['counts']['total'])
end

NxTest.test('S1-C: nalez NEBLOKUJE export (spotrebic sa nevyraba)') do
  code = NxS1C.src('noxun_engine', 'core', 'validation.rb')
  body = NxS1C.body_of(code, 'check_appliance_missing')
  NxTest.refute(body.empty?, 'metoda sa nasla')
  NxTest.assert(body.include?('ORANGE'), 'zavaznost je ORANGE, nikdy RED')
  NxTest.refute(body.include?('RED'), 'vyrobne data su v poriadku — je to upozornenie')
end

# ---------------------------------------------------------------------------
# 4) SABLONA (C1, C2, C9, C16, R3, R6)
# ---------------------------------------------------------------------------

NxTest.test('S1-C (C2): `TemplateStore::STD` ostava 5 — ocakavania ziju v CONFIGU') do
  NxTest.assert_equal(5, NxS1C::TS::STD,
                      'bump by zamkol zapis kniznice starsiemu pluginu bez jedineho dovodu')
  hdr = NxS1C.src('noxun_engine', 'core', 'templates.rb')
  NxTest.refute(hdr.include?("'expects'"), 'zaznam sablony ziadny novy kluc NEMA')
end

NxTest.test('S1-C (C2): slotove seed sablony ocakavaju umyvacku IMPLICITNE') do
  NxS1C::TS.build_predefined_slots.each do |seed|
    cfg = seed['config']
    NxTest.refute(cfg.key?('appliance_expects'),
                  'seed kluc nenesie — ocakavanie dosadi builder podla typu')
    sum = NxS1C::TS.appliance_expects_summary(cfg)
    NxTest.assert_equal(%w[dishwasher], sum['codes'],
                        'stara aj nova slotova sablona hovoria to iste')
    NxTest.assert_equal('očakáva umývačku', sum['text'])
  end
end

NxTest.test('S1-C (C10): citanie kniznice STD 5 NIC nezapisuje') do
  NxTest.skip!('katalogy v %APPDATA% sa testuju len headless') unless NxTest.headless?
  ts = NxS1C::TS
  ts.upsert('cabinet', 'S1C round-trip', { 'type' => 'lower', 'width' => 600.0,
                                           'appliance_expects' => %w[oven microwave] })
  before = File.read(ts.path, mode: 'rb')
  3.times { ts.reload!; ts.load }
  NxTest.assert_equal(before, File.read(ts.path, mode: 'rb'),
                      'subor je BAJTOVO nezmeneny (ziadna migracia, ziadny bump)')
  rec = ts.find('cabinet', 'S1C round-trip')
  NxTest.assert_equal(%w[oven microwave], rec['config']['appliance_expects'],
                      'round-trip dvoch kategorii')
  ts.delete('cabinet', 'S1C round-trip')
end

NxTest.test('S1-C (C16): prepis sablony ZACHOVA nezname kluce ZAZNAMU') do
  NxTest.skip!('katalogy v %APPDATA% sa testuju len headless') unless NxTest.headless?
  ts = NxS1C::TS
  name = 'S1C neznamy kluc'
  ts.upsert('cabinet', name, { 'type' => 'lower', 'width' => 600.0 })
  # Zaznam z NOVSEJ verzie: kluc, o ktorom tento plugin nic nevie.
  list = ts.load.map do |t|
    next t unless t['name'] == name

    t.merge('buduce_pole' => { 'x' => 1 })
  end
  NxTest.assert(ts.send(:write_list, list))
  NxTest.assert(ts.upsert('cabinet', name, { 'type' => 'lower', 'width' => 800.0,
                                             'appliance_expects' => %w[fridge] }))
  rec = ts.find('cabinet', name)
  NxTest.assert_equal({ 'x' => 1 }, rec['buduce_pole'], 'neznamy kluc zaznamu PREZIL prepis')
  NxTest.assert_equal(800.0, rec['config']['width'], 'a config je NOVY')
  NxTest.assert_equal(%w[fridge], rec['config']['appliance_expects'])
  ts.delete('cabinet', name)
end

NxTest.test('S1-C (C1): modal je AUTORITA ocakavani sablony (nie config skrinky)') do
  # Skrinka ocakava ruru, v modale pouzivatel prepne na mikrovlnku.
  cfg = { 'type' => 'lower', 'appliance_expects' => %w[oven] }
  NxTest.assert(NxS1C::PANEL.apply_template_expects!(cfg, %w[microwave]).nil?)
  NxTest.assert_equal(%w[microwave], cfg['appliance_expects'])
  # Prazdny zoznam = sablona nic neocakava (kluc MIZNE, nie prazdne pole).
  cfg2 = { 'type' => 'lower', 'appliance_expects' => %w[oven] }
  NxTest.assert(NxS1C::PANEL.apply_template_expects!(cfg2, []).nil?)
  NxTest.refute(cfg2.key?('appliance_expects'))
  # Starsi klient kluc neposiela -> ocakavania sa NEMENIA.
  cfg3 = { 'type' => 'lower', 'appliance_expects' => %w[oven] }
  NxTest.assert(NxS1C::PANEL.apply_template_expects!(cfg3, nil).nil?)
  NxTest.assert_equal(%w[oven], cfg3['appliance_expects'])
end

NxTest.test('S1-C (C5): SLOTOVA sablona ocakava umyvacku aj pri podvrhnutom payloade') do
  cfg = { 'type' => 'dishwasher' }
  NxTest.assert(NxS1C::PANEL.apply_template_expects!(cfg, %w[oven]).nil?)
  NxTest.assert_equal(%w[dishwasher], cfg['appliance_expects'],
                      'HTML readonly ochrana nie je — vynucuje to server')
end

NxTest.test('S1-C (C9): neznama kategoria sa odmietne PRED zapisom do kniznice') do
  cfg = { 'type' => 'lower' }
  err = NxS1C::PANEL.apply_template_expects!(cfg, %w[nieco])
  NxTest.refute(err.nil?, 'handler vracia hlasku')
  NxTest.assert(err.start_with?('Šablóna sa neuložila'), err)
  NxTest.refute(cfg.key?('appliance_expects'), 'config sa nedotkol')
  # A v handleri stoji kontrola PRED `capture` aj PRED `upsert` (poradie je
  # kontrakt: odmietnuta sablona nesmie prepisat ani obrazok).
  body = NxS1C.body_of(NxS1C.src('noxun_engine', 'ui', 'panel', 'actions_templates.rb'),
                       'handle_save_template_as')
  NxTest.refute(body.empty?)
  i_exp = body.index('apply_template_expects!')
  NxTest.assert(i_exp && i_exp < body.index('TemplatePreviews.capture'), 'pred fotenim')
  NxTest.assert(i_exp < body.index('TemplateStore.upsert'), 'a pred zapisom')
end

NxTest.test('S1-C (R3): `template_config_from` nesie ocakavania a vazbu NIKDY') do
  st = NxS1C::CB.cabinet_config(NxS1C::CB.normalize(
                                 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                                 'depth' => 560.0, 'thickness' => 18.0,
                                 'appliance_expects' => %w[oven],
                                 'appliance_refs' => [NxS1C.ref('I-1', 'oven')]
                               ))
  st = JSON.parse(st.to_json)
  tc = NxS1C::PANEL.template_config_from(st)
  NxTest.assert_equal(%w[oven], tc['appliance_expects'])
  NxTest.refute(tc.key?('appliance_refs'), 'vazba je majetkom JEDNEJ skrinky v JEDNEJ zakazke')
end

NxTest.test('S1-C (R6): `merge_template` zachova refs CIELA a ocakavania ZJEDNOTI') do
  target = { 'appliance_refs' => [NxS1C.ref('I-1', 'oven')],
             'appliance_expects' => %w[oven], 'part_overrides' => {}, 'hardware_overrides' => [] }
  merged = NxS1C::TD.merge_template(target, { 'type' => 'lower',
                                              'appliance_expects' => %w[microwave] })
  NxTest.assert_equal([NxS1C.ref('I-1', 'oven')], merged['appliance_refs'],
                      'aplikovanie sablony NESMIE odpojit spotrebic')
  NxTest.assert_equal(%w[oven microwave], merged['appliance_expects'],
                      'unia — prepis by ticho zahodil ocakavanie ciela')
  # Sablona BEZ ocakavani ocakavanie ciela nezmaze.
  m2 = NxS1C::TD.merge_template(target, { 'type' => 'lower' })
  NxTest.assert_equal(%w[oven], m2['appliance_expects'])
  # Ani ciel, ani sablona nic -> kluc v configu NEBUDE.
  m3 = NxS1C::TD.merge_template({ 'part_overrides' => {}, 'hardware_overrides' => [] },
                                { 'type' => 'lower' })
  NxTest.assert(m3['appliance_expects'].nil?, 'prazdne pole by predstieralo, ze sa to uz riesilo')
end

NxTest.test('S1-C (R6): unia zachova aj NEZNAMY kod z novsej verzie') do
  merged = NxS1C::TD.union_expects(%w[buduce_zariadenie], %w[oven])
  NxTest.assert_equal(%w[oven buduce_zariadenie], merged,
                      'kanonicke kody prve, neznamy sa NEZAHADZUJE')
end

NxTest.test('S1-C (R3): vlozenie zo sablony vezme ocakavania zo ZAZNAMU (E7)') do
  NxTest.skip!('kniznica v %APPDATA% sa testuje len headless') unless NxTest.headless?
  ts = NxS1C::TS
  name = 'S1C rurova skrina'
  ts.upsert('cabinet', name, { 'type' => 'lower', 'width' => 600.0,
                              'appliance_expects' => %w[oven microwave] })
  # Payload z CEF ocakavania NEPOZNA (a podvrhnute by sa zahodili).
  params = { 'type' => 'lower', 'width' => 600.0,
             'appliance_expects' => %w[fridge],
             'appliance_refs' => [NxS1C.ref('PODVRH', 'oven')] }
  NxS1C::PANEL.apply_template_slot_fields!(params, ['cabinet', name])
  NxTest.assert_equal(%w[oven microwave], params['appliance_expects'],
                      'autoritou je ULOZENY zaznam, nie klient')
  NxTest.refute(params.key?('appliance_refs'), 'vklad nikdy nenesie vazbu')
  # A cely cyklus: normalize -> config skrinky.
  cfg = JSON.parse(NxS1C::CB.cabinet_config(NxS1C::CB.normalize(params)).to_json)
  NxTest.assert_equal(%w[oven microwave], cfg['appliance_expects'])
  ts.delete('cabinet', name)
end

NxTest.test('S1-C (C11): vklad zo ZMIZNUTEJ sablony sa ODMIETNE, bez ref ide dalej') do
  body = NxS1C.body_of(NxS1C.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'),
                       'handle_insert')
  NxTest.refute(body.empty?)
  NxTest.assert(body.include?('TemplateStore.find(*tpl_ref).nil?'),
                'zmiznuta DEKLAROVANA sablona = odmietnutie')
  i = body.index('TemplateStore.find(*tpl_ref).nil?')
  NxTest.assert(i < body.index('apply_template_slot_fields!'),
                'a stoji PRED doplnenim poli zo zaznamu')
  NxTest.assert(i < body.index('CabinetBuilder.prepare_insert'), 'teda pred akoukolvek stavbou')
  # `take_template_ref!` vracia nil, ked payload sablonu nedeklaruje — vtedy
  # sa guard vobec nespusti (vedomy vklad bez sablony).
  NxTest.assert(NxS1C::PANEL.take_template_ref!({ 'type' => 'lower' }, 'cabinet').nil?)
  NxTest.assert_equal(['cabinet', 'X'],
                      NxS1C::PANEL.take_template_ref!({ 'template_kind' => 'cabinet',
                                                        'template_name' => 'X' }, 'cabinet'))
end

NxTest.test('S1-C (C15): dlazdica sablony ukazuje ocakavania (text sklada server)') do
  row = NxS1C::TD.tile_row({ 'name' => 'Rúrová', 'preview_rev' => nil,
                             'config' => { 'type' => 'lower', 'width' => 600.0,
                                           'appliance_expects' => %w[oven microwave] } })
  NxTest.assert_equal({ 'has' => true, 'codes' => %w[oven microwave],
                        'text' => 'očakáva rúru, mikrovlnku' }, row['appliance_expects'])
  # Sablona BEZ ocakavani riadok nedostane.
  plain = NxS1C::TD.tile_row({ 'name' => 'Dolná', 'config' => { 'type' => 'lower' } })
  NxTest.assert_equal(false, plain['appliance_expects']['has'])
  NxTest.assert_equal('', plain['appliance_expects']['text'])
  NxTest.refute(row['config'].key?('appliance_expects'),
                'uzavrety kluc `config` dlazdice sa nenafukol — ocakavania su vlastny kluc')
end

# ---------------------------------------------------------------------------
# 5) CONFIG-ONLY ZAPIS (C4)
# ---------------------------------------------------------------------------

# Codex #385 kolo 1 (P1) PREPISAL rozhodnutie C4: marker sa config-only zapisom
# NEPOSUVA. Je to PROVENIENCIA STAVBY — citaju ju stale guardy zasuviek, zavesov
# a vyklopov proti prahom `*_ACTIVATION_SCHEMA`, takze tiche posunutie by
# vyhlasilo, ze skrinka je postavena s funkciami, ktore v nej nie su, a RED
# nalezy aj blokacia exportov by zmizli.
NxTest.test('S1-C (P1): `write_config_keys!` marker NEPOSUVA a zvysok configu NEMENI') do
  cab = NxS1C.cabinet('CAB-1', 101, schema: NxS1C::CB::CONFIG_SCHEMA)
  NxS1C::CB.write_config_keys!(cab, 'appliance_expects' => %w[oven])
  cfg = NxS1C.cfg_of(cab)
  NxTest.assert_equal(%w[oven], cfg['appliance_expects'])
  NxTest.assert_equal(NxS1C::CB::CONFIG_SCHEMA, cfg['config_schema'], 'marker ostava aky bol')
  NxTest.assert_close(720.0, cfg['height'], 0.01, 'zvysok configu je NEDOTKNUTY')
  # `nil` kluc ODSTRANI (kus nikdy nedostane prazdne pole).
  NxS1C::CB.write_config_keys!(cab, 'appliance_expects' => nil)
  NxTest.refute(NxS1C.cfg_of(cab).key?('appliance_expects'))

  # LEGACY skrinka: keby zapis predsa len prebehol, marker sa NEZDVIHNE.
  old = NxS1C.cabinet('CAB-2', 102, schema: 15)
  NxS1C::CB.write_config_keys!(old, 'appliance_expects' => %w[oven])
  NxTest.assert_equal(15, NxS1C.cfg_of(old)['config_schema'],
                      'marker je proveniencia STAVBY, nie verzia zapisu')
  # A doska ma ten isty kontrakt (vlastny, nezavisly marker).
  brd = NxS1C.board('BRD-1', 201, schema: 1)
  NxS1C::BB.write_config_keys!(brd, 'appliance_expects' => %w[sink])
  NxTest.assert_equal(1, NxS1C.cfg_of(brd)['config_schema'])
end

NxTest.test('S1-C (P1): STARSIA schema = akcia sa ODMIETNE (marker migruje LEN prestavba)') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  model = NxS1C::FakeModel.new
  legacy = NxS1C.cabinet('CAB-3', 303, schema: 15)
  NxS1C.with_stubs([NxS1C.scan_stub(cabinets: [legacy])]) do
    inst, _t, err = NxS1C::PANEL.appliance_expects_entity(model, legacy, 'cabinet', 'CAB-3',
                                                          'CAB-3', { 'pid' => 303 })
    NxTest.assert(inst.nil?)
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_OLDER, err)
    NxTest.assert(err.include?('prestav'), 'hlaska hovori, CO ma pouzivatel urobit')
  end
  NxTest.assert_equal(15, NxS1C.cfg_of(legacy)['config_schema'], 'marker ostal nedotknuty')
  NxTest.refute(NxS1C.cfg_of(legacy).key?('appliance_expects'), 'a nic sa nezapisalo')

  # AKTUALNA schema prejde.
  fresh = NxS1C.cabinet('CAB-4', 304, schema: NxS1C::CB::CONFIG_SCHEMA)
  NxS1C.with_stubs([NxS1C.scan_stub(cabinets: [fresh])]) do
    inst, target, err = NxS1C::PANEL.appliance_expects_entity(model, fresh, 'cabinet', 'CAB-4',
                                                              'CAB-4', { 'pid' => 304 })
    NxTest.assert(err.nil?, err.to_s)
    NxTest.assert_equal(fresh, inst)
    NxTest.assert_equal('cabinet', target['kind'])
  end
  # DOSKA ma vlastnu hlasku a vlastny prah.
  brd = NxS1C.board('BRD-2', 202, schema: 1)
  NxS1C.with_stubs([NxS1C.scan_stub(boards: [brd])]) do
    _i, _t, err = NxS1C::PANEL.appliance_expects_entity(model, brd, 'board', 'BRD-2', 'BRD-2',
                                                        { 'pid' => 202 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_OLDER_BOARD, err)
  end
end

NxTest.test('S1-C (P1): STALE guardy zasuviek/zavesov/vyklopov po zapise STALE hlasia RED') do
  # Skrinka postavena PRED aktivaciou receptov zasuviek (schema 4) s uz
  # klasifikovanym celom — `drawer_stale_issue` z nej robi RED.
  cfg = { 'config_schema' => NxS1C::CB::DRAWER_ACTIVATION_SCHEMA - 1, 'type' => 'lower',
          'front_items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                              'drawer' => { 'construction' => 'metal' } }] }
  before = NxS1C::BOM.drawer_stale_issue('CAB-5', 105, cfg)
  NxTest.refute(before.nil?, 'vychodisko: stara skrinka RED hlasi')

  inst = NxS1C::FakeInst.new(105)
  NxS1C::STORE.write(inst, { kind: 'cabinet', cabinet_id: 'CAB-5', config: cfg })
  NxS1C::CB.write_config_keys!(inst, 'appliance_expects' => %w[oven])
  after = NxS1C::BOM.drawer_stale_issue('CAB-5', 105, NxS1C.cfg_of(inst))
  NxTest.refute(after.nil?,
                'config-only zapis NESMIE zhasnut RED — marker je proveniencia stavby')
  NxTest.assert_equal(before['code'], after['code'])
  # To iste pre zavesy a vyklopy — vsetky tri citaju TEN ISTY marker.
  hcfg = { 'config_schema' => NxS1C::CB::HINGE_ACTIVATION_SCHEMA - 1, 'type' => 'lower',
           'hardware' => [{ 'generic_type' => 'hinge', 'owner_part_key' => 'front:F1/panel' }],
           'front_items' => [{ 'id' => 'F1', 'type' => 'door' }] }
  hinst = NxS1C::FakeInst.new(106)
  NxS1C::STORE.write(hinst, { kind: 'cabinet', cabinet_id: 'CAB-6', config: hcfg })
  NxS1C::CB.write_config_keys!(hinst, 'appliance_expects' => %w[oven])
  NxTest.refute(NxS1C::BOM.hinge_stale_issue('CAB-6', 106, NxS1C.cfg_of(hinst)).nil?,
                'zavesy tiez ostavaju RED')
  NxTest.assert(NxS1C::BOM.pre_lift_build?(NxS1C.cfg_of(hinst)),
                'a skrinka je dalej „postavena pred vyklopmi"')
end

NxTest.test('S1-C (C4): zapis do configu z NOVSEJ verzie sa ODMIETNE (nic sa nezahodi)') do
  cab = NxS1C.cabinet('CAB-2', 102, schema: 99)
  begin
    NxS1C::CB.write_config_keys!(cab, 'appliance_expects' => %w[oven])
    NxTest.assert(false, 'zapis mal vyhodit vynimku')
  rescue StandardError => e
    NxTest.assert(e.message.include?('novšej verzie'), e.message)
  end
  NxTest.refute(NxS1C.cfg_of(cab).key?('appliance_expects'), 'config je nedotknuty')

  # DOSKA ma vlastny NEZAVISLY kontrakt (marker 2).
  brd = NxS1C.board('BRD-1', 201)
  NxS1C::BB.write_config_keys!(brd, 'appliance_expects' => %w[sink])
  NxTest.assert_equal(%w[sink], NxS1C.cfg_of(brd)['appliance_expects'])
  NxTest.assert_equal(NxS1C::BB::BOARD_CONFIG_SCHEMA, NxS1C.cfg_of(brd)['config_schema'])
end

NxTest.test('S1-C: ocakavanie prezije prestavbu (`normalize` -> config -> params)') do
  params = NxS1C::CB.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                               'depth' => 560.0, 'thickness' => 18.0,
                               'appliance_expects' => %w[oven])
  cfg = JSON.parse(NxS1C::CB.cabinet_config(params).to_json)
  NxTest.assert_equal(%w[oven], cfg['appliance_expects'])
  back = NxS1C::CB.config_to_params(cfg)
  NxTest.assert_equal(%w[oven], back[:appliance_expects] || back['appliance_expects'])
end

# ---------------------------------------------------------------------------
# 6) AKCIA `set_appliance_expects` — GUARDY (C6, C7, C8, C14)
# ---------------------------------------------------------------------------

NxTest.test('S1-C: whitelist panela pozna `set_appliance_expects`') do
  src = NxS1C.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.assert(src.include?("cb(dlg, 'set_appliance_expects')"), 'callback je registrovany')
end

NxTest.test('S1-C (C6): ciel sa overuje CELY — echo ID, PID, jednoznacnost, odpojeny') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  model = NxS1C::FakeModel.new
  cab = NxS1C.cabinet('CAB-3', 303)
  NxS1C.with_stubs([NxS1C.scan_stub(cabinets: [cab])]) do
    inst, target, err = NxS1C::PANEL.appliance_expects_entity(
      model, cab, 'cabinet', 'CAB-3', 'CAB-3', { 'pid' => 303 }
    )
    NxTest.assert(err.nil?, err.to_s)
    NxTest.assert_equal(cab, inst)
    NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-3', 'pid' => 303 }, target)

    # ECHO z CUDZIEHO vyberu
    _, _, e1 = NxS1C::PANEL.appliance_expects_entity(model, cab, 'cabinet', 'CAB-3', 'CAB-9',
                                                     { 'pid' => 303 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_STALE, e1)
    # PRAZDNE echo sa NETOLERUJE (riadok ho kresli vzdy)
    _, _, e2 = NxS1C::PANEL.appliance_expects_entity(model, cab, 'cabinet', 'CAB-3', '',
                                                     { 'pid' => 303 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_STALE, e2)
    # RECYKLOVANE ID: PID nesedi
    _, _, e3 = NxS1C::PANEL.appliance_expects_entity(model, cab, 'cabinet', 'CAB-3', 'CAB-3',
                                                     { 'pid' => 999 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_STALE, e3)
    # CHYBAJUCI PID (stary DOM)
    _, _, e4 = NxS1C::PANEL.appliance_expects_entity(model, cab, 'cabinet', 'CAB-3', 'CAB-3', {})
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_STALE, e4)
  end
end

NxTest.test('S1-C (C6): dva kusy s tym istym ID a ODPOJENY dielec zapis ODMIETNU') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  model = NxS1C::FakeModel.new
  cab = NxS1C.cabinet('CAB-3', 303)
  twin = NxS1C.cabinet('CAB-3', 304)
  NxS1C.with_stubs([NxS1C.scan_stub(cabinets: [cab, twin])]) do
    _, _, err = NxS1C::PANEL.appliance_expects_entity(model, cab, 'cabinet', 'CAB-3', 'CAB-3',
                                                      { 'pid' => 303 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_AMBIG, err)
  end
  NxS1C.with_stubs([NxS1C.scan_stub(cabinets: [cab], detached: { 'CAB-3' => 1 })]) do
    _, _, err = NxS1C::PANEL.appliance_expects_entity(model, cab, 'cabinet', 'CAB-3', 'CAB-3',
                                                      { 'pid' => 303 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_DETACH, err)
  end
  newer = NxS1C.cabinet('CAB-4', 305, schema: 99)
  NxS1C.with_stubs([NxS1C.scan_stub(cabinets: [newer])]) do
    _, _, err = NxS1C::PANEL.appliance_expects_entity(model, newer, 'cabinet', 'CAB-4', 'CAB-4',
                                                      { 'pid' => 305 })
    NxTest.assert_equal(NxS1C::PANEL::APPL_MSG_NEWER, err)
  end
end

NxTest.test('S1-C: VIAZANU kategoriu sa odstranit NEDA (osirely zaznam ju nezamkne)') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  model = NxS1C::FakeModel.new
  cab = NxS1C.cabinet('CAB-3', 303, refs: [NxS1C.ref('I-1', 'oven')], expects: %w[oven])
  items = [NxS1C.item('I-1', 'oven', 'cabinet', 'CAB-3')]
  NxS1C.with_stubs([[NxS1C::PANEL, :appliance_items, ->(_m) { items }]]) do
    msg = NxS1C::PANEL.appliance_expects_locked(model, cab, [])
    NxTest.refute(msg.nil?, 'viazana rura drzi svoje ocakavanie')
    NxTest.assert(msg.include?('odpoj'), msg.to_s)
    NxTest.assert(NxS1C::PANEL.appliance_expects_locked(model, cab, %w[oven]).nil?,
                  'ponechanie tej istej kategorie je v poriadku')

    # OSIRELY zaznam (polozka uz neexistuje) ocakavanie NEZAMYKA.
    orphan = NxS1C.cabinet('CAB-4', 304, refs: [NxS1C.ref('ZOMBIE', 'oven')], expects: %w[oven])
    NxTest.assert(NxS1C::PANEL.appliance_expects_locked(model, orphan, []).nil?,
                  'inak by osirely zaznam navzdy zamkol ocakavanie, ktore nikto neplni')
  end
end

NxTest.test('S1-C (C8): NEZMENENY vysledok = ZIADNA operacia (ziadny prazdny krok Spat)') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  model = NxS1C::FakeModel.new
  cab = NxS1C.cabinet('CAB-3', 303, expects: %w[oven])
  target = { 'kind' => 'cabinet', 'id' => 'CAB-3', 'pid' => 303 }
  NxS1C.with_stubs([[NxS1C::PANEL, :push_selected, ->(_m, **_k) { true }],
                    [NxS1C::PANEL, :set_status, ->(msg, err = false) { [msg, err] }]]) do
    out = NxS1C::PANEL.appliance_expects_write(model, cab, target, NxS1C.cfg_of(cab), %w[oven])
    NxTest.assert_equal([], model.ops, 'ten isty zoznam = model sa nedotkol')
    NxTest.assert_equal([NxS1C::PANEL::APPL_MSG_EXPECTS_SAME, false], out)

    NxS1C::PANEL.appliance_expects_write(model, cab, target, NxS1C.cfg_of(cab), %w[oven microwave])
    NxTest.assert_equal([NxS1C::PANEL::APPL_EXPECTS_OP], model.ops, 'JEDNA operacia = 1 Spat')
    NxTest.assert_equal(1, model.committed)
    NxTest.assert_equal(%w[oven microwave], NxS1C.cfg_of(cab)['appliance_expects'])

    # `[]` kluc ZRUSI.
    NxS1C::PANEL.appliance_expects_write(model, cab, target, NxS1C.cfg_of(cab), [])
    NxTest.refute(NxS1C.cfg_of(cab).key?('appliance_expects'))
    NxTest.assert_equal(2, model.committed)
  end
end

NxTest.test('S1-C (C7/C14): poradie handlera — bariera, ciel, guardy, operacia, refresh') do
  body = NxS1C.body_of(NxS1C.src('noxun_engine', 'ui', 'panel', 'actions_appliance.rb'),
                       'handle_set_appliance_expects')
  NxTest.refute(body.empty?, 'handler sa nasiel')
  i_doc = body.index('foreign_document?')
  i_busy = body.index('observer_idle?')
  i_target = body.index('appliance_expects_target')
  i_valid = body.index('validate_expects')
  i_lock = body.index('appliance_expects_locked')
  i_write = body.index('appliance_expects_write')
  NxTest.assert(i_doc && i_busy && i_target && i_valid && i_lock && i_write, body)
  NxTest.assert(i_doc < i_busy, 'identita dokumentu je PRVA')
  NxTest.assert(i_busy < i_target, 'ciel sa cita AZ PO bariere observera (C7)')
  NxTest.assert(i_target < i_valid, 'druh vlastnika urcuje, co sa smie ocakavat')
  NxTest.assert(i_valid < i_lock && i_lock < i_write, 'guardy PRED zapisom')
  # Codex #385 kolo 1 (P2): KAZDE odmietnutie posiela cerstvu kartu — klient si
  # po odoslani ovladac zamyka a odomkne ho az novy payload.
  NxTest.assert_equal(5, body.scan('appliance_expects_refused').length,
                      'vsetky styri guardy AJ `rescue` idu cez jednu cestu s refreshom')
  rbody = NxS1C.body_of(NxS1C.src('noxun_engine', 'ui', 'panel', 'actions_appliance.rb'),
                        'appliance_expects_refused')
  NxTest.assert(rbody.index('push_selected') < rbody.index('set_status'),
                'NAJPRV cerstva karta (odomkne riadok), az potom hlaska')
  NxTest.assert(rbody.include?('dedup: false'), 'zapis sa nekonal — netreba dedup prestavbu')

  wbody = NxS1C.body_of(NxS1C.src('noxun_engine', 'ui', 'panel', 'actions_appliance.rb'),
                        'appliance_expects_write')
  NxTest.assert(wbody.index('start_operation') < wbody.index('commit_operation'))
  NxTest.assert(wbody.include?('CabinetBuilder.guarded'),
                'inak by observer z zapisu configu spravil ghost prestavbu')
  NxTest.assert(wbody.include?('abort_safely'), 'vynimka = abort, nie polovicny stav')
  NxTest.assert(wbody.index('start_operation') < wbody.index('refresh_if_open(bump: true)'),
                'C14: zdvih generacie Studia je AZ PO uspesnom zapise')
  NxTest.refute(wbody.include?('rebuild'), 'ocakavanie NIC nekresli — ziadna prestavba')
end

# ---------------------------------------------------------------------------
# 7) GUARDY DAVKY
# ---------------------------------------------------------------------------

NxTest.test('S1-C: popisky v 4. pade pokryvaju `CATEGORIES` PRESNE') do
  NxTest.assert_equal(NxS1C::AC::CATEGORIES.sort, NxS1C::AC::CATEGORY_LABELS_ACC.keys.sort,
                      'ziadny kod bez popisku a ziadny popisok bez kodu')
  NxTest.assert(NxS1C::AC::CATEGORY_LABELS_ACC.values.none? { |v| v.to_s.strip.empty? })
  NxTest.assert_equal('rúru', NxS1C::AC.category_label_acc('oven'))
  NxTest.assert_equal('nieco', NxS1C::AC.category_label_acc('nieco'), 'neznamy kod = kod')
end

NxTest.test('S1-C: `?v=` vo vsetkych html = presne VERSION') do
  ver = NxTest::LOADER_VERSION
  Dir[File.join(NxTest::ROOT, 'noxun_engine', 'ui', '*.html')].each do |path|
    File.read(path, encoding: 'UTF-8').scan(/\?v=([0-9.]+)/).flatten.each do |v|
      NxTest.assert_equal(ver, v, File.basename(path))
    end
  end
end

NxTest.test('S1-C: novy JS panela pozna pole modalu aj riadok volby') do
  html = NxS1C.src('noxun_engine', 'ui', 'panel.html')
  NxTest.assert(html.include?('id="tplSaveExpects"'), 'D-14 modal ma pole „Očakáva"')
  %w[fridge oven microwave].each do |cat|
    NxTest.assert(html.include?("data-tplexp=\"#{cat}\""), cat)
  end
  NxTest.refute(html.include?('data-tplexp="dishwasher"'),
                'umyvacku modal neponuka — pri slote je volba dana')
  js = NxS1C.src('noxun_engine', 'ui', 'js', 'appliance_row.js')
  NxTest.assert(js.include?('set_appliance_expects'), 'riadok posiela vlastny callback')
  NxTest.refute(js.include?('CATEGORY'), 'JS ziadnu mapu popiskov nema — text sklada server')
end
