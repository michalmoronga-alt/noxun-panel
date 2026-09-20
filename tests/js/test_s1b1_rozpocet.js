// S1-B1 — SPOTREBIC V ROZPOCTE: katalog, vlastnik, „dodáva zákazník".
//
// Preco su to testy a nie klikanie:
//   1. KATEGORIE CHODIA ZO SERVERA. Keby si ich okno drzalo natvrdo, casom by
//      ponukalo typ, ktory server nepozna — a polozka by sa nedala ulozit.
//   2. PONUKA VLASTNIKOV je matica × zoznam kusov TEJTO zakazky. Klient ju LEN
//      sklada; keby si maticu vymyslel, ponukol by umyvacku do beznej skrinky
//      a server by zapis odmietol az po kliku.
//   3. VYBER MODELU predvyplna polia zo STRUKTUROVANYCH dat (`data`), nikdy
//      parsovanim zobrazeneho textu — text je len to, co pouzivatel cita.
//   4. MODAL PATRI DOKUMENTU. Po prepnuti zakazky sa musi zavriet a jeho
//      fronta aj rozpracovany dotaz zahodit, inak by polozka sadla do CUDZEJ
//      zakazky.
//   5. ZMENA VLASTNIKA je INA domenova akcia nez uprava poli — ide vlastnym
//      op-om (`appliance_owner`), lebo na serveri je to jedna operacia vazby.
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
global.NXModal = NXModal;

const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);
const STATUS = mkEl('div');
STATUS.attrs.id = 'status';
DOC.body.appendChild(STATUS);

const SENT = [];
const LOOKUPS = [];
global.sketchup = {
  budget_mutate: function(json){ SENT.push(JSON.parse(json)); },
  appl_lookup: function(json){ LOOKUPS.push(JSON.parse(json)); }
};
global.window.sketchup = global.sketchup;

require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const B = require(path.join(JS, 'budget.js'));

// --- payload rozpoctu (presne to, co posiela server) -------------------------
const TYPES = [
  { code: 'fridge', label: 'Chladnička' }, { code: 'oven', label: 'Rúra' },
  { code: 'microwave', label: 'Mikrovlnka' }, { code: 'dishwasher', label: 'Umývačka' },
  { code: 'hob', label: 'Varná doska' }, { code: 'sink', label: 'Drez' },
  { code: 'hood', label: 'Digestor' }, { code: 'other', label: 'Iné' }
];

const OWNERS = {
  matrix: { fridge: ['cabinet'], oven: ['cabinet'], microwave: ['cabinet'],
            dishwasher: ['slot'], hob: ['board'], sink: ['board'], hood: [], other: [] },
  options: {
    cabinet: [{ kind: 'cabinet', id: 'CAB-1', pid: 101, label: 'CAB-1 · Chladničková' },
              { kind: 'cabinet', id: 'CAB-2', pid: 102, label: 'CAB-2' }],
    slot: [{ kind: 'slot', id: 'CAB-3', pid: 103, label: 'CAB-3 · Umývačka 60' }],
    board: [{ kind: 'board', id: 'BRD-1', pid: 201, label: 'BRD-1 · Pracovná doska' }]
  },
  job_label: 'len zákazka (bez väzby)'
};

function budget(rows){
  return {
    mode: 'standard', mode_label: 'Štandard', currency: 'EUR', vat_divisor: 1.23,
    appliance_types: TYPES, appliance_owners: OWNERS,
    budget_std: { state: 'current', blocked: false, reason: '' },
    totals: { total: 0, total_novat: 0, raw_total: 0, rounding: 0, subtotals: {} },
    budget_check: [],
    sections: [{ key: 'appliances', name: 'Spotrebiče a vybavenie', rows: rows || [],
                 subtotal: 0, unknown_count: 0, complete: true,
                 counts_in_total: true, included: true }]
  };
}

const ROW_BOUND = {
  key: 'appliance:A1', id: 'A1', nazov: 'Beko BCNA306E5ZSN', typ: 'fridge',
  typ_label: 'Chladnička', dodavatel: 'Beko', cena_mj: 899, spolu: 899,
  catalog_id: 'CAT-1', owner: { kind: 'cabinet', id: 'CAB-1' }, customer_supplied: false
};
const ROW_FREE = {
  key: 'appliance:A2', id: 'A2', nazov: 'Drez', typ: 'sink', typ_label: 'Drez',
  cena_mj: null, spolu: null, price_missing: true,
  owner: { kind: 'job' }, customer_supplied: true
};

// V CEF je `ST` JEDEN globalny payload, ktory cita aj `studio.js`, aj
// `budget.js`; v Node ho `require` izoluje do modulu, takze sa musi nasadit
// aj globalne (vzor `tests/js/test_st2d_kde.js`).
function push(guid, rows){
  const data = { gen: 7, model_guid: guid || 'DOC-A', rows: [], sheets: [], edging: [],
                 control: [], counts: { red: 0, orange: 0, total: 0 },
                 budget: budget(rows), version: 'test' };
  global.ST = data;
  NX.setStudio(data);
}
push('DOC-A', [ROW_BOUND, ROW_FREE]);

// ===================== 1) kategorie su ZO SERVERA ===========================

(function(){
  const b = budget([]);
  eq(B.budApplTypes(b).length, 8, 'osem kanonickych kategorii');
  eq(B.budApplTypes(b)[0], ['fridge', 'Chladnička'], 'kod + SK popisok z payloadu');
  eq(B.budApplTypeLabel(b, 'dishwasher'), 'Umývačka');
  eq(B.budApplTypes({}), [], 'bez payloadu ziadne kategorie — NIC sa nevymysla');
  eq(B.budApplTypeLabel({}, 'fridge'), 'fridge', 'neznamy kod sa ukaze ako kod');
})();

// ===================== 2) ponuka vlastnikov (matica) ========================

(function(){
  const b = budget([]);
  eq(B.budOwnerOptions(b, 'fridge').map(function(o){ return o[0]; }),
     ['cabinet:CAB-1', 'cabinet:CAB-2', 'job'],
     'chladnicka: skrinky + „len zakazka" na konci');
  eq(B.budOwnerOptions(b, 'dishwasher').map(function(o){ return o[0]; }),
     ['slot:CAB-3', 'job'], 'umyvacka: LEN sloty');
  eq(B.budOwnerOptions(b, 'hob').map(function(o){ return o[0]; }),
     ['board:BRD-1', 'job'], 'varna doska: LEN dosky');
  eq(B.budOwnerOptions(b, 'hood').map(function(o){ return o[0]; }),
     ['job'], 'digestor fyzickeho vlastnika NEMA');
  eq(B.budOwnerOptions({}, 'fridge').map(function(o){ return o[0]; }),
     ['job'], 'bez payloadu ostava len „len zakazka"');
  eq(B.budOwnerOptions(b, 'fridge')[0][1], 'CAB-1 · Chladničková', 'popisok je zo servera');

  // Hodnota selectu <-> payload vlastnika (s PID z ponuky — identita ciela).
  eq(B.budOwnerPayload(b, 'cabinet:CAB-2'), { kind: 'cabinet', id: 'CAB-2', pid: 102 });
  eq(B.budOwnerPayload(b, 'slot:CAB-3'), { kind: 'slot', id: 'CAB-3', pid: 103 });
  eq(B.budOwnerPayload(b, 'job'), { kind: 'job', id: '', pid: null });
  eq(B.budOwnerPayload(b, ''), { kind: 'job', id: '', pid: null });
  eq(B.budOwnerPayload(b, 'cabinet:NEEXISTUJE').pid, null,
     'ciel mimo ponuky PID nema — server ho odmietne');
  eq(B.budOwnerValue(ROW_BOUND), 'cabinet:CAB-1');
  eq(B.budOwnerValue(ROW_FREE), 'job');
})();

// ===================== 3) polia modalu ======================================

(function(){
  const b = budget([]);
  const f = B.budDraftFields('appliance', null, b);
  eq(f.map(function(x){ return x.key; }),
     ['catalog_id', 'typ', 'nazov', 'dodavatel', 'cena', 'owner', 'customer_supplied']);
  eq(f[0].type, 'lookup', 'prve pole je vyber modelu z katalogu');
  ok(typeof f[0].search === 'function', 'a ma serverove hladanie');
  ok(typeof f[0].onPick === 'function', 'vyber je ZACIATOK dalsieho kroku (predvyplnenie)');
  eq(f[1].options, B.budApplTypes(b), 'typ ponuka kategorie zo servera');
  eq(f[5].options.map(function(o){ return o[0]; }), ['cabinet:CAB-1', 'cabinet:CAB-2', 'job'],
     'vlastnik je podla PRVEJ kategorie (fridge)');
  eq(f[6].type, 'checkbox', '„dodáva zákazník" je prepinac');

  // Ina kategoria = INA ponuka vlastnikov.
  const dw = B.budDraftFields('appliance', { typ: 'dishwasher' }, b);
  eq(dw[5].options.map(function(o){ return o[0]; }), ['slot:CAB-3', 'job']);
})();

// ===================== 4) riadok tabulky ====================================

(function(){
  const b = budget([]);
  ok(B.budApplTypeLocked(ROW_BOUND), 'model z katalogu typ ZAMYKA');
  ok(B.budApplTypeLocked({ owner: { kind: 'cabinet', id: 'CAB-1' } }),
     'fyzicky vlastnik ho zamyka tiez (matica by sa inak rozbila)');
  ok(!B.budApplTypeLocked({ owner: { kind: 'job' } }), 'polozka „len zakazka" ho menit SMIE');

  eq(B.budApplOwnerText(ROW_BOUND), 'CAB-1');
  eq(B.budApplOwnerText(ROW_FREE), 'len zákazka');

  const bound = B.budApplianceRow(ROW_BOUND, { vat: true }, b);
  ok(bound.indexOf('<select') < 0, 'zamknuty typ sa kresli ako TEXT, nie ponuka');
  ok(bound.indexOf('Chladnička') > -1, 'a ukaze SK popisok');
  ok(bound.indexOf('CAB-1') > -1, 'riadok priznava vlastnika');
  ok(bound.indexOf('dodáva zákazník') < 0, 'ocenena polozka stitok nema');

  const free = B.budApplianceRow(ROW_FREE, { vat: true }, b);
  ok(free.indexOf('<select') > -1, 'volna polozka typ menit moze');
  ok(free.indexOf('dodáva zákazník') > -1, 'a stitok je vidno');
  ok(free.indexOf('len zákazka') > -1);
})();

// ===================== 5) naseptavac katalogu ===============================

(function(){
  SENT.length = 0;
  LOOKUPS.length = 0;
  B.budOpenDraft('appliance');
  ok(NXModal.isOpen(), 'modal je otvoreny');

  const q = DOC.getElementById('nxm_catalog_id_q');
  ok(q, 'pole hladania existuje');
  q.value = 'beko';
  dispatch(q, 'input');
  eq(LOOKUPS.length, 1, 'hladanie ide na SERVER');
  eq(LOOKUPS[0].q, 'beko');

  // Odpoved: polozka nesie STRUKTUROVANE data (B14).
  const gen = LOOKUPS[0].gen;
  NX.applLookupResult({ gen: gen, total: 1, items: [
    { value: 'CAT-1', text: 'Beko BCNA306E5ZSN', hint: 'Chladnička',
      data: { manufacturer: 'Beko', name: 'BCNA306E5ZSN', category: 'fridge',
              category_label: 'Chladnička' } }
  ] });
  const hits = ROOT.querySelectorAll('.mlkitem');
  eq(hits.length, 1, 'ponuka sa vykreslila');
  dispatch(hits[0], 'click');
  eq(DOC.getElementById('nxm_catalog_id').value, 'CAT-1', 'odosiela sa ID, nie text');
  eq(DOC.getElementById('nxm_nazov').value, 'Beko BCNA306E5ZSN',
     'nazov sa predvyplnil zo strukturovanych dat');
  eq(DOC.getElementById('nxm_dodavatel').value, 'Beko');
  eq(DOC.getElementById('nxm_typ').value, 'fridge', 'aj kategoria — z `data`, nie z textu');

  // STARSIA odpoved sa zahadzuje.
  const before = DOC.getElementById('nxm_catalog_id').value;
  NX.applLookupResult({ gen: gen - 5, total: 9, items: [] });
  eq(DOC.getElementById('nxm_catalog_id').value, before, 'pomalsie kolo cerstvy vyber neprepise');
  NXModal.close();
})();

// ===================== 6) zapis z modalu ====================================

(function(){
  SENT.length = 0;
  B.budOpenDraft('appliance');
  DOC.getElementById('nxm_nazov').value = 'Beko BCNA306E5ZSN';
  DOC.getElementById('nxm_catalog_id').value = 'CAT-1';
  DOC.getElementById('nxm_owner').value = 'cabinet:CAB-1';
  DOC.getElementById('nxm_customer_supplied').checked = true;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');

  eq(SENT.length, 1, 'jeden zapis');
  eq(SENT[0].op, 'appliance_add');
  eq(SENT[0].catalog_id, 'CAT-1', 'identita modelu ide ako ODKAZ');
  eq(SENT[0].owner, { kind: 'cabinet', id: 'CAB-1', pid: 101 },
     'vlastnik ide s PID — server overi vsetky tri udaje');
  eq(SENT[0].attrs.customer_supplied, true);
  ok(SENT[0].attrs.snapshot === undefined, 'klient NIKDY neposiela snapshot');
  eq(SENT[0].model_guid, 'DOC-A', 'zapis nesie identitu dokumentu modalu');

  // Odmietnutie NEZATVARA modal (kontrakt D-15).
  NX.budgetResult('appliance_add', false);
  ok(NXModal.isOpen(), 'odmietnuty zapis necha hodnoty na mieste');
  NX.budgetResult('appliance_add', true);
  ok(!NXModal.isOpen(), 'potvrdenie modal zavrie');
})();

// ===================== 7) ⋯ editor: vlastnik je VLASTNA akcia ===============

(function(){
  push('DOC-A', [ROW_BOUND, ROW_FREE]);
  SENT.length = 0;
  B.budOpenMore('appliance', 'A1');
  ok(NXModal.isOpen(), 'editor sa otvoril');
  eq(DOC.getElementById('nxm_owner').value, 'cabinet:CAB-1', 'vlastnik je predvyplneny');
  ok(DOC.getElementById('nxm_kod') === null, 'spotrebic kod nema');

  // Zmena LEN priznaku = obycajna uprava.
  DOC.getElementById('nxm_customer_supplied').checked = true;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT[0].op, 'appliance_update');
  eq(SENT[0].attrs.customer_supplied, true);
  ok(SENT[0].owner === undefined, 'vlastnik sa neposiela — nezmenil sa');
  NX.budgetResult('appliance_update', true);

  // Zmena VLASTNIKA = vlastna akcia (na serveri jedna operacia vazby).
  push('DOC-A', [ROW_BOUND, ROW_FREE]);
  SENT.length = 0;
  B.budOpenMore('appliance', 'A1');
  DOC.getElementById('nxm_owner').value = 'cabinet:CAB-2';
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT[0].op, 'appliance_owner');
  eq(SENT[0].owner, { kind: 'cabinet', id: 'CAB-2', pid: 102 });
  eq(SENT[0].id, 'A1');
  NX.budgetResult('appliance_owner', true);
  ok(!NXModal.isOpen(), 'potvrdenie zavrie aj editor vlastnika');

  // Odpojenie: vlastnik -> „len zakazka".
  push('DOC-A', [ROW_BOUND, ROW_FREE]);
  SENT.length = 0;
  B.budOpenMore('appliance', 'A1');
  DOC.getElementById('nxm_owner').value = 'job';
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT[0].op, 'appliance_owner');
  eq(SENT[0].owner, { kind: 'job', id: '', pid: null });
  NX.budgetResult('appliance_owner', true);
})();

// ===================== 8) modal patri DOKUMENTU (B4) ========================

(function(){
  push('DOC-A', [ROW_BOUND]);
  SENT.length = 0;
  LOOKUPS.length = 0;
  B.budOpenDraft('appliance');
  ok(NXModal.isOpen());
  ok(B.budModalOp('appliance_add'), 'zapis z modalu identitu dokumentu nesie');
  ok(!B.budModalOp('mode'), 'prepnutie rezimu nie je z modalu');

  // Dokument sa vymenil.
  push('DOC-B', []);
  ok(!NXModal.isOpen(), 'modal z inej zakazky sa ZAVREL');

  // Rozpracovana odpoved naseptavaca z PREDCHADZAJUCEHO dokumentu sa ignoruje.
  const before = SENT.length;
  NX.applLookupResult({ gen: 1, total: 1, items: [{ value: 'X', text: 'X' }] });
  eq(SENT.length, before, 'a nic sa neodoslalo');
})();

// ===================== 9) fronta zapisov po prepnuti dokumentu ==============

(function(){
  push('DOC-A', [ROW_BOUND]);
  SENT.length = 0;
  // Prvy zapis obsadi kanal, druhy caka vo fronte.
  B.budOpenMore('appliance', 'A1');
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1, 'prvy zapis odisiel');
  B.budOpenMore('appliance', 'A1');
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1, 'druhy caka vo fronte (kanal je obsadeny)');

  // Prepnutie dokumentu frontu ZAHODI — cakajuci zapis nesmie sadnut inam.
  push('DOC-B', []);
  eq(SENT.length, 1, 'cakajuci zapis sa NEODOSLAL do inej zakazky');
})();

console.log('OK test_s1b1_rozpocet.js — ' + n + ' kontrol');
