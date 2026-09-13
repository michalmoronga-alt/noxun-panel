// Testy D-131 — riadok „Kresba čiel" v sekcii Materiály (proj_materials.js).
//
// CO SA TU ZAMYKA:
//   1) Riadok sa kresli VYHRADNE zo serveroveho `mat.front_grain` — klient si
//      ziadne cislo nedopocitava (vzor celej sekcie).
//   2) ZAMOK TLACIDLA: prestavba zakazky trva; druhy klik pred NOVYM pushom
//      nesmie odist, inak by z jednej volby vznikli DVA kroky Späť.
//   3) 0 ciel = tlacidlo `disabled` s textom „Žiadne čelá" (nie prazdny klik,
//      ktory by na serveri skoncil hlaskou).
//   4) Payload nesie `gen` + `model_guid` — identitu kliku overuje SERVER
//      (stary DOM / prepnuty dokument).
'use strict';
const assert = require('assert');
const path = require('path');

// --- DOM stub (vzor tests/js/test_replace_uni.js) --------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], _html: '', _attrs: {}, disabled: false, value: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children = []; }
  });
  Object.defineProperty(n, 'textContent', { get(){ return n._text || ''; }, set(v){ n._text = v; } });
  n.appendChild = function(c){ n.children.push(c); return c; };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  return n;
}
['md_front_grain', 'md_front_grain_apply', 'md_front_grain_now'].forEach(function(id){
  ELS[id] = stubEl(id);
});
const SENT = [];
global.window = { sketchup: { fronts_grain_all: function(p){ SENT.push(p); } } };
global.sketchup = global.window.sketchup;
global.document = {
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  addEventListener: function(){}
};

require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'studio.js'));
global.NX = global.window.NX;
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let passed = 0;
function eq(a, b, msg){ assert.deepStrictEqual(a, b, msg); passed += 1; }
function ok(c, msg){ assert.ok(c, msg); passed += 1; }

// --- 1) TEXTY (ciste funkcie) ---------------------------------------------

eq(M.mdFrontGrainBtnText({ count: 12 }), 'Použiť na všetky čelá (12)',
   'tlacidlo nesie POCET ciel, na ktore akcia dosiahne');
eq(M.mdFrontGrainBtnText({ count: 0 }), 'Žiadne čelá',
   'prazdna zakazka to povie uz na tlacidle');
eq(M.mdFrontGrainBtnText(null), 'Stav nedostupný',
   'chybajuci stav sa NEtvari ako prazdna zakazka');

eq(M.mdFrontGrainNowText({ by: { length: 0, width: 8, inherit: 4 } }),
   'teraz: 8× priečna · 4× podľa materiálu',
   'nulove skupiny sa nevypisuju (vertikalny priestor je vzacny)');
eq(M.mdFrontGrainNowText({ by: { length: 3, width: 0, inherit: 0 } }),
   'teraz: 3× pozdĺžna');
eq(M.mdFrontGrainNowText({ by: {} }), '', 'bez ciel sa nepise nic');
eq(M.mdFrontGrainNowText(null), 'stav sa nepodarilo zistiť',
   'zlyhanie zberu sa PRIZNA (server posiela `front_grain: null`)');

// --- 1b) PRESKOCENE SKRINKY sa NIKDY nezamlcia --------------------------
// Zakazka, kde je preskocene VSETKO (novsia schema / stara skrinka), by inak
// hlasila falosne „Žiadne čelá" (review #365, P2).
const SKIP2 = [{ cabinet_id: 'CAB-009', why: 'novšia verzia pluginu' },
               { cabinet_id: 'CAB-010', why: 'novšia verzia pluginu' }];
eq(M.mdFrontGrainSkipText(SKIP2), '2 skrinky preskočené — novšia verzia pluginu',
   'dovody sa deduplikuju');
eq(M.mdFrontGrainSkipText([{ why: 'a' }, { why: 'b' }]), '2 skrinky preskočené — a, b');
eq(M.mdFrontGrainSkipText([{ why: 'a' }]), '1 skrinka preskočená — a',
   'sklonovanie sedi aj v jednotnom cisle');
eq(M.mdFrontGrainSkipText([]), '', 'bez preskocenych sa nepise nic');
eq(M.mdFrontGrainNowText({ count: 0, by: {}, skipped: SKIP2 }),
   '2 skrinky preskočené — novšia verzia pluginu',
   'ked nie je co nastavit, riadok povie PRECO');
eq(M.mdFrontGrainBtnText({ count: 0, skipped: SKIP2 }), 'Žiadne dostupné čelá',
   'nie „Žiadne čelá" — čelá tam sú, len sa na ne nedá siahnuť');
eq(M.mdFrontGrainNowText({ count: 4, by: { width: 4 }, skipped: [{ why: 'x' }] }),
   'teraz: 4× priečna · 1 skrinka preskočená — x',
   'preskocene sa priznaju aj vedla beznych poctov');

// --- 2) PAYLOAD ------------------------------------------------------------

eq(M.mdFrontGrainPayload(7, 'G-1', 'width'), { gen: 7, model_guid: 'G-1', grain: 'width' },
   'identitu kliku (gen + model_guid) overuje SERVER — klient ju verne vracia');
eq(M.mdFrontGrainPayload(0, '', '__inherit__'), { gen: 0, model_guid: '', grain: '__inherit__' },
   'sentinel dedenia ide na server rovnako ako smer');
eq(M.mdFrontGrainPayload(7, 'G-1', ''), null, 'bez smeru sa NEPOSIELA nic');

// --- 3) RENDER ZO SERVEROVEHO STAVU ----------------------------------------

NX.setStudio({ gen: 5, mat: { model_guid: 'G-1', project: {},
                              front_grain: { count: 12, cabinets: 5,
                                             by: { length: 0, width: 8, inherit: 4 } } } });
M.mdRenderFrontGrain();
eq(ELS.md_front_grain_now.textContent, 'teraz: 8× priečna · 4× podľa materiálu',
   'read-only stav sa kresli z payloadu');
eq(ELS.md_front_grain_apply.textContent, 'Použiť na všetky čelá (12)');
eq(ELS.md_front_grain_apply.disabled, false, 's celami je tlacidlo aktivne');

// --- 4) KLIK + ZAMOK -------------------------------------------------------

ELS.md_front_grain.value = 'width';
ok(M.mdFrontGrainApply(), 'prvy klik otazku POSLE');
eq(SENT.length, 1, 'prave jedna otazka');
eq(JSON.parse(SENT[0]), { gen: 5, model_guid: 'G-1', grain: 'width' },
   'payload nesie generaciu OKNA (nie sekcie) a identitu dokumentu');
eq(ELS.md_front_grain_apply.disabled, true, 'tlacidlo je zamknute');
eq(ELS.md_front_grain_apply.textContent, 'Prestavujem…', 'a hovori, ze sa pracuje');

ok(M.mdFrontGrainApply() === false, 'DRUHY klik pred pushom NEPOSLE nic');
eq(SENT.length, 1, 'stale jedna otazka — inak by vznikli dva kroky Späť');

// Zámok pustí LEN plný push okna. Katalógové echo (`NX.setMatCatalog`) generáciu
// nedvíha ani modelový stav nenesie — tlačidlo po ňom musí ostať zamknuté.
NX.setMatCatalog({ sheets: [], edges: [] });
eq(ELS.md_front_grain_apply.disabled, true, 'katalógové echo zámok NEPUSTÍ');
ok(M.mdFrontGrainApply() === false, 'a klik po ňom stále nič nepošle');
eq(SENT.length, 1);

// --- 5) NOVY PUSH ODOMKNE --------------------------------------------------

NX.setStudio({ gen: 6, mat: { model_guid: 'G-1', project: {},
                              front_grain: { count: 12, cabinets: 5,
                                             by: { length: 0, width: 12, inherit: 0 } } } });
M.mdRenderFrontGrain();
eq(ELS.md_front_grain_apply.disabled, false, 'novy push tlacidlo ODOMKNE');
eq(ELS.md_front_grain_now.textContent, 'teraz: 12× priečna', 'a ukaze novy stav');
ok(M.mdFrontGrainApply(), 'po pushi sa da klikat znova');
eq(JSON.parse(SENT[2 - 1]).gen, 6, 'druha otazka ide uz s CERSTVOU generaciou');

// Aj push BEZ sekcie `mat` (payload sa nepodarilo zostavit) musi tlacidlo
// odomknut — inak by ostalo navzdy v stave „Prestavujem…".
NX.setStudio({ gen: 7 });
M.mdRenderFrontGrain();
eq(ELS.md_front_grain_apply.disabled, false, 'push bez `mat` tlacidlo neuvazni');

// --- 6) PRAZDNA ZAKAZKA ----------------------------------------------------

SENT.length = 0;
NX.setStudio({ gen: 8, mat: { model_guid: 'G-1', project: {},
                              front_grain: { count: 0, cabinets: 0, by: {} } } });
M.mdRenderFrontGrain();
eq(ELS.md_front_grain_apply.disabled, true, '0 ciel = tlacidlo je vypnute');
eq(ELS.md_front_grain_apply.textContent, 'Žiadne čelá');
eq(ELS.md_front_grain_now.textContent, '', 'a stav nema co hlasit');

console.log('test_d131_ui.js OK (' + passed + ' kontrol)');
