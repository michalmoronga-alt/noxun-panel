# frozen_string_literal: true
# Straz pravidiel oblasti `.claude/rules/*.md` (blok 10 · PRAVIDLA, davka P3a).
# Claude Code nacita subor oblasti SAM, ked agent cita alebo upravuje subor zodpovedajuci `paths:` v hlavicke;
# subor bez `paths:` by sa nacital kazdej role vzdy (a zerel by kontext), glob bez zhody je mrtve pravidlo
# a subor, ktory POVINNE_CITANIE.md nemenuje, nenajde Codex ani Grok (automaticky ho nedostanu).
# Strop velkosti suborov oblasti a zakaz historie ostavaju v test_pravidla_velkost.rb.
require 'tmpdir'
require 'fileutils'
require_relative '../helper' unless defined?(NxTest)

NX_RULES_DIR = File.join('.claude', 'rules').freeze
NX_RULES_INDEX = File.join('SYSTEM', 'pravidla', 'POVINNE_CITANIE.md').freeze

# Hlavicka suboru oblasti: zoznam globov z `paths:` (YAML zoznam) alebo nil, ked hlavicka/paths chyba.
def nx_rules_paths(path)
  text = File.read(path, encoding: 'UTF-8').gsub("\r\n", "\n")
  m = text.match(/\A---\n(.*?)\n---\n/m)
  return nil unless m

  globs = []
  in_paths = false
  m[1].each_line do |line|
    if line.match?(/\Apaths:\s*\z/)
      in_paths = true
    elsif in_paths && (mm = line.match(/\A\s+-\s+"?([^"\n]+?)"?\s*\z/))
      globs << mm[1]
    else
      in_paths = false
    end
  end
  globs
end

# Zoznam problemov: "subor: popis" pre kazdy subor oblasti v `root`/.claude/rules.
def nx_rules_problems(root)
  Dir[File.join(root, NX_RULES_DIR, '*.md')].sort.flat_map do |path|
    rel = path.sub("#{root}/", '')
    globs = nx_rules_paths(path)
    if globs.nil? || globs.empty?
      ["#{rel}: chyba hlavicka s neprazdnym `paths:` (subor bez paths by sa nacital vzdy)"]
    else
      globs.reject { |g| Dir.glob(File.join(root, g), File::FNM_EXTGLOB).any? }
           .map { |g| "#{rel}: glob #{g.inspect} netrafi ziadny subor (preklep = mrtve pravidlo)" }
    end
  end
end

NxTest.test('oblasti: kazdy .claude/rules/*.md ma paths: a kazdy glob trafi aspon jeden subor') do
  files = Dir[File.join(NxTest::ROOT, NX_RULES_DIR, '*.md')]
  NxTest.assert(files.length >= 8, "ocakavam subory oblasti v #{NX_RULES_DIR} (nasiel som #{files.length})")
  problems = nx_rules_problems(NxTest::ROOT)
  NxTest.assert(problems.empty?, "Pravidla oblasti:\n  #{problems.join("\n  ")}")
end

NxTest.test('oblasti: POVINNE_CITANIE.md menuje kazdy subor oblasti') do
  index = File.read(File.join(NxTest::ROOT, NX_RULES_INDEX), encoding: 'UTF-8')
  missing = Dir[File.join(NxTest::ROOT, NX_RULES_DIR, '*.md')].map { |p| File.basename(p) }.sort
                                                              .reject { |n| index.include?("#{NX_RULES_DIR.tr('\\', '/')}/#{n}") }
  NxTest.assert(missing.empty?,
                "POVINNE_CITANIE.md nemenuje #{missing.join(', ')} — Codex a Grok ich automaticky nedostanu, tabulka oblasti ich musi mat")
end

NxTest.test('oblasti: straz chyti subor bez paths, mrtvy glob a nechyti platnu oblast (vlastne spravanie)') do
  Dir.mktmpdir('nx-oblasti-') do |root|
    FileUtils.mkdir_p(File.join(root, NX_RULES_DIR))
    FileUtils.mkdir_p(File.join(root, 'src', 'ui'))
    File.write(File.join(root, 'src', 'ui', 'panel.rb'), "# x\n")
    File.write(File.join(root, 'src', 'a.rb'), "# x\n")
    rules = File.join(root, NX_RULES_DIR)

    # negativny pripad: platne oblasti (zoznam globov, `**`, zlozene zatvorky) nemaju nalez
    File.write(File.join(rules, 'ok.md'), "---\npaths:\n  - \"src/ui/**\"\n  - \"src/{a,b}.rb\"\n---\n\n# Oblast\n", encoding: 'UTF-8')
    NxTest.assert(nx_rules_problems(root).empty?, "platna oblast nesmie mat nalez (#{nx_rules_problems(root).inspect})")

    # pozitivne pripady: bez hlavicky, bez paths, prazdne paths, glob bez zhody
    File.write(File.join(rules, 'bez_hlavicky.md'), "# Oblast\n", encoding: 'UTF-8')
    File.write(File.join(rules, 'bez_paths.md'), "---\ntitle: x\n---\n\n# Oblast\n", encoding: 'UTF-8')
    File.write(File.join(rules, 'prazdne.md'), "---\npaths:\n---\n\n# Oblast\n", encoding: 'UTF-8')
    File.write(File.join(rules, 'mrtvy.md'), "---\npaths:\n  - \"src/ui/**\"\n  - \"src/uii/**\"\n---\n\n# Oblast\n", encoding: 'UTF-8')
    found = nx_rules_problems(root)
    %w[bez_hlavicky.md bez_paths.md prazdne.md].each do |n|
      NxTest.assert(found.any? { |f| f.include?(n) && f.include?('paths') },
                    "pozitivny pripad: straz nechytila #{n} (nasla: #{found.inspect})")
    end
    NxTest.assert(found.any? { |f| f.include?('mrtvy.md') && f.include?('src/uii/**') },
                  "pozitivny pripad: straz nechytila mrtvy glob (nasla: #{found.inspect})")
    NxTest.assert(found.none? { |f| f.include?('ok.md') }, "ok.md nesmie mat nalez (nasla: #{found.inspect})")
  end
end
