# frozen_string_literal: true
# Testy D-134 — JEDNOTNY ROZSAH HROMADNYCH ZAPISOV ZAKAZKY.
#
# PRECO tato sada existuje: D-131 („Kresba čiel") a D-133 („Nahradiť UNI…") uz
# stali na `Ids.top_level_scan`, ale DALSIE TRI hromadne zapisove cesty ostali
# na GLOBALNOM prechode cez `model.definitions`:
#   1) ulozenie aj doplnenie PRAVIDIEL KOVANIA (`ui/rules_dialog.rb`),
#   2) zmena PROJEKTOVEJ PREDVOLBY materialu (`ui/materials_dialog.rb`),
#   3) override materialu dielca „aj na podobné v projekte"
#      (`ui/panel/actions_parts.rb`).
# Skrinka VNORENA v cudzom komponente sa takou akciou prestavala — a to vo
# VSETKYCH vyskytoch zdielanej definicie — hoci vo vystupoch zakazky (kusovnik,
# VEPO, Kontrola) vobec nie je; a skrinku s ODPOJENYM dielcom prestavba nechala
# s dvojnikom (vnoreny dielec novy, odpojeny stary, kusovnik nesie oboje).
#
# ZAVAZNY KONTRAKT, ktory tu zamykame:
#   1) JEDEN ZDROJ: `Panel.job_cabinets` nad `Ids.top_level_scan`. Vnorena
#      skrinka sa do neho NEDOSTANE; CITACIE cesty volaju `Ids.each_cabinet`
#      priamo (`Panel.all_cabinets` po slepom review P3-2 ZANIKLO).
#   1b) BRANY hrubky/receptov sa pytaju nad VSETKYMI dediacimi skrinkami
#      VRATANE preskocenych (predvolba sa dedi za behu), prestavba len nad
#      tymi bez odpojeneho dielca.
#   2) SKIP, NIE BLOKADA: skrinka s odpojenym dielcom vypadne z prestavby, ale
#      PROJEKTOVY ZAPIS (pravidla, predvolba) prebehne — zakazka nesmie ostat
#      bez ulozenych pravidiel kvoli jednej vytiahnutej doske. (Na rozdiel od
#      „Nahradiť UNI…", kde je nahrada dekoru all-or-nothing.)
#   3) FAIL-VISIBLE: preskocena skrinka sa VYMENUJE aj s napravou zo zdielanej
#      konstanty `Ids::DETACHED_PART_REASON`.
#   4) PODOBNE DIELCE: `similar_parts_map` ostava JEDINOU autoritou poctu aj
#      zapisu — vracia [mapa, preskocene], takze modal aj zapis stoja na tom
#      istom vysledku.
#   5) PRAZDNY ZOZNAM JOBOV: `rebuild_many` aj tak otvori operaciu a vykona blok
#      — projektovy zapis teda nikdy nekonci „ticho neulozeny" ani mimo operacie.
#   6) CHARAKTERIZACIA: zakazka BEZ vnorenych skriniek a BEZ odpojenych dielcov
#      dostane bajtovo rovnake hlasky ako pred davkou.
#
# MUTACIE OVERENE proti tejto sade (kazda ju zhodi):
#   M1 — pravidla kovania spat na `cabinets(model)` (= `Ids.each_cabinet`)
#        -> „zdroj: pravidla kovania beru skrinky ZAKAZKY"
#   M2 — projektova predvolba neskipne odpojeny dielec (`affected` = cele
#        `inheriting`) -> „predvolba: skrinka s odpojenym dielcom vypadne"
#   M3 — `similar_parts_map` rata preskocenu skrinku do poctu
#        -> „podobne dielce: preskocena skrinka nie je v mape ani v pocte"
#   M4 — projektovy zapis pravidiel sa pri 0 joboch nevykona
#        -> „prazdny zoznam jobov: blok `rebuild_many` aj tak prebehne"
require_relative '../helper' unless defined?(NxTest)

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine/ui/panel/payloads')
  require File.join(NxTest::ROOT, 'noxun_engine/ui/panel/resolvers')
  require File.join(NxTest::ROOT, 'noxun_engine/ui/panel/actions_parts')
  # `fmt_mm` (hlasky predvolby) zije v actions_cabinet.rb — ten isty reopen Panel.
  require File.join(NxTest::ROOT, 'noxun_engine/ui/panel/actions_cabinet')
  require File.join(NxTest::ROOT, 'noxun_engine/ui/materials_dialog')
end

D134IDS = Noxun::Engine::Ids

# --- Stub SketchUp tried pre `Ids` (prechod korenom modelu).
# Vzor `test_d133_nahradit_uni_rozsah.rb` — stub zije VNUTRI modulu, aby ho
# nasla lexikalna konstanta v jeho metodach.
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
  D134PANEL = Noxun::Engine::Panel
  D134MD = Noxun::Engine::MaterialsDialog
  D134_SU = Noxun::Engine::Ids::Sketchup

  # Definicia komponentu s ENTITAMI: `Ids.each_of_kind` sa pyta na `instances`,
  # `Panel.regenerated_parts` na `entities` — oboje je ten isty obsah.
  class D134Def < NxTest::FakeDefinition
    def entities
      instances
    end
  end

  # Duck-typing NOXUN entita (vzor D-133): ploche NOXUN kluce + config ako JSON.
  class D134Ent < D134_SU::ComponentInstance
    attr_reader :entityID # rubocop:disable Naming/MethodName — zrkadli SketchUp API
    attr_accessor :parent
    attr_writer :definition

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

    def definition
      @definition ||= D134Def.new([])
    end

    def get_attribute(dict, key, default = nil)
      return default unless dict == 'NOXUN'

      @dict.fetch(key.to_s, default)
    end
  end

  # Model s OBOMA pohladmi (`entities` = zakazka, `definitions` = globalny
  # prechod). Rozdiel medzi nimi je presne to, co D-134 rieši.
  class D134Model
    attr_reader :entities, :definitions

    def initialize(entities, nested = [])
      @entities = entities
      @definitions = [D134Def.new(entities + nested)]
    end

    def path
      'C:/tmp/d134.skp'
    end
  end

  def d134_part(cid, role, material, entity_id, key: nil)
    D134Ent.new({ 'kind' => 'part', 'cabinet_id' => cid, 'role' => role,
                  'manufactured' => true, 'production_class' => 'sheet',
                  'part_key' => key || "#{cid}-#{role.upcase}-#{entity_id}" },
                { 'material_id' => material, 'thickness' => 18.0 }, entity_id)
  end

  # Skrinka s vnorenymi dielcami (to, co prestavba naozaj prekresli).
  def d134_cab(cid, entity_id, parts: [], cfg: {})
    cab = D134Ent.new({ 'kind' => 'cabinet', 'cabinet_id' => cid },
                      { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                        'depth' => 500.0, 'thickness' => 18.0 }.merge(cfg), entity_id)
    dfn = D134Def.new(parts)
    cab.definition = dfn
    parts.each { |p| p.parent = dfn }
    cab
  end

  # Odpojeny dielec = top-level `part` s vlastnikom v `cabinet_id`.
  def d134_detached(cid, entity_id)
    d134_part(cid, 'shelf', 'DEKOR_A', entity_id)
  end

  # `Panel.regenerated_parts` grepuje `Sketchup::ComponentInstance` — Panel
  # vlastny `Sketchup` NEMA, takze sa hlada az na najvyssej urovni. Stub sa
  # preto zaklada LEN NA CAS volania a hned sa rusi (vzor `with_sketchup`
  # v `test_kovg2_nohy_ui.rb`): trvaly globalny `Sketchup` by zmenil vetvy
  # `defined?(Sketchup)` vsetkym sadam, ktore bezia po tejto.
  def d134_with_sketchup
    return yield if Object.const_defined?(:Sketchup)

    mod = Module.new
    # TA ISTA trieda, akou zbiera koren modelu `Ids.top_level_scan` — inak by
    # `regenerated_parts` nenaslo dielce, ktore zber pustil dalej.
    mod.const_set(:ComponentInstance, D134_SU::ComponentInstance)
    mod.define_singleton_method(:active_model) { nil }
    Object.const_set(:Sketchup, mod)
    begin
      yield
    ensure
      Object.send(:remove_const, :Sketchup)
    end
  end
end

# ---------------------------------------------------------------------------
# 1) JEDEN ZDROJ SKRINIEK PRE ZAPIS (R1)
# ---------------------------------------------------------------------------

NxTest.test('D-134 zdroj: `job_cabinets` berie ZAKAZKU, vnorena skrinka v nej nie je') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  top = d134_cab('CAB-001', 1)
  nested = d134_cab('CAB-NESTED', 9)
  model = D134Model.new([top], [nested])

  out = D134PANEL.job_cabinets(model)
  NxTest.assert_equal(['CAB-001'], out['cabinets'].map { |i| i.get_attribute('NOXUN', 'cabinet_id') })
  NxTest.assert_equal(0, out['detached']['CAB-001'], 'bez odpojeneho dielca je mapa nulova, nie nil')

  # Kontrolna otazka: CITACIA cesta vnorenu skrinku NAOPAK vidiet MUSI
  # (katalogovy usage/delete guard) — a to sa davkou nemeni.
  seen = []
  D134IDS.each_cabinet(model) { |i| seen << i.get_attribute('NOXUN', 'cabinet_id') }
  NxTest.assert_equal(%w[CAB-001 CAB-NESTED], seen.sort)
end

NxTest.test('D-134 zdroj: `job_split` oddeli skrinku s odpojenym dielcom') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  a = d134_cab('CAB-001', 1)
  b = d134_cab('CAB-002', 2)
  model = D134Model.new([a, b, d134_detached('CAB-002', 31)])

  scan = D134PANEL.job_cabinets(model)
  jobs, skipped = D134PANEL.job_split(scan['cabinets'], scan['detached'])
  NxTest.assert_equal(['CAB-001'], jobs.map { |i| i.get_attribute('NOXUN', 'cabinet_id') })
  NxTest.assert_equal(['CAB-002'], skipped)

  # Skratka pre cesty, ktore beru CELU zakazku, dava to iste.
  jobs2, skipped2 = D134PANEL.job_cabinets_split(model)
  NxTest.assert_equal(jobs.map(&:entityID), jobs2.map(&:entityID))
  NxTest.assert_equal(skipped, skipped2)
end

NxTest.test('D-134 zdroj: volajuci si zoznam moze ZUZIT skor, nez sa oddelia preskocene') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  # Projektova predvolba berie LEN dediace skrinky: skrinka s vlastnym
  # overridom sa nemenila ani predtym, takze menovat ju medzi preskocenymi by
  # pouzivatela poslalo hladat problem tam, kde ziadny nie je.
  a = d134_cab('CAB-001', 1)
  b = d134_cab('CAB-002', 2)
  model = D134Model.new([a, b, d134_detached('CAB-002', 31)])
  scan = D134PANEL.job_cabinets(model)
  jobs, skipped = D134PANEL.job_split([a], scan['detached'])
  NxTest.assert_equal(['CAB-001'], jobs.map { |i| i.get_attribute('NOXUN', 'cabinet_id') })
  NxTest.assert_equal([], skipped, 'skrinka mimo vyberu sa medzi preskocene nedostane')
end

NxTest.test('D-134 hlaska: preskocene sa VYMENUJU zdielanou vetou o naprave') do
  tail = Noxun::Engine::Panel.detached_skipped_tail(%w[CAB-003])
  NxTest.assert(tail.start_with?(' · preskočené: CAB-003 ('), tail)
  NxTest.assert(tail.include?(D134IDS::DETACHED_PART_REASON),
                'veta musi byt zo zdielanej konstanty, nie kopia')
  NxTest.assert_equal('', Noxun::Engine::Panel.detached_skipped_tail([]),
                      'bezna zakazka nema ziadny chvost (charakterizacia)')
  NxTest.assert_equal('', Noxun::Engine::Panel.detached_skipped_tail(nil))
  # Dve skrinky = jeden riadok oddeleny ciarkou (status ostava jednou vetou).
  NxTest.assert(Noxun::Engine::Panel.detached_skipped_tail(%w[CAB-003 CAB-004]).include?('), CAB-004 ('))
end

# ---------------------------------------------------------------------------
# 2) PRAVIDLA KOVANIA (R3) — zdrojove guardy oboch ciest
# ---------------------------------------------------------------------------

module D134Src
  RB = {}

  def self.src(rel)
    RB[rel] ||= File.read(File.join(NxTest::ROOT, 'noxun_engine', rel), encoding: 'UTF-8')
  end

  # Telo metody BEZ komentarov — guard sa nesmie chytat na vetu v komentari.
  def self.body(rel, name)
    raw = src(rel)[/^        def #{name}\b.*?\n        end\n/m].to_s
    raw.gsub(/^\s*#.*$/, '').gsub(%r{\s+#\s.*$}, '')
  end
end

NxTest.test('D-134 zdroj: pravidla kovania beru skrinky ZAKAZKY (obe cesty)') do
  %w[handle_save handle_merge_seed].each do |name|
    body = D134Src.body('ui/rules_dialog.rb', name)
    NxTest.assert(!body.empty?, "#{name} sa nasiel")
    NxTest.assert(body.include?('Panel.job_cabinets_split(model)'),
                  "#{name}: zoznam skriniek ide cez zdielany helper zakazky")
    NxTest.assert(!body.include?('cabinets(model).map'),
                  "#{name}: globalny prechod (`Ids.each_cabinet`) sa do zapisu uz nesmie vratit")
    NxTest.assert(body.include?('Panel.detached_skipped_tail(skipped)'),
                  "#{name}: status VYMENUJE preskocene skrinky")
    NxTest.assert(body.include?('CabinetBuilder.rebuild_many'),
                  "#{name}: prestavba aj zapis pravidiel ostavaju JEDNOU operaciou")
  end
end

NxTest.test('D-134 zdroj: CITACIE cesty sekcie Pravidla ostavaju GLOBALNE') do
  body = D134Src.body('ui/rules_dialog.rb', 'cabinets')
  NxTest.assert(body.include?('Ids.each_cabinet(model)'),
                'pocet „skriniek v modeli" a resolver jednej skrinky sa nemenia')
end

NxTest.test('D-134 prazdny zoznam jobov: blok `rebuild_many` aj tak prebehne') do
  # Keby `rebuild_many` s prazdnym zoznamom operaciu neotvorilo, zakazka, kde je
  # KAZDA skrinka preskocena, by ostala bez ulozenych pravidiel — a pouzivatel by
  # pritom videl hlasku o uspechu.
  ops = []
  model = Object.new
  model.define_singleton_method(:active_path) { nil }
  model.define_singleton_method(:start_operation) { |name, *_rest| ops << [:start, name] }
  model.define_singleton_method(:commit_operation) { ops << [:commit] }
  model.define_singleton_method(:abort_operation) { ops << [:abort] }

  wrote = false
  out = Noxun::Engine::CabinetBuilder.rebuild_many(model, [], op_name: 'NOXUN: test') { wrote = true }
  NxTest.assert(wrote, 'projektovy zapis sa vykonal')
  NxTest.assert_equal([], out)
  NxTest.assert_equal([[:start, 'NOXUN: test'], [:commit]], ops,
                      'zapis prebehol VNUTRI operacie (nikdy mimo nej)')
end

# ---------------------------------------------------------------------------
# 3) PROJEKTOVA PREDVOLBA MATERIALU (R4)
# ---------------------------------------------------------------------------

NxTest.test('D-134 predvolba: skrinka s odpojenym dielcom vypadne, zapis prebehne') do
  body = D134Src.body('ui/materials_dialog.rb', 'handle_set_project_material')
  NxTest.assert(!body.empty?, 'handler sa nasiel')
  NxTest.assert(body.include?('Panel.job_cabinets(model)'),
                'dediace skrinky sa hladaju v ZAKAZKE')
  NxTest.assert(!body.include?('Panel.all_cabinets(model)'),
                'globalny prechod sa do zapisovej vetvy uz nesmie vratit')
  NxTest.assert(body.include?("affected, skipped = Panel.job_split(inheriting, scan['detached'])"),
                'preskocene sa oddeluju AZ z dediacich skriniek')
  # Slepe review P2-1: BRANY sa pytaju nad `inheriting` (vsetky dediace
  # vratane preskocenych) — predvolba sa dedi ZA BEHU, takze preskocena
  # skrinka novu hrubku aj tak dostane a branu nesmie obist.
  NxTest.assert(body.include?('body_change_plan(model, inheriting, sheet, value)'),
                'D-46 brana vidi aj preskocene skrinky')
  NxTest.assert(body.include?('drawer_change_plan(model, inheriting, have)'),
                'brana receptov zasuviek tiez')
  NxTest.assert(body.include?('incompatible = inheriting.select'),
                'a brana hrubky ostatnych rol tiez')
  NxTest.assert(body.include?('body_change_plan(model, affected, sheet, value) unless skipped.empty?'),
                'PRESTAVBA sa pocita znova nad uzsim zoznamom — a len ked je co vylucit')
  NxTest.assert(body.include?('skipped_tail: skip_tail'),
                'potvrdzovacia lista menuje preskocene skrinky')
  NxTest.assert(body.include?('saved_msg(adopted_n, recomputed_n, have, skip_tail)'),
                'vysledny status ich menuje tiez')
  # Zapis predvolby ostava VNUTRI operacie rebuildov (1 undo krok) — a teda
  # prebehne aj vtedy, ked su vsetky dediace skrinky preskocene.
  NxTest.assert(body.include?('CabinetBuilder.rebuild_many(model, jobs') &&
                body.include?('Materials.set_project_default(model, key, value)'),
                'predvolba sa zapisuje v tej istej operacii ako prestavba')
end

NxTest.test('D-134 predvolba: hlasky su bez preskocenych BAJTOVO rovnake (charakterizacia)') do
  NxTest.skip!('potrebuje UI vrstvu') unless NxTest.headless?
  NxTest.assert_equal('Predvoľba uložená — prepočítaných 3 skriniek.',
                      D134MD.saved_msg(0, 3, 18.0))
  NxTest.assert_equal(D134MD.saved_msg(0, 3, 18.0), D134MD.saved_msg(0, 3, 18.0, ''))
  NxTest.assert_equal('2 skrinky prevezmú hrúbku 18 mm — potvrď nižšie.',
                      D134MD.confirm_msg(2, 0, 18.0))
  NxTest.assert_equal(D134MD.confirm_msg(2, 0, 18.0), D134MD.confirm_msg(2, 0, 18.0, ''))

  tail = Noxun::Engine::Panel.detached_skipped_tail(%w[CAB-003])
  saved = D134MD.saved_msg(0, 3, 18.0, tail)
  NxTest.assert(saved.include?('CAB-003') && saved.end_with?('.'), saved)
  confirm = D134MD.confirm_msg(2, 0, 18.0, tail)
  NxTest.assert(confirm.include?('CAB-003'), confirm)
  NxTest.assert(confirm.end_with?(' — potvrď nižšie.'),
                'veta o preskocenych stoji PRED vyzvou na potvrdenie')
end

# ---------------------------------------------------------------------------
# 4) PODOBNE DIELCE V PROJEKTE (R5)
# ---------------------------------------------------------------------------

NxTest.test('D-134 podobne dielce: „projekt" = ZAKAZKA (vnorena skrinka sa neta)') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  src = d134_part('CAB-001', 'shelf', 'DEKOR_A', 11, key: 'CAB-001-SHELF-1')
  a = d134_cab('CAB-001', 1, parts: [src, d134_part('CAB-001', 'shelf', 'DEKOR_A', 12,
                                                    key: 'CAB-001-SHELF-2')])
  b = d134_cab('CAB-002', 2, parts: [d134_part('CAB-002', 'shelf', 'DEKOR_A', 21,
                                               key: 'CAB-002-SHELF-1')])
  nested = d134_cab('CAB-NESTED', 9, parts: [d134_part('CAB-NESTED', 'shelf', 'DEKOR_A', 91,
                                                       key: 'CAB-NESTED-SHELF-1')])
  model = D134Model.new([a, b], [nested])

  map, skipped = d134_with_sketchup { D134PANEL.similar_parts_map(model, a, src, 'project') }
  NxTest.assert_equal(%w[CAB-001 CAB-002], map.keys.sort,
                      'vnorena skrinka nie je v mape — a teda ani v pocte ani v zapise')
  NxTest.assert_equal([], skipped)
  NxTest.assert_equal(2, D134PANEL.similar_parts_count(map), 'zdrojovy dielec sa neta')

  # Rozsah „táto skrinka" ostava nedotknuty.
  map_cab, skipped_cab = d134_with_sketchup { D134PANEL.similar_parts_map(model, a, src, 'cabinet') }
  NxTest.assert_equal(['CAB-001'], map_cab.keys)
  NxTest.assert_equal([], skipped_cab)
  NxTest.assert_equal(1, D134PANEL.similar_parts_count(map_cab))
end

NxTest.test('D-134 podobne dielce: preskocena skrinka nie je v mape ani v pocte') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  src = d134_part('CAB-001', 'shelf', 'DEKOR_A', 11, key: 'CAB-001-SHELF-1')
  a = d134_cab('CAB-001', 1, parts: [src, d134_part('CAB-001', 'shelf', 'DEKOR_A', 12,
                                                    key: 'CAB-001-SHELF-2')])
  b = d134_cab('CAB-002', 2, parts: [d134_part('CAB-002', 'shelf', 'DEKOR_A', 21,
                                               key: 'CAB-002-SHELF-1')])
  model = D134Model.new([a, b, d134_detached('CAB-002', 31)])

  map, skipped = d134_with_sketchup { D134PANEL.similar_parts_map(model, a, src, 'project') }
  NxTest.assert_equal(['CAB-001'], map.keys, 'skrinka s odpojenym dielcom vypadla')
  NxTest.assert_equal(['CAB-002'], skipped)
  # POCET = ZAPIS: modal ukaze presne tolko, kolko sa zapise.
  NxTest.assert_equal(1, D134PANEL.similar_parts_count(map))

  veta = D134PANEL.similar_skipped_text(skipped)
  NxTest.assert(veta.start_with?('Preskočené: CAB-002 ('), veta)
  NxTest.assert(veta.include?(D134IDS::DETACHED_PART_REASON), veta)
  NxTest.assert_equal('', D134PANEL.similar_skipped_text([]),
                      'bezna zakazka riadok v modale vobec nema')
end

NxTest.test('D-134 podobne dielce (P3-3): rozsah „táto skrinka" odmietne INY odpojeny dielec') do
  NxTest.skip!('potrebuje stub SketchUp tried') unless NxTest.headless?
  # `similar_context` (`detached_part_error`) kryje LEN oznaceny dielec. Ked ma
  # skrinka vytiahnuty INY dielec, zapis by vyrobil presne toho dvojnika, pred
  # ktorym strazi rozsah „celý projekt" — preto idu oba rozsahy tym istym filtrom.
  src = d134_part('CAB-001', 'shelf', 'DEKOR_A', 11, key: 'CAB-001-SHELF-1')
  a = d134_cab('CAB-001', 1, parts: [src, d134_part('CAB-001', 'shelf', 'DEKOR_A', 12,
                                                    key: 'CAB-001-SHELF-2')])
  model = D134Model.new([a, d134_detached('CAB-001', 31)])

  map, skipped = d134_with_sketchup { D134PANEL.similar_parts_map(model, a, src, 'cabinet') }
  NxTest.assert_equal({}, map, 'skrinka s INYM odpojenym dielcom sa nezapise ani vo vlastnom rozsahu')
  NxTest.assert_equal(['CAB-001'], skipped, 'a VYMENUJE sa — nikdy ticho')
  NxTest.assert_equal(0, D134PANEL.similar_parts_count(map))

  # Bez odpojeneho dielca je vysledok NEZMENENY (charakterizacia).
  clean = D134Model.new([a])
  map2, skipped2 = d134_with_sketchup { D134PANEL.similar_parts_map(clean, a, src, 'cabinet') }
  NxTest.assert_equal(['CAB-001'], map2.keys)
  NxTest.assert_equal([], skipped2)
  NxTest.assert_equal(1, D134PANEL.similar_parts_count(map2))
end

NxTest.test('D-134 podobne dielce (P3-3): prazdny vysledok s preskocenymi NEKLAME o pricine') do
  body = D134Src.body('ui/panel/actions_parts.rb', 'handle_apply_edges_similar')
  NxTest.assert(body.include?('if skipped.empty?'),
                'hlaska sa rozvetvuje podla toho, ci je co preskocene')
  NxTest.assert(body.include?('nie je na čo olep použiť'),
                'pri preskocenych sa veta o „rovnakej role a materiáli" VYNECHAVA')
  NxTest.assert(body.include?('similar_skipped_text(skipped)'),
                'a preskocene skrinky sa vymenuju')
end

NxTest.test('D-134 podobne dielce: JEDINA autorita poctu aj zapisu') do
  count = D134Src.body('ui/panel/actions_parts.rb', 'handle_similar_parts_count')
  apply = D134Src.body('ui/panel/actions_parts.rb', 'handle_apply_edges_similar')
  NxTest.assert(count.include?('map, skipped = similar_parts_map(model, cab, part, scope)'),
                'pocet berie mapu AJ preskocene z tej istej funkcie')
  NxTest.assert(apply.include?('map, skipped = similar_parts_map(model, cab, part, scope)'),
                'zapis sa pyta TEJ ISTEJ funkcie')
  NxTest.assert(count.include?('skipped: similar_skipped_text(skipped)'),
                'modal dostava HOTOVU vetu zo servera')
  NxTest.assert(apply.include?('similar_skipped_text(skipped)'),
                'status po zapise preskocene tiez menuje')
  map = D134Src.body('ui/panel/actions_parts.rb', 'similar_parts_map')
  NxTest.assert(map.include?('job_cabinets(model)') && !map.include?('all_cabinets(model)'),
                'vyberova funkcia stoji na zbere ZAKAZKY')
end

# ---------------------------------------------------------------------------
# 5) ZDROJOVE GUARDY NAPRIEC (R1) — ziadna zapisova vetva na globalnom prechode
# ---------------------------------------------------------------------------

NxTest.test('D-134 guard: ziadna z troch zapisovych ciest nechodi globalne') do
  [['ui/rules_dialog.rb', 'handle_save'],
   ['ui/rules_dialog.rb', 'handle_merge_seed'],
   ['ui/materials_dialog.rb', 'handle_set_project_material'],
   ['ui/panel/actions_parts.rb', 'similar_parts_map']].each do |rel, name|
    body = D134Src.body(rel, name)
    NxTest.assert(!body.empty?, "#{rel}##{name} sa nasiel")
    NxTest.assert(!body.include?('Ids.each_cabinet'), "#{rel}##{name}: ziadny `Ids.each_cabinet`")
    NxTest.assert(!body.include?('all_cabinets('), "#{rel}##{name}: ziadny `all_cabinets`")
  end
end

NxTest.test('D-134 guard (P3-4): medzi zberom skriniek a prestavbou NIE JE early return') do
  # Invariant „projektovy zapis prebehne aj pri 0 joboch" stoji na tom, ze sa
  # medzi rozdelenim zakazky a `rebuild_many` NIKTO neotoci. Skratka typu
  # `return if jobs.empty?` by ho zrusila TICHO — zakazka by ostala bez
  # ulozenych pravidiel/predvolby a pouzivatel by videl hlasku o uspechu.
  [['ui/rules_dialog.rb', 'handle_save', 'Panel.job_cabinets_split(model)', true],
   ['ui/rules_dialog.rb', 'handle_merge_seed', 'Panel.job_cabinets_split(model)', true],
   # Projektova predvolba ma medzi zberom a prestavbou LEGITIMNE navraty: brany
   # hrubky/receptov a ponuku na potvrdenie. Tie odmietaju CELU zmenu (a hovoria
   # preco) — to je opak ticheho preskocenia zapisu. Strazi sa teda len to, ze
   # dovodom navratu NIE JE prazdny zoznam jobov.
   ['ui/materials_dialog.rb', 'handle_set_project_material', 'Panel.job_split(', false]]
    .each do |rel, name, split, no_return|
    body = D134Src.body(rel, name)
    from = body.index(split)
    to = body.index('CabinetBuilder.rebuild_many')
    NxTest.assert(from && to && from < to, "#{rel}##{name}: zber stoji PRED prestavbou")
    between = body[from...to]
    NxTest.assert(!between.match?(/^\s*return\b/),
                  "#{rel}##{name}: medzi zberom a prestavbou ziadny `return`") if no_return
    NxTest.assert(!between.match?(/\b(jobs|affected|job_cabs)\s*\.empty\?/),
                  "#{rel}##{name}: prazdny zoznam jobov NIE JE dovod preskocit zapis")
  end
end

NxTest.test('D-134 guard: helper stoji na zdielanom `Ids.top_level_scan`') do
  body = D134Src.body('ui/panel/payloads.rb', 'job_cabinets')
  NxTest.assert(body.include?('Ids.top_level_scan(model)'),
                'vsetkych pat hromadnych zapisov zdiela JEDEN prechod korenom')
  # Slepe review P3-2: `all_cabinets` ZANIKLO — prazdny obal bez volajuceho
  # by len zvadzal vratit sa nim do zapisovej vetvy.
  NxTest.assert(!D134Src.src('ui/panel/payloads.rb').include?('def all_cabinets'),
                'globalny obal uz v Paneli nezije')
end
