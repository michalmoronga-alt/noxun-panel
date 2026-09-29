// NP-4 (blok 2 · Nárezový plán) — CENY PODĽA PLÁNU v sekcii Rozpočet.
//
// Čo sa tu dokazuje (package PACKAGE_NP4_CENY.md §4 bod 4 + audit B1):
//   1. prepínač „ceny podľa plánu" je v HLAVIČKE sekcie Materiál (vzor
//      „sčítať do rozpočtu"), stav berie z payloadu a patrí medzi ovládače,
//      ktoré R-14 vypína,
//   2. zmena prepínača pošle JEDNU mutáciu `plan_prices {enabled}`,
//   3. značka „podľa plánu" / „z odhadu" je v bunke množstva LEN pri
//      zapnutom prepínači (riadok nesie `qty_source`); vypnutý = bez značiek,
//   4. tooltip `?` nesie vetu z mockupu (VEPO celé tabule, Späť → Obnoviť),
//   5. AUDIT B1: čakajúca mutácia nesie identitu dokumentu a `gen` z okamihu
//      kliknutia — po prepnutí dokumentu sa do nového NIKDY neodošle.
//
// Render beží v JEDNOM scope (studio.js + budget.js cez `vm`), vzor
// test_r14_budget_std.js.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));

let n = 0;
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS_DIR = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel'].forEach(function(id){
  const el = mkEl('div');
  el.attrs.id = id;
  DOC.body.appendChild(el);
});

const SENT = [];
const sketchup = new Proxy({}, {
  get: function(_t, name){
    return function(json){ SENT.push([String(name), JSON.parse(json)]); };
  },
  has: function(){ return true; }
});

// Časovače sa nespúšťajú (poistný timer fronty by inak držal proces 6 s).
const sandbox = {
  console: console, document: DOC,
  setTimeout: function(){ return 1; }, clearTimeout: function(){},
  localStorage: { getItem(){ return null; }, setItem(){} },
  sketchup: sketchup, module: undefined,
  NXEdgeMenu: { num(v){ return Number(v) || 0; }, menuHtml(){ return ''; },
                selectionHint(){ return ''; }, optionPayload(p){ return p; } }
};
sandbox.window = sandbox;
vm.createContext(sandbox);
['studio.js', 'budget.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(JS_DIR, f), 'utf8'), sandbox, { filename: f });
});
const STATUS = [];
sandbox.NX.setStatus = function(text, isErr){ STATUS.push([String(text), !!isErr]); };

const OKSTD = { state: 'current', blocked: false, reason: '' };
const NEWSTD = { state: 'newer', blocked: true, reason: 'Rozpočet zákazky je z novšej verzie Noxun — aktualizuj plugin.' };

function matRow(over){
  return Object.assign({ key: 'material:H18', nazov: 'H1181 DTDL 18 mm', mnozstvo: 5, mj: 'PLATŇA',
                         cena_mj: 211.55, spolu: 1057.75, material_id: 'H18',
                         poznamka: '14,72 m² · plán: 5 platní (horná hranica)' }, over || {});
}

function budgetPayload(opts){
  const o = opts || {};
  return {
    mode: 'standard', mode_label: '€€', vat_divisor: 1.23,
    budget_std: o.std || OKSTD, plan_prices: o.on === true,
    totals: { total: 2000, total_novat: 1626.02, rounding: 0, appliances_subtotal: 0,
              appliances_included: false, unknown_count_in_total: 0 },
    stale: { stale_days: 30, counts: {}, items: [] },
    budget_check: [],
    sections: [
      { key: 'materials', name: 'Materiál', subtotal: 1500, rows: o.rows || [matRow()] },
      { key: 'services', name: 'Služby', subtotal: 300,
        rows: [{ key: 'service:porez', nazov: 'Porez platní', mnozstvo: 10, mj: 'PLATŇA',
                 cena_mj: 17, spolu: 170, zdroj: 'auto',
                 poznamka: o.on ? 'platne z Materiálu (1 podľa plánu, 1 z odhadu)' : null }] },
      { key: 'rounding', name: 'Zaokrúhlenie', subtotal: 0, rows: [{ poznamka: 'nahor' }] }
    ],
    cp_preview: null
  };
}

function push(opts){
  const o = opts || {};
  sandbox.NX.setStudio({
    version: '0.0.0', gen: o.gen || 3, model_title: 'T', model_guid: o.guid || 'GA',
    rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
    summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
    vepo: { project: 'p', default_project: 'p', merge_18_36: true },
    control: [], counts: { red: 0, orange: 0, clean: 1, cabinets: 1 },
    edge_check: null, grain_check: null, open_section: 'budget', anchor: null,
    budget: budgetPayload(o)
  });
}

function body(){ return DOC.getElementById('secbody').innerHTML; }
function box(){ return DOC.querySelector('[data-bud="plan_prices"]'); }
function mutations(){ return SENT.filter(function(s){ return s[0] === 'budget_mutate'; }).map(function(s){ return s[1]; }); }

// ============================ 1. PREPÍNAČ V HLAVIČKE =========================

push({ on: false });
let h = body();
const matSummary = h.slice(h.indexOf('data-section="materials"'), h.indexOf('</summary>', h.indexOf('data-section="materials"')));
ok(matSummary.indexOf('data-bud="plan_prices"') > -1, 'prepínač je v <summary> sekcie Materiál');
ok(matSummary.indexOf('ceny podľa plánu') > -1, 'a má text z mockupu');
ok(matSummary.indexOf('class="bappl" onclick="event.stopPropagation()"') > -1,
   'vzor „sčítať do rozpočtu": klik na prepínač nezbalí sekciu');
ok(h.split('data-bud="plan_prices"').length - 1 === 1, 'prepínač je v tele PRÁVE raz');
ok(!!box() && box().checked === false, 'vypnutý stav z payloadu = neoznačený');
ok(h.indexOf('class="qtag') < 0, 'VYPNUTÝ prepínač: ŽIADNA značka v bunke množstva');
push({ on: true, rows: [matRow({ qty_source: 'plan', estimate_qty: 4, qty_tip: 'Množstvo z nárezového plánu (horná hranica).' })] });
ok(box().checked === true, 'zapnutý stav z payloadu = označený');
ok(sandbox.BUD_STD_OFF.plan_prices === 1, 'prepínač patrí medzi ovládače, ktoré R-14 vypína');

// tooltip `?` — veta z mockupu + audit F5, nezbalí sekciu
const tipAt = body().indexOf('class="nxtip"');
ok(tipAt > -1 && tipAt < body().indexOf('</summary>'), 'tooltip „?" je v hlavičke sekcie');
const tipTag = body().slice(tipAt, body().indexOf('>', tipAt));
ok(tipTag.indexOf('VEPO účtuje celé tabule') > -1, 'tooltip hovorí, že VEPO účtuje celé tabule');
ok(tipTag.indexOf('počet sa môže líšiť') > -1, 'a že počet VEPO sa môže líšiť');
ok(tipTag.indexOf('montáž ostáva z odhadu') > -1, 'porez za platňami, montáž z odhadu');
ok(tipTag.indexOf('Po Späť klikni na Obnoviť') > -1, 'audit F5: Späť → Obnoviť');
ok(tipTag.indexOf('onclick="event.stopPropagation();event.preventDefault()"') > -1,
   'klik na „?" v <summary> sekciu nezbalí ani neprepne');

// ============================ 2. ZNAČKY MNOŽSTVA =============================

push({ on: true, rows: [
  matRow({ qty_source: 'plan', estimate_qty: 4, qty_tip: 'Množstvo z nárezového plánu (horná hranica).' }),
  matRow({ key: 'material:W18', material_id: 'W18', nazov: 'W1000', mnozstvo: 1, qty_source: 'estimate',
           estimate_qty: 1, qty_tip: 'Plán je neúplný "<b>". Množstvo a cena ostávajú z odhadu z m².' })
] });
h = body();
ok(h.indexOf('<span class="qtag plan" title="Množstvo z nárezového plánu (horná hranica).">podľa plánu</span>5') > -1,
   'riadok z plánu: značka „podľa plánu" pred množstvom');
ok(h.indexOf('<span class="qtag est" title="Plán je neúplný &quot;&lt;b&gt;&quot;. Množstvo a cena ostávajú z odhadu z m².">z odhadu</span>1') > -1,
   'riadok z odhadu: jantárová značka, serverový tooltip ESCAPOVANÝ');
ok(h.indexOf('"<b>"') < 0, 'surový text tooltipu sa do HTML nedostane');
// čistá funkcia značky
eq(sandbox.budQtyTagHtml({ mnozstvo: 3 }), '', 'riadok bez `qty_source` (vypnutý) = bez značky');
eq(sandbox.budQtyTagHtml({ qty_source: 'nieco' }), '', 'neznámy zdroj = bez značky');

// ============================ 3. ODOSLANIE =================================

SENT.length = 0;
push({ on: false });
box().checked = true;
dispatch(box(), 'change');
let muts = mutations();
eq(muts.length, 1, 'zmena prepínača = jedna mutácia');
eq(muts[0].op, 'plan_prices', 'op `plan_prices`');
eq(muts[0].enabled, true, 'enabled = stav checkboxu');
eq(muts[0].gen, 3, 'gen z payloadu');
eq(muts[0].model_guid, 'GA', 'identita dokumentu');

// R-14: nekompatibilná zákazka — prepínač je vypnutý a klik zo starého DOM nič nepošle
push({ std: NEWSTD });
ok(box().disabled === true, 'R-14: prepínač je vypnutý (disabled)');
SENT.length = 0;
STATUS.length = 0;
box().checked = true;
dispatch(box(), 'change');
eq(mutations(), [], 'R-14: klik zo zastaraného DOM sa neposiela');
ok(STATUS.length === 1 && STATUS[0][1] === true, 'a dôvod sa povie červeným statusom');

// ============================ 4. AUDIT B1 — FRONTA A DOKUMENT ==============

// Zákazka A: prvá mutácia beží (BUSY), druhá (plan_prices) čaká vo fronte.
SENT.length = 0;
push({ guid: 'GA', gen: 7 });            // čerstvý payload uvoľní predošlé BUSY
sandbox.budSend('mode', { mode: 'vysoky' });
box().checked = true;
dispatch(box(), 'change');
muts = mutations();
eq(muts.length, 1, 'druhý zápis čaká vo fronte (beží prvý)');
eq(muts[0].op, 'mode', 'odišiel len prvý');
// Príde payload INÉHO dokumentu B (prepnutý model, nová generácia).
push({ guid: 'GB', gen: 8 });
muts = mutations();
eq(muts.length, 1, 'B1: čakajúci `plan_prices` zo zákazky A sa do B NEODOŠLE');
ok(muts.every(function(m){ return m.model_guid !== 'GB'; }), 'žiadny zápis s identitou B');
// A späť — fronta ostala prázdna (zahodená, nie odložená)
push({ guid: 'GA', gen: 9 });
eq(mutations().length, 1, 'návrat na A nevzkriesi zahodený zápis');

// Rovnaký dokument: čakajúci zápis odíde s identitou a gen Z OKAMIHU KLIKNUTIA.
SENT.length = 0;
push({ guid: 'GA', gen: 11 });
sandbox.budSend('mode', { mode: 'nizky' });
box().checked = false;
dispatch(box(), 'change');
push({ guid: 'GA', gen: 11 });           // push po mutácii rozpočtu gen nedvíha
muts = mutations();
eq(muts.length, 2, 'po payloade TOHO ISTÉHO dokumentu odíde čakajúci zápis');
eq([muts[1].op, muts[1].enabled, muts[1].model_guid, muts[1].gen], ['plan_prices', false, 'GA', 11],
   'identita a gen z okamihu kliknutia');

// Model sa medzitým zmenil (gen sa zdvihla): zápis odíde so STAROU gen -> server ho odmietne.
SENT.length = 0;
push({ guid: 'GA', gen: 12 });
sandbox.budSend('mode', { mode: 'standard' });
box().checked = true;
dispatch(box(), 'change');
push({ guid: 'GA', gen: 13 });
muts = mutations();
eq(muts.length, 2, 'zápis rovnakého dokumentu sa odošle');
eq(muts[1].gen, 12, 'so STAROU gen — server ho odmietne ako zastaraný (nie tichý zápis nad novým stavom)');

// Poistka bez nového payloadu (poistný timer): cudzí zápis sa zahodí aj v `budAfterPush`.
SENT.length = 0;
push({ guid: 'GA', gen: 14 });
sandbox.budSend('mode', { mode: 'vysoky' });
sandbox.budSend('plan_prices', { enabled: true }, { doc: 'GX', gen: 14 }); // simulovaná cudzia položka
sandbox.budAfterPush();
eq(mutations().length, 1, 'položka iného dokumentu z fronty neodíde ani cez poistný timer');

// ============================ 5. ZDROJ (guard) ==============================

const SRC = fs.readFileSync(path.join(JS_DIR, 'budget.js'), 'utf8');
ok(SRC.indexOf("budSend('plan_prices', { enabled: t.checked === true })") > -1, 'jediná cesta odoslania prepínača');
ok(/BUD_QUEUE\.push\(\{ op: op, extra: extra, doc: doc, gen: gen \}\)/.test(SRC), 'fronta nesie doc aj gen');

console.log('test_np4_ceny.js: ' + n + ' OK');
