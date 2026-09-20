# frozen_string_literal: true
# S1-A2 — sekcia SPOTREBIČE (`appl`) v okne Štúdio: KANÁL (server) a jeho hranice.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. Whitelist akcii sekcie je UZAVRETY a `ready` v nom BYT NESMIE: Studio
#      registruje callbacky pod TYMI ISTYMI menami, takze `ready` by prepisal
#      jeho vlastny — okno by prestalo dostat prvy push a ostalo by prazdne.
#      Toto je presne ten druh chyby, ktoru vidis az po spusteni SketchUpu.
#   2. Polia karty a polia MODALU maju JEDEN zdroj (`ROWS`) a KAZDE z nich
#      musi poznat aj katalog. Pole, ktore je v UI a nie je vo whiteliste
#      kategorie, by pouzivatel vyplnil a server by cely zapis odmietol ako
#      „neznáme pole" — formular by sa nedal ulozit a nebolo by vidiet preco.
#   3. Kluc pola modalu je PRESNE cesta, ktoru katalog vracia v chybe. Keby sa
#      tvary rozisli, `NXModal.showErrors` by pole nenasiel a bezne odmietnutie
#      (min > max) by skoncilo v zbernom pase bez oznaceneho vstupu.
#   4. `appl_open_url` musi odmietnut vsetko okrem http/https. Adresa chodi
#      z KLIENTA a `UI.openURL` nad `file:` alebo `javascript:` je uplne iny
#      druh akcie, nez na aky pouzivatel klikol.
#   5. Zapis do katalogu NESMIE zdvihnut generaciu okna ani poslat plny push:
#      katalog spotrebicov v tejto davke nemeni ziadne cislo zakazky, takze by
#      zbytocne zneplatnil rozkliknuty riadok Kusovnika a rozrobeny export.
#   6. `UI.messagebox` v callbacku sekcie NIKDY — nativny modal blokuje cely
#      kanal HtmlDialogu a Studio by zamrzlo.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'appliance_catalog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog') if NxTest.headless?

S1A2_AP_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'appliance_dialog.rb'),
                       encoding: 'UTF-8')
S1A2_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
S1A2_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
S1A2_SHELL_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'),
                          encoding: 'UTF-8')
S1A2_AP_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'appliances.js'),
                       encoding: 'UTF-8')
S1A2_ICONS_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'icons.js'),
                          encoding: 'UTF-8')
S1A2_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# Zdrojak BEZ komentarov — mena zakazanych veci v komentaroch ZAMERNE ostavaju.
S1A2_AP_CODE = S1A2_AP_RB.lines.reject { |l| l.strip.start_with?('#') }.join
S1A2_AP_JS_CODE = S1A2_AP_JS.lines.reject { |l| l.strip.start_with?('//') }.join

S1A2_AD = Noxun::Engine::ApplianceDialog
S1A2_AC = Noxun::Engine::ApplianceCatalog

# --- 1) `appl` je ZIVA sekcia vo vsetkych zrkadlach --------------------------

NxTest.test('S1-A2: `appl` je ZIVA sekcia vo VSETKYCH TROCH zrkadlach') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  js = S1A2_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  shell = S1A2_SHELL_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  NxTest.assert(rb.include?('appl'), 'Ruby je autorita zoznamu sekcii')
  NxTest.assert_equal(rb, js, 'studio.js je jeho zrkadlo')
  NxTest.assert_equal(rb, shell, 'a shell.js (deep-link `openStudio`) tiez')
end

NxTest.test('S1-A2: sekcia stoji v skupine KATALÓGY medzi Kovanim a Pravidlami') do
  rb = Noxun::Engine::StudioDialog::SECTIONS
  NxTest.assert_equal(rb.index('hw') + 1, rb.index('appl'), 'hned za `hw`')
  NxTest.assert_equal(rb.index('appl') + 1, rb.index('rules'), 'a hned pred `rules`')
  nav = S1A2_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  item = nav[/\{ id: 'appl'.*?\},/m].to_s
  NxTest.assert(!item.empty?, 'polozka navigacie sa nasla')
  NxTest.assert(item.include?("ic: 'appliance'"), 'ikona = appliance')
  NxTest.refute(item.include?('disabled:'), 'polozka nie je neaktivna — sekcia zije')
  # Badge by tvrdil, ze sa nieco pocita; pocty „chyba/nesedi" pridu az v S1-B.
  NxTest.refute(item.include?('badge:'), 'badge navigacie v A2 EST NIE JE')
end

NxTest.test('S1-A2: sekcia ma hlavicku (SEC_META) a vlastnu vetvu listy aj tela') do
  meta = S1A2_STUDIO_JS[/appl: \{ t: 'Spotrebiče',.*?\},/m].to_s
  NxTest.assert(meta.include?('tohto počítača'), 'hint hovori, ze katalog je vec POCITACA')
  NxTest.assert(S1A2_STUDIO_JS.include?("if (studioSec === 'appl'){"),
                'lista aj telo maju vlastnu vetvu')
  NxTest.assert(S1A2_STUDIO_JS.include?('apRenderTools'), 'listu kresli appliances.js')
  NxTest.assert(S1A2_STUDIO_JS.include?('apRenderBody'), 'telo tiez')
  NxTest.assert(S1A2_STUDIO_JS.include?('apOnLeaveSection'),
                'odchod zo sekcie ma hook (modal zije mimo tela sekcie)')
end

# --- 2) whitelist akcii sekcie ----------------------------------------------

NxTest.test('S1-A2: whitelist akcii sekcie je UZAVRETY a `ready` v nom NIE JE') do
  acts = S1A2_AD::SECTION_ACTIONS
  NxTest.assert_equal(%w[appl_tree appl_card appl_create appl_patch appl_delete appl_restore
                         appl_attach appl_thumbnail appl_remove_attachment
                         appl_open_url appl_open_attachment appl_leave],
                      acts, 'presne tieto akcie a ziadne ine')
  NxTest.refute(acts.include?('ready'), '`ready` by prepisal vlastny callback okna')
  NxTest.assert(acts.frozen?, 'zoznam je zmrazeny')
  NxTest.assert(acts.all? { |a| a.start_with?('appl_') },
                'kazda akcia ma vlastny priestor mien — inak by prepisala callback inej sekcie')
end

NxTest.test('S1-A2: mena akcii sa NEZRAZAJU s inymi sekciami Studia') do
  others = []
  others += Noxun::Engine::HardwareCatalogDialog::SECTION_ACTIONS if defined?(Noxun::Engine::HardwareCatalogDialog)
  others += Noxun::Engine::MaterialsDialog::SECTION_ACTIONS if defined?(Noxun::Engine::MaterialsDialog)
  others += Noxun::Engine::RulesDialog::SECTION_ACTIONS if defined?(Noxun::Engine::RulesDialog)
  others += Noxun::Engine::TemplatesDialog::SECTION_ACTIONS if defined?(Noxun::Engine::TemplatesDialog)
  clash = S1A2_AD::SECTION_ACTIONS & others
  NxTest.assert(clash.empty?, "kolizia mien callbackov: #{clash.join(' ')}")
end

NxTest.test('S1-A2: neznama akcia sa NEVYKONA — dispatch ju odmietne') do
  sent = []
  S1A2_AD.dispatch('appl_nuke', '{}', ->(s) { sent << s })
  NxTest.assert_equal(1, sent.length, 'prisla presne jedna odpoved')
  NxTest.assert(sent.first.start_with?('AP.setStatus('), 'a je to stavova hlaska')
  NxTest.assert(sent.first.include?('Neznáma akcia'), 'ktora to prizna')
end

NxTest.test('S1-A2: Studio registruje VSETKY akcie sekcie (a nic navyse)') do
  NxTest.assert(S1A2_STUDIO_RB.include?('appl_actions.each { |name| cb(dlg, name) { |p| do_appl(name, p) } }'),
                'callbacky sa registruju z JEDINEHO zoznamu — druha kopia by sa rozisla')
  NxTest.assert(S1A2_STUDIO_RB.include?('def appl_sink'), 'odpoved ide do TOHTO okna')
  NxTest.assert(S1A2_STUDIO_RB.include?('def appl_js'), 'a mimo volania sekcie cez verejny most')
  NxTest.assert(S1A2_STUDIO_RB.include?('appl: appl_payload'),
                'prvotny stav sekcie ide v push_state pod klucom `appl`')
end

# --- 3) refresh invariant ----------------------------------------------------

NxTest.test('S1-A2: zapis do katalogu NEDVIHA generaciu okna a neposiela plny push') do
  %w[push_state refresh_if_open NX.setStudio bump].each do |forbidden|
    NxTest.refute(S1A2_AP_CODE.include?(forbidden),
                  "#{forbidden} v sekcii nema co robit — katalog spotrebicov nemeni cislo zakazky")
  end
  NxTest.assert(S1A2_AP_CODE.include?('NX.applTree('), 'echo posiela strom')
  NxTest.assert(S1A2_AP_CODE.include?('NX.applCard('), 'a kartu')
end

NxTest.test('S1-A2: echo kresli LEN ked je sekcia `appl` aktivna (zdielany #secbody)') do
  NxTest.assert(S1A2_AP_JS_CODE.include?("studioActiveSection() === 'appl'"),
                'klient sa pyta autority (`studio.js`), ktora sekcia je otvorena')
  %w[apSetTree apSetCard].each do |fn|
    body = S1A2_AP_JS[/function #{fn}\(.*?\n  \}\n/m].to_s
    NxTest.assert(body.include?('if (!apIsActive()) return;'),
                  "#{fn} nekresli, kym je otvorena INA sekcia (review #225 P1)")
  end
end

NxTest.test('S1-A2: nativny modal v callbacku NIKDY (D-15 danger modal namiesto neho)') do
  NxTest.refute(S1A2_AP_CODE.include?('UI.messagebox'),
                'UI.messagebox by zablokoval cely kanal HtmlDialogu')
  NxTest.assert(S1A2_AP_JS_CODE.include?('danger: true'), 'mazanie potvrdzuje D-15 danger modal')
end

# --- 4) polia karty a modalu maju jeden zdroj a katalog ich pozna ------------

NxTest.test('S1-A2: KAZDE pole karty pozna aj whitelist kategorie v katalogu') do
  bad = []
  S1A2_AC::CATEGORIES.each do |cat|
    S1A2_AD.modal_paths(cat).each do |(block, field)|
      root, nested = field.to_s.split('.')
      allowed = S1A2_AC.block_fields(block, cat)
      next bad << "#{cat}/#{block}.#{field}" unless allowed.include?(root)
      next if nested.nil?

      bad << "#{cat}/#{block}.#{field}" unless root == 'furniture_doors' &&
                                               S1A2_AC::FURNITURE_DOOR_FIELDS.include?(nested)
    end
  end
  NxTest.assert(bad.empty?,
                "polia, ktore UI ponuka a katalog nepozna: #{bad.join(' · ')} — " \
                'zapis by skoncil ako „neznáme pole" a formular by sa nedal ulozit')
end

NxTest.test('S1-A2: kazde pole modalu ma POPISOK (ziadny holy kluc na obrazovke)') do
  missing = []
  S1A2_AC::CATEGORIES.each do |cat|
    S1A2_AD.form_fields(cat).each do |f|
      next if f['type'] == 'group'

      label = f['label'].to_s
      missing << "#{cat}/#{f['key']}" if label.empty? || label == f['field'].to_s
    end
  end
  NxTest.assert(missing.empty?, "polia bez SK popisku: #{missing.join(' · ')}")
end

NxTest.test('S1-A2: kluc pola modalu je PRESNE cesta, ktoru katalog vracia v chybe') do
  # Odmietnutie z katalogu (`min > max`) nesie cestu `dims.niche.width_min`.
  status, info = S1A2_AC.normalize_dims({ 'niche' => { 'width_min' => 600.0, 'width_max' => 500.0 } },
                                        'oven')[0..2].then { |d, m, f| [d ? :ok : :invalid, { message: m, field: f }] }
  NxTest.assert_equal(:invalid, status, 'min > max je odmietnutie')
  field = info[:field].to_s
  NxTest.assert_equal('dims.niche.width_min', field, 'cesta pola z katalogu')
  keys = S1A2_AD.form_fields('oven').reject { |f| f['type'] == 'group' }.map { |f| f['key'] }
  NxTest.assert(keys.include?(field),
                'a presne tak sa vola kluc pola modalu — ziadna prekladova tabulka')
  NxTest.assert_equal(field, S1A2_AD.modal_field(field), 'preklad je identita')
end

NxTest.test('S1-A2: enum pole ponuka PRAZDNU volbu (neznáme pole = prázdne)') do
  f = S1A2_AD.form_fields('fridge').find { |x| x['key'] == 'dims.install.door_system' }
  NxTest.assert(!f.nil?, 'pole `door_system` je vo formulari')
  NxTest.assert_equal('select', f['type'], 'enum sa kresli ako select')
  NxTest.assert_equal(['', '—'], f['options'].first, 'prva volba je „ziadna"')
  codes = f['options'][1..].map(&:first)
  NxTest.assert_equal(S1A2_AC::ENUM_FIELDS['door_system'], codes, 'kody su z katalogu')
end

NxTest.test('S1-A2: SK popisky enumov pokryvaju VSETKY hodnoty katalogu') do
  missing = []
  S1A2_AC::ENUM_FIELDS.each do |name, values|
    map = S1A2_AD::ENUM_LABELS[name] || {}
    values.each { |v| missing << "#{name}=#{v}" unless map.key?(v) }
  end
  NxTest.assert(missing.empty?, "enumy bez SK popisku: #{missing.join(' · ')}")
end

NxTest.test('S1-A2: karta ma pre KAZDU kategoriu styri bloky (aj prazdny sa prizna)') do
  S1A2_AC::CATEGORIES.each do |cat|
    rec = { 'id' => 'x', 'category' => cat, 'name' => 'Test', 'rev' => 'r' }
    blocks = S1A2_AD.card_payload(rec)['blocks']
    NxTest.assert_equal(S1A2_AC::DIM_BLOCKS, blocks.map { |b| b['key'] },
                        "#{cat}: bloky su v poradi tela -> niky -> cela -> montaze")
    NxTest.assert(blocks.all? { |b| !b['title'].to_s.empty? }, "#{cat}: kazdy blok ma nadpis")
  end
end

# --- 5) strom sklada server --------------------------------------------------

NxTest.test('S1-A2: strom drzi PORADIE kategorii z katalogu (JS nic nepreskladava)') do
  payload = S1A2_AD.tree_payload('', false, 7)
  codes = payload['groups'].map { |g| g['code'] }.reject { |c| c == S1A2_AD::DELETED_GROUP }
  NxTest.assert_equal(S1A2_AC::CATEGORIES, codes, 'poradie skupin = poradie CATEGORIES')
  NxTest.assert_equal(7, payload['gen'], '`gen` sa len echuje (staršia odpoveď sa zahodí)')
  NxTest.assert(payload.key?('state') && payload.key?('writable'),
                'stav katalogu chodi v KAZDOM payloade — banner sa nesmie rozist so zapismi')
  NxTest.assert(payload['categories'].is_a?(Array), 'kategorie pre select modalu chodia zo servera')
end

NxTest.test('S1-A2: formular chodi LEN na vyziadanie (`form: true`)') do
  NxTest.refute(S1A2_AD.tree_payload('', false, 0).key?('form'),
                'bezny strom formular NENESIE — v kazdom pushi by to boli kB navyse')
  sent = []
  S1A2_AD.dispatch('appl_tree', { 'query' => '', 'gen' => 1, 'form' => true }.to_json,
                   ->(s) { sent << s })
  line = sent.find { |s| s.start_with?('NX.applTree(') }
  NxTest.assert(!line.nil?, 'odpoved je strom')
  data = JSON.parse(line[/\ANX\.applTree\((.*)\)\z/m, 1])
  NxTest.assert(data['form'].is_a?(Hash), 'na vyziadanie formular v payloade JE')
  NxTest.assert_equal(S1A2_AC::CATEGORIES.sort, data['form'].keys.sort,
                      'a pozna VSETKY kategorie (klient prepina sadu poli bez servera)')
end

NxTest.test('S1-A2: odchod zo sekcie ZABUDNE filter stromu') do
  S1A2_AD.dispatch('appl_tree', { 'query' => 'beko', 'include_deleted' => true, 'gen' => 2 }.to_json,
                   ->(_s) {})
  NxTest.assert_equal('beko', S1A2_AD.view_query, 'server si filter pamata pre echo')
  NxTest.assert(S1A2_AD.view_deleted?, 'aj prepinac vyradenych')
  S1A2_AD.dispatch('appl_leave', '{}', ->(_s) {})
  NxTest.assert_equal('', S1A2_AD.view_query,
                      'po odchode nie — plny push by inak nakreslil strom zuzeny neviditelnym filtrom')
  NxTest.refute(S1A2_AD.view_deleted?, 'a prepinac tiez')
end

# --- 6) otvaranie odkazov ----------------------------------------------------

NxTest.test('S1-A2: `appl_open_url` pusti LEN http a https') do
  %w[http://noxun.sk https://www.beko.com/list.pdf].each do |ok|
    NxTest.assert(S1A2_AD.http_url?(ok), "#{ok} je platna adresa")
  end
  ['file:///C:/Windows/System32/cmd.exe', 'javascript:alert(1)', 'ftp://server/x',
   'skp:launch', '', 'https://', 'nie je adresa'].each do |bad|
    NxTest.refute(S1A2_AD.http_url?(bad), "#{bad.inspect} sa NESMIE otvorit")
  end
end

NxTest.test('S1-A2: odmietnuta adresa sa NEOTVARA — sekcia to povie statusom') do
  sent = []
  S1A2_AD.dispatch('appl_open_url', { 'url' => 'file:///C:/tajne.txt' }.to_json, ->(s) { sent << s })
  NxTest.assert_equal(1, sent.length, 'jedna odpoved')
  NxTest.assert(sent.first.include?('Neplatný odkaz'), 'a je to odmietnutie s dovodom')
end

# --- 7) lazy kanal miniatur --------------------------------------------------

NxTest.test('S1-A2: miniatury chodia LEN na vyziadanie karty') do
  rec = { 'id' => 'x', 'category' => 'fridge', 'name' => 'Test', 'rev' => 'r',
          'attachments' => [{ 'id' => 'a1', 'kind' => 'image', 'file' => 'a1_x.png', 'name' => 'x.png' }] }
  NxTest.assert_equal({}, S1A2_AD.card_payload(rec)['thumbs'],
                      'echo po zapise obrazky NENESIE (inak by kazda zmena nazvu poslala stovky kB)')
  NxTest.assert(S1A2_AD.card_payload(rec, thumbs: true).key?('thumbs'),
                'na vyziadanie karty ano')
end

NxTest.test('S1-A2: klient, ktory miniaturu UZ MA, ju druhy raz nedostane') do
  rec = { 'id' => 'x', 'category' => 'fridge', 'name' => 'Test', 'rev' => 'r',
          'attachments' => [{ 'id' => 'a1', 'kind' => 'image', 'file' => 'a1_x.png', 'name' => 'x.png' },
                            { 'id' => 'a2', 'kind' => 'sheet', 'file' => 'a2_x.pdf', 'name' => 'x.pdf' }] }
  thumbs = S1A2_AD.card_payload(rec, thumbs: true, have: ['a1'])['thumbs']
  NxTest.refute(thumbs.key?('a1'), 'uz zacachovanu prilohu server neposiela')
  NxTest.refute(thumbs.key?('a2'), 'a PDF nikdy — nahlad z neho UI nevykresli')
end

# 1x1 PNG — validny subor, nie len magic bytes.
S1A2_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='

NxTest.test('S1-A2: nahradna cesta miniatury posle POVODNY subor — ale len maly a spravny') do
  require 'tmpdir'
  Dir.mktmpdir('noxun-s1a2-') do |dir|
    small = File.join(dir, 'x.png')
    File.binwrite(small, S1A2_PNG.unpack1('m'))
    uri = S1A2_AD.thumb_data_uri(small)
    NxTest.assert(uri.to_s.start_with?('data:image/png;base64,'),
                  'maly obrazok so spravnymi magic bytes ide klientovi ako data URI')

    big = File.join(dir, 'big.png')
    File.binwrite(big, S1A2_PNG.unpack1('m') + ('x' * (300 * 1024)))
    NxTest.assert(S1A2_AD.thumb_data_uri(big).nil?,
                  "obrazok nad #{S1A2_AD::THUMB_MAX_BYTES / 1024} kB sa NEPOSIELA — data URI nad strop "                   'uz nie je nahlad, ale prenos (klient si `nil` zacachuje a nepyta sa znova)')

    pdf = File.join(dir, 'list.pdf')
    File.binwrite(pdf, '%PDF-1.7')
    NxTest.assert(S1A2_AD.thumb_data_uri(pdf).nil?, 'z PDF sa nahlad nerobi')

    fake = File.join(dir, 'podvrh.png')
    File.binwrite(fake, 'toto nie je obrazok')
    NxTest.assert(S1A2_AD.thumb_data_uri(fake).nil?,
                  'subor s obrazkovou priponou, ale bez magic bytes, sa do okna nedostane')
    NxTest.assert(S1A2_AD.thumb_data_uri(File.join(dir, 'niet.png')).nil?, 'chybajuci subor = nil')
  end
end

NxTest.test('S1-A2: prilohy nesu DRUH, nie cestu na disk') do
  rec = { 'id' => 'x', 'category' => 'fridge', 'name' => 'T', 'rev' => 'r',
          'attachments' => [{ 'id' => 'a1', 'kind' => 'thumbnail', 'file' => 'a1_x.jpg', 'name' => 'x.jpg' },
                            { 'id' => 'a2', 'kind' => 'sheet', 'file' => 'a2_x.pdf', 'name' => 'list.pdf' }] }
  list = S1A2_AD.card_payload(rec)['attachments']
  NxTest.assert(list.none? { |a| a.key?('path') }, 'cesta na disk do CEF nikdy nechodi')
  NxTest.assert(list[0]['image'] && list[0]['thumbnail'], 'nahlad je obrazok a je oznaceny')
  NxTest.refute(list[1]['image'], 'PDF nie je obrazok')
end

# --- 8) texty karty ----------------------------------------------------------

NxTest.test('S1-A2: nezname pole je `nil` (klient kresli „—"), odvodene nesie priznak') do
  rec = { 'id' => 'x', 'category' => 'oven', 'name' => 'T', 'rev' => 'r',
          'dims' => { 'body' => { 'height' => 570.0, 'depth' => 548.0 } },
          'derived' => ['body.depth'] }
  rows = S1A2_AD.card_payload(rec)['blocks'].find { |b| b['key'] == 'body' }['rows']
  NxTest.assert_equal('— × 570 × 548', rows.first['value'],
                      'chybajuci clen trojice sa prizna pomlckou, riadok nezanika')
  NxTest.assert(rows.first['derived'], 'riadok s odvodenym clenom je oznaceny')
  empty = S1A2_AD.card_payload({ 'id' => 'x', 'category' => 'oven', 'name' => 'T', 'rev' => 'r' })
  NxTest.assert(empty["blocks"].first["rows"].first["value"].nil?,
                    'uplne nevyplneny riadok je nil — text „—" sklada klient')
end

NxTest.test('S1-A2: jednostranny rozsah sa PRIZNA slovom (holé číslo by klamalo)') do
  NxTest.assert_equal('min 560', S1A2_AD.range_text(560.0, nil))
  NxTest.assert_equal('max 568', S1A2_AD.range_text(nil, 568.0))
  NxTest.assert_equal('560 – 568', S1A2_AD.range_text(560.0, 568.0))
  NxTest.assert_equal('560', S1A2_AD.range_text(560.0, 560.0), 'rovnake konce = jedno cislo')
  NxTest.assert_equal('', S1A2_AD.range_text(nil, nil))
end

NxTest.test('S1-A2: mm ide na obrazovku v slovenskom tvare (ciarka, bez .0)') do
  NxTest.assert_equal('548', S1A2_AD.fmt_mm(548.0))
  NxTest.assert_equal('19,5', S1A2_AD.fmt_mm(19.5))
end

# --- 9) vstup modalu -> atributy katalogu ------------------------------------

NxTest.test('S1-A2: prazdne pole formulara ZMAZE hodnotu (nikdy sa nedoplni odhadom)') do
  attrs = S1A2_AD.attrs_from('name' => 'X', 'dims.body.width' => '548',
                             'dims.body.height' => '', 'dims.front.overhang_ref' => 'body',
                             'shop_urls' => ['https://a.sk', '  '])
  NxTest.assert_equal('548', attrs['dims']['body']['width'])
  NxTest.assert(attrs['dims']['body'].key?('height'), 'kluc v patchi JE')
  NxTest.assert(attrs['dims']['body']['height'].nil?, 'ale s hodnotou nil = zmaz (semantika A10)')
  NxTest.assert_equal(['https://a.sk'], attrs['shop_urls'], 'prazdne riadky odkazov vypadnu')
  NxTest.assert_equal('body', attrs['dims']['front']['overhang_ref'])
end

NxTest.test('S1-A2: vnorene pole (`furniture_doors`) sa sklada spat do stromu') do
  attrs = S1A2_AD.attrs_from('dims.front.furniture_doors.lower_min' => '600')
  NxTest.assert_equal('600', attrs['dims']['front']['furniture_doors']['lower_min'])
end

NxTest.test('S1-A2: z formulara sa NEPREBERA nic, co katalog nepusti') do
  attrs = S1A2_AD.attrs_from('id' => 'podvrh', 'rev' => 'x', 'seed' => true,
                             'attachments' => [], 'deleted_at' => 'kedysi', 'name' => 'X')
  NxTest.assert_equal(%w[name], attrs.keys, 'whitelist vstupu drzi server, nie formular')
end

# --- 10) klient: subory, poradie a cache-bust --------------------------------

NxTest.test('S1-A2: `appliances.js` sa nacitava AZ ZA `studio.js`') do
  ver = NxTest::LOADER_VERSION
  ap = S1A2_STUDIO_HTML.index("js/appliances.js?v=#{ver}")
  st = S1A2_STUDIO_HTML.index("js/studio.js?v=#{ver}")
  NxTest.assert(!ap.nil? && !st.nil?, 'oba skripty su v studio.html so spravnym `?v=`')
  NxTest.assert(ap > st,
                'appliances.js obaluje NX.setStudio a doplna NX.appl* — v opacnom poradi by ich ' \
                '`window.NX = {…}` zo studio.js prepisalo')
end

NxTest.test('S1-A2: ikona `appliance` je v sprite a v inventari UI_DIZAJN §4') do
  NxTest.assert(S1A2_ICONS_JS.include?("'appliance':"), 'symbol je v `icons.js`')
  NxTest.assert(S1A2_ICONS_JS.include?("'image':"), 'aj dlazdicovy `image`')
  dizajn = File.read(File.join(NxTest::ROOT, 'docs', 'UI_DIZAJN.md'), encoding: 'UTF-8')
  NxTest.assert(dizajn.include?('`appliance` (S1-A2'), 'inventar ikon ju pozna')
  NxTest.assert(dizajn.include?('`image` (S1-A2'), 'a druhu tiez')
end

NxTest.test('S1-A2: klient ma vlastny priestor mien (`ap*` / `AP_*`)') do
  globals = S1A2_AP_JS_CODE.scan(/^  (?:var|function) ([A-Za-z_][A-Za-z0-9_]*)/).flatten.uniq
  bad = globals.reject { |g| g.start_with?('ap', 'AP') }
  NxTest.assert(bad.empty?,
                "globaly bez prefixu: #{bad.join(' ')} — subor bezi v TOM ISTOM scope ako studio.js")
end

NxTest.test('S1-A2: pohlad „V zákazke" aj „Do zákazky" su aria-disabled s DOVODOM (D-78)') do
  NxTest.assert(S1A2_AP_JS.include?('data-ap="view" data-v="job" aria-disabled="true"'),
                'segment pohladov ma neaktivnu polovicu')
  NxTest.assert(S1A2_AP_JS.include?('data-ap="tojob" aria-disabled="true"'),
                'a tlacidlo karty tiez')
  NxTest.assert(S1A2_AP_JS.scan(/S1-B/).length >= 3,
                'dovod („príde v S1-B") je v tooltipe aj v hlaske po kliku — nie mrtve tlacidlo')
  NxTest.refute(S1A2_AP_JS_CODE.include?(' disabled>'),
                'HTML `disabled` by prvok vyhodilo z Tab poradia a mlcalo by')
end
