// S1-C — OČAKÁVANÝ SPOTREBIČ v UI: pole modalu D-14 + riadok voľby „očakáva".
//
// Prečo sú to testy a nie klikanie:
//   1. RIADOK VOĽBY posiela ÚPLNÝ zoznam, nie „pridaj/odober". Keby klient
//      poslal len jednu kategóriu, pridanie mikrovlnky by TICHO zmazalo
//      očakávanie rúry — a Kontrola by prestala upozorňovať na chýbajúci
//      spotrebič, ktorý si používateľ vyžiadal.
//   2. PRVÁ VOĽBA ponuky je neutrálny SÚHRN. `<select>` bez vyslovenej hodnoty
//      vyberie prvú možnosť, takže keby ňou bol príkaz, jediné vykreslenie
//      karty by zapísalo očakávanie (a s ním krok Späť).
//   3. SLOT voľbu nemá. Server mu umývačku vynucuje, takže ponuka „očakáva: —"
//      by bola klamstvo.
//   4. MODAL D-14 musí najprv flushnúť rozpísané úpravy skrinky (`nxCabinetAction`)
//      a až potom odoslať — inak sa šablóna uloží zo starých hodnôt a očakávania
//      by odišli s nimi.
//   5. Popisky kategórií NEŽIJÚ v klientovi: text riadku aj text dlaždice skladá
//      server. Druhá mapa by sa časom rozišla s katalógom.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_s1b2_pohlad.js) ---------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '', _attrs: {}, value: '',
              hidden: false, checked: false, disabled: false, title: '', classList: {
                add(){}, remove(){}, contains(){ return false; }
              } };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){
    return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null;
  };
  n.removeAttribute = function(k){ delete n._attrs[k]; };
  n.closest = function(sel){
    if (sel === '[data-apr-kind]' && n._attrs['data-apr-kind'] !== undefined) return n;
    if (sel === '[data-apr-expects]' && n._attrs['data-apr-expects'] !== undefined) return n;
    return (n._closest && n._closest[sel]) ? n._closest[sel] : null;
  };
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  n.focus = function(){};
  n.select = function(){};
  n.addEventListener = function(){};
  return n;
}
['applRows', 'boardApplRows'].forEach(function(id){ ELS[id] = stubEl(id); });

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
global.nxDocPayload = function(obj){ return JSON.stringify(Object.assign({ model_guid: 'G' }, obj)); };
global.openStudio = function(){};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const R = require(path.join(JS, 'appliance_row.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

function change(node){
  (LISTEN.change || []).forEach(function(fn){ fn({ target: node }); });
}

// Riadok voľby v tvare, aký skladá `Panel.appliance_expects_row`.
function pickRow(extra){
  return Object.assign({
    state: 'expects', item_id: null, category: null, category_label: '',
    text: 'očakáva rúru', sub: '', tone: '', link: false,
    expects: ['oven'], placeholder: 'očakáva: rúra',
    options: [
      { value: 'add:fridge', code: 'fridge', op: 'add', text: '+ chladnička', disabled: false },
      { value: 'del:oven', code: 'oven', op: 'del', text: '− rúra', disabled: false },
      { value: 'add:microwave', code: 'microwave', op: 'add', text: '+ mikrovlnka', disabled: false }
    ]
  }, extra || {});
}

// ---------------------------------------------------------------------------
// 1) PONUKA OČAKÁVANÍ — prvá voľba je neutrálna, zamknutá kategória nesie dôvod
// ---------------------------------------------------------------------------
{
  const h = R.aprExpectsHtml(pickRow());
  ok(h.indexOf('<option value="">očakáva: rúra</option>') > 0,
     'PRVÁ voľba je neutrálny súhrn — inak by vykreslenie karty zapísalo očakávanie');
  ok(h.indexOf('data-apr="expects"') > 0, 'zápis ide vlastným kanálom, nie cez `pick`');
  ok(h.indexOf('value="add:fridge"') > 0 && h.indexOf('value="del:oven"') > 0,
     'voľby sú PRÍKAZY (add/del), nie stav');

  const locked = R.aprExpectsHtml(pickRow({
    options: [{ value: 'del:oven', code: 'oven', op: 'del',
                text: '− rúra (priradená — najprv odpoj)', disabled: true }]
  }));
  ok(locked.indexOf('disabled') > 0, 'viazaná kategória je disabled');
  ok(locked.indexOf('najprv odpoj') > 0, 'a nesie DÔVOD — mŕtva voľba bez vysvetlenia je horšia');
}

// ---------------------------------------------------------------------------
// 2) NOVÝ ÚPLNÝ ZOZNAM (čistá funkcia) — pridanie je únia, odobranie filter
// ---------------------------------------------------------------------------
{
  eq(R.aprExpectsNext(['oven'], 'add:microwave'), ['oven', 'microwave'],
     'pridanie NEZMAŽE to, čo už skrinka očakáva');
  eq(R.aprExpectsNext(['oven', 'microwave'], 'del:oven'), ['microwave'],
     'odobranie nechá zvyšok');
  eq(R.aprExpectsNext(['oven'], 'add:oven'), ['oven'], 'dvojité pridanie nič nezdvojí');
  eq(R.aprExpectsNext([], 'del:oven'), [], 'odobranie neexistujúceho je prázdny zoznam');
  eq(R.aprExpectsNext(['oven'], ''), null, 'neutrálna voľba NIČ nepošle');
  eq(R.aprExpectsNext(['oven'], 'add:'), null, 'príkaz bez kategórie sa zahodí');
  eq(R.aprExpectsNext(['oven'], 'nieco'), null, 'neznámy príkaz sa zahodí');
}

// ---------------------------------------------------------------------------
// 3) VYKRESLENIE RIADKU — úplný zoznam ide do DOM, text je zo servera
// ---------------------------------------------------------------------------
{
  const h = R.aprRowHtml(pickRow());
  ok(h.indexOf('data-apr-expects="oven"') > 0,
     'ÚPLNY zoznam žije v DOM — riadok sa prekresľuje celou kartou');
  ok(h.indexOf('očakáva rúru') > 0, 'text skladá server');
  ok(h.indexOf('class="aprow expects"') > 0, 'riadok má vlastnú triedu (tlmený, bez semaforu)');
  ok(h.indexOf('data-apr="unbind"') < 0 && h.indexOf('data-apr="pick"') < 0,
     'voľba nie je ani väzba, ani odpojenie');

  // Meno kategórie píše server, ale HTML sa aj tak escapuje.
  const evil = R.aprRowHtml(pickRow({ text: '<img src=x>', expects: ['a"b'] }));
  ok(evil.indexOf('<img') < 0, 'text je escapovaný');
  ok(evil.indexOf('&quot;') > 0, 'aj hodnota atribútu');
}

// ---------------------------------------------------------------------------
// 4) ZÁPIS — payload nesie ÚPLNY zoznam, identitu kusu a PID
// ---------------------------------------------------------------------------
{
  SENT.length = 0;
  R.renderApplianceRows([pickRow()], { kind: 'cabinet', id: 'CAB-3', pid: 303 }, 'applRows');
  eq(ELS.applRows.getAttribute('data-apr-pid'), '303', 'kontext nesie PID (ID sa recyklujú)');

  // Riadok z DOM sa v stube nedá vyhľadať, preto sa uzol poskladá ručne —
  // podstatné je, ČO sa pošle, nie ako sa našiel.
  const sel = stubEl('sel');
  sel.setAttribute('data-apr', 'expects');
  sel.setAttribute('data-apr-expects', 'oven');
  sel.setAttribute('data-apr-kind', 'cabinet');
  sel.setAttribute('data-apr-id', 'CAB-3');
  sel.setAttribute('data-apr-pid', '303');
  sel.value = 'add:microwave';
  change(sel);
  eq(SENT.length, 1, 'jedna zmena = jeden zápis');
  eq(SENT[0][0], 'set_appliance_expects', 'vlastný callback, nie `set_appliance_owner`');
  const pay = JSON.parse(SENT[0][1]);
  eq(pay.expects, ['oven', 'microwave'], 'posiela sa ÚPLNY zoznam');
  eq(pay.cabinet_id, 'CAB-3', 'echo identity kusu');
  eq(pay.pid, '303', 'a PID z času vykreslenia');
  eq(pay.model_guid, 'G', 'identita dokumentu (R-02)');
  eq(sel.value, '', 'select sa vracia na neutrálny súhrn — pravdu prinesie čerstvá karta');

  // Neutrálna voľba NIČ nepošle.
  SENT.length = 0;
  sel.value = '';
  change(sel);
  eq(SENT.length, 0, 'neutrálna voľba zápis nespustí');

  // DOSKA posiela `board_id`.
  SENT.length = 0;
  const bsel = stubEl('bsel');
  bsel.setAttribute('data-apr', 'expects');
  bsel.setAttribute('data-apr-expects', '');
  bsel.setAttribute('data-apr-kind', 'board');
  bsel.setAttribute('data-apr-id', 'BRD-2');
  bsel.setAttribute('data-apr-pid', '21');
  bsel.value = 'add:sink';
  change(bsel);
  const bpay = JSON.parse(SENT[0][1]);
  eq(bpay.board_id, 'BRD-2', 'doska je plnohodnotný vlastník');
  eq(bpay.expects, ['sink']);
  ok(bpay.cabinet_id === undefined, 'a NEPOSIELA skrinku');
}

// ---------------------------------------------------------------------------
// 5) ODCHOD Z KONTEXTU zahodí aj PID
// ---------------------------------------------------------------------------
{
  R.renderApplianceRows([pickRow()], { kind: 'cabinet', id: 'CAB-3', pid: 303 }, 'applRows');
  R.clearApplianceRows('applRows');
  eq(ELS.applRows.getAttribute('data-apr-pid'), null,
     's kontajnerom odchádza CELÝ kontext — inak by zápis odišiel na kus, ktorý nikto nevidí');
}

// ---------------------------------------------------------------------------
// 6) MODAL D-14 — pole „Očakáva" (zdroj, nie DOM: modal žije vo form.js)
// ---------------------------------------------------------------------------
{
  const form = fs.readFileSync(path.join(JS, 'form.js'), 'utf8');
  const html = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'panel.html'),
                               'utf8');
  ok(html.indexOf('id="tplSaveExpects"') > 0, 'pole je v D-14 modale (panel.html)');
  ['fridge', 'oven', 'microwave'].forEach(function(c){
    ok(html.indexOf('data-tplexp="' + c + '"') > 0, 'checkbox ' + c);
  });
  ok(html.indexOf('data-tplexp="dishwasher"') < 0,
     'umývačku modal neponúka — pri slote je voľba daná a server ju vynucuje');

  ok(form.indexOf('function nxSyncTplSaveExpects') > 0, 'zrkadlo očakávaní do modalu');
  ok(form.indexOf('nxSyncTplSaveExpects(getType())') > 0, 'volá sa pri OTVORENÍ modalu');
  ok(form.indexOf('cabApplianceExpects') > 0, 'predvyplní sa z configu označenej skrinky');

  // SLOT: checkboxy sa zamknú a payload ich NEPOSIELA.
  const sync = form.slice(form.indexOf('function nxSyncTplSaveExpects'));
  ok(sync.indexOf("t === 'dishwasher'") > 0, 'slot sa rozpozná');
  ok(sync.indexOf('inp.disabled = slot') > 0, 'a voľby sa zamknú');
  const value = form.slice(form.indexOf('function nxTplSaveExpectsValue'));
  ok(value.indexOf("if (t === 'dishwasher') return null") > 0,
     'slot `expects` NEPOSIELA — prázdny zoznam by vyzeral ako „nič neočakáva"');

  // Uloženie: flush rozpísaných úprav ide PRED odoslaním (inak stará hodnota).
  const save = form.slice(form.indexOf('function saveTemplateAs'),
                          form.indexOf('function bindTplModal'));
  ok(save.indexOf('nxCabinetAction') < save.indexOf('sketchup.save_template_as'),
     'rozpísané úpravy sa flushnú PRED uložením šablóny');
  ok(save.indexOf('validateFields') < save.indexOf('sketchup.save_template_as'),
     'a červené polia ukladanie zastavia');
  ok(save.indexOf('nxTplSaveExpectsValue') > 0 && save.indexOf('payload.expects = exp') > 0,
     'očakávania idú do payloadu LEN keď ich modal má');

  // Zmena checkboxu ruší rozpísané uloženie (rovnako ako názov a typ).
  const bind = form.slice(form.indexOf('function bindTplModal'));
  ok(bind.indexOf('nxTplExpectBoxes') > 0 && bind.indexOf('cancelTplDeferredSave') > 0,
     'zmena očakávania zruší odložené uloženie');
}

// ---------------------------------------------------------------------------
// 7) DLAŽDICA ŠABLÓNY — text zo servera, žiadna mapa popiskov v klientovi
// ---------------------------------------------------------------------------
{
  const tpl = fs.readFileSync(path.join(JS, 'templates.js'), 'utf8');
  ok(tpl.indexOf('tp.appliance_expects') > 0, 'dlaždica kreslí kľúč payloadu');
  ok(tpl.indexOf('appliance_expects.text') > 0, 'a VETU skladá server');
  ok(tpl.indexOf("'očakáva'") < 0 && tpl.indexOf('Chladnička') < 0,
     'žiadny popisok kategórie v klientovi');

  const row = fs.readFileSync(path.join(JS, 'appliance_row.js'), 'utf8');
  ok(row.indexOf('Chladnička') < 0 && row.indexOf('Mikrovlnka') < 0,
     'ani v riadku Spotrebiča — druhá mapa by sa rozišla s katalógom');
}

// --- MUTÁCIE (čo test naozaj chytí) -----------------------------------------
// M1 „klient posiela len zmenenú kategóriu" zabije blok 4 (payload.expects).
// M2 „prvá voľba ponuky je príkaz" zabije blok 1 (neutrálna voľba).
// M3 „kontext riadku nenesie PID" zabije blok 4 (pay.pid) aj blok 5.

console.log('OK test_s1c_expects.js — ' + n + ' kontrol');
