# frozen_string_literal: true
# Guard registra agentov (26.9.2026, rozhodnutie Z9 — vetva feat/register-agentov): typy subagentov projektu
# v .claude/agents/*.md. Orchestrator vybera typ podla `description`; model a effort su
# v definicii. Chybny frontmatter Claude Code typ NENACITA a agent potichu zmizne zo zoznamu
# (napr. neuvodzovkovany popis s dvojbodkou a medzerou je neplatny YAML).
# Guard kontroluje VYHRADNE STRUKTURU: platny YAML frontmatter, name = nazov suboru
# a unikatny, neprazdny description a model, model/effort z dokumentovanych hodnot
# (code.claude.com/docs/en/sub-agents) a kazdy typ zapisany v SYSTEM/WORKFLOW.md
# (tabulka Obsadenie roli je jedina mapa — typ mimo nej by orchestrator nepoznal).
# ZNENIE popisov sa nekontroluje.
require_relative '../helper' unless defined?(NxTest)

NX_AGENTS_DIR = File.join(NxTest::ROOT, '.claude', 'agents')
# Alias alebo plne ID modelu (claude-...). `inherit` = model hlavnej konverzacie.
NX_AGENT_MODELS = %w[opus sonnet haiku fable inherit].freeze
NX_AGENT_MODEL_ID = /\Aclaude-[a-z0-9.-]+\z/.freeze
NX_AGENT_EFFORTS = %w[low medium high xhigh max].freeze
# Male pismena, cislice, pomlcky; dvojbodka je rezervovana pre typy pluginov (plugin:typ).
NX_AGENT_NAME = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
# Docs: sucet popisov nad 15 000 tokenov = varovanie; popis je vyberove kriterium, nie navod.
NX_AGENT_DESC_MAX = 1024

def nx_agent_files
  Dir[File.join(NX_AGENTS_DIR, '**', '*.md')].sort
end

# Frontmatter ako Hash; nil = subor nema blok `---` na zaciatku.
def nx_agent_frontmatter(path)
  text = File.read(path, encoding: 'UTF-8')
  m = text.match(/\A---\r?\n(.*?)\r?\n---\r?\n/m)
  return nil unless m

  YAML.safe_load(m[1])
end

def nx_agent_yaml!
  require 'yaml'
rescue LoadError
  NxTest.skip!('YAML (psych) nie je v tomto Ruby dostupne')
end

NxTest.test('agenti: .claude/agents ma aspon jeden typ subagenta') do
  NxTest.assert(Dir.exist?(NX_AGENTS_DIR), '.claude/agents chyba — register agentov zmizol')
  NxTest.assert(!nx_agent_files.empty?, '.claude/agents nema ziadnu definiciu *.md')
end

NxTest.test('agenti: frontmatter je platny YAML s name = nazov suboru, description a model') do
  nx_agent_yaml!
  bad = []
  nx_agent_files.each do |path|
    rel = path.sub("#{NxTest::ROOT}/", '')
    begin
      fm = nx_agent_frontmatter(path)
    rescue StandardError => e
      bad << "#{rel}: neplatny YAML frontmatter (#{e.class}) — popis s dvojbodkou a medzerou daj do uvodzoviek"
      next
    end
    unless fm.is_a?(Hash)
      bad << "#{rel}: chyba frontmatter (subor musi zacinat riadkom ---)"
      next
    end
    name = fm['name']
    base = File.basename(path, '.md')
    bad << "#{rel}: name #{name.inspect} != nazov suboru #{base.inspect}" unless name == base
    bad << "#{rel}: name #{name.inspect} nie je v tvare male-pismena-a-pomlcky" unless name.is_a?(String) && name.match?(NX_AGENT_NAME)
    desc = fm['description']
    if !desc.is_a?(String) || desc.strip.empty?
      bad << "#{rel}: chyba description (podla neho orchestrator typ vybera)"
    elsif desc.length > NX_AGENT_DESC_MAX
      bad << "#{rel}: description ma #{desc.length} znakov (limit #{NX_AGENT_DESC_MAX}) — skrat, detaily patria do tela"
    end
    model = fm['model']
    if !model.is_a?(String) || model.strip.empty?
      bad << "#{rel}: chyba model (bez neho typ bezi na predvolenom modeli — rozhodnutie N13)"
    elsif !(NX_AGENT_MODELS.include?(model) || model.match?(NX_AGENT_MODEL_ID))
      bad << "#{rel}: model #{model.inspect} nie je alias (#{NX_AGENT_MODELS.join(', ')}) ani ID claude-..."
    end
    effort = fm['effort']
    bad << "#{rel}: effort #{effort.inspect} nie je z #{NX_AGENT_EFFORTS.join(', ')}" unless effort.nil? || NX_AGENT_EFFORTS.include?(effort)
    tools = fm['tools']
    bad << "#{rel}: tools musi byt text alebo zoznam nazvov nastrojov" unless tools.nil? || tools.is_a?(String) || tools.is_a?(Array)
  end
  NxTest.assert(bad.empty?, "Chybne definicie agentov:\n  #{bad.join("\n  ")}")
end

NxTest.test('agenti: mena typov su unikatne') do
  nx_agent_yaml!
  names = nx_agent_files.map do |path|
    # Neplatny YAML hlasi test vyssie; tu sa pre taky subor pouzije nazov suboru.
    fm = begin
      nx_agent_frontmatter(path)
    rescue StandardError
      nil
    end
    fm.is_a?(Hash) ? fm['name'].to_s : File.basename(path, '.md')
  end
  dupes = names.group_by(&:itself).select { |_n, v| v.size > 1 }.keys
  NxTest.assert(dupes.empty?, "Duplicitne mena typov agentov: #{dupes.join(', ')} — Claude Code by nacital len jeden")
end

NxTest.test('agenti: kazdy typ je zapisany v SYSTEM/WORKFLOW.md (Obsadenie roli)') do
  workflow = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'WORKFLOW.md'), encoding: 'UTF-8')
  missing = nx_agent_files.map { |p| File.basename(p, '.md') }.reject { |n| workflow.include?("`#{n}`") }
  NxTest.assert(missing.empty?,
                "Typy agentov chybajuce v SYSTEM/WORKFLOW.md: #{missing.join(', ')} — dopln ich do tabulky Obsadenie roli")
end

# --- G4 (blok 10 · PRAVIDLA, davka P2): typy su GENEROVANE zo SYSTEM/pravidla/typy/ a nededia CLAUDE.md ---
# Zdroj pravdy je subor roly v SYSTEM/pravidla/roly/; telo typu z neho sklada scripts/generuj_typy_agentov.rb.
# (a) ulozene typy = vystup generatora (rucna uprava alebo zabudnute pregenerovanie = cerveny test),
# (b) kazdy typ ma omitClaudeMd: true (inak zdedi most CLAUDE.md, a tym pravidla orchestratora),
# (c) ziadny typ nenesie text ORCHESTRATOR.md (podpisova veta).
require_relative '../../scripts/generuj_typy_agentov'

NX_ORCH_SIGNATURE = 'Hlavné okno je orchestrátor'

NxTest.test('agenti G4: typy v .claude/agents su zhodne s vystupom generatora') do
  problems = NxTypyAgentov.diff
  NxTest.assert(problems.empty?,
                "Typy agentov sa lisia od zdrojov:\n  #{problems.join("\n  ")}\n" \
                'Spusti `ruby scripts/generuj_typy_agentov.rb` (zdroj: SYSTEM/pravidla/typy/ a subory roli).')
end

NxTest.test('agenti G4: kazdy typ ma omitClaudeMd: true') do
  bad = nx_agent_files.reject do |path|
    m = File.read(path, encoding: 'UTF-8').gsub("\r\n", "\n").match(/\A---\n(.*?)\n---\n/m)
    m && m[1].split("\n").include?('omitClaudeMd: true')
  end
  NxTest.assert(bad.empty?,
                "Typy bez omitClaudeMd: true: #{bad.map { |p| File.basename(p) }.join(', ')} — subagent by zdedil CLAUDE.md")
end

NxTest.test('agenti G4: ziadny typ nenesie text ORCHESTRATOR.md') do
  orch = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'pravidla', 'roly', 'ORCHESTRATOR.md'), encoding: 'UTF-8')
  NxTest.assert(orch.include?(NX_ORCH_SIGNATURE),
                "ORCHESTRATOR.md uz nema podpisovu vetu „#{NX_ORCH_SIGNATURE}\" — uprav NX_ORCH_SIGNATURE")
  bad = nx_agent_files.select { |p| File.read(p, encoding: 'UTF-8').include?(NX_ORCH_SIGNATURE) }
  NxTest.assert(bad.empty?, "Typy s pravidlami orchestratora: #{bad.map { |p| File.basename(p) }.join(', ')}")
  # Aj ziadny zdroj typu nevklada ORCHESTRATOR.md (ani jeho sekciu) — podpisova veta by nechytila vlozenu sekciu bez nej.
  vklada = NxTypyAgentov.source_paths.select do |path|
    rel = path.sub("#{NxTest::ROOT}/", '')
    NxTypyAgentov.parse_source(NxTypyAgentov.read_lf(path), rel)[:zdroje].any? { |z| z.split('#').first.end_with?('ORCHESTRATOR.md') }
  end
  NxTest.assert(vklada.empty?, "Zdroje typov vkladaju ORCHESTRATOR.md: #{vklada.map { |p| File.basename(p) }.join(', ')}")
end

NxTest.test('agenti G4: kazdy zdroj typu ma typ a naopak (generator nic neprehliadne)') do
  src = NxTypyAgentov.source_paths.map { |p| File.basename(p) }.sort
  out = nx_agent_files.map { |p| File.basename(p) }.sort
  NxTest.assert(src == out, "Zdroje #{src.inspect} != typy #{out.inspect}")
end

NxTest.test('agenti G4: generator vlozi sekciu podla kotvy a chyti rucnu upravu aj typ bez zdroja (vlastne spravanie)') do
  Dir.mktmpdir('nx-typy-') do |root|
    FileUtils.mkdir_p(File.join(root, 'SYSTEM', 'pravidla', 'typy'))
    FileUtils.mkdir_p(File.join(root, '.claude', 'agents'))
    File.write(File.join(root, 'ROLA.md'),
               "# Rola\n\n<a id=\"a\"></a>\n\n## Sekcia A\n\nobsah A\n\n### Podsekcia\n\nviac A\n\n" \
               "<a id=\"b\"></a>\n\n## Sekcia B\n\nobsah B\n", encoding: 'UTF-8')
    File.binwrite(File.join(root, 'JADRO.md'), "# Jadro\r\n\r\njadro text\r\n")
    File.write(File.join(root, 'SYSTEM', 'pravidla', 'typy', 'skuska.md'),
               "---\nname: skuska\ndescription: Skuska\nmodel: sonnet\nzdroje:\n  - JADRO.md\n  - ROLA.md#a\n---\n\nHlavicka.\n",
               encoding: 'UTF-8')
    out = NxTypyAgentov.render_all(root)
    body = out['.claude/agents/skuska.md']
    NxTest.assert(body, "generator nevratil vystup (#{out.keys.inspect})")
    NxTest.assert(body.start_with?("---\nname: skuska\ndescription: Skuska\nmodel: sonnet\nomitClaudeMd: true\n---\n"),
                  "frontmatter vystupu: #{body[0, 120].inspect}")
    NxTest.assert(!body.include?('zdroje:'), 'zoznam zdrojov nesmie ist do vystupu')
    NxTest.assert(body.include?('Hlavicka.') && body.include?('jadro text') && !body.include?("\r"),
                  'hlavicka a cely subor jadra (LF) vo vystupe')
    NxTest.assert(body.include?('obsah A') && body.include?('viac A') && !body.include?('obsah B'),
                  'sekcia podla kotvy: obsah A aj podsekcia ano, sekcia B nie')
    NxTest.assert(NxTypyAgentov.render_all(root) == out, 'generator nie je deterministicky')

    NxTypyAgentov.write_all(root)
    NxTest.assert(NxTypyAgentov.diff(root).empty?, "po zapise ma byt zhoda (#{NxTypyAgentov.diff(root).inspect})")
    File.write(File.join(root, '.claude', 'agents', 'skuska.md'), "#{body}rucna uprava\n", encoding: 'UTF-8')
    File.write(File.join(root, '.claude', 'agents', 'sirota.md'), "---\nname: sirota\n---\n", encoding: 'UTF-8')
    found = NxTypyAgentov.diff(root)
    NxTest.assert(found.any? { |f| f.include?('skuska.md') } && found.any? { |f| f.include?('sirota.md') },
                  "diff nechytil rucnu upravu alebo typ bez zdroja: #{found.inspect}")
  end
end
