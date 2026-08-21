# frozen_string_literal: true
# ST-1a PR A: zdielane ciste jadro okna Vyroba (`ui/production_core.rb`).
#
# Cielom dávky je REFACTOR BEZ ZMENY SPRAVANIA — pomocnici sa presunuli do
# `ProductionCore`, aby ich mohlo citat aj nove okno Studio. Tato sada strazi
# tri veci:
#   1. Core existuje a vie VSETKO, co sa donho presunulo,
#   2. ProductionDialog na tie mena STALE odpoveda (aj privatne) — panel,
#      pure testy (`send(:vepo_materials)`) aj in-SU runner
#      (`send(:pids_for_problem)`) ich volaju povodnymi menami,
#   3. ide o DELEGACIU, nie o druhu kopiu — telo v production_dialog.rb
#      uz nezije (dve kopie by sa casom rozisli).
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva). Parse-time
# tu ziadne SketchUp API nie je — vsetko je vnutri metod. V SketchUpe su oba
# subory uz nacitane pluginom.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?

ST1A_CORE_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                          encoding: 'UTF-8')
ST1A_PROD_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb'),
                          encoding: 'UTF-8')
ST1A_MAIN_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')

# Presne to, co dávka ST-1a PR A presuva (rozsah zuzeny auditom #8 — telo
# do_export/do_select ostava v okne a extrahuje sa az v PR B).
ST1A_MOVED = %i[
  vepo_settings save_vepo_settings vepo_materials vepo_base_label
  vepo_disambiguate_variants vepo_disambiguate vepo_group_key
  vepo_edge_thicknesses default_project_name
  sheets_map edges_map model_guid
  pids_for_problem pids_for_duplicate refs_for
].freeze

NxTest.test('ST-1a: ProductionCore existuje a vie vsetkych presunutych pomocnikov') do
  NxTest.assert(defined?(Noxun::Engine::ProductionCore),
                'modul Noxun::Engine::ProductionCore sa nenacital')
  core = Noxun::Engine::ProductionCore
  missing = ST1A_MOVED.reject { |m| core.respond_to?(m) }
  NxTest.assert(missing.empty?,
                "ProductionCore neodpoveda na: #{missing.join(', ')} — presun je neuplny")
end

NxTest.test('ST-1a: ProductionDialog stale odpoveda na povodne mena (thin wrappery)') do
  pd = Noxun::Engine::ProductionDialog
  # respond_to?(.., true) vidi AJ privatne — presne tak ich volaju testy
  # (`send(:vepo_materials)`) a in-SU runner (`send(:pids_for_problem)`).
  missing = ST1A_MOVED.reject { |m| pd.respond_to?(m, true) }
  NxTest.assert(missing.empty?,
                "ProductionDialog stratil metody: #{missing.join(', ')} — wrappery musia ostat " \
                '(existujuce testy ich volaju reflexne a NESMU sa menit)')
end

NxTest.test('ST-1a: wrappery ostavaju PRIVATNE (verejne API okna sa nerozsirilo)') do
  pd = Noxun::Engine::ProductionDialog
  public_now = ST1A_MOVED.select { |m| pd.respond_to?(m) }
  NxTest.assert(public_now.empty?,
                "wrappery sa stali verejnymi: #{public_now.join(', ')} — refactor nesmie menit " \
                'viditelnost (verejne su len relay metody do_export/do_select/do_hw_csv)')
end

NxTest.test('ST-1a: relay trojica okna ostava public (regresia v0.5.39 sa nesmie vratit)') do
  pd = Noxun::Engine::ProductionDialog
  %i[do_export do_select do_hw_csv].each do |m|
    NxTest.assert(pd.respond_to?(m), "ProductionDialog.#{m} musi ostat PUBLIC (relay z panel.rb)")
  end
end

NxTest.test('ST-1a: production_dialog.rb DELEGUJE — telo presunutych metod tam uz nezije') do
  # Podpisy tiel, ktore sa presunuli. Ked sa niektory vrati do okna, mame
  # dve kopie toho isteho vypoctu — presne to, comu dávka predchadza.
  fingerprints = {
    'vepo_settings' => "JsonFileStore.available?(path)",
    'save_vepo_settings' => 'JsonFileStore.write(path,',
    'vepo_materials' => 'labeled = Materials.sheets.map',
    'vepo_base_label' => "s['back_decor']",
    'vepo_disambiguate' => 'groups_per = labeled.group_by',
    'vepo_edge_thicknesses' => 'Materials.edges.each_with_object',
    'default_project_name' => "File.basename(p, '.*')",
    'sheets_map' => 'Materials.sheets.each_with_object',
    'model_guid' => 'model.respond_to?(:guid)',
    'pids_for_problem' => 'Sketchup::ComponentInstance',
    'refs_for' => "bom[:rows].find"
  }
  leftovers = fingerprints.reject { |_m, needle| !ST1A_PROD_SRC.include?(needle) }.keys
  NxTest.assert(leftovers.empty?,
                "production_dialog.rb stale obsahuje telo: #{leftovers.join(', ')} — " \
                'wrapper ma LEN delegovat na ProductionCore')
  # a naopak: telo MUSI byt v Core
  absent = fingerprints.reject { |_m, needle| ST1A_CORE_SRC.include?(needle) }.keys
  NxTest.assert(absent.empty?,
                "production_core.rb neobsahuje telo: #{absent.join(', ')} — presun je neuplny")
end

NxTest.test('ST-1a: kazdy wrapper deleguje na ProductionCore rovnakym menom') do
  missing = ST1A_MOVED.reject { |m| ST1A_PROD_SRC.include?("ProductionCore.#{m}") }
  NxTest.assert(missing.empty?,
                "wrapper nedeleguje na ProductionCore: #{missing.join(', ')}")
end

NxTest.test('ST-1a: ProductionCore nedrzi ziadny okenny stav (@dialog/@generation/@pending_*)') do
  # Kontrakt modulu: ciste funkcie. Okenny stav patri VYHRADNE do dialogu —
  # dve okna nad jednym Core by si ho inak prepisovali.
  code = ST1A_CORE_SRC.lines.map { |l| l.sub(/#.*$/, '') }.join # komentare (aj zakaz vyssie) ignorujeme
  offenders = code.scan(/@[a-z_][a-z0-9_]*/).uniq
  NxTest.assert(offenders.empty?,
                "ProductionCore obsahuje instancne premenne: #{offenders.join(', ')} — " \
                'modul musi byt bez stavu')
end

NxTest.test('ST-1a: loader nacitava production_core PRED oknom Vyroba') do
  core_at = ST1A_MAIN_SRC.index("Sketchup.require 'noxun_engine/ui/production_core'")
  dlg_at  = ST1A_MAIN_SRC.index("Sketchup.require 'noxun_engine/ui/production_dialog'")
  NxTest.assert(!core_at.nil?, 'main.rb nenacitava noxun_engine/ui/production_core')
  NxTest.assert(!dlg_at.nil?, 'main.rb nenacitava noxun_engine/ui/production_dialog')
  NxTest.assert(core_at < dlg_at,
                'production_core sa musi nacitat PRED production_dialog (wrappery ho volaju)')
end

NxTest.test('ST-1a: vepo_materials cez Core a cez wrapper daju TEN ISTY vysledok') do
  # Headless nad sandbox katalogom helpera (APPDATA je presmerovana) — metoda
  # cita LEN katalog materialov, ziadny SketchUp model.
  NxTest.skip!('vyzaduje headless sandbox katalogu') unless NxTest.headless?
  core = Noxun::Engine::ProductionCore.vepo_materials
  wrap = Noxun::Engine::ProductionDialog.send(:vepo_materials)
  NxTest.assert_equal(core, wrap,
                      'wrapper musi vratit PRESNE to, co Core — inak to nie je delegacia')
end

NxTest.test('ST-1a: refs_for je cista funkcia a cez obe cesty vracia to iste') do
  bom = { rows: [{ 'key' => 'R1', 'refs' => [{ 'pid' => 11 }, { 'pid' => 12 }, { 'pid' => 11 }] }],
          hardware: [{ 'key' => 'H1', 'breakdown' => [{ 'owner_pid' => 21 }, { 'owner_pid' => 22 }] }] }
  core = Noxun::Engine::ProductionCore
  pd = Noxun::Engine::ProductionDialog
  cases = [
    [{ 'parts_key' => 'R1' }, [11, 12]],
    [{ 'parts_key' => 'NIC' }, []],
    [{ 'hw_key' => 'H1' }, [21, 22]],
    [{ 'pids' => [5, 5, nil, 7] }, [5, 7]]
  ]
  cases.each do |(data, expected)|
    NxTest.assert_equal(expected, core.refs_for(bom, data), "refs_for #{data.keys.first}")
    NxTest.assert_equal(expected, pd.send(:refs_for, bom, data),
                        "wrapper refs_for #{data.keys.first} musi dat to iste")
  end
end

NxTest.test('ST-1a: model_guid znesie nil aj objekt bez guid (obe cesty rovnako)') do
  core = Noxun::Engine::ProductionCore
  pd = Noxun::Engine::ProductionDialog
  no_guid = Object.new
  with_guid = Struct.new(:guid).new('G-1')
  [nil, no_guid, with_guid].each do |m|
    NxTest.assert_equal(core.model_guid(m), pd.send(:model_guid, m),
                        'model_guid musi ist cez JEDNU implementaciu')
  end
  NxTest.assert_equal('', core.model_guid(nil), 'nil model = prazdny guid')
  NxTest.assert_equal('G-1', core.model_guid(with_guid), 'guid sa cita z modelu')
end

NxTest.test('ST-1a: vepo_base_label sklada label z dekoru, struktury, nazvu a typu') do
  core = Noxun::Engine::ProductionCore
  pd = Noxun::Engine::ProductionDialog
  sheet = { 'material_id' => 'M1', 'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL' }
  NxTest.assert_equal('K009 PW DTDL', core.vepo_base_label(sheet))
  NxTest.assert_equal(core.vepo_base_label(sheet), pd.send(:vepo_base_label, sheet),
                      'wrapper vepo_base_label musi dat to iste')
  # fallbacky (family -> material_id) su sucastou kontraktu labelu
  NxTest.assert_equal('PD', core.vepo_base_label({ 'material_id' => 'M2', 'family' => 'PD' }))
  NxTest.assert_equal('M3', core.vepo_base_label({ 'material_id' => 'M3' }))
end

NxTest.test('ST-1a: vepo_group_key vracia group_id, inak vyrobcu') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert_equal('GRP-1', core.vepo_group_key('group_id' => 'GRP-1', 'manufacturer' => 'Egger'))
  NxTest.assert_equal('man:Egger', core.vepo_group_key('manufacturer' => 'Egger'))
  NxTest.assert_equal('man:', core.vepo_group_key({}))
  NxTest.assert_equal(core.vepo_group_key('group_id' => 'GRP-1'),
                      Noxun::Engine::ProductionDialog.send(:vepo_group_key, 'group_id' => 'GRP-1'),
                      'wrapper vepo_group_key musi dat to iste')
end
