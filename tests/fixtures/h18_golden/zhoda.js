'use strict';
// R4: pravda pochadza z oracle STAREHO Ruby resolvera; skutocnu kresbu cita HW.
const HW = require('../../../noxun_engine/ui/js/hardware.js');
function disagreements(payloads, sources, blockedSources){
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
        if (owner === null){
          if (source.status === 'blocked') truth = blockedSources[id].cab;
          raw = truth.stored_value; valueId = truth.stored_id; valueText = truth.stored_text;
        }
        else {
          const winner = truth.stored_winner;
          const hasOwner = ['owner', 'owner_class'].includes(winner[1]);
          raw = hasOwner ? winner[0] : null;
          valueId = hasOwner ? truth.stored_id : null;
          valueText = hasOwner ? truth.stored_text : null;
        }
        const known = source.status !== 'blocked' && valueId !== null && sc.options.some(o => o.id === valueId);
        same(id, owner || 'cab', 'Z1 current', sc.current, known ? valueId : null);
        same(id, owner || 'cab', 'Z1 stored', sc.stored, raw != null && !known);
        if (raw != null) same(id, owner || 'cab', 'Z1 text', sc.value_text, valueText);
        same(id, owner || 'cab', 'Z1 selected', options.filter(o => o.selected).length, 1);
        const selected = options.find(o => o.selected);
        same(id, owner || 'cab', 'Z1 selected value', selected.value, known ? valueId : raw != null ? '__stored__' : '');
        same(id, owner || 'cab', 'Z1 selected disabled', selected.disabled, raw != null && !known);
        if (raw != null && !known) same(id, owner || 'cab', 'Z1 stored text', selected.text, valueText + ' (uložený výber)');
      }
      if (compat){
        if (compat.cab) scope(compat.cab, source.cab, null);
        Object.keys(compat.owners).forEach(owner => scope(compat.owners[owner], source.owners[owner], owner));
      }
      // Z7: ulozene-neucinne ploche vybery. Pravda je z pripnutej starej
      // retaze, nie z aktualnych override_* poli ani z noveho source helpera.
      if (source.status === 'blocked'){
        const saved = blockedSources[id];
        function flat(owner, raw, text){
          const options = owner === null ? HW.hwCabOptionList(entry) : HW.hwOwnerOptionList(entry, owner);
          if (!options) return;
          const key = owner || 'cab';
          const selected = options.filter(o => o.selected);
          const title = owner === null ? HW.hwCabTitle(entry) : HW.hwOwnerTitle(entry, owner);
          same(id, key, 'Z7 first option', options[0].text, saved.flat_none_label);
          same(id, key, 'Z7 tooltip', title.includes(saved.flat_none_label), true);
          same(id, key, 'Z7 selected count', selected.length, 1);
          same(id, key, 'Z7 selected value', selected[0].value, raw != null ? '__stored__' : '');
          same(id, key, 'Z7 stored text', selected[0].text, raw != null ? text + ' (uložený výber)' : saved.flat_none_label);
          same(id, key, 'Z7 disabled', selected[0].disabled, raw != null);
        }
        if (!compat) flat(null, saved.flat_cab_raw, saved.flat_cab_text);
        Object.keys(saved.owners).forEach(owner => {
          if (compat && compat.owners[owner]) return;
          flat(owner, saved.owners[owner].flat_raw, saved.owners[owner].flat_text);
        });
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
  if (blockedSources) failures.push(...require('./mixed_display.js').disagreements(payloads, blockedSources));
  return failures;
}
module.exports = { disagreements };
