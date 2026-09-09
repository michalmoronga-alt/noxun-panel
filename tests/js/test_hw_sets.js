// Testy V0.6 D1b: sety kovania v okne Katalog (hw_sets.js) — dependency-free
// Node. LEN ciste funkcie bez DOM: slug identity noveho setu, filter setov
// podla typu, citatelny suhrn clena, editor stav <-> server payload
// round-trip (rad NL -> mapa; prazdne riadky von — server validuje zvysok).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwsSlug, hwsSetsForType, hwsMemberSummary, hwsBuildSetPayload,
        hwsMembersOf, hwsBuildMembers, hwsNum, hwsParamLabel, hwsBandsSummary, hwsBuildBands,
        hwsSelectorFrom, hwsBuildSelector, hwsProjDraftKeys,
        hwsPinRev, hwsMapRev, hwsMapClassValue, hwsMapClassSelectedId,
        hwsMemberProblems, HWS_STORED_OPT } =
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
// KOV-E1a (Codex #332 kolo 3 P2): „na vlastníka" už BEZ „(dvierka)" — od
// výklopov je vlastníkom aj čelo výklopu (`front:F#/flap`), nie len dvierka.
eq(hwsMemberSummary({ code: '250831', qty: 1, per: 'owner' }),
   '250831 ×1 na vlastníka', 'per owner popis');
eq(hwsMemberSummary({ code_by_nl: { '470': '357696', '420': '357695' }, qty: 1, per: 'unit' }),
   'rad NL: 420→357695, 470→357696', 'rad zoradeny ciselne podla NL');

// --- hwsBuildSetPayload (KOV-B3: draft + cleny) --------------------------------
const built = hwsBuildSetPayload(
  { set_id: 'zaves-p2o', name: ' Záves P2O ', use_type: 'door',
    opening_mode: 'classic', manufacturer: 'Hettich', series: 'Sensys', active: true },
  [
    { is_series: false, per: 'unit', qty: '2', code: ' 245723 ', label: 'záves P2O' },
    { is_series: false, per: 'owner', qty: 1, code: '250831', label: '' },
    { is_series: true, per: 'unit', qty: 1,
      series: [{ nl: ' 420 ', code: ' 357695 ' }, { nl: '', code: 'x' }, { nl: '470', code: '' }] }
  ]
);
eq(built.set_id, 'zaves-p2o', 'identita sa nesie');
eq(built.name, 'Záves P2O', 'nazov trim');
eq(built.members[0], { per: 'unit', qty: 2, label: 'záves P2O', code: '245723' },
   'clen: qty na cislo, kod trim, label len ked je');
eq(built.members[1], { per: 'owner', qty: 1, code: '250831' }, 'per owner bez labelu');
eq(built.members[2], { per: 'unit', qty: 1, code_by_nl: { '420': '357695' } },
   'rad: len kompletne riadky (NL aj kod), trim');

// --- hwsMembersOf (round-trip s buildom) --------------------------------------
const libSet = {
  set_id: 'vysuv-atira-biela-h70', name: 'Atira biela H70 (rad podľa NL)',
  generic_type: 'slide',
  members: [{ per: 'unit', qty: 1, label: 'K-sada',
              code_by_nl: { '470': '357696', '420': '357695' } }]
};
const edit = hwsMembersOf(libSet);
eq(edit[0].is_series, true, 'rad sa rozpozna');
eq(edit[0].series, [{ nl: '420', code: '357695' }, { nl: '470', code: '357696' }],
   'riadky radu zoradene podla NL');
const round = hwsBuildSetPayload({ set_id: libSet.set_id, name: libSet.name }, edit);
eq(round.members[0].code_by_nl, { '420': '357695', '470': '357696' },
   'cleny -> payload round-trip bez straty');
eq(round.set_id, libSet.set_id, 'identita drzi');

const plain = hwsMembersOf({ set_id: 'k', name: 'K', generic_type: 'hinge',
                             members: [{ code: '1', per: 'owner', qty: 3 }] });
// KOV-E2: kazdy clen editora nesie aj POCET Z PARAMETRA (`quantity_from`) —
// je NEZAVISLY od strategie kodu, takze pole ma aj plochy clen (prazdne =
// pevny pocet). Na server sa prazdna hodnota NEZAPISUJE (viz round-trip nizsie).
eq(plain[0], { per: 'owner', qty: 3, label: '', qfrom: '', qfrom_custom: '',
               is_series: false, code: '1' },
   'plochy clen do stavu editora');
eq(hwsBuildMembers(plain), [{ per: 'owner', qty: 3, code: '1' }],
   'a spat na server bez prazdneho `quantity_from`');

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

// --- KOV-G1a: sentinel `none` v KODOVOM pasme ---------------------------------
// Vyplnene pasmo s hodnotou `none` znamena „v tomto pasme clen VEDOME
// nevznika" (platnicka AXILO pod 55 mm). V suhrne sa pise po ludsky — surove
// „none" by vyzeralo ako preklep alebo ako kod, ktory sa objedna.
eq(hwsMemberSummary({ per: 'unit', qty: 1, label: 'platnička',
                      param_bands: { param: 'height',
                                     bands: [{ min: 17.0, max: 20.0, code: 'none' },
                                             { min: 55.0, max: 220.0, code: '9079' }] } }, PARAMS),
   'podľa výšky sokla: 17–20 → bez kódu · 55–220 → 9079', 'sentinel v pasme je „bez kódu"');
eq(hwsBandsSummary([{ min: 17.0, max: 20.0, code: ' NONE ' }], 'code'),
   '17–20 → bez kódu', 'zhoda je bez ohladu na velkost pismen a medzery');
// V SELECTORE mapovania je „none" legitimne MENO SETU — tam sa neprekladá,
// inak by riadok tvrdil „bez kódu" o sete, ktory sa naozaj objedna.
eq(hwsBandsSummary([{ min: 0.0, max: 100.0, set_id: 'none' }], 'set_id'),
   '0–100 → none', 'selector setov sentinel NEMA');
// Editor pasmo prijme a posle ho na server nezmenene (kanonizuje az server).
eq(hwsBuildBands([{ min: '17', max: '20', code: 'none' }], 'code'),
   [{ min: '17', max: '20', code: 'none' }], 'pasmo `none` sa da zadat a odide na server');
// Prazdny kod dalej PADA na serveri — sentinel nie je „prazdna bunka".
eq(hwsBuildBands([{ min: '17', max: '20', code: '' }], 'code'),
   [{ min: '17', max: '20', code: '' }], 'prazdna hodnota ostava prazdna (chybu hlasi SERVER)');

// --- KOV-G1a (Codex #337 N1): VSETKY kody clena su `none` ---------------------
// Sentinel znamena „TU ziadny kod nepatri". Ked ho ma clen VSADE, nikdy nic
// neobjedna — server takeho clena odmieta a editor to musi povedat SKOR
// (a menovat clena, o ktoreho ide).
const vsetkyNone = hwsMemberProblems([{ per: 'unit', qty: 1, is_bands: true, param: 'height',
                                        bands: [{ min: '17', max: '20', code: 'none' },
                                                { min: '55', max: '220', code: ' NONE ' }] }]);
eq(vsetkyNone.length, 1, 'clen so samymi `none` pasmami sa ohlasi');
eq(vsetkyNone[0].row, 'members:0', 'a pristane pri TOM clenovi');
eq(vsetkyNone[0].msg.indexOf('všetky kódy sú „none“') >= 0, true,
   'veta povie, co je zle: ' + vsetkyNone[0].msg);
// Zmiesany clen (aspon jeden kod) je PLATNY — to je tvar seed setu nôh.
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_bands: true, param: 'height',
                        bands: [{ min: '17', max: '20', code: 'none' },
                                { min: '55', max: '220', code: '9079' }] }]), [],
   'platnicka AXILO: jedno pasmo `none`, druhe s kodom');
// TA ISTA uvaha v rade podla dlzky (`code_by_nl`).
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_series: true,
                        series: [{ nl: '350', code: 'none' }, { nl: '420', code: 'none' }] }]).length,
   1, 'cely rad `none` tiez');
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_series: true,
                        series: [{ nl: '350', code: 'none' }, { nl: '420', code: '357695' }] }]), [],
   'rad s jednou vedome prazdnou dlzkou prejde');
// Nedopisane riadky sa NEPOCITAJU — o tych hovori server.
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_bands: true, param: 'height',
                        bands: [{ min: '', max: '', code: '' }] }]), [],
   'prazdny riadok nie je „same none"');
eq(hwsMemberProblems([{ per: 'unit', qty: 1, code: 'none' }]), [],
   'pevny kod `none` odmieta SERVER (v editore je to jedno pole, nie tabulka)');

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
const legEdit = { members: hwsMembersOf(legSet) };
eq(legEdit.members[0].is_bands, true, 'pasma sa rozpoznaju');
eq(legEdit.members[0].param, 'height', 'parameter sa nesie');
eq(legEdit.members[0].bands, [{ min: '17', max: '21', code: '82744' },
                              { min: '140', max: '160', code: '367823' }],
   'pasma do editora bez „.0" chvostov');
const legPayload = hwsBuildSetPayload({ set_id: legSet.set_id, name: legSet.name },
                                      legEdit.members);
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

// --- 1d/R-08 (review #258 P1): draft editora pasiem si PRIPNE reviziu -------
// Rozpisany draft plny push ZAMERNE prezije. Keby sa pri Ulozit poslala
// CERSTVA revizia, serverovy guard by presiel nad stavom, ktory pouzivatel
// nikdy nevidel — a mapovanie druhej instancie by ticho zmizlo.
const draft = hwsPinRev({ param: 'height', rows: [{ min: '', max: '', set_id: '' }] }, 'rev-A');
eq(draft.rev, 'rev-A', 'draft si drzi reviziu z chvile otvorenia');
eq(hwsMapRev(draft.rev, 'rev-B'), 'rev-A', 'push omladil kniznicu, ale posiela sa PRIPNUTA revizia');
eq(hwsMapRev(undefined, 'rev-B'), 'rev-B', 'bez draftu (priamy vyber zo selectu) plati aktualna revizia');
eq(hwsMapRev(null, 'rev-B'), 'rev-B', 'chybajuca pripnuta hodnota = aktualna');
eq(hwsMapRev('', 'rev-B'), '', 'PRIPNUTA prazdna sa NEDOPLNA cerstvou (bola by to ta ista slepota)');
eq(hwsMapRev(undefined, undefined), '', 'ziadna revizia = prazdny retazec (server odmietne)');
// Pripnuta revizia NESMIE presiaknut do payloadu mapovania (je to klientsky
// stav draftu, nie hodnota mapovania).
eq(Object.keys(hwsBuildSelector(hwsPinRev({ param: 'height', rows: [{ min: '', max: '900', set_id: 'a' }] }, 'rev-A'))).sort(),
   ['bands', 'param'],
   'server dostava CISTY selector — `rev` v nom nie je');
eq(hwsPinRev(null, 'rev-A'), null, 'null draft je bezpecny');


// --- KOV-F1: SENTINEL "vedome bez setu" v triednom mapovani -------------------
// Volba "bez setu" sa uklada ako VYHRADENA hodnota, nie zmazanim kluca. Pri
// zavesoch je rozdiel vecny: prazdny kluc znamena "padni nizsie" (legacy
// `hinge`), teda presny OPAK toho, co si pouzivatel vybral.
// Codex #329: `none_value` je TOKEN volby v selecte, `none_send` je HODNOTA,
// ktoru JS posle spat — sentinel je Hash a panel ho nikdy neskláda sam.
const HROW = { key: 'class:hinge|tipon', none_value: 'none', none_send: { none: true },
               options: [{ id: 'set:zaves-p2o', set_id: 'zaves-p2o' },
                         { id: 'sel:x', selector: { param: 'height', bands: [] } }] };
eq(hwsMapClassValue(HROW, 'none'), { none: true }, 'sentinel ide na server ako HODNOTA zo servera');
eq(hwsMapClassValue(HROW, 'set:zaves-p2o'), 'zaves-p2o', 'pevny set = set_id');
eq(hwsMapClassValue(HROW, 'sel:x'), { param: 'height', bands: [] }, 'rodina = selektor');
eq(hwsMapClassValue(HROW, ''), '', 'prazdne ID ostava zrusenim mapovania');
eq(hwsMapClassValue(HROW, 'neznamy'), null, 'nezname ID sa NEODOSIELA');
// Token bez hodnoty (starsi/orezany payload) NEPOSLE nic — radsej ziadny zapis
// nez retazec "none", ktory by na serveri bol `set_id`.
eq(hwsMapClassValue({ key: 'class:hinge|tipon', none_value: 'none', options: [] }, 'none'), null,
   'token bez `none_send` sa NEODOSIELA');
// Riadok BEZ `none_value` (starsi payload) sa sprava presne ako doteraz.
eq(hwsMapClassValue({ key: 'class:slide|classic|metal', options: [] }, 'none'), null,
   'bez `none_value` je sentinel len nezname ID — ziadny tichy zapis');

// --- Codex #329: "nenastavene" vs. "vedome bez setu" --------------------------
// Projekt BEZ triedneho kluca (`current` null, `stored` false) NIE JE "vedome
// bez setu": resolver pri chybajucom kluci pada na legacy `hinge`, takze zavesy
// v nakupe SU. Select preto ma DVE volby a vybrana je prava z nich.
eq(hwsMapClassSelectedId({ none_value: 'none', current: null, stored: false }), '',
   'chybajuci kluc = "nenastavene", NIE sentinel');
eq(hwsMapClassSelectedId({ none_value: 'none', current: 'none', stored: false }), 'none',
   'ulozeny sentinel = volba "vedome bez setu"');
eq(hwsMapClassSelectedId({ none_value: 'none', current: 'set:zaves-p2o', stored: false }),
   'set:zaves-p2o', 'ulozeny set = jeho volba');
eq(hwsMapClassSelectedId({ none_value: 'none', current: null, stored: true }), HWS_STORED_OPT,
   'hodnota mimo ponuky = "ulozeny vyber" (F10)');
eq(hwsMapClassSelectedId(null), '', 'chybajuci riadok je bezpecny');

console.log(`OK — test_hw_sets.js: ${n} testov preslo`);
