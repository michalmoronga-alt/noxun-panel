// KOV-F1 — UI riadku mapovania ZÁVESOV v Pravidlách Štúdia (hw_sets.js,
// mini-DOM). Vzniklo z fix kola po Codex GH review #329 (P2 na hw_sets.js).
//
// Čo sa stráži:
//   R1 select triedneho kľúča závesov má DVE prázdne voľby, nie jednu:
//      „nenastavené" (kľúč sa z mapovania ZMAŽE — resolver padne na legacy
//      `hinge` a závesy sa objednajú) a „vedome bez setu" (uloží sa SENTINEL
//      — nákup ostane bez závesov). Projekt bez kľúča má vybranú PRVÚ.
//   R2 sentinel ide na server ako HODNOTA zo servera (`none_send`), nie ako
//      reťazec „none" — ten je platné `set_id` a server by ho tak aj uložil.
//   R3 „nenastavené" naďalej posiela prázdny reťazec (zrušenie mapovania).
//
// MUTÁCIE (každá overená ručne — po zanesení chyby do hw_sets.js spadne test):
//   M1 `none.selected = !row.stored` (stav pred #329)
//      -> „R1: projekt BEZ kľúča má vybrané „nenastavené"…"
//   M2 `hwsMapClassValue` vracia `row.none_value`
//      -> „R2: sentinel ide na server ako HODNOTA…"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));
global.NXModal = require(path.join(JS, 'nx_modal.js')); // hw_sets.js siaha na HOLY global

const ROOT = mkEl('div'); ROOT.attrs.id = 'nxModalRoot'; DOC.body.appendChild(ROOT);
const TABSETS = mkEl('div'); TABSETS.attrs.id = 'hwTabSets'; DOC.body.appendChild(TABSETS);
const TABPROJ = mkEl('div'); TABPROJ.attrs.id = 'hwTabProj'; DOC.body.appendChild(TABPROJ);

const SENT = [];
const BRIDGE = {};
['hws_map_project', 'hws_map_global'].forEach(function(name){
  BRIDGE[name] = function(json){ SENT.push({ name: name, data: JSON.parse(json) }); };
});
global.window.sketchup = BRIDGE;
global.sketchup = BRIDGE;

const HWS = require(path.join(JS, 'hw_sets.js'));

// Riadok tak, ako ho skladá server (`class_mapping_rows`): PROJEKT ešte
// triedny kľúč závesov NEMÁ — `current` null, `stored` false.
const HINGE_ROW = {
  key: 'class:hinge|tipon', label: 'Závesy · Tip-On',
  options: [{ id: 'set:zaves-p2o', label: 'Záves P2O', set_id: 'zaves-p2o' }],
  current: null, stored: false, value_text: 'bez setu',
  none_value: 'none', none_send: { none: true },
  none_label: '— vedome bez setu (dvierka bez závesov)',
  unset_label: '— nenastavené (dedí sa z predvoľby „Závesy")'
};

HWS.HWSETS.init({
  sets: [{ set_id: 'zaves-p2o', name: 'Záves P2O', generic_type: 'hinge',
           members: [{ code: '245723', per: 'unit', qty: 1 }] }],
  global_mapping: {}, revision: 'rev1', library_state: 'ok', library_reason: '',
  type_options: { hinge: [{ set_id: 'zaves-p2o', name: 'Záves P2O' }] },
  params: [{ key: 'front_height', label: 'výška čela', by: 'podľa výšky čela' }],
  class_options: {}, preview_sample: {},
  taxonomy: { manufacturers: [], series: [], revision: 't1', read_only: false,
              write_blocked: false, state_reason: '' },
  project: { status: 'ok', mapping: {}, sets: [] },
  generic_types: [{ key: 'hinge', label: 'Závesy' }],
  class_rows: { project: [HINGE_ROW], global: [HINGE_ROW] },
  model_guid: 'G1', model_title: 'Test'
});

// --- R1: dve prázdne voľby, vybraná je „nenastavené" -------------------------
// Prvá tabuľka = mapovanie PROJEKTU (druhá je zbalená sekcia globálnych
// predvolieb, ktorá žije v tom istom paneli).
const tables = TABPROJ.querySelectorAll('.hwsmap');
ok(tables.length >= 1, 'tabuľka mapovaní projektu existuje');
const sels = tables[0].querySelectorAll('[data-hws-mapkey]');
eq(sels.length, 1, 'riadok závesov je v tabuľke mapovaní');
const sel = sels[0];
const opts = sel.querySelectorAll('option').map(function(o){
  return [o.value, o.textContent, !!o.selected, !!o.disabled];
});
eq(opts, [['', HINGE_ROW.unset_label, true, false],
          ['none', HINGE_ROW.none_label, false, false],
          ['set:zaves-p2o', 'Záves P2O', false, false]],
   'R1: projekt BEZ kľúča má vybrané „nenastavené" — „vedome bez setu" je SAMOSTATNÁ voľba');

// --- R2: sentinel ide ako hodnota zo servera --------------------------------
SENT.length = 0;
sel.value = 'none';
dispatch(sel, 'change');
eq(SENT.length, 1, 'voľba sa odošle');
eq(SENT[0].data.mapping_key, 'class:hinge|tipon', 'a nesie TRIEDNY kľúč');
eq(SENT[0].data.value, { none: true },
   'R2: sentinel ide na server ako HODNOTA zo servera, nie ako reťazec „none"');

// --- R3: „nenastavené" ostáva zrušením mapovania ----------------------------
SENT.length = 0;
sel.value = '';
dispatch(sel, 'change');
eq(SENT[0].data.value, '', 'R3: „nenastavené" zmaže kľúč (dedí sa legacy `hinge`)');

// --- uložený sentinel je vybraný, nie „uložený výber" -----------------------
const stored = JSON.parse(JSON.stringify(HINGE_ROW));
stored.current = 'none';
stored.value_text = 'vedome bez setu';
eq(HWS.hwsMapClassSelectedId(stored), 'none',
   'uložený sentinel je bežná vybraná voľba, nie hodnota mimo ponuky');
ok(HWS.hwsMapClassSelectedId(HINGE_ROW) === '', 'a bez kľúča ostáva „nenastavené"');

console.log('KOV-F1 UI: ' + n + ' assertov OK');
