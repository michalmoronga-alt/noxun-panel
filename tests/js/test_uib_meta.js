// UI-B dotiahnutie — META SUHRNY v listach sektorov (dependency-free Node:
// node tests/js/test_uib_meta.js).
//
// Lista kazdeho sektora nesie vpravo jednoriadkovy suhrn toho, co je vnutri
// (mockup_inspector_c.html, funkcia `sect`). Co sa tu strazi:
//   1) S1 = nazov PROJEKCIE podla rezimu vyberu a kontextu (nahlad je
//      kontextovy — UI-B2),
//   2) S2 = trojica rozmerov (nedelitelna) + sokel len tam, kde vobec je,
//   3) S3 = popisy materialov; prazdny slot = dedenie, ziadny slot = ziadne
//      meta (dielec/doska maju vlastnu kartu),
//   4) S4 = otvorena skupina menom, inak pocet zbalenych so SPRAVNOU
//      slovenskou mnozinou,
//   5) skladanie je CISTA funkcia — bez DOM, bez cachovaneho textu.
//
// shell.js exportuje ciste jadro (NXShell); DOM cast sa v Node nikdy nevola.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const NXShell = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.strictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
const meta = (s) => NXShell.sectorMeta(s);

// ------------------------------------------------------------------- S1 ------
// Nahlad sa medzi kontextami VYMIENA — meta hovori, ktora projekcia je na
// obrazovke (rovnaky zoznam ako PROJ_TITLE v mockupe).
eq(meta({ mode: 'cab', ctx: 'korpus' }).s1, 'Čelný rez + kóty', 'S1 korpus');
eq(meta({ mode: 'cab', ctx: 'zony' }).s1, 'Zóny', 'S1 zony');
eq(meta({ mode: 'cab', ctx: 'cela' }).s1, 'Čelá', 'S1 cela');
eq(meta({ mode: 'cab', ctx: 'kovanie' }).s1, 'Kovanie — pozície', 'S1 kovanie');
eq(meta({ mode: 'part', ctx: 'kovanie' }).s1, 'Dielec — hrany', 'dielec ma vlastnu projekciu bez ohladu na kontext');
eq(meta({ mode: 'board', ctx: 'korpus' }).s1, 'Doska — hrany', 'doska ma vlastnu projekciu');
eq(meta({ mode: 'insert', insert_kind: 'cabinet' }).s1, 'Náhľad šablóny', 'vkladanie korpusu');
eq(meta({ mode: 'insert', insert_kind: 'board' }).s1, 'Doska — smer dekoru', 'vkladanie dosky');
// Neznamy kontext neprepadne na prazdno (normCtx -> korpus).
eq(meta({ mode: 'cab', ctx: 'nieco' }).s1, 'Čelný rez + kóty', 'neznamy kontext = Korpus');

// ------------------------------------------------------------------- S2 ------
eq(meta({ mode: 'cab', dims: { w: 900, h: 720, d: 560, plinth: 100 } }).s2,
  '900 × 720 × 560 · sokel 100', 'S2 rozmery so soklom');
// Horna skrinka sokel nema — riadok je skryty, meta ho teda nespomina.
eq(meta({ mode: 'cab', dims: { w: 600, h: 720, d: 320, plinth: 100, plinth_visible: false } }).s2,
  '600 × 720 × 320', 'skryty sokel sa do meta nepise');
eq(meta({ mode: 'cab', dims: { w: 600, h: 720, d: 320, plinth: 0 } }).s2,
  '600 × 720 × 320', 'nulovy sokel sa nepise');
// Trojica je NEDELITELNA — dva z troch rozmerov by klamali.
eq(meta({ mode: 'cab', dims: { w: 900, h: 720 } }).s2, '', 'nekompletne rozmery = ziadne meta');
eq(meta({ mode: 'cab', dims: { w: 900, h: 720, d: 0 } }).s2, '', 'nulovy rozmer neplati');
eq(meta({ mode: 'cab', dims: {} }).s2, '', 'prazdne rozmery = ziadne meta');
eq(meta({ mode: 'cab' }).s2, '', 'chybajuce rozmery = ziadne meta');
// Rozpisane hodnoty su cisla, nie vety — zaokruhluje sa na cele mm.
eq(meta({ mode: 'cab', dims: { w: 899.6, h: 720.4, d: 560 } }).s2, '900 × 720 × 560', 'mm bez desatin');

// ------------------------------------------------------------------- S3 ------
eq(meta({ mode: 'cab', materials: ['K2738 MO', 'Biela', 'Biela'] }).s3,
  'K2738 MO · Biela · Biela', 'S3 tri materialy');
eq(meta({ mode: 'cab', materials: ['K2738 MO', '', ''] }).s3,
  'K2738 MO', 'prazdny slot (dedenie) sa vynecha');
eq(meta({ mode: 'cab', materials: ['', '', ''] }).s3,
  'dedí z projektu', 'vsetko dedene sa povie nahlas');
eq(meta({ mode: 'part', materials: [] }).s3, '', 'dielec ma vlastnu kartu — ziadne meta');
eq(meta({ mode: 'cab' }).s3, '', 'ziadne sloty = ziadne meta');
eq(meta({ mode: 'cab', materials: ['  ', null] }).s3, 'dedí z projektu', 'biele znaky su prazdny slot');

// ------------------------------------------------------------------- S4 ------
eq(meta({ mode: 'cab', groups: { open: 'Strop', count: 4 } }).s4, 'Strop', 'otvorena skupina menom');
// Kontext Cela ma jedinu skupinu s rovnakym menom ako sektor — „ČELÁ Čelá" je
// sum, nie udaj; meta nazov sektora NIKDY neopakuje.
eq(meta({ mode: 'cab', ctx: 'cela', groups: { open: 'Čelá', count: 1 }, s4_name: 'Čelá' }).s4,
  '', 'meta neopakuje nazov sektora');
eq(meta({ mode: 'cab', groups: { open: 'Strop', count: 4 }, s4_name: 'Nastavenia' }).s4,
  'Strop', 'ina skupina nazov sektora neopakuje');
eq(meta({ mode: 'cab', groups: { open: '', count: 4 } }).s4, '4 skupiny · všetko zbalené', '2–4 skupiny');
eq(meta({ mode: 'cab', groups: { open: '', count: 1 } }).s4, '1 skupina · všetko zbalené', 'jedna skupina');
eq(meta({ mode: 'cab', groups: { open: '', count: 5 } }).s4, '5 skupín · všetko zbalené', '5+ skupín');
eq(meta({ mode: 'cab', groups: { open: '', count: 0 } }).s4, '', 'kontext bez skupin = ziadne meta');
// Codex #173 P2: kontext Zony ma jedinu skupinu a je to `data-s4-solo` strom.
// Solo je vynate z EXKLUZIVITY, nie zo zberu udajov — meta ho musi vidiet.
eq(meta({ mode: 'cab', ctx: 'zony', groups: { open: 'Štruktúra zón', count: 1 }, s4_name: 'Zóny' }).s4,
  'Štruktúra zón', 'solo skupina (strom zon) ma v meta svoje meno');
eq(meta({ mode: 'cab', ctx: 'zony', groups: { open: '', count: 1 }, s4_name: 'Zóny' }).s4,
  '1 skupina · všetko zbalené', 'zbalena solo skupina sa pocita');
eq(meta({ mode: 'part', groups: { open: '', count: 0 } }).s4, '', 'dielec: karta, nie skupiny');
eq(meta({ mode: 'cab' }).s4, '', 'chybajuce skupiny = ziadne meta');

// ----------------------------------------------------------- cistota funkcie --
// Vstup sa NEMENI a rovnaky vstup da rovnaky vystup (skladanie nesmie mat pamat).
const vstup = { mode: 'cab', ctx: 'korpus', dims: { w: 900, h: 720, d: 560, plinth: 100 },
                materials: ['K2738 MO', '', ''], groups: { open: '', count: 4 } };
const kopia = JSON.parse(JSON.stringify(vstup));
const prvy = meta(vstup);
const druhy = meta(vstup);
n++;
assert.deepStrictEqual(prvy, druhy, 'to iste zadanie musi dat to iste meta');
n++;
assert.deepStrictEqual(vstup, kopia, 'sectorMeta nesmie siahnut na vstup');
// Vysledok su presne styri texty — kostra ma styri sektory.
n++;
assert.deepStrictEqual(Object.keys(prvy).sort(), ['s1', 's2', 's3', 's4'], 'meta pre styri sektory');

// Bez rezimu sa berie stav modulu (rovnaky vzor ako sectorVis) — po track('cab')
// je to kontext Korpus.
NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: 'g' }));
eq(meta({ dims: { w: 900, h: 720, d: 560 } }).s1, 'Čelný rez + kóty', 'bez rezimu plati stav modulu');

console.log(`OK test_uib_meta.js — ${n} kontrol`);
