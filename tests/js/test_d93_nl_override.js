// Testy D-93 (JS zrkadlo) — rucny override nominalnej dlzky vysuvu.
//
// JS je LEN zobrazenie: zamok, rad hodnot aj „co by dal automat" prichadzaju zo
// SERVERA (blok `nl` v polozke kovania). Klient si nic neprepocitava a do Ruby
// posiela vzdy identitu riadku + pole/hodnotu (o platnosti rozhoduje server).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// hwNlHtml a hwPayload siahaju po globalnych helperoch panela — v CEF su z
// core.js/icons.js, tu ich podstrcime (zhodne spravanie, ziadna logika navyse).
global.esc = s => String(s == null ? '' : s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.NXIcons = { svg: name => `<svg data-icon="${name}"></svg>` };

const H = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hardware.js'));

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const P = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'production.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const SERIES = [260, 300, 350, 420, 470, 520, 560, 620];
function nl(over){
  return Object.assign({ series: SERIES, value: 470, locked: false, auto: 470, auto_known: true }, over || {});
}
function flat(list){ return list.map(o => [o.value, o.text, o.selected]); }

// --- format cisla (rovnaky tvar ako Ruby fmt_mm) ------------------------------
(function(){
  eq(H.hwNlFmt(420), '420', 'cele cislo bez desatin');
  eq(H.hwNlFmt(419.6), '419,6', 'desatina so slovenskou ciarkou');
  eq(H.hwNlFmt('nic'), '', 'necislo = prazdny text');
})();

// --- ponuka selectu -----------------------------------------------------------
(function(){
  const list = H.hwNlOptionList(nl());
  eq(list.length, SERIES.length, 'ponuka = rad pravidla');
  eq(flat(list)[4], ['470', '470', true], 'aktualna hodnota je vybrana');
  ok(flat(list).filter(o => o[2]).length === 1, 'vybrana je prave jedna volba');

  // F5: hodnota mimo aktualneho radu (rad sa medzitym upravil) sa NEMAZE —
  // pridá sa ako doplnena volba, inak by select klamal.
  const out = H.hwNlOptionList(nl({ value: 419.6, locked: true }));
  eq(out.length, SERIES.length + 1, 'doplnena volba navyse');
  eq(flat(out)[SERIES.length], ['419.6', '419,6 (mimo radu)', true], 'mimo radu je vybrana');

  // Bez hodnoty (automat nevie, polozka bez NL) nie je vybrana ziadna volba.
  const none = H.hwNlOptionList(nl({ value: null }));
  eq(none.length, SERIES.length, 'ziadna doplnena volba');
  ok(none.every(o => !o.selected), 'bez hodnoty nie je vybrane nic');
})();

// --- tooltipy (zamknuty / odomknuty stav) -------------------------------------
(function(){
  eq(H.hwNlAutoText(nl({ locked: true, auto: 470, auto_known: true })), '470 mm', 'automat zname');
  eq(H.hwNlAutoText(nl({ locked: true, auto: null, auto_known: false })), 'nezmestí sa',
     'automat nevie = zrozumitelny text, nikdy prazdno');
  ok(H.hwNlSelectTitle(nl({ locked: true })).indexOf('zamknutá') >= 0, 'zamknuty select to povie');
  ok(H.hwNlSelectTitle(nl()).indexOf('automat') >= 0, 'odomknuty select vysvetli automat');
  ok(H.hwNlLockTitle(nl({ locked: true })).indexOf('Odomknúť') === 0, 'zamok odomyka');
  ok(H.hwNlLockTitle(nl()).indexOf('Zamknúť') === 0, 'odomknuty zamok zamyka');
})();

// --- render selectu + zamku ---------------------------------------------------
(function(){
  const openHtml = H.hwNlHtml(nl());
  ok(openHtml.indexOf('data-icon="lock-open"') >= 0, 'odomknuty = sprite lock-open (N8)');
  ok(openHtml.indexOf('aria-pressed="false"') >= 0, 'aria-pressed zrkadli stav');
  ok(openHtml.indexOf('class="hwnlsel"') >= 0, 'odomknuty select bez override farby');

  const lockHtml = H.hwNlHtml(nl({ locked: true, value: 420, auto: 470 }));
  ok(lockHtml.indexOf('data-icon="lock"') >= 0, 'zamknuty = sprite lock');
  ok(lockHtml.indexOf('aria-pressed="true"') >= 0, 'aria-pressed true');
  ok(lockHtml.indexOf('hwnlsel manual') >= 0, 'zamknuty select nesie override triedu');
  ok(lockHtml.indexOf('<option value="420" selected>420</option>') >= 0, 'vybrana rucna hodnota');
  ok(lockHtml.indexOf('emoji') < 0 && lockHtml.indexOf('🔒') < 0, 'ziadne emoji — len sprite');
})();

// --- payload zapisu (identita + cabinet_id guard) -----------------------------
(function(){
  // Minimalny dvojnik riadku: node.closest('.hwrow') vrati riadok s datasetom.
  const row = { dataset: { owner: 'front:F1/panel', type: 'slide',
                           rule: 'vysuvy-nl-podla-hlbky', cab: 'CAB-7' } };
  const node = { closest: () => row };
  eq(H.hwPayload(node, { field: 'nominal_length', value: 420 }),
     { owner_part_key: 'front:F1/panel', generic_type: 'slide',
       rule_id: 'vysuvy-nl-podla-hlbky', cabinet_id: 'CAB-7',
       field: 'nominal_length', value: 420 },
     'payload nesie identitu riadku aj cabinet_id (F6)');

  eq(H.hwPayload(node, { field: 'nominal_length', value: null }).value, null,
     'odomknutie posiela value null (zrusi LEN toto pole)');

  const cab = { dataset: { owner: '', type: 'leg', rule: 'nohy-zakladne', cab: '' } };
  eq(H.hwPayload({ closest: () => cab }, { field: 'quantity', value: 6 }).owner_part_key, null,
     'korpusova polozka ma owner null, nie prazdny retazec');
})();

// --- znamienko rucneho zasahu v okne Vyroba -----------------------------------
(function(){
  eq(P.hwManualMark(null), '', 'bez zasahu ziadne znamienko');
  const mark = P.hwManualMark('ručne prepísané: 4 ks (automat: 470 mm)');
  ok(mark.indexOf('#i-pencil') >= 0, 'sprite ikona, ziadne emoji');
  ok(mark.indexOf('title="ručne prepísané: 4 ks (automat: 470 mm)"') >= 0,
     'tooltip je serverovy text bez zmeny');
})();

console.log(`test_d93_nl_override.js: ${n} kontrol OK`);
