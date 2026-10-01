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

# Davka H1 (blok 9 · HARDENING, 1.10.2026, krizovy audit V1 B-04): PLAN.md narastol na
# 116 kB / 721 riadkov, z toho ~86 % tvorili hotove bloky, ktore sa nikdy formalne
# neuzavreli — a PLAN je povinne citanie kazdej novej davky. Strop = ~2x velkosti
# ziveho PLANu po uprataní (zaokruhlene): prestane stacit az vtedy, ked sa hotovy blok
# zabudne presunut do archiv/ROADMAP_hotove_etapy.md, nie pri beznom raste bloku.
NX_PLAN_MAX_LINES = 280
NX_PLAN_MAX_BYTES = 40 * 1024

# Davka "Docs cleanup B" (26.8.2026): SYSTEM/ ma vrstvy — zive docs (nizsie), zdroje/
# (nezavazne koncepty, necitaju sa automaticky) a archiv/ (historia, append-only).
# Mapu autorit drzi SYSTEM/README.md.
# Zoznam je EXPLICITNY, nie glob: archiv/ a zdroje/ sa vedome nestrazia (su to
# historicke texty, ktore sa nesmu prepisovat kvoli zalomeniu).
# Davka "Docs cleanup C" (26.8.2026) doplnila STANDARD.md a POJMY.md — po
# reflowe uz ziadny zivy dokument v SYSTEM/ nema vynimku.
# Davka workflowu (PR B, 26.9.2026) doplnila WORKFLOW.md — mapa workflowu je zivy dokument.
NX_SYSTEM_LINE_FILES = %w[
  STAV.md PLAN.md DOGFOODING.md README.md V1_VIZIA.md VEPO_KONTRAKT.md AUDIT_REGISTER.md
  STANDARD.md POJMY.md WORKFLOW.md
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
  hardware.md appliances.md outputs.md ui-lifecycle.md
].freeze
# Dlhy riadok = necitatelny diff (jeden odsek = jeden riadok bola presne choroba,
# ktoru tato davka liecila). Plati na router aj na mapu; SYSTEM/ je mimo rozsah.
NX_ARCH_MAX_LINE = 400

# Davka H5a (blok 9 · HARDENING, 1.10.2026, krizovy audit V1 B-02/B-03, CS-04):
# ui-lifecycle.md narastol na 551 kB, lebo kazda davka pridavala do odsekov
# priebeh prac (cisla PR, kola review, zaniknute okna) — agent potom nevedel, ktora
# zo stoviek historickych viet este plati. Historia sa presunula plnym textom do
# SYSTEM/archiv/UI_LIFECYCLE_historia_do_v0.17.md a ziva mapa ma 253 kB.
# STROP = ~1,3x velkosti po upratani (pri ostatnych suboroch ~1,3x dnesnej velkosti,
# zaokruhlene na kB) — prestane stacit az vtedy, ked sa zive odseky zacnu znova
# nafukovat historiou, nie pri beznom raste. Merane v bajtoch na disku (CRLF aj LF
# checkout sa zmesti; hodnoty reportovacieho behu su v PR davky H5a).
NX_ARCH_MAX_BYTES = {
  'ui-lifecycle.md' => 330 * 1024,
  'hardware.md' => 270 * 1024,
  'construction.md' => 230 * 1024,
  'outputs.md' => 215 * 1024,
  'materials.md' => 95 * 1024,
  'model-a-identita.md' => 90 * 1024,
  'appliances.md' => 62 * 1024
}.freeze
# Historicke znacky smu v upratanych suboroch mapy stat LEN vo vyhradenej sekcii
# „## História" na konci suboru (zaniknute okna, odkaz do archivu). Ostatne subory
# mapy este upratane nie su — pribudnu sem, ked ich niektora davka uprace.
NX_ARCH_HISTORY_FILES = %w[ui-lifecycle.md].freeze
NX_ARCH_HISTORY_HEADING = '## História'

# Davka H5b (blok 9 · HARDENING, 1.10.2026, krizovy audit V1 B-05/B-03, CS-06, CN-08/CN-09):
# docs/UI_DIZAJN.md je NORMA (tokeny, typografia, ikony, komponentove vzory) a povinne citanie
# KAZDEJ UI davky — mal v sebe aj dennik davok (verzie, PR, kola review, zaniknute okna) a
# zastarane vety (semafor „nikde sa nepouziva", inventar ikon „uplny k v0.7.28"). Dennik sa
# presunul plnym textom do SYSTEM/archiv/UI_DIZAJN_dennik_do_v0.17.md. Ten isty mechanizmus ako
# H5a: strop velkosti ~1,3x po upratani (dnes ~121 kB na disku s CRLF), historicke znacky len
# v sekcii „## História" na konci a k tomu inventar ikon §4 = kazdy kluc spritu icons.js.
NX_UI_DIZAJN = File.join('docs', 'UI_DIZAJN.md')
NX_UI_DIZAJN_MAX_BYTES = 160 * 1024
# Znacky sa hladaju BEZ OHLADU na velkost pismen a s toleranciou Markdownu a medzier
# (`Review #226`, `V0.4.7`, `PR **#438**`, `PR  #438` su v repe bezne zapisy) — riadok sa
# pred porovnanim normalizuje (`nx_arch_history_norm`: bez `*` a spatnych apostrofov,
# medzery zlucene). ZANIKL ostava VERZALKAMI: male „zaniklo" je bezne slovo opisu.
NX_ARCH_HISTORY_RE = /\b(?:PR|review|Codex|audit|GH)\s*#\s*\d|\bv\d+\.\d+\.\d+\b/i.freeze
# Pismenove oznacenia PR z fazy STUDIO (`PR A`, `PR B1`, `ŠT-1c PR B3`) su v repe bezna
# forma — chytaju sa tiez, ale LEN verzalkami (male „pr a" by bol falosny poplach).
NX_ARCH_HISTORY_CAPS_RE = /ZANIKL|\bPR\s+[A-Z]\d{0,2}\b/.freeze

def nx_arch_history_norm(line)
  line.gsub(/[*`]/, '').gsub(/\s+/, ' ')
end

def nx_arch_history_marker(line)
  norm = nx_arch_history_norm(line)
  norm[NX_ARCH_HISTORY_RE] || norm[NX_ARCH_HISTORY_CAPS_RE]
end

# Problemy upratanych suborov mapy nad riadkami (cista funkcia — testuje sa aj nad
# syntetickymi vstupmi): chybajuca sekcia Historia, AKYKOLVEK nadpis za nou (aj `###` —
# inak by sa zivy odsek pripojeny za historiu vyhol zakazu znaciek) a znacky pred nou.
def nx_arch_history_problems(name, lines)
  hist = lines.index(NX_ARCH_HISTORY_HEADING)
  return ["#{name}: chyba vyhradena sekcia '#{NX_ARCH_HISTORY_HEADING}'"] unless hist

  later = lines[(hist + 1)..].to_a.select { |l| l.match?(/\A\#{1,6}\s/) }
  problems = later.map { |l| "#{name}: za sekciou '#{NX_ARCH_HISTORY_HEADING}' je nadpis '#{l}' (musi byt posledna)" }
  lines[0...hist].each_with_index do |l, i|
    m = nx_arch_history_marker(l)
    problems << "#{name}:#{i + 1} znacka '#{m}'" if m
  end
  problems
end

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

NxTest.test('docs: SYSTEM/PLAN.md ma strop riadkov a kB (hotove bloky patria do archivu)') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'PLAN.md')
  lines = File.readlines(path, encoding: 'UTF-8').length
  size = File.size(path)
  NxTest.assert(lines <= NX_PLAN_MAX_LINES && size <= NX_PLAN_MAX_BYTES,
                "PLAN.md ma #{lines} riadkov a #{size} B (limit #{NX_PLAN_MAX_LINES} riadkov / " \
                "#{NX_PLAN_MAX_BYTES} B) — hotovy blok alebo hotovu cast presun plnym textom do " \
                'SYSTEM/archiv/ROADMAP_hotove_etapy.md; zadania davok patria do priecinka bloku')
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

NxTest.test('docs: docs/architecture/ ma vsetky subory mapy') do
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

NxTest.test('docs: kazdy subor docs/architecture/ ma strop velkosti (historia patri do archivu)') do
  # Inventar ADRESARA, nie len zoznam NX_ARCH_FILES: novy subor mapy bez stropu = pad.
  present = Dir.glob(File.join(NxTest::ROOT, 'docs', 'architecture', '*.md')).map { |p| File.basename(p) }.sort
  NxTest.assert(present.length >= NX_ARCH_FILES.length, "nenasiel som subory mapy (#{present.length}) — zla cesta?")
  missing = (present | NX_ARCH_FILES).reject { |n| NX_ARCH_MAX_BYTES.key?(n) }
  NxTest.assert(missing.empty?, "subory mapy bez stropu velkosti: #{missing.join(' · ')} — dopln NX_ARCH_MAX_BYTES")
  over = NX_ARCH_MAX_BYTES.filter_map do |name, max|
    path = File.join(NxTest::ROOT, 'docs', 'architecture', name)
    next "#{name} chyba (strop bez suboru — odstran ho z NX_ARCH_MAX_BYTES)" unless File.exist?(path)

    size = File.size(path)
    "#{name} #{size} B (strop #{max} B)" if size > max
  end
  NxTest.assert(over.empty?,
                "Subory mapy prekrocili strop: #{over.join(' · ')} — priebeh prac (PR, review, zaniknute " \
                'riesenia) patri do SYSTEM/archiv/KRONIKA.md alebo do archivu suboru; odsek drzi len aktualny kontrakt')
end

NxTest.test('docs: upratane subory mapy nemaju historicke znacky mimo sekcie Historia') do
  NX_ARCH_HISTORY_FILES.each do |name|
    lines = File.readlines(File.join(NxTest::ROOT, 'docs', 'architecture', name), encoding: 'UTF-8').map(&:rstrip)
    problems = nx_arch_history_problems(name, lines)
    NxTest.assert(problems.empty?,
                  "Historicke znacky mimo sekcie Historia: #{problems.first(10).join(' · ')} — cislo PR, kolo review, " \
                  "verzia ani 'ZANIKLO' do ziveho odseku nepatria (KRONIKA, archiv, alebo sekcia '#{NX_ARCH_HISTORY_HEADING}' " \
                  'na konci suboru, za ktorou uz ziadny nadpis nie je)')
  end
end

# Negativne pripady guardu nad syntetickymi riadkami — guard nesmie mlcat pri zapisoch,
# ktore v repe bezne existuju, a nesmie hlasit bezny opis (falosny poplach).
NxTest.test('docs: guard historickych znaciek chyta varianty zapisu a nadpis za Historiou') do
  ok = ['# Mapa', '', '### Sekcia X', 'zaniklo v sekcii, verzia v0.17.x, Š8–Š11, audit B1 FIX 5, čísla PR, kolá review', '',
        NX_ARCH_HISTORY_HEADING, 'Výroba ZANIKLO v ŠT-1c PR #212 (review #2)']
  NxTest.assert(nx_arch_history_problems('t.md', ok).empty?,
                "falosny poplach: #{nx_arch_history_problems('t.md', ok).join(' · ')}")
  ['Review #226', 'V0.4.7', 'PR **#438**', 'PR  #438', '`PR #12`', 'codex #3', 'GH #138', 'AUDIT #9', 'okno ZANIKLO',
   'PR A', 'v ŠT-1c PR B1', 'PR B3', '**PR B2**'].each do |bad|
    lines = ['# Mapa', "text #{bad} text", NX_ARCH_HISTORY_HEADING]
    NxTest.refute(nx_arch_history_problems('t.md', lines).empty?, "guard nezachytil znacku '#{bad}'")
  end
  %w[## ### ####].each do |lvl|
    lines = ['# Mapa', NX_ARCH_HISTORY_HEADING, 'veta', "#{lvl} foo.rb", 'zivy odsek PR #1']
    NxTest.refute(nx_arch_history_problems('t.md', lines).empty?, "nadpis '#{lvl}' za Historiou presiel")
  end
  NxTest.refute(nx_arch_history_problems('t.md', ['# Mapa', 'bez historie']).empty?, 'chybajuca sekcia Historia presla')
end

# Zaniknuty subor nesmie mat ZIVY modulovy nadpis (CS-07): nadpis `### <subor>.rb|js|html|css`
# v mape musi menovat subor, ktory v noxun_engine/ naozaj je. Zaniknute okna patria do
# sekcie Historia ako veta, nie ako vlastny odsek, inak agent hlada neexistujucu cestu.
NxTest.test('docs: modulove nadpisy v docs/architecture/ menuju existujuce subory') do
  root = File.join(NxTest::ROOT, 'noxun_engine')
  existing = Dir.glob(File.join(root, '**', '*.{rb,js,html,css}')).map { |p| File.basename(p) }.uniq
  NxTest.assert(existing.length > 40, "nenasiel som subory pluginu (#{existing.length}) — zla cesta?")
  dead = Dir.glob(File.join(NxTest::ROOT, 'docs', 'architecture', '*.md')).sort.flat_map do |f|
    File.readlines(f, encoding: 'UTF-8').filter_map do |l|
      m = l.match(/\A### (\S+\.(?:rb|js|html|css))(?:\s|\z)/)
      "#{File.basename(f)}: #{m[1]}" if m && !existing.include?(File.basename(m[1]))
    end
  end
  NxTest.assert(dead.empty?,
                "Nadpisy suborov, ktore v kode nie su: #{dead.join(' · ')} — zaniknuty subor patri do sekcie " \
                "'#{NX_ARCH_HISTORY_HEADING}' ako veta s odkazom do archivu, nie ako zivy odsek")
end

NxTest.test('docs: UI_DIZAJN.md ma strop velkosti (norma, dennik davok patri do archivu)') do
  path = File.join(NxTest::ROOT, NX_UI_DIZAJN)
  size = File.size(path)
  NxTest.assert(size <= NX_UI_DIZAJN_MAX_BYTES,
                "UI_DIZAJN.md ma #{size} B (strop #{NX_UI_DIZAJN_MAX_BYTES} B) — norma opisuje pravidlo, nie priebeh prac; " \
                'ktora davka co zaviedla patri do SYSTEM/archiv/KRONIKA.md')
end

NxTest.test('docs: UI_DIZAJN.md nema historicke znacky mimo sekcie Historia') do
  lines = File.readlines(File.join(NxTest::ROOT, NX_UI_DIZAJN), encoding: 'UTF-8').map(&:rstrip)
  problems = nx_arch_history_problems('UI_DIZAJN.md', lines)
  NxTest.assert(problems.empty?,
                "Historicke znacky mimo sekcie Historia: #{problems.first(10).join(' · ')} — cislo PR, kolo review, " \
                "verzia ani 'ZANIKLO' do normy nepatria (KRONIKA, archiv, alebo sekcia '#{NX_ARCH_HISTORY_HEADING}' na konci)")
end

# CN-09 bod 5: veta „inventar je uplny" klamala, lebo ikony pribudali bez riadku v §4.
# Teraz je to kontrola: KAZDY symbol, ktory sprite vygeneruje (`<symbol id="i-…">`), stoji v §4
# ako `kluc`. Symboly vznikaju dvoma cestami (Codex #440 P2): sluckou nad objektom `LUCIDE`
# (dynamicke `'<symbol id="i-' + id`) a samostatnymi literalmi (`LOGO` = `<symbol id="i-logo"`).
# Guard berie obe; dynamicka cesta mimo slucky LUCIDE (druha mapa symbolov) je pad — inak by
# jej symboly presli bez kontroly.
def nx_sprite_symbol_ids(src)
  lucide = src[/var LUCIDE = \{(.*?)\n  \};/m, 1].to_s.scan(/^    '([a-z0-9-]+)':/).flatten
  literal = src.scan(/<symbol id="i-([a-z0-9-]+)"/).flatten
  dynamic = src.scan(/'<symbol id="i-' \+/).length
  [(lucide + literal).uniq, dynamic]
end

def nx_icon_inventory_missing(ids, doc)
  sec4 = doc[/^## 4\. Ikony.*?(?=^## 5\.)/m].to_s
  return nil if sec4.empty?

  ids.reject { |i| sec4.include?("`#{i}`") }
end

NxTest.test('docs: inventar ikon UI_DIZAJN §4 obsahuje kazdy symbol spritu icons.js') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'), encoding: 'UTF-8')
  ids, dynamic = nx_sprite_symbol_ids(src)
  NxTest.assert(ids.length > 50, "nenasiel som symboly spritu (#{ids.length}) — zmenil sa tvar icons.js?")
  NxTest.assert(ids.include?('logo'), 'samostatne generovany symbol `logo` (LOGO) guard nevidi')
  NxTest.assert_equal(1, dynamic,
                      'icons.js sklada <symbol id="i-…"> dynamicky inde nez v slucke nad LUCIDE — rozsir nx_sprite_symbol_ids')
  missing = nx_icon_inventory_missing(ids, File.read(File.join(NxTest::ROOT, NX_UI_DIZAJN), encoding: 'UTF-8'))
  NxTest.assert(!missing.nil?, 'UI_DIZAJN.md nema sekciu ## 4. Ikony pred ## 5.')
  NxTest.assert(missing.empty?,
                "Ikony zo spritu bez riadku v inventari UI_DIZAJN §4: #{missing.join(' · ')} — dopln ich s popisom, kde sa kreslia")
end

# Negativne pripady nad syntetickym spritom: samostatny literal (vzor LOGO) aj kluc LUCIDE
# musia byt videne a chybajuci riadok v §4 musi byt nahlaseny.
NxTest.test('docs: guard inventara ikon vidi samostatne symboly a hlasi chybajuci riadok') do
  src = "  var LUCIDE = {\n    'aa': '<path/>',\n    'bb-c': '<path/>'\n  };\n" \
        "  var LOGO = '<symbol id=\"i-logo\" viewBox=\"0 0 1 1\">' + '</symbol>';\n" \
        "  var X = '<symbol id=\"i-extra\">';\n  s += '<symbol id=\"i-' + id + '\">';\n"
  ids, dynamic = nx_sprite_symbol_ids(src)
  NxTest.assert_equal(%w[aa bb-c logo extra], ids)
  NxTest.assert_equal(1, dynamic)
  doc = "## 4. Ikony\n`aa` · `bb-c` · `extra`\n## 5. Vzory\n`logo`\n"
  NxTest.assert_equal(['logo'], nx_icon_inventory_missing(ids, doc), 'logo mimo §4 musi chybat')
  NxTest.assert_equal([], nx_icon_inventory_missing(ids, doc.sub('`extra`', '`extra` · `logo`')))
  NxTest.assert(nx_icon_inventory_missing(ids, "## 5. Vzory\n").nil?, 'chybajuca §4 musi byt nahlasena')
  _, dyn2 = nx_sprite_symbol_ids(src + "  t += '<symbol id=\"i-' + k;\n")
  NxTest.assert_equal(2, dyn2, 'druha dynamicka cesta musi byt zachytena')
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
# NASTROJE-1: `tools/` je od T1a plnohodnotny priecinok modulov (Mower, Snaper) —
# patri do inventara rovnako ako core/ a ui/, inak by novy nastroj presiel bez
# odseku v mape aj bez riadku v routri.
NX_ARCH_MODULE_DIRS = '{core,modules,tools,ui}'

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
             SYSTEM/DOGFOODING.md SYSTEM/V1_VIZIA.md SYSTEM/WORKFLOW.md docs/UI_DIZAJN.md] +
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
