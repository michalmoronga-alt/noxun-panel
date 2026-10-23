# frozen_string_literal: true
# Guard G3 "jedna definicia" (blok 10 · PRAVIDLA, davka P1a, 23.10.2026).
# Definicie, podla ktorych sa rozhoduje o branach kazdej davky (vyrobna/cenova D1, audit-povinna D2,
# triedy D3, povinna predrecenzia D4, novy ovladaci prvok v UI D5, in-SU ako brana mergu D6), maju
# JEDINE znenie v SYSTEM/pravidla/DEFINICIE.md. Dovod (prieskum sessions 6.-17.10.2026): ta ista
# veta na 3-8 miestach -> review opakovane nachadzalo zabudnute kopie (#464, #465 2x P1, #468 6x P2).
# Guard: podpisove frazy (2-4 charakteristicke useky z kazdej definicie) sa smu vyskytnut LEN
# v DEFINICIE.md. Prehladavaju sa subory pravidiel, ktore agenti citaju; archiv, KRONIKA
# a SYSTEM/zdroje/ sa vedome NEprehladavaju (historia sa neprepisuje).
# Porovnanie: bez ohladu na velkost pismen, zalomenie riadkov, odsadenie, citacie "> "
# a markdown zvyraznenie (* a `) — kopia s inym zalomenim alebo tucnym pismom sa chyti tiez.
# Zmena znenia definicie: zmen DEFINICIE.md a ked sa tym zmeni podpisova fraza, aj zoznam nizsie.
require 'tmpdir'
require_relative '../helper' unless defined?(NxTest)

NX_DEF_FILE = File.join(NxTest::ROOT, 'SYSTEM', 'pravidla', 'DEFINICIE.md')
NX_DEF_IDS = %w[D1 D2 D3 D4 D5 D6].freeze

# Podpisove frazy podla definicie (pisane uz v normalizovanom tvare: male pismena, bez * a `).
NX_DEF_PHRASES = {
  'D1' => ['rozmery alebo počty dielov, hrany, kusovník',
           'podľa ktorého sa v okne objednáva',
           'precedens rows_with_roles',
           'preklad nadpisov a popiskov bez zmeny čísel'],
  'D2' => ['každé zvýšenie config_schema',
           'rozhoduje obsah zásahu, nie žáner',
           'nová plocha sketchup api sama osebe'],
  'D3' => ['platí najvyššia trieda',
           'd je užší prípad ľ',
           'hranica pri zadaní je odhad',
           'pokračovaním sa opravujú len p2/p3'],
  'D4' => ['druhý slepý recenzent iného providera',
           'kód iného providera vždy kontroluje',
           'nová interakcia v ui bez nového ovládacieho prvku'],
  'D5' => ['ďalšia voľba v existujúcom zozname',
           'presun existujúceho tlačidla alebo jeho zmena na ikonu',
           'rozbaľovačka alebo položka menu, ktorá niečo spúšťa'],
  'D6' => ['nemenia ruby kód spúšťačov',
           'akcie panela zapisujúce do modelu',
           'na ktorej hlave in-su bežal']
}.freeze

# Subory pravidiel, ktore nesmu niest kopiu definicie (relativne k rootu; glob povoleny).
# STANDARD.md navyse oproti package P1a § 5 — v §13 niesol parafrazu D1/D2 (R10); docs/architecture/*.md
# po review PR #478 (rozsirovacie-body.md prerozpravalo hranice D1 a D5). Davka P1b: subory roli
# a povinne citanie (pravidla presunute z CLAUDE.md).
NX_DEF_SCAN = %w[
  CLAUDE.md AGENTS.md SYSTEM/WORKFLOW.md SYSTEM/PLAN.md SYSTEM/README.md SYSTEM/STANDARD.md
  SYSTEM/pravidla/roly/*.md SYSTEM/pravidla/POVINNE_CITANIE.md
  .claude/agents/*.md .claude/skills/*/SKILL.md docs/architecture/*.md
].freeze

def nx_def_normalize(text)
  text.lines.map { |l| l.sub(/\A\s*>\s?/, '') }.join
      .downcase.delete('*`').gsub(/\s+/, ' ')
end

def nx_def_scan_files
  NX_DEF_SCAN.flat_map { |pat| Dir[File.join(NxTest::ROOT, pat)] }.uniq.sort
end

# Vrati zoznam "subor: fraza (Dx)" pre kazdu podpisovu frazu najdenu v danych suboroch.
def nx_def_offenders(paths)
  paths.flat_map do |path|
    norm = nx_def_normalize(File.read(path, encoding: 'UTF-8'))
    rel = path.sub("#{NxTest::ROOT}/", '')
    NX_DEF_PHRASES.flat_map do |id, phrases|
      phrases.select { |p| norm.include?(p) }.map { |p| "#{rel}: „#{p}\" (#{id})" }
    end
  end
end

NxTest.test('definicie: SYSTEM/pravidla/DEFINICIE.md existuje a ma nadpisy D1-D6') do
  NxTest.assert(File.exist?(NX_DEF_FILE), 'SYSTEM/pravidla/DEFINICIE.md chyba — jediny domov definicii zmizol')
  text = File.read(NX_DEF_FILE, encoding: 'UTF-8')
  missing = NX_DEF_IDS.reject { |id| text.match?(/^## #{id} · /) }
  NxTest.assert(missing.empty?, "DEFINICIE.md nema nadpisy #{missing.join(', ')} (tvar „## Dx · Nazov\")")
end

NxTest.test('definicie: kazda podpisova fraza je v DEFINICIE.md (zoznam v teste je aktualny)') do
  norm = nx_def_normalize(File.read(NX_DEF_FILE, encoding: 'UTF-8'))
  stale = NX_DEF_PHRASES.flat_map { |id, ps| ps.reject { |p| norm.include?(p) }.map { |p| "#{id}: „#{p}\"" } }
  NxTest.assert(stale.empty?,
                "Podpisove frazy, ktore uz v DEFINICIE.md nie su: #{stale.join(' · ')} — " \
                'po zmene znenia definicie uprav zoznam NX_DEF_PHRASES v tests/pure/test_definicie.rb')
end

NxTest.test('definicie: podpisove frazy su LEN v DEFINICIE.md (ziadna kopia v pravidlach)') do
  files = nx_def_scan_files
  NxTest.assert(files.length >= 8, "guard nenasiel subory pravidiel (#{files.length}) — over NX_DEF_SCAN")
  offenders = nx_def_offenders(files)
  NxTest.assert(offenders.empty?,
                "Kopie definicii mimo SYSTEM/pravidla/DEFINICIE.md:\n  #{offenders.join("\n  ")}\n" \
                'Nahrad znenie odkazom (napr. „vyrobna/cenova davka — DEFINICIE.md § D1"), obsah neopakuj.')
end

# Od davky P1b je CLAUDE.md len most — skutocny text pravidiel je v AGENTS.md a suboroch roli,
# preto sa testuje ich spojenie (presne to, co Claude Code nacita cez most).
NxTest.test('definicie: guard chyti kopiu vlozenu do docasnej kopie pravidiel (aj s inym zalomenim a pismom)') do
  Dir.mktmpdir('nx-definicie-') do |dir|
    src = %w[AGENTS.md SYSTEM/pravidla/roly/ORCHESTRATOR.md SYSTEM/pravidla/roly/IMPLEMENTATOR.md].map do |rel|
      File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
    end.join("\n")
    clean = File.join(dir, 'pravidla.md')
    File.write(clean, src, encoding: 'UTF-8')
    NxTest.assert(nx_def_offenders([clean]).empty?, 'negativny pripad: ciste pravidla nesmu mat nalez')

    dirty = File.join(dir, 'pravidla_kopia.md')
    File.write(dirty, "#{src}\n- **Ďalšia voľba** v existujúcom\n  zozname nie je nový prvok.\n" \
                      "> Platí NAJVYŠŠIA\n> trieda.\n", encoding: 'UTF-8')
    found = nx_def_offenders([dirty])
    NxTest.assert(found.any? { |f| f.include?('(D5)') } && found.any? { |f| f.include?('(D3)') },
                  "pozitivny pripad: guard nechytil vlozene frazy D5 a D3 (nasiel: #{found.inspect})")
  end
end
