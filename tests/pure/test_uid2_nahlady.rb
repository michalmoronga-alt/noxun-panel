# frozen_string_literal: true
# UI-D2 — PNG NAHLADY SABLON: identita suboru, sklad a transport.
#
# Kamera ani `write_image` sa tu testovat NEDAJU (potrebuju zivy SketchUp view)
# — tie kryje in-SketchUp sekcia `run_uid2` v tests/sketchup/su_runner.rb.
# Tu sa dokazuje vsetko ostatne z Codex auditu davky:
#   BLOCKER 1 — meno suboru je BEZPECNE: slug je whitelist [a-z0-9-] so stropom
#               dlzky, IDENTITU drzi prvych 16 hex SHA1("kind:name"); ziadne
#               meno sablony neunikne z adresara a dve rozne sablony nikdy
#               nespadnu do jedneho suboru (containment check cesty)
#   BLOCKER 2 — PNG zije a umiera SO ZAZNAMOM: `upsert` obrazok nasadi/zmaze,
#               `delete` ho zmaze, ODMIETNUTY zapis (forward guard) sa ho
#               NEDOTKNE; prepis so ZLYHANYM capture stary obrazok ZMAZE
#   FIX  4/8  — `preview_rev` je TRANSIENTNE pole payloadu: subor sablon je po
#               zostaveni zoznamu BYTE-NEZMENENY a zaznam v nom kluc nema;
#               samotne PNG ide samostatnym kanalom s kontrolou magic + limitu
require_relative '../helper' unless defined?(NxTest)

# UI vrstva: reopeny Panel modulov su parse-safe (SketchUp API zije vyhradne
# vnutri metod). V SketchUpe su uz nacitane pluginom.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxD2
  TP = Noxun::Engine::TemplatePreviews
  TS = Noxun::Engine::TemplateStore
  JFS = Noxun::Engine::JsonFileStore

  # Najmensi platny zaciatok PNG (magic + IHDR hlavicka). Obsah sa nedekoduje —
  # server kontroluje magic bytes a velkost, nie obrazkove data.
  PNG_HEAD = "\x89PNG\r\n\x1A\n".b

  module_function

  def reset!
    [TS.path, Noxun::Engine::TemplateUsage.path].each do |p|
      FileUtils.rm_f(p)
      FileUtils.rm_f("#{p}.bak")
      JFS.invalidate(p)
    end
    FileUtils.rm_rf(TP.dir)
  end

  def png(size = 64)
    (PNG_HEAD + ('x' * [size - PNG_HEAD.bytesize, 0].max)).b
  end

  # Polozi hotovy PNG rovno na finalne miesto (simulacia uz ulozeneho nahladu).
  def put!(kind, name, bytes = png)
    p = TP.path_for(kind, name)
    FileUtils.mkdir_p(File.dirname(p))
    File.binwrite(p, bytes)
    p
  end

  # Vyrobi capture TEMP subor tak, ako ho vyrobi `TemplatePreviews.capture`.
  def tmp!(bytes = png)
    p = TP.new_tmp_path
    File.binwrite(p, bytes)
    p
  end

  def cfg(width = 600.0)
    { 'type' => 'lower', 'width' => width }
  end
end

# ---------------------------------------------------------------------------
# BLOCKER 1 — bezpecne meno suboru (slug + hash + containment)
# ---------------------------------------------------------------------------

NxTest.test('UI-D2 slug: whitelist [a-z0-9-], diakritika von, prazdny vysledok ma nahradu') do
  NxTest.assert_equal('dolna-klasik', NxD2::TP.slug('Dolná klasik'))
  NxTest.assert_equal('pracovna-doska', NxD2::TP.slug('Pracovná doska'))
  NxTest.assert_equal('x', NxD2::TP.slug('***'), 'nic pouzitelne = nahradny slug')
  NxTest.assert_equal('x', NxD2::TP.slug(''), 'prazdne meno = nahradny slug')
  NxTest.assert_equal('con', NxD2::TP.slug('CON'), 'rezervovane meno je LEN cast mena suboru')
end

NxTest.test('UI-D2 slug: uniku z adresara sa neda dosiahnut ziadnym menom') do
  ['..\\..\\zakazka', '../../etc/passwd', 'C:\\Windows\\system32', 'a/b/c', "nul\u0000x"].each do |bad|
    s = NxD2::TP.slug(bad)
    NxTest.assert_equal(true, s.match?(/\A[a-z0-9-]+\z/), "slug '#{s}' obsahuje len povolene znaky")
  end
end

NxTest.test('UI-D2 slug: dlhe (aj cele Unicode) meno ma strop dlzky') do
  long = 'Ž' * 200 # NFD zhodi macek — ostane 200x 'z', teda strop dlzky
  NxTest.assert_equal('z' * NxD2::TP::MAX_SLUG, NxD2::TP.slug(long))
  NxTest.assert_equal('x', NxD2::TP.slug('中文名称' * 20), 'meno bez ASCII zvysku = nahradny slug')
  long2 = "#{'Dolná skrinka ' * 20}koniec"
  NxTest.assert_equal(true, NxD2::TP.slug(long2).length <= NxD2::TP::MAX_SLUG,
                      'slug nikdy neprekroci strop dlzky')
  NxTest.assert_equal(false, NxD2::TP.slug(long2).end_with?('-'), 'zavesny spojovnik po oreze zmizne')
end

NxTest.test('UI-D2 identita: autoritou je HASH — rovnake slugy sa NIKDY nezrazia') do
  a = NxD2::TP.file_name('cabinet', 'Dolná klasik')
  b = NxD2::TP.file_name('cabinet', 'Dolna klasik!')   # rovnaky slug, INE meno
  NxTest.assert_equal(false, a == b, 'rovnaky slug + ine meno = iny subor')
  NxTest.assert_equal(a, NxD2::TP.file_name('cabinet', 'Dolná klasik'), 'meno je stabilne')
  NxTest.assert_equal(false, NxD2::TP.file_name('board', 'Zástena') == NxD2::TP.file_name('cabinet', 'Zástena'),
                      'druh je sucastou identity (dvojica kind+name)')
  NxTest.assert_equal(true, a.match?(/\Acabinet-[a-z0-9-]+-[0-9a-f]{16}\.png\z/), "tvar mena: #{a}")
end

NxTest.test('UI-D2 containment: cesta VZDY lezi v template_previews') do
  NxTest.skip!('cesty sa overuju nad sandbox %APPDATA%') unless NxTest.headless?
  base = File.expand_path(NxD2::TP.dir)
  ['..\\..\\zakazka', '../../x', 'Dolná klasik', 'C:/Windows/x'].each do |name|
    p = NxD2::TP.path_for('cabinet', name)
    NxTest.assert_equal(true, !p.nil? && p.start_with?("#{base}/"), "'#{name}' -> #{p}")
    NxTest.assert_equal(base, File.expand_path(File.dirname(p)), 'subor lezi PRIAMO v adresari nahladov')
  end
  NxTest.assert_equal(nil, NxD2::TP.path_for('cabinet', ''), 'prazdne meno = ziadna cesta')
end

# ---------------------------------------------------------------------------
# transport — PNG magic + tvrdy byte limit
# ---------------------------------------------------------------------------

NxTest.test('UI-D2 transport: data URI len z PLATNEHO PNG do stropu velkosti') do
  NxTest.skip!('sklad nahladov bezi nad sandbox %APPDATA%') unless NxTest.headless?
  NxD2.reset!

  NxTest.assert_equal(nil, NxD2::TP.data_uri('cabinet', 'Chyba'), 'neexistujuci subor = bez nahladu')

  NxD2.put!('cabinet', 'HTML', 'ehm, toto je HTML chybova stranka'.b)
  NxTest.assert_equal(nil, NxD2::TP.data_uri('cabinet', 'HTML'), 'subor bez PNG magic sa NEPOSIELA')

  NxD2.put!('cabinet', 'Velka', NxD2.png(NxD2::TP::MAX_BYTES + 1))
  NxTest.assert_equal(nil, NxD2::TP.data_uri('cabinet', 'Velka'), 'subor nad limitom sa NEPOSIELA')

  NxD2.put!('cabinet', 'Dobra', NxD2.png(512))
  uri = NxD2::TP.data_uri('cabinet', 'Dobra')
  NxTest.assert_equal(true, uri.to_s.start_with?('data:image/png;base64,'), 'platny PNG ide ako data URI')
  NxTest.assert_equal(NxD2.png(512), uri.sub('data:image/png;base64,', '').unpack1('m0').b,
                      'obsah data URI je presne obsah suboru')
end

NxTest.test('UI-D2 revizia: odtlacok suboru, po prepise ina, bez suboru nil') do
  NxTest.skip!('sklad nahladov bezi nad sandbox %APPDATA%') unless NxTest.headless?
  NxD2.reset!
  NxTest.assert_equal(nil, NxD2::TP.rev_for('cabinet', 'Dolná'), 'bez suboru ziadna revizia')

  p = NxD2.put!('cabinet', 'Dolná', NxD2.png(200))
  r1 = NxD2::TP.rev_for('cabinet', 'Dolná')
  NxTest.assert_equal(false, r1.nil?, 'existujuci subor ma reviziu')
  File.binwrite(p, NxD2.png(300))
  File.utime(Time.now + 5, Time.now + 5, p) # mtime aj velkost su ine
  NxTest.assert_equal(false, r1 == NxD2::TP.rev_for('cabinet', 'Dolná'), 'prepis meni reviziu')
end

# ---------------------------------------------------------------------------
# BLOCKER 2 — PNG zije a umiera so zaznamom (pod TYM ISTYM zamkom)
# ---------------------------------------------------------------------------

NxTest.test('UI-D2 upsert: capture temp subor sa presunie na finalne meno') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  tmp = NxD2.tmp!(NxD2.png(300))
  NxTest.assert_equal(true, NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, tmp))
  NxTest.assert_equal(false, File.exist?(tmp), 'temp subor po presune uz neexistuje')
  NxTest.assert_equal(true, File.file?(NxD2::TP.path_for('cabinet', 'Dolná klasik')), 'PNG je na mieste')
  NxTest.assert_equal(false, NxD2::TP.rev_for('cabinet', 'Dolná klasik').nil?)
end

NxTest.test('UI-D2 upsert: prepis so ZLYHANYM capture stary PNG ZMAZE') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!)
  NxTest.assert_equal(true, File.file?(NxD2::TP.path_for('cabinet', 'Dolná klasik')))

  # nil = capture zlyhal; obrazok stareho tvaru k novemu configu je horsi
  # nez schematicky fallback.
  NxTest.assert_equal(true, NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(900.0), nil))
  NxTest.assert_equal(false, File.exist?(NxD2::TP.path_for('cabinet', 'Dolná klasik')), 'stary PNG je prec')
  NxTest.assert_close(900.0, NxD2::TS.find('cabinet', 'Dolná klasik')['config']['width'], 0.01,
                      'zaznam sa ulozil aj bez nahladu')
end

NxTest.test('UI-D2 upsert: BEZ parametra `preview` sa obrazka nikto nedotkne') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!)
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(700.0)) # stary volajuci / migracia
  NxTest.assert_equal(true, File.file?(NxD2::TP.path_for('cabinet', 'Dolná klasik')),
                      'default :keep necha obrazok tak')
end

NxTest.test('UI-D2 delete: mazanie PNG patri DO TemplateStore.delete') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!)
  NxD2::TS.upsert('board', 'Zástena', NxD2.cfg, NxD2.tmp!)

  NxTest.assert_equal(true, NxD2::TS.delete('cabinet', 'Dolná klasik'))
  NxTest.assert_equal(false, File.exist?(NxD2::TP.path_for('cabinet', 'Dolná klasik')), 'PNG zmizol so zaznamom')
  NxTest.assert_equal(true, File.file?(NxD2::TP.path_for('board', 'Zástena')),
                      'rovnomenny/iny druh sa mazanim NEDOTKNE')
end

NxTest.test('UI-D2 forward guard: odmietnuty zapis sa PNG NEDOTKNE') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!)
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')
  before = File.binread(png_path)

  # Subor sablon z NOVSEJ verzie pluginu -> cely store je len na citanie.
  data = JSON.parse(File.binread(NxD2::TS.path))
  File.binwrite(NxD2::TS.path, JSON.generate(data.merge('std' => NxD2::TS::STD + 5)))
  NxD2::JFS.invalidate(NxD2::TS.path)

  tmp = NxD2.tmp!
  NxTest.assert_equal(false, NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(900.0), tmp))
  NxTest.assert_equal(before, File.binread(png_path), 'odmietnuty upsert PNG NEPREPISAL')
  NxTest.assert_equal(false, File.exist?(tmp), 'nepouzity capture temp subor sa upratal')

  NxTest.assert_equal(false, NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(900.0), nil))
  NxTest.assert_equal(before, File.binread(png_path), 'odmietnuty upsert bez capture PNG NEZMAZAL')

  NxTest.assert_equal(false, NxD2::TS.delete('cabinet', 'Dolná klasik'))
  NxTest.assert_equal(before, File.binread(png_path), 'odmietnuty delete PNG NEZMAZAL')
end

NxTest.test('UI-D2 discard: upratuje VYHRADNE v temp adresari, nikdy ulozeny nahlad') do
  NxTest.skip!('sklad nahladov bezi nad sandbox %APPDATA%') unless NxTest.headless?
  NxD2.reset!
  saved = NxD2.put!('cabinet', 'Dolná klasik')
  NxTest.assert_equal(false, NxD2::TP.discard(saved), 'ulozeny nahlad NIE JE temp')
  NxTest.assert_equal(true, File.file?(saved), 'a teda ostal na disku')

  tmp = NxD2.tmp!
  NxTest.assert_equal(true, NxD2::TP.discard(tmp))
  NxTest.assert_equal(false, File.exist?(tmp))
  NxTest.assert_equal(false, NxD2::TP.discard(nil), 'nil sa ticho ignoruje')
end

# ---------------------------------------------------------------------------
# FIX 4/8 — preview_rev je TRANSIENTNE pole payloadu
# ---------------------------------------------------------------------------

NxTest.test('UI-D2 payload: preview_rev je len v zozname — subor sablon je BYTE-NEZMENENY') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!)
  before = File.binread(NxD2::TS.path)

  list = Noxun::Engine::Panel.template_list(previews: true)
  row = list.find { |t| t['name'] == 'Dolná klasik' }
  NxTest.assert_equal(false, row['preview_rev'].nil?, 'zoznam nesie reviziu nahladu')
  NxTest.assert_equal(before, File.binread(NxD2::TS.path), 'zostavenie zoznamu NEZAPISUJE')

  raw = JSON.parse(File.binread(NxD2::TS.path))
  rec = raw['templates'].find { |t| t['name'] == 'Dolná klasik' }
  NxTest.assert_equal(false, rec.key?('preview_rev'), 'do templates.json sa revizia NIKDY nezapise')

  # Kontrolne kolo: aj po dalsom zapise (nezname kluce zaznamu inak PREZIJU).
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(650.0), NxD2.tmp!)
  raw2 = JSON.parse(File.binread(NxD2::TS.path))
  rec2 = raw2['templates'].find { |t| t['name'] == 'Dolná klasik' }
  NxTest.assert_equal(false, rec2.key?('preview_rev'), 'ani po prepise sa revizia nezapisala')
end

NxTest.test('UI-D2 payload: bez `previews:` sa nahlady vobec nepytaju (okno Sablony)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!)

  row = Noxun::Engine::Panel.template_list(kind: 'cabinet').find { |t| t['name'] == 'Dolná klasik' }
  NxTest.assert_equal(false, row.key?('preview_rev'), 'okno Sablony nahlady nekresli, tak ich ani nedostava')
  NxTest.assert_equal(true, row.key?('used_seq'), 'poradie pouzitia chodi dalej')
end

NxTest.test('UI-D2 payload: sablona BEZ nahladu ma preview_rev nil (dlazdica ostane na scheme)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Bez obrazka', NxD2.cfg) # ziadny capture

  row = Noxun::Engine::Panel.template_list(previews: true).find { |t| t['name'] == 'Bez obrazka' }
  NxTest.assert_equal(nil, row['preview_rev'])
end
