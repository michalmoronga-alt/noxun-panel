# frozen_string_literal: true
# KOV-F1 (8.9.2026) — ZÁVESY: Noxun tabuľka + set podľa otvárania.
#
# Počet závesov určuje JEDNA tabuľka Noxun (platí pre všetkých výrobcov; set
# rozhoduje len o produkte): do 849 → 2 · 850–1700 → 3 · 1701–2200 → 4 ·
# 2201–2400 → 5 · 2401–2600 → 6 · 2601–2800 → 7. Guard z praxe: šírka nad
# 600 mm → +1. Hmotnosť vo V1 LEN VARUJE.
#
# Druh pravidla ostáva `bands` — ŽIADNY nový kind: starší plugin by neznámy kind
# preskočil a dvierka by dostali NULA závesov (aj pri novom vložení skrinky, lebo
# čítače pravidiel `std` ignorujú). Guardy sú preto VOLITEĽNÉ kľúče.
#
# Co sa overuje:
#   1) TABULKA a hranice (849 / 849,5 / 850 · 1700 / 1700,01 · 2800 / 2900)
#   2) `width_plus` +1 nad 600 mm (600 / 600,5) — bez podmienky výšky; explicitné
#      `wings` (auto nad 600 mm delí na 2 krídla, takže +1 by inak nikdy nenastalo)
#   3) VAROVANIA bez vplyvu na počet: `door_wide`, `door_wider_than_high`,
#      `hinge_weight_more` (nad VÝSLEDNÝM počtom po zámku), `hinge_weight_max`;
#      `weight_kg` nil → info `hinge_weight_unknown` v `BUILD_INFO_ONLY`
#   4) `finite` + zásah catch-all pásma: položka SA VYDÁ (počet 7) + KONFLIKT
#      `door_height_out_of_table`; ručný zámok počtu ho ZHASNE
#   5) CHARAKTERIZÁCIA STARÉHO ČÍTAČA: pravidlo bez guardov (a starý `compute`)
#      ráta podľa tabuľky bez +1 a nikdy nevydá nulu
#   6) SEED: nahradenie LEN presného starého tvaru, prekryv pravidiel = ORANGE,
#      `std` forward gate (dokument z novšej verzie sa len číta)
#   7) SETY: klasifikácia seed setov, triedny kľúč `hinge` (ponuka + zápisová
#      validácia), migrácia mapovania (vlastný set prežije, jednorazovosť),
#      sentinel `none` (round-trip + resolver + uložený snapshot a reopen),
#      precedencia s override skrinky
#   8) EXPANZIA: Tip-On → P2O set + 1 piest na krídlo (1/2/3/4 krídla),
#      nesúlad klasifikácie = RED `hinge_set_mismatch`
#   9) BRÁNY: jediný register `BuildPlan.hw_blockers`; zásuvkové výstupy
#      BAJTOVO ROVNAKÉ; VEPO závesové kódy neblokujú
#  10) `CONFIG_SCHEMA` 9 (trvalý nosič + klasifikované závesy): downgrade sa
#      odmieta s hláškou, staršie schémy sa čítajú a prestavbou dostanú 9
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1  pásmo 849 sa zmení na 850 (výlučne)      -> hranice tabuľky
#   M2  `width_plus` sa ráta z výšky, nie šírky  -> +1 nad 600 mm
#   M3  hmotnostná kontrola beží PRED override   -> „zámok pod pásmom"
#   M4  catch-all pásmo sa pri `finite` zahodí   -> položka nad 2800 mm
#   M5  konflikt nezhasne po ručnom zámku        -> náprava zámkom
#   M6  `normalize_rules` zahodí nové kľúče      -> round-trip pravidla
#   M7  seed prepíše aj UPRAVENÉ pravidlo        -> nahradenie len presného tvaru
#   M8  triedny kľúč závesu vyžaduje systém      -> ponuka setov pre `class:hinge|…`
#   M9  migrácia prepíše existujúci kľúč         -> vlastný set prežije
#   M10 sentinel `none` sa v mapovaní zahodí     -> round-trip + resolver
#   M11 generický override skrinky spadne na
#       projektový triedny kľúč                  -> precedencia
#   M12 nesúlad klasifikácie = ORANGE, nie RED   -> `hinge_set_mismatch` v bránach
#   M13 závesový kód zablokuje VEPO              -> `scope: :kit`
#   M14 zásuvkové brány zmenia poradie/text      -> charakterizácia registra
#   M15 značka migrácie sa pri zápise stratí      -> snapshot round-trip
#   M16 varovanie šírky sa posunie o 1 mm         -> hranica 800 / 801
#   M17 `CONFIG_SCHEMA` ostane na 8               -> schéma 9 a downgrade brána
#   M18 sentinel je REŤAZEC „none"                -> vlastný set s ID `none`
#   M19 zmrazenie globálu sentinel zahodí         -> nový projekt / doplnenie
#   M20 door guardy z POSLEDNÉHO duplikátu        -> duplicitný `rule_id`
#   M21 set iného typu pri dvierkach = ORANGE     -> RED `hinge_set_mismatch`
require_relative '../helper' unless defined?(NxTest)

require 'json'
require 'fileutils'

# UI vrstva (brana exportov) — headless nie je v require zozname helpera,
# takze si ju sada pyta sama (vzor `test_kovc2b_brany.rb`).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

module NxKovF
  E   = Noxun::Engine
  HR  = E::HardwareRules
  HWS = E::HardwareSets
  CN  = E::Construction
  CB  = E::CabinetBuilder
  BP  = E::BuildPlan
  BOM = E::Bom
  V   = E::Validation
  PC  = E::ProductionCore
  REC = E::Recipes

  HINGE_RULE = 'zavesy-podla-vysky'

  module_function

  def rules
    HR.normalize_rules(HR::SEED_RULES)
  end

  def hinge_rule
    rules.find { |r| r['rule_id'] == HINGE_RULE }
  end

  # Deskriptor KRIDLA dvierok. `weight` nil = plan bez hustot (KOV-W neanotovala).
  def door(height, width = 400.0, key = 'front:F1/wing:single', weight: nil, mode: nil)
    d = { role: 'front_door', part_key: key, suffix: 'DOOR-1', name: 'Dvierka 1',
          prod: { length: height.to_f, width: width.to_f, thickness: 18.0 } }
    d[:weight_kg] = weight if weight
    d[:opening_mode] = mode if mode
    d
  end

  def ctx(over = {})
    { 'width' => 600.0, 'height' => 2000.0, 'depth' => 510.0, 'floor_height' => 100.0,
      'available_width' => 564.0, 'available_height' => 584.0, 'available_depth' => 510.0,
      'support' => 'none' }.merge(over)
  end

  def evaluate(parts, cfg = {}, rules_over = nil)
    HR.evaluate(cfg, parts, ctx, rules: rules_over || rules)
  end

  def hinges(res)
    res[:items].select { |it| it['generic_type'] == 'hinge' }
  end

  def qty(height, width = 400.0)
    hinges(evaluate([door(height, width)])).first['quantity']
  end

  def warn_codes(res)
    res[:warnings].map { |w| w['code'] }
  end

  # Pravidlo BEZ door guardov = presne to, co vidi STARY citac.
  def legacy_reader_rule
    r = JSON.parse(JSON.generate(hinge_rule))
    HR::DOOR_GUARD_KEYS.each { |k| r.delete(k) }
    HR.normalize_rules([r])
  end

  # --- sety a expanzia ----------------------------------------------------

  def seed_sets
    HWS.normalize_sets(HWS::SEED_SETS)
  end

  def set_def(sid)
    seed_sets.find { |s| s['set_id'] == sid }
  end

  # Projektovy stav so seed setmi zavesov a danym mapovanim.
  def state(mapping, sids = %w[zaves-klasik zaves-p2o])
    defs = {}
    sids.each { |sid| defs[sid] = set_def(sid) }
    { 'mapping' => mapping, 'sets' => defs }
  end

  # Polozka zavesu tak, ako ju emituje pravidlo PO KOV-F1.
  def item(mode = 'classic', owner = 'front:F1/wing:single', qty = 2, cid = 'CAB-1')
    { 'owner_id' => cid, 'owner_part_key' => owner, 'generic_type' => 'hinge',
      'quantity' => qty, 'rule_id' => HINGE_RULE, 'source' => 'rule',
      'params' => { 'use_type' => 'door', 'opening_mode' => mode } }
  end

  # LEGACY polozka (zakazka spred KOV-F1) — ziadne params.
  def legacy_item(owner = 'front:F1/wing:single')
    { 'owner_id' => 'CAB-1', 'owner_part_key' => owner, 'generic_type' => 'hinge',
      'quantity' => 2, 'rule_id' => HINGE_RULE, 'source' => 'rule', 'params' => {} }
  end

  def codes(exp)
    exp['rows'].map { |r| [r['code'], r['quantity']] }.sort
  end
end

# ============================================================================
# 1 — TABULKA A HRANICE
# ============================================================================

NxTest.test('KOV-F1 (1): NOXUN tabuľka a jej hranice (849 / 849,5 / 850 / 2800 / 2900)') do
  c = NxKovF
  { 300.0 => 2, 849.0 => 2, 849.5 => 3, 850.0 => 3, 1700.0 => 3, 1700.01 => 4,
    2200.0 => 4, 2201.0 => 5, 2400.0 => 5, 2401.0 => 6, 2600.0 => 6,
    2601.0 => 7, 2800.0 => 7, 2900.0 => 7 }.each do |h, want|
    NxTest.assert_equal(want, c.qty(h), "výška #{h} -> #{want}")
  end
end

NxTest.test('KOV-F1 (1): tabuľka MA catch-all pásmo — starý čítač nikdy nedostane nulu') do
  c = NxKovF
  bands = c.hinge_rule['bands']
  NxTest.assert_equal(nil, bands.last['max'], 'posledné pásmo je „všetko nad"')
  NxTest.assert_equal(7, bands.last['quantity'], 'a dáva počet posledného pásma')
  # Validator zapisovej cesty preto NEMA co vytknut (kontrakt sa nemeni).
  NxTest.assert_equal([], c::HR.rules_problems(c.rules), 'seed sa dá uložiť')
end

# ============================================================================
# 2 — +1 NAD 600 mm
# ============================================================================

NxTest.test('KOV-F1 (2): šírka nad 600 mm = +1 záves (hranice 600 / 600,5)') do
  c = NxKovF
  NxTest.assert_equal(2, c.qty(700.0, 600.0), '600 mm je EŠTE bez prídavku')
  NxTest.assert_equal(3, c.qty(700.0, 600.5), '600,5 mm už +1')
  NxTest.assert_equal(4, c.qty(1000.0, 900.0), 'platí aj v treťom pásme')
  NxTest.assert_equal(3, c.qty(500.0, 800.0), 'a bez podmienky výšky (široké nízke dvere)')
end

NxTest.test('KOV-F1 (2): +1 sa počíta zo ŠÍRKY KRÍDLA, nie z otvoru skrinky') do
  c = NxKovF
  # Skrinka 1000 mm s EXPLICITNE jedným krídlom: krídlo je široké, +1 nastane.
  cfg = c::CB.normalize('width' => 1000.0, 'height' => 800.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '1' }] })
  pl = c::CN.build_plan(cfg, 'CAB-1', hardware_rules: c.rules)
  one = pl[:hardware].select { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal(1, one.length, 'jedno krídlo = jedna položka')
  NxTest.assert_equal(3, one.first['quantity'], 'krídlo ~996 mm > 600 -> 2 + 1')
  # To iste s DVOMA kridlami: kazde je uzke (~496 mm), ziadny pridavok.
  cfg2 = c::CB.normalize('width' => 1000.0, 'height' => 800.0, 'depth' => 500.0,
                         'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '2' }] })
  two = c::CN.build_plan(cfg2, 'CAB-1', hardware_rules: c.rules)[:hardware]
             .select { |h| h['generic_type'] == 'hinge' }
  NxTest.assert_equal(2, two.length, 'dve krídla = dve položky')
  NxTest.assert_equal([2, 2], two.map { |h| h['quantity'] }, 'úzke krídla bez prídavku')
end

# ============================================================================
# 3 — VAROVANIA (POCET NEMENIA)
# ============================================================================

NxTest.test('KOV-F1 (3): široké čelo = ORANGE `door_wide`, počet sa NEMENÍ') do
  c = NxKovF
  res = c.evaluate([c.door(700.0, 850.0)])
  NxTest.assert_equal(3, c.hinges(res).first['quantity'], '2 z tabuľky + 1 za šírku')
  w = res[:warnings].find { |x| x['code'] == 'door_wide' }
  NxTest.assert(w, "čakal som door_wide, mám #{c.warn_codes(res).inspect}")
  NxTest.assert_equal('front:F1/wing:single', w['part_key'])
  # HRANICA: 800 mm je EŠTE v poriadku, 801 mm už varuje (inkluzívne `over`).
  NxTest.assert_equal([], c.warn_codes(c.evaluate([c.door(700.0, 800.0)])) & ['door_wide'],
                      '800 mm je ešte v poriadku')
  NxTest.assert(c.warn_codes(c.evaluate([c.door(700.0, 801.0)])).include?('door_wide'),
                '801 mm už varuje')
end

NxTest.test('KOV-F1 (3): door guardy sa berú z PRVÉHO duplicitného pravidla') do
  c = NxKovF
  # Codex #329 kolo 1 P2: `evaluate` pri duplicitnom `rule_id` použije PRVÉ
  # pravidlo (druhé prizná ORANGE `hardware_rule_duplicate` a preskočí).
  # Index guardov to musí robiť ROVNAKO — inak by nadvýška aj varovania prišli
  # z pravidla, ktoré položku vôbec nevydalo.
  first = c.hinge_rule
  second = JSON.parse(JSON.generate(first))
  second.delete('finite')          # bez `finite` by nad tabuľkou nevznikol konflikt
  second['width_warn_over'] = 3000 # a široké čelo by nevarovalo
  res = c.evaluate([c.door(2900.0, 900.0)], {}, c::HR.normalize_rules([first, second]))
  codes = c.warn_codes(res)
  NxTest.assert(codes.include?('hardware_rule_duplicate'), codes.inspect)
  NxTest.assert_equal([c::HR::DOOR_OUT_OF_TABLE], res[:conflicts].map { |x| x['code'] },
                      'konflikt „mimo tabuľky" je z PRVÉHO pravidla (`finite`)')
  NxTest.assert(codes.include?('door_wide'), "aj varovanie šírky (limit 800): #{codes.inspect}")
end

NxTest.test('KOV-F1 (3): širšie než vyššie = ORANGE „nemá to byť výklop?"') do
  c = NxKovF
  res = c.evaluate([c.door(400.0, 500.0)])
  w = res[:warnings].find { |x| x['code'] == 'door_wider_than_high' }
  NxTest.assert(w, "čakal som door_wider_than_high, mám #{c.warn_codes(res).inspect}")
  NxTest.assert(w['message'].include?('výklop'), w['message'])
  NxTest.refute(c.warn_codes(c.evaluate([c.door(500.0, 400.0)])).include?('door_wider_than_high'))
end

NxTest.test('KOV-F1 (3): hmotnosť nad 22 kg = ORANGE `hinge_weight_max`') do
  c = NxKovF
  res = c.evaluate([c.door(700.0, 400.0, weight: 24.0)])
  NxTest.assert_equal(2, c.hinges(res).first['quantity'], 'hmotnosť počet NEMENÍ (V1 len varuje)')
  w = res[:warnings].find { |x| x['code'] == 'hinge_weight_max' }
  NxTest.assert(w, "čakal som hinge_weight_max, mám #{c.warn_codes(res).inspect}")
  NxTest.assert(w['message'].include?('22'), w['message'])
end

NxTest.test('KOV-F1 (3): hmotnostné pásmo sa porovnáva s VÝSLEDNÝM počtom po zámku') do
  c = NxKovF
  # 15 kg -> Hettich chce 4; tabulka pri 700 mm dava 2 -> varovanie.
  res = c.evaluate([c.door(700.0, 400.0, weight: 15.0)])
  w = res[:warnings].find { |x| x['code'] == 'hinge_weight_more' }
  NxTest.assert(w, "čakal som hinge_weight_more, mám #{c.warn_codes(res).inspect}")
  NxTest.assert_equal(4, w['data']['want'])
  NxTest.assert_equal(2, w['data']['quantity'])
  # Rucny zamok na 4 -> varovanie zmizne (kontrola bezi PO override).
  cfg = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/wing:single',
                                 'generic_type' => 'hinge', 'rule_id' => c::HINGE_RULE,
                                 'quantity' => 4 }] }
  res2 = c.evaluate([c.door(700.0, 400.0, weight: 15.0)], cfg)
  NxTest.assert_equal(4, c.hinges(res2).first['quantity'])
  NxTest.refute(c.warn_codes(res2).include?('hinge_weight_more'), 'zámok varovanie zhasne')
  # Zamok POD pasmom (3) varovanie NECHAVA.
  cfg[:hardware_overrides].first['quantity'] = 3
  NxTest.assert(c.warn_codes(c.evaluate([c.door(700.0, 400.0, weight: 15.0)], cfg))
                 .include?('hinge_weight_more'), 'zámok pod pásmom varuje ďalej')
end

NxTest.test('KOV-F1 (3): neznáma hmotnosť = INFO, ktoré Kontrola NEUKAZUJE') do
  c = NxKovF
  res = c.evaluate([c.door(700.0)])
  w = res[:warnings].find { |x| x['code'] == 'hinge_weight_unknown' }
  NxTest.assert(w, "čakal som hinge_weight_unknown, mám #{c.warn_codes(res).inspect}")
  NxTest.assert_equal('info', w['severity'])
  NxTest.assert(c::V::BUILD_INFO_ONLY.include?('hinge_weight_unknown'),
                'INFO o stave dát nie je nález — inak by svietilo na každých dvierkach')
  items = []
  c::V.check_build(w.merge('owner_id' => 'CAB-1'), items)
  NxTest.assert_equal([], items, 'do Kontroly sa nedostane')
end

# ============================================================================
# 4 — NAD TABULKOU (`finite`)
# ============================================================================

NxTest.test('KOV-F1 (4): nad 2800 mm položka VZNIKNE (7 ks) + konflikt „mimo tabuľky"') do
  c = NxKovF
  res = c.evaluate([c.door(2900.0)])
  h = c.hinges(res)
  NxTest.assert_equal(1, h.length, 'riadok v Kovaní MUSÍ existovať — inak nemá kde vzniknúť zámok')
  NxTest.assert_equal(7, h.first['quantity'], 'počet posledného pásma')
  cf = res[:conflicts]
  NxTest.assert_equal(1, cf.length, "čakal som konflikt, mám #{cf.inspect}")
  NxTest.assert_equal(c::HR::DOOR_OUT_OF_TABLE, cf.first['code'])
  NxTest.assert_equal('front:F1/wing:single', cf.first['owner_part_key'])
  NxTest.assert(cf.first['message'].include?('2900'), cf.first['message'])
  NxTest.assert_equal([], c.evaluate([c.door(2800.0)])[:conflicts], '2800 je ešte v tabuľke')
end

NxTest.test('KOV-F1 (4): ručný zámok počtu konflikt ZHASNE') do
  c = NxKovF
  cfg = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/wing:single',
                                 'generic_type' => 'hinge', 'rule_id' => c::HINGE_RULE,
                                 'quantity' => 8 }] }
  res = c.evaluate([c.door(2900.0)], cfg)
  NxTest.assert_equal(8, c.hinges(res).first['quantity'])
  NxTest.assert_equal([], res[:conflicts], 'zámok = vedomé rozhodnutie, RED zhasne')
  # Vypnuta polozka konflikt tiez nerobi (niet co objednavat).
  off = { hardware_overrides: [{ 'owner_part_key' => 'front:F1/wing:single',
                                 'generic_type' => 'hinge', 'rule_id' => c::HINGE_RULE,
                                 'disabled' => true }] }
  res_off = c.evaluate([c.door(2900.0)], off)
  NxTest.assert_equal([], c.hinges(res_off))
  NxTest.assert_equal([], res_off[:conflicts])
end

NxTest.test('KOV-F1 (4): konflikt prežije config (nosič `hardware_conflicts`) a vráti sa do Kontroly') do
  c = NxKovF
  cfg = c::CB.normalize('width' => 600.0, 'height' => 3100.0, 'depth' => 500.0,
                        'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '1' }] })
  pl = c::CN.build_plan(cfg, 'CAB-1', hardware_rules: c.rules)
  NxTest.assert_equal([c::HR::DOOR_OUT_OF_TABLE], pl[:hardware_conflicts].map { |x| x['code'] })
  stored = c::CB.send(:merge_final, cfg, pl)
  NxTest.assert_equal(1, Array(stored[:hardware_conflicts]).length, 'nosič je v configu')
  round = JSON.parse(JSON.generate(stored[:hardware_conflicts]))
  NxTest.assert_equal(stored[:hardware_conflicts], round, 'a prežije JSON round-trip')
  # Bom -> hardware_issues -> Kontrola RED
  iss = c::BOM.hardware_conflict_issues('CAB-1', 42, round, stored[:front_items])
  NxTest.assert_equal(1, iss.length)
  NxTest.assert_equal('red', iss.first['severity'])
  items = []
  c::V.check_hardware_issues(iss, items)
  NxTest.assert_equal(1, items.length)
  NxTest.assert_equal(c::V::RED, items.first['severity'])
  NxTest.assert(items.first['message_sk'].include?('tabuľk'), items.first['message_sk'])
end

NxTest.test('KOV-F1 (4): nosič má vlastný kontrakt — neznámy kód plán ODMIETNE') do
  c = NxKovF
  ok = [{ 'owner_part_key' => 'front:F1/wing:single', 'code' => c::HR::DOOR_OUT_OF_TABLE,
          'message' => 'x' }]
  NxTest.assert_equal(ok, c::BP.validate_hardware_conflicts!(ok))
  NxTest.assert_raise('neznamy kod') do
    c::BP.validate_hardware_conflicts!([{ 'owner_part_key' => 'front:F1/wing:single',
                                          'code' => 'vymyslene', 'message' => 'x' }])
  end
  NxTest.assert_raise('nema owner_part_key') do
    c::BP.validate_hardware_conflicts!([{ 'owner_part_key' => '', 'code' => c::HR::DOOR_OUT_OF_TABLE,
                                          'message' => 'x' }])
  end
  # Neznamy kod v ULOZENOM configu (novsia verzia) sa v zbere PRESKOCI.
  iss = c::BOM.hardware_conflict_issues('CAB-1', 1,
                                        [{ 'owner_part_key' => 'front:F1/wing:single',
                                           'code' => 'z_buducnosti', 'message' => 'x' }], [])
  NxTest.assert_equal([], iss, 'o novšiu zákazku sa stará vlastná brána `newer_configs`')
end

# ============================================================================
# 5 — CHARAKTERIZACIA STAREHO CITACA
# ============================================================================

NxTest.test('KOV-F1 (5): starý čítač ráta podľa tabuľky bez +1 a NIKDY nulu') do
  c = NxKovF
  legacy = c.legacy_reader_rule
  { 300.0 => 2, 850.0 => 3, 2900.0 => 7 }.each do |h, want|
    res = c::HR.evaluate({}, [c.door(h, 900.0)], c.ctx, rules: legacy)
    hin = c.hinges(res)
    NxTest.assert_equal(1, hin.length, "výška #{h}: položka vznikne aj bez guardov")
    NxTest.assert_equal(want, hin.first['quantity'], "výška #{h} -> #{want} (bez +1 za šírku)")
    NxTest.assert_equal([], res[:conflicts], 'bez `finite` žiadny konflikt')
    NxTest.assert_equal([], c.warn_codes(res) & %w[door_wide door_wider_than_high
                                                   hinge_weight_more hinge_weight_max],
                        'a žiadne door guardy')
  end
end

NxTest.test('KOV-F1 (5): nové kľúče prežijú normalizáciu a typovo sa očistia') do
  c = NxKovF
  r = c.hinge_rule
  NxTest.assert_equal(true, r['finite'])
  NxTest.assert_equal({ 'over' => 600.0, 'add' => 1 }, r['width_plus'])
  NxTest.assert_equal(800.0, r['width_warn_over'])
  NxTest.assert_equal([7.7, 13.7, 17.1, 22.0], r['weight_bands'].map { |b| b['max'] })
  # Round-trip cez JSON (snapshot v .skp) nic nestrati.
  again = c::HR.normalize_rules(JSON.parse(JSON.generate([r]))).first
  NxTest.assert_equal(r, again, 'normalizácia je idempotentná')
  # Poskodene tvary sa ZAHODIA, nie hadaju.
  bad = c::HR.normalize_rules([r.merge('width_plus' => { 'over' => 0, 'add' => 1 },
                                       'width_warn_over' => 'x')]).first
  NxTest.refute(bad.key?('width_plus'), 'nekladné `over` = guard preč')
  NxTest.refute(bad.key?('width_warn_over'), 'nečíselná hranica = guard preč')
end

# ============================================================================
# 6 — SEED, PREKRYV, `std` BRANA
# ============================================================================

NxTest.test('KOV-F1 (6): seed nahradí LEN nedotknutý starý tvar pravidla') do
  c = NxKovF
  old = c::HR::LEGACY_SEED_SHAPES[c::HINGE_RULE].first
  refreshed, added, ref_ids = c::HR.project_seed_plan(c::HR.normalize_rules([old]))
  NxTest.assert_equal([c::HINGE_RULE], ref_ids, 'nedotknutý starý seed sa obnoví')
  NxTest.assert_equal([849.0, 1700.0, 2200.0, 2400.0, 2600.0, 2800.0, nil],
                      refreshed.find { |r| r['rule_id'] == c::HINGE_RULE }['bands'].map { |b| b['max'] })
  NxTest.assert(added.include?('uchytkovy-profil'), 'chýbajúce pravidlá sa doplnia')
  # Upraveny (premenovany, iny pocet) tvar sa NEDOTKNE.
  mine = c::HR.normalize_rules([old.merge('bands' => [{ 'max' => nil, 'quantity' => 9 }])])
  _out, _add, refs2 = c::HR.project_seed_plan(mine)
  NxTest.assert_equal([], refs2, 'používateľská úprava sa NIKDY neprepíše')
end

NxTest.test('KOV-F1 (6): druhé zapnuté pravidlo závesov = ORANGE, uplatní sa PRVÉ') do
  c = NxKovF
  mine = c.hinge_rule.merge('rule_id' => 'moje-zavesy',
                            'bands' => [{ 'max' => nil, 'quantity' => 9 }])
  res = c.evaluate([c.door(700.0)], {}, c::HR.normalize_rules([c.hinge_rule, mine]))
  NxTest.assert_equal(1, c.hinges(res).length, 'dvojitý nákup NIKDY')
  NxTest.assert_equal(2, c.hinges(res).first['quantity'], 'platí prvé pravidlo')
  w = res[:warnings].find { |x| x['code'] == 'hardware_rule_overlap' }
  NxTest.assert(w, "čakal som hardware_rule_overlap, mám #{c.warn_codes(res).inspect}")
  NxTest.assert_equal(c::HINGE_RULE, w['data']['used_rule_id'])
  # A seed sa do takeho snapshotu NEDOPLNA.
  _out, added, = c::HR.project_seed_plan(c::HR.normalize_rules([mine]))
  NxTest.refute(added.include?(c::HINGE_RULE), 'vlastné pravidlo závesov = seed ruky preč')
end

NxTest.test('KOV-F1 (6): `std` forward gate — dokument z novšej verzie sa len číta') do
  c = NxKovF
  NxTest.assert(c::HR::STD >= 2, 'KOV-F1 bumplo STD')
  NxTest.assert(c::HR.doc_std_unsupported?('std' => c::HR::STD + 1), 'novší dokument')
  NxTest.refute(c::HR.doc_std_unsupported?('std' => c::HR::STD))
  NxTest.refute(c::HR.doc_std_unsupported?('seed_version' => 1), 'chýbajúci std = najstarší formát')
  # Zapisova cesta snapshotu ho ODMIETNE (model = fake s novsim dokumentom).
  model = Struct.new(:doc) do
    def get_attribute(_dict, _key)
      doc
    end

    def set_attribute(_dict, _key, _value)
      raise 'zápis do snapshotu z novšej verzie sa NESMIE stať'
    end
  end.new(JSON.generate('std' => c::HR::STD + 1, 'rules' => []))
  NxTest.assert_equal(false, c::HR.set_project_rules(model, c.rules))
end

# ============================================================================
# 7 — SETY, TRIEDNY KLUC, MIGRACIA, SENTINEL
# ============================================================================

NxTest.test('KOV-F1 (7): seed sety závesov sú KLASIFIKOVANÉ (dvierka + otváranie)') do
  c = NxKovF
  { 'zaves-klasik' => 'classic', 'zaves-p2o' => 'tipon' }.each do |sid, om|
    s = c.set_def(sid)
    NxTest.assert_equal('door', s['use_type'], sid)
    NxTest.assert_equal(om, s['opening_mode'], sid)
    NxTest.assert_equal('Hettich', s['manufacturer'], sid)
    NxTest.assert_equal('Sensys', s['series'], sid)
    NxTest.assert_equal('hinge', s['generic_type'], sid)
  end
  _norm, errs = c::HWS.validate_sets(c::HWS::SEED_SETS)
  NxTest.assert_equal([], errs, errs.inspect)
end

NxTest.test('KOV-F1 (7): triedny kľúč `hinge` má vlastnú ponuku aj zápisovú validáciu') do
  c = NxKovF
  canon, err = c::HWS.parse_class_key('class:hinge|tipon')
  NxTest.assert_equal('class:hinge|tipon', canon, err.to_s)
  NxTest.assert_equal(nil, c::HWS.parse_class_key('class:hinge|tipon|metal').first,
                      'konštrukciu zásuvky má len výsuv')
  NxTest.assert_equal(nil, c::HWS.parse_class_key('class:hinge|tipon@front:F1/panel',
                                                  allow_owner: true).first,
                      'per-krídlo výber je MIMO KOV-F1')
  # Ponuka: zavesove sety NEMAJU system zasuviek, a predsa sa musia ponuknut.
  opts = c::HWS.class_set_options('class:hinge|tipon', c.seed_sets, {}, [])
  NxTest.assert_equal(['zaves-p2o'], opts.map { |o| o['set_id'] }, opts.inspect)
  NxTest.assert_equal(['zaves-klasik'],
                      c::HWS.class_set_options('class:hinge|classic', c.seed_sets, {}, [])
                            .map { |o| o['set_id'] })
  # Zapisova validacia: Tip-On kluc na klasicky set = odmietnutie.
  defs = c::HWS.index_sets(c.seed_sets)
  NxTest.assert_equal(nil, c::HWS.class_key_value_problem('class:hinge|tipon', 'zaves-p2o', defs))
  NxTest.assert(c::HWS.class_key_value_problem('class:hinge|tipon', 'zaves-klasik', defs))
  NxTest.assert(c::HWS.class_key_value_problem('class:hinge|classic', 'nohy-klzak-17', defs),
                'set na nohy nie je set na dvierka')
  NxTest.assert(c::HWS.class_key_label('class:hinge|tipon').to_s.include?('Tip-On'))
end

NxTest.test('KOV-F1 (7): sentinel `none` prežije mapovanie, snapshot aj resolver') do
  c = NxKovF
  out, errs = c::HWS.parse_mapping({ 'class:hinge|tipon' => c::HWS::MAPPING_NONE })
  NxTest.assert_equal([], errs, errs.inspect)
  NxTest.assert_equal(c::HWS::MAPPING_NONE, out['class:hinge|tipon'], 'round-trip')
  NxTest.assert_equal([], c::HWS.value_set_ids(c::HWS::MAPPING_NONE),
                      'na žiadny set neukazuje — snapshot nemá čo zmraziť')
  NxTest.assert_equal([], c::HWS.mapping_commitments(c::HWS::MAPPING_NONE))
  NxTest.assert_equal(nil, c::HWS.class_key_value_problem('class:hinge|tipon',
                                                          c::HWS::MAPPING_NONE, {}))
  NxTest.assert(c::HWS.mapping_value_text(c::HWS::MAPPING_NONE, {}).include?('vedome'))
  # Normalizacia so ZOZNAMOM setov ho NESMIE zahodit (inak by snapshot spadol).
  kept = c::HWS.normalize_mapping({ 'class:hinge|tipon' => c::HWS::MAPPING_NONE }, c.seed_sets)
  NxTest.assert_equal(c::HWS::MAPPING_NONE, kept['class:hinge|tipon'])
  # A prezije JSON round-trip (config, snapshot aj kniznica idu cez JSON).
  NxTest.assert(c::HWS.mapping_none?(JSON.parse(JSON.generate(c::HWS::MAPPING_NONE))),
                'sentinel musí prežiť JSON — inak by sa po reopene stal „selektorom"')
  # Resolver: vedome bez setu, NIKDY set z nizsej urovne.
  st = c.state('class:hinge|tipon' => c::HWS::MAPPING_NONE, 'hinge' => 'zaves-klasik')
  exp = c::HWS.expand([c.item('tipon')], st)
  NxTest.assert_equal([], exp['rows'], 'žiadne kódy')
  NxTest.assert_equal('set_none', exp['unmapped'].first['reason'])
  NxTest.assert(c::HWS.unmapped_reason_sk(exp['unmapped'].first).include?('vedome'))
end

NxTest.test('KOV-F1 (7): sentinel a značka migrácie prežijú ULOŽENIE snapshotu a reopen') do
  c = NxKovF
  model = c.fake_model
  st = c.state('class:hinge|tipon' => c::HWS::MAPPING_NONE, 'hinge' => 'zaves-klasik')
  st['migrations'] = [c::HWS::HINGE_CLASS_MIGRATION]
  NxTest.assert_equal(true, c::HWS.write_project_state(model, st), 'snapshot sa uloží')
  status, back = c::HWS.project_state_status(model)
  NxTest.assert_equal(:ok, status, 'a znovu sa načíta ako platný')
  NxTest.assert_equal(c::HWS::MAPPING_NONE, back['mapping']['class:hinge|tipon'],
                      'sentinel prežije reopen — inak by voľba ticho spadla na projektový default')
  NxTest.assert_equal([c::HWS::HINGE_CLASS_MIGRATION], back['migrations'],
                      'značka prežije zápis — inak by sa migrácia opakovala pri každom otvorení')
  # A `ensure_project_state!` uz do mapovania NESIAHNE (znacka je tam).
  NxTest.assert_equal(back['mapping'], c::HWS.ensure_project_state!(model)['mapping'])
end

NxTest.test('KOV-F1 (7): vlastný set s ID `none` ostáva REÁLNYM setom') do
  c = NxKovF
  # Codex #329 kolo 1 P2: `set_id` je ľubovoľný neprázdny reťazec, takže set
  # s ID „none" sú PLATNÉ dáta. Reťazcový sentinel by ho (aj v inej veľkosti
  # písmen) preklasifikoval na „vedome bez setu" — teda dvierka BEZ závesov
  # v nákupe, bez jediného náznaku. Sentinel je preto OBJEKT.
  NxTest.refute(c::HWS.mapping_none?('none'), 'reťazec je `set_id`, nie sentinel')
  NxTest.refute(c::HWS.mapping_none?('NONE'))
  NxTest.refute(c::HWS.mapping_none?({ 'param' => 'none', 'bands' => [] }), 'selektor tiež nie')
  NxTest.assert(c::HWS.mapping_none?(c::HWS::MAPPING_NONE))
  # Tokeny sa nemôžu prekryť — reálny set má prefix, sentinel je holý.
  NxTest.assert_equal('set:none', c::HWS.mapping_option_id('none'))
  NxTest.assert_equal(c::HWS::MAPPING_NONE_OPTION, c::HWS.mapping_option_id(c::HWS::MAPPING_NONE))
  NxTest.refute(c::HWS.mapping_option_id('none') == c::HWS.mapping_option_id(c::HWS::MAPPING_NONE))
  # A set s ID `none` prejde mapovaním, zmrazením aj nákupom ako každý iný.
  mine = c.set_def('zaves-klasik').merge('set_id' => 'none', 'name' => 'Môj záves')
  out, errs = c::HWS.parse_mapping({ 'class:hinge|classic' => 'none' })
  NxTest.assert_equal([], errs, errs.inspect)
  NxTest.assert_equal('none', out['class:hinge|classic'])
  NxTest.assert_equal(['none'], c::HWS.value_set_ids('none'), 'snapshot ho MUSÍ zmraziť')
  exp = c::HWS.expand([c.item('classic')],
                      { 'mapping' => { 'class:hinge|classic' => 'none' },
                        'sets' => { 'none' => mine } })
  NxTest.assert_equal([], exp['unmapped'], exp['unmapped'].inspect)
  NxTest.assert_equal(c.codes(c::HWS.expand([c.item('classic')],
                                            c.state('class:hinge|classic' => 'zaves-klasik'))),
                      c.codes(exp), 'nakúpi presne to, čo ten istý set pod iným ID')
end

NxTest.test('KOV-F1 (7): sentinel prežije zmrazenie globálu aj „Doplniť nové predvoľby"') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxKovF
  # Codex #329 kolo 1 P2: obe kopírovacie cesty preskakovali mapovanie
  # s PRÁZDNYM zoznamom referencií — a sentinel na žiadny set neukazuje.
  # Nový projekt by tak dostal kľúč zmazaný a spadol na legacy `hinge`, hoci
  # UI tvrdí, že globálna voľba platí.
  c.with_library do
    c.install('std' => c::HWS::STD_CLASSIFIED, 'seed_version' => c::HWS::SEED_VERSION,
              'sets' => [c.set_def('zaves-klasik')],
              'mapping' => { 'hinge' => 'zaves-klasik',
                             'class:hinge|tipon' => c::HWS::MAPPING_NONE })
    NxTest.assert_equal(:ok, c::HWS.library_state, c::HWS.library_state_reason)
    gd = c::HWS.global_default_state
    NxTest.assert_equal(c::HWS::MAPPING_NONE, gd['mapping']['class:hinge|tipon'],
                        'nový projekt musí zdediť „vedome bez setu"')
    # Doplnenie do EXISTUJUCEHO snapshotu (vedoma akcia pouzivatela).
    m = c.fake_model(JSON.generate(c.snapshot_of([c.set_def('zaves-klasik')],
                                                 'hinge' => 'zaves-klasik')))
    status, _added_sets, added_map, = c::HWS.merge_project_sets_seed!(m)
    NxTest.assert_equal(:updated, status)
    NxTest.assert(added_map.include?('class:hinge|tipon'), added_map.inspect)
    _ok, state = c::HWS.project_state_status(m)
    NxTest.assert_equal(c::HWS::MAPPING_NONE, state['mapping']['class:hinge|tipon'],
                        'a snapshot ho po uložení naozaj nesie')
    sid, reason, = c::HWS.resolve_set_id('hinge', c.item('tipon'), {}, state['mapping'])
    NxTest.assert_equal([nil, 'set_none'], [sid, reason], 'resolver ho rešpektuje')
  end
end

NxTest.test('KOV-F1 (7): migrácia mapovania je JEDNORAZOVÁ a vlastný set prežije') do
  c = NxKovF
  # Projekt s VLASTNYM (klasifikovanym) zavesom v legacy mapovani.
  mine = c.set_def('zaves-klasik').merge('set_id' => 'moj-zaves', 'name' => 'Môj záves')
  defs = { 'moj-zaves' => mine, 'zaves-p2o' => c.set_def('zaves-p2o') }
  st = { 'mapping' => { 'hinge' => 'moj-zaves' }, 'sets' => defs, 'migrations' => [] }
  model = NxKovF.fake_model
  out = c::HWS.migrate_hinge_classes!(model, st)
  NxTest.assert_equal('moj-zaves', out['mapping']['class:hinge|classic'],
                      'triedny kľúč sa odvodí z ÚČINNÉHO legacy mapovania')
  NxTest.assert_equal('zaves-p2o', out['mapping']['class:hinge|tipon'])
  NxTest.assert_equal('moj-zaves', out['mapping']['hinge'], 'legacy kľúč ostáva')
  NxTest.assert(out['migrations'].include?('hinge_class_v1'), 'značka jednorazovosti')
  # Druhy beh uz NIC nemeni (aj ked si kluc pouzivatel zmaze).
  st2 = JSON.parse(JSON.generate(out))
  st2['mapping'].delete('class:hinge|classic')
  again = c::HWS.migrate_hinge_classes!(model, st2)
  NxTest.refute(again['mapping'].key?('class:hinge|classic'), 'jednorazovo znamená JEDNORAZOVO')
end

NxTest.test('KOV-F1 (7): migrácia NEPREPÍŠE existujúci kľúč ani vlastný Tip-On set') do
  c = NxKovF
  tip = c.set_def('zaves-p2o').merge('set_id' => 'moj-tipon', 'name' => 'Môj Tip-On')
  defs = { 'zaves-klasik' => c.set_def('zaves-klasik'), 'moj-tipon' => tip,
           'zaves-p2o' => c.set_def('zaves-p2o') }
  st = { 'mapping' => { 'hinge' => 'zaves-klasik', 'class:hinge|tipon' => 'moj-tipon' },
         'sets' => defs, 'migrations' => [] }
  out = c::HWS.migrate_hinge_classes!(NxKovF.fake_model, st)
  NxTest.assert_equal('moj-tipon', out['mapping']['class:hinge|tipon'], 'existujúci kľúč sa nikdy neprepíše')
  # A ked ma pouzivatel VLASTNY tipon set BEZ kluca, kluc sa NEVYROBI.
  st2 = { 'mapping' => { 'hinge' => 'zaves-klasik' }, 'sets' => defs, 'migrations' => [] }
  out2 = c::HWS.migrate_hinge_classes!(NxKovF.fake_model, st2)
  NxTest.refute(out2['mapping'].key?('class:hinge|tipon'),
                'vlastný Tip-On set = seed sa nevnucuje')
end

NxTest.test('KOV-F1 (7): NEKLASIFIKOVANÝ legacy set = nákup ako doteraz + ORANGE poznámka') do
  c = NxKovF
  legacy_set = { 'set_id' => 'zaves-klasik', 'name' => 'Záves KLASIK',
                 'generic_type' => 'hinge',
                 'members' => [{ 'code' => '104717', 'per' => 'unit', 'qty' => 1 }] }
  st = { 'mapping' => { 'hinge' => 'zaves-klasik' },
         'sets' => { 'zaves-klasik' => c::HWS.normalize_sets([legacy_set]).first } }
  exp = c::HWS.expand([c.item('classic')], st)
  NxTest.assert_equal([['104717', 2]], c.codes(exp), 'nákup beží ďalej (kódy set MÁ)')
  NxTest.assert_equal([], exp['unmapped'], 'nezaradený set NIE JE nesúlad')
  NxTest.assert_equal(1, exp['notes'].length, exp['notes'].inspect)
  NxTest.assert_equal('hinge_set_unclassified', exp['notes'].first['code'])
  items = []
  c::V.check_hardware_notes(exp, items)
  NxTest.assert_equal(1, items.length)
  NxTest.assert_equal(c::V::ORANGE, items.first['severity'])
  NxTest.assert(items.first['message_sk'].include?('Doplniť nové predvoľby'))
end

# ============================================================================
# 8 — EXPANZIA: SET PODLA OTVARANIA
# ============================================================================

NxTest.test('KOV-F1 (8): Tip-On čelo dostane P2O set + 1 piest na KRÍDLO') do
  c = NxKovF
  st = c.state('class:hinge|classic' => 'zaves-klasik', 'class:hinge|tipon' => 'zaves-p2o',
               'hinge' => 'zaves-klasik')
  (1..4).each do |wings|
    items = (1..wings).map { |i| c.item('tipon', "front:F1/wing:p#{i}", 2) }
    exp = c::HWS.expand(items, st)
    NxTest.assert_equal([], exp['unmapped'], exp['unmapped'].inspect)
    rows = exp['rows'].each_with_object({}) { |r, o| o[r['code']] = r['quantity'] }
    NxTest.assert_equal(wings, rows['250831'], "#{wings} krídla = #{wings} piesty (per owner)")
    NxTest.assert_equal(2 * wings, rows['245723'], 'závesov je počet × krídla')
    NxTest.refute(rows.key?('104717'), 'klasický záves sa NIKDY nepridá k Tip-On čelu')
  end
  # Klasicke celo dostane klasicky set.
  exp = c::HWS.expand([c.item('classic')], st)
  NxTest.assert_equal([['104717', 2], ['105408', 2], ['105425', 2], ['106412', 2]], c.codes(exp))
end

NxTest.test('KOV-F1 (8): Tip-On čelo na klasickom sete = RED `hinge_set_mismatch`') do
  c = NxKovF
  st = c.state('class:hinge|tipon' => 'zaves-klasik', 'hinge' => 'zaves-klasik')
  exp = c::HWS.expand([c.item('tipon')], st)
  NxTest.assert_equal([], exp['rows'], 'nákup by bol bez závesov — radšej NIČ')
  u = exp['unmapped'].first
  NxTest.assert_equal(c::HWS::HINGE_SET_MISMATCH, u['reason'])
  NxTest.assert_equal('opening_mode', u['detail'])
  NxTest.assert(c::HWS.unmapped_reason_sk(u).include?('vyber správny set'))
  items = []
  c::V.check_hardware_expansion(exp, items)
  NxTest.assert_equal(1, items.length)
  NxTest.assert_equal(c::V::RED, items.first['severity'])
  NxTest.assert(items.first['message_sk'].include?('Doplniť nové predvoľby'))
end

NxTest.test('KOV-F1 (8): závesový set INÉHO TYPU kovania je RED, nie ORANGE') do
  c = NxKovF
  # Codex #329 kolo 1 P2: mapovanie zo šablóny môže ukázať na `set_id`, ktorého
  # definíciu si projekt drží VLASTNÚ — a tá môže byť setom na nohy. Táto vetva
  # je SKORŠIA než kontrola klasifikácie, takže bez povýšenia by nákup ostal
  # BEZ ZÁVESOV a ORANGE by zákazku pustil von.
  legs = c.seed_sets.find { |s| s['generic_type'] == 'leg' }
  st = { 'mapping' => { 'class:hinge|classic' => legs['set_id'] },
         'sets' => { legs['set_id'] => legs } }
  exp = c::HWS.expand([c.item('classic')], st)
  NxTest.assert_equal([], exp['rows'], 'nákup by bol bez závesov — radšej NIČ')
  u = exp['unmapped'].first
  NxTest.assert_equal(c::HWS::HINGE_SET_MISMATCH, u['reason'])
  NxTest.assert_equal('generic_type', u['detail'])
  NxTest.assert(c::HWS.unmapped_reason_sk(u).include?('iného typu'), c::HWS.unmapped_reason_sk(u))
  items = []
  c::V.check_hardware_expansion(exp, items)
  NxTest.assert_equal(c::V::RED, items.first['severity'], 'RED brána, nie ORANGE')
  NxTest.assert(c::BP.hw_blockers.include?(c::HWS::HINGE_SET_MISMATCH), 'a kód je v registri brán')
  # LEGACY položka (bez klasifikácie) ostáva na ORANGE `set_type_mismatch`.
  legacy = c::HWS.expand([c.legacy_item],
                         { 'mapping' => { 'hinge' => legs['set_id'] },
                           'sets' => { legs['set_id'] => legs } })
  NxTest.assert_equal('set_type_mismatch', legacy['unmapped'].first['reason'],
                      'nezmenené správanie pre položku bez `use_type`')
end

NxTest.test('KOV-F1 (8): precedencia — vlastný set NA SKRINKE prežije prestavbu') do
  c = NxKovF
  mine = c.set_def('zaves-p2o').merge('set_id' => 'moj-zaves', 'name' => 'Môj záves',
                                      'opening_mode' => 'classic')
  st = { 'mapping' => { 'class:hinge|classic' => 'zaves-klasik', 'hinge' => 'zaves-klasik' },
         'sets' => { 'zaves-klasik' => c.set_def('zaves-klasik'), 'moj-zaves' => mine } }
  # GENERICKY override skrinky ma prednost pred TRIEDNYM klucom projektu.
  exp = c::HWS.expand([c.item('classic')], st, cabinet_overrides: { 'CAB-1' => { 'hinge' => 'moj-zaves' } })
  NxTest.assert(exp['rows'].any? { |r| r['code'] == '245723' },
                "vlastný set skrinky NIKDY ticho nespadne na projektový default: #{c.codes(exp).inspect}")
  # TRIEDNY override skrinky ma prednost pred generickym.
  ov = { 'CAB-1' => { 'hinge' => 'moj-zaves', 'class:hinge|classic' => 'zaves-klasik' } }
  exp2 = c::HWS.expand([c.item('classic')], st, cabinet_overrides: ov)
  NxTest.assert(exp2['rows'].any? { |r| r['code'] == '104717' }, c.codes(exp2).inspect)
  # OVERRIDE VLASTNIKA je nad vsetkym.
  ov2 = { 'CAB-1' => { 'hinge' => 'zaves-klasik',
                       'hinge@front:F1/wing:single' => 'moj-zaves' } }
  exp3 = c::HWS.expand([c.item('classic')], st, cabinet_overrides: ov2)
  NxTest.assert(exp3['rows'].any? { |r| r['code'] == '245723' }, c.codes(exp3).inspect)
end

NxTest.test('KOV-F1 (8): bez triedneho kľúča padne záves na LEGACY `hinge`') do
  c = NxKovF
  st = c.state({ 'hinge' => 'zaves-klasik' }, %w[zaves-klasik])
  exp = c::HWS.expand([c.item('classic')], st)
  NxTest.assert_equal([], exp['unmapped'], 'existujúca zákazka po prestavbe NESMIE stratiť závesy')
  NxTest.assert_equal(4, exp['rows'].length)
  # LEGACY polozka (bez params) sa sprava presne ako doteraz.
  NxTest.assert_equal(nil, c::HWS.class_key_for(c.legacy_item, 'hinge'))
  NxTest.assert_equal(c.codes(exp), c.codes(c::HWS.expand([c.legacy_item], st)))
  # A ked nie je ZIADNE mapovanie, dovod ostava dnesny `no_set`.
  empty = c::HWS.expand([c.item('classic')], { 'mapping' => {}, 'sets' => {} })
  NxTest.assert_equal('no_set', empty['unmapped'].first['reason'])
end

# ============================================================================
# 9 — BRANY EXPORTU
# ============================================================================

NxTest.test('KOV-F1 (9): jediný register brán — závesové kódy sú v ňom, VEPO neblokujú') do
  c = NxKovF
  reg = c::BP.hw_blockers
  c::REC::DRAWER_BLOCKERS.each { |code| NxTest.assert(reg.include?(code), "chýba #{code}") }
  NxTest.assert_equal(c::REC::DRAWER_BLOCKERS, reg[0, c::REC::DRAWER_BLOCKERS.length],
                      'zásuvkové kódy si držia PORADIE — vety brány sa nesmú prehádzať')
  NxTest.assert_equal(c::BP::HW_HINGE_BLOCKERS, reg[c::REC::DRAWER_BLOCKERS.length..])
  reg.each do |code|
    label = c::REC::BLOCKER_LABELS[code] || c::BP::HW_BLOCKER_LABELS[code]
    NxTest.assert(label, "kód #{code} nemá vetu brány")
  end
end

NxTest.test('KOV-F1 (9): `door_height_out_of_table` zastaví nákup, rozpočet a ponuku — VEPO nie') do
  c = NxKovF
  collected = { hardware_issues: [{ 'code' => c::HR::DOOR_OUT_OF_TABLE, 'owner_id' => 'CAB-7' }],
                hardware: [] }
  all = c::PC.hardware_blockers(collected, nil)
  NxTest.assert_equal(1, all.length, all.inspect)
  NxTest.assert(all.first.include?('CAB-7'), all.first)
  NxTest.assert(all.first.include?('tabuľka závesov'), all.first)
  NxTest.assert_equal([], c::PC.hardware_blockers(collected, nil, scope: :kit),
                      'VEPO sa nezastavuje — geometria je správna')
  NxTest.assert_equal(all, c::PC.export_blockers(hardware: all), 'brána ide cez ten istý vstup')
end

NxTest.test('KOV-F1 (9): `hinge_set_mismatch` číta brána z EXPANZIE (nie z uloženého stavu)') do
  c = NxKovF
  exp = { 'unmapped' => [{ 'reason' => c::HWS::HINGE_SET_MISMATCH, 'cabinet_id' => 'CAB-3' }] }
  out = c::PC.hardware_blockers({ hardware_issues: [], hardware: [] }, exp)
  NxTest.assert_equal(1, out.length, out.inspect)
  NxTest.assert(out.first.include?('CAB-3'), out.first)
  NxTest.assert_equal([], c::PC.hardware_blockers({ hardware_issues: [], hardware: [] },
                                                  exp, scope: :kit))
end

NxTest.test('KOV-F1 (9): zásuvkové brány ostali BAJTOVO ROVNAKÉ') do
  c = NxKovF
  collected = { hardware_issues: [{ 'code' => 'drawer_no_fit', 'owner_id' => 'CAB-1' },
                                  { 'code' => c::REC::STALE, 'owner_id' => 'CAB-2' }],
                hardware: [] }
  exp = { 'unmapped' => [{ 'reason' => c::REC::KIT_MISSING, 'cabinet_id' => 'CAB-1' }] }
  all = c::PC.hardware_blockers(collected, exp)
  NxTest.assert_equal(
    ['zásuvka sa do skrinky nezmestí (CAB-1) — oprav to v sekcii Kontrola',
     'nákup nenašiel kit výsuvu k postaveným dielcom (CAB-1) — oprav to v sekcii Kontrola',
     'zásuvka je klasifikovaná ešte spred aktivovania receptov (CAB-2) — oprav to v sekcii Kontrola'],
    all
  )
  NxTest.assert_equal(
    ['nákup nenašiel kit výsuvu k postaveným dielcom (CAB-1) — oprav to v sekcii Kontrola',
     'zásuvka je klasifikovaná ešte spred aktivovania receptov (CAB-2) — oprav to v sekcii Kontrola'],
    c::PC.hardware_blockers(collected, exp, scope: :kit)
  )
end

# ============================================================================
# 10 — CONFIG_SCHEMA 9 (Codex #329 kolo 1 P1)
# ============================================================================

NxTest.test('KOV-F1 (10): trvalý nosič a klasifikované závesy si vyžiadali schému 9') do
  c = NxKovF
  # PRESNE cislo strazi VZDY najnovsia davka, ktora ho zdvihla (vzor KOV-D1a R3).
  NxTest.assert_equal(9, c::CB::CONFIG_SCHEMA, 'KOV-F1 zaviedla schému 9')
  NxTest.assert_equal(5, c::CB::DRAWER_ACTIVATION_SCHEMA, 'aktivácia zásuviek sa bumpom nehýbe')
  cfg = c::CB.normalize('width' => 600.0, 'height' => 720.0, 'depth' => 500.0)
  written = c::CB.cabinet_config(cfg)
  NxTest.assert_equal(9, written[:config_schema], 'marker sa zapisuje pri KAŽDOM zápise configu')
  NxTest.assert_equal([], written[:hardware_conflicts],
                      'nosič `hardware_conflicts` je v configu VŽDY — aj prázdny')
end

NxTest.test('KOV-F1 (10): DOWNGRADE — config novšej schémy sa NEPRESTAVIA, staršie sa načítajú') do
  c = NxKovF
  cur = c::CB::CONFIG_SCHEMA
  # Starsi plugin sa tu simuluje POSUNUTIM configu o jedno cislo vyssie —
  # `newer_config?` porovnava PRESNE tak, ako by ho porovnal citac schemy 8
  # nad configom 9 (vzor charakterizacie KOV-D1a R3; stary plugin sa spustit
  # neda). Odmietnutie MA hlasku — ticha strata pola je presne to, comu bump
  # branil (Codex #329 P1).
  NxTest.assert(c::CB.newer_config?('config_schema' => cur + 1))
  inst = NxTest::FakeEntity.new
  inst.set_attribute(c::E::Store::DICT, 'config', JSON.generate('config_schema' => cur + 1))
  err = NxTest.assert_raise(/novšej verzie/) { c::CB.guard_newer_config!(inst) }
  NxTest.assert(err.message.include?('novší plugin'), err.message)
  # Opacny smer: KAZDA staršia schema (aj legacy 0 bez markera) sa cita dalej.
  (0..cur).each do |s|
    NxTest.refute(c::CB.newer_config?('config_schema' => s), "schéma #{s} je čitateľná")
  end
  NxTest.refute(c::CB.newer_config?({}), 'legacy korpus bez markera nikdy neblokuje')
  # A pri PRESTAVBE dostane stara skrinka aktualnu schemu — nosic aj
  # klasifikacia sa tym padom zapisu pod spravnym cislom.
  old = c::CB.normalize('config_schema' => 8, 'width' => 600.0,
                        'height' => 720.0, 'depth' => 500.0)
  NxTest.assert_equal(cur, c::CB.cabinet_config(old)[:config_schema],
                      'prestavba prepíše marker na aktuálny')
end

# ============================================================================
# POMOCNY MODEL (zapis snapshotu bez SketchUpu)
# ============================================================================

module NxKovF
  # Minimalny nahradnik `Sketchup::Model` pre zapisove cesty snapshotu:
  # `write_project_state` cita a pise JEDEN atribut.
  class FakeModel
    attr_reader :raw

    def initialize(raw = nil)
      @raw = raw
    end

    def get_attribute(_dict, _key)
      @raw
    end

    def set_attribute(_dict, _key, value)
      @raw = value
      true
    end
  end

  module_function

  def fake_model(raw = nil)
    FakeModel.new(raw)
  end

  # --- sandbox globalnej kniznice (vzor `test_kovc2a_kanal_sety.rb`) --------
  # Codex #329 kolo 1 P2 si vyziadal test nad ZMRAZENIM globalnych predvolieb,
  # a to je jedina cesta tejto sady, ktora saha na %APPDATA% (len headless).
  def with_library
    paths = [HWS.path, E::HardwareTaxonomy.path]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    # Sandbox je ZDIELANY celym behom — skorsie sady v nom mohli nechat
    # taxonomiu v stave `:read_only`; pri prvom pristupe sa naseeduje cerstva.
    FileUtils.rm_f(E::HardwareTaxonomy.path)
    FileUtils.rm_f("#{E::HardwareTaxonomy.path}.bak")
    E::JsonFileStore.invalidate(E::HardwareTaxonomy.path)
    E::HardwareTaxonomy.reset_state!
    yield
  ensure
    before.each do |(p, raw)|
      raw ? File.binwrite(p, raw) : FileUtils.rm_f(p)
      FileUtils.rm_f("#{p}.bak")
      E::JsonFileStore.invalidate(p)
    end
    HWS.reset_library_state!
    E::HardwareTaxonomy.reset_state!
  end

  def install(doc)
    FileUtils.mkdir_p(File.dirname(HWS.path))
    File.binwrite(HWS.path, JSON.pretty_generate(doc))
    E::JsonFileStore.invalidate(HWS.path)
    HWS.reset_library_state!
    true
  end

  def snapshot_of(sets, mapping)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'std' => HWS.snapshot_std(mapping, by_id.values), 'mapping' => mapping, 'sets' => by_id }
  end
end
