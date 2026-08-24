# frozen_string_literal: true
# PICKER-2 — SERVEROVÁ časť: „Použité v projekte" v Štúdiu (`mat_used_ids`)
# a IDENTITA VARIANTOVEJ RODINY (`Materials.variant_family_key`), teda hranica,
# po ktorú sa smú hrúbky zlučovať do jedného riadku vyhľadávača.
#
# PICKER-1 túto skupinu v Štúdiu priznane NEMAL: sekcia drží počty pod kľúčom
# SKUPINY (`used`), kým vyhľadávač pýta ZOZNAM ID dosiek. Mapovať jedno na
# druhé v kliente by bolo hádanie, tak to server posiela rovno — v tom istom
# tvare, aký má panelový `used_ids_payload`.
#
# Čo táto sada stráži (a prečo to klikaním nezistíš):
#   1. TVAR musí sedieť s panelom (`sheets` / `edges` ako polia ID). Keby sa
#      rozišiel, ponuka by v jednom okne skupinu mala a v druhom ticho nie.
#   2. ŽIADNY DRUHÝ SKEN MODELU. Zdrojom je UŽ zozbieraný kusovník — presne to,
#      čo ŠT-2a raz odstránilo; nový sken by okno spomalil pri každom prepočte.
#   3. Dielec BEZ `owner_id` sa tu (na rozdiel od `used_where`) NEVYHADZUJE.
#      Tam ide o klikateľného vlastníka, tu o holú otázku „je tento materiál
#      v zákazke?" — a odpojený dielec v nej je.
#   4. ID sa neopakujú — zoznam ide do vyhľadávača, nie do štatistiky.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?

P2_STUDIO_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                          encoding: 'UTF-8')
P2_PAYLOADS_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads.rb'),
                            encoding: 'UTF-8')
P2_MATDLG_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog.rb'),
                          encoding: 'UTF-8')
P2MAT = Noxun::Engine::Materials

# Zaznam katalogu SCHEMA 2 — presne tie polia, ktore rozhoduju o IDENTITE.
def p2_sheet(over = {})
  { 'material_id' => 'M1', 'group_id' => 'G1', 'decor' => '5981', 'structure' => 'MG',
    'type' => 'DTDL', 'thickness' => 18.0 }.merge(over)
end

module NxP2Fix
  module_function

  def rec(owner, mat, edges = {})
    { 'name' => 'Dielec', 'owner_id' => owner, 'pid' => 1, 'role' => 'shelf',
      'length' => 600.0, 'width' => 500.0, 'thickness' => 18.0, 'quantity' => 1,
      'material_id' => mat, 'grain_direction' => 'none',
      'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.merge(edges) }
  end

  def collected(records)
    { records: records, hardware: [], hardware_overrides: [], cabinet_sets: {},
      placements: [], warnings: [], cabinets: 1, boards: 0 }
  end

  def sample
    [
      rec('CAB-001', 'H3303_18', { 'L1' => 'ABS_H3303_22' }),
      rec('CAB-001', 'H3303_36', {}),
      rec('CAB-002', 'H3303_18', { 'W1' => 'ABS_H3303_22' }), # opakovanie mat aj ABS
      rec('',        'HDF_3',    { 'L2' => 'ABS_INY_22' })    # dielec BEZ vlastnika
    ]
  end
end

NxTest.test('PICKER-2: `used_ids` nesie ID DOSIEK aj ABS z celej zakazky') do
  out = Noxun::Engine::StudioDialog.mat_used_ids(NxP2Fix.collected(NxP2Fix.sample))
  NxTest.assert_equal(%w[H3303_18 H3303_36 HDF_3], out['sheets'].sort)
  NxTest.assert_equal(%w[ABS_H3303_22 ABS_INY_22], out['edges'].sort)
end

NxTest.test('PICKER-2: dielec BEZ `owner_id` sa v `used_ids` POCITA') do
  out = Noxun::Engine::StudioDialog.mat_used_ids(NxP2Fix.collected(NxP2Fix.sample))
  # `used_where` taky riadok zahadzuje (nema klikatelneho vlastnika, review #4
  # ST-2d). Tu je otazka ina: material V ZAKAZKE JE, takze v skupine
  # „Pouzite v projekte" musi byt. Keby sa logika prebrala z `used_where`,
  # odpojeny dielec by dekor zo skupiny ticho vyhodil.
  NxTest.assert(out['sheets'].include?('HDF_3'),
                'HDF chrbat patri odpojenemu dielcu — a v zakazke je')
  NxTest.assert(out['edges'].include?('ABS_INY_22'), 'a jeho ABS tiez')
end

NxTest.test('PICKER-2: ID sa NEOPAKUJU') do
  out = Noxun::Engine::StudioDialog.mat_used_ids(NxP2Fix.collected(NxP2Fix.sample))
  NxTest.assert_equal(out['sheets'].uniq, out['sheets'])
  NxTest.assert_equal(out['edges'].uniq, out['edges'])
end

NxTest.test('PICKER-2: prazdne ID a chybajuce `edges` zoznam nezanesu') do
  recs = [NxP2Fix.rec('CAB-001', ''), { 'material_id' => 'X_18' },
          NxP2Fix.rec('CAB-002', 'Y_18', { 'L1' => '' })]
  out = Noxun::Engine::StudioDialog.mat_used_ids(NxP2Fix.collected(recs))
  NxTest.assert_equal(%w[X_18 Y_18], out['sheets'].sort,
                      'prazdny material_id nie je ID — do ponuky nepatri')
  NxTest.assert_equal([], out['edges'], 'zaznam bez `edges` nesmie padnut ani nic pridat')
end

NxTest.test('PICKER-2: prazdny zber = prazdne zoznamy, nie nil') do
  out = Noxun::Engine::StudioDialog.mat_used_ids({ records: nil })
  NxTest.assert_equal({ 'sheets' => [], 'edges' => [] }, out)
end

NxTest.test('PICKER-2: tvar `used_ids` je ZHODNY s panelovym `used_ids_payload`') do
  # Klient ma v oboch oknach ten isty jednoriadkovy hook
  # (`kind === 'abs' ? .edges : .sheets`). Keby sa kluce rozisli, skupina by
  # v jednom okne fungovala a v druhom by bola prazdna — bez chyby, bez stopy.
  NxTest.assert(P2_PAYLOADS_SRC.include?("{ 'sheets' =>"),
                'panel posiela sheets/edges')
  NxTest.assert(P2_STUDIO_SRC.include?("{ 'sheets' => sheets.keys, 'edges' => edges.keys }"),
                'Studio posiela ten isty tvar')
end

NxTest.test('PICKER-2: `used_ids` vznika z UZ zozbieraneho kusovnika, nie z noveho skenu') do
  body = P2_STUDIO_SRC[/def mat_used_ids\(collected\).*?\n        end/m].to_s
  NxTest.assert(!body.empty?, 'metoda existuje')
  NxTest.assert(body.include?('collected[:records]'), 'zdroj je zber, ktory sekcia uz ma')
  NxTest.assert(!body.include?('Sketchup.active_model') && !body.include?('Materials.used_'),
                'ziadny druhy prechod modelom (ST-2a to raz uz odstranilo)')
  NxTest.assert(P2_STUDIO_SRC.include?("'used_ids' => mat_used_ids(collected)"),
                'a payload sekcie ho naozaj nesie')
end

# --- IDENTITA VARIANTOVEJ RODINY (review #231 P1) ---------------------------
#
# Zlucovat sa smu LEN hrubky TOHO ISTEHO materialu. V SCHEMA 2 sa to iste
# cislo dekoru legalne opakuje u dvoch vyrobcov, ta ista skupina ma viac
# STRUKTUR a typy s formatom v identite (PD, zastena) sa lisia formatom alebo
# rubom. Keby tieto rozmery v kluci chybali, vyhladavac by zlucil dva RÔZNE
# materialy — dva cipy s ROVNAKOU hrubkou by boli nerozlisitelne a dala by sa
# vybrat cudzia cena, povrch aj format. Klient to hadat nesmie, preto kluc
# sklada server.

NxTest.test('PICKER-2: hrubky toho isteho materialu maju ROVNAKY kluc rodiny') do
  a = P2MAT.variant_family_key(p2_sheet('material_id' => 'A', 'thickness' => 18.0))
  b = P2MAT.variant_family_key(p2_sheet('material_id' => 'B', 'thickness' => 36.0))
  NxTest.assert_equal(a, b, 'hrubka do identity NEPATRI — je to prave to, co sa dava na cipy')
end

NxTest.test('PICKER-2: iny VYROBCA, ina STRUKTURA a iny TYP su ROZNE rodiny') do
  base = P2MAT.variant_family_key(p2_sheet)
  NxTest.assert(base != P2MAT.variant_family_key(p2_sheet('group_id' => 'G2')),
                'dva vyrobcovia s rovnakym cislom dekoru sa NESMU zlucit')
  NxTest.assert(base != P2MAT.variant_family_key(p2_sheet('structure' => 'BS')),
                'ina struktura je iny povrch, nie ina hrubka')
  NxTest.assert(base != P2MAT.variant_family_key(p2_sheet('type' => 'HDF')),
                'HDF nie je tensia verzia DTDL')
  NxTest.assert(base != P2MAT.variant_family_key(p2_sheet('decor' => '5982')),
                'iny dekor je samozrejme ina rodina')
end

NxTest.test('PICKER-2: FORMAT a RUB su sucastou identity (typy s formatom v identite)') do
  pd1 = p2_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0])
  pd2 = p2_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 900.0])
  NxTest.assert(P2MAT.variant_family_key(pd1) != P2MAT.variant_family_key(pd2),
                'dva formaty PD su dva materialy — presne to riesil aj label (GH #95 P1)')
  z1 = p2_sheet('type' => 'ZASTENA', 'back_decor' => 'K552')
  z2 = p2_sheet('type' => 'ZASTENA', 'back_decor' => 'K553')
  NxTest.assert(P2MAT.variant_family_key(z1) != P2MAT.variant_family_key(z2),
                'iny rub zasteny je iny material')
end

NxTest.test('PICKER-2: UNI zaznamy sa NEZLUCUJU vobec') do
  u1 = P2MAT.variant_family_key(p2_sheet('material_id' => 'U1', 'uni' => true))
  u2 = P2MAT.variant_family_key(p2_sheet('material_id' => 'U2', 'uni' => true))
  NxTest.assert(u1 != u2,
                'kazdy UNI ma vlastnu rolu a jeho hrubka je len pracovny default')
end

NxTest.test('PICKER-2: kluc sa neda oklamat posunutim textu medzi polia') do
  # Text sa medzi polami posuva LEGALNE (2A-4b: "K009 PW"+"" vs "K009"+"PW"),
  # takze oddelovac musi byt taky, aky sa v datach nevyskytuje — inak by dva
  # rozne materialy dostali ten isty kluc a zlucili by sa do jedneho riadku.
  a = P2MAT.variant_family_key(p2_sheet('decor' => '5981 MG', 'structure' => 'PW'))
  b = P2MAT.variant_family_key(p2_sheet('decor' => '5981', 'structure' => 'MG PW'))
  NxTest.assert(a != b,
                'zlozky sa spajaju oddelovacom, ktory sa v datach nevyskytuje')
end

NxTest.test('PICKER-2: OBA payloady posielaju row_label aj row_key z JEDNEHO zdroja') do
  # Keby si kazde okno skladalo hranicu samo, ponuka by sa v Inspectore
  # a v Studiu zlucovala INAK — a nikto by si toho nevsimol, kym by sa
  # nevybral zly material.
  NxTest.assert(P2_PAYLOADS_SRC.include?("'row_label' => sheet_row_label(s, ctx)") &&
                P2_PAYLOADS_SRC.include?("'row_key' => Materials.variant_family_key(s)"),
                'panel posiela menovku riadku aj identitu rodiny')
  NxTest.assert(P2_MATDLG_SRC.include?("'row_label' => Panel.sheet_row_label(s, ctx)") &&
                P2_MATDLG_SRC.include?("'row_key' => Materials.variant_family_key(s)"),
                'Studio berie TIE ISTE dve metody, nekopiruje si logiku')
end

NxTest.test('PICKER-2: ULOZENY duplak sa v payloade prizna priznakom, nie tvarom ID') do
  # Duplak zapisany do katalogu ma bezne `material_id` a pozna sa VYHRADNE
  # podla `source_material_id`. Bez tohto priznaku by v ponuke vyzeral ako
  # kupena hruba doska, nedal by sa najst hladanim „duplak" — a mohol by sa
  # predvolit, hoci je to doska za dvojnasobok.
  blok = P2_PAYLOADS_SRC[/def materials_payload.+?\n        end/m].to_s
  NxTest.assert(blok.include?("base['duplak'] = true unless s['source_material_id']"),
                'priznak ide zo zdrojoveho materialu, nie z regexu nad ID')
end
