// Testy KON-0 · D-143 (JS zrkadlo) — chrbát v drážke do nárezu v plnom rozmere.
//
// Co tato sada strazi:
//   1. Karta dielca: riadok „Do nárezu" je LEN pri dielci, ktoremu server poslal
//      `cut_size` (dnes chrbat v drazke) — sadne pod Hrúbku (vpravo), karta
//      nenarastie; Dĺžka/Šírka ostavaju rozmer MODELU a tooltip to povie.
//      Vsetky texty sklada server (`Panel.part_cut_payload`) — klient nic
//      nepocita ani nepreklada.
//   2. Kontrola: akcia „Prestaviť zastarané skrinky" je LEN pri naleze, ktory
//      nesie serverovy priznak `fix: 'rebuild_stale'`.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

global.fmtmm = function (v) { return (v == null || v === '') ? '?' : Math.round(parseFloat(v)); };
global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const ROOT = path.join(__dirname, '..', '..');
const { nxPartBasicRows } = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'part_card.js'));
const S = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) karta dielca ---------------------------------------------------------
const BACK = { length: 564, width: 684, thickness: 3,
               cut_size: { length: 600, width: 720 }, cut_text: '600 × 720',
               cut_title: 'Chrbát v drážke ide do nárezu v plnom rozmere 600 × 720 mm — zrezať do drážky v dielni.',
               model_title: 'Rozmer v modeli — do nárezu ide 600 × 720 mm.' };
const r = nxPartBasicRows(BACK);
eq(r.left.length, 2, 'vlavo ostavaju dva riadky');
eq(r.right.length, 2, 'vpravo pribudol riadok — do volneho miesta pod Hrúbku (karta nenarastie)');
eq(r.right[0].label, 'Hrúbka', 'Hrúbka ostava prva');
eq(r.right[1].label, 'Do nárezu', 'pod nou „Do nárezu"');
eq(r.right[1].value, '600 × 720', 'rozmer do narezu zo servera');
eq(r.right[1].unit, 'mm', 's jednotkou');
ok(r.right[1].title.indexOf('zrezať do drážky') >= 0, 'tooltip povie, ze sa zreze v dielni');
eq([r.left[0].value, r.left[1].value], [564, 684], 'Dĺžka/Šírka = rozmer MODELU');
ok(r.left[0].title.indexOf('Rozmer v modeli') === 0, 'tooltip Dĺžky vysvetli rozdiel');
eq(r.right.some(function (x){ return !!x.click; }), false, 'riadok je informacia, nie ovladac');

const SIDE = { length: 720, width: 560, thickness: 18 };
const s = nxPartBasicRows(SIDE);
eq(s.right.length, 1, 'bez cut_size ziadny riadok navyse — karta presne ako doteraz');
eq(s.left[0].title, '', 'a bez tooltipu o narezu');
eq(nxPartBasicRows({ length: 1, width: 1, cut_size: { length: 2, width: 2 } }).right.length, 1,
   'bez hotoveho textu zo servera riadok nevznikne (klient si cislo neskladá)');

// --- 2) Kontrola: akcia prestavby ---------------------------------------------
const STALE = { severity: 'red', category: 'back_cut', owner_id: 'CAB-1', fix: 'rebuild_stale',
                message_sk: 'Skrinka CAB-1 má chrbát v drážke zo staršej verzie', stable_key: 'back_cut|x' };
const acts = S.ctrlActionsHtml(STALE);
ok(acts.indexOf('data-act="rebuild"') >= 0, 'zastarana skrinka ponukne prestavbu');
ok(acts.indexOf('data-act="eye"') >= 0 && acts.indexOf('data-act="edit"') >= 0, 'oko a ceruzka ostavaju');
const EDGED = { severity: 'red', category: 'back_cut', owner_id: 'CAB-2', message_sk: 'olepená hrana',
                stable_key: 'back_cut|y' };
ok(S.ctrlActionsHtml(EDGED).indexOf('data-act="rebuild"') < 0, 'bez serveroveho priznaku ziadna prestavba');
ok(S.ctrlActionsHtml(Object.assign({}, STALE, { category: 'material' })).indexOf('data-act="rebuild"') < 0,
   'priznak mimo kategorie back_cut sa ignoruje');
ok(S.ctrlRowHtml(STALE, 0).indexOf('data-act="rebuild"') >= 0, 'riadok Kontroly akciu nesie');

console.log(`OK test_kon0_do_narezu.js — ${n} kontrol`);
