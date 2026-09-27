# frozen_string_literal: true
# Guard kodovania — CI brana nad CELYM repozitarom. Pravidla (mojibake, BOM, NUL, C0, C1,
# cyrilika, charset) ziju v `scripts/encoding_guard.rb` — JEDINA implementacia, ktoru vola
# tento test aj lokalny hook `.claude/hooks/post_edit_check.ps1`. Tu su:
#   1. sken repozitara — rozsah = vsetky sledovane .rb/.js/.html/.css/.md/.ps1 (ako hook),
#   2. pripady: spravna slovencina aj VELKYMI prejde (zadanie 27.9.2026: PAMÄŤ, ŤAŽKÝ, ĽAD),
#      skutocne mojibake (cp1250 z incidentu 21.7., cp1252, latin1, aj dvojite) sa chyti,
#   3. ostatne kontroly (BOM, NUL, C0, C1, nevalidne UTF-8, cyrilika, charset),
#   4. CLI kontrakt guardu a hook spusteny naostro — hook a test hovoria to iste.
# Historia: incident 21.7. (panel.html s rozbitou diakritikou priamo v bajtoch), cyrilika
# #223, NUL #225, C0 #322, rozsah .claude #363/#392. 27.9.2026 zjednotene: hook mal vlastnu
# kopiu signatur a test nevidel docs/architecture/, kde hook hlasil falosny poplach na slove
# PAMÄŤ (zname od ŠT-3b-2c2; KOV-A1 #280: rozsirit glob len SPOLU so spresnenim vzoru).
# DOSLOVNE priklady poskodeneho textu sem NEPATRIA — sken repozitara cita aj tento subor;
# mojibake sa tu vyraba za behu (`enc_mangle`) alebo pise bajtovymi escapmi.
require_relative '../helper' unless defined?(NxTest)
require_relative '../../scripts/encoding_guard'
require 'rbconfig'
require 'tmpdir'

# Presne mechanizmus incidentu: UTF-8 bajty precitane ako jednobajtove kodovanie a zapisane
# spat ako UTF-8. Nedefinovany bajt (napr. 0x81 v cp1250) Windows mapuje na U+0080..U+009F.
def enc_mangle(text, enc)
  text.b.each_byte.map do |b|
    next b.chr if b < 0x80

    begin
      b.chr.force_encoding(enc).encode('UTF-8')
    rescue EncodingError
      [b].pack('U')
    end
  end.join.b
end

def enc_mojibake?(bytes)
  NxEncodingGuard.problems(bytes, 'x.md').any? { |p| p.start_with?('mojibake', 'C1') }
end

ENC_ROUTES = %w[Windows-1250 Windows-1252 ISO-8859-1].freeze

NxTest.test('encoding: cely repozitar bez poskodeneho kodovania (rozsah ako hook)') do
  root = NxTest::ROOT
  files = NxEncodingGuard.repo_files(root)
  # Aj to, co stary glob nevidel: docs/architecture, koren .ps1, html mockupy a fixtury.
  %w[docs/architecture/ui-lifecycle.md docs/architecture/hardware.md INSTALL_noxun_engine.ps1
     noxun_engine/ui/panel.html SYSTEM/STAV.md .claude/hooks/post_edit_check.ps1
     scripts/encoding_guard.rb tests/pure/test_encoding_guard.rb].each do |rel|
    NxTest.assert(files.include?(rel), "rozsah guardu musi zahrnat #{rel}")
  end
  NxTest.refute(files.any? { |rel| rel.start_with?('_dev/', '.claude/worktrees/', '.git/') },
                'lokalne kopie repa ani _dev/ do rozsahu nepatria')
  bad = files.flat_map { |rel| NxEncodingGuard.check_file(File.join(root, rel)).map { |p| "#{rel}: #{p}" } }
  NxTest.assert(bad.empty?, "Poskodene kodovanie:\n  #{bad.join("\n  ")}")
end

NxTest.test('encoding: rozsah guardu pokryva kazdy sledovany subor (git ls-files)') do
  NxTest.skip!('v SketchUpe sa externe procesy nespustaju') unless NxTest.headless?
  root = NxTest::ROOT
  tracked = begin
    IO.popen(['git', '-C', root, 'ls-files'], err: File::NULL, &:read).to_s.split("\n")
  rescue SystemCallError
    []
  end
  NxTest.skip!('git nie je k dispozicii') if tracked.empty?
  guarded = tracked.select { |rel| NxEncodingGuard::EXTENSIONS.include?(File.extname(rel).downcase) }
  missing = guarded - NxEncodingGuard.repo_files(root)
  NxTest.assert(missing.empty?, "sledovane subory mimo rozsahu guardu (dopln repo_files): #{missing.first(10).join(', ')}")
end

NxTest.test('encoding: spravna slovencina aj VELKYMI pismenami nie je mojibake') do
  words = ['PAMÄŤ', 'ŤAŽKÝ', 'ĽAD', # zadanie 27.9.2026
           'PAMÄŤ DRAFTU DRŽÍ', 'PAMÄŤ JE PO BUNKÁCH', 'závesu je PÄŤSTUPŇOVÁ', # riadky z docs/architecture
           'PÄŤ', 'DEVÄŤ', 'OPÄŤ', 'SPÄŤ', 'VÄČŠÍ', 'ZVÄČŠENIE', 'NAJMÄ', 'DĹŽKA', 'DOPĹŇA', 'HĹBKA', 'STĹPEC',
           'ŠÍRKA', 'ČELO', 'ĎALEJ', 'ÔSMY', 'ÚČET', 'SKRIŇA', 'MŔTVY', 'KÔŇ', 'ĽAVÝ', 'ŤAH', 'ŽĽAB',
           'päť', 'pamäť', 'väčší', 'dĺžka', 'vŕtanie', 'už', 'ďalej', 'kľúč', 'Ä', 'Ĺ', 'Ô']
  words.each do |w|
    [w, w.upcase, w.capitalize].uniq.each do |f|
      ["#{f} ", "**#{f}**", "`#{f}`", "„#{f}“", "#{f}.", "(#{f})", "#{f}:", "#{f} – ďalej", "#{f}…", "- #{f}\r\n"].each do |ctx|
        probs = NxEncodingGuard.problems(ctx.b, 'x.md')
        NxTest.assert(probs.empty?, "spravny text #{ctx.inspect} guard hlasi: #{probs.join('; ')}")
      end
    end
  end
end

NxTest.test('encoding: skutocne mojibake sa chyti (cp1250 z incidentu, cp1252, latin1, dvojite)') do
  # Priklady zo zadania 27.9.2026 v bajtoch: a s dlznom cez cp1252, c s makcenom cez latin1,
  # pomlcka cez cp1252 (plus c s makcenom cez cp1250 — bajtovo to iste ako v slove PAMÄŤ).
  { 'a s dlznom cez cp1252' => "\xC3\x83\xC2\xA1",
    'c s makcenom cez latin1' => "\xC3\x84\xC2\x8D",
    'pomlcka cez cp1252' => "\xC3\xA2\xE2\x82\xAC\xE2\x80\x9C",
    'cas cez cp1250' => "\xC3\x84\xC5\xA4as",
    'mec cez cp1250' => "me\xC3\x84\xC5\xA4" }.each do |what, bytes|
    NxTest.assert(enc_mojibake?(bytes.b), "#{what} musi byt mojibake")
  end
  # Generovane z beznych a vyrobnych slov — vratane tych istych slov, ktore VELKYMI prejdu.
  words = ['časť', 'čas', 'meč', 'šírka', 'hĺbka', 'dĺžka', 'vŕtanie', 'Vŕtanie', 'skriňa', 'PLATŇA', 'už', 'až',
           'ďalej', 'päť', 'väčší', 'ľavý', 'ťah', 'žltá', 'účet', 'Zóny', 'ŠÍRKA', 'DĹŽKA', 'PAMÄŤ', 'ŤAŽKÝ', 'ĽAD',
           'm²', '±2 mm', '§ 5', '90°', 'a – b', '„úvodzovky“', 'hotovo ✓', 'atď…']
  ENC_ROUTES.each do |enc|
    words.each do |w|
      NxTest.assert(enc_mojibake?(enc_mangle(" #{w} ", enc)), "#{w} prehnane cez #{enc} musi byt mojibake")
    end
  end
  %w[Windows-1250 Windows-1252].each do |enc|
    words.each do |w|
      twice = enc_mangle(enc_mangle(" #{w} ", enc), enc)
      NxTest.assert(enc_mojibake?(twice), "#{w} prehnane DVAKRAT cez #{enc} musi byt mojibake")
    end
  end
  # Hlasenie ukazuje riadok, aby agent vedel, kam siahnut.
  probs = NxEncodingGuard.problems("ok\nok\n#{enc_mangle('časť', 'Windows-1250')}\n".b, 'x.md')
  NxTest.assert(probs.any? { |p| p.start_with?('mojibake signatura na riadku 3 ') }, "cislo riadku: #{probs.inspect}")
end

NxTest.test('encoding: ostatne kontroly guardu (BOM, NUL, C0, C1, UTF-8, cyrilika, charset)') do
  has = ->(bytes, path, part) { NxEncodingGuard.problems(bytes.b, path).any? { |p| p.include?(part) } }
  NxTest.assert(has.("\xEF\xBB\xBFahoj", 'a.md', 'BOM'), 'BOM')
  NxTest.assert(has.("a#{0.chr}b", 'a.js', 'NUL'), 'NUL bajt')
  NxTest.assert(has.("a\x07b", 'a.rb', 'C0'), 'C0 riadiaci znak (BEL)')
  NxTest.refute(has.("a\tb\r\nc\n", 'a.rb', 'C0'), 'TAB, CR a LF su v poriadku')
  NxTest.assert(has.("a\xC2\x85b", 'a.md', 'C1'), 'C1 kontrolny znak')
  NxTest.assert(has.("a\xFFb", 'a.md', 'UTF-8'), 'nevalidne UTF-8')
  NxTest.assert(has.("Z#{[0x0435].pack('U')}ny", 'a.md', 'cyrilicky'), 'cyrilicky homoglyf uprostred slova')
  NxTest.assert(has.('<html><body>x</body></html>', 'a.html', 'charset'), '.html bez charsetu')
  ['<meta charset="utf-8">', '<meta charset="UTF-8">',
   '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">'].each do |html|
    NxTest.assert(NxEncodingGuard.problems(html.b, 'a.html').empty?, "platne vyhlasenie UTF-8: #{html}")
  end
  NxTest.assert(NxEncodingGuard.problems('bez charsetu'.b, 'a.md').empty?, 'charset sa pyta len od .html')
end

NxTest.test('encoding: CLI guardu (kontrakt hooku) — exit 0/1/2 a riadky „subor: problem"') do
  NxTest.skip!('v SketchUpe sa externe procesy nespustaju') unless NxTest.headless?
  guard = File.join(NxTest::ROOT, 'scripts', 'encoding_guard.rb')
  Dir.mktmpdir('nx-enc-cli-') do |dir|
    ok = File.join(dir, 'ok.md')
    File.binwrite(ok, "**PAMÄŤ** ŤAŽKÝ ĽAD\n")
    bad = File.join(dir, 'bad.md')
    File.binwrite(bad, enc_mangle("časť\n", 'Windows-1250'))
    out = IO.popen([RbConfig.ruby, guard, ok, bad], err: %i[child out], &:read)
    NxTest.assert_equal(1, $?.exitstatus, "nalez = exit 1 (#{out})")
    NxTest.assert(!out.empty? && out.lines.all? { |l| l.start_with?("#{bad}: ") }, "riadky len pre zly subor: #{out}")
    out = IO.popen([RbConfig.ruby, guard, ok], err: %i[child out], &:read)
    NxTest.assert_equal(0, $?.exitstatus, "cisty subor = exit 0 (#{out})")
    IO.popen([RbConfig.ruby, guard], err: %i[child out], &:read)
    NxTest.assert_equal(2, $?.exitstatus, 'bez argumentov = exit 2 (zle pouzitie)')
  end
end

NxTest.test('encoding: hook po uprave suboru hovori to iste ako guard (spusteny naostro)') do
  NxTest.skip!('v SketchUpe sa externe procesy nespustaju') unless NxTest.headless?
  hook = File.join(NxTest::ROOT, '.claude', 'hooks', 'post_edit_check.ps1')
  src = File.read(hook, encoding: 'UTF-8')
  NxTest.assert(src.include?("'../../scripts/encoding_guard.rb'"), 'hook vola spolocny guard')
  NxTest.refute(src.match?(/0xC[2-5]|\\xC[2-5]|\[regex\]::IsMatch/i), 'hook nesmie mat vlastnu kopiu signatur (drift do 27.9.2026)')
  ps = %w[powershell.exe pwsh].find { |exe| system(exe, '-NoProfile', '-Command', 'exit 0', out: File::NULL, err: File::NULL) }
  NxTest.skip!('PowerShell nie je k dispozicii — hook sa naostro neoveri') unless ps
  run = lambda do |path|
    args = [ps, '-NoProfile']
    args += %w[-ExecutionPolicy Bypass] if Gem.win_platform?
    out = IO.popen(args + ['-File', hook], 'r+', err: %i[child out]) do |io|
      io.write(JSON.generate('tool_input' => { 'file_path' => path }))
      io.close_write
      io.read
    end
    [$?.exitstatus, out]
  end
  Dir.mktmpdir('nx-enc-hook-') do |dir|
    ok = File.join(dir, 'ok.md')
    File.binwrite(ok, "**PAMÄŤ DRAFTU DRŽÍ** ŤAŽKÝ ĽAD\n")
    bad = File.join(dir, 'bad.md')
    File.binwrite(bad, enc_mangle("časť\n", 'Windows-1250'))
    code, out = run.call(ok)
    NxTest.assert_equal(0, code, "spravna slovencina VELKYMI: hook ticho (#{out})")
    code, out = run.call(bad)
    NxTest.assert_equal(2, code, "mojibake: hook exit 2 (#{out})")
    NxTest.assert(out.include?('mojibake signatura na riadku 1'), "hook hovori to iste ako guard: #{out}")
  end
end
