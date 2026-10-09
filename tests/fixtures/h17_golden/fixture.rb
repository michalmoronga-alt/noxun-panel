# frozen_string_literal: true
# H17 / R0.2 — FIXTURA ZAKAZKY pre golden T0 spolocnej pripravy exportov.
#
# Zakazka (2 skrinky, 10 zaznamov dielcov, 1 samostatna doska) nesie presne to,
# co package H17 §6 R0.2 vyzaduje: dosku 18 S CENOU aj doskou 18 BEZ CENY,
# DUPLAK 36 s vazbou na 18 (VEPO 18 + 36), hranu ABS s INYM dekorom nez doska
# (D-112), nazov dielca nad 20 znakov (orez D-121b) a expanziu kovania
# s nacenenou, nenacenenou a nemapovanou polozkou a zdrojom `per_owner`.
#
# Data su ZMRAZENE: fixtura ani golden sa po 1. commite H17a NEMENIA (poistka
# package §2 — zmena = STOP). Vsetko su ciste data bez volania pluginu, okrem
# `real_hardware` (skutocna stavba skrinky cez Construction — vstup prípadu so
# skutocnou expanziou nad seedom).
module NxH17Fixture
  EDGE_NONE = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }.freeze

  # Katalog dosiek (`sheets_map`). K009 je ZAMERNE bez ceny (rozpocet: riadok
  # „chýba cena" -> potvrdenie poctom).
  SHEETS = {
    'EG_H1180_18' => { 'material_id' => 'EG_H1180_18', 'type' => 'DTDL', 'thickness' => 18.0,
                       'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1180', 'structure' => 'ST37',
                       'manufacturer' => 'Egger', 'group_id' => 'grp-h1180', 'grain' => 'length',
                       'color' => [139, 101, 66], 'price_per_m2' => 36.5 },
    'EG_H1180_36' => { 'material_id' => 'EG_H1180_36', 'type' => 'DTDL', 'thickness' => 36.0,
                       'sheet_size' => [2800.0, 2070.0], 'decor' => 'H1180', 'structure' => 'ST37',
                       'manufacturer' => 'Egger', 'group_id' => 'grp-h1180', 'grain' => 'length',
                       'color' => [139, 101, 66], 'price_per_m2' => 73.0 },
    'KR_K009_18' => { 'material_id' => 'KR_K009_18', 'type' => 'DTDL', 'thickness' => 18.0,
                      'sheet_size' => [2800.0, 2070.0], 'decor' => 'K009', 'structure' => 'PW',
                      'manufacturer' => 'Kronospan', 'group_id' => 'grp-k009', 'grain' => 'length',
                      'color' => [198, 168, 122], 'price_per_m2' => nil },
    'HDF_W_3' => { 'material_id' => 'HDF_W_3', 'type' => 'HDF', 'thickness' => 3.0,
                   'sheet_size' => [2800.0, 2070.0], 'decor' => 'Biela', 'manufacturer' => 'Kronospan',
                   'group_id' => 'grp-hdf', 'grain' => 'none', 'color' => [238, 236, 230], 'price_per_m2' => 3.2 }
  }.freeze

  # Katalog ABS (`edges_map`). ABS_K009 na doske H1180 = INY dekor (D-112).
  EDGES = {
    'ABS_H1180_20' => { 'abs_id' => 'ABS_H1180_20', 'decor' => 'H1180', 'thickness' => 2.0,
                        'group_id' => 'grp-h1180', 'price_per_bm' => 0.95 },
    'ABS_H1180_10' => { 'abs_id' => 'ABS_H1180_10', 'decor' => 'H1180', 'thickness' => 1.0,
                        'group_id' => 'grp-h1180', 'price_per_bm' => 0.55 },
    'ABS_K009_10' => { 'abs_id' => 'ABS_K009_10', 'decor' => 'K009', 'decor_name' => 'Pinia',
                       'thickness' => 1.0, 'group_id' => 'grp-k009', 'price_per_bm' => 0.6 }
  }.freeze

  # VEPO mapy (`vepo_materials`, `vepo_edge_*`, `vepo_sheet_decors`) — tvar
  # presne ako ich sklada ProductionCore z katalogu.
  VEPO_MATERIALS = {
    'EG_H1180_18' => { 'label' => 'H1180 ST37 DTDL' },
    'EG_H1180_36' => { 'label' => 'H1180 ST37 DTDL' },
    'KR_K009_18' => { 'label' => 'K009 PW DTDL' },
    'HDF_W_3' => { 'label' => 'Biela HDF' }
  }.freeze
  VEPO_EDGE_THICKNESSES = { 'ABS_H1180_20' => 2.0, 'ABS_H1180_10' => 1.0, 'ABS_K009_10' => 1.0 }.freeze
  VEPO_EDGE_DECORS = {
    'ABS_H1180_20' => { 'decor' => 'H1180', 'decor_name' => '', 'group_id' => 'grp-h1180' },
    'ABS_H1180_10' => { 'decor' => 'H1180', 'decor_name' => '', 'group_id' => 'grp-h1180' },
    'ABS_K009_10' => { 'decor' => 'K009', 'decor_name' => 'Pinia', 'group_id' => 'grp-k009' }
  }.freeze
  VEPO_SHEET_DECORS = {
    'EG_H1180_18' => { 'decor' => 'H1180', 'group_id' => 'grp-h1180' },
    'EG_H1180_36' => { 'decor' => 'H1180', 'group_id' => 'grp-h1180' },
    'KR_K009_18' => { 'decor' => 'K009', 'group_id' => 'grp-k009' },
    'HDF_W_3' => { 'decor' => 'Biela', 'group_id' => 'grp-hdf' }
  }.freeze

  DUPLAK = { 'material_id' => 'EG_H1180_18', 'multiplier' => 2 }.freeze

  # [nazov, rola, dlzka, sirka, hrubka, material, vlastnik, hrany, vazba duplaku]
  # BEZ REMIZ (CI Linux, PR #467): dva rozne riadky kusovnika nesmu mat rovnaky
  # material a rozmer — `Bom` ich triedi nestabilnym `sort_by` a poradie remizy
  # je na Windows a Linuxe ine. Preto CAB-002 bok s ABS K009 ma 721 (nie 720)
  # a polica s dlhym nazvom 561 (nie 562). Strazi `NxH17.sort_ties`.
  PARTS = [
    ['Bok lavy', 'side_left', 720.0, 560.0, 18.0, 'EG_H1180_18', 'CAB-001',
     { 'L1' => 'ABS_H1180_20' }, nil],
    ['Bok pravy', 'side_right', 720.0, 560.0, 18.0, 'EG_H1180_18', 'CAB-001',
     { 'L1' => 'ABS_H1180_20' }, nil],
    ['Dno', 'bottom', 564.0, 560.0, 18.0, 'EG_H1180_18', 'CAB-001', { 'L1' => 'ABS_H1180_10' }, nil],
    ['Polica 1', 'shelf', 562.0, 530.0, 18.0, 'KR_K009_18', 'CAB-001',
     { 'L1' => 'ABS_H1180_10' }, nil],
    ['Chrbat', 'back', 716.0, 596.0, 3.0, 'HDF_W_3', 'CAB-001', {}, nil],
    ['Bok lavy', 'side_left', 720.0, 560.0, 18.0, 'EG_H1180_18', 'CAB-002',
     { 'L1' => 'ABS_H1180_20' }, nil],
    ['Bok pravy', 'side_right', 721.0, 560.0, 18.0, 'EG_H1180_18', 'CAB-002',
     { 'L1' => 'ABS_K009_10' }, nil],
    ['Pracovna doska duplak', 'top', 1200.0, 600.0, 36.0, 'EG_H1180_36', 'CAB-002',
     { 'L1' => 'ABS_H1180_20', 'L2' => 'ABS_H1180_20' }, DUPLAK],
    ['Polica s dlhym nazvom pre orez', 'shelf', 561.0, 530.0, 18.0, 'KR_K009_18', 'CAB-002',
     { 'L1' => 'ABS_K009_10' }, nil],
    ['Chrbat', 'back', 716.0, 596.0, 3.0, 'HDF_W_3', 'CAB-002', {}, nil]
  ].freeze

  def self.record(row, idx)
    name, role, len, wid, th, mat, owner, edges, ms = row
    rec = { 'name' => name, 'part_key' => "cabinet/#{role}:#{idx}", 'owner_id' => owner, 'pid' => 500 + idx,
            'role' => role, 'length' => len, 'width' => wid, 'thickness' => th, 'quantity' => 1,
            'material_id' => mat, 'grain_direction' => 'length', 'edges' => EDGE_NONE.merge(edges) }
    rec['material_source'] = ms.dup if ms
    rec
  end

  # Samostatna doska (owner BRD-) — VEPO ju nazve podla volneho textu.
  BOARD = { 'name' => 'Policka nad dvere', 'part_key' => 'board/panel', 'owner_id' => 'BRD-001', 'pid' => 590,
            'role' => 'board', 'length' => 800.0, 'width' => 300.0, 'thickness' => 18.0, 'quantity' => 2,
            'material_id' => 'EG_H1180_18', 'grain_direction' => 'length',
            'edges' => { 'L1' => 'ABS_H1180_10', 'L2' => nil, 'W1' => nil, 'W2' => nil } }.freeze

  def self.records
    PARTS.each_with_index.map { |row, i| record(row, i) } + [Marshal.load(Marshal.dump(BOARD))]
  end

  # Kovanie zo zberu (vstup brany kovania a duplicit, NIE nakupu — nakup ide
  # z expanzie). Prazdne = ziadna receptova ani vyklopova polozka.
  def self.identities
    [{ 'kind' => 'cabinet', 'id' => 'CAB-001' }, { 'kind' => 'cabinet', 'id' => 'CAB-002' },
     { 'kind' => 'board', 'id' => 'BRD-001' }]
  end

  # Tvar `fresh_collect` (`Bom.collect`) — vsetky kluce, ktore exporty citaju.
  def self.collected(records: self.records, hardware: [], identities: self.identities)
    { records: records, hardware: hardware, hardware_manual: [], hardware_overrides: [], cabinet_sets: {},
      cabinet_set_conflicts: {}, placements: [], warnings: [], identities: identities,
      hardware_issues: [], cut_issues: [], newer_configs: [] }
  end

  # Expanzia kovania (`hardware_expansion`): nacenena polozka (2 zdroje, jeden
  # `per_owner`), NENACENENA polozka a NEMAPOVANA polozka.
  def self.expansion
    { 'rows' => [
        { 'code' => 'BLUM-71B3550', 'quantity' => 4, 'manual_quantity' => 0, 'missing' => false,
          'name_sk' => 'Záves Clip Top 110°', 'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => 3.42,
          'manual_note' => nil, 'subtotal_eur_vat' => 13.68,
          'sources' => [
            { 'cabinet_id' => 'CAB-001', 'owner_part_key' => 'front:F1/wing:left', 'generic_type' => 'hinge',
              'rule_id' => 'zavesy-podla-vysky', 'set_id' => 'zaves-klasik', 'quantity' => 2 },
            { 'cabinet_id' => 'CAB-002', 'owner_part_key' => 'front:F1/wing:single', 'generic_type' => 'hinge',
              'rule_id' => 'zavesy-podla-vysky', 'set_id' => 'zaves-klasik', 'quantity' => 2 }
          ] },
        { 'code' => 'BLUM-TIPON', 'quantity' => 1, 'manual_quantity' => 0, 'missing' => false,
          'name_sk' => 'TipOn krátky', 'category' => 'ZAVESY', 'unit' => 'ks', 'price_eur_vat' => nil,
          'manual_note' => nil, 'subtotal_eur_vat' => nil,
          'sources' => [
            { 'cabinet_id' => 'CAB-001', 'owner_part_key' => 'front:F1/wing:left', 'generic_type' => 'hinge',
              'rule_id' => 'zavesy-podla-vysky', 'set_id' => 'zaves-tipon', 'quantity' => 1, 'per_owner' => true }
          ] }
      ],
      'unmapped' => [
        { 'cabinet_id' => 'CAB-002', 'owner_part_key' => nil, 'generic_type' => 'leg', 'rule_id' => 'nohy-fixne',
          'quantity' => 4, 'set_id' => nil, 'reason' => 'no_set', 'reason_sk' => 'bez setu',
          'nominal_length' => nil, 'params_label' => nil }
      ],
      'summary' => { 'rows' => 2, 'quantity' => 5, 'total_eur_vat' => 13.68, 'unknown_prices' => 1, 'unmapped' => 1 },
      'state_status' => 'missing' }
  end

  # Skutocna stavba skrinky (dvojkridlove dvierka) — kovanie zo zberu pre prípad
  # so SKUTOCNOU expanziou nad seedom (`hardware_expansion` sa vtedy nestubuje).
  REAL_CABINET = { 'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0,
                   'thickness' => 18.0, 'floor_height' => 100.0,
                   'fronts' => { 'items' => [{ 'id' => 'F1', 'type' => 'door', 'mode' => 'auto', 'height' => nil,
                                               'locked' => false, 'wings' => '2' }] } }.freeze
  REAL_MATERIALS = {
    'channels' => { 'body' => { 'thickness' => 18.0, 'density' => 680.0, 'uni' => false },
                    'front' => { 'thickness' => 18.0, 'density' => 750.0, 'uni' => false },
                    'back' => { 'thickness' => 3.0, 'density' => 870.0, 'uni' => false },
                    'drawer' => { 'thickness' => 16.0, 'density' => 680.0, 'uni' => false } },
    'parts' => {}
  }.freeze

  def self.real_hardware
    e = Noxun::Engine
    rules = e::HardwareRules.normalize_rules(e::HardwareRules::SEED_RULES)
    plan = e::Construction.build_plan(e::CabinetBuilder.normalize(Marshal.load(Marshal.dump(REAL_CABINET))),
                                      'CAB-001', hardware_rules: rules, materials: REAL_MATERIALS)
    Array(plan[:hardware]).map { |h| JSON.parse(JSON.generate(h)) }
  end
end
