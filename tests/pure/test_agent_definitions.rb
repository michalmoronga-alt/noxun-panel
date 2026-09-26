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
