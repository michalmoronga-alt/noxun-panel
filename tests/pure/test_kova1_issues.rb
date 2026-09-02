# frozen_string_literal: true
# KOV-A1 — RED KANAL „dvierka bez urceneho smeru" (`hardware_issues` -> Kontrola).
#
# CO SA OVERUJE
#   1) `Bom.front_direction_issues` (CISTA funkcia, headless): nalez vznikne
#      VYHRADNE pri stave `unset`; legacy (kluc chyba) ani vyriesene
#      `left`/`right` nalez netvoria. Aplikovatelnost urcuje VYHRADNE
#      `Fronts.direction_slots` — single pri 1 kridle, p2 pri 3, p2+p3 pri 4,
#      dvojkridlo a ne-dvierka NIC.
#   2) Identita pri DUPLICITNOM `cabinet_id` (audit #14 FIX 11): `owner_pid`
#      nesie instanciu, ktora smer nema; `stable_key` ostava
#      `front_direction|owner_id|part_key`, takze dva rovnake nalezy sa zlievaju
#      do JEDNEHO riadku Kontroly.
#   3) `Validation.run` z toho stavia RED riadok kategorie `front_direction`
#      s textom podla mockupu (scena 4) — a NEROBI z neho branu.
#   4) `Bom.compute` je s klucom aj bez neho OBSAHOVO IDENTICKY (kusovnik,
#      nakup ani ceny sa nemenia ani o cislo).
#   5) Ine kody `hardware_issues` sa v A1 IGNORUJU (patria ku svojim branam
#      v KOV-C/D).
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `front_direction_issues` tvori nalez aj pri stave nil (legacy).
#   2. `owner_pid` sa dostane do `stable_key` (dva nalezy namiesto jedneho).
#   3. `Validation.run` nalez pusti ako ORANGE namiesto RED.
#   4. `check_hardware_issues` spracuje KAZDY kod, nielen `front_direction_unset`.
require_relative '../helper' unless defined?(NxTest)

require 'json'

module NxKovA1Iss
  E  = Noxun::Engine
  F  = E::Fronts
  B  = E::Bom
  V  = E::Validation

  SRC_DIR = File.join(NxTest::ROOT, 'noxun_engine')

  module_function

  def src(rel)
    File.read(File.join(SRC_DIR, rel), encoding: 'UTF-8')
  end

  # Resolved celo, presne v tvare, v akom zije v ulozenom `config['front_items']`.
  def front(over = {})
    { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => 500.0,
      'locked' => false, 'wings' => '1', 'wings_n' => 1, 'profile' => 'none',
      'z' => 102.0 }.merge(over)
  end

  def issues(front_items, cid = 'CAB-1', pid = 101)
    B.front_direction_issues(cid, pid, front_items)
  end

  # Zber v tvare, aky Validation.run dostava z Bom.collect.
  def collected(hardware_issues)
    { records: [], hardware_overrides: [], warnings: [], cabinets: 1,
      hardware_issues: hardware_issues }
  end

  def run_items(hardware_issues)
    V.run(collected(hardware_issues))['items']
  end
end

module NxTest
  I = NxKovA1Iss

  # ==================== 1) kedy nalez VZNIKNE a kedy NIE ====================

  test('KOV-A1 RED: nalez vznikne VYHRADNE pri `unset` (legacy ani strana nic netvoria)') do
    assert_equal(1, I.issues([I.front('direction' => 'unset')]).length, 'unset = nalez')
    %w[left right].each do |d|
      assert_equal([], I.issues([I.front('direction' => d)]), "#{d} = vyriesene, ziadny nalez")
    end
    # LEGACY: kluc v configu vobec nie je -> stav nil -> NIKDY nalez.
    assert_equal([], I.issues([I.front]), 'legacy celo NESMIE dostat RED')
    assert_equal([], I.issues([]), 'skrinka bez ciel')
    assert_equal([], I.issues(nil), 'poskodeny/chybajuci front_items')
    assert_equal([], I.issues('nieco'), 'ne-pole sa ignoruje')
    assert_equal([], I.issues([nil, 'x', 7]), 'ne-hash polozky sa preskocia')
  end

  test('KOV-A1 RED: tvar nalezu — kod, zavaznost, adresa, part_key, label') do
    iss = I.issues([I.front('direction' => 'unset')], 'CAB-5', 4242).first
    assert_equal('front_direction_unset', iss['code'])
    assert_equal('red', iss['severity'])
    assert_equal('CAB-5', iss['owner_id'])
    assert_equal(4242, iss['owner_pid'])
    assert_equal('front:F1/wing:single', iss['part_key'])
    assert_equal('F1', iss['front_id'])
    assert_equal('F1 · dvierka', iss['label'], 'label je SERVEROVY human_label (JS nic neskladá)')
    assert_equal(JSON.parse(JSON.generate(iss)), iss, 'zaznam je cisty JSON tvar (ziadny SketchUp objekt)')
  end

  test('KOV-A1 RED: stredne kridla 3/4-kridlovych dvierok maju vlastny nalez') do
    three = I.front('wings' => '3', 'wings_n' => 3,
                    'wing_directions' => { 'p2' => 'unset' })
    out3 = I.issues([three])
    assert_equal(1, out3.length, 'pri 3 kridlach je stredne LEN p2')
    assert_equal('front:F1/wing:p2', out3.first['part_key'])
    assert_equal('F1 · dvierka, krídlo 2/3', out3.first['label'])

    four = I.front('wings' => '4', 'wings_n' => 4,
                   'wing_directions' => { 'p2' => 'unset', 'p3' => 'unset' })
    out4 = I.issues([four])
    assert_equal(%w[front:F1/wing:p2 front:F1/wing:p3], out4.map { |x| x['part_key'] },
                 'pri 4 kridlach su dva samostatne nalezy')

    # Krajne kridla su ODVODENE — nikdy nalez netvoria, ani ked su 4.
    solved = I.front('wings' => '4', 'wings_n' => 4,
                     'wing_directions' => { 'p2' => 'left', 'p3' => 'right' })
    assert_equal([], I.issues([solved]), 'vyriesene stredne kridla = ziadny nalez')
  end

  test('KOV-A1 RED: dvojkridlo a ne-dvierka sa na smer nepytaju') do
    two = I.front('wings' => '2', 'wings_n' => 2, 'direction' => 'unset')
    assert_equal([], I.issues([two]), 'dvojkridlo: Lave+Prave su jednoznacne')
    %w[drawer_front lift fall blind none].each do |t|
      it = I.front('type' => t, 'direction' => 'unset')
      assert_equal([], I.issues([it]), "#{t}: smer sa nepyta")
    end
  end

  test('KOV-A1 RED: viac ciel v skrinke -> nalez na kazde neurcene celo') do
    items = [I.front('id' => 'F1', 'direction' => 'unset'),
             I.front('id' => 'F2', 'direction' => 'left'),
             I.front('id' => 'F3'),
             I.front('id' => 'F4', 'direction' => 'unset')]
    out = I.issues(items)
    assert_equal(%w[F1 F4], out.map { |x| x['front_id'] })
    assert_equal(['F1 · dvierka', 'F4 · dvierka'], out.map { |x| x['label'] },
                 'cislo v labeli je PORADIE v zozname ciel, ktore vidi pouzivatel')
  end

  # ==================== 2) duplicitna identita (FIX 11) =====================

  test('KOV-A1 RED: dup-ID s roznym smerom -> JEDEN riadok, owner_pid instancie s `unset`') do
    # Dve fyzicke skrinky so ZDIELANYM cabinet_id: prva ma smer urceny, druha nie.
    a = I.issues([I.front('direction' => 'left')], 'CAB-9', 111)
    b = I.issues([I.front('direction' => 'unset')], 'CAB-9', 222)
    raw = a + b
    assert_equal(1, raw.length, 'nalez tvori LEN instancia bez smeru')
    assert_equal(222, raw.first['owner_pid'], 'owner_pid ukazuje na KONKRETNU instanciu')

    items = I.run_items(raw)
    assert_equal(1, items.length)
    assert_equal(222, items.first['owner_pid'], 'pid sa nesie do Kontroly ako extra pole')

    # Ked NEMAJU smer OBE, je to stale JEDEN problem jedneho dielca jedneho ID.
    both = I.issues([I.front('direction' => 'unset')], 'CAB-9', 111) +
           I.issues([I.front('direction' => 'unset')], 'CAB-9', 222)
    assert_equal(2, both.length, 'zber je per instancia')
    dedup = I.run_items(both)
    assert_equal(1, dedup.length, 'Kontrola ich zlieva podla stable_key')
    assert_equal('front_direction|CAB-9|front:F1/wing:single', dedup.first['stable_key'])
    refute(dedup.first['stable_key'].include?('111'), 'owner_pid do stable_key NEPATRI')
    refute(dedup.first['stable_key'].include?('222'), 'owner_pid do stable_key NEPATRI')
  end

  # ==================== 3) Validation.run: RED bez brany ====================

  test('KOV-A1 RED: Validation.run vyrobi RED riadok kategorie front_direction') do
    it = I.run_items(I.issues([I.front('direction' => 'unset')], 'CAB-5', 7)).first
    assert(it, 'nalez sa musi dostat do Kontroly')
    assert_equal(I::V::RED, it['severity'], 'neurceny smer je RED (O1 = a)')
    assert_equal('front_direction', it['category'])
    assert_equal(I::V::CAT_FRONT_DIR, it['category'])
    assert_equal('CAB-5', it['owner_id'], 'klik-select ide cez owner_id + part_key')
    assert_equal('front:F1/wing:single', it['part_key'])
    assert_equal(nil, it['hw_key'])
    m = it['message_sk']
    assert(m.include?('F1 · dvierka'), 'hlaska menuje CELO cez serverovy label')
    assert(m.include?('CAB-5'), 'hlaska menuje SKRINKU')
    assert(m.include?('pántov'), 'hlaska hovori, ze smer = strana pantov')
    assert(m.include?('neblokuje'), 'hlaska priznava, ze export sa zatial nezastavi')
    assert(m.include?('D-95'), 'hlaska pomenuje davku, ktora branu prinesie')
  end

  test('KOV-A1 RED: counts — nalez sa rata do RED, skrinka prestava byt „cista"') do
    res = I::V.run(I.collected(I.issues([I.front('direction' => 'unset')])),
                   placements: [{ 'kind' => 'cabinet', 'owner_id' => 'CAB-1' }])
    assert_equal(1, res['counts']['red'])
    assert_equal(0, res['counts']['orange'])
    assert_equal(1, res['counts']['total'])
    assert_equal(0, res['counts']['clean'], 'skrinka s nalezom uz nie je bez nalezu')
  end

  test('KOV-A1 RED: chybajuci kluc `hardware_issues` nic nemeni (legacy volania)') do
    assert_equal([], I::V.run({ records: [], cabinets: 0 })['items'])
    assert_equal([], I.run_items(nil))
    assert_equal([], I.run_items([]))
    assert_equal([], I.run_items(['nieco', nil, 7]), 'poskodene zaznamy sa preskocia')
  end

  test('KOV-A1 RED: ine kody hardware_issues sa v A1 ZAMERNE ignoruju (KOV-C/D)') do
    future = [{ 'code' => 'drawer_no_fit', 'severity' => 'red', 'owner_id' => 'CAB-2',
                'part_key' => 'front:F1/panel' },
              { 'code' => 'owner_without_set', 'severity' => 'red', 'owner_id' => 'CAB-3' }]
    assert_equal([], I.run_items(future), 'kod bez svojej brany sa do Kontroly nedostane')
    mixed = future + I.issues([I.front('direction' => 'unset')])
    items = I.run_items(mixed)
    assert_equal(1, items.length)
    assert_equal('front_direction', items.first['category'])
  end

  test('KOV-A1 RED: ZIADNA exportna brana (R-39 ostava otvorena)') do
    # Brana je pre-committed v AUDIT_REGISTER a pristane az s prvym vystupom,
    # ktory smer realne spotrebuje (D-95). Dovtedy sa kategoria NESMIE objavit
    # v ziadnom mieste, ktore zastavuje zapis suboru.
    %w[ui/production_core.rb core/cp_export.rb core/vepo_export.rb core/budget.rb].each do |rel|
      s = I.src(rel)
      refute(s.include?('front_direction'), "#{rel} nesmie o smerovom naleze vobec vediet")
      refute(s.include?('CAT_FRONT_DIR'), "#{rel} nesmie citat kategoriu smeru")
    end
    reg = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'AUDIT_REGISTER.md'), encoding: 'UTF-8')
    assert(reg.include?('R-39'), 'brana ostava evidovana ako OTVORENA polozka registra')
  end

  # ==================== 4) vystupy sa NEMENIA ===============================

  test('KOV-A1: Bom.compute je s klucom hardware_issues aj bez neho IDENTICKY') do
    rec = { 'name' => 'Dvierka 1', 'part_key' => 'front:F1/wing:single', 'owner_id' => 'CAB-1',
            'role' => 'front_door', 'length' => 500.0, 'width' => 596.0, 'thickness' => 18.0,
            'material_id' => 'K009', 'grain_direction' => 'none', 'quantity' => 1, 'pid' => 11,
            'edges' => { 'L1' => 'A1', 'L2' => 'A1', 'W1' => 'A1', 'W2' => 'A1' } }
    hw = [{ 'generic_type' => 'hinge', 'quantity' => 2, 'owner_id' => 'CAB-1' }]
    base = { records: [rec], hardware: hw, warnings: [], cabinets: 1, boards: 0 }
    with = base.merge(hardware_issues: I.issues([I.front('direction' => 'unset')]))
    assert_equal(JSON.generate(I::B.compute(base)), JSON.generate(I::B.compute(with)),
                 'kusovnik, nakup ani ceny sa novym klucom NEMENIA ani o cislo')
  end

  # ============ P2-A: `owner_pid` scopuje klik na JEDEN vyskyt ==============
  #
  # Charakterizacia ZDROJA (vzor test_1b3_citanie.rb): telo `pids_for_problem`
  # vyzaduje ZIVY SketchUp model, takze sa headless spustit neda — overuje sa
  # PRITOMNOST vetvy a jej fail-open guardy. Ucinok nad realnym modelom dokazuje
  # in-SketchUp sekcia `run_kova` (dup-ID scenar).
  test('KOV-A1 P2-A: Validation prenasa owner_pid do polozky Kontroly (mimo stable_key)') do
    it = I.run_items(I.issues([I.front('direction' => 'unset')], 'CAB-5', 909)).first
    assert_equal(909, it['owner_pid'], 'bez tohto pola nema klik co scopovat')
    refute(it['stable_key'].include?('909'), 'pid je adresa VYSKYTU, nie identita problemu')
  end

  test('KOV-A1 P2-A: pids_for_problem scopuje podla owner_pid a je FAIL-OPEN') do
    s = I.src('ui/production_core.rb')
    branch = s[/def pids_for_problem\(model, item\).*?\n        out = \[\]/m].to_s
    assert(branch.include?('scoped_owner_instance(model, item, oid)'),
           'pids_for_problem sa musi najprv spytat na scope podla owner_pid')
    assert(branch.include?('return pids_in_cabinet(scoped, pkey) if scoped'),
           'pri overenej instancii hlada dielec LEN v nej')
    scope = s[/def scoped_owner_instance\(model, item, oid\).*?\n      end/m].to_s
    assert(scope.include?("pid.is_a?(Integer)"), 'kluc musi byt Integer (fail-open)')
    assert(scope.include?('find_entity_by_persistent_id(pid)'), 'entita sa hlada cerstvo v modeli')
    assert(scope.include?('ent.valid?'), 'zanikla entita = fail-open')
    assert(scope.include?('ent.parent.is_a?(Sketchup::Model)'), 'len TOP-LEVEL kus')
    assert(scope.include?("Store.kind(ent) == 'cabinet'"), 'len korpus (dosky/dielce sa nemenia)')
    assert(scope.include?("Store.get(ent, 'cabinet_id').to_s == oid"),
           'autoritou ostava IDENTITA — nezhodne cabinet_id = fail-open')
    fb = s[/def pids_in_cabinet\(inst, pkey\).*?\n      end/m].to_s
    assert(fb.include?('found.empty? ? [inst.persistent_id] : found'),
           'nepostaveny dielec = vlastnik, nikdy prazdny vyber')
    # Vetvy board/part a dup kategorie ostavaju NEDOTKNUTE.
    assert(s.include?('return pids_for_duplicate(model, item) if dup_cats.include?'),
           'dup kategorie maju nadalej vlastnu adresu')
  end

  test('KOV-A1: collect nesie hardware_issues ako ADITIVNY kluc (zdroj = ulozeny config)') do
    s = I.src('core/bom.rb')
    assert(s.include?('hardware_issues: hardware_issues'), 'kluc je sucastou navratu collect')
    assert(s.include?("front_direction_issues(cid, inst.persistent_id, ccfg['front_items'])"),
           'zdrojom je ULOZENY front_items korpusu — ziadne prepocitavanie planu')
    refute(I.src('core/bom.rb').match?(/def compute.*hardware_issues/m),
           'compute() kluc nikde necita')
  end
end
