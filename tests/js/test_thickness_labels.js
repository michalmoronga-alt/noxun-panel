// Testy D-45: hrubkove filtre a labely v core.js (mmLabel / bodyThicknessNote /
// frontMatch / thMatch) — dependency-free Node (node tests/js/test_thickness_labels.js).
// Kontext: katalogovy material 18,6 mm sa nedal pouzit — korpusovy select ho
// disabloval a cela boli natvrdo 18/19. Po D-45 su inohrubkove dosky VYBERATELNE
// (hrubku korpusu prevezme material, autorita je server) a cela beru katalogovu
// hrubku v rozsahu dosky. Tieto funkcie su len UX zrkadlo Ruby pravidiel.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mmLabel, bodyThicknessNote, frontMatch, rangeMatch, thMatch, TH_RANGE } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- mmLabel: desatinna CIARKA, cele cisla bez desatin (zrkadlo Materials.fmt_mm) ---
eq(mmLabel(18), '18', 'cele cislo bez desatin');
eq(mmLabel(18.0), '18', '18.0 = 18');
eq(mmLabel(18.6), '18,6', 'desatiny s CIARKOU');
eq(mmLabel('18.6'), '18,6', 'string z payloadu');
eq(mmLabel(0.5), '0,5', 'polovica milimetra');
eq(mmLabel(50), '50', 'horna hranica rozsahu');
eq(mmLabel('abc'), '', 'necislo = prazdny label (ziadne NaN v UI)');
eq(mmLabel(null), '', 'null = prazdny label');

// --- TH_RANGE = zrkadlo Ruby CabinetBuilder::THICKNESS_RANGE ---
eq(TH_RANGE, [6, 50], 'rozsah hrubky korpusu/cela');

// --- bodyThicknessNote: co sa stane po vybere dosky KORPUSU ---
eq(bodyThicknessNote(18, 18), '', 'rovnaka hrubka = ziadna poznamka');
eq(bodyThicknessNote(18.02, 18), '', 'tolerancia 0,05 mm = ziadna poznamka');
eq(bodyThicknessNote(18.6, 18), ' · (prevezme hrúbku 18,6)', 'Halifax 18,6 nad 18 mm korpusom');
eq(bodyThicknessNote(18, 18.6), ' · (prevezme hrúbku 18)', 'aj opacny smer (18,6 -> 18)');
eq(bodyThicknessNote(36, 18), ' · (prevezme hrúbku 36)', 'hruba doska je legitimna volba');
eq(bodyThicknessNote(3, 18), ' · (mimo rozsahu 6–50 mm)', 'HDF 3 korpus neunesie — poznamka varuje');
eq(bodyThicknessNote(60, 18), ' · (mimo rozsahu 6–50 mm)', 'nad rozsahom');
eq(bodyThicknessNote(18.6, NaN), '', 'neznama aktualna hrubka = ziadna poznamka');
eq(bodyThicknessNote('abc', 18), '', 'necislo = ziadna poznamka');

// --- frontMatch: cela uz NIE su natvrdo 18/19 (to bola pricina blokovaneho 18,6) ---
const fm = frontMatch();
eq(fm({ thickness: 18 }), true, 'klasicke 18 mm celo');
eq(fm({ thickness: 19 }), true, 'klasicke 19 mm celo');
eq(fm({ thickness: 18.6 }), true, 'D-45: 18,6 mm celo je vyberatelne');
eq(fm({ thickness: 36 }), true, 'hrube celo v rozsahu');
eq(fm({ thickness: 6 }), true, 'dolna hranica vratane');
eq(fm({ thickness: 50 }), true, 'horna hranica vratane');
eq(fm({ thickness: 3 }), false, 'HDF 3 ako celo nie');
eq(fm({ thickness: 60 }), false, 'nad rozsahom');
eq(fm({ thickness: 'abc' }), false, 'necislo neprejde');

// --- rangeMatch: filter korpusoveho selectu — disabled je uz LEN to, co server
//     odmietne (hrubka mimo rozsahu dosky), nie ina hrubka ---
const rm = rangeMatch();
eq(rm({ thickness: 18.6 }), true, 'D-45: 18,6 mm doska je vyberatelna ako korpus');
eq(rm({ thickness: 3 }), false, 'HDF 3 korpus neunesie — ostava disabled');

// --- thMatch: presna hrubka (chrbat + dielce korpusu) ostava bez zmeny ---
const tm = thMatch(18.6);
eq(tm({ thickness: 18.6 }), true, 'presna zhoda');
eq(tm({ thickness: 18 }), false, 'ina hrubka nesedi');
eq(thMatch('')({ thickness: 3 }), true, 'prazdny ciel = nefiltruj (radsej vsetko nez nic)');

console.log(JSON.stringify({ passed: n, failed: 0 }));
