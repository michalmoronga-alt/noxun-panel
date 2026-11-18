# frozen_string_literal: true
# Generator typov agentov Claude Code (blok 10 · PRAVIDLA, davka P2).
#
# Kazdy typ v .claude/agents/<typ>.md je GENEROVANY — rucne sa needituje. Zdroj typu je
# SYSTEM/pravidla/typy/<typ>.md: frontmatter typu (name, description, model, effort, tools, isolation)
# + zoznam `zdroje:` (len pre generator, do vystupu nejde) + kratka hlavicka typu v tele.
# Vystup = frontmatter zdroja bez `zdroje:` + `omitClaudeMd: true` (typ nededi most CLAUDE.md, a tym
# ani ORCHESTRATOR.md) + znacka "generovane" + hlavicka + doslovne vlozene subory zo `zdroje:`.
# Polozka zdroja je cesta k suboru (cely subor) alebo `cesta#kotva` — sekcia od riadku
# `<a id="kotva"></a>` po dalsiu kotvu alebo nadpis `## ` za nadpisom sekcie.
# Vystup je deterministicky: konce riadkov LF, rovnaky vstup = rovnaky subor.
#
# Pouzitie (z korena repa):
#   ruby scripts/generuj_typy_agentov.rb          # zapise vsetky typy
#   ruby scripts/generuj_typy_agentov.rb --check  # len porovna; exit 1 pri rozdiele (straz G4 robi to iste v teste)
# Ciste Ruby bez gemov (bezi aj v teste v SketchUpe).

module NxTypyAgentov
  ROOT = File.expand_path('..', __dir__)
  SRC_DIR = File.join('SYSTEM', 'pravidla', 'typy')
  OUT_DIR = File.join('.claude', 'agents')
  OMIT_LINE = 'omitClaudeMd: true'
  MARK = '<!-- GENEROVANÉ: scripts/generuj_typy_agentov.rb zo SYSTEM/pravidla/typy/%<typ>s.md — needituj ručne; ' \
         'zmena = zdroj + `ruby scripts/generuj_typy_agentov.rb`. -->'

  class Chyba < StandardError; end

  module_function

  def read_lf(path)
    File.read(path, encoding: 'UTF-8').gsub("\r\n", "\n")
  end

  def source_paths(root = ROOT)
    Dir[File.join(root, SRC_DIR, '*.md')].sort
  end

  # Rozdeli zdroj na riadky frontmatteru, zoznam zdrojov a hlavicku.
  def parse_source(text, rel)
    m = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
    raise Chyba, "#{rel}: chyba frontmatter (subor musi zacinat riadkom ---)" unless m

    fm_lines = []
    zdroje = []
    in_zdroje = false
    m[1].split("\n").each do |line|
      if line.match?(/\Azdroje:\s*(\[\])?\s*\z/)
        in_zdroje = true
      elsif in_zdroje && (mm = line.match(/\A\s+-\s+(\S.*?)\s*\z/))
        zdroje << mm[1]
      else
        in_zdroje = false
        raise Chyba, "#{rel}: #{OMIT_LINE.split(':').first} nepis do zdroja — doplni ho generator" if line.start_with?('omitClaudeMd')

        fm_lines << line
      end
    end
    name = fm_lines.find { |l| l.start_with?('name:') }.to_s.sub('name:', '').strip
    base = File.basename(rel, '.md')
    raise Chyba, "#{rel}: name #{name.inspect} != nazov suboru #{base.inspect}" unless name == base

    { fm_lines: fm_lines, zdroje: zdroje, header: m[2].strip }
  end

  # Text zdroja: cely subor alebo sekcia podla kotvy.
  def fragment(item, root, rel)
    path, anchor = item.split('#', 2)
    full = File.join(root, path)
    raise Chyba, "#{rel}: zdroj #{path} neexistuje" unless File.file?(full)

    text = read_lf(full)
    return text.strip unless anchor

    lines = text.split("\n")
    start = lines.index(%(<a id="#{anchor}"></a>))
    raise Chyba, "#{rel}: v #{path} chyba kotva <a id=\"#{anchor}\"></a>" unless start

    out = []
    seen_heading = false
    lines[(start + 1)..].each do |line|
      break if line.start_with?('<a id=')
      if line.start_with?('## ')
        break if seen_heading

        seen_heading = true
      end
      out << line
    end
    out.join("\n").strip
  end

  def render(src_path, root = ROOT)
    rel = src_path.sub("#{root}/", '')
    src = parse_source(read_lf(src_path), rel)
    typ = File.basename(src_path, '.md')
    parts = []
    parts << "---\n#{(src[:fm_lines] + [OMIT_LINE]).join("\n")}\n---"
    parts << format(MARK, typ: typ)
    parts << src[:header] unless src[:header].empty?
    src[:zdroje].each do |item|
      path, anchor = item.split('#', 2)
      parts << if anchor
                 "> **Vložená sekcia `#{anchor}` zo súboru `#{path}`** (odkazy v nej sú relatívne k tomu súboru)."
               else
                 "> **Vložený súbor `#{path}`** (odkazy v ňom sú relatívne k nemu; netreba ho čítať znova)."
               end
      parts << fragment(item, root, rel)
    end
    "#{parts.join("\n\n")}\n"
  end

  # { 'relativna cesta vystupu' => obsah } pre vsetky zdroje.
  def render_all(root = ROOT)
    source_paths(root).to_h do |path|
      [File.join(OUT_DIR, File.basename(path)).tr('\\', '/'), render(path, root)]
    end
  end

  # Zoznam rozdielov medzi vygenerovanym a ulozenym stavom (prazdny = zhoda).
  def diff(root = ROOT)
    want = render_all(root)
    have = Dir[File.join(root, OUT_DIR, '*.md')].map { |p| p.sub("#{root}/", '') }
    problems = []
    want.each do |rel, content|
      full = File.join(root, rel)
      if !File.file?(full)
        problems << "#{rel}: chyba (zdroj existuje)"
      elsif read_lf(full) != content
        problems << "#{rel}: lisi sa od vystupu generatora"
      end
    end
    (have - want.keys).each { |rel| problems << "#{rel}: nema zdroj v #{SRC_DIR.tr('\\', '/')}/" }
    problems
  end

  def write_all(root = ROOT)
    render_all(root).each do |rel, content|
      File.binwrite(File.join(root, rel), content.encode('UTF-8'))
    end
  end
end

if File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__)
  begin
    if ARGV.include?('--check')
      problems = NxTypyAgentov.diff
      if problems.empty?
        puts 'typy agentov: zhoda so zdrojmi'
      else
        puts "typy agentov: rozdiel\n  #{problems.join("\n  ")}\nspusti `ruby scripts/generuj_typy_agentov.rb`"
        exit 1
      end
    else
      NxTypyAgentov.write_all
      puts "typy agentov: zapisanych #{NxTypyAgentov.source_paths.length}"
    end
  rescue NxTypyAgentov::Chyba => e
    warn "typy agentov: #{e.message}"
    exit 2
  end
end
