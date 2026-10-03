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
assert.deepEqual(after, [], 'T3 Z1-Z8: skutocne vykreslenie == nezavisly oracle stareho resolvera');
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
// T12: skutocny lahky refresh; okrem textu zostava rozpisany riadok/fokus.
const { panel } = require(path.join(dir, 'mixed_display.js'));
const ui = panel();
try {
  ['Dmix', 'Dmixleg'].forEach(kind => {
    const id = kind + '/ov1/seed/blocked', original = payload[id];
    const items = Object.keys(blocked[id].owners).map(owner => ({ generic_type: 'hinge', owner_part_key: owner,
      owner_label: owner.includes('F1') ? 'F1 · dvierka' : 'F2 · dvierka', quantity: 2, rule_id: 'h18-fixture' }));
    ui.ctx.renderHardware(items, [], original, 'CAB-1');
    const draft = ui.items.querySelector('input.hwqty');
    draft.value = '7';
    draft.focus();
    const edited = JSON.parse(JSON.stringify(original));
    edited[0].override_value_text = '<img src=x> & "zmenený výber"';
    ui.ctx.refreshHardwareSets(edited);
    const row = ui.sets.querySelector('.hwstoredsetrow');
    assert(row, kind + ' ulozeny riadok zostal viditelny');
    assert.equal(ui.textOf(row), 'Závesy skrinka: <img src=x> & "zmenený výber" (uložený výber) — nepoužíva sa', kind + ' aktualny serverovy text');
    assert.equal(row.querySelectorAll('img,select,input,button').length, 0, kind + ' len escapovany text bez ovladaca');
    assert.equal(ui.items.querySelector('input.hwqty'), draft, kind + ' povodny item DOM');
    assert.equal(draft.value, '7', kind + ' rozpisany pocet ostal');
    assert.equal(ui.ctx.document.activeElement, draft, kind + ' fokus zostal');
    const owners = ui.items.querySelectorAll('select.hwsetsel');
    assert.equal(owners.length, 2, kind + ' oba existujuce owner selecty');
    owners.forEach(sel => {
      const selected = sel.querySelectorAll('option').filter(o => o.hasAttribute('selected'));
      assert.equal(selected.length, 1, kind + ' owner ma jednu vybranu volbu');
      assert.equal(selected[0].value, '', kind + ' ucinne dedenie ownera');
      assert.equal(ui.textOf(selected[0]), 'podľa projektu — bez setu', kind + ' bez ulozeneho cab vo vlastnikovi');
    });
    ui.ctx.refreshHardwareSets(payload[kind + '/ov1/seed/ok']);
    assert.equal(ui.sets.querySelectorAll('.hwstoredsetrow').length, 0, kind + ' odblokovanie odstrani neucinny text');
    assert.equal(ui.byId('hwSetRowsEmpty').hidden, false, kind + ' znovu viditelny existujuci popis zmiesanej skrinky');
    ui.ctx.refreshHardwareSets(original);
    assert.equal(ui.sets.querySelectorAll('.hwstoredsetrow').length, 1, kind + ' nove blokovanie zobrazi ulozeny text');
    ui.ctx.refreshHardwareSets(payload[kind + '/ov0/seed/blocked']);
    assert.equal(ui.sets.querySelectorAll('.hwstoredsetrow').length, 0, kind + ' odstraneny vyber nezostane visiet');
    assert.equal(ui.byId('hwSetRowsEmpty').hidden, false, kind + ' bez ulozeneho vyberu ma popis');
    assert.equal(ui.sets.querySelectorAll('select,input,button').length, 0, kind + ' refresh neprida zapis');
    assert.equal(ui.items.querySelector('input.hwqty'), draft, kind + ' zachovany DOM po celom cykle');
    assert.equal(draft.value, '7', kind + ' rozpisany pocet po celom cykle');
    assert.equal(ui.ctx.document.activeElement, draft, kind + ' fokus po celom cykle');
  });
} finally { ui.dispose(); }
console.log('H18 T3/T12: ' + Object.keys(sources).length + ' pripadov, rozchody ' + before.length + ' -> ' + after.length + '; Z1-Z8 + zmiesany refresh OK');
