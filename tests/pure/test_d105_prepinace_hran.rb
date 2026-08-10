# frozen_string_literal: true
# Testy D-105 „Prepinace kontroly hran" — TRI stavy hrany, filter podla vyberu,
# pocty a perzistencia prepinacov (bez SketchUpu, bez Overlay API).
#
# Kontrolovane invarianty:
#   1) kazda hrana LEPITELNEHO dielca padne presne do JEDNEHO stavu
#      (missing = pravidlo ziada + paska chyba · extra = pravidlo neziada +
#       paska chyba · taped = paska je),
#   2) PRESKOCENY dielec (material mimo katalogu / UNI / KOMPAKT / PD-postforming)
#      nesvieti v ZIADNOM stave — kompakt sa NESMIE tvarit ako „neolepeny",
#   3) filter „len vybrane" patri VYHRADNE zelenej, zvlada VIAC objektov naraz,
#      pozna korpus / dosku / jeden dielec a pri kopiach rozhoduje active_path,
#   4) prazdny vyber pri zapnutom „len vybrane" = zelena sa NEKRESLI,
#   5) prepinace: whitelist kluca, striktny boolean, poskodeny subor = DEFAULT,
#      nastavenie zije v %APPDATA%, NIKDY v modeli.
require_relative '../helper' unless defined?(NxTest)

D105 = Noxun::Engine::EdgeCheck

D105_SHEET = { 'material_id' => 'X18', 'type' => 'DTDL', 'thickness' => 18.0 }.freeze
D105_RULE_SHELF = { 'L1' => 1.0 }.freeze
D105_RULE_NONE = {}.freeze

def d105_rec(edges, quantity = 1)
  { 'edges' => edges, 'quantity' => quantity }
end

# --- 1) tri stavy -------------------------------------------------------------

NxTest.test('D-105: polica s pravidlovou paskou — 1 olepena, 3 mimo pravidla, 0 chybajucich') do
  rec = d105_rec({ 'L1' => 'ABS_X_10', 'L2' => nil, 'W1' => nil, 'W2' => nil })
  cls = D105.classify_edges(rec, D105_SHEET, D105_RULE_SHELF)
  NxTest.assert_equal([], cls['missing'])
  NxTest.assert_equal(%w[L2 W1 W2], cls['extra'])
  NxTest.assert_equal(['L1'], cls['taped'])
end

NxTest.test('D-105: vedome zruseny olep ostava CERVENY (zamer D-104 sa nemeni)') do
  cls = D105.classify_edges(d105_rec({ 'L1' => nil }), D105_SHEET, D105_RULE_SHELF)
  NxTest.assert_equal(['L1'], cls['missing'])
  NxTest.assert(!cls['extra'].include?('L1'), 'hrana s pravidlom nikdy nie je fialova')
end

NxTest.test('D-105: chrbat/sokel (prazdne pravidlo) = vsetky 4 hrany FIALOVE, nikdy cervene') do
  cls = D105.classify_edges(d105_rec({}), D105_SHEET, D105_RULE_NONE)
  NxTest.assert_equal([], cls['missing'])
  NxTest.assert_equal(%w[L1 L2 W1 W2], cls['extra'])
end

NxTest.test('D-105: kazda hrana padne presne do JEDNEHO stavu (ziadny prekryv, ziadna navyse)') do
  rec = d105_rec({ 'L1' => 'ABS_X_10', 'L2' => '  ', 'W1' => nil, 'W2' => 'ABS_Y_20' })
  cls = D105.classify_edges(rec, D105_SHEET, { 'L1' => 1.0, 'W1' => 1.0 })
  all = cls['missing'] + cls['extra'] + cls['taped']
  NxTest.assert_equal(%w[L1 L2 W1 W2], all.sort)
  NxTest.assert_equal(all.length, all.uniq.length)
  NxTest.assert_equal(['W1'], cls['missing'])
  NxTest.assert_equal(['L2'], cls['extra'])   # prazdne medzery = bez pasky
  NxTest.assert_equal(%w[L1 W2], cls['taped'])
end

NxTest.test('D-105: paska MIMO pravidla je zelena (paska tam je — semafor ju hlasi zvlast)') do
  cls = D105.classify_edges(d105_rec({ 'L2' => 'ABS_X_10' }), D105_SHEET, D105_RULE_SHELF)
  NxTest.assert_equal(['L2'], cls['taped'])
end

NxTest.test('D-105: flagged_edges (D-104 kontrakt) je presne stav missing') do
  rec = d105_rec({ 'L1' => nil, 'L2' => 'ABS_X_10' })
  cls = D105.classify_edges(rec, D105_SHEET, D105_RULE_SHELF)
  NxTest.assert_equal(cls['missing'], D105.flagged_edges(rec, D105_SHEET, D105_RULE_SHELF))
end

# --- 2) preskocene dielce vo VSETKYCH stavoch ---------------------------------

NxTest.test('D-105: KOMPAKT nesvieti ANI FIALOVO — nie je „neolepeny", len sa lepit neda') do
  kompakt = { 'material_id' => 'K12', 'type' => 'KOMPAKT' }
  cls = D105.classify_edges(d105_rec({}), kompakt, D105_RULE_NONE)
  NxTest.assert_equal([], cls['missing'])
  NxTest.assert_equal([], cls['extra'])
  NxTest.assert_equal([], cls['taped'])
end

NxTest.test('D-105: PD s postformingom je preskocena vo vsetkych stavoch; PD s ABS nie') do
  post = { 'material_id' => 'PD1', 'type' => 'PD', 'pd_edge_subtype' => 'postforming' }
  abs  = { 'material_id' => 'PD2', 'type' => 'PD', 'pd_edge_subtype' => 'abs' }
  NxTest.assert_equal([], D105.classify_edges(d105_rec({}), post, D105_RULE_NONE)['extra'])
  NxTest.assert_equal(%w[L1 L2 W1 W2], D105.classify_edges(d105_rec({}), abs, D105_RULE_NONE)['extra'])
end

NxTest.test('D-105: UNI aj material mimo katalogu su preskocene vo vsetkych stavoch') do
  uni = { 'material_id' => 'UNI_KORPUS', 'uni' => true }
  [uni, nil].each do |sheet|
    cls = D105.classify_edges(d105_rec({ 'L1' => 'ABS_X_10' }), sheet, D105_RULE_SHELF)
    NxTest.assert_equal([], cls['taped'] + cls['extra'] + cls['missing'])
  end
end

# --- 3) filter „len vybrane" --------------------------------------------------

def d105_occ(part, owner, codes, qty = 1)
  { 'part' => part, 'owner' => owner, 'qty' => qty, 'unresolved' => false,
    'codes' => { 'missing' => [], 'extra' => [], 'taped' => [] }.merge(codes),
    'quads' => { 'missing' => [], 'extra' => [], 'taped' => [] } }
end

def d105_filter(ids, ctx = nil)
  { 'ids' => ids.each_with_object({}) { |i, h| h[i] = true }, 'ctx' => ctx }
end

NxTest.test('D-105: oznaceny KORPUS pusti vsetky svoje dielce') do
  occ = d105_occ(11, 10, {})
  NxTest.assert(D105.occurrence_selected?(occ, d105_filter([10])))
  NxTest.assert(!D105.occurrence_selected?(occ, d105_filter([99])))
end

NxTest.test('D-105: oznacena DOSKA (vlastnik je ona sama) prejde') do
  board = d105_occ(20, 20, {})
  NxTest.assert(D105.occurrence_selected?(board, d105_filter([20])))
end

NxTest.test('D-105: VIAC oznacenych objektov naraz (cely sektor) prejde vsetky') do
  f = d105_filter([10, 20, 30])
  NxTest.assert([d105_occ(11, 10, {}), d105_occ(20, 20, {}), d105_occ(31, 30, {})]
                  .all? { |o| D105.occurrence_selected?(o, f) })
  NxTest.assert(!D105.occurrence_selected?(d105_occ(41, 40, {}), f))
end

NxTest.test('D-105: jeden DIELEC vnutri korpusu — rozhoduje active_path, nie zdielana definicia') do
  # Dve kopie korpusu (10, 20) zdielaju definiciu, takze vnoreny dielec ma v oboch
  # ROVNAKE entityID (11). Bez kontextu by sa rozsvietil v oboch (Codex BLOCKER 2).
  in_a = d105_occ(11, 10, {})
  in_b = d105_occ(11, 20, {})
  f = d105_filter([11], 10)
  NxTest.assert(D105.occurrence_selected?(in_a, f), 'otvoreny vyskyt sa zvyrazni')
  NxTest.assert(!D105.occurrence_selected?(in_b, f), 'kopia s tym istym ID sa NEZVYRAZNI')
end

NxTest.test('D-105: dielec bez kontextu (active_path prazdna) sa nezatají') do
  NxTest.assert(D105.occurrence_selected?(d105_occ(11, 10, {}), d105_filter([11], nil)))
end

NxTest.test('D-105: prazdny vyber neprepusti nic (zelena sa nekresli)') do
  f = d105_filter([])
  NxTest.assert(!D105.occurrence_selected?(d105_occ(11, 10, {}), f))
  NxTest.assert_equal({}, f['ids'])
end

# --- 4) prepinace: whitelist, boolean, perzistencia ---------------------------

NxTest.test('D-105: default = svieti len cervena; zelena je „len vybrane"') do
  d = D105::DEFAULT_OPTIONS
  NxTest.assert_equal(true, d['show_missing'])
  NxTest.assert_equal(false, d['show_extra'])
  NxTest.assert_equal(false, d['show_taped'])
  NxTest.assert_equal(true, d['taped_selected_only'])
end

NxTest.test('D-105: poskodeny/cudzi obsah suboru = DEFAULT (nikdy „nahodny" stav)') do
  NxTest.assert_equal(D105::DEFAULT_OPTIONS, D105.normalize_options(nil))
  NxTest.assert_equal(D105::DEFAULT_OPTIONS, D105.normalize_options('nezmysel'))
  NxTest.assert_equal(D105::DEFAULT_OPTIONS,
                      D105.normalize_options({ 'show_extra' => 'true', 'show_taped' => 1 }))
  NxTest.assert_equal(true, D105.normalize_options({ 'show_extra' => true })['show_extra'])
end

NxTest.test('D-105: normalize zahodi cudzie kluce (subor nikdy nerozsiri kontrakt)') do
  out = D105.normalize_options({ 'show_missing' => false, 'hack' => true })
  NxTest.assert_equal(D105::OPTION_KEYS.sort, out.keys.sort)
  NxTest.assert_equal(false, out['show_missing'])
end

NxTest.test('D-105: set_option zapise len whitelistovany kluc a VYSLOVNE boolean') do
  tmp = Dir.mktmpdir('nx-d105-')
  Noxun::Engine::Materials.test_dir_override = tmp
  D105.instance_variable_set(:@options, nil)
  begin
    opts = D105.set_option('show_taped', true)
    NxTest.assert_equal(true, opts['show_taped'])
    NxTest.assert_equal(true, opts['show_missing'], 'ostatne prepinace sa zapisom nemenia')
    # cudzi kluc aj nebooleovska hodnota = ziadna zmena
    NxTest.assert_equal(true, D105.set_option('hack', true)['show_taped'])
    NxTest.assert_equal(true, D105.set_option('show_taped', 'false')['show_taped'])
    NxTest.assert(!File.exist?(File.join(tmp, 'materials.json')),
                  'nastavenie zvyraznenia nesmie siahat na katalog')
    saved = JSON.parse(File.read(File.join(tmp, D105::SETTINGS_FILE)))
    NxTest.assert_equal(true, saved['show_taped'])
    NxTest.assert_equal(D105::SETTINGS_STD, saved['std'])
    # nova instancia (novy start SketchUpu) najde zapamatany stav
    D105.instance_variable_set(:@options, nil)
    NxTest.assert_equal(true, D105.settings['show_taped'])
  ensure
    D105.instance_variable_set(:@options, nil)
    Noxun::Engine::Materials.test_dir_override = nil
    FileUtils.rm_rf(tmp)
  end
end

NxTest.test('D-105: farby stavov su tri RÔZNE a kryju sa s tokenmi --nx-edge-*') do
  colors = D105::COLORS
  NxTest.assert_equal(3, colors.values.uniq.length)
  hex = colors.transform_values { |c| format('#%02x%02x%02x', c[0], c[1], c[2]) }
  css = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'))
  D105::STATES.each do |state|
    NxTest.assert(css.include?("--nx-edge-#{state}:#{hex[state]}"),
                  "token --nx-edge-#{state} musi mat #{hex[state]} (svorka = farba plosky)")
  end
end

NxTest.test('D-105: vsetky tri stavy sa kreslia plnou ploskou (Michalov test 11.8.)') do
  NxTest.assert_equal([], D105::OUTLINE_ONLY,
                      'linka namiesto plosky je necitatelna pri dieloch vedla seba')
  NxTest.assert(D105::DRAW_ORDER.first == 'taped' && D105::DRAW_ORDER.last == 'missing',
                'cervena sa kresli posledna — nikdy ju neprekryje informativny stav')
end
