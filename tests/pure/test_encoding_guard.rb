# frozen_string_literal: true
# Guard kodovania (incident 21.7.: panel.html s mojibake priamo v bajtoch —
# UTF-8 texty prehnane cez cp1250 zapis pocas nocnej fronty; pouzivatel videl
# "Z-o-acute-mangled" namiesto "Zóny"). Tento test SKENUJE zdrojove subory a spadne, ak:
#   1. subor obsahuje typicke double-encoding signatury (bajtove sekvencie,
#      pozri regex nizsie — DOSLOVNE priklady sem NEpatria, guard by chytil sam seba),
#   2. subor obsahuje C1 kontrolne znaky U+0080..U+009F (zvysky passthrough),
#   3. .html subor nema <meta charset="utf-8">,
#   4. subor nie je validne UTF-8,
#   5. subor obsahuje CYRILICKY HOMOGLYF (review #223) — cyrilicke pismena su od
#      latinskych na pohlad NEROZLISITELNE, takze prejdu ocami aj code review,
#      ale rozbijaju grep aj porovnanie retazcov. DOSLOVNY priklad sem NEpatri
#      (guard by chytil sam seba, rovnako ako pri mojibake) — typicky nalez je
#      slovenske slovo s jednym cyrilickym pismenom uprostred, vzniknute
#      kopirovanim textu odinakial.
# ZNAMY FALOSNY POPLACH (ŠT-3b-2c2): slovenske pismeno „a s dvoma bodkami"
# (C3 84) nasledovane pismenom z Latin Extended-A — napr. slovenska cislovka
# 5 vypisana slovom, ci „T s makcenom" za nim — trafi signaturu
# `\xC3\x84[\xC2\xC4\xC5]` nizsie. (Doslovny priklad sem NEPATRI, guard by
# chytil sam seba — presne to sa pri pisani tohto komentara aj stalo.)
# Signatura sa
# NEZUZUJE (chytila realny incident 21.7.); texty v repe pouzivaju v takom
# pripade cislovku alebo iny tvar slova. Kto na to narazi: nie je to
# poskodeny subor, je to hranica tohto guardu.
# Inak ziadny falosny poplach: signatury su bajtove sekvencie, ktore sa v cistej
# slovencine/kode nikdy nevyskytuju.
require_relative '../helper' unless defined?(NxTest)

NxTest.test('encoding: ziadne mojibake/C1 bajty v UI a docs suboroch + html charset') do
  root = NxTest::ROOT
  # GH P3: aj root-level zdroje a skripty — mojibake sa nesmie schovat nikde.
  targets = Dir[File.join(root, 'noxun_engine', '**', '*.{html,js,css,rb}')] +
            Dir[File.join(root, 'SYSTEM', '**', '*.md')] +
            Dir[File.join(root, 'docs', '*.md')] +
            Dir[File.join(root, '*.{md,rb}')] +
            Dir[File.join(root, 'scripts', '*.{ps1,rb}')] +
            Dir[File.join(root, 'tests', '**', '*.{rb,js}')]
  # GH P2 doplnok: \xC3\x82\xC2 = double-encoded C2-xx znaky (±, ·, °...) — presne
  # tato medzera nechala v prvej verzii opravy prejst poskodeny znak ± (bez
  # doslovneho prikladu tu — guard by chytil sam seba).
  sig = /\xC3\xA2[\xC2\xE2]|\xC4\x82[\xCB\xC2\xC4\xC5]|\xC4\xB9[\xCB\xC2\xA0-\xBF]|\xC4\x8C\xCB\x87|\xC3\x84[\xC2\xC4\xC5]|\xC3\x85[\xC2\xC4\xC5]|\xC3\x82\xC2/n
  c1 = /\xC2[\x80-\x9F]/n
  # ŠT-3b-2c1 (review #223 NOTE 6): CYRILIKA v slovenskom/anglickom zdrojaku je
  # VZDY homoglyf — cyrilicke pismena su od latinskych na pohlad NEROZLISITELNE,
  # takze prejdu ocami aj code review, ale rozbijaju hladanie, grep aj porovnanie
  # retazcov. Prve zapnutie tohto guardu naslo TRI take zvysky v repe (komentar
  # v part_card.js, hlaska v test_st2a_mat.js, komentar v test_k1_smer_dekoru.rb)
  # — projekt ziadny cyrilicky text nema, takze je to bezpecny plosny zakaz.
  # Rozsah sa pise ESCAPMI, nie znakmi — inak by guard nasiel sam seba
  # (rovnaky dovod, preco tu nie su doslovne mojibake priklady).
  cyr = /[\u0400-\u04FF]/
  bad = []
  targets.each do |p|
    bytes = File.binread(p)
    rel = p.sub("#{root}/", '')
    bad << "#{rel}: mojibake signatura" if bytes.match?(sig)
    bad << "#{rel}: C1 kontrolny znak (U+0080..9F)" if bytes.match?(c1)
    # ŠT-3c-1 (review #225 P1): NUL bajt v zdrojaku spravi zo suboru BINARNY —
    # git ho prestane diffovat a KAZDE review ho vidi ako „Bin 0 -> 0 bytes".
    # Realny nalez: oddelovac kluca cache v `js/templates.js` bol napisany
    # doslovnym NUL, takze hlavny klientsky subor davky bol pre review neviditelny.
    # (Znak sa pise `0.chr` - doslovny NUL v tomto subore by chytil guard
    #  sam seba, presne ako pri mojibake signaturach a cyrilike.)
    bad << "#{rel}: NUL bajt (subor by bol pre git BINARNY)" if bytes.include?(0.chr.b)
    text = bytes.dup.force_encoding('UTF-8')
    if text.valid_encoding? && (hit = text[cyr])
      bad << "#{rel}: cyrilicky homoglyf #{format('U+%04X', hit.ord)} (v SK/EN zdrojaku nema co robit)"
    end
    begin
      bytes.dup.force_encoding('UTF-8').unicode_normalize
    rescue StandardError
      bad << "#{rel}: nevalidne UTF-8"
    end
    if p.end_with?('.html') && !bytes.include?('charset="utf-8"')
      bad << "#{rel}: chyba <meta charset=\"utf-8\">"
    end
  end
  NxTest.assert(bad.empty?, "Poskodene kodovanie:\n  #{bad.join("\n  ")}")
end
