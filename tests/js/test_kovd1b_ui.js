// KOV-D1b — MAPOVANIE, UI: riadky mapovania PODĽA TRIEDY v Pravidlách Štúdia
// (hw_sets.js, mini-DOM) a ponuka setu pre klasifikovanú zásuvku na karte
// skrinky/čela (hardware.js, čisté funkcie).
//
// Čo dávka sľubuje (a čo tieto testy strážia):
//   R1 riadky triednych kľúčov idú do TEJ ISTEJ tabuľky mapovaní (žiadny nový
//      blok), ponuku aj texty skladá SERVER; výber odošle `mapping_key`
//      a hodnotu (pevný set = reťazec, rodina = selektor)
//   R1b uložená voľba mimo ponuky sa ZOBRAZÍ, ale je `disabled` — vybrať sa
//      nedá a nikdy sa neodošle (F10)
//   R2 karta: prvá voľba = čo platí bez vlastného výberu, ponuka = hotový
//      zoznam zo servera; „vrátiť na projekt" pošle prázdne `set_id`
//   R3 neznáme ID sa NEODOSIELA (radšej nič než hádanie)
//
// MUTÁCIE (každá overená ručne — po zanesení chyby do zdroja spadne test):
//   M1 `hwSetPayload` posiela ID voľby namiesto `set_id`/`value`
//      -> „KOV-D1b (R2): rodina sa posiela ako selektor…"
//   M2 „(uložený výber)" nie je `disabled`
//      -> „KOV-D1b (R1b): uložená voľba mimo ponuky sa nedá vybrať"
//   M3 `hwsSendMap` nenesie `mapping_key`
//      -> „KOV-D1b (R1): výber v Pravidlách pošle TRIEDNY kľúč…"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// ===========================================================================
// A) KARTA SKRINKY / ČELA (hardware.js — čisté funkcie, bez DOM)
// ===========================================================================
const HW = require(path.join(JS, 'hardware.js'));

const WHITE = { param: 'height_variant',
                bands: [{ min: 70, max: 70, set_id: 'atira-biela-h70-sisy' },
                        { min: 144, max: 144, set_id: 'atira-biela-h144-sisy' }] };
const DARK = { param: 'height_variant',
               bands: [{ min: 70, max: 70, set_id: 'atira-antracit-h70-sisy' },
                       { min: 144, max: 144, set_id: 'atira-antracit-h144-sisy' }] };
const OPT_WHITE = { id: 'sel:white', label: 'Atira biela — klasické · podľa výšky zásuvky (H70 · H144)',
                    selector: WHITE };
const OPT_DARK = { id: 'sel:dark', label: 'Atira antracit — klasické · podľa výšky zásuvky (H70 · H144)',
                   selector: DARK };
const OPT_QUADRO = { id: 'set:vysuv-quadro-v6-sisy', label: 'Quadro V6 EB23 — klasické',
                     set_id: 'vysuv-quadro-v6-sisy' };

// Payload zo servera (Panel.hardware_set_options) — položka pre 'slide'
// s KOV-D1b rozsahmi.
const ENTRY = {
  generic_type: 'slide', label: 'Výsuv',
  project_label: 'podľa projektu — Atira biela', owner_default_label: 'podľa projektu — Atira biela',
  owner_overrides: {}, status: 'ok',
  options: [{ set_id: 'atira-biela-h70-sisy', name: 'Atira biela H70 — klasické' }],
  compat: {
    cab: { class_key: 'class:slide|classic|metal',
           class_label: 'Výsuv · Klasické · Kovové bočnice',
           scope_label: 'Set pre túto skrinku',
           none_label: 'podľa projektu — Atira biela — klasické · podľa výšky zásuvky (H70 · H144)',
           options: [OPT_DARK, OPT_WHITE, OPT_QUADRO], current: null, stored: false,
           value_text: 'bez setu' },
    owners: {
      'front:F1/panel': { class_key: 'class:slide|classic|metal',
                          class_label: 'Výsuv · Klasické · Kovové bočnice',
                          scope_label: 'Set pre toto čelo',
                          none_label: 'podľa skrinky — Atira antracit',
                          options: [OPT_DARK, OPT_WHITE], current: 'sel:white', stored: false,
                          value_text: 'Atira biela' }
    }
  }
};
const clone = o => JSON.parse(JSON.stringify(o));
const flat = list => list.map(o => [o.value, o.text, o.selected, o.disabled]);

// --- rozsah + ponuka -------------------------------------------------------
eq(HW.hwCompatScope(ENTRY, null).scope_label, 'Set pre túto skrinku', 'rozsah SKRINKY');
eq(HW.hwCompatScope(ENTRY, 'front:F1/panel').scope_label, 'Set pre toto čelo', 'rozsah ČELA');
eq(HW.hwCompatScope(ENTRY, 'front:F9/panel'), null, 'čelo bez klasifikovanej položky rozsah nemá');
eq(HW.hwCompatScope({ generic_type: 'hinge' }, null), null, 'typ bez compat = pôvodná cesta');

eq(flat(HW.hwCabOptionList(ENTRY)),
   [['', 'podľa projektu — Atira biela — klasické · podľa výšky zásuvky (H70 · H144)', true, false],
    ['sel:dark', OPT_DARK.label, false, false],
    ['sel:white', OPT_WHITE.label, false, false],
    ['set:vysuv-quadro-v6-sisy', OPT_QUADRO.label, false, false]],
   'KOV-D1b (R2): prvá voľba povie, čo platí z projektu, ponuka je zo servera');

eq(flat(HW.hwOwnerOptionList(ENTRY, 'front:F1/panel')),
   [['', 'podľa skrinky — Atira antracit', false, false],
    ['sel:dark', OPT_DARK.label, false, false],
    ['sel:white', OPT_WHITE.label, true, false]],
   'na čele je vybraný jeho vlastný výber a dedená voľba priznáva SKRINKU');

// Uložená voľba mimo ponuky (neaktívny set) — vidno ju, vybrať sa nedá.
const stored = clone(ENTRY);
stored.compat.cab.stored = true;
stored.compat.cab.value_text = 'Atira šedá — klasické · podľa výšky zásuvky (H70)';
const storedList = flat(HW.hwCabOptionList(stored));
eq(storedList[1], [HW.HW_SET_STORED, 'Atira šedá — klasické · podľa výšky zásuvky (H70) (uložený výber)',
                   true, true],
   'KOV-D1b (R1b): uložená voľba mimo ponuky sa nedá vybrať');
eq(storedList[0][2], false, 'a dedená voľba pri nej vybraná nie je');

// --- payload odoslania -----------------------------------------------------
const CAB = HW.hwCompatScope(ENTRY, null);
eq(HW.hwSetPayload(CAB, 'sel:dark', 'slide', '', 'CAB-1'),
   { generic_type: 'slide', owner_part_key: null, set_id: '', cabinet_id: 'CAB-1', value: DARK },
   'KOV-D1b (R2): rodina sa posiela ako selektor (`value`), nikdy ako ID voľby');
eq(HW.hwSetPayload(CAB, 'set:vysuv-quadro-v6-sisy', 'slide', 'front:F1/panel', 'CAB-1'),
   { generic_type: 'slide', owner_part_key: 'front:F1/panel',
     set_id: 'vysuv-quadro-v6-sisy', cabinet_id: 'CAB-1' },
   'pevný set ide ako `set_id` — bez `value`');
eq(HW.hwSetPayload(CAB, '', 'slide', 'front:F1/panel', 'CAB-1'),
   { generic_type: 'slide', owner_part_key: 'front:F1/panel', set_id: '', cabinet_id: 'CAB-1' },
   '„vrátiť na projekt" = prázdne `set_id` (existujúca cesta zrušenia)');
eq(HW.hwSetPayload(CAB, 'sel:neznamy', 'slide', '', 'CAB-1'), null,
   'KOV-D1b (R3): neznáme ID sa NEODOSIELA');
eq(HW.hwSetPayload(CAB, HW.HW_SET_STORED, 'slide', '', 'CAB-1'), null,
   '„(uložený výber)" sa neodosiela nikdy');
eq(HW.hwSetPayload(null, 'atira', 'slide', '', 'CAB-1'),
   { generic_type: 'slide', owner_part_key: null, set_id: 'atira', cabinet_id: 'CAB-1' },
   'bez compat ostáva pôvodná cesta (plochý zoznam setov) nedotknutá');

// --- zmiešaná skrinka: `compat` JE, ale `cab` je null (Codex #310 P2-3) ----
// Server to posiela zámerne — jeden kľúč by platil len na časť položiek
// a `apply_cabinet_override` taký zápis odmieta. Riadok skrinky sa preto
// nesmie vykresliť VÔBEC; pôvodný plochý zoznam setov by ponúkal samé chyby.
const MIXED = clone(ENTRY);
MIXED.compat.cab = null;
eq(HW.hwCabRowOff(MIXED), true, 'KOV-D1b (P2-3): prítomný `compat` s `cab: null` = riadok skrinky OFF');
eq(HW.hwCabRowOff(ENTRY), false, 'jedna trieda → riadok skrinky beží');
eq(HW.hwCabRowOff({ generic_type: 'hinge' }), false,
   'NEPRÍTOMNÝ `compat` (legacy) sa nesmie zameniť za `cab: null`');
eq(HW.hwCabOptionList(MIXED), null, 'a ponuka pre skrinku sa NESTAVIA');
eq(flat(HW.hwOwnerOptionList(MIXED, 'front:F1/panel')).length, 3,
   'výber na konkrétnom čele ostáva funkčný');
eq(flat(HW.hwCabOptionList({ generic_type: 'hinge', options: [], project_label: 'podľa projektu' })),
   [['', 'podľa projektu', true, false]],
   'legacy záznam bez `compat` kreslí pôvodný plochý zoznam');

ok(HW.hwCabTitle(ENTRY).indexOf('Set pre túto skrinku — Výsuv · Klasické · Kovové bočnice') === 0,
   'tooltip menuje rozsah aj triedu');
ok(HW.hwOwnerTitle(ENTRY, 'front:F1/panel').indexOf('Set pre toto čelo') === 0,
   'a na čele hovorí o čele');
ok(HW.hwCabTitle({ generic_type: 'hinge' }).indexOf('Set kovania pre celú skrinku') === 0,
   'bez compat ostáva pôvodný tooltip');

// ===========================================================================
// B) PRAVIDLÁ ŠTÚDIA — riadky mapovania podľa triedy (hw_sets.js, mini-DOM)
// ===========================================================================
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

const CLASS_ROW = {
  key: 'class:slide|classic|metal', label: 'Výsuv · Klasické · Kovové bočnice',
  options: [OPT_DARK, OPT_WHITE, OPT_QUADRO], current: 'sel:white', stored: false,
  value_text: 'Atira biela', none_label: '— bez setu (RED — zásuvka bez kitu)'
};
const CLASS_ROW_TIP = {
  key: 'class:slide|tipon|metal', label: 'Výsuv · Tip-On · Kovové bočnice',
  options: [], current: null, stored: true, value_text: 'Atira šedá Tip-On',
  none_label: '— bez setu (RED — zásuvka bez kitu)'
};

function payload(){
  return {
    sets: [{ set_id: 'zaves-klasik', name: 'Záves KLASIK', generic_type: 'hinge',
             members: [{ code: '104717', per: 'unit', qty: 1 }] }],
    global_mapping: { hinge: 'zaves-klasik' },
    revision: 'rev1', library_state: 'ok', library_reason: '',
    type_options: { hinge: [{ set_id: 'zaves-klasik', name: 'Záves KLASIK' }] },
    params: [{ key: 'front_height', label: 'výška čela', by: 'podľa výšky čela' }],
    class_options: {}, preview_sample: {},
    taxonomy: { manufacturers: [], series: [], revision: 't1', read_only: false,
                write_blocked: false, state_reason: '' },
    project: { status: 'ok', mapping: { hinge: 'zaves-klasik' }, sets: [] },
    generic_types: [{ key: 'hinge', label: 'Závesy' }],
    class_rows: { project: [CLASS_ROW, CLASS_ROW_TIP], global: [CLASS_ROW] },
    model_guid: 'G1', model_title: 'Test'
  };
}

HWS.HWSETS.init(payload());

// Riadky triedy žijú v TEJ ISTEJ tabuľke mapovaní ako generické typy.
const tables = TABPROJ.querySelectorAll('.hwsmap');
ok(tables.length >= 1, 'tabuľka mapovaní projektu existuje');
const classSels = tables[0].querySelectorAll('[data-hws-mapkey]');
eq(classSels.length, 2, 'KOV-D1b (R1): triedne riadky sú v EXISTUJÚCEJ tabuľke mapovaní');
eq(tables[0].querySelectorAll('[data-action-change="hws-map-proj"]').length, 1,
   'a generický riadok (závesy) ostáva vedľa nich');

const metal = classSels[0];
eq(metal.getAttribute('data-hws-mapkey'), 'class:slide|classic|metal', 'kľúč riadku je TRIEDNY');
const opts = metal.querySelectorAll('option').map(function(o){
  return [o.value, o.textContent, !!o.selected, !!o.disabled];
});
eq(opts, [['', '— bez setu (RED — zásuvka bez kitu)', false, false],
          ['sel:dark', OPT_DARK.label, false, false],
          ['sel:white', OPT_WHITE.label, true, false],
          ['set:vysuv-quadro-v6-sisy', OPT_QUADRO.label, false, false]],
   'ponuka aj texty sú zo servera; uložená hodnota je vybraná');

// Uložená hodnota mimo ponuky (neaktívny set) — zobrazí sa, nedá sa vybrať.
const tip = classSels[1];
const tipOpts = tip.querySelectorAll('option').map(function(o){
  return [o.value, o.textContent, !!o.selected, !!o.disabled];
});
eq(tipOpts[1], [HWS.HWS_STORED_OPT, 'Atira šedá Tip-On (uložený výber)', true, true],
   'KOV-D1b (R1b): uložená voľba mimo ponuky sa nedá vybrať');

// --- odoslanie výberu ------------------------------------------------------
SENT.length = 0;
metal.value = 'sel:dark';
dispatch(metal, 'change');
eq(SENT.length, 1, 'zmena riadku pošle práve jeden zápis');
eq(SENT[0].name, 'hws_map_project', 'projektová tabuľka píše do PROJEKTU');
eq(SENT[0].data.mapping_key, 'class:slide|classic|metal',
   'KOV-D1b (R1): výber v Pravidlách pošle TRIEDNY kľúč (mapping_key)');
eq(SENT[0].data.value, DARK, 'a hodnotou je SELEKTOR rodiny, nie ID voľby');
eq(SENT[0].data.model_guid, 'G1', 'guard dokumentu ostáva');

SENT.length = 0;
metal.value = 'set:vysuv-quadro-v6-sisy';
dispatch(metal, 'change');
eq(SENT[0].data.value, 'vysuv-quadro-v6-sisy', 'pevný set ide ako reťazec');

SENT.length = 0;
metal.value = '';
dispatch(metal, 'change');
eq(SENT[0].data.value, '', 'prázdna voľba = zrušenie mapovania');

SENT.length = 0;
metal.value = 'sel:neexistuje';
dispatch(metal, 'change');
eq(SENT.length, 0, 'KOV-D1b (R3): neznáme ID sa NEODOSIELA');

// --- čisté funkcie výberu --------------------------------------------------
eq(HWS.hwsScopeOf('hws-map-global'), 'global', 'globálna tabuľka číta globálne riadky');
eq(HWS.hwsScopeOf('hws-map-proj'), 'project');
eq(HWS.hwsMapClassPick(CLASS_ROW, 'sel:white'), OPT_WHITE, 'voľba sa hľadá podľa ID');
eq(HWS.hwsMapClassValue(CLASS_ROW, 'sel:white'), WHITE, 'a hodnotou je jej selektor');
eq(HWS.hwsMapClassValue(CLASS_ROW, ''), '', 'prázdne ID = zrušenie');
eq(HWS.hwsMapClassValue(CLASS_ROW, 'nic'), null, 'neznáme ID nemá hodnotu');
eq(HWS.hwsMapClassRows('global').length, 1, 'globálne riadky sú vlastný zoznam');

// ===========================================================================
// C) ĽAHKÝ PUSH obnovuje aj detail zásuvky (Codex #310 P2-5)
// ===========================================================================
// `NX.setHardwareSets` (zmena mapovania alebo katalógu v Štúdiu) mení názov
// setu a kódy — teda presne obsah rozkliku „Technický detail". Kontrakt sa
// overuje na zdrojoch: server ho do payloadu priloží, bridge ho posunie
// ďalej a `refreshFrontDrawer` prekreslí LEN otvorenú kartu.
const fs = require('node:fs');
// Zdroje sa citaju s normalizovanymi koncami riadkov: na Windows checkoute
// (core.autocrlf=true) su subory CRLF a regexy nizsie kotvia na `
` —
// bez normalizacie sada padne lokalne, hoci v CI (LF) prejde.
const readSrc = (name) => fs.readFileSync(path.join(JS, name), 'utf8').replace(/
/g, '
');
const bridgeSrc = readSrc('bridge.js');
const formSrc = readSrc('form.js');
const hwSrc = readSrc('hardware.js');

const setHw = bridgeSrc.match(/setHardwareSets: function\(data\)\{[\s\S]*?\n    \},/)[0];
ok(/refreshFrontDrawer\(d\.front_drawer\)/.test(setHw),
   'KOV-D1b (P2-5): ľahký push obnoví aj detail zásuvky');
ok(/d\.front_drawer && typeof d\.front_drawer === 'object'/.test(setHw),
   'starý payload bez kľúča sa nedotkne ničoho (a `{}` je legitímna hodnota)');
ok(setHw.indexOf('refreshHardwareSets') < setHw.indexOf('refreshFrontDrawer'),
   'poradie ostáva: ponuky a nákup najprv, detail za nimi');

const refreshFd = formSrc.match(/function refreshFrontDrawer\(map\)\{[\s\S]*?\n  \}/)[0];
ok(/frontDrawer = map \|\| \{\}/.test(refreshFd), 'záznam sa vymení celý (server je autorita)');
ok(/if \(openFrontCardId\) refreshFrontCards\(\)/.test(refreshFd),
   'prekresľuje sa LEN otvorená karta — riadky čiel sa neprestavujú');

const refreshSets = hwSrc.match(/function refreshHardwareSets\(options\)\{[\s\S]*?\n  \}\n/)[0];
ok(/if \(!list\)\{ hwDropSetRow\(sel\); continue; \}/.test(refreshSets),
   'KOV-D1b (P2-3): živý push odstráni nepoužiteľný riadok skrinky, nedopĺňa doň plochý zoznam');

console.log('KOV-D1b UI: ' + n + ' assertov OK');
