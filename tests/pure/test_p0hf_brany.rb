# frozen_string_literal: true
# P0-HF (externy Codex audit 29.8.2026) — FINALNE BRANY PRED ZAPISOM SUBORU.
#
# CO BOLO ZLE (spolocny koren oboch P0 nalezov): system poznal chybny finalny
# vystup a NAPRIEK TOMU HO ULOZIL. Rozpocet aj cenova ponuka sa zapisali na disk
# a az POTOM sa vyhodnotilo, ze riadky nemaju cenu, ze „Nábytková zostava" vysla
# zaporna alebo ze suma nesedi s rozpoctom; nakupny CSV kovania rovnako vzniknul
# aj vtedy, ked dve fyzicke skrinky zdielali ID a clen setu `per: 'owner'`
# (napr. TipOn) sa zapocital LEN RAZ. Cerveny status prisiel AZ POD hotovym
# suborom — a subor, ktory existuje, sa da odoslat dodavatelovi aj zakaznikovi.
#
# CO PLATI TERAZ: tri exporty (nakupny CSV kovania, XLSX rozpoctu, XLSX cenovej
# ponuky) maju pred `savepanel` FINALNU BRANU s DVOMA VETVAMI:
#
#   TVRDA (`export_blockers`) — stavy, ktore su VZDY chyba a NEDAJU sa potvrdit:
#     zaporna „Nábytková zostava", nesulad ponuky s rozpoctom a duplicitne ID
#     SKRINIEK (zliate vlastnictvo kovania). Subor nevznikne nikdy.
#
#   POTVRDITELNA (`export_confirmations`) — riadky BEZ CENY. STANDARD §11.3
#     hovori, ze neznama cena sa NIKDY nenahradi nulou, ale ma sa PRIZNAT —
#     rozpracovany rozpocet je legitimny stav zakazky a plosny tvrdy blok by
#     bral pouzivatelovi vystup, na ktory ma pravo (Codex review PR #250 proti
#     auditu). Prvy klik export ZASTAVI, druhy s `confirm_unpriced` ho pusti
#     a hotovy subor podhodnotenie PRIZNA v statuse. Nikdy ticha nula.
#
# VEDOME PREVRATENIE ROZHODNUTIA 1b-3: davka 1b-3 zvolila „export dobehne
# + cerveny status" a `test_1b3_citanie.rb` to charakterizoval. Audit to
# eskaloval na P0. Semafor KONTROLY sa tym NEMENI — ten stale len varuje
# a nikdy neblokuje (RED nezastavi ani VEPO); brana plati VYHRADNE pre finalny
# zapis suboru s cenou alebo objednavkou.
#
# Sada ma tri casti:
#   1. PREDIKATY `export_blockers` / `export_confirmations` — ciste dovody,
#      vratane toho, ze duplicitna DOSKA neblokuje (kovanie nema, takze
#      podpocet objednavky nehrozi).
#   2. SPRAVANIE exportov — dokaz, ze pri chybe SUBOR NEVZNIKOL (prazdny
#      priecinok) a ze sa `savepanel` ani neotvoril; ze POTVRDENY export
#      prebehne a podhodnotenie prizna; a ze cista zakazka subor NAOZAJ
#      vytvori (brana nemeria prazdno).
#   3. VEPO branu NEDOSTAVA — rezaci vystup duplicitna identita neskresluje
#      a audit ho vyslovne vynima.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxP0
  module_function

  PC = Noxun::Engine::ProductionCore
  SC = PC.singleton_class

  # --- fixtury -------------------------------------------------------------

  def collected(identities = [])
    { records: [], hardware: [], hardware_overrides: [], cabinet_sets: {},
      placements: [], warnings: [], identities: identities }
  end

  def ident(id, kind: 'cabinet', times: 2)
    [{ 'kind' => kind, 'id' => id }] * times
  end

  def cp(over = {})
    { 'total' => 1234.0, 'rows' => [], 'assembly' => 100.0, 'assembly_negative' => false,
      'consistent' => true, 'diff' => 0.0 }.merge(over)
  end

  def budget(miss: 0, cp_over: {})
    { 'totals' => { 'total' => 1234.0, 'unknown_count_in_total' => miss },
      'cp_preview' => cp(cp_over) }
  end

  def hw_exp
    { 'rows' => [{ 'code' => 'TIPON', 'quantity' => 2, 'sources' => [] }], 'unmapped' => [] }
  end

  # --- stubbing ------------------------------------------------------------
  #
  # `module_function` metody ziju NA SINGLETON TRIEDE modulu (vzor
  # `test_ec_ceny.rb`): `define_singleton_method` by original PREPISAL
  # a `remove_method` zmazal nadobro — dalsie sady by padali. Preto alias
  # tam a spat.
  def with_stubs(overrides)
    names = overrides.keys
    names.each do |name|
      SC.send(:alias_method, :"p0_orig_#{name}", name)
      SC.send(:define_method, name, &overrides[name])
    end
    yield
  ensure
    names.each do |name|
      SC.send(:remove_method, name)
      SC.send(:alias_method, name, :"p0_orig_#{name}")
      SC.send(:remove_method, :"p0_orig_#{name}")
    end
  end

  # Fake `UI` LEN na cas testu (headless ho v procese nikto iny nema).
  # POCITA VOLANIA `savepanel`/`select_directory` — brana ma zastavit export
  # PRED nimi, takze „picker sa neotvoril" je sucast dokazu: keby sa otvoril,
  # pouzivatel by uz vyberal miesto pre subor, ktory nesmie vzniknut.
  def with_ui(target, calls)
    ui = Module.new
    ui.define_singleton_method(:savepanel) do |_title, _dir, _name|
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

  # Jedno spustenie exportu nad prazdnym priecinkom.
  # -> [status_sprava, chyba?, [subory v priecinku], [volania pickera]]
  def run_export(method, stubs, dir, file_name, data = {})
    msg = nil
    err = nil
    calls = []
    target = File.join(dir, file_name)
    with_stubs(stubs) do
      with_ui(target, calls) do
        PC.send(method, :model, { 'gen' => 1 }.merge(data), generation: 1,
                                                            status: ->(m, e = false) { msg = m; err = e },
                                                            repush: -> {})
      end
    end
    [msg, err, Dir.children(dir).sort, calls]
  end

  # Spolocne stuby pre vsetky tri cenove/nakupne exporty.
  # POZOR: telo lambdy sa cez `define_method` viaze na ProductionCore — vsetko,
  # co ma vratit, musi byt LOKALNA premenna zachytena TU, nie volanie na NxP0.
  def base_stubs(col, bud)
    exp = hw_exp
    { refresh_vepo_settings: ->(*_a) {},
      vepo_settings: ->(*_a) { {} },
      save_vepo_settings: ->(*_a) { true },
      project_name: ->(*_a) { 'Test zákazka' },
      fresh_collect: ->(*_a) { col },
      sheets_map: ->(*_a) { {} },
      hardware_expansion: ->(*_a) { exp },
      budget_payload: ->(*_a) { bud } }
  end

  def in_tmp
    Dir.mktmpdir('nx-p0hf-') { |d| yield d }
  end
end

# --- 1. PREDIKAT ------------------------------------------------------------

NxTest.test('P0-HF: cista zakazka nema ZIADNY dovod na zastavenie (brana nemeri prazdno)') do
  NxTest.assert_equal([], NxP0::PC.export_blockers(collected: NxP0.collected, cp: NxP0.cp))
  NxTest.assert_equal([], NxP0::PC.export_confirmations(budget: NxP0.budget))
  # bez argumentov (legacy volanie / vystup, ktoreho sa brana netyka) tiez nic
  NxTest.assert_equal([], NxP0::PC.export_blockers)
  NxTest.assert_equal([], NxP0::PC.export_confirmations)
end

NxTest.test('P0-HF-02: duplicitna SKRINKA je dovod — hovori ID, dosledok aj KDE to opravit') do
  b = NxP0::PC.export_blockers(collected: NxP0.collected(NxP0.ident('CAB-001')))
  NxTest.assert_equal(1, b.length, b.inspect)
  NxTest.assert(b.first.include?('CAB-001'), b.first)
  NxTest.assert(b.first.include?('kovanie'), "dosledok pre objednavku: #{b.first}")
  NxTest.assert(b.first.include?('Kontrola'), "kam ist opravit: #{b.first}")
end

NxTest.test('P0-HF-02: duplicitna DOSKA NEBLOKUJE — a nikdy nedostane text o kovani') do
  ids = NxP0.collected(NxP0.ident('BRD-001', kind: 'board'))
  NxTest.assert_equal([], NxP0::PC.export_blockers(collected: ids),
                      'doska kovanie nema, takze podpocet objednavky nehrozi')
  # ...ale prizna sa ako NEBLOKUJUCE varovanie — bez vety o kovani
  s = NxP0::PC.dup_id_suffix(ids)
  NxTest.refute(s.empty?, 'nalez sa neprehltne')
  NxTest.refute(s.include?('kovanie'), s)
end

NxTest.test('P0-HF-02: mix skrinka + doska — blokuje LEN skrinka, doska ostava vo varovani') do
  col = NxP0.collected(NxP0.ident('CAB-002') + NxP0.ident('BRD-002', kind: 'board'))
  b = NxP0::PC.export_blockers(collected: col)
  NxTest.assert_equal(1, b.length, b.inspect)
  NxTest.assert(b.first.include?('CAB-002'), b.first)
  NxTest.refute(b.first.include?('BRD-002'), "doska do blokujuceho dovodu nepatri: #{b.first}")
  NxTest.assert(NxP0::PC.dup_id_suffix(col).include?('BRD-002'), 'doska je vo varovani')
end

NxTest.test('P0-HF-01: riadok bez ceny je POTVRDITELNY dovod, nie tvrdy blok (STANDARD §11.3)') do
  # rozpracovany rozpocet MUSI ostat exportovatelny — preto NIE `export_blockers`
  NxTest.assert_equal([], NxP0::PC.export_blockers(collected: NxP0.collected, cp: NxP0.cp))
  c = NxP0::PC.export_confirmations(budget: NxP0.budget(miss: 3))
  NxTest.assert_equal(1, c.length, c.inspect)
  NxTest.assert(c.first.include?('3 riadkov'), c.first)
  NxTest.assert(c.first.include?('PODHODNOTENÁ'), c.first)
end

NxTest.test('P0-HF-01: zaporna „Nábytková zostava" a nesulad s rozpoctom su TVRDE dovody') do
  neg = NxP0::PC.export_blockers(cp: NxP0.cp('assembly_negative' => true, 'assembly' => -12.5))
  NxTest.assert_equal(1, neg.length, neg.inspect)
  NxTest.assert(neg.first.include?('12,50 €'), "suma v hlaske: #{neg.first}")

  inc = NxP0::PC.export_blockers(cp: NxP0.cp('consistent' => false, 'diff' => 7.5))
  NxTest.assert_equal(1, inc.length, inc.inspect)
  NxTest.assert(inc.first.include?('7,50 €'), "rozdiel v hlaske: #{inc.first}")
end

NxTest.test('P0-HF: hlaska TVRDEJ brany povie, ze SUBOR NEVZNIKOL — aj vsetky dovody naraz') do
  msg = NxP0::PC.export_blocked_status(['prvý dôvod', 'druhý dôvod'])
  NxTest.assert(msg.include?('nevytvoril'), "pouzivatel ho nesmie ist hladat na disk: #{msg}")
  NxTest.assert(msg.include?('prvý dôvod') && msg.include?('druhý dôvod'), msg)
end

NxTest.test('P0-HF-01: hlaska POTVRDITELNEJ brany ponuka aj CESTU VON') do
  msg = NxP0::PC.export_confirm_status(['2 riadkov nemá cenu'])
  NxTest.assert(msg.include?('nevytvoril'), msg)
  NxTest.assert(msg.include?('2 riadkov nemá cenu'), msg)
  NxTest.assert(msg.include?('ešte raz'), "bez cesty von by to bol tvrdy blok: #{msg}")
end

NxTest.test('P0-HF-01: potvrdenie sa overuje NA SERVERI (klient nie je ochrana)') do
  pc = NxP0::PC
  NxTest.assert(pc.export_confirmed?('confirm_unpriced' => true))
  NxTest.refute(pc.export_confirmed?('confirm_unpriced' => 'true'), 'retazec nie je potvrdenie')
  NxTest.refute(pc.export_confirmed?('confirm_unpriced' => false))
  NxTest.refute(pc.export_confirmed?({}))
  NxTest.refute(pc.export_confirmed?(nil))
  # a potvrdeny export to musi PRIZNAT v statuse
  NxTest.assert(pc.export_confirmed_notes(['x']).first.include?('potvrdil'))
  NxTest.assert_equal([], pc.export_confirmed_notes(nil))
end

# --- 2. SPRAVANIE EXPORTOV: SUBOR NEVZNIKOL ---------------------------------
#
# Vsetky tri exporty bezia nad PRAZDNYM docasnym priecinkom; `savepanel` je
# nastaveny tak, aby subor smeroval PRAVE DONHO. Dokazom nie je text statusu,
# ale `Dir.children(dir) == []` po dobehnuti.

unless NxTest.headless?
  NxTest.skip!('brany exportov: fake `UI` sa v SketchUpe nestavia (realne UI je zive)')
end

if NxTest.headless?
  NxTest.test('P0-HF-01: XLSX rozpoctu s riadkom bez ceny sa NEZAPISE, kym to nepotvrdis') do
    NxP0.in_tmp do |dir|
      msg, err, files, calls = NxP0.run_export(
        :do_budget_xlsx, NxP0.base_stubs(NxP0.collected, NxP0.budget(miss: 2)), dir, 'rozpocet.xlsx'
      )
      NxTest.assert_equal([], files, 'na disku nesmie ostat NIC')
      NxTest.assert_equal([], calls, 'a picker sa ani neotvoril')
      NxTest.assert(err, 'status je cerveny')
      NxTest.assert(msg.include?('nevytvoril') && msg.include?('2 riadkov'), msg)
      NxTest.assert(msg.include?('ešte raz'), "a ponukne cestu von: #{msg}")
    end
  end

  NxTest.test('P0-HF-01: POTVRDENY export rozpracovaneho rozpoctu PREBEHNE — a podhodnotenie prizna') do
    NxP0.in_tmp do |dir|
      msg, err, files, calls = NxP0.run_export(
        :do_budget_xlsx, NxP0.base_stubs(NxP0.collected, NxP0.budget(miss: 2)), dir, 'rozpocet.xlsx',
        { 'confirm_unpriced' => true }
      )
      NxTest.assert_equal(['rozpocet.xlsx'], files, 'STANDARD §11.3: rozpracovany rozpocet sa exportovat DA')
      NxTest.assert_equal([:savepanel], calls)
      NxTest.assert(err, 'ale status ostava cerveny — tiche zelene „uložené" je presne to, co P0-HF rusi')
      NxTest.assert(msg.include?('2 riadkov') && msg.include?('potvrdil'), msg)
    end
  end

  NxTest.test('P0-HF-02: XLSX rozpoctu nad zliatymi vlastnikmi sa NEZAPISE (subor nevznikol)') do
    NxP0.in_tmp do |dir|
      stubs = NxP0.base_stubs(NxP0.collected(NxP0.ident('CAB-001')), NxP0.budget)
      msg, err, files, calls = NxP0.run_export(:do_budget_xlsx, stubs, dir, 'rozpocet.xlsx')
      NxTest.assert_equal([], files, 'na disku nesmie ostat NIC')
      NxTest.assert_equal([], calls)
      NxTest.assert(err && msg.include?('CAB-001'), msg)
    end
  end

  NxTest.test('P0-HF-01: cisty rozpocet sa zapise ako doteraz (dokaz, ze brana nemeri prazdno)') do
    NxP0.in_tmp do |dir|
      msg, err, files, calls = NxP0.run_export(
        :do_budget_xlsx, NxP0.base_stubs(NxP0.collected, NxP0.budget), dir, 'rozpocet.xlsx'
      )
      NxTest.assert_equal(['rozpocet.xlsx'], files, 'subor NAOZAJ vznikol')
      NxTest.assert_equal([:savepanel], calls)
      NxTest.refute(err, "zeleny status: #{msg}")
      NxTest.assert(msg.include?('Rozpočet uložený'), msg)
    end
  end

  NxTest.test('P0-HF-02: duplicitna DOSKA rozpocet NEZASTAVI — subor vznikne s varovanim') do
    NxP0.in_tmp do |dir|
      stubs = NxP0.base_stubs(NxP0.collected(NxP0.ident('BRD-001', kind: 'board')), NxP0.budget)
      msg, err, files, = NxP0.run_export(:do_budget_xlsx, stubs, dir, 'rozpocet.xlsx')
      NxTest.assert_equal(['rozpocet.xlsx'], files, 'doska zapis neblokuje')
      NxTest.assert(err, 'ale status varuje (farba)')
      NxTest.assert(msg.include?('BRD-001'), msg)
      NxTest.refute(msg.include?('kovanie'), "doska nedostane nepravdivy text o kovani: #{msg}")
    end
  end

  NxTest.test('P0-HF-01: cenova ponuka so zapornou zostavou sa NEZAPISE — a POTVRDIT sa neda') do
    NxP0.in_tmp do |dir|
      bud = NxP0.budget(cp_over: { 'assembly_negative' => true, 'assembly' => -30.0 })
      msg, err, files, calls = NxP0.run_export(:do_cp_xlsx, NxP0.base_stubs(NxP0.collected, bud),
                                               dir, 'ponuka.xlsx')
      NxTest.assert_equal([], files, 'na disku nesmie ostat NIC')
      NxTest.assert_equal([], calls)
      NxTest.assert(err && msg.include?('Nábytková zostava'), msg)
      # TVRDY dovod: `confirm_unpriced` ho NEPUSTI (na rozdiel od chybajucej ceny)
      _m2, _e2, files2, = NxP0.run_export(:do_cp_xlsx, NxP0.base_stubs(NxP0.collected, bud),
                                          dir, 'ponuka.xlsx', { 'confirm_unpriced' => true })
      NxTest.assert_equal([], files2, 'zaporna zostava je VZDY chyba — potvrdenie na nu neplati')
    end
  end

  NxTest.test('P0-HF-01: cenova ponuka, ktora nesedi s rozpoctom, sa NEZAPISE') do
    NxP0.in_tmp do |dir|
      bud = NxP0.budget(cp_over: { 'consistent' => false, 'diff' => 41.0 })
      msg, err, files, = NxP0.run_export(:do_cp_xlsx, NxP0.base_stubs(NxP0.collected, bud),
                                         dir, 'ponuka.xlsx', { 'confirm_unpriced' => true })
      NxTest.assert_equal([], files, 'ani potvrdenie tvrdy dovod neprejde')
      NxTest.assert(err && msg.include?('nesedí s rozpočtom'), msg)
    end
  end

  NxTest.test('P0-HF-01/02: zliati vlastnici su TVRDY dovod aj v ponuke — potvrdenie ho neprejde') do
    NxP0.in_tmp do |dir|
      stubs = NxP0.base_stubs(NxP0.collected(NxP0.ident('CAB-009')), NxP0.budget(miss: 1))
      msg, _err, files, = NxP0.run_export(:do_cp_xlsx, stubs, dir, 'ponuka.xlsx',
                                          { 'confirm_unpriced' => true })
      NxTest.assert_equal([], files)
      NxTest.assert(msg.include?('CAB-009'), "tvrdy dovod ide prvy: #{msg}")
    end
  end

  NxTest.test('P0-HF-01: POTVRDENA cenova ponuka bez ceny PREBEHNE — a podhodnotenie prizna') do
    NxP0.in_tmp do |dir|
      stubs = NxP0.base_stubs(NxP0.collected, NxP0.budget(miss: 1))
      msg, err, files, = NxP0.run_export(:do_cp_xlsx, stubs, dir, 'ponuka.xlsx',
                                         { 'confirm_unpriced' => true })
      NxTest.assert_equal(['ponuka.xlsx'], files, 'STANDARD §11.3: rozpracovana ponuka sa exportovat DA')
      NxTest.assert(err, 'status ostava cerveny')
      NxTest.assert(msg.include?('1 riadkov') && msg.include?('potvrdil'), msg)
      # ...a bez potvrdenia by nevznikla
      _m2, _e2, files2, = NxP0.run_export(:do_cp_xlsx, NxP0.base_stubs(NxP0.collected,
                                                                      NxP0.budget(miss: 1)),
                                          dir, 'ponuka2.xlsx')
      NxTest.assert_equal(['ponuka.xlsx'], files2, 'druhy subor bez potvrdenia nepribudol')
    end
  end

  NxTest.test('P0-HF-01: cista cenova ponuka sa zapise ako doteraz') do
    NxP0.in_tmp do |dir|
      msg, err, files, calls = NxP0.run_export(:do_cp_xlsx, NxP0.base_stubs(NxP0.collected, NxP0.budget),
                                               dir, 'ponuka.xlsx')
      NxTest.assert_equal(['ponuka.xlsx'], files, 'subor NAOZAJ vznikol')
      NxTest.assert_equal([:savepanel], calls)
      NxTest.refute(err, "zeleny status: #{msg}")
      NxTest.assert(msg.include?('Cenová ponuka uložená'), msg)
    end
  end

  NxTest.test('P0-HF-02: nakupny CSV kovania nad zliatymi vlastnikmi sa NEZAPISE') do
    NxP0.in_tmp do |dir|
      stubs = NxP0.base_stubs(NxP0.collected(NxP0.ident('CAB-005')), NxP0.budget)
      msg, err, files, calls = NxP0.run_export(:do_hw_csv, stubs, dir, 'kovanie.csv')
      NxTest.assert_equal([], files, 'objednavka s podpoctom nesmie vzniknut')
      NxTest.assert_equal([], calls)
      NxTest.assert(err && msg.include?('CAB-005') && msg.include?('TipOn'), msg)
    end
  end

  NxTest.test('P0-HF-02: cisty nakupny CSV kovania sa zapise ako doteraz') do
    NxP0.in_tmp do |dir|
      msg, err, files, calls = NxP0.run_export(:do_hw_csv, NxP0.base_stubs(NxP0.collected, NxP0.budget),
                                               dir, 'kovanie.csv')
      NxTest.assert_equal(['kovanie.csv'], files, 'subor NAOZAJ vznikol')
      NxTest.assert_equal([:savepanel], calls)
      NxTest.refute(err, "zeleny status: #{msg}")
      NxTest.assert(msg.include?('Nákupný zoznam'), msg)
    end
  end

  # --- 3. VEPO BRANU NEDOSTAVA ---------------------------------------------

  NxTest.test('P0-HF: VEPO sa duplicitou NEBLOKUJE — rezaci vystup vznikne') do
    NxP0.in_tmp do |dir|
      row = { 'names' => ['Bok'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0,
              'quantity' => 2, 'material_id' => 'MAT1', 'grain_direction' => 'length',
              'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil },
              'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 2 }] }
      stubs = NxP0.base_stubs(NxP0.collected(NxP0.ident('CAB-001')), NxP0.budget).merge(
        control_payload: ->(*_a, **_k) { { 'items' => [], 'counts' => { 'total' => 0 } } },
        vepo_materials: ->(*_a) { { 'MAT1' => { 'label' => 'Testovací dekor' } } },
        vepo_edge_thicknesses: ->(*_a) { {} },
        merge_18_36: ->(*_a) { true }
      )
      msg = nil
      err = nil
      calls = []
      bom = Noxun::Engine::Bom
      bom.singleton_class.send(:alias_method, :p0_orig_compute, :compute)
      bom.singleton_class.send(:define_method, :compute) { |*_a| { rows: [row], hardware: [] } }
      begin
        NxP0.with_stubs(stubs) do
          NxP0.with_ui(dir, calls) do
            NxP0::PC.do_export(:model, { 'gen' => 1 }, generation: 1,
                                                       status: ->(m, e = false) { msg = m; err = e },
                                                       repush: -> {})
          end
        end
      ensure
        bom.singleton_class.send(:remove_method, :compute)
        bom.singleton_class.send(:alias_method, :compute, :p0_orig_compute)
        bom.singleton_class.send(:remove_method, :p0_orig_compute)
      end
      NxTest.refute(Dir.children(dir).empty?, "VEPO subory vznikli napriek duplicite: #{msg}")
      NxTest.refute(err, "a status nie je cerveny: #{msg}")
      NxTest.assert(msg.include?('VEPO export hotový'), msg)
      NxTest.assert_equal([:select_directory], calls)
    end
  end

  NxTest.test('P0-HF: `do_export` branu ani NEVOLA (audit ju z VEPO vyslovne vynima)') do
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                    encoding: 'UTF-8')
    body = src[/def do_export\(model, data, generation:, status:, repush:\).*?\n      rescue StandardError/m].to_s
    NxTest.refute(body.empty?, 'do_export sa nasla')
    NxTest.refute(body.include?('export_blockers('),
                  'rezaci vystup zastavovat nechceme — zastavila by sa vyroba')
    # ...a dokaz, ze sa nekontroluje prazdno: OSTATNE TRI branu maju
    %w[do_hw_csv do_budget_xlsx do_cp_xlsx].each do |m|
      b = src[/def #{m}\(model, data, generation:, status:, repush:\).*?\n      rescue StandardError/m].to_s
      NxTest.assert(b.include?('export_blockers('), "#{m}: brana chyba")
    end
  end
end
