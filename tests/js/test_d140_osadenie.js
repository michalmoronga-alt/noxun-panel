// D-140 — VÝŠKA OSADENIA CHLADNIČKY: čip v riadku Spotrebič + statický popover.
//
// Prečo sú to testy a nie klikanie (Astra C BLOCKER 2 + FIX 8):
//   1. ZÁPIS IDE LEN CEZ „Použiť"/Enter — nikdy `blur`. Pri prepnutí dokumentu
//      `nxSetModelGuid` najprv prepíše identitu a až potom zhodí fokus; uloženie
//      na `blur` by starú hodnotu odoslalo s NOVÝM dokumentom.
//   2. Popover si pri OTVORENÍ zachytí dokument, kus (druh, ID, PID), `item_id`
//      a PÔVODNÚ hodnotu — a pošle PRESNE tie, nie stav okna v čase odoslania.
//   3. Popover je STATICKÝ uzol mimo `#applRows`: echo prestavby prekreslí
//      riadky, ale rozpísanú hodnotu nezmaže. Zmena dokumentu, kusu alebo
//      zánik riadku ho ZAVRIE BEZ ZÁPISU.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_s1c_expects.js, s funkčným classList) -----
const ELS = {};
function stubEl(id){
  const cls = new Set();
  const n = { id, style: {}, children: [], _html: '', _attrs: {}, value: '', hidden: false,
              focused: 0, selected: 0,
              classList: {
                add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); }
              } };
  Object.defineProperty(n, 'innerHTML', { get(){ return n._html; }, set(v){ n._html = v; } });
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){
    return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null;
  };
  n.removeAttribute = function(k){ delete n._attrs[k]; };
  n.closest = function(sel){ return (n._closest && n._closest[sel]) ? n._closest[sel] : null; };
  n.focus = function(){ n.focused++; };
  n.select = function(){ n.selected++; };
  n.addEventListener = function(){};
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  return n;
}
['applRows', 'boardApplRows', 'aprMountPop', 'aprMountVal'].forEach(function(id){ ELS[id] = stubEl(id); });
ELS.aprMountPop.hidden = true;
// Kontajner riadkov je „[data-apr-kind]" pre seba (aprCtxOf hľadá cez closest).
ELS.applRows.closest = function(sel){ return sel === '[data-apr-kind]' ? ELS.applRows : null; };
ELS.boardApplRows.closest = function(sel){ return sel === '[data-apr-kind]' ? ELS.boardApplRows : null; };

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
// Identita dokumentu ako v shell.js: `nxDocPayload(obj, guid)` berie ZACHYTENÝ
// guid, inak aktuálny.
let DOC = 'doc-A';
global.nxDocGuid = function(){ return DOC; };
global.nxDocPayload = function(obj, guid){
  const o = obj || {};
  o.model_guid = (guid === undefined || guid === null) ? DOC : String(guid);
  return JSON.stringify(o);
};
global.openStudio = function(){};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const R = require(path.join(JS, 'appliance_row.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

// Riadok viazanej chladničky v tvare `Panel.appliance_bound_row`.
function fridgeRow(extra){
  return Object.assign({
    state: 'bound', item_id: 'I-1', category: 'fridge', category_label: 'chladnička',
    text: 'Beko BCNA306E5ZSN', sub: 'nika ✓', tone: 'ok', link: true,
    mount: { value: 150, text: 'osadenie 150 mm' }
  }, extra || {});
}
const CTX = { kind: 'cabinet', id: 'CAB-3', pid: 303 };

// Tlačidlo čipu tak, ako ho po kliknutí vidí handler (leží v #applRows).
function chip(item, v, box){
  const b = stubEl('chip');
  b._attrs = { 'data-apr': 'mount', 'data-id': item || 'I-1', 'data-v': String(v == null ? 150 : v) };
  b.closest = function(sel){
    if (sel === '[data-apr-kind]') return box || ELS.applRows;
    if (sel === '[data-apr]' || sel === '[data-apr="mount"]') return b;
    return null;
  };
  return b;
}
function fire(type, ev){ (LISTEN[type] || []).forEach(function(fn){ fn(ev); }); }
function lastSent(){ return SENT.length ? [SENT[SENT.length - 1][0], JSON.parse(SENT[SENT.length - 1][1])] : null; }
function reset(){ R.aprMountClose(); SENT.length = 0; DOC = 'doc-A'; ELS.aprMountVal.value = ''; ELS.aprMountVal.classList.remove('bad'); }

// ---------------------------------------------------------------------------
// 1) ČIP V RIADKU — len viazaná chladnička v skrinke (rozhoduje server)
// ---------------------------------------------------------------------------
{
  const h = R.aprRowHtml(fridgeRow());
  ok(h.indexOf('class="apmount"') > 0 && h.indexOf('data-apr="mount"') > 0, 'čip osadenia je v riadku');
  ok(h.indexOf('data-id="I-1"') > 0 && h.indexOf('data-v="150"') > 0, 'nesie kus aj pôvodnú hodnotu');
  ok(h.indexOf('aria-controls="aprMountPop"') > 0, 'ovláda statický popover');
  ok(h.indexOf('>osadenie 150 mm</button>') > 0, 'text je zo servera');
  ok(h.indexOf('data-apr="mount"') < h.indexOf('data-apr="unbind"'), 'čip je PRED odpojením (jeden riadok)');
  ok(h.indexOf('<input') < 0, 'v riadku NIE JE pole — zápis ide len cez popover');

  const oven = R.aprRowHtml(fridgeRow({ category: 'oven', mount: undefined }));
  ok(oven.indexOf('apmount') < 0, 'rúra čip nemá (server `mount` neposlal)');
  const pick = R.aprRowHtml(fridgeRow({ state: 'empty', options: [] }));
  ok(pick.indexOf('apmount') < 0, 'neviazaný riadok čip nemá, aj keby `mount` prišiel');
  const esc = R.aprRowHtml(fridgeRow({ mount: { value: '1"><b', text: '<x>' } }));
  ok(esc.indexOf('1"><b') < 0 && esc.indexOf('data-v="1&quot;&gt;&lt;b"') > 0 &&
     esc.indexOf('<x>') < 0 && esc.indexOf('&lt;x&gt;') > 0, 'hodnota aj text sa escapujú');
}

// ---------------------------------------------------------------------------
// 2) ČÍSLO Z POĽA — čiarka aj bodka, nič iné
// ---------------------------------------------------------------------------
{
  eq(R.aprMountParse('150'), 150, 'celé číslo');
  eq(R.aprMountParse('150,5'), 150.5, 'desatinná čiarka (SK)');
  eq(R.aprMountParse(' 12.5 '), 12.5, 'bodka a medzery');
  ok(Number.isNaN(R.aprMountParse('abc')), 'text = neplatné');
  ok(Number.isNaN(R.aprMountParse('')), 'prázdne = neplatné (nie 0)');
  ok(Number.isNaN(R.aprMountParse('1e3')), 'exponent nie');
  ok(Number.isNaN(R.aprMountParse('10+5')), 'výraz nie (výrazové polia sú len rozmery korpusu)');
  eq(R.aprMountFmt(150), '150');
  eq(R.aprMountFmt(150.5), '150,5');
  eq(R.aprMountFmt(0), '0');
}

// ---------------------------------------------------------------------------
// 3) OTVORENIE ZACHYTÍ dokument, kus a pôvodnú hodnotu; Použiť pošle PRESNE tie
// ---------------------------------------------------------------------------
{
  reset();
  R.renderApplianceRows([fridgeRow()], CTX);
  ok(R.aprMountOpen(chip('I-1', 150)), 'popover sa otvorí');
  eq(ELS.aprMountPop.hidden, false, 'je viditeľný');
  eq(ELS.aprMountVal.value, '150', 'pole ukazuje pôvodnú hodnotu');
  ok(ELS.aprMountVal.focused > 0 && ELS.aprMountVal.selected > 0, 'fokus + označenie (hneď sa píše)');
  const st = R.aprMountState();
  eq([st.guid, st.item, st.prev], ['doc-A', 'I-1', 150], 'zachytený dokument, kus aj pôvodná hodnota');
  eq([st.ctx.kind, st.ctx.id, st.ctx.pid], ['cabinet', 'CAB-3', '303'], 'vlastník z DOM kontajnera');

  ELS.aprMountVal.value = '200';
  ok(R.aprMountApply(), 'Použiť odošle');
  eq(lastSent(), ['set_appliance_mount',
                  { item_id: 'I-1', value: 200, prev: 150, cabinet_id: 'CAB-3', pid: '303', model_guid: 'doc-A' }],
     'payload = zachytený stav + nová hodnota');
  eq(ELS.aprMountPop.hidden, true, 'po odoslaní sa zavrie');
  eq(R.aprMountState(), null, 'a stav sa zahodí');
}

// Payload ako čistá funkcia (bez DOM).
{
  const p = R.aprMountPayload({ item: 'I-7', prev: 0, ctx: { kind: 'cabinet', id: 'CAB-9', pid: '909' } }, 120);
  eq(p, { item_id: 'I-7', value: 120, prev: 0, cabinet_id: 'CAB-9', pid: '909' }, 'čistý payload');
}

// ---------------------------------------------------------------------------
// 4) PREPNUTIE DOKUMENTU medzi otvorením a odoslaním — ide ZACHYTENÝ dokument
// ---------------------------------------------------------------------------
{
  reset();
  R.renderApplianceRows([fridgeRow()], CTX);
  R.aprMountOpen(chip('I-1', 150));
  DOC = 'doc-B'; // push z iného okna ešte riadky neprekreslil
  ELS.aprMountVal.value = '180';
  R.aprMountApply();
  eq(lastSent()[1].model_guid, 'doc-A', 'odchádza dokument z času otvorenia (server cudzí odmietne)');
}

// ---------------------------------------------------------------------------
// 5) NEZMENENÁ alebo NEPLATNÁ hodnota — nič sa neposiela
// ---------------------------------------------------------------------------
{
  reset();
  R.renderApplianceRows([fridgeRow()], CTX);
  R.aprMountOpen(chip('I-1', 150));
  ELS.aprMountVal.value = '150,0';
  eq(R.aprMountApply(), false, 'tá istá hodnota = žiadna prestavba');
  eq(SENT.length, 0);
  eq(ELS.aprMountPop.hidden, true, 'ale popover sa zavrie');

  R.aprMountOpen(chip('I-1', 150));
  ELS.aprMountVal.value = 'abc';
  eq(R.aprMountApply(), false, 'neplatné sa neodošle');
  ok(ELS.aprMountVal.classList.contains('bad'), 'pole sa označí');
  eq(ELS.aprMountPop.hidden, false, 'popover ostáva — dá sa opraviť');
  ELS.aprMountVal.value = '-5';
  eq(R.aprMountApply(), false, 'záporné sa neodošle');
  eq(SENT.length, 0, 'nič neodišlo');
  R.aprMountOpen(chip('I-1', 150));
  ok(!ELS.aprMountVal.classList.contains('bad'), 'nové otvorenie začína čisto');
}

// ---------------------------------------------------------------------------
// 6) PREKRESLENIE RIADKOV — rozpísaná hodnota prežije echo TOHO ISTÉHO kusu
// ---------------------------------------------------------------------------
{
  reset();
  R.renderApplianceRows([fridgeRow()], CTX);
  R.aprMountOpen(chip('I-1', 150));
  ELS.aprMountVal.value = '17';
  R.renderApplianceRows([fridgeRow()], CTX); // echo prestavby / nový payload
  ok(R.aprMountState() !== null, 'popover žije ďalej');
  eq(ELS.aprMountVal.value, '17', 'rozpísaná hodnota prežila (FIX 8)');
  R.renderApplianceRows([fridgeRow()], { kind: 'board', id: 'BRD-1', pid: 1 }, 'boardApplRows');
  ok(R.aprMountState() !== null, 'karta dosky popover skrinky nezavrie');

  const closers = [
    ['iná skrinka', [fridgeRow()], { kind: 'cabinet', id: 'CAB-4', pid: 404 }, 'doc-A'],
    ['iný PID (recyklované ID)', [fridgeRow()], { kind: 'cabinet', id: 'CAB-3', pid: 999 }, 'doc-A'],
    ['kus zmizol z riadkov', [fridgeRow({ item_id: 'I-2' })], CTX, 'doc-A'],
    ['riadok už osadenie nemá', [fridgeRow({ mount: undefined })], CTX, 'doc-A'],
    ['iný dokument', [fridgeRow()], CTX, 'doc-B']
  ];
  closers.forEach(function(c){
    reset();
    R.renderApplianceRows([fridgeRow()], CTX);
    R.aprMountOpen(chip('I-1', 150));
    DOC = c[3];
    R.renderApplianceRows(c[1], c[2]);
    eq(R.aprMountState(), null, c[0] + ' → popover sa zavrie BEZ zápisu');
    eq(ELS.aprMountPop.hidden, true, c[0] + ' → skrytý');
    eq(SENT.length, 0, c[0] + ' → nič neodišlo');
  });

  reset();
  R.renderApplianceRows([fridgeRow()], CTX);
  R.aprMountOpen(chip('I-1', 150));
  R.clearApplianceRows('applRows');
  eq(R.aprMountState(), null, 'kus zmizol z okna → zavrieť');
}

// ---------------------------------------------------------------------------
// 7) KLÁVESY A KLIKY — Enter = Použiť, Escape / klik mimo = zrušiť
// ---------------------------------------------------------------------------
{
  const noop = function(){};
  reset();
  R.renderApplianceRows([fridgeRow()], CTX);
  fire('click', { target: chip('I-1', 150) });
  ok(R.aprMountState() !== null, 'klik na čip otvorí popover');
  ELS.aprMountVal.value = '90';
  fire('keydown', { key: 'Enter', target: ELS.aprMountVal, preventDefault: noop });
  eq(lastSent()[1].value, 90, 'Enter = Použiť');
  eq(R.aprMountState(), null);

  SENT.length = 0;
  fire('click', { target: chip('I-1', 150) });
  ELS.aprMountVal.value = '90';
  let stopped = 0;
  fire('keydown', { key: 'Escape', target: ELS.aprMountVal, preventDefault: noop,
                    stopImmediatePropagation: function(){ stopped++; } });
  eq([R.aprMountState(), SENT.length], [null, 0], 'Escape zruší bez zápisu');
  eq(stopped, 1, 'Escape sa spotrebuje (popover je najvyššia vrstva)');

  // Codex #389 P2: Escape aj z TLAČIDLA v popoveri (Tab z poľa na Použiť/Zrušiť/Pomoc).
  const tabbed = stubEl('tabbed-ok');
  tabbed._attrs = { 'data-apr': 'mount-ok' };
  fire('click', { target: chip('I-1', 150) });
  ELS.aprMountVal.value = '90';
  fire('keydown', { key: 'Escape', target: tabbed, preventDefault: noop });
  eq([R.aprMountState(), SENT.length], [null, 0], 'Escape z tlačidla v popoveri zruší bez zápisu');
  fire('click', { target: chip('I-1', 150) });
  fire('keydown', { key: 'Enter', target: tabbed, preventDefault: noop });
  ok(R.aprMountState() !== null && SENT.length === 0,
     'Enter na tlačidle nerieši keydown (vybaví ho klik tlačidla), pole nie je odoslané');
  R.aprMountClose();
  stopped = 0;
  fire('keydown', { key: 'Escape', target: tabbed, preventDefault: noop,
                    stopImmediatePropagation: function(){ stopped++; } });
  eq(stopped, 0, 'zatvorený popover Escape nespotrebúva (patrí iným vrstvám)');

  fire('click', { target: chip('I-1', 150) });
  const inside = stubEl('inside');
  inside.closest = function(sel){ return sel === '#aprMountPop' ? ELS.aprMountPop : null; };
  fire('mousedown', { target: inside });
  ok(R.aprMountState() !== null, 'klik DO popoveru ho nezavrie');
  const outside = stubEl('outside');
  fire('mousedown', { target: outside });
  eq([R.aprMountState(), SENT.length], [null, 0], 'klik mimo zruší bez zápisu');

  fire('click', { target: chip('I-1', 150) });
  ELS.aprMountVal.value = '45';
  const okBtn = stubEl('ok');
  okBtn._attrs = { 'data-apr': 'mount-ok' };
  okBtn.closest = function(sel){ return sel === '[data-apr]' ? okBtn : null; };
  fire('click', { target: okBtn });
  eq(lastSent()[1].value, 45, 'tlačidlo Použiť');
  const cancel = stubEl('cancel');
  cancel._attrs = { 'data-apr': 'mount-cancel' };
  cancel.closest = function(sel){ return sel === '[data-apr]' ? cancel : null; };
  SENT.length = 0;
  fire('click', { target: chip('I-1', 150) });
  fire('click', { target: cancel });
  eq([R.aprMountState(), SENT.length], [null, 0], 'Zrušiť');
}

// ---------------------------------------------------------------------------
// 7b) FOKUS (Codex #389 kolo 3, P2) — po Escape / Zrušiť / Použiť sa vráti na
//     čip, ale LEN keď bol v popoveri (vzor `closeFrontBulk`); upratovanie pri
//     zmene dokumentu či kusu a klik mimo fokus nepresúvajú.
// ---------------------------------------------------------------------------
{
  const noop = function(){};
  const chipEl = chip('I-1', 150);
  ELS.applRows.querySelectorAll = function(sel){ return sel === '[data-apr="mount"]' ? [chipEl] : []; };
  const inside = stubEl('inside-btn');
  inside.closest = function(sel){ return sel === '#aprMountPop' ? ELS.aprMountPop : null; };
  const away = stubEl('away');
  function openAgain(){ R.renderApplianceRows([fridgeRow()], CTX); R.aprMountOpen(chipEl); }

  reset(); openAgain();
  global.document.activeElement = inside;
  fire('keydown', { key: 'Escape', target: inside, preventDefault: noop });
  eq(chipEl.focused, 1, 'Escape v popoveri vráti fokus na čip');

  openAgain(); global.document.activeElement = inside;
  const cancelBtn = stubEl('cancel2');
  cancelBtn._attrs = { 'data-apr': 'mount-cancel' };
  cancelBtn.closest = function(sel){ return sel === '[data-apr]' ? cancelBtn : null; };
  fire('click', { target: cancelBtn });
  eq(chipEl.focused, 2, 'Zrušiť vráti fokus na čip');

  openAgain(); global.document.activeElement = inside;
  ELS.aprMountVal.value = '150';
  R.aprMountApply();
  eq([chipEl.focused, SENT.length], [3, 0], 'Použiť bez zmeny: fokus na čip, nič neodišlo');

  openAgain(); global.document.activeElement = away;
  fire('keydown', { key: 'Escape', target: away, preventDefault: noop });
  eq([R.aprMountState(), chipEl.focused], [null, 3], 'Escape mimo popoveru zavrie, ale fokus neťahá späť');

  openAgain(); global.document.activeElement = inside;
  fire('mousedown', { target: away });
  eq([R.aprMountState(), chipEl.focused], [null, 3], 'klik mimo: fokus patrí tomu, na čo sa kliklo');

  openAgain(); global.document.activeElement = inside;
  R.renderApplianceRows([fridgeRow()], { kind: 'cabinet', id: 'CAB-4', pid: 404 });
  eq([R.aprMountState(), chipEl.focused], [null, 3], 'zmena kusu (upratovanie) fokus nepresúva');

  openAgain(); global.document.activeElement = inside;
  R.aprMountClose(); // tak volá nxDropDocState pri zmene dokumentu
  eq(chipEl.focused, 3, 'zmena dokumentu fokus nepresúva');

  ELS.applRows.querySelectorAll = function(){ return []; };
  global.document.activeElement = null;
  reset();
}

// ---------------------------------------------------------------------------
// 8) GUARDY ZDROJA — žiadny blur zápis, popover je statický, CSS schová [hidden]
// ---------------------------------------------------------------------------
{
  const src = fs.readFileSync(path.join(JS, 'appliance_row.js'), 'utf8');
  ok(!/addEventListener\('(blur|focusout)'/.test(src), 'riadok Spotrebič NIKDY neukladá na blur (BLOCKER 2)');
  ok(src.indexOf('sketchup.set_appliance_mount(nxDocPayload(aprMountPayload(s, v), s.guid))') > 0,
     'odosiela sa ZACHYTENÝ dokument');

  const html = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'panel.html'), 'utf8');
  const iRows = html.indexOf('id="applRows"');
  const iPop = html.indexOf('id="aprMountPop"');
  ok(iRows > 0 && iPop > iRows, 'popover je STATICKÝ uzol ZA #applRows (prekreslenie ho nezmaže)');
  const pop = html.slice(iPop, html.indexOf('</div>', html.indexOf('data-apr="mount-cancel"')));
  ok(/id="aprMountPop"[^>]*\bhidden\b/.test(html), 'predvolene skrytý');
  ok(pop.indexOf('id="aprMountVal"') > 0, 'pole hodnoty');
  ok(pop.indexOf('data-apr="mount-ok"') > 0 && pop.indexOf('data-apr="mount-cancel"') > 0, 'Použiť + Zrušiť');
  ok(!/on(blur|change|input)=/.test(pop), 'pole nemá inline zápis');

  const css = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'css', 'panel.css'), 'utf8');
  ok(css.indexOf('.nx-inspector .aprmountpop[hidden] { display: none; }') > 0,
     'autorský `display: flex` nesmie prebiť [hidden] (poučenie D-137)');
}

console.log('test_d140_osadenie: ' + n + ' kontrol OK');
