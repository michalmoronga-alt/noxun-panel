# frozen_string_literal: true
# CENY-M1b — rucne overenie ceny dosky a ABS bez Demosu (SCHEMA 12).
#
# Co tato sada strazi (package CENY-M1 §7 bod 2, poziadavky [B]):
#   R1/R2  marker 12 LEN obsahom (kluc metody), nezavisi od poradia zaznamov;
#   R5     duplak metodu nezdedi;
#   R9     normalize nesie 'manual' LEN s datumom, bez Demosu, nie UNI/duplak;
#          'manual' pri Demos vazbe zahodi metodu AJ datum (poistka O8);
#   R10    `manual_price_state` — fresh/stale/never, prah, buduci a poskodeny
#          datum, bez ceny, bez odkazu = fresh, UNI/duplak/Demos = nil;
#   R11    `confirm_manual_price` — plate/m2/bm, 0, prazdna, zaporna, necislo,
#          plate bez formatu, UNI, duplak, Demos, konflikt, chybajuca polozka,
#          read-only, bez odkazu OK, datum a metoda zo servera, marker 12;
#   R11a   „bez zmeny" = PRESNA zhoda so ZOBRAZENOU hodnotou (hranice pol
#          centa x formaty; ABS 0,125 vs 0,13 = zmena), `plate` nil bez formatu;
#   O7     mriezka formatov x ceny po centoch — Rozpocet ukaze za platnu
#          presne zadanu sumu (aj po JSON okruhu);
#   R12    echo zobrazenej €/m2 (bunka, formular, editor, confirm m2; ABS nie);
#   R13    O6 matica — kazda cesta x kazde overene pole rusi overenie + veta
#          R22; nezneplatnujuce cesty overenie nechaju;
#   R13b   D-148 — formular ceruzky pri Demos polozke rusi datum z Demosu;
#   R14    O8 — Demos ma prednost, odkaz sa nemaze, rucny datum sa netvari
#          ako Demos datum;
#   R15    akcie mat_manual_prepare/open/confirm (openURL false neblokuje);
#   R8     payload `price_display`, `price_check`, `stale_days`;
#   R24    Rozpocet s novymi polami = rovnake cisla, riadky aj XLSX.
require_relative '../helper' unless defined?(NxTest)
require_relative 'test_ceny_m1_links'
require_relative 'test_np4_golden'

module CenyM1b
  E = Noxun::Engine
  M = E::Materials
  S = E::JsonFileStore
  D = E::MaterialsDialog
  MANUAL_MSG = 'Uložené — ručné overenie ceny sa zrušilo, položka ide na kontrolu.'
  DEMOS_MSG = 'Uložené — dátum overenia z Demosu sa zrušil, cenu obnoví Prepočítať ceny.'

  module_function

  def seed!
    CenyM1.seed!
  end

  def confirm(kind, id, price, basis)
    rec = kind == 'edge' ? M.edge(id) : M.sheet(id)
    M.confirm_manual_price(kind, id, price: price, basis: basis, row_rev: M.record_rev(rec))
  end

  # Rucne overena doska s presnou €/m2 (179,90 € za platnu 2800 x 2070).
  def checked_sheet!(ids)
    st, info, = confirm('sheet', ids[:s25], '179,90', 'plate')
    raise "confirm: #{info.inspect}" unless st == :ok
    M.sheet(ids[:s25])
  end

  def checked_edge!(ids)
    st, info, = confirm('edge', ids[:e08], '0,9', 'bm')
    raise "confirm: #{info.inspect}" unless st == :ok
    M.edge(ids[:e08])
  end

  def manual?(rec)
    rec['price_check_method'] == 'manual' && !rec['price_checked_at'].to_s.empty?
  end

  def status_of(out)
    CenyM1.status_of(out)
  end

  # Priamy zapis zaznamu do suboru (bez normalize) — pre nastavenie stavu,
  # ktory by beznou cestou nevznikol (poskodeny datum, cena na hranici).
  def poke!(listk, idk, id, patch)
    data = JSON.parse(File.binread(M.path))
    rec = data[listk].find { |r| r[idk] == id }
    patch.each { |k, v| v.nil? ? rec.delete(k) : rec[k] = v }
    File.binwrite(M.path, JSON.generate(data))
    S.invalidate(M.path)
  end

  def editor_rows(gid, over = {})
    M.sheets.select { |x| x['group_id'] == gid && !M.duplak?(x) }.map do |x|
      row = { 'material_id' => x['material_id'], 'row_rev' => M.record_rev(x), 'type' => x['type'],
              'thickness' => M.fmt_mm(x['thickness']),
              'sheet_size' => x['sheet_size'] ? x['sheet_size'].map { |v| M.fmt_mm(v) }.join('×') : '',
              'code' => x['code'].to_s, 'supplier' => x['supplier'].to_s,
              # R21: editor ukazuje ZOBRAZENU €/m2 s ciarkou
              'price_per_m2' => M.display_m2(x['price_per_m2']).nil? ? '' : format('%.2f', M.display_m2(x['price_per_m2'])).tr('.', ',') }
      row.merge(over[x['material_id']] || {})
    end
  end

  def editor_edge_rows(gid, over = {})
    M.edges.select { |x| x['group_id'] == gid }.map do |x|
      row = { 'abs_id' => x['abs_id'], 'row_rev' => M.record_rev(x), 'width' => M.fmt_mm(x['width']),
              'thickness' => M.fmt_mm(x['thickness']), 'code' => x['code'].to_s, 'supplier' => x['supplier'].to_s,
              'price_per_bm' => x['price_per_bm'].nil? ? '' : x['price_per_bm'].to_s }
      row.merge(over[x['abs_id']] || {})
    end
  end

  def save_editor(gid, sheets_over = {}, edges_over = {})
    M.save_decor('mode' => 'edit', 'group_id' => gid, 'base_rev' => M.catalog_revision,
                 'catalog_schema' => M::SCHEMA_CURRENT, 'decor' => 'H1180', 'decor_name' => 'Dub Halifax',
                 'manufacturer' => 'Egger', 'sheets' => editor_rows(gid, sheets_over),
                 'edges' => editor_edge_rows(gid, edges_over))
  end

  # Studio kontext pre akcie mat_manual_* (vzor test_ceny_kov_manual.rb).
  def with_model
    made_su = !Object.const_defined?(:Sketchup)
    Object.const_set(:Sketchup, Module.new) if made_su
    model = Struct.new(:path).new('')
    had = Sketchup.respond_to?(:active_model)
    old = Sketchup.method(:active_model) if had
    Sketchup.define_singleton_method(:active_model) { model }
    CenyM1.with_ui { |opened| yield(E::DocKey.key(model), opened) }
  ensure
    if had
      Sketchup.define_singleton_method(:active_model, old)
    elsif !made_su && Object.const_defined?(:Sketchup)
      Sketchup.singleton_class.send(:remove_method, :active_model) rescue nil
    end
    Object.send(:remove_const, :Sketchup) if made_su
  end

  def parse(out, fn)
    s = out.find { |v| v.start_with?("#{fn}(") }
    s && JSON.parse(s[(fn.length + 1)...-1])
  end
end

# --- R1 / R2 / R5: schema a whitelisty -------------------------------------------

NxTest.test('CENY-M1b (R1): SCHEMA_MANUAL_CHECK = 12 = SCHEMA_CURRENT') do
  NxTest.assert_equal(12, CenyM1b::M::SCHEMA_MANUAL_CHECK)
  NxTest.assert_equal(CenyM1b::M::SCHEMA_MANUAL_CHECK, CenyM1b::M::SCHEMA_CURRENT)
end

NxTest.test('CENY-M1b (R2): marker 12 za kluc metody v kazdom poradi zaznamov') do
  m = CenyM1b::M
  recs = [{ 'appearance' => { 'version' => 1 } }, { 'uni' => true }, { 'demos_url' => 'https://www.demos-trade.sk/x' },
          { 'product_url' => 'https://shop.example/p' },
          { 'price_check_method' => 'manual', 'price_checked_at' => '2026-09-01T00:00:00Z' }]
  recs.permutation.each do |perm|
    NxTest.assert_equal(12, m.required_schema_for(perm, []), perm.map(&:keys).inspect)
    NxTest.assert_equal(12, m.required_schema_for([], perm), "ABS: #{perm.map(&:keys).inspect}")
  end
  recs[0..3].permutation.each do |perm|
    NxTest.assert_equal(11, m.required_schema_for(perm, []), 'bez metody drzi 11')
  end
end

NxTest.test('CENY-M1b (R1): marker 12 zdvihne az prve potvrdenie, bezny zapis nie') do
  ids = CenyM1b.seed!
  data = CenyM1.raw
  data['schema'] = 11
  File.binwrite(CenyM1b::M.path, JSON.generate(data))
  CenyM1b::S.invalidate(CenyM1b::M.path)
  NxTest.assert(CenyM1b::M.upsert_sheet(CenyM1b::M.sheet(ids[:s25]).merge('code' => 'X9')))
  NxTest.assert_equal(11, CenyM1.marker, 'zapis bez metody marker nemeni')
  CenyM1b.checked_sheet!(ids)
  NxTest.assert_equal(12, CenyM1.marker, 'prve rucne potvrdenie zdvihlo marker')
end

NxTest.test('CENY-M1b (R5): duplak metodu ani datum nezdedi') do
  src = { 'material_id' => 'S', 'decor' => 'D', 'type' => 'DTDL', 'thickness' => 18.0, 'price_per_m2' => 30.0,
          'price_check_method' => 'manual', 'price_checked_at' => '2026-09-01T00:00:00Z' }
  dup = CenyM1b::M.duplak_record_from(src, 2)
  NxTest.refute(dup.key?('price_check_method'))
  NxTest.refute(dup.key?('price_checked_at'))
end

# --- R9: normalizacia ------------------------------------------------------------

NxTest.test('CENY-M1b (R9): normalize nesie manual len s datumom, bez Demosu, nie UNI/duplak') do
  m = CenyM1b::M
  stamp = '2026-09-01T10:00:00Z'
  base = { 'material_id' => 'X', 'decor' => 'D', 'type' => 'DTDL', 'thickness' => 18.0, 'group_id' => 'G',
           'price_per_m2' => 30.0, 'price_check_method' => 'manual', 'price_checked_at' => stamp }
  ok = m.normalize_sheet(base)
  NxTest.assert_equal('manual', ok['price_check_method'])
  NxTest.assert_equal(stamp, ok['price_checked_at'])
  NxTest.refute(m.normalize_sheet(base.merge('price_checked_at' => '')).key?('price_check_method'), 'bez datumu metoda nezije')
  demos = m.normalize_sheet(base.merge('demos_url' => CenyM1::DEMOS))
  NxTest.refute(demos.key?('price_check_method'), 'manual pri Demos vazbe = zahodena metoda')
  NxTest.refute(demos.key?('price_checked_at'), 'a AJ datum — rucny datum sa netvari ako Demos datum (O8)')
  NxTest.refute(m.normalize_sheet(base.merge('uni' => true, 'uni_role' => 'body')).key?('price_check_method'))
  NxTest.refute(m.normalize_sheet(base.merge('source_material_id' => 'Y', 'source_multiplier' => 2)).key?('price_check_method'))
  NxTest.refute(m.normalize_sheet(base.merge('price_check_method' => 'demos')).key?('price_check_method'), 'ina hodnota zahodena')
  NxTest.assert_equal(stamp, m.normalize_sheet(base.merge('price_check_method' => 'demos'))['price_checked_at'])
  edge = { 'abs_id' => 'A', 'decor' => 'D', 'thickness' => 1.0, 'group_id' => 'G', 'price_per_bm' => 0.5,
           'price_check_method' => 'manual', 'price_checked_at' => stamp }
  NxTest.assert_equal('manual', m.normalize_edge(edge)['price_check_method'])
  e_demos = m.normalize_edge(edge.merge('demos_url' => 'https://www.demos-trade.sk/abs'))
  NxTest.refute(e_demos.key?('price_check_method'))
  NxTest.refute(e_demos.key?('price_checked_at'))
end

# --- R10: stav rucneho overenia ----------------------------------------------------

NxTest.test('CENY-M1b (R10): manual_price_state — fresh/stale/never, prah, buduci a poskodeny datum') do
  m = CenyM1b::M
  now = Time.utc(2026, 9, 30, 12)
  rec = ->(stamp, extra = {}) {
    { 'material_id' => 'X', 'price_per_m2' => 30.0, 'price_check_method' => 'manual',
      'price_checked_at' => stamp }.merge(extra)
  }
  d29 = (now - (29 * 86_400)).iso8601
  d30 = (now - (30 * 86_400)).iso8601
  NxTest.assert_equal({ 'state' => 'fresh', 'checked_at' => d29, 'age_days' => 29 }, m.manual_price_state(rec.call(d29), stale_days: 30, now: now))
  NxTest.assert_equal({ 'state' => 'stale', 'checked_at' => d30, 'age_days' => 30 }, m.manual_price_state(rec.call(d30), stale_days: 30, now: now))
  NxTest.assert_equal('stale', m.manual_price_state(rec.call(d29), stale_days: 10, now: now)['state'], 'prah z nastaveni')
  NxTest.assert_equal(0, m.manual_price_state(rec.call(now.iso8601), stale_days: 30, now: now)['age_days'])
  never = { 'state' => 'never', 'checked_at' => nil, 'age_days' => nil }
  NxTest.assert_equal(never, m.manual_price_state(rec.call((now + 3600).iso8601), stale_days: 30, now: now), 'buduci datum')
  NxTest.assert_equal(never, m.manual_price_state(rec.call('vcera'), stale_days: 30, now: now), 'poskodeny datum')
  NxTest.assert_equal(never, m.manual_price_state(rec.call(d29).reject { |k, _| k == 'price_per_m2' }, stale_days: 30, now: now), 'bez ceny')
  NxTest.assert_equal(never, m.manual_price_state(rec.call(d29, 'price_per_m2' => -1.0), stale_days: 30, now: now))
  NxTest.assert_equal(never, m.manual_price_state(rec.call(d29).reject { |k, _| k == 'price_check_method' }, stale_days: 30, now: now))
  NxTest.assert_equal('fresh', m.manual_price_state(rec.call(d29, 'price_per_m2' => 0.0), stale_days: 30, now: now)['state'], '0 € je platna cena')
  NxTest.assert_equal('fresh', m.manual_price_state(rec.call(d29), stale_days: 30, now: now)['state'], 'bez odkazu = fresh (O9)')
  NxTest.assert_equal('fresh', m.manual_price_state({ 'abs_id' => 'A', 'price_per_bm' => 0.5, 'price_check_method' => 'manual',
                                                      'price_checked_at' => d29 }, stale_days: 30, now: now)['state'], 'ABS €/bm')
  NxTest.assert_equal(nil, m.manual_price_state(rec.call(d29, 'demos_url' => CenyM1::DEMOS), stale_days: 30, now: now))
  NxTest.assert_equal(nil, m.manual_price_state(rec.call(d29, 'uni' => true), stale_days: 30, now: now))
  NxTest.assert_equal(nil, m.manual_price_state(rec.call(d29, 'source_material_id' => 'Y'), stale_days: 30, now: now))
end

# --- R11: potvrdenie ----------------------------------------------------------------

NxTest.test('CENY-M1b (R11): potvrdenie za platnu, za m2 a za bm — datum a metoda zo servera, marker 12') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  before = Time.now.utc - 1
  st, info, = CenyM1b.confirm('sheet', ids[:s25], '179,90', 'plate')
  NxTest.assert_equal(:ok, st, info.inspect)
  rec = m.sheet(ids[:s25])
  NxTest.assert_equal(179.9 / 5.796, rec['price_per_m2'], '€/m2 NEZAOKRUHLENE (O7)')
  NxTest.assert_equal(179.9, Noxun::Engine::Budget.price_per_plate(rec['price_per_m2'], nil, rec['sheet_size']), 'Rozpocet ukaze presne 179,90')
  NxTest.assert_equal(179.9, info['plate'])
  NxTest.assert_equal(false, info['unchanged'])
  NxTest.assert_equal('manual', rec['price_check_method'])
  t = Time.iso8601(rec['price_checked_at'])
  NxTest.assert(t >= before && t <= Time.now.utc, 'datum zo servera v okne behu')
  NxTest.assert_equal(12, CenyM1.marker)
  st, = CenyM1b.confirm('sheet', ids[:s25], '31,50', 'm2')
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal(31.5, m.sheet(ids[:s25])['price_per_m2'])
  st, = CenyM1b.confirm('edge', ids[:e08], '1,15', 'bm')
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal(1.15, m.edge(ids[:e08])['price_per_bm'])
  NxTest.assert_equal('manual', m.edge(ids[:e08])['price_check_method'])
end

NxTest.test('CENY-M1b (R11/O4/O9): 0 € aj polozka bez odkazu sa potvrdit daju; prazdna, zaporna, necislo nie') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  NxTest.refute(m.sheet(ids[:s25]).key?('product_url'), 'seed: doska bez odkazu')
  st, info, = CenyM1b.confirm('sheet', ids[:s25], '0', 'plate')
  NxTest.assert_equal(:ok, st, "0 € bez odkazu: #{info.inspect}")
  NxTest.assert_equal(0.0, m.sheet(ids[:s25])['price_per_m2'])
  [nil, '', '  ', 'abc', '-1', '-0,01', Float::INFINITY, Float::NAN, false, {}, []].each do |bad|
    before = CenyM1.bytes
    st, msg, field = CenyM1b.confirm('sheet', ids[:s25], bad, 'plate')
    NxTest.assert_equal(:invalid, st, bad.inspect)
    NxTest.assert_equal('price', field)
    NxTest.assert_equal('Vlož nezápornú cenu s DPH; prázdna cena sa nedá potvrdiť.', msg)
    NxTest.assert_equal(before, CenyM1.bytes, "#{bad.inspect}: nic sa nezapisalo")
  end
  before = CenyM1.bytes
  NxTest.assert_equal(:invalid, CenyM1b.confirm('sheet', ids[:s25], '10', 'bm')[0], 'doska nema bm')
  NxTest.assert_equal(:invalid, CenyM1b.confirm('edge', ids[:e08], '10', 'plate')[0], 'ABS nema platnu')
  NxTest.assert_equal(before, CenyM1.bytes)
end

NxTest.test('CENY-M1b (R11): plate bez formatu, UNI, duplak, Demos, konflikt, chybajuca polozka, read-only') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  CenyM1b.poke!('sheets', 'material_id', ids[:s25], 'sheet_size' => nil)
  before = CenyM1.bytes
  st, msg, field = CenyM1b.confirm('sheet', ids[:s25], '100', 'plate')
  NxTest.assert_equal([:invalid, 'basis'], [st, field])
  NxTest.assert(msg.include?('bez formátu'), msg)
  NxTest.assert_equal(nil, m.price_display(m.sheet(ids[:s25]))['plate'], 'bez formatu price_display.plate = nil (delta audit)')
  NxTest.assert_equal(:ok, CenyM1b.confirm('sheet', ids[:s25], '95,5', 'm2')[0], 'sklo bez formatu za m2 (O3)')
  uni = m.sheets.find { |s| m.uni?(s) }
  NxTest.assert_equal(:invalid, CenyM1b.confirm('sheet', uni['material_id'], '1', 'm2')[0])
  st, drec = m.create_duplak_sheet(ids[:s25], 2)
  NxTest.assert_equal(:ok, st, drec.inspect)
  NxTest.assert_equal(:invalid, CenyM1b.confirm('sheet', drec['material_id'], '1', 'm2')[0])
  st, msg, = CenyM1b.confirm('sheet', ids[:s18], '1', 'plate')
  NxTest.assert_equal(:invalid, st)
  NxTest.assert_equal('Položka je viazaná na Demos — cenu obnovuje Demos.', msg)
  before = CenyM1.bytes
  NxTest.assert_equal(:conflict, m.confirm_manual_price('sheet', ids[:s25], price: '1', basis: 'm2', row_rev: 'stary')[0])
  NxTest.assert_equal(:conflict, m.confirm_manual_price('sheet', ids[:s25], price: '1', basis: 'm2', row_rev: '')[0])
  NxTest.assert_equal(:not_found, m.confirm_manual_price('sheet', 'NIE', price: '1', basis: 'm2', row_rev: 'x')[0])
  NxTest.assert_equal(before, CenyM1.bytes)
  rev = m.record_rev(m.sheet(ids[:s25]))
  CenyM1.stub(m, :catalog_read_only?, -> { true }) do
    st, = m.confirm_manual_price('sheet', ids[:s25], price: '1', basis: 'm2', row_rev: rev)
    NxTest.assert_equal(:catalog_read_only, st)
  end
  NxTest.assert_equal(before, CenyM1.bytes)
end

NxTest.test('CENY-M1b (R11a): hranice pol centa x formaty — zobrazena hodnota = bez zmeny, susedny cent = zmena') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  b = Noxun::Engine::Budget
  formats = [[1000.0, 1000.0], [2800.0, 2070.0], [4100.0, 635.0]]
  [1.005, 31.005, 2.675, 0.125, 31.03864734299517].each do |stored|
    formats.each do |fmt|
      tag = "#{stored} @ #{fmt.inspect}"
      CenyM1b.poke!('sheets', 'material_id', ids[:s25], 'price_per_m2' => stored, 'sheet_size' => fmt,
                    'price_check_method' => nil, 'price_checked_at' => nil)
      pd = m.price_display(m.sheet(ids[:s25]))
      NxTest.assert_equal(b.price_per_plate(stored, nil, fmt), pd['plate'], "#{tag}: plate = Rozpocet")
      NxTest.assert_equal(m.display_m2(stored), pd['m2'])
      # za platnu: vstup = zobrazena cena platne -> bitovo bez zmeny
      st, info, = CenyM1b.confirm('sheet', ids[:s25], format('%.2f', pd['plate']).tr('.', ','), 'plate')
      NxTest.assert_equal(:ok, st, tag)
      NxTest.assert_equal(true, info['unchanged'], "#{tag}: plate bez zmeny")
      NxTest.assert(stored.eql?(m.sheet(ids[:s25])['price_per_m2']), "#{tag}: bitovo ta ista €/m2")
      # susedny cent -> zmena, Rozpocet ukaze presne vstup
      [-0.01, 0.01].each do |delta|
        want = ((pd['plate'] * 100).round + (delta * 100).round) / 100.0
        next if want.negative?
        CenyM1b.poke!('sheets', 'material_id', ids[:s25], 'price_per_m2' => stored)
        st, info, = CenyM1b.confirm('sheet', ids[:s25], format('%.2f', want), 'plate')
        NxTest.assert_equal(:ok, st, tag)
        NxTest.assert_equal(false, info['unchanged'], "#{tag}: plate #{want} je zmena")
        NxTest.assert_equal(want, b.price_per_plate(m.sheet(ids[:s25])['price_per_m2'], nil, fmt), "#{tag}: Rozpocet = #{want}")
      end
      # za m2: vstup = zobrazena €/m2 -> bez zmeny; susedny cent -> zmena
      CenyM1b.poke!('sheets', 'material_id', ids[:s25], 'price_per_m2' => stored)
      st, info, = CenyM1b.confirm('sheet', ids[:s25], format('%.2f', pd['m2']), 'm2')
      NxTest.assert_equal([:ok, true], [st, info['unchanged']], "#{tag}: m2 echo")
      NxTest.assert(stored.eql?(m.sheet(ids[:s25])['price_per_m2']))
      [-0.01, 0.01].each do |delta|
        want = ((pd['m2'] * 100).round + (delta * 100).round) / 100.0
        next if want.negative?
        CenyM1b.poke!('sheets', 'material_id', ids[:s25], 'price_per_m2' => stored)
        st, info, = CenyM1b.confirm('sheet', ids[:s25], format('%.2f', want), 'm2')
        NxTest.assert_equal([:ok, false], [st, info['unchanged']], "#{tag}: m2 #{want} je zmena")
        NxTest.assert_equal(want, m.sheet(ids[:s25])['price_per_m2'])
      end
    end
  end
  # ABS: €/bm presne — 0,125 vs 0,13 je ZMENA (delta audit)
  CenyM1b.poke!('edges', 'abs_id', ids[:e08], 'price_per_bm' => 0.125)
  st, info, = CenyM1b.confirm('edge', ids[:e08], '0,13', 'bm')
  NxTest.assert_equal([:ok, false], [st, info['unchanged']])
  NxTest.assert_equal(0.13, m.edge(ids[:e08])['price_per_bm'])
  CenyM1b.poke!('edges', 'abs_id', ids[:e08], 'price_per_bm' => 0.125)
  st, info, = CenyM1b.confirm('edge', ids[:e08], '0,125', 'bm')
  NxTest.assert_equal([:ok, true], [st, info['unchanged']])
  NxTest.assert(0.125.eql?(m.edge(ids[:e08])['price_per_bm']))
  # sonda auditora: ulozene 1,005 €/m2, 1000 x 1000, vstup 1,00 € = ZMENA
  CenyM1b.poke!('sheets', 'material_id', ids[:s25], 'price_per_m2' => 1.005, 'sheet_size' => [1000.0, 1000.0])
  st, info, = CenyM1b.confirm('sheet', ids[:s25], '1,00', 'plate')
  NxTest.assert_equal([:ok, false], [st, info['unchanged']])
  NxTest.assert_equal(1.0, b.price_per_plate(m.sheet(ids[:s25])['price_per_m2'], nil, [1000.0, 1000.0]))
  # Review #427: platna 1,005 € sa pred delenim zaokruhli na 1,01 € (D3) —
  # to iste ukazuje nahlad klienta (test_ceny_m1_manual.js, mdPlateAmount)
  st, info, = CenyM1b.confirm('sheet', ids[:s25], '1,005', 'plate')
  NxTest.assert_equal([:ok, false], [st, info['unchanged']])
  NxTest.assert_equal(1.01, m.sheet(ids[:s25])['price_per_m2'])
end

NxTest.test('CENY-M1b (O7): mriezka 14 formatov x 0,00–200,00 € po centoch — Rozpocet ukaze presne zadanu platnu') do
  m = CenyM1b::M
  b = Noxun::Engine::Budget
  formats = [[2800.0, 2070.0], [2070.0, 2800.0], [4100.0, 635.0], [4100.0, 600.0], [4100.0, 920.0], [4100.0, 650.0],
             [4100.0, 640.0], [3050.0, 1300.0], [2440.0, 1220.0], [2800.0, 1310.0], [1000.0, 1000.0], [3660.0, 1830.0],
             [2750.0, 1830.0], [5000.0, 500.0], [3050.0, 2070.0]]
  errors = 0
  json_errors = 0
  formats.each do |fmt|
    rec = { 'material_id' => 'X', 'sheet_size' => fmt }
    area3 = (fmt[0] * fmt[1] / 1_000_000.0).round(3)
    (0..20_000).each do |cents|
      plate = cents / 100.0
      m2 = m.plate_to_m2(plate, rec)
      errors += 1 unless b.price_per_plate(m2, area3, fmt) == plate
      json_errors += 1 unless JSON.parse(JSON.generate([m2]))[0].eql?(m2)
    end
  end
  NxTest.assert_equal(0, errors, 'Rozpocet = zadana platna vo vsetkych kombinaciach')
  NxTest.assert_equal(0, json_errors, 'JSON okruh bezstratovy')
end

NxTest.test('CENY-M1b (O7): potvrdenie za platnu cez JsonFileStore okruh — platna presne, €/m2 zobrazena na centy') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  b = Noxun::Engine::Budget
  %w[179,90 0,01 199,99 57,33 123,45].each do |txt|
    st, = CenyM1b.confirm('sheet', ids[:s25], txt, 'plate')
    NxTest.assert_equal(:ok, st, txt)
    m.reload!
    rec = m.sheet(ids[:s25])
    NxTest.assert_equal(txt.tr(',', '.').to_f, b.price_per_plate(rec['price_per_m2'], nil, rec['sheet_size']), txt)
  end
end

# --- R12: echo zobrazenej €/m2 ------------------------------------------------------

NxTest.test('CENY-M1b (R12): bunka — echo zobrazenej €/m2 nic nezapise a overenie ostava; ABS echo nema') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  rec = CenyM1b.checked_sheet!(ids)
  NxTest.assert_equal(31.04, m.display_m2(rec['price_per_m2']))
  before = CenyM1.bytes
  NxTest.assert_equal([:ok, nil], m.patch_record('sheet', ids[:s25], { 'price_per_m2' => '31.04' }, row_rev: m.record_rev(rec)))
  NxTest.assert_equal([:ok, nil], m.patch_record('sheet', ids[:s25], { 'price_per_m2' => '31,04' }, row_rev: m.record_rev(rec)))
  NxTest.assert_equal(before, CenyM1.bytes, 'echo bunky = ziadny zapis')
  out = CenyM1.call('patch_sheet', 'id' => ids[:s25], 'patch' => { 'price_per_m2' => '31.04' },
                                   'row_rev' => m.record_rev(rec), 'catalog_schema' => m::SCHEMA_CURRENT)
  NxTest.assert_equal(['Cena sa nezmenila.', false], CenyM1.status_of(out))
  NxTest.assert_equal(before, CenyM1.bytes)
  NxTest.refute(m.sheet_price_echo?('31.038', rec['price_per_m2']), 'jemnejsie nez cent nie je zobrazena hodnota')
  NxTest.refute(m.sheet_price_echo?('31.03', rec['price_per_m2']))
  NxTest.refute(m.sheet_price_echo?('31.0', 31.005), 'audit: 31,00 nie je echo 31,005 (zobrazene 31,01)')
  NxTest.assert(m.sheet_price_echo?('31.01', 31.005))
  # ABS: €/bm sa nezaokruhluje — 0,13 nad 0,125 je zmena ceny
  a = m.edge(ids[:e08])
  CenyM1b.poke!('edges', 'abs_id', ids[:e08], 'price_per_bm' => 0.125)
  a = m.edge(ids[:e08])
  st, = m.patch_record('edge', ids[:e08], { 'price_per_bm' => '0.13' }, row_rev: m.record_rev(a))
  NxTest.assert_equal(:ok, st)
  NxTest.assert_equal(0.13, m.edge(ids[:e08])['price_per_bm'])
end

NxTest.test('CENY-M1b (R12): formular variantu a editor „Upraviť…" — nedotknuta zobrazena €/m2 cenu nemeni') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  rec = CenyM1b.checked_sheet!(ids)
  exact = rec['price_per_m2']
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'price_per_m2' => '31.04', 'family' => 'Rodina X'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  after = m.sheet(ids[:s25])
  NxTest.assert(exact.eql?(after['price_per_m2']), 'formular: presna €/m2 ostala (S10: 179,90 neskoci na 179,91)')
  NxTest.assert(CenyM1b.manual?(after), 'overenie ostava')
  gid = after['group_id']
  st, info = CenyM1b.save_editor(gid, ids[:s25] => { 'code' => after['code'] })
  NxTest.assert_equal(:ok, st, info.inspect)
  after = m.sheet(ids[:s25])
  NxTest.assert(exact.eql?(after['price_per_m2']), 'editor: presna €/m2 ostala')
  NxTest.assert(CenyM1b.manual?(after), 'editor echo overenie nezrusi')
  NxTest.refute(info.key?('manual_cleared'))
  # confirm m2 s echom = bez zmeny
  st, info, = CenyM1b.confirm('sheet', ids[:s25], '31,04', 'm2')
  NxTest.assert_equal([:ok, true], [st, info['unchanged']])
  NxTest.assert(exact.eql?(m.sheet(ids[:s25])['price_per_m2']))
end

# --- R13: O6 matica zneplatnenia --------------------------------------------------

NxTest.test('CENY-M1b (R13/O6): bunka — cena, kod, dodavatel, dekor u dodavatela rusia overenie + veta R22') do
  { 'price_per_m2' => '40', 'code' => 'NOVY', 'supplier' => 'Iný', 'supplier_decor' => 'H1180X' }.each do |k, v|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    rec = CenyM1b.checked_sheet!(ids)
    out = CenyM1.call('patch_sheet', 'id' => ids[:s25], 'patch' => { k => v }, 'row_rev' => m.record_rev(rec),
                                     'catalog_schema' => m::SCHEMA_CURRENT, 'allow_duplicate_code' => true)
    NxTest.assert_equal([CenyM1b::MANUAL_MSG, false], CenyM1.status_of(out), k)
    after = m.sheet(ids[:s25])
    NxTest.refute(after.key?('price_check_method'), "#{k}: metoda zrusena")
    NxTest.refute(after.key?('price_checked_at'), "#{k}: datum zruseny")
  end
  %w[price_per_bm code supplier].each do |k|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    a = CenyM1b.checked_edge!(ids)
    out = CenyM1.call('patch_edge', 'id' => ids[:e08], 'patch' => { k => k == 'price_per_bm' ? '2' : 'X' },
                                    'row_rev' => m.record_rev(a), 'catalog_schema' => m::SCHEMA_CURRENT,
                                    'allow_duplicate_code' => true)
    NxTest.assert_equal([CenyM1b::MANUAL_MSG, false], CenyM1.status_of(out), "ABS #{k}")
    NxTest.refute(CenyM1b.manual?(m.edge(ids[:e08])), "ABS #{k}")
  end
end

NxTest.test('CENY-M1b (R13/O6): formular variantu — cena, kod, dodavatel, odkaz, format, dekor u dodavatela, Demos URL') do
  cases = {
    'price_per_m2' => { 'price_per_m2' => '40' }, 'code' => { 'code' => 'NOVY' }, 'supplier' => { 'supplier' => 'Iný' },
    'product_url' => { 'product_url' => CenyM1::SHOP }, 'sheet_size zmena' => { 'sheet_size' => [2800.0, 2100.0] },
    'sheet_size zmazanie' => { 'clear_sheet_size' => true }, 'supplier_decor' => { 'supplier_decor' => 'H1180X' },
    'demos_url' => { 'demos_url' => 'https://www.demos-trade.sk/nova-h1180' }
  }
  cases.each do |tag, over|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    CenyM1b.checked_sheet!(ids)
    form = CenyM1.sheet_form(ids[:s25], { 'price_per_m2' => '31.04', 'allow_duplicate_code' => true }.merge(over))
    form.delete('sheet_size') if over['clear_sheet_size']
    out = CenyM1.call('update_sheet', form)
    NxTest.assert_equal([CenyM1b::MANUAL_MSG, false], CenyM1.status_of(out), "#{tag}: #{out.inspect}")
    after = m.sheet(ids[:s25])
    NxTest.refute(after.key?('price_check_method'), "#{tag}: metoda")
    NxTest.refute(after.key?('price_checked_at'), "#{tag}: datum")
  end
  { 'price_per_bm' => { 'price_per_bm' => '2' }, 'code' => { 'code' => 'N' }, 'supplier' => { 'supplier' => 'S' },
    'product_url' => { 'product_url' => 'https://abs.example/43' } }.each do |tag, over|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    CenyM1b.checked_edge!(ids)
    out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e08], { 'allow_duplicate_code' => true }.merge(over)))
    NxTest.assert_equal([CenyM1b::MANUAL_MSG, false], CenyM1.status_of(out), "ABS #{tag}")
    NxTest.refute(CenyM1b.manual?(m.edge(ids[:e08])), "ABS #{tag}")
  end
end

NxTest.test('CENY-M1b (R13/O6): editor „Upraviť…" — cena, kod, dodavatel aj format rusia overenie') do
  { 'price_per_m2' => '40', 'code' => 'NOVY', 'supplier' => 'Iný', 'sheet_size' => '2800×2100' }.each do |k, v|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    rec = CenyM1b.checked_sheet!(ids)
    st, info = CenyM1b.save_editor(rec['group_id'], ids[:s25] => { k => v })
    NxTest.assert_equal(:ok, st, "#{k}: #{info.inspect}")
    NxTest.assert_equal([ids[:s25]], info['manual_cleared'], k)
    NxTest.assert(CenyM1b::D.save_decor_status(info).include?('Ručné overenie ceny sa zrušilo (1×)'), k)
    NxTest.refute(CenyM1b.manual?(m.sheet(ids[:s25])), "editor #{k}")
  end
  ids = CenyM1b.seed!
  m = CenyM1b::M
  a = CenyM1b.checked_edge!(ids)
  st, info = CenyM1b.save_editor(a['group_id'], {}, ids[:e08] => { 'price_per_bm' => '2' })
  NxTest.assert_equal(:ok, st, info.inspect)
  NxTest.refute(CenyM1b.manual?(m.edge(ids[:e08])), 'editor ABS cena')
end

NxTest.test('CENY-M1b (R13): nezneplatnujuce cesty — nazov, farba, vyrobca, premenovanie, vzhlad, smer, cp_nazov, universal, duplak sync, UNI seed') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  rec = CenyM1b.checked_sheet!(ids)
  CenyM1b.checked_edge!(ids)
  gid = rec['group_id']
  survive = lambda do |why|
    NxTest.assert(CenyM1b.manual?(m.sheet(ids[:s25])), "doska po: #{why}")
    NxTest.assert(CenyM1b.manual?(m.edge(ids[:e08])), "ABS po: #{why}")
  end
  NxTest.assert(m.set_decor_name(gid, 'Dub Halifax prírodný')[0])
  NxTest.assert(m.set_decor_manufacturer('H1180', 'Egger AG', group_id: gid)[0])
  NxTest.assert(m.set_decor_color('H1180', [10, 20, 30], group_id: gid)[0]) if m.respond_to?(:set_decor_color)
  survive.call('nazov, vyrobca, farba')
  NxTest.assert(m.rename_decor('H1180', 'H1180X', group_id: gid)[0])
  survive.call('premenovanie')
  s = m.sheet(ids[:s25])
  NxTest.assert_equal(:ok, m.patch_record('sheet', ids[:s25], { 'cp_nazov' => 'Obchodný názov' }, row_rev: m.record_rev(s))[0])
  a = m.edge(ids[:e08])
  NxTest.assert_equal(:ok, m.patch_record('edge', ids[:e08], { 'universal' => true }, row_rev: m.record_rev(a))[0])
  survive.call('cp_nazov a universal')
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'price_per_m2' => '31.04', 'grain' => 'width'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.refute(CenyM1.status_of(out)[0].include?('ručné overenie'), 'smer dekoru nie je overene pole')
  survive.call('smer dekoru vo formulari')
  st, drec = m.create_duplak_sheet(ids[:s25], 2)
  NxTest.assert_equal(:ok, st, drec.inspect)
  NxTest.refute(m.sheet(drec['material_id']).key?('price_check_method'), 'duplak metodu nema')
  NxTest.assert(m.upsert_sheet_with_duplak_sync(m.sheet(ids[:s25]).merge('grain' => 'none')))
  survive.call('upsert so synchrom duplakov')
  _, scope = m.appearance_scope('sheet', ids[:s25])
  st, info = m.publish_appearance('sheet', ids[:s25], baseline: scope['baseline'], mode: 'color')
  NxTest.assert_equal(:ok, st, info.inspect)
  survive.call('vzhlad')
  m.ensure_uni_records!
  survive.call('UNI seed')
end

NxTest.test('CENY-M1b (R13b / D-148): formular ceruzky pri Demos polozke rusi datum pri zmene ceny, kodu, dodavatela, formatu') do
  { 'price_per_m2' => '25', 'code' => 'DEM1', 'supplier' => 'Iný', 'sheet_size' => [2800.0, 2100.0] }.each do |k, v|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    NxTest.refute(m.sheet(ids[:s18])['price_checked_at'].to_s.empty?, 'seed: Demos datum')
    form = CenyM1.sheet_form(ids[:s18], 'price_per_m2' => '20.00', k => v, 'allow_duplicate_code' => true)
    form.delete('clear_sheet_size') if k == 'sheet_size' # seed Demos dosky format nema — tu ho pridavame
    out = CenyM1.call('update_sheet', form)
    NxTest.assert_equal([CenyM1b::DEMOS_MSG, false], CenyM1.status_of(out), "#{k}: #{out.inspect}")
    after = m.sheet(ids[:s18])
    NxTest.refute(after.key?('price_checked_at'), "#{k}: Demos datum zruseny")
    NxTest.assert_equal(CenyM1::DEMOS, after['demos_url'], "#{k}: vazba ostava")
  end
  %w[price_per_bm code supplier].each do |k|
    ids = CenyM1b.seed!
    m = CenyM1b::M
    out = CenyM1.call('update_edge', CenyM1.edge_form(ids[:e10], k => (k == 'price_per_bm' ? '0.75' : 'X'),
                                                     'allow_duplicate_code' => true))
    NxTest.assert_equal([CenyM1b::DEMOS_MSG, false], CenyM1.status_of(out), "ABS #{k}")
    NxTest.refute(m.edge(ids[:e10]).key?('price_checked_at'), "ABS #{k}")
  end
  ids = CenyM1b.seed!
  m = CenyM1b::M
  stamp = m.sheet(ids[:s18])['price_checked_at']
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s18], 'price_per_m2' => '20.00', 'family' => 'X'))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  NxTest.assert_equal(stamp, m.sheet(ids[:s18])['price_checked_at'], 'nezmenena cena (echo 20.00) datum nechava')
end

# --- R14: O8 Demos ma prednost -----------------------------------------------------

NxTest.test('CENY-M1b (R14/O8): Demos apply nad rucne overenou polozkou — metoda zanikne, odkaz ostava') do
  m = CenyM1b::M
  [['nova cena', { 'price' => 33.0 }, true], ['price_confirmed', { 'price_confirmed' => true }, true],
   ['kod', { 'code' => 'DMS-1' }, false]].each do |tag, fields, stamped|
    ids = CenyM1b.seed!
    CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'price_per_m2' => '31.00', 'product_url' => CenyM1::SHOP))
    rec = CenyM1b.checked_sheet!(ids)
    manual_stamp = rec['price_checked_at']
    st, info = m.apply_demos_batch([{ 'kind' => 'sheet', 'id' => ids[:s25], 'row_rev' => m.record_rev(rec),
                                      'fields' => fields.merge('demos_url' => 'https://www.demos-trade.sk/h1180-25') }],
                                   catalog_rev: m.catalog_revision)
    NxTest.assert_equal(:ok, st, "#{tag}: #{info.inspect}")
    after = m.sheet(ids[:s25])
    NxTest.refute(after.key?('price_check_method'), "#{tag}: metoda zanikla")
    NxTest.assert_equal(CenyM1::SHOP, after['product_url'], "#{tag}: odkaz sa NEMAZE (odlozeny)")
    if stamped
      NxTest.refute(after['price_checked_at'].to_s.empty?, "#{tag}: Demos datum zapisany")
    else
      NxTest.refute(after.key?('price_checked_at'), "#{tag}: rucny datum sa netvari ako Demos datum (S8)")
    end
    NxTest.assert_equal(nil, m.manual_price_state(after, stale_days: 30, now: Time.now.utc), "#{tag}: Demos = nil")
    NxTest.assert(Time.iso8601(after['price_checked_at']) >= Time.iso8601(manual_stamp), "#{tag}: Demos datum je novy") if stamped
  end
end

NxTest.test('CENY-M1b (R14/O8): formular — Demos URL k rucne overenej polozke zrusi overenie; zrusenie vazby vrati odkaz, overenie nie') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'price_per_m2' => '31.00', 'product_url' => CenyM1::SHOP))
  CenyM1b.checked_sheet!(ids)
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'price_per_m2' => '31.04',
                                                     'demos_url' => 'https://www.demos-trade.sk/h1180-25'))
  NxTest.assert_equal([CenyM1b::MANUAL_MSG, false], CenyM1.status_of(out))
  after = m.sheet(ids[:s25])
  NxTest.refute(after.key?('price_check_method'))
  NxTest.refute(after.key?('price_checked_at'))
  NxTest.assert_equal(CenyM1::SHOP, after['product_url'])
  out = CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'demos_url' => ''))
  NxTest.assert(out.include?('ECHO'), out.inspect)
  after = m.sheet(ids[:s25])
  NxTest.assert_equal(CenyM1::SHOP, after['product_url'], 'odkaz je znova aktivny')
  NxTest.assert_equal({ 'state' => 'never', 'checked_at' => nil, 'age_days' => nil },
                      m.manual_price_state(after, stale_days: 30, now: Time.now.utc), 'overenie sa nevracia')
end

# --- R8: payload --------------------------------------------------------------------

NxTest.test('CENY-M1b (R8): payload — price_display na riadkoch, price_check len pri rucnych, stale_days z nastaveni') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  rec = CenyM1b.checked_sheet!(ids)
  pay = nil
  CenyM1.stub(CenyM1b::E::SupplierSettings, :active, -> { { 'stale_days' => 10 } }) { pay = CenyM1b::D.catalog_payload }
  NxTest.assert_equal(10, pay[:stale_days])
  row = pay[:catalog]['sheets'].find { |s| s['material_id'] == ids[:s25] }
  NxTest.assert_equal({ 'plate' => 179.9, 'm2' => 31.04, 'area' => 5.796 }, row['price_display'])
  NxTest.assert_equal('fresh', row['price_check']['state'])
  NxTest.assert_equal(0, row['price_check']['age_days'])
  NxTest.assert_equal(m.record_rev(rec), row['row_rev'], 'row_rev zo suroveho zaznamu')
  demos = pay[:catalog]['sheets'].find { |s| s['material_id'] == ids[:s18] }
  NxTest.refute(demos.key?('price_check'), 'Demos riadok stav rucneho overenia nema')
  uni = pay[:catalog]['sheets'].find { |s| m.uni?(s) }
  NxTest.refute(uni.key?('price_check'))
  edge = pay[:catalog]['edges'].find { |a| a['abs_id'] == ids[:e08] }
  NxTest.assert_equal({ 'bm' => 0.9 }, edge['price_display'])
  NxTest.assert_equal('never', edge['price_check']['state'])
  CenyM1.stub(CenyM1b::E::SupplierSettings, :active, -> { raise IOError, 'disk' }) do
    NxTest.assert_equal(30, CenyM1b::D.manual_stale_days, 'fail-soft 30')
  end
end

# --- R15: akcie kanala ----------------------------------------------------------------

NxTest.test('CENY-M1b (R15): mat_manual_prepare / open nic nezapisu; openURL false potvrdenie neblokuje') do
  CenyM1.headless!
  ids = CenyM1b.seed!
  m = CenyM1b::M
  CenyM1.call('update_sheet', CenyM1.sheet_form(ids[:s25], 'price_per_m2' => '31.00', 'product_url' => CenyM1::SHOP))
  CenyM1b.with_model do |guid, opened|
    req = { 'kind' => 'sheet', 'id' => ids[:s25], 'token' => 't1', 'section' => 'mat', 'model_guid' => guid }
    before = CenyM1.bytes
    ready = CenyM1b.parse(CenyM1.call('mat_manual_prepare', req), 'MD.manualReady')
    NxTest.assert_equal('t1', ready['token'])
    NxTest.assert_equal(true, ready['has_url'])
    NxTest.assert_equal(false, ready['read_only'])
    NxTest.assert_equal(m.record_rev(m.sheet(ids[:s25])), ready['row_rev'])
    NxTest.assert_equal(31.0, ready['item']['price_display']['m2'])
    NxTest.assert_equal('never', ready['item']['price_check']['state'])
    NxTest.assert(ready['item']['label'].to_s.length.positive?)
    NxTest.assert_equal([], opened, 'prepare prehliadac neotvara')
    ack = CenyM1b.parse(CenyM1.call('mat_manual_open', req.merge('row_rev' => ready['row_rev'], 'url' => 'https://zly.example')),
                        'MD.manualResult')
    NxTest.assert_equal(%w[open ok], [ack['phase'], ack['status']])
    NxTest.assert_equal(true, ack['opened'])
    NxTest.assert_equal([CenyM1::SHOP], opened, 'URL zo servera, nie od klienta')
    stale = CenyM1b.parse(CenyM1.call('mat_manual_open', req.merge('row_rev' => 'stary')), 'MD.manualResult')
    NxTest.assert_equal(%w[open conflict], [stale['phase'], stale['status']])
    NxTest.assert_equal(1, opened.length, 'zmeneny riadok neotvori iny produkt')
    UI.define_singleton_method(:openURL) { |_u| false }
    failed = CenyM1b.parse(CenyM1.call('mat_manual_open', req.merge('row_rev' => ready['row_rev'])), 'MD.manualResult')
    NxTest.assert_equal(true, failed['ok'], 'neuspesne otvorenie NEBLOKUJE (mockup B1)')
    NxTest.assert_equal(false, failed['opened'])
    NxTest.assert_equal('Obchod sa nepodarilo otvoriť — cenu si over inak a potvrď.', failed['msg'])
    NxTest.assert_equal(before, CenyM1.bytes, 'prepare ani open nic nezapisali')
  end
end

NxTest.test('CENY-M1b (R15): mat_manual_confirm — ok + status, konflikt s cerstvym snimkom, model guard, schema guard') do
  CenyM1.headless!
  ids = CenyM1b.seed!
  m = CenyM1b::M
  CenyM1b.with_model do |guid, _opened|
    base = { 'kind' => 'sheet', 'id' => ids[:s25], 'token' => 's1', 'section' => 'mat', 'model_guid' => guid,
             'catalog_schema' => m::SCHEMA_CURRENT }
    rev = m.record_rev(m.sheet(ids[:s25]))
    out = CenyM1.call('mat_manual_confirm', base.merge('row_rev' => rev, 'price' => '179,90', 'basis' => 'plate',
                                                       'price_checked_at' => '2099-01-01T00:00:00Z',
                                                       'price_check_method' => 'x'))
    res = CenyM1b.parse(out, 'MD.manualResult')
    NxTest.assert_equal([true, 'ok', 's1'], [res['ok'], res['status'], res['token']])
    NxTest.assert(out.include?('ECHO'), 'katalog sa obnovil')
    day = Time.now.utc
    NxTest.assert_equal("Cena potvrdená k #{day.day}.#{day.month}.#{day.year}: 179,90 € za platňu = 31,04 €/m².", res['msg'])
    NxTest.assert_equal([res['msg'], false], CenyM1.status_of(out))
    NxTest.refute(m.sheet(ids[:s25])['price_checked_at'].start_with?('2099'), 'datum NIKDY od klienta')
    rev = m.record_rev(m.sheet(ids[:s25]))
    out = CenyM1.call('mat_manual_confirm', base.merge('row_rev' => rev, 'price' => '179,90', 'basis' => 'plate'))
    res = CenyM1b.parse(out, 'MD.manualResult')
    NxTest.assert(res['msg'].end_with?('(bez zmeny ceny — len dátum).'), res['msg'])
    before = CenyM1.bytes
    out = CenyM1.call('mat_manual_confirm', base.merge('row_rev' => 'stary', 'price' => '100', 'basis' => 'plate'))
    res = CenyM1b.parse(out, 'MD.manualResult')
    NxTest.assert_equal('conflict', res['status'])
    NxTest.assert_equal(m.record_rev(m.sheet(ids[:s25])), res['row_rev'], 'konflikt nesie cerstvy snimok')
    NxTest.assert(out.any? { |s| s.start_with?('MD.setCatalog(') }, 'konflikt obnovi katalog')
    foreign = CenyM1b.parse(CenyM1.call('mat_manual_confirm', base.merge('row_rev' => rev, 'price' => '1', 'basis' => 'm2',
                                                                         'model_guid' => 'cudzi')), 'MD.manualResult')
    NxTest.assert_equal('stale_model', foreign['status'])
    old = CenyM1b.parse(CenyM1.call('mat_manual_confirm', base.merge('row_rev' => rev, 'price' => '1', 'basis' => 'm2',
                                                                     'catalog_schema' => 11)), 'MD.manualResult')
    NxTest.assert_equal('schema', old['status'], 'stary klient odmietnuty')
    bad = CenyM1b.parse(CenyM1.call('mat_manual_confirm', base.merge('row_rev' => m.record_rev(m.sheet(ids[:s25])),
                                                                     'price' => '-5', 'basis' => 'plate')), 'MD.manualResult')
    NxTest.assert_equal('invalid', bad['status'])
    NxTest.assert_equal([{ 'field' => 'price', 'msg' => 'Vlož nezápornú cenu s DPH; prázdna cena sa nedá potvrdiť.' }], bad['errors'])
    NxTest.assert_equal(before, CenyM1.bytes)
    CenyM1.stub(m, :confirm_manual_price, ->(*_a, **_k) { raise IOError, 'disk' }) do
      err = CenyM1b.parse(CenyM1.call('mat_manual_confirm', base.merge('row_rev' => rev, 'price' => '1', 'basis' => 'm2')),
                          'MD.manualResult')
      NxTest.assert_equal(['error', 's1'], [err['status'], err['token']], 'vynimka vrati odpoved a odomkne modal')
    end
    # ABS a doska bez formatu (m2) — statusy
    out = CenyM1.call('mat_manual_confirm', base.merge('kind' => 'edge', 'id' => ids[:e08], 'row_rev' => m.record_rev(m.edge(ids[:e08])),
                                                       'price' => '0,125', 'basis' => 'bm'))
    NxTest.assert(CenyM1b.parse(out, 'MD.manualResult')['msg'].include?(': 0,125 €/bm.'))
  end
end

NxTest.test('CENY-M1b (R15): tok mimo Demos session — akcie maju predponu mat_, odchod zo sekcie ich nerusi') do
  acts = CenyM1b::D::SECTION_ACTIONS
  %w[mat_manual_prepare mat_manual_open mat_manual_confirm].each { |a| NxTest.assert(acts.include?(a), a) }
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'materials_dialog.rb'), encoding: 'UTF-8')
  body = src[/def handle_manual_confirm.*?\n        end\n/m].to_s
  NxTest.refute(body.include?('@demos_running'), 'confirm nepouziva Demos session')
  NxTest.refute(body.include?('demos_bump_session'))
end

# --- R24: Rozpocet sa nemeni -----------------------------------------------------------

NxTest.test('CENY-M1b (R24): Rozpocet s rucne overenymi materialmi = tie iste riadky, cisla aj XLSX') do
  g = NxNp4Golden
  e = Noxun::Engine
  extra = { 'price_check_method' => 'manual', 'price_checked_at' => '2026-09-20T08:00:00Z',
            'product_url' => 'https://shop.example/p' }
  sheets2 = g::SHEETS.each_with_object({}) do |(k, v), h|
    h[k] = %w[H18 W18 NOF].include?(k) ? v.merge(extra) : v
  end
  snap = lambda do |sheets|
    rows = g.mixed_rows
    p = e::Budget.compute({ rows: rows, edging: [] }, {}, e::SupplierSettings.seed_supplier,
                          sheets: sheets, edges: {}, sheet_estimate: g.estimate(rows),
                          sheet_layout: g.plan(rows), now: g::NOW)
    { 'payload' => p, 'xlsx' => e::BudgetXlsx.sheet(p, project: 'R24', now: g::NOW),
      'cp' => e::CpXlsx.price_sheet(p['cp_preview'], project: 'R24', now: g::NOW) }
  end
  a = g.roundtrip(snap.call(g::SHEETS))
  b = g.roundtrip(snap.call(sheets2))
  NxTest.assert_equal(a['xlsx'], b['xlsx'], 'XLSX rozpoctu')
  NxTest.assert_equal(a['cp'], b['cp'], 'XLSX ponuky')
  strip = lambda do |p|
    Array(p.dig('stale', 'items')).each { |i| i.delete('checked_at') }
    p
  end
  NxTest.assert_equal(strip.call(a['payload']), strip.call(b['payload']),
                      'payload rovnaky (jediny dovoleny rozdiel stale.items[].checked_at)')
end

# --- starsi plugin ---------------------------------------------------------------------

NxTest.test('CENY-M1b: starsi plugin (M1a, SCHEMA_CURRENT 11) katalog s markerom 12 len cita') do
  ids = CenyM1b.seed!
  m = CenyM1b::M
  CenyM1b.checked_sheet!(ids)
  NxTest.assert_equal(12, CenyM1.marker)
  old = m::SCHEMA_CURRENT
  m.send(:remove_const, :SCHEMA_CURRENT)
  m.const_set(:SCHEMA_CURRENT, 11)
  begin
    before = CenyM1.bytes
    NxTest.refute(m.schema_write_allowed?(11), 'klient 11 nad markerom 12 nezapisuje')
    NxTest.refute(m.upsert_sheet(m.sheet(ids[:s25]).merge('code' => 'STARY')), 'zapis odmietnuty')
    NxTest.assert_equal(before, CenyM1.bytes)
  ensure
    m.send(:remove_const, :SCHEMA_CURRENT)
    m.const_set(:SCHEMA_CURRENT, old)
  end
end
