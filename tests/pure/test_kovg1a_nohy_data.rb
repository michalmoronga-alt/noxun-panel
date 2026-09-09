# frozen_string_literal: true
# Testy KOV-G1a: NOHY 17-220 mm, HÄFELE, SETY, PRICHYT SOKLA (datova vrstva).
#
# Co davka slubuje (a co tieto testy strazia):
#   R1 set „Nohy podľa výšky sokla" pokryva KAZDU vysku sokla 17-220 mm okrem
#      VEDOME nepokrytej zony 20-55 mm; hranice pasiem su VRATANE a vyska
#      medzi pasmami (90,5) je ORANGE — nikdy najblizsie pasmo
#   R2 PLATNICKA je na kazdu nohu AXILO; pri klzaku 17-20 mm ma pasmo `none`
#      („v tomto pasme clen vedome nevznika") -> ziadny riadok a ZIADNY nalez.
#      CHYBAJUCE pasmo ostava ORANGE `param_band_missing` -> Kontrola hovori
#      o VYSKE SOKLA
#   R3 marker kompatibility: sentinel v KODOVOM pasme nesie ten isty `std` 5
#      ako v rade `code_by_nl` (starsi plugin obsah odmietne, nikdy z neho
#      nevyrobi nakupny riadok s kodom „none")
#   R4 migracia kniznice: NEDOTKNUTY stary tvar setu nôh sa nahradi novym,
#      pouzivatelom upraveny set ostava; do PROJEKTU ho prenesie az vedome
#      „Doplniť nové predvoľby"
#   R5 novy typ kovania `plinth_clip` + set „Príchyt sokla AXILO" + mapovanie
#      (add-if-absent, vlastna volba sa NIKDY neprepise); popisok „Príchyt
#      sokla" je rovnaky na VSETKYCH miestach a starsi citac set ODMIETNE
#   R6 katalog: patch v5 doplna LEN vymenovanych 9 kodov, riadok 367823
#      obohaci o vyrobcu/radu LEN ked su OBE prazdne, a polozky s dvojicou
#      Hettich+AXILO presunie pod Häfele (radu presunula migracia taxonomie)
#   R7 taxonomia: vyrobca Häfele a rada AXILO pod nim; PRESNE stary seed tvar
#      sa presunie, pouzivatelska rada („AXILO plus", vlastny vlastnik) NIE
#   R8 dodavatel QUATRO LM: riadky NEMAJU `demos_url` (a teda ani datum
#      overenia), dodavatel je v poli `supplier` a jeho adresa v poznamke
#
# MUTACIE (kazda overena rucne — po zaneseni chyby spadne uvedeny test):
#   M1 `member_code` prestane pre pasmo `none` vracat [nil, nil] (vrati kod)
#      -> „KOV-G1a (R2): pasmo `none` nevyda riadok ani nalez"
#   M2 pasmo nohy 17-20 sa roztiahne na 17-54 (VEDOME nepokryta zona 20-55 mm
#      dostane kod 272212) -> „KOV-G1a (R1): tabulka vysok sokla…" + „(R2):
#      pasmo `none` nevyda riadok…" + „(R2): Kontrola pri vyske mimo pasiem…"
#   M3 `enrich_axilo_150` prestane kontrolovat prazdnu klasifikaciu (prepise ju
#      vzdy) -> „KOV-G1a (R6): patch v5 — 367823 s VLASTNOU klasifikaciou ostava"
#   M4 `member_skip_code?` prestane pozerat do `param_bands`
#      -> „KOV-G1a (R3): sentinel v kodovom pasme = std 5"
#   M5 `migrate_axilo_owner!` prestane overovat, ze radu vlastni Hettich
#      -> „KOV-G1a (R7): pouzivatelska rada sa NEPRESUNIE"
#
# CODEX #337 KOLO 1 — co pribudlo (a mutacie, ktore to strazia):
#   N1 clen so samymi `none` kodmi sa NEULOZI (pasma aj rad) a set, ktory pre
#      BEZNU polozku nevyda NIC, je viditelny ORANGE `members_all_skipped`
#      M6 `validate_param_bands` prestane kontrolovat „vsetky pasma none"
#         -> „(Codex #337 N1): clen, ktoreho su VSETKY pasma `none`, sa NEULOZI"
#      M7 `set_empty_reason` vrati vzdy `members_skipped`
#         -> „(Codex #337 N1): set, ktory pre polozku nevyda NIC, je ORANGE"
#      M8 fallback sa vrati k `return unless recipe_or_lift?(it)` (tiche nic)
#         -> to iste („MUSI vzniknut zaznam")
#   N2 vlastnika rady AXILO urcuje ZIVA taxonomia
#      M9 `fix_axilo_manufacturer` sa vrati k odvodeniu vlastnika zo seedu
#         -> „(Codex #337 N2): AXILO pod VLASTNYM vyrobcom — katalog sa NEDOTKNE"
#   N3 seed set s cudzou vazbou rady sa instaluje BEZ klasifikacie
#      M10 `seed_sets_resolved` prestane citat taxonomiu (owner = nil)
#         -> „(Codex #337 N3): seed set s cudzou vazbou rady sa instaluje BEZ zaradenia"
#   N4 genericky kluc mapovania overuje `generic_type` cieloveho setu
#      M11 `mapping_seed_ref_ok?` sa vrati k „len pritomnost"
#         -> „(Codex #337 N4): predvolba prichytu sa NEDOPLNI na set INEHO typu"
require_relative '../helper' unless defined?(NxTest)

module NxG1a
  E     = Noxun::Engine
  HWS   = E::HardwareSets
  HWC   = E::HardwareCatalog
  TAX   = E::HardwareTaxonomy
  BP    = E::BuildPlan
  STORE = E::JsonFileStore

  LEG_SET   = 'nohy-podla-sokla'
  CLIP_SET  = 'prichyt-sokla-axilo'
  CLIP_TYPE = 'plinth_clip'

  # TABULKOVA FIXTURA — prepisana RUCNE z rozhodnuti Michala (9.9.2026), nie
  # odvodena zo seedu. `nil` = vyska, ktora VEDOME nema kod (zona 20-55 mm
  # a nad 220 mm) -> ORANGE „doplň pásmo".
  NOHA_PRE_VYSKU = {
    17.0 => '272212', 20.0 => '272212',
    40.0 => nil,
    55.0 => '9069', 90.0 => '9069',
    91.0 => '9078', 115.0 => '9078',
    116.0 => '9077', 140.0 => '9077',
    141.0 => '9076', 170.0 => '9076',
    171.0 => '9027', 190.0 => '9027',
    191.0 => '9075', 220.0 => '9075',
    221.0 => nil
  }.freeze

  # Platnicka: `false` = pasmo VYPLNENE sentinelom (clen sa vedome nevyda),
  # nil = pasmo CHYBA (ORANGE), inak kod.
  PLATNICKA_PRE_VYSKU = {
    17.0 => false, 20.0 => false,
    40.0 => nil, 221.0 => nil
  }.freeze

  module_function

  def seed_norm
    HWS.normalize_sets(HWS::SEED_SETS)
  end

  def set_of(sid)
    seed_norm.find { |s| s['set_id'] == sid }
  end

  def state(sets = seed_norm, mapping = HWS::SEED_MAPPING)
    by_id = {}
    sets.each { |s| by_id[s['set_id']] = s }
    { 'mapping' => mapping.dup, 'sets' => by_id }
  end

  def leg_item(height, over = {})
    { 'owner_id' => 'CAB-1', 'owner_part_key' => nil, 'generic_type' => 'leg',
      'quantity' => 4, 'rule_id' => 'nohy-zakladne', 'source' => 'rule',
      'params' => height.nil? ? {} : { 'height' => height } }.merge(over)
  end

  def codes(exp)
    exp['rows'].map { |r| r['code'] }.sort
  end

  # --- sandbox taxonomie (vzor `test_kovb1_taxonomia.rb`) -------------------
  # Migracie od Codex #337 (N2/N3) sa pytaju ZIVEJ taxonomie, takze test musi
  # vediet postavit konkretny stav suboru a po sebe upratat.

  def with_taxonomy
    path = TAX.path
    before = (File.binread(path) if File.exist?(path))
    bak = (File.binread("#{path}.bak") if File.exist?("#{path}.bak"))
    yield
  ensure
    if before then File.binwrite(path, before) else FileUtils.rm_f(path) end
    if bak then File.binwrite("#{path}.bak", bak) else FileUtils.rm_f("#{path}.bak") end
    STORE.invalidate(path)
    TAX.reset_state!
  end

  # Zapise dokument PRIAMO na disk (obide brany) a zhodi cache aj stav.
  def install_tax(mans, sers)
    FileUtils.mkdir_p(File.dirname(TAX.path))
    File.binwrite(TAX.path,
                  JSON.pretty_generate('std' => TAX::STD, 'schema' => TAX::SCHEMA_CURRENT,
                                       'seed_version' => TAX::SEED_VERSION,
                                       'manufacturers' => mans.map { |n| { 'name' => n } },
                                       'series' => sers.map { |(n, m)| { 'name' => n, 'manufacturer' => m } }))
    STORE.invalidate(TAX.path)
    TAX.reset_state!
    true
  end

  # --- sandbox globalnej kniznice (vzor `test_kovb1_sety.rb`) ---------------

  def with_library
    paths = [HWS.path, TAX.path]
    before = paths.map { |p| [p, (File.exist?(p) ? File.binread(p) : nil)] }
    yield
  ensure
    before.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
      FileUtils.rm_f("#{p}.bak")
      STORE.invalidate(p)
    end
    HWS.reset_library_state!
    TAX.reset_state!
  end

  def install_lib(sets, mapping = {}, seed_version = HWS::SEED_VERSION)
    FileUtils.mkdir_p(File.dirname(HWS.path))
    File.binwrite(HWS.path,
                  JSON.pretty_generate('std' => HWS::STD_SKIP_CODE, 'seed_version' => seed_version,
                                       'sets' => sets, 'mapping' => mapping))
    FileUtils.rm_f("#{HWS.path}.bak")
    STORE.invalidate(HWS.path)
    HWS.reset_library_state!
    true
  end

  # Set, aky sa DAL ULOZIT vo verziach so sentinelom `none` (D-118b): prvy clen
  # nema ANI JEDEN skutocny kod, druhy je uplne bezny. `kind` = :nl | :bands.
  def legacy_all_none_set(kind)
    prvy = if kind == :nl
             { 'per' => 'unit', 'qty' => 1, 'code_by_nl' => { '350' => 'none', '420' => 'none' } }
           else
             { 'per' => 'unit', 'qty' => 1,
               'param_bands' => { 'param' => 'height',
                                  'bands' => [{ 'min' => 17.0, 'max' => 220.0, 'code' => 'none' }] } }
           end
    { 'set_id' => 'legacy-none', 'name' => 'Legacy none', 'generic_type' => 'leg',
      'members' => [prvy, { 'per' => 'unit', 'qty' => 1, 'code' => '9069' }] }
  end

  # Kopia seed setu nôh s upravenym clenom (pre negativne varianty).
  def leg_set_with(member_index)
    copy = Marshal.load(Marshal.dump(set_of(LEG_SET)))
    yield copy['members'][member_index]
    copy
  end

  # Minimalny model (vzor `test_h1a_sety.rb`) — snapshot v NOXUN dict.
  class Model
    def initialize
      @attrs = {}
    end

    def get_attribute(dict, key)
      (@attrs[dict] || {})[key]
    end

    def set_attribute(dict, key, val)
      (@attrs[dict] ||= {})[key] = val
    end
  end
end

# ============================================================================
# R1 — TABULKA VYSOK SOKLA
# ============================================================================

NxTest.test('KOV-G1a (R1): tabulka vysok sokla (tabulkova fixtura)') do
  c = NxG1a
  st = c.state
  c::NOHA_PRE_VYSKU.each do |vyska, kod|
    exp = c::HWS.expand([c.leg_item(vyska)], st, catalog: [])
    noha = exp['rows'].find { |r| r['code'] == kod }
    if kod.nil?
      NxTest.assert_equal([], exp['rows'], "sokel #{vyska} mm NEMA mat kod")
      NxTest.assert_equal(%w[param_band_missing param_band_missing],
                          exp['unmapped'].map { |u| u['reason'] },
                          "sokel #{vyska} mm: ORANGE na OBOCH clenoch")
    else
      NxTest.assert(noha, "sokel #{vyska} mm chce nohu #{kod} (#{c.codes(exp).inspect})")
      NxTest.assert_equal(4, noha['quantity'], "sokel #{vyska} mm: 4 nohy")
    end
  end
end

NxTest.test('KOV-G1a (R1): neceloselna vyska MEDZI pasmami je ORANGE, nikdy susedny kod') do
  c = NxG1a
  st = c.state
  # Pasma su celociselne rozsahy (55-90, 91-115): 90,5 mm do ziadneho nepatri.
  # Je to VEDOMA vlastnost — vysky sokla su v praxi z rozmeroveho radu a
  # „najblizsie pasmo" by objednalo inu nohu (ta ista filozofia ako presny
  # kluc radu NL, nikdy sused).
  # Platnicka ma JEDNO spojite pasmo 55-220, takze tu ORANGE dostane iba NOHA
  # — a to je presne ta veta, ktoru ma clovek vidiet („55-90 alebo 91-115").
  exp = c::HWS.expand([c.leg_item(90.5)], st, catalog: [])
  NxTest.assert_equal(['9079'], c.codes(exp), 'ziadna NOHA — nikdy susedne pasmo')
  NxTest.assert_equal(['param_band_missing'], exp['unmapped'].map { |u| u['reason'] })
  NxTest.assert_equal(0, exp['unmapped'].first['member_index'], 'nemapovana je noha')
  NxTest.assert_equal(90.5, exp['unmapped'].first['value'])
  # A hranice pasiem su VRATANE — 90 aj 91 kod MAJU.
  NxTest.assert(c::HWS.expand([c.leg_item(90.0)], st, catalog: [])['rows'].any?)
  NxTest.assert(c::HWS.expand([c.leg_item(91.0)], st, catalog: [])['rows'].any?)
end

# ============================================================================
# R2 — PLATNICKA A SENTINEL `none` V KODOVOM PASME
# ============================================================================

NxTest.test('KOV-G1a (R2): pasmo `none` nevyda riadok ani nalez') do
  c = NxG1a
  st = c.state
  c::PLATNICKA_PRE_VYSKU.each do |vyska, ocakavane|
    exp = c::HWS.expand([c.leg_item(vyska)], st, catalog: [])
    if ocakavane.nil? # chybajuce pasmo — ORANGE je overeny v R1
      NxTest.assert_equal([], c.codes(exp), "sokel #{vyska} mm nema vydat ziadny riadok")
      next
    end
    # Riadok setu je PRESNE noha — ziadny druhy, a uz vobec nie s doslovnym
    # kodom „none" (ten by sa dostal do nakupu aj do CSV).
    NxTest.assert_equal([c::NOHA_PRE_VYSKU[vyska]], c.codes(exp),
                        "sokel #{vyska} mm: platnicka sa VEDOME nevyda")
    NxTest.assert_equal([], exp['unmapped'],
                        "sokel #{vyska} mm: vedome prazdne pasmo NIE JE problem")
  end
  # Od 55 mm ide platnicka na KAZDU nohu (rovnaky pocet ako noha).
  exp = c::HWS.expand([c.leg_item(150.0)], st, catalog: [])
  NxTest.assert_equal(%w[9076 9079], c.codes(exp), 'noha + platnicka')
  exp['rows'].each { |r| NxTest.assert_equal(4, r['quantity'], r['code']) }
  NxTest.assert_equal([], exp['unmapped'])
end

NxTest.test('KOV-G1a (R2): CHYBAJUCE pasmo je ORANGE — rozdiel oproti `none` je ZAMER') do
  c = NxG1a
  # Ta ista vyska (17 mm), len platnicke sa pasmo `none` ODOBERIE.
  bez = c.leg_set_with(1) { |m| m['param_bands']['bands'].reject! { |b| b['min'] == 17.0 } }
  st = c.state(c.seed_norm.map { |s| s['set_id'] == c::LEG_SET ? bez : s })
  exp = c::HWS.expand([c.leg_item(17.0)], st, catalog: [])
  NxTest.assert_equal(['272212'], c.codes(exp), 'noha sa objedna dalej')
  NxTest.assert_equal(['param_band_missing'], exp['unmapped'].map { |u| u['reason'] },
                      'chybajuce pasmo = nemapovany clen')
  NxTest.assert_equal(1, exp['unmapped'].first['member_index'], 'a je to PLATNICKA')
end

NxTest.test('KOV-G1a (R2): Kontrola pri vyske mimo pasiem hovori o VYSKE SOKLA') do
  c = NxG1a
  exp = c::HWS.expand([c.leg_item(40.0)], c.state, catalog: [])
  res = c::E::Validation.run({}, hardware_expansion: exp)
  items = res['items'].select { |i| i['category'] == 'hardware_unmapped' }
  NxTest.assert_equal(2, items.length, 'noha aj platnicka')
  NxTest.assert_equal(res['counts']['orange'], items.length, 'ORANGE, nikdy RED')
  items.each do |i|
    NxTest.assert(i['message_sk'].include?('výšku sokla 40 mm'),
                  "veta musi menovat vysku sokla: #{i['message_sk']}")
    NxTest.assert(i['message_sk'].include?('doplň pásmo'), i['message_sk'])
  end
end

NxTest.test('KOV-G1a (R2): supis (explain) preskoceny clen PRIZNA, nemlci') do
  c = NxG1a
  ex = c::HWS.explain(c.leg_item(17.0), c.state)
  NxTest.assert_equal([], ex['problems'], ex['problems'].inspect)
  skipped = ex['members'].select { |m| m['skipped'] }
  NxTest.assert_equal(1, skipped.length, 'platnicka je v supise ako vedome preskocena')
  NxTest.assert_equal('platnička', skipped.first['label'])
  NxTest.assert_equal(nil, skipped.first['code'], 'a NEMA kod')
end

NxTest.test('KOV-G1a (R2): `none` v kodovom pasme sa uklada KANONICKY, pevny kod ho dalej odmieta') do
  c = NxG1a
  ok, errs = c::HWS.validate_member(
    { 'per' => 'unit', 'qty' => 1,
      'param_bands' => { 'param' => 'height',
                         'bands' => [{ 'min' => 17.0, 'max' => 20.0, 'code' => ' NoNe ' },
                                     { 'min' => 55.0, 'max' => 220.0, 'code' => '9079' }] } }, 0
  )
  NxTest.assert_equal([], errs, errs.inspect)
  NxTest.assert_equal(c::HWS::SKIP_CODE, ok['param_bands']['bands'].first['code'])
  # PEVNY kod `none` ostava zakazany — clen, ktory nikdy nic nevyda, je tichy
  # nezmysel (kto ho nechce, nech ho zmaze).
  bad, errs2 = c::HWS.validate_member({ 'per' => 'unit', 'qty' => 1, 'code' => 'none' }, 0)
  NxTest.assert_equal(nil, bad)
  NxTest.assert(errs2.first.to_s.include?('none'), errs2.inspect)
end

NxTest.test('KOV-G1a (Codex #337 N1): clen, ktoreho su VSETKY pasma `none`, sa NEULOZI') do
  c = NxG1a
  # Sentinel znamena „TU ziadny kod nepatri". Ked ho ma clen vo VSETKYCH
  # pasmach, je to clen, ktory nikdy nic neobjedna — ten isty tichy nezmysel
  # ako pevny kod `none`. Kto ho nechce, nech ho zmaze.
  # Codex #337 kolo 2 N1: odmieta sa PISANIE setu (`authoring: true` — editor),
  # nie citanie uz ulozeneho obsahu.
  bad, errs = c::HWS.validate_member(
    { 'per' => 'unit', 'qty' => 1,
      'param_bands' => { 'param' => 'height',
                         'bands' => [{ 'min' => 17.0, 'max' => 20.0, 'code' => 'none' },
                                     { 'min' => 55.0, 'max' => 220.0, 'code' => 'NONE' }] } },
    1, authoring: true
  )
  NxTest.assert_equal(nil, bad)
  NxTest.assert(errs.first.to_s.include?('všetky pásma'), errs.inspect)
  # TA ISTA uvaha v rade podla dlzky (D-118b) — aj tam musi ostat aspon
  # jeden skutocny kod.
  bad2, errs2 = c::HWS.validate_member(
    { 'per' => 'unit', 'qty' => 1, 'code_by_nl' => { '350' => 'none', '420' => 'none' } },
    1, authoring: true
  )
  NxTest.assert_equal(nil, bad2)
  NxTest.assert(errs2.first.to_s.include?('celý rad'), errs2.inspect)
  # Zmiesany clen (aspon jeden kod) ostava PLATNY — to je tvar seed setu nôh.
  ok, = c::HWS.validate_member(
    { 'per' => 'unit', 'qty' => 1, 'code_by_nl' => { '350' => 'none', '420' => '357695' } },
    1, authoring: true
  )
  NxTest.assert_equal({ '350' => c::HWS::SKIP_CODE, '420' => '357695' }, ok['code_by_nl'])
end

NxTest.test('KOV-G1a (Codex #337 kolo 2 N1): LEGACY clen bez kodov sa CITA — nic sa nezahadzuje') do
  c = NxG1a
  # Verzie so sentinelom `none` (D-118b) taketo cleny ulozit DOVOLILI. Keby ich
  # citacia cesta zahodila, `members_lost?` by uvidel zmenu poctu a CELA
  # kniznica by skoncila ako read-only (snapshot ako `:invalid`) — pouzivatel
  # by prisiel o VSETKY sety kvoli jednemu clenu.
  %i[nl bands].each do |kind|
    raw = c.legacy_all_none_set(kind)
    norm = c::HWS.normalize_sets([raw])
    NxTest.assert_equal(1, norm.length, "#{kind}: set sa NESMIE zahodit")
    NxTest.assert_equal(2, norm.first['members'].length, "#{kind}: OBA cleny ostavaju")
    NxTest.refute(c::HWS.members_lost?([raw], norm), "#{kind}: detektor straty NESMIE vystrelit")
    # A ten isty obsah sa da aj ZAPISAT spat (seed-merge kniznice, zmrazenie
    # snapshotu) — inak by projekt ostal navzdy bez snapshotu.
    _sets, errs = c::HWS.validate_sets(norm)
    NxTest.assert_equal([], errs, "#{kind}: #{errs.inspect}")
    m = c::Model.new
    NxTest.assert(c::HWS.write_project_state(m, 'mapping' => { 'leg' => 'legacy-none' },
                                                'sets' => { 'legacy-none' => norm.first }),
                  "#{kind}: snapshot sa MUSI dat zmrazit")
    NxTest.assert_equal(:ok, c::HWS.project_state_status(m).first, kind.to_s)
  end
end

NxTest.test('KOV-G1a (Codex #337 kolo 2 N1): legacy set FUNGUJE — clen sa preskoci, zvysok sa objedna') do
  c = NxG1a
  norm = c::HWS.normalize_sets([c.legacy_all_none_set(:nl)])
  st = c.state(norm, 'leg' => 'legacy-none')
  exp = c::HWS.expand([c.leg_item(60.0, 'params' => { 'height' => 60.0,
                                                      'nominal_length' => 420.0 })],
                      st, catalog: [])
  NxTest.assert_equal(['9069'], c.codes(exp), 'druhy clen sa objedna normalne')
  NxTest.assert_equal([], exp['unmapped'], exp['unmapped'].inspect)
  ex = c::HWS.explain(c.leg_item(60.0, 'params' => { 'height' => 60.0,
                                                     'nominal_length' => 420.0 }), st)
  NxTest.assert_equal([], ex['problems'], ex['problems'].inspect)
  NxTest.assert_equal(1, ex['members'].count { |m| m['skipped'] }, 'clen bez kodu je „preskoceny"')
end

NxTest.test('KOV-G1a (Codex #337 kolo 2 N1): EDITOR ten isty tvar odmietne — oprava sa vyziada pri ulozeni') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxG1a
  c.with_library do
    %i[nl bands].each do |kind|
      raw = c.legacy_all_none_set(kind)
      c.install_lib(c::HWS.normalize_sets([raw]), { 'leg' => 'legacy-none' })
      # Kniznica sa CITA normalne (o to islo) …
      NxTest.refute(c::HWS.library_read_only?, "#{kind}: legacy obsah NESMIE zamknut kniznicu")
      lib = c::HWS.load
      set = lib['sets'].find { |x| x['set_id'] == 'legacy-none' }
      NxTest.assert(set, "#{kind}: set sa nacital")
      NxTest.assert_equal(2, set['members'].length, "#{kind}: s OBOMA clenmi")
      # … ale prvy pokus ULOZIT ho z editora si vypyta opravu.
      status, msg = c::HWS.save_set!(set)
      NxTest.assert_equal(:invalid, status, "#{kind}: #{msg}")
      NxTest.assert(msg.to_s.include?(kind == :nl ? 'celý rad' : 'všetky pásma'), msg.to_s)
      # A po oprave (doplneny kod) uz zapis prejde.
      fixed = Marshal.load(Marshal.dump(set))
      if kind == :nl
        fixed['members'][0]['code_by_nl']['420'] = '357695'
      else
        fixed['members'][0]['param_bands']['bands'][0]['code'] = '9069'
      end
      NxTest.assert_equal(:ok, c::HWS.save_set!(fixed).first, kind.to_s)
    end
  end
end

NxTest.test('KOV-G1a (Codex #337 N1): set, ktory pre polozku nevyda NIC, je ORANGE — nikdy ticho') do
  c = NxG1a
  # Kazdy clen je sam o sebe platny (ma aj skutocne kody), len pre TUTO vysku
  # sokla su OBA vedome bez kodu. Set sa nasiel, sedel — a nakup by ostal
  # prazdny BEZ jedineho dovodu: kovanie by z objednavky ticho zmizlo.
  bez = c.leg_set_with(0) { |m| m['param_bands']['bands'][0]['code'] = c::HWS::SKIP_CODE }
  st = c.state(c.seed_norm.map { |s| s['set_id'] == c::LEG_SET ? bez : s })
  exp = c::HWS.expand([c.leg_item(17.0)], st, catalog: [])
  NxTest.assert_equal([], exp['rows'], 'ziadny nakupny riadok')
  u = exp['unmapped'].first
  NxTest.assert(u, 'MUSI vzniknut zaznam')
  NxTest.assert_equal(c::HWS::MEMBERS_ALL_SKIPPED, u['reason'])
  NxTest.refute(u['blocks_export'], 'ORANGE — polozka je nenacenena, nie nevyrobitelna')
  NxTest.assert(c::HWS.unmapped_reason_sk(u).include?('ani jeden riadok'),
                c::HWS.unmapped_reason_sk(u))
  # Kontrola o tom hovori jednou ORANGE polozkou s navodom.
  res = c::E::Validation.run({}, hardware_expansion: exp)
  items = res['items'].select { |i| i['category'] == 'hardware_unmapped' }
  NxTest.assert_equal(1, items.length, res['items'].inspect)
  NxTest.assert_equal('orange', items.first['severity'])
  NxTest.assert(items.first['message_sk'].include?('nevydal ani jeden nákupný riadok'),
                items.first['message_sk'])
  NxTest.refute(items.first['message_sk'].include?('nemá priradený set'),
                'zavadzajuca veta — set priradeny JE')
  # A supis (karta) sa s Kontrolou NEROZIDE.
  ex = c::HWS.explain(c.leg_item(17.0), st)
  NxTest.assert_equal(1, ex['problems'].length, ex.inspect)
  NxTest.assert(ex['problems'].first.include?('ani jeden riadok'), ex['problems'].inspect)
  NxTest.assert_equal(c::HWS::MEMBERS_ALL_SKIPPED, ex['unmapped'].first['reason'])
  # Receptova zasuvka a vyklop si drzia SVOJU (RED) cestu — dovod sa nemeni.
  NxTest.assert(c::HWS::UNMAPPED_REASONS.include?(c::HWS::MEMBERS_ALL_SKIPPED))
  NxTest.assert_equal('members_skipped',
                      c::HWS.send(:set_empty_reason, 'generic_type' => 'lift'))
  NxTest.assert_equal('members_skipped',
                      c::HWS.send(:set_empty_reason, 'source' => c::BP::HW_SOURCE_RECIPE))
end

# ============================================================================
# R3 — MARKER KOMPATIBILITY
# ============================================================================

NxTest.test('KOV-G1a (R3): sentinel v kodovom pasme = std 5') do
  c = NxG1a
  nohy = [c.set_of(c::LEG_SET)]
  NxTest.assert(c::HWS.skip_code_present?(nohy),
                'predikat MUSI vidiet sentinel aj v `param_bands`')
  NxTest.assert_equal(c::HWS::STD_SKIP_CODE, c::HWS.snapshot_std({}, nohy),
                      'inak by starsi plugin z bunky vyrobil kod „none"')
  # Bez sentinelu ostava marker nizsie — spatna citatelnost sa neblokuje zbytocne.
  bez = [c.leg_set_with(1) { |m| m['param_bands']['bands'].shift }]
  NxTest.refute(c::HWS.skip_code_present?(bez))
  NxTest.assert(c::HWS.snapshot_std({}, bez) < c::HWS::STD_SKIP_CODE)
end

# ============================================================================
# R4 — MIGRACIA KNIZNICE A PROJEKTU
# ============================================================================

NxTest.test('KOV-G1a (R4): NEDOTKNUTY stary tvar setu nôh sa nahradi novym') do
  c = NxG1a
  stary = c::HWS.normalize_sets([c::HWS::LEGACY_SEED_SHAPES[c::LEG_SET].first])
  merged, _map, changed = c::HWS.merge_seed(stary, { 'leg' => c::LEG_SET }, 7)
  NxTest.assert_equal(true, changed)
  nohy = merged.find { |s| s['set_id'] == c::LEG_SET }
  NxTest.assert_equal(2, nohy['members'].length, 'novy tvar ma nohu AJ platnicku')
  NxTest.assert_equal(7, nohy['members'][0]['param_bands']['bands'].length,
                      'sedem pasiem nohy (17-220 mm okrem 20-55)')
end

NxTest.test('KOV-G1a (R4): pouzivatelom upraveny set nôh ostava — ruky prec') do
  c = NxG1a
  moj = Marshal.load(Marshal.dump(c::HWS::LEGACY_SEED_SHAPES[c::LEG_SET].first))
  moj['members'][0]['param_bands']['bands'][0]['code'] = 'MOJ-KLZAK'
  merged, = c::HWS.merge_seed(c::HWS.normalize_sets([moj]), { 'leg' => c::LEG_SET }, 7)
  nohy = merged.find { |s| s['set_id'] == c::LEG_SET }
  NxTest.assert_equal(1, nohy['members'].length, 'upraveny set sa NEPREPISUJE')
  NxTest.assert_equal('MOJ-KLZAK', nohy['members'][0]['param_bands']['bands'][0]['code'])
  # Aj samotne PREMENOVANIE znamena ruky prec.
  premenovany = Marshal.load(Marshal.dump(c::HWS::LEGACY_SEED_SHAPES[c::LEG_SET].first))
  premenovany['name'] = 'Moje nohy'
  merged2, = c::HWS.merge_seed(c::HWS.normalize_sets([premenovany]), {}, 7)
  NxTest.assert_equal('Moje nohy', merged2.first['name'])
end

NxTest.test('KOV-G1a (R4): projektovy snapshot sa NEMENI sam — prevezme ho „Doplniť nové predvoľby"') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxG1a
  FileUtils.mkdir_p(c::HWS.dir)
  c::STORE.write(c::HWS.path,
                 'std' => c::HWS::STD_SKIP_CODE, 'seed_version' => c::HWS::SEED_VERSION,
                 'sets' => c.seed_norm,
                 'mapping' => c::HWS::SEED_MAPPING.merge(c::HWS::MAPPING_ADDITIONS))
  FileUtils.rm_f("#{c::HWS.path}.bak")
  c::STORE.invalidate(c::HWS.path)
  c::HWS.reset_library_state!
  begin
    stary = c::HWS.normalize_sets([c::HWS::LEGACY_SEED_SHAPES[c::LEG_SET].first]).first
    m = c::Model.new
    c::HWS.write_project_state(m, 'mapping' => { 'leg' => c::LEG_SET },
                                  'sets' => { c::LEG_SET => stary })
    _, pred = c::HWS.project_state_status(m)
    NxTest.assert_equal(1, pred['sets'][c::LEG_SET]['members'].length,
                        'hotova zakazka si nesie kody, s ktorymi bola objednana')

    res, _added_sets, added_map, refreshed = c::HWS.merge_project_sets_seed!(m)
    NxTest.assert_equal(:updated, res)
    NxTest.assert(Array(refreshed).include?(c::LEG_SET), Array(refreshed).inspect)
    NxTest.assert(Array(added_map).include?(c::CLIP_TYPE),
                  "predvolba prichytu sa doplnila: #{Array(added_map).inspect}")
    _, po = c::HWS.project_state_status(m)
    NxTest.assert_equal(2, po['sets'][c::LEG_SET]['members'].length, 'projekt uz ma platnicku')
    NxTest.assert(po['sets'].key?(c::CLIP_SET), 'a aj definiciu setu prichytu')
  ensure
    [c::HWS.path, "#{c::HWS.path}.bak"].each { |f| FileUtils.rm_f(f) }
    c::STORE.invalidate(c::HWS.path)
    c::HWS.reset_library_state!
  end
end

# ============================================================================
# R5 — TYP `plinth_clip`, SET PRICHYTU A MAPOVANIE
# ============================================================================

NxTest.test('KOV-G1a (R5): typ `plinth_clip` ma SK nazov na VSETKYCH miestach') do
  c = NxG1a
  NxTest.assert(c::BP::GENERIC_TYPES.include?(c::CLIP_TYPE), 'slovnik typov kovania')
  NxTest.assert_equal('Príchyt sokla', c::E::HardwareRules.label_for(c::CLIP_TYPE))
  NxTest.assert_equal('Príchyt sokla', c::E::Validation::HW_LABELS[c::CLIP_TYPE])
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'rules.js'), encoding: 'UTF-8')
  NxTest.assert(js.include?("plinth_clip:'Príchyt sokla'"), 'sekcia Pravidla')
  hw = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hardware.js'), encoding: 'UTF-8')
  NxTest.assert(hw.include?("plinth_clip:'Príchyt sokla'"), 'fallback mapa panela')
end

NxTest.test('KOV-G1a (R5): set prichytu je jednoclenny, klasifikovany a NEVYDA nic bez pravidla') do
  c = NxG1a
  set = c.set_of(c::CLIP_SET)
  NxTest.assert(set, 'seed set prichytu existuje')
  NxTest.assert_equal(c::CLIP_TYPE, set['generic_type'])
  NxTest.assert_equal('Häfele', set['manufacturer'])
  NxTest.assert_equal('AXILO', set['series'])
  NxTest.assert_equal([['950', 1, 'unit']],
                      set['members'].map { |m| [m['code'], m['qty'], m['per']] })
  # Bez PRAVIDLA (to je G1b) ziadna polozka `plinth_clip` nevznika — expanzia
  # bez nej teda nema co objednat a je to v poriadku.
  exp = c::HWS.expand([c.leg_item(150.0)], c.state, catalog: [])
  NxTest.refute(c.codes(exp).include?('950'), 'prichyt sa sam od seba neobjedna')
  # A ked polozka pride (G1b), set ju uz vie rozlozit.
  item = { 'owner_id' => 'CAB-1', 'owner_part_key' => nil, 'generic_type' => c::CLIP_TYPE,
           'quantity' => 2, 'rule_id' => 'prichyt-sokla', 'source' => 'rule', 'params' => {} }
  exp2 = c::HWS.expand([item], c.state, catalog: [])
  NxTest.assert_equal(['950'], c.codes(exp2))
  NxTest.assert_equal(2, exp2['rows'].first['quantity'])
  NxTest.assert_equal([], exp2['unmapped'])
end

NxTest.test('KOV-G1a (R5): mapovanie prichytu je ADD-IF-ABSENT, vlastna volba sa NEPREPISE') do
  c = NxG1a
  NxTest.assert_equal(c::CLIP_SET, c::HWS::SEED_MAPPING[c::CLIP_TYPE], 'cerstva kniznica')
  doplnene = c::HWS.add_mapping_seed(c.seed_norm, {})
  NxTest.assert_equal(c::CLIP_SET, doplnene[c::CLIP_TYPE], 'uz zalozena kniznica dostane kluc')
  moje = c::HWS.add_mapping_seed(c.seed_norm, c::CLIP_TYPE => 'moj-prichyt')
  NxTest.assert_equal('moj-prichyt', moje[c::CLIP_TYPE], 'ruky prec od pouzivatelskej volby')
  # Genericky kluc do tabulky TRIEDNYCH mapovani NEPATRI (`class_key_label` by
  # mu vratil nil a riadok by ostal bez popisku) — ma vlastny riadok medzi
  # generickymi typmi.
  NxTest.refute(c::HWS::CLASS_MAPPING_KEYS.include?(c::CLIP_TYPE))
  NxTest.assert(c::HWS::CLASS_MAPPING_KEYS.all? { |k| k.start_with?('class:') })
end

NxTest.test('KOV-G1a (Codex #337 N4): predvolba prichytu sa NEDOPLNI na set INEHO typu') do
  c = NxG1a
  # Upgrade: pouzivatel uz ma VLASTNY set s tym istym ID, ale je to ZAVES.
  # `merge_seed` mu ho spravne necha — a predvolba `plinth_clip` sa preto
  # doplnit NESMIE, inak by kazdy prichyt skoncil `set_type_mismatch`
  # namiesto objednanych kusov.
  moj = { 'set_id' => c::CLIP_SET, 'name' => 'Moje dvierka', 'generic_type' => 'hinge',
          'members' => [{ 'code' => 'X1', 'per' => 'unit', 'qty' => 1 }] }
  sets = c.seed_norm.map { |s| s['set_id'] == c::CLIP_SET ? c::HWS.normalize_sets([moj]).first : s }
  out = c::HWS.add_mapping_seed(sets, {})
  NxTest.refute(out.key?(c::CLIP_TYPE),
                "genericky kluc na set ineho typu: #{out[c::CLIP_TYPE].inspect}")
  # Kontrola je o TYPE, nie o mene: ten isty set spravneho typu kluc dostane.
  NxTest.assert_equal(c::CLIP_SET, c::HWS.add_mapping_seed(c.seed_norm, {})[c::CLIP_TYPE])
  # A rovnaka brana chrani aj snapshot noveho projektu / „Doplniť nové
  # predvoľby" — obe cesty stoja na `mapping_seed_value_ok?`.
  by_id = {}
  sets.each { |s| by_id[s['set_id']] = s }
  NxTest.refute(c::HWS.mapping_seed_value_ok?(c::CLIP_TYPE, c::CLIP_SET, by_id))
end

NxTest.test('KOV-G1a (R5): STARSI citac set prichytu ODMIETNE — nikdy tichy orez') do
  c = NxG1a
  h = c::HWS
  clip = c.set_of(c::CLIP_SET)
  # Simulacia STARSIEHO pluginu: slovnik typov BEZ `plinth_clip` (spustit stary
  # plugin sa neda, takze charakterizacia ide cez konstantu — vzor KOV-E1a).
  orig = c::BP::GENERIC_TYPES
  begin
    c::BP.send(:remove_const, :GENERIC_TYPES)
    c::BP.const_set(:GENERIC_TYPES, (orig - [c::CLIP_TYPE]).freeze)
    NxTest.assert(h.incompatible_set?(clip),
                  'set neznameho typu je pre starsi citac NEKOMPATIBILNY')
    status, lost = h.assess_set_defs([clip])
    NxTest.assert_equal(:lossy, status, 'sablona s takym setom sa ODMIETNE BEZ zapisu')
    NxTest.assert_equal([c::CLIP_SET], lost)
    # A mapovanie s neznamym typom je STRATA, nie ticho zahodeny kluc.
    _norm, errs = h.parse_mapping({ c::CLIP_TYPE => c::CLIP_SET })
    NxTest.assert(errs.any?, 'neznamy typ v mapovani = chyba tvaru')
  ensure
    c::BP.send(:remove_const, :GENERIC_TYPES)
    c::BP.const_set(:GENERIC_TYPES, orig)
  end
  # TATO verzia ho, samozrejme, cita bez straty.
  NxTest.refute(h.incompatible_set?(clip))
  NxTest.assert_equal(:ok, h.assess_set_defs([clip])[0])
end

NxTest.test('KOV-G1a (Codex #337 N3): seed set s cudzou vazbou rady sa instaluje BEZ zaradenia') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxG1a
  c.with_taxonomy do
    # Podporovany upgrade: pouzivatel ma radu AXILO naviazanu na vlastneho
    # vyrobcu a migracia taxonomie mu to (spravne) necha. Seed set prichytu
    # nesie Häfele/AXILO natvrdo — kniznica by tak dostala dvojicu, ktora
    # v jeho taxonomii NEEXISTUJE, a KAZDA neskorsia uprava toho setu cez
    # `save_set!` by skoncila hlaskou „rada AXILO patrí výrobcovi …".
    c.install_tax(['Hettich', 'Häfele', 'Moja firma'],
                  [['AXILO', 'Moja firma'], ['Sensys', 'Hettich']])
    # (a) CERSTVA kniznica
    lib = c::HWS.seed_library
    clip = lib['sets'].find { |s| s['set_id'] == c::CLIP_SET }
    NxTest.assert_equal(nil, clip['manufacturer'], 'nezaradeny set — nie polovicna klasifikacia')
    NxTest.assert_equal(nil, clip['series'])
    NxTest.assert_equal(c::CLIP_TYPE, clip['generic_type'], 'typ kovania sa NEMENI')
    NxTest.assert_equal('950', clip['members'][0]['code'], 'a kody uz vobec nie')
    zaves = lib['sets'].find { |s| s['set_id'] == 'zaves-klasik' }
    NxTest.assert_equal('Hettich', zaves['manufacturer'], 'nedotknuta rada ostava zaradena')
    NxTest.assert_equal(c::CLIP_SET, lib['mapping'][c::CLIP_TYPE],
                        'genericke mapovanie prichytu sa doplni aj tak (nakup je nezavisly)')
    # (b) UPGRADE uz zalozenej kniznice ide tou istou sadou
    stara = c::HWS.normalize_sets([c::HWS::LEGACY_SEED_SHAPES['nohy-klzak-17'].first])
    merged, = c::HWS.merge_seed(stara, {}, 7)
    doplneny = merged.find { |s| s['set_id'] == c::CLIP_SET }
    NxTest.assert_equal(nil, doplneny['manufacturer'], 'to iste pri seed-mergi')
    # (c) a nad takym setom uz `save_set!` PREJDE (o to cele ide)
    FileUtils.mkdir_p(c::HWS.dir)
    sets = c::HWS.normalize_sets(lib['sets'])
    begin
      c::STORE.write(c::HWS.path, 'std' => c::HWS::STD_SKIP_CODE,
                                  'seed_version' => c::HWS::SEED_VERSION,
                                  'sets' => sets, 'mapping' => lib['mapping'])
      FileUtils.rm_f("#{c::HWS.path}.bak")
      c::STORE.invalidate(c::HWS.path)
      c::HWS.reset_library_state!
      status, = c::HWS.save_set!(sets.find { |s| s['set_id'] == c::CLIP_SET }
                                     .merge('name' => 'Príchyt sokla (moje)'))
      NxTest.assert_equal(:ok, status, 'set, ktory sme nainstalovali, sa MUSI dat aj ulozit')
    ensure
      [c::HWS.path, "#{c::HWS.path}.bak"].each { |f| FileUtils.rm_f(f) }
      c::STORE.invalidate(c::HWS.path)
      c::HWS.reset_library_state!
    end
  end
end

NxTest.test('KOV-G1a (Codex #337 N3): bez taxonomie (a pri zhode) klasifikacia OSTAVA') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxG1a
  c.with_taxonomy do
    # Subor taxonomie este neexistuje — seed ho vzapati zalozi so spravnou
    # dvojicou, takze odoberat klasifikaciu by len zbytocne odpojilo triedne
    # predvolby zavesov a vyklopov.
    FileUtils.rm_f(c::TAX.path)
    FileUtils.rm_f("#{c::TAX.path}.bak")
    c::STORE.invalidate(c::TAX.path)
    c::TAX.reset_state!
    clip = c::HWS.seed_sets_resolved.find { |s| s['set_id'] == c::CLIP_SET }
    NxTest.assert_equal('Häfele', clip['manufacturer'])
    NxTest.assert_equal('AXILO', clip['series'])
    # A ked taxonomia dvojicu POTVRDI, ostava tiez (aj pri inom zapise mena).
    c.install_tax(['HÄFELE'], [['axilo', 'HÄFELE']])
    clip2 = c::HWS.seed_sets_resolved.find { |s| s['set_id'] == c::CLIP_SET }
    NxTest.assert_equal('Häfele', clip2['manufacturer'], 'zhoda je bez ohladu na zapis mena')
  end
end

# ============================================================================
# R6 + R8 — KATALOG
# ============================================================================

NxTest.test('KOV-G1a (R6): kazdy kod setu nôh a prichytu MA katalogovu polozku s cenou') do
  c = NxG1a
  by_code = {}
  c::HWC::SEED_ITEMS.each { |i| by_code[i['item_code']] = i }
  kody = c::NOHA_PRE_VYSKU.values.compact + %w[9079 950]
  kody.uniq.each do |kod|
    rec = by_code[kod]
    NxTest.assert(rec, "kod #{kod} nema katalogovu polozku (v Nakupe by bol bez ceny)")
    NxTest.assert_equal('NOHY', rec['category'], kod)
    NxTest.assert(rec['price_eur_vat'].to_f.positive?, "#{kod}: cena s DPH")
  end
  NxTest.assert_equal(0.80, by_code['9069']['price_eur_vat'], 'AXILO H60 = 0,65 bez DPH -> 0,80 s DPH')
  NxTest.assert_equal(0.41, by_code['272212']['price_eur_vat'])
  NxTest.assert_equal(0.35, by_code['950']['price_eur_vat'])
end

NxTest.test('KOV-G1a (R8): QUATRO LM riadky nemaju Demos vazbu, dodavatel a adresa su ulozene') do
  c = NxG1a
  quatro = c::HWC::SEED_ITEMS.select { |i| i['supplier'] == 'Quatro LM' }
  NxTest.assert_equal(8, quatro.length, 'sest nôh + platnicka + prichyt')
  quatro.each do |i|
    NxTest.refute(i.key?('demos_url'),
                  "#{i['item_code']}: cudzia adresa NIE JE Demos vazba (allowlist by ju odmietol)")
    NxTest.refute(i.key?('price_checked_at'),
                  "#{i['item_code']}: bez vazby nemoze byt ani datum overenia")
    NxTest.assert(i['notes'].to_s.include?('Quatro LM · https://quatrolm.sk/p/'),
                  "#{i['item_code']}: adresa dodavatela je v poznamke")
    NxTest.assert_equal('Häfele', i['manufacturer'], i['item_code'])
    NxTest.assert_equal('AXILO', i['series'], i['item_code'])
  end
  # 272212 je z Demosu — vazbu aj datum MA.
  strong = c::HWC::SEED_ITEMS.find { |i| i['item_code'] == '272212' }
  NxTest.assert_equal('Demos', strong['supplier'])
  NxTest.assert(strong['demos_url'].to_s.start_with?('https://www.demos-trade.sk/'))
  NxTest.assert(strong.key?('price_checked_at'))
end

NxTest.test('KOV-G1a (R6): patch v5 doplna LEN vymenovane kody (plny seed sa NELEJE)') do
  c = NxG1a
  # Katalog „pred davkou" = v4 sada BEZ devatich novych kodov a bez jedneho
  # kodu, ktory si pouzivatel ZMAZAL (82744) — ten sa vzkriesit NESMIE.
  novy = c::HWC::SEED_PATCH_V5_ADD
  items = c::HWC::SEED_ITEMS.reject { |i| novy.include?(i['item_code']) || i['item_code'] == '82744' }
                            .map { |i| c::HWC.normalize_item(i)[0] }
  pred = items.length
  c::HWC.apply_seed_patch_v5(items, c::HWC::SEED_ITEMS)
  NxTest.assert_equal(pred + novy.length, items.length, 'doplnilo sa presne devat kodov')
  have = items.map { |i| i['item_code'] }
  novy.each { |kod| NxTest.assert(have.include?(kod), "#{kod} chyba") }
  NxTest.refute(have.include?('82744'), 'zmazany seed kod sa NEVZKRIESI')
  # Druhy beh uz nic nedopĺňa (idempotencia).
  c::HWC.apply_seed_patch_v5(items, c::HWC::SEED_ITEMS)
  NxTest.assert_equal(pred + novy.length, items.length)
end

NxTest.test('KOV-G1a (R6): patch v5 — 367823 dostane klasifikaciu LEN ked je prazdna') do
  c = NxG1a
  bez = c::HWC.normalize_item(c::HWC::SEED_ITEMS.find { |i| i['item_code'] == '367823' }
                                                .reject { |k, _| %w[manufacturer series].include?(k) })[0]
  items = [bez]
  c::HWC.apply_seed_patch_v5(items, c::HWC::SEED_ITEMS)
  rec = items.find { |i| i['item_code'] == '367823' }
  NxTest.assert_equal('Häfele', rec['manufacturer'], 'prazdna klasifikacia sa doplni')
  NxTest.assert_equal('AXILO', rec['series'])
  NxTest.assert_equal(1.52, rec['price_eur_vat'], 'a NIC INE sa nemeni')
end

NxTest.test('KOV-G1a (R6): patch v5 — 367823 s VLASTNOU klasifikaciou ostava') do
  c = NxG1a
  moje = c::HWC.normalize_item(
    c::HWC::SEED_ITEMS.find { |i| i['item_code'] == '367823' }
                      .merge('manufacturer' => 'Moja Firma', 'series' => nil, 'use_count' => 7)
  )[0]
  items = [moje]
  c::HWC.apply_seed_patch_v5(items, c::HWC::SEED_ITEMS)
  rec = items.find { |i| i['item_code'] == '367823' }
  NxTest.assert_equal('Moja Firma', rec['manufacturer'], 'ruky prec od pouzivatelskej upravy')
  NxTest.assert_equal(nil, rec['series'])
  NxTest.assert_equal(7, rec['use_count'])
end

NxTest.test('KOV-G1a (R6): patch v5 opravi polozky s dvojicou Hettich+AXILO') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxG1a
  # Radu AXILO presunula spod Hettichu pod Häfele migracia taxonomie, takze
  # polozka s tou dvojicou by uz v modale NEPRESLA („rada nepatri výrobcovi") —
  # a bez opravy by ju pouzivatel nevedel ulozit. Meni sa VYHRADNE vyrobca.
  c.with_taxonomy do
    c.install_tax(['Hettich', 'Häfele'], [['AXILO', 'Häfele'], ['Sensys', 'Hettich']])
    moja, = c::HWC.normalize_item('item_code' => 'X-AXILO', 'name_sk' => 'Moja noha AXILO',
                                  'category' => 'NOHY', 'unit' => 'ks',
                                  'manufacturer' => 'hettich', 'series' => 'axilo',
                                  'price_eur_vat' => 9.99)
    ina, = c::HWC.normalize_item('item_code' => 'X-SENSYS', 'name_sk' => 'Záves',
                                 'category' => 'ZAVESY', 'unit' => 'ks',
                                 'manufacturer' => 'Hettich', 'series' => 'Sensys')
    items = [moja, ina]
    c::HWC.apply_seed_patch_v5(items, c::HWC::SEED_ITEMS)
    NxTest.assert_equal('Häfele', items[0]['manufacturer'], 'AXILO uz patri Häfele')
    NxTest.assert_equal('axilo', items[0]['series'], 'rada sa NEMENI (ani jej zapis)')
    NxTest.assert_equal(9.99, items[0]['price_eur_vat'], 'a nic ine tiez nie')
    NxTest.assert_equal('Hettich', items[1]['manufacturer'], 'ina rada Hettichu sa NEDOTKNE')
  end
end

NxTest.test('KOV-G1a (Codex #337 N2): AXILO pod VLASTNYM vyrobcom — katalog sa NEDOTKNE') do
  NxTest.skip!('zapisuje do headless %APPDATA% sandboxu') unless NxTest.headless?
  c = NxG1a
  # Pouzivatel ma radu AXILO naviazanu na vlastneho vyrobcu; migracia taxonomie
  # mu to (spravne) necha. Katalogovy patch sa preto pytat NASHO seedu NESMIE:
  # `resolve_classification('Häfele','AXILO')` vrati „Häfele BEZ rady", a keby
  # z toho odvodil vlastnika, prepisal by polozky na dvojicu Häfele+AXILO,
  # ktora v JEHO taxonomii NEEXISTUJE (a v modale by ju uz neulozil).
  c.with_taxonomy do
    c.install_tax(['Hettich', 'Häfele', 'Moja firma'], [['AXILO', 'Moja firma']])
    NxTest.assert_equal('Moja firma', c::TAX.series_owner('axilo'), 'ziva taxonomia rozhoduje')
    moja, = c::HWC.normalize_item('item_code' => 'X-AXILO', 'name_sk' => 'Moja noha AXILO',
                                  'category' => 'NOHY', 'unit' => 'ks',
                                  'manufacturer' => 'Hettich', 'series' => 'AXILO',
                                  'price_eur_vat' => 9.99)
    items = [moja]
    c::HWC.apply_seed_patch_v5(items, c::HWC::SEED_ITEMS)
    NxTest.assert_equal('Hettich', items[0]['manufacturer'],
                        'cudzia vazba rady = ruky prec od katalogovych poloziek')
    NxTest.assert_equal('AXILO', items[0]['series'])
  end
  # A ked taxonomia este NEEXISTUJE (subor sa zaklada az prvym pouzitim),
  # krok sa tiez nevykona — nemame sa coho chytit.
  c.with_taxonomy do
    FileUtils.rm_f(c::TAX.path)
    FileUtils.rm_f("#{c::TAX.path}.bak")
    c::STORE.invalidate(c::TAX.path)
    c::TAX.reset_state!
    NxTest.assert_equal(nil, c::TAX.series_owner('AXILO'), 'bez suboru sa NESEEDUJE a nic nevie')
  end
end

# ============================================================================
# R7 — TAXONOMIA
# ============================================================================

NxTest.test('KOV-G1a (R7): seed nesie Häfele a rada AXILO patri jemu') do
  c = NxG1a
  NxTest.assert(c::TAX::SEED_MANUFACTURERS.include?('Häfele'))
  axilo = c::TAX::SEED_SERIES.find { |(name, _)| name == 'AXILO' }
  NxTest.assert_equal(['AXILO', 'Häfele'], axilo, 'AXILO je HÄFELE program, nie Hettich')
  NxTest.assert(c::TAX::SEED_VERSION >= 3, 'presun potrebuje bump seed verzie')
end

NxTest.test('KOV-G1a (R7): PRESNE stary seed tvar sa presunie pod Häfele') do
  c = NxG1a
  doc = { 'manufacturers' => [{ 'name' => 'Hettich' }],
          'series' => [{ 'name' => 'AXILO', 'manufacturer' => 'Hettich' },
                       { 'name' => 'Sensys', 'manufacturer' => 'Hettich' }] }
  mans, sers = c::TAX.merge_seed(doc)
  axilo = sers.find { |s| s['name'] == 'AXILO' }
  NxTest.assert_equal('Häfele', axilo['manufacturer'], 'presunuta')
  NxTest.assert_equal(1, sers.count { |s| s['name'] == 'AXILO' }, 'a NEZDVOJILA sa')
  NxTest.assert_equal('Hettich', sers.find { |s| s['name'] == 'Sensys' }['manufacturer'],
                      'ostatne rady Hettichu sa nedotknu')
  NxTest.assert(mans.any? { |m| m['name'] == 'Häfele' }, 'vyrobca pribudol')
end

NxTest.test('KOV-G1a (R7): vlastnik sa berie z ULOZENEHO zapisu vyrobcu') do
  c = NxG1a
  # Pouzivatel ma „HÄFELE" — merge vyrobcu nedopĺňa (slug sedi) a rada zapisana
  # nasim „Häfele" by v selectoch rad ZMIZLA (JS filtruje presnym retazcom).
  doc = { 'manufacturers' => [{ 'name' => 'Hettich' }, { 'name' => 'HÄFELE' }],
          'series' => [{ 'name' => 'AXILO', 'manufacturer' => 'HETTICH' }] }
  mans, sers = c::TAX.merge_seed(doc)
  NxTest.assert_equal('HÄFELE', sers.find { |s| s['name'] == 'AXILO' }['manufacturer'])
  NxTest.assert_equal(1, mans.count { |m| c::TAX.same_name?(m['name'], 'Häfele') },
                      'vyrobca sa nezdvojil')
end

NxTest.test('KOV-G1a (R7): pouzivatelska rada sa NEPRESUNIE') do
  c = NxG1a
  # (a) vlastne meno rady — nas seed ho nikdy nezapisal
  doc = { 'manufacturers' => [{ 'name' => 'Hettich' }],
          'series' => [{ 'name' => 'AXILO plus', 'manufacturer' => 'Hettich' }] }
  _mans, sers = c::TAX.merge_seed(doc)
  NxTest.assert_equal('Hettich', sers.find { |s| s['name'] == 'AXILO plus' }['manufacturer'],
                      'vlastna rada ostava tam, kam ju dal pouzivatel')
  NxTest.assert_equal('Häfele', sers.find { |s| s['name'] == 'AXILO' }['manufacturer'],
                      'a nasa AXILO pribudne pod Häfele')
  # (b) rada AXILO, ktoru si pouzivatel naviazal na INEHO vyrobcu
  doc2 = { 'manufacturers' => [{ 'name' => 'Hettich' }, { 'name' => 'Moja Firma' }],
           'series' => [{ 'name' => 'AXILO', 'manufacturer' => 'Moja Firma' }] }
  _m2, sers2 = c::TAX.merge_seed(doc2)
  NxTest.assert_equal('Moja Firma', sers2.find { |s| s['name'] == 'AXILO' }['manufacturer'],
                      'cudzia vazba = ruky prec')
end
