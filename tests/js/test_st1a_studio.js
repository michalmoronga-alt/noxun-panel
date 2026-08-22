// Testy ST-1a — okno ŠTÚDIO, sekcia Kusovník (Š1–Š6). CISTE funkcie bez DOM.
//
// Preco su to testy a nie klikanie:
//   1. Zoskupenie podla materialu urcuje PORADIE aj MEDZISUCTY — keby JS
//      scitaval sam, kusovnik a rozpocet by casom ukazali ine m² tej istej
//      zakazky (a rozdiel by sa objavil az na objednavke platni).
//   2. Hladanie musi ignorovat diakritiku: „lavy" ma najst „Bok ľavý". Bez toho
//      by filter na slovenskej zakazke prakticky nefungoval.
//   3. Kody hran L1/L2/W1/W2 sa ZAMERNE neprekladaju na „predná/zadná" — ten
//      isty kod znamena pri kazdej role INU fyzicku hranu (docs/ARCHITEKTURA,
//      `part_faces`), takze pevny preklad by pri policiach klamal.
//   4. Navigacia: co je PREMOSTENIE (otvara ine okno) a co je zivá sekcia, musi
//      sediet s Ruby whitelistom — inak by klik skoncil ticho.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const S = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'studio.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) whitelist sekcii (zrkadlo StudioDialog::SECTIONS) --------------------

// ŠT-1b: pribudla sekcia Kontrola (`ctrl`) — dovtedy bola premostenim do
// okna Vyroba. Zoznam je ZRKADLO `StudioDialog::SECTIONS`.
eq(S.STUDIO_SECTIONS, ['bom', 'ctrl'], 'v Studiu ziju sekcie Kusovník a Kontrola');

// --- 2) hladanie bez diakritiky (Š6) ----------------------------------------

eq(S.normText('Bok ľavý'), 'bok lavy', 'diakritika ide prec, text sa zmensi');
eq(S.normText('ČELO Š1'), 'celo s1', 'aj velke pismena s diakritikou');
eq(S.normText(null), '', 'chybajuca hodnota nezhodi normalizaciu');

const ROW_A = { names: ['Bok ľavý'], kde: [{ owner_id: 'CAB-004', quantity: 1 }],
                material_id: 'M500', role_label: 'Bok ľavý', length: 720, width: 560,
                thickness: 18, quantity: 1, grain_direction: 'length',
                edges: { L1: 'A1', L2: null, W1: 'A1', W2: null }, key: ['k', 'a'] };
const ROW_B = { names: ['Polica'], kde: [{ owner_id: 'CAB-009', quantity: 2 }],
                material_id: 'M500', role_label: 'Polica', length: 560, width: 530,
                thickness: 18, quantity: 2, grain_direction: 'none',
                edges: { L1: 'A2' }, key: ['k', 'b'] };
const ROW_C = { names: ['Čelo F1'], kde: [{ owner_id: 'CAB-004', quantity: 1 }],
                material_id: 'K686', role_label: 'Dvierka', length: 355, width: 596,
                thickness: 18, quantity: 1, grain_direction: 'width',
                edges: {}, key: ['k', 'c'] };

ok(S.rowHit(ROW_A, ''), 'prazdny filter prepusti vsetko');
ok(S.rowHit(ROW_A, 'lavy'), 'hlada sa BEZ diakritiky — „lavy" najde „Bok ľavý"');
ok(S.rowHit(ROW_A, 'CAB-004'), 'hlada sa aj podla skrinky');
ok(S.rowHit(ROW_A, 'cab-004'), 'velkost pismen nerozhoduje');
ok(S.rowHit(ROW_B, 'polica'), 'nazov dielca');
ok(!S.rowHit(ROW_B, 'CAB-004'), 'ina skrinka sa nenajde');
ok(S.rowHit(ROW_C, 'dvierka'), 'hlada sa aj podla ROLY (serverovy text `role_label`)');
ok(!S.rowHit(ROW_C, 'zzz'), 'nezmysel nenajde nic');

// --- 3) Š1: zoskupenie podla materialu ---------------------------------------
// Medzisucty NEPOCITA klient — beru sa z `sheets` (server). Test to strazi tym,
// ze do `sheets` da cisla, ktore sa zo `rows` NEDAJU odvodit: keby si ich JS
// dopocitaval, vysli by ine.
const SHEETS = [
  { material_id: 'M500', m2: 6.84, quantity: 10 },
  { material_id: 'K686', m2: 2.42, quantity: 7 }
];
const ROWS = [ROW_A, ROW_B, ROW_C];

const G = S.groupBom(ROWS, SHEETS, '');
eq(G.groups.map(g => g.id), ['M500', 'K686'], 'poradie skupin urcuje SERVEROVY supis, nie poradie riadkov');
eq(G.groups[0].rows.length, 2, 'riadky sadli do svojej skupiny');
eq(G.groups[0].m2, 6.84, 'medzisucet m² je SERVEROVE cislo (nie sucet riadkov)');
eq(G.groups[0].ks, 10, 'medzisucet ks je SERVEROVE cislo');
eq(G.shown, 3, 'bez filtra su videt vsetky riadky');
eq(G.total, 3, 'celkovy pocet riadkov');

const GF = S.groupBom(ROWS, SHEETS, 'celo');
eq(GF.groups.map(g => g.id), ['K686'], 'Š6: prazdna skupina sa pri filtri SKRYJE');
eq(GF.shown, 1, 'pocitadlo filtra rata zobrazene riadky');
eq(GF.total, 3, 'a druhe cislo ostava celkom (aby bolo „1 z 3")');

eq(S.groupBom([], SHEETS, '').groups, [], 'prazdny kusovnik = ziadne skupiny');
eq(S.groupBom(null, null, '').groups, [], 'chybajuce data nezhodia zoskupenie');

// Material, ktory v supise NIE JE (nemal by), sa nestrati — pripoji sa bez
// medzisuctu. Radsej riadok bez suctu nez dielec, ktory z kusovnika zmizne.
const GX = S.groupBom([{ names: ['X'], kde: [], material_id: 'NEZNAMY', edges: {} }], SHEETS, '');
eq(GX.groups.map(g => g.id), ['NEZNAMY'], 'neznamy material dostane vlastnu skupinu');
eq(GX.groups[0].m2, null, 'a prizna, ze medzisucet nema (nedopocitava sa)');

// --- 4) Š2: volitelne stlpce -------------------------------------------------

const DEFAULT_COLS = S.activeCols(S.COLS).map(c => c.k);
eq(DEFAULT_COLS, ['name', 'cab', 'l', 'w', 'th', 'q', 'abs'],
   'default podla kontraktu Š2: Dielec·Skrinka·Dĺžka·Šírka·Hr.·ks·ABS');
eq(S.COLS.filter(c => c.fixed).map(c => c.k), ['name'],
   'jediny nevypnutelny stlpec je nazov dielca (bez neho by riadok nic nehovoril)');
eq(S.COLS.map(c => c.k).sort(),
   ['abs', 'cab', 'grain', 'l', 'name', 'q', 'role', 'th', 'w'].sort(),
   'VEDOMA ODCHYLKA ST-1a: stlpec „Poznámka" tu NIE JE — v Ruby preň neexistuje zdroj');

const OFF = S.COLS.map(c => Object.assign({}, c, { on: c.k === 'name' }));
eq(S.activeCols(OFF).map(c => c.k), ['name'], 'vypnute stlpce sa nekreslia');

// --- 5) hodnoty buniek -------------------------------------------------------

eq(S.cellValue(ROW_A, 'name'), 'Bok ľavý', 'nazov je zoznam mien riadku');
// Riadok sa agreguje NAPRIEC skrinkami, takze bez poctu na vlastnika by sa
// nedalo povedat, kolko kusov potrebuje ktora z nich (vzor okna Vyroba).
eq(S.cellValue(ROW_A, 'cab'), 'CAB-004 ×1', 'skrinka nesie AJ pocet kusov');
eq(S.cellValue(ROW_B, 'cab'), 'CAB-009 ×2', 'dva kusy v jednej skrinke');
eq(S.cellValue({ kde: [{ owner_id: 'CAB-1', quantity: 2 }, { owner_id: 'CAB-2', quantity: 1 }] }, 'cab'),
   'CAB-1 ×2, CAB-2 ×1', 'viac vlastnikov = zoznam s poctami');
eq(S.cellValue({ kde: [{ owner_id: 'CAB-1' }] }, 'cab'), 'CAB-1',
   'chybajuci pocet sa nevymysla (starsi payload)');
eq(S.cellValue(ROW_A, 'th'), 18, 'hrubku urcuje DIELEC, nie skupina');
eq(S.cellValue(ROW_A, 'role'), 'Bok ľavý', 'rolu sklada SERVER (`role_label`)');
eq(S.cellValue({}, 'role'), '', 'riadok bez roly nic nevymysla');
eq(S.cellValue(ROW_A, 'grain'), 'pozdĺžna', 'smer dekoru rečou stolára');
eq(S.cellValue(ROW_B, 'grain'), 'bez smeru', 'materiál bez smeru');
eq(S.cellValue(ROW_C, 'grain'), 'priečna', 'priečny smer');

// --- 6) ABS kompakt ----------------------------------------------------------

const EMETA = { A1: { label: 'K686 22×1', th: 1.0 }, A2: { label: 'K686 22×2', th: 2.0 } };
eq(S.absCompact(ROW_A, EMETA), 'L1:1 · W1:1', 'kompakt nesie KOD hrany a hrubku pasky');
eq(S.absCompact(ROW_B, EMETA), 'L1:2', 'jedna olepena hrana');
eq(S.absCompact(ROW_C, EMETA), '—', 'dielec bez olepu');
eq(S.absCompact(ROW_A, {}), 'L1 · W1', 'bez metadat sa ukaze aspon kod hrany');
eq(S.absFull(ROW_A, EMETA), 'L1 — K686 22×1 · W1 — K686 22×1', 'tooltip nesie plne znenie');
eq(S.absFull(ROW_C, EMETA), 'bez ABS', 'a pri prazdnom olepe to POVIE');

// --- 7) farba vzorky (server posiela [r,g,b], nie CSS) ----------------------

eq(S.rgbHex([246, 246, 243]), '#f6f6f3', 'pole [r,g,b] sa prevedie na hex');
eq(S.rgbHex([0, 0, 0]), '#000000', 'nuly sa doplnia nulou');
eq(S.rgbHex(null), '', 'chybajuca farba = ziadna vzorka (radsej nic nez nahodna farba)');
eq(S.rgbHex([1, 2]), '', 'neuplne pole sa odmietne');
eq(S.rgbHex(['red', 0, 0]), '', 'necislo sa odmietne — do `style` ide iba hex');
eq(S.rgbHex([300, -5, 12]), '#ff000c', 'hodnoty mimo rozsahu sa orezu, nie zahodia');

// --- 8) navigacia: premostenia vs. neaktivne polozky ------------------------

eq(S.navBridgeIds().sort(),
   ['about', 'bset', 'budget', 'buy', 'hw', 'mat', 'offer', 'rules', 'sup', 'tpl'].sort(),
   'ZRKADLO whitelistu premosteni v StudioDialog (PRODUCTION_BRIDGES + WINDOW_BRIDGES + about)');

const CUT = S.navItem('cut');
ok(CUT && CUT.disabled, 'Nárezový plán je JEDINA neaktivna polozka');
ok(!CUT.bridge, 'a nema kam premostit — neexistuje okno, ktore by ho ukazalo');
ok(/fáza 2/.test(CUT.disabled), 'dovod je v tooltipe (vzor D-78 — ziadne mrtve tlacidlo bez vysvetlenia)');

const BOM_ITEM = S.navItem('bom');
ok(BOM_ITEM && !BOM_ITEM.bridge && !BOM_ITEM.disabled, 'Kusovník je ZIVA sekcia tohto okna');

// Kazda polozka navigacie je bud sekcia, alebo premostenie, alebo ma dovod.
// Polozka bez jedneho z troch by bola tichy mrtvy klik.
S.NAV.forEach(function(g){
  g.items.forEach(function(it){
    ok(S.STUDIO_SECTIONS.indexOf(it.id) >= 0 || it.bridge || it.disabled,
       `polozka navigacie „${it.t}" musi byt sekcia, premostenie alebo mat dovod`);
    ok(!!it.ic, `polozka „${it.t}" ma ikonu (zbalena navigacia ukazuje LEN ikony)`);
  });
});

// --- 8b) pohlad PLATNE: duplak (2B-1 / D-43) --------------------------------
// Material, ktoreho plocha vznikla LEN z lepenych (duplakovych) dielcov, NEMA
// vlastne vyrobne dielce — v `sheets` teda nie je, ale v `sheet_estimate` ANO,
// lebo sa REALNE nakupuje. Keby tabulka isla iba cez `sheets`, ten nakup by
// z nej zmizol a suctovy riadok (rata cez vsetky polozky odhadu) by s nou
// nesedel. Presne to bol nalez review P2.
const DUP_ROWS = [
  { names: ['Doska'], kde: [{ owner_id: 'CAB-1', quantity: 1 }], material_id: 'DUP36',
    material_source: { material_id: 'ZDROJ18', multiplier: 2 }, edges: {} }
];
const DUP_SHEETS = [{ material_id: 'DUP36', m2: 1.2, quantity: 1 }];
const DUP_EST = [
  { material_id: 'DUP36', m2: 1.2, sheet_size: [2800, 2070], count_min: 0.1, count_max: 0.2 },
  { material_id: 'ZDROJ18', m2: 2.4, sheet_size: [2800, 2070], count_min: 0.2, count_max: 0.4,
    doubled_m2: 2.4, doubled_quantity: 2 }
];

const SR = S.sheetRows(DUP_SHEETS, DUP_EST, DUP_ROWS);
eq(SR.map(r => r.mid), ['DUP36', 'ZDROJ18'],
   'zdrojovy material BEZ vlastnych dielcov ostava v tabulke (nakup by inak zmizol)');
eq(SR[0].purchaseOnly, false, 'material s vlastnymi dielcami nie je „nakup pre dupláky"');
eq(SR[1].purchaseOnly, true, 'zdroj duplaku JE nakupny riadok');
eq(SR[1].quantity, null, 'a nema pocet dielcov (ziadne vlastne nema)');
eq(SR[0].dup, ['lepí sa 2× z ZDROJ18'], 'vazba duplaku sa cita z BOM riadkov');
eq(SR[1].est.doubled_m2, 2.4, 'anotacia „+X dupl." ma z coho vzniknut');

// Ten isty material s ROZNYMI vazbami (katalog sa zmenil medzi rebuildmi) —
// BOM ich drzi oddelene, takze zoznam, nie posledna hodnota (GH #94 P2).
const TWO = S.sheetRows(
  [{ material_id: 'DUP36', m2: 1, quantity: 2 }],
  [],
  [{ material_id: 'DUP36', material_source: { material_id: 'A', multiplier: 2 } },
   { material_id: 'DUP36', material_source: { material_id: 'B', multiplier: 2 } },
   { material_id: 'DUP36', material_source: { material_id: 'A', multiplier: 2 } }]
);
eq(TWO[0].dup, ['lepí sa 2× z A', 'lepí sa 2× z B'], 'dve vazby, bez duplicit');

eq(S.sheetRows(null, null, null), [], 'chybajuce data nezhodia zoznam');
eq(S.sheetRows([{ material_id: 'M1', m2: 1, quantity: 1 }], [], []).map(r => r.est), [null],
   'material bez odhadu prizna, ze odhad nema');

// --- 9) kotva deep-linku (audit #12) ----------------------------------------

eq(S.anchorFilter({ anchor: 'CAB-004' }), 'CAB-004', 'kotva sa stane textom hladania');
eq(S.anchorFilter({ anchor: '  CAB-004  ' }), 'CAB-004', 'okraje sa orezu');
eq(S.anchorFilter({ anchor: '   ' }), null, 'prazdna kotva nefiltruje nic');
eq(S.anchorFilter({}), null, 'bez kotvy sa filter nemeni');
eq(S.anchorFilter(null), null, 'chybajuci payload nezhodi kotvu');

// Kotva naozaj zuzi zoznam na jednu skrinku — to je splneny slub UI-D3.
const GA = S.groupBom(ROWS, SHEETS, S.anchorFilter({ anchor: 'CAB-009' }));
eq(GA.shown, 1, 'kotva CAB-009 necha jediny riadok tej skrinky');
eq(GA.groups[0].rows[0].names, ['Polica'], 'a je to naozaj jej dielec');

console.log(`test_st1a_studio: ${n} kontrol OK`);
