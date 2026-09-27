# frozen_string_literal: true
# KON-D — VSTAVANA SABLONA „Chladničková" (blok 7 KONŠTRUKCIA, posledna davka).
# Package: SYSTEM/archiv/bloky/KONSTRUKCIA/PACKAGE_KOND_CHLADNICKOVA.md.
#
# CO PLATI:
#   * seed „Chladničková": dolna 600 x 2100 x 560, sokel 100, komin 50, BEZ
#     chrbta, zapustenie 0 a vyska list 100 VYSLOVNE, ocakava chladnicku,
#     dvoje dvierka F1 719 fixed + F2 auto so smerom „neurceny",
#     `config_schema` = aktualna CONFIG_SCHEMA;
#   * kniznica `STD` 6 -> 7: jednorazovy krok migracie seed prida, vlastnu
#     rovnomennu sablonu NEPREPISE, zmazany seed NEOBNOVI; seed NIE JE
#     v `build_predefined` (nudzova nahrada);
#   * migracia NIKDY nezapisuje nad POSKODENYM primarom (audit BLOCKER 1) —
#     nie je JSON alebo zly tvar = ziadny zapis (ani zo `.bak`, ani nudzove
#     predvolby); CHYBAJUCI primar s platnou zalohou sa obnovi + seed (ako
#     `JsonFileStore.degraded?` — predrecenzia P3);
#   * suhrn konstrukcie na dlazdici z UCINNYCH hodnot (oba payloady) + veta
#     o vetrani pri sablone, ktora ocakava chladnicku.
#
# MUTACIE, ktore tato sada chyta (overene rucne pri davke, report/PR):
#   M1 seed bez `config_schema`                    -> „seed: obsah"
#   M2 migracia prepise vlastnu rovnomennu sablonu -> „migracia: vlastna Chladničková"
#   M3 seed v `build_predefined`                   -> „nudzova nahrada seed NEMA"
#   M4 chyba vyslovne `top_front_setback 0`        -> „seed: obsah" + „pouzitie na skrinku so zapustenim"
#   M5 migracia zapise nad zalohou                 -> „zdravie primara: poskodeny primar + zaloha"
#   M6 suhrn „z líšt" aj pri inom chrbte           -> „suhrn: ucinne hodnoty" + „SKUTOCNE payloady"
#   M7 dvierka seedu bez smeru (legacy)            -> „dvoje dvierka" + „Kontrola ho hlasi"
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet actions_templates payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
end
require_relative 'test_s1f_chladnicka'

module NxKonD
  module_function

  E   = Noxun::Engine
  TS  = E::TemplateStore
  JFS = E::JsonFileStore
  CB  = E::CabinetBuilder
  CN  = E::Construction
  AC  = E::ApplianceChecks
  NAME = 'Chladničková'

  def seed
    TS.build_predefined_fridge.first
  end

  def cfg
    seed['config']
  end

  # Config tak, ako ho zapise STAVBA (normalize -> plan -> cabinet_config -> JSON).
  def built(params)
    norm = CB.normalize(params)
    plan = CN.build_plan(norm, 'CAB-001')
    [plan, JSON.parse(JSON.generate(CB.cabinet_config(CB.merge_final(norm, plan))))]
  end

  def part(plan, key)
    plan[:parts].find { |pd| pd[:part_key] == key }
  end

  def reset!
    FileUtils.rm_f(TS.path)
    FileUtils.rm_f("#{TS.path}.bak")
    JFS.invalidate(TS.path)
  end

  def write!(payload, path = TS.path)
    FileUtils.mkdir_p(TS.dir)
    File.binwrite(path, payload.is_a?(String) ? payload : JSON.generate(payload))
    JFS.invalidate(TS.path)
  end

  # Kniznica, ako ju zanechal plugin so STD 6 (v0.13.3): vsetky seedy okrem
  # Chladničkovej.
  def std6_payload(extra = [])
    list = TS.build_predefined + TS.build_predefined_slots + TS.build_predefined_boards + extra
    JSON.parse(JSON.generate('std' => 6, 'templates' => list))
  end

  def names(list, kind = 'cabinet')
    list.select { |t| t['kind'] == kind }.map { |t| t['name'] }
  end

  # Simulacia STARSIEHO pluginu: docasne ina hodnota konstanty.
  def with_const(mod, name, value)
    old = mod.const_get(name)
    mod.send(:remove_const, name)
    mod.const_set(name, value)
    yield
  ensure
    mod.send(:remove_const, name)
    mod.const_set(name, old)
  end
end

# ============================================================================
# 1. SEED — obsah
# ============================================================================

NxTest.test('KON-D seed: obsah — rozmery, komin, bez chrbta, vyslovne predvolby, schema, ocakavanie') do
  s = NxKonD.seed
  c = NxKonD.cfg
  NxTest.assert_equal(['Chladničková', 'cabinet'], [s['name'], s['kind']], 'meno s diakritikou, korpusovy druh')
  want = { 'type' => 'lower', 'width' => 600.0, 'height' => 2100.0, 'depth' => 560.0, 'thickness' => 18.0,
           'floor_height' => 100.0, 'bottom_mode' => 'under_sides', 'top_mode' => 'full',
           'back_mode' => 'none', 'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 40.0,
           'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
           'back_setback' => 50.0, 'top_front_setback' => 0.0, 'back_rail_height' => 100.0,
           'appliance_expects' => ['fridge'] }
  want.each { |k, v| NxTest.assert_equal(v, c[k], "seed: #{k}") }
  NxTest.assert(c.key?('top_front_setback') && c.key?('back_rail_height'),
                'predvolby KON-A/KON-B su VYSLOVNE (inak by sablona hodnotu ciela zachovala)')
  NxTest.assert_equal(NxKonD::CB::CONFIG_SCHEMA, c['config_schema'], 'seed nesie AKTUALNU schemu (R-12)')
  NxTest.assert_equal(21, c['config_schema'], 'po KON-B 21')
  NxTest.assert_equal(0, c['zone_tree']['shelves'].to_i, 'bez polic')
end

NxTest.test('KON-D seed: dvoje dvierka nad sebou — F1 fixed 719 zamknute, F2 auto, smer VYSLOVNE neurceny') do
  items = NxKonD.cfg['fronts']['items']
  NxTest.assert_equal(%w[F1 F2], items.map { |i| i['id'] }, 'F1 dolne (cela sa kladu odspodu), F2 horne')
  NxTest.assert_equal(%w[door door], items.map { |i| i['type'] })
  NxTest.assert_equal(['fixed', 719.0, true], items[0].values_at('mode', 'height', 'locked'))
  NxTest.assert_equal(['auto', nil, false], items[1].values_at('mode', 'height', 'locked'))
  NxTest.assert_equal(%w[auto auto], items.map { |i| i['wings'] })
  NxTest.assert_equal(%w[unset unset], items.map { |i| i['direction'] },
                      'smer neurceny — stranu pantov si stolar zvoli (audit FIX 2), nikdy sa nehada')
  norm = Noxun::Engine::Fronts.normalize_config(NxKonD.cfg['fronts'])
  NxTest.assert_equal(%w[unset unset], norm['items'].map { |i| i['direction'] }, 'normalizacia smer zachova')
end

# ============================================================================
# 2. STAVBA ZO SEEDU
# ============================================================================

NxTest.test('KON-D stavba: dno a strop 510, boky 560, ziadny chrbat, vnutro 510, nika 560, 2 fyzicke dvierka') do
  plan, st = NxKonD.built(NxKonD.cfg)
  side = NxKonD.part(plan, 'cabinet/side:left')[:prod]
  bot = NxKonD.part(plan, 'cabinet/bottom')[:prod]
  top = NxKonD.part(plan, 'cabinet/top')[:prod]
  NxTest.assert_equal([1982.0, 560.0], [side[:length], side[:width]], 'bok 2100 − sokel 100 − dno 18, plna hlbka 560')
  NxTest.assert_equal([600.0, 510.0], [bot[:length], bot[:width]], 'dno pod bokmi 600 x 510 (komin 50)')
  NxTest.assert_equal([564.0, 510.0], [top[:length], top[:width]], 'strop 564 x 510')
  NxTest.assert_equal(nil, NxKonD.part(plan, 'cabinet/back'), 'bez chrbta')
  NxTest.assert_equal([], plan[:parts].map { |pd| pd[:part_key] }.grep(/back_rail/), 'ani listy')
  NxTest.assert_close(510.0, st['available_depth'], 0.01, 'vnutro po zadnu hranu dna')
  NxTest.assert_equal(560.0, NxKonD::AC.context(st)['interior']['depth'], 'nika pri komine z hlbky BOKU (M9)')
  NxTest.assert_equal(560.0, Noxun::Engine::Panel.appliance_interior(st)['depth'], 'ponuka „zmesti sa" tiez 560')
  NxTest.assert_equal({ 'width' => 564.0, 'height' => 1964.0, 'depth' => 560.0 }, NxKonD::AC.context(st)['interior'])
  doors = plan[:parts].select { |pd| pd[:role].to_s == 'front_door' }
  NxTest.assert_equal(%w[front:F1/wing:single front:F2/wing:single], doors.map { |pd| pd[:part_key] },
                      '2 FYZICKE dvierka (sirka 600 = 1 kridlo; bez zamkov vkladania)')
  NxTest.assert_equal([719.0, 1274.0], doors.map { |pd| pd[:prod][:length] }, '719 + 1274 (2000 − 2 − 2 − 3 − 719)')
  NxTest.assert_equal(NxKonD::CB::CONFIG_SCHEMA, st['config_schema'])
  NxTest.assert_equal(['fridge'], st['appliance_expects'], 'vlozena skrinka ocakava chladnicku')
end

NxTest.test('KON-D stavba: neurceny smer prezije stavbu a Kontrola ho hlasi pri OBOCH dvierkach') do
  _plan, st = NxKonD.built(NxKonD.cfg)
  NxTest.assert_equal(%w[unset unset], st['front_items'].map { |i| i['direction'] })
  iss = Noxun::Engine::Bom.front_direction_issues('CAB-1', 101, st['front_items'])
  NxTest.assert_equal(%w[front:F1/wing:single front:F2/wing:single], iss.map { |i| i['part_key'] },
                      'Kontrola vyzve zvolit stranu pantov (nie vynimka starych dat)')
  NxTest.assert(iss.all? { |i| i['code'] == 'front_direction_unset' })
end

NxTest.test('KON-D osadenie 0/14/24/24,25/25 — verdikt vysky niky aj delenia ciel (audit FIX 3)') do
  _plan, st = NxKonD.built(NxKonD.cfg)
  # [osadenie, vyska niky, stav delenia, hrana od dna niky]
  [[0.0, 'clash', 'ok', 703.0], [14.0, 'ok', 'ok', 689.0], [24.0, 'ok', 'ok', 679.0],
   [24.25, 'ok', 'clash', 678.75], [25.0, 'clash', 'clash', 678.0]].each do |m, h, split, edge|
    ref = NxS1F.ref('I-1', m.zero? ? {} : { 'mount_offset' => m })
    rec = NxS1F.record(st.merge('appliance_refs' => [ref]))
    v = NxKonD::AC.niche_verdict(rec)
    s = NxKonD::AC.door_split_verdict(rec)
    NxTest.assert_equal(%w[ok ok], v['axes'].values_at('width', 'depth'), "osadenie #{m}: sirka 564, hlbka 560 sedia")
    NxTest.assert_equal(h, v['axes']['height'], "osadenie #{m}: vyska niky 1964 − #{m} vs 1940–1950")
    NxTest.assert_equal([split, 'practice', [679.0, 727.0]], s.values_at('state', 'source', 'range'),
                        "osadenie #{m}: delenie ciel")
    NxTest.assert_close(edge, s['edge'], 0.001, "osadenie #{m}: hrana 821 − (118 + osadenie)")
  end
end

# ============================================================================
# 3. KNIZNICA STD 6 -> 7
# ============================================================================

NxTest.test('KON-D kniznica: STD 7, cerstva instalacia 10 sablon (7 korpusovych) s Chladničkovou') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  list = NxKonD::TS.load
  NxTest.assert_equal(7, NxKonD::TS::STD)
  NxTest.assert_equal(10, list.length)
  NxTest.assert_equal(['Dolna klasik', 'Drezova', 'Varna doska', 'Horna klasik', 'Umývačka 60', 'Umývačka 45',
                       'Chladničková'], NxKonD.names(list))
  raw = JSON.parse(File.binread(NxKonD::TS.path))
  NxTest.assert_equal(7, raw['std'])
  NxTest.assert_equal(NxKonD.seed, raw['templates'].find { |t| t['name'] == NxKonD::NAME }, 'seed zapisany presne')
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D kniznica: nudzova nahrada (`build_predefined`) seed NEMA') do
  NxTest.refute(NxKonD::TS.build_predefined.any? { |t| t['name'] == NxKonD::NAME }, 'seed nie je v build_predefined')
  NxTest.assert_equal([NxKonD::NAME], NxKonD::TS.build_predefined_fridge.map { |t| t['name'] })
  NxTest.assert_equal([], NxKonD::TS.missing_fridge_seed(NxKonD::TS.build_predefined_fridge), 'cista funkcia')
end

NxTest.test('KON-D migracia 6 -> 7: seed pridany RAZ na koniec, ostatne zaznamy bajtovo nedotknute') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  mine = { 'name' => 'Moja vysoká', 'kind' => 'cabinet', 'config' => { 'type' => 'lower', 'height' => 2000.0 },
           'buduce_pole' => { 'x' => 1 } }
  before = NxKonD.std6_payload([mine])
  NxKonD.write!(before)
  NxKonD::TS.reload!
  raw = JSON.parse(File.binread(NxKonD::TS.path))
  NxTest.assert_equal(7, raw['std'], 'marker 7')
  NxTest.assert_equal(before['templates'], raw['templates'][0...-1], 'ostatne zaznamy nedotknute (aj nezname kluce)')
  NxTest.assert_equal(NxKonD.seed, raw['templates'].last, 'seed pridany na koniec')
  bytes = File.binread(NxKonD::TS.path)
  2.times { NxKonD::TS.reload! }
  NxTest.assert_equal(bytes, File.binread(NxKonD::TS.path), 'dalsie nacitanie uz nic nezapise')
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D migracia: vlastna Chladničková (korpusova) sa NEPREPISE; doskova rovnomenna seed nezastavi') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  own = { 'name' => NxKonD::NAME, 'kind' => 'cabinet', 'config' => { 'type' => 'lower', 'width' => 650.0 } }
  NxKonD.write!(NxKonD.std6_payload([own]))
  list = NxKonD::TS.reload!
  hits = list.select { |t| t['kind'] == 'cabinet' && t['name'] == NxKonD::NAME }
  NxTest.assert_equal(1, hits.length, 'ziadny duplikat')
  NxTest.assert_equal(own['config'], hits.first['config'], 'vlastna sablona ostala presne taka, aka bola')
  NxTest.assert_equal(7, JSON.parse(File.binread(NxKonD::TS.path))['std'])

  NxKonD.reset!
  board = { 'name' => NxKonD::NAME, 'kind' => 'board',
            'config' => { 'type' => 'board', 'config_schema' => 1, 'orientation' => 'leziaca' } }
  NxKonD.write!(NxKonD.std6_payload([board]))
  list = NxKonD::TS.reload!
  NxTest.assert_equal(1, list.count { |t| t['kind'] == 'cabinet' && t['name'] == NxKonD::NAME },
                      'identita je (kind, meno) — doskova rovnomenna seed nezastavi')
  NxTest.assert_equal(1, list.count { |t| t['kind'] == 'board' && t['name'] == NxKonD::NAME })
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D migracia: ZMAZANY seed sa NEOBNOVI (krok bezi len pri prechode markera)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD::TS.load
  NxTest.assert_equal(true, NxKonD::TS.delete('cabinet', NxKonD::NAME))
  bytes = File.binread(NxKonD::TS.path)
  list = NxKonD::TS.reload!
  NxTest.assert_equal(nil, list.find { |t| t['name'] == NxKonD::NAME }, 'zmazana Chladničková sa nevratila')
  NxTest.assert_equal(bytes, File.binread(NxKonD::TS.path), 'nacitanie STD 7 nic nezapise')
ensure
  NxKonD.reset! if NxTest.headless?
end

# ============================================================================
# 4. ZDRAVIE PRIMARA (audit BLOCKER 1)
# ============================================================================

NxTest.test('KON-D zdravie primara: POSKODENY primar + zaloha STD 6 -> ZIADNY zapis, cita sa zaloha') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  bak = JSON.generate(NxKonD.std6_payload)
  NxKonD.write!(bak, "#{NxKonD::TS.path}.bak")
  NxKonD.write!('{"std": 6, "templates": [ poskodene')
  corrupt = File.binread(NxKonD::TS.path)
  list = NxKonD::TS.reload!
  NxTest.assert_equal(corrupt, File.binread(NxKonD::TS.path), 'poskodeny primar sa NEPREPISAL zalohou')
  NxTest.assert_equal(bak.b, File.binread("#{NxKonD::TS.path}.bak"), 'zaloha nedotknuta')
  NxTest.assert_equal(9, list.length, 'kniznica sa cita zo zalohy (bez seedu)')
  NxTest.assert_equal(nil, list.find { |t| t['name'] == NxKonD::NAME }, 'seed sa nad zalohou NEPRIDAL')
  NxKonD::TS.load
  NxTest.assert_equal(corrupt, File.binread(NxKonD::TS.path), 'ani opakovane nacitanie nezapise')

  # Po oprave primara (zdravy STD 6) migracia prebehne.
  NxKonD.write!(NxKonD.std6_payload)
  list = NxKonD::TS.reload!
  NxTest.assert(list.any? { |t| t['name'] == NxKonD::NAME }, 'nad zdravym primarom seed pribudne')
  NxTest.assert_equal(7, JSON.parse(File.binread(NxKonD::TS.path))['std'])
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D zdravie primara: {std: 6, templates: null} -> ZIADNY zapis (nie nudzove predvolby + seed)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD.write!('{"std": 6, "templates": null}')
  bytes = File.binread(NxKonD::TS.path)
  list = NxKonD::TS.reload!
  NxTest.assert_equal(bytes, File.binread(NxKonD::TS.path), 'subor ostal presne taky, aky bol')
  NxTest.refute(File.exist?("#{NxKonD::TS.path}.bak"), 'ziadny zapis = ani zaloha nevznikla')
  NxTest.assert_equal(NxKonD.names(NxKonD::TS.build_predefined), NxKonD.names(list), 'citanie = nudzove predvolby')
  NxTest.assert_equal(nil, list.find { |t| t['name'] == NxKonD::NAME }, 'nudzova nahrada seed nema')
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D zdravie primara: CHYBAJUCI primar + platna zaloha STD 6 -> obnova zo zalohy + seed (ako JsonFileStore.degraded?)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  bak = NxKonD.std6_payload
  NxKonD.write!(bak, "#{NxKonD::TS.path}.bak")
  NxTest.assert_equal(false, Noxun::Engine::JsonFileStore.degraded?(NxKonD::TS.path), 'chybajuci primar degraded NIE JE')
  list = NxKonD::TS.reload!
  raw = JSON.parse(File.binread(NxKonD::TS.path))
  NxTest.assert_equal(7, raw['std'], 'primar sa obnovil zo zalohy uz na STD 7')
  NxTest.assert_equal(bak['templates'], raw['templates'][0...-1], 'obsah zalohy nedotknuty')
  NxTest.assert_equal(NxKonD.seed, raw['templates'].last, 'Chladničková pribudla (zmazany templates.json ju neukradne)')
  NxTest.assert_equal(10, list.length)
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D zdravie primara: CHYBAJUCI primar + zaloha ZLEHO TVARU -> ZIADNY zapis') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD.write!('{"std": 6, "templates": null}', "#{NxKonD::TS.path}.bak")
  list = NxKonD::TS.reload!
  NxTest.refute(File.exist?(NxKonD::TS.path), 'z nepouzitelnej zalohy sa primar nevyrobil')
  NxTest.assert_equal(nil, list.find { |t| t['name'] == NxKonD::NAME }, 'ani seed')
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D zdravie primara: ZLY TVAR primara (pole, templates ako objekt) -> ZIADNY zapis ani pri platnej zalohe') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  ['[1, 2]', '{"std": 6, "templates": {"a": 1}}'].each do |bad|
    NxKonD.reset!
    NxKonD.write!(NxKonD.std6_payload, "#{NxKonD::TS.path}.bak")
    NxKonD.write!(bad)
    NxTest.assert_equal(nil, NxKonD::TS.migration_source, "#{bad}: zdroj migracie nie je")
    NxKonD::TS.reload!
    NxTest.assert_equal(bad.b, File.binread(NxKonD::TS.path), "#{bad}: primar ostal presne taky, aky bol")
  end
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D zdravie primara: zdroj migracie — zdravy tvar = Hash s polom `templates` (chybajuci std = legacy 1)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD.write!('{"templates": []}')
  NxTest.assert_equal({ 'templates' => [] }, NxKonD::TS.migration_source, 'legacy bez std je zdravy')
  NxKonD.write!('{"std": 5, "templates": []}', "#{NxKonD::TS.path}.bak")
  NxTest.assert_equal({ 'templates' => [] }, NxKonD::TS.migration_source, 'existujuci primar ma prednost pred zalohou')
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D: kniznica STD 7 je pre plugin so STD 6 LEN NA CITANIE (aktualizovat obe PC)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD::TS.load
  bytes = File.binread(NxKonD::TS.path)
  NxKonD.with_const(NxKonD::TS, :STD, 6) do
    NxTest.assert_equal(true, NxKonD::TS.read_only?, 'std 7 > STD 6')
    NxTest.assert_equal(false, NxKonD::TS.upsert('cabinet', 'Nova', { 'type' => 'lower' }), 'ulozit sa neda')
    NxTest.assert_equal(:readonly, NxKonD::TS.rename('cabinet', NxKonD::NAME, 'Iná'), 'premenovat sa neda')
    NxTest.assert_equal(false, NxKonD::TS.delete('cabinet', NxKonD::NAME), 'zmazat sa neda')
    NxTest.assert_equal(false, NxKonD::TS.touch_used('cabinet', NxKonD::NAME), 'ani peciatka pouzitia')
  end
  NxTest.assert_equal(bytes, File.binread(NxKonD::TS.path), 'subor netknuty')
ensure
  NxKonD.reset! if NxTest.headless?
end

NxTest.test('KON-D (R-12): seed so schemou 21 starsi plugin (schema 20) ODMIETNE pouzit aj vlozit') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD::TS.load
  # Seed z TOHTO pluginu (schema 21) — generator seedu cita konstantu, preto
  # sa config berie PRED simulaciou starsieho pluginu.
  shipped = NxKonD.cfg
  NxKonD.with_const(NxKonD::CB, :CONFIG_SCHEMA, 20) do
    NxTest.assert_equal(true, NxKonD::CB.newer_config?(shipped), 'plugin 20 seed vidi ako novsi')
    msg = Noxun::Engine::Panel.newer_template_refusal(['cabinet', NxKonD::NAME], 'vloženie by nastavenia stratilo')
    NxTest.assert(msg.to_s.include?('novšej verzie'), "vklad odmietnuty: #{msg.inspect}")
  end
  NxTest.assert_equal(false, NxKonD::CB.newer_config?(NxKonD.cfg), 'aktualny plugin seed berie')
  NxTest.assert_equal(nil, Noxun::Engine::Panel.newer_template_refusal(['cabinet', NxKonD::NAME], 'x'))
ensure
  NxKonD.reset! if NxTest.headless?
end

# ============================================================================
# 5. POUZITIE SEEDU NA EXISTUJUCU SKRINKU (audit NOTE 5)
# ============================================================================

NxTest.test('KON-D pouzitie na skrinku so zapustenim: zapustenie -> 0, vazby, osadenie aj ocakavania ostanu') do
  td = Noxun::Engine::TemplatesDialog
  ref = NxS1F.ref('I-7', 'mount_offset' => 14.0)
  _plan, src = NxKonD.built('type' => 'lower', 'width' => 600.0, 'height' => 2100.0, 'depth' => 580.0,
                            'top_front_setback' => 30.0, 'back_setback' => 20.0, 'back_mode' => 'overlay',
                            'back_rail_height' => 150.0, 'appliance_expects' => ['oven'])
  target = NxKonD::CB.config_to_params(src.merge('appliance_refs' => [ref]))
  merged = td.merge_template(target, NxKonD.cfg)
  NxTest.assert_equal([50.0, 0.0, 100.0], merged.values_at('back_setback', 'top_front_setback', 'back_rail_height'),
                      'vyslovne predvolby seedu prepisu ciel (zapustenie 30 -> 0, H 150 -> 100)')
  NxTest.assert_equal([ref], merged['appliance_refs'], 'vazba na spotrebic aj s osadenim 14 ostala cielu')
  NxTest.assert_equal(%w[fridge oven], merged['appliance_expects'], 'ocakavania sa ZJEDNOTILI')
  plan, st = NxKonD.built(merged)
  NxTest.assert_equal(0.0, st['top_front_setback'].to_f, 'po prestavbe bez zapustenia')
  NxTest.assert_equal(14.0, st['appliance_refs'].first['mount_offset'], 'osadenie prezilo prestavbu')
  NxTest.assert_equal([600.0, 510.0], NxKonD.part(plan, 'cabinet/bottom')[:prod].values_at(:length, :width))
  NxTest.assert_equal(nil, NxKonD.part(plan, 'cabinet/back'))
end

# ============================================================================
# 6. SUHRN NA DLAZDICI (audit FIX 4)
# ============================================================================

NxTest.test('KON-D suhrn: ucinne hodnoty — komin, zapustenie nie pri Bez stropu, listy len pri rails, slot nikdy') do
  s = ->(c) { NxKonD::TS.construction_summary(c)['text'] }
  NxTest.assert_equal({ 'has' => true, 'text' => 'komín vzadu 50' }, NxKonD::TS.construction_summary(NxKonD.cfg),
                      'Chladničková: lišty 100 pri Bez chrbta sa NEUKAZUJU')
  NxTest.assert_equal({ 'has' => false, 'text' => '' }, NxKonD::TS.construction_summary('type' => 'lower'))
  NxTest.assert_equal('', s.call('back_setback' => 0.0, 'top_front_setback' => 0.0, 'back_rail_height' => 100.0,
                                 'back_mode' => 'overlay'), 'vyslovne predvolby = ziadny riadok')
  NxTest.assert_equal('zap. 30', s.call('top_mode' => 'full', 'top_front_setback' => 30.0))
  NxTest.assert_equal('zap. 30', s.call('top_mode' => 'two_rails', 'top_front_setback' => 30.0))
  NxTest.assert_equal('', s.call('top_mode' => 'none', 'top_front_setback' => 30.0), 'Bez stropu: zapustenie neplati')
  NxTest.assert_equal('z líšt 100', s.call('back_mode' => 'rails'), 'listy aj pri predvolenej vyske')
  NxTest.assert_equal('z líšt 150', s.call('back_mode' => 'rails', 'back_rail_height' => 150.0))
  NxTest.assert_equal('z líšt 100', s.call('back' => { 'mode' => 'rails' }), 'vnoreny back.mode')
  NxTest.assert_equal('', s.call('back_mode' => 'groove', 'back_rail_height' => 150.0), 'pamatana H pri inom chrbte nie')
  NxTest.assert_equal('komín vzadu 50 · zap. 30 · z líšt 100',
                      s.call('back_setback' => 50.0, 'top_front_setback' => 30.0, 'back_mode' => 'rails'))
  NxTest.assert_equal('komín vzadu 12,5', s.call('back_setback' => '12.5'), 'desatiny s ciarkou, prisne parsovanie')
  NxTest.assert_equal('', s.call('back_setback' => '50oops'), 'neplatna hodnota = 0 (ako pri stavbe)')
  NxTest.assert_equal('', s.call('type' => 'dishwasher', 'back_setback' => 50.0, 'back_mode' => 'rails'), 'slot nikdy')
end

NxTest.test('KON-D veta o vetrani: pri KAZDEJ sablone, ktora ocakava chladnicku — inak nic') do
  vent = 'Vetracie otvory v sokli a hore rieši stolár podľa montážneho listu spotrebiča.'
  NxTest.assert_equal(vent, NxKonD::TS.ventilation_note(NxKonD.cfg))
  NxTest.assert_equal(vent, NxKonD::TS.ventilation_note('type' => 'upper', 'appliance_expects' => %w[oven fridge]))
  NxTest.assert_equal('', NxKonD::TS.ventilation_note('appliance_expects' => ['oven']))
  NxTest.assert_equal('', NxKonD::TS.ventilation_note('type' => 'dishwasher'))
  NxTest.assert_equal('', NxKonD::TS.ventilation_note(nil))
end

NxTest.test('KON-D suhrn: SKUTOCNE payloady oboch ciest (Studio `tile_row`, vkladanie `template_list`)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  NxKonD.reset!
  NxKonD::TS.load
  # Neaktivne ulozene hodnoty: lišty 150 pri naloženom chrbte, zapustenie pri Bez stropu, slot s kominom.
  NxKonD::TS.upsert('cabinet', 'Skrytá', 'type' => 'lower', 'back_mode' => 'overlay', 'back_rail_height' => 150.0,
                                         'top_mode' => 'none', 'top_front_setback' => 40.0)
  NxKonD::TS.upsert('cabinet', 'Slot s komínom', 'type' => 'dishwasher', 'back_setback' => 50.0)
  pay = Noxun::Engine::TemplatesDialog.tpl_payload
  studio = pay['cabinet'].to_h { |r| [r['name'], r] }
  insert = Noxun::Engine::Panel.template_list.select { |t| t['kind'] == 'cabinet' }.to_h { |t| [t['name'], t] }
  vent = NxKonD::TS::VENT_NOTE
  [studio, insert].each_with_index do |rows, i|
    path = i.zero? ? 'Studio' : 'vkladanie'
    fr = rows[NxKonD::NAME]
    NxTest.assert_equal({ 'has' => true, 'text' => 'komín vzadu 50' }, fr['construction'], "#{path}: Chladničková")
    NxTest.assert_equal(vent, fr['vent_note'], "#{path}: veta o vetrani")
    %w[Skrytá Dolna\ klasik Umývačka\ 60 Slot\ s\ komínom].each do |n|
      NxTest.assert_equal({ 'has' => false, 'text' => '' }, rows[n]['construction'], "#{path}: #{n} bez riadku")
      NxTest.assert_equal('', rows[n]['vent_note'], "#{path}: #{n} bez vety")
    end
  end
  NxTest.refute(studio[NxKonD::NAME]['config'].key?('back_setback'), 'TILE_CONFIG_KEYS ostava orezany')
  raw = JSON.parse(File.binread(NxKonD::TS.path))
  NxTest.refute(raw['templates'].any? { |t| t.key?('construction') || t.key?('vent_note') },
                'odvodene udaje sa do templates.json NIKDY nezapisu')
ensure
  NxKonD.reset! if NxTest.headless?
end
