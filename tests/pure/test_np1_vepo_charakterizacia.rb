# frozen_string_literal: true
# NP-1 (blok 2 · Nárezový plán, audit návrhu F3): CHARAKTERIZAČNÉ testy VEPO
# exportu PRED vytiahnutím spoločnej prípravy riadka (`VepoExport.prepare_row`).
#
# Zamyká PRESNÉ bajty výstupu dnešného `VepoExport.build` — celé CSV každej
# skupiny, celý LOG a pole `errors` v presnom poradí (vrátane textu dôvodu) —
# nad fixtúrou, ktorá pokrýva rizikové miesta extrakcie:
#   * súbežné chyby na jednom riadku (rozhoduje poradie kontrol),
#   * dve neznáme ABS pri orientácii `width` (rozhoduje poradie hrán PO výmene),
#   * zlomkové rozmery (…,5 — zaokrúhlenie od nuly) aj dĺžku 0,4 (VEPO ju dnes
#     vydá ako 0 mm — plán ju vyradí sám, VEPO sa nemení),
#   * duplák (jeden riadok duplákového materiálu),
#   * oba režimy `merge_18_36`,
#   * skrátené názvy a poznámky pre VEPO (čítajú zaokrúhlené rozmery).
# Očakávané hodnoty vznikli spustením `build` PRED extrakciou; extrakcia ich
# nesmie zmeniť ani o bajt. Zmena je dovolená VÝHRADNE samostatným commitom
# s dôvodom (rovnaké pravidlo ako zlatá vzorka v test_vepo_export.rb).
require_relative '../helper' unless defined?(NxTest)

module NxNp1Char
  module_function

  MATS = {
    'K009_PW_DTDL_18' => { 'label' => 'K009 PW DTDL' },
    'K009_PW_DTDL_36' => { 'label' => 'K009 PW DTDL', 'display' => 'K009 PW DTDL 36 (duplák)' },
    'HDF_WHITE_3'     => { 'label' => 'Biela HDF' }
  }.freeze
  EDGES = { 'ABS1' => 1.0, 'ABS2' => 2.0 }.freeze
  EDEC = { 'ABS2' => { 'decor' => 'W1000', 'decor_name' => 'Biela', 'group_id' => 'G2' },
           'ABS1' => { 'decor' => 'K009', 'decor_name' => 'Dub', 'group_id' => 'G1' } }.freeze
  SDEC = { 'K009_PW_DTDL_18' => { 'decor' => 'K009', 'group_id' => 'G1' } }.freeze
  VAL = { 'items' => [{ 'severity' => 'red', 'message_sk' => 'Test RED' },
                      { 'severity' => 'orange', 'message_sk' => 'Test ORANGE' }],
          'counts' => { 'red' => 1, 'orange' => 1 } }.freeze

  def row(over = {})
    { 'names' => ['Bok lavy', 'Bok pravy'], 'length' => 720.0, 'width' => 560.0, 'thickness' => 18.0,
      'quantity' => 2, 'material_id' => 'K009_PW_DTDL_18', 'grain_direction' => 'length',
      'edges' => { 'L1' => 'ABS1', 'L2' => nil, 'W1' => nil, 'W2' => nil },
      'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 2 }] }.merge(over)
  end

  def rows
    [
      row,
      row('names' => ['Polica 1'], 'length' => 720.5, 'width' => 559.5, 'quantity' => 3,
          'edges' => { 'L1' => 'ABS1', 'L2' => 'ABS2', 'W1' => nil, 'W2' => nil }),
      row('names' => ['Polica 2'], 'length' => 0.4, 'width' => 300.49, 'quantity' => 1),
      row('names' => ['Dvierka 1'], 'grain_direction' => 'width', 'length' => 715.0, 'width' => 396.0,
          'edges' => { 'L1' => 'ABS1', 'L2' => 'ABS1', 'W1' => 'ABS2', 'W2' => 'ABS2' }),
      row('names' => ['Pracovna'], 'material_id' => 'K009_PW_DTDL_36', 'thickness' => 36.0,
          'length' => 1200.0, 'width' => 600.0, 'quantity' => 2,
          'material_source' => { 'material_id' => 'K009_PW_DTDL_18', 'multiplier' => 2 }),
      row('names' => ['Chrbat'], 'material_id' => 'HDF_WHITE_3', 'thickness' => 3.0, 'length' => 716.0,
          'width' => 596.0, 'quantity' => 1, 'grain_direction' => 'none',
          'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }),
      # skrátený názov (orez aj bez skrinky) so zlomkovými rozmermi
      row('names' => ['Vystuha predna', 'Vystuha zadna', 'Sokel predny', 'Priecka zvisla'],
          'length' => 400.5, 'width' => 99.5, 'quantity' => 4,
          'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 2 }, { 'owner_id' => 'CAB-002', 'quantity' => 2 }]),
      row('names' => ['Polica 3'], 'length' => 500.0, 'width' => 300.0, 'quantity' => 1,
          'kde' => [{ 'owner_id' => 'CAB-001', 'quantity' => 1 }, { 'owner_id' => 'CAB-002', 'quantity' => 1 },
                    { 'owner_id' => 'CAB-003', 'quantity' => 1 }, { 'owner_id' => 'CAB-004', 'quantity' => 1 },
                    { 'owner_id' => 'CAB-005', 'quantity' => 1 }]),
      # súbežné chyby na jednom riadku — rozhoduje poradie kontrol
      row('names' => ['Zla 1'], 'material_id' => '', 'length' => -5.0, 'quantity' => 0),
      row('names' => ['Zla 2'], 'length' => 0.0, 'quantity' => 0),
      row('names' => ['Zla 3'], 'thickness' => 0.0,
          'edges' => { 'L1' => 'NEZNAMA', 'L2' => nil, 'W1' => nil, 'W2' => nil }),
      row('names' => ['Zla 4'], 'width' => 0.0, 'quantity' => 0),
      row('names' => ['Zla 5'], 'quantity' => 0, 'thickness' => -1.0),
      row('names' => ['Zla 6'], 'thickness' => 0.0),
      # dve neznáme ABS — pri `width` vyhrá tá, ktorá je PO výmene prvá (W1 -> L1)
      row('names' => ['Zla 7'], 'grain_direction' => 'width',
          'edges' => { 'L1' => 'NEZ_L1', 'L2' => nil, 'W1' => 'NEZ_W1', 'W2' => nil }),
      row('names' => ['Zla 8'], 'grain_direction' => 'length',
          'edges' => { 'L1' => 'NEZ_L1', 'L2' => nil, 'W1' => 'NEZ_W1', 'W2' => nil })
    ]
  end

  def build(merge_18_36:)
    Noxun::Engine::VepoExport.build(
      rows, project: 'Kuchyňa Novák', materials: MATS, edge_thicknesses: EDGES, validation: VAL,
            edge_decors: EDEC, sheet_decors: SDEC, version: '9.9.9', generated_at: 'TEST-CAS',
            merge_18_36: merge_18_36
    )
  end

  EXPECTED = {
    true => {
      'groups' => [
        ["kuchyna_novak_biela_hdf_3.csv", [
          "\"Chrbat s1\";\"716\";\"\";\"596\";\"\";\"3\";\"1\";\"Biela HDF\";\"\"",
        ]],
        ["kuchyna_novak_k009_pw_dtdl_18_36.csv", [
          "\"Bok LP s1\";\"720\";\"—\";\"560\";\"\";\"18\";\"2\";\"K009 PW DTDL\";\"\"",
          "\"Polica 1 s1\";\"721\";\"=\";\"560\";\"\";\"18\";\"3\";\"K009 PW DTDL\";\"ABS W1000 Biela\"",
          "\"Polica 2 s1\";\"0\";\"—\";\"300\";\"\";\"18\";\"1\";\"K009 PW DTDL\";\"\"",
          "\"Dv1 s1\";\"396\";\"=\";\"715\";\"=\";\"18\";\"2\";\"K009 PW DTDL\";\"ABS W1000 Biela\"",
          "\"Pracovna s1\";\"1200\";\"—\";\"600\";\"\";\"36\";\"2\";\"K009 PW DTDL\";\"\"",
          "\"Vyst PZ/Sokel\";\"401\";\"—\";\"100\";\"\";\"18\";\"4\";\"K009 PW DTDL\";\"\"",
          "\"Polica 3 s1 s2 s3 +2\";\"500\";\"—\";\"300\";\"\";\"18\";\"1\";\"K009 PW DTDL\";\"\"",
        ]],
      ],
      'errors' => [
        {"name"=>"Zla 1 s1", "reason"=>"chýba materiál", "material_id"=>"", "owners"=>["CAB-001"]},
        {"name"=>"Zla 2 s1", "reason"=>"nekladná dĺžka", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 3 s1", "reason"=>"neznáma ABS NEZNAMA", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 4 s1", "reason"=>"nekladná šírka", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 5 s1", "reason"=>"chybný počet kusov", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 6 s1", "reason"=>"chybná hrúbka 0.0", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 7 s1", "reason"=>"neznáma ABS NEZ_W1", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 8 s1", "reason"=>"neznáma ABS NEZ_L1", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
      ],
      'shortened' => [
        {"full"=>"Vyst PZ/Sokel/Priecka Z", "name"=>"Vyst PZ/Sokel", "reason"=>"cut", "length"=>401, "width"=>100, "thickness"=>18, "quantity"=>4, "owners"=>["CAB-001", "CAB-002"], "filename"=>"kuchyna_novak_k009_pw_dtdl_18_36.csv"},
      ],
      'log' => [
        "Noxun Engine — VEPO export LOG",
        "Projekt: Kuchyňa Novák (kuchyna_novak)",
        "Verzia:  9.9.9",
        "Dátum:   TEST-CAS",
        "------------------------------------------------------------",
        "Skupiny exportu (2):",
        "  - kuchyna_novak_biela_hdf_3.csv (1 riadkov, 1 ks) [HDF_WHITE_3]",
        "  - kuchyna_novak_k009_pw_dtdl_18_36.csv (7 riadkov, 15 ks) [K009_PW_DTDL_18, K009_PW_DTDL_36] — K009 PW DTDL 36 (duplák)",
        "------------------------------------------------------------",
        "Riadky vyradené z CSV (8):",
        "  ! Zla 1 s1 () @ CAB-001: chýba materiál",
        "  ! Zla 2 s1 (K009_PW_DTDL_18) @ CAB-001: nekladná dĺžka",
        "  ! Zla 3 s1 (K009_PW_DTDL_18) @ CAB-001: neznáma ABS NEZNAMA",
        "  ! Zla 4 s1 (K009_PW_DTDL_18) @ CAB-001: nekladná šírka",
        "  ! Zla 5 s1 (K009_PW_DTDL_18) @ CAB-001: chybný počet kusov",
        "  ! Zla 6 s1 (K009_PW_DTDL_18) @ CAB-001: chybná hrúbka 0.0",
        "  ! Zla 7 s1 (K009_PW_DTDL_18) @ CAB-001: neznáma ABS NEZ_W1",
        "  ! Zla 8 s1 (K009_PW_DTDL_18) @ CAB-001: neznáma ABS NEZ_L1",
        "------------------------------------------------------------",
        "Skrátené názvy (1):",
        "  * Vyst PZ/Sokel/Priecka Z -> Vyst PZ/Sokel [kuchyna_novak_k009_pw_dtdl_18_36.csv] — 401×100×18, 4 ks @ CAB-001, CAB-002",
        "------------------------------------------------------------",
        "Poznámky pre VEPO (2 riadkov):",
        "  * Polica 1 s1 [kuchyna_novak_k009_pw_dtdl_18_36.csv]: ABS W1000 Biela",
        "  * Dv1 s1 [kuchyna_novak_k009_pw_dtdl_18_36.csv]: ABS W1000 Biela",
        "------------------------------------------------------------",
        "KONTROLA — 1 kritických (RED), 1 na kontrolu (ORANGE):",
        "  [RED]    Test RED",
        "  [ORANGE] Test ORANGE",
        "  Pozn.: RED je varovanie, export sa neblokuje.",
      ],
      'totals' => [8, 16]
    },
    false => {
      'groups' => [
        ["kuchyna_novak_biela_hdf_3.csv", [
          "\"Chrbat s1\";\"716\";\"\";\"596\";\"\";\"3\";\"1\";\"Biela HDF\";\"\"",
        ]],
        ["kuchyna_novak_k009_pw_dtdl_18.csv", [
          "\"Bok LP s1\";\"720\";\"—\";\"560\";\"\";\"18\";\"2\";\"K009 PW DTDL\";\"\"",
          "\"Polica 1 s1\";\"721\";\"=\";\"560\";\"\";\"18\";\"3\";\"K009 PW DTDL\";\"ABS W1000 Biela\"",
          "\"Polica 2 s1\";\"0\";\"—\";\"300\";\"\";\"18\";\"1\";\"K009 PW DTDL\";\"\"",
          "\"Dv1 s1\";\"396\";\"=\";\"715\";\"=\";\"18\";\"2\";\"K009 PW DTDL\";\"ABS W1000 Biela\"",
          "\"Vyst PZ/Sokel\";\"401\";\"—\";\"100\";\"\";\"18\";\"4\";\"K009 PW DTDL\";\"\"",
          "\"Polica 3 s1 s2 s3 +2\";\"500\";\"—\";\"300\";\"\";\"18\";\"1\";\"K009 PW DTDL\";\"\"",
        ]],
        ["kuchyna_novak_k009_pw_dtdl_36.csv", [
          "\"Pracovna s1\";\"1200\";\"—\";\"600\";\"\";\"36\";\"2\";\"K009 PW DTDL\";\"\"",
        ]],
      ],
      'errors' => [
        {"name"=>"Zla 1 s1", "reason"=>"chýba materiál", "material_id"=>"", "owners"=>["CAB-001"]},
        {"name"=>"Zla 2 s1", "reason"=>"nekladná dĺžka", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 3 s1", "reason"=>"neznáma ABS NEZNAMA", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 4 s1", "reason"=>"nekladná šírka", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 5 s1", "reason"=>"chybný počet kusov", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 6 s1", "reason"=>"chybná hrúbka 0.0", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 7 s1", "reason"=>"neznáma ABS NEZ_W1", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
        {"name"=>"Zla 8 s1", "reason"=>"neznáma ABS NEZ_L1", "material_id"=>"K009_PW_DTDL_18", "owners"=>["CAB-001"]},
      ],
      'shortened' => [
        {"full"=>"Vyst PZ/Sokel/Priecka Z", "name"=>"Vyst PZ/Sokel", "reason"=>"cut", "length"=>401, "width"=>100, "thickness"=>18, "quantity"=>4, "owners"=>["CAB-001", "CAB-002"], "filename"=>"kuchyna_novak_k009_pw_dtdl_18.csv"},
      ],
      'log' => [
        "Noxun Engine — VEPO export LOG",
        "Projekt: Kuchyňa Novák (kuchyna_novak)",
        "Verzia:  9.9.9",
        "Dátum:   TEST-CAS",
        "------------------------------------------------------------",
        "Skupiny exportu (3):",
        "  - kuchyna_novak_biela_hdf_3.csv (1 riadkov, 1 ks) [HDF_WHITE_3]",
        "  - kuchyna_novak_k009_pw_dtdl_18.csv (6 riadkov, 13 ks) [K009_PW_DTDL_18]",
        "  - kuchyna_novak_k009_pw_dtdl_36.csv (1 riadkov, 2 ks) [K009_PW_DTDL_36] — K009 PW DTDL 36 (duplák)",
        "------------------------------------------------------------",
        "Riadky vyradené z CSV (8):",
        "  ! Zla 1 s1 () @ CAB-001: chýba materiál",
        "  ! Zla 2 s1 (K009_PW_DTDL_18) @ CAB-001: nekladná dĺžka",
        "  ! Zla 3 s1 (K009_PW_DTDL_18) @ CAB-001: neznáma ABS NEZNAMA",
        "  ! Zla 4 s1 (K009_PW_DTDL_18) @ CAB-001: nekladná šírka",
        "  ! Zla 5 s1 (K009_PW_DTDL_18) @ CAB-001: chybný počet kusov",
        "  ! Zla 6 s1 (K009_PW_DTDL_18) @ CAB-001: chybná hrúbka 0.0",
        "  ! Zla 7 s1 (K009_PW_DTDL_18) @ CAB-001: neznáma ABS NEZ_W1",
        "  ! Zla 8 s1 (K009_PW_DTDL_18) @ CAB-001: neznáma ABS NEZ_L1",
        "------------------------------------------------------------",
        "Skrátené názvy (1):",
        "  * Vyst PZ/Sokel/Priecka Z -> Vyst PZ/Sokel [kuchyna_novak_k009_pw_dtdl_18.csv] — 401×100×18, 4 ks @ CAB-001, CAB-002",
        "------------------------------------------------------------",
        "Poznámky pre VEPO (2 riadkov):",
        "  * Polica 1 s1 [kuchyna_novak_k009_pw_dtdl_18.csv]: ABS W1000 Biela",
        "  * Dv1 s1 [kuchyna_novak_k009_pw_dtdl_18.csv]: ABS W1000 Biela",
        "------------------------------------------------------------",
        "KONTROLA — 1 kritických (RED), 1 na kontrolu (ORANGE):",
        "  [RED]    Test RED",
        "  [ORANGE] Test ORANGE",
        "  Pozn.: RED je varovanie, export sa neblokuje.",
      ],
      'totals' => [8, 16]
    }
  }.freeze
end

[true, false].each do |merge|
  NxTest.test("NP-1 charakterizacia VEPO (merge_18_36=#{merge}): CSV kazdej skupiny bajtovo zhodne") do
    out = NxNp1Char.build(merge_18_36: merge)
    exp = NxNp1Char::EXPECTED[merge]
    NxTest.assert_equal(exp['groups'].map(&:first), out['groups'].map { |g| g['filename'] }, 'nazvy suborov')
    exp['groups'].each_with_index do |(fname, lines), i|
      want = lines.map { |l| "#{l}\r\n" }.join
      NxTest.assert_equal(want.b, out['groups'][i]['csv'].b, "CSV bajty #{fname}")
    end
    NxTest.assert_equal(exp['totals'], [out['total_rows'], out['total_pieces']], 'sucty riadkov a kusov')
  end

  NxTest.test("NP-1 charakterizacia VEPO (merge_18_36=#{merge}): errors v presnom poradi a s presnym textom") do
    out = NxNp1Char.build(merge_18_36: merge)
    NxTest.assert_equal(NxNp1Char::EXPECTED[merge]['errors'], out['errors'])
    NxTest.assert_equal(NxNp1Char::EXPECTED[merge]['shortened'], out['shortened'])
  end

  NxTest.test("NP-1 charakterizacia VEPO (merge_18_36=#{merge}): cely LOG bajtovo zhodny") do
    out = NxNp1Char.build(merge_18_36: merge)
    want = NxNp1Char::EXPECTED[merge]['log'].map { |l| "#{l}\r\n" }.join
    NxTest.assert_equal(want.b, out['log_text'].b, 'LOG bajty')
  end
end
