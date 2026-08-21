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

NxTest.test('UI-D2 payload: bez `previews:` sa nahlady vobec nepytaju') do
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

# ---------------------------------------------------------------------------
# SMOKE PACK 1 (6A) — RUCNE odfotenie nahladu k UZ ULOZENEJ sablone.
# `TemplateStore.set_preview` je JEDINA cesta, ktora meni obrazok BEZ zapisu
# zaznamu — dokazuje sa, ze zaznam ostava byte-nedotknuty, ze osirely PNG
# nevznikne a ze forward guard (novsia schema) akciu odmietne.
# ---------------------------------------------------------------------------

NxTest.test('SMOKE1 set_preview: prida PNG k existujucej sablone a ZAZNAM sa nezmeni') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Bez obrazka', NxD2.cfg(720.0)) # stara sablona bez fotky
  before = File.binread(NxD2::TS.path)
  NxTest.assert_equal(nil, NxD2::TP.rev_for('cabinet', 'Bez obrazka'), 'zaciname bez nahladu')

  tmp = NxD2.tmp!(NxD2.png(300))
  NxTest.assert_equal(true, NxD2::TS.set_preview('cabinet', 'Bez obrazka', tmp))
  NxTest.assert_equal(false, File.exist?(tmp), 'temp subor sa presunul na finalne meno')
  NxTest.assert_equal(true, File.file?(NxD2::TP.path_for('cabinet', 'Bez obrazka')), 'PNG je na mieste')
  NxTest.assert_equal(before, File.binread(NxD2::TS.path), 'templates.json ostal BYTE-NEZMENENY')
  NxTest.assert_close(720.0, NxD2::TS.find('cabinet', 'Bez obrazka')['config']['width'], 0.01,
                      'config sablony sa fotenim nemeni')
end

NxTest.test('SMOKE1 set_preview: prepis nahladu meni REVIZIU (dlazdica si vypyta novy obrazok)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  r1 = NxD2::TP.rev_for('cabinet', 'Dolná klasik')

  NxTest.assert_equal(true, NxD2::TS.set_preview('cabinet', 'Dolná klasik', NxD2.tmp!(NxD2.png(400))))
  NxTest.assert_equal(false, r1 == NxD2::TP.rev_for('cabinet', 'Dolná klasik'), 'nova fotka = nova revizia')
end

NxTest.test('SMOKE1 set_preview: sablona, ktora uz neexistuje, OSIRELY PNG nedostane') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg)

  tmp = NxD2.tmp!
  NxTest.assert_equal(false, NxD2::TS.set_preview('cabinet', 'Neexistuje', tmp))
  NxTest.assert_equal(false, File.exist?(tmp), 'nepouzity temp subor sa zahodil')
  NxTest.assert_equal(false, File.exist?(NxD2::TP.path_for('cabinet', 'Neexistuje')), 'ziadny osirely PNG')
end

NxTest.test('SMOKE1 set_preview: doskova sablona rovnakeho mena je INA sablona (identita kind+name)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('board', 'Zástena', NxD2.cfg)

  tmp = NxD2.tmp!
  NxTest.assert_equal(false, NxD2::TS.set_preview('cabinet', 'Zástena', tmp),
                      'korpusova sablona toho mena neexistuje')
  NxTest.assert_equal(false, File.exist?(NxD2::TP.path_for('cabinet', 'Zástena')))
  NxTest.assert_equal(nil, NxD2::TP.rev_for('board', 'Zástena'), 'doskova ostala bez nahladu')
end

NxTest.test('SMOKE1 set_preview: forward guard (novsia schema) odmietne a PNG sa NEDOTKNE') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')
  before = File.binread(png_path)

  data = JSON.parse(File.binread(NxD2::TS.path))
  File.binwrite(NxD2::TS.path, JSON.generate(data.merge('std' => NxD2::TS::STD + 5)))
  NxD2::JFS.invalidate(NxD2::TS.path)

  tmp = NxD2.tmp!(NxD2.png(400))
  NxTest.assert_equal(false, NxD2::TS.set_preview('cabinet', 'Dolná klasik', tmp))
  NxTest.assert_equal(false, File.exist?(tmp), 'odmietnuty capture sa zahodil')
  NxTest.assert_equal(before, File.binread(png_path), 'stary PNG ostal nedotknuty')
end

# Docasne nahradi presun suboru chybou disku (rovnaky vzor ako
# `uid2_with_broken_capture` v in-SketchUp runneri) — inak sa zlyhanie `mv`
# v teste nasimulovat neda.
def smoke1_with_broken_move
  tp = NxD2::TP
  orig = tp.method(:move_into_place)
  tp.define_singleton_method(:move_into_place) { |*| raise IOError, 'simulovana chyba disku' }
  yield
ensure
  tp.define_singleton_method(:move_into_place, orig)
end

NxTest.test('SMOKE1 set_preview: ZLYHANY presun NECHA stary nahlad na mieste (Codex #183 P2)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')
  before = File.binread(png_path)

  # „Prefotiť" nad sablonou, ktora uz nahlad MA. Config sa nemeni, takze stary
  # obrazok je stale platny — prechodna chyba disku oň nesmie pripraviť.
  tmp = NxD2.tmp!(NxD2.png(400))
  result = nil
  smoke1_with_broken_move { result = NxD2::TS.set_preview('cabinet', 'Dolná klasik', tmp) }

  NxTest.assert_equal(false, result, 'zlyhanie sa prizna (ziadny falosny uspech)')
  NxTest.assert_equal(before, File.binread(png_path), 'POVODNY nahlad ostal nedotknuty')
  NxTest.assert_equal(false, File.exist?(tmp), 'nepouzity capture temp sa zahodil')
end

# Zlyhanie SAMOTNEHO `FileUtils.mv` (nie stub celej `move_into_place`) — presne
# to, co `force: true` predtym prehltlo. `mode`:
#   :raise — realna chyba FS (zamknuty subor, plny disk)
#   :silent — mv sa TVARI, ze presunul, ale na disku nie je nic
def smoke1_with_broken_fs_mv(mode)
  fu = FileUtils
  orig = fu.method(:mv)
  fu.define_singleton_method(:mv) do |*|
    raise Errno::EACCES, 'simulovana chyba FS' if mode == :raise

    nil
  end
  yield
ensure
  fu.define_singleton_method(:mv, orig)
end

[:raise, :silent].each do |mode|
  NxTest.test("SWEEP: zlyhane `FileUtils.mv` (#{mode}) NIKDY nevrati falosny uspech") do
    NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
    NxD2.reset!
    NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
    png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')
    before = File.binread(png_path)

    # Nedestruktivna cesta „Prefotiť": config sa nemeni, takze uz ulozeny nahlad
    # ostava platny a neuspesny presun oň nesmie pripraviť — ale ani nesmie
    # tvrdit, ze sa prefotilo. TICHY no-op (mode :silent) je pritom to, co
    # `force: true` robilo pri KAZDEJ chybe.
    tmp = NxD2.tmp!(NxD2.png(400))
    result = nil
    smoke1_with_broken_fs_mv(mode) { result = NxD2::TS.set_preview('cabinet', 'Dolná klasik', tmp) }

    NxTest.assert_equal(false, result, 'zlyhanie presunu sa prizna (ziadny falosny uspech)')
    NxTest.assert_equal(before, File.binread(png_path), 'POVODNY nahlad ostal nedotknuty')
    NxTest.assert_equal(false, File.exist?(tmp), 'nepouzity capture temp NEOSTAL visiet')
  end
end

NxTest.test('SWEEP: zlyhane `FileUtils.mv` v upsert ceste stary PNG ZMAZE (schema > zly obrazok)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')

  tmp = NxD2.tmp!(NxD2.png(400))
  smoke1_with_broken_fs_mv(:silent) { NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(900.0), tmp) }

  NxTest.assert_equal(false, File.exist?(png_path),
                      'config sa zmenil — obrazok stareho tvaru sa NESMIE parovat s novym')
  NxTest.assert_equal(false, File.exist?(tmp), 'nepouzity capture temp sa zahodil')
end

NxTest.test('SMOKE1: upsert cesta sa sprava NAOPAK — zlyhany presun stary PNG ZMAZE') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')

  # Tu sa config MENI, takze stary obrazok uz patri inemu tvaru skrinky —
  # radsej schema nez zly obrazok. Obe cesty sa teda lisia ZAMERNE.
  tmp = NxD2.tmp!(NxD2.png(400))
  smoke1_with_broken_move { NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg(900.0), tmp) }

  NxTest.assert_equal(false, File.exist?(png_path), 'neplatny stary PNG je prec')
  NxTest.assert_close(900.0, NxD2::TS.find('cabinet', 'Dolná klasik')['config']['width'], 0.01,
                      'zaznam sa napriek tomu ulozil')
end

# Zlyhanie SAMOTNEHO `File.rename` — posledny krok stagingu (Codex #186 P2).
# `mv` medzi zvazkami (presmerovany %TEMP% vs. %APPDATA%) nie je rename, ale
# STREAMOVANA KOPIA. Kym isla priamo do cieloveho suboru, chyba v polovici uz
# stary PNG orezala. Teraz sa kompletizuje `<ciel>.new` a padnut moze len
# rename v ramci JEDNEHO priecinka — ciel preto ostava nedotknuty.
#
# Padnut smie LEN posledny krok: `FileUtils.mv` si vnutorne tiez sklada rename,
# takze stub sa viaze na ZDROJ koncaci `.new` — inak by sa staging vobec
# nestihol vyrobit a test by dokazoval nieco ine, nez tvrdi.
def smoke1_with_broken_rename
  orig = File.method(:rename)
  File.define_singleton_method(:rename) do |src, dst|
    raise Errno::EACCES, 'simulovana chyba FS' if src.to_s.end_with?('.new')

    orig.call(src, dst)
  end
  yield
ensure
  File.define_singleton_method(:rename, orig)
end

NxTest.test('SWEEP: zlyhany RENAME nechá starý náhľad BAJT PO BAJTE (Codex #186 P2)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')
  before = File.binread(png_path)

  tmp = NxD2.tmp!(NxD2.png(400))
  result = nil
  smoke1_with_broken_rename { result = NxD2::TS.set_preview('cabinet', 'Dolná klasik', tmp) }

  NxTest.assert_equal(false, result, 'zlyhanie sa prizna (ziadny falosny uspech)')
  NxTest.assert_equal(before, File.binread(png_path),
                      'POVODNY nahlad je nedotknuty — nie orezany, nie prepisany')
  NxTest.assert_equal(false, File.exist?("#{png_path}.new"),
                      'staging subor po sebe NEOSTAL visiet v priecinku nahladov')
  NxTest.assert_equal(false, File.exist?(tmp), 'nepouzity capture temp sa zahodil')
end

NxTest.test('SWEEP: uspesny presun po sebe staging subor NENECHA') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxD2.reset!
  NxD2::TS.upsert('cabinet', 'Dolná klasik', NxD2.cfg, NxD2.tmp!(NxD2.png(200)))
  png_path = NxD2::TP.path_for('cabinet', 'Dolná klasik')

  novy = NxD2.png(400)
  tmp = NxD2.tmp!(novy)
  NxTest.assert_equal(true, NxD2::TS.set_preview('cabinet', 'Dolná klasik', tmp))

  NxTest.assert_equal(novy, File.binread(png_path), 'na cieli je NOVY obrazok')
  NxTest.assert_equal(false, File.exist?("#{png_path}.new"), 'staging subor je prec')
  NxTest.assert_equal(false, File.exist?(tmp), 'capture temp je prec')
  NxTest.assert_equal(1, Dir.children(NxD2::TP.dir).count { |f| f.end_with?('.png') },
                      'v priecinku nahladov nepribudol ziadny odpad')
end

NxTest.test('SMOKE1 capture: cesta fotenia NEROBI operaciu ani zapis do modelu') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'template_previews.rb'), encoding: 'UTF-8')
  # Komentare o zakaze operacie sa nepocitaju — hlada sa REALNE volanie.
  code = src.lines.reject { |l| l.strip.start_with?('#') }.join
  NxTest.assert_equal(false, code.include?('start_operation'), 'capture nikdy nezacina operaciu')
  NxTest.assert(src.include?('restore_camera(view, cam)'), 'kamera sa obnovuje')
  NxTest.assert(src.include?('ensure'), 'obnova kamery bezi v ensure — aj pri vynimke')

  ts = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'templates.rb'), encoding: 'UTF-8')
  NxTest.assert(ts.include?('def set_preview'), 'sklad ma vlastnu cestu na vymenu obrazka')
  NxTest.assert(ts[/def set_preview.*?\n      end\n/m].to_s.include?('with_lock'),
                'set_preview bezi pod TYM ISTYM sidecar zamkom ako upsert/delete')
end

NxTest.test('SMOKE1 guard: „Odfotiť" pyta PRAVE JEDNU oznacenu skrinku a nefoti dosky') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates.rb'), encoding: 'UTF-8')
  body = src[/def capture_preview_for.*?\n        end\n/m].to_s
  NxTest.assert(body.include?("unless k == 'cabinet'"), 'doskova sablona sa nefoti')
  NxTest.assert(body.include?('TemplateStore.find(k, n).nil?'), 'sablona musi existovat')
  NxTest.assert(body.include?('cabs.empty?'), 'bez oznacenia sa odmieta')
  NxTest.assert(body.include?('cabs.length > 1'), 'viac oznacenych skriniek sa odmieta')
  NxTest.assert(body.include?('TemplateStore.set_preview(k, n, tmp)'), 'zapisuje sa cez sklad, nie priamo')
  NxTest.assert_equal(false, body.include?('start_operation'), 'ziadny krok Späť')

  sel = src[/def selected_cabinets.*?\n        end\n/m].to_s
  NxTest.assert(sel.include?("Store.kind(e) == 'cabinet'"), 'berie sa LEN priamo oznaceny korpus')
end

NxTest.test('SMOKE1 okno Sablony: „Odfotiť" ma vlastny callback a nevola upsert') do
  rb = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'), encoding: 'UTF-8')
  NxTest.assert(rb.include?("cb(dlg, 'tpl_capture')"), 'callback je zaregistrovany')
  body = rb[/def handle_capture.*?\n        end\n/m].to_s
  NxTest.assert(body.include?("Panel.capture_preview_for('cabinet', name)"), 'jedna zdielana cesta')
  NxTest.assert_equal(false, body.include?('upsert'), 'fotenie NEPREPISUJE zaznam sablony')

  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'templates_dialog.js'), encoding: 'UTF-8')
  NxTest.assert(js.include?('sketchup.tpl_capture'), 'okno posiela meno sablony na server')
  NxTest.assert(js.include?('function captureLabel'), 'riadok rozlisuje Odfotiť / Prefotiť')
end
