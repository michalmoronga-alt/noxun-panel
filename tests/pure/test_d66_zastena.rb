# frozen_string_literal: true
# Testy D-66: zastena cez "Pridat z Demosu" — rub z PARAMETROV stranky (nie zo
# slugu; FIX 7 nedotknuty). Ziva stranka overena 2.8.2026: "Cislo dekoru:
# F094/H1145", "Struktura materialu: ST15/ST10" — fixture je jej kopia.
#   DemosProductParser.split_pair    — prisny lice/rub split (audit F4)
#   DemosFamily.family_from          — hlavicka rodiny = LICE (audit F3)
#   DemosFamily.classify_item        — zastena je sheet kandidat
#   DemosFamily.verify_sheet         — back_decor/back_structure do zapisu
#   DemosProductParser.identity_match? — lookup zasteny (audit B2)
#   Materials.create_group_from_demos — dedup + ID s rubom (audit B1)
require_relative '../helper' unless defined?(NxTest)

D66P = Noxun::Engine::DemosProductParser
D66F = Noxun::Engine::DemosFamily
D66M = Noxun::Engine::Materials

D66_URL = 'https://www.demos-trade.sk/zastena-f094-st15-h1145-st10-4100-640-9-2/'

def d66_fixture
  File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'demos', 'zastena_f094_product.html'),
            encoding: 'UTF-8')
end

def d66_parsed
  @d66_parsed ||= D66P.parse(d66_fixture)
end

NxTest.test('d66 setup: cerstvy SCHEMA 2 seed katalog') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(NxTest.install_fresh_seed_catalog!)
end

NxTest.test('d66: split_pair — prisne dve casti, koncova lomka a 3 casti padaju') do
  NxTest.assert_equal(%w[F094 H1145], D66P.split_pair('F094/H1145'))
  NxTest.assert_equal(['ST15', 'ST10'], D66P.split_pair(' ST15 / ST10 ', require_both: false))
  NxTest.assert_equal(nil, D66P.split_pair('F094'), 'bez lomky nie je par')
  NxTest.assert_equal(nil, D66P.split_pair('F094/H1145/'), 'koncova lomka = 3 tokeny, nie par')
  NxTest.assert_equal(nil, D66P.split_pair('F094/H1145/X'), 'tri casti sa TICHO nezahadzuju')
  NxTest.assert_equal(nil, D66P.split_pair('F094/'), 'prazdny rub pri require_both')
  NxTest.assert_equal(['ST15', ''], D66P.split_pair('ST15/', require_both: false))
  NxTest.assert_equal(nil, D66P.split_pair('/H1145'), 'prazdne lice nikdy')
  NxTest.assert_equal(nil, D66P.split_pair(nil))
end

NxTest.test('d66: parser fixture — zastena parametre presne ako ziva stranka') do
  p = d66_parsed
  NxTest.assert(p['ok'])
  NxTest.assert_equal('F094/H1145', p['params']['decor'])
  NxTest.assert_equal('ST15/ST10', p['params']['structure'])
  NxTest.assert_equal('Egger', p['brand'])
  NxTest.assert_close(9.2, p['params']['thickness'])
  NxTest.assert_equal([4100.0, 640.0], p['params']['format'])
end

NxTest.test('d66: family_from — hlavicka rodiny zo zasteny je LICE (audit F3)') do
  header, items, err = D66F.family_from(d66_parsed, D66_URL)
  NxTest.assert(header, "hlavicka vznikla: #{err.inspect}")
  NxTest.assert_equal('F094', header['decor'], 'identita rodiny = licovy dekor')
  NxTest.assert_equal('ST15', header['structure'])
  NxTest.assert_equal('Egger', header['manufacturer'])
  NxTest.refute(header['decor_name'].include?('/'), "nazov je licovy: #{header['decor_name']}")
  main = items.find { |it| it['url'] == D66_URL }
  NxTest.assert_equal('sheet', main['kind'], 'zastena je doskovy kandidat')
  NxTest.assert_equal('ZASTENA', main['type'])
  NxTest.assert_close(9.2, main['thickness_hint'].to_f)
end

NxTest.test('d66: verify_sheet — rub z parametrov do zapisu; bez paru = fail') do
  parsed = d66_parsed
  params = parsed['params']
  slug = Noxun::Engine::DemosSlugMatcher.slug_of(D66_URL)
  out = D66F.verify_sheet(parsed, params, slug, '307887', D66_URL, { 'kind' => 'sheet', 'type' => 'ZASTENA' })
  NxTest.assert_equal(nil, out['reason'], out.inspect)
  NxTest.assert_equal('ZASTENA', out['type'])
  NxTest.assert_equal('ST15', out['structure'], 'struktura zapisu = lice')
  NxTest.assert_equal('H1145', out['back_decor'])
  NxTest.assert_equal('ST10', out['back_structure'])
  NxTest.assert_equal([4100.0, 640.0], out['sheet_size'])

  # D-72 + GH #119 P2: jeden dekor je legalny LEN pri skutocnom protitah
  # produkte — obojstranna stranka s rozbitym parametrom sa neimportuje ticho.
  single = JSON.parse(JSON.generate(parsed))
  single['params']['decor'] = 'F094'
  bad1 = D66F.verify_sheet(single, single['params'], slug, 'X', D66_URL, { 'kind' => 'sheet' })
  NxTest.assert(bad1['reason'].to_s.include?('nečakaný tvar'),
                "single BEZ protitah markera musi failnut: #{bad1.inspect}")
  bad = JSON.parse(JSON.generate(parsed))
  bad['params']['decor'] = 'F094/H1145/X'
  b = D66F.verify_sheet(bad, bad['params'], slug, 'X', D66_URL, { 'kind' => 'sheet' })
  NxTest.assert(b['reason'].to_s.include?('nečakaný tvar'), "3 casti musia failnut: #{b.inspect}")
end

NxTest.test('d66: identity_match? — zastena lookup cez lice+rub (audit B2)') do
  rec = { 'type' => 'ZASTENA', 'decor' => 'F094', 'structure' => 'ST15',
          'thickness' => 9.2, 'sheet_size' => [4100.0, 640.0],
          'back_decor' => 'H1145', 'back_structure' => 'ST10' }
  NxTest.assert(D66P.identity_match?(d66_parsed, rec), 'plna zhoda lica aj rubu')
  NxTest.refute(D66P.identity_match?(d66_parsed, rec.merge('back_decor' => 'K552')),
                'iny rub nie je zhoda')
  NxTest.refute(D66P.identity_match?(d66_parsed, rec.merge('decor' => 'H1145')),
                'rubovy dekor na mieste lica nie je zhoda')
  legacy = rec.reject { |k, _| k.start_with?('back_') }
  NxTest.assert(D66P.identity_match?(d66_parsed, legacy),
                'legacy zaznam bez rubu porovnava len lice (GH #96 P1 pravidlo)')
  plain = JSON.parse(JSON.generate(d66_parsed))
  plain['params']['decor'] = 'F094'
  NxTest.refute(D66P.identity_match?(plain, rec),
                'zaznam zasteny vs stranka bez paru = necakany tvar, nie zhoda')
end

# ---------------------------------------------------------------------------
# D-72: PROTITAHOVA (jednostranna) zastena — realny produkt (399198, fixture)
# ---------------------------------------------------------------------------

def d72_parsed
  @d72_parsed ||= D66P.parse(
    File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'demos', 'zastena_f206_protitah_product.html'),
              encoding: 'UTF-8')
  )
end

D72_URL = 'https://www.demos-trade.sk/zastena-f206-pm-protitah-sm-4100-640-9-2/'

NxTest.test('d72: zastena_decor_parts — single legalny, par prisny, odpad odmietnuty') do
  NxTest.assert_equal(['F206', nil], D66P.zastena_decor_parts('F206'))
  NxTest.assert_equal(%w[F094 H1145], D66P.zastena_decor_parts('F094/H1145'))
  NxTest.assert_equal(nil, D66P.zastena_decor_parts('F094/'), 'par s prazdnym rubom nie')
  NxTest.assert_equal(nil, D66P.zastena_decor_parts('a/b/c'), '3 casti nie')
  NxTest.assert_equal(nil, D66P.zastena_decor_parts('  '))
end

NxTest.test('d72: protitahova zastena — parser/rodina/verify bez rubu (zivy fixture 399198)') do
  p = d72_parsed
  NxTest.assert(p['ok'])
  NxTest.assert_equal('F206', p['params']['decor'], 'stranka nesie JEDEN dekor')
  header, items, err = D66F.family_from(p, D72_URL)
  NxTest.assert(header, "rodina vznikla: #{err.inspect}")
  NxTest.assert_equal('F206', header['decor'])
  NxTest.assert_equal('PM', header['structure'])
  main = items.find { |it| it['url'] == D72_URL }
  NxTest.assert_equal(%w[sheet ZASTENA], [main['kind'], main['type']], main.inspect)

  slug = Noxun::Engine::DemosSlugMatcher.slug_of(D72_URL)
  out = D66F.verify_sheet(p, p['params'], slug, '399198', D72_URL, { 'kind' => 'sheet', 'type' => 'ZASTENA' })
  NxTest.assert_equal(nil, out['reason'], out.inspect)
  NxTest.refute(out.key?('back_decor'), 'jednostranna zastena bez back poli')
  NxTest.assert_equal(true, out['single_sided'], 'explicitny protitahovy priznak (GH #119 P1)')
  NxTest.assert_equal('PM', out['structure'])
end

NxTest.test('d72: identity_match? — pravidla stran (single/par stranka vs single_sided/legacy/rub zaznam)') do
  legacy = { 'type' => 'ZASTENA', 'decor' => 'F206', 'structure' => 'PM',
             'thickness' => 9.2, 'sheet_size' => [4100.0, 640.0] }
  flagged = legacy.merge('single_sided' => true)
  double = legacy.merge('back_decor' => 'H1145', 'back_structure' => 'ST10')
  # protitahova (single) stranka:
  NxTest.assert(D66P.identity_match?(d72_parsed, flagged), 'single_sided zaznam matchne svoju stranku')
  NxTest.assert(D66P.identity_match?(d72_parsed, legacy), 'legacy bez rubu prechadza licom (GH #96)')
  NxTest.refute(D66P.identity_match?(d72_parsed, double), 'zaznam S rubom vs single stranka = iny produkt')
  # obojstranna (par) stranka F094/H1145 — GH #119 P1: single_sided zaznam sa NIKDY nezhodne
  pair = JSON.parse(JSON.generate(d66_parsed))
  f094_single = { 'type' => 'ZASTENA', 'decor' => 'F094', 'structure' => 'ST15',
                  'thickness' => 9.2, 'sheet_size' => [4100.0, 640.0], 'single_sided' => true }
  NxTest.refute(D66P.identity_match?(pair, f094_single),
                'parova stranka nesmie podvrhnut kod/cenu jednostrannemu zaznamu')
  # single stranka BEZ protitah markera (F094 parsed s orezanym dekorom) = nezhoda
  fake = JSON.parse(JSON.generate(d66_parsed))
  fake['params']['decor'] = 'F094'
  NxTest.refute(D66P.identity_match?(fake, f094_single.merge('decor' => 'F094')),
                'malformovana stranka bez protitah markera nie je dokaz (GH #119 P2)')
end

NxTest.test('d72: create + first-fill — single_sided sa ulozi a rub sa nan uz NIKDY nedoplni (GH #119 P1)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  item = { 'kind' => 'sheet', 'type' => 'ZASTENA', 'thickness' => 9.2,
           'structure' => 'PM', 'single_sided' => true,
           'sheet_size' => [4100.0, 640.0], 'code' => '399198',
           'price' => 36.7, 'demos_url' => D72_URL, 'image_url' => '' }
  created = []
  begin
    status, info = D66M.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F206', 'decor_name' => 'Pietra Grigia',
      'sheet_items' => [item], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status, info.inspect)
    created.concat(info['sheets'])
    rec = D66M.sheet(info['sheets'][0])
    NxTest.assert_equal(true, rec['single_sided'], 'priznak prezil create+normalize')
    NxTest.refute(rec.key?('back_decor'))
    err = D66M.identity_edit_error({ 'back_decor' => 'H1145' }, rec)
    NxTest.assert(err.to_s.include?('Protiťahová'), "first-fill rubu musi byt odmietnuty: #{err.inspect}")
    ok_v, msg_v = D66M.validate_sheet_attrs(rec.merge('back_decor' => 'H1145'))
    NxTest.refute(ok_v, 'validacia odmieta single_sided + rub sucasne')
    NxTest.assert(msg_v.to_s.include?('rubový'), msg_v.inspect)
  ensure
    created.each { |id| D66M.delete_sheet(id) }
  end
end

NxTest.test('d66: create — zastena sa zalozi s rubom, ID nesie R token, dedup funguje (audit B1)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  item = { 'kind' => 'sheet', 'type' => 'ZASTENA', 'thickness' => 9.2,
           'structure' => 'ST15', 'back_decor' => 'H1145', 'back_structure' => 'ST10',
           'sheet_size' => [4100.0, 640.0], 'code' => '307887',
           'price' => 51.4, 'demos_url' => D66_URL, 'image_url' => '' }
  created = []
  begin
    status, info = D66M.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F094', 'decor_name' => 'Mramor Cipollino',
      'sheet_items' => [item], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status, info.inspect)
    created.concat(info['sheets'])
    NxTest.assert_equal(1, info['sheets'].size)
    rec = D66M.sheet(info['sheets'][0])
    NxTest.assert_equal('ZASTENA', rec['type'])
    NxTest.assert_equal('H1145', rec['back_decor'])
    NxTest.assert_equal('ST10', rec['back_structure'])
    NxTest.assert(rec['material_id'].include?('RH1145'), "ID nesie rub token: #{rec['material_id']}")
    NxTest.assert(D66M.catalog_schema >= 6, "demos zapis = demos polia + obrazok (schema >= 6): #{D66M.catalog_schema}")

    # ta ista zastena druhykrat = skipped (ziadny duplicitny variant)
    status2, info2 = D66M.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F094', 'decor_name' => '',
      'sheet_items' => [item], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status2, info2.inspect)
    created.concat(info2['sheets'])
    NxTest.assert_equal(0, info2['sheets'].size, 'existujuci variant sa preskoci')
    NxTest.assert_equal(1, Array(info2['skipped']).size)

    # iny rub = NOVY variant tej istej skupiny (na Demose ma vlastny kod)
    other = item.merge('back_decor' => 'W908', 'back_structure' => 'ST37', 'code' => '307999',
                       'demos_url' => 'https://www.demos-trade.sk/zastena-f094-st15-w908-st37-4100-640-9-2/')
    status3, info3 = D66M.create_group_from_demos(
      'manufacturer' => 'Egger', 'decor' => 'F094', 'decor_name' => '',
      'sheet_items' => [other], 'edge_items' => []
    )
    NxTest.assert_equal(:ok, status3, info3.inspect)
    created.concat(info3['sheets'])
    NxTest.assert_equal(1, info3['sheets'].size, 'iny rub je novy variant')
    NxTest.assert_equal(D66M.sheet(created[0])['group_id'], D66M.sheet(info3['sheets'][0])['group_id'],
                        'rovnaka dekorova skupina')
  ensure
    created.each { |id| D66M.delete_sheet(id) }
  end
end
