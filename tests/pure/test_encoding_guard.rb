# frozen_string_literal: true
# Guard kodovania (incident 21.7.: panel.html s mojibake priamo v bajtoch —
# UTF-8 texty prehnane cez cp1250 zapis pocas nocnej fronty; pouzivatel videl
# "Z-o-acute-mangled" namiesto "Zóny"). Tento test SKENUJE zdrojove subory a spadne, ak:
#   1. subor obsahuje typicke double-encoding signatury (bajtove sekvencie,
#      pozri regex nizsie — DOSLOVNE priklady sem NEpatria, guard by chytil sam seba),
#   2. subor obsahuje C1 kontrolne znaky U+0080..U+009F (zvysky passthrough),
#   3. .html subor nema <meta charset="utf-8">,
#   4. subor nie je validne UTF-8.
# Ziadny falosny poplach: signatury su bajtove sekvencie, ktore sa v cistej
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
  bad = []
  targets.each do |p|
    bytes = File.binread(p)
    rel = p.sub("#{root}/", '')
    bad << "#{rel}: mojibake signatura" if bytes.match?(sig)
    bad << "#{rel}: C1 kontrolny znak (U+0080..9F)" if bytes.match?(c1)
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
