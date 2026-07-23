# frozen_string_literal: true
# Testy D-41 (PR A): sirka ABS pasky + deterministicky picker + dekor ako kluc
# skupiny (trim, near-match, dup variant identity, rename_decor, catalog_revision).
#
# Picker (audit BLOCKER 2): NIKDY uzsia paska nez dielec — najmensia sirka
# >= hrubka+WIDTH_MARGIN -> legacy bez sirky -> nil. Tie-break abs_id.
require_relative '../helper' unless defined?(NxTest)

PMAT = Noxun::Engine::Materials

# Kandidat na test pickera (cisty hash ako v katalogu).
def pw_edge(id, width = nil, thickness = 1.0)
  rec = { 'abs_id' => id, 'decor' => 'PW Test', 'thickness' => thickness, 'price_per_bm' => 0.5 }
  rec['width'] = width if width
  rec
end

# ---------------------------------------------------------------------------
# pick_edge_variant — cista funkcia (bez katalogu)
# ---------------------------------------------------------------------------

NxTest.test('abs-width: picker vyberie najmensiu vyhovujucu sirku') do
  cands = [pw_edge('A43', 43.0), pw_edge('A22', 22.0)]
  NxTest.assert_equal('A22', PMAT.pick_edge_variant(cands, 18.0)['abs_id'])
  NxTest.assert_equal('A43', PMAT.pick_edge_variant(cands, 36.0)['abs_id'])
end

NxTest.test('abs-width: hranica presahu = hrubka + 2 mm') do
  cands = [pw_edge('A22', 22.0)]
  NxTest.assert_equal('A22', PMAT.pick_edge_variant(cands, 20.0)['abs_id'], '20+2=22 vyhovuje')
  NxTest.assert_equal(nil, PMAT.pick_edge_variant(cands, 21.0), '21+2=23 > 22 -> nic (nikdy uzsia)')
end

NxTest.test('abs-width: bez vyhovujucej sirky pada na legacy univerzalnu, nikdy na uzsiu') do
  cands = [pw_edge('A43', 43.0), pw_edge('LEG')]
  NxTest.assert_equal('LEG', PMAT.pick_edge_variant(cands, 42.0)['abs_id'], '42+2=44 > 43 -> legacy')
  NxTest.assert_equal(nil, PMAT.pick_edge_variant([pw_edge('A22', 22.0)], 50.0), 'len uzsia sirkova -> nil')
end

NxTest.test('abs-width: bez hrubky dielca preferuje legacy, inak najsirsiu') do
  NxTest.assert_equal('LEG', PMAT.pick_edge_variant([pw_edge('A22', 22.0), pw_edge('LEG')], nil)['abs_id'])
  NxTest.assert_equal('A43', PMAT.pick_edge_variant([pw_edge('A22', 22.0), pw_edge('A43', 43.0)], nil)['abs_id'])
end

NxTest.test('abs-width: tie-break abs_id pri rovnakej sirke + prazdni kandidati') do
  cands = [pw_edge('B22', 22.0), pw_edge('A22', 22.0)]
  NxTest.assert_equal('A22', PMAT.pick_edge_variant(cands, 18.0)['abs_id'])
  NxTest.assert_equal(nil, PMAT.pick_edge_variant([], 18.0))
end

# ---------------------------------------------------------------------------
# validacia + normalize + ID so sirkou
# ---------------------------------------------------------------------------

NxTest.test('abs-width: validate_edge_attrs — sirka volitelna, rozsah 10-200') do
  NxTest.assert(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0)[0], 'bez sirky OK')
  NxTest.assert(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'width' => '')[0], 'prazdna OK')
  NxTest.assert(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'width' => 22)[0])
  NxTest.assert(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'width' => '43,5')[0], 'ciarkova sirka OK')
  NxTest.refute(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'width' => 5)[0], 'pod rozsahom')
  NxTest.refute(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'width' => 999)[0], 'nad rozsahom')
  NxTest.refute(PMAT.validate_edge_attrs('decor' => 'X', 'thickness' => 1.0, 'width' => 'abc')[0], 'neciselna')
end

NxTest.test('abs-width: normalize_edge — width len ked ma hodnotu, decor trim') do
  rec = PMAT.normalize_edge('abs_id' => 'T1', 'decor' => '  PW Test ', 'thickness' => 1.0, 'width' => '22')
  NxTest.assert_equal(22.0, rec['width'])
  NxTest.assert_equal('PW Test', rec['decor'], 'decor sa trimuje pri zapise (audit BLOCKER 1)')
  NxTest.refute(PMAT.normalize_edge('abs_id' => 'T2', 'decor' => 'X', 'thickness' => 1.0).key?('width'),
                'bez sirky sa kluc neuklada')
  NxTest.refute(PMAT.normalize_edge('abs_id' => 'T3', 'decor' => 'X', 'thickness' => 1.0, 'width' => 'abc').key?('width'),
                'nevalidna sirka sa neuklada (validator ju predtym odmietne)')
end

NxTest.test('abs-width: normalize_sheet trimuje decor aj type') do
  rec = PMAT.normalize_sheet('material_id' => 'M1', 'decor' => ' U702 ST9 ', 'type' => ' DTDL ', 'thickness' => 18)
  NxTest.assert_equal('U702 ST9', rec['decor'])
  NxTest.assert_equal('DTDL', rec['type'])
end

NxTest.test('abs-width: generate_edge_id so sirkou (22X10) aj desatinnou (22P5X10)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal('ABS_SIRKOVY_DEKOR_22X10', PMAT.generate_edge_id('Sirkovy dekor', 1.0, 22))
  NxTest.assert_equal('ABS_SIRKOVY_DEKOR_22P5X20', PMAT.generate_edge_id('Sirkovy dekor', 2.0, '22,5'))
  NxTest.assert_equal('ABS_SIRKOVY_DEKOR_10', PMAT.generate_edge_id('Sirkovy dekor', 1.0), 'bez sirky stary format')
end

# ---------------------------------------------------------------------------
# dekor ako kluc skupiny: near-match, variant identity, rename, revision
# ---------------------------------------------------------------------------

NxTest.test('abs-width: decor_conflict chyta case/whitespace preklepy, presnu zhodu nie') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert_equal(nil, PMAT.decor_conflict('K009 PW'), 'presna zhoda nie je konflikt')
  NxTest.assert_equal('K009 PW', PMAT.decor_conflict('k009 pw'))
  NxTest.assert_equal('K009 PW', PMAT.decor_conflict('K009  PW'))
  # Codex GH #70: aj CHYBAJUCA medzera je preklep tej istej skupiny.
  NxTest.assert_equal('K009 PW', PMAT.decor_conflict('K009PW'))
  NxTest.assert_equal('K009 PW', PMAT.decor_conflict('K 009 PW'))
  NxTest.assert_equal(nil, PMAT.decor_conflict('Uplne novy dekor'))
end

NxTest.test('abs-width: find_sheet_variant / find_edge_variant (identity vratane sirky)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  NxTest.assert(PMAT.find_sheet_variant('K009 PW', 'dtdl', 18), 'typ case-insensitive')
  NxTest.assert_equal(nil, PMAT.find_sheet_variant('K009 PW', 'MDF', 18))
  NxTest.assert(PMAT.find_edge_variant('K009 PW', nil, 1.0), 'seed paska bez sirky')
  NxTest.assert_equal(nil, PMAT.find_edge_variant('K009 PW', 22, 1.0), 'sirkova varianta neexistuje')
  PMAT.upsert_edge('abs_id' => 'ABS_FEVT_22X10', 'decor' => 'FEVT Dekor', 'thickness' => 1.0, 'width' => 22)
  NxTest.assert(PMAT.find_edge_variant('FEVT Dekor', '22,0', 1.0))
  NxTest.assert_equal(nil, PMAT.find_edge_variant('FEVT Dekor', nil, 1.0))
  PMAT.delete_edge('ABS_FEVT_22X10')
end

NxTest.test('abs-width: rename_decor premenuje celu skupinu atomicky (sheets + edges)') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  PMAT.upsert_sheet('material_id' => 'RN_S18', 'decor' => 'Rename Test', 'type' => 'DTDL', 'thickness' => 18.0)
  PMAT.upsert_edge('abs_id' => 'RN_E10', 'decor' => 'Rename Test', 'thickness' => 1.0)
  ok, count = PMAT.rename_decor('Rename Test', 'Rename Done')
  NxTest.assert(ok, 'rename ma prejst')
  NxTest.assert_equal(2, count)
  NxTest.assert_equal('Rename Done', PMAT.sheet('RN_S18')['decor'])
  NxTest.assert_equal('Rename Done', PMAT.edge('RN_E10')['decor'])
  NxTest.assert_equal('RN_E10', PMAT.abs_for_decor('Rename Done', 1.0), 'vazba bezi cez novy nazov')
  PMAT.delete_sheet('RN_S18')
  PMAT.delete_edge('RN_E10')
end

NxTest.test('abs-width: rename_decor guardy — near-match, dup variant pri merge, nenajdeny') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  PMAT.upsert_sheet('material_id' => 'RG_S18', 'decor' => 'Guard Test', 'type' => 'DTDL', 'thickness' => 18.0)
  ok, err = PMAT.rename_decor('Guard Test', 'k009 pw')
  NxTest.refute(ok, 'near-match k inej skupine sa odmietne')
  NxTest.assert(err.include?('K009 PW'), "chyba ma navrhnut presny tvar: #{err}")
  ok2, = PMAT.rename_decor('Guard Test', 'K009 PW')
  NxTest.refute(ok2, 'merge s dup variantom (DTDL 18 existuje v K009 PW) sa odmietne')
  NxTest.refute(PMAT.rename_decor('Neexistujuci Dekor', 'X')[0])
  NxTest.assert_equal('Guard Test', PMAT.sheet('RG_S18')['decor'], 'neuspesny rename nic nezmenil')
  PMAT.delete_sheet('RG_S18')
end

NxTest.test('abs-width: catalog_revision sa meni so zapisom a je stabilna bez neho') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  r1 = PMAT.catalog_revision
  NxTest.assert_equal(r1, PMAT.catalog_revision, 'bez zapisu stabilna')
  PMAT.upsert_edge('abs_id' => 'REV_E10', 'decor' => 'Rev Test', 'thickness' => 1.0)
  r2 = PMAT.catalog_revision
  NxTest.refute(r1 == r2, 'po zapise sa meni')
  PMAT.delete_edge('REV_E10')
end

# ---------------------------------------------------------------------------
# abs_for_decor + resolve_edges s hrubkou dielca (cez katalog)
# ---------------------------------------------------------------------------

NxTest.test('abs-width: abs_for_decor vybera sirku podla hrubky dielca + spatna kompatibilita') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  PMAT.upsert_edge('abs_id' => 'AFD_22X10', 'decor' => 'AFD Dekor', 'thickness' => 1.0, 'width' => 22)
  PMAT.upsert_edge('abs_id' => 'AFD_43X10', 'decor' => 'AFD Dekor', 'thickness' => 1.0, 'width' => 43)
  NxTest.assert_equal('AFD_22X10', PMAT.abs_for_decor('AFD Dekor', 1.0, 18.0))
  NxTest.assert_equal('AFD_43X10', PMAT.abs_for_decor('AFD Dekor', 1.0, 36.0))
  NxTest.assert_equal(nil, PMAT.abs_for_decor('AFD Dekor', 1.0, 60.0), 'nikdy uzsia -> nil')
  NxTest.assert_equal('AFD_43X10', PMAT.abs_for_decor('AFD Dekor', 1.0), 'bez hrubky (legacy volanie) najsirsia')
  NxTest.assert_equal('ABS_K009_10', PMAT.abs_for_decor('K009 PW', 1.0, 18.0), 'seed bez sirky funguje ako doteraz')
  PMAT.delete_edge('AFD_22X10')
  PMAT.delete_edge('AFD_43X10')
end

NxTest.test('abs-width: resolve_edges preberie hrubku dielca do vyberu pasky') do
  NxTest.skip!('katalogove testy bezia len headless') unless NxTest.headless?
  rules = Noxun::Engine::AbsRules
  PMAT.upsert_edge('abs_id' => 'RE_22X10', 'decor' => 'RE Dekor', 'thickness' => 1.0, 'width' => 22)
  PMAT.upsert_edge('abs_id' => 'RE_43X10', 'decor' => 'RE Dekor', 'thickness' => 1.0, 'width' => 43)
  NxTest.assert_equal('RE_22X10', rules.resolve_edges('shelf', 'RE Dekor', 18.0)['L1'])
  NxTest.assert_equal('RE_43X10', rules.resolve_edges('shelf', 'RE Dekor', 36.0)['L1'])
  NxTest.assert_equal(nil, rules.resolve_edges('shelf', 'RE Dekor', 60.0)['L1'], 'ziadna vyhovujuca -> bez ABS')
  PMAT.delete_edge('RE_22X10')
  PMAT.delete_edge('RE_43X10')
end
