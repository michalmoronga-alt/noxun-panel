# frozen_string_literal: true
# Guard skriptov P4a (blok 10 PRAVIDLA): scripts/run_js_tests.ps1, scripts/lib/nx_paths.ps1,
# scripts/lib/nx_pr.ps1, scripts/otvor_pr.ps1 (+ napojenie nx_paths.ps1 v run_su_tests.ps1,
# ui_foto.ps1, export_test.ps1). Nie su sucast pluginu. Skripty beru Windows PowerShell 5.1
# (Michalovo PC) aj pwsh (CI ubuntu); bez PowerShellu sa testy preskocia.
# Docasne repozitare (git init + bare origin) v os.tmpdir — skutocny repozitar sa nemeni;
# `gh` a kvotova brana su nahradene stubmi (-Gh, -UsageScript).
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative '../helper' unless defined?(NxTest)

module NxP4a
  ROOT = NxTest::ROOT
  SCRIPTS = File.join(ROOT, 'scripts')

  def self.pwsh
    return @pwsh if defined?(@pwsh)

    @pwsh = %w[powershell pwsh].find do |exe|
      system(exe, '-NoProfile', '-Command', 'exit 0', out: File::NULL, err: File::NULL)
    rescue StandardError
      false
    end
  end

  def self.need_pwsh!
    NxTest.skip!('powershell/pwsh nie je k dispozicii') unless pwsh
    NxTest.skip!('git nie je k dispozicii') unless system('git', '--version', out: File::NULL, err: File::NULL)
  end

  # PowerShell skript so zoznamom argumentov -> [stdout+stderr, status]
  def self.ps_file(script, *args, env: {})
    out, st = Open3.capture2e(env, pwsh, '-NoProfile', '-File', script, *args)
    [out, st]
  end

  def self.ps_cmd(command)
    out, st = Open3.capture2e(pwsh, '-NoProfile', '-Command', command)
    [out, st]
  end

  def self.git(dir, *args)
    out, st = Open3.capture2e('git', '-C', dir, *args)
    raise "git #{args.join(' ')} zlyhal: #{out}" unless st.success?

    out.strip
  end

  # Docasny repozitar: main s jednym commitom + bare origin. Vrati cestu k repu.
  def self.make_repo(root, files = {})
    repo = File.join(root, 'repo')
    origin = File.join(root, 'origin.git')
    FileUtils.mkdir_p(repo)
    system('git', 'init', '-q', '--bare', origin) || raise('git init --bare')
    system('git', 'init', '-q', '-b', 'main', repo) || raise('git init')
    { 'user.name' => 'Test', 'user.email' => 't@example.com', 'core.autocrlf' => 'false', 'commit.gpgsign' => 'false' }.each do |k, v|
      git(repo, 'config', k, v)
    end
    git(repo, 'remote', 'add', 'origin', origin)
    files.each { |p, c| write(repo, p, c) }
    git(repo, 'add', '-A')
    git(repo, 'commit', '-q', '-m', 'init')
    git(repo, 'push', '-q', 'origin', 'main')
    repo
  end

  def self.write(repo, rel, content)
    path = File.join(repo, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
  end

  def self.read(repo, rel)
    File.binread(File.join(repo, rel)).force_encoding('UTF-8')
  end

  def self.same_path?(a, b)
    File.realpath(a.strip) == File.realpath(b)
  end
end

NxTest.test('p4a: nove skripty su ASCII (PS 5.1 cita .ps1 bez BOM v systemovej kodovej stranke)') do
  %w[run_js_tests.ps1 otvor_pr.ps1 lib/nx_paths.ps1 lib/nx_pr.ps1].each do |f|
    bytes = File.binread(File.join(NxP4a::SCRIPTS, f)).bytes
    NxTest.assert(bytes.all? { |b| b < 128 }, "#{f} musi byt ASCII")
  end
end

NxTest.test('p4a: run_su_tests, ui_foto a export_test pouzivaju spolocne nx_paths.ps1') do
  %w[run_su_tests.ps1 ui_foto.ps1 export_test.ps1].each do |f|
    txt = File.binread(File.join(NxP4a::SCRIPTS, f)).force_encoding('UTF-8')
    NxTest.assert(txt.include?("'nx_paths.ps1'"), "#{f} nenacitava lib/nx_paths.ps1")
  end
  NxTest.refute(File.binread(File.join(NxP4a::SCRIPTS, 'ui_foto.ps1')).include?('function Resolve-NxTestModel'),
                'ui_foto.ps1 ma mat Resolve-NxTestModel len v lib/nx_paths.ps1')
  NxTest.refute(File.binread(File.join(NxP4a::SCRIPTS, 'run_su_tests.ps1')).include?("Join-Path $repo '_dev\\ENGINEtests.skp'"),
                'run_su_tests.ps1 nesmie hladat model len v aktualnom checkoute')
end

NxTest.test('p4a: nx_paths — model z aktualneho checkoutu, z hlavneho checkoutu (worktree), inak chyba s oboma cestami') do
  NxP4a.need_pwsh!
  lib = File.join(NxP4a::SCRIPTS, 'lib', 'nx_paths.ps1')
  Dir.mktmpdir('p4a-paths-') do |root|
    main = NxP4a.make_repo(root, '.gitignore' => "_dev/\n", 'a.txt' => 'a')
    wt = File.join(root, 'wt')
    NxP4a.git(main, 'worktree', 'add', '-q', '-b', 'vetva', wt)
    call = lambda do |repo|
      out, st = NxP4a.ps_cmd(". '#{lib}'; Write-Output ('MODEL=' + (Resolve-NxTestModel '#{repo}')); " \
                             "Write-Output ('ZAK=' + (Resolve-NxDevFile '#{repo}' @('_dev','export_test','zakazka.skp'))); " \
                             "Write-Output (Get-NxMissingDevMessage 'testovaci model' '#{repo}' @('_dev','ENGINEtests.skp'))")
      NxTest.assert(st.success?, "ps: #{out}")
      out
    end
    # (d) nikde nie je -> prazdne + hlaska s OBOMA skusanymi cestami
    out = call.call(wt)
    NxTest.assert(out.include?("MODEL=\n") || out =~ /MODEL=\r?\n/, "model nikde: prazdne (#{out})")
    NxTest.assert(out.include?('CHYBA: testovaci model chyba'), 'hlaska o chybajucom modeli')
    norm = out.tr('\\', '/')
    NxTest.assert(norm.include?("#{wt.tr('\\', '/')}/_dev/ENGINEtests.skp") || norm.downcase.include?('wt/_dev/enginetests.skp'), "hlaska menuje cestu worktree (#{out})")
    NxTest.assert(norm.downcase.include?('repo/_dev/enginetests.skp'), "hlaska menuje cestu hlavneho checkoutu (#{out})")
    # (b) model len v hlavnom checkoute -> worktree ho najde tam
    NxP4a.write(main, '_dev/ENGINEtests.skp', 'skp')
    NxP4a.write(main, '_dev/export_test/zakazka.skp', 'zak')
    out = call.call(wt)
    m = out[/MODEL=(.*)$/, 1].to_s.strip
    NxTest.assert(!m.empty? && NxP4a.same_path?(m, File.join(main, '_dev', 'ENGINEtests.skp')), "worktree -> model z hlavneho checkoutu (#{out})")
    z = out[/ZAK=(.*)$/, 1].to_s.strip
    NxTest.assert(!z.empty? && NxP4a.same_path?(z, File.join(main, '_dev', 'export_test', 'zakazka.skp')), "worktree -> zakazka z hlavneho checkoutu (#{out})")
    # (a) hlavny checkout sam
    out = call.call(main)
    NxTest.assert(NxP4a.same_path?(out[/MODEL=(.*)$/, 1].to_s, File.join(main, '_dev', 'ENGINEtests.skp')), 'hlavny checkout: vlastny model')
    msg = out[/CHYBA:.*/m].to_s
    NxTest.assert_equal(1, msg.scan('ENGINEtests.skp').length, "v hlavnom checkoute sa cesta nevypisuje dvakrat (#{msg})")
    NxTest.assert_equal(2, call.call(wt)[/CHYBA:.*/m].to_s.scan('ENGINEtests.skp').length, 'vo worktree su dve rozne cesty')
    # (c) worktree s vlastnym _dev ma prednost
    NxP4a.write(wt, '_dev/ENGINEtests.skp', 'wt-skp')
    out = call.call(wt)
    NxTest.assert(NxP4a.same_path?(out[/MODEL=(.*)$/, 1].to_s, File.join(wt, '_dev', 'ENGINEtests.skp')), "worktree s vlastnym _dev: vlastny model (#{out})")
  end
end

NxTest.test('p4a: run_su_tests.ps1 -DryRun vo worktree bez _dev najde model v hlavnom checkoute (len ak je SketchUp)') do
  NxP4a.need_pwsh!
  su = 'C:\Program Files\SketchUp\SketchUp 2026\SketchUp\SketchUp.exe'
  NxTest.skip!('SketchUp nie je nainstalovany (suchy beh ho hlada)') unless File.exist?(su)
  Dir.mktmpdir('p4a-dry-') do |root|
    main = NxP4a.make_repo(root, '.gitignore' => "_dev/\n")
    NxP4a.write(main, '_dev/ENGINEtests.skp', 'skp')
    wt = File.join(root, 'wt')
    NxP4a.git(main, 'worktree', 'add', '-q', '-b', 'vetva', wt)
    # skripty z tohto checkoutu skopirujeme do worktree (v docasnom repe ich nie je)
    FileUtils.mkdir_p(File.join(wt, 'scripts'))
    FileUtils.cp_r(File.join(NxP4a::SCRIPTS, 'lib'), File.join(wt, 'scripts', 'lib'))
    FileUtils.cp(File.join(NxP4a::SCRIPTS, 'run_su_tests.ps1'), File.join(wt, 'scripts', 'run_su_tests.ps1'))
    out, st = NxP4a.ps_file(File.join(wt, 'scripts', 'run_su_tests.ps1'), '-DryRun')
    NxTest.assert(st.success?, "dry-run exit (#{out})")
    NxTest.assert(out.include?('DRYRUN: model:') && out.tr('\\', '/').downcase.include?('repo/_dev/enginetests.skp'),
                  "model z hlavneho checkoutu (#{out})")
    NxTest.refute(File.exist?(File.join(wt, '_dev')), 'dry-run nic nevytvoril')
  end
end

NxTest.test('p4a: run_js_tests.ps1 — spusti kazdu sadu zvlast, suhrn, exit != 0 pri zlyhani, -FailFast') do
  NxP4a.need_pwsh!
  NxTest.skip!('node nie je k dispozicii') unless system('node', '--version', out: File::NULL, err: File::NULL)
  script = File.join(NxP4a::SCRIPTS, 'run_js_tests.ps1')
  Dir.mktmpdir('p4a-js-') do |dir|
    File.write(File.join(dir, 'test_a_fail.js'), "console.log('padla hlavna vec'); process.exit(1);\n")
    File.write(File.join(dir, 'test_b_ok.js'), "console.log('ok');\n")
    File.write(File.join(dir, 'test_c_ok.js'), "console.log('ok');\n")
    File.write(File.join(dir, 'nie_test.js'), "process.exit(1);\n") # nezodpoveda test_*.js
    out, st = NxP4a.ps_file(script, '-Dir', dir)
    NxTest.refute(st.success?, "padnuta sada = exit != 0 (#{out})")
    NxTest.assert(out.include?('FAIL test_a_fail.js'), "FAIL riadok (#{out})")
    NxTest.assert(out.include?('padla hlavna vec'), 'vystup padnutej sady sa vypise')
    NxTest.assert(out.include?('PASS test_b_ok.js') && out.include?('PASS test_c_ok.js'), 'bezi sa do konca (aj sady po zlyhani)')
    NxTest.assert(out.include?('JS: 3 sad, 2 PASS, 1 FAIL'), "suhrn (#{out})")
    NxTest.refute(out.include?('nie_test.js'), 'len test_*.js')
    out, st = NxP4a.ps_file(script, '-Dir', dir, '-FailFast')
    NxTest.refute(st.success?, '-FailFast: exit != 0')
    NxTest.assert(out.include?('JS: 1 sad, 0 PASS, 1 FAIL') && !out.include?('PASS test_b_ok.js'), "-FailFast skonci po prvom zlyhani (#{out})")
    File.delete(File.join(dir, 'test_a_fail.js'))
    out, st = NxP4a.ps_file(script, '-Dir', dir)
    NxTest.assert(st.success?, "vsetky presli = exit 0 (#{out})")
    NxTest.assert(out.include?('JS: 2 sad, 2 PASS, 0 FAIL'), "suhrn bez zlyhania (#{out})")
  end
  Dir.mktmpdir('p4a-js-empty-') do |dir|
    out, st = NxP4a.ps_file(script, '-Dir', dir)
    NxTest.refute(st.success?, "prazdny priecinok sad = chyba, nie tichy uspech (#{out})")
  end
end

PR_PLAN_OLD = "# PLAN\n\n> pravidlo: pred gh pr create sa pise PR #? a doplni ho samostatny commit\n\n- P1a hotovo - PR #478.\n"
PR_KRONIKA_OLD = "# KRONIKA\n\n## Zaznamy davok\n\n- stary zaznam o pravidle `PR #?` (text pravidla)\n"

# Davka vo vetve: prida riadky s PR #? do PLAN a KRONIKA (CRLF), README (mimo zoznamu) a necha STAV.
def nx_p4a_prepare(root)
  main = NxP4a.make_repo(root, 'SYSTEM/PLAN.md' => PR_PLAN_OLD, 'SYSTEM/archiv/KRONIKA.md' => PR_KRONIKA_OLD.gsub("\n", "\r\n"),
                              'SYSTEM/STAV.md' => "# STAV\nverzia 1\n", 'README.md' => "# README\n")
  NxP4a.git(main, 'checkout', '-q', '-b', 'feat/p4a-test')
  NxP4a.write(main, 'SYSTEM/PLAN.md', PR_PLAN_OLD + "- P4a drobnosti - PR #?.\n")
  kron = PR_KRONIKA_OLD.sub("## Zaznamy davok\n\n", "## Zaznamy davok\n\n- **P4a (23.10.2026, PR #?)** dvakrat PR #? v jednom riadku\n")
  NxP4a.write(main, 'SYSTEM/archiv/KRONIKA.md', kron.gsub("\n", "\r\n"))
  NxP4a.write(main, 'README.md', "# README\nmimo zoznamu: PR #? ostane\n")
  NxP4a.git(main, 'add', '-A')
  NxP4a.git(main, 'commit', '-q', '-m', 'davka')
  main
end

NxTest.test('p4a: Update-NxPrNumber — nahradi PR #? len na riadkoch pridanych vetvou a len v zozname suborov, zachova CRLF') do
  NxP4a.need_pwsh!
  lib = File.join(NxP4a::SCRIPTS, 'lib', 'nx_pr.ps1')
  Dir.mktmpdir('p4a-num-') do |root|
    repo = nx_p4a_prepare(root)
    out, st = NxP4a.ps_cmd(". '#{lib}'; Update-NxPrNumber '#{repo}' 'main' '479' -DryRun | ForEach-Object { Write-Output ($_.file + '=' + $_.replaced) }")
    NxTest.assert(st.success?, "ps: #{out}")
    NxTest.assert(out.include?('SYSTEM/PLAN.md=1') && out.include?('SYSTEM/archiv/KRONIKA.md=1'), "dry-run hlasi pocty riadkov (#{out})")
    NxTest.assert(NxP4a.read(repo, 'SYSTEM/PLAN.md').scan('PR #?').length == 2, 'dry-run nic nezapisal')
    out, st = NxP4a.ps_cmd(". '#{lib}'; Update-NxPrNumber '#{repo}' 'main' '479' | ForEach-Object { Write-Output ($_.file + '=' + $_.replaced) }")
    NxTest.assert(st.success?, "ps: #{out}")
    plan = NxP4a.read(repo, 'SYSTEM/PLAN.md')
    NxTest.assert(plan.include?("- P4a drobnosti - PR #479.\n"), "pridany riadok PLAN dostal cislo (#{plan.inspect})")
    NxTest.assert(plan.include?('sa pise PR #? a doplni'), 'stary riadok s textom pravidla ostal')
    kron = NxP4a.read(repo, 'SYSTEM/archiv/KRONIKA.md')
    NxTest.assert(kron.include?("(23.10.2026, PR #479)** dvakrat PR #479 v jednom riadku\r\n"), "obe vyskyty v pridanom riadku (#{kron.inspect})")
    NxTest.assert(kron.include?('`PR #?` (text pravidla)'), 'stary zaznam s textom pravidla ostal')
    NxTest.assert(kron.scan("\r\n").length == kron.scan("\n").length, 'konce riadkov CRLF zachovane')
    NxTest.assert(NxP4a.read(repo, 'README.md').include?('PR #? ostane'), 'subor mimo zoznamu sa nemeni')
    NxTest.assert(NxP4a.read(repo, 'SYSTEM/STAV.md') == "# STAV\nverzia 1\n", 'nezmenena vetvou = nedotknuty')
  end
end

# stub kvotovej brany a gh (PowerShell skripty); vystup/volania cez env premenne
NX_P4A_USAGE_STUB = "param([string]$Label, [string]$Phase, [string]$Gate)\nWrite-Output 'stub kvoty'\nexit ([int]$env:NX_STUB_GATE)\n"
NX_P4A_GH_STUB = <<~'PS'
  if ($env:NX_STUB_LOG) { Add-Content -LiteralPath $env:NX_STUB_LOG -Value ($args -join ' ') }
  if ($args[0] -eq 'pr' -and $args[1] -eq 'view') {
    if ($env:NX_STUB_EXISTING) {
      Write-Output $env:NX_STUB_EXISTING
      if ($env:NX_STUB_STATE) { Write-Output $env:NX_STUB_STATE } else { Write-Output 'OPEN' }
      exit 0
    }
    exit 1
  }
  if ($args[0] -eq 'pr' -and $args[1] -eq 'create') {
    if ($env:NX_STUB_CREATE_FAIL) { exit 1 }
    Write-Output 'https://github.com/o/r/pull/42'
    exit 0
  }
  exit 1
PS

def nx_p4a_stubs(root)
  usage = File.join(root, 'usage_stub.ps1')
  gh = File.join(root, 'gh_stub.ps1')
  body = File.join(root, 'popis.md')
  File.write(usage, NX_P4A_USAGE_STUB)
  File.write(gh, NX_P4A_GH_STUB)
  File.write(body, "Popis PR\n")
  { usage: usage, gh: gh, body: body, log: File.join(root, 'gh.log') }
end

def nx_p4a_otvor(repo, stubs, gate, extra = [], env = {})
  args = ['-Title', 'Test PR', '-BodyFile', stubs[:body], '-CoAuthor', 'Claude Test 1.0 <noreply@anthropic.com>',
          '-RepoRoot', repo, '-Gh', stubs[:gh], '-UsageScript', stubs[:usage]] + extra
  NxP4a.ps_file(File.join(NxP4a::SCRIPTS, 'otvor_pr.ps1'), *args,
                env: { 'NX_STUB_GATE' => gate.to_s, 'NX_STUB_LOG' => stubs[:log] }.merge(env))
end

NxTest.test('p4a: otvor_pr.ps1 -WhatIf — vypise plan a NIC nezapise, nepushne ani nezavola gh') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4a-whatif-') do |root|
    repo = nx_p4a_prepare(root)
    stubs = nx_p4a_stubs(root)
    head = NxP4a.git(repo, 'rev-parse', 'HEAD')
    out, st = nx_p4a_otvor(repo, stubs, 3, ['-WhatIf'])
    NxTest.assert(st.success?, "WhatIf exit 0 (#{out})")
    NxTest.assert(out.include?('WHATIF: vetva \'feat/p4a-test\''), "plan: vetva (#{out})")
    NxTest.assert(out.include?('KVOTA: exit 3') && out.include?('DRAFT'), "brana exit 3 = draft (#{out})")
    NxTest.assert(out.include?('--draft'), 'plan obsahuje --draft')
    NxTest.assert(out =~ %r{nahradil by sa 'PR #\?' v SYSTEM/PLAN\.md \(1x\)}, "plan: PLAN (#{out})")
    NxTest.assert(out =~ %r{v SYSTEM/archiv/KRONIKA\.md \(1x\)}, 'plan: KRONIKA')
    NxTest.assert(out.include?('Claude Test 1.0 <noreply@anthropic.com>'), 'plan: trailer s CoAuthor')
    NxTest.assert_equal(head, NxP4a.git(repo, 'rev-parse', 'HEAD'), 'WhatIf: ziaden commit')
    NxTest.assert_equal('', NxP4a.git(repo, 'status', '--porcelain'), 'WhatIf: strom bez zmien')
    NxTest.assert(NxP4a.read(repo, 'SYSTEM/PLAN.md').include?('P4a drobnosti - PR #?.'), 'WhatIf: PR #? ostalo')
    NxTest.refute(File.exist?(stubs[:log]), 'WhatIf: gh sa nevolal')
    refs, = Open3.capture2e('git', '-C', repo, 'ls-remote', '--heads', 'origin')
    NxTest.refute(refs.include?('feat/p4a-test'), 'WhatIf: vetva nebola pushnuta')
    out, st = nx_p4a_otvor(repo, stubs, 0, ['-WhatIf'])
    NxTest.assert(st.success? && out.include?('KVOTA: exit 0') && out.include?('nie draft') && !out.include?('--draft'), "brana exit 0 = nie draft (#{out})")
  end
end

NxTest.test('p4a: otvor_pr.ps1 — ostry beh so stubom gh: push, PR, cislo PR samostatnym commitom s trailerom, push') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4a-open-') do |root|
    repo = nx_p4a_prepare(root)
    stubs = nx_p4a_stubs(root)
    work_head = NxP4a.git(repo, 'rev-parse', 'HEAD')
    out, st = nx_p4a_otvor(repo, stubs, 0)
    NxTest.assert(st.success?, "ostry beh exit 0 (#{out})")
    NxTest.assert(out.include?('PR: #42  https://github.com/o/r/pull/42') && out.include?('DRAFT: nie'), "vypis URL, cislo, draft (#{out})")
    head = NxP4a.git(repo, 'rev-parse', 'HEAD')
    NxTest.assert(out.include?("COMMIT s cislom: #{head}"), "vypis SHA commitu s cislom (#{out})")
    NxTest.refute(work_head == head, 'vznikol novy commit')
    NxTest.assert_equal(work_head, NxP4a.git(repo, 'rev-parse', 'HEAD~1'), 'samostatny commit nad hlavou davky')
    msg = NxP4a.git(repo, 'log', '-1', '--format=%B')
    NxTest.assert(msg.start_with?('docs: doplnit cislo PR #42'), "sprava commitu (#{msg})")
    NxTest.assert(msg.include?('Co-Authored-By: Claude Test 1.0 <noreply@anthropic.com>'), 'trailer z -CoAuthor')
    NxTest.assert_equal(%w[SYSTEM/PLAN.md SYSTEM/archiv/KRONIKA.md], NxP4a.git(repo, 'show', '--name-only', '--format=', 'HEAD').split("\n").sort,
                        'commit meni len subory s cislom PR')
    NxTest.assert(NxP4a.read(repo, 'SYSTEM/PLAN.md').include?('- P4a drobnosti - PR #42.'), 'cislo v PLAN')
    NxTest.assert_equal(head, NxP4a.git(repo, 'ls-remote', 'origin', 'refs/heads/feat/p4a-test').split("\t").first, 'hlava vetvy (aj commit s cislom) je pushnuta')
    log = File.read(stubs[:log])
    NxTest.assert(log.include?('pr create --base main --head feat/p4a-test --title Test PR --body-file'), "gh pr create argumenty (#{log})")
    NxTest.refute(log.include?('--draft'), 'brana presla = nie draft')
  end
end

NxTest.test('p4a: otvor_pr.ps1 — brana exit 3 = --draft; existujuci PR, zly CoAuthor, main a neprazdny strom konci chybou bez pushu') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4a-guards-') do |root|
    repo = nx_p4a_prepare(root)
    stubs = nx_p4a_stubs(root)
    heads = lambda do
      refs, = Open3.capture2e('git', '-C', repo, 'ls-remote', '--heads', 'origin')
      refs
    end
    # existujuci PR
    out, st = nx_p4a_otvor(repo, stubs, 0, [], 'NX_STUB_EXISTING' => '7')
    NxTest.refute(st.success?, 'existujuci PR = chyba')
    NxTest.assert(out.include?('uz existuje (otvoreny): #7'), "hlaska o existujucom PR (#{out})")
    NxTest.refute(heads.call.include?('feat/p4a-test'), 'existujuci PR: nic sa nepushlo')
    # existujuci ZATVORENY / zmergovany PR novemu PR nebrani (P3-6)
    out, st = nx_p4a_otvor(repo, stubs, 0, ['-WhatIf'], 'NX_STUB_EXISTING' => '7', 'NX_STUB_STATE' => 'CLOSED')
    NxTest.assert(st.success?, "WhatIf s existujucim zatvorenym PR (#{out})")
    # zly CoAuthor
    args = ['-Title', 't', '-BodyFile', stubs[:body], '-CoAuthor', 'Claude bez-emailu', '-RepoRoot', repo, '-Gh', stubs[:gh], '-UsageScript', stubs[:usage]]
    out, st = NxP4a.ps_file(File.join(NxP4a::SCRIPTS, 'otvor_pr.ps1'), *args)
    NxTest.refute(st.success?, "zly -CoAuthor = chyba (#{out})")
    # neprazdny strom
    File.write(File.join(repo, 'SYSTEM/STAV.md'), "# STAV\nzmena\n")
    out, st = nx_p4a_otvor(repo, stubs, 0)
    NxTest.refute(st.success?, 'necommitnuta zmena = chyba')
    NxTest.assert(out.include?('necommitnute zmeny'), "hlaska o stave stromu (#{out})")
    NxP4a.git(repo, 'checkout', '-q', '--', 'SYSTEM/STAV.md')
    # hlavna vetva
    NxP4a.git(repo, 'checkout', '-q', 'main')
    out, st = nx_p4a_otvor(repo, stubs, 0)
    NxTest.refute(st.success?, 'z main sa PR neotvara')
    NxP4a.git(repo, 'checkout', '-q', 'feat/p4a-test')
    # brana exit 3 -> --draft v gh pr create
    out, st = nx_p4a_otvor(repo, stubs, 3)
    NxTest.assert(st.success?, "ostry beh s branou exit 3 (#{out})")
    NxTest.assert(out.include?('DRAFT: ano'), "vypis draft (#{out})")
    NxTest.assert(File.read(stubs[:log]).include?('--draft'), 'gh pr create dostal --draft')
  end
end

NxTest.test('p4a: otvor_pr.ps1 — zatvoreny PR vetvy nebrani; neznamy stav kvoty (exit 2) = draft s dôvodom, -NoDraftOnUnknownQuota to vypne') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4a-quota-') do |root|
    repo = nx_p4a_prepare(root)
    stubs = nx_p4a_stubs(root)
    # exit 2 / 4 = stav kvoty nedostupny -> draft + vypis preco (WhatIf nic nezapise)
    [2, 4].each do |code|
      out, st = nx_p4a_otvor(repo, stubs, code, ['-WhatIf'])
      NxTest.assert(st.success?, "WhatIf exit #{code} (#{out})")
      NxTest.assert(out.include?("KVOTA: exit #{code} - stav kvoty nedostupny: PR sa otvori ako DRAFT") && out.include?('--draft'), "exit #{code} = draft (#{out})")
    end
    out, st = nx_p4a_otvor(repo, stubs, 2, ['-WhatIf', '-NoDraftOnUnknownQuota'])
    NxTest.assert(st.success? && out.include?('-NoDraftOnUnknownQuota: PR sa otvori normalne') && !out.include?('--draft'), "-NoDraftOnUnknownQuota (#{out})")
    # chybajuci skript brany = neznamy stav = draft
    args = ['-Title', 't', '-BodyFile', stubs[:body], '-CoAuthor', 'Claude Test 1.0 <noreply@anthropic.com>', '-RepoRoot', repo, '-Gh', stubs[:gh],
            '-UsageScript', File.join(root, 'neexistuje.ps1'), '-WhatIf']
    out, st = NxP4a.ps_file(File.join(NxP4a::SCRIPTS, 'otvor_pr.ps1'), *args)
    NxTest.assert(st.success? && out.include?('skript brany nenajdeny') && out.include?('--draft'), "bez skriptu brany = draft (#{out})")
    # ostry beh s exit 2 -> gh pr create dostane --draft; zatvoreny existujuci PR nevadi
    out, st = nx_p4a_otvor(repo, stubs, 2, [], 'NX_STUB_EXISTING' => '7', 'NX_STUB_STATE' => 'MERGED')
    NxTest.assert(st.success?, "ostry beh po zmergovanom PR vetvy (#{out})")
    NxTest.assert(out.include?('DRAFT: ano'), 'exit 2 = draft aj v ostrom behu')
    NxTest.assert(File.read(stubs[:log]).include?('--draft'), 'gh pr create dostal --draft')
  end
end

NxTest.test('p4a: otvor_pr.ps1 — zlyhanie gh pr create (HEAD nezmeneny, PR #? ostava) a zlyhanie pushu commitu s cislom (hlaska, ze PR je vytvoreny)') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4a-fail-') do |root|
    repo = nx_p4a_prepare(root)
    stubs = nx_p4a_stubs(root)
    head = NxP4a.git(repo, 'rev-parse', 'HEAD')
    # gh pr create zlyha -> exit 1, ziadny commit, PR #? ostava
    out, st = nx_p4a_otvor(repo, stubs, 0, [], 'NX_STUB_CREATE_FAIL' => '1')
    NxTest.refute(st.success?, "zlyhany gh pr create = exit != 0 (#{out})")
    NxTest.assert(out.include?('gh pr create zlyhal - PR sa nevytvoril'), "hlaska (#{out})")
    NxTest.assert_equal(head, NxP4a.git(repo, 'rev-parse', 'HEAD'), 'HEAD sa nezmenil')
    NxTest.assert_equal('', NxP4a.git(repo, 'status', '--porcelain'), 'strom bez zmien')
    NxTest.assert(NxP4a.read(repo, 'SYSTEM/PLAN.md').include?('P4a drobnosti - PR #?.'), 'PR #? ostalo')
    # push commitu s cislom zlyha (pre-receive hook odmietne commit "docs: doplnit cislo")
    hook = File.join(root, 'origin.git', 'hooks', 'pre-receive')
    File.write(hook, <<~'SH')
      #!/bin/sh
      while read old new ref; do
        subj=$(git log -1 --format=%s "$new")
        case "$subj" in "docs: doplnit cislo"*) echo "odmietnute testom" >&2; exit 1;; esac
      done
      exit 0
    SH
    File.chmod(0o755, hook)
    out, st = nx_p4a_otvor(repo, stubs, 0)
    NxTest.refute(st.success?, "zlyhany push commitu s cislom = exit != 0 (#{out})")
    NxTest.assert(out.include?('git push commitu s cislom zlyhal'), "hlaska o pushi (#{out})")
    NxTest.assert(out.include?('PR #42 JE VYTVORENY'), "hlaska, ze PR je vytvoreny (#{out})")
    NxTest.assert(out.include?('https://github.com/o/r/pull/42'), 'hlaska nesie URL PR')
    NxTest.assert(NxP4a.git(repo, 'rev-parse', 'HEAD') != head, 'commit s cislom je lokalne')
    NxTest.assert(NxP4a.read(repo, 'SYSTEM/PLAN.md').include?('P4a drobnosti - PR #42.'), 'cislo je v subore lokalne')
  end
end

NxTest.test('p4a: INSTALL_noxun_engine.ps1 zapise znacku nasadenia (vetva, SHA, clean, cas) — len pri skutocnom nasadeni alebo s NOXUN_DEPLOY_MARKER') do
  NxP4a.need_pwsh!
  Dir.mktmpdir('p4a-marker-') do |root|
    repo = NxP4a.make_repo(root, 'noxun_engine.rb' => "# loader\n", 'noxun_engine/main.rb' => "# main\n")
    FileUtils.cp(File.join(NxP4a::ROOT, 'INSTALL_noxun_engine.ps1'), File.join(repo, 'INSTALL_noxun_engine.ps1'))
    NxP4a.git(repo, 'add', '-A')
    NxP4a.git(repo, 'commit', '-q', '-m', 'installer')
    NxP4a.git(repo, 'checkout', '-q', '-b', 'feat/znacka')
    sha = NxP4a.git(repo, 'rev-parse', 'HEAD')
    dest = File.join(root, 'plugins')
    marker = File.join(root, 'znacka.txt')
    tmpdir = File.join(root, 'tmp')
    FileUtils.mkdir_p(tmpdir)
    tmp_env = { 'TEMP' => tmpdir, 'TMP' => tmpdir, 'TMPDIR' => tmpdir, 'NOXUN_INSTALL_DEST' => dest }
    script = File.join(repo, 'INSTALL_noxun_engine.ps1')
    # testovaci rezim (NOXUN_INSTALL_DEST) bez NOXUN_DEPLOY_MARKER: znacka sa nezapisuje (ani do TEMP)
    out, st = NxP4a.ps_file(script, env: tmp_env)
    NxTest.assert(st.success?, "installer: #{out}")
    NxTest.refute(File.exist?(File.join(tmpdir, 'noxun_nasadene.txt')), 'testovaci rezim nezapisuje znacku do TEMP')
    # s NOXUN_DEPLOY_MARKER: znacka z cisteho stromu
    out, st = NxP4a.ps_file(script, env: tmp_env.merge('NOXUN_DEPLOY_MARKER' => marker))
    NxTest.assert(st.success?, "installer: #{out}")
    raw = File.binread(marker)
    NxTest.refute(raw.start_with?("\xEF\xBB\xBF".b), 'znacka bez BOM')
    kv = raw.force_encoding('UTF-8').lines.map { |l| l.chomp.split('=', 2) }.to_h
    NxTest.assert_equal('feat/znacka', kv['branch'], "vetva (#{raw})")
    NxTest.assert_equal(sha, kv['sha'], 'plny SHA HEAD')
    NxTest.assert_equal('yes', kv['clean'], 'cisty strom')
    NxTest.assert(kv['time'] =~ /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\z/, "cas ISO (#{kv['time']})")
    NxTest.assert_equal('INSTALL_noxun_engine.ps1', kv['by'], 'kto')
    # spinavy strom (necommitnuty subor pluginu) -> clean=no
    File.write(File.join(repo, 'noxun_engine', 'main.rb'), "# main zmena\n")
    out, st = NxP4a.ps_file(script, env: tmp_env.merge('NOXUN_DEPLOY_MARKER' => marker))
    NxTest.assert(st.success?, "installer: #{out}")
    kv = File.binread(marker).force_encoding('UTF-8').lines.map { |l| l.chomp.split('=', 2) }.to_h
    NxTest.assert_equal('no', kv['clean'], 'spinavy strom = clean=no')
    # skutocne nasadenie (bez NOXUN_INSTALL_DEST) sa tu nerobi: cielom by bol zivy SketchUp
  end
end
