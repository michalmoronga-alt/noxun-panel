// UI-B2 — nahlad ako kontextova projekcia + spodny pas vrstiev
// (dependency-free Node: node tests/js/test_uib2_nahlad.js).
//
// Co sa tu strazi:
//   1) kazdy kontext railu ma SVOJU projekciu (Kovanie uz nekresli korpus),
//   2) chipy pasu: zakladny chip kontextu sa neda zhasnut, ostatne sa daju
//      prisvietit ako ghost, Olep je mimo kontextu Dielec NEAKTIVNY (korpusovy
//      payload hranove data nema) a chip bez dat je neaktivny tiez,
//   3) stav chipov drzi kontext samostatne a NOVA identita vyberu ho resetuje
//      (echo push ho nechava — rovnaka zasada ako viewContext z UI-B1),
//   4) znacky kovania sa odvodzuju VYHRADNE z payloadu (owner_part_key +
//      generic_type + pocet) — ziadne nove data,
//   5) koty ciel su rozklad radu na vysky a medzery z resolved payloadu.
//
// preview.js exportuje ciste jadro; DOM cast sa v Node nikdy nevola
// (rovnaky vzor ako shell.js / usage.js).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const PV = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'preview.js'));
const NXLayers = PV.NXLayers;

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.strictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function deq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const ALL = { zony: true, cela: true, kovanie: true, olep: true };
function stateMap(mode, avail){
  const out = {};
  NXLayers.chips(mode, avail || ALL).forEach(c => { out[c.key] = c.state; });
  return out;
}

// ------------------------------------------------- 1) vyber projekcie -------
// Kontext railu -> rezim nahladu. Kovanie ma OD UI-B2 vlastnu projekciu.
eq(PV.cabTabPreview('korpus'), 'cab', 'Korpus = celny rez');
eq(PV.cabTabPreview('zony'), 'zones', 'Zony = zonova schema');
eq(PV.cabTabPreview('cela'), 'fronts', 'Cela = predny pohlad ciel');
eq(PV.cabTabPreview('kovanie'), 'hw', 'Kovanie ma VLASTNU projekciu (uz nekresli korpus)');
eq(PV.cabTabPreview('nieco-ine'), 'cab', 'neznamy kontext = korpus (fallback)');

// -------------------------------------------------- 2) chipy spodneho pasu --
NXLayers.reset();
deq(stateMap('zones'), { zony: 'base', cela: 'off', kovanie: 'off', olep: 'disabled' },
  'v kontexte Zony je zakladom chip Zony');
deq(stateMap('fronts'), { zony: 'off', cela: 'base', kovanie: 'off', olep: 'disabled' },
  'v kontexte Cela je zakladom chip Cela');
deq(stateMap('hw'), { zony: 'off', cela: 'off', kovanie: 'base', olep: 'disabled' },
  'v kontexte Kovanie je zakladom chip Kovanie');
deq(stateMap('cab'), { zony: 'off', cela: 'off', kovanie: 'off', olep: 'disabled' },
  'korpusova projekcia nema zakladnu vrstvu — vsetko sa da prisvietit');
deq(stateMap('part'), { zony: 'disabled', cela: 'disabled', kovanie: 'disabled', olep: 'base' },
  'v kontexte Dielec je zakladom Olep a vrstvy skrinky sa neprisvecuju');

// Olep mimo Dielca je NEAKTIVNY a povie preco (korpusovy payload hrany nenesie).
const olepCab = NXLayers.chips('cab', ALL).find(c => c.key === 'olep');
ok(/len pri označenom dielci/.test(olepCab.title), 'neaktivny Olep vysvetli dovod');
eq(NXLayers.toggle('cab', 'olep', ALL), false, 'Olep sa mimo Dielca neda prisvietit');
eq(NXLayers.toggle('zones', 'zony', ALL), false, 'zakladny chip sa neda zhasnut');

// Popis chipu sa sklada do aria-label ako „<vrstva> — <popis>", takze sam
// nesmie zacinat menom vrstvy (citacka by ho precitala dvakrat).
['cab', 'zones', 'fronts', 'hw', 'part'].forEach(mode => {
  [ALL, { zony: false, cela: false, kovanie: false, olep: false }].forEach(av => {
    NXLayers.chips(mode, av).forEach(c => {
      ok(!c.title.startsWith(c.label), `popis chipu ${c.key} (${mode}) nesmie zacinat menom vrstvy: "${c.title}"`);
      ok(c.title.length > 0, `chip ${c.key} (${mode}) musi mat popis`);
    });
  });
});

// Chip bez dat je neaktivny (poctivo — nie ticho mrtvy).
deq(stateMap('cab', { zony: true, cela: false, kovanie: false, olep: false }),
  { zony: 'off', cela: 'disabled', kovanie: 'disabled', olep: 'disabled' },
  'bez ciel a bez kovania su ich chipy neaktivne');
eq(NXLayers.toggle('cab', 'kovanie', { kovanie: false }), false,
  'chip bez dat sa neda zapnut');

// ---------------------------------------------- 3) stav chipov a jeho reset --
NXLayers.reset();
eq(NXLayers.toggle('cab', 'cela', ALL), true, 'prisvietenie vrstvy meni stav');
deq(NXLayers.ghosts('cab', ALL), ['cela'], 'prisvietena vrstva je v ghostoch');
eq(stateMap('cab').cela, 'on', 'chip svieti');
// Stav je VLASTNY pre kazdy kontext — prisvietenie v Korpuse nesvieti v Zonach.
deq(NXLayers.ghosts('zones', ALL), [], 'iny kontext ma vlastny stav chipov');
NXLayers.toggle('zones', 'kovanie', ALL);
deq(NXLayers.ghosts('zones', ALL), ['kovanie'], 'kontext Zony si drzi svoju vrstvu');
deq(NXLayers.ghosts('cab', ALL), ['cela'], 'a kontext Korpus tu svoju');
// Zakladna vrstva NIKDY nie je ghost (kresli ju samotna projekcia).
NXLayers.toggle('cab', 'zony', ALL);
deq(NXLayers.ghosts('zones', ALL), ['kovanie'], 'zakladna vrstva sa medzi ghosty nepridava');
// Druhy klik zhasina.
eq(NXLayers.toggle('cab', 'cela', ALL), true, 'druhy klik meni stav spat');
deq(NXLayers.ghosts('cab', ALL), ['zony'], 'zhasnuta vrstva vypadla z ghostov');
// Ghost sa nekresli, ked mu medzitym zmizli data (echo bez ciel).
NXLayers.reset();
NXLayers.toggle('cab', 'cela', ALL);
deq(NXLayers.ghosts('cab', { zony: true, cela: false, kovanie: true, olep: false }), [],
  'prisvietena vrstva bez dat sa nekresli');
// NOVA identita vyberu = cisty pas (echo push ho nezhasina — to strazi bridge,
// ktory reset vola LEN pri zmene identity; tu sa strazi samotny reset).
NXLayers.reset();
deq(NXLayers.ghosts('cab', ALL), [], 'reset zhasne vsetky prisvietene vrstvy');

// ------------------------------------------------- 4) znacky kovania --------
const GEOM = {
  W: 900, H: 720, fh: 100, gapSides: 2, gap: 3,
  fronts: [
    { id: 'F1', type: 'drawer_front', z: 100, height: 180, wings_n: 1 },
    { id: 'F2', type: 'door', z: 283, height: 437, wings_n: 2 }
  ]
};
const ITEMS = [
  { owner_part_key: null, generic_type: 'leg', quantity: 4, label: 'Nohy' },
  { owner_part_key: 'front:F1/panel', generic_type: 'slide', quantity: 1, label: 'Výsuv',
    owner_label: 'F1 · zásuvka' },
  { owner_part_key: 'front:F2/wing:left', generic_type: 'hinge', quantity: 2, label: 'Závesy',
    owner_label: 'F2 · ľavé krídlo' },
  { owner_part_key: 'front:F2/wing:right', generic_type: 'hinge', quantity: 2, label: 'Závesy',
    owner_label: 'F2 · pravé krídlo' },
  { owner_part_key: null, generic_type: 'shelf_pin', quantity: 8, label: 'Podperky' }
];
const marks = PV.nxHwMarks(ITEMS, GEOM);
const byKind = k => marks.filter(m => m.kind === k);
eq(byKind('leg').length, 4, '4 nohy = 4 znacky');
eq(byKind('hinge').length, 4, '2+2 zavesy = 4 znacky');
eq(byKind('slide').length, 2, 'jeden vysuv = dvojica kolajnic');
eq(marks.length, 10, 'podperky znacku nedostanu (nemaju kresitelnu poziciu)');
ok(byKind('leg').every(m => m.z === 0 && m.h <= GEOM.fh),
  'nohy sedia v pasme sokla, ked skrinka sokel ma');
ok(byKind('leg').every(m => m.x >= 0 && m.x + m.w <= GEOM.W),
  'nohy neprecnievaju z korpusu');
// Zavesy: lave kridlo vlavo, prave kridlo vpravo — a obe vo vyske SVOJHO cela.
const hL = marks.filter(m => m.kind === 'hinge' && m.owner === 'front:F2/wing:left');
const hR = marks.filter(m => m.kind === 'hinge' && m.owner === 'front:F2/wing:right');
ok(hL.every(m => m.x < GEOM.W / 2), 'zavesy laveho kridla su na lavej polovici');
ok(hR.every(m => m.x > GEOM.W / 2), 'zavesy praveho kridla su na pravej polovici');
ok(hL.concat(hR).every(m => m.z >= 283 && m.z <= 283 + 437),
  'zavesy su vo vyske svojho cela');
// Vysuv sedi vo vyske zasuvky F1, nie inde.
ok(byKind('slide').every(m => m.z >= 100 && m.z <= 100 + 180),
  'kolajnice su vo vyske zasuvky');
// Tooltip pomenuva polozku, vlastnika aj pocet — presne to, co je v payloade.
eq(hL[0].title, 'Závesy · F2 · ľavé krídlo · 2×', 'popis znacky je z payloadu');
// Kovanie na cele, ktore v rade neexistuje (stary override), sa NEKRESLI.
deq(PV.nxHwMarks([{ owner_part_key: 'front:F9/wing:left', generic_type: 'hinge', quantity: 2 }], GEOM), [],
  'kovanie neexistujuceho cela znacku nedostane');
deq(PV.nxHwMarks(null, GEOM), [], 'bez payloadu ziadne znacky');
deq(PV.nxHwMarks([], GEOM), [], 'prazdny payload = ziadne znacky');
// Bez sokla stoja nohy POD korpusom (zaporne z) — inak by viseli v dne.
const noPlinth = PV.nxHwMarks([{ owner_part_key: null, generic_type: 'leg', quantity: 4 }],
  Object.assign({}, GEOM, { fh: 0 }));
ok(noPlinth.every(m => m.z < 0), 'bez sokla su nohy pod korpusom');
// Suhrn: VSETKY typy vratane tych bez znacky.
eq(PV.nxHwSummary(ITEMS), 'Nohy 4× · Výsuv 1× · Závesy 4× · Podperky 8×',
  'suhrn scita rovnake polozky a nezabudne na typy bez znacky');
eq(PV.nxHwSummary([]), '', 'prazdne kovanie = prazdny suhrn');

// ---------------------------------------------------- 5) koty ciel a zon ----
const dims = PV.nxFrontDims(GEOM.fronts, GEOM);
deq(dims.map(d => d.kind), ['front', 'gap', 'front'], 'rad = celo, medzera, celo');
eq(Math.round(dims[0].size), 180, 'vyska F1 je z payloadu');
eq(Math.round(dims[1].size), 3, 'medzera je rozdiel medzi celami (ziadny vlastny vzorec)');
eq(Math.round(dims[2].size), 437, 'vyska F2 je z payloadu');
// Sokel nie je medzera — rad zacina az nad nim.
ok(!dims.some(d => d.kind === 'gap' && d.z1 === 0), 'pasmo sokla sa nekotuje ako medzera');
deq(PV.nxFrontDims([], GEOM), [], 'bez ciel niet co kotovat');
deq(PV.nxFrontDims([{ id: 'F1', z: 100, height: 0 }], GEOM), [],
  'celo s nulovou vyskou sa preskakuje');
// Horna medzera (rad konci pod stropom) sa kotuje tiez.
const withTop = PV.nxFrontDims([{ id: 'F1', z: 100, height: 500 }], GEOM);
deq(withTop.map(d => d.kind), ['front', 'gap'], 'zvysok pod stropom je medzera');

// Kota hlbky lezi NAD naznakom skosenia — scena jej musi nechat miesto na
// ciaru, znacky aj text, inak ju fit oreze (Codex #169 P2).
[ { H: 720, sk: 100.8 }, { H: 2000, sk: 24 }, { H: 400, sk: 130 } ].forEach(c => {
  const dimZ = PV.pvDepthDimZ(c.H, c.sk);
  const top = PV.pvSceneTopZ(c.H, c.sk);
  ok(dimZ > c.H + c.sk, `kota hlbky lezi nad skosenim (H=${c.H})`);
  ok(top >= dimZ + 16, `scena nechava miesto na kotu hlbky aj jej text (H=${c.H}): top=${top}, kota=${dimZ}`);
});
eq(PV.pvSceneTopZ(720, 0), 720, 'bez hlbky (bez skosenia) sa scena nad korpus nerozsiruje');

// Koty sirok zon: distinct stlpce, zoradene zlava.
deq(PV.nxZoneSpans([
  { leaf: true, x: 18, w: 414, z: 0, h: 500 },
  { leaf: true, x: 18, w: 414, z: 500, h: 100 },
  { leaf: true, x: 450, w: 414, z: 0, h: 600 },
  { leaf: false, x: 0, w: 900, z: 0, h: 700 }
]), [{ x: 18, w: 414 }, { x: 450, w: 414 }],
  'rovnake stlpce sa kotuju raz a nelistove zony vobec');
deq(PV.nxZoneSpans([]), [], 'bez zon niet co kotovat');

console.log(`OK test_uib2_nahlad.js — ${n} kontrol`);
