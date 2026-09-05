# frozen_string_literal: true
# Testy V0.6 H2 (D-76): SABLONA NESIE KOVANIE.
#
# Pokryva audit kontrakty davky:
#   BLOCKER 1 — sablona uklada mapovanie AJ zmrazene definicie vsetkych
#               referencovanych setov (priame hodnoty aj pasma selectora);
#               composite kluce „typ@dielec" su neprenosne a zahadzuju sa
#   BLOCKER 2 — zmrazenie bezi v operacii stavby; zlyhanie = vynimka (volajuci
#               operaciu zrusi celu — ziadna skrinka s nezmrazenym setom)
#   F4        — merge_template: legacy sablona BEZ kluca zachova sety CIELA
#               (do H2 ich aplikacia sablony ticho ZMAZALA), sablona s klucom
#               prebije genericke kluce a composite kluce ciela preziju
#   F5        — kolizie: neexistuje -> zapis, rovnaka -> nic, INA -> projekt
#               vyhrava (a hlasi sa), zly generic_type -> definicia sa nezmrazi
#
# Geometricka cast (vklad/undo v modeli) patri do tests/sketchup/su_runner.rb —
# Placement/ScaleWatch nie su v headless load liste.
require_relative '../helper' unless defined?(NxTest)

# UI vrstva: reopeny modulov Panel / TemplatesDialog bez SketchUp API pri load
# (vsetky volania su vnutri metod). V SketchUpe su uz nacitane pluginom.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
end

module NxH2
  HWS   = Noxun::Engine::HardwareSets
  PANEL = Noxun::Engine::Panel
  TD    = Noxun::Engine::TemplatesDialog
  CB    = Noxun::Engine::CabinetBuilder

  module_function

  def set_def(sid, gt, code, name = nil)
    { 'set_id' => sid, 'name' => name || sid, 'generic_type' => gt,
      'members' => [{ 'code' => code, 'per' => 'unit', 'qty' => 1 }] }
  end

  def norm(sid, gt, code, name = nil)
    HWS.normalize_sets([set_def(sid, gt, code, name)]).first
  end

  def selector(param, bands)
    { 'param' => param, 'bands' => bands }
  end

  def wipe_library!
    [HWS.path, "#{HWS.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
    Noxun::Engine::JsonFileStore.invalidate(HWS.path)
  end

  # Model s NOXUN dict (vzor NxH1a::Model) + pocitadlo zapisov: „jedno
  # zmrazenie = JEDEN zapis" je sucast kontraktu 1 undo.
  class Model
    attr_reader :writes

    def initialize(raw = nil)
      @attrs = {}
      @writes = 0
      @attrs[Noxun::Engine::Store::DICT] = { HWS::MODEL_KEY => raw } unless raw.nil?
    end

    def get_attribute(dict, key)
      (@attrs[dict] || {})[key]
    end

    def set_attribute(dict, key, val)
      @writes += 1
      (@attrs[dict] ||= {})[key] = val
    end

    def snapshot_sets
      _, st = HWS.project_state_status(self)
      st ? st['sets'] : {}
    end
  end

  # Model, ktoremu zlyha ZAPIS (plny disk / zamknuty dokument): write_project_state
  # vrati false -> zmrazenie skonci :failed.
  class DeadModel < Model
    def set_attribute(_dict, _key, _val)
      raise 'zapis do modelu zlyhal'
    end
  end

  # Skrinka s namapovanym setom + snapshot projektu, ktory ho drzi.
  def project_with(sets_by_id, mapping = {})
    m = Model.new
    HWS.write_project_state(m, 'mapping' => mapping, 'sets' => sets_by_id)
    m
  end
end

# --- 1) ULOZENIE sablony: mapovanie + zmrazene definicie (BLOCKER 1) ----------

NxTest.test('H2 sablona: uklada mapovanie setov AJ definicie (vratane pasiem selectora)') do
  hws = NxH2::HWS
  NxH2.wipe_library! # global = seed (zaves-klasik)
  a = NxH2.norm('bocnica-h70', 'slide', 'S70')
  b = NxH2.norm('bocnica-h144', 'slide', 'S144')
  m = NxH2.project_with({ 'bocnica-h70' => a, 'bocnica-h144' => b })
  sel = NxH2.selector('front_height',
                      [{ 'min' => 0.0, 'max' => 120.0, 'set_id' => 'bocnica-h70' },
                       { 'min' => 120.01, 'max' => 400.0, 'set_id' => 'bocnica-h144' }])
  cfg = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
          'thickness' => 18.0,
          'hardware_sets' => { 'slide' => sel, 'hinge' => 'zaves-klasik',
                               'slide@front:F1/panel' => 'bocnica-h70' } }
  tc = NxH2::PANEL.template_config_from(cfg, model: m)
  NxTest.assert_equal(%w[hinge slide], tc['hardware_sets'].keys.sort,
                      'composite kluc „typ@dielec" sa do sablony NEUKLADA (neprenosny)')
  NxTest.assert_equal('front_height', tc['hardware_sets']['slide']['param'], 'selector prezil')
  NxTest.assert_equal(%w[bocnica-h144 bocnica-h70 zaves-klasik],
                      tc['hardware_set_defs'].keys.sort,
                      'zmrazene su OBE pasma selectora aj priama hodnota')
  NxTest.assert_equal('S144', tc['hardware_set_defs']['bocnica-h144']['members'][0]['code'])
  NxTest.assert_equal('104717', tc['hardware_set_defs']['zaves-klasik']['members'][0]['code'],
                      'set mimo snapshotu sa doberie z globalnej kniznice')
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 sablona: definicia sa berie zo SNAPSHOTU projektu, nie z dnesneho globalu') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  snap = NxH2.norm('zaves-klasik', 'hinge', 'SNAP', 'Snapshot zaves')
  # Projektove mapovanie na set NEUKAZUJE — referenciu drzi az override skrinky.
  m = NxH2.project_with({ 'zaves-klasik' => snap })
  tc = NxH2::PANEL.template_config_from({ 'type' => 'lower',
                                          'hardware_sets' => { 'hinge' => 'zaves-klasik' } },
                                        model: m)
  NxTest.assert_equal('SNAP', tc['hardware_set_defs']['zaves-klasik']['members'][0]['code'],
                      'zmrazi sa to, co skrinka REALNE nakupuje (snapshot pred globalom)')
  NxTest.assert_equal('Snapshot zaves', tc['hardware_set_defs']['zaves-klasik']['name'])
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 sablona: bez kovania ziadne prazdne kluce; bez modelu sa kovanie neuklada') do
  m = NxH2::Model.new
  bez = NxH2::PANEL.template_config_from({ 'type' => 'lower' }, model: m)
  NxTest.assert_equal(false, bez.key?('hardware_sets'), 'ziadny prazdny kluc mapovania')
  NxTest.assert_equal(false, bez.key?('hardware_set_defs'), 'ziadny prazdny kluc definicii')
  prazdne = NxH2::PANEL.template_config_from({ 'type' => 'lower', 'hardware_sets' => {} }, model: m)
  NxTest.assert_equal(false, prazdne.key?('hardware_sets'))
  # POZOR (Ruby 3): bez zatvoriek by sa hash s => pri metode s kwargs (model:)
  # citalo ako keyword argumenty — hash sa VZDY zapisuje v zlozenych zatvorkach.
  legacy = NxH2::PANEL.template_config_from({ 'type' => 'lower',
                                              'hardware_sets' => { 'hinge' => 'zaves-klasik' } })
  NxTest.assert_equal(false, legacy.key?('hardware_sets'),
                      'volanie bez modelu (legacy) kovanie do sablony nedava')
  NxTest.assert_equal('lower', legacy['type'], 'konstrukcna cast sablony sa nemeni')
end

NxTest.test('H2 sablona: kovanie prezije ulozenie a nacitanie z kniznice sablon') do
  NxTest.skip!('TemplateStore testy bezia len headless (realny %APPDATA%)') unless NxTest.headless?

  NxH2.wipe_library!
  snap = NxH2.norm('zaves-klasik', 'hinge', 'SNAP')
  m = NxH2.project_with({ 'zaves-klasik' => snap })
  tc = NxH2::PANEL.template_config_from({ 'type' => 'lower',
                                          'hardware_sets' => { 'hinge' => 'zaves-klasik' } },
                                        model: m)
  store = Noxun::Engine::TemplateStore
  store.reload!
  store.upsert('cabinet', 'H2 docasna', tc)
  store.reload!
  back = store.find('cabinet', 'H2 docasna')['config']
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, back['hardware_sets'], 'mapovanie prezilo JSON')
  NxTest.assert_equal('SNAP', back['hardware_set_defs']['zaves-klasik']['members'][0]['code'],
                      'zmrazena definicia prezila JSON (sablona funguje aj na inom PC)')
ensure
  begin
    Noxun::Engine::TemplateStore.delete('cabinet', 'H2 docasna')
  rescue StandardError
    nil
  end
  NxH2.wipe_library!
end

# --- 2) merge_template (audit F4 + opravovany BUG) ---------------------------

NxTest.test('H2 merge BUG: legacy sablona BEZ kluca ZACHOVA sety ciela (dovtedy sa mazali)') do
  target = { 'part_overrides' => { 'cabinet/side:left' => { 'material_id' => 'X' } },
             'hardware_overrides' => [{ 'owner_part_key' => nil, 'generic_type' => 'leg',
                                        'rule_id' => 'r', 'quantity' => 6 }],
             'hardware_sets' => { 'hinge' => 'zaves-p2o', 'slide@front:F1/panel' => 'bocnica-h70' } }
  tpl = { 'type' => 'lower', 'width' => 600.0 } # seed sablona (kluc nema)
  merged = NxH2::TD.merge_template(target, tpl)
  NxTest.assert_equal({ 'hinge' => 'zaves-p2o', 'slide@front:F1/panel' => 'bocnica-h70' },
                      merged['hardware_sets'],
                      'aplikacia lubovolnej sablony uz NEMAZE vyber setov skrinky')
  NxTest.assert_equal(target['part_overrides'], merged['part_overrides'], 'regresia: part_overrides')
  NxTest.assert_equal(target['hardware_overrides'], merged['hardware_overrides'],
                      'regresia: hardware_overrides')
  NxTest.assert_equal(600.0, merged['width'], 'konstrukcia je zo sablony')
end

NxTest.test('H2 merge: sablona s kovanim je autorita generickych klucov, composite ciela PREZIJU') do
  target = { 'hardware_sets' => { 'hinge' => 'zaves-p2o', 'leg' => 'nohy-klzak-17',
                                  'slide@front:F1/panel' => 'bocnica-h70' } }
  tpl = { 'hardware_sets' => { 'hinge' => 'zaves-klasik' } }
  merged = NxH2::TD.merge_template(target, tpl)
  NxTest.assert_equal('zaves-klasik', merged['hardware_sets']['hinge'], 'sablona prebila zavesy')
  NxTest.assert_equal(false, merged['hardware_sets'].key?('leg'),
                      'genericke kluce urcuje SABLONA (nedoplnaju sa z ciela)')
  NxTest.assert_equal('bocnica-h70', merged['hardware_sets']['slide@front:F1/panel'],
                      'vyber na konkretnom dielci ciela sablona nikdy nemaze')
end

# (GH #133 P2: takuto sablonu odmietne uz handle_apply — merge je druha obrana.)
NxTest.test('H2 merge: composite kluc v sablone (rucne upraveny JSON) sa do skrinky NEDOSTANE') do
  tpl = { 'hardware_sets' => { 'slide@front:F1/panel' => 'bocnica-h144',
                               'hinge' => 'zaves-klasik', 'vymysleny' => 'x' } }
  merged = NxH2::TD.merge_template({ 'hardware_sets' => {} }, tpl)
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, merged['hardware_sets'],
                      'composite kluc aj neznamy typ zo sablony vypadnu')
end

NxTest.test('H2 merge: vysledok prejde builder round-tripom bez straty') do
  target = { 'hardware_sets' => { 'slide@front:F1/panel' => 'bocnica-h70' } }
  tpl = { 'type' => 'lower', 'hardware_sets' => { 'hinge' => 'zaves-klasik' } }
  merged = NxH2::TD.merge_template(target, tpl)
  cfg = NxH2::CB.normalize(merged)
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik', 'slide@front:F1/panel' => 'bocnica-h70' },
                      cfg[:hardware_sets], 'normalize drzi obe formy klucov')
end

# --- 3) zmrazenie definicii pri aplikacii/vklade (BLOCKER 2 + F5) ------------

NxTest.test('H2 zmrazenie: chybajuci set sa zapise; JEDEN zapis pre cely balik (1 undo)') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  a = NxH2.norm('bocnica-h70', 'slide', 'S70')
  z = NxH2.norm('zaves-vlastny', 'hinge', 'ZV')
  m = NxH2.project_with({}, {})
  before = m.writes
  res = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70', 'hinge' => 'zaves-vlastny' },
                                  { 'bocnica-h70' => a, 'zaves-vlastny' => z })
  NxTest.assert_equal(:ok, res['status'])
  NxTest.assert_equal(%w[bocnica-h70 zaves-vlastny], res['added'].sort)
  NxTest.assert_equal(1, m.writes - before, 'dva sety = JEDEN zapis snapshotu (jedno undo)')
  sets = m.snapshot_sets
  NxTest.assert_equal('S70', sets['bocnica-h70']['members'][0]['code'])
  NxTest.assert_equal('ZV', sets['zaves-vlastny']['members'][0]['code'])
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 zmrazenie: rovnaka definicia = nic; INA definicia = PROJEKT VYHRAVA') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  moja = NxH2.norm('bocnica-h70', 'slide', 'PROJEKT')
  m = NxH2.project_with({ 'bocnica-h70' => moja }, 'slide' => 'bocnica-h70')
  # (a) rovnaka definicia — ziadny zapis
  before = m.writes
  res = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70' },
                                  { 'bocnica-h70' => NxH2.norm('bocnica-h70', 'slide', 'PROJEKT') })
  NxTest.assert_equal([], res['added'], 'zhodna definicia sa nezapisuje')
  NxTest.assert_equal([], res['kept'])
  NxTest.assert_equal(0, m.writes - before, 'ziadny zbytocny zapis')
  # (b) INA definicia — projekt si drzi svoju a hlasi to
  res2 = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70' },
                                   { 'bocnica-h70' => NxH2.norm('bocnica-h70', 'slide', 'SABLONA') })
  NxTest.assert_equal(['bocnica-h70'], res2['kept'], 'kolizia sa hlasi')
  NxTest.assert_equal([], res2['added'])
  NxTest.assert_equal('PROJEKT', m.snapshot_sets['bocnica-h70']['members'][0]['code'],
                      'definicia projektu OSTAVA (prepis by zmenil uz postavene skrinky)')
  note = NxH2::PANEL.template_hardware_note(res2)
  NxTest.assert(note.include?('vlastnú verziu'), "hlaska pre pouzivatela: #{note}")
  # (c) iny NAZOV toho isteho setu je tiez ina definicia
  res3 = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70' },
                                   { 'bocnica-h70' => NxH2.norm('bocnica-h70', 'slide', 'PROJEKT',
                                                                'Ine meno') })
  NxTest.assert_equal(['bocnica-h70'], res3['kept'], 'kanonicke porovnanie berie cely zaznam')
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 zmrazenie: kolizia s GLOBALNOU predvolbou — sablonova verzia sa NEZAPISE') do
  hws = NxH2::HWS
  NxH2.wipe_library! # global = seed (zaves-klasik, kod 104717)
  m = NxH2::Model.new # projekt este NEMA snapshot
  iny = NxH2.norm('zaves-klasik', 'hinge', 'INY')
  res = hws.freeze_template_sets!(m, { 'hinge' => 'zaves-klasik' }, { 'zaves-klasik' => iny })
  NxTest.assert_equal(['zaves-klasik'], res['kept'],
                      'prvy zapis mrazi globalne predvolby — tie su uz "verzia projektu"')
  NxTest.assert_equal(0, m.writes, 'nic sa nezapisuje')
  NxTest.assert_equal('104717',
                      hws.global_default_state['sets']['zaves-klasik']['members'][0]['code'],
                      'pri stavbe (ensure_project_state!) sa zmrazi GLOBALNA definicia')
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 zmrazenie: nekompatibilny typ setu sa NEZMRAZI (mapovanie ostava, ORANGE)') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  m = NxH2.project_with({}, {})
  zle = NxH2.norm('bocnica-h70', 'hinge', 'ZAVES') # typ setu nesedi s klucom 'slide'
  res = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70' }, { 'bocnica-h70' => zle })
  NxTest.assert_equal(['bocnica-h70'], res['type_mismatch'])
  NxTest.assert_equal([], res['added'], 'ziadny tichy zly hardver')
  NxTest.assert_equal(nil, m.snapshot_sets['bocnica-h70'])
  NxTest.assert(NxH2::PANEL.template_hardware_note(res).include?('iného typu'), 'hlaska o type')
  # ten isty set pod dvoma roznymi typmi = konflikt -> nezmrazi sa vobec
  ok_def = NxH2.norm('spolocny', 'slide', 'S')
  res2 = hws.freeze_template_sets!(m, { 'slide' => 'spolocny', 'hinge' => 'spolocny' },
                                   { 'spolocny' => ok_def })
  NxTest.assert_equal(['spolocny'], res2['type_mismatch'], 'nejednoznacny typ = ruky prec')
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 zmrazenie: definicia, ktoru sablona nenesie, skonci ako missing (ORANGE)') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  m = NxH2.project_with({}, {})
  res = hws.freeze_template_sets!(m, { 'slide' => 'nie-je-nikde' }, {})
  NxTest.assert_equal(['nie-je-nikde'], res['missing'])
  NxTest.assert_equal(:ok, res['status'], 'chybajuca definicia nie je chyba zapisu')
  NxTest.assert(NxH2::PANEL.template_hardware_note(res).include?('chýba'), 'hlaska o chybajucom sete')
  # ak ho projekt uz ma, nie je to missing
  m2 = NxH2.project_with({ 'nie-je-nikde' => NxH2.norm('nie-je-nikde', 'slide', 'S') })
  res2 = hws.freeze_template_sets!(m2, { 'slide' => 'nie-je-nikde' }, {})
  NxTest.assert_equal([], res2['missing'], 'set uz v projekte je — sablona ho niest nemusi')
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 zmrazenie: poskodeny snapshot projektu NEPREPISE nic a vyhodi vynimku') do
  hws = NxH2::HWS
  m = NxH2::Model.new('{ nezmysel')
  a = NxH2.norm('bocnica-h70', 'slide', 'S70')
  res = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70' }, { 'bocnica-h70' => a })
  NxTest.assert_equal(:invalid, res['status'])
  NxTest.assert_equal([], res['added'])
  err = NxTest.assert_raise('poškodené') do
    NxH2::PANEL.freeze_template_hardware!(m, { 'slide' => 'bocnica-h70' }, { 'bocnica-h70' => a })
  end
  NxTest.assert(!err.message.empty?, 'vynimka zrusi CELU operaciu vkladu/aplikacie')
  NxTest.assert_equal('{ nezmysel', m.get_attribute(Noxun::Engine::Store::DICT, hws::MODEL_KEY),
                      'poskodeny snapshot ostal nedotknuty (ziadna tichá oprava)')
end

NxTest.test('H2 zmrazenie: zlyhany zapis = :failed a vynimka (ziadna skrinka s nezmrazenym setom)') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  m = NxH2::DeadModel.new
  a = NxH2.norm('bocnica-h70', 'slide', 'S70')
  res = hws.freeze_template_sets!(m, { 'slide' => 'bocnica-h70' }, { 'bocnica-h70' => a })
  NxTest.assert_equal(:failed, res['status'])
  NxTest.assert_equal([], res['added'])
  NxTest.assert_raise('nepodarilo') do
    NxH2::PANEL.freeze_template_hardware!(m, { 'slide' => 'bocnica-h70' }, { 'bocnica-h70' => a })
  end
  # uspesna cesta vracia poznamku (nie vynimku)
  ok_model = NxH2.project_with({}, {})
  note = NxH2::PANEL.freeze_template_hardware!(ok_model, { 'slide' => 'bocnica-h70' },
                                               { 'bocnica-h70' => a })
  NxTest.assert(note.include?('bocnica-h70'), "poznamka o doplnenych setoch: #{note}")
ensure
  NxH2.wipe_library!
end

NxTest.test('H2 zmrazenie: sablona bez kovania nesiaha na projekt (legacy cesta)') do
  m = NxH2::Model.new
  before = m.writes
  note = NxH2::TD.freeze_sets_from_template!(m, { 'hardware_sets' => { 'hinge' => 'zaves-klasik' } },
                                             { 'type' => 'lower' })
  NxTest.assert_equal('', note, 'legacy sablona nema co mrazit')
  NxTest.assert_equal(0, m.writes - before, 'ziadny zapis do modelu')
end

# --- 3b) posledna poistka: expanzia setu INEHO typu (audit F5) ---------------

NxTest.test('H2 expanzia: set ineho typu ako polozka = ORANGE, NIKDY tichy zly hardver') do
  hws = NxH2::HWS
  st = { 'mapping' => { 'slide' => 'spolocny' },
         'sets' => { 'spolocny' => NxH2.norm('spolocny', 'hinge', 'ZAVES') } }
  item = { 'owner_id' => 'CAB-1', 'owner_part_key' => 'front:F1/panel', 'generic_type' => 'slide',
           'quantity' => 1, 'rule_id' => 'r', 'params' => {} }
  exp = hws.expand([item], st, catalog: [])
  NxTest.assert_equal([], exp['rows'], 'ziadne kody zavesov na vysuv')
  NxTest.assert_equal('set_type_mismatch', exp['unmapped'][0]['reason'])
  res = Noxun::Engine::Validation.run({}, hardware_expansion: exp)
  NxTest.assert(res['items'][0]['message_sk'].include?('iného typu'), 'SK hlaska semafora')
  NxTest.assert_equal(res['counts']['orange'], res['items'].length, 'ORANGE, nikdy RED')
  NxTest.assert(hws.purchase_csv(exp).include?('iného typu'), 'dovod aj v nakupnom CSV')
end

NxTest.test('H2 kolizia + typ: projekt drzi set ineho typu -> nezapise sa a kovanie skonci ORANGE') do
  hws = NxH2::HWS
  NxH2.wipe_library!
  projektovy = NxH2.norm('spolocny', 'hinge', 'ZAVES')
  m = NxH2.project_with({ 'spolocny' => projektovy }, 'hinge' => 'spolocny')
  sablonovy = NxH2.norm('spolocny', 'slide', 'BOCNICA')
  res = hws.freeze_template_sets!(m, { 'slide' => 'spolocny' }, { 'spolocny' => sablonovy })
  NxTest.assert_equal(['spolocny'], res['kept'], 'projektova definicia sa NEPREPISUJE')
  NxTest.assert_equal('ZAVES', m.snapshot_sets['spolocny']['members'][0]['code'])
  # a expanzia to nezamlci
  _, st = hws.project_state_status(m)
  st['mapping']['slide'] = 'spolocny'
  item = { 'owner_id' => 'CAB-1', 'generic_type' => 'slide', 'quantity' => 1,
           'rule_id' => 'r', 'params' => {} }
  exp = hws.expand([item], st, catalog: [])
  NxTest.assert_equal('set_type_mismatch', exp['unmapped'][0]['reason'],
                      'radsej ORANGE ako kody zavesov na vysuv')
ensure
  NxH2.wipe_library!
end

# --- 4) vklad zo sablony: sanitizacia payloadu (audit F3) --------------------

NxTest.test('H2 vklad: mapovanie z JS sa normalizuje, definicie do configu skrinky nejdu') do
  defs = { 'zaves-klasik' => NxH2.set_def('zaves-klasik', 'hinge', '104717') }
  params = { 'type' => 'lower', 'width' => 600.0,
             'hardware_sets' => { 'hinge' => ' zaves-klasik ' },
             'hardware_set_defs' => defs }
  status, hw = NxH2::PANEL.take_insert_hardware!(params)
  NxTest.assert_equal(:ok, status)
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, hw['mapping'], 'hodnota otrimovana')
  NxTest.assert_equal(defs, hw['defs'], 'definicie idu na zmrazenie, nie do configu')
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, params['hardware_sets'],
                      'params nesu uz OCISTENE mapovanie')
  NxTest.assert_equal(false, params.key?('hardware_set_defs'),
                      'definicie sa z params odstranuju (config skrinky ich nenesie)')
  cfg = NxH2::CB.normalize(params)
  NxTest.assert_equal({ 'hinge' => 'zaves-klasik' }, cfg[:hardware_sets], 'mapovanie doputuje do configu')
end

NxTest.test('H2 vklad GH#133 P2: neprecitatelne kovanie sablony vklad ODMIETNE (ziadna ocesana mapa)') do
  status, lost = NxH2::PANEL.take_insert_hardware!(
    'hardware_sets' => { 'hinge' => 'zaves-klasik', 'slide@front:F1/panel' => 'x' }
  )
  NxTest.assert_equal(:lossy, status, 'composite kluc = rucne upravena sablona')
  NxTest.assert_equal(['slide@front:F1/panel'], lost, 'hlaska vymenuje, co sa necita')
  NxTest.assert_equal(:lossy, NxH2::PANEL.take_insert_hardware!('hardware_sets' => { 'magnet_push' => 'x' })[0],
                      'typ kovania z NOVSEJ verzie pluginu')
  NxTest.assert_equal(:ok, NxH2::PANEL.take_insert_hardware!('hardware_sets' => { 'hinge' => 'zaves-klasik' })[0],
                      'cista mapa prejde')
end

NxTest.test('H2 vklad: bez kovania sa kluce z params ODSTRANIA (ziadne prazdne mapovanie)') do
  params = { 'type' => 'lower', 'hardware_sets' => {}, 'hardware_set_defs' => {} }
  NxTest.assert_equal([:ok, nil], NxH2::PANEL.take_insert_hardware!(params), 'nic na zmrazenie')
  NxTest.assert_equal(false, params.key?('hardware_sets'))
  NxTest.assert_equal(false, params.key?('hardware_set_defs'))
  # payload uplne bez klucov (bezny vklad) nespadne
  plain = { 'type' => 'lower' }
  NxTest.assert_equal([:ok, nil], NxH2::PANEL.take_insert_hardware!(plain))
  NxTest.assert_equal({ 'type' => 'lower' }, plain, 'bezny vklad sa nemeni')
  # samotne definicie bez mapovania nemaju co zmrazit
  only_defs = { 'hardware_set_defs' => { 'x' => NxH2.set_def('x', 'slide', 'S') } }
  NxTest.assert_equal([:ok, nil], NxH2::PANEL.take_insert_hardware!(only_defs))
  NxTest.assert_equal(false, only_defs.key?('hardware_set_defs'))
end

# --- 5) GH #133 P2: bezstratove citanie sablony + poskodene sety projektu -----

NxTest.test('H2 GH#133 P2: mapovanie sablony sa cita BEZSTRATOVO alebo vobec') do
  hws = NxH2::HWS
  NxTest.assert_equal([:ok, {}], hws.read_template_mapping(nil), 'legacy sablona bez kluca')
  NxTest.assert_equal(:ok, hws.read_template_mapping('hinge' => 'zaves-klasik')[0])
  NxTest.assert_equal([:ok, { 'leg' => 'nohy-podla-sokla' }],
                      hws.read_template_mapping(' leg ' => ' nohy-podla-sokla '),
                      'trim nie je strata')
  NxTest.assert_equal(:lossy, hws.read_template_mapping('magnet_push' => 'x')[0],
                      'typ kovania z novsej verzie pluginu')
  NxTest.assert_equal(:lossy, hws.read_template_mapping('hinge' => 42)[0], 'neplatna hodnota')
  NxTest.assert_equal(:lossy, hws.read_template_mapping('nezmysel')[0], 'cudzi tvar')
  NxTest.assert_equal(:lossy, hws.read_template_mapping('slide@front:F1/panel' => 'x')[0],
                      'composite kluc — rucne upravena sablona')
end

NxTest.test('H2 GH#133 P2: poskodene sety projektu = sablona sa ulozi BEZ kovania a hlasi to') do
  NxH2.wipe_library!
  m = NxH2::Model.new('{ nezmysel') # snapshot :invalid
  cfg = { 'type' => 'lower', 'hardware_sets' => { 'hinge' => 'zaves-klasik' } }
  tc = NxH2::PANEL.template_config_from(cfg, model: m)
  NxTest.assert_equal(false, tc.key?('hardware_sets'),
                      'NIKDY kody z globalu, ktore zdrojovy model nepouziva')
  NxTest.assert_equal(false, tc.key?('hardware_set_defs'))
  NxTest.assert(NxH2::PANEL.template_save_hardware_note(cfg, tc, m).include?('poškodené'),
                'pouzivatel sa dozvie, ze sablona kovanie nenesie')
  # zdravy projekt: kovanie sa ulozi a hlaska nie je
  zdravy = NxH2.project_with({ 'zaves-klasik' => NxH2.norm('zaves-klasik', 'hinge', 'SNAP') })
  ok_tc = NxH2::PANEL.template_config_from(cfg, model: zdravy)
  NxTest.assert_equal('SNAP', ok_tc['hardware_set_defs']['zaves-klasik']['members'][0]['code'])
  NxTest.assert_equal('', NxH2::PANEL.template_save_hardware_note(cfg, ok_tc, zdravy))
  # skrinka bez kovania ziadnu hlasku nedostane
  NxTest.assert_equal('', NxH2::PANEL.template_save_hardware_note({ 'type' => 'lower' },
                                                                  { 'type' => 'lower' }, zdravy))
ensure
  NxH2.wipe_library!
end

# --- KOV-B1: BEZSTRATOVA BRANA DEFINICII SETOV (audit #17 BLOCKER 1) ---------
#
# H2 riesila bezstratove citanie MAPOVANIA sablony. Definicie setov
# (`hardware_set_defs`) isli dovtedy len cez tolerantny `normalize_sets`, takze
# sablona z novsej verzie by sa do .skp zmrazila UZ OREZANA (a nikto by uz
# nevedel, ze tam nieco bolo). Od KOV-B1 ich obe cesty — VKLAD aj POUZITIE —
# posudia `HardwareSets.assess_set_defs` a odmietnu BEZ zapisu do modelu.

NxTest.test('KOV-B1/H2: definicie setov sa citaju BEZSTRATOVO alebo vobec') do
  hws = NxH2::HWS
  plain = NxH2.set_def('zaves-klasik', 'hinge', '104717')
  klas = plain.merge('use_type' => 'door', 'opening_mode' => 'classic',
                     'manufacturer' => 'Hettich')
  NxTest.assert_equal([:ok, {}], hws.assess_set_defs(nil), 'legacy sablona bez definicii')
  NxTest.assert_equal(:ok, hws.assess_set_defs('zaves-klasik' => plain)[0])
  NxTest.assert_equal(:ok, hws.assess_set_defs('zaves-klasik' => klas)[0], 'nas vlastny tvar')
  # tvary z NOVSEJ verzie / rucne upravena sablona
  {
    'neznamy kluc setu' => plain.merge('rating' => 3),
    'neznamy typ pouzitia' => klas.merge('use_type' => 'sliding'),
    'novy tvar `active`' => plain.merge('active' => 'zajtra'),
    'neznamy kluc clena' => plain.merge('members' => [{ 'code' => 'X', 'per' => 'unit',
                                                        'qty' => 1, 'per_length_mm' => 10 }])
  }.each do |why, bad|
    status, lost = hws.assess_set_defs('zaves-klasik' => bad)
    NxTest.assert_equal(:lossy, status, "#{why}: musi sa ODMIETNUT")
    NxTest.assert_equal(['zaves-klasik'], lost, "#{why}: hlaska menuje definiciu")
  end
  NxTest.assert_equal([:lossy, ['hardware_set_defs']], hws.assess_set_defs(42),
                      'uplne cudzi tvar')
end

NxTest.test('KOV-B1/H2 vklad: sablona s novsimi definiciami sa ODMIETNE (model netknuty)') do
  defs = { 'zaves-klasik' => NxH2.set_def('zaves-klasik', 'hinge', '104717')
                                 .merge('use_type' => 'sliding') }
  params = { 'type' => 'lower', 'hardware_sets' => { 'hinge' => 'zaves-klasik' },
             'hardware_set_defs' => defs }
  status, lost = NxH2::PANEL.take_insert_hardware!(params)
  NxTest.assert_equal(:lossy_defs, status, 'vlastny status = vlastna hlaska pre pouzivatela')
  NxTest.assert_equal(['zaves-klasik'], lost)
  # Brana bezi PRED `prepare_insert` aj pred ghost session — v modeli sa
  # nesmie stat NIC (kontrakt cesty; geometricka cast je in-SU `run_kovb1`).
  s = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_cabinet.rb'))
          .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  body = s[/^        def handle_insert.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo `handle_insert` sa naslo')
  gate = body.index('take_insert_hardware!(params)')
  prep = body.index('CabinetBuilder.prepare_insert(')
  ghost = body.index('GhostTool.start(')
  NxTest.assert(gate && prep && ghost, 'brana, priprava aj ghost su v tele')
  NxTest.assert(gate < prep && gate < ghost, 'brana bezi PRVA — ziadna operacia sa neotvori')
end

NxTest.test('KOV-B1/H2 pouzitie: brana definicii bezi PRED prestavbou') do
  s = File.binread(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog.rb'))
          .force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  body = s[/^        def handle_apply.*?\n        end\n/m].to_s
  NxTest.assert(!body.empty?, 'telo `handle_apply` sa naslo')
  gate = body.index('HardwareSets.assess_set_defs(')
  build = body.index('CabinetBuilder.rebuild_many(')
  NxTest.assert(gate && build, 'brana aj prestavba su v tele')
  NxTest.assert(gate < build, 'brana je PRED prestavbou (ziadny zapis do modelu)')
  NxTest.assert(body.include?('Nepoužitá, nič sa nezmenilo'),
                'a hlaska hovori, ze sa nic nestalo')
end

NxTest.test('KOV-B1/H2: platne definicie prechadzaju a zmrazuju sa ako doteraz') do
  hws = NxH2::HWS
  klas = NxH2.set_def('zaves-vlastny-b1', 'hinge', '104717')
              .merge('use_type' => 'door', 'opening_mode' => 'classic',
                     'manufacturer' => 'Hettich', 'series' => 'Sensys')
  NxH2.wipe_library!
  m = NxH2::Model.new
  res = hws.freeze_template_sets!(m, { 'hinge' => 'zaves-vlastny-b1' }, { 'zaves-vlastny-b1' => klas })
  NxTest.assert_equal(:ok, res['status'])
  NxTest.assert_equal(['zaves-vlastny-b1'], res['added'])
  frozen = m.snapshot_sets['zaves-vlastny-b1']
  NxTest.assert_equal('door', frozen['use_type'], 'klasifikacia sa zmrazi CELA')
  NxTest.assert_equal('Sensys', frozen['series'])
  snap = JSON.parse(m.get_attribute(Noxun::Engine::Store::DICT, hws::MODEL_KEY))
  # KOV-C2a: prvy zapis do prazdneho projektu zmrazi VSETKY globalne predvolby
  # a v seede su od tejto davky sety zasuviek s `height_variant` — snapshot
  # preto dostane std 4. Podstata testu je nezmenena: obsah, ktoremu starsia
  # verzia nerozumie, je pre nu `:invalid`, NIKDY ciastocne precitany.
  NxTest.assert_equal(hws::STD_HEIGHT_VARIANT, snap['std'],
                      'snapshot s klasifikaciou dostane std 4 (starsi plugin ho odmietne)')
ensure
  NxH2.wipe_library!
end
