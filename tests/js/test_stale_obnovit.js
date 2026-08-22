// Jantarovy indikator neaktualnosti tlacidla „Obnoviť" — KLIENTSKA cast (22.8.).
//
// Preco su to testy a nie klikanie:
//   1. Tlacidlo je na PIATICH miestach (Kusovnik · Kontrola · Nakup · Rozpocet ·
//      Ponuka). Keby si kazde kreslilo vlastny markup, jedna sekcia by casom
//      tvrdila, ze cisla su cerstve, hoci uz nie su — a prave z nej by sa
//      exportovalo. Sada preto overuje, ze vsetkych 5 ide JEDNYM helperom.
//   2. Stav sa smie zhodit VYHRADNE prichodom plneho payloadu. Echa (lista
//      VEPO, prepinace hran, vysledok zapisu rozpoctu) cisla NENESU — keby
//      jantar zhadzovali, okno by po zapise sumy tvrdilo, ze je aktualne.
//   3. `markStale` sa smie dotknut LEN listy sekcie: tabulka aj zoznam nalezov
//      su stale tie cisla, ktore sem prisli naposledy.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

global.window = {};
const LISTEN = {};
const ELS = {};
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; }
};
const S = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'studio.js'));
// V prehliadaci JE `window` globalny objekt — v Node treba mat `NX` na oboch
// menach, inak by obal `NX.setStudio` v budget.js nenasiel, co obaluje.
// Poradie requirov je to iste ako poradie <script> v studio.html.
global.NX = global.window.NX;
const B = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'budget.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const TIP_BOM = 'Prepočítať kusovník z aktuálneho modelu';

// --- 1) zdielany markup: dva stavy jedneho tlacidla --------------------------
(function(){
  const cold = S.refreshBtnHtml(false, TIP_BOM);
  const warm = S.refreshBtnHtml(true, TIP_BOM);
  ok(cold.indexOf('id="refreshBtn"') > -1, 'tlacidlo drzi svoje ID (zdielany handler)');
  ok(cold.indexOf('nxstale') < 0, 'aktualne okno = NEUTRALNE tlacidlo (ziadna trvala zelena)');
  ok(cold.indexOf(TIP_BOM) > -1, 'a tooltip hovori o TEJ sekcii');
  ok(warm.indexOf('class="ghostbtn nxstale"') > -1, 'neaktualne okno = jantarova trieda');
  ok(warm.indexOf(S.STALE_TIP) > -1, 'a tooltip povie PRECO');
  ok(warm.indexOf(TIP_BOM) > -1, 'bez toho, aby zahodil povodny popis sekcie');
  ok(warm.indexOf('Platí pre akúkoľvek zmenu v dokumente') > -1,
     'sirka signalu je PRIZNANA — jantar znamena „mozno neaktualne", nie „urcite zmenene"');
  // Lista Rozpoctu a Ponuky sa prekresluje aj pocas ovladania — bez `data-bkey`
  // by po prekresleni spadol fokus na <body>.
  ok(S.refreshBtnHtml(false, 'x', ' data-bkey="refresh"').indexOf('data-bkey="refresh"') > -1,
     'volajuci si smie doniest vlastne atributy (fokus listy Rozpoctu)');
  // Stav chodi ARGUMENTOM aj do listy Kusovnika (funkcia ostava cista).
  ok(S.bomToolsHtml({}, { view: 'parts', q: '', stale: true }).indexOf('nxstale') > -1,
     'lista Kusovnika kresli jantar z `st.stale`');
  ok(S.bomToolsHtml({}, { view: 'parts', q: '', stale: false }).indexOf('nxstale') < 0,
     'a bez neho ostava neutralna');
})();

// --- 2) rovnaky markup v Rozpocte aj Ponuke (budget.js je len most) ---------
(function(){
  eq(B.budStaleFlag(), false, 'bez signalu je okno povazovane za aktualne');
  const cold = B.budOfferToolsHtml();
  ok(cold.indexOf('id="refreshBtn"') > -1 && cold.indexOf('nxstale') < 0,
     'lista Ponuky ma „Obnoviť" a je neutralna');
  global.staleFlag = true;              // v prehliadaci je to globál studio.js
  eq(B.budStaleFlag(), true, 'budget.js cita stav z toho isteho miesta ako `ST`');
  const warm = B.budOfferToolsHtml();
  ok(warm.indexOf('nxstale') > -1, 'lista Ponuky zozltne s celym oknom');
  ok(warm.indexOf(S.STALE_TIP) > -1, 'a nesie TEN ISTY tooltip (jeden markup, jedna pravda)');
  ok(B.budToolsHtml({}).indexOf('nxstale') > -1, 'lista Rozpoctu tiez');
  eq(B.budRefreshBtnHtml('Prepočítať rozpočet z aktuálneho modelu'),
     S.refreshBtnHtml(true, 'Prepočítať rozpočet z aktuálneho modelu', ' data-bkey="refresh"'),
     'budget.js NEMA vlastnu kopiu markupu — vracia presne to, co studio.js');
  global.staleFlag = false;
})();

// --- 3) zivot stavu v okne: signal -> lista, payload -> zhodenie ------------
(function(){
  const tools = { innerHTML: '' };
  const body = { innerHTML: '' };
  ['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel'].forEach(function(id){
    ELS[id] = (id === 'sectools') ? tools : (id === 'secbody' ? body : { innerHTML: '', textContent: '' });
  });
  const SU = { ready: function(){}, refresh_bom: function(){} };
  global.window.sketchup = SU;
  global.sketchup = SU;
  const VEPO = { project: 'ENGINEtests', default_project: 'ENGINEtests', merge_18_36: true };
  const push = function(sec, gen){
    global.window.NX.setStudio({ version: '0.7.43', gen: gen, model_title: 'ENGINEtests',
                                 rows: [], sheets: [], counts: {}, control: [], vepo: VEPO,
                                 edge_check: { available: true, active: false, options: {}, counts: {} },
                                 grain_check: { available: true, active: false },
                                 open_section: sec });
  };

  push('bom', 1);
  ok(tools.innerHTML.indexOf('nxstale') < 0, 'po prepocte je lista Kusovnika neutralna');
  const bodyBefore = body.innerHTML;

  global.window.NX.markStale();
  ok(tools.innerHTML.indexOf('nxstale') > -1, 'signal zo servera zozltil „Obnoviť"');
  eq(body.innerHTML, bodyBefore,
     'a NEDOTKOL sa obsahu sekcie — su to stale tie cisla, ktore prisli naposledy');

  // Echa: nesu stav prepinacov a listy, NIE cisla.
  global.window.NX.setVepoBar({ project: 'Iná zákazka', merge_18_36: false });
  ok(tools.innerHTML.indexOf('nxstale') > -1, 'echo listy VEPO jantar NEZHADZUJE');

  push('ctrl', 2);
  ok(tools.innerHTML.indexOf('nxstale') < 0, 'plny payload ho zhodil aj v Kontrole');
  global.window.NX.markStale();
  ok(tools.innerHTML.indexOf('nxstale') > -1, 'Kontrola zozltne rovnako ako Kusovnik');
  ok(tools.innerHTML.indexOf('Prepočítať kontrolu z aktuálneho modelu') > -1,
     'a drzi si vlastny popis sekcie');
  global.window.NX.setEdgeCheck({ available: true, active: true, options: {}, counts: {} });
  ok(tools.innerHTML.indexOf('nxstale') > -1,
     'echo prepinaca hran prekresli listu, ale jantar NEZHADZUJE (nenesie cisla)');
  global.window.NX.setGrainCheck({ available: true, active: true });
  ok(tools.innerHTML.indexOf('nxstale') > -1, 'ani echo smeru kresby');

  // Opakovany signal je no-op (server ho posiela raz za burst, ale okno sa
  // nesmie prekreslovat pri kazdom dalsom).
  global.window.NX.markStale();
  ok(tools.innerHTML.indexOf('nxstale') > -1, 'druhy signal stav nemeni');

  push('buy', 3);
  ok(tools.innerHTML.indexOf('nxstale') < 0, 'a Nakup kovania sa sprava rovnako');
  global.window.NX.markStale();
  ok(tools.innerHTML.indexOf('nxstale') > -1, 'jantar sa ukaze aj v Nakupe');
})();

console.log(`test_stale_obnovit: ${n} kontrol OK`);
