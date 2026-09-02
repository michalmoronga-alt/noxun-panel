# frozen_string_literal: true
# KOV-A1 — DATOVA VRSTVA CIEL: typy, smer, klasifikacia, nove roly.
#
# CO SA OVERUJE
#   1) TROJSTAV smeru (audit #14 BLOCKER 1): kluc CHYBA = legacy (NIKDY sa
#      nedoplna) · 'unset' = vedome neurcene · 'left'/'right' = vyriesene.
#      Poskodena hodnota (neznamy neprazdny string) -> 'unset' (fail-visible),
#      nil/'' -> kluc prec. ZIADNA cesta nesmie z chybajuceho pola vyrobit
#      `unset` ani stranu — a to vo VSETKYCH 6 projekciach configu.
#   2) DORMANT (BLOCKER 3): `direction`, `wing_directions`, `opening_mode`
#      a `drawer` sa drzia bez ohladu na typ a pocet kridiel; po navrate na
#      dvierka/1 kridlo sa hodnota obnovi.
#   3) `Fronts.direction_slots` = JEDINA definicia aplikovatelnosti smeru;
#      rozhoduje EFEKTIVNY `wings_n` (auto okolo 600 mm), nie surove `wings`.
#   4) BLOCKER 2 (Michal 3.9., variant a): krajne kridla su ODVODENE (nic sa
#      neuklada), stredne (p2/p3) maju vlastny trojstav.
#   5) BLOCKER 4: zasuvka bez klasifikacie ostava „neklasifikovana" — nikdy sa
#      nedoplni `metal`+`standard`.
#   6) BLOCKER 5: kanonicke part_keys `front:F#/flap` a `front:F#/blind`,
#      suffixy FLAP-#/BLIND-#, `human_label` vetvy; overridy su per kind, takze
#      pri prepnuti typu ostavaju DORMANT pod starym klucom.
#   7) Nove roly `flap`/`false_front` prechadzaju VSETKYMI allowlistmi (tag,
#      material, hrubka 18/18,6/19, osi, ABS labely/strany/seed, ROLE_LABELS,
#      FRONT_ROLES, ABS_ROLE_ORDER, part_card.js).
#   8) `CONFIG_SCHEMA >= 2` (R-12).
#   9) GUARDY: ziadny default smeru v Ruby ani JS; form.js pass-through bez
#      defaultu + tri NEAKTIVNE volby typu.
#
# `hardware_issues` + RED kategoria `front_direction` maju vlastnu sadu
# (`test_kova1_issues.rb`); obsahova nemennost vystupov je v `test_kova_golden.rb`.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `Fronts.layout` neprenesie `direction` do resolved itemu (5. projekcia).
#   2. `normalize_items` materializuje `direction => 'unset'` aj pri chybajucom kluci.
#   3. `direction_slots` cita surove `wings` namiesto efektivneho `wings_n`.
#   4. `normalize_items` necha profil na `blind` (namiesto sklopenia na 'none').
require_relative '../helper' unless defined?(NxTest)

require 'json'

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
end

module NxKovA1
  E  = Noxun::Engine
  F  = E::Fronts
  CB = E::CabinetBuilder
  PK = E::PartKeys

  SRC_DIR = File.join(NxTest::ROOT, 'noxun_engine')

  module_function

  def src(rel)
    File.read(File.join(SRC_DIR, rel), encoding: 'UTF-8')
  end

  def base(over = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 100.0, 'back_thickness' => 3.0 }.merge(over)
  end

  def door(over = {})
    { 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 500.0,
      'wings' => '1' }.merge(over)
  end

  # --- 6 PROJEKCII configu ---------------------------------------------------
  #
  # Kazda z nich je miesto, kde uz raz pole ticho vypadlo (D-90 P1). Test ich
  # preto prechadza VSETKY naraz a porovnava TU ISTU polozku.
  PROJECTIONS = %w[normalize_items config_to_params normalize cabinet_config
                   template_config_from front_items].freeze

  # Vrati { projekcia => polozka cela } pre PRVU polozku configu.
  def projections(raw_items, width = 600.0)
    fronts = { 'items' => raw_items }
    norm   = CB.normalize(base('width' => width).merge('fronts' => fronts))
    plan   = E::Construction.build_plan(norm)
    merged = CB.merge_final(norm, plan)
    stored = JSON.parse(JSON.generate(CB.cabinet_config(merged)))
    {
      'normalize_items'      => F.normalize_items(raw_items).first,
      'config_to_params'     => CB.config_to_params(stored)['fronts']['items'].first,
      'normalize'            => norm[:fronts]['items'].first,
      'cabinet_config'       => stored['fronts']['items'].first,
      'template_config_from' => E::Panel.template_config_from(stored)['fronts']['items'].first,
      'front_items'          => stored['front_items'].first
    }
  end

  # Resolved polozky (`front_items`) pre cely config — pre `direction_slots`.
  def resolved(raw_items, width = 600.0, height = 720.0, floor = 100.0)
    F.layout({ 'items' => raw_items }, width, height, floor, 18.0)[:items]
  end

  def plan_parts(raw_items, width = 600.0)
    E::Construction.build_plan(CB.normalize(base('width' => width).merge('fronts' => { 'items' => raw_items })))[:parts]
  end

  def part_by_suffix(parts, suffix)
    parts.find { |pd| pd[:suffix] == suffix }
  end
end

module NxTest
  K = NxKovA1

  # ========================= 1) TYPY A ROLY ================================

  test('KOV-A1: normalize_items pozna 6 typov; neznamy typ ostava „door"') do
    %w[door drawer_front lift fall blind none].each do |t|
      out = K::F.normalize_items([K.door('type' => t)]).first
      assert_equal(t, out['type'], "typ #{t} musi prezit normalizaciu")
    end
    assert_equal('door', K::F.normalize_items([K.door('type' => 'sliding_2027')]).first['type'],
                 'neznamy typ (aj z novsej verzie) sa sklopi na door — config nesmie spadnut')
    assert_equal(%w[door drawer_front lift fall blind none], K::F::TYPES,
                 'zoznam typov je uzavrety a stabilny')
  end

  test('KOV-A1: lift/fall -> rola flap (FLAP-#, front:F#/flap); blind -> false_front (BLIND-#)') do
    lift = K.plan_parts([K.door('type' => 'lift')])
    p = K.part_by_suffix(lift, 'FLAP-1')
    assert(p, 'vyklop musi vyrobit dielec so suffixom FLAP-1')
    assert_equal('flap', p[:role])
    assert_equal('front:F1/flap', p[:part_key])
    assert_equal('Výklop 1', p[:name])
    assert_equal(:front, p[:material], 'vyklop je celny dielec (material :front)')

    fall = K.part_by_suffix(K.plan_parts([K.door('type' => 'fall')]), 'FLAP-1')
    assert_equal('flap', fall[:role], 'sklop nesie TU ISTU rolu ako vyklop')
    assert_equal('front:F1/flap', fall[:part_key], 'sklop ma ten isty kanonicky kluc')
    assert_equal('Sklop 1', fall[:name], 'nazov rozlisuje vyklop od sklopu')

    blind = K.part_by_suffix(K.plan_parts([K.door('type' => 'blind')]), 'BLIND-1')
    assert(blind, 'blenda musi vyrobit dielec so suffixom BLIND-1')
    assert_equal('false_front', blind[:role])
    assert_equal('front:F1/blind', blind[:part_key])
    assert_equal('Blenda 1', blind[:name])
  end

  test('KOV-A1: vyklop/sklop/blenda maju ROVNAKU matematiku ako zasuvkove celo') do
    drw = K.part_by_suffix(K.plan_parts([K.door('type' => 'drawer_front')]), 'DRW-1')
    %w[lift fall blind].each do |t|
      parts = K.plan_parts([K.door('type' => t)])
      p = parts.find { |x| %w[flap false_front].include?(x[:role]) }
      assert_equal(drw[:box], p[:box], "#{t}: box musi sediet so zasuvkovym celom")
      assert_equal(drw[:origin], p[:origin], "#{t}: origin musi sediet so zasuvkovym celom")
      assert_equal(drw[:prod], p[:prod], "#{t}: vyrobne udaje musia sediet")
      assert_equal(drw[:axes], p[:axes], "#{t}: osi musia sediet (AXES_FRONT)")
      assert_equal(1, parts.count { |x| %w[flap false_front].include?(x[:role]) },
                   "#{t}: PRAVE jeden panel")
    end
  end

  test('KOV-A1: vedomy limit — profil je na lift/fall/blind normalizovany na none') do
    %w[lift fall blind none].each do |t|
      out = K::F.normalize_items([K.door('type' => t, 'profile' => 'ukw7')]).first
      assert_equal(E::FrontProfiles::NONE, out['profile'],
                   "#{t}: profil sa sklopi na none (inak by vznikol falosny profile_rule_missing)")
    end
    %w[door drawer_front].each do |t|
      out = K::F.normalize_items([K.door('type' => t, 'profile' => 'ukw7')]).first
      assert_equal('ukw7', out['profile'], "#{t}: profil ostava (D-90 sa nemeni)")
    end
  end

  test('KOV-A1: wings su neutralne 1 pre vsetky ne-dvierkove typy') do
    %w[drawer_front lift fall blind none].each do |t|
      out = K::F.normalize_items([K.door('type' => t, 'wings' => '3')]).first
      assert_equal(1, out['wings'], "#{t}: wings je neutralne 1")
    end
    assert_equal('3', K::F.normalize_items([K.door('wings' => '3')]).first['wings'])
  end

  test('KOV-A1: resolved celo nesie flap_dir odvodeny z typu (a nikde inde)') do
    assert_equal('up', K.resolved([K.door('type' => 'lift')]).first['flap_dir'])
    assert_equal('down', K.resolved([K.door('type' => 'fall')]).first['flap_dir'])
    %w[door drawer_front blind none].each do |t|
      it = K.resolved([K.door('type' => t)]).first
      refute(it.key?('flap_dir'), "#{t}: flap_dir nema co robit na nepohyblivom cele")
    end
  end

  # ================== 2) TROJSTAV SMERU cez 6 PROJEKCII ====================

  test('KOV-A1: LEGACY (kluc chyba) ostava bez kluca vo VSETKYCH 6 projekciach') do
    proj = K.projections([K.door])
    K::PROJECTIONS.each do |name|
      it = proj[name]
      assert(it, "projekcia #{name} nevratila polozku")
      %w[direction wing_directions opening_mode drawer].each do |key|
        refute(it.key?(key), "#{name}: legacy polozka NESMIE dostat kluc '#{key}'")
      end
    end
  end

  test('KOV-A1: unset/left/right prezije VSETKYCH 6 projekcii (string aj symbol kluce)') do
    %w[unset left right].each do |state|
      [{ 'direction' => state }, { direction: state }].each_with_index do |over, i|
        proj = K.projections([K.door.merge(over)])
        K::PROJECTIONS.each do |name|
          assert_equal(state, proj[name]['direction'],
                       "#{name}: smer '#{state}' (#{i.zero? ? 'string' : 'symbol'} kluc) musi prejst")
        end
      end
    end
  end

  test('KOV-A1: poskodena hodnota smeru -> unset (fail-visible); nil/prazdne -> kluc prec') do
    ['lefft', 'ĽAVÉ', 'left_top_2027'].each do |bad|
      out = K::F.normalize_items([K.door('direction' => bad)]).first
      assert_equal('unset', out['direction'], "poskodeny smer '#{bad}' sa PRIZNA ako neurceny")
    end
    [nil, '', '   '].each do |empty|
      out = K::F.normalize_items([K.door('direction' => empty)]).first
      refute(out.key?('direction'), "prazdna hodnota (#{empty.inspect}) = kluc sa zahodi (legacy)")
    end
    # Iny TYP nie je smer a nikdy nim nebol — RED nalez z takej hodnoty by
    # nikoho nikam nedoviedol.
    [42, true, [], {}].each do |weird|
      out = K::F.normalize_items([K.door('direction' => weird)]).first
      refute(out.key?('direction'), "hodnota #{weird.inspect} nie je smer -> kluc prec")
    end
  end

  test('KOV-A1: wing_directions — len p2/p3, ostatne kluce sa zahadzuju') do
    out = K::F.normalize_items([K.door('wings' => '4', 'wing_directions' => {
                                         'p1' => 'left', 'p2' => 'right', 'p3' => 'unset',
                                         'p4' => 'left', 'p9' => 'left'
                                       })]).first
    assert_equal({ 'p2' => 'right', 'p3' => 'unset' }, out['wing_directions'],
                 'ukladaju sa VYHRADNE stredne kridla — krajne su odvodene')
    # symbolove kluce
    sym = K::F.normalize_items([K.door(wing_directions: { p2: 'left' })]).first
    assert_equal({ 'p2' => 'left' }, sym['wing_directions'])
    # bez jedineho platneho kluca -> pole vobec nevznikne
    %w[p1 p4].each do |k|
      empty = K::F.normalize_items([K.door('wing_directions' => { k => 'left' })]).first
      refute(empty.key?('wing_directions'), "sam '#{k}' nie je stredne kridlo -> kluc prec")
    end
    refute(K::F.normalize_items([K.door('wing_directions' => 'left')]).first.key?('wing_directions'),
           'ne-hash sa zahodi')
  end

  test('KOV-A1: opening_mode — classic/tipon prejde, cokolvek ine kluc ZAHODI') do
    %w[classic tipon].each do |m|
      assert_equal(m, K::F.normalize_items([K.door('opening_mode' => m)]).first['opening_mode'])
    end
    ['servo', '', nil, 'CLASSIC', 7].each do |bad|
      out = K::F.normalize_items([K.door('opening_mode' => bad)]).first
      refute(out.key?('opening_mode'),
             "neplatny opening_mode #{bad.inspect} = kluc prec (stav 'neurceny' tu neexistuje)")
    end
  end

  test('KOV-A1: zasuvka bez klasifikacie ostava NEKLASIFIKOVANA (BLOCKER 4)') do
    plain = K::F.normalize_items([K.door('type' => 'drawer_front')]).first
    refute(plain.key?('drawer'), 'nikdy sa nedoplni metal+standard')
    proj = K.projections([K.door('type' => 'drawer_front')])
    K::PROJECTIONS.each { |n| refute(proj[n].key?('drawer'), "#{n}: klasifikacia sa nesmie vymysliet") }

    # Pod-polia su NEZAVISLE — samotna konstrukcia je platny stav.
    only_c = K::F.normalize_items([K.door('drawer' => { 'construction' => 'wood' })]).first
    assert_equal({ 'construction' => 'wood' }, only_c['drawer'])
    only_v = K::F.normalize_items([K.door('drawer' => { 'variant' => 'internal' })]).first
    assert_equal({ 'variant' => 'internal' }, only_v['drawer'])
    both = K::F.normalize_items([K.door(drawer: { construction: 'metal', variant: 'standard' })]).first
    assert_equal({ 'construction' => 'metal', 'variant' => 'standard' }, both['drawer'])
    # Hash bez jedineho platneho pod-pola -> kluc prec.
    [{ 'construction' => 'plastic' }, { 'variant' => 'hidden' }, {}, 'metal'].each do |bad|
      out = K::F.normalize_items([K.door('drawer' => bad)]).first
      refute(out.key?('drawer'), "#{bad.inspect} nema platne pod-pole -> kluc prec")
    end
  end

  test('KOV-A1: vsetky 4 nove polia prejdu VSETKYMI 6 projekciami naraz') do
    item = K.door('wings' => '4', 'direction' => 'left',
                  'wing_directions' => { 'p2' => 'unset', 'p3' => 'right' },
                  'opening_mode' => 'tipon',
                  'drawer' => { 'construction' => 'wood', 'variant' => 'internal' })
    proj = K.projections([item])
    K::PROJECTIONS.each do |name|
      it = proj[name]
      assert_equal('left', it['direction'], "#{name}: direction")
      assert_equal({ 'p2' => 'unset', 'p3' => 'right' }, it['wing_directions'], "#{name}: wing_directions")
      assert_equal('tipon', it['opening_mode'], "#{name}: opening_mode")
      assert_equal({ 'construction' => 'wood', 'variant' => 'internal' }, it['drawer'], "#{name}: drawer")
    end
  end

  # ========================= 3) DORMANT =====================================

  test('KOV-A1: DORMANT — polia sa drzia pri kazdom type (prepnutie tam a spat)') do
    full = { 'direction' => 'right', 'wing_directions' => { 'p2' => 'left' },
             'opening_mode' => 'tipon',
             'drawer' => { 'construction' => 'metal', 'variant' => 'internal' } }
    %w[door drawer_front lift fall blind none].each do |t|
      out = K::F.normalize_items([K.door(full.merge('type' => t))]).first
      full.each do |k, v|
        assert_equal(v, out[k], "#{t}: '#{k}' sa musi udrzat aj ked typ pole nepouziva")
      end
    end
    # Prepnutie dvierka -> zasuvka -> dvierka: hodnota sa OBNOVI (nikde sa nestrati).
    a = K::F.normalize_items([K.door(full)]).first
    b = K::F.normalize_items([a.merge('type' => 'drawer_front')]).first
    c = K::F.normalize_items([b.merge('type' => 'door', 'wings' => '1')]).first
    assert_equal('right', c['direction'], 'smer prezije cestu dvierka -> zasuvka -> dvierka')
    assert_equal({ 'p2' => 'left' }, c['wing_directions'])
    assert_equal('tipon', c['opening_mode'])
    assert_equal({ 'construction' => 'metal', 'variant' => 'internal' }, c['drawer'])
  end

  test('KOV-A1: DORMANT — smer prezije prepnutie 1 -> 2 -> 1 kridlo a NECITA sa medzitym') do
    item = K.door('direction' => 'unset', 'wings' => '1')
    one = K.resolved([item]).first
    assert_equal(1, one['wings_n'])
    assert_equal(1, K::F.direction_slots(one).length, 'jednokridlo sa na smer pyta')

    two = K.resolved([K::F.normalize_items([item.merge('wings' => '2')]).first]).first
    assert_equal('unset', two['direction'], 'hodnota ostava ulozena (dormant)')
    assert_equal([], K::F.direction_slots(two), 'dvojkridlo smer NECITA (odvodeny L+P)')

    back = K.resolved([K::F.normalize_items([two.merge('wings' => '1')]).first]).first
    assert_equal([{ wing: 'single', part_key: 'front:F1/wing:single', state: 'unset' }],
                 K::F.direction_slots(back), 'po navrate na 1 kridlo sa hodnota OBNOVI')
  end

  # ==================== 4) direction_slots (jedina definicia) ===============

  test('KOV-A1: direction_slots — 1/2/3/4 kridla (krajne odvodene, stredne vlastne)') do
    wd = { 'p2' => 'unset', 'p3' => 'left' }
    one = K.resolved([K.door('wings' => '1', 'direction' => 'left')]).first
    assert_equal([{ wing: 'single', part_key: 'front:F1/wing:single', state: 'left' }],
                 K::F.direction_slots(one))

    two = K.resolved([K.door('wings' => '2', 'direction' => 'left')]).first
    assert_equal([], K::F.direction_slots(two), 'dvojkridlo: Lave+Prave su jednoznacne')

    three = K.resolved([K.door('wings' => '3', 'wing_directions' => wd)]).first
    assert_equal([{ wing: 'p2', part_key: 'front:F1/wing:p2', state: 'unset' }],
                 K::F.direction_slots(three), 'pri 3 kridlach je stredne LEN p2')

    four = K.resolved([K.door('wings' => '4', 'wing_directions' => wd)]).first
    assert_equal([{ wing: 'p2', part_key: 'front:F1/wing:p2', state: 'unset' },
                  { wing: 'p3', part_key: 'front:F1/wing:p3', state: 'left' }],
                 K::F.direction_slots(four), 'pri 4 kridlach su stredne p2 aj p3')
  end

  test('KOV-A1: direction_slots — ne-dvierka nemaju smer, chybajuci wings_n = ziadny slot') do
    %w[drawer_front lift fall blind none].each do |t|
      it = K.resolved([K.door('type' => t, 'direction' => 'unset')]).first
      assert_equal([], K::F.direction_slots(it), "#{t}: smer sa nepyta")
    end
    assert_equal([], K::F.direction_slots(nil))
    assert_equal([], K::F.direction_slots({}))
    # Velmi stary ulozeny `front_items` bez `wings_n` = legacy -> ZIADNY nalez.
    assert_equal([], K::F.direction_slots({ 'id' => 'F1', 'type' => 'door', 'direction' => 'unset' }))
  end

  test('KOV-A1: direction_slots rozhoduje EFEKTIVNY wings_n, nie surove wings (auto ~600 mm)') do
    # Hranica plati na CELNY OTVOR (sirka - 2*gap_sides), pri gap_sides 2 mm je
    # zlom na sirke korpusu 604 mm.
    { 599.0 => 1, 601.0 => 1, 603.0 => 1, 605.0 => 2, 900.0 => 2 }.each do |w, want|
      it = K.resolved([K.door('wings' => 'auto', 'direction' => 'unset')], w).first
      assert_equal(want, it['wings_n'], "sirka #{w}: efektivny pocet kridiel")
      slots = K::F.direction_slots(it)
      assert_equal('auto', it['wings'], 'surove `wings` ostava „auto"')
      if want == 1
        assert_equal(1, slots.length, "sirka #{w}: auto -> 1 kridlo -> smer sa pyta")
        assert_equal('single', slots.first[:wing])
      else
        assert_equal([], slots, "sirka #{w}: auto -> 2 kridla -> smer sa NEPYTA")
      end
    end
  end

  test('KOV-A1: direction_slots je JEDINA definicia — nikde inde sa nerozhoduje z `wings`') do
    %w[core/bom.rb core/validation.rb].each do |rel|
      s = NxKovA1.src(rel)
      refute(s.match?(/wings_n|\['wings'\]/), "#{rel} nesmie rozhodovat o smere z poctu kridiel sam")
      next unless rel == 'core/bom.rb'

      assert(s.include?('Fronts.direction_slots(item)'),
             'bom.rb pouziva direction_slots ako jediny zdroj aplikovatelnosti')
    end
  end

  # ================== 5) LEGACY a stabilita part_key ========================

  test('KOV-A1: legacy STRING fronts nikdy nevyrobi smer ani klasifikaciu') do
    %w[none 1 2 auto].each do |legacy|
      cfg = K::F.normalize_config(legacy)
      cfg['items'].each do |it|
        %w[direction wing_directions opening_mode drawer].each do |k|
          refute(it.key?(k), "legacy fronts='#{legacy}': kluc '#{k}' sa nesmie vymysliet")
        end
      end
    end
    assert_equal([], K::F.normalize_config('none')['items'])
    assert_equal(1, K::F.normalize_config('auto')['items'].length)
  end

  test('KOV-A1: part_key je stabilny a UNIKATNY pri prepinani typov') do
    keys = {}
    %w[door drawer_front lift fall blind].each do |t|
      parts = K.plan_parts([K.door('type' => t)]).select { |p| p[:part_key].to_s.start_with?('front:') }
      assert_equal(1, parts.length, "#{t}: prave jeden celny dielec")
      keys[t] = parts.first[:part_key]
    end
    assert_equal('front:F1/wing:single', keys['door'])
    assert_equal('front:F1/panel', keys['drawer_front'])
    assert_equal('front:F1/flap', keys['lift'])
    assert_equal('front:F1/flap', keys['fall'], 'vyklop a sklop zdielaju rolu, teda aj kluc')
    assert_equal('front:F1/blind', keys['blind'])
    assert(keys.values.uniq.length == 4, 'kluce sa medzi typmi (okrem lift/fall) NEPREKRYVAJU')
    keys.each_value { |k| assert(K::PK.valid?(k), "#{k} musi prejst formalnou validaciou") }
  end

  test('KOV-A1: overridy su per kind — pri prepnuti typu ostavaju DORMANT pod starym klucom') do
    ov = { 'front:F1/wing:single' => { 'material_id' => 'K009' } }
    # Prepnutie dvierok na vyklop: novy plan stary kluc NEPOZNA, ale migracia ho
    # NESMIE zahodit (inak by sa navrat na dvierka vratil bez materialu).
    parts = K.plan_parts([K.door('type' => 'lift')])
    out = K::PK.migrate_overrides(ov, parts)
    assert_equal({ 'material_id' => 'K009' }, out['front:F1/wing:single'],
                 'override dvierok prezije prepnutie na vyklop (dormant)')
    refute(out.key?('front:F1/flap'), 'override sa NEPRENASA na iny kind')
    # Navrat na dvierka override obnovi.
    back = K::PK.migrate_overrides(out, K.plan_parts([K.door]))
    assert_equal({ 'material_id' => 'K009' }, back['front:F1/wing:single'])
  end

  test('KOV-A1: human_label pozna vyklop, sklop aj blendu') do
    fronts = [{ 'id' => 'F1', 'type' => 'drawer_front', 'wings_n' => 1 },
              { 'id' => 'F2', 'type' => 'lift', 'wings_n' => 1 },
              { 'id' => 'F3', 'type' => 'fall', 'wings_n' => 1 },
              { 'id' => 'F4', 'type' => 'blind', 'wings_n' => 1 }]
    assert_equal('F2 · výklop', K::PK.human_label('front:F2/flap', fronts: fronts))
    assert_equal('F3 · sklop', K::PK.human_label('front:F3/flap', fronts: fronts))
    assert_equal('F4 · blenda', K::PK.human_label('front:F4/blind', fronts: fronts))
    # Bez zhody sa NEHADA — vrati sa neutralny tvar (a cislo ostane surove id).
    assert_equal('FX · výklop/sklop', K::PK.human_label('front:FX/flap', fronts: fronts))
    assert_equal('FX · blenda', K::PK.human_label('front:FX/blind', fronts: fronts))
    # Stare tvary sa NEMENIA.
    assert_equal('F1 · zásuvkové čelo', K::PK.human_label('front:F1/panel', fronts: fronts))
    assert_equal(1, K::PK::SCHEMA, 'nove kinds su ADITIVNE — SCHEMA sa nebumpuje')
  end

  # ===================== 6) ALLOWLISTY novych roli ==========================

  test('KOV-A1: flap/false_front prechadzaju allowlistmi builder-a') do
    %w[flap false_front].each do |role|
      assert_equal('Noxun/Čelá', K::CB::PART_TAGS[role], "#{role}: tag Cela")
      assert_equal('F', K::CB.base_material_for(role, :korpus, 'B', 'F', 'Z'),
                   "#{role}: berie CELNY material aj ked signal materialu hovori inak")
      [18.0, 18.6, 19.0].each do |th|
        assert(K::CB.thickness_ok_for?(role, 18.0, th),
               "#{role}: katalogova hrubka #{th} mm musi prejst (D-45)")
      end
      refute(K::CB.thickness_ok_for?(role, 18.0, 60.0), "#{role}: 60 mm uz nie je doskovy material")
      assert_equal([E::PartFaces::AXES_FRONT], E::PartFaces::ROLE_AXES[role], "#{role}: AXES_FRONT")
    end
  end

  test('KOV-A1: materialized_part prepise hrubku vyklopu aj blendy (19 mm)') do
    %w[flap false_front].each do |role|
      pd = { role: role, box: [500.0, 18.0, 400.0], origin: [2.0, -18.0, 102.0],
             prod: { length: 400.0, width: 500.0, thickness: 18.0 } }
      out = K::CB.materialized_part(pd, { sheet_thickness: 19.0 })
      assert_equal(19.0, out[:box][1], "#{role}: hrubka boxu")
      assert_equal(-19.0, out[:origin][1], "#{role}: celo sa posunie pred korpus o novu hrubku")
      assert_equal(19.0, out[:prod][:thickness], "#{role}: vyrobny udaj")
      assert_equal(18.0, pd[:box][1], "#{role}: vstup sa NEMUTUJE")
    end
  end

  test('KOV-A1: ABS — labely, strany a seed pravidla novych roli') do
    ar = E::AbsRules
    %w[flap false_front].each do |role|
      assert_equal({ 'L1' => 'Ľavá', 'L2' => 'Pravá', 'W1' => 'Dolná', 'W2' => 'Horná' },
                   ar.edge_labels(role), "#{role}: labely ako celo")
      assert_equal(ar::EDGE_SIDES_FRONT, ar.edge_sides(role), "#{role}: strany 2D karty ako celo")
      assert_equal({ 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, ar::SEED_RULES[role],
                   "#{role}: olepenie dookola ako dvierka")
    end
    assert_equal(3, ar::SEED_VERSION, 'bump na 3 doplni nove roly aj v EXISTUJUCOM subore')
  end

  test('KOV-A1: seed-merge v2 -> v3 doplni LEN chybajuce roly (pouzivatelske hodnoty nedotknute)') do
    ar = E::AbsRules
    # Subor „ako ho ma dnesny pouzivatel": vsetky v2 roly, dvierka RUCNE zmenene.
    v2 = ar.deep_copy(ar::SEED_RULES)
    v2.delete('flap')
    v2.delete('false_front')
    v2['front_door'] = { 'L1' => 2.0 }        # vedoma uzivatelska zmena
    v2['rail_front'] = { 'L1' => 1.0 }        # uz po D-30 migracii
    out, stale = ar.merge_seed_roles(v2, 2, v2)
    assert(stale, 'merge si vynuti zapis (bump verzie v subore)')
    assert_equal({ 'L1' => 2.0 }, out['front_door'], 'RUCNA hodnota ostava NEDOTKNUTA')
    assert_equal({ 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, out['flap'])
    assert_equal({ 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, out['false_front'])
    assert_equal({ 'L1' => 1.0 }, out['rail_front'], 'rail migracia sa NEOPAKUJE')

    # Subor UZ na v3 sa nemerguje vobec.
    v3 = ar.deep_copy(ar::SEED_RULES)
    v3['flap'] = {}
    same, stale3 = ar.merge_seed_roles(v3, 3, v3)
    refute(stale3, 'v3 subor sa uz nemerguje')
    assert_equal({}, same['flap'], 'pouzivatelom vyprazdnena rola ostava prazdna')

    # v1 subor: rail migracia PLATI (file_version < 2) a nove roly pribudnu tiez.
    v1 = ar.deep_copy(ar::SEED_RULES)
    %w[flap false_front].each { |r| v1.delete(r) }
    v1['rail_front'] = {}
    v1['rail_back'] = {}
    out1, = ar.merge_seed_roles(v1, 1, v1)
    assert_equal({ 'L1' => 1.0 }, out1['rail_front'], 'jednorazova rail migracia z v1 ostava zachovana')
    assert_equal({ 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, out1['false_front'])
  end

  test('KOV-A1: cista instalacia ABS pravidiel seedne aj flap/false_front') do
    skip! 'katalogove testy bezia len headless (APPDATA sandbox)' unless NxTest.headless?
    ar = E::AbsRules
    nx_reset_catalog_file(ar.path)
    rules = ar.load
    %w[flap false_front].each do |role|
      assert_equal({ 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 }, rules[role],
                   "#{role}: cerstvy subor musi rolu obsahovat")
    end
    assert_equal(E::AbsRules::SEED_VERSION, JSON.parse(File.binread(ar.path))['seed_version'])
  end

  test('KOV-A1: vystupne allowlisty — FRONT_ROLES, ROLE_LABELS, ABS_ROLE_ORDER, part_card.js') do
    %w[flap false_front].each do |role|
      assert(E::Validation::FRONT_ROLES.include?(role), "Validation::FRONT_ROLES chyba #{role}")
    end
    # Rola `flap` je SPOLOCNA pre vyklop aj sklop -> nazov musi byt NEUTRALNY
    # (Codex #280 P2-B). Konkretny text vie povedat len TYP cela.
    assert_equal('Výklop/sklop', E::ProductionCore.role_label('flap'))
    assert_equal('Blenda', E::ProductionCore.role_label('false_front'))
    refute(E::ProductionCore.role_label('flap') == 'Výklop',
           'nazov roly nesmie tvrdit „výklop" — pri sklope by klamal')
    rd = NxKovA1.src('ui/rules_dialog.rb')
    assert(rd.match?(/drawer_front\s*\n?\s*flap false_front/) || rd.include?('flap false_front'),
           'ABS_ROLE_ORDER musi niest flap aj false_front (hned za drawer_front)')
    pc = NxKovA1.src('ui/js/part_card.js')
    assert(pc.include?("pc.role === 'flap'") && pc.include?("pc.role === 'false_front'"),
           'part_card.js: isFront musi poznat nove roly (inak by 19 mm material bol disabled)')
    assert(pc.include?("flap:'Výklop/sklop'") && pc.include?("false_front:'Blenda'"),
           'part_card.js: nazvy roli (flap NEUTRALNE — spolocna rola vyklopu aj sklopu)')
  end

  # ========================= 7) CONFIG_SCHEMA ===============================

  test('KOV-A1: CONFIG_SCHEMA >= 2 a marker sa zapisuje do ulozeneho configu') do
    assert(K::CB::CONFIG_SCHEMA >= 2, 'novy typ cela a nove polia = bump kontraktu (R-12)')
    stored = JSON.parse(JSON.generate(K::CB.cabinet_config(K::CB.normalize(K.base))))
    assert_equal(K::CB::CONFIG_SCHEMA, stored['config_schema'])
    assert(K::CB.newer_config?({ 'config_schema' => K::CB::CONFIG_SCHEMA + 1 }))
    refute(K::CB.newer_config?({ 'config_schema' => K::CB::CONFIG_SCHEMA }))
    refute(K::CB.newer_config?({}), 'legacy config bez markera nikdy neblokuje')
  end

  # ============================ 8) GUARDY ===================================

  test('KOV-A1 GUARD: nikde v Ruby ani JS neexistuje DEFAULT smeru') do
    # (a) fallback `direction || '...'` / `direction ?? '...'`.
    # Lookbehind vynima `grain_direction` (SMER DEKORU, D-108) — to je ina
    # velicina s legitimnym defaultom 'none'; O1 sa tyka smeru OTVARANIA.
    fallback = /(?<![A-Za-z0-9_])direction\s*(\|\||\?\?)\s*['"]/
    # (b) natvrdo zapisana strana ako hodnota kluca `direction`
    hard_rb = /['"]direction['"]\s*=>\s*['"](left|right)['"]/
    hard_js = /direction:\s*['"](left|right)['"]/
    files = Dir[File.join(NxKovA1::SRC_DIR, '**', '*.rb')] +
            Dir[File.join(NxKovA1::SRC_DIR, 'ui', 'js', '*.js')]
    assert(files.length > 40, 'guard musi realne nieco prehladat')
    bad = []
    files.each do |p|
      s = File.read(p, encoding: 'UTF-8')
      rel = p.sub("#{NxKovA1::SRC_DIR}/", '')
      bad << "#{rel}: fallback smeru" if s.match?(fallback)
      bad << "#{rel}: natvrdo zapisana strana" if s.match?(hard_rb) || s.match?(hard_js)
    end
    assert_equal([], bad, "ZIADNY default ani heuristika smeru (O1): #{bad.join('; ')}")
  end

  test('KOV-A1 GUARD: literal `unset` zije LEN na allowlistovanych miestach') do
    # `unset` smie vzniknut VYHRADNE v normalizacii (fail-visible z poskodenej
    # hodnoty) a citat sa smie VYHRADNE v zbere nalezov. Kazde dalsie miesto by
    # bolo druha pravda o tom, co „neurceny" znamena.
    #   modules/fronts.rb — DIRECTIONS + norm_direction (jediny vyrobca)
    #   core/bom.rb       — porovnanie stavu slotu (jediny citatel)
    # POZN.: kod `front_direction_unset` NIE JE literal `unset` (iny token),
    # takze validation.rb ani JS na allowliste byt nemusia.
    allow = %w[modules/fronts.rb core/bom.rb]
    literal = /['"]unset['"]/
    files = Dir[File.join(NxKovA1::SRC_DIR, '**', '*.rb')] +
            Dir[File.join(NxKovA1::SRC_DIR, 'ui', 'js', '*.js')]
    found = files.filter_map do |p|
      rel = p.sub("#{NxKovA1::SRC_DIR}/", '')
      rel if File.read(p, encoding: 'UTF-8').match?(literal)
    end.sort
    assert_equal(allow.sort, found, 'literal `unset` mimo allowlistu')
  end

  test('KOV-A1 GUARD: nahlad popisuje kazdy typ vlastnym slovom (P2-C)') do
    js = NxKovA1.src('ui/js/preview.js')
    assert(js.include?('var PV_FRONT_TYPE_DESC = {'), 'popisy typov ziju na JEDNOM mieste')
    %w[lift fall blind].each do |t|
      assert(js.match?(/PV_FRONT_TYPE_DESC = \{[^}]*#{t}:/m), "mapa pozna typ #{t}")
    end
    assert(js.include?("+frontTypeDesc(it.type)+"),
           'popis v texte ide cez mapu, nie cez natvrdo zapisanu vetvu')
    refute(js.include?("(it.type==='drawer_front'?'zásuvka':'dvierka')"),
           'stary dvojstavovy fallback (vsetko ostatne = „dvierka") uz neexistuje')
  end

  test('KOV-A1 GUARD: form.js pass-through BEZ defaultu + tri NEAKTIVNE volby typu') do
    s = NxKovA1.src('ui/js/form.js')
    assert(s.include?("var FRONT_EXTRA_KEYS = ['direction', 'wing_directions', 'opening_mode', 'drawer']"),
           'form.js musi drzat zoznam prenasanych poli na JEDNOM mieste')
    assert(s.include?('frontExtraStore(row, item)'), 'addFrontRow uklada polia do datasetu')
    assert(s.include?('frontExtraApply(item, r)'), 'collectFronts ich vracia spat')
    # Telo oboch funkcii NESMIE obsahovat ziadny `|| '...'` default.
    body = s[/function frontExtraStore.*?^  \}\n  function frontExtraApply.*?^  \}/m]
    assert(body, 'telo pass-through funkcii sa nenaslo')
    refute(body.match?(/\|\|\s*['"]/), 'pass-through nesmie doplnat ZIADNY default')
    # Tri neaktivne volby typu (nahradili `flap (faza 3)`).
    %w[lift fall blind].each do |t|
      assert(s.include?("<option value=\"#{t}\" disabled>"),
             "select typu musi niest NEAKTIVNU volbu #{t} (inak by config z API prepol typ na door)")
    end
    refute(s.include?('value="flap"'), 'stara volba `flap (faza 3)` uz neexistuje')
    assert(s.include?("lift: 'Výklop'") && s.include?("fall: 'Sklop'") && s.include?("blind: 'Blenda'"),
           'FRONT_TYPE_LABEL pozna nove typy')
  end
end
