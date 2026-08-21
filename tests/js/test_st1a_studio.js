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

eq(S.STUDIO_SECTIONS, ['bom'], 'v ST-1a zije jedina sekcia — Kusovník');

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
eq(S.cellValue(ROW_A, 'cab'), 'CAB-004', 'skrinka sa berie z `kde`');
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
   ['about', 'bset', 'budget', 'buy', 'ctrl', 'hw', 'mat', 'offer', 'rules', 'sup', 'tpl'].sort(),
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
