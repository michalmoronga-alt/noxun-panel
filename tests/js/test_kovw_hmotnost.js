// Testy KOV-W / D-125 — riadok HMOTNOST v informacnom stlpci Zakladnych.
//   node tests/js/test_kovw_hmotnost.js
//
// Kontrakt, ktory sa tu strazi:
//   1) text riadku sklada CISTA funkcia z payloadu skrinky (panel nic nepocita —
//      sucet robi server `Bom.weight_totals`),
//   2) ODHAD sa prizna: znacka ≈ a tooltip, ktory povie kolko dielcov a akou
//      hustotou sa ratalo (rozhodnutie Michal 8.9.2026 — nikdy ticho),
//   3) skrinka bez vyrobnych dielcov = '—' (radsej pomlcka nez vymyslene cislo),
//   4) cislo je po slovensky (desatinna CIARKA, jedno desatinne miesto),
//   5) riadok ma v HTML vlastne `id` na oboch urovniach (hodnota + tooltip),
//      inak by ho most nemal kam zapisat,
//   6) vo VKLADANI sa riadok vynuluje — nesmie drzat cislo predtym oznacenej
//      skrinky,
//   7) CELY TOK payload -> riadok: `setCabInfo` sa cita PRIAMO z `bridge.js`
//      (Sol audit 5 — formatovac sam by neodhalil, ze most riadok neplni) a
//      spusta sa nad mini-DOM; `setCabInfo(null)` = reset na '—', inak by riadok
//      ukazoval hmotnost PREDTYM oznacenej skrinky.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

const ROOT = path.join(__dirname, '..', '..');
const UI = path.join(ROOT, 'noxun_engine', 'ui');
const { nxCabWeight, NX_WEIGHT_TITLE, nxCabInfo } = require(path.join(UI, 'js', 'core.js'));

const PANEL_HTML = fs.readFileSync(path.join(UI, 'panel.html'), 'utf8');
const BRIDGE_SRC = fs.readFileSync(path.join(UI, 'js', 'bridge.js'), 'utf8');
const FORM_SRC = fs.readFileSync(path.join(UI, 'js', 'form.js'), 'utf8');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) PRESNE cislo ---------------------------------------------------------

eq(nxCabWeight({ weight_kg: 12.44, weight_estimated_parts: 0, weight_estimated_density: null }),
   { text: '12,4 kg', title: NX_WEIGHT_TITLE, estimated: false },
   'zname hustoty = presne cislo bez znacky');
eq(nxCabWeight({ weight_kg: 12.45, weight_estimated_parts: 0 }).text, '12,5 kg',
   'zaokruhluje sa na jedno desatinne miesto');
eq(nxCabWeight({ weight_kg: 12, weight_estimated_parts: 0 }).text, '12 kg',
   'cele cislo ostava bez desatinnej casti (vzor mmLabel)');
ok(nxCabWeight({ weight_kg: 12.4, weight_estimated_parts: 0 }).text.indexOf('.') === -1,
   'ziadna desatinna BODKA — panel je po slovensky');

// --- 2) ODHAD sa prizna ------------------------------------------------------

const est = nxCabWeight({ weight_kg: 12.44, weight_estimated_parts: 3, weight_estimated_density: 870 });
eq(est.text, '≈ 12,4 kg', 'odhad nesie znacku ≈');
eq(est.estimated, true, 'volajuci sa vie spytat, ci je to odhad');
ok(est.title.indexOf('3 dielce') !== -1, `tooltip povie POCET dielcov: ${est.title}`);
ok(est.title.indexOf('870') !== -1, `tooltip povie HUSTOTU: ${est.title}`);
ok(est.title.indexOf('ťažšia') !== -1, `tooltip povie, ze sa ratalo tazsie: ${est.title}`);
ok(est.title !== NX_WEIGHT_TITLE, 'odhad ma VLASTNY tooltip, nie vseobecny');

// Slovenske sklonovanie — 1 dielec / 2-4 dielce / 5+ dielcov.
ok(nxCabWeight({ weight_kg: 5, weight_estimated_parts: 1, weight_estimated_density: 870 })
     .title.indexOf('1 dielec ') !== -1, '1 dielec');
ok(nxCabWeight({ weight_kg: 5, weight_estimated_parts: 4, weight_estimated_density: 870 })
     .title.indexOf('4 dielce ') !== -1, '4 dielce');
ok(nxCabWeight({ weight_kg: 5, weight_estimated_parts: 9, weight_estimated_density: 870 })
     .title.indexOf('9 dielcov ') !== -1, '9 dielcov');

// Chybajuca hustota v payloade tooltip NEROZBIJE (len ju nespomenie).
const noDens = nxCabWeight({ weight_kg: 5, weight_estimated_parts: 2 });
eq(noDens.text, '≈ 5 kg', 'odhad ostava odhadom aj bez cisla hustoty');
ok(noDens.title.indexOf('NaN') === -1, 'ziadne NaN v tooltipe');

// --- 3) PRAZDNE stavy = pomlcka ---------------------------------------------

[[null, 'bez skrinky'], [{}, 'payload bez hmotnosti'],
 [{ weight_kg: 0, weight_estimated_parts: 0 }, 'skrinka bez vyrobnych dielcov'],
 [{ weight_kg: 'x' }, 'poskodena hodnota']].forEach(function(c){
  eq(nxCabWeight(c[0]), { text: '—', title: NX_WEIGHT_TITLE, estimated: false }, c[1]);
});

// --- 4) HTML + zapisove cesty ------------------------------------------------

ok(/id="infWeight"[^>]*><span>Hmotnosť<\/span><b id="inf_weight">/.test(PANEL_HTML),
   'riadok ma id na oboch urovniach (tooltip aj hodnota)');
ok(PANEL_HTML.indexOf('Hmotnosť príde s kovaním') === -1,
   'stary placeholder tooltip zmizol (D-125)');
ok(PANEL_HTML.indexOf('id="infWeight" onclick') === -1, 'riadok NIE JE klikatelny');

ok(/nxCabWeight\(c\)/.test(BRIDGE_SRC) && /setOut\('inf_weight'/.test(BRIDGE_SRC),
   'most zapisuje hodnotu z cistej funkcie');
ok(/el\('infWeight'\)/.test(BRIDGE_SRC), 'most nastavuje aj tooltip riadku');
ok(/setOut\('inf_weight', '—'\)/.test(FORM_SRC),
   'vo VKLADANI sa riadok vynuluje — nesmie drzat cislo predtym oznacenej skrinky');

// --- 5) TOK payload -> riadok (Sol audit 5) ---------------------------------
// `setCabInfo` sa NEKOPIRUJE — cita sa PRIAMO z bridge.js a spusta v sandboxe s
// podstrcenymi zavislostami (vzor test_nastroje1_flush.js). Zrkadlo funkcie by
// mohlo od zdroja odbehnut a prave tento nalez (most riadok nepln) by unikol.
const SET_CAB_INFO = (function(){
  const m = BRIDGE_SRC.match(/function setCabInfo\(c\)\{[\s\S]*?\n  \}/);
  assert.ok(m, 'setCabInfo sa v bridge.js nenasla');
  return m[0];
})();

function mkNode(){ return { textContent: '', title: '', _attrs: {},
                            setAttribute(k, v){ this._attrs[k] = String(v); } }; }

function runSetCabInfo(payload){
  // Mini-DOM: len uzly, ktore riadok informacneho stlpca potrebuje.
  const nodes = { inf_parts: mkNode(), inf_area: mkNode(), inf_weight: mkNode(),
                  infParts: mkNode(), infArea: mkNode(), infWeight: mkNode() };
  const deps = {
    el: function(id){ return nodes[id] || null; },
    // presna kopia `setOut` z core.js (prazdna hodnota = pomlcka)
    setOut: function(id, v){
      const e = nodes[id]; if (!e) return;
      e.textContent = (v === null || v === undefined || v === '') ? '—' : String(v);
    },
    nxCabInfo: nxCabInfo,     // realna funkcia z core.js
    nxCabWeight: nxCabWeight  // realna funkcia z core.js
  };
  const factory = new Function('deps', `
    var el = deps.el, setOut = deps.setOut,
        nxCabInfo = deps.nxCabInfo, nxCabWeight = deps.nxCabWeight;
    ${SET_CAB_INFO}
    return setCabInfo;
  `);
  factory(deps)(payload);
  return nodes;
}

let dom = runSetCabInfo({ cabinet_id: 'CAB-001', parts_count: 7, parts_area_m2: 3.2,
                          weight_kg: 12.44, weight_estimated_parts: 0,
                          weight_estimated_density: null });
eq(dom.inf_weight.textContent, '12,4 kg', 'payload oznacenej skrinky sa NAOZAJ dostane do riadku');
eq(dom.infWeight.title, NX_WEIGHT_TITLE, 'riadok dostane aj vseobecny tooltip');
eq(dom.inf_parts.textContent, '7', 'ostatne riadky stlpca ostavaju nedotknute');

dom = runSetCabInfo({ cabinet_id: 'CAB-002', parts_count: 5, parts_area_m2: 2.0,
                      weight_kg: 9.06, weight_estimated_parts: 3,
                      weight_estimated_density: 870 });
eq(dom.inf_weight.textContent, '≈ 9,1 kg', 'odhad ide do riadku aj so znackou ≈');
ok(dom.infWeight.title.indexOf('3 dielce') !== -1,
   `tooltip riadku vysvetli odhad: ${dom.infWeight.title}`);

// RESET: preklik na dosku / prazdny vyber (`setCabInfo(null)`) — bez neho by
// riadok drzal hmotnost predtym oznacenej skrinky.
dom = runSetCabInfo(null);
eq(dom.inf_weight.textContent, '—', 'bez skrinky je riadok prazdny');
eq(dom.infWeight.title, NX_WEIGHT_TITLE, 'a tooltip sa vrati na vseobecny text');
eq(dom.infParts._attrs['aria-disabled'], 'true', 'klikatelne riadky su neaktivne (vzor UI-B3)');

console.log(`OK ${n} kontrol (KOV-W hmotnost)`);
