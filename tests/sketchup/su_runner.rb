# frozen_string_literal: true
# Noxun Engine — in-SketchUp test runner (milnik V0.3.4). Spustanie:
#   -RubyStartup bootstrap (scripts/run_su_tests.ps1) alebo v Ruby konzole test okna:
#   load 'C:/APP DEV/RUBY/ENGINE/tests/sketchup/su_runner.rb'
#
# BEZPECNOST: bezi VYHRADNE v modeli ENGINEtests*.skp alebo v neulozenom Untitled
# (pravidla ENGINE/CLAUDE.md). V inom modeli sa okamzite ukonci so SKIP.
# Vystup: subor ENV['NOXUN_SU_OUT'] (default %TEMP%/noxun_su_result.txt) — riadky
# PASS/FAIL/INFO + koncovy marker '=== KONIEC SUBORU ==='. Undo scenare S1/S2 su
# od V0.3.4 undo fixov TVRDE asserty (transparentne operacie absorpcie a dedupu);
# INFO ostava len pre redo pozorovania (Ruby API nema spolahlive redo na Windows).
#
# Struktura:
#   SYNC-VYSTUHY (H3/D-80) — vnutro konci pod hornymi vystuhami: odsadenie flat,
#     orientacia upright, vyska chrbta inset, odmietnutie rebuildu pri zmensenom
#     vnutre + warning o orezanom odsadeni.
#   SYNC cast — geometria proti BuildPlan kontraktu (plan vs. model 1:1), NOXUN data
#     dielcov, ghost zony, rebuild identita + prezitie part_overrides, dedup kopie
#     (priame volanie), undo rebuildu = presne 1 krok; D-45 sekcia (hrubka <->
#     material tela: adopcia hrubky, auto-pick materialu, vklad, zamok x sablona —
#     bezi nad DOCASNYM testovacim dekorom, ktory po sebe upratuje); D-46 sekcia
#     (projektova predvolba korpusu s inou hrubkou: ponuka -> potvrdenie -> 1 undo
#     krok, blokujuce dielce, zastaraly suhlas); V0.4.7b sync-board sekcia
#     (build/rebuild/undo/dedup samostatnej dosky, standard 8.3); D-35 sync-abs
#     sekcia (bulk olepenie 4 hran = 1 undo, echo guardy, no-op bez ABS variantu);
#     2A-2 sekcia (migracia katalogu na SCHEMA 2 nad IZOLOVANYM katalogom cez
#     Materials.test_dir_override — dry_run/ostry beh, rebuild, BOM, semafor
#     abs_missing, remap; realny %APPDATA% katalog sa necita ani nezapisuje).
#   UI-C1c sekcia — ORIENTACIA DOSKY (leziaca/stojaca/na_stenu): svetove osi,
#     normala dekorovej plochy a kotviace roviny pre kazdu hodnotu, zhodnost
#     matic stojaca/na_stenu (lisi sa POLE, nie bbox), zmena orientacie ako
#     DELTA (rucne otocenie prezije, opakovanie nekumuluje), 1 undo krok,
#     rebuild transformaciu nemeni, cache scale observera ide s otocenim
#     (odmietnuty scale vracia do OTOCENEJ polohy), dedup kopie, guard neznamej
#     hodnoty a NEDOTKNUTY vyrobny obraz (kusovnik = vstup VEPO).
#   D-90 sekcia — vizual uchytkoveho profilu UKW-7: kotva proxy (vrch riadku,
#     zadna rovina cela, dlzka = sirka kridla, prekryv „nosa" 1,419 mm), proxy
#     kontrakt, zdielana definicia per (profil, dlzka), reprodukovatelny rebuild,
#     vypnutie profilu a undo.
#   ASYNC cast — retaz UI.start_timer krokov (observer debounce = 0.2 s):
#     S1 scale -> absorpcia -> Ctrl+Z (audit riziko: re-absorpcia po undo)
#     S2 kopia -> observer dedup -> Ctrl+Z (audit riziko: zapis ID mimo operacie)
#     S3 kopia DOSKY -> observer dedup (nove BRD id) -> Ctrl+Z (V0.4.7b)
#     S4 miesana davka stale+fresh duplicit -> fresh v paste ticku, stale follow-up
#     S5 scale DOSKY (V0.4.7d): X absorpcia+undo, vertikalna doska (global Z =
#        lokalna sirka), X+Z kombinacia (hrubka drzi material), reject bez materialu
#     D-101 panel po Spat/Znova: Ctrl+Z/Ctrl+Y obnovi Inspector sam — refresh
#        bezi PRESNE raz, s dedup:false a BEZ noveho undo kroku; coalescing dvoch
#        rychlych undo; detach/anti-double/multi-model/zlyhany remove sa dokazuju
#        POCITADLOM vstupov do handlera (nie „neprisiel push"). Redo vetva je
#        VRSTVENA (Ruby API nema na Windows spolahlivu redo akciu): editRedo ->
#        legacy numericke ID -> priama invokacia onTransactionRedo. Cesta sa
#        kvalifikuje UCINKOM, nie navratovou hodnotou (numericke ID vracia na
#        Windows true a nespravi nic); pouzita cesta sa vzdy prizna v INFO riadku.
#     S6 nasobenie kopii `*N` (D-103): kopia s OTVORENYM Inspectorom (Panel.push_selected)
#        -> interne undo nastroja MUSI odstranit kopiu (ziadna zombie) -> pole 4 kopii
#        = presne 5 dosiek s 5 ID na 5 roznych miestach; S6b = zachytna siet v KONTROLE
#        (Bom.collect placements -> Validation duplicate_position -> klik oznaci obe)
#
# Cistenie: kazdy scenar maze svoje korpusy v ScaleWatch.guard (inak by debounce
# timer po skonceni testu vykonal dedup/prune nekontrolovane) + purge_unused.

require 'tmpdir'
require 'fileutils'

module NoxunSuRunner
  OUT = (ENV['NOXUN_SU_OUT'] && !ENV['NOXUN_SU_OUT'].empty? ? ENV['NOXUN_SU_OUT'] : File.join(Dir.tmpdir, 'noxun_su_result.txt'))
  TOL = 0.1     # mm — tolerancia geometrie (Length konverzie)
  SETTLE = 1.2  # s — cakanie na ustalenie observer debounce (0.2 s) + rezerva

  module_function

  def log_line(msg)
    File.open(OUT, 'a') { |f| f.puts(msg) }
  end

  def ok(name, cond)
    log_line("#{cond ? 'PASS' : 'FAIL'}: #{name}")
    cond
  end

  def info(msg)
    log_line("INFO: #{msg}")
  end

  def e
    Noxun::Engine
  end

  def mm(len)
    e::Units.to_mm(len)
  end

  # Guard (Codex review PR #20, P1 + V0.4.7b): Untitled NEstaci — neulozena moze byt
  # aj zakazka. Povolene: (a) model ENGINEtests*.skp, alebo (b) neulozeny model BEZ
  # jedineho NOXUN vlastnickeho objektu (korpus AJ doska — cerstve testovacie okno;
  # nie je co znicit, vsetko dalej vyrobi runner sam).
  def guard_model?(model)
    path = model ? model.path.to_s : ''
    base = path.gsub('\\', '/').downcase.split('/').last.to_s
    return true if base.start_with?('enginetests')
    path.empty? && cabinets(model).empty? && boards(model).empty?
  end

  def cabinets(model)
    out = []
    e::Ids.each_cabinet(model) { |i| out << i }
    out
  end

  def boards(model)
    out = []
    e::Ids.each_board(model) { |i| out << i }
    out
  end

  # Zmaze vsetky NOXUN korpusy, dosky + ghosty v guarde (observer nedostane vlastne upratovanie).
  def cleanup(model)
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST cleanup', true)
      cabinets(model).each { |i| i.erase! if i.valid? }
      boards(model).each { |i| i.erase! if i.valid? }
      e::Zones.prune_orphans(model) if defined?(e::Zones)
      model.commit_operation
      model.definitions.purge_unused
    end
  rescue StandardError => ex
    log_line("FAIL: cleanup vynimka: #{ex.class}: #{ex.message}")
  end

  # --- SYNC: geometria proti BuildPlan kontraktu -----------------------------

  def run_sync(model)
    params = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
               'top_mode' => 'two_rails', 'rails_orientation' => 'flat',
               # wings PINNUTE na '1': auto by pri teste sirky 600->650 prepol single->left/right
               # (zmena topologie = legitimna zmena part_key; test identity potrebuje stabilny pocet kridel)
               'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
               'zone_tree' => { 'id' => 'Z1', 'split' => { 'axis' => 'v', 'count' => 2,
                                                           'cuts' => [{ 'size' => nil }, { 'size' => nil }] },
                                'children' => [
                                  { 'id' => 'ZL', 'shelves' => 1, 'children' => [] },
                                  { 'id' => 'ZR', 'shelves' => 0, 'children' => [] }
                                ] } }
    inst = e::CabinetBuilder.build(model, params)
    return ok('sync: vlozenie korpusu', false) unless inst

    cid = e::Store.get(inst, 'cabinet_id')
    cfg = e::Store.config(inst) || {}
    plan = e::Construction.build_plan(e::CabinetBuilder.normalize(params), cid)

    # 1) plan vs. model 1:1 — pocet a identita dielcov
    parts = inst.definition.entities.grep(Sketchup::ComponentInstance)
                .select { |i| e::Store.kind(i) == 'part' }
    ok("sync: pocet dielcov plan #{plan[:parts].length} == model #{parts.length}",
       plan[:parts].length == parts.length)
    model_keys = parts.map { |i| e::Store.get(i, 'part_key') }.sort
    plan_keys = plan[:parts].map { |pd| pd[:part_key].to_s }.sort
    ok('sync: mnozina part_key plan == model', model_keys == plan_keys)

    # 2) geometria kazdeho dielca: origin (transformacia) + rozmery definicie proti planu
    geo_bad = []
    plan[:parts].each do |pd|
      pi = parts.find { |i| e::Store.get(i, 'part_key') == pd[:part_key].to_s }
      next geo_bad << "#{pd[:part_key]} chyba" unless pi
      po = pi.transformation.origin
      org = [mm(po.x), mm(po.y), mm(po.z)]
      unless org.zip(pd[:origin]).all? { |a, b| (a - b.to_f).abs <= TOL }
        geo_bad << "#{pd[:part_key]} origin #{org.map { |v| v.round(2) }} != #{pd[:origin]}"
      end
      b = pi.definition.bounds
      dims = [mm(b.width), mm(b.height), mm(b.depth)]
      unless dims.zip(pd[:box]).all? { |a, bx| (a - bx.to_f).abs <= TOL }
        geo_bad << "#{pd[:part_key]} box #{dims.map { |v| v.round(2) }} != #{pd[:box]}"
      end
      unless pi.definition.name == "NOXUN #{cid} #{pd[:suffix]}"
        geo_bad << "#{pd[:part_key]} meno definicie '#{pi.definition.name}'"
      end
    end
    ok("sync: geometria dielcov sedi s planom (#{geo_bad.length} nezhod)#{geo_bad.empty? ? '' : ' — ' + geo_bad.first(3).join('; ')}",
       geo_bad.empty?)

    # 3) NOXUN data dielca: round-trip configu + kontraktove polia
    sample = parts.find { |i| e::Store.get(i, 'role') == 'shelf' } || parts.first
    scfg = e::Store.config(sample) || {}
    ok('sync: dielec nesie config s length/width/thickness/material_id/edges',
       %w[length width thickness quantity edges].all? { |k| scfg.key?(k) })
    ok('sync: dielec production_class=sheet, manufactured=true',
       e::Store.get(sample, 'production_class') == 'sheet' && e::Store.get(sample, 'manufactured') == true)

    # 4) ghost zony: kazda listova zona ma top-level skupinu
    leaves = (cfg['zones'] || []).select { |z| z['leaf'] }
    missing = leaves.reject { |z| e::Zones.find_zone_group(model, cid, z['id']) }
    ok("sync: ghost skupina pre kazdu listovu zonu (#{leaves.length} zon)", !leaves.empty? && missing.empty?)

    # 5) rebuild identita + prezitie part_override
    shelf_key = 'zone:ZL/shelf:1'
    p2 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p2['part_overrides'] = { shelf_key => { 'edges' => { 'L1' => nil } } }
    p2['width'] = 650.0
    e::CabinetBuilder.rebuild(model, inst, p2)
    cfg2 = e::Store.config(inst) || {}
    keys_after = inst.definition.entities.grep(Sketchup::ComponentInstance)
                     .select { |i| e::Store.kind(i) == 'part' }
                     .map { |i| e::Store.get(i, 'part_key') }.sort
    ok('sync: rebuild (sirka 600->650) zachoval mnozinu part_key', keys_after == plan_keys)
    ok('sync: part_override prezil rebuild na stabilnom kluci',
       (cfg2['part_overrides'] || {}).key?(shelf_key))

    # 6) undo rebuildu = PRESNE 1 krok (sirka spat na 600)
    Sketchup.undo
    cfg3 = e::Store.config(inst) || {}
    ok("sync: 1x undo vratil rebuild (sirka #{cfg3['width']})", (cfg3['width'].to_f - 600.0).abs < 0.01)

    # 7) V0.4 kovanie: data v configu + vizual noh (proxy) + rucny zasah a reset
    cfgh = e::Store.config(inst) || {}
    hw = cfgh['hardware'] || []
    leg = hw.find { |h| h['generic_type'] == 'leg' }
    hinge = hw.find { |h| h['generic_type'] == 'hinge' }
    ok('sync: config.hardware — nohy 4 ks na korpuse (owner nil)',
       !leg.nil? && leg['quantity'] == 4 && leg['owner_part_key'].nil?)
    ok('sync: config.hardware — zavesy 2 ks na kridle front:F1/wing:single',
       !hinge.nil? && hinge['quantity'] == 2 && hinge['owner_part_key'] == 'front:F1/wing:single')
    legs_inst = inst.definition.entities.grep(Sketchup::ComponentInstance)
                    .find { |i| e::Store.kind(i) == 'hardware' }
    lb = legs_inst && legs_inst.definition.bounds
    ok('sync: vizual noh = proxy (kind=hardware, none/false, vyska = sokel 100)',
       !legs_inst.nil? && e::Store.get(legs_inst, 'production_class') == 'none' &&
       e::Store.get(legs_inst, 'manufactured') == false &&
       !lb.nil? && (mm(lb.depth) - 100.0).abs <= TOL)
    p3 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p3['hardware_overrides'] = [{ 'owner_part_key' => nil, 'generic_type' => 'leg',
                                  'rule_id' => 'nohy-zakladne', 'quantity' => 6 }]
    e::CabinetBuilder.rebuild(model, inst, p3)
    leg2 = ((e::Store.config(inst) || {})['hardware'] || []).find { |h| h['generic_type'] == 'leg' }
    ok('sync: rucny pocet noh 6 (source manual, rule_quantity 4)',
       !leg2.nil? && leg2['quantity'] == 6 && leg2['source'] == 'manual' && leg2['rule_quantity'] == 4)
    p4 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p4['hardware_overrides'] = []
    e::CabinetBuilder.rebuild(model, inst, p4)
    leg3 = ((e::Store.config(inst) || {})['hardware'] || []).find { |h| h['generic_type'] == 'leg' }
    ok('sync: reset zasahu — plati zas pravidlo (4 ks, source rule)',
       !leg3.nil? && leg3['quantity'] == 4 && leg3['source'] == 'rule')

    # 7b) D-07 medzery a presahy cel: zaporne okraje = celo presahuje obrys.
    #     Asserty VOCI floor_height (Codex N9): z = floor + gap_bottom, nie globalna 0.
    p5 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p5['fronts'] = (p5['fronts'] || {}).merge('gap' => 10.0, 'gap_top' => -15.0,
                                              'gap_bottom' => -30.0, 'gap_sides' => -20.0)
    e::CabinetBuilder.rebuild(model, inst, p5)
    cfg5 = e::Store.config(inst) || {}
    fh5 = cfg5['floor_height'].to_f
    front5 = inst.definition.entities.grep(Sketchup::ComponentInstance)
                 .find { |i| e::Store.get(i, 'part_key') == 'front:F1/wing:single' }
    fo = front5 && front5.transformation.origin
    fb = front5 && front5.definition.bounds
    exp_z = fh5 - 30.0                                   # floor + gap_bottom
    exp_h = (720.0 - fh5) + 15.0 + 30.0                  # total_v - gt - gb
    ok("sync: D-07 presah dole — celo z=#{fo ? mm(fo.z).round(1) : 'nil'} (floor #{fh5} - 30)",
       !front5.nil? && (mm(fo.z) - exp_z).abs <= TOL)
    ok('sync: D-07 presah do stran — celo x=-20, sirka 640',
       !front5.nil? && (mm(fo.x) - (-20.0)).abs <= TOL && (mm(fb.width) - 640.0).abs <= TOL)
    ok("sync: D-07 vyska cela #{fb ? mm(fb.depth).round(1) : 'nil'} = #{exp_h} (presah hore aj dole)",
       !front5.nil? && (mm(fb.depth) - exp_h).abs <= TOL)
    fi5 = (cfg5['front_items'] || []).first
    ok('sync: D-07 resolved front_items nesie wings_n',
       !fi5.nil? && fi5['wings_n'] == 1)
    p6 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p6['fronts'] = (p6['fronts'] || {}).merge('gap' => 3.0, 'gap_top' => 2.0,
                                              'gap_bottom' => 2.0, 'gap_sides' => 2.0)
    e::CabinetBuilder.rebuild(model, inst, p6)

    # 7c) D-18 celo BEZ: prepnutie dvierok na 'none' odstrani front dielec (autorita
    #     BOM/VEPO = snapshoty na entitach) aj zavesy; 1x undo vrati oboje; opakovany
    #     rebuild na none = deterministicka dopredna cesta (redo cez send_action je
    #     asynchronne — sync sekcia drzi synchronne kroky, redo pokryva async S1).
    front_parts = lambda do
      inst.definition.entities.grep(Sketchup::ComponentInstance)
          .select { |i| e::Store.kind(i) == 'part' && e::Store.get(i, 'part_key').to_s.start_with?('front:') }
    end
    p7 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p7['fronts'] = (p7['fronts'] || {}).merge('items' => [
      { 'id' => 'F1', 'type' => 'none', 'mode' => 'auto', 'wings' => 1 }
    ])
    e::CabinetBuilder.rebuild(model, inst, p7)
    cfg7 = e::Store.config(inst) || {}
    hw7 = cfg7['hardware'] || []
    ok('sync: D-18 none — ziadny front dielec v modeli (nika)', front_parts.call.empty?)
    ok('sync: D-18 none — ziadne kovanie frontu (hinge prec, nohy ostavaju)',
       hw7.none? { |h| h['owner_part_key'].to_s.start_with?('front:') } &&
       hw7.none? { |h| h['generic_type'] == 'hinge' } &&
       hw7.any? { |h| h['generic_type'] == 'leg' })
    fi7 = (cfg7['front_items'] || []).first
    ok("sync: D-18 none — front_items nesie niku (type none, vyska #{fi7 ? fi7['height'] : 'nil'})",
       !fi7.nil? && fi7['type'] == 'none' && fi7['height'].to_f > 0)
    Sketchup.undo
    cfg7u = e::Store.config(inst) || {}
    ok('sync: D-18 1x undo vratil dvierka (front dielec + zavesy v configu)',
       front_parts.call.length == 1 &&
       (cfg7u['hardware'] || []).any? { |h| h['generic_type'] == 'hinge' })
    e::CabinetBuilder.rebuild(model, inst, p7)
    ok('sync: D-18 opatovny rebuild na none znovu odstranil front dielec', front_parts.call.empty?)
    p8 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p8['fronts'] = (p8['fronts'] || {}).merge('items' => [
      { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }
    ])
    e::CabinetBuilder.rebuild(model, inst, p8) # navrat na dvierka pre dalsie kroky

    # 7d) D-24 kridla dvierok: 3 kridla = 3 fyzicke dielce s unikatnymi part_id
    #     a definiciami (suffix DOOR-1-P1..P3 recykluje definicie per kridlo),
    #     spravne sirky a 3 polozky zavesov v config.hardware[] (autorita supisu).
    p9 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p9['fronts'] = (p9['fronts'] || {}).merge('items' => [
      { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '3' }
    ])
    e::CabinetBuilder.rebuild(model, inst, p9)
    cfg9 = e::Store.config(inst) || {}
    wings9 = front_parts.call
    keys9 = wings9.map { |i| e::Store.get(i, 'part_key') }.sort
    ok('sync: D-24 tri kridla = 3 fyzicke dielce (wing:p1..p3)',
       wings9.length == 3 && keys9 == %w[front:F1/wing:p1 front:F1/wing:p2 front:F1/wing:p3])
    pids9 = wings9.map { |i| e::Store.get(i, 'part_id') }
    defs9 = wings9.map(&:definition)
    exp_defs = (1..3).map { |i| "NOXUN #{cid} DOOR-1-P#{i}" }.sort
    ok("sync: D-24 unikatne part_id a definicie (#{pids9.sort.join(', ')})",
       pids9.uniq.length == 3 && defs9.uniq.length == 3 && defs9.map(&:name).sort == exp_defs)
    exp_dw = ((600.0 - 2 * 2.0) - 2 * 3.0) / 3.0 # (opening 596 - 2x gap 3) / 3
    widths9 = wings9.map { |i| mm(i.definition.bounds.width) }
    ok("sync: D-24 sirky kridiel #{widths9.map { |v| v.round(1) }.join('/')} = #{exp_dw.round(2)}",
       widths9.length == 3 && widths9.all? { |w| (w - exp_dw).abs <= TOL })
    hinges9 = (cfg9['hardware'] || []).select { |h| h['generic_type'] == 'hinge' }
    ok('sync: D-24 tri polozky zavesov v config.hardware[] (per kridlo)',
       hinges9.length == 3 &&
       hinges9.map { |h| h['owner_part_key'] }.sort == %w[front:F1/wing:p1 front:F1/wing:p2 front:F1/wing:p3])

    # 7e) D-24 identita: ABS override na wing:left prezije 2->2 rebuild (zmena
    #     sirky nemeni topologiu kridiel — kluce left/right ostavaju).
    p10 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p10['fronts'] = (p10['fronts'] || {}).merge('items' => [
      { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '2' }
    ])
    p10['part_overrides'] = (p10['part_overrides'] || {})
                            .merge('front:F1/wing:left' => { 'edges' => { 'L1' => nil } })
    e::CabinetBuilder.rebuild(model, inst, p10)
    p11 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p11['width'] = 650.0
    e::CabinetBuilder.rebuild(model, inst, p11) # 2->2 rebuild so zmenou sirky
    cfg11 = e::Store.config(inst) || {}
    left11 = inst.definition.entities.grep(Sketchup::ComponentInstance)
                 .find { |i| e::Store.get(i, 'part_key') == 'front:F1/wing:left' }
    lcfg11 = left11 ? (e::Store.config(left11) || {}) : {}
    ok('sync: D-24 ABS override wing:left prezil 2->2 rebuild (config aj dielec)',
       (cfg11['part_overrides'] || {}).key?('front:F1/wing:left') &&
       !left11.nil? && lcfg11['edges'].is_a?(Hash) &&
       lcfg11['edges'].key?('L1') && lcfg11['edges']['L1'].nil?)
    # navrat na stav pred 7d (sirka 600, 1 kridlo, bez overridov) pre sekciu 8
    p12 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p12['width'] = 600.0
    p12['fronts'] = (p12['fronts'] || {}).merge('items' => [
      { 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }
    ])
    p12['part_overrides'] = {}
    e::CabinetBuilder.rebuild(model, inst, p12)

    # 8) dedup kopie (priame volanie, synchronne): kopia dostane nove cid, original drzi
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST kopia', true)
      tr = inst.transformation * Geom::Transformation.translation(e::Units.vector(800, 0, 0))
      copy = model.entities.add_instance(inst.definition, tr)
      %w[std kind id cabinet_id template_id role part_key_schema manufactured production_class config].each do |k|
        v = e::Store.get(inst, k)
        copy.set_attribute('NOXUN', k, v) unless v.nil?
      end
      model.commit_operation
    end
    changed = e::CabinetBuilder.dedup_copies(model)
    ids = cabinets(model).map { |i| e::Store.get(i, 'cabinet_id') }
    ok("sync: dedup kopie — nove ID (#{ids.sort.join(', ')})",
       changed.length == 1 && ids.uniq.length == 2 && ids.include?(cid))
    ok('sync: original si drzi povodne cid', e::Store.get(inst, 'cabinet_id') == cid)

    # 9) V0.4.7b samostatna doska: build -> atributy/geometria, rebuild identita,
    #    undo = 1 krok, dedup kopie (priame volanie). Standard 8.3.
    binst = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                           'length' => 720.0, 'width' => 580.0,
                                           'name' => 'Testovacia doska' })
    return ok('sync-board: vlozenie dosky', false) unless binst

    bid = e::Store.get(binst, 'id')
    ok("sync-board: identita a ploche atributy (#{bid})",
       bid.to_s.match?(/\ABRD-\d+\z/) && e::Store.kind(binst) == 'board' &&
       e::Store.get(binst, 'part_key') == 'board/main' &&
       e::Store.get(binst, 'manufactured') == true &&
       e::Store.get(binst, 'production_class') == 'sheet' &&
       e::Store.get(binst, 'role') == 'free_panel')
    bcfg = e::Store.config(binst) || {}
    ok('sync-board: config nesie vyrobne polia (rozmery/material/edges/quantity)',
       (bcfg['length'].to_f - 720.0).abs < 0.01 && (bcfg['width'].to_f - 580.0).abs < 0.01 &&
       (bcfg['thickness'].to_f - 18.0).abs < 0.01 && bcfg['material_id'] == 'K009_PW_DTDL_18' &&
       bcfg['edges'].is_a?(Hash) && bcfg['edges'].key?('L1') && bcfg['quantity'] == 1)
    ok('sync-board: ABS default free_panel (1 pozdlzna 1.0)',
       bcfg['edges']['L1'] == 'ABS_K009_10' && bcfg['edges']['L2'].nil?)
    bb = binst.definition.bounds
    ok('sync-board: geometria = config (720x580x18, length=X width=Y thickness=Z)',
       (mm(bb.width) - 720.0).abs <= TOL && (mm(bb.height) - 580.0).abs <= TOL &&
       (mm(bb.depth) - 18.0).abs <= TOL)
    ok("sync-board: meno definicie 'NOXUN Doska #{bid}'",
       binst.definition.name == "NOXUN Doska #{bid}")

    e::BoardBuilder.rebuild(model, binst, { 'width' => 600.0 })
    bcfg2 = e::Store.config(binst) || {}
    ok('sync-board: rebuild (580->600) zachoval identitu, zmenil sirku, drzi material',
       e::Store.get(binst, 'id') == bid && (bcfg2['width'].to_f - 600.0).abs < 0.01 &&
       bcfg2['material_id'] == 'K009_PW_DTDL_18')
    Sketchup.undo
    bcfg3 = e::Store.config(binst) || {}
    ok("sync-board: 1x undo vratil rebuild (sirka #{bcfg3['width']})",
       (bcfg3['width'].to_f - 580.0).abs < 0.01)

    e::ScaleWatch.guard do
      model.start_operation('SU-TEST kopia dosky', true)
      tr2 = binst.transformation * Geom::Transformation.translation(e::Units.vector(900, 0, 0))
      bcopy = model.entities.add_instance(binst.definition, tr2)
      %w[std kind id part_id part_key part_key_schema role name manufactured production_class config].each do |k|
        v = e::Store.get(binst, k)
        bcopy.set_attribute('NOXUN', k, v) unless v.nil?
      end
      model.commit_operation
    end
    bchanged = e::BoardBuilder.dedup_copies(model)
    bids = boards(model).map { |i| e::Store.get(i, 'id') }
    ok("sync-board: dedup kopie — nove ID bez prekreslenia (#{bids.sort.join(', ')})",
       bchanged.length == 1 && bids.uniq.length == 2 && bids.include?(bid))
    ok('sync-board: original drzi id, kopia ma vlastnu definiciu s novym menom',
       e::Store.get(binst, 'id') == bid && bchanged.first.definition != binst.definition &&
       bchanged.first.definition.name.start_with?('NOXUN Doska BRD-'))

    # 10) V0.4.7c panel vrstva: payload kontrakt + guard oneskoreneho zapisu.
    #     Dialog nie je otvoreny — Panel.js() je no-op, handlery bezia naplno.
    pay = e::Panel.board_payload(binst)
    ok('sync-board: board_payload nesie kompletny kontrakt karty',
       %w[board_id name role role_label length width thickness material_id
          grain_direction edges edge_labels edge_sides quantity].all? { |k| pay.key?(k) })
    e::Panel.select_only(model, binst)
    e::Panel.handle_set_board_fields({ 'board_id' => 'BRD-999', 'fields' => { 'width' => 555.0 } }.to_json)
    ok('sync-board: guard zahodil zapis s nespravnym echo board_id',
       ((e::Store.config(binst) || {})['width'].to_f - 580.0).abs < 0.01)

    e::Panel.handle_set_board_fields({ 'board_id' => bid, 'fields' => { 'width' => 555.0 } }.to_json)
    ok('sync-board: panel zapis presiel (width 555)',
       ((e::Store.config(binst) || {})['width'].to_f - 555.0).abs < 0.01)
    e::Panel.handle_set_board_edge({ 'board_id' => bid, 'edge' => 'W1', 'abs_id' => 'ABS_K009_20' }.to_json)
    ecfg = (e::Store.config(binst) || {})['edges'] || {}
    ok('sync-board: ABS hrana W1 cez panel, L1 default drzi (read-modify-write)',
       ecfg['W1'] == 'ABS_K009_20' && ecfg['L1'] == 'ABS_K009_10')
    # Codex GH #33: materials_payload nesie grain (vkladacia karta predvyplna smer)
    mp = e::Panel.materials_payload
    ok('sync-board: materials_payload sheets nesu grain',
       mp['sheets'].is_a?(Array) && mp['sheets'].all? { |s| s.key?('grain') })
    # Codex GH #33: zmena materialu prevedie ABS stareho dekoru (1mm ma variant,
    # 2mm v W1000 nema -> nil) a material bez dekoru zhodi smer dekoru na none.
    # 2A-3 rider (environmentalny FAIL 30.7.): zivy katalog nemusi obsahovat
    # seed pasku ABS_W1000_10 — ak W1000 nema jednotkovu pasku, docasne sa
    # vytvori (presny seed tvar) a na KONCI run_sync sa katalog vrati do
    # povodneho stavu. Ocakavania sa citaju z pickera PRED zmenou materialu —
    # ked paska existuje (seed stav), asserty su presne povodne.
    # Codex GH #90 P1: rename dekoru ID zamerne zachovava — zaznam s tymto ID
    # moze zit pod inym dekorom, decor-lookup ho nevidi a seed by ho PREPISAL.
    # Preto snapshot PODLA ID pred zasahom a navrat presneho zaznamu v cleanupe
    # (delete len ked predtym neexistoval).
    # GH #90 P2 (4. kolo): rider je SCHEMA-AWARE — v marker-2 katalogu docasna
    # paska dedi group_id + strukturu sheetu (legacy tvar by write guard
    # odmietol) a ocakavania sa citaju rovnakym pickerom ako server.
    w1000_seeded = false
    w1000_saved = e::JsonFileStore.deep_copy(e::Materials.edge('ABS_W1000_10'))
    w_sheet = e::Materials.sheet('W1000_DTDL_18')
    w_schema2 = e::Materials.catalog_schema >= e::Materials::SCHEMA_GROUPS &&
                w_sheet && !w_sheet['group_id'].to_s.strip.empty?
    w_pick_l1 = lambda do
      w_schema2 ? e::Materials.abs_for_sheet(w_sheet, :jednotka, 18.0).first
                : e::Materials.abs_for_decor('W1000 ST9 Biela', 1.0, 18.0)
    end
    if w_sheet && w_pick_l1.call.nil?
      seed = { 'abs_id' => 'ABS_W1000_10', 'decor' => w_sheet['decor'].to_s,
               'thickness' => 1.0, 'price_per_bm' => 0.60, 'color' => [246, 246, 244] }
      if w_schema2
        seed['group_id'] = w_sheet['group_id']
        st = w_sheet['structure'].to_s.strip
        seed['structure'] = st unless st.empty?
      end
      w1000_seeded = e::Materials.upsert_edge(seed)
      info('sync-board: ABS_W1000_10 nemala pouzitelnu jednotku — docasne doseedovana') if w1000_seeded
    end
    exp_l1 = w_pick_l1.call
    exp_w1 = if w_schema2
               e::Materials.abs_for_sheet(w_sheet, :dvojka, 18.0).first
             else
               e::Materials.abs_for_decor('W1000 ST9 Biela', 2.0, 18.0)
             end
    e::Panel.handle_set_board_material({ 'board_id' => bid, 'material_id' => 'W1000_DTDL_18' }.to_json)
    mcfg = e::Store.config(binst) || {}
    mecfg = mcfg['edges'] || {}
    ok("sync-board: zmena materialu K009->W1000 previedla ABS dekor (L1 -> #{exp_l1 || 'nil'}, W1 2mm -> #{exp_w1 || 'nil'})",
       mcfg['material_id'] == 'W1000_DTDL_18' && !exp_l1.nil? &&
       mecfg['L1'] == exp_l1 && mecfg['W1'] == exp_w1)
    ok('sync-board: material bez dekoroveho smeru zhodil grain na none',
       mcfg['grain_direction'] == 'none')
    model.selection.clear

    # 11) Davka 2 (D-05): sprava katalogu end-to-end — novy 38mm material cez
    #     dialogovy handler, doska ho prevezme (hrubka z katalogu), delete guardy.
    begin
      e::MaterialsDialog.handle_save_sheet({ 'decor' => 'Runner Pracovna', 'type' => 'DTDL',
                                             'thickness' => '38', 'grain' => 'length',
                                             'price_per_m2' => '20', 'color' => [50, 60, 70] }.to_json, create: true)
      wt = e::Materials.sheet('RUNNER_PRACOVNA_DTDL_38')
      ok('katalog: novy 38mm material vytvoreny (server-generovane ID)', !wt.nil? && (wt['thickness'].to_f - 38.0).abs < 0.01)
      e::BoardBuilder.rebuild(model, binst, { 'material_id' => 'RUNNER_PRACOVNA_DTDL_38' })
      kcfg = e::Store.config(binst) || {}
      kb = binst.definition.bounds
      ok("katalog: doska prevzala novu hrubku 38 (cfg #{kcfg['thickness']}, geo #{mm(kb.depth).round(1)})",
         (kcfg['thickness'].to_f - 38.0).abs < 0.01 && (mm(kb.depth) - 38.0).abs <= TOL)
      e::MaterialsDialog.handle_delete_sheet({ 'material_id' => 'RUNNER_PRACOVNA_DTDL_38' }.to_json)
      ok('katalog: delete POUZITEHO materialu odmietnuty (doska ho drzi)',
         !e::Materials.sheet('RUNNER_PRACOVNA_DTDL_38').nil?)
      e::MaterialsDialog.handle_delete_sheet({ 'material_id' => 'K009_PW_DTDL_18' }.to_json)
      ok('katalog: chranena predvolba sa neda zmazat',
         !e::Materials.sheet('K009_PW_DTDL_18').nil?)
      # Codex GH #39: hrubka ABS pri edite nemenna (ID _10 nesmie zacat znamenat 2mm)
      e::MaterialsDialog.handle_save_edge({ 'abs_id' => 'ABS_K009_10', 'decor' => 'K009 PW',
                                            'thickness' => '2.0', 'price_per_bm' => '1' }.to_json, create: false)
      abs10 = e::Materials.edge('ABS_K009_10')
      ok('katalog: zmena hrubky existujucej ABS odmietnuta (ostava 1.0)',
         !abs10.nil? && (abs10['thickness'].to_f - 1.0).abs < 0.01)
    ensure
      # uprac: dosku vrat na seed material a testovaci zaznam zmaz (uz nepouzity)
      e::BoardBuilder.rebuild(model, binst, { 'material_id' => 'K009_PW_DTDL_18' }) rescue nil
      e::Materials.delete_sheet('RUNNER_PRACOVNA_DTDL_38')
    end
    ok('katalog: nepouzity testovaci material zmazany (cleanup)',
       e::Materials.sheet('RUNNER_PRACOVNA_DTDL_38').nil?)

    # 12) V0.5 A: BOM zo snapshotov — collect nad realnym modelom (2 korpusy z
    #     dedup bodu 8 + 2 dosky z bodu 9). BEZI AZ NA KONCI run_sync — meni
    #     selection, board testy vyssie potrebuju svoj vyber (prva SU lekcia B).
    col = e::Bom.collect(model)
    bom = e::Bom.compute(col)
    ok("sync-bom: collect vidi 2 korpusy a 2 dosky (records #{col[:records].length})",
       col[:cabinets] == 2 && col[:boards] == 2 && col[:records].length > 10)
    side = col[:records].find { |r| r['part_key'] == 'cabinet/side:left' }
    ok('sync-bom: snapshot dielca nesie material a realnu hrubku',
       !side.nil? && side['material_id'].to_s != '' && (side['thickness'] - 18.0).abs < 0.01)
    legs = bom[:hardware].find { |g| g['generic_type'] == 'leg' }
    ok("sync-bom: nohy agregovane z config.hardware[] oboch korpusov (#{legs ? legs['quantity'] : 0} ks)",
       !legs.nil? && legs['quantity'] == 8 && legs['breakdown'].length == 2)
    ok('sync-bom: m2 supis nenulovy a summary sedi s poctami',
       bom[:summary]['m2_total'] > 0.5 && bom[:summary]['cabinets'] == 2 &&
       bom[:summary]['boards'] == 2 && bom[:summary]['rows'] <= bom[:summary]['records'])
    # Codex GH #47 P2: odpojeny vyrobny dielec priamo v model.entities sa zbiera tiez
    src_part = inst.definition.entities.grep(Sketchup::ComponentInstance)
                   .find { |i| e::Store.get(i, 'part_key') == 'cabinet/side:left' }
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST detached part', true)
      det = model.entities.add_instance(src_part.definition,
                                        Geom::Transformation.translation(e::Units.vector(1600, 0, 0)))
      %w[std kind id part_id cabinet_id role name part_key part_key_schema
         manufactured production_class config].each do |k|
        v = e::Store.get(src_part, k)
        det.set_attribute('NOXUN', k, v) unless v.nil?
      end
      model.commit_operation
      col2 = e::Bom.collect(model)
      ok("sync-bom: odpojeny dielec v modeli sa zbiera (#{col2[:records].length} records)",
         col2[:records].length == col[:records].length + 1)
      model.start_operation('SU-TEST detached cleanup', true)
      det.erase!
      model.commit_operation
    end

    # 13) V0.5 B: klik-select z okna Vyroba — do_select cez persistent_id,
    #     ziadna mutacia modelu, stale generacia sa odmietne.
    col3 = e::Bom.collect(model)
    bom3 = e::Bom.compute(col3)
    row = bom3[:rows].find { |r| r['refs'].length >= 2 }
    ok('sync-vyroba: riadok kusovnika nesie refs s pid',
       !row.nil? && row['refs'].all? { |r| r['pid'].is_a?(Integer) })
    cfg_before = (e::Store.config(inst) || {})['width']
    e::ProductionDialog.do_select({ 'gen' => 0, 'parts_key' => row['key'] })
    ok("sync-vyroba: select cez KLUC riadku oznacil #{model.selection.size} dielcov (#{row['refs'].length} refs)",
       model.selection.size == row['refs'].length)
    ok('sync-vyroba: select NEzmutoval model (config drzi, ziadny dedup)',
       ((e::Store.config(inst) || {})['width'] == cfg_before))
    e::ProductionDialog.do_select({ 'gen' => -99, 'pids' => row['refs'].map { |r| r['pid'] } })
    ok('sync-vyroba: stale generacia odmietnuta — selection sa nezmenil',
       model.selection.size == row['refs'].length)
    hwrow = bom3[:hardware].find { |g| g['generic_type'] == 'leg' }
    e::ProductionDialog.do_select({ 'gen' => 0, 'hw_key' => hwrow['key'] })
    ok('sync-vyroba: klik na kovanie (hw_key) oznacil oba korpusy',
       model.selection.size == 2 && model.selection.all? { |s| e::Store.kind(s) == 'cabinet' })

    # 14) D-35 bulk ABS (audit FIX 8): olepenie vsetkych 4 hran JEDNYM callbackom
    #     = 1 undo krok; identity guard (zle echo nic nezmeni); nenajdena ABS =
    #     atomicky no-op BEZ undo kroku (mapa 4x nil sa NIKDY nesmie ulozit).
    shelf14 = inst.definition.entities.grep(Sketchup::ComponentInstance)
                  .find { |i| e::Store.get(i, 'role') == 'shelf' }
    rk14 = e::Store.get(shelf14, 'part_key').to_s
    cid14 = e::Store.get(inst, 'cabinet_id').to_s
    e::Panel.select_only(model, shelf14)
    # zle echo cabinet_id -> ticho zahodene, ziadna zmena
    e::Panel.handle_set_part_edges_all({ 'cabinet_id' => 'CAB-999', 'role_key' => rk14 }.to_json)
    ov14 = (e::Store.config(inst) || {})['part_overrides'] || {}
    ok('sync-abs: part bulk so zlym echo cabinet_id nic nezmenil', !ov14.key?(rk14))
    # kluc INEHO dielca nez oznaceneho -> ticho zahodene
    e::Panel.handle_set_part_edges_all({ 'cabinet_id' => cid14, 'role_key' => 'cabinet/side:left' }.to_json)
    ov14b = (e::Store.config(inst) || {})['part_overrides'] || {}
    ok('sync-abs: part bulk s klucom ineho dielca nic nezmenil', !ov14b.key?('cabinet/side:left'))
    # spravne echo: VSETKY 4 hrany jednym callbackom (ABS dekoru materialu dielca)
    e::Panel.handle_set_part_edges_all({ 'cabinet_id' => cid14, 'role_key' => rk14 }.to_json)
    find_part14 = lambda do
      inst.definition.entities.grep(Sketchup::ComponentInstance)
          .find { |i| e::Store.get(i, 'part_key').to_s == rk14 }
    end
    ecfg14 = (e::Store.config(find_part14.call) || {})['edges'] || {}
    ov14c = ((e::Store.config(inst) || {})['part_overrides'] || {})[rk14] || {}
    ok('sync-abs: part bulk olepil vsetky 4 hrany jednym callbackom (ABS_K009_10)',
       %w[L1 L2 W1 W2].all? { |c| ecfg14[c] == 'ABS_K009_10' } &&
       %w[L1 L2 W1 W2].all? { |c| (ov14c['edges'] || {})[c] == 'ABS_K009_10' })
    # JEDNO undo vrati vsetky 4 hrany naraz (bulk = 1 operacia)
    Sketchup.undo
    ecfg14u = (e::Store.config(find_part14.call) || {})['edges'] || {}
    ov14u = (e::Store.config(inst) || {})['part_overrides'] || {}
    ok('sync-abs: 1x undo vratil vsetky 4 hrany naraz (override prec, default L1 drzi)',
       !ov14u.key?(rk14) && ecfg14u['L1'] == 'ABS_K009_10' && ecfg14u['L2'].nil? &&
       ecfg14u['W1'].nil? && ecfg14u['W2'].nil?)

    # board bulk: poradie flush -> bulk (JS flushBoardEditsNow simulovane volanim
    # set_board_fields tesne pred bulkom — bulk musi pracovat nad cerstvym configom)
    e::Panel.select_only(model, binst)
    bid14 = e::Store.get(binst, 'id').to_s
    e::Panel.handle_set_board_fields({ 'board_id' => bid14, 'fields' => { 'width' => 590.0 } }.to_json)
    e::Panel.handle_set_board_edges_all({ 'board_id' => bid14 }.to_json)
    bcfg14 = e::Store.config(binst) || {}
    ok('sync-abs: board bulk po flushi poli — sirka 590 drzi a 4 hrany olepene',
       (bcfg14['width'].to_f - 590.0).abs < 0.01 &&
       %w[L1 L2 W1 W2].all? { |c| (bcfg14['edges'] || {})[c] == 'ABS_K009_10' })
    Sketchup.undo
    bcfg14u = e::Store.config(binst) || {}
    ok('sync-abs: board bulk 1x undo vratil hrany, flush poli bol samostatny krok (sirka 590)',
       (bcfg14u['width'].to_f - 590.0).abs < 0.01 &&
       (bcfg14u['edges'] || {})['L2'].nil?)
    e::Panel.handle_set_board_edges_all({ 'board_id' => 'BRD-999' }.to_json)
    ok('sync-abs: board bulk so zlym echo board_id nic nezmenil',
       ((e::Store.config(binst) || {})['edges'] || {})['L2'].nil?)
    # nenajdena ABS (HDF nema 1.0 mm pasku): atomicky no-op — hrany NEDOTKNUTE
    # (ziadne 4x nil!) a ZIADEN undo krok (marker width 570 sa musi undo-nut prvy)
    e::Panel.handle_set_board_material({ 'board_id' => bid14, 'material_id' => 'HDF_WHITE_3' }.to_json)
    edges_before14 = ((e::Store.config(binst) || {})['edges'] || {}).dup
    e::Panel.handle_set_board_fields({ 'board_id' => bid14, 'fields' => { 'width' => 570.0 } }.to_json)
    e::Panel.handle_set_board_edges_all({ 'board_id' => bid14 }.to_json)
    bcfg14n = e::Store.config(binst) || {}
    ok('sync-abs: bulk bez ABS variantu = atomicky no-op (hrany nedotknute, ziadne 4x nil)',
       (bcfg14n['edges'] || {}) == edges_before14 && (bcfg14n['width'].to_f - 570.0).abs < 0.01)
    Sketchup.undo
    bcfg14z = e::Store.config(binst) || {}
    ok('sync-abs: bulk bez ABS nevytvoril undo krok (1x undo vratil marker 570 -> 590)',
       (bcfg14z['width'].to_f - 590.0).abs < 0.01)

    # 14b) D-41 C2: create_missing_abs (modal "Vytvorit a pokracovat") — server
    #      dovytvori 1,0 mm pasku dekoru a rucne zladene hrany nasleduju novy
    #      dekor (centralny remap). Katalogovy zapis je MIMO model undo — po
    #      undo materialu paska v globalnom katalogu OSTAVA (NOTE 9). Docasny
    #      dekor sa po scenari z katalogu uprace.
    ok41, res41 = e::Materials.add_decor_batch('decor' => 'SU D41 Dekor', 'thicknesses' => '18')
    if ok41
      sid41 = res41['sheets'][0]
      shelf41 = inst.definition.entities.grep(Sketchup::ComponentInstance)
                    .find { |i| e::Store.get(i, 'role') == 'shelf' }
      rk41 = e::Store.get(shelf41, 'part_key').to_s
      cid41 = e::Store.get(inst, 'cabinet_id').to_s
      e::Panel.select_only(model, shelf41)
      # rucna hrana zladena s POVODNYM dekorom (K009) — remap ju musi previest
      e::Panel.handle_set_part_edge({ 'cabinet_id' => cid41, 'role_key' => rk41,
                                      'edge' => 'L1', 'abs_id' => 'ABS_K009_10' }.to_json)
      e::Panel.handle_set_part_material({ 'cabinet_id' => cid41, 'role_key' => rk41,
                                          'material_id' => sid41, 'create_missing_abs' => true }.to_json)
      created41 = e::Materials.abs_for_decor('SU D41 Dekor', 1.0, 18.0)
      part41 = inst.definition.entities.grep(Sketchup::ComponentInstance)
                   .find { |i| e::Store.get(i, 'part_key').to_s == rk41 }
      pcfg41 = e::Store.config(part41) || {}
      ov41 = ((e::Store.config(inst) || {})['part_overrides'] || {})[rk41] || {}
      ok('sync-abs C2: create_missing_abs vytvoril pasku 23/1 noveho dekoru',
         created41 == 'ABS_SU_D41_DEKOR_23X10')
      ok('sync-abs C2: material nastaveny a rucna hrana L1 prevedena na novu pasku',
         pcfg41['material_id'] == sid41 && (ov41['edges'] || {})['L1'] == created41 &&
         (pcfg41['edges'] || {})['L1'] == created41)
      Sketchup.undo
      ov41u = ((e::Store.config(inst) || {})['part_overrides'] || {})[rk41] || {}
      ok('sync-abs C2: 1x undo vratil material aj hranu, paska v katalogu OSTAVA (NOTE 9)',
         (ov41u['edges'] || {})['L1'] == 'ABS_K009_10' && !e::Materials.edge(created41).nil?)
      # upratanie: override hrany prec + docasne katalogove zaznamy prec
      e::Panel.handle_set_part_edge({ 'cabinet_id' => cid41, 'role_key' => rk41,
                                      'edge' => 'L1', 'abs_id' => '__inherit__' }.to_json)
      e::Materials.delete_edge(created41) if created41
      e::Materials.delete_sheet(sid41)
      ok('sync-abs C2: cleanup docasneho dekoru (katalog bez SU D41 zaznamov)',
         e::Materials.sheet(sid41).nil? && e::Materials.abs_for_decor('SU D41 Dekor', 1.0).nil?)
    else
      ok("sync-abs C2: seed docasneho dekoru zlyhal (#{res41.inspect})", false)
    end

    # 15) V0.5 D: KONTROLNY SEMAFOR — raw hardware_overrides (nalez 2), Validation
    #     nad CERSTVYM zberom, klik-select semaforovej polozky cez STABILNY kluc
    #     (prezije rebuild — nalez 4), stale generacia. NESPUSTA sa tu (spusti hlavny
    #     agent pri review — konflikt SketchUp instancii); scenar je pripraveny.
    cid15 = e::Store.get(inst, 'cabinet_id').to_s
    smap15 = e::Materials.sheets.each_with_object({}) { |s, o| o[s['material_id']] = s }
    e::Panel.select_only(model, inst)
    colH = e::Bom.collect(model)
    legH = colH[:hardware].find { |h| h['owner_id'] == cid15 && h['generic_type'] == 'leg' }
    if legH
      e::Panel.handle_set_hardware_override({ 'owner_part_key' => legH['owner_part_key'],
                                              'generic_type' => 'leg', 'rule_id' => legH['rule_id'],
                                              'disabled' => true }.to_json)
      col15 = e::Bom.collect(model)
      # raw hardware_overrides nesie disabled zaznam; v config.hardware[] uz NIE je (nalez 2)
      ok('sync-semafor: raw hardware_overrides zbiera disabled zaznam (owner_id/owner_pid)',
         col15[:hardware_overrides].any? { |o| o['owner_id'] == cid15 && o['disabled'] == true } &&
         col15[:hardware].none? { |h| h['owner_id'] == cid15 && h['generic_type'] == 'leg' })
      val15 = e::Validation.run(col15, sheets: smap15)
      hwitem = val15['items'].find { |i| i['category'] == 'hardware' && i['owner_id'] == cid15 }
      ok('sync-semafor: vypnute kovanie = ORANGE polozka so stabilnym klucom',
         !hwitem.nil? && hwitem['severity'] == 'orange' && !hwitem['stable_key'].to_s.empty?)
      # klik-select semaforovej polozky (bez part_key = korpus ako celok) oznaci OWNER korpus
      e::ProductionDialog.do_select({ 'gen' => 0, 'problem_key' => hwitem['stable_key'] })
      ok('sync-semafor: klik na semafor polozku oznacil owner korpus',
         model.selection.size == 1 && e::Store.get(model.selection.first, 'cabinet_id').to_s == cid15)
      # STABILNY kluc prezije rebuild (pending-edit flush simulovany zmenou sirky):
      # kovanie stale disabled -> ten isty stable_key znova vyberie korpus (nalez 4)
      base15 = e::CabinetBuilder.config_to_params(e::Store.config(inst))
      w15 = (e::Store.config(inst) || {})['width'].to_f
      e::CabinetBuilder.rebuild(model, inst, base15.merge('width' => w15 + 20.0))
      val15b = e::Validation.run(e::Bom.collect(model), sheets: smap15)
      hwitem2 = val15b['items'].find { |i| i['category'] == 'hardware' && i['owner_id'] == cid15 }
      ok('sync-semafor: semafor polozka prezila rebuild (stabilny kluc nezmeneny)',
         !hwitem2.nil? && hwitem2['stable_key'] == hwitem['stable_key'])
      model.selection.clear
      e::ProductionDialog.do_select({ 'gen' => 0, 'problem_key' => hwitem2['stable_key'] })
      ok('sync-semafor: klik po rebuilde znova oznacil korpus (dohladanie podla identity, nie PID)',
         model.selection.size == 1 && e::Store.get(model.selection.first, 'cabinet_id').to_s == cid15)
      # stale generacia (iny model / stary DOM) sa odmietne — selection nezmeneny
      sz15 = model.selection.size
      e::ProductionDialog.do_select({ 'gen' => -99, 'problem_key' => hwitem2['stable_key'] })
      ok('sync-semafor: stale generacia odmietnuta — selection nezmeneny', model.selection.size == sz15)
      # reset kovania: ORANGE polozka zmizne z CERSTVEHO zberu (kanon je aktualny stav)
      e::Panel.select_only(model, inst)
      e::Panel.handle_set_hardware_override({ 'owner_part_key' => legH['owner_part_key'],
                                              'generic_type' => 'leg', 'rule_id' => legH['rule_id'] }.to_json)
      val15c = e::Validation.run(e::Bom.collect(model), sheets: smap15)
      ok('sync-semafor: reset kovania -> ORANGE polozka zmizla',
         val15c['items'].none? { |i| i['category'] == 'hardware' && i['owner_id'] == cid15 })
    else
      info('sync-semafor: korpus nema nohy (leg) — semafor kovania scenar preskoceny')
    end

    # 2A-3 rider (Codex GH #90 P1): navrat PRESNEHO stavu katalogu — existujuci
    # zaznam pod tymto ID sa obnovi (rename dekoru ID drzi!), inak sa docasny
    # seed zmaze. Board hrany na pasku po HDF remape uz neukazuju.
    if w1000_seeded
      w1000_saved ? e::Materials.upsert_edge(w1000_saved) : e::Materials.delete_edge('ABS_W1000_10')
    end
    cleanup(model)
    ok('sync: cleanup (0 korpusov, 0 dosiek)', cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: sync vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    begin
      if defined?(w1000_seeded) && w1000_seeded
        if defined?(w1000_saved) && w1000_saved
          e::Materials.upsert_edge(w1000_saved)
        else
          e::Materials.delete_edge('ABS_W1000_10')
        end
      end
    rescue StandardError
      nil
    end
    cleanup(model)
  end

  # --- SYNC-BACK: D-37 celkova hlbka + D-31 bez chrbta + D-38 pevny chrbat ---
  # (davka Chrbat 20.7. — hlbka cfg = CELKOVA vratane chrbta; bez migracie:
  # rebuild starej geometrie ju VEDOME prepocita — rozhodnutie Michala)

  def find_part(inst, key)
    inst.definition.entities.grep(Sketchup::ComponentInstance)
        .find { |i| e::Store.kind(i) == 'part' && e::Store.get(i, 'part_key') == key }
  end

  # bounds instancie dielca su v suradniciach definicie KORPUSU (parent space)
  def part_y_end(pi)
    mm(pi.bounds.max.y)
  end

  def part_depth(pi)
    mm(pi.bounds.max.y) - mm(pi.bounds.min.y)
  end

  # H3/D-80: zvisle rozmery dielca v ramci definicie korpusu (Z = vyska).
  def part_z0(pi)
    mm(pi.bounds.min.z)
  end

  def part_z1(pi)
    mm(pi.bounds.max.z)
  end

  def part_height(pi)
    part_z1(pi) - part_z0(pi)
  end

  def carcass_max_y(inst)
    parts = inst.definition.entities.grep(Sketchup::ComponentInstance)
                .select { |i| e::Store.kind(i) == 'part' }
    parts.map { |i| part_y_end(i) }.max
  end

  def run_sync_back(model)
    params = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0 }

    # 1) D-37: novy overlay korpus (bt 3) — telo 507, zadna hrana chrbta PRESNE 510
    inst = e::CabinetBuilder.build(model, params)
    return ok('back: vlozenie korpusu', false) unless inst
    side = find_part(inst, 'cabinet/side:left')
    back = find_part(inst, 'cabinet/back')
    ok('back D-37: bok ma konstrukcnu hlbku 507', side && (part_depth(side) - 507.0).abs < TOL)
    ok('back D-37: chrbat konci PRESNE na celkovej hlbke 510',
       back && (part_y_end(back) - 510.0).abs < TOL)
    ok('back D-37: max Y vsetkych dielcov = 510 (nic netrci za celkovu hlbku)',
       (carcass_max_y(inst) - 510.0).abs < TOL)

    # 2) D-37 bez migracie: STARA overlay geometria = telo 510 + chrbat [510,513]
    #    so stored depth 510 (nasimulovane buildom 513 + prepisom configu).
    old = e::CabinetBuilder.build(model, params.merge('depth' => 513.0))
    model.start_operation('SU-TEST sim old', true)
    old.set_attribute('NOXUN', 'config',
                      JSON.generate((e::Store.config(old) || {}).merge('depth' => 510.0)))
    model.commit_operation
    ok('back D-37: simulacia starej geometrie (chrbat do 513, stored 510)',
       (carcass_max_y(old) - 513.0).abs < TOL)
    e::CabinetBuilder.rebuild(model, old,
                              e::CabinetBuilder.config_to_params(e::Store.config(old)))
    old_side = find_part(old, 'cabinet/side:left')
    ok('back D-37: rebuild starej geometrie = nova pravda (telo 507, max Y 510)',
       old_side && (part_depth(old_side) - 507.0).abs < TOL &&
       (carcass_max_y(old) - 510.0).abs < TOL)
    Sketchup.undo
    ok('back D-37: 1x undo vratil staru geometriu (chrbat do 513)',
       old.valid? && (carcass_max_y(old) - 513.0).abs < TOL)

    # 3) D-31 prechody na TEJ ISTEJ instancii: overlay -> none -> groove
    base = e::CabinetBuilder.config_to_params(e::Store.config(inst))
    e::CabinetBuilder.rebuild(model, inst, base.merge('back_mode' => 'none'))
    ok('back D-31: none — BACK dielec neexistuje', find_part(inst, 'cabinet/back').nil?)
    n_side = find_part(inst, 'cabinet/side:left')
    ok('back D-31: none — bok na PLNU hlbku 510', n_side && (part_depth(n_side) - 510.0).abs < TOL)
    cid = e::Store.get(inst, 'cabinet_id').to_s
    bom = e::Bom.collect(model)
    ok('back D-31: BOM nema chrbat korpusu bez chrbta',
       bom[:records].none? { |r| r['owner_id'] == cid && r['part_key'] == 'cabinet/back' })
    e::CabinetBuilder.rebuild(model, inst, base.merge('back_mode' => 'groove'))
    g_back = find_part(inst, 'cabinet/back')
    ok('back D-31: navrat none -> groove obnovil chrbat (hrubka zachovana)',
       g_back && ((e::Store.config(inst) || {})['back_thickness'].to_f - 3.0).abs < 0.01)

    # 4) D-38: preflight pevneho chrbta — auto-pick materialu hrubky (zavisi od katalogu)
    m18 = defined?(e::Materials) ? e::Materials.sheets.find { |s| (s['thickness'].to_f - 18.0).abs < 0.01 } : nil
    if m18
      pf_params = e::CabinetBuilder.config_to_params(e::Store.config(inst))
                                   .merge('back_mode' => 'overlay', 'back_thickness' => 18.0)
      pf = e::Panel.send(:back_preflight, pf_params, model)
      ok('back D-38: preflight vybral 18 mm material (note + back_material_id)',
         pf && pf[:error].nil? && pf[:note] && !pf_params['back_material_id'].to_s.empty?)
      e::CabinetBuilder.rebuild(model, inst, pf_params)
      s18 = find_part(inst, 'cabinet/side:left')
      ok('back D-38: rebuild s pevnym 18 PRESIEL — telo 492, chrbat konci na 510',
         s18 && (part_depth(s18) - 492.0).abs < TOL &&
         (part_y_end(find_part(inst, 'cabinet/back')) - 510.0).abs < TOL)
    else
      info('back D-38: katalog nema 18 mm material — preflight scenar preskoceny')
    end

    cleanup(model)
    ok('back: cleanup (0 korpusov)', cabinets(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: sync-back vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    cleanup(model)
  end

  # --- SYNC-VYSTUHY: H3/D-80 vnutro konci pod hornymi vystuhami (davka Geometria).
  # Realny pripad z hlasenia: varna skrinka 860 / sokel 150 / vystuhy naplocho
  # znizene o 30 mm pod varnu dosku. Overuje sa MODEL, nie len plan.
  def run_sync_rails(model)
    base = { 'type' => 'lower', 'width' => 600.0, 'height' => 860.0, 'depth' => 510.0,
             'floor_height' => 150.0, 'back_mode' => 'inset',
             'top_mode' => 'two_rails', 'rails_orientation' => 'flat',
             'rail_depth' => 100.0, 'rails_top_offset' => 30.0,
             'zone_tree' => { 'id' => 'Z1', 'shelves' => 2, 'children' => [] } }
    inst = e::CabinetBuilder.build(model, base)
    return ok('rails: vlozenie korpusu', false) unless inst

    # 1) flat + odsadenie 30: spodna hrana vystuh (812) = strop vnutra; svetla
    #    vyska 644 (pred opravou hlasil engine 674 a police liezli do vystuh).
    rf = find_part(inst, 'cabinet/rail:front')
    ok('rails D-80: flat vystuha stoji na 812 (860 - 30 - 18)',
       rf && (part_z0(rf) - 812.0).abs < TOL)
    ok('rails D-80: svetla vyska v configu = 644 (pred opravou 674)',
       ((e::Store.config(inst) || {})['available_height'].to_f - 644.0).abs < 0.01)
    top_shelf = find_part(inst, 'zone:Z1/shelf:2')
    ok('rails D-80: horna polica ostala POD vystuhami',
       top_shelf && part_z1(top_shelf) <= 812.0 + TOL)
    bk = find_part(inst, 'cabinet/back')
    ok('rails D-80: inset chrbat skrateny presne o odsadenie (644)',
       bk && (part_height(bk) - 644.0).abs < TOL)

    # 2) upright bez odsadenia: vnutro konci pod CELOU vystuhou (760), chrbat sa
    #    o jej vysku NEskracuje — bezi za vystuhami (674).
    up = e::CabinetBuilder.config_to_params(e::Store.config(inst))
                          .merge('rails_orientation' => 'upright', 'rails_top_offset' => 0.0)
    e::CabinetBuilder.rebuild(model, inst, up)
    rfu = find_part(inst, 'cabinet/rail:front')
    ok('rails D-80: upright vystuha vysoka 100 stoji na 760',
       rfu && (part_z0(rfu) - 760.0).abs < TOL && (part_height(rfu) - 100.0).abs < TOL)
    ok('rails D-80: upright svetla vyska = 592 (860 - 100 - 168)',
       ((e::Store.config(inst) || {})['available_height'].to_f - 592.0).abs < 0.01)
    ok('rails D-80: chrbat pri upright NIE JE skrateny o vysku vystuhy (674)',
       (part_height(find_part(inst, 'cabinet/back')) - 674.0).abs < TOL)

    # 3) extremne odsadenie + 4 police: odsadenie sa OREZE (warning) a clenenie sa
    #    do zmenseneho vnutra nezmesti -> rebuild sa odmietne zrozumitelnou hlaskou
    #    a model ostane presne taky, aky bol (abort_safely).
    bad = e::CabinetBuilder.config_to_params(e::Store.config(inst))
                           .merge('rails_orientation' => 'upright', 'rail_depth' => 400.0,
                                  'rails_top_offset' => 500.0,
                                  'zone_tree' => { 'id' => 'Z1', 'shelves' => 4, 'children' => [] })
    msg = nil
    begin
      e::CabinetBuilder.rebuild(model, inst, bad)
    rescue StandardError => ex
      msg = ex.message
    end
    ok('rails D-80: prilis male vnutro odmietne rebuild zrozumitelnou hlaskou',
       msg.to_s.include?('Vnútorná výška sa znížila'))
    ok('rails D-80: odmietnuty rebuild nechal korpus nedotknuty (upright vystuha na 760)',
       inst.valid? && (part_z0(find_part(inst, 'cabinet/rail:front')) - 760.0).abs < TOL)

    # 4) to iste odsadenie BEZ policia prejde — orezanie sa hlasi warningom.
    okp = bad.merge('zone_tree' => { 'id' => 'Z1', 'shelves' => 0, 'children' => [] })
    e::CabinetBuilder.rebuild(model, inst, okp)
    warns = ((e::Store.config(inst) || {})['warnings'] || [])
    ok('rails D-80: orezanie odsadenia sa hlasi warningom rail_offset_clamped',
       warns.any? { |x| x.is_a?(Hash) && x['code'] == 'rail_offset_clamped' })
    ok('rails D-80: po oreze drzi vnutro rezervu 20 mm',
       ((e::Store.config(inst) || {})['available_height'].to_f - 20.0).abs < 0.01)

    cleanup(model)
    ok('rails: cleanup (0 korpusov)', cabinets(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: sync-rails vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    cleanup(model)
  end

  # --- Recorder Panel.js (audit F9): zatvoreny panel je no-op — dokaz volania
  # NX.clearSelected/NX.setStatus sa zbiera docasnym obalenim Panel.js. Vzdy
  # parovat install/remove; remove je idempotentny (bezpecny aj po FAIL ceste).

  def install_js_recorder(rec)
    e::Panel.singleton_class.class_eval do
      alias_method :nx_js_orig_vkl, :js
      define_method(:js) { |script| rec << script.to_s; nil }
    end
  end

  def remove_js_recorder
    sc = e::Panel.singleton_class
    return unless sc.method_defined?(:nx_js_orig_vkl)
    sc.class_eval do
      alias_method :js, :nx_js_orig_vkl
      remove_method :nx_js_orig_vkl
    end
  end

  # --- SYNC-VKLADANIE: D-32/D-33 sablona+materialy, D-39 zamky/F8 konflikty,
  # B3 presna kopia, N11 imutabilita sablon (davka Vkladanie) ------------------

  def run_insert_batch(model)
    # 0) D-39: sanitizacia zamkov v Ruby pamati (whitelist poli + cisla)
    e::Panel.handle_set_insert_locks({ 'locks' => { 'height' => 950.0, 'bogus' => 5,
                                                    'width' => 'abc' } }.to_json)
    ok('vklad D-39: sanitizacia zamkov (whitelist + cisla)',
       e::Panel.insert_locks == { 'height' => 950.0 })

    # 1) D-33 + N11: seed sablony DOKONCENY pred snapshotom; insert zo sablony
    #    so zamknutou vyskou (payload uz nesie lock hodnotu — JS krok F7/2)
    tpl_cfg = { 'type' => 'lower', 'width' => 450.0, 'height' => 720.0, 'depth' => 510.0,
                'thickness' => 18.0, 'floor_height' => 100.0,
                'bottom_mode' => 'under_sides', 'top_mode' => 'full', 'back_mode' => 'overlay',
                'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 40.0,
                'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
                'material_id' => 'K009_PW_DTDL_18',
                'zone_tree' => { 'id' => 'Z1', 'shelves' => 2, 'children' => [] },
                'fronts' => { 'items' => [] } }
    # GH P2: NIKDY nesiahat na pouzivatelske sablony — exoticky nazov, ktory
    # pouzivatel nema; ak by predsa existoval, scenar sa preskoci (nic nemazeme).
    tpl_name = '__SU_TEST_VKLAD__'
    if e::TemplateStore.find('cabinet', tpl_name)
      info("vklad: sablona #{tpl_name} uz existuje — sablonovy scenar preskoceny (chranime pouzivatelske data)")
      tpl_snapshot = nil
    else
      e::TemplateStore.upsert('cabinet', tpl_name, tpl_cfg)
      tpl_snapshot = File.binread(e::TemplateStore.path) # snapshot AZ PO migracii+seede (N11)
    end
    # UI-C1a: payload nesie IDENTITU sablony (kind + nazov) — server ju po vklade
    # opeciatkuje do template_usage.json, ale subor SABLON musi ostat byte-
    # nezmeneny (N11 nizsie kontroluje presne to).
    payload = if tpl_snapshot
                (e::TemplateStore.find('cabinet', tpl_name) || {})['config']
                  .merge('height' => 950.0,
                         'template_kind' => 'cabinet', 'template_name' => tpl_name)
              end
    if payload
      e::Panel.handle_insert(payload.to_json)
      inst = model.selection.to_a.find { |i| e::Store.kind(i) == 'cabinet' }
      cfg = inst ? (e::Store.config(inst) || {}) : {}
      ok("vklad D-39: zamknuta vyska prebila sablonu (950, sirka zo sablony #{cfg['width']})",
         inst && (cfg['height'].to_f - 950.0).abs < 0.01 && (cfg['width'].to_f - 450.0).abs < 0.01)
      ok('vklad F6: material sablony zapisany do configu korpusu',
         cfg['material_id'] == 'K009_PW_DTDL_18')
      ok('vklad D-33: zony zo sablony (2 police v koreni)',
         ((cfg['zone_tree'] || {})['shelves']).to_i == 2)
    end

    if tpl_snapshot
      # modify korpusu po vklade — sablona sa NIKDY nemeni (N11)
      e::CabinetBuilder.rebuild(model, inst,
                                e::CabinetBuilder.config_to_params(cfg).merge('width' => 650.0)) if inst
      # UI-C1a: peciatka pouzitia ide do INEHO suboru (template_usage.json),
      # takze byte-identita suboru sablon plati aj po vklade ZO SABLONY.
      ok('vklad N11: subor sablon byte-nezmeneny po inserte + edite korpusu',
         File.binread(e::TemplateStore.path) == tpl_snapshot)
      ok('vklad UI-C1a: pouzitie sablony opeciatkovane vo vlastnom subore',
         !e::TemplateUsage.seq_for('cabinet', tpl_name).nil?)
      e::TemplateStore.delete('cabinet', tpl_name) # cleanup VLASTNEJ testovacej sablony
    end

    # 2) F8 konflikt A: zamknuta vyska + vysoke pevne cela -> vklad ODMIETNUTY
    #    backend hlaskou; status vymenuje aktivne zamky (recorder na Panel.js)
    e::Panel.handle_set_insert_locks({ 'locks' => { 'height' => 300.0 } }.to_json)
    before = cabinets(model).length
    rec = []
    install_js_recorder(rec)
    begin
      e::Panel.handle_insert({ 'type' => 'lower', 'width' => 600.0, 'height' => 300.0,
                               'depth' => 510.0,
                               'fronts' => { 'items' => [
                                 { 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed', 'height' => 250.0, 'wings' => '1', 'locked' => true },
                                 { 'id' => 'F2', 'type' => 'door', 'mode' => 'fixed', 'height' => 250.0, 'wings' => '1', 'locked' => true }
                               ] } }.to_json)
    ensure
      remove_js_recorder
    end
    ok('vklad F8: zamknuta vyska x pevne cela — vklad odmietnuty (nic sa nevlozilo)',
       cabinets(model).length == before)
    ok('vklad F8: status pomenoval aktivne zamky (vyska)',
       rec.any? { |s| s.include?('NX.setStatus') && s.include?('aktívne zámky') && s.include?('výška') })

    # 3) F8 konflikt B: zamknuta hrubka + material inej hrubky -> odmietnute
    if e::Materials.sheet('HDF_WHITE_3')
      e::Panel.handle_set_insert_locks({ 'locks' => { 'thickness' => 18.0 } }.to_json)
      before2 = cabinets(model).length
      rec2 = []
      install_js_recorder(rec2)
      begin
        e::Panel.handle_insert({ 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                                 'depth' => 510.0, 'thickness' => 18.0,
                                 'material_id' => 'HDF_WHITE_3' }.to_json)
      ensure
        remove_js_recorder
      end
      ok('vklad F8: zamknuta hrubka x material 3 mm — vklad odmietnuty hrubkovym guardom',
         cabinets(model).length == before2)
      ok('vklad F8: hlaska nesie hrubkovy konflikt + zamky',
         rec2.any? { |s| s.include?('NX.setStatus') && s.include?('mm') && s.include?('aktívne zámky') })
    else
      info('vklad F8: katalog nema HDF_WHITE_3 — hrubkovy konflikt preskoceny')
    end
    e::Panel.handle_set_insert_locks({ 'locks' => {} }.to_json) # zamky uprace

    # 4) B3 presna kopia: zdroj s materialmi + part_override + hardware_override
    #    + cela + zony + nazov -> insert_copy -> config_to_params IDENTICKE
    src_params = { 'type' => 'lower', 'width' => 640.0, 'height' => 720.0, 'depth' => 510.0,
                   'name' => 'Kopia zdroj',
                   'material_id' => 'K009_PW_DTDL_18', 'front_material_id' => 'K009_PW_DTDL_18',
                   'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
                   'zone_tree' => { 'id' => 'Z1', 'shelves' => 2, 'children' => [] },
                   'part_overrides' => { 'cabinet/side:left' => { 'material_id' => 'K009_PW_DTDL_18',
                                                                 'edges' => { 'L1' => 'ABS_K009_10' } } } }
    src = e::CabinetBuilder.build(model, src_params)
    leg = ((e::Store.config(src) || {})['hardware'] || []).find { |h| h['generic_type'] == 'leg' }
    if leg
      e::CabinetBuilder.rebuild(model, src,
                                e::CabinetBuilder.config_to_params(e::Store.config(src)).merge(
                                  'hardware_overrides' => [{ 'owner_part_key' => nil, 'generic_type' => 'leg',
                                                             'rule_id' => leg['rule_id'], 'quantity' => 6 }]
                                ))
    else
      info('kopia: plan nema nohy — hardware_override cast preskocena')
    end
    src_cid = e::Store.get(src, 'cabinet_id')
    e::Panel.handle_insert_copy({ 'cabinet_id' => src_cid }.to_json)
    copy = model.selection.to_a.find { |i| e::Store.kind(i) == 'cabinet' }
    ok('kopia B3: kopia vlozena a oznacena s NOVYM CAB id',
       copy && copy != src && e::Store.get(copy, 'cabinet_id') != src_cid)
    if copy
      pa = e::CabinetBuilder.config_to_params(e::Store.config(src) || {})
      pb = e::CabinetBuilder.config_to_params(e::Store.config(copy) || {})
      ok('kopia B3: config_to_params IDENTICKE (materialy, part_overrides, hardware_overrides, cela, zony, nazov)',
         pa == pb)
      leg_copy = ((e::Store.config(copy) || {})['hardware'] || []).find { |h| h['generic_type'] == 'leg' }
      ok('kopia B3: rucny pocet noh 6 preneseny (config.hardware zo snapshotu kopie)',
         leg.nil? || (leg_copy && leg_copy['quantity'] == 6))
      ok('kopia B3: ABS override boku prezil kopiu',
         ((pb['part_overrides'] || {}).dig('cabinet/side:left', 'edges') || {})['L1'] == 'ABS_K009_10')
    end
    e::Panel.handle_insert_copy({ 'cabinet_id' => 'CAB-999' }.to_json)
    ok('kopia B3: neexistujuce id = ziadna nova skrinka',
       cabinets(model).length == (copy ? before + 2 : before + 1))

    cleanup(model)
    ok('vklad: cleanup (0 korpusov)', cabinets(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: sync-vkladanie vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    remove_js_recorder
    cleanup(model)
  end

  # --- SYNC-D45: hrubka <-> material tela (deadlock 18,6 mm) -----------------
  # Bloker z testovania: katalogovy material 18,6 mm sa nedal pouzit. Tu sa overuju
  # VSETKY tri cesty von + odmietnutia. Katalog: docasny testovaci dekor (18 + 18,6),
  # ktory sa na konci ZMAZE; ak by uz existoval, sekcia sa preskoci (pouzivatelske
  # data sa nikdy nemazu). Projektova predvolba modelu sa odklada a vracia.

  D45_DECOR = 'SU TEST D45'

  def d45_sheets
    [e::Materials.sheets.find { |s| s['decor'] == D45_DECOR && (s['thickness'].to_f - 18.0).abs < 0.01 },
     e::Materials.sheets.find { |s| s['decor'] == D45_DECOR && (s['thickness'].to_f - 18.6).abs < 0.01 }]
  end

  # X rozmer dielca (hrubka boku) v suradniciach definicie korpusu
  def part_width_x(pi)
    mm(pi.bounds.max.x) - mm(pi.bounds.min.x)
  end

  def run_d45(model)
    if e::Materials.sheets.any? { |s| s['decor'] == D45_DECOR }
      return info("D-45: dekor #{D45_DECOR} uz v katalogu existuje — sekcia preskocena (chranime pouzivatelske data)")
    end
    seeded, res = e::Materials.add_decor_batch(
      'decor' => D45_DECOR, 'manufacturer' => 'SU TEST', 'type' => 'DTDL', 'thicknesses' => '18, 18.6'
    )
    return info("D-45: seed katalogu zlyhal (#{res.inspect}) — sekcia preskocena") unless seeded
    m18, m186 = d45_sheets
    unless m18 && m186
      d45_cleanup_catalog(res)
      return info('D-45: seed nema oba varianty — sekcia preskocena')
    end
    id18 = m18['material_id']
    id186 = m186['material_id']
    saved_default = e::Materials.project_defaults(model)['default_material_id']

    begin
      # (a) MATERIAL -> HRUBKA: zmena materialu tela na 18,6 prevezme hrubku,
      #     geometria sedi a 1x undo vrati VSETKO naraz (jeden rebuild = 1 krok).
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                                              'depth' => 510.0, 'thickness' => 18.0, 'material_id' => id18 })
      cid = e::Store.get(inst, 'cabinet_id')
      model.selection.clear
      model.selection.add(inst)
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_set_cabinet_material({ 'which' => 'body', 'value' => id186,
                                               'cabinet_id' => cid }.to_json)
      ensure
        remove_js_recorder
      end
      cfg = e::Store.config(inst) || {}
      side = find_part(inst, 'cabinet/side:left')
      ok('D-45 (a): zmena materialu tela prevzala hrubku 18,6 do configu',
         (cfg['thickness'].to_f - 18.6).abs < 0.01 && cfg['material_id'] == id186)
      ok('D-45 (a): geometria boku sedi s novou hrubkou (18,6 mm)',
         side && (part_width_x(side) - 18.6).abs < TOL)
      ok('D-45 (a): status oznamil prevzatie hrubky',
         rec.any? { |s| s.include?('NX.setStatus') && s.include?('18,6') })
      Sketchup.undo
      cfg_u = e::Store.config(inst) || {}
      side_u = find_part(inst, 'cabinet/side:left')
      ok('D-45 (a): 1x undo vratil hrubku AJ material naraz',
         inst.valid? && (cfg_u['thickness'].to_f - 18.0).abs < 0.01 && cfg_u['material_id'] == id18 &&
         side_u && (part_width_x(side_u) - 18.0).abs < TOL)

      # (b) HRUBKA -> MATERIAL: zmena hrubky na 18,6 si doberie material
      #     ROVNAKEHO dekoru (deterministicky pick, ziadny nahodny material).
      e::Panel.handle_apply_all({ 'cabinet_id' => cid, 'thickness' => 18.6 }.to_json)
      cfg_b = e::Store.config(inst) || {}
      ok('D-45 (b): zmena hrubky si dobrala material rovnakeho dekoru',
         (cfg_b['thickness'].to_f - 18.6).abs < 0.01 && cfg_b['material_id'] == id186)

      # (b2) per-dielec konflikt (audit F8): polica s VLASTNYM materialom 18,6
      #      musi navrat hrubky na 18 ODMIETNUT (nic sa nemaze, nic sa neprestavi).
      params_sh = e::CabinetBuilder.config_to_params(e::Store.config(inst))
                                   .merge('zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
      shelf_key = e::CabinetBuilder.plan_parts_by_key(params_sh)
                                   .find { |_k, pd| pd[:role].to_s == 'shelf' }&.first
      if shelf_key
        e::CabinetBuilder.rebuild(model, inst,
                                  params_sh.merge('part_overrides' => { shelf_key => { 'material_id' => id186 } }))
        rec2 = []
        install_js_recorder(rec2)
        begin
          e::Panel.handle_apply_all({ 'cabinet_id' => cid, 'thickness' => 18.0 }.to_json)
        ensure
          remove_js_recorder
        end
        cfg_c = e::Store.config(inst) || {}
        ok('D-45 (F8): polica s vlastnym materialom zmenu hrubky odmietla (drzi 18,6)',
           (cfg_c['thickness'].to_f - 18.6).abs < 0.01)
        ok('D-45 (F8): hlaska vymenovala blokujuci dielec',
           rec2.any? { |s| s.include?('NX.setStatus') && s.include?('blokujú dielce') })
      else
        info('D-45 (F8): plan nema policu — scenar per-dielec konfliktu preskoceny')
      end

      # (c) VKLAD: projektova predvolba 18,6 -> nova skrinka sa postavi s 18,6
      e::Panel.handle_set_insert_locks({ 'locks' => {} }.to_json)
      model.start_operation('SU-TEST D45 predvolba', true)
      e::Materials.set_project_default(model, 'default_material_id', id186)
      model.commit_operation
      before = cabinets(model).length
      e::Panel.handle_insert({ 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                               'depth' => 510.0, 'thickness' => 18.0 }.to_json)
      fresh = model.selection.to_a.find { |i| e::Store.kind(i) == 'cabinet' }
      cfg_i = fresh ? (e::Store.config(fresh) || {}) : {}
      ok('D-45 (c): vklad prevzal hrubku 18,6 z projektovej predvolby',
         cabinets(model).length == before + 1 && (cfg_i['thickness'].to_f - 18.6).abs < 0.01)
      ok('D-45 (c): dielce noveho korpusu su realne 18,6 mm',
         fresh && (part_width_x(find_part(fresh, 'cabinet/side:left')) - 18.6).abs < TOL)

      # (d) ZAMOK x SABLONA: zamknuta hrubka 18 + material sablony 18,6 =
      #     ODMIETNUTIE (D-39 kontrakt — konflikt so sablonou sa NIC neupravuje)
      e::Panel.handle_set_insert_locks({ 'locks' => { 'thickness' => 18.0 } }.to_json)
      before2 = cabinets(model).length
      rec3 = []
      install_js_recorder(rec3)
      begin
        e::Panel.handle_insert({ 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                                 'depth' => 510.0, 'thickness' => 18.0, 'material_id' => id186 }.to_json)
      ensure
        remove_js_recorder
      end
      ok('D-45 (d): zamknuta hrubka x material sablony 18,6 — vklad odmietnuty',
         cabinets(model).length == before2)
      ok('D-45 (d): hlaska pomenovala zamok aj material sablony',
         rec3.any? { |s| s.include?('NX.setStatus') && s.include?('Zamknutá hrúbka') && s.include?('aktívne zámky') })
      e::Panel.handle_set_insert_locks({ 'locks' => {} }.to_json)

      # (e) SABLONA na EXISTUJUCU skrinku (audit B4): sablona s materialom 18,6
      #     zladi hrubku ciela; typovy guard aj merge ostavaju nedotknute.
      tpl_name = '__SU_TEST_D45__'
      if e::TemplateStore.find('cabinet', tpl_name)
        info("D-45 (e): sablona #{tpl_name} uz existuje — scenar preskoceny")
      else
        e::TemplateStore.upsert('cabinet', tpl_name,
                                { 'type' => 'lower', 'width' => 500.0, 'height' => 720.0,
                                  'depth' => 510.0, 'thickness' => 18.6, 'material_id' => id186,
                                  'back_thickness' => 3.0 })
        target = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0,
                                                  'depth' => 510.0, 'thickness' => 18.0, 'material_id' => id18 })
        model.selection.clear
        model.selection.add(target)
        e::TemplatesDialog.handle_apply({ 'template' => tpl_name }.to_json)
        cfg_t = e::Store.config(target) || {}
        ok('D-45 (e): sablona s materialom 18,6 prestavala skrinku na 18,6',
           (cfg_t['thickness'].to_f - 18.6).abs < 0.01 && cfg_t['material_id'] == id186 &&
           (part_width_x(find_part(target, 'cabinet/side:left')) - 18.6).abs < TOL)
        e::TemplateStore.delete('cabinet', tpl_name)
      end
    ensure
      # poradie: model spat na povodnu predvolbu, potom katalog (mazanie dosky
      # kontroluje jej pouzitie — korpusy uz musia byt prec)
      model.start_operation('SU-TEST D45 obnova predvolby', true)
      e::Materials.set_project_default(model, 'default_material_id', saved_default.to_s)
      model.commit_operation
      cleanup(model)
      d45_cleanup_catalog(res)
    end
    ok('D-45: cleanup (0 korpusov, testovaci dekor prec)',
       cabinets(model).empty? && e::Materials.sheets.none? { |s| s['decor'] == D45_DECOR })
  rescue StandardError => ex
    log_line("FAIL: D-45 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    remove_js_recorder
    cleanup(model)
    d45_cleanup_catalog(res) if defined?(res) && res.is_a?(Hash)
  end

  def d45_cleanup_catalog(res)
    return unless res.is_a?(Hash)
    Array(res['sheets']).each { |id| e::Materials.delete_sheet(id) }
    Array(res['edges']).each { |id| e::Materials.delete_edge(id) }
  rescue StandardError => ex
    log_line("INFO: D-45 cleanup katalogu: #{ex.class}: #{ex.message}")
  end

  # --- SYNC-D46: projektova predvolba KORPUSU s inou hrubkou ------------------
  # Bloker z testovania (Halifax 18,6): predvolba sa nedala zmenit, kym existovali
  # dediace skrinky — tvrdy abort. Teraz: dry-run -> ponuka -> jedno potvrdenie ->
  # vsetky dediace skrinky prevezmu hrubku v JEDNOM undo kroku. Overuje sa aj to,
  # co sa VEDOME odmieta (blokujuce dielce, zastaraly suhlas).
  # Katalog: docasny dekor (DTDL 18 + DTDL 18,6 + MDF 18), na konci sa ZMAZE.

  D46_DECOR = 'SU TEST D46'

  def install_md_recorder(rec)
    e::MaterialsDialog.singleton_class.class_eval do
      alias_method :nx_js_orig_md, :js
      define_method(:js) { |script| rec << script.to_s; nil }
    end
  end

  def remove_md_recorder
    sc = e::MaterialsDialog.singleton_class
    return unless sc.method_defined?(:nx_js_orig_md)
    sc.class_eval do
      alias_method :js, :nx_js_orig_md
      remove_method :nx_js_orig_md
    end
  end

  # Poziadavka do okna Materialy projektu; vrati ZAZNAM JS volani (okno nebezi).
  def md_call(payload)
    rec = []
    install_md_recorder(rec)
    begin
      e::MaterialsDialog.handle_set_project_material(payload.to_json)
    ensure
      remove_md_recorder
    end
    rec
  end

  # Pending kontrakt z poslednej ponuky MD.confirmDefault({...}) alebo nil.
  def md_pending(rec)
    line = rec.reverse.find { |s| s.start_with?('MD.confirmDefault(') }
    return nil unless line
    JSON.parse(line[(line.index('(') + 1)...line.rindex(')')])['pending']
  rescue StandardError => ex
    log_line("INFO: D-46 parse pendingu: #{ex.class}: #{ex.message}")
    nil
  end

  def md_status?(rec, *fragments)
    rec.any? { |s| s.include?('MD.setStatus') && fragments.all? { |f| s.include?(f) } }
  end

  def d46_default(model)
    e::Materials.project_defaults(model)['default_material_id']
  end

  def d46_th(inst)
    (e::Store.config(inst) || {})['thickness'].to_f
  end

  def run_d46(model)
    if e::Materials.sheets.any? { |s| s['decor'] == D46_DECOR }
      return info("D-46: dekor #{D46_DECOR} uz v katalogu existuje — sekcia preskocena (chranime pouzivatelske data)")
    end
    seeded, res = e::Materials.add_decor_batch('decor' => D46_DECOR, 'manufacturer' => 'SU TEST',
                                               'type' => 'DTDL', 'thicknesses' => '18, 18.6')
    return info("D-46: seed katalogu zlyhal (#{res.inspect}) — sekcia preskocena") unless seeded
    # druhy material hrubky 18 (iny TYP) — potrebny na scenar zastaraleho suhlasu
    seeded2, res2 = e::Materials.add_decor_batch('decor' => D46_DECOR, 'manufacturer' => 'SU TEST',
                                                 'type' => 'MDF', 'thicknesses' => '18')
    sh = ->(type, th) {
      s = e::Materials.sheets.find do |x|
        x['decor'] == D46_DECOR && x['type'].to_s.upcase == type && (x['thickness'].to_f - th).abs < 0.01
      end
      s && s['material_id']
    }
    id18 = sh.call('DTDL', 18.0)
    id186 = sh.call('DTDL', 18.6)
    id18b = seeded2 ? sh.call('MDF', 18.0) : nil
    unless id18 && id186 && id18b
      d46_cleanup_catalog(res, res2)
      return info('D-46: seed nema vsetky varianty — sekcia preskocena')
    end
    saved_default = d46_default(model)
    guid = e::MaterialsDialog.model_guid(model)
    base = { 'type' => 'lower', 'height' => 720.0, 'depth' => 510.0, 'thickness' => 18.0 }

    begin
      model.start_operation('SU-TEST D46 predvolba', true)
      e::Materials.set_project_default(model, 'default_material_id', id18)
      model.commit_operation

      a = e::CabinetBuilder.build(model, base.merge('width' => 600.0))            # dedi
      b = e::CabinetBuilder.build(model, base.merge('width' => 500.0))            # dedi
      own = e::CabinetBuilder.build(model, base.merge('width' => 450.0, 'material_id' => id18))
      cid_a = e::Store.get(a, 'cabinet_id')
      cid_b = e::Store.get(b, 'cabinet_id')

      # (a) PRVY POKUS = len ponuka. Do modelu sa nesmie zapisat NIC.
      rec = md_call('key' => 'default_material_id', 'value' => id186, 'model_guid' => guid)
      pending = md_pending(rec)
      ok('D-46 (a): prvy pokus vratil ponuku s pendingom pre obe dediace skrinky',
         !pending.nil? && pending['adopting_ids'].sort == [cid_a, cid_b].sort)
      ok('D-46 (a): ponuka NIC nezapisala (predvolba aj hrubky drzia 18)',
         d46_default(model) == id18 && (d46_th(a) - 18.0).abs < 0.01 && (d46_th(b) - 18.0).abs < 0.01)
      ok('D-46 (a): status pomenoval pocet skriniek aj novu hrubku',
         md_status?(rec, 'skrinky prevezmú', '18,6'))
      ok('D-46 (c): skrinka s VLASTNYM materialom v ponuke vobec nie je',
         !pending.nil? &&
         !(pending['adopting_ids'] + pending['recompute_ids']).include?(e::Store.get(own, 'cabinet_id')))

      # (e) ZASTARALY SUHLAS: predvolba sa medzitym zmeni na iny material rovnakej
      #     hrubky (ziadne potvrdenie netreba) — stary pending uz nesedi.
      md_call('key' => 'default_material_id', 'value' => id18b, 'model_guid' => guid)
      ok('D-46 (e): material rovnakej hrubky sa ulozil BEZ potvrdenia',
         d46_default(model) == id18b && (d46_th(a) - 18.0).abs < 0.01)
      rec_e = md_call('key' => 'default_material_id', 'value' => id186,
                      'model_guid' => guid, 'confirm' => pending)
      ok('D-46 (e): zastaraly suhlas sa NEVYKONAL (predvolba drzi, hrubky drzia)',
         d46_default(model) == id18b && (d46_th(a) - 18.0).abs < 0.01)
      ok('D-46 (e): namiesto zapisu prisla NOVA ponuka',
         rec_e.any? { |s| s.start_with?('MD.confirmDefault(') } && md_status?(rec_e, 'medzitým'))

      # (a2) POTVRDENIE cerstvym kontraktom — 1 undo krok vrati vsetko naraz.
      pending2 = md_pending(rec_e)
      md_call('key' => 'default_material_id', 'value' => id186, 'model_guid' => guid,
              'confirm' => pending2)
      side_a = find_part(a, 'cabinet/side:left')
      ok('D-46 (a): potvrdenie prevzalo hrubku OBOM dediacim skrinkam + ulozilo predvolbu',
         d46_default(model) == id186 && (d46_th(a) - 18.6).abs < 0.01 && (d46_th(b) - 18.6).abs < 0.01)
      ok('D-46 (a): geometria bokov sedi s novou hrubkou (18,6 mm)',
         !side_a.nil? && (part_width_x(side_a) - 18.6).abs < TOL &&
         (part_width_x(find_part(b, 'cabinet/side:left')) - 18.6).abs < TOL)
      ok('D-46 (c): skrinka s vlastnym materialom ostala nedotknuta (18 mm)',
         (d46_th(own) - 18.0).abs < 0.01 && (e::Store.config(own) || {})['material_id'] == id18)
      Sketchup.undo
      ok('D-46 (a): 1x undo vratil OBE skrinky AJ modelovu predvolbu',
         d46_default(model) == id18b && (d46_th(a) - 18.0).abs < 0.01 && (d46_th(b) - 18.0).abs < 0.01 &&
         (part_width_x(find_part(a, 'cabinet/side:left')) - 18.0).abs < TOL)

      # (d) MIESANA DAVKA: skrinka s hrubkovym driftom (dedi, ale uz stoji na 18,6)
      #     sa len prepocita — pocty v ponuke to musia rozlisit.
      c = e::CabinetBuilder.build(model, base.merge('width' => 400.0, 'thickness' => 18.6,
                                                    'material_id' => id186))
      cid_c = e::Store.get(c, 'cabinet_id')
      model.start_operation('SU-TEST D46 drift', true)
      cfg_c = e::Store.config(c) || {}
      cfg_c.delete('material_id') # dedi, ale hrubku uz ma novu (stav z praxe: drift)
      e::Store.write_config(c, cfg_c)
      model.commit_operation
      rec_d = md_call('key' => 'default_material_id', 'value' => id186, 'model_guid' => guid)
      pending_d = md_pending(rec_d)
      ok('D-46 (d): miesana davka — 2 prevezmu hrubku, 1 sa len prepocita',
         !pending_d.nil? && pending_d['adopting_ids'].sort == [cid_a, cid_b].sort &&
         pending_d['recompute_ids'] == [cid_c])
      ok('D-46 (d): ponuka vypisala aj pocet prepocitanych',
         md_status?(rec_d, 'prepočítajú sa aj ďalšie: 1'))
      rec_d2 = md_call('key' => 'default_material_id', 'value' => id186, 'model_guid' => guid,
                       'confirm' => pending_d)
      ok('D-46 (d): potvrdenie prestavalo vsetky tri (2 prevzali hrubku, 1 prepocitana)',
         d46_default(model) == id186 && (d46_th(a) - 18.6).abs < 0.01 &&
         (d46_th(c) - 18.6).abs < 0.01 && md_status?(rec_d2, 'Predvoľba uložená', 'prevzali'))

      # (b) BLOKUJUCE DIELCE: polica skrinky A ma vlastny material 18,6 — navrat
      #     predvolby na 18 sa odmietne CELY, bez ponuky a bez zapisu.
      params_sh = e::CabinetBuilder.config_to_params(e::Store.config(a))
                                   .merge('zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] })
      shelf_key = e::CabinetBuilder.plan_parts_by_key(params_sh)
                                   .find { |_k, pd| pd[:role].to_s == 'shelf' }&.first
      if shelf_key
        e::CabinetBuilder.rebuild(model, a,
                                  params_sh.merge('part_overrides' => { shelf_key => { 'material_id' => id186 } }))
        rec_b = md_call('key' => 'default_material_id', 'value' => id18, 'model_guid' => guid)
        ok('D-46 (b): blokujuci dielec zrusil CELU davku — ziadna ponuka',
           rec_b.none? { |s| s.start_with?('MD.confirmDefault(') })
        ok('D-46 (b): hlaska vymenovala skrinku aj blokujuci dielec',
           md_status?(rec_b, 'blokujú dielce', cid_a.to_s))
        ok('D-46 (b): predvolba ani konfiguracie sa nezmenili',
           d46_default(model) == id186 && (d46_th(a) - 18.6).abs < 0.01 && (d46_th(b) - 18.6).abs < 0.01)
        ok('D-46 (b): select sa vratil na skutocnu predvolbu',
           rec_b.any? { |s| s.start_with?('MD.resetProject(') && s.include?(id186) })
      else
        info('D-46 (b): plan nema policu — scenar blokujuceho dielca preskoceny')
      end
    ensure
      model.start_operation('SU-TEST D46 obnova predvolby', true)
      e::Materials.set_project_default(model, 'default_material_id', saved_default.to_s)
      model.commit_operation
      cleanup(model)
      d46_cleanup_catalog(res, res2)
    end
    ok('D-46: cleanup (0 korpusov, testovaci dekor prec)',
       cabinets(model).empty? && e::Materials.sheets.none? { |s| s['decor'] == D46_DECOR })
  rescue StandardError => ex
    log_line("FAIL: D-46 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    remove_md_recorder
    cleanup(model)
    d46_cleanup_catalog(res, res2) if defined?(res)
  end

  def d46_cleanup_catalog(*results)
    results.each do |res|
      next unless res.is_a?(Hash)
      Array(res['sheets']).each { |id| e::Materials.delete_sheet(id) }
      Array(res['edges']).each { |id| e::Materials.delete_edge(id) }
    end
  rescue StandardError => ex
    log_line("INFO: D-46 cleanup katalogu: #{ex.class}: #{ex.message}")
  end

  # --- SYNC-2A2: migracia katalogu na SCHEMA 2 nad IZOLOVANYM katalogom -------
  # Cely scenar bezi cez Materials.test_dir_override (docasny priecinok s legacy
  # fixture) — REALNY %APPDATA% katalog sa NIKDY necita ani nezapisuje; overuje
  # sa len, ze override cesta je aktivna. Override sa VZDY vracia na nil
  # (aj vo FAIL vetve) + Materials.reload!, inak by dalsie sekcie citali cudzi
  # katalog. Tok: fixture -> korpus + doska so starymi ID -> dry_run (subor
  # nedotknuty) -> ostra migracia -> rebuild + BOM + semafor (RED abs_missing
  # LEN pre zmazanu pasku) -> remap_edges nad novym dekorom -> cleanup.

  A2_FIXTURE = File.expand_path('../fixtures/materials_legacy_v1.json', __dir__)

  def run_2a2(model)
    unless File.exist?(A2_FIXTURE)
      return info("2A-2: fixture #{A2_FIXTURE} chyba — sekcia preskocena")
    end
    tmp = File.join(Dir.tmpdir, "noxun_2a2_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    fixture = File.binread(A2_FIXTURE)
    File.binwrite(File.join(tmp, 'materials.json'), fixture)
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    begin
      ok('2A-2: override cesty katalogu je aktivny (realny katalog sa nedotkne)',
         e::Materials.path == File.join(tmp, 'materials.json') &&
         e::Materials.sheet('K009_PW_DTDL_18') != nil)

      # korpus so starym ID + rucne ABS overridy (jedna hrana na pasku, ktoru
      # migracia zmaze) + samostatna doska so starym ID
      inst = e::CabinetBuilder.build(model, {
        'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
        'thickness' => 18.0, 'material_id' => 'K009_PW_DTDL_18',
        'part_overrides' => {
          'cabinet/side:left'  => { 'edges' => { 'L1' => 'ABS_K009_10' } },
          'cabinet/side:right' => { 'edges' => { 'L1' => 'ABS_PRACOVNA_DOSKA_10' } }
        }
      })
      board = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                             'length' => 400.0, 'width' => 300.0,
                                             'edges' => { 'L1' => 'ABS_K009_10' } })
      ok('2A-2: korpus + doska so starymi ID stoja', !inst.nil? && !board.nil?)

      before = File.binread(e::Materials.path)
      rep_dry = e::Materials.migrate_to_schema2!(dry_run: true)
      ok("2A-2: dry_run report ok (skupiny #{rep_dry[:groups].length}, mazane #{rep_dry[:deleted].inspect})",
         rep_dry[:status] == :ok && rep_dry[:groups].length == 9 &&
         rep_dry[:deleted] == ['ABS_PRACOVNA_DOSKA_10'] &&
         rep_dry[:retyped] == ['HALIFAX_TABAKOVY_PD_DTDL_38'])
      ok('2A-2: dry_run subor bajtovo nezmenil (ani zalohu nevytvoril)',
         File.binread(e::Materials.path).b == before.b &&
         !File.exist?(e::Materials.pre_schema2_backup_path))
      ok('2A-2: dry_run report vie o pouziti mazanej pasky v modeli (O7 varovanie)',
         rep_dry[:warnings].any? { |w| w.include?('ABS_PRACOVNA_DOSKA_10') })

      rep = e::Materials.migrate_to_schema2!
      ok("2A-2: ostra migracia presla (#{rep[:status].inspect})", rep[:status] == :ok)
      e::Materials.reload!
      ok('2A-2: katalog nesie SCHEMA 2 + predmigracna zaloha je bajtova kopia povodiny',
         e::Materials.catalog_schema == 2 &&
         File.binread(e::Materials.pre_schema2_backup_path).b == fixture.b)
      k18 = e::Materials.sheet('K009_PW_DTDL_18')
      ke = e::Materials.edge('ABS_K009_10')
      ok('2A-2: K009 zachovane ID, spolocny group_id dosky a pasky, dekor K009/PW',
         !k18.nil? && !ke.nil? && k18['group_id'].to_s.start_with?('GRP-') &&
         k18['group_id'] == ke['group_id'] && k18['decor'] == 'K009' && k18['structure'] == 'PW')
      ok('2A-2: zmazana paska uz v katalogu nie je',
         e::Materials.edge('ABS_PRACOVNA_DOSKA_10').nil?)

      # BOM + semafor NAD STARYMI SNAPSHOTMI (pred rebuildom — presne stav
      # "stary .skp otvoreny po migracii"): zachovane ID citaju dalej, zmazana
      # paska = RED abs_missing. (Rebuild by referenciu cez normalized_abs_id
      # legalne zmenil na "bez ABS" — preto sa semafor overuje PRED nim.)
      collected = e::Bom.collect(model)
      mats = collected[:records].map { |r| r['material_id'] }.uniq
      ok('2A-2: BOM cita zachovane ID dielcov aj dosky', mats.include?('K009_PW_DTDL_18'))
      smap = e::Materials.sheets.each_with_object({}) { |s, out| out[s['material_id']] = s }
      emap = e::Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a }
      control = e::Validation.run(collected, sheets: smap, edges: emap)
      missing = control['items'].select { |i| i['category'] == 'abs_missing' }
      ok('2A-2: semafor RED abs_missing PRESNE pre zmazanu pasku (side:right)',
         missing.length == 1 && missing.first['severity'] == 'red' &&
         missing.first['message_sk'].include?('ABS_PRACOVNA_DOSKA_10') &&
         missing.first['part_key'] == 'cabinet/side:right')
      ok('2A-2: ziadny RED material pre zachovane ID',
         control['items'].none? { |i| i['category'] == 'material' })

      # rebuild korpusu nad SCHEMA 2 katalogom — stare ID funguju dalej
      p2 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      e::CabinetBuilder.rebuild(model, inst, p2)
      cfg = e::Store.config(inst) || {}
      ok('2A-2: rebuild po migracii OK a material drzi povodne ID',
         inst.valid? && cfg['material_id'] == 'K009_PW_DTDL_18')
      mats2 = e::Bom.collect(model)[:records].map { |r| r['material_id'] }.uniq
      ok('2A-2: BOM po rebuilde stale cita zachovane ID', mats2.include?('K009_PW_DTDL_18'))

      # remap_edges nad migrovanym katalogom (nove dekory skupin)
      remapped, lost = e::Materials.remap_edges({ 'L1' => 'ABS_K009_10' }, 'K009', 'U750', 18.0)
      ok('2A-2: remap_edges bezi nad novymi dekormi (K009 -> U750 23/1)',
         !remapped.nil? && remapped['L1'] == 'ABS_U750_ST9_TAUPE_SEDA_23X10' && lost.empty?)
    ensure
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      cleanup(model)
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
    ok('2A-2: cleanup (override prec, realny katalog cita zas z APPDATA)',
       e::Materials.test_dir_override.nil? && cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: 2A-2 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  # --- SYNC-2A3: vyberove cesty ABS so strukturou (SCHEMA 2 sandbox) ---------
  # Cely scenar bezi nad IZOLOVANYM katalogom SCHEMA 2 (Materials.test_dir_override
  # — vzor run_2a2; realny %APPDATA% katalog sa NIKDY necita ani nezapisuje).
  # ABS pravidla NEMAJU override — sekcia si ich docasne upravi (dvojka na
  # side_left) a v ensure VZDY vrati bajt-presny povodny subor + reload.
  # Scenare (2A-3a): korpus + celo dostanu pasky spravnej struktury; 5981
  # s dvoma 23/1 roznych struktur sa nikdy nemiesa; dvojka fallback 1,5 je
  # viditelny v KONTROLE (ORANGE); ensure vytvori 23/1 so strukturou dosky;
  # warning dosky prezije retaz config -> Bom.collect -> Validation.run.

  def a3_catalog_json
    sheet = lambda do |id, gid, decor, structure, th|
      { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => decor,
        'type' => 'DTDL', 'thickness' => th, 'grain' => 'length',
        'sheet_size' => [2800.0, 2070.0], 'color' => [200, 190, 170],
        'production_class' => 'sheet', 'group_id' => gid, 'structure' => structure }
    end
    edge = lambda do |id, gid, decor, structure, th, w|
      { 'abs_id' => id, 'decor' => decor, 'thickness' => th, 'width' => w,
        'color' => [200, 190, 170], 'group_id' => gid, 'structure' => structure }
    end
    {
      'std' => 1, 'schema' => 2,
      'sheets' => [
        sheet.call('A3KORP18', 'GRP-A3K009', 'K009', 'PW', 18.0),
        sheet.call('A35981MG18', 'GRP-A35981', '5981', 'MG', 18.0),
        sheet.call('A35981AF18', 'GRP-A35981', '5981', 'AF', 18.0),
        sheet.call('A3DVOJ18', 'GRP-A3DVOJ', 'DVOJ', 'ST', 18.0),
        sheet.call('A3ENS18', 'GRP-A3ENS', 'ENS', 'XA', 18.0),
        sheet.call('A3NOABS18', 'GRP-A3NOABS', 'NOABS', 'SM', 18.0)
      ],
      'edges' => [
        edge.call('A3E_K009_PW_23X10', 'GRP-A3K009', 'K009', 'PW', 1.0, 23.0),
        edge.call('A3E_5981_MG_23X10', 'GRP-A35981', '5981', 'MG', 1.0, 23.0),
        edge.call('A3E_5981_AF_23X10', 'GRP-A35981', '5981', 'AF', 1.0, 23.0),
        edge.call('A3E_DVOJ_15', 'GRP-A3DVOJ', 'DVOJ', 'ST', 1.5, 23.0)
      ]
    }
  end

  def a3_part_by_role(inst, role)
    inst.definition.entities.grep(Sketchup::ComponentInstance)
        .find { |i| e::Store.kind(i) == 'part' && e::Store.get(i, 'role').to_s == role }
  end

  def run_2a3(model)
    tmp = File.join(Dir.tmpdir, "noxun_2a3_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(a3_catalog_json))
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    rules_path = e::AbsRules.path
    rules_before = File.exist?(rules_path) ? File.binread(rules_path) : nil
    begin
      ok('2A-3: override katalogu aktivny + marker SCHEMA 2',
         e::Materials.path == File.join(tmp, 'materials.json') &&
         e::Materials.catalog_schema == 2 && !e::Materials.sheet('A3KORP18').nil?)

      # 1) korpus + celo: pasky SPRAVNEJ struktury (telo PW, celo 5981 MG)
      inst = e::CabinetBuilder.build(model, {
        'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
        'thickness' => 18.0, 'material_id' => 'A3KORP18',
        'front_material_id' => 'A35981MG18', 'fronts' => '1'
      })
      side = a3_part_by_role(inst, 'side_left')
      scfg = e::Store.config(side) || {}
      ok('2A-3: bok dostal pasku struktury PW (skupina tela)',
         (scfg['edges'] || {})['L1'] == 'A3E_K009_PW_23X10')
      front = a3_part_by_role(inst, 'front_door')
      fcfg = e::Store.config(front) || {}
      ok('2A-3: celo dostalo 4x pasku PRESNE svojej struktury MG',
         %w[L1 L2 W1 W2].all? { |c| (fcfg['edges'] || {})[c] == 'A3E_5981_MG_23X10' })

      # 2) 5981: dve 23/1 roznych struktur sa NIKDY nemiesaju — prepnutie cela
      #    MG -> AF preladi pravidlove hrany vyhradne na AF pasku
      p2 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      p2['front_material_id'] = 'A35981AF18'
      e::CabinetBuilder.rebuild(model, inst, p2)
      front2 = a3_part_by_role(inst, 'front_door')
      f2cfg = e::Store.config(front2) || {}
      ok('2A-3: celo po zmene MG -> AF nesie vyhradne AF pasku (struktury sa nemiesaju)',
         %w[L1 L2 W1 W2].all? { |c| (f2cfg['edges'] || {})[c] == 'A3E_5981_AF_23X10' })

      # 3) dvojka fallback 1,5 az do KONTROLY (ORANGE): docasne pravidlo
      #    side_left L1 = 2,0 nad skupinou, ktora ma LEN 1,5
      rules = e::AbsRules.load
      rules['side_left'] = { 'L1' => 2.0 }
      e::AbsRules.write(rules)
      inst3 = e::CabinetBuilder.build(model, {
        'type' => 'lower', 'width' => 500.0, 'height' => 720.0, 'depth' => 510.0,
        'thickness' => 18.0, 'material_id' => 'A3DVOJ18'
      })
      cid3 = e::Store.get(inst3, 'cabinet_id').to_s
      side3 = a3_part_by_role(inst3, 'side_left')
      s3cfg = e::Store.config(side3) || {}
      ok('2A-3: dvojka rozriesena na 1,5 pasku skupiny (resolver fallback)',
         (s3cfg['edges'] || {})['L1'] == 'A3E_DVOJ_15')
      c3cfg = e::Store.config(inst3) || {}
      w3 = Array(c3cfg['warnings'])
      ok('2A-3: config korpusu nesie warning abs_15_fallback s part_key boku',
         w3.any? { |w| w['code'] == 'abs_15_fallback' && w['part_key'] == 'cabinet/side:left' })
      smap = e::Materials.sheets.each_with_object({}) { |s, o| o[s['material_id']] = s }
      val3 = e::Validation.run(e::Bom.collect(model), sheets: smap)
      item3 = val3['items'].find do |i|
        i['category'] == 'build' && i['owner_id'] == cid3 &&
          i['stable_key'].include?('abs_15_fallback')
      end
      ok('2A-3: dvojka fallback 1,5 viditelny v KONTROLE (ORANGE)',
         !item3.nil? && item3['severity'] == 'orange' && item3['part_key'] == 'cabinet/side:left')

      # 4) ensure vytvori 23/1 so strukturou dosky (skupina ENS bez pasok)
      st4, aid4 = e::Materials.ensure_edge_for_sheet('A3ENS18', client_schema: 2)
      rec4 = e::Materials.edge(aid4)
      ok('2A-3: ensure vytvoril 23/1 so strukturou dosky + group_id skupiny',
         st4 == :created && !rec4.nil? && (rec4['width'].to_f - 23.0).abs < 0.01 &&
         (rec4['thickness'].to_f - 1.0).abs < 0.01 && rec4['structure'] == 'XA' &&
         rec4['group_id'] == 'GRP-A3ENS')

      # 5) warning DOSKY prezije retaz config -> Bom.collect -> Validation.run
      board = e::BoardBuilder.build(model, { 'material_id' => 'A3NOABS18',
                                             'length' => 400.0, 'width' => 300.0 })
      bid5 = e::Store.get(board, 'id').to_s
      bcfg5 = e::Store.config(board) || {}
      ok('2A-3: doska nad skupinou bez pasok nesie warning abs_structure_missing v configu',
         Array(bcfg5['warnings']).any? { |w| w['code'] == 'abs_structure_missing' })
      col5 = e::Bom.collect(model)
      ok('2A-3: Bom.collect zbiera warnings aj z dosky (board vetva)',
         col5[:warnings].any? { |w| w['code'] == 'abs_structure_missing' && w['owner_id'] == bid5 })
      val5 = e::Validation.run(col5, sheets: smap)
      ok('2A-3: warning dosky je ORANGE polozka KONTROLY',
         val5['items'].any? do |i|
           i['category'] == 'build' && i['owner_id'] == bid5 &&
             i['stable_key'].include?('abs_structure_missing') && i['severity'] == 'orange'
         end)
    ensure
      if rules_before
        File.binwrite(rules_path, rules_before)
      else
        begin
          File.delete(rules_path) if File.exist?(rules_path)
        rescue StandardError
          nil
        end
      end
      e::AbsRules.reload!
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      cleanup(model)
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
    ok('2A-3: cleanup (override prec, pravidla vratene, model prazdny)',
       e::Materials.test_dir_override.nil? && cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: 2A-3 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  # --- D-40: selection eventy po builde musia zit (DC observer pasca) --------
  # Bug: zapis dynamic_attributes (scaletool) v operacii, ktora VYTVARA definiciu/
  # instanciu, pri commite cez DC extension observer vypne dorucovanie selection
  # eventov celemu modelu (panel "visi" na starom vybere; reset az zmenou edit
  # kontextu). Fix: zamok v transparentnom follow-upe (apply_scale_lock_op).

  class D40Probe < Sketchup::SelectionObserver
    def initialize
      super
      @n = 0
    end
    attr_reader :n

    def onSelectionBulkChange(_s); @n += 1; end
    def onSelectionCleared(_s); @n += 1; end
    def onSelectionAdded(_s, _e); @n += 1; end
    def onSelectionRemoved(_s, _e); @n += 1; end
  end

  # Ziju selection observer eventy? (add+clear s cerstvym observerom, count > 0)
  def selection_alive?(model, inst)
    return false unless inst && inst.valid?
    probe = D40Probe.new
    model.selection.add_observer(probe)
    model.selection.add(inst)
    model.selection.clear
    probe.n > 0
  ensure
    begin
      model.selection.remove_observer(probe) if probe
    rescue StandardError
      nil
    end
  end

  # --- SYNC-2A4: OSTRY CUTOVER — boot_cutover! nad legacy fixture (2A-4b) ----
  # Vzor run_2a2: cely scenar bezi nad IZOLOVANYM katalogom (test_dir_override
  # + kopia fixture) — zivy %APPDATA% katalog sa NIKDY necita ani nezapisuje.
  # Scenar: legacy fixture -> boot_cutover! (ostra migracia + zaloha + log) ->
  # korpus dostane pasky strukturne (picker SCHEMA 2) -> universal patch cez
  # SKUTOCNY handler okna Materialy -> restore_pre_schema2! (rollback + hold)
  # -> druhy boot preskoci (hold sa konzumuje) -> treti boot migruje znova.
  def run_2a4(model)
    unless File.exist?(A2_FIXTURE)
      return info("2A-4: fixture #{A2_FIXTURE} chyba — sekcia preskocena")
    end
    tmp = File.join(Dir.tmpdir, "noxun_2a4_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    fixture = File.binread(A2_FIXTURE)
    File.binwrite(File.join(tmp, 'materials.json'), fixture)
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    begin
      ok('2A-4: override cesty katalogu je aktivny (realny katalog sa nedotkne)',
         e::Materials.path == File.join(tmp, 'materials.json'))

      # 1. BOOT CUTOVER: legacy katalog sa OSTRO zmigruje (to iste, co spravi
      # main.rb pri starte SketchUpu po merge + INSTALL).
      branch = e::Materials.boot_cutover!
      e::Materials.reload!
      ok("2A-4: boot_cutover! zmigroval legacy katalog (#{branch.inspect})",
         branch == :migrated && e::Materials.catalog_schema == 2)
      ok('2A-4: predmigracna zaloha je bajtova kopia povodiny',
         File.exist?(e::Materials.pre_schema2_backup_path) &&
         File.binread(e::Materials.pre_schema2_backup_path).b == fixture.b)
      ok('2A-4: NOTE12 — po cutoveri su presne 3 pasky bez struktury a bez universal (banner)',
         e::Materials.unusable_edges_count == 3)
      k = e::Materials.sheet('K009_PW_DTDL_18')
      ok('2A-4: K009 nesie skupinu + strukturu PW (ID nezmenene)',
         !k.nil? && k['decor'] == 'K009' && k['structure'] == 'PW' &&
         k['group_id'].to_s.start_with?('GRP-'))

      # 2. Korpus nad zmigrovanym katalogom: picker vybera STRUKTURNE
      # (abs_for_sheet vetva A — PW doska dostane PW pasku).
      inst = e::CabinetBuilder.build(model, {
        'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
        'thickness' => 18.0, 'material_id' => 'K009_PW_DTDL_18'
      })
      ok('2A-4: korpus nad SCHEMA 2 katalogom stoji', !inst.nil? && inst.valid?)
      # ABS defaulty sa citaju zo SNAPSHOTU dielca (standard 8.3) — bok nesie
      # edges v configu na instancii (side_left ma default L1 jednotku).
      side = inst.definition.entities.grep(Sketchup::ComponentInstance)
                 .find { |i| e::Store.kind(i) == 'part' && e::Store.get(i, 'role').to_s == 'side_left' }
      sedges = side ? (e::Store.config(side) || {})['edges'] : nil
      ok('2A-4: bok dostal strukturnu 1,0 pasku K009 PW (picker vetva A)',
         sedges.is_a?(Hash) && sedges['L1'] == 'ABS_K009_10')

      # 3. Universal patch cez SKUTOCNY handler okna Materialy (patch_edge cesta;
      # dialog nie je otvoreny — js() je no-op, zapis bezi naplno).
      rec = e::Materials.edge('ABS_BIELA_KORPUS_10')
      payload = { 'id' => 'ABS_BIELA_KORPUS_10', 'patch' => { 'universal' => true },
                  'row_rev' => e::Materials.record_rev(rec), 'catalog_schema' => 2 }.to_json
      e::MaterialsDialog.handle_patch(payload, 'edge')
      e::Materials.reload!
      ok('2A-4: universal toggle cez handler zapisal priznak',
         e::Materials.edge('ABS_BIELA_KORPUS_10')['universal'] == true)
      ok('2A-4: banner pocet klesol na 2 (Halifax + UNI ostavaju)',
         e::Materials.unusable_edges_count == 2)
      # Universal paska je teraz pouzitelna pre bezstrukturnu Biela korpus dosku.
      bk = e::Materials.sheets.find { |s| s['decor'] == 'Biela korpus' }
      ok('2A-4: universal paska je hned pouzitelna pre bezstrukturnu dosku (vetva B)',
         !bk.nil? && e::Materials.abs_for_sheet(bk, :jednotka, 18.0).first == 'ABS_BIELA_KORPUS_10')

      # 4. ROLLBACK: restore_pre_schema2! nasadi zalohu + hold flag; druhy boot
      # migraciu RAZ preskoci (hold sa konzumuje), treti migruje znova.
      ok_res, report = e::Materials.restore_pre_schema2!
      e::Materials.reload!
      ok("2A-4: restore_pre_schema2! nasadil zalohu (#{report.inspect})",
         ok_res && e::Materials.catalog_schema == 1 && e::Materials.migration_hold?)
      ok('2A-4: boot po rollbacku = :hold (migracia preskocena, flag zmazany)',
         e::Materials.boot_cutover! == :hold && !e::Materials.migration_hold? &&
         e::Materials.catalog_schema == 1)
      ok('2A-4: dalsi boot migruje znova (jednorazovost holdu)',
         e::Materials.boot_cutover! == :migrated && e::Materials.catalog_schema == 2)
    ensure
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      cleanup(model)
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
    ok('2A-4: cleanup (override prec, realny katalog cita zas z APPDATA)',
       e::Materials.test_dir_override.nil? && cabinets(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: 2A-4 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  def run_d40(model)
    # D40-1: korpus — eventy + atributy zamku
    cab = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0 })
    ok('D40: build korpusu vrati instanciu', !cab.nil?)
    ok('D40: selection eventy ziju po vlozeni korpusu', selection_alive?(model, cab))
    ok('D40: scaletool na instancii po vlozeni', cab.get_attribute('dynamic_attributes', 'scaletool') == '120')
    ok('D40: scaletool na definicii po vlozeni', cab.definition.get_attribute('dynamic_attributes', 'scaletool') == '120')

    # D40-2: doska — eventy po vlozeni
    brd = e::BoardBuilder.build(model, { 'length' => 800.0, 'width' => 400.0 })
    ok('D40: selection eventy ziju po vlozeni dosky', !brd.nil? && selection_alive?(model, brd))

    # D40-3: paste kopia s DC atributmi netriggeruje pascu (Codex audit B2 poistka).
    # Guard: simulovana kopia nesmie pocas testu spustit dedup tick observera.
    copy = nil
    e::ScaleWatch.guard do
      model.start_operation('D40 paste sim', false)
      copy = model.entities.add_instance(cab.definition,
                                         cab.transformation * Geom::Transformation.translation([mm(900), 0, 0]))
      src = cab.attribute_dictionary('dynamic_attributes')
      src && src.each_pair { |k, v| copy.set_attribute('dynamic_attributes', k, v) }
      model.commit_operation
    end
    ok('D40: selection eventy ziju po paste kopie', selection_alive?(model, copy))
    e::ScaleWatch.guard do
      model.start_operation('D40 paste cleanup', true)
      copy.erase! if copy && copy.valid?
      model.commit_operation
    end

    # D40-4: undo/redo — 1x undo odstrani CELE vlozenie (vratane transparent zamku);
    # redo (ak je synchronne API dostupne) obnovi objekt AJ oba zamky.
    n_before = cabinets(model).length
    c2 = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 500.0, 'height' => 700.0, 'depth' => 500.0 })
    c2_cid = e::Store.get(c2, 'cabinet_id')
    ok('D40: undo baseline — korpus pribudol', cabinets(model).length == n_before + 1)
    Sketchup.undo
    ok('D40: 1x undo odstrani cele vlozenie (vratane zamku)', cabinets(model).length == n_before)
    if Sketchup.respond_to?(:redo)
      Sketchup.redo
      c2r = nil
      e::Ids.each_cabinet(model) { |i| c2r = i if e::Store.get(i, 'cabinet_id') == c2_cid }
      ok('D40: redo vrati vlozeny korpus', !c2r.nil?)
      if c2r
        ok('D40: redo obnovi scaletool na instancii', c2r.get_attribute('dynamic_attributes', 'scaletool') == '120')
        ok('D40: redo obnovi scaletool na definicii', c2r.definition.get_attribute('dynamic_attributes', 'scaletool') == '120')
        ok('D40: selection eventy ziju po redo', selection_alive?(model, c2r))
      end
    else
      info('D40 REDO: Sketchup.redo nedostupne — redo vetva netestovana (async send_action vzor viz S1).')
    end

    cleanup(model)
    ok('D40: cleanup (0 korpusov)', cabinets(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: D40 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    cleanup(model)
  end

  # --- D-90: vizual uchytkoveho profilu UKW-7 na cele ------------------------
  # Overuje sa PROXY geometria proti kotve z navrhu (potvrdena fotkou montaze):
  #   vrch profilu = vrch POVODNEHO cela (z riadku + vyska riadku)
  #   zadna rovina = zadna rovina cela (Y = 0), profil ide dopredu do -19,181
  #   dlzka = sirka kridla; kazde kridlo ma vlastny kus
  # + vypnutie profilu (proxy zmizne, celo naspat plnou vyskou), undo a
  # reprodukovatelnost rebuildu.
  def d90_profiles(inst)
    inst.definition.entities.grep(Sketchup::ComponentInstance).select do |i|
      e::Store.kind(i) == 'hardware' && (e::Store.config(i) || {})['profile']
    end
  end

  def d90_fronts(inst)
    inst.definition.entities.grep(Sketchup::ComponentInstance).select do |i|
      e::Store.kind(i) == 'part' && e::Store.get(i, 'role') == 'front_door'
    end
  end

  # Obalovy kvader instancie v suradniciach KORPUSU (mm) = posun instancie +
  # obalovy kvader definicie (transformacia je ciste posunutie, ako pri dielcoch).
  def d90_box(i)
    o = i.transformation.origin
    b = i.definition.bounds
    { x0: mm(o.x) + mm(b.min.x), x1: mm(o.x) + mm(b.max.x),
      y0: mm(o.y) + mm(b.min.y), y1: mm(o.y) + mm(b.max.y),
      z0: mm(o.z) + mm(b.min.z), z1: mm(o.z) + mm(b.max.z) }
  end

  def d90_params(profile)
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'fixed',
                                  'height' => 500.0, 'wings' => '2',
                                  'profile' => profile }] } }
  end

  def run_d90(model)
    inst = e::CabinetBuilder.build(model, d90_params('ukw7'))
    return ok('D90: vlozenie korpusu s profilom', false) unless inst

    profs = d90_profiles(inst)
    fronts = d90_fronts(inst)
    ok("D90: 2 kridla = 2 kusy profilu (najdenych #{profs.length})", profs.length == 2)
    ok("D90: cela su skratene o 36 mm (#{fronts.map { |f| mm(f.definition.bounds.depth).round(1) }})",
       fronts.length == 2 && fronts.all? { |f| (mm(f.definition.bounds.depth) - 464.0).abs <= TOL })

    # kotva: vrch riadku = 102 (podlaha 100 + okraj 2) + 500 = 602
    z_top = 602.0
    bad = []
    profs.each do |p|
      b = d90_box(p)
      bad << "vrch #{b[:z1].round(2)} != #{z_top}" if (b[:z1] - z_top).abs > TOL
      bad << "vyska #{(b[:z1] - b[:z0]).round(2)} != 37,419" if ((b[:z1] - b[:z0]) - 37.419).abs > TOL
      bad << "zadna rovina #{b[:y1].round(2)} != 0" if b[:y1].abs > TOL
      bad << "hlbka #{(b[:y1] - b[:y0]).round(2)} != 19,181" if ((b[:y1] - b[:y0]) - 19.181).abs > TOL
    end
    ok("D90: profil sedi v pasme nad celom (#{bad.length} nezhod)#{bad.empty? ? '' : ' — ' + bad.first(3).join('; ')}",
       bad.empty?)

    # dlzka rezu = sirka kridla; kazdy profil lezi presne nad „svojim" kridlom
    pairs = profs.map do |p|
      pb = d90_box(p)
      f = fronts.find { |fr| (mm(fr.transformation.origin.x) - pb[:x0]).abs <= TOL }
      [pb, f]
    end
    ok('D90: kazdy profil ma svoje kridlo a dlzku = sirka kridla',
       pairs.all? { |pb, f| f && ((pb[:x1] - pb[:x0]) - mm(f.definition.bounds.width)).abs <= TOL })

    # spodok profilu prekryva vrch skrateneho panelu o 1,419 mm (zamerne)
    over = pairs.map do |pb, f|
      f ? (mm(f.transformation.origin.z) + mm(f.definition.bounds.depth)) - pb[:z0] : nil
    end
    ok("D90: spodny nos profilu prekryva lico cela o 1,419 mm (#{over.map { |v| v && v.round(3) }})",
       over.all? { |v| v && (v - 1.419).abs <= TOL })

    # PROXY kontrakt (supis geometriu nikdy necita)
    p0 = profs.first
    pcfg = e::Store.config(p0) || {}
    ok('D90: proxy = kind hardware, production_class none, manufactured false',
       e::Store.kind(p0) == 'hardware' && e::Store.get(p0, 'production_class') == 'none' &&
       e::Store.get(p0, 'manufactured') == false)
    ok("D90: proxy nesie generic_type handle + profil + rez (#{pcfg['generic_type']}, #{pcfg['profile']})",
       pcfg['generic_type'] == 'handle' && pcfg['profile'] == 'ukw7' && pcfg['proxy'] == true)
    ok('D90: definicia je per (profil, dlzka) — obe kridla ju zdielaju',
       profs.map { |p| p.definition.name }.uniq.length == 1 &&
       profs.first.definition.name.start_with?('NOXUN_PROFILE_UKW7_L'))
    # ORIENTACIA (Michalov nalez 9.8. — profil bol zrkadlovo): nos = najnizsie
    # body obrysu MUSIA lezat vpredu (y ~ -depth), chrbat na zadnej rovine.
    # Bbox je na zrkadlenie slepy, kontroluju sa skutocne vrcholy definicie.
    dverts = p0.definition.entities.grep(Sketchup::Edge).flat_map(&:vertices).uniq
                .map { |v| [mm(v.position.y), mm(v.position.z)] }
    dz0 = dverts.map(&:last).min
    nose_y = dverts.select { |_y, z| (z - dz0).abs <= 0.01 }.map(&:first)
    ok("D90: nos profilu je VPREDU (y spodnych bodov #{nose_y.map { |y| y.round(1) }.uniq.sort})",
       !nose_y.empty? && nose_y.all? { |y| y < -17.0 })
    # supis kovania ostava datovy — 2 polozky z config.hardware[], nie z geometrie
    hw = (e::Store.config(inst) || {})['hardware'] || []
    ok("D90: config.hardware nesie 2 polozky profilu (#{hw.count { |h| (h['params'] || {})['profile'] == 'ukw7' }})",
       hw.count { |h| (h['params'] || {})['profile'] == 'ukw7' } == 2)

    # reprodukovatelnost: rovnaky rebuild = rovnaky pocet aj kotva
    before = profs.map { |p| d90_box(p) }.sort_by { |b| b[:x0] }
    e::CabinetBuilder.rebuild(model, inst, d90_params('ukw7'))
    after = d90_profiles(inst).map { |p| d90_box(p) }.sort_by { |b| b[:x0] }
    ok('D90: rebuild je reprodukovatelny (rovnake proxy na rovnakom mieste)',
       after.length == before.length &&
       before.zip(after).all? { |a, b| a.keys.all? { |k| (a[k] - b[k]).abs <= TOL } })

    # vypnutie profilu: proxy zmizne a celo je opat plnou vyskou riadku
    e::CabinetBuilder.rebuild(model, inst, d90_params('none'))
    ok('D90: vypnutie profilu odstrani proxy', d90_profiles(inst).empty?)
    ok('D90: celo je po vypnuti opat 500 mm',
       d90_fronts(inst).all? { |f| (mm(f.definition.bounds.depth) - 500.0).abs <= TOL })

    # undo posledneho rebuildu = 1 krok spat (profil aj skratene celo su naspat)
    Sketchup.undo
    ok("D90: 1x undo vratil profil (#{d90_profiles(inst).length} ks) aj skratene celo",
       d90_profiles(inst).length == 2 &&
       d90_fronts(inst).all? { |f| (mm(f.definition.bounds.depth) - 464.0).abs <= TOL })

    cleanup(model)
    ok('D90: cleanup (0 korpusov)', cabinets(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: D90 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    cleanup(model)
  end

  # --- D-93: rucny zamok nominalnej dlzky vysuvu ------------------------------
  #
  # Overuje sa to, co Michal robi rukou: zamkne dlzku vysuvu na 420, potom meni
  # HLBKU skrinky — zamok musi drzat (aj ked automat by dal ine cislo, aj ked sa
  # do svetlej hlbky uz nezmesti ziadna dlzka radu), a po odomknuti sa musi
  # vratit automat. Vsetko cez REALNU prestavbu korpusu (config je autorita).
  def d93_params(depth)
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => depth,
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'drawer_front',
                                  'mode' => 'fixed', 'height' => 200.0 }] } }
  end

  def d93_slide(inst)
    ((e::Store.config(inst) || {})['hardware'] || []).find { |h| h['generic_type'] == 'slide' }
  end

  def d93_warn?(inst, code)
    Array((e::Store.config(inst) || {})['warnings']).any? { |w| w.is_a?(Hash) && w['code'] == code }
  end

  def d93_rebuild(model, inst, depth, overrides)
    p = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    p['depth'] = depth
    p['hardware_overrides'] = overrides
    e::CabinetBuilder.rebuild(model, inst, p)
  end

  def run_d93(model)
    inst = e::CabinetBuilder.build(model, d93_params(510.0))
    return ok('D93: vlozenie korpusu so zasuvkovym celom', false) unless inst

    auto = d93_slide(inst)
    ok("D93: automat vybral NL z hlbky (#{auto && auto['params'] && auto['params']['nominal_length']})",
       !auto.nil? && auto['source'] == 'rule' && auto['params']['nominal_length'].to_f > 0)
    owner = auto && auto['owner_part_key']
    lock = [{ 'owner_part_key' => owner, 'generic_type' => 'slide',
              'rule_id' => 'vysuvy-nl-podla-hlbky', 'nominal_length' => 420.0 }]

    # 1) zamok pri povodnej hlbke
    d93_rebuild(model, inst, 510.0, lock)
    s1 = d93_slide(inst)
    ok('D93: zamknuta NL 420 (source manual, automat ostal v rule_nominal_length)',
       !s1.nil? && (s1['params']['nominal_length'].to_f - 420.0).abs < 0.01 &&
       s1['source'] == 'manual' && s1['rule_nominal_length'].to_f > 420.0)

    # 2) zmena hlbky skrinky — zamok DRZI (automat by dal ine cislo)
    d93_rebuild(model, inst, 660.0, lock)
    s2 = d93_slide(inst)
    ok("D93: po zmene hlbky 510->660 NL drzi na 420 (automat #{s2 && s2['rule_nominal_length']})",
       !s2.nil? && (s2['params']['nominal_length'].to_f - 420.0).abs < 0.01 &&
       s2['rule_nominal_length'].to_f > 420.0)
    ok('D93: override prezil prestavbu v configu korpusu',
       Array((e::Store.config(inst) || {})['hardware_overrides'])
         .any? { |o| (o['nominal_length'].to_f - 420.0).abs < 0.01 })

    # 3) hlbka POD minimom radu — polozka existuje LEN vdaka zamku (audit B1)
    d93_rebuild(model, inst, 240.0, lock)
    s3 = d93_slide(inst)
    ok('D93: pod minimom radu polozka VZNIKNE so zamkom (automat nevie = nil)',
       !s3.nil? && (s3['params']['nominal_length'].to_f - 420.0).abs < 0.01 &&
       s3.key?('rule_nominal_length') && s3['rule_nominal_length'].nil?)
    ok('D93: pod minimom radu ORANGE hardware_manual_no_fit (nie hardware_no_fit)',
       d93_warn?(inst, 'hardware_manual_no_fit') && !d93_warn?(inst, 'hardware_no_fit'))

    # 4) odomknutie = automat (a pri malej hlbke povodne spravanie bez polozky)
    d93_rebuild(model, inst, 240.0, [])
    ok('D93: odomknutie pri malej hlbke — polozka zmizne, plati hardware_no_fit',
       d93_slide(inst).nil? && d93_warn?(inst, 'hardware_no_fit'))
    d93_rebuild(model, inst, 510.0, [])
    s4 = d93_slide(inst)
    ok("D93: odomknute pri hlbke 510 = automat (#{s4 && s4['params'] && s4['params']['nominal_length']})",
       !s4.nil? && s4['source'] == 'rule' && !s4.key?('rule_nominal_length') &&
       s4['params']['nominal_length'].to_f > 420.0)

    # 5) nezavislost poli (audit B2): rucny pocet + zamok naraz, zrusenie NL
    #    nesmie zmazat pocet.
    both = [{ 'owner_part_key' => owner, 'generic_type' => 'slide',
              'rule_id' => 'vysuvy-nl-podla-hlbky', 'nominal_length' => 420.0, 'quantity' => 3 }]
    d93_rebuild(model, inst, 510.0, both)
    s5 = d93_slide(inst)
    ok('D93: jeden zaznam nesie NL aj rucny pocet',
       !s5.nil? && s5['quantity'] == 3 && (s5['params']['nominal_length'].to_f - 420.0).abs < 0.01)
    only_qty = [{ 'owner_part_key' => owner, 'generic_type' => 'slide',
                  'rule_id' => 'vysuvy-nl-podla-hlbky', 'quantity' => 3 }]
    d93_rebuild(model, inst, 510.0, only_qty)
    s6 = d93_slide(inst)
    ok('D93: odomknutie NL nechalo rucny pocet na mieste',
       !s6.nil? && s6['quantity'] == 3 && s6['params']['nominal_length'].to_f > 420.0)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: D93 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    cleanup(model)
  end

  # --- D-88: farba ABS pasky na bocnych plochach dielcov ---------------------
  #
  # Overuje sa to, co Michal vidi v modeli: hnedá páska na bielej doske = HNEDÁ
  # bočná plôška, veľké plochy ostávajú vo farbe dosky. Kontroluje sa POLOHOU
  # plochy (nie cez PartFaces, aby test nebol tautologiou): plocha na minime osi
  # sirky = L1, na maxime = L2, na minime osi dlzky = W1 atd. — viď kontrakt
  # v core/part_faces.rb.
  # Bezi nad IZOLOVANYM katalogom (Materials.test_dir_override, vzor 2A-3).
  def d88_catalog_json
    sheet = lambda do |id, gid, decor, color, extra|
      { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => decor,
        'type' => 'DTDL', 'thickness' => 18.0, 'grain' => 'none',
        'sheet_size' => [2800.0, 2070.0], 'color' => color,
        'production_class' => 'sheet', 'group_id' => gid, 'structure' => 'SM' }.merge(extra)
    end
    edge = lambda do |id, gid, decor, color|
      { 'abs_id' => id, 'decor' => decor, 'thickness' => 1.0, 'width' => 23.0,
        'color' => color, 'group_id' => gid, 'structure' => 'SM' }
    end
    {
      'std' => 1, 'schema' => 2,
      'sheets' => [
        sheet.call('D88BIELA18', 'GRP-D88BIELA', 'BIELA', [246, 246, 244], {}),
        sheet.call('D88ZHODA18', 'GRP-D88ZHODA', 'ZHODA', [200, 190, 170], {}),
        sheet.call('D88NOABS18', 'GRP-D88NOABS', 'NOABS', [180, 180, 180], {})
      ],
      'edges' => [
        # kontrastna paska (hneda na bielej doske) — TOTO je D-88
        edge.call('D88E_HNEDA_23X10', 'GRP-D88BIELA', 'BIELA', [120, 80, 40]),
        # paska ROVNAKEJ farby ako doska — material sa vtedy vobec nevytvara
        edge.call('D88E_ZHODA_23X10', 'GRP-D88ZHODA', 'ZHODA', [200, 190, 170])
      ]
    }
  end

  def d88_part(inst, role)
    inst.definition.entities.grep(Sketchup::ComponentInstance)
        .find { |i| e::Store.kind(i) == 'part' && e::Store.get(i, 'role').to_s == role }
  end

  # Plocha na danej stene obalu definicie: axis 0=X 1=Y 2=Z, side :min/:max.
  def d88_face_on(pi, axis, side)
    b = pi.definition.bounds
    lo = [mm(b.min.x), mm(b.min.y), mm(b.min.z)]
    hi = [mm(b.max.x), mm(b.max.y), mm(b.max.z)]
    want = side == :min ? lo[axis] : hi[axis]
    pi.definition.entities.grep(Sketchup::Face).find do |f|
      c = f.bounds.center
      ([mm(c.x), mm(c.y), mm(c.z)][axis] - want).abs <= TOL
    end
  end

  def d88_face_mat(pi, axis, side)
    f = d88_face_on(pi, axis, side)
    m = f && f.material
    m ? m.name.to_s : nil
  end

  def d88_abs_name(abs_id)
    e::Materials.su_edge_material_name(abs_id)
  end

  def d88_params(extra = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'material_id' => 'D88BIELA18', 'front_material_id' => 'D88BIELA18',
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
      'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] } }.merge(extra)
  end

  def run_d88(model)
    tmp = File.join(Dir.tmpdir, "noxun_d88_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(d88_catalog_json))
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    hneda = d88_abs_name('D88E_HNEDA_23X10')
    begin
      ok('D-88: override katalogu aktivny (kontrastna paska v katalogu)',
         !e::Materials.edge('D88E_HNEDA_23X10').nil? &&
         e::Materials.edge_color_of('D88E_HNEDA_23X10') == [120, 80, 40])

      inst = e::CabinetBuilder.build(model, d88_params)
      return ok('D-88: vlozenie korpusu', false) unless inst

      # BOK: osi UPRIGHT (dlzka Z, sirka Y, hrubka X) -> L1 = plocha na Y minime.
      side = d88_part(inst, 'side_left')
      scfg = e::Store.config(side) || {}
      ok("D-88: bok ma pravidlovu pasku na L1 (#{(scfg['edges'] || {})['L1']})",
         (scfg['edges'] || {})['L1'] == 'D88E_HNEDA_23X10')
      ok('D-88: bok — predna ploska (Y min) nesie material PASKY',
         d88_face_mat(side, 1, :min) == hneda)
      ok('D-88: bok — zadna ploska (Y max) bez pasky ostava bez materialu',
         d88_face_mat(side, 1, :max).nil?)
      ok('D-88: bok — velke dekorove plochy (X min/max) ostavaju bez materialu (dedia dosku)',
         d88_face_mat(side, 0, :min).nil? && d88_face_mat(side, 0, :max).nil?)
      ok('D-88: bok — dolna/horna ploska (Z) bez pravidla ostava bez materialu',
         d88_face_mat(side, 2, :min).nil? && d88_face_mat(side, 2, :max).nil?)

      # CELO: osi FRONT (dlzka Z, sirka X, hrubka Y) -> vsetky 4 bocne plosky.
      front = d88_part(inst, 'front_door')
      ok('D-88: celo ma pasku na vsetkych 4 bocnych ploskach',
         [[0, :min], [0, :max], [2, :min], [2, :max]].all? { |a, s| d88_face_mat(front, a, s) == hneda })
      ok('D-88: celo — velke plochy (Y min/max) ostavaju bez materialu',
         d88_face_mat(front, 1, :min).nil? && d88_face_mat(front, 1, :max).nil?)

      # POLICA: osi LYING (dlzka X, sirka Y) -> L1 = Y minimum (predna hrana).
      shelf = d88_part(inst, 'shelf')
      ok('D-88: polica — predna ploska (Y min) nesie pasku, ostatne nie',
         d88_face_mat(shelf, 1, :min) == hneda && d88_face_mat(shelf, 1, :max).nil? &&
         d88_face_mat(shelf, 0, :min).nil? && d88_face_mat(shelf, 2, :min).nil?)

      # CHRBAT: pravidlo prazdne -> ziadna farebna ploska.
      back = d88_part(inst, 'back')
      ok('D-88: chrbat (pravidlo bez ABS) nema ziadnu zafarbenu plosku',
         back.nil? || back.definition.entities.grep(Sketchup::Face).none? { |f| f.material })

      # OVERRIDE: rucne olepenie zadnej hrany police -> po rebuilde je zafarbena.
      params = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      pkey = e::Store.get(shelf, 'part_key').to_s
      params['part_overrides'] = { pkey => { 'edges' => { 'L2' => 'D88E_HNEDA_23X10' } } }
      e::CabinetBuilder.rebuild(model, inst, params)
      shelf2 = d88_part(inst, 'shelf')
      ok('D-88: rucny override L2 sa po rebuilde prejavi na zadnej plosky police',
         d88_face_mat(shelf2, 1, :max) == hneda)
      Sketchup.undo
      shelf3 = d88_part(inst, 'shelf')
      ok('D-88: 1x undo vrati zafarbenie do povodneho stavu (zadna ploska cista)',
         d88_face_mat(shelf3, 1, :max).nil? && d88_face_mat(shelf3, 1, :min) == hneda)

      # VEDOME „bez ABS" na prednej hrane -> ploska sa vrati na farbu dosky.
      params2 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      params2['part_overrides'] = { pkey => { 'edges' => { 'L1' => nil } } }
      e::CabinetBuilder.rebuild(model, inst, params2)
      shelf4 = d88_part(inst, 'shelf')
      ok('D-88: vedome „bez ABS" necha plosku vo farbe dosky (bez materialu)',
         d88_face_mat(shelf4, 1, :min).nil?)

      # PASKA ROVNAKEJ FARBY ako doska: ziadny material sa netvori (cista kniznica).
      inst2 = e::CabinetBuilder.build(model, d88_params('width' => 500.0,
                                                        'material_id' => 'D88ZHODA18',
                                                        'front_material_id' => 'D88ZHODA18'))
      side2 = d88_part(inst2, 'side_left')
      ok('D-88: paska rovnakej farby ako doska plosku nefarbi (ziadny zbytocny material)',
         d88_face_mat(side2, 1, :min).nil? &&
         model.materials[d88_abs_name('D88E_ZHODA_23X10')].nil?)

      # SAMOSTATNA DOSKA: osi LYING; pravidlo free_panel = L1 (pozdlzna).
      board = e::BoardBuilder.build(model, { 'material_id' => 'D88BIELA18',
                                             'length' => 800.0, 'width' => 400.0 })
      bcfg = e::Store.config(board) || {}
      ok("D-88: doska ma pravidlovu pasku na L1 (#{(bcfg['edges'] || {})['L1']})",
         (bcfg['edges'] || {})['L1'] == 'D88E_HNEDA_23X10')
      ok('D-88: doska — ploska na Y minime nesie pasku, velke plochy (Z) nie',
         d88_face_mat(board, 1, :min) == hneda &&
         d88_face_mat(board, 2, :min).nil? && d88_face_mat(board, 2, :max).nil?)
      # rebuild dosky (zmena rozmeru) zafarbenie ZACHOVA a scale zamok drzi
      e::BoardBuilder.rebuild(model, board, { 'length' => 900.0 })
      ok('D-88: po rebuilde dosky ostava ploska zafarbena a rozmer sedi',
         d88_face_mat(board, 1, :min) == hneda &&
         (mm(board.definition.bounds.width) - 900.0).abs <= TOL)
      ok('D-88: doska ma po rebuilde stale scale masku (absorpcia nedotknuta)',
         board.definition.get_attribute('dynamic_attributes', 'scaletool').to_s == '120')

      # doska bez pouzitelnej pasky -> ziadna zafarbena ploska
      board2 = e::BoardBuilder.build(model, { 'material_id' => 'D88NOABS18',
                                              'length' => 300.0, 'width' => 200.0 })
      ok('D-88: doska bez pasky v skupine nema ziadnu zafarbenu plosku',
         board2.definition.entities.grep(Sketchup::Face).none? { |f| f.material })
    ensure
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      cleanup(model)
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
    ok('D-88: cleanup (override prec, model prazdny)',
       e::Materials.test_dir_override.nil? && cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: D-88 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  # --- D-104: kontrola hran (overlay „zvyrazni hrany bez olepu") -------------
  # Overlay lifecycle sa headless overit NEDA — tato sekcia dokazuje presne to,
  # co je na nom rizikove: zapnutie/vypnutie/znovuzapnutie, pravdivy pocet,
  # invalidacia po prestavbe, ziadny undo krok a ziadna stopa v modeli.

  # Katalog D-88 + KOMPAKT doska (nelepitelny typ) — D-88 sadu nechavame nedotknutu.
  def d104_catalog_json
    cat = d88_catalog_json
    cat['sheets'] = cat['sheets'] + [
      { 'material_id' => 'D104KOMPAKT12', 'manufacturer' => 'Egger', 'decor' => 'KOMPAKT',
        'type' => 'KOMPAKT', 'thickness' => 12.0, 'grain' => 'none',
        'sheet_size' => [4100.0, 1300.0], 'color' => [90, 90, 90],
        'production_class' => 'sheet', 'group_id' => 'GRP-D104KOMPAKT', 'structure' => 'SM' }
    ]
    cat
  end

  def d104_overlay_present?(model)
    return false unless model.respond_to?(:overlays)
    model.overlays.to_a.any? { |o| o.respond_to?(:overlay_id) && o.overlay_id.to_s == e::EdgeCheck::OVERLAY_ID }
  end

  def d104_state(model)
    e::EdgeCheck.ui_state(model)
  end

  def run_d104(model)
    unless e::EdgeCheck.available?(model)
      info('D-104: SketchUp bez Overlay API (SU 2022 a starsi) — sekcia preskocena')
      return
    end
    tmp = File.join(Dir.tmpdir, "noxun_d104_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(d104_catalog_json))
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    begin
      # 1) prazdny model = nula, nic zapnute
      cleanup(model)
      st = d104_state(model)
      ok('D-104: pred zapnutim je zvyraznenie vypnute a bez poctu',
         st['available'] == true && st['active'] == false && st['count'].nil?)

      inst = e::CabinetBuilder.build(model, d88_params)
      return ok('D-104: vlozenie korpusu', false) unless inst

      # 2) zapnutie nad ciston skrinkou — vsetko olepene podla pravidla
      st = e::EdgeCheck.toggle(model)
      ok('D-104: po zapnuti je overlay zaregistrovany v modeli',
         st['active'] == true && d104_overlay_present?(model))
      ok("D-104: cista skrinka nema hrany bez olepu (count #{st['count']}, unresolved #{st['unresolved']})",
         st['count'].to_i.zero? && st['unresolved'].to_i.zero?)

      # 3) vedome zrusena paska na prednej hrane police -> presne 1 hrana
      shelf = d88_part(inst, 'shelf')
      pkey = e::Store.get(shelf, 'part_key').to_s
      params = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      params['part_overrides'] = { pkey => { 'edges' => { 'L1' => nil } } }
      e::CabinetBuilder.rebuild(model, inst, params)
      e::EdgeCheck.refresh!(model)
      st = d104_state(model)
      ok("D-104: po prestavbe (polica bez pasky) hlasi 1 hranu bez olepu (#{st['count']}, kreslene #{st['drawn']})",
         st['count'].to_i == 1 && st['drawn'].to_i == 1)

      # 4) ziadny undo krok: posledna transakcia je PRESTAVBA, nie zapnutie
      Sketchup.undo
      shelf_back = d88_part(inst, 'shelf')
      back_cfg = shelf_back ? (e::Store.config(shelf_back) || {}) : {}
      ok('D-104: 1x undo vrati prestavbu (zvyraznenie nie je undo krok)',
         (back_cfg['edges'] || {})['L1'].to_s == 'D88E_HNEDA_23X10')
      e::EdgeCheck.refresh!(model)
      ok('D-104: po undo je pocet zase nulovy', d104_state(model)['count'].to_i.zero?)

      # 5) doska s viac kusmi: 1 ploska, ale pocet hovori o KUSOCH
      board = e::BoardBuilder.build(model, { 'material_id' => 'D88NOABS18', 'length' => 800.0,
                                             'width' => 400.0, 'quantity' => 3 })
      e::EdgeCheck.refresh!(model)
      st = d104_state(model)
      ok("D-104: doska 3 ks bez pouzitelnej pasky = 3 hrany, 1 ploska, priznak multi (#{st.inspect})",
         board && st['count'].to_i == 3 && st['drawn'].to_i == 1 && st['multi'].to_i == 1)

      # 6) nelepitelny material sa nezvyrazni ani ked pravidlo pasku ziada
      board.erase! if board && board.valid?
      kompakt = e::BoardBuilder.build(model, { 'material_id' => 'D104KOMPAKT12', 'length' => 600.0,
                                               'width' => 300.0 })
      e::EdgeCheck.refresh!(model)
      ok('D-104: KOMPAKT doska nema ziadnu zvyraznenu hranu',
         kompakt && d104_state(model)['count'].to_i.zero?)
      kompakt.erase! if kompakt && kompakt.valid?

      # 7) kopia skrinky PRED dedup tickom: obe kopie sa kreslia (identita vyskytu,
      #    nie persistent_id vnoreneho dielca)
      params2 = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      params2['part_overrides'] = { pkey => { 'edges' => { 'L1' => nil } } }
      e::CabinetBuilder.rebuild(model, inst, params2)
      copy = nil
      e::ScaleWatch.guard do
        model.start_operation('SU-TEST kopia', true)
        tr = inst.transformation * Geom::Transformation.translation(e::Units.vector(1000, 0, 0))
        copy = model.entities.add_instance(inst.definition, tr)
        # Ctrl+C/V nesie atributy INSTANCIE — bez nich by kopia nebola NOXUN korpus.
        %w[std kind id cabinet_id template_id role part_key_schema manufactured
           production_class config].each do |k|
          v = e::Store.get(inst, k)
          copy.set_attribute('NOXUN', k, v) unless v.nil?
        end
        model.commit_operation
      end
      e::EdgeCheck.refresh!(model)
      st = d104_state(model)
      ok("D-104: kopia skrinky pred dedup tickom sa zvyrazni tiez (#{st['drawn']} plosky)",
         copy && st['drawn'].to_i == 2 && st['count'].to_i == 2)
      copy.erase! if copy && copy.valid?

      # 8) vypnutie: overlay prec, ziadne cisla
      st = e::EdgeCheck.toggle(model)
      ok('D-104: po vypnuti nie je overlay v modeli a stav je cisty',
         st['active'] == false && st['count'].nil? && !d104_overlay_present?(model))

      # 9) ON -> OFF -> ON v tom istom modeli (odstraneny Overlay je navzdy neplatny)
      st = e::EdgeCheck.toggle(model)
      ok('D-104: opatovne zapnutie v tom istom modeli funguje (nova instancia overlayu)',
         st['active'] == true && d104_overlay_present?(model) && st['count'].to_i == 1)

      # 9b) Codex #152 P2: zmena KATALOGU nie je modelova transakcia — invalidate!
      #     musi stacit na cerstvy pocet uz pri najblizsom stave pre okno.
      e::EdgeCheck.invalidate!
      dirty_before = e::EdgeCheck.instance_variable_get(:@dirty)
      st = d104_state(model)
      ok('D-104: invalidate! (zmena katalogu) sa prepocita bez modelovej transakcie',
         dirty_before == true && e::EdgeCheck.instance_variable_get(:@dirty) == false &&
         st['count'].to_i == 1)

      # 9c) Codex #152 P2: nativne vypnutie v paneli Overlays sa musi hlasit ako VYPNUTE
      ov = e::EdgeCheck.instance_variable_get(:@overlay)
      if ov.respond_to?(:enabled=)
        ov.enabled = false
        ok('D-104: nativne vypnuty overlay sa NEhlasi ako zapnuty',
           d104_state(model)['active'] == false)
        ov.enabled = true
        ok('D-104: po nativnom zapnuti sa hlasi zase zapnuty (a pocet sedi)',
           d104_state(model)['active'] == true && d104_state(model)['count'].to_i == 1)
      else
        info('D-104: Sketchup::Overlay#enabled= nie je k dispozicii — nativny toggle netestovany')
      end

      # 10) kreslenie nespadne a obal kresby nie je prazdny
      begin
        e::EdgeCheck.draw(model.active_view)
        drawn_ok = true
      rescue StandardError => ex
        drawn_ok = false
        log_line("INFO: D-104 draw vynimka: #{ex.class}: #{ex.message}")
      end
      bb = e::EdgeCheck.extents(model)
      ok('D-104: kreslenie prebehne a obal kresby (getExtents) je platny',
         drawn_ok && bb.is_a?(Geom::BoundingBox) && bb.valid?)

      e::EdgeCheck.disable!
      cleanup(model)
      ok('D-104: cleanup — model prazdny, overlay odregistrovany',
         cabinets(model).empty? && boards(model).empty? && !d104_overlay_present?(model))
    ensure
      begin
        e::EdgeCheck.disable!
      rescue StandardError
        nil
      end
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
  rescue StandardError => ex
    log_line("FAIL: D-104 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    begin
      e::EdgeCheck.disable!
    rescue StandardError
      nil
    end
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  # --- D-105: prepinace kontroly hran (tri stavy + filter podla vyberu) ------
  # Headless sada overuje CISTE rozhodnutie (klasifikacia, filter, prepinace).
  # TU sa dokazuje to, co sa inak dokazat neda: ze prepnutie prepinaca ani zmena
  # VYBERU nespusti novy sken, ze zmena vyberu NEMENI MODEL a nerobi undo krok
  # (lekcia D-103), ze KOMPAKT nesvieti oranzovo a ze obal kresby drzi vsetky tri
  # stavy aj ked su vypnute (Codex audit FIX 6).

  def d105_counts(model)
    (e::EdgeCheck.ui_state(model)['counts'] || {})
  end

  def d105_cache_id
    c = e::EdgeCheck.instance_variable_get(:@cache)
    c.nil? ? nil : c.object_id
  end

  def d105_extents_key(model)
    bb = e::EdgeCheck.extents(model)
    [bb.min.to_a.map { |v| v.round(6) }, bb.max.to_a.map { |v| v.round(6) }]
  end

  # Odtlacok MODELU (nie vyberu): kolko entit, ake objekty a s akymi datami.
  # Zmena vyberu ho NESMIE pohnut ani o bit.
  def d105_fingerprint(model)
    rows = model.entities.grep(Sketchup::ComponentInstance).map do |i|
      [e::Store.kind(i).to_s, i.persistent_id,
       (e::Store.get(i, 'cabinet_id') || e::Store.get(i, 'id')).to_s,
       i.definition.entities.length, (e::Store.config(i) || {}).to_json]
    end
    [model.entities.length, model.definitions.length, rows.sort_by(&:to_s)].to_json
  end

  def d105_reset_options
    e::EdgeCheck::DEFAULT_OPTIONS.each { |k, v| e::EdgeCheck.set_option(k, v) }
  end

  def run_d105(model)
    unless e::EdgeCheck.available?(model)
      info('D-105: SketchUp bez Overlay API (SU 2022 a starsi) — sekcia preskocena')
      return
    end
    tmp = File.join(Dir.tmpdir, "noxun_d105_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(d104_catalog_json))
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    begin
      cleanup(model)
      d105_reset_options
      inst = e::CabinetBuilder.build(model, d88_params)
      return ok('D-105: vlozenie korpusu', false) unless inst

      e::EdgeCheck.enable!(model)
      # Baza sa meria BEZ filtra vyberu — „len vybrane" ma vlastnu sekciu nizsie
      # (s filtrom a prazdnym vyberom je zelena spravne 0 a nedalo by sa nic porovnat).
      e::EdgeCheck.set_option('taped_selected_only', false)
      base = d105_counts(model)
      ok("D-105: cista skrinka — 0 cervenych, ale oranzove aj zelene hrany existuju (#{base.inspect})",
         base['missing'].to_i.zero? && base['extra'].to_i.positive? && base['taped'].to_i.positive?)

      # 1) POCTY nezavisia od prepinacov zobrazenia (cislo vedla prepinaca musi
      #    byt pravdive este predtym, nez ho pouzivatel zapne)
      cache_before = d105_cache_id
      e::EdgeCheck.set_option('show_extra', true)
      e::EdgeCheck.set_option('show_taped', true)
      all_on = d105_counts(model)
      ok("D-105: pocty su rovnake pri zapnutych aj vypnutych stavoch (#{all_on.inspect})",
         all_on == base)
      ok('D-105: prepnutie prepinaca NESPUSTA novy sken (ta ista cache)',
         !cache_before.nil? && d105_cache_id == cache_before)
      st = e::EdgeCheck.ui_state(model)
      ok("D-105: tri stavy naraz sa aj kreslia (drawn #{st['drawn']})",
         st['drawn'].to_i >= base.values.map(&:to_i).sum - st['unresolved'].to_i)

      # 2) obal kresby drzi VSETKY tri stavy aj ked su vypnute (Codex FIX 6)
      ext_all = d105_extents_key(model)
      e::EdgeCheck.set_option('show_extra', false)
      e::EdgeCheck.set_option('show_taped', false)
      ok('D-105: obal kresby (getExtents) sa vypnutim stavov NEZMENSI',
         d105_extents_key(model) == ext_all)
      e::EdgeCheck.set_option('show_extra', true)
      e::EdgeCheck.set_option('show_taped', true)

      # 3) KOMPAKT (nelepitelny) nesmie svietit ANI oranzovo
      kompakt = e::BoardBuilder.build(model, { 'material_id' => 'D104KOMPAKT12',
                                               'length' => 600.0, 'width' => 300.0 })
      e::EdgeCheck.refresh!(model)
      ok('D-105: KOMPAKT doska nepridala ziadnu hranu do ziadneho stavu (ani oranzovu)',
         kompakt && d105_counts(model) == base)
      kompakt.erase! if kompakt && kompakt.valid?
      e::EdgeCheck.refresh!(model)

      # 4) „len vybrane" patri VYHRADNE zelenej
      board = e::BoardBuilder.build(model, { 'material_id' => 'D88BIELA18',
                                             'length' => 800.0, 'width' => 400.0 })
      e::EdgeCheck.refresh!(model)
      with_board = d105_counts(model)
      e::EdgeCheck.set_option('taped_selected_only', true)
      model.selection.clear
      empty = e::EdgeCheck.ui_state(model)
      ok("D-105: prazdny vyber — zelena je 0, cervena a oranzova ostavaju (#{empty['counts'].inspect})",
         empty['counts']['taped'].to_i.zero? && empty['selection_empty'] == true &&
         empty['counts']['extra'] == with_board['extra'] &&
         empty['counts']['missing'] == with_board['missing'])

      cache_sel = d105_cache_id
      model.selection.add(inst)
      only_cab = d105_counts(model)
      ok("D-105: oznaceny korpus rozsvieti zelenu len na nom (#{only_cab['taped']} z #{with_board['taped']})",
         only_cab['taped'].to_i.positive? && only_cab['taped'].to_i < with_board['taped'].to_i)
      ok('D-105: zmena vyberu NESPUSTA novy sken (prepocita sa len filter)',
         d105_cache_id == cache_sel)

      model.selection.add(board)
      ok('D-105: VIAC oznacenych objektov naraz (korpus + doska) = zelena na oboch',
         d105_counts(model)['taped'].to_i == with_board['taped'].to_i)
      e::EdgeCheck.set_option('taped_selected_only', false) # spat na porovnatelnu bazu

      # 5) DOKAZ: zmena vyberu nemeni model a nie je undo krok
      fp = d105_fingerprint(model)
      3.times do
        model.selection.clear
        model.selection.add(inst)
        model.selection.add(board)
      end
      model.selection.clear
      ok('D-105: seria zmien vyberu NEZMENILA model (odtlacok sedi)',
         d105_fingerprint(model) == fp)
      Sketchup.undo
      ok('D-105: 1x undo vratil VLOZENIE DOSKY — zmeny vyberu nevyrobili undo krok',
         boards(model).empty?)
      e::EdgeCheck.refresh!(model)
      ok('D-105: po undo sedia pocty zase so stavom pred doskou', d105_counts(model) == base)

      # 6) prestavba pri zapnutom zvyrazneni — cerstve pocty bez zasahu pouzivatela
      shelf = d88_part(inst, 'shelf')
      pkey = e::Store.get(shelf, 'part_key').to_s
      params = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
      params['part_overrides'] = { pkey => { 'edges' => { 'L1' => nil } } }
      e::CabinetBuilder.rebuild(model, inst, params)
      e::EdgeCheck.refresh!(model)
      after = d105_counts(model)
      ok("D-105: po prestavbe je 1 cervena navyse a 1 zelena menej (#{after.inspect})",
         after['missing'].to_i == base['missing'].to_i + 1 &&
         after['taped'].to_i == base['taped'].to_i - 1 &&
         after['extra'].to_i == base['extra'].to_i)
      Sketchup.undo

      # 7) nastavenie prezije vypnutie/zapnutie (zije v %APPDATA%, nie v modeli)
      e::EdgeCheck.set_option('show_extra', true)
      e::EdgeCheck.disable!
      st = e::EdgeCheck.ui_state(model)
      ok('D-105: po vypnuti su prepinace v stave, kde ostali (a bez poctov)',
         st['active'] == false && st['counts'].nil? && st['options']['show_extra'] == true)
      e::EdgeCheck.enable!(model)
      ok('D-105: po opatovnom zapnuti sedia prepinace aj pocty',
         e::EdgeCheck.ui_state(model)['options']['show_extra'] == true)
      ok('D-105: nastavenie zije v %APPDATA%, NIC z neho nejde do modelu',
         File.exist?(e::EdgeCheck.settings_path) &&
         (e::Store.config(inst) || {}).to_json.index('show_extra').nil?)

      # 8) prepnutie dokumentu = zvyraznenie zhasne (vratane odpojenia observerov)
      e::EdgeCheck.on_model_changed(Object.new)
      ok('D-105: prepnutie okna vypne zvyraznenie a odregistruje overlay',
         e::EdgeCheck.active?(model) == false && !d104_overlay_present?(model))
      model.selection.clear
      ok('D-105: po vypnuti uz zmena vyberu nic nerobi (stav ostava cisty)',
         e::EdgeCheck.ui_state(model)['counts'].nil?)

      cleanup(model)
      ok('D-105: cleanup — model prazdny, overlay odregistrovany',
         cabinets(model).empty? && boards(model).empty? && !d104_overlay_present?(model))
    ensure
      begin
        e::EdgeCheck.disable!
        d105_reset_options
        e::EdgeCheck.instance_variable_set(:@options, nil)
      rescue StandardError
        nil
      end
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
  rescue StandardError => ex
    log_line("FAIL: D-105 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    begin
      e::EdgeCheck.disable!
      e::EdgeCheck.instance_variable_set(:@options, nil)
    rescue StandardError
      nil
    end
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  # --- D-101: panel sa po Spat/Znova obnovi (PanelModelObserver lifecycle) ---
  # DOKAZOVA ZASADA (Codex audit D-101, FIX D): „neprisiel push" NEdokazuje
  # detach — handler sam konci na guardoch (@dialog, multi-model). Preto sa
  # ratau VSTUPY: do handlera (on_model_txn, este pred kazdym guardom), do
  # odlozeneho refreshu (flush_txn_refresh) a do push_selected vratane hodnoty
  # `dedup`. Bez pocitadiel by test presiel aj s uplne mrtvym observerom.

  # Panel bez otvoreneho HtmlDialogu je no-op — sonda musi dialog predstierat.
  class D101FakeDialog
    def visible?
      true
    end

    def execute_script(_script)
      nil
    end
  end

  # Model, ktoremu zlyha PRVY krok detachu (remove observera vyberu); druhy krok
  # (remove ModelObservera) sa deleguje na skutocny model. Dokazuje BLOCKER A:
  # zlyhanie prveho remove nesmie preskocit druhy.
  class D101FailingSelectionModel
    def initialize(real)
      @real = real
    end

    def selection
      raise 'SU-TEST: simulovane zlyhanie remove_observer(vyber)'
    end

    def remove_observer(obs)
      @real.remove_observer(obs)
    end
  end

  def d101_state
    { txn: 0, sel: 0, flush: 0, push: 0, in_flush: false, flush_pushes: 0, flush_dedups: [] }
  end

  # `flush_dedups` je najtvrdsi dokaz kontraktu: zbiera hodnotu `dedup` VYHRADNE
  # z pushov, ktore vznikli VNUTRI odlozeneho refreshu — pushy zo selection
  # eventov (dedup: true) sa doň nepocitaju.
  def d101_install_probe(st)
    e::Panel.singleton_class.class_eval do
      alias_method :nx_d101_txn, :on_model_txn
      alias_method :nx_d101_sel, :on_selection_changed
      alias_method :nx_d101_flush, :flush_txn_refresh
      alias_method :nx_d101_push, :push_selected
      define_method(:on_model_txn) do |model|
        st[:txn] += 1
        nx_d101_txn(model)
      end
      # Vstupy do sync vyberu — dokazuju, ze na modeli NEVISI observer vyberu
      # (rata sa PRED suspend guardom, takze ziadny guard vysledok neskresli).
      define_method(:on_selection_changed) do
        st[:sel] += 1
        nx_d101_sel
      end
      define_method(:flush_txn_refresh) do |model|
        st[:flush] += 1
        prev = st[:in_flush]
        st[:in_flush] = true
        begin
          nx_d101_flush(model)
        ensure
          st[:in_flush] = prev
        end
      end
      define_method(:push_selected) do |model, dedup: true|
        st[:push] += 1
        if st[:in_flush]
          st[:flush_pushes] += 1
          st[:flush_dedups] << dedup
        end
        nx_d101_push(model, dedup: dedup)
      end
    end
  end

  # Idempotentny teardown — bezi aj z FAIL cesty async walku.
  def d101_remove_probe
    sc = e::Panel.singleton_class
    return unless sc.method_defined?(:nx_d101_txn)

    sc.class_eval do
      alias_method :on_model_txn, :nx_d101_txn
      alias_method :on_selection_changed, :nx_d101_sel
      alias_method :flush_txn_refresh, :nx_d101_flush
      alias_method :push_selected, :nx_d101_push
      remove_method :nx_d101_txn
      remove_method :nx_d101_sel
      remove_method :nx_d101_flush
      remove_method :nx_d101_push
    end
  end

  def d101_reset(st)
    st[:txn] = 0
    st[:sel] = 0
    st[:flush] = 0
    st[:push] = 0
    st[:flush_pushes] = 0
    st[:flush_dedups] = []
  end

  def d101_width(inst)
    return nil unless inst && inst.valid?

    (e::Store.config(inst) || {})['width'].to_f
  end

  # send_action defenzivne: neznamy nazov akcie aj numericke ID mozu na danom
  # builde vratit false ALEBO hodit vynimku — vrstveny redo fallback nesmie
  # kvoli tomu zhodit cely scenar.
  def d101_send_action(action)
    Sketchup.send_action(action) ? true : false
  rescue StandardError => ex
    info("D101 REDO: send_action(#{action.inspect}) odmietnute (#{ex.class})")
    false
  end

  def d101_rebuild(model, inst, width)
    params = e::CabinetBuilder.config_to_params(e::Store.config(inst) || {})
    params['width'] = width
    e::CabinetBuilder.rebuild(model, inst, params)
  end

  # Vrati Panel do stavu spred sekcie. Idempotentne — bezi aj z FAIL cesty
  # async walku. Ak bol pri manualnom spusteni panel realne otvoreny, jeho
  # dialog aj observery sa vratia spat (runner nesmie zabit zivy Inspector).
  def d101_teardown(state)
    d101_remove_probe
    remove_js_recorder
    return unless state && state[:d101_active]

    state[:d101_active] = false
    # VZDY vynutit cisty detach nad REALNYM modelom — nezavisle od toho, ci bol
    # panel otvoreny. Failure-probe (simulovane zlyhanie prveho remove) necha
    # observer VYBERU visiet na modeli a @observer_model vynulovany; bez tohto
    # by dalsie sekcie bezali s kontaminovanym observerom (kazda zmena vyberu
    # by pytala dedup a menila model).
    begin
      e::Panel.instance_variable_set(:@observer_model, state[:d101_model] || Sketchup.active_model)
      e::Panel.detach_observer
    rescue StandardError
      nil
    end
    prev = state[:d101_prev_dialog]
    e::Panel.instance_variable_set(:@dialog, prev)
    e::Panel.attach_observer if prev
  rescue StandardError
    nil
  end

  # --- UI-B1: kostra Inspectora (rail + sektory) — SERVEROVA cast smoke testu --
  # Co sa da overit z Ruby: kontrakt payloadov, ktore rail a sektory riadia
  # (rezim vyberu + identita + stav ABS kontroly) a obe cesty krizika docasnej
  # polozky. Prepinanie kontextov je ciste JS a stravi ho sada
  # tests/js/test_uib1_kostra.js — TU sa strazi to, co JS nemoze: ze zmena
  # vyberu z panela NEMENI model a NEROBI undo krok.
  def run_uib1(model)
    cleanup(model)

    # 1) push_init nesie stav ABS kontroly pre ikonu v raile (pull pri otvoreni)
    rec = []
    install_js_recorder(rec)
    begin
      e::Panel.push_init
    ensure
      remove_js_recorder
    end
    init = rec.find { |s| s.include?('NX.init(') }
    ok('UI-B1: push_init nesie stav ABS kontroly pre rail (edge_check)',
       !init.nil? && init.include?('"edge_check"'))
    ok('UI-B1: push_init nesie identitu dokumentu (model_guid)',
       !init.nil? && init.include?('"model_guid"'))

    # 2) oznaceny KORPUS -> rezim cab (rail ma aktivne kontexty)
    # Vlastne parametre (ziadny testovaci katalog — materialy dedia z projektu).
    uib1 = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
             'thickness' => 18.0,
             'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
             'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] } }
    inst = e::CabinetBuilder.build(model, uib1)
    return ok('UI-B1: vlozenie korpusu', false) unless inst

    cid = e::Store.get(inst, 'cabinet_id').to_s
    model.selection.clear
    model.selection.add(inst)
    rec = []
    install_js_recorder(rec)
    begin
      e::Panel.push_selected(model, dedup: false)
    ensure
      remove_js_recorder
    end
    cab_push = rec.find { |s| s.include?('NX.loadSelected(') }
    ok('UI-B1: oznaceny korpus posiela loadSelected s identitou skrinky',
       !cab_push.nil? && cab_push.include?("\"cabinet_id\":\"#{cid}\"") &&
         cab_push.include?('"part_card":null'))

    # 3) oznaceny DIELEC -> rezim part (rail ukaze docasnu polozku, kontexty sivnu)
    shelf = d88_part(inst, 'shelf')
    if shelf
      begin
        model.active_path = [inst]
      rescue StandardError
        nil
      end
      model.selection.clear
      model.selection.add(shelf)
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.push_selected(model, dedup: false)
      ensure
        remove_js_recorder
      end
      part_push = rec.find { |s| s.include?('NX.loadSelected(') }
      ok('UI-B1: oznaceny dielec posiela part_card (identita docasnej polozky raily)',
         !part_push.nil? && part_push.include?('"part_card":{') && part_push.include?('"role_key"'))

      # Codex #168 P2 (3. kolo): panel OTVORENY nad uz oznacenym dielcom musi
      # dostat rovnaky obraz ako pri beznom pushi — inak by sa otvoril v rezime
      # skrinky (bez docasnej polozky raily a bez karty dielca).
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.push_init
      ensure
        remove_js_recorder
      end
      init2 = rec.find { |s| s.include?('NX.init(') }
      ok('UI-B1: push_init nad oznacenym dielcom nesie part_card aj model_guid',
         !init2.nil? && init2.include?('"part_card":{') && init2.include?('"model_guid"'))

      # 4) krizik pri DIELCI = existujuca cesta „spat na skrinku"
      before = model.entities.length
      # Codex #168 P2 (4. kolo): oneskoreny klik z INEHO dokumentu nesmie
      # prehodit vyber tu (ID skriniek sa naprie dokumentmi opakuju).
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_select_cabinet({ 'cabinet_id' => cid, 'model_guid' => 'CUDZI-GUID' }.to_json)
      ensure
        remove_js_recorder
      end
      ok('UI-B1: navrat na skrinku z INEHO dokumentu sa NEVYKONA (guard dokumentu)',
         model.selection.to_a.include?(shelf))

      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_select_cabinet({ 'cabinet_id' => cid,
                                         'model_guid' => e::Panel.model_guid(model) }.to_json)
      ensure
        remove_js_recorder
      end
      back = rec.find { |s| s.include?('NX.loadSelected(') }
      ok('UI-B1: krizik pri dielci vrati vyber na skrinku (bez karty dielca)',
         !back.nil? && back.include?('"part_card":null') &&
           model.selection.to_a.include?(inst))
      ok('UI-B1: navrat na skrinku NEMENI model (ziadna nova entita)',
         model.entities.length == before)
    else
      info('UI-B1: v skrinke nie je polica — cast s dielcom preskocena')
    end

    # 5) krizik pri DOSKE = vycistenie vyberu (bez zapisu do modelu, bez undo kroku)
    board = e::BoardBuilder.build(model, { 'length' => 800.0, 'width' => 600.0 })
    if board
      model.selection.clear
      model.selection.add(board)
      before = model.entities.length
      bid = e::Store.get(board, 'id').to_s
      # Codex #168 P2: identity guard — callback zo STAREJ dosky (medzitym sa
      # vyber zmenil) NESMIE zhodit novy vyber. Panel sa len obnovi.
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_clear_selection({ 'board_id' => 'BRD-NEEXISTUJE',
                                          'model_guid' => e::Panel.model_guid(model) }.to_json)
      ensure
        remove_js_recorder
      end
      ok('UI-B1: krizik STAREJ dosky vyber NEZHODI (identity guard)',
         model.selection.to_a.include?(board) &&
           rec.none? { |s| s.include?('NX.clearSelected(') })

      # Codex #168 P2 (2. kolo): ID dosky je jedinecne LEN v ramci modelu —
      # callback z INEHO dokumentu nesmie zhodit vyber tu, aj keby ID sedelo.
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_clear_selection({ 'board_id' => bid, 'model_guid' => 'CUDZI-GUID' }.to_json)
      ensure
        remove_js_recorder
      end
      ok('UI-B1: krizik z INEHO dokumentu vyber NEZHODI (guard dokumentu)',
         model.selection.to_a.include?(board) &&
           rec.none? { |s| s.include?('NX.clearSelected(') })

      # Codex #168 P2 (5. kolo): guard je PRISNY — aj CHYBAJUCA identita sa
      # odmieta (okno, ktoremu este nedosiel NX.init, nesmie cistit vyber).
      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_clear_selection({ 'board_id' => bid }.to_json)
      ensure
        remove_js_recorder
      end
      ok('UI-B1: krizik BEZ identity dokumentu vyber NEZHODI (prisny guard)',
         model.selection.to_a.include?(board) &&
           rec.none? { |s| s.include?('NX.clearSelected(') })

      rec = []
      install_js_recorder(rec)
      begin
        e::Panel.handle_clear_selection({ 'board_id' => bid,
                                          'model_guid' => e::Panel.model_guid(model) }.to_json)
      ensure
        remove_js_recorder
      end
      ok('UI-B1: krizik pri doske posiela clearSelected (vkladaci rezim)',
         rec.any? { |s| s.include?('NX.clearSelected(') })
      # Codex #168 P2 (3. kolo): aj prazdny vyber nesie identitu dokumentu —
      # bez nej by panel po prepnuti do dokumentu BEZ vyberu drzal stary guid
      # a ABS prepinac by kazdy klik odmietal ako nezhodu modelu.
      ok('UI-B1: clearSelected nesie identitu dokumentu',
         rec.any? { |s| s.include?("NX.clearSelected(\"") })
      ok('UI-B1: vycistenie vyberu NEMENI model (ziadna entita naviac ani menej)',
         model.entities.length == before && model.selection.empty?)
      # Jeden krok Spat musi zmazat DOSKU — keby vycistenie vyberu bolo vlastnou
      # operaciou, undo by najprv vratilo ju a doska by ostala v modeli.
      Sketchup.undo
      ok('UI-B1: 1x Spat zmaze dosku (vycistenie vyberu NIE JE undo krok)',
         boards(model).none? { |b| b.valid? && b == board })
    else
      info('UI-B1: dosku sa nepodarilo vlozit — cast s doskou preskocena')
    end

    # 6) ABS kontrola z raily: prepne EdgeCheck a NEVYTVORI undo krok
    if e::EdgeCheck.available?(model)
      was = e::EdgeCheck.active?(model)
      e::EdgeCheck.disable! if was
      marker = e::CabinetBuilder.build(model, uib1)
      # Guard dokumentu: klik z INEHO dokumentu nesmie zapnut overlay tu.
      e::Panel.handle_edge_toggle({ 'model_guid' => 'CUDZI-GUID' }.to_json)
      ok('UI-B1: ABS toggle z INEHO dokumentu zvyraznenie NEZAPNE (guard dokumentu)',
         e::EdgeCheck.active?(model) == false)
      # Codex #168 P2 (5. kolo): guard je PRISNY — chybajuca identita sa tiez odmieta
      # (okno, ktoremu este nedosiel NX.init, nesmie prepnut prave aktivny model).
      e::Panel.handle_edge_toggle(nil)
      ok('UI-B1: ABS toggle BEZ identity dokumentu sa odmietne (prisny guard)',
         e::EdgeCheck.active?(model) == false)

      e::Panel.handle_edge_toggle({ 'model_guid' => e::Panel.model_guid(model) }.to_json)
      ok('UI-B1: ABS toggle z panela ZAPOL zvyraznenie (rovnaka cesta ako toolbar)',
         e::EdgeCheck.active?(model) == true)
      # Undo musi vratit POSLEDNU MODELOVU operaciu (vlozenie markera), nie toggle.
      Sketchup.undo
      ok('UI-B1: 1x Spat po ABS toggle vrati vlozenie skrinky (toggle nie je undo krok)',
         marker.nil? || !marker.valid?)
      e::Panel.handle_edge_toggle({ 'model_guid' => e::Panel.model_guid(model) }.to_json)
      ok('UI-B1: opakovany klik zvyraznenie VYPOL', e::EdgeCheck.active?(model) == false)
    else
      info('UI-B1: SketchUp bez Overlay API — ABS cast preskocena')
    end

    cleanup(model)
  rescue StandardError => ex
    remove_js_recorder
    log_line("FAIL: UI-B1 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  end

  # --- UI-B2: kamera spodneho pasu nahladu (N7) ------------------------------
  # Jedina serverova cast davky. Overuje sa presne to, co je na nej rizikove:
  # zarovnanie pohladu je CISTE CITANIE — nesmie zmenit model, vyber ani
  # pridat krok Spat (lekcia D-103). Projekcie samotne su ciste JS (sada
  # tests/js/test_uib2_nahlad.js).
  def run_uib2(model)
    cleanup(model)

    cfg = { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0 }
    inst = e::CabinetBuilder.build(model, cfg)
    return ok('UI-B2: vlozenie skrinky pre kameru', false) unless inst

    cid = e::Store.get(inst, 'cabinet_id').to_s
    model.selection.clear
    model.selection.add(inst)
    before_ents = model.entities.length
    before_sel = model.selection.to_a.dup
    eye0 = model.active_view.camera.eye.clone

    # Guard dokumentu: klik z INEHO dokumentu pohlad TU nezarovna.
    e::Panel.handle_camera_focus({ 'cabinet_id' => cid, 'model_guid' => 'CUDZI-GUID' }.to_json)
    ok('UI-B2: kamera z INEHO dokumentu pohlad NEZAROVNA (guard dokumentu)',
       model.active_view.camera.eye == eye0)
    # Prisny guard: aj CHYBAJUCA identita sa odmieta (okno bez dobehnuteho NX.init).
    e::Panel.handle_camera_focus({ 'cabinet_id' => cid }.to_json)
    ok('UI-B2: kamera BEZ identity dokumentu pohlad NEZAROVNA (prisny guard)',
       model.active_view.camera.eye == eye0)
    # Codex #169 P2: ID, ktore nesedi s AKTUALNYM vyberom (medzitym sa zmenil),
    # sa odmieta — pohlad nesmie odskocit inam, nez kde pouzivatel je.
    e::Panel.handle_camera_focus({ 'cabinet_id' => 'CAB-NEEXISTUJE',
                                   'model_guid' => e::Panel.model_guid(model) }.to_json)
    ok('UI-B2: kamera na INU nez oznacenu skrinku pohlad NEMENI (test cerstvosti)',
       model.active_view.camera.eye == eye0)

    e::Panel.handle_camera_focus({ 'cabinet_id' => cid,
                                   'model_guid' => e::Panel.model_guid(model) }.to_json)
    ok('UI-B2: kamera zarovnala pohlad na skrinku (zmenil sa bod oka)',
       model.active_view.camera.eye != eye0)
    # Celny pohlad = oko PRED skrinkou (v zapornom Y od jej stredu), hore +Z.
    cam = model.active_view.camera
    center = inst.bounds.center
    ok('UI-B2: pohlad je CELNY (oko pred skrinkou, hore je Z)',
       cam.eye.y < center.y && (cam.eye.x - center.x).abs < 1.0 && cam.up.z > 0.9)
    ok('UI-B2: kamera NEMENI model (ziadna entita naviac ani menej)',
       model.entities.length == before_ents)
    ok('UI-B2: kamera NEMENI vyber', model.selection.to_a == before_sel)

    # Keby zarovnanie bolo vlastnou operaciou, 1x Spat by vratilo JU a skrinka
    # by ostala v modeli. Undo teda musi zmazat prave vlozenu skrinku.
    # (Test ide TU — poslednou modelovou operaciou je zatial vlozenie skrinky.)
    Sketchup.undo
    ok('UI-B2: 1x Spat zmaze skrinku (zarovnanie pohladu NIE JE undo krok)',
       inst.nil? || !inst.valid?)

    # Codex #169 P2: OTOCENA skrinka — celo uz nemieri na globalne -Y, takze
    # pevna os by ukazala bok. Smer musi vyjst z transformacie skrinky.
    rot = e::CabinetBuilder.build(model, cfg)
    if rot
      model.start_operation('SU-TEST rotacia skrinky', true)
      rot.transformation = rot.transformation *
                           Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
      model.commit_operation
      rid = e::Store.get(rot, 'cabinet_id').to_s
      model.selection.clear
      model.selection.add(rot)
      e::Panel.handle_camera_focus({ 'cabinet_id' => rid,
                                     'model_guid' => e::Panel.model_guid(model) }.to_json)
      cam2 = model.active_view.camera
      # Lokalne -Y otocenej skrinky ukazuje do globalneho +X (rotacia +90 okolo Z).
      fwd = rot.transformation.yaxis
      to_eye = cam2.eye - rot.bounds.center
      ok('UI-B2: otocena skrinka — oko stoji pred JEJ celom (smer z transformacie)',
         to_eye.dot(fwd) < 0 && cam2.up.z > 0.9)
    else
      info('UI-B2: druhu skrinku sa nepodarilo vlozit — rotacna cast preskocena')
    end

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-B2 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  end

  # UI-B3: klik na „Dielcov" v informacnom stlpci Zakladnych. Overuje presne to,
  # co sa da overit LEN v SketchUpe: ze oznacenie dielcov je CISTE CITANIE +
  # zmena vyberu — teda ziadna nova entita, ziadny novy krok Spat a spravny
  # pocet oznacenych dielcov. Guardy identity sa testuju rovnako ako pri kamere.
  def run_uib3(model)
    cleanup(model)

    cfg = { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0 }
    inst = e::CabinetBuilder.build(model, cfg)
    return ok('UI-B3: vlozenie skrinky pre vyber dielcov', false) unless inst

    cid = e::Store.get(inst, 'cabinet_id').to_s
    model.selection.clear
    model.selection.add(inst)
    before_ents = model.entities.length
    guid = e::Panel.model_guid(model)

    # Odvodene udaje informacneho stlpca — ciste citanie snapshotov.
    stats = e::Panel.cabinet_stats(inst)
    parts = e::Panel.manufactured_parts(inst)
    ok('UI-B3: informacny stlpec pozna pocet dielcov (rovnaky filter ako kusovnik)',
       stats['parts_count'].to_i.positive? && stats['parts_count'].to_i >= parts.size)
    ok('UI-B3: informacny stlpec pozna plochu materialu (m2 > 0)',
       stats['parts_area_m2'].to_f > 0.0)

    # Guard dokumentu aj cerstvosti vyberu — klik z ineho dokumentu / na inu
    # skrinku vyber NEMENI (asynchronny callback HtmlDialogu).
    e::Panel.handle_select_parts({ 'cabinet_id' => cid, 'model_guid' => 'CUDZI-GUID' }.to_json)
    ok('UI-B3: vyber dielcov z INEHO dokumentu sa NEVYKONA (guard dokumentu)',
       model.selection.to_a == [inst])
    e::Panel.handle_select_parts({ 'cabinet_id' => 'CAB-NEEXISTUJE', 'model_guid' => guid }.to_json)
    ok('UI-B3: vyber dielcov pre INU nez oznacenu skrinku sa NEVYKONA',
       model.selection.to_a == [inst])

    e::Panel.handle_select_parts({ 'cabinet_id' => cid, 'model_guid' => guid }.to_json)
    sel = model.selection.to_a
    ok('UI-B3: oznacili sa VYROBNE dielce skrinky (a nie skrinka sama)',
       !sel.empty? && sel.size == parts.size && sel.none? { |x| x == inst })
    ok('UI-B3: oznacenie dielcov NEMENI model (ziadna entita naviac ani menej)',
       model.entities.length == before_ents)

    # Keby oznacenie bolo vlastnou operaciou, 1x Spat by vratilo JU a skrinka by
    # v modeli ostala. Poslednou modelovou operaciou je zatial vlozenie skrinky.
    Sketchup.undo
    ok('UI-B3: 1x Spat zmaze skrinku (oznacenie dielcov NIE JE undo krok)',
       inst.nil? || !inst.valid?)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-B3 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  end

  # === UI-C4: KOVANIE — oznacenie VLASTNIKA polozky v modeli =================
  # Overuje presne to, co headless sada NEVIE: ci klik na hlavicku boxu (a na
  # znacku v nahlade) naozaj oznaci SPRAVNE dielce zivej skrinky, ci pritom
  # model NEMENI a ci nevznika krok Spat. Guardy identity sa skusaju na tom
  # istom modeli, lebo callback HtmlDialogu je asynchronny.
  def run_uic4(model)
    cleanup(model)

    cfg = { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0,
            'fronts' => { 'items' => [
              { 'id' => 'F1', 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 200.0 },
              { 'id' => 'F2', 'type' => 'door', 'mode' => 'auto' }
            ] } }
    inst = e::CabinetBuilder.build(model, cfg)
    return ok('UI-C4: vlozenie skrinky s celami pre vyber vlastnika', false) unless inst

    cid = e::Store.get(inst, 'cabinet_id').to_s
    guid = e::Panel.model_guid(model)
    model.selection.clear
    model.selection.add(inst)
    before_ents = model.entities.length

    hw = Array((e::Store.config(inst) || {})['hardware'])
    owners = hw.map { |h| h['owner_part_key'].to_s }.reject(&:empty?).uniq
    front_keys = owners.select { |k| k.start_with?('front:') }
    ok('UI-C4: kovanie skrinky ma vlastnikov na celach (podklad boxov)', !front_keys.empty?)

    # 1) guardy identity — cudzi dokument ani ina skrinka vyber NEMENIA
    e::Panel.handle_select_hw_owner({ 'model_guid' => 'CUDZI-GUID', 'cabinet_id' => cid,
                                      'part_keys' => front_keys }.to_json)
    ok('UI-C4: klik z INEHO dokumentu vyber NEMENI (guard dokumentu)',
       model.selection.to_a == [inst])
    e::Panel.handle_select_hw_owner({ 'model_guid' => guid, 'cabinet_id' => 'CAB-NEEXISTUJE',
                                      'part_keys' => front_keys }.to_json)
    ok('UI-C4: klik pre INU nez oznacenu skrinku vyber NEMENI',
       model.selection.to_a == [inst])

    # 2) box CELA -> oznacia sa PRESNE jeho dielce (a nie skrinka sama)
    one = [front_keys.first]
    e::Panel.handle_select_hw_owner({ 'model_guid' => guid, 'cabinet_id' => cid,
                                      'part_keys' => one }.to_json)
    sel = model.selection.to_a
    keys_sel = sel.map { |x| e::Store.get(x, 'part_key').to_s }
    ok("UI-C4: box vlastnika oznacil jeho dielec (#{one.first})",
       !sel.empty? && sel.none? { |x| x == inst } && keys_sel.uniq == one)

    # 3) neexistujuci kluc vyber NEZHODI (radsej nic nez prazdny vyber)
    e::Panel.handle_select_hw_owner({ 'model_guid' => guid, 'cabinet_id' => cid,
                                      'part_keys' => ['front:NEEXISTUJE/wing:single'] }.to_json)
    ok('UI-C4: neznamy part_key vyber NEZHODI (prizna sa hlaskou)',
       model.selection.to_a.map { |x| e::Store.get(x, 'part_key').to_s }.uniq == one)

    # 3b) Codex #179 P2: CIASTOCNE najdeny box — oznacia sa najdene dielce
    # (dve kridla z troch su stale to, co pouzivatel chcel), ale chybajuce sa
    # v statuse POMENUJU. Tu sa overuje aspon to, ze sa vyber neroztiahne na
    # nic navyse a nezhodi.
    e::Panel.handle_select_hw_owner({ 'model_guid' => guid, 'cabinet_id' => cid,
                                      'part_keys' => one + ['front:NEEXISTUJE/wing:single'] }.to_json)
    ok('UI-C4: ciastocne najdeny box oznaci LEN existujuce dielce',
       model.selection.to_a.map { |x| e::Store.get(x, 'part_key').to_s }.uniq == one)

    # 4) box SKRINKA (prazdne kluce) -> oznaci sa cely korpus
    e::Panel.handle_select_hw_owner({ 'model_guid' => guid, 'cabinet_id' => cid,
                                      'part_keys' => [] }.to_json)
    ok('UI-C4: box „Skrinka" oznaci cely korpus', model.selection.to_a == [inst])

    ok('UI-C4: oznacenie vlastnika NEMENI model (ziadna entita naviac ani menej)',
       model.entities.length == before_ents)

    # Keby oznacenie bolo vlastnou operaciou, 1x Spat by vratilo JU a skrinka by
    # v modeli ostala. Poslednou modelovou operaciou je vlozenie skrinky.
    Sketchup.undo
    ok('UI-C4: 1x Spat zmaze skrinku (oznacenie vlastnika NIE JE undo krok)',
       inst.nil? || !inst.valid?)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-C4 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  end

  # === UI-C2: ZONY ===========================================================
  # Overuje presne to, co headless sada NEVIE: ci sa zmena stromu naozaj
  # PRESTAVA v modeli (priecky, police), ci je to JEDEN krok Spat, ci vyber po
  # operacii ostava na skrinke a — hlavne — ci ODMIETNUTA zmena model NEDOTKNE.
  #
  # Najdrahsia pasca tejto davky: poskodene `zone_id` doteraz padlo na KOREN
  # (`zone_path` vracala [1]), takze „Vycistit zonu" vedelo zmazat cele vnutro
  # skrinky. Tu sa to overuje na zivom modeli.

  # Kolko dielcov s danou rolou ma skrinka (priecky, police).
  def zone_role_count(cab, role)
    return 0 unless cab && cab.valid?

    # `role` je TOP-LEVEL atribut dielca (Store.write), nie polozka configu.
    cab.definition.entities.grep(Sketchup::ComponentInstance).count do |x|
      e::Store.get(x, 'role').to_s == role
    end
  end

  def zone_tree_of(cab)
    (e::Store.config(cab) || {})['zone_tree'] || {}
  end

  def run_uic2(model)
    cleanup(model)

    cfg = { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0 }
    cab = e::CabinetBuilder.build(model, cfg)
    return ok('UI-C2: vlozenie skrinky pre zonove testy', false) unless cab

    cid = e::Store.get(cab, 'cabinet_id').to_s
    guid = e::Panel.model_guid(model)
    root = "#{cid}-Z1"
    e::Panel.select_only(model, cab)

    # --- 1) GUARD DOKUMENTU: cudzi guid nesmie prestavat NIC ------------------
    before = zone_role_count(cab, 'divider_v')
    e::Panel.handle_split_zone({ 'zone_id' => root, 'axis' => 'v', 'count' => 2,
                                 'model_guid' => 'CUDZI-GUID', 'cabinet_id' => cid }.to_json)
    ok('UI-C2: delenie z INEHO dokumentu sa NEVYKONA (guard identity)',
       zone_role_count(cab, 'divider_v') == before && zone_tree_of(cab)['split'].nil?)

    # --- 2) POSKODENE zone_id: ziadny fallback na koren ----------------------
    e::Panel.handle_split_zone({ 'zone_id' => "#{cid}-ZXY", 'axis' => 'v', 'count' => 2,
                                 'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    ok('UI-C2: poskodene zone_id sa ODMIETNE (nepadne na koren)',
       zone_tree_of(cab)['split'].nil?)

    # --- 3) DELENIE: prestavba, jeden undo krok, vyber ostava ----------------
    # Ghost zon zije PRIAMO v `model.entities` (zones.rb), takze holy pocet entit
    # sa delenim legitimne meni — invariantom je pocet NOXUN objektov.
    cabs_before = cabinets(model).length
    e::Panel.handle_split_zone({ 'zone_id' => root, 'axis' => 'v', 'count' => 2,
                                 'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: delenie na 2 stlpce postavilo ZVISLU priecku',
       zone_role_count(cab, 'divider_v') == 1)
    ok('UI-C2: strom skrinky nesie delenie (v ×2)',
       zone_tree_of(cab)['split'].is_a?(Hash) &&
       zone_tree_of(cab)['split']['axis'] == 'v' && zone_tree_of(cab)['split']['count'].to_i == 2)
    ok('UI-C2: po deleni ostava oznacena SKRINKA (nie zmazany ghost)',
       model.selection.to_a == [cab])
    ok('UI-C2: delenie nevyrobilo ziadny novy NOXUN objekt na najvyssej urovni',
       cabinets(model).length == cabs_before && boards(model).empty?)

    # --- 4) DRUHE delenie tej istej zony sa ODMIETNE (jedina cesta = Vycistit)
    e::Panel.handle_split_zone({ 'zone_id' => root, 'axis' => 'h', 'count' => 3,
                                 'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: opakovane delenie uz delenej zony sa ODMIETNE (podstrom prezije)',
       zone_tree_of(cab)['split']['axis'] == 'v' && zone_role_count(cab, 'divider_h').zero?)

    # --- 5) POLICE 0–6 na LISTOVEJ zone, odmietnutie na delenej --------------
    e::Panel.handle_set_zone_shelves({ 'zone_id' => root, 'count' => 3,
                                       'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: police na DELENEJ zone sa odmietnu (podstrom sa nezmaze)',
       zone_tree_of(cab)['split'].is_a?(Hash) && zone_role_count(cab, 'shelf').zero?)

    e::Panel.handle_set_zone_shelves({ 'zone_id' => "#{cid}-Z1.1", 'count' => 6,
                                       'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: 6 polic (novy strop) sa naozaj postavilo v stlpci Z1.1',
       zone_role_count(cab, 'shelf') == 6)

    # --- 6) PRESNA CESTA: rozmer pola cislom --------------------------------
    plan_zone = lambda do
      cfg2 = e::CabinetBuilder.normalize(e::Panel.existing_params(cab))
      Array(e::Construction.build_plan(cfg2, cid)[:zones]).find { |z| z[:id].to_s == root }
    end
    z = plan_zone.call
    clear = Array(z[:split][:fields]).reduce(0.0) { |s, f| s + f[:size].to_f }
    good = [{ 'size' => 500.0, 'locked' => true }, { 'size' => (clear - 500.0).round(2), 'locked' => false }]
    e::Panel.handle_set_zone_field({ 'zone_id' => root, 'index' => 0, 'cuts' => good,
                                     'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    cuts = zone_tree_of(cab)['split']['cuts']
    ok('UI-C2: presny rozmer pola 1 sa ulozil aj so zamkom',
       (cuts[0]['size'].to_f - 500.0).abs < 0.01 && cuts[0]['locked'] == true)
    z2 = plan_zone.call
    ok('UI-C2: geometria plan<->strom sedi (prve pole ma 500 mm)',
       (z2[:split][:fields][0][:size].to_f - 500.0).abs < 0.01)

    # Nezmestitelna hodnota sa ODMIETNE — nikdy sa ticho nezmensi.
    bad = [{ 'size' => clear + 200.0, 'locked' => true }, { 'size' => 100.0, 'locked' => false }]
    e::Panel.handle_set_zone_field({ 'zone_id' => root, 'index' => 0, 'cuts' => bad,
                                     'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: nezmestitelny rozmer sa ODMIETNE a strom ostane povodny',
       (zone_tree_of(cab)['split']['cuts'][0]['size'].to_f - 500.0).abs < 0.01)
    # Text namiesto cisla tiez (`'650-36'.to_f` by ticho vratilo 650).
    txt = [{ 'size' => '650-36', 'locked' => true }, { 'size' => 100.0, 'locked' => false }]
    e::Panel.handle_set_zone_field({ 'zone_id' => root, 'index' => 0, 'cuts' => txt,
                                     'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: textovy „rozmer" sa ODMIETNE (ziadny tichy prevod na cislo)',
       (zone_tree_of(cab)['split']['cuts'][0]['size'].to_f - 500.0).abs < 0.01)

    # --- 7) UNDO: posledna zmena je PRESNE JEDEN krok Spat -------------------
    shelves_before = zone_role_count(cab, 'shelf')
    e::Panel.handle_set_zone_shelves({ 'zone_id' => "#{cid}-Z1.2", 'count' => 2,
                                       'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: police v druhom stlpci pribudli',
       zone_role_count(cab, 'shelf') == shelves_before + 2)
    Sketchup.undo
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: 1x Spat vratil presne poslednu zonovu zmenu (jedna operacia)',
       cab && cab.valid? && zone_role_count(cab, 'shelf') == shelves_before &&
       zone_role_count(cab, 'divider_v') == 1)

    # --- 8) VYCISTIT ZONU je jedina destruktivna cesta -----------------------
    e::Panel.handle_clean_zone({ 'zone_id' => root, 'model_guid' => guid,
                                 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2: „Vycistit zonu" zrusilo delenie aj police',
       zone_tree_of(cab)['split'].nil? && zone_role_count(cab, 'divider_v').zero? &&
       zone_role_count(cab, 'shelf').zero?)
    ok('UI-C2: po vycisteni ostava oznacena skrinka', model.selection.to_a == [cab])

    # --- 9) HLBKA: 4. uroven sa neda vytvorit -------------------------------
    e::Panel.handle_split_zone({ 'zone_id' => root, 'axis' => 'v', 'count' => 2,
                                 'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    e::Panel.handle_split_zone({ 'zone_id' => "#{cid}-Z1.1", 'axis' => 'h', 'count' => 2,
                                 'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    e::Panel.handle_split_zone({ 'zone_id' => "#{cid}-Z1.1.1", 'axis' => 'v', 'count' => 2,
                                 'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    cab = e::Panel.find_cabinet_by_id(model, cid)
    ok('UI-C2 (N22): 4. uroven sa neda vytvorit (strom ostal na 3)',
       e::ZoneTree.depth(zone_tree_of(cab)) == 3)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-C2 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  end

  # === UI-C1c: ORIENTACIA DOSKY ==============================================
  # Overuje presne to, co headless sada NEVIE: realne matice, SVETOVE osi,
  # normalu dekorovej plochy, kotviace roviny, spravanie transformacie pri
  # rebuilde/scale/dedupe a pocet undo krokov.
  #
  # KONTRAKT (Codex audit C1c): orientacia je TRANSFORMACIA INSTANCIE —
  # geometria v definicii ostava LEZIACA a vyrobne data (deskriptor, kusovnik,
  # VEPO) sa NEMENIA. Zmena orientacie je DELTA (T × O_old⁻¹ × O_new), takze
  # rucne otocenie pouzivatela prezije a opakovane prepnutie nekumuluje.

  # Zloženie transformacie ako porovnatelne pole (mm-presnost staci).
  def tr_key(tr)
    tr.to_a.map { |v| v.round(6) }
  end

  def vec_near?(vec, x, y, z, tol = 0.001)
    v = vec.normalize
    (v.x - x).abs < tol && (v.y - y).abs < tol && (v.z - z).abs < tol
  end

  # VYROBNY OBRAZ modelu (vstup kusovnika a odtial VEPO) BEZ adresnych udajov:
  # `refs`/`kde`/`names`/`key` su navigacia v UI (pid, vlastnik, nazvy), nie
  # vyroba — porovnavaju sa rozmery, material, hrany, smer dekoru a mnozstvo.
  def bom_rows(model)
    e::Bom.compute(e::Bom.collect(model))[:rows].map do |r|
      r.reject { |k, _| %w[refs kde names key].include?(k) }
    end
  end

  def run_uic1c(model)
    cleanup(model)
    mat = 'K009_PW_DTDL_18'
    th = 18.0
    len = 700.0
    wid = 500.0

    # --- 1) VLOZENIE v kazdej orientacii: svetove osi + normala dekoru + roviny
    insts = {}
    %w[leziaca stojaca na_stenu].each do |o|
      insts[o] = e::BoardBuilder.build(model, { 'material_id' => mat, 'length' => len,
                                                'width' => wid, 'orientation' => o,
                                                'name' => "UI-C1c #{o}" })
    end
    return ok('UI-C1c: vlozenie dosiek vo vsetkych troch orientaciach', false) if insts.values.any?(&:nil?)

    insts.each do |o, inst|
      cfg = e::Store.config(inst) || {}
      ok("UI-C1c: config nesie orientaciu '#{o}'", cfg['orientation'] == o)
      # Geometria DEFINICIE je pri kazdej orientacii ROVNAKA (lezaca).
      db = inst.definition.bounds
      ok("UI-C1c (#{o}): geometria definicie ostala LEZIACA (#{len}x#{wid}x#{th})",
         (mm(db.width) - len).abs <= TOL && (mm(db.height) - wid).abs <= TOL &&
         (mm(db.depth) - th).abs <= TOL)
    end

    lez = insts['leziaca']
    ok('UI-C1c (leziaca): svetove osi = identita (X dlzka, Y sirka, Z hrubka)',
       vec_near?(lez.transformation.xaxis, 1, 0, 0) &&
       vec_near?(lez.transformation.yaxis, 0, 1, 0) &&
       vec_near?(lez.transformation.zaxis, 0, 0, 1))
    lb = lez.bounds
    ok('UI-C1c (leziaca): dekorova plocha mieri HORE (+Z) a doska lezi na Z=0',
       vec_near?(lez.transformation.zaxis, 0, 0, 1) && mm(lb.min.z).abs <= TOL &&
       (mm(lb.max.z) - th).abs <= TOL)

    %w[stojaca na_stenu].each do |o|
      inst = insts[o]
      tr = inst.transformation
      ok("UI-C1c (#{o}): svetove osi — dlzka X, hrubka do +Y, vyska do +Z",
         vec_near?(tr.xaxis, 1, 0, 0) && vec_near?(tr.yaxis, 0, 0, 1) && vec_near?(tr.zaxis, 0, -1, 0))
      ok("UI-C1c (#{o}): normala DEKOROVEJ plochy mieri DOPREDU (-Y)",
         vec_near?(tr.zaxis, 0, -1, 0))
      b = inst.bounds
      ok("UI-C1c (#{o}): kotviace roviny — dekor na Y=0, chrbat na Y=hrubka",
         mm(b.min.y).abs <= TOL && (mm(b.max.y) - th).abs <= TOL)
      ok("UI-C1c (#{o}): spodna dlha hrana sadla na Z=0, vyska = sirka dosky",
         mm(b.min.z).abs <= TOL && (mm(b.max.z) - wid).abs <= TOL)
      ok("UI-C1c (#{o}): dlzka ostala v X (#{len} mm)",
         (mm(b.max.x) - mm(b.min.x) - len).abs <= TOL)
    end

    # ZAMERNE zhodne matice — enum je udaj UMIESTNENIA so semantikou, nie tvar.
    ok('UI-C1c: „na_stenu" ma ZAMERNE tu istu maticu ako „stojaca" (lisi sa POLE, nie bbox)',
       tr_key(e::BoardBuilder.orientation_matrix('stojaca', th)) ==
       tr_key(e::BoardBuilder.orientation_matrix('na_stenu', th)) &&
       (e::Store.config(insts['stojaca']) || {})['orientation'] !=
       (e::Store.config(insts['na_stenu']) || {})['orientation'])

    # --- 2) VYROBNE DATA sa orientaciou NEMENIA (kusovnik = vstup VEPO) -------
    rows_before = bom_rows(model)
    ok('UI-C1c: tri rovnake dosky v troch orientaciach = JEDEN riadok kusovnika',
       rows_before.size == 1 && rows_before.first['quantity'].to_i == 3)

    # --- 3) ZMENA ORIENTACIE cez panel: delta, 1 undo krok, cache observera ---
    b = lez
    bid = e::Store.get(b, 'id').to_s
    e::Panel.select_only(model, b)
    e::Panel.handle_set_board_orientation({ 'board_id' => bid, 'orientation' => 'stojaca' }.to_json)
    cfg_after = e::Store.config(b) || {}
    ok('UI-C1c edit: config prevzal novu orientaciu', cfg_after['orientation'] == 'stojaca')
    ok('UI-C1c edit: instancia sa naozaj otocila (dekor mieri do -Y)',
       vec_near?(b.transformation.zaxis, 0, -1, 0))
    db2 = b.definition.bounds
    ok('UI-C1c edit: geometria definicie ostala LEZIACA (otocila sa INSTANCIA)',
       (mm(db2.width) - len).abs <= TOL && (mm(db2.height) - wid).abs <= TOL &&
       (mm(db2.depth) - th).abs <= TOL)
    ok('UI-C1c edit: kusovnik sa NEZMENIL (orientacia nie je vyrobny udaj)',
       bom_rows(model) == rows_before)
    # FIX 4: stabilna transformacia observera musi ist s otocenim, inak by
    # najblizsi ODMIETNUTY scale dosku vratil do starej polohy.
    ok('UI-C1c edit: scale observer si zapamatal NOVU stabilnu transformaciu',
       e::ScaleWatch.stable_transform(b) &&
       tr_key(e::ScaleWatch.stable_transform(b)) == tr_key(b.transformation))

    tr_standing = tr_key(b.transformation)
    Sketchup.undo
    ok('UI-C1c edit: 1x Spat vratil orientaciu AJ transformaciu (jeden krok)',
       (e::Store.config(b) || {})['orientation'] == 'leziaca' &&
       vec_near?(b.transformation.zaxis, 0, 0, 1))
    e::Panel.handle_set_board_orientation({ 'board_id' => bid, 'orientation' => 'stojaca' }.to_json)
    ok('UI-C1c edit: opakovane prepnutie dava TU ISTU transformaciu (ziadna kumulacia)',
       tr_key(b.transformation) == tr_standing)

    # --- 4) DELTA: rucne otocenie pouzivatela PREZIJE zmenu orientacie -------
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST rucna rotacia dosky', true)
      b.transformation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * b.transformation
      model.commit_operation
    end
    e::ScaleWatch.remember_transform(b)
    e::Panel.handle_set_board_orientation({ 'board_id' => bid, 'orientation' => 'leziaca' }.to_json)
    ok('UI-C1c delta: rucne otocenie o 90° prezilo prepnutie orientacie',
       vec_near?(b.transformation.xaxis, 0, 1, 0) && vec_near?(b.transformation.zaxis, 0, 0, 1) &&
       (e::Store.config(b) || {})['orientation'] == 'leziaca')
    # Rucnu rotaciu vratime spat — dalsie scenare (scale, dedup) porovnavaju
    # SVETOVE osi proti kontraktovym hodnotam, nie proti pouzivatelovmu natoceniu.
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST navrat z rucnej rotacie', true)
      b.transformation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, -90.degrees) * b.transformation
      model.commit_operation
    end
    e::ScaleWatch.remember_transform(b)
    e::Panel.handle_set_board_orientation({ 'board_id' => bid, 'orientation' => 'stojaca' }.to_json)
    ok('UI-C1c delta: po navrate rucnej rotacie doska zas stoji v kontraktovej polohe',
       vec_near?(b.transformation.zaxis, 0, -1, 0) && vec_near?(b.transformation.xaxis, 1, 0, 0))

    # --- 5) REBUILD transformaciu NEMENI + je idempotentny -------------------
    tr_keep = tr_key(b.transformation)
    e::BoardBuilder.rebuild(model, b, { 'width' => 520.0 })
    ok('UI-C1c rebuild: zmena rozmeru transformaciu NEMENI (orientacia sa neaplikuje 2x)',
       tr_key(b.transformation) == tr_keep &&
       ((e::Store.config(b) || {})['width'].to_f - 520.0).abs < 0.01 &&
       (e::Store.config(b) || {})['orientation'] == 'stojaca')
    e::BoardBuilder.rebuild(model, b, { 'width' => 520.0 })
    ok('UI-C1c rebuild: opakovany rebuild je idempotentny',
       tr_key(b.transformation) == tr_keep)

    # --- 6) SCALE: absorpcia aj ODMIETNUTIE nad OTOCENOU doskou --------------
    # Scale v LOKALNEJ osi Y (= svetove Z stojacej dosky) musi skoncit v sirke.
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST scale otocenej dosky', true)
      b.transformation = b.transformation * Geom::Transformation.scaling(ORIGIN, 1.0, 1.2, 1.0)
      model.commit_operation
    end
    e::ScaleWatch.absorb_board(b)
    ok('UI-C1c scale: absorpcia otocenej dosky isla do SIRKY (520 -> 624)',
       ((e::Store.config(b) || {})['width'].to_f - 624.0).abs < 1.0)
    ok('UI-C1c scale: po absorpcii je transformacia bez scale a doska stale stoji',
       !e::ScaleWatch.scaled?(b.transformation) && vec_near?(b.transformation.zaxis, 0, -1, 0))

    stable_now = tr_key(b.transformation)
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST neplatny scale dosky', true)
      b.transformation = b.transformation * Geom::Transformation.scaling(ORIGIN, 3.0, 1.0, 1.0)
      model.commit_operation
    end
    e::ScaleWatch.reject_scale(b, RuntimeError.new('SU-TEST odmietnutie'))
    ok('UI-C1c scale: ODMIETNUTY scale vratil dosku do OTOCENEJ polohy (nie do lezacej)',
       tr_key(b.transformation) == stable_now && vec_near?(b.transformation.zaxis, 0, -1, 0))

    # --- 7) KOPIA: dedup drzi orientaciu aj polohu ---------------------------
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST kopia otocenej dosky', true)
      trc = b.transformation * Geom::Transformation.translation(e::Units.vector(900, 0, 0))
      bcopy = model.entities.add_instance(b.definition, trc)
      %w[std kind id part_id part_key part_key_schema role name manufactured production_class config].each do |k|
        v = e::Store.get(b, k)
        bcopy.set_attribute('NOXUN', k, v) unless v.nil?
      end
      model.commit_operation
    end
    copies = e::BoardBuilder.dedup_copies(model)
    cp = copies.first
    ok('UI-C1c kopia: dedup dal nove ID a kopia si drzi orientaciu aj natocenie',
       copies.length == 1 && cp && (e::Store.config(cp) || {})['orientation'] == 'stojaca' &&
       vec_near?(cp.transformation.zaxis, 0, -1, 0) &&
       e::Store.get(cp, 'id').to_s != bid)

    # --- 8) GUARD neznamej hodnoty (insert aj edit) --------------------------
    before_boards = boards(model).length
    raised = false
    begin
      e::BoardBuilder.build(model, { 'material_id' => mat, 'orientation' => 'zavesena' })
    rescue StandardError
      raised = true
    end
    ok('UI-C1c guard: neznama orientacia pri VKLADANI padne a doska nevznikne',
       raised && boards(model).length == before_boards)

    e::Panel.select_only(model, b)
    cfg_keep = (e::Store.config(b) || {})['orientation']
    tr_before_bad = tr_key(b.transformation)
    e::Panel.handle_set_board_orientation({ 'board_id' => bid, 'orientation' => 'zavesena' }.to_json)
    ok('UI-C1c guard: neznama orientacia pri EDITE nic nezmeni (config ani poloha)',
       (e::Store.config(b) || {})['orientation'] == cfg_keep &&
       tr_key(b.transformation) == tr_before_bad)

    # Ulozena NEZNAMA orientacia (config z novsej verzie) = odmietnutie, nie
    # ticha oprava — delta by z nej spravila nezmysel.
    e::ScaleWatch.guard do
      model.start_operation('SU-TEST config z novsej verzie', true)
      bad = (e::Store.config(b) || {}).merge('orientation' => 'zavesena')
      e::Store.write(b, { config: bad })
      model.commit_operation
    end
    e::Panel.handle_set_board_orientation({ 'board_id' => bid, 'orientation' => 'leziaca' }.to_json)
    ok('UI-C1c guard: NEZNAMA ULOZENA orientacia sa odmietne (poloha ostala)',
       (e::Store.config(b) || {})['orientation'] == 'zavesena' &&
       tr_key(b.transformation) == tr_before_bad)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-C1c sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    cleanup(model)
  end

  # --- ASYNC: undo/redo scenare (retaz timerov, observer debounce 0.2 s) -----

  # === UI-D1: DIELEC — „Označiť v modeli" + „Použiť na podobné…" =============
  # Overuje presne to, co headless sada NEVIE: ci sa olep naozaj zapise do
  # VIACERYCH dielcov (aj naprie skrinkami), ci je to JEDEN krok Spat, ci
  # „Označiť v modeli" model NEDOTKNE a ci guardy identity drzia na zivom modeli.
  #
  # Najdrahsia pasca tejto davky: hromadny zapis po jednom rebuilde by vyrobil
  # tolko krokov Spat, kolko skriniek sa zmenilo — pouzivatel by sa z toho uz
  # nedostal jednym Ctrl+Z. Preto sa tu meria PRESNE jedno undo.

  # Kluce dielcov skrinky, ktore maju RUCNY override hrany L1.
  def uid1_l1_override_keys(cab)
    return [] unless cab && cab.valid?

    ov = (e::Store.config(cab) || {})['part_overrides'] || {}
    ov.select { |_k, v| v.is_a?(Hash) && v['edges'].is_a?(Hash) && v['edges'].key?('L1') }.keys.sort
  end

  def uid1_parts_of_role(cab, role)
    e::Panel.manufactured_parts(cab).select { |p| e::Store.get(p, 'role').to_s == role }
  end

  def run_uid1(model)
    cleanup(model)

    cfg = { 'type' => 'lower', 'width' => 900.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0 }
    cab_a = e::CabinetBuilder.build(model, cfg)
    cab_b = e::CabinetBuilder.build(model, cfg.merge('width' => 600.0))
    return ok('UI-D1: vlozenie dvoch skriniek pre test podobnych dielcov', false) unless cab_a && cab_b

    cid_a = e::Store.get(cab_a, 'cabinet_id').to_s
    cid_b = e::Store.get(cab_b, 'cabinet_id').to_s
    guid = e::Panel.model_guid(model)

    # Po 3 police v kazdej skrinke — az tie vyrobia dielce ROVNAKEJ ROLY.
    [[cab_a, cid_a], [cab_b, cid_b]].each do |inst, cid|
      e::Panel.select_only(model, inst)
      e::Panel.handle_set_zone_shelves({ 'zone_id' => "#{cid}-Z1", 'count' => 3,
                                         'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    end
    cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
    cab_b = e::Panel.find_cabinet_by_id(model, cid_b)
    shelves_a = uid1_parts_of_role(cab_a, 'shelf')
    shelves_b = uid1_parts_of_role(cab_b, 'shelf')
    ok("UI-D1: obe skrinky maju police (A=#{shelves_a.size}, B=#{shelves_b.size})",
       shelves_a.size == 3 && shelves_b.size == 3)
    return unless shelves_a.size == 3 && shelves_b.size == 3

    src = shelves_a.first
    src_key = e::Store.get(src, 'part_key').to_s
    e::Panel.select_only(model, src)

    # --- 1) DEFINICIA „podobny": rovnaka ROLA + rovnaky MATERIAL ------------
    n_cab = e::Panel.similar_parts_count(e::Panel.similar_parts_map(model, cab_a, src, 'cabinet'))
    n_prj = e::Panel.similar_parts_count(e::Panel.similar_parts_map(model, cab_a, src, 'project'))
    ok("UI-D1: rozsah „táto skrinka\" = ostatne police tej istej skrinky (#{n_cab})", n_cab == 2)
    ok("UI-D1: rozsah „celý projekt\" berie aj druhu skrinku (#{n_prj})", n_prj == 5)

    top = uid1_parts_of_role(cab_a, 'top').first
    if top
      n_top_cab = e::Panel.similar_parts_count(e::Panel.similar_parts_map(model, cab_a, top, 'cabinet'))
      n_top_prj = e::Panel.similar_parts_count(e::Panel.similar_parts_map(model, cab_a, top, 'project'))
      ok('UI-D1: rola s JEDINYM dielcom v skrinke ma v rozsahu skrinky 0 podobnych',
         n_top_cab.zero?)
      ok('UI-D1: ta ista rola ma v projekte 1 podobny (vrch druhej skrinky)', n_top_prj == 1)
    else
      info('UI-D1: skrinka nema dielec role `top` — test „0 podobnych" preskoceny.')
    end

    # --- 2) zdrojovy override: hrana L1 = BEZ ABS ----------------------------
    e::Panel.handle_set_part_edge({ 'role_key' => src_key, 'edge' => 'L1', 'abs_id' => '',
                                    'cabinet_id' => cid_a }.to_json)
    cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
    cab_b = e::Panel.find_cabinet_by_id(model, cid_b)
    ok('UI-D1: zdrojovy dielec ma rucny override hrany L1',
       uid1_l1_override_keys(cab_a) == [src_key])
    ok('UI-D1: druha skrinka je zatial NEDOTKNUTA', uid1_l1_override_keys(cab_b).empty?)

    # --- 3) GUARDY: cudzi dokument ani ina skrinka nezapisu NIC -------------
    e::Panel.handle_apply_edges_similar({ 'model_guid' => 'CUDZI-GUID', 'cabinet_id' => cid_a,
                                          'role_key' => src_key, 'scope' => 'project' }.to_json)
    cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
    cab_b = e::Panel.find_cabinet_by_id(model, cid_b)
    ok('UI-D1: „Použiť na podobné" z INEHO dokumentu nezapise NIC (guard dokumentu)',
       uid1_l1_override_keys(cab_a) == [src_key] && uid1_l1_override_keys(cab_b).empty?)

    e::Panel.handle_apply_edges_similar({ 'model_guid' => guid, 'cabinet_id' => 'CAB-NEEXISTUJE',
                                          'role_key' => src_key, 'scope' => 'project' }.to_json)
    cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
    cab_b = e::Panel.find_cabinet_by_id(model, cid_b)
    ok('UI-D1: „Použiť na podobné" pre INU nez oznacenu skrinku nezapise NIC',
       uid1_l1_override_keys(cab_a) == [src_key] && uid1_l1_override_keys(cab_b).empty?)

    # --- 4) ZAPIS na cely projekt = JEDNA operacia --------------------------
    cabs_before = cabinets(model).length
    e::Panel.handle_apply_edges_similar({ 'model_guid' => guid, 'cabinet_id' => cid_a,
                                          'role_key' => src_key, 'scope' => 'project' }.to_json)
    cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
    cab_b = e::Panel.find_cabinet_by_id(model, cid_b)
    keys_a = uid1_l1_override_keys(cab_a)
    keys_b = uid1_l1_override_keys(cab_b)
    ok("UI-D1: olep sa zapisal VSETKYM policiam oboch skriniek (#{keys_a.size} + #{keys_b.size})",
       keys_a.size == 3 && keys_b.size == 3)
    ok('UI-D1: zapis nevyrobil ziadny novy NOXUN objekt', cabinets(model).length == cabs_before)
    ok('UI-D1: po zapise ostava vo vybere ZDROJOVY dielec (karta sa nestrati)',
       model.selection.to_a.map { |x| e::Store.get(x, 'part_key').to_s } == [src_key])

    # --- 5) „Označiť v modeli" — ziadny zapis, ziadny krok Spat -------------
    before_ents = model.entities.length
    e::Panel.select_only(model, cab_a)
    e::Panel.handle_select_part({ 'model_guid' => 'CUDZI-GUID', 'cabinet_id' => cid_a,
                                  'role_key' => src_key }.to_json)
    ok('UI-D1: „Označiť v modeli" z INEHO dokumentu vyber NEMENI',
       model.selection.to_a == [cab_a])
    e::Panel.handle_select_part({ 'model_guid' => guid, 'cabinet_id' => 'CAB-NEEXISTUJE',
                                  'role_key' => src_key }.to_json)
    ok('UI-D1: „Označiť v modeli" pre INU nez oznacenu skrinku vyber NEMENI',
       model.selection.to_a == [cab_a])
    e::Panel.handle_select_part({ 'model_guid' => guid, 'cabinet_id' => cid_a,
                                  'role_key' => src_key }.to_json)
    ok('UI-D1: „Označiť v modeli" oznaci PRESNE ten dielec',
       model.selection.to_a.map { |x| e::Store.get(x, 'part_key').to_s } == [src_key])
    ok('UI-D1: oznacenie dielca NEMENI model (ziadna entita naviac ani menej)',
       model.entities.length == before_ents)

    # --- 6) JEDEN krok Spat vrati VSETKO -------------------------------------
    # Keby bolo „Označiť v modeli" vlastnou operaciou, toto undo by vratilo JU
    # a olep by v modeli ostal. Keby bol hromadny zapis rebuildom po jednom,
    # vratila by sa len POSLEDNA skrinka.
    Sketchup.undo
    cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
    cab_b = e::Panel.find_cabinet_by_id(model, cid_b)
    ok('UI-D1: 1x Spat vratil olep v OBOCH skrinkach naraz (ostal len zdrojovy override)',
       uid1_l1_override_keys(cab_a) == [src_key] && uid1_l1_override_keys(cab_b).empty?)

    # --- 7) 0 podobnych: nic sa nezapise ------------------------------------
    top = uid1_parts_of_role(cab_a, 'top').first
    if top
      top_key = e::Store.get(top, 'part_key').to_s
      e::Panel.select_only(model, top)
      e::Panel.handle_apply_edges_similar({ 'model_guid' => guid, 'cabinet_id' => cid_a,
                                            'role_key' => top_key, 'scope' => 'cabinet' }.to_json)
      cab_a = e::Panel.find_cabinet_by_id(model, cid_a)
      ok('UI-D1: pri 0 podobnych sa NEZAPISE nic (atomicky no-op)',
         uid1_l1_override_keys(cab_a) == [src_key])
    end

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-D1 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  end

  # =========================================================================
  # UI-D2 — PNG NAHLADY SABLON (kamera + sklad)
  #
  # Headless sada overi meno suboru, zamok, transport aj forward guard; TU sa
  # overuje to, co bez ziveho `Sketchup::View` overit NEDA:
  #   * `write_image` naozaj vyrobi platny PNG,
  #   * kamera je po capture KOMPLETNE obnovena — perspektivna AJ ortogonalna
  #     (`write_image` prepisuje aj `aspect_ratio`, takze obnova samotneho
  #     eye/target/up by nestacila) a obnovi sa aj vtedy, ked capture ZLYHA,
  #   * capture ani ulozenie sablony NEVYROBI undo krok (ziadna model operacia).
  #
  # POZOR na sklad sablon: `scripts\run_su_tests.ps1` presmeruje %APPDATA% do
  # sandboxu, ale pri RUCNOM `load` v konzole ziveho okna by sekcia siahla na
  # skutocnu kniznicu — preto pracuje s jedinym docasnym nazvom `UID2_NAME`
  # a upratuje ho na zaciatku aj v `ensure`.
  UID2_NAME = 'SU-TEST nahlad (docasna)'

  # Odtlacok CELEJ kamery — presne to, co musi capture vratit do povodneho stavu.
  def uid2_cam(view)
    c = view.camera
    { eye: c.eye.to_a, target: c.target.to_a, up: c.up.to_a,
      perspective: (c.perspective? ? true : false),
      fov: c.fov.to_f, height: c.height.to_f, aspect: c.aspect_ratio.to_f }
  end

  def uid2_cam_same?(a, b)
    return false unless a[:perspective] == b[:perspective]
    return false unless %i[eye target up].all? { |k| uid2_vec_same?(a[k], b[k]) }
    return false if (a[:aspect] - b[:aspect]).abs > 0.001

    key = a[:perspective] ? :fov : :height
    (a[key] - b[key]).abs <= (a[key].abs * 0.001 + 0.001)
  end

  def uid2_vec_same?(a, b)
    a.each_with_index.all? { |v, i| (v.to_f - b[i].to_f).abs < 0.001 }
  end

  # Docasne rozbity capture: cielova cesta na neexistujucom disku, takze
  # `write_image` nemoze uspiet. Povodna metoda sa vracia v `ensure` — inak by
  # zvysok behu (a pri pade aj cele okno) ostal s rozbitym nahladom.
  def uid2_with_broken_capture(tp)
    orig = tp.method(:new_tmp_path)
    tp.define_singleton_method(:new_tmp_path) { 'Z:/noxun-neexistujuci-disk/uid2.png' }
    yield
  ensure
    tp.define_singleton_method(:new_tmp_path) { orig.call }
  end

  def uid2_cam_diff(a, b)
    %i[eye target up perspective fov height aspect].reject { |k| a[k] == b[k] }
                                                   .map { |k| "#{k}: #{a[k].inspect} -> #{b[k].inspect}" }
                                                   .join(', ')
  end

  def run_uid2(model)
    cleanup(model)
    tp = e::TemplatePreviews
    ts = e::TemplateStore
    ts.delete('cabinet', UID2_NAME) # zvysky z predosleho behu

    cfg = { 'type' => 'lower', 'width' => 800.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0 }
    inst = e::CabinetBuilder.build(model, cfg)
    return ok('UI-D2: vlozenie skrinky pre nahlad', false) unless inst

    cid = e::Store.get(inst, 'cabinet_id').to_s
    guid = e::Panel.model_guid(model)
    e::Panel.select_only(model, inst)
    view = model.active_view
    before_ents = model.entities.length

    # --- 1) PERSPEKTIVNA kamera ---------------------------------------------
    view.camera.perspective = true
    view.camera.set(Geom::Point3d.new(200, -300, 200), Geom::Point3d.new(0, 0, 20), Z_AXIS)
    view.camera.fov = 47.5
    cam_before = uid2_cam(view)
    tmp = tp.capture(model, inst)
    ok('UI-D2: capture vyrobil subor', !tmp.nil? && File.file?(tmp.to_s))
    ok('UI-D2: subor je platny PNG do stropu velkosti (magic + limit)', tp.valid_file?(tmp.to_s))
    info("UI-D2: velkost capture PNG = #{tmp && File.file?(tmp) ? File.size(tmp) : '?'} B " \
         "(strop #{tp::MAX_BYTES} B)")
    cam_after = uid2_cam(view)
    ok('UI-D2: PERSPEKTIVNA kamera je po capture KOMPLETNE obnovena (eye/target/up/fov/aspect)',
       uid2_cam_same?(cam_before, cam_after))
    info("UI-D2: rozdiel perspektivnej kamery: #{uid2_cam_diff(cam_before, cam_after)}") unless
      uid2_cam_same?(cam_before, cam_after)
    ok('UI-D2: capture NEMENI model (ziadna entita naviac ani menej)',
       model.entities.length == before_ents)
    ok('UI-D2: capture NEMENI vyber', model.selection.to_a == [inst])
    tp.discard(tmp)

    # --- 2) ORTOGONALNA kamera ----------------------------------------------
    # Iny rezim = ina velicina zoomu (`height` namiesto `fov`). Keby sa obnovoval
    # len `fov`, orto pohlad by po ulozeni sablony odskocil.
    view.camera.perspective = false
    view.camera.set(Geom::Point3d.new(0, -400, 100), Geom::Point3d.new(0, 0, 100), Z_AXIS)
    view.camera.height = 120.0
    cam_ortho = uid2_cam(view)
    tmp2 = tp.capture(model, inst)
    ok('UI-D2: capture funguje aj v orto pohlade', tp.valid_file?(tmp2.to_s))
    cam_ortho_after = uid2_cam(view)
    ok('UI-D2: ORTOGONALNA kamera je po capture KOMPLETNE obnovena (vratane height a rezimu)',
       uid2_cam_same?(cam_ortho, cam_ortho_after))
    info("UI-D2: rozdiel orto kamery: #{uid2_cam_diff(cam_ortho, cam_ortho_after)}") unless
      uid2_cam_same?(cam_ortho, cam_ortho_after)
    ok('UI-D2: orto rezim ostal orto (write_image ho neprepol)', view.camera.perspective? == false)
    tp.discard(tmp2)
    view.camera.perspective = true # naspat do bezneho rezimu pre zvysok behu

    # --- 3) ZLYHANY capture: kamera sa OBNOVI aj tak ------------------------
    # Simulacia zlou cielovou cestou — `write_image` na neexistujucom disku
    # nemoze uspiet. Ide o vetvu `written == false` / vynimka: kamera musi ist
    # spat z `ensure`, nie „po ceste".
    cam_fail = uid2_cam(view)
    failed = nil
    uid2_with_broken_capture(tp) { failed = tp.capture(model, inst) }
    ok('UI-D2: zlyhany capture vracia nil (write_image sa kontroluje, nie len vynimka)', failed.nil?)
    ok('UI-D2: kamera je obnovena AJ pri zlyhanom capture', uid2_cam_same?(cam_fail, uid2_cam(view)))

    # --- 4) ULOZENIE SABLONY z panela: zaznam + PNG -------------------------
    e::Panel.handle_save_template_as({ 'name' => UID2_NAME, 'type' => 'lower',
                                       'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    ok('UI-D2: sablona sa ulozila', !ts.find('cabinet', UID2_NAME).nil?)
    png = tp.path_for('cabinet', UID2_NAME)
    ok('UI-D2: ulozenie sablony vyrobilo PNG nahlad', tp.valid_file?(png))
    rev1 = tp.rev_for('cabinet', UID2_NAME)
    ok('UI-D2: zoznam sablon nesie reviziu nahladu (transport do dlazdice)',
       !rev1.nil? && e::Panel.template_list(previews: true)
                             .find { |t| t['name'] == UID2_NAME }['preview_rev'] == rev1)
    ok('UI-D2: server posiela nahlad ako data URI',
       tp.data_uri('cabinet', UID2_NAME).to_s.start_with?('data:image/png;base64,'))
    ok('UI-D2: ulozenie sablony NEMENI model', model.entities.length == before_ents)

    # --- 5) PREPIS so ZLYHANYM capture: stary PNG musi ZMIZNUT --------------
    uid2_with_broken_capture(tp) do
      e::Panel.handle_save_template_as({ 'name' => UID2_NAME, 'type' => 'upper',
                                         'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    end
    ok('UI-D2: prepis sablony prebehol aj bez nahladu',
       (ts.find('cabinet', UID2_NAME) || {}).fetch('config', {})['type'] == 'upper')
    ok('UI-D2: prepis so ZLYHANYM capture stary PNG ZMAZAL (radsej schema nez zly obrazok)',
       !File.exist?(png.to_s))
    ok('UI-D2: sablona bez nahladu ma v zozname preview_rev nil',
       e::Panel.template_list(previews: true).find { |t| t['name'] == UID2_NAME }['preview_rev'].nil?)

    # --- 6) VYMAZANIE sablony berie PNG so sebou ----------------------------
    e::Panel.handle_save_template_as({ 'name' => UID2_NAME, 'type' => 'lower',
                                       'model_guid' => guid, 'cabinet_id' => cid }.to_json)
    ok('UI-D2: sablona ma pred mazanim zase nahlad', tp.valid_file?(png))
    ok('UI-D2: vymazanie sablony prebehlo', ts.delete('cabinet', UID2_NAME))
    ok('UI-D2: PNG zmizol SO ZAZNAMOM (mazanie zije v TemplateStore.delete)', !File.exist?(png.to_s))

    # --- 7) ZIADNY undo krok ------------------------------------------------
    # Poslednou MODELOVOU operaciou je stale vlozenie skrinky (kroky 1-6 su
    # ciste citanie + subory). Keby capture ci ulozenie sablony boli vlastnou
    # operaciou, 1x Spat by vratilo JU a skrinka by v modeli ostala.
    Sketchup.undo
    ok('UI-D2: 1x Spat zmazal skrinku — capture ani ulozenie sablony NIE JE undo krok',
       inst.nil? || !inst.valid?)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: UI-D2 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  ensure
    begin
      e::TemplateStore.delete('cabinet', UID2_NAME) # docasna sablona nesmie prezit beh
    rescue StandardError
      nil
    end
  end

  # ===========================================================================
  # SMOKE PACK 1 (6A) — RUCNE odfotenie nahladu k UZ ULOZENEJ sablone.
  # Nova serverova cesta s KAMEROU, preto in-SketchUp sekcia (headless sada
  # `write_image` ani kameru neoveri). Dokazuje sa:
  #   * bez oznacenia a pri VIACERYCH oznacenych skrinkach sa NEZAPISE nic,
  #   * pri prave jednej oznacenej vznikne PNG a zaznam sablony sa NEZMENI,
  #   * kamera je po fotenie kompletne obnovena,
  #   * cela akcia NIE JE undo krok (1x Spat vrati este vlozenie skrinky).
  # Docasny nazov sablony sa uprace na zaciatku aj v `ensure` (vzor UI-D2).
  SMOKE1_NAME = 'SU-TEST odfotenie (docasna)'

  # =========================================================================
  # K1 / D-108 — SMER DEKORU PER DIELEC ako VSTUP
  #
  # Headless sada overi retaz `override -> material -> snapshot` aj vystupy;
  # TU sa overuje to, co bez ziveho modelu overit NEDA:
  #   * zapis z panela na ZIVEJ skrinke je PRESNE JEDEN krok Spat,
  #   * GEOMETRIA sa nezmenila (rozmery kvadra ostali) — otaca sa VYSTUP,
  #     nie model; kresba je vyrobny udaj, nie transformacia,
  #   * D-88 farbenie hran je po otoceni NEZMENENE (osi dielca sa nehybu),
  #   * kopia skrinky (dedup) si override NESIE,
  #   * ODPOJENY dielec drzi svoj snapshot aj ked sa korpus vrati na dedenie,
  #   * otvorenie STAREJ zakazky bez pola nezapise NIC,
  #   * VEPO CSV naozaj obsahuje OTOCENY riadok.
  #
  # Bezi nad IZOLOVANYM katalogom (Materials.test_dir_override, vzor D-88) —
  # fresh seed su UNI materialy BEZ smeru, na ktorych by sa otacanie nedalo
  # ani vyskusat.
  def k1_catalog_json
    sheet = lambda do |id, grain, extra|
      { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => "DEC-#{id}",
        'type' => 'DTDL', 'thickness' => 18.0, 'grain' => grain,
        'sheet_size' => [2800.0, 2070.0], 'color' => [200, 190, 170],
        'production_class' => 'sheet', 'group_id' => "GRP-#{id}", 'structure' => 'SM' }.merge(extra)
    end
    {
      'std' => 1, 'schema' => 2,
      'sheets' => [
        sheet.call('K1DUB18', 'length', {}),                            # dekor s kresbou
        sheet.call('K1UNI18', 'none', 'uni' => true, 'uni_role' => 'body')
      ],
      'edges' => [
        { 'abs_id' => 'K1E_DUB_23X10', 'decor' => 'DEC-K1DUB18', 'thickness' => 1.0,
          'width' => 23.0, 'color' => [120, 80, 40], 'group_id' => 'GRP-K1DUB18',
          'structure' => 'SM' }
      ]
    }
  end

  def k1_params(extra = {})
    { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
      'thickness' => 18.0, 'material_id' => 'K1DUB18', 'front_material_id' => 'K1DUB18',
      'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] },
      'zone_tree' => { 'id' => 'Z1', 'shelves' => 1, 'children' => [] } }.merge(extra)
  end

  def k1_part(inst, role)
    inst.definition.entities.grep(Sketchup::ComponentInstance)
        .find { |i| e::Store.kind(i) == 'part' && e::Store.get(i, 'role').to_s == role }
  end

  def k1_grain_of(inst, role)
    p = k1_part(inst, role)
    p ? (e::Store.config(p) || {})['grain_direction'].to_s : nil
  end

  def k1_override_of(inst, key)
    ov = (e::Store.config(inst) || {})['part_overrides'] || {}
    (ov[key] || {})['grain_direction']
  end

  # Vonkajsie rozmery kvadra dielca v mm (zoradene) — otocenie kresby ich
  # NESMIE zmenit ani o desatinu.
  def k1_box(part)
    return nil unless part && part.valid?
    b = part.definition.bounds
    [mm(b.width), mm(b.height), mm(b.depth)].map { |v| v.round(2) }.sort
  end

  # VEPO riadok TOHTO dielca — hlada sa cez presnu hrubku a mnozinu rozmerov.
  def k1_vepo_csv(model)
    collected = e::Bom.collect(model)
    bom = e::Bom.compute(collected)
    mats = e::Materials.sheets.each_with_object({}) { |s, o| o[s['material_id']] = s }
    eths = e::Materials.edges.each_with_object({}) { |a, o| o[a['abs_id']] = a['thickness'].to_f }
    res = e::VepoExport.build(bom[:rows], project: 'SU-TEST K1', materials: mats,
                              edge_thicknesses: eths, version: e::VERSION,
                              generated_at: '2026-08-21 00:00', merge_18_36: true)
    Array(res['groups']).map { |g| g['csv'].to_s }.join
  end

  def run_k1(model)
    cleanup(model)
    tmp = File.join(Dir.tmpdir, "noxun_k1_#{Process.pid}")
    FileUtils.mkdir_p(tmp)
    File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(k1_catalog_json))
    e::Materials.test_dir_override = tmp
    e::Materials.reload!
    hneda = e::Materials.su_edge_material_name('K1E_DUB_23X10')
    begin
      ok('K1: izolovany katalog aktivny (dekor s kresbou po dlzke)',
         (e::Materials.sheet('K1DUB18') || {})['grain'].to_s == 'length')

      inst = e::CabinetBuilder.build(model, k1_params)
      return ok('K1: vlozenie korpusu', false) unless inst

      cid = e::Store.get(inst, 'cabinet_id').to_s
      guid = e::Panel.model_guid(model)
      front = k1_part(inst, 'front_door')
      return ok('K1: korpus ma celo', false) unless front

      fkey = e::Store.get(front, 'part_key').to_s
      fcfg = e::Store.config(front) || {}
      box_before = k1_box(front)
      dims_before = [fcfg['length'].to_f.round(2), fcfg['width'].to_f.round(2)]

      # --- 1) DEDENIE = dnesne spravanie pred K1 -----------------------------
      ok("K1: celo bez zasahu dedi smer materialu (#{k1_grain_of(inst, 'front_door')})",
         k1_grain_of(inst, 'front_door') == 'length')
      pay = e::Panel.part_card_payload(model, inst, front) || {}
      ok("K1: karta hlasi zdedeny stav a VYSLEDOK (#{pay['grain_value']} / #{pay['grain_effective']})",
         pay['grain_value'] == 'inherit' && pay['grain_effective'] == 'length' &&
         pay['grain_locked'] == false)
      inh = Array(pay['grain_options']).find { |o| o['value'] == 'inherit' }
      ok("K1: volba „Podľa materiálu\" nesie VYSLEDOK, nie prazdne „dedí\" (#{inh && inh['label']})",
         inh && inh['label'].to_s.include?('pozdĺžna'))
      wopt = Array(pay['grain_options']).find { |o| o['value'] == 'width' }
      ok("K1: tooltip priecnej volby ukazuje VYROBNY rozmer (#{wopt && wopt['title']})",
         wopt && wopt['title'].to_s.include?("#{dims_before[1].round}×#{dims_before[0].round}"))

      # --- 2) ENUM GUARD: neznama hodnota nezapise NIC -----------------------
      e::Panel.select_only(model, front)
      cfg_before = e::Store.get(inst, 'config').to_s
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => 'diagonal',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      ok('K1: neznamy smer sa ODMIETNE — config sa nezmenil ani o bajt',
         e::Store.get(inst, 'config').to_s == cfg_before)

      # Codex #185 P1: surovy UI token `inherit` NIE JE sentinel dedenia —
      # server pozna `__inherit__`. Zhodu oboch stran zamyka headless test;
      # tu sa dokazuje, ze druha (tichá) cesta naozaj neexistuje.
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => 'inherit',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      ok('K1: surovy token „inherit" server NEPRIJIMA (jediny sentinel je __inherit__)',
         e::Store.get(inst, 'config').to_s == cfg_before)

      # --- 3) ZAPIS na zivej skrinke = PRESNE JEDEN krok Spat ----------------
      ents_before = model.entities.length
      e::Panel.select_only(model, front)
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => 'width',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      front2 = k1_part(inst, 'front_door')
      ok("K1: celo ma po zasahu PRIECNU kresbu (#{k1_grain_of(inst, 'front_door')})",
         k1_grain_of(inst, 'front_door') == 'width')
      ok('K1: override zije v configu korpusu (prezije rebuild aj ulozenie)',
         k1_override_of(inst, fkey) == 'width')
      ok('K1: zapis nevyrobil ziadny novy NOXUN objekt v modeli',
         model.entities.length == ents_before)

      # --- 4) GEOMETRIA SA NEHYBE — otaca sa VYSTUP, nie model ---------------
      fcfg2 = e::Store.config(front2) || {}
      ok("K1: rozmery dielca ostali GEOMETRICKE (#{fcfg2['length']}×#{fcfg2['width']})",
         [fcfg2['length'].to_f.round(2), fcfg2['width'].to_f.round(2)] == dims_before)
      ok('K1: kvader dielca v modeli ma nezmenene rozmery',
         k1_box(front2) == box_before)

      # --- 5) D-88 farbenie hran NEZMENENE ----------------------------------
      # Osi dielca su explicitny udaj deskriptora — smer dekoru sa ich netyka.
      # Keby otocenie hybalo osami, paska by po zmene kresby skocila na inu hranu.
      ok('K1: celo ma pasku na vsetkych 4 bocnych ploskach aj po otoceni kresby',
         [[0, :min], [0, :max], [2, :min], [2, :max]].all? { |a, s| d88_face_mat(front2, a, s) == hneda })
      ok('K1: velke dekorove plochy ostali bez materialu (D-88 kontrakt nedotknuty)',
         d88_face_mat(front2, 1, :min).nil? && d88_face_mat(front2, 1, :max).nil?)

      # --- 6) VEPO CSV nesie OTOCENY riadok ----------------------------------
      csv = k1_vepo_csv(model)
      want = "\"#{dims_before[1].round}\";"
      ok("K1: VEPO CSV zacina riadok celu OTOCENOU dlzkou (#{dims_before[1].round} mm)",
         csv.include?(want))
      ok("K1: povodna (geometricka) dlzka #{dims_before[0].round} mm je vo VEPO ako SIRKA",
         csv.include?("\";\"#{dims_before[0].round}\";"))

      # --- 7) JEDEN krok Spat vrati vsetko ----------------------------------
      Sketchup.undo
      inst = e::Panel.find_cabinet_by_id(model, cid)
      ok('K1: 1x Spat vratil smer aj override naraz (jedna operacia)',
         k1_grain_of(inst, 'front_door') == 'length' && k1_override_of(inst, fkey).nil?)

      # --- 8) KOPIA SKRINKY si override nesie -------------------------------
      e::Panel.select_only(model, k1_part(inst, 'front_door'))
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => 'width',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      # Kopia zdiela definiciu AJ cabinet_id — presne to, co robi Ctrl+C/Ctrl+V
      # v modeli (atributy nesie INSTANCIA, preto sa prenesu rucne);
      # `dedup_copies` jej potom pridelí nove ID a prestavi ju.
      e::ScaleWatch.guard do
        model.start_operation('SU-TEST K1 kopia', true)
        tr = inst.transformation * Geom::Transformation.translation(e::Units.vector(1000, 0, 0))
        copy = model.entities.add_instance(inst.definition, tr)
        %w[std kind id cabinet_id template_id role part_key_schema manufactured
           production_class config].each do |k|
          v = e::Store.get(inst, k)
          copy.set_attribute(e::Store::DICT, k, v) unless v.nil?
        end
        model.commit_operation
      end
      e::CabinetBuilder.dedup_copies(model)
      new_cab = cabinets(model).find { |c| e::Store.get(c, 'cabinet_id').to_s != cid }
      ok('K1: kopia skrinky dostala nove ID a prestavala sa', !new_cab.nil?)
      if new_cab
        ok("K1: kopia si NESIE priecnu kresbu (#{k1_grain_of(new_cab, 'front_door')})",
           k1_grain_of(new_cab, 'front_door') == 'width')
        new_key = e::Store.get(k1_part(new_cab, 'front_door'), 'part_key').to_s
        ok('K1: aj zaznam overridu presiel do configu kopie',
           k1_override_of(new_cab, new_key) == 'width')
      end

      # --- 9) ODPOJENY dielec drzi SVOJ snapshot -----------------------------
      inst = e::Panel.find_cabinet_by_id(model, cid)
      src = k1_part(inst, 'front_door')
      detached = nil
      e::ScaleWatch.guard do
        model.start_operation('SU-TEST K1 odpojeny dielec', true)
        detached = model.entities.add_instance(
          src.definition, Geom::Transformation.translation(e::Units.vector(0, 2000, 0))
        )
        # Kopia instancie zdiela definiciu, ale NOXUN atributy nesie INSTANCIA —
        # prenesieme ich, presne ako ked pouzivatel vytiahne dielec z korpusu.
        %w[std kind id part_id cabinet_id role name part_key part_key_schema role_key
           manufactured production_class config].each do |k|
          v = src.get_attribute(e::Store::DICT, k)
          detached.set_attribute(e::Store::DICT, k, v) unless v.nil?
        end
        model.commit_operation
      end
      # korpus sa VRATI na dedenie — odpojeny dielec sa uz neprestavuje
      e::Panel.select_only(model, k1_part(inst, 'front_door'))
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => '__inherit__',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      det_rec = e::Bom.collect(model)[:records].find do |r|
        r['owner_id'].to_s == cid && r['part_key'].to_s == fkey && r['grain_direction'] == 'width'
      end
      ok("K1: korpus je spat na dedeni (#{k1_grain_of(inst, 'front_door')}), " \
         'ODPOJENY dielec drzi svoj snapshot „width"',
         k1_grain_of(inst, 'front_door') == 'length' && !det_rec.nil?)
      detached.erase! if detached && detached.valid?

      # --- 10) UNI material: override sa NEMAZE, len neucinkuje --------------
      inst = e::Panel.find_cabinet_by_id(model, cid)
      e::Panel.select_only(model, k1_part(inst, 'front_door'))
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => 'width',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      e::Panel.select_only(model, k1_part(inst, 'front_door'))
      e::Panel.handle_set_part_material({ 'role_key' => fkey, 'material_id' => 'K1UNI18',
                                          'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      ufront = k1_part(inst, 'front_door')
      ok("K1: na materiali BEZ smeru je vysledok „none\" (#{k1_grain_of(inst, 'front_door')})",
         k1_grain_of(inst, 'front_door') == 'none')
      ok('K1: ulozeny override sa pritom NEZMAZAL (rozhodnutie pouzivatela prezije)',
         k1_override_of(inst, fkey) == 'width')
      upay = ufront ? (e::Panel.part_card_payload(model, inst, ufront) || {}) : {}
      ok("K1: karta segment ZAMKNE a povie preco (#{upay['grain_hint']})",
         upay['grain_locked'] == true && !upay['grain_hint'].to_s.empty?)

      # --- 10b) ZMENENY KATALOG: karta ukazuje SNAPSHOT, nie dopocet -------
      # Codex #185 P1. Dielec je postaveny s kresbou po dlzke; katalogu sa
      # potom `grain` prepise. Karta MUSI dalej hlasit to, s cim dielec ide do
      # VEPO (snapshot), prospektivny vysledok drzat bokom a rozpor PRIZNAT.
      inst = e::Panel.find_cabinet_by_id(model, cid)
      e::Panel.select_only(model, k1_part(inst, 'front_door'))
      e::Panel.handle_set_part_material({ 'role_key' => fkey, 'material_id' => 'K1DUB18',
                                          'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      e::Panel.select_only(model, k1_part(inst, 'front_door'))
      e::Panel.handle_set_part_grain({ 'role_key' => fkey, 'grain' => '__inherit__',
                                       'cabinet_id' => cid, 'model_guid' => guid }.to_json)
      inst = e::Panel.find_cabinet_by_id(model, cid)
      sfront = k1_part(inst, 'front_door')
      built = k1_grain_of(inst, 'front_door')
      # katalog sa zmeni POD dielcom — bez prestavby (vzor „otvorenie .skp na
      # stroji s inym katalogom")
      cat = k1_catalog_json
      cat['sheets'][0]['grain'] = 'width'
      File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(cat))
      e::Materials.reload!
      spay = sfront ? (e::Panel.part_card_payload(model, inst, sfront) || {}) : {}
      ok("K1: po zmene katalogu karta hlasi SNAPSHOT (#{spay['grain_effective']}), nie dopocet (#{spay['grain_pending']})",
         built == 'length' && spay['grain_effective'] == 'length' && spay['grain_pending'] == 'width')
      ok("K1: rozpor snapshot vs. katalog karta PRIZNA (#{spay['grain_hint']})",
         !spay['grain_hint'].to_s.empty? && spay['grain_hint'].to_s.include?('prestavbe'))
      File.binwrite(File.join(tmp, 'materials.json'), JSON.pretty_generate(k1_catalog_json))
      e::Materials.reload!

      # --- 11) STARA ZAKAZKA BEZ POLA: otvorenie nezapise NIC ---------------
      # Simulacia „otvorenia starej zakazky": config bez `grain_direction`
      # prejde CITACOU cestou panela (vyber -> karta) a nesmie sa zmenit.
      old = e::CabinetBuilder.build(model, k1_params('width' => 800.0))
      old_cfg = e::Store.get(old, 'config').to_s
      old_ents = model.entities.length
      e::Panel.select_only(model, old)
      e::Panel.push_selected(model)
      oldp = k1_part(old, 'front_door')
      e::Panel.select_only(model, oldp)
      e::Panel.push_selected(model)
      e::Panel.part_card_payload(model, old, oldp)
      ok('K1: otvorenie starej zakazky BEZ pola nezapisalo nic (config bajt-presne rovnaky)',
         e::Store.get(old, 'config').to_s == old_cfg && model.entities.length == old_ents)
      ok('K1: a v jej configu ziadny smer dekoru nepribudol',
         !old_cfg.include?('grain_direction'))
    ensure
      e::Materials.test_dir_override = nil
      e::Materials.reload!
      cleanup(model)
      begin
        FileUtils.rm_rf(tmp)
      rescue StandardError
        nil
      end
    end
    ok('K1: cleanup (override prec, model prazdny)',
       e::Materials.test_dir_override.nil? && cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: K1 vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    e::Materials.test_dir_override = nil
    e::Materials.reload!
    cleanup(model)
  end

  def run_smoke1(model)
    cleanup(model)
    tp = e::TemplatePreviews
    ts = e::TemplateStore
    ts.delete('cabinet', SMOKE1_NAME)

    cfg = { 'type' => 'lower', 'width' => 800.0, 'height' => 720.0, 'depth' => 560.0,
            'thickness' => 18.0, 'floor_height' => 100.0 }
    # Sablona vznikne BEZ nahladu (`preview` sa neodovzdava) — presne stav
    # starych sablon, kvoli ktorym akcia vznikla.
    ok('SMOKE1: sablona bez nahladu sa ulozila', ts.upsert('cabinet', SMOKE1_NAME, cfg))
    png = tp.path_for('cabinet', SMOKE1_NAME)
    ok('SMOKE1: sablona zacina BEZ nahladu', !File.exist?(png.to_s))
    rec_before = ts.find('cabinet', SMOKE1_NAME).to_json

    # --- 1) bez oznacenia: odmietnutie BEZ zapisu ---------------------------
    model.selection.clear
    okd, msg = e::Panel.capture_preview_for('cabinet', SMOKE1_NAME)
    ok('SMOKE1: bez oznacenej skrinky sa foti ODMIETNE', okd == false)
    info("SMOKE1: hlaska bez vyberu = #{msg.inspect}")
    ok('SMOKE1: odmietnutie nevyrobilo ziadny PNG', !File.exist?(png.to_s))

    inst = e::CabinetBuilder.build(model, cfg)
    return ok('SMOKE1: vlozenie skrinky', false) unless inst

    # --- 2) VIAC oznacenych skriniek: tiez odmietnutie ----------------------
    inst2 = e::CabinetBuilder.build(model, cfg.merge('width' => 600.0))
    # Odtlacok az TU — obe skrinky uz stoja, takze zmena poctu entit by mohla
    # pochadzat uz len z fotenia.
    before_ents = model.entities.length
    model.selection.clear
    model.selection.add([inst, inst2])
    okd2, msg2 = e::Panel.capture_preview_for('cabinet', SMOKE1_NAME)
    ok('SMOKE1: dve oznacene skrinky = ODMIETNUTIE (panel si nevyberie za pouzivatela)', okd2 == false)
    info("SMOKE1: hlaska pri viacerych = #{msg2.inspect}")
    ok('SMOKE1: ani tu nevznikol PNG', !File.exist?(png.to_s))

    # --- 3) PRAVE JEDNA oznacena: fotka vznikne, zaznam sa nezmeni ----------
    model.selection.clear
    model.selection.add(inst)
    view = model.active_view
    view.camera.perspective = true
    view.camera.set(Geom::Point3d.new(220, -320, 210), Geom::Point3d.new(0, 0, 20), Z_AXIS)
    view.camera.fov = 47.5
    cam_before = uid2_cam(view)

    okd3, msg3 = e::Panel.capture_preview_for('cabinet', SMOKE1_NAME)
    ok('SMOKE1: fotenie z prave jednej oznacenej skrinky prebehlo', okd3 == true)
    info("SMOKE1: hlaska po fotenie = #{msg3.inspect}")
    ok('SMOKE1: vznikol platny PNG nahlad', tp.valid_file?(png))
    ok('SMOKE1: ZAZNAM sablony sa fotenim NEZMENIL',
       ts.find('cabinet', SMOKE1_NAME).to_json == rec_before)
    ok('SMOKE1: zoznam sablon uz nesie reviziu nahladu',
       !e::Panel.template_list(previews: true)
                .find { |t| t['name'] == SMOKE1_NAME }['preview_rev'].nil?)
    ok('SMOKE1: kamera je po fotenie KOMPLETNE obnovena', uid2_cam_same?(cam_before, uid2_cam(view)))
    info("SMOKE1: rozdiel kamery: #{uid2_cam_diff(cam_before, uid2_cam(view))}") unless
      uid2_cam_same?(cam_before, uid2_cam(view))
    ok('SMOKE1: fotenie NEMENI model', model.entities.length == before_ents)
    ok('SMOKE1: fotenie NEMENI vyber', model.selection.to_a == [inst])

    # --- 4) doskova sablona sa nefoti ---------------------------------------
    okd4, = e::Panel.capture_preview_for('board', SMOKE1_NAME)
    ok('SMOKE1: doskova sablona sa nefoti', okd4 == false)
    okd5, = e::Panel.capture_preview_for('cabinet', 'SU-TEST neexistuje')
    ok('SMOKE1: neexistujuca sablona sa odmietne', okd5 == false)

    # --- 5) ZIADNY undo krok ------------------------------------------------
    # Poslednou MODELOVOU operaciou je vlozenie druhej skrinky — keby bolo
    # fotenie vlastnou operaciou, 1x Spat by vratilo JU.
    Sketchup.undo
    ok('SMOKE1: 1x Spat zmazal poslednu vlozenu skrinku — fotenie NIE JE undo krok',
       inst2.nil? || !inst2.valid?)

    cleanup(model)
  rescue StandardError => ex
    log_line("FAIL: SMOKE1 sekcia vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
  ensure
    begin
      e::TemplateStore.delete('cabinet', SMOKE1_NAME)
    rescue StandardError
      nil
    end
  end

  def run_async(model, done)
    state = {}
    steps = []

    # S1: scale -> absorpcia -> undo
    steps << [0.1, lambda do
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0 })
      state[:s1] = inst
      # simulacia pouzivatelskeho Scale: 1 operacia, zmena transformacie (observer NIE je guardnuty)
      model.start_operation('SU-TEST user scale', true)
      inst.transformation = inst.transformation * Geom::Transformation.scaling(ORIGIN, 1.5, 1.0, 1.0)
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      inst = state[:s1]
      cfg = e::Store.config(inst) || {}
      absorbed = (cfg['width'].to_f - 900.0).abs < 0.01
      clean = e::ScaleWatch.scale_factors(inst.transformation).nil?
      ok("async S1: absorpcia scale (600 -> #{cfg['width']}, transform cisty=#{clean})", absorbed && clean)
      Sketchup.undo # vrat absorpcny rebuild
    end]
    steps << [SETTLE, lambda do
      # V0.3.4 undo fix: absorpcia je transparentna operacia pripojena k Scale kroku,
      # takze 1x undo MUSI vratit scale aj absorpciu naraz (sirka 600, cisty transform)
      # a observer uz nema co re-absorbovat. Tvrdy assert (predtym INFO pozorovanie).
      inst = state[:s1]
      if inst && inst.valid?
        cfg = e::Store.config(inst) || {}
        w = cfg['width'].to_f
        clean = e::ScaleWatch.scale_factors(inst.transformation).nil?
        ok("async S1: 1x undo vratil scale AJ absorpciu (sirka #{cfg['width']}, transform cisty=#{clean})",
           (w - 600.0).abs < 0.01 && clean)
      else
        ok('async S1: instancia po undo existuje', false)
      end
      # Redo (Codex review PR #20): po undo mohli nove operacie (re-absorpcia, ghost presuny)
      # zmazat redo stack — presne 3. audit riziko. send_action je asynchronne -> pozorovanie
      # v dalsom kroku. Nazov akcie je cross-platform 'editRedo'.
      state[:s1_redo_sent] = Sketchup.send_action('editRedo')
    end]
    steps << [SETTLE, lambda do
      inst = state[:s1]
      if !state[:s1_redo_sent]
        info('S1 REDO: send_action editRedo nedostupne na tejto platforme — redo netestovane.')
      elsif inst && inst.valid?
        cfg = e::Store.config(inst) || {}
        info("S1 REDO: stav po redo — sirka #{cfg['width']}, transform cisty=#{e::ScaleWatch.scale_factors(inst.transformation).nil?}. " \
             'Ak sa sirka nezmenila, redo stack bol zmazany operaciami observera po undo (audit riziko #3).')
      else
        info('S1 REDO: instancia po redo neexistuje — preverit rucne.')
      end
      cleanup(model)
    end]

    # S2: kopia -> observer dedup -> undo
    steps << [0.5, lambda do
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 500.0, 'height' => 720.0, 'depth' => 510.0 })
      state[:s2] = inst
      state[:s2_cid] = e::Store.get(inst, 'cabinet_id')
      # simulacia Ctrl+C/V: nova instancia + NOXUN atributy v JEDNEJ operacii (observer NIE je guardnuty)
      model.start_operation('SU-TEST user copy', true)
      tr = inst.transformation * Geom::Transformation.translation(e::Units.vector(700, 0, 0))
      copy = model.entities.add_instance(inst.definition, tr)
      %w[std kind id cabinet_id template_id role part_key_schema manufactured production_class config].each do |k|
        v = e::Store.get(inst, k)
        copy.set_attribute('NOXUN', k, v) unless v.nil?
      end
      state[:s2_copy] = copy
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      copy = state[:s2_copy]
      new_cid = copy && copy.valid? ? e::Store.get(copy, 'cabinet_id') : nil
      orig_ok = state[:s2] && state[:s2].valid? && e::Store.get(state[:s2], 'cabinet_id') == state[:s2_cid]
      ok("async S2: observer dedup kopie (#{state[:s2_cid]} -> #{new_cid})",
         !new_cid.nil? && new_cid != state[:s2_cid] && orig_ok)
      Sketchup.undo # vrat dedup rebuild (posledna operacia)
    end]
    steps << [SETTLE, lambda do
      # V0.3.4 undo fix: dedup (identita + rebuild) je transparentna operacia pripojena
      # k paste kroku — 1x undo MUSI odstranit kopiu CELU (ziadny medzistav s novym cid).
      # Original ostava so svojim cid. Tvrdy assert (predtym INFO pozorovanie).
      copy = state[:s2_copy]
      copy_gone = copy.nil? || !copy.valid?
      orig_ok = state[:s2] && state[:s2].valid? && e::Store.get(state[:s2], 'cabinet_id') == state[:s2_cid]
      cids = cabinets(model).map { |i| e::Store.get(i, 'cabinet_id') }
      ok("async S2: 1x undo vratil kopiu CELU (kopia prec=#{copy_gone}, original #{state[:s2_cid]} drzi, korpusy: #{cids.sort.join(', ')})",
         copy_gone && orig_ok && cids == [state[:s2_cid]])
      state[:s2_redo_sent] = Sketchup.send_action('editRedo')
    end]
    steps << [SETTLE, lambda do
      copy = state[:s2_copy]
      if !state[:s2_redo_sent]
        info('S2 REDO: send_action editRedo nedostupne — redo netestovane.')
      elsif copy && copy.valid?
        info("S2 REDO: stav po redo — kopia cid '#{e::Store.get(copy, 'cabinet_id')}', original cid '#{state[:s2] && state[:s2].valid? ? e::Store.get(state[:s2], 'cabinet_id') : '?'}'.")
      else
        info('S2 REDO: kopia po redo neexistuje.')
      end
      cleanup(model)
    end]

    # S3 (V0.4.7b): kopia DOSKY -> observer dedup (nove BRD id, transparent) -> undo
    steps << [0.5, lambda do
      binst = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                             'length' => 400.0, 'width' => 300.0 })
      state[:s3] = binst
      state[:s3_bid] = e::Store.get(binst, 'id')
      # simulacia Ctrl+C/V: nova instancia + NOXUN atributy v JEDNEJ operacii (observer NIE je guardnuty)
      model.start_operation('SU-TEST user copy board', true)
      tr = binst.transformation * Geom::Transformation.translation(e::Units.vector(500, 0, 0))
      bcopy = model.entities.add_instance(binst.definition, tr)
      %w[std kind id part_id part_key part_key_schema role name manufactured production_class config].each do |k|
        v = e::Store.get(binst, k)
        bcopy.set_attribute('NOXUN', k, v) unless v.nil?
      end
      state[:s3_copy] = bcopy
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      copy = state[:s3_copy]
      new_id = copy && copy.valid? ? e::Store.get(copy, 'id') : nil
      orig_ok = state[:s3] && state[:s3].valid? && e::Store.get(state[:s3], 'id') == state[:s3_bid]
      ok("async S3: observer dedup kopie dosky (#{state[:s3_bid]} -> #{new_id})",
         !new_id.nil? && new_id != state[:s3_bid] && orig_ok)
      Sketchup.undo # dedup je transparentny k paste kroku -> 1x undo ma vratit kopiu celu
    end]
    steps << [SETTLE, lambda do
      copy = state[:s3_copy]
      copy_gone = copy.nil? || !copy.valid?
      orig_ok = state[:s3] && state[:s3].valid? && e::Store.get(state[:s3], 'id') == state[:s3_bid]
      bids = boards(model).map { |i| e::Store.get(i, 'id') }
      ok("async S3: 1x undo vratil kopiu dosky CELU (kopia prec=#{copy_gone}, dosky: #{bids.sort.join(', ')})",
         copy_gone && orig_ok && bids == [state[:s3_bid]])
      cleanup(model)
    end]

    # S4 (Codex GH review PR #32, P2): MIESANA davka — stara duplicita (vytvorena
    # v guarde, observer ju nevidel) + cerstva kopia v jednom debounce okne.
    # Paste tick spracuje LEN cerstvu (transparent na paste); staru prevezme
    # follow-up tick ako samostatny krok. Assert = konvergencia identity
    # (3 dosky -> 3 unikatne ID); undo poradie mixed davky je dokumentovany
    # kompromis a netestuje sa.
    steps << [0.5, lambda do
      b1 = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                          'length' => 350.0, 'width' => 250.0 })
      state[:s4] = b1
      state[:s4_bid] = e::Store.get(b1, 'id')
      attrs = %w[std kind id part_id part_key part_key_schema role name manufactured production_class config]
      # STALA duplicita: kopia v guarde — observer tick nepribehne, zdielane ID ostava
      e::ScaleWatch.guard do
        model.start_operation('SU-TEST stale copy board', true)
        sc = model.entities.add_instance(b1.definition,
                                         b1.transformation * Geom::Transformation.translation(e::Units.vector(450, 0, 0)))
        attrs.each { |k| v = e::Store.get(b1, k); sc.set_attribute('NOXUN', k, v) unless v.nil? }
        state[:s4_stale] = sc
        model.commit_operation
      end
      # CERSTVA kopia: user operacia BEZ guardu -> observer tick s fresh_ids
      model.start_operation('SU-TEST user copy board 2', true)
      fc = model.entities.add_instance(b1.definition,
                                       b1.transformation * Geom::Transformation.translation(e::Units.vector(900, 0, 0)))
      attrs.each { |k| v = e::Store.get(b1, k); fc.set_attribute('NOXUN', k, v) unless v.nil? }
      state[:s4_fresh] = fc
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      # SETTLE (1.2 s) pokryva paste tick (0.2 s) aj follow-up tick (0.4 s).
      trio = [state[:s4], state[:s4_stale], state[:s4_fresh]]
      ids = trio.map { |i| i && i.valid? ? e::Store.get(i, 'id') : nil }
      ok("async S4: mixed stale+fresh — konvergencia na 3 unikatne ID (#{ids.compact.sort.join(', ')})",
         ids.compact.length == 3 && ids.uniq.length == 3 && ids.include?(state[:s4_bid]))
      cleanup(model)
    end]

    # D-34 (davka Vkladanie, audit F9): zmazanie OZNACENEJ skrinky -> observer
    # erase tick (notify_erase -> process_dirty po prune) -> Panel.push_selected
    # -> NX.clearSelected. Dokaz VYHRADNE cez recorder na Panel.js — zatvoreny
    # panel je no-op a prazdny SketchUp vyber NIE JE dokaz.
    steps << [0.5, lambda do
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                              'height' => 720.0, 'depth' => 510.0 })
      state[:d34] = inst
      e::Panel.select_only(model, inst)
      state[:d34_rec] = []
      install_js_recorder(state[:d34_rec])
      # simulacia pouzivatelskeho Delete: erase v JEDNEJ operacii BEZ guardu
      model.start_operation('SU-TEST user delete', true)
      inst.erase!
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      remove_js_recorder
      rec = state[:d34_rec] || []
      cleared = rec.any? { |s| s.include?('NX.clearSelected') }
      ok("async D34: erase oznacenej skrinky poslal NX.clearSelected (#{rec.length} js volani)", cleared)
      ok('async D34: skrinka je prec a resolvery nepadli na mrtvej entite',
         cabinets(model).empty?)
      cleanup(model)
    end]

    # D-101: panel sa po Spat/Znova obnovi SAM (PanelModelObserver).
    # Chyba: Ctrl+Z zmenil model, ale ziadny selection event nepride — Inspector
    # visel na predoslom stave az do prekliku vyberu. Scenar ide presne cez
    # observer (Sketchup.undo), nie cez priame volanie handlera.
    steps << [0.5, lambda do
      st = d101_state
      state[:d101] = st
      state[:d101_prev_dialog] = e::Panel.instance_variable_get(:@dialog)
      state[:d101_model] = model
      state[:d101_active] = true
      e::Panel.instance_variable_set(:@dialog, D101FakeDialog.new)
      d101_install_probe(st)
      state[:d101_js] = []
      install_js_recorder(state[:d101_js])
      e::Panel.attach_observer
      ok('D101: attach pripojil observer transakcii a zapamatal si model',
         !e::Panel.instance_variable_get(:@model_observer).nil? &&
         e::Panel.instance_variable_get(:@observer_model) == model)
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                              'height' => 720.0, 'depth' => 510.0 })
      state[:d101_cab] = inst
      e::Panel.select_only(model, inst)
      d101_rebuild(model, inst, 800.0)
      d101_reset(st)
      state[:d101_js].clear
      Sketchup.undo # UZIVATELSKY Ctrl+Z — ziadny selection event nepride
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      w = d101_width(state[:d101_cab])
      ok("D101: undo vratil sirku korpusu (800 -> #{w})", w && (w - 600.0).abs < 0.01)
      ok("D101: undo vstupil do handlera panela (#{st[:txn]}x) a odlozeny refresh prebehol (#{st[:flush]}x)",
         st[:txn] >= 1 && st[:flush] >= 1)
      ok("D101: refresh z observera bezal PRESNE raz a s dedup:false — ziadna mutacia modelu (#{st[:flush_dedups].inspect})",
         st[:flush_dedups] == [false])
      ok("D101: Inspector dostal cerstvy stav (#{state[:d101_js].length} js volani)",
         state[:d101_js].any? { |s| s.include?('NX.loadSelected') || s.include?('NX.clearSelected') })
      # COALESCING: dve rychle Ctrl+Z za sebou = JEDEN push najnovsieho stavu.
      inst = state[:d101_cab]
      d101_rebuild(model, inst, 800.0)
      d101_rebuild(model, inst, 900.0)
      d101_reset(st)
      state[:d101_js].clear
      Sketchup.undo
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      w = d101_width(state[:d101_cab])
      ok("D101: dve rychle undo = 2 udalosti, ale JEDEN push najnovsieho stavu (txn #{st[:txn]}, flush #{st[:flush]}, pushov #{st[:flush_pushes]}, sirka #{w})",
         st[:txn] == 2 && st[:flush] == 1 && st[:flush_pushes] == 1 && w && (w - 600.0).abs < 0.01)
      # REDO — `onTransactionRedo` musi ist tou istou cestou. Undo aj redo bezia
      # v JEDNOM kroku: medzi ne sa tak NEZMESTI debounce tick ScaleWatchu, ktory
      # by transparentnou operaciou vymazal redo stack.
      # VRSTVENY pristup (Ruby API nema na Windows spolahlivu redo akciu — vid
      # PLAN, blok STABILITA; `Sketchup.redo` v API vobec nie je): skusi sa
      # 1) send_action('editRedo') — funguje na macOS, 2) legacy numericke ID
      # Windows prikazu Redo, 3) priama invokacia callbacku observera.
      # KVALIFIKACIA CESTY JE PODLA UCINKU, NIE PODLA NAVRATOVEJ HODNOTY:
      # send_action(21836) na tomto builde vrati true a NESPRAVI NIC (falosny
      # pozitiv, beh c. 4) — preto sa v dalsom kroku ceka na skutocny ucinok
      # (sirka spat na 850 + prirastok vstupov do handlera) a bez neho sa
      # prepadne na cestu 3. Pouzita cesta sa vzdy prizna v logu.
      inst = state[:d101_cab]
      d101_rebuild(model, inst, 850.0)
      d101_reset(st)
      state[:d101_js].clear
      Sketchup.undo # 850 -> 600
      state[:d101_redo_sent] =
        if d101_send_action('editRedo') then :action_name
        elsif d101_send_action(21836) then :action_id
        end
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      w = d101_width(state[:d101_cab])
      sent = state[:d101_redo_sent]
      # UCINOK = model sa naozaj vratil do 850 A handler dostal dalsi vstup
      # (undo + redo). Samotne „akcia bola prijata" nestaci.
      effect = w && (w - 850.0).abs < 0.01 && st[:txn] >= 2
      if sent && effect
        info("D101 REDO: pouzita cesta #{sent == :action_name ? "send_action('editRedo')" : 'send_action(21836) — legacy Windows ID prikazu Redo'}")
        ok("D101: redo vratilo zmenu SPAT a panel sa obnovil tou istou cestou (sirka #{w}, txn #{st[:txn]}, refreshov #{st[:flush]}, dedup #{st[:flush_dedups].inspect})",
           st[:flush] >= 1 && !st[:flush_dedups].empty? && st[:flush_dedups].all? { |d| d == false })
      else
        # Windows: ziadna redo akcia Ruby API realne nezabrala. Model teda redo
        # nespravi, ale ZAPOJENIE onTransactionRedo -> pending -> timer ->
        # push_selected sa da overit tvrdo — invokaciou callbacku na SKUTOCNOM
        # observer objekte, ktory drzi Panel. Skutocne Ctrl+Y z klavesnice
        # overuje Michal rucne (otvoreny bod „redo po zlucenych transparentnych
        # operaciach" v PLAN, blok STABILITA).
        if sent
          info("D101 REDO: #{sent == :action_name ? "send_action('editRedo')" : 'send_action(21836)'} vratilo true, ale BEZ UCINKU " \
               "(sirka #{w}, vstupov do handlera #{st[:txn]}) — prepadam na priamu invokaciu.")
        else
          info('D101 REDO: ani editRedo, ani legacy ID neboli prijate — prepadam na priamu invokaciu.')
        end
        # Cesta 2 mohla stav rozbehnut (ciastocny/oneskoreny ucinok) — pred
        # cestou 3 obnovime vychodisko scenara, nech jej asserty meraju cisto:
        # sirka 600 po undo a vynulovane pocitadla.
        inst = state[:d101_cab]
        d101_rebuild(model, inst, 600.0) if inst && inst.valid? && w && (w - 600.0).abs >= 0.01
        obs = e::Panel.instance_variable_get(:@model_observer)
        state[:d101_direct] = true
        ok('D101: observer transakcii je drzany v Paneli (bez neho by redo cestu nebolo na com overit)', !obs.nil?)
        d101_reset(st)
        state[:d101_js].clear
        obs.onTransactionRedo(model) if obs
      end
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      if state[:d101_direct]
        w = d101_width(state[:d101_cab])
        ok("D101: redo handler cez priamu invokaciu (Windows bez redo akcie) — pending -> timer -> jeden push s dedup:false (txn #{st[:txn]}, refreshov #{st[:flush]}, pushov #{st[:flush_pushes]}, dedup #{st[:flush_dedups].inspect})",
           st[:txn] == 1 && st[:flush] == 1 && st[:flush_pushes] == 1 && st[:flush_dedups] == [false])
        ok("D101: priama invokacia doniesla Inspectoru cerstvy stav (#{state[:d101_js].length} js volani)",
           state[:d101_js].any? { |s| s.include?('NX.loadSelected') || s.include?('NX.clearSelected') })
        ok("D101: priama invokacia NEsiahla na model — vychodisko scenara drzi (sirka #{w})",
           w && (w - 600.0).abs < 0.01)
      end
      # ZIADNY NOVY UNDO KROK: po refreshi musi dalsi Ctrl+Z odstranit CELE vlozenie.
      cleanup(model)
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                              'height' => 720.0, 'depth' => 510.0 })
      state[:d101_cab] = inst
      e::Panel.select_only(model, inst)
      d101_rebuild(model, inst, 800.0)
      d101_reset(st)
      Sketchup.undo # 1. undo: rebuild (refresh panela bezi v timeri)
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      w = d101_width(state[:d101_cab])
      ok("D101: 1. undo vratil rebuild a refresh prebehol (sirka #{w}, flush #{st[:flush]})",
         w && (w - 600.0).abs < 0.01 && st[:flush] >= 1)
      d101_reset(st)
      Sketchup.undo # 2. undo: ak by refresh pridal vlastnu operaciu, tento krok by vratil JU
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      ok("D101: refresh z observera NEPRIDAL undo krok — 2. undo odstranil cele vlozenie (#{cabinets(model).length} korpusov)",
         cabinets(model).empty?)
      ok("D101: aj undo vlozenia obnovil panel s dedup:false (#{st[:flush_dedups].inspect})",
         st[:txn] >= 1 && st[:flush_dedups] == [false])
      # DETACH (zatvorenie panela): ziadny vstup do handlera — dokaz je POCITADLO
      # vstupov, nie „neprisiel push" (handler by aj tak skoncil na guarde).
      e::Panel.detach_observer
      d101_reset(st)
      state[:d101_cab] = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                                          'height' => 720.0, 'depth' => 510.0 })
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      ok("D101: po detachi neprisiel do handlera ANI JEDEN vstup (#{st[:txn]}) — observer je naozaj odvesany",
         st[:txn].zero?)
      ok('D101: undo po detachi normalne odstranil korpus', cabinets(model).empty?)
      # ANTI-DOUBLE: dvojity attach nesmie dorucit udalost dvakrat.
      e::Panel.attach_observer
      e::Panel.attach_observer
      inst = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                              'height' => 720.0, 'depth' => 510.0 })
      state[:d101_cab] = inst
      d101_rebuild(model, inst, 800.0)
      d101_reset(st)
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      ok("D101: dvojity attach = PRESNE jeden vstup do handlera (#{st[:txn]}) — ziadny double-attach",
         st[:txn] == 1)
      # MULTI-MODEL GUARD: udalost z INEHO dokumentu Inspector aktivneho neprepise.
      e::Panel.instance_variable_set(:@observer_model, Object.new)
      d101_reset(st)
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      ok("D101: udalost z ineho dokumentu sa zastavi na guarde (vstupov #{st[:txn]}, refreshov #{st[:flush]}, pushov #{st[:flush_pushes]})",
         st[:txn] >= 1 && st[:flush].zero? && st[:flush_pushes].zero?)
      # ODLOZENY callback: guard sa overuje ZNOVA tesne pred pushom — dokument
      # sa moze prepnut medzi udalostou a timerom.
      e::Panel.instance_variable_set(:@observer_model, model)
      d101_reset(st)
      e::Panel.on_model_txn(model) # pending naplanovany nad AKTIVNYM modelom
      e::Panel.instance_variable_set(:@observer_model, Object.new) # ...a teraz sa dokument prepne
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      ok("D101: odlozeny refresh po prepnuti dokumentu Inspector NEPREPISAL (refreshov #{st[:flush]}, pushov #{st[:flush_pushes]})",
         st[:flush] == 1 && st[:flush_pushes].zero?)
      # ZLYHANIE PRVEHO REMOVE: druhy observer sa MUSI odvesit aj tak (BLOCKER A).
      e::Panel.instance_variable_set(:@observer_model, D101FailingSelectionModel.new(model))
      e::Panel.detach_observer
      ok('D101: detach po zlyhani prveho remove dobehol a vynuloval model',
         e::Panel.instance_variable_get(:@observer_model).nil?)
      d101_reset(st)
      state[:d101_cab] = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                                          'height' => 720.0, 'depth' => 510.0 })
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      st = state[:d101]
      ok("D101: zlyhanie remove observera vyberu NEPRESKOCILO odvesenie ModelObservera (vstupov #{st[:txn]})",
         st[:txn].zero?)
      # Po failure-probe VISI realny observer VYBERU na modeli (jeho remove
      # simulovane zlyhal) a @observer_model je vynulovany. Odvesit ho treba
      # VZDY — aj ked panel nebol otvoreny; inak by S5/S6 bezali s kontaminovanym
      # observerom (kazda zmena vyberu = ziadost o dedup = zasah do modelu).
      e::Panel.instance_variable_set(:@observer_model, model)
      e::Panel.detach_observer
      probe = e::CabinetBuilder.build(model, { 'type' => 'lower', 'width' => 600.0,
                                               'height' => 720.0, 'depth' => 510.0 })
      d101_reset(st)
      e::Panel.select_only(model, probe) # zmena vyberu: klik + zrusenie
      model.selection.clear
      ok("D101: po failure-probe uz na modeli NEVISI observer vyberu (vstupov do sync vyberu: #{st[:sel]})",
         st[:sel].zero?)
      d101_teardown(state) # vrati Panel do povodneho stavu (dialog + observery)
      cleanup(model)
      ok('D101: cleanup (0 korpusov, sonda odstranena)',
         cabinets(model).empty? && !e::Panel.singleton_class.method_defined?(:nx_d101_txn))
    end]

    # S5 (V0.4.7d): scale absorpcia DOSKY — X/Y sa preberaju do length/width,
    # hrubku RIADI material (Z faktor sa zahadzuje), reject pri neplatnom rebuilde.
    steps << [0.5, lambda do
      b = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                         'length' => 400.0, 'width' => 300.0 })
      state[:s5] = b
      model.start_operation('SU-TEST user scale board X', true)
      b.transformation = b.transformation * Geom::Transformation.scaling(ORIGIN, 1.5, 1.0, 1.0)
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      b = state[:s5]
      cfg = e::Store.config(b) || {}
      clean = e::ScaleWatch.scale_factors(b.transformation).nil?
      ok("async S5: absorpcia X scale dosky (400 -> #{cfg['length']}, sirka #{cfg['width']}, hrubka #{cfg['thickness']}, transform cisty=#{clean})",
         (cfg['length'].to_f - 600.0).abs < 0.01 && (cfg['width'].to_f - 300.0).abs < 0.01 &&
         (cfg['thickness'].to_f - 18.0).abs < 0.01 && clean)
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      b = state[:s5]
      cfg = e::Store.config(b) || {}
      clean = e::ScaleWatch.scale_factors(b.transformation).nil?
      ok("async S5: 1x undo vratil scale AJ absorpciu dosky (dlzka #{cfg['length']}, cisty=#{clean})",
         (cfg['length'].to_f - 400.0).abs < 0.01 && clean)
      # postav dosku NAVISLO (rotacia 90° okolo X — lokalna Y mieri do globalnej Z)
      model.start_operation('SU-TEST rotate board upright', true)
      b.transformation = b.transformation * Geom::Transformation.rotation(ORIGIN, Geom::Vector3d.new(1, 0, 0), 90.degrees)
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      b = state[:s5]
      # GLOBALNY Z scale vertikalnej dosky = tah za jej lokalnu Y (sirku)
      model.start_operation('SU-TEST user scale board global Z', true)
      b.transformation = Geom::Transformation.scaling(ORIGIN, 1.0, 1.0, 1.4) * b.transformation
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      b = state[:s5]
      cfg = e::Store.config(b) || {}
      ok("async S5: globalny Z scale VERTIKALNEJ dosky = lokalna sirka (300 -> #{cfg['width']}, dlzka #{cfg['length']})",
         (cfg['width'].to_f - 420.0).abs < 0.01 && (cfg['length'].to_f - 400.0).abs < 0.01)
      # kombinovany lokalny X+Z scale: dlzka sa preberie, hrubka NIE (riadi ju material)
      model.start_operation('SU-TEST user scale board X+Z', true)
      b.transformation = b.transformation * Geom::Transformation.scaling(ORIGIN, 1.25, 1.0, 2.0)
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      b = state[:s5]
      cfg = e::Store.config(b) || {}
      tb = b.definition.bounds
      ok("async S5: X+Z scale — dlzka prevzata (#{cfg['length']}), hrubka drzi material (cfg #{cfg['thickness']}, geo #{mm(tb.depth).round(1)})",
         (cfg['length'].to_f - 500.0).abs < 0.01 && (cfg['thickness'].to_f - 18.0).abs < 0.01 &&
         (mm(tb.depth) - 18.0).abs <= TOL)
      # REJECT scenar (Codex audit d, blocker 1): material zmizne z katalogu ->
      # absorpcia musi scale VRATIT (nie absorbovat ani nechat skoseny stav).
      # PRESNY povodny zaznam si odlozime a vratime (Codex GH #34): pri manualnom
      # spusteni runnera z konzoly bezi test nad REALNYM %APPDATA% katalogom —
      # hardcoded seed by prepisal pouzivatelske upravy (ceny, formaty...).
      state[:s5_saved_sheet] = e::JsonFileStore.deep_copy(e::Materials.sheet('K009_PW_DTDL_18'))
      e::Materials.delete_sheet('K009_PW_DTDL_18')
      model.start_operation('SU-TEST user scale board no-material', true)
      b.transformation = b.transformation * Geom::Transformation.scaling(ORIGIN, 1.5, 1.0, 1.0)
      model.commit_operation
    end]
    steps << [SETTLE, lambda do
      b = state[:s5]
      cfg = e::Store.config(b) || {}
      clean = e::ScaleWatch.scale_factors(b.transformation).nil?
      ok("async S5: reject bez katalogoveho materialu — config drzi (#{cfg['length']}) a transform je vrateny cisty (#{clean})",
         (cfg['length'].to_f - 500.0).abs < 0.01 && clean && b.valid?)
      # obnov PRESNY povodny zaznam (nie seed — respektuje pouzivatelske upravy)
      e::Materials.upsert_sheet(state[:s5_saved_sheet]) if state[:s5_saved_sheet]
      cleanup(model)
    end]

    # S6 (D-103, Codex audit FIX 7): NASOBENIE KOPII `*N`. Realna chyba:
    # Move+Ctrl kopia s OTVORENYM Inspectorom -> selection callback spustil
    # netransparentny dedup -> ten sa stal vrcholom undo stacku -> ked pouzivatel
    # dopisal `*4`, Move nastroj svoju operaciu PREPISAL (interne undo + nove
    # kopie) a undo trafilo NASU operaciu: kopia prezila a nasobenie polozilo
    # dalsiu na to iste miesto (6 dosiek namiesto 5, dva dielce vo vystupoch).
    # Scenar ide presne touto cestou vratane Panel.push_selected.
    steps << [0.8, lambda do
      b = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                         'length' => 400.0, 'width' => 300.0 })
      state[:s6] = b
      state[:s6_bid] = e::Store.get(b, 'id')
      attrs = %w[std kind id part_id part_key part_key_schema role name manufactured production_class config]
      model.start_operation('SU-TEST user move+ctrl copy', true)
      cp = model.entities.add_instance(b.definition,
                                       b.transformation * Geom::Transformation.translation(e::Units.vector(200, 0, 0)))
      attrs.each { |k| v = e::Store.get(b, k); cp.set_attribute('NOXUN', k, v) unless v.nil? }
      model.commit_operation
      state[:s6_copy] = cp
      # PRESNA cesta otvoreneho Inspectora: SelObserver -> Panel.push_selected.
      # Po D-103 uz NESMIE vykonat vlastnu (netransparentnu) operaciu.
      e::Panel.select_only(model, cp)
      e::Panel.push_selected(model)
    end]
    steps << [SETTLE, lambda do
      cp = state[:s6_copy]
      new_id = cp && cp.valid? ? e::Store.get(cp, 'id') : nil
      ok("async S6: kopia dostala nove ID aj bez dedupu vo vybere (#{state[:s6_bid]} -> #{new_id})",
         !new_id.nil? && new_id != state[:s6_bid])
      # `*4` nasobenie: SketchUp najprv ODUNDUJE svoju kopirovaciu operaciu
      Sketchup.undo
    end]
    steps << [SETTLE, lambda do
      cp = state[:s6_copy]
      gone = cp.nil? || !cp.valid?
      bids = boards(model).map { |i| e::Store.get(i, 'id') }
      # JADRO OPRAVY: interne undo nastroja musi trafit KOPIU, nie nasu operaciu.
      ok("async S6: interne undo nasobenia odstranilo kopiu CELU — ziadna zombie (kopia prec=#{gone}, dosky: #{bids.sort.join(', ')})",
         gone && bids == [state[:s6_bid]])
      # ...a teraz nastroj polozi pole 4 kopii v JEDNEJ operacii
      b = state[:s6]
      attrs = %w[std kind id part_id part_key part_key_schema role name manufactured production_class config]
      model.start_operation('SU-TEST user copy array *4', true)
      [200.0, 400.0, 600.0, 800.0].each do |dx|
        c = model.entities.add_instance(b.definition,
                                        b.transformation * Geom::Transformation.translation(e::Units.vector(dx, 0, 0)))
        attrs.each { |k| v = e::Store.get(b, k); c.set_attribute('NOXUN', k, v) unless v.nil? }
      end
      model.commit_operation
      e::Panel.push_selected(model) # selection sync po nasobeni
    end]
    steps << [SETTLE, lambda do
      bs = boards(model)
      ids = bs.map { |i| e::Store.get(i, 'id') }
      origins = bs.map { |i| o = i.transformation.origin; [mm(o.x).round(3), mm(o.y).round(3), mm(o.z).round(3)] }
      ok("async S6: po `*4` je presne 5 dosiek s 5 unikatnymi ID (#{ids.sort.join(', ')})",
         bs.length == 5 && ids.compact.uniq.length == 5)
      ok("async S6: ziadne dve dosky nestoja na tom istom mieste (#{origins.map { |o| o[0] }.sort.join(', ')})",
         origins.uniq.length == origins.length)
      state[:s6_dump] = origins
      cleanup(model)
    end]

    # S6b: zachytna siet v KONTROLE — ked uz dva kusy na jednom mieste vzniknu
    # (starsi projekt, paste-in-place), semafor ich MUSI ukazat. Overuje CELU
    # retaz Bom.collect -> Validation.run(placements:), nielen cistu funkciu.
    steps << [0.5, lambda do
      b1 = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                          'length' => 400.0, 'width' => 300.0 })
      b2 = e::BoardBuilder.build(model, { 'material_id' => 'K009_PW_DTDL_18',
                                          'length' => 400.0, 'width' => 300.0 })
      state[:s6b] = [b1, b2]
      # polož druhu PRESNE na prvu (guard: nejde o kopiu, ID su rozne)
      e::ScaleWatch.guard do
        model.start_operation('SU-TEST paste-in-place', true)
        b2.transformation = b1.transformation
        model.commit_operation
      end
    end]
    steps << [SETTLE, lambda do
      collected = e::Bom.collect(model)
      pl = Array(collected[:placements])
      out = e::Validation.run(collected, sheets: {}, placements: pl)
      dups = out['items'].select { |i| i['category'] == e::Validation::CAT_DUPLICATE }
      ids = state[:s6b].map { |i| e::Store.get(i, 'id') }.sort
      ok("async S6b: Bom.collect zbiera umiestnenia (#{pl.length} zaznamov, druhy: #{pl.map { |p| p['kind'] }.uniq.join(',')})",
         pl.length >= 2 && pl.all? { |p| p['origin'].is_a?(Array) && p['axes'].length == 9 })
      ok("async S6b: KONTROLA hlasi dve dosky na jednom mieste ako ORANGE (#{dups.map { |d| d['message_sk'] }.join(' | ')})",
         dups.length == 1 && dups.first['severity'] == 'orange' &&
         dups.first['dup_owner_ids'] == ids && dups.first['dup_kind'] == 'board')
      pids = e::ProductionDialog.send(:pids_for_problem, model, dups.first) unless dups.empty?
      ok("async S6b: klik na nalez oznaci OBE dosky (#{Array(pids).length} entit)",
         Array(pids).length == 2)
      cleanup(model)
      log_line('=== KONIEC SUBORU ===')
      done.call if done
    end]

    walk = lambda do |idx|
      return if idx >= steps.length
      delay, action = steps[idx]
      UI.start_timer(delay, false) do
        begin
          action.call
        rescue StandardError => ex
          log_line("FAIL: async krok #{idx} vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
          begin
            remove_js_recorder # idempotentne — D-34 recorder nesmie prezit FAIL
            d101_teardown(state) # idempotentne — sonda a fake dialog panela tiez nie
            cleanup(model)
          rescue StandardError
            nil
          end
          log_line('=== KONIEC SUBORU ===')
          next
        end
        walk.call(idx + 1)
      end
    end
    walk.call(0)
  end

  def run
    File.write(OUT, "MARKER START #{Time.now} (su_runner)\n")
    unless defined?(Noxun::Engine::CabinetBuilder)
      log_line('FAIL: Noxun Engine nie je nacitany')
      log_line('=== KONIEC SUBORU ===')
      return
    end
    model = Sketchup.active_model
    unless guard_model?(model)
      log_line("SKIP: nespravny model ('#{model && model.path}', korpusov: #{model ? cabinets(model).length : '?'}) — testy NEBEZALI")
      log_line('=== KONIEC SUBORU ===')
      return
    end
    log_line("INFO: verzia pluginu #{Noxun::Engine::VERSION}, model '#{File.basename(model.path.to_s)}'")
    cleanup(model) # cisty stol (zvysky z predoslych behov)
    # Opakovany beh v TOM ISTOM okne (MCP replay): predosly beh mohol cez
    # observer/push_state zdvihnut generation counter okna Vyroba — klik testy
    # posielaju gen 0 a stale guard by ich falosne odmietol (nalez 30.7.:
    # 4x FAIL select-cez-kluc bez realnej regresie). Cerstva instancia ma nil.
    e::ProductionDialog.instance_variable_set(:@generation, 0) if defined?(e::ProductionDialog)
    run_sync(model)
    run_sync_back(model)     # davka Chrbat: D-37 hlbka, D-31 none, D-38 pevny 18
    run_sync_rails(model)    # H3/D-80: vnutro pod vystuhami (odsadenie, upright, chrbat, odmietnutie)
    run_insert_batch(model)  # davka Vkladanie: D-33/F6 sablona+materialy, D-39/F8 zamky, B3 kopia, N11
    run_d45(model)           # D-45: hrubka <-> material tela (18,6 mm deadlock)
    run_d46(model)           # D-46: projektova predvolba korpusu s inou hrubkou (potvrdenie)
    run_2a2(model)           # 2A-2: migracia katalogu na SCHEMA 2 (izolovany katalog cez override)
    run_2a3(model)           # 2A-3: vyberove cesty ABS so strukturou (SCHEMA 2 sandbox katalog)
    run_2a4(model)           # 2A-4b: OSTRY cutover — boot_cutover!, picker, universal, rollback+hold
    run_d40(model)           # D-40: selection eventy po builde (DC observer pasca)
    run_d90(model)           # D-90: vizual uchytkoveho profilu UKW-7 (kotva, undo, rebuild)
    run_d93(model)           # D-93: rucny zamok NL vysuvu (drzi cez zmenu hlbky, odomknutie)
    run_d88(model)           # D-88: farba ABS na bocnych plochach dielcov a dosky
    run_d104(model)          # D-104: overlay „hrany bez olepu" (lifecycle, pocty, ziadny undo krok)
    run_d105(model)          # D-105: tri stavy + filter podla vyberu (vyber NEMENI model)
    run_uib1(model)          # UI-B1: kostra Inspectora — payloady raily, krizik dielca/dosky, ABS toggle bez undo kroku
    run_uib2(model)          # UI-B2: kamera nahladu — celny pohlad, guardy identity, ziadny zapis ani undo krok
    run_uib3(model)          # UI-B3: vyber dielcov z informacneho stlpca — ciste citanie, ziadny undo krok
    run_uic1c(model)         # UI-C1c: orientacia dosky — matice, delta, scale/dedup, vyrobne data nedotknute
    run_uic2(model)          # UI-C2: zony — delenie/police/presna cesta na zivej skrinke, guardy, undo, vyber
    run_uic4(model)          # UI-C4: kovanie — oznacenie vlastnika polozky v modeli (guardy, ziadny undo krok)
    run_uid1(model)          # UI-D1: dielec — „Použiť na podobné" (zapis do viacerych dielcov, 1 undo) + „Označiť v modeli"
    run_k1(model)            # K1/D-108: smer dekoru per dielec — 1 undo, geometria a D-88 nedotknute, VEPO otocene
    run_uid2(model)          # UI-D2: PNG nahlady sablon — capture, KOMPLETNA obnova kamery (persp. aj orto), ziadny undo krok
    run_smoke1(model)        # SMOKE PACK 1 (6A): rucne odfotenie nahladu k ULOZENEJ sablone — guardy vyberu, ziadny undo krok
    run_async(model, nil)
  rescue StandardError => ex
    log_line("FAIL: runner vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    log_line('=== KONIEC SUBORU ===')
  end
end

NoxunSuRunner.run
