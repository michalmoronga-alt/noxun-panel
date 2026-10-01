# frozen_string_literal: true
# Testy H10a/R-35 — DVE OKNA SKETCHUPU A GLOBALNE PRAVIDLA KOVANIA.
#
# Do H10a zapisovalo okno Pravidla globalnu kniznicu (`hardware_rules.json`,
# „aj ako globálnu predvoľbu") UPLNOU NAHRADOU bez revizie: dve okna, ktore si
# pravidla nacitali sucasne, sa prebijali „posledny vyhrava" a zmena prveho
# zanikla bez slova (sonda P1). Projekt BEZ vlastnych pravidiel (preberajuci
# globál) navyse dopadol podla sekundovej cache: raz sa rozpisany formular
# zahodil, raz sa cudzi globál ticho prepisal (audit FIX 2).
#
# Co davka garantuje a co tieto testy overuju:
#   C   jedno okno — kniznica sa zapise BAJTOVO rovnako ako doteraz;
#   A1  `library_check` (rozliseny stav bez zapisu, brana = `write_gate` H9)
#       a `save_library!` (revizia POD zamkom nad cerstvym suborom);
#   A2  predkontrola v `handle_save` — kazdy riadok tabulky R1.4: presna
#       hlaska, ziadna operacia, formular ostava, obnova pinu LEN pri
#       konflikte (nie pri chybe citania ani brane);
#   A3  projekt bez snapshotu — rozhodne cerstva predkontrola pri OBOCH
#       casovaniach cache (formular ostava), identita dokumentu bez zmeny;
#   A4  subeh PO prestavbe (H-RACE) — projekt ulozeny, cudzi globál bajtovo
#       zachovany, pin obnoveny;
#   A5  strukturalne guardy zdroja (poradie, `case`, ziadny `write(` z okna).
#
# MUTACIE overene proti tejto sade + `tests/js/test_h10a_pin.js` su v PR.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog')
  # `Panel.job_cabinets*` / `detached_skipped_tail` (vzor test_d134).
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'resolvers')
end

module NxH10a
  E     = Noxun::Engine
  HR    = E::HardwareRules
  STORE = E::JsonFileStore
  MAT   = E::Materials

  module_function

  # Ulozi primar aj `.bak` kniznice, spusti blok a vrati PRESNY povodny stav.
  def with_lib
    paths = [HR.path, "#{HR.path}.bak"]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    STORE.reload!(HR.path)
    HR.instance_variable_set(:@write_block_reason, '')
    yield
  ensure
    before.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
    end
    STORE.reload!(HR.path)
    HR.instance_variable_set(:@write_block_reason, '')
  end

  def bytes(path = HR.path)
    File.exist?(path) ? File.binread(path) : nil
  end

  def files
    [bytes(HR.path), bytes("#{HR.path}.bak")]
  end

  def lib_doc(rules, std: HR::STD, seed_version: HR::SEED_VERSION)
    { 'std' => std, 'seed_version' => seed_version, 'rules' => HR.normalize_rules(rules) }
  end

  # Pravidla s jednou zmenou (prepnute `enabled` pravidla s danym vystupom).
  def toggled(output, base = HR::SEED_RULES)
    HR.normalize_rules(base).map do |r|
      r['output'] == output ? r.merge('enabled' => r['enabled'] == false) : r
    end
  end

  # „Druhe okno" zapise globál PRIAMO na disk (tmp + rename) a nasu sekundovu
  # cache ZAMERNE NEzhodi — iny OS proces ju tiez nezhodi (vzor R-08).
  def other_write(doc)
    FileUtils.mkdir_p(File.dirname(HR.path))
    tmp = "#{HR.path}.tmp-other"
    File.binwrite(tmp, doc.is_a?(String) ? doc : JSON.pretty_generate(doc))
    File.rename(tmp, HR.path)
  end

  # Degradovany stav (poskodeny primar + zaloha dobreho tvaru).
  def make_degraded
    File.binwrite("#{HR.path}.bak", JSON.pretty_generate(lib_doc(HR::SEED_RULES)))
    File.binwrite(HR.path, '{ poskodeny')
    STORE.invalidate
  end

  def make_newer
    File.binwrite(HR.path, JSON.pretty_generate(lib_doc(HR::SEED_RULES, std: HR::STD + 1)))
    FileUtils.rm_f("#{HR.path}.bak")
    STORE.invalidate
  end

  # Citanie kniznice zlyha I/O chybou (prava, zdielanie) — LEN pre jej subory.
  def with_unreadable
    orig = STORE.method(:read)
    lib = File.expand_path(HR.path)
    STORE.define_singleton_method(:read) do |path, **kw|
      raise Errno::EACCES, 'hardware_rules.json (test)' if File.expand_path(path).start_with?(lib)

      orig.call(path, **kw)
    end
    yield
  ensure
    STORE.define_singleton_method(:read, orig)
  end

  # Druha instancia zapise PRESNE RAZ tesne pred tym, nez si vezmeme zamok.
  def with_other_instance(doc)
    orig = MAT.method(:with_catalog_lock)
    fired = false
    MAT.define_singleton_method(:with_catalog_lock) do |&blk|
      unless fired
        fired = true
        NxH10a.other_write(doc)
      end
      orig.call(&blk)
    end
    yield
    fired
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end

  def with_broken_lock
    orig = MAT.method(:with_catalog_lock)
    MAT.define_singleton_method(:with_catalog_lock) { |&_b| raise Errno::EACCES, 'materials.lock (test)' }
    yield
  ensure
    MAT.define_singleton_method(:with_catalog_lock, orig)
  end

  # Zdroje (strukturalne guardy). Konce riadkov sa normalizuju (CRLF/LF).
  def src(rel)
    File.binread(File.join(NxTest::ROOT, 'noxun_engine', rel)).force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  def body(rel, name, indent)
    src(rel)[/^#{' ' * indent}def #{Regexp.escape(name)}(?![\w!?]).*?\n#{' ' * indent}end\n/m].to_s
  end
end

# Fake model: atributy (snapshot pravidiel), identita (`path` pre DocKey)
# a zaznam operacii — presne to, co `handle_save` od modelu potrebuje
# (`CabinetBuilder.rebuild_many` nad prazdnym zoznamom jobov otvori a zavrie
# operaciu, sonda H2).
class NxH10aModel
  attr_reader :ops

  def initialize
    @ops = []
    @attrs = {}
  end

  def path
    ''
  end

  def get_attribute(dict, key, default = nil)
    @attrs.key?([dict, key]) ? @attrs[[dict, key]] : default
  end

  def set_attribute(dict, key, value)
    @attrs[[dict, key]] = value
  end

  def start_operation(name, *_rest)
    @ops << [:start, name]
    true
  end

  def commit_operation
    @ops << [:commit]
    true
  end

  def abort_operation
    @ops << [:abort]
    true
  end

  def active_path
    nil
  end
end

module NxH10aSave
  RD = Noxun::Engine::RulesDialog
  HR = Noxun::Engine::HardwareRules

  module_function

  # Docasne stuby okna (vzor R-37 T15): `Sketchup.active_model`, zakazka bez
  # skriniek, `after_model_write` a echo sekcie sa ZAZNAMENAJU.
  def with_dialog(model)
    panel = Noxun::Engine::Panel
    log = { after: 0, echo: [] }
    stubs = [[panel, :job_cabinets_split, ->(_m) { [[], []] }],
             [panel, :job_cabinets, ->(_m) { { 'cabinets' => [] } }],
             [panel, :detached_skipped_tail, ->(_s) { '' }],
             [RD, :after_model_write, ->(_m) { log[:after] += 1 }],
             [RD, :push_section_echo, ->(_m, force: false) { log[:echo] << force }]]
    orig = stubs.map do |obj, name, _|
      [obj, name, begin
        obj.method(name)
      rescue NameError
        nil
      end]
    end
    stubs.each { |obj, name, impl| obj.define_singleton_method(name, &impl) }
    su = Module.new
    su.define_singleton_method(:active_model) { model }
    Object.const_set(:Sketchup, su)
    yield log
  ensure
    Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
    Array(orig).each do |obj, name, m|
      m ? obj.define_singleton_method(name, m) : obj.singleton_class.send(:remove_method, name)
    end
    %i[@baseline_guid @baseline_rules @baseline_rev @baseline_source @client_sink].each do |iv|
      RD.instance_variable_set(iv, nil)
    end
  end

  # Model so snapshotom (vlastne pravidla projektu) alebo bez neho.
  def model(snapshot: true)
    m = NxH10aModel.new
    if snapshot
      m.set_attribute(Noxun::Engine::Store::DICT, HR::MODEL_KEY,
                      JSON.generate(NxH10a.lib_doc(NxH10a.toggled('shelf_pin'))))
    end
    m
  end

  # Ulozenie zo sekcie presne ako klient: z payloadu, ktorym bol naplneny.
  # `global_rev: :omit` = stary DOM (kluc chyba).
  def save(model, pay, rules, also_global:, global_rev: nil)
    data = { 'rules' => rules, 'also_global' => also_global,
             'model_guid' => pay['model_guid'], 'rules_rev' => pay['rules_rev'] }
    data['global_rev'] = global_rev.nil? ? pay['global_rev'] : global_rev unless global_rev == :omit
    rec = []
    RD.dispatch('save_rules', data.to_json, ->(s) { rec << s.to_s })
    rec
  end

  def statuses(rec)
    rec.filter_map do |s|
      m = s.match(/\ARD\.setStatus\((".*"), (true|false)\)\z/m)
      m && [JSON.parse("[#{m[1]}]").first, m[2] == 'true']
    end
  end

  def last_status(rec)
    statuses(rec).last || ['', false]
  end

  def global_revs(rec)
    rec.flat_map { |s| s.scan(/RD\.setGlobalRev\(("[^"]*")\)/).map { |(j)| JSON.parse("[#{j}]").first } }
  end

  def snapshot(model)
    HR.project_rules(model)
  end
end

# =============================================================================
# C · charakterizacia
# =============================================================================

NxTest.test('H10a C1: jedno okno — `write` zapise kniznicu presne v dnesnom tvare') do
  r = NxH10a
  r.with_lib do
    rules = r.toggled('leg')
    NxTest.assert(r::HR.write(rules), 'zapis prebehol')
    want = JSON.pretty_generate('std' => r::HR::STD, 'seed_version' => r::HR::SEED_VERSION,
                                'rules' => r::HR.normalize_rules(rules))
    NxTest.assert_equal(want, r.bytes, 'bajty = {std, seed_version, normalize_rules(rules)}')
  end
end

NxTest.test('H10a C1: `save_library!` s aktualnou reviziou zapise TIE ISTE bajty ako `write`') do
  r = NxH10a
  rules = r.toggled('leg')
  want = nil
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    r::HR.write(rules)
    want = r.bytes
  end
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    rev = r::HR.library_check[:rev]
    status, nrev = r::HR.save_library!(rules, rev)
    NxTest.assert_equal(:ok, status)
    NxTest.assert_equal(want, r.bytes, 'jedno okno = bajtovo rovnaky subor')
    NxTest.assert_equal(r::HR.library_check[:rev], nrev, 'vratena revizia = revizia zapisaneho obsahu')
    NxTest.refute(nrev.to_s.empty?, 'a nie je prazdna')
  end
end

# =============================================================================
# A1 · jadro: library_check / library_revision / save_library!
# =============================================================================

NxTest.test('H10a T-A1: library_check :ok — revizia obsahu = rules_rev(load), BEZ zapisu') do
  r = NxH10a
  r.with_lib do
    # Starsi seed_version: `load` by seed-mergol a ZAPISAL — check nesmie.
    old = r.lib_doc(r.toggled('leg'), seed_version: 0)
    old['rules'] = old['rules'].reject { |x| x['rule_id'] == r::HR::SEED_RULES.last['rule_id'] }
    r.other_write(old)
    r::STORE.invalidate
    before = r.files
    c = r::HR.library_check
    NxTest.assert_equal(:ok, c[:state])
    NxTest.assert_equal('', c[:reason])
    NxTest.assert_equal(before, r.files, 'ziadny zapis (ani seed-merge, ani seed)')
    NxTest.assert_equal(c[:rev], r::HR.library_revision, 'payload a predkontrola maju tu istu reviziu')
    NxTest.assert_equal(r::HR.rules_rev(r::HR.load), c[:rev],
                        'obsahova revizia = to, co vidi `load` (seed-merge meni bajty, nie obsah)')
  end
end

NxTest.test('H10a T-A1: poskodeny primar BEZ zalohy a chybajuci subor = revizia seedu (samooprava ostava)') do
  r = NxH10a
  seed_rev = r::HR.rules_rev(r::HR.normalize_rules(r::HR::SEED_RULES))
  NxTest.assert_equal(r::HR.rules_rev(r::HR::SEED_RULES), seed_rev, 'seed a normalizovany seed = ta ista revizia')
  r.with_lib do
    File.binwrite(r::HR.path, '{ poskodeny')
    FileUtils.rm_f("#{r::HR.path}.bak")
    r::STORE.invalidate
    c = r::HR.library_check
    NxTest.assert_equal([:ok, seed_rev], [c[:state], c[:rev]], 'poskodeny bez zalohy')
    FileUtils.rm_f(r::HR.path)
    r::STORE.invalidate
    c = r::HR.library_check
    NxTest.assert_equal([:ok, seed_rev], [c[:state], c[:rev]], 'chybajuci subor')
    NxTest.refute(File.exist?(r::HR.path), 'a check ho NEZALOZIL')
    status, = r::HR.save_library!(r.toggled('leg'), seed_rev)
    NxTest.assert_equal(:ok, status, 'zapis nad seedovou reviziou prejde (samooprava R-11)')
  end
end

NxTest.test('H10a T-A1: degradovany a novsi std -> :blocked s vetou brany; parita s `write`') do
  r = NxH10a
  [[:degraded, -> { r.make_degraded }], [:newer, -> { r.make_newer }]].each do |(name, setup)|
    r.with_lib do
      setup.call
      gate, reason = r::HR.write_gate
      NxTest.assert_equal(name, gate, "#{name}: brana H9")
      c = r::HR.library_check
      NxTest.assert_equal(:blocked, c[:state], "#{name}: citatelne, zapis zakazany")
      NxTest.assert_equal(reason, c[:reason], "#{name}: veta = presne veta brany")
      NxTest.refute(c[:rev].to_s.empty?, "#{name}: revizia z precitaneho obsahu")
      before = r.files
      NxTest.assert_equal(false, r::HR.write(r.toggled('leg')), "#{name}: `write` odmietne")
      NxTest.assert_equal(reason, r::HR.write_block_reason, "#{name}: ten isty dovod (jedna autorita)")
      NxTest.assert_equal(before, r.files, "#{name}: nic sa nezapisalo")
    end
  end
end

NxTest.test('H10a T-A1: parita library_check <-> write v piatich stavoch suboru') do
  r = NxH10a
  states = {
    zdravy: -> { r::HR.write(r::HR::SEED_RULES) },
    degradovany: -> { r.make_degraded },
    novsi: -> { r.make_newer },
    poskodeny_bez_zalohy: -> { File.binwrite(r::HR.path, 'x'); FileUtils.rm_f("#{r::HR.path}.bak") },
    chybajuci: -> { FileUtils.rm_f(r::HR.path); FileUtils.rm_f("#{r::HR.path}.bak") }
  }
  states.each do |name, setup|
    r.with_lib do
      setup.call
      r::STORE.invalidate
      blocked = r::HR.library_check[:state] == :blocked
      NxTest.assert_equal(!blocked, r::HR.write(r.toggled('leg')), "#{name}: check :blocked <=> write false")
    end
  end
end

NxTest.test('H10a T-A1: necitatelna kniznica -> :unreadable, rev nil; zapis :unreadable a nic') do
  r = NxH10a
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    rev = r::HR.library_check[:rev]
    before = r.files
    r.with_unreadable do
      c = r::HR.library_check
      NxTest.assert_equal([:unreadable, nil], [c[:state], c[:rev]])
      NxTest.assert_equal('', r::HR.library_revision, 'payload: neznama revizia = prazdna')
      NxTest.assert_equal([:unreadable, nil], r::HR.save_library!(r.toggled('leg'), rev))
    end
    NxTest.assert_equal(before, r.files, 'nic sa nezapisalo')
  end
end

NxTest.test('H10a T-A1: dve okna z tej istej revizie — prve uspeje, druhe dostane KONFLIKT') do
  r = NxH10a
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    rev0 = r::HR.library_check[:rev]
    a = r.toggled('leg')
    b = r.toggled('hinge')
    sa, rev_a = r::HR.save_library!(a, rev0)
    NxTest.assert_equal(:ok, sa, 'okno A')
    sb, rev_b = r::HR.save_library!(b, rev0)
    NxTest.assert_equal([:conflict, rev_a], [sb, rev_b], 'okno B: konflikt + AKTUALNA revizia (A)')
    NxTest.assert_equal(r::HR.normalize_rules(a), JSON.parse(r.bytes)['rules'], 'v subore ostala zmena A')
    NxTest.assert_equal(:ok, r::HR.save_library!(b, rev_b).first, 'vedome prepisanie s cerstvou reviziou prejde')
  end
end

NxTest.test('H10a T-A1: prazdna aj chybajuca revizia = konflikt (fail-closed)') do
  r = NxH10a
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    rev0 = r::HR.library_check[:rev]
    before = r.files
    ['', nil].each do |bad|
      NxTest.assert_equal([:conflict, rev0], r::HR.save_library!(r.toggled('leg'), bad), bad.inspect)
    end
    NxTest.assert_equal(before, r.files, 'nic sa nezapisalo')
  end
end

NxTest.test('H10a T-A1: cudzi zapis tesne pred zamkom -> konflikt, cudzi obsah PREZIJE') do
  r = NxH10a
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    rev0 = r::HR.library_check[:rev]
    r::STORE.read(r::HR.path) # nahreta cache (stav bezicich okien)
    foreign = r.lib_doc(r.toggled('hinge'))
    out = nil
    fired = r.with_other_instance(foreign) { out = r::HR.save_library!(r.toggled('leg'), rev0) }
    NxTest.assert(fired, 'druha instancia zapisala')
    NxTest.assert_equal(:conflict, out.first, 'revizia sa porovnava AZ POD zamkom nad cerstvym suborom')
    NxTest.assert_equal(r::HR.rules_rev(foreign['rules']), out.last, 'vrati reviziu cudzieho obsahu')
    NxTest.assert_equal(foreign['rules'], JSON.parse(r.bytes)['rules'], 'cudzi obsah nezmeneny')
  end
end

NxTest.test('H10a T-A1: degradovany + zla revizia -> :blocked (nie konflikt); zamok zlyha -> :write_failed') do
  r = NxH10a
  r.with_lib do
    r.make_degraded
    before = r.files
    NxTest.assert_equal([:blocked, nil], r::HR.save_library!(r.toggled('leg'), 'zla-revizia'))
    NxTest.assert(r::HR.write_block_reason.include?('poškodené'), 'dovod brany pre okno')
    NxTest.assert_equal(before, r.files, 'nic sa nezapisalo')
  end
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    rev0 = r::HR.library_check[:rev]
    before = r.files
    r.with_broken_lock do
      NxTest.assert_equal([:write_failed, nil], r::HR.save_library!(r.toggled('leg'), rev0))
    end
    NxTest.assert_equal(before, r.files, 'bez zamku sa nezapisalo nic')
  end
end

# =============================================================================
# A2 · predkontrola v `handle_save` (tabulka R1.4)
# =============================================================================

NxTest.test('H10a T-A2 riadok 7: zhoda revizie — projekt aj globál ulozene, pin = nova revizia') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    model = s.model
    s.with_dialog(model) do |log|
      pay = s::RD.rules_payload(model)
      NxTest.assert_equal(r::HR.library_check[:rev], pay['global_rev'], 'payload nesie reviziu globalu')
      form = r.toggled('leg', pay['rules'])
      rec = s.save(model, pay, form, also_global: true)
      msg, err = s.last_status(rec)
      NxTest.assert(msg.start_with?('Pravidlá uložené do projektu + globálna predvoľba — prestavaných 0 skriniek'), msg)
      NxTest.refute(err)
      NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model), 'projekt = formular')
      NxTest.assert_equal(r::HR.normalize_rules(form), JSON.parse(r.bytes)['rules'], 'globál = formular')
      NxTest.assert_equal([r::HR.library_check[:rev]], s.global_revs(rec), 'pin = nova revizia globalu')
      NxTest.assert_equal([[:start, 'NOXUN: pravidla kovania'], [:commit]], model.ops)
      NxTest.assert_equal(1, log[:after])
    end
  end
end

NxTest.test('H10a T-A2 riadok 6: cudzi globál (H-PRE) — NIC sa neulozi, formular ostava, pin obnoveny') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    model = s.model
    s.with_dialog(model) do |log|
      pay = s::RD.rules_payload(model)
      snap0 = s.snapshot(model)
      foreign = r.lib_doc(r.toggled('hinge'))
      r.other_write(foreign)
      fbytes = r.bytes
      rec = s.save(model, pay, r.toggled('leg', pay['rules']), also_global: true)
      msg, err = s.last_status(rec)
      NxTest.assert_equal(s::RD::GLOBAL_PRE_TEXT, msg)
      NxTest.assert(err, 'cervena')
      NxTest.assert_equal([], model.ops, 'ziadna operacia = ziadny krok Spat')
      NxTest.assert_equal(snap0, s.snapshot(model), 'snapshot nedotknuty')
      NxTest.assert_equal(fbytes, r.bytes, 'cudzi globál bajtovo nedotknuty')
      NxTest.assert_equal([r::HR.rules_rev(foreign['rules'])], s.global_revs(rec), 'pin = cudzia revizia')
      NxTest.assert_equal([], log[:echo], 'ziadne echo — rozpisany formular ostava')
      NxTest.assert_equal(0, log[:after])
      # Druhe Ulozit s obnovenym pinom = vedome prepisanie.
      form = r.toggled('leg', pay['rules'])
      rec2 = s.save(model, pay, form, also_global: true, global_rev: s.global_revs(rec).last)
      NxTest.assert(s.last_status(rec2).first.include?('+ globálna predvoľba'), s.last_status(rec2).first)
      NxTest.assert_equal(r::HR.normalize_rules(form), JSON.parse(r.bytes)['rules'], 'globál = formular')
    end
  end
end

NxTest.test('H10a T-A2 riadky 1, 3, 4: necitatelny / stary DOM / neznamy zaklad — nic, pin len pri 4') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  cases = [
    ['1 H-READ', s::RD::GLOBAL_READ_TEXT, { global_rev: nil }, true, false],
    ['3 H-OLD', s::RD::GLOBAL_OLD_TEXT, { global_rev: :omit }, false, false],
    ['4 H-UNK', s::RD::GLOBAL_UNK_TEXT, { global_rev: '' }, false, true]
  ]
  cases.each do |(name, text, opts, unreadable, pin)|
    r.with_lib do
      r::HR.write(r::HR::SEED_RULES)
      model = s.model
      s.with_dialog(model) do |log|
        pay = s::RD.rules_payload(model)
        snap0 = s.snapshot(model)
        before = r.files
        rec = nil
        run = -> { rec = s.save(model, pay, r.toggled('leg', pay['rules']), also_global: true, **opts) }
        unreadable ? r.with_unreadable(&run) : run.call
        msg, err = s.last_status(rec)
        NxTest.assert_equal(text, msg, name)
        NxTest.assert(err, "#{name}: cervena")
        NxTest.assert_equal([], model.ops, "#{name}: ziadna operacia")
        NxTest.assert_equal(snap0, s.snapshot(model), "#{name}: snapshot nedotknuty")
        NxTest.assert_equal(before, r.files, "#{name}: globál nedotknuty")
        NxTest.assert_equal([], log[:echo], "#{name}: formular ostava")
        if pin
          NxTest.assert_equal([r::HR.library_check[:rev]], s.global_revs(rec), "#{name}: pin obnoveny (neprazdny)")
        else
          NxTest.assert_equal([], s.global_revs(rec), "#{name}: pin sa NEOBNOVUJE, prepis sa neponuka")
        end
      end
    end
  end
end

NxTest.test('H10a T-A2 riadok 2: brana + „aj ako globálnu" — projekt ulozeny, globál nie, veta brany') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  [[:degraded, -> { r.make_degraded }], [:newer, -> { r.make_newer }]].each do |(name, setup)|
    [nil, :omit, 'cudzia'].each do |grev|
      r.with_lib do
        model = s.model
        s.with_dialog(model) do |_log|
          setup.call
          pay = s::RD.rules_payload(model)
          _, reason = r::HR.write_gate
          before = r.files
          form = r.toggled('leg', pay['rules'])
          rec = s.save(model, pay, form, also_global: true, global_rev: grev)
          msg, err = s.last_status(rec)
          NxTest.assert_equal("Pravidlá uložené do projektu — #{reason} — prestavaných 0 skriniek.", msg,
                              "#{name}/#{grev.inspect}")
          NxTest.refute(err, "#{name}: nie konflikt")
          NxTest.refute(msg.include?('iné okno') || msg.include?('predošlej verzie'), 'nie H-PRE ani H-OLD')
          NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model), 'projekt ulozeny')
          NxTest.assert_equal(before, r.files, 'globál nedotknuty')
          NxTest.assert_equal([], s.global_revs(rec), 'pin bez zmeny')
          NxTest.assert_equal([[:start, 'NOXUN: pravidla kovania'], [:commit]], model.ops)
        end
      end
    end
  end
end

NxTest.test('H10a T-A2: bez „aj ako globálnu" nad projektom so snapshotom sa globál vobec necita') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    model = s.model
    s.with_dialog(model) do |_log|
      pay = s::RD.rules_payload(model)
      r.other_write(r.lib_doc(r.toggled('hinge')))
      form = r.toggled('leg', pay['rules'])
      rec = nil
      r.with_unreadable { rec = s.save(model, pay, form, also_global: false, global_rev: :omit) }
      NxTest.assert_equal(['Pravidlá uložené do projektu — prestavaných 0 skriniek.', false], s.last_status(rec),
                          'dnesne znenie, bajtovo')
      NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model))
      NxTest.assert_equal([], s.global_revs(rec))
    end
  end
end

# =============================================================================
# A3 · projekt BEZ snapshotu (preberajuci globál) — oba casovania cache
# =============================================================================

NxTest.test('H10a T-A3: projekt bez snapshotu + cudzi globál -> H-INH pri OBOCH casovaniach cache') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  [['a: cache drzi stary globál', false], ['b: cache uz vidi cudzi', true]].each do |(name, reload)|
    [false, true].each do |also|
      r.with_lib do
        r::HR.write(r::HR::SEED_RULES)
        model = s.model(snapshot: false)
        s.with_dialog(model) do |log|
          pay = s::RD.rules_payload(model)
          NxTest.assert_equal('global', pay['source'])
          NxTest.assert_equal(pay['rules_rev'], pay['global_rev'], 'zdroj global: revizia = odtlacok formulara')
          r::STORE.read(r::HR.path) # nahreta cache
          foreign = r.lib_doc(r.toggled('hinge'))
          r.other_write(foreign)
          r::STORE.reload!(r::HR.path) if reload
          fbytes = r.bytes
          form = r.toggled('leg', pay['rules'])
          rec = s.save(model, pay, form, also_global: also)
          msg, err = s.last_status(rec)
          NxTest.assert_equal(s::RD::GLOBAL_INH_TEXT, msg, "#{name} / also=#{also}")
          NxTest.assert(err)
          NxTest.assert_equal([], model.ops, "#{name}: ziadna operacia")
          NxTest.assert_equal([], log[:echo], "#{name}: ZIADNE echo — formular ostava (FIX 2)")
          NxTest.assert_equal(nil, s.snapshot(model), "#{name}: snapshot sa nezapisal")
          NxTest.assert_equal(fbytes, r.bytes, "#{name}: globál = okno B")
          frev = r::HR.rules_rev(foreign['rules'])
          NxTest.assert_equal([frev], s.global_revs(rec), "#{name}: pin obnoveny")
          # Druhe Ulozit s obnovenym pinom: projekt sa ulozi tak, ako je formular.
          rec2 = s.save(model, pay, form, also_global: also, global_rev: frev)
          NxTest.refute(s.last_status(rec2).last, "#{name}: druhe ulozenie bez chyby (#{s.last_status(rec2).first})")
          NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model), "#{name}: projekt = formular")
          want = also ? r::HR.normalize_rules(form) : foreign['rules']
          NxTest.assert_equal(want, JSON.parse(r.bytes)['rules'], "#{name}: globál #{also ? '= formular' : 'nedotknuty'}")
        end
      end
    end
  end
end

NxTest.test('H10a T-A3: projekt bez snapshotu nad degradovanym globalom — pri zhode sa projekt ulozi, globál nie') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r.make_degraded
    model = s.model(snapshot: false)
    s.with_dialog(model) do |_log|
      pay = s::RD.rules_payload(model)
      _, reason = r::HR.write_gate
      before = r.files
      form = r.toggled('leg', pay['rules'])
      rec = s.save(model, pay, form, also_global: true)
      NxTest.assert_equal(["Pravidlá uložené do projektu — #{reason} — prestavaných 0 skriniek.", false],
                          s.last_status(rec))
      NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model))
      NxTest.assert_equal(before, r.files)
      # Nezhoda pri prebratom globale nad branou = H-INH (obsah je citatelny).
      model2 = s.model(snapshot: false)
      s::RD.rules_payload(model2)
      Object.send(:remove_const, :Sketchup)
      su = Module.new
      su.define_singleton_method(:active_model) { model2 }
      Object.const_set(:Sketchup, su)
      pay2 = s::RD.rules_payload(model2)
      rec2 = s.save(model2, pay2, form, also_global: false, global_rev: 'ina-revizia')
      NxTest.assert_equal(s::RD::GLOBAL_INH_TEXT, s.last_status(rec2).first)
      NxTest.assert_equal([], model2.ops)
    end
  end
end

NxTest.test('H10a T-A3: iny DOKUMENT ostava destruktivne echo (identita bez zmeny)') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    model = s.model(snapshot: false)
    s.with_dialog(model) do |log|
      pay = s::RD.rules_payload(model)
      s::RD.rules_payload(s.model(snapshot: false)) # formular z INEHO dokumentu (baseline)
      rec = s.save(model, pay, r.toggled('leg', pay['rules']), also_global: true)
      msg, err = s.last_status(rec)
      NxTest.assert(msg.start_with?('Aktívny model/pravidlá sa medzitým zmenili — formulár je načítaný nanovo.'), msg)
      NxTest.assert(err)
      NxTest.assert_equal([true], log[:echo], 'echo s vynutenym prekreslenim')
      NxTest.assert_equal([], model.ops)
    end
  end
end

# =============================================================================
# A4 · subeh PO prestavbe (H-RACE)
# =============================================================================

NxTest.test('H10a T-A4: cudzi zapis medzi predkontrolou a zamkom -> H-RACE, projekt ulozeny, cudzi globál zije') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    model = s.model
    s.with_dialog(model) do |log|
      pay = s::RD.rules_payload(model)
      foreign = r.lib_doc(r.toggled('hinge'))
      orig = r::HR.method(:save_library!)
      fired = false
      ops_at_hook = nil
      r::HR.define_singleton_method(:save_library!) do |rules, rev|
        unless fired
          fired = true
          ops_at_hook = model.ops.dup
          NxH10a.other_write(foreign)
        end
        orig.call(rules, rev)
      end
      begin
        form = r.toggled('leg', pay['rules'])
        rec = s.save(model, pay, form, also_global: true)
      ensure
        r::HR.define_singleton_method(:save_library!, orig)
      end
      NxTest.assert(fired, 'hook vystrelil')
      NxTest.assert_equal([[:start, 'NOXUN: pravidla kovania'], [:commit]], ops_at_hook,
                          'globál sa zapisuje AZ PO zavreti operacie prestavby')
      msg, err = s.last_status(rec)
      NxTest.assert_equal("Pravidlá uložené do projektu — prestavaných 0 skriniek. #{s::RD::GLOBAL_RACE_TEXT}", msg)
      NxTest.assert(err, 'cervena')
      NxTest.assert_equal(JSON.pretty_generate(foreign), r.bytes, 'cudzi globál BAJTOVO zachovany')
      NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model), 'novy snapshot = formular')
      NxTest.assert_equal([[:start, 'NOXUN: pravidla kovania'], [:commit]], model.ops, 'jedna operacia')
      frev = r::HR.rules_rev(foreign['rules'])
      NxTest.assert_equal([frev], s.global_revs(rec), 'pin = revizia cudzieho')
      NxTest.assert(rec.index { |x| x.include?('setGlobalRev') } < rec.index { |x| x.include?('setStatus') },
                    'pin ide pred hlaskou')
      NxTest.assert_equal(1, log[:after], 'after_model_write 1x')
      NxTest.assert_equal(frev, s::RD.rules_payload(model)['global_rev'], 'dalsi payload nesie tu istu reviziu')
    end
  end
end

NxTest.test('H10a T-A4: :unreadable a :write_failed po prestavbe — pin bez zmeny, prepis sa neponuka') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  { unreadable: ["Pravidlá uložené do projektu — prestavaných 0 skriniek. #{NxH10aSave::RD::GLOBAL_UNREADABLE_AFTER_TEXT}", true],
    write_failed: ['Pravidlá uložené do projektu (globálny zápis zlyhal!) — prestavaných 0 skriniek.', false] }
    .each do |(status, (text, err))|
    r.with_lib do
      r::HR.write(r::HR::SEED_RULES)
      model = s.model
      s.with_dialog(model) do |_log|
        pay = s::RD.rules_payload(model)
        orig = r::HR.method(:save_library!)
        r::HR.define_singleton_method(:save_library!) { |_r, _v| [status, nil] }
        begin
          rec = s.save(model, pay, r.toggled('leg', pay['rules']), also_global: true)
        ensure
          r::HR.define_singleton_method(:save_library!, orig)
        end
        NxTest.assert_equal([text, err], s.last_status(rec), status.to_s)
        NxTest.assert_equal([], s.global_revs(rec), "#{status}: pin bez zmeny")
      end
    end
  end
end

NxTest.test('H10a T-A4: brana az POD zamkom po prestavbe (:blocked) — veta brany, globál nedotknuty, pin bez zmeny') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r::HR::SEED_RULES)
    model = s.model
    s.with_dialog(model) do |log|
      pay = s::RD.rules_payload(model)
      orig = r::HR.method(:save_library!)
      reason = nil
      before = nil
      r::HR.define_singleton_method(:save_library!) do |rules, rev|
        # Predkontrola prebehla nad zdravym suborom; medzi nou a zamkom sa
        # subor poskodil (degradovany: poskodeny primar + platna zaloha).
        NxH10a.make_degraded
        reason = r::HR.write_gate.last
        before = NxH10a.files
        orig.call(rules, rev)
      end
      begin
        form = r.toggled('leg', pay['rules'])
        rec = s.save(model, pay, form, also_global: true)
      ensure
        r::HR.define_singleton_method(:save_library!, orig)
      end
      NxTest.assert(reason.to_s.include?('poškodené'), "brana pod zamkom (#{reason})")
      NxTest.assert_equal(["Pravidlá uložené do projektu — #{reason} — prestavaných 0 skriniek.", false],
                          s.last_status(rec), 'veta brany, nie konflikt ani „zápis zlyhal"')
      NxTest.assert_equal(before, r.files, 'globalny primar aj .bak nedotknute')
      NxTest.assert_equal(r::HR.normalize_rules(form), s.snapshot(model), 'projekt ulozeny')
      NxTest.assert_equal([], s.global_revs(rec), 'pin bez zmeny, prepis sa neponuka')
      NxTest.assert_equal(1, log[:after])
    end
  end
end

NxTest.test('H10a T-A2: „Načítať globálne" posle pravidla AJ revíziu globalu (pin)') do
  NxTest.skip!('okno Pravidla headless') unless NxTest.headless? && !Object.const_defined?(:Sketchup)
  r = NxH10a
  s = NxH10aSave
  r.with_lib do
    r::HR.write(r.toggled('hinge'))
    model = s.model
    s.with_dialog(model) do |_log|
      rec = []
      s::RD.dispatch('load_global', '', ->(x) { rec << x.to_s })
      line = rec.find { |x| x.start_with?('RD.setRules(') }
      NxTest.assert(line, 'formular dostal globál')
      NxTest.assert_equal([r::HR.library_check[:rev]], s.global_revs(rec), 'pin = revizia nacitaneho globalu')
      NxTest.assert(line.index('RD.setRules(') < line.index('RD.setGlobalRev('), 'v jednom skripte, za pravidlami')
      NxTest.assert(line.include?('if (window.RD && RD.setGlobalRev)'), 'guard pre DOM bez prijimaca')
      NxTest.assert_equal([], model.ops, 'nacitanie nic nezapisuje do modelu')
    end
  end
end

# =============================================================================
# A5 · strukturalne guardy zdroja
# =============================================================================

NxTest.test('H10a T-A5: poradie v `handle_save` — stav baseline, identita, revizie, predkontrola, prestavba, globál') do
  b = NxH10a.body('ui/rules_dialog.rb', 'handle_save', 8)
  idx = ->(s) { b.index(s) || raise("#{s} chyba v handle_save") }
  NxTest.assert(idx.call('baseline_state(model)') < idx.call('DocKey.foreign?'), 'stav baseline pred identitou z payloadu')
  NxTest.assert(idx.call('DocKey.foreign?') < idx.call("data['rules_rev']"), 'identita pred odtlackom projektu')
  NxTest.assert(idx.call('HardwareRules.rules_problems(rules)') < idx.call('global_precheck('),
                'predkontrola AZ za validaciou pravidiel')
  NxTest.assert(idx.call('global_precheck(') < idx.call('rebuild_many'), 'predkontrola PRED prestavbou')
  NxTest.assert(idx.call('rebuild_many') < idx.call('HardwareRules.save_library!'), 'globál AZ PO prestavbe')
  NxTest.assert(b.include?('case status'), 'vysledok zapisu cez `case`, nie pravdivost')
  NxTest.refute(b.include?('if HardwareRules.save_library!'), 'nikdy `if save_library!` (pole je pravdive)')
  NxTest.assert(b.include?('HardwareRules.write_block_reason'), 'R-11: dovod brany z modulu')
  NxTest.refute(NxH10a.src('ui/rules_dialog.rb').include?('HardwareRules.write('),
                'okno uz nevola uplnu nahradu bez revizie')
  pre = NxH10a.body('ui/rules_dialog.rb', 'global_precheck', 8)
  order = ['library_check(fresh: true)', ':unreadable', ':blocked && !inherits', "data.key?('global_rev')",
           'pin.empty?', "pin != c[:rev]"].map { |s| pre.index(s) }
  NxTest.assert(order.none?(&:nil?) && order == order.sort, "poradie riadkov predkontroly R1.4 (#{order.inspect})")
  state = NxH10a.body('ui/rules_dialog.rb', 'baseline_state', 8)
  NxTest.assert(state.index(':inherits_global') < state.index('HardwareRules.load'),
                'prebraty globál sa NEPOROVNAVA cez cachovany `load` (FIX 2)')
end

NxTest.test('H10a T-A5 (R-08): revizia globalu sa porovnava AZ POD zamkom nad cerstvym suborom') do
  b = NxH10a.body('core/hardware_rules.rb', 'save_library!', 6)
  lock = b.index('with_catalog_lock')
  check = b.index('library_check(fresh: true)')
  cmp = b.index('revision.to_s != c[:rev]')
  NxTest.assert(lock && check && cmp, 'zamok, cerstve citanie aj porovnanie su v tele')
  NxTest.assert(lock < check && check < cmp, 'porovnanie AZ pod zamkom a AZ po cerstvom citani')
  NxTest.assert(b.index(':blocked') < cmp, 'brana ma prednost pred konfliktom (D10)')
  NxTest.assert(b.include?('write(rules)') && !b.include?('JsonFileStore.write('),
                'zapis ide cez `write` (jedine miesto zapisu, guard R-08)')
  NxTest.refute(b[/rescue StandardError.*\z/m].to_s.include?(':ok'), 'rescue nehlasi uspech')
  chk = NxH10a.body('core/hardware_rules.rb', 'library_check', 6)
  NxTest.assert(chk.index('JsonFileStore.reload!(path) if fresh') < chk.index('library_content_rev'),
                'cerstvy check zhodi cache pred citanim')
  NxTest.assert(chk.include?('write_gate'), 'brana je JEDNA autorita (H9 R15)')
  NxTest.refute(chk.include?('ensure_seeded') || chk.include?('persist_seed_merge!'), 'check nezapisuje')
end
