// Dávka 1b-7 — TICHÝ NÁVRAT STAREJ CENY DEKORU (sweep 27.8., nálezy #8 a #9).
//
// Preco su to testy a nie klikanie (katalog su CENY REALNYCH OBJEDNAVOK):
//   1. Stara hodnota z formulara sa spajala s CERSTVYM `row_rev`. Optimisticky
//      zamok tym prestal chranit to, na co je: druhy Save presiel cez oba
//      zamky a ticho vratil cenu, ktorú medzitym priniesla „Aktualizovať
//      z Demosu". Chyba je NEVIDITELNA — bez testu ju odhali az zla faktura.
//   2. Realny scenar (#9) je bezny pracovny postup, nie exotika:
//      otvor editor dekoru -> oprav jednu hodnotu -> Esc -> aktualizuj ceny
//      z Demosu -> otvor ten isty dekor -> Ulož.
//   3. Kolizia sa NEDA vyriesit tichou volbou. Ked tú istú bunku zmenil
//      pouzivatel AJ katalog, rozhodnut musi clovek — preto sa overuje aj to,
//      ze bez rozhodnutia zapis NEODIDE.
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

const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);
const STATUS = mkEl('div');
STATUS.attrs.id = 'status';
DOC.body.appendChild(STATUS);

const SENT = [];
global.sketchup = { save_decor: function(json){ SENT.push(JSON.parse(json)); } };
global.window.sketchup = global.sketchup;

require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const M = require(path.join(JS, 'proj_materials.js'));

// --- pomocky ----------------------------------------------------------------
function rows(){ return DOC.querySelectorAll('[data-nxm-row="sheets"]'); }
function cell(idx, col){ return rows()[idx].querySelector('[data-nxm-col="' + col + '"]'); }
function submit(){ dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click'); }

function catalog(rev, over){
  const s0 = Object.assign({
    material_id: 'S18', group_id: 'GRP1', decor: 'H3303', decor_name: 'Dub Halifax',
    manufacturer: 'Egger', type: 'DTDL', thickness: 18, structure: 'ST10',
    color: [200, 180, 150], code: 'A18', price_per_m2: 18.4, row_rev: 'r18',
    label: 'H3303 DTDL 18'
  }, (over && over.s0) || {});
  const s1 = Object.assign({
    material_id: 'S36', group_id: 'GRP1', decor: 'H3303', type: 'DTDL', thickness: 36,
    structure: 'ST10', color: [200, 180, 150], code: 'A36', price_per_m2: 30,
    row_rev: 'r36', label: 'H3303 DTDL 36'
  }, (over && over.s1) || {});
  return {
    catalog_rev: rev, catalog_schema: 9, catalog_state: 'ok',
    materials: { sheets: [] },
    catalog: { sheets: [s0, s1], edges: [] }
  };
}
const KEY = 'g:GRP1';

// ===== 1) PAMAT PO ESC PRELIEVA LEN BUNKY, KTORYCH SA POUZIVATEL DOTKOL =====
//
// Scenar #9 doslova. Pred 1b-7 sa po Esc zapamatala CELA tabulka a pri dalsom
// otvoreni sa vliala do cerstveho katalogu — nova cena z Demosu zmizla.
(function(){
  NXModal.clearMemory('mat:edit:GRP1');
  M.mdSetCatalog(catalog('C1'));
  M.mdEditOpen(KEY);
  cell(0, 'code').value = 'MOJ-KOD';      // pouzivatel opravil JEDNU bunku
  NXModal.close();                        // Esc

  const mem = NXModal.memory('mat:edit:GRP1');
  ok(mem && mem.sheets, 'pamat drzi riadky');
  eq(mem.sheets.length, 1, 'a LEN riadok, v ktorom sa naozaj nieco zmenilo');
  eq(Object.keys(mem.sheets[0]).sort(), ['_base', 'code', 'material_id'],
     'z riadku LEN zmenena bunka + identita + vychodisko (ziadna cena, ziadny row_rev)');
  eq(mem.sheets[0]._base.code, 'A18',
     '`_base` je hodnota, PROTI KTOREJ pouzivatel pisal — podla nej sa pozna kolizia');

  // Medzitym „Aktualizovať z Demosu": obom doskam sa zmenila CENA.
  M.mdSetCatalog(catalog('C2', { s0: { price_per_m2: 21.9, row_rev: 'r18b' },
                                 s1: { price_per_m2: 33.5, row_rev: 'r36b' } }));
  M.mdEditOpen(KEY);
  ok(DOC.querySelector('.mmemo'), 'formular priznava, ze je z rozpisaneho konceptu');
  eq(cell(0, 'code').value, 'MOJ-KOD', 'rozpisana bunka sa vratila…');
  eq(cell(0, 'price_per_m2').value, '21,9',
     '…ale NOVA CENA Z DEMOSU ostala (jadro naleza #9 — predtym sa vratilo 18,4)');
  eq(cell(1, 'price_per_m2').value, '33,5',
     'a riadok, ktoreho sa pouzivatel vobec nedotkol, je cely cerstvy');
  eq(DOC.querySelector('.mrconf'), null, 'nic sa nekrizi — niet co rozhodovat');

  SENT.length = 0;
  submit();
  eq(SENT.length, 1, 'zapis odisiel');
  eq(SENT[0].sheets[0].price_per_m2, '21,9', 'a nesie CERSTVU cenu, nie tú z konceptu');
  eq(SENT[0].sheets[0].code, 'MOJ-KOD', 'so zmenou, ktorú pouzivatel naozaj napisal');
  M.MD.editSaved();
})();

// ===== 2) KOLIZIA: tú istú bunku zmenil pouzivatel AJ katalog ===============
(function(){
  NXModal.clearMemory('mat:edit:GRP1');
  M.mdSetCatalog(catalog('D1'));
  M.mdEditOpen(KEY);
  cell(0, 'price_per_m2').value = '25,00';   // pouzivatel prepisal CENU
  NXModal.close();

  // Demos prisiel s INOU cenou tej ISTEJ dosky.
  M.mdSetCatalog(catalog('D2', { s0: { price_per_m2: 22.5, row_rev: 'r18c' } }));
  M.mdEditOpen(KEY);

  const conf = DOC.querySelector('.mrconf');
  ok(conf, 'kolizna bunka rozsvieti pas rozhodnutia');
  const txt = String(conf.textContent);
  ok(txt.indexOf('25,00') > -1, 'a ukaze OBE hodnoty — tvoju…');
  ok(txt.indexOf('22,5') > -1, '…aj tú, ktora je v katalogu');
  ok(String(cell(0, 'price_per_m2').className).indexOf('conf') > -1,
     'a samotna bunka je oznacena (trieda `conf`, nie `bad` — tú maze `clearErrors`)');
  eq(cell(0, 'price_per_m2').value, '25,00',
     'v poli ostava hodnota pouzivatela — nic sa mu nezmazalo pod rukou');
  // PASCA: `readRows` cita KAZDY uzol s `data-nxm-col` v riadku. Keby ho niesli
  // aj rozhodovacie tlacidla, ich prazdna `value` by hodnotu bunky vymazala.
  eq(NXModal.values().sheets[0].price_per_m2, '25,00',
     'a pas rozhodnutia hodnoty riadku NEPREPISUJE (tlacidla nemaju `data-nxm-col`)');
  eq(DOC.querySelector('.mrconf').querySelector('[data-nxm-col]'), null,
     'v pase kolizie nie je ziadny uzol, ktory by sa cital ako bunka');

  // BEZ ROZHODNUTIA SA NEZAPISUJE.
  SENT.length = 0;
  submit();
  eq(SENT.length, 0, 'zapis bez rozhodnutia NEODISIEL');
  ok(String(DOC.querySelector('[data-nxm-errtop]').textContent).indexOf('rozhodni') > -1,
     'a pouzivatel sa dozvedel PRECO');
  ok(!NXModal.isBusy(), 'okno pritom nezostalo zamknute v „ukladám"');
  eq(NXModal.conflicts(), 1, 'komponent vie o jednej nerozhodnutej bunke');

  // „Prevziať z katalógu" — vyhrava Demos.
  dispatch(DOC.querySelector('[data-nxm-act="conftake"]'), 'click');
  eq(DOC.querySelector('.mrconf'), null, 'pas rozhodnutia zmizol');
  eq(NXModal.conflicts(), 0, 'a kolizia je vybavena');
  eq(cell(0, 'price_per_m2').value, '22,5', 'v poli je katalogova hodnota');
  SENT.length = 0;
  submit();
  eq(SENT.length, 1, 'teraz zapis prejde');
  eq(SENT[0].sheets[0].price_per_m2, '22,5', 's rozhodnutou hodnotou');
  M.MD.editSaved();
})();

// ===== 3) „Ponechať moju" — rozhodnutie sa NEPYTA DONEKONECNA ===============
(function(){
  NXModal.clearMemory('mat:edit:GRP1');
  M.mdSetCatalog(catalog('E1'));
  M.mdEditOpen(KEY);
  cell(0, 'price_per_m2').value = '40,00';
  NXModal.close();
  M.mdSetCatalog(catalog('E2', { s0: { price_per_m2: 19, row_rev: 'r18d' } }));
  M.mdEditOpen(KEY);
  ok(DOC.querySelector('.mrconf'), 'kolizia svieti');

  dispatch(DOC.querySelector('[data-nxm-act="confkeep"]'), 'click');
  eq(cell(0, 'price_per_m2').value, '40,00', 'moja hodnota ostala');
  eq(NXModal.conflicts(), 0, 'kolizia je rozhodnuta');
  NXModal.close();                            // Esc PO rozhodnuti

  M.mdEditOpen(KEY);
  eq(cell(0, 'price_per_m2').value, '40,00', 'rozpis prezil zatvorenie');
  eq(DOC.querySelector('.mrconf'), null,
     'a ta ista kolizia sa uz NEPYTA — rozhodnutie posunulo vychodisko');
  NXModal.clearMemory('mat:edit:GRP1');
  NXModal.close();
})();

// ===== 4) NEROZHODNUTA KOLIZIA PREZIJE ESC ==================================
//
// Inak by stacilo okno zavriet a otvorit — a tichy prepis by sa vratil.
(function(){
  NXModal.clearMemory('mat:edit:GRP1');
  M.mdSetCatalog(catalog('F1'));
  M.mdEditOpen(KEY);
  cell(0, 'price_per_m2').value = '55,00';
  NXModal.close();
  M.mdSetCatalog(catalog('F2', { s0: { price_per_m2: 17, row_rev: 'r18e' } }));
  M.mdEditOpen(KEY);
  ok(DOC.querySelector('.mrconf'), 'kolizia sa ukazala');
  NXModal.close();                            // pouzivatel ju NEROZHODOL

  M.mdEditOpen(KEY);
  ok(DOC.querySelector('.mrconf'),
     'po opatovnom otvoreni sa PYTA ZNOVA — Escape nie je sposob, ako ju obist');
  SENT.length = 0;
  submit();
  eq(SENT.length, 0, 'a zapis stale neprejde');

  // „Začať odznova" je legitimna cesta von: koncept aj kolizia zanikaju.
  dispatch(DOC.querySelector('[data-nxm-act="memreset"]'), 'click');
  eq(DOC.querySelector('.mrconf'), null, '„Začať odznova" koliziu ruší');
  eq(cell(0, 'price_per_m2').value, '17', 'a v poli je cisty CERSTVY katalog');
  eq(NXModal.conflicts(), 0, 'niet co rozhodovat');
  SENT.length = 0;
  submit();
  eq(SENT.length, 1, 'zapis znova prechadza');
  M.MD.editSaved();
})();

// ===== 5) ZOTAVENIE Z KONFLIKTU (`mdEditRefresh`) — nalez #8 ================
(function(){
  NXModal.clearMemory('mat:edit:GRP1');
  M.mdSetCatalog(catalog('G1'));
  M.mdEditOpen(KEY);
  cell(0, 'price_per_m2').value = '99,00';    // dotkol sa LEN ceny
  submit();

  // Server odmietol (`:stale`) a prislo echo: cudzia zmena KODU (iná bunka)
  // aj CENY (tá istá bunka).
  M.mdSetCatalog(catalog('G2', { s0: { code: 'CUDZI', price_per_m2: 12.5, row_rev: 'r18f' } }));
  M.MD.editBlocked();

  eq(cell(0, 'code').value, 'CUDZI',
     'nalez #8: bunka, ktorej sa pouzivatel nedotkol, dostane CERSTVU hodnotu');
  eq(cell(0, 'price_per_m2').value, '99,00', 'jeho vlastna hodnota ostava v poli');
  ok(DOC.querySelector('.mrconf'), 'ale je oznacena ako kolizna…');
  ok(String(DOC.querySelector('.mrconf').textContent).indexOf('12,5') > -1,
     '…a pas ukazuje, co je dnes v katalogu');
  ok(DOC.querySelector('.mrflag'), 'stitok „zmenené mimo editora" ostava vidiet');
  ok(String(STATUS.textContent).indexOf('rozhodni') > -1,
     'a hlaska pyta ROZHODNUTIE, nie „ulož znova"');

  SENT.length = 0;
  submit();
  eq(SENT.length, 0, 'bez rozhodnutia sa druhy zapis NEODOSLE');

  dispatch(DOC.querySelector('[data-nxm-act="confkeep"]'), 'click');
  SENT.length = 0;
  submit();
  eq(SENT.length, 1, 'po rozhodnuti zapis odide');
  eq(SENT[0].sheets[0].price_per_m2, '99,00', 's VEDOME ponechanou hodnotou');
  eq(SENT[0].sheets[0].code, 'CUDZI', 'a s cudzou zmenou, ktorú nemal preco prepisat');
  eq(SENT[0].sheets[0].row_rev, 'r18f', 'odtlacok riadku je cerstvy — zapis ma sancu prejst');
  eq(SENT[0].base_rev, 'G2', 'aj baseline katalogu');
  M.MD.editSaved();
})();

// ===== 6) STITKY PREZIJU PREKRESLENIE KONTAJNERA ============================
//
// Repeater sa pri kazdom „+ riadok" prekresluje z `readRows`, ktory cita LEN
// bunky. Keby stitky zili iba v DOM, jedno pridanie riadku by pas kolizie
// ZHASLO — a zapis by presiel bez rozhodnutia.
(function(){
  NXModal.clearMemory('mat:edit:GRP1');
  M.mdSetCatalog(catalog('H1'));
  M.mdEditOpen(KEY);
  cell(0, 'price_per_m2').value = '77,00';
  NXModal.close();
  M.mdSetCatalog(catalog('H2', { s0: { price_per_m2: 15, row_rev: 'r18g' } }));
  M.mdEditOpen(KEY);
  ok(DOC.querySelector('.mrconf'), 'kolizia svieti');

  dispatch(DOC.querySelector('[data-nxm-act="rowadd"]'), 'click');
  ok(DOC.querySelector('.mrconf'),
     'po pridani riadku pas kolizie STALE svieti (stitky ziju v stave, nie v DOM)');
  eq(cell(0, 'price_per_m2').value, '77,00', 'a rozpisana hodnota tiez');
  eq(NXModal.conflicts(), 1, 'komponent o kolizii vie dalej');
  SENT.length = 0;
  submit();
  eq(SENT.length, 0, 'takze zapis stale nepresiel');
  NXModal.clearMemory('mat:edit:GRP1');
  NXModal.close();
})();

console.log('OK test_1b7_kolizia_buniek.js — ' + n + ' kontrol');
