# frozen_string_literal: true
# H13 (blok 9 HARDENING, krizovy audit V1 B-06/B-07; CN-02, CN-03, CN-04) —
# MAPA ROZSIROVACICH BODOV a JEDNA TABULKA VERZII DAT nesmu zastarat potichu.
#
# CO PLATI:
#   * `docs/architecture/rozsirovacie-body.md`: kazdy riadok tabulky, ktory
#     zacina cestou v spatnych apostrofoch, menuje EXISTUJUCI subor a KAZDE meno
#     z druheho stlpca v nom je (cele slovo; meno s `::`/`.`/`#` po castiach,
#     meno s medzerou alebo pomlckou ako doslovny text) — premenovany alebo
#     zruseny register zhodi test, nie agenta o pol roka;
#   * pasca zavesov CN-03: kazdy VISIACI typ registra (`hang_z > 0`) je v
#     `applies_to.cabinet_type` seed pravidla zavesov, alebo vo vynimkach s
#     dovodom; pravidlo zavesov neplati na typ, ktory nevisi (presunute sem
#     z H12a T3c a rozsirene o vynimky);
#   * `SYSTEM/STANDARD.md` §13: hodnota kazdeho riadku = konstanta v kode a
#     KAZDA ciselna konstanta verzie v `noxun_engine/` je v tabulke (kroky
#     historie `SCHEMA_*` modulu so `SCHEMA_CURRENT` su vynimka, test overi,
#     ze `SCHEMA_CURRENT` ukazuje na najvyssi krok).
#
# Vsetky tri guardy su CISTE funkcie nad textom/datami — negativne testy nizsie
# ich spustaju nad umyselne pokazenymi kopiami (zly subor, chybajuce meno,
# visiaci typ bez zavesov, stara hodnota, chybajuca konstanta).
require_relative '../helper' unless defined?(NxTest)

NX_H13_MAP = File.join('docs', 'architecture', 'rozsirovacie-body.md')
NX_H13_STANDARD = File.join('SYSTEM', 'STANDARD.md')
NX_H13_SCENARIOS = [
  '## 1 · Nový typ skrinky',
  '## 2 · Nová rola dielca',
  '## 3 · Nový stĺpec Kusovníka',
  '## 4 · Nová sekcia Štúdia',
  '## 5 · Nové pravidlo kovania viazané na typ skrinky'
].freeze

# CN-03: seed pravidla, ktore vydavaju ZAVESY na stenu, a vynimky (id typu =>
# dovod), ktore zavesy z tohto pravidla vedome nedostanu (napr. typ s vlastnym
# pravidlom zavesov). Prazdny dovod je chyba — vynimka bez dovodu je zabudnutie.
NX_H13_HANG_RULES = %w[zavesenie-hornej-skrinky].freeze
NX_H13_HANG_EXCEPTIONS = {}.freeze

def nx_h13_src(rel)
  File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
end

def nx_h13_cells(line)
  line.strip.sub(/\A\|/, '').sub(/\|\z/, '').split('|').map(&:strip)
end

def nx_h13_ticks(text)
  text.to_s.scan(/`([^`]+)`/).flatten
end

# --- B-06 / CN-02: mapa rozsirovacich bodov -----------------------------------

# Riadky tabuliek mapy, ktore sa kontroluju: prva bunka = PRAVE JEDNA cesta
# v spatnych apostrofoch (obsahuje `/` a priponu). Vrati [sekcia, cesta, mena].
def nx_h13_map_rows(lines)
  section = nil
  lines.each_with_object([]) do |line, out|
    section = line.strip if line.start_with?('## ')
    next unless line.start_with?('|')

    cells = nx_h13_cells(line)
    next if cells.length < 2

    path = nx_h13_ticks(cells[0])
    next unless path.length == 1 && cells[0].strip == "`#{path[0]}`" && path[0].match?(%r{/.+\.\w+\z})

    out << [section, path[0], nx_h13_ticks(cells[1])]
  end
end

# Meno ako identifikator (aj `Modul::KONST`, `Modul.metoda`, `metoda!`); ostatne
# (pomlcka, medzera) sa hladaju doslovne.
NX_H13_IDENT = /\A[A-Za-z_]\w*[?!]?(?:(?:::|\.)[A-Za-z_]\w*[?!]?)*\z/.freeze
# Obalove moduly pluginu — nerozlisuju register (kazdy subor ich ma).
NX_H13_WRAPPERS = %w[Noxun Engine].freeze

def nx_h13_word?(word, src)
  src.match?(/(?<![\w])#{Regexp.escape(word)}(?![\w?!])/)
end

# Moduly a triedy, ktore subor deklaruje (bez obalovych).
def nx_h13_modules(src)
  src.scan(/^\s*(?:module|class)\s+([A-Z]\w*)/).flatten.uniq - NX_H13_WRAPPERS
end

# Telo modulu `mod` v Ruby zdroji: od riadku `module mod` po prvy `end`
# s ROVNAKYM odsadenim (kod pluginu je dosledne odsadeny). nil = subor ho nema.
def nx_h13_scope(src, mod)
  lines = src.lines
  start = lines.index { |l| l.match?(/^\s*(?:module|class)\s+#{Regexp.escape(mod)}\b/) }
  return nil if start.nil?

  indent = lines[start][/\A\s*/]
  stop = ((start + 1)...lines.length).find { |i| lines[i].match?(/\A#{indent}end\b/) }
  lines[start..(stop || -1)].join
end

# Kvalifikovane meno (`Modul::CLEN`, `Modul.metoda`) sa overuje v ROZSAHU
# modulu — clen rovnakeho mena v inom module toho isteho suboru nestaci
# (review #449: `TemplateStore::STD` vs `TemplateUsage::STD`). Subor, ktory
# modul nedeklaruje (test, JS), musi obsahovat cely zapis doslovne.
def nx_h13_name_in?(name, src)
  return src.include?(name) unless name.match?(NX_H13_IDENT)

  segs = name.split(/::|\./)
  return nx_h13_word?(segs[0], src) if segs.length == 1

  scope = nx_h13_scope(src, segs[-2])
  return src.include?(name) if scope.nil?

  nx_h13_word?(segs[-1], scope)
end

# Problemy mapy: cesta neexistuje, riadok bez mien, meno v subore nie je,
# holé meno clena v Ruby subore s viacerymi modulmi (nejednoznacne).
# `reader` vrati obsah suboru alebo nil (negativne testy ho podvrhnu).
def nx_h13_map_problems(rows, reader)
  rows.each_with_object([]) do |(section, path, names), out|
    src = reader.call(path)
    if src.nil?
      out << "#{section}: subor #{path} neexistuje"
      next
    end
    out << "#{section}: riadok #{path} nemenuje ziadne meno" if names.empty?
    mods = path.end_with?('.rb') ? nx_h13_modules(src) : []
    names.each do |n|
      out << "#{section}: #{path} nema `#{n}`" unless nx_h13_name_in?(n, src)
      next unless mods.length > 1 && n.match?(NX_H13_IDENT) && !n.match?(/::|\./) && !mods.include?(n)

      out << "#{section}: #{path} ma moduly #{mods.join('/')} — meno `#{n}` kvalifikuj (`Modul::#{n}`)"
    end
  end
end

# Mena, ktore scenar MUSI menovat (nie su len nahodou v nejakom riadku):
# pasca zavesov a skutocne miesta vykreslenia sekcie Studia (review #449).
NX_H13_REQUIRED = {
  '## 1 · Nový typ skrinky' => %w[zavesenie-hornej-skrinky CabinetTypes::REGISTRY NX_H13_HANG_EXCEPTIONS],
  '## 4 · Nová sekcia Štúdia' => %w[StudioDialog::SECTIONS SEC_META renderHead renderTools renderBody ssRenderBody]
}.freeze

def nx_h13_required_missing(rows)
  NX_H13_REQUIRED.flat_map do |sec, names|
    have = rows.select { |r| r[0] == sec }.flat_map { |r| r[2] }
    (names - have).map { |n| "#{sec}: chyba `#{n}`" }
  end
end

def nx_h13_repo_reader
  lambda do |rel|
    full = File.join(NxTest::ROOT, rel)
    File.file?(full) ? File.read(full, encoding: 'UTF-8') : nil
  end
end

NxTest.test('H13 B-06: mapa rozsirovacich bodov ma vsetkych 5 scenarov a v kazdom strazene riadky') do
  lines = nx_h13_src(NX_H13_MAP).lines.map(&:rstrip)
  heads = lines.select { |l| l.start_with?('## ') }
  missing = NX_H13_SCENARIOS.reject { |h| heads.include?(h) }
  NxTest.assert(missing.empty?, "mapa nema scenare: #{missing.join(' · ')}")
  rows = nx_h13_map_rows(lines)
  NxTest.assert(rows.length > 40, "mapa ma len #{rows.length} strazenych riadkov — zmenil sa tvar tabuliek?")
  NX_H13_SCENARIOS.each do |h|
    n = rows.count { |r| r[0] == h }
    NxTest.assert(n >= 4, "scenar '#{h}' ma len #{n} strazenych riadkov (subor + mena)")
  end
  missing_names = nx_h13_required_missing(rows)
  NxTest.assert(missing_names.empty?, "mapa vynechala povinne mena: #{missing_names.join(' · ')}")
end

NxTest.test('H13 B-06: kazdy register menovany v mape v kode existuje (subor + mena)') do
  rows = nx_h13_map_rows(nx_h13_src(NX_H13_MAP).lines.map(&:rstrip))
  problems = nx_h13_map_problems(rows, nx_h13_repo_reader)
  NxTest.assert(problems.empty?,
                "Mapa rozsirovacich bodov zastarala: #{problems.first(12).join(' · ')} — dávka, ktora register " \
                "premenovala alebo zrusila, opravi jeho riadok v #{NX_H13_MAP} (nie cisla riadkov, len mena)")
end

NxTest.test('H13 B-06: guard mapy chyti zly subor, chybajuce meno a prazdny riadok; nehlasi falosne') do
  doc = ["## 1 · X", '| Súbor | Mená | Čo |', '|---|---|---|',
         '| `a/real.rb` | `Mod::KONST` · `ok?` · `zavesenie-hornej` · `H12a T3` | text `nie/je.rb` |',
         '| text `a/real.rb` | `Nic` | prva bunka nie je cista cesta — riadok sa nekontroluje |']
  fake = { 'a/real.rb' => "module Mod\n  KONST = 1\n  def ok?; end\n  # zavesenie-hornej H12a T3\nend\n" }
  reader = ->(p) { fake[p] }
  rows = nx_h13_map_rows(doc)
  NxTest.assert_equal([['## 1 · X', 'a/real.rb', ['Mod::KONST', 'ok?', 'zavesenie-hornej', 'H12a T3']]], rows)
  NxTest.assert_equal([], nx_h13_map_problems(rows, reader), 'falosny poplach')
  bad = { 'zly subor' => doc[3].sub('a/real.rb', 'a/zly.rb'),
          'chybajuce meno' => doc[3].sub('`ok?`', '`ok_nie?`'),
          'cast mena' => doc[3].sub('Mod::KONST', 'Mod::KONST_X'),
          'doslovny text' => doc[3].sub('zavesenie-hornej', 'zavesenie-dolnej'),
          'prazdny riadok' => '| `a/real.rb` | bez mien | text |' }
  bad.each do |why, line|
    probs = nx_h13_map_problems(nx_h13_map_rows(doc[0..2] + [line]), reader)
    NxTest.refute(probs.empty?, "guard mapy nezachytil: #{why}")
  end
  NxTest.refute(nx_h13_name_in?('KONST', 'KONSTANTA = 1'), 'cast slova nie je cele slovo')
end

# Review #449 P2: kvalifikovane meno sa overuje v rozsahu SVOJHO modulu.
NxTest.test('H13 B-06: Modul::CLEN plati len v rozsahu modulu; hole meno v subore s viacerymi modulmi neprejde') do
  two = "module Noxun\n  module Engine\n    module TemplateStore\n      STD = 7\n      def migrate!; end\n    end\n" \
        "    module TemplateUsage\n      STD = 1\n    end\n  end\nend\n"
  NxTest.assert(nx_h13_name_in?('TemplateStore::STD', two))
  NxTest.assert(nx_h13_name_in?('TemplateStore.migrate!', two))
  NxTest.assert(nx_h13_name_in?('TemplateUsage::STD', two))
  gone = two.sub("      STD = 7\n", '')
  NxTest.refute(nx_h13_name_in?('TemplateStore::STD', gone), 'zmazane TemplateStore::STD preslo vdaka TemplateUsage::STD')
  NxTest.refute(nx_h13_name_in?('TemplateUsage.migrate!', two), 'metoda ineho modulu presla')
  NxTest.assert(nx_h13_name_in?('BuildPlan::ROLES', 'x = e::BuildPlan::ROLES'), 'nedeklarovany modul = doslovny odkaz')
  NxTest.refute(nx_h13_name_in?('BuildPlan::ROLES', 'BuildPlan; ROLES'), 'nedeklarovany modul po castiach nestaci')
  reader = ->(p) { { 'x/t.rb' => two, 'x/g.rb' => gone }[p] }
  doc = ['## 1 · X', '| Súbor | Mená | Čo |', '|---|---|---|']
  NxTest.assert_equal([], nx_h13_map_problems(nx_h13_map_rows(doc + ['| `x/t.rb` | `TemplateStore::STD` · `TemplateUsage` | a |']), reader))
  NxTest.refute(nx_h13_map_problems(nx_h13_map_rows(doc + ['| `x/g.rb` | `TemplateStore::STD` | a |']), reader).empty?)
  NxTest.refute(nx_h13_map_problems(nx_h13_map_rows(doc + ['| `x/t.rb` | `STD` | a |']), reader).empty?, 'hole STD v subore s 2 modulmi preslo')
  rows = [['## 4 · Nová sekcia Štúdia', 'x', %w[StudioDialog::SECTIONS SEC_META renderHead renderTools ssRenderBody]]]
  NxTest.assert(nx_h13_required_missing(rows).include?('## 4 · Nová sekcia Štúdia: chyba `renderBody`'), 'chybajuci renderBody presiel')
end

# --- CN-03: pasca zavesov ------------------------------------------------------

def nx_h13_hang_problems(hanging:, known:, seed_rules:, hang_rules:, exceptions:)
  problems = []
  found = seed_rules.select { |r| hang_rules.include?(r['rule_id']) }
  (hang_rules - found.map { |r| r['rule_id'] }).each { |id| problems << "seed pravidlo zavesov #{id} chyba" }
  covered = found.flat_map { |r| Array((r['applies_to'] || {})['cabinet_type']).map(&:to_s) }.uniq
  (hanging - covered).each do |id|
    next if exceptions.key?(id)

    problems << "VISIACI typ #{id} (hang_z > 0) nema zavesy: dopln ho do `applies_to.cabinet_type` pravidla " \
                "#{hang_rules.join('/')}, zvys HardwareRules::SEED_VERSION a v projektoch 'Doplniť nové predvoľby' " \
                '(alebo vynimka s dovodom v NX_H13_HANG_EXCEPTIONS)'
  end
  (covered - hanging).each { |id| problems << "pravidlo zavesov plati na typ #{id}, ktory nevisi (hang_z 0)" }
  exceptions.each do |id, why|
    problems << "vynimka #{id} nema dovod" if why.to_s.strip.empty?
    problems << "vynimka #{id} nie je visiaci typ registra (zastarala)" unless hanging.include?(id)
    problems << "vynimka #{id} je zaroven v pravidle zavesov" if covered.include?(id)
  end
  seed_rules.each do |r|
    Array((r['applies_to'] || {})['cabinet_type']).each do |t|
      problems << "seed pravidlo #{r['rule_id']} filtruje neznamy typ #{t}" unless known.include?(t.to_s)
    end
  end
  problems
end

def nx_h13_hang_input
  ct = Noxun::Engine::CabinetTypes
  { hanging: ct::IDS.select { |id| ct.hangs?(id) }, known: ct::IDS,
    seed_rules: Noxun::Engine::HardwareRules::SEED_RULES, hang_rules: NX_H13_HANG_RULES,
    exceptions: NX_H13_HANG_EXCEPTIONS }
end

NxTest.test('H13 CN-03: kazdy visiaci typ registra ma zavesy zo seedu (alebo vynimku s dovodom)') do
  input = nx_h13_hang_input
  NxTest.assert(input[:hanging].include?('upper'), 'register nema ani jeden visiaci typ — zmenil sa `hang_z`?')
  problems = nx_h13_hang_problems(**input)
  NxTest.assert(problems.empty?, "Pasca zavesov CN-03: #{problems.join(' · ')}")
end

NxTest.test('H13 CN-03: guard zavesov chyti novy visiaci typ, zly filter a zlu vynimku') do
  base = nx_h13_hang_input
  rules = base[:seed_rules].map { |r| JSON.parse(JSON.generate(r)) }
  known = base[:known] + ['upper_corner']
  # novy visiaci typ bez seedu
  probs = nx_h13_hang_problems(**base, known: known, hanging: base[:hanging] + ['upper_corner'])
  NxTest.assert(probs.any? { |p| p.include?('upper_corner') && p.include?('SEED_VERSION') }, 'novy visiaci typ presiel')
  # ten isty typ s vynimkou s dovodom prejde, bez dovodu nie
  NxTest.assert_equal([], nx_h13_hang_problems(**base, known: known, hanging: base[:hanging] + ['upper_corner'],
                                               exceptions: { 'upper_corner' => 'vlastne pravidlo zavesov' }))
  NxTest.refute(nx_h13_hang_problems(**base, known: known, hanging: base[:hanging] + ['upper_corner'],
                                     exceptions: { 'upper_corner' => ' ' }).empty?, 'vynimka bez dovodu presla')
  # zastarala vynimka (typ nevisi)
  NxTest.refute(nx_h13_hang_problems(**base, exceptions: { 'lower' => 'x' }).empty?, 'zastarala vynimka presla')
  # pravidlo zavesov na stojaci typ
  hang = rules.find { |r| r['rule_id'] == NX_H13_HANG_RULES.first }
  hang['applies_to']['cabinet_type'] = %w[upper lower]
  NxTest.refute(nx_h13_hang_problems(**base, seed_rules: rules).empty?, 'zavesy na dolnej presli')
  # chybajuce pravidlo zavesov a neznamy typ vo filtri
  NxTest.refute(nx_h13_hang_problems(**base, seed_rules: rules.reject { |r| r.equal?(hang) }).empty?, 'chybajuce pravidlo preslo')
  hang['applies_to']['cabinet_type'] = %w[upper tall]
  NxTest.assert(nx_h13_hang_problems(**base, seed_rules: rules).any? { |p| p.include?('neznamy typ tall') }, 'neznamy typ presiel')
end

# --- B-07 / CN-04: jedna tabulka verzii dat ------------------------------------

NX_H13_VERSION_NAME = /SCHEMA|STD|SEED|VERSION/.freeze
NX_H13_CONST_LINE = /\A\s*([A-Z][A-Z0-9_]*)\s*=\s*(\d+|[A-Z][A-Z0-9_]*)\s*(?:#.*)?\s*\z/.freeze
# Ciselne konstanty s menom verzie, ktore verziou dat NIE SU (meno => dovod).
NX_H13_NOT_VERSIONS = {
  'Updater::VERSION_HEAD_BYTES' => 'pocet bajtov hlavicky suboru, v ktorych updater hlada VERSION pluginu'
}.freeze

# Sekcia §13 STANDARDU (po dalsi nadpis `## `).
def nx_h13_section13(text)
  text[/^## 13\. .*?(?=^## (?!13\.)|\z)/m].to_s
end

# Riadky tabuliek §13: [cesta, 'Modul::KONST', hodnota]. Stlpec hodnoty sa
# hlada podla hlavicky „Hodnota" kazdej tabulky; vrati aj chyby tvaru riadkov.
def nx_h13_version_rows(section)
  rows = []
  errs = []
  val_idx = nil
  section.lines.map(&:rstrip).each do |line|
    unless line.start_with?('|')
      val_idx = nil
      next
    end
    cells = nx_h13_cells(line)
    if val_idx.nil?
      val_idx = cells.index('Hodnota')
      errs << "tabulka bez stlpca Hodnota: #{line[0, 60]}" if val_idx.nil?
      val_idx ||= -1
      next
    end
    next if cells.all? { |c| c.match?(/\A:?-+:?\z/) } || val_idx.negative?

    ticks = nx_h13_ticks(cells[1])
    path = ticks.find { |t| t.include?('/') }
    consts = ticks.select { |t| t.include?('::') }
    value = cells[val_idx].to_s[/\d+/]
    if path.nil? || consts.length != 1 || value.nil?
      errs << "riadok bez cesty, s inym poctom konstant nez 1 alebo bez hodnoty: #{line[0, 80]}"
      next
    end
    rows << [path, consts.first, value.to_i]
  end
  [rows, errs]
end

# Hodnota konstanty `Modul::KONST` v zdroji: prvy zapis `KONST =` za riadkom
# `module <posledny segment modulu>`; odkaz na inu konstantu sa dohlada v tom
# istom module (napr. SCHEMA_CURRENT = SCHEMA_MANUAL_CHECK).
def nx_h13_const_value(src, qualified, depth = 0)
  *mods, name = qualified.split('::')
  lines = src.lines
  start = mods.empty? ? 0 : lines.index { |l| l.match?(/\A\s*module #{Regexp.escape(mods.last)}\b/) }
  return nil if start.nil? || depth > 3

  lines[start..].each do |l|
    m = l.match(NX_H13_CONST_LINE)
    next unless m && m[1] == name

    return m[2].match?(/\A\d+\z/) ? m[2].to_i : nx_h13_const_value(src, "#{mods.join('::')}::#{m[2]}", depth + 1)
  end
  nil
end

# Inventar ciselnych konstant verzii v zdrojoch: { 'subor' => [[Modul, KONST]] }
# (modul = najblizsi predchadzajuci riadok `module X`).
def nx_h13_version_consts(files)
  files.each_with_object({}) do |(rel, src), out|
    mod = nil
    src.lines.each do |l|
      if (m = l.match(/\A\s*module (\w+)/))
        mod = m[1]
        next
      end
      m = l.match(NX_H13_CONST_LINE)
      next unless m && m[1].match?(NX_H13_VERSION_NAME)
      # Odkaz na inu konstantu sa pocita len vtedy, ked vedie k cislu
      # (`SCHEMA_CURRENT = SCHEMA_X` ano, `SEED_PATCH_V4_ADD = SEED_AVENTOS_V4` nie).
      next unless nx_h13_const_value(src, "#{mod}::#{m[1]}").is_a?(Integer)

      (out[rel] ||= []) << [mod, m[1]]
    end
  end
end

# Problemy tabulky: hodnota nesedi, konstanta v kode chyba v tabulke, krok
# historie mimo SCHEMA_CURRENT. `files` = { cesta => zdroj }.
def nx_h13_version_problems(section, files, not_versions = NX_H13_NOT_VERSIONS)
  rows, problems = nx_h13_version_rows(section)
  rows.each do |path, const, value|
    src = files[path]
    next problems << "§13: subor #{path} neexistuje" if src.nil?

    have = nx_h13_const_value(src, const)
    problems << "§13: #{const} v #{path} nenajdena" if have.nil?
    problems << "§13: #{const} = #{have} v kode, tabulka hovori #{value}" if have && have != value
  end
  listed = rows.map { |p, c, _| [p, c.split('::').last(2).join('::')] }
  inventory = nx_h13_version_consts(files)
  seen = inventory.values.flatten(1).map { |m, n| "#{m}::#{n}" }
  not_versions.each_key { |k| problems << "§13: vynimka #{k} uz v kode nie je (zmaz ju)" unless seen.include?(k) }
  inventory.each do |path, consts|
    with_current = consts.select { |_, n| n == 'SCHEMA_CURRENT' }.map(&:first)
    consts.each do |mod, name|
      if name.start_with?('SCHEMA_') && name != 'SCHEMA_CURRENT' && with_current.include?(mod)
        next
      end
      next if listed.include?([path, "#{mod}::#{name}"]) || not_versions.key?("#{mod}::#{name}")

      problems << "§13: konstanta #{mod}::#{name} (#{path}) nie je v tabulke"
    end
    with_current.each do |mod|
      steps = consts.select { |m, n| m == mod && n.start_with?('SCHEMA_') && n != 'SCHEMA_CURRENT' }
                    .map { |_, n| nx_h13_const_value(files[path], "#{mod}::#{n}") }
      cur = nx_h13_const_value(files[path], "#{mod}::SCHEMA_CURRENT")
      problems << "§13: #{mod}::SCHEMA_CURRENT = #{cur}, najvyssi krok #{steps.max}" if steps.any? && cur != steps.max
    end
  end
  problems
end

def nx_h13_plugin_files
  root = NxTest::ROOT.to_s.tr('\\', '/').chomp('/')
  Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')).sort.to_h do |p|
    [p.tr('\\', '/').sub("#{root}/", ''), File.read(p, encoding: 'UTF-8')]
  end
end

NxTest.test('H13 B-07: STANDARD §13 = konstanty verzii v kode (hodnoty aj uplnost)') do
  section = nx_h13_section13(nx_h13_src(NX_H13_STANDARD))
  NxTest.refute(section.empty?, 'STANDARD.md nema sekciu ## 13. (tabulka verzii dat)')
  rows, = nx_h13_version_rows(section)
  NxTest.assert(rows.length > 30, "§13 ma len #{rows.length} riadkov — zmenil sa tvar tabuliek?")
  %w[CabinetBuilder::CONFIG_SCHEMA BuildPlan::SCHEMA TemplateStore::STD BudgetStore::BUDGET_STD
     AbsRules::SEED_VERSION HardwareRules::SEED_VERSION Materials::SCHEMA_CURRENT Store::STD].each do |c|
    NxTest.assert(rows.any? { |_, k, _| k == c }, "§13 nema riadok #{c}")
  end
  problems = nx_h13_version_problems(section, nx_h13_plugin_files)
  NxTest.assert(problems.empty?,
                "Tabulka verzii dat nesedi s kodom: #{problems.first(12).join(' · ')} — dávka, ktora verziu zvysila " \
                'alebo pridala, prepise riadok v SYSTEM/STANDARD.md §13 (historia ide do komentara HISTORIA pri konstante)')
end

NxTest.test('H13 B-07: guard tabulky verzii chyti staru hodnotu, chybajucu konstantu a zly krok historie') do
  src = "module Noxun\n  module Engine\n    module Foo\n      STD = 2\n      SCHEMA_A = 1\n      SCHEMA_B = 2\n" \
        "      SCHEMA_CURRENT = SCHEMA_B\n    end\n    module Bar\n      STD = 5 # format\n      SEED_VERSION = 3\n" \
        "    end\n  end\nend\n"
  files = { 'x/foo.rb' => src }
  sec = "## 13. Verzie\n\n| Čo | Kde | Hodnota | Kedy |\n|---|---|---|---|\n" \
        "| a | `x/foo.rb` · `Foo::STD` | **2** | k |\n| b | `x/foo.rb` · `Foo::SCHEMA_CURRENT` | **2** | k |\n" \
        "| c | `x/foo.rb` · `Bar::STD` | **5** | k |\n| d | `x/foo.rb` · `Bar::SEED_VERSION` | **3** | k |\n"
  NxTest.assert_equal([], nx_h13_version_problems(sec, files, {}), 'falosny poplach')
  NxTest.assert_equal(5, nx_h13_const_value(src, 'Bar::STD'), 'STD v druhom module tej istej suboru')
  NxTest.assert_equal(2, nx_h13_const_value(src, 'Foo::SCHEMA_CURRENT'), 'odkaz na krok')
  NxTest.refute(nx_h13_version_problems(sec.sub('| **3** |', '| **2** |'), files, {}).empty?, 'stara hodnota presla')
  NxTest.refute(nx_h13_version_problems(sec.sub(/^\| d .*\n/, ''), files, {}).empty?, 'chybajuca konstanta presla')
  bumped = { 'x/foo.rb' => src.sub("      SCHEMA_CURRENT = SCHEMA_B\n", "      SCHEMA_C = 3\n      SCHEMA_CURRENT = SCHEMA_B\n") }
  NxTest.assert(nx_h13_version_problems(sec, bumped, {}).any? { |p| p.include?('najvyssi krok 3') }, 'SCHEMA_CURRENT za krokom presiel')
  NxTest.refute(nx_h13_version_problems(sec.sub('`Foo::STD`', 'Foo::STD'), files, {}).empty?, 'riadok bez konstanty presiel')
  NxTest.refute(nx_h13_version_problems(sec.sub('x/foo.rb` · `Bar::STD', 'x/nie.rb` · `Bar::STD'), files, {}).empty?,
                'neexistujuci subor presiel')
  NxTest.refute(nx_h13_version_problems(sec.sub('| Hodnota |', '| Cislo |'), files, {}).empty?, 'tabulka bez stlpca Hodnota presla')
  NxTest.assert_equal([], nx_h13_version_problems(sec.sub(/^\| d .*\n/, ''), files, { 'Bar::SEED_VERSION' => 'test' }),
                      'vynimka s dovodom ma konstantu z tabulky ospravedlnit')
  NxTest.refute(nx_h13_version_problems(sec, files, { 'Foo::NIC' => 'x' }).empty?, 'zastarala vynimka presla')
  ref = { 'x/foo.rb' => src.sub("    end\n  end\nend\n", "      SEED_LIST = SEED_ARR\n      SEED_ARR = [1].freeze\n    end\n  end\nend\n") }
  NxTest.assert_equal([], nx_h13_version_problems(sec, ref, {}), 'odkaz na necislo (pole) nie je verzia')
end

# STAV „Kompatibilita" a §2.5 na tabulku len odkazuju — jedno miesto s cislami.
NxTest.test('H13 B-07: STAV a mapa odkazuju na STANDARD §13') do
  NxTest.assert(nx_h13_src(File.join('SYSTEM', 'STAV.md')).include?('STANDARD.md#13'), 'STAV „Kompatibilita" neodkazuje na STANDARD §13')
  NxTest.assert(nx_h13_src(NX_H13_MAP).include?('STANDARD.md') && nx_h13_src(NX_H13_MAP).include?('§13'),
                'mapa rozsirovacich bodov neodkazuje na STANDARD §13')
end
