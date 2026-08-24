# frozen_string_literal: true
# TEST-1 — nálezy z PRVÉHO testu v0.8.0 naostro (Michal, 24.8.).
#
# Co tato sada strazi (a preco to klikanim NEZISTIS, kym nie je neskoro):
#   1. ZAKLADNY ZOZNAM katalogu kovania je serverovy search s PRAZDNYM
#      dotazom a orezanim. Radi sa `score -> -use_count -> kod`, takze NOVA
#      polozka (`use_count` 0) skonci na chvoste a pri orezani ZMIZNE. Michal
#      ju po pridani nenasiel a mysleli sme si, ze sa neulozila — pritom
#      v katalogu bola. Orezanie sa preto MUSI priznat cislom.
#   2. Prave zalozena polozka musi byt VIDNO HNED. Poradie ale nadalej sklada
#      SERVER (kontrakt GH #100 P2 — JS ho nikdy nedoplna): klient posiela
#      `pin`, server ho da navrch. Keby si poradie doplnal klient, rozislo by
#      sa so serverovym a filtre by zacali klamat.
#   3. Pravidla „Uchytky" su DVE (dvierka + zasuvkove cela) a mali JEDNU
#      spolocnu vysvetlivku o „sirke kridla" — pri zasuvkach KLAMALA a obe
#      pravidla vyzerali ako duplicita, ktoru niekto zabudol zmazat.
require_relative '../helper' unless defined?(NxTest)

require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog') if NxTest.headless?

T1_HW_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'hardware_catalog_dialog.rb'),
                     encoding: 'UTF-8')
T1_HW_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hw_catalog.js'),
                     encoding: 'UTF-8')
T1_RULES_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'rules.js'),
                        encoding: 'UTF-8')

# Katalog s N polozkami; `used` urcuje, ktore maju `use_count` (a teda konciaa
# v poradi PRED novou polozkou).
def t1_items(count, new_code: nil)
  out = (1..count).map do |i|
    { 'item_code' => format('OLD%03d', i), 'name_sk' => "Polozka #{i}",
      'category' => 'ZAVES', 'unit' => 'ks', 'active' => true, 'use_count' => 100 - (i % 5) }
  end
  out << { 'item_code' => new_code, 'name_sk' => 'Uplne nova polozka', 'category' => 'ZAVES',
           'unit' => 'ks', 'active' => true, 'use_count' => 0 }
  out
end

# --- 1) SEARCH vracia CELKOVY POCET, nielen orezany zoznam -------------------

NxTest.test('TEST-1: `search_with_total` vrati aj POCET ZHOD pred orezanim') do
  hc = Noxun::Engine::HardwareCatalog
  items = t1_items(80, new_code: 'NOVA001')
  page, total = hc.search_with_total(items, '', top: 50)
  NxTest.assert_equal(50, page.length, 'orezanie plati')
  NxTest.assert_equal(81, total, 'ale POCET ZHOD je cely — inak sa oreznanie neda priznat')
  # Prave to je jadro naleza: nova polozka (use_count 0) v orezanom zozname NIE JE.
  NxTest.refute(page.any? { |i| i['item_code'] == 'NOVA001' },
                'fixture: nova polozka naozaj vypadne z prvej padesiatky (preto ju Michal nenasiel)')
  NxTest.assert_equal(hc.search(items, '', top: 50).map { |i| i['item_code'] },
                      page.map { |i| i['item_code'] },
                      '`search` sa nezmenil — vracia PRESNE to, co prva polozka dvojice')
end

NxTest.test('TEST-1: nic sa neoreze = `total` sedi s poctom vratenych') do
  hc = Noxun::Engine::HardwareCatalog
  items = t1_items(5, new_code: 'NOVA001')
  page, total = hc.search_with_total(items, '', top: 50)
  NxTest.assert_equal(6, page.length, 'vsetko sa zmestilo')
  NxTest.assert_equal(6, total, 'a total to potvrdzuje (klient vtedy hint NEVYPISUJE)')
end

# --- 2) HANDLER: vyssi strop prazdneho dotazu + total + pin ------------------

NxTest.test('TEST-1: prazdny dotaz ma VLASTNY strop a orezanie sa PRIZNAVA') do
  body = T1_HW_RB[/def handle_search\(payload\).*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('EMPTY_TOP'), 'prazdny dotaz ma vlastny (vyssi) strop')
  NxTest.assert(body.include?('SEARCH_TOP'), 'hladanie si drzi svoj')
  NxTest.assert(body.include?("query.strip.empty? && category.strip.empty?"),
                'vyssi strop plati LEN pre zoznam bez dotazu aj bez kategorie')
  NxTest.assert(body.include?('search_with_total'), 'berie sa POCET ZHOD, nie len stranka')
  NxTest.assert(body.include?("'total' => total"), 'a posiela sa klientovi')
  NxTest.assert(body.include?("'shown' => codes.length"), 'spolu s poctom vratenych')
  sd = Noxun::Engine::HardwareCatalogDialog
  NxTest.assert(sd::EMPTY_TOP > sd::SEARCH_TOP, 'strop zoznamu je VYSSI nez strop hladania')
end

NxTest.test('TEST-1: PIN dava polozku navrch — ale sklada ho SERVER') do
  body = T1_HW_RB[/def handle_search\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?("pin = pinned_code(data['pin'].to_s)"), 'pin chodi od klienta')
  NxTest.assert(body.include?('codes = ([pin] + (codes - [pin])).first(top) if pin'),
                'a NAVRCH ho zaradi SERVER (klient poradie nikdy nedoplna — GH #100 P2)')
  pinned = T1_HW_RB[/def pinned_code\(code\).*?\n        end\n/m].to_s
  NxTest.assert(pinned.include?("HardwareCatalog.items.any?"),
                'pin sa pusti LEN ked taka polozka naozaj existuje')
  NxTest.assert(pinned.include?('return nil if code.strip.empty?'), 'prazdny pin sa ignoruje')
  js = T1_HW_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.assert(js.include?('pin: MDH_PIN'), 'klient pin posiela')
  NxTest.refute(js.include?('MDH_ORDER.unshift'), 'ale poradie si NEDOPLNA sam')
end

NxTest.test('TEST-1: po zalozeni polozky ide jej KOD klientovi (obe cesty)') do
  create = T1_HW_RB[/def handle_create\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(create.include?("js(\"MDH.created(#{'#{'}info['item_code'].to_s.to_json})\")"),
                'rucne zalozenie posiela kod')
  demos = T1_HW_RB[/def handle_demos_create\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(demos.include?("js(\"MDH.demosCreated(#{'#{'}info['item_code'].to_s.to_json})\")"),
                'aj zalozenie z Demosu')
  js = T1_HW_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  NxTest.assert(js.include?('created: function(code)'), 'prijimac kod prijima')
  NxTest.assert(js.include?('demosCreated: function(code)'), 'oba prijimace')
  NxTest.assert(js.include?('MDH.created(code)'), 'a demos ho posuva dalej')
end

# --- 3) PRAVIDLA: hint per rola ---------------------------------------------

NxTest.test('TEST-1: „Úchytky" maju hint PER ROLU — pri zasuvkach uz neklame') do
  js = T1_RULES_JS.lines.reject { |l| l.strip.start_with?('//') }.join
  fn = js[/function rdHandleHint\(role\).*?\n  \}/m].to_s
  NxTest.refute(fn.empty?, 'hint je vlastna (testovatelna) funkcia')
  NxTest.assert(fn.include?("role === 'drawer_front'"), 'rozlisuje zasuvkove celo')
  NxTest.assert(fn.include?('šírka čela'), 'a hovori o SIRKE CELA')
  NxTest.assert(fn.include?('šírka krídla'), 'kym dvierka ostavaju pri sirke kridla')
  branch = js[/if \(r\.kind === 'part_flag_length'\)\{.*?\n      \}/m].to_s
  NxTest.assert(branch.include?('rdHandleHint((r.applies_to || {}).role)'),
                'vetva pravidla berie rolu z `applies_to`')
  NxTest.refute(branch.include?('dĺžka rezu = šírka krídla. Vypnutím'),
                'stary spolocny text (klamlivy pri zasuvkach) je PREC')
end
