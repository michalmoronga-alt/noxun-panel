// SMOKE PACK 1 — ciste funkcie zoskupenia PODPERIEK POLIC (hardware.js).
// Michal 20.8.: pat polic = pat riadkov, ktore hovoria to iste. Po novom je nad
// nimi JEDEN suhrnny riadok s rozklikom; per-polica riadky (a teda editovanie
// poctu) ostavaju, len su zbalene.
//
// Testuje sa VYHRADNE rozhodovanie a texty — DOM, localStorage ani render tu
// nie su (v Node neexistuju). Dolezite je, ze zoskupenie sa DAT nedotyka:
// polozky idu do rozkliku TAKE, ake prisli.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwItemManual, hwShelfPinSummary, hwShelfCountText, hwShelfPinTitle,
        hwShelfPinTip, hwSplitShelfPins, HW_SHELF_PIN, HW_PINS_MIN, HW_PINS_KEY,
        HW_GROUP_CAB, HW_GROUP_INSIDE } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hardware.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

function pin(zone, qty, extra){
  return Object.assign({ owner_part_key: 'zone:' + zone + '/shelf:1',
                         owner_label: 'Polica ' + zone,
                         generic_type: HW_SHELF_PIN, rule_id: 'podperky-policove',
                         quantity: qty }, extra || {});
}

// --- 1) „rucne" rozhoduje JEDNO miesto (D-93 quantity_manual, stary source) --
eq(hwItemManual(null), false, 'nic nie je rucne');
eq(hwItemManual({ quantity_manual: true }), true, 'novy payload: rucne');
eq(hwItemManual({ quantity_manual: false, source: 'manual' }), false,
   'novy payload VYHRAVA nad starym polom — inak by sa panel hadal sam so sebou');
eq(hwItemManual({ source: 'manual' }), true, 'stary payload: rucne');
eq(hwItemManual({ source: 'rule' }), false, 'z pravidla');

// --- 2) suhrn: kolko polic, kolko kusov, ci do niecoho niekto siahol ---------
eq(hwShelfPinSummary([]), { rows: 0, total: 0, edited: false }, 'prazdny zoznam');
eq(hwShelfPinSummary([pin('Z1', 4), pin('Z2', 4)]), { rows: 2, total: 8, edited: false },
   'dve police po 4 ks');
eq(hwShelfPinSummary([pin('Z1', 4), pin('Z2', 4), pin('Z3', 4), pin('Z4', 4), pin('Z5', 4)]),
   { rows: 5, total: 20, edited: false }, 'Michalov pripad — 5 polic, 20 ks');
eq(hwShelfPinSummary([pin('Z1', 4), pin('Z2', 6, { quantity_manual: true })]),
   { rows: 2, total: 10, edited: true }, 'rucny zasah do jednej police vidno v suhrne');
eq(hwShelfPinSummary([pin('Z1', 4), { generic_type: 'hinge', quantity: 2 }]),
   { rows: 1, total: 4, edited: false }, 'do suhrnu patria LEN podperky');
eq(hwShelfPinSummary([pin('Z1', null), pin('Z2', 'x'), pin('Z3', 4)]),
   { rows: 3, total: 4, edited: false }, 'necitatelny pocet sa NEPOCITA (nikdy NaN v texte)');

// --- 3) texty (slovenske tvary + presne znenie zo zadania) -------------------
eq(hwShelfCountText(0), '0 políc', 'nula');
eq(hwShelfCountText(1), '1 polica', 'jednotne cislo');
eq(hwShelfCountText(2), '2 police', 'dve az styri');
eq(hwShelfCountText(4), '4 police', 'styri');
eq(hwShelfCountText(5), '5 políc', 'pat a viac');
eq(hwShelfPinTitle({ rows: 5, total: 20 }), 'Podperky políc — 5 políc: 20 ks',
   'presne znenie suhrnneho riadku');
eq(hwShelfPinTitle({ rows: 1, total: 4 }), 'Podperky políc — 1 polica: 4 ks', 'jedna polica');
eq(hwShelfPinTitle(null), 'Podperky políc — 0 políc: 0 ks', 'chybajuci suhrn nespadne');
eq(hwShelfPinTip({ rows: 2, total: 8, edited: true }).indexOf('ručne upravený počet') > 0, true,
   'tooltip prizna neStandard');
eq(hwShelfPinTip({ rows: 2, total: 8, edited: false }).indexOf('ručne') , -1,
   'bez rucneho zasahu sa nic o nom netvrdi');

// --- 4) rozdelenie: zoskupuje sa LEN vo Vnutre a az od prahu -----------------
const PINS5 = [pin('Z1', 4), pin('Z2', 4), pin('Z3', 4), pin('Z4', 4), pin('Z5', 4)];
const HINGE = { owner_part_key: 'front:F1/wing:left', generic_type: 'hinge',
                rule_id: 'zavesy', quantity: 2 };

eq(HW_PINS_MIN, 2, 'prah zoskupenia — jedna polica sa nezbaluje');

let s = hwSplitShelfPins(HW_GROUP_INSIDE, PINS5);
eq(s.pins.length, 5, 'pat polic ide do rozkliku');
eq(s.rest.length, 0, 'a mimo neho neostane nic');
eq(s.pins[0] === PINS5[0], true, 'polozky sa odovzdavaju NEZMENENE (ta ista referencia)');

s = hwSplitShelfPins(HW_GROUP_INSIDE, [pin('Z1', 4)]);
eq(s.pins.length, 0, 'jedna polica sa NEZBALUJE');
eq(s.rest.length, 1, 'ostava normalnym riadkom');

s = hwSplitShelfPins(HW_GROUP_INSIDE, [HINGE].concat(PINS5));
eq(s.rest.length, 1, 'ostatne polozky Vnutra ostavaju samostatne');
eq(s.rest[0].generic_type, 'hinge', 'a v povodnom poradi');
eq(s.pins.length, 5, 'podperky idu pod suhrn');

s = hwSplitShelfPins(HW_GROUP_CAB, PINS5);
eq(s.pins.length, 0, 'v boxe Skrinky sa nezoskupuje — suhrn patri VYHRADNE Vnutru');
eq(s.rest.length, 5, 'vsetko ostava tak, ako prislo');

s = hwSplitShelfPins('front:F1', PINS5);
eq(s.pins.length, 0, 'ani v boxe cela');

eq(hwSplitShelfPins(HW_GROUP_INSIDE, null), { pins: [], rest: [] }, 'prazdny vstup nespadne');

// --- 5) kluc localStorage je stabilny (stav rozkliku prezije prekreslenie) ---
eq(HW_PINS_KEY, 'nx_hw_shelfpins_open', 'kluc sa nemeni — inak by sa zabudlo nastavenie');

console.log('OK test_smoke1_ui.js — ' + n + ' kontrol');
