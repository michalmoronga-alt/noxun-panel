// 1d/R-07 — KOMPATIBILITNA BRANA knižnice setov v sekcii `hw` Štúdia (klient).
//
// Preco su to testy a nie klikanie:
//   1. Knižnica z NOVŠEJ verzie sa nesmie potichu POUŽIŤ. Server jej obsah do
//      sekcie neposiela (posiela prázdno + dôvod) — bez banneru by používateľ
//      videl „Knižnica setov je prázdna." a prvá reakcia by bola založiť sety
//      NANOVO, teda presne tá strata, ktorej brána bráni.
//   2. Globálne mutácie musia byť VYPNUTÉ. Server ich odmietne tak či tak, ale
//      tlačidlo, ktoré sa dá stlačiť, sľubuje niečo, čo sa nestane.
//   3. PROJEKTOVÉ predvoľby nad zdravým snapshotom sa vypnúť NESMÚ — ich
//      zdrojom je .skp, nie knižnica, a zákazka sa musí dať dokončiť.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));

// Most do Ruby: zachytavame, co by sekcia poslala serveru.
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

// Kostra sekcie (`hw` v Studiu) — dva bloky, ktore si hw_sets.js kresli sam.
const TABSETS = mkEl('div');
TABSETS.attrs.id = 'hwTabSets';
DOC.body.appendChild(TABSETS);
const TABPROJ = mkEl('div');
TABPROJ.attrs.id = 'hwTabProj';
DOC.body.appendChild(TABPROJ);

const TYPES = [{ key: 'hinge', label: 'Záves' }, { key: 'leg', label: 'Noha' }];
const SET_A = { set_id: 'zaves-a', name: 'Záves KLASIK', generic_type: 'hinge',
                members: [{ code: 'KOD-1', per: 'unit', qty: 1 }] };

// Payload sekcie (HardwareCatalogDialog.sets_payload).
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

const RO_REASON = 'Knižnica setov kovania je z novšej verzie Noxun — aktualizuj plugin';
function readOnlyPayload(projectOver){
  // Server pri read-only posiela PRAZDNU kniznicu — vykreslit orezany obsah by
  // bolo horsie nez nevykreslit nic.
  return payload(Object.assign({
    sets: [], global_mapping: {}, type_options: { hinge: [], leg: [] },
    library_state: 'read_only', library_reason: RO_REASON
  }, projectOver || {}));
}

function txt(el){ return el.textContent; }
function btnByAction(root, action){
  return root.querySelector('[data-action="' + action + '"]');
}

// --- 1) ciste funkcie brany --------------------------------------------------
eq(HWS.hwsLibBlocked({ library_state: 'read_only' }), true, 'read_only = brána zavretá');
eq(HWS.hwsLibBlocked({ library_state: 'ok' }), false, 'ok = knižnica sa smie meniť');
eq(HWS.hwsLibBlocked(null), false, 'chýbajúci payload nič neblokuje (starší server)');
eq(HWS.hwsLibReason({ library_reason: RO_REASON }), RO_REASON, 'dôvod je hotová SK veta zo servera');
ok(HWS.hwsLibReason({}).length > 10, 'bez dôvodu ostáva zmysluplný fallback');
// Zoznam akcii je KONTRAKT: menia kniznicu, alebo z nej kopiruju do .skp.
// KOV-B3: `hws-save` z neho ZMIZLA spolu s inline editorom — set sa uklada
// tlacidlom MODALU, ktore sa bez `hws-new`/`hws-edit` neotvori (a serverova
// brana `library_write_blocked?` je aj tak posledne slovo).
eq(HWS.HWS_LIB_ACTIONS.slice().sort(),
   ['hws-del', 'hws-edit', 'hws-merge-seed', 'hws-new', 'hws-reset-proj'],
   'akcie viazané na knižnicu');

// --- 2) zdrava kniznica: sekcia vyzera ako doteraz ---------------------------
HWS.HWSETS.init(payload());
ok(txt(TABSETS).indexOf('Záves KLASIK') >= 0, 'zdravá knižnica sa vykreslí');
ok(!btnByAction(TABSETS, 'hws-new').disabled, '„+ Nový set" je dostupný');
ok(txt(TABPROJ).indexOf('Predvoľby nových projektov') >= 0, 'globálne predvoľby sú v sekcii');
ok(TABPROJ.querySelector('[data-action-change="hws-map-global"]'),
   'a dajú sa meniť selectom');

// --- 3) read-only kniznica: BANNER namiesto „prazdna" + vypnute mutacie -----
HWS.HWSETS.init(readOnlyPayload());
ok(txt(TABSETS).indexOf(RO_REASON) >= 0, 'banner hovorí DÔVOD, nie „Knižnica setov je prázdna."');
eq(txt(TABSETS).indexOf('Knižnica setov je prázdna.'), -1,
   'zavádzajúca veta o prázdnej knižnici sa NEZOBRAZÍ');
eq(btnByAction(TABSETS, 'hws-new').disabled, true, '„+ Nový set" je vypnutý');
eq(TABSETS.querySelector('[data-action="hws-edit"]'), null, 'žiadne „Upraviť"');
eq(TABSETS.querySelector('[data-action="hws-del"]'), null, 'žiadne „Zmazať"');
eq(btnByAction(TABPROJ, 'hws-merge-seed').disabled, true,
   '„Doplniť nové predvoľby" kopíruje z knižnice — vypnuté');
eq(TABPROJ.querySelector('[data-action-change="hws-map-global"]'), null,
   'globálne predvoľby sa nedajú meniť');
ok(txt(TABPROJ).indexOf(RO_REASON) >= 0, 'a dôvod je aj pri nich');

// --- 4) PROJEKTOVE predvolby nad zdravym snapshotom ZOSTAVAJU ----------------
const projSel = TABPROJ.querySelector('[data-action-change="hws-map-proj"]');
ok(projSel, 'projektový výber setu ostáva funkčný (zdroj je .skp, nie knižnica)');
SENT.length = 0;
projSel.value = 'zaves-a';
dispatch(projSel, 'change');
eq(SENT.length, 1, 'projektová zmena sa POŠLE');
eq(SENT[0][0], 'hws_map_project', 'a ide na projektový handler');

// --- 5) poistka: klik zo zastaraneho DOM-u sa neodosle ----------------------
SENT.length = 0;
const stale = mkEl('button');
stale.setAttribute('data-action', 'hws-merge-seed');
DOC.body.appendChild(stale);
dispatch(stale, 'click');
eq(SENT.length, 0, 'globálna akcia sa pri read-only knižnici NEODOŠLE ani z DOM-u bez `disabled`');

// --- 6) projekt BEZ snapshotu: povie sa PRAVDA (nemapuje sa nic) -------------
HWS.HWSETS.init(readOnlyPayload({ project: { status: 'missing', mapping: {}, sets: [] } }));
ok(txt(TABPROJ).indexOf('nenamapuje') >= 0,
   'bez snapshotu je jediným zdrojom knižnica — sekcia to prizná, nie prázdny select');
eq(TABPROJ.querySelector('[data-action-change="hws-map-proj"]'), null,
   'a neponúka výber, ktorý by sa nedal uložiť');

// --- 7) navrat do zdraveho stavu je uplny -----------------------------------
HWS.HWSETS.init(payload());
ok(txt(TABSETS).indexOf('Záves KLASIK') >= 0, 'po oprave knižnice sa sekcia vráti do normálu');
ok(!btnByAction(TABSETS, 'hws-new').disabled, 'a mutácie sú znova dostupné');

console.log(`OK — test_r07_kniznica_ui.js: ${n} testov preslo`);
