# frozen_string_literal: true
# D-139 (smoke S1, Michal 21.9. + 24.9.2026) — VYSKA CELA SLOTU UMYVACKY JE
# ODVODENA: vyska linky − sokel − medzera hore (`fronts.gap_top`, schema
# medzier skrinky). Vstup „Čelo V" zanikol; predvolby 880 / 100 -> celo 778.
# Zvysok D-138: texty Kovania/Nakupu/Kontroly hovoria „F1 · dv myčka".
#
# PRECO TIETO TESTY (Codex audit Astra B2, 24.9.2026):
#   1) JEDEN VZOREC, JEDNA VALIDACIA (FIX 3). `dw_front_eval` cita normalize,
#      panelovy preflight aj absorpcia scale; JS ma zrkadlo. Spolocna fixtura
#      `tests/fixtures/slot_front_eval.json` drzi obe strany pri tom istom
#      cisle aj pri tej istej strane rady (pod minimom vs nad maximom).
#   2) CITANIE NEPREDSTIERA PRESTAVBU (FIX 2). Stary slot (schema 16, rucne
#      celo) ukazuje svoje ulozene cislo a „po prestavbe X", kym ho nieco
#      neprestavi — geometria v modeli je stale ta stara.
#   3) SEED SA OBNOVUJE LEN NEDOTKNUTY (BLOCKER 1). Odtlacok z vybranych
#      rozmerov by prepisal aj sablonu so zmenenym dekorom ci medzerami —
#      porovnava sa CELY zaznam.
#   4) SCALE BEZ NORMALIZE STAREHO CONFIGU (FIX 5). Hranice vysky linky sa
#      pocitaju zo sokla a medzery, nie normalizovanim ulozeneho (mozno
#      neplatneho) slotu.
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxD139
  module_function

  def cb
    Noxun::Engine::CabinetBuilder
  end

  def fixture
    @fixture ||= JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'slot_front_eval.json'),
                                      encoding: 'UTF-8'))
  end

  def slot(over = {})
    cb.normalize({ 'type' => 'dishwasher', 'width' => 600.0, 'height' => 880.0, 'depth' => 560.0,
                   'dw_class' => 600, 'dw_body_height' => 820.0, 'dw_front_bottom' => 100.0 }.merge(over))
  end

  def stored(cfg)
    JSON.parse(cb.cabinet_config(cfg).to_json)
  end

  def side_of(err)
    return nil if err.nil?
    return 'low' if err.include?('najmenej')
    return 'high' if err.include?('najviac')

    'unknown'
  end

  # Slot zo schemy 16 (pred D-139): rucne celo 776 pri linke 930 a sokli 64,
  # medzeru hore stare `slot_fronts!` vynucovalo na 0.
  def legacy_slot_cfg
    fronts = Noxun::Engine::Fronts.empty_config.merge(
      'gap' => 0.0, 'gap_top' => 0.0, 'gap_bottom' => 0.0,
      'items' => [{ 'id' => 'F1', 'type' => 'blind', 'mode' => 'fixed', 'height' => 776.0,
                    'locked' => true, 'wings' => 1, 'profile' => 'none' }]
    )
    { 'config_schema' => 16, 'type' => 'dishwasher', 'width' => 600.0, 'height' => 930.0,
      'depth' => 560.0, 'thickness' => 18.0, 'floor_height' => 0.0, 'dw_class' => 600,
      'dw_body_height' => 820.0, 'dw_front_bottom' => 64.0, 'dw_front_height' => 776.0,
      'fronts' => fronts }
  end
end

# --- 1) jeden vzorec, jedna validacia ---------------------------------------

NxTest.test('D-139: `dw_front_eval` sedi so spolocnou fixturou (cislo aj strana rady)') do
  cases = NxD139.fixture['cases']
  NxTest.assert(cases.length >= 8, 'fixtura je podozrivo kratka')
  cases.each do |c|
    ev = NxD139.cb.dw_front_eval(c['height'], c['bottom'], c['gap_top'])
    NxTest.assert_close(c['value'].to_f, ev[:value], 0.001, c['case'])
    NxTest.assert_equal(c['side'], NxD139.side_of(ev[:error]), "#{c['case']}: strana rady")
  end
end

NxTest.test('D-139: predvolby 880 / 100 davaju celo 778 a hornu hranu 2 mm pod linkou') do
  cfg = NxD139.slot
  NxTest.assert_close(778.0, cfg[:dw_front_height], 0.01)
  pd = Noxun::Engine::Construction.build_plan(cfg, 'CAB-139')[:parts].first
  NxTest.assert_close(100.0, pd[:origin][2], 0.01, 'celo stoji na sokli')
  NxTest.assert_close(778.0, pd[:box][2], 0.01)
  NxTest.assert_close(878.0, pd[:origin][2] + pd[:box][2], 0.01, 'horna hrana = linka − medzera 2')
  d = NxD139.cb::DISHWASHER_DEFAULTS
  NxTest.assert_close(880.0, d[:height], 0.01, 'predvolena linka (Michal 24.9.2026)')
  NxTest.assert_close(100.0, d[:dw_front_bottom], 0.01, 'predvoleny sokel')
  NxTest.refute(d.key?(:dw_front_height), 'vyska cela nie je predvolba — je odvodena')
end

NxTest.test('D-139: zmena linky, soklu aj medzery hore prepocita celo (ziadne rucne pole)') do
  NxTest.assert_close(828.0, NxD139.slot('height' => 930.0)[:dw_front_height], 0.01, 'linka')
  NxTest.assert_close(814.0, NxD139.slot('dw_front_bottom' => 64.0)[:dw_front_height], 0.01, 'sokel')
  NxTest.assert_close(773.0, NxD139.slot('fronts' => { 'gap_top' => 7.0 })[:dw_front_height], 0.01, 'medzera')
  NxTest.assert_close(778.0, NxD139.slot('dw_front_height' => 500.0)[:dw_front_height], 0.01,
                      'poslana vyska cela sa IGNORUJE')
end

NxTest.test('D-139: celo mimo rozsahu slot NEPOSTAVI a veta radi PODLA STRANY') do
  low = begin
    NxD139.slot('height' => 500.0, 'dw_front_bottom' => 300.0)
    nil
  rescue RuntimeError => e
    e.message
  end
  NxTest.assert(low.to_s.include?('najmenej 300 mm') && low.include?('zvýš výšku linky'), low.inspect)
  high = begin
    NxD139.slot('height' => 1200.0, 'dw_front_bottom' => 0.0, 'fronts' => { 'gap_top' => -2.0 })
    nil
  rescue RuntimeError => e
    e.message
  end
  NxTest.assert(high.to_s.include?('najviac 1200 mm') && high.include?('zníž výšku linky'), high.inspect)
end

# --- 2) panel: preflight, brana, payload ------------------------------------

NxTest.test('D-139: preflight slotu odvodi celo aj pri STAREJ vyske v riadku klienta') do
  NxTest.skip!('panel sa testuje headless') unless NxTest.headless?
  stale = { 'items' => [{ 'id' => 'F1', 'type' => 'blind', 'mode' => 'fixed', 'height' => 500.0 }],
            'gap_top' => 2.0 }
  data = { 'type' => 'dishwasher', 'fronts' => stale, 'width' => 600.0, 'height' => 930.0,
           'floor_height' => 0.0, 'dw_front_bottom' => 100.0, 'revision' => 1 }
  out = Noxun::Engine::Panel.front_preflight_result(data)
  NxTest.assert_equal(true, out['valid'], "platny preflight: #{out['errors'].inspect}")
  NxTest.assert_close(828.0, out['items'].first['height'], 0.01, 'vyska z linky 930, sokla 100, medzery 2')
  bad = Noxun::Engine::Panel.front_preflight_result(data.merge('height' => 500.0, 'dw_front_bottom' => 300.0))
  NxTest.assert_equal(false, bad['valid'])
  NxTest.assert(bad['errors'].first['message'].include?('najmenej 300 mm'),
                'preflight hovori TOU ISTOU vetou ako stavba')
end

NxTest.test('D-139: brana ciel slotu posudzuje pocet, typ a rezim — vysku NIE') do
  NxTest.skip!('panel sa testuje headless') unless NxTest.headless?
  params = { 'type' => 'dishwasher' }
  one = { 'items' => [{ 'id' => 'F1', 'type' => 'blind', 'mode' => 'fixed', 'height' => 111.0 }] }
  NxTest.assert_equal(nil, Noxun::Engine::Panel.slot_fronts_refusal(params, one),
                      'stara vyska z riadku nie je odmietnutie (normalize ju odvodi)')
  two = { 'items' => one['items'] * 2 }
  msg = Noxun::Engine::Panel.slot_fronts_refusal(params, two)
  NxTest.assert(msg.to_s.include?('dopočíta z výšky linky'), msg.inspect)
  NxTest.refute(msg.include?('Čelo V'), 'veta uz neodkazuje na zaniknute pole')
  NxTest.refute(Noxun::Engine::Panel::PARAM_KEYS.include?('dw_front_height'))
end

NxTest.test('D-139 (Astra FIX 2): payload ukazuje ULOZENE celo a pri starom slote „po prestavbe"') do
  NxTest.skip!('panel sa testuje headless') unless NxTest.headless?
  pay = Noxun::Engine::Panel.slot_payload(NxD139.legacy_slot_cfg)
  NxTest.assert_equal('776', pay['front_height'], 'stav poslednej stavby — v modeli stoji 776')
  NxTest.assert_equal('866', pay['front_after'], 'nova hodnota az po prestavbe (930 − 64 − 0)')
  NxTest.assert_equal('776 · po prestavbe 866', pay['front_text'])
  NxTest.assert_equal('0 · schéma medzier', pay['gap_text'], 'stara medzera hore bola 0')
  fresh = Noxun::Engine::Panel.slot_payload(NxD139.stored(NxD139.slot))
  NxTest.assert_equal('778', fresh['front_text'], 'po stavbe su ulozena a odvodena hodnota zhodne')
  NxTest.assert_equal(nil, fresh['front_after'])
end

# --- 3) texty „F1 · dv myčka" (zvysok D-138) -----------------------------------

NxTest.test('D-138/B2: plan slotu pomenuje celo pre texty Kovania — bezna blenda ostava blendou') do
  pl = Noxun::Engine::Construction.build_plan(NxD139.slot, 'CAB-139')
  items = pl[:front_items]
  NxTest.assert_equal('dv myčka', items.first['label'], 'odvodeny kluc na resolved polozke')
  NxTest.assert_equal('F1 · dv myčka', Noxun::Engine::PartKeys.human_label('front:F1/blind', fronts: items))
  low = NxD139.cb.normalize('type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'floor_height' => 100.0,
                            'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'blind', 'mode' => 'auto' }] })
  li = Noxun::Engine::Construction.build_plan(low, 'CAB-140')[:front_items]
  NxTest.refute(li.first.key?('label'), 'bezna blenda kluc nedostane')
  NxTest.assert_equal('F1 · blenda', Noxun::Engine::PartKeys.human_label('front:F1/blind', fronts: li))
  # Builder zapisuje `front_items` z PLANU (`write_cabinet_attrs`); tu ta ista
  # cesta cez `cabinet_config` + JSON round-trip — kluc prezije do modelu.
  st = NxD139.stored(NxD139.slot.merge(front_items: items))
  NxTest.assert_equal('dv myčka', st['front_items'].first['label'],
                      'projekcia sa ulozi do configu (odtial ju citaju Kovanie aj Nakup)')
end

# --- 4) scale bez normalize stareho configu ---------------------------------

NxTest.test('D-139 (Astra FIX 5): hranice vysky linky slotu su zo sokla a medzery, nie z normalize') do
  b = NxD139.cb.slot_height_bounds('dw_front_bottom' => 100.0, 'fronts' => { 'gap_top' => 2.0 })
  NxTest.assert_equal([500.0, 1200.0], b, 'typovy rozsah, lebo 402 < 500 a 1302 > 1200')
  b2 = NxD139.cb.slot_height_bounds('dw_front_bottom' => 300.0, 'fronts' => { 'gap_top' => 2.0 })
  NxTest.assert_close(602.0, b2[0], 0.01, 'vysoky sokel dviha spodnu hranicu (300 + 2 + 300)')
  b3 = NxD139.cb.slot_height_bounds('dw_front_bottom' => 0.0, 'fronts' => { 'gap_top' => -30.0 })
  NxTest.assert_close(1170.0, b3[1], 0.01, 'zaporna medzera znizi hornu (0 − 30 + 1200)')
  # Stary slot, ktory je pod novym pravidlom NEPLATNY (500 − 300 − 0 = 200):
  # hranice sa aj tak spocitaju — normalize by vybuchol.
  legacy = NxD139.legacy_slot_cfg.merge('height' => 500.0, 'dw_front_bottom' => 300.0)
  NxTest.assert_close(600.0, NxD139.cb.slot_height_bounds(legacy)[0], 0.01)
  NxTest.assert_close(600.0, Noxun::Engine::Construction.min_valid_height(
    { type: 'dishwasher', dw_front_bottom: 300.0, fronts: { 'gap_top' => 0.0 } }
  ), 0.01, 'min_valid_height pre slot = ta ista spodna hranica (normalizovany config)')
  scale = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer.rb'), encoding: 'UTF-8')
  body = scale[/def clamp_height\(params, val, cid\).*?\n        end\n/m].to_s
  NxTest.assert(body.index('clamp_slot_height') < body.index('CabinetBuilder.normalize'),
                'slot odbocuje PRED normalize ulozeneho configu')
end

# --- 5) seed sablon: obnovi sa LEN nedotknuty --------------------------------

NxTest.test('D-139 (Astra BLOCKER 1): obnova seedu prepise LEN zaznam zhodny CELY so seedom S1-E') do
  ts = Noxun::Engine::TemplateStore
  legacy = ts.legacy_slot_seeds
  fresh = ts.build_predefined_slots
  out = ts.refresh_slot_seed(legacy)
  NxTest.assert_equal(ts.canon_json(fresh), ts.canon_json(out), 'nedotknute seedy -> nove predvolby')
  NxTest.assert_close(880.0, out[0]['config']['height'], 0.01)
  NxTest.assert_equal(NxD139.cb::CONFIG_SCHEMA, out[0]['config']['config_schema'])

  gap = Noxun::Engine::JsonFileStore.deep_copy(legacy[0])
  gap['config']['fronts']['gap_top'] = 5.0
  deco = Noxun::Engine::JsonFileStore.deep_copy(legacy[0])
  deco['config']['front_material_id'] = 'H1181'
  extra = legacy[0].merge('buduce_pole' => 1)
  newer = Noxun::Engine::JsonFileStore.deep_copy(legacy[0])
  newer['config']['config_schema'] = 18
  renamed = legacy[0].merge('name' => 'Umývačka 60 moja')
  [gap, deco, extra, newer, renamed].each_with_index do |rec, i|
    got = ts.refresh_slot_seed([rec]).first
    NxTest.assert_equal(ts.canon_json(rec), ts.canon_json(got), "odlisny zaznam #{i + 1} ostava nedotknuty")
  end
  other = { 'name' => 'Dolna klasik', 'kind' => 'cabinet', 'config' => { 'type' => 'lower' } }
  NxTest.assert_equal(other, ts.refresh_slot_seed([other]).first, 'ine sablony sa nemenia')
end

NxTest.test('D-139: kniznica std 5 so seedmi S1-E sa pri nacitani obnovi na std 6 (raz)') do
  NxTest.skip!('TemplateStore testy bezia len headless (APPDATA sandbox)') unless NxTest.headless?
  ts = Noxun::Engine::TemplateStore
  jfs = Noxun::Engine::JsonFileStore
  mine = jfs.deep_copy(ts.legacy_slot_seeds[1])
  mine['config']['dw_body_height'] = 800.0 # 45 cm upravil pouzivatel
  FileUtils.mkdir_p(ts.dir)
  File.binwrite(ts.path, JSON.generate('std' => 5, 'templates' => [ts.legacy_slot_seeds[0], mine]))
  FileUtils.rm_f("#{ts.path}.bak")
  jfs.invalidate(ts.path)
  ts.reload!
  list = ts.load
  data = JSON.parse(File.binread(ts.path))
  NxTest.assert_equal(6, data['std'], 'marker sa posunul')
  s60 = list.find { |t| t['name'] == 'Umývačka 60' }
  s45 = list.find { |t| t['name'] == 'Umývačka 45' }
  NxTest.assert_close(880.0, s60['config']['height'], 0.01, 'nedotknuty seed dostal nove predvolby')
  NxTest.assert_close(100.0, s60['config']['dw_front_bottom'], 0.01)
  NxTest.assert_close(915.0, s45['config']['height'], 0.01, 'upraveny zaznam ostal')
  NxTest.assert_close(800.0, s45['config']['dw_body_height'], 0.01)
  before = File.binread(ts.path)
  2.times { ts.reload!; ts.load }
  NxTest.assert_equal(before, File.binread(ts.path), 'dalsie nacitanie uz nic nezapise')
ensure
  if NxTest.headless?
    FileUtils.rm_f(ts.path)
    FileUtils.rm_f("#{ts.path}.bak")
    jfs.invalidate(ts.path)
    ts.reload!
  end
end
