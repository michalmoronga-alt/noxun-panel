// KOV-H2 — AD-HOC KOVANIE V INSPECTOROVI (riadky, modal, zápis) + PÔVOD
// v sekcii Nákup Štúdia.
//
// Preco su to testy a nie klikanie:
//   1. `values()` pri poli `lookup` musi vratit LEN KOD. Keby vratilo aj nazov
//      alebo cenu z obrazovky, dostala by sa do configu cena, ktora uz neplati
//      (KOV-H1 BLOCKER 2 / FIX 12) — a to POTICHU, lebo nakup by vyzeral spravne.
//   2. Odpovede hladania chodia ASYNCHRONNE. Bez zahodenia starsej generacie by
//      pomalsie kolo prepisalo cerstvejsie vysledky a pouzivatel by vybral
//      polozku z ineho dotazu, nez ma pred sebou.
//   3. Zapis ide EXISTUJUCOU cestou (`collectAll` -> `apply_all`) a modal caka
//      na vysledok. Keby `hwManualResult(false)` modal zatvoril, pouzivatel by
//      prisiel o rozpisany formular a nedozvedel by sa preco.
//   4. `hwManual` je pass-through: `|| []` by z „o polozkach neviem" spravilo
//      „polozky nie su" a najblizsi apply by ich zmazal.
//   5. Nakupny riadok je SUCET — bez rozkliku povodu sa neda zistit, ci kus
//      objednava set alebo clovek rucne.
//
// MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
//   1. `hwManualRecord` posiela pri KATALOGOVEJ polozke aj nazov a cenu,
//   2. `onHwManualDel` posle `hwManual = null` namiesto zoznamu bez polozky,
//   3. `onHwManualResult(false, …)` modal ZATVORI (namiesto ponechania s hodnotami),
//   4. `values()` vracia pri `lookup` aj TEXT polozky (nielen kod),
//   5. odpoved so STARSOU generaciou sa spracuje (prepise ponuku starym kolom),
//   6. blok rucnych poloziek sa kresli NAD boxmi vlastnikov (tlacidlo nie je posledne).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch, textOf } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// --- prostredie panela (globaly, ktore hardware.js pouziva) ------------------
const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);

global.esc = function(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
global.el = function(id){ return DOC.getElementById(id); };
global.NXIcons = { svg: function(name){ return '<svg class="ic"><use href="#i-' + name + '"/></svg>'; } };

const STATUS = [];
global.NX = { setStatus: function(msg, err){ STATUS.push({ msg: msg, err: !!err }); } };

const SENT = [];                        // co odislo do Ruby
global.sketchup = {
  apply_all: function(p){ SENT.push({ cb: 'apply_all', data: JSON.parse(p) }); },
  hw_manual_search: function(p){ SENT.push({ cb: 'hw_manual_search', data: JSON.parse(p) }); }
};
global.window.sketchup = global.sketchup;

global.nxDocPayload = function(p){ return JSON.stringify(p); };
global.selectedCabId = 'CAB-002';
global.cabEditsInFlight = false;
let VALID = true;
global.validateFields = function(){ return VALID; };
let CANCELS = 0;
global.cancelCabinetEdits = function(){ CANCELS++; };
// Zrkadlo `collectAll()` z form.js: kluc sa posiela LEN ked existuje.
global.collectAll = function(){
  const c = { width: 600, height: 720 };
  if (global.hwManual) c.hardware_manual = global.hwManual;
  return c;
};

global.NXModal = require(path.join(JS, 'nx_modal.js'));
const HW = require(path.join(JS, 'hardware.js'));

const OWNERS = [
  { key: null, label: 'celá skrinka' },
  { key: 'front:F1/wing:left', label: 'F1 · dvierka ľavé' },
  { key: 'zone:Z1/shelf:1', label: 'Polica 1' }
];
const CAT_ITEM = { id: 'H1', owner_part_key: 'front:F1/wing:left',
                   owner_label: 'F1 · dvierka ľavé', owner_missing: false,
                   source: 'catalog', code: '93240', name: 'Bystrica — rektifikačný uholník',
                   unit: 'ks', price_eur_vat: 1.14, qty: 2, note: '', catalog_missing: false };
const FREE_ITEM = { id: 'H2', owner_part_key: null, owner_label: null, owner_missing: false,
                    source: 'free', code: '', name: 'Zámok Abloy', unit: 'ks',
                    price_eur_vat: 12.0, qty: 1, note: 'podľa priania zákazníka',
                    catalog_missing: false };

function reset(state){
  global.hwManual = (state && 'manual' in state) ? state.manual : [];
  global.hwManualView = (state && state.view) || [];
  global.hwManualOwners = (state && state.owners) || OWNERS;
  SENT.length = 0;
  STATUS.length = 0;
  CANCELS = 0;
  VALID = true;
  if (global.NXModal.isOpen()) global.NXModal.close();
}

function q(sel){ return ROOT.querySelector(sel); }
function qa(sel){ return ROOT.querySelectorAll(sel); }

// ===================== 1) POLE `lookup` v kostre D-15 ========================

(function(){
  reset();
  const CALLS = [];
  global.NXModal.open({
    title: 'Test lookup',
    fields: [{ key: 'code', label: 'Položka', type: 'lookup', value: '', valueText: '',
               hintText: 'začni písať',
               search: function(query, done){ CALLS.push({ q: query, done: done }); } }],
    onSubmit: function(){ CALLS.push({ submitted: true }); }
  });
  const qnode = q('[data-nxm-lkq="code"]');
  ok(!!qnode, 'lookup kresli pole hladania');
  ok(!!DOC.getElementById('nxm_code'), 'a SKRYTE pole s hodnotou (to sa odosiela)');
  eq(DOC.getElementById('nxm_code').getAttribute('type'), 'hidden',
     'odosielana hodnota je skryta — pouzivatel ju needituje rucne');
  eq(q('[data-nxm-lkhint="code"]').textContent, 'začni písať',
     'staticka vysvetlivka sa vykresli');

  qnode.value = 'uholnik';
  dispatch(qnode, 'input');
  eq(CALLS.length, 1, 'pisanie spusti hladanie');
  eq(CALLS[0].q, 'uholnik', 'a posle SERVERU presne to, co je v poli');
  eq(qa('.mlkitem').length, 0, 'kym odpoved nepride, ponuka je prazdna');

  CALLS[0].done([{ value: '93240', text: '93240 · Bystrica', hint: '1,14 € / ks' },
                 { value: '93241', text: '93241 · Bystrica L', hint: '1,20 € / ks' }], 7);
  eq(qa('.mlkitem').length, 2, 'odpoved sa vykresli');
  ok(textOf(ROOT).indexOf('ďalších 5') > -1,
     'orezanie ponuky sa PRIZNA (no silent caps)');
  eq(qnode.getAttribute('aria-expanded'), 'true', 'ponuka je ohlasena citacke');

  // MUTACIA 5: starsia odpoved sa NESMIE spracovat.
  qnode.value = 'uholnik ry';
  dispatch(qnode, 'input');
  eq(CALLS.length, 2, 'dalsie pisanie spusti dalsie kolo');
  CALLS[0].done([{ value: 'STARY', text: 'stary vysledok' }], 1);
  eq(textOf(ROOT).indexOf('stary vysledok'), -1,
     'STARSIA odpoved sa zahodi — ponuku uz drzi novsie kolo');
  eq(qa('.mlkitem').length, 2, 'a stara ponuka ostava, kym nepride cerstva (ziadne blikanie)');
  CALLS[1].done([{ value: '93240', text: '93240 · Bystrica', hint: '1,14 € / ks · katalóg' }], 1);
  eq(qa('.mlkitem').length, 1, 'a cerstva sa vykresli');

  // sipky + Enter
  dispatch(qnode, 'keydown', { key: 'ArrowDown' });
  dispatch(qnode, 'keydown', { key: 'Enter' });
  eq(global.NXModal.values().code, '93240', 'Enter vyberie zvyraznenu polozku');
  eq(global.NXModal.values().code, '93240', 'a `values()` vracia LEN KOD');
  eq(Object.keys(global.NXModal.values()), ['code'],
     'ziadne dalsie pole — nazov ani cena z obrazovky sa neodosielaju');
  eq(qnode.value, '93240 · Bystrica', 'v poli ostane citatelny text vyberu');
  eq(q('[data-nxm-lkhint="code"]').textContent, '1,14 € / ks · katalóg',
     'a pod nim ZIVA cena vybranej polozky');
  eq(qa('.mlkitem').length, 0, 'vyber ponuku zatvori');
  ok(!CALLS.some(function(c){ return c.submitted; }),
     'Enter v poli hladania formular NEODOSLAL');

  // pisanie po vybere zahadzuje vyber
  qnode.value = '9324';
  dispatch(qnode, 'input');
  eq(global.NXModal.values().code, '',
     'pisanie po vybere ZAHODI kod — inak by odisiel stary kod pod novym textom');

  // Escape zatvara LEN ponuku
  CALLS[CALLS.length - 1].done([{ value: '93240', text: '93240 · Bystrica' }], 1);
  eq(qa('.mlkitem').length, 1, 'ponuka je otvorena');
  dispatch(qnode, 'keydown', { key: 'Escape' });
  ok(global.NXModal.isOpen(), 'prve Escape modal NEZATVORI');
  eq(qa('.mlkitem').length, 0, 'zatvori LEN ponuku');
  dispatch(qnode, 'keydown', { key: 'Escape' });
  ok(!global.NXModal.isOpen(), 'druhe Escape zatvori modal');
})();

// ===================== 2) POLIA MODALU + validacia ===========================

(function(){
  const add = HW.hwManualFields(OWNERS, HW.hwManualDraft(null));
  const keys = add.map(function(f){ return f.key; });
  eq(keys, ['owner', 'source', 'code', 'qty', 'note'],
     'pri KATALOGOVEJ polozke sa pyta kod (nie nazov, MJ ani cena)');
  eq(add[0].options[0], ['', 'celá skrinka'], 'default vlastnika je cela skrinka');
  eq(add[2].type, 'lookup', 'kod sa vybera naseptavacom');
  eq(add[3].value, '1', 'mnozstvo ma default 1');

  const free = HW.hwManualFields(OWNERS, Object.assign(HW.hwManualDraft(null), { source: 'free' }));
  eq(free.map(function(f){ return f.key; }), ['owner', 'source', 'name', 'unit', 'price', 'qty', 'note'],
     'pri VOLNEJ polozke sa pyta nazov, MJ a cena — a kod uz nie');
  eq(free[3].options, HW.HW_MANUAL_UNITS, 'MJ ide z jedineho slovnika jednotiek');

  const edit = HW.hwManualFields(OWNERS, HW.hwManualDraft(CAT_ITEM));
  eq(edit[0].value, 'front:F1/wing:left', 'uprava predvyplni vlastnika');
  eq(edit[2].value, '93240', 'aj kod');
  eq(edit[2].valueText, '93240 · Bystrica — rektifikačný uholník',
     'a citatelny popis vybranej polozky');
  eq(edit[3].value, '2', 'aj mnozstvo');

  // Vlastnik, ktory uz v plane NIE JE, sa PRIZNA — inak by select klamal.
  const lost = HW.hwManualOwnerOptions(OWNERS, 'front:F9/wing:left');
  eq(lost[lost.length - 1], ['front:F9/wing:left', 'front:F9/wing:left (dielec už neexistuje)'],
     'mrtvy vlastnik ostava v ponuke s dovodom');

  eq(HW.hwManualValidate({ source: 'catalog', code: '93240', qty: '2', note: '' }), [],
     'platny katalogovy vstup prejde');
  eq(HW.hwManualValidate({ source: 'catalog', code: '', qty: '2' })[0].field, 'code',
     'katalogova polozka bez kodu neprejde');
  eq(HW.hwManualValidate({ source: 'free', name: '', unit: 'ks', price: '', qty: '1' })[0].field, 'name',
     'volna polozka bez nazvu neprejde');
  eq(HW.hwManualValidate({ source: 'free', name: 'X', price: '12,50', qty: '1' }), [],
     'cena s desatinnou CIARKOU je platna (slovensky zapis)');
  eq(HW.hwManualValidate({ source: 'free', name: 'X', price: 'nezmysel', qty: '1' })[0].field, 'price',
     'nezmyselna cena neprejde');
  eq(HW.hwManualValidate({ source: 'free', name: 'X', price: '', qty: '1' }), [],
     'prazdna cena je „bez ceny", nie chyba');
  ['0', '1000', '2,5', 'x', ''].forEach(function(bad){
    eq(HW.hwManualValidate({ source: 'catalog', code: 'A', qty: bad })[0].field, 'qty',
       'mnozstvo „' + bad + '" neprejde');
  });
  eq(HW.hwManualParsePrice(''), null, 'prazdna cena = nezadana (nikdy 0)');
  eq(HW.hwManualParsePrice('0'), 0, 'nula je platna hodnota');
  eq(HW.hwManualParsePrice('-1'), false, 'zaporna cena nie je');
})();

// ===================== 3) ZAZNAM DO CONFIGU + novy zoznam ====================

(function(){
  // MUTACIA 1: pri katalogovej polozke sa smie posielat LEN kod.
  const rec = HW.hwManualRecord({ owner: 'front:F1/wing:left', source: 'catalog',
                                  code: '93240', qty: '2', note: 'pozn' }, null);
  eq(Object.keys(rec).sort(), ['code', 'id', 'note', 'owner_part_key', 'qty', 'source'],
     'katalogovy zaznam nesie LEN kod — nazov, MJ ani cenu klient neposiela');
  eq(rec.id, '', 'nova polozka ide s PRAZDNYM id — prideluje ho server');
  eq(rec.qty, 2, 'mnozstvo je cislo, nie retazec');

  const freeRec = HW.hwManualRecord({ owner: '', source: 'free', name: ' Zámok Abloy ',
                                      unit: 'ks', price: '12,50', qty: '1', note: '' }, null);
  eq(freeRec.owner_part_key, null, 'prazdny vlastnik = cela skrinka (null, nie prazdny retazec)');
  eq(freeRec.price_eur_vat, 12.5, 'cena volnej polozky ide ako CISLO');
  eq(freeRec.name, 'Zámok Abloy', 'nazov sa orezava');
  ok(!('code' in freeRec), 'volna polozka kod NEMA (nesmie sa tvarit ako katalogova)');
  const noPrice = HW.hwManualRecord({ source: 'free', name: 'X', unit: 'ks', price: '', qty: '1' }, null);
  ok(!('price_eur_vat' in noPrice), 'prazdna cena sa NEPOSIELA (server ju zmaze)');

  const list = [CAT_ITEM, FREE_ITEM];
  const added = HW.hwManualNextList(list, rec, { kind: 'add', id: '' });
  eq(added.length, 3, 'add pripoji zaznam');
  eq(added[2], rec, 'na koniec');
  const edited = HW.hwManualNextList(list, rec, { kind: 'edit', id: 'H1' });
  eq(edited.length, 2, 'edit dlzku zoznamu nemeni');
  eq(edited[0], rec, 'a nahradi PRAVE jednu polozku');
  eq(edited[1], FREE_ITEM, 'ostatne ostavaju nedotknute');
  const deleted = HW.hwManualNextList(list, null, { kind: 'delete', id: 'H2' });
  eq(deleted.length, 1, 'delete polozku vynecha');
  eq(deleted[0], CAT_ITEM, 'a zvysok necha');
  // MUTACIA 2: nenajdena polozka NESMIE skoncit tichym pripojenim.
  eq(HW.hwManualNextList(list, rec, { kind: 'edit', id: 'NIET' }), null,
     'uprava neexistujucej polozky vrati null (tichy append by spravil duplikat)');
  eq(HW.hwManualNextList(list, null, { kind: 'delete', id: 'NIET' }), null,
     'a mazanie neexistujucej tiez');
})();

// ===================== 4) CELY TOK MODALU (pridanie) =========================

(function(){
  reset({ manual: [], view: [] });
  HW.onHwManualAdd();
  ok(global.NXModal.isOpen(), 'tlacidlo otvori modal');
  const qnode = q('[data-nxm-lkq="code"]');
  qnode.value = 'uholnik';
  dispatch(qnode, 'input');
  eq(SENT.length, 1, 'hladanie islo na SERVER (panel katalog necita)');
  eq(SENT[0].cb, 'hw_manual_search', 'callbackom `hw_manual_search`');
  eq(SENT[0].data.q, 'uholnik', 's dotazom pouzivatela');
  const gen = SENT[0].data.gen;

  // Odpoved so STAROU generaciou sa zahadza (MUTACIA 5).
  HW.hwManualSearchResult({ gen: gen - 1, total: 1,
                            items: [{ code: 'STARY', name_sk: 'stary' }] });
  eq(qa('.mlkitem').length, 0, 'odpoved so starsou generaciou sa ignoruje');
  HW.hwManualSearchResult({ gen: gen, total: 1,
                            items: [{ code: '93240', name_sk: 'Bystrica — uholník',
                                      unit: 'ks', price_eur_vat: 1.14, category: 'SPOJKY' }] });
  eq(qa('.mlkitem').length, 1, 'cerstva odpoved sa vykresli');
  dispatch(qa('.mlkitem')[0], 'click');
  eq(global.NXModal.values().code, '93240', 'klik vyberie kod');

  DOC.getElementById('nxm_qty').value = '2';
  DOC.getElementById('nxm_owner').value = 'front:F1/wing:left';
  global.NXModal.submit();
  eq(SENT.length, 2, 'odoslanie islo do Ruby');
  eq(SENT[1].cb, 'apply_all', 'EXISTUJUCOU cestou `apply_all` (ziadny novy kanal)');
  eq(CANCELS, 1, 'cakajuci debounce sa ZRUSIL — rozpisany edit ide v tom istom payloade');
  const p = SENT[1].data;
  eq(p.manual_op, { kind: 'add', id: '' }, 'payload nesie operaciu pre modal');
  eq(p.cabinet_id, 'CAB-002', 'a identitu skrinky');
  eq(p.hardware_manual.length, 1, 'zoznam ma novu polozku');
  eq(p.hardware_manual[0].code, '93240', 'so spravnym kodom');
  eq(p.hardware_manual[0].id, '', 'a prazdnym id (prideli ho server)');
  ok(!('hardware_manual_view' in p) && !('hardware_manual_owners' in p),
     'zobrazovacie projekcie sa NIKDY neposielaju spat');
  ok(global.NXModal.isBusy(), 'modal je pocas zapisu ZAMKNUTY');
  ok(global.NXModal.isOpen(), 'a odoslanie ho NEZATVARA');

  // MUTACIA 3: odmietnutie modal NESMIE zatvorit.
  HW.onHwManualResult(false, 'Kovanie sa neuložilo — kód „93240“ nie je v katalógu.',
                      { kind: 'add', id: '' });
  ok(global.NXModal.isOpen(), 'odmietnutie necha modal OTVORENY');
  ok(!global.NXModal.isBusy(), 'a zamok pusti');
  eq(global.NXModal.values().code, '93240', 'hodnoty ostanu na mieste');
  ok(textOf(ROOT).indexOf('nie je v katalógu') > -1, 'dovod je v modali');

  // Po odmietnuti server pushne ULOZENY stav — neuspesna zmena sa nesmie drzat.
  global.hwManual = [];
  global.NXModal.submit();              // pouzivatel to skusi znova
  const p2 = SENT[SENT.length - 1].data;
  eq(p2.hardware_manual.length, 1,
     'opakovane odoslanie po odmietnuti prida polozku RAZ (nie dvakrat)');

  HW.onHwManualResult(true, 'Položka pridaná.', { kind: 'add', id: '' });
  ok(!global.NXModal.isOpen(), 'az potvrdenie servera modal zatvori');
  eq(STATUS[STATUS.length - 1], { msg: 'Položka pridaná.', err: false },
     'a hlaska servera ide do statusu');
})();

// ===================== 5) UPRAVA, MAZANIE, KONTEXT ===========================

(function(){
  reset({ manual: [{ id: 'H1', source: 'catalog', code: '93240', qty: 2,
                     owner_part_key: 'front:F1/wing:left', note: '' },
                   { id: 'H2', source: 'free', name: 'Zámok Abloy', unit: 'ks',
                     price_eur_vat: 12.0, qty: 1, note: '' }],
          view: [CAT_ITEM, FREE_ITEM] });
  const btn = { getAttribute: function(k){ return k === 'data-id' ? 'H1' : null; } };
  HW.onHwManualEdit(btn);
  ok(global.NXModal.isOpen(), 'ceruzka otvori modal v rezime upravy');
  eq(DOC.getElementById('nxm_qty').value, '2', 's hodnotami polozky');
  DOC.getElementById('nxm_qty').value = '5';
  global.NXModal.submit();
  const p = SENT[SENT.length - 1].data;
  eq(p.manual_op, { kind: 'edit', id: 'H1' }, 'uprava posiela operaciu edit s id');
  eq(p.hardware_manual.length, 2, 'zoznam ostava rovnako dlhy');
  eq(p.hardware_manual[0].qty, 5, 'a meni sa PRAVE upravovana polozka');
  eq(p.hardware_manual[0].id, 'H1', 'ktora si drzi svoje id');
  eq(p.hardware_manual[1].name, 'Zámok Abloy', 'druha ostava nedotknuta');
  HW.onHwManualResult(true, 'Položka upravená.', { kind: 'edit', id: 'H1' });
  ok(!global.NXModal.isOpen(), 'potvrdenie modal zatvori');

  // Prepnutie Zdroja mení sadu polí a NESMIE stratit rozpisane hodnoty.
  reset({ manual: [], view: [] });
  HW.onHwManualAdd();
  DOC.getElementById('nxm_qty').value = '4';
  DOC.getElementById('nxm_note').value = 'poznámka';
  const sel = DOC.getElementById('nxm_source');
  sel.value = 'free';
  dispatch(sel, 'change');
  ok(!!DOC.getElementById('nxm_name'), 'po prepnuti na volnu polozku sa pyta NAZOV');
  ok(!DOC.getElementById('nxm_code'), 'a kod uz nie');
  eq(DOC.getElementById('nxm_qty').value, '4', 'rozpisane mnozstvo prezilo prepnutie');
  eq(DOC.getElementById('nxm_note').value, 'poznámka', 'aj poznamka');

  // MAZANIE: bez potvrdzovacieho okna, jednym krokom Spat.
  reset({ manual: [{ id: 'H1', source: 'catalog', code: '93240', qty: 2 },
                   { id: 'H2', source: 'free', name: 'Zámok Abloy', unit: 'ks', qty: 1 }],
          view: [CAT_ITEM, FREE_ITEM] });
  HW.onHwManualDel({ getAttribute: function(){ return 'H2'; } });
  ok(!global.NXModal.isOpen(), 'mazanie ZIADNE potvrdzovacie okno neotvara');
  const d = SENT[SENT.length - 1].data;
  eq(d.manual_op, { kind: 'delete', id: 'H2' }, 'posiela operaciu delete');
  // MUTACIA 2: zoznam MUSI byt pole bez polozky, nikdy null.
  ok(Array.isArray(d.hardware_manual), 'zoznam je POLE (nikdy null — apply by ich zmazal vsetky)');
  eq(d.hardware_manual.length, 1, 'bez zmazanej polozky');
  eq(d.hardware_manual[0].id, 'H1', 'a so zvysnymi nedotknutymi');

  // Cervene pole formulara zapis ZASTAVI (modal sa nezamkne nad zapisom, ktory neodide).
  reset({ manual: [], view: [] });
  VALID = false;
  HW.onHwManualAdd();
  const codeNode = q('[data-nxm-lkq="code"]');
  codeNode.value = 'x';
  DOC.getElementById('nxm_code').value = '93240';
  global.NXModal.submit();
  eq(SENT.length, 0, 'pri cervenom poli sa NEPOSIELA nic');
  ok(!global.NXModal.isBusy(), 'a modal nezostane zamknuty');
  ok(STATUS.some(function(s){ return s.err; }), 'pouzivatel sa dozvie dovod');

  // `hwManual` = null („o polozkach neviem") zapis zastavi.
  reset({ manual: null, view: [] });
  HW.onHwManualAdd();
  DOC.getElementById('nxm_code').value = '93240';
  global.NXModal.submit();
  eq(SENT.length, 0, 'bez zoznamu sa NEPOSIELA nic (`|| []` je zakazane)');
  ok(global.NXModal.isOpen(), 'modal ostava otvoreny s dovodom');
})();

// ============ 5b) ZMENA VYBERU POD OTVORENYM MODALOM (Codex #285 P1) ========
// Modal drzi rozpisany zoznam JEDNEJ skrinky. Keby prezil zmenu vyberu,
// odoslanie by postavilo zoznam z NOVEJ skrinky a orazitkovalo ho jej
// identitou — polozka by pristala na nespravnej skrinke (a pri zhode `id` by
// PREPISALA cudzi zaznam). Zatvara sa preto pri kazdej zmene IDENTITY.

(function(){
  reset({ manual: [], view: [] });
  HW.onHwManualAdd();
  ok(global.NXModal.isOpen(), 'modal je otvoreny');
  // ECHO TEJ ISTEJ skrinky (nas vlastny apply, na ktory modal caka) ho
  // zatvorit NESMIE — inak by zmizol skor, nez pride odpoved.
  eq(HW.hwManualDropIfForeign('CAB-002', true), false,
     'echo TEJ ISTEJ skrinky modal NEZATVARA');
  ok(global.NXModal.isOpen(), 'a modal ostava otvoreny');
  ok(!!HW.hwManualState(), 'aj jeho stav');

  // INA skrinka = ina identita -> modal ide prec.
  eq(HW.hwManualDropIfForeign('CAB-009', true), true, 'INA skrinka modal ZATVORI');
  ok(!global.NXModal.isOpen(), 'okno je zavrete');
  eq(HW.hwManualState(), null, 'a stav modalu je vycisteny');
  eq(STATUS[STATUS.length - 1], { msg: HW.HW_MAN_DROP_SK, err: true },
     'pouzivatel sa dozvie, ze sa NIC neulozilo');

  // TA ISTA skrinka v INOM DOKUMENTE je tiez ina identita.
  reset({ manual: [], view: [] });
  HW.onHwManualAdd();
  eq(HW.hwManualDropIfForeign('CAB-002', false), true,
     'ta ista skrinka v INOM dokumente modal ZATVORI');
  ok(!global.NXModal.isOpen(), 'okno je zavrete aj tu');

  // Bezuce hladanie uz nema komu odpovedat.
  reset({ manual: [], view: [] });
  HW.onHwManualAdd();
  const qn = q('[data-nxm-lkq="code"]');
  qn.value = 'uholnik';
  dispatch(qn, 'input');
  const stale = SENT[SENT.length - 1].data.gen;
  HW.hwManualDropIfForeign('CAB-009', true);
  HW.onHwManualAdd();                       // novy modal nad NOVOU skrinkou
  HW.hwManualSearchResult({ gen: stale, total: 1,
                            items: [{ code: 'STARY', name_sk: 'z predchadzajucej skrinky' }] });
  eq(qa('.mlkitem').length, 0,
     'odpoved hladania z pred zatvorenia sa do noveho modalu NEDOSTANE');
  reset({ manual: [], view: [] });
})();

// Zdrojovy guard: rozhodnutie robi `hardware.js` a `bridge.js` ho vola PRED
// instalaciou noveho stavu — inak by sa stary formular mal proti comu odoslat.
(function(){
  const fs = require('node:fs');
  const src = fs.readFileSync(path.join(JS, 'bridge.js'), 'utf8');
  const load = src.slice(src.indexOf('loadSelected: function(c)'));
  const call = load.indexOf('hwManualDropIfForeign(c.cabinet_id, sameDoc)');
  ok(call > -1, 'loadSelected zatvara modal pri cudzej identite');
  ok(call < load.indexOf('hwManual = Array.isArray('),
     'a robi to PRED instalaciou noveho stavu');
  ok(src.split('hwManualDropModal(HW_MAN_DROP_SK)').length - 1 === 2,
     'odchod na dosku aj prazdny vyber modal tiez zatvaraju');
})();

// ===================== 6) RIADKY KONTEXTU KOVANIE ============================

(function(){
  eq(HW.hwManualOwnerText(CAT_ITEM), 'F1 · dvierka ľavé', 'popis vlastnika je zo SERVERA');
  eq(HW.hwManualOwnerText(FREE_ITEM), 'celá skrinka', 'bez vlastnika = cela skrinka');
  eq(HW.hwManualQtyText(CAT_ITEM), '2 ks', 'mnozstvo s MJ');
  eq(HW.hwManualQtyText({ qty: 3, unit: 'par' }), '3 pár', 'MJ ma slovensky popis');
  eq(HW.hwManualBuyText(CAT_ITEM), '93240 · 1,14 € / ks · patrí: F1 · dvierka ľavé',
     'sekundarny riadok: kod, ZIVA cena, vlastnik');
  eq(HW.hwManualBuyText(FREE_ITEM),
     'voľná položka · 12,00 € / ks · patrí: celá skrinka · pozn.: podľa priania zákazníka',
     'volna polozka sa priznava a nesie poznamku');
  eq(HW.hwManualBuyText({ source: 'catalog', code: '93240', unit: 'ks', catalog_missing: true }),
     '93240 · — / ks · patrí: celá skrinka',
     'chybajuca cena je POMLCKA, nikdy 0');

  eq(HW.hwManualChips(CAT_ITEM).map(function(c){ return c.text; }), ['ručná'],
     'zdrava polozka ma jediny chip');
  eq(HW.hwManualChips({ owner_missing: true }).map(function(c){ return c.text; }),
     ['ručná', 'bez vlastníka'], 'mrtvy vlastnik sa PRIZNA');
  eq(HW.hwManualChips({ catalog_missing: true }).map(function(c){ return c.text; }),
     ['ručná', 'chýba v katalógu'], 'aj zmiznuty kod');
  ok(HW.hwManualChips({ owner_missing: true })[1].warn === true,
     'oba stavy su jantarove (upozornenie, nie neutralny stitok)');

  const html = HW.hwManualHtml([CAT_ITEM, FREE_ITEM]);
  ok(html.indexOf('Ručne pridané') > -1, 'blok ma nadpis, ked su polozky');
  ok(html.indexOf('data-manid="H1"') > -1 && html.indexOf('data-manid="H2"') > -1,
     'a riadok pre kazdu polozku');
  ok(html.indexOf('onHwManualEdit(this)') > -1 && html.indexOf('onHwManualDel(this)') > -1,
     'kazdy riadok ma upravu aj zmazanie');
  ok(html.indexOf('Pridať konkrétnu položku (mimo setov)') > -1,
     'a na konci je tlacidlo');
  ok(html.indexOf('#i-pencil') > -1 && html.indexOf('#i-trash') > -1 &&
     html.indexOf('#i-plus') > -1, 'ikony su zo spritu (ziadne emoji)');
  ok(html.indexOf('data-owner=') === -1 && html.indexOf('data-rule=') === -1,
     'riadok NEMA identitu pravidla — `refreshHardwarePurchase` ho hladat nesmie');
  const empty = HW.hwManualHtml([]);
  eq(empty.indexOf('Ručne pridané'), -1,
     'bez poloziek sa nadpis nekresli (vertikalny priestor)');
  ok(empty.indexOf('Pridať konkrétnu položku') > -1, 'ale tlacidlo ostava');
})();

// ===================== 7) NAKUP STUDIA: chip + rozklik povodu ================

(function(){
  const ST = require(path.join(JS, 'studio.js'));
  eq(ST.hwRowManual({ adhoc_quantity: 2 }), true, 'riadok s ad-hoc kusmi je rucny');
  eq(ST.hwRowManual({ free: true }), true, 'volna polozka tiez');
  eq(ST.hwRowManual({ adhoc_quantity: 0, free: false }), false, 'cisto setovy riadok nie');
  eq(ST.hwRowManual({}), false, 'stary payload bez priznakov tiez nie');

  eq(ST.hwSourceText({ cabinet_id: 'CAB-2', owner_part_key: 'front:F1/wing:left',
                       owner_label: 'F1 · dvierka ľavé', origin: 'adhoc', quantity: 2 }),
     'CAB-2 · F1 · dvierka ľavé · ručná ×2',
     'ad-hoc zdroj sa cita ako veta a popis vlastnika je zo servera');
  eq(ST.hwSourceText({ cabinet_id: 'CAB-2', set_id: 'zaves-klasik', quantity: 4 }),
     'CAB-2 · set zaves-klasik ×4', 'setovy zdroj menuje set');
  eq(ST.hwSourceText({ cabinet_id: 'CAB-2', origin: 'adhoc', quantity: 1 }),
     'CAB-2 · ručná ×1', 'polozka celej skrinky vlastnika nemenuje');

  const rows = [{ code: '93240', name_sk: 'Bystrica', quantity: 6, unit: 'ks',
                  price_eur_vat: 1.14, subtotal_eur_vat: 6.84, adhoc_quantity: 2,
                  sources: [{ cabinet_id: 'CAB-2', owner_label: 'F1 · dvierka ľavé',
                              origin: 'adhoc', quantity: 2 },
                            { cabinet_id: 'CAB-1', set_id: 'uholniky', quantity: 4 }] },
                { code: '', free: true, name_sk: 'Zámok Abloy', quantity: 1, unit: 'ks',
                  price_eur_vat: 12.0, subtotal_eur_vat: 12.0, adhoc_quantity: 1,
                  sources: [{ cabinet_id: 'CAB-2', origin: 'adhoc', quantity: 1 }] }];
  ST.setBuyOpen({});
  const closed = ST.buySection({ rows: rows, summary: {} }, []);
  ok(closed.indexOf('<span class="hwchip">ručná</span>') > -1,
     'rucny riadok nesie chip „ručná"');
  ok(closed.indexOf('<td>—</td>') > -1, 'volna polozka ma v stlpci Kod pomlcku');
  eq(closed.indexOf('Pôvod:'), -1, 'zbaleny riadok povod nekresli');
  ok(closed.indexOf('data-buy="0"') > -1, 'riadok je rozklikatelny');

  ST.setBuyOpen({ 0: true });
  const open = ST.buySection({ rows: rows, summary: {} }, []);
  ok(open.indexOf('Pôvod:') > -1, 'rozkliknuty riadok ukaze povod');
  ok(open.indexOf('CAB-2 · F1 · dvierka ľavé · ručná ×2') > -1, 'a v nom rucny zdroj');
  ok(open.indexOf('CAB-1 · set uholniky ×4') > -1, 'aj setovy zdroj toho isteho kodu');
  ST.setBuyOpen({});
})();

// ===================== 8) zdrojove guardy ===================================

(function(){
  const fs = require('node:fs');
  const hwSrc = fs.readFileSync(path.join(JS, 'hardware.js'), 'utf8');
  const formSrc = fs.readFileSync(path.join(JS, 'form.js'), 'utf8');
  ok(formSrc.indexOf('hardware_manual_view') === -1 &&
     formSrc.indexOf('hardware_manual_owners') === -1,
     '`collectAll` o zobrazovacich projekciach NEVIE (nemoze ich poslat spat)');
  ok(hwSrc.indexOf('hwManual || []') === -1,
     '`|| []` nad pass-through zoznamom je zakazane');
  // MUTACIA 6: blok nesmie vzniknut bez oznacenej skrinky — kresli sa az za
  // vetvou `items === null`, ktora sa vracia skor — a POD boxmi vlastnikov,
  // nie nad nimi (tlacidlo je posledne v sekcii).
  const render = hwSrc.slice(hwSrc.indexOf('function renderHardware'));
  ok(render.indexOf('if (items === null)') < render.indexOf('hwManualHtml()'),
     'blok rucnych poloziek sa kresli AZ po vetve „nic nie je oznacene"');
  ok(render.indexOf('box.innerHTML = html + hwManualHtml();') > -1,
     'a pripaja sa ZA boxy vlastnikov (poradie je sucast navrhu, nie nahoda)');
})();

console.log('OK test_kovh2_adhoc_ui.js — ' + n + ' kontrol');
