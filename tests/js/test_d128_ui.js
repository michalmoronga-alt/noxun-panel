// D-128 — RUCNA VYSKA DREVENEHO BOXU: chip „box" s malym CISELNYM POLOM
// v kontexte Kovanie AJ v karte cela.
//
// Preco su to testy a nie klikanie v paneli:
//   1. HODNOTA DO ZAPISU IDE Z POLA, nikdy z textu chipu. Text chipu je
//      popisok pre cloveka („box 360"); keby sa z neho parsovalo cislo,
//      zamklo by sa nieco ine, nez pouzivatel napisal.
//   2. PARSER MUSI BYT PRISNY. `parseFloat('1e309')` dá Infinity a
//      `parseFloat('300,5')` dá 300 — server by dostal iny rozmer boxu, nez
//      je na obrazovke. Klient preto overuje CELY text.
//   3. Z POLA NIKDY NEVZNIKNE `null`. Odomknutie je vedome rozhodnutie
//      (chip alebo tlacidlo „Odomknúť"), nie vymazanie textu.
//   4. KONFLIKT NEMA POLE — presne ako nema ponuku. Jedina cesta von je
//      nahrada s potvrdenim alebo odomknutie.
//   5. ATIRA SA NEMENI ANI O BAJT — os `box` v jej payloade neexistuje.
//
// MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
//   M4 `onHwAxNum` cita hodnotu z textu chipu namiesto `input.value`
//      -> „D-128: zapis ide z POLA, nie z textu chipu"
//   M6 `hwAxNum` pouzije `parseFloat` bez prisneho regexu
//      -> „D-128: prisny parser odmietne „1e309" aj „300,5xx""
//   M7 pole sa kresli aj v stave `conflict`
//      -> „D-128: os v KONFLIKTE nema pole — len náhradu a odomknutie"
//   M8 pole sa kresli aj pri PRAZDNOM rozsahu (`max < min`)
//      -> „D-128: prazdny alebo neurcitelny rozsah pole NEKRESLI"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

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

// Payload servera (`Panel.drawer_axes_map`) — kontrakt D-128.
const IDENT = { owner_part_key: 'front:F1/panel', generic_type: 'slide',
                rule_id: 'recipe:quadro_v6_sisy_v1', cabinet_id: 'CAB-1' };
const AUTO = {
  box: { state: 'auto', value: 360, min: 58, max: 360 },
  nl: { state: 'auto', value: 450, options: [350, 400, 450] }
};
const LOCKED = {
  box: { state: 'locked', value: 300, min: 58, max: 360 },
  nl: { state: 'auto', value: 450, options: [350, 400, 450] }
};
const CONFLICT = {
  box: { state: 'conflict', value: 500, min: 58, max: 360, proposal: 360,
         message: 'Quadro V6 SiSy v1: ručne zamknutá výška boxu 500 mm je nad automatom 360 mm.' },
  nl: { state: 'auto', value: 450, options: [350, 400, 450] }
};
// A6: velmi nizka zona — rozsah je PRAZDNY, zamknut sa neda nic.
const NORANGE = {
  box: { state: 'auto', value: null, min: null, max: null },
  nl: { state: 'auto', value: 350, options: [350] }
};
// Atira: os `box` v jej payloade NEEXISTUJE.
const ATIRA = {
  height: { state: 'auto', value: 144, options: [70, 144] },
  nl: { state: 'auto', value: 470, options: [350, 420, 470] }
};

function render(axes, ident){
  const box = mkEl('div');
  DOC.body.appendChild(box);
  box.innerHTML = HW.hwAxHtml(axes, ident || IDENT);
  return box;
}
function chipOf(box, kind){ return box.querySelector('.axchip[data-ax="' + kind + '"]'); }
function numOf(box){ return box.querySelector('.axnum'); }
function last(){ return SENT[SENT.length - 1]; }

// ===========================================================================
// A) CISTE FUNKCIE — texty a PRISNY parser
// ===========================================================================

eq(HW.HW_AX.map(d => d.key), ['height', 'box', 'nl'], 'poradie osi = poradie resolvera');
eq(HW.hwAxDef ? 0 : 0, 0, 'definicia osi je interna — testuje sa cez markup');

eq(HW.hwAxValText('box', 300), 'box 300', 'chip nesie nazov osi (v rade chipov musi byt jasny)');
eq(HW.hwAxValText('box', 300.5), 'box 300,5', 'desatinna CIARKA po slovensky');
eq(HW.hwAxValText('box', null), '—', 'chybajuca hodnota sa PRIZNA');
eq(HW.hwAxBare('box', 360), '360', 'veta os uz menuje — nazov sa neopakuje');
eq(HW.hwAxBare('height', 144), 'H144', 'starsie osi sa NEMENIA');
eq(HW.hwAxBare('nl', 470), 'NL 470', 'starsie osi sa NEMENIA');
eq(HW.hwAxFixLabel('box', CONFLICT.box), 'Nahradiť za 360', 'tlacidlo nahrady bez „box"');
ok(HW.hwAxFixSub('box', CONFLICT.box).indexOf('Výška boxu 500 už neplatí') === 0,
   'veta potvrdenia menuje os RAZ: ' + HW.hwAxFixSub('box', CONFLICT.box));

// PRISNY parser — jadro naleza Astra BLOCKER 3.
[['300', 300], ['300.5', 300.5], ['300,5', 300.5], ['  300  ', 300], ['0.5', 0.5]]
  .forEach(function(p){
    eq(HW.hwAxNum(p[0]), p[1], 'platny vstup ' + JSON.stringify(p[0]));
  });
['1e309', '1e3', 'Infinity', '-Infinity', 'NaN', '', '   ', 'abc', '300px', '300,5xx',
 '-5', '0', '.5', '3 0 0', '0x10', '+300', null, undefined]
  .forEach(function(raw){
    eq(HW.hwAxNum(raw), null, 'neplatny vstup ' + JSON.stringify(raw) + ' sa NEPARSUJE');
  });
// Presne to, co by `parseFloat` prehltlo (mutacia M6).
ok(isFinite(parseFloat('300,5')) && HW.hwAxNum('300,5xx') === null,
   'D-128: prisny parser odmietne „1e309" aj „300,5xx"');
ok(parseFloat('1e309') === Infinity && HW.hwAxNum('1e309') === null,
   'D-128: prisny parser odmietne „1e309" aj „300,5xx" (overflow)');

// ===========================================================================
// B) MARKUP — pole namiesto ponuky
// ===========================================================================

const auto = render(AUTO);
ok(chipOf(auto, 'box'), 'Quadro ma chip osi `box`');
ok(!chipOf(auto, 'height'), 'Quadro kluc `height` nema — pravidlo D2b plati dalej');
eq(auto.querySelectorAll('.axsel[data-ax="box"]').length, 0,
   'spojity rozsah NEMA ponuku — ziadny <select> pre `box`');
const numAuto = numOf(auto);
ok(numAuto, 'os `box` ma male ciselne pole');
eq(numAuto.getAttribute('data-ax'), 'box');
eq(numAuto.getAttribute('data-axc'), 'num', 'druh ovladaca pre obnovu fokusu');
eq(numAuto.getAttribute('value'), '', 'v stave `auto` je pole prazdne');
eq(numAuto.getAttribute('placeholder'), '58–360', 'placeholder nesie ROZSAH zo servera');
eq(numAuto.getAttribute('data-min'), '58');
eq(numAuto.getAttribute('data-max'), '360');
ok(numAuto.getAttribute('title').indexOf('automat 360') > 0,
   'title povie, co je automat: ' + numAuto.getAttribute('title'));
eq(chipOf(auto, 'box').getAttribute('data-val'), '360', 'chip nesie hodnotu ZO SERVERA');

const locked = render(LOCKED);
eq(numOf(locked).getAttribute('value'), '300', 'zamknuta hodnota je v poli');
eq(numOf(locked).getAttribute('data-init'), '300', 'pociatocna hodnota pre porovnanie pri blur');
eq(chipOf(locked, 'box').getAttribute('data-state'), 'locked');

const conflict = render(CONFLICT);
eq(numOf(conflict), null, 'D-128: os v KONFLIKTE nema pole — len náhradu a odomknutie');
ok(conflict.querySelector('[data-ax="box"][data-axc="fix"]'), 'ponuka náhrady je');
ok(conflict.querySelector('[data-ax="box"][data-axc="unlock"]'), 'odomknutie je vzdy');
ok(conflict.innerHTML.indexOf('nad automatom 360') > 0, 'veta je SERVEROVA');

const norange = render(NORANGE);
eq(numOf(norange), null, 'D-128: prazdny alebo neurcitelny rozsah pole NEKRESLI');
ok(chipOf(norange, 'box'), 'chip ostava (aby sa dal stav priznat)');
eq(chipOf(norange, 'box').getAttribute('data-val'), '', 'bez hodnoty sa nema co zamknut');

const atira = render(ATIRA);
eq(numOf(atira), null, 'Atira pole nema — os `box` v jej payloade neexistuje');
eq(atira.querySelectorAll('.axchip').length, 2, 'Atira ma presne dva chipy (výška, NL)');
ok(atira.innerHTML.indexOf('data-ax="box"') < 0, 'ani stopa po osi `box`');
ok(atira.querySelector('.axsel[data-ax="height"]'), 'Atira ponuku vysok NESTRATILA');

// ===========================================================================
// C) ZAPIS Z POLA
// ===========================================================================

SENT.length = 0;
STATUS.length = 0;
const w = render(AUTO);
const inp = numOf(w);
inp.value = '300';
ok(HW.onHwAxNum(inp), 'zmenena hodnota sa odosle');
eq(last().field, 'box_height', 'pole zaznamu je `box_height`');
eq(last().value, 300, 'D-128: zapis ide z POLA, nie z textu chipu');
eq(last().owner_part_key, 'front:F1/panel', 'identita z obalu `.hwax`');
eq(last().rule_id, 'recipe:quadro_v6_sisy_v1');
eq(last().cabinet_id, 'CAB-1', 'guard F6 plati aj pre pole');
ok(String(last().value) !== '360', 'hodnota chipu (360) sa neposlala');

// Desatinna ciarka je slovenska realita — server dostane bodkove cislo.
SENT.length = 0;
inp.value = '300,5';
ok(HW.onHwAxNum(inp));
eq(last().value, 300.5);

// Neplatny text sa NEODOSIELA a povie sa to.
SENT.length = 0;
STATUS.length = 0;
inp.value = '1e309';
eq(HW.onHwAxNum(inp), false, 'overflow sa neodosle');
eq(SENT.length, 0);
eq(STATUS[STATUS.length - 1].msg, HW.HW_AX_BADNUM);
ok(STATUS[STATUS.length - 1].err, 'je to chyba, nie informacia');

// Prazdne pole = NIC (odomyka sa chipom alebo tlacidlom).
SENT.length = 0;
STATUS.length = 0;
inp.value = '';
eq(HW.onHwAxNum(inp), false, 'prazdne pole sa neodosiela');
eq(SENT.length, 0, 'z pola NIKDY nevznikne odomknutie (`value: null`)');
eq(STATUS.length, 0, 'a ani hlaska — nie je to chyba');

// Blur BEZ zmeny nezapisuje (panel sa prekresluje po kazdom pushi).
SENT.length = 0;
const w2 = render(LOCKED);
const inp2 = numOf(w2);
eq(HW.onHwAxNum(inp2), false, 'nezmenena hodnota sa neposiela znova');
eq(SENT.length, 0);
inp2.value = '250';
ok(HW.onHwAxNum(inp2), 'zmenena uz ano');
eq(last().value, 250);

// Enter odosiela, ine klavesy nie.
SENT.length = 0;
const w3 = render(AUTO);
const inp3 = numOf(w3);
inp3.value = '200';
let prevented = 0;
eq(HW.onHwAxNumKey({ key: 'a', preventDefault: function(){ prevented++; } }, inp3), false,
   'ina klavesa nezapisuje');
eq(SENT.length, 0);
ok(HW.onHwAxNumKey({ key: 'Enter', preventDefault: function(){ prevented++; } }, inp3),
   'Enter zapisuje');
eq(prevented, 1, 'Enter nesmie odoslat formular');
eq(last().value, 200);

// Chip v stave `auto` zamkne AUTOMAT zo servera, `locked` odomkne LEN tuto os.
SENT.length = 0;
HW.onHwAxChip(chipOf(render(AUTO), 'box'));
eq(last().value, 360, 'klik na chip zamkne automat');
eq(last().field, 'box_height');
SENT.length = 0;
HW.onHwAxChip(chipOf(render(LOCKED), 'box'));
eq(last().value, null, 'odomknutie posiela `value: null`');
ok(!('reset' in last()), 'nikdy sa nezahadzuje CELY zaznam — druhy zamok zije');

// Chip pri PRAZDNOM rozsahu nema co zamknut.
SENT.length = 0;
STATUS.length = 0;
HW.onHwAxChip(chipOf(render(NORANGE), 'box'));
eq(SENT.length, 0, 'bez hodnoty sa nic neodosle');
eq(STATUS[STATUS.length - 1].msg, HW.HW_AX_NOVAL);

// ===========================================================================
// D) OBNOVA FOKUSU V KARTE CELA
// ===========================================================================

eq(C.frontCardFocusKey({ ax: 'box', axc: 'num' }), 'a:box|num',
   'pole je plnohodnotny ovladac osi');
eq(C.frontCardFocusSelector('a:box|num'), '[data-ax="box"][data-axc="num"]',
   'a po prekresleni karty sa najde presne ono');

console.log('D-128 UI: ' + n + ' assertov OK');
