# frozen_string_literal: true
# D-140 — VYSKA OSADENIA CHLADNICKY V SKRINKE (smoke S1, oprava C).
#
# CO BOLO ZLE: box niky chladnicky stal VZDY na dne skrinky. Ked Michal dal pod
# chladnicku policu, box aj pasma dveri ostali „prilepene na dne" a Kontrola
# delenia ciel radila hranu pre chladnicku, ktora tam vobec nestoji.
#
# CO PLATI TERAZ:
#   * polozka `appliance_refs[]` kategorie fridge smie niest `mount_offset`
#     (mm od hornej plochy dna po spodok niky); chybajuci kluc = 0,
#   * JEDINY citac `Construction.appliance_mount_offset` — builder, Kontrola,
#     Inspector, akcia panela aj prenos pri vymene modelu,
#   * box niky stoji na `z_lo + osadenie`, pasma dveri idu s nim,
#   * vyska niky sa meria ako VNUTRO − OSADENIE; vycerpana vyska je konflikt
#     a pri viacerych zonach sa aspon overi presah nad cele vnutro (Astra C FIX 6),
#   * veta Kontroly pouziva TU ISTU dostupnu vysku ako verdikt (FIX 7),
#   * hrana delenia ciel sa meria od DNA NIKY; vykres vyrobcu je kotveny
#     k standardnej montazi, takze dolne dvere narastu o osadenie (BLOCKER 3),
#   * zapis ide vlastnou akciou panela `set_appliance_mount` (jeden krok Spat),
#   * `CONFIG_SCHEMA` 18 — plugin v0.12.19 novy config neprestavuje (BLOCKER 1).
require_relative '../helper' unless defined?(NxTest)

# Headless: UI vrstva nie je v require zozname helpera. Fixtury S1-C a S1-F sa
# znovu pouzivaju (ten isty tvar skrinky, ref aj polozky zakazky) — ich subory
# v behu celej sady pridu na rad az po tomto, preto ich zavislosti nacitame sami.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  %w[actions_cabinet sync resolvers].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
end
require_relative 'test_s1c_expects'
require_relative 'test_s1f_chladnicka'

module NxD140
  module_function

  F     = NxS1F
  C     = NxS1C
  CN    = Noxun::Engine::Construction
  CB    = Noxun::Engine::CabinetBuilder
  AC    = Noxun::Engine::ApplianceChecks
  AB    = Noxun::Engine::ApplianceBinding
  BOM   = Noxun::Engine::Bom
  PANEL = Noxun::Engine::Panel

  # Ref chladnicky s osadenim (nil = kluc chyba).
  def ref(mount = nil, item_id = 'I-1', extra = {})
    extra = extra.merge('mount_offset' => mount) unless mount.nil?
    F.ref(item_id, extra)
  end

  # VYSOKA skrinka: vnutro 2090 (2226 − sokel 100 − dno 18 − vrch 18). Nika Beko
  # 1940–1950 sa do nej zmesti PRESNE pri osadeni 150.
  def tall(extra = {})
    F.cab({ 'height' => 2226.0 }.merge(extra))
  end

  # Skrinka s dvomi zonami nad sebou (vyska niky sa inak nekontroluje).
  def split_zones(extra = {})
    split = { 'id' => 'Z1', 'split' => { 'axis' => 'h', 'count' => 2, 'cuts' => [{}, {}] },
              'children' => [{ 'id' => 'Z1.1' }, { 'id' => 'Z1.2' }] }
    { 'zone_tree' => split, 'zones' => [{ 'id' => 'Z1.1' }, { 'id' => 'Z1.2' }] }.merge(extra)
  end

  # Vykres vyrobcu: dolne nabytkove dvere 700–720 (VYSKA DIELCA pri chladnicke na dne).
  def drawing_item
    fd = { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0, 'door_gap' => 71.0,
           'door_upper' => 1159.0,
           'furniture_doors' => { 'lower_min' => 700.0, 'lower_max' => 720.0, 'gap_ref' => 2.0 } }
    F.item('I-1', 'fridge', 'CAB-3', F.snapshot(nil, fd))
  end

  # Riadky karty skrinky CAB-3 — `owner_id` posiela produkcny payload vzdy
  # (bez neho by chyba obojsmerny dokaz a cip osadenia by sa neukazal).
  def row_for(cfg, items, owner_id: 'CAB-3')
    PANEL.appliance_rows('cabinet', cfg, items, PANEL.appliance_interior(cfg), owner_id: owner_id)
  end

  # Ciel akcie: skrinka CAB-3 (pid 303) s refs a polozkami zakazky.
  def with_target(cab, items, scan: nil)
    C.with_stubs([[PANEL, :find_cabinet, ->(_m) { cab }],
                  [PANEL, :appliance_items, ->(_m) { items }],
                  scan || C.scan_stub(cabinets: [cab])]) { yield }
  end

  def target(cab, items, data, scan: nil)
    with_target(cab, items, scan: scan) { PANEL.appliance_mount_target(C::FakeModel.new, data) }
  end

  def data(extra = {})
    { 'cabinet_id' => 'CAB-3', 'pid' => 303, 'item_id' => 'I-1' }.merge(extra)
  end

  def fridge_item(owner_id = 'CAB-3')
    C.item('I-1', 'fridge', 'cabinet', owner_id)
  end
end

# ============================ 1) CITAC HODNOTY ==============================

NxTest.test('D-140: citac osadenia — platne kladne cislo, inak 0 (nikdy nezhodi stavbu)') do
  cn = NxD140::CN
  NxTest.assert_equal(0.0, cn.appliance_mount_offset(nil), 'nil ref')
  NxTest.assert_equal(0.0, cn.appliance_mount_offset({}), 'chybajuci kluc = 0')
  NxTest.assert_equal(150.0, cn.appliance_mount_offset('mount_offset' => 150))
  NxTest.assert_equal(150.5, cn.appliance_mount_offset('mount_offset' => 150.5))
  NxTest.assert_equal(80.0, cn.appliance_mount_offset(mount_offset: 80.0), 'symbolovy kluc (plan)')
  NxTest.assert_equal(0.0, cn.appliance_mount_offset('mount_offset' => '150'), 'retazec nie je cislo')
  NxTest.assert_equal(0.0, cn.appliance_mount_offset('mount_offset' => -5.0), 'zaporne = 0')
  NxTest.assert_equal(0.0, cn.appliance_mount_offset('mount_offset' => Float::NAN))
  NxTest.assert_equal(0.0, cn.appliance_mount_offset('mount_offset' => Float::INFINITY))
  NxTest.assert_equal(cn::MOUNT_OFFSET_MAX, cn.appliance_mount_offset('mount_offset' => 5000.0),
                      'preklep (m namiesto mm) sa oreze na strop')
  NxTest.assert_equal(0.0, cn.appliance_mount_offset('nie hash'))
end

NxTest.test('D-140: CONFIG_SCHEMA >= 18 — plugin v0.12.19 kluc nepozna a novy config neprestavi') do
  NxTest.assert(NxD140::CB::CONFIG_SCHEMA >= 18, "schema #{NxD140::CB::CONFIG_SCHEMA}")
  cfg = { 'config_schema' => NxD140::CB::CONFIG_SCHEMA + 1 }
  NxTest.assert(NxD140::CB.newer_config?(cfg), 'novsi config sa brani (vzor 5-17)')
end

# ============================== 2) BOX NIKY =================================

NxTest.test('D-140: osadenie 150 zdvihne box niky o 150 (z 118 -> 268), rozmer aj pasma ostavaju') do
  rd = NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [NxD140.ref(150.0)])).first
  NxTest.assert_equal([20.0, 0.0, 268.0], rd[:origin].map(&:to_f), 'dno 118 + osadenie 150')
  NxTest.assert_equal([560.0, 555.0, 1940.0], rd[:box].map(&:to_f), 'box sa NIKDY nedeformuje')
  NxTest.assert_equal(40.0, rd[:bands]['door_bottom_offset'], 'pasma idu s boxom (su relativne)')
  rd0 = NxS1F.plan_refs(NxS1F.cab('appliance_refs' => [NxD140.ref(0.0)])).first
  NxTest.assert_equal(118.0, rd0[:origin][2].to_f, 'osadenie 0 = stoji na dne')
end

NxTest.test('D-140: DVE chladnicky — kazda ma VLASTNE osadenie (ref, nie spolocny kontext)') do
  small = { 'width_min' => 450.0, 'height_min' => 800.0, 'depth_min' => 500.0 }
  cfg = NxS1F.cab('appliance_refs' => [NxD140.ref(150.0, 'I-1'),
                                       NxD140.ref(nil, 'I-2', 'niche' => small)])
  by = NxS1F.plan_refs(cfg).each_with_object({}) { |r, h| h[r[:item_id]] = r[:origin][2].to_f }
  NxTest.assert_equal({ 'I-1' => 268.0, 'I-2' => 118.0 }, by)

  owners = {}
  NxD140::BOM.note_appliance_owner(owners, 'CAB-3', 303, cfg)
  items = [NxS1F.item('I-1'), NxS1F.item('I-2')]
  recs = NxD140::BOM.appliance_records(items, owners)
  mounts = recs.each_with_object({}) { |r, h| h[r['item_id']] = r['mount_offset'] }
  NxTest.assert_equal({ 'I-1' => 150.0, 'I-2' => 0.0 }, mounts, 'zber nesie osadenie PER KUS')
end

NxTest.test('D-140: prestavba cez config_to_params kluc ZACHOVA; kopia ho zahodi s celou vazbou') do
  cfg = NxS1F.cab('appliance_refs' => [NxD140.ref(150.0)])
  norm = NxD140::CB.normalize(NxD140::CB.config_to_params(cfg))
  refs = norm['appliance_refs'] || norm[:appliance_refs]
  NxTest.assert_equal(150.0, refs.first['mount_offset'], 'zmena rozmeru skrinky osadenie nezmaze')

  params = NxD140::CB.config_to_params(cfg)
  NxD140::CB.strip_appliance_refs!(params)
  NxTest.refute(params.key?('appliance_refs'), 'kopia skrinky nevlastni ten isty kus ani jeho osadenie')
end

# ============================ 3) VERDIKT VYSKY ==============================

NxTest.test('D-140: vyska sa meria ako VNUTRO − OSADENIE (2090 − 150 = 1940 sedi, bez osadenia nie)') do
  rec = NxS1F.record(NxD140.tall('appliance_refs' => [NxD140.ref(150.0)]))
  NxTest.assert_equal(150.0, rec['mount_offset'])
  NxTest.assert_equal(2090.0, rec['interior']['height'], 'vnutro sa NEMENI')
  v = NxD140::AC.niche_verdict(rec)
  NxTest.assert_equal('ok', v['axes']['height'])
  NxTest.assert(v['axis_texts']['height'].include?('(vnútro 2090 − osadenie 150)'),
                "veta priznava odpocet: #{v['axis_texts']['height']}")

  bez = NxS1F.record(NxD140.tall('appliance_refs' => [NxD140.ref]))
  NxTest.assert_equal('clash', NxD140::AC.niche_verdict(bez)['axes']['height'], '2090 > 1950')
end

NxTest.test('D-140: osadenie v NIZKEJ nike = konflikt vysky s odpoctom vo vete') do
  rec = NxS1F.record(NxS1F.cab('appliance_refs' => [NxD140.ref(150.0)]))
  v = NxD140::AC.niche_verdict(rec)
  NxTest.assert_equal('clash', v['axes']['height'])
  NxTest.assert(v['text'].include?('výška 1790 < 1940 (vnútro 1940 − osadenie 150)'), v['text'])
end

NxTest.test('D-140 (FIX 6): VYCERPANA vyska (osadenie >= vnutro) je KONFLIKT, nie „nevieme"') do
  [1940.0, 2000.0].each do |m|
    rec = NxS1F.record(NxS1F.cab('appliance_refs' => [NxD140.ref(m)]))
    v = NxD140::AC.niche_verdict(rec)
    NxTest.assert_equal('clash', v['axes']['height'], "osadenie #{m}")
    NxTest.assert(v['axis_texts']['height'].include?("osadenie #{m.round} ≥ vnútro 1940"),
                  v['axis_texts']['height'])
    codes = NxS1F.codes(NxS1F.findings(rec))
    NxTest.assert(codes.include?('appliance_niche_clash|height'), "nalez Kontroly: #{codes.inspect}")
  end
end

NxTest.test('D-140 (FIX 6): VIAC ZON — presah osadenia nad CELE vnutro je konflikt, inak skip') do
  # 100 + 1940 = 2040 > 1924 (nizka skrinka) -> clash.
  rec = NxS1F.record(NxS1F.low_cab(NxD140.split_zones('appliance_refs' => [NxD140.ref(100.0)])))
  NxTest.assert_equal(false, rec['single_zone'])
  v = NxD140::AC.niche_verdict(rec)
  NxTest.assert_equal('clash', v['axes']['height'])
  NxTest.assert(v['axis_texts']['height'].include?('osadenie 100 + nika 1940 > vnútro 1924'),
                v['axis_texts']['height'])
  msgs = NxS1F.findings(rec).map { |i| i['message_sk'] }
  NxTest.assert(msgs.any? { |m| m.include?('osadenie 100 + nika 1940 > vnútro 1924') },
                "Kontrola hovori to iste: #{msgs.inspect}")

  # 100 + 1940 = 2040 <= 2090 (vysoka skrinka) -> vyska sa nekontroluje ako doteraz.
  ok = NxS1F.record(NxD140.tall(NxD140.split_zones('appliance_refs' => [NxD140.ref(100.0)])))
  v2 = NxD140::AC.niche_verdict(ok)
  NxTest.assert_equal('skip', v2['axes']['height'])
  NxTest.assert_equal([], NxS1F.findings(ok), 'preskocena os nalez nerobi')
end

NxTest.test('D-140 (FIX 7): veta Kontroly radi TU ISTU opravu ako Inspector (1800 − 100 = 1700)') do
  niche = { 'width_min' => 560.0, 'height_min' => 1750.0, 'height_max' => 1780.0, 'depth_min' => 555.0 }
  it = NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot(niche))
  cfg = NxS1F.cab('height' => 1936.0, 'appliance_refs' => [NxD140.ref(100.0)])
  rec = NxS1F.record(cfg, [it])
  NxTest.assert_equal(1800.0, rec['interior']['height'])
  msg = NxS1F.findings(rec).find { |i| i['stable_key'].include?('niche_clash') }['message_sk']
  NxTest.assert(msg.include?('min 1750, skrinka má 1700 (vnútro 1800 − osadenie 100)'), msg)
  NxTest.refute(msg.include?('najviac'), "nesmie radit opacnu opravu: #{msg}")

  # Bez osadenia je 1800 NAOZAJ privela — a veta to povie.
  rec0 = NxS1F.record(NxS1F.cab('height' => 1936.0, 'appliance_refs' => [NxD140.ref]), [it])
  msg0 = NxS1F.findings(rec0).find { |i| i['stable_key'].include?('niche_clash') }['message_sk']
  NxTest.assert(msg0.include?('najviac 1780, skrinka má 1800.'), msg0)
end

# ========================= 4) DELENIE CIEL S OSADENIM =======================

NxTest.test('D-140: pasmo z PRAXE ide so spotrebicom — hrana sa meria od DNA NIKY') do
  # Dolne celo 869: vrch v modeli 102 + 869 = 971; dno niky 118 + 150 = 268 -> hrana 703.
  rec = NxS1F.record(NxD140.tall('appliance_refs' => [NxD140.ref(150.0)],
                                 'fronts' => NxS1F.fronts(869.0)))
  s = NxD140::AC.door_split_verdict(rec)
  NxTest.assert_equal('practice', s['source'])
  NxTest.assert_equal([679.0, 727.0], s['range'], 'pasmo v suradniciach niky sa NEMENI')
  NxTest.assert_close(703.0, s['edge'], 0.01)
  NxTest.assert_equal('ok', s['state'])

  # To iste celo BEZ osadenia by hranu malo o 150 vyssie — nad pasmom.
  rec0 = NxS1F.record(NxD140.tall('appliance_refs' => [NxD140.ref],
                                  'fronts' => NxS1F.fronts(869.0)))
  s0 = NxD140::AC.door_split_verdict(rec0)
  NxTest.assert_close(853.0, s0['edge'], 0.01)
  NxTest.assert_equal('clash', s0['state'])
end

NxTest.test('D-140 (BLOCKER 3): VYKRES vyrobcu — dolne dvere narastu o osadenie (nie ticho ok)') do
  cfg = NxD140.tall('appliance_refs' => [NxD140.ref(150.0)], 'fronts' => NxS1F.fronts(710.0))
  s = NxD140::AC.door_split_verdict(NxS1F.record(cfg, [NxD140.drawing_item]))
  NxTest.assert_equal('drawing', s['source'])
  NxTest.assert_equal([684.0, 704.0], s['range'], 'vykres je kotveny k montazi na dne')
  NxTest.assert_close(544.0, s['edge'], 0.01, '812 − (118 + 150)')
  NxTest.assert_equal('clash', s['state'], 'dvere 710 pri zdvihnutej chladnicke uz nesedia')
  NxTest.assert(s['note'].to_s.include?('pri osadení 150 sa dolné dvere zväčšujú o 150'),
                "prizna sa to: #{s['note'].inspect}")
  NxTest.assert(s['note'].to_s.include?('škárou 2'), 'gap_ref ostava v poznamke')

  # Dvere o 150 vyssie (860) su zase v pasme.
  cfg2 = NxD140.tall('appliance_refs' => [NxD140.ref(150.0)], 'fronts' => NxS1F.fronts(860.0))
  s2 = NxD140::AC.door_split_verdict(NxS1F.record(cfg2, [NxD140.drawing_item]))
  NxTest.assert_close(694.0, s2['edge'], 0.01)
  NxTest.assert_equal('ok', s2['state'])

  # Bez osadenia sa poznamka o zvacseni NEPISE.
  cfg0 = NxD140.tall('appliance_refs' => [NxD140.ref], 'fronts' => NxS1F.fronts(710.0))
  s0 = NxD140::AC.door_split_verdict(NxS1F.record(cfg0, [NxD140.drawing_item]))
  NxTest.assert_equal('ok', s0['state'])
  NxTest.refute(s0['note'].to_s.include?('osadení'), s0['note'].inspect)
end

# ======================== 5) INSPECTOR: riadok + nahlad =====================

NxTest.test('D-140: riadok chladnicky nesie `mount`; verdikt riadku = verdikt Kontroly') do
  cfg = NxD140.tall('appliance_refs' => [NxD140.ref(150.0)], 'fronts' => NxS1F.fronts(869.0))
  row = NxD140.row_for(cfg, [NxS1F.item]).first
  NxTest.assert_equal({ 'value' => 150.0, 'text' => 'osadenie 150 mm' }, row['mount'])
  NxTest.assert_equal('ok', row['check']['state'], 'nika aj delenie sedia az S OSADENIM')
  NxTest.assert_equal(NxD140::AC.verdict(NxS1F.record(cfg))['state'], row['check']['state'],
                      'Inspector a Kontrola citaju osadenie z toho isteho ref')

  half = NxD140.row_for(NxS1F.cab('appliance_refs' => [NxD140.ref(150.5)]), [NxS1F.item]).first
  NxTest.assert_equal('osadenie 150,5 mm', half['mount']['text'])
  zero = NxD140.row_for(NxS1F.cab('appliance_refs' => [NxD140.ref]), [NxS1F.item]).first
  NxTest.assert_equal({ 'value' => 0.0, 'text' => 'osadenie 0 mm' }, zero['mount'],
                      'chladnicka na dne ma tlacidlo tiez (inak by sa osadenie nedalo zadat)')
end

NxTest.test('D-140: osadenie NEMA rura ani osirely riadok (zaniknuta polozka)') do
  oven_ref = { 'item_id' => 'I-9', 'category' => 'oven' }
  oven = NxS1F.item('I-9', 'oven', 'CAB-3', NxS1F.snapshot.merge('category' => 'oven'))
  rows = NxD140.row_for(NxS1F.cab('appliance_refs' => [oven_ref]), [oven])
  NxTest.refute(rows.first.key?('mount'), "rura: #{rows.first.inspect}")

  orphan = NxD140.row_for(NxS1F.cab('appliance_refs' => [NxD140.ref(150.0)]), []).first
  NxTest.assert_equal('bound', orphan['state'])
  NxTest.refute(orphan.key?('mount'), 'sirota sa neupravuje, len odpaja')
end

NxTest.test('D-140 (Codex #389 kolo 2): cip LEN pri OBOJSMERNEJ vazbe — jednostranny zaznam ho nema') do
  cfg = NxS1F.cab('appliance_refs' => [NxD140.ref(150.0)])
  ok = NxD140.row_for(cfg, [NxS1F.item('I-1', 'fridge', 'CAB-3')]).first
  NxTest.assert_equal(150.0, ok['mount']['value'], 'polozka patri tejto skrinke -> cip')

  # Polozku medzitym presunulo druhe okno do CAB-4, CAB-3 drzi uz len stary zaznam.
  stale = NxD140.row_for(cfg, [NxS1F.item('I-1', 'fridge', 'CAB-4')]).first
  NxTest.assert_equal('bound', stale['state'], 'riadok ostava (da sa odpojit)')
  NxTest.refute(stale.key?('mount'), 'server by zapis vzdy odmietol -> cip nesmie klamat')

  twice = NxS1F.cab('appliance_refs' => [NxD140.ref(150.0), NxD140.ref(90.0)])
  rows = NxD140.row_for(twice, [NxS1F.item('I-1', 'fridge', 'CAB-3')])
  NxTest.assert(rows.none? { |r| r.key?('mount') }, 'dva zaznamy toho isteho kusu = nejednoznacny ciel')
  NxTest.assert(NxD140.row_for(cfg, [NxS1F.item], owner_id: '').none? { |r| r.key?('mount') },
                'bez identity vlastnika sa dokaz neda urobit')
end

NxTest.test('D-140 (Codex #389 kolo 2): VYCERPANA vyska je konflikt aj BEZ udajov niky') do
  bez = NxS1F.item('I-1', 'fridge', 'CAB-3', NxS1F.snapshot({}))
  rec = NxS1F.record(NxS1F.cab('appliance_refs' => [NxD140.ref(1940.0)]), [bez])
  v = NxD140::AC.niche_verdict(rec)
  NxTest.assert_equal(true, v['specs_missing'], 'model rozmery niky naozaj nema')
  NxTest.assert_equal('clash', v['axes']['height'])
  NxTest.assert(v['text'].include?('osadenie 1940 ≥ vnútro 1940'), v['text'])
  msgs = NxS1F.findings(rec).select { |i| i['stable_key'].include?('niche_clash|height') }
  NxTest.assert_equal(1, msgs.length, 'Kontrola ho hlasi')
  NxTest.assert(msgs.first['message_sk'].include?('osadenie 1940 ≥ vnútro 1940'), msgs.first['message_sk'])

  # Osadenie, ktore vnutro NEVYCERPA, bez udajov niky ostava „nevieme".
  ok = NxS1F.record(NxS1F.cab('appliance_refs' => [NxD140.ref(100.0)]), [bez])
  v2 = NxD140::AC.niche_verdict(ok)
  NxTest.assert_equal('unknown', v2['state'])
  NxTest.assert_equal([], NxS1F.findings(ok).select { |i| i['stable_key'].include?('niche_clash') })
end

NxTest.test('D-140: nahlad kresli box, pasma aj pasmo hrany od ZDVIHNUTEHO dna') do
  cfg = NxD140.tall('appliance_refs' => [NxD140.ref(150.0)], 'fronts' => NxS1F.fronts(869.0))
  rows = NxD140.row_for(cfg, [NxS1F.item])
  pv = NxD140::PANEL.appliance_preview(cfg, rows).first
  NxTest.assert_equal(268.0, pv['box']['z'])
  NxTest.assert_equal(268.0, pv['bands'].first['z0'], 'pasma idu s boxom')
  sp = pv['split']
  NxTest.assert_equal([947.0, 995.0], [sp['lo'], sp['hi']], '268 + 679 / 268 + 727')
  NxTest.assert_equal(971.0, sp['edge'], 'hrana = skutocny vrch dolneho cela v modeli')
  NxTest.assert_equal([679.0, 727.0], [sp['lo_mm'], sp['hi_mm']], 'popisok v suradniciach niky')
end

# ============================ 6) AKCIA PANELA ===============================

NxTest.test('D-140: hodnota osadenia — 0 az 2000 mm, zaokruhlenie na 0,1 mm, inak veta') do
  p = NxD140::PANEL
  NxTest.assert_equal([150.0, nil], p.appliance_mount_value(150))
  NxTest.assert_equal([150.0, nil], p.appliance_mount_value(150.04), 'zaokruhlenie 0,1 mm')
  NxTest.assert_equal([0.0, nil], p.appliance_mount_value(0), '0 = stoji na dne (platne)')
  NxTest.assert_equal([2000.0, nil], p.appliance_mount_value(2000.0))
  [-1, 2000.5].each do |bad|
    v, err = p.appliance_mount_value(bad)
    NxTest.assert(v.nil? && err.include?('0 až 2000'), "#{bad}: #{err.inspect}")
  end
  ['150', nil, Float::NAN, Float::INFINITY].each do |bad|
    v, err = p.appliance_mount_value(bad)
    NxTest.assert(v.nil? && err.include?('zadaj výšku v mm'), "#{bad.inspect}: #{err.inspect}")
  end
end

NxTest.test('D-140: novy zoznam refs meni LEN tento kus a 0 kluc ZMAZE') do
  a = NxD140.ref(nil, 'I-1')
  b = NxD140.ref(90.0, 'I-2')
  refs = [a, b]
  out = NxD140::PANEL.appliance_mount_refs(refs, 0, 150.0)
  NxTest.assert_equal(150.0, out[0]['mount_offset'])
  NxTest.assert(out[1].equal?(b), 'iny kus sa nedotkne')
  NxTest.refute(a.key?('mount_offset'), 'povodny zoznam sa NEMUTUJE')
  zero = NxD140::PANEL.appliance_mount_refs(refs, 1, 0.0)
  NxTest.refute(zero[1].key?('mount_offset'), 'nula sa neuklada — chybajuci kluc = 0')
  NxTest.assert_equal(90.0, b['mount_offset'], 'povodny ref ostal cely')
end

NxTest.test('D-140 (FIX 5): ciel zapisu — echo ID+PID, zivy kus TEJTO skrinky, PRAVE JEDEN fridge ref') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  pm = NxD140::PANEL
  fr = { 'item_id' => 'I-1', 'category' => 'fridge' }
  cab = NxS1C.cabinet('CAB-3', 303, refs: [fr])
  items = [NxD140.fridge_item]

  inst, refs, idx, err = NxD140.target(cab, items, NxD140.data)
  NxTest.assert(err.nil?, err.inspect)
  NxTest.assert(inst.equal?(cab), 'ciel je oznacena skrinka')
  NxTest.assert_equal([0, 'I-1'], [idx, refs[idx]['item_id']])
  NxTest.assert(NxD140.target(cab, items, NxD140.data('pid' => '303'))[3].nil?, 'pid ako retazec z DOM')

  cases = {
    'ina skrinka' => [NxD140.data('cabinet_id' => 'CAB-9'), pm::APPL_MSG_STALE],
    'iny pid' => [NxD140.data('pid' => 304), pm::APPL_MSG_STALE],
    'neznamy kus' => [NxD140.data('item_id' => 'I-X'), pm::APPL_MSG_MOUNT_GONE],
    'prazdny kus' => [NxD140.data('item_id' => ''), pm::APPL_MSG_MOUNT_GONE]
  }
  cases.each do |what, (d, want)|
    NxTest.assert_equal(want, NxD140.target(cab, items, d)[3], what)
  end

  gone = NxD140.target(cab, [], NxD140.data)[3]
  NxTest.assert_equal(pm::APPL_MSG_MOUNT_GONE, gone, 'polozka zmizla zo zakazky')
  foreign = NxD140.target(cab, [NxD140.fridge_item('CAB-4')], NxD140.data)[3]
  NxTest.assert_equal(pm::APPL_MSG_MOUNT_GONE, foreign, 'polozka patri inej skrinke (obojsmerny dokaz)')

  oven = NxS1C.cabinet('CAB-3', 303, refs: [{ 'item_id' => 'I-1', 'category' => 'oven' }])
  NxTest.assert_equal(pm::APPL_MSG_MOUNT_GONE,
                      NxD140.target(oven, [NxS1C.item('I-1', 'oven', 'cabinet', 'CAB-3')], NxD140.data)[3],
                      'osadenie ma LEN chladnicka')
  twice = NxS1C.cabinet('CAB-3', 303, refs: [fr, fr.dup])
  NxTest.assert_equal(pm::APPL_MSG_MOUNT_GONE, NxD140.target(twice, items, NxD140.data)[3],
                      'dva zaznamy toho isteho kusu = nejednoznacny ciel')
  slot = NxS1C.cabinet('CAB-3', 303, type: 'dishwasher', refs: [fr])
  NxTest.assert_equal(pm::APPL_MSG_MOUNT_GONE, NxD140.target(slot, items, NxD140.data)[3])
  newer = NxS1C.cabinet('CAB-3', 303, refs: [fr], schema: NxD140::CB::CONFIG_SCHEMA + 1)
  NxTest.assert_equal(pm::APPL_MSG_NEWER, NxD140.target(newer, items, NxD140.data)[3])

  det = NxS1C.scan_stub(cabinets: [cab], detached: { 'CAB-3' => 1 })
  NxTest.assert_equal(pm::APPL_MSG_DETACH, NxD140.target(cab, items, NxD140.data, scan: det)[3])
  twin = NxS1C.cabinet('CAB-3', 404, refs: [fr])
  amb = NxS1C.scan_stub(cabinets: [cab, twin])
  NxTest.assert_equal(pm::APPL_MSG_AMBIG, NxD140.target(cab, items, NxD140.data, scan: amb)[3])
  NxTest.assert_equal(pm::APPL_MSG_NO_TARGET, NxD140.target(nil, items, NxD140.data)[3])
end

NxTest.test('D-140: zapis = JEDNA operacia (1 krok Spat); zlyhanie = abort + cerstva karta') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  pm = NxD140::PANEL
  cab = NxS1C.cabinet('CAB-3', 303, refs: [{ 'item_id' => 'I-1', 'category' => 'fridge' }])
  written = []
  pushes = []
  write_ok = ->(_m, _inst, refs) { written << refs; true }
  NxS1C.with_stubs([[NxD140::CB, :write_appliance_refs!, write_ok],
                    [pm, :push_selected, ->(_m, **k) { pushes << k; true }],
                    [pm, :set_status, ->(msg, err = false) { [msg, err] }]]) do
    model = NxS1C::FakeModel.new
    out = pm.appliance_mount_write(model, cab, [{ 'item_id' => 'I-1', 'mount_offset' => 150.0 }], 150.0)
    NxTest.assert_equal([pm::APPL_MOUNT_OP], model.ops, 'JEDNA operacia')
    NxTest.assert_equal([1, 0], [model.committed, model.aborted])
    NxTest.assert_equal(150.0, written.first.first['mount_offset'])
    NxTest.assert_equal(['Osadenie spotrebiča: 150 mm od dna.', false], out)
    out0 = pm.appliance_mount_write(NxS1C::FakeModel.new, cab, [{ 'item_id' => 'I-1' }], 0.0)
    NxTest.assert_equal(['Osadenie spotrebiča: na dne.', false], out0)
  end

  boom = ->(_m, _inst, _refs) { raise 'stavba zlyhala' }
  NxS1C.with_stubs([[NxD140::CB, :write_appliance_refs!, boom],
                    [pm, :push_selected, ->(_m, **k) { pushes << k; true }],
                    [pm, :set_status, ->(msg, err = false) { [msg, err] }]]) do
    model = NxS1C::FakeModel.new
    out = pm.appliance_mount_write(model, cab, [], 150.0)
    NxTest.assert_equal([0, 1], [model.committed, model.aborted], 'polovicny stav sa zahodi')
    NxTest.assert_equal([pm::APPL_MSG_MOUNT_FAILED, true], out)
    NxTest.assert_equal({ dedup: false }, pushes.last, 'cerstva karta bez dedup prestavby')
  end
end

NxTest.test('D-140: poradie handlera — dokument, bariera, ciel, hodnota, echo povodnej, zapis') do
  src = NxS1C.src('noxun_engine', 'ui', 'panel', 'actions_appliance.rb')
  body = NxS1C.body_of(src, 'handle_set_appliance_mount')
  NxTest.refute(body.empty?, 'handler sa nasiel')
  order = ['foreign_document?', 'observer_idle?', 'appliance_mount_target',
           'appliance_mount_value', "data['prev']", 'APPL_MSG_MOUNT_STALE', 'APPL_MSG_MOUNT_SAME',
           'appliance_mount_write']
  idx = order.map { |k| body.index(k) }
  NxTest.assert(idx.none?(&:nil?), "vsetky kroky: #{order.zip(idx).inspect}")
  NxTest.assert_equal(idx.sort, idx, 'identita dokumentu PRVA, bariera PRED cielom, echo PRED zapisom')

  wbody = NxS1C.body_of(src, 'appliance_mount_write')
  %w[ensure_root_context CabinetBuilder.guarded start_operation(APPL_MOUNT_OP write_appliance_refs!
     commit_operation].each_cons(2) do |a, b|
    NxTest.assert(wbody.index(a) && wbody.index(b) && wbody.index(a) < wbody.index(b), "#{a} < #{b}")
  end
  NxTest.assert(wbody.include?('abort_safely'), 'vynimka = abort')
  NxTest.assert(wbody.index('commit_operation') < wbody.index('refresh_if_open(bump: true)'),
                'Studio sa obnovi AZ PO uspesnom zapise')
  panel = NxS1C.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.assert(panel.include?("cb(dlg, 'set_appliance_mount') { |p| handle_set_appliance_mount(p) }"),
                'callback je zaregistrovany')
end

# ======================= 7) VYMENA MODELU (carry) ===========================

NxTest.test('D-140 (FIX 9): vymena modelu prenesie osadenie LEN medzi dvoma chladnickami') do
  ab = NxD140::AB
  old = { 'item_id' => 'I-1', 'category' => 'fridge', 'mount_offset' => 150.0 }
  rec = ab.carry_mount!({ 'item_id' => 'I-1', 'category' => 'fridge' }, old)
  NxTest.assert_equal(150.0, rec['mount_offset'], 'fridge -> fridge')

  NxTest.refute(ab.carry_mount!({ 'item_id' => 'I-1', 'category' => 'oven' }, old).key?('mount_offset'),
                'fridge -> rura osadenie NEPRENASA')
  oven_old = old.merge('category' => 'oven')
  NxTest.refute(ab.carry_mount!({ 'item_id' => 'I-1', 'category' => 'fridge' }, oven_old).key?('mount_offset'))
  NxTest.refute(ab.carry_mount!({ 'item_id' => 'I-1', 'category' => 'fridge' }, nil).key?('mount_offset'),
                'presun na inu skrinku (stary zaznam tam nie je)')
  zero = old.merge('mount_offset' => 0.0)
  NxTest.refute(ab.carry_mount!({ 'item_id' => 'I-1', 'category' => 'fridge' }, zero).key?('mount_offset'),
                'nula sa neuklada')

  src = NxS1C.src('noxun_engine', 'core', 'appliance_binding.rb')
  body = src[/def add_ref!\(.*?\n      end\n/m].to_s
  call = "carry_mount!(rec, carry_source(plan, rec['item_id']))"
  NxTest.assert(body.index(call) && body.index(call) < body.index('.reject'),
                'stary zaznam sa precita PRED prepisom zoznamu')
end

NxTest.test('D-140 (Codex #389 kolo 2): PRESUN na jednostranny zaznam osadenie NEZDEDI') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  ab = NxD140::AB
  stale = { 'item_id' => 'I-1', 'category' => 'fridge', 'mount_offset' => 90.0 }
  cab_b = NxS1C.cabinet('CAB-4', 404, refs: [stale])
  cab_a = NxS1C.cabinet('CAB-3', 303, refs: [{ 'item_id' => 'I-1', 'category' => 'fridge' }])

  moving = { owner_changed: true, new_entity: cab_b, prev: { inst: cab_a, kind: 'cabinet' } }
  NxTest.assert(ab.carry_source(moving, 'I-1').nil?, 'presun: zdroj osadenia NIE JE')
  rebind = { owner_changed: false, new_entity: cab_b, prev: { inst: cab_b, kind: 'cabinet' } }
  NxTest.assert_equal(90.0, ab.carry_source(rebind, 'I-1')['mount_offset'], 'vymena modelu: platna vazba')
  orphan = { owner_changed: false, new_entity: cab_b, prev: nil }
  NxTest.assert(ab.carry_source(orphan, 'I-1').nil?, 'bez overenej predchadzajucej vazby nic')

  written = []
  NxS1C.with_stubs([[ab, :write_refs!, ->(_m, _k, _inst, list) { written << list; true }]]) do
    item = NxS1F.item('I-1', 'fridge', 'CAB-4')
    owner = { 'kind' => 'cabinet', 'id' => 'CAB-4' }
    ab.add_ref!(NxS1C::FakeModel.new, moving.merge(owner: owner), owner, item)
    rec = written.last.find { |r| r['item_id'] == 'I-1' }
    NxTest.refute(rec.key?('mount_offset'), "presun nezdedil stare osadenie ciela: #{rec.inspect}")
    ab.add_ref!(NxS1C::FakeModel.new, rebind.merge(owner: owner), owner, item)
    NxTest.assert_equal(90.0, written.last.find { |r| r['item_id'] == 'I-1' }['mount_offset'],
                        'vymena modelu na tej istej entite osadenie drzi')
  end
end
