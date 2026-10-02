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
//   4) S4 = SUHRN OBSAHU kontextu (H6b, O12) — otvorena skupina ho nemeni,
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
// UI-C1b: vkladanie kresli sablonu TAK, AKO BUDE VLOZENA (N9) — nazov projekcie
// je zrkadlom mockupu (mockup_inspector_c.html, sectPreview).
eq(meta({ mode: 'insert', insert_kind: 'cabinet' }).s1, 'Šablóna — ako bude vložená', 'vkladanie korpusu');
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
// H6b (O12): lista S4 je vzdy SUHRN OBSAHU kontextu — zbaleny aj rozbaleny sektor
// ukazuje to iste a otvorena skupina ho NEMENI. Podrobne scenare (Korpus 3 x 2 x 5
// kombinacii, Zony, Cela, Kovanie, okrajove pripady) su v test_h6b_suhrny.js; tu
// ostava nadstavba nad starym kontraktom „meta nie je nazov skupiny".
eq(meta({ mode: 'cab', content: { korpus: { top: 'two_rails', bottom: 'under_sides', back: 'groove' } } }).s4,
  'strop 2 výstuhy · boky na dne · chrbát v drážke', 'S4: Korpus = suhrn konstrukcie');
eq(meta({ mode: 'cab' }).s4, '', 'chybajuci obsah = ziadne meta');
eq(meta({ mode: 'part', content: { korpus: { top: 'full', bottom: 'under_sides', back: 'groove' } } }).s4, '',
  'S4: dielec ma kartu, nie skupiny');
eq(meta({ mode: 'board', content: { korpus: { top: 'full', bottom: 'under_sides', back: 'groove' } } }).s4, '',
  'S4: doska ma kartu, nie skupiny');
eq(meta({ mode: 'insert', content: { korpus: { top: 'full', bottom: 'under_sides', back: 'groove' } } }).s4, '',
  'S4: vkladanie ma vlastnu kartu (sektor Nastavenia je v nom skryty)');
// Stary vstup `groups` (otvorena skupina) uz nic nerobi — meta ho ignoruje.
eq(meta({ mode: 'cab', groups: { open: 'Strop', count: 4 } }).s4, '',
  'S4 (M3): otvorena skupina meta NEMENI (a ziadne „4 skupiny · vsetko zbalene")');

// ----------------------------------------------------------- cistota funkcie --
// Vstup sa NEMENI a rovnaky vstup da rovnaky vystup (skladanie nesmie mat pamat).
const vstup = { mode: 'cab', ctx: 'korpus', dims: { w: 900, h: 720, d: 560, plinth: 100 },
                materials: ['K2738 MO', '', ''],
                content: { korpus: { top: 'full', bottom: 'between_sides', back: 'overlay' } } };
const kopia = JSON.parse(JSON.stringify(vstup));
const prvy = meta(vstup);
const druhy = meta(vstup);
n++;
assert.deepStrictEqual(prvy, druhy, 'to iste zadanie musi dat to iste meta');
n++;
assert.deepStrictEqual(vstup, kopia, 'sectorMeta nesmie siahnut na vstup');
// Vysledok su texty pre styri sektory + odkaz v liste Nahladu (H6b).
n++;
assert.deepStrictEqual(Object.keys(prvy).sort(), ['s1', 's1link', 's2', 's3', 's4'],
  'meta pre styri sektory a odkaz na Korpus');

// Bez rezimu sa berie stav modulu (rovnaky vzor ako sectorVis) — po track('cab')
// je to kontext Korpus.
NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: 'g' }));
eq(meta({ dims: { w: 900, h: 720, d: 560 } }).s1, 'Čelný rez + kóty', 'bez rezimu plati stav modulu');

// ------------------------------------------------- S4: DOM cesta -------------
// `nxSectorMetaApply` sa v Node nevola, takze zdrojove kontroly strazia, ze sa
// k nazvu otvorenej skupiny (`textContent` <summary>) nikdy nevrati.
(function(){
  const src = require('node:fs')
    .readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'), 'utf8');
  n++; assert.ok(src.indexOf('function nxMetaContent(') >= 0, 'S4: `nxMetaContent` sa v shell.js nasla');
  n++; assert.ok(src.indexOf('function nxMetaGroups(') < 0, 'S4: `nxMetaGroups` zanikla (O12)');
  n++; assert.ok(src.indexOf('groupTitle') < 0, 'S4: nazov skupiny sa uz nezbiera');
})();

console.log(`OK test_uib_meta.js — ${n} kontrol`);
