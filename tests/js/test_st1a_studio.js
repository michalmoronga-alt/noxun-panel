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

// DOM stub je ZAMERNE prazdny (getElementById vracia null) — vacsina sady su
// ciste funkcie. Delegovane listenery si vsak PAMATA: sekcia 11 nimi klika na
// rohove nastavenie VEPO a bez nich by sa spravanie „otvor / zavri / zapis"
// dalo overit len grepom.
global.window = {};
const LISTEN = {};
const ELS = {};
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; }
};
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
// ŠT-2a: pribudla sekcia Materiály (`mat`) — prva ziva polozka skupiny KATALÓGY.
// ŠT-3a-1: a Kovanie (`hw`) — druha.
eq(S.STUDIO_SECTIONS, ['bom', 'ctrl', 'buy', 'budget', 'offer', 'mat', 'hw', 'rules', 'tpl'],
   'v Studiu ziju sekcie Kusovník, Kontrola, Nákup kovania, Rozpočet, Cenová ponuka, Materiály, Kovanie, Pravidlá a Šablóny');

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

// ŠT-1c PR A: `buy` (Nákup kovania) uz NIE JE premostenie — je to ziva sekcia.
// ŠT-1c PR B1: to iste `budget` (Rozpocet), PR B2 `offer` (Cenova ponuka).
// ŠT-2a: `mat` (Materiály) uz NIE JE premostenie — je to ziva sekcia.
// ŠT-3a-1: to iste `hw` (Kovanie) — okno „Katalóg kovania" este zije, ale
// otvara ho premostenie Z VNUTRA sekcie, nie polozka navigacie.
// ŠT-3b-1: `rules` (Pravidlá) už NIE JE premostenie — je to živá sekcia.
eq(S.navBridgeIds().sort(),
   ['about', 'bset', 'sup'].sort(),
   'ZRKADLO whitelistu premosteni v StudioDialog (WINDOW_BRIDGES + about)');

const MAT_ITEM = S.navItem('mat');
ok(MAT_ITEM && !MAT_ITEM.bridge && !MAT_ITEM.disabled,
   'ŠT-2a: Materiály su ZIVA sekcia tohto okna (navigacia uz neotvara satelit)');

const HW_ITEM = S.navItem('hw');
ok(HW_ITEM && !HW_ITEM.bridge && !HW_ITEM.disabled,
   'ŠT-3a-1: Kovanie je ZIVA sekcia tohto okna');
eq(HW_ITEM.ic, 'hammer', 'ikona sekcie je hammer — ta ista ako rail Inspectora (kontrakt)');

const RULES_ITEM = S.navItem('rules');
ok(RULES_ITEM && !RULES_ITEM.bridge && !RULES_ITEM.disabled,
   'ŠT-3b-1: Pravidlá su ZIVA sekcia tohto okna');

const BUDGET_ITEM = S.navItem('budget');
ok(BUDGET_ITEM && !BUDGET_ITEM.bridge && !BUDGET_ITEM.disabled,
   'Rozpočet je ZIVA sekcia tohto okna (ŠT-1c PR B1)');

const OFFER_ITEM = S.navItem('offer');
ok(OFFER_ITEM && !OFFER_ITEM.bridge && !OFFER_ITEM.disabled,
   'ŠT-1c PR B2: Cenová ponuka je ZIVA sekcia tohto okna');
ok(!OFFER_ITEM.goto,
   'klientsky preklik do casti Rozpoctu ZANIKOL — ponuka ma vlastnu sekciu');

const BUY_ITEM = S.navItem('buy');
ok(BUY_ITEM && !BUY_ITEM.bridge && !BUY_ITEM.disabled, 'Nákup kovania je ZIVA sekcia tohto okna');

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

// --- 10) SMOKE 22.8.: LISTA sekcie Kusovnik (1B/1C/1D) ----------------------
// Michalov smoke test hlasil tri veci naraz: neaktivne XLSX/CSV vyzeraju ako
// rozbite tlacidla, checkbox „18+36 spolu" nema v liste pohladu co robit
// (patri k EXPORTU) a pole Projekt splyva s popiskami. Lista sa tym prekopala,
// takze tu je jej zavazny tvar — poradie aj obsah.

const VEPO = { project: 'Kuchyňa Novák', default_project: 'projekt', merge_18_36: true };
const BAR = S.bomToolsHtml(VEPO, { view: 'parts', q: '', cols: false, vepo: false });

ok(BAR.indexOf('XLSX') < 0, '1B: neaktivne XLSX tlacidlo je z listy PREC (vrati sa s realnym exportom)');
ok(BAR.indexOf('> CSV</button>') < 0, '1B: a to iste plati pre CSV kusovnika');
ok(BAR.indexOf('zatiaľ neexistuje') < 0, '1B: v liste uz nie je ziadny slub „prijde v dalsej davke"');
ok(BAR.indexOf('aria-disabled') < 0, '1B: v liste Kusovnika neostalo ZIADNE mrtve tlacidlo');
// „CSV" v tooltipe VEPO exportu je nazov FORMATU, nie druhe tlacidlo.
ok(/title="Exportuje prírezy[^"]*VEPO CSV/.test(BAR), 'VEPO export ostal a stale hovori, co robi');

// 1C+1D poradie: vlavo „co pozeram", vpravo „co s tym robim".
const ORDER = ['class="bomviews"', 'class="prjbox"', 'class="searchbox"', 'class="spacer"',
               'id="vepoBtn"', 'id="colBtn"', 'id="refreshBtn"'];
let last = -1;
ORDER.forEach(function(mark){
  const at = BAR.indexOf(mark);
  ok(at > last, `1C: ${mark} je v liste na svojom mieste (poradie schvalene 22.8.)`);
  last = at;
});

ok(BAR.indexOf('<span class="prjlbl">Projekt</span>') > -1,
   '1D: pole Projekt ma VIDITELNY stitok (nie len placeholder)');
ok(BAR.indexOf('value="Kuchyňa Novák"') > -1, '1D: a nesie hodnotu zo SERVERA');
ok(BAR.indexOf('placeholder="projekt"') > -1, 'default projektu ostava placeholderom');
ok(/title="Názov zákazky[^"]*exporty/.test(BAR),
   '1D: tooltip povie, ze nazov plati pre VSETKY exporty');

// Segment pohladov aj stlpce reaguju na stav, ktory pride ARGUMENTOM.
const ABS_BAR = S.bomToolsHtml(VEPO, { view: 'abs', q: 'polica', cols: false, vepo: false });
ok(ABS_BAR.indexOf('id="colBtn"') < 0, 'Stlpce ma len pohlad Dielce (Platne/ABS ich nemaju)');
ok(ABS_BAR.indexOf('value="polica"') > -1, 'text hladania sa do listy vracia');
ok(S.bomToolsHtml(VEPO, { view: 'parts', q: '', cols: true, vepo: false }).indexOf('id="colMenu"') > -1,
   'otvorene menu stlpcov sa kresli');

// --- 11) SMOKE 1A: rohove nastavenie VEPO exportu ---------------------------
// Checkbox „18+36 spolu" sa z listy odstahoval do rohu tlacidla VEPO (vzor
// „flyout roh", UI_DIZAJN §5.11). Overuje sa TVAR (roh je samostatne tlacidlo
// nad telom, nie vnoreny span) aj SPRAVANIE (otvorenie, zatvorenie klikom mimo
// a Escapom, zapis existujucou cestou).

ok(BAR.indexOf('id="vepoMore"') > -1, '1A: VEPO export ma rohovu klikaciu zonu');
ok(BAR.indexOf('id="mergeChk"') > -1, '1A: a checkbox „18+36 spolu" je v jeho nastaveni');
ok(BAR.indexOf('class="mergebox"') < 0, '1A: z LISTY checkbox zmizol');
{
  const fly = BAR.slice(BAR.indexOf('<span class="vepofly">'));
  const corner = fly.indexOf('id="vepoMore"');
  const body = fly.indexOf('id="vepoBtn"');
  ok(body < corner, '1A: roh je SUROdenec tela, nie jeho obsah (tlacidlo v tlacidle je neplatne HTML)');
  ok(fly.slice(corner, fly.indexOf('</button>', corner)).indexOf('class="cornerzone"') > -1,
     '1A: a pouziva ZDIELANU klikaciu zonu `.cornerzone` (rovnaky vzor ako rail a Kontrola)');
}
ok(S.vepoMenuHtml(VEPO, false).indexOf('class="vepomenu"') > -1, '1A: zavrete okno nema triedu `open`');
ok(S.vepoMenuHtml(VEPO, true).indexOf('class="vepomenu open"') > -1, '1A: otvorene ju ma');
ok(S.vepoBtnHtml(VEPO, true).indexOf('aria-expanded="true"') > -1,
   '1A: citacka sa o otvorenom nastaveni dozvie (aria-expanded)');
ok(S.vepoMenuHtml({ merge_18_36: false }, true).indexOf('checked') < 0,
   '1A: stav checkboxu je Z PAYLOADU — vypnuty merge sa naozaj nekresli');
ok(S.vepoMenuHtml({}, true).indexOf('checked') > -1,
   '1A: chybajuca hodnota = zapnute (zhodne so serverovym defaultom)');
// Review #4: okno ma HLAVICKU — inak sa otvara rovno checkboxom a nepovie,
// co vlastne nastavuje (vzor `.colmenu .mgrp` aj zdielaneho nastavenia hran).
ok(S.vepoMenuHtml(VEPO, true).indexOf('<div class="mgrp">Nastavenie VEPO exportu</div>') > -1,
   'review #4: nastavenie ma hlavicku .mgrp (zhoda s mockupom aj susednym menu)');

// Review #1: menu stlpcov visi na SVOJOM tlacidle — obal `.colfly` (vzor
// `.vepofly`). Kym bolo kotvene na lište, po presune tlacidla doprava sa od
// neho vizualne odtrhlo.
{
  const cols = S.bomToolsHtml(VEPO, { view: 'parts', q: '', cols: true, vepo: false });
  const fly = cols.indexOf('<span class="colfly">');
  ok(fly > -1, 'review #1: tlacidlo Stĺpce ma vlastny pozicovaci obal');
  ok(fly < cols.indexOf('id="colBtn"') && cols.indexOf('id="colBtn"') < cols.indexOf('id="colMenu"'),
     'review #1: a menu je V NOM, hned za tlacidlom');
  ok(cols.indexOf('id="colMenu"') < cols.indexOf('</span>', cols.indexOf('id="colMenu"')),
     'review #1: obal sa uzatvara az za menu');
}

(function(){
  // Minimalny DOM: `renderTools` musi mat kam pisat, inak sa vrati hned.
  const box = { innerHTML: '' };
  ['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel'].forEach(function(id){
    ELS[id] = (id === 'sectools') ? box : { innerHTML: '', textContent: '' };
  });
  const sent = [];
  // V prehliadaci je `sketchup` globalny objekt — v Node ho treba mat na OBOCH
  // menach (`window.sketchup` guard aj holy `sketchup` v tele funkcii).
  const SU = {
    ready: function(){},
    studio_set_vepo_opts: function(p){ sent.push(JSON.parse(p)); },
    refresh_bom: function(){ sent.push('refresh'); }
  };
  global.window.sketchup = SU;
  global.sketchup = SU;
  global.NX = global.window.NX;   // ten isty dovod ako pri `sketchup`
  const fire = function(type, target, extra){
    (LISTEN[type] || []).forEach(function(fn){
      fn(Object.assign({ type: type, target: target, preventDefault: function(){} }, extra || {}));
    });
  };
  // Ciel klikov: `closest` odpoveda LEN na selektory, ktore uzol naozaj ma.
  const tgt = function(map){
    return { closest: function(sel){ return map[sel] || null; },
             hasAttribute: function(){ return false; } };
  };
  const CORNER = tgt({ '[data-vepo]': {}, '.vepofly': {} });
  const OUTSIDE = tgt({});

  global.window.NX.setStudio({ version: '0.7.41', gen: 3, model_title: 'ENGINEtests',
                               rows: [], sheets: [], counts: {}, vepo: VEPO });
  ok(box.innerHTML.indexOf('class="vepomenu"') > -1, '1A: po pushi je nastavenie ZAVRETE');

  fire('click', CORNER);
  ok(box.innerHTML.indexOf('class="vepomenu open"') > -1, '1A: klik na roh ho OTVORIL');
  ok(box.innerHTML.indexOf('aria-expanded="true"') > -1, '1A: a roh to prizna');

  fire('change', { id: 'mergeChk', checked: false, hasAttribute: function(){ return false; } });
  eq(sent.length, 1, '1A: prepnutie islo do Ruby (jedna sprava)');
  eq(sent[0].merge, false, '1A: EXISTUJUCOU cestou `studio_set_vepo_opts` s hodnotou');
  eq(sent[0].gen, 3, '1A: a s identitou okna (server odmietne stary DOM)');

  // Echo servera prepise stav checkboxu aj v OTVORENOM okne (audit #16).
  ELS.mergeChk = { checked: false };
  global.window.NX.setVepoBar({ project: 'Kuchyňa Novák', merge_18_36: true });
  eq(ELS.mergeChk.checked, true, '1A: echo servera dorovna otvorene nastavenie');
  delete ELS.mergeChk;

  fire('click', OUTSIDE);
  ok(box.innerHTML.indexOf('class="vepomenu open"') < 0, '1A: klik MIMO nastavenie zavrel');

  fire('click', CORNER);
  ok(box.innerHTML.indexOf('class="vepomenu open"') > -1, 'a znova otvoril');
  fire('keydown', OUTSIDE, { key: 'Escape' });
  ok(box.innerHTML.indexOf('class="vepomenu open"') < 0, '1A: Escape ho tiez zavrie');

  // Klik na TELO exportu sa k nastaveniu nedostane a naopak (dve akcie, dva ciele).
  SU.vepo_export = function(){ sent.push('export'); };
  fire('click', tgt({ '#vepoBtn': {} }));
  eq(sent[sent.length - 1], 'export', '1A: klik na telo exportuje ako doteraz');
  fire('click', CORNER);
  eq(sent[sent.length - 1], 'export', '1A: a klik na roh NEEXPORTUJE (otvara nastavenie)');

  // --- review #8: otvorene menu patri SEKCII, z ktorej odchadzame -----------
  // Bez vynulovania by sa nastavenie pri navrate do Kusovnika otvorilo „samo".
  ok(box.innerHTML.indexOf('class="vepomenu open"') > -1, 'nastavenie je pred prepnutim OTVORENE');
  global.window.studioGoSection('ctrl');
  global.window.studioGoSection('bom');
  ok(box.innerHTML.indexOf('class="vepomenu open"') < 0,
     'review #8: po prepnuti sekcie a navrate je nastavenie ZAVRETE');

  // Deep-link je ten isty pripad — sekciu prepina server, nie klik.
  fire('click', CORNER);
  ok(box.innerHTML.indexOf('class="vepomenu open"') > -1, 'a znova otvorene');
  global.window.NX.setStudio({ version: '0.7.42', gen: 4, model_title: 'ENGINEtests',
                               rows: [], sheets: [], counts: {}, vepo: VEPO,
                               open_section: 'bom' });
  ok(box.innerHTML.indexOf('class="vepomenu open"') < 0,
     'review #8: deep-link do sekcie otvorene menu tiez zhasne');

  // --- review #7: sekcia Kontrola MA „Obnoviť" ------------------------------
  // Bola jedina sekcia bez neho — a pritom je to sekcia, kvoli ktorej sa clovek
  // do okna vracia po oprave v Inspectore.
  global.window.NX.setStudio({ version: '0.7.42', gen: 5, model_title: 'ENGINEtests',
                               rows: [], sheets: [], counts: {}, control: [], vepo: VEPO,
                               edge_check: { available: true, active: false, options: {}, counts: {} },
                               open_section: 'ctrl' });
  ok(box.innerHTML.indexOf('id="refreshBtn"') > -1, 'review #7: lista Kontroly ma „Obnoviť"');
  ok(box.innerHTML.indexOf('Prepočítať kontrolu z aktuálneho modelu') > -1,
     'review #7: a tooltip hovori o KONTROLE, nie o kusovniku');
  const before = sent.length;
  fire('click', tgt({ '#refreshBtn': {} }));
  eq(sent[sent.length - 1], 'refresh', 'review #7: a tlacidlo vola ZDIELANU serverovu cestu');
  ok(sent.length === before + 1, 'jedno kliknutie = jedna ziadost');
  eq(ELS.status.textContent, 'Prepočítavam kontrolu…',
     'review #7: a hlaska hovori o kontrole (REFRESH_STATUS.ctrl)');
})();

console.log(`test_st1a_studio: ${n} kontrol OK`);
