# frozen_string_literal: true
# Noxun Engine — kontrola kodovania zdrojakov a dokumentacie. JEDINA implementacia:
#   * CI test tests/pure/test_encoding_guard.rb ju pusta na CELY repozitar (repo_files),
#   * lokalny hook .claude/hooks/post_edit_check.ps1 na prave editovany subor (CLI nizsie).
# Obaja volaju tento subor, takze nemozu hovorit nieco ine. (Do 27.9.2026 mal hook vlastnu
# kopiu signatur v PowerShelli a test nevidel docs/architecture/ — hook tam hlasil falosny
# poplach na slove PAMÄŤ, ktory CI nikdy nevidelo.) Pravidla sa menia VYHRADNE tu.
#
# CLI:  ruby scripts/encoding_guard.rb SUBOR [SUBOR...]   exit 3 + riadky „subor: problem"
#       ruby scripts/encoding_guard.rb --repo              cely repozitar (rozsah CI testu)
#       exit 0 = cisto, 3 = nalezy, 2 = zle pouzitie. Nalez NIE JE 1 zamerne: exit 1 dava
#       Ruby sam pri pade ci syntaktickej chybe tohto suboru a hook ich nesmie zamenit
#       (realny pripad 27.9.2026: hook cital guard prave vo chvili zapisu).
#
# MOJIBAKE = UTF-8 text precitany ako jednobajtove kodovanie (cp1250, cp1252, latin1) a
# zapisany spat ako UTF-8 — incident 21.7.: panel.html s rozbitou diakritikou, ktoru videl
# pouzivatel. Kazde povodne pismeno sa rozpadne na DVA znaky: „uvodny" (A s oblucikom,
# A s vlnovkou, A s dvoma bodkami, L s dlznom, A s kruzkom, a/A so striezkou) a „zvysok"
# (znak, ktoreho UTF-8 zacina bajtom C2, C4, C5, C6, CB alebo E2). Signatury su preto
# BAJTOVE vzory tychto dvojic. DOSLOVNE priklady poskodeneho textu sem NEPATRIA — guard
# skenuje aj tento subor a nasiel by sam seba; vzory sa pisu bajtovymi escapmi.
#
# PASCA, KVOLI KTOREJ PRAVIDLA NIZSIE NIE SU JEDNODUCHSIE: dve z uvodnych pismen su aj
# LEGITIMNE slovenske velke pismena — Ä (PAMÄŤ, VÄČŠÍ, NAJMÄ) a Ĺ (DĹŽKA, DOPĹŇA) — a za
# nimi ide v spravnom texte velke pismeno z tej istej bajtovej skupiny C4/C5 ako zvysok.
# Horsie: „č" prehnane cez cp1250 dava PRESNE tie iste bajty ako „ÄŤ" v slove PAMÄŤ.
# Preto sa pri Ä a Ĺ rozhoduje podla toho, CO nasleduje a CO ich obklopuje: v spravnom
# texte stoja len vo VELKOM slove (za velkym pismenom alebo na zaciatku, pred velkym
# pismenom alebo koncom slova); mojibake vznika uprostred bezneho slova s malymi pismenami.
# Zname hranice (bajtovo nerozlisitelne od spravneho textu, ine signatury ich v subore
# takmer vzdy chytia): VELKE slovo s Ď cez cp1250/cp1252, samostatne pismeno č cez cp1250,
# velke Ň na konci slova cez cp1250. Meranie 27.9.2026 na 19 480 slovach z repa (stara
# sada v zatvorke): zachyt cp1250 99,96 % (92 %), cp1252 99,98 % (42 %), latin1 100 %
# (45 %), dvojite cp1250 100 % (62 %); falosne poplachy na tych istych slovach VELKYMI,
# s velkym zaciatkom, v uvodzovkach, zatvorkach ci za pomlckou 0 (stara sada 1 215 tvarov).

module NxEncodingGuard
  EXTENSIONS = %w[.rb .js .html .css .md .ps1].freeze
  # Lokalne, gitignorovane priecinky — do repa nikdy nejdu, preto ich lokalny beh sady
  # nesmie citat: testovacie modely (_dev/) a retro inbox orchestratora (PR #406).
  LOCAL_ONLY_DIRS = %w[_dev/ SYSTEM/retro/inbox/].freeze

  # Velke slovenske pismena, ktorych UTF-8 zacina bajtom C4/C5: Č Ď Ĺ Ľ Ň Ŕ Š Ť Ž.
  SK_UPPER_C4C5 = '(?:\xC4[\x8C\x8E\xB9\xBD]|\xC5[\x87\x94\xA0\xA4\xBD])'

  # [bajtovy vzor, co zvycajne znamena] — popis je ASCII (hook ho vypisuje cez konzolu).
  SIGNATURES = [
    # Uvodne pismena, ktore v slovencine NIE SU: kazde z nich + zvysok = mojibake.
    ['\xC3\xA2[\xC2\xC5\xCB\xE2]', 'a so strieskou + zvysok: pomlcka, uvodzovka, trojbodka, sipka cez cp1250/cp1252/latin1'],
    ['\xC4\x82[\xC2\xC4\xC5\xCB\xE2]', 'A s oblucikom + zvysok: a e i o u y s dlznom, a s dvoma bodkami, o s vokanom cez cp1250 (incident 21.7.)'],
    ['\xC3\x83[\xC2\xC5\xC6\xCB\xE2]', 'A s vlnovkou + zvysok: a e i o u y s dlznom, a s dvoma bodkami, o s vokanom cez cp1252/latin1'],
    ['\xC3\x85[\xC2\xC4\xC5\xCB\xE2]', 'A s kruzkom + zvysok: s z t n r s makcenom ci dlznom cez cp1252/latin1'],
    ['\xC3\x82[\xC2\xC4\xC5\xCB]', 'A so strieskou + zvysok: nbsp, paragraf, stupen, plus-minus, m2 cez cp1250/cp1252/latin1'],
    ['\xC4\x8C\xCB\x87', 'C s makcenom + samostatny makcen (povodna signatura z incidentu 21.7.)'],
    # Ä a Ĺ su aj slovenske pismena — mojibake len v tychto tvaroch (pasca v hlavicke).
    ['\xC3\x84(?:\xC2[\x80-\x9F\xB9\xBA\xBD\xBE]|\xCB|\xE2\x80\x9A)',
     'A s dvoma bodkami + zvysok: c d s makcenom, l L s dlznom ci makcenom cez cp1252/latin1, L s makcenom cez cp1250, dvojite cp1250'],
    ['\xC4\xB9(?:\xC2[\x80-\x9F\xA0\xA4]|\xCB)', 'L s dlznom + zvysok: s S T Z n s makcenom cez cp1250'],
    ["(?:\\xC3\\x84|\\xC4\\xB9)(?!#{SK_UPPER_C4C5})[\\xC4\\xC5]",
     'A s dvoma bodkami / L s dlznom + pismeno, ktore NIE JE velke slovenske: c d l s makcenom, t z s makcenom cez cp1250'],
    ['[a-z](?:\xC3\x84|\xC4\xB9)', 'male pismeno tesne pred velkym A s dvoma bodkami / L s dlznom: makcen ci dlzen uprostred slova cez cp1250'],
    ["\\xC3\\x84#{SK_UPPER_C4C5}[a-z]", 'A s dvoma bodkami + velke pismeno + male pismeno: c D s makcenom na zaciatku slova cez cp1250'],
    ['\xC4\xB9\xE2[\x80-\xBF][\x80-\xBF][A-Za-z]', 'L s dlznom + typograficky znak + pismeno: r R s dlznom, N s makcenom cez cp1250']
  ].map { |src, what| [Regexp.new(src.b, Regexp::NOENCODING), what].freeze }.freeze

  MOJIBAKE = Regexp.union(SIGNATURES.map(&:first))
  C1 = Regexp.new('\xC2[\x80-\x9F]'.b, Regexp::NOENCODING)
  C0 = Regexp.new('[\x01-\x08\x0B\x0C\x0E-\x1F]'.b, Regexp::NOENCODING)
  # Cyrilika U+0400..U+04FF je v SK/EN zdrojaku VZDY homoglyf latinky (review #223) —
  # rozsah sa sklada z cisel kodov, doslovny znak by guard nasiel sam v sebe.
  CYRILLIC = Regexp.new("[#{[0x0400].pack('U')}-#{[0x04FF].pack('U')}]")
  CHARSET = /charset=["']?utf-8/i
  BOM = "\xEF\xBB\xBF".b.freeze

  module_function

  # Problemy jedneho suboru (bajty + cesta kvoli pripone). Prazdne pole = cisto.
  def problems(bytes, path = '')
    bytes = bytes.b
    out = []
    out << 'UTF-8 BOM na zaciatku suboru (konvencia repa: UTF-8 bez BOM - typicka pasca Out-File/Set-Content)' if bytes.start_with?(BOM)
    text = bytes.dup.force_encoding('UTF-8')
    out << 'subor nie je validne UTF-8' unless text.valid_encoding?
    if (m = bytes.match(MOJIBAKE))
      pos = m.begin(0)
      what = SIGNATURES.find { |re, _| (s = re.match(bytes, pos)) && s.begin(0) == pos }&.last
      out << "mojibake signatura na riadku #{line_of(bytes, pos)} [#{hex(m[0])}] - #{what}"
    end
    if (m = bytes.match(C1))
      out << "C1 kontrolny znak U+0080..U+009F na riadku #{line_of(bytes, m.begin(0))} (zvysok zleho prekodovania)"
    end
    # ŠT-3c-1 (review #225 P1): NUL bajt spravi zo suboru BINARNY — git ho prestane diffovat
    # a KAZDE review ho vidi ako „Bin 0 -> 0 bytes" (znak sa pise `0.chr`, doslovny NUL by
    # guard nasiel sam v sebe).
    if (i = bytes.index(0.chr.b))
      out << "NUL bajt na riadku #{line_of(bytes, i)} (subor by bol pre git BINARNY)"
    end
    # Codex #322 P2: ostatne C0 riadiace znaky okrem TAB/LF/CR (realny nalez: `\a` z cesty
    # prehnanej interpolujucim heredocom).
    if (m = bytes.match(C0))
      out << "C0 riadiaci znak (0x#{m[0].ord.to_s(16)}) na riadku #{line_of(bytes, m.begin(0))}"
    end
    if text.valid_encoding? && (m = text.match(CYRILLIC))
      out << format('cyrilicky homoglyf U+%04X na riadku %d (v SK/EN zdrojaku nema co robit)', m[0].ord, m.pre_match.count("\n") + 1)
    end
    out << 'chyba <meta charset="utf-8">' if path.to_s.downcase.end_with?('.html') && !bytes.match?(CHARSET)
    out
  end

  def check_file(path)
    problems(File.binread(path), path)
  end

  # Rozsah CI testu = vsetky subory s EXTENSIONS v repozitari (relativne cesty). Glob
  # nevstupuje do bodkovych priecinkov (.git, .claude/worktrees s kopiami repa), z .claude
  # sa berie len to, co je v gite (skilly, hooky, typy agentov).
  def repo_files(root)
    exts = EXTENSIONS.map { |e| e.delete('.') }.join(',')
    files = Dir.glob("**/*.{#{exts}}", base: root) +
            Dir.glob(".claude/{skills,hooks,agents}/**/*.{#{exts}}", base: root)
    files.reject { |rel| rel.start_with?(*LOCAL_ONLY_DIRS) }.uniq.sort
  end

  def line_of(bytes, pos)
    bytes.byteslice(0, pos).count("\n") + 1
  end

  def hex(bytes)
    bytes.b.byteslice(0, 8).unpack('C*').map { |c| format('%02X', c) }.join(' ')
  end
end

if File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__)
  root = File.expand_path('..', __dir__)
  paths = ARGV == ['--repo'] ? NxEncodingGuard.repo_files(root).map { |rel| File.join(root, rel) } : ARGV
  if paths.empty? || paths.any? { |p| p.start_with?('--') }
    warn 'pouzitie: ruby scripts/encoding_guard.rb SUBOR [SUBOR...] | --repo'
    exit 2
  end
  found = 0
  paths.each do |p|
    NxEncodingGuard.check_file(p).each do |msg|
      puts "#{p}: #{msg}"
      found += 1
    end
  end
  exit(found.zero? ? 0 : 3)
end
