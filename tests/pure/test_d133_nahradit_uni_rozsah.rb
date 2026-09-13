# frozen_string_literal: true
# Testy D-133 — „NAHRADIT UNI…": ROZSAH ZAKAZKY + ODPOJENY DIELEC.
#
# PRECO tato sada existuje: „Nahradiť UNI…" zbierala skrinky a dosky GLOBALNE
# (`Ids.each_of_kind` = prechod cez `model.definitions`), kym kusovnik, VEPO
# a Studio pracuju len s TOP-LEVEL entitami zakazky. Dva rozne rozsahy pri
# HROMADNOM ZAPISE su vyrobna chyba: vnorena skrinka v zdielanej definicii by
# sa prestavala vo VSETKYCH vyskytoch, a pritom vo vystupoch vobec nie je.
# Druha medzera: odpojeny dielec (vyrobny dielec vytiahnuty na koren modelu,
# ktory kusovnik dalej zbiera cez `cabinet_id`) — prestavba skrinky by ho
# nechala so STARYM materialom a vyrobila DVOJNIKA.
#
# ZAVAZNY KONTRAKT, ktory tu zamykame:
#   1) ROZSAH: `Ids.top_level_scan` = JEDEN prechod `model.entities`. Vnorena
#      skrinka/doska v cudzom komponente sa do nej NEDOSTANE.
#   2) ODPOJENY DIELEC: top-level `part` s `manufactured == true` a vlastnikom
#      v `cabinet_id` zvysuje `detached[cid]`. Dielec bez `manufactured` nie.
#   3) BLOKACIA: skrinka s vyskytom UNI a odpojenym dielcom ide do `blocked`
#      s dovodom `:detached` a NIE do `jobs_cab`. All-or-nothing kontrakt
#      (neprazdny `blocked` zastavi CELU nahradu) sa nemeni.
#   4) SKRINKA BEZ UNI sa odpojenym dielcom NEDOTKNE — nebola v plane ani predtym.
#   5) VETA je JEDNA (`Ids::DETACHED_PART_REASON`) pre „Kresba čiel" aj
#      „Nahradiť UNI…" — pouzivatel nesmie pri tom istom probleme citat dve
#      rozne napravy.
#   6) CHARAKTERIZACIA: zakazka bez vnorenych skriniek a bez odpojenych dielcov
#      ma PRESNE rovnaky plan aj `digest` ako pred davkou.
#
# MUTACIE OVERENE proti tejto sade (kazda ju zhodi):
#   M1 — `replace_uni_scan` spat na `Ids.each_of_kind` -> „rozsah: vnorena
#        skrinka s UNI nie je v `cabs`" + zdrojovy guard
#   M2 — odpojeny dielec NEBLOKUJE -> „blokacia: skrinka s UNI a odpojenym
#        dielcom ide do `blocked`, nie do `jobs_cab`"
#   M3 — `front_grain_scan` ma vlastny prechod -> „zdroj: obe hromadne akcie
#        stoja na `Ids.top_level_scan`"
#   M4 — `ru_blocked_line` nepozna `:detached` (spadne do `else why.to_s`)
#        -> „hlaska: dovod `:detached` je po slovensky a zdielany"
require_relative '../helper' unless defined?(NxTest)

D133IDS = Noxun::Engine::Ids
D133MAT = Noxun::Engine::Materials

# --- Stub SketchUp tried, ktore `Ids.top_level_scan` pouziva na filter korena.
# Stub zije VNUTRI modulu `Ids`, aby ho nasla lexikalna konstanta v jeho
# metodach (vzor `test_ghost_d1_dosky.rb` / `test_r01_observer_multimodel.rb`).
unless NxTest::IN_SKETCHUP
  module Noxun
    module Engine
      module Ids
        module Sketchup
          class ComponentInstance; end
        end
      end
    end
  end
end

if NxTest.headless?
  D133_SU = Noxun::Engine::Ids::Sketchup

  # Duck-typing NOXUN entita. `attrs` = ploche NOXUN kluce; `cfg` sa uklada ako
  # JSON string presne tak, ako ho zapisuje `Store.write_config`.
  class D133Ent < D133_SU::ComponentInstance
    attr_reader :entityID # rubocop:disable Naming/MethodName — zrkadli SketchUp API

    def initialize(attrs, cfg = nil, entity_id = 1)
      super()
      @dict = attrs.transform_keys(&:to_s)
      @dict['config'] = JSON.generate(cfg) unless cfg.nil?
      @entityID = entity_id
    end

    def valid?
      true
    end

    def persistent_id
      @entityID
    end

    def get_attribute(dict, key, default = nil)
      return default unless dict == 'NOXUN'

      @dict.fetch(key.to_s, default)
    end
  end

  # Model s OBOMA pohladmi: `entities` = koren zakazky, `definitions` = globalny
  # prechod, ktorym chodi `Ids.each_of_kind`. Rozdiel medzi nimi je presne to,
  # co D-133 rieši.
  class D133Model
    attr_reader :entities, :definitions

    def initialize(entities, nested = [])
      @entities = entities
      @definitions = [NxTest::FakeDefinition.new(entities + nested)]
      @attrs = {}
    end

    def path
      'C:/tmp/d133.skp'
    end

    def get_attribute(_dict, key, default = nil)
      @attrs.fetch(key.to_s, default)
    end

    def set_project_attr(key, value)
      @attrs[key.to_s] = value
    end
  end

  def d133_cab(cid, cfg = {}, entity_id = 1)
    D133Ent.new({ 'kind' => 'cabinet', 'cabinet_id' => cid },
                { 'part_overrides' => {}, 'type' => 'lower', 'width' => 600.0,
                  'height' => 720.0, 'depth' => 500.0, 'thickness' => 18.0 }.merge(cfg),
                entity_id)
  end

  def d133_board(bid, material_id, entity_id = 2)
    D133Ent.new({ 'kind' => 'board', 'id' => bid },
                { 'material_id' => material_id, 'thickness' => 18.0 }, entity_id)
  end

  # Odpojeny dielec = top-level `part` s vlastnikom v `cabinet_id`.
  def d133_part(cid, entity_id = 3, manufactured: true)
    D133Ent.new({ 'kind' => 'part', 'cabinet_id' => cid,
                  'manufactured' => manufactured, 'production_class' => 'sheet' },
                { 'thickness' => 18.0 }, entity_id)
  end
end

# ---------------------------------------------------------------------------
# 1) ZDIELANY ZBER: Ids.top_level_scan
# ---------------------------------------------------------------------------

NxTest.test('D-133 zber: top-level skrinka a doska su v zakazke, VNORENA nie') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  top_cab = d133_cab('CAB-001')
  top_brd = d133_board('BRD-001', 'X')
  nested  = d133_cab('CAB-NESTED', {}, 9)
  model = D133Model.new([top_cab, top_brd], [nested])

  scan = D133IDS.top_level_scan(model)
  NxTest.assert_equal(['CAB-001'], scan['cabinets'].map { |i| i.get_attribute('NOXUN', 'cabinet_id') })
  NxTest.assert_equal(['BRD-001'], scan['boards'].map { |i| i.get_attribute('NOXUN', 'id') })

  # Kontrolna otazka: GLOBALNY prechod ju NAOPAK vidi — presne v tomto rozdiele
  # zila chyba „Nahradiť UNI…".
  seen = []
  D133IDS.each_of_kind(model, 'cabinet') { |i| seen << i.get_attribute('NOXUN', 'cabinet_id') }
  NxTest.assert_equal(%w[CAB-001 CAB-NESTED], seen.sort, 'each_of_kind vidi aj vnorenu (a to je v poriadku pre CITACIE cesty)')
end

NxTest.test('D-133 zber: odpojeny VYROBNY dielec rata svojmu vlastnikovi') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  model = D133Model.new([d133_cab('CAB-001'),
                         d133_part('CAB-001', 3),
                         d133_part('CAB-001', 4)])
  scan = D133IDS.top_level_scan(model)
  NxTest.assert_equal(2, scan['detached']['CAB-001'])
  NxTest.assert_equal(0, scan['detached']['CAB-999'], 'neznamy vlastnik = 0, nie nil')
end

NxTest.test('D-133 zber: dielec BEZ `manufactured` a dielec BEZ vlastnika sa neratau') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  orphan = D133Ent.new({ 'kind' => 'part', 'manufactured' => true }, {}, 5)
  model = D133Model.new([d133_cab('CAB-001'),
                         d133_part('CAB-001', 6, manufactured: false),
                         orphan])
  scan = D133IDS.top_level_scan(model)
  NxTest.assert_equal(0, scan['detached']['CAB-001'], 'nevyrobny dielec nie je vyrobna hrozba')
  NxTest.assert_equal(1, scan['cabinets'].size)
end

NxTest.test('D-133 zber: NEPLATNA entita zber nezhodi (D-34 erase okno)') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  dead = d133_cab('CAB-DEAD', {}, 7)
  def dead.valid?
    false
  end

  def dead.get_attribute(*)
    raise TypeError, 'deleted entity'
  end
  model = D133Model.new([d133_cab('CAB-001'), dead])
  scan = D133IDS.top_level_scan(model)
  NxTest.assert_equal(['CAB-001'], scan['cabinets'].map { |i| i.get_attribute('NOXUN', 'cabinet_id') })
end

NxTest.test('D-133 zber: bez modelu je vysledok prazdny (nie chyba)') do
  scan = D133IDS.top_level_scan(nil)
  NxTest.assert_equal([], scan['cabinets'])
  NxTest.assert_equal([], scan['boards'])
  NxTest.assert_equal(0, scan['detached']['CAB-001'])
end

# ---------------------------------------------------------------------------
# 2) ROZSAH „Nahradiť UNI…" (adapter scan)
# ---------------------------------------------------------------------------

NxTest.test('D-133 rozsah: vnorena skrinka s UNI nie je v `cabs`, top-level ano') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  uni = 'K009_PW_DTDL_18'
  top = d133_cab('CAB-001', { 'material_id' => uni })
  nested = d133_cab('CAB-NESTED', { 'material_id' => uni }, 9)
  brd_top = d133_board('BRD-001', uni)
  brd_nested = d133_board('BRD-NESTED', uni, 8)
  model = D133Model.new([top, brd_top], [nested, brd_nested])

  scan = D133MAT.replace_uni_scan(model, uni)
  NxTest.assert_equal(['CAB-001'], scan['cabs'].map(&:first))
  NxTest.assert_equal(['BRD-001'], scan['boards'].map(&:first))
end

NxTest.test('D-133 rozsah: scan nesie mapu odpojenych dielcov (aditivny kluc)') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  uni = 'K009_PW_DTDL_18'
  model = D133Model.new([d133_cab('CAB-001', { 'material_id' => uni }),
                         d133_part('CAB-001', 3)])
  scan = D133MAT.replace_uni_scan(model, uni)
  NxTest.assert_equal(1, scan['detached']['CAB-001'])
  # `cabs` je pole poli s PEVNYMI indexmi — do stredu sa nic vkladat nesmie.
  NxTest.assert_equal(5, scan['cabs'][0].size, 'tvar zaznamu skrinky sa nezmenil')
end

# ---------------------------------------------------------------------------
# 3) KLASIFIKACIA: odpojeny dielec BLOKUJE
# ---------------------------------------------------------------------------

D133_UNI_BODY = 'K009_PW_DTDL_18'

NxTest.test('d133 setup: cerstvy SCHEMA 2 seed s UNI sadou') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!, 'fresh seed sa nenainstaloval')
end

def d133_seed_target
  ok, res = D133MAT.add_decor_batch(
    'batch_schema' => 3, 'decor' => 'D133T', 'manufacturer' => 'Egger',
    'decor_name' => 'Testovaci dub', 'type' => 'DTDL', 'grain' => 'length',
    'color' => [10, 20, 30],
    'sheet_variants' => [{ 'thickness' => 18.0, 'structure' => 'ST9' }],
    'edge_variants' => [{ 'width' => 23.0, 'thickness' => 1.0, 'structure' => 'ST9' }]
  )
  raise "seed D133T zlyhal: #{res.inspect}" unless ok

  res
end

def d133_cleanup(res)
  return unless res

  (res['sheets'] || []).each { |id| D133MAT.delete_sheet(id) }
  (res['edges'] || []).each { |id| D133MAT.delete_edge(id) }
end

def d133_params(over = {})
  { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 500.0,
    'thickness' => 18.0 }.merge(over)
end

def d133_eff(body = D133_UNI_BODY)
  { 'body' => body, 'front' => 'W1000_DTDL_18', 'back' => 'HDF_WHITE_3' }
end

def d133_scan(cabs, detached = nil)
  out = { 'cabs' => cabs, 'boards' => [], 'project' => {}, 'model_guid' => 'G-1' }
  out['detached'] = detached unless detached.nil?
  out
end

NxTest.test('D-133 blokacia: skrinka s UNI a odpojenym dielcom ide do `blocked`') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d133_seed_target
  begin
    target = D133MAT.sheet((res['sheets'] || []).first)
    cabs = [['CAB-001', d133_params('material_id' => D133_UNI_BODY), d133_eff, 'raw1', :r1]]
    out = D133MAT.replace_uni_classify(d133_scan(cabs, { 'CAB-001' => 1 }),
                                       D133MAT.sheet(D133_UNI_BODY), target)
    NxTest.assert_equal([['CAB-001', :detached, []]], out['blocked'])
    NxTest.assert_equal([], out['jobs_cab'], 'blokovana skrinka sa NEPRESTAVUJE')
    NxTest.assert_equal([], out['adopting'])
    NxTest.assert_equal([], out['recompute'])
    NxTest.refute(D133MAT.replace_uni_empty?(out), 'blokacia NIE JE „niet co nahradit"')
  ensure
    d133_cleanup(res)
  end
end

NxTest.test('D-133 blokacia: dovod je PRVY — pyta sa PRED hrubkami') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d133_seed_target
  begin
    target = D133MAT.sheet((res['sheets'] || []).first)
    # Skrinka ma UNI na CELE aj odpojeny dielec. Ktorykolvek hrubkovy dovod by
    # pouzivatela poslal opravovat nespravnu vec — odpojeny dielec je tvrdsi.
    cabs = [['CAB-007', d133_params('front_material_id' => 'W1000_DTDL_18'),
             d133_eff, 'raw7', :r7]]
    out = D133MAT.replace_uni_classify(d133_scan(cabs, { 'CAB-007' => 3 }),
                                       D133MAT.sheet('W1000_DTDL_18'), target)
    NxTest.assert_equal([:detached], out['blocked'].map { |b| b[1] })
  ensure
    d133_cleanup(res)
  end
end

NxTest.test('D-133 blokacia: skrinka BEZ vyskytu UNI sa odpojenym dielcom NEDOTKNE') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d133_seed_target
  begin
    target = D133MAT.sheet((res['sheets'] || []).first)
    # Skrinka je cela na realnom dekore — v plane nebola ani predtym, takze
    # odpojeny dielec nema co blokovat (inak by sa zakazka zasekla na skrinke,
    # ktorej sa akcia vobec netyka).
    cabs = [['CAB-002', d133_params('material_id' => target['material_id']),
             d133_eff(target['material_id']), 'raw2', :r2]]
    out = D133MAT.replace_uni_classify(d133_scan(cabs, { 'CAB-002' => 2 }),
                                       D133MAT.sheet(D133_UNI_BODY), target)
    NxTest.assert_equal([], out['blocked'])
    NxTest.assert_equal([], out['jobs_cab'])
    NxTest.assert(D133MAT.replace_uni_empty?(out), 'niet co nahradit')
  ensure
    d133_cleanup(res)
  end
end

# ---------------------------------------------------------------------------
# 4) HLASKA
# ---------------------------------------------------------------------------

NxTest.test('D-133 hlaska: dovod `:detached` je po slovensky a ZDIELANY') do
  line = D133MAT.ru_blocked_line('CAB-001', :detached, [])
  NxTest.assert(line.start_with?('CAB-001 — '), line)
  NxTest.assert(line.include?('odpojený dielec'), line)
  NxTest.assert(line.include?(D133IDS::DETACHED_PART_REASON),
                'veta musi byt zo zdielanej konstanty, nie kopia')
  # „Kresba čiel" (D-131) pouziva TU ISTU vetu — dve kopie by sa rozisli.
  ent = { 'detached' => true }
  NxTest.assert_equal(D133IDS::DETACHED_PART_REASON,
                      Noxun::Engine::ProductionCore.front_grain_skip_reason(ent))
end

# ---------------------------------------------------------------------------
# 4b) SLEPA ULICKA: UNI LEN VO VNORENEJ SKRINKE
#
# Dekor pouzity v modeli LEN vo vnorenej skrinke by pouzivatela zasekol:
# nahradenie ho nevidi (rozsah = zakazka) a zmazanie v katalogu ho ODMIETNE
# („používa sa 1×", delete guard je GLOBALNY). Hlaska musi povedat, KDE je.
# ---------------------------------------------------------------------------

if NxTest.headless?
  D133MD = Noxun::Engine::MaterialsDialog

  NxTest.test('D-133 hlaska: UNI len vo vnorenej skrinke povie, KDE je a co s tym') do
    uni = 'K009_PW_DTDL_18'
    model = D133Model.new([], [d133_cab('CAB-NESTED', { 'material_id' => uni }, 9)])
    msg = D133MD.ru_empty_msg(model, uni, 'Korpus UNI')
    NxTest.assert(msg.include?('len mimo zákazky'), msg)
    NxTest.assert(msg.include?('vnorená v inom komponente'), msg)
    NxTest.assert(msg.include?('koreň modelu'), 'hlaska musi dat NAPRAVU, nie len diagnozu')
  end

  NxTest.test('D-133 hlaska: dekor NIKDE = povodna veta „niet čo nahradiť"') do
    model = D133Model.new([d133_cab('CAB-001', { 'material_id' => 'INY_DEKOR' })])
    msg = D133MD.ru_empty_msg(model, 'K009_PW_DTDL_18', 'Korpus UNI')
    NxTest.assert_equal('Korpus UNI sa v projekte nepoužíva — niet čo nahradiť.', msg)
  end
end

# ---------------------------------------------------------------------------
# 5) CHARAKTERIZACIA: zakazka bez vnorenych a bez odpojenych sa NEMENI
# ---------------------------------------------------------------------------

NxTest.test('D-133 charakterizacia: plan aj digest su bez `detached` NEZMENENE') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d133_seed_target
  begin
    target = D133MAT.sheet((res['sheets'] || []).first)
    uni = D133MAT.sheet(D133_UNI_BODY)
    # KAZDE volanie dostane CERSTVE `params` — klasifikacia ich mutuje na mieste
    # (adapter ich preto vyraba ako kopie). Zdielany hash by druhe volanie
    # ukazal uz PREPISANY a test by meral nieco ine, nez mysli.
    cabs = -> { [['CAB-001', d133_params('material_id' => D133_UNI_BODY), d133_eff, 'raw1', :r1]] }

    legacy = D133MAT.replace_uni_classify(d133_scan(cabs.call), uni, target)      # scan BEZ kluca
    empty  = D133MAT.replace_uni_classify(d133_scan(cabs.call, {}), uni, target)  # prazdna mapa
    other  = D133MAT.replace_uni_classify(d133_scan(cabs.call, { 'CAB-999' => 4 }), uni, target)

    NxTest.assert_equal(legacy['digest'], empty['digest'], 'prazdna mapa nesmie hnut odtlackom')
    NxTest.assert_equal(legacy['digest'], other['digest'], 'cudzi vlastnik sa tejto skrinky netyka')
    NxTest.assert_equal([], legacy['blocked'])
    NxTest.assert_equal(1, legacy['jobs_cab'].size)
    NxTest.assert_equal(legacy['summary'], other['summary'])

    # A naopak: odpojeny dielec odtlacok ZMENIT MUSI — inak by sa dalo potvrdit
    # potvrdenie vydane pred vytiahnutim dielca.
    blocked = D133MAT.replace_uni_classify(d133_scan(cabs.call, { 'CAB-001' => 1 }), uni, target)
    NxTest.refute(legacy['digest'] == blocked['digest'], 'blokacia MUSI zmenit odtlacok planu')
  ensure
    d133_cleanup(res)
  end
end

# ---------------------------------------------------------------------------
# 6) ZDROJOVE GUARDY
# ---------------------------------------------------------------------------

D133_RU_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'materials_replace_uni.rb'),
                        encoding: 'UTF-8')
D133_PC_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core.rb'),
                        encoding: 'UTF-8')
# Komentare sa zo zdroja ODSTRANUJU — guard sa pyta na KOD. Bez toho by
# staclo, aby meno helpera ostalo vo vysvetlujucej vete, a mutacia „vlastny
# prechod nazad" by presla.
def d133_code_only(src)
  src.lines.reject { |l| l.strip.start_with?('#') }.join
end

D133_SCAN_SRC = d133_code_only(D133_RU_SRC[/def replace_uni_scan.*?\n      end\n/m].to_s)
D133_FG_SRC = d133_code_only(D133_PC_SRC[/def front_grain_scan.*?\n      end\n/m].to_s)

NxTest.test('D-133 zdroj: obe hromadne akcie stoja na `Ids.top_level_scan`') do
  NxTest.assert(D133_SCAN_SRC.include?('Ids.top_level_scan'),
                '„Nahradiť UNI…" musi zbierat rozsah zakazky')
  NxTest.refute(D133_SCAN_SRC.include?('each_of_kind'),
                'globalny prechod cez definicie je pri HROMADNOM ZAPISE chyba')
  NxTest.assert(D133_FG_SRC.include?('Ids.top_level_scan'),
                '„Kresba čiel" musi zdielat TEN ISTY zber')
  NxTest.refute(D133_FG_SRC.include?('model.entities.grep'),
                'druhy vlastny prechod by sa casom rozisiel')
end
