// Testy UI-D3: KLIKATELNOST — ciste funkcie warnpanelu (N5) a deep-linku do
// okna Vyroba („Štúdio"). Bez DOM: overuje sa, CO panel vykresli a CO odosle.
//
// Preco to je test a nie klikanie: riadok warnpanelu nesie kluce dielcov, ktore
// oko oznaci v modeli — zla konvencia (napr. „ziadny part_key" prelozeny na
// prazdny retazec namiesto prazdneho pola) by oznacila nieco ine, nez o com
// nalez hovori, a v modeli by to vyzeralo ako nahoda.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const NXShell = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- 1) riadky warnpanelu ----------------------------------------------------

eq(NXShell.warnRows(null), [], 'bez upozorneni sa nekresli nic');
eq(NXShell.warnRows([]), [], 'prazdne pole = prazdny panel');

const CAB_LEVEL = NXShell.warnRows([
  { code: 'rail_depth_clamped', severity: 'warn', message: 'Výstuha orezaná na 500 mm.', part_key: null }
]);
eq(CAB_LEVEL.length, 1, 'jeden nalez = jeden riadok');
eq(CAB_LEVEL[0].text, 'Výstuha orezaná na 500 mm.', 'text je serverova sprava, panel ju neprepisuje');
eq(CAB_LEVEL[0].keys, [],
   'korpusova uroven (part_key nil) = PRAZDNE kluce, teda „označ celú skrinku" ' +
   '— rovnaka konvencia ako box Skrinka v Kovani');
eq(/skrinku/.test(CAB_LEVEL[0].tip), true, 'tooltip povie, co sa oznaci');

const PART_LEVEL = NXShell.warnRows([
  { code: 'front_profile_missing', message: 'Čelo F1 bez profilu.', part_key: 'front:1' }
]);
eq(PART_LEVEL[0].keys, ['front:1'], 'part_key ide do klucov nedotknuty (nesklada sa, neseka)');
eq(/dielec/.test(PART_LEVEL[0].tip), true, 'tooltip rozlisi dielec od skrinky');

// part_key sa NIKDY neupravuje — nesie ':' aj '/' a kazda „normalizacia" by
// z neho spravila kluc ineho dielca (lekcia PartKeys.segment).
eq(NXShell.warnRows([{ message: 'x', part_key: 'zone:Z1.2/shelf:3' }])[0].keys,
   ['zone:Z1.2/shelf:3'], 'zlozeny kluc prejde bez zmeny');

// Codex #182 P2: nalez o dielci, ktory sa NIKDY nepostavil, nesmie poslat jeho
// kluc na vyber — skoncil by zarucene na "Dielec sa v modeli nenašiel".
// `part_skipped_degenerate` je presne ten pripad: plan dielec vyradil, ale kluc
// si v upozorneni ponechal, aby sa dalo povedat, ktory to bol.
const SKIPPED = NXShell.warnRows([
  { code: 'part_skipped_degenerate', message: 'Dielec Polica (Z1.2) ma nekladny rozmer — preskoceny.',
    part_key: 'zone:Z1.2/shelf:1' }
]);
eq(SKIPPED[0].keys, [], 'vyradeny dielec spadne na korpusovu uroven (oznaci sa skrinka)');
eq(/skrinku/.test(SKIPPED[0].tip), true, 'a tooltip to POVIE — nesluby o dielci, ktory neexistuje');
eq(SKIPPED[0].text, 'Dielec Polica (Z1.2) ma nekladny rozmer — preskoceny.',
   'text nalezu ostava nedotknuty — pouzivatel sa stale dozvie, o ktory dielec islo');
// Sweep review P2: plytka zona police NEPOSTAVI (`zone_tree.rb`), ale kluc
// prvej z nich si v upozorneni ponecha — kod v allowliste chybal, takze oko na
// tom riadku koncilo hlaskou „Dielec sa v modeli nenašiel".
const SHALLOW = NXShell.warnRows([
  { code: 'shelf_skipped_shallow_zone', message: 'Zona Z2: prilis plytka na police (3 ks preskocenych).',
    part_key: 'zone:Z2/shelf:1' }
]);
eq(SHALLOW[0].keys, [], 'preskocena polica spadne na korpusovu uroven (oznaci sa skrinka)');
eq(/skrinku/.test(SHALLOW[0].tip), true, 'a tooltip to POVIE');
eq(SHALLOW[0].text, 'Zona Z2: prilis plytka na police (3 ks preskocenych).',
   'text nalezu ostava nedotknuty — pouzivatel sa dozvie, o ktoru zonu islo');

// Rovnaky kluc pri INOM kode ostava cielom — vyradenie plati len pre vymenovane
// kody, nie pre kazdy nalez so zonovym klucom.
eq(NXShell.warnRows([{ code: 'rail_depth_clamped', message: 'x', part_key: 'zone:Z1.2/shelf:1' }])[0].keys,
   ['zone:Z1.2/shelf:1'], 'ostatne kody svoj dielec dalej oznacia');
eq(NXShell.warnRows([{ message: 'bez kodu', part_key: 'front:1' }])[0].keys, ['front:1'],
   'chybajuci kod = bezny nalez (nevyhadzuje sa kluc naslepo)');

// Prazdny/chybajuci text = riadok bez informacie: oko by slubilo skok a
// nepovedalo preco. Taky nalez sa nekresli.
eq(NXShell.warnRows([{ code: 'x', part_key: 'front:1' }]).length, 0, 'nalez bez textu sa zahodi');
eq(NXShell.warnRows([{ message: '', part_key: 'front:1' }]).length, 0, 'prazdny text sa zahodi');
eq(NXShell.warnRows([null, undefined, { message: 'ok' }]).length, 1, 'dier v poli sa test nezlaka');

// Poradie je poradie servera — je to zoznam nalezov, nie rebricek.
eq(NXShell.warnRows([{ message: 'a' }, { message: 'b' }]).map(r => r.text), ['a', 'b'],
   'poradie zo servera ostava');

// --- 2) deep-link na TAB okna Vyroba: ZANIKOL --------------------------------

// ST-1a: `rows`/`sheets`/`edging` zanikli — kusovnik a supisy platni a ABS su
// sekciou Kusovnik okna Studio. ŠT-1b: to iste sa stalo tabu `control`,
// ŠT-1c PR A tabu `hardware` (sekcia `buy` Studia) a ŠT-1c PR B1 POSLEDNEMU
// tabu `budget` (sekcia `budget`). ŠT-1c PR B3 zmazala okno aj celu mechaniku
// deep-linku na tab — jediny deep-link mieri na SEKCIU (nizsie).
eq(typeof NXShell.STUDIO_TABS, 'undefined', 'zoznam tabov zanikol spolu s oknom Vyroba');
eq(typeof NXShell.studioTab, 'undefined', 'a s nim aj jeho filter');
eq(typeof NXShell.studioLink, 'undefined', 'aj skladanie payloadu deep-linku na tab');

// --- 3) ST-1a: deep-link do okna STUDIO -------------------------------------

eq(NXShell.STUDIO_SECTIONS, ['bom', 'ctrl', 'buy', 'budget', 'offer', 'mat', 'hw', 'rules'],
   'zoznam sekcii je ZRKADLO StudioDialog::SECTIONS');
eq(NXShell.studioSection('bom'), 'bom', 'platna sekcia prejde');
eq(NXShell.studioSection('ctrl'), 'ctrl', 'ŠT-1b: Kontrola je ZIVA sekcia Studia (uz nie premostenie)');
eq(NXShell.studioSection('buy'), 'buy', 'ŠT-1c: Nákup kovania je ZIVA sekcia Studia (uz nie premostenie)');
eq(NXShell.studioSection('budget'), 'budget', 'ŠT-1c PR B1: Rozpočet je ZIVA sekcia Studia');
eq(NXShell.studioSection('offer'), 'offer', 'ŠT-1c PR B2: Cenová ponuka je ZIVA sekcia Studia');
eq(NXShell.studioSection('mat'), 'mat', 'ŠT-2a: Materiály su ZIVA sekcia Studia');
eq(NXShell.studioSection('hw'), 'hw', 'ŠT-3a-1: Kovanie je ZIVA sekcia Studia');
eq(NXShell.studioSection('rules'), 'rules', 'ŠT-3b-1: Pravidlá su ZIVA sekcia Studia');
eq(NXShell.studioSection('tpl'), null, 'premostenie do ineho okna NIE JE sekcia');
eq(NXShell.studioSection(''), null, 'prazdna hodnota = bez deep-linku');
eq(NXShell.studioSection(null), null, 'chybajuca hodnota = bez deep-linku');
eq(NXShell.studioSection('__proto__'), null, 'zoznam sa pyta indexOf, nie vlastnosti objektu');

eq(NXShell.studioOpenLink('bom', 'CAB-004'), { section: 'bom', anchor: 'CAB-004' },
   'N13 posiela sekciu aj kotvu (ID skrinky predvyplni hladanie)');
eq(NXShell.studioOpenLink(), { section: null, anchor: null },
   'rail Štúdio (bez argumentov) sekciu NEPREPINA');
eq(NXShell.studioOpenLink(null, 'CAB-004'), { section: null, anchor: null },
   'kotva bez sekcie nema kam sadnut — von ide null');
eq(NXShell.studioOpenLink('bom', '   '), { section: 'bom', anchor: null },
   'prazdna kotva sa nepodstrci ako filter');
eq(NXShell.studioOpenLink('nieco', 'CAB-004'), { section: null, anchor: null },
   'nezname meno sekcie sa z panela vobec nedostane von');

console.log(`test_uid3_klikatelnost: ${n} kontrol OK`);
