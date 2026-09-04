# frozen_string_literal: true
# NASTROJE-1 (T1a): ciste jadra nastrojov Mower a Snaper.
#
# Co sa tu overuje: posun kopie po LOKALNEJ osi X (mm, znamienko podla smeru),
# vyber cesty (edit kontext / vnoreny / korpus / doska / cudzi objekt), pripona
# nazvu kopie (najblizsia VOLNA v celom modeli) a AABB sweep prisunutia vratane
# viditelnosti (skryte uzly sa do jadra vobec nedostanu — traverza ich odfiltruje,
# tu sa dokazuje, ze ich NEPRITOMNOST meni doraz).
# Geometria v modeli, undo a realna viditelnost su in-SU sekcia `run_tools1`.
require_relative '../helper' unless defined?(NxTest)

MC = Noxun::Engine::Tools::MowerCalc
SC = Noxun::Engine::Tools::SnapCalc

# --- mower_calc: posun a smer -------------------------------------------------

NxTest.test('NASTROJE-1: posun kopie je SIRKA KORPUSU po lokalnej osi X') do
  NxTest.assert_close(600.0, MC.copy_offset_mm(600.0, :right), 0.001)
  NxTest.assert_close(-600.0, MC.copy_offset_mm(600.0, :left), 0.001)
  NxTest.assert_equal(-1.0, MC.sign(:left))
  NxTest.assert_equal(1.0, MC.sign(:right))
  # Sirka je mm Float — prevod na palce robi az `Units.vector` v SketchUp vrstve.
  NxTest.assert_close(449.5, MC.copy_offset_mm('449.5', :right), 0.001)
end

NxTest.test('NASTROJE-1: Z posun je rozdiel voci suucasnej vyske originu') do
  NxTest.assert_close(-720.0, MC.z_delta_mm(720.0, 0.0), 0.001)
  NxTest.assert_close(150.0, MC.z_delta_mm(720.0, 870.0), 0.001)
  NxTest.assert_close(0.0, MC.z_delta_mm(0.0, 0.0), 0.001)
end

# --- mower_calc: vyber cesty ---------------------------------------------------

NxTest.test('NASTROJE-1: otvoreny edit kontext odmieta VSETKO — este pred typom objektu') do
  # Poradie je sucast kontraktu: `CabinetBuilder.build` si edit kontext zatvara
  # SAM, takze odmietnutie musi prist PRED nim (audit 2).
  NxTest.assert_equal(:edit_context,
                      MC.route(kind: 'cabinet', root_context: false, top_level: true))
  NxTest.assert_equal(:edit_context,
                      MC.route(kind: nil, root_context: false, top_level: false))
end

NxTest.test('NASTROJE-1: vnoreny objekt sa odmieta, root-level sa smeruje podla druhu') do
  NxTest.assert_equal(:nested, MC.route(kind: 'cabinet', root_context: true, top_level: false))
  NxTest.assert_equal(:cabinet, MC.route(kind: 'cabinet', root_context: true, top_level: true))
  NxTest.assert_equal(:board, MC.route(kind: 'board', root_context: true, top_level: true))
  # Stary DC komponent nema NOXUN data -> legacy cesta.
  NxTest.assert_equal(:legacy, MC.route(kind: nil, root_context: true, top_level: true))
  NxTest.assert_equal(:legacy, MC.route(kind: 'zone', root_context: true, top_level: true))
end

# --- mower_calc: nazov kopie (FIX 10) -----------------------------------------

NxTest.test('NASTROJE-1: kopia bez rucneho nazvu si necha automaticky nazov') do
  NxTest.assert_equal(nil, MC.copy_name(nil, []))
  NxTest.assert_equal(nil, MC.copy_name('   ', ['Skrinka']))
end

NxTest.test('NASTROJE-1: opakovana kopia toho isteho zdroja ide a -> b -> c') do
  taken = ['Drezová']
  first = MC.copy_name('Drezová', taken)
  NxTest.assert_equal('Drezová a', first)
  taken << first
  second = MC.copy_name('Drezová', taken)
  NxTest.assert_equal('Drezová b', second)
  taken << second
  # Kopirovanie KOPIE (vyber po kopii ostava na nej) — zaklad je ten isty.
  NxTest.assert_equal('Drezová c', MC.copy_name(second, taken))
end

NxTest.test('NASTROJE-1: hlada sa NAJBLIZSIA VOLNA pripona (diera po zmazanom a)') do
  NxTest.assert_equal('Skrinka a', MC.copy_name('Skrinka', ['Skrinka', 'Skrinka b']))
  NxTest.assert_equal('Skrinka c', MC.copy_name('Skrinka', ['Skrinka a', 'Skrinka b']))
end

NxTest.test('NASTROJE-1: po vycerpani jednopismenovych pripon pokracuju dvojpismenove (z -> aa)') do
  taken = MC::LETTERS.map { |l| "Rad #{l}" }
  NxTest.assert_equal('Rad aa', MC.copy_name('Rad', taken))
  NxTest.assert_equal('Rad ab', MC.copy_name('Rad aa', taken + ['Rad aa']))
end

NxTest.test('NASTROJE-1: pripona NIKDY nie je cislo (bijektivna sustava a…z, aa…zz, aaa…)') do
  NxTest.assert_equal(%w[a b z aa ab az ba zz aaa],
                      [0, 1, 25, 26, 27, 51, 52, 701, 702].map { |i| MC.suffix_for(i) })
  offenders = (0..800).map { |i| MC.suffix_for(i) }.reject { |s| s =~ /\A[a-z]+\z/ }
  NxTest.assert(offenders.empty?, "necisto pismenove pripony: #{offenders.first(5).inspect}")
end

NxTest.test('NASTROJE-1: rucny nazov koniaci CISLOM sa nikdy neoreze (sirka nie je pripona)') do
  # Rozhodnutie 4.9.2026: „Dolná 900" je sirka skrinky — kopia ju musi UDRZAT.
  NxTest.assert_equal('Dolná 900 a', MC.copy_name('Dolná 900', ['Dolná 900']))
  NxTest.assert_equal('Dolná 900 b', MC.copy_name('Dolná 900 a', ['Dolná 900', 'Dolná 900 a']))
  # VELKE pismeno tiez nie je pripona — „Bok L" je oznacenie laveho boku.
  NxTest.assert_equal('Bok L a', MC.copy_name('Bok L', ['Bok L']))
  NxTest.assert_equal('Bok L b', MC.copy_name('Bok L a', ['Bok L', 'Bok L a']))
end

NxTest.test('NASTROJE-1: pripona PREZIJE 80-znakovy limit — zaklad sa oreze') do
  base = 'A' * 80
  out = MC.copy_name(base, [])
  NxTest.assert(out.length <= MC::NAME_MAX_LEN, "nazov ma #{out.length} znakov")
  NxTest.assert(out.end_with?(' a'), "pripona sa stratila: #{out.inspect}")
  # A dve kopie toho isteho dlheho nazvu sa NESMU zliat na jeden retazec.
  second = MC.copy_name(base, [out])
  NxTest.assert(second != out, 'dve kopie dlheho nazvu dostali ten isty nazov')
  NxTest.assert(second.end_with?(' b'), second.inspect)
end

NxTest.test('NASTROJE-1: zaklad nazvu = nazov bez pripony, ktoru vyrobila kopia') do
  # Odstranuje sa VYHRADNE medzera + 1-2 male pismena.
  NxTest.assert_equal('Skrinka', MC.copy_base_name('Skrinka a'))
  NxTest.assert_equal('Skrinka', MC.copy_base_name('Skrinka aa'))
  NxTest.assert_equal('Skrinka', MC.copy_base_name('Skrinka zz'))
  # Cisla NIKDY (sirka v nazve) a velke pismeno tiez nie.
  NxTest.assert_equal('Dolná 900', MC.copy_base_name('Dolná 900'))
  NxTest.assert_equal('Linka 2', MC.copy_base_name('Linka 2'))
  NxTest.assert_equal('Bok L', MC.copy_base_name('Bok L'))
  # Tri a viac pismen uz nie je pripona — je to slovo.
  NxTest.assert_equal('Skrinka pod', MC.copy_base_name('Skrinka pod'))
  NxTest.assert_equal('Skrinka', MC.copy_base_name('  Skrinka   '))
  NxTest.assert_equal('Pod drez', MC.copy_base_name('Pod drez'))
end

NxTest.test('NASTROJE-1: limit nazvu v jadre sedi s CabinetBuilder::NAME_MAX_LEN') do
  # Jadro sa vedome neviaze na builder (nacita sa aj samo), preto guard.
  NxTest.assert_equal(Noxun::Engine::CabinetBuilder::NAME_MAX_LEN, MC::NAME_MAX_LEN)
end

# --- kopia: ad-hoc kovanie a premisa scenara s presahujucim celom ---------------
# Obe veci zhodili PRVY in-SU beh — headless ich preto drzi natvrdo.

NxTest.test('NASTROJE-1: kopia da ad-hoc kovaniu NOVE id, obsah ostava nedotknuty') do
  cb = Noxun::Engine::CabinetBuilder
  base = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 560.0,
           'hardware_manual' => [{ 'id' => 'MAN-001', 'source' => 'free', 'name' => 'Testovacia položka',
                                   'qty' => 2, 'unit' => 'ks', 'price_eur_vat' => 1.5 }] }
  # `Store.config` vracia STRINGOVE kluce — cesta kopie ich tak aj cita.
  cfg = JSON.parse(JSON.generate(cb.send(:normalize, base)))
  stored = Array(cfg['hardware_manual']).first
  NxTest.refute(stored.nil?,
                'polozka musi prejst uzavretym whitelistom MANUAL_KEYS (source/qty/price_eur_vat) — ' \
                'vymyslene kluce norm_hardware_manual TICHO zahodi')

  params = cb.config_to_params(cfg)
  cb.rekey_hardware_manual(params) # presne poradie cesty „Vlozit kopiu" aj nastroja
  copied = Array(JSON.parse(JSON.generate(cb.send(:normalize, params)))['hardware_manual']).first
  NxTest.refute(copied.nil?, 'polozka sa pri kopii stratila')
  NxTest.assert(copied['id'] != stored['id'],
                "kopia je NOVA skrinka — polozka musi dostat vlastne id (#{stored['id']} -> #{copied['id']})")
  %w[source name qty unit price_eur_vat owner_part_key].each do |k|
    NxTest.assert_equal(stored[k], copied[k], "pole #{k} sa kopiou menit NESMIE")
  end
end

NxTest.test('NASTROJE-1: celo so zapornym gap_sides presahuje sirku korpusu (a bez items celo nie je)') do
  cb = Noxun::Engine::CabinetBuilder
  front_of = lambda do |gap_sides|
    params = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 560.0,
               'fronts' => { 'gap_sides' => gap_sides,
                             'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] } }
    plan = Noxun::Engine::Construction.build_plan(cb.send(:normalize, params))
    Array(plan[:parts]).find { |p| p[:part_key].to_s.start_with?('front') }
  end

  wide = front_of.call(-20.0)
  NxTest.refute(wide.nil?, 'celo sa nepostavilo')
  NxTest.assert(wide[:origin][0] < 0.0 && (wide[:origin][0] + wide[:box][0]) > 600.0,
                "celo #{wide[:origin][0]}..#{wide[:origin][0] + wide[:box][0]} nepresahuje korpus 0..600 — " \
                'bez presahu nema in-SU scenar co merat (obalka instancie = obalka korpusu)')
  narrow = front_of.call(2.0)
  NxTest.assert(narrow[:origin][0] > 0.0 && (narrow[:origin][0] + narrow[:box][0]) < 600.0,
                'kladny gap_sides ma celo drzat VNUTRI sirky korpusu')

  # PASCA z prveho in-SU behu: bez `fronts.items` postavi builder skrinku BEZ CELA.
  bare = Noxun::Engine::Construction.build_plan(
    cb.send(:normalize, { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 560.0 })
  )
  NxTest.assert(Array(bare[:parts]).none? { |p| p[:part_key].to_s.start_with?('front') },
                'bez fronts.items celo vzniknut NESMIE — scenar si ho musi vypytat vyslovne')
end

# --- handshake s Inspectorom pred kopiou (Codex #293 kolo 1, P2) ---------------

NxTest.test('NASTROJE-1: handshake — token je JEDINY korelacny kluc odpovede') do
  now = 1000.0
  pending = { 'token' => 't1', 'dir' => :right, 'cabinet_id' => 'CAB-001', 'deadline' => now + 2.0 }
  NxTest.assert_equal(:copy, MC.pending_decision(pending, 't1', 'nothing', now))
  NxTest.assert_equal(:copy, MC.pending_decision(pending, 't1', 'flushed', now))
  NxTest.assert_equal(:invalid, MC.pending_decision(pending, 't1', 'invalid', now))
  # Cudzia, stara alebo prazdna odpoved sa TICHO zahodi — nikdy nespusti kopiu.
  NxTest.assert_equal(:ignore, MC.pending_decision(pending, 't2', 'nothing', now))
  NxTest.assert_equal(:ignore, MC.pending_decision(pending, '', 'nothing', now))
  NxTest.assert_equal(:ignore, MC.pending_decision(nil, 't1', 'nothing', now))
  # Neznamy vysledok = neplatny. Kopia zo stareho configu je horsia nez odmietnutie.
  NxTest.assert_equal(:invalid, MC.pending_decision(pending, 't1', 'hocico', now))
  NxTest.assert_equal(:invalid, MC.pending_decision(pending, 't1', nil, now))
end

NxTest.test('NASTROJE-1: handshake — po lehote sa kopia ODMIETNE, nie vykona') do
  pending = { 'token' => 't1', 'deadline' => 1000.0 }
  NxTest.assert_equal(:copy, MC.pending_decision(pending, 't1', 'nothing', 1000.0))
  NxTest.assert_equal(:expired, MC.pending_decision(pending, 't1', 'nothing', 1000.01))
  NxTest.assert_equal(:expired, MC.pending_decision(pending, 't1', 'flushed', 1500.0))
  NxTest.assert_close(2.0, MC::FLUSH_TIMEOUT_S, 0.001)
end

NxTest.test('NASTROJE-1: handshake — token vyraba SERVER a dve kopie za sebou ho zdielat nesmu') do
  a = MC.flush_token(1, 1_700_000_000)
  b = MC.flush_token(2, 1_700_000_000)
  NxTest.assert(a != b, "dva handshaky dostali ten isty token (#{a})")
  NxTest.assert(a.start_with?('tcopy-'), a)
  NxTest.assert_equal(%w[flushed nothing invalid], MC::FLUSH_RESULTS)
end

# --- snap_calc: sweep ----------------------------------------------------------

def nx_box(x1, x2, y1 = 0.0, y2 = 600.0, z1 = 0.0, z2 = 720.0)
  { min: [x1, y1, z1], max: [x2, y2, z2] }
end

NX_TARGET = nx_box(0.0, 600.0)

# Kontajner tak, ako ho stava SketchUp vrstva: obalka = ZJEDNOTENIE viditelnych
# listov (skryte sa do zoznamu vobec nedostanu).
def nx_container(children)
  lo = children.map { |c| c[:box][:min] }
  hi = children.map { |c| c[:box][:max] }
  { box: { min: (0..2).map { |i| lo.map { |v| v[i] }.min },
           max: (0..2).map { |i| hi.map { |v| v[i] }.max } },
    container: true, children: children }
end

NxTest.test('NASTROJE-1: sweep najde najblizsiu prekazku v smere posunu') do
  nodes = [{ box: nx_box(700.0, 1300.0), container: false },
           { box: nx_box(900.0, 1500.0), container: false }]
  NxTest.assert_close(100.0, SC.nearest_gap(NX_TARGET, nodes, :right), 0.001)
  NxTest.assert_equal(nil, SC.nearest_gap(NX_TARGET, nodes, :left))

  left = [{ box: nx_box(-450.0, -50.0), container: false }]
  NxTest.assert_close(50.0, SC.nearest_gap(NX_TARGET, left, :left), 0.001)
end

NxTest.test('NASTROJE-1: sused, ktory sa nekryje vo vyske ani v hlbke, neblokuje') do
  vysoko = [{ box: nx_box(700.0, 1300.0, 0.0, 600.0, 2000.0, 2500.0), container: false }]
  NxTest.assert_equal(nil, SC.nearest_gap(NX_TARGET, vysoko, :right))
  # DOTYK nie je prekryv — podlaha pod skrinkou (Z od -18 do 0) bocny posun nebrzdi.
  podlaha = [{ box: nx_box(700.0, 5000.0, 0.0, 600.0, -18.0, 0.0), container: false }]
  NxTest.assert_equal(nil, SC.nearest_gap(NX_TARGET, podlaha, :right))
end

NxTest.test('NASTROJE-1: uz prisunuty sused dava medzeru 0 (nie zapornu)') do
  nodes = [{ box: nx_box(600.0, 1200.0), container: false }]
  NxTest.assert_close(0.0, SC.nearest_gap(NX_TARGET, nodes, :right), 0.001)
  NxTest.assert_equal(:touching, SC.verdict(0.0, 0.0))
end

NxTest.test('NASTROJE-1: obalka miestnosti sa PRECHADZA — doraz dava az vnutorna stena') do
  # Obalka kontajnera = zjednotenie VIDITELNYCH listov (tak ju stava SketchUp
  # vrstva). Izba ciel obklopuje, takze sama kandidatom nie je — musi sa zostupit.
  izba = nx_container([{ box: nx_box(-2000.0, -1900.0), container: false },
                       { box: nx_box(2400.0, 2500.0), container: false }])
  NxTest.assert_close(1800.0, SC.nearest_gap(NX_TARGET, [izba], :right), 0.001)
  NxTest.assert_close(1900.0, SC.nearest_gap(NX_TARGET, [izba], :left), 0.001)
end

NxTest.test('NASTROJE-1: kontajner NIE JE kandidat — gap dava az jeho LIST') do
  # Codex #293 kolo 1 (P2): obalka kontajnera je UNIA deti, takze by miesala
  # X jedneho dietata s Y/Z ineho. Dieta blizko, ale MIMO koridoru ciela,
  # nesmie doraz skratit — plati az to daleke, ktore v koridore naozaj je.
  mimo = { box: nx_box(700.0, 800.0, 1000.0, 1200.0), container: false } # y mimo 0..600
  v_koridore = { box: nx_box(2000.0, 2100.0, 0.0, 600.0), container: false }
  NxTest.assert_close(1400.0, SC.nearest_gap(NX_TARGET, [nx_container([mimo, v_koridore])], :right), 0.001,
                      'unia deti dala medzeru podla prekazky, ktora skrinke vobec nestoji v ceste')
  # Kontrola protikladom: to iste dieta V koridore doraz skratit MUSI.
  v_ceste = { box: nx_box(700.0, 800.0, 0.0, 600.0), container: false }
  NxTest.assert_close(100.0, SC.nearest_gap(NX_TARGET, [nx_container([v_ceste, v_koridore])], :right), 0.001)
end

NxTest.test('NASTROJE-1: do kontajnera sa zostupuje LENIVO — len ked siaha k veducemu okraju') do
  calls = [0]
  # Kontajner CELY ZA cielom (v protismere) sa neprechadza vobec.
  za_chrbtom = { box: nx_box(-900.0, -300.0), container: true,
                 children: -> { calls[0] += 1; [{ box: nx_box(-900.0, -300.0), container: false }] } }
  NxTest.assert_equal(nil, SC.nearest_gap(NX_TARGET, [za_chrbtom], :right))
  NxTest.assert_equal(0, calls[0], 'deti kontajnera mimo smeru sa nesmu ani nacitat')

  # Kontajner, ktory k veducemu okraju siaha, deti POTREBUJE — aj ked je cely
  # pred cielom (jeho vlastna obalka uz kandidatom nie je).
  vpredu = { box: nx_box(800.0, 1200.0), container: true,
             children: -> { calls[0] += 1; [{ box: nx_box(900.0, 1200.0), container: false }] } }
  NxTest.assert_close(300.0, SC.nearest_gap(NX_TARGET, [vpredu], :right), 0.001)
  NxTest.assert_equal(1, calls[0])
end

NxTest.test('NASTROJE-1: zanorenie kontajnerov konci na hlbke 8') do
  # Retaz 10 obklopujucich kontajnerov, stena az na dne — hlbsie sa uz nejde.
  deep = { box: nx_box(1000.0, 1400.0), container: false }
  10.downto(1) do |_i|
    inner = deep
    deep = { box: nx_box(-500.0, 1500.0), container: true, children: [inner] }
  end
  NxTest.assert_equal(nil, SC.nearest_gap(NX_TARGET, [deep], :right))
  NxTest.assert_equal(SC::MAX_DEPTH, 8)
end

NxTest.test('NASTROJE-1: skryte DIETA kontajnera doraz neblokuje') do
  # Traverza SketchUp vrstvy skryte uzly vynecha — a s nimi zmizne aj ich podiel
  # na obalke kontajnera (surove `definition.bounds` by ich nieslo dalej).
  blizka = { box: nx_box(700.0, 800.0), container: false }
  stena = { box: nx_box(2000.0, 2100.0), container: false }
  NxTest.assert_close(100.0, SC.nearest_gap(NX_TARGET, [nx_container([blizka, stena])], :right), 0.001)
  NxTest.assert_close(1400.0, SC.nearest_gap(NX_TARGET, [nx_container([stena])], :right), 0.001)
end

NxTest.test('NASTROJE-1: skryty VNUK vo viditelnom kontajneri doraz neblokuje') do
  # Dvojurovnove zanorenie: skryty je az potomok VNORENEJ skupiny. Jednourovnovy
  # vypocet obalky (kolo 3 P2) by ju nesol dalej a prisunutie by skoncilo skor.
  vnuk_blizky = { box: nx_box(700.0, 800.0), container: false }
  vnuk_stena = { box: nx_box(2000.0, 2100.0), container: false }
  so_vsetkym = nx_container([nx_container([vnuk_blizky, vnuk_stena])])
  bez_vnuka = nx_container([nx_container([vnuk_stena])])
  NxTest.assert_close(100.0, SC.nearest_gap(NX_TARGET, [so_vsetkym], :right), 0.001)
  NxTest.assert_close(1400.0, SC.nearest_gap(NX_TARGET, [bez_vnuka], :right), 0.001)
end

NxTest.test('NASTROJE-1: presahujuci potomok CIELA posuva jeho obalku (a s nou doraz)') do
  # Obalka ciela sa pocita TOU ISTOU traverzou — ked je presahujuci potomok
  # skryty, ciel je uzsi a doraz vyjde dalej (audit 2 FIX 6).
  sused = [{ box: nx_box(700.0, 1300.0), container: false }]
  siroky_ciel = nx_box(0.0, 650.0) # presahujuca uchytka je VIDITELNA
  NxTest.assert_close(50.0, SC.nearest_gap(siroky_ciel, sused, :right), 0.001)
  NxTest.assert_close(100.0, SC.nearest_gap(NX_TARGET, sused, :right), 0.001)
end

NxTest.test('NASTROJE-1: verdikty prisunutia (nic / doraz / WARN 10 m / BLOCK 20 m)') do
  NxTest.assert_equal(:none, SC.verdict(nil, nil))
  NxTest.assert_equal(:touching, SC.verdict(0.1, 0.1))
  NxTest.assert_equal(:ok, SC.verdict(500.0, 500.0))
  NxTest.assert_equal(:far, SC.verdict(12_000.0, 12_000.0))
  NxTest.assert_equal(:too_far, SC.verdict(25_000.0, 25_000.0))
  # Pri skalovanej cudzej instancii rozhoduje SVETOVA vzdialenost, nie lokalna.
  NxTest.assert_equal(:too_far, SC.verdict(10_000.0, 30_000.0))
  NxTest.assert_close(10_000.0, SC::WARN_MM, 0.001)
  NxTest.assert_close(20_000.0, SC::BLOCK_MM, 0.001)
end

# --- guard: UI vrstva sa headless NENACITAVA (FIX 8) ---------------------------

NxTest.test('NASTROJE-1 guard: headless sada nacitava LEN ciste jadra nastrojov') do
  helper = File.read(File.join(NxTest::ROOT, 'tests', 'helper.rb'), encoding: 'UTF-8')
  NxTest.assert(helper.include?('tools/mower_calc'), 'mower_calc chyba v zozname helpera')
  NxTest.assert(helper.include?('tools/snap_calc'), 'snap_calc chyba v zozname helpera')
  %w[tools/tools tools/mower tools/snaper].each do |rel|
    NxTest.refute(helper.include?("\n    #{rel}\n"),
                  "#{rel} sa headless nacitavat NESMIE (UI::Toolbar/HtmlDialog tam neexistuju)")
  end
  NxTest.skip!('v SketchUpe su UI moduly nacitane pluginom') unless NxTest.headless?

  NxTest.refute(defined?(Noxun::Engine::Tools::Mower), 'Tools::Mower sa headless nacital')
  NxTest.refute(defined?(Noxun::Engine::Tools::Snaper), 'Tools::Snaper sa headless nacital')
end

NxTest.test('NASTROJE-1 guard: vsetkych 9 prikazov ma restart latch a ikonu') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'tools', 'tools.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?('Engine.update_restart_pending?'),
                'D-52a: prikazy nastrojov musia mat restart latch')
  cmds = src.scan(/^\s+command\(/).length
  NxTest.assert_equal(9, cmds)
  icons = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'icons', 'tools')
  missing = %w[rotate_ccw rotate_cw rotate_180 z0 zmove copy_left copy_right].reject do |b|
    File.exist?(File.join(icons, "#{b}_16.png")) && File.exist?(File.join(icons, "#{b}_24.png"))
  end
  missing += %w[snap_left snap_right].reject { |b| File.exist?(File.join(icons, "#{b}.svg")) }
  NxTest.assert(missing.empty?, "chybajuce ikony nastrojov: #{missing.join(', ')}")
end

NxTest.test('NASTROJE-1 guard: Z-dialog je vo VSETKYCH TROCH zoznamoch bariery updatera') do
  upd = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'updater.rb'), encoding: 'UTF-8')
  sup = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'supplier_settings_dialog.rb'),
                  encoding: 'UTF-8')
  close_all = upd[/def self\.close_all_dialogs.*?\n    end/m].to_s
  NxTest.assert(close_all.include?('Tools::ZDialog'), 'close_all_dialogs nezatvara Z-dialog')
  closer = sup[/def close_plugin_dialogs.*?\n        end/m].to_s
  NxTest.assert(closer.include?('Tools::ZDialog'), 'close_plugin_dialogs nezatvara Z-dialog')
  waiter = sup[/def dialogs_closed\?.*?\n        end/m].to_s
  NxTest.assert(waiter.include?('Tools::ZDialog'), 'bariera necaka na zanik Z-dialogu')

  mower = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'tools', 'mower.rb'), encoding: 'UTF-8')
  NxTest.assert(mower.include?('Engine.update_locked?(:tools_z)'),
                'callback applyZ nie je guardovany latchom callbackov')
  NxTest.assert(mower.include?('set_on_closed'), 'Z-dialog nepusta referenciu po zatvoreni')
  # Callbacky PRED show (kontrakt HtmlDialog) — inak ich okno nikdy nedostane.
  NxTest.assert(mower.index('register_callbacks(@dialog)') < mower.index('def register_callbacks'),
                'callbacky sa musia registrovat v ensure_dialog, teda pred show')
end

NxTest.test('NASTROJE-1 guard: kopia ide cez sev enginu, nie cez add_instance') do
  mower = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'tools', 'mower.rb'), encoding: 'UTF-8')
  cab = mower[/def copy_cabinet.*?\n          end/m].to_s
  NxTest.refute(cab.include?('add_instance'),
                'kopia NOXUN korpusu cez add_instance = kopia bez identity (D-20)')
  NxTest.assert(cab.include?('CabinetBuilder.build'), 'kopia nejde cez sev vkladu')
  NxTest.assert(cab.include?('rekey_hardware_manual'), 'ad-hoc kovanie kopie musi dostat nove ID')
  NxTest.assert(cab.include?('newer_config?'), 'R-12 brana chyba')
  NxTest.assert(cab.include?('Units.vector'), 'posun sa nesmie skladat z holych mm')
  NxTest.assert(cab.include?('dedup: false'),
                'push_selected s predvolenym dedupom by zalozil zbytocnu poziadavku observera')
end

NxTest.test('NASTROJE-1 guard: kopia rusi ghost session a caka na Inspector') do
  mower = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'tools', 'mower.rb'), encoding: 'UTF-8')
  body = mower[/def copy\(dir\).*?\n          end/m].to_s
  # Volanie musi byt SAMOSTATNY prikaz — `false && GhostTool.cancel_session(...)`
  # by hole `include?` presiel a session by prezila.
  NxTest.assert(body =~ /^\s*GhostTool\.cancel_session\('kópia nástrojom'\) if defined\?\(GhostTool\)$/,
                'ghost visiaci na kurzore by dalsim klikom commitol STARY plan (vzor handle_insert_copy)')
  NxTest.assert(body.index('cancel_session') < body.index('start_cabinet_copy'),
                'session sa musi zrusit PRED vlozenim kopie')
  start = mower[/def start_cabinet_copy.*?\n          end/m].to_s
  NxTest.assert(start.include?('inspector_live?'), 'bez otvoreneho Inspectora niet co flushovat')
  NxTest.assert(start.include?('Panel.request_native_flush'), 'handshake sa nevyziada')
  NxTest.assert(start.include?('arm_flush_timeout'),
                'bez timeoutu by cakajuca kopia visela navzdy')
  fin = mower[/def finish_pending_copy.*?\n          end/m].to_s
  NxTest.assert(fin.include?("pending['dir']"),
                'smer kopie musi ist z cakajuceho zaznamu SERVERA, nie z echa klienta')
end

NxTest.test('NASTROJE-1 guard: `native_op` je uzavrety whitelist bez smeru z klienta') do
  ac = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'),
                 encoding: 'UTF-8')
  body = ac[/def resolve_native_op.*?\n        end/m].to_s
  NxTest.assert(body.include?('NATIVE_OPS.include?'), 'chyba whitelist druhu operacie')
  NxTest.assert(body.include?('manual_token('), 'token z klienta sa musi ocistit')
  NxTest.refute(body.include?("raw['dir']"),
                'smer kopie sa z payloadu klienta citat NESMIE — autorita je server')
  NxTest.assert(body.include?("'flushed'"), 'apply s native_op je pre server vysledok `flushed`')
  # Dispatch AZ po uspesnej prestavbe: odmietnute vetvy maju vlastny `return`.
  apply = ac[/def handle_apply_all.*?\n        end/m].to_s
  NxTest.assert(apply.include?('resolve_native_op(data)'),
                'handle_apply_all cakajucu kopiu vobec nespusta — server by cakal do timeoutu')
  NxTest.assert(apply.index('resolve_native_op(data)') > apply.index('CabinetBuilder.rebuild'),
                'kopia sa smie spustit AZ po zapise configu')
  panel = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
  NxTest.assert(panel.include?("cb(dlg, 'native_flush_done')"), 'callback odpovede nie je registrovany')
end

NxTest.test('NASTROJE-1 guard: JS odpovie serveru v KAZDEJ vetve flushu') do
  form = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'form.js'), encoding: 'UTF-8')
  fn = form[/function nxFlushForNative\(token, op\)\{.*?\n  \}/m].to_s
  NxTest.refute(fn.empty?, 'nxFlushForNative sa v form.js nenasla')
  %w[nothing invalid].each do |r|
    NxTest.assert(fn.include?("nxNativeFlushDone(token, '#{r}')"), "chyba vetva '#{r}'")
  end
  NxTest.assert(fn.include?('flushCabinetEdits(selectedCabId'), 'rozpisane edity sa neflushnu')
  flush = form[/function flushCabinetEdits\(cabSnapshot, guidSnapshot, nativeOp\)\{.*?\n    if \(nativeOp\) payload\.native_op = nativeOp;/m].to_s
  NxTest.refute(flush.empty?, 'flushCabinetEdits neprijima nativeOp')
  NxTest.assert_equal(3, flush.scan(/if \(nativeOp\) nxNativeFlushDone/).length,
                      'kazda predcasna navratova vetva flushu musi serveru odpovedat')
  bridge = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), encoding: 'UTF-8')
  NxTest.assert(bridge.include?('flushForNative: function(token, op)'), 'NX.flushForNative chyba')
  NxTest.assert(bridge.include?("nxNativeFlushDone(token, 'nothing')"),
                'bez formularovej vrstvy musi bridge odpovedat sam (inak server caka do timeoutu)')
end
