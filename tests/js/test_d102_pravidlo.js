// Testy D-102: „(podľa pravidla)" musi povedat, CO pravidlo vybralo.
// Zrkadlo JS strany — dependency-free Node (node tests/js/test_d102_pravidlo.js).
//
// KONTRAKT: text sklada VYHRADNE server (payloads.rb edge_rule_options /
// edge_none_option / edge_hints). JS ho iba ESCAPUJE a vlozi; ked text chyba
// (napr. hned po lokalnej zmene materialu, kym nedojde Ruby echo), pouzije sa
// NEUTRALNY zaklad — nikdy STARY vysledok pravidla.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { edgeOptionsHtml, boardEdgeOptionsHtml, edgeSideText } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- volba hrany DIELCA: serverovy text v option -------------------------------
const withRule = edgeOptionsHtml('X', '__inherit__', '(podľa pravidla — 500 SM Biela 23/1 mm)');
ok(withRule.indexOf('<option value="__inherit__">(podľa pravidla — 500 SM Biela 23/1 mm)</option>') === 0,
   'serverovy text ide do prvej volby');
ok(withRule.indexOf('<option value="">Bez ABS</option>') > 0, 'volba Bez ABS ostava');

// bez textu (lokalny regroup po zmene materialu) = neutralny zaklad
['', null, undefined].forEach(function(v){
  ok(edgeOptionsHtml('X', '__inherit__', v).indexOf('<option value="__inherit__">(podľa pravidla)</option>') === 0,
     'chybajuci text = neutralne (podľa pravidla)');
});
// stary podpis (2 argumenty) sa sprava rovnako — ziadna regresia
ok(edgeOptionsHtml('X', '__inherit__').indexOf('<option value="__inherit__">(podľa pravidla)</option>') === 0,
   'volanie bez tretieho argumentu funguje');

// vysledok „bez ABS" aj „nelepí sa" prejdu ako obycajny text
ok(edgeOptionsHtml('X', '__inherit__', '(podľa pravidla — bez ABS)').indexOf('— bez ABS)</option>') > 0,
   'bez ABS');
ok(edgeOptionsHtml('X', '__inherit__', '(podľa pravidla — nelepí sa)').indexOf('— nelepí sa)</option>') > 0,
   'nelepí sa');

// --- escapovanie: dekor s HTML znakmi nesmie rozbit select ---------------------
const nasty = edgeOptionsHtml('X', '__inherit__', '(podľa pravidla — A & B <script> "x")');
ok(nasty.indexOf('<script>') === -1, 'ziadny surovy tag v HTML');
ok(nasty.indexOf('&amp;') > 0 && nasty.indexOf('&lt;script&gt;') > 0 && nasty.indexOf('&quot;') > 0,
   'ampersand, tag aj uvodzovky su escapovane');

// --- volba hrany DOSKY: „Bez ABS" vs „Bez ABS (nelepí sa)" ---------------------
ok(boardEdgeOptionsHtml('X', '').indexOf('<option value="">Bez ABS</option>') === 0,
   'doska bez textu = obycajne Bez ABS');
ok(boardEdgeOptionsHtml('X', '', 'Bez ABS (nelepí sa)').indexOf('<option value="">Bez ABS (nelepí sa)</option>') === 0,
   'nelepitelny material to povie priamo vo volbe');
ok(boardEdgeOptionsHtml('X', '', 'A & B').indexOf('A &amp; B') > 0, 'text dosky je escapovany');
ok(boardEdgeOptionsHtml('X', '').indexOf('__inherit__') === -1,
   'doska NEMA volbu „podľa pravidla" (ziadna override vrstva)');

// --- popisok strany v 2D nahlade ----------------------------------------------
eq(edgeSideText('Predná', '23/1'), 'Predná · 23/1', 'nazov + skratka');
eq(edgeSideText('Predná', ''), 'Predná', 'bez pasky ostava holy nazov');
eq(edgeSideText('Predná', null), 'Predná', 'null skratka');
eq(edgeSideText('Predná', undefined), 'Predná', 'undefined skratka');
eq(edgeSideText(undefined, '23/1'), '23/1', 'chybajuci nazov nespravi „ · "');
eq(edgeSideText(undefined, undefined), '', 'prazdne oboje');
eq(edgeSideText('Pozdĺžna 1', '1'), 'Pozdĺžna 1 · 1', 'paska bez sirky');

console.log(`OK test_d102_pravidlo.js — ${n} kontrol`);
