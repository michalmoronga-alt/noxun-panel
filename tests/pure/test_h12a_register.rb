# frozen_string_literal: true
# H12a (blok 9 HARDENING, C-01) — REGISTER TYPOV SKRINKY `CabinetTypes`.
# Package H12 §6 R1/R2/R5/R6, testy T1–T3 (cast jadra; panel H12b, JS H12c).
#
# CO PLATI:
#   * jeden register `core/cabinet_types.rb` — typy a ich VLASTNOSTI; jadro sa
#     pyta vlastnosti (`hangs?`, `on_floor?`, `carcass?`, `corner?`, `prop`),
#     nie mena typu;
#   * neznamy typ = profil dolnej (`norm`), miesta IDENTITY drzia surovy
#     retazec (`id_or_default`, vstup pravidiel `cabinet_type`);
#   * `client_payload` je kontrakt pre JS = `tests/fixtures/h12_cabinet_types.json`;
#   * pasca CN-03 (visiace typy registra = typy seed pravidla zavesov) od H13
#     v `test_h13_rozsirovacie_body.rb`.
#
# Vysledky (cisla, plan, config, VEPO) strazi golden `test_h12_golden.rb`
# + in-SU `run_h12` — tu je kontrakt registra a guardy proti navratu
# vetvenia podla mena.
#
# MUTACIE (overene rucne pri davke, PR H12a): M1 `upper hang_z 0` · M2
# `dishwasher on_floor true` · M3 `corner_blind on_floor false` · M4 `FALLBACK
# 'upper'` · M5 `norm` neznamy ponecha · M7 `limits` slotu 200 · M8 `corner_blind
# zones tree` · M9 `dishwasher template_type switchable` · M10 `type_locked false`
# pri rohovej · M11 `appliance_owner cabinet` pri slote · M12 `fronts free` pri
# slote · M13 `corner_blind hang_z 1400` bez seedu · M14 poradie `EXTRA_KEYS`
# (package §7 T5; M6, M15, M16 su JS/H12d — mimo H12a). Navyse nad package:
# M17 `support_type` cez `hangs?` namiesto `on_floor?` · M18 `legacy_plinth`
# cez `on_floor?` namiesto `hangs?` · M19 nove `== 'upper'` v `bom.rb`.
# Spolu 16 mutacii, kazda zhodi aspon jeden test (golden alebo tento subor).
require_relative '../helper' unless defined?(NxTest)
require 'json'

module NxH12a
  module_function

  E  = Noxun::Engine
  CT = E::CabinetTypes
  CB = E::CabinetBuilder

  PAYLOAD_FIXTURE = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h12_cabinet_types.json')
  INPUTS = ['lower', 'upper', 'dishwasher', 'corner_blind', 'tall', nil, ''].freeze

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  # Mnozina vstupov, pre ktore predikat plati (matica R2.1).
  def set_of(&blk)
    INPUTS.select(&blk)
  end

  # T3a: vetvenie podla MENA typu v Ruby. Rozsah H12a = `core/` a `modules/`,
  # H12b pridala `ui/` (panel, sablony, Studio — len `.rb`; JS je H12c).
  # Register sam je vynimka.
  SCAN_DIRS = %w[core modules ui].freeze
  NAME = '(?:lower|upper|dishwasher|corner_blind)'
  REG_ID = '(?:CabinetTypes::(?:CORNER|FALLBACK)\b|CabinetTypes::IDS\s*\[)'
  # Formy vetvenia (predrecenzia H12a P3: aj symboly, `eql?`, pole s
  # `include?`, `when` s viacerymi hodnotami a mapa `{ 'upper' => … }[t]`).
  BRANCH_RES = [
    /(?:==|!=|===)\s*(?:['"]|:)#{NAME}\b/,
    /['"]#{NAME}['"]\s*(?:==|!=|===)/,
    /\bwhen\b[^\n]*(?:['"]|:)#{NAME}\b/,
    /%w\[[^\]]*\b#{NAME}\b[^\]]*\]/,
    /\[[^\]]*['"]#{NAME}['"][^\]]*\]\s*\.\s*include\?/,
    /include\?\(\s*(?:['"]|:)#{NAME}\b/,
    /\.eql\?\(\s*(?:['"]|:)#{NAME}\b/,
    /['"]#{NAME}['"]\s*=>/,
    /\|\|\s*['"]#{NAME}['"]/,
    /\bCORNER_TYPE\b/,
    # H12b (predrecenzia P3): porovnanie s ID-KONSTANTOU registra mimo registra
    # je to iste vetvenie podla mena (`== CabinetTypes::CORNER`). Predvolba
    # (`|| CabinetTypes::FALLBACK`) a clenstvo (`IDS.include?`) vetvenim nie su.
    /(?:==|!=|===)\s*#{REG_ID}/,
    /CabinetTypes::(?:CORNER|FALLBACK)\b\s*(?:==|!=|===)/,
    /CabinetTypes::IDS\s*\[[^\]]*\]\s*(?:==|!=|===)/,
    /\bwhen\b[^\n]*#{REG_ID}/,
    /(?:\.eql\?|include\?)\(\s*#{REG_ID}/
  ].freeze
  # Povolene riadky = [subor, podretazec riadka, DOVOD]. Novy riadok sem patri
  # LEN s dovodom — inak patri vlastnost do registra.
  ALLOW = [
    ['core/appliance_binding.rb', 'SLOT_EXPECTS = %w[dishwasher]', 'kategoria SPOTREBICA (umyvacka), nie typ skrinky'],
    ['core/appliance_binding.rb', "'dishwasher' => [KIND_SLOT]", 'OWNER_MATRIX: kategoria spotrebica -> vlastnik'],
    ['core/appliance_catalog.rb', 'CATEGORIES = %w[', 'kategorie spotrebicov katalogu'],
    ['core/appliance_catalog.rb', "'dishwasher' =>", 'popisky a polia KATEGORIE spotrebica'],
    ['core/cabinet_builder.rb', "'lower' => LOWER_DEFAULTS, 'upper' => UPPER_DEFAULTS", 'mapa DEFAULTS_BY_TYPE (paritny guard)'],
    ['core/cabinet_builder.rb', "'dishwasher' => DISHWASHER_DEFAULTS", 'mapa DEFAULTS_BY_TYPE (paritny guard)'],
    ['core/cabinet_builder.rb', "EXTRA_KEYS_BY_TYPE = { 'dishwasher' => DW_KEYS", 'mapa EXTRA_KEYS_BY_TYPE (paritny guard)'],
    ['core/construction.rb', "r['category'].to_s == 'dishwasher'", 'kategoria spotrebica vo vazbe slotu'],
    ['core/construction.rb', 'CORNER_TYPE = CabinetTypes::CORNER', 'alias registra'],
    ['core/cabinet_builder.rb', 'CORNER_TYPE = CabinetTypes::CORNER', 'alias registra'],
    ['core/cabinet_builder.rb', 'type: CORNER_TYPE, width: 1100.0', 'predvolby rohovej (DEFAULTS_BY_TYPE)'],
    ['core/cabinet_builder.rb', 'CORNER_TYPE => CORNER_DEFAULTS', 'mapa DEFAULTS_BY_TYPE (paritny guard)'],
    ['core/cabinet_builder.rb', 'CORNER_TYPE => CORNER_KEYS', 'mapa EXTRA_KEYS_BY_TYPE (paritny guard)'],
    ['core/hardware_rules.rb', "'cabinet_type' => %w[upper]", 'seed pravidla zavesov — strazi ho guard CN-03'],
    # H12b (ui/):
    ['ui/appliance_dialog.rb', "'dishwasher' => 'Nábytkové čelo (evidencia)'", 'popis KATEGORIE spotrebica v okne Spotrebice'],
    ['ui/appliance_dialog.rb', "'dishwasher' => {", 'polia formulara KATEGORIE spotrebica'],
    ['ui/appliance_dialog.rb', 'JOB_CHECKED = %w[fridge oven microwave dishwasher]', 'kategorie spotrebicov kontrolovane v zakazke'],
    ['ui/rules_dialog.rb', "TYPE_SCOPE_PHRASES = { 'upper' => 'na hornú skrinku'",
     'VETY rozsahu pravidla (akuzativ, terminologia F3) zrkadlo rules.js — nie vlastnost typu']
  ].freeze

  def code_part(line)
    s = line.strip
    return '' if s.start_with?('#')

    line.sub(/\s#\s.*\z/, '')
  end

  def branch?(line)
    code = code_part(line)
    BRANCH_RES.any? { |re| code.match?(re) }
  end

  def branch_hits
    root = File.join(NxTest::ROOT, 'noxun_engine')
    SCAN_DIRS.flat_map { |d| Dir[File.join(root, d, '**', '*.rb')] }.sort.flat_map do |path|
      rel = path.sub("#{root}/", '')
      next [] if rel == 'core/cabinet_types.rb'

      File.readlines(path, encoding: 'UTF-8').each_with_index.filter_map do |line, i|
        code = code_part(line)
        next nil unless BRANCH_RES.any? { |re| code.match?(re) }
        next nil if ALLOW.any? { |f, frag, _why| f == rel && code.include?(frag) }

        "#{rel}:#{i + 1}: #{line.strip}"
      end
    end
  end
end

# --- T1 · register -------------------------------------------------------------

NxTest.test('H12a T1: register — styri typy v dnesnom poradi, aliasy buildera a konstrukcie') do
  ct = NxH12a::CT
  NxTest.assert_equal(%w[lower upper dishwasher corner_blind], ct::IDS)
  NxTest.assert(ct::IDS.equal?(NxH12a::CB::TYPES), 'CabinetBuilder::TYPES je ALIAS registra, nie kopia')
  NxTest.assert_equal('corner_blind', NxH12a::CB::CORNER_TYPE)
  NxTest.assert_equal('corner_blind', Noxun::Engine::Construction::CORNER_TYPE)
  NxTest.assert_equal(1400.0, NxH12a::CB::UPPER_HANG_Z)
  NxTest.assert_equal([300.0, 1200.0], NxH12a::CB::DW_WIDTH_RANGE)
  NxTest.assert_equal([500.0, 1200.0], NxH12a::CB::DW_HEIGHT_RANGE)
  NxTest.assert(ct::REGISTRY.frozen? && ct::REGISTRY.values.all?(&:frozen?), 'register je zmrazeny')
end

NxTest.test('H12a T1: kazdy typ ma vsetky kluce, id = kluc, FALLBACK je znamy a NEUTRALNY') do
  ct = NxH12a::CT
  ct::REGISTRY.each do |id, props|
    NxTest.assert_equal(ct::KEYS, props.keys, "#{id}: kluce registra (aj poradie)")
    NxTest.assert_equal(id, props[:id])
    NxTest.assert(!props[:label].to_s.empty? && !props[:word].to_s.empty?, "#{id}: nazov a slovo")
    NxTest.assert_equal(props[:label].downcase, props[:word], "#{id}: slovo = nazov malym")
    # Typ bez korpusu MUSI mat vlastne limity (normalize ich cita).
    NxTest.assert(!props[:limits].nil?, "#{id}: slot bez limitov") if props[:builder] != 'carcass'
    NxTest.assert(!props[:template_lock].nil?, "#{id}: zamknuty typ sablony bez textu") if props[:template_type] == 'locked'
  end
  fb = ct.get(ct::FALLBACK)
  NxTest.assert(ct.known?(ct::FALLBACK))
  neutral = { hang_z: 0.0, on_floor: true, builder: 'carcass', fronts: 'free', front_opening: 'full',
              zones: 'tree', template_type: 'switchable', type_locked: false, assembly: nil,
              limits: nil, appliance_owner: 'cabinet', auto_name_typed: false }
  neutral.each { |k, v| NxTest.assert_equal(v, fb[k], "FALLBACK #{k} musi byt neutralny") }
  NxTest.assert_equal(%w[1 2 3 4], ct::IDS.map { |i| ct.get(i)[:ui_order].to_s }.sort, 'ui_order 1..4 bez dier')
end

NxTest.test('H12a T1: norm / id_or_default / known? nad String, Symbol, nil, prazdnym a neznamym') do
  ct = NxH12a::CT
  NxTest.assert_equal('upper', ct.norm('upper'))
  NxTest.assert_equal('upper', ct.norm(:upper))
  NxTest.assert_equal('lower', ct.norm(nil))
  NxTest.assert_equal('lower', ct.norm(''))
  NxTest.assert_equal('lower', ct.norm('tall'), 'neznamy typ = profil dolnej (R5)')
  NxTest.assert(ct.known?(:corner_blind) && ct.known?('dishwasher'))
  NxTest.refute(ct.known?('tall') || ct.known?(nil) || ct.known?(''))
  NxTest.assert_equal('lower', ct.id_or_default(nil))
  NxTest.assert_equal('lower', ct.id_or_default(''))
  NxTest.assert_equal('tall', ct.id_or_default('tall'), 'identita: neznamy typ OSTAVA')
  NxTest.assert_equal('upper', ct.id_or_default('upper'))
  NxTest.assert_equal(ct.get('lower'), ct.get('tall'))
end

NxTest.test('H12a T1: client_payload = kontrakt pre JS (fixtura h12_cabinet_types.json)') do
  got = NxH12a::CT.client_payload
  json = JSON.generate(got)
  NxTest.assert(got.all? { |h| h.keys.all? { |k| k.is_a?(String) } }, 'kluce su stringy')
  NxTest.assert_equal(NxH12a::CT::IDS, got.map { |h| h['id'] })
  want = JSON.parse(File.read(NxH12a::PAYLOAD_FIXTURE, encoding: 'UTF-8'))
  NxTest.assert_equal(want, JSON.parse(json), 'client_payload sa zmenil — zmena kontraktu = fixtura + odsek cabinet_types.rb')
end

# --- T2 · matica predikatov (stara mnozina = nova, R2.1) ------------------------

NxTest.test('H12a T2: predikaty davaju PRESNE dnesne mnoziny typov nad 7 vstupmi') do
  ct = NxH12a::CT
  m = NxH12a
  NxTest.assert_equal(['upper'], m.set_of { |t| ct.hangs?(t) }, 'visi = len horna (home_z, legacy sokel, CN-03)')
  NxTest.assert_equal(%w[upper dishwasher], m.set_of { |t| !ct.on_floor?(t) }, 'nestoji = horna alebo slot')
  NxTest.assert_equal(['dishwasher'], m.set_of { |t| !ct.carcass?(t) }, 'bez korpusu = slot')
  NxTest.assert_equal(['corner_blind'], m.set_of { |t| ct.corner?(t) }, 'rohova zostava')
  NxTest.assert_equal(['dishwasher'], m.set_of { |t| ct.prop(t, :appliance_owner) == 'slot' })
  NxTest.assert_equal(['dishwasher'], m.set_of { |t| ct.prop(t, :fronts) == 'slot_fixed' })
  NxTest.assert_equal(['dishwasher'], m.set_of { |t| ct.prop(t, :front_opening) == 'slot' })
  NxTest.assert_equal(['corner_blind'], m.set_of { |t| ct.prop(t, :auto_name_typed) })
  NxTest.assert_equal(['corner_blind'], m.set_of { |t| ct.prop(t, :type_locked) })
  NxTest.assert_equal(%w[dishwasher corner_blind], ct.ids_where(:template_type, 'locked'))
  NxTest.assert_equal(%w[lower upper], ct.ids_where(:template_type, 'switchable'))
  NxTest.assert_equal(['dishwasher'], m.set_of { |t| !ct.prop(t, :limits).nil? })
end

# --- T3 · guardy --------------------------------------------------------------

NxTest.test('H12a/H12b T3a: v Ruby (core, modules, ui) nie je nove vetvenie podla MENA typu (len vlastnosti registra)') do
  hits = NxH12a.branch_hits
  NxTest.assert(hits.empty?,
                "vetvenie podla mena typu mimo registra (pridaj vlastnost do CabinetTypes::REGISTRY, alebo " \
                "riadok do ALLOW s dovodom): #{hits.first(5).join(' | ')}")
end

NxTest.test('H12a T3a: guard chyti kazdu formu vetvenia podla mena a nehlasi falosne poplachy') do
  caught = [
    "return 'none' if cfg[:type] == 'upper'",
    "slot = type != \"dishwasher\"",
    "'corner_blind' == t",
    "x if t == :upper",
    "when 'upper' then 1",
    "when 'lower', 'dishwasher' then 2",
    'when :corner_blind',
    "%w[lower upper].include?(t)",
    "['upper', 'dishwasher'].include?(t)",
    "LIST.include?('upper')",
    "t.eql?('dishwasher')",
    "z = { 'upper' => 1400.0 }[t]",
    "t = cfg['type'] || 'lower'",
    'CORNER_TYPE == t',
    "return x if cfg['type'].to_s == CabinetTypes::CORNER",
    'CabinetTypes::FALLBACK != have',
    't == CabinetTypes::IDS[1]',
    'when CabinetTypes::CORNER then 1',
    't.eql?(CabinetTypes::FALLBACK)',
    '[a].include?(CabinetTypes::CORNER)'
  ]
  caught.each { |l| NxTest.assert(NxH12a.branch?(l), "guard nechytil: #{l}") }
  clean = [
    "# komentar: == 'upper' sa tu len spomina",
    "tpl('Umyvacka', { 'type' => 'dishwasher', 'width' => 600.0 })",
    'CabinetTypes.hangs?(cfg[:type])',
    "when 'lift' then SYM_UP",
    "x = :lower_bound",
    "label = 'Horná skrinka'",
    "r = cfg[:type] # pozri == 'upper' v komentari",
    "'type' => cfg['type'] || CabinetTypes::FALLBACK,",
    'CORNER_TYPE_ALIAS = CabinetTypes::CORNER',
    'TYPES = CabinetTypes::IDS',
    'return nil unless CabinetTypes::IDS.include?(t)'
  ]
  clean.each { |l| NxTest.refute(NxH12a.branch?(l), "falosny poplach: #{l}") }
end

NxTest.test('H12a T3a: allowlist guardu nie je mrtvy (kazda vynimka ma svoj riadok)') do
  root = File.join(NxTest::ROOT, 'noxun_engine')
  NxH12a::ALLOW.each do |file, frag, why|
    txt = File.read(File.join(root, file), encoding: 'UTF-8')
    NxTest.assert(txt.include?(frag), "vynimka #{file} [#{frag}] (#{why}) uz neplati — zmaz ju")
  end
end

NxTest.test('H12a T3b: DEFAULTS_BY_TYPE = IDS a EXTRA_KEYS_BY_TYPE su podmnozina IDS') do
  cb = NxH12a::CB
  NxTest.assert_equal(NxH12a::CT::IDS, cb::DEFAULTS_BY_TYPE.keys, 'novy typ musi mat predvolby')
  cb::DEFAULTS_BY_TYPE.each { |id, d| NxTest.assert_equal(id, d[:type], "predvolby #{id} nesu svoj typ") }
  NxTest.assert((cb::EXTRA_KEYS_BY_TYPE.keys - NxH12a::CT::IDS).empty?, 'extra polia len pre znamy typ')
  NxTest.assert_equal(cb::DW_KEYS, cb::EXTRA_KEYS_BY_TYPE['dishwasher'])
  NxTest.assert_equal(cb::CORNER_KEYS, cb::EXTRA_KEYS_BY_TYPE['corner_blind'])
end

# T3c (pasca zavesov CN-03) zije od H13 v `test_h13_rozsirovacie_body.rb`
# (rovnaka kontrola + zoznam vynimiek s dovodom a negativne testy).

NxTest.test('H12a T3e: main.rb nacita register za build_plan a PRED construction/hardware_rules/builderom') do
  main = NxH12a.src('noxun_engine', 'main.rb')
  at = ->(rel) { main.index("Sketchup.require 'noxun_engine/core/#{rel}'") }
  reg = at.call('cabinet_types')
  NxTest.assert(reg, 'main.rb nenacitava core/cabinet_types')
  NxTest.assert(at.call('build_plan') < reg, 'register az za build_plan')
  %w[hardware_rules construction scale_observer cabinet_builder ghost_tool templates bom].each do |rel|
    NxTest.assert(reg < at.call(rel), "register musi byt nacitany PRED #{rel} (inak pad pri starte)")
  end
  helper = NxH12a.src('tests', 'helper.rb')
  NxTest.assert(helper.index('core/cabinet_types') < helper.index('core/construction'), 'helper: rovnake poradie')
end
