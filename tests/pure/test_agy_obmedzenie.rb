# frozen_string_literal: true
# Straz jedneho domova bloku OBMEDZENIE NASTROJOV pre beh `agy` (blok 10 · PRAVIDLA, davka P3b).
# Doslovny text bloku ma jediny domov: scripts/agy/obmedzenie.txt. Obal `agy-reserser` (zdroj aj vygenerovany typ) ho cita zo
# suboru; skill `antigravity-outside-in` na subor len odkazuje. Dalsia kopia textu by sa pri zmene bloku zabudla opravit.
require 'tmpdir'
require_relative '../helper' unless defined?(NxTest)

NX_OBM_FILE = File.join('scripts', 'agy', 'obmedzenie.txt').freeze
# Doslovny text bloku: zaciatok bloku a jeho charakteristicke vety.
NX_OBM_PATTERNS = [
  /OBMEDZENIE NÁSTROJOV:\s*nepoužívaj/,
  /nepoužívaj terminál, príkazy ani čítanie či zápis súborov/,
  /Používaj výhradne vyhľadávanie na webe \(search_web\)/
].freeze
NX_OBM_READ = %q(OBM="$(tr -d '\r' < "$S/obmedzenie.txt")").freeze
NX_OBM_SCAN = %w[.claude/**/* SYSTEM/**/* scripts/**/*].freeze

# Subory (relativne cesty) pod NX_OBM_SCAN, ktore obsahuju doslovny text bloku; `skip` sa preskoci.
def nx_obm_copies(root, skip)
  NX_OBM_SCAN.flat_map { |pat| Dir[File.join(root, pat)] }.uniq.sort.filter_map do |path|
    rel = path.sub("#{root}/", '')
    # `.claude/worktrees/` su cudzie checkouty vetiev (v hlavnom checkoute), nie subory tohto repa.
    next if rel == skip || rel.start_with?('.claude/worktrees/') || !File.file?(path)

    text = File.binread(path).force_encoding('UTF-8').scrub
    rel if NX_OBM_PATTERNS.any? { |re| text.match?(re) }
  end
end

NxTest.test('agy OBM: doslovny text bloku je len v scripts/agy/obmedzenie.txt') do
  path = File.join(NxTest::ROOT, NX_OBM_FILE)
  NxTest.assert(File.exist?(path), "#{NX_OBM_FILE} chyba — jediny domov bloku OBMEDZENIE NASTROJOV")
  raw = File.binread(path)
  NxTest.assert(!raw.start_with?("\xEF\xBB\xBF".b), "#{NX_OBM_FILE} nesmie mat BOM")
  text = raw.force_encoding('UTF-8')
  NxTest.assert(text.valid_encoding?, "#{NX_OBM_FILE} nie je platne UTF-8")
  NxTest.assert(text.strip.lines.length == 1, "#{NX_OBM_FILE} ma mat jeden riadok (ma #{text.strip.lines.length})")
  NxTest.assert(NX_OBM_PATTERNS.all? { |re| text.match?(re) }, "#{NX_OBM_FILE} neobsahuje doslovny text bloku")

  copies = nx_obm_copies(NxTest::ROOT, NX_OBM_FILE)
  NxTest.assert(copies.empty?,
                "Doslovny text bloku OBMEDZENIE NASTROJOV je aj mimo #{NX_OBM_FILE}: #{copies.join(', ')} — " \
                'v ostatnych suboroch ma byt len odkaz na subor.')
end

NxTest.test('agy OBM: obal agy-reserser cita blok zo suboru (zdroj aj vygenerovany typ)') do
  %w[SYSTEM/pravidla/typy/agy-reserser.md .claude/agents/agy-reserser.md].each do |rel|
    src = File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
    # `tr -d '\r'`: checkout s core.autocrlf=true ma subor s CRLF a CR by sa dostal do promptu.
    NxTest.assert(src.include?(NX_OBM_READ), "#{rel}: prikaz behu nenacitava blok zo suboru obmedzenie.txt bez CR (#{NX_OBM_READ})")
    NxTest.assert(src.include?('printf \'%s\n\n\' "$OBM"'), "#{rel}: prikaz behu nevklada blok OBM na zaciatok promptu")
  end
  skill = File.read(File.join(NxTest::ROOT, '.claude', 'skills', 'antigravity-outside-in', 'SKILL.md'), encoding: 'UTF-8')
  NxTest.assert(skill.include?('scripts/agy/obmedzenie.txt'), 'skill antigravity-outside-in neodkazuje na scripts/agy/obmedzenie.txt')
  NxTest.assert(skill.include?(NX_OBM_READ), "skill antigravity-outside-in: prikaz behu nenacitava blok bez CR (#{NX_OBM_READ})")
end

NxTest.test('agy OBM: straz chyti kopiu textu a nechyti odkaz na subor (vlastne spravanie)') do
  Dir.mktmpdir('nx-obm-') do |dir|
    FileUtils.mkdir_p(File.join(dir, '.claude', 'skills'))
    FileUtils.mkdir_p(File.join(dir, 'scripts', 'agy'))
    File.write(File.join(dir, 'scripts', 'agy', 'obmedzenie.txt'),
               "OBMEDZENIE NÁSTROJOV: nepoužívaj terminál, príkazy ani čítanie či zápis súborov.\n", encoding: 'UTF-8')
    File.write(File.join(dir, '.claude', 'skills', 'odkaz.md'),
               "Blok OBMEDZENIE NÁSTROJOV je v scripts/agy/obmedzenie.txt.\n", encoding: 'UTF-8')
    NxTest.assert(nx_obm_copies(dir, NX_OBM_FILE).empty?, 'negativny pripad: odkaz na subor nesmie byt kopia')

    File.write(File.join(dir, '.claude', 'skills', 'kopia.md'),
               "OBM='OBMEDZENIE NÁSTROJOV: nepoužívaj terminál, príkazy ani čítanie či zápis súborov — sú zablokované.'\n",
               encoding: 'UTF-8')
    NxTest.assert(nx_obm_copies(dir, NX_OBM_FILE) == ['.claude/skills/kopia.md'],
                  "pozitivny pripad: straz nechytila kopiu (nasla: #{nx_obm_copies(dir, NX_OBM_FILE).inspect})")
  end
end
