// 1d/R-11 — DEGRADOVANÁ knižnica setov v sekcii `hw` Štúdia (klient).
//
// Degradovaná = poškodený primárny súbor + PLATNÁ záloha. Je to iný stav než
// R-07 „read_only":
//   1. Obsah zálohy je POUŽITEĽNÝ — sety sa musia ZOBRAZIŤ a musia sa dať
//      použiť v projekte (zmrazenie do .skp, projektové predvoľby). Zákazka sa
//      musí dať dokončiť.
//   2. Zápisy do GLOBÁLNEHO SÚBORU sa musia vypnúť — inak by prvý zápis
//      prepísal primár obsahom odvodeným od STARŠEJ zálohy a všetko medzi
//      zálohou a poškodením by zmizlo.
//   3. Používateľ musí vidieť DÔVOD (banner), inak si nevšimne, že knižnica
//      je len na čítanie, a bude sa čudovať, prečo sa nič neuloží.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));

const SENT = [];
global.sketchup = new Proxy({}, {
  get: function(_t, name){
    return function(json){ SENT.push([String(name), JSON.parse(json)]); };
  },
  has: function(){ return true; }
});
global.window.sketchup = global.sketchup;

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const HWS = require(path.join(JS, 'hw_sets.js'));

const TABSETS = mkEl('div');
TABSETS.attrs.id = 'hwTabSets';
DOC.body.appendChild(TABSETS);
const TABPROJ = mkEl('div');
TABPROJ.attrs.id = 'hwTabProj';
DOC.body.appendChild(TABPROJ);

const TYPES = [{ key: 'hinge', label: 'Záves' }, { key: 'leg', label: 'Noha' }];
const SET_A = { set_id: 'zaves-a', name: 'Záves KLASIK', generic_type: 'hinge',
                members: [{ code: 'KOD-1', per: 'unit', qty: 1 }] };

const DEG_REASON = 'Knižnica setov kovania je poškodená — číta sa záloha, globálne zápisy sú vypnuté ' +
                   '(oprav alebo zmaž súbor C:\\...\\hardware_sets.json)';

// Server pri degraded posiela PLNÝ obsah (zo zálohy) + stav a dôvod.
function payload(over){
  return Object.assign({
    sets: [SET_A],
    global_mapping: { hinge: 'zaves-a' },
    revision: 'rev-A',
    library_state: 'ok',
    library_reason: '',
    type_options: { hinge: [{ set_id: 'zaves-a', name: 'Záves KLASIK' }], leg: [] },
    params: [{ key: 'height', label: 'výška sokla', by: 'podľa výšky sokla' }],
    project: { status: 'ok', mapping: { hinge: 'zaves-a' }, sets: [SET_A] },
    generic_types: TYPES,
    model_guid: 'GUID-1',
    model_title: 'Zákazka'
  }, over || {});
}
function degradedPayload(over){
  return payload(Object.assign({ library_state: 'degraded', library_reason: DEG_REASON }, over || {}));
}

function txt(el){ return el.textContent; }
function btnByAction(root, action){
  return root.querySelector('[data-action="' + action + '"]');
}

// --- 1) ciste funkcie: dve OSI, nie jeden priznak ----------------------------
eq(HWS.hwsLibDegraded({ library_state: 'degraded' }), true, 'degraded sa rozpozná');
eq(HWS.hwsLibDegraded({ library_state: 'read_only' }), false, 'read_only nie je degraded');
eq(HWS.hwsLibBlocked({ library_state: 'degraded' }), false,
   'degraded knižnicu POUŽIŤ SMIEM — obsah zálohy je platný');
eq(HWS.hwsLibWriteBlocked({ library_state: 'degraded' }), true, 'ale zapisovať do súboru nie');
eq(HWS.hwsLibWriteBlocked({ library_state: 'read_only' }), true, 'read_only zápis tiež nepustí');
eq(HWS.hwsLibWriteBlocked({ library_state: 'ok' }), false, 'zdravá knižnica sa mení normálne');
eq(HWS.hwsLibWriteBlocked(null), false, 'chýbajúci payload nič neblokuje (starší server)');
// Kontrakt: zápisové akcie sú PODMNOŽINOU akcií viazaných na knižnicu —
// `hws-merge-seed` a `hws-reset-proj` medzi ne NEPATRIA (zapisujú do MODELU).
// KOV-B3: `hws-save` zanikla s inline editorom (set sa ukladá tlačidlom modalu).
eq(HWS.HWS_WRITE_ACTIONS.slice().sort(), ['hws-del', 'hws-edit', 'hws-new'],
   'zápis do globálneho súboru = nový/upraviť/zmazať set');
ok(HWS.HWS_WRITE_ACTIONS.every(function(a){ return HWS.HWS_LIB_ACTIONS.indexOf(a) !== -1; }),
   'a všetky sú aj v širšom zozname R-07');

// --- 2) degradovana kniznica: sety VIDNO, menit sa nedaju -------------------
HWS.HWSETS.init(degradedPayload());
ok(txt(TABSETS).indexOf('Záves KLASIK') >= 0,
   'sety sa ZOBRAZIA — obsah zálohy je platný (na rozdiel od read_only)');
ok(txt(TABSETS).indexOf('poškodená') >= 0, 'a banner povie dôvod');
eq(btnByAction(TABSETS, 'hws-new').disabled, true, '„+ Nový set" je vypnutý');
ok(btnByAction(TABSETS, 'hws-edit'), '„Upraviť" na karte ostáva (set je vidieť)');
eq(btnByAction(TABSETS, 'hws-edit').disabled, true, 'ale je vypnuté');
eq(btnByAction(TABSETS, 'hws-del').disabled, true, 'a „Zmazať" tiež');

// --- 3) projektova vrstva bezi DALEJ ----------------------------------------
ok(!btnByAction(TABPROJ, 'hws-merge-seed').disabled,
   '„Doplniť nové predvoľby" kopíruje do MODELU — pri degraded ostáva dostupné');
const projSel = TABPROJ.querySelector('[data-action-change="hws-map-proj"]');
ok(projSel, 'projektový výber setu sa vykreslí');
SENT.length = 0;
projSel.value = 'zaves-a';
dispatch(projSel, 'change');
eq(SENT.length, 1, 'projektová zmena sa POŠLE (zapisuje sa do .skp, nie do súboru)');
eq(SENT[0][0], 'hws_map_project', 'a ide na projektový handler');

// --- 4) GLOBALNE predvolby su vypnute ---------------------------------------
eq(TABPROJ.querySelector('[data-action-change="hws-map-global"]'), null,
   'globálna predvoľba je zápis do knižnice — select sa nevykreslí');
ok(txt(TABPROJ).indexOf('Globálne predvoľby sa zatiaľ nedajú meniť') >= 0, 'a dôvod je pri nich');

// --- 5) poistky pre zastaraly DOM -------------------------------------------
SENT.length = 0;
const staleSave = mkEl('button');
staleSave.setAttribute('data-action', 'hws-save');
DOC.body.appendChild(staleSave);
dispatch(staleSave, 'click');
eq(SENT.length, 0, 'zápis do knižnice sa neodošle ani z DOM-u bez `disabled`');

SENT.length = 0;
const staleMerge = mkEl('button');
staleMerge.setAttribute('data-action', 'hws-merge-seed');
DOC.body.appendChild(staleMerge);
dispatch(staleMerge, 'click');
eq(SENT.length, 1, 'ale doplnenie predvolieb do projektu sa poslať SMIE');
eq(SENT[0][0], 'hws_merge_seed', 'a ide na svoj handler');

// --- 6) navrat do zdraveho stavu je uplny -----------------------------------
HWS.HWSETS.init(payload());
ok(!btnByAction(TABSETS, 'hws-new').disabled, 'po oprave súboru sa mutácie vrátia');
ok(!btnByAction(TABSETS, 'hws-edit').disabled, 'aj „Upraviť"');
ok(TABPROJ.querySelector('[data-action-change="hws-map-global"]'),
   'a globálne predvoľby sa dajú znova meniť');

console.log(`OK — test_r11_degradovana_ui.js: ${n} testov preslo`);
