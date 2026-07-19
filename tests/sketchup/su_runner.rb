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
#     (build/rebuild/undo/dedup samostatnej dosky, standard 8.3).
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

    cleanup(model)
    ok('sync: cleanup (0 korpusov, 0 dosiek)', cabinets(model).empty? && boards(model).empty?)
  rescue StandardError => ex
    log_line("FAIL: sync vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
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
    run_async(model, nil)
  rescue StandardError => ex
    log_line("FAIL: runner vynimka: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
    log_line('=== KONIEC SUBORU ===')
  end
end

NoxunSuRunner.run
