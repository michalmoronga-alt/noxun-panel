// KOV-E2 — KARTA ČELA VÝKLOPU (core.js view-model + form.js DOM).
//
// Karta výklopu je zámerne ÚSPORNÁ: jeden riadok systému (HK top | HL top),
// jeden read-only riadok vyriešeného výklopu s rozklikom a inforow LEN pri
// RED/ORANGE. Riziká sú dve a obe tiché:
//   * klient si zloží VLASTNÚ vetu o chybe a rozíde sa s Kontrolou v Štúdiu
//     (dve vety o jednom probléme = používateľ nevie, ktorá platí);
//   * zápis systému sa cestou riadok -> karta -> `collectFronts` stratí a HL
//     top ticho spadne na HK — teda iný mechanizmus, iné ramená, iná tyč.
//
// ČO SA OVERUJE:
//   K1 view-model: segment systému má LEN výklop (sklop nie), aktívna hodnota
//      ide z `item.lift.system` a klient si ju NEDOPĹŇA
//   K2 riadky zo servera (`front_lift[fid]`): `ok` = resolved + detail,
//      `conflict`/`stale` = ČERVENÝ inforow s vetou SERVERA, ORANGE je riadok
//      NAVIAC; `pending` = karta mlčí a hovorí za ňu veta o automate
//      K2b: `incomplete` (set nevydá celú zostavu) = ČERVENÝ riadok NAD
//      zhrnutím, ktoré aj s rozklikom OSTÁVA
//   K3 VERTIKÁLNY PRIESTOR: vyriešený výklop nepridá druhú vetu o automate
//   K4 zápis: klik na chip zapíše `lift.system` a `collectFronts` ho pošle;
//      prepnutie typu hodnotu NEZAHODÍ (dormant)
//   K5 HTML karty: `.drow` + `<details>` detail + inforow s ikonou
//   K6 GOLDEN: čelo BEZ výklopu sa nemení ani o riadok
//
// MUTÁCIE, ktoré sada chytá:
//   M1 segment systému sa objaví aj pri sklope        -> K1
//   M2 klient si `hk_top` domyslí pri renderi         -> K1
//   M3 karta si zloží vlastnú vetu konfliktu          -> K2
//   M4 ORANGE nahradí riadok výklopu                  -> K2
//   M5 veta o automate ostane aj nad vyriešeným       -> K3
//   M6 klik na chip zapíše `lift_system` naplocho     -> K4
//   M7 detail sa nevykreslí ako rozklik               -> K5
//   M8 karta dvierok dostane riadok výklopu           -> K6
//   M9 stav `incomplete` sa nekreslí, alebo je len jantárový (Codex #334
//      kolo 2 P2 — neúplná zostava by vyzerala ako drobnosť)  -> K2b
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const md = require(path.join(__dirname, 'minidom.js'));
const { mkEl, DOC } = md;
const C = require(path.join(JS, 'core.js'));

function rowKeys(m){
  return m.rows.filter(r => r.kind === 'seg').map(r => r.key);
}
function kinds(m){ return m.rows.map(r => r.kind); }
function infoTexts(m){
  return m.rows.filter(r => r.kind === 'info').map(r => r.text);
}
const ENTRY = { wings_n: 1, slots: [] };

// ============ K1: segment systému ===========================================
const bezSystemu = C.frontCardModel({ type: 'lift' }, ENTRY);
eq(rowKeys(bezSystemu), ['lift_system', 'opening_mode'], 'K1: výklop má systém aj otváranie');
const sysRow = bezSystemu.rows.find(r => r.key === 'lift_system');
eq(sysRow.label, 'Systém', 'K1: riadok je pomenovaný rečou stolára');
eq(sysRow.options.map(o => o.value), ['hk_top', 'hl_top'], 'K1: dve voľby, teda segment');
eq(sysRow.options.map(o => o.label), ['HK top', 'HL top'], 'K1: názvy sú Blum');
ok(sysRow.options.every(o => o.title && o.title.length > 5),
   'K1: každá voľba povie tooltipom, čo to je');
eq(sysRow.active, null,
   'K1: bez uloženej hodnoty NIE JE aktívna žiadna — klient si `hk_top` nedomýšľa (M2)');

const hl = C.frontCardModel({ type: 'lift', lift: { system: 'hl_top' } }, ENTRY);
eq(hl.rows.find(r => r.key === 'lift_system').active, 'hl_top',
   'K1: aktívna voľba ide z uloženej hodnoty');
eq(rowKeys(C.frontCardModel({ type: 'fall' }, ENTRY)), ['opening_mode'],
   'K1: SKLOP systém nemá — dostáva závesy ako dvierka (M1)');
eq(rowKeys(C.frontCardModel({ type: 'door' }, ENTRY)), ['opening_mode'],
   'K1: ani dvierka');

// `frontLiftSystem` je JEDINÉ miesto čítania — poškodený tvar ho nezhodí.
eq(C.frontLiftSystem({ lift: { system: 'hk_top' } }), 'hk_top', 'K1: čítanie systému');
eq(C.frontLiftSystem({ lift: {} }), null, 'K1: prázdny objekt = žiadna hodnota');
eq(C.frontLiftSystem({ lift: 'nezmysel' }), null, 'K1: poškodený tvar nespadne');
eq(C.frontLiftSystem(null), null, 'K1: ani chýbajúca položka');

// ============ K2: riadky zo servera =========================================
const OK_REC = { state: 'ok', text: 'AVENTOS HK top · 22K2300 · automat',
                 detail: ['Otváranie: klasické', 'Rozmery pre výber: výška korpusu bez sokla 400 mm',
                          'Stabilizačná tyč: 1×'] };
eq(C.frontLiftRows(undefined), [], 'K2: bez záznamu servera sa nekreslí NIČ');
eq(C.frontLiftRows(null), [], 'K2: ani pri null');
eq(C.frontLiftRows({ state: 'pending' }), [], 'K2: `pending` = karta mlčí');

const okRows = C.frontLiftRows(OK_REC);
eq(okRows.length, 1, 'K2: vyriešený výklop = PRESNE JEDEN riadok');
eq(okRows[0].kind, 'resolved', 'K2: a je to read-only riadok, nie pole');
eq(okRows[0].label, 'Výklop', 'K2: pomenovaný');
eq(okRows[0].text, OK_REC.text, 'K2: text je DOSLOVNE zo servera');
eq(okRows[0].detail, OK_REC.detail, 'K2: aj vety detailu');

const VETA = 'Výklop „F1“: HL top sa v prevedení Tip-On nevyrába — vyber HK top.';
const redRows = C.frontLiftRows({ state: 'conflict', message: VETA });
eq(redRows.length, 1, 'K2: konflikt = jeden červený riadok');
eq(redRows[0].kind, 'info', 'K2: je to inforow, nie resolved');
eq(redRows[0].tone, 'err', 'K2: červený');
eq(redRows[0].icon, 'alert', 'K2: s ikonou (vzor C2c — LEN pri RED/ORANGE)');
eq(redRows[0].text, VETA, 'K2: a veta je SERVERA, slovo za slovom (M3)');
eq(C.frontLiftRows({ state: 'conflict', message: '' }), [],
   'K2: konflikt bez vety nekreslí prázdny červený pruh');
const staleRows = C.frontLiftRows({ state: 'stale', message: 'Prestav skrinku.' });
eq(staleRows[0].tone, 'err', 'K2: stale je tiež červené');

const warnRows = C.frontLiftRows(Object.assign({ warn: 'Čelo je ľahké.' }, OK_REC));
eq(warnRows.length, 2, 'K2: ORANGE je riadok NAVIAC (M4)');
eq(warnRows[0].kind, 'resolved', 'K2: vyriešený riadok ostáva prvý');
eq(warnRows[1].tone, 'warn', 'K2: a jantárový stojí pod ním');
eq(warnRows[1].text, 'Čelo je ľahké.', 'K2: aj tú vetu skladá server');

// K2b (Codex #334 kolo 2 P2): NEÚPLNÁ ZOSTAVA je RED STAV karty, nie riadok
// schovaný v rozkliku. Kým `state` ostávalo `ok`, karta o výklope bez kódu
// mlčala (veta „Bez kódu: …" žila len v „Technickom detaile"), kým Kontrola
// vedľa hlásila RED a zastavovala nákup, rozpočet aj cenovú ponuku.
const NEUPLNY = 'Výklop (HK top): set „vyklop-hk-klasik“ nemá kód pre triedu, ' +
  'ktorú výklop potrebuje — člen 1 — doplň kód do setu. Zostava by bola neúplná ' +
  '(krytky bez mechanizmu), preto sa nákup kovania, rozpočet ani cenová ponuka ' +
  'zatiaľ nedajú vydať.';
const badRows = C.frontLiftRows(Object.assign({}, OK_REC,
                                              { state: 'incomplete', message: NEUPLNY }));
eq(badRows.length, 2, 'K2b: červený dôvod + zhrnutie, nie jedno namiesto druhého');
eq(badRows[0].kind, 'info', 'K2b: dôvod je inforow');
eq(badRows[0].tone, 'err', 'K2b: a je ČERVENÝ — nie jantárová poznámka');
eq(badRows[0].text, NEUPLNY, 'K2b: veta je SERVERA, slovo za slovom (tá istá ako v Kontrole)');
eq(badRows[1].kind, 'resolved', 'K2b: pod ním ostáva zhrnutie…');
eq(badRows[1].detail, OK_REC.detail, '…aj s rozklikom — čo už vieme, sa nezahadzuje');
const badWarn = C.frontLiftRows(Object.assign({}, OK_REC,
                                              { state: 'incomplete', message: NEUPLNY,
                                                warn: 'Čelo je ľahké.' }));
eq(badWarn.map(r => r.tone || r.kind), ['err', 'resolved', 'warn'],
   'K2b: poradie je RED → zhrnutie → ORANGE');
eq(C.frontLiftRows({ state: 'incomplete', text: 'x', message: '' }).length, 1,
   'K2b: bez vety sa prázdny červený pruh nekreslí');
const kartaNeuplna = C.frontCardModel({ type: 'lift', lift: { system: 'hk_top' } }, ENTRY, null,
                                      Object.assign({}, OK_REC,
                                                    { state: 'incomplete', message: NEUPLNY }));
eq(kinds(kartaNeuplna), ['seg', 'seg', 'info', 'resolved'],
   'K2b: veta o automate MIZNE aj tu — hovorí zaň červený riadok');

// ============ K3: vertikálny priestor =======================================
const bezZaznamu = C.frontCardModel({ type: 'lift' }, ENTRY);
eq(infoTexts(bezZaznamu).length, 1, 'K3: bez záznamu servera hovorí veta o automate');
ok(infoTexts(bezZaznamu)[0].indexOf('automat') >= 0, 'K3: a povie, podľa čoho vyberá');

const sZaznamom = C.frontCardModel({ type: 'lift', lift: { system: 'hk_top' } }, ENTRY, null, OK_REC);
eq(infoTexts(sZaznamom).length, 0,
   'K3: nad vyriešeným výklopom veta o automate MIZNE — hovorí zaň riadok (M5)');
eq(kinds(sZaznamom), ['seg', 'seg', 'resolved'],
   'K3: presne systém + otváranie + jeden riadok');
const sKonfliktom = C.frontCardModel({ type: 'lift' }, ENTRY, null,
                                     { state: 'conflict', message: VETA });
eq(kinds(sKonfliktom), ['seg', 'seg', 'info'], 'K3: pri chybe červený riadok NAMIESTO vety');
eq(infoTexts(sKonfliktom), [VETA], 'K3: a je to veta servera');

// ============ K4 + K5: DOM — zápis a HTML karty =============================
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { global[k] = C[k]; });
global.FRONT_PROFILES = [];
global.frontItems = null;
global.frontSlots = null;
global.frontDrawer = null;
global.frontLift = null;
global.selectedCabId = null;
global.applyTimer = null;
global.newStableId = p => p + (++global.__nxid || (global.__nxid = 1));
global.attachExprField = () => {};
global.nxDimFillRow = () => {};
global.evalDim = v => parseFloat(v);
global.numv = () => NaN;
global.val = () => '';
global.setNum = () => {};
global.setOut = () => {};
global.isExprInput = () => false;
global.isExprStr = () => false;
global.refreshMaterialFilters = () => {};
global.renderPreview = () => {};
global.clearFrontHover = () => {};
global.currentCarcass = () => ({});
global.nxInteriorZ = () => ({ availH: 0 });
global.pvGeom = () => ({ W: 0, H: 0 });
global.computeZones = () => [];
global.pvInsertFronts = () => [];
global.nxDraftStats = () => ({});
global.setCabInfo = () => {};
global.frontHwBadge = () => '';
global.frontHwBuy = () => '';
global.hwAxHtml = require(path.join(JS, 'hardware.js')).hwAxHtml;
const FM = require(path.join(JS, 'form.js'));

const rows = mkEl('div');
rows.attrs.id = 'frontRows';
DOC.body.appendChild(rows);
function resetRows(){
  rows.children = [];
  global.frontSlots = null; global.frontDrawer = null; global.frontLift = null;
}
function rowOf(fid){ return rows.querySelectorAll('.frow').find(r => r.dataset.frontId === fid); }
function items(){ return FM.collectFronts().items; }
function openCard(fid){
  FM.refreshFrontCards();
  const b = rowOf(fid).querySelector('.ftname');
  if (b.getAttribute('aria-expanded') !== 'true') FM.onFrontCardToggle(b);
}
function cardOf(fid){ return rowOf(fid).querySelector('.fcard'); }

// --- K4a: klik na chip zapíše systém ----------------------------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'lift', lift: { system: 'hk_top' } });
openCard('F1');
const chipHl = cardOf('F1').querySelectorAll('button')
  .find(b => b.dataset.k === 'lift_system' && b.dataset.v === 'hl_top');
ok(chipHl, 'K4: chip HL top je v karte');
FM.onFrontSeg(chipHl);
eq(items()[0].lift, { system: 'hl_top' },
   'K4: klik zapíše VNORENÝ objekt `lift.system`, nie plochý kľúč (M6)');
eq(items()[0].type, 'lift', 'K4: a typ riadku sa nemení');

// Klik na UŽ aktívnu voľbu = žiadny prázdny krok Späť.
const chipHl2 = cardOf('F1').querySelectorAll('button')
  .find(b => b.dataset.k === 'lift_system' && b.dataset.v === 'hl_top');
eq(chipHl2.getAttribute('aria-pressed'), 'true', 'K4: aktívny chip je označený');

// --- K4b: prepnutie typu NA VÝKLOP systém materializuje ----------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door' }, true);
openCard('F1');
const tileLift = rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === 'lift');
FM.onFrontTile(tileLift);
eq(items()[0].lift, { system: 'hk_top' },
   'K4: prepnutie NA výklop nasadí to, čo server aj tak uloží (`Fronts.normalize_config`)');
// A uložená hodnota sa NEPREPÍŠE.
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', lift: { system: 'hl_top' } });
openCard('F1');
FM.onFrontTile(rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === 'lift'));
eq(items()[0].lift, { system: 'hl_top' }, 'K4: dormant HL top prežije návrat na výklop');

// --- K5: HTML karty ----------------------------------------------------------
resetRows();
global.frontLift = { F1: Object.assign({ warn: 'Čelo je príliš ľahké.' }, OK_REC) };
FM.addFrontRow({ id: 'F1', type: 'lift', lift: { system: 'hk_top' } });
openCard('F1');
const card = cardOf('F1');
const drow = card.querySelector('.drow');
ok(drow, 'K5: vyriešený výklop má vlastný read-only riadok');
eq(md.textOf(drow.querySelector('.dl')), 'Výklop', 'K5: s popiskom');
eq(md.textOf(drow.querySelector('.dv')), OK_REC.text, 'K5: a hodnotou zo servera');
const det = card.querySelector('.ddet');
ok(det, 'K5: technický detail je ROZKLIK, nie trvalý blok (M7)');
eq(md.textOf(det.querySelector('summary')), 'Technický detail', 'K5: pomenovaný');
eq(det.querySelectorAll('li').length, OK_REC.detail.length, 'K5: veta na riadok');
const warn = card.querySelectorAll('.inforow').find(e => (e.attrs.class || '').indexOf('warn') >= 0);
ok(warn, 'K5: ORANGE inforow je vykreslený');
ok(md.textOf(warn).indexOf('príliš ľahké') >= 0, 'K5: s vetou servera');
ok(warn.querySelector('use'), 'K5: a s ikonou zo spritu (žiadne emoji)');

// RED: veta konfliktu má triedu `err`.
resetRows();
global.frontLift = { F1: { state: 'conflict', message: VETA } };
FM.addFrontRow({ id: 'F1', type: 'lift', lift: { system: 'hl_top' } });
openCard('F1');
const err = cardOf('F1').querySelectorAll('.inforow').find(e => (e.attrs.class || '').indexOf('err') >= 0);
ok(err, 'K5: konflikt je červený inforow');
ok(md.textOf(err).indexOf('Tip-On') >= 0, 'K5: s vetou servera');
ok(!cardOf('F1').querySelector('.drow'), 'K5: a bez riadku, ktorý by tvrdil, že je hotovo');
// HTML `disabled` nie je ochrana: kombinácia HL + Tip-On sa DÁ nastaviť ďalej,
// karta o nej len hneď povie (server ju odmieta v bránach, nie v markupe).
const tipon = cardOf('F1').querySelectorAll('button')
  .find(b => b.dataset.k === 'opening_mode' && b.dataset.v === 'tipon');
ok(tipon && !tipon.attrs.disabled, 'K5: chip Tip-On ostáva klikateľný — nič sa nezakazuje potichu');

// ============ K6: GOLDEN — čelo bez výklopu ================================
resetRows();
global.frontLift = { F1: OK_REC }; // záznam je v mape, ale patrí inému čelu
FM.addFrontRow({ id: 'F2', type: 'door' });
openCard('F2');
ok(!cardOf('F2').querySelector('.drow'),
   'K6: dvierka riadok výklopu NEDOSTANÚ ani keď mapa nejaký nesie (M8)');
eq(C.frontCardModel({ type: 'door' }, ENTRY, null, OK_REC).rows.filter(r => r.kind === 'resolved')
   .length, 0, 'K6: ani vo view-modeli');
eq(C.frontCardModel({ type: 'fall' }, ENTRY, null, OK_REC).rows.filter(r => r.kind === 'resolved')
   .length, 0, 'K6: a sklop tiež nie');

// ============ K7: PICKER SETU VÝKLOPU (kontext Kovanie) =====================
//
// Výber setu (vrátane tmavého) NIE JE v karte čela — je pri položke kovania,
// rovnako ako pri zásuvke (D1b). Klient tu NIČ nefiltruje a nič neprekladá:
// ponuku aj popisky skladá server (`Panel.class_compat_payload`) a panel pošle
// späť ID voľby, ktoré dostal. Táto sekcia stráži presne to.
const HW = require(path.join(JS, 'hardware.js'));
const OWNER = 'front:F1/flap';
// Payload presne v tvare, aký posiela server pre klasifikovaný výklop.
const ENTRY_LIFT = {
  generic_type: 'lift', label: 'Výklop / sklop',
  compat: { cab: null, owners: { [OWNER]: {
    class_key: 'class:lift|classic|hk_top',
    class_label: 'Výklop / sklop · klasické · HK top',
    scope_label: 'Set pre toto čelo',
    none_label: 'podľa projektu — Výklop HK top — klasik (biela)',
    options: [{ id: 'vyklop-hk-klasik', label: 'Výklop HK top — klasik (biela)',
                set_id: 'vyklop-hk-klasik' },
              { id: 'vyklop-hk-klasik-tmavy', label: 'Výklop HK top — klasik (tmavá)',
                set_id: 'vyklop-hk-klasik-tmavy' }],
    current: 'vyklop-hk-klasik-tmavy', stored: false,
    value_text: 'Výklop HK top — klasik (tmavá)'
  } } }
};
const picker = HW.hwOwnerOptionList(ENTRY_LIFT, OWNER);
eq(picker.length, 3, 'K7: „predvolené" + dve triedne kompatibilné voľby');
eq(picker[0].text, 'podľa projektu — Výklop HK top — klasik (biela)',
   'K7: prvá voľba povie, čo platí BEZ vlastného výberu');
eq(picker[0].selected, false, 'K7: a nie je vybraná, lebo vlastný výber existuje');
ok(picker.some(o => o.text.indexOf('tmavá') >= 0), 'K7: tmavý set je v ponuke POZNAŤ');
eq(picker.find(o => o.value === 'vyklop-hk-klasik-tmavy').selected, true,
   'K7: uložený výber je vybraný — prvý klik vedľa ho ticho neprepíše');
ok(HW.hwOwnerTitle(ENTRY_LIFT, OWNER).indexOf('HK top') >= 0,
   'K7: tooltip povie, akej triedy sa výber týka');
// Čelo BEZ klasifikácie (starý výklop) ponuku triedy nedostane — spadne na
// pôvodný plochý zoznam, presne ako doteraz.
eq(HW.hwOwnerOptionList({ generic_type: 'lift', options: [] }, OWNER)[0].text,
   '(podľa skrinky/projektu)', 'K7: neklasifikovaná položka ide pôvodnou cestou');

console.log('KOV-E2 karta vyklopu: ' + n + ' assertov OK');
