# frozen_string_literal: true
# UI-C1c — ORIENTACIA DOSKY: slovnik + guard v BoardBuilderi, config tvar,
# NEDOTKNUTELNOST vyrobnych dat a STUPNOVANA migracia sablon std 2 -> 3.
#
# Matice a geometria sa headless overit NEDAJU (Geom::Transformation je
# SketchUp API) — su v in-SketchUp sekcii `run_uic1c` (tests/sketchup/su_runner.rb).
# Tu zije to, co je cista logika:
#
# Kontrakty z Codex auditu C1c:
#   BLOCKER 2 — migracia je STUPNOVANA podla STAREHO markera (seed len old_std<2,
#               orientation fill len old_std<3), jeden zapis pod jednym zamkom
#   FIX 5     — fill dostane kontraktovu orientaciu LEN pri zhode MENA aj
#               ODTLACKU seedu std 2; vsetko ostatne 'leziaca'
#   FIX 6/7   — pole zije v `config['orientation']`; chyba/prazdne => 'leziaca',
#               EXPLICITNA neznama => ODMIETNUTIE (ziadna ticha preklasifikacia)
#   NOTE 10   — orientacia NIKDY nevstupi do deskriptora (prod/axes), agregacneho
#               kluca kusovnika ani do AbsRules.edge_sides
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxC1c
  BB = Noxun::Engine::BoardBuilder
  TS = Noxun::Engine::TemplateStore
  JFS = Noxun::Engine::JsonFileStore

  module_function

  def reset!
    [TS.path, Noxun::Engine::TemplateUsage.path].each do |p|
      FileUtils.rm_f(p)
      FileUtils.rm_f("#{p}.bak")
      JFS.invalidate(p)
    end
  end

  def write_raw!(payload)
    FileUtils.mkdir_p(TS.dir)
    File.binwrite(TS.path, JSON.generate(payload))
    FileUtils.rm_f("#{TS.path}.bak")
    JFS.invalidate(TS.path)
  end

  def raw
    JSON.parse(File.binread(TS.path))
  end

  # PRESNY tvar doskoveho zaznamu, ako ho zapisal seed std 2 (bez orientacie).
  def seed_std2(name, thickness, length, width, extra = {})
    { 'name' => name, 'kind' => 'board',
      'config' => { 'material_id' => nil, 'length' => length, 'width' => width,
                    'thickness' => thickness, 'grain_direction' => 'length',
                    'type' => 'board' }.merge(extra) }
  end

  def std2_payload(templates)
    { 'std' => 2, 'templates' => templates }
  end

  def board_orientation(name)
    rec = TS.find('board', name)
    rec && rec['config']['orientation']
  end

  # Minimalny platny config dosky (bez materialu — normalize material nevaliduje).
  def params(extra = {})
    { 'length' => 800.0, 'width' => 600.0, 'thickness' => 18.0 }.merge(extra)
  end
end

# ---------------------------------------------------------------------------
# slovnik + guard (FIX 6/7) — JEDINA autorita je BoardBuilder.normalize
# ---------------------------------------------------------------------------

NxTest.test('UI-C1c slovnik: tri hodnoty, default leziaca, popisky pre kazdu') do
  NxTest.assert_equal(%w[leziaca stojaca na_stenu], NxC1c::BB::ORIENTATIONS)
  NxTest.assert_equal('leziaca', NxC1c::BB::DEFAULT_ORIENTATION)
  NxC1c::BB::ORIENTATIONS.each do |o|
    NxTest.assert(!NxC1c::BB::ORIENTATION_LABELS[o].to_s.empty?, "#{o}: chyba slovensky popisok")
  end
end

NxTest.test('UI-C1c guard: chybajuca aj prazdna orientacia = leziaca (dosky pred UI-C1c)') do
  NxTest.assert_equal('leziaca', NxC1c::BB.normalize(NxC1c.params)[:orientation])
  NxTest.assert_equal('leziaca', NxC1c::BB.normalize(NxC1c.params('orientation' => ''))[:orientation])
  NxTest.assert_equal('leziaca', NxC1c::BB.normalize(NxC1c.params('orientation' => '  '))[:orientation])
  NxTest.assert_equal('leziaca', NxC1c::BB.normalize(NxC1c.params('orientation' => nil))[:orientation])
end

NxTest.test('UI-C1c guard: platne hodnoty prejdu (string aj symbol kluc)') do
  NxTest.assert_equal('stojaca', NxC1c::BB.normalize(NxC1c.params('orientation' => 'stojaca'))[:orientation])
  NxTest.assert_equal('na_stenu', NxC1c::BB.normalize(orientation: 'na_stenu')[:orientation])
end

NxTest.test('UI-C1c guard: EXPLICITNA neznama orientacia sa ODMIETNE (ziadna tichá preklasifikacia)') do
  %w[lezaca LEZIACA vertical na-stenu 1].each do |bad|
    raised = false
    begin
      NxC1c::BB.normalize(NxC1c.params('orientation' => bad))
    rescue StandardError => e
      raised = e.message.include?(bad)
    end
    NxTest.assert(raised, "#{bad}: normalize mala vyhodit vynimku s hodnotou v hlaske")
  end
end

NxTest.test('UI-C1c: stored_orientation cita config (chybajuca = leziaca, NEZNAMU NEOPRAVUJE)') do
  NxTest.assert_equal('leziaca', NxC1c::BB.stored_orientation({}))
  NxTest.assert_equal('leziaca', NxC1c::BB.stored_orientation('orientation' => ''))
  NxTest.assert_equal('stojaca', NxC1c::BB.stored_orientation('orientation' => 'stojaca'))
  # Config z novsej verzie: hodnota sa VRATI TAK, AKO JE — volajuci ju odmietne.
  NxTest.assert_equal('zavesena', NxC1c::BB.stored_orientation('orientation' => 'zavesena'))
end

# ---------------------------------------------------------------------------
# config tvar + NEDOTKNUTELNOST vyrobnych dat (NOTE 10)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1c config: orientacia je v configu dosky (round-trip cez normalize)') do
  cfg = NxC1c::BB.board_config(NxC1c::BB.normalize(NxC1c.params('orientation' => 'na_stenu')))
  NxTest.assert_equal('na_stenu', cfg[:orientation])
  # Round-trip: ulozeny config -> params -> normalize drzi hodnotu.
  stored = JSON.parse(JSON.generate(cfg))
  again = NxC1c::BB.normalize(NxC1c::BB.config_to_params(stored))
  NxTest.assert_equal('na_stenu', again[:orientation])
end

NxTest.test('UI-C1c: DESKRIPTOR orientaciu NENESIE — osi ostavaju lezaice pre kazdu hodnotu') do
  NxC1c::BB::ORIENTATIONS.each do |o|
    cfg = NxC1c::BB.normalize(NxC1c.params('orientation' => o, 'material_id' => 'K009_PW_DTDL_18'))
    pd = NxC1c::BB.descriptor(cfg)
    NxTest.refute(pd.key?(:orientation), "#{o}: orientacia sa dostala do deskriptora")
    NxTest.assert_equal(Noxun::Engine::PartFaces::AXES_LYING, pd[:axes], "#{o}: osi deskriptora")
    NxTest.assert_equal([800.0, 600.0, 18.0], pd[:box], "#{o}: kvader deskriptora")
    NxTest.assert_equal({ length: 800.0, width: 600.0, thickness: 18.0 }, pd[:prod], "#{o}: vyrobne rozmery")
  end
end

NxTest.test('UI-C1c: KUSOVNIK orientaciu ignoruje — zaznam je pre vsetky tri zhodny') do
  base = NxC1c::BB.board_config(NxC1c::BB.normalize(
                                  NxC1c.params('orientation' => 'leziaca',
                                               'material_id' => 'K009_PW_DTDL_18')
                                ))
  ref = Noxun::Engine::Bom.record(JSON.parse(JSON.generate(base)),
                                  owner_id: 'BRD-001', name: 'D', part_key: 'board/main',
                                  role: 'free_panel')
  %w[stojaca na_stenu].each do |o|
    cfg = NxC1c::BB.board_config(NxC1c::BB.normalize(
                                   NxC1c.params('orientation' => o,
                                                'material_id' => 'K009_PW_DTDL_18')
                                 ))
    rec = Noxun::Engine::Bom.record(JSON.parse(JSON.generate(cfg)),
                                    owner_id: 'BRD-001', name: 'D', part_key: 'board/main',
                                    role: 'free_panel')
    NxTest.assert_equal(ref, rec, "#{o}: kusovnikovy zaznam sa zmenil orientaciou")
  end
end

NxTest.test('UI-C1c: ABS mapa hran (edge_sides/edge_labels) je na orientacii NEZAVISLA') do
  # AbsRules pozna VYHRADNE rolu — orientacia sa k nemu nemá ako dostat.
  NxTest.assert_equal(1, NxC1c::BB::ROLES.size, 'doska ma stale jedinu rolu')
  sides = Noxun::Engine::AbsRules.edge_sides('free_panel')
  NxTest.assert_equal(%w[L1 L2 W1 W2].sort, sides.keys.sort, 'mapa stran ostava kompletna')
  NxTest.assert_equal(sides, Noxun::Engine::AbsRules.edge_sides('free_panel'), 'mapa je stabilna')
end

# ---------------------------------------------------------------------------
# panel payload karty dosky
# ---------------------------------------------------------------------------

NxTest.test('UI-C1c payload: karta dostane orientaciu aj jej popisok') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  inst = NxTest::FakeInstance.new(1)
  cfg = NxC1c::BB.board_config(NxC1c::BB.normalize(
                                 NxC1c.params('orientation' => 'stojaca',
                                              'material_id' => 'K009_PW_DTDL_18')
                               ))
  Noxun::Engine::Store.write(inst, { std: Noxun::Engine::Store::STD, kind: 'board', id: 'BRD-001',
                                     role: 'free_panel', name: 'D', config: cfg })
  pay = Noxun::Engine::Panel.board_payload(inst)
  NxTest.assert_equal('stojaca', pay['orientation'])
  NxTest.assert_equal('Nastojato', pay['orientation_label'])
end

NxTest.test('UI-C1c payload: doska BEZ orientacie (pred UI-C1c) sa hlasi ako leziaca') do
  NxTest.skip!('payload testy potrebuju Store fake') unless NxTest.headless?
  inst = NxTest::FakeInstance.new(2)
  Noxun::Engine::Store.write(inst, { std: Noxun::Engine::Store::STD, kind: 'board', id: 'BRD-002',
                                     role: 'free_panel', name: 'D',
                                     config: { 'length' => 800.0, 'width' => 600.0,
                                               'thickness' => 18.0, 'edges' => {} } })
  pay = Noxun::Engine::Panel.board_payload(inst)
  NxTest.assert_equal('leziaca', pay['orientation'])
end

# ---------------------------------------------------------------------------
# seed std 3 — kontraktove hodnoty
# ---------------------------------------------------------------------------

NxTest.test('UI-C1c seed: Diel stoji, Pracovna doska lezi, Zastena ide na stenu') do
  want = { 'Diel' => 'stojaca', 'Pracovná doska' => 'leziaca', 'Zástena' => 'na_stenu' }
  NxC1c::TS.build_predefined_boards.each do |t|
    o = t['config']['orientation']
    NxTest.assert_equal(want[t['name']], o, "#{t['name']}: kontraktova orientacia seedu")
    NxTest.assert(NxC1c::BB::ORIENTATIONS.include?(o), "#{t['name']}: hodnota mimo slovnika BoardBuilder")
  end
end

# GHOST-D1: marker suboru sa posunul na 4 (doskove sablony nesu
# `config['config_schema']`). Krok 2 -> 3 (orientacia) je tym NEDOTKNUTY —
# migracia je stupnovana, takze scenare nizsie startuju zo std 2 aj zo std 1.
NxTest.test('UI-C1c/GHOST-D1: marker suboru sablon je 4 a krok orientacie ostava') do
  NxTest.assert_equal(4, NxC1c::TS::STD)
  NxTest.assert(NxC1c::TS.respond_to?(:fill_orientations), 'krok 2 -> 3 existuje')
  NxTest.assert(NxC1c::TS.respond_to?(:fill_board_schema), 'krok 3 -> 4 existuje')
end

# ---------------------------------------------------------------------------
# STUPNOVANA migracia (BLOCKER 2) + orientation fill (FIX 5)
# ---------------------------------------------------------------------------

NxTest.test('UI-C1c migracia 2->3: cisty seed std 2 dostane KONTRAKTOVE hodnoty') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  NxC1c.write_raw!(NxC1c.std2_payload([
                                        NxC1c.seed_std2('Diel', 18.0, 800.0, 600.0),
                                        NxC1c.seed_std2('Pracovná doska', 38.0, 2600.0, 600.0),
                                        NxC1c.seed_std2('Zástena', 10.0, 2600.0, 580.0)
                                      ]))
  NxC1c::TS.load
  NxTest.assert_equal(NxC1c::TS::STD, NxC1c.raw['std'], 'marker posunuty na aktualny')
  NxTest.assert_equal('stojaca', NxC1c.board_orientation('Diel'))
  NxTest.assert_equal('leziaca', NxC1c.board_orientation('Pracovná doska'))
  NxTest.assert_equal('na_stenu', NxC1c.board_orientation('Zástena'))
end

NxTest.test('UI-C1c migracia 2->3: ZMAZANY seed sa NEVRATI (seed patri prechodu 1->2)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  # Pouzivatel si na std 2 zmazal „Zástena"; migracia 2->3 ju NESMIE doseje.
  NxC1c.write_raw!(NxC1c.std2_payload([NxC1c.seed_std2('Diel', 18.0, 800.0, 600.0)]))
  list = NxC1c::TS.load
  boards = list.select { |t| t['kind'] == 'board' }.map { |t| t['name'] }
  NxTest.assert_equal(['Diel'], boards, 'orientation fill nesmie dosievat zaznamy')
end

NxTest.test('UI-C1c migracia 2->3: PREMENOVANY seed dostane leziaca (vedome obmedzenie)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  # Rozmery su presne Zastena, ale meno je vlastne — zhoda musi byt v OBOCH.
  NxC1c.write_raw!(NxC1c.std2_payload([NxC1c.seed_std2('Moja zástena', 10.0, 2600.0, 580.0)]))
  NxC1c::TS.load
  NxTest.assert_equal('leziaca', NxC1c.board_orientation('Moja zástena'))
end

NxTest.test('UI-C1c migracia 2->3: UPRAVENY rovnomenny zaznam dostane leziaca (odtlacok nesedi)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  NxC1c.write_raw!(NxC1c.std2_payload([
                                        NxC1c.seed_std2('Zástena', 10.0, 3000.0, 580.0), # ina dlzka
                                        NxC1c.seed_std2('Diel', 18.0, 800.0, 600.0,
                                                        'material_id' => 'K009_PW_DTDL_18') # ma material
                                      ]))
  NxC1c::TS.load
  NxTest.assert_equal('leziaca', NxC1c.board_orientation('Zástena'), 'zmeneny rozmer = nie je to seed')
  NxTest.assert_equal('leziaca', NxC1c.board_orientation('Diel'), 'doplneny material = nie je to seed')
end

NxTest.test('UI-C1c migracia 2->3: EXPLICITNA orientacia (aj neznama) ostava NEDOTKNUTA') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  NxC1c.write_raw!(NxC1c.std2_payload([
                                        NxC1c.seed_std2('Diel', 18.0, 800.0, 600.0, 'orientation' => 'leziaca'),
                                        NxC1c.seed_std2('Zástena', 10.0, 2600.0, 580.0, 'orientation' => 'zavesena')
                                      ]))
  NxC1c::TS.load
  NxTest.assert_equal('leziaca', NxC1c.board_orientation('Diel'), 'vedoma volba pouzivatela ostava')
  NxTest.assert_equal('zavesena', NxC1c.board_orientation('Zástena'), 'hodnota z novsej verzie ostava')
end

NxTest.test('UI-C1c migracia 2->3: KORPUSOVYCH sablon sa netyka') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  NxC1c.write_raw!(NxC1c.std2_payload([{ 'name' => 'Dolna klasik', 'kind' => 'cabinet',
                                         'config' => { 'type' => 'lower', 'width' => 600.0 } }]))
  NxC1c::TS.load
  cab = NxC1c::TS.find('cabinet', 'Dolna klasik')
  NxTest.refute(cab['config'].key?('orientation'), 'korpusova sablona orientaciu nedostava')
end

NxTest.test('UI-C1c migracia 1->3: seed AJ orientacia JEDNYM zapisom (ziadny medzistav)') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  NxC1c.write_raw!({ 'std' => 1,
                     'templates' => [{ 'name' => 'Stara dolna', 'config' => { 'type' => 'lower' } }] })
  NxC1c::TS.load
  raw = NxC1c.raw
  NxTest.assert_equal(NxC1c::TS::STD, raw['std'])
  NxTest.assert_equal(%w[leziaca na_stenu stojaca],
                      raw['templates'].select { |t| t['kind'] == 'board' }
                          .map { |t| t['config']['orientation'] }.sort)
  # Druhy load uz NEZAPISUJE (marker je aktualny) — dokaz jedneho zapisu.
  before = File.binread(NxC1c::TS.path)
  NxC1c::TS.load
  NxTest.assert_equal(before, File.binread(NxC1c::TS.path), 'load nad aktualnym markerom nezapisuje')
end

NxTest.test('UI-C1c forward guard: subor z NOVSEJ verzie je LEN NA CITANIE a ostane byte-nezmeneny') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?
  NxC1c.reset!
  NxC1c.write_raw!({ 'std' => NxC1c::TS::STD + 1,
                     'templates' => [NxC1c.seed_std2('Diel', 18.0, 800.0, 600.0)] })
  before = File.binread(NxC1c::TS.path)
  NxC1c::TS.load
  NxTest.assert_equal(false,
                      NxC1c::TS.upsert('board', 'Nova', 'length' => 100.0,
                                       'config_schema' => NxC1c::BB::BOARD_CONFIG_SCHEMA),
                      'upsert odmietnuty')
  NxTest.assert_equal(before, File.binread(NxC1c::TS.path), 'novsi subor sa NEPREPISUJE')
  NxTest.assert_equal(nil, NxC1c.board_orientation('Diel'), 'ani orientacia sa nedoplnila')
end
