// KOV-D2b — ZAMKY OSI, UI: chipy „výška" a „NL" v sekcii Kovanie AJ v karte
// čela, klik = zamknúť aktuálnu / odomknúť, konflikt = RED + náhrada s D-15
// potvrdením.
//
// Preco su to testy a nie klikanie v paneli:
//   1. SERVER JE AUTORITA. Chip smie ukazat LEN to, co prislo v `axes`, a do
//      zapisu smie ist LEN hodnota zo servera (`value` / `options` /
//      `proposal`). Keby panel cital cislo z TEXTU chipu, „H144" by sa poslalo
//      ako 144 aj tam, kde server hovori nieco ine — a zamok by uzamkol inu
//      vysku, nez pouzivatel videl.
//   2. JEDEN MARKUP PRE DVE MIESTA. Sekcia Kovanie a karta cela musia kreslit
//      TEN ISTY rad; dva renderery by sa casom rozisli.
//   3. ODOMKNUTIE MUSI ZOSTAT DOSTUPNE aj vtedy, ked polozka vysuvu pri
//      konflikte NEVZNIKLA (osiroteny riadok / konfliktna karta).
//   4. NAHRADA JE ROZHODNUTIE. Bez D-15 potvrdenia sa zamknuta hodnota
//      nezmeni nikdy.
//
// MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
//   M1 `onHwAxChip` cita hodnotu z TEXTU chipu namiesto `data-val`
//      -> „KOV-D2b (R2): klik na `auto` zamkne hodnotu ZO SERVERA"
//   M2 `onHwAxFix` odosle nahradu bez potvrdenia
//      -> „KOV-D2b (R3): nahrada sa BEZ potvrdenia neodosle"
//   M3 `onHwAxChip` posle pri odomykani `reset: true` (cely zaznam)
//      -> „KOV-D2b (R2): klik na `locked` odomkne LEN TUTO os"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, textOf } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// --- prostredie panela -------------------------------------------------------
const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);

global.esc = function(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
global.el = function(id){ return DOC.getElementById(id); };
global.NXIcons = { svg: function(name){ return '<svg class="ic"><use href="#i-' + name + '"/></svg>'; } };

const STATUS = [];
global.NX = { setStatus: function(msg, err){ STATUS.push({ msg: msg, err: !!err }); } };

const SENT = [];
global.sketchup = {
  set_hardware_override: function(p){ SENT.push(JSON.parse(p)); }
};
global.window.sketchup = global.sketchup;
global.nxDocPayload = function(p){ return JSON.stringify(p); };

global.NXModal = require(path.join(JS, 'nx_modal.js'));
const HW = require(path.join(JS, 'hardware.js'));
const C = require(path.join(JS, 'core.js'));

// Payload servera (`Panel.drawer_axes_map`) — tvar je kontrakt D2a.
const IDENT = { owner_part_key: 'front:F1/panel', generic_type: 'slide',
                rule_id: 'recipe:atira_sisy_v1', cabinet_id: 'CAB-1' };
const AUTO = {
  height: { state: 'auto', value: 144, options: [70, 144] },
  nl: { state: 'auto', value: 470, options: [350, 420, 470] }
};
const LOCKED = {
  height: { state: 'locked', value: 70, options: [70, 144] },
  nl: { state: 'auto', value: 470, options: [350, 420, 470] }
};
const CONFLICT = {
  height: { state: 'conflict', value: 176, options: [70, 144],
            message: 'Výška H176 sa do svetlej výšky 175 mm nezmestí (potrebuje 221 mm).',
            proposal: 144 },
  nl: { state: 'auto', value: null, options: [], blocked_by: 'height' }
};
const NO_FIX = {
  nl: { state: 'conflict', value: 620, options: [350, 420, 470],
        message: 'Dĺžka 620 nie je v rade H70.', proposal: null }
};
const QUADRO = { nl: { state: 'auto', value: 450, options: [350, 400, 450] } };

function render(axes, ident){
  const box = mkEl('div');
  DOC.body.appendChild(box);
  box.innerHTML = HW.hwAxHtml(axes, ident || IDENT);
  return box;
}
function chips(box){ return box.querySelectorAll('.axchip'); }
function chipOf(box, kind){
  return box.querySelector('.axchip[data-ax="' + kind + '"]');
}

// ===========================================================================
// A) CISTE FUNKCIE — texty, stavy, ponuka
// ===========================================================================

eq(HW.hwAxState({ state: 'locked' }), 'locked', 'stav je SERVEROVY enum');
eq(HW.hwAxState({ state: 'conflict' }), 'conflict');
eq(HW.hwAxState({ state: 'auto' }), 'auto');
eq(HW.hwAxState({ state: 'nieco-nove' }), 'auto',
   'neznamy stav sa NEDOMYSLA — kresli sa ako automat');
eq(HW.hwAxState(null), 'auto');

eq(HW.hwAxValText('height', 144), 'H144', 'vyska ma popisok „H<číslo>"');
eq(HW.hwAxValText('nl', 470), 'NL 470', 'dlzka ma popisok „NL <číslo>"');
eq(HW.hwAxValText('nl', 470.5), 'NL 470,5', 'desatiny idu cez formatovac panela');
eq(HW.hwAxValText('height', null), '—',
   'chybajuca hodnota sa PRIZNA — nula by klamala');

eq(HW.hwAxOptionList('height', AUTO.height),
   [{ value: '70', text: 'H70', selected: false },
    { value: '144', text: 'H144', selected: true }],
   'ponuka = VYHRADNE `options` zo servera, vybrana je aktualna hodnota');
eq(HW.hwAxOptionList('nl', CONFLICT.nl), [],
   'KOV-D2b (R3): pri `blocked_by` nie je co ponukat');

ok(HW.hwAxChipTitle('height', AUTO.height).indexOf('Zamknúť výšku H144') === 0,
   'tooltip `auto` pomenuje, co sa zamkne');
eq(HW.hwAxChipTitle('nl', { state: 'locked', value: 470 }), 'Odomknúť — platí automat',
   'tooltip `locked` pomenuje NAVRAT na automat');
ok(HW.hwAxChipTitle('height', CONFLICT.height).indexOf('už neplatí') > 0,
   'tooltip konfliktu hovori, ze hodnota neplati');

eq(HW.hwAxFixLabel('height', CONFLICT.height), 'Nahradiť za H144',
   'tlacidlo nahrady menuje KONKRETNU hodnotu zo servera');

// ===========================================================================
// B) MARKUP — co sa nakresli
// ===========================================================================

const bAuto = render(AUTO);
eq(chips(bAuto).length, 2, 'dve osi = dva chipy (ziadny novy blok)');
// (medzeru medzi hodnotou a popiskom robi `gap` v CSS — mini-DOM ju nevidi)
eq(textOf(chipOf(bAuto, 'height')).trim(), 'H144výška',
   'chip vysky nesie hodnotu aj popisok osi');
eq(textOf(chipOf(bAuto, 'nl')).trim(), 'NL 470', 'chip dlzky nesie „NL <číslo>"');
eq(chipOf(bAuto, 'height').getAttribute('data-val'), '144',
   'hodnota do zapisu je v datasete, nie v texte');
eq(chipOf(bAuto, 'height').getAttribute('aria-pressed'), 'false', 'automat nie je zamok');
ok(bAuto.innerHTML.indexOf('#i-lock-open') >= 0, 'automat kresli OTVORENY zamok (sprite, nie emoji)');
eq(bAuto.querySelectorAll('.axsel').length, 2, 'obe osi maju ponuku inej hodnoty');
eq(bAuto.querySelectorAll('.axconf').length, 0, 'bez konfliktu ziadny cerveny blok');

const bLock = render(LOCKED);
ok(chipOf(bLock, 'height').getAttribute('class').indexOf('locked') >= 0,
   'zamknuta os ma jantarovy chip (tokeny --nx-warn-*)');
eq(chipOf(bLock, 'height').getAttribute('aria-pressed'), 'true');
ok(bLock.innerHTML.indexOf('#i-lock"') >= 0, 'a ZATVORENY zamok');

const bConf = render(CONFLICT);
ok(chipOf(bConf, 'height').getAttribute('class').indexOf('err') >= 0, 'konflikt je CERVENY chip');
const conf = bConf.querySelector('.axconf');
ok(conf, 'konflikt ma vlastny riadok s dovodom');
ok(textOf(conf).indexOf(CONFLICT.height.message) >= 0,
   'veta je SERVEROVA — panel ziadnu vlastnu neskladá');
const cbtns = conf.querySelectorAll('button');
eq(cbtns.length, 2, 'nahrada + odomknutie');
ok(textOf(cbtns[0]).indexOf('Nahradiť za H144') >= 0);
ok(textOf(cbtns[1]).indexOf('Odomknúť') >= 0);
eq(bConf.querySelector('.axnote') ? textOf(bConf.querySelector('.axnote')) : '',
   HW.HW_AX_BLOCKED, 'KOV-D2b (R3): pri `blocked_by` NL povie, ze najprv treba vysku');
eq(bConf.querySelectorAll('.axsel[data-ax="nl"]').length, 0,
   'a nema ziadnu ponuku');

const bNoFix = render(NO_FIX);
const noFixBtns = bNoFix.querySelector('.axconf').querySelectorAll('button');
eq(noFixBtns.length, 1, 'KOV-D2b (R3): bez `proposal` sa nahrada NEPONUKA');
ok(textOf(noFixBtns[0]).indexOf('Odomknúť') >= 0,
   'odomknutie je dostupne VZDY (aj ked navrh neexistuje)');

const bQ = render(QUADRO);
eq(chips(bQ).length, 1, 'Quadro nema os vysky — chip sa nekresli');
eq(chipOf(bQ, 'height'), null, 'ani ako „automat"');

eq(HW.hwAxHtml(null, IDENT), '', 'bez stavu servera sa nekresli nic');
eq(HW.hwAxHtml(AUTO, null), '', 'bez identity zapisu tiez nic (klik do prazdna)');

// ===========================================================================
// C) ZAPIS — co odide do Ruby
// ===========================================================================

function lastSent(){ return SENT.length ? SENT[SENT.length - 1] : null; }

SENT.length = 0;
HW.onHwAxChip(chipOf(bAuto, 'height'));
eq(SENT.length, 1, 'klik posle prave jeden zapis');
eq(lastSent(), { owner_part_key: 'front:F1/panel', generic_type: 'slide',
                 rule_id: 'recipe:atira_sisy_v1', cabinet_id: 'CAB-1',
                 field: 'height_variant', value: 144 },
   'KOV-D2b (R2): klik na `auto` zamkne hodnotu ZO SERVERA (existujuca akcia, pole osi)');

SENT.length = 0;
HW.onHwAxChip(chipOf(bAuto, 'nl'));
eq(lastSent().field, 'nominal_length', 'druha os pise do svojho pola');
eq(lastSent().value, 470);

// Text chipu a hodnota do zapisu su DVE ROZNE veci: „NL 470,5" je popisok pre
// cloveka (desatinna CIARKA), 470.5 je cislo pre server. Keby panel cital
// cislo z textu, poslal by 4705 — a zamkol by dlzku, ktora neexistuje.
SENT.length = 0;
const bDec = render({ nl: { state: 'auto', value: 470.5, options: [420, 470.5] } });
eq(textOf(chipOf(bDec, 'nl')).trim(), 'NL 470,5', 'popisok je slovenský, s ciarkou');
HW.onHwAxChip(chipOf(bDec, 'nl'));
eq(lastSent().value, 470.5,
   'KOV-D2b (R2): hodnota do zapisu ide z `axes.value`, NIKDY z textu chipu');

SENT.length = 0;
HW.onHwAxChip(chipOf(bLock, 'height'));
eq(lastSent(), { owner_part_key: 'front:F1/panel', generic_type: 'slide',
                 rule_id: 'recipe:atira_sisy_v1', cabinet_id: 'CAB-1',
                 field: 'height_variant', value: null },
   'KOV-D2b (R2): klik na `locked` odomkne LEN TUTO os (`value: null`, nikdy `reset`)');
ok(!Object.prototype.hasOwnProperty.call(lastSent(), 'reset'),
   'zahodenie celeho zaznamu by zmazalo aj platny druhy zamok');

SENT.length = 0;
const sel = bAuto.querySelector('.axsel[data-ax="nl"]');
sel.value = '350';
HW.onHwAxPick(sel);
eq(lastSent().value, 350, 'volba z ponuky zamkne PRESNE tu hodnotu');
eq(lastSent().field, 'nominal_length');

SENT.length = 0;
HW.onHwAxUnlock(bConf.querySelector('.axconf').querySelectorAll('button')[1]);
eq(lastSent(), { owner_part_key: 'front:F1/panel', generic_type: 'slide',
                 rule_id: 'recipe:atira_sisy_v1', cabinet_id: 'CAB-1',
                 field: 'height_variant', value: null },
   'KOV-D2b (R3): odomknut sa da aj z KONFLIKTNEJ karty (bez emitovanej polozky)');

// Chip bez hodnoty (server ju nema) sa zamknut NEDA — a povie preco.
SENT.length = 0;
STATUS.length = 0;
const bNoVal = render({ nl: { state: 'auto', value: null, options: [] } });
HW.onHwAxChip(chipOf(bNoVal, 'nl'));
eq(SENT.length, 0, 'bez serverovej hodnoty sa neodosiela nic');
eq(STATUS.length ? STATUS[0].msg : '', HW.HW_AX_NOVAL, 'a pouzivatel sa dozvie preco');

// ===========================================================================
// D) NAHRADA = D-15 POTVRDENIE
// ===========================================================================

SENT.length = 0;
const fixBtn = bConf.querySelector('.axconf').querySelectorAll('button')[0];
HW.onHwAxFix(fixBtn);
eq(SENT.length, 0, 'KOV-D2b (R3): nahrada sa BEZ potvrdenia neodosle');
ok(global.NXModal.isOpen(), 'nahrada otvara potvrdenie (kostra D-15)');
const modal = DOC.getElementById('nxModalRoot');
ok(textOf(modal).indexOf('Nahradiť za H144') >= 0 || textOf(modal).indexOf('H144') >= 0,
   'okno menuje, co sa zamkne namiesto coho');
ok(textOf(modal).indexOf('Zámok druhej osi sa nemení') >= 0,
   'a hovori, ze druhy zamok ostava');
global.NXModal.submit();
eq(lastSent(), { owner_part_key: 'front:F1/panel', generic_type: 'slide',
                 rule_id: 'recipe:atira_sisy_v1', cabinet_id: 'CAB-1',
                 field: 'height_variant', value: 144 },
   'po potvrdeni sa zapise NAVRH SERVERA — a ostava ZAMKNUTY');
ok(!global.NXModal.isOpen(), 'potvrdenie okno zatvara');

// Zrusenie potvrdenia nezapise nic.
SENT.length = 0;
HW.onHwAxFix(fixBtn);
global.NXModal.close();
eq(SENT.length, 0, 'zavrete okno = ziadny zapis');

// ===========================================================================
// E) OBE MIESTA KRESLIA TEN ISTY RAD
// ===========================================================================

// 1) sekcia Kovanie — riadok polozky vysuvu aj OSIROTENY riadok zasahu.
// `hwItemHtml`/`hwOffHtml` nie su exportovane (potrebuju cely kontext boxov),
// preto sa kontroluje ZDROJ — rovnaky vzor ako v `test_kovd1b_ui.js`.
const fs = require('node:fs');
// Zdroje sa citaju s normalizovanymi koncami riadkov (Windows checkout = CRLF).
const readSrc = (name) => fs.readFileSync(path.join(JS, name), 'utf8').replace(/\r\n/g, '\n');
const hwSrc = readSrc('hardware.js');
const formSrc = readSrc('form.js');

const itemFn = hwSrc.match(/function hwItemHtml\(it, cabId, groupKey\)\{[\s\S]*?\n  \}\n/)[0];
ok(/hwAxHtml\(it\.axes,/.test(itemFn),
   'riadok vysuvu v Kovani kresli chipy z `it.axes`');
ok(itemFn.indexOf('hwAxHtml') < itemFn.indexOf('hwBuyHtml(it.purchase)'),
   'chipy stoja PRED nakupnym riadkom — `refreshHardwarePurchase` ho prilepuje na koniec');

const offFn = hwSrc.match(/function hwOffHtml\(ov, cabId, groupKey\)\{[\s\S]*?\n  \}\n/)[0];
ok(/hwAxHtml\(ov\.axes,/.test(offFn),
   'OSIROTENY riadok zasahu dostava chipy tiez (polozka pri konflikte nevznikla)');

// 2) karta cela — view-model riadok + delegacia na TEN ISTY renderer.
const CARD_OK = { state: 'ok', text: 'Atira · H144 · NL 470', detail: [],
                  axes: AUTO, lock: IDENT };
const rows = C.frontDrawerRows(CARD_OK);
eq(rows.map(r => r.kind), ['resolved', 'axes'],
   'karta kresli zhrnutie a POD nim rad chipov (ziadny druhy blok)');
eq(rows[1].axes, AUTO, 'stav je ten isty objekt zo servera');
eq(rows[1].ident, IDENT, 'a identitu zapisu dava server (`recipe:<id>` panel neskladá)');

const confRows = C.frontDrawerRows({ state: 'conflict', message: 'Nezmestí sa.',
                                     axes: CONFLICT, lock: IDENT });
eq(confRows.map(r => r.kind), ['info', 'axes'],
   'KOV-D2b (R3): aj KONFLIKTNA karta ma chipy — inak sa neda odomknut');

eq(C.frontDrawerRows({ state: 'ok', text: 'x', detail: [], axes: AUTO }).map(r => r.kind),
   ['resolved'], 'bez identity zapisu sa chipy nekreslia (klik do prazdna)');
eq(C.frontDrawerRows({ state: 'ok', text: 'x', detail: [] }).map(r => r.kind),
   ['resolved'], 'stary payload bez `axes` sa sprava presne ako v C2c');
eq(C.frontDrawerRows({ state: 'stale' }).map(r => r.kind), ['info'],
   'nemigrovana zasuvka nema co zamykat');

const cardFn = formSrc.match(/function frontCardHtml\(row\)\{[\s\S]*?\n  \}\n/)[0];
ok(/r\.kind === 'axes'/.test(cardFn) && /hwAxHtml\(r\.axes, r\.ident\)/.test(cardFn),
   'karta cela kresli TEN ISTY markup ako sekcia Kovanie (jeden renderer)');

// Chipy „otváranie" a „nosnosť" z mockupu sa VEDOME nepridali (vertikalny
// priestor; riadok zhrnutia ich uz nesie) — strazi to pocet osi.
eq(HW.HW_AX.map(d => d.key), ['height', 'nl'],
   'osi su PRAVE DVE — mockupove chipy otvarania a nosnosti sa nepridavaju');

console.log('KOV-D2b UI: ' + n + ' assertov OK');
