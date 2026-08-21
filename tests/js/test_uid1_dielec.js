// Testy UI-D1: DIELEC — ciste funkcie karty dielca (part_card.js), bez DOM.
// Overuje sa: skladanie informacnych riadkov „Zakladnych" (vystup nikdy nie je
// pole), rotacie hranovych ikon odvodene zo strany 2D nahladu a texty aj stav
// tlacidla modalu „Použiť na podobné…" (vratane hranicnych poctov).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// `nxPartBasicRows` pouziva globalne `fmtmm` z core.js (rovnaky vzor ako
// hwNlHtml v test_d93) — test si ho podstrci v tej istej podobe.
global.fmtmm = function (v) { return (v == null || v === '') ? '?' : Math.round(parseFloat(v)); };

const { nxPartBasicRows, nxEdgeRotOf, nxSimilarCountText, nxSimilarBtnState } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'part_card.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- 1) „Zakladne" su VYSTUP: informacne riadky, nikdy polia ----------------
// K1 (D-108): „Smer dekoru" sa z informacneho stlpca PRESTAHOVAL do segmentu
// (je to vstup) — vpravo ostala len Hrúbka. Stavy segmentu ma vlastnu sadu
// tests/js/test_k1_smer_dekoru.js.
const PC = { length: 720.6, width: 560, thickness: 18, grain_direction: 'length' };
const rows = nxPartBasicRows(PC);
eq(rows.left.length, 2, 'vlavo dva riadky');
eq(rows.right.length, 1, 'vpravo uz len hrubka');
eq(rows.left.map(r => r.label), ['Dĺžka', 'Šírka'], 'vlavo rozmery plochy');
eq(rows.right.map(r => r.label), ['Hrúbka'], 'vpravo hrubka');
eq(rows.left[0].value, 721, 'rozmer je cele cislo (rozmer je cislo, nie veta)');
eq(rows.right[0].unit, 'mm', 'hrubka ma jednotku');
// Kazdy udaj, ktory pouzivatel nemoze zmenit tu, musi povedat KDE sa meni.
eq(typeof rows.right[0].title === 'string' && rows.right[0].title.length > 0, true,
   'hrubka vysvetli, ze ju urcuje material');
eq(rows.right.some(r => !!r.click), false,
   'hrubka nikam nevedie — urcuje ju material KORPUSU a ten sa v rezime dielca neotvori');

const EMPTY = nxPartBasicRows({});
eq(EMPTY.left[0].value, '?', 'chybajuci rozmer sa prizna otaznikom, nevymysla sa nula');
eq(nxPartBasicRows(null).left.length, 2, 'bez payloadu sa nepada — kostra ostava');

// --- 2) rotacia hranovej ikony sa berie zo STRANY 2D nahladu ----------------
// Mapa musi sediet s AbsRules.edge_sides: lezaci dielec ma L1='bottom'
// (predna hrana je v nahlade dole), celo ma L1='left'. Ikona tak ukazuje
// PRESNE tu hranu, ktoru nahlad nad zoznamom farebne kresli.
eq(nxEdgeRotOf('top'), 0, 'horna hrana = 0°');
eq(nxEdgeRotOf('right'), 90, 'prava hrana = 90°');
eq(nxEdgeRotOf('bottom'), 180, 'dolna hrana = 180°');
eq(nxEdgeRotOf('left'), 270, 'lava hrana = 270°');
eq(nxEdgeRotOf('nezname'), 0, 'neznama strana nerotuje (radsej nic nez nahodny uhol)');
eq(nxEdgeRotOf(undefined), 0, 'chybajuca mapa nerotuje');
// Styri hrany = styri RôZNE uhly (inak by dve hrany vyzerali rovnako).
const LYING = ['bottom', 'top', 'left', 'right'].map(nxEdgeRotOf);
eq(new Set(LYING).size, 4, 'lezaci dielec: styri odlisne uhly');

// --- 3) modal „Použiť na podobné…" — texty a stav tlacidla ------------------
eq(nxSimilarCountText(null), 'Počítam podobné dielce…', 'kym pocet nie je, NEUKAZE sa nula');
eq(nxSimilarCountText(undefined), 'Počítam podobné dielce…', 'to iste pre undefined');
eq(nxSimilarCountText(0),
   'Žiadny podobný dielec — rovnakú rolu a materiál nemá v tomto rozsahu nikto iný.',
   'nula povie DOVOD, nie len cislo');
eq(nxSimilarCountText(1), 'Zmení sa 1 podobný dielec.', 'jednotne cislo');
eq(nxSimilarCountText(2), 'Zmení sa 2 podobné dielce.', 'dva az styri');
eq(nxSimilarCountText(4), 'Zmení sa 4 podobné dielce.', 'styri');
eq(nxSimilarCountText(5), 'Zmení sa 5 podobných dielcov.', 'pat a viac');
eq(nxSimilarCountText(12), 'Zmení sa 12 podobných dielcov.', 'dvojciferne');

eq(nxSimilarBtnState(null).enabled, false, 'kym sa pocita, tlacidlo nejde');
eq(nxSimilarBtnState(0).enabled, false, 'nula = nie je co zapisat');
eq(nxSimilarBtnState(1).enabled, true, 'jeden dielec uz stoji za zapis');
eq(nxSimilarBtnState(6).enabled, true, 'viac dielcov tiez');
// Neaktivne tlacidlo musi VZDY povedat preco (vzor D-78) — nikdy ticho mŕtve.
eq(nxSimilarBtnState(null).title.length > 0, true, 'pocitanie ma vysvetlenie');
eq(nxSimilarBtnState(0).title.indexOf('celý projekt') >= 0, true,
   'nula ponukne dalsi krok (skus siri rozsah), nie len konstatovanie');
eq(nxSimilarBtnState(3).title.indexOf('Späť') >= 0, true,
   'aktivne tlacidlo vopred povie, ze je to JEDEN krok Späť');

console.log(`OK test_uid1_dielec.js — ${n} kontrol`);
