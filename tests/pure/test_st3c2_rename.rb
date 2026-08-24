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

ST3C2_TPL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'),
                         encoding: 'UTF-8')
ST3C2_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'templates.js'),
                     encoding: 'UTF-8')
ST3C2_CORE_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'templates.rb'),
                          encoding: 'UTF-8')

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
  NxTest.assert_equal(:ok, e::TemplateStore.rename('cabinet', 'ST3C2 C', 'ST3C2 C'),
                      'rovnake meno je :ok bez zapisu')
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
