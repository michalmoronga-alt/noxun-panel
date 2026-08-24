# frozen_string_literal: true
# ŠT-3c-2 — PREMENOVANIE sablony: co sa pri nom NESMIE stratit.
#
# Premenovanie meni IDENTITU perzistovaneho zaznamu, a od tej identity visia
# tri dalsie veci: PNG nahlad (meno je sucastou hashu suboru), peciatka
# „naposledy pouzite" (kluc je „kind:nazov") a poradie dlazdic v knizniciach.
# Klikanim sa to neoveri — chyba sa prejavi az o tyzden ako „kde sa podela
# fotka" alebo „preco sa mi dlazdice preskladali".
#
# Co tato sada strazi:
#   1. IN-PLACE zmena (audit B1): zaznam ostava na SVOJOM mieste v zozname
#      a nezname kluce (novsia verzia Noxunu) prezivaju. `upsert` by spravil
#      oboje zle — stavia zaznam nanovo a pripina ho na koniec.
#   2. GUARDY POD ZAMKOM (B2/B3): kolizia mena a zmiznuta sablona vracaju
#      symbol a subor NECHAVAJU byte-nezmeneny; forward guard (novsia schema)
#      odmieta zapis uplne.
#   3. PNG sa presunie POD NOVE hashove meno a pod starym uz nie je.
#   4. Peciatka sa PRENESIE s POVODNYM cislom (nie `stamp` — to by sablonu
#      povysilo na „naposledy pouzitu" a preskladalo dlazdice).
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog') if NxTest.headless?
# Sekcia po premenovani BROADCASTUJE do panela (`Panel.push_template_renamed`,
# `Panel.push_templates`) — bez tohto modulu by handler headless spadol na
# neznamej konstante a testy by merali vynimku, nie spravanie. `Panel.js` bez
# ziveho dialogu nic nerobi, takze je to ciste.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync') if NxTest.headless?

ST3C2_TPL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'),
                         encoding: 'UTF-8')
ST3C2_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'templates.js'),
                     encoding: 'UTF-8')
ST3C2_CORE_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'templates.rb'),
                          encoding: 'UTF-8')
# Minimalne validne PNG pre fixtury (magic bytes + vypln nad prazdny subor).
ST3C2_PNG = ("\x89PNG\r\n\x1A\n".b + ('x' * 64).b).freeze

# Docasna sablona s CUDZIM klucom — simuluje zaznam ulozeny NOVSOU verziou.
def st3c2_seed(name, extra = {})
  store = Noxun::Engine::TemplateStore
  store.upsert('cabinet', name, { 'type' => 'lower', 'width' => 450.0 })
  return if extra.empty?

  list = store.load
  rec = list.find { |t| t['kind'] == 'cabinet' && t['name'] == name }
  extra.each { |k, v| rec[k] = v }
  store.send(:write_list, list)
end

def st3c2_cleanup(*names)
  names.each do |n|
    Noxun::Engine::TemplateStore.delete('cabinet', n)
    Noxun::Engine::TemplatePreviews.delete('cabinet', n)
  end
end

NxTest.test('ŠT-3c-2: rename je IN-PLACE — cudzi kluc prezije a poradie sa nemeni') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 A', 'ST3C2 B', 'ST3C2 A2')
  # Dve sablony za sebou: keby rename pouzil `upsert`, premenovana by skocila
  # NA KONIEC a pouzivatelovi by sa dlazdice preskladali.
  st3c2_seed('ST3C2 A', 'poznamka_z_buducnosti' => { 'x' => 1 })
  st3c2_seed('ST3C2 B')
  before = e::TemplateStore.load
  idx = before.index { |t| t['name'] == 'ST3C2 A' }

  NxTest.assert_equal(:ok, e::TemplateStore.rename('cabinet', 'ST3C2 A', 'ST3C2 A2'),
                      'premenovanie prejde')
  after = e::TemplateStore.load
  NxTest.assert_equal(idx, after.index { |t| t['name'] == 'ST3C2 A2' },
                      'zaznam ostal na SVOJOM mieste v zozname')
  rec = e::TemplateStore.find('cabinet', 'ST3C2 A2')
  NxTest.assert_equal({ 'x' => 1 }, rec['poznamka_z_buducnosti'],
                      'neznamy kluc z novsej verzie PREZIL (upsert by ho zahodil)')
  NxTest.assert_close(450.0, rec['config']['width'].to_f, 0.01, 'config sa nedotkol')
  NxTest.assert(e::TemplateStore.find('cabinet', 'ST3C2 A').nil?, 'stare meno uz neexistuje')
  NxTest.assert_equal(before.length, after.length, 'pocet sablon sa nezmenil')
ensure
  st3c2_cleanup('ST3C2 A', 'ST3C2 B', 'ST3C2 A2') if NxTest.headless?
end

NxTest.test('ŠT-3c-2: kolizia a zmiznute meno nechavaju subor BYTE-NEZMENENY') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 C', 'ST3C2 D')
  st3c2_seed('ST3C2 C')
  st3c2_seed('ST3C2 D')
  snap = File.binread(e::TemplateStore.path)

  NxTest.assert_equal(:exists, e::TemplateStore.rename('cabinet', 'ST3C2 C', 'ST3C2 D'),
                      'obsadene meno = :exists')
  NxTest.assert_equal(snap, File.binread(e::TemplateStore.path),
                      'a subor sa NEDOTKOL (guard bezi PRED zapisom)')
  NxTest.assert_equal(:missing, e::TemplateStore.rename('cabinet', 'ST3C2 neexistuje', 'ST3C2 E'),
                      'zmiznuta sablona = :missing')
  NxTest.assert_equal(snap, File.binread(e::TemplateStore.path), 'aj tu je subor netknuty')
  NxTest.assert_equal(:unchanged, e::TemplateStore.rename('cabinet', 'ST3C2 C', 'ST3C2 C'),
                      'rovnake meno ma VLASTNY vysledok a nezapisuje (NOTE 1)')
  NxTest.assert_equal(snap, File.binread(e::TemplateStore.path), 'a tiez bez dotyku suboru')
  NxTest.assert_equal(:missing, e::TemplateStore.rename('cabinet', '', 'ST3C2 E'),
                      'prazdne stare meno = :missing')
  NxTest.assert_equal(:failed, e::TemplateStore.rename('cabinet', 'ST3C2 C', '   '),
                      'prazdne nove meno (po strip) = :failed')
ensure
  st3c2_cleanup('ST3C2 C', 'ST3C2 D') if NxTest.headless?
end

NxTest.test('ŠT-3c-2: kniznica z NOVSEJ verzie sa nepremenuje (forward guard)') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 F', 'ST3C2 F2')
  st3c2_seed('ST3C2 F')
  raw = JSON.parse(File.read(e::TemplateStore.path, encoding: 'UTF-8'))
  raw['std'] = e::TemplateStore::STD + 1
  File.write(e::TemplateStore.path, JSON.pretty_generate(raw), encoding: 'UTF-8')
  e::TemplateStore.reload!
  snap = File.binread(e::TemplateStore.path)

  NxTest.assert_equal(:readonly, e::TemplateStore.rename('cabinet', 'ST3C2 F', 'ST3C2 F2'),
                      'novsia schema = :readonly')
  NxTest.assert_equal(snap, File.binread(e::TemplateStore.path), 'a NIC sa nezmenilo')
ensure
  if NxTest.headless?
    begin
      raw2 = JSON.parse(File.read(Noxun::Engine::TemplateStore.path, encoding: 'UTF-8'))
      raw2['std'] = Noxun::Engine::TemplateStore::STD
      File.write(Noxun::Engine::TemplateStore.path, JSON.pretty_generate(raw2), encoding: 'UTF-8')
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
    Noxun::Engine::TemplateStore.reload!
    st3c2_cleanup('ST3C2 F', 'ST3C2 F2')
  end
end

NxTest.test('ŠT-3c-2: NAHLAD sa presunie pod nove meno a pod starym uz nie je') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 G', 'ST3C2 G2')
  st3c2_seed('ST3C2 G')
  src = e::TemplatePreviews.path_for('cabinet', 'ST3C2 G')
  dst = e::TemplatePreviews.path_for('cabinet', 'ST3C2 G2')
  NxTest.assert(src && dst && src != dst, 'meno je sucastou identity PNG suboru')
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(src))
  # Minimalne validne PNG (magic bytes staci — `rev_for` cita mtime/velkost).
  File.binwrite(src, "\x89PNG\r\n\x1A\n".b + ('x' * 64).b)

  NxTest.assert_equal(:ok, e::TemplateStore.rename('cabinet', 'ST3C2 G', 'ST3C2 G2'))
  NxTest.assert(File.file?(dst), 'PNG je pod NOVYM hashovym menom')
  NxTest.refute(File.file?(src), 'a pod starym uz nie')
  NxTest.assert(!e::TemplatePreviews.rev_for('cabinet', 'ST3C2 G2').nil?,
                'nova sablona nahlad MA')
  NxTest.assert(e::TemplatePreviews.rev_for('cabinet', 'ST3C2 G').nil?,
                'stara ho nema (a UI sa jej uz aj tak nepyta)')
ensure
  st3c2_cleanup('ST3C2 G', 'ST3C2 G2') if NxTest.headless?
end

NxTest.test('ŠT-3c-2: peciatka sa PRENESIE s povodnym cislom (nie `stamp`)') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  u = e::TemplateUsage
  u.stamp('cabinet', 'ST3C2 H')          # najstarsia peciatka
  was = u.seq_for('cabinet', 'ST3C2 H')
  u.stamp('cabinet', 'ST3C2 CERSTVA')    # novsia — po prenose musi ostat vyssia
  fresh = u.seq_for('cabinet', 'ST3C2 CERSTVA')
  NxTest.assert(was.to_i.positive? && fresh.to_i > was.to_i, 'fixture: dve rozne peciatky')

  u.rename('cabinet', 'ST3C2 H', 'ST3C2 H2')
  NxTest.assert_equal(was, u.seq_for('cabinet', 'ST3C2 H2'),
                      'novy kluc nesie POVODNE cislo — premenovanie NIE JE pouzitie')
  NxTest.assert(u.seq_for('cabinet', 'ST3C2 H').nil?, 'stary kluc zanikol')
  NxTest.assert_equal(fresh, u.seq_for('cabinet', 'ST3C2 CERSTVA'),
                      'a cudzia peciatka sa nepohla')
end

NxTest.test('ŠT-3c-2: `delete` neexistujucej sablony uz NEHLASI uspech (N1)') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  NxTest.refute(e::TemplateStore.delete('cabinet', 'ST3C2 nikdy neexistovala'),
                'zapis „nezmeneneho zoznamu" sa uz nevydava za vymazanie')
  del = ST3C2_CORE_RB[/def delete\(kind, name\).*?\n      end\n/m].to_s
  NxTest.assert(del.include?('next false if find(k, n).nil?'), 'guard je POD zamkom')
  NxTest.assert(del.index('refuse_write') < del.index('find(k, n).nil?'),
                'a az za forward guardom (novsia kniznica ma vlastnu hlasku)')
end

NxTest.test('ŠT-3c-2: handler odmietnutie NEZATVARA modal a nerobi undo krok') do
  h = ST3C2_TPL_RB[/def handle_rename\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(!h.empty?, 'handler existuje')
  NxTest.assert(h.include?("data['new_name']"),
                'nove meno chodi pod `new_name` — `name` je v sekcii meno SUCASNE (pasca)')
  NxTest.assert(h.include?('.strip'), 'okrajove medzery su preklep, nie meno')
  NxTest.assert(h.include?('KINDS.include?(kind)'), 'druh sa validuje proti uzavretemu zoznamu')
  %i[ok exists missing readonly].each do |sym|
    NxTest.assert(h.include?("when :#{sym}"), "vetva pre :#{sym}")
  end
  NxTest.assert(h.include?('TemplateUsage.rename'), 'peciatka sa prenasa AZ po :ok')
  NxTest.assert(h.index('TemplateStore.rename') < h.index('TemplateUsage.rename'),
                'a MIMO zamku sablon (az po navrate zo skladu)')
  NxTest.refute(h.include?('after_model_write'),
                'kniznica je subor MIMO modelu — ZIADNY bump ani krok Spat')
  NxTest.refute(h.include?('start_operation'), 'a ziadna operacia')
  NxTest.assert(h.include?('after_change'), 'ale echo sekcie ano (zoznam sa zmenil)')
  err = ST3C2_TPL_RB[/def rename_error\(msg\).*?\n        end\n/m].to_s
  NxTest.assert(err.include?('TPL.renameError'), 'odmietnutie ide prijimacu, ktory modal NEZATVARA')
  NxTest.assert(err.include?('set_status'), 'a zaroven do stavoveho riadku (modal uz nemusi zit)')
end

NxTest.test('ŠT-3c-2: klient — ceruzka na OBOCH druhoch, modal ceka na server') do
  code = ST3C2_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  tile = code[/function tplTileHtml\(tp, kind, idx\).*?\n  \}/m].to_s
  cab = tile[/if \(isCab\)\{.*?\n    \}/m].to_s
  NxTest.assert(tile.include?('tplRename('), 'dlazdica ma ceruzku')
  NxTest.refute(cab.include?('tplRename('),
                'ceruzka je MIMO vetvy `isCab` — doskova sablona sa premenuje tiez')
  NxTest.assert(tile.index('tplRename(') < tile.index('stpldel'), 'ceruzka stoji pred kosom')

  ren = code[/function tplRename\(kind, name\).*?\n  \}/m].to_s
  NxTest.assert(ren.include?("key: 'name'"), 'modal ma JEDINE pole')
  NxTest.assert(ren.include?('value: name'), 'predvyplnene SUCASNYM menom')
  NxTest.assert(ren.include?('new_name:'), 'na server ide pod `new_name`')
  NxTest.refute(ren.include?('NXModal.close()'),
                'modal sa po odoslani NEZATVARA — o vysledku rozhoduje server')
  NxTest.assert(code.include?('renameSaved: function()'), 'prijimac potvrdenia')
  NxTest.assert(code.include?('renameError: function(msg, field)'), 'aj odmietnutia')
  saved = code[/renameSaved: function\(\).*?\n    \},/m].to_s
  NxTest.assert(saved.include?('setBusy(false, { clear: true })'), 'potvrdenie odomkne a zabudne rozpis')
  NxTest.assert(saved.include?('m.close()'), 'a zavrie')
  errj = code[/renameError: function\(msg, field\).*?\n    \}/m].to_s
  NxTest.assert(errj.include?('setBusy(false)'),
                'odmietnutie ODOMKNE — inak by „Premenovať" ostalo navzdy zosednute')
  NxTest.assert(errj.include?('showErrors'), 'a chyba sedi pri poli')
  NxTest.refute(errj.include?('close()'), 'modal OSTAVA otvoreny s rozpisanym menom')
end

NxTest.test('ŠT-3c-2: vynimka pod zamkom vracia :failed, NIE `false` (B3)') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  store = Noxun::Engine::TemplateStore
  store.reload!
  st3c2_cleanup('ST3C2 I', 'ST3C2 I2')
  st3c2_seed('ST3C2 I')
  # `with_lock` vynimku POHLTI a vrati `false` (praca sa nesmie zrutit) — keby
  # `rename` vracalo jeho navrat priamo, handler by dostal `false` a spadol do
  # vetvy `else`... alebo NIE, podla toho, ako je `case` napisany. Preto sa
  # navrat MAPUJE na symbol. Vynimku vyrobime zvnutra zamku.
  store.singleton_class.send(:alias_method, :st3c2_orig_refuse_write, :refuse_write)
  store.define_singleton_method(:refuse_write) { |_op| raise 'SU-TEST vynimka pod zamkom' }
  begin
    res = store.rename('cabinet', 'ST3C2 I', 'ST3C2 I2')
    NxTest.assert_equal(:failed, res, 'vysledok je SYMBOL — `false` by prepadlo cez vsetky vetvy')
  ensure
    store.singleton_class.send(:alias_method, :refuse_write, :st3c2_orig_refuse_write)
    store.singleton_class.send(:remove_method, :st3c2_orig_refuse_write)
  end
  NxTest.assert(store.find('cabinet', 'ST3C2 I2').nil?, 'a NIC sa nepremenovalo')
ensure
  st3c2_cleanup('ST3C2 I', 'ST3C2 I2') if NxTest.headless?
end

# --- review #226 (Codex P2) --------------------------------------------------

NxTest.test('ŠT-3c-2 (review #226 P2): sirota na CIELI zmizne aj ked zdroj nahlad NEMA') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 J', 'ST3C2 J2')
  st3c2_seed('ST3C2 J')                     # BEZ nahladu
  dst = e::TemplatePreviews.path_for('cabinet', 'ST3C2 J2')
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(dst))
  # Osirely PNG po davno zmazanej sablone toho mena — identita suboru je
  # odvodena od MENA, takze na cieli lezi cudzi obrazok.
  File.binwrite(dst, "\x89PNG\r\n\x1A\n".b + ('x' * 64).b)
  NxTest.assert(!e::TemplatePreviews.rev_for('cabinet', 'ST3C2 J2').nil?, 'fixture: sirota lezi na cieli')

  NxTest.assert_equal(:ok, e::TemplateStore.rename('cabinet', 'ST3C2 J', 'ST3C2 J2'))
  NxTest.assert(e::TemplatePreviews.rev_for('cabinet', 'ST3C2 J2').nil?,
                'premenovana sablona BEZ fotky NEZDEDILA cudzi obrazok')
  NxTest.refute(File.file?(dst), 'a sirota je zo suboroveho systemu prec')
ensure
  st3c2_cleanup('ST3C2 J', 'ST3C2 J2') if NxTest.headless?
end

NxTest.test('ŠT-3c-2 (review #226 P2): mazanie rozlisi „zmizla" AZ PO navrate zo zamku') do
  h = ST3C2_TPL_RB[/def handle_delete\(payload\).*?
        end
/m].to_s
  NxTest.assert(h.scan('template_gone(name)').length == 2,
                'obe cesty (pred zapisom aj PO odmietnutom zapise) maju hlasku „zmizla"')
  del = h[/unless TemplateStore\.delete.*?
          end
/m].to_s
  NxTest.assert(del.include?('template_gone(name) if TemplateStore.find(kind, name).nil?'),
                'po `false` sa este RAZ pozrieme, ci sablona vobec existuje')
  NxTest.assert(del.index('template_gone') < del.index('novšej verzie'),
                'a hlaska o novsej schéme/disku je az POSLEDNA moznost')
  gone = ST3C2_TPL_RB[/def template_gone\(name\).*?
        end
/m].to_s
  NxTest.assert(gone.include?('refresh_if_open'), 'a zoznam sa pritom obnovi')
end

NxTest.test('ŠT-3c-2 (review #226 P2): premenovanie prehodi VOLBU vkladacej karty') do
  h = ST3C2_TPL_RB[/def handle_rename\(payload\).*?
        end
/m].to_s
  NxTest.assert(h.include?('Panel.push_template_renamed(kind, old_name, new_name)'),
                'karta panela drzi sablonu MENOM — bez prehodenia by vkladala pod starou identitou')
  NxTest.assert(h.index('push_template_renamed') < h.index('after_change'),
                'prehodenie ide PRED echom, aby prestavane dlazdice vyznacili spravnu')
  sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'),
                   encoding: 'UTF-8')
  m = sync[/def push_template_renamed\(kind, old_name, new_name\).*?
        end
/m].to_s
  NxTest.assert(m.include?('NX.renameTemplate('), 'posiela sa vlastnym prijimacom panela')
  NxTest.assert(m.include?('.to_json'), 'mena su serializovane (pisane pouzivatelom)')
  bridge = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                     encoding: 'UTF-8')
  r = bridge[/renameTemplate: function\(kind, oldName, newName\)\{.*?
    \},/m].to_s
  NxTest.assert(r.include?('NXInsert.templateName(k) !== String'),
                'prehadzuje sa LEN zhodna volba (cudzia sa nedotkne)')
  NxTest.assert(r.include?('NXInsert.setTemplateName(k, newName)'), 'a nastavi sa nove meno')
end

# --- review #226 kolo 2: BEHAVIORALNE dokazy (grep uz nestaci) ---------------
#
# Kazdy test nizsie zabija KONKRETNU mutaciu, ktora predtym prezila: poradie
# zapis→PNG, hlaska o nepresunutom nahlade, `max` pri kolizii peciatky,
# overenie presunu na disku, containment cesty, obnova zoznamu pri zmiznutej
# sablone a vsetky STYRI vlastnosti, ktore `with_entries` slubuje.

# Vykona blok s docasne nahradenou modulovou metodou.
def st3c2_with_stub(mod, name, impl)
  sc = mod.singleton_class
  alias_name = :"st3c2_orig_#{name}"
  sc.send(:alias_method, alias_name, name)
  mod.define_singleton_method(name, impl)
  yield
ensure
  sc.send(:alias_method, name, alias_name)
  sc.send(:remove_method, alias_name)
end

NxTest.test('ŠT-3c-2 (kolo 2): PNG sa hybe AZ PO zapise zoznamu — zlyhany zapis ho nechá') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 K', 'ST3C2 K2')
  st3c2_seed('ST3C2 K')
  src = e::TemplatePreviews.path_for('cabinet', 'ST3C2 K')
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(src))
  File.binwrite(src, ST3C2_PNG)

  # Zapis zoznamu ZLYHA (plny disk, prava): zaznam ostava na starom mene —
  # a obrazok sa preto NESMIE pohnut. Keby sa PNG presuvalo PRED `write_list`,
  # sablona by po neuspesnom premenovani prisla o nahlad.
  res = st3c2_with_stub(e::TemplateStore, :write_list, ->(_list) { false }) do
    e::TemplateStore.rename('cabinet', 'ST3C2 K', 'ST3C2 K2')
  end
  NxTest.assert_equal(:failed, res, 'zlyhany zapis = :failed')
  NxTest.assert(!e::TemplatePreviews.rev_for('cabinet', 'ST3C2 K').nil?,
                'nahlad ostal pri POVODNEJ sablone')
  NxTest.assert(e::TemplatePreviews.rev_for('cabinet', 'ST3C2 K2').nil?,
                'a na nove meno sa NEPRESUNUL (poradie zapis -> PNG)')
ensure
  st3c2_cleanup('ST3C2 K', 'ST3C2 K2') if NxTest.headless?
end

NxTest.test('ŠT-3c-2 (kolo 2): nepresunuty nahlad sa POVIE (hlaska nie je ozdoba)') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 L', 'ST3C2 L2')
  st3c2_seed('ST3C2 L')
  src = e::TemplatePreviews.path_for('cabinet', 'ST3C2 L')
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(src))
  File.binwrite(src, ST3C2_PNG)

  # Presun PNG zlyha (subor drzi iny proces): premenovanie je AJ TAK uspesne
  # (zaznam uz nove meno ma), ale pouzivatel sa MUSI dozvediet, ze fotka
  # neprisla — inak ju bude hladat.
  got = []
  st3c2_with_stub(e::TemplatePreviews, :rename, ->(_k, _o, _n) { false }) do
    e::TemplatesDialog.dispatch('tpl_rename',
                                { 'kind' => 'cabinet', 'template' => 'ST3C2 L',
                                  'new_name' => 'ST3C2 L2' }.to_json,
                                ->(js) { got << js.to_s })
  end
  NxTest.assert(!e::TemplateStore.find('cabinet', 'ST3C2 L2').nil?, 'zaznam sa premenoval')
  NxTest.assert(got.any? { |x| x.include?('Náhľad sa nepreniesol') },
                'a status to PRIZNAL (mutacia bez hlasky tu padne)')
  NxTest.assert(got.any? { |x| x.include?('TPL.renameSaved()') }, 'modal sa zavrel')
ensure
  st3c2_cleanup('ST3C2 L', 'ST3C2 L2') if NxTest.headless?
end

NxTest.test('ŠT-3c-2 (kolo 2): zmiznuta sablona OBNOVI zoznam a modal ZAVRIE (NOTE 3)') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  got = []
  e::TemplatesDialog.dispatch('tpl_rename',
                              { 'kind' => 'cabinet', 'template' => 'ST3C2 NEEXISTUJE',
                                'new_name' => 'ST3C2 M' }.to_json,
                              ->(js) { got << js.to_s })
  NxTest.assert(got.any? { |x| x.start_with?('TPL.init(') },
                'zoznam sa OBNOVI — pouzivatel musi vidiet, co v kniznici naozaj je')
  NxTest.assert(got.any? { |x| x.include?('TPL.renameClosed()') },
                'a modal sa ZAVRIE — meno neexistujucej sablony nie je co opravovat')
  NxTest.refute(got.any? { |x| x.include?('TPL.renameSaved()') }, 'nikdy nie ako uspech')
  NxTest.assert(e::TemplateStore.find('cabinet', 'ST3C2 M').nil?, 'a nic nevzniklo')
end

NxTest.test('ŠT-3c-2 (kolo 2, NOTE 1): rovnake meno je :unchanged — a to AZ za guardmi') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 N')
  st3c2_seed('ST3C2 N')
  snap = File.binread(e::TemplateStore.path)
  NxTest.assert_equal(:unchanged, e::TemplateStore.rename('cabinet', 'ST3C2 N', 'ST3C2 N'),
                      'existujuca sablona s tym istym menom = :unchanged')
  NxTest.assert_equal(snap, File.binread(e::TemplateStore.path), 'a subor sa NEDOTKOL')
  # Skratka PRED zamkom tvrdila „hotovo" aj tam, kde sa premenovat NEDA.
  NxTest.assert_equal(:missing, e::TemplateStore.rename('cabinet', 'ST3C2 NIET', 'ST3C2 NIET'),
                      'neexistujuca sablona = :missing (nie falosne „hotovo")')
  raw = JSON.parse(File.read(e::TemplateStore.path, encoding: 'UTF-8'))
  raw['std'] = e::TemplateStore::STD + 1
  File.write(e::TemplateStore.path, JSON.pretty_generate(raw), encoding: 'UTF-8')
  e::TemplateStore.reload!
  NxTest.assert_equal(:readonly, e::TemplateStore.rename('cabinet', 'ST3C2 N', 'ST3C2 N'),
                      'a kniznica z novsej verzie = :readonly')
ensure
  if NxTest.headless?
    begin
      raw2 = JSON.parse(File.read(Noxun::Engine::TemplateStore.path, encoding: 'UTF-8'))
      raw2['std'] = Noxun::Engine::TemplateStore::STD
      File.write(Noxun::Engine::TemplateStore.path, JSON.pretty_generate(raw2), encoding: 'UTF-8')
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end
    Noxun::Engine::TemplateStore.reload!
    st3c2_cleanup('ST3C2 N')
  end
end

NxTest.test('ŠT-3c-2 (kolo 2): presun PNG sa OVERUJE na disku a cesta ma containment') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  st3c2_cleanup('ST3C2 O', 'ST3C2 O2')
  src = e::TemplatePreviews.path_for('cabinet', 'ST3C2 O')
  require 'fileutils'
  FileUtils.mkdir_p(File.dirname(src))
  File.binwrite(src, ST3C2_PNG)

  # `File.rename` „prebehne", ale na disku sa nic nestane (sietovy disk,
  # antivirus). Bez overenia by metoda vratila true a volajuci by tvrdil,
  # ze nahlad je na novom mene.
  moved = st3c2_with_stub(File, :rename, ->(_a, _b) { 0 }) do
    e::TemplatePreviews.rename('cabinet', 'ST3C2 O', 'ST3C2 O2')
  end
  NxTest.refute(moved, 'nepotvrdeny presun = false (nie „podarilo sa")')

  # CONTAINMENT: keby `slug` pustil cestu von z adresara, `path_for` musi
  # vratit nil — je to posledna poistka, nie ozdoba.
  # POZOR na oddelovac: `..\..` je uteka cesta LEN na Windows — na Linuxe (CI)
  # je spatna lomka bezny znak v mene suboru, takze by cesta z adresara vobec
  # neusla a test by NIC nedokazoval. Pouziva sa `../..`, ktora uteka VSADE.
  escaped = st3c2_with_stub(e::TemplatePreviews, :file_name, ->(_k, _n) { '../../evil.png' }) do
    e::TemplatePreviews.path_for('cabinet', 'ST3C2 O')
  end
  NxTest.assert(escaped.nil?, 'cesta mimo adresara nahladov sa NEVYDA')
ensure
  st3c2_cleanup('ST3C2 O', 'ST3C2 O2') if NxTest.headless?
end

NxTest.test('ŠT-3c-2 (kolo 2): kolizia peciatky berie NOVSIE cislo (`max`)') do
  NxTest.skip!('TemplateUsage testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  u = Noxun::Engine::TemplateUsage
  u.stamp('cabinet', 'ST3C2 P')        # STARSIA peciatka
  old_seq = u.seq_for('cabinet', 'ST3C2 P')
  u.stamp('cabinet', 'ST3C2 P2')       # NOVSIA — pod tymto menom uz peciatka JE
  new_seq = u.seq_for('cabinet', 'ST3C2 P2')
  NxTest.assert(old_seq.to_i.positive? && new_seq.to_i > old_seq.to_i, 'fixture: dve peciatky')

  u.rename('cabinet', 'ST3C2 P', 'ST3C2 P2')
  NxTest.assert_equal(new_seq, u.seq_for('cabinet', 'ST3C2 P2'),
                      'kolizia berie NOVSIE cislo — pouzitie nesmie zostarnut')
  NxTest.assert(u.seq_for('cabinet', 'ST3C2 P').nil?, 'stary kluc zanikol')
end

NxTest.test('ŠT-3c-2 (kolo 2): `with_entries` drzi VSETKY styri slubene vlastnosti') do
  NxTest.skip!('TemplateUsage testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  u = Noxun::Engine::TemplateUsage
  # 1) NEZNAMY top-level kluc (novsia verzia) musi zapis PREZIT.
  # 2) VADNE zaznamy sa sanitizuju (nula, text, prilis dlhy kluc).
  # 3) `seq` je MONOTONNY aj nad rucne zmensenym suborom.
  raw = { 'std' => Noxun::Engine::TemplateUsage::STD, 'seq' => 1,
          'entries' => { 'cabinet:ST3C2 dobra' => 7, 'cabinet:ST3C2 nula' => 0,
                         'cabinet:ST3C2 text' => 'ahoj',
                         "cabinet:#{'x' * 300}" => 3 },
          'poznamka_z_buducnosti' => { 'x' => 1 } }
  File.write(u.path, JSON.pretty_generate(raw), encoding: 'UTF-8')

  NxTest.assert(u.stamp('cabinet', 'ST3C2 Q'), 'peciatka prejde')
  data = JSON.parse(File.read(u.path, encoding: 'UTF-8'))
  NxTest.assert_equal({ 'x' => 1 }, data['poznamka_z_buducnosti'],
                      'neznamy top-level kluc PREZIL (merge extras)')
  ent = data['entries']
  NxTest.assert(!ent.key?('cabinet:ST3C2 nula'), 'nulovy zaznam sa sanitizoval')
  NxTest.assert(!ent.key?('cabinet:ST3C2 text'), 'aj textovy')
  NxTest.assert(ent.keys.none? { |k| k.length > Noxun::Engine::TemplateUsage::MAX_KEY_LENGTH },
                'aj prilis dlhy kluc')
  NxTest.assert(data['seq'].to_i > 7, '`seq` je nad NAJVYSSOU peciatkou (monotonnost)')
  NxTest.assert_equal(data['seq'].to_i, ent['cabinet:ST3C2 Q'].to_i, 'a nova peciatka ho drzi')

  # 4) PRUNE: nad stropom zaznamov vypadnu NAJSTARSIE.
  maxn = Noxun::Engine::TemplateUsage::MAX_ENTRIES
  many = {}
  (1..(maxn + 20)).each { |i| many["cabinet:ST3C2 hromada #{i}"] = i }
  File.write(u.path, JSON.pretty_generate({ 'std' => Noxun::Engine::TemplateUsage::STD,
                                            'seq' => maxn + 20, 'entries' => many }),
             encoding: 'UTF-8')
  u.stamp('cabinet', 'ST3C2 R')
  after = JSON.parse(File.read(u.path, encoding: 'UTF-8'))['entries']
  NxTest.assert(after.length <= maxn, "strop zaznamov plati (#{after.length} <= #{maxn})")
  NxTest.assert(after.key?('cabinet:ST3C2 R'), 'a cerstva peciatka v nom ostala')
  NxTest.assert(!after.key?('cabinet:ST3C2 hromada 1'), 'najstarsia vypadla')

  # `with_entries` je NAOZAJ privatny (NOTE 6) — nie len slovom v komentari.
  NxTest.assert_raise(/private method|private/) do
    u.with_entries { |_e, _s| nil }
  end
end

NxTest.test('ŠT-3c-2 (kolo 2): premenovanie BROADCASTUJE prehodenie volby PRED zoznamom') do
  NxTest.skip!('TemplateStore testy bezia len headless (testovaci %APPDATA%)') unless NxTest.headless?

  e = Noxun::Engine
  e::TemplateStore.reload!
  st3c2_cleanup('ST3C2 S', 'ST3C2 S2')
  st3c2_seed('ST3C2 S')
  sent = []
  st3c2_with_stub(e::Panel, :js, ->(script) { sent << script.to_s }) do
    e::TemplatesDialog.dispatch('tpl_rename',
                                { 'kind' => 'cabinet', 'template' => 'ST3C2 S',
                                  'new_name' => 'ST3C2 S2' }.to_json,
                                ->(_js) { nil })
  end
  ren = sent.index { |x| x.start_with?('NX.renameTemplate(') }
  lst = sent.index { |x| x.start_with?('NX.setTemplates(') }
  NxTest.assert(!ren.nil?, 'panel dostal prehodenie volby vkladacej karty')
  NxTest.assert(sent[ren].include?('"cabinet"') && sent[ren].include?('"ST3C2 S"') &&
                sent[ren].include?('"ST3C2 S2"'),
                'a nesie druh, STARE aj NOVE meno')
  NxTest.assert(!lst.nil? && ren < lst,
                'prehodenie ide PRED zoznamom — prestavane dlazdice uz vyznacia spravnu')
ensure
  st3c2_cleanup('ST3C2 S', 'ST3C2 S2') if NxTest.headless?
end
