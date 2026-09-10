// D-124: veľká vzorka musí nasledovať aj PROGRAMOVÉ vrátenie selectu.
// Skutočné MD callbacky + skutočný NXCombo nad minimálnym DOM (vzor
// test_picker1_combo_dom.js); žiadny SketchUp zápis, server nahrádza SENT.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
let passed = 0;
function eq(a, b, msg){ passed++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ passed++; assert.ok(c, msg); }
function decode(s){ return String(s).replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&'); }
function walk(root){ return [root].concat(...(root.children || []).map(walk)); }
function el(tag, id){
  const n = { tagName: tag.toUpperCase(), id: id || '', children: [], parentNode: null,
    style: {}, className: '', disabled: false, _attrs: {}, _html: '', _text: '', _listeners: {}, options: [], selectedIndex: -1 };
  n.appendChild = c => { if (c.parentNode) c.parentNode.removeChild(c); c.parentNode = n; n.children.push(c); return c; };
  n.insertBefore = (c, ref) => { if (c.parentNode) c.parentNode.removeChild(c); c.parentNode = n; const i = n.children.indexOf(ref); n.children.splice(i < 0 ? n.children.length : i, 0, c); return c; };
  n.removeChild = c => { const i = n.children.indexOf(c); if (i >= 0) n.children.splice(i, 1); c.parentNode = null; return c; };
  n.setAttribute = (k, v) => { n._attrs[k] = String(v); };
  n.getAttribute = k => Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null;
  n.hasAttribute = k => Object.prototype.hasOwnProperty.call(n._attrs, k);
  n.removeAttribute = k => { delete n._attrs[k]; };
  n.addEventListener = (k, fn) => { (n._listeners[k] || (n._listeners[k] = [])).push(fn); };
  n.removeEventListener = () => {};
  n.dispatchEvent = ev => { if (n['on' + ev.type]) n['on' + ev.type](ev); (n._listeners[ev.type] || []).forEach(fn => fn(ev)); };
  n.contains = c => walk(n).includes(c);
  n.querySelector = () => null;
  n.querySelectorAll = selector => walk(n).filter(c => selector === 'select[data-nx-combo]'
    ? c.tagName === 'SELECT' && c.hasAttribute('data-nx-combo')
    : selector === '.cbtrigger' && c.className.split(' ').includes('cbtrigger'));
  n.getElementsByTagName = t => t === 'option' ? n.options : [];
  n.getBoundingClientRect = () => ({ width: 180, height: 54, top: 10, bottom: 64, left: 10, right: 190 });
  n.focus = () => {};
  Object.defineProperty(n, 'textContent', { get(){ return n._text; }, set(v){ n._text = String(v); } });
  Object.defineProperty(n, 'value', { get(){ return n.options[n.selectedIndex] ? n.options[n.selectedIndex].value : ''; },
    set(v){ n.selectedIndex = n.options.findIndex(o => o.value === String(v)); } });
  Object.defineProperty(n, 'innerHTML', { get(){ return n._html; }, set(v){
    n._html = String(v);
    n.children.forEach(c => { c.parentNode = null; }); n.children = [];
    if (n.tagName === 'SELECT'){
      n.options = Array.from(n._html.matchAll(/<option value="([^"]*)">([\s\S]*?)<\/option>/g), m => ({
        value: decode(m[1]), textContent: decode(m[2]), parentNode: n, disabled: false
      }));
      n.selectedIndex = n.options.length ? 0 : -1;
    }
  } });
  return n;
}
const body = el('body'), section = el('div'), details = el('details');
body.appendChild(section); section.appendChild(details); details.open = true;
body.appendChild(el('div', 'status'));
const KEYS = ['default_material_id', 'default_front_material_id', 'default_back_material_id', 'default_drawer_material_id'];
const IDS = ['md_body', 'md_front', 'md_back', 'md_drawer'];
const ROLES = ['Korpus', 'Čelá', 'Chrbát', 'Zásuvky'];
const fields = {};
IDS.forEach((id, i) => {
  const row = el('div'), label = el('label', id + '_label');
  label.textContent = ROLES[i]; row.appendChild(label);
  row.appendChild(el('div', id + '_swatch'));
  const sel = el('select', id); sel.setAttribute('data-nx-combo', 'decor'); row.appendChild(sel);
  row.appendChild(el('div', id + '_meta')); details.appendChild(row); fields[id] = sel;
});
const bar = el('div', 'mdConfirmBar'), message = el('span', 'mdConfirmText');
bar.appendChild(message); details.appendChild(bar);
const SENT = [];
global.document = { body, activeElement: null,
  getElementById: id => walk(body).find(n => n.id === id) || null,
  createElement: tag => el(tag), querySelector: () => null,
  querySelectorAll: selector => body.querySelectorAll(selector), addEventListener(){}, removeEventListener(){} };
global.window = { document, innerWidth: 1200, innerHeight: 900, addEventListener(){}, removeEventListener(){},
  sketchup: { set_project_material: p => SENT.push(JSON.parse(p)) } };
global.sketchup = window.sketchup;
global.localStorage = { getItem(){ return null; }, setItem(){}, removeItem(){} };
const JS = path.join(__dirname, '../../noxun_engine/ui/js');
global.NXCombo = require(path.join(JS, 'nx_combo.js'));
require(path.join(JS, 'studio.js'));
global.NX = window.NX;
const M = require(path.join(JS, 'proj_materials.js'));
IDS.forEach((id, i) => { fields[id].onchange = () => M.onProjMaterial(KEYS[i], fields[id].value); });
function node(id){ return document.getElementById(id); }
function photo(id){ return node(id + '_swatch').innerHTML; }
function meta(id){ return node(id + '_meta').textContent; }
function named(id){ return fields[id].__nxc.btn.getAttribute('aria-label'); }
function choose(id, value){ fields[id].value = value; fields[id].dispatchEvent({ type: 'change' }); }
function cat(records){ return { materials: { sheets: records.map(r => ({ id: r.material_id, label: r.label,
  type: r.type, thickness: r.thickness, color: r.color, uni: r.uni })) }, catalog: { sheets: records, edges: [] } }; }
const records = [
  { material_id: 'WOOD18', decor: 'H1', label: 'H1 ST9 Dub · DTDL 18 mm', type: 'DTDL', thickness: 18, color: [130, 90, 40], image_file: 'C:\\cache\\drevo 18.jpg' },
  // Rovnaký dekor, iný variant a obrázok — nehľadať iba podľa dekoru/názvu.
  { material_id: 'WOOD186', decor: 'H1', label: 'H1 ST9 Dub · DTDL 18.6 mm', type: 'DTDL', thickness: 18.6, color: [100, 60, 20], image_file: 'C:\\cache\\drevo 186.jpg' },
  { material_id: 'FRONT', label: 'F "biela" <matná> · DTDL 18 mm', type: 'DTDL', thickness: 18, color: [255, 255, 255] },
  { material_id: 'BACK', label: '101 PE Biela · HDF 3 mm', type: 'HDF', thickness: 3, color: [250, 250, 250] },
  { material_id: 'DRAWER16', label: '500 SM Biela · DTDL 16 mm', type: 'DTDL', thickness: 16, color: [255, 255, 255], image_file: 'C:\\cache\\drawer.jpg' },
  { material_id: 'BAD25', label: 'Hrubá · DTDL 25 mm', type: 'DTDL', thickness: 25, color: [10, 20, 30] },
  { material_id: 'UNI', label: 'Zásuvka UNI · UNI', type: 'DTDL', thickness: 16, color: [210, 180, 150], uni: true },
  { material_id: 'PD', label: 'Dub · PD 38 mm · 4100×600 · rub Biela', type: 'PD', thickness: 38, color: [130, 90, 40] }
];
const catalog = cat(records);
const project = { default_material_id: 'WOOD18', default_front_material_id: 'FRONT', default_back_material_id: 'BACK', default_drawer_material_id: 'DRAWER16' };
M.matApplyState({ model_guid: 'A', project, catalog });
M.MD.setCatalog(catalog);
eq(body.querySelectorAll('.cbtrigger').length, 4, 'skutočný NXCombo vytvoril štyri ovládače');
eq(meta('md_body'), 'DTDL · 18 mm', 'korpus má hrúbku svojho variantu');
eq(meta('md_back'), 'HDF · 3 mm', 'chrbát má vlastný materiál');
eq(meta('md_drawer'), 'DTDL · 16 mm', 'zásuvky majú vlastný materiál');
ok(photo('md_body').includes('file:///C:/cache/drevo%2018.jpg'), 'foto používa lokálny image_file a existujúci URL helper');
eq(named('md_front'), 'Čelá: F "biela" <matná> · DTDL 18 mm', 'prístupný názov reálneho triggera obsahuje rolu a celý serverový label');

choose('md_body', 'WOOD186');
eq(meta('md_body'), 'DTDL · 18,6 mm', 'change aktualizuje náhľad konkrétneho variantu');
ok(photo('md_body').includes('drevo%20186.jpg'), 'rovnaký dekor nezamení variant fotografie');
eq(SENT[0], { key: KEYS[0], value: 'WOOD186', model_guid: 'A' }, 'výber ide pôvodným callbackom a nesie model');
const pending = { key: KEYS[0], value: 'WOOD186', model_guid: 'A', old_default: 'WOOD18', adopting_ids: ['CAB-1'], recompute_ids: [] };
M.MD.confirmDefault({ key: KEYS[0], current: 'WOOD18', pending, message: 'Zmení sa hrúbka.' });
eq(fields.md_body.value, 'WOOD18', 'ponuka vráti select bez change');
eq(meta('md_body'), 'DTDL · 18 mm', 'a vráti metadáta');
ok(photo('md_body').includes('drevo%2018.jpg'), 'a pôvodnú fotografiu');
ok(named('md_body').includes('DTDL 18 mm'), 'a prístupný názov triggera');
eq(SENT.length, 1, 'programový návrat nespustil druhú mutáciu');
eq(bar.style.display, '', 'ponuka zostáva viditeľná');
M.mdCancelProject();
eq(bar.style.display, 'none', 'Zrušiť skryje ponuku');
eq(meta('md_body'), 'DTDL · 18 mm', 'Zrušiť ponechá potvrdený materiál');
M.mdConfirmProject();
eq(SENT.length, 1, 'zrušenú ponuku nemožno odoslať');

M.MD.confirmDefault({ key: KEYS[0], current: 'WOOD18', pending });
M.mdConfirmProject();
eq(SENT[1].confirm, pending, 'potvrdenie odošle celý pôvodný kontrakt');
eq(SENT[1].value, 'WOOD186', 'potvrdenie neprečíta vrátený select');
const adopted = { ...project, default_material_id: 'WOOD186' };
M.matApplyState({ model_guid: 'A', project: adopted });
M.MD.setCatalog(catalog);
eq(meta('md_body'), 'DTDL · 18,6 mm', 'prijatá zmena zo servera obnoví náhľad');

choose('md_drawer', 'WOOD18');
const drawerPending = { ...pending, key: KEYS[3], value: 'WOOD18', old_default: 'DRAWER16', adopting_ids: [], recompute_ids: ['CAB-2'] };
M.MD.confirmDefault({ key: KEYS[3], current: 'DRAWER16', pending: drawerPending });
eq(meta('md_drawer'), 'DTDL · 16 mm', 'kompatibilita zásuvky používa rovnaký návrat');
ok(photo('md_drawer').includes('drawer.jpg'), 'zásuvke sa vráti aj fotografia');
choose('md_front', 'PD');
eq(bar.style.display, 'none', 'nový výber v inom kanáli ruší starú ponuku');
ok(named('md_front').includes('4100×600 · rub Biela'), 'trigger nestratil rozlíšenie formátu a rubu');
choose('md_drawer', 'BAD25');
const sentBeforeReset = SENT.length;
M.MD.resetProject({ key: KEYS[3], current: 'DRAWER16' });
eq(meta('md_drawer'), 'DTDL · 16 mm', 'tvrdé odmietnutie 25 mm vráti náhľad');
eq(SENT.length, sentBeforeReset, 'tvrdé odmietnutie nevytvára ďalší callback');

choose('md_drawer', 'UNI');
eq(meta('md_drawer'), 'Pracovný materiál UNI', 'UNI neukazuje katalógovú hrúbku ako výrobnú');
eq(photo('md_drawer'), '', 'UNI nededí fotografiu starého výberu');
fields.md_body.value = 'MISSING';
M.onProjMaterial(KEYS[0], 'MISSING');
eq(photo('md_body'), '', 'neznámy materiál neukazuje fotografiu iného ID');
eq(node('md_body_swatch').style.backgroundColor, '', 'ani jeho RGB');

// Echo môže meniť menovku aj obrázok pri rovnakom ID; potvrdenia sú neplatné.
const updated = cat(records.map(r => r.material_id === 'WOOD186'
  ? { ...r, label: 'Premenovaný dub · DTDL 18.6 mm', image_file: '', image_url: 'https://example.invalid/remote.jpg', color: [1, 2, 3] } : r));
M.MD.confirmDefault({ key: KEYS[0], current: 'WOOD186', pending });
M.MD.setCatalog(updated);
eq(photo('md_body'), '', 'katalógové echo odstráni staré foto; remote URL sa nepoužije');
eq(node('md_body_swatch').style.backgroundColor, '#010203', 'a zmení RGB toho istého ID');
ok(named('md_body').includes('Premenovaný dub'), 'echo aktualizuje aj prístupný názov');
eq(bar.style.display, 'none', 'echo ruší staré potvrdenie');

// Prepnutie dokumentu počas neprítomnosti sekcie; telo i ručné zbalenie žijú.
details.open = false;
M.MD.confirmDefault({ key: KEYS[0], current: 'WOOD186', pending });
body.removeChild(section);
const projectB = { default_material_id: 'FRONT', default_front_material_id: 'PD', default_back_material_id: 'BACK', default_drawer_material_id: 'UNI' };
M.matApplyState({ model_guid: 'B', project: projectB, catalog: updated });
M.MD.setCatalog(updated);
const sentBeforeModel = SENT.length;
M.mdConfirmProject();
eq(SENT.length, sentBeforeModel, 'nový dokument zahodil odložené potvrdenie');
body.appendChild(section);
M.MD.setCatalog(updated);
IDS.forEach((id, i) => eq(fields[id].value, projectB[KEYS[i]], 'návrat sekcie používa nový projekt: ' + id));
eq(body.querySelectorAll('.cbtrigger').length, 4, 'návrat nevytvoril duplicitné pickery');
eq(details.open, false, 'obnova dát neotvorila ručne zbalený blok');
eq(photo('md_body'), '', 'B nezostal s obrázkom korpusu A');
eq(meta('md_drawer'), 'Pracovný materiál UNI', 'nový projekt má vlastné zásuvky');
choose('md_body', 'WOOD18');
eq(SENT[SENT.length - 1].model_guid, 'B', 'nasledujúci výber nesie identitu nového dokumentu');
console.log(`OK test_d124_predvolby.js — ${passed} kontrol`);
