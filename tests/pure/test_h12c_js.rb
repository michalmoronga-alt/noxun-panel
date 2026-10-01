# frozen_string_literal: true
# H12c (blok 9 HARDENING, C-01) — JS Inspectora a Studia cita TYPY SKRINKY
# zo servera. Package H12 §6 R3, §7 T3a (JS) a T3d, §15 A1.
#
# CO PLATI:
#   * JS nema vlastny zoznam ani porovnanie MENA typu — register `NXTypes`
#     (core.js) plni `NX.init` z `cabinet_types` (= `CabinetTypes.client_payload`);
#     vynimky (bootstrap `DEFAULTS` pred initom, `FALLBACK` a hodnota zostavy
#     v registri) su v ALLOW s dovodom;
#   * HTML ostava STATICKE (rozhodnutie D5) — tlacidla typu a `<select>`
#     modalu sablony sa porovnavaju s registrom (`label`, `ui_order`);
#   * vety rozsahu pravidiel (`type_scope`) a slovo typu sablony (`type_word`)
#     sklada server — fixtura `type_scope.json` (vstup JS golden) = Ruby pole
#     po riadkoch (`type_scope_list`).
#
# Spravanie pred/po (bajtovo) strazi JS golden `tests/js/test_h12_golden.js`;
# register, A1 a matica su v `tests/js/test_h12c_typy.js`.
#
# MUTACIE (overene rucne pri davke, PR H12c; kazda zhodi aspon jeden test):
# C1 (M6) `currentCarcass` cez `!onFloor` namiesto `hangs` · C2 navrh ciel cez
# `hangs` namiesto `!onFloor` · C3 riadok Sokel cez `!hangs` · C4 „Delenie zóny"
# cez `zones !== 'tree'` · C5 nohy bez `known(t)` · C6 `templateType` bez `norm`
# (surovy typ) · C7 (M5) `norm` neznamy ponecha · C8 neutralny profil
# `on_floor false` (bliknutie pred initom) · C9 (M15) `NXTypes.set` az po
# `loadSelected` · C10 (A1) zoznam typov vkladania zlozeny pri nacitani ·
# C11 vety rozsahu v `rdSetExtra` (lacne echo ich prepise) · C12 rail zamkne
# Zony pri kazdom `zones != tree` · C13 HTML popisok tlacidla iny nez `label` ·
# C14 nove `=== 'upper'` v form.js.
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog') unless defined?(Noxun::Engine::RulesDialog)
end

module NxH12c
  module_function

  E  = Noxun::Engine
  CT = E::CabinetTypes
  JS_DIR = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js')

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  NAME = '(?:lower|upper|dishwasher|corner_blind)'
  # Retazec v JS: '…', "…" aj sablonovy `…` (predrecenzia P3).
  Q = %q{['"`]}
  # Formy vetvenia podla MENA typu v JS (porovnanie oboma smermi, `case`,
  # `indexOf`/`includes`, zoznam v poli, predvolba `||` aj ternarna, mapa
  # s klucom typu — holym aj v uvodzovkach — a pristup `.corner_blind`/`['upper']`).
  BRANCH_RES = [
    /[{,]\s*#{Q}#{NAME}#{Q}\s*:/,
    /(?:===?|!==?)\s*#{Q}#{NAME}#{Q}/,
    /#{Q}#{NAME}#{Q}\s*(?:===?|!==?)/,
    /\bcase\s+#{Q}#{NAME}#{Q}/,
    /(?:indexOf|includes)\(\s*#{Q}#{NAME}#{Q}/,
    /\[[^\]]*#{Q}#{NAME}#{Q}[^\]]*\]/,
    /\|\|\s*#{Q}#{NAME}#{Q}/,
    /\?[^:;]*:\s*#{Q}#{NAME}#{Q}/,
    /[{,]\s*#{NAME}\s*:/,
    /\.#{NAME}\b/
  ].freeze
  # [subor, podretazec riadka, DOVOD]. Novy riadok LEN s dovodom — inak patri
  # vlastnost do registra (`CabinetTypes::REGISTRY`, JS ju dostane v `NX.init`).
  ALLOW = [
    ['core.js', 'var DEFAULTS = { lower: {}, upper: {} };', 'bootstrap predvolieb PRED NX.init (R3.6)'],
    ['bridge.js', 'DEFAULTS = data.defaults || { lower: {}, upper: {} };', 'bootstrap predvolieb bez kluca (R3.6)'],
    ['core.js', "var FALLBACK = 'lower';", 'FALLBACK registra NXTypes (jedina konstanta typu, R5)'],
    ['core.js', "corner: function(t){ return get(t).assembly === 'corner_blind'; }",
     'hodnota ZOSTAVY v registri (Ruby `CabinetTypes::CORNER`), nie meno typu']
  ].freeze

  def code_part(line)
    s = line.strip
    return '' if s.start_with?('//', '*', '/*')

    line.sub(%r{\s//\s.*\z}, '')
  end

  def branch?(line)
    code = code_part(line)
    BRANCH_RES.any? { |re| code.match?(re) }
  end

  def branch_hits
    Dir[File.join(JS_DIR, '*.js')].sort.flat_map do |path|
      rel = File.basename(path)
      File.readlines(path, encoding: 'UTF-8').each_with_index.filter_map do |line, i|
        code = code_part(line)
        next nil unless BRANCH_RES.any? { |re| code.match?(re) }
        next nil if ALLOW.any? { |f, frag, _why| f == rel && code.include?(frag) }

        "ui/js/#{rel}:#{i + 1}: #{line.strip}"
      end
    end
  end

  def by_order
    CT.client_payload.sort_by { |r| r['ui_order'] }
  end
end

# --- T3a · JS bez vetvenia podla mena typu -----------------------------------------

NxTest.test('H12c T3a: v ui/js nie je vetvenie podla MENA typu (len vlastnosti registra NXTypes)') do
  hits = NxH12c.branch_hits
  NxTest.assert(hits.empty?,
                'vetvenie podla mena typu v JS (pridaj vlastnost do CabinetTypes::REGISTRY — JS ju dostane ' \
                "v NX.init —, alebo riadok do ALLOW s dovodom): #{hits.first(5).join(' | ')}")
end

NxTest.test('H12c T3a: guard chyti kazdu formu vetvenia podla mena v JS a nehlasi falosne poplachy') do
  caught = [
    "if (t === 'upper') return 0;",
    "var slot = (cabTypeNow() == \"dishwasher\");",
    "if ('corner_blind' !== t) return;",
    "case 'lower': x = 1;",
    "if (LIST.indexOf('upper') >= 0) y();",
    "kinds.includes('dishwasher')",
    "var CAB = ['lower', 'upper'];",
    "var t = c.type || 'lower';",
    "var t = has ? getType() : 'lower';",
    "var L = { lower: 'Dolná', upper: 'Horná' };",
    'var d = DEFAULTS.corner_blind || {};',
    # predrecenzia P3: mapa s klucom v uvodzovkach a sablonovy retazec
    "var L = { 'upper': 'Horná' };",
    'var L = { "dishwasher": 1, "lower": 2 };',
    'var L = {a: 1, "corner_blind": 3};',
    'if (t === `upper`) return 0;',
    'var CAB = [`lower`, `upper`];',
    'var d = DEFAULTS[`dishwasher`];'
  ]
  caught.each { |l| NxTest.assert(NxH12c.branch?(l), "guard nechytil: #{l}") }
  clean = [
    "// komentar: t === 'upper' sa tu len spomina",
    "if (NXTypes.hangs(t)) return 0;",
    "var slot = !NXTypes.carcass(cabTypeNow()); // pozri === 'dishwasher' v komentari",
    "if (type === 'blind' && NXTypes.has(cabType, 'fronts', 'slot_fixed')) return 'down';",
    "{ id:'corner_door_w', kind:'num', dflt:450, onlyIf:'corner' },",
    "var t = c.type || NXTypes.FALLBACK;",
    "type: 'lower',  // bootstrap",
    "label = 'Horná skrinka';",
    "var o = { 'type': t, 'upper_hang': 1 };",
    'var s = `Typ ${NXTypes.label(t)}`;',
    "var k = { lowerBound: 1 };"
  ]
  clean.each { |l| NxTest.refute(NxH12c.branch?(l), "falosny poplach: #{l}") }
end

NxTest.test('H12c T3a: allowlist JS guardu nie je mrtvy (kazda vynimka ma svoj riadok)') do
  NxH12c::ALLOW.each do |file, frag, why|
    txt = File.read(File.join(NxH12c::JS_DIR, file), encoding: 'UTF-8')
    NxTest.assert(txt.include?(frag), "vynimka #{file} [#{frag}] (#{why}) uz neplati — zmaz ju")
  end
end

NxTest.test('H12c R3.2: zrusene JS zoznamy typu nie su nikde v ui/js') do
  all = Dir[File.join(NxH12c::JS_DIR, '*.js')].map { |p| File.read(p, encoding: 'UTF-8') }.join("\n")
  %w[CAB_TYPES INSERT_TYPES NX_TYPE_LABEL LEGS_INSERT_TYPES NX_CTX_LOCK TPL_TYPE_LOCK TPL_TYPE_WORDS].each do |name|
    NxTest.refute(all.match?(/\bvar\s+#{name}\b|\b#{name}\s*:/), "#{name} sa vratil ako JS zoznam")
  end
  NxTest.refute(all.match?(/\bvar\s+TYPE_LIMITS\b/), 'TYPE_LIMITS sa vratil')
end

# --- R3.1 · dorucenie registra --------------------------------------------------

NxTest.test('H12c R3.1: NX.init nasadi register PRVYM prikazom, server ho posiela') do
  bridge = NxH12c.src('noxun_engine', 'ui', 'js', 'bridge.js')
  body = bridge[/init: function\(data\)\{\n(.*?)\n\s*DEFAULTS = /m, 1].to_s
  code = body.lines.map(&:strip).reject { |l| l.empty? || l.start_with?('//') }
  NxTest.assert_equal(['NXTypes.set(data.cabinet_types);'], code, 'pred predvolbami a vyberom nic ine nebezi')
  NxTest.assert(NxH12c.src('noxun_engine', 'ui', 'panel', 'sync.rb').include?('cabinet_types: CabinetTypes.client_payload'),
                'push_init posiela register')
  core = NxH12c.src('noxun_engine', 'ui', 'js', 'core.js')
  preds = core[/var NXTypes = \(function\(\)\{(.*?)\n  \}\)\(\);/m, 1].to_s
  NxTest.refute(preds.empty?, 'NXTypes je v core.js')
  # `onlyIf` pola konstrukcie musi byt predikat registra (inak by zber spadol).
  core.scan(/onlyIf:'([a-zA-Z]+)'/).flatten.uniq.each do |p|
    NxTest.assert(preds.match?(/\b#{p}: function\(t\)/), "onlyIf '#{p}' je predikat NXTypes")
  end
end

# --- T3d · HTML (staticke, D5) = register ----------------------------------------

NxTest.test('H12c T3d: tlacidla typu vo vkladacej karte = register (poradie ui_order, label, title)') do
  html = NxH12c.src('noxun_engine', 'ui', 'panel.html')
  row = html[%r{<div class="segrow" id="insertTypeRow">(.*?)</div>}m, 1].to_s
  btns = row.scan(%r{<button[^>]*data-ins-type="([a-z_]+)"[^>]*title="([^"]*)"[^>]*>.*?<span>([^<]*)</span></button>}m)
  cab = btns.reject { |id, _t, _l| id == 'board' }
  NxTest.assert_equal(NxH12c.by_order.map { |r| r['id'] }, cab.map(&:first), 'typy a poradie = register (ui_order)')
  NxTest.assert_equal(NxH12c.by_order.map { |r| r['label'] }, cab.map(&:last), 'text tlacidla = label registra')
  cab.each { |id, title, _l| NxTest.refute(title.strip.empty?, "tlacidlo #{id} ma title") }
  NxTest.assert_equal('board', btns.last.first, 'doska je posledna volba (nie typ korpusu)')
end

NxTest.test('H12c T3d: select typu v modale „Uložiť ako šablónu" = register (value, text, poradie)') do
  html = NxH12c.src('noxun_engine', 'ui', 'panel.html')
  sel = html[%r{<select id="tplSaveType">(.*?)</select>}m, 1].to_s
  opts = sel.scan(%r{<option value="([a-z_]+)">([^<]*)</option>})
  NxTest.assert_equal(NxH12c.by_order.map { |r| [r['id'], r['label']] }, opts, 'volby = register v poradi ui_order')
end

# --- R3.4 · Studio: vety zo servera ----------------------------------------------

NxTest.test('H12c R3.4: fixtura type_scope.json (vstup JS golden) = pole servera type_scope_list') do
  fx = JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'h12_golden', 'type_scope.json'), encoding: 'UTF-8'))
  NxTest.assert_equal(fx['type_scope'], NxH12c::E::RulesDialog.type_scope_list(fx['rules']),
                      'JS golden dostava presne to, co server posiela')
  rules = NxH12c.src('noxun_engine', 'ui', 'js', 'rules.js')
  NxTest.assert(rules.include?('RD_TYPE_SCOPE = rdScopeList(d.type_scope);'), 'plny push nasadi pole (rdSetState)')
  NxTest.assert(rules.include?('rdRoleDesc(r, rdScopeAt(i))'), 'riadok formulara berie vetu na svojej pozicii')
  NxTest.refute(rules.match?(/r\.rule_id\b[^\n]*RD_TYPE_SCOPE|RD_TYPE_SCOPE[^\n]*rule_id/), 'vety sa nekluccuju podla rule_id')
  extra = rules[/function rdSetExtra\(d\)\{(.*?)\n  \}/m, 1].to_s
  NxTest.refute(extra.include?('type_scope'), 'lacne echo (rdSetExtra) mapu neprepisuje')
  tpl = NxH12c.src('noxun_engine', 'ui', 'js', 'templates.js')
  NxTest.assert(tpl.include?("function tplTypeWord(tp){ return String((tp && tp.type_word) || ''); }"),
                'slovo typu dlazdice = type_word servera')
end
