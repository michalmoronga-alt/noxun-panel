// H12d · R0.6 — CHARAKTERIZACNY ODTLACOK mien roli v karte dielca PRED
// zjednotenim (package `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H12.md`, H12d).
//   node tests/js/test_h12d_mena_roli.js
//
// Dnes ma karta dielca vlastnu JS mapu `roleLabel` (part_card.js), ktora sa od
// stlpca Rola v Kusovniku (`ProductionCore::ROLE_LABELS`) lisi v 9 rolach.
// Tento test zachytil NEZMENENY kod: pre kazdu rolu `BuildPlan::ROLES` + neznamu
// a prazdnu (zoznam z Ruby fixtury `roles.json`) hlavicku karty (`pcName`,
// `pcName2`), vetu modalu „Použiť na podobné…" (`simWhat`) a popis docasnej
// polozky raily (`nxTempLabel`) — s prazdnym aj vyplnenym nazvom dielca.
//
// Generovanie (LEN na nezmenenom kode, nikdy pri refaktore):
//   NX_H12D_WRITE=1 node tests/js/test_h12d_mena_roli.js
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const H = require('./h12_harness.js');

const FIX = path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'roles_js.json');
const RUBY = JSON.parse(fs.readFileSync(path.join(H.ROOT, 'tests', 'fixtures', 'h12_golden', 'roles.json'), 'utf8'));
const NAMES = ['', 'Bok lavy'];

function card(role, name){
  return { role: role, name: name, role_key: 'cabinet/x', cabinet_id: 'CAB-001', length: 600, width: 560,
           thickness: 18, edges: {}, edge_labels: {}, edge_sides: {} };
}

function snapshot(){
  const L = H.load();
  const out = {};
  RUBY.roles.forEach(function(role){
    const row = { js_role_label: L.ctx.roleLabel(role) };
    NAMES.forEach(function(name){
      const pc = card(role, name);
      L.ctx.renderPartCard(pc);
      L.ctx.openSimilarModal();
      row[name === '' ? 'bez_nazvu' : 's_nazvom'] = {
        pcName: L.node('pcName').innerHTML,
        pcName2: L.node('pcName2').textContent,
        simWhat: L.node('simWhat').innerHTML,
        temp: L.ctx.nxTempLabel('part', pc)
      };
    });
    out[role === '' ? "('')" : role] = row;
  });
  return out;
}

const got = JSON.stringify(snapshot(), null, 2) + '\n';
if (process.env.NX_H12D_WRITE === '1'){
  fs.writeFileSync(FIX, got, 'utf8');
  console.log('OK: zapisane ' + FIX);
  process.exit(0);
}
assert.ok(fs.existsSync(FIX), 'chyba fixtura ' + FIX);
assert.strictEqual(got, fs.readFileSync(FIX, 'utf8').replace(/\r\n/g, '\n'), 'odtlacok mien roli v karte dielca sa zmenil');
console.log('test_h12d_mena_roli: OK (' + RUBY.roles.length + ' roli)');
