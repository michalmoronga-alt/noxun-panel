'use strict';
const assert = require('node:assert/strict');
const payloads = require('../fixtures/h18b_golden/payload_po.json');
const HW = require('../../noxun_engine/ui/js/hardware.js');
for (const [id, c] of Object.entries(payloads)) {
  const entry = c.payload.find(e => e.generic_type === 'hinge');
  const selected = HW.hwOwnerOptionList(entry, c.owner).filter(o => o.selected);
  assert.equal(selected.length, 1, id);
  assert.equal(selected[0].value, 'set:' + c.value, id + ' vybrany set kridla');
  assert.notEqual(HW.hwSetsMetaText(c.payload), 'podľa projektu', id + ' vlastny vyber');
}
console.log('H18b T5: 3 JS scenare PASS');
