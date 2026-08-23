// ŠT-2c PR 2c-2b — klient „Pridať ručne" (D-69 editor v rezime `create`)
// a ZANIK zakladania dekoru z batch formulara s preset cipmi.
//
// Preco su to testy a nie klikanie (katalog su CENY REALNYCH OBJEDNAVOK):
//   1. ROVNAKE POLIA BEZ OHLADU NA VSTUP (D-69). Keby sa prazdny formular
//      a formular „Upraviť…" rozisli v stlpcoch, pouzivatel by pri zakladani
//      zadaval ine udaje ako pri oprave — a jeden z tokov by musel dopisovat
//      zvysok inde.
//   2. ŠTRUKTÚRA. Je sucastou identity variantu, takze sa uz NEDA dopisat.
//      Ked ju klient nevleje do zakladanych riadkov, dekor vznikne bez nej
//      a jedinou opravou je zmazat ho a zalozit znova.
//   3. USPECH -> DETAIL. Po zalozeni musi pouzivatel stat v novom dekore
//      (dopisuje tam ceny). Inak sa formular zavrie do prazdna a nikto nevie,
//      ci zapis vobec prebehol.
//   4. ZANIK BATCH ZAKLADANIA. Dve cesty na zalozenie dekoru = dve rozne sady
//      pravidiel a dve pamate rozpisu; guard drzi, ze ostala JEDNA.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXModal = require(path.join(JS, 'nx_modal.js'));
global.window.NXModal = NXModal;

// Kotva modalu, pas statusu a uzly, ktore `mdRenderAll` naozaj hlada
// (`mdDecorList` je tu ZAMERNE — bez neho by sa skok do detailu neoveril).
['nxModalRoot', 'status', 'mdDecorList', 'mdDecorForm', 'mdSheetForm', 'mdEdgeForm']
  .forEach(function(id){
    const el = mkEl(id === 'status' ? 'div' : 'div');
    el.attrs.id = id;
    DOC.body.appendChild(el);
  });
const STATUS = DOC.getElementById('status');
const LIST = DOC.getElementById('mdDecorList');
const DECORFORM = DOC.getElementById('mdDecorForm');

const SENT = [];
global.sketchup = {
  save_decor: function(json){ SENT.push(JSON.parse(json)); },
  add_decor_batch: function(json){ SENT.push(JSON.parse(json)); }
};
global.window.sketchup = global.sketchup;

require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const M = require(path.join(JS, 'proj_materials.js'));

// --- katalog (tvar `full_catalog_payload`) ----------------------------------
function catalog(rev){
  return {
    catalog_rev: rev, catalog_schema: 9, catalog_state: 'ok',
    materials: { sheets: [] },
    catalog: {
      sheets: [
        { material_id: 'H3303_ST10_DTDL_18', group_id: 'GRP1', decor: 'H3303',
          decor_name: 'Dub Halifax', manufacturer: 'Egger', type: 'DTDL', thickness: 18,
          structure: 'ST10', color: [200, 180, 150], code: 'A18', price_per_m2: 18.4,
          row_rev: 'r18', label: 'H3303 DTDL 18' }
      ],
      edges: []
    }
  };
}

// Katalog PO zapise — presne to, co by prislo echom pred `MD.editSaved`.
function catalogWithNew(rev){
  const c = catalog(rev);
  c.catalog.sheets.push({ material_id: 'N9001_ST10_DTDL_18', group_id: 'GRPNEW', decor: 'N9001',
                          decor_name: 'Testovací dub', manufacturer: 'Egger', type: 'DTDL',
                          thickness: 18, structure: 'ST10', color: [16, 32, 48], code: 'K-18',
                          price_per_m2: 18.4, row_rev: 'rn', label: 'N9001 DTDL 18' });
  return c;
}

// ===================== 1) POLIA PRAZDNEHO FORMULARA ==========================

(function(){
  const f = M.mdCreateFields();
  const keys = f.filter(function(x){ return x.key; }).map(function(x){ return x.key; });
  eq(keys, ['decor', 'decor_name', 'manufacturer', 'structure', 'grain', 'color', 'sheets', 'edges'],
     'identita skupiny + struktura a smer dekoru (tie existujuca skupina uz ma) + dva repeatery');
  ok(f.filter(function(x){ return x.type === 'group'; }).length === 3,
     'rovnake predely ako pri uprave (Dekor · Dosky · ABS)');
  const flat = f.filter(function(x){ return x.key && x.type !== 'rows'; });
  ok(flat.every(function(x){ return x.key === 'grain' || x.key === 'color' || x.value === ''; }),
     'formular je PRAZDNY — ziadna predvyplnená identita');
  eq(f.find(function(x){ return x.key === 'grain'; }).value, 'length',
     'smer dekoru ma zmysluplnu predvolbu (nie prazdno)');

  // D-69: TIE ISTE stlpce ako pri uprave — inak by boli dva rôzne formuláre.
  const editFields = M.mdEditFields({ key: 'g:GRP1', gid: 'GRP1', decor: 'H3303', sheets: [], edges: [] });
  ['sheets', 'edges'].forEach(function(k){
    const a = M.mdCreateFields().find(function(x){ return x.key === k; });
    const b = editFields.find(function(x){ return x.key === k; });
    eq(a.cols, b.cols, 'stlpce „' + k + '" su ZHODNE s formularom „Upraviť…"');
    eq(a.hidden, b.hidden, 'aj skryte kluce riadku');
    eq(a.value, [], 'ale hodnoty zacinaju PRAZDNE');
  });
  const sheets = M.mdCreateFields().find(function(x){ return x.key === 'sheets'; });
  ok(String(sheets.empty).indexOf('aspoň jednu') > -1,
     'prazdna tabulka povie, ze aspon jedna doska je potrebna (server to vyzaduje)');
})();

// ===================== 2) PAYLOAD ============================================

(function(){
  const v = { decor: 'N9001', decor_name: 'Testovací dub', manufacturer: 'Egger',
              structure: 'ST10', grain: 'width', color: '#102030',
              sheets: [{ type: 'DTDL', thickness: '18', code: 'K-18' },
                       { type: 'DTDL', thickness: '36', structure: 'PW' }],
              edges: [{ width: '23', thickness: '1' }] };
  const p = M.mdCreatePayload(v, { rev: 'R1' });
  eq(p.mode, 'create');
  eq(p.group_id, '', 'skupina este neexistuje — group_id posiela az server spat');
  eq(p.base_rev, 'R1', 'baseline je zmrazeny z casu OTVORENIA');
  eq(p.catalog_schema, 9, 'klient hlasi SVOJU schemu');
  eq(p.grain, 'width');
  eq(p.color, '#102030');
  eq(p.allow_duplicate_code, false);
  eq(p.sheets[0].structure, 'ST10',
     'ŠTRUKTÚRA skupiny sa vlieva do riadku — je to identita variantu a dopisat sa uz neda');
  eq(p.sheets[1].structure, 'PW', 'vlastna hodnota riadku ma prednost');
  eq(p.edges[0].structure, 'ST10', 'aj do pasky');
  eq(p.sheets[0].code, 'K-18', 'a ostatne hodnoty ostavaju nedotknute');

  // bez struktury sa nic nedomysla (server ju odvodi od skupiny)
  const bare = M.mdCreatePayload({ structure: '  ', sheets: [{ type: 'DTDL' }] }, { rev: 'R1' });
  eq(Object.prototype.hasOwnProperty.call(bare.sheets[0], 'structure'), false,
     'prazdna struktura NEZAKLADA pole — ziadna vymyslena hodnota');
  eq(M.mdCreateRows(null, 'ST10'), [], 'ziadne riadky = prazdne pole, ziadny pad');
})();

// ===================== 3) OTVORENIE + ODOSLANIE ==============================

(function(){
  M.mdSetCatalog(catalog('R1'));
  M.mdCreateOpen();
  ok(NXModal.isOpen(), 'prazdny formular sa otvoril');
  const root = DOC.getElementById('nxModalRoot');
  ok(root.querySelector('.nxmcard.wide'), 'karta je siroka (rovnaka ako pri uprave)');
  eq(root.querySelectorAll('[data-nxm-row="sheets"]').length, 0, 'ziadne dosky');
  eq(root.querySelectorAll('[data-nxm-row="edges"]').length, 0, 'ziadne pasky');
  ok(String(root.querySelector('.mhead h3').textContent).indexOf('ručne') > -1,
     'titulok hovori, ze ide o RUCNE pridanie (mockup: „Pridať materiál ručne")');
  ok(String(root.querySelector('[data-nxm-act="submit"]').textContent).indexOf('katalógu') > -1,
     'potvrdenie je „Pridať do katalógu" (nie „Uložiť" — nic sa neprepisuje)');
  const note = String(root.querySelector('.mbody .hint').textContent);
  ok(note.indexOf('Zástenu') > -1 || note.indexOf('Zásteny') > -1,
     'poznamka priznava, ze zastena/PD sem nepatria…');
  ok(note.indexOf('+ variant') > -1, '…a povie, KDE sa zakladaju');
  ok(note.indexOf('zápisom') > -1, 'a varuje pred preklepom v cisle dekoru');

  // vyplnenie: identita + jedna doska pridana tlacidlom „+"
  DOC.getElementById('nxm_decor').value = 'N9001';
  DOC.getElementById('nxm_decor_name').value = 'Testovací dub';
  DOC.getElementById('nxm_manufacturer').value = 'Egger';
  DOC.getElementById('nxm_structure').value = 'ST10';
  dispatch(root.querySelector('[data-nxm-act="rowadd"]'), 'click');
  const line = root.querySelectorAll('[data-nxm-row="sheets"]')[0];
  ok(line, 'tlacidlo „+" pridalo riadok');
  ok(!line.querySelector('[data-nxm-col="thickness"]').hasAttribute('readonly'),
     'NOVY riadok ma vsetky polia editovatelne (ziadna cudzia identita)');
  line.querySelector('[data-nxm-col="type"]').value = 'DTDL';
  line.querySelector('[data-nxm-col="thickness"]').value = '18';
  line.querySelector('[data-nxm-col="price_per_m2"]').value = '18,40';

  // katalogove echo medzi otvorenim a odoslanim NESMIE omladit baseline
  M.mdSetCatalog(catalog('R2'));
  SENT.length = 0;
  dispatch(root.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1, 'odoslalo sa presne raz');
  const p = SENT[0];
  eq(p.mode, 'create');
  eq(p.base_rev, 'R1', 'BASELINE JE ZMRAZENY PRI OTVORENI');
  eq(p.decor, 'N9001');
  eq(p.sheets.length, 1);
  eq(p.sheets[0].thickness, '18');
  eq(p.sheets[0].structure, 'ST10', 'struktura skupiny sa vliala do riadku');
  eq(p.sheets[0].price_per_m2, '18,40');
  ok(!p.sheets[0].material_id, 'riadok nenesie ziadne ID — je novy');
  ok(NXModal.isBusy(), 'zamok drzi — druhy Enter sa zahodi');
  SENT.length = 0;
  dispatch(root.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 0, 'druhy klik pocas zapisu sa ZAHADZUJE (dekor dvakrat)');
})();

// ===================== 4) ODMIETNUTIE: chyby a konflikt ======================

(function(){
  M.MD.editErrors([
    { row: null, field: 'decor', msg: 'Číslo dekoru je povinné.' },
    { row: 'sheets:0', field: 'type', msg: 'Typ dosky je povinný.' }
  ]);
  ok(!NXModal.isBusy(), 'odmietnuty zapis ODOMKNE tlacidlo');
  ok(NXModal.isOpen(), 'a modal NEZATVARA — hodnoty ostavaju');
  const dec = DOC.getElementById('nxm_decor');
  ok(String(dec.className).indexOf('bad') > -1, 'chybne pole identity je oznacene');
  eq(dec.closest('.mrow').querySelector('.merr').textContent, 'Číslo dekoru je povinné.');
  eq(DOC.querySelectorAll('[data-nxm-row="sheets"]')[0].querySelector('.merr').textContent,
     'Typ dosky je povinný.', 'chyba riadku sedi PRI RIADKU');

  // :stale pri zakladani — omladit baseline je JEDINA cesta von
  M.mdSetCatalog(catalog('R3'));
  M.MD.editBlocked();
  ok(NXModal.isOpen(), 'okno zije dalej');
  eq(DOC.getElementById('nxm_decor').value, 'N9001', 'rozpisana identita ostala');
  // (review 2c-2b #4) Pri ZAKLADANI sa nic nedorovnava — v katalogu ziadny nas
  // riadok nie je, takze hlaska editu by klamala o tom, co sa stalo.
  const blocked = String(STATUS.textContent);
  ok(blocked.indexOf('skús uložiť znova') > -1,
     'hlaska create vetvy hovori PRAVDU: „Katalóg sa medzitým zmenil — skús uložiť znova."');
  ok(blocked.indexOf('dorovnali') === -1,
     'a NEtvrdi, ze sa riadky dorovnali (to je vec editu)');
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT[0].base_rev, 'R3', 'baseline OMLADOL — druhy pokus ma sancu prejst');
})();

// ===================== 5) USPECH -> DETAIL NOVEHO DEKORU =====================

(function(){
  // Server posiela cerstvy katalog PRED „ulozene" — dlazdica uz existuje.
  M.mdSetCatalog(catalogWithNew('R4'));
  M.MD.editSaved({ mode: 'create', group_id: 'GRPNEW' });
  ok(!NXModal.isOpen(), 'potvrdeny zapis modal ZATVARA');
  eq(NXModal.memory('mat:create'), null,
     'a pamat rozpisu zanika — inak by sa pri dalsom „Pridať ručne" vratil stary dekor');
  const html = String(LIST.innerHTML);
  ok(html.indexOf('N9001') > -1, 'sekcia stoji v DETAILE noveho dekoru…');
  ok(html.indexOf('mdEditOpen') > -1, '…a v nom je „Upraviť…" (ceny sa doplnaju tam)');
})();

// ===================== 6) PAMAT ROZPISU (mat:create) =========================

(function(){
  M.mdSetCatalog(catalog('R5'));
  M.mdCreateOpen();
  DOC.getElementById('nxm_decor').value = 'ROZPISANY';
  NXModal.close();                       // Esc — hodnoty sa zapamätaju
  const mem = NXModal.memory('mat:create');
  ok(mem && mem.decor === 'ROZPISANY', 'rozpisany dekor prezil zatvorenie (kontrakt D-15)');
  M.mdCreateOpen();
  eq(DOC.getElementById('nxm_decor').value, 'ROZPISANY', 'a vratil sa pri dalsom otvoreni');
  ok(DOC.querySelector('.mmemo'), 'a je VIDNO, ze ide o stary koncept');

  // slot `mat:create` je NEZAVISLY od `mat:edit:<dekor>` — su to ine ciele
  M.mdEditOpen('g:GRP1');
  ok(NXModal.memory('mat:create'), 'otvorenie editora INEHO dekoru rozpis noveho NEZAHADZUJE');
  NXModal.close();
  NXModal.clearMemory('mat:create');
  NXModal.clearMemory('mat:edit:GRP1');
})();

// ===================== 7) BRANY OTVORENIA ====================================

(function(){
  const ro = catalog('R6');
  ro.catalog_state = 'read_only';
  M.mdSetCatalog(ro);
  M.mdCreateOpen();
  ok(!NXModal.isOpen(), 'read-only katalog zakladanie NEOTVARA');

  const legacy = catalog('R7');
  legacy.catalog_schema = 1;
  M.mdSetCatalog(legacy);
  M.mdCreateOpen();
  ok(!NXModal.isOpen(), 'v legacy katalogu (pred migraciou na skupiny) tiez nie');
  ok(String(STATUS.textContent).indexOf('migrácii') > -1, 'a povie preco');

  M.mdSetCatalog(catalog('R8'));
  M.mdCreateOpen();
  ok(NXModal.isOpen(), 'nad zdravym katalogom sa otvara');
  M.matOnLeaveSection();
  ok(!NXModal.isOpen(), 'odchod zo sekcie ho zatvara (kotva zije mimo tela sekcie)');
  NXModal.clearMemory('mat:create');
})();

// ===================== 8) ZANIK ZAKLADANIA Z BATCH FORMULARA =================

(function(){
  M.mdSetCatalog(catalog('R9'));
  DECORFORM.style.display = 'none';
  SENT.length = 0;
  M.mdOpenDecorForm(null);
  eq(DECORFORM.style.display, 'none',
     'batch formular sa BEZ dekoru uz NEOTVARA — zalozil by skupinu s prazdnym cislom');
  eq(SENT.length, 0, 'a nic neposlal');
  ok(String(STATUS.textContent).indexOf('Pridať ručne') > -1,
     'hlaska posiela na JEDINU cestu zakladania');
  M.mdOpenDecorForm('g:NEEXISTUJE');
  eq(DECORFORM.style.display, 'none', 'ani s neznamym dekorom');

  // lista sekcie vedie na D-69 editor, nie na batch formular
  const tools = M.matToolsHtml({ ro: false, q: '', mode: 'man' });
  ok(/id="mdNewDecorBtn"[^>]*onclick="mdCreateOpen\(\)"/.test(tools),
     '„Pridať ručne" otvara D-69 editor (mode create)');
  ok(tools.indexOf('mdOpenDecorForm(null)') === -1,
     'a na zaniknutu batch cestu uz nevedie NIC');

  const src = fs.readFileSync(path.join(JS, 'proj_materials.js'), 'utf8');
  ok(src.indexOf('nd_color') === -1,
     'pole farby v batch formulari ZANIKLO — skupina tam vzdy existuje a farbu si drzi');
  ok(src.indexOf('mdStoreLastSet') === -1 && src.indexOf('nx_decor_last_set') === -1,
     'localStorage pamat preset sady je PREC (jedina pamat rozpisu je v NXModal)');
  const html = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');
  ok(html.indexOf('id="nd_color"') === -1, 'a nie je ani v markupe');
  ok(/id="nd_decor"[^>]*disabled/.test(html) && /id="nd_manufacturer"[^>]*disabled/.test(html),
     'identita skupiny je v „+ variant" len na citanie');
})();

console.log('OK test_st2c_create.js — ' + n + ' kontrol');
