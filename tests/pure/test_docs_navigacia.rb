# frozen_string_literal: true
# Guard navigacie dokumentacie (davka U1, 11.8.2026; rozsirene davkou U3).
# STAV.md je vstupny bod kazdeho sedenia — musi ostat KRATKY a musi mat stabilnu
# kostru, aby agent vedel, kde hladat. PLAN.md drzi bloky prac.
# Guard kontroluje VYHRADNE STRUKTURU (existencia, limit riadkov, povinne nadpisy,
# platnost lokalnych odkazov) — ZNENIE textu nikdy: obsah sa prepisuje pri kazdom
# uzavere davky a test ho nesmie blokovat.
require_relative '../helper' unless defined?(NxTest)

NX_STAV_MAX_LINES = 80
NX_STAV_SECTIONS = ['## Stav', '## Robí sa', '## Ďalší krok',
                    '## Posledné uzávery', '## Kam sa pozrieť'].freeze
# Limit riadkov sam o sebe nestaci — 80 obrich riadkov je 30 kB textu, ktory sa
# nedal precitat (presne stav pred davkou "Docs cleanup B", 26.8.2026).
NX_STAV_MAX_BYTES = 12 * 1024

# Davka "Docs cleanup B" (26.8.2026): SYSTEM/ ma vrstvy — zive docs (nizsie), zdroje/
# (nezavazne koncepty, necitaju sa automaticky) a archiv/ (historia, append-only).
# Mapu autorit drzi SYSTEM/README.md.
# Zoznam je EXPLICITNY, nie glob: archiv/ a zdroje/ sa vedome nestrazia (su to
# historicke texty, ktore sa nesmu prepisovat kvoli zalomeniu).
# Davka "Docs cleanup C" (26.8.2026) doplnila STANDARD.md a POJMY.md — po
# reflowe uz ziadny zivy dokument v SYSTEM/ nema vynimku.
NX_SYSTEM_LINE_FILES = %w[
  STAV.md PLAN.md DOGFOODING.md README.md V1_VIZIA.md VEPO_KONTRAKT.md
  STANDARD.md POJMY.md
].freeze
NX_SYSTEM_MAX_LINE = 400

# Koncepty v zdroje/next_sessions/ nesmu vyzerat ako zadanie — kazdy nesie status
# riadok hned pod nadpisom. README.md priecinka je rozcestnik, nie koncept.
NX_NEXT_SESSIONS_STATUS = '> Stav: KONCEPT'

# Davka "Docs cleanup A" (26.8.2026): ARCHITEKTURA.md je uz LEN rozcestnik,
# odseky modulov ziju v docs/architecture/. Router musi ostat kratky, mapa uplna.
NX_ARCH_ROUTER_MAX_LINES = 200
NX_ARCH_FILES = %w[
  model-a-identita.md construction.md materials.md
  hardware.md outputs.md ui-lifecycle.md
].freeze
# Dlhy riadok = necitatelny diff (jeden odsek = jeden riadok bola presne choroba,
# ktoru tato davka liecila). Plati na router aj na mapu; SYSTEM/ je mimo rozsah.
NX_ARCH_MAX_LINE = 400

NxTest.test('docs: SYSTEM/STAV.md existuje a ma najviac 80 riadkov') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'STAV.md')
  NxTest.assert(File.exist?(path), 'SYSTEM/STAV.md chyba — je to vstupny bod kazdeho sedenia')
  lines = File.readlines(path, encoding: 'UTF-8').length
  NxTest.assert(lines <= NX_STAV_MAX_LINES,
                "STAV.md ma #{lines} riadkov (limit #{NX_STAV_MAX_LINES}) — presun detaily do PLAN.md alebo archiv/KRONIKA.md")
end

NxTest.test('docs: SYSTEM/STAV.md ma najviac 12 kB') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'STAV.md')
  size = File.size(path)
  NxTest.assert(size <= NX_STAV_MAX_BYTES,
                "STAV.md ma #{size} B (limit #{NX_STAV_MAX_BYTES}) — starsie uzavery zloz do " \
                'jedneho riadku s odkazom na archiv/KRONIKA.md, nahradeny text patri do KRONIKY')
end

NxTest.test('docs: zive SYSTEM/*.md nemaju riadok nad 400 znakov') do
  offenders = []
  NX_SYSTEM_LINE_FILES.each do |name|
    path = File.join(NxTest::ROOT, 'SYSTEM', name)
    NxTest.assert(File.exist?(path), "SYSTEM/#{name} chyba")
    File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
      len = line.rstrip.length
      offenders << "SYSTEM/#{name}:#{i + 1} (#{len})" if len > NX_SYSTEM_MAX_LINE
    end
  end
  NxTest.assert(offenders.empty?,
                "Riadky nad #{NX_SYSTEM_MAX_LINE} znakov: #{offenders.join(', ')} — " \
                'rozbi odsek na kratsie riadky (Markdown ich spoji do jedneho odseku)')
end

# Hotovy blok patri do archivu, nie do planu. Nadpis s "KOMPLET", "HOTOVE" alebo fajkou
# znamena, ze sa uzavrety blok v PLAN.md zabudol presunut do archiv/ROADMAP_hotove_etapy.md.
# Slovnik repa pozna obe slova, preto sa chytaju obe — a case-insensitive, lebo nadpisy
# ich pisu raz verzalkami, raz normalne. Hranica je ZACIATOK SLOVA (rovnaky idiom ako
# NX_DOG_DONE_RE nizsie): "nehotove" je opak a v plane je legitimne (review #233 P2).
# Chyta sa cela rodina tvarov hotov- (HOTOVE/HOTOVO/HOTOVA/HOTOVY — review #233 kolo 4).
NX_PLAN_DONE_RE = /(?<![[:alpha:]])(?:hotov[áéeoý]|komplet)|✅/.freeze
NxTest.test('docs: PLAN.md nema nadpis hotoveho bloku (KOMPLET / HOTOVE / fajka)') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'PLAN.md')
  offenders = File.read(path, encoding: 'UTF-8').lines.map(&:rstrip).select do |l|
    l.start_with?('#') && l.downcase.match?(NX_PLAN_DONE_RE)
  end
  NxTest.assert(offenders.empty?,
                "PLAN.md ma nadpis hotoveho bloku (#{offenders.join(' · ')}) — presun blok plnym " \
                'textom do SYSTEM/archiv/ROADMAP_hotove_etapy.md; PLAN drzi len nehotove veci')
end

# To iste pre zapisnik: vyriesene D-cisla ziju v archive (plny text + index), tu by
# len duplikovali a rastli donekonecna. Slovnik repa pozna "vyriesene" aj "zavrete"
# (D-26 je "ZAVRETE bez implementacie"), preto sa chytaju obe a case-insensitive.
#
# Hranica je ZACIATOK SLOVA, nie holy include: je to silnejsie nez lookbehind na "ne"
# a chyta obe pasce naraz — "nevyriesene" (opak) aj "uzavretom" (v ktorom je "zavreto"
# ako podretazec). Oboje je legitimny text nadpisu (review #233 kolo 2 P2).
NX_DOG_DONE_RE = /(?<![[:alpha:]])(?:vyriešen|zavret)/.freeze
NxTest.test('docs: DOGFOODING.md nema sekciu vyriesenych (Vyriesene / Zavrete)') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'DOGFOODING.md')
  offenders = File.read(path, encoding: 'UTF-8').lines.map(&:rstrip).select do |l|
    l.start_with?('#') && l.downcase.match?(NX_DOG_DONE_RE)
  end
  NxTest.assert(offenders.empty?,
                "DOGFOODING.md ma sekciu vyriesenych (#{offenders.join(' · ')}) — plny text aj " \
                'index patria do SYSTEM/archiv/DOGFOODING_vyriesene.md; tu ostavaju len otvorene postrehy')
end

NxTest.test('docs: SYSTEM/README.md existuje — mapa autorit priecinka') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'README.md')
  NxTest.assert(File.exist?(path),
                'SYSTEM/README.md chyba — bez mapy autorit agent nevie, ktory dokument plati na co')
end

NxTest.test('docs: kazdy koncept v zdroje/next_sessions/ nesie status riadok') do
  dir = File.join(NxTest::ROOT, 'SYSTEM', 'zdroje', 'next_sessions')
  NxTest.assert(Dir.exist?(dir), 'SYSTEM/zdroje/next_sessions/ chyba')
  files = Dir.glob(File.join(dir, '*.md')).sort
             .reject { |f| File.basename(f) == 'README.md' }
  NxTest.assert(files.length > 5, "nenasiel som koncepty (#{files.length}) — zla cesta?")
  # Status musi byt PRVY obsahovy riadok hned pod H1 — nie kdekolvek v subore.
  # Riadok schovany na konci dlheho dokumentu nikto necita, a prave to ma zabranit
  # tomu, aby sa koncept precital ako zadanie (review #233 P2).
  missing = files.reject do |f|
    lines = File.readlines(f, encoding: 'UTF-8').map(&:rstrip)
    h1 = lines.index { |l| l.start_with?('# ') }
    next false if h1.nil? # chybajuci H1 hlasi test nizsie

    first = lines[(h1 + 1)..].to_a.find { |l| !l.strip.empty? }
    first.to_s.start_with?(NX_NEXT_SESSIONS_STATUS)
  end
  NxTest.assert(missing.empty?,
                "Koncepty, ktorym '#{NX_NEXT_SESSIONS_STATUS}' nie je PRVY riadok pod nadpisom: " \
                "#{missing.map { |f| File.basename(f) }.join(' · ')} — status patri hned pod H1, " \
                'inak vyzera koncept ako zadanie a agent ho moze zacat implementovat')

  # H1 je podmienkou guardu vyssie — bez neho by sa status nemal k comu vztiahnut.
  no_h1 = files.reject do |f|
    File.readlines(f, encoding: 'UTF-8').any? { |l| l.start_with?('# ') }
  end
  NxTest.assert(no_h1.empty?,
                "Koncepty bez H1 nadpisu: #{no_h1.map { |f| File.basename(f) }.join(' · ')}")
end

NxTest.test('docs: STAV.md ma vsetkych 5 povinnych sekcii') do
  src = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'STAV.md'), encoding: 'UTF-8')
  headings = src.lines.map(&:rstrip).select { |l| l.start_with?('## ') }
  missing = NX_STAV_SECTIONS.reject { |h| headings.include?(h) }
  NxTest.assert(missing.empty?,
                "STAV.md nema povinne sekcie: #{missing.join(' · ')} (najdene: #{headings.join(' · ')})")
end

NxTest.test('docs: docs/ARCHITEKTURA.md existuje a je jedinym miestom architektury') do
  arch = File.join(NxTest::ROOT, 'docs', 'ARCHITEKTURA.md')
  NxTest.assert(File.exist?(arch),
                'docs/ARCHITEKTURA.md chyba — je to referencna mapa modulov (davka U3)')
  src = File.read(arch, encoding: 'UTF-8')
  %w[Core Modules].each do |sec|
    NxTest.assert(src.include?("### #{sec}"), "docs/ARCHITEKTURA.md nema sekciu ### #{sec}")
  end
end

NxTest.test('docs: ARCHITEKTURA.md je ROUTER — kratky a odkazuje na docs/architecture/') do
  arch = File.join(NxTest::ROOT, 'docs', 'ARCHITEKTURA.md')
  lines = File.readlines(arch, encoding: 'UTF-8').length
  NxTest.assert(lines <= NX_ARCH_ROUTER_MAX_LINES,
                "ARCHITEKTURA.md ma #{lines} riadkov (limit #{NX_ARCH_ROUTER_MAX_LINES}) — " \
                'odseky modulov patria do docs/architecture/, tu ostava len rozcestnik')
  src = File.read(arch, encoding: 'UTF-8')
  NX_ARCH_FILES.each do |name|
    NxTest.assert(src.include?("architecture/#{name}"),
                  "ARCHITEKTURA.md neodkazuje na architecture/#{name} — mapa by sa nedala najst")
  end
end

NxTest.test('docs: docs/architecture/ ma vsetkych 6 suborov mapy') do
  dir = File.join(NxTest::ROOT, 'docs', 'architecture')
  NxTest.assert(Dir.exist?(dir), 'docs/architecture/ chyba — tam ziju odseky modulov')
  missing = NX_ARCH_FILES.reject { |n| File.exist?(File.join(dir, n)) }
  NxTest.assert(missing.empty?, "docs/architecture/ nema subory: #{missing.join(' · ')}")
end

# Jeden odsek na jednom obrom riadku znamena necitatelny diff a nemozne review.
NxTest.test('docs: ARCHITEKTURA.md a docs/architecture/*.md nemaju riadok nad 400 znakov') do
  paths = [File.join(NxTest::ROOT, 'docs', 'ARCHITEKTURA.md')] +
          Dir.glob(File.join(NxTest::ROOT, 'docs', 'architecture', '*.md')).sort
  offenders = []
  paths.each do |path|
    File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
      len = line.rstrip.length
      offenders << "#{path.sub(NxTest::ROOT.to_s, '').tr('\\', '/')}:#{i + 1} (#{len})" if len > NX_ARCH_MAX_LINE
    end
  end
  NxTest.assert(offenders.empty?,
                "Riadky nad #{NX_ARCH_MAX_LINE} znakov: #{offenders.join(', ')} — " \
                'rozbi odsek na kratsie riadky (Markdown ich spoji do jedneho odseku)')
end

# Mapa nesmie zaostat za kodom. Zmienka v proze NESTACI — genericke meno (napr.
# core/report.rb) by sa nahodne trafilo do vety a modul by prekizol bez dokumentacie.
# Kontroluju sa TRI veci: vlastny nadpis v mape, riadok v tabulke routra a
# jednoznacnost basename napriec inventarom.
# Pozaduje sa preto EXPLICITNY nadpis `### <basename>.rb` v niektorom suboru mapy
# (povoleny je aj zdruzeny tvar `### <basename>.rb + nieco` / `### <basename>.rb — nieco`)
# A ZAROVEN riadok v tabulke routra, aby sa modul dal najst aj z rozcestnika.
#
# IDENTITA MODULU JE BASENAME — konvencia nadpisov `### <basename>.rb` je tym
# jednoducha a grepovatelna, ale plati len dovtedy, kym su basename jednoznacne.
# Dva rovnomenne subory v roznych priecinkoch (napr. core/client.rb popri
# core/demos/client.rb) by sa v mape zliali do jedneho nadpisu a novy modul by
# presiel nezdokumentovany. Kolizia sa preto detekuje VYSLOVNE (test nizsie) —
# guard sa kvoli nej neoslabuje, riesi sa v mape.
#
# INVENTAR je core/ + modules/ + ui/ — ruby moduly UI vrstvy (dialogy, domeny
# panela, jadro vystupov) su rovnako sucastou architektury ako core; bez nich by
# novy dialog prekizol vsetkymi tromi kontrolami (review #232 kolo 3).
# Su to VYHRADNE .rb subory: js/html/css do inventara nepatria (mapa ich popisuje
# v odsekoch, ale nemaju vlastne nadpisy).
NX_ARCH_MODULE_DIRS = '{core,modules,ui}'

def nx_arch_module_paths
  root = NxTest::ROOT.to_s.tr('\\', '/').chomp('/')
  Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', NX_ARCH_MODULE_DIRS, '**', '*.rb')).sort
     .map { |p| p.tr('\\', '/').sub("#{root}/", '') }
end

def nx_arch_modules
  nx_arch_module_paths.map { |p| File.basename(p, '.rb') }.uniq.sort
end

def nx_arch_headings
  Dir.glob(File.join(NxTest::ROOT, 'docs', 'architecture', '*.md')).sort.flat_map do |f|
    File.readlines(f, encoding: 'UTF-8').map(&:rstrip).select { |l| l.start_with?('### ') }
  end
end

# Tokeny v spatnych apostrofoch z tabulkovych riadkov routra (riadok zacina '|').
def nx_router_tokens
  File.readlines(File.join(NxTest::ROOT, 'docs', 'ARCHITEKTURA.md'), encoding: 'UTF-8')
      .map(&:rstrip).select { |l| l.start_with?('|') }
      .join("\n").scan(/`([^`]+)`/).flatten
end

NxTest.test('docs: basename modulu je jednoznacny — ziadna kolizia medzi priecinkami') do
  paths = nx_arch_module_paths
  NxTest.assert(paths.length > 40, "nenasiel som moduly (#{paths.length}) — zla cesta?")
  clashes = paths.group_by { |p| File.basename(p, '.rb') }.select { |_, v| v.length > 1 }
  detail = clashes.map { |base, v| "#{base}.rb: #{v.join(' vs ')}" }.join(' · ')
  NxTest.assert(clashes.empty?,
                "Kolizia basename modulov (#{detail}) — mapa docs/architecture/ rozlisuje moduly " \
                'nadpisom `### <basename>.rb`, takze dva rovnomenne subory by sa v nej zliali a jeden ' \
                'by presiel nezdokumentovany. Rozlis ich v mape plnou cestou (a uprav identitu v tomto ' \
                'guarde), alebo jeden z modulov premenuj.')
end

NxTest.test('docs: kazdy modul core/, modules/ a ui/ ma vlastny nadpis v docs/architecture/') do
  mods = nx_arch_modules
  NxTest.assert(mods.length > 40, "nenasiel som moduly (#{mods.length}) — zla cesta?")
  headings = nx_arch_headings
  missing = mods.reject do |m|
    re = /\A### #{Regexp.escape(m)}\.rb(?:\s|\z)/
    headings.any? { |h| h =~ re }
  end
  NxTest.assert(missing.empty?,
                "Moduly bez vlastneho nadpisu '### <meno>.rb' v docs/architecture/: " \
                "#{missing.join(' · ')} — pridaj im odsek (aspon stub) do prislusneho suboru mapy")
end

NxTest.test('docs: kazdy modul core/, modules/ a ui/ je v tabulke routra ARCHITEKTURA.md') do
  tokens = nx_router_tokens
  NxTest.assert(tokens.length > 40, "router nema tabulkove riadky s modulmi (#{tokens.length})")
  # Router pise moduly raz holym menom (`units`), raz s priponou (`panel.rb`) — obe plati.
  missing = nx_arch_modules.reject { |m| tokens.include?(m) || tokens.include?("#{m}.rb") }
  NxTest.assert(missing.empty?,
                "Moduly chybajuce v tabulke routra docs/ARCHITEKTURA.md: #{missing.join(' · ')} — " \
                'doplnit do riadku sekcie Core/Modules/UI, inak sa modul z rozcestnika nedohlada')
end

# CLAUDE.md sa nacitava AUTOMATICKY kazde sedenie — architektura sa don nesmie vratit
# (davka U3 ju presunula do docs/ARCHITEKTURA.md). Guard proti recidive.
NxTest.test('docs: CLAUDE.md neobsahuje nadpis sekcie Architektura') do
  path = File.join(NxTest::ROOT, 'CLAUDE.md')
  NxTest.assert(File.exist?(path), 'CLAUDE.md chyba')
  offenders = File.read(path, encoding: 'UTF-8').lines.map(&:rstrip).select do |l|
    l.start_with?('## ') && l.downcase.include?('architekt')
  end
  NxTest.assert(offenders.empty?,
                "CLAUDE.md ma nadpis architektury (#{offenders.join(' · ')}) — patri do docs/ARCHITEKTURA.md")
end

NxTest.test('docs: CLAUDE.md odkazuje na docs/ARCHITEKTURA.md') do
  src = File.read(File.join(NxTest::ROOT, 'CLAUDE.md'), encoding: 'UTF-8')
  NxTest.assert(src.include?('docs/ARCHITEKTURA.md'),
                'CLAUDE.md neodkazuje na docs/ARCHITEKTURA.md — agent by mapu modulov nenasiel')
end

NxTest.test('docs: relativne odkazy v navigacnych suboroch ukazuju na existujuce subory') do
  broken = []
  names = %w[CLAUDE.md docs/ARCHITEKTURA.md SYSTEM/README.md SYSTEM/STAV.md SYSTEM/PLAN.md
             SYSTEM/DOGFOODING.md SYSTEM/V1_VIZIA.md] +
          NX_ARCH_FILES.map { |n| "docs/architecture/#{n}" }
  names.each do |name|
    path = File.join(NxTest::ROOT, name)
    NxTest.assert(File.exist?(path), "#{name} chyba")
    dir = File.dirname(path)
    File.read(path, encoding: 'UTF-8').scan(/\]\(([^)\s]+)\)/).each do |(target)|
      next if target.start_with?('http://', 'https://', 'mailto:', '#')

      rel = target.split('#').first
      next if rel.nil? || rel.empty?

      full = File.expand_path(rel, dir)
      broken << "#{name} → #{target}" unless File.exist?(full)
    end
  end
  NxTest.assert(broken.empty?, "Rozbite odkazy v navigacii docs: #{broken.join(', ')}")
end
