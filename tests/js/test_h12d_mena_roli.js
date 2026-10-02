// H12d (C-05) — MENA ROLI V KARTE DIELCA zo servera (package
// `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H12.md`, R0.6, R4.3, R4.4, M16).
//   node tests/js/test_h12d_mena_roli.js
//
// Do H12d mala karta dielca vlastnu JS mapu `roleLabel` (part_card.js), ktora
// sa od stlpca Rola v Kusovniku lisila v 9 rolach a pri dielcoch zasuvky
// a volnej doske ukazovala surovy kod (`drawer_bottom`). Od H12d posiela server
// v payloade karty `role_label` (`PartKeys::ROLE_LABELS`) a karta ho len vypise.
//
// Fixtura `roles_js.json` je DOKUMENTACNY ODTLACOK NEZMENENEHO kodu (prvy
// commit H12d): hlavicka karty (`pcName`, `pcName2`), veta modalu „Použiť na
// podobné…" (`simWhat`) a popis polozky raily (`nxTempLabel`) pre kazdu rolu
// `BuildPlan::ROLES` + neznamu a prazdnu (zoznam a mena z Ruby fixtury
// `roles.json`), s prazdnym aj vyplnenym nazvom dielca. NEREGENERUJE sa
// (po H12d uz mapa neexistuje). Test overi:
//   1) rola, ktorej meno sa nezmenilo -> vsetky texty BAJTOVO ako predtym,
//   2) rola z 9 dokumentovanych rozdielov -> ten isty text, len meno roly je
//      z Kusovnika (Q1: „Strop", „Čelo zásuvky", „Dno zásuvky"…),
//   3) mnozina zmenenych roli = presne tych 9 (S5) — nic ine sa nepohlo,
//   4) payload bez `role_label` (starsi push) -> surova rola (bez padu),
//   5) okno nema JS funkciu `roleLabel` (M16; sken zdrojov = guard T3f v Ruby).
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const H = require('./h12_harness.js');

const FIX = path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'roles_js.json');
const RUBY = JSON.parse(fs.readFileSync(path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'roles.json'), 'utf8'));
const BEFORE = JSON.parse(fs.readFileSync(FIX, 'utf8'));
const NAMES = ['', 'Bok lavy'];
const KEY = function(role){ return role === '' ? "('')" : role; };

// S5 (package H12 §0): roly, ktore JS mapa pred H12d volala inak nez Kusovnik.
const DOC_DIFF = { top: 'Strop', divider_v: 'Zvislá priečka', divider_h: 'Vodorovná priečka',
                   drawer_front: 'Čelo zásuvky', free_panel: 'Voľná doska', drawer_bottom: 'Dno zásuvky',
                   drawer_back: 'Chrbát zásuvky', box_side: 'Bok boxu', drawer_inner_front: 'Vnútorné čelo zásuvky' };

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

function card(role, name, withLabel){
  const pc = { role: role, name: name, role_key: 'cabinet/x', cabinet_id: 'CAB-001', length: 600, width: 560,
               thickness: 18, edges: {}, edge_labels: {}, edge_sides: {} };
  // Server: `role_label` = `PartKeys.role_label(role)` (Ruby fixtura).
  if (withLabel) pc.role_label = RUBY.role_label[role];
  return pc;
}

function render(L, pc){
  L.ctx.renderPartCard(pc);
  L.ctx.openSimilarModal();
  return { pcName: L.node('pcName').innerHTML, pcName2: L.node('pcName2').textContent,
           simWhat: L.node('simWhat').innerHTML, temp: L.ctx.nxTempLabel('part', pc) };
}

function swap(obj, from, to){
  const out = {};
  Object.keys(obj).forEach(function(k){ out[k] = from === '' ? obj[k] : obj[k].split(from).join(to); });
  return out;
}

// ============ 1–3) texty karty zo servera ======================================
const L = H.load();
const changed = [];
RUBY.roles.forEach(function(role){
  const before = BEFORE[KEY(role)];
  const server = RUBY.role_label[role];
  ok(before, 'fixtura nesie rolu ' + KEY(role));
  if (before.js_role_label !== server) changed.push(role);
  NAMES.forEach(function(name){
    const was = before[name === '' ? 'bez_nazvu' : 's_nazvom'];
    const now = render(L, card(role, name, true));
    // Meno roly sa vymeni LEN tam, kde stalo (nazov dielca „Bok lavy" ziadne meno roly neobsahuje).
    eq(now, swap(was, before.js_role_label, server), KEY(role) + ' / nazov „' + name + '"');
  });
});
eq(changed.sort(), Object.keys(DOC_DIFF).sort(), 'zmenilo sa presne 9 dokumentovanych roli (S5) — nic ine');
Object.keys(DOC_DIFF).forEach(function(role){
  eq(RUBY.role_label[role], DOC_DIFF[role], role + ': meno z Kusovnika (Q1)');
  eq(render(L, card(role, '', true)).pcName, '<b>' + DOC_DIFF[role] + '</b> · ' + DOC_DIFF[role],
     role + ': hlavicka karty ako stlpec Rola Kusovnika');
});
eq(render(L, card('drawer_bottom', '', true)).pcName2, 'Dno zásuvky', 'dno zasuvky uz nie je surovy kod');

// ============ 4) payload bez `role_label` ======================================
['drawer_bottom', 'top', 'neznama_rola'].forEach(function(role){
  const now = render(L, card(role, '', false));
  eq(now.pcName, '<b>' + role + '</b> · ' + role, role + ': bez kluca surova rola (ziadny JS preklad)');
  eq(now.temp, role, role + ': polozka raily bez kluca = surova rola');
});
eq(L.ctx.nxTempLabel('part', { role: '' }), '', 'prazdna rola nevymysla text');
eq(L.ctx.nxTempLabel('board', { role: 'free_panel', role_label: 'Voľná doska' }), '', 'doska bez nazvu — rezim board sa nemeni');

// ============ 5) M16: v okne nie je JS preklad roly ============================
// (Sken zdrojov `ui/js` na mapu mien roli je guard T3f v `tests/pure/test_h12d_mena_roli.rb`.)
eq(typeof L.ctx.roleLabel, 'undefined', 'JS funkcia roleLabel zanikla (meno roly sklada server)');

console.log('test_h12d_mena_roli: OK (' + n + ' kontrol, ' + RUBY.roles.length + ' roli)');
