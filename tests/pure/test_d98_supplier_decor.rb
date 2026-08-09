# frozen_string_literal: true
# Testy D-98: "dekor u dodavatela" (supplier_decor) — alias cisla dekoru, pod
# ktorym dodavatel vedie TEN ISTY dekor (Egger kompakt F8001 = kompaktna verzia
# dekoru F800; stranka Demosu uvadza "F8001 ST9", zaznam zije v skupine F800).
#   Materials.normalize_sheet / validate_sheet_attrs / required_schema_for
#     — merge-safe pole, typovy guard ZASTENA (audit F3), marker 9 (audit N6)
#   DemosProductParser.identity_match?  — dekor stranky sa porovnava s aliasom
#   DemosSlugMatcher.score              — slug musi niest OBA tokeny (audit B1)
#   Materials.patch_record              — zmena/vymazanie rusi price_checked_at (B2)
# Duplakovu ocistu (audit F5) overuje test_d49_duplak_auto.rb.
require_relative '../helper' unless defined?(NxTest)

D98M = Noxun::Engine::Materials
D98P = Noxun::Engine::DemosProductParser
D98S = Noxun::Engine::DemosSlugMatcher

# Realny pripad z 9.8.: kompaktna doska Egger F8001 ST9 (dekor skupiny F800).
D98_URL = 'https://www.demos-trade.sk/kd-in-f8001-st9-f800-solid-mramor-kristalovy-sj-bcs-4100-650-12/'

def d98_rec(over = {})
  { 'material_id' => 'F800_ST9_KOMPAKT_12', 'decor' => 'F800', 'structure' => 'ST9',
    'manufacturer' => 'Egger', 'type' => 'KOMPAKT', 'thickness' => 12.0,
    'sheet_size' => [4100.0, 650.0], 'supplier_decor' => 'F8001' }.merge(over)
end

def d98_parsed(decor = 'F8001 ST9')
  { 'ok' => true, 'title' => 'Kompaktná doska F8001 ST9',
    'params' => { 'decor' => decor.split.first, 'structure' => 'ST9',
                  'thickness' => 12.0, 'format' => [4100.0, 650.0] } }
end

# ---------------------------------------------------------------------------
# normalize + validacia + schema
# ---------------------------------------------------------------------------

NxTest.test('d98: normalize_sheet — alias sa nesie merge-safe, prazdny kluc ODSTRANI') do
  rec = D98M.normalize_sheet(d98_rec)
  NxTest.assert_equal('F8001', rec['supplier_decor'])
  trimmed = D98M.normalize_sheet(d98_rec('supplier_decor' => '  F8001  '))
  NxTest.assert_equal('F8001', trimmed['supplier_decor'], 'trim ako code/supplier')
  cleared = D98M.normalize_sheet(d98_rec('supplier_decor' => '   '))
  NxTest.refute(cleared.key?('supplier_decor'), 'prazdna hodnota kluc odstrani')
  none = D98M.normalize_sheet(d98_rec.reject { |k, _| k == 'supplier_decor' })
  NxTest.refute(none.key?('supplier_decor'), 'chybajuce = bez kluca')
end

NxTest.test('d98: alias NIE JE identita variantu (sheet_identity_key sa nemeni)') do
  with = D98M.sheet_identity_key(d98_rec)
  without = D98M.sheet_identity_key(d98_rec.reject { |k, _| k == 'supplier_decor' })
  NxTest.assert_equal(without, with, 'alias do kluca variantu nevstupuje')
end

NxTest.test('d98 (audit F3): ZASTENA alias ODMIETNE — par aj protitah, validacia aj normalize') do
  pair = { 'decor' => 'F094', 'type' => 'ZASTENA', 'thickness' => 9.2,
           'sheet_size' => [4100.0, 640.0], 'back_decor' => 'H1145',
           'supplier_decor' => 'F0941' }
  ok, msg = D98M.validate_sheet_attrs(pair)
  NxTest.refute(ok, 'obojstranna zastena alias nedostane')
  NxTest.assert(msg.to_s.include?('Zástena'), msg.inspect)
  single = { 'decor' => 'F206', 'type' => 'ZASTENA', 'thickness' => 9.2,
             'sheet_size' => [4100.0, 640.0], 'single_sided' => true,
             'supplier_decor' => 'F2061' }
  ok2, msg2 = D98M.validate_sheet_attrs(single)
  NxTest.refute(ok2, 'protitahova zastena alias tiez nedostane')
  NxTest.assert(msg2.to_s.include?('Zástena'), msg2.inspect)
  # normalize je druha poistka — pole neprezije ani okruznou cestou
  NxTest.refute(D98M.normalize_sheet(pair.merge('material_id' => 'Z1')).key?('supplier_decor'))
  NxTest.refute(D98M.normalize_sheet(single.merge('material_id' => 'Z2')).key?('supplier_decor'))
end

NxTest.test('d98: validate_sheet_attrs — alias na beznom type prejde, dlhy odmietne') do
  ok, = D98M.validate_sheet_attrs(d98_rec)
  NxTest.assert(ok)
  ok2, = D98M.validate_sheet_attrs(d98_rec('supplier_decor' => ''))
  NxTest.assert(ok2, 'prazdny alias je platny stav')
  bad, msg = D98M.validate_sheet_attrs(d98_rec('supplier_decor' => 'X' * 200))
  NxTest.refute(bad)
  NxTest.assert(msg.to_s.include?('Dekor u dodávateľa'), msg.inspect)
end

NxTest.test('d98 (audit N6): required_schema_for = 9; SCHEMA_CURRENT bumpnuta s kodom') do
  rec = D98M.normalize_sheet(d98_rec)
  NxTest.assert_equal(D98M::SCHEMA_SUPPLIER_DECOR, D98M.required_schema_for([rec]),
                      'obsah pola dvihne marker na 9')
  bare = D98M.normalize_sheet(d98_rec.reject { |k, _| k == 'supplier_decor' })
  NxTest.assert_equal(0, D98M.required_schema_for([bare]), 'bez pola marker nestupa')
  NxTest.assert_equal(9, D98M::SCHEMA_CURRENT)
end

# ---------------------------------------------------------------------------
# dokaz identity: parser + slug
# ---------------------------------------------------------------------------

NxTest.test('d98: identity_match? — dekor stranky sa porovnava s ALIASOM (F8001 vs skupina F800)') do
  rec = d98_rec
  NxTest.assert(D98P.identity_match?(d98_parsed, rec),
                'kompakt F8001 v skupine F800 uz PRECHADZA (predtym identity_fail navzdy)')
  NxTest.refute(D98P.identity_match?(d98_parsed('F800'), rec),
                'stranka so skupinovym cislom nie je zhoda pre zaznam s aliasom')
  NxTest.refute(D98P.identity_match?(d98_parsed('F9001'), rec), 'cudzi dekor')
  # bez aliasu plati povodne pravidlo (dekor skupiny)
  plain = rec.reject { |k, _| k == 'supplier_decor' }
  NxTest.assert(D98P.identity_match?(d98_parsed('F800'), plain))
  NxTest.refute(D98P.identity_match?(d98_parsed, plain), 'bez aliasu F8001 nesedi')
end

NxTest.test('d98 (audit B1): slug musi niest OBA tokeny — dekor skupiny AJ alias') do
  toks = D98S.record_tokens(d98_rec)
  real = D98S.slug_of(D98_URL)
  NxTest.assert(D98S.score(real, toks), 'realny slug ma f800 aj f8001 -> prejde')
  # cudzi produkt: alias by sam osebe stacil, cislo skupiny v slugu chyba
  foreign = 'kd-in-f8001-st9-f900-iny-dekor-4100-650-12'
  NxTest.assert_equal(nil, D98S.score(foreign, toks), 'bez tokenu skupiny F800 neprejde')
  # produkt skupiny bez aliasu (bezna doska) sa zaznamu s aliasom nepodstrci
  no_alias = 'kd-in-f800-st9-solid-mramor-4100-650-12'
  NxTest.assert_equal(nil, D98S.score(no_alias, toks), 'bez tokenu aliasu neprejde')
  # zaznam BEZ aliasu ostava na povodnom spravani
  plain_toks = D98S.record_tokens(d98_rec.reject { |k, _| k == 'supplier_decor' })
  NxTest.assert(D98S.score(no_alias, plain_toks), 'bez aliasu staci dekor skupiny')
end

NxTest.test('d98: match() cez sitemap — alias zuzuje kandidatov, nerozsiruje ich') do
  urls = [D98_URL, 'https://www.demos-trade.sk/kd-in-f8001-st9-f900-iny-4100-650-12/']
  r = D98S.match(d98_rec, urls)
  NxTest.assert_equal('match', r['status'], r.inspect)
  NxTest.assert_equal(D98_URL, r['url'])
end

# ---------------------------------------------------------------------------
# patch protokol (audit B2) — zmena/vymazanie rusi datum overenia
# ---------------------------------------------------------------------------

def d98_seed_kompakt
  ok, res = D98M.add_decor_batch(
    'batch_schema' => 3, 'decor' => 'F800', 'manufacturer' => 'Egger',
    'decor_name' => 'Mramor kryštálový', 'type' => 'KOMPAKT', 'grain' => 'none',
    'color' => [200, 200, 200],
    'sheet_variants' => [{ 'thickness' => 12.0, 'structure' => 'ST9',
                           'sheet_size' => [4100.0, 650.0] }],
    'edge_variants' => []
  )
  raise "seed F800 zlyhal: #{res.inspect}" unless ok
  res
end

def d98_cleanup(res)
  return unless res
  (res['sheets'] || []).each { |id| D98M.delete_sheet(id) }
  (res['edges'] || []).each { |id| D98M.delete_edge(id) }
end

NxTest.test('d98 (audit B2): patch aliasu ZMAZE price_checked_at, cena a kod ostanu') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  res = d98_seed_kompakt
  begin
    id = res['sheets'][0]
    st, = D98M.patch_record('sheet', id, { 'code' => '514485', 'supplier' => 'Demos' })
    NxTest.assert_equal(:ok, st)
    # datum overenia zapisuje server (apply_demos_batch) — simulujeme ho priamo
    NxTest.assert(D98M.upsert_sheet(D98M.sheet(id).merge('price_per_m2' => 55.0,
                                                         'price_checked_at' => '2026-08-09T10:00:00Z')))
    NxTest.assert_equal('2026-08-09T10:00:00Z', D98M.sheet(id)['price_checked_at'], 'sanity')
    st2, err2 = D98M.patch_record('sheet', id, { 'supplier_decor' => 'F8001' })
    NxTest.assert_equal(:ok, st2, err2.inspect)
    after = D98M.sheet(id)
    NxTest.assert_equal('F8001', after['supplier_decor'])
    NxTest.refute(after.key?('price_checked_at'), 'zmena aliasu rusi datum overenia')
    NxTest.assert_equal('514485', after['code'], 'kod ostava')
    NxTest.assert_close(55.0, after['price_per_m2'], 0.001, 'cena ostava')
  ensure
    d98_cleanup(res)
  end
end

NxTest.test('d98 (audit B2): VYMAZANIE aliasu rusi datum tiez; rovnaka hodnota ho necha') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  res = d98_seed_kompakt
  begin
    id = res['sheets'][0]
    NxTest.assert(D98M.upsert_sheet(D98M.sheet(id).merge('supplier_decor' => 'F8001',
                                                         'price_checked_at' => '2026-08-09T10:00:00Z')))
    # patch TOU ISTOU hodnotou nie je zmena — datum prezije
    st0, = D98M.patch_record('sheet', id, { 'supplier_decor' => ' F8001 ' })
    NxTest.assert_equal(:ok, st0)
    NxTest.assert_equal('2026-08-09T10:00:00Z', D98M.sheet(id)['price_checked_at'],
                        'rovnaky alias datum nerusi')
    st, err = D98M.patch_record('sheet', id, { 'supplier_decor' => '' })
    NxTest.assert_equal(:ok, st, err.inspect)
    after = D98M.sheet(id)
    NxTest.refute(after.key?('supplier_decor'), 'prazdna hodnota alias vymaze')
    NxTest.refute(after.key?('price_checked_at'), 'vymazanie aliasu rusi datum overenia')
  ensure
    d98_cleanup(res)
  end
end

NxTest.test('d98 (audit N6): prvy alias LAZY dvihne marker na 9 a starsi klient uz nezapise') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
  res = d98_seed_kompakt
  begin
    # Fresh seed nesie marker 7 (UNI zaznamy su sucastou seedu) — podstatne je,
    # ze je NIZSI ako 9, takze klient so schemou 8 este pisat smie.
    NxTest.assert_equal(D98M::SCHEMA_UNI, D98M.catalog_schema, 'fresh seed = marker 7 (UNI)')
    NxTest.assert(D98M.schema_write_allowed?(8), 'pred aliasom smie pisat aj klient so schemou 8')
    st, err = D98M.patch_record('sheet', res['sheets'][0], { 'supplier_decor' => 'F8001' })
    NxTest.assert_equal(:ok, st, err.inspect)
    NxTest.assert_equal(D98M::SCHEMA_SUPPLIER_DECOR, D98M.catalog_schema,
                        'prvy zapis s aliasom dvihol marker suboru')
    NxTest.refute(D98M.schema_write_allowed?(8),
                  'starsi klient (schema 8) uz zapisovat nesmie — alias by ticho zahodil')
    NxTest.assert(D98M.schema_write_allowed?(9), 'klient tejto verzie pise dalej')
  ensure
    d98_cleanup(res)
  end
end

NxTest.test('d98: UNI zaznam alias nedostane (nakupne pole)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  st, err = D98M.patch_record('sheet', 'UNI_DOSKA_18', { 'supplier_decor' => 'F8001' })
  NxTest.assert_equal(:invalid, st)
  NxTest.assert(err.to_s.include?('UNI'), err.inspect)
end
