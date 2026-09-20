// S1-B2 — pohľad „V zákazke" (sekcia Spotrebiče) + riadok „Spotrebič" (Inspector).
//
// Prečo sú to testy a nie klikanie:
//   1. TABUĽKU skladá server. Keby si ju klient preskladal (napr. abecedne),
//      prestalo by platiť „skrinky, dosky, sloty, len zákazka" a používateľ by
//      hľadal spotrebič inde, než kde ho server umiestnil.
//   2. AKCIE riadku rozhoduje server. Klikaním sa nedá overiť, že „oko" pri
//      sirote naozaj NIE JE (vlastník neexistuje, nie je čo označiť).
//   3. PRVÁ VOĽBA ponuky je neutrálna. `<select>` bez vyslovenej hodnoty
//      vyberie prvú možnosť — keby ňou bol model, jediné kliknutie do riadku
//      by spotrebič naviazalo AJ S PRESTAVBOU skrinky.
//   4. KONTEXT vlastníka (skrinka vs doska) žije v DOM. Panel vie mať obe karty
//      vykreslené naraz, takže globál by sa dal prepísať pod rukami a zápis by
//      odišiel na cudzieho vlastníka.
//   5. Mená modelov píše používateľ — neescapovaný `<` rozbije celú sekciu.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_s1a2_sekcia.js) ---------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '', _attrs: {}, value: '',
              hidden: false };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){ n._text = v; }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.removeAttribute = function(k){ delete n._attrs[k]; };
  n.closest = function(sel){
    if (sel === '[data-apr-kind]' && n._attrs['data-apr-kind'] !== undefined) return n;
    return n._closest && n._closest[sel] ? n._closest[sel] : null;
  };
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio', 'applRows', 'boardApplRows']
  .forEach(function(id){ ELS[id] = stubEl(id); });

const SENT = [];
global.window = {
  sketchup: new Proxy({}, {
    get(_t, name){
      if (typeof name !== 'string') return undefined;
      return function(payload){ SENT.push([name, payload]); };
    },
    has(){ return true; }
  })
};
global.sketchup = global.window.sketchup;
const LISTEN = {};
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  querySelectorAll: function(){ return []; }
};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;           // poradie <script> v studio.html
const A = require(path.join(JS, 'appliances.js'));
const R = require(path.join(JS, 'appliance_row.js'));

// `budget.js` beží v CEF v tom istom scope — tu ho zastupujú globály, aby sa
// dalo overiť, že sekcia volá SPOLOČNÝ modal a SPOLOČNÝ kanál zápisu.
const BUD = { draft: [], more: [], send: [], goto: [] };
global.budOpenDraft = function(kind, values){ BUD.draft.push([kind, values]); };
global.budOpenApplEdit = function(id){ BUD.more.push(id); };
global.budSend = function(op, extra){ BUD.send.push([op, extra]); };
global.budGoto = function(sec){ BUD.goto.push(sec); };
global.studioGoSection = function(sec){ BUD.goto.push('section:' + sec); };
global.nxDocPayload = function(obj){ return JSON.stringify(Object.assign({ model_guid: 'G' }, obj)); };
global.openStudio = function(section, anchor){ BUD.goto.push('studio:' + section + ':' + (anchor || '')); };

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

function reset(){
  SENT.length = 0;
  BUD.draft.length = 0; BUD.more.length = 0; BUD.send.length = 0; BUD.goto.length = 0;
  A.apReset();
  ELS.secbody._html = '';
  ELS.sectools._html = '';
  S.setStudioSection('appl');
}

function click(node){
  (LISTEN.click || []).forEach(function(fn){ fn({ target: node }); });
}
function change(node){
  (LISTEN.change || []).forEach(function(fn){ fn({ target: node }); });
}
function btn(attrs){
  const node = stubEl('btn');
  Object.keys(attrs).forEach(function(k){ node.setAttribute(k, attrs[k]); });
  node.closest = function(sel){
    if (sel === '[data-ap]' && attrs['data-ap'] !== undefined) return node;
    if (sel === '[data-apr]' && attrs['data-apr'] !== undefined) return node;
    if (sel === '[data-apr-kind]') return node._owner || null;
    return null;
  };
  return node;
}

// --- vzorové payloady (presne v tvare, aký skladá appliance_dialog.rb) -------

function jobRow(extra){
  return Object.assign({
    state: 'bound', item_id: 'I-FRIDGE', category: 'fridge', category_label: 'Chladnička',
    model: 'Beko BCNA306E5ZSN', model_sub: 'Beko · z katalógu',
    owner: { kind: 'cabinet', id: 'CAB-3', pid: 11 },
    owner_label: 'CAB-3', owner_desc: 'Chladničková skriňa',
    tone: 'ok', status_text: 'v poriadku', price_text: '639,00 €', customer_supplied: false,
    shop_url: 'https://nay.sk/beko', sheet_url: '',
    actions: { select: true, edit: true, remove: true, unbind: true, assign: false,
               shop: true, sheet: false }
  }, extra || {});
}

function job(extra){
  return Object.assign({
    rows: [
      jobRow(),
      jobRow({ state: 'owner_missing', item_id: 'I-OVEN', category: 'oven',
               category_label: 'Rúra', model: 'Bosch HBF153EB0',
               model_sub: 'ručný záznam (bez katalógu)', owner_label: 'CAB-11',
               owner: { kind: 'cabinet', id: 'CAB-11', pid: null },
               tone: 'warn', status_text: 'vlastník zmizol', price_text: '—',
               shop_url: '', actions: { select: false, edit: true, remove: true, unbind: true,
                                        assign: false, shop: false, sheet: false } }),
      jobRow({ state: 'expected_missing', item_id: null, category: 'dishwasher',
               category_label: 'Umývačka', model: '— nevybraný',
               model_sub: 'vlastník očakáva umývačka',
               owner: { kind: 'slot', id: 'CAB-7', pid: 13 }, owner_label: 'CAB-7',
               owner_desc: 'Umývačka 60', tone: 'warn', status_text: 'nevybraný',
               price_text: '—', shop_url: '',
               actions: { select: true, edit: false, remove: false, unbind: false, assign: true,
                          shop: false, sheet: false } })
    ],
    total: 2, warn: 2, counts: { red: 0, orange: 2, total: 2 },
    summary: '2 spotrebiče · 1 nevybraný · 1 bez vlastníka',
    subtotal_text: '639,00 €', subtotal_included: false,
    categories: [['fridge', 'Chladnička'], ['oven', 'Rúra'], ['dishwasher', 'Umývačka']]
  }, extra || {});
}

function tree(extra){
  return Object.assign({
    gen: 1, query: '', include_deleted: false, total: 1, deleted_total: 0, seed_total: 1,
    state: 'ok', state_reason: '', writable: true,
    categories: [['fridge', 'Chladnička']],
    groups: [{ code: 'fridge', label: 'Chladnička', total: 1,
               items: [{ id: 'f1', name: 'BCNA306E5ZSN', manufacturer: 'Beko',
                         title: 'Beko BCNA306E5ZSN', category: 'fridge', sub: 'seed',
                         seed: true, deleted: false }] }]
  }, extra || {});
}

// ---------------------------------------------------------------------------
// 1) SEGMENT POHĽADOV — obe polovice sú živé
// ---------------------------------------------------------------------------
reset();
A.apSetTree(tree({ job: job() }));
{
  const html = A.apToolsHtml(A.apToolsState());
  ok(html.indexOf('data-v="job"') > 0, 'segment má obe polovice');
  ok(html.indexOf('aria-disabled') < 0, 'a ani jedna už nie je placeholder z A2');
  ok(/data-v="cat"[^>]*class|class="bomvw on"[^>]*data-v="cat"/.test(html) ||
     html.indexOf('bomvw on" data-ap="view" data-v="cat"') > 0,
     'predvolený pohľad je Katalóg');
}

SENT.length = 0;                      // katalóg si pri vykreslení pýta formulár
A.apSetView('job');
eq(A.apState().view, 'job', 'prepnutie pohľadu je ČISTO klientske');
eq(SENT.length, 0, 'a nejde naň žiadny dotaz na server');

// ---------------------------------------------------------------------------
// 2) TABUĽKA — riadky, poradie, escapovanie, prázdne stavy
// ---------------------------------------------------------------------------
{
  const html = A.apJobHtml(job());
  ok(html.indexOf('Beko BCNA306E5ZSN') > 0, 'model je v tabuľke');
  ok(html.indexOf('CAB-3') > 0 && html.indexOf('Chladničková skriňa') > 0,
     'vlastník aj jeho popis');
  ok(html.indexOf('— nevybraný') > 0, 'riadok „nevybraný" (mockup CAB-9)');
  ok(html.indexOf('vlastník zmizol') > 0, 'aj riadok siroty');
  ok(html.indexOf('639,00 €') > 0, 'cena je HOTOVÝ text zo servera');
  ok(html.indexOf('2 spotrebiče') > 0, 'súhrn pod tabuľkou tiež');
}

{
  // PORADIE: klient kreslí presne to, čo dostal (server ho už zoradil).
  const j = job();
  const order = j.rows.map(function(r){ return r.item_id || 'X'; });
  const html = A.apJobHtml(j);
  let last = -1;
  order.forEach(function(id){
    const i = html.indexOf(id === 'X' ? '— nevybraný' : id);
    ok(i > last, 'riadok ' + id + ' je v poradí zo servera');
    last = i;
  });
}

{
  const html = A.apJobHtml(job({ rows: [], total: 0, summary: '0 spotrebičov' }));
  ok(html.indexOf('Zákazka zatiaľ žiadny spotrebič nemá') > 0,
     'prázdna zákazka hovorí, čo s tým');
  ok(A.apJobHtml(null).indexOf('nenačítala') > 0, 'a bez payloadu tiež (nikdy mlčanie)');
}

{
  const evil = job({ rows: [jobRow({ model: '<img src=x onerror=alert(1)>' })] });
  const html = A.apJobHtml(evil);
  ok(html.indexOf('<img src=x') < 0, 'meno modelu je ESCAPOVANÉ');
  ok(html.indexOf('&lt;img') > 0, 'a vidno ho ako text');
}

// ---------------------------------------------------------------------------
// 3) AKCIE RIADKU podľa `actions` zo servera
// ---------------------------------------------------------------------------
{
  const html = A.apJobActsHtml(jobRow());
  ok(html.indexOf('data-ap="jsel"') > 0, 'oko pri živom vlastníkovi');
  ok(html.indexOf('data-ap="jedit"') > 0 && html.indexOf('data-ap="jdel"') > 0);
  ok(html.indexOf('data-ap="junbind"') > 0, 'odpojiť');
  ok(html.indexOf('data-ap="url"') > 0, 'odkaz na obchod');
}
{
  const orphan = A.apJobActsHtml(job().rows[1]);
  ok(orphan.indexOf('data-ap="jsel"') < 0, 'sirota nemá čo označiť');
  ok(orphan.indexOf('data-ap="junbind"') > 0, 'ale dá sa odpojiť');
  const exp = A.apJobActsHtml(job().rows[2]);
  ok(exp.indexOf('data-ap="jassign"') > 0, 'riadok „nevybraný" ponúka výber');
  ok(exp.indexOf('data-ap="jdel"') < 0, 'a nedá sa zmazať — nie je čo');
}
{
  // Codex #383 kolo 1 (P2): vlastník mimo ponuky — akcia NIE JE a riadok
  // povie dôvod (server ju v `actions.assign` vypne).
  const locked = job().rows[2];
  locked.actions.assign = false;
  locked.model_sub = 'vlastník očakáva umývačka — teraz sa k nemu priradiť nedá';
  const html = A.apJobActsHtml(locked);
  ok(html.indexOf('data-ap="jassign"') < 0, 'bez ponuky žiadne „vybrať…"');
  ok(A.apJobRowHtml(locked).indexOf('priradiť nedá') > 0, 'dôvod je v riadku vidieť');
}

// ---------------------------------------------------------------------------
// 4) FILTER tabuľky je klientsky (zužuje, čo už v okne je)
// ---------------------------------------------------------------------------
eq(A.apJobRows(job(), 'beko', '').length, 1, 'hľadanie podľa modelu');
eq(A.apJobRows(job(), 'CAB-7', '').length, 1, 'aj podľa vlastníka');
eq(A.apJobRows(job(), '', 'oven').length, 1, 'filter kategórie');
eq(A.apJobRows(job(), '', '').length, 3, 'bez filtra sú všetky riadky');
A.apJobSearch('beko');
eq(A.apState().jobQuery, 'beko', 'text hľadania je stav klienta');
eq(SENT.length, 0, 'a nejde naň dotaz na server');
A.apJobSearch('');

// ---------------------------------------------------------------------------
// 5) SPOLOČNÝ MODAL — dve vstupné miesta, jedna implementácia
// ---------------------------------------------------------------------------
reset();
A.apSetTree(tree({ job: job() }));
A.apSetView('job');
click(btn({ 'data-ap': 'jadd' }));
eq(BUD.draft.length, 1, '„Pridať do zákazky" otvára modal ROZPOČTU');
eq(BUD.draft[0][0], 'appliance', 'a je to spotrebičová pridávačka');
eq(BUD.draft[0][1], null, 'bez predvyplnenia — používateľ si model vyberie');

click(btn({ 'data-ap': 'jassign', 'data-c': 'dishwasher', 'data-ok': 'slot', 'data-oid': 'CAB-7' }));
eq(BUD.draft.length, 2, 'riadok „nevybraný" otvára TEN ISTÝ modal');
eq(BUD.draft[1][1], { typ: 'dishwasher', owner: 'slot:CAB-7' },
   'predvyplnený je vlastník aj kategória — hodnota selectu je `<druh>:<id>`');

reset();
A.apSetCard({ id: 'f1', name: 'BCNA306E5ZSN', manufacturer: 'Beko', category: 'fridge',
              category_label: 'Chladnička', deleted: false, writable: true, blocks: [],
              shop_urls: [], sheet_urls: [], attachments: [], thumbs: {}, fields: {} });
ok(A.apCardToJob(), '„Do zákazky" z karty katalógu');
eq(BUD.draft[0][1].catalog_id, 'f1', 'nesie model z karty');
eq(BUD.draft[0][1].nazov, 'Beko BCNA306E5ZSN', 'názov skladá klient rovnako ako našepkávač');
eq(BUD.draft[0][1].typ, 'fridge', 'aj kategóriu');

reset();
A.apSetCard({ id: 'f1', name: 'BCNA306E5ZSN', manufacturer: 'Beko', category: 'fridge',
              deleted: true, writable: true, blocks: [], shop_urls: [], sheet_urls: [],
              attachments: [], thumbs: {}, fields: {} });
ok(!A.apCardToJob(), 'VYRADENÝ model sa do zákazky nepriradí');
eq(BUD.draft.length, 0, 'a modal sa ani neotvorí');
ok(A.apCardHtml({ id: 'f1', name: 'X', deleted: true, blocks: [], shop_urls: [], sheet_urls: [],
                  attachments: [] }).indexOf('data-ap="tojob"') < 0,
   'tombstone tlačidlo ani nemá');

// ---------------------------------------------------------------------------
// 6) ZÁPISY IDÚ KANÁLOM ROZPOČTU (jeden transakčný vstup väzby)
// ---------------------------------------------------------------------------
reset();
A.apSetTree(tree({ job: job() }));
A.apSetView('job');
click(btn({ 'data-ap': 'junbind', 'data-id': 'I-FRIDGE' }));
eq(BUD.send.length, 1, 'odpojenie ide `budget_mutate`, nie vlastnou akciou sekcie');
eq(BUD.send[0][0], 'appliance_owner');
eq(BUD.send[0][1], { id: 'I-FRIDGE', owner: { kind: 'job', id: '', pid: null } },
   'odpojenie = vlastník „len zákazka"');

click(btn({ 'data-ap': 'jedit', 'data-id': 'I-FRIDGE' }));
eq(BUD.more, ['I-FRIDGE'], 'ceruzka otvára editor položky ROZPOČTU (plná sada polí)');

A.apSetJobDoc({ model_guid: 'DOC-1', gen: 7 });
click(btn({ 'data-ap': 'jsel', 'data-id': 'I-FRIDGE' }));
{
  const sel = SENT.filter(function(x){ return x[0] === 'appl_job_select'; });
  eq(sel.length, 1, 'oko je jediná vlastná akcia sekcie');
  // Codex #383 kolo 1 (P2): s identitou PAYLOADU (dokument + kolo okna) —
  // klik zo zastaraného pohľadu server odmietne.
  eq(JSON.parse(sel[0][1]),
     { kind: 'cabinet', id: 'CAB-3', pid: 11, model_guid: 'DOC-1', gen: 7 },
     'identitu posiela SERVER v riadku — klient si ju neskladá z textu');
}

click(btn({ 'data-ap': 'jbudget' }));
ok(BUD.goto.indexOf('section:budget') >= 0 && BUD.goto.indexOf('appliances') >= 0,
   'medzisúčet je PREKLIK do Rozpočtu');

// ---------------------------------------------------------------------------
// 7) ECHO: tabuľka chodí LEN plným pushom
// ---------------------------------------------------------------------------
reset();
A.apSetTree(tree({ job: job() }));
ok(A.apState().job !== null, 'plný push tabuľku prinesie');
A.apSetTree(tree({ gen: 2 }));            // echo po zápise do katalógu
ok(A.apState().job !== null, 'echo katalógu ju NEVYMAŽE');
eq(A.apState().job.rows.length, 3, 'a nechá v nej presne to, čo prišlo naposledy');

// ---------------------------------------------------------------------------
// 8) DEEP-LINK z Kontroly (kotva `appliance:<uuid>`)
// ---------------------------------------------------------------------------
reset();
A.apSetTree(tree({ job: job() }));
ok(A.apOpenAnchor('appliance:I-FRIDGE'), 'kotva nájde riadok');
eq(A.apState().view, 'job', 'a prepne pohľad na „V zákazke"');
eq(A.apState().jobFocus, 'I-FRIDGE', 'riadok sa prisvieti');
ok(A.apJobRowHtml(jobRow()).indexOf('focus') > 0, 'a je to vidieť v triede riadku');
ok(!A.apOpenAnchor('appliance:NEEXISTUJE'),
   'riadok, ktorý medzitým zanikol, NIE JE tichý no-op');
ok(!A.apOpenAnchor('material:K009'), 'cudzia kotva sekciu nezaujíma');

// ---------------------------------------------------------------------------
// 9) RIADOK „SPOTREBIČ" v Inspectore
// ---------------------------------------------------------------------------
const BOUND = { state: 'bound', item_id: 'I-1', category: 'fridge',
                category_label: 'Chladnička', text: 'Beko BCNA306E5ZSN',
                sub: 'Chladnička', tone: 'ok', link: true };
const EXPECTED = { state: 'expected', item_id: null, category: 'oven', category_label: 'Rúra',
                   text: 'očakáva: rúra', sub: '1 z 2 sa zmestí do niky', tone: 'warn',
                   link: true, placeholder: 'vyber model…',
                   options: [{ item_id: 'OK', fits: true, text: 'Whirlpool OMSR58', hint: '' },
                             { item_id: 'NO', fits: false, hint: 'hĺbka 540 < 560',
                               text: 'Bosch HBG774 (nesedí: hĺbka 540 < 560)' }],
                   all: true, all_note: '— zobraziť všetky (1)' };

{
  const html = R.aprRowHtml(BOUND);
  ok(html.indexOf('Beko BCNA306E5ZSN') > 0, 'viazaný riadok menuje model');
  ok(html.indexOf('data-apr="unbind"') > 0, 'a ponúka „odpojiť"');
  ok(html.indexOf('<select') < 0, 'viazaný riadok druhý výber NEMÁ (výmena ide cez Štúdio)');
  ok(html.indexOf('data-apr="studio"') > 0, 'odkaz do Štúdia je vždy');
}
{
  const html = R.aprRowHtml(EXPECTED);
  const first = html.indexOf('<option');
  ok(html.indexOf('<option value="">vyber model…</option>') === first,
     'PRVÁ voľba je neutrálna — prehliadač inak vyberie model a naviaže ho');
  ok(html.indexOf('nesedí') > 0, 'model, ktorý nesedí, v ponuke OSTÁVA s dôvodom');
  ok(html.indexOf('— zobraziť všetky (1)') > 0, 'a riadok prizná, že filter nie je brána');
  ok(html.indexOf('data-apr="unbind"') < 0, 'očakávanie sa odpojiť nedá');
}
{
  const evil = R.aprRowHtml(Object.assign({}, BOUND, { text: '<b>x</b>' }));
  ok(evil.indexOf('<b>x</b>') < 0 && evil.indexOf('&lt;b&gt;') > 0, 'text je escapovaný');
}

// --- vykreslenie + kontext vlastníka z DOM ----------------------------------
ELS.applRows._attrs = {}; ELS.boardApplRows._attrs = {};
ok(R.renderApplianceRows([BOUND], { kind: 'cabinet', id: 'CAB-3' }, 'applRows'),
   'riadky sa vykreslia do Základných');
eq(ELS.applRows.hidden, false, 'a kontajner je viditeľný');
eq(ELS.applRows.getAttribute('data-apr-kind'), 'cabinet');
eq(ELS.applRows.getAttribute('data-apr-id'), 'CAB-3');
ok(!R.renderApplianceRows([], { kind: 'cabinet', id: 'CAB-3' }, 'applRows'),
   'prázdny zoznam vráti false');
eq(ELS.applRows.hidden, true, 'a riadok sa SCHOVÁ (vertikálny priestor je vzácny)');

R.renderApplianceRows([BOUND], { kind: 'board', id: 'BRD-2' }, 'boardApplRows');
eq(ELS.boardApplRows.getAttribute('data-apr-kind'), 'board', 'karta dosky má vlastný kontext');
eq(R.aprPayload({ item_id: 'I-1' }, { kind: 'board', id: 'BRD-2' }),
   { item_id: 'I-1', board_id: 'BRD-2' }, 'doska posiela `board_id`');
eq(R.aprPayload({ item_id: 'I-1' }, { kind: 'cabinet', id: 'CAB-3' }),
   { item_id: 'I-1', cabinet_id: 'CAB-3' }, 'skrinka `cabinet_id`');

// --- zápis z riadku ----------------------------------------------------------
reset();
R.renderApplianceRows([EXPECTED], { kind: 'cabinet', id: 'CAB-3' }, 'applRows');
{
  const sel = stubEl('sel');
  sel.setAttribute('data-apr', 'pick');
  sel.value = 'OK';
  sel._owner = ELS.applRows;
  sel.closest = function(s){
    if (s === '[data-apr-kind]') return ELS.applRows;
    return null;
  };
  change(sel);
  const rows = SENT.filter(function(x){ return x[0] === 'set_appliance_owner'; });
  eq(rows.length, 1, 'výber modelu = jeden zápis');
  eq(JSON.parse(rows[0][1]), { model_guid: 'G', item_id: 'OK', cabinet_id: 'CAB-3' },
     'posiela sa LEN čo priradiť + echo ID (vlastníka skladá server z výberu)');
  SENT.length = 0;
  sel.value = '';
  change(sel);
  eq(SENT.length, 0, 'neutrálna voľba nezapisuje nič');
}
{
  const b = btn({ 'data-apr': 'unbind', 'data-id': 'I-1' });
  b._owner = ELS.applRows;
  b.closest = function(s){
    if (s === '[data-apr]') return b;
    if (s === '[data-apr-kind]') return ELS.applRows;
    return null;
  };
  SENT.length = 0;
  click(b);
  const rows = SENT.filter(function(x){ return x[0] === 'set_appliance_owner'; });
  eq(JSON.parse(rows[0][1]).unbind, true, '„odpojiť" posiela príznak, nie vlastnú akciu');
}
{
  const b = btn({ 'data-apr': 'studio', 'data-id': 'I-1' });
  BUD.goto.length = 0;
  click(b);
  eq(BUD.goto, ['studio:appl:appliance:I-1'],
     'odkaz vedie na TEN ISTÝ riadok ako nález Kontroly');
}

// --- Codex #383 kolo 1 (P2): odchod z kontextu riadky ZAHODÍ ----------------
{
  R.renderApplianceRows([BOUND], { kind: 'cabinet', id: 'CAB-3' }, 'applRows');
  eq(ELS.applRows.hidden, false, 'východisko: riadok je vykreslený');
  ok(R.clearApplianceRows('applRows'), 'odznačenie riadky zahodí');
  eq(ELS.applRows._html, '', 'obsah je preč (nie iba skrytý)');
  eq(ELS.applRows.hidden, true);
  eq(ELS.applRows.getAttribute('data-apr-kind'), null,
     'a s ním aj KONTEXT vlastníka — stará akcia nemá kam poslať zápis');
  eq(R.aprCtxOf(ELS.applRows), null, 'kontext sa už nedá vyriešiť');
}
{
  // Zdrojový guard: obe cesty odchodu z kontextu skrinky riadky čistia.
  const fs = require('node:fs');
  const src = fs.readFileSync(path.join(JS, 'bridge.js'), 'utf8');
  const clear = src.slice(src.indexOf('clearSelected: function(guid)'),
                          src.indexOf('setStatus: function(msg, err)'));
  const board = src.slice(src.indexOf('loadBoard: function(b)'),
                          src.indexOf('clearSelected: function(guid)'));
  ok(clear.indexOf('clearApplianceRows') > -1, 'prázdny výber riadky zahodí');
  ok(board.indexOf("clearApplianceRows('applRows')") > -1,
     'a prechod na dosku zahodí KORPUSOVÝ riadok (doska má vlastný)');
}

// ---------------------------------------------------------------------------
// 10) BADGE navigácie — číslo skladá server
// ---------------------------------------------------------------------------
{
  // Plný push cez ten istý vstup, aký má okno (`NX.setStudio`) — `ST` je
  // modulová premenná studio.js a inak sa k nej dostať nedá. Render nad DOM
  // stubom môže vypadnúť; podstatné je, že payload je dosadený PRED ním.
  try {
    global.window.NX.setStudio({
      gen: 1, model_guid: 'G', model_title: 'T', version: '0.0.0',
      counts: { red: 1, orange: 2 }, control: [], rows: [], sheets: [], edging: [],
      appl: tree({ job: job({ counts: { red: 0, orange: 5, total: 5 } }) })
    });
  } catch (e) { /* render nad DOM stubom nie je predmetom tohto testu */ }
  eq(S.navCounts('appl'), { red: 0, orange: 5, total: 5 }, 'badge sekcie je z `appl.job.counts`');
  eq(S.navCounts(true), { red: 1, orange: 2 }, 'Kontrola má ďalej svoje vlastné');
  ok(S.navBadgeHtml(S.navCounts('appl')).indexOf('5') > 0, 'a vykreslí sa');
  ok(S.NAV.some(function(g){
    return g.items.some(function(it){ return it.id === 'appl' && it.badge === 'appl'; });
  }), 'položka navigácie si pýta PRÁVE tieto počty');
}

// --- MUTÁCIE (čo test naozaj chytí) -----------------------------------------
// M1 „tabuľka sa radí na klientovi" zabije test poradia v bloku 2.
// M2 „prvá voľba ponuky je model" zabije test v bloku 9.
// M3 „kontext vlastníka drží globál" zabije test karty dosky v bloku 9
//     (druhé vykreslenie by prepísalo kontext skrinky).

console.log('OK test_s1b2_pohlad.js — ' + n + ' kontrol');
