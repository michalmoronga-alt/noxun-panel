# frozen_string_literal: true
# Testy KOV-D1c: PRODUKCNY SEED ALTERNATIVNEJ RODINY „ATIRA ANTRACIT".
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 6 novych seed setov `atira-antracit-h{70,144,176}-{sisy,p2o}` — rovnaka
#      klasifikacia ako biela rodina (drawer / metal / Hettich / InnoTech Atira),
#      vlastny kmen NAZVU (inak by ich `family_stem` zlucil s bielou) a
#      `set_system` = `atira`
#   R2 KODY presne podla tabulky draftu #13 §1 (Demos 6.9.2026) a LEN pre bunky
#      radov receptov v1 — TABULKOVA FIXTURA nizsie je DRUHY, nezavisly zapis
#      tych istych dat; chybajuca bunka = kluc v `code_by_nl` NEPRITOMNY
#      (nikdy prazdny retazec, nikdy kod inej farby/dlzky)
#   R3 chybajuca bunka pod ANTRACIT selektorom = RED `drawer_kit_missing`
#      (`base_reason` `nl_missing`) a ZIADNY riadok nakupu — nikdy sa neobjedna
#      biely kit k antracitovej zakazke
#   R4 `merge_seed` zo starsej kniznice (v3) doplni PRESNE 6 setov a NEZMENI
#      ani mapovanie, ani pouzivatelske sety; `MAPPING_ADDITIONS` ostava BIELA
#      (predvolba noveho projektu sa nemeni)
#   R5 `family_groups` vidi antracit SiSy a antracit Tip-On ako DVE rodiny po
#      troch pasmach; ponuka triedneho kluca (`class_set_options`) ma preto po
#      davke dve volby — bielu a antracitovu
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do seedu spadne uvedeny test):
#   M1 do antracit bunky sa vlozi CUDZI (biely) kod, napr. H176/520 = 357777
#      -> „KOV-D1c (R2): kody antracitu presne podla tabulky Demos"
#         + „KOV-D1c (R3): chybajuca bunka je RED, nikdy tichá zámena"
#   M2 chybajuca bunka sa zapise ako PRAZDNY RETAZEC ('520' => '')
#      -> „KOV-D1c (R2): chybajuca bunka = kluc CHYBA, nikdy prazdna hodnota"
#   M3 antracit set sa prida do `MAPPING_ADDITIONS` (predvolba by prestala byt
#      biela) -> „KOV-D1c (R4): predvolba noveho projektu ostava BIELA"
#   M4 nazov antracit setu sa zmeni na „Atira biela H70 — klasické"
#      -> „KOV-D1c (R5): antracit je VLASTNA rodina, nezlucuje sa s bielou"
require_relative '../helper' unless defined?(NxTest)

module NxD1c
  E   = Noxun::Engine
  HWS = E::HardwareSets
  REC = E::Recipes

  CLASSIC_METAL = 'class:slide|classic|metal'
  TIPON_METAL   = 'class:slide|tipon|metal'

  # --- TABULKOVA FIXTURA (draft #13 §1, „Antracit kity Atira", Demos 6.9.2026)
  # Zapisana RUCNE z tabulky — nie odvodena zo seedu. Bunka, ktora v tabulke
  # nie je (alebo nie je v rade receptu v1), tu NEMA kluc, presne ako v seede.
  # NL 260/300 z tabulky sa vedome NEUVADZAJU: su mimo radov receptov v1.
  ANTRACIT = {
    'atira-antracit-h70-sisy' => { 'opening' => 'classic', 'hv' => 70,
                                   'codes' => { '350' => '357887', '420' => '357888',
                                                '470' => '348777', '520' => '357890' } },
    'atira-antracit-h144-sisy' => { 'opening' => 'classic', 'hv' => 144,
                                    'codes' => { '350' => '357926', '420' => '357927',
                                                 '470' => '357928' } },
    'atira-antracit-h176-sisy' => { 'opening' => 'classic', 'hv' => 176,
                                    'codes' => { '420' => '357969', '470' => '357970' } },
    'atira-antracit-h70-p2o' => { 'opening' => 'tipon', 'hv' => 70,
                                  'codes' => { '350' => '357914', '420' => '357915',
                                               '470' => '357916', '520' => '357917' } },
    'atira-antracit-h144-p2o' => { 'opening' => 'tipon', 'hv' => 144,
                                   'codes' => { '350' => '357955', '420' => '357956',
                                                '470' => '357957', '520' => '357958' } },
    'atira-antracit-h176-p2o' => { 'opening' => 'tipon', 'hv' => 176,
                                   'codes' => { '350' => '357996', '420' => '357997',
                                                '470' => '357998', '520' => '357999' } }
  }.freeze

  # Bunky radov v1, ktore antracit NEMA (= musia byt RED).
  CHYBAJUCE = [['atira-antracit-h176-sisy', 350.0], ['atira-antracit-h176-sisy', 520.0],
               ['atira-antracit-h176-sisy', 620.0], ['atira-antracit-h70-p2o', 620.0],
               ['atira-antracit-h144-p2o', 620.0], ['atira-antracit-h176-p2o', 620.0]].freeze

  module_function

  def seed_norm
    HWS.normalize_sets(HWS::SEED_SETS)
  end

  def by_id
    out = {}
    seed_norm.each { |s| out[s['set_id']] = s }
    out
  end

  def set_of(sid)
    by_id[sid]
  end

  def codes_of(sid)
    set_of(sid)['members'].first['code_by_nl']
  end

  # SUROVY (nenormalizovany) rad zo `SEED_SETS`. Normalizacia je TOLERANTNA —
  # prazdnu hodnotu ticho ZAHODI — takze „prazdny retazec namiesto chybajucej
  # bunky" by sa cez normalizovany tvar nedal odhalit; kontroluje sa preto
  # ZDROJOVY literal.
  def raw_codes_of(sid)
    HWS::SEED_SETS.find { |s| s['set_id'] == sid }['members'].first['code_by_nl']
  end

  def state_of(sets, mapping)
    idx = {}
    HWS.normalize_sets(sets).each { |s| idx[s['set_id']] = s }
    { 'mapping' => mapping, 'sets' => idx }
  end

  # Projektovy stav CELEHO seedu, v ktorom si pouzivatel prepol triedny kluc
  # na antracitovu rodinu (presne to, co ulozi selektor Studia — hodnotu
  # vyraba PRODUKCNA `height_selector_for`, nie ruka).
  def antracit_state(opening = 'classic')
    sets = seed_norm
    suffix = opening == 'tipon' ? 'p2o' : 'sisy'
    family = sets.select { |s| s['set_id'].start_with?('atira-antracit-') && s['set_id'].end_with?(suffix) }
    key = opening == 'tipon' ? TIPON_METAL : CLASSIC_METAL
    mapping = HWS::SEED_MAPPING.merge(HWS::MAPPING_ADDITIONS)
              .merge(key => HWS.height_selector_for(family))
    state_of(sets, mapping)
  end

  # Receptova polozka zasuvky (tvar, ktory emituje `Construction`).
  def drawer_item(height_variant, nl, opening = 'classic')
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'source' => 'recipe',
      'rule_id' => "recipe:atira_#{opening == 'tipon' ? 'p2o' : 'sisy'}_v1",
      'params' => { 'opening_mode' => opening, 'drawer_construction' => 'metal',
                    'system' => 'atira', 'height_variant' => height_variant.to_f,
                    'nominal_length' => nl.to_f } }
  end

  # Rady receptov v1 per vyska — jediny zdroj toho, ktore bunky sa vobec
  # objednavaju (test si ich necita z tabulky, ale z RECEPTU).
  def series_for(opening)
    rid = opening == 'tipon' ? 'atira_p2o_v1' : 'atira_sisy_v1'
    REC.load(rid)[:nl_series_by_height]
  end
end

# ============================================================================
# R1 — SETY EXISTUJU A SU SPRAVNE ZARADENE
# ============================================================================

NxTest.test('KOV-D1c (R1): 6 antracit setov, klasifikacia zhodna s bielou') do
  c = NxD1c
  NxTest.assert_equal(6, c::ANTRACIT.length, 'fixtura ma 6 setov')
  c::ANTRACIT.each do |sid, row|
    set = c.set_of(sid)
    NxTest.assert(set, "seed set #{sid} chyba")
    NxTest.assert_equal('slide', set['generic_type'], sid)
    NxTest.assert_equal('drawer', set['use_type'], sid)
    NxTest.assert_equal(row['opening'], set['opening_mode'], sid)
    NxTest.assert_equal('metal', set['drawer_construction'], sid)
    NxTest.assert_equal('Hettich', set['manufacturer'], sid)
    NxTest.assert_equal('InnoTech Atira', set['series'], sid)
    NxTest.assert_equal(row['hv'], set['height_variant'], sid)
    NxTest.assert_equal('atira', c::HWS.set_system(set),
                        "#{sid}: bez systemu by sa set ani neponukol, ani neulozil")
    NxTest.assert_equal(nil, set['active'], "#{sid}: set je AKTIVNY (sparse priznak sa neuklada)")
    members = set['members']
    NxTest.assert_equal(1, members.length, "#{sid}: jeden clen (K-sada)")
    NxTest.assert_equal(['unit', 1, 'K-sada'],
                        [members.first['per'], members.first['qty'], members.first['label']], sid)
  end
  # Seed sa nesmie „stratit" pri normalizacii (whitelist SET_KEYS je kontrakt).
  NxTest.assert_equal(c::HWS::SEED_SETS.length, c.seed_norm.length, 'ziadny seed set nevypadol')
end

# ============================================================================
# R2 — KODY PRESNE PODLA TABULKY, CHYBAJUCA BUNKA = KLUC CHYBA
# ============================================================================

NxTest.test('KOV-D1c (R2): kody antracitu presne podla tabulky Demos') do
  c = NxD1c
  c::ANTRACIT.each do |sid, row|
    NxTest.assert_equal(row['codes'], c.codes_of(sid), "#{sid}: rad kodov sa rozisiel s tabulkou")
  end
  # ZIADNY antracit kod sa nesmie zhodovat s bielym (copy-paste by objednal
  # bielu K-sadu k antracitovej zakazke a nakup by to uz neodhalil).
  white = c.seed_norm.select { |s| s['set_id'].start_with?('atira-biela-') }
               .flat_map { |s| s['members'].first['code_by_nl'].values }
  anthr = c::ANTRACIT.values.flat_map { |r| r['codes'].values }
  NxTest.assert_equal([], (white & anthr), 'antracit a biela nesmu zdielat kod')
  NxTest.assert_equal(anthr.length, anthr.uniq.length, 'kod sa v antracite neopakuje')
end

NxTest.test('KOV-D1c (R2): chybajuca bunka = kluc CHYBA, nikdy prazdna hodnota') do
  c = NxD1c
  c::ANTRACIT.each do |sid, row|
    raw = c.raw_codes_of(sid)
    # Zdrojovy literal sa musi zhodovat s tabulkou AJ pred normalizaciou —
    # inak by prazdna hodnota v seede vyzerala ako „bunka bez kodu".
    NxTest.assert_equal(row['codes'], raw, "#{sid}: surovy rad zo SEED_SETS")
    raw.each do |nl, code|
      NxTest.assert(code.is_a?(String) && !code.strip.empty?,
                    "#{sid} NL #{nl}: prazdna hodnota nie je „bunka bez kodu“, ale poškodený rad")
      NxTest.assert(code.match?(/\A\d+\z/), "#{sid} NL #{nl}: kod #{code.inspect} nie je cislo Demosu")
    end
  end
  c::CHYBAJUCE.each do |(sid, nl)|
    key = nl.to_i.to_s
    NxTest.assert(!c.raw_codes_of(sid).key?(key),
                  "#{sid} NL #{key}: bunka nema kod -> kluc tam NESMIE byt (ani prazdny)")
    NxTest.assert(!c.codes_of(sid).key?(key), "#{sid} NL #{key}: ani po normalizacii")
  end
end

NxTest.test('KOV-D1c (R2): kody su LEN pre bunky radov receptov v1') do
  c = NxD1c
  %w[classic tipon].each do |opening|
    series = c.series_for(opening)
    suffix = opening == 'tipon' ? 'p2o' : 'sisy'
    series.each do |hv, list|
      sid = "atira-antracit-h#{hv}-#{suffix}"
      allowed = list.map { |nl| nl.to_i.to_s }
      c.codes_of(sid).each_key do |nl|
        NxTest.assert(allowed.include?(nl),
                      "#{sid}: NL #{nl} nie je v rade receptu — taky kit sa neobjednava")
      end
    end
  end
end

# ============================================================================
# R3 — CHYBAJUCA BUNKA JE RED, NIKDY TICHA ZAMENA
# ============================================================================

NxTest.test('KOV-D1c (R3): antracit selektor objedna ANTRACIT kod') do
  c = NxD1c
  state = c.antracit_state
  cat = [{ 'item_code' => '357970', 'name_sk' => 'K-sada Atira antracit H176/470',
           'category' => 'VYSUVY', 'unit' => 'ks', 'price_eur_vat' => 46.0 }]
  exp = c::HWS.expand([c.drawer_item(176, 470)], state, catalog: cat)
  NxTest.assert_equal([], exp['unmapped'], exp['unmapped'].inspect)
  NxTest.assert_equal(['357970'], exp['rows'].map { |r| r['code'] })
  NxTest.assert_equal(['atira-antracit-h176-sisy'], exp['rows'].first['sources'].map { |s| s['set_id'] })

  # Tip-On vetva ide na vlastnu rodinu.
  tip = c::HWS.expand([c.drawer_item(144, 520, 'tipon')], c.antracit_state('tipon'))
  NxTest.assert_equal(['357958'], tip['rows'].map { |r| r['code'] })
end

NxTest.test('KOV-D1c (R3): chybajuca bunka je RED, nikdy tichá zámena') do
  c = NxD1c
  # SiSy H176/520 — antracit kit NEEXISTUJE; biela ho ma (357777).
  exp = c::HWS.expand([c.drawer_item(176, 520)], c.antracit_state)
  NxTest.assert_equal([], exp['rows'], 'ziadny riadok — nikdy sa neobjedna biely kit')
  u = exp['unmapped'].first
  NxTest.assert(u, 'chybajuca bunka MUSI vyrobit zaznam nemapovanej polozky')
  NxTest.assert_equal('drawer_kit_missing', u['reason'], 'receptova polozka = RED')
  NxTest.assert_equal('nl_missing', u['base_reason'])
  NxTest.assert_equal('atira-antracit-h176-sisy', u['set_id'])
  NxTest.assert(c::HWS.unmapped_reason_sk(u).include?('357777') == false,
                'hlaska nesmie navadzat na biely kod')

  # A to iste pre KAZDU chybajucu bunku — vratane vsetkych NL 620.
  c::CHYBAJUCE.each do |(sid, nl)|
    opening = sid.end_with?('p2o') ? 'tipon' : 'classic'
    hv = sid[/h(\d+)-/, 1].to_i
    e = c::HWS.expand([c.drawer_item(hv, nl, opening)], c.antracit_state(opening))
    NxTest.assert_equal([], e['rows'], "#{sid} NL #{nl.to_i}: nesmie vzniknut riadok nakupu")
    NxTest.assert_equal(['drawer_kit_missing', sid],
                        [e['unmapped'].first['reason'], e['unmapped'].first['set_id']],
                        "#{sid} NL #{nl.to_i}")
  end
end

NxTest.test('KOV-D1c (R3): biela rodina je nad radmi v1 NADALEJ uplna') do
  c = NxD1c
  state = c.state_of(c.seed_norm, c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS))
  %w[classic tipon].each do |opening|
    c.series_for(opening).each do |hv, list|
      list.each do |nl|
        exp = c::HWS.expand([c.drawer_item(hv.to_i, nl, opening)], state)
        NxTest.assert_equal([], exp['unmapped'],
                            "biela H#{hv} NL #{nl.to_i}: #{exp['unmapped'].inspect}")
        NxTest.assert_equal(1, exp['rows'].length, "biela H#{hv} NL #{nl.to_i}")
      end
    end
  end
end

# ============================================================================
# R4 — MERGE DO EXISTUJUCEJ KNIZNICE A PREDVOLBA
# ============================================================================

NxTest.test('KOV-D1c (R4): `merge_seed` z v3 doplni PRESNE 6 setov') do
  c = NxD1c
  # Kniznica stavu v3 = seed BEZ antracitu + jeden pouzivatelsky set.
  user = { 'set_id' => 'moj-vysuv', 'name' => 'Môj výsuv', 'generic_type' => 'slide',
           'members' => [{ 'code' => 'X1', 'per' => 'unit', 'qty' => 1 }] }
  v3 = c::HWS.normalize_sets(
    c::HWS::SEED_SETS.reject { |s| s['set_id'].start_with?('atira-antracit-') } + [user]
  )
  mapping = c::HWS.normalize_mapping(
    c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS).merge('slide' => 'moj-vysuv'), v3
  )
  merged, map, changed = c::HWS.merge_seed(v3, mapping, 3)
  NxTest.assert_equal(true, changed)
  pribudlo = merged.map { |s| s['set_id'] } - v3.map { |s| s['set_id'] }
  NxTest.assert_equal(c::ANTRACIT.keys.sort, pribudlo.sort, 'pribudnu PRESNE antracit sety')
  NxTest.assert_equal(mapping, map, 'mapovanie sa merge-om NEZMENI')
  NxTest.assert(merged.any? { |s| s['set_id'] == 'moj-vysuv' }, 'pouzivatelsky set OSTAVA')
  NxTest.assert_equal(user['members'], merged.find { |s| s['set_id'] == 'moj-vysuv' }['members'],
                      'pouzivatelsky set sa NEPREPISUJE')

  # Idempotencia: kniznica uz na aktualnej verzii sa nemeni.
  _same, _m, changed2 = c::HWS.merge_seed(merged, map, c::HWS::SEED_VERSION)
  NxTest.assert_equal(false, changed2, 'druhy beh uz nic nedopĺňa')
end

NxTest.test('KOV-D1c (R4): predvolba noveho projektu ostava BIELA') do
  c = NxD1c
  refs = c::HWS::MAPPING_ADDITIONS.values.flat_map { |v| c::HWS.value_set_ids(v) }
  NxTest.assert_equal([], refs.select { |sid| sid.start_with?('atira-antracit-') },
                      'antracit set NESMIE byt v `MAPPING_ADDITIONS` — predvolba je biela')
  lib = c::HWS.seed_library
  NxTest.assert_equal(c::ANTRACIT.keys.sort,
                      lib['sets'].map { |s| s['set_id'] }
                         .select { |sid| sid.start_with?('atira-antracit-') }.sort,
                      'cerstva kniznica antracit sety MA (len sa nepouzivaju automaticky)')
  NxTest.assert_equal('atira-biela-h70-sisy',
                      lib['mapping'][c::CLASSIC_METAL]['bands'].first['set_id'],
                      'novy projekt zacina na bielej')
  NxTest.assert_equal(4, c::HWS::SEED_VERSION, 'antracit seed = bump SEED_VERSION na 4')
end

# ============================================================================
# R5 — RODINY A PONUKA V STUDIU
# ============================================================================

NxTest.test('KOV-D1c (R5): antracit je VLASTNA rodina, nezlucuje sa s bielou') do
  c = NxD1c
  variant = c.seed_norm.select { |s| s['height_variant'] }
  groups = c::HWS.family_groups(variant)
  # Rodina = (vyrobca, rada, nazov bez tokenu H<cislo>).
  sisy = groups[['Hettich', 'InnoTech Atira', 'Atira antracit — klasické']]
  tipon = groups[['Hettich', 'InnoTech Atira', 'Atira antracit — Tip-On']]
  NxTest.assert(sisy, "antracit SiSy rodina chyba: #{groups.keys.inspect}")
  NxTest.assert(tipon, "antracit Tip-On rodina chyba: #{groups.keys.inspect}")
  NxTest.assert_equal([70, 144, 176], sisy.map { |s| s['height_variant'] }.sort)
  NxTest.assert_equal([70, 144, 176], tipon.map { |s| s['height_variant'] }.sort)
  NxTest.assert(groups.key?(['Hettich', 'InnoTech Atira', 'Atira biela — klasické']),
                'biela rodina ostava samostatna')
  NxTest.assert_equal(4, groups.length, "prave 4 rodiny: #{groups.keys.inspect}")
end

NxTest.test('KOV-D1c (R5): Studio ponukne pre triedny kluc bielu AJ antracitovu rodinu') do
  c = NxD1c
  opts = c::HWS.class_set_options(c::CLASSIC_METAL, c.seed_norm, {}, [])
  NxTest.assert_equal(2, opts.length, "dve rodiny: #{opts.map { |o| o['label'] }.inspect}")
  NxTest.assert(opts.all? { |o| o['selector'] }, 'obe volby su PASMOVE (nikdy pevny set)')
  ids = opts.map { |o| o['selector']['bands'].map { |b| b['set_id'] } }
  NxTest.assert(ids.include?(%w[atira-antracit-h70-sisy atira-antracit-h144-sisy
                                atira-antracit-h176-sisy]), ids.inspect)
  NxTest.assert(ids.include?(%w[atira-biela-h70-sisy atira-biela-h144-sisy
                                atira-biela-h176-sisy]), ids.inspect)
  NxTest.assert_equal(2, opts.map { |o| o['label'] }.uniq.length,
                      'popisky sa musia lisit — inak si pouzivatel farbu nevyberie')

  tip = c::HWS.class_set_options(c::TIPON_METAL, c.seed_norm, {}, [])
  NxTest.assert_equal(2, tip.length, "dve Tip-On rodiny: #{tip.map { |o| o['label'] }.inspect}")
  # Klasicke sety sa do Tip-On ponuky NEDOSTANU (a naopak).
  NxTest.assert_equal([], tip.flat_map { |o| o['selector']['bands'].map { |b| b['set_id'] } }
                             .select { |sid| sid.end_with?('-sisy') })
end
