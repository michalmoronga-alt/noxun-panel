'use strict';
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const dir = path.join(__dirname, '../fixtures/h18_golden');
const read = name => JSON.parse(fs.readFileSync(path.join(dir, name + '.json'), 'utf8'));
const { disagreements } = require(path.join(dir, 'zhoda.js'));
const HW = require('../../noxun_engine/ui/js/hardware.js');
// Mutačný beh môže odovzdať čerstvý payload z mutovaného Ruby do dočasného súboru.
// Bežná sada používa pripnutý PO; Ruby T0 overuje, že je totožný s aktuálnym kódom.
const payload = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2], 'utf8')) : read('payload_po');
const before = read('zhoda_pred'), after = disagreements(payload, read('source_pred'));
assert(before.length > 0, 'PRED musi zachytit skutocny nalez');
assert.deepEqual(after, [], 'T3 Z1-Z6: skutocne vykreslenie == nezavisly oracle stareho resolvera');
assert.equal(HW.hwSetsMetaText([{ own_count: '2' }, { own_count: NaN }, { own_count: Infinity }]), 'podľa projektu');
assert.equal(HW.hwSetsMetaText([{ own_count: 1 }, { own_count: 2 }]), '3 vlastné');
assert.equal(HW.hwSetsMetaText([{ own_count: 5 }]), '5 vlastných');
console.log('H18 T3: ' + Object.keys(read('source_pred')).length + ' pripadov, rozchody ' + before.length + ' -> ' + after.length + '; Z1-Z6 + tooltipy OK');
