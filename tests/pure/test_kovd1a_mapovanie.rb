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
  NxTest.assert_equal(nil, c::FR.norm_recipe_refs('atira|sisy' => { 'a' => 1 }),
                      'hodnota, ktora nie je retazec, nie je ref v ziadnom tvare')
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
