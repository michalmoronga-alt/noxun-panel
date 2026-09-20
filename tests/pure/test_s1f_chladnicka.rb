# frozen_string_literal: true
# S1-F — TELO CHLADNICKY (kontrolna geometria niky) + KONTROLA NIKY A DELENIA CIEL.
#
# CO BOLO ZLE: skrinka s priradenou chladnickou v modeli nic neukazala a nikto
# nepovedal, ci sa nika zmesti ani kde ma byt hrana medzi celami. Michal to
# kreslil rucne a delenie odhadoval.
#
# CO PLATI TERAZ:
#   * BOX NIKY vznika VYHRADNE z vazby (`appliance_refs[]`) kategorie chladnicka
#     a LEN ked su vsetky tri minima kladne (Astra FIX F3) — skrinka, ktora
#     chladnicku iba ocakava, box NEMA; neuplny katalogovy zaznam prestavbu
#     NEZHODI, len sa nekresli,
#   * box stoji na HORNEJ PLOCHE DNA, je centrovany a licuje s celnou rovinou;
#     NIKDY sa nedeformuje — ked nesedi, TRCI a Kontrola to povie,
#   * VERDIKT (nika per os + delenie ciel) ma JEDEN modul `ApplianceChecks`,
#     z ktoreho ziju Kontrola AJ riadok Spotrebic (FIX F4) — dve pravdy sa
#     nepripustaju,
#   * HRANA DELENIA je VRCH DOLNEHO CELA meraný od dna niky (FIX F1)
#     a musi lezat v `[D + 10, D + G − s − 10]`; `furniture_doors` z vykresu
#     vyrobcu ma prednost a prevadza sa cez SPODNU hranu dolneho cela (FIX F2),
#   * Kontrola vyraba nalez LEN pre `clash` a `unsatisfiable` (FIX F7 + F9) —
#     ziadna nova zavaznost, informacne stavy ziju v riadku Spotrebic.
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'appliance_catalog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog')
end

module NxS1F
  module_function

  CN  = Noxun::Engine::Construction
  CB  = Noxun::Engine::CabinetBuilder
  BP  = Noxun::Engine::BuildPlan
  AC  = Noxun::Engine::ApplianceChecks
  BOM = Noxun::Engine::Bom
  VAL = Noxun::Engine::Validation
  PANEL = Noxun::Engine::Panel

  # --- fixtury ---------------------------------------------------------------

  # Chladnickova skrinka 600 x 2076 x 580 -> vnutro 564 x 1940 x 575
  # (nika Beko 560 / 1940–1950 / 555 sa do nej zmesti presne).
  def cab(extra = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 2076.0, 'depth' => 580.0,
      'thickness' => 18.0, 'floor_height' => 100.0, 'bottom_mode' => 'between_sides',
      'top_mode' => 'full', 'back_mode' => 'inset', 'back_thickness' => 5.0,
      'zones' => [] }.merge(extra)
  end

  # TA ISTA skrinka o 16 mm nizsia a s hrubsim chrbtom -> vnutro 564 x 1924 x 562:
  # vyska nesedi (1924 < 1940), sirka a hlbka ano.
  def low_cab(extra = {})
    cab({ 'height' => 2060.0, 'back_thickness' => 18.0 }.merge(extra))
  end

  # Zaznam vazby tak, ako ho pise `ApplianceBinding.ref_record`.
  def ref(item_id = 'I-1', extra = {})
    { 'item_id' => item_id, 'category' => 'fridge',
      'body' => { 'width' => 540.0, 'height' => 1935.0, 'depth' => 545.0 },
      'niche' => { 'width_min' => 560.0, 'height_min' => 1940.0, 'height_max' => 1950.0,
                   'depth_min' => 555.0 },
      'bands' => { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                   'door_gap' => 71.0, 'door_upper' => 1159.0 },
      'snapshot_at' => '2026-09-21T08:00:00Z' }.merge(extra)
  end

  # Snapshot polozky zakazky (ten isty list, ktory dal `ref`).
  def snapshot(niche = nil, front = nil)
    { 'catalog_id' => 'CAT-BEKO', 'category' => 'fridge', 'manufacturer' => 'Beko',
      'name' => 'BCNA306E5ZSN',
      'dims' => {
        'body' => { 'width' => 540.0, 'height' => 1935.0, 'depth' => 545.0 },
        'niche' => niche || { 'width_min' => 560.0, 'height_min' => 1940.0,
                              'height_max' => 1950.0, 'depth_min' => 555.0 },
        'front' => front || { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                              'door_gap' => 71.0, 'door_upper' => 1159.0 }
      },
      'catalog_std' => 1, 'snapshot_at' => '2026-09-21T08:00:00Z' }
  end

  def item(id = 'I-1', typ = 'fridge', owner_id = 'CAB-3', snap = nil)
    { 'id' => id, 'typ' => typ, 'nazov' => 'Beko', 'customer_supplied' => false,
      'owner' => { 'kind' => 'cabinet', 'id' => owner_id },
      'snapshot' => snap || snapshot }
  end

  # DVE dvierka nad sebou; `lower` je vyska DOLNEHO cela (mm).
  def fronts(lower, gap = nil)
    f = { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => lower },
                      { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto' }] }
    f['gap'] = gap if gap
    f
  end

  # ZAZNAM ZBERU cez REALNU projekciu (`Bom.note_appliance_owner` +
  # `Bom.appliance_records`) — ziadny rucne poskladany hash.
  def record(cfg, it = nil, owner_id = 'CAB-3', pid = 303)
    owners = {}
    BOM.note_appliance_owner(owners, owner_id, pid, cfg)
    items = it.nil? ? [item] : Array(it)
    BOM.appliance_records(items, owners).find { |r| !r['item_id'].to_s.empty? }
  end

  # Zaznam pre skrinku s vazbou na chladnicku (najbeznejsi pripad).
  def bound(cfg_extra = {}, item_extra = nil)
    cfg = cab(cfg_extra.is_a?(Hash) ? { 'appliance_refs' => [ref] }.merge(cfg_extra) : cfg_extra)
    record(cfg, item_extra)
  end

  def plan_refs(cfg)
    CN.build_plan(CB.normalize(cfg), 'CAB-3')[:references]
  end

  # Nalezy kategorie `appliance` cez REALNU cestu Kontroly.
  def findings(rec)
    items = []
    VAL.check_appliances([rec], items)
    items
  end

  def codes(items)
    items.map { |i| i['stable_key'].to_s.split('|')[2..].join('|') }
  end
end

# =========================== 1) PLAN: BOX NIKY ==============================

NxTest.test('S1-F: vazba na chladnicku da PRESNE JEDEN deskriptor niky (box, poloha, identita)') do
  refs = NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [NxS1F.ref]))
  NxTest.assert_equal(1, refs.length, "presne jeden box: #{refs.inspect}")
  rd = refs.first
  NxTest.assert_equal('appliance_niche', rd[:role])
  NxTest.assert_equal('ref:appliance_niche:I-1', rd[:ref_key], 'identita je per POLOZKA')
  NxTest.assert_equal('I-1', rd[:item_id])
  NxTest.assert_equal('catalog', rd[:source], 'box je vzdy z listu, nikdy genericky')
  NxTest.assert_equal(false, rd[:manufactured], 'referencia sa NEVYRABA')
  NxTest.assert_equal('reference', rd[:production_class])
  # Box = MINIMA niky [sirka, hlbka, vyska]; NIE telo (540 x 545 x 1935).
  NxTest.assert_equal([560.0, 555.0, 1940.0], rd[:box].map(&:to_f))
  # Stoji na hornej ploche dna (sokel 100 + dno 18), centrovany ((600-560)/2)
  # a lici s celnou rovinou (y = 0).
  NxTest.assert_equal([20.0, 0.0, 118.0], rd[:origin].map(&:to_f))
  NxTest.assert_equal(40.0, rd[:bands]['door_bottom_offset'], 'pasma dveri idu do deskriptora')
end

NxTest.test('S1-F: skrinka BEZ vazby (len „očakáva") box NEMA') do
  NxTest.assert_equal([], NxS1F.plan_refs(NxS1F.cab('appliance_expects' => ['fridge'])))
  NxTest.assert_equal([], NxS1F.plan_refs(NxS1F.cab))
end

NxTest.test('S1-F (F3): box vznikne LEN pri TROCH kladnych minimach — a NIKDY nevybuchne') do
  # Chybajuca `depth_min`: box sa nekresli, ale prestavba prejde a kontrola
  # bezi dalej na zvysnych osiach.
  partial = NxS1F.ref('I-1', 'niche' => { 'width_min' => 560.0, 'height_min' => 1940.0 })
  refs = NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [partial]))
  NxTest.assert_equal([], refs, 'bez hlbky ziadny box — a ziadna vynimka')
  # Nula ani zaporne cislo nie su rozmer.
  %w[width_min depth_min height_min].each do |field|
    bad = NxS1F.ref('I-1', 'niche' => NxS1F.ref['niche'].merge(field => 0.0))
    NxTest.assert_equal([], NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [bad])),
                        "#{field} = 0 nie je rozmer")
  end
end

NxTest.test('S1-F: box sa NIKDY nedeformuje — v nizkej skrinke TRCI') do
  rd = NxS1F.plan_refs(NxS1F.low_cab('appliance_refs' => [NxS1F.ref])).first
  NxTest.assert_equal(1940.0, rd[:box][2].to_f, 'vyska boxu ostava vyskou niky')
  # Vnutro nizkej skrinky je 1924 — box z neho vytrca o 16 mm.
  NxTest.assert_close(118.0, rd[:origin][2].to_f)
end

NxTest.test('S1-F: DVE chladnicky v jednej skrinke = DVA boxy s vlastnou identitou') do
  cfg = NxS1F.cab('appliance_refs' => [NxS1F.ref('I-1'), NxS1F.ref('I-2')])
  refs = NxS1F.plan_refs(cfg)
  NxTest.assert_equal(2, refs.length)
  NxTest.assert_equal(%w[I-1 I-2], refs.map { |r| r[:item_id] })
  NxTest.assert_equal(%w[ref:appliance_niche:I-1 ref:appliance_niche:I-2],
                      refs.map { |r| r[:ref_key] })
  # Mena definicii aj identity dielcov v modeli sa musia lisit (FIX F5).
  names = refs.map { |r| NxS1F::CB.reference_def_name('CAB-3', r) }
  NxTest.assert_equal(names.uniq.length, 2, "dve mena definicii: #{names.inspect}")
  ids = refs.map { |r| NxS1F::CB.reference_id('CAB-3', r) }
  NxTest.assert_equal(%w[CAB-3-REF-NICHE-I1 CAB-3-REF-NICHE-I2], ids)
end

NxTest.test('S1-F: telo slotu si svoje MENO aj IDENTITU drzi (S1-E sa nemeni)') do
  body = { role: 'appliance_body', item_id: nil }
  NxTest.assert_equal('NOXUN CAB-7 APPLIANCE', NxS1F::CB.reference_def_name('CAB-7', body))
  NxTest.assert_equal('CAB-7-REF-APPL', NxS1F::CB.reference_id('CAB-7', body))
end

NxTest.test('S1-F: `BuildPlan.validate!` pozna OBE roly referencie') do
  NxTest.assert_equal(%w[appliance_body appliance_niche], NxS1F::BP::REFERENCE_ROLES)
  rd = NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [NxS1F.ref])).first
  NxTest.assert_equal([rd], NxS1F::BP.validate_references!([rd]), 'nova rola prejde validatorom')
  NxTest.assert_raise(/neznamu rolu|neznámu rolu|rolu/) do
    NxS1F::BP.validate_references!([rd.merge(role: 'appliance_fridge')])
  end
end

NxTest.test('S1-F: pasma dveri su hrany ZDOLA — horna hrana sa nekresli') do
  levels = NxS1F::CB.niche_band_levels('door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                                       'door_gap' => 71.0, 'door_upper' => 1159.0)
  NxTest.assert_equal([40.0, 669.0, 740.0], levels, '40 · 40+629 · +71')
  NxTest.assert_equal([], NxS1F::CB.niche_band_levels({}), 'bez udajov ziadne pasma')
end

# =========================== 2) VERDIKT NIKY ================================

NxTest.test('S1-F: nika SEDI — vsetky tri osi OK') do
  v = NxS1F::AC.niche_verdict(NxS1F.bound)
  NxTest.assert_equal('ok', v['state'])
  NxTest.assert_equal({ 'width' => 'ok', 'height' => 'ok', 'depth' => 'ok' }, v['axes'])
  NxTest.assert(v['text'].include?('nika ✓'), v['text'])
end

NxTest.test('S1-F: vnutro 564 x 1924 x 562 -> VYSKA nesedi, sirka a hlbka ano') do
  rec = NxS1F.record(NxS1F.low_cab('appliance_refs' => [NxS1F.ref]))
  NxTest.assert_equal({ 'width' => 564.0, 'height' => 1924.0, 'depth' => 562.0 },
                      rec['interior'], 'zber nesie vnutro')
  v = NxS1F::AC.niche_verdict(rec)
  NxTest.assert_equal('clash', v['state'])
  NxTest.assert_equal('clash', v['axes']['height'])
  NxTest.assert_equal('ok', v['axes']['width'])
  NxTest.assert_equal('ok', v['axes']['depth'])
  NxTest.assert(v['text'].include?('nezmestí sa'), v['text'])
  NxTest.assert(v['text'].include?('1924') && v['text'].include?('1940'), v['text'])
end

NxTest.test('S1-F: JEDNOSTRANNE minimum (list max nedava) prejde aj pri 2000') do
  snap = NxS1F.snapshot('width_min' => 560.0, 'height_min' => 1940.0, 'depth_min' => 555.0)
  cfg = NxS1F.cab('height' => 2136.0, 'appliance_refs' => [NxS1F.ref])
  rec = NxS1F.record(cfg, [NxS1F.item('I-1', 'fridge', 'CAB-3', snap)])
  NxTest.assert_equal(2000.0, rec['interior']['height'])
  v = NxS1F::AC.niche_verdict(rec)
  NxTest.assert_equal('ok', v['state'], "bez max je 2000 v poriadku: #{v['text']}")
  # S maximom 1950 to uz je clash.
  rec2 = NxS1F.record(cfg, [NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot)])
  NxTest.assert_equal('clash', NxS1F::AC.niche_verdict(rec2)['axes']['height'])
end

NxTest.test('S1-F: VIAC ZON -> vyska sa preskoci, sirka a hlbka sa kontroluju dalej') do
  split = { 'id' => 'Z1', 'split' => { 'axis' => 'h', 'count' => 2, 'cuts' => [{}, {}] },
            'children' => [{ 'id' => 'Z1.1' }, { 'id' => 'Z1.2' }] }
  cfg = NxS1F.low_cab('appliance_refs' => [NxS1F.ref], 'zone_tree' => split,
                      'zones' => [{ 'id' => 'Z1.1' }, { 'id' => 'Z1.2' }])
  rec = NxS1F.record(cfg)
  NxTest.assert_equal(false, rec['single_zone'], 'zber vie, ze skrinka ma viac zon')
  v = NxS1F::AC.niche_verdict(rec)
  NxTest.assert_equal('skip', v['axes']['height'])
  NxTest.assert_equal('ok', v['axes']['width'])
  NxTest.assert_equal('ok', v['axes']['depth'])
  NxTest.assert_equal('skip', v['state'], 'skip je informacia, nie chyba')
  NxTest.assert(v['text'].include?('viac zón'), v['text'])
  NxTest.assert_equal([], NxS1F.findings(rec), 'preskocena os NIKDY nerobi nalez')
end

NxTest.test('S1-F: RURA a MIKROVLNKA maju SIRKU a HLBKU, vysku nie') do
  NxTest.assert_equal(%w[width depth], NxS1F::AC::AXES['oven'])
  NxTest.assert_equal(%w[width depth], NxS1F::AC::AXES['microwave'])
  oven = { 'category' => 'oven', 'name' => 'Rúra', 'owner' => { 'kind' => 'cabinet' },
           'snapshot' => { 'niche' => { 'width_min' => 560.0, 'width_max' => 568.0,
                                        'height_min' => 583.0, 'depth_min' => 560.0 } },
           'interior' => { 'width' => 564.0, 'height' => 1924.0, 'depth' => 562.0 },
           'single_zone' => true }
  v = NxS1F::AC.niche_verdict(oven)
  NxTest.assert_equal(%w[width depth], v['axes'].keys, 'vyska sa rury netyka')
  NxTest.assert_equal('ok', v['state'])
end

NxTest.test('S1-F (F3): „chýbajú údaje niky" plati, az ked NIKTORA os nema hodnotu') do
  NxTest.assert(NxS1F::AC.specs_missing?(nil))
  NxTest.assert(NxS1F::AC.specs_missing?({}))
  NxTest.refute(NxS1F::AC.specs_missing?('depth_min' => 555.0), 'jedna os staci')
  bez = NxS1F.record(NxS1F.cab('appliance_refs' => [NxS1F.ref]),
                     [NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot({}))])
  NxTest.assert_equal(%w[appliance_specs_missing], NxS1F.codes(NxS1F.findings(bez)))
  ciast = NxS1F.record(NxS1F.cab('appliance_refs' => [NxS1F.ref]),
                       [NxS1F.item('I-1', 'fridge', 'CAB-3',
                                   NxS1F.snapshot('width_min' => 560.0, 'height_min' => 1940.0))])
  NxTest.refute(NxS1F.codes(NxS1F.findings(ciast)).include?('appliance_specs_missing'),
                'neuplny zaznam sa kontroluje na osiach, ktore ma')
  v = NxS1F::AC.niche_verdict(ciast)
  NxTest.assert_equal('unknown', v['axes']['depth'], 'hlbka bez cisla = „nevieme"')
  NxTest.assert_equal('ok', v['axes']['width'])
end

NxTest.test('S1-F: doska ani kategoria bez kontroly niku neriesia') do
  rec = NxS1F.bound.merge('owner' => { 'kind' => 'board' })
  NxTest.assert_equal('na', NxS1F::AC.niche_verdict(rec)['state'])
  hob = NxS1F.bound.merge('category' => 'hob')
  NxTest.assert_equal('na', NxS1F::AC.niche_verdict(hob)['state'])
end

# ======================= 3) VERDIKT DELENIA CIEL ============================

NxTest.test('S1-F (F1): hrana = VRCH DOLNEHO CELA od dna niky; pasmo praxe 679–727') do
  # Dolne celo 682 -> vrch v modeli 102 + 682 = 784; dno niky 118 -> hrana 666.
  rec = NxS1F.bound('fronts' => NxS1F.fronts(682.0))
  s = NxS1F::AC.door_split_verdict(rec)
  NxTest.assert_equal([679.0, 727.0], s['range'], 'D=669, G=71, s=3')
  NxTest.assert_equal(703.0, s['recommended'], 'stred pasma je odporucanie')
  NxTest.assert_equal(666.0, s['edge'])
  NxTest.assert_equal('clash', s['state'], '666 je pod pasmom')
  NxTest.assert_equal('practice', s['source'])
end

NxTest.test('S1-F (F1): OBA konce pasma su platne, o 1 mm vedla uz nie') do
  # edge = lower_z1 - z_lo = (102 + h) - 118 = h - 16
  { 679.0 => 'ok', 678.0 => 'clash', 727.0 => 'ok', 728.0 => 'clash' }.each do |edge, want|
    rec = NxS1F.bound('fronts' => NxS1F.fronts(edge + 16.0))
    s = NxS1F::AC.door_split_verdict(rec)
    NxTest.assert_close(edge, s['edge'], 0.01)
    NxTest.assert_equal(want, s['state'], "hrana #{edge} ma byt #{want}")
  end
end

NxTest.test('S1-F: SKARA ciel meni horny koniec pasma (3 -> 727, 2 -> 728)') do
  rec3 = NxS1F.bound('fronts' => NxS1F.fronts(700.0))
  NxTest.assert_equal(3.0, rec3['gap'], 'predvolena skara je Fronts::GAP_DEFAULT')
  NxTest.assert_equal([679.0, 727.0], NxS1F::AC.door_split_verdict(rec3)['range'])
  rec2 = NxS1F.bound('fronts' => NxS1F.fronts(700.0, 2.0))
  NxTest.assert_equal(2.0, rec2['gap'])
  NxTest.assert_equal([679.0, 728.0], NxS1F::AC.door_split_verdict(rec2)['range'])
end

NxTest.test('S1-F (M3): SOKEL a DNO sa od hrany ODPOCITAVAJU (800 v modeli = 682 v nike)') do
  rec = NxS1F.bound('fronts' => NxS1F.fronts(698.0))
  pair = rec['fronts_pair']
  NxTest.assert_close(800.0, pair['lower_z1'], 0.01, 'vrch dolneho cela v modeli')
  NxTest.assert_close(118.0, rec['z_lo'], 0.01, 'dno niky = sokel 100 + dno 18')
  s = NxS1F::AC.door_split_verdict(rec)
  NxTest.assert_close(682.0, s['edge'], 0.01, 'bez odpocitania z_lo by tu bolo 800')
  NxTest.assert_equal('ok', s['state'])
end

NxTest.test('S1-F (F2): `furniture_doors` z vykresu ma PREDNOST a prevadza sa cez SPODNU hranu') do
  fd = { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0, 'door_gap' => 71.0,
         'door_upper' => 1159.0,
         'furniture_doors' => { 'lower_min' => 700.0, 'lower_max' => 720.0, 'gap_ref' => 2.0 } }
  it = NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot(nil, fd))
  rec = NxS1F.record(NxS1F.cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(710.0)), [it])
  s = NxS1F::AC.door_split_verdict(rec)
  NxTest.assert_equal('drawing', s['source'])
  # lower_z0 = 102 (sokel 100 + okraj 2), z_lo = 118 -> posun -16.
  NxTest.assert_equal([684.0, 704.0], s['range'], 'vyska dielca 700–720 -> 684–704 v nike')
  NxTest.assert_close(694.0, s['edge'], 0.01)
  NxTest.assert_equal('ok', s['state'])
  NxTest.assert(s['note'].to_s.include?('škárou 2'), "gap_ref sa prizna: #{s['note'].inspect}")
end

NxTest.test('S1-F (F2): CIASTOCNY blok vykresu = jednostranny rozsah, PRAZDNY = vzorec praxe') do
  only_min = { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0, 'door_gap' => 71.0,
               'furniture_doors' => { 'lower_min' => 700.0 } }
  it = NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot(nil, only_min))
  rec = NxS1F.record(NxS1F.cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(710.0)), [it])
  s = NxS1F::AC.door_split_verdict(rec)
  NxTest.assert_equal([684.0, nil], s['range'], 'len dolny koniec')
  NxTest.assert(s['recommended'].nil?, 'jednostranny rozsah stred nema')
  NxTest.assert_equal('ok', s['state'])

  prazdny = { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0, 'door_gap' => 71.0,
              'furniture_doors' => {} }
  it2 = NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot(nil, prazdny))
  rec2 = NxS1F.record(NxS1F.cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(710.0)), [it2])
  NxTest.assert_equal('practice', NxS1F::AC.door_split_verdict(rec2)['source'])
end

NxTest.test('S1-F (F6): delenie sa tyka LEN dvoch dvierok nad sebou') do
  cases = {
    'jedno čelo' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto' }] },
    'tri čelá' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto' },
                                { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto' },
                                { 'id' => 'F3', 'type' => 'door', 'mode' => 'auto' }] },
    'zásuvka' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'auto' },
                               { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto' }] },
    'výklop' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto' },
                              { 'id' => 'F2', 'type' => 'lift', 'mode' => 'auto' }] },
    'blenda' => { 'items' => [{ 'id' => 'F1', 'type' => 'blind', 'mode' => 'auto' },
                              { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto' }] },
    'bez čela' => { 'items' => [{ 'id' => 'F1', 'type' => 'none', 'mode' => 'auto' },
                                { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto' }] }
  }
  cases.each do |label, fr|
    rec = NxS1F.bound('fronts' => fr)
    s = NxS1F::AC.door_split_verdict(rec)
    NxTest.assert_equal('na', s['state'], "#{label} delenie nema")
    NxTest.assert(s['reason'].to_s.start_with?('delenie sa netýka'), "#{label}: #{s['reason']}")
    NxTest.assert_equal([], NxS1F.findings(rec), "#{label} NIKDY nerobi nalez")
  end
  NxTest.assert_equal('clash',
                      NxS1F::AC.door_split_verdict(NxS1F.bound('fronts' => NxS1F.fronts(682.0)))['state'],
                      'dve dvierka delenie MAJU')
end

NxTest.test('S1-F (F8): PRAZDNY interval (G < s + 20) je `unsatisfiable`, rovnost je platny bod') do
  uzky = NxS1F.ref('I-1', 'bands' => { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                                       'door_gap' => 20.0, 'door_upper' => 1200.0 })
  snap = NxS1F.snapshot(nil, 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                             'door_gap' => 20.0, 'door_upper' => 1200.0)
  cfg = NxS1F.cab('appliance_refs' => [uzky], 'fronts' => NxS1F.fronts(700.0))
  rec = NxS1F.record(cfg, [NxS1F.item('I-1', 'fridge', 'CAB-3', snap)])
  s = NxS1F::AC.door_split_verdict(rec)
  NxTest.assert_equal('unsatisfiable', s['state'])
  NxTest.assert(s['range'].nil?, 'ziadne pasmo')
  NxTest.assert(s['recommended'].nil?, 'ziadny odporucany stred')
  NxTest.assert(s['text'].include?('20'), s['text'])
  NxTest.assert_equal(%w[appliance_door_split], NxS1F.codes(NxS1F.findings(rec)),
                      'nemozny interval je ORANGE — pouzivatel o nom musi vediet')

  # G = s + 20 -> lo == hi (jediny platny bod).
  rovny = NxS1F.snapshot(nil, 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                              'door_gap' => 23.0, 'door_upper' => 1200.0)
  cfg2 = NxS1F.cab('appliance_refs' => [uzky], 'fronts' => NxS1F.fronts(695.0))
  rec2 = NxS1F.record(cfg2, [NxS1F.item('I-1', 'fridge', 'CAB-3', rovny)])
  s2 = NxS1F::AC.door_split_verdict(rec2)
  NxTest.assert_equal([679.0, 679.0], s2['range'])
  NxTest.assert_equal('ok', s2['state'], 'hrana 679 presne v jedinom bode')
end

NxTest.test('S1-F: bez pasiem dveri sa delenie NEODPORUCA (a nerobi nalez)') do
  it = NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot(nil, {}))
  rec = NxS1F.record(NxS1F.cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(700.0)), [it])
  s = NxS1F::AC.door_split_verdict(rec)
  NxTest.assert_equal('unknown', s['state'])
  NxTest.assert_equal([], NxS1F.findings(rec))
end

# ========================= 4) KONTROLA (Validation) =========================

NxTest.test('S1-F (F7): nalez je LEN pre `clash` — a per OS, s vlastnym `stable_key`') do
  cfg = NxS1F.low_cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(682.0))
  rec = NxS1F.record(cfg)
  items = NxS1F.findings(rec)
  NxTest.assert_equal(%w[appliance_door_split appliance_niche_clash|height].sort,
                      NxS1F.codes(items).sort, "nalezy: #{NxS1F.codes(items).inspect}")
  NxTest.assert(items.all? { |i| i['severity'] == NxS1F::VAL::ORANGE }, 'nikdy RED')
  NxTest.assert(items.all? { |i| i['category'] == NxS1F::VAL::CAT_APPLIANCE })
  NxTest.assert(items.all? { |i| i['owner_id'] == 'CAB-3' && i['owner_pid'] == 303 },
                'klik-select mieri na skrinku')
  vyska = items.find { |i| i['stable_key'].include?('niche_clash') }
  NxTest.assert(vyska['message_sk'].include?('1940') && vyska['message_sk'].include?('1924'),
                vyska['message_sk'])
end

NxTest.test('S1-F: kazda nesediaca OS je SAMOSTATNY riadok Kontroly') do
  uzka = NxS1F.low_cab('width' => 520.0, 'appliance_refs' => [NxS1F.ref])
  items = NxS1F.findings(NxS1F.record(uzka))
  NxTest.assert_equal(%w[appliance_niche_clash|height appliance_niche_clash|width],
                      NxS1F.codes(items).sort)
  NxTest.assert_equal(2, items.map { |i| i['stable_key'] }.uniq.length,
                      'dva rozne kluce — dedup ich nezlucí')
end

NxTest.test('S1-F (F9): ZIADNA nova zavaznost — INFO v Kontrole nie je') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'validation.rb'), encoding: 'UTF-8')
  NxTest.refute(src.include?("INFO = '"), 'kontrakt Kontroly ostava RED/ORANGE')
  ok_rec = NxS1F.bound('fronts' => NxS1F.fronts(695.0))
  NxTest.assert_equal([], NxS1F.findings(ok_rec), 'sediaca skrinka nema co hlasit')
end

NxTest.test('S1-F: pohlad „V zakazke" pomenuje nove kody (nie surovy segment osi)') do
  ad = Noxun::Engine::ApplianceDialog
  st = ad.job_status('bound', 'fridge',
                     [{ 'stable_key' => 'appliance|I-1|appliance_niche_clash|height',
                        'message_sk' => 'Spotrebič „Beko“ potrebuje niku výška min 1940, skrinka má 1924.' }])
  NxTest.assert_equal('warn', st['tone'])
  NxTest.assert_equal('nezmestí sa', st['status_text'], 'kod je TRETI segment kluca, nie posledny')
  st2 = ad.job_status('bound', 'fridge',
                      [{ 'stable_key' => 'appliance|I-1|appliance_door_split', 'message_sk' => 'x' }])
  NxTest.assert_equal('delenie čiel', st2['status_text'])
end

# ===================== 5) INSPECTOR: riadok + nahlad ========================

NxTest.test('S1-F: riadok Spotrebica nesie `check` a jeho verdikt je TEN ISTY ako v Kontrole') do
  cfg = NxS1F.low_cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(682.0))
  row = NxS1F::PANEL.appliance_rows('cabinet', cfg, [NxS1F.item],
                                    NxS1F::PANEL.appliance_interior(cfg)).first
  NxTest.assert_equal('bound', row['state'])
  NxTest.assert_equal('warn', row['tone'], 'clash = ORANGE riadok')
  NxTest.assert(row['check'].is_a?(Hash), 'riadok nesie cely verdikt')
  NxTest.assert_equal('clash', row['check']['state'])
  NxTest.assert_equal('clash', row['check']['niche']['axes']['height'])
  NxTest.assert_equal('clash', row['check']['door_split']['state'])
  # Rovnaka fixtura, druha cesta (zber -> Kontrola) musi povedat to iste.
  rec = NxS1F.record(cfg)
  NxTest.assert_equal(NxS1F::AC.verdict(rec)['state'], row['check']['state'],
                      'Inspector a Kontrola maju JEDEN modul')
  NxTest.assert(row['sub'].include?('nezmestí sa'), row['sub'])
end

NxTest.test('S1-F: sediaca skrinka ma riadok ZELENY a verdikt v podtexte') do
  cfg = NxS1F.cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(695.0))
  row = NxS1F::PANEL.appliance_rows('cabinet', cfg, [NxS1F.item],
                                    NxS1F::PANEL.appliance_interior(cfg)).first
  NxTest.assert_equal('ok', row['tone'])
  NxTest.assert_equal('ok', row['check']['state'])
  NxTest.assert(row['sub'].include?('nika ✓'), row['sub'])
  NxTest.assert(row['sub'].include?('679–727'), row['sub'])
end

NxTest.test('S1-F (F10): nahlad je KOLEKCIA adresovana `item_id`') do
  cfg = NxS1F.cab('appliance_refs' => [NxS1F.ref('I-1'),
                                       NxS1F.ref('I-2', 'niche' => { 'width_min' => 450.0,
                                                                     'height_min' => 800.0,
                                                                     'depth_min' => 500.0 })],
                  'fronts' => NxS1F.fronts(695.0))
  rows = NxS1F::PANEL.appliance_rows('cabinet', cfg, [NxS1F.item],
                                     NxS1F::PANEL.appliance_interior(cfg))
  pv = NxS1F::PANEL.appliance_preview(cfg, rows)
  NxTest.assert_equal(%w[I-1 I-2], pv.map { |a| a['item_id'] })
  NxTest.assert_equal({ 'x' => 20.0, 'z' => 118.0, 'w' => 560.0, 'h' => 1940.0 }, pv[0]['box'])
  NxTest.assert_equal({ 'x' => 75.0, 'z' => 118.0, 'w' => 450.0, 'h' => 800.0 }, pv[1]['box'])
  # Pasma prvej polozky: 0–40 · 40–669 · 669–740 · 740–1940 (v suradniciach korpusu +118).
  NxTest.assert_equal([40.0, 629.0, 71.0, 1200.0], pv[0]['bands'].map { |b| b['size'] })
  NxTest.assert_equal(118.0, pv[0]['bands'].first['z0'])
  NxTest.assert_equal(2058.0, pv[0]['bands'].last['z1'])
  # Druha polozka ma TIE ISTE pasma, ale NIZSI box — posledne pasmo sa OREZE
  # po vrch boxu (40 + 629 + 71 + 60 = 800). Box sa kvoli listu nezvacsuje.
  NxTest.assert_equal([40.0, 629.0, 71.0, 60.0], pv[1]['bands'].map { |b| b['size'] })
  NxTest.assert_equal(918.0, pv[1]['bands'].last['z1'], 'pasma koncia na vrchu boxu')
  sp = pv[0]['split']
  NxTest.assert_equal([797.0, 845.0], [sp['lo'], sp['hi']], 'pasmo hrany v suradniciach korpusu')
  NxTest.assert_equal([679.0, 727.0], [sp['lo_mm'], sp['hi_mm']], 'a cisla do popisku v nike')
  NxTest.assert_equal('ok', sp['state'])
end

NxTest.test('S1-F: bez vazby nahlad nekresli nic') do
  NxTest.assert_equal([], NxS1F::PANEL.appliance_preview(NxS1F.cab('appliance_expects' => ['fridge']), []))
end

# ==================== 6) LIFECYCLE cez REALNY build_plan ====================

NxTest.test('S1-F (F12): vazba -> box, odpojenie -> nic, iny model -> iny box') do
  base = NxS1F.cab
  NxTest.assert_equal([], NxS1F.plan_refs(base), 'pred vazbou')
  s_bind = NxS1F.plan_refs(base.merge('appliance_refs' => [NxS1F.ref]))
  NxTest.assert_equal([560.0, 555.0, 1940.0], s_bind.first[:box].map(&:to_f))
  # `rebind_model` prepise zaznam vazby -> box sa zmeni, identita polozky ostava.
  iny = NxS1F.ref('I-1', 'niche' => { 'width_min' => 600.0, 'height_min' => 1780.0,
                                      'depth_min' => 560.0 })
  s_re = NxS1F.plan_refs(base.merge('appliance_refs' => [iny]))
  NxTest.assert_equal([600.0, 560.0, 1780.0], s_re.first[:box].map(&:to_f))
  NxTest.assert_equal('ref:appliance_niche:I-1', s_re.first[:ref_key], 'identita je polozka')
  NxTest.assert_equal([], NxS1F.plan_refs(base), 'odpojenie = ziadny box')
end

NxTest.test('S1-F (F12): ZMENA ZIVEHO KATALOGU po vazbe boxom ani verdiktom nepohne') do
  cfg = NxS1F.cab('appliance_refs' => [NxS1F.ref], 'fronts' => NxS1F.fronts(695.0))
  box0 = NxS1F.plan_refs(cfg).first[:box].map(&:to_f)
  v0 = NxS1F::AC.verdict(NxS1F.record(cfg))['state']
  # Katalog sa medzitym zmenil — ale zakazka ma SNAPSHOT, a ten sa nemeni.
  Noxun::Engine::ApplianceCatalog.reset_state! if
    Noxun::Engine::ApplianceCatalog.respond_to?(:reset_state!)
  NxTest.assert_equal(box0, NxS1F.plan_refs(cfg).first[:box].map(&:to_f))
  NxTest.assert_equal(v0, NxS1F::AC.verdict(NxS1F.record(cfg))['state'])
end

# ====================== 7) VYSTUPY SU NEDOTKNUTE ============================

NxTest.test('S1-F (R6): box niky NIKDY nejde do kusovnika, VEPO ani nakupu') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'),
                  encoding: 'UTF-8')
  body = src[/def render_reference\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'renderer referencie sa nasiel')
  NxTest.assert(body.include?("kind: 'reference'"), 'entita je referencia, nie dielec')
  NxTest.assert(body.include?('manufactured: false'))
  refs = NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [NxS1F.ref]))
  NxTest.assert(refs.all? { |r| r[:production_class] == 'reference' })
  # Plan referencii nie je `parts` — kusovnik cita VYHRADNE dielce.
  plan = NxS1F::CN.build_plan(NxS1F::CB.normalize(NxS1F.cab('appliance_refs' => [NxS1F.ref])), 'CAB-3')
  NxTest.refute(plan[:parts].any? { |p| p[:role].to_s.start_with?('appliance') })
end

NxTest.test('S1-F: `merge_final` referencie do configu NEUKLADA (model ostava cisty)') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'cabinet_builder.rb'),
                  encoding: 'UTF-8')
  body = src[/def merge_final\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, '`merge_final` sa nasla')
  NxTest.refute(body.include?('references'), 'plan referencii sa neperzistuje')
end
