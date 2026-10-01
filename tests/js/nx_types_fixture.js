// H12c — REGISTER TYPOV SKRINKY pre Node sady Inspectora. NIE JE to testovacia
// sada (nema prefix `test_`), CI ju samostatne nespusta.
//
// V CEF plni register `NX.init` (`cabinet_types` = `CabinetTypes.client_payload`);
// v Node ho sady naplnia zo ZMLUVNEJ fixtury `tests/fixtures/h12_cabinet_types.json`
// (Ruby `test_h12a_register.rb` strazi, ze server posiela presne ju).
//   * `require('./nx_types_fixture.js')` — naplni zdielany `NXTypes` z core.js
//     (Node cache: ten isty objekt vidi kazdy `require` core.js) a nasadi ho
//     ako `global.NXTypes` (form.js, insert_state.js, shell.js… sa nan pytaju
//     ako na global, rovnako ako v CEF),
//   * `fill(ctx)` — to iste pre `vm` kontext so samostatne nacitanym core.js.
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
const C = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'core.js'));

function registry(){
  return JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'h12_cabinet_types.json'), 'utf8'));
}

C.NXTypes.set(registry());
global.NXTypes = C.NXTypes;

function fill(ctx){
  ctx.NXTypes.set(registry());
  return ctx.NXTypes;
}

module.exports = { NXTypes: C.NXTypes, registry: registry, fill: fill };
