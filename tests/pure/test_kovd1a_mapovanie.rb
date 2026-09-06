# frozen_string_literal: true
# Testy KOV-D1a: MAPOVANIE — JADRO. Owner triedny kluc, trojurovnova
# precedencia, zapisove operacie s triednym klucom, CONFIG_SCHEMA 6, neaktivny
# set a oprava neplatneho `recipe_refs` zaznamu.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 owner triedny kluc `class:slide|<otvaranie>|<konstrukcia>@front:<id>/panel`
#      — LEN v cabinet override mape; triedna cast normalizovana, owner doslovne;
#      precedencia owner triedny -> triedny -> projekt (nizsie LEN pri
#      NEPRITOMNOM kluci); neexistujuce celo = zaznam prec s logom
#   R2 `set_global_mapping!` / `set_project_mapping!` prijmu triedny kluc (owner
#      NIE), meni sa JEDEN kluc, sety VSETKYCH pasiem sa zmrazia
#   R3 `CONFIG_SCHEMA` 5 -> 6, `DRAWER_ACTIVATION_SCHEMA` ostava 5, forward guard
#   R4 neaktivny set — NOVY vyber odmietnuty, ULOZENA volba zachovana
#   R5 pritomny NEPLATNY `recipe_refs` zaznam = `[:unknown]` -> RED
#      `drawer_recipe_unknown` (nie zahodenie + surodenec/latest)
#   R5b sablony zachovaju owner triedny kluc, `override_keys_in_use` ho pozna,
#      akcia zapisu validuje KAZDE pasmo PRED zapisom
#   R6 charakterizacia — zakazka BEZ owner klucov expanduje identicky
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M1 `parse_mapping` pusti owner triedny kluc aj do globalu/projektu
#      -> „KOV-D1a (R1): owner triedny kluc zije LEN v mape skrinky"
#   M2 `resolve_mapping_value` owner triedny kluc IGNORUJE (padne na skrinku)
#      -> „KOV-D1a (R1): precedencia owner -> skrinka -> projekt"
#   M3 `norm_recipe_refs` zahodi PRITOMNY neplatny zaznam
#      -> „KOV-D1a (R5): neplatny `recipe_refs` zaznam je RED, nie surodenec"
#   M4 zapisova cesta prijme NEAKTIVNY set ako novy vyber
#      -> „KOV-D1a (R4): neaktivny set sa NOVO vybrat neda"
require_relative '../helper' unless defined?(NxTest)

# UI vrstvy (sablony, ochrana kolidujucich kopii, payload karty) — headless nie
# su v require zozname helpera, takze si ich sada pyta sama (vzor KOV-C2a).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_hardware')
end

module NxD1a
  E   = Noxun::Engine
  HWS = E::HardwareSets
  CB  = E::CabinetBuilder
  CN  = E::Construction
  FR  = E::Fronts
  REC = E::Recipes
  PC  = E::ProductionCore
  BP  = E::BuildPlan

  OWNER  = 'front:F1/panel'
  CLASSK = 'class:slide|classic|metal'
  OWNK   = "#{CLASSK}@#{OWNER}"

  module_function

  # --- fixtury -------------------------------------------------------------

  # Receptova polozka vysuvu (Atira, vyskovy variant H70).
  def atira_item(over = {})
    o = over.dup
    params = { 'opening_mode' => 'classic', 'drawer_construction' => 'metal',
               'system' => 'atira', 'height_variant' => 70.0,
               'nominal_length' => 470.0 }.merge(o.delete('params') || {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => OWNER, 'generic_type' => 'slide',
      'quantity' => 1, 'rule_id' => 'recipe:atira_sisy_v1', 'params' => params,
      'source' => 'recipe' }.merge(o)
  end

  # Receptova polozka drevenej zasuvky (Quadro — BEZ vyskoveho variantu).
  def quadro_item(over = {})
    atira_item({ 'raw' => true }.merge(over)).tap do |it|
      it['params'] = { 'opening_mode' => 'classic', 'drawer_construction' => 'wood',
                       'system' => 'quadro_v6', 'nominal_length' => 450.0 }
      it.delete('raw')
    end
  end

  def seed_set(sid)
    HWS.normalize_sets(HWS::SEED_SETS).find { |s| s['set_id'] == sid }
  end

  def state_of(sets, mapping)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'mapping' => mapping, 'sets' => by_id }
  end

  # Projektovy stav = cely seed (to, co dostane novy projekt).
  def seed_state
    lib = HWS.seed_library
    state_of(lib['sets'], lib['mapping'])
  end

  # Vyskovy selektor Atiry pre dane pasma (min == max == vyska setu).
  def height_selector(pairs)
    { 'param' => 'height_variant',
      'bands' => pairs.map { |h, sid| { 'min' => h.to_f, 'max' => h.to_f, 'set_id' => sid } } }
  end

  # Ulozeny config skrinky s jednou receptovou polozkou a danou override mapou.
  def cfg_with(map, items = [atira_item])
    { 'hardware' => items, 'hardware_sets' => map }
  end

  class Model
    def initialize(raw = nil)
      @attrs = {}
      @attrs[E::Store::DICT] = { HWS::MODEL_KEY => raw } unless raw.nil?
    end

    def get_attribute(dict, key)
      (@attrs[dict] || {})[key]
    end

    def set_attribute(dict, key, val)
      (@attrs[dict] ||= {})[key] = val
    end
  end

  def model_with(state)
    m = Model.new
    HWS.write_project_state(m, state)
    m
  end

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end
end

# ============================================================================
# R1 — OWNER TRIEDNY KLUC (parser, precedencia, kompatibilita)
# ============================================================================

NxTest.test('KOV-D1a (R1): kanonicky tvar owner triedneho kluca') do
  h = NxD1a::HWS
  NxTest.assert_equal([NxD1a::OWNK, nil],
                      h.parse_class_key(NxD1a::OWNK, allow_owner: true))
  # Triedna cast sa normalizuje (trim + downcase), OWNER ostava DOSLOVNE —
  # part_key je identita dielca, nie enum.
  NxTest.assert_equal('class:slide|classic|metal@front:F1/panel',
                      h.parse_class_key(' CLASS: Slide | Classic | Metal @front:F1/panel ',
                                        allow_owner: true)[0])
  NxTest.assert_equal(%w[class:slide|classic|metal front:F1/panel],
                      h.class_key_split(NxD1a::OWNK))
  NxTest.assert_equal([NxD1a::CLASSK, nil], h.class_key_split(NxD1a::CLASSK))
  NxTest.assert_equal('slide', h.mapping_key_type(NxD1a::OWNK), 'typ z owner kluca')
  NxTest.assert(h.owner_scoped_key?(NxD1a::OWNK), 'owner triedny kluc je viazany na dielec')
  NxTest.refute(h.owner_scoped_key?(NxD1a::CLASSK), 'bezownerovy triedny nie')
  NxTest.assert(h.owner_scoped_key?('slide@front:F1/panel'), 'legacy composite ostava')

  # Owner MUSI byt panel cela — nic ine (fail-closed: na zonu/dosku by resolver
  # taky override nikdy nepozrel).
  ['class:slide|classic|metal@front:F1', 'class:slide|classic|metal@zone:Z1/shelf:1',
   'class:slide|classic|metal@', 'class:slide|classic|metal@front:F1/panel/x'].each do |bad|
    key, err = h.parse_class_key(bad, allow_owner: true)
    NxTest.assert_equal(nil, key, "#{bad} musi padnut")
    NxTest.assert(err.to_s.include?('panel čela'), "#{bad}: #{err}")
  end
  # Neplatna TRIEDNA cast padne aj s platnym ownerom.
  NxTest.assert_equal(nil, h.parse_class_key('class:hinge|classic|metal@front:F1/panel',
                                             allow_owner: true)[0])
end

NxTest.test('KOV-D1a (R1): owner triedny kluc zije LEN v mape skrinky') do
  h = NxD1a::HWS
  # cabinet override mapa (allow_owner: true) ho PRIJME
  out, errs = h.parse_mapping({ NxD1a::OWNK => 'atira-biela-h70-sisy' }, allow_owner: true)
  NxTest.assert_equal([], errs)
  NxTest.assert_equal({ NxD1a::OWNK => 'atira-biela-h70-sisy' }, out)
  # globalna kniznica / projektovy snapshot (allow_owner: false) ho ODMIETNU
  out2, errs2 = h.parse_mapping({ NxD1a::OWNK => 'atira-biela-h70-sisy' })
  NxTest.assert_equal({}, out2, 'kluc sa do globalu/projektu nedostane')
  NxTest.assert(errs2.first.to_s.include?('na úrovni dielca'), errs2.inspect)
  # a bezownerovy triedny kluc prechadza VSADE dalej (kontrakt KOV-B1)
  NxTest.assert_equal({ NxD1a::CLASSK => 'x' },
                      h.parse_mapping({ NxD1a::CLASSK => 'x' })[0])
end

NxTest.test('KOV-D1a (R1): precedencia owner -> skrinka -> projekt') do
  c = NxD1a
  h = c::HWS
  it = c.atira_item
  proj = { c::CLASSK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }
  cab  = { c::CLASSK => c.height_selector([[70, 'atira-biela-h144-sisy']]) }
  own  = { c::OWNK => c.height_selector([[70, 'atira-biela-h176-sisy']]) }

  NxTest.assert_equal('atira-biela-h176-sisy',
                      h.resolve_set_id('slide', it, { 'CAB-1' => cab.merge(own) }, proj)[0],
                      'owner triedny kluc vyhrava')
  NxTest.assert_equal('atira-biela-h144-sisy',
                      h.resolve_set_id('slide', it, { 'CAB-1' => cab }, proj)[0],
                      'bez owner kluca plati triedny override skrinky')
  NxTest.assert_equal('atira-biela-h70-sisy',
                      h.resolve_set_id('slide', it, {}, proj)[0],
                      'bez override plati projekt')
  # NA NIZSIU UROVEN sa ide LEN pri NEPRITOMNOM kluci: pritomny kluc s hodnotou,
  # ktora sa nedá rozlozit (chybajuce pasmo), konci NEMAPOVANE — NIKDY fallback.
  bez_pasma = { c::OWNK => c.height_selector([[144, 'atira-biela-h144-sisy']]) }
  sid, reason, = h.resolve_set_id('slide', it, { 'CAB-1' => cab.merge(bez_pasma) }, proj)
  NxTest.assert_equal(nil, sid)
  NxTest.assert_equal('selector_unresolved', reason, 'chybajuce pasmo = dovod, nie nizsia uroven')
  # A na genericky `slide` sa NEPADA ani cez owner uroven (C2a kontrakt).
  legacy = { 'slide' => 'atira-biela-h70-sisy', "slide@#{c::OWNER}" => 'atira-biela-h70-sisy' }
  NxTest.assert_equal(['class_unmapped'],
                      [h.resolve_set_id('slide', it, { 'CAB-1' => legacy }, {})[1]],
                      'genericke kluce pre klasifikovanu polozku NEEXISTUJU')
end

NxTest.test('KOV-D1a (R1): Atira pod owner klucom potrebuje vyskovy selektor, Quadro nie') do
  c = NxD1a
  h = c::HWS
  fixed = { c::OWNK => 'atira-biela-h70-sisy' }
  sid, reason, info = h.resolve_set_id('slide', c.atira_item, { 'CAB-1' => fixed }, {})
  NxTest.assert_equal(nil, sid)
  NxTest.assert_equal(['set_incompatible', 'height_selector'], [reason, info['detail']],
                      'pevny set by po prerasteni zasuvky objednal zly kit')
  # Quadro (bez vyskoveho variantu) pevny set SMIE.
  q_owner = "class:slide|classic|wood@#{c::OWNER}"
  NxTest.assert_equal('vysuv-quadro-v6-sisy',
                      h.resolve_set_id('slide', c.quadro_item,
                                       { 'CAB-1' => { q_owner => 'vysuv-quadro-v6-sisy' } }, {})[0])
end

# In-SU beh nad `b59cd47` ukazal, ze tento tvar sa v ZIVOM modeli naozaj vyskytne
# (zasuvka prerastie z H70 na H176, owner selektor ostane s pasmom 70). Headless
# ho preto strazi PRIAMO — in-SU meria nakup CELEHO modelu, takze sa tam da
# vysledok prekryt inou skrinkou; tu sa neda.
NxTest.test('KOV-D1a (R1): prerastena zasuvka bez pasma = RED bez kitu, NIKDY nizsia uroven') do
  c = NxD1a
  h = c::HWS
  # Owner selektor pozna LEN pasmo 70; zasuvka medzitym prerastla na H176.
  own = { c::OWNK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }
  # Nizsie urovne ponukaju PLATNE pasmo 176 — a predsa sa na ne NESMIE padnut:
  # kluc na vyssej urovni JE pritomny, len sa nedá rozlozit.
  cab  = { c::CLASSK => c.height_selector([[176, 'atira-biela-h176-sisy']]) }
  proj = { c::CLASSK => c.height_selector([[176, 'atira-biela-h176-sisy']]) }
  it = c.atira_item('params' => { 'height_variant' => 176.0 })

  sid, reason, = h.resolve_set_id('slide', it, { 'CAB-1' => cab.merge(own) }, proj)
  NxTest.assert_equal([nil, 'selector_unresolved'], [sid, reason],
                      'pritomny kluc bez pasma NIKDY nepadne na skrinku ani projekt')

  state = c.state_of([c.seed_set('atira-biela-h70-sisy'), c.seed_set('atira-biela-h176-sisy')], proj)
  exp = h.expand([it], state, cabinet_overrides: { 'CAB-1' => cab.merge(own) })
  NxTest.assert_equal([], exp['rows'], 'ZIADNY kit — ani ten z pasma 70, ani ten z nizsej urovne')
  u = exp['unmapped'].first
  NxTest.assert_equal(['drawer_kit_missing', 'selector_unresolved', true],
                      [u['reason'], u['base_reason'], u['blocks_export']],
                      'receptova polozka = RED, ktore zastavuje export')
end

NxTest.test('KOV-D1a (R1): owner triedny kluc na NEEXISTUJUCE celo sa zahodi') do
  c = NxD1a
  fronts = { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                           'height' => 175.0 }] }
  params = { 'width' => 900.0, 'height' => 720.0, 'depth' => 500.0, 'fronts' => fronts,
             'hardware_sets' => { c::OWNK => 'atira-biela-h70-sisy',
                                  "#{c::CLASSK}@front:F9/panel" => 'atira-biela-h144-sisy',
                                  c::CLASSK => 'vysuv-quadro-v6-sisy' } }
  map = c::CB.normalize(params)[:hardware_sets]
  NxTest.assert(map.key?(c::OWNK), 'existujuce celo si vyber ponecha')
  NxTest.refute(map.key?("#{c::CLASSK}@front:F9/panel"), 'mrtvy vyber v configu neostava')
  NxTest.assert(map.key?(c::CLASSK), 'bezownerovy kluc sa cielami neriadi')
  # Bez zoznamu ciel je to CISTA tvarova normalizacia (citacia cesta configu).
  NxTest.assert(c::CB.norm_hardware_sets(c::OWNK => 'atira-biela-h70-sisy').key?(c::OWNK))
end

# ============================================================================
# R2 — ZAPISOVE OPERACIE S TRIEDNYM KLUCOM
# ============================================================================

NxTest.test('KOV-D1a (R2): `set_project_mapping!` prijme triedny kluc, owner NIE') do
  c = NxD1a
  h = c::HWS
  m = c.model_with(c.seed_state)
  sel = c.height_selector([[70, 'atira-biela-h70-sisy'], [144, 'atira-biela-h144-sisy']])
  defs = [c.seed_set('atira-biela-h70-sisy'), c.seed_set('atira-biela-h144-sisy')]

  NxTest.assert_equal(true, h.set_project_mapping!(m, c::CLASSK, sel, defs))
  _, st = h.project_state_status(m)
  NxTest.assert_equal(sel, st['mapping'][c::CLASSK], 'meni sa PRAVE tento kluc')
  NxTest.assert(st['sets'].key?('atira-biela-h70-sisy') && st['sets'].key?('atira-biela-h144-sisy'),
                'definicie VSETKYCH pasiem selektora su zmrazene (jeden zapis)')
  NxTest.assert_equal(h.seed_library['mapping']['class:slide|tipon|metal'],
                      st['mapping']['class:slide|tipon|metal'], 'ostatne mapovania nedotknute')
  NxTest.assert_equal(h.seed_library['mapping']['hinge'], st['mapping']['hinge'],
                      'a genericky typ kovania uz vobec nie')

  # Owner triedny kluc do projektu NEPATRI.
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::OWNK, 'atira-biela-h70-sisy',
                                                    [c.seed_set('atira-biela-h70-sisy')]))
  _, st2 = h.project_state_status(m)
  NxTest.refute(st2['mapping'].key?(c::OWNK), 'a nic sa nezapisalo')
  # Nesediaci typ setu voci kluctu ostava odmietnuty.
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::CLASSK, 'zaves-p2o',
                                                    [c.seed_set('zaves-p2o')]))
end

NxTest.test('KOV-D1a (R2): `set_global_mapping!` prijme triedny kluc, owner NIE') do
  NxTest.skip!('kniznicne testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  c = NxD1a
  h = c::HWS
  before = (File.binread(h.path) if File.exist?(h.path))
  begin
    lib = h.seed_library
    File.binwrite(h.path, JSON.pretty_generate(lib))
    Noxun::Engine::JsonFileStore.invalidate(h.path)
    h.reset_library_state!

    sel = c.height_selector([[70, 'atira-biela-h70-sisy']])
    NxTest.assert_equal(:ok, h.set_global_mapping!(c::CLASSK, sel))
    NxTest.assert_equal(sel, h.load['mapping'][c::CLASSK])
    NxTest.assert_equal(lib['mapping']['hinge'], h.load['mapping']['hinge'],
                        'ostatne kluce nedotknute')
    NxTest.assert_equal(false, h.set_global_mapping!(c::OWNK, 'atira-biela-h70-sisy'),
                        'owner triedny kluc je len na skrinke')
    NxTest.assert_equal(false, h.set_global_mapping!(c::CLASSK, 'zaves-p2o'),
                        'set musi byt typu z kluca')
  ensure
    if before then File.binwrite(h.path, before) else File.delete(h.path) if File.exist?(h.path) end
    File.delete("#{h.path}.bak") if File.exist?("#{h.path}.bak")
    Noxun::Engine::JsonFileStore.invalidate(h.path)
    h.reset_library_state!
  end
end

NxTest.test('KOV-D1a (R2): `apply_cabinet_override` pise pre klasifikovane celo OWNER TRIEDNY kluc') do
  c = NxD1a
  h = c::HWS
  sel = c.height_selector([[70, 'atira-biela-h70-sisy']])
  st, map, refs = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, sel,
                                           known_sets: [c.seed_set('atira-biela-h70-sisy')])
  NxTest.assert_equal(:ok, st, map.inspect)
  NxTest.assert_equal([c::OWNK], map.keys, 'genericky `slide@owner` uz pre take celo NEVZNIKA')
  NxTest.assert_equal(['atira-biela-h70-sisy'], refs)
  # Zrusenie maze TEN ISTY kluc.
  st2, map2, = h.apply_cabinet_override(c.cfg_with(map), 'slide', c::OWNER, nil)
  NxTest.assert_equal([:ok, {}], [st2, map2])
  # LEGACY (neklasifikovana) polozka ostava na generickom kluci — bez zmeny.
  legacy = [{ 'owner_id' => 'CAB-1', 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
              'quantity' => 1, 'rule_id' => 'vysuvy-nl-podla-hlbky',
              'params' => { 'nominal_length' => 470.0 }, 'source' => 'rule' }]
  st3, map3, = h.apply_cabinet_override(c.cfg_with({}, legacy), 'slide', c::OWNER,
                                        'atira-biela-h70-sisy',
                                        known_sets: [c.seed_set('atira-biela-h70-sisy')])
  NxTest.assert_equal([:ok, ["slide@#{c::OWNER}"]], [st3, map3.keys])
end

# ============================================================================
# R5b — VALIDACIA PASIEM PRED ZAPISOM (forged payload) + AKCIA
# ============================================================================

NxTest.test('KOV-D1a (R5b): zapis validuje KAZDE pasmo proti klasifikacii cela') do
  c = NxD1a
  h = c::HWS
  defs = %w[atira-biela-h70-sisy atira-biela-h144-sisy atira-biela-h70-p2o
            vysuv-quadro-v6-sisy].map { |s| c.seed_set(s) }
  ok = c.height_selector([[70, 'atira-biela-h70-sisy'], [144, 'atira-biela-h144-sisy']])
  NxTest.assert_equal(:ok, h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, ok,
                                                    known_sets: defs)[0])

  # 1) pasmo vydava set INEHO otvarania (Tip-On kit ku klasickej zasuvke)
  bad_open = c.height_selector([[70, 'atira-biela-h70-p2o']])
  st, msg, = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, bad_open, known_sets: defs)
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(msg.include?('otvárania'), msg)

  # 2) pasmo H144 vydava set H70 (podvrhnuta hranica pasma)
  swapped = c.height_selector([[144, 'atira-biela-h70-sisy']])
  st2, msg2, = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, swapped, known_sets: defs)
  NxTest.assert_equal(:invalid, st2)
  NxTest.assert(msg2.include?('pásma'), msg2)

  # 3) selektor BEZ pasma pre aktualnu vysku cela
  mimo = c.height_selector([[144, 'atira-biela-h144-sisy']])
  st3, msg3, = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, mimo, known_sets: defs)
  NxTest.assert_equal(:invalid, st3)
  NxTest.assert(msg3.include?('H70'), msg3)

  # 4) pevny set na zasuvku s vyskovym variantom
  st4, msg4, = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, 'atira-biela-h70-sisy',
                                        known_sets: defs)
  NxTest.assert_equal(:invalid, st4)
  NxTest.assert(msg4.include?('podľa výšky'), msg4)

  # 5) Quadro (bez vyskoveho variantu) selektor NEPOTREBUJE a ani ho neprijme
  qcfg = c.cfg_with({}, [c.quadro_item])
  NxTest.assert_equal(:ok, h.apply_cabinet_override(qcfg, 'slide', c::OWNER, 'vysuv-quadro-v6-sisy',
                                                    known_sets: defs)[0])
  st5, msg5, = h.apply_cabinet_override(qcfg, 'slide', c::OWNER, ok, known_sets: defs)
  NxTest.assert_equal(:invalid, st5)
  NxTest.assert(msg5.include?('výškový variant nemá'), msg5)
end

NxTest.test('KOV-D1a (R5b): akcia panela — hodnota z payloadu a jedna zapisova cesta') do
  panel = Noxun::Engine::Panel
  # Payload smie niest selector (`value`) alebo set_id; prazdne = zrusenie.
  sel = NxD1a.height_selector([[70, 'atira-biela-h70-sisy']])
  NxTest.assert_equal(sel, panel.hw_set_value('value' => sel, 'set_id' => 'x'),
                      'selector ma prednost pred set_id')
  NxTest.assert_equal('atira-biela-h70-sisy', panel.hw_set_value('set_id' => 'atira-biela-h70-sisy'))
  NxTest.assert_equal(nil, panel.hw_set_value('set_id' => ''), 'prazdne = zrusenie overridu')
  NxTest.assert_equal(nil, panel.hw_set_value({}))

  # Akcia validuje a mrazi cez SERVEROVE cesty — ziadne skladanie klucov v paneli.
  body = NxD1a.src('noxun_engine', 'ui', 'panel',
                   'actions_hardware.rb')[/def handle_set_hardware_set.*?\n        end\n/m].to_s
  NxTest.assert(body.include?('HardwareSets.apply_cabinet_override(cfg, gt, owner, value'),
                'hodnotu (aj selector) validuje server PRED zapisom')
  NxTest.assert(body.include?('HardwareSets.add_project_sets!(model, set_defs)'),
                'do snapshotu sa mrazi KAZDY referencovany set')
  NxTest.assert(body.include?('rebuild_many'), 'zapis + zmrazenie + prestavba = JEDNA operacia')
  NxTest.refute(body.include?('"class:'), 'panel triedny kluc NESKLADA')
end

NxTest.test('KOV-D1a (R5b): sablona zachova owner triedny override ciela') do
  c = NxD1a
  target = { 'hardware_sets' => { c::OWNK => c.height_selector([[70, 'atira-biela-h70-sisy']]),
                                  "slide@#{c::OWNER}" => 'vysuv-quadro-v6-sisy',
                                  c::CLASSK => 'vysuv-quadro-v6-sisy' } }
  tpl = { 'hardware_sets' => { 'hinge' => 'zaves-p2o' } }
  out = c::E::TemplatesDialog.merge_hardware_sets(target, tpl)
  NxTest.assert(out.key?(c::OWNK), 'owner triedny vyber ciela sablona NEPREPISUJE')
  NxTest.assert(out.key?("slide@#{c::OWNER}"), 'ani legacy composite')
  NxTest.assert_equal('zaves-p2o', out['hinge'], 'genericke kluce su zo sablony')
  NxTest.refute(out.key?(c::CLASSK), 'bezownerovy triedny kluc je vec SABLONY')
end

NxTest.test('KOV-D1a (R5b): duplicitne ID skriniek s roznym owner overridom = BLOKUJE') do
  c = NxD1a
  keys = c::PC.override_keys_in_use(hardware: [c.atira_item])['CAB-1']
  NxTest.assert(keys[c::OWNK], 'brana pozna owner triedny kluc')
  NxTest.assert(keys[c::CLASSK], 'aj triedny')
  # Rozidena mapa PRAVE v owner kluci je materialny rozdiel -> export sa zastavi.
  NxTest.assert(c::PC.conflict_matters?([c::OWNK], keys))
  NxTest.refute(c::PC.conflict_matters?(['hinge'], keys), 'rozdiel v nepouzitom kluci nie')
end

NxTest.test('KOV-D1a (R4/Codex #308 P1): neaktivny set odmietne AJ LEGACY zapis override') do
  c = NxD1a
  h = c::HWS
  dead = c.seed_set('zaves-p2o').merge('active' => false)
  legacy = [{ 'owner_id' => 'CAB-1', 'owner_part_key' => nil, 'generic_type' => 'hinge',
              'quantity' => 2, 'rule_id' => 'r', 'params' => {}, 'source' => 'rule' }]
  cfg = c.cfg_with({}, legacy)
  st, msg, = h.apply_cabinet_override(cfg, 'hinge', nil, 'zaves-p2o', known_sets: [dead])
  NxTest.assert_equal(:invalid, st, 'brana F10 nesmie zavisiet od klasifikacie polozky')
  NxTest.assert(msg.include?('neaktívny'), msg)
  # Aktivny set tou istou cestou prejde.
  NxTest.assert_equal(:ok, h.apply_cabinet_override(cfg, 'hinge', nil, 'zaves-p2o',
                                                    known_sets: [c.seed_set('zaves-p2o')])[0])
  # A UZ ULOZENY neaktivny set sa zapisom NA SEBA nestrati.
  had = c.cfg_with({ 'hinge' => 'zaves-p2o' }, legacy)
  NxTest.assert_equal(:ok, h.apply_cabinet_override(had, 'hinge', nil, 'zaves-p2o',
                                                    known_sets: [dead])[0])
end

NxTest.test('KOV-D1a (Codex #308 P2): override skrinky sa overuje proti VSETKYM zasuvkam') do
  c = NxD1a
  h = c::HWS
  # Dve zasuvky ROVNAKEJ triedy, ale roznej vysky (H70 a H144).
  items = [c.atira_item,
           c.atira_item('owner_part_key' => 'front:F2/panel',
                        'params' => { 'height_variant' => 144.0 })]
  defs = %w[atira-biela-h70-sisy atira-biela-h144-sisy].map { |s| c.seed_set(s) }
  cfg = c.cfg_with({}, items)
  # Selektor, ktory vyhovuje PRVEJ zasuvke, ale druhej nie.
  len = c.height_selector([[70, 'atira-biela-h70-sisy']])
  st, msg, = h.apply_cabinet_override(cfg, 'slide', nil, len, known_sets: defs)
  NxTest.assert_equal(:invalid, st, 'nesmie sa ulozit vyber, ktory druhu zasuvku necha bez kitu')
  NxTest.assert(msg.include?('H144'), msg)
  NxTest.assert(msg.include?('front:F2/panel'), "hlaska musi povedat KTOREJ zasuvky sa tyka: #{msg}")
  # Selektor s OBOMA pasmami prejde a zapise sa TRIEDNY (bezownerovy) kluc.
  ok = c.height_selector([[70, 'atira-biela-h70-sisy'], [144, 'atira-biela-h144-sisy']])
  st2, map2, = h.apply_cabinet_override(cfg, 'slide', nil, ok, known_sets: defs)
  NxTest.assert_equal([:ok, [c::CLASSK]], [st2, map2.keys])
end

NxTest.test('KOV-D1a (Codex #308 P2): pasmo smie vydat LEN set s vyskovym variantom') do
  c = NxD1a
  h = c::HWS
  # Quadro set variant NEMA — vo vyskovom selektore nemá čo hľadať.
  bez = c.height_selector([[70, 'vysuv-quadro-v6-sisy']])
  st, msg, = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, bez,
                                      known_sets: [c.seed_set('vysuv-quadro-v6-sisy')])
  NxTest.assert_equal(:invalid, st, 'inak by zapis prešiel a expanzia dala `drawer_kit_missing`')
  NxTest.assert(msg.include?('nemá výškový variant'), msg)
end

NxTest.test('KOV-D1a (Codex #308 P2): klasifikovany owner vyber uprace LEGACY kluc') do
  c = NxD1a
  h = c::HWS
  # Skrinka po upgrade: v configu ostal legacy owner kluc z predchadzajucej verzie.
  legacy_key = "slide@#{c::OWNER}"
  cfg = c.cfg_with({ legacy_key => 'atira-biela-h70-sisy' })
  sel = c.height_selector([[70, 'atira-biela-h70-sisy']])
  st, map, = h.apply_cabinet_override(cfg, 'slide', c::OWNER, sel,
                                      known_sets: [c.seed_set('atira-biela-h70-sisy')])
  NxTest.assert_equal([:ok, [c::OWNK]], [st, map.keys],
                      'mrtvy legacy kluc nesmie ostat — karta by ho ukazovala ako volbu')
  # A pri ZRUSENI volby zmiznu OBA.
  st2, map2, = h.apply_cabinet_override(c.cfg_with(map.merge(legacy_key => 'atira-biela-h70-sisy')),
                                        'slide', c::OWNER, nil)
  NxTest.assert_equal([:ok, {}], [st2, map2])
  # LEGACY polozka (bez klasifikacie) si svoj kluc PONECHA — jej ho resolver číta.
  plain = [{ 'owner_id' => 'CAB-1', 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
             'quantity' => 1, 'rule_id' => 'r', 'params' => { 'nominal_length' => 470.0 },
             'source' => 'rule' }]
  st3, map3, = h.apply_cabinet_override(c.cfg_with({}, plain), 'slide', c::OWNER,
                                        'atira-biela-h70-sisy',
                                        known_sets: [c.seed_set('atira-biela-h70-sisy')])
  NxTest.assert_equal([:ok, [legacy_key]], [st3, map3.keys])
end

NxTest.test('KOV-D1a (Codex #308 kolo 2 P1): PRITOMNY kluc s pokazenou hodnotou = RED, nie nizsia uroven') do
  c = NxD1a
  h = c::HWS
  it = c.atira_item
  # Nizsie urovne maju PLATNU hodnotu — a predsa sa na ne NESMIE padnut.
  proj = { c::CLASSK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }
  cab  = { c::CLASSK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }

  [{ 'popis' => 'prazdna hodnota', 'raw' => '' },
   { 'popis' => 'zly tvar selektora', 'raw' => { 'param' => 'height_variant', 'bands' => 'nie pole' } },
   { 'popis' => 'prazdne set_id v pasme', 'raw' => { 'param' => 'height_variant',
                                                     'bands' => [{ 'min' => 70.0, 'max' => 70.0,
                                                                   'set_id' => '' }] } }].each do |cs|
    raw = { c::OWNK => cs['raw'] }
    ov = h.normalize_mapping(raw, nil, allow_owner: true)
    NxTest.assert(h.invalid_mapping_value?(ov[c::OWNK]), "#{cs['popis']}: kluc OSTAVA ako marker")

    sid, reason, = h.resolve_set_id('slide', it, { 'CAB-1' => cab.merge(ov) }, proj)
    NxTest.assert_equal([nil, 'mapping_invalid'], [sid, reason],
                        "#{cs['popis']}: nikdy set z nizsej urovne")
  end

  # Expanzia: RED bez kodu (receptova polozka), nie kit z projektu.
  ov = h.normalize_mapping({ c::OWNK => '' }, nil, allow_owner: true)
  state = c.state_of([c.seed_set('atira-biela-h70-sisy')], proj)
  exp = h.expand([it], state, cabinet_overrides: { 'CAB-1' => ov })
  NxTest.assert_equal([], exp['rows'], 'ziadny kod z predvolby projektu')
  u = exp['unmapped'].first
  NxTest.assert_equal(['drawer_kit_missing', 'mapping_invalid', true],
                      [u['reason'], u['base_reason'], u['blocks_export']])
  NxTest.assert(h.unmapped_reason_sk(u).include?('poškodený'), h.unmapped_reason_sk(u))

  # NEEXISTUJUCI set_id ostava vlastnym dovodom (`set_missing`) — kluc je platny.
  ov2 = h.normalize_mapping({ c::OWNK => c.height_selector([[70, 'nie-je']]) },
                            nil, allow_owner: true)
  exp2 = h.expand([it], state, cabinet_overrides: { 'CAB-1' => ov2 })
  NxTest.assert_equal('set_missing', exp2['unmapped'].first['base_reason'])
end

NxTest.test('KOV-D1a (Codex #308 kolo 3 P1): marker PREZIJE KAZDU citaciu cestu cabinet mapy') do
  c = NxD1a
  h = c::HWS
  it = c.atira_item
  proj = { c::CLASSK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }
  broken = h.normalize_mapping({ c::OWNK => '' }, nil, allow_owner: true)
  NxTest.assert(h.invalid_mapping_value?(broken[c::OWNK]), 'vychodisko: marker v mape')

  # (1) UPRAVA INEHO KOVANIA na tej istej skrinke. Prave tu marker doteraz
  # ticho zmizol — a nasledna prestavba by zasuvke dala set z projektu.
  cfg = c.cfg_with(broken, [it, { 'owner_id' => 'CAB-1', 'owner_part_key' => nil,
                                  'generic_type' => 'hinge', 'quantity' => 2,
                                  'rule_id' => 'r', 'params' => {}, 'source' => 'rule' }])
  st, map, = h.apply_cabinet_override(cfg, 'hinge', nil, 'zaves-p2o',
                                      known_sets: [c.seed_set('zaves-p2o')])
  NxTest.assert_equal(:ok, st, map.inspect)
  NxTest.assert(h.invalid_mapping_value?(map[c::OWNK]),
                'zapis INEHO kluca nesmie poskodeny vyber odstranit')
  NxTest.assert_equal('zaves-p2o', map['hinge'])

  # (2) PRESTAVBA (config -> params -> normalize) marker nesie dalej.
  fronts = { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                           'height' => 175.0 }] }
  norm = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                         'fronts' => fronts, 'hardware_sets' => map)
  NxTest.assert(h.invalid_mapping_value?(norm[:hardware_sets][c::OWNK]), 'prestavba ho nestrati')

  # (3) SABLONA: cielovy owner vyber (aj poskodeny) sa NEPREPISUJE.
  merged = c::E::TemplatesDialog.merge_hardware_sets({ 'hardware_sets' => map },
                                                     { 'hardware_sets' => { 'hinge' => 'zaves-klasik' } })
  NxTest.assert(h.invalid_mapping_value?(merged[c::OWNK]), 'merge sablony ho nesmie zahodit')

  # (4) PAYLOAD karty (`cabinet_set_overrides`) aj `explain` panela.
  pay = c::E::Panel.cabinet_set_overrides('hardware_sets' => map)
  NxTest.assert(h.invalid_mapping_value?(pay[c::OWNK]), 'payload ho nesmie zahodit')
  state = c.state_of([c.seed_set('atira-biela-h70-sisy'), c.seed_set('zaves-p2o')], proj)
  ex = h.explain(it, state, overrides: map)
  NxTest.assert_equal(nil, ex['set_id'], 'panel NESMIE ukazat set z predvolby projektu')
  NxTest.assert(ex['problems'].first.to_s.include?('poškodený'), ex['problems'].inspect)

  # (5) A po tom vsetkom expanzia STALE dava RED, nie kod z projektu.
  exp = h.expand([it], state, cabinet_overrides: { 'CAB-1' => norm[:hardware_sets] })
  NxTest.assert_equal([], exp['rows'])
  NxTest.assert_equal(['drawer_kit_missing', 'mapping_invalid'],
                      [exp['unmapped'].first['reason'], exp['unmapped'].first['base_reason']])
end

NxTest.test('KOV-D1a (Codex #308 kolo 3 P1): marker patri VYHRADNE cabinet mape') do
  c = NxD1a
  h = c::HWS
  # `allow_owner: false` = kniznica / snapshot / sablona: ziadna nizsia uroven,
  # takze marker tam nepatri a brany strat by ho naopak vyhodnotili ako platnu
  # polozku (`read_template_mapping` by stratu neohlasil).
  out, errs = h.parse_mapping({ 'hinge' => '' }, allow_owner: false)
  NxTest.assert_equal({}, out, 'bez ownera sa polozka zahadzuje ako doteraz')
  NxTest.refute(errs.empty?, 'a zapisova cesta ju odmietne chybou')
  # Sablona so zlou hodnotou sa nadalej prizna ako STRATOVA.
  status, lost = h.read_template_mapping('hinge' => '')
  NxTest.assert_equal([:lossy, ['hinge']], [status, lost])
  # Marker ako VSTUP do nekabinetnej mapy tiez neprejde.
  NxTest.assert_equal({}, h.parse_mapping({ 'hinge' => { 'invalid' => 'x' } },
                                          allow_owner: false)[0])
end

NxTest.test('KOV-D1a (Codex #308 kolo 2 P2): owner kluc na riadku `none` sa zahodi') do
  c = NxD1a
  fronts = { 'items' => [{ 'id' => 'F1', 'type' => 'none' },
                         { 'id' => 'F2', 'type' => 'drawer_front', 'mode' => 'fixed',
                           'height' => 175.0 }] }
  map = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0, 'fronts' => fronts,
                        'hardware_sets' => { c::OWNK => 'atira-biela-h70-sisy',
                                             "#{c::CLASSK}@front:F2/panel" => 'atira-biela-h70-sisy' })[:hardware_sets]
  NxTest.refute(map.key?(c::OWNK), 'riadok `none` ziadne celo nema — vyber by sa ticho reaktivoval')
  NxTest.assert(map.key?("#{c::CLASSK}@front:F2/panel"), 'skutocne celo si vyber ponecha')
end

NxTest.test('KOV-D1a (Codex #308 kolo 2 P2): neaktivny set sa neda PRESUNUT do ineho pasma') do
  c = NxD1a
  h = c::HWS
  dead70 = c.seed_set('atira-biela-h70-sisy').merge('active' => false)
  live144 = c.seed_set('atira-biela-h144-sisy')
  stored = c.height_selector([[70, 'atira-biela-h70-sisy']])
  state = c.state_of([dead70, live144], c::CLASSK => stored)
  m = c.model_with(state)

  # Rovnaky zavazok (to iste pasmo) = ZACHOVANIE ulozenej volby -> prejde.
  NxTest.assert_equal(true, h.set_project_mapping!(m, c::CLASSK, stored, [dead70]))
  # POSUN neaktivneho setu do INEHO pasma uz NIE JE zachovanie, ale NOVY vyber.
  posun = { 'param' => 'height_variant',
            'bands' => [{ 'min' => 70.0, 'max' => 144.0, 'set_id' => 'atira-biela-h70-sisy' }] }
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::CLASSK, posun, [dead70]),
                      'rozsirene pasmo by neaktivny set objednalo do INYCH zakaziek')
  # Rovnako prechod z pevnej volby na selektor s tym istym setom.
  fix_state = c.state_of([dead70], 'class:slide|classic|wood' => 'atira-biela-h70-sisy')
  m2 = c.model_with(fix_state)
  NxTest.assert_equal(false, h.set_project_mapping!(m2, 'class:slide|classic|wood',
                                                    c.height_selector([[70, 'atira-biela-h70-sisy']]),
                                                    [dead70]))
end

NxTest.test('KOV-D1a (Codex #308 kolo 2 P2): triedny zapis overi sety proti KLASIFIKACII kluca') do
  c = NxD1a
  h = c::HWS
  m = c.model_with(c.state_of([c.seed_set('vysuv-quadro-v6-sisy')],
                              'class:slide|classic|wood' => 'vysuv-quadro-v6-sisy'))
  # Tip-On sety pod klasickym klucom.
  tipon = c.height_selector([[70, 'atira-biela-h70-p2o']])
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::CLASSK, tipon,
                                                    [c.seed_set('atira-biela-h70-p2o')]),
                      'iny sposob otvarania nez pomenuva kluc')
  # PEVNY Atira set (ma vyskovy variant) pod triednym klucom.
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::CLASSK, 'atira-biela-h70-sisy',
                                                    [c.seed_set('atira-biela-h70-sisy')]),
                      'set s vyskovym variantom sa pevne vybrat neda')
  # Ina konstrukcia (drevo pod kovovym klucom).
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::CLASSK, 'vysuv-quadro-v6-sisy',
                                                    [c.seed_set('vysuv-quadro-v6-sisy')]))
  # A SPRAVNA kombinacia prejde.
  ok = c.height_selector([[70, 'atira-biela-h70-sisy']])
  NxTest.assert_equal(true, h.set_project_mapping!(m, c::CLASSK, ok,
                                                   [c.seed_set('atira-biela-h70-sisy')]))
end

NxTest.test('KOV-D1a (vlastny prechod): ZMIESANA skrinka sa jednym klucom zapisat NEDA') do
  c = NxD1a
  h = c::HWS
  legacy = { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F2/panel', 'generic_type' => 'slide',
             'quantity' => 1, 'rule_id' => 'r', 'params' => { 'nominal_length' => 470.0 },
             'source' => 'rule' }
  cfg = c.cfg_with({}, [c.atira_item, legacy])
  sel = c.height_selector([[70, 'atira-biela-h70-sisy']])
  st, msg, = h.apply_cabinet_override(cfg, 'slide', nil, sel,
                                      known_sets: [c.seed_set('atira-biela-h70-sisy')])
  NxTest.assert_equal(:invalid, st, 'genericky kluc by klasifikovanu polozku NECITAL (tichy no-op)')
  NxTest.assert(msg.include?('na konkrétnom čele'), msg)
  # Na KONKRETNOM celi to ide dalej bez problemu.
  NxTest.assert_equal(:ok, h.apply_cabinet_override(cfg, 'slide', c::OWNER, sel,
                                                    known_sets: [c.seed_set('atira-biela-h70-sisy')])[0])
end

NxTest.test('KOV-D1a (Codex #308 kolo 2 P2): karta ukaze LEN kluc AKTIVNEJ triedy dielca') do
  c = NxD1a
  panel = c::E::Panel
  tipon_key = "class:slide|tipon|metal@#{c::OWNER}"
  overrides = { c::OWNK => 'A', tipon_key => 'B', "slide@#{c::OWNER}" => 'C' }

  # Celo je KLASICKE: dormantny Tip-On vyber ani legacy kluc sa NEUKAZU.
  out = panel.owner_set_overrides(overrides, 'slide', [c.atira_item])
  NxTest.assert_equal({ 'set_id' => 'A' }, out[c::OWNER], 'len kluc aktivnej triedy')

  # Po prepnuti na Tip-On sa ukaze TEN druhy — a klasicky sa stane dormantnym.
  tip = c.atira_item('params' => { 'opening_mode' => 'tipon' })
  out2 = panel.owner_set_overrides(overrides, 'slide', [tip])
  NxTest.assert_equal({ 'set_id' => 'B' }, out2[c::OWNER])

  # NEKLASIFIKOVANA polozka cita legacy kluc — a ten sa jej ukaze.
  legacy = { 'owner_id' => 'CAB-1', 'owner_part_key' => c::OWNER, 'generic_type' => 'slide',
             'quantity' => 1, 'rule_id' => 'r', 'params' => { 'nominal_length' => 470.0 },
             'source' => 'rule' }
  NxTest.assert_equal({ 'set_id' => 'C' }, panel.owner_set_overrides(overrides, 'slide', [legacy])[c::OWNER])

  # Poskodena hodnota sa PRIZNA — nie prazdny select.
  bad = c::HWS.normalize_mapping({ c::OWNK => '' }, nil, allow_owner: true)
  NxTest.assert_equal({ 'invalid' => true },
                      panel.owner_set_overrides(bad, 'slide', [c.atira_item])[c::OWNER])
end

NxTest.test('KOV-D1a (vlastny prechod): pritomne `value` sa nepresvieti na `set_id`') do
  panel = Noxun::Engine::Panel
  NxTest.assert_equal(42, panel.hw_set_value('value' => 42, 'set_id' => 'atira-biela-h70-sisy'),
                      'nepouzitelny tvar odmietne SERVER s hlaskou, nie ticho iny vyber')
  NxTest.assert_equal('x', panel.hw_set_value('value' => 'x', 'set_id' => 'y'))
  NxTest.assert_equal('y', panel.hw_set_value('value' => nil, 'set_id' => 'y'), 'null = nie je volba')
end

# ============================================================================
# R3 — CONFIG_SCHEMA 6
# ============================================================================

NxTest.test('KOV-D1a (R3): CONFIG_SCHEMA je 6, aktivacia zasuviek ostava 5') do
  c = NxD1a
  NxTest.assert_equal(6, c::CB::CONFIG_SCHEMA)
  NxTest.assert_equal(5, c::CB::DRAWER_ACTIVATION_SCHEMA)
  NxTest.assert_equal(Noxun::Engine::PartKeys::SCHEMA, Noxun::Engine::PartKeys::SCHEMA)
  # Downgrade: plugin so schemou 6 odmietne PRESTAVBU configu 7; schema 6 prejde,
  # 5 (starsia) je kompatibilna. Owner kluc sa NIKDY ticho neoreze.
  NxTest.refute(c::CB.newer_config?('config_schema' => 6))
  NxTest.refute(c::CB.newer_config?('config_schema' => 5))
  NxTest.assert(c::CB.newer_config?('config_schema' => 7))
  inst = NxTest::FakeEntity.new
  inst.set_attribute(c::E::Store::DICT, 'config', JSON.generate('config_schema' => 7))
  NxTest.assert_raise(/novšej verzie/) { c::CB.guard_newer_config!(inst) }
  # `drawer_stale` sa pre schemu 5 AJ 6 sprava rovnako (nic).
  cfg5 = { 'config_schema' => 5, 'front_items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                                     'opening_mode' => 'classic',
                                                     'drawer' => { 'construction' => 'metal' } }] }
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 1, cfg5))
  NxTest.assert_equal(nil, c::E::Bom.drawer_stale_issue('CAB-1', 1, cfg5.merge('config_schema' => 6)))
  NxTest.assert(c::E::Bom.drawer_stale_issue('CAB-1', 1, cfg5.merge('config_schema' => 4)),
                'schema pred aktivaciou ostava RED')
end

NxTest.test('KOV-D1a (R3): prestavba zapise schemu 6 aj bez owner kluca') do
  c = NxD1a
  cfg = c::CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0)
  NxTest.assert_equal(6, c::CB.cabinet_config(cfg)[:config_schema],
                      'marker sa zapisuje pri KAZDOM zapise configu')
end

# ============================================================================
# R4 — NEAKTIVNY SET
# ============================================================================

NxTest.test('KOV-D1a (R4): neaktivny set sa NOVO vybrat neda') do
  c = NxD1a
  h = c::HWS
  dead = c.seed_set('atira-biela-h70-sisy').merge('active' => false)
  live = c.seed_set('atira-biela-h144-sisy')
  # Projekt, ktory tento kluc ESTE nema — zapis je teda NOVY vyber.
  m = c.model_with(c.state_of([c.seed_set('vysuv-quadro-v6-sisy')],
                              'class:slide|classic|wood' => 'vysuv-quadro-v6-sisy'))

  sel_dead = c.height_selector([[70, 'atira-biela-h70-sisy']])
  NxTest.assert_equal(false, h.set_project_mapping!(m, c::CLASSK, sel_dead, [dead]),
                      'projektovy zapis neaktivny set odmietne')
  st, msg, = h.apply_cabinet_override(c.cfg_with({}), 'slide', c::OWNER, sel_dead,
                                      known_sets: [dead])
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(msg.include?('neaktívny'), msg)

  # ULOZENA volba neaktivneho setu sa ZACHOVA — a dalsi zapis INEHO kluca ju
  # neprepise (meni sa vzdy len jeden kluc).
  state = c.seed_state
  state['mapping'][c::CLASSK] = sel_dead
  state['sets']['atira-biela-h70-sisy'] = dead
  m2 = c.model_with(state)
  NxTest.assert_equal(true, h.set_project_mapping!(m2, 'class:slide|classic|wood',
                                                   'vysuv-quadro-v6-sisy',
                                                   [c.seed_set('vysuv-quadro-v6-sisy')]))
  _, st2 = h.project_state_status(m2)
  NxTest.assert_equal(sel_dead, st2['mapping'][c::CLASSK], 'ulozena volba prezije')
  # Prepis toho isteho kluca NA SEBA je stale povoleny (nie je to NOVY vyber).
  NxTest.assert_equal(true, h.set_project_mapping!(m2, c::CLASSK, sel_dead, [dead]))
  # A vymena za INY neaktivny set uz nie.
  dead2 = live.merge('active' => false)
  NxTest.assert_equal(false, h.set_project_mapping!(m2, c::CLASSK,
                                                    c.height_selector([[70, 'atira-biela-h70-sisy'],
                                                                       [144, 'atira-biela-h144-sisy']]),
                                                    [dead, dead2]))
end

NxTest.test('KOV-D1a (R4): deaktivacia setu NEMENI nakup existujucej zakazky') do
  c = NxD1a
  h = c::HWS
  it = c.atira_item
  proj = { c::CLASSK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }
  live  = c.state_of([c.seed_set('atira-biela-h70-sisy')], proj)
  dead  = c.state_of([c.seed_set('atira-biela-h70-sisy').merge('active' => false)], proj)
  a = h.expand([it], live)
  b = h.expand([it], dead)
  NxTest.assert_equal(a['rows'], b['rows'], 'expanzia je na `active` slepa (B3 kontrakt)')
  NxTest.assert_equal([], b['unmapped'])
end

# ============================================================================
# R5 — NEPLATNY `recipe_refs` ZAZNAM = RED
# ============================================================================

NxTest.test('KOV-D1a (R5): neplatny `recipe_refs` zaznam je RED, nie surodenec') do
  c = NxD1a
  # (a) NESULAD kluca a receptu
  refs = c::FR.norm_recipe_refs('atira|sisy' => 'quadro_v6_p2o_v1')
  NxTest.assert_equal({ 'atira|sisy' => 'quadro_v6_p2o_v1' }, refs, 'zaznam PREZIJE')
  NxTest.assert_equal([:unknown, 'quadro_v6_p2o_v1'], c::REC.active_ref(refs, 'atira', 'sisy'))
  NxTest.assert_equal(nil, c::REC.pick_ref(refs, 'atira', 'sisy'), 'ziadny nahradny recept')

  # (b) ZLY TVAR hodnoty
  bad = c::FR.norm_recipe_refs('atira|sisy' => 'nezmysel')
  NxTest.assert_equal({ 'atira|sisy' => 'nezmysel' }, bad)
  NxTest.assert_equal([:unknown, 'nezmysel'], c::REC.active_ref(bad, 'atira', 'sisy'))

  # (c) NEREGISTROVANE, ale tvarovo platne ID (kontrakt uz z C2b)
  unk = c::FR.norm_recipe_refs('atira|sisy' => 'atira_sisy_v9')
  NxTest.assert_equal([:unknown, 'atira_sisy_v9'], c::REC.active_ref(unk, 'atira', 'sisy'))

  # (d) NEPRITOMNY zaznam ostava „chybajuci -> surodenec/latest"
  NxTest.assert_equal([:missing, nil], c::REC.active_ref({}, 'atira', 'sisy'))
  NxTest.assert_equal('atira_sisy_v1', c::REC.pick_ref({}, 'atira', 'sisy'))
  sib = { 'atira|p2o' => 'atira_p2o_v1' }
  NxTest.assert_equal('atira_sisy_v1', c::REC.pick_ref(sib, 'atira', 'sisy'), 'surodenec verzie')

  # (e) POSKODENY zaznam NIKDY neurci surodenca pre inu kombinaciu
  mixed = { 'atira|p2o' => 'quadro_v6_sisy_v1' }
  NxTest.assert_equal('atira_sisy_v1', c::REC.pick_ref(mixed, 'atira', 'sisy'),
                      'surodenec sa berie LEN z validovanych zaznamov (tu z registra)')

  # (f) kluc mimo uzavreteho slovnika ziadnu kombinaciu nepripina -> vypadne
  NxTest.assert_equal(nil, c::FR.norm_recipe_refs('zly|kluc' => 'atira_sisy_v1'))

  # (g) Codex #308 kolo 1 P1: KAZDA pritomna hodnota pod platnym klucom je PIN.
  # Cislo, prazdny retazec, objekt aj `null` = pin, ktory je POSKODENY —
  # NIKDY „pin chyba" (to by bol surodenec/latest, teda ticha zmena fyziky).
  { 42 => '42', '' => '', '   ' => '', nil => '', { 'a' => 1 } => '',
    [1] => '', true => '' }.each do |raw, want|
    refs = c::FR.norm_recipe_refs('atira|sisy' => raw)
    NxTest.assert_equal({ 'atira|sisy' => want }, refs, "#{raw.inspect} ostava ako pin")
    NxTest.assert_equal([:unknown, want], c::REC.active_ref(refs, 'atira', 'sisy'),
                        "#{raw.inspect} je NEPLATNY pin, nie chybajuci")
    NxTest.assert_equal(nil, c::REC.pick_ref(refs, 'atira', 'sisy'),
                        "#{raw.inspect}: ziadny nahradny recept")
  end
  # Idempotencia: druhy prechod normalizaciou pin nestrati.
  once = c::FR.norm_recipe_refs('atira|sisy' => nil)
  NxTest.assert_equal(once, c::FR.norm_recipe_refs(once), 'prestavba pin NESTRATI')
end

NxTest.test('KOV-D1a (R5): pin BEZ citatelnej hodnoty ma zrozumitelnu vetu, nie prazdne uvodzovky') do
  c = NxD1a
  full = c::CB.normalize(
    'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
    'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                                'height' => 175.0, 'opening_mode' => 'classic',
                                'drawer' => { 'construction' => 'metal',
                                              'recipe_refs' => { 'atira|sisy' => nil } } }] }
  )
  pl = c::CN.build_plan(full, 'CAB-1')
  cf = Array(pl[:drawer_conflicts]).first
  NxTest.assert_equal('drawer_recipe_unknown', cf && cf['code'])
  NxTest.assert(cf['message'].include?('bez čitateľnej hodnoty'), cf['message'])
  NxTest.refute(cf['message'].include?('„“'), 'ziadne prazdne uvodzovky v hlaske')
  NxTest.assert_equal(nil, pl[:hardware].find { |x| x['generic_type'] == 'slide' })
end

NxTest.test('KOV-D1a (R5): poskodeny pin = `drawer_recipe_unknown` bez dielcov aj vysuvu') do
  c = NxD1a
  full = c::CB.normalize(
    'width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
    'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed',
                                'height' => 175.0, 'opening_mode' => 'classic',
                                'drawer' => { 'construction' => 'metal',
                                              'recipe_refs' => { 'atira|sisy' => 'atira_p2o_v1' } } }] }
  )
  pl = c::CN.build_plan(full, 'CAB-1')
  NxTest.assert_equal(['drawer_recipe_unknown'], Array(pl[:drawer_conflicts]).map { |x| x['code'] })
  NxTest.assert_equal(nil, pl[:hardware].find { |x| x['generic_type'] == 'slide' })
  NxTest.assert_equal([], pl[:parts].select { |p| c::CB::DRAWER_ROLES.include?(p[:role].to_s) })
  NxTest.assert(c::REC::BUILD_BLOCKERS.include?('drawer_recipe_unknown'),
                'kod blokuje stavbu aj exporty (register brany)')
end

# ============================================================================
# R6 — CHARAKTERIZACIA
# ============================================================================

NxTest.test('KOV-D1a (R6): zakazka BEZ owner klucov ma IDENTICKE vystupy') do
  c = NxD1a
  h = c::HWS
  it = c.atira_item
  proj = { c::CLASSK => c.height_selector([[70, 'atira-biela-h70-sisy']]) }
  state = c.state_of([c.seed_set('atira-biela-h70-sisy')], proj)
  exp = h.expand([it], state)
  NxTest.assert_equal(['357696'], exp['rows'].map { |r| r['code'] }, 'kod podla NL 470 a H70')
  NxTest.assert_equal([], exp['unmapped'])
  # Legacy skrinka bez klasifikacie ide dalej generickym klucom.
  legacy = { 'owner_id' => 'CAB-1', 'owner_part_key' => c::OWNER, 'generic_type' => 'hinge',
             'quantity' => 2, 'rule_id' => 'r', 'params' => {}, 'source' => 'rule' }
  lstate = c.state_of([c.seed_set('zaves-klasik')], 'hinge' => 'zaves-klasik')
  NxTest.assert_equal(4, h.expand([legacy], lstate)['rows'].length, 'stary kanal nedotknuty')
end
