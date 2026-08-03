// Testy V0.6 D1b: sety kovania v okne Katalog (hw_sets.js) — dependency-free
// Node. LEN ciste funkcie bez DOM: slug identity noveho setu, filter setov
// podla typu, citatelny suhrn clena, editor stav <-> server payload
// round-trip (rad NL -> mapa; prazdne riadky von — server validuje zvysok).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwsSlug, hwsSetsForType, hwsMemberSummary, hwsBuildSetPayload,
        hwsEditStateFrom, hwsNum, hwsParamLabel, hwsBandsSummary, hwsBuildBands,
        hwsSelectorFrom, hwsBuildSelector, hwsProjDraftKeys } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_sets.js'));

// Slovnik parametrov posiela server (HardwareSets::PARAM_OPTIONS).
const PARAMS = [
  { key: 'height', label: 'výška sokla', by: 'podľa výšky sokla' },
  { key: 'front_height', label: 'výška čela', by: 'podľa výšky čela' }
];

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- hwsSlug ------------------------------------------------------------------
eq(hwsSlug('Záves KLASIK (Sensys 110°)'), 'zaves-klasik-sensys-110', 'diakritika von, medzery/zatvorky -> pomlcky');
eq(hwsSlug('  '), 'set', 'prazdny nazov = fallback');
eq(hwsSlug('Atira biela H70'), 'atira-biela-h70', 'bezne meno');

// --- hwsSetsForType -----------------------------------------------------------
const SETS = [
  { set_id: 'a', generic_type: 'hinge' },
  { set_id: 'b', generic_type: 'leg' },
  { set_id: 'c', generic_type: 'hinge' }
];
eq(hwsSetsForType(SETS, 'hinge').map(s => s.set_id), ['a', 'c'], 'filter typu, poradie kniznice');
eq(hwsSetsForType(SETS, 'slide'), [], 'typ bez setov');
eq(hwsSetsForType(null, 'hinge'), [], 'null vstup bezpecny');

// --- hwsMemberSummary ---------------------------------------------------------
eq(hwsMemberSummary({ code: '104717', qty: 1, per: 'unit', label: 'záves' }),
   'záves 104717 ×1', 'clen s labelom');
eq(hwsMemberSummary({ code: '250831', qty: 1, per: 'owner' }),
   '250831 ×1 na vlastníka (dvierka)', 'per owner popis');
eq(hwsMemberSummary({ code_by_nl: { '470': '357696', '420': '357695' }, qty: 1, per: 'unit' }),
   'rad NL: 420→357695, 470→357696', 'rad zoradeny ciselne podla NL');

// --- hwsBuildSetPayload -------------------------------------------------------
const built = hwsBuildSetPayload({
  set_id: 'zaves-p2o', name: ' Záves P2O ', generic_type: 'hinge',
  members: [
    { is_series: false, per: 'unit', qty: '2', code: ' 245723 ', label: 'záves P2O' },
    { is_series: false, per: 'owner', qty: 1, code: '250831', label: '' },
    { is_series: true, per: 'unit', qty: 1,
      series: [{ nl: ' 420 ', code: ' 357695 ' }, { nl: '', code: 'x' }, { nl: '470', code: '' }] }
  ]
});
eq(built.set_id, 'zaves-p2o', 'identita sa nesie');
eq(built.name, 'Záves P2O', 'nazov trim');
eq(built.members[0], { per: 'unit', qty: 2, label: 'záves P2O', code: '245723' },
   'clen: qty na cislo, kod trim, label len ked je');
eq(built.members[1], { per: 'owner', qty: 1, code: '250831' }, 'per owner bez labelu');
eq(built.members[2], { per: 'unit', qty: 1, code_by_nl: { '420': '357695' } },
   'rad: len kompletne riadky (NL aj kod), trim');

// --- hwsEditStateFrom (round-trip s buildom) -----------------------------------
const libSet = {
  set_id: 'vysuv-atira-biela-h70', name: 'Atira biela H70 (rad podľa NL)',
  generic_type: 'slide',
  members: [{ per: 'unit', qty: 1, label: 'K-sada',
              code_by_nl: { '470': '357696', '420': '357695' } }]
};
const edit = hwsEditStateFrom(libSet);
eq(edit.existing, true, 'edit stav existujuceho setu');
eq(edit.members[0].is_series, true, 'rad sa rozpozna');
eq(edit.members[0].series, [{ nl: '420', code: '357695' }, { nl: '470', code: '357696' }],
   'riadky radu zoradene podla NL');
const round = hwsBuildSetPayload(edit);
eq(round.members[0].code_by_nl, { '420': '357695', '470': '357696' },
   'edit -> payload round-trip bez straty');
eq(round.set_id, libSet.set_id, 'identita drzi');

const plain = hwsEditStateFrom({ set_id: 'k', name: 'K', generic_type: 'hinge',
                                 members: [{ code: '1', per: 'owner', qty: 3 }] });
eq(plain.members[0], { is_series: false, per: 'owner', qty: 3, label: '', code: '1' },
   'plochy clen do edit stavu');

// ============ H1b: pasma clena setu + vyber setu podla parametra ============

// --- hwsNum (zrkadlo Ruby fmt_mm) ---------------------------------------------
eq(hwsNum(17), '17', 'cele cislo bez desatin');
eq(hwsNum(17.0), '17', 'Float bez zvysku = cele');
eq(hwsNum(17.5), '17,5', 'SK desatinna ciarka pre zobrazenie');
eq(hwsNum(''), '', 'prazdna hodnota ostava prazdna');
// GH #132 P2: hranica pasma ide cez tuto funkciu DO EDITORA — zaokruhlenie by
// otvorenim a ulozenim ticho posunulo hranicu (120,25 -> 120,3).
eq(hwsNum(120.25), '120,25', 'presnost sa NEstraca');
eq(hwsNum('0,5'), '0,5', 'vstup s ciarkou sa neznormalizuje na 0');

// --- hwsParamLabel ------------------------------------------------------------
eq(hwsParamLabel('height', PARAMS), 'podľa výšky sokla', '2. pad zo servera');
eq(hwsParamLabel('front_height', PARAMS, 'label'), 'výška čela', '1. pad pre select');
eq(hwsParamLabel('nieco', PARAMS), 'podľa: nieco', 'neznamy parameter = surovy kluc');

// --- hwsMemberSummary s pasmami -----------------------------------------------
eq(hwsMemberSummary({ per: 'unit', qty: 1, label: 'noha',
                      param_bands: { param: 'height',
                                     bands: [{ min: 17.0, max: 21.0, code: '82744' },
                                             { min: 140.0, max: 160.0, code: '367823' }] } }, PARAMS),
   'podľa výšky sokla: 17–21 → 82744 · 140–160 → 367823', 'citatelny zapis pasiem clena');
eq(hwsMemberSummary({ param_bands: { param: 'height', bands: [] } }, PARAMS),
   'podľa výšky sokla: —', 'clen bez pasiem');

// --- hwsBuildBands ------------------------------------------------------------
eq(hwsBuildBands([{ min: ' 17 ', max: '21', code: ' 82744 ' },
                  { min: '', max: '', code: '' },
                  { min: '140', max: '', code: '' }], 'code'),
   [{ min: '17', max: '21', code: '82744' }, { min: '140', max: '', code: '' }],
   'prazdny riadok von, ciastocny ostava (chybu hlasi SERVER)');
eq(hwsBuildBands([{ min: '17,5', max: '21,5', code: 'A' }], 'code'),
   [{ min: '17.5', max: '21.5', code: 'A' }], 'SK ciarka -> bodka pre Ruby Float');
eq(hwsBuildBands(null, 'code'), [], 'null vstup bezpecny');

// --- pasma clena: editor stav <-> payload round-trip --------------------------
const legSet = {
  set_id: 'nohy-podla-sokla', name: 'Nohy podľa výšky sokla', generic_type: 'leg',
  members: [{ per: 'unit', qty: 1, label: 'noha',
              param_bands: { param: 'height',
                             bands: [{ min: 17.0, max: 21.0, code: '82744' },
                                     { min: 140.0, max: 160.0, code: '367823' }] } }]
};
const legEdit = hwsEditStateFrom(legSet);
eq(legEdit.members[0].is_bands, true, 'pasma sa rozpoznaju');
eq(legEdit.members[0].param, 'height', 'parameter sa nesie');
eq(legEdit.members[0].bands, [{ min: '17', max: '21', code: '82744' },
                              { min: '140', max: '160', code: '367823' }],
   'pasma do editora bez „.0" chvostov');
const legPayload = hwsBuildSetPayload(legEdit);
eq(legPayload.members[0], { per: 'unit', qty: 1, label: 'noha',
                            param_bands: { param: 'height',
                                           bands: [{ min: '17', max: '21', code: '82744' },
                                                   { min: '140', max: '160', code: '367823' }] } },
   'round-trip pasiem bez straty (a bez code/code_by_nl navyse)');

// --- selector mapovania -------------------------------------------------------
const sel = hwsSelectorFrom({ param: 'front_height',
                              bands: [{ min: 0.0, max: 120.0, set_id: 'bocnica-h70' },
                                      { min: 120.5, max: 400.0, set_id: 'bocnica-h144' }] });
eq(sel.param, 'front_height', 'parameter vyberu');
eq(sel.rows, [{ min: '0', max: '120', set_id: 'bocnica-h70' },
              { min: '120,5', max: '400', set_id: 'bocnica-h144' }], 'riadky editora vyberu');
eq(hwsBuildSelector(sel), { param: 'front_height',
                            bands: [{ min: '0', max: '120', set_id: 'bocnica-h70' },
                                    { min: '120.5', max: '400', set_id: 'bocnica-h144' }] },
   'editor -> hodnota mapovania (ciarka -> bodka)');
eq(hwsSelectorFrom('bocnica-h70'), null, 'pevny set NIE JE vyber podla parametra');
eq(hwsSelectorFrom(null), null, 'prazdne mapovanie');
eq(hwsBandsSummary([{ min: 0, max: 120, set_id: 'a' }], 'set_id', { a: 'Atira H70' }),
   '0–120 → Atira H70', 'suhrn vyberu pouzije NAZOV setu');
eq(hwsBandsSummary([{ min: 0, max: 120, set_id: 'zmazany' }], 'set_id', {}),
   '0–120 → zmazany', 'set mimo ponuky sa ukaze aspon identitou');
// hranica s dvoma desatinami prezije round-trip editorom bez posunu
const presne = hwsSelectorFrom({ param: 'front_height',
                                 bands: [{ min: 120.25, max: 400.0, set_id: 'a' }] });
eq(presne.rows[0].min, '120,25', 'hranica v editore drzi presnost');
eq(hwsBuildSelector(presne).bands[0].min, '120.25', 'a vracia sa serveru nezmenena');

// --- GH #132 P1: rozpracovane PROJEKTOVE pasma su viazane na model ----------
eq(hwsProjDraftKeys(['hws-map-proj|slide', 'hws-map-global|leg', 'hws-map-proj|leg']),
   ['hws-map-proj|slide', 'hws-map-proj|leg'],
   'prepnutie modelu zahodi len projektove drafty, globalne (kniznicne) ostanu');
eq(hwsProjDraftKeys([]), [], 'ziadne drafty');

console.log(`OK — test_hw_sets.js: ${n} testov preslo`);
