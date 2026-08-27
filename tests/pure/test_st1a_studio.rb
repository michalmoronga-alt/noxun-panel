# frozen_string_literal: true
# ST-1a PR B — okno ŠTÚDIO (skelet + sekcia Kusovník) a SERVEROVY nazov projektu.
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. SEKCIE su whitelist v RUBY a JS je jeho zrkadlo. Keby sa rozisli, panel by
#      posielal meno, ktore okno nepozna — deep-link by skoncil ticho.
#   2. Deep-link sa spotrebuje PRAVE RAZ. Bez toho by kazdy refresh vratil
#      pouzivatela do sekcie, z ktorej medzitym odisiel (lekcia `@pending_tab`).
#   3. NAZOV PROJEKTU je od tejto davky SERVEROVY (audit #1). Dokial ho posielal
#      DOM, mali by dve okna dve pravdy — VEPO z jedneho a rozpocet z druheho by
#      pomenovali TU ISTU zakazku inak. Test preto vyzaduje, aby vsetky STYRI
#      exporty citali `project_name(model)` a aby JS `project:` uz neposielal.
#   4. `materials_meta` je kontrakt Š1 — bez neho by klient musel skladat nazov
#      dekoru sam a mal by druhu pravdu o tom, ako sa material vola.
#   5. Premostenia navigacie su uzavrety zoznam v Ruby. Klient posiela iba kluc;
#      keby o cieli rozhodoval on, dalo by sa z okna otvorit cokolvek.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva). Parse-time
# tu ziadne SketchUp API nie je — vsetko je vnutri metod.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') if NxTest.headless?

ST1B_STUDIO_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                           encoding: 'UTF-8')
ST1B_CORE_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                           encoding: 'UTF-8')
ST1B_PANEL_RB  = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
ST1B_MAIN_RB   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
ST1B_STUDIO_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'),
                           encoding: 'UTF-8')
ST1B_BUDGET_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'budget.js'),
                           encoding: 'UTF-8')
ST1B_BRIDGE_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'),
                           encoding: 'UTF-8')
ST1B_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

# --- 1) whitelist sekcii + zrkadlo -------------------------------------------

NxTest.test('ST-1a: SECTIONS je whitelist v RUBY a JS je jeho ZRKADLO') do
  rb = ST1B_STUDIO_RB[/SECTIONS = %w\[([a-z ]+)\]/, 1].to_s.split
  js = ST1B_STUDIO_JS[/var STUDIO_SECTIONS = \[(.*?)\];/m, 1].to_s.scan(/'([a-z]+)'/).flatten
  # ŠT-1b pridala sekciu Kontrola (`ctrl`) — dovtedy premostenie do okna Vyroba.
  # ŠT-1c PR A pridala Nakup kovania (`buy`) — presun tabu Kovanie 1:1 (Š7).
  # ŠT-1c PR B1 pridala Rozpocet (`budget`) — POSLEDNY tab okna Vyroba.
  NxTest.assert_equal(%w[bom ctrl buy budget offer mat hw rules tpl sup bset about], rb,
                      'v Studiu ziju sekcie Kusovník, Kontrola, Nákup, Rozpočet, Ponuka, Materiály, Kovanie, Pravidlá a Šablóny')
  NxTest.assert_equal(rb, js, 'JS zoznam sekcii sa nesmie rozist s Ruby autoritou')
  NxTest.assert_equal(rb, Noxun::Engine::StudioDialog::SECTIONS,
                      'konstanta a zdrojak hovoria to iste')
end

NxTest.test('ST-1a: deep-link sekcie sa spotrebuje PRAVE RAZ') do
  body = ST1B_STUDIO_RB[/def consume_pending_section.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'spotreba ma vlastnu funkciu')
  NxTest.assert(body.include?('@pending_section = nil'),
                'bez vynulovania by kazdy refresh vratil pouzivatela do starej sekcie')
  NxTest.assert(body.include?('SECTIONS.include?'), 'aj pri spotrebe plati whitelist')
  anchor = ST1B_STUDIO_RB[/def consume_pending_anchor.*?\n        end\n/m].to_s
  NxTest.assert(anchor.include?('@pending_anchor = nil'),
                'kotva hladania sa spotrebuje rovnako — inak by sa filter vracal po kazdom pushi')
  NxTest.assert(ST1B_STUDIO_RB.include?('open_section: consume_pending_section'),
                'sekcia cestuje v tom istom pushi ako data (okno po `show` este nemusi mat HTML)')
  NxTest.assert(ST1B_STUDIO_RB.include?('anchor: consume_pending_anchor'),
                'a kotva s nou')
end

NxTest.test('ST-1a: kotva sa posiela LEN so sekciou (inak nema kam sadnut)') do
  body = ST1B_STUDIO_RB[/def show\(open_section:.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'show sa nasiel')
  NxTest.assert(body.include?('@pending_anchor = @pending_section ? anchor.to_s.strip : nil'),
                'bez platnej sekcie sa kotva zahadzuje')
end

# --- 2) nazov projektu je SERVEROVY (audit #1) -------------------------------

NxTest.test('ST-1a: nazov projektu zije v ProductionCore (mapa project_names)') do
  core = Noxun::Engine::ProductionCore
  %i[project_names project_name save_project_name merge_18_36 save_merge_18_36
     project_key project_session_key normalize_project_path
     session_keys_for remembered_session_key adopt_session_name].each do |m|
    NxTest.assert(core.respond_to?(m), "ProductionCore neodpoveda na #{m}")
  end
  NxTest.assert_equal('project_names', Noxun::Engine::ProductionCore::PROJECT_NAMES_KEY,
                      'kluc mapy je sucastou kontraktu suboru vepo_settings.json')
end

NxTest.test('ST-1a (review P1): klucom je CESTA, nie model.guid — guid sa meni pri ulozeni') do
  # SketchUp dokumentuje, ze `Model#guid` sa MENI po kazdom ulozeni. Na guid
  # kluci by sa nazov po Ctrl+S ticho stratil a v subore by rastli mrtve
  # zaznamy. Tento test simuluje presne to: medzi zapisom a citanim sa guid
  # zmeni, cesta ostane — a nazov MUSI prezit.
  core = Noxun::Engine::ProductionCore
  m1 = Struct.new(:path, :guid).new('C:/Zakazky/KLINIKA_v7.skp', 'GUID-PRED-ULOZENIM')
  m2 = Struct.new(:path, :guid).new('C:/Zakazky/KLINIKA_v7.skp', 'GUID-PO-ULOZENI')
  begin
    core.save_project_name(m1, 'Klinika Bratislava')
    NxTest.assert_equal('Klinika Bratislava', core.project_name(m2),
                        'zmena guid (ulozenie modelu) nesmie nazov zahodit')
    # Kluc je normalizovany — Windows nerozlisuje velkost pismen ani lomitka.
    m3 = Struct.new(:path, :guid).new('c:\\zakazky\\KLINIKA_v7.skp', 'GUID-INY')
    NxTest.assert_equal('Klinika Bratislava', core.project_name(m3),
                        'ta ista cesta inak zapisana = ten isty zaznam')
    NxTest.assert_equal('c:/zakazky/klinika_v7.skp', core.project_key(m3),
                        'kluc je normalizovana cesta')
  ensure
    core.save_project_name(m1, '')
  end
end

NxTest.test('1b-6a: Ctrl+S meni CESTU aj GUID — nazov zadany pred ulozenim to musi prezit') do
  # VYROBNA P2: pomenuj zakazku v Studiu, kym model este nie je ulozeny, potom
  # Ctrl+S. SketchUp pri ulozeni NARAZ prida cestu a ZMENI guid, takze zaznam
  # ostal viset pod klucom `guid:<STARY guid>` a vsetky styri exporty sa
  # pomenovali podla .skp suboru namiesto zakazky.
  #
  # Simulacia musi menit TEN ISTY objekt modelu (SketchUp iny nevytvara) —
  # dva samostatne Structy s rovnakym guid, ktore tu stali do 1b-6a, chybu
  # MASKOVALI, lebo zmenu guid vobec nepredviedli.
  core = Noxun::Engine::ProductionCore
  m = Struct.new(:path, :guid).new('', 'GUID-UNTITLED')
  begin
    NxTest.assert_equal('guid:GUID-UNTITLED', core.project_key(m),
                        'neulozeny model ma kluc sedenia (plati len dovtedy, kym sa neulozi)')
    core.save_project_name(m, 'Rozrobena zakazka')
    NxTest.assert_equal('Rozrobena zakazka', core.project_name(m))
    # Ctrl+S na TOM ISTOM modeli: pribudla cesta a guid je INY.
    m.path = 'C:/Zakazky/Nova.skp'
    m.guid = 'GUID-PO-ULOZENI'
    NxTest.assert_equal('Rozrobena zakazka', core.project_name(m),
                        'zmena guid pri prvom ulozeni nesmie nazov zakazky zahodit')
    map = core.project_names
    NxTest.assert(map.key?('c:/zakazky/nova.skp'),
                  'citanie zaznam ZMIGROVALO na cestu (inak by zil len do konca sedenia)')
    NxTest.refute(map.key?('guid:GUID-UNTITLED'),
                  'guid zaznam po migracii zanikol — inak by v subore rastli mrtve kluce')
  ensure
    core.save_project_name(m, '')
    core.update_project_names do |map|
      %w[guid:GUID-UNTITLED guid:GUID-PO-ULOZENI].each { |k| map.delete(k) }
      map
    end
  end
end

NxTest.test('1b-6a: zmigrovany nazov drzi aj po RESTARTE (nie len v pamati sedenia)') do
  # Most neulozeny→ulozeny zije v pamati procesu. Keby migracia nezapisala
  # zaznam na cestu, po restarte SketchUpu (= novy objekt modelu, prazdna
  # pamat) by sa nazov aj tak stratil. Test preto cita CUDZIM objektom.
  core = Noxun::Engine::ProductionCore
  m = Struct.new(:path, :guid).new('', 'GUID-RESTART')
  begin
    core.save_project_name(m, 'Klinika Ruzinov')
    m.path = 'C:/Zakazky/Restart.skp'
    m.guid = 'GUID-RESTART-2'
    core.project_name(m) # prve citanie po ulozeni = migracia na cestu
    po_restarte = Struct.new(:path, :guid).new('C:/Zakazky/Restart.skp', 'GUID-INY-BEH')
    NxTest.assert_equal('Klinika Ruzinov', core.project_name(po_restarte),
                        'zaznam prezil v subore, nie len v pamati sedenia')
  ensure
    core.save_project_name(m, '')
    core.update_project_names do |map|
      %w[guid:GUID-RESTART guid:GUID-RESTART-2].each { |k| map.delete(k) }
      map
    end
  end
end

NxTest.test('1b-6a: rozrobeny nazov NEZDEDI cudzia zakazka (most plati len pre ten isty model)') do
  # Most je viazany na IDENTITU objektu modelu. Keby sa adoptoval „posledny
  # rozrobeny nazov", staci otvorit iny subor a jeho vyrobne vystupy by sa
  # volali podla cudzej zakazky.
  core = Noxun::Engine::ProductionCore
  rozrobena = Struct.new(:path, :guid).new('', 'GUID-ROZROBENA')
  cudzia = Struct.new(:path, :guid).new('C:/Zakazky/Ine.skp', 'GUID-CUDZIA')
  begin
    core.save_project_name(rozrobena, 'Zakazka A')
    NxTest.assert_equal('Ine', core.project_name(cudzia),
                        'iny dokument dostane nazov zo svojho suboru, nie rozrobeny nazov')
    NxTest.assert_equal('Zakazka A', core.project_name(rozrobena),
                        'a rozrobenej zakazke sa nazov citanim inej nestratil')
  ensure
    core.save_project_name(rozrobena, '')
    core.update_project_names do |map|
      map.delete('guid:GUID-ROZROBENA')
      map
    end
  end
end

NxTest.test('1b-6a (review #243 P2-1): zlyhany zapis migracie NESMIE zahodit most') do
  # Zamknuty subor / plny disk: `save_vepo_settings` pad len zaloguje. Keby sa
  # most spotreboval aj tak, nazov by dal spravne LEN toto jedno citanie a
  # najblizsi export by uz zase pisal meno .skp suboru.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  store = Noxun::Engine::JsonFileStore
  m = Struct.new(:path, :guid).new('', 'GUID-ZAMKNUTY')
  begin
    core.save_project_name(m, 'Zamknuta zakazka')
    m.path = 'C:/Zakazky/Zamknuta.skp'
    m.guid = 'GUID-ZAMKNUTY-2'
    orig = store.method(:write)
    begin
      store.define_singleton_method(:write) { |*_a| raise IOError, 'disk full (test)' }
      NxTest.assert_equal('Zamknuta zakazka', core.project_name(m),
                          'aj pri zlyhanom zapise dava citanie spravny nazov')
    ensure
      store.define_singleton_method(:write, orig)
    end
    NxTest.assert_equal('Zamknuta zakazka', core.project_name(m),
                        'most prezil, takze migracia sa zopakuje hned ako zapis prejde')
    NxTest.assert(core.project_names.key?('c:/zakazky/zamknuta.skp'),
                  'a zaznam uz sedi na ceste')
  ensure
    core.save_project_name(m, '')
    core.update_project_names do |map|
      %w[guid:GUID-ZAMKNUTY guid:GUID-ZAMKNUTY-2].each { |k| map.delete(k) }
      map
    end
  end
end

NxTest.test('1b-6a (review #243 P2-2): nazov na ceste ma PREDNOST a most sa aj tak spotrebuje') do
  # Ulozenie do suboru, ktory uz svoj nazov ma (napr. prepis starej zakazky):
  # rozrobeny nazov ho NESMIE prepisat — ale kluc sedenia musi zaniknut, inak
  # by sa ten nazov o par minut vynoril pri „Ulozit ako" na cerstvej ceste.
  core = Noxun::Engine::ProductionCore
  stara = Struct.new(:path, :guid).new('C:/Zakazky/Stara.skp', 'GUID-STARA')
  m = Struct.new(:path, :guid).new('', 'GUID-ROZROBENA-2')
  begin
    core.save_project_name(stara, 'Stara zakazka')
    core.save_project_name(m, 'Rozrobena zakazka')
    m.path = 'C:/Zakazky/Stara.skp'
    m.guid = 'GUID-ROZROBENA-3'
    NxTest.assert_equal('Stara zakazka', core.project_name(m),
                        'zaznam na ceste sa rozrobenym nazvom neprepisuje')
    NxTest.refute(core.project_names.key?('guid:GUID-ROZROBENA-2'),
                  'kluc sedenia sa spotreboval aj ked sa nic neadoptovalo')
    # „Ulozit ako" na cerstvu cestu: rozrobeny nazov uz nesmie nikde ozit.
    m.path = 'C:/Zakazky/Cerstva.skp'
    m.guid = 'GUID-ROZROBENA-4'
    NxTest.assert_equal('Cerstva', core.project_name(m),
                        'cerstva cesta dostane nazov zo suboru, nie stary rozrobeny nazov')
  ensure
    core.save_project_name(stara, '')
    core.save_project_name(m, '')
    core.update_project_names do |map|
      %w[guid:GUID-ROZROBENA-2 guid:GUID-ROZROBENA-3 guid:GUID-ROZROBENA-4
         c:/zakazky/stara.skp c:/zakazky/cerstva.skp].each { |k| map.delete(k) }
      map
    end
  end
end

NxTest.test('1b-6a: prepis nazvu PO ulozeni zmaze aj zaznam spred ulozenia') do
  # Zapisova cesta musi upratat to iste, co citacia — inak by po prvom
  # premenovani ulozenej zakazky ostal v subore mrtvy guid kluc.
  core = Noxun::Engine::ProductionCore
  m = Struct.new(:path, :guid).new('', 'GUID-PREPIS')
  begin
    core.save_project_name(m, 'Prve meno')
    m.path = 'C:/Zakazky/Prepis.skp'
    m.guid = 'GUID-PREPIS-2'
    NxTest.assert_equal('Druhe meno', core.save_project_name(m, 'Druhe meno'))
    map = core.project_names
    NxTest.assert_equal('Druhe meno', map['c:/zakazky/prepis.skp'], 'zaznam sadol na cestu')
    NxTest.refute(map.key?('guid:GUID-PREPIS'), 'kluc spred ulozenia zanikol')
  ensure
    core.save_project_name(m, '')
    core.update_project_names do |map|
      %w[guid:GUID-PREPIS guid:GUID-PREPIS-2].each { |k| map.delete(k) }
      map
    end
  end
end

NxTest.test('ST-1a: nazov projektu je nastavenie POCITACA — nikdy sa nezapisuje do modelu') do
  body = ST1B_CORE_RB[/def save_project_name.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'zapis ma vlastnu funkciu')
  # 1b-6c: zapis ide cez `update_project_names` (zamok + cerstva mapa), ktore
  # pod kapotou vola zapisove dvere — cielom je stale %APPDATA%, nie .skp.
  NxTest.assert(body.include?('update_project_names'),
                'zapisuje sa cez zamknutu upravu mapy nazvov, nie do modelu')
  door = ST1B_CORE_RB[/def update_vepo_settings.*?\n      end\n/m].to_s
  NxTest.assert(door.include?('JsonFileStore.write(vepo_settings_path'),
                'zapisuje sa do %APPDATA% (vepo_settings.json), nie do .skp')
  NxTest.refute(body.include?('start_operation'), 'ziadna operacia = ziadny krok Spat')
  NxTest.refute(body.include?('Store.'), 'ziadny zapis do NOXUN dictionary modelu')
end

# --- 1b-6c: vepo_settings.json pod JEDNYM medziprocesovym zamkom -------------
#
# Dve instancie SketchUpu zdielaju jeden %APPDATA%. Kym sa subor menil
# read-modify-write nad odtlackom, vedel zapis jednej instancie zmazat zaznam,
# ktory prave zapisala druha — pri mape nazvov islo o CELU zakazku.

# Zapis „druhej instancie": pise do suboru PRIAMO — iny proces nase dvere
# nepozna a v teste by ich volanie zvnutra podstrceneho zamku islo do rekurzie.
# Pouziva sa presne MEDZI nasim citanim a nasim zapisom.
ST1B_OTHER_INSTANCE = lambda do |key, name|
  core = Noxun::Engine::ProductionCore
  store = Noxun::Engine::JsonFileStore
  store.reload!(core.vepo_settings_path)
  data = core.vepo_settings
  names = data[Noxun::Engine::ProductionCore::PROJECT_NAMES_KEY]
  names = names.is_a?(Hash) ? names.dup : {}
  names[key] = name
  store.write(core.vepo_settings_path,
              data.merge(Noxun::Engine::ProductionCore::PROJECT_NAMES_KEY => names))
end

# Upratanie testovacieho kluca zo suboru nastaveni (mimo mapy nazvov).
ST1B_FORGET_SETTING = lambda do |*keys|
  core = Noxun::Engine::ProductionCore
  store = Noxun::Engine::JsonFileStore
  store.reload!(core.vepo_settings_path)
  data = core.vepo_settings.dup
  keys.each { |k| data.delete(k) }
  store.write(core.vepo_settings_path, data)
end

NxTest.test('1b-6c: KAZDY zapisovatel suboru berie zamok a cita NANOVO') do
  # Statiky guard: keby si `save_merge_18_36` alebo niektory zapis `last_dir`
  # sahal na `JsonFileStore.write` sam, zamok by chranil len mapu nazvov a
  # subeh by zmigrovany nazov aj tak stratil (kolo 3 #243).
  door = ST1B_CORE_RB[/def update_vepo_settings.*?\n      end\n/m].to_s
  NxTest.assert(door.include?('Materials.with_catalog_lock'),
                'zapisove dvere berú medziprocesovy zamok')
  NxTest.assert(door.include?('JsonFileStore.reload!'),
                'a citaju subor NANOVO — sekundova cache by zapis druhej instancie skryla')
  NxTest.assert(door.include?('rescue StandardError'),
                'cela zamknuta uprava je v rescue — zlyhanie .lock nesmie uniknut ako vynimka')
  writes = ST1B_CORE_RB.scan(/JsonFileStore\.write\(vepo_settings_path/).length
  NxTest.assert_equal(1, writes, 'do suboru nastaveni zapisuje JEDINE miesto')
end

NxTest.test('1b-6c: mapu nazvov cez save_vepo_settings zapisat NEDA (obchadzka zamku)') do
  # Zamok chrani len top-level zlucenie: odovzdany ODTLACOK mapy by cerstvu
  # mapu prepisal cely a strata nazvov by sa vratila spolocnymi dverami.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  key = 'c:/zakazky/obchadzka.skp'
  begin
    core.update_project_names { |map| map.merge(key => 'Zakazka v subore') }
    NxTest.refute(core.save_vepo_settings(core::PROJECT_NAMES_KEY => {}),
                  'zapis mapy tadeto je odmietnuty')
    NxTest.assert_equal('Zakazka v subore', core.project_names[key],
                        'a mapa v subore ostala nedotknuta')
  ensure
    core.update_project_names do |map|
      map.delete(key)
      map
    end
  end
end

NxTest.test('1b-6c: zapis last_dir NEZMAZE nazov, ktory medzitym zapisala druha instancia') do
  # Klasicky subeh: druha instancia si po nasom citani pomenuje zakazku a my
  # zapiseme `last_dir` — bez zamku a cerstveho citania by sme jej zaznam
  # prepisali nasim odtlackom.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  mats = Noxun::Engine::Materials
  key = 'c:/zakazky/druha-lastdir.skp'
  orig = mats.method(:with_catalog_lock)
  begin
    mats.define_singleton_method(:with_catalog_lock) do |&blk|
      # „Druha instancia" stihne zapisat PRESNE medzi nasim citanim a zapisom.
      ST1B_OTHER_INSTANCE.call(key, 'Druha instancia')
      orig.call(&blk)
    end
    NxTest.assert(core.save_vepo_settings('last_dir' => 'C:/Export'), 'nas zapis presiel')
  ensure
    mats.define_singleton_method(:with_catalog_lock, orig)
  end
  NxTest.assert_equal('Druha instancia', core.project_names[key],
                      'zaznam druhej instancie nas zapis last_dir prezil')
  NxTest.assert_equal('C:/Export', core.vepo_settings['last_dir'], 'a nas kluc sadol')
ensure
  core.update_project_names do |map|
    map.delete(key)
    map
  end
  ST1B_FORGET_SETTING.call('last_dir')
end

NxTest.test('1b-6c: prepinac 18/36 nezmaze zaznam druhej instancie') do
  # Druhy zapisovatel toho isteho suboru — rovnaka pasca ako pri `last_dir`.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  mats = Noxun::Engine::Materials
  key = 'c:/zakazky/druha-merge.skp'
  orig = mats.method(:with_catalog_lock)
  begin
    mats.define_singleton_method(:with_catalog_lock) do |&blk|
      ST1B_OTHER_INSTANCE.call(key, 'Druha instancia')
      orig.call(&blk)
    end
    NxTest.refute(core.save_merge_18_36(false), 'prepinac sa zapisal')
  ensure
    mats.define_singleton_method(:with_catalog_lock, orig)
  end
  NxTest.assert_equal('Druha instancia', core.project_names[key],
                      'zaznam druhej instancie prezil aj zapis prepinaca')
ensure
  core.save_merge_18_36(true)
  core.update_project_names do |map|
    map.delete(key)
    map
  end
end

NxTest.test('1b-6c: migracia nazvu nezmaze zakazku pomenovanu v druhej instancii') do
  # To iste nad MAPOU: keby migracia zapisovala odtlacok z citania, prepisala
  # by cely `project_names` a zakazka z druheho okna by zmizla.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  mats = Noxun::Engine::Materials
  m = Struct.new(:path, :guid).new('', 'GUID-SUBEH')
  orig = mats.method(:with_catalog_lock)
  begin
    core.save_project_name(m, 'Nasa zakazka')
    m.path = 'C:/Zakazky/Nasa.skp'
    m.guid = 'GUID-SUBEH-2'
    mats.define_singleton_method(:with_catalog_lock) do |&blk|
      ST1B_OTHER_INSTANCE.call('c:/zakazky/druha.skp', 'Druha instancia')
      orig.call(&blk)
    end
    NxTest.assert_equal('Nasa zakazka', core.project_name(m), 'nasa migracia prebehla')
  ensure
    mats.define_singleton_method(:with_catalog_lock, orig)
  end
  map = core.project_names
  NxTest.assert_equal('Druha instancia', map['c:/zakazky/druha.skp'],
                      'zaznam druhej instancie migraciu prezil')
  NxTest.assert_equal('Nasa zakazka', map['c:/zakazky/nasa.skp'], 'a nas sadol na cestu')
ensure
  core.update_project_names do |map|
    %w[guid:GUID-SUBEH guid:GUID-SUBEH-2 c:/zakazky/druha.skp c:/zakazky/nasa.skp]
      .each { |k| map.delete(k) }
    map
  end
end

NxTest.test('1b-6c: zamknuta migracia vrati CERSTVU hodnotu cesty (kolo 3 #243)') do
  # Cesta uz svoj nazov MA a druha instancia ho PREMENUJE tesne po nasom
  # predzamkovom citani. Migracia jej nazov spravne zachova — ale keby
  # `project_name` cital dalej zo stareho odtlacku, export by odisiel pod
  # nazvom, ktory uz v subore nikto nema.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  mats = Noxun::Engine::Materials
  cesta = 'c:/zakazky/cerstva-hodnota.skp'
  m = Struct.new(:path, :guid).new('', 'GUID-CERSTVA')
  orig = mats.method(:with_catalog_lock)
  begin
    core.save_project_name(m, 'Rozrobena')
    core.update_project_names { |map| map.merge(cesta => 'Stary nazov') }
    m.path = 'C:/Zakazky/Cerstva-hodnota.skp'
    m.guid = 'GUID-CERSTVA-2'
    mats.define_singleton_method(:with_catalog_lock) do |&blk|
      ST1B_OTHER_INSTANCE.call(cesta, 'Premenovane v druhej instancii')
      orig.call(&blk)
    end
    NxTest.assert_equal('Premenovane v druhej instancii', core.project_name(m),
                        'citanie vratilo hodnotu spod zamku, nie odtlacok spred neho')
  ensure
    mats.define_singleton_method(:with_catalog_lock, orig)
  end
  NxTest.assert_equal('Premenovane v druhej instancii', core.project_names[cesta],
                      'a migracia cudzi nazov neprepisala rozrobenym')
ensure
  core.update_project_names do |map|
    %W[guid:GUID-CERSTVA guid:GUID-CERSTVA-2 #{cesta}].each { |k| map.delete(k) }
    map
  end
end

NxTest.test('1b-6c: zlyhanie zamku je len FALSE — a export dostane spravny nazov') do
  # `.lock` sa neda otvorit (prava profilu, I/O). Vynimka by vyletela do okna
  # aj do exportu; a keby sa nazov pocital az pod zamkom, prve citanie po
  # ulozeni by vratilo meno .skp suboru namiesto zakazky (audit 1b-6c #2).
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  mats = Noxun::Engine::Materials
  m = Struct.new(:path, :guid).new('', 'GUID-BEZ-ZAMKU')
  orig = mats.method(:with_catalog_lock)
  begin
    core.save_project_name(m, 'Zakazka bez zamku')
    m.path = 'C:/Zakazky/BezZamku.skp'
    m.guid = 'GUID-BEZ-ZAMKU-2'
    mats.define_singleton_method(:with_catalog_lock) do |&_blk|
      raise Errno::EACCES, 'materials.lock (test)'
    end
    NxTest.refute(core.save_vepo_settings('last_dir' => 'C:/Nezapise'),
                  'zapis pri nedostupnom zamku vracia FALSE, nevyhadzuje')
    NxTest.assert_equal('Zakazka bez zamku', core.project_name(m),
                        'citanie aj tak dava spravny nazov (fallback spred zamku)')
  ensure
    mats.define_singleton_method(:with_catalog_lock, orig)
  end
  NxTest.assert_equal('Zakazka bez zamku', core.project_name(m),
                      'most prezil, takze migracia sa zopakuje hned ako zamok pojde')
ensure
  core.save_project_name(m, '')
  core.update_project_names do |map|
    %w[guid:GUID-BEZ-ZAMKU guid:GUID-BEZ-ZAMKU-2 c:/zakazky/bezzamku.skp]
      .each { |k| map.delete(k) }
    map
  end
end

NxTest.test('1b-6c: NEPRECITATELNY subor nastavenia NEPREPISE (audit #1)') do
  # Lenive `{}` z chybneho citania by sa zlucilo s novymi `attrs` a zapis by
  # zmazal `project_names`, `merge_18_36` aj `last_dir` — teda presne to, co
  # ma zamok chranit. Chybne citanie preto zastavi zapis.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  store = Noxun::Engine::JsonFileStore
  key = 'c:/zakazky/poskodeny.skp'
  begin
    core.update_project_names { |map| map.merge(key => 'Zakazka pred poskodenim') }
    orig_read = store.method(:read)
    orig_write = store.method(:write)
    writes = 0
    begin
      store.define_singleton_method(:read) { |*_a, **_k| raise IOError, 'poskodeny subor (test)' }
      store.define_singleton_method(:write) { |*a| writes += 1; orig_write.call(*a) }
      NxTest.refute(core.save_vepo_settings('last_dir' => 'C:/Export'),
                    'zapis nad neprecitatelnym suborom sa NEUDEJE')
      # Nie-Hash obsah (platny JSON, zly tvar) je rovnaka pasca.
      store.define_singleton_method(:read) { |*_a, **_k| [] }
      NxTest.refute(core.save_vepo_settings('last_dir' => 'C:/Export'),
                    'ani nad obsahom, ktory nie je objekt')
      NxTest.assert_equal(0, writes, 'do suboru sa nezapisalo NIC')
    ensure
      store.define_singleton_method(:read, orig_read)
      store.define_singleton_method(:write, orig_write)
    end
    NxTest.assert_equal('Zakazka pred poskodenim', core.project_names[key],
                        'povodny obsah suboru ostal cely')
  ensure
    core.update_project_names do |map|
      map.delete(key)
      map
    end
  end
end

NxTest.test('1b-6c: zamok blokuje DRUHY PROCES (nie len monkeypatch)') do
  # Jediny sposob, ako na Windows overit, ze `flock` naozaj serializuje dve
  # instancie: druhy OS proces si vezme ten isty sidecar `.lock`, drzi ho a az
  # POTOM zapise. Nas zapis musi pockat a jeho zaznam precitat.
  NxTest.skip!('vyzaduje headless sandbox nastaveni') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore
  dir = Noxun::Engine::Materials.dir
  FileUtils.mkdir_p(dir)
  ready = File.join(dir, 'druhy_proces.ready')
  FileUtils.rm_f(ready)
  script = <<~RUBY
    require 'json'
    dir, ready = ARGV
    path = File.join(dir, 'vepo_settings.json')
    File.open(File.join(dir, 'materials.lock'), 'a') do |f|
      f.flock(File::LOCK_EX)
      data = File.exist?(path) ? JSON.parse(File.binread(path)) : {}
      File.binwrite(ready, 'ok')
      sleep 1.2 # kriticka sekcia druhej instancie
      data['druhy_proces'] = 'X'
      tmp = path + '.tmp-child'
      File.binwrite(tmp, JSON.pretty_generate(data))
      File.rename(tmp, path)
      f.flock(File::LOCK_UN)
    end
  RUBY
  pid = Process.spawn(RbConfig.ruby, '-e', script, dir, ready)
  begin
    deadline = Time.now + 15
    sleep 0.05 until File.exist?(ready) || Time.now > deadline
    NxTest.assert(File.exist?(ready), 'druhy proces zamok drzi')
    NxTest.assert(core.save_vepo_settings('last_dir' => 'C:/Po-zamku'), 'nas zapis presiel')
  ensure
    Process.waitpid(pid)
    FileUtils.rm_f(ready)
  end
  settings = core.vepo_settings
  NxTest.assert_equal('X', settings['druhy_proces'],
                      'nas zapis pockal na druhy proces a jeho zaznam nechal zit')
  NxTest.assert_equal('C:/Po-zamku', settings['last_dir'], 'a nas kluc sadol')
ensure
  ST1B_FORGET_SETTING.call('druhy_proces', 'last_dir')
end

NxTest.test('ST-1a: model bez akejkolvek identity dostane DEFAULT (nema sa kam zapisat)') do
  core = Noxun::Engine::ProductionCore
  # Ani cesta, ani guid = neexistuje stabilny kluc. Vymyslat ho by znamenalo,
  # ze si dva rozne dokumenty prepisu ten isty zaznam.
  empty = Struct.new(:path, :guid).new('', '')
  NxTest.assert_equal('', core.project_key(empty), 'bez cesty aj bez guid nie je kluc')
  NxTest.assert_equal('projekt', core.project_name(empty), 'neulozena zakazka ma zastupny nazov')
  NxTest.assert_equal('projekt', core.save_project_name(empty, 'ine meno'),
                      'a zapis sa NEUDEJE')
  named = Struct.new(:path, :guid).new('C:/x/KLINIKA_v7.skp', '')
  NxTest.assert_equal('KLINIKA_v7', core.project_name(named),
                      'bez ulozeneho zaznamu sa nazov berie zo suboru zakazky')
end

NxTest.test('ST-1a: VSETKY STYRI exporty citaju nazov zo SERVERA — z DOM uz nechodi') do
  # Presne toto bol BLOCKER #1: dokial nazov posielal DOM, dve okna mali dve
  # pravdy a ta ista zakazka sa v dvoch vystupoch volala inak.
  NxTest.assert(ST1B_CORE_RB.include?('project: project_name(model)'),
                'VEPO export cita nazov v Ruby')
  # ŠT-1c PR A: telo CSV kovania sa prestahovalo do jadra; PR B1 tam presunula
  # aj oba XLSX exporty. VSETKY STYRI teda citaju nazov v ZDIELANOM jadre —
  # dve kopie by sa casom rozisli.
  NxTest.assert_equal(3, ST1B_CORE_RB.scan(/project = project_name\(model\)/).length,
                      'CSV kovania, XLSX rozpoctu aj XLSX cenovej ponuky citaju nazov v jadre')
  # Komentare (ktore o zaniknutej ceste hovoria) sa vynechavaju — hlada sa KOD.
  strip = ->(src) { src.lines.map { |l| l.sub(/#.*$/, '') }.join }
  NxTest.refute(strip.call(ST1B_CORE_RB).include?("data['project']"),
                'zdielane jadro nazov z klienta NECITA')
  [['budget.js', ST1B_BUDGET_JS], ['studio.js', ST1B_STUDIO_JS]].each do |(name, src)|
    NxTest.refute(src.match?(/project:\s*\(/),
                  "#{name} uz nesmie posielat `project:` z DOM (server je autorita)")
  end
  NxTest.assert(ST1B_STUDIO_HTML.include?('id="secbody"') && ST1B_STUDIO_JS.include?("id=\"prjInput\""),
                'editovatelny input zije v liste Kusovnika v Studiu')
end

NxTest.test('ST-1a: merge 18+36 je GLOBALNE nastavenie a chodi v KAZDOM pushi (audit #16)') do
  NxTest.assert(ST1B_CORE_RB.include?("vepo_settings['merge_18_36'] != false"),
                'default je zapnute')
  NxTest.assert(ST1B_CORE_RB.include?('merge = merge_18_36'),
                'export cita merge zo SERVERA, nie z checkboxu')
  NxTest.assert(ST1B_STUDIO_RB.include?('merge_18_36: ProductionCore.merge_18_36'),
                'stav checkboxu je v KAZDOM pushi Studia — cita sa zo SERVERA')
  # SMOKE 22.8.: checkbox sa z listy prestahoval do ROHOVEHO nastavenia VEPO
  # (`vepoMenuHtml`) — pravidlo „hodnota je z payloadu" plati bezo zmeny.
  NxTest.assert(ST1B_STUDIO_JS.include?("(s.merge_18_36 === false ? '' : ' checked')"),
                'checkbox sa NASADZUJE z payloadu (nie z pamate klienta)')
  NxTest.assert(ST1B_STUDIO_JS.include?('NX.setVepoBar') || ST1B_STUDIO_JS.include?('setVepoBar:'),
                'a echo servera ho dorovna aj v otvorenom nastaveni')
end

# --- 3) kontrakt payloadu Kusovnika (audit #4) -------------------------------

NxTest.test('ST-1a: materials_meta nesie label, farbu a hrubku per material_id') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert(core.respond_to?(:materials_meta), 'ProductionCore.materials_meta existuje')
  NxTest.assert(core.respond_to?(:edges_meta), 'a jeho protajsok pre ABS pasky')
  NxTest.assert(ST1B_STUDIO_RB.include?('materials_meta: ProductionCore.materials_meta(bom)'),
                'payload Studia ich naozaj nesie')
  NxTest.assert(ST1B_STUDIO_RB.include?('edges_meta: ProductionCore.edges_meta(bom)'),
                'aj pasky (pohlad ABS)')
  # tvar zaznamu — klient sa na tieto kluce spolieha
  meta = core.materials_meta(rows: [{ 'material_id' => 'NEEXISTUJE' }], sheets: [])
  NxTest.assert(meta.key?('NEEXISTUJE'), 'material z riadku dostane zaznam aj bez katalogu')
  NxTest.assert_equal(%w[label color th uni].sort, meta['NEEXISTUJE'].keys.sort,
                      'tvar zaznamu je kontrakt Š1')
  NxTest.assert_equal('NEEXISTUJE', meta['NEEXISTUJE']['label'],
                      'material mimo katalogu sa pomenuje svojim ID — nikdy sa nevymysla nazov')
  NxTest.assert_equal(nil, meta['NEEXISTUJE']['color'],
                      'bez katalogovej farby sa vzorka NEKRESLI (radsej nic nez nahodna farba)')
end

NxTest.test('ST-1a: farba je katalogove pole [r,g,b], nie CSS retazec') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert_equal([1, 2, 3], core.catalog_color('color' => [1, 2, 3]))
  NxTest.assert_equal(nil, core.catalog_color('color' => '#ff0000'), 'CSS retazec sa odmietne')
  NxTest.assert_equal(nil, core.catalog_color('color' => [1, 2]), 'neuplne pole sa odmietne')
  NxTest.assert_equal(nil, core.catalog_color(nil), 'chybajuci zaznam nezhodi prevod')
end

NxTest.test('ST-1a: rola dielca je SERVEROVY text a NEMENI kluc agregacie') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert_equal('Bok ľavý', core.role_label('side_left'), 'enum ma slovensky nazov')
  NxTest.assert_equal('Polica', core.role_label('shelf'))
  NxTest.assert_equal('', core.role_label(''), 'prazdna rola nevymysla text')
  NxTest.assert_equal('nieco_ine', core.role_label('nieco_ine'),
                      'nezname enum sa vypise, nie zahodí (aby sa nova rola nestratila)')
  # Kluc agregacie sa NESMIE zmenit — kusovnik aj VEPO na nom stoja.
  bom_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'bom.rb'), encoding: 'UTF-8')
  NxTest.refute(bom_src[/def row_key.*?\n      end/m].to_s.include?("r['role']"),
                'rola sa do kluca riadku NEPRIDALA — zmenila by kusovnik aj VEPO')
  NxTest.assert(ST1B_CORE_RB.include?('def rows_with_roles'),
                'rola sa doplna READ-ONLY obohatenim riadku')
end

NxTest.test('ST-1a: rows_with_roles paruje zaznamy s riadkami cez TEN ISTY row_key') do
  core = Noxun::Engine::ProductionCore
  rec = { 'name' => 'Bok', 'part_key' => 'p1', 'owner_id' => 'CAB-1', 'pid' => 1,
          'role' => 'side_left', 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0,
          'quantity' => 1, 'material_id' => 'M1', 'grain_direction' => 'length',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  bom = Noxun::Engine::Bom.compute(records: [rec])
  out = core.rows_with_roles(bom[:rows], records: [rec])
  NxTest.assert_equal('Bok ľavý', out.first['role_label'], 'riadok dostal svoju rolu')
  NxTest.assert_equal(bom[:rows].first['key'], out.first['key'], 'kluc riadku ostal NEDOTKNUTY')
  NxTest.assert_equal([], core.rows_with_roles([], records: []), 'prazdny kusovnik nezhodi obohatenie')
end

NxTest.test('ST-1a: sucty suctoveho riadku pocita SERVER (JS zo `totals` LEN cita)') do
  NxTest.assert(ST1B_STUDIO_RB.include?('totals: totals_payload(bom, estimate)'),
                'payload nesie hotove sucty')
  body = ST1B_STUDIO_RB[/def totals_payload.*?\n        end\n/m].to_s
  %w[parts rows m2 bm materials edges plates_min plates_max].each do |k|
    NxTest.assert(body.include?("'#{k}'"), "sucet #{k} chyba v payloade")
  end
  NxTest.refute(ST1B_STUDIO_JS.match?(/reduce\(|\+=\s*\w+\.m2|\+=\s*\w+\.quantity/),
                'studio.js nesmie scitavat sumy — od toho je server')
end

# --- 4) vlastny kanal okna (audit #3) ----------------------------------------

NxTest.test('ST-1a: Studio ma VLASTNY generacny token aj vlastny relay') do
  NxTest.assert(ST1B_STUDIO_RB.include?('@generation = @generation.to_i + 1'),
                'push_state zdviha vlastnu generaciu')
  NxTest.assert(ST1B_STUDIO_RB.include?('generation: @generation'),
                'a odovzdava ju zdielanemu jadru')
  NxTest.assert(ST1B_STUDIO_RB.include?('NX.studioRelay('),
                'vyber ide vlastnym relayom (inak by odpoved prisla do okna Vyroba)')
  NxTest.assert(ST1B_STUDIO_RB.include?('NX.studioRelayExport('), 'export tiez')
  NxTest.assert(ST1B_BRIDGE_JS.include?('studioRelay: function(p)'), 'panel relay existuje')
  NxTest.assert(ST1B_BRIDGE_JS.include?('studioRelayExport: function(p)'), 'aj pre export')
  NxTest.assert(ST1B_BRIDGE_JS.include?('sketchup.studio_do_select'), 'a vola vlastny callback')
  NxTest.assert(ST1B_PANEL_RB.include?("cb(dlg, 'studio_do_select')"), 'panel ho registruje')
  NxTest.assert(ST1B_PANEL_RB.include?("cb(dlg, 'studio_do_export')"), 'aj export')
end

NxTest.test('ST-1a: export zo Studia ma PLNY flush handshake') do
  # ŠT-1c PR B3: relaye okna Vyroba, s ktorymi sa tvar handshaku porovnaval,
  # ZANIKLI — kontrakt teraz drzia relaye Studia samy (a strazi ho aj to, ze
  # kazdy z nich ma vsetky tri prvky: guard, flush, flush_blocked).
  studio = ST1B_BRIDGE_JS[/studioRelayExport: function\(p\)\{.*?\n    \},/m].to_s
  NxTest.assert(!studio.empty?, 'relay Studia sa nasiel')
  NxTest.refute(ST1B_BRIDGE_JS.include?('productionRelayExport: function(p)'),
                'relay zaniknuteho okna Vyroba je PREC')
  NxTest.assert(studio.include?('!validateFields()'), 'neplatne pole export ZASTAVI')
  NxTest.assert(studio.include?('p.flush_blocked = blocked'), 'a povie to serveru')
  NxTest.assert(studio.include?('flushCabinetEditsNow()') && studio.include?('flushBoardEditsNow()'),
                'rozpisane edity korpusu aj dosky idu na server PRED zberom modelu')
end

NxTest.test('ST-1a: gen mismatch = RE-PUSH a status, nikdy ticho') do
  body = ST1B_CORE_RB[/def do_export\(model, data.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'zdielane telo exportu sa nasiel')
  NxTest.assert(body.include?('repush.call'), 'stary DOM klik obnovi okno')
  NxTest.assert(body.include?('Dáta okna sa medzitým zmenili'), 'a povie preco')
  # Review P2: vyber koncil TICHYM no-opom — pouzivatel klikol, nic sa
  # neoznacilo a okno mlcalo.
  sel = ST1B_CORE_RB[/def do_select\(model, data.*?\n      end\n/m].to_s
  NxTest.assert(sel.include?('Dáta okna sa medzitým obnovili — klikni znova.'),
                'aj vyber povie, PRECO sa nic neoznacilo')
  opts = ST1B_STUDIO_RB[/def do_set_vepo_opts.*?\n        end\n/m].to_s
  NxTest.assert(opts.include?('Okno sa medzitým prepočítalo'), 'to iste pri zapise nastaveni')
  NxTest.assert(opts.include?('Model sa medzitým prepol'), 'a pri prepnutom dokumente')
end

NxTest.test('ST-1a (review P2): zapis nastaveni NEZDVIHA generaciu (inak by prvy export spadol)') do
  # `change` na inpute Projekt priletí tesne pred `click` na VEPO. Keby zapis
  # koncil plnym push_state, generacia by sa zdvihla a prvy export by ZARUCENE
  # spadol na „Dáta okna sa medzitým zmenili" — pritom kusovnik sa nezmenil.
  opts = ST1B_STUDIO_RB[/def do_set_vepo_opts.*?\n        end\n/m].to_s
  NxTest.assert(!opts.empty?, 'handler sa nasiel')
  NxTest.assert(opts.include?('push_vepo_bar(model)'),
                'lista sa synchronizuje CIELENYM echom (vzor push_edge_check)')
  # Jediny push_state v handleri smie byt v ODMIETACICH vetvach (gen/model guard).
  tail = opts.split('msg = []').last.to_s
  NxTest.refute(tail.include?('push_state'),
                'uspesny zapis NESMIE prepocitat cele okno — zdvihol by generaciu')
  NxTest.refute(opts.include?('ProductionDialog'),
                'ŠT-1c PR B3: vetva zaniknuteho okna Vyroba je PREC')
  echo = ST1B_STUDIO_RB[/def push_vepo_bar.*?\n        end\n/m].to_s
  NxTest.refute(echo.include?('@generation'), 'echo sa generacie NEDOTYKA')
  NxTest.assert(echo.include?('NX.setVepoBar'), 'a meni LEN obsah listy')
  NxTest.assert(ST1B_STUDIO_JS.include?('setVepoBar: function(state)'), 'klient echo pozna')
  NxTest.assert(ST1B_STUDIO_JS.include?('document.activeElement !== inp'),
                'hodnota inputu sa nenasadzuje, kym v nom pouzivatel pise')
end

NxTest.test('ST-1a (review P2): sekcia ma RUCNY refresh (prestavba z Inspectora sem sama nedorazi)') do
  NxTest.assert(ST1B_STUDIO_RB.include?("cb(dlg, 'refresh_bom')"), 'callback existuje')
  NxTest.assert(ST1B_STUDIO_JS.include?("id=\"refreshBtn\""),
                'a MA ho co zavolat — inak by okno exportovalo VEPO zo starych cisel')
  NxTest.assert(ST1B_STUDIO_JS.include?("sketchup.refresh_bom('')"), 'tlacidlo vola callback')
end

NxTest.test('SMOKE 22.8. (1A–1D): LISTA Kusovnika a rohove nastavenie VEPO — kontrakt') do
  kontrakt = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'zdroje', 'ui20', 'UI20_KONTRAKT.md'),
                       encoding: 'UTF-8')
  mockup = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'zdroje', 'ui20', 'mockup_studio.html'),
                     encoding: 'UTF-8')

  # 1B: neaktivne XLSX/CSV placeholdery zanikli vo VSETKYCH TROCH miestach
  # (pravidlo troch miest: kod · kontrakt · mockup) — inak by sa pri porovnani
  # panela s mockupom 1:1 hlasil rozdiel, ktory je v skutocnosti rozhodnutim.
  NxTest.refute(ST1B_STUDIO_JS.include?('XLSX zatiaľ neexistuje'),
                'kod: placeholder XLSX kusovnika je prec')
  NxTest.refute(ST1B_STUDIO_JS.include?('CSV zatiaľ neexistuje'),
                'kod: a placeholder CSV kusovnika tiez')
  NxTest.assert(kontrakt.include?('tlačidlá sa NEZOBRAZUJÚ'),
                'kontrakt Š5 nesie verdikt zo smoke testu 22.8.')
  NxTest.refute(mockup.include?('XLSX kusovník pripravený') || mockup.include?(' XLSX</button>'),
                'mockup: lista Kusovnika uz XLSX/CSV nekresli')

  # 1A: checkbox „18+36 spolu" sa PRESUNUL do rohoveho nastavenia VEPO.
  NxTest.refute(ST1B_STUDIO_JS.include?('class="mergebox"'), 'z listy checkbox zmizol')
  NxTest.refute(ST1B_STUDIO_HTML.include?('.mergebox'), 'a jeho styl v okne neostal mrtvy')
  NxTest.assert(ST1B_STUDIO_JS.include?('function vepoMenuHtml'),
                'nastavenie ma vlastny maly markup (obsah je iny nez 3-stavova kontrola hran)')
  NxTest.assert(ST1B_STUDIO_JS.include?('id="vepoMore" class="cornerzone"'),
                'ale klikaciu zonu ZDIELA s existujucim vzorom (rail + lista Kontroly)')
  NxTest.assert(ST1B_STUDIO_JS.include?('id="mergeChk"'),
                'checkbox zije dalej — len na inom mieste')
  NxTest.assert(ST1B_STUDIO_JS.include?("if (vepoMenuOpen && !t.closest('.vepofly')) vepoMenuClose();"),
                'zatvara ho klik mimo')
  NxTest.assert(ST1B_STUDIO_JS.include?('if (vepoMenuOpen){'), 'aj Escape')
  # Zapis ide EXISTUJUCOU cestou — ziadny druhy kanal na server.
  NxTest.assert_equal(1, ST1B_STUDIO_JS.scan(/sketchup\.studio_set_vepo_opts\(/).length,
                      'zapis nastavenia ma jedinu cestu (`studio_set_vepo_opts`)')
  NxTest.assert(kontrakt.include?('ROHOVÉ NASTAVENIE'), 'kontrakt roh pozna')

  # Review #1: obe menu listy visia na SVOJOM tlacidle (vlastny pozicovaci
  # obal), nie na `.sectools` — inak sa po presune tlacidla od neho odtrhnu.
  NxTest.assert(ST1B_STUDIO_JS.include?('<span class="colfly">'), 'menu stlpcov ma obal')
  NxTest.assert(ST1B_STUDIO_HTML.include?('.colfly { position: relative;'),
                'a obal je pozicovaci kontext')
  colcss = ST1B_STUDIO_HTML[/\.colmenu \{[^}]*\}/m].to_s
  NxTest.assert(colcss.include?('right: 0;'), 'menu je kotvene na tlacidlo, nie na okraj listy')
  NxTest.refute(colcss.include?('right: 12px'), 'stare kotvenie na listu je PREC')
  NxTest.assert(mockup.include?('colfly'), 'mockup drzi ten isty vzor (1:1)')

  # Review #4: obe rohove/rozbalovacie okna maju hlavicku `.mgrp`.
  NxTest.assert(ST1B_STUDIO_JS.include?('<div class="mgrp">Nastavenie VEPO exportu</div>'),
                'nastavenie VEPO ma hlavicku')
  NxTest.assert(ST1B_STUDIO_HTML.include?('.vepomenu .mgrp'), 'a jej styl (klon .colmenu .mgrp)')

  # Review #5: pravidlo pre neaktivne ovladace listy ZANIKLO spolu s poslednym
  # z nich — mrtve CSS sluby vzor, ktory sa uz nekresli.
  NxTest.refute(ST1B_STUDIO_HTML.include?('.sectools [aria-disabled="true"]'),
                'mrtve pravidlo `.sectools [aria-disabled]` je zmazane')

  # Review #7: KAZDA sekcia ma vlastnu cestu k cerstvym cislam. Kontrola bola
  # posledna bez nej — a je to sekcia, kvoli ktorej sa clovek do okna vracia.
  ctrl = ST1B_STUDIO_JS[/if \(studioSec === 'ctrl'\)\{.*?\n    \}/m].to_s
  # Od 22.8. kresli tlacidlo ZDIELANY helper `refreshBtnHtml` (jeden markup pre
  # vsetkych 5 mist) — sekcia si ho pyta aj s vlastnym tooltipom.
  NxTest.assert(ctrl.include?('refreshBtnHtml(staleFlag,'), 'lista Kontroly ma „Obnoviť"')
  NxTest.assert(ctrl.include?('Prepočítať kontrolu z aktuálneho modelu'),
                'a tooltip hovori o KONTROLE')
  NxTest.assert(ST1B_STUDIO_JS.include?("ctrl: 'Prepočítavam kontrolu…'"),
                'aj priebezna hlaska je per sekciu')
  NxTest.assert_equal(1, ST1B_STUDIO_JS.scan(/t\.closest\('#refreshBtn'\)/).length,
                      'vsetky sekcie idu JEDNYM handlerom (ziadna druha serverova cesta)')
  NxTest.assert(mockup.include?('Kontrola prepočítaná z modelu'), 'mockup Kontroly to drzi tiez')

  # Review #8: otvoreny overlay patri sekcii, z ktorej odchadzame.
  NxTest.assert(ST1B_STUDIO_JS.include?('function closeSectionMenus'),
                'zhasnutie overlayov ma JEDNO miesto')
  go = ST1B_STUDIO_JS[/function studioGoSection\(id\)\{.*?\n  \}/m].to_s
  NxTest.assert(go.include?('closeSectionMenus();'), 'prepnutie sekcie ich zhasne')
  NxTest.assert(ST1B_STUDIO_JS[/if \(ST && ST\.open_section.*?\n      \}/m].to_s
                              .include?('closeSectionMenus();'),
                'a deep-link zo servera tiez')

  # 1D: „Projekt" je VSTUP so stitkom, nie popisok medzi tlacidlami.
  NxTest.assert(ST1B_STUDIO_JS.include?('<span class="prjlbl">Projekt</span>'),
                'pole ma viditelny stitok')
  NxTest.assert(ST1B_STUDIO_HTML.include?('.prjbox .prjlbl'), 'a stitok ma svoj styl')
  NxTest.assert(mockup.include?('prjbox'), 'mockup pole Projekt tiez ukazuje')
end

NxTest.test('SMOKE 22.8.: „Prepočítať ceny" prizna stare ceny (projekcia payloadu)') do
  # ZIADEN novy vypocet: `stale` uz v payloade JE (kresli sa z neho chip aj
  # zoznam). Klient ho len premietne na tlacidlo, ktore ten stav riesi.
  NxTest.assert(ST1B_BUDGET_JS.include?('function budPriceBtnHtml'),
                'tlacidlo ma vlastnu cistu funkciu (testuje ju tests/js/test_budget_ui.js)')
  body = ST1B_BUDGET_JS[/function budPriceBtnHtml.*?\n  \}\n/m].to_s
  NxTest.assert(body.include?('budStaleLabel(b && b.stale)'),
                'pocet aj prah beru z UZ EXISTUJUCEHO pasu cenovej cerstvosti')
  NxTest.assert(body.include?('bstalebtn'), 'a menia LEN triedu (farba je v CSS tokene)')
  NxTest.refute(body.match?(/Date|now|age_days\s*>/),
                'ziadny vypocet veku v klientovi — server je autorita')
  # Od 22.8. zdiela pravidlo s jantarovym „Obnoviť" (`.nxstale`) — obe tlacidla
  # hovoria to iste („cisla mozu byt stare"), takze maju aj ten isty vzhlad.
  css = ST1B_STUDIO_HTML[/\.sectools \.ghostbtn\.bstalebtn,[^{]*\{[^}]*\}/m].to_s
  NxTest.assert(css.include?('--nx-warn'), 'farba ide cez jantarove tokeny')
  NxTest.refute(css.match?(/green|--nx-state-green|--nx-ok/),
                'ZIADNA zelena — vyznamove farby ostavaju semaforu Kontroly')
end

NxTest.test('SMOKE 22.8.: „Obnoviť" hlasku VZDY zhodi — nikdy vecne „Prepočítavam…"') do
  # Klient si pred volanim nastavi „Prepočítavam…" (per sekciu) a sam o vysledku
  # nema ako vediet — prepocet bezi na SERVERI. Kym hlasku nikto nezhadzoval,
  # visela v okne aj po dobehnutom prepocte a vyzeralo to ako zamrznute okno.
  NxTest.assert(ST1B_STUDIO_JS.include?("var REFRESH_STATUS = {"),
                'klient hlasku „Prepočítavam…" naozaj nastavuje (per sekciu)')
  NxTest.assert(ST1B_STUDIO_RB.include?("cb(dlg, 'refresh_bom')  { |_p| do_refresh_bom }"),
                'callback uz nevola holy push_state — ma vlastnu cestu s hlaskou')
  body = ST1B_STUDIO_RB[/def do_refresh_bom.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('push_state'), 'USPESNA vetva okno prepocita')
  NxTest.assert(body.include?("set_status('Prepočítané.')"),
                'a HNED za tym zhodi hlasku (echo NX.setStatus)')
  # Review #6: potvrdenie LEN ked payload naozaj odosiel. `js` hlta vynimky
  # `execute_script` a mlci pri mrtvom okne — bez navratovej hodnoty by server
  # potvrdil prepocet, ktory sa ku klientovi nikdy nedostal.
  NxTest.assert(body.include?('return unless push_state'),
                'review #6: „Prepočítané." az po OVERENOM odoslani payloadu')
  jsm = ST1B_STUDIO_RB[/def js\(script\).*?\n        end\n/m].to_s
  NxTest.assert(jsm.include?('return false unless'), 'review #6: `js` prizna mrtve okno')
  NxTest.assert(jsm.match?(/execute_script\(script\)\s*\n\s*true/),
                'review #6: a uspesne odoslanie vracia true')
  NxTest.assert(jsm.match?(/log_error.*\n\s*false\n/),
                'review #6: vynimka konci false (nie tichym nil, ktore by sa citalo ako uspech)')
  push = ST1B_STUDIO_RB[/def push_state\(bump: true\).*?\n        end\n/m].to_s
  # POSLEDNY VYRAZ metody = jej navratova hodnota. Hlada sa posledny riadok
  # s kodom (komentare a zatvaracie `end` sa vynechavaju). Od jantaroveho
  # „Obnoviť" si vysledok drzi premenna `sent` (medzi nou a returnom sa zapisuje
  # epocha) — PREPOSIELA sa nadalej.
  code = push.lines.map(&:strip).reject { |l| l.empty? || l.start_with?('#') || l == 'end' }
  NxTest.assert(code.include?('sent = js("NX.setStudio(#{data.to_json})")'),
                'review #6: push_state si vysledok `js` odklada')
  NxTest.assert_equal('sent', code.last,
                      'review #6: push_state vysledok `js` PREPOSIELA (posledny vyraz metody)')
  # Rescue vetva: hlaska sa nesmie zaseknut ANI pri vynimke a chyba patri do logu.
  NxTest.assert(body.include?('rescue StandardError => e'), 'ma rescue vetvu')
  NxTest.assert(body.include?("Engine.log_error(e, 'StudioDialog.do_refresh_bom')"),
                'vynimka ide do logu s menom TEJTO cesty')
  NxTest.assert(body =~ /set_status\("Prepočet zlyhal.*?, true\)/,
                'a pouzivatel dostane CHYBOVU hlasku, nie vecne „Prepočítavam…"')
end

# --- 5) premostenia navigacie ZANIKLI (ŠT-4a) --------------------------------

NxTest.test('ŠT-4a: PREMOSTENIA ZANIKLI CELE — niet uz kam premostovat') do
  st = Noxun::Engine::StudioDialog
  # Premostenie bolo docasny most do satelitu, ktory este zil. Postupne zanikli
  # vsetky: `PRODUCTION_BRIDGES` (ŠT-1c PR B3, okno Vyroba) · `mat` (ŠT-2a/2b) ·
  # `hw` (ŠT-3a) · `rules` (ŠT-3b-1) · `tpl` (ŠT-3c-1) a ŠT-4a odstranila
  # POSLEDNY satelit (Nastavenia rozpoctu). Cela masineria preto zanikla —
  # most bez oboch koncov je mrtvy kod, ktory prezije prve „to sa este zide".
  %i[PRODUCTION_BRIDGES WINDOW_BRIDGES BRIDGE_STATUS].each do |c|
    NxTest.refute(st.const_defined?(c), "konstanta #{c} uz neexistuje")
  end
  NxTest.refute(st.respond_to?(:do_bridge), 'a ani serverova cesta `do_bridge`')
  NxTest.refute(st.respond_to?(:bridge_window), 'ani `bridge_window`')
  NxTest.refute(ST1B_STUDIO_RB.include?("cb(dlg, 'studio_bridge')"),
                'callback okna zanikol tiez — klient nema co volat')
  # Klientska strana MUSI zaniknut V TEJ ISTEJ davke, inak by navigacia volala
  # callback, ktory neexistuje (a klik by ticho nespravil nic).
  NxTest.refute(ST1B_STUDIO_JS.include?('sketchup.studio_bridge'),
                'JS uz premostenie neposiela')
  NxTest.refute(ST1B_STUDIO_JS.include?('function bridgeTo('), '`bridgeTo` zaniklo')
  # Pozor na komentar: meno zaniknutej funkcie v NOM ostava zamerne (vysvetluje
  # PRECO zaniklo), takze sa hlada FUNKCIA a jej export, nie retazec.
  NxTest.refute(ST1B_STUDIO_JS.include?('function navBridgeIds('), 'aj jeho zrkadlo `navBridgeIds`')
  NxTest.refute(ST1B_STUDIO_JS.include?('navBridgeIds:'), 'a jeho export do testov')
  nav = ST1B_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  NxTest.refute(nav.include?('bridge:'),
                'ZIADNA polozka navigacie uz nie je premostenie — kazda je sekcia (alebo ma dovod)')
  NxTest.refute(ST1B_STUDIO_JS.include?('nbridge'),
                'a zmizla aj sipka ↗, ktora premostenie oznacovala')
end

NxTest.test('ST-1a: „Nárezový plán" je JEDINA neaktivna polozka a ma dovod (D-78)') do
  nav = ST1B_STUDIO_JS[/var NAV = \[.*?\n  \];/m].to_s
  NxTest.assert(!nav.empty?, 'navigacia sa nasla')
  NxTest.assert_equal(1, nav.scan(/disabled:/).length,
                      'jedina neaktivna polozka — vsetko ostatne je premostenie')
  NxTest.assert(nav.include?("disabled: 'fáza 2"), 'a dovod je vypisany, nie zamlcany')
end

# --- 6) okno Vyroba ZANIKLO --------------------------------------------------

NxTest.test('ŠT-1c PR B3: okno Vyroba a jeho tri subory su PREC') do
  # Postupny presun: ST-1a vzala taby Kusovník / Materiály / ABS, ŠT-1b tab
  # Kontrola, ŠT-1c PR A tab Kovanie a PR B1 posledny tab Rozpocet. PR B3
  # zmazala prazdnu skrupinu vratane vsetkych vstupnych bodov.
  %w[production_dialog.rb production.html js/production.js].each do |rel|
    NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', *rel.split('/'))),
                  "ui/#{rel} zanikol spolu s oknom")
  end
  NxTest.refute(defined?(Noxun::Engine::ProductionDialog),
                'modul ProductionDialog uz nesmie existovat')
  NxTest.refute(ST1B_MAIN_RB.include?('noxun_engine/ui/production_dialog'),
                'loader ho uz nenacitava')
  NxTest.refute(ST1B_PANEL_RB.include?('ProductionDialog'),
                'panel uz nema ziadny relay do zaniknuteho okna')
end

NxTest.test('ŠT-1c: `price()` odisiel z okna Vyroba do Studia (sekcia Nakup)') do
  # ST-1a ho tu este drzal tab Kovanie (audit #9). ŠT-1c PR A tab presunula,
  # takze helper — a s nim CELY nakupny zoznam — zije v studio.js.
  NxTest.assert(ST1B_STUDIO_JS.include?('function price(v)'), 'helper zije v Studiu')
  NxTest.assert(ST1B_STUDIO_JS.include?('price(r.price_eur_vat)'), 'a naozaj sa pouziva')
  NxTest.assert(ST1B_STUDIO_RB.include?('hardware_sets: hw_exp'),
                'nakupny zoznam dostava Studio (sekcia Nakup kovania)')
end

# --- 7) lifecycle okna a refresh cesty (audit #10, #14) ----------------------

NxTest.test('ST-1a: okno sa po zatvoreni vynuluje a JS chyby idu do logu (audit #14)') do
  # Od jantaroveho „Obnoviť" (22.8.) je v bloku aj odvesenie observera —
  # kontrakt „referencia sa vynuluje" plati nezmeneny.
  closed = ST1B_STUDIO_RB[/@dialog\.set_on_closed do.*?\n          end\n/m].to_s
  NxTest.assert(closed.include?('@dialog = nil'),
                'referencia na mrtve okno by tichla na vynimke pri kazdom pushi')
  NxTest.assert(ST1B_STUDIO_RB.include?("add_action_callback('js_error')"),
                'JS chyby okna sa daju precitat (konzolu HtmlDialogu nevidno)')
  NxTest.assert(ST1B_STUDIO_HTML.include?('js/errors.js'), 'okno nacitava errors.js')
  NxTest.assert(ST1B_STUDIO_RB.include?("Engine.register_dialog_fit(dlg, 'studio')"),
                'spolocny boot hook = tema (UI-01) + dorovnanie velkosti (D-77)')
end

NxTest.test('ST-1a: Studio je vo VSETKYCH refresh cestach (audit #10)') do
  # ŠT-1c PR B3: piata cesta viedla z okna Vyroba (jeho `price_refresh_after`)
  # — okno zaniklo, prepocet cien riadi Studio samo (`price_refresh_after_proc`
  # vo `studio_dialog.rb`).
  cesty = {
    'core/scale_observer.rb' => 'StudioDialog.on_model_changed(model)',
    'ui/materials_dialog.rb' => 'StudioDialog.refresh_if_open',
    'ui/supplier_settings_dialog.rb' => 'StudioDialog.refresh_if_open',
    # F5 (ŠT-3a-2): polozka chytala KOMENTAR o zrusenej ceste — realna cesta
    # obnovy Studia z tohto modulu je `refresh_if_open` (`after_sets_change`).
    'ui/hardware_catalog_dialog.rb' => 'StudioDialog.refresh_if_open'
  }
  cesty.each do |rel, needle|
    src = File.read(File.join(NxTest::ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
    NxTest.assert(src.include?(needle),
                  "#{rel} neobnovuje Studio — okno by drzalo stare cisla")
    NxTest.refute(src.include?('ProductionDialog'),
                  "#{rel} este obsahuje vetvu zaniknuteho okna Vyroba")
  end
  after = ST1B_STUDIO_RB[/def price_refresh_after_proc.*?\n        end\n/m].to_s
  # ŠT-2b: satelit Materialy zanikol — katalog dostava SEKCIA `mat` tohto okna.
  NxTest.assert(after.include?('push_mat_catalog') && after.include?('Panel.push_materials') &&
                after.include?('HardwareCatalogDialog.push_items'),
                'po prepocte cien dostanu cerstve cisla vsetci odberatelia katalogu')
  NxTest.refute(after.include?('MaterialsDialog.push_catalog'),
                'vetva zaniknuteho satelitu Materialy je PREC')
  NxTest.refute(after.include?('ProductionDialog'), 'okrem zaniknuteho okna Vyroba')
end

NxTest.test('ST-1a: D-51 trojica rozmerov okna si zodpoveda (obsah 1060 × 640)') do
  fit = ST1B_STUDIO_HTML[/NX_FIT_MIN = \{ w: (\d+), h: (\d+) \}/]
  NxTest.assert(!fit.nil?, 'studio.html deklaruje obsahove minimum')
  w = Regexp.last_match(1).to_i
  h = Regexp.last_match(2).to_i
  NxTest.assert_equal([1060, 640], [w, h], 'obsahovy viewport podla kontraktu D-51')
  dlg_w = ST1B_STUDIO_RB[/width: (\d+),/, 1].to_i
  min_w = ST1B_STUDIO_RB[/min_width: (\d+),/, 1].to_i
  NxTest.assert(dlg_w > w && dlg_w - w <= 24,
                "vonkajsia sirka #{dlg_w} musi byt obsah #{w} + ramik (~16 px)")
  NxTest.assert_equal(dlg_w, min_w, 'min_width drzi tu istu sirku (okno sa neda stiahnut pod obsah)')
end

# --- 8) vstupne body (audit #2) ---------------------------------------------

NxTest.test('ST-1a: toolbar aj rail vedu do ŠTÚDIA; Výroba zmizla aj z Extensions menu') do
  NxTest.assert(ST1B_MAIN_RB.include?("UI::Command.new('Štúdio') { StudioDialog.show }"),
                'toolbar tlacidlo Štúdio otvara Studio')
  # ŠT-1c PR B3: docasna polozka menu „Výroba" zanikla spolu s oknom.
  NxTest.refute(ST1B_MAIN_RB.include?("menu.add_item('Výroba"),
                'okno Vyroba uz z menu neotvara nic — zaniklo')
  NxTest.assert(ST1B_MAIN_RB.include?("menu.add_item('Štúdio') { StudioDialog.show }"),
                'Studio v menu ostava')
  panel_html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.html'), encoding: 'UTF-8')
  rail = panel_html[/<button[^>]*id="railStudio".*?<\/button>/m].to_s
  NxTest.assert(rail.include?('onclick="openStudio()"'),
                'rail „Štúdio" otvara Studio, nie okno Vyroba')
  NxTest.assert(ST1B_MAIN_RB.include?("Sketchup.require 'noxun_engine/ui/studio_dialog'"),
                'loader okno nacitava')
end

NxTest.test('ST-1a: ceruzka riadku zdvihne Inspector — a NIC v modeli nezapise') do
  body = ST1B_CORE_RB[/def do_select\(model, data.*?\n      end\n/m].to_s
  NxTest.assert(!body.empty?, 'zdielane telo vyberu sa nasiel')
  NxTest.assert(body.include?("data['focus_inspector'] == true && Panel.dialog_alive?"),
                'Inspector sa zdviha LEN ked zije (nikdy sa neotvara sam)')
  NxTest.assert(body.include?('Panel.bring_to_front'), 'a robi to jedna metoda panela')
  NxTest.assert(body.include?('Panel.suspend_selection_sync'),
                'zmena vyberu bezi pod suspend guardom (vzor B2)')
  NxTest.assert(body.include?('Panel.push_selected(model, dedup: false)'),
                'refresh panela BEZ dedup ticku — dedup MENI model (lekcia D-103)')
  NxTest.refute(body.include?('start_operation'), 'vyber nie je operacia = ziadny krok Spat')
  NxTest.assert(ST1B_STUDIO_JS.include?("data-act=\"edit\""), 'ceruzka je vlastna akcia riadku')
  NxTest.assert(ST1B_STUDIO_JS.include?("data-act=\"eye\""), 'oko tiez')
  # Š3: riadok KUSOVNIKA ma PRAVE DVE hover akcie — tretia („detail") pride az
  # s D-94. Riadok KONTROLY (ŠT-1b) ma navyse KONTEXTOVU opravu, preto sa
  # pocita len markup tabulky kusovnika.
  parts = ST1B_STUDIO_JS[/function partsTable.*?\n  \}/m].to_s
  NxTest.assert_equal(2, parts.scan(/data-act="/).length,
                      'Š3: PRAVE DVE hover akcie v Kusovníku — tretia („detail") pride az s D-94')
end
