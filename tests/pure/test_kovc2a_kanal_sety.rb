# frozen_string_literal: true
# Testy KOV-C2a: PRIPRAVA AKTIVACIE ZASUVIEK — 4. materialovy kanal, ABS seed
# per rola, klasifikacne pole `height_variant` na setoch, seed klasifikovanych
# setov + triedne mapovania a citanie triedneho kluca v resolveri.
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 4. materialovy kanal `:drawer` — projektovy kluc, UNI 16 fallback,
#      VLASTNA idempotentna migracia `ensure_drawer_uni!`, nove roly v
#      `thickness_ok_for?`
#   R2 ABS seed per rola (SEED_VERSION 4) — dno bez olepu, ostatne L1 1,0;
#      merge do existujuceho suboru NEPREPISE pouzivatelske pravidlo
#   R3 `height_variant` — volitelne klasifikacne pole LEN pri zasuvke,
#      bezstratovy round-trip VSETKYMI zapisovymi cestami, lazy std 4
#   R4 seed 8 klasifikovanych setov + `MAPPING_ADDITIONS` (add-if-absent)
#   R5 triedny kluc v resolveri: cabinet override -> projekt, ZIADNY fallback
#      na genericky `slide`, owner-level `slide@…` sa IGNORUJE, kompatibilita
#      setu (otvaranie · konstrukcia · system · vyska)
#   R6 ZIADNA aktivacia — vystupy existujucich zakaziek su CONTENT-identicke
#   R7 `override_keys_in_use` pozna triedne kluce
#
# MUTACIE (kazda overena rucne — po zaneseni chyby do core spadne uvedeny test):
#   M1 `resolve_mapping_value` pri chybajucom triednom kluci spadne na `slide`
#      -> „KOV-C2a (R5): chybajuce triedne mapovanie = `class_unmapped`…"
#   M2 `add_mapping_seed` prepise EXISTUJUCI kluc pouzivatela
#      -> „KOV-C2a (R4): `MAPPING_ADDITIONS` NEPREPISE pouzivatelsky kluc"
#   M3 seed setu chyba kod pre bunku radu receptu
#      -> „KOV-C2a (R4): completeness — KAZDA bunka radov v1 ma kit kod"
#   M4 `save_set!` / `build_set` stratia `height_variant` (editorska cesta)
#      -> „KOV-C2a (R3): `height_variant` prezije VSETKY zapisove cesty"
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

# UI vrstva (ochrana kolidujucich kopii) — headless nie je v require zozname
# helpera, takze sada si ju pyta sama (vzor `test_kovb1_sety.rb`).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
end

module NxC2a
  E     = Noxun::Engine
  HWS   = E::HardwareSets
  TAX   = E::HardwareTaxonomy
  MAT   = E::Materials
  ABS   = E::AbsRules
  CB    = E::CabinetBuilder
  REC   = E::Recipes
  STORE = E::JsonFileStore
  PC    = E::ProductionCore

  module_function

  # --- sandbox (vzor KOV-B1) ----------------------------------------------

  def with_library
    paths = [HWS.path, TAX.path]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    # Sandbox je ZDIELANY celym behom a niektore skorsie sady v nom nechavaju
    # taxonomiu v stave `:read_only` (simulacia „subor z novsej verzie").
    # Zapis KLASIFIKOVANEHO setu je nad takou taxonomiou fail-closed, takze si
    # ju tu vynulujeme — pri prvom pristupe sa naseeduje cerstva.
    FileUtils.rm_f(TAX.path)
    FileUtils.rm_f("#{TAX.path}.bak")
    STORE.invalidate(TAX.path)
    TAX.reset_state!
    yield
  ensure
    before.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
      FileUtils.rm_f("#{p}.bak")
      STORE.invalidate(p)
    end
    HWS.reset_library_state!
    TAX.reset_state!
  end

  def install(doc)
    FileUtils.mkdir_p(File.dirname(HWS.path))
    File.binwrite(HWS.path, JSON.pretty_generate(doc))
    STORE.invalidate(HWS.path)
    HWS.reset_library_state!
    true
  end

  def raw_lib
    JSON.parse(File.binread(HWS.path))
  end

  def model_with(state = nil)
    m = NxTest::FakeEntity.new
    m.set_attribute(E::Store::DICT, HWS::MODEL_KEY, state.to_json) if state
    m
  end

  # --- fixtury ------------------------------------------------------------

  # Set Atira H70 SiSy zo seedu (kanonicka podoba klasifikovaneho drawer setu).
  def seed_set(sid)
    HWS::SEED_SETS.find { |s| s['set_id'] == sid }
  end

  def snapshot_of(sets, mapping)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'std' => HWS.snapshot_std(mapping, by_id.values), 'mapping' => mapping, 'sets' => by_id }
  end

  def state_of(sets, mapping)
    by_id = {}
    HWS.normalize_sets(sets).each { |s| by_id[s['set_id']] = s }
    { 'mapping' => mapping, 'sets' => by_id }
  end

  # Receptova polozka vysuvu (tvar, ktory bude emitovat C2b).
  # `params` v `over` sa MERGUJU do defaultov; `raw_params` ich NAHRADI CELE
  # (Quadro nema `height_variant` a merge by mu default vysku ponechal).
  def drawer_item(over = {})
    o = over.dup
    raw = o.delete('raw_params')
    params = raw || { 'opening_mode' => 'classic', 'drawer_construction' => 'metal',
                      'system' => 'atira', 'height_variant' => 70.0,
                      'nominal_length' => 470.0 }.merge(o.delete('params') || {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'recipe:atira_sisy_v1',
      'params' => params, 'source' => 'recipe' }.merge(o)
  end

  # Legacy polozka vysuvu (dnesne pravidlo — ZIADNA klasifikacia v params).
  def legacy_item(over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel',
      'generic_type' => 'slide', 'quantity' => 1, 'rule_id' => 'vysuvy-nl-podla-hlbky',
      'params' => { 'nominal_length' => 470.0 }, 'source' => 'rule' }.merge(over)
  end

  # Cely seed (sety + mapovania) ako projektovy stav — presne to, co dostane
  # novy projekt.
  def seed_state
    lib = HWS.seed_library
    state_of(lib['sets'], lib['mapping'])
  end
end

# ============================================================================
# R1 — 4. MATERIALOVY KANAL `:drawer`
# ============================================================================

NxTest.test('KOV-C2a (R1): projektovy kluc zasuviek, UNI 16 fallback a nedeletovatelne ID') do
  c = NxC2a
  NxTest.assert(c::MAT::PROJECT_KEYS.include?('default_drawer_material_id'),
                '4. kanal musi byt v PROJECT_KEYS (dedenie projekt->korpus->dielec)')
  NxTest.assert_equal('UNI_ZASUVKA_16', c::MAT::PROJECT_FALLBACK['default_drawer_material_id'],
                      'fallback je UNI 16 mm (obe rady receptov stavaju na 16)')
  NxTest.assert(c::MAT::PROTECTED_SHEET_IDS.include?('UNI_ZASUVKA_16'),
                'fallback ID je NEDELETOVATELNE (inak by prvy vklad spadol)')
  NxTest.assert(c::MAT::UNI_ROLES.include?('drawer'), 'UNI rola `drawer`')
end

NxTest.test('KOV-C2a (R1): `eff_drawer` = projektova predvolba, inak UNI 16') do
  c = NxC2a
  eff = c::CB.effective_materials(nil, {})
  NxTest.assert_equal('UNI_ZASUVKA_16', eff['drawer'],
                      'bez modelu aj bez predvolby padne kanal na UNI 16')
  # Uroven skrinky pre tento kanal v C2a NEEXISTUJE — config kluc pridava C2b.
  eff2 = c::CB.effective_materials(nil, 'drawer_material_id' => 'CUDZI')
  NxTest.assert_equal('UNI_ZASUVKA_16', eff2['drawer'],
                      'override na skrinke sa v C2a este NECITA (C2b + CONFIG_SCHEMA bump)')
  m = NxTest::FakeEntity.new
  m.set_attribute(c::E::Store::DICT, 'default_drawer_material_id', 'REALNY_16')
  NxTest.assert_equal('REALNY_16', c::CB.effective_materials(m, {})['drawer'],
                      'projektova predvolba vyhrava nad fallbackom')
  # Ostatne tri kanaly sa NEZMENILI.
  NxTest.assert_equal(%w[back body drawer front], eff.keys.sort)
end

NxTest.test('KOV-C2a (R1): `thickness_ok_for?` pozna 4 roly dielcov zasuviek') do
  c = NxC2a
  NxTest.assert_equal(%w[drawer_bottom drawer_back box_side drawer_inner_front],
                      c::CB::DRAWER_ROLES)
  # Jedna domenova pravda s receptami (vazba je guard test, nie referencia —
  # `cabinet_builder` sa nacitava PRED `drawer_recipes`).
  NxTest.assert_equal([c::REC::ROLE_BOTTOM, c::REC::ROLE_BACK,
                       c::REC::ROLE_BOX_SIDE, c::REC::ROLE_INNER_FRONT],
                      c::CB::DRAWER_ROLES,
                      'roly musia sediet s `Recipes::ROLE_*`')
  c::CB::DRAWER_ROLES.each do |role|
    NxTest.assert(c::CB.thickness_ok_for?(role, 16.0, 16.0), "#{role}: 16 mm sedi")
    # Hrubka je VSTUP receptu — 18 mm tu prejde a odmietne ho az
    # `thickness_supported` receptu (C2b), nie tato funkcia.
    NxTest.assert(c::CB.thickness_ok_for?(role, 16.0, 18.0), "#{role}: 18 mm nie je vec tejto funkcie")
    NxTest.refute(c::CB.thickness_ok_for?(role, 16.0, 3.0), "#{role}: 3 mm je mimo rozsahu dosky")
  end
  # Korpusove roly sa NEZMENILI (presna zhoda).
  NxTest.refute(c::CB.thickness_ok_for?('side_left', 18.0, 16.0), 'bok stale vyzaduje presnu zhodu')
end

NxTest.test('KOV-C2a (R1): `ensure_drawer_uni!` je idempotentna a nekoliduje s ID') do
  NxTest.skip!('katalogove testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  c = NxC2a
  mat = c::MAT
  NxTest.install_fresh_seed_catalog!
  FileUtils.rm_f(mat.drawer_uni_marker_path)
  # Fresh seed uz zaznam ma -> migracia nic nepridava, len zapise marker.
  NxTest.assert_equal(:noop, mat.ensure_drawer_uni!, 'seed ho uz ma — nepridava sa druhy')
  NxTest.assert(File.exist?(mat.drawer_uni_marker_path))
  NxTest.assert_equal(:done, mat.ensure_drawer_uni!, 'marker = druhy beh no-op')
  NxTest.assert_equal(1, mat.load['sheets'].count { |s| s['material_id'] == 'UNI_ZASUVKA_16' },
                      '2x beh = 1 zaznam')

  # Existujuci katalog BEZ zaznamu (a s uz zapisanym `uni_seed.done`) — presne
  # stav kazdej dnesnej instalacie.
  data = mat.load
  data['sheets'] = data['sheets'].reject { |s| s['material_id'] == 'UNI_ZASUVKA_16' }
  NxTest.assert(mat.write(data))
  FileUtils.rm_f(mat.drawer_uni_marker_path)
  NxTest.assert_equal(:added, mat.ensure_drawer_uni!, 'existujuci katalog zaznam DOSTANE')
  zas = mat.sheet('UNI_ZASUVKA_16')
  NxTest.assert_equal(['drawer', true], [zas['uni_role'], mat.uni?(zas)])
  NxTest.assert_close(16.0, zas['thickness'], 0.01)

  # ROVNAKY DEKOR, INY VYROBCA = INA SKUPINA (standard 7.1), teda ZIADNA kolizia.
  # Keby sa merala len zhoda dekoru, „Egger + Zásuvka UNI" by blokoval migraciu
  # pri KAZDOM starte a fallback ID by nevzniklo NIKDY (Codex #303 kolo 2 P2).
  data = mat.load
  data['sheets'] = data['sheets'].reject { |s| s['material_id'] == 'UNI_ZASUVKA_16' }
  data['sheets'] << mat.normalize_sheet('material_id' => 'EGGER_ZAS_16',
                                        'manufacturer' => 'Egger', 'decor' => 'Zásuvka UNI',
                                        'type' => 'DTDL', 'thickness' => 16.0,
                                        'group_id' => mat.group_id_for('Egger', 'Zásuvka UNI'))
  NxTest.assert(mat.write(data))
  FileUtils.rm_f(mat.drawer_uni_marker_path)
  NxTest.assert_equal(:added, mat.ensure_drawer_uni!, 'iny vyrobca NIE JE kolizia')
  NxTest.assert(mat.sheet('UNI_ZASUVKA_16'), 'fallback ID vzniklo')
  NxTest.assert_equal('Egger', mat.sheet('EGGER_ZAS_16')['manufacturer'], 'cudzi zaznam NEDOTKNUTY')

  # Kolizia CELEJ identity skupiny (rovnaky vyrobca AJ dekor) pod INYM ID =
  # FAIL-CLOSED: nas zaznam by nevznikol a `PROJECT_FALLBACK` by ukazoval na
  # neexistujuce ID. Marker sa preto NEZAPISE a dalsi start to skusi znova.
  data = mat.load
  data['sheets'] = data['sheets'].reject { |s| s['material_id'] == 'UNI_ZASUVKA_16' }
  data['sheets'] << mat.normalize_sheet('material_id' => 'CUDZI_16', 'manufacturer' => '',
                                        'decor' => 'Zásuvka UNI', 'type' => 'DTDL',
                                        'thickness' => 16.0,
                                        'group_id' => mat.group_id_for('', 'Zásuvka UNI'))
  NxTest.assert(mat.write(data))
  FileUtils.rm_f(mat.drawer_uni_marker_path)
  NxTest.assert_equal(:conflict, mat.ensure_drawer_uni!, 'ta ista skupina = fail-closed')
  NxTest.refute(File.exist?(mat.drawer_uni_marker_path), 'marker sa NEZAPISAL')
  NxTest.assert_equal(nil, mat.sheet('UNI_ZASUVKA_16'), 'a ziadny zaznam nepribudol')
  # Po premenovani cudzieho zaznamu sa druhy beh doplni sam.
  data = mat.load
  data['sheets'] = data['sheets'].map do |s|
    next s unless s['material_id'] == 'CUDZI_16'

    s.merge('decor' => 'Moja zásuvka', 'group_id' => mat.group_id_for('', 'Moja zásuvka'))
  end
  NxTest.assert(mat.write(data))
  NxTest.assert_equal(:added, mat.ensure_drawer_uni!, 'po premenovani sa doplni')
  NxTest.assert(mat.sheet('UNI_ZASUVKA_16'))

  # Kolizia ID: pouzivatel si ID obsadil vlastnym REALNYM materialom —
  # zaznam sa NEPREPISE (a fallback na neho ukazuje, takze marker je v poriadku).
  data = mat.load
  data['sheets'] = data['sheets'].map do |s|
    next s unless s['material_id'] == 'UNI_ZASUVKA_16'

    mat.normalize_sheet('material_id' => 'UNI_ZASUVKA_16', 'manufacturer' => 'Egger',
                        'decor' => 'W980', 'type' => 'DTDL', 'thickness' => 16.0,
                        'group_id' => mat.group_id_for('Egger', 'W980'), 'code' => '999')
  end
  NxTest.assert(mat.write(data))
  FileUtils.rm_f(mat.drawer_uni_marker_path)
  NxTest.assert_equal(:noop, mat.ensure_drawer_uni!, 'obsadene ID = nepridava sa nic')
  NxTest.assert_equal('999', mat.sheet('UNI_ZASUVKA_16')['code'], 'cudzi zaznam NEDOTKNUTY')
ensure
  FileUtils.rm_f(NxC2a::MAT.drawer_uni_marker_path)
  NxTest.install_fresh_seed_catalog!
end

# ============================================================================
# R2 — ABS SEED PER ROLA
# ============================================================================

NxTest.test('KOV-C2a (R2): ABS seed dielcov zasuviek — dno bez olepu, ostatne L1 1,0') do
  c = NxC2a
  NxTest.assert(c::ABS::SEED_VERSION >= 4, 'bump seed verzie (inak sa roly nedoplnia)')
  NxTest.assert_equal({}, c::ABS::SEED_RULES['drawer_bottom'],
                      'dno sada na prirubu zargy — ziadna hrana')
  %w[drawer_back box_side drawer_inner_front].each do |role|
    NxTest.assert_equal({ 'L1' => 1.0 }, c::ABS::SEED_RULES[role],
                        "#{role}: horna dlha hrana 1,0 mm")
  end
end

NxTest.test('KOV-C2a (R2): 2D karta kresli L1 dielcov zasuvky na HORNU stranu') do
  c = NxC2a
  # Pravidlo aj `EDGE_LABELS` hovoria „horna dlha hrana" — keby `edge_sides`
  # vratilo lezacu mapu (L1 = bottom), karta by pasku nakreslila NA OPACNU
  # stranu, nez sa reze. Dno LEZI, takze mu lezaca mapa ostava.
  %w[drawer_back box_side drawer_inner_front].each do |role|
    NxTest.assert_equal(c::ABS::EDGE_SIDES_STANDING, c::ABS.edge_sides(role), role)
    NxTest.assert_equal('top', c::ABS.edge_sides(role)['L1'], "#{role}: L1 je HORNA strana")
    NxTest.assert_equal('Horná', c::ABS.edge_labels(role)['L1'], "#{role}: aj label")
  end
  NxTest.assert_equal(c::ABS::EDGE_SIDES_LYING, c::ABS.edge_sides('drawer_bottom'),
                      'dno LEZI — lezaca mapa ostava')
  # Ostatne roly sa NEZMENILI.
  NxTest.assert_equal(c::ABS::EDGE_SIDES_LYING, c::ABS.edge_sides('shelf'))
  NxTest.assert_equal(c::ABS::EDGE_SIDES_FRONT, c::ABS.edge_sides('front_door'))
end

NxTest.test('KOV-C2a (R2): merge seedu do EXISTUJUCEHO suboru neprepise pouzivatelske pravidlo') do
  c = NxC2a
  # Subor „ako ho ma dnesny pouzivatel" (v3): bez roli zasuviek, s RUCNE
  # zmenenymi dvierkami.
  v3 = c::ABS.deep_copy(c::ABS::SEED_RULES)
  %w[drawer_bottom drawer_back box_side drawer_inner_front].each { |r| v3.delete(r) }
  v3['front_door'] = { 'L1' => 2.0 }
  out, stale = c::ABS.merge_seed_roles(v3, 3, v3)
  NxTest.assert(stale, 'merge si vynuti zapis')
  NxTest.assert_equal({ 'L1' => 2.0 }, out['front_door'], 'RUCNA hodnota ostava NEDOTKNUTA')
  NxTest.assert_equal({ 'L1' => 1.0 }, out['drawer_back'], 'chybajuca rola pribudla')
  NxTest.assert_equal({}, out['drawer_bottom'])
  # Rola, ktoru si pouzivatel VEDOME vyprazdnil, sa NEDOPLNA.
  v4 = c::ABS.deep_copy(c::ABS::SEED_RULES)
  v4['drawer_back'] = {}
  same, stale4 = c::ABS.merge_seed_roles(v4, c::ABS::SEED_VERSION, v4)
  NxTest.refute(stale4, 'subor na aktualnej verzii sa uz nemerguje')
  NxTest.assert_equal({}, same['drawer_back'])
end

# ============================================================================
# R3 — KLASIFIKACNE POLE `height_variant`
# ============================================================================

NxTest.test('KOV-C2a (R3): `height_variant` je volitelne a LEN pri zasuvke') do
  c = NxC2a
  base = c.seed_set('atira-biela-h70-sisy')
  norm, errs = c::HWS.validate_set(base)
  NxTest.assert_equal([], errs, errs.inspect)
  NxTest.assert_equal(70, norm['height_variant'], 'hodnota je CELE cislo')

  # Set na dvierka s vyskou = ODMIETNUTY zapis.
  door = { 'set_id' => 'x', 'name' => 'X', 'generic_type' => 'hinge',
           'use_type' => 'door', 'opening_mode' => 'classic',
           'manufacturer' => 'Hettich', 'series' => 'Sensys', 'height_variant' => 70,
           'members' => [{ 'code' => 'K1', 'per' => 'unit', 'qty' => 1 }] }
  bad, derrs = c::HWS.validate_set(door)
  NxTest.assert_equal(nil, bad, 'dvierka s vyskou variantu sa neulozia')
  NxTest.assert(derrs.first.to_s.include?('zásuvky'), derrs.inspect)

  # Neznama vyska = obsah novsej verzie -> odmietnutie, nie „nova kategoria".
  bad2, e2 = c::HWS.validate_set(base.merge('height_variant' => 84))
  NxTest.assert_equal(nil, bad2, '84 nie je v uzavretom slovniku')
  NxTest.assert(e2.first.to_s.include?('výšku'), e2.inspect)
  # Quadro V6 vyskove varianty NEMA — a je to v poriadku.
  q, qerrs = c::HWS.validate_set(c.seed_set('vysuv-quadro-v6-sisy'))
  NxTest.assert_equal([], qerrs, qerrs.inspect)
  NxTest.refute(q.key?('height_variant'), 'chybajuce pole je LEGITIMNE')
end

NxTest.test('KOV-C2a (R3): `height_variant` prezije VSETKY zapisove cesty') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxC2a
  src = c.seed_set('atira-biela-h176-sisy')
  c.with_library do
    # (1) GLOBALNY zapis setu
    c.install('std' => c::HWS::STD, 'seed_version' => c::HWS::SEED_VERSION,
              'sets' => [src], 'mapping' => {})
    status, sinfo = c::HWS.save_set!(src)
    NxTest.assert_equal(:ok, status,
                        "#{sinfo.inspect} lib=#{c::HWS.library_state.inspect} " \
                        "tax=#{c::TAX.state.inspect}")
    NxTest.assert_equal(176, c::HWS.load['sets'].first['height_variant'], 'globalny zapis')

    # (2) EDITOR setu — modal posiela klasifikaciu BEZ `height_variant`
    # (pole nepozna). Merge ho musi prevziat z ULOZENEHO setu.
    from_editor = {
      'set_id' => src['set_id'], 'name' => src['name'], 'use_type' => 'drawer',
      'opening_mode' => 'classic', 'drawer_construction' => 'metal',
      'manufacturer' => 'Hettich', 'series' => 'InnoTech Atira', 'active' => true,
      'members' => [{ 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
                      'code_by_nl' => { '470' => '357775' } }]
    }
    st2, info = c::HWS.save_set!(from_editor)
    NxTest.assert_equal(:ok, st2, info.inspect)
    NxTest.assert_equal(176, c::HWS.load['sets'].first['height_variant'],
                        'uprava clena zo 4-klucoveho editora vysku NESMIE zhodit')

    # (3) PROJEKTOVY SNAPSHOT
    m = c.model_with
    NxTest.assert(c::HWS.set_project_mapping!(m, 'slide', src['set_id'], src))
    ok, state = c::HWS.project_state_status(m)
    NxTest.assert_equal(:ok, ok, 'snapshot sa cita BEZSTRATOVO')
    NxTest.assert_equal(176, state['sets'][src['set_id']]['height_variant'])

    # (4) SABLONA korpusu (brana definicii)
    tstatus, defs = c::HWS.assess_set_defs([c::HWS.normalize_sets([src]).first])
    NxTest.assert_equal(:ok, tstatus)
    NxTest.assert_equal(176, defs[src['set_id']]['height_variant'])
  end
end

NxTest.test('KOV-C2a (R3): editor pri prepnuti zo zasuvky na dvierka vysku NEDEDI') do
  c = NxC2a
  stored = c::HWS.normalize_sets([c.seed_set('atira-biela-h70-sisy')]).first
  # Modal posiela klasifikaciu VZDY CELU — `height_variant` medzi jeho poliami
  # nie je, takze ho musi odstranit SERVER (inak by set uz nikdy neprešiel).
  raw = { 'set_id' => stored['set_id'], 'name' => stored['name'],
          'use_type' => 'door', 'opening_mode' => 'classic',
          'drawer_construction' => '', 'manufacturer' => 'Hettich',
          'series' => 'Sensys', 'members' => stored['members'] }
  merged = c::HWS.send(:merge_class_keys, raw, stored)
  NxTest.refute(merged.key?('height_variant'), 'vyska sa na dvierka nededi')
  # A pri zasuvke sa nadalej dedi.
  keep = c::HWS.send(:merge_class_keys, raw.merge('use_type' => 'drawer',
                                                  'drawer_construction' => 'metal',
                                                  'series' => 'InnoTech Atira'), stored)
  NxTest.assert_equal(70, keep['height_variant'])
end

NxTest.test('KOV-C2a (R3): lazy std 4 — LEN obsah s vyskou; strata sa PRIZNA') do
  c = NxC2a
  hv = c::HWS.normalize_sets([c.seed_set('atira-biela-h70-sisy')]).first
  quadro = c::HWS.normalize_sets([c.seed_set('vysuv-quadro-v6-sisy')]).first
  legacy = c::HWS.normalize_sets([c.seed_set('vysuv-atira-biela-h70')]).first

  NxTest.assert_equal(c::HWS::STD_HEIGHT_VARIANT, c::HWS.snapshot_std({}, [hv]),
                      'set s vyskou = std 4')
  NxTest.assert_equal(c::HWS::STD_CLASSIFIED, c::HWS.snapshot_std({}, [quadro]),
                      'klasifikovany set BEZ vysky ostava na 3')
  NxTest.assert_equal(c::HWS::STD_CLASSIFIED,
                      c::HWS.snapshot_std({ 'class:slide|classic|wood' => 'x' }, [legacy]),
                      'triedny kluc sam o sebe je stale 3')
  NxTest.assert_equal(c::HWS::STD, c::HWS.snapshot_std({}, [legacy]), 'cisty legacy = 1')
  NxTest.assert(c::HWS::STD_SUPPORTED.include?(c::HWS::STD_HEIGHT_VARIANT),
                'vlastny zapis si musime vediet precitat')

  # 4. vrstva detektora: zvysok klasifikacie prezije, vyska zmizne = STRATA.
  lost = hv.reject { |k, _| k == 'height_variant' }
  NxTest.assert(c::HWS.classification_lost?([hv], [lost]),
                'strata vysky sa MUSI priznat (inak by snapshot vyzeral zdravo)')
  NxTest.refute(c::HWS.classification_lost?([hv], [hv]), 'bezstratove citanie nic nehlasi')
end

NxTest.test('KOV-C2a (R3): std 4 je pre STARSI plugin `:invalid` snapshot') do
  c = NxC2a
  hv = c::HWS.normalize_sets([c.seed_set('atira-biela-h70-sisy')]).first
  snap = { 'std' => c::HWS::STD_HEIGHT_VARIANT, 'mapping' => {},
           'sets' => { hv['set_id'] => hv } }
  NxTest.assert_equal(:ok, c::HWS.project_state_status(c.model_with(snap))[0],
                      'tato verzia ho cita')
  orig = c::HWS::STD_SUPPORTED
  begin
    c::HWS.send(:remove_const, :STD_SUPPORTED)
    c::HWS.const_set(:STD_SUPPORTED, [1, 2, 3].freeze)
    NxTest.assert_equal(:invalid, c::HWS.project_state_status(c.model_with(snap))[0],
                        'starsi plugin ho odmietne CELY (NIKDY ciastocne citanie)')
  ensure
    c::HWS.send(:remove_const, :STD_SUPPORTED)
    c::HWS.const_set(:STD_SUPPORTED, orig)
  end
end

# ============================================================================
# R4 — SEED SETOV, MAPPING_ADDITIONS A MIGRACIE
# ============================================================================

NxTest.test('KOV-C2a (R4): cerstva kniznica ma 8 novych setov a 4 triedne mapovania') do
  c = NxC2a
  lib = c::HWS.seed_library
  ids = %w[atira-biela-h70-sisy atira-biela-h144-sisy atira-biela-h176-sisy
           atira-biela-h70-p2o atira-biela-h144-p2o atira-biela-h176-p2o
           vysuv-quadro-v6-sisy vysuv-quadro-v6-p2o]
  have = lib['sets'].map { |s| s['set_id'] }
  ids.each { |sid| NxTest.assert(have.include?(sid), "seed set #{sid} chyba") }
  NxTest.assert(have.include?('vysuv-atira-biela-h70'),
                'LEGACY set ostava NEDOTKNUTY (drzi legacy mapovanie `slide`)')
  NxTest.assert_equal('vysuv-atira-biela-h70', lib['mapping']['slide'],
                      'legacy mapovanie `slide` sa nemeni')
  c::HWS::MAPPING_ADDITIONS.each_key do |key|
    NxTest.assert(lib['mapping'].key?(key), "cerstva kniznica musi mat #{key}")
  end
  NxTest.assert_equal(4, c::HWS::MAPPING_ADDITIONS.size)
  # Vsetky seed sety su platne aj podla PRISNEJ zapisovej validacie.
  _norm, errs = c::HWS.validate_sets(c::HWS::SEED_SETS)
  NxTest.assert_equal([], errs, errs.inspect)
end

NxTest.test('KOV-C2a (R4): SEEDNUTY SUBOR nesie triedne mapovania (nielen `seed_library`)') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxC2a
  c.with_library do
    # Fresh install = kniznica NEEXISTUJE. `ensure_seeded` ju zapise pri prvom
    # `load`, a musi to urobit cez `seed_library` — inak by cerstva instalacia
    # zasuvky NEMAPOVALA, kym upgrade (cez `merge_seed`) ano. Test cita SUBOR
    # NA DISKU, nie accessor: prave ten rozdiel bol chybou, ktoru odhalil
    # in-SketchUp beh (`ensure_seeded` seedovala zo samotnej `SEED_MAPPING`).
    FileUtils.rm_f(c::HWS.path)
    FileUtils.rm_f("#{c::HWS.path}.bak")
    c::STORE.invalidate(c::HWS.path)
    c::HWS.reset_library_state!

    c::HWS.load
    doc = c.raw_lib
    c::HWS::MAPPING_ADDITIONS.each_key do |key|
      NxTest.assert(doc['mapping'].key?(key), "seednuty subor musi mat #{key}")
    end
    NxTest.assert_equal('vysuv-atira-biela-h70', doc['mapping']['slide'],
                        'legacy mapovanie `slide` ostava')
    NxTest.assert_equal(c::HWS::STD_HEIGHT_VARIANT, doc['std'],
                        'seed nesie drawer sety s `height_variant` -> std 4')
    NxTest.assert_equal(:ok, c::HWS.library_state, 'a TA ISTA verzia si ho precita')

    # Predvolby NOVEHO projektu (`global_default_state`) z toho zmrazia aj
    # triedne mapovania a sety, na ktore ukazuju — inak by nova zakazka mala
    # zasuvky nemapovane az do prveho „Doplniť nové predvoľby".
    gd = c::HWS.global_default_state
    NxTest.assert(gd['mapping'].key?('class:slide|classic|metal'))
    NxTest.assert(gd['sets'].key?('atira-biela-h70-sisy'))
    NxTest.assert_equal(c::HWS::STD_HEIGHT_VARIANT,
                        c::HWS.snapshot_std(gd['mapping'], gd['sets'].values),
                        'snapshot noveho projektu preto tiez nesie std 4')
  end
end

NxTest.test('KOV-C2a (R4): `MAPPING_ADDITIONS` NEPREPISE pouzivatelsky kluc') do
  c = NxC2a
  sets = c::HWS.normalize_sets(c::HWS::SEED_SETS)
  mine = { 'class:slide|classic|metal' => 'vysuv-atira-biela-h70' }
  out = c::HWS.send(:add_mapping_seed, sets, mine)
  NxTest.assert_equal('vysuv-atira-biela-h70', out['class:slide|classic|metal'],
                      'pouzivatelske mapovanie ma ABSOLUTNU prednost')
  NxTest.assert(out['class:slide|tipon|metal'].is_a?(Hash), 'ostatne chybajuce pribudli')
  # Ciastocny selektor sa NEDOPLNA (chybajuci referencovany set).
  bez = sets.reject { |s| s['set_id'] == 'atira-biela-h144-sisy' }
  out2 = c::HWS.send(:add_mapping_seed, bez, {})
  NxTest.refute(out2.key?('class:slide|classic|metal'),
                'chybajuci set v pasme = kluc sa NEDOPLNI vobec')
  NxTest.assert(out2.key?('class:slide|classic|wood'), 'nezavisly kluc pribudne')
end

NxTest.test('KOV-C2a (R4): stary globál + stary snapshot -> po oboch mergoch je zasuvka namapovana') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxC2a
  legacy_set = c.seed_set('vysuv-atira-biela-h70')
  c.with_library do
    # (1) GLOBAL zo starej verzie: seed_version 2, vlastne mapovanie `slide`.
    c.install('std' => c::HWS::STD, 'seed_version' => 2,
              'sets' => [legacy_set], 'mapping' => { 'slide' => 'vysuv-atira-biela-h70' })
    lib = c::HWS.load
    NxTest.assert_equal('vysuv-atira-biela-h70', lib['mapping']['slide'],
                        'pouzivatelske mapovanie `slide` OSTALO')
    NxTest.assert(lib['mapping']['class:slide|classic|metal'].is_a?(Hash),
                  'triedny kluc PRIBUDOL (bez neho by „Doplniť nové predvoľby" neopravilo nic)')
    stored_legacy = lib['sets'].find { |s| s['set_id'] == 'vysuv-atira-biela-h70' }
    NxTest.assert_equal(c::HWS.normalize_sets([legacy_set]).first, stored_legacy,
                        'legacy set je BAJT NA BAJT ten isty (kompatibilita by inak padla)')

    # (2) STARY SNAPSHOT projektu — bez triednych klucov.
    snap = c.snapshot_of([legacy_set], { 'slide' => 'vysuv-atira-biela-h70' })
    m = c.model_with(snap)
    status, added_sets, added_map = c::HWS.merge_project_sets_seed!(m)
    NxTest.assert_equal(:updated, status)
    NxTest.assert(added_map.include?('class:slide|classic|metal'), added_map.inspect)
    NxTest.assert(added_sets.include?('atira-biela-h70-sisy'), added_sets.inspect)
    _ok, state = c::HWS.project_state_status(m)
    NxTest.assert_equal('vysuv-atira-biela-h70', state['mapping']['slide'],
                        'existujuce mapovanie snapshotu sa NEPREPISUJE')
    # A zasuvka sa uz namapuje.
    sid, reason, = c::HWS.resolve_set_id('slide', c.drawer_item, {}, state['mapping'])
    NxTest.assert_equal(['atira-biela-h70-sisy', nil], [sid, reason])
  end
end

NxTest.test('KOV-C2a (R4): completeness — KAZDA bunka radov v1 ma kit kod') do
  c = NxC2a
  seed = c::HWS.normalize_sets(c::HWS::SEED_SETS)
  by_id = {}
  seed.each { |s| by_id[s['set_id']] = s }
  mapping = c::HWS::MAPPING_ADDITIONS
  opening_mode = { 'sisy' => 'classic', 'p2o' => 'tipon' }
  construction = { 'atira' => 'metal', 'quadro_v6' => 'wood' }
  checked = 0

  c::REC.released.each_key do |rid|
    recipe = c::REC.load(rid)
    om = opening_mode.fetch(recipe[:opening])
    dc = construction.fetch(recipe[:system])
    key = "class:slide|#{om}|#{dc}"
    value = mapping[key]
    NxTest.assert(value, "recept #{rid}: chyba triedne mapovanie #{key}")

    cells =
      if recipe[:nl_series_by_height]
        recipe[:nl_series_by_height].map { |h, list| [h.to_i, list] }
      else
        [[nil, recipe[:nl_series]]]
      end

    cells.each do |height, list|
      p = { 'opening_mode' => om, 'drawer_construction' => dc,
            'system' => recipe[:system], 'nominal_length' => list.first.to_f }
      p['height_variant'] = height.to_f if height
      it = c.drawer_item('raw_params' => p)
      sid, reason, info = c::HWS.resolve_set_id('slide', it, {}, mapping)
      NxTest.assert_equal(nil, reason, "#{rid} H#{height}: #{reason} #{info.inspect}")
      set = by_id[sid]
      NxTest.assert(set, "#{rid} H#{height}: set #{sid} nie je v seede")
      if height
        NxTest.assert_equal(height, set['height_variant'],
                            "#{rid}: set #{sid} musi mat vysku #{height}")
      end
      member = set['members'].first
      list.each do |nl|
        code = member['code_by_nl'][nl.to_i.to_s]
        NxTest.assert(code && !code.to_s.strip.empty?,
                      "#{rid} H#{height} NL #{nl}: set #{sid} nema kit kod")
        checked += 1
      end
    end
  end
  NxTest.assert(checked >= 26, "completeness overila len #{checked} buniek")
end

# ============================================================================
# R5 — TRIEDNY KLUC V RESOLVERI A KOMPATIBILITA
# ============================================================================

NxTest.test('KOV-C2a (R5): triedny kluc vybera set podla vysky a NL') do
  c = NxC2a
  state = c.seed_state
  cat = [{ 'item_code' => '357696', 'name_sk' => 'K-sada Atira H70/470', 'category' => 'VYSUVY',
           'unit' => 'ks', 'price_eur_vat' => 30.0 },
         { 'item_code' => '357775', 'name_sk' => 'K-sada Atira H176/470', 'category' => 'VYSUVY',
           'unit' => 'ks', 'price_eur_vat' => 44.0 },
         { 'item_code' => '317642', 'name_sk' => 'K-set Quadro V6 450', 'category' => 'VYSUVY',
           'unit' => 'ks', 'price_eur_vat' => 22.0 }]

  h70 = c::HWS.expand([c.drawer_item], state, catalog: cat)
  NxTest.assert_equal(['357696'], h70['rows'].map { |r| r['code'] }, h70['unmapped'].inspect)

  h176 = c::HWS.expand([c.drawer_item('params' => { 'height_variant' => 176.0 })], state, catalog: cat)
  NxTest.assert_equal(['357775'], h176['rows'].map { |r| r['code'] },
                      'ta ista NL, INA vyska = INY kit')

  wood = c.drawer_item('rule_id' => 'recipe:quadro_v6_sisy_v1',
                       'raw_params' => { 'opening_mode' => 'classic',
                                         'drawer_construction' => 'wood',
                                         'system' => 'quadro_v6', 'nominal_length' => 450.0 })
  q = c::HWS.expand([wood], state, catalog: cat)
  NxTest.assert_equal(['317642'], q['rows'].map { |r| r['code'] },
                      'dreveny box ide na Quadro (pevny set_id, ziadna vyska)')
end

NxTest.test('KOV-C2a (R5): chybajuce triedne mapovanie = `class_unmapped`, NIKDY fallback na `slide`') do
  c = NxC2a
  # Projekt MA legacy mapovanie `slide` — a prave nan sa nesmie spadnut.
  state = c.state_of([c.seed_set('vysuv-atira-biela-h70')],
                     { 'slide' => 'vysuv-atira-biela-h70' })
  exp = c::HWS.expand([c.drawer_item], state)
  NxTest.assert_equal([], exp['rows'], 'ziadny riadok — H70 kit „len tak" sa neobjedna')
  u = exp['unmapped'].first
  NxTest.assert_equal('class_unmapped', u['reason'])
  NxTest.assert_equal('class:slide|classic|metal', u['class_key'])
  NxTest.assert(c::HWS.unmapped_reason_sk(u).include?('Doplniť nové predvoľby'),
                'hlaska navaguje na EXISTUJUCU akciu')
  # Legacy polozka toho isteho typu sa MAPUJE ako doteraz.
  legacy = c::HWS.expand([c.legacy_item], state)
  NxTest.assert_equal(['357696'], legacy['rows'].map { |r| r['code'] },
                      'legacy vysuv ide dalej cez genericky `slide`')
end

NxTest.test('KOV-C2a (R5): cabinet override triedneho kluca ma prednost, owner-level sa IGNORUJE') do
  c = NxC2a
  state = c.seed_state
  # Override skrinky = vyskovy selektor na Tip-On sety.
  ov = { 'CAB-1' => { 'class:slide|classic|metal' => c::HWS::MAPPING_ADDITIONS['class:slide|tipon|metal'] } }
  sid, reason, = c::HWS.resolve_set_id('slide', c.drawer_item, ov, state['mapping'])
  NxTest.assert_equal(['atira-biela-h70-p2o', nil], [sid, reason], 'override skrinky vyhrava')

  # Owner-level `slide@…` je pre receptovu polozku NEVIDITELNY.
  ov2 = { 'CAB-1' => { 'slide@front:F1/panel' => 'vysuv-atira-biela-h70',
                       'slide' => 'vysuv-atira-biela-h70' } }
  sid2, = c::HWS.resolve_set_id('slide', c.drawer_item, ov2, state['mapping'])
  NxTest.assert_equal('atira-biela-h70-sisy', sid2,
                      'owner-level ani genericky override receptovu polozku neprebije')
end

NxTest.test('KOV-C2a (R5): pevny `set_id` pre Atiru = nekompatibilne, Quadro ho smie') do
  c = NxC2a
  state = c.seed_state
  ov = { 'CAB-1' => { 'class:slide|classic|metal' => 'atira-biela-h70-sisy' } }
  sid, reason, info = c::HWS.resolve_set_id('slide', c.drawer_item, ov, state['mapping'])
  NxTest.assert_equal([nil, 'set_incompatible'], [sid, reason],
                      'pevny set_id by po prerasteni H70 -> H176 objednal ZLY kit')
  NxTest.assert_equal('height_selector', info['detail'])
  # Quadro (bez vysky) pevny set_id smie — to je seed hodnota.
  wood = c.drawer_item('raw_params' => { 'opening_mode' => 'classic',
                                         'drawer_construction' => 'wood',
                                         'system' => 'quadro_v6', 'nominal_length' => 450.0 })
  sid2, reason2, = c::HWS.resolve_set_id('slide', wood, {}, state['mapping'])
  NxTest.assert_equal(['vysuv-quadro-v6-sisy', nil], [sid2, reason2])
end

NxTest.test('KOV-C2a (R5): nesedici set = nemapovane s dovodom, NIKDY iny set') do
  c = NxC2a
  sets = c::HWS::SEED_SETS
  cases = {
    # zla vyska: mapovanie ukazuje na H70 set, polozka je H176
    'height_variant' => [c.drawer_item('params' => { 'height_variant' => 176.0 }),
                         { 'class:slide|classic|metal' => { 'param' => 'height_variant',
                                                            'bands' => [{ 'min' => 176.0, 'max' => 176.0,
                                                                          'set_id' => 'atira-biela-h70-sisy' }] } }],
    # iny system pri rovnakej klasifikacii (Antaro/StrongBox scenar)
    'system' => [c.drawer_item('params' => { 'system' => 'quadro_v6' }),
                 { 'class:slide|classic|metal' => { 'param' => 'height_variant',
                                                    'bands' => [{ 'min' => 70.0, 'max' => 70.0,
                                                                  'set_id' => 'atira-biela-h70-sisy' }] } }],
    # ine otvaranie (mapovanie ukazuje na Tip-On set)
    'opening_mode' => [c.drawer_item,
                       { 'class:slide|classic|metal' => { 'param' => 'height_variant',
                                                          'bands' => [{ 'min' => 70.0, 'max' => 70.0,
                                                                        'set_id' => 'atira-biela-h70-p2o' }] } }]
  }
  cases.each do |detail, (item, mapping)|
    state = c.state_of(sets, mapping)
    exp = c::HWS.expand([item], state)
    NxTest.assert_equal([], exp['rows'], "#{detail}: ziadny riadok")
    u = exp['unmapped'].first
    NxTest.assert_equal(['set_incompatible', detail], [u['reason'], u['detail']], u.inspect)
    # Panel (`explain`) hovori TO ISTE, co supis.
    ex = c::HWS.explain(item, state)
    NxTest.assert_equal([], ex['members'], "#{detail}: panel nesmie rozpisat kody")
    NxTest.assert(ex['problems'].first.to_s.include?('nesedí'), ex.inspect)
  end
end

NxTest.test('KOV-C2a (R5): triedny kluc si ziada KLASIFIKOVANY set (legacy set neprejde)') do
  c = NxC2a
  state = c.state_of([c.seed_set('vysuv-atira-biela-h70')],
                     { 'class:slide|classic|metal' => 'vysuv-atira-biela-h70' })
  exp = c::HWS.expand([c.drawer_item], state)
  NxTest.assert_equal([], exp['rows'])
  NxTest.assert_equal('set_incompatible', exp['unmapped'].first['reason'],
                      'nezaradeny set nedokaze, ze patri k tejto zasuvke')
end

# ============================================================================
# R6 — CHARAKTERIZACIA: EXISTUJUCE ZAKAZKY SU CONTENT-IDENTICKE
# ============================================================================

NxTest.test('KOV-C2a (R6): polozky BEZ klasifikacie sa spravaju presne ako doteraz') do
  c = NxC2a
  state = c.seed_state
  cat = [{ 'item_code' => '357696', 'name_sk' => 'K-sada', 'category' => 'VYSUVY',
           'unit' => 'ks', 'price_eur_vat' => 30.0 },
         { 'item_code' => '104717', 'name_sk' => 'Záves', 'category' => 'ZAVESY',
           'unit' => 'ks', 'price_eur_vat' => 4.18 }]
  items = [c.legacy_item,
           { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/wing:single',
             'generic_type' => 'hinge', 'quantity' => 2, 'rule_id' => 'zavesy',
             'params' => {}, 'source' => 'rule' }]
  exp = c::HWS.expand(items, state, catalog: cat)
  # Zaves ma v seed sete 4 cleny (zaves + platnicka + 2 krytky) — riadok vznikne
  # aj bez zaznamu v katalogu (`missing`), presne ako doteraz.
  NxTest.assert_equal(%w[104717 105408 105425 106412 357696],
                      exp['rows'].map { |r| r['code'] }.sort)
  NxTest.assert_equal([], exp['unmapped'], exp['unmapped'].inspect)
  # Triedna vetva sa pre ne NIKDY nezapne.
  items.each do |it|
    NxTest.assert_equal(nil, c::HWS.class_key_for(it, it['generic_type']),
                        'polozka bez opening_mode/drawer_construction nema triedny kluc')
    NxTest.assert_equal(nil, c::HWS.send(:set_incompatible_info, it, state['sets'].values.first))
  end
  # A ziadne dnesne pravidlo tie params neemituje.
  rules = c::E::HardwareRules.normalize_rules(c::E::HardwareRules::SEED_RULES)
  json = JSON.generate(rules)
  NxTest.refute(json.include?('opening_mode'), 'ziadne seed pravidlo neemituje `opening_mode`')
  NxTest.refute(json.include?('drawer_construction'), 'ani `drawer_construction`')
end

# ============================================================================
# R7 — OCHRANA KOLIDUJUCICH KOPII
# ============================================================================

NxTest.test('KOV-C2a (R7): `override_keys_in_use` vracia aj triedne kluce') do
  c = NxC2a
  collected = { hardware: [c.drawer_item, c.legacy_item] }
  keys = c::PC.override_keys_in_use(collected)['CAB-1']
  NxTest.assert(keys['class:slide|classic|metal'],
                'kluc, ktory resolver CITA, musi ochrana poznat (inak by rozidena mapa presla)')
  NxTest.assert(keys['slide'], 'legacy polozka registruje legacy kluce')
  NxTest.assert(keys['slide@front:F1/panel'])

  # A NAOPAK: klasifikovana polozka registruje LEN triedny kluc. Generic `slide`
  # ani `slide@owner` pre nu resolver necita, takze rozdiel v nich jej kod
  # NEZMENI — zapisat ich by znamenalo zastavit export kvoli nicomu.
  only_class = c::PC.override_keys_in_use(hardware: [c.drawer_item])['CAB-1']
  NxTest.assert_equal(['class:slide|classic|metal'], only_class.keys,
                      'receptova polozka registruje VYHRADNE triedny kluc')
end
