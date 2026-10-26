# frozen_string_literal: true
# Guardy G1 "strop velkosti" a G2 "bez historie" pravidiel (blok 10 · PRAVIDLA, davka P1b).
# Pravidla, ktore agenti citaju automaticky (AGENTS.md, most CLAUDE.md, SYSTEM/pravidla/**, .claude/rules/**), nesmu znova
# "pretiect": CLAUDE.md narastol na 35 kB a Codex oreze AGENTS.md na 32 KiB. Historia (datumy zavedenia,
# revizie, cisla PR) patri do KRONIKY a archivu — v pravidle len platne znenie.
# Zmena stropu = zmena konstanty nizsie (jedine miesto).
require 'tmpdir'
require_relative '../helper' unless defined?(NxTest)

# G1 — stropy: relativna cesta (glob povoleny) → [max bajtov, max riadkov alebo nil].
NX_PRAV_LIMITS = {
  'AGENTS.md' => [12 * 1024, 150],
  'CLAUDE.md' => [1 * 1024, nil],
  # Roly: spolocny strop 14 kB; IMPLEMENTATOR.md ma vlastny 8 kB riadok — pravidla oblasti ziju v .claude/rules/, nie v roli.
  'SYSTEM/pravidla/roly/*.md' => [14 * 1024, nil],
  'SYSTEM/pravidla/roly/IMPLEMENTATOR.md' => [8 * 1024, nil],
  # POVINNE_CITANIE je rozcestnik: riadky bez cesty + tabulka oblasti; obsah oblasti je v .claude/rules/.
  'SYSTEM/pravidla/POVINNE_CITANIE.md' => [6 * 1024, nil],
  # Subory oblasti: nacitaju sa do kontextu agenta pri praci so subormi oblasti.
  '.claude/rules/*.md' => [6 * 1024, nil],
  'SYSTEM/pravidla/DEFINICIE.md' => [10 * 1024, nil],
  # Davka P2: podrobnosti nastrojov testov (foto okien, export test, diagnostika MCP) vybrane z IMPLEMENTATOR.md.
  'SYSTEM/pravidla/NASTROJE_TESTOV.md' => [8 * 1024, nil]
}.freeze

# G2 — subory bez historie a vzory historie.
NX_PRAV_HISTORY_SCAN = %w[AGENTS.md CLAUDE.md SYSTEM/pravidla/**/*.md .claude/rules/**/*.md].freeze
NX_PRAV_HISTORY_PATTERNS = {
  'od <dátum>' => /\bod\s+\d{1,2}\.\s?\d{1,2}\./i,
  '(od <č>.<č>.20' => /\(od\s+\d{1,2}\.\s?\d{1,2}\.\s?20/i,
  'od v<verzia>' => /\bod\s+v\d+\.\d+/i,
  # Len revizia s datumom alebo menom kola (napr. "revízia 27.9.", "revízie RETRO 12.8."); vecne slovo
  # ("stabilizačná revízia" = kontrola kodu) historia nie je.
  # Meno kola len verzalkami (RETRO, WORKFLOW) — malé „workflow" vo vecnom texte historia nie je.
  'revízi <dátum>' => /revízi\w*\s+(?:(?-i:RETRO|WORKFLOW)|\d)/i,
  'PR #<číslo>' => /\bPR\s*#\s*\d/,
  'pokus 2' => /\bpokus\s+2/i
}.freeze

def nx_prav_files(patterns)
  patterns.flat_map { |pat| Dir[File.join(NxTest::ROOT, pat)] }.uniq.sort
end

# Vrati zoznam "subor:riadok — vzor" pre kazdy vyskyt vzoru historie.
def nx_prav_history_offenders(paths)
  paths.flat_map do |path|
    rel = path.sub("#{NxTest::ROOT}/", '')
    File.readlines(path, encoding: 'UTF-8').each_with_index.flat_map do |line, i|
      NX_PRAV_HISTORY_PATTERNS.select { |_name, re| line.match?(re) }.map { |name, _re| "#{rel}:#{i + 1} — „#{name}\"" }
    end
  end
end

NxTest.test('pravidla G1: AGENTS.md, CLAUDE.md, roly, POVINNE_CITANIE a DEFINICIE su pod stropom') do
  bad = []
  NX_PRAV_LIMITS.each do |pat, (max_bytes, max_lines)|
    files = nx_prav_files([pat])
    NxTest.assert(!files.empty?, "#{pat}: nenasiel som ziadny subor — guard by nic nestrazil")
    files.each do |path|
      rel = path.sub("#{NxTest::ROOT}/", '')
      # Bajty bez CR: strop nesmie zavisiet od toho, ci checkout na Windows zmenil konce riadkov na CRLF.
      size = File.binread(path).gsub("\r\n", "\n").bytesize
      lines = File.readlines(path, encoding: 'UTF-8').length
      bad << "#{rel}: #{size} B (strop #{max_bytes} B)" if size > max_bytes
      bad << "#{rel}: #{lines} riadkov (strop #{max_lines})" if max_lines && lines > max_lines
    end
  end
  NxTest.assert(bad.empty?,
                "Pravidla nad stropom:\n  #{bad.join("\n  ")}\n" \
                'Pravidlo patri na jedno miesto (rola, skill, .claude/rules/), historia do KRONIKY — nie dalsi text sem.')
end

NxTest.test('pravidla G1: roly su v SYSTEM/pravidla/roly/ (vsetky karty roli)') do
  %w[ORCHESTRATOR.md IMPLEMENTATOR.md RECENZENT.md AUDITOR.md RESERSER.md ANALYTIK.md].each do |name|
    path = File.join(NxTest::ROOT, 'SYSTEM', 'pravidla', 'roly', name)
    NxTest.assert(File.exist?(path), "SYSTEM/pravidla/roly/#{name} chyba")
  end
end

NxTest.test('pravidla G1: CLAUDE.md je most — importuje AGENTS.md a ORCHESTRATOR.md') do
  src = File.read(File.join(NxTest::ROOT, 'CLAUDE.md'), encoding: 'UTF-8')
  %w[@AGENTS.md @SYSTEM/pravidla/roly/ORCHESTRATOR.md].each do |imp|
    NxTest.assert(src.lines.map(&:strip).include?(imp), "CLAUDE.md nema riadok #{imp} — Claude Code by pravidla nenacital")
  end
end

NxTest.test('pravidla G2: v AGENTS.md, CLAUDE.md a SYSTEM/pravidla/ nie je historia') do
  files = nx_prav_files(NX_PRAV_HISTORY_SCAN)
  NxTest.assert(files.length >= 5, "guard nenasiel subory pravidiel (#{files.length}) — over NX_PRAV_HISTORY_SCAN")
  offenders = nx_prav_history_offenders(files)
  NxTest.assert(offenders.empty?,
                "Historia v pravidlach:\n  #{offenders.join("\n  ")}\n" \
                'Datum zavedenia, reviziu alebo cislo PR presun do KRONIKY; v pravidle ostava len platne znenie.')
end

NxTest.test('pravidla G2: guard chyti historiu a nechyti platne znenie (vlastne spravanie)') do
  Dir.mktmpdir('nx-pravidla-') do |dir|
    clean = File.join(dir, 'cisty.md')
    File.write(clean, "Pred `gh pr create` sa píše `PR #?`; od 75 % kontextu zapíš stav.\n" \
                      "Bump patch (0.5.0 → 0.5.1). PR #N menil plugin.\n" \
                      "Stabilizačná revízia kódu ešte nebola; revízie návrhu robí audítor.\n" \
                      "Revízie workflowu robí orchestrátor.\n", encoding: 'UTF-8')
    NxTest.assert(nx_prav_history_offenders([clean]).empty?,
                  "negativny pripad: platne znenie nesmie mat nalez (#{nx_prav_history_offenders([clean]).inspect})")

    dirty = File.join(dir, 'historia.md')
    File.write(dirty, "## Git (záväzné od 16.7.2026, revízia 12.8.)\n- Štart bloku (od 27.9.2026): dôvod PR #398.\n" \
                      "- Retro (pokus 27.9.–11.10.2026).\n- Verzia (od v0.5.0).\n", encoding: 'UTF-8')
    found = nx_prav_history_offenders([dirty])
    NX_PRAV_HISTORY_PATTERNS.each_key do |name|
      NxTest.assert(found.any? { |f| f.include?("„#{name}\"") },
                    "pozitivny pripad: guard nechytil vzor „#{name}\" (nasiel: #{found.inspect})")
    end

    # Revizia s menom kola (bez datumu za slovom) je tiez historia.
    kolo = File.join(dir, 'kolo.md')
    File.write(kolo, "Git workflow (revízie RETRO 12.8. a WORKFLOW 26.9.)\n", encoding: 'UTF-8')
    NxTest.assert(nx_prav_history_offenders([kolo]).any? { |f| f.include?('revízi <dátum>') },
                  'pozitivny pripad: guard nechytil „revízie RETRO"')
  end
end
