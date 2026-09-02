# frozen_string_literal: true
# Testy 1d/R-12: DOPREDNY GUARD CONFIGU KORPUSU (`config_schema`).
#
# CO BOLO ZLE: config korpusu je UZAVRETY WHITELIST (`normalize` +
# `cabinet_config`), takze zakazka ulozena NOVSIM pluginom prisla pri prvej
# prestavbe TICHO o vsetko, comu tato verzia nerozumie — a strata sa ulozenim
# ZVECNILA. Dopredny guard mal LEN kovanie (`guard_unknown_hardware!`);
# `plan_schema` verzuje tranzientny tvar planu a `part_key_schema` len kluce
# dielcov, takze kompatibilitu CONFIGU nevyjadri ani jeden.
#
# CO PLATI TERAZ:
#   * `CabinetBuilder::CONFIG_SCHEMA` je verzia kontraktu configu korpusu;
#   * marker sa zapisuje v JEDINOM zapisovom bode (`cabinet_config`, cez ktory
#     ide build AJ rebuild) a VZDY ako AKTUALNA hodnota — nikdy sa nepreberá
#     z params (klientsky payload z CEF nie je autorita);
#   * `guard_newer_config!` cita RAW ULOZENY config z ENTITY a odmietne
#     PRESTAVBU, ked je ulozene cislo VYSSIE nez CONFIG_SCHEMA; legacy korpus
#     bez markera (0) prechadza;
#   * citanie, vyber, kusovnik, VEPO a exporty sa NEBLOKUJU — zastavi sa
#     vyhradne zapisova cesta, ktora by config prepisala;
#   * `dedup_copies` novsiu kopiu PRESKOCI a pokracuje zvyskom (vynimka by
#     cez rescue okolo celej metody vyhladovala ostatne duplicity);
#   * STRATOVE cesty BEZ rebuildu maju vlastne odmietnutie so spolocnym
#     textovym zdrojom (`newer_config_message`): sablona pri POUZITI aj pri
#     VKLADE (autorita je ULOZENY zaznam, nie payload), „Vlozit kopiu"
#     a „Ulozit ako sablonu";
#   * sablonovy whitelist (`template_config_from`) marker NESIE, inak by
#     sablona z novsej verzie vyzerala ako legacy.
#
# PRIZNANE: preskocena novsia kopia si necha ZDIELANE `cabinet_id` — Kontrola
# drzi ORANGE `duplicate_identity` a zliate ID zastavi nakupne/cenove exporty
# (brana P0-2). Vedome: tichy orez vyrobnych dat je horsi nez zastaveny export.
#
# MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
#   1. `guard_newer_config!` z `rebuild_in_operation` odstraneny,
#   2. marker sa v `cabinet_config` nezapisuje,
#   3. porovnanie `>=` namiesto `>` (rovnaka schema by sa odmietala),
#   4. `dedup_copies` novsiu kopiu neprescakuje (raise cez cely cyklus),
#   5. `template_config_from` marker nestampuje,
#   6. `newer_template_refusal` cita payload namiesto ulozeneho zaznamu.
#
# GEOMETRIU, UNDO a odmietnutie nad ZIVYM modelom dokazuje in-SketchUp sekcia
# `run_r12` (+ async R12 dedup) v tests/sketchup/su_runner.rb.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_templates')
end

module NxR12
  E  = Noxun::Engine
  CB = E::CabinetBuilder

  SRC_DIR = File.join(NxTest::ROOT, 'noxun_engine')

  module_function

  def src(rel)
    File.read(File.join(SRC_DIR, rel), encoding: 'UTF-8')
  end

  # Zdrojovy poradovy test: `first` musi v subore stat PRED `second`.
  def order?(text, first, second)
    a = text.index(first)
    b = text.index(second)
    !a.nil? && !b.nil? && a < b
  end

  BASE = {
    'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
    'thickness' => 18.0, 'back_thickness' => 3.0
  }.freeze

  # Skrinka ako ju vidi guard: FakeInstance s NOXUN/config (JSON string).
  def cabinet(cfg)
    inst = NxTest::FakeInstance.new(1)
    E::Store.write_config(inst, cfg)
    inst
  end

  # Config, ktory by zapisal TENTO plugin (jediny zapisovy bod).
  def stored_config
    JSON.parse(CB.cabinet_config(CB.normalize(BASE)).to_json)
  end

  def future_config
    cfg = stored_config
    cfg['config_schema'] = CB::CONFIG_SCHEMA + 1
    cfg['zvlastne_nove_pole'] = { 'vyklop' => 'flap' }
    cfg
  end
end

module NxTest
  # --- 1) marker vznika v JEDINOM zapisovom bode -----------------------------

  test('R-12: cabinet_config stampuje aktualny config_schema (build aj rebuild)') do
    cfg = NxR12.stored_config
    assert_equal(NxR12::CB::CONFIG_SCHEMA, cfg['config_schema'],
                 'ulozeny config nesie aktualny marker kontraktu')
    assert(NxR12::CB::CONFIG_SCHEMA.is_a?(Integer) && NxR12::CB::CONFIG_SCHEMA >= 1,
           'CONFIG_SCHEMA je Integer >= 1')
  end

  test('R-12: zapisovy choke point — build aj rebuild idu cez write_cabinet_attrs') do
    s = NxR12.src('core/cabinet_builder.rb')
    # Marker sa smie zapisovat LEN v cabinet_config; keby si niektora cesta
    # skladala config sama, guard by nad nou nemal co porovnavat.
    assert_equal(1, s.scan(/config_schema: CONFIG_SCHEMA/).length,
                 'marker sa zapisuje na JEDINOM mieste (cabinet_config)')
    assert_equal(2, s.scan(/^ +write_cabinet_attrs\(inst, cid, /).length,
                 'write_cabinet_attrs volaju PRAVE dve cesty (commit_insert + rebuild_in_operation)')
    assert(s.include?('def cabinet_config(cfg)') && NxR12.order?(s, 'def write_cabinet_attrs', 'def cabinet_config'),
           'write_cabinet_attrs serializuje config cez cabinet_config')
  end

  test('R-12: marker sa NEDA podstrcit z params (klientsky payload nie je autorita)') do
    params = NxR12::BASE.merge('config_schema' => 99, 'part_key_schema' => 1)
    norm = NxR12::CB.normalize(params)
    assert(!norm.key?(:config_schema), 'normalize marker z params vobec nepozna')
    cfg = JSON.parse(NxR12::CB.cabinet_config(norm).to_json)
    assert_equal(NxR12::CB::CONFIG_SCHEMA, cfg['config_schema'],
                 'zapisany marker ostava aktualny aj pri podvrhnutom params')
  end

  # --- 2) truth table markera ------------------------------------------------

  test('R-12: newer_config? — legacy, rovnaka, novsia, neplatna hodnota') do
    cb = NxR12::CB
    cur = cb::CONFIG_SCHEMA
    assert_equal(0, cb.config_schema_of(nil), 'nil config = legacy 0')
    assert_equal(0, cb.config_schema_of({}), 'chybajuci marker = legacy 0')
    assert_equal(0, cb.config_schema_of('config_schema' => 'nezmysel'), 'neciselna hodnota = 0')
    assert_equal(cur + 1, cb.config_schema_of('config_schema' => (cur + 1).to_s),
                 'ciselny string sa cita ako cislo')

    refute(cb.newer_config?(nil), 'nil config NEBLOKUJE')
    refute(cb.newer_config?({}), 'legacy korpus bez markera prechadza')
    refute(cb.newer_config?('config_schema' => cur), 'rovnaka schema je kompatibilna')
    refute(cb.newer_config?('config_schema' => cur - 1), 'starsia schema je kompatibilna')
    assert(cb.newer_config?('config_schema' => cur + 1), 'novsia schema = blokuje')
    assert(cb.newer_config?('config_schema' => cur + 9), 'este novsia schema = blokuje')
  end

  # --- 3) guard nad ENTITOU --------------------------------------------------

  test('R-12: guard_newer_config! odmietne prestavbu a config NECHA NEDOTKNUTY') do
    inst = NxR12.cabinet(NxR12.future_config)
    before = E::Store.get(inst, 'config')
    e = assert_raise('z novšej verzie Noxun') { NxR12::CB.guard_newer_config!(inst) }
    assert(e.message.include?('prestavba by nastavenia stratila'),
           "hlaska pomenuje dosledok: #{e.message}")
    assert(e.message.include?('novší plugin'), 'hlaska navadza na aktualizaciu pluginu')
    assert_equal(before, E::Store.get(inst, 'config'),
                 'guard je CITACI — ulozeny config ostal bajtovo rovnaky')
    raw = JSON.parse(E::Store.get(inst, 'config'))
    assert_equal({ 'vyklop' => 'flap' }, raw['zvlastne_nove_pole'],
                 'neznáme pole novsej verzie prezilo (nic sa neorezalo)')
  end

  test('R-12: legacy a aktualny korpus prestavbu NEBLOKUJU') do
    legacy = NxR12.cabinet(JSON.parse(NxR12.stored_config.to_json).tap { |c| c.delete('config_schema') })
    assert_equal(nil, NxR12::CB.guard_newer_config!(legacy), 'legacy korpus (bez markera) prechadza')
    current = NxR12.cabinet(NxR12.stored_config)
    assert_equal(nil, NxR12::CB.guard_newer_config!(current), 'korpus tejto verzie prechadza')
    empty = NxTest::FakeInstance.new(2)
    assert_equal(nil, NxR12::CB.guard_newer_config!(empty), 'entita bez configu guard nezhodi')
  end

  test('R-12: guard cita RAW ULOZENY config, NIE params') do
    # (a) marker je v modeli, ale z params vypadol (config_to_params ho
    #     nepozna) — guard MUSI odmietnut.
    future = NxR12.future_config
    inst = NxR12.cabinet(future)
    params = NxR12::CB.config_to_params(future)
    assert(!params.key?('config_schema'), 'config_to_params marker neprenasa (params nie su autorita)')
    assert_raise('z novšej verzie Noxun') { NxR12::CB.guard_newer_config!(inst) }

    # (b) opacne: v modeli legacy config, ale „klient" tvrdi novsiu schemu —
    #     guard sa payloadu vobec nepyta, takze prestavba bezi.
    legacy = NxR12.cabinet('type' => 'lower', 'width' => 600.0)
    assert_equal(nil, NxR12::CB.guard_newer_config!(legacy),
                 'podvrhnuty marker v payloade prestavbu NEZASTAVI (cita sa entita)')
  end

  test('R-12: guard je zaradeny v rebuild_in_operation vedla kovania') do
    s = NxR12.src('core/cabinet_builder.rb')
    assert(s.include?('guard_unknown_hardware!(inst)') && s.include?('guard_newer_config!(inst)'),
           'oba dopredne guardy stoja v rebuild_in_operation')
    assert(NxR12.order?(s, 'guard_newer_config!(inst)', 'inst.make_unique'),
           'guard bezi PRED make_unique aj pred clear! definicie (ziadna mutacia)')
    # Guard sa NESMIE dostat do citacich/exportnych ciest.
    others = Dir[File.join(NxR12::SRC_DIR, '**', '*.rb')].reject { |f| f.end_with?('cabinet_builder.rb') }
    users = others.select { |f| File.read(f, encoding: 'UTF-8').include?('guard_newer_config!') }
    assert_equal([], users, 'guard vola VYHRADNE cabinet_builder (citanie/exporty sa neblokuju)')
  end

  # --- 4) dedup: novsia kopia sa PRESKOCI, cyklus pokracuje ------------------

  test('R-12: dedup_copies novsiu kopiu preskoci PRED start_operation') do
    s = NxR12.src('core/cabinet_builder.rb')
    body = s[s.index('def dedup_copies'), 2600].to_s
    assert(body.include?('if newer_config?(Store.config(inst))'),
           'dedup si novsiu kopiu overi sam (nespolieha sa na vynimku z rebuildu)')
    assert(NxR12.order?(body, 'newer_config?(Store.config(inst))', 'Ids.next_cabinet_id'),
           'preskocenie je PRED pridelenim noveho ID')
    assert(NxR12.order?(body, 'newer_config?(Store.config(inst))', "model.start_operation('NOXUN: Kopia"),
           'preskocenie je PRED otvorenim operacie (ziadna zrusena operacia, ziadny undo krok)')
    idx = body.index('if newer_config?(Store.config(inst))')
    assert(body[idx, 400].to_s.include?('next'), 'novsia kopia sa PRESKOCI (cyklus ide dalej)')
  end

  # --- 5) sablony: marker v zazname + obe cesty (pouzitie aj vklad) ---------

  test('R-12: template_config_from stampuje marker a ten prezije round-trip skladu') do
    skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?

    cfg = NxR12.stored_config
    tc = E::Panel.template_config_from(cfg)
    assert_equal(NxR12::CB::CONFIG_SCHEMA, tc['config_schema'],
                 'sablonovy whitelist marker NESIE (inak by novsia sablona vyzerala ako legacy)')

    name = '__R12_ROUNDTRIP__'
    E::TemplateStore.reload!
    E::TemplateStore.upsert('cabinet', name, tc)
    back = E::TemplateStore.find('cabinet', name)
    assert_equal(NxR12::CB::CONFIG_SCHEMA, back['config']['config_schema'],
                 'marker prezil zapis aj nacitanie sablony')
    refute(NxR12::CB.newer_config?(back['config']), 'vlastna sablona sa NEODMIETA')
    E::TemplateStore.delete('cabinet', name)
  end

  test('R-12: sablona z NOVSEJ verzie — vklad aj pouzitie odmietnute') do
    skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?

    name = '__R12_BUDUCA__'
    E::TemplateStore.reload!
    E::TemplateStore.upsert('cabinet', name, NxR12.future_config)
    back = E::TemplateStore.find('cabinet', name)
    assert(NxR12::CB.newer_config?(back['config']), 'ulozena sablona nesie novsi marker')

    msg = E::Panel.newer_template_refusal(['cabinet', name], 'vloženie by nastavenia stratilo')
    assert(!msg.nil? && msg.include?('Šablóna je z novšej verzie Noxun'),
           "vklad zo sablony sa odmieta: #{msg.inspect}")
    assert(msg.include?('vloženie by nastavenia stratilo'), 'hlaska pomenuje dosledok cesty')
    E::TemplateStore.delete('cabinet', name)

    # ROVNAKY TEXTOVY ZDROJ pre vsetky cesty.
    assert_equal(NxR12::CB.newer_config_message('Šablóna', 'vloženie by nastavenia stratilo'), msg,
                 'hlaska pochadza z jedineho zdroja (newer_config_message)')
  end

  test('R-12: vklad zo sablony cita ULOZENY zaznam, nie payload') do
    skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?

    E::TemplateStore.reload!
    # (a) zmiznuta sablona vklad NEBLOKUJE (chyba zaznamu nie je dokaz novsej verzie)
    assert_equal(nil, E::Panel.newer_template_refusal(['cabinet', '__R12_NEEXISTUJE__'], 'x'),
                 'neznamy zaznam sa neodmieta')
    assert_equal(nil, E::Panel.newer_template_refusal(nil, 'x'), 'vklad bez sablony sa nekontroluje')

    # (b) kompatibilna sablona prejde
    name = '__R12_OK__'
    E::TemplateStore.upsert('cabinet', name, E::Panel.template_config_from(NxR12.stored_config))
    assert_equal(nil, E::Panel.newer_template_refusal(['cabinet', name], 'x'),
                 'sablona tejto verzie sa nezastavuje')
    E::TemplateStore.delete('cabinet', name)

    # (c) autorita je zaznam — kontrola sa nepyta payloadu (v handleri sa cita
    #     LEN dvojica kind+name, ktoru vydal take_template_ref!)
    s = NxR12.src('ui/panel/actions_templates.rb')
    assert(s.include?('TemplateStore.find(kind, name)'),
           'refusal si zaznam nacita zo skladu')
    ac = NxR12.src('ui/panel/actions_cabinet.rb')
    assert(NxR12.order?(ac, 'newer_template_refusal(tpl_ref', 'CabinetBuilder.prepare_insert'),
           'kontrola sablony bezi PRED pripravou vkladu')
  end

  test('R-12: pouzitie sablony sa odmietne PRED merge aj rebuildom') do
    s = NxR12.src('ui/templates_dialog.rb')
    assert(s.include?("CabinetBuilder.newer_config?(tpl['config'])"),
           'apply kontroluje RAW config ULOZENEHO zaznamu sablony')
    assert(NxR12.order?(s, "CabinetBuilder.newer_config?(tpl['config'])", 'merge_template(target'),
           'kontrola je PRED zliatim configu sablony s cielom')
    assert(NxR12.order?(s, "CabinetBuilder.newer_config?(tpl['config'])", 'CabinetBuilder.rebuild_many'),
           'kontrola je PRED prestavbou')
  end

  # --- 6) dve stratove NE-rebuild cesty (B2) --------------------------------

  test('R-12: „Vlozit kopiu" sa odmietne PRED config_to_params aj buildom') do
    s = NxR12.src('ui/panel/actions_cabinet.rb')
    assert(s.include?('CabinetBuilder.newer_config?(src_cfg)'), 'kopia kontroluje RAW config zdroja')
    assert(NxR12.order?(s, 'CabinetBuilder.newer_config?(src_cfg)', 'CabinetBuilder.config_to_params(src_cfg)'),
           'kontrola je PRED prekladom configu na params')
    assert(NxR12.order?(s, 'CabinetBuilder.newer_config?(src_cfg)', 'CabinetBuilder.build(model, params)'),
           'kontrola je PRED vznikom odvodeneho korpusu')
    assert(s.include?("newer_config_message('Korpus', 'kópia by nastavenia stratila')"),
           'hlaska ide z jedineho textoveho zdroja')
  end

  test('R-12: „Ulozit ako sablonu" sa odmietne PRED template_config_from') do
    s = NxR12.src('ui/panel/actions_templates.rb')
    assert(s.include?('CabinetBuilder.newer_config?(cab_cfg)'), 'kontroluje RAW config oznacenej skrinky')
    assert(NxR12.order?(s, 'CabinetBuilder.newer_config?(cab_cfg)', 'template_config_from(cab_cfg'),
           'kontrola je PRED sablonovym whitelistom')
    assert(NxR12.order?(s, 'CabinetBuilder.newer_config?(cab_cfg)', 'TemplateStore.upsert'),
           'kontrola je PRED zapisom do kniznice (ziadny zapis)')
    assert(s.include?("newer_config_message('Korpus', 'šablóna by nastavenia stratila')"),
           'hlaska ide z jedineho textoveho zdroja')
  end

  test('R-12: hlasky vsetkych ciest maju JEDINY textovy zdroj') do
    cb = NxR12::CB
    msg = cb.newer_config_message('Korpus', 'prestavba by nastavenia stratila')
    assert_equal('Korpus je z novšej verzie Noxun — prestavba by nastavenia stratila; ' \
                 'projekt vyžaduje novší plugin.', msg, 'presne znenie hlasky')
    files = %w[ui/panel/actions_cabinet.rb ui/panel/actions_templates.rb ui/templates_dialog.rb]
    files.each do |rel|
      s = NxR12.src(rel)
      refute(s.include?('je z novšej verzie Noxun —'),
             "#{rel} si hlasku NEskláda sam (pouziva newer_config_message)")
    end
  end
end

# --- KOV-B1: bump na 4 + brana definicii setov v sablone ---------------------

module NxTest
  test('KOV-B1 (R-12): CONFIG_SCHEMA je >= 4 a sada R-12 ostava zelena') do
    cb = NxR12::CB
    assert(cb::CONFIG_SCHEMA >= 4,
           "schema configu #{cb::CONFIG_SCHEMA} < 4 — sety s klasifikaciou cestuju v sablonach")
    assert(cb.newer_config?('config_schema' => cb::CONFIG_SCHEMA + 1))
    refute(cb.newer_config?('config_schema' => cb::CONFIG_SCHEMA))
    # sablona ulozena TOUTO verziou nesie marker, takze ju starsi plugin odmietne
    tc = Noxun::Engine::Panel.template_config_from(NxR12.stored_config)
    assert_equal(cb::CONFIG_SCHEMA, tc['config_schema'],
                 'sablonovy whitelist stampuje AKTUALNY marker')
  end

  test('KOV-B1 (R-12): histori bumpu je zapisana v zdroji (disciplina STANDARD 2.5)') do
    s = NxR12.src('core/cabinet_builder.rb')
    hist = s[/HISTORIA:.*?CONFIG_SCHEMA = /m].to_s
    assert(!hist.empty?, 'komentar HISTORIA sa naslo')
    assert(hist.include?('4 = KOV-B1'), 'kazde cislo ma v komentari svoj dovod')
    assert(hist.include?('assess_set_defs'),
           'a menuje aj DOPREDNU branu, ktora k bumpu patri')
  end
end
