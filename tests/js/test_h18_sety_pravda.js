'use strict';
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const dir = path.join(__dirname, '../fixtures/h18_golden');
const read = name => JSON.parse(fs.readFileSync(path.join(dir, name + '.json'), 'utf8'));
const { disagreements } = require(path.join(dir, 'zhoda.js'));
const HW = require('../../noxun_engine/ui/js/hardware.js');
// Mutačný beh môže odovzdať čerstvý payload z mutovaného Ruby do dočasného súboru.
// Bežná sada používa pripnutý PO; Ruby T0 overuje, že je totožný s aktuálnym kódom.
const payload = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2], 'utf8')) : Object.assign({}, read('payload_po'), read('blocked_payload_po'));
const blocked = read('blocked_pred'), sources = read('source_pred');
Object.keys(blocked).filter(id => id.startsWith('P2/')).forEach(id => { sources[id] = blocked[id]; });
const before = read('zhoda_pred'), after = disagreements(payload, sources, blocked);
assert(before.length > 0, 'PRED musi zachytit skutocny nalez');
assert.deepEqual(after, [], 'T3 Z1-Z6: skutocne vykreslenie == nezavisly oracle stareho resolvera');
// Normal, missing-unblocked a invalid NESMU dostat novy ulozeny-neucinny
// stav. Nezavisle pripinanie zdraveho stringu, selectora a invalid markeru.
Object.keys(blocked).filter(id => id.startsWith('P2/') && blocked[id].status !== 'blocked').forEach(id => {
  const truth = blocked[id], entry = payload[id][0];
  function active(owner, raw, text){
    const opts = owner === null ? HW.hwCabOptionList(entry) : HW.hwOwnerOptionList(entry, owner);
    const selected = opts.find(o => o.selected);
    assert.equal(selected.value, raw == null ? '' : typeof raw === 'object' ? '__param__' : raw, id + ' active value');
    assert.equal(selected.disabled, raw != null && typeof raw === 'object', id + ' active disabled');
    if (raw != null) assert.equal(selected.text, text, id + ' active text');
  }
  if (!entry.compat){
    active(null, truth.flat_cab_raw, truth.flat_cab_active_text);
    Object.keys(truth.owners).forEach(owner => active(owner, truth.owners[owner].flat_raw, truth.owners[owner].flat_active_text));
  } else if (id.includes('/known_string/') && ['ok','missing'].includes(truth.status)){
    // Tento set je v povodnom snapshote znamy a kompatibilny. Nesmieme
    // odvodit ocakavanu dostupnost z aktualnych sc.options (samooverenie).
    const scopes = Object.keys(entry.compat.owners).map(owner => [entry.compat.owners[owner], truth.owners[owner].flat_raw]);
    if (entry.compat.cab) scopes.push([entry.compat.cab, truth.cab.stored_value]);
    scopes.filter(row => row[1] === 'zaves-p2o').forEach(row => {
      assert.equal(row[0].current, 'set:zaves-p2o', id + ' known compatible set');
      assert.equal(row[0].stored, false, id + ' known set is current');
    });
  }
});
assert.equal(HW.hwSetsMetaText([{ own_count: '2' }, { own_count: NaN }, { own_count: Infinity }]), 'podľa projektu');
assert.equal(HW.hwSetsMetaText([{ own_count: 1 }, { own_count: 2 }]), '3 vlastné');
assert.equal(HW.hwSetsMetaText([{ own_count: 5 }]), '5 vlastných');
console.log('H18 T3: ' + Object.keys(sources).length + ' pripadov, rozchody ' + before.length + ' -> ' + after.length + '; Z1-Z7 + tooltipy OK');
