// D-132 — RIADOK DORMANTNEHO ZAMKU v kontexte Kovanie (hardware.js).
//
// Preco su to testy a nie klikanie v paneli:
//   1. TEXTY SKLADA SERVER. Nadpis („Dormantný zámok · NL 470") aj dovod
//      („teraz je pripnutý Atira SiSy v1") prichadzaju hotove v payloade —
//      keby ich skladal JS, potreboval by vlastnu pravdu o tom, ktory recept
//      je pripnuty, a prave tej tichej zamene cely package KOV-D brani.
//   2. CESTA VON JE EXISTUJUCA. Tlacidlo „zrušiť" posiela `reset: true`
//      s adresou riadku — ta ista serverova akcia ako pri neplatnom zasahu,
//      teda jeden krok Spat.
//   3. OSTATNE DRUHY SA NESMU POHNUT. `invalid`, `disabled` a `part_material`
//      maju svoj markup uz z KOV-C2b — snapshot ho strazi bajt po bajte.
//   4. BEZ POZNAMKY SA POZNAMKA NEKRESLI. Payload bez `orphan_note` nesmie
//      vyrobit prazdny druhy riadok (vertikalny priestor panela je vzacny).
//
// MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
//   M5 `hwOffHtml` sklada text poznamky sam (ignoruje `orphan_note`)
//      -> „D-132: poznamka pod riadkom je PRESNE serverovy text"
//   M6 dormantny riadok dostane `onHwEnable` („obnoviť") namiesto resetu
//      -> „D-132: „zrušiť" posiela EXISTUJUCU akciu `reset: true`"
//   M7 `hwDisabledOffs` filtruje dormantny zaznam prec
//      -> „D-132: filter riadkov sa NEMENI — rozhoduje `orphan`"
// Slepy Opus review (P3-2):
//   M9 box so ZANIKNUTYM vlastnikom dostane oko `onHwOwnerPick`
//      -> „D-132 (P3-2): box zaniknuteho cela oko NEMA"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

global.esc = function(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
// Zhodne s `NXIcons.svg` v `icons.js` — `<use …/>` je SAMOUZATVARACI.
global.NXIcons = {
  svg: function(id, cls){
    return '<svg class="ic' + (cls ? ' ' + cls : '') + '" aria-hidden="true"><use href="#i-' + id + '"/></svg>';
  }
};

const HW = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hardware.js'));
const { hwOffHtml, hwOffLabel, hwOffName, hwDisabledOffs } = HW;

// Payload servera (`Panel.hardware_overrides_payload`) — kontrakt D-132.
const DORMANT = {
  owner_part_key: 'front:F1/panel', generic_type: 'slide',
  rule_id: 'recipe:atira_p2o_v1', orphan: true, orphan_kind: 'dormant',
  owner_label: 'F1 · zásuvkové čelo',
  orphan_label: 'Dormantný zámok · NL 470',
  orphan_note: 'Zámok receptu Atira Tip-On v1 — teraz je pripnutý Atira SiSy v1, ' +
               'takže neplatí a čaká. Zrušiť ho môžeš tu.'
};
const INVALID = {
  owner_part_key: 'front:F1/panel', generic_type: 'slide',
  rule_id: 'recipe:atira_sisy_v1', orphan: true, orphan_kind: 'invalid',
  owner_label: 'F1 · zásuvkové čelo'
};

// --- 1) riadok sa kresli v boxe VLASTNIKA s obsahom zo servera ---------------
const html = hwOffHtml(DORMANT, 'CAB-1', 'front:F1');
ok(html.indexOf('Dormantný zámok · NL 470') >= 0, 'nadpis riadku je serverovy `orphan_label`');
ok(html.indexOf('data-owner="front:F1/panel"') >= 0 &&
   html.indexOf('data-type="slide"') >= 0 &&
   html.indexOf('data-rule="recipe:atira_p2o_v1"') >= 0 &&
   html.indexOf('data-cab="CAB-1"') >= 0,
   'riadok nesie CELU adresu zapisu (owner + typ + pravidlo + skrinka)');
ok(html.indexOf('zásuvkové čelo') >= 0, 'v boxe cela ostava v riadku upresnenie vlastnika');
ok(html.indexOf('<use href="#i-lock"/>') >= 0, 'zatvoreny zamok zo sprite (ziadne emoji)');
eq(hwOffLabel(DORMANT), 'neplatí', 'kratka pripona stavu — dovod hovori poznamka');
eq(hwOffName(DORMANT), 'Dormantný zámok · NL 470', 'nazov berie server, nie mapa typov v JS');

// M5
ok(html.indexOf('<div class="axnote">Zámok receptu Atira Tip-On v1 — teraz je pripnutý ' +
                'Atira SiSy v1, takže neplatí a čaká. Zrušiť ho môžeš tu.</div>') >= 0,
   'D-132: poznamka pod riadkom je PRESNE serverovy text');
ok(html.indexOf('<div class="hwitem">') === 0 && html.indexOf('</div></div>') > 0,
   'riadok + poznamka su v jednom obale `.hwitem` (odstupy ako pri chipoch)');

// M6
ok(html.indexOf('onclick="onHwOrphanReset(this)"') >= 0 &&
   html.indexOf('onHwEnable') < 0,
   'D-132: „zrušiť" posiela EXISTUJUCU akciu `reset: true`');
ok(html.indexOf('> zrušiť</button>') >= 0, 'tlacidlo je „zrušiť", nie „obnoviť"');

// --- 2) bez poznamky ziadny druhy riadok (vertikalny priestor) ---------------
const bare = hwOffHtml({ owner_part_key: 'front:F1/panel', generic_type: 'slide',
                         rule_id: 'recipe:atira_p2o_v1', orphan: true,
                         orphan_kind: 'dormant', orphan_label: 'Dormantný zámok · H144' },
                       'CAB-1', 'front:F1');
ok(bare.indexOf('axnote') < 0, 'payload bez `orphan_note` poznamku NEKRESLI');
ok(bare.indexOf('hwitem') < 0, 'a ani prazdny obal — riadok ostava JEDEN');
ok(bare.indexOf('Dormantný zámok · H144') >= 0, 'nadpis ostava');

// --- 3) ostatne druhy sa nepohli (snapshot KOV-C2b) -------------------------
const inv = hwOffHtml(INVALID, 'CAB-1', 'front:F1');
eq(inv,
   '<div class="hwrow hwoff" data-owner="front:F1/panel" data-type="slide" ' +
   'data-rule="recipe:atira_sisy_v1" data-part="" data-cab="CAB-1">' +
   '<span class="hwname" title="Výsuv · F1 · zásuvkové čelo · neplatný ručný zásah">' +
   'Výsuv <span class="hwown">zásuvkové čelo</span> ' +
   '<span class="hwext">neplatný ručný zásah</span></span>' +
   '<button class="ghostbtn hwbtn" title="Zrušiť ručný zásah (obnoví sa výpočet)" ' +
   'onclick="onHwOrphanReset(this)"><svg class="ic" aria-hidden="true">' +
   '<use href="#i-rotate-ccw"/></svg> zrušiť</button></div>',
   'riadok `invalid` je bajtovo ten isty ako pred D-132');
eq(hwOffLabel({ orphan_kind: 'invalid' }), 'neplatný ručný zásah', 'popis `invalid` sa nemeni');
eq(hwOffLabel({ orphan_kind: 'disabled' }), 'vypnuté', 'popis `disabled` sa nemeni');
eq(hwOffLabel({ orphan_kind: 'part_material' }), 'neplatný ručný materiál',
   'popis materialoveho zaznamu sa nemeni');

// --- 4) filter riadkov sa nemeni (M7) ---------------------------------------
const OFFS = hwDisabledOffs([], [DORMANT, INVALID,
                                 { owner_part_key: '', generic_type: 'leg', rule_id: 'nohy',
                                   disabled: true, orphan: false }]);
eq(OFFS.length, 2, 'D-132: filter riadkov sa NEMENI — rozhoduje `orphan`');
eq(OFFS[0].orphan_kind, 'dormant', 'dormantny zaznam medzi osirotenymi JE');

// --- 5) P3-2: box ZANIKNUTEHO vlastnika nema co oznacit v modeli -------------
const { hwGroups, hwBoxGone, hwBoxHtml } = HW;
const GONE = {
  owner_part_key: 'front:F9/panel', generic_type: 'slide',
  rule_id: 'recipe:atira_p2o_v1', orphan: true, orphan_kind: 'dormant',
  orphan_owner_gone: true, owner_label: '(už neexistuje) · pôvodné zásuvkové čelo',
  orphan_label: 'Dormantný zámok · NL 470',
  orphan_note: 'Zámok receptu Atira Tip-On v1 — čelo, ktorému patril, už neexistuje. Zrušiť ho môžeš tu.'
};

eq(hwBoxGone({ items: [], offs: [GONE] }), true, 'box so samymi zaniknutymi riadkami');
eq(hwBoxGone({ items: [], offs: [GONE, DORMANT] }), false,
   'staci JEDEN riadok zijuceho vlastnika a oko sa kresli');
eq(hwBoxGone({ items: [{ owner_part_key: 'front:F9/panel' }], offs: [GONE] }), false,
   'ziva polozka = vlastnik existuje');
eq(hwBoxGone({ items: [], offs: [] }), false, 'prazdny box nie je „zaniknuty"');

// M9
const goneBox = hwBoxHtml(hwGroups([], [GONE], ['F1'], 'CAB-1')[0], 'CAB-1');
ok(goneBox.indexOf('onHwOwnerPick') < 0 && goneBox.indexOf('#i-eye') < 0,
   'D-132 (P3-2): box zaniknuteho cela oko NEMA');
ok(goneBox.indexOf('<div class="hwboxh hwboxh-static"') >= 0,
   'hlavicka je staticka (nie tlacidlo)');
ok(goneBox.indexOf('Čelo (už neexistuje)') >= 0,
   'a nemenuje cislo F#, ktore uz nic neznamena');
ok(goneBox.indexOf('</span></div><div class="hwboxb">') >= 0,
   'telo boxu ostava SURODENCOM hlavicky (UI-C4 invariant)');

const liveBox = hwBoxHtml(hwGroups([], [DORMANT], ['F1'], 'CAB-1')[0], 'CAB-1');
ok(liveBox.indexOf('onclick="onHwOwnerPick(this)"') >= 0 && liveBox.indexOf('#i-eye') >= 0,
   'box ZIVEHO cela oko naďalej ma (dormantny zamok nie je dovod ho brat)');

console.log(`OK test_d132_ui.js (${n} kontrol)`);
