// ŠT-2c PR 2c-2a — klient D-69 editora dekoru („Upraviť…") nad kostrou D-15.
//
// Preco su to testy a nie klikanie (katalog su CENY REALNYCH OBJEDNAVOK):
//   1. BASELINE. `MD_REV` prepise KAZDE katalogove echo. Keby formular cital
//      revíziu az pri odoslani, guard by po cudzom zapise „omladol" a editor
//      by prepisal zmenu, ktorú nikdy nevidel. Overuje sa to JEDINE tak, ze
//      medzi otvorenim a odoslanim pride echo s inou reviziou.
//   2. IDENTITNE POLIA. Typ, hrubka a sirka EXISTUJUCEHO variantu su jeho
//      identita — musia byt `readonly` a povedat DOVOD. Keby boli editovatelne,
//      pouzivatel by prepisal cislo a dostal by len chybu servera.
//   3. DIRTY BUNKY. Otvorenie editora zahadzuje rozpisane inline bunky toho
//      isteho dekoru — inak by v pamati zili DVE rozpisane verzie tej istej
//      ceny a zapisala by sa tá, na ktorú sa nahodou klikne.
//   4. CHYBY PRI POLIACH. Server vracia [{row, field, msg}]; keby sa nedali
//      priradit k riadku, pouzivatel by v tabulke s desiatimi cenami hladal,
//      ktorá je zla.
//   5. STLPCE REPEATERA (review 2c-1 #8). Hlavicka a bunka musia mat TU ISTU
//      sirkovu triedu, inak sa tabulka cita krivo.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXModal = require(path.join(JS, 'nx_modal.js'));
global.window.NXModal = NXModal;

// Kotva modalu + pas statusu (`MD.setStatus` ho pise priamo).
const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);
const STATUS = mkEl('div');
STATUS.attrs.id = 'status';
DOC.body.appendChild(STATUS);

// Most do Ruby: zachytavame, co by sekcia poslala serveru.
const SENT = [];
global.sketchup = { save_decor: function(json){ SENT.push(JSON.parse(json)); } };
global.window.sketchup = global.sketchup;

// Poradie <script> v `studio.html`: studio.js zaklada `window.NX`, materialy sa
// nan az napajaju (`global.NX` zrkadli bare identifier v CEF).
require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const M = require(path.join(JS, 'proj_materials.js'));

// --- katalog jedneho dekoru (tvar `full_catalog_payload`) --------------------
function catalog(rev){
  return {
    catalog_rev: rev, catalog_schema: 9, catalog_state: 'ok',
    materials: { sheets: [] },
    catalog: {
      sheets: [
        { material_id: 'H3303_ST10_DTDL_18', group_id: 'GRP1', decor: 'H3303',
          decor_name: 'Dub Halifax', manufacturer: 'Egger', type: 'DTDL', thickness: 18,
          structure: 'ST10', color: [200, 180, 150], code: 'A18', price_per_m2: 18.4,
          row_rev: 'r18', label: 'H3303 DTDL 18' },
        { material_id: 'H3303_ST10_DTDL_36', group_id: 'GRP1', decor: 'H3303',
          decor_name: 'Dub Halifax', manufacturer: 'Egger', type: 'DTDL', thickness: 36,
          structure: 'ST10', color: [200, 180, 150], row_rev: 'r36', label: 'H3303 DTDL 36' },
        { material_id: 'H3303_DUPLAK_36', group_id: 'GRP1', decor: 'H3303', type: 'DTDL',
          thickness: 36, source_material_id: 'H3303_ST10_DTDL_18', source_multiplier: 2,
          color: [200, 180, 150], row_rev: 'rd', label: 'duplák' }
      ],
      edges: [
        { abs_id: 'ABS_H3303_ST10_23X10', group_id: 'GRP1', decor: 'H3303', width: 23,
          thickness: 1, color: [200, 180, 150], code: 'E23', price_per_bm: 1.2,
          row_rev: 'ra', label: 'ABS H3303 23/1' }
      ]
    }
  };
}

const KEY = 'g:GRP1';
const GROUP = {
  key: KEY, gid: 'GRP1', decor: 'H3303', decor_name: 'Dub Halifax', manufacturer: 'Egger',
  color: [200, 180, 150],
  sheets: catalog('R1').catalog.sheets,
  edges: catalog('R1').catalog.edges
};

// ===================== 1) POLIA FORMULARA (cista funkcia) ====================

(function(){
  const f = M.mdEditFields(GROUP);
  const keys = f.filter(function(x){ return x.key; }).map(function(x){ return x.key; });
  eq(keys, ['decor', 'decor_name', 'manufacturer', 'color', 'sheets', 'edges'],
     'formular nesie identitu skupiny + dva repeatery — a NIC navyse');
  ok(f.filter(function(x){ return x.type === 'group'; }).length === 3,
     'dlhy formular ma predely (Dekor · Dosky · ABS)');
  const sheets = f.find(function(x){ return x.key === 'sheets'; });
  eq(sheets.hidden, ['material_id', 'row_rev'],
     'riadok nesie SKRYTE id + odtlacok — identita sa neodvodzuje od kodu, ktory sa prepisuje');
  eq(sheets.value.length, 2,
     'duplak sa v editore NEZOBRAZUJE (vsetko deriva zo zdroja, nema co editovat)');
  eq(sheets.value[0].thickness, '18', 'hrubka je predvyplnena');
  eq(sheets.value[0].price_per_m2, '18,4', 'cena v SK zapise (server berie ciarku aj bodku)');
  eq(sheets.value[1].price_per_m2, '', 'cena NEZADANA ostava PRAZDNA (nie 0)');
  const roCols = sheets.cols.filter(function(c){ return c.roWhen === 'material_id'; })
                            .map(function(c){ return c.key; });
  eq(roCols, ['type', 'thickness'], 'typ a hrubka existujuceho variantu su ZAMKNUTE');
  ok(sheets.cols.filter(function(c){ return c.roWhen; }).every(function(c){ return !!c.roTitle; }),
     'kazde zamknute pole povie DOVOD (D-78)');
  const edges = f.find(function(x){ return x.key === 'edges'; });
  eq(edges.hidden, ['abs_id', 'row_rev']);
  eq(edges.cols.filter(function(c){ return c.roWhen === 'abs_id'; }).map(function(c){ return c.key; }),
     ['width', 'thickness'], 'sirka aj hrubka pasky su identita');
  eq(M.mdEditKey(GROUP), 'mat:edit:GRP1',
     'kluc pamate ma konvenciu <domena>:<mode>:<ciel> — iny dekor stary rozpis zahodi');
})();

// ===================== 2) MARKUP: readonly, aria, stlpce =====================

(function(){
  const f = M.mdEditFields(GROUP);
  const sheets = f.find(function(x){ return x.key === 'sheets'; });
  const h = NXModal.rowsHtml(sheets, sheets.value);
  ok(h.indexOf('data-nxm-col="thickness" class="mtiny" aria-label="Hrúbka"') > -1,
     'bunka ma aria-label (nadpis je nad stlpcom, nie pri poli)');
  ok(h.indexOf('readonly value="18"') > -1, 'identitna bunka existujuceho riadku je readonly');
  ok(h.indexOf('Hrúbka definuje variant') > -1, 'a tooltip povie DOVOD');
  ok(h.indexOf('disabled') === -1,
     'NIE `disabled` — hodnotu musi byt vidno, dat zamerat aj skopirovat');
  // review 2c-1 #8: hlavicka MUSI mat tu istu sirkovu triedu ako bunka
  ok(h.indexOf('<span class="mtiny">Hrúbka</span>') > -1, 'hlavicka nesie sirku stlpca');
  ok(h.indexOf('<span class="mshort">Formát</span>') > -1, 'aj pri sirsom stlpci');
  // novy riadok (bez id) ma VSETKY polia editovatelne
  const empty = NXModal.rowsHtml(sheets, [{ type: '', thickness: '', code: '' }]);
  ok(empty.indexOf('readonly') === -1, 'NOVY riadok ma hrubku aj typ EDITOVATELNE');
})();

// ===================== 3) OTVORENIE: dirty bunky + baseline ==================

let editRoot = null;
(function(){
  M.mdSetCatalog(catalog('R1'));
  // rozpisana inline bunka toho isteho dekoru (data-orig != value)
  const cell = mkEl('input');
  cell.attrs.class = 'mdcell';
  cell.attrs['data-kind'] = 'sheet';
  cell.attrs['data-id'] = 'H3303_ST10_DTDL_18';
  cell.attrs['data-field'] = 'price_per_m2';
  cell.attrs['data-orig'] = '18,4';
  cell.value = '99,9';
  DOC.body.appendChild(cell);
  // a bunka CUDZIEHO dekoru — tej sa editor dotknut nesmie
  const other = mkEl('input');
  other.attrs.class = 'mdcell';
  other.attrs['data-id'] = 'INY_18';
  other.attrs['data-orig'] = '5';
  other.value = '7';
  DOC.body.appendChild(other);

  M.mdEditOpen(KEY);
  ok(NXModal.isOpen(), 'editor sa otvoril');
  eq(cell.value, '18,4', 'audit #18: rozpisana bunka TOHTO dekoru sa ZAHODILA');
  eq(other.value, '7', 'bunka INEHO dekoru ostala nedotknuta');
  ok(String(STATUS.textContent).indexOf('zahodili') > -1, 'a povedalo sa to nahlas');
  editRoot = DOC.getElementById('nxModalRoot');
  ok(editRoot.querySelectorAll('[data-nxm-row="sheets"]').length === 2, 'dve dosky v tabulke');
  ok(editRoot.querySelectorAll('[data-nxm-row="edges"]').length === 1, 'jedna paska');
  ok(editRoot.querySelector('.nxmcard.wide'), 'karta je siroka (stlpce sa nezlomia pod seba)');
})();

(function(){
  // KATALOGOVE ECHO medzi otvorenim a odoslanim: `MD_REV` sa zmeni, ale
  // formular MUSI poslat revíziu z casu OTVORENIA (audit #1).
  M.mdSetCatalog(catalog('R2'));
  const price = DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
                   .querySelector('[data-nxm-col="price_per_m2"]');
  price.value = '19,90';
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1, 'odoslalo sa presne raz');
  const p = SENT[0];
  eq(p.base_rev, 'R1', 'BASELINE JE ZMRAZENY PRI OTVORENI — nie zivy MD_REV');
  eq(p.mode, 'edit');
  eq(p.group_id, 'GRP1');
  eq(p.catalog_schema, 9, 'klient hlasi SVOJU schemu, nie echo servera');
  eq(p.allow_duplicate_code, false);
  eq(p.sheets.length, 2, 'duplak sa neposiela');
  eq(p.sheets[0].material_id, 'H3303_ST10_DTDL_18', 'riadok nesie ID variantu');
  eq(p.sheets[0].row_rev, 'r18', 'a odtlacok Z CASU OTVORENIA');
  eq(p.sheets[0].price_per_m2, '19,90', 'aj rozpisanu cenu');
  eq(p.edges[0].abs_id, 'ABS_H3303_ST10_23X10');
  ok(NXModal.isBusy(), 'zamok drzi — druhy Enter sa zahodi');
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 0, 'druhy klik pocas zapisu sa ZAHADZUJE (jedna polozka dvakrat = dva Späť)');
})();

// ===================== 4) CHYBY PRI POLIACH ==================================

(function(){
  M.MD.editErrors([
    { row: null, field: 'manufacturer', msg: 'Prázdny výrobca — na vymazanie použi tlačidlo.' },
    { row: 'sheets:1', field: 'thickness', msg: 'Hrúbka definuje variant.' },
    { row: 'edges:0', field: null, msg: 'Cena nesmie byť záporná.' },
    { row: null, field: null, msg: 'Katalóg má inú štruktúru.' }
  ]);
  ok(!NXModal.isBusy(), 'odmietnuty zapis ODOMKNE tlacidlo');
  ok(NXModal.isOpen(), 'a modal NEZATVARA — hodnoty ostavaju na mieste');
  const man = DOC.getElementById('nxm_manufacturer');
  ok(String(man.className).indexOf('bad') > -1, 'chybne ploche pole je oznacene');
  eq(man.getAttribute('aria-invalid'), 'true', 'aj pre citacku obrazovky');
  const manRow = man.closest('.mrow');
  eq(manRow.querySelector('.merr').textContent, 'Prázdny výrobca — na vymazanie použi tlačidlo.',
     'hlaska sedi PRI POLI');
  const line = DOC.querySelectorAll('[data-nxm-row="sheets"]')[1];
  eq(line.querySelector('.merr').textContent, 'Hrúbka definuje variant.',
     'chyba riadku sedi PRI RIADKU (nie na konci formulara)');
  ok(String(line.querySelector('[data-nxm-col="thickness"]').className).indexOf('bad') > -1,
     'a konkretna bunka je zvyraznena');
  const edgeLine = DOC.querySelector('[data-nxm-row="edges"]');
  eq(edgeLine.querySelector('.merr').textContent, 'Cena nesmie byť záporná.',
     'chyba bez pola sadne aspon na riadok');
  eq(DOC.querySelector('[data-nxm-errtop]').textContent, 'Katalóg má inú štruktúru.',
     'nezaraditelna chyba ide do zberneho pasu navrchu');

  // Druhy pokus chyby PREPISE, nie pripise.
  M.MD.editErrors([{ row: 'sheets:1', field: 'code', msg: 'Kód je príliš dlhý.' }]);
  eq(manRow.querySelector('.merr').textContent, '', 'stara chyba plocheho pola zmizla');
  eq(String(man.className).indexOf('bad'), -1, 'aj jeho zvyraznenie');
  eq(DOC.querySelector('[data-nxm-errtop]').textContent, '', 'zberny pas sa vycistil');
  eq(line.querySelector('.merr').textContent, 'Kód je príliš dlhý.', 'nova chyba je na mieste');
})();

// ===================== 5) VYSLEDKY ZO SERVERA ================================

(function(){
  // Odmietnutie „katalog sa zmenil": odomkni, hodnoty OSTAVAJU — a riadky sa
  // DOROVNAJU z cerstveho katalogu (review #1b), inak by konflikt nemal cestu
  // von: formular by drzal stare `row_rev` a kazdy dalsi pokus by skoncil
  // rovnako.
  M.MD.editBlocked();
  ok(!NXModal.isBusy(), 'odomknute');
  ok(NXModal.isOpen(), 'okno zije dalej — pouzivatel ma opravit cislo, nie pisat znova');
  const row = DOC.querySelectorAll('[data-nxm-row="sheets"]')[0];
  eq(row.querySelector('[data-nxm-col="price_per_m2"]').value, '19,90',
     'rozpisana cena je stale na mieste');
  eq(row.querySelector('[data-nxm-col="row_rev"]').value, 'r18',
     'odtlacok riadku je CERSTVY z katalogu (echo R2 ho neprepisalo v pamati)');
  ok(String(STATUS.textContent).indexOf('dorovnali') > -1,
     'hlaska hovori PRAVDU o tom, co sa stalo (review #1c)');

  // Duplicitny kod: druhe „Uložiť" ho POTVRDI — ale LEN pre TIE hodnoty.
  M.MD.editDuplicateCode();
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1);
  eq(SENT[0].allow_duplicate_code, true, 'druhy pokus nesie potvrdenie duplicity');
  eq(SENT[0].base_rev, 'R2', 'a UZ OMLADENY baseline — druhe uloženie ma sancu prejst');

  // review #5: po zmene ktorejkolvek hodnoty suhlas s duplicitou PADA.
  M.MD.editDuplicateCode();
  DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
     .querySelector('[data-nxm-col="code"]').value = 'INY';
  NXModal.setBusy(false);
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1);
  eq(SENT[0].allow_duplicate_code, false,
     'zmena hodnoty rusi suhlas — blanket „raz som potvrdil" nesmie vzniknut');

  // Potvrdeny zapis: zatvor + zahod pamat rozpisu.
  M.MD.editSaved();
  ok(!NXModal.isOpen(), 'potvrdeny zapis modal ZATVARA');
  eq(NXModal.memory('mat:edit:GRP1'), null,
     'a pamat rozpisu zanika — inak by sa pri dalsom otvoreni vratila stara cena');
})();

// ===== 5b) SCENAR Z REVIEW: konflikt -> druhe ULOZENIE PREJDE ================

(function(){
  M.mdSetCatalog(catalog('K1'));
  M.mdEditOpen(KEY);
  DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
     .querySelector('[data-nxm-col="price_per_m2"]').value = '25,00';
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT[0].base_rev, 'K1', 'prve odoslanie ide so starym baseline');
  eq(SENT[0].sheets[0].row_rev, 'r18');

  // server: :stale -> echo s NOVYM katalogom (cudzia zmena riadku) + editBlocked
  const fresh = catalog('K2');
  fresh.catalog.sheets[0].row_rev = 'r18-cudzi';
  fresh.catalog.sheets[0].code = 'CUDZI';
  M.mdSetCatalog(fresh);
  M.MD.editBlocked();
  ok(DOC.querySelector('.mrflag'), 'riadok zmeneny ZVONKU je VIDNO (jantárový štítok)');
  eq(DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
       .querySelector('[data-nxm-col="code"]').value, 'A18',
     'kod ostal ten, ktory ma pouzivatel v ruke (jeho hodnota sa neprepisuje potichu)');

  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1, 'druhe odoslanie prebehlo');
  eq(SENT[0].base_rev, 'K2', 'S OMLADENYM baseline…');
  eq(SENT[0].sheets[0].row_rev, 'r18-cudzi', '…a s CERSTVYM odtlackom riadku — teraz to PREJDE');
  eq(SENT[0].sheets[0].price_per_m2, '25,00', 'a stale s cenou, ktorú pouzivatel napisal');
  M.MD.editSaved();
})();

// ===== 5c) PAMAT NESMIE VRACAT SERVER-OWNED ODTLACOK (review #1a) ============

(function(){
  M.mdSetCatalog(catalog('P1'));
  M.mdEditOpen(KEY);
  DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
     .querySelector('[data-nxm-col="price_per_m2"]').value = '31,00';
  NXModal.close(); // Esc — hodnoty sa zapamätaju
  const mem = NXModal.memory('mat:edit:GRP1');
  ok(mem && mem.sheets, 'pamat drzi riadky');
  eq(Object.prototype.hasOwnProperty.call(mem.sheets[0], 'row_rev'), false,
     'ale NIE server-owned odtlacok — inak by sa vratil zastarany a zapis by sa nikdy nepodaril');
  eq(mem.sheets[0].material_id, 'H3303_ST10_DTDL_18', 'identitu riadku si pamat drzi (parovanie)');

  // katalog sa medzitym zmenil: iny odtlacok + pribudla doska
  const later = catalog('P2');
  later.catalog.sheets[0].row_rev = 'r18-neskor';
  later.catalog.sheets.push({ material_id: 'H3303_ST10_DTDL_10', group_id: 'GRP1', decor: 'H3303',
                              type: 'DTDL', thickness: 10, structure: 'ST10', color: [200, 180, 150],
                              row_rev: 'r10', label: 'H3303 DTDL 10' });
  M.mdSetCatalog(later);
  M.mdEditOpen(KEY);
  const lines = DOC.querySelectorAll('[data-nxm-row="sheets"]');
  eq(lines.length, 3, 'formular ukazuje CERSTVY pocet variantov (aj ten, co pribudol)');
  // riadok sa hlada podla IDENTITY, nie podla poradia — katalog radi varianty
  // podla hrubky, takze pribudnutá 10-ka posunula vsetko pod seba.
  const mine = lines.filter(function(l){
    return l.querySelector('[data-nxm-col="material_id"]').value === 'H3303_ST10_DTDL_18';
  })[0];
  ok(mine, 'nas riadok sa nasiel podla material_id');
  eq(mine.querySelector('[data-nxm-col="price_per_m2"]').value, '31,00',
     'rozpisana cena sa vratila…');
  eq(mine.querySelector('[data-nxm-col="row_rev"]').value, 'r18-neskor',
     '…ale odtlacok je CERSTVY z katalogu, nie z pamate');
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  const sent18 = SENT[0].sheets.filter(function(r){ return r.material_id === 'H3303_ST10_DTDL_18'; })[0];
  eq(sent18.row_rev, 'r18-neskor', 'a taky sa aj odosle');
  eq(sent18.price_per_m2, '31,00', 's cenou z pamate');
  eq(SENT[0].base_rev, 'P2');
  M.MD.editSaved();
})();

// ===================== 6) PAMAT ROZPISU vs ODMIETNUTIE =======================

(function(){
  M.mdSetCatalog(catalog('R3'));
  M.mdEditOpen(KEY);
  const price = DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
                   .querySelector('[data-nxm-col="price_per_m2"]');
  price.value = '21,00';
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  M.MD.editBlocked();
  NXModal.close(); // pouzivatel zavrel Escapom
  M.mdEditOpen(KEY);
  eq(DOC.querySelectorAll('[data-nxm-row="sheets"]')[0]
       .querySelector('[data-nxm-col="price_per_m2"]').value, '21,00',
     'rozpisany formular prezije zatvorenie (kontrakt D-15)');
  ok(DOC.querySelector('.mmemo'), 'a je VIDNO, ze ide o stary koncept');
  NXModal.clearMemory('mat:edit:GRP1');
  NXModal.close();
})();

// ===================== 7) BRANY OTVORENIA ====================================

(function(){
  const uni = catalog('R4');
  uni.catalog.sheets = [{ material_id: 'UNI_KORPUS_18', group_id: 'GRPUNI', decor: 'Korpus UNI',
                          type: 'DTDL', thickness: 18, uni: true, color: [169, 169, 178],
                          row_rev: 'ru', label: 'Korpus UNI' }];
  uni.catalog.edges = [];
  M.mdSetCatalog(uni);
  M.mdEditOpen('g:GRPUNI');
  ok(!NXModal.isOpen(), 'UNI editor NEOTVARA — pracovny material sa nahradza, needituje');
  ok(String(STATUS.textContent).indexOf('UNI') > -1, 'a povie preco');

  const ro = catalog('R5');
  ro.catalog_state = 'read_only';
  M.mdSetCatalog(ro);
  M.mdEditOpen(KEY);
  ok(!NXModal.isOpen(), 'read-only katalog editor NEOTVARA');

  M.mdSetCatalog(catalog('R6'));
  M.mdEditOpen('g:NEEXISTUJE');
  ok(!NXModal.isOpen(), 'neznamy dekor editor NEOTVARA');

  // review #4: LEGACY katalog (SCHEMA 1) editor nedostava — formular stoji na
  // `group_id`, ktore vtedy neexistuje (rovnaka brana ako susedny „Názov").
  const legacy = catalog('R6b');
  legacy.catalog_schema = 1;
  M.mdSetCatalog(legacy);
  M.mdEditOpen('d:H3303');
  ok(!NXModal.isOpen(), 'v legacy katalogu sa editor NEOTVARA');
  ok(String(STATUS.textContent).indexOf('migrácii') > -1, 'a povie preco');
  const g1 = { key: 'd:H3303', gid: '', decor: 'H3303', sheets: [], edges: [], color: [1, 2, 3] };
  ok(M.mdDetailHtml(g1).indexOf('mdEditOpen') === -1,
     'a tlacidlo „Upraviť…" sa v legacy detaile ani nekresli');
  M.mdSetCatalog(catalog('R6c'));
  ok(M.mdDetailHtml(GROUP).indexOf('mdEditOpen') > -1, 'v SCHEMA 2 detail tlacidlo MA');
  ok(M.mdDetailHtml({ key: 'g:U', gid: 'U', decor: 'Korpus UNI', uni: true, sheets: [], edges: [],
                      color: [1, 2, 3] }).indexOf('mdEditOpen') === -1,
     'UNI dlazdica ho nema');
})();

// ===================== 7b) POZNAMKA POD TABULKOU (review #8) =================

(function(){
  M.mdSetCatalog(catalog('R6d'));
  M.mdEditOpen(KEY);
  const note = DOC.querySelector('.mbody .hint');
  ok(note, 'formular ma vysvetlujucu poznamku');
  const t = String(note.textContent);
  ok(t.indexOf('nemaže') > -1, 'povie, ze riadok mimo formulara sa nemaze');
  ok(t.indexOf('+ variant') > -1 && t.indexOf('Zástenu') > -1,
     'a ze zastenu/PD treba pridat cez „+ variant" — maju dalsie povinne udaje');
  NXModal.close();
  NXModal.clearMemory('mat:edit:GRP1');
})();

// ===================== 8) ODCHOD ZO SEKCIE ===================================

(function(){
  M.mdSetCatalog(catalog('R7'));
  M.mdEditOpen(KEY);
  ok(NXModal.isOpen(), 'vychodisko: editor je otvoreny');
  M.matOnLeaveSection();
  ok(!NXModal.isOpen(),
     'odchod zo sekcie editor ZATVARA — kotva zije mimo tela sekcie a inak by visel nad Kusovnikom');
  NXModal.clearMemory('mat:edit:GRP1');
})();

console.log('OK test_st2c_editor.js — ' + n + ' kontrol');
