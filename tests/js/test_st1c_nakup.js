// Testy ŠT-1c PR A (JS zrkadlo) — sekcia NÁKUP KOVANIA v okne ŠTÚDIO (Š7).
//
// Sekcia je PRESUN tabu Kovanie okna Výroba 1:1 (Š7 zakazuje redizajn), preto
// tato sada strazi hlavne to, co by sa pri „presune" najlahsie stratilo:
//   1. KATEGORIE — riadok kategorie sa kresli LEN pri ZMENE kategorie (inak by
//      mal kazdy riadok vlastnu hlavicku) a polozka mimo katalogu ma vlastnu
//      kategoriu „MIMO KATALÓGU".
//   2. JANTAROVE (nekompletne) riadky — `missing` polozka aj zoznam „Bez kodov"
//      musia niest triedu `.hwmiss`; bez nej by sa nenacenene kovanie stratilo
//      medzi beznymi riadkami a objednalo by sa nekompletne.
//   3. CENA — nezadana cena je „—", NIKDY 0 (audit N11): nula by v objednavke
//      znamenala „zadarmo".
//   4. SERVEROVE TEXTY — `label`, `params_label`, `reason_sk` a `manual_note`
//      sklada Ruby; klient nesmie mat vlastny preklad enumu ani vlastny format.
//   5. KLIK-SELECT — riadok generiky musi niest `data-i` (index v serverovom
//      poli), inak by klik nemal ako oznacit vlastnika v modeli.
'use strict';
const assert = require('node:assert');
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

// Payload zo servera (HardwareSets.expand + ProductionCore.hardware_labeled).
const HS = {
  state_status: 'ok',
  rows: [
    { code: '9071193', name_sk: 'Záves Sensys 110°', category: 'Závesy', quantity: 4,
      unit: 'ks', price_eur_vat: 3.5, subtotal_eur_vat: 14 },
    { code: '9071194', name_sk: 'Podložka Sensys', category: 'Závesy', quantity: 4,
      unit: 'ks', price_eur_vat: null, subtotal_eur_vat: null },
    { code: '357783', name_sk: 'Atira zásuvka 620', category: 'Výsuvy', quantity: 2,
      unit: 'sada', price_eur_vat: 21.4, subtotal_eur_vat: 42.8,
      manual_note: 'ručne prepísaný počet: 2 ks (automat: 3 ks)' },
    { code: 'XX-404', missing: true, quantity: 1, unit: 'ks' }
  ],
  unmapped: [
    { generic_type: 'rail', cabinet_id: 'CAB-2', owner_part_key: 'front-1', quantity: 1,
      reason_sk: 'set nemá kód pre túto dĺžku', params_label: 'rez 597 mm' }
  ],
  summary: { total_eur_vat: 56.8, unknown_prices: 1 }
};

const HW = [
  { key: 'H1', generic_type: 'hinge', label: 'Záves', quantity: 4,
    params: { angle: '110' }, params_label: null,
    breakdown: [{ owner_id: 'CAB-1', quantity: 4 }] },
  { key: 'H2', generic_type: 'rail', label: 'Koľajnica', quantity: 2,
    params: { length: '597' }, params_label: 'rez 597 mm',
    breakdown: [{ owner_id: 'CAB-2', quantity: 2, source: 'manual',
                  manual_note: 'ručne prepísaná dĺžka (automat: 470 mm)' }] }
];

const clone = o => JSON.parse(JSON.stringify(o));

// --- 1) cena: nezadana je pomlcka, nikdy nula --------------------------------
eq(S.price(null), '—', 'nezadana cena = pomlcka (NIKDY 0 — nula znamena zadarmo)');
eq(S.price(undefined), '—', 'chybajuca cena rovnako');
eq(S.price('x'), '—', 'necislo sa neformatuje');
eq(S.price(3.5), '3,50 €', 'dve desatiny so slovenskou ciarkou');
eq(S.price(0), '0,00 €', 'ale skutocna nula zo servera sa ukaze (je to udaj, nie chybajuca cena)');

// --- 2) znamienko rucneho zasahu (D-93) --------------------------------------
eq(S.hwManualMark(null), '', 'bez zasahu ziadne znamienko');
eq(S.hwManualMark(''), '', 'prazdny text tiez nie');
const mark = S.hwManualMark('ručne prepísaný počet: 2 ks');
ok(mark.indexOf('#i-pencil') >= 0, 'sprite ikona, ziadne emoji');
ok(mark.indexOf('title="ručne prepísaný počet: 2 ks"') >= 0, 'tooltip je serverovy text bez zmeny');

// --- 3) kategorie sa kreslia LEN pri zmene -----------------------------------
const H = S.buySection(HS, HW);
eq((H.match(/class="hwcat"/g) || []).length, 3,
   'tri kategorie (Závesy · Výsuvy · MIMO KATALÓGU), nie riadok na kazdu polozku');
ok(H.indexOf('MIMO KATALÓGU') >= 0, 'polozka mimo katalogu ma vlastnu kategoriu');
ok(H.indexOf('nie je v katalógu kovania') >= 0, 'a v nazve to prizna');

// --- 4) jantarove (nekompletne) riadky ---------------------------------------
ok(H.indexOf('<tr class="hwmiss">') >= 0, 'polozka mimo katalogu je jantarovy riadok');
ok(H.indexOf('Bez kódov (1)') >= 0, 'zoznam bez kodov nesie POCET zo servera');
ok(H.indexOf('set nemá kód pre túto dĺžku · rez 597 mm') >= 0,
   'dovod aj rozmer skladá SERVER (D-90: bez rozmeru sa neda objednat)');
ok(H.indexOf('CAB-2 · front-1') >= 0, 'a vidno, na ktorom dielci to visi');
ok(H.indexOf('sekcii Kontrola') >= 0,
   'odkaz vedie do SEKCIE Kontrola (od ŠT-1b je to sekcia tohto okna, nie tab Vyroby)');

// --- 5) sucet: len zname ceny + priznany pocet nezadanych --------------------
ok(H.indexOf('SPOLU — len známe ceny (1× cena nezadaná)') >= 0,
   'sucet PRIZNA, kolko poloziek cenu nema (inak by vyzeral uplnejsie, nez je)');
ok(H.indexOf('56,80 €') >= 0, 'a samotny sucet je SERVEROVE cislo');

// --- 6) generika: serverove texty + klik-select ------------------------------
ok(H.indexOf('<tr class="hwrow" data-i="0">') >= 0,
   'riadok generiky nesie INDEX v serverovom poli (adresa pre klik-select)');
ok(H.indexOf('<tr class="hwrow" data-i="1">') >= 0, 'a to kazdy');
ok(H.indexOf('rez 597 mm') >= 0, 'params_label zo servera sa ukaze NAMIESTO surovych key/value');
ok(H.indexOf('angle 110') >= 0, 'bez params_label sa vypisu surove parametre');
ok(H.indexOf('CAB-2×2 (ručne)') >= 0, 'rucny povod vlastnika je priznany');
ok(H.indexOf('title="ručne prepísaná dĺžka (automat: 470 mm)"') >= 0,
   'a serverovy popis je v tooltipe');

// --- 7) banner poskodenych setov + prazdne stavy -----------------------------
const bad = clone(HS);
bad.state_status = 'invalid';
ok(S.buySection(bad, HW).indexOf('hwbanner') >= 0,
   'poskodene sety projektu = banner, NIKDY tichy fallback na global');

ok(S.buySection(null, []).indexOf('Nákupný zoznam sa nepodarilo zostaviť') >= 0,
   'chybajuci payload sa PRIZNA (nie prazdna tabulka, ktora vyzera ako „niet kovania")');

const empty = { state_status: 'ok', rows: [], unmapped: [], summary: {} };
ok(S.buySection(empty, []).indexOf('model nemá kovanie') >= 0,
   'prazdny model to povie rovno');
ok(S.buySection(empty, []).indexOf('Žiadne kovanie (kovanie sa počíta z pravidiel korpusov)') >= 0,
   'a to aj pri generike');

// --- 8) CSV export NIE JE v tele sekcie (presunul sa do listy) ---------------
ok(H.indexOf('hwCsvExport()') < 0 && H.indexOf('CSV kovania') < 0,
   'export patri LISTE SEKCIE (kontrakt §3), nie hlavicke tabulky');
ok(H.indexOf('Nákupný zoznam (sety)') >= 0, 'hlavicka zoznamu ostala 1:1');

console.log(`test_st1c_nakup.js: ${n} kontrol OK`);
