# frozen_string_literal: true
# ST-1a PR A: zdielane ciste jadro vystupov zakazky (`ui/production_core.rb`).
#
# Cielom dávky ST-1a bol REFACTOR BEZ ZMENY SPRAVANIA — pomocnici sa presunuli
# z okna Vyroba do `ProductionCore`, aby ich mohlo citat aj nove okno Studio.
#
# ŠT-1c PR B3: okno Vyroba ZANIKLO. Tvrdenia o jeho TENKYCH OBALOCH (ze na
# povodne mena stale odpoveda a ze deleguje) tym stratili predmet — jadro je
# od tejto davky JEDINA implementacia. Sada preto strazi:
#   1. Core existuje a vie VSETKO, co sa donho presunulo,
#   2. Core je BEZ STAVU (ciste funkcie — okenny stav patri dialogu),
#   3. loader ho nacitava PRED oknom, ktore ho vola,
#   4. spravanie samotnych pomocnikov (labely, guidy, refs) sa nezmenilo.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva). Parse-time
# tu ziadne SketchUp API nie je — vsetko je vnutri metod. V SketchUpe je subor
# uz nacitany pluginom.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

ST1A_CORE_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                          encoding: 'UTF-8')
ST1A_MAIN_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')

# Presne to, co dávka ST-1a PR A presunula do jadra.
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

NxTest.test('ST-1a: telo presunutych metod zije v Core (a nikde inde druhykrat)') do
  # Podpisy tiel, ktore sa presunuli. Ked sa niektory objavi v okne, mame dve
  # kopie toho isteho vypoctu — presne to, comu dávka predchadza.
  fingerprints = {
    'vepo_settings' => 'JsonFileStore.available?(path)',
    'save_vepo_settings' => 'JsonFileStore.write(path,',
    'vepo_materials' => 'labeled = Materials.sheets.map',
    'vepo_base_label' => "s['back_decor']",
    'vepo_disambiguate' => 'groups_per = labeled.group_by',
    'vepo_edge_thicknesses' => 'Materials.edges.each_with_object',
    'default_project_name' => "File.basename(p, '.*')",
    'sheets_map' => 'Materials.sheets.each_with_object',
    'model_guid' => 'model.respond_to?(:guid)',
    'pids_for_problem' => 'Sketchup::ComponentInstance',
    'refs_for' => 'bom[:rows].find'
  }
  absent = fingerprints.reject { |_m, needle| ST1A_CORE_SRC.include?(needle) }.keys
  NxTest.assert(absent.empty?,
                "production_core.rb neobsahuje telo: #{absent.join(', ')} — presun je neuplny")
  studio = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog.rb'),
                     encoding: 'UTF-8')
  leftovers = fingerprints.reject { |_m, needle| !studio.include?(needle) }.keys
  NxTest.assert(leftovers.empty?,
                "studio_dialog.rb obsahuje VLASTNU kopiu tela: #{leftovers.join(', ')} — " \
                'okno ma LEN volat ProductionCore')
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

NxTest.test('ST-1a: loader nacitava production_core PRED oknom, ktore ho vola') do
  core_at = ST1A_MAIN_SRC.index("Sketchup.require 'noxun_engine/ui/production_core'")
  dlg_at  = ST1A_MAIN_SRC.index("Sketchup.require 'noxun_engine/ui/studio_dialog'")
  NxTest.assert(!core_at.nil?, 'main.rb nenacitava noxun_engine/ui/production_core')
  NxTest.assert(!dlg_at.nil?, 'main.rb nenacitava noxun_engine/ui/studio_dialog')
  NxTest.assert(core_at < dlg_at,
                'production_core sa musi nacitat PRED studio_dialog (okno ho vola)')
  # ŠT-1c PR B3: zaniknute okno sa uz NESMIE nacitavat.
  NxTest.refute(ST1A_MAIN_SRC.include?('noxun_engine/ui/production_dialog'),
                'loader uz nesmie nacitavat zaniknute okno Vyroba')
end

NxTest.test('ST-1a: vepo_materials drzi kontrakt mapy material_id -> zaznam') do
  # Headless nad sandbox katalogom helpera (APPDATA je presmerovana) — metoda
  # cita LEN katalog materialov, ziadny SketchUp model.
  #
  # Tvrdenie je o TVARE vysledku, nie o „dve volania daju to iste" (to by bola
  # tautologia a==a): kluc je `material_id` z katalogu, hodnota VZDY nesie
  # neprazdny `label` (VEPO bucket) a volitelny `display` (ludsky zaklad pre
  # LOG), ktory sa uklada LEN ked sa od labelu lisi.
  NxTest.skip!('vyzaduje headless sandbox katalogu') unless NxTest.headless?
  mats = Noxun::Engine::ProductionCore.vepo_materials
  NxTest.assert(mats.is_a?(Hash), 'vepo_materials vracia mapu material_id -> zaznam')
  ids = Noxun::Engine::Materials.sheets.map { |s| s['material_id'] }
  NxTest.assert_equal(ids.sort, mats.keys.sort,
                      'mapa pokryva PRESNE dosky katalogu (ziadna navyse, ziadna nechyba)')
  bad_label = mats.reject { |_id, e| e.is_a?(Hash) && e['label'].is_a?(String) && !e['label'].empty? }
  NxTest.assert(bad_label.empty?,
                "zaznam bez neprazdneho `label`: #{bad_label.keys.join(', ')} — VEPO bucket by nemal meno")
  bad_display = mats.reject { |_id, e| !e.key?('display') || (e['display'].is_a?(String) && e['display'] != e['label']) }
  NxTest.assert(bad_display.empty?,
                "`display` sa uklada LEN ked sa lisi od labelu (porusene: #{bad_display.keys.join(', ')})")
  NxTest.assert_equal(mats.keys.length, mats.values.map { |e| e['label'] }.uniq.length,
                      'labely su JEDNOZNACNE — dva materialy sa nesmu zliat do jedneho VEPO bucketu')
end

NxTest.test('ST-1a: refs_for je cista funkcia') do
  bom = { rows: [{ 'key' => 'R1', 'refs' => [{ 'pid' => 11 }, { 'pid' => 12 }, { 'pid' => 11 }] }],
          hardware: [{ 'key' => 'H1', 'breakdown' => [{ 'owner_pid' => 21 }, { 'owner_pid' => 22 }] }] }
  core = Noxun::Engine::ProductionCore
  cases = [
    [{ 'parts_key' => 'R1' }, [11, 12]],
    [{ 'parts_key' => 'NIC' }, []],
    [{ 'hw_key' => 'H1' }, [21, 22]],
    [{ 'pids' => [5, 5, nil, 7] }, [5, 7]]
  ]
  cases.each do |(data, expected)|
    NxTest.assert_equal(expected, core.refs_for(bom, data), "refs_for #{data.keys.first}")
  end
end

NxTest.test('ST-1a: model_guid znesie nil aj objekt bez guid') do
  core = Noxun::Engine::ProductionCore
  no_guid = Object.new
  with_guid = Struct.new(:guid).new('G-1')
  NxTest.assert_equal('', core.model_guid(nil), 'nil model = prazdny guid')
  NxTest.assert_equal('', core.model_guid(no_guid), 'objekt bez guid = prazdny guid')
  NxTest.assert_equal('G-1', core.model_guid(with_guid), 'guid sa cita z modelu')
end

NxTest.test('ST-1a: vepo_base_label sklada label z dekoru, struktury, nazvu a typu') do
  core = Noxun::Engine::ProductionCore
  sheet = { 'material_id' => 'M1', 'decor' => 'K009', 'structure' => 'PW', 'type' => 'DTDL' }
  NxTest.assert_equal('K009 PW DTDL', core.vepo_base_label(sheet))
  # fallbacky (family -> material_id) su sucastou kontraktu labelu
  NxTest.assert_equal('PD', core.vepo_base_label({ 'material_id' => 'M2', 'family' => 'PD' }))
  NxTest.assert_equal('M3', core.vepo_base_label({ 'material_id' => 'M3' }))
end

NxTest.test('ST-1a: vepo_group_key vracia group_id, inak vyrobcu') do
  core = Noxun::Engine::ProductionCore
  NxTest.assert_equal('GRP-1', core.vepo_group_key('group_id' => 'GRP-1', 'manufacturer' => 'Egger'))
  NxTest.assert_equal('man:Egger', core.vepo_group_key('manufacturer' => 'Egger'))
  NxTest.assert_equal('man:', core.vepo_group_key({}))
end
