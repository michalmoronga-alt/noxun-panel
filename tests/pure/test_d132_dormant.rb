# frozen_string_literal: true
# Testy D-132: DORMANTNY ZAMOK OSI ZASUVKY JE VIDITELNY A DA SA ZRUSIT.
#
# Problem, ktory davka riesi: po prepnuti otvarania (classic <-> Tip-On) sa
# pripne INY recept a stary zaznam `hardware_overrides` ostane v configu —
# resolver ho nepouzije (KOV-D4 bod 3) a doteraz ho NEKRESLIL ani riadok
# rucnych zasahov, lebo `override_orphan_kind` vratil `nil`. Pouzivatel taky
# zamok nevedel zrusit, kym sa nevratil k povodnemu otvaraniu — a tam sa
# zamok „prebudil".
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 ZIADNA zmena kontraktu ani normalizacie — dormantny zaznam OSTAVA
#      v configu, davka ho len UKAZE a da zrusit (`reset: true`).
#   R2 klasifikacia je CISTA funkcia so zavaznym poradim:
#      ma polozku -> nil · `disabled` · `invalid` · `dormant` · inak nil.
#      Bez `active_rules`/`front_owners` (legacy volanie) sa dormantnost
#      NEVYHODNOCUJE — kto nevidi pripnute recepty ciel, nesmie hadat.
#   R3 TEXTY riadku sklada SERVER (`orphan_label` + `orphan_note`), nie JS.
#   R4 AKTIVNY zamok sa nemeni ani o bajt (ziadny `orphan`, chipy ostavaju).
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
#   M1 `override_dormant_why` vyhodnoti dormantnost aj bez `active_rules`
#      -> „D-132 (h): LEGACY volanie s 3 argumentmi dormantnost NEHADA"
#   M2 `attach_override_axes` prilepi chipy aj dormantnemu zaznamu
#      -> „D-132 (R4): dormantny riadok chipy osi NEDOSTANE"
#   M3 texty riadku sklada JS (server posle len `orphan_kind`)
#      -> „D-132 (R3): nadpis aj dovod riadku sklada SERVER"
#   M4 `invalid` uz nema prednost pred `dormant`
#      -> „D-132 (c): ULOZENY KONFLIKT vitazi nad dormantnostou"
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads') if NxTest.headless?

module NxD132
  module_function

  def e
    Noxun::Engine
  end

  def hr
    e::HardwareRules
  end

  def panel
    e::Panel
  end

  def cb
    e::CabinetBuilder
  end

  OWNER  = 'front:F1/panel'
  OTHER  = 'front:F9/panel'
  SISY   = 'recipe:atira_sisy_v1'
  TIPON  = 'recipe:atira_p2o_v1'
  QUADRO = 'recipe:quadro_v6_sisy_v1'
  LEGACY = 'vysuvy-nl-podla-hlbky'

  # Zaznam `hardware_overrides` v ulozenom tvare (string kluce, mm Float).
  def ov(extra = {}, rule_id = SISY, owner = OWNER)
    { 'owner_part_key' => owner, 'generic_type' => 'slide',
      'rule_id' => rule_id }.merge(extra)
  end

  # Mapa PRIPNUTYCH receptov (`Panel.active_lock_rules`) a zoznam vlastnikov
  # EXISTUJUCICH ciel (`Panel.front_owner_keys`).
  def pinned(rule_id = TIPON, owner = OWNER)
    { owner => rule_id }
  end

  def fronts(*owners)
    owners.empty? ? [OWNER] : owners
  end

  # --- fixtury REALNEJ zakazky (rovnaka skrinka ako KOV-D4) -----------------
  def params(front = {})
    item = { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
             'height' => 175.0, 'opening_mode' => 'classic',
             'drawer' => { 'construction' => 'metal' } }.merge(front)
    { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
      'thickness' => 18.0, 'floor_height' => 100.0,
      'fronts' => { 'items' => [item] } }
  end

  def cfg_for(par, overrides = [])
    norm = cb.normalize(par.merge('hardware_overrides' => overrides))
    plan = e::Construction.build_plan(norm, 'CAB-1',
                                      part_thicknesses: cb.drawer_thicknesses(norm, {}))
    JSON.parse(JSON.generate(cb.cabinet_config(cb.merge_final(norm, plan))))
  end

  def index_for(cfg)
    panel.drawer_axes_index(cfg, cb.config_to_params(cfg))
  end

  # Riadky presne tak, ako ich vidi PANEL (s `orphan`, `orphan_label`, notou).
  def rows_for(cfg)
    panel.hardware_overrides_payload(cfg, cfg['hardware_overrides'], index_for(cfg))
  end

  def row_of(cfg, rule_id)
    rows_for(cfg).find { |r| r['rule_id'].to_s == rule_id }
  end
end

# ============================================================================
# R2 — TABULKA KLASIFIKACIE (`override_orphan_kind`)
# ============================================================================

NxTest.test('D-132 (a,b): zaznam s polozkou nie je osiroteny, `disabled` ostava `disabled`') do
  c = NxD132
  rec = c.ov('nominal_length' => 470.0)
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(rec, [rec], [], c.pinned, c.fronts),
                      'zaznam so ZIVOU polozkou sa kresli PRI nej')
  off = c.ov('disabled' => true, 'nominal_length' => 470.0)
  NxTest.assert_equal('disabled', c.hr.override_orphan_kind(off, [], [], c.pinned, c.fronts),
                      'vypnuta kategoria ma vlastnu napravu („obnoviť") — dormantnost ju neprebije')
end

# M4
NxTest.test('D-132 (c): ULOZENY KONFLIKT vitazi nad dormantnostou') do
  c = NxD132
  rec = c.ov('nominal_length' => 470.0)
  NxTest.assert_equal('invalid',
                      c.hr.override_orphan_kind(rec, [], [NxD132::OWNER], c.pinned, c.fronts),
                      'konflikt blokuje exporty — jeho riadok to musi povedat prednostne')
end

NxTest.test('D-132 (d,e,f): tri dovody dormantnosti — iny recept, nie zasuvka, ziadne celo') do
  c = NxD132
  nl = c.ov('nominal_length' => 470.0)
  NxTest.assert_equal(['dormant', 'other_recipe'],
                      [c.hr.override_orphan_kind(nl, [], [], c.pinned, c.fronts),
                       c.hr.override_dormant_why(nl, c.pinned, c.fronts)],
                      'vlastnik ma pripnuty INY recept (ine otvaranie)')
  h = c.ov({ 'height_variant' => 144 }, NxD132::SISY)
  NxTest.assert_equal(['dormant', 'not_drawer'],
                      [c.hr.override_orphan_kind(h, [], [], {}, c.fronts),
                       c.hr.override_dormant_why(h, {}, c.fronts)],
                      'celo existuje, ale ziadny recept pripnuty nema (je to dvierka)')
  b = c.ov({ 'box_height' => 300.0 }, NxD132::QUADRO)
  NxTest.assert_equal(['dormant', 'no_front'],
                      [c.hr.override_orphan_kind(b, [], [], {}, [NxD132::OTHER]),
                       c.hr.override_dormant_why(b, {}, [NxD132::OTHER])],
                      'celo, ktoremu zamok patril, uz medzi celami nie je')
end

NxTest.test('D-132 (g): zaznam receptovej identity BEZ pola zamku dormantny NIE JE') do
  c = NxD132
  qty = c.ov('quantity' => 3)
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(qty, [], [], c.pinned, c.fronts),
                      'rucny POCET bez konfliktu nie je osiroteny (spravanie spred D-132)')
  # Neplatny TVAR hodnoty nie je zamok — plati ten isty citac ako v resolveri.
  bad = c.ov('nominal_length' => 0.0, 'height_variant' => 144.5)
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(bad, [], [], c.pinned, c.fronts),
                      'nula ani desatinny vyskovy variant zamok nenesu')
end

# M1
NxTest.test('D-132 (h): LEGACY volanie s 3 argumentmi dormantnost NEHADA') do
  c = NxD132
  nl = c.ov('nominal_length' => 470.0)
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(nl, [], []),
                      'kto nevidi pripnute recepty ciel, nesmie hadat')
  NxTest.assert_equal(nil, c.hr.override_dormant_why(nl, nil, nil))
  NxTest.assert_equal(nil, c.hr.override_dormant_why(nl, c.pinned, nil),
                      'aj chybajuci zoznam ciel = ziadne rozhodnutie')
end

NxTest.test('D-132 (i): dormantny je LEN zamok osi — ine kovanie ani legacy pravidlo nie') do
  c = NxD132
  hinge = c.ov({ 'generic_type' => 'hinge', 'quantity' => 2 }, 'zavesy')
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(hinge, [], [], c.pinned, c.fronts),
                      'zavesy zamok osi nemaju')
  custom = c.ov({ 'nominal_length' => 470.0 }, 'nohy-standard')
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(custom, [], [], c.pinned, c.fronts),
                      'nereceptove `rule_id` identitu zamku nenesie')
  # Legacy `vysuvy-nl-podla-hlbky` cita `Recipes.lock_value` pri KAZDOM recepte,
  # takze na cele s pripnutym receptom je ZIVY — nie dormantny.
  legacy = c.ov({ 'nominal_length' => 470.0 }, NxD132::LEGACY)
  NxTest.assert_equal(nil, c.hr.override_orphan_kind(legacy, [], [], c.pinned, c.fronts),
                      'legacy zamok pripnuty recept POUZIJE — „čaká" by bola lez')
  NxTest.assert_equal('not_drawer', c.hr.override_dormant_why(legacy, {}, c.fronts),
                      'ale na cele BEZ receptu (dvierka) caka rovnako ako receptovy')
  NxTest.assert_equal(nil, c.hr.override_dormant_why(c.ov('nominal_length' => 470.0),
                                                     { NxD132::OWNER => NxD132::SISY }, c.fronts),
                      'zaznam PRIPNUTEHO receptu dormantny nie je (to je aktivny zamok)')
end

# ============================================================================
# R3 — TEXTY RIADKU SKLADA SERVER
# ============================================================================

# M3
NxTest.test('D-132 (R3): nadpis aj dovod riadku sklada SERVER') do
  c = NxD132
  cfg = c.cfg_for(c.params, [c.ov({ 'nominal_length' => 470.0 }, NxD132::TIPON)])
  row = c.row_of(cfg, NxD132::TIPON)
  NxTest.refute(row.nil?, 'dormantny zaznam je v payloade')
  NxTest.assert_equal([true, 'dormant'], [row['orphan'], row['orphan_kind']])
  NxTest.assert_equal('Dormantný zámok · NL 470', row['orphan_label'],
                      'nadpis nesie LEN osi, ktore zaznam naozaj drzi')
  NxTest.assert(row['orphan_note'].include?('Atira Tip-On v1') &&
                row['orphan_note'].include?('Atira SiSy v1'),
                "poznamka menuje OBA recepty: #{row['orphan_note'].inspect}")
  NxTest.assert(row['orphan_note'].include?('Zrušiť ho môžeš tu.'),
                'a konci cestou von (riadok ma tlacidlo „zrušiť")')
  NxTest.assert_equal(nil, row['axes'],
                      'chipy NEDOSTANE — ukazovali by stav CUDZIEHO receptu (KOV-D4 bod 3)')
end

NxTest.test('D-132 (R3): nadpis nesie VSETKY osi zaznamu v poradi resolvera') do
  c = NxD132
  all = c.ov({ 'nominal_length' => 470.5, 'height_variant' => 144, 'box_height' => 300.0 },
             NxD132::TIPON)
  NxTest.assert_equal('Dormantný zámok · H144 · box 300 · NL 470,5',
                      c.panel.dormant_label(all),
                      'vyska rozhoduje PRED radom NL — poradie textu to zrkadli')
  NxTest.assert_equal('Dormantný zámok · box 300',
                      c.panel.dormant_label(c.ov({ 'box_height' => 300.0 }, NxD132::QUADRO)),
                      'os, ktoru zaznam nenesie, sa v nadpise NEOBJAVI')
end

NxTest.test('D-132 (R3): dovod ma vlastnu vetu pre kazdy podtyp') do
  c = NxD132
  rec = c.ov({ 'nominal_length' => 470.0 }, NxD132::TIPON)
  other = c.panel.dormant_note(rec, 'other_recipe', { NxD132::OWNER => NxD132::SISY })
  NxTest.assert(other.include?('teraz je pripnutý Atira SiSy v1'), other)
  nod = c.panel.dormant_note(rec, 'not_drawer', {})
  NxTest.assert(nod.include?('čelo už nie je zásuvka'), nod)
  none = c.panel.dormant_note(rec, 'no_front', {})
  NxTest.assert(none.include?('už neexistuje'), none)
  # Nezname ID receptu sa NEHADA — veta ostane pravdiva aj bez mena.
  raw = c.panel.dormant_note(c.ov({ 'nominal_length' => 470.0 }, 'recipe:cudzi_x'), 'no_front', {})
  NxTest.assert(raw.start_with?('Zámok —'), raw)
end

NxTest.test('D-132 (R3): dvierka a zaniknute celo maju svoj riadok tiez') do
  c = NxD132
  door = c.cfg_for(c.params('type' => 'door'),
                   [c.ov({ 'nominal_length' => 470.0 }, NxD132::SISY)])
  row = c.row_of(door, NxD132::SISY)
  NxTest.refute(row.nil?, 'zaznam prezil prechod na dvierka (KOV-D4 pamat)')
  NxTest.assert_equal(['dormant', 'not_drawer'],
                      [row['orphan_kind'],
                       c.hr.override_dormant_why(row, {}, [NxD132::OWNER])])
  NxTest.assert(row['orphan_note'].include?('zásuvka'), row['orphan_note'])

  gone = c.cfg_for(c.params, [c.ov({ 'nominal_length' => 470.0 }, NxD132::TIPON, NxD132::OTHER)])
  grow = c.rows_for(gone).find { |r| r['owner_part_key'] == NxD132::OTHER }
  NxTest.assert_equal('dormant', grow['orphan_kind'], 'celo F9 v zakazke nie je')
  NxTest.assert(grow['orphan_note'].include?('už neexistuje'), grow['orphan_note'])
end

# ============================================================================
# R4 — AKTIVNY ZAMOK SA NEMENI ANI O BAJT
# ============================================================================

# M2
NxTest.test('D-132 (R4): dormantny riadok chipy osi NEDOSTANE') do
  c = NxD132
  cfg = c.cfg_for(c.params, [c.ov({ 'nominal_length' => 420.0 }, NxD132::SISY),
                             c.ov({ 'nominal_length' => 520.0 }, NxD132::TIPON)])
  index = c.index_for(cfg)
  rows = c.panel.attach_override_axes(
    c.panel.hardware_overrides_payload(cfg, cfg['hardware_overrides'], index), index
  )
  by_rule = rows.each_with_object({}) { |r, o| o[r['rule_id']] = r }
  NxTest.assert_equal(420.0, by_rule[NxD132::SISY]['axes']['nl']['value'],
                      'PRIPNUTY recept ma chipy so svojim zamkom')
  NxTest.refute(by_rule[NxD132::SISY].key?('orphan'),
                'aktivny zamok osiroteny NIE JE — riadok sa kresli pri polozke vysuvu')
  NxTest.assert_equal(nil, by_rule[NxD132::TIPON]['axes'],
                      'dormantny zaznam chipy nema ani po `attach_override_axes`')
  NxTest.assert_equal('dormant', by_rule[NxD132::TIPON]['orphan_kind'])
end

NxTest.test('D-132 (R1): payload BEZ indexu je zhodny s tym spred davky') do
  c = NxD132
  cfg = c.cfg_for(c.params, [c.ov({ 'nominal_length' => 470.0 }, NxD132::TIPON)])
  old = c.panel.hardware_overrides_payload(cfg, cfg['hardware_overrides'])
  NxTest.refute(old.first.key?('orphan'),
                'starsi volajuci (bez indexu) dostane presne to, co dostaval')
  NxTest.assert_equal(cfg['hardware_overrides'],
                      c.rows_for(cfg).map { |r| r.reject { |k, _| k.start_with?('orphan') || k == 'owner_label' } },
                      'ULOZENY zaznam sa davkou NEMENI — payload je len zobrazenie')
end
