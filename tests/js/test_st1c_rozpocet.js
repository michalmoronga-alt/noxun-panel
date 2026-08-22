// ŠT-1c PR B1 — sekcia ROZPOČET v okne ŠTÚDIO: RENDER V JEDNOM SCOPE.
//
// Preco takto a nie `require`: v prehliadaci su `studio.js` a `budget.js` DVA
// klasicke skripty v JEDNOM globalnom scope — budget.js cita globalny payload
// `ST` a OBALUJE `NX.setStudio`, ktore studio.js priraduje ako CELY objekt.
// `require` by kazdy subor izoloval a presne tento vztah by NEOVERIL. Preto sa
// oba spustaju cez `vm` v spolocnom kontexte nad minimalnym DOM stubom.
//
// Co to chyta (a ziadna ina sada to nechyti):
//   1. KOLIZIU GLOBALNYCH MIEN — oba subory maju vlastny `renderBody`/`el`,
//      takze zle pomenovana funkcia by ticho prepisala tu druhu,
//   2. PORADIE SKRIPTOV — keby sa budget.js nacital skor, `window.NX = {…}`
//      zo studio.js by prepisal jeho obal a rozpocet by po prvom zapise zamrzol
//      na „cakam na odpoved" (fronta by sa nemala kde uvolnit),
//   3. PAD PRI RENDERI sekcie nad realnym tvarom payloadu.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const JS_DIR = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
let n = 0;
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- minimalny DOM stub (len to, co render sekcie naozaj pouziva) ------------
function mkEl(id){
  return {
    id: id, innerHTML: '', textContent: '', className: '', value: '', style: {},
    classList: { toggle(){}, add(){}, remove(){}, contains(){ return false; } },
    getAttribute(){ return null; }, setAttribute(){}, hasAttribute(){ return false; },
    querySelectorAll(){ return []; }, appendChild(){}, focus(){}, scrollIntoView(){}
  };
}
const els = {};
['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel'].forEach(function(id){
  els[id] = mkEl(id);
});
const doc = {
  addEventListener(){}, querySelector(){ return null; }, querySelectorAll(){ return []; },
  getElementById(id){ return els[id] || null; },
  createElement(){ return mkEl('tmp'); }, body: { appendChild(){} }, activeElement: null
};

const sandbox = {
  console: console, document: doc, setTimeout: setTimeout, clearTimeout: clearTimeout,
  localStorage: { getItem(){ return null; }, setItem(){} },
  module: undefined,
  // Zdielany komponent 3-stavoveho nastavenia hran (v okne ho nacita
  // edge_menu.js) — sekcia Rozpocet ho nepouziva, lista Kontroly ano.
  NXEdgeMenu: { num(v){ return Number(v) || 0; }, menuHtml(){ return ''; },
                selectionHint(){ return ''; }, optionPayload(p){ return p; } }
};
sandbox.window = sandbox;
vm.createContext(sandbox);

// PORADIE JE SUCASTOU TESTU — presne tak, ako ich nacitava studio.html.
['studio.js', 'budget.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(JS_DIR, f), 'utf8'), sandbox, { filename: f });
});

ok(typeof sandbox.NX.setStudio === 'function', 'okno ma prijimac payloadu');
ok(typeof sandbox.NX.budgetResult === 'function',
   'obal budget.js bezal — inak by sa odmietnuty zapis nemal ako dozvediet o drafte');
ok(typeof sandbox.NX.priceRefresh === 'function', 'a fazove okno prepoctu cien tiez');
ok(typeof sandbox.studioGoSection === 'function',
   'prepnutie sekcie je globalne — vola ho aj budget.js (chip suctu -> Kontrola)');

// --- realny tvar payloadu (skratene, ale so VSETKYMI sekciami) --------------
const PAYLOAD = {
  version: '0.0.0', gen: 3, model_title: 'T', model_guid: 'G',
  rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
  summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
  vepo: { project: 'p', default_project: 'p', merge_18_36: true },
  control: [], counts: { red: 0, orange: 1, clean: 1, cabinets: 1 },
  edge_check: null, grain_check: null, open_section: 'budget', anchor: null,
  budget: {
    mode: 'standard', mode_label: '€€', vat_divisor: 1.23,
    totals: { total: 1234.5, total_novat: 1003.66, rounding: 5.5,
              appliances_subtotal: 649, appliances_included: false },
    stale: { stale_days: 30, counts: { stale: 1 },
             items: [{ kind: 'sheet', id: 'S1', label: 'H3303', state: 'stale',
                       age_days: 44, demos_url: 'https://x.sk/a' }] },
    budget_check: [{ stable_key: 'budget|services|no_rate', section: 'services',
                     message: 'montáž bez hodinovej sadzby' }],
    sections: [
      { key: 'materials', name: 'Materiál', subtotal: 500,
        rows: [{ nazov: 'H3303', mnozstvo: 3, mj: 'm²', cena_mj: 20, spolu: 60, material_id: 'S1' }] },
      { key: 'abs', name: 'ABS', subtotal: 40,
        rows: [{ nazov: 'ABS 1 mm', mnozstvo: 12.3, mj: 'bm', cena_mj: 1, spolu: 12, abs_id: 'A1' }] },
      { key: 'hardware', name: 'Kovanie', subtotal: 90,
        rows: [{ kod: 'K1', nazov: 'Pánt', mnozstvo: 4, mj: 'ks', cena_mj: 2, spolu: 8 }] },
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
      { key: 'rounding', name: 'Zaokrúhlenie', subtotal: 5.5,
        rows: [{ poznamka: 'na celé desiatky nahor' }] }
    ],
    cp_preview: { consistent: true, complete: true, threshold: 300, total: 1234.5,
                  total_label: 'SPOLU',
                  rows: [{ polozka: 'Nábytková zostava', cena: 1234.5, mnozstvo: 1,
                           mj: 'ks', kind: 'assembly' }],
                  candidates: [{ source_key: 'material:S1', label: 'Doska', amount: 500,
                                 state: 'zostava' }] }
  }
};

sandbox.NX.setStudio(PAYLOAD); // deep-link otvori rovno sekciu Rozpocet
const tools = els.sectools.innerHTML;
const body = els.secbody.innerHTML;

// LISTA sekcie
ok(tools.indexOf('data-bud="vat"') > -1, 'lista nesie prepinac DPH');
ok(tools.indexOf('data-bud="mode"') > -1, 'aj cenovy rezim');
ok(tools.indexOf('data-bud="xlsx"') > -1, 'aj export XLSX rozpoctu');
// ŠT-1c PR B2: export cenovej ponuky sa PRESUNUL do listy sekcie `offer` —
// v liste Rozpoctu uz nema co robit (a lista tym schudla o najdlhsi popisok).
ok(tools.indexOf('data-bud="cp"') === -1,
   'export cenovej ponuky uz v liste Rozpoctu NIE JE (presunul sa do sekcie Ponuka)');

// TELO sekcie
ok(body.indexOf('class="btotal"') > -1, 'telo nesie velky sucet zakazky');
// Oddelovac tisicov je NEZALOMITELNA medzera (U+00A0) — v teste explicitne.
ok(body.indexOf('1 234,50 €') > -1, 'suma je SERVEROVE cislo (JS nic neprepocitava)');
ok(body.indexOf('data-bud="ctrl"') > -1, 'jantarovy chip vedie do sekcie Kontrola');
['materials', 'abs', 'hardware', 'services', 'standard_rows', 'custom', 'appliances'].forEach(
  function(key){
    ok(body.indexOf('data-section="' + key + '"') > -1, 'sekcia rozpoctu ' + key + ' sa vykreslila');
  }
);
ok(body.indexOf('Zaokrúhlenie ponuky') > -1, 'riadok zaokruhlenia tiez');
// ŠT-1c PR B2: nahlad CP sa odstahoval do vlastnej sekcie — v Rozpocte ostal
// LEN tenky preklik (ziadna druha kopia tabulky, ktora by sa casom rozisla).
ok(body.indexOf('Cenová ponuka — náhľad') === -1,
   'nahlad cenovej ponuky uz v tele Rozpoctu NIE JE');
ok(body.indexOf('data-bud="offer"') > -1, 'ostal po nom tenky preklik do sekcie Ponuka');
ok(body.indexOf('data-bud="draft" data-kind="custom"') > -1,
   'tlacidlo „Pridať položku" ostava na svojom mieste (otvara D-15 modal)');
ok(body.indexOf('class="bdraft"') === -1,
   'inline draft v tele sekcie ZANIKOL — pridavanie je D-15 modal');
ok(body.indexOf('class="bfoot"') === -1, 'patka s exportmi zanikla — exporty su v liste');
ok(body.indexOf('data-bud="vat"') === -1, 'a prepinac DPH v tele NIE JE (zdvojenie by klamalo)');

// Prepnutie na inu sekciu telo prepise — a nie je to pad.
sandbox.studioGoSection('bom');
ok(els.secbody.innerHTML.indexOf('class="btotal"') === -1,
   'prepnutie sekcie telo rozpoctu odstrani');

console.log('test_st1c_rozpocet.js: ' + n + ' OK');
