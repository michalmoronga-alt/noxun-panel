# frozen_string_literal: true
# H8 (R-13) — KONTROLA HLASI KUS Z INEJ VERZIE STANDARDU (`NOXUN/std`).
#
# CO BOLO ZLE: kazda NOXUN entita nesie znacku verzie standardu `std`
# (STANDARD 0 a 2.1: „bez tohto pola je entita predštandardová a systém ju
# označí na revíziu"), ale ZIADNA vetva pluginu ju necitala — „pisem, necitam".
#
# CO PLATI TERAZ:
#   * `Store.read_std` / `Store.std_state_of` — CISTA klasifikacia znacky na
#     :current / :legacy (chyba) / :older / :newer / :invalid; platna je LEN
#     `Integer >= 1` (vzor R-14, ziadny fail-open), vynimka pri citani = :invalid,
#   * `Bom.collect` v TOM ISTOM prechode sklada aditivny kluc `std_issues` —
#     JEDEN zaznam na top-level skrinku (korpus + vyrobne dielce), dosku (pred
#     filtrom manufactured) a samostatny dielec; pri RED `newer_config` nic,
#   * `Validation` z neho robi ORANGE `std_version` (bez brany, bez tlacidla);
#     klik oznaci PRESNE ten kus (`ProductionCore.pids_for_problem`),
#   * kusovnik, VEPO, nakup ani ceny sa NEMENIA — dokaz nizsie nad SKUTOCNYM
#     `Bom.collect` (audit H8 A1), nie len nad textom zdroja.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (UI vrstva).
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') if NxTest.headless?

# Stub SketchUp tried, ktore `ProductionCore.pids_for_problem` pouziva na
# rozlisenie „top-level NOXUN kus" (vzor `test_ghost_d1_dosky.rb` — znovuotvorenie
# je idempotentne). Ta ista trieda posluzi aj zberu (`with_bom_stub`).
unless NxTest::IN_SKETCHUP
  module Noxun
    module Engine
      module ProductionCore
        module Sketchup
          class ComponentInstance; end
          class Model; end
        end
      end
    end
  end
end

module NxH8
  module_function

  E = Noxun::Engine
  ST = E::Store
  BOM = E::Bom
  VAL = E::Validation
  CAT = 'std_version'
  SHEETS = { 'm1' => { 'thickness' => 18.0, 'sheet_size' => [2800.0, 2070.0] } }.freeze
  TAIL = 'Nákup ani výroba sa tým nezastavujú.'
  ADV_FIX = 'Skontroluj rozmery a materiál; prestavba (zmeň a vráť rozmer v Inspectore) značku doplní.'
  ADV_NEW = 'Plugin ju číta podľa svojej verzie — aktualizuj plugin, kým s ňou budeš ďalej pracovať.'

  def src(*parts)
    File.read(File.join(NxTest::ROOT, 'noxun_engine', *parts), encoding: 'UTF-8')
  end

  # FakeEntity s danou znackou: :missing = kluc chyba, inak ulozena hodnota.
  def ent(std)
    e = NxTest::FakeEntity.new
    e.set_attribute(ST::DICT, 'std', std) unless std == :missing
    e
  end

  def raising
    Class.new(NxTest::FakeEntity) do
      def get_attribute(dict, key, default = nil)
        raise IOError, 'poskodeny atribut' if key == 'std'

        super
      end
    end.new
  end
end

# --- fake model pre SKUTOCNY `Bom.collect` (headless) ----------------------
if NxTest.headless?
  NXH8_SU = Noxun::Engine::ProductionCore::Sketchup
  NXH8_ROOT = NXH8_SU::Model.new

  class NxH8Ent < NXH8_SU::ComponentInstance
    Vec = Struct.new(:x, :y, :z) do
      def length
        Math.sqrt((x * x) + (y * y) + (z * z))
      end
    end
    Tr = Struct.new(:origin, :xaxis, :yaxis, :zaxis)
    Bounds = Struct.new(:width, :height, :depth)
    Defn = Struct.new(:entities, :bounds)

    attr_reader :persistent_id, :parent, :definition, :transformation

    # std: Integer/ine = ulozena hodnota, :missing = kluc chyba, :raise = vynimka pri citani.
    def initialize(pid, attrs, std: 1, children: [], root: true)
      super()
      @persistent_id = pid
      @raise_std = std == :raise
      @d = { 'NOXUN' => attrs.dup }
      @d['NOXUN']['std'] = std unless %i[missing raise].include?(std)
      @parent = root ? NXH8_ROOT : Object.new
      @definition = Defn.new(children, Bounds.new(10.0, 10.0, 10.0))
      @transformation = Tr.new(Vec.new(pid.to_f, 0.0, 0.0), Vec.new(1.0, 0.0, 0.0),
                               Vec.new(0.0, 1.0, 0.0), Vec.new(0.0, 0.0, 1.0))
    end

    def valid?
      true
    end

    def get_attribute(dict, key, default = nil)
      raise IOError, 'poskodeny atribut' if @raise_std && key == 'std'

      (@d[dict] || {}).fetch(key, default)
    end

    def set_attribute(dict, key, value)
      (@d[dict] ||= {})[key] = value
    end
  end

  class NxH8Model
    attr_reader :entities

    def initialize(entities)
      @entities = entities
    end

    def get_attribute(_dict, _key, default = nil)
      default
    end

    def find_entity_by_persistent_id(pid)
      @entities.each do |e|
        return e if e.persistent_id == pid
        e.definition.entities.each { |c| return c if c.persistent_id == pid }
      end
      nil
    end
  end

  module NxH8
    module_function

    CFG_PART = { 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0, 'material_id' => 'm1',
                 'edges' => {} }.freeze

    def part(pid, key, std, root: false, manufactured: true, pclass: 'sheet', kind: 'part', extra: {})
      attrs = { 'kind' => kind, 'manufactured' => manufactured, 'production_class' => pclass,
                'name' => key, 'part_key' => key, 'role' => 'side',
                'config' => CFG_PART.to_json }.merge(extra)
      NxH8Ent.new(pid, attrs, std: std, root: root)
    end

    # Scena so VSETKYMI druhmi kusov. `std` = mapa kluc -> znacka (default 1).
    def scene(std = {})
      s = ->(k) { std.fetch(k, 1) }
      sch = Noxun::Engine::CabinetBuilder::CONFIG_SCHEMA
      bsch = Noxun::Engine::BoardBuilder::BOARD_CONFIG_SCHEMA
      cab = NxH8Ent.new(100, { 'kind' => 'cabinet', 'cabinet_id' => 'CAB-001',
                               'config' => { 'config_schema' => sch }.to_json },
                        std: s[:cab], children: [
                          part(101, 'side_l', s[:c_p1]), part(102, 'side_r', s[:c_p2]),
                          part(103, 'nevyrabany', s[:c_nm], manufactured: false),
                          part(104, 'linearny', s[:c_lin], pclass: 'linear'),
                          part(105, 'proxy', s[:c_hw], kind: 'hardware')
                        ])
      cab2 = NxH8Ent.new(200, { 'kind' => 'cabinet', 'cabinet_id' => 'CAB-002',
                                'config' => { 'config_schema' => sch }.to_json },
                         std: s[:cab2], children: [part(201, 'side_l', s[:c2_p1])])
      brd = NxH8Ent.new(300, { 'kind' => 'board', 'id' => 'BRD-001', 'manufactured' => true,
                               'production_class' => 'sheet', 'part_key' => 'board',
                               'config' => CFG_PART.merge('name' => 'Doska').to_json }, std: s[:brd])
      brd_nm = NxH8Ent.new(310, { 'kind' => 'board', 'id' => 'BRD-002', 'manufactured' => false,
                                  'config' => CFG_PART.to_json }, std: s[:brd_nm])
      sp = part(400, 'side_l', s[:sp], root: true,
                                       extra: { 'cabinet_id' => 'CAB-001', 'name' => 'Bok ľavý' })
      sp_noid = part(410, 'polica', s[:sp_noid], root: true, extra: { 'name' => 'Polica' })
      cab_new = NxH8Ent.new(500, { 'kind' => 'cabinet', 'cabinet_id' => 'CAB-009',
                                   'config' => { 'config_schema' => sch + 1 }.to_json },
                            std: s[:cab_new], children: [part(501, 'side_l', s[:cn_p1])])
      brd_new = NxH8Ent.new(600, { 'kind' => 'board', 'id' => 'BRD-009', 'manufactured' => true,
                                   'production_class' => 'sheet', 'part_key' => 'board',
                                   'config' => CFG_PART.merge('config_schema' => bsch + 1).to_json },
                            std: s[:brd_new])
      NxH8Model.new([cab, cab2, brd, brd_nm, sp, sp_noid, cab_new, brd_new])
    end

    # `Bom.collect` cita `Sketchup::ComponentInstance` lexikalne — na cas zberu
    # dostane stub (ta ista trieda ako fake entity); potom sa odstrani, aby
    # nic dalsie v procese nevidelo cudzi `Bom::Sketchup`.
    def collect(model)
      mod = Module.new
      mod.const_set(:ComponentInstance, NXH8_SU::ComponentInstance)
      BOM.const_set(:Sketchup, mod)
      BOM.collect(model)
    ensure
      BOM.send(:remove_const, :Sketchup) if BOM.const_defined?(:Sketchup, false)
    end

    VARIANT = { c_p1: :missing, c_p2: 2, c_nm: :missing, c_lin: 2, c_hw: 'x',
                cab2: :raise, brd: '1', brd_nm: :missing, sp: 2, sp_noid: :missing,
                cab_new: :missing, cn_p1: :missing, brd_new: 3 }.freeze

    def without_std(c)
      c.reject { |k, _| k == :std_issues }
    end
  end
end

# ---------------------------------------------------------------------------
# a) Store.std_state_of — cela matica (R1.2)
# ---------------------------------------------------------------------------

NxTest.test('H8 a: std_state_of — aktualna, chybajuca, starsia, novsia a neplatne znacky') do
  st = NxH8::ST
  NxTest.assert_equal(1, st::STD, 'STD ostava 1 (dávka ho nezvysuje)')
  NxTest.assert_equal(:current, st.std_state_of(:present, 1))
  NxTest.assert_equal(:legacy, st.std_state_of(:missing, nil))
  NxTest.assert_equal(:newer, st.std_state_of(:present, 2))
  NxTest.assert_equal(:invalid, st.std_state_of(:error, nil), 'vynimka pri citani = poskodena')
  # current: 3 — starsie aj novsie sa daju odlisit (buduci bump STD).
  NxTest.assert_equal(:older, st.std_state_of(:present, 1, current: 3))
  NxTest.assert_equal(:older, st.std_state_of(:present, 2, current: 3))
  NxTest.assert_equal(:current, st.std_state_of(:present, 3, current: 3))
  NxTest.assert_equal(:newer, st.std_state_of(:present, 4, current: 3))
  [0, -1, 1.0, 2.0, '1', '', nil, true, false, { 'a' => 1 }, [1], :x].each do |raw|
    NxTest.assert_equal(:invalid, st.std_state_of(:present, raw), "neplatna znacka #{raw.inspect}")
  end
end

# ---------------------------------------------------------------------------
# b) Store.std_state nad entitou (bez vynimky)
# ---------------------------------------------------------------------------

NxTest.test('H8 b: std_state nad entitou — zapis cez Store.write, chybajuci kluc, vynimka, cudzi objekt') do
  st = NxH8::ST
  ok = NxTest::FakeEntity.new
  st.write(ok, std: st::STD, kind: 'part')
  NxTest.assert_equal(:current, st.std_state(ok), 'to, co pise plugin, je aktualne')
  leg = NxTest::FakeEntity.new
  st.write(leg, kind: 'part')
  NxTest.assert_equal(:legacy, st.std_state(leg))
  NxTest.assert_equal([:missing, nil], st.read_std(leg), 'sentinel rozlisi „chyba" od ulozeneho nil')
  NxTest.assert_equal(:newer, st.std_state(NxH8.ent(2)))
  NxTest.assert_equal(:invalid, st.std_state(NxH8.ent(nil)), 'ulozene nil je poskodena znacka, nie chybajuca')
  NxTest.assert_equal(:invalid, st.std_state(NxH8.raising), 'vynimka sa NEPREPUSTI')
  NxTest.assert_equal([:error, nil], st.read_std(NxH8.raising))
  NxTest.assert_equal(:legacy, st.std_state(Object.new), 'objekt bez get_attribute = chybajuca znacka')
  NxTest.assert_equal(:older, st.std_state(NxH8.ent(1), current: 2))
end

# ---------------------------------------------------------------------------
# c) Bom.std_issue — agregacia na top-level objekt
# ---------------------------------------------------------------------------

NxTest.test('H8 c: std_issue — vsetko aktualne = nil, inak JEDEN zaznam s rozpisom stavov') do
  bom = NxH8::BOM
  e = NxH8.method(:ent)
  NxTest.assert_equal(nil, bom.std_issue('cabinet', 'CAB-001', 10, [e[1], e[1], e[1]]))
  NxTest.assert_equal(nil, bom.std_issue('cabinet', 'CAB-001', 10, []))

  leg = bom.std_issue('cabinet', 'CAB-001', 10, [e[1], e[1], e[:missing], e[1], e[:missing], e[1]])
  NxTest.assert_equal({ 'kind' => 'cabinet', 'id' => 'CAB-001', 'owner_pid' => 10, 'pid' => nil,
                        'name' => nil, 'state' => 'legacy', 'std' => nil, 'count' => 2, 'total' => 6,
                        'states' => { 'legacy' => 2 } }, leg)

  mix = bom.std_issue('cabinet', 'CAB-001', 10, [e[1], e[2], e[:missing], e[:missing]])
  NxTest.assert_equal('newer', mix['state'], 'najzavaznejsi stav vyhrava (nie prvy kus)')
  NxTest.assert_equal(2, mix['std'])
  NxTest.assert_equal(3, mix['count'])
  NxTest.assert_equal({ 'newer' => 1, 'legacy' => 2 }, mix['states'])
  # Poradie kusov nemeni vysledok (M11: stav podla prveho kusa).
  NxTest.assert_equal('newer', bom.std_issue('cabinet', 'X', 1, [e[:missing], e[2]])['state'])
  NxTest.assert_equal('invalid', bom.std_issue('cabinet', 'X', 1, [e[:missing], e['1']])['state'])
  NxTest.assert_equal('invalid', bom.std_issue('cabinet', 'X', 1, [NxH8.raising])['state'],
                      'vynimka pri citani je poskodena znacka, nie pad zberu')
  older = bom.std_issue('board', 'BRD-1', 5, [e[1]], current: 2)
  NxTest.assert_equal(%w[older 1], [older['state'], older['std'].to_s])
  NxTest.assert_equal(4, bom.std_issue('cabinet', 'X', 1, [e[2], e[4], e[3]])['std'], 'najvyssia znacka')

  sp = bom.std_issue('part', 'CAB-004', nil, [e[2]], pid: 77, name: 'Bok ľavý')
  NxTest.assert_equal([nil, 77, 'Bok ľavý', 1], [sp['owner_pid'], sp['pid'], sp['name'], sp['total']],
                      'samostatny dielec nesie pid a nazov, nie owner_pid')
end

# ---------------------------------------------------------------------------
# A1 — SKUTOCNY Bom.collect: meni sa LEN `std_issues`
# ---------------------------------------------------------------------------

NxTest.test('H8 A1: Bom.collect — rozne znacky menia LEN std_issues, vsetky ostatne kluce su zhodne') do
  NxTest.skip!('zber nad fake modelom bezi len headless') unless NxTest.headless?
  base = NxH8.collect(NxH8.scene)
  var = NxH8.collect(NxH8.scene(NxH8::VARIANT))
  NxTest.assert_equal([], base[:std_issues], 'vsetko aktualne = ziadny zaznam')
  NxTest.assert(base.key?(:std_issues), 'kluc je vzdy v navrate')
  NxTest.assert_equal(NxH8.without_std(base), NxH8.without_std(var),
                      'records, newer_configs, identity, placements … su HLBOKO zhodne')
  # Kontrola tvaru vstupu: vyrobne zaznamy su vsetky (aj z novsej skrinky a dosky).
  NxTest.assert_equal([101, 102, 201, 300, 400, 410, 501, 600],
                      base[:records].map { |r| r['pid'] }.sort, 'nevyrobne/nie sheet dielce sa nezbieraju')
  NxTest.assert_equal(%w[CAB-009 BRD-009], var[:newer_configs].map { |n| n['id'] })

  got = var[:std_issues]
  NxTest.assert_equal(
    [
      { 'kind' => 'cabinet', 'id' => 'CAB-001', 'owner_pid' => 100, 'pid' => nil, 'name' => nil,
        'state' => 'newer', 'std' => 2, 'count' => 2, 'total' => 3,
        'states' => { 'newer' => 1, 'legacy' => 1 } },
      { 'kind' => 'cabinet', 'id' => 'CAB-002', 'owner_pid' => 200, 'pid' => nil, 'name' => nil,
        'state' => 'invalid', 'std' => nil, 'count' => 1, 'total' => 2, 'states' => { 'invalid' => 1 } },
      { 'kind' => 'board', 'id' => 'BRD-001', 'owner_pid' => 300, 'pid' => nil, 'name' => nil,
        'state' => 'invalid', 'std' => nil, 'count' => 1, 'total' => 1, 'states' => { 'invalid' => 1 } },
      { 'kind' => 'board', 'id' => 'BRD-002', 'owner_pid' => 310, 'pid' => nil, 'name' => nil,
        'state' => 'legacy', 'std' => nil, 'count' => 1, 'total' => 1, 'states' => { 'legacy' => 1 } },
      { 'kind' => 'part', 'id' => 'CAB-001', 'owner_pid' => nil, 'pid' => 400, 'name' => 'Bok ľavý',
        'state' => 'newer', 'std' => 2, 'count' => 1, 'total' => 1, 'states' => { 'newer' => 1 } },
      { 'kind' => 'part', 'id' => '', 'owner_pid' => nil, 'pid' => 410, 'name' => 'Polica',
        'state' => 'legacy', 'std' => nil, 'count' => 1, 'total' => 1, 'states' => { 'legacy' => 1 } }
    ], got,
    'skrinka (korpus + VYROBNE dielce), doska aj nevyrabana, samostatne dielce aj bez ID; ' \
    'novsia skrinka a doska (RED newer_config) bez druheho riadku'
  )
end

NxTest.test('H8 A1: Bom.collect — nevyrobny, linearny a proxy kus vnutri skrinky znacku nehlasi') do
  NxTest.skip!('zber nad fake modelom bezi len headless') unless NxTest.headless?
  c = NxH8.collect(NxH8.scene(c_nm: :missing, c_lin: 2, c_hw: :raise))
  NxTest.assert_equal([], c[:std_issues], 'to, co nejde do vystupov, sa nekontroluje')
  # Samotny vyrobny dielec ano (M7: dielce sa nezbieraju, len skrinka).
  c2 = NxH8.collect(NxH8.scene(c_p2: :missing))
  NxTest.assert_equal([['CAB-001', 1, 3]], c2[:std_issues].map { |i| [i['id'], i['count'], i['total']] })
  # Novsia skrinka: ani poskodeny korpus, ani jej dielce druhy riadok nedaju (R2.4).
  c3 = NxH8.collect(NxH8.scene(cab_new: 'x', cn_p1: 2, brd_new: :missing))
  NxTest.assert_equal([], c3[:std_issues], 'RED newer_config ma prednost (M5)')
end

# ---------------------------------------------------------------------------
# d) Validation.check_std_issues — riadky a vety
# ---------------------------------------------------------------------------

NxTest.test('H8 d: ORANGE std_version — presne vety podla stavu a druhu') do
  val = NxH8::VAL
  run = lambda do |iss|
    items = []
    val.check_std_issues([iss], items)
    items
  end
  NxTest.assert_equal([], [].tap { |o| val.check_std_issues(nil, o) }, 'chybajuci kluc = nic')
  NxTest.assert_equal([], [].tap { |o| val.check_std_issues([], o) })

  cab = run.call('kind' => 'cabinet', 'id' => 'CAB-004', 'owner_pid' => 40, 'state' => 'legacy',
                 'count' => 3, 'total' => 14, 'states' => { 'legacy' => 3 })
  NxTest.assert_equal(1, cab.length)
  it = cab.first
  NxTest.assert_equal(%w[orange std_version CAB-004], [it['severity'], it['category'], it['owner_id']])
  NxTest.assert_equal([40, nil, nil, nil], [it['owner_pid'], it['pid'], it['part_key'], it['hw_key']])
  NxTest.assert_equal('std_version|cabinet|CAB-004|40', it['stable_key'])
  NxTest.assert_equal('Skrinka CAB-004 (3 z 14 kusov): nemá značku verzie štandardu Noxun — kus vznikol mimo ' \
                      "tohto pluginu alebo bol ručne upravený. #{NxH8::ADV_FIX} #{NxH8::TAIL}", it['message_sk'])

  one = run.call('kind' => 'cabinet', 'id' => 'CAB-005', 'owner_pid' => 50, 'state' => 'newer', 'std' => 2,
                 'count' => 1, 'total' => 1, 'states' => { 'newer' => 1 }).first
  NxTest.assert_equal('Skrinka CAB-005: je z novšej verzie štandardu Noxun (značka 2, tento plugin pozná 1). ' \
                      "#{NxH8::ADV_NEW} #{NxH8::TAIL}", one['message_sk'], 'bez rozsahu pri jedinom kuse')

  brd = run.call('kind' => 'board', 'id' => 'BRD-002', 'owner_pid' => 7, 'state' => 'invalid',
                 'count' => 1, 'total' => 1, 'states' => { 'invalid' => 1 }).first
  NxTest.assert_equal("Doska BRD-002: má poškodenú značku verzie štandardu Noxun. #{NxH8::ADV_FIX} #{NxH8::TAIL}",
                      brd['message_sk'])
  old = run.call('kind' => 'board', 'id' => 'BRD-003', 'owner_pid' => 8, 'state' => 'older', 'std' => 1,
                 'count' => 1, 'total' => 1, 'states' => { 'older' => 1 }).first
  NxTest.assert(old['message_sk'].include?('je zo staršej verzie štandardu Noxun (značka 1, aktuálna 1).'),
                old['message_sk'])

  sp = run.call('kind' => 'part', 'id' => 'CAB-004', 'pid' => 77, 'name' => 'Bok ľavý', 'state' => 'legacy',
                'count' => 1, 'total' => 1, 'states' => { 'legacy' => 1 }).first
  NxTest.assert_equal('Samostatný dielec „Bok ľavý“ (zo skrinky CAB-004): nemá značku verzie štandardu Noxun — ' \
                      'kus vznikol mimo tohto pluginu alebo bol ručne upravený. Skontroluj ho ručne — ' \
                      "prestavba ho nezasiahne. #{NxH8::TAIL}", sp['message_sk'])
  NxTest.assert_equal([nil, 77, 'CAB-004'], [sp['owner_pid'], sp['pid'], sp['owner_id']])
  NxTest.assert_equal('std_version|part|CAB-004|77', sp['stable_key'])
  spn = run.call('kind' => 'part', 'id' => 'CAB-004', 'pid' => 78, 'name' => 'Bok', 'state' => 'newer',
                 'std' => 2, 'count' => 1, 'total' => 1, 'states' => { 'newer' => 1 }).first
  NxTest.assert(spn['message_sk'].include?('Plugin ho číta podľa svojej verzie — aktualizuj plugin, kým s ním'),
                spn['message_sk'])
end

NxTest.test('H8 A2: samostatny dielec BEZ cabinet_id sa nestrati — adresa podla PID, veta bez skrinky') do
  items = []
  NxH8::VAL.check_std_issues([{ 'kind' => 'part', 'id' => '', 'pid' => 410, 'name' => 'Bok ľavý',
                                'state' => 'legacy', 'count' => 1, 'total' => 1,
                                'states' => { 'legacy' => 1 } }], items)
  NxTest.assert_equal(1, items.length, 'nalez ostava')
  it = items.first
  NxTest.assert_equal('bez ID (pid 410)', it['owner_id'])
  NxTest.assert_equal(410, it['pid'])
  NxTest.assert(it['message_sk'].start_with?('Samostatný dielec „Bok ľavý“: nemá značku'), it['message_sk'])
  NxTest.refute(it['message_sk'].include?('zo skrinky'), 'netvrdi neznamu prislusnost')
  # Bez nazvu aj bez ID — veta nesie aspon adresu.
  items2 = []
  NxH8::VAL.check_std_issues([{ 'kind' => 'part', 'id' => '', 'pid' => 9, 'state' => 'invalid',
                                'states' => { 'invalid' => 1 }, 'count' => 1, 'total' => 1 }], items2)
  NxTest.assert(items2.first['message_sk'].start_with?('Samostatný dielec bez ID (pid 9): má poškodenú'),
                items2.first['message_sk'])
  # Bez ID AJ bez PID nie je adresa — preskoci sa (R3.2).
  items3 = []
  NxH8::VAL.check_std_issues([{ 'kind' => 'part', 'id' => '', 'state' => 'legacy' },
                              { 'kind' => 'cabinet', 'id' => '  ', 'state' => 'legacy' }], items3)
  NxTest.assert_equal([], items3)
end

NxTest.test('H8 A4: zmiesane stavy — pocet kusov s problemom znacky + rozpis, rada podla najzavaznejsieho') do
  items = []
  NxH8::VAL.check_std_issues([{ 'kind' => 'cabinet', 'id' => 'CAB-004', 'owner_pid' => 4, 'state' => 'newer',
                                'std' => 2, 'count' => 3, 'total' => 14,
                                'states' => { 'newer' => 1, 'legacy' => 2 } }], items)
  NxTest.assert_equal('Skrinka CAB-004 — značka verzie štandardu Noxun nesedí pri 3 z 14 kusov ' \
                      "(1 z novšej verzie, 2 bez značky). #{NxH8::ADV_NEW} #{NxH8::TAIL}", items.first['message_sk'])
  items2 = []
  NxH8::VAL.check_std_issues([{ 'kind' => 'cabinet', 'id' => 'CAB-005', 'owner_pid' => 5, 'state' => 'invalid',
                                'count' => 4, 'total' => 9,
                                'states' => { 'legacy' => 3, 'invalid' => 1 } }], items2)
  NxTest.assert_equal('Skrinka CAB-005 — značka verzie štandardu Noxun nesedí pri 4 z 9 kusov ' \
                      "(1 s poškodenou značkou, 3 bez značky). #{NxH8::ADV_FIX} #{NxH8::TAIL}",
                      items2.first['message_sk'], 'rozpis v poradi zavaznosti')
end

NxTest.test('H8 d: dve kopie so zhodnym ID a roznym PID su DVA riadky (stable_key s PID)') do
  val = NxH8::VAL
  base = { 'kind' => 'cabinet', 'id' => 'CAB-001', 'state' => 'legacy', 'count' => 1, 'total' => 1,
           'states' => { 'legacy' => 1 } }
  out = val.run({ records: [], std_issues: [base.merge('owner_pid' => 1), base.merge('owner_pid' => 2),
                                            base.merge('owner_pid' => 2)] })
  rows = out['items'].select { |i| i['category'] == NxH8::CAT }
  NxTest.assert_equal(['std_version|cabinet|CAB-001|1', 'std_version|cabinet|CAB-001|2'],
                      rows.map { |i| i['stable_key'] }.sort, 'kopie sa nezleju, ten isty kus 2x ano (dedup)')
end

# ---------------------------------------------------------------------------
# e) Validation.run celý + A6 (zelene cislo podla ID — dnesny limit)
# ---------------------------------------------------------------------------

NxTest.test('H8 e: Validation.run — bez kluca bajtovo to iste, s klucom +ORANGE, RED bez zmeny') do
  NxTest.skip!('zber nad fake modelom bezi len headless') unless NxTest.headless?
  val = NxH8::VAL
  base = NxH8.collect(NxH8.scene)
  var = NxH8.collect(NxH8.scene(NxH8::VARIANT))
  run = ->(c) { val.run(c, sheets: NxH8::SHEETS, placements: c[:placements]) }
  r0 = run.call(base)
  NxTest.assert_equal(run.call(NxH8.without_std(base)).to_json, r0.to_json,
                      'prazdny `std_issues` = presne dnesny vystup (legacy volania)')
  r1 = run.call(var)
  NxTest.assert_equal(r0['counts']['red'], r1['counts']['red'], 'RED sa nemeni')
  NxTest.assert_equal(r0['counts']['orange'] + 6, r1['counts']['orange'], '+1 ORANGE na zaznam (6 zaznamov)')
  NxTest.assert(r1['items'].none? { |i| i['category'] == NxH8::CAT && i['severity'] != 'orange' }, 'nikdy RED')
  NxTest.assert_equal(r0['items'], r1['items'].reject { |i| i['category'] == NxH8::CAT },
                      'ostatne riadky Kontroly su tie iste')
  # Zelene cislo: 3 skrinky; CAB-009 je RED v oboch, CAB-001 a CAB-002 pribudnu.
  NxTest.assert_equal([3, 2], [r0['counts']['cabinets'], r0['counts']['clean']])
  NxTest.assert_equal([3, 0], [r1['counts']['cabinets'], r1['counts']['clean']])
  # with_budget prenesie pocty (zelene cislo sa neprepocitava).
  wb = val.with_budget(r1, [{ 'message' => 'x', 'stable_key' => 'b1' }])
  NxTest.assert_equal([r1['counts']['orange'] + 1, 0, 3],
                      [wb['counts']['orange'], wb['counts']['clean'], wb['counts']['cabinets']])
end

NxTest.test('H8 A6: zelene cislo sa pocita podla ID, nie PID — dnesny limit (zladi H3/A-03)') do
  val = NxH8::VAL
  iss = { 'kind' => 'cabinet', 'id' => 'CAB-001', 'state' => 'legacy', 'count' => 1, 'total' => 1,
          'states' => { 'legacy' => 1 } }
  placements = [{ 'kind' => 'cabinet', 'owner_id' => 'CAB-001' }, { 'kind' => 'cabinet', 'owner_id' => 'CAB-001' },
                { 'kind' => 'cabinet', 'owner_id' => 'CAB-002' }]
  out = val.run({ records: [], cabinets: 3,
                  std_issues: [iss.merge('owner_pid' => 1), iss.merge('owner_pid' => 2)] }, placements: placements)
  NxTest.assert_equal(2, out['items'].count { |i| i['category'] == NxH8::CAT }, 'dva riadky')
  NxTest.assert_equal(2, out['counts']['clean'], 'dve problemove kopie so zhodnym ID ubraju zo zeleneho len 1')
end

# ---------------------------------------------------------------------------
# f) zdroj bom.rb — tri vetvy, preskok, navrat, ziadny druhy sken
# ---------------------------------------------------------------------------

NxTest.test('H8 f: zdroj Bom.collect — std_issue v troch vetvach, navrat kluca, ziadny druhy prechod') do
  src = NxH8.src('core', 'bom.rb')
  body = src[/def collect\(model\)(.*?)\n      end\n/m, 1].to_s
  NxTest.assert(!body.empty?, 'telo collect sa naslo')
  NxTest.assert_equal(1, body.scan("std_issue('cabinet'").length)
  NxTest.assert_equal(1, body.scan("std_issue('board'").length)
  NxTest.assert_equal(1, body.scan("std_issue('part'").length)
  NxTest.assert(body.include?('std_issues: std_issues'), 'navrat nesie kluc')
  NxTest.assert(body.include?('unless cab_newer') && body.include?('unless brd_newer'), 'preskok pri newer_config')
  NxTest.assert_equal(2, body.scan('grep(Sketchup::ComponentInstance)').length, 'ziadny druhy sken modelu')
  NxTest.refute(body.include?('set_attribute') || body.include?('Store.write'), 'zber nic nezapisuje')
end

# ---------------------------------------------------------------------------
# g) klik — presne ten kus
# ---------------------------------------------------------------------------

NxTest.test('H8 g: klik na nalez oznaci PRESNE ten kus (skrinka, doska bez ID, samostatny dielec)') do
  NxTest.skip!('stub SketchUp tried bezi len headless') unless NxTest.headless?
  pc = Noxun::Engine::ProductionCore
  model = NxH8.scene(NxH8::VARIANT)
  c = NxH8.collect(model)
  items = NxH8::VAL.run(c, sheets: NxH8::SHEETS)['items'].select { |i| i['category'] == NxH8::CAT }
  by = ->(oid) { items.find { |i| i['owner_id'] == oid } }
  NxTest.assert_equal([100], pc.pids_for_problem(model, by.call('CAB-001')), 'skrinka podla owner_pid')
  NxTest.assert_equal([310], pc.pids_for_problem(model, by.call('BRD-002')), 'nevyrabana doska')
  sp = items.find { |i| i['pid'] == 400 }
  NxTest.assert_equal([400], pc.pids_for_problem(model, sp),
                      'samostatny dielec — NIE aj skrinka CAB-001 a jej vnorene dvojca (M10)')
  NxTest.assert_equal([410], pc.pids_for_problem(model, by.call('bez ID (pid 410)')), 'dielec bez ID podla pid')

  # Doska BEZ vyrobneho ID: adresa „bez ID (pid N)" + owner_pid.
  nb = NxH8Ent.new(700, { 'kind' => 'board', 'manufactured' => true, 'production_class' => 'sheet',
                          'config' => NxH8::CFG_PART.to_json }, std: :missing)
  m2 = NxH8Model.new([nb])
  it2 = NxH8::VAL.run(NxH8.collect(m2), sheets: NxH8::SHEETS)['items'].find { |i| i['category'] == NxH8::CAT }
  NxTest.assert_equal('bez ID (pid 700)', it2['owner_id'])
  NxTest.assert_equal([700], pc.pids_for_problem(m2, it2))

  # Zmiznuty kus = dnesna vseobecna vetva (fail-open, podla owner_id).
  gone = by.call('CAB-001').merge('owner_pid' => 999_999)
  NxTest.assert_equal([100, 400], pc.pids_for_problem(model, gone).sort,
                      'vseobecna vetva: skrinka + samostatne dielce s tym cabinet_id')
  vnoreny = by.call('CAB-001').merge('owner_pid' => 101)
  NxTest.refute(pc.pids_for_problem(model, vnoreny).include?(101), 'vnoreny kus nie je ciel')
end

# ---------------------------------------------------------------------------
# h) exportne brany nedotknute
# ---------------------------------------------------------------------------

NxTest.test('H8 h: exportne brany o std nevedia — ORANGE nic nezastavi') do
  pc = NxH8.src('ui', 'production_core.rb')
  NxTest.refute(pc.include?('std_issues'), 'production_core kluc zberu necita')
  NxTest.assert_equal(1, pc.scan('CAT_STD_VERSION').length, 'kategoria len v klik-resolveri')
  body = pc[/def pids_for_problem\(model, item\)(.*?)\n      end\n/m, 1].to_s
  NxTest.assert(body.include?('CAT_STD_VERSION'), 'a to prave v `pids_for_problem`')
  NxTest.assert(pc.include?('def export_blockers(dups: [], cp: nil, newer: [], hardware: [])'),
                'signatura export_blockers bez zmeny')
  NxTest.assert_equal([], Noxun::Engine::ProductionCore.export_blockers, 'bez vstupu ziadna blokada')
end

# ---------------------------------------------------------------------------
# i) charakterizacia — kusovnik a VEPO rovnake, LOG nesie riadok
# ---------------------------------------------------------------------------

NxTest.test('H8 i: Bom.compute a VEPO CSV su zhodne, sekcia KONTROLA vo VEPO LOGu nesie ORANGE riadok') do
  NxTest.skip!('zber nad fake modelom bezi len headless') unless NxTest.headless?
  bom = NxH8::BOM
  base = NxH8.collect(NxH8.scene)
  var = NxH8.collect(NxH8.scene(NxH8::VARIANT))
  NxTest.assert_equal(bom.compute(base), bom.compute(var), 'kusovnik sa nemeni ani o cislo')
  NxTest.assert_equal(bom.compute(base), bom.compute(base.merge(std_issues: var[:std_issues])),
                      'compute kluc ignoruje')
  vepo = Noxun::Engine::VepoExport
  build = lambda do |c|
    vepo.build(bom.compute(c)[:rows], project: 'H8', validation: NxH8::VAL.run(c, sheets: NxH8::SHEETS),
                                      generated_at: '2026-10-01 12:00')
  end
  b0 = build.call(base)
  b1 = build.call(var)
  NxTest.assert_equal(b0['groups'], b1['groups'], 'CSV objednavky su bajtovo rovnake')
  NxTest.assert(b1['log_text'].include?('[ORANGE] Skrinka CAB-001 — značka verzie štandardu Noxun nesedí'),
                'LOG nesie riadok Kontroly')
  NxTest.refute(b0['log_text'].include?('štandardu Noxun'), 'cista zakazka ho nema')
end
