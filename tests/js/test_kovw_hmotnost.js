// Testy KOV-W / D-125 — riadok HMOTNOST v informacnom stlpci Zakladnych.
//   node tests/js/test_kovw_hmotnost.js
//
// Kontrakt, ktory sa tu strazi:
//   1) text riadku sklada CISTA funkcia z payloadu skrinky (panel nic nepocita —
//      sucet robi server `Bom.weight_totals`),
//   2) ODHAD sa prizna: znacka ≈ a tooltip, ktory povie kolko dielcov a akou
//      hustotou sa ratalo (rozhodnutie Michal 8.9.2026 — nikdy ticho),
//   3) skrinka bez vyrobnych dielcov = '—' (radsej pomlcka nez vymyslene cislo),
//   4) cislo je po slovensky (desatinna CIARKA, jedno desatinne miesto),
//   5) riadok ma v HTML vlastne `id` na oboch urovniach (hodnota + tooltip),
//      inak by ho most nemal kam zapisat,
//   6) vo VKLADANI sa riadok vynuluje — nesmie drzat cislo predtym oznacenej
//      skrinky.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

const ROOT = path.join(__dirname, '..', '..');
const UI = path.join(ROOT, 'noxun_engine', 'ui');
const { nxCabWeight, NX_WEIGHT_TITLE } = require(path.join(UI, 'js', 'core.js'));

const PANEL_HTML = fs.readFileSync(path.join(UI, 'panel.html'), 'utf8');
const BRIDGE_SRC = fs.readFileSync(path.join(UI, 'js', 'bridge.js'), 'utf8');
const FORM_SRC = fs.readFileSync(path.join(UI, 'js', 'form.js'), 'utf8');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) PRESNE cislo ---------------------------------------------------------

eq(nxCabWeight({ weight_kg: 12.44, weight_estimated_parts: 0, weight_estimated_density: null }),
   { text: '12,4 kg', title: NX_WEIGHT_TITLE, estimated: false },
   'zname hustoty = presne cislo bez znacky');
eq(nxCabWeight({ weight_kg: 12.45, weight_estimated_parts: 0 }).text, '12,5 kg',
   'zaokruhluje sa na jedno desatinne miesto');
eq(nxCabWeight({ weight_kg: 12, weight_estimated_parts: 0 }).text, '12 kg',
   'cele cislo ostava bez desatinnej casti (vzor mmLabel)');
ok(nxCabWeight({ weight_kg: 12.4, weight_estimated_parts: 0 }).text.indexOf('.') === -1,
   'ziadna desatinna BODKA — panel je po slovensky');

// --- 2) ODHAD sa prizna ------------------------------------------------------

const est = nxCabWeight({ weight_kg: 12.44, weight_estimated_parts: 3, weight_estimated_density: 870 });
eq(est.text, '≈ 12,4 kg', 'odhad nesie znacku ≈');
eq(est.estimated, true, 'volajuci sa vie spytat, ci je to odhad');
ok(est.title.indexOf('3 dielce') !== -1, `tooltip povie POCET dielcov: ${est.title}`);
ok(est.title.indexOf('870') !== -1, `tooltip povie HUSTOTU: ${est.title}`);
ok(est.title.indexOf('ťažšia') !== -1, `tooltip povie, ze sa ratalo tazsie: ${est.title}`);
ok(est.title !== NX_WEIGHT_TITLE, 'odhad ma VLASTNY tooltip, nie vseobecny');

// Slovenske sklonovanie — 1 dielec / 2-4 dielce / 5+ dielcov.
ok(nxCabWeight({ weight_kg: 5, weight_estimated_parts: 1, weight_estimated_density: 870 })
     .title.indexOf('1 dielec ') !== -1, '1 dielec');
ok(nxCabWeight({ weight_kg: 5, weight_estimated_parts: 4, weight_estimated_density: 870 })
     .title.indexOf('4 dielce ') !== -1, '4 dielce');
ok(nxCabWeight({ weight_kg: 5, weight_estimated_parts: 9, weight_estimated_density: 870 })
     .title.indexOf('9 dielcov ') !== -1, '9 dielcov');

// Chybajuca hustota v payloade tooltip NEROZBIJE (len ju nespomenie).
const noDens = nxCabWeight({ weight_kg: 5, weight_estimated_parts: 2 });
eq(noDens.text, '≈ 5 kg', 'odhad ostava odhadom aj bez cisla hustoty');
ok(noDens.title.indexOf('NaN') === -1, 'ziadne NaN v tooltipe');

// --- 3) PRAZDNE stavy = pomlcka ---------------------------------------------

[[null, 'bez skrinky'], [{}, 'payload bez hmotnosti'],
 [{ weight_kg: 0, weight_estimated_parts: 0 }, 'skrinka bez vyrobnych dielcov'],
 [{ weight_kg: 'x' }, 'poskodena hodnota']].forEach(function(c){
  eq(nxCabWeight(c[0]), { text: '—', title: NX_WEIGHT_TITLE, estimated: false }, c[1]);
});

// --- 4) HTML + zapisove cesty ------------------------------------------------

ok(/id="infWeight"[^>]*><span>Hmotnosť<\/span><b id="inf_weight">/.test(PANEL_HTML),
   'riadok ma id na oboch urovniach (tooltip aj hodnota)');
ok(PANEL_HTML.indexOf('Hmotnosť príde s kovaním') === -1,
   'stary placeholder tooltip zmizol (D-125)');
ok(PANEL_HTML.indexOf('id="infWeight" onclick') === -1, 'riadok NIE JE klikatelny');

ok(/nxCabWeight\(c\)/.test(BRIDGE_SRC) && /setOut\('inf_weight'/.test(BRIDGE_SRC),
   'most zapisuje hodnotu z cistej funkcie');
ok(/el\('infWeight'\)/.test(BRIDGE_SRC), 'most nastavuje aj tooltip riadku');
ok(/setOut\('inf_weight', '—'\)/.test(FORM_SRC),
   'vo VKLADANI sa riadok vynuluje — nesmie drzat cislo predtym oznacenej skrinky');

console.log(`OK ${n} kontrol (KOV-W hmotnost)`);
