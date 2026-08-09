# frozen_string_literal: true
# Testy D-92: „co sa realne kupi" v sekcii Kovanie karty skrinky.
#   1) HardwareSets.explain — rozpis JEDNEJ polozky config.hardware[] (set ->
#      kody -> nazvy z katalogu) cez TIE ISTE autority ako expand.
#   2) PartKeys.human_label — ludsky nazov vlastnika namiesto suroveho part_key.
# Oboje su CISTE funkcie (ziadny SketchUp) — payload panela je nad nimi len
# tenka vrstva.
require_relative '../helper' unless defined?(NxTest)

module NxD92
  HWS = Noxun::Engine::HardwareSets
  PK  = Noxun::Engine::PartKeys

  # --- sety projektu (tvar snapshotu: set_id => definicia) ---------------------
  SETS = {
    'zaves-klasik' => {
      'set_id' => 'zaves-klasik', 'name' => 'Záves KLASIK', 'generic_type' => 'hinge',
      'members' => [
        { 'code' => '104717', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' },
        { 'code' => '105408', 'per' => 'unit', 'qty' => 2, 'label' => 'krytka' },
        { 'code' => '250831', 'per' => 'owner', 'qty' => 1, 'label' => 'TipOn' }
      ]
    },
    'atira-h70' => {
      'set_id' => 'atira-h70', 'name' => 'Atira biela H70', 'generic_type' => 'slide',
      'members' => [
        { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
          'code_by_nl' => { '420' => '357695', '470' => '357696' } }
      ]
    },
    'atira-h176' => {
      'set_id' => 'atira-h176', 'name' => 'Atira biela H176', 'generic_type' => 'slide',
      'members' => [{ 'code' => '357783', 'per' => 'unit', 'qty' => 1 }]
    },
    'nohy-podla-sokla' => {
      'set_id' => 'nohy-podla-sokla', 'name' => 'Nohy podľa výšky sokla', 'generic_type' => 'leg',
      'members' => [
        { 'per' => 'unit', 'qty' => 1, 'label' => 'noha',
          'param_bands' => { 'param' => 'height',
                             'bands' => [{ 'min' => 17.0, 'max' => 21.0, 'code' => '82744' },
                                         { 'min' => 140.0, 'max' => 160.0, 'code' => '367823' }] } }
      ]
    },
    # set INEHO typu pod slide mapovanim (posledna poistka expanzie aj explainu)
    'zly-typ' => {
      'set_id' => 'zly-typ', 'name' => 'Zlý typ', 'generic_type' => 'hinge',
      'members' => [{ 'code' => '104717', 'per' => 'unit', 'qty' => 1 }]
    }
  }.freeze

  MAPPING = { 'hinge' => 'zaves-klasik', 'slide' => 'atira-h70',
              'leg' => 'nohy-podla-sokla' }.freeze

  CATALOG = [
    { 'item_code' => '104717', 'name_sk' => 'Záves Sensys 110°' },
    { 'item_code' => '105408', 'name_sk' => 'Krytka misky' },
    { 'item_code' => '250831', 'name_sk' => 'TipOn na dvierka' },
    { 'item_code' => '357695', 'name_sk' => 'K-Atira zásuvka 420/50kg' },
    { 'item_code' => '357783', 'name_sk' => 'K-Atira zásuvka 620/50kg' },
    { 'item_code' => '82744',  'name_sk' => 'Klzák 17 mm' }
    # 367823 (AXILO) v katalogu VEDOME NIE JE — kontrola „mimo katalógu"
  ].freeze

  FRONTS = [
    { 'id' => 'Fmsi0wnix-1-3a3kxe', 'type' => 'drawer_front', 'wings_n' => 1 },
    { 'id' => 'Fzz9', 'type' => 'door', 'wings_n' => 3 },
    { 'id' => 'Fqq2', 'type' => 'door', 'wings_n' => 2 }
  ].freeze

  module_function

  def state(mapping = MAPPING, sets = SETS)
    { 'mapping' => mapping, 'sets' => sets }
  end

  def item(over = {})
    { 'owner_part_key' => 'front:Fzz9/wing:left', 'generic_type' => 'hinge',
      'quantity' => 4, 'rule_id' => 'zavesy-podla-vysky', 'params' => {},
      'source' => 'rule' }.merge(over)
  end

  def explain(it, over = {})
    HWS.explain(it, over[:state] || state, overrides: over[:overrides] || {},
                    catalog: over.key?(:catalog) ? over[:catalog] : CATALOG)
  end

  def codes(res)
    res['members'].map { |m| m['code'] }
  end
end

# --- 1) namapovany set: kody, nazvy a pocty -----------------------------------

NxTest.test('D-92 explain: namapovany set rozpise kody, nazvy a pocty') do
  res = NxD92.explain(NxD92.item)
  NxTest.assert_equal('zaves-klasik', res['set_id'])
  NxTest.assert_equal('Záves KLASIK', res['set_name'])
  NxTest.assert_equal(%w[104717 105408 250831], NxD92.codes(res))
  NxTest.assert_equal([], res['problems'], 'kompletny nakup nema problem')
  # per 'unit' = pocet polozky x pocet clena; per 'owner' = raz na vlastnika
  NxTest.assert_equal([4, 8, 1], res['members'].map { |m| m['qty'] })
  NxTest.assert_equal(%w[unit unit owner], res['members'].map { |m| m['per'] })
  NxTest.assert_equal('Záves Sensys 110°', res['members'][0]['name'])
  NxTest.assert_equal(false, res['members'][0]['missing'])
  NxTest.assert_equal('záves', res['members'][0]['label'])
end

NxTest.test('D-92 explain: kod mimo katalogu kovania je priznany, nie vymysleny') do
  it = NxD92.item('generic_type' => 'leg', 'owner_part_key' => nil, 'quantity' => 4,
                  'rule_id' => 'nohy-zakladne', 'params' => { 'height' => 150.0 })
  res = NxD92.explain(it)
  NxTest.assert_equal(%w[367823], NxD92.codes(res))
  NxTest.assert_equal(true, res['members'][0]['missing'], 'AXILO v katalogu nie je')
  NxTest.assert_equal(nil, res['members'][0]['name'], 'nazov sa NIKDY nedosadzuje')
  NxTest.assert_equal([], res['problems'], 'chybajuci nazov nie je nemapovana polozka')
end

# --- 2) rad podla dlzky (code_by_nl) ------------------------------------------

NxTest.test('D-92 explain: rad podla NL vyberie kod a nesie hodnotu, ktora ho vybrala') do
  it = NxD92.item('generic_type' => 'slide', 'owner_part_key' => 'front:Fmsi0wnix-1-3a3kxe/panel',
                  'quantity' => 1, 'rule_id' => 'vysuvy-nl-podla-hlbky',
                  'params' => { 'nominal_length' => 420.0 })
  res = NxD92.explain(it)
  NxTest.assert_equal(%w[357695], NxD92.codes(res))
  NxTest.assert_equal(420.0, res['members'][0]['nominal_length'])
  NxTest.assert_equal([], res['problems'])
end

NxTest.test('D-92 explain: NL mimo radu = SK dovod, NIKDY susedny kod') do
  it = NxD92.item('generic_type' => 'slide', 'quantity' => 1,
                  'rule_id' => 'vysuvy-nl-podla-hlbky',
                  'params' => { 'nominal_length' => 500.0 })
  res = NxD92.explain(it)
  NxTest.assert_equal('atira-h70', res['set_id'], 'set je znamy — chyba len kod')
  NxTest.assert_equal([], res['members'])
  NxTest.assert_equal(1, res['problems'].length)
  NxTest.assert(res['problems'][0].include?('NL 500'), "dovod nesie dlzku: #{res['problems'][0]}")
  # ten isty text ako CSV a semafor (jedna autorita unmapped_reason_sk)
  ref = NxD92::HWS.unmapped_reason_sk('reason' => 'nl_missing', 'set_id' => 'atira-h70',
                                      'nominal_length' => 500.0)
  NxTest.assert_equal(ref, res['problems'][0])
end

# --- 3) pasma clena (param_bands) ---------------------------------------------

NxTest.test('D-92 explain: pasma clena vyberu kod podla vysky sokla') do
  it = NxD92.item('generic_type' => 'leg', 'owner_part_key' => nil, 'quantity' => 4,
                  'rule_id' => 'nohy-zakladne', 'params' => { 'height' => 18.0 })
  res = NxD92.explain(it)
  NxTest.assert_equal(%w[82744], NxD92.codes(res))
  NxTest.assert_equal(4, res['members'][0]['qty'])
  NxTest.assert_equal('Klzák 17 mm', res['members'][0]['name'])
end

NxTest.test('D-92 explain: vyska mimo pasiem = SK dovod s identifikaciou clena') do
  it = NxD92.item('generic_type' => 'leg', 'owner_part_key' => nil, 'quantity' => 4,
                  'rule_id' => 'nohy-zakladne', 'params' => { 'height' => 100.0 })
  res = NxD92.explain(it)
  NxTest.assert_equal([], res['members'])
  NxTest.assert_equal(1, res['problems'].length)
  NxTest.assert(res['problems'][0].include?('výška sokla'), res['problems'][0])
  NxTest.assert(res['problems'][0].include?('(noha)'), "dovod pomenuje clena: #{res['problems'][0]}")
end

# --- 4) selector mapovania (vyber setu podla parametra) -----------------------

NxTest.test('D-92 explain: selector vyberie set podla vysky cela') do
  sel = { 'param' => 'front_height',
          'bands' => [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'atira-h70' },
                      { 'min' => 121.0, 'max' => 400.0, 'set_id' => 'atira-h176' }] }
  st = NxD92.state({ 'slide' => sel })
  it = NxD92.item('generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'r1',
                  'params' => { 'front_height' => 176.0, 'nominal_length' => 420.0 })
  res = NxD92.explain(it, state: st)
  NxTest.assert_equal('atira-h176', res['set_id'])
  NxTest.assert_equal('Atira biela H176', res['set_name'])
  NxTest.assert_equal(%w[357783], NxD92.codes(res))

  # hodnota mimo vsetkych pasiem = ORANGE, NIKDY najblizsie pasmo
  out = NxD92.explain(it.merge('params' => { 'front_height' => 900.0 }), state: st)
  NxTest.assert_equal(nil, out['set_id'])
  NxTest.assert_equal(1, out['problems'].length)
  NxTest.assert(out['problems'][0].include?('výška čela'), out['problems'][0])
end

# --- 5) precedencia overridov (skrinka + dielec) ------------------------------

NxTest.test('D-92 explain: override na dielci prebije override skrinky aj projekt') do
  it = NxD92.item('generic_type' => 'slide', 'owner_part_key' => 'front:Fzz9/panel',
                  'quantity' => 1, 'rule_id' => 'r1',
                  'params' => { 'nominal_length' => 420.0 })
  # projekt hovori atira-h70; skrinka atira-h176; dielec spat atira-h70
  cab = NxD92.explain(it, overrides: { 'slide' => 'atira-h176' })
  NxTest.assert_equal('atira-h176', cab['set_id'], 'override skrinky prebije projekt')

  own = NxD92.explain(it, overrides: { 'slide' => 'atira-h176',
                                       'slide@front:Fzz9/panel' => 'atira-h70' })
  NxTest.assert_equal('atira-h70', own['set_id'], 'override dielca prebije skrinku')
  NxTest.assert_equal(%w[357695], NxD92.codes(own))

  # override INEHO dielca sa tejto polozky netyka
  other = NxD92.explain(it, overrides: { 'slide@front:Fqq2/panel' => 'atira-h176' })
  NxTest.assert_equal('atira-h70', other['set_id'], 'cudzi dielec nemeni vyber')
end

# --- 6) nemapovane stavy ------------------------------------------------------

NxTest.test('D-92 explain: bez setu / chybajuci set / iny typ maju vlastny SK dovod') do
  it = NxD92.item('generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'r1',
                  'params' => { 'nominal_length' => 420.0 })

  none = NxD92.explain(it, state: NxD92.state({}))
  NxTest.assert_equal(nil, none['set_id'])
  NxTest.assert_equal(['typ nemá priradený set'], none['problems'])

  miss = NxD92.explain(it, state: NxD92.state('slide' => 'neexistuje'))
  NxTest.assert_equal('neexistuje', miss['set_id'], 'set_id sa priznava aj ked definicia chyba')
  NxTest.assert(miss['problems'][0].include?('v projekte chýba'), miss['problems'][0])

  bad = NxD92.explain(it, state: NxD92.state('slide' => 'zly-typ'))
  NxTest.assert_equal('Zlý typ', bad['set_name'])
  NxTest.assert_equal([], bad['members'], 'set ineho typu NIKDY nekupi zly hardver')
  NxTest.assert(bad['problems'][0].include?('iného typu'), bad['problems'][0])
end

NxTest.test('D-92 explain: bez snapshotu (nil state) nemapuje nic a nespadne') do
  res = NxD92::HWS.explain(NxD92.item, nil)
  NxTest.assert_equal(nil, res['set_id'])
  NxTest.assert_equal([], res['members'])
  NxTest.assert_equal(['typ nemá priradený set'], res['problems'])
  # nezmyselny vstup nesmie vybuchnut
  NxTest.assert_equal([], NxD92::HWS.explain(nil, NxD92.state)['problems'])
  NxTest.assert_equal([], NxD92::HWS.explain({ 'generic_type' => '' }, NxD92.state)['members'])
end

# --- 7) cistota + lookup ------------------------------------------------------

NxTest.test('D-92 explain: cista funkcia — vstup ostava nedotknuty') do
  it = NxD92.item
  before = Marshal.dump(it)
  NxD92.explain(it)
  NxTest.assert_equal(before, Marshal.dump(it), 'polozka sa NEMENI (ani owner_id)')
  NxTest.assert_equal(false, it.key?('owner_id'), 'synteticky vlastnik neunikne von')
end

NxTest.test('D-92 explain: predpocitany lookup da rovnaky vysledok ako cely katalog') do
  it = NxD92.item
  a = NxD92::HWS.explain(it, NxD92.state, catalog: NxD92::CATALOG)
  b = NxD92::HWS.explain(it, NxD92.state,
                         lookup: NxD92::HWS.catalog_lookup(NxD92::CATALOG))
  NxTest.assert_equal(a, b, 'lookup je len optimalizacia, nie iny vyklad')
  # bez katalogu = same kody bez nazvov (nakup sa napriek tomu ukaze)
  c = NxD92::HWS.explain(it, NxD92.state)
  NxTest.assert_equal(%w[104717 105408 250831], NxD92.codes(c))
  NxTest.assert_equal([true, true, true], c['members'].map { |m| m['missing'] })
end

# --- 8) ludsky nazov vlastnika ------------------------------------------------

NxTest.test('D-92 human_label: cela sa cisluju podla PORADIA, nie podla generovaneho id') do
  pk = NxD92::PK
  f = NxD92::FRONTS
  NxTest.assert_equal('F1 · zásuvkové čelo',
                      pk.human_label('front:Fmsi0wnix-1-3a3kxe/panel', fronts: f))
  NxTest.assert_equal('F2 · dvierka ľavé', pk.human_label('front:Fzz9/wing:left', fronts: f))
  NxTest.assert_equal('F3 · dvierka pravé', pk.human_label('front:Fqq2/wing:right', fronts: f))
  NxTest.assert_equal('F2 · dvierka, krídlo 2/3', pk.human_label('front:Fzz9/wing:p2', fronts: f))
  NxTest.assert_equal('F3 · dvierka', pk.human_label('front:Fqq2/wing:single', fronts: f))
end

NxTest.test('D-92 human_label: neznamy tvar sa NIKDY nehada — vrati sa surovy kluc') do
  pk = NxD92::PK
  f = NxD92::FRONTS
  # celo, ktore v zozname nie je (stary config) — aspon surove id, ziadne cislo
  NxTest.assert_equal('Fnope · dvierka ľavé', pk.human_label('front:Fnope/wing:left', fronts: f))
  # bez zoznamu ciel sa cislo nema odkial vziat
  NxTest.assert_equal('Fzz9 · zásuvkové čelo', pk.human_label('front:Fzz9/panel'))
  # pN bez znameho poctu kridiel = len poradie
  NxTest.assert_equal('Fnope · dvierka, krídlo 3', pk.human_label('front:Fnope/wing:p3', fronts: f))
  NxTest.assert_equal('cabinet/bottom', pk.human_label('cabinet/bottom', fronts: f))
  NxTest.assert_equal('nieco/ine', pk.human_label('nieco/ine'))
  NxTest.assert_equal(nil, pk.human_label(nil), 'kovanie skrinky vlastnika nema')
  NxTest.assert_equal(nil, pk.human_label('   '))
end

NxTest.test('D-92 human_label: dielce zon (podperky, priecky) maju slovensky nazov') do
  pk = NxD92::PK
  NxTest.assert_equal('Polica 2', pk.human_label('zone:Z1/shelf:2'))
  NxTest.assert_equal('Zvislá priečka 1', pk.human_label('zone:Z1-a/divider_v:1'))
  NxTest.assert_equal('Vodorovná priečka 3', pk.human_label('zone:Z1-a/divider_h:3'))
end
