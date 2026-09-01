// 1d/R-14 — NEKOMPATIBILNE DATA ROZPOCTU v oknách Rozpočet a Cenová ponuka.
//
// Zákazka uložená NOVŠÍM pluginom (alebo s poškodeným markerom `budget_std`)
// sa dá čítať, ale čísla sú počítané z OREZANÉHO stavu. Klient preto musí:
//   1. povedať DÔVOD trvalým bannerom v OBOCH sekciách (status by zmizol pri
//      prvom prekreslení — a payload chodí po každom kliku),
//   2. VYPNÚŤ všetky ovládače, ktoré menia zákazku alebo vyrábajú CENOVÝ
//      dokument — vrátane prepínača „samostatne" (`cp_sep`) v Cenovej ponuke,
//   3. NEPOSLAŤ nič ani vtedy, keď klik príde zo zastaraného DOM (server ho
//      odmietne tak či tak — okno o tom nesmie mlčať).
// Prepínač DPH, „Obnoviť" a „Prepočítať ceny" ostávajú ZÁMERNE aktívne:
// prvé dva sú číre zobrazenie, tretí zapisuje do KATALÓGU cien, nie do zákazky.
//
// Render beží v JEDNOM scope (studio.js + budget.js cez `vm`, presne ako
// v prehliadači) nad mini-DOM, ktorý HTML naozaj parsuje — inak by sa
// „ovládač je vypnutý" overiť nedalo.
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

const sandbox = {
  console: console, document: DOC, setTimeout: setTimeout, clearTimeout: clearTimeout,
  localStorage: { getItem(){ return null; }, setItem(){} },
  sketchup: sketchup, module: undefined,
  NXEdgeMenu: { num(v){ return Number(v) || 0; }, menuHtml(){ return ''; },
                selectionHint(){ return ''; }, optionPayload(p){ return p; } }
};
sandbox.window = sandbox;
vm.createContext(sandbox);

// PORADIE JE SUCASTOU KONTRAKTU — presne tak, ako ich nacitava studio.html.
['studio.js', 'budget.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(JS_DIR, f), 'utf8'), sandbox, { filename: f });
});

// Statusy sa zbieraju — okno musi dovod POVEDAT, nie len prestat reagovat.
const STATUS = [];
sandbox.NX.setStatus = function(text, isErr){ STATUS.push([String(text), !!isErr]); };

const NEWER = 'Rozpočet zákazky je z novšej verzie Noxun — úprava by dáta orezala; aktualizuj plugin.';
const BROKEN = 'Dáta rozpočtu sú poškodené (neplatná verzia formátu) — nahlás problém, needituj.';

function budgetPayload(std){
  return {
    mode: 'standard', mode_label: '€€', vat_divisor: 1.23,
    budget_std: std,
    totals: { total: 1234.5, total_novat: 1003.66, rounding: 5.5,
              appliances_subtotal: 649, appliances_included: false,
              unknown_count_in_total: 0 },
    stale: { stale_days: 30, counts: {}, items: [] },
    budget_check: [],
    sections: [
      { key: 'materials', name: 'Materiál', subtotal: 500,
        rows: [{ nazov: 'H3303', mnozstvo: 3, mj: 'm²', cena_mj: 20, spolu: 60, material_id: 'S1' }] },
      { key: 'services', name: 'Služby', subtotal: 300,
        rows: [{ key: 'service:montaz', nazov: 'Montáž', mnozstvo: 4, mj: 'h',
                 cena_mj: 25, spolu: 100, zdroj: 'auto' }] },
      { key: 'standard_rows', name: 'Štandardné riadky', subtotal: 200,
        rows: [{ key: 'std:doprava', nazov: 'Doprava', kind: 'flat', multiplier: 1,
                 rate: 50, spolu: 50 }] },
      { key: 'custom', name: 'Vlastné položky', subtotal: 100,
        rows: [{ id: 'c1', nazov: 'Likvidácia', mnozstvo: 1, cena_mj: 100, spolu: 100 }] },
      { key: 'appliances', name: 'Spotrebiče', subtotal: 649, counts_in_total: false,
        included: false,
        rows: [{ id: 'a1', typ: 'umyvacka', nazov: 'Bosch', dodavatel: 'X',
                 cena_mj: 649, spolu: 649 }] },
      { key: 'rounding', name: 'Zaokrúhlenie', subtotal: 5.5, rows: [{ poznamka: 'nahor' }] }
    ],
    cp_preview: { consistent: true, complete: true, threshold: 300, total: 1234.5,
                  total_label: 'SPOLU',
                  rows: [{ polozka: 'Nábytková zostava', cena: 1234.5, mnozstvo: 1,
                           mj: 'ks', kind: 'assembly' }],
                  candidates: [{ source_key: 'material:S1', label: 'Doska', amount: 500,
                                 state: 'zostava' }] }
  };
}

function push(std, section){
  SENT.length = 0;
  STATUS.length = 0;
  sandbox.NX.setStudio({
    version: '0.0.0', gen: 3, model_title: 'T', model_guid: 'G',
    rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
    summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
    vepo: { project: 'p', default_project: 'p', merge_18_36: true },
    control: [], counts: { red: 0, orange: 0, clean: 1, cabinets: 1 },
    edge_check: null, grain_check: null, open_section: section || 'budget', anchor: null,
    budget: budgetPayload(std)
  });
}

const OKSTD = { state: 'current', blocked: false, reason: '' };
const NEWSTD = { state: 'newer', blocked: true, reason: NEWER };
const BADSTD = { state: 'invalid', blocked: true, reason: BROKEN };

function nodes(){
  return DOC.querySelectorAll('[data-bud]');
}

function actionState(){
  const out = {};
  nodes().forEach(function(el){
    const a = el.getAttribute('data-bud');
    if (out[a] === undefined) out[a] = true;
    out[a] = out[a] && el.disabled === true;
  });
  return out;
}

// ============================ 1. KOMPATIBILNA ZAKAZKA =======================

push(OKSTD, 'budget');
ok(DOC.getElementById('secbody').innerHTML.indexOf('hwbanner') === -1,
   'kompatibilna zakazka NEMA banner (brana nemeri prazdno)');
const okState = actionState();
Object.keys(sandbox.BUD_STD_OFF || {}).forEach(function(a){
  if (okState[a] === undefined) return;
  ok(okState[a] === false, 'kompatibilna zakazka: ovladac ' + a + ' je AKTIVNY');
});

// ============================ 2. NOVSIA ZAKAZKA — ROZPOCET ==================

push(NEWSTD, 'budget');
const body = DOC.getElementById('secbody').innerHTML;
const tools = DOC.getElementById('sectools').innerHTML;
ok(body.indexOf('hwbanner') > -1, 'banner je v tele sekcie Rozpocet');
ok(body.indexOf(NEWER) > -1, 'a nesie PRESNU hlasku zo servera');
ok(body.indexOf('orezaných dát') > -1, 'banner povie aj dosledok pre cisla pod nim');
ok(body.indexOf('class="btotal"') > -1, 'sumy sa dalej ZOBRAZUJU (citanie sa neblokuje)');
ok(tools.indexOf('data-bud="xlsx"') > -1, 'export z listy nezmizol (len sa vypne)');

const blocked = actionState();
['mode', 'xlsx', 'draft', 'remove', 'more', 'override', 'multiplier', 'appl_included',
 'custom_field', 'appl_field'].forEach(function(a){
  if (blocked[a] === undefined) return; // ovladac v tomto payloade nie je
  ok(blocked[a] === true, 'novsia zakazka: ovladac ' + a + ' je VYPNUTY');
});
ok(blocked.mode === true && blocked.xlsx === true,
   'rezim aj XLSX rozpocet su v tomto payloade a musia byt vypnute');
ok(blocked.vat === false, 'prepinac DPH ostava — je to cire ZOBRAZENIE');
ok(blocked.refresh === false, 'a „Prepočítať ceny" tiez (zapisuje do katalogu, nie do zakazky)');

// tooltip nesie dôvod — používateľ nemusí hádať, prečo je tlačidlo šedé
const modeBtn = DOC.querySelector('[data-bud="mode"]');
eq(modeBtn.getAttribute('title'), NEWER, 'vypnuty ovladac nesie dovod v tooltipe');

// ============================ 3. ODOSLANIE SA NEKONA ========================

dispatch(modeBtn, 'click');
eq(SENT, [], 'klik na vypnuty rezim NEPOSIELA nic');
eq(STATUS.length, 1, 'ale okno dovod POVIE');
eq(STATUS[0], [NEWER, true], 'cervenym statusom s presnou hlaskou');

STATUS.length = 0;
sandbox.budXlsx();
eq(SENT, [], 'ani XLSX rozpocet sa neposle');
eq(STATUS[0], [NEWER, true], 'a dovod je ten isty (jeden zdroj textu)');

STATUS.length = 0;
sandbox.budCpExport();
eq(SENT, [], 'ani zakaznicka cenova ponuka');
eq(STATUS[0], [NEWER, true], 'so zhodnou hlaskou');

// Inline zápis bunky (change na poli) ide tou istou cestou.
const ovr = DOC.querySelector('[data-bud="override"]');
ok(!!ovr, 'pole prepisu sumy v tele naozaj je');
STATUS.length = 0;
ovr.value = '150';
dispatch(ovr, 'change');
eq(SENT, [], 'inline prepis sumy sa tiez neposiela');
eq(STATUS[0], [NEWER, true], 'a povie dovod');

// ============================ 4. CENOVA PONUKA ==============================

push(NEWSTD, 'offer');
const offerBody = DOC.getElementById('secbody').innerHTML;
ok(offerBody.indexOf('hwbanner') > -1, 'banner je AJ v sekcii Cenova ponuka');
ok(offerBody.indexOf(NEWER) > -1, 'a je to ta ista hlaska');
const offer = actionState();
ok(offer.cp === true, 'export zakaznickeho dokumentu je vypnuty');
ok(offer.cp_sep === true,
   'a prepinac „samostatne" tiez — je to modelova mutacia (cp_group)');
ok(offer.to_budget === false || offer.to_budget === undefined,
   'preklik do Rozpoctu ostava — nic nemeni');

const sep = DOC.querySelector('[data-bud="cp_sep"]');
ok(!!sep, 'prepinac „samostatne" v ponuke naozaj existuje (inak by scenar nic nedokazoval)');
STATUS.length = 0;
SENT.length = 0;
sep.checked = true;
dispatch(sep, 'change');
eq(SENT, [], 'prepnutie zaradenia v ponuke sa neposiela');
eq(STATUS[0], [NEWER, true], 'a dovod sa povie');

// ============================ 5. POSKODENE DATA =============================

push(BADSTD, 'budget');
ok(DOC.getElementById('secbody').innerHTML.indexOf(BROKEN) > -1,
   'poskodene data maju VLASTNU hlasku (nie tu o novsej verzii)');
ok(actionState().mode === true, 'a ovladace su vypnute rovnako');

// ============================ 6. CISTE FUNKCIE ==============================

ok(sandbox.budStdBlocked({ budget_std: NEWSTD }) === true, 'blocked=true je blokovany stav');
ok(sandbox.budStdBlocked({ budget_std: OKSTD }) === false, 'blocked=false nie je');
ok(sandbox.budStdBlocked({}) === false, 'payload bez priznaku (starsi server) NIC nevypina');
ok(sandbox.budStdBlocked(null) === false, 'ani chybajuci rozpocet');
eq(sandbox.budStdReason({ budget_std: NEWSTD }), NEWER, 'dovod je SERVEROVY text');
ok(sandbox.budStdReason({ budget_std: { blocked: true, reason: '' } }).length > 10,
   'prazdny dovod ma nahradu — nikdy prazdny banner');
eq(sandbox.budStdReason({ budget_std: OKSTD }), '', 'kompatibilny stav dovod nema');
ok(sandbox.budStdBannerHtml({ budget_std: OKSTD }) === '', 'a ziadny banner');
ok(sandbox.budStdOff('xlsx', { budget_std: NEWSTD }) === true, 'export je v zozname vypnutych');
ok(sandbox.budStdOff('vat', { budget_std: NEWSTD }) === false, 'DPH nie');
ok(sandbox.budStdOff('xlsx', { budget_std: OKSTD }) === false,
   'a nad kompatibilnou zakazkou sa nevypina nic');

// Zoznam vypnutych akcii je KOMPLETNY voci mutaciam, ktore posiela klient:
// kazdy `budSend('<op>')` v budget.js musi mat svoj ovladac v BUD_STD_OFF.
const SRC = fs.readFileSync(path.join(JS_DIR, 'budget.js'), 'utf8');
['mode', 'override', 'multiplier', 'viz_m2', 'appl_included', 'cp_sep', 'custom_field',
 'appl_field', 'draft', 'remove', 'more', 'xlsx', 'cp'].forEach(function(a){
  ok(sandbox.BUD_STD_OFF[a] === 1, 'ovladac ' + a + ' patri medzi vypnute');
});
ok(SRC.indexOf('budStdDisable(box)') > -1, 'vypinanie bezi po kresleni (jeden prechod nad DOM)');
eq(SRC.split('budStdDisable(box);').length - 1, 4,
   'a vola sa vo VSETKYCH styroch kresliacich cestach (telo + lista, obe sekcie)');

console.log('test_r14_budget_std.js: ' + n + ' OK');
