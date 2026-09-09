# frozen_string_literal: true
# KOV-E1b (9.9.2026) — VYKLOPY: pravidlo `lift_class`, config cela `lift.system`
# a BRANY (sklop = zavesy, stale, eligibility, prekryv, overridy).
#
# E1a priniesla DATA (katalog, sety, `code_by_param`, `quantity_from`, owner
# `/flap`); TATO davka prinasa PRAVIDLO, ktore ich naplni: z rozmerov KORPUSU
# a hmotnosti CELA urci triedu mechanizmu (HK top) alebo mechanizmus + ramena
# + pocet stabilizacnych tyci (HL top). Kod z triedy robi az set.
#
# CO SA OVERUJE:
#   1) HK TOP — LF = KH x (hmotnost + rezerva 0,5 kg); hranice tabulky
#      419,9 / 420 · 1610 / 1610,5 · 1730 · 2800 / 2800,5 · 9000 / 9000,5;
#      v prekryve NAJSLABSIA trieda, pod tabulkou ORANGE `lift_light_front`
#   2) HL TOP — mechanizmus podla KH (389 / 390), ramena podla KH A hmotnosti
#      (299 / 300 · 339,5 · 389,5 · 540 / 540,5 · 580 / 581; 9,00 / 9,01 pri
#      KH 320 · 12,25 / 12,26 pri KH 500 · 14,00 / 14,01); ziadna MEDZERA
#   3) TYC podla KB (1099 / 1100 -> `rod_count` 1 / 2, `rod_extension` 0 / 1)
#   4) KH je vyska KORPUSU BEZ SOKLA — nie vyrobna dlzka cela (396 v korpuse
#      400) a nie vyska so soklom
#   5) ELIGIBILITY — KB 1801 · hlbka 263 (HL) · KH 204 (HK) -> RED
#      `lift_dimension_unsupported`; hlbka ide z `available_depth` (chrbat
#      aj drazka), NIE z `depth - hrubka chrbta` (delta audit Sol BLOCKER 1)
#   6) TVRDE STAVY — `weight_kg` nil · HL + Tip-On · dva riadky ciel; polozka
#      sa VZDY VYDA (riadok v Kovani), export stoji
#   7) SKLOP — `zavesy-sklop` da zavesy s `use_type: 'door'`; sklop NIKDY
#      nedostane `lift`, vyklop NIKDY `hinge`; „nemá to byť výklop?" na sklop
#      neplati
#   8) PREKRYV — seed aj RUNTIME podla (vystup, rola, SMER); pravidlo len pre
#      `down` seed vyklopov NEPOTLACI, dve `lift` pravidla = jedna polozka
#      (delta audit Sol BLOCKER 2)
#   9) OVERRIDY — `disabled`/`quantity` na polozke `vyklopy-aventos` sa
#      IGNORUJU (+ ORANGE) a normalizacia configu ich vycisti; na VLASTNOM
#      `lift` pravidle ostavaju UCINNE
#  10) CONFIG CELA — `lift.system` prezije `normalize_items`, layout projekciu,
#      stavbu aj „reopen"; `CONFIG_SCHEMA` 11
#  11) `flap_stale` — LEN podla PROVENIENCIE STAVBY, a to DVOJITEJ (Codex #333
#      kolo 1 P1): `config_schema` < 11 ALEBO `rules_seed_version` < 5, takze
#      prestavba so STARYM snapshotom pravidiel RED nezhasne; up AJ down;
#      celo s UPLNOU RUCNOU ZOSTAVOU (mechanizmus vyklopu / zaves sklopu)
#      nalez nerobi a automat sa naň nevydava; prislusenstvo (krytka, tyc,
#      ramena, Tip-On) ani zly DRUH zostavu netvoria — automat bezi dalej
#      a zliatie kodov prizna ORANGE `flap_manual_duplicate`
#      (delta audit Sol FIX 4 + Codex #333 kola 1 a 2)
#  12) BRANY — kody v registri, nakup/rozpocet/ponuka stoja, VEPO bezi;
#      nedostupna expanzia s vyklopom je fail-closed (guard z E1a — TU sa LEN
#      overuje, ze plati aj na polozku z pravidla)
#  13) END-TO-END — pravidlo -> set -> nakup (HL 500 / 6 kg -> 22L2500 +
#      22L3800 + 1 tyc BEZ predlzenia; KB 1200 -> 2 tyce + predlzenie)
#  14) SEED — `SEED_VERSION` 5 (migracia z kniznice v4 doplni obe pravidla,
#      pouzivatelske nechá tak) a GOLDEN: zakazka bez vyklopov sa NEMENI
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1  rezerva na uchytku sa pripocita LEN pri HK      -> hranice HL kg
#   M2  v prekryve tried vyhrava NAJSILNEJSIA           -> 22K2300 pri LF 1000
#   M3  ramena maju medzeru (339,5 nikam nespada)       -> spojite pasma
#   M4  horna hranica ramien 300–339 je inkluzivna      -> KH 340 = 22L3500
#   M5  KH sa berie z vyrobnej dlzky cela               -> 396 v korpuse 400
#   M6  KH sa rata so soklom                            -> sokel 200
#   M7  hlbka pre HL = `depth` mínus chrbat             -> drazkovany chrbat
#   M8  RED polozku ZAHODI                              -> riadok v Kovani
#   M9  sklop dostane vyklopovy mechanizmus             -> filter `flap_dir`
#   M10 pravidlo bez filtra smeru sa neuplatni          -> wildcard
#   M11 prekryv sa porovnava LEN podla roly             -> hinge/up vs. sklop
#   M12 dve `lift` pravidla vydaju dva mechanizmy       -> runtime prekryv
#   M13 `disabled` vypne polozku vyklopu                -> plny automat
#   M14 ochrana plati aj na VLASTNE `lift` pravidlo     -> override ucinny
#   M15 `lift` zanikne v `normalize_items`              -> round-trip
#   M16 `flap_stale` sa pyta na seed pravidla           -> proveniencia stavby
#   M17 prestavana skrinka je stale                     -> schema 11
#   M18 vyklopove kody zablokuju VEPO                   -> scope `:kit`
#   M19 `SEED_VERSION` ostane 4                         -> migracia z v4
#   M20 pocet tyci sa rata zo SIRKY CELA                -> KB korpusu
#   M21 `flap_stale` pozera LEN na schemu configu       -> prestavba so seed 4
#   M22 brana ignoruje UPLNU rucnu zostavu na cele      -> `hardware_manual`
#   M23 automat sa vyda AJ k rucnemu mechanizmu         -> potlacenie + ORANGE
#   M24 potlacenie spusti KAZDA rucna polozka           -> krytka/volna/nezname
#   M25 stale branu zhasne HOCIJAKY rucny zaznam        -> prislusenstvo = RED
#   M26 druh rucnej polozky sa neporovnava so SMEROM    -> zaves na vyklope
#   M27 zliatie kodu s automatom je ticho               -> `flap_manual_duplicate`
#   M28 neciselny skalar zhodi normalizaciu dokumentu   -> Hash/true v pravidle
require_relative '../helper' unless defined?(NxTest)

require 'json'

# UI vrstva (brana exportov) — headless nie je v require zozname helpera.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxKovE1b
  E   = Noxun::Engine
  HR  = E::HardwareRules
  HWS = E::HardwareSets
  CN  = E::Construction
  CB  = E::CabinetBuilder
  BP  = E::BuildPlan
  BOM = E::Bom
  V   = E::Validation
  PC  = E::ProductionCore
  FR  = E::Fronts

  LIFT_RULE = HR::LIFT_RULE_ID
  FALL_RULE = HR::FALL_RULE_ID
  # KH, pri ktorej sa LF da nastavit PRESNE: mocnina dvojky, takze
  # `lf / KH_LF - 0,5` a spätne `(w + 0,5) * KH_LF` su v Float bezstratove.
  KH_LF = 512.0

  # Materialy pre anotaciu hmotnosti (vzor KOV-W): celo 18 mm / 750 kg/m3.
  def self.mat(th, dens)
    { 'thickness' => th, 'density' => dens, 'uni' => false }
  end
  MAT = { 'channels' => { 'body' => mat(18.0, 680.0), 'front' => mat(18.0, 750.0),
                          'back' => mat(3.0, 870.0), 'drawer' => mat(16.0, 680.0) },
          'parts' => {} }.freeze

  module_function

  def rules
    HR.normalize_rules(HR::SEED_RULES)
  end

  def lift_rule
    rules.find { |r| r['rule_id'] == LIFT_RULE }
  end

  # Deskriptor CELA vyklopu/sklopu tak, ako ho anotuje `Construction`.
  def flap(over = {})
    { role: 'flap', part_key: 'front:F1/flap', suffix: 'FLAP-1', name: 'Výklop 1',
      prod: { length: 396.0, width: 596.0, thickness: 18.0 },
      flap_dir: HR::FLAP_UP, lift_system: HR::LIFT_HK, weight_kg: 3.0 }.merge(over)
  end

  def ctx(over = {})
    { 'width' => 600.0, 'height' => 500.0, 'depth' => 500.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 384.0, 'available_depth' => 480.0,
      'kh' => 400.0, 'kb' => 600.0, 'front_rows' => 1, 'support' => 'none' }.merge(over)
  end

  def evaluate(parts, over_ctx = {}, cfg = {}, rules_over = nil, manual_flap = {})
    HR.evaluate(cfg, Array(parts), ctx(over_ctx), rules: rules_over || rules,
                                                  manual_flap_owners: manual_flap)
  end

  # Deskriptor DVIEROK (rola `front_door`) — kontrola, ze sa spravanie F1
  # potlacenim vyklopov nezmenilo.
  def door(over = {})
    { role: 'front_door', part_key: 'front:F2/wing:single', suffix: 'DOOR-1', name: 'Dvierka',
      prod: { length: 700.0, width: 396.0, thickness: 18.0 },
      weight_kg: 5.0 }.merge(over)
  end

  def lifts(res)
    res[:items].select { |it| it['generic_type'] == 'lift' }
  end

  def hinges(res)
    res[:items].select { |it| it['generic_type'] == 'hinge' }
  end

  def codes(res)
    res[:conflicts].map { |c| c['code'] }.sort
  end

  def warn_codes(res)
    res[:warnings].map { |w| w['code'] }
  end

  # Hmotnost cela, pri ktorej vyjde PRESNE zadane LF (pri `KH_LF`).
  def weight_for_lf(lf)
    lf / KH_LF - 0.5
  end

  # Trieda HK pri danom LF (KH je `KH_LF`).
  def hk_class(lf, over = {})
    res = evaluate([flap({ weight_kg: weight_for_lf(lf) }.merge(over))], 'kh' => KH_LF)
    lifts(res).first['params']['lift_class']
  end

  # Vysledok HL vyklopu: [lift_class, arm_class] alebo [nil, nil].
  def hl_class(kh, weight)
    res = evaluate([flap(lift_system: HR::LIFT_HL, weight_kg: weight)], 'kh' => kh)
    p = lifts(res).first['params']
    [p['lift_class'], p['arm_class']]
  end

  # --- sety a expanzia ----------------------------------------------------

  def seed_sets
    HWS.normalize_sets(HWS::SEED_SETS)
  end

  def state
    defs = {}
    seed_sets.each { |s| defs[s['set_id']] = s }
    { 'mapping' => HWS::SEED_MAPPING.merge(HWS::MAPPING_ADDITIONS), 'sets' => defs }
  end

  def buy(items)
    exp = HWS.expand(items, state)
    exp['rows'].each_with_object({}) { |r, out| out[r['code'].to_s] = r['quantity'] }
  end

  # --- config skrinky s vyklopom -------------------------------------------

  def cfg(front = {}, over = {})
    item = { 'id' => 'F1', 'type' => 'lift', 'mode' => 'auto' }.merge(front)
    CB.normalize({ 'type' => 'lower', 'width' => 600.0, 'height' => 400.0, 'depth' => 500.0,
                   'thickness' => 18.0, 'floor_height' => 0.0,
                   'fronts' => { 'items' => [item] } }.merge(over))
  end

  def plan(front = {}, over = {})
    CN.build_plan(cfg(front, over), 'CAB-1', hardware_rules: rules, materials: MAT)
  end

  def plan_lifts(pl)
    pl[:hardware].select { |h| h['generic_type'] == 'lift' }
  end

  # ULOZENY config skrinky s celom `flap`, ktora este nepozna pravidla vyklopov.
  # Codex #333 kolo 1 P1: proveniencie su DVE — schema configu A seed pravidiel,
  # s ktorym stavba bezala. Predvolena seed verzia je AKTUALNA, takze stare
  # volania (`stale_cfg(10)`) skusaju presne to, co skusali.
  def stale_cfg(schema, dir = HR::FLAP_UP, hardware = [],
                seed: HR::LIFT_SEED_VERSION, manual: [])
    { 'config_schema' => schema, 'rules_seed_version' => seed,
      'front_items' => [{ 'id' => 'F1', 'type' => (dir == HR::FLAP_UP ? 'lift' : 'fall'),
                          'flap_dir' => dir, 'height' => 396.0 }],
      'hardware' => hardware, 'hardware_manual' => manual }
  end

  # --- kody zo SEED SETOV (klasifikacia rucnych poloziek, Codex #333 kolo 2) -
  # Mechanizmus = PRVY clen `per: 'unit'`; ostatne kody su prislusenstvo.
  MECH_HK      = '347810' # AVENTOS HK top 22K2300 (set `vyklop-hk-klasik`)
  MECH_HK_TIP  = '347814' # HK top Tip-On 22K2300
  MECH_HL      = '507352' # AVENTOS HL top 22L2500
  MECH_HINGE   = '104717' # Sensys zaves (set `zaves-klasik`)
  MECH_HINGE_T = '245723' # zaves P2O (set `zaves-p2o`)
  ACC_COVER    = '347834' # krytky biele — clen setu, NIE mechanizmus
  ACC_ARMS     = '507357' # ramena HL 22L3800
  ACC_ROD      = '507365' # stabilizacna tyc
  ACC_TIPON    = '250831' # Tip-On jednotka

  # Model s (alebo bez) projektovym snapshotom pravidiel — LEN citanie.
  FAKE_MODEL = Struct.new(:doc) do
    def get_attribute(_dict, _key, default = nil)
      doc.nil? ? default : doc
    end
  end

  def model_with(doc)
    FAKE_MODEL.new(doc.nil? ? nil : JSON.generate(doc))
  end

  # Rucna (ad-hoc) polozka kovania pripnuta na celo F1.
  def manual_rec(source: 'catalog', code: MECH_HK, owner: 'front:F1/flap')
    { 'id' => 'M1', 'owner_part_key' => owner, 'source' => source, 'code' => code,
      'name' => 'AVENTOS HK top', 'unit' => 'ks', 'qty' => 1 }
  end
end

# ============================================================================
# 1 — HK TOP: LF A TABULKA TRIED
# ============================================================================

NxTest.test('KOV-E1b (1): LF = KH × (hmotnosť + rezerva) — hranice tabuľky HK top') do
  c = NxKovE1b
  # Sebakontrola fixtury: hmotnost sa da nastavit na PRESNE LF (bez Float sumu).
  [419.9, 420.0, 1610.0, 1610.5, 9000.5].each do |lf|
    NxTest.assert_equal(lf, (c.weight_for_lf(lf) + 0.5) * c::KH_LF, "fixtúra dá presne LF #{lf}")
  end
  { 420.0 => '22K2300', 1610.0 => '22K2300', 1610.5 => '22K2500', 1730.0 => '22K2500',
    2800.0 => '22K2500', 2800.5 => '22K2700', 5200.0 => '22K2700', 5200.5 => '22K2900',
    9000.0 => '22K2900' }.each do |lf, want|
    NxTest.assert_equal(want, c.hk_class(lf), "LF #{lf} -> #{want}")
  end
end

NxTest.test('KOV-E1b (1): v prekryve tried vyhráva NAJSLABŠIA, ktorá LF pokrýva') do
  c = NxKovE1b
  # LF 2000 pokryva 22K2500 (930–2800) aj 22K2700 (1730–5200) — berie sa slabsia.
  NxTest.assert_equal('22K2500', c.hk_class(2000.0))
  NxTest.assert_equal('22K2700', c.hk_class(4000.0), 'LF 4000 pokrýva 2700 aj 2900')
end

NxTest.test('KOV-E1b (1): LF nad tabuľkou = RED, pod tabuľkou = ORANGE + najslabšia trieda') do
  c = NxKovE1b
  over = c.evaluate([c.flap(weight_kg: c.weight_for_lf(9000.5))], 'kh' => c::KH_LF)
  NxTest.assert_equal(1, c.lifts(over).length, 'položka sa VYDÁ aj pri RED (riadok v Kovaní)')
  NxTest.assert_equal(nil, c.lifts(over).first['params']['lift_class'], 'ale bez triedy')
  NxTest.assert_equal([c::HR::LIFT_CLASS_MISSING], c.codes(over))
  NxTest.assert(over[:conflicts].first['message'].include?('9000'), over[:conflicts].first['message'])

  light = c.evaluate([c.flap(weight_kg: c.weight_for_lf(419.9))], 'kh' => c::KH_LF)
  NxTest.assert_equal('22K2300', c.lifts(light).first['params']['lift_class'],
                      'pod tabuľkou dostane NAJSLABŠIU triedu')
  NxTest.assert_equal([], c.codes(light), 'a je to len ORANGE, nie stopka')
  NxTest.assert(c.warn_codes(light).include?('lift_light_front'), c.warn_codes(light).inspect)
  NxTest.refute(c.warn_codes(c.evaluate([c.flap(weight_kg: c.weight_for_lf(420.0))],
                                        'kh' => c::KH_LF)).include?('lift_light_front'),
                'LF 420 je EŠTE v tabuľke')
end

NxTest.test('KOV-E1b (1): rezerva na úchytku sa počíta pri HK top') do
  c = NxKovE1b
  rule = c.lift_rule
  NxTest.assert_equal(0.5, rule['handle_allowance_kg'])
  # Bez rezervy by 3,0 kg pri KH 512 dalo LF 1536 (22K2300); s rezervou 1792.
  NxTest.assert_equal('22K2500', c.hk_class(1792.0))
  NxTest.assert_equal(3.0, c.weight_for_lf(1792.0), 'kontrola: je to naozaj 3 kg čelo')
end

# ============================================================================
# 2 — HL TOP: MECHANIZMUS A RAMENA
# ============================================================================

NxTest.test('KOV-E1b (2): mechanizmus HL top podľa KH (hranica 389 / 390)') do
  c = NxKovE1b
  NxTest.assert_equal(%w[22L2200 22L3500], c.hl_class(389.0, 3.0))
  NxTest.assert_equal(%w[22L2500 22L3800], c.hl_class(390.0, 3.0))
end

NxTest.test('KOV-E1b (2): ramená HL top sú SPOJITÉ — 339,5 ani 389,5 nespadnú do medzery') do
  c = NxKovE1b
  { 300.0 => '22L3200', 339.5 => '22L3200', 339.9 => '22L3200',
    340.0 => '22L3500', 389.5 => '22L3500', 390.0 => '22L3800',
    540.0 => '22L3800', 540.5 => '22L3900', 580.0 => '22L3900' }.each do |kh, want|
    NxTest.assert_equal(want, c.hl_class(kh, 3.0).last, "KH #{kh} -> #{want}")
  end
end

NxTest.test('KOV-E1b (2): KH mimo tabuľky HL = RED, položka bez triedy') do
  c = NxKovE1b
  [299.0, 581.0].each do |kh|
    res = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, weight_kg: 3.0)], 'kh' => kh)
    NxTest.assert_equal(1, c.lifts(res).length, "KH #{kh}: položka existuje")
    NxTest.assert_equal(nil, c.lifts(res).first['params']['lift_class'], "KH #{kh}: bez triedy")
    NxTest.assert(c.codes(res).include?(c::HR::LIFT_CLASS_MISSING), c.codes(res).inspect)
  end
  NxTest.assert_equal(%w[22L2200 22L3200], c.hl_class(300.0, 3.0), 'KH 300 ešte áno')
end

NxTest.test('KOV-E1b (2): ramená podľa HMOTNOSTI VRÁTANE rezervy (9,00 / 9,01 pri KH 320)') do
  c = NxKovE1b
  # KH 320: JEDINE ramena 22L3200 (1,5–9 kg). 8,5 + 0,5 = 9,00 este ano.
  NxTest.assert_equal('22L3200', c.hl_class(320.0, 8.5).last)
  res = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, weight_kg: 8.51)], 'kh' => 320.0)
  NxTest.assert_equal(nil, c.lifts(res).first['params']['arm_class'],
                      '9,01 kg už žiadne ramená pri tejto výške nepokryjú')
  NxTest.assert(c.codes(res).include?(c::HR::LIFT_CLASS_MISSING))
  NxTest.assert(res[:conflicts].first['message'].include?('9'), res[:conflicts].first['message'])
end

NxTest.test('KOV-E1b (2): v prekryve KH vyhrávajú NAJSLABŠIE ramená, ktoré hmotnosť pokryjú') do
  c = NxKovE1b
  # KH 500: 22L3800 (2–12,25) aj 22L3900 (2,5–14).
  NxTest.assert_equal('22L3800', c.hl_class(500.0, 11.75).last, '12,25 kg ešte 3800')
  NxTest.assert_equal('22L3900', c.hl_class(500.0, 11.76).last, '12,26 kg už 3900')
  NxTest.assert_equal('22L3900', c.hl_class(500.0, 13.5).last, '14,00 kg ešte 3900')
  res = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, weight_kg: 13.51)], 'kh' => 500.0)
  NxTest.assert_equal(nil, c.lifts(res).first['params']['arm_class'], '14,01 kg je nad tabuľkou')
  NxTest.assert(c.codes(res).include?(c::HR::LIFT_CLASS_MISSING))
end

NxTest.test('KOV-E1b (2): príliš ľahké čelo pri HL = ORANGE + najslabšie ramená') do
  c = NxKovE1b
  res = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, weight_kg: 0.5)], 'kh' => 500.0)
  NxTest.assert_equal(%w[22L2500 22L3800], [c.lifts(res).first['params']['lift_class'],
                                            c.lifts(res).first['params']['arm_class']])
  NxTest.assert_equal([], c.codes(res), 'ľahké čelo nie je stopka')
  NxTest.assert(c.warn_codes(res).include?('lift_light_front'), c.warn_codes(res).inspect)
end

# ============================================================================
# 3 — STABILIZACNA TYC PODLA KB
# ============================================================================

NxTest.test('KOV-E1b (3): druhá tyč + predĺženie od šírky KORPUSU 1100 mm') do
  c = NxKovE1b
  low = c.lifts(c.evaluate([c.flap(lift_system: c::HR::LIFT_HL)], 'kb' => 1099.0)).first['params']
  NxTest.assert_equal([1, 0], [low['rod_count'], low['rod_extension']])
  hi = c.lifts(c.evaluate([c.flap(lift_system: c::HR::LIFT_HL)], 'kb' => 1100.0)).first['params']
  NxTest.assert_equal([2, 1], [hi['rod_count'], hi['rod_extension']])
  # Rozhoduje SIRKA KORPUSU, nie sirka cela (to je uzsie o medzery).
  wide = c.lifts(c.evaluate([c.flap(prod: { length: 396.0, width: 1096.0, thickness: 18.0 })],
                            'kb' => 1099.0)).first['params']
  NxTest.assert_equal(1, wide['rod_count'], 'čelo 1096 mm v korpuse 1099 mm = jedna tyč')
end

# ============================================================================
# 4 — KH JE VYSKA KORPUSU BEZ SOKLA
# ============================================================================

NxTest.test('KOV-E1b (4): KH je výška KORPUSU (400), nie výrobná dĺžka čela (396)') do
  c = NxKovE1b
  pl = c.plan('lift' => { 'system' => 'hl_top' })
  front = pl[:parts].find { |pd| pd[:role] == 'flap' }
  NxTest.assert(front[:prod][:length] < 400.0,
                "čelo je nižšie než korpus (#{front[:prod][:length]})")
  it = c.plan_lifts(pl).first
  # KH 400 -> mechanizmus 22L2500 a ramena 22L3800; KH 396 by dalo 22L2200 + 22L3500.
  NxTest.assert_equal('22L2500', it['params']['lift_class'], 'KH 400 = výška korpusu')
  NxTest.assert_equal('22L3800', it['params']['arm_class'])
end

NxTest.test('KOV-E1b (4): sokel sa od KH ODPOČÍTA') do
  c = NxKovE1b
  # Korpus 600 so soklom 200 => KH 400 (rovnaky vysledok ako 400 bez sokla).
  pl = c.plan({ 'lift' => { 'system' => 'hl_top' } },
              'height' => 600.0, 'floor_height' => 200.0)
  it = c.plan_lifts(pl).first
  NxTest.assert_equal(%w[22L2500 22L3800], [it['params']['lift_class'], it['params']['arm_class']],
                      'KH = 600 − 200; bez odpočtu sokla by to bolo iné pásmo')
end

# ============================================================================
# 5 — ELIGIBILITY
# ============================================================================

NxTest.test('KOV-E1b (5): rozmery mimo programu Blum = RED `lift_dimension_unsupported`') do
  c = NxKovE1b
  hk = c.lift_rule['eligibility']['hk_top']
  NxTest.assert_equal([205.0, 600.0, 1800.0], [hk['kh_min'], hk['kh_max'], hk['kb_max']])
  NxTest.assert_equal([], c.codes(c.evaluate([c.flap], 'kh' => 205.0)), 'KH 205 ešte áno')
  NxTest.assert_equal([c::HR::LIFT_DIMENSION_UNSUPPORTED],
                      c.codes(c.evaluate([c.flap], 'kh' => 204.0)), 'KH 204 už nie')
  NxTest.assert_equal([], c.codes(c.evaluate([c.flap], 'kb' => 1800.0)))
  wide = c.evaluate([c.flap], 'kb' => 1801.0)
  NxTest.assert_equal([c::HR::LIFT_DIMENSION_UNSUPPORTED], c.codes(wide))
  NxTest.assert_equal(1, c.lifts(wide).length, 'položka sa VYDÁ aj tak')
end

NxTest.test('KOV-E1b (5): hĺbka pre HL top ide z VNÚTORNEJ hĺbky (chrbát aj drážka)') do
  c = NxKovE1b
  hl = c.lift_rule['eligibility']['hl_top']
  NxTest.assert_equal(264.0, hl['depth_min'])
  ok = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL)], 'available_depth' => 264.0)
  NxTest.assert_equal([], c.codes(ok))
  bad = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL)], 'available_depth' => 263.0)
  NxTest.assert_equal([c::HR::LIFT_DIMENSION_UNSUPPORTED], c.codes(bad))
  NxTest.assert(bad[:conflicts].first['message'].include?('hĺbka'), bad[:conflicts].first['message'])
  # HK sa hlbka NETYKA (nema `depth_min`).
  NxTest.assert_equal([], c.codes(c.evaluate([c.flap], 'available_depth' => 200.0)))
end

NxTest.test('KOV-E1b (5): DRÁŽKOVANÝ chrbát sa do vnútornej hĺbky započíta (BLOCKER 1)') do
  c = NxKovE1b
  # `available_depth` je `Construction` interior `back_front_y` — ten uz drazku
  # aj overlay riesi. Sada to overuje na REALNOM plane pre vsetky rezimy chrbta.
  seen = {}
  %w[none inset groove overlay].each do |mode|
    pl = c.plan({ 'lift' => { 'system' => 'hl_top' } },
                'height' => 500.0, 'depth' => 275.0, 'back_mode' => mode)
    seen[mode] = pl[:available][:depth]
  end
  NxTest.assert(seen['none'] > seen['inset'], "chrbát hĺbku uberá: #{seen.inspect}")
  NxTest.assert(seen['groove'] < seen['none'], "drážkovaný chrbát tiež: #{seen.inspect}")
  # Pri hlbke 275 a drazkovanom chrbte je vnutorna hlbka POD 264 -> RED.
  pl = c.plan({ 'lift' => { 'system' => 'hl_top' } },
              'height' => 500.0, 'depth' => 275.0, 'back_mode' => 'groove')
  NxTest.assert(pl[:available][:depth] < 264.0, "vnútorná hĺbka #{pl[:available][:depth]}")
  NxTest.assert(Array(pl[:hardware_conflicts]).map { |x| x['code'] }
                     .include?(c::HR::LIFT_DIMENSION_UNSUPPORTED),
                Array(pl[:hardware_conflicts]).inspect)
end

# ============================================================================
# 6 — TVRDE STAVY (POLOZKA SA VZDY VYDA)
# ============================================================================

NxTest.test('KOV-E1b (6): bez hmotnosti sa trieda NEDÁ určiť = RED') do
  c = NxKovE1b
  res = c.evaluate([c.flap(weight_kg: nil)])
  NxTest.assert_equal(1, c.lifts(res).length)
  NxTest.assert_equal(nil, c.lifts(res).first['params']['lift_class'])
  NxTest.assert_equal([c::HR::LIFT_CLASS_MISSING], c.codes(res))
  NxTest.assert(res[:conflicts].first['message'].include?('hmotnosť'),
                res[:conflicts].first['message'])
end

NxTest.test('KOV-E1b (6): HL top + Tip-On = RED `lift_combo_unsupported`') do
  c = NxKovE1b
  res = c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, opening_mode: 'tipon')])
  NxTest.assert_equal([c::HR::LIFT_COMBO_UNSUPPORTED], c.codes(res))
  NxTest.assert_equal(1, c.lifts(res).length, 'položka existuje (riadok v Kovaní)')
  # HK + Tip-On je bezny stav.
  NxTest.assert_equal([], c.codes(c.evaluate([c.flap(opening_mode: 'tipon')])))
  NxTest.assert_equal('tipon', c.lifts(c.evaluate([c.flap(opening_mode: 'tipon')]))
                                .first['params']['opening_mode'])
end

NxTest.test('KOV-E1b (6): výklop vo VIACRIADKOVEJ skrinke = RED `lift_multirow_unsupported`') do
  c = NxKovE1b
  NxTest.assert_equal([], c.codes(c.evaluate([c.flap], 'front_rows' => 1)))
  res = c.evaluate([c.flap], 'front_rows' => 2)
  NxTest.assert_equal([c::HR::LIFT_MULTIROW_UNSUPPORTED], c.codes(res))
  NxTest.assert(res[:conflicts].first['message'].include?('samostatnú skrinku'),
                res[:conflicts].first['message'])
end

# ============================================================================
# 7 — SKLOP DOSTANE ZAVESY
# ============================================================================

NxTest.test('KOV-E1b (7): sklop dostane ZÁVESY ako dvierka a NIKDY výklopový mechanizmus') do
  c = NxKovE1b
  res = c.evaluate([c.flap(flap_dir: c::HR::FLAP_DOWN, name: 'Sklop 1')])
  NxTest.assert_equal([], c.lifts(res), 'sklop nikdy nevydá `lift`')
  h = c.hinges(res)
  NxTest.assert_equal(1, h.length, "sklop dostane závesy (#{res[:items].inspect})")
  NxTest.assert_equal(c::FALL_RULE, h.first['rule_id'])
  NxTest.assert_equal('door', h.first['params']['use_type'], 'set si hľadá triednym kľúčom dvierok')
  NxTest.assert_equal('classic', h.first['params']['opening_mode'])
end

NxTest.test('KOV-E1b (7): výklop NIKDY nedostane závesy') do
  c = NxKovE1b
  res = c.evaluate([c.flap])
  NxTest.assert_equal([], c.hinges(res), "výklop nedostane hinge (#{res[:items].inspect})")
  NxTest.assert_equal(1, c.lifts(res).length)
end

NxTest.test('KOV-E1b (7): „nemá to byť výklop?" sa na SKLOP neuplatní') do
  c = NxKovE1b
  # Sirsie nez vyssie je pri sklope NORMA.
  res = c.evaluate([c.flap(flap_dir: c::HR::FLAP_DOWN,
                           prod: { length: 300.0, width: 596.0, thickness: 18.0 })])
  NxTest.refute(c.warn_codes(res).include?('door_wider_than_high'), c.warn_codes(res).inspect)
  NxTest.assert(res[:warnings].none? { |w| w['message'].to_s.include?('Dvierka') },
                'a hláška sklop nevolá „Dvierka"')
end

NxTest.test('KOV-E1b (7): deskriptor BEZ smeru nedostane ani výklop, ani sklop') do
  c = NxKovE1b
  # Legacy plan (cudzi volajuci bez anotacie) — smer sa NIKDY nehada.
  res = c.evaluate([c.flap(flap_dir: nil)])
  NxTest.assert_equal([], c.lifts(res))
  NxTest.assert_equal([], c.hinges(res))
end

# ============================================================================
# 8 — PREKRYV PODLA SMERU
# ============================================================================

NxTest.test('KOV-E1b (8): seed sa NEDOPLNÍ, keď ten istý SMER už obsluhuje iné pravidlo') do
  c = NxKovE1b
  own_up = { 'rule_id' => 'moj-vyklop', 'enabled' => true, 'output' => 'lift',
             'kind' => 'lift_class', 'applies_to' => { 'role' => 'flap', 'flap_dir' => 'up' } }
  add = c::HR.seed_additions(c::HR.normalize_rules([own_up]), {}).map { |r| r['rule_id'] }
  NxTest.refute(add.include?(c::LIFT_RULE), "vlastný výklop seed potlačí: #{add.inspect}")
  NxTest.assert(add.include?(c::FALL_RULE), 'sklop sa doplní ďalej')

  own_down = own_up.merge('rule_id' => 'moje-vzpery',
                          'applies_to' => { 'role' => 'flap', 'flap_dir' => 'down' })
  add2 = c::HR.seed_additions(c::HR.normalize_rules([own_down]), {}).map { |r| r['rule_id'] }
  NxTest.assert(add2.include?(c::LIFT_RULE),
                "pravidlo len pre `down` seed výklopov NEPOTLAČÍ: #{add2.inspect}")
end

NxTest.test('KOV-E1b (8): RUNTIME prekryv sa pýta na (výstup, rola, SMER)') do
  c = NxKovE1b
  # Skorsie `hinge` pravidlo pre `flap/up` NESMIE potlacit `zavesy-sklop`.
  mine = { 'rule_id' => 'moje-zavesy-vyklopu', 'enabled' => true, 'output' => 'hinge',
           'kind' => 'bands', 'input' => 'height',
           'applies_to' => { 'role' => 'flap', 'flap_dir' => 'up' },
           'bands' => [{ 'max' => nil, 'quantity' => 2 }] }
  rules = c::HR.normalize_rules([mine] + c::HR::SEED_RULES)
  res = c.evaluate([c.flap(flap_dir: c::HR::FLAP_DOWN)], {}, {}, rules)
  NxTest.assert_equal([c::FALL_RULE], c.hinges(res).map { |h| h['rule_id'] },
                      "sklop dostane závesy zo seedu (#{res[:warnings].map { |w| w['code'] }.inspect})")
end

NxTest.test('KOV-E1b (8): DVE `lift` pravidlá = JEDNA položka + ORANGE `hardware_rule_overlap`') do
  c = NxKovE1b
  second = JSON.parse(JSON.generate(c.lift_rule)).merge('rule_id' => 'moj-vyklop')
  rules = c::HR.normalize_rules([c.lift_rule, second])
  res = c.evaluate([c.flap], {}, {}, rules)
  NxTest.assert_equal(1, c.lifts(res).length, 'dvojitý mechanizmus by nikto nezbadal')
  NxTest.assert_equal(c::LIFT_RULE, c.lifts(res).first['rule_id'], 'použije sa PRVÉ pravidlo')
  w = res[:warnings].find { |x| x['code'] == 'hardware_rule_overlap' }
  NxTest.assert(w, c.warn_codes(res).inspect)
  NxTest.assert(w['message'].include?('výklopov'), w['message'])
end

NxTest.test('KOV-E1b (8): pravidlo BEZ filtra smeru sa prekrýva s OBOMA smermi') do
  c = NxKovE1b
  wild = JSON.parse(JSON.generate(c.lift_rule))
             .merge('rule_id' => 'vsetky-flap', 'applies_to' => { 'role' => 'flap' })
  rules = c::HR.normalize_rules([wild, c.lift_rule])
  res = c.evaluate([c.flap], {}, {}, rules)
  NxTest.assert_equal(['vsetky-flap'], c.lifts(res).map { |it| it['rule_id'] })
  NxTest.assert(c.warn_codes(res).include?('hardware_rule_overlap'))
end

NxTest.test('KOV-E1b (8): `zavesy-sklop` a `zavesy-podla-vysky` sa NEPREKRÝVAJÚ (iné roly)') do
  c = NxKovE1b
  res = c.evaluate([c.flap(flap_dir: c::HR::FLAP_DOWN)])
  NxTest.refute(c.warn_codes(res).include?('hardware_rule_overlap'), c.warn_codes(res).inspect)
  NxTest.assert_equal([], c::HR.seed_additions(c.rules, c.rules.each_with_object({}) do |r, h|
    h[r['rule_id']] = true
  end), 'kompletný seed sa sám o seba nezakopne')
end

# ============================================================================
# 9 — OVERRIDY (PLNY AUTOMAT)
# ============================================================================

NxTest.test('KOV-E1b (9): ručný zásah na SEED výklope sa IGNORUJE + ORANGE') do
  c = NxKovE1b
  ov = [{ 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'lift',
          'rule_id' => c::LIFT_RULE, 'disabled' => true }]
  res = c.evaluate([c.flap], {}, { hardware_overrides: ov })
  NxTest.assert_equal(1, c.lifts(res).length, 'výklop sa vypnúť nedá — je to zostava')
  NxTest.assert_equal('rule', c.lifts(res).first['source'])
  NxTest.assert(c.warn_codes(res).include?('lift_override_ignored'), c.warn_codes(res).inspect)

  qty = [{ 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'lift',
           'rule_id' => c::LIFT_RULE, 'quantity' => 5 }]
  res2 = c.evaluate([c.flap], {}, { hardware_overrides: qty })
  NxTest.assert_equal(1, c.lifts(res2).first['quantity'], 'ani ručný počet')
end

NxTest.test('KOV-E1b (9): na VLASTNOM `lift` pravidle override ostáva ÚČINNÝ') do
  c = NxKovE1b
  mine = JSON.parse(JSON.generate(c.lift_rule)).merge('rule_id' => 'moj-vyklop')
  ov = [{ 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'lift',
          'rule_id' => 'moj-vyklop', 'disabled' => true }]
  res = c.evaluate([c.flap], {}, { hardware_overrides: ov }, c::HR.normalize_rules([mine]))
  NxTest.assert_equal([], c.lifts(res), 'vlastné pravidlo si používateľ vypnúť smie')
  NxTest.refute(c.warn_codes(res).include?('lift_override_ignored'))
end

NxTest.test('KOV-E1b (9): normalizácia configu neplatný zásah SEED výklopu VYČISTÍ') do
  c = NxKovE1b
  cfg = c::CB.normalize('width' => 600.0, 'height' => 400.0, 'depth' => 500.0,
                        'hardware_overrides' => [
                          { 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'lift',
                            'rule_id' => c::LIFT_RULE, 'disabled' => true },
                          { 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'lift',
                            'rule_id' => 'moj-vyklop', 'quantity' => 2 }
                        ])
  ids = Array(cfg[:hardware_overrides]).map { |o| o['rule_id'] }
  NxTest.assert_equal(['moj-vyklop'], ids, "zostal len zásah vlastného pravidla (#{ids.inspect})")
end

# ============================================================================
# 10 — CONFIG CELA `lift.system`
# ============================================================================

NxTest.test('KOV-E1b (10): `lift.system` prežije normalizáciu a je DORMANT') do
  c = NxKovE1b
  out = c::FR.normalize_items([{ 'id' => 'F1', 'type' => 'lift',
                                 'lift' => { 'system' => 'hl_top' } }]).first
  NxTest.assert_equal({ 'system' => 'hl_top' }, out['lift'])
  # Neznama hodnota sa NEHADA — kluc vypadne a citac plati `hk_top`.
  bad = c::FR.normalize_items([{ 'id' => 'F1', 'type' => 'lift',
                                 'lift' => { 'system' => 'xx' } }]).first
  NxTest.assert_equal({ 'system' => 'hk_top' }, bad['lift'], 'nový zápis hodnotu VŽDY uloží')
  # Dormant: prepnutie na dvierka a spat system NEZAHODI.
  door = c::FR.normalize_items([{ 'id' => 'F1', 'type' => 'door',
                                  'lift' => { 'system' => 'hl_top' } }]).first
  NxTest.assert_equal({ 'system' => 'hl_top' }, door['lift'])
  NxTest.assert(c::FR::DORMANT_KEYS.include?('lift'), 'a je to DORMANT kľúč')
end

NxTest.test('KOV-E1b (10): `layout` premietne systém do resolved čela vedľa `flap_dir`') do
  c = NxKovE1b
  res = c::FR.layout({ 'items' => [{ 'id' => 'F1', 'type' => 'lift',
                                     'lift' => { 'system' => 'hl_top' } }] },
                     600.0, 720.0, 100.0, 18.0)
  it = res[:items].first
  NxTest.assert_equal('up', it['flap_dir'])
  NxTest.assert_equal('hl_top', it['lift_system'])
  # Sklop system NEMA (dostane zavesy).
  fall = c::FR.layout({ 'items' => [{ 'id' => 'F1', 'type' => 'fall' }] },
                      600.0, 720.0, 100.0, 18.0)[:items].first
  NxTest.assert_equal('down', fall['flap_dir'])
  NxTest.assert_equal(nil, fall['lift_system'])
end

NxTest.test('KOV-E1b (10): HL top prežije stavbu aj „reopen" (config → plán → config)') do
  c = NxKovE1b
  cfg = c.cfg('lift' => { 'system' => 'hl_top' })
  NxTest.assert_equal({ 'system' => 'hl_top' }, cfg[:fronts]['items'].first['lift'])
  pl = c.plan('lift' => { 'system' => 'hl_top' })
  NxTest.assert_equal('hl_top', c.plan_lifts(pl).first['params']['lift_system'])
  # „Reopen": ulozeny config -> params -> normalize (to iste, co robi prestavba).
  saved = c::CB.cabinet_config(cfg)
  again = c::CB.normalize(c::CB.config_to_params(JSON.parse(JSON.generate(saved))))
  NxTest.assert_equal({ 'system' => 'hl_top' }, again[:fronts]['items'].first['lift'],
                      'bez toho by prestavba ticho spadla na HK')
  NxTest.assert_equal(11, c::CB::CONFIG_SCHEMA, 'a schéma si to vyžiadala')
end

NxTest.test('KOV-E1b (10): deskriptor nesie `flap_dir` aj `lift_system` explicitne') do
  c = NxKovE1b
  pl = c.plan('lift' => { 'system' => 'hl_top' })
  pd = pl[:parts].find { |x| x[:role] == 'flap' }
  NxTest.assert_equal('up', pd[:flap_dir])
  NxTest.assert_equal('hl_top', pd[:lift_system])
end

# ============================================================================
# 11 — `flap_stale`
# ============================================================================

NxTest.test('KOV-E1b (11): skrinka spred pravidiel výklopov = RED `flap_stale`') do
  c = NxKovE1b
  NxTest.assert_equal(11, c::CB::LIFT_ACTIVATION_SCHEMA, 'aktivácia je VLASTNÁ konštanta')
  iss = c::BOM.flap_stale_issue('CAB-5', 7, c.stale_cfg(c::CB::LIFT_ACTIVATION_SCHEMA - 1))
  NxTest.assert(iss, 'skrinka schémy 10 s výklopom = nález')
  NxTest.assert_equal(c::BP::FLAP_STALE, iss['code'])
  NxTest.assert_equal('red', iss['severity'])
  NxTest.assert_equal('front:F1/flap', iss['part_key'])
  NxTest.assert(iss['message'].include?('Doplniť nové predvoľby'), iss['message'])

  down = c::BOM.flap_stale_issue('CAB-5', 7,
                                 c.stale_cfg(c::CB::LIFT_ACTIVATION_SCHEMA - 1, c::HR::FLAP_DOWN))
  NxTest.assert(down, 'a platí aj pre SKLOP')
  NxTest.assert(down['message'].include?('sklop'), down['message'])
end

NxTest.test('KOV-E1b (11): rozhoduje PROVENIENCIA stavby, nie pravidlá projektu') do
  c = NxKovE1b
  # Prestavana skrinka (schema 11 A seed 5) NIE JE stale NIKDY — ani ked vyklop
  # kovanie nedostal (vypnute vlastne pravidlo je rozhodnutie pouzivatela).
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7,
                                                   c.stale_cfg(c::CB::LIFT_ACTIVATION_SCHEMA)))
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7,
                                                   c.stale_cfg(c::CB::CONFIG_SCHEMA)))
  # Stara skrinka, ktora polozku UZ MA (kopia z novsieho pluginu), tiez nie.
  hw = [{ 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'lift',
          'quantity' => 1, 'rule_id' => c::LIFT_RULE, 'params' => {} }]
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7,
                                                   c.stale_cfg(10, c::HR::FLAP_UP, hw)))
  # Sklop so zavesmi dvierok tiez nie.
  hinge = [{ 'owner_part_key' => 'front:F1/flap', 'generic_type' => 'hinge',
             'quantity' => 2, 'rule_id' => c::FALL_RULE,
             'params' => { 'use_type' => 'door' } }]
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7,
                                                   c.stale_cfg(10, c::HR::FLAP_DOWN, hinge)))
  # Skrinka BEZ cela `flap` nalez nerobi.
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7,
                                                   { 'config_schema' => 9,
                                                     'front_items' => [{ 'id' => 'F1',
                                                                         'type' => 'door' }],
                                                     'hardware' => [] }))
end

# --- Codex #333 kolo 1 P1: druha proveniencia = SEED PRAVIDIEL -------------
NxTest.test('KOV-E1b (11): prestavba so STARYM snapshotom pravidiel RED NEZHASNE') do
  c = NxKovE1b
  NxTest.assert_equal(5, c::HR::LIFT_SEED_VERSION, 'hranica je VLASTNÁ konštanta')
  # Východisko: stará skrinka (schéma 10), zákazka má snapshot pravidiel spred
  # E1b (seed 4).
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, c.stale_cfg(10, c::HR::FLAP_UP, [], seed: 4)),
                'schéma 10 + seed 4 = RED')
  # PRESTAVBA so starým snapshotom: `ensure_project_rules!` vráti pôvodné
  # pravidlá, takže výklop ZASE nedostane nič — ale config už nesie schému 11.
  # Bez druhej proveniencie by tu RED zhasol nad zákazkou BEZ mechanizmu.
  reb = c.stale_cfg(c::CB::CONFIG_SCHEMA, c::HR::FLAP_UP, [], seed: 4)
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, reb),
                'schéma 11, ale seed 4 — RED ostáva (M21)')
  # To isté pre SKLOP.
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7,
                                        c.stale_cfg(c::CB::CONFIG_SCHEMA, c::HR::FLAP_DOWN, [],
                                                    seed: 4)),
                'a rovnako pre sklop')
  # Config spred tejto opravy kľúč vôbec nemá = 0, teda „nevieme" -> RED.
  no_key = c.stale_cfg(c::CB::CONFIG_SCHEMA)
  no_key.delete('rules_seed_version')
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, no_key), 'chýbajúci kľúč je najstarší seed')
  # Až „Doplniť nové predvoľby" (snapshot na seed 5) + PRESTAVBA zhasnú RED.
  NxTest.assert_equal(nil,
                      c::BOM.flap_stale_issue('CAB-5', 7,
                                              c.stale_cfg(c::CB::CONFIG_SCHEMA, c::HR::FLAP_UP, [],
                                                          seed: 5)),
                      'schéma 11 + seed 5 = hotovo')
  # A stále platí FIX 4: rozhoduje VERZIA snapshotu, nie prítomnosť seed
  # pravidiel — vedome vypnuté vlastné pravidlo v snapshote seed 5 falošnú
  # červenú nerobí.
  NxTest.assert_equal(nil,
                      c::BOM.flap_stale_issue('CAB-5', 7,
                                              c.stale_cfg(c::CB::CONFIG_SCHEMA, c::HR::FLAP_DOWN, [],
                                                          seed: 9)),
                      'novší seed tiež nie je zaostalosť')
end

NxTest.test('KOV-E1b (11): `effective_seed_version` je proveniencia stavby') do
  c = NxKovE1b
  NxTest.assert(c::HR.respond_to?(:effective_seed_version), 'funkcia existuje')
  # Projektový snapshot rozhoduje (aj keď je starší než knižnica).
  model = c.model_with('std' => c::HR::STD, 'seed_version' => 4, 'rules' => [])
  NxTest.assert_equal(4, c::HR.effective_seed_version(model), 'zo snapshotu projektu')
  # Chýbajúci kľúč `seed_version` v snapshote = najstarší seed.
  model2 = c.model_with('std' => c::HR::STD, 'rules' => [])
  NxTest.assert_equal(0, c::HR.effective_seed_version(model2), 'bez kľúča = 0')
  # Bez snapshotu sa dedí knižnica — tú čítanie MIGRUJE, takže je to náš seed.
  NxTest.assert_equal(c::HR::SEED_VERSION, c::HR.effective_seed_version(c.model_with(nil)),
                      'projekt bez snapshotu dedí knižnicu')
end

# --- Codex #333 kolo 2 P1: UPLNA rucna zostava na vyklope ------------------
NxTest.test('KOV-E1b (11): `flap_stale` zhasne LEN úplná ručná zostava') do
  c = NxKovE1b
  # Skrinka schemy 10, ktorej vyklop ma MECHANIZMUS pridany RUCNE (kanal
  # `hardware_manual`). Bez tejto vetvy by ju brana hnala do prestavby, ta by
  # k rucnej polozke pridala automaticku zostavu a nakup by ten isty kod
  # zratal DVAKRAT (`add_adhoc_row` scitava rovnake kody).
  cfg = c.stale_cfg(10, c::HR::FLAP_UP, [], manual: [c.manual_rec])
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7, cfg), 'M22')
  # Rucna polozka INEHO cela branu nezhasne.
  other = c.stale_cfg(10, c::HR::FLAP_UP, [],
                      manual: [c.manual_rec(owner: 'front:F9/flap')])
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, other), 'cudzie čelo nález nezhasí')
  # PRISLUSENSTVO (krytka, ramena, tyc, Tip-On) zostavu NETVORI — bez
  # mechanizmu je celo stale UPLNE BEZ kovania a RED musí ostať (M25).
  [c::ACC_COVER, c::ACC_ARMS, c::ACC_ROD, c::ACC_TIPON].each do |code|
    acc = c.stale_cfg(10, c::HR::FLAP_UP, [], manual: [c.manual_rec(code: code)])
    NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, acc), "#{code} nie je zostava")
  end
  # Neznamy kod, VOLNA polozka a zaznam bez kodu tiez nie.
  [c.manual_rec(code: 'NEEXISTUJE'), c.manual_rec(source: 'free'),
   c.manual_rec(code: '')].each do |rec|
    cfg2 = c.stale_cfg(10, c::HR::FLAP_UP, [], manual: [rec])
    NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, cfg2), rec.inspect)
  end
  # DRUH musí sedieť so SMEROM: ručný ZÁVES na výklope HORE mechanizmus
  # nenahradí (M26) a naopak výklopový mechanizmus na sklope tiež nie.
  up_hinge = c.stale_cfg(10, c::HR::FLAP_UP, [], manual: [c.manual_rec(code: c::MECH_HINGE)])
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, up_hinge), 'záves výklop hore nezhasí')
  down_lift = c.stale_cfg(10, c::HR::FLAP_DOWN, [], manual: [c.manual_rec])
  NxTest.assert(c::BOM.flap_stale_issue('CAB-5', 7, down_lift), 'mechanizmus sklop nezhasí')
  # SKLOP zhasne ručný ZÁVES (oba seed sety).
  [c::MECH_HINGE, c::MECH_HINGE_T].each do |code|
    down = c.stale_cfg(10, c::HR::FLAP_DOWN, [], manual: [c.manual_rec(code: code)])
    NxTest.assert_equal(nil, c::BOM.flap_stale_issue('CAB-5', 7, down), "sklop + #{code}")
  end
end

NxTest.test('KOV-E1b (11): pri ručnom kovaní sa AUTOMAT vynechá (nikdy sčítanie oboch)') do
  c = NxKovE1b
  owner = 'front:F1/flap'
  # (a) VYKLOP s rucnym vyklopovym kovanim: polozka NEVZNIKNE + ORANGE.
  res = c.evaluate([c.flap], {}, {}, nil, owner => { 'lift' => true })
  NxTest.assert_equal([], c.lifts(res), 'automatický mechanizmus sa nevydal (M23)')
  w = res[:warnings].find { |x| x['code'] == 'flap_manual_hardware' }
  NxTest.assert(w, "ORANGE priznanie (#{c.warn_codes(res).inspect})")
  NxTest.assert_equal(owner, w['part_key'])
  NxTest.assert(w['message'].include?('RUČNE'), w['message'])
  NxTest.assert(w['message'].include?('dvakrát'), w['message'])
  # (b) RUCNY ZAVES na vyklope automat NEZASTAVI — je to iný druh kovania.
  res2 = c.evaluate([c.flap], {}, {}, nil, owner => { 'hinge' => true })
  NxTest.assert_equal(1, c.lifts(res2).length, 'iný druh ručnej položky automat nevypína')
  NxTest.refute(c.warn_codes(res2).include?('flap_manual_hardware'))
  # (c) SKLOP s rucnymi zavesmi: zavesy sklopu sa nevydaju + ORANGE „Sklop".
  fall = c.flap(flap_dir: c::HR::FLAP_DOWN, name: 'Sklop 1')
  res3 = c.evaluate([fall], {}, {}, nil, owner => { 'hinge' => true })
  NxTest.assert_equal([], c.hinges(res3), 'závesy sklopu sa nevydali')
  w3 = res3[:warnings].find { |x| x['code'] == 'flap_manual_hardware' }
  NxTest.assert(w3 && w3['message'].include?('Sklop'), w3.inspect)
  # (d) DVIERKA sa tým NEMENIA (F1 ostáva bajtovo rovnaké): ručný záves na
  #     dvierkach automat NEVYPÍNA — potlačenie je úzko len pre rolu `flap`.
  res4 = c.evaluate([c.door], {}, {}, nil,
                    'front:F2/wing:single' => { 'hinge' => true })
  NxTest.assert(c.hinges(res4).length.positive?, 'dvierka dostanú závesy ako doteraz')
  NxTest.refute(c.warn_codes(res4).include?('flap_manual_hardware'))
  # (e) Po ODSTRANENI rucnej polozky sa automat vrati.
  NxTest.assert_equal(1, c.lifts(c.evaluate([c.flap])).length, 'bez ručnej položky = automat')
end

NxTest.test('KOV-E1b (11): úplnú ručnú zostavu tvorí MECHANIZMUS, nie príslušenstvo') do
  c = NxKovE1b
  cfg = { hardware_manual: [
    { 'owner_part_key' => 'front:F1/flap', 'source' => 'catalog', 'code' => c::MECH_HK, 'qty' => 1 },
    { 'owner_part_key' => 'front:F2/flap', 'source' => 'catalog', 'code' => c::MECH_HINGE, 'qty' => 1 },
    # krytka je v TOM ISTOM sete (a v katalógu v kategórii VYKLOPY) — zostavu
    # netvorí, automat na tom čele beží ďalej aj s bránami (M24)
    { 'owner_part_key' => 'front:F3/flap', 'source' => 'catalog', 'code' => c::ACC_COVER, 'qty' => 1 },
    { 'owner_part_key' => 'front:F4/flap', 'source' => 'catalog', 'code' => 'NEEXISTUJE', 'qty' => 1 },
    # voľná položka nemá katalógový kód — v nákupe je vlastným riadkom, takže
    # sa s automatom nikdy nezlieva a automat sa kvôli nej nevypína
    { 'owner_part_key' => 'front:F5/flap', 'source' => 'free', 'code' => c::MECH_HK, 'qty' => 1 },
    # Tip-On, ramená a tyč sú tiež len príslušenstvo
    { 'owner_part_key' => 'front:F6/flap', 'source' => 'catalog', 'code' => c::ACC_TIPON, 'qty' => 1 }
  ] }
  map = c::CB.manual_flap_owners(cfg)
  NxTest.assert_equal({ 'lift' => true }, map['front:F1/flap'])
  NxTest.assert_equal({ 'hinge' => true }, map['front:F2/flap'])
  %w[front:F3/flap front:F4/flap front:F5/flap front:F6/flap].each do |owner|
    NxTest.assert_equal(nil, map[owner], "#{owner} zostavu netvorí")
  end
  NxTest.assert_equal({}, c::CB.manual_flap_owners(hardware_manual: []), 'bez položiek prázdna mapa')
  # Tip-On mechanizmus (iný set, iný kód) zostavu TVORÍ.
  tip = { hardware_manual: [{ 'owner_part_key' => 'front:F1/flap', 'source' => 'catalog',
                              'code' => c::MECH_HK_TIP, 'qty' => 1 }] }
  NxTest.assert_equal({ 'lift' => true }, c::CB.manual_flap_owners(tip)['front:F1/flap'])
  # A HL mechanizmus tiež.
  hl = { hardware_manual: [{ 'owner_part_key' => 'front:F1/flap', 'source' => 'catalog',
                             'code' => c::MECH_HL, 'qty' => 1 }] }
  NxTest.assert_equal({ 'lift' => true }, c::CB.manual_flap_owners(hl)['front:F1/flap'])
end

NxTest.test('KOV-E1b (11): mechanizmy sa čítajú aj z POUŽÍVATEĽSKÝCH setov snapshotu') do
  c = NxKovE1b
  # Seed sám o sebe kód `X-MECH` nepozná.
  seed = c::HWS.flap_set_codes
  NxTest.assert(seed['lift']['mechanism'][c::MECH_HK], 'seed pozná HK mechanizmus')
  NxTest.assert(seed['lift']['members'][c::ACC_COVER], 'krytka je členom setu')
  NxTest.refute(seed['lift']['mechanism'][c::ACC_COVER], 'krytka NIE JE mechanizmus')
  NxTest.refute(seed['lift']['mechanism']['X-MECH'])
  # Projektový snapshot s VLASTNÝM výklopovým setom: prvý `per: 'unit'` člen
  # je mechanizmus, druhý (ramená) už nie.
  state = { 'mapping' => {},
            'sets' => { 'moj-vyklop' => {
              'set_id' => 'moj-vyklop', 'generic_type' => 'lift', 'use_type' => 'lift',
              'members' => [{ 'code' => 'X-MECH', 'per' => 'unit', 'qty' => 1 },
                            { 'code' => 'X-ARM', 'per' => 'unit', 'qty' => 1 }]
            } } }
  codes = c::HWS.flap_set_codes(state)
  NxTest.assert(codes['lift']['mechanism']['X-MECH'], 'vlastný mechanizmus sa pozná')
  NxTest.refute(codes['lift']['mechanism']['X-ARM'], 'druhý člen mechanizmus nie je')
  NxTest.assert(codes['lift']['members']['X-ARM'], 'ale členom setu áno')
  NxTest.assert(codes['lift']['mechanism'][c::MECH_HK], 'seed ostáva ako základ')
  # A predikát ten kód uzná.
  rec = [{ 'owner_part_key' => 'front:F1/flap', 'source' => 'catalog',
           'code' => 'X-MECH', 'qty' => 1 }]
  NxTest.assert_equal({ 'front:F1/flap' => { 'lift' => true } },
                      c::HWS.manual_flap_assemblies(rec, codes))
  NxTest.assert_equal({}, c::HWS.manual_flap_assemblies(rec), 'bez snapshotu seed kód nepozná')
  # Pokazený snapshot normalizáciu ani zber nezhodí (fail-soft).
  NxTest.assert(c::HWS.flap_set_codes('nezmysel')['lift']['mechanism'][c::MECH_HK])
end

NxTest.test('KOV-E1b (11): POKAZENÝ marker provenience nezhodí zber — platí najstarší') do
  c = NxKovE1b
  # Codex #333 kolo 3 P2: `to_i` na Hash/Array/true vyhodí výnimku a `Bom.collect`
  # žiadny rescue nemá — jeden ručne pokazený atribút by zhodil Kontrolu AJ
  # všetky výstupy. Nepoužiteľná hodnota preto znamená to isté ako chýbajúca: 0.
  [{}, [], true, 'nezmysel', nil, -3].each do |junk|
    cfg = c.stale_cfg(c::CB::LIFT_ACTIVATION_SCHEMA, c::HR::FLAP_UP, [], seed: junk)
    iss = c::BOM.flap_stale_issue('CAB-9', 4, cfg)
    NxTest.assert(iss, "seed #{junk.inspect} = najstarší -> RED `flap_stale`")
    NxTest.assert_equal(c::BP::FLAP_STALE, iss['code'])
  end
  # To isté pre schému configu (číta ju KAŽDÁ migračná vetva zberu).
  bad = c.stale_cfg(c::CB::LIFT_ACTIVATION_SCHEMA)
  bad['config_schema'] = {}
  NxTest.assert_equal(0, c::CB.config_schema_of(bad), 'smetie = najstaršia schéma')
  NxTest.assert(c::BOM.flap_stale_issue('CAB-9', 4, bad), 'a skrinka je nemigrovaná')
  NxTest.refute(c::CB.newer_config?(bad), 'smetie NIE JE marker novšej verzie')
  # Zdravá skrinka sa tým nemení.
  NxTest.assert_equal(nil, c::BOM.flap_stale_issue(
                             'CAB-9', 4,
                             c.stale_cfg(c::CB::LIFT_ACTIVATION_SCHEMA, c::HR::FLAP_UP,
                                         [{ 'owner_part_key' => 'front:F1/flap',
                                            'generic_type' => 'lift' }])
                           ))
end

NxTest.test('KOV-E1b (11): ručný doplnok vedľa automatu = ORANGE `flap_manual_duplicate`') do
  c = NxKovE1b
  owner = 'front:F1/flap'
  parts = [{ role: 'flap', part_key: owner, suffix: 'FLAP-1', name: 'Výklop 1' }]
  hw = [{ 'owner_part_key' => owner, 'generic_type' => 'lift', 'quantity' => 1 }]
  plan = { parts: parts, hardware: hw }
  emitted = c::CB.emitted_flap_kinds(plan)
  NxTest.assert_equal({ owner => { 'lift' => true } }, emitted)
  codes = c::HWS.flap_set_codes
  # Krytka JE členom setu -> nákup ich zlepí do jedného riadku (M27).
  ws = c::CB.manual_duplicate_warnings([c.manual_rec(code: c::ACC_COVER)], emitted, codes)
  NxTest.assert_equal(1, ws.length, ws.inspect)
  NxTest.assert_equal('flap_manual_duplicate', ws.first['code'])
  NxTest.assert_equal(owner, ws.first['part_key'])
  NxTest.assert(ws.first['message'].include?(c::ACC_COVER), ws.first['message'])
  # Kód mimo setu ORANGE nerobí; rovnako voľná položka.
  NxTest.assert_equal([], c::CB.manual_duplicate_warnings([c.manual_rec(code: 'INE')],
                                                          emitted, codes))
  NxTest.assert_equal([], c::CB.manual_duplicate_warnings([c.manual_rec(code: c::ACC_COVER,
                                                                       source: 'free')],
                                                          emitted, codes))
  # Bez vydanej automatickej položky (napr. čelo s úplnou ručnou zostavou) tiež nie.
  NxTest.assert_equal([], c::CB.manual_duplicate_warnings([c.manual_rec(code: c::ACC_COVER)],
                                                          {}, codes))
  # DVIERKA sa tým nedotknú — `emitted_flap_kinds` berie LEN rolu `flap`.
  door_plan = { parts: [{ role: 'front_door', part_key: 'front:F2/wing:single',
                          suffix: 'DOOR-1', name: 'Dvierka' }],
                hardware: [{ 'owner_part_key' => 'front:F2/wing:single',
                             'generic_type' => 'hinge', 'quantity' => 2 }] }
  NxTest.assert_equal({}, c::CB.emitted_flap_kinds(door_plan))
end

NxTest.test('KOV-E1b (11): `flap_stale` je RED v Kontrole a stopka pre 3 exporty') do
  c = NxKovE1b
  iss = c::BOM.flap_stale_issue('CAB-8', 3, c.stale_cfg(10))
  items = []
  c::V.check_hardware_issues([iss], items)
  NxTest.assert_equal(1, items.length)
  NxTest.assert_equal(c::V::RED, items.first['severity'])
  collected = { hardware_issues: [iss], hardware: [] }
  all = c::PC.hardware_blockers(collected, nil)
  NxTest.assert_equal(1, all.length, all.inspect)
  NxTest.assert(all.first.include?('CAB-8'), all.first)
  NxTest.assert_equal([], c::PC.hardware_blockers(collected, nil, scope: :kit),
                      'VEPO beží — geometria je správna')
end

# ============================================================================
# 12 — BRANY
# ============================================================================

NxTest.test('KOV-E1b (12): výklopové kódy sú v JEDINOM registri a zastavujú 3 výstupy') do
  c = NxKovE1b
  %w[lift_class_missing lift_dimension_unsupported lift_multirow_unsupported
     lift_combo_unsupported flap_stale].each do |code|
    NxTest.assert(c::BP::HW_LIFT_BLOCKERS.include?(code), "#{code} je v registri")
    NxTest.assert(c::BP.hw_blockers.include?(code), "#{code} zastavuje výstupy")
    NxTest.assert(c::BP::HW_BLOCKER_LABELS.key?(code), "#{code} má slovenskú vetu")
  end
  NxTest.assert(c::BP::HW_LIFT_BLOCKERS.first == 'lift_set_incomplete',
                'poradie registra je kontrakt — E1a kód ostáva prvý')
  collected = { hardware_issues: [{ 'code' => 'lift_class_missing', 'owner_id' => 'CAB-2' }],
                hardware: [] }
  out = c::PC.hardware_blockers(collected, nil)
  NxTest.assert_equal(1, out.length, out.inspect)
  NxTest.assert_equal([], c::PC.hardware_blockers(collected, nil, scope: :kit))
end

NxTest.test('KOV-E1b (12): uložený nosič `hardware_conflicts` unesie výklopové dôvody') do
  c = NxKovE1b
  pl = c.plan({ 'lift' => { 'system' => 'hl_top' } }, 'height' => 250.0, 'depth' => 200.0)
  conf = Array(pl[:hardware_conflicts])
  NxTest.assert(conf.any?, "plán nesie dôvody (#{conf.inspect})")
  # Nosic prejde validatorom planu (kod je v `HW_CONFLICT_CODES`).
  c::BP.validate_hardware_conflicts!(conf)
  iss = c::BOM.hardware_conflict_issues('CAB-1', 1, conf, pl[:front_items])
  NxTest.assert_equal(conf.length, iss.length, 'a zber ich prečíta ako tvrdé nálezy')
  items = []
  c::V.check_hardware_issues(iss, items)
  NxTest.assert(items.all? { |i| i['severity'] == c::V::RED }, items.inspect)
end

NxTest.test('KOV-E1b (12): nedostupná expanzia s výklopom z PRAVIDLA je fail-closed') do
  c = NxKovE1b
  pl = c.plan
  it = c.plan_lifts(pl).first
  NxTest.assert(it, 'skrinka má položku výklopu')
  collected = { hardware: [it.merge('owner_id' => 'CAB-1')], hardware_issues: [] }
  NxTest.assert(c::PC.hardware_expansion_unproven?(collected, nil),
                'bez expanzie sa úplnosť zostavy nedá dokázať')
  NxTest.refute(c::PC.hardware_expansion_unproven?(collected, nil, scope: :kit),
                'VEPO sa to netýka')
  NxTest.refute(c::PC.hardware_expansion_unproven?({ hardware: [], hardware_issues: [] }, nil))
  NxTest.assert(c::PC.drawer_stop(collected, nil), 'a brána exportov stojí')
end

# ============================================================================
# 13 — END-TO-END: PRAVIDLO -> SET -> NAKUP
# ============================================================================

NxTest.test('KOV-E1b (13): HL top 500 mm / 6 kg → 22L2500 + 22L3800 + JEDNA tyč') do
  c = NxKovE1b
  it = c.lifts(c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, weight_kg: 6.0)], 'kh' => 500.0))
        .first.merge('owner_id' => 'CAB-1')
  NxTest.assert_equal(%w[22L2500 22L3800], [it['params']['lift_class'], it['params']['arm_class']])
  bought = c.buy([it])
  NxTest.assert_equal(1, bought['507352'], "mechanizmus 22L2500 (#{bought.inspect})")
  NxTest.assert_equal(1, bought['507357'], 'ramená 22L3800')
  NxTest.assert_equal(1, bought['507365'], 'jedna stabilizačná tyč')
  NxTest.refute(bought.key?('507366'), "predĺženie sa NEVYDÁ vôbec (#{bought.inspect})")
  NxTest.assert_equal(1, bought['13781'], 'čelný príchyt')
  NxTest.assert_equal(1, bought['507343'], 'krytky biele')
end

NxTest.test('KOV-E1b (13): široká skrinka (KB 1200) → 2 tyče + predĺženie') do
  c = NxKovE1b
  it = c.lifts(c.evaluate([c.flap(lift_system: c::HR::LIFT_HL, weight_kg: 6.0)],
                          'kh' => 500.0, 'kb' => 1200.0)).first.merge('owner_id' => 'CAB-1')
  bought = c.buy([it])
  NxTest.assert_equal(2, bought['507365'], "dve tyče (#{bought.inspect})")
  NxTest.assert_equal(1, bought['507366'], 'a predlžovací diel')
end

NxTest.test('KOV-E1b (13): HK top Tip-On → set s piestom, klasik bez neho') do
  c = NxKovE1b
  tip = c.lifts(c.evaluate([c.flap(opening_mode: 'tipon')])).first.merge('owner_id' => 'CAB-1')
  bought = c.buy([tip])
  NxTest.assert(bought.key?('347814'), "Tip-On mechanizmus 22K2300T (#{bought.inspect})")
  NxTest.assert_equal(1, bought['250831'], 'Tip-On jednotka 76 mm')
  classic = c.buy([c.lifts(c.evaluate([c.flap])).first.merge('owner_id' => 'CAB-1')])
  NxTest.assert(classic.key?('347810'), "klasický mechanizmus (#{classic.inspect})")
  NxTest.refute(classic.key?('250831'), 'bez piestu')
end

NxTest.test('KOV-E1b (13): položka BEZ triedy zastaví export (`lift_set_incomplete`)') do
  c = NxKovE1b
  it = c.lifts(c.evaluate([c.flap(weight_kg: nil)])).first.merge('owner_id' => 'CAB-1')
  exp = c::HWS.expand([it], c.state)
  NxTest.assert(exp['unmapped'].any? { |u| u['reason'] == c::HWS::LIFT_SET_INCOMPLETE },
                exp['unmapped'].inspect)
  NxTest.assert(c::PC.hardware_blockers({ hardware_issues: [], hardware: [] }, exp).any?,
                'nákup, rozpočet ani ponuka sa nevydajú')
end

# ============================================================================
# 14 — SEED A GOLDEN
# ============================================================================

NxTest.test('KOV-E1b (14): `SEED_VERSION` 5 — knižnica v4 dostane OBE nové pravidlá') do
  c = NxKovE1b
  NxTest.assert_equal(5, c::HR::SEED_VERSION)
  NxTest.assert_equal(3, c::HR::STD, 'nový kind si vyžiadal aj `std`')
  mine = { 'rule_id' => 'moje-pravidlo', 'enabled' => true, 'output' => 'leg',
           'kind' => 'fixed', 'quantity' => 6, 'applies_to' => { 'role' => 'cabinet' } }
  old = c::HR.normalize_rules(c::HR::SEED_RULES.reject do |r|
    [c::LIFT_RULE, c::FALL_RULE].include?(r['rule_id'])
  end + [mine])
  merged, changed = c::HR.merge_seed(old, 4)
  NxTest.assert(changed, 'migrácia z v4 prebehne')
  ids = merged.map { |r| r['rule_id'] }
  NxTest.assert(ids.include?(c::LIFT_RULE) && ids.include?(c::FALL_RULE), ids.inspect)
  NxTest.assert_equal(6, merged.find { |r| r['rule_id'] == 'moje-pravidlo' }['quantity'],
                      'používateľské pravidlo ostáva nedotknuté')
  NxTest.assert_equal([merged, false], c::HR.merge_seed(merged, 5), 'z v5 sa už nič nedopĺňa')
end

NxTest.test('KOV-E1b (14): pravidlo `lift_class` prejde normalizáciou aj zápisovou bránou') do
  c = NxKovE1b
  NxTest.assert_equal([], c::HR.rules_problems(c.rules), 'seed sa dá uložiť')
  # Pasma su ZORADENE a typovo ocistene (poradie je vyznamove).
  r = c::HR.normalize_rules([JSON.parse(JSON.generate(c.lift_rule))
                               .merge('classes' => [
                                        { 'code' => '22K2900', 'min' => 3200, 'max' => 9000 },
                                        { 'code' => '22K2300', 'min' => 420, 'max' => 1610 },
                                        { 'code' => 'x' }
                                      ])]).first
  NxTest.assert_equal(%w[22K2300 22K2900], r['classes'].map { |x| x['code'] },
                      'zoradené a riadok bez čísel vypadol')
  NxTest.assert_equal(420.0, r['classes'].first['min'], 'a hodnoty sú Float')
  # Diera medzi pasmami ramien sa NEULOZI.
  gap = JSON.parse(JSON.generate(c.lift_rule))
  gap['arms'] = [{ 'code' => 'a', 'kh_min' => 300.0, 'kh_max' => 340.0, 'max_exclusive' => true,
                   'kg_min' => 1.0, 'kg_max' => 9.0 },
                 { 'code' => 'b', 'kh_min' => 400.0, 'kh_max' => 580.0,
                   'kg_min' => 1.0, 'kg_max' => 9.0 }]
  msg = c::HR.rules_problems(c::HR.normalize_rules([gap])).first
  NxTest.assert(msg && msg['message'].include?('medzera'), msg.inspect)
  # Prazdna tabulka tried tiez nie.
  empty = JSON.parse(JSON.generate(c.lift_rule)).merge('classes' => [])
  NxTest.assert(c::HR.rules_problems(c::HR.normalize_rules([empty])).any?)
end

# --- Codex #333 kolo 2 P2: neciselny skalar nezhodi CELY snapshot ----------
NxTest.test('KOV-E1b (14): nečíselná rezerva/prah pravidlo NAHLÁSI, snapshot NEZAHODÍ') do
  c = NxKovE1b
  mine = { 'rule_id' => 'moje-pravidlo', 'enabled' => true, 'output' => 'leg',
           'kind' => 'fixed', 'quantity' => 6, 'applies_to' => { 'role' => 'cabinet' } }
  broken = JSON.parse(JSON.generate(c.lift_rule))
                .merge('handle_allowance_kg' => {}, 'rod_double_from_kb_mm' => true)
  rules = nil
  begin
    rules = c::HR.normalize_rules([broken, mine])
  rescue StandardError => e
    NxTest.assert(false, "normalizácia spadla: #{e.class} #{e.message} (M28)")
  end
  NxTest.assert_equal(2, rules.length, 'ostatné pravidlá projektu ostávajú')
  NxTest.assert_equal(6, rules.last['quantity'], 'používateľské pravidlo nedotknuté')
  bad = rules.first
  NxTest.assert_equal(nil, bad['handle_allowance_kg'], 'neplatný skalár = nil, kľúč ostáva')
  NxTest.assert_equal(nil, bad['rod_double_from_kb_mm'])
  # Pravidlo sa NEULOZI, kym to clovek neopravi — a hlaska povie CO.
  msg = c::HR.rules_problems(rules).first
  NxTest.assert(msg && msg['message'].include?('rezerva na úchytku'), msg.inspect)
  NxTest.assert(msg['message'].include?('musí byť číslo'), msg['message'])
  # Vypnute pravidlo branu neblokuje (cesta von).
  off = rules.map { |r| r['rule_id'] == c::LIFT_RULE ? r.merge('enabled' => false) : r }
  NxTest.assert_equal([], c::HR.rules_problems(off), 'vypnuté pravidlo sa nekontroluje')
  # Vypocet je typovo bezpecny: ziadna rezerva, JEDNA tyc (nikdy hadanie).
  res = c.evaluate([c.flap(weight_kg: 3.0)], { 'kh' => c::KH_LF, 'kb' => 1200.0 }, {}, rules)
  item = c.lifts(res).first
  NxTest.assert(item, res[:conflicts].inspect)
  NxTest.assert_equal(1, item['params']['rod_count'], 'bez prahu sa tyč nezdvojí')
  # PROJEKTOVY snapshot s takym pravidlom sa DA precitat (P2: `to_f` na Hash
  # padol -> `project_rules` vratil nil -> `ensure_project_rules!` by projektove
  # pravidla ticho nahradil globalnou kniznicou).
  model = c.model_with('std' => c::HR::STD, 'seed_version' => c::HR::SEED_VERSION,
                       'rules' => [broken, mine])
  loaded = c::HR.project_rules(model)
  NxTest.assert(loaded.is_a?(Array), 'snapshot sa načítal')
  NxTest.assert_equal([c::LIFT_RULE, 'moje-pravidlo'], loaded.map { |r| r['rule_id'] })
end

NxTest.test('KOV-E1b (14): GOLDEN — zákazka BEZ výklopov sa nezmenila') do
  c = NxKovE1b
  cfg = c::CB.normalize('width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door',
                                                    'wings' => '1' }] })
  pl = c::CN.build_plan(cfg, 'CAB-1', hardware_rules: c.rules, materials: c::MAT)
  types = pl[:hardware].map { |h| h['generic_type'] }.uniq.sort
  NxTest.assert_equal(%w[hinge leg], types, "žiadny výklop nepribudol (#{types.inspect})")
  NxTest.assert_equal([], Array(pl[:hardware_conflicts]))
  hinge = pl[:hardware].find { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal('zavesy-podla-vysky', hinge['rule_id'], 'dvierka berie pôvodné pravidlo')
  NxTest.assert_equal(2, hinge['quantity'])
end
