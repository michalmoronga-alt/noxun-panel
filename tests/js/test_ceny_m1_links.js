// CENY-M1a — odkaz na produkt pri doske a ABS bez Demosu (Štúdio → Materiály).
//
// Co tato sada strazi (package CENY-M1 §7 bod 3):
//   R16  PEVNY slot troch ikon — hlavicka ma presne tu istu sirku ako kazdy
//        riadok (Demos / rucny / UNI / ABS), stlpce su pod sebou;
//   R17  ikona „Otvoriť produkt" (siva / jantarova), title a aria-label; klik
//        otvori obchod serverom (klient posiela len kind+id) alebo formular
//        s kurzorom v poli odkazu;
//   R18  pole „Odkaz na produkt" vo formulari variantu — zivy zamok pri Demos
//        URL, hinty, lokalna chyba (formular ostava otvoreny), payload bez
//        `product_url` pri zamku;
//   R6b  formular drzi baseline z OTVORENIA — katalogove echo ho neomladi;
//        konflikt servera formular otvori nanovo s cerstvymi udajmi;
//   R1   MD_CLIENT_SCHEMA = 11.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// --- DOM stub: formulare variantu + riadok pola --------------------------------
const ELS = {};
let FOCUSED = null;
function stubEl(id){
  const n = { id, style: {}, value: '', readOnly: false, disabled: false, placeholder: '', textContent: '',
              _attrs: {}, _cls: new Set(), _row: null };
  n.classList = { add: c => n._cls.add(c), remove: c => n._cls.delete(c), contains: c => n._cls.has(c) };
  n.setAttribute = (k, v) => { n._attrs[k] = String(v); };
  n.getAttribute = k => (Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null);
  n.removeAttribute = k => { delete n._attrs[k]; };
  n.focus = () => { FOCUSED = id; };
  n.select = () => {};
  n.closest = () => n._row || (n._row = stubEl(id + '-row'));
  return n;
}
function formId(id){ return /^(ms_|me_)/.test(id) || id === 'mdSheetForm' || id === 'mdEdgeForm' || id === 'status'; }
global.window = { NX_MAT_SECTION: true };
global.document = {
  activeElement: null,
  addEventListener: function(){},
  getElementById: function(id){ if (!formId(id)) return null; return ELS[id] || (ELS[id] = stubEl(id)); },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; }
};
const SENT = [];
global.window.sketchup = new Proxy({}, { get: (_t, name) => (payload) => SENT.push({ name, payload: JSON.parse(payload) }) });
global.sketchup = global.window.sketchup;

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
require(path.join(JS, 'studio.js'));   // poradie <script> v studio.html (vzor test_st2a_mat.js)
global.NX = global.window.NX;
const M = require(path.join(JS, 'proj_materials.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }
function el(id){ return document.getElementById(id); }
function last(name){ const hit = SENT.filter(s => s.name === name); return hit.length ? hit[hit.length - 1].payload : null; }

// --- katalog -----------------------------------------------------------------
const S25 = { material_id: 'S25', decor: 'H1180', type: 'DTDL', thickness: 25, grain: 'length', price_per_m2: 31,
              code: '310418', supplier: 'Drevocentrum', sheet_size: [2800, 2070], group_id: 'G', structure: 'ST37',
              row_rev: 'r25', product_link: false };
const S25L = Object.assign({}, S25, { product_url: 'https://shop.example.sk/dtdl-25?x=1', product_link: true, row_rev: 'r25b' });
const S18D = { material_id: 'S18', decor: 'H1180', type: 'DTDL', thickness: 18, grain: 'length', price_per_m2: 20,
               demos_url: 'https://www.demos-trade.sk/h1180-18', price_checked_at: '2026-09-01T10:00:00Z',
               product_url: 'https://odlozeny.example/p', group_id: 'G', structure: 'ST37', row_rev: 'r18' };
const UNI = { material_id: 'U', decor: 'Korpus UNI', type: 'DTDL', thickness: 18, uni: true, uni_role: 'body',
              group_id: 'GU', row_rev: 'ru' };
const E08 = { abs_id: 'E08', decor: 'H1180', thickness: 0.8, width: 43, price_per_bm: 0.9, group_id: 'G',
              structure: 'ST37', row_rev: 're', product_link: false };
const E10D = { abs_id: 'E10', decor: 'H1180', thickness: 1, width: 23, price_per_bm: 0.5, group_id: 'G',
               structure: 'ST37', demos_url: 'https://www.demos-trade.sk/abs', row_rev: 're10' };
function catalog(sheets, edges){
  return { materials: { sheets: [] }, catalog: { sheets: sheets, edges: edges || [] }, protected_ids: [],
           catalog_rev: 'CR' + Math.random(), catalog_schema: 11, catalog_state: 'ok' };
}
M.mdSetCatalog(catalog([S25, S18D, UNI], [E08, E10D]));

// --- R1 -----------------------------------------------------------------------
eq(M.MD_CLIENT_SCHEMA, 11, 'klient hlasi schemu 11 (product_url)');

// --- R16: pevny slot -----------------------------------------------------------
(function(){
  const gap = '<i class="mdgap"></i>';
  eq(M.mdSlotHtml(), '<span class="mdslot">' + gap + gap + gap + '</span>', 'prazdny slot = tri medzery rovnakej sirky');
  eq(M.mdSlotHtml('A', '', 'C'), '<span class="mdslot">A' + gap + 'C</span>', 'prazdna pozicia drzi miesto');
  const sec = { sheets: [S25, S18D, UNI], edges: [E08, E10D] };
  const h = M.mdSectionRows(sec);
  const heads = h.match(/<div class="mdvhead">.*?<\/div>/g) || [];
  eq(heads.length, 2, 'hlavicka Dosky aj ABS');
  heads.forEach(function(hd){ ok(hd.indexOf('<span class="mdslot">' + gap + gap + gap + '</span><span class="mdvact">') >= 0, 'hlavicka ma ten isty slot pred akciami'); });
  const rows = h.split('<div class="mdvrow"').slice(1);
  eq(rows.length, 5, 'kazdy variant ma riadok');
  rows.forEach(function(r){
    const slot = r.match(/<span class="mdslot">(.*?)<\/span><span class="mdvact">/);
    ok(slot, 'KAZDY riadok ma slot hned pred akciami: ' + r.slice(0, 60));
    const positions = (slot[1].match(/<i class="mdgap"><\/i>|<button[^>]*>.*?<\/button>/g) || []).length;
    eq(positions, 3, 'slot ma vzdy tri pozicie');
  });
  ok(/mdprod is-missing/.test(rows[0]), 'DTDL 25 bez odkazu = jantarova ikona');
  ok(/mddm/.test(rows[1]) && !/mdprod/.test(rows[1]), 'Demos riadok ma Demos ikonu, nie odkaz');
  ok(!/mdprod/.test(rows[2]) && !/mddm/.test(rows[2]), 'UNI bez ikony odkazu aj Demosu (A7)');
  ok(/mdprod is-missing/.test(rows[3]), 'ABS bez odkazu = jantar');
  ok(/mddm/.test(rows[4]), 'ABS s Demosom ostava Demos');
  ok(rows[1].indexOf('<span class="mdslot">') < rows[1].indexOf('<span class="mdvact">'), 'poradie: slot pred akciami');
})();

// --- R17: ikona odkazu ---------------------------------------------------------
(function(){
  const miss = M.mdProductBtn('sheet', 'S25', S25);
  ok(/class="mduni mdprod is-missing"/.test(miss), 'chybajuci odkaz = is-missing');
  ok(/title="Chýba odkaz — doplniť odkaz na produkt"/.test(miss));
  ok(/aria-label="Doplniť odkaz na produkt · DTDL 25"/.test(miss));
  ok(/#i-external-link/.test(miss), 'ta ista kresba ako Demos');
  const has = M.mdProductBtn('sheet', 'S25', S25L);
  ok(/class="mduni mdprod"/.test(has) && !/is-missing/.test(has), 'odkaz je = siva');
  ok(has.indexOf('title="Otvoriť produkt v prehliadači\nshop.example.sk"') >= 0, 'tooltip ma host na druhom riadku');
  ok(/aria-label="Otvoriť produkt · DTDL 25"/.test(has));
  eq(M.mdProductBtn('sheet', 'S18', S18D), '', 'Demos vazba ikonu odkazu nekresli');
  eq(M.mdProductBtn('sheet', 'U', UNI), '', 'UNI (bez product_link) nic');
  ok(/aria-label="Doplniť odkaz na produkt · ABS 43\/0,8"/.test(M.mdProductBtn('edge', 'E08', E08)), 'ABS meno s ciarkou');
  eq(M.mdUrlHost('https://user@shop.sk:8443/a?b#c'), 'shop.sk');
  eq(M.mdUrlHost('nie-url'), '');
  // klik: odkaz je -> server (len kind+id)
  SENT.length = 0;
  M.mdProductClick('sheet', 'S25', true);
  eq(SENT.length, 1);
  eq(SENT[0].name, 'mat_product_open');
  eq(SENT[0].payload, { kind: 'sheet', id: 'S25' }, 'URL posiela VYHRADNE server');
  // klik: chyba -> formular s fokusom v poli odkazu + zvyraznenie riadku
  SENT.length = 0; FOCUSED = null;
  M.mdProductClick('sheet', 'S25', false);
  eq(SENT.length, 0, 'jantarova ikona nic neposiela');
  eq(el('mdSheetForm').style.display, '', 'formular dosky je otvoreny');
  eq(FOCUSED, 'ms_product_url', 'kurzor je v poli odkazu (C3)');
  ok(el('ms_product_url').closest('.row').classList.contains('mdflash'), 'riadok pola kratko svieti');
  FOCUSED = null;
  M.mdProductClick('edge', 'E08', false);
  eq(el('mdEdgeForm').style.display, '', 'ABS formular');
  eq(FOCUSED, 'me_product_url');
})();

// --- R18: pole vo formulari, zivy zamok, lokalna chyba, payload --------------
(function(){
  // rucna doska: pole editovatelne, prefill, hint
  M.mdSetCatalog(catalog([S25L, S18D, UNI], [E08, E10D]));
  M.mdOpenSheetForm('S25');
  const inp = el('ms_product_url');
  eq(inp.readOnly, false);
  eq(inp.value, S25L.product_url, 'prefill ulozeneho odkazu');
  eq(el('ms_product_hint').textContent, 'Otvorí sa vo webovom prehliadači.');
  // zivy zamok pri pisani do Demos URL
  inp.value = 'https://rozpisany.example/p';
  el('ms_demos_url').value = 'https://www.demos-trade.sk/x';
  M.mdProductLockSync('ms');
  eq(inp.readOnly, true, 'Demos URL zamkne odkaz ZIVO');
  eq(inp.value, '', 'zamknute pole je prazdne');
  eq(inp.placeholder, '— viazané na Demos');
  ok(el('ms_product_hint').textContent.indexOf('Položka je viazaná na Demos — odkaz aj cenu spravuje Demos') === 0, 'hint C4');
  ok(el('ms_product_hint').textContent.indexOf('Uložený ručný odkaz sa po zrušení väzby vráti.') > 0, 'odlozeny odkaz sa priznava');
  SENT.length = 0;
  M.mdSaveSheet();
  let p = last('update_sheet');
  ok(p, 'save odisiel');
  ok(!Object.prototype.hasOwnProperty.call(p, 'product_url'), 'zamknute pole sa NEPOSIELA');
  // odomknutie vrati rozpisany text
  M.mdOpenSheetForm('S25');
  el('ms_product_url').value = 'https://rozpisany.example/p';
  el('ms_demos_url').value = 'https://www.demos-trade.sk/x'; M.mdProductLockSync('ms');
  el('ms_demos_url').value = ''; M.mdProductLockSync('ms');
  eq(el('ms_product_url').readOnly, false);
  eq(el('ms_product_url').value, 'https://rozpisany.example/p', 'odomknutie vrati rozpisany text');
  // Demos doska: otvorenie = zamknute, vymazanie Demos URL vrati odlozeny odkaz
  M.mdOpenSheetForm('S18');
  eq(el('ms_product_url').readOnly, true, 'Demos doska ma pole zamknute hned pri otvoreni');
  eq(el('ms_product_url').value, '');
  el('ms_demos_url').value = ''; M.mdProductLockSync('ms');
  eq(el('ms_product_url').value, 'https://odlozeny.example/p', 'po vymazani Demos URL sa vrati odlozeny odkaz');
  el('ms_product_url').value = 'https://novy.example/p';
  SENT.length = 0;
  M.mdSaveSheet();
  p = last('update_sheet');
  eq(p.demos_url, '', 'Demos URL vymazana');
  eq(p.product_url, 'https://novy.example/p', 'a odkaz vlozeny v JEDNOM ulozeni');
  eq(p.row_rev, 'r18', 'baseline z otvorenia');
  // lokalna chyba: formular ostava otvoreny, nic neodide
  M.mdOpenSheetForm('S25');
  ['ftp://x.sk/p', 'www.x.sk', 'https://x.sk/a b', 'https:///x', 'https://x.sk/"'].forEach(function(bad){
    el('ms_product_url').value = bad;
    SENT.length = 0;
    M.mdSaveSheet();
    eq(SENT.length, 0, 'zly odkaz sa neposiela: ' + bad);
    eq(el('status').textContent, 'Odkaz nie je platná webová adresa — musí začínať http:// alebo https:// a nesmie mať medzery, úvodzovky, diakritiku ani znaky ako | { } ^.');
    eq(el('mdSheetForm').style.display, '', 'formular ostava otvoreny');
  });
  eq(M.mdProductUrlLocalError(''), null, 'prazdne = zmazanie, nie chyba');
  eq(M.mdProductUrlLocalError('http://x.sk/p'), null, 'http aj https');
  // UNI: pole skryte a neposiela sa
  M.mdOpenSheetForm('U');
  eq(el('ms_product_url').closest('.row').style.display, 'none', 'UNI pole nema');
  eq(el('ms_product_hint').style.display, 'none');
  SENT.length = 0;
  M.mdSaveSheet();
  p = last('update_sheet');
  ok(p && !Object.prototype.hasOwnProperty.call(p, 'product_url'), 'UNI odkaz neposiela');
  // ABS
  M.mdOpenEdgeForm('E10');
  eq(el('me_product_url').readOnly, true, 'ABS s Demosom zamknuta');
  M.mdOpenEdgeForm('E08');
  eq(el('me_product_url').readOnly, false);
  el('me_product_url').value = 'https://abs.example/43';
  SENT.length = 0;
  M.mdSaveEdge();
  p = last('update_edge');
  eq(p.product_url, 'https://abs.example/43');
  eq(p.row_rev, 're');
  eq(p.catalog_schema, 11);
  eq(M.mdProductLockState('', '').locked, false);
  eq(M.mdProductLockState(' x ', '').hint.indexOf('Uložený ručný odkaz'), -1, 'bez odlozeneho odkazu veta chyba');
})();

// --- R6b: baseline z otvorenia prezije echo; konflikt otvori nanovo -----------
(function(){
  M.mdSetCatalog(catalog([S25L, S18D, UNI], [E08, E10D]));
  M.mdOpenSheetForm('S25');
  el('ms_product_url').value = 'https://moj.example/p';
  // Demos apply alebo bunka inde zmenili riadok -> echo s NOVYM row_rev
  const changed = Object.assign({}, S25L, { price_per_m2: 44, demos_url: 'https://www.demos-trade.sk/h1180-25', row_rev: 'r25-NEW' });
  delete changed.product_link;
  M.MD.setCatalog(catalog([changed, S18D, UNI], [E08, E10D]));
  eq(el('mdSheetForm').style.display, '', 'echo otvoreny formular nezatvara');
  SENT.length = 0;
  M.mdSaveSheet();
  let p = last('update_sheet');
  eq(p.row_rev, 'r25b', 'baseline je z OTVORENIA — echo ho neomladilo (R6b)');
  ok(p.catalog_rev !== 'CR', 'catalog_rev je zivy (server ho pre formular nepouziva)');
  // server vrati konflikt: cerstvy katalog uz prisiel echom -> formular nanovo
  M.MD.formConflict('sheet', 'S25');
  eq(el('mdSheetForm').style.display, '', 'formular je znovu otvoreny');
  eq(el('ms_price').value, '44', 'cerstve udaje (cena z Demos apply)');
  eq(el('ms_product_url').readOnly, true, 'cerstva Demos vazba odkaz zamkla');
  SENT.length = 0;
  M.mdSaveSheet();
  p = last('update_sheet');
  eq(p.row_rev, 'r25-NEW', 'novy baseline az po znovuotvoreni');
  // ABS: to iste
  M.mdOpenEdgeForm('E08');
  M.MD.setCatalog(catalog([S25L, S18D, UNI], [Object.assign({}, E08, { price_per_bm: 2.5, row_rev: 're-NEW' }), E10D]));
  SENT.length = 0;
  M.mdSaveEdge();
  eq(last('update_edge').row_rev, 're', 'ABS baseline z otvorenia');
  M.MD.formConflict('edge', 'E08');
  eq(el('me_price').value, '2.5');
  SENT.length = 0;
  M.mdSaveEdge();
  eq(last('update_edge').row_rev, 're-NEW');
  // zaznam medzitym zmizol -> nic sa neotvara
  el('mdSheetForm').style.display = 'none';
  M.MD.formConflict('sheet', 'NEEXISTUJE');
  eq(el('mdSheetForm').style.display, 'none', 'zmiznuty zaznam formular neotvori');
  // potvrdenie duplicity (druhe ulozenie) nesie TEN ISTY baseline ako prve
  M.mdSetCatalog(catalog([S25L, S18D, UNI], [E08, E10D]));
  M.mdOpenSheetForm('S25');
  SENT.length = 0;
  M.mdSaveSheet();
  M.mdSetCatalog(catalog([Object.assign({}, S25L, { row_rev: 'echo-rev' }), S18D, UNI], [E08, E10D]));
  M.MD.flagDuplicateCode('sheet');
  SENT.length = 0;
  M.mdSaveSheet();
  eq(last('update_sheet').row_rev, 'r25b', 'znovuotvorenie po duplicite drzi baseline pokusu');
  eq(last('update_sheet').allow_duplicate_code, true);
})();

// --- predrecenzia P3: parita klienta so serverom nad spolocnou tabulkou --------
(function(){
  const table = require(path.join(__dirname, '..', 'fixtures', 'ceny_m1_product_urls.json')).rows;
  ok(table.length >= 40, 'tabulka je netrivialna');
  ok(table.some(r => r[1]) && table.some(r => !r[1]), 'tabulka ma platne aj neplatne vstupy');
  table.forEach(function(row){
    eq(M.mdProductUrlLocalError(row[0]) === null, row[1], 'parita so serverom: ' + JSON.stringify(row[0]));
  });
})();

// --- predrecenzia P3: serverove odmietnutie odkazu upravu nezahodi ------------
(function(){
  M.mdSetCatalog(catalog([S25L, S18D, UNI], [E08, E10D]));
  M.mdOpenSheetForm('S25');
  el('ms_price').value = '55';
  el('ms_code').value = 'NOVY-KOD';
  el('ms_product_url').value = 'https://ok.example/p';
  SENT.length = 0;
  M.mdSaveSheet();
  eq(SENT.length, 1, 'odoslane');
  el('mdSheetForm').style.display = 'none';        // klient formular po odoslani zatvara
  el('ms_price').value = ''; el('ms_code').value = ''; el('ms_product_url').value = '';
  FOCUSED = null;
  M.MD.formRejected('sheet');
  eq(el('mdSheetForm').style.display, '', 'formular je znovu otvoreny');
  eq(el('ms_price').value, '55', 'rozpisana cena sa nestratila');
  eq(el('ms_code').value, 'NOVY-KOD', 'ani kod');
  eq(el('ms_product_url').value, 'https://ok.example/p', 'ani odkaz');
  eq(FOCUSED, 'ms_product_url', 'kurzor v poli odkazu');
  SENT.length = 0;
  M.mdSaveSheet();
  eq(last('update_sheet').row_rev, 'r25b', 'baseline pokusu ostava');
  // ABS
  M.mdOpenEdgeForm('E08');
  el('me_price').value = '3.3';
  el('me_product_url').value = 'https://ok.example/abs';
  M.mdSaveEdge();
  el('mdEdgeForm').style.display = 'none'; el('me_price').value = '';
  M.MD.formRejected('edge');
  eq(el('mdEdgeForm').style.display, '');
  eq(el('me_price').value, '3.3');
  // cudzi druh (posledny pokus bol ABS) formular dosky neotvori
  el('mdSheetForm').style.display = 'none';
  M.MD.formRejected('sheet');
  eq(el('mdSheetForm').style.display, 'none', 'odpoved na iny formular sa ignoruje');
})();

// --- read-only katalog: jantarova ikona povie, ze upravy su vypnute ------------
(function(){
  const ro = catalog([S25], []); ro.catalog_state = 'read_only';
  M.mdSetCatalog(ro);
  el('mdSheetForm').style.display = 'none';
  M.mdProductClick('sheet', 'S25', false);
  eq(el('status').textContent, 'Katalóg je len na čítanie — úpravy sú vypnuté.');
  eq(el('mdSheetForm').style.display, 'none', 'formular sa v read-only neotvori');
  SENT.length = 0;
  M.mdProductClick('sheet', 'S25', true);
  eq(SENT[0] && SENT[0].name, 'mat_product_open', 'existujuci odkaz sa otvori aj v read-only');
})();

console.log('OK ' + n + ' kontrol (CENY-M1a odkaz na produkt)');
