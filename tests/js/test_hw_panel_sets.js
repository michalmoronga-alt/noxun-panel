// Testy V0.6 H1b: ponuka setov kovania v PANELI (hardware.js) — dependency-free
// Node. LEN ciste funkcie bez DOM: zoznam volieb selectu setu na skrinke aj na
// dielci (D-81), dedena prva volba, set mimo ponuky, vyber podla parametra.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwSetOptionList, hwOwnerOptionList, hwCabOptionList, hwFindEntry,
        hwOwnerDesc, HW_SET_PARAM } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hardware.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
// Skratka na citatelne porovnanie: [hodnota, text, vybrane?, zakazane?]
function flat(list){
  return list.map(o => [o.value, o.text, o.selected, o.disabled]);
}

// Payload zo servera (Panel.hardware_set_options) — jedna polozka pre 'slide'.
const ENTRY = {
  generic_type: 'slide',
  label: 'Výsuv',
  project_set_id: 'atira',
  project_set_name: 'Atira biela H70',
  project_label: 'podľa projektu — Atira biela H70',
  override_set_id: null,
  override_selector: null,
  override_label: null,
  owner_overrides: {},
  owner_default_label: 'podľa projektu — Atira biela H70',
  status: 'ok',
  options: [{ set_id: 'atira', name: 'Atira biela H70' },
            { set_id: 'bocnica-h70', name: 'Bočnica H70' }]
};
const clone = o => JSON.parse(JSON.stringify(o));

// --- hwFindEntry ---------------------------------------------------------------
eq(hwFindEntry([ENTRY], 'slide').generic_type, 'slide', 'polozka podla typu');
eq(hwFindEntry([ENTRY], 'hinge'), null, 'typ bez ponuky');
eq(hwFindEntry(null, 'slide'), null, 'null vstup bezpecny');

// --- riadok SKRINKY (override projektovej predvolby) ----------------------------
eq(flat(hwCabOptionList(ENTRY)),
   [['', 'podľa projektu — Atira biela H70', true, false],
    ['atira', 'Atira biela H70', false, false],
    ['bocnica-h70', 'Bočnica H70', false, false]],
   'bez overridu je vybrana DEDENA volba a jej text je zo servera');

const cabOv = clone(ENTRY);
cabOv.override_set_id = 'bocnica-h70';
eq(flat(hwCabOptionList(cabOv))[2], ['bocnica-h70', 'Bočnica H70', true, false],
   'override skrinky je vybrany');
eq(flat(hwCabOptionList(cabOv))[0][2], false, 'dedena volba pri override nie je vybrana');

// Projekt riadi vyber podla parametra -> prva volba to POVIE (text zo servera).
const cabSelector = clone(ENTRY);
cabSelector.project_set_id = null;
cabSelector.project_set_name = null;
cabSelector.project_label = 'podľa projektu — podľa výšky čela';
cabSelector.owner_default_label = 'podľa projektu — podľa výšky čela';
eq(flat(cabSelector && hwCabOptionList(cabSelector))[0],
   ['', 'podľa projektu — podľa výšky čela', true, false],
   'selector predvolby projektu je v prvej volbe citatelne');

// Vlastny vyber SKRINKY podla parametra — panel ho needituje, len ZOBRAZI
// (disabled volba), aby sa nedal omylom prepisat na prazdno.
const cabOwnSelector = clone(ENTRY);
cabOwnSelector.override_selector = { param: 'front_height', bands: [] };
cabOwnSelector.override_label = 'podľa výšky čela';
eq(flat(hwCabOptionList(cabOwnSelector)),
   [['', 'podľa projektu — Atira biela H70', false, false],
    [HW_SET_PARAM, 'podľa výšky čela', true, true],
    ['atira', 'Atira biela H70', false, false],
    ['bocnica-h70', 'Bočnica H70', false, false]],
   'vyber podla parametra = vybrana ZAKAZANA volba, ostatne ostavaju dostupne');

// --- riadok DIELCA (D-81 owner-level override) ----------------------------------
eq(flat(hwOwnerOptionList(ENTRY, 'front:F1/panel'))[0],
   ['', '(podľa skrinky/projektu)', true, false],
   'bez vlastneho vyberu dedi dielec skrinku/projekt');

const ownerOv = clone(ENTRY);
ownerOv.owner_overrides = { 'front:F1/panel': { set_id: 'bocnica-h70' } };
eq(flat(hwOwnerOptionList(ownerOv, 'front:F1/panel'))[2],
   ['bocnica-h70', 'Bočnica H70', true, false], 'vyber na dielci je vybrany');
eq(flat(hwOwnerOptionList(ownerOv, 'front:F2/panel'))[0][2], true,
   'INY dielec ostava dedeny (override je per vlastnik)');

const ownerSelector = clone(ENTRY);
ownerSelector.owner_overrides = { 'front:F1/panel': { selector: true, label: 'podľa výšky čela' } };
eq(flat(hwOwnerOptionList(ownerSelector, 'front:F1/panel'))[1],
   [HW_SET_PARAM, 'podľa výšky čela', true, true],
   'vyber podla parametra na dielci sa ZOBRAZI, needituje');

// --- set, ktory uz v ponuke nie je (zmazany z kniznice) -------------------------
const gone = clone(ENTRY);
gone.owner_overrides = { 'front:F1/panel': { set_id: 'stary-set' } };
const goneList = flat(hwOwnerOptionList(gone, 'front:F1/panel'));
eq(goneList[goneList.length - 1], ['stary-set', 'stary-set (chýba)', true, false],
   'zapisany set mimo ponuky ostava viditelny — select nesmie klamat');
eq(goneList[0][2], false, 'a dedena volba pri nom nie je vybrana');

// --- hwSetOptionList priamo (bez payloadu) --------------------------------------
eq(flat(hwSetOptionList(null, '', 'dedi', null)), [['', 'dedi', true, false]],
   'prazdna ponuka = len dedena volba');

// --- hwOwnerDesc (popis vlastnika v riadku) -------------------------------------
eq(hwOwnerDesc('front:F1/panel'), 'F1 · zásuvka', 'zasuvka');
eq(hwOwnerDesc('front:F2/wing:left'), 'F2 · ľavé krídlo', 'krídlo');
eq(hwOwnerDesc(null), '', 'bez vlastnika');

console.log(`OK — test_hw_panel_sets.js: ${n} testov preslo`);
