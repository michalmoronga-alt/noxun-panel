// MR2B: živý controller + existujúci katalóg/transport, malé DOM zdieľané s NXModal.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mkEl, DOC, dispatch, textOf } = require('./minidom.js');
const JS = path.join(__dirname, '../../noxun_engine/ui/js');
let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(value, msg){ n++; assert.ok(value, msg); }
function node(id){ return DOC.getElementById(id); }
['mdAppearanceRoot', 'mdDecorList', 'status', 'nxModalRoot'].forEach(id => {
  const el = mkEl('div'); el.id = id; DOC.body.appendChild(el);
});
node('mdAppearanceRoot').style.display = 'none';
window.innerWidth = 1000; window.innerHeight = 800;
window.NXEsc = global.NXEsc = require(path.join(JS, 'nx_esc.js'));
window.NXModal = global.NXModal = require(path.join(JS, 'nx_modal.js'));
global.NX = window.NX = {};
const sent = [];
window.sketchup = global.sketchup = new Proxy({}, { get: (_target, key) => raw => sent.push([key, raw ? JSON.parse(raw) : null]) });
global.studioSec = 'mat';
const M = require(path.join(JS, 'proj_materials.js'));
window.mdAppearanceContext = M.mdAppearanceContext;
window.mdColorSave = M.mdColorSave;
const A = require(path.join(JS, 'md_appearance.js'));
const base = {
  sheets: [
    { material_id: 'S18', group_id: 'G', decor: 'H3303', decor_name: 'Dub', structure: 'ST 10', thickness: 18, type: 'DTDL', color: [10, 20, 30], image_url: 'https://example.invalid/photo.png' },
    { material_id: 'S36', group_id: 'G', decor: 'H3303', structure: ' st   10 ', thickness: 36, type: 'DTDL', color: [10, 20, 30] },
    { material_id: 'EMPTY', group_id: 'EMPTY', decor: 'W', structure: '', thickness: 18, type: 'DTDL', color: [90, 100, 110] },
    { material_id: 'UNI', group_id: 'UNI', decor: 'UNI', structure: '', thickness: 18, type: 'DTDL', color: [90, 100, 110], uni: true }
  ],
  edges: [
    { abs_id: 'E1', group_id: 'G', decor: 'H3303', structure: 'ST 10', thickness: 1, width: 23, color: [10, 20, 30] },
    { abs_id: 'E2', group_id: 'G', decor: 'H3303', structure: 'ST 10', thickness: 2, width: 43, color: [10, 20, 30] },
    { abs_id: 'OTHER', group_id: 'G', decor: 'H3303', structure: 'ST9', thickness: 1, color: [10, 20, 30] },
    { abs_id: 'ONLY', group_id: 'ONLY', decor: 'ABS', structure: '', thickness: 1, color: [70, 80, 90] }
  ]
};
function catalog(more = {}, rows = base){ return Object.assign({ catalog_schema: 10, catalog_rev: 'r1', catalog: structuredClone(rows) }, more); }
function install(cat = catalog(), guid = 'doc-A'){
  M.matApplyState({ model_guid: guid, catalog: cat }); M.mdRenderLists();
}
function count(action){ return sent.filter(x => x[0] === action).length; }
function last(action){ return sent.filter(x => x[0] === action).at(-1)[1]; }
function click(id){ return dispatch(node(id), 'click'); }
function surface(key = 'ST 10'){
  return DOC.querySelectorAll('[data-mda-group][data-mda-surface]').find(el => el.getAttribute('data-mda-surface') === key);
}
function state(more = {}){ return Object.assign({ mode: 'color', color: [10, 20, 30], preview_url: null,
  message: 'Plošná farba bez textúry.', can_pick: true, can_edit: true, can_save: false, can_reset: false, can_apply: false }, more); }
function request(group = 'g:G', key = 'ST 10'){
  A.invalidate(); studioSec = 'mat'; install(); M.mdOpenDetail(group);
  dispatch(surface(key), 'click'); return last('appearance_prepare');
}
function ready(req, more = {}){ M.MD.appearanceReady(Object.assign({}, req, { ok: true, session_token: 'session-' + req.request_token, state: state() }, more)); }
function reply(action, more = {}, req = last('appearance_' + action)){
  M.MD.appearanceResult(Object.assign({}, req, { action, ok: true, state: state() }, more));
}
function open(more = {}){ const req = request(); ready(req, more); return req; }

// Povrch je jedna skupina dosiek aj ABS, vrátane prázdnej štruktúry a ABS bez dosky.
install(); M.mdOpenDetail('g:G');
eq(DOC.querySelectorAll('[data-mda-surface]').length, 2, 'dve štruktúry = dva vstupy, hrúbky ani ABS nepridávajú ďalší');
M.mdOpenDetail('g:EMPTY'); eq(DOC.querySelectorAll('[data-mda-surface]').length, 1, 'jeden prázdny povrch má Vzhľad');
eq(surface('').getAttribute('data-mda-surface'), '');
let req = request('g:ONLY', ''); eq(req.kind, 'edge'); eq(req.anchor_id, 'ONLY', 'ABS-only kotva');
M.mdOpenDetail('g:UNI'); eq(DOC.querySelectorAll('[data-mda-surface]').length, 0, 'UNI nedostáva úpravu vzhľadu');
ok(!A.open('g:UNI', '', null));
install(catalog({ catalog_state: 'read_only', catalog_state_reason: 'Novšia schéma' })); M.mdOpenDetail('g:G');
eq(surface().getAttribute('aria-disabled'), 'true');
let before = count('appearance_prepare'); dispatch(surface(), 'click'); eq(count('appearance_prepare'), before, 'RO nevytvorí session');

// Žiadne zápisy pred ready; presná korelácia a vlastná podporovaná schéma.
req = request();
eq(Object.keys(req).sort(), ['anchor_id', 'catalog_schema', 'kind', 'model_guid', 'request_token', 'section'].sort());
eq(req.catalog_schema, 10); eq(req.kind, 'sheet'); eq(req.anchor_id, 'S18');
ok(NXEsc.FOREIGN_MODAL_IDS.includes('mdAppearanceRoot')); eq(NXEsc.blockedBy(), 'mdAppearanceRoot');
click('mdaPick'); eq(count('appearance_pick'), 0, 'prepare ešte nepovolí akciu');
for (const [key, value] of [['request_token', 'old'], ['model_guid', 'other'], ['section', 'bom'], ['anchor_id', 'S36'], ['kind', 'edge']]){
  ready(Object.assign({}, req, { [key]: value })); eq(node('mdaPick').getAttribute('aria-disabled'), 'true', 'cudzie ready: ' + key);
}
ready(req); eq(node('mdaPick').getAttribute('aria-disabled'), 'false');
eq(node('mdaSave').getAttribute('aria-disabled'), 'true'); ok(node('mdaSave').title.includes('ukladá hneď'));
eq(node('mdaPreview').style.backgroundImage, 'none', 'katalógová fotka nesmie predstierať textúru');
eq(node('mdaPreview').style.backgroundColor, '#0a141e');
eq(DOC.activeElement.id, 'mdaClose');

// Busy drží X, catcher, Escape, ostatné akcie, druhé otvorenie aj farebný picker.
click('mdaPick'); const pick = last('appearance_pick'); ok(A.isBusy());
const total = sent.length;
['mdaPick', 'mdaEdit', 'mdaSave', 'mdaReset', 'mdaApply', 'mdaClose'].forEach(click);
dispatch(node('mdAppearanceRoot'), 'click');
const escape = dispatch(node('mdaPick'), 'keydown', { key: 'Escape' });
ok(escape._prevented && escape._immediate); ok(A.isOpen() && A.isBusy());
eq(A.open('g:G', 'ST9', surface('ST9')), false, 'iný povrch nenahradí busy okno');
ok(click('mdaColor')._prevented, 'native picker sa počas akcie neotvorí');
node('mdaColor').value = '#abcdef'; dispatch(node('mdaColor'), 'change');
eq(M.mdColorSave('g:G', '#abcdef'), false, 'aj starý vonkajší color caller rešpektuje busy');
eq(sent.length, total, 'žiadny druhý request ani close');
for (const [key, value] of [['request_token', 'wrong'], ['session_token', 'wrong'], ['action_token', 'wrong'], ['action', 'save'], ['model_guid', 'other'], ['section', 'bom'], ['kind', 'edge'], ['anchor_id', 'S36']]){
  reply('pick', { [key]: value }, pick); ok(A.isBusy(), 'cudzí výsledok neodomkne: ' + key);
}
reply('pick', { ok: false, message: 'Výber bol zrušený.' }, pick); ok(A.isOpen() && !A.isBusy());
eq(node('mdaNotice').textContent, 'Výber bol zrušený.');

// Rovnaký dokument sa môže celý obnoviť a trigger zmeniť DOM identitu aj poradie.
click('mdaPick'); const active = last('appearance_pick'), oldTrigger = surface();
const changed = structuredClone(base);
changed.sheets.unshift(Object.assign({}, changed.sheets[0], { material_id: 'S8', thickness: 8 }));
changed.sheets.forEach(row => { if (row.group_id === 'G') row.color = [1, 2, 3]; });
install(catalog({}, changed));
ok(A.isBusy() && A.isOpen(), 'same-doc full refresh drží session aj busy');
ok(surface() !== oldTrigger, 'detail skutočne nahradil DOM');
eq(surface().getAttribute('aria-expanded'), 'true');
eq(node('mdaColor').value, '#010203', 'echo obnoví farbu');
reply('pick', { state: state({ mode: 'working', can_save: true, can_reset: true }) }, active);
ok(!A.isBusy(), 'odpoveď pôvodnej S18 kotvy platí aj po pridaní S8');
node('mdaClose').focus(); dispatch(node('mdaClose'), 'keydown', { key: 'Tab', shiftKey: true }); eq(DOC.activeElement.id, 'mdaReset');
dispatch(node('mdaReset'), 'keydown', { key: 'Tab' }); eq(DOC.activeElement.id, 'mdaClose');
click('mdaClose'); eq(DOC.activeElement, surface(), 'fokus ide na nový živý trigger');
ok(!A.isOpen()); eq(NXEsc.blockedBy(), null);

// ABA: ani pending ready, ani starý úspech po odchode/návrate nepatria novému oknu.
const old = request(); A.close(); const fresh = request();
ok(old.request_token !== fresh.request_token); ready(old); eq(node('mdaPick').getAttribute('aria-disabled'), 'true');
ready(fresh); click('mdaPick'); const oldAction = last('appearance_pick');
M.matOnLeaveSection(); studioSec = 'bom'; ok(!A.isOpen(), 'odchod invaliduje aj busy okno');
req = request(); ready(req); click('mdaPick');
reply('pick', {}, oldAction); ok(A.isBusy(), 'starý úspech neodomkne nový pokus');
M.matApplyState({ model_guid: 'doc-B' }); ok(!A.isOpen(), 'nový dokument zatvorí starú session');
reply('pick'); ok(!A.isOpen());
req = request(); M.mdCloseDetail(); ready(req); ok(!A.isOpen());
req = request(); M.mdSearchInput(); ready(req); ok(!A.isOpen());
req = request(); M.matOpenAnchor('S36'); ready(req); ok(!A.isOpen(), 'deep-link je nová návšteva aj rovnakej skupiny');

// Farba používa pôvodný callback, výhradne change a korelované finálne potvrdenie.
open(); before = count('set_decor_color');
node('mdaColor').value = '#abcdef'; dispatch(node('mdaColor'), 'input'); eq(count('set_decor_color'), before);
dispatch(node('mdaColor'), 'change');
const color = last('set_decor_color');
eq(color.color, '#abcdef'); eq(color.group_id, 'G'); eq(color.catalog_schema, 10);
eq(color.appearance_context.anchor_id, 'S18'); ok(color.appearance_context.session_token); ok(A.isBusy());
const rgbRows = structuredClone(base); rgbRows.sheets[0].color = [171, 205, 239];
M.MD.setCatalog(catalog({ catalog_rev: 'r2' }, rgbRows));
ok(A.isBusy(), 'katalógové echo nie je finálna odpoveď'); eq(node('mdaColor').value, '#abcdef');
M.MD.appearanceResult(Object.assign({}, color.appearance_context, { action: 'color', ok: false, message: 'Zápis bol odmietnutý.', state: state({ color: [171, 205, 239] }) }));
ok(!A.isBusy() && A.isOpen(), 'aj color refusal odomkne až vlastný formulár'); eq(node('mdaNotice').textContent, 'Zápis bol odmietnutý.');
A.close(); ok(M.mdColorSave('g:G', '#112233')); ok(!('appearance_context' in last('set_decor_color')), 'normálny caller má pôvodný payload');

// Stav a náhľad pochádzajú zo servera; chýbajúci zdroj nesmie vyzerať ako RGB/textúra z fotky.
open({ state: state({ mode: 'missing', message: 'Uložený súbor chýba.', preview_url: 'https://example.invalid/photo.png', can_edit: false, can_save: false, can_reset: true }) });
eq(node('mdaPreview').style.backgroundImage, 'none'); eq(node('mdaPreview').style.backgroundColor, 'var(--nx-surface-sunken)');
ok(textOf(node('mdaCard')).includes('Uložený súbor chýba.')); eq(node('mdaEdit').getAttribute('aria-disabled'), 'true');
eq(node('mdaPick').getAttribute('aria-disabled'), 'false'); eq(node('mdaReset').getAttribute('aria-disabled'), 'false');
open({ state: state({ mode: 'working', preview_url: 'data:image/png;base64,YQ==', can_save: true, can_reset: true }) });
eq(node('mdaPreview').style.backgroundImage, 'url("data:image/png;base64,YQ==")');
click('mdaSave'); reply('save', { ok: false, message: 'Uložené, použitie zlyhalo.', state: state({ mode: 'native', can_save: false, can_apply: true }) });
eq(node('mdaApply').style.display, ''); before = count('appearance_save'); node('mdaApply').focus(); click('mdaApply');
eq(count('appearance_save'), before, 'retry používa Apply, neopakuje publikovanie');
reply('apply');
eq(DOC.activeElement.id, 'mdaPick', 'zánik retry tlačidla presunie fokus na živú akciu v okne');
install(catalog({ catalog_state: 'read_only', catalog_state_reason: 'Novšia schéma' }));
ok(A.isOpen(), 'samotné echo nezatvára okno'); eq(node('mdaPick').getAttribute('aria-disabled'), 'true');
eq(node('mdaColor').getAttribute('aria-disabled'), 'true'); ok(node('mdaNotice').textContent.includes('Novšia schéma'));
install(catalog({}, { sheets: [], edges: [] })); ok(!A.isOpen(), 'zmiznutá kotva invaliduje okno');

// Identity conflict je chyba otvorenia, nie úspešné okno s farebnou náhradou.
req = request(); ready(req, { ok: false, message: 'Vzhľad má konfliktnú identitu.' });
eq(node('mdaPick').getAttribute('aria-disabled'), 'true'); eq(node('mdaColor').getAttribute('aria-disabled'), 'true');
eq(node('mdaPreview').style.backgroundColor, 'var(--nx-surface-sunken)');
ok(node('mdaNotice').textContent.includes('konfliktnú identitu'));
A.close();
console.log(`OK ${n} kontrol (MR2B spoločný vzhľad)`);
