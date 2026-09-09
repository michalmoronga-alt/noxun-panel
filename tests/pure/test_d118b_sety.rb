# frozen_string_literal: true
# Testy D-118b: OPRAVA KODU, PTOs MODUL A VYHRADENA BUNKA `none`.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 antracit H70/470 objedna `357889` (K-sada); `348777` (nie je K-sada —
#      celne kovanie treba dokupit) sa v setoch UZ NEVYSKYTUJE
#   R2 KAZDY `PTOs` kit ma v tom istom sete PTOs modul podla nosnosti
#      (30 kg -> 352908, 50 kg -> 352909) a KAZDY kit typu `PTO` ma `none`
#      (modul je vo vysuve) — TABULKOVA FIXTURA nizsie je DRUHY, nezavisly zapis
#   R3 `none` = VEDOME bez kodu -> clen sa preskoci: ziadny riadok nakupu,
#      ziadny ORANGE; CHYBAJUCI kluc ostava NEMAPOVANY (rozdiel „pritomna
#      hodnota != nepritomna")
#   R4 expanzia: Tip-On zasuvka vyda DVA riadky (kit + modul), klasicka JEDEN;
#      dve zasuvky ten isty modul SCITAJU; v CSV nakupu nie je retazec `none`
#   R5 FAIL-CLOSED (Astra #21 BLOCKER 3): ked set nevyda pre RECEPTOVU polozku
#      ANI JEDEN riadok, je to RED `drawer_kit_missing` (`members_skipped`)
#      so zastavenym exportom — nikdy ticho prazdny nakup
#   R6 MARKER KOMPATIBILITY: kniznica/snapshot so sentinelom ma `STD_SKIP_CODE`
#      (starsi plugin ich odmietne), obsah bez neho ostava na povodnom std
#   R7 MIGRACIA: nedotknuty seed tvar sa nahradi novym (vratane premenovania
#      legacy setu), pouzivatelom upraveny set ostava
#   R8 `none` je vyhradene pre BUNKU (rad `code_by_nl`, od KOV-G1a aj KODOVE
#      pasmo `param_bands`) — ako PEVNY kod sa odmieta dalej
#
# MUTACIE (kazda overena rucne — po zaneseni chyby spadne uvedeny test):
#   M1 v sete sa vrati kod 348777 -> „D-118b (R1): antracit H70/470 = 357889"
#   M2 modul pri H176/520 sa zmeni na 352908 -> „D-118b (R2): modul podla nosnosti"
#   M3 bunka 620 dostane kod namiesto `none` -> „D-118b (R2): kit PTO modul NEPOTREBUJE"
#   M4 `member_code` vrati pre `none` kod -> „D-118b (R3): `none` nevyda riadok…"
#   M5 fail-closed vetva v `expand_members` sa zmaze -> „D-118b (R5): set bez…"
#   M6 `skip_code_present?` vrati vzdy false -> „D-118b (R6): sentinel = std 5"
#   M7 `replace_untouched_seed_sets` sa preskoci -> „D-118b (R7): nedotknuty…"
require_relative '../helper' unless defined?(NxTest)

module NxD118b
  E     = Noxun::Engine
  HWS   = E::HardwareSets
  REC   = E::Recipes
  STORE = E::JsonFileStore

  TIPON_METAL = 'class:slide|tipon|metal'

  # TABULKOVA FIXTURA — zapisana RUCNE z produktovych stranok Demosu (7.9.2026),
  # nie odvodena zo seedu: kit -> modul, ktory k nemu patri. `nil` = kit typu
  # `PTO`, ktory ma push-to-open priamo vo vysuve (modul netreba).
  MODUL_PRE_KIT = {
    # biela H70 / H144 / H176 (PTOs 30 kg)
    '357722' => '352908', '357723' => '352908', '357724' => '352908', '357725' => '352908',
    '357761' => '352908', '357762' => '352908', '357763' => '352908', '357764' => '352908',
    '357801' => '352908', '357802' => '352908', '357803' => '352908',
    '357812' => '352909', # H176/520 je 50 kg kit -> silnejsie pasmo
    # antracit (vsetky 30 kg)
    '357914' => '352908', '357915' => '352908', '357916' => '352908', '357917' => '352908',
    '357955' => '352908', '357956' => '352908', '357957' => '352908', '357958' => '352908',
    '357996' => '352908', '357997' => '352908', '357998' => '352908', '357999' => '352908',
    # kity typu PTO (620 mm) — modul je vo vysuve
    '357716' => nil, '357755' => nil, '357795' => nil
  }.freeze

  TIPON_SETY = %w[atira-biela-h70-p2o atira-biela-h144-p2o atira-biela-h176-p2o
                  atira-antracit-h70-p2o atira-antracit-h144-p2o
                  atira-antracit-h176-p2o].freeze

  module_function

  def seed_norm
    HWS.normalize_sets(HWS::SEED_SETS)
  end

  def set_of(sid)
    seed_norm.find { |s| s['set_id'] == sid }
  end

  def raw_set(sid)
    HWS::SEED_SETS.find { |s| s['set_id'] == sid }
  end

  def state_of(sets, mapping)
    idx = {}
    HWS.normalize_sets(sets).each { |s| idx[s['set_id']] = s }
    { 'mapping' => mapping, 'sets' => idx }
  end

  # Stav projektu s BIELOU Tip-On rodinou pod triednym klucom.
  def tipon_state
    sets = seed_norm
    family = sets.select { |s| s['set_id'].start_with?('atira-biela-') && s['set_id'].end_with?('p2o') }
    mapping = HWS::SEED_MAPPING.merge(HWS::MAPPING_ADDITIONS)
              .merge(TIPON_METAL => HWS.height_selector_for(family))
    state_of(sets, mapping)
  end

  def drawer_item(height_variant, nl, owner = 'CAB-1', part = 'front:F1/panel')
    { 'owner_id' => owner, 'owner_part_key' => part,
      'generic_type' => 'slide', 'quantity' => 1, 'source' => 'recipe',
      'rule_id' => 'recipe:atira_p2o_v1',
      'params' => { 'opening_mode' => 'tipon', 'drawer_construction' => 'metal',
                    'system' => 'atira', 'height_variant' => height_variant.to_f,
                    'nominal_length' => nl.to_f } }
  end

  def codes_of(exp)
    exp['rows'].map { |r| r['code'] }.sort
  end
end

# ============================================================================
# R1–R2 — DATA SEEDU
# ============================================================================

NxTest.test('D-118b (R1): antracit H70/470 = 357889, kod 348777 sa v setoch nevyskytuje') do
  c = NxD118b
  kit = c.set_of('atira-antracit-h70-sisy')['members'].first['code_by_nl']
  NxTest.assert_equal('357889', kit['470'],
                      '348777 NIE je K-sada — celne kovanie treba dokupit zvlast')
  vsetky = c::HWS::SEED_SETS.flat_map do |s|
    Array(s['members']).flat_map { |m| (m['code_by_nl'] || {}).values + [m['code']] }
  end.compact
  NxTest.refute(vsetky.include?('348777'), 'ziadny set uz na 348777 neukazuje')
end

NxTest.test('D-118b (R2): modul podla nosnosti kitu (tabulkova fixtura)') do
  c = NxD118b
  overenych = 0
  c::TIPON_SETY.each do |sid|
    set = c.set_of(sid)
    NxTest.assert(set, "set #{sid} chyba")
    NxTest.assert_equal(2, set['members'].length, "#{sid}: K-sada + PTOs modul")
    kit = set['members'][0]['code_by_nl']
    mod = set['members'][1]['code_by_nl']
    NxTest.assert_equal('PTOs mechanizmus', set['members'][1]['label'], sid)
    NxTest.assert_equal(1, set['members'][1]['qty'], "#{sid}: 1 modul na zasuvku")
    NxTest.assert_equal('unit', set['members'][1]['per'], "#{sid}: per jednotka")
    NxTest.assert_equal(kit.keys.sort, mod.keys.sort, "#{sid}: modul ma bunku pre KAZDU dlzku")
    kit.each do |nl, code|
      want = c::MODUL_PRE_KIT.fetch(code)
      got = mod[nl]
      if want.nil?
        NxTest.assert(c::HWS.skip_code?(got),
                      "#{sid} NL #{nl}: kit #{code} je typu PTO — modul NEPOTREBUJE (#{got})")
      else
        NxTest.assert_equal(want, got, "#{sid} NL #{nl}: kit #{code} chce modul #{want}")
      end
      overenych += 1
    end
  end
  NxTest.assert(overenych >= 27, "fixtura overila len #{overenych} buniek")
end

NxTest.test('D-118b (R2): kit PTO modul NEPOTREBUJE — bunka je VYPLNENA sentinelom') do
  c = NxD118b
  # Rozdiel oproti chybajucemu klucu je ZAMER: vynechany kluc = „kod sme
  # nedoplnili" (ORANGE), vyplnene `none` = „tu ziadny kod nepatri".
  %w[atira-biela-h70-p2o atira-biela-h144-p2o atira-biela-h176-p2o].each do |sid|
    raw = c.raw_set(sid)['members'][1]['code_by_nl']
    NxTest.assert(raw.key?('620'), "#{sid}: kluc 620 MUSI byt pritomny")
    NxTest.assert_equal(c::HWS::SKIP_CODE, raw['620'], "#{sid}: a jeho hodnota je sentinel")
  end
  # Quadro V6 (drevene zasuvky) ma P2O vo vysuve — set sa NEMENI.
  NxTest.assert_equal(1, c.set_of('vysuv-quadro-v6-p2o')['members'].length,
                      'Quadro V6 Tip-On ostava jednoclenny')
end

# ============================================================================
# R3–R4 — EXPANZIA
# ============================================================================

NxTest.test('D-118b (R3): `none` nevyda riadok ani ORANGE, chybajuci kluc ORANGE ostava') do
  c = NxD118b
  # NL 620: kit 357716 (PTO) + modul `none` -> JEDEN riadok, ziadny nemapovany.
  exp = c::HWS.expand([c.drawer_item(70, 620)], c.tipon_state)
  NxTest.assert_equal(['357716'], c.codes_of(exp), 'len kit, modul sa preskocil')
  NxTest.assert_equal([], exp['unmapped'], "vedome prazdna bunka NIE JE problem: #{exp['unmapped'].inspect}")

  # Ta ista poloha, ale s CHYBAJUCIM klucom = nemapovane (ORANGE/RED).
  sets = c.seed_norm.map do |s|
    next s unless s['set_id'] == 'atira-biela-h70-p2o'

    copy = Marshal.load(Marshal.dump(s))
    copy['members'][1]['code_by_nl'].delete('620')
    copy
  end
  family = sets.select { |s| s['set_id'].start_with?('atira-biela-') && s['set_id'].end_with?('p2o') }
  st = c.state_of(sets, c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
                          .merge(c::TIPON_METAL => c::HWS.height_selector_for(family)))
  miss = c::HWS.expand([c.drawer_item(70, 620)], st)
  NxTest.assert_equal(['357716'], c.codes_of(miss), 'kit sa objedna dalej')
  NxTest.assert_equal(['drawer_kit_missing'], miss['unmapped'].map { |u| u['reason'] },
                      'chybajuci kluc = nemapovany zaznam (pri recepte RED)')
  NxTest.assert_equal('nl_missing', miss['unmapped'].first['base_reason'])
end

NxTest.test('D-118b (R4): Tip-On zasuvka objedna kit AJ modul, dve zasuvky ho scitaju') do
  c = NxD118b
  cat = [{ 'item_code' => '357723', 'name_sk' => 'K-sada Atira H70/420 PTOs',
           'category' => 'VYSUVY', 'unit' => 'set', 'price_eur_vat' => 46.0 },
         { 'item_code' => '352908', 'name_sk' => 'Atira mechanizmus PTOs 10-30kg',
           'category' => 'VYSUVY', 'unit' => 'set', 'price_eur_vat' => 28.33 }]
  exp = c::HWS.expand([c.drawer_item(70, 420)], c.tipon_state, catalog: cat)
  NxTest.assert_equal(%w[352908 357723], c.codes_of(exp), 'kit + modul')
  NxTest.assert_equal([], exp['unmapped'])
  modul = exp['rows'].find { |r| r['code'] == '352908' }
  NxTest.assert_equal(1, modul['quantity'], 'jeden modul na zasuvku')
  NxTest.assert_close(74.33, exp['summary']['total_eur_vat'], 0.005, 'nakup scita kit aj modul')

  dve = c::HWS.expand([c.drawer_item(70, 420),
                       c.drawer_item(70, 470, 'CAB-1', 'front:F2/panel')],
                      c.tipon_state, catalog: cat)
  m2 = dve['rows'].find { |r| r['code'] == '352908' }
  NxTest.assert_equal(2, m2['quantity'], 'dve zasuvky = dva moduly (agregacia podla kodu)')
end

NxTest.test('D-118b (R4): klasicka zasuvka modul nedostane a CSV neobsahuje `none`') do
  c = NxD118b
  sets = c.seed_norm
  family = sets.select { |s| s['set_id'].start_with?('atira-biela-') && s['set_id'].end_with?('sisy') }
  st = c.state_of(sets, c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
                          .merge('class:slide|classic|metal' => c::HWS.height_selector_for(family)))
  klasik = c.drawer_item(70, 420)
  klasik['params']['opening_mode'] = 'classic'
  klasik['rule_id'] = 'recipe:atira_sisy_v1'
  exp = c::HWS.expand([klasik], st)
  NxTest.assert_equal(['357695'], c.codes_of(exp), 'SiSy rad modul nepotrebuje')

  csv = c::HWS.purchase_csv(c::HWS.expand([c.drawer_item(70, 620)], c.tipon_state))
  NxTest.refute(csv.downcase.include?('none'), 'sentinel sa do nakupneho CSV NIKDY nedostane')
end

# ============================================================================
# R5 — FAIL-CLOSED
# ============================================================================

NxTest.test('D-118b (R5): set bez jedinej polozky = RED, nikdy ticho prazdny nakup') do
  c = NxD118b
  # Patologicky (ale ULOZITELNY) stav: pre TUTO dlzku (NL 420) je `none`
  # v KAZDOM clene setu — ostatne dlzky kody maju, takze sety su platne
  # (Codex #337 N1: clen, ktoreho su VSETKY bunky `none`, uz validacia
  # odmieta, takze taky set by sa v kniznici ani nedal ulozit).
  sets = c.seed_norm.map do |s|
    next s unless s['set_id'] == 'atira-biela-h70-p2o'

    copy = Marshal.load(Marshal.dump(s))
    copy['members'].each { |m| m['code_by_nl']['420'] = c::HWS::SKIP_CODE }
    copy
  end
  family = sets.select { |s| s['set_id'].start_with?('atira-biela-') && s['set_id'].end_with?('p2o') }
  st = c.state_of(sets, c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
                          .merge(c::TIPON_METAL => c::HWS.height_selector_for(family)))
  exp = c::HWS.expand([c.drawer_item(70, 420)], st)
  NxTest.assert_equal([], exp['rows'], 'ziadny riadok nakupu')
  u = exp['unmapped'].first
  NxTest.assert(u, 'MUSI vzniknut zaznam — inak by zasuvka bola bez kovania a Kontrola by mlcala')
  NxTest.assert_equal('drawer_kit_missing', u['reason'], 'receptova polozka = RED')
  NxTest.assert_equal('members_skipped', u['base_reason'])
  NxTest.assert_equal(true, u['blocks_export'], 'RED zastavuje export vratane VEPO')
  NxTest.assert(c::HWS.unmapped_reason_sk(u).to_s.length > 10, 'veta semaforu existuje')
end

# ============================================================================
# R6 — MARKER KOMPATIBILITY
# ============================================================================

NxTest.test('D-118b (R6): sentinel = std 5, obsah bez neho ostava na svojom std') do
  c = NxD118b
  sets = c.seed_norm
  mapping = c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
  # KOV-E1a: seed uz nesie AJ sety vyklopov (`code_by_param`), a NAJVYSSI
  # marker vyhrava — sentinel sa preto skusa nad seedom BEZ nich.
  bez_lift = sets.reject { |s| s['generic_type'] == 'lift' }
  NxTest.assert_equal(c::HWS::STD_LIFT_FORMS, c::HWS.snapshot_std(mapping, sets),
                      'seed nesie sety vyklopov -> std 6')
  NxTest.assert_equal(c::HWS::STD_SKIP_CODE, c::HWS.snapshot_std(mapping, bez_lift),
                      'seed nesie Tip-On sety so sentinelom')

  # KOV-G1a: sentinel zije UZ AJ v KODOVOM PASME (platnicka setu nôh pod
  # 55 mm), takze „obsah bez sentinelu" musi vynechat aj ten set.
  bez = bez_lift.reject { |s| c::TIPON_SETY.include?(s['set_id']) || s['set_id'] == 'nohy-podla-sokla' }
  NxTest.assert_equal(c::HWS::STD_HEIGHT_VARIANT, c::HWS.snapshot_std(mapping, bez),
                      'bez sentinelu ostava marker na 4 — spatna citatelnost sa neblokuje zbytocne')
  nohy = bez_lift.select { |s| s['set_id'] == 'nohy-podla-sokla' }
  NxTest.assert_equal(c::HWS::STD_SKIP_CODE, c::HWS.snapshot_std({}, nohy),
                      'KOV-G1a: sentinel v KODOVOM pasme nesie ten isty marker ako v rade')
  NxTest.assert(c::HWS::STD_SUPPORTED.include?(c::HWS::STD_SKIP_CODE),
                'novy marker je medzi podporovanymi')
  NxTest.assert(Noxun::Engine::HardwareSets::SEED_VERSION >= 5, 'D-118b seed = 5; KOV-F1 bumplo na 6')
end

# ============================================================================
# R7 — MIGRACIA KNIZNICE
# ============================================================================

NxTest.test('D-118b (R7): nedotknuty seed tvar sa nahradi, upraveny set ostava') do
  c = NxD118b
  # Stara (v4) kniznica: antracit set so ZLYM kodom + Tip-On set BEZ modulu
  # + legacy set so starym nazvom — presne tvary zo `LEGACY_SEED_SHAPES`.
  stare = c::HWS::LEGACY_SEED_SHAPES.values_at('atira-antracit-h70-sisy',
                                               'atira-biela-h70-p2o',
                                               'vysuv-atira-biela-h70').map(&:first)
  # ...a JEDEN set, ktory si pouzivatel upravil (iny nazov).
  upraveny = Marshal.load(Marshal.dump(c::HWS::LEGACY_SEED_SHAPES['atira-biela-h144-p2o'].first))
  upraveny['name'] = 'Moja Atira'
  sets = c::HWS.normalize_sets(stare + [upraveny])
  merged, _map, changed = c::HWS.merge_seed(sets, {}, 4)
  NxTest.assert(changed, 'starsia sada = merge prebehol')
  by_id = {}
  merged.each { |s| by_id[s['set_id']] = s }

  NxTest.assert_equal('357889', by_id['atira-antracit-h70-sisy']['members'].first['code_by_nl']['470'],
                      'zly kod sa opravil')
  NxTest.assert_equal(2, by_id['atira-biela-h70-p2o']['members'].length,
                      'PTOs modul pribudol do nedotknuteho setu')
  NxTest.assert_equal('Výsuv (staré zákazky)', by_id['vysuv-atira-biela-h70']['name'],
                      'legacy set sa premenoval')
  NxTest.assert_equal('Moja Atira', by_id['atira-biela-h144-p2o']['name'],
                      'POUZIVATELOM upraveny set ostava nedotknuty')
  NxTest.assert_equal(1, by_id['atira-biela-h144-p2o']['members'].length,
                      '… vratane jeho clenov (nikdy sa nedoplna do cudzieho setu)')
  NxTest.assert_equal(c::HWS::SEED_SETS.length, merged.length, 'chybajuce sety sa doplnili')
end

# ============================================================================
# R8 — VALIDACIA
# ============================================================================

NxTest.test('D-118b (R8): `none` je vyhradene pre bunku radu, nie pre pevny kod') do
  c = NxD118b
  bad, errs = c::HWS.validate_member({ 'per' => 'unit', 'qty' => 1, 'code' => 'none' }, 0)
  NxTest.assert_equal(nil, bad, 'pevny kod `none` sa odmietne')
  NxTest.assert(errs.first.to_s.include?('none'), errs.inspect)

  ok, errs2 = c::HWS.validate_member({ 'per' => 'unit', 'qty' => 1,
                                       'code_by_nl' => { '350' => '352908', '620' => 'NONE' } }, 0)
  NxTest.assert_equal([], errs2, errs2.inspect)
  NxTest.assert_equal(c::HWS::SKIP_CODE, ok['code_by_nl']['620'],
                      'sentinel sa uklada kanonicky malymi pismenami')
end

NxTest.test('D-118b (R3): supis clenov PRIZNA vedome preskoceny modul') do
  c = NxD118b
  ex = c::HWS.explain(c.drawer_item(70, 620), c.tipon_state)
  NxTest.assert_equal([], ex['problems'], ex['problems'].inspect)
  skipped = ex['members'].select { |m| m['skipped'] }
  NxTest.assert_equal(1, skipped.length, 'modul je v supise ako vedome preskoceny')
  NxTest.assert_equal('PTOs mechanizmus', skipped.first['label'])
  NxTest.assert_equal(nil, skipped.first['code'], 'a NEMA kod')
end

# ============================================================================
# R9 — NALEZY CODEX #321 (kolo 1)
# ============================================================================

module NxD118b
  # Minimalny model (vzor `test_h1a_sety.rb`) — snapshot v NOXUN dict.
  class Model
    def initialize
      @attrs = {}
    end

    def get_attribute(dict, key)
      (@attrs[dict] || {})[key]
    end

    def set_attribute(dict, key, val)
      (@attrs[dict] ||= {})[key] = val
    end
  end
end

NxTest.test('D-118b (R9): veta pre `members_skipped` nehovori „typ nema priradeny set"') do
  c = NxD118b
  u = { 'reason' => 'drawer_kit_missing', 'base_reason' => 'members_skipped',
        'set_id' => 'atira-biela-h70-p2o', 'generic_type' => 'slide' }
  txt = c::HWS.unmapped_reason_sk(u)
  NxTest.assert(txt.include?('ani jednu položku'), "zavadzajuca veta: #{txt}")
  NxTest.refute(txt.include?('nemá priradený set'), "fallback sa NESMIE pouzit: #{txt}")
end

NxTest.test('D-118b (R9): supis (explain) prizna, ked set nevyda ANI JEDNU polozku') do
  c = NxD118b
  # Ta ista fixtura ako v R5: `none` LEN pre NL 420 (Codex #337 N1).
  sets = c.seed_norm.map do |s|
    next s unless s['set_id'] == 'atira-biela-h70-p2o'

    copy = Marshal.load(Marshal.dump(s))
    copy['members'].each { |m| m['code_by_nl']['420'] = c::HWS::SKIP_CODE }
    copy
  end
  family = sets.select { |s| s['set_id'].start_with?('atira-biela-') && s['set_id'].end_with?('p2o') }
  st = c.state_of(sets, c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS)
                          .merge(c::TIPON_METAL => c::HWS.height_selector_for(family)))
  ex = c::HWS.explain(c.drawer_item(70, 420), st)
  NxTest.assert_equal(1, ex['problems'].length, "panel a supis sa nesmu rozist: #{ex.inspect}")
  NxTest.assert(ex['problems'].first.include?('ani jednu položku'), ex['problems'].inspect)
end

NxTest.test('D-118b (R9): „Doplniť nové predvoľby" OSVIEZI nedotknutu definiciu v projekte') do
  c = NxD118b
  # Projekt uz MA triedny kluc aj zmrazenu STARU definiciu (v4 tvar bez modulu)
  # + jeden set, ktory si pouzivatel upravil. Bez osviezenia by akcia vratila
  # `:none` a zakazka by dalej objednavala bez PTOs modulu (Codex #321 P1).
  stary = c::HWS.normalize_sets([c::HWS::LEGACY_SEED_SHAPES['atira-biela-h70-p2o'].first]).first
  moj = Marshal.load(Marshal.dump(c::HWS::LEGACY_SEED_SHAPES['atira-antracit-h70-sisy'].first))
  moj['name'] = 'Moja antracit'
  moj_norm = c::HWS.normalize_sets([moj]).first
  m = c::Model.new
  c::HWS.write_project_state(m, 'mapping' => { c::TIPON_METAL => 'atira-biela-h70-p2o' },
                                'sets' => { 'atira-biela-h70-p2o' => stary,
                                            'atira-antracit-h70-sisy' => moj_norm })
  res, _added_sets, _added_map, refreshed = c::HWS.merge_project_sets_seed!(m)
  NxTest.assert_equal(:updated, res, 'akcia sa NESMIE skoncit ako „niet co doplnat"')
  NxTest.assert(Array(refreshed).include?('atira-biela-h70-p2o'), Array(refreshed).inspect)
  NxTest.refute(Array(refreshed).include?('atira-antracit-h70-sisy'),
                'pouzivatelom upravena definicia sa NEPREPISE')

  _, st = c::HWS.project_state_status(m)
  NxTest.assert_equal(2, st['sets']['atira-biela-h70-p2o']['members'].length,
                      'projekt uz ma PTOs modul')
  NxTest.assert_equal('Moja antracit', st['sets']['atira-antracit-h70-sisy']['name'],
                      'a vlastny nazov ostal')
end

NxTest.test('D-118b (R9): osvieženie berie definiciu z KNIZNICE, nie zo zabudovaneho seedu') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxD118b
  # Pouzivatel si v GLOBALI ten isty set upravil (vlastny kod). „Doplniť nové
  # predvoľby" kopiruje GLOBAL do projektu — nesmie teda dosadit zabudovany
  # seed a prepisat mu jeho kody (Codex #321 kolo 2 P2).
  lib_set = Marshal.load(Marshal.dump(c::HWS::SEED_SETS.find { |s| s['set_id'] == 'atira-biela-h70-p2o' }))
  lib_set['members'][1]['code_by_nl']['420'] = '999420'
  lib_sets = c::HWS::SEED_SETS.map { |s| s['set_id'] == 'atira-biela-h70-p2o' ? lib_set : s }
  FileUtils.mkdir_p(c::HWS.dir)
  c::STORE.write(c::HWS.path, 'std' => c::HWS::STD_SKIP_CODE, 'seed_version' => c::HWS::SEED_VERSION,
                              'sets' => c::HWS.normalize_sets(lib_sets),
                              'mapping' => c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS))
  FileUtils.rm_f("#{c::HWS.path}.bak")
  c::STORE.invalidate(c::HWS.path)
  c::HWS.reset_library_state!
  begin
    stary = c::HWS.normalize_sets([c::HWS::LEGACY_SEED_SHAPES['atira-biela-h70-p2o'].first]).first
    m = c::Model.new
    c::HWS.write_project_state(m, 'mapping' => { c::TIPON_METAL => 'atira-biela-h70-p2o' },
                                  'sets' => { 'atira-biela-h70-p2o' => stary })
    res, _a, _b, refreshed = c::HWS.merge_project_sets_seed!(m)
    NxTest.assert_equal(:updated, res)
    NxTest.assert_equal(['atira-biela-h70-p2o'], Array(refreshed))
    _, st = c::HWS.project_state_status(m)
    NxTest.assert_equal('999420',
                        st['sets']['atira-biela-h70-p2o']['members'][1]['code_by_nl']['420'],
                        'do projektu ide KNIZNICNA definicia, nie zabudovany seed')
  ensure
    [c::HWS.path, "#{c::HWS.path}.bak"].each { |f| FileUtils.rm_f(f) }
    c::STORE.invalidate(c::HWS.path)
    c::HWS.reset_library_state!
  end
end

NxTest.test('D-118b (R8) + KOV-G1a: `none` je PLATNE v kodovom pasme, v selectore setov je meno') do
  c = NxD118b
  # D-118b tu sentinel ZAKAZOVALO — a to z JEDINEHO dovodu: marker `std` sa
  # naň nepytal, takze starsi plugin by z bunky vyrobil riadok s kodom „none".
  # KOV-G1a mu marker dal (`skip_code_present?` vidi aj pasma), takze zakaz
  # zanikol a pasmo `none` znamena „v tomto pasme clen vedome nevznika".
  # Codex #337 N1: aspon JEDNO pasmo musi mat skutocny kod — clen, ktoreho su
  # VSETKY pasma `none`, by nikdy nic neobjednal (rovnaky tichy nezmysel ako
  # pevny kod `none`), preto ho validacia odmieta.
  ok, errs = c::HWS.validate_member(
    { 'per' => 'unit', 'qty' => 1,
      'param_bands' => { 'param' => 'height',
                         'bands' => [{ 'min' => 10.0, 'max' => 20.0, 'code' => 'NONE' },
                                     { 'min' => 55.0, 'max' => 220.0, 'code' => '9079' }] } }, 0
  )
  NxTest.assert_equal([], errs, errs.inspect)
  NxTest.assert_equal(c::HWS::SKIP_CODE, ok['param_bands']['bands'].first['code'],
                      'sentinel sa aj v pasme uklada kanonicky malymi pismenami')
  _bad, errs_all = c::HWS.validate_member(
    { 'per' => 'unit', 'qty' => 1,
      'param_bands' => { 'param' => 'height',
                         'bands' => [{ 'min' => 10.0, 'max' => 20.0, 'code' => 'none' }] } }, 0
  )
  NxTest.assert(errs_all.first.to_s.include?('všetky pásma'), errs_all.inspect)

  # Selector mapovania nesie `set_id` — tam je „none" legitimne meno setu.
  sel, errs2 = c::HWS.validate_param_bands(
    { 'param' => 'front_height',
      'bands' => [{ 'min' => 0.0, 'max' => 100.0, 'set_id' => 'none' }] }, 'set_id', 'výber'
  )
  NxTest.assert_equal([], errs2, errs2.inspect)
  NxTest.assert_equal('none', sel['bands'].first['set_id'])
end
