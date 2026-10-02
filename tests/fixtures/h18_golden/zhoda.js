'use strict';
// R4: pravda pochadza z oracle STAREHO Ruby resolvera; skutocnu kresbu cita HW.
const HW = require('../../../noxun_engine/ui/js/hardware.js');
function disagreements(payloads, sources){
  const failures = [];
  function same(id, scope, rule, actual, expected){
    if (JSON.stringify(actual) !== JSON.stringify(expected)) failures.push({ id, scope, rule, actual, expected });
  }
  Object.keys(sources).forEach(id => {
    const source = sources[id], list = payloads[id];
    const own = source.own_keys.length;
    same(id, 'meta', 'Z4', HW.hwSetsMetaText(list), !list.length ? '' : own === 0 ? 'podľa projektu' : own + ' ' + (own === 1 ? 'vlastný' : own < 5 ? 'vlastné' : 'vlastných'));
    list.forEach(entry => {
      const compat = entry.compat;
      function scope(sc, truth, owner){
        const options = owner === null ? HW.hwCabOptionList(entry) : HW.hwOwnerOptionList(entry, owner);
        const title = owner === null ? HW.hwCabTitle(entry) : HW.hwOwnerTitle(entry, owner);
        same(id, owner || 'cab', 'Z2 first option', options[0].text, truth.none_label);
        same(id, owner || 'cab', 'Z2 tooltip', title.includes(truth.none_label), true);
        let raw, valueId, valueText;
        if (owner === null){ raw = truth.stored_value; valueId = truth.stored_id; valueText = truth.stored_text; }
        else {
          const winner = truth.stored_winner;
          const hasOwner = ['owner', 'owner_class'].includes(winner[1]);
          raw = hasOwner ? winner[0] : null;
          valueId = hasOwner ? truth.stored_id : null;
          valueText = hasOwner ? truth.stored_text : null;
        }
        const known = valueId !== null && sc.options.some(o => o.id === valueId);
        same(id, owner || 'cab', 'Z1 current', sc.current, known ? valueId : null);
        same(id, owner || 'cab', 'Z1 stored', sc.stored, raw != null && !known);
        if (raw != null) same(id, owner || 'cab', 'Z1 text', sc.value_text, valueText);
        same(id, owner || 'cab', 'Z1 selected', options.filter(o => o.selected).length, 1);
      }
      if (compat){
        if (compat.cab) scope(compat.cab, source.cab, null);
        Object.keys(compat.owners).forEach(owner => scope(compat.owners[owner], source.owners[owner], owner));
      }
      // Plochy riadok: zdrave legacy selecty ostavaju presne ako pred H18.
      Object.keys(entry.owner_overrides || {}).forEach(owner => {
        if (compat && compat.owners[owner]) return;
        const ov = entry.owner_overrides[owner], selected = HW.hwOwnerOptionList(entry, owner).find(o => o.selected);
        if (ov.invalid){
          same(id, owner, 'Z1b invalid', selected.text, 'neplatný výber (uložený výber)');
          same(id, owner, 'Z1b disabled', selected.disabled, true);
        }
      });
      if (!compat && entry.override_selector && entry.override_selector.invalid){
        const selected = HW.hwCabOptionList(entry).find(o => o.selected);
        same(id, 'cab', 'Z6 invalid', selected.text, 'neplatný výber (uložený výber)');
        same(id, 'cab', 'Z6 disabled', selected.disabled, true);
      }
    });
  });
  return failures;
}
module.exports = { disagreements };
