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

// ------------------------------------------------- S4: NAZOV SKUPINY --------
// D-130b: hlavicky skupin nesu od D-130a `.gtools` (meta + akcie), takze
// `textContent` cele hlavicky uz NIE JE nazov skupiny — lista sektora by
// ukazovala „Čelá 3 čelá · 1 bez smeru všetkým". `groupTitle` berie LEN priame
// textove uzly `<summary>`; skupiny bez `.gtools` musia dat to iste, co davali
// predtym (inak by oprava potichu premenovala pol panela).
const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
function summaryOf(html){
  const s = mkEl('summary');
  s.innerHTML = html;
  DOC.body.appendChild(s);
  return s;
}
// Skupina S DOPLNKAMI v hlavicke (Čelá, D-130a).
eq(NXShell.groupTitle(summaryOf(
  '<svg class="ic gic"><use href="#i-front"/></svg>Čelá\n  ' +
  '<span class="gtools"><span class="meta" id="frontMeta">3 čelá · 1 bez smeru</span>' +
  '<button type="button" class="ibtn wide" id="frontBulkBtn">všetkým</button>' +
  '<button type="button" class="nxtip r"><svg class="ic"><use href="#i-help-circle"/></svg></button>' +
  '</span>')), 'Čelá', 'S4: meta ani akcie hlavicky NIE SU sucastou nazvu skupiny');
// Skupina „Spoločné pre skrinku" (D-130b) — meta je dlha a menila by sa pri
// kazdej zmene dekoru/medzier, takze v liste sektora nema co robit.
eq(NXShell.groupTitle(summaryOf(
  '<svg class="ic gic"><use href="#i-cabinet"/></svg>Spoločné pre skrinku\n  ' +
  '<span class="gtools"><span class="meta" id="cabfrontMeta">H1180 ST37 Du… · 3 · 2/2/0/0</span>' +
  '<button type="button" class="ibtn" id="edgeLimitLock"><svg class="ic"><use href="#i-lock"/></svg></button>' +
  '<button type="button" class="ibtn" id="frontGapsReset"><svg class="ic"><use href="#i-rotate-ccw"/></svg></button>' +
  '</span>')), 'Spoločné pre skrinku', 'S4: to iste pre skupinu so schemou medzier');
// Skupiny BEZ `.gtools` — presne tie isté nazvy ako pred opravou.
eq(NXShell.groupTitle(summaryOf('<svg class="ic gic"><use href="#i-p-bottom"/></svg>Dno &amp; podstavec')),
  'Dno & podstavec', 'S4: bezna skupina s ikonou ostava nedotknuta (aj s entitou)');
eq(NXShell.groupTitle(summaryOf('<svg class="ic gic"><use href="#i-rows-3"/></svg>Police')),
  'Police', 'S4: bezna skupina');
eq(NXShell.groupTitle(summaryOf('Pokročilé')), 'Pokročilé', 'S4: skupina bez ikony');
// Hranicne vstupy: ziadna hlavicka a hlavicka bez textu nesmu spadnut.
eq(NXShell.groupTitle(null), '', 'S4: chybajuca hlavicka = prazdny nazov');
eq(NXShell.groupTitle(summaryOf('<span class="meta">len meta</span>')), '',
  'S4: hlavicka bez vlastneho textu nema nazov (radsej prazdno nez cudzi text)');
// A DOM cesta ju naozaj pouziva — `nxSectorMetaApply` sa v Node nevola, takze
// bez tejto kontroly by sa dal `nxMetaGroups` ticho vratit na `textContent`.
(function(){
  const src = require('node:fs')
    .readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'), 'utf8');
  const fn = src.match(/function nxMetaGroups\(\)[\s\S]*?\n  \}/);
  n++; assert.ok(fn, 'S4: `nxMetaGroups` sa v shell.js nasla');
  n++; assert.ok(fn[0].indexOf('NXShell.groupTitle(s)') >= 0,
    'S4: `nxMetaGroups` berie nazov cez `groupTitle`');
  n++; assert.ok(fn[0].indexOf('textContent') < 0,
    'S4: a NEcita `textContent` hlavicky (pribral by meta aj akcie)');
})();

console.log(`OK test_uib_meta.js — ${n} kontrol`);
