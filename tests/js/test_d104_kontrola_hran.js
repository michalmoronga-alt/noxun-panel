// Testy D-104 (JS zrkadlo) — prepinac „Zvyraznit hrany bez olepu".
// ŠT-1b: prepinac sa presunul z tabu KONTROLA okna Vyroba do LISTY SEKCIE
// Kontrola v okne STUDIO, preto tato sada testuje studio.js.
// JS je LEN zobrazenie: pocet, dostupnost aj zapnutost nesie SERVER; klient si nic
// neprepocitava a do Ruby posiela iba identitu (gen + model_guid), nikdy stav.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// studio.js sa v prehliadaci vesa na window/document — pre node stacia tenke
// atrapy (subor okrem toho pri nacitani nic nerobi).
global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const P = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'studio.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- sklonovanie poctu hran ---------------------------------------------------
eq(P.edgePluralSk(1), 'hrana', '1 = hrana');
eq(P.edgePluralSk(2), 'hrany', '2 = hrany');
eq(P.edgePluralSk(4), 'hrany', '4 = hrany');
eq(P.edgePluralSk(5), 'hrán', '5 = hran');
eq(P.edgePluralSk(21), 'hrán', '21 = hran (bez vynimiek)');

// --- text stavu ---------------------------------------------------------------
// D-105: stav uz nesie 'options' + 'counts' (pocty per stav). Skalarny 'count'
// ostava v payloade kvoli kompatibilite, ale text sa sklada z 'counts'.
const RED_ONLY = { show_missing: true, show_extra: false, show_taped: false, taped_selected_only: true };
function red(n, extra){
  return Object.assign({ available: true, active: true, options: RED_ONLY,
                         counts: { missing: n, extra: 0, taped: 0 } }, extra || {});
}

eq(P.edgeCheckText(null), 'Vypnuté — v modeli nie je nič nakreslené.', 'bez stavu = vypnute');
eq(P.edgeCheckText({ available: true, active: false }),
   'Vypnuté — v modeli nie je nič nakreslené.', 'vypnute povie, ze v modeli nic nie je');
eq(P.edgeCheckText(red(0)),
   'Všetky hrany podľa pravidla sú olepené.', 'nula = ciste (Michalov cielovy stav)');
eq(P.edgeCheckText(red(1)), '1 hrana bez olepu', 'jedna hrana');
eq(P.edgeCheckText(red(7)), '7 hrán bez olepu', 'sedem hran');
ok(P.edgeCheckText(red(7, { unresolved: 2 })).indexOf('2 sa nedá zvýrazniť') >= 0,
   'nezvyraznitelne hrany sa PRIZNAJU (nie tiche mlcanie)');
ok(P.edgeCheckText(red(3, { multi: 1 })).indexOf('nakreslený raz') >= 0,
   'dielec s viac kusmi je v modeli nakresleny raz — text to povie');

// --- lista prepinaca ----------------------------------------------------------
(function(){
  const off = P.edgeCheckBarHtml({ available: true, active: false, options: RED_ONLY }, false);
  ok(off.indexOf('Zvýrazniť hrany') >= 0, 'tlacidlo nesie nazov akcie');
  ok(off.indexOf('#i-eye') >= 0, 'ikona zo spritu (ziadne emoji)');
  ok(off.indexOf('aria-pressed="false"') >= 0, 'vypnuty stav je aj pre citacku');
  ok(off.indexOf('class="ecbtn"') >= 0, 'vypnute tlacidlo nema triedu on');

  const on = P.edgeCheckBarHtml(red(2), false);
  ok(on.indexOf('class="ecbtn on"') >= 0, 'zapnuty stav je ZJAVNY (trieda on)');
  ok(on.indexOf('#i-eye-off') >= 0, 'zapnute tlacidlo ponuka vypnutie');
  ok(on.indexOf('aria-pressed="true"') >= 0, 'zapnuty stav je aj pre citacku');
  ok(on.indexOf('2 hrany bez olepu') >= 0, 'pocet zo servera je v liste');

  const na = P.edgeCheckBarHtml({ available: false }, false);
  ok(na.indexOf('SketchUp 2023') >= 0, 'stary SketchUp dostane vetu, nie mrtve tlacidlo');
  ok(na.indexOf('<button') < 0, 'bez Overlay API sa tlacidlo vobec nezobrazi');
  ok(P.edgeCheckBarHtml(null, false).indexOf('SketchUp 2023') >= 0, 'chybajuci stav = nedostupne');
})();

// --- payload do Ruby ----------------------------------------------------------
eq(P.edgeCheckPayload({ gen: 12, model_guid: 'G-1' }), { gen: 12, model_guid: 'G-1' },
   'posiela sa LEN identita (gen + model_guid) — stav urcuje server');
eq(P.edgeCheckPayload(null), { gen: 0, model_guid: '' }, 'bez dat sa nepada');
eq(P.edgeCheckPayload({ gen: 5 }), { gen: 5, model_guid: '' }, 'chybajuci guid = prazdny');
ok(Object.keys(P.edgeCheckPayload({ gen: 1, model_guid: 'G' })).indexOf('active') < 0,
   'klient NEPOSIELA pozadovany stav — o prepnuti rozhoduje server');

console.log(`test_d104_kontrola_hran.js: ${n} testov OK`);
