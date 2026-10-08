# frozen_string_literal: true
# ROH-A2 · K3 — VKLADANIE A NAHLAD ROHOVEJ (blok 8, typ `corner_blind`).
# Package: SYSTEM/archiv/bloky/ROHOVA/PACKAGE_ROHA2.md (kontrakt z ROH-A1 sa nemeni).
#
# CO PLATI:
#   * preflight ciel vracia CELNY OTVOR `opening {x0, w, z0, h}` pre KAZDY typ
#     (rohova: dverova cast so zivou sirkou, vpravo `x0 = W − D`; slot vlastny;
#     dolna a horna cela sirka) — aj pri odmietnuti, ked ho server spocital;
#   * payload oznacenej skrinky nesie `front_opening` ulozeneho stavu z tej
#     istej autority (`Construction.front_opening`);
#   * vkladanie: `DEFAULTS.corner_blind` = `CORNER_DEFAULTS`, preflight pri
#     vkladani cita stranu a dverovu cast z PAYLOADU (predvolby / sablona);
#   * UI: tlacidlo „Rohová" vo vkladacej karte (jeden rad), modal sablony
#     pozna typ rohovej, ikona `cab-corner` v sprite a v inventari UI_DIZAJN.
#
# MUTACIE (overene rucne pri davke, report):
#   M1 `out['opening']` az po kontrole medzery pri rohu -> „otvor ide aj s odmietnutim"
#   M2 payload bez `front_opening`                        -> „payload skrinky nesie otvor"
#   M3 tlacidlo mimo `#insertTypeRow`                     -> „tlacidlo Rohová v jednom rade"
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  %w[actions_cabinet actions_templates payloads].each do |f|
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', f)
  end
end

module NxRohA2
  module_function

  E  = Noxun::Engine
  CB = E::CabinetBuilder
  CN = E::Construction

  FRONTS = { 'gap' => 3.0, 'gap_top' => 5.0, 'gap_bottom' => 0.0, 'gap_left' => 2.0, 'gap_right' => 2.0,
             'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'wings' => '1',
                           'direction' => 'right' }] }.freeze

  def src(*parts)
    File.read(File.join(NxTest::ROOT, *parts), encoding: 'UTF-8')
  end

  def data(over = {})
    { 'type' => 'corner_blind', 'width' => 1100.0, 'height' => 862.0, 'floor_height' => 150.0,
      'fronts' => JSON.parse(JSON.generate(FRONTS)), 'revision' => 1 }.merge(over)
  end

  def stored(over = {})
    base = { 'type' => 'corner_blind', 'width' => 1100.0, 'height' => 862.0, 'depth' => 510.0,
             'thickness' => 18.0, 'floor_height' => 150.0, 'fronts' => JSON.parse(JSON.generate(FRONTS)) }
    JSON.parse(JSON.generate(CB.cabinet_config(CB.normalize(base.merge(over)))))
  end

  def pan
    E::Panel
  end
end

# ============================================================================
# 1. PREFLIGHT: OTVOR V ODPOVEDI PRE KAZDY TYP
# ============================================================================

NxTest.test('ROH-A2: preflight vracia otvor rohovej — vlavo 0/450, vpravo W − D so zivou sirkou') do
  %w[left right].each do |side|
    st = NxRohA2.stored('corner_side' => side)
    [1100.0, 1200.0].each do |w|
      res = NxRohA2.pan.front_preflight_result(NxRohA2.data('width' => w), st)
      NxTest.assert_equal(true, res['valid'], "#{side} #{w}: #{res['errors'].inspect}")
      x0 = side == 'right' ? w - 450.0 : 0.0
      NxTest.assert_equal({ 'x0' => x0, 'w' => 450.0, 'z0' => 150.0, 'h' => 712.0 }, res['opening'],
                          "#{side} #{w}: otvor = dverova cast (x0 #{x0})")
    end
  end
end

NxTest.test('ROH-A2: preflight pri VKLADANI cita stranu a dverovu cast z payloadu (predvolby / sablona)') do
  res = NxRohA2.pan.front_preflight_result(NxRohA2.data('corner_side' => 'right', 'corner_door_w' => 500.0))
  NxTest.assert_equal({ 'x0' => 600.0, 'w' => 500.0, 'z0' => 150.0, 'h' => 712.0 }, res['opening'],
                      'sablona vpravo / 500 pri sirke 1100')
  d = NxRohA2::CB::CORNER_DEFAULTS
  res = NxRohA2.pan.front_preflight_result(NxRohA2.data('corner_side' => d[:corner_side],
                                                        'corner_door_w' => d[:corner_door_w]))
  NxTest.assert_equal({ 'x0' => 0.0, 'w' => 450.0, 'z0' => 150.0, 'h' => 712.0 }, res['opening'],
                      'predvolby typu = vlavo 450')
  # Oznacena rohova: ULOZENY config prebije payload (server je autorita strany).
  res = NxRohA2.pan.front_preflight_result(NxRohA2.data('corner_side' => 'right'),
                                           NxRohA2.stored('corner_side' => 'left'))
  NxTest.assert_equal(0.0, res['opening']['x0'], 'ulozena strana vlavo vyhrava nad payloadom')
end

NxTest.test('ROH-A2: otvor ide aj s odmietnutim (medzera pri rohu mimo rozsahu)') do
  bad = NxRohA2.data('fronts' => NxRohA2::FRONTS.merge('gap_right' => 0.0))
  res = NxRohA2.pan.front_preflight_result(bad, NxRohA2.stored('corner_side' => 'left'))
  NxTest.assert_equal(false, res['valid'], 'medzera pri rohu 0 = odmietnutie')
  NxTest.assert_equal(450.0, res.dig('opening', 'w'), 'otvor je v odpovedi aj tak (nahlad sa nevrati na celu sirku)')
  # Rozmer mimo rozsahu: otvor sa este nepocital — kluc chyba, panel drzi posledny.
  res = NxRohA2.pan.front_preflight_result(NxRohA2.data('width' => 40.0))
  NxTest.assert_equal(false, res['valid'])
  NxTest.refute(res.key?('opening'), 'nepocitany otvor sa nevymysla')
end

NxTest.test('ROH-A2: ostatne typy — otvor = cela sirka, polozky preflightu bez zmeny') do
  low = NxRohA2.data('type' => 'lower', 'width' => 700.0,
                     'fronts' => NxRohA2::FRONTS.merge('items' => [{ 'id' => 'F1', 'type' => 'door',
                                                                     'mode' => 'auto', 'wings' => 'auto' }]))
  res = NxRohA2.pan.front_preflight_result(low)
  NxTest.assert_equal({ 'x0' => 0.0, 'w' => 700.0, 'z0' => 150.0, 'h' => 712.0 }, res['opening'], 'dolna')
  NxTest.assert_equal(Noxun::Engine::Fronts.preflight(low['fronts'], 700.0, 862.0, 150.0)['items'], res['items'],
                      'dolna: polozky zhodne s preflightom bez otvoru')
  up = NxRohA2.pan.front_preflight_result(low.merge('type' => 'upper', 'floor_height' => 0.0))
  NxTest.assert_equal({ 'x0' => 0.0, 'w' => 700.0, 'z0' => 0.0, 'h' => 862.0 }, up['opening'], 'horna')
  dw = NxRohA2.pan.front_preflight_result(
    low.merge('type' => 'dishwasher', 'width' => 600.0, 'height' => 880.0, 'dw_front_bottom' => 100.0,
              'fronts' => NxRohA2::FRONTS.merge('gap_top' => 2.0,
                                                'items' => [{ 'id' => 'F1', 'type' => 'blind', 'mode' => 'fixed',
                                                              'height' => 778.0 }]))
  )
  NxTest.assert_equal({ 'x0' => 0.0, 'w' => 600.0, 'z0' => 100.0, 'h' => 780.0 }, dw['opening'],
                      'slot ma vlastny otvor (od sokla cela po linku)')
end

# ============================================================================
# 2. PAYLOAD OZNACENEJ SKRINKY + DEFAULTS PRE VKLADANIE
# ============================================================================

NxTest.test('ROH-A2: payload skrinky nesie `front_opening` ulozeneho stavu (ta ista autorita)') do
  NxTest.assert_equal({ 'x0' => 650.0, 'w' => 450.0, 'z0' => 150.0, 'h' => 712.0 },
                      NxRohA2.pan.front_opening_payload(NxRohA2.stored('corner_side' => 'right')), 'rohova vpravo')
  NxTest.assert_equal({ 'x0' => 0.0, 'w' => 900.0, 'z0' => 100.0, 'h' => 620.0 },
                      NxRohA2.pan.front_opening_payload(JSON.parse(JSON.generate(
                        NxRohA2::CB.cabinet_config(NxRohA2::CB.normalize('type' => 'lower', 'width' => 900.0,
                                                                         'height' => 720.0, 'floor_height' => 100.0))
                      ))), 'dolna = cela sirka')
  NxTest.assert_equal(0.0, NxRohA2.pan.front_opening_payload(nil)['w'], 'poskodeny config nevymysli sirku')
  pl = NxRohA2.src('noxun_engine', 'ui', 'panel', 'payloads.rb')
  NxTest.assert(pl.include?("params['front_opening'] = front_opening_payload(cfg)"),
                'cabinet_payload posiela otvor (M2)')
end

NxTest.test('ROH-A2: vkladanie — DEFAULTS rohovej zo servera, JS polia rohovej do payloadu neposiela') do
  sync = NxRohA2.src('noxun_engine', 'ui', 'panel', 'sync.rb')
  # ROH-B1: predvolby = CORNER_DEFAULTS + ucinna hrubka CR 2 (`corner_insert_defaults`).
  # H12b: `init_defaults` — rohova cez `corner_insert_defaults` (kluc `corner_blind` z `DEFAULTS_BY_TYPE`).
  NxTest.assert(sync.include?('defaults: init_defaults(model)') &&
                sync.include?('CabinetTypes.corner?(id) ? corner_insert_defaults(model) : d'), 'DEFAULTS.corner_blind')
  NxTest.assert_equal('corner_blind', NxRohA2::CB::DEFAULTS_BY_TYPE.keys.find { |id| Noxun::Engine::CabinetTypes.corner?(id) })
  d = NxRohA2::CB::CORNER_DEFAULTS
  NxTest.assert_equal(['left', 450.0, 80.0, 80.0, 1100.0],
                      [d[:corner_side], d[:corner_door_w], d[:corner_cr1], d[:corner_cr2], d[:width]])
  # Insert bez poli rohovej (tak ho posiela panel) = predvolby rohovej.
  n = NxRohA2::CB.normalize('type' => 'corner_blind', 'width' => 1100.0, 'height' => 862.0,
                            'floor_height' => 150.0)
  NxTest.assert_equal(['left', 450.0, 80.0, 80.0], n.values_at(:corner_side, :corner_door_w, :corner_cr1, :corner_cr2))
  NxTest.assert_equal('right', n[:fronts]['items'].first['direction'], 'R7: panty pri rohu (vpravo pri dverach vlavo)')
  form = NxRohA2.src('noxun_engine', 'ui', 'js', 'form.js')
  # ROH-B1: strana z registra (prepinac), dverova cast z POLA riadku rohovej.
  NxTest.assert(form.include?('out.corner_side = nxCornerSide();'), 'preflight dostane stranu')
  NxTest.assert(form.include?("out.corner_door_w = c.corner_door_w === '' ? d.corner_door_w : c.corner_door_w;"),
                'preflight dostane zivu dverovu cast')
  actions = NxRohA2.src('noxun_engine', 'ui', 'js', 'actions.js')
  NxTest.refute(actions.include?('cornerDraft'), 'insert payload register nečíta priamo')
  # H12c (T4): „len pri rohovej" = typ s rohovou zostavou z registra (`NXTypes.corner`).
  NxTest.assert(actions.include?("if (NXTypes.corner(p.type) && typeof nxCornerSide === 'function') p.corner_side = nxCornerSide();"),
                'ROH-B1: vklad nesie zvolenu stranu LEN pri rohovej')
  NxTest.assert_equal(['corner_blind'], Noxun::Engine::CabinetTypes.ids_where(:assembly, 'corner_blind'),
                      'rohovu zostavu ma dnes len rohova')
end

# ============================================================================
# 3. UI KOSTRA: tlacidlo, ikona, modal sablony, cache-bust
# ============================================================================

NxTest.test('ROH-A2: tlacidlo „Rohová" v jednom rade vkladacej karty (poradie, aria, ikona)') do
  html = NxRohA2.src('noxun_engine', 'ui', 'panel.html')
  row = html[%r{<div class="segrow" id="insertTypeRow">(.*?)</div>}m, 1].to_s
  NxTest.assert(!row.empty?, 'rad typov existuje')
  order = row.scan(/data-ins-type="([a-z_]+)"/).flatten
  NxTest.assert_equal(%w[lower upper corner_blind dishwasher board], order, 'Dolná · Horná · Rohová · Umývačka · Doska (M3)')
  btn = row[/<button[^>]*id="insTypeCorner"[^>]*>/].to_s
  NxTest.assert(btn.include?('aria-pressed="false"'), 'aria-pressed')
  NxTest.assert(btn.include?("onInsertType('corner_blind')"), 'klik ide cez spolocny onInsertType')
  NxTest.assert(btn.include?('title="Rohová — dolná slepá rohová skrinka s CR lištou (dvere v dverovej časti)"'), 'tooltip')
  NxTest.assert(row.include?('<use href="#i-cab-corner"/>'), 'ikona zo spritu')
  NxTest.assert_equal(1, html.scan('id="insertTypeRow"').length, 'rad je JEDEN (vertikalny priestor)')
  icons = NxRohA2.src('noxun_engine', 'ui', 'js', 'icons.js')
  NxTest.assert(icons.include?("'cab-corner':"), 'symbol v icons.js')
  NxTest.assert(NxRohA2.src('docs', 'UI_DIZAJN.md').include?('`cab-corner`'), 'ikona v inventari UI_DIZAJN §4')
end

NxTest.test('ROH-A2: modal „Uložiť ako šablónu" pozna rohovu a zamyka ju (vzor slotu)') do
  html = NxRohA2.src('noxun_engine', 'ui', 'panel.html')
  sel = html[%r{<select id="tplSaveType">(.*?)</select>}m, 1].to_s
  NxTest.assert(sel.include?('<option value="corner_blind">Rohová</option>'), 'volba Rohová')
  form = NxRohA2.src('noxun_engine', 'ui', 'js', 'form.js')
  # H12c (T4): zamok typu sablony a jeho vety su v registri servera
  # (`template_type: locked` + `template_lock`), JS tabulka TPL_TYPE_LOCK zanikla.
  NxTest.refute(form.include?('TPL_TYPE_LOCK'), 'JS tabulka zamkov zanikla')
  NxTest.assert(form.include?("return (p.template_type === 'locked' && p.template_lock) ? p.template_lock : null;"),
                'zamok cita register')
  ct = Noxun::Engine::CabinetTypes
  NxTest.assert_equal(%w[dishwasher corner_blind], ct.ids_where(:template_type, 'locked'), 'zamok typu slot + rohova')
  NxTest.assert(ct.prop('corner_blind', :template_lock)[:tip].include?('rohovú zostavu'), 'veta bubliny rohovej')
  NxTest.assert_equal('', Noxun::Engine::Panel.apply_template_type!({ 'type' => 'corner_blind' }, 'lower'),
                      'server typ rohovej sablony nepreklopi')
end

NxTest.test('ROH-A2: nahlad noh vo vkladani plati aj pre rohovu') do
  hw = NxRohA2.src('noxun_engine', 'ui', 'js', 'hardware.js')
  # H12c (T4): „ma nohy" = znamy typ na podlahe (`on_floor` registra), nie JS zoznam.
  NxTest.assert(hw.include?('function nxLegsTypeHasLegs(t){ return NXTypes.known(t) && NXTypes.onFloor(t); }'),
                'rohova ma nohy ako dolna')
  NxTest.assert_equal(%w[lower corner_blind], Noxun::Engine::CabinetTypes.ids_where(:on_floor, true),
                      'na podlahe stoja dolna a rohova')
  NxTest.refute(hw.include?("if (getType() !== 'lower') return false;"), 'odpoved rohovej sa nezahadzuje')
end
