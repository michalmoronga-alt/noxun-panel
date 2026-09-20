# frozen_string_literal: true
# S1-E — SLOT UMYVACKY (novy typ korpusu `dishwasher`).
#
# Slot nie je korpus: nema boky, dno, strop, chrbat ani zony. Ma JEDEN vyrobny
# dielec (celo cez modul ciel) a telo spotrebica ako REFERENCIU — vec, ktoru
# zakaznik kupuje a my ju len ukazujeme.
#
# PRECO GUARD TESTY A NIE KLIKANIE:
#   1) REFERENCIA NESMIE BYT DIELEC. Keby telo umyvacky preslo cez `parts`,
#      renderer dielcov by mu zapisal `kind: 'part'` a kusovnik, VEPO aj nakup
#      by ho zapocitali ako dosku, ktoru nikdy nikto nevyrobi. Kontrakt je
#      preto UZKY (vlastny zoznam `plan[:references]`, vlastny validator)
#      a testuje sa PRIAMO, nie cez vysledok kusovnika.
#   2) VAZBA NA SPOTREBIC MA DVE PROTICHODNE POZIADAVKY: musi PREZIT bezne
#      cesty (prestavba, materialy, scale) a musi ZANIKNUT v kopii. Jedna
#      chyba na ktorejkolvek strane znamena bud sirotu v zakazke, alebo dve
#      skrinky, ktore tvrdia, ze v nich stoji ta ista umyvacka.
#   3) JEDNA HODNOTA, VIAC MIEST. Hranice slotu ziju v Ruby (`DW_*`),
#      v absorpcii scale (`ScaleWatch::MIN_BY_TYPE`) aj v JS (`form.js`).
#      Rozidene cisla = pasmo, v ktorom panel hodnotu pusti a builder ju ticho
#      klampne.
require_relative '../helper' unless defined?(NxTest)

# Headless: `ui/*.rb` nie su v require zozname helpera (UI vrstva) — sablonovy
# whitelist a vkladacia cesta si ich sada dotiahne sama (vzor test_s1e0).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates')
end

module NxS1E
  module_function

  def cb
    Noxun::Engine::CabinetBuilder
  end

  def cn
    Noxun::Engine::Construction
  end

  def bp
    Noxun::Engine::BuildPlan
  end

  def src(*rel)
    File.read(File.join(NxTest::ROOT, *rel), encoding: 'UTF-8')
  end

  # Slot 60 cm v „Michalovych" hodnotach z debaty 20.9.: linka 930, telo 820,
  # sokel 64, celo 776 (vyplň hore 90 mm sa rieši rucne).
  def slot(over = {})
    cb.normalize({ 'type' => 'dishwasher', 'width' => 600.0, 'height' => 930.0,
                   'depth' => 560.0, 'dw_class' => 600, 'dw_body_height' => 820.0,
                   'dw_front_bottom' => 64.0, 'dw_front_height' => 776.0 }.merge(over))
  end

  def plan(cfg = slot)
    cn.build_plan(cfg, 'CAB-007')
  end

  # Config tak, ako ho zapise JEDINY zapisovy bod (`cabinet_config`), cez JSON
  # round-trip — presne to, co prezije cesta do modelu.
  def stored(cfg)
    JSON.parse(cb.cabinet_config(cfg).to_json)
  end

  # Vyrobne dielce planu (referencia medzi nimi BYT NESMIE).
  def parts(pl)
    pl[:parts]
  end

  def refs(pl)
    Array(pl[:references])
  end

  # Zaznam slotu pre Kontrolu — TOU ISTOU funkciou, akou ho stavia `Bom.collect`.
  def slot_record(cfg, oid = 'CAB-007', pid = 42)
    Noxun::Engine::Bom.appliance_slot_record(oid, pid, stored(cfg))
  end

  # REALNA cesta zberu do Kontroly: `Bom` -> `Validation.run` (nie izolovana
  # fixtura — kluc `appliance_slots` musi sediet na oboch stranach).
  def control(cfg)
    Noxun::Engine::Validation.run({ appliance_slots: [slot_record(cfg)] })
  end

  def codes(res)
    Array(res['items']).map { |i| i['stable_key'].to_s.split('|').last }
  end

  def form_js
    @form_js ||= src('noxun_engine', 'ui', 'js', 'form.js')
  end

  # Dvojica [min, max] z JS zoznamu LIMITS / TYPE_LIMITS (suroví text — guard
  # ma padnut aj vtedy, ked by JS sada nebezala).
  def js_limit(block_re, id)
    block = form_js[block_re, 1].to_s
    NxTest.assert(!block.empty?, 'v form.js sa nenasiel hladany zoznam limitov')
    m = block.match(/\b#{id}\s*:\s*\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]/)
    NxTest.assert(m, "v zozname chyba pole #{id}")
    [m[1].to_f, m[2].to_f]
  end

  # `ScaleWatch::MIN_BY_TYPE` sa cita zo ZDROJA — `core/scale_observer.rb`
  # sa v helperi NENACITAVA (potrebuje zive SketchUp API); rovnaky vzor ako
  # `NxS1E0.observer_min`.
  def observer_slot_min
    src_txt = src('noxun_engine', 'core', 'scale_observer.rb')
    line = src_txt[/MIN_BY_TYPE\s*=\s*\{\s*'dishwasher'\s*=>\s*\{(.*?)\}/m, 1].to_s
    NxTest.assert(!line.empty?, 'v scale_observer.rb sa nenasla MIN_BY_TYPE dishwasher')
    line.scan(/'(\w+)'\s*=>\s*(-?[\d.]+)/).to_h { |key, value| [key, value.to_f] }
  end
end

# ---------------------------------------------------------------------------
# 1) TYP A NORMALIZACIA
# ---------------------------------------------------------------------------

NxTest.test('S1-E R1: TYPES je JEDINY zoznam typov a obsahuje dishwasher') do
  NxTest.assert_equal(%w[lower upper dishwasher], NxS1E.cb::TYPES)
  # Neznamy typ sa (ako doteraz) sklapa na dolnu skrinku — skrinku z NOVSEJ
  # verzie zastavi dopredny guard EST PRED normalizaciou.
  NxTest.assert_equal('lower', NxS1E.cb.normalize('type' => 'nieco')[:type])
  NxTest.assert_equal('dishwasher', NxS1E.slot[:type])
end

NxTest.test('S1-E R1: slot ma podporu `none` — sokel cela NIKDY netecie do floor_height') do
  cfg = NxS1E.slot('floor_height' => 150.0)
  NxTest.assert_close(0.0, cfg[:floor_height], 0.01, 'floor_height slotu je vzdy 0')
  NxTest.assert_close(64.0, cfg[:dw_front_bottom], 0.01, 'sokel zije vo vlastnom poli')
  NxTest.assert_equal('none', cfg[:plinth_mode])
  NxTest.assert_equal('none', NxS1E.cn.support_type(cfg),
                      'bez toho by pravidla vydali nohy aj prichyty sokla')
end

NxTest.test('S1-E R1: slot NEVYDA ziadnu polozku kovania korpusu (nohy, prichyt, zavesenie)') do
  hw = NxS1E.plan[:hardware]
  %w[leg plinth_clip wall_hanger hinge].each do |gt|
    NxTest.refute(hw.any? { |h| h['generic_type'].to_s == gt },
                  "slot nesmie dostat polozku #{gt}")
  end
end

NxTest.test('S1-E E1 (BLOCKER): sirka slotu sa NEKLAMPUJE na triedu') do
  # Uzky slot sa POSTAVI — nedostatocnu sirku hlasi Kontrola ORANGE, nikdy
  # neblokuje prestavbu (semafor varuje, nezastavuje).
  cfg = NxS1E.slot('width' => 590.0)
  NxTest.assert_close(590.0, cfg[:width], 0.01, 'sirka ostava taka, aku zadal clovek')
  NxTest.assert_equal(600, cfg[:dw_class], 'a trieda sa nemeni podla sirky')
  NxTest.assert(NxS1E.plan(cfg)[:parts].length.positive?, 'geometria sa aj tak postavi')
end

NxTest.test('S1-E E1: hranice sirky a vysky su NA JEDNOM mieste (Ruby, scale, JS)') do
  NxTest.assert_equal([300.0, 1200.0], NxS1E.cb::DW_WIDTH_RANGE)
  NxTest.assert_equal([500.0, 1200.0], NxS1E.cb::DW_HEIGHT_RANGE)
  NxTest.assert_close(300.0, NxS1E.cb.normalize('type' => 'dishwasher', 'width' => 10.0)[:width])
  NxTest.assert_close(1200.0, NxS1E.cb.normalize('type' => 'dishwasher', 'width' => 9000.0)[:width])
  NxTest.assert_close(500.0, NxS1E.cb.normalize('type' => 'dishwasher', 'height' => 10.0)[:height])

  omin = NxS1E.observer_slot_min
  NxTest.assert_close(NxS1E.cb::DW_WIDTH_RANGE[0], omin['width'], 0.01,
                      'absorpcia scale ma TU ISTU spodnu hranicu sirky')
  NxTest.assert_close(NxS1E.cb::DW_HEIGHT_RANGE[0], omin['height'], 0.01,
                      'a tu istu hranicu vysky')

  jw = NxS1E.js_limit(/var\s+TYPE_LIMITS\s*=\s*\{\s*dishwasher:\s*\{(.*?)\}\s*\};/m, 'width')
  jh = NxS1E.js_limit(/var\s+TYPE_LIMITS\s*=\s*\{\s*dishwasher:\s*\{(.*?)\}\s*\};/m, 'height')
  NxTest.assert_equal(NxS1E.cb::DW_WIDTH_RANGE, jw, 'panel ma ten isty rozsah sirky')
  NxTest.assert_equal(NxS1E.cb::DW_HEIGHT_RANGE, jh, 'a ten isty rozsah vysky')
end

NxTest.test('S1-E R1: rozsahy poli slotu su zrkadlom v Ruby aj v JS') do
  ranges = NxS1E.cb::DW_RANGES
  NxTest.assert_equal([700.0, 1000.0], ranges[:dw_body_height])
  NxTest.assert_equal([0.0, 300.0], ranges[:dw_front_bottom])
  NxTest.assert_equal([300.0, 1200.0], ranges[:dw_front_height])
  ranges.each do |key, want|
    got = NxS1E.js_limit(/var\s+LIMITS\s*=\s*\{(.*?)\};/m, key.to_s)
    NxTest.assert_equal(want, got, "form.js ma pre #{key} ten isty rozsah")
  end
  # Presah cela NAD vysku linky sa NEOBMEDZUJE — celo 1200 na linke 930 prejde.
  cfg = NxS1E.slot('dw_front_height' => 1200.0)
  NxTest.assert_close(1200.0, cfg[:dw_front_height], 0.01)
end

NxTest.test('S1-E R1: trieda je UZAVRETY slovnik (600 | 450)') do
  NxTest.assert_equal(600, NxS1E.slot('dw_class' => 999)[:dw_class], 'neznama trieda -> default')
  NxTest.assert_equal(450, NxS1E.slot('dw_class' => 450)[:dw_class])
  d450 = NxS1E.cn.dw_class_dims(450)
  NxTest.assert_close(448.0, d450[:body_w])
  NxTest.assert_equal('45', d450[:label])
end

# ---------------------------------------------------------------------------
# 2) PLAN: JEDEN VYROBNY DIELEC + JEDNA REFERENCIA
# ---------------------------------------------------------------------------

NxTest.test('S1-E R3: plan slotu = presne JEDEN vyrobny dielec (rola false_front)') do
  pl = NxS1E.plan
  NxTest.assert_equal(1, NxS1E.parts(pl).length, 'slot vyraba JEDINE celo')
  pd = NxS1E.parts(pl).first
  NxTest.assert_equal('false_front', pd[:role], 'typ `blind` emituje rolu blendy, nie dvierok')
  NxTest.assert_equal('front:F1/blind', pd[:part_key].to_s,
                      'kluc je klucom BLENDY (E10), nie wing:single')
  NxTest.assert_equal(:front, pd[:material], 'celo dedi materialovy kanal ciel')
  NxTest.refute(NxS1E.parts(pl).any? { |p| %w[side_left side_right bottom top back].include?(p[:role]) },
                'slot nema boky, dno, strop ani chrbat')
  NxTest.assert_equal([], pl[:zones], 'ani zony')
end

NxTest.test('S1-E R3: celo stoji na virtualnom otvore (sokel .. sokel + vyska cela)') do
  pl = NxS1E.plan
  pd = NxS1E.parts(pl).first
  NxTest.assert_close(64.0, pd[:origin][2], 0.01, 'spodna hrana cela = dw_front_bottom')
  NxTest.assert_close(776.0, pd[:box][2], 0.01, 'vyska cela = dw_front_height')
  # Bocne medzery ciel PLATIA (default 2 mm z kazdej strany).
  NxTest.assert_close(2.0, pd[:origin][0], 0.01)
  NxTest.assert_close(596.0, pd[:box][0], 0.01)
end

NxTest.test('S1-E E8: `front_opening` je JEDINA autorita otvoru (a pre korpus sa NEMENI)') do
  op = NxS1E.cn.front_opening(NxS1E.slot)
  NxTest.assert_close(64.0, op[:z0], 0.01)
  NxTest.assert_close(776.0, op[:h], 0.01)
  low = NxS1E.cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                           'floor_height' => 100.0)
  lop = NxS1E.cn.front_opening(low)
  NxTest.assert_close(100.0, lop[:z0], 0.01, 'dolna skrinka ma otvor od sokla')
  NxTest.assert_close(620.0, lop[:h], 0.01, 'a vysku po vrch korpusu — presne ako doteraz')
end

NxTest.test('S1-E E9: jedno pevne celo je SERVEROVY invariant') do
  # Payload s dvoma celami aj s typom `door` sa pri normalizacii VZDY vrati
  # na jedno pevne celo `blind` s vyskou z `dw_front_height`.
  cfg = NxS1E.slot('fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto' },
                                             { 'id' => 'F2', 'type' => 'drawer_front' }] })
  items = cfg[:fronts]['items']
  NxTest.assert_equal(1, items.length)
  NxTest.assert_equal('blind', items[0]['type'])
  NxTest.assert_equal('fixed', items[0]['mode'])
  NxTest.assert_close(776.0, items[0]['height'], 0.01)
  # A ta ista otazka ako CISTY predikat pre zapisovu cestu panela.
  NxTest.assert(NxS1E.cb.slot_fronts_ok?(cfg[:fronts], 776.0))
  NxTest.refute(NxS1E.cb.slot_fronts_ok?(cfg[:fronts], 800.0), 'cudzia vyska sa odmietne')
  NxTest.refute(NxS1E.cb.slot_fronts_ok?({ 'items' => [] }, 776.0), 'prazdny zoznam tiez')
end

NxTest.test('S1-E E2 (BLOCKER): referencia ma VLASTNE miesto v plane, nikdy `parts`') do
  pl = NxS1E.plan
  NxTest.assert_equal(1, NxS1E.refs(pl).length)
  rd = NxS1E.refs(pl).first
  NxTest.assert_equal('ref:appliance_body', rd[:ref_key])
  NxTest.assert_equal('appliance_body', rd[:role])
  NxTest.assert_equal('reference', rd[:kind])
  NxTest.assert_equal('reference', rd[:production_class])
  NxTest.assert_equal(false, rd[:manufactured])
  NxTest.assert_equal('generic', rd[:source])
  NxTest.assert_close(598.0, rd[:box][0], 0.01, 'sirka generickeho tela triedy 600')
  NxTest.assert_close(555.0, rd[:box][1], 0.01)
  NxTest.assert_close(820.0, rd[:box][2], 0.01, 'vyska tela = dw_body_height')
  NxTest.assert_close(1.0, rd[:origin][0], 0.01, 'telo je vycentrovane v slote')
  NxTest.assert_close(0.0, rd[:origin][2], 0.01, 'a stoji na podlahe')
  # A NIKDY sa nesmie tvarit ako dielec.
  NxTest.refute(NxS1E.parts(pl).any? { |p| p[:role].to_s == 'appliance_body' })
end

NxTest.test('S1-E E2: `validate_references!` odmietne kazdu odchylku od kontraktu') do
  ok = NxS1E.refs(NxS1E.plan).first
  NxS1E.bp.validate_references!([ok]) # kontrola nepadne
  { manufactured: true, production_class: 'sheet', kind: 'part', role: 'shelf',
    source: 'vymyslene', label: '' }.each do |key, bad|
    NxTest.assert_raise(/BuildPlan/) { NxS1E.bp.validate_references!([ok.merge(key => bad)]) }
  end
  NxTest.assert_raise(/duplicitny ref_key/) { NxS1E.bp.validate_references!([ok, ok]) }
  NxTest.assert_raise(/box/) { NxS1E.bp.validate_references!([ok.merge(box: [0.0, 1.0, 1.0])]) }
end

NxTest.test('S1-E E2: plan BEZ referencii (dolna a horna skrinka) ostava NEDOTKNUTY') do
  low = NxS1E.cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                           'floor_height' => 100.0)
  pl = NxS1E.cn.build_plan(low, 'CAB-001')
  NxTest.refute(pl.key?(:references), 'kluc sa korpusovemu planu NEPRIDAVA')
  NxTest.assert_equal(5, NxS1E.bp::SCHEMA, 'plan sa neperzistuje, takze schema ostava')
end

NxTest.test('S1-E R4: konstanty zakladne tela ziju na JEDNOM mieste') do
  NxTest.assert_close(200.0, NxS1E.cn::DW_BASE_H)
  NxTest.assert_close(50.0, NxS1E.cn::DW_BASE_INSET_FRONT)
  NxTest.assert_close(20.0, NxS1E.cn::DW_BASE_INSET_SIDE)
  # Zrkadlo v nahlade (preview.js kresli zakladnu aj vo VKLADANI, kde ziadny
  # serverovy payload neexistuje).
  pv = NxS1E.src('noxun_engine', 'ui', 'js', 'preview.js')
  NxTest.assert(pv.include?('PV_DW_BASE_H = 200'), 'nahlad ma tu istu vysku zakladne')
  NxTest.assert(pv.include?('PV_DW_BASE_SIDE = 20'), 'aj odsadenie do stran')
  NxTest.assert(pv.include?('600: { w: 598, d: 555 }'), 'a rozmery generickeho tela 60')
  NxTest.assert(pv.include?('450: { w: 448, d: 550 }'), 'aj 45')
end

# ---------------------------------------------------------------------------
# 3) SCHEMA 16 A REZERVOVANE VAZBY
# ---------------------------------------------------------------------------

NxTest.test('S1-E R2: CONFIG_SCHEMA je 16 a slot nesie svoje polia') do
  NxTest.assert_equal(16, NxS1E.cb::CONFIG_SCHEMA)
  st = NxS1E.stored(NxS1E.slot)
  NxTest.assert_equal(16, st['config_schema'])
  NxTest.assert_equal('dishwasher', st['type'])
  NxTest.assert_equal('noxun-dishwasher', st['construction_preset'])
  NxTest.assert_equal(600, st['dw_class'])
  NxTest.assert_close(820.0, st['dw_body_height'], 0.01)
  NxTest.assert_close(64.0, st['dw_front_bottom'], 0.01)
  NxTest.assert_close(776.0, st['dw_front_height'], 0.01)
end

NxTest.test('S1-E R2: dolna skrinka NEDOSTALA ani jedno pole slotu (golden sa nehne)') do
  low = NxS1E.cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0)
  st = NxS1E.stored(low)
  NxS1E.cb::DW_KEYS.each { |k| NxTest.refute(st.key?(k.to_s), "config dolnej skrinky nema #{k}") }
  NxTest.refute(st.key?('appliance_refs'), 'ani rezervovane vazby')
  NxTest.refute(st.key?('appliance_expects'))
end

NxTest.test('S1-E R2: dopredny guard — schema 17 sa odmietne, 16 prejde') do
  st = NxS1E.stored(NxS1E.slot)
  NxTest.refute(NxS1E.cb.newer_config?(st), 'vlastny config prechadza')
  NxTest.assert(NxS1E.cb.newer_config?(st.merge('config_schema' => 17)))
  # Starsi plugin (schema 15): jeho `newer_config?` je presne toto porovnanie.
  NxTest.assert(NxS1E.cb.config_schema_of(st) > 15,
                'slot je pre schemu 15 NOVSI — prestavba by z neho spravila PLNY korpus')
end

NxTest.test('S1-E R2b: BOARD_CONFIG_SCHEMA je 2 a doska ma vlastny guard') do
  bb = Noxun::Engine::BoardBuilder
  NxTest.assert_equal(2, bb::BOARD_CONFIG_SCHEMA)
  NxTest.refute(bb.newer_config?('config_schema' => 2))
  NxTest.assert(bb.newer_config?('config_schema' => 3), 'doska schemy 3 sa odmietne')
  # Kontrakty su NEZAVISLE — cisla sa medzi sebou nikdy neporovnavaju.
  guard = NxS1E.src('noxun_engine', 'core', 'board_builder.rb')[/def newer_config\?\(cfg\).*?\n        end\n/m].to_s
  NxTest.refute(guard.include?('CabinetBuilder::CONFIG_SCHEMA'))
end

NxTest.test('S1-E E4: vazby PREZIJU normalize aj `config_to_params` (prestavba, materialy, scale)') do
  refs = [{ 'item_id' => 'uuid-1', 'category' => 'dishwasher' }]
  cfg = NxS1E.slot('appliance_refs' => refs, 'appliance_expects' => %w[dishwasher])
  NxTest.assert_equal(refs, cfg[:appliance_refs])
  NxTest.assert_equal(%w[dishwasher], cfg[:appliance_expects])
  st = NxS1E.stored(cfg)
  NxTest.assert_equal(refs, st['appliance_refs'])
  # Round-trip cez prestavbovu cestu (ULOZENY config -> params -> normalize).
  again = NxS1E.cb.normalize(NxS1E.cb.config_to_params(st))
  NxTest.assert_equal(refs, again[:appliance_refs], 'prestavba vazbu NESMIE stratit')
  NxTest.assert_equal(%w[dishwasher], again[:appliance_expects])
end

NxTest.test('S1-E E4: `strip_appliance_refs!` zahodi LEN vazbu, ocakavanie ostava') do
  st = NxS1E.stored(NxS1E.slot('appliance_refs' => [{ 'item_id' => 'uuid-1' }],
                               'appliance_expects' => %w[dishwasher]))
  params = NxS1E.cb.config_to_params(st)
  NxS1E.cb.strip_appliance_refs!(params)
  copy = NxS1E.cb.normalize(params)
  NxTest.assert_equal(nil, copy[:appliance_refs], 'kopia nevlastni ten isty spotrebic')
  NxTest.assert_equal(%w[dishwasher], copy[:appliance_expects], 'ale OCAKAVA ho')
end

NxTest.test('S1-E E4: VSETKY TRI kopirovacie vstupy volaju `strip_appliance_refs!`') do
  { 'noxun_engine/core/cabinet_builder.rb' => 'dedup_copies (natívna kopia)',
    'noxun_engine/tools/mower.rb' => 'kopia nastrojom',
    'noxun_engine/ui/panel/actions_cabinet.rb' => 'Vlozit kopiu' }.each do |rel, what|
    txt = NxS1E.src(*rel.split('/'))
    NxTest.assert(txt.include?('strip_appliance_refs!'), "#{what} zahadza vazbu")
  end
end

NxTest.test('S1-E E6: dedup DOSKY ma dopredny guard a zahadza LEN `appliance_refs`') do
  body = NxS1E.src('noxun_engine', 'core', 'board_builder.rb')[/def drop_appliance_refs!\(inst\).*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'helper existuje')
  NxTest.assert(body.include?('newer_config?'), 'novsia doska sa NEDOTKNE')
  NxTest.assert(body.include?("delete('appliance_refs')"), 'zahadza sa LEN vazba')
  NxTest.refute(body.include?('normalize'), 'ziadny normalize round-trip (dedup meni len identitu)')
  NxTest.refute(body.include?('appliance_expects'), 'ocakavanie ostava')
end

NxTest.test('S1-E R2b: config dosky nesie rezervovane kluce LEN ked nieco nesie') do
  bb = Noxun::Engine::BoardBuilder
  plain = bb.board_config(bb.normalize('role' => 'free_panel', 'name' => 'Doska'))
  NxTest.refute(plain.key?(:appliance_refs), 'bezna doska kluc nedostane')
  bound = bb.board_config(bb.normalize('role' => 'free_panel', 'name' => 'Doska',
                                       'appliance_refs' => [{ 'item_id' => 'uuid-9' }],
                                       'appliance_expects' => %w[sink]))
  NxTest.assert_equal([{ 'item_id' => 'uuid-9' }], bound[:appliance_refs])
  NxTest.assert_equal(%w[sink], bound[:appliance_expects])
end

# ---------------------------------------------------------------------------
# 4) SABLONY
# ---------------------------------------------------------------------------

NxTest.test('S1-E R2c: sablona nesie `dw_*` a OCAKAVANIE, vazbu NIKDY') do
  st = NxS1E.stored(NxS1E.slot('appliance_refs' => [{ 'item_id' => 'uuid-1' }],
                               'appliance_expects' => %w[dishwasher]))
  tc = Noxun::Engine::Panel.template_config_from(st)
  NxTest.assert_equal('dishwasher', tc['type'])
  NxTest.assert_equal(600, tc['dw_class'])
  NxTest.assert_close(776.0, tc['dw_front_height'], 0.01)
  NxTest.assert_equal(%w[dishwasher], tc['appliance_expects'])
  NxTest.refute(tc.key?('appliance_refs'), 'sablona nenesie vazbu na konkretny spotrebic')
  NxTest.assert_equal(16, tc['config_schema'], 'a stampuje aktualny marker')
end

NxTest.test('S1-E R2c: `merge_template` ZACHOVA vazby CIELA') do
  target = { 'appliance_refs' => [{ 'item_id' => 'uuid-1' }], 'appliance_expects' => %w[dishwasher],
             'part_overrides' => {}, 'hardware_overrides' => [] }
  tpl = { 'type' => 'dishwasher', 'width' => 600.0 }
  merged = Noxun::Engine::TemplatesDialog.merge_template(target, tpl)
  NxTest.assert_equal([{ 'item_id' => 'uuid-1' }], merged['appliance_refs'],
                      'aplikovanie sablony NESMIE odpojit spotrebic')
  NxTest.assert_equal(%w[dishwasher], merged['appliance_expects'])
  # Sablona s VLASTNYM ocakavanim ho prepise (spotrebicova sablona je prave o tom).
  m2 = Noxun::Engine::TemplatesDialog.merge_template(target, tpl.merge('appliance_expects' => %w[oven]))
  NxTest.assert_equal(%w[oven], m2['appliance_expects'])
  NxTest.assert_equal([{ 'item_id' => 'uuid-1' }], m2['appliance_refs'], 'vazba ostava cielu')
end

NxTest.test('S1-E E5: seed slotov nesie marker schemy (inak by ho starsi plugin sklopil na lower)') do
  seeds = Noxun::Engine::TemplateStore.build_predefined_slots
  NxTest.assert_equal(%w[Umývačka\ 60 Umývačka\ 45], seeds.map { |s| s['name'] })
  seeds.each do |s|
    cfg = s['config']
    NxTest.assert_equal('cabinet', s['kind'])
    NxTest.assert_equal('dishwasher', cfg['type'])
    NxTest.assert_equal(NxS1E.cb::CONFIG_SCHEMA, cfg['config_schema'],
                        'marker je POVINNY — starsi plugin by inak zo slotu spravil korpus')
    NxTest.assert_close(64.0, cfg['dw_front_bottom'], 0.01)
    NxTest.assert_close(776.0, cfg['dw_front_height'], 0.01)
  end
  NxTest.assert_equal(600, seeds[0]['config']['dw_class'])
  NxTest.assert_equal(450, seeds[1]['config']['dw_class'])
end

NxTest.test('S1-E E5: STARSI plugin (schema 15) seedovanu sablonu ODMIETNE') do
  # Simulacia: starsi plugin porovnava marker sablony proti SVOJEJ konstante.
  cfg = Noxun::Engine::TemplateStore.build_predefined_slots.first['config']
  NxTest.assert(NxS1E.cb.config_schema_of(cfg) > 15,
                'sablona je pre schemu 15 NOVSIA — `newer_template_refusal` ju zastavi')
end

NxTest.test('S1-E R6: seed STD je 5 a je MARKEROVY (zmazanu sablonu nevrati)') do
  ts = Noxun::Engine::TemplateStore
  NxTest.assert_equal(5, ts::STD)
  # `missing_slot_seed` je CISTA funkcia — nad zoznamom, kde uz sablona je,
  # vrati prazdno (preto sa seed nikdy neopakuje).
  have = ts.build_predefined_slots
  NxTest.assert_equal([], ts.missing_slot_seed(have), 'existujuce sablony sa neprepisu')
  NxTest.assert_equal(2, ts.missing_slot_seed([]).length, 'prazdny zoznam dostane obe')
  only60 = [have[0]]
  NxTest.assert_equal(['Umývačka 45'], ts.missing_slot_seed(only60).map { |s| s['name'] })
end

NxTest.test('S1-E: „Uložiť ako šablónu" pri slote typ NEPREPINA') do
  cfg = { 'type' => 'dishwasher' }
  note = Noxun::Engine::Panel.apply_template_type!(cfg, 'upper')
  NxTest.assert_equal('dishwasher', cfg['type'], 'slot sa na hornu skrinku prepnut neda')
  NxTest.assert_equal('', note)
  # Dolna a horna sa dalej prepinaju presne ako doteraz.
  low = { 'type' => 'lower' }
  Noxun::Engine::Panel.apply_template_type!(low, 'upper')
  NxTest.assert_equal('upper', low['type'])
end

# ---------------------------------------------------------------------------
# 5) VYSTUPY A KONTROLA
# ---------------------------------------------------------------------------

NxTest.test('S1-E E12: `Bom.appliance_slot_record` dava Kontrole udaje slotu') do
  rec = NxS1E.slot_record(NxS1E.slot)
  NxTest.assert_equal('CAB-007', rec['owner_id'])
  NxTest.assert_equal(42, rec['owner_pid'])
  NxTest.assert_close(600.0, rec['width'], 0.01)
  NxTest.assert_close(930.0, rec['height'], 0.01)
  NxTest.assert_close(820.0, rec['dw_body_height'], 0.01)
  NxTest.assert_close(598.0, rec['body_width'], 0.01, 'telo z TEJ ISTEJ tabulky ako builder')
  # Dolna skrinka zaznam NEDOSTANE — kontrola sa jej netyka.
  low = NxS1E.cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0)
  NxTest.assert_equal(nil, Noxun::Engine::Bom.appliance_slot_record('CAB-001', 1, NxS1E.stored(low)))
end

NxTest.test('S1-E R10: Kontrola hlasi `dw_body_fit`, ked sa telo do slotu nezmesti') do
  res = NxS1E.control(NxS1E.slot('width' => 590.0))
  NxTest.assert_equal(['dw_body_fit'], NxS1E.codes(res))
  it = res['items'].first
  NxTest.assert_equal('appliance', it['category'])
  NxTest.assert_equal('orange', it['severity'])
  NxTest.assert_equal('CAB-007', it['owner_id'], 'klik-select mieri na slot')
  NxTest.assert(it['message_sk'].include?('598'), 'veta menuje telo')
  NxTest.assert(it['message_sk'].include?('590'), 'aj sirku slotu')
end

NxTest.test('S1-E R10: `dw_height_fit` porovnava NASTAVENU vysku tela s vyskou linky') do
  res = NxS1E.control(NxS1E.slot('height' => 800.0))
  NxTest.assert_equal(['dw_height_fit'], NxS1E.codes(res))
  NxTest.assert(res['items'].first['message_sk'].include?('820'))
  NxTest.assert(res['items'].first['message_sk'].include?('800'))
  # Hranicna zhoda (telo presne po linku) nalez NEVYROBI.
  NxTest.assert_equal([], NxS1E.codes(NxS1E.control(NxS1E.slot('height' => 820.0))))
end

NxTest.test('S1-E R10: OBA nalezy naraz su DVA riadky (kod je sucastou stable_key)') do
  res = NxS1E.control(NxS1E.slot('width' => 500.0, 'height' => 700.0))
  NxTest.assert_equal(%w[dw_body_fit dw_height_fit].sort, NxS1E.codes(res).sort)
  keys = res['items'].map { |i| i['stable_key'] }
  NxTest.assert_equal(2, keys.uniq.length, 'dedup ich nesmie zliat')
end

NxTest.test('S1-E R10: zdravy slot nema ziadny nalez a chybajuci kluc kontrolu preskoci') do
  NxTest.assert_equal([], NxS1E.codes(NxS1E.control(NxS1E.slot)))
  res = Noxun::Engine::Validation.run({})
  NxTest.assert_equal(0, res['counts']['total'], 'zber bez slotov = ziadna kontrola')
end

NxTest.test('S1-E R11: kusovnik slotu = JEDEN riadok (celo), referencia nikde') do
  pl = NxS1E.plan
  pd = NxS1E.parts(pl).first
  rec = { 'name' => pd[:name], 'part_key' => pd[:part_key], 'owner_id' => 'CAB-007',
          'role' => pd[:role], 'length' => pd[:prod][:length], 'width' => pd[:prod][:width],
          'thickness' => pd[:prod][:thickness], 'quantity' => 1,
          'material_id' => 'K009', 'grain_direction' => 'none',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  out = Noxun::Engine::Bom.compute({ records: [rec] })
  NxTest.assert_equal(1, out[:rows].length, 'kusovnik vidi LEN celo')
  NxTest.assert_equal(1, out[:rows].first['quantity'])
end

NxTest.test('S1-E E11: Inspector a Kontrola tvrdia TO ISTE („Pod doskou")') do
  bad = NxS1E.slot('height' => 800.0)
  pay = Noxun::Engine::Panel.slot_payload(NxS1E.stored(bad))
  NxTest.assert_equal(false, pay['under_ok'], 'Inspector hlasi ✗')
  NxTest.assert_equal(['dw_height_fit'], NxS1E.codes(NxS1E.control(bad)), 'a Kontrola ORANGE')
  good = NxS1E.slot
  NxTest.assert_equal(true, Noxun::Engine::Panel.slot_payload(NxS1E.stored(good))['under_ok'])
  NxTest.assert_equal([], NxS1E.codes(NxS1E.control(good)))
end

NxTest.test('S1-E R7: payload slotu nesie vystupy informacneho stlpca') do
  pay = Noxun::Engine::Panel.slot_payload(NxS1E.stored(NxS1E.slot))
  NxTest.assert_equal('598 × 820 × 555', pay['body'])
  NxTest.assert_equal('generické 60', pay['body_note'])
  NxTest.assert_equal('840', pay['front_top'], 'sokel 64 + celo 776')
  NxTest.assert_equal('+20 nad telom', pay['front_over_text'])
  NxTest.assert_equal('90', pay['fill'], 'vyplň po liniu linky 930')
  NxTest.assert_equal('60 · bez modelu', pay['class_text'])
  # Dolna skrinka kluc NEDOSTANE.
  low = NxS1E.cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0)
  NxTest.assert_equal(nil, Noxun::Engine::Panel.slot_payload(NxS1E.stored(low)))
end

# ---------------------------------------------------------------------------
# 6) PARITA TYPOV NAPRIEC VRSTVAMI
# ---------------------------------------------------------------------------

NxTest.test('S1-E: JS pozna PRESNE tie iste typy ako Ruby') do
  core = NxS1E.src('noxun_engine', 'ui', 'js', 'core.js')
  m = core[/var\s+CAB_TYPES\s*=\s*\[(.*?)\];/m, 1].to_s
  js_types = m.scan(/'([a-z_]+)'/).flatten
  NxTest.assert_equal(NxS1E.cb::TYPES, js_types, 'core.js ma zrkadlo TYPES')

  ins = NxS1E.src('noxun_engine', 'ui', 'js', 'insert_state.js')
  mi = ins[/var\s+INSERT_TYPES\s*=\s*\[(.*?)\];/m, 1].to_s
  ins_types = mi.scan(/'([a-z_]+)'/).flatten
  NxTest.assert_equal(NxS1E.cb::TYPES + ['board'], ins_types,
                      'vkladacia karta ponuka vsetky typy + dosku')
end

NxTest.test('S1-E: panel prijme polia slotu (PARAM_KEYS) a posiela ich (CONSTRUCTION_FIELDS)') do
  NxS1E.cb::DW_KEYS.each do |k|
    NxTest.assert(Noxun::Engine::Panel::PARAM_KEYS.include?(k.to_s),
                  "apply whitelist pozna #{k}")
  end
  core = NxS1E.src('noxun_engine', 'ui', 'js', 'core.js')
  block = core[/var\s+CONSTRUCTION_FIELDS\s*=\s*\[(.*?)\];/m, 1].to_s
  NxS1E.cb::DW_KEYS.each do |k|
    NxTest.assert(block.include?("id:'#{k}'"), "form.js posiela #{k}")
  end
end

NxTest.test('S1-E E3: logicka obalka je zapojena vsade, kde sa doteraz citali bounds') do
  { 'noxun_engine/core/placement.rb' => 'next_x',
    'noxun_engine/tools/snaper.rb' => 'snap (ciel aj prekazka)',
    'noxun_engine/tools/mower.rb' => 'stred otacania' }.each do |rel, what|
    txt = NxS1E.src(*rel.split('/'))
    NxTest.assert(txt.include?('CabinetBuilder.envelope'), "#{what} pouziva obalku")
  end
  # A snaper si ju berie v OBOCH vetvach (ciel aj prekazka).
  sn = NxS1E.src('noxun_engine', 'tools', 'snaper.rb')
  NxTest.assert_equal(2, sn.scan(/noxun_envelope_box\(/).length - 1,
                      'obalka sa cita pri cieli aj pri prekazke')
end

NxTest.test('S1-E R12: VERSION je v oboch suboroch rovnaka a `?v=` sedi') do
  v = Noxun::Engine::VERSION
  main = NxS1E.src('noxun_engine', 'main.rb')
  NxTest.assert(main.include?("VERSION = '#{v}'"), 'main.rb drzi tu istu verziu')
  %w[panel.html studio.html].each do |f|
    html = NxS1E.src('noxun_engine', 'ui', f)
    html.scan(/\?v=([0-9.]+)/).flatten.uniq.each do |got|
      NxTest.assert_equal(v, got, "#{f}: cache-bust sedi s VERSION")
    end
  end
end
