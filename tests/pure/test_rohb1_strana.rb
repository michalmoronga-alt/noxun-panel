# frozen_string_literal: true
# ROH-B1 · K3 — OVLADACE ROHOVEJ A PREPINAC STRANY DVERI (blok 8).
# Package: SYSTEM/zdroje/bloky/ROHOVA/PACKAGE_ROHB1.md (+ audit navrhu B1).
#
# CO PLATI:
#   * PREPNUTIE STRANY = JEDINA cista funkcia `CabinetBuilder.corner_mirror_params`:
#     okraje ciel vlavo <-> vpravo, smer pantov `left` <-> `right` (`unset`
#     ostava, CHYBAJUCI kluc ostava chybat), `profile_edge` `left` <-> `right`,
#     rucne hrany PODLA OSI dielca — `AXES_FRONT` dielce zostavy (blenda
#     korpusova, CR 1) a kridla riadku ciel si vymenia L1 <-> L2 (aj
#     `edge_warnings`, riedka mapa ostava riedka — audit B1 NOTE 7);
#     stojace dielce zostavy (vystuha zavesov, rohova vystuha, CR 2) a korpus
#     bez zmeny; dvojite prepnutie = povodny stav (identita);
#   * zoznam zrkadlenych dielcov = PRESNE `AXES_FRONT` dielce `corner_parts`;
#   * ine cesty stranu dalej odmietaju — novou vetou (apply, sablona);
#   * akcia panela `corner_side`: R-02 poradie, bariera observera PRED citanim
#     configu (audit B1 FIX 3), korelovana odpoved v KAZDEJ vetve (FIX 1);
#   * preflight oznacenej rohovej: strana z ULOZENEHO configu, dverova cast
#     ZIVA z formulara (audit B1 NOTE 6) + `corner_ctx` s ucinnymi hrubkami;
#   * minimum sirky = presne `corner_fit_width` (audit B1 FIX 5), tabulka
#     parity zdielana s `tests/js/test_rohb1_ovladace.js`;
#   * JS zrkadla: rozsahy poli, predvolby `dflt`, `only`, `corner_th2` v payloade.
#
# MUTACIE (overene pri davke, report):
#   M1 hrany aj pri `AXES_UPRIGHT` (vystuha zavesov v zozname) -> „hrany podla osi"
#   M2 bez vymeny okrajov                                         -> „okraje ciel"
#   M3 smer bez zrkadla                                           -> „smer pantov"
#   M4 `unset` -> strana                                          -> „smer pantov"
#   M5 riedka mapa doplni `L1: nil`                               -> „riedka mapa"
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'fileutils'
require 'tmpdir'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  # sync + resolvers: `foreign_document?`, `parse`, `part_count` (vzor test_d140_osadenie.rb).
  %w[actions_cabinet actions_templates payloads sync resolvers].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'templates_dialog')
  # ScaleWatch (bariera prepinaca) — vzor `test_roha1_rohova.rb`: observer
  # triedy nad `Sketchup::*Observer` sa na chvilu podstrcia a hned upracu.
  unless defined?(Noxun::Engine::ScaleWatch)
    su = Module.new
    %w[EntityObserver EntitiesObserver AppObserver].each { |c| su.const_set(c, Class.new) }
    Object.const_set(:Sketchup, su)
    begin
      require File.join(NxTest::ROOT, 'noxun_engine', 'core', 'scale_observer')
    ensure
      Object.send(:remove_const, :Sketchup)
    end
  end
end

module NxRohB1
  module_function

  E  = Noxun::Engine
  CB = E::CabinetBuilder
  CN = E::Construction
  PF = E::PartFaces

  FRONTS = { 'gap' => 3.0, 'gap_top' => 5.0, 'gap_bottom' => 0.0, 'gap_left' => 0.0, 'gap_right' => 2.0,
             'items' => [{ 'id' => 'F7', 'type' => 'door', 'mode' => 'auto', 'wings' => '1',
                           'direction' => 'right', 'profile' => 'none' }] }.freeze

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  # Ulozeny config (tvar `Store.config` — stringove kluce po JSON).
  def stored(over = {})
    JSON.parse(JSON.generate(CB.cabinet_config(CB.normalize(params(over)))))
  end

  def params(over = {})
    { 'type' => 'corner_blind', 'width' => 1100.0, 'height' => 862.0, 'depth' => 510.0,
      'thickness' => 18.0, 'floor_height' => 150.0, 'corner_side' => 'left', 'corner_door_w' => 450.0,
      'corner_cr1' => 80.0, 'corner_cr2' => 80.0, 'fronts' => JSON.parse(JSON.generate(FRONTS)) }.merge(over)
  end

  # Rucne hrany na VSETKYCH dielcoch zostavy + kridle + boku korpusu.
  def overrides
    {
      'front:F7/wing:single' => { 'material_id' => 'M1', 'edges' => { 'L1' => 'ABS-A', 'W2' => 'ABS-B' },
                                   'edge_warnings' => { 'L1' => { 'reason' => 'remap', 'abs_id' => 'ABS-A' } } },
      'cabinet/cr:1' => { 'edges' => { 'L1' => 'ABS-C', 'L2' => nil } },
      'cabinet/corner_panel' => { 'edges' => { 'L2' => 'ABS-D' }, 'grain_direction' => 'width' },
      'cabinet/hinge_rail' => { 'edges' => { 'L1' => 'ABS-E' } },
      'cabinet/corner_rail' => { 'edges' => { 'L1' => 'ABS-F', 'W1' => 'ABS-G' } },
      'cabinet/cr:2' => { 'edges' => { 'L2' => 'ABS-H' } },
      'cabinet/side:left' => { 'edges' => { 'L1' => 'ABS-I' } }
    }
  end

  # Tabulka PARITY minima (zdielana s JS sadou — rovnake cisla tam):
  # [D, CR 1, th2, t, ocakavane minimum]. Desatinne riadky = audit B1 FIX 5.
  MIN_TABLE = [
    [450.0, 80.0, 18.0, 18.0, 584.0], [450.0, 80.0, 19.0, 18.0, 585.0],
    [300.0, 50.0, 18.0, 18.0, 404.0], [600.0, 120.0, 18.0, 25.0, 788.0],
    [800.0, 250.0, 18.0, 18.0, 1104.0], [250.0, 50.0, 19.0, 25.0, 369.0],
    [450.0, 80.0, 19.0, 25.0, 599.0], [450.0, 80.0, 18.6, 18.0, 584.6],
    [450.25, 80.1, 18.0, 18.0, 584.35]
  ].freeze
end

NxTest.test('ROH-B1: zrkadlo ciel — okraje vlavo <-> vpravo, smer pantov, strana profilu, ID a zvysok bez zmeny') do
  pr = NxRohB1.params
  m = NxRohB1::CB.corner_mirror_params(pr, 'right')
  NxTest.assert_equal('right', m['corner_side'])
  NxTest.assert_equal([2.0, 0.0], m['fronts'].values_at('gap_left', 'gap_right'),
                      'okraje ciel: vonkajsi 0 ostane vonkajsi, pri rohu 2 ostane pri rohu')
  NxTest.assert_equal([3.0, 5.0, 0.0], m['fronts'].values_at('gap', 'gap_top', 'gap_bottom'), 'ostatne medzery bez zmeny')
  it = m['fronts']['items'].first
  NxTest.assert_equal(%w[F7 door auto 1 left none], it.values_at('id', 'type', 'mode', 'wings', 'direction', 'profile'),
                      'smer pantov zrkadlom (panty pri rohu ostanu pri rohu), ID a zvysok bez zmeny')
  # smer: left/right/unset/chybajuci
  { 'left' => 'right', 'right' => 'left', 'unset' => 'unset' }.each do |have, want|
    p2 = NxRohB1.params
    p2['fronts']['items'][0]['direction'] = have
    NxTest.assert_equal(want, NxRohB1::CB.corner_mirror_params(p2, 'right')['fronts']['items'][0]['direction'],
                        "smer pantov: #{have} -> #{want}")
  end
  p3 = NxRohB1.params
  p3['fronts']['items'][0].delete('direction')
  m3 = NxRohB1::CB.corner_mirror_params(p3, 'right')
  NxTest.refute(m3['fronts']['items'][0].key?('direction'), 'chybajuci smer ostane chybat (predvolba rohovej)')
  n3 = NxRohB1::CB.normalize(m3)
  NxTest.assert_equal('left', n3[:fronts]['items'][0]['direction'], 'predvolba R7 = panty pri rohu (vpravo dvere -> vlavo)')
  %w[left right top free].each do |pe|
    p4 = NxRohB1.params
    p4['fronts']['items'][0]['profile_edge'] = pe
    got = NxRohB1::CB.corner_mirror_params(p4, 'right')['fronts']['items'][0]['profile_edge']
    NxTest.assert_equal({ 'left' => 'right', 'right' => 'left' }.fetch(pe, pe), got, "profile_edge #{pe}")
  end
end

NxTest.test('ROH-B1: rucne hrany podla osi — AXES_FRONT a kridlo L1 <-> L2, stojace dielce a korpus bez zmeny') do
  pr = NxRohB1.params('part_overrides' => NxRohB1.overrides)
  ov = NxRohB1::CB.corner_mirror_params(pr, 'right')['part_overrides']
  NxTest.assert_equal({ 'L2' => 'ABS-A', 'W2' => 'ABS-B' }, ov['front:F7/wing:single']['edges'], 'kridlo dveri L1 -> L2')
  NxTest.assert_equal({ 'L2' => { 'reason' => 'remap', 'abs_id' => 'ABS-A' } }, ov['front:F7/wing:single']['edge_warnings'],
                      'edge_warnings idu spolu s hranou')
  NxTest.assert_equal('M1', ov['front:F7/wing:single']['material_id'], 'material sa nemeni')
  NxTest.assert_equal({ 'L2' => 'ABS-C', 'L1' => nil }, ov['cabinet/cr:1']['edges'], 'CR 1: L1 <-> L2 (aj vedome bez ABS = nil)')
  NxTest.assert_equal({ 'L1' => 'ABS-D' }, ov['cabinet/corner_panel']['edges'], 'blenda korpusova: L2 -> L1')
  NxTest.assert_equal('width', ov['cabinet/corner_panel']['grain_direction'], 'smer dekoru sa nemeni')
  %w[cabinet/hinge_rail cabinet/corner_rail cabinet/cr:2 cabinet/side:left].each do |k|
    NxTest.assert_equal(NxRohB1.overrides[k], ov[k], "#{k}: bez zmeny (stojaci dielec / korpus)")
  end
end

NxTest.test('ROH-B1 (audit NOTE 7): riedka mapa ostane riedka — {L1: X} -> iba {L2: X}') do
  ax = 'ABS_K009_10'
  pr = NxRohB1.params('part_overrides' => { 'cabinet/cr:1' => { 'edges' => { 'L1' => ax },
                                                                'edge_warnings' => { 'L1' => { 'reason' => 'r', 'abs_id' => ax } } } })
  rec = NxRohB1::CB.corner_mirror_params(pr, 'right')['part_overrides']['cabinet/cr:1']
  NxTest.assert_equal({ 'L2' => ax }, rec['edges'], 'ziadne L1: nil (nil by vypol pravidlovy olep)')
  NxTest.assert_equal(['L2'], rec['edge_warnings'].keys, 'warning len na L2')
  # normalize tu odlisnost zachova (chybajuci kluc = dedenie)
  n = NxRohB1::CB.normalize(NxRohB1::CB.corner_mirror_params(pr, 'right'))
  # (bez katalogu normalize neznamu pasku zmeni na nil — rozhoduje KLUC)
  NxTest.assert_equal(['L2'], n[:part_overrides]['cabinet/cr:1']['edges'].keys)
  NxTest.refute(n[:part_overrides]['cabinet/cr:1']['edges'].key?('L1'), 'L1 po normalize chyba (dedi pravidlo)')
end

NxTest.test('ROH-B1: dvojite prepnutie = povodny config (identita), rovnaka strana = kopia, vstup sa nemeni') do
  pr = NxRohB1.params('part_overrides' => NxRohB1.overrides)
  before = JSON.generate(pr)
  there = NxRohB1::CB.corner_mirror_params(pr, 'right')
  back = NxRohB1::CB.corner_mirror_params(there, 'left')
  NxTest.assert_equal(JSON.parse(before), JSON.parse(JSON.generate(back)), 'vlavo -> vpravo -> vlavo = povodne params')
  NxTest.assert_equal(before, JSON.generate(pr), 'vstup volajuceho sa nezmenil (hlboka kopia)')
  same = NxRohB1::CB.corner_mirror_params(pr, 'left')
  NxTest.assert_equal(JSON.parse(before), JSON.parse(JSON.generate(same)), 'rovnaka strana = bez zmeny')
  NxTest.assert_equal('left', NxRohB1::CB.corner_mirror_params(pr, 'hore')['corner_side'], 'neznama strana = left (norm_corner)')
  # normalizovany config (symbolove kluce) prejde tiez
  cfg = NxRohB1::CB.normalize(pr)
  m = NxRohB1::CB.corner_mirror_params(cfg, 'right')
  NxTest.assert_equal('right', NxRohB1::CB.normalize(m)[:corner_side])
end

NxTest.test('ROH-B1: zoznam zrkadlenych hran = PRESNE AXES_FRONT dielce zostavy; popisky L1 lava / L2 prava') do
  cfg = NxRohB1::CB.normalize(NxRohB1.params)
  plan = NxRohB1::CN.build_plan(cfg, 'CAB-1')
  corner = plan[:parts].select { |p| NxRohB1::CN::CORNER_ROLES.include?(p[:role].to_s) }
  NxTest.assert_equal(5, corner.length, 'pat dielcov zostavy')
  front = corner.select { |p| p[:axes] == NxRohB1::PF::AXES_FRONT }.map { |p| p[:part_key].to_s }.sort
  NxTest.assert_equal(NxRohB1::CN::CORNER_MIRROR_EDGE_KEYS.sort, front, 'zoznam = AXES_FRONT dielce corner_parts')
  up = corner.reject { |p| p[:axes] == NxRohB1::PF::AXES_FRONT }.map { |p| p[:axes] }.uniq
  NxTest.assert_equal([NxRohB1::PF::AXES_UPRIGHT], up, 'zvysok zostavy je stojaci (bez zmeny hran)')
  abs = NxRohB1::E::AbsRules
  (%w[front_door corner_blind_panel cr_front]).each do |r|
    NxTest.assert_equal(%w[Ľavá Pravá], abs.edge_labels(r).values_at('L1', 'L2'), "#{r}: L1 lava, L2 prava")
  end
  %w[hinge_rail corner_rail cr_side].each do |r|
    NxTest.assert_equal('Predná', abs.edge_labels(r)['L1'], "#{r}: L1 je predna (zrkadlo ju nemeni)")
  end
end

NxTest.test('ROH-B1 (audit FIX 5): minimum sirky = presne corner_fit_width (tabulka parity s JS, aj desatinne)') do
  NxRohB1::MIN_TABLE.each do |d, c1, th2, t, want|
    cfg = NxRohB1::CB.normalize(NxRohB1.params('corner_door_w' => d, 'corner_cr1' => c1, 'thickness' => t))
    got = NxRohB1::CN.corner_fit_width(cfg, { 'cabinet/cr:2' => th2 })
    NxTest.assert_close(want, got, 0.001, "D #{d} CR1 #{c1} th2 #{th2} t #{t}")
  end
  # celociselna sonda (klamp Scale) je o nieco vyssia pri desatinnom minime
  cfg = NxRohB1::CB.normalize(NxRohB1.params)
  NxTest.assert_equal(585.0, NxRohB1::CN.min_valid_width(cfg, part_thicknesses: { 'cabinet/cr:2' => 18.6 }),
                      'sonda sa zaokruhli na cele mm (panel ju nepouziva)')
  js = NxRohB1.src('tests', 'js', 'test_rohb1_ovladace.js')
  NxRohB1::MIN_TABLE.each do |row|
    NxTest.assert(js.include?("[#{row.map { |v| v == v.round ? v.round.to_s : v.to_s }.join(', ')}]"),
                  "JS sada nesie ten isty riadok tabulky #{row.inspect}")
  end
end

NxTest.test('ROH-B1: iné cesty stranu dalej odmietaju — novou vetou (apply, sablona na existujucu rohovu)') do
  pn = NxRohB1::E::Panel
  NxTest.assert_equal('Stranu dverí zmeň prepínačom v riadku rohovej.', pn::CORNER_SIDE_MSG)
  pr = NxRohB1::CB.config_to_params(NxRohB1.stored)
  NxTest.assert_equal(pn::CORNER_SIDE_MSG, pn.corner_change_refusal(pr, 'corner_side' => 'right'))
  NxTest.assert_equal(nil, pn.corner_change_refusal(pr, 'corner_side' => 'left'), 'rovnaka strana v apply prejde')
  td = NxRohB1::E::TemplatesDialog
  NxTest.assert_equal(pn::CORNER_SIDE_MSG,
                      td.corner_template_apply_refusal({ 'type' => 'corner_blind', 'corner_side' => 'left' },
                                                       { 'type' => 'corner_blind', 'corner_side' => 'right' }))
end

NxTest.test('ROH-B1: akcia corner_side — R-02, bariera observera PRED configom, echo, korelovana odpoved v kazdej vetve') do
  ac = NxRohB1.src('noxun_engine', 'ui', 'panel', 'actions_cabinet.rb')
  body = ac[/def handle_corner_side.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'handler existuje')
  i_doc = body.index('foreign_document?')
  i_bar = body.index('ScaleWatch.flush_pending!(model) == true')
  i_cfg = body.index('existing_params(cab)')
  NxTest.assert(i_doc && i_bar && i_cfg && i_doc < i_bar && i_bar < i_cfg,
                'poradie: identita dokumentu -> bariera observera -> citanie configu (audit FIX 3)')
  NxTest.assert(body.index('foreign_document?', i_bar), 'po bariere sa dokument overi znova')
  NxTest.assert(body.index('corner_side_target(model, data)', i_bar), 'po bariere sa cielova skrinka overi znova')
  NxTest.assert(body.include?('CabinetBuilder.corner_mirror_params(params, want)'), 'zrkadlo = jedina funkcia')
  NxTest.assert(body.include?('op_name: CORNER_SIDE_OP'), 'vlastny nazov operacie (1 krok Spat)')
  NxTest.assert(body.include?('ensure') && body.include?('NX.cornerSideResult'), 'odpoved v KAZDEJ vetve (ensure)')
  NxTest.assert(body.index('push_selected(model)') < body.rindex('NX.cornerSideResult'), 'odpoved az po pushi stavu')
  tgt = ac[/def corner_side_target.*?\n        end\n/m].to_s
  NxTest.assert(tgt.include?('!echo.empty? && echo == cid'), 'echo cabinet_id je POVINNE')
  panel = NxRohB1.src('noxun_engine', 'ui', 'panel.rb')
  NxTest.assert(panel.include?("cb(dlg, 'corner_side')    { |p| handle_corner_side(p) }"), 'callback registrovany')
  NxTest.assert_equal('NOXUN: Strana dverí rohovej', NxRohB1::E::Panel::CORNER_SIDE_OP)
end

NxTest.test('ROH-B1 (audit NOTE 6): preflight oznacenej rohovej — strana ULOZENA, dverova cast ZIVA') do
  pn = NxRohB1::E::Panel
  stored = NxRohB1.stored('corner_side' => 'right')
  data = { 'model_guid' => 'G', 'cabinet_id' => 'CAB-1', 'revision' => 1, 'type' => 'corner_blind',
           'width' => 1100.0, 'height' => 862.0, 'floor_height' => 150.0, 'corner_side' => 'left',
           'corner_door_w' => 500.0, 'fronts' => { 'gap' => 3.0, 'gap_top' => 5.0, 'gap_bottom' => 0.0,
                                                   'gap_left' => 2.0, 'gap_right' => 0.0,
                                                   'items' => [{ 'id' => 'F7', 'type' => 'door', 'mode' => 'auto', 'wings' => '1' }] } }
  op = pn.front_preflight_result(data, stored)['opening']
  NxTest.assert_equal({ 'x0' => 600.0, 'w' => 500.0, 'z0' => 150.0, 'h' => 712.0 }, op,
                      'dvere vpravo (ulozene, nie z payloadu) a dverova cast 500 zo ziveho formulara')
  bad = pn.front_preflight_result(data.merge('corner_door_w' => 900.0), stored)['opening']
  NxTest.assert_equal(450.0, bad['w'], 'dverova cast mimo rozsahu -> otvor drzi ulozenu (pole je v paneli cervene)')
  ins = pn.front_preflight_result(data.merge('cabinet_id' => '', 'corner_side' => 'right', 'corner_door_w' => 520.0), nil)['opening']
  NxTest.assert_equal([580.0, 520.0], ins.values_at('x0', 'w'), 'vkladanie: strana aj dverova cast z payloadu')
  ctx = pn.corner_preflight_ctx(data.merge('thickness' => 25.0), stored, nil)
  NxTest.assert_equal({ 'th2' => 18.0, 't' => 25.0 }, ctx, 'oznacena: th2 z ulozeneho (bez materialov 18), t zivy')
  NxTest.assert_equal(nil, pn.corner_preflight_ctx(data.merge('type' => 'lower', 'cabinet_id' => ''), nil, nil),
                      'iny typ ctx nema')
end

NxTest.test('ROH-B1: JS zrkadla — rozsahy, predvolby `dflt`, `only`, corner_th2 v payloade a predvolbach') do
  form = NxRohB1.src('noxun_engine', 'ui', 'js', 'form.js')
  NxRohB1::CB::CORNER_RANGES.each do |k, (lo, hi)|
    NxTest.assert(form.include?("#{k}:[#{lo.round},#{hi.round}]"), "LIMITS #{k} = CORNER_RANGES")
  end
  core = NxRohB1.src('noxun_engine', 'ui', 'js', 'core.js')
  %i[corner_door_w corner_cr1 corner_cr2].each do |k|
    NxTest.assert(core.include?("{ id:'#{k}', kind:'num', dflt:#{NxRohB1::CB::CORNER_DEFAULTS[k].round}, only:'corner_blind' }"),
                  "CONSTRUCTION_FIELDS #{k}: dflt = CORNER_DEFAULTS, only = rohova")
  end
  pay = NxRohB1.src('noxun_engine', 'ui', 'panel', 'payloads.rb')
  NxTest.assert(pay.include?("params['corner_th2'] = corner_th2_payload(entity_model(cab), params) if Construction.corner?(cfg)"),
                'payload oznacenej: corner_th2 LEN pri rohovej')
  d = NxRohB1::E::Panel.corner_insert_defaults(nil)
  NxTest.assert_equal(18.0, d[:corner_th2], 'predvolby vkladania nesu th2 (bez materialov 18)')
  NxTest.assert_equal(NxRohB1::CB::CORNER_DEFAULTS.merge(corner_th2: 18.0), d, 'zvysok = CORNER_DEFAULTS')
  NxTest.assert(NxRohB1::CB::CORNER_DEFAULTS.frozen? && !NxRohB1::CB::CORNER_DEFAULTS.key?(:corner_th2),
                'konstanta buildera ostava nedotknuta')
  html = NxRohB1.src('noxun_engine', 'ui', 'panel.html')
  row = html[%r{<div class="cornerrow" id="cornerRow" hidden>(.*?)\n        </div>}m, 1].to_s
  NxTest.refute(row.empty?, 'riadok rohovej v #basicCard, predvolene skryty')
  %w[corner_door_w corner_cr1 corner_cr2].each do |id|
    NxTest.assert(row.include?(%(id="#{id}")) && row.include?('oninput="onField()"'), "pole #{id} ide beznou cestou onField")
  end
  NxTest.assert(row.include?(%(onclick="onCornerSide('left')")) && row.include?(%(onclick="onCornerSide('right')")),
                'prepinac strany = vlastna akcia')
  NxTest.assert(row.include?('aria-pressed') && row.include?('#i-corner-l') && row.include?('#i-corner-r'), 'aria + ikony')
  NxTest.assert(html.index('id="cornerRow"') < html.index('id="legsRow"'), 'riadok rohovej stoji nad riadkom Nohy')
  css = NxRohB1.src('noxun_engine', 'ui', 'css', 'panel.css')
  NxTest.assert(css.include?('.nx-inspector .cornerrow[hidden] { display: none; }'), 'parove [hidden] pravidlo (D-137)')
  icons = NxRohB1.src('noxun_engine', 'ui', 'js', 'icons.js')
  NxTest.assert(icons.include?("'corner-l':") && icons.include?("'corner-r':"), 'ikony strany v sprite')
  ui = NxRohB1.src('docs', 'UI_DIZAJN.md')
  NxTest.assert(ui.include?('`corner-l` / `corner-r`'), 'ikony v inventari UI_DIZAJN §4')
end

# ===========================================================================
# Predrecenzia P2-2: SPRAVANIE (nie len poradie v zdrojaku) — ucinne hrubky
# pri VKLADANI a vetvy akcie `handle_corner_side`.
# ===========================================================================
module NxRohB1
  module_function

  # Katalog: telo 25, celovy 19 a 18 (vzor `roha1_catalog_json` v in-SU).
  def catalog_json
    sheet = lambda do |id, th|
      { 'material_id' => id, 'manufacturer' => 'Egger', 'decor' => 'ROHB1', 'type' => 'DTDL',
        'thickness' => th, 'grain' => 'none', 'sheet_size' => [2800.0, 2070.0], 'color' => [230, 225, 215],
        'production_class' => 'sheet', 'group_id' => 'GRP-ROHB1', 'structure' => 'SM' }
    end
    { 'std' => 1, 'schema' => 2,
      'sheets' => [sheet.call('B1K25', 25.0), sheet.call('B1F19', 19.0), sheet.call('B1K18', 18.0)],
      'edges' => [] }
  end

  def with_catalog
    mat = E::Materials
    prev = mat.test_dir_override
    dir = File.join(Dir.tmpdir, "nx_rohb1_#{Process.pid}")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, 'materials.json'), JSON.generate(catalog_json))
    mat.test_dir_override = dir
    mat.reload!
    yield
  ensure
    mat.test_dir_override = prev
    mat.reload!
    FileUtils.rm_rf(dir) if dir
  end

  def with_locks(locks)
    pn = E::Panel
    prev = pn.instance_variable_get(:@insert_locks)
    pn.instance_variable_set(:@insert_locks, locks)
    yield
  ensure
    pn.instance_variable_set(:@insert_locks, prev)
  end

  def insert_data(over = {})
    { 'model_guid' => 'G', 'cabinet_id' => '', 'insert_session' => 1, 'revision' => 1, 'type' => 'corner_blind',
      'width' => 1100.0, 'height' => 862.0, 'floor_height' => 150.0, 'corner_side' => 'left',
      'corner_door_w' => 450.0, 'thickness' => 18.0 }.merge(over)
  end

  # --- akcia prepinaca: falosny model, skrinka a zaznam volani -------------
  class FakeModel
    def path
      'C:/tmp/rohb1.skp'
    end
  end

  class FakeCab
    def initialize(cfg, cid = 'CAB-7')
      @a = { 'kind' => 'cabinet', 'cabinet_id' => cid, 'config' => JSON.generate(cfg) }
    end

    def get_attribute(dict, key, default = nil)
      dict == 'NOXUN' ? @a.fetch(key.to_s, default) : default
    end
  end

  # Stub singleton metod (aj tych, ktore headless nema — tie sa po teste zmazu).
  def with_stubs(entries)
    saved = []
    entries.each do |(mod, name, impl)|
      sc = mod.singleton_class
      had = sc.method_defined?(name) || sc.private_method_defined?(name)
      saved << [sc, name, had ? sc.instance_method(name) : nil]
      sc.send(:define_method, name, &impl)
    end
    yield
  ensure
    saved.reverse_each do |(sc, name, orig)|
      orig ? sc.send(:define_method, name, orig) : sc.send(:remove_method, name)
    end
  end

  # Spusti `handle_corner_side` s podstrcenym prostredim; -> zaznam volani.
  def switch(cab:, data:, barrier: true, rebuild: nil)
    model = FakeModel.new
    guid = E::DocKey.key(model)
    log = []
    pn = E::Panel
    su = Module.new
    su.define_singleton_method(:active_model) { model }
    rebuild ||= ->(_m, _c, params, **kw) { log << [:rebuild, params['corner_side'], kw[:op_name]] }
    stubs = [
      [pn, :find_cabinet, ->(_m) { cab }],
      [pn, :push_selected, ->(_m, **_kw) { log << [:push] }],
      [pn, :set_status, ->(msg, err = false) { log << [:status, msg, err] }],
      [pn, :js, ->(script) { log << [:js, script] }],
      [pn, :reselect, ->(_m, _c) { log << [:reselect] }],
      [pn, :status_with_warnings, ->(_c, msg) { log << [:status, msg, false] }],
      [pn, :part_count, ->(_c) { 42 }],
      [pn, :suspend_selection_sync, ->(&blk) { blk.call }],
      [E::ScaleWatch, :flush_pending!, ->(_m = nil) { log << [:barrier]; barrier }],
      [CB, :rebuild, rebuild]
    ]
    Object.const_set(:Sketchup, su)
    begin
      with_stubs(stubs) do
        payload = { 'model_guid' => guid, 'cabinet_id' => 'CAB-7', 'corner_side' => 'right',
                    'switch_token' => 'tok-1' }.merge(data)
        payload['model_guid'] = 'CUDZI' if data['model_guid'] == :foreign
        begin
          pn.handle_corner_side(payload.to_json)
        rescue StandardError => e
          log << [:raised, e.message]
        end
      end
    ensure
      Object.send(:remove_const, :Sketchup)
    end
    log
  end

  def ack(log)
    s = log.select { |l| l[0] == :js }.map { |l| l[1] }.grep(/NX\.cornerSideResult/).last.to_s
    j = s[/\((\{.*\})\)/, 1]
    j ? JSON.parse(j) : nil
  end

  def corner_cfg(over = {})
    stored(over)
  end
end

NxTest.test('ROH-B1 (predrecenzia P2-2a): corner_ctx pri VKLADANI — hrubka tela z materialu, CR 2 z celoveho sablony') do
  pn = NxRohB1::E::Panel
  NxRohB1.with_catalog do
    NxRohB1.with_locks({}) do
      ctx = pn.corner_preflight_ctx(NxRohB1.insert_data('material_id' => 'B1K25', 'front_material_id' => 'B1F19'), nil, nil)
      NxTest.assert_equal({ 'th2' => 19.0, 't' => 25.0 }, ctx, 'vklad prevezme hrubku tela 25 (odomknuta) a CR 2 19')
      cfg = NxRohB1::CB.normalize(NxRohB1.params('thickness' => ctx['t']))
      NxTest.assert_close(599.0, NxRohB1::CN.corner_fit_width(cfg, { 'cabinet/cr:2' => ctx['th2'] }), 0.001,
                          'minimum pri korpuse 25 a celovom 19 = 599 (audit B1 FIX 4)')
      none = pn.corner_preflight_ctx(NxRohB1.insert_data, nil, nil)
      NxTest.assert_equal({ 'th2' => 18.0, 't' => 18.0 }, none, 'bez materialov navrhu: projekt mimo katalogu -> 18 / zivy t')
      front18 = pn.corner_preflight_ctx(NxRohB1.insert_data('front_material_id' => 'B1K18'), nil, nil)
      NxTest.assert_equal(18.0, front18['th2'], 'celovy 18 -> th2 18')
    end
    NxRohB1.with_locks({ 'thickness' => 18.0 }) do
      locked = pn.corner_preflight_ctx(NxRohB1.insert_data('material_id' => 'B1K25', 'front_material_id' => 'B1F19'), nil, nil)
      NxTest.assert_equal({ 'th2' => 19.0, 't' => 18.0 }, locked,
                          'zamknuta hrubka 18 so sablonou 25 -> t ostava 18 (vklad by konflikt odmietol, nie prevzal)')
    end
  end
end

NxTest.test('ROH-B1 (predrecenzia P2-2b): handle_corner_side — uspech, cudzi dokument, bez vyberu, bariera, vynimka') do
  cfg = NxRohB1.corner_cfg
  cab = NxRohB1::FakeCab.new(cfg)
  busy = NxRohB1::E::Panel::CORNER_SIDE_BUSY_MSG

  # Uspech: bariera -> JEDNA prestavba so zrkadlom -> push -> odpoved ok.
  log = NxRohB1.switch(cab: cab, data: {})
  kinds = log.map(&:first)
  NxTest.assert_equal([:rebuild, 'right', 'NOXUN: Strana dverí rohovej'], log.find { |l| l[0] == :rebuild },
                      'jedna prestavba, strana vpravo, vlastna operacia')
  NxTest.assert(kinds.index(:barrier) < kinds.index(:rebuild), 'bariera observera pred prestavbou')
  NxTest.assert(kinds.index(:reselect) && kinds.rindex(:push) < kinds.rindex(:js), 'push stavu pred odpovedou')
  NxTest.assert_equal({ 'model_guid' => log.find { |l| l[0] == :js }[1][/"model_guid":"([^"]+)"/, 1],
                        'cabinet_id' => 'CAB-7', 'switch_token' => 'tok-1', 'ok' => true }, NxRohB1.ack(log))

  # Cudzi dokument (R-02): ziadna bariera, ziadna prestavba, odpoved ok false.
  log = NxRohB1.switch(cab: cab, data: { 'model_guid' => :foreign })
  NxTest.refute(log.any? { |l| %i[barrier rebuild].include?(l[0]) }, 'cudzi dokument: nic sa nedeje')
  NxTest.assert(log.any? { |l| l[0] == :status && l[1].include?('panel patrí inému dokumentu') }, 'hlasi sa nahlas')
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'], 'odpoved ok false')

  # Bez oznacenej skrinky.
  log = NxRohB1.switch(cab: nil, data: {})
  NxTest.refute(log.any? { |l| %i[barrier rebuild].include?(l[0]) }, 'bez vyberu: ziadna bariera ani prestavba')
  NxTest.assert(log.any? { |l| l[0] == :status && l[1].include?('Najprv označ rohovú skrinku') }, 'veta bez vyberu')
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'])

  # Cudzie echo cabinet_id.
  log = NxRohB1.switch(cab: cab, data: { 'cabinet_id' => 'CAB-999' })
  NxTest.refute(log.any? { |l| l[0] == :rebuild }, 'cudzie echo: ziadna prestavba')
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'])

  # Neuspesna bariera observera.
  log = NxRohB1.switch(cab: cab, data: {}, barrier: false)
  NxTest.refute(log.any? { |l| l[0] == :rebuild }, 'bariera zlyhala: ziadna prestavba')
  NxTest.assert(log.any? { |l| l[0] == :status && l[1] == busy && l[2] == true }, 'veta CORNER_SIDE_BUSY_MSG')
  NxTest.assert(log.any? { |l| l[0] == :push }, 'resync panela')
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'])

  # Vynimka prestavby: resync, vynimka ide dalej (cb wrapper), odpoved ok false.
  boom = ->(_m, _c, _p, **_kw) { raise 'prestavba zlyhala' }
  log = NxRohB1.switch(cab: cab, data: {}, rebuild: boom)
  kinds = log.map(&:first)
  NxTest.assert(kinds.include?(:raised), 'vynimka sa nezamlci (status da cb wrapper)')
  NxTest.assert(kinds.index(:push) && kinds.index(:push) < kinds.rindex(:js), 'resync pred odpovedou')
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'], 'odpoved ok false aj pri vynimke')

  # Nerohova skrinka / rovnaka strana / neznama strana.
  low = NxRohB1::FakeCab.new(NxRohB1::JSON_LOWER)
  log = NxRohB1.switch(cab: low, data: {})
  NxTest.refute(log.any? { |l| l[0] == :rebuild }, 'dolna: ziadna prestavba')
  NxTest.assert(log.any? { |l| l[0] == :status && l[1] == 'Stranu dverí má len rohová skrinka.' })
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'])
  log = NxRohB1.switch(cab: cab, data: { 'corner_side' => 'left' })
  NxTest.refute(log.any? { |l| l[0] == :rebuild }, 'rovnaka strana: ziadny krok Spat')
  NxTest.assert_equal(true, NxRohB1.ack(log)['ok'])
  log = NxRohB1.switch(cab: cab, data: { 'corner_side' => 'hore' })
  NxTest.refute(log.any? { |l| l[0] == :rebuild }, 'neznama strana: nic')
  NxTest.assert_equal(false, NxRohB1.ack(log)['ok'])

  # Bez tokenu (stary klient) sa odpoved neposiela, prestavba prebehne.
  log = NxRohB1.switch(cab: cab, data: { 'switch_token' => nil })
  NxTest.assert(log.any? { |l| l[0] == :rebuild } && NxRohB1.ack(log).nil?, 'bez tokenu ziadna odpoved')
end

module NxRohB1
  JSON_LOWER = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'thickness' => 18.0 }.freeze
end
