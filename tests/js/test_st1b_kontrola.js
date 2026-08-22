// Testy ŠT-1b (JS zrkadlo) — sekcia KONTROLA v okne ŠTÚDIO (Š8–Š11).
//
// Co tato sada strazi (a preco to klikanim neoveris):
//   1. SEMAFOR ukazuje VYHRADNE serverove cisla — vratane zeleneho „skriniek
//      bez nalezu". Keby si klient cokolvek dopocital, Kontrola by hlasila ine
//      cislo nez ⚠ chip Inspectora a nez suhrn v LOGu exportu.
//   2. FILTER je cisto zobrazovaci: LEN skryva, nikdy nepreusporadúva ani
//      neprepocitava (poradie urcuje server) a druhy klik ho zrusi.
//   3. Riadok nesie STABILNY kluc problemu a spravne AKCIE — kontextova oprava
//      je tam, kde naozaj existuje (UNI / rozpocet), inak len oko a ceruzka.
//   4. Badge navigacie (Š11) ide z TYCH ISTYCH counts ako semafor.
//   5. 3-stavove nastavenie je TRETIA INSTANCIA zdielaneho komponentu — nie
//      tretia kopia (zhodu markupu s railom strazi test_abs_rail_3stav.js).
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const ROOT = path.join(__dirname, '..', '..');
const S = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function no(cond, msg){ n++; assert.ok(!cond, msg); }

const ITEMS = [
  { severity: 'red', category: 'material', owner_id: 'CAB-001', message_sk: 'Materiál mimo katalógu',
    stable_key: 'material|CAB-001|bok_l' },
  { severity: 'red', category: 'thickness', owner_id: 'CAB-002', message_sk: 'Hrúbka nesedí',
    stable_key: 'thickness|CAB-002|polica' },
  { severity: 'orange', category: 'uni_material', owner_id: 'CAB-003', uni_id: 'UNI-KORPUS',
    message_sk: 'Materiál neurčený (UNI)', stable_key: 'uni_material|CAB-003|' },
  { severity: 'orange', category: 'budget', owner_id: null, budget_section: 'services',
    message_sk: 'Rozpočet: montáž bez sadzby', stable_key: 'budget|services|rate' }
];
const COUNTS = { red: 2, orange: 2, total: 4, cabinets: 20, clean: 17 };

// --- 1) semafor: cisla LEN zo servera, RED/ORANGE su filtre ------------------
(function(){
  const h = S.semaforHtml(COUNTS, 'all');
  ok(h.indexOf('class="semafor"') >= 0, 'semafor je jeden riadok troch chipov');
  ok(h.indexOf('data-sev="red"') >= 0, 'cerveny chip je KLIKATELNY filter');
  ok(h.indexOf('data-sev="orange"') >= 0, 'oranzovy chip tiez');
  no(h.indexOf('data-sev="green"') >= 0, 'zeleny chip je INFORMACNY — niet co filtrovat');
  ok(h.indexOf('blokuje výrobu') >= 0, 'cerveny chip hovori, co znamena');
  ok(h.indexOf('skontroluj pred objednávkou') >= 0, 'oranzovy tiez');
  ok(h.indexOf('skriniek bez nálezu') >= 0, 'zeleny nesie serverove cislo skriniek');
  ok(h.indexOf('>17<') >= 0, 'zelene cislo je PRESNE to zo servera (counts.clean)');
  ok(h.indexOf('>2<') >= 0, 'a cervene/oranzove tiez');

  const on = S.semaforHtml(COUNTS, 'red');
  ok(on.indexOf('class="schip s-red on"') >= 0, 'zapnuty filter je vidno na chipe');
  ok(on.indexOf('aria-pressed="true"') >= 0, 'a je to aj pre citacku');

  // Starsi payload (bez zeleneho cisla) sa PRIZNA pomlckou — klient si pocet
  // skriniek nikdy nedopocitava zo zoznamu nalezov.
  const noClean = S.semaforHtml({ red: 1, orange: 0, total: 1 }, 'all');
  ok(noClean.indexOf('—') >= 0, 'chybajuce zelene cislo = pomlcka, nie vymysleny pocet');
})();

// --- 2) filter LEN skryva (poradie urcuje server) ----------------------------
(function(){
  const all = S.ctrlRows(ITEMS, 'all');
  eq(all.length, 4, 'bez filtra su vsetky nalezy');
  eq(all.map(function(p){ return p[1]; }), [0, 1, 2, 3], 'poradie je serverove — klient netriedi');

  const red = S.ctrlRows(ITEMS, 'red');
  eq(red.length, 2, 'cerveny filter necha len RED');
  eq(red.map(function(p){ return p[0].severity; }), ['red', 'red'], 'a naozaj len RED');
  // Index musi ostat INDEXOM V SERVEROVOM ZOZNAME, inak by klik pri zapnutom
  // filtri adresoval iny nalez.
  eq(S.ctrlRows(ITEMS, 'orange').map(function(p){ return p[1]; }), [2, 3],
     'index ukazuje do POVODNEHO zoznamu, nie do vyfiltrovaneho');
  eq(S.ctrlRows([], 'red').length, 0, 'prazdny zoznam nezhodi filter');
  eq(S.ctrlRows(null, 'all').length, 0, 'chybajuci zoznam tiez nie');
})();

// --- 3) riadok nalezu: kluc, miesto a AKCIE ---------------------------------
(function(){
  const red = S.ctrlRowHtml(ITEMS[0], 0);
  ok(red.indexOf('class="ctrlrow ctrl-red"') >= 0, 'zavaznost je vidiet na riadku');
  ok(red.indexOf('data-ci="0"') >= 0, 'riadok nesie adresu do serveroveho zoznamu');
  ok(red.indexOf('Materiál mimo katalógu') >= 0, 'text nálezu skladá SERVER');
  ok(red.indexOf('CAB-001') >= 0, 'miesto (vlastník) je v riadku');
  ok(red.indexOf('data-act="eye"') >= 0, 'oko = označ v modeli');
  ok(red.indexOf('data-act="edit"') >= 0, 'ceruzka = označ + Inspector dopredu');
  no(red.indexOf('data-act="uni"') >= 0, 'bezny nalez NEMA kontextovu opravu');

  const uni = S.ctrlRowHtml(ITEMS[2], 2);
  ok(uni.indexOf('data-act="uni"') >= 0, 'UNI nalez PONUKA „Nahradiť UNI…"');
  ok(uni.indexOf('data-uni="UNI-KORPUS"') >= 0, 'a nesie ID materialu zo SERVERA');
  ok(uni.indexOf('#i-arrow-left-right') >= 0, 'ikona zo spritu (ziadne emoji)');

  // UNI nalez bez `uni_id` (starsi payload) skratku NEPONUKNE — inak by klik
  // otvoril modal nad nicim.
  const uniNoId = S.ctrlRowHtml({ severity: 'orange', category: 'uni_material',
                                  owner_id: 'CAB-9', message_sk: 'x', stable_key: 'k' }, 9);
  no(uniNoId.indexOf('data-act="uni"') >= 0, 'bez uni_id sa skratka nekresli');

  const bud = S.ctrlRowHtml(ITEMS[3], 3);
  ok(bud.indexOf('Rozpočet') >= 0, 'rozpoctovy nalez NEMA entitu — miesto je „Rozpočet"');
  ok(bud.indexOf('data-act="budget"') >= 0, 'a ma vlastnu akciu (premostenie)');
  ok(bud.indexOf('okne Výroba') >= 0, 'tooltip PRIZNA, ze Rozpocet je zatial v okne Vyroba');
  no(bud.indexOf('data-act="eye"') >= 0, 'oko pri nom nie je — niet co oznacit');
})();

// --- 4) badge navigacie ide z TYCH ISTYCH counts -----------------------------
(function(){
  const b = S.navBadgeHtml(COUNTS);
  ok(b.indexOf('class="nbadge"') >= 0, 'badge existuje');
  ok(b.indexOf('<i class="r">2</i>') >= 0, 'cervene cislo sedi so semaforom');
  ok(b.indexOf('<i class="o">2</i>') >= 0, 'oranzove tiez');
  eq(S.navBadgeHtml({ red: 0, orange: 0, total: 0 }), '', 'cista zakazka badge NEKRESLI');
  eq(S.navBadgeHtml(null), '', 'chybajuce counts badge nezhodia');
  ok(S.navBadgeHtml({ red: 0, orange: 3 }).indexOf('class="r"') < 0,
     'bez cervenych sa cervena znacka nekresli (nula nie je nalez)');

  // Navigacna polozka Kontrola musi mat priznak badge, inak by cisla nemal kto
  // vykreslit; a NESMIE byt premostenim (obsah je uz tu).
  const it = S.navItem('ctrl');
  ok(it && it.badge === true, 'polozka Kontrola nesie zive pocty');
  no(it.bridge, 'a uz NIE JE premostenim do okna Vyroba');
  ok(S.STUDIO_SECTIONS.indexOf('ctrl') >= 0, 'je to ZIVA sekcia tohto okna');
})();

// --- 5) lista sekcie: prepinace a ich payload --------------------------------
(function(){
  const EDGE = { available: true, active: true,
                 options: { show_missing: true, show_extra: false, show_taped: false,
                            taped_selected_only: true },
                 counts: { missing: 3, extra: 9, taped: 40 } };
  const bar = S.edgeCheckBarHtml(EDGE, false, { available: true, active: false });
  ok(bar.indexOf('data-ec="toggle"') >= 0, 'telo tlacidla prepina zvyraznenie');
  ok(bar.indexOf('data-ec="menu"') >= 0, 'roh otvara 3-stavove nastavenie (vlastna akcia)');
  ok(bar.indexOf('data-gc="toggle"') >= 0, 'druhy prepinac je smer kresby');
  ok(bar.indexOf('ecmenu-studio') >= 0, 'okno nastavenia ma polohu PRI TOMTO tlacidle');

  // Payload je LEN identita — o prepnuti aj o zapise rozhoduje server.
  eq(S.edgeCheckPayload({ gen: 4, model_guid: 'G-7' }), { gen: 4, model_guid: 'G-7' },
     'prepinac posiela iba identitu okna a dokumentu');
  eq(S.edgeCheckOptionPayload({ gen: 4, model_guid: 'G-7' }, 'show_taped', true),
     { gen: 4, model_guid: 'G-7', key: 'show_taped', value: true },
     'nastavenie posiela identitu + kluc + STRIKTNY boolean');
})();

// --- 6) zdroje pravdy: klient si NIC neprepocitava ---------------------------
(function(){
  const src = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'), 'utf8');
  // Zelene cislo semaforu nesmie vzniknut v prehliadaci (odcitanim vlastnikov
  // od poctu skriniek) — to je serverovy vypocet vo `Validation.counts`.
  no(/counts\.cabinets\s*-/.test(src), 'zelene cislo sa v JS NEDOPOCITAVA');
  no(/\.filter\([^)]*owner_id[^)]*\)\.length/.test(src), 'ani cez pocitanie vlastnikov');
  // Klik na nalez posiela STABILNY kluc (nie pids — rebuild ich meni).
  ok(src.indexOf('problem_key: key') >= 0, 'klik posiela stabilny kluc problemu');
  no(src.indexOf('pids:') >= 0, 'nikdy pids — po flushi editov by uz neplatili');
})();

console.log(`test_st1b_kontrola.js: ${n} testov OK`);
