// KOV-E1a (9.9.2026) / KOV-E2 — nové tvary člena setu v editore knižnice (hw_sets.js).
//
// PREČO: člen výklopu nesie kód PODĽA TRIEDY (`code_by_param`) alebo počet
// Z PARAMETRA (`quantity_from`). E1a ich vedela iba PRENIESŤ (set bol v editore
// len na čítanie); **E2 ich EDITUJE** — a presne tu je riziko: rozobrať člen na
// polia formulára a zložiť ho späť sa dá tichým spôsobom zle. Set by sa uložil
// bez mechanizmu (prázdny kód) alebo bez počtu tyčí a nikto by si to nevšimol,
// kým by neprišla objednávka bez mechanizmu výklopu (Astra FIX 10).
//
// ČO SA OVERUJE:
//   1) rozpoznanie tvaru v editore (`hwsMemberKind` = štvrtá stratégia `param`)
//   2) BEZSTRATOVÝ round-trip: knižnica -> editor -> payload servera
//   3) EDITOVATEĽNOSŤ: zmena triedy, kódu aj počtu z parametra prejde
//   4) názov parametra = select + „iné (vypíšem)" (`hwsParamSplit`/`hwsParamJoin`)
//   5) `quantity_from` je NEZÁVISLÉ od stratégie kódu — prepnutie kódu ho
//      nezahodí (tyč má pevný kód a premenlivý počet)
//   6) súhrn člena vie nové tvary prečítať (nie prázdny riadok)
//   7) legacy tvary (pevný kód, rad NL, pásma) sa správajú PRESNE ako doteraz
//   8) `lift_system` prejde knižnica -> editor -> payload servera BEZ straty
//      (Codex #332 kolo 2 P1 — bez toho sa legacy výklop nedal doplniť)
//
// MUTÁCIE, ktoré sada chytá:
//   M1 `hwsMembersOf` rozoberie `code_by_param` zle      -> round-trip
//   M2 `hwsBuildMembers` pošle `{code: ''}`              -> round-trip
//   M3 `quantity_from` sa cestou stratí                  -> round-trip
//   M4 súhrn nového člena je prázdny reťazec             -> súhrn
//   M5 prepnutie stratégie kódu zahodí `quantity_from`   -> `hwsMemberSwitch`
//   M6 `lift_system` sa cestou modal -> server stratí    -> round-trip poľa
//   M7 `quantity_from` s výpisom kódov zamlčí počet alebo vypíše `undefined`
//      namiesto kódov                                    -> súhrn 6b
//   M8 „iné (vypíšem)" sa pošle na server ako `__other__` -> hwsParamJoin
//   M9 poradie tried sa preusporiada (abecedne)          -> round-trip poradia
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwsMembersOf, hwsBuildMembers, hwsMemberSummary, hwsBuildSetPayload,
        hwsSetDraftOf, hwsMemberKind, hwsMemberBlank, hwsMemberSwitch,
        hwsParamSplit, hwsParamJoin, HWS_KINDS, HWS_CODE_PARAMS, HWS_QTY_PARAMS,
        HWS_PARAM_OTHER, hwsMemberProblems } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_sets.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(value, msg){
  n++;
  assert.ok(value, msg);
}

// Set výklopu presne v tvare, v akom ho posiela server (SEED_SETS).
const HL_SET = {
  set_id: 'vyklop-hl-klasik',
  name: 'Výklop HL top — klasik (biela)',
  generic_type: 'lift',
  use_type: 'lift',
  opening_mode: 'classic',
  lift_system: 'hl_top',
  manufacturer: 'Blum',
  series: 'AVENTOS',
  members: [
    { per: 'unit', qty: 1, label: 'mechanizmus HL top',
      code_by_param: { param: 'lift_class', codes: { '22L2200': '507351', '22L2500': '507352' } } },
    { per: 'owner', qty: 1, label: 'stabilizačná tyč', code: '507365', quantity_from: 'rod_count' },
    { per: 'unit', qty: 1, label: 'čelný príchyt (pár)', code: '13781' }
  ]
};

// --- 1) rozpoznanie tvaru v editore -------------------------------------------
const edit = hwsMembersOf(HL_SET);
eq(hwsMemberKind(edit[0]), 'param', 'kód podľa triedy je štvrtá stratégia');
eq(hwsMemberKind(edit[1]), 'code', 'pevný kód s počtom z parametra ostáva „pevný kód"');
eq(hwsMemberKind(edit[2]), 'code', 'obyčajný pevný kód');
eq(hwsMemberKind({ is_series: true }), 'nl', 'rad NL');
eq(hwsMemberKind({ is_bands: true }), 'bands', 'pásma parametra');
eq(hwsMemberKind(null), 'code', 'prázdny člen je bezpečný');
ok(HWS_KINDS.some(k => k[0] === 'param'), 'ponuka „Ako sa určí kód?" má štvrtú voľbu');
eq(HWS_KINDS.length, 4, 'a presne štyri — server validuje XOR nad štyrmi tvarmi');

// --- 2) BEZSTRATOVÝ round-trip ------------------------------------------------
eq(edit.length, 3, 'každý člen prežije cestu do editora');
ok(edit[0].is_param && !edit[0].is_series && !edit[0].is_bands,
   'člen „podľa triedy" má vlastný príznak');
eq(edit[0].param, 'lift_class', 'názov parametra sa trafil do ponuky');
eq(edit[0].param_custom, '', 'takže voľný text ostáva prázdny');
eq(edit[0].codes, [{ value: '22L2200', code: '507351' }, { value: '22L2500', code: '507352' }],
   'trieda -> kód sa rozobrala na riadky V PORADÍ SETU');
eq(edit[1].qfrom, 'rod_count', 'počet z parametra sa dostal do editora');
eq(hwsBuildMembers(edit), HL_SET.members, 'späť na server ide PRESNE to, čo prišlo');

// Zmena legacy člena nesmie poškodiť tie ostatné.
const zmena = hwsMembersOf(HL_SET);
zmena[2].code = '13782';
const poslane = hwsBuildMembers(zmena);
eq(poslane[0], HL_SET.members[0], 'mechanizmus ostal nedotknutý');
eq(poslane[1], HL_SET.members[1], 'tyč aj s počtom z parametra ostala nedotknutá');
eq(poslane[2].code, '13782', 'zmena legacy člena prešla');

// Celý payload setu (modal) — členovia sa nesmú stratiť ani cez neho.
const payload = hwsBuildSetPayload({ set_id: HL_SET.set_id, name: HL_SET.name,
                                     use_type: 'lift', opening_mode: 'classic',
                                     manufacturer: 'Blum', series: 'AVENTOS' },
                                   hwsMembersOf(HL_SET));
eq(payload.members, HL_SET.members, 'payload setu nesie členov bezstratovo');

// --- 3) EDITOVATEĽNOSŤ (E2) ---------------------------------------------------
const upravene = hwsMembersOf(HL_SET);
upravene[0].codes[1].code = '507999';                       // iný kód triedy
upravene[0].codes.push({ value: '22L2900', code: '507111' }); // nová trieda
upravene[1].qfrom = 'rod_extension';                        // iný zdroj počtu
const po = hwsBuildMembers(upravene);
eq(po[0].code_by_param.codes,
   { '22L2200': '507351', '22L2500': '507999', '22L2900': '507111' },
   'zmena aj pridanie triedy sa dostanú na server');
eq(po[1].quantity_from, 'rod_extension', 'zmena zdroja počtu prejde');
eq(po[1].code, '507365', 'a pevný kód pri tom neutrpí');

// Prázdny riadok tabuľky sa ZAHODÍ (vzor radu NL) — „+ trieda" bez vyplnenia
// nesmie vyrobiť triedu s prázdnym názvom aj kódom.
const prazdny = hwsMembersOf(HL_SET);
prazdny[0].codes.push({ value: '', code: '' });
eq(hwsBuildMembers(prazdny)[0].code_by_param.codes,
   { '22L2200': '507351', '22L2500': '507352' }, 'úplne prázdny riadok sa nezapíše');
// ČIASTOČNE vyplnený ide na server — nech používateľ dostane konkrétnu vetu
// (validácia je all-or-nothing na SERVERI).
const polovicny = hwsMembersOf(HL_SET);
polovicny[0].codes.push({ value: '22L2900', code: '' });
eq(hwsBuildMembers(polovicny)[0].code_by_param.codes['22L2900'], '',
   'polovičný riadok sa neschová — server o ňom povie');

// Nový prázdny člen „podľa triedy" (tlačidlo „+ Pridať člena" + prepnutie).
const novy = hwsMemberBlank('param', 'lift');
ok(novy.is_param, 'prázdny člen má správny tvar');
eq(novy.param, HWS_CODE_PARAMS[0][0], 'a predvolený parameter z ponuky');
eq(novy.codes, [{ value: '', code: '' }], 'aj jeden prázdny riadok');
eq(hwsBuildMembers([novy])[0].code_by_param, { param: 'lift_class', codes: {} },
   'nevyplnený člen odchádza PRÁZDNY — server ho odmietne vetou, nie ticho');

// --- 4) názov parametra: select + „iné (vypíšem)" -----------------------------
eq(hwsParamSplit('lift_class', HWS_CODE_PARAMS), { sel: 'lift_class', custom: '' },
   'známy parameter sa trafí do selectu');
eq(hwsParamSplit('moj_param', HWS_CODE_PARAMS), { sel: HWS_PARAM_OTHER, custom: 'moj_param' },
   'neznámy sa otvorí ako voľný text (inak by ho editor ticho prepísal)');
eq(hwsParamSplit('', HWS_CODE_PARAMS), { sel: '', custom: '' }, 'chýbajúci = žiadna voľba');
eq(hwsParamJoin('lift_class', ''), 'lift_class', 'select ide na server tak, ako je');
eq(hwsParamJoin(HWS_PARAM_OTHER, ' moj_param '), 'moj_param', 'voľný text sa orezáva');
eq(hwsParamJoin(HWS_PARAM_OTHER, ''), '', '„iné" bez textu = kľúč sa nezapíše');
ok(HWS_QTY_PARAMS.some(p => p[0] === 'rod_count') &&
   HWS_QTY_PARAMS.some(p => p[0] === 'rod_extension'),
   'ponuka počtu pozná oba parametre stabilizačnej tyče');
const vlastny = hwsMembersOf({ members: [{ per: 'unit', qty: 1,
  code_by_param: { param: 'moj_param', codes: { A: '1' } } }] });
eq(vlastny[0].param, HWS_PARAM_OTHER, 'vlastný parameter otvorí voľné pole');
eq(hwsBuildMembers(vlastny)[0].code_by_param.param, 'moj_param',
   'a na server ide vypísaný názov, nikdy sentinel „iné"');

// --- 5) `quantity_from` je NEZÁVISLÉ od stratégie kódu ------------------------
const prepnuty = hwsMemberSwitch(hwsMembersOf(HL_SET)[1], 'param', 'lift');
eq(prepnuty.qfrom, 'rod_count',
   'prepnutie stratégie kódu počet z parametra NEZAHADZUJE (M5)');
eq(prepnuty.label, 'stabilizačná tyč', 'ani popis');
eq(prepnuty.per, 'owner', 'ani „Koľko?"');
const spat = hwsMemberSwitch(hwsMembersOf(HL_SET)[0], 'code', 'lift');
eq(spat.qfrom, '', 'člen bez počtu z parametra si ho ani po prepnutí nevymyslí');

// --- 6) SÚHRN ČLENA -----------------------------------------------------------
eq(hwsMemberSummary(HL_SET.members[0]),
   'podľa lift_class: 22L2200→507351, 22L2500→507352', 'kód podľa triedy sa dá prečítať');
eq(hwsMemberSummary(HL_SET.members[1]),
   'stabilizačná tyč 507365 — počet podľa rod_count na vlastníka',
   'počet z parametra sa dá prečítať');
eq(hwsMemberSummary({ code_by_param: { param: 'arm_class', codes: {} } }),
   'podľa arm_class: —', 'prázdny selektor sa prizná, nie zamlčí');

// --- 6b) KÓD × POČET sa skladajú NEZÁVISLE (Codex #332 kolo 3 P2) ------------
eq(hwsMemberSummary({ per: 'unit', qty: 1, quantity_from: 'rod_count',
                      code_by_param: { param: 'lift_class', codes: { '22K2300': '347810' } } }),
   'podľa lift_class: 22K2300→347810 — počet podľa rod_count',
   'trieda + počet z parametra: obe veci naraz');
eq(hwsMemberSummary({ per: 'owner', qty: 1, quantity_from: 'rod_count',
                      code_by_nl: { 420: '357695', 470: '357696' } }),
   'rad NL: 420→357695, 470→357696 — počet podľa rod_count na vlastníka',
   'rad NL + počet z parametra: kódy sa NEstratia');
eq(hwsMemberSummary({ per: 'unit', qty: 2, quantity_from: 'rod_count',
                      param_bands: { param: 'height',
                                     bands: [{ min: 17, max: 21, code: '82744' }] } }, []),
   'podľa: height: 17–21 → 82744 — počet podľa rod_count ×2',
   'pásma + počet z parametra (aj s násobkom)');
eq(hwsMemberSummary({ per: 'unit', qty: 1, quantity_from: 'rod_extension',
                      label: 'predĺženie', code: '507366' }),
   'predĺženie 507366 — počet podľa rod_extension',
   'pevný kód + počet z parametra ako doteraz');

// --- 7) LEGACY tvary sa nemenia -----------------------------------------------
eq(hwsMemberSummary({ code: '104717', qty: 1, per: 'unit', label: 'záves' }),
   'záves 104717 ×1', 'pevný kód ako doteraz');
eq(hwsMemberSummary({ code_by_nl: { 420: '357695', 470: '357696' } }),
   'rad NL: 420→357695, 470→357696', 'rad NL ako doteraz');
const legacy = { set_id: 'zaves-klasik', generic_type: 'hinge',
                 members: [{ per: 'unit', qty: 1, label: 'záves', code: '104717' },
                           { per: 'unit', qty: 1,
                             code_by_nl: { 420: '357695', 470: '357696' } }] };
eq(hwsBuildMembers(hwsMembersOf(legacy)),
   [{ per: 'unit', qty: 1, label: 'záves', code: '104717' },
    { per: 'unit', qty: 1, code_by_nl: { 420: '357695', 470: '357696' } }],
   'legacy set round-trip bez zmeny');
// (Hranice pásiem chodia editorom ako TEXT — `hwsNum`/`hwsNumIn`; typ dorába
//  server. Kontroluje sa preto obsah, nie typ čísla.)
const bands = { members: [{ per: 'unit', qty: 1,
                            param_bands: { param: 'height',
                                           bands: [{ min: 17, max: 21, code: '82744' }] } }] };
eq(hwsBuildMembers(hwsMembersOf(bands)),
   [{ per: 'unit', qty: 1,
      param_bands: { param: 'height', bands: [{ min: '17', max: '21', code: '82744' }] } }],
   'pásma parametra round-trip bez zmeny obsahu');

// --- 8) `lift_system` v editore (Codex #332 kolo 2 P1) ------------------------
// Legacy set z v0.9.52 je `use_type: 'lift'` BEZ systému. Server ho číta ako
// zaradený (grandfather), ale zápis systém VYŽADUJE — takže modal ho musí
// vedieť poslať, inak sa taký set už nikdy neuloží.
const LEGACY_LIFT = { set_id: 'moj-vyklop', name: 'Môj výklop', generic_type: 'lift',
                      use_type: 'lift', opening_mode: 'classic', manufacturer: 'Blum',
                      members: [{ per: 'unit', qty: 1, code: '347810' }] };
eq(hwsSetDraftOf(HL_SET).lift_system, 'hl_top', 'uložený systém sa dostane do editora');
eq(hwsSetDraftOf(LEGACY_LIFT).lift_system, '', 'legacy set sa otvorí s prázdnym systémom');

const doplneny = hwsBuildSetPayload({ set_id: LEGACY_LIFT.set_id, name: LEGACY_LIFT.name,
                                      use_type: 'lift', opening_mode: 'classic',
                                      lift_system: 'hk_top', manufacturer: 'Blum' },
                                    hwsMembersOf(LEGACY_LIFT));
eq(doplneny.lift_system, 'hk_top', 'doplnený systém odchádza na server');
// Kľúč sa posiela VŽDY (aj prázdny) — `save_set!` merguje, takže vynechaný
// kľúč by v uloženom sete nechal systém po prepnutí typu použitia.
const zasuvka = hwsBuildSetPayload({ set_id: 'z', name: 'Z', use_type: 'drawer',
                                     opening_mode: 'classic', drawer_construction: 'metal',
                                     lift_system: 'hk_top', manufacturer: 'Hettich' }, []);
eq(zasuvka.lift_system, '', 'pri zásuvke odchádza PRÁZDNY systém (vedomé vymazanie)');
ok(Object.prototype.hasOwnProperty.call(zasuvka, 'lift_system'),
   'kľúč sa nikdy nevynechá — server merguje');


// ============ DUPLICITNÁ TRIEDA (Codex #334 kolo 1 P2) ======================
// `code_by_param.codes` je na serveri MAPA: druhý riadok s tou istou triedou
// prepíše prvý UŽ pri skladaní payloadu, takže server duplicitu nikdy neuvidí,
// uloženie prejde a prvé priradenie po refreshi ticho zmizne. Povedať to vie
// LEN klient, kým sú riadky ešte poľom.
const dupClen = { per: 'unit', qty: 1, is_param: true, param: 'lift_class',
                  codes: [{ value: '22K2300', code: '347810' },
                          { value: ' 22K2300 ', code: '347899' }] };
const dupErr = hwsMemberProblems([dupClen]);
eq(dupErr.length, 1, 'duplicitná trieda sa ohlási');
ok(dupErr[0].msg.indexOf('22K2300') >= 0 && dupErr[0].msg.indexOf('dvakrát') >= 0,
   'veta menuje hodnotu: ' + dupErr[0].msg);
eq(dupErr[0].row, 'members:0', 'a pristane pri TOM členovi');
// Skladanie payloadu duplicitu naozaj STRATÍ — preto musí padnúť PRED ním.
eq(Object.keys(hwsBuildMembers([dupClen])[0].code_by_param.codes).length, 1,
   'mapa udrží len jednu hodnotu (to je tá pasca)');
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_param: true, param: 'lift_class',
                            codes: [{ value: '22K2300', code: '347810' },
                                    { value: '22K2500', code: '347811' }] }]), [],
   'rôzne triedy prejdú');
// Prázdne hodnoty duplicitou nie sú (o nedopísanom riadku hovorí server).
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_param: true, param: 'lift_class',
                            codes: [{ value: '', code: '1' }, { value: '', code: '2' }] }]), [],
   'dva prázdne riadky ohlási server, nie táto kontrola');
// TÁ ISTÁ pasca je v rade NL (`code_by_nl` je tiež mapa).
eq(hwsMemberProblems([{ per: 'unit', qty: 1, is_series: true,
                            series: [{ nl: '450', code: 'A' }, { nl: '450', code: 'B' }] }]).length,
   1, 'duplicitná NL v rade tiež');
eq(hwsMemberProblems([]), [], 'prázdny zoznam členov nespadne');
eq(hwsMemberProblems(null), [], 'ani chýbajúci');

console.log(`OK — test_hw_sets_code_by_param.js: ${n} testov preslo`);
