// KOV-D4 — UI DROBNOSTI: prisvietenie cieloveho riadku po ceruzke Kontroly,
// smerovanie na KONKRETNY osiroteny zaznam v Kovani a ludsky nazov cela
// v tabulke „Bez kódov" sekcie Nakup.
//
// Preco su to testy a nie klikanie v paneli:
//   1. SERVER JE AUTORITA ADRESY. Klient nesmie z `part_key` odvodzovat, ci je
//      cielom ziva polozka alebo osiroteny zasah — prisvietil by cudzi riadok
//      (a pri zamkoch by pouzivatel odomykal nieco ine, nez vidi).
//   2. ZASTARANY PAYLOAD MUSI MLCAT. Ked riadok medzitym zanikol (prestavba,
//      iny vyber), deep-link NEROBI NIC. Falosne prisvietenie klame.
//   3. NAJVIAC JEDNO PRISVIETENIE. Dva skoky za sebou nesmu nechat svietit dva
//      riadky — z obrazovky sa to vsimne az po case, z testu okamzite.
//   4. „BEZ KÓDOV" NESMIE MENIT IDENTITU. Ludsky popis je LEN zobrazenie:
//      pocet riadkov, ich poradie, dedup zasuviek aj `blocks_export` ostavaju
//      presne take, ake boli.
//
// MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
//   M1 `hwRowKindOk` neoveruje triedu riadku (vzdy true)
//      -> „KOV-D4 (R1): ani naopak (osiroteny zaznam pod `orphan: false`)"
//   M2 `hwFlash` nesnima predchadzajuce prisvietenie
//      -> „KOV-D4 (R1): svieti NAJVIAC JEDEN riadok"
//   M3 `hwMissWhere` sklada popis z `owner_part_key`, ked `owner_label` chyba
//      na SERVERI, ale zaroven ho pouzije aj ked ho server poslal
//      -> „KOV-D4 (R2): stlpec „kde" ukazuje LUDSKY nazov, surovy kluc ostava
//         v `title`"
//   M4 `hwMissWhere` zmeni identitu riadku (dedup zasuviek podla popisu)
//      -> „KOV-D4 (R2): identita a dedup sa popisom NEMENIA"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function no(c, msg){ n++; assert.ok(!c, msg); }
function eq(a, b, msg){
  n++;
  assert.deepStrictEqual(a, b, `${msg}: cakam ${JSON.stringify(b)}, dostal ${JSON.stringify(a)}`);
}

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));

global.el = function(id){ return DOC.getElementById(id); };
global.esc = function(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
global.NXIcons = { svg: function(name){ return '<svg class="ic"><use href="#i-' + name + '"/></svg>'; } };
const STATUS = [];
global.NX = { setStatus: function(msg, err){ STATUS.push({ msg: msg, err: !!err }); } };
// Kontext panela: `nxFocusHardware` ho ma PREPNUT na Kovanie.
const CTX = [];
global.setViewContext = function(c){ CTX.push(c); };
const REVEALED = [];
global.nxRevealTarget = function(node){ REVEALED.push(node); return node; };

const HW = require(path.join(JS, 'hardware.js'));

// ===========================================================================
// 1) R1 — SELEKTOR CIELOVEHO RIADKU (cista funkcia)
// ===========================================================================

const LIVE = { owner_part_key: 'front:F1/panel', generic_type: 'slide',
               rule_id: 'recipe:atira_sisy_v1', orphan: false };
const ORPH = { owner_part_key: 'front:F2/panel', generic_type: 'slide',
               rule_id: 'recipe:atira_sisy_v1', orphan: true };

eq(HW.hwRowSelector(LIVE),
   '.hwrow[data-owner="front:F1/panel"][data-type="slide"][data-rule="recipe:atira_sisy_v1"]',
   'ziva polozka sa adresuje TROJICOU identity (vlastnik + typ + pravidlo)');
eq(HW.hwRowSelector(ORPH),
   '.hwrow.hwoff[data-owner="front:F2/panel"][data-type="slide"][data-rule="recipe:atira_sisy_v1"]',
   'osiroteny zaznam ma vlastnu triedu — `orphan` hovori SERVER');
eq(HW.hwRowSelector({ owner_part_key: '', generic_type: 'leg', rule_id: 'nohy-standard' }),
   '.hwrow[data-owner=""][data-type="leg"][data-rule="nohy-standard"]',
   'kovanie CELEJ skrinky ma prazdneho vlastnika (a to je platna adresa)');
eq(HW.hwRowSelector(null), '', 'bez adresy sa nehlada nic');
eq(HW.hwRowSelector({ owner_part_key: 'x' }), '', 'neuplna adresa (bez typu a pravidla) = nic');
eq(HW.hwRowSelector({ generic_type: 'slide' }), '', 'ani samotny typ nestaci');

// ===========================================================================
// 2) R1 — DEEP-LINK NAD SKUTOCNYM DOM (mini-DOM)
// ===========================================================================

const BOX = mkEl('div');
BOX.attrs.id = 'hwRows';
DOC.body.appendChild(BOX);

// Presne ten markup, ktory kresli `hwItemHtml` / `hwOffHtml`: ziva polozka je
// `.hwrow` v obale `.hwitem`, osiroteny zasah je `.hwrow.hwoff`.
BOX.innerHTML =
  '<div class="hwbox" data-group="front:F1">'
  + '<div class="hwitem">'
  + '<div class="hwrow" data-owner="front:F1/panel" data-type="slide" data-rule="recipe:atira_sisy_v1" data-cab="CAB-1"></div>'
  + '<div class="hwbuy"></div>'
  + '</div></div>'
  + '<div class="hwbox" data-group="front:F2">'
  + '<div class="hwrow hwoff" data-owner="front:F2/panel" data-type="slide" data-rule="recipe:atira_sisy_v1" data-cab="CAB-1"></div>'
  + '</div>'
  + '<div class="hwbox" data-group="cab">'
  + '<div class="hwrow hwoff" data-owner="" data-type="leg" data-rule="nohy-standard" data-cab="CAB-1"></div>'
  + '</div>';

function rowOf(sel){ return BOX.querySelector(sel); }
const liveRow = rowOf('.hwrow[data-owner="front:F1/panel"]');
const liveItem = BOX.querySelector('.hwitem');
const orphRow = rowOf('.hwrow[data-owner="front:F2/panel"]');
const cabRow = rowOf('.hwrow[data-type="leg"]');

ok(HW.hwFlashTargetOf(liveRow) === liveItem,
   'prisvieti sa CELA polozka — chipy osi aj nakupny riadok patria k nej');
ok(HW.hwFlashTargetOf(orphRow) === orphRow,
   'osiroteny zasah obal `.hwitem` mat nemusi — vtedy svieti riadok');
eq(HW.hwFlashTargetOf(null), null, 'bez uzla sa nesvieti nic');

ok(HW.nxFocusHardware(LIVE), 'deep-link na ZIVU polozku uspeje');
eq(CTX[CTX.length - 1], 'kovanie', 'panel sa prepne do sekcie Kovanie');
ok(REVEALED[REVEALED.length - 1] === liveItem, 'cesta k cielu sa rozbali');
ok(liveItem.classList.contains('hwfocus'), 'a ciel sa prisvieti');

// M1: `orphan` nie je kozmetika — je to sucast adresy.
HW.hwFlashClear();
no(HW.nxFocusHardware(Object.assign({}, LIVE, { orphan: true })),
   'KOV-D4 (R1): osiroteny zaznam a ziva polozka sa NEZAMIENAJU (ziva polozka pod `orphan: true`)');
no(HW.nxFocusHardware(Object.assign({}, ORPH, { orphan: false })),
   'KOV-D4 (R1): ani naopak (osiroteny zaznam pod `orphan: false`)');
no(liveItem.classList.contains('hwfocus'), 'a nic sa neprisvieti');
no(orphRow.classList.contains('hwfocus'), 'ani na druhej strane');

ok(HW.nxFocusHardware(ORPH), 'deep-link na OSIROTENY zaznam uspeje');
ok(orphRow.classList.contains('hwfocus'), 'svieti riadok osiroteneho zasahu');

ok(HW.nxFocusHardware({ owner_part_key: '', generic_type: 'leg',
                        rule_id: 'nohy-standard', orphan: true }),
   'kovanie celej skrinky (prazdny vlastnik) sa najde tiez');
ok(cabRow.classList.contains('hwfocus'), 'a prisvieti sa');

// M2: dva skoky za sebou = JEDEN svietiaci riadok.
no(orphRow.classList.contains('hwfocus'),
   'KOV-D4 (R1): svieti NAJVIAC JEDEN riadok — predchadzajuci sa snal HNED');

// Zastarany payload: riadok, ktory v paneli nie je.
HW.hwFlashClear();
const ctxBefore = CTX.length;
no(HW.nxFocusHardware({ owner_part_key: 'front:F9/panel', generic_type: 'slide',
                        rule_id: 'recipe:atira_sisy_v1', orphan: false }),
   'riadok, ktory v paneli nie je, deep-link NEOTVORI');
eq(CTX.length, ctxBefore, 'a kontext sa ani neprepne (nic by tam nesvietilo)');
no(HW.nxFocusHardware(null), 'chybajuca adresa nespadne');
no(HW.nxFocusHardware({}), 'ani prazdna');

// Casovac: prisvietenie sa sníma samo.
HW.hwFlash(liveItem);
ok(liveItem.classList.contains('hwfocus'), 'prisvietene');
ok(HW.HW_FLASH_MS > 0, 'trvanie je konstanta (nie magicke cislo v tele funkcie)');
HW.hwFlashClear();
no(liveItem.classList.contains('hwfocus'), 'po snati je trieda prec');

// ===========================================================================
// 3) R2 — „BEZ KÓDOV": LUDSKY NAZOV CELA MIESTO SUROVEHO KLUCA
// ===========================================================================

global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const S = require(path.join(JS, 'studio.js'));

const U_LABEL = { generic_type: 'slide', cabinet_id: 'CAB-2',
                  owner_part_key: 'front:Fmsi0wnix-1-3a3kxe/panel',
                  owner_label: 'F1 · zásuvkové čelo', quantity: 1,
                  reason: 'drawer_kit_missing', reason_sk: 'set „atira" nemá kód pre dĺžku NL 470',
                  blocks_export: true };
const U_RAW = { generic_type: 'slide', cabinet_id: 'CAB-3',
                owner_part_key: 'front:F5/panel', quantity: 2,
                reason: 'nl_missing', reason_sk: 'set „x" nemá kód pre dĺžku NL 470' };
const U_CAB = { generic_type: 'leg', cabinet_id: 'CAB-4', quantity: 4,
                reason: 'set_missing', reason_sk: 'set chýba' };

// M3
eq(S.hwMissWhere(U_LABEL), 'CAB-2 · F1 · zásuvkové čelo',
   'KOV-D4 (R2): stlpec „kde" ukazuje LUDSKY nazov, surovy kluc ostava v `title`');
ok(S.hwMissWhereTitle(U_LABEL).indexOf('front:Fmsi0wnix-1-3a3kxe/panel') >= 0,
   'surovy kluc sa NESTRACA — je v tooltipe (identita riadku)');
ok(S.hwMissWhereTitle(U_LABEL).indexOf('F1 · zásuvkové čelo') >= 0,
   'tooltip nesie oboje (popis aj kluc)');
eq(S.hwMissWhere(U_RAW), 'CAB-3 · front:F5/panel',
   'stary payload BEZ `owner_label` sa sprava presne ako doteraz (ziadne hadanie)');
eq(S.hwMissWhereTitle(U_RAW), 'CAB-3 · front:F5/panel', 'a tooltip je ten isty text');
eq(S.hwMissWhere(U_CAB), 'CAB-4', 'kovanie CELEJ skrinky nema vlastnika — len skrinku');
eq(S.hwMissWhereTitle(U_CAB), 'CAB-4', 'a tooltip tiez');
eq(S.hwMissWhere(null), '', 'poskodeny zaznam nespadne');

// Markup tabulky: pocet riadkov, poradie a cervena/jantarova zavaznost sa nemenia.
const HS = { state_status: 'ok', rows: [], unmapped: [U_LABEL, U_RAW, U_CAB], summary: {} };
const H = S.buySection(HS, []);
eq((H.match(/<tr class="hwmiss/g) || []).length, 3,
   'charakterizacia: tri nemapovane zaznamy = tri riadky (pocet sa popisom nemeni)');
ok(H.indexOf('class="hwmiss hwstop"') >= 0,
   '`blocks_export` nadalej robi riadok CERVENYM');
ok(H.indexOf('CAB-2 · F1 · zásuvkové čelo') >= 0, 'v tabulke je LUDSKY nazov');
ok(H.indexOf('>CAB-2 · front:Fmsi0wnix-1-3a3kxe/panel<') < 0,
   'a surovy kluc uz nie je HLAVNYM textom bunky');
ok(H.indexOf('title="CAB-2 · F1 · zásuvkové čelo · front:Fmsi0wnix-1-3a3kxe/panel"') >= 0,
   'kluc je v `title` bunky');
ok(H.indexOf('Bez kódov (3)') >= 0, 'aj pocet v nadpise sekcie ostava');

// M4: identita a dedup zasuviek su POLIA SERVERA, nie zobrazeny text.
const U_LABEL2 = Object.assign({}, U_LABEL, { member_index: 1,
                                              owner_label: 'F1 · zásuvkové čelo' });
eq(S.hwStopOwners([U_LABEL, U_LABEL2]), ['CAB-2|front:Fmsi0wnix-1-3a3kxe/panel'],
   'KOV-D4 (R2): identita a dedup sa popisom NEMENIA (kluc = skrinka + owner_part_key)');
eq(S.hwStopCount([U_LABEL, U_LABEL2]), 1, 'dva chybajuce kody JEDNEJ zasuvky = jedna zasuvka');
const U_NOLBL = Object.assign({}, U_LABEL);
delete U_NOLBL.owner_label;
eq(S.hwStopOwners([U_NOLBL]), S.hwStopOwners([U_LABEL]),
   'zaznam s popisom aj bez neho ma TU ISTU identitu');
eq(S.hwRowStops(U_LABEL), true, '`blocks_export` sa popisom nedotkol');

console.log(`test_kovd4_ui: ${n} assertov OK`);
