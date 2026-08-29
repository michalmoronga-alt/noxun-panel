// P0-HF — DVOJKROKOVÝ EXPORT pri riadkoch bez ceny (sekcie Rozpočet + Cenová ponuka).
//
// Preco su to testy a nie klikanie:
//   1. STANDARD §11.3 hovori, ze neznama cena sa NIKDY nenahradi nulou, ale
//      rozpracovany rozpocet MUSI ostat exportovatelny. Klik teda nesmie ani
//      ticho vyrobit podhodnoteny subor, ani pouzivatelovi vystup upriet —
//      a presne tato dvojica sa klikanim overuje najhorsie.
//   2. PRVY klik export ZASTAVI a povie preco; DRUHY ho pusti s prihlaskou
//      `confirm_unpriced: <pocet>`. Je to POCET, nie `true` (review #252 P1):
//      export medzi klikmi flushne edit Inspectora a rozpocet prepocita, takze
//      neviazany boolean by potvrdil aj INY dokument. Server prijme len presnu
//      zhodu so svojim cerstvym poctom.
//   3. OZBROJENIE plati pre CISLA, KTORE POUZIVATEL VIDEL. Cerstvy payload ho
//      musi zrusit (`NX.setStudio` -> `budDisarm`), inak by potvrdenie z inej
//      sumy pustilo export nad novymi cislami.
//   4. Rozpocet a ponuka su DVA samostatne kluce — potvrdenie jedneho nesmie
//      odomknut druhy.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const STATUS = mkEl('div');
STATUS.attrs.id = 'status';
DOC.body.appendChild(STATUS);

// Most do Ruby: zachytavame, co by okno poslalo serveru.
const SENT = [];
global.sketchup = {
  budget_xlsx: function(json){ SENT.push(['budget_xlsx', JSON.parse(json)]); },
  cp_xlsx: function(json){ SENT.push(['cp_xlsx', JSON.parse(json)]); }
};
global.window.sketchup = global.sketchup;

require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const B = require(path.join(JS, 'budget.js'));
// V CEF su funkcie budget.js GLOBALY toho isteho scope ako studio.js — `NX.setStudio`
// z neho vola `budDisarm` bez prefixu. V Node ich `require` izoluje, takze sa
// zrkadlia; bez toho by sa vetva ticho preskocila a test by overoval prazdno.
global.budDisarm = B.budDisarm;

// Cerstvy push zo servera. `global.ST` je v CEF globalny payload okna (budget.js
// ho vidi ako premennu suboru nacitaneho PRED nim); v Node ho `require` izoluje,
// takze sa nastavuje rucne — presne ako v `test_st2d_kde.js`.
function push(miss){
  SENT.length = 0;
  const data = { gen: 7, model_title: 'T', version: '0.0.0',
                 budget: { totals: { total: 100, unknown_count_in_total: miss } } };
  global.ST = data;
  NX.setStudio(data);
}

// --- ciste funkcie ----------------------------------------------------------

(function pureCounts(){
  eq(B.budUnpricedCount(null), 0, 'bez payloadu niet co potvrdzovat');
  eq(B.budUnpricedCount({}), 0);
  eq(B.budUnpricedCount({ budget: {} }), 0);
  eq(B.budUnpricedCount({ budget: { totals: {} } }), 0);
  eq(B.budUnpricedCount({ budget: { totals: { unknown_count_in_total: 0 } } }), 0);
  eq(B.budUnpricedCount({ budget: { totals: { unknown_count_in_total: 3 } } }), 3);
  // pokazena hodnota sa NEHADA — ziadne varovanie je lepsie nez nahodne cislo
  eq(B.budUnpricedCount({ budget: { totals: { unknown_count_in_total: 'x' } } }), 0);
})();

(function pureText(){
  const t1 = B.budConfirmText(1, 'xlsx');
  ok(t1.indexOf('1 riadok') > -1, 'sklonovanie 1: ' + t1);
  ok(t1.indexOf('rozpočtu') > -1, t1);
  ok(t1.indexOf('PODHODNOTENÁ') > -1, t1);
  ok(t1.indexOf('ešte raz') > -1, 'hlaska MUSI ponuknut cestu von: ' + t1);
  const t5 = B.budConfirmText(5, 'cp');
  ok(t5.indexOf('5 riadkov') > -1, 'sklonovanie 5: ' + t5);
  ok(t5.indexOf('ponuky') > -1, 'ponuka hovori o svojej sume: ' + t5);
})();

// --- dvojkrokovy tok --------------------------------------------------------

(function cleanGoesStraightThrough(){
  push(0);
  B.budXlsx();
  eq(SENT.length, 1, 'bez riadkov bez ceny sa export posle HNED');
  eq(SENT[0][0], 'budget_xlsx');
  eq(SENT[0][1].confirm_unpriced, 0, 'a bez potvrdenia — netreba ho');
  eq(SENT[0][1].gen, 7, 'gen ide zo servera, nie z DOM');
})();

(function firstClickStops(){
  push(2);
  B.budXlsx();
  eq(SENT.length, 0, 'PRVY klik subor nezacne — na server sa nic neposlalo');
  ok(String(STATUS.textContent).indexOf('2 riadky') > -1, 'a povie kolko: ' + STATUS.textContent);
  eq(B.budArmed('xlsx'), 2, 'ozbrojene PRESNE tym poctom, ktory sa ukazal');
  eq(B.budArmed('cp'), 0, 'potvrdenie rozpoctu NEODOMYKA ponuku');
})();

(function secondClickSends(){
  // pokracuje po `firstClickStops` — ZAMERNE bez noveho pushu
  B.budXlsx();
  eq(SENT.length, 1, 'DRUHY klik export posle');
  // review #252 P1: posiela sa POCET, nie `true` — server prijme len presnu
  // zhodu so svojim cerstvym poctom, takze potvrdenie neplati na iny dokument.
  eq(SENT[0][1].confirm_unpriced, 2, 'a nesie POCET, ktory pouzivatel potvrdil');
})();

(function freshPayloadDisarms(){
  push(2);
  B.budXlsx();
  eq(SENT.length, 0, 'prvy klik zastavi');
  push(2); // cerstvy payload zo servera = ine cisla, potvrdenie padá
  eq(B.budArmed('xlsx'), 0, 'ozbrojenie neprezije cerstvy payload');
  B.budXlsx();
  eq(SENT.length, 0, 'takze prvy klik po pushi znova ZASTAVI');
})();

(function armIsBoundToTheCount(){
  // Priamo na `budNeedsConfirm`, bez pushu: ozbrojenie NIE JE „už raz klikol",
  // ale „potvrdil PRÁVE TOTO číslo". Keby stačil truthy príznak, iné číslo by
  // sa poslalo ako potvrdené bez toho, aby ho používateľ videl.
  B.budDisarm();
  const st2 = { budget: { totals: { unknown_count_in_total: 2 } } };
  const st5 = { budget: { totals: { unknown_count_in_total: 5 } } };
  ok(B.budNeedsConfirm('xlsx', st2), 'prvy klik nad 2 zastavi');
  eq(B.budArmed('xlsx'), 2);
  ok(!B.budNeedsConfirm('xlsx', st2), 'druhy klik nad TYM ISTYM cislom prejde');
  ok(B.budNeedsConfirm('xlsx', st5), 'ale INE cislo sa musi potvrdit ZNOVA');
  eq(B.budArmed('xlsx'), 5, 'a ozbrojenie sa prepise na nove cislo');
  ok(!B.budNeedsConfirm('xlsx', st5));
  B.budDisarm();
})();

(function changedCountReArms(){
  // Server pri rozidenych cislach export zastavi A OKNO OBNOVI. Nový payload
  // nesie INY pocet — potvrdenie sa musi pytat ZNOVA, a novym cislom.
  push(2);
  B.budXlsx();               // ozbroji na 2
  eq(B.budArmed('xlsx'), 2);
  push(5);                   // obnova zo servera: v skutocnosti ich je 5
  B.budXlsx();
  eq(SENT.length, 0, 'iny pocet = iny dokument, klik sa spotrebuje na varovanie');
  ok(String(STATUS.textContent).indexOf('5 riadkov') > -1, STATUS.textContent);
  eq(B.budArmed('xlsx'), 5, 'a ozbroji sa uz NOVYM cislom');
  B.budXlsx();
  eq(SENT.length, 1);
  eq(SENT[0][1].confirm_unpriced, 5);
})();

(function offerHasOwnKey(){
  push(1);
  B.budCpExport();
  eq(SENT.length, 0, 'ponuka ma vlastny prvy klik');
  eq(B.budArmed('cp'), 1);
  eq(B.budArmed('xlsx'), 0, 'a rozpocet ostava zamknuty');
  B.budCpExport();
  eq(SENT.length, 1);
  eq(SENT[0][0], 'cp_xlsx');
  eq(SENT[0][1].confirm_unpriced, 1);
})();

(function armingClearsWhenPriced(){
  push(1);
  B.budXlsx();               // ozbroji
  eq(B.budArmed('xlsx'), 1);
  push(0);                   // ceny doplnene
  B.budXlsx();
  eq(SENT.length, 1, 'cisty rozpocet ide priamo');
  eq(SENT[0][1].confirm_unpriced, 0, 'a uz NIC nepotvrdzuje');
})();

console.log('OK test_p0hf_potvrdenie.js — ' + n + ' kontrol');
