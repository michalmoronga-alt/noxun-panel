// UI-B1 — kostra Inspectora: stavovy stroj VYBER x KONTEXT + zbalenia sektorov
// a skupin (dependency-free Node: node tests/js/test_uib1_kostra.js).
//
// Co sa tu strazi (audit A1/A5/A10):
//   1) identita vyberu — retazec nesie REZIM AJ ID, takze cab -> dielec tej
//      istej skrinky je spravne NOVA identita,
//   2) NOVA identita resetuje viewContext na 'korpus'; ECHO push tej istej
//      identity kontext NEMENI (rozpisana praca a otvorene skupiny preziju),
//   3) kontexty su platne LEN nad oznacenym korpusom — pri dielci, doske aj
//      vkladani su neaktivne a klik NEROBI NIC (guard, nie CSS),
//   4) kluce zbalenia: sektory nezavisle, skupiny S4 kvalifikovane kontextom,
//   5) exkluzivita skupin V RAMCI JEDNEHO kontextu S4 (vratane vynimky solo).
//
// shell.js exportuje ciste jadro (NXShell); DOM cast sa v Node nikdy nevolá
// — rovnaky vzor ako insert_state.js a usage.js.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const NXShell = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.strictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function deq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
// Kazdy scenar zacina z ciasteho stavu (modul je singleton).
function reset(){
  NXShell.track('insert', NXShell.identityOf('insert', null));
}

// ---------------------------------------------------------------- identita ---
// Identita nesie REZIM, ID aj DOKUMENT (Codex #168 P2): ID su jedinecne len
// v ramci modelu, takze dva otvorene dokumenty bezne obsahuju CAB-001 aj BRD-001.
const G1 = 'guid-A', G2 = 'guid-B';
eq(NXShell.identityOf('cab', { cabinet_id: 'CAB-005', model_guid: G1 }), 'guid-A|cab:CAB-005',
  'identita korpusu nesie dokument');
eq(NXShell.identityOf('part', { cabinet_id: 'CAB-005', role_key: 'side_left', model_guid: G1 }),
  'guid-A|part:CAB-005/side_left', 'identita dielca nesie skrinku AJ rolu');
eq(NXShell.identityOf('board', { board_id: 'BRD-003', model_guid: G1 }), 'guid-A|board:BRD-003',
  'identita dosky');
eq(NXShell.identityOf('insert', null), 'none', 'vkladanie nema identitu');
// Rovnake ID v inom rezime NIE je ta ista identita.
assert.notStrictEqual(NXShell.identityOf('cab', { cabinet_id: 'CAB-005', model_guid: G1 }),
  NXShell.identityOf('part', { cabinet_id: 'CAB-005', role_key: 'side_left', model_guid: G1 }));
n++;
// Rovnake ID v INOM DOKUMENTE tiez NIE je ta ista identita — inak by prepnutie
// dokumentu vyzeralo ako echo push a kontext by sa neresetoval.
assert.notStrictEqual(NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: G1 }),
  NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: G2 }));
n++;
reset();
NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: G1 }));
NXShell.setCtx('kovanie');
eq(NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: G1 })), false,
  'echo push v tom istom dokumente');
eq(NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: G2 })), true,
  'rovnake ID v INOM dokumente = nova identita');
eq(NXShell.effectiveCtx(), 'korpus', 'prepnutie dokumentu resetuje kontext na Korpus');

// ------------------------------------------------- matica rezim x kontext ---
// none/insert: kontexty neaktivne, prepnutie NEROBI NIC
reset();
eq(NXShell.ctxEnabled(), false, 'vkladanie: kontexty neaktivne');
eq(NXShell.setCtx('zony'), false, 'vkladanie: klik na Zony sa ignoruje');
eq(NXShell.effectiveCtx(), 'korpus', 'vkladanie: zobrazuje sa Korpus');

// cab: kontexty aktivne
eq(NXShell.track('cab', 'cab:CAB-005'), true, 'prvy vyber korpusu = nova identita');
eq(NXShell.ctxEnabled(), true, 'korpus: kontexty aktivne');
eq(NXShell.effectiveCtx(), 'korpus', 'novy vyber startuje na Korpuse');
eq(NXShell.setCtx('cela'), true, 'prepnutie na Cela prejde');
eq(NXShell.effectiveCtx(), 'cela', 'kontext je Cela');
eq(NXShell.setCtx('cela'), false, 'to iste znova = ziadna zmena (bez zbytocneho prekreslenia)');
eq(NXShell.setCtx('nezmysel'), true, 'neznamy kontext spadne na Korpus');
eq(NXShell.effectiveCtx(), 'korpus', 'fallback je Korpus');

// ECHO push tej istej identity — kontext DRZI
NXShell.setCtx('kovanie');
eq(NXShell.track('cab', 'cab:CAB-005'), false, 'echo push tej istej skrinky NIE je nova identita');
eq(NXShell.effectiveCtx(), 'kovanie', 'echo push kontext NEMENI');
eq(NXShell.track('cab', 'cab:CAB-005'), false, 'opakovany echo push (auto-apply) tiez nie');
eq(NXShell.effectiveCtx(), 'kovanie', 'ani opakovany echo kontext nezhodi');

// INA skrinka — reset na Korpus
eq(NXShell.track('cab', 'cab:CAB-009'), true, 'ina skrinka = nova identita');
eq(NXShell.effectiveCtx(), 'korpus', 'nova skrinka startuje na Korpuse');

// cab -> part: kontexty zosednu, prepnutie NEROBI NIC
NXShell.setCtx('zony');
eq(NXShell.track('part', 'part:CAB-009/side_left'), true, 'dielec tej istej skrinky = nova identita');
eq(NXShell.ctxEnabled(), false, 'dielec: kontexty neaktivne');
eq(NXShell.setCtx('zony'), false, 'dielec: klik na kontext sa ignoruje');
eq(NXShell.effectiveCtx(), 'korpus', 'dielec: zobrazuje sa Korpus');
// echo push dielca (napr. po zmene ABS hrany) identitu nemeni
eq(NXShell.track('part', 'part:CAB-009/side_left'), false, 'echo push dielca nie je nova identita');
// iny dielec tej istej skrinky JE nova identita
eq(NXShell.track('part', 'part:CAB-009/side_right'), true, 'iny dielec = nova identita');

// part -> cab (krizik / omrvinka): opat Korpus a kontexty aktivne
eq(NXShell.track('cab', 'cab:CAB-009'), true, 'navrat na skrinku = nova identita');
eq(NXShell.ctxEnabled(), true, 'navrat: kontexty aktivne');
eq(NXShell.effectiveCtx(), 'korpus', 'navrat startuje na Korpuse');

// board
eq(NXShell.track('board', 'board:BRD-003'), true, 'doska = nova identita');
eq(NXShell.ctxEnabled(), false, 'doska: kontexty neaktivne');
eq(NXShell.setCtx('cela'), false, 'doska: klik na kontext sa ignoruje');
eq(NXShell.track('board', 'board:BRD-003'), false, 'echo push dosky nie je nova identita');
eq(NXShell.track('insert', 'none'), true, 'zrusenie vyberu = nova identita (vkladanie)');
eq(NXShell.track('insert', 'none'), false, 'echo push vkladania nie je nova identita');

// ------------------------------- identita pre asynchronne callbacky (#168) ---
// Krizik dosky posiela board_id — server ho porovna s tym, co je NAOZAJ vybrate
// (kym callback dobehne, mohol pouzivatel oznacit nieco ine).
reset();
NXShell.track('board', NXShell.identityOf('board', { board_id: 'BRD-003', model_guid: G1 }));
eq(NXShell.identityId(), 'BRD-003', 'z identity dosky sa da vytiahnut ciste ID');
eq(NXShell.identityGuid(), G1, 'a k nemu dokument');
NXShell.track('cab', NXShell.identityOf('cab', { cabinet_id: 'CAB-005', model_guid: G2 }));
eq(NXShell.identityId(), 'CAB-005', 'z identity korpusu tiez');
eq(NXShell.identityGuid(), G2, 'dokument korpusu');
NXShell.track('part', NXShell.identityOf('part', { cabinet_id: 'CAB-005', role_key: 'cabinet/side:left', model_guid: G1 }));
eq(NXShell.identityId(), 'CAB-005/cabinet/side:left', 'dielec nesie skrinku aj rolu (dvojbodky v roli prezijú)');
NXShell.track('insert', NXShell.identityOf('insert', null));
eq(NXShell.identityId(), '', 'vkladanie nema co poslat');
eq(NXShell.identityGuid(), '', 'ani dokument');

// --------------------- viditelnost S2/S3 + kontextovy riadok (fix 18.8.) -----
// PRECO to matica nechytila doteraz: testovala VYHRADNE stavovy stroj (rezim,
// identita, echo/nova, kluce zbaleni) — o tom, CO sa pri danom stave zobrazi,
// nevedela nic. Viditelnost sektorov zila len v CSS a UI-B1 do nej dala mapu
// pre REZIM VYBERU (part/board/insert), nie pre KONTEXT raily; kontrakt „S2/S3
// patria Korpusu + tenky kontextovy riadok inde" tak vypadol ticho a ziadny
// test o nom nevedel. Odteraz je pravidlo CISTA funkcia NXShell.sectorVis
// (CSS je jej zrkadlo — zhodu strazi tests/pure/test_uib1_kostra.rb).
function vis(mode, ctx){ return NXShell.sectorVis(mode, ctx); }

// Oznaceny korpus: Korpus ukazuje sektory, ostatne kontexty kontextovy riadok.
deq(vis('cab', 'korpus'), { basic: true, mat: true, note: false },
  'Korpus: Zakladne aj Materialy su na mieste, riadok netreba');
['zony', 'cela', 'kovanie'].forEach(function(c){
  deq(vis('cab', c), { basic: false, mat: false, note: true },
    'kontext ' + c + ': S2/S3 skryte, namiesto nich kontextovy riadok');
});
// Neznamy kontext padne na Korpus (rovnaky fallback ako normCtx).
deq(vis('cab', 'nezmysel'), { basic: true, mat: true, note: false },
  'neznamy kontext sa sprava ako Korpus');

// NEZMENENE: dielec a doska maju vlastnu kartu — sektory ani riadok nemaju co
// robit; vkladanie ukazuje vkladaciu kartu aj materialy (Codex #168 P2).
['part', 'board'].forEach(function(m){
  deq(vis(m, 'korpus'), { basic: false, mat: false, note: false },
    m + ': ziadne korpusove sektory ani riadok');
  deq(vis(m, 'kovanie'), { basic: false, mat: false, note: false },
    m + ': kontext sa na to nesmie pytat (rail je aj tak neaktivny)');
});
deq(vis('insert', 'korpus'), { basic: true, mat: true, note: false },
  'vkladanie: vkladacia karta aj materialy ostavaju');
deq(vis('insert', 'cela'), { basic: true, mat: true, note: false },
  'vkladanie: kontext je neplatny, sektory drzia (effectiveCtx je Korpus)');

// Bez argumentov cita ZIVY stav — presne tak ju vola nxShellApply.
reset();
NXShell.track('cab', 'cab:CAB-007');
deq(vis(), { basic: true, mat: true, note: false }, 'zivy stav: novy vyber startuje na Korpuse');
NXShell.setCtx('cela');
deq(vis(), { basic: false, mat: false, note: true }, 'zivy stav: po prepnuti na Cela');

// ------------------------------------------- text kontextoveho riadku -------
// Rozmery aj popis materialu prichadzaju z payloadu — panel nic nedopocitava.
eq(NXShell.ctxNoteText({ w: 900, h: 720, d: 560 }, 'K2738 MO'), '900 × 720 × 560 · K2738 MO',
  'suhrn skrinky: rozmery + dekor');
eq(NXShell.ctxNoteText({ w: 900.4, h: 719.6, d: 560 }, ''), '900 × 720 × 560',
  'rozmery su cele mm; bez materialu ostanu same');
eq(NXShell.ctxNoteText({ w: 900, h: 0, d: 560 }, 'K2738 MO'), 'K2738 MO',
  'nekompletne rozmery sa VYNECHAJU (radsej nic nez vymyslene cislo)');
eq(NXShell.ctxNoteText(null, ''), '—', 'bez dat ostane pomlcka');
eq(NXShell.ctxNoteText({ w: 'x', h: 'y', d: 'z' }, '  '), '—', 'nezmysly sa nezobrazia');

// --------------------------------------------- kluce zbalenia (A5) ----------
eq(NXShell.secKey('s1', null), 'nxsec_s1', 'sektor ma vlastny nezavisly kluc');
eq(NXShell.secKey('s4', null), 'nxsec_s4', 'sektor S4 je nezavisly od svojich skupin');
eq(NXShell.secKey('top', 'korpus'), 'nxsec_s4.korpus.top', 'skupina S4 je kvalifikovana kontextom');
eq(NXShell.secKey('zones', 'zony'), 'nxsec_s4.zony.zones', 'skupina ineho kontextu ma iny kluc');
assert.notStrictEqual(NXShell.secKey('top', 'korpus'), NXShell.secKey('top', 'cela'));
n++;

// ------------------------------------------- exkluzivita skupin S4 (A5) -----
const groups = [
  { key: 's1', s4: null, solo: false, open: true },   // sektory — mimo exkluzivity
  { key: 's4', s4: null, solo: false, open: true },
  { key: 'top', s4: 'korpus', solo: false, open: true },
  { key: 'bottom', s4: 'korpus', solo: false, open: true },
  { key: 'sides', s4: 'korpus', solo: false, open: false },
  { key: 'back', s4: 'korpus', solo: false, open: true },
  { key: 'zones', s4: 'zony', solo: true, open: true }, // strom zon — vynimka
  { key: 'fronts', s4: 'cela', solo: false, open: true }
];
deq(NXShell.exclusiveClose(groups, 'top'), ['bottom', 'back'],
  'otvorenie skupiny zavrie OTVORENYCH surodencov toho isteho kontextu');
deq(NXShell.exclusiveClose(groups, 'fronts'), [],
  'jedina skupina kontextu nema koho zatvarat');
deq(NXShell.exclusiveClose(groups, 'zones'), [],
  'solo skupina (strom zon) nikoho nezatvara');
deq(NXShell.exclusiveClose(groups, 's4'), [],
  'sektor NIE JE skupina — sektory su nezavisle a navzajom sa nezatvaraju');
deq(NXShell.exclusiveClose(groups, 's1'), [],
  'sektor Nahlad nezatvara sektor Nastavenia');
deq(NXShell.exclusiveClose(groups, 'neznamy'), [], 'neznamy kluc nic nezavrie');
deq(NXShell.exclusiveClose(null, 'top'), [], 'prazdny vstup nespadne');
// solo skupina sa NEZATVARA ani ked sa otvori iny surodenec toho isteho kontextu
const zonySkupiny = [
  { key: 'zones', s4: 'zony', solo: true, open: true },
  { key: 'zonecfg', s4: 'zony', solo: false, open: true },
  { key: 'zonemore', s4: 'zony', solo: false, open: true }
];
deq(NXShell.exclusiveClose(zonySkupiny, 'zonecfg'), ['zonemore'],
  'solo skupina prezije otvorenie ineho surodenca');

// ------- perzistencia zbalení cez echo push: track sa pamate zbalení NEDOTYKA
// (kluce ostavaju rovnake a stav skupin zije v localStorage, nie v NXShell).
const preKey = NXShell.secKey('top', 'korpus');
NXShell.track('cab', 'cab:CAB-100');
NXShell.setCtx('cela');
NXShell.track('cab', 'cab:CAB-100'); // echo
eq(NXShell.secKey('top', 'korpus'), preKey, 'echo push nemeni kluce zbalenia');
eq(NXShell.effectiveCtx(), 'cela', 'echo push nemeni ani kontext');

console.log(JSON.stringify({ passed: n, failed: 0 }));
