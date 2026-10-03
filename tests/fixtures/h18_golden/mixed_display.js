'use strict';
// Z8 cita skutocny renderHardware, nie kopiu jeho filter/map ani novy helper.
// Ulozeny text a zmiesany rozsah pochadzaju z pripnuteho blocked_pred.json.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const { mkEl, DOC, textOf, faithful, reset } = require('../../js/minidom.js');
const file = path.join(__dirname, '../../../noxun_engine/ui/js/hardware.js');
function panel(code = fs.readFileSync(file, 'utf8')){
  const previous = DOC.body.children;
  DOC.body.children = [];
  faithful(true);
  ['hwRows', 'hwSetRows', 'hwItemsMeta', 'hwSetsMeta'].forEach(id => {
    const node = mkEl('div'); node.id = id; DOC.body.appendChild(node);
  });
  const ctx = {
    document: DOC, el: id => DOC.getElementById(id), window: {},
    esc: s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;'),
    NXIcons: { svg: () => '' }, hwManualView: []
  };
  vm.createContext(ctx);
  try { vm.runInContext(code, ctx, { filename: file }); }
  catch (error){ DOC.body.children = previous; reset(); throw error; }
  return {
    ctx, sets: DOC.getElementById('hwSetRows'), items: DOC.getElementById('hwRows'),
    byId: id => DOC.getElementById(id), textOf,
    dispose(){ DOC.body.children = previous; reset(); }
  };
}
function disagreements(payloads, truths, code){
  const out = [], ui = panel(code);
  function same(id, rule, actual, expected){
    if (JSON.stringify(actual) !== JSON.stringify(expected)) out.push({ id, scope: 'cab', rule, actual, expected });
  }
  try {
    Object.keys(truths).forEach(id => {
      const truth = truths[id];
      // Neodvodzujeme zmiesanu triedu z aktualneho compat.cab (samooverenie).
      if (truth.cab !== null || !Object.values(truth.owners).some(o => o.class_key)) return;
      const entries = payloads[id];
      ui.ctx.renderHardware([], [], entries, 'CAB-1');
      const expected = truth.status === 'blocked' && truth.flat_cab_raw != null;
      const rows = ui.sets.querySelectorAll('.hwstoredsetrow');
      same(id, 'Z8 saved mixed cab row count', rows.length, expected ? 1 : 0);
      same(id, 'Z8 mixed cab writes forbidden', ui.sets.querySelectorAll('select,input,button').length, 0);
      if (expected && rows[0]){
        const text = entries[0].label + ' skrinka: ' + truth.flat_cab_text + ' (uložený výber) — nepoužíva sa';
        same(id, 'Z8 independent saved text', textOf(rows[0]), text);
        same(id, 'Z8 full tooltip', rows[0].querySelector('.hwname').getAttribute('title'), text);
      }
    });
  } finally { ui.dispose(); }
  return out;
}
module.exports = { panel, disagreements };
