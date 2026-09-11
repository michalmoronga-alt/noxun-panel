// KOV-I: realny mini-modal, pamat volby, payload a suhrn v oboch povrchoch.
// Node + zdielany mini-DOM; serverovych `hardware` dat sa klient iba dotyka.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const dom = require('./minidom.js');
const UI = path.join(__dirname, '..', '..', 'noxun_engine', 'ui');
const html = fs.readFileSync(path.join(UI, 'panel.html'), 'utf8');
const modalHtml = html.slice(html.indexOf('<div id="tplModal"'), html.indexOf('<!-- UI-D1: modal'));
const footHtml = html.match(/<div class="tplfoot">[\s\S]*?<\/div>/)[0];
dom.DOC.body.innerHTML = '<span id="insTplMeta"></span>' + footHtml + modalHtml;
global.el = function(id){ return dom.DOC.getElementById(id); };
global.val = function(id){ return el(id).value; };
global.setVal = function(id, value){ el(id).value = value; };
global.getType = function(){ return 'lower'; };
global.esc = function(s){ return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;'); };
global.mmLabel = function(v){ return String(v); };
global.selectedCabId = 'CAB-007';
global.nxModelGuid = 'model-kovi';
global.tplNameSuggestion = 'Zásuvková';
global.TEMPLATES = [];
const statuses = [], sent = [], order = [], saved = {};
global.NX = { setStatus: function(text, bad){ statuses.push({ text: text, bad: bad }); } };
global.localStorage = {
  getItem: function(key){ return Object.prototype.hasOwnProperty.call(saved, key) ? saved[key] : null; },
  setItem: function(key, value){ saved[key] = String(value); }
};
global.window.sketchup = global.sketchup = {
  save_template_as: function(json){ order.push('save'); sent.push(JSON.parse(json)); }
};
let valid = true;
global.validateFields = function(){ return valid; };
global.flushCabinetEditsNow = function(){ order.push('flush'); };
global.NXInsert = require(path.join(UI, 'js', 'insert_state.js'));
const ctx = vm.createContext({ module: { exports: {} }, window: window, document: document,
  el: el, val: val, setVal: setVal, getType: getType, esc: esc, mmLabel: mmLabel,
  selectedCabId: selectedCabId, nxModelGuid: nxModelGuid, tplNameSuggestion: tplNameSuggestion,
  TEMPLATES: TEMPLATES, NX: NX, NXInsert: NXInsert, localStorage: localStorage, sketchup: sketchup });
vm.runInContext(fs.readFileSync(path.join(UI, 'js', 'form.js'), 'utf8'), ctx);
// Vedlajsie formularove cesty maju svoje sady; tu izolujeme hranicu ulozenia.
ctx.validateFields = global.validateFields;
ctx.flushCabinetEditsNow = global.flushCabinetEditsNow;
ctx.nxCabinetAction = function(){ if (!valid) return false; order.push('flush'); return true; }; // handshake ma vlastnu sadu CELA-B
const fm = ctx.module.exports;
const studio = require(path.join(UI, 'js', 'templates.js'));
el('tplSaveName').select = function(){}; // mini-DOM nema vyber textu inputu
let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(a, msg){ n++; assert.ok(a, msg); }

// V skutocnom HTML je checkbox aj pravdivy materialovy kontrakt.
const checkbox = el('tplSaveHardware');
ok(checkbox && checkbox.getAttribute('type') === 'checkbox', 'modal ma checkbox');
ok(checkbox.hasAttribute('checked'), 'HTML default je zapnuty');
ok(checkbox.closest('label').textContent.includes('Uložiť aj kovanie (sety a ručné položky)'),
  'checkbox ma pristupny popis setov aj rucnych poloziek');
ok(modalHtml.includes('nastavené materiály skrinky'), 'materialy skrinky sa ukladaju dalej');
ok(modalHtml.includes('Úpravy jednotlivých dielcov (materiál/ABS) sa neukladajú'), 'part upravy sa neslubuju');
ok(modalHtml.includes('ručné zámky (dĺžka výsuvu, výška a počty) nie'), 'modal prizna neprenos zamkov');

fm.openSaveTemplateModal();
eq(checkbox.checked, true, 'prve otvorenie predvoli dnesne spravanie');
eq(el('tplSaveName').value, 'Zásuvková', 'navrh mena ostava');
fm.saveTemplateAs();
eq(sent[0], { name: 'Zásuvková', cabinet_id: 'CAB-007', model_guid: 'model-kovi',
  type: 'lower', with_hardware: true }, 'server dostane bool aj existujucu identitu');
eq(order, ['flush', 'save'], 'rozpisane edity sa flushnu pred ulozenim');

fm.openSaveTemplateModal();
checkbox.checked = false;
dom.dispatch(checkbox, 'change');
fm.closeSaveTemplateModal();
fm.openSaveTemplateModal();
eq(checkbox.checked, false, 'volba prezije zrusenie a nove otvorenie modalu');
fm.saveTemplateAs();
eq(sent[1].with_hardware, false, 'vypnute kovanie je explicitny boolean false');
eq(Object.values(saved), ['0'], 'pamat je per PC v localStorage');

fm.openSaveTemplateModal();
checkbox.checked = true;
dom.dispatch(checkbox, 'change');
fm.closeSaveTemplateModal();
fm.openSaveTemplateModal();
eq(checkbox.checked, true, 'pamat dokaze zapnut volbu naspat');
const goodStorage = global.localStorage;
global.localStorage = { getItem: function(){ throw new Error('unavailable'); },
  setItem: function(){ throw new Error('unavailable'); } };
ctx.localStorage = global.localStorage;
fm.openSaveTemplateModal();
eq(checkbox.checked, true, 'nedostupna pamat zachova zapnuty default');
checkbox.checked = false;
dom.dispatch(checkbox, 'change');
fm.saveTemplateAs();
eq(sent[2].with_hardware, false, 'nedostupna pamat neblokuje vedome ulozenie bez kovania');
global.localStorage = goodStorage;
ctx.localStorage = goodStorage;
valid = false;
fm.openSaveTemplateModal();
fm.saveTemplateAs();
eq(sent.length, 3, 'neplatne edity stale blokuju ulozenie');
ok(statuses[0].bad, 'neplatne edity maju povodnu chybovu hlasku');
valid = true;

const plain = { name: 'Bez kovania', kind: 'cabinet', config: { type: 'lower', width: 600 },
  hardware: { has: false, labels: [] } };
const withHw = { name: 'So setmi', kind: 'cabinet', config: { type: 'lower', width: 600 },
  hardware: { has: true, labels: ['závesy Klasik', 'zásuvky Atira SiSy', '+2 ručné položky'] } };
const manual = { name: 'Ručné', kind: 'cabinet', config: {},
  hardware: { has: true, labels: ['+1 ručná položka'] } };
const expected = 'Kovanie: závesy Klasik · zásuvky Atira SiSy · +2 ručné položky — zámky sa neprenášajú';
eq(fm.nxTplHardwareText(withHw), expected, 'suhrn ma nazvy servera a R12');
eq(fm.nxTplHardwareText(plain), '', 'prazdna sablona nema suhrn');
eq(fm.nxTplHardwareText({ config: { hardware_sets: { hinge: 'x' } } }), '',
  'klient neodvodzuje druhu pravdu zo surovych config dat');
eq(fm.nxTplTitle(withHw).split('\n')[1], expected, 'hover Inspectora obsahuje cely suhrn');
ok(!fm.nxTplTitle(plain).includes('Kovanie:'), 'hover bez kovania ostava bez riadku');
eq(fm.nxTplBadge({ kind: 'board', config: { thickness: 18 } }), '18 mm', 'badge hrubky zachovany');

function tileNode(markup, selector){
  const wrap = dom.mkEl('div'); wrap.innerHTML = markup;
  return wrap.querySelector(selector);
}
const before = JSON.stringify(withHw);
[withHw, manual].forEach(function(tp){
  const inspector = tileNode(fm.tplTileHtml(tp, ''), '.tpltile');
  const catalogue = tileNode(studio.tplTileHtml(tp, 'cabinet'), '.stpltile');
  [inspector, catalogue].forEach(function(tile){
    ok(tile.querySelector('use[href="#i-wrench"]'), 'oba povrchy pouzivaju sprite wrench');
    ok(tile.querySelector('.tplhw').getAttribute('aria-label').includes('zámky sa neprenášajú'),
      'indikator ma pristupny suhrn vratane R12');
    ok(tile.getAttribute('title').includes(fm.nxTplHardwareText(tp)), 'hover celej dlazdice ma rovnaky suhrn');
  });
});
[fm.tplTileHtml(plain, ''), studio.tplTileHtml(plain, 'cabinet')].forEach(function(markup){
  ok(!markup.includes('#i-wrench'), 'bez kovania nevznika ikona');
  ok(!markup.includes('Kovanie:'), 'bez kovania nevznika prazdny suhrn');
});
eq(JSON.stringify(withHw), before, 'kreslenie nemeni data sablony');

const hostile = { name: 'Test', kind: 'cabinet', config: {},
  hardware: { has: true, labels: ['závesy " onclick="bad <img src=x>'] } };
[fm.tplTileHtml(hostile, ''), studio.tplTileHtml(hostile, 'cabinet')].forEach(function(markup){
  ok(markup.includes('&quot; onclick=&quot;bad &lt;img src=x&gt;'), 'nazov setu je escapovany v title aj aria-label');
  ok(!markup.includes('<img src=x>'), 'nazov setu nevytvori HTML uzol');
});

// Detail sa nasadi do existujuceho riadku a zmaze sa pri zmene sablony/druhu.
global.TEMPLATES = [plain, withHw, manual];
ctx.TEMPLATES = global.TEMPLATES;
NXInsert.setInsertType('lower');
NXInsert.setTemplateName('cabinet', withHw.name);
fm.setTplMeta();
const hint = el('tplHint');
const fullDetail = 'Kovanie zo šablóny: závesy Klasik · zásuvky Atira SiSy · +2 ručné položky — zámky sa neprenášajú';
eq(hint.title, fullDetail, 'detail ma cely text s R12 v title');
eq(hint.textContent.length, 80, 'dlhy detail sa skrati na 80 znakov');
ok(hint.textContent.endsWith('…'), 'skrateni je priznane tromi bodkami');
ok(!hint.textContent.includes('\n') && hint.classList.contains('tplhwhint'), 'detail je jeden riadok');
eq(dom.DOC.querySelectorAll('#tplHint').length, 1, 'ziadny dalsi blok detailu nepribudol');
NXInsert.setTemplateName('cabinet', manual.name);
fm.setTplMeta();
eq(hint.textContent, 'Kovanie zo šablóny: +1 ručná položka — zámky sa neprenášajú', 'kratky detail sa neoreze');
NXInsert.setTemplateName('cabinet', plain.name);
fm.setTplMeta();
eq(hint.title, '', 'prechod na sablonu bez kovania zmaze stary title');
eq(hint.textContent, 'Klik = vybrať a doladiť · dvojklik = vlož hneď.', 'povodny hint sa vrati');
ok(!hint.classList.contains('tplhwhint'), 'bez kovania nezostane specialny styl');
NXInsert.setTemplateName('cabinet', withHw.name);
NXInsert.setInsertType('board');
fm.setTplMeta();
eq(hint.title, '', 'doska nezdedi suhrn vybranej skrinky');
NXInsert.setInsertType('lower');
NXInsert.setTemplateName('cabinet', withHw.name);
global.TEMPLATES = [plain];
ctx.TEMPLATES = global.TEMPLATES;
fm.setTplMeta();
eq(hint.title, '', 'zmazana sablona nezanecha stary detail');
const css = fs.readFileSync(path.join(UI, 'css', 'panel.css'), 'utf8');
ok(/\.tplhwhint\s*\{[^}]*white-space:\s*nowrap/.test(css), 'CSS zabranuje zalomeniu detailu');
ok(/\.tpltile \.tplhw \.ic\s*\{[^}]*height:\s*12px/.test(css), 'ikona nezdedi 38 px vysku schemy');

// CELA-B review: zrusenie, nove otvorenie a uprava poli zrusia odlozene ulozenie.
valid = true;
const directGate = ctx.nxCabinetAction;
for (const cancel of [
  () => fm.closeSaveTemplateModal(),
  () => { fm.closeSaveTemplateModal(); fm.openSaveTemplateModal(); },
  () => { const input = el('tplSaveName'); input.value = 'Nový názov';
    input._listeners.input.forEach(fn => fn.call(input, {target:input})); },
  () => dom.dispatch(el('tplModal'), 'keydown', {key:'Escape'}),
  () => { checkbox.checked = !checkbox.checked; dom.dispatch(checkbox, 'change'); }
]){
  fm.openSaveTemplateModal();
  let queued;
  ctx.nxCabinetAction = function(fn){ queued = fn; ctx.cabAfterApply = {run:fn}; return false; };
  const before = sent.length;
  fm.saveTemplateAs();ok(queued, 'ulozenie caka na apply');
  cancel();eq(ctx.cabAfterApply,null,'zrusenie vycisti cakajuce ulozenie');
  ctx.nxCabinetAction = directGate;
  queued();eq(sent.length,before,'neskory apply neulozi zrusenu ani zmenenu sablonu');
  fm.closeSaveTemplateModal();
}
studio.tplCancelAsk();
console.log('KOV-I sablony: ' + n + ' assertions OK');
