# frozen_string_literal: true
# D-100 — nazvy skriniek. Automaticky nazov je ZIVY (dopocitava sa zo sucasnych
# parametrov, do configu sa NEUKLADA), rucny nazov sa uklada a nikdy sa
# neprepisuje. Heuristika spatnej kompatibility: ulozeny nazov, ktory vyzera ako
# automaticky (aj stary bezdiakriticky tvar), sa povazuje za NEnastaveny.
require_relative '../helper' unless defined?(NxTest)

CB100 = Noxun::Engine::CabinetBuilder

# ---------------------------------------------------------------------------
# heuristika automatickeho nazvu
# ---------------------------------------------------------------------------

NxTest.test('D-100: vzor automatickeho nazvu (diakritika, velkost pismen, medzery)') do
  [
    'Spodna skrinka 600',   # historicky tvar (tak sa mena pecili do V0.5.54)
    'Spodná skrinka 900',   # novy tvar s diakritikou
    'Horna skrinka 450',
    'Horná skrinka 1200',
    'HORNÁ SKRINKA 600',    # velkost pismen nerozhoduje
    'spodná skrinka 600',
    '  Spodná   skrinka 600  ' # okrajove/viacnasobne medzery
  ].each do |n|
    NxTest.assert(CB100.auto_name?(n), "„#{n}“ ma byt rozpoznane ako automaticky nazov")
  end

  [
    'Chladničková',
    'Spodná skrinka pri okne',
    'Spodná skrinka',        # bez cisla to uz nie je automaticky tvar
    'Skrinka 600',
    'Spodná skrinka 600 A',
    'Rohová 900'
  ].each do |n|
    NxTest.refute(CB100.auto_name?(n), "„#{n}“ je RUCNY nazov — nesmie sa zahodit")
  end
end

NxTest.test('D-100: sanitize_name — trim, dlzka, prazdne a automaticke = nil') do
  NxTest.assert_equal('Chladničková', CB100.sanitize_name('  Chladničková  '))
  NxTest.assert_equal('Skrinka pri okne', CB100.sanitize_name("Skrinka\t pri   okne"))
  NxTest.assert_equal(nil, CB100.sanitize_name(''))
  NxTest.assert_equal(nil, CB100.sanitize_name('   '))
  NxTest.assert_equal(nil, CB100.sanitize_name(nil))
  NxTest.assert_equal(nil, CB100.sanitize_name('Spodná skrinka 600'),
                      'rucne napisany automaticky tvar = ziadny vlastny nazov (nazov ostane zivy)')
  long = 'A' * 200
  NxTest.assert_equal(80, CB100.sanitize_name(long).length, 'nazov sa oreze na NAME_MAX_LEN')
end

# ---------------------------------------------------------------------------
# display_name — zivy default vs rucny nazov, oba tvary klucov
# ---------------------------------------------------------------------------

NxTest.test('D-100: display_name pocita default zo SUCASNYCH parametrov') do
  NxTest.assert_equal('Spodná skrinka 900', CB100.display_name('type' => 'lower', 'width' => 900.0))
  NxTest.assert_equal('Horná skrinka 450', CB100.display_name('type' => 'upper', 'width' => 450.0))
  # Codex audit BLOCKER 3: helper sa vola aj nad Store.config (stringy) aj nad
  # normalize (symboly) — obe cesty musia dat ten isty vysledok.
  NxTest.assert_equal('Spodná skrinka 900', CB100.display_name(type: 'lower', width: 900.0))
  NxTest.assert_equal('Horná skrinka 450', CB100.display_name(type: 'upper', width: 450.0))
  # nekruhle sirky sa zaokruhluju
  NxTest.assert_equal('Spodná skrinka 601', CB100.display_name('type' => 'lower', 'width' => 600.6))
end

NxTest.test('D-100: zapeceny stary nazov ozije, rucny nazov sa nedotkne') do
  stale = { 'type' => 'lower', 'width' => 900.0, 'name' => 'Spodna skrinka 700' }
  NxTest.assert_equal('Spodná skrinka 900', CB100.display_name(stale),
                      'skrinka s dnes zapecenym defaultom sa opravi sama')
  NxTest.assert_equal(nil, CB100.manual_name(stale))

  manual = { 'type' => 'lower', 'width' => 900.0, 'name' => 'Chladničková' }
  NxTest.assert_equal('Chladničková', CB100.display_name(manual))
  NxTest.assert_equal('Chladničková', CB100.manual_name(manual))
end

# ---------------------------------------------------------------------------
# config: automaticky nazov sa NEUKLADA
# ---------------------------------------------------------------------------

NxTest.test('D-100: cabinet_config neuklada dopocitany default') do
  cfg = CB100.normalize({})
  c = CB100.cabinet_config(cfg)
  NxTest.assert_equal(nil, c[:name], 'bez rucneho nazvu sa do configu neuklada nic')
  NxTest.assert_equal('Spodná skrinka 600', CB100.display_name(c))

  named = CB100.cabinet_config(CB100.normalize('name' => 'Chladničková'))
  NxTest.assert_equal('Chladničková', named[:name])
  NxTest.assert_equal('Chladničková', CB100.display_name(named))
end

NxTest.test('D-100: normalize ocisti nazov (stary default -> nil)') do
  NxTest.assert_equal(nil, CB100.normalize('name' => 'Spodna skrinka 600')[:name])
  NxTest.assert_equal(nil, CB100.normalize('name' => '   ')[:name])
  NxTest.assert_equal('Pod drezom', CB100.normalize('name' => ' Pod drezom ')[:name])
  NxTest.assert_equal('Pod drezom', CB100.normalize(name: 'Pod drezom')[:name])
end

NxTest.test('D-100: zmena sirky opravi nazov, rucny nazov prezije round-trip') do
  # zivy default: config -> params -> config po zmene sirky
  cfg = CB100.cabinet_config(CB100.normalize('width' => 700.0))
  json = JSON.parse(JSON.generate(cfg))
  NxTest.assert_equal('Spodná skrinka 700', CB100.display_name(json))
  params = CB100.config_to_params(json)
  params['width'] = 900.0
  after = CB100.cabinet_config(CB100.normalize(params))
  NxTest.assert_equal(nil, after[:name])
  NxTest.assert_equal('Spodná skrinka 900', CB100.display_name(after),
                      'nazov musi nasledovat sirku (D-100 nalez Michala)')

  # rucny nazov: sirka sa meni, nazov NIE
  cfg2 = CB100.cabinet_config(CB100.normalize('width' => 700.0, 'name' => 'Chladničková'))
  p2 = CB100.config_to_params(JSON.parse(JSON.generate(cfg2)))
  p2['width'] = 900.0
  after2 = CB100.cabinet_config(CB100.normalize(p2))
  NxTest.assert_equal('Chladničková', after2[:name])
  NxTest.assert_equal('Chladničková', CB100.display_name(after2))
end

NxTest.test('D-100: stary zapeceny nazov sa pri prestavbe z configu odstrani') do
  legacy = { 'type' => 'lower', 'width' => 900.0, 'name' => 'Spodna skrinka 700',
             'part_overrides' => {} }
  params = CB100.config_to_params(legacy)
  NxTest.assert_equal('Spodna skrinka 700', params['name'],
                      'config_to_params nesie SUROVY nazov (vstup prestavby)')
  rebuilt = CB100.cabinet_config(CB100.normalize(params))
  NxTest.assert_equal(nil, rebuilt[:name], 'prestavba zapeceny default zahodi')
  NxTest.assert_equal('Spodná skrinka 900', CB100.display_name(rebuilt))
end

# ---------------------------------------------------------------------------
# sablony — nazov nie je sucastou sablony
# ---------------------------------------------------------------------------

NxTest.test('D-100: sablona nenesie nazov skrinky (round-trip)') do
  # sablony sa ukladaju cez Panel.template_config_from; headless testujeme
  # kontrakt na urovni configu: v predvolenych sablonach ziadny 'name' nie je
  # a aplikacia sablony (merge do params) ho preto nemoze prepisat.
  Noxun::Engine::TemplateStore.build_predefined.each do |t|
    NxTest.refute(t['config'].key?('name'),
                  "sablona „#{t['name']}“ nesmie niest nazov skrinky")
  end

  stored = JSON.parse(JSON.generate(CB100.cabinet_config(CB100.normalize('name' => 'Chladničková'))))
  target = CB100.config_to_params(stored)
  merged = target.merge(Noxun::Engine::TemplateStore.build_predefined.first['config'])
  NxTest.assert_equal('Chladničková', CB100.normalize(merged)[:name],
                      'pouzitie sablony nesmie zmazat rucny nazov skrinky')
end

# ---------------------------------------------------------------------------
# guard nad zdrojakom callbacku (zavery Codex auditu nesmu ticho vypadnut)
# ---------------------------------------------------------------------------

NxTest.test('D-100 guard: callback premenovania je registrovany a drzi zavery auditu') do
  panel = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'), encoding: 'UTF-8')
  NxTest.assert(panel.include?("cb(dlg, 'rename_cabinet')"),
                'callback rename_cabinet musi byt registrovany v panel.rb')

  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_rename_cabinet.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'handle_rename_cabinet sa nenasiel')
  NxTest.assert(body.include?('CabinetBuilder.guarded'),
                'BLOCKER 1: zapis nazvu musi bezat pod ScaleWatch guardom (inak observer presunie ghost zony ' \
                'vo vlastnej operacii a premenovanie prestane byt 1 undo krok)')
  NxTest.assert(body.include?('start_operation'), 'zapis musi byt vlastna undo operacia')
  NxTest.refute(body.include?('push_selected(model)'),
                'BLOCKER 2: refresh po premenovani musi ist s dedup: false (inak moze prestavat cudziu duplicitnu skrinku)')
  NxTest.assert(body.scan('push_selected(model, dedup: false)').size >= 2,
                'BLOCKER 2: vsetky refreshe v premenovani su bez dedupu')
  NxTest.assert(body.include?('echo.empty? || echo != cid'),
                'FIX 6: prazdne ANI nezhodne cabinet_id nesmie nic zapisat')
end
