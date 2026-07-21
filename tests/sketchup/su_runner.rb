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
#   SYNC cast — geometria proti BuildPlan kontraktu (plan vs. model 1:1), NOXUN data
#     dielcov, ghost zony, rebuild identita + prezitie part_overrides, dedup kopie
#     (priame volanie), undo rebuildu = presne 1 krok; V0.4.7b sync-board sekcia
#     (build/rebuild/undo/dedup samostatnej dosky, standard 8.3); D-35 sync-abs
#     sekcia (bulk olepenie 4 hran = 1 undo, echo guardy, no-op bez ABS variantu).
#   ASYNC cast — retaz UI.start_timer krokov (observer debounce = 0.2 s):
#     S1 scale -> absorpcia -> Ctrl+Z (audit riziko: re-absorpcia po undo)
#     S2 kopia -> observer dedup -> Ctrl+Z (audit riziko: zapis ID mimo operacie)
#     S3 kopia DOSKY -> observer dedup (nove BRD id) -> Ctrl+Z (V0.4.7b)
#     S4 miesana davka stale+fresh duplicit -> fresh v paste ticku, stale follow-up
#     S5 scale DOSKY (V0.4.7d): X absorpcia+undo, vertikalna doska (global Z =
#        lokalna sirka), X+Z kombinacia (hrubka drzi material), reject bez materialu
#
# Cistenie: kazdy scenar maze svoje korpusy v ScaleWatch.guard (inak by debounce
# timer po skonceni testu vykonal dedup/prune nekontrolovane) + purge_unused.

require 'tmpdir'

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
    # 2mm v W1000 nema -> nil) a material bez dekoru zhodi smer dekoru na none
    e::Panel.handle_set_board_material({ 'board_id' => bid, 'material_id' => 'W1000_DTDL_18' }.to_json)
    mcfg = e::Store.config(binst) || {}
    mecfg = mcfg['edges'] || {}
    ok('sync-board: zmena materialu K009->W1000 previedla ABS dekor (L1 1mm remap, W1 2mm -> nil)',
       mcfg['material_id'] == 'W1000_DTDL_18' && mecfg['L1'] == 'ABS_W1000_10' && mecfg['W1'].nil?)
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

    cleanup(model)
    ok('sync: cleanup (0 korpusov, 0 dosiek)', cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: sync vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
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
    if e::TemplateStore.find(tpl_name)
      info("vklad: sablona #{tpl_name} uz existuje — sablonovy scenar preskoceny (chranime pouzivatelske data)")
      tpl_snapshot = nil
    else
      e::TemplateStore.upsert(tpl_name, tpl_cfg)
      tpl_snapshot = File.binread(e::TemplateStore.path) # snapshot AZ PO seede (N11)
    end
    payload = tpl_snapshot ? (e::TemplateStore.find(tpl_name) || {})['config'].merge('height' => 950.0) : nil
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
      ok('vklad N11: subor sablon byte-nezmeneny po inserte + edite korpusu',
         File.binread(e::TemplateStore.path) == tpl_snapshot)
      e::TemplateStore.delete(tpl_name) # cleanup VLASTNEJ testovacej sablony
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

  # --- ASYNC: undo/redo scenare (retaz timerov, observer debounce 0.2 s) -----

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
    run_sync(model)
    run_sync_back(model)     # davka Chrbat: D-37 hlbka, D-31 none, D-38 pevny 18
    run_insert_batch(model)  # davka Vkladanie: D-33/F6 sablona+materialy, D-39/F8 zamky, B3 kopia, N11
    run_d40(model)           # D-40: selection eventy po builde (DC observer pasca)
    run_async(model, nil)
  rescue StandardError => ex
    log_line("FAIL: runner vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    log_line('=== KONIEC SUBORU ===')
  end
end

NoxunSuRunner.run
