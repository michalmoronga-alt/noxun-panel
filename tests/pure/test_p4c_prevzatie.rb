# frozen_string_literal: true
# Guard dávky P4c (blok 10 PRAVIDLA): prevzatie práce — karta priebehu (šablóna ↔ scripts/rozpracovane.ps1),
# scripts/rozpracovane.ps1 nad dočasným repom, scripts/lib/nx_text.ps1, KRONIKA po súboroch (číslo PR v
# SYSTEM/zdroje/bloky/*/kronika/*.md) a scripts/session_digest.rb nad vymyslenou fixtúrou.
# Skripty berú Windows PowerShell 5.1 (Michalov PC) aj pwsh (CI ubuntu); bez PowerShellu sa testy skriptov preskočia.
# `gh` je nahradený stubom (-Gh); dočasné repozitáre (git init + bare origin) sú v os.tmpdir.
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'tmpdir'
require_relative '../helper' unless defined?(NxTest)
require_relative 'test_p4a_skripty' # NxP4a (pomocníci pre PowerShell a dočasné repozitáre)

module NxP4c
  ROOT = NxTest::ROOT
  TEMPLATE = File.join(ROOT, 'SYSTEM', 'pravidla', 'sablony', 'PRIEBEH.md')
  ROZP = File.join(ROOT, 'scripts', 'rozpracovane.ps1')

  def self.read(path)
    File.binread(path).force_encoding('UTF-8').gsub("\r\n", "\n")
  end

  # Regexy poľa karty z rozpracovane.ps1 ($NxReState, $NxReNext) ako Ruby Regexp.
  def self.field_regex(name)
    src = read(ROZP)[/^\$#{name} = '(.*)'$/, 1]
    raise "rozpracovane.ps1: chyba $#{name}" unless src

    Regexp.new(src, Regexp::IGNORECASE)
  end

  # Hodnota poľa (prvý zhodný riadok) alebo nil.
  def self.field(text, name)
    re = field_regex(name)
    text.each_line { |l| m = re.match(l.chomp); return m[1] if m }
    nil
  end

  def self.cards
    (Dir[File.join(ROOT, 'SYSTEM', 'zdroje', 'bloky', '*', 'priebeh', '*.md')] +
     Dir[File.join(ROOT, 'SYSTEM', 'zdroje', 'opravy', 'priebeh', '*.md')]).sort
  end
end

NxTest.test('p4c: nove skripty su ASCII (PS 5.1 cita .ps1 bez BOM v systemovej kodovej stranke)') do
  %w[rozpracovane.ps1 start_okna.ps1 lib/nx_text.ps1 lib/nx_pr.ps1 otvor_pr.ps1].each do |f|
    bytes = File.binread(File.join(NxP4a::SCRIPTS, f)).bytes
    NxTest.assert(bytes.all? { |b| b < 128 }, "#{f} musi byt ASCII")
  end
end

NxTest.test('p4c: To-SafeLine ma jeden domov (lib/nx_text.ps1); start_okna.ps1 aj rozpracovane.ps1 ho nacitavaju, nie kopiruju') do
  NxTest.assert(NxP4c.read(File.join(NxP4a::SCRIPTS, 'lib', 'nx_text.ps1')).include?('function To-SafeLine'), 'nx_text.ps1 definuje To-SafeLine')
  %w[start_okna.ps1 rozpracovane.ps1].each do |f|
    src = NxP4c.read(File.join(NxP4a::SCRIPTS, f))
    NxTest.refute(src.include?('function To-SafeLine'), "#{f}: To-SafeLine sa nekopiruje")
    NxTest.assert(src.include?("'nx_text.ps1'"), "#{f}: nacitava lib/nx_text.ps1")
  end
  start = NxP4c.read(File.join(NxP4a::SCRIPTS, 'start_okna.ps1'))
  NxTest.assert(start.include?("'rozpracovane.ps1'"), 'start_okna.ps1 vola rozpracovane.ps1')
  # Vypis rozpracovanej prace musi prebehnut aj pri predcasnom konci (register nedostupny) — pred kazdym `exit 0`.
  parts = start.split(/^[ \t]*exit 0$/)
  NxTest.assert(parts.length >= 3, 'start_okna.ps1 ma aspon dva exit 0')
  parts[0..-2].each_with_index do |chunk, i|
    NxTest.assert(chunk.lines.last(3).any? { |l| l.include?('Write-Rozpracovane') }, "Write-Rozpracovane tesne pred exit 0 c. #{i + 1}")
  end
end

NxTest.test('p4c: sablona karty priebehu obsahuje polia, ktore cita rozpracovane.ps1; vsetky existujuce karty sa daju precitat') do
  tpl = NxP4c.read(NxP4c::TEMPLATE)
  NxTest.assert_equal('aktívna', NxP4c.field(tpl, 'NxReState'), 'sablona: Stav')
  NxTest.assert(!NxP4c.field(tpl, 'NxReNext').to_s.empty?, 'sablona: Ďalší krok')
  %w[Zadanie Trieda Vetva Základ Robil].each { |k| NxTest.assert(tpl.match?(/^#{k}:\s*\S/), "sablona: pole #{k}") }
  %w[Hotové\ kroky Otvorené\ otázky Brány].each { |h| NxTest.assert(tpl.include?("## #{h}"), "sablona: sekcia #{h}") }
  NxTest.assert(NxP4c.cards.any?, 'v repe je aspon jedna karta priebehu (karta davky P4c)')
  NxP4c.cards.each do |path|
    txt = NxP4c.read(path)
    rel = path.sub("#{NxTest::ROOT}/", '')
    st = NxP4c.field(txt, 'NxReState')
    NxTest.assert(st && (st == 'aktívna' || st.start_with?('odložená') || st.start_with?('v review (PR #')), "#{rel}: Stav je `aktívna`, `odložená — dôvod` alebo `v review (PR #N)` (je: #{st.inspect})")
    NxTest.assert(!NxP4c.field(txt, 'NxReNext').to_s.strip.empty?, "#{rel}: chyba riadok `Ďalší krok:`")
  end
end

CARD_TEXT = "# Priebeh davky PX\n\nZadanie: x\nTrieda: S\nStav: odložená — čaká na limit\nĎalší krok: dokončiť test\e[31m červený\nRobil: Claude\n"

NX_P4C_GH_STUB = <<~'PS'
  if ($args[0] -eq 'pr' -and $args[1] -eq 'list') {
    if ($env:NX_STUB_FAIL) { exit 1 }
    Write-Output $env:NX_STUB_JSON
    exit 0
  }
  exit 1
PS

# Hlavny repo (HANDOFF v mainu) + vetvy: s kartou, bez karty, s HANDOFF, zhodna s mainom (nesmie sa objavit).
def nx_p4c_repo(root)
  main = NxP4a.make_repo(root, 'README.md' => "# r\n", 'SYSTEM/zdroje/bloky/ABC/HANDOFF.md' => "handoff\n")
  mk = lambda do |branch, files|
    NxP4a.git(main, 'checkout', '-q', '-b', branch, 'main')
    files.each { |p, c| NxP4a.write(main, p, c) }
    unless files.empty?
      NxP4a.git(main, 'add', '-A')
      NxP4a.git(main, 'commit', '-q', '-m', "x #{branch}")
    end
    NxP4a.git(main, 'push', '-q', 'origin', branch)
    NxP4a.git(main, 'checkout', '-q', 'main')
  end
  mk.call('feat/karta', 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/PX.md' => CARD_TEXT)
  mk.call('feat/oprava', 'SYSTEM/zdroje/opravy/priebeh/FIX1.md' => CARD_TEXT.sub('Stav: odložená — čaká na limit', 'Stav: aktívna'))
  mk.call('feat/bez-karty', 'a.txt' => "a\n")
  mk.call('feat/handoff', 'SYSTEM/zdroje/bloky/DEF/HANDOFF.md' => "h\n")
  mk.call('feat/stara', {})
  main
end

def nx_p4c_rozp(repo, root, env = {}, gh: nil)
  stub = File.join(root, 'gh_stub.ps1')
  File.write(stub, NX_P4C_GH_STUB)
  NxP4a.ps_file(NxP4c::ROZP, '-RepoRoot', repo, '-Gh', gh || stub, '-NoFetch', env: env)
end

NxTest.test('p4c: rozpracovane.ps1 — PR, vetvy s kartou (Stav, Dalsi krok), vetvy bez karty, HANDOFF; ASCII, bez riadiacich znakov, exit 0') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4c-rozp-') do |root|
    repo = nx_p4c_repo(root)
    json = '[{"number":486,"headRefName":"feat/karta","isDraft":true,"updatedAt":"2026-10-27T08:00:00Z","title":"docs: P4c čalsi"},' \
           '{"number":487,"headRefName":"feat/x","isDraft":false,"updatedAt":"2026-10-26T08:00:00Z","title":"fix"}]'
    out, st = nx_p4c_rozp(repo, root, { 'NX_STUB_JSON' => json })
    NxTest.assert(st.success?, "exit 0 (#{out})")
    NxTest.assert(out.start_with?('Rozpracovane'), "hlavicka (#{out})")
    NxTest.assert(out.include?('PR otvorene: 2'), "pocet PR (#{out})")
    NxTest.assert(out =~ %r{^ {2}#486 feat/karta DRAFT 2026-10-27 - docs: P4c .alsi$}, "PR 486 draft (#{out})")
    NxTest.assert(out =~ %r{^ {2}#487 feat/x 2026-10-26 - fix$}, "PR 487 nie draft (#{out})")
    NxTest.assert(out.include?('Vetvy pred main s kartou priebehu: 2'), "dve vetvy s kartou (#{out})")
    NxTest.assert(out =~ %r{^ {2}feat/oprava \[FIX1\] \d{4}-\d{2}-\d{2} [0-9a-f]+ \| Stav: aktivna \| Dalsi krok: }, "karta davky mimo bloku (#{out})")
    NxTest.assert(out =~ %r{^ {2}feat/karta \[PX\] \d{4}-\d{2}-\d{2} [0-9a-f]+ \| Stav: odlozena - caka na limit \| Dalsi krok: dokoncit test .?\[31m cerveny$}, "riadok karty (#{out})")
    NxTest.assert(out =~ /bez karty[^:]*: .*feat\/bez-karty/ && out =~ /bez karty[^:]*: .*feat\/handoff/, "vetvy bez karty (#{out})")
    NxTest.refute(out.include?('feat/stara'), 'vetva zhodna s mainom sa nevypisuje')
    NxTest.assert(out.include?('HANDOFF v checkoute: SYSTEM/zdroje/bloky/ABC/HANDOFF.md'), "HANDOFF v checkoute (#{out})")
    NxTest.assert(out =~ %r{HANDOFF na vetve feat/handoff: SYSTEM/zdroje/bloky/DEF/HANDOFF\.md \(\d{4}-\d{2}-\d{2} [0-9a-f]+\)}, "HANDOFF na vetve (#{out})")
    NxTest.assert(out.bytes.all? { |b| b == 10 || b == 13 || (b >= 32 && b < 127) }, "vystup je ASCII bez riadiacich znakov (#{out.inspect})")
  end
end

NxTest.test('p4c: rozpracovane.ps1 — bez gh, zlyhane gh, prazdny zoznam PR, repo bez origin/main: kratka hlaska, exit 0') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4c-rozp2-') do |root|
    repo = nx_p4c_repo(root)
    out, st = nx_p4c_rozp(repo, root, {}, gh: 'neexistujuci-gh-xyz')
    NxTest.assert(st.success? && out.include?('gh nie je dostupne'), "bez gh (#{out})")
    NxTest.assert(out.include?('Vetvy pred main s kartou priebehu: 2'), 'vetvy sa vypisu aj bez gh')
    out, st = nx_p4c_rozp(repo, root, { 'NX_STUB_FAIL' => '1' })
    NxTest.assert(st.success? && out.include?('zoznam sa nepodarilo nacitat'), "gh zlyhalo (#{out})")
    out, st = nx_p4c_rozp(repo, root, { 'NX_STUB_JSON' => '[]' })
    NxTest.assert(st.success? && out.include?('PR: ziadne otvorene'), "prazdny zoznam (#{out})")
  end
  Dir.mktmpdir('p4c-rozp3-') do |root|
    plain = File.join(root, 'plain')
    FileUtils.mkdir_p(plain)
    system('git', 'init', '-q', '-b', 'main', plain) || raise('git init')
    out, st = nx_p4c_rozp(plain, root, { 'NX_STUB_JSON' => '[]' })
    NxTest.assert(st.success? && out.include?('origin/main sa nenaslo'), "repo bez origin/main (#{out})")
    out, st = nx_p4c_rozp(File.join(root, 'nie-je-repo'), root, { 'NX_STUB_JSON' => '[]' })
    NxTest.assert(st.success?, "adresar, ktory nie je repo: exit 0 (#{out})")
  end
end

NxTest.test('p4c: Update-NxPrNumber — cislo PR sa doplna aj v zazname davky bloku (SYSTEM/zdroje/bloky/*/kronika/*.md), `*` je jeden usek cesty') do
  NxP4a.need_pwsh!
  lib = File.join(NxP4a::SCRIPTS, 'lib', 'nx_pr.ps1')
  Dir.mktmpdir('p4c-num-') do |root|
    old = "# stara\n\nText pravidla: pise sa `PR #?` a doplni sa.\n"
    main = NxP4a.make_repo(root, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/stara.md' => old.gsub("\n", "\r\n"), 'README.md' => "# r\n")
    NxP4a.git(main, 'checkout', '-q', '-b', 'feat/p4c-test')
    NxP4a.write(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/P4c.md', "- **P4c (PR #?)** zaznam\r\ndruhy riadok bez cisla\r\n")
    NxP4a.write(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/podpriecinok/X.md', "- **X (PR #?)** vnoreny subor nie je zaznam davky\n")
    NxP4a.write(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/stara.md', (old + "- **dopisane (PR #?)**\n").gsub("\n", "\r\n"))
    NxP4a.write(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/P4c.md', "Zadanie: x PR #? v karte priebehu sa nedopalna\n")
    NxP4a.git(main, 'add', '-A')
    NxP4a.git(main, 'commit', '-q', '-m', 'davka')
    cmd = ". '#{lib}'; Update-NxPrNumber '#{main}' 'main' '486' | ForEach-Object { Write-Output ($_.file + '=' + $_.replaced) }"
    out, st = NxP4a.ps_cmd(cmd)
    NxTest.assert(st.success?, "ps: #{out}")
    lines = out.split(/\r?\n/).map(&:strip).reject(&:empty?).sort
    NxTest.assert_equal(%w[SYSTEM/zdroje/bloky/PRAVIDLA/kronika/P4c.md=1 SYSTEM/zdroje/bloky/PRAVIDLA/kronika/stara.md=1], lines, "len zaznamy davok (#{out})")
    nova = NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/P4c.md')
    NxTest.assert(nova.start_with?("- **P4c (PR #486)** zaznam\r\n"), "cislo doplnene, CRLF zachovane (#{nova.inspect})")
    stara = NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/stara.md')
    NxTest.assert(stara.include?('pise sa `PR #?` a doplni'), 'stary riadok s textom pravidla ostal')
    NxTest.assert(stara.include?('dopisane (PR #486)'), 'dopisany riadok dostal cislo')
    NxTest.assert(NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/kronika/podpriecinok/X.md').include?('PR #?'), 'vnoreny subor sa nemeni')
    NxTest.assert(NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/P4c.md').include?('PR #?'), 'karta priebehu sa nemeni')
  end
end

NxTest.test('p4c: zoznam suborov s cislom PR je v otvor_pr.ps1, nx_pr.ps1 a straz.js rovnaky (aj zaznamy davok bloku)') do
  pr = NxP4c.read(File.join(NxP4a::SCRIPTS, 'lib', 'nx_pr.ps1'))
  list = pr[/\$NxPrNumberFiles = @\((.*?)\n\)/m, 1].to_s.scan(%r{'(SYSTEM/[^']+)'}).flatten.sort
  straz = NxP4c.read(File.join(NxTest::ROOT, '.claude', 'hooks', 'straz.js'))
  js = straz[/const G7_FILES = \[(.*?)\];/m, 1].to_s.scan(%r{'(SYSTEM/[^']+)'}).flatten.sort
  NxTest.assert(list.include?('SYSTEM/zdroje/bloky/*/kronika/*.md'), 'nx_pr.ps1 zahŕňa kronika/*.md')
  NxTest.assert_equal(list, js, 'nx_pr.ps1 a straz.js (G7_FILES) maju rovnaky zoznam')
  head = NxP4c.read(File.join(NxP4a::SCRIPTS, 'otvor_pr.ps1'))[/#\s+5\.[\s\S]*?(?=\n#\s+6\.)/].to_s
  NxTest.assert_equal(list, head.scan(%r{SYSTEM/[A-Za-z_/*]+\.md}).sort, 'hlavicka otvor_pr.ps1 (krok 5) ma rovnaky zoznam')
end

NxTest.test('p4c: pravidla odkazuju na kartu priebehu, G10 a zaznam davky po suboroch') do
  impl = NxP4c.read(File.join(NxTest::ROOT, 'SYSTEM', 'pravidla', 'roly', 'IMPLEMENTATOR.md'))
  %w[sablony/PRIEBEH.md priebeh/ kronika/ CI].each { |k| NxTest.assert(impl.include?(k), "IMPLEMENTATOR.md zmienuje #{k}") }
  testy = NxP4c.read(File.join(NxTest::ROOT, '.claude', 'rules', 'testy.md'))
  NxTest.assert(impl.include?('rules/testy.md') && impl.include?('opravy/priebeh'), 'IMPLEMENTATOR.md: G10 odkazuje na testy.md, karta mimo bloku')
  NxTest.assert(testy.include?('gh run watch $id --exit-status') && testy.include?('--commit <sha>'), 'testy.md: G10 s run-id, --commit a --exit-status')
  kron = NxP4c.read(File.join(NxTest::ROOT, 'SYSTEM', 'archiv', 'KRONIKA.md'))
  NxTest.assert(kron[0, 1500].include?('kronika/'), 'hlavicka KRONIKY menuje zaznamy po suboroch')
  uz = NxP4c.read(File.join(NxTest::ROOT, '.claude', 'skills', 'uzaver-bloku', 'SKILL.md'))
  NxTest.assert(uz.include?('kronika/'), 'uzaver-bloku: zlucenie zaznamov z kronika/')
  start = NxP4c.read(File.join(NxTest::ROOT, 'SYSTEM', 'pravidla', 'roly', 'ORCHESTRATOR.md'))
  NxTest.assert(start.include?('rozpracovane.ps1'), 'ORCHESTRATOR.md: start okna zmienuje rozpracovane.ps1')
  po = NxP4c.read(File.join(NxTest::ROOT, '.claude', 'skills', 'codex-po-pr', 'SKILL.md'))
  NxTest.assert(po.include?('codex-review-state'), 'codex-po-pr: cakanie na znacku codex-review-state')
  NxTest.refute(po.include?('`sleep 600`'), 'codex-po-pr: budik sleep 600 naslepo nahradeny')
  NxTest.refute(po.include?('sha=$(git rev-parse HEAD)'), 'codex-po-pr: sha hlavy PR sa nebera z miestneho checkoutu')
  NxTest.assert(po.scan('headRefOid').length >= 2, 'codex-po-pr: sha zo `gh pr view --json headRefOid` v slucke aj pri merge')
  NxTest.assert(po.include?('koniec: ${s:-bez znacky}'), 'codex-po-pr: slucka vypise stav po limite')
  krok5 = po[/^5\. \*\*Merge robí orchestrátor\*\*.*?^6\. /m].to_s
  NxTest.assert(krok5.include?('RAZ') && krok5.index('gh pr view <N> --json headRefOid') < krok5.index('--commit "$sha"') && krok5.index('--commit "$sha"') < krok5.index('--match-head-commit "$sha"'),
                'codex-po-pr krok 5: sha nacitana raz pred overovanim branami, ta ista pri mergi')
  NxTest.assert(krok5.scan('gh pr view <N> --json headRefOid').length == 1, 'codex-po-pr krok 5: sha sa nenacitava druhy raz tesne pred mergom')
  NxTest.assert(po.include?('chatgpt-codex-connector[bot]') && po.include?('create an environment') && po.include?('kolo nebeží'), 'codex-po-pr: slucka rozpozna odpoved bota create an environment')
end

NxTest.test('p4c: Update-NxCardState — v commite s cislom PR sa karta dávky zmenená vetvou prepne na `v review`; ostatné karty a CRLF ostanú') do
  NxP4a.need_pwsh!
  lib = File.join(NxP4a::SCRIPTS, 'lib', 'nx_pr.ps1')
  Dir.mktmpdir('p4c-card-') do |root|
    stara = "Stav: aktívna\nĎalší krok: stará karta\n"
    main = NxP4a.make_repo(root, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/STARA.md' => stara, 'README.md' => "# r\n")
    NxP4a.git(main, 'checkout', '-q', '-b', 'feat/p4c-card')
    NxP4a.write(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/NOVA.md', "# Priebeh\r\n\r\nStav: aktívna\r\nĎalší krok: dokončiť dávku\r\nRobil: x\r\n")
    NxP4a.write(main, 'SYSTEM/zdroje/opravy/priebeh/FIX.md', "Stav: odložená — limit\nĎalší krok: pokračovať\n")
    NxP4a.git(main, 'add', '-A')
    NxP4a.git(main, 'commit', '-q', '-m', 'davka')
    cmd = ". '#{lib}'; Update-NxCardState '#{main}' 'main' '486' -DryRun | ForEach-Object { Write-Output $_ }"
    out, st = NxP4a.ps_cmd(cmd)
    NxTest.assert(st.success? && out.split(/\r?\n/).map(&:strip).reject(&:empty?).sort == %w[SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/NOVA.md SYSTEM/zdroje/opravy/priebeh/FIX.md], "dry-run hlási len karty vetvy (#{out})")
    NxTest.assert(NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/NOVA.md').include?("Stav: aktívna\r\n"), 'dry-run nič nezapísal')
    out, st = NxP4a.ps_cmd(". '#{lib}'; Update-NxCardState '#{main}' 'main' '486' | Out-Null")
    NxTest.assert(st.success?, "ps: #{out}")
    nova = NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/NOVA.md')
    NxTest.assert(nova.include?("Stav: v review (PR #486)\r\nĎalší krok: review PR #486, merge robí orchestrátor\r\nRobil: x\r\n"), "stav aj ďalší krok, CRLF zachované (#{nova.inspect})")
    fix = NxP4a.read(main, 'SYSTEM/zdroje/opravy/priebeh/FIX.md')
    NxTest.assert(fix.start_with?("Stav: v review (PR #486)\nĎalší krok: review PR #486, merge robí orchestrátor\n"), "karta dávky mimo bloku (#{fix.inspect})")
    NxTest.assert_equal(stara, NxP4a.read(main, 'SYSTEM/zdroje/bloky/PRAVIDLA/priebeh/STARA.md'), 'karta, ktorú vetva nemenila, ostáva')
    # výsledný stav musí prejsť guardom stavov a prečítať ho rozpracovane.ps1
    NxTest.assert_equal('v review (PR #486)', NxP4c.field(nova, 'NxReState'), 'rozpracovane.ps1 prečíta stav `v review`')
  end
end

# --- session_digest.rb ---------------------------------------------------------------------------------------------

require File.join(NxTest::ROOT, 'scripts', 'session_digest.rb')

SD_FIXTURE = File.join(NxTest::ROOT, 'tests', 'fixtures', 'session_digest', 'projekt')

def nx_p4c_digest(args)
  io = StringIO.new
  code = NxSessionDigest.run(args.dup, io: io)
  [code, io.string]
end

NxTest.test('session_digest: sprava pouzivatela, text asistenta, nastroje s vysledkom, chyby, orezanie; zly riadok JSONL nepadne') do
  Dir.mktmpdir('p4c-digest-') do |dir|
    out = File.join(dir, 'digest.txt')
    code, msg = nx_p4c_digest(['--in', SD_FIXTURE, '--out', out])
    NxTest.assert_equal(0, code, "exit 0 (#{msg})")
    NxTest.assert(msg.include?('2 sessions') && msg.include?('1 preskočených'), "sumar (#{msg})")
    txt = File.read(out, encoding: 'UTF-8')
    NxTest.assert(txt.include?('=== SESSION 11111111 2026-10-20 08:00..08:04 vetva feat/vymyslena'), "hlavicka session (#{txt[0, 200]})")
    NxTest.assert(txt.include?('[U 08:00] Priprav vymyslenu davku V1 a zapis ju do karty.'), 'sprava pouzivatela')
    NxTest.assert(txt.include?('[A 08:00] Zacnem citanim zadania.'), 'text asistenta')
    NxTest.assert(txt.include?('[T 08:00] Read: /vymyslene/zadanie.md -> Prvy riadok zadania. Druhy riadok zadania.'), 'nastroj, vstup, vysledok na jednom riadku')
    NxTest.assert(txt.include?('[E 08:01] Bash: ruby tests/run_all.rb -> CHYBA: Test zlyhal: ocakavane 3, dostal 4.'), 'chyba nastroja (is_error, pole blokov)')
    NxTest.assert(txt =~ /\[T 08:02\] Grep: dlhy_vystup -> X{200}…\[\+\d+ znakov\]/, 'dlhy vysledok sa orezal')
    NxTest.assert(txt.include?('[~A 08:03] Vedlajsi agent hlasi hotovo.'), 'vedlajsi agent (sidechain) ma predponu ~')
    NxTest.assert(txt.include?('[T 08:04] Agent: analytik: Preskumaj vymyslene zaznamy -> (bez výsledku)'), 'nevybaveny nastroj')
    NxTest.refute(txt.include?('toto sa nema objavit'), 'uvaha (thinking) sa nevypisuje')
    NxTest.refute(txt.include?('Meta sprava'), 'meta sprava sa nevypisuje')
    NxTest.assert(txt.include?('Starsia vymyslena session.'), 'druha session je vo vystupe')
  end
end

NxTest.test('session_digest: --since, --max-result, tokeny sa skryju, vystup v repe a chybne vstupy sa odmietnu') do
  Dir.mktmpdir('p4c-digest2-') do |dir|
    out = File.join(dir, 'digest.txt')
    code, = nx_p4c_digest(['--in', SD_FIXTURE, '--out', out, '--since', '2026-10-10', '--max-result', '20'])
    NxTest.assert_equal(0, code, 'exit 0')
    txt = File.read(out, encoding: 'UTF-8')
    NxTest.refute(txt.include?('Starsia vymyslena'), '--since vyradi starsiu session')
    NxTest.assert(txt.include?('[T 08:00] Read: /vymyslene/zadanie.md -> Prvy riadok zadania.…[+'), '--max-result orezava')

    pat = "github_pat_#{'B' * 30}"
    token = "ghp_#{'A' * 36}"
    one = File.join(dir, 'tajna.jsonl')
    File.write(one, JSON.generate('type' => 'user', 'timestamp' => '2026-10-20T09:00:00.000Z',
                                  'message' => { 'role' => 'user', 'content' => "Token #{token} a #{pat} a heslo" }) + "\n", encoding: 'UTF-8')
    code, = nx_p4c_digest(['--in', one, '--out', out])
    NxTest.assert_equal(0, code, 'jeden subor .jsonl')
    txt = File.read(out, encoding: 'UTF-8')
    NxTest.refute(txt.include?(token) || txt.include?(pat), 'tokeny sa nevypisuju')
    NxTest.assert(txt.include?('Token [skryté] a [skryté] a heslo'), 'tokeny nahradene znackou (aj github_pat_)')

    code, msg = nx_p4c_digest(['--in', SD_FIXTURE, '--out', File.join(NxTest::ROOT, 'digest_nesmie_vzniknut.txt')])
    NxTest.assert_equal(2, code, 'vystup v repe sa odmietne')
    NxTest.assert(msg.include?('MIMO repa') && !File.exist?(File.join(NxTest::ROOT, 'digest_nesmie_vzniknut.txt')), 'hlaska a nic sa nezapisalo')
    code, = nx_p4c_digest(['--in', SD_FIXTURE])
    NxTest.assert_equal(2, code, 'bez --out')
    NxSessionDigest.repo_roots.each do |r|
      NxTest.assert(NxSessionDigest.inside_repo?(File.join(r, 'vnutri', 'digest.txt')), "vystup pod korenom repa sa odmietne: #{r}")
    end
    NxTest.assert(NxSessionDigest.inside_repo?(File.join(NxTest::ROOT, 'nie', 'je', 'este', 'digest.txt')), 'este neexistujuca cesta v repe sa odmietne')
    NxTest.assert(NxSessionDigest.inside_repo?(NxTest::ROOT.upcase + '/x.txt') || !NxSessionDigest.windows?, 'na Windows sa velkost pismen nerozlisuje')
    NxTest.refute(NxSessionDigest.inside_repo?(File.join(dir, 'x.txt')), 'docasny priecinok mimo repa je v poriadku')
    prazdny = File.join(dir, 'prazdny')
    FileUtils.mkdir_p(prazdny)
    code, = nx_p4c_digest(['--in', prazdny, '--out', File.join(dir, 'x.txt')])
    NxTest.assert_equal(2, code, 'priecinok bez .jsonl')
    code, = nx_p4c_digest(['--zla-volba'])
    NxTest.assert_equal(2, code, 'neznama volba')
  end
end

NxTest.test('session_digest: spusta sa ako samostatny proces (exit 0) a fixtura nema skutocne zaznamy') do
  Dir.mktmpdir('p4c-digest3-') do |dir|
    out = File.join(dir, 'digest.txt')
    msg, st = Open3.capture2e(RbConfig.ruby, File.join(NxTest::ROOT, 'scripts', 'session_digest.rb'), '--in', SD_FIXTURE, '--out', out)
    NxTest.assert(st.success?, "proces: #{msg}")
    NxTest.assert(File.exist?(out), 'vystupny subor vznikol')
  end
  Dir[File.join(SD_FIXTURE, '*')].each do |f|
    txt = File.read(f, encoding: 'UTF-8')
    NxTest.refute(txt.match?(/michalmoronga|[A-Z]:\\|\\Users\\/i), "#{File.basename(f)}: fixtura nesmie niest skutocne cesty ani mena")
  end
end
