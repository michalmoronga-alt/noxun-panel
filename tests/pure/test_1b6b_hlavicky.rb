# frozen_string_literal: true
# Davka 1b-6b (vyrobna P2, triaz #33): HLAVICKY MATERIALOVYCH SKUPIN vo vystupoch.
#
# Skupina Kusovnika a riadok supisu Platni sa doteraz volali `material_label` —
# cislo dekoru + struktura + nazov. Dva ROZNE vyrobne materialy (iny vyrobca,
# typ, format platne alebo rub zasteny) z toho dostali IDENTICKY text, a podla
# tychto hlaviciek sa objednava. Panel taky problem nema: ma kolizny aparat
# (`Panel.label_base` + `Materials.sheet_label_suffix`), vystupy ho len
# nepouzivali.
#
# Co sada strazi:
#   1. Bez kolizie sa hlavicka NEMENI (bezna zakazka bez sumu navyse).
#   2. Pri kolizii dostane rozlisenie — a je to PRESNE panelova menovka
#      (rovnaky aparat -> rovnaky vysledok, ziadna kopia logiky vo vystupoch).
#   3. Rozdiel LEN v hrubke nie je kolizia — hrubku hlavicka aj supis ukazuju
#      vlastnym udajom (`th`), takze rozlisovat netreba.
#   4. Menovky su po vsetkych kolach JEDNOZNACNE — dva materialy sa nesmu zliat
#      do jednej hlavicky ani vtedy, ked je katalog nezmyselny (poistka `[id]`).
#   5. To iste plati pre supis ABS pasok.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva). Parse-time tu
# ziadne SketchUp API nie je. `panel/payloads.rb` je reopen modulu Panel bez
# SketchUp zavislosti (vzor test_2a4b_cutover) — labely sa daju overit headless.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

H6CORE  = Noxun::Engine::ProductionCore
H6PANEL = Noxun::Engine::Panel

# Kontext kolizie vyrobcov (tvar `Panel.label_ctx`) sa testom podstrkuje
# EXPLICITNE — sada tak nezavisi od obsahu sandbox katalogu.
H6_CTX = { 'num' => { 'K111' => %w[G1 G2] }, 'base' => {}, 'hard' => {},
           'group_man' => { 'G1' => 'Egger', 'G2' => 'Kronospan' } }.freeze

def h6_sheet(over = {})
  { 'material_id' => 'A', 'decor' => 'K111', 'structure' => 'ST9', 'decor_name' => 'Dub',
    'type' => 'DTDL', 'thickness' => 18.0, 'manufacturer' => 'Egger', 'group_id' => 'G1' }.merge(over)
end

def h6_map(*recs)
  recs.each_with_object({}) { |r, out| out[r['material_id']] = r }
end

def h6_edge(over = {})
  { 'abs_id' => 'E1', 'decor' => 'K009', 'structure' => 'PW', 'width' => 22.0,
    'thickness' => 1.0, 'group_id' => 'G1' }.merge(over)
end

# --- 1) bez kolizie sa nemeni nic --------------------------------------------

NxTest.test('1b-6b: nekolizna zakazka ma hlavicky PRESNE ako doteraz') do
  a = h6_sheet('material_id' => 'A')
  b = h6_sheet('material_id' => 'B', 'decor' => 'K222', 'decor_name' => 'Buk')
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), H6_CTX)
  NxTest.assert_equal('K111 ST9 Dub', labels['A'], 'dekorova menovka ostava kratka')
  NxTest.assert_equal('K222 ST9 Buk', labels['B'])
  NxTest.assert_equal(H6CORE.material_label(a, 'A'), labels['A'],
                      'bez kolizie je to bajtovo `material_label` — ziadny sum navyse')
end

NxTest.test('1b-6b: rozdiel LEN v hrubke nie je kolizia (hrubku ukazuje vlastny udaj)') do
  a = h6_sheet('material_id' => 'A', 'thickness' => 18.0)
  b = h6_sheet('material_id' => 'B', 'thickness' => 36.0)
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), H6_CTX)
  NxTest.assert_equal('K111 ST9 Dub', labels['A'])
  NxTest.assert_equal('K111 ST9 Dub', labels['B'],
                      'hlavicka aj supis Platni maju hrubku vo vlastnom stlpci — netreba ju do menovky')
end

NxTest.test('1b-6b: material mimo katalogu sa aj nadalej vola svojim ID') do
  labels = H6CORE.material_labels(%w[NEEXISTUJE], {}, H6_CTX)
  NxTest.assert_equal('NEEXISTUJE', labels['NEEXISTUJE'], 'nazov sa nikdy nevymysla')
end

# --- 2) kolizie: vyrobca, format, rub, typ ------------------------------------

NxTest.test('1b-6b: dva VYROBCOVIA toho isteho cisla dostanu rozlisene hlavicky') do
  a = h6_sheet('material_id' => 'A')
  b = h6_sheet('material_id' => 'B', 'manufacturer' => 'Kronospan', 'group_id' => 'G2')
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), H6_CTX)
  NxTest.refute(labels['A'] == labels['B'], 'dve nerozlisitelne hlavicky = riziko objednavky')
  NxTest.assert(labels['A'].include?('Egger'), "menovka A nesie vyrobcu (#{labels['A']})")
  NxTest.assert(labels['B'].include?('Kronospan'), "menovka B nesie vyrobcu (#{labels['B']})")
  NxTest.assert_equal(H6PANEL.raw_row_label(a, H6_CTX), labels['A'],
                      'je to PRESNE panelova menovka — rovnaky aparat, rovnaky vysledok')
end

NxTest.test('1b-6b: dva FORMATY pracovnej dosky dostanu rozlisene hlavicky') do
  a = h6_sheet('material_id' => 'A', 'type' => 'PD', 'thickness' => 38.0,
               'sheet_size' => [4100.0, 600.0])
  b = h6_sheet('material_id' => 'B', 'type' => 'PD', 'thickness' => 38.0,
               'sheet_size' => [4100.0, 920.0])
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), nil)
  NxTest.refute(labels['A'] == labels['B'], 'hlavicky musia byt rozlisene')
  NxTest.assert(labels['A'].include?('4100×600'), "format je v menovke (#{labels['A']})")
  NxTest.assert(labels['B'].include?('4100×920'), "format je v menovke (#{labels['B']})")
  NxTest.assert_equal(H6PANEL.raw_row_label(a, nil), labels['A'],
                      'pripona je `Materials.sheet_label_suffix` cez panelovu menovku')
end

NxTest.test('1b-6b: dva RUBY zasteny dostanu rozlisene hlavicky') do
  a = h6_sheet('material_id' => 'A', 'type' => 'ZASTENA', 'thickness' => 8.0,
               'sheet_size' => [4100.0, 640.0], 'back_decor' => 'K552', 'back_structure' => 'RT')
  b = h6_sheet('material_id' => 'B', 'type' => 'ZASTENA', 'thickness' => 8.0,
               'sheet_size' => [4100.0, 640.0], 'back_decor' => 'K553')
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), nil)
  NxTest.refute(labels['A'] == labels['B'], 'hlavicky musia byt rozlisene')
  NxTest.assert(labels['A'].include?('/K552'), "rub je v menovke (#{labels['A']})")
  NxTest.assert(labels['B'].include?('/K553'), "rub je v menovke (#{labels['B']})")
end

NxTest.test('1b-6b: ten isty dekor v DVOCH TYPOCH eskaluje na plnu panelovu menovku') do
  a = h6_sheet('material_id' => 'A', 'type' => 'DTDL')
  b = h6_sheet('material_id' => 'B', 'type' => 'KOMPAKT')
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), nil)
  NxTest.refute(labels['A'] == labels['B'],
                      'DTDL 18 a kompakt 18 toho isteho dekoru nie su ten isty material')
  NxTest.assert(labels['A'].include?('DTDL'), "typ je v menovke (#{labels['A']})")
  NxTest.assert(labels['B'].include?('KOMPAKT'), "typ je v menovke (#{labels['B']})")
  NxTest.assert_equal(H6PANEL.sheet_label(a, nil), labels['A'],
                      'druhy stupen je `Panel.sheet_label` — nic vlastne sa neskladá')
end

NxTest.test('1b-6b: poistka `[material_id]` — dve hlavicky sa nesmu zliat NIKDY') do
  # Katalog take zaznamy zakazuje (identita variantu), ale hlavicka je nakupny
  # udaj: aj pri nezmyselnom katalogu musi ostat rozlisitelna (vzor VEPO).
  a = h6_sheet('material_id' => 'A')
  b = h6_sheet('material_id' => 'B')
  labels = H6CORE.material_labels(%w[A B], h6_map(a, b), nil)
  NxTest.refute(labels['A'] == labels['B'], 'hlavicky musia byt rozlisene')
  NxTest.assert(labels['A'].end_with?('[A]'), "poistka pridava ID (#{labels['A']})")
  NxTest.assert(labels['B'].end_with?('[B]'), "poistka pridava ID (#{labels['B']})")
end

NxTest.test('1b-6b: kolizia sa riesi LEN medzi kolidujucimi — ostatne hlavicky ticho') do
  a = h6_sheet('material_id' => 'A')
  b = h6_sheet('material_id' => 'B', 'manufacturer' => 'Kronospan', 'group_id' => 'G2')
  c = h6_sheet('material_id' => 'C', 'decor' => 'K222', 'decor_name' => 'Buk')
  labels = H6CORE.material_labels(%w[A B C], h6_map(a, b, c), H6_CTX)
  NxTest.assert_equal('K222 ST9 Buk', labels['C'], 'nekolizna skupina ostava nedotknuta')
  NxTest.assert_equal(3, labels.values.uniq.length, 'kazda hlavicka je jednoznacna')
end

# --- 3) kontrakt payloadu ------------------------------------------------------

NxTest.test('1b-6b: materials_meta stavia label cez kolizny aparat (jeden zdroj pravdy)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                  encoding: 'UTF-8')
  NxTest.assert(src.include?('labels = material_labels(ids, smap)'),
                'materials_meta pouziva `material_labels`, nie holy `material_label`')
  NxTest.assert(src.include?('labels = edge_labels(ids, emap)'),
                'to iste plati pre supis ABS')
  NxTest.assert(src.include?('Panel.raw_row_label(rec, ctx)') && src.include?('Panel.sheet_label(rec, ctx)'),
                'eskalacia vola PANELOVY aparat — vystupy si vlastnu logiku menoviek neskladaju')
  meta = H6CORE.materials_meta(rows: [{ 'material_id' => 'NEEXISTUJE' }], sheets: [])
  NxTest.assert_equal(%w[label color th uni].sort, meta['NEEXISTUJE'].keys.sort,
                      'tvar zaznamu (kontrakt S1) sa nemeni')
  NxTest.assert_equal('NEEXISTUJE', meta['NEEXISTUJE']['label'])
end

# --- 4) ABS pasky --------------------------------------------------------------

NxTest.test('1b-6b: dve ABS pasky toho isteho cisla v DVOCH STRUKTURACH sa rozlisia') do
  a = h6_edge('abs_id' => 'E1', 'structure' => 'PW')
  b = h6_edge('abs_id' => 'E2', 'structure' => 'SM')
  emap = { 'E1' => a, 'E2' => b }
  labels = H6CORE.edge_labels(%w[E1 E2], emap, nil)
  NxTest.refute(labels['E1'] == labels['E2'], 'supis pasok je nakupny zoznam')
  NxTest.assert(labels['E1'].include?('PW'), "struktura je v menovke (#{labels['E1']})")
  NxTest.assert_equal(H6PANEL.abs_label(a, nil), labels['E1'],
                      'eskalacia je panelovy `abs_label`')
end

NxTest.test('1b-6b: nekolizne pasky ostavaju s dnesnou menovkou') do
  a = h6_edge('abs_id' => 'E1')
  b = h6_edge('abs_id' => 'E2', 'decor' => 'K222')
  emap = { 'E1' => a, 'E2' => b }
  labels = H6CORE.edge_labels(%w[E1 E2], emap, nil)
  NxTest.assert_equal(H6CORE.edge_label(a, 'E1'), labels['E1'], 'ziadny sum navyse')
  NxTest.assert_equal(H6CORE.edge_label(b, 'E2'), labels['E2'])
end
