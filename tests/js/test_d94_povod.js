// D-94 — „NÁKUP S PÔVODOM": rozklik pôvodu v sekcii Nákup (klient).
//
// Preco su to testy a nie klikanie:
//   1. PAMAT ROZKLIKU je od tejto davky klucovana IDENTITOU riadku, nie
//      indexom. Rozdiel vidiet az vtedy, ked server riadky PREUSPORIADA:
//      s indexom by sa otvoril CUDZI riadok — a vyzeralo by to spravne,
//      len s pomiesanym povodom. To sa klikanim nechyti.
//   2. Reset pamate sa presunul „pri kazdom pushi" -> „len pri zmene
//      dokumentu". Keby ostal pri kazdom pushi, rozklik by sa zavrel po
//      kazdom „Obnoviť" a nikto by netusil preco.
//   3. KLIK NA ZDROJ musi poslat `source_ref` (identitu), NIKDY pids z DOM —
//      po flushi editov su pids mrtve a oznacilo by sa nieco ine.
//   4. Klik na zdroj sa musi spracovat PRED riadkom nakupu: inak by rozklik
//      iba zbalil a vyber by sa nikdy nevykonal.
//   5. SUCTY skupin su jediny udaj, podla ktoreho pouzivatel vidi, kolko kusov
//      ide z ktorej skrinky — a musia sediet s poctom riadku.
//
// MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
//   1. `buyOpen` klucovany INDEXOM riadku (`data-buy` nesie poradie),
//   2. klik na zdroj sa spracuje AZ ZA riadkom nakupu (prepne rozklik namiesto vyberu),
//   3. `selectSource` posiela `source_ref` BEZ `focus_inspector`,
//   4. `hwSourceGroups` necita mnozstva (skupina bez suctu).
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// --- DOM stub (vzor tests/js/test_d122_uni_skupina.js) -----------------------
const listeners = {};
const body = { innerHTML: '' };
const SENT = [];
global.window = { sketchup: { nx_select: function(p){ SENT.push(JSON.parse(p)); } } };
global.sketchup = global.window.sketchup;
global.document = {
  addEventListener: function(name, fn){ listeners[name] = fn; },
  getElementById: function(id){ return id === 'secbody' ? body : null; }
};
const S = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'studio.js'));

const click = function(matches){
  listeners.click({ target: { closest: function(sel){ return matches[sel] || null; } } });
};
const attr = function(attrs){
  return { getAttribute: function(k){
    return Object.prototype.hasOwnProperty.call(attrs, k) ? attrs[k] : null;
  } };
};

// --- fixtury ----------------------------------------------------------------
// Nakupny riadok je SUCET cez celu zakazku: ten isty kod prisiel z dvoch
// skriniek, v jednej z nich dvakrat (dve cela) a v druhej rucne.
const SRC = [
  { cabinet_id: 'CAB-3', owner_part_key: 'front:F1/wing:left',
    owner_label: 'F1 · dvierka ľavé', set_id: 'zaves-klasik', quantity: 2 },
  { cabinet_id: 'CAB-3', owner_part_key: 'front:F2/wing:right',
    owner_label: 'F2 · dvierka pravé', set_id: 'zaves-klasik', quantity: 4 },
  { cabinet_id: 'CAB-1', owner_part_key: null, origin: 'adhoc', quantity: 3 }
];
const ROW_A = { code: '93240', name_sk: 'Záves Sensys', category: 'Závesy', quantity: 9,
                unit: 'ks', price_eur_vat: 1.14, subtotal_eur_vat: 10.26,
                adhoc_quantity: 3, sources: SRC };
const ROW_FREE = { code: '', free: true, free_key: 'free:CAB-1:H2', name_sk: 'Zámok Abloy',
                   quantity: 1, unit: 'ks', price_eur_vat: 12.0, subtotal_eur_vat: 12.0,
                   adhoc_quantity: 1,
                   sources: [{ cabinet_id: 'CAB-1', owner_part_key: null,
                               origin: 'adhoc', quantity: 1 }] };
const hs = function(rows){ return { state_status: 'ok', rows: rows, summary: {} }; };
const push = function(rows, guid, gen){
  window.NX.setStudio({ model_guid: guid || 'DOC-A', gen: gen || 1, open_section: 'buy',
                        rows: [], sheets: [], counts: {}, control: [],
                        hardware: [], hardware_sets: hs(rows) });
};

// ===================== 1) ZOSKUPENIE ZDROJOV PER SKRINKA =====================

(function(){
  const g = S.hwSourceGroups(SRC);
  eq(g.length, 2, 'tri zdroje z dvoch skriniek = dve skupiny');
  eq(g.map(function(x){ return x.cabinet_id; }), ['CAB-3', 'CAB-1'],
     'poradie skupin = poradie PRVEHO vyskytu (server triedi deterministicky)');
  eq(g[0].quantity, 6, 'skupina scitava kusy svojej skrinky');
  eq(g[1].quantity, 3, 'a druha tiez');
  eq(g[0].items.length, 2, 'polozky skupiny ostavaju v povodnom poradi');
  eq(g[0].items[0].owner_label, 'F1 · dvierka ľavé');
  eq(g.reduce(function(s, x){ return s + x.quantity; }, 0), ROW_A.quantity,
     'Σ skupin = mnozstvo riadku (to iste, co strazi test_d94_povod.rb na serveri)');

  // Zdroj BEZ `cabinet_id` (nemal by vzniknut, ale payload je verejny kanal)
  // ma VLASTNU skupinu s prazdnym ID — nikdy sa neprilepi k cudzej skrinke.
  const mix = S.hwSourceGroups([{ cabinet_id: '', quantity: 1 },
                                { cabinet_id: 'CAB-9', quantity: 2 },
                                { quantity: 5 }]);
  eq(mix.length, 2, 'zdroje bez ID sa zliali do JEDNEJ bezmennej skupiny');
  eq(mix[0].cabinet_id, '', 'a ta ma prazdne ID');
  eq(mix[0].quantity, 6, 'so svojim vlastnym suctom');

  eq(S.hwSourceGroups(null), [], 'chybajuci zoznam nespadne');
  eq(S.hwSourceGroups([]), [], 'ani prazdny');
  // Necislo v mnozstve sucet NEZNICI (NaN by zo suctu spravil „—").
  eq(S.hwSourceGroups([{ cabinet_id: 'C', quantity: 'x' },
                       { cabinet_id: 'C', quantity: 2 }])[0].quantity, 2,
     'nepouzitelne mnozstvo sa preskoci, sucet ostane cislom');
})();

// ===================== 2) KRESLENIE ROZKLIKU =================================

(function(){
  S.setBuyOpen({});
  const closed = S.buySection(hs([ROW_A]), []);
  eq(closed.indexOf('Pôvod:'), -1, 'zbaleny riadok povod nekresli');
  ok(closed.indexOf('data-buy="93240"') > -1,
     'adresa rozkliku je KOD riadku (identita), nie poradie');

  S.setBuyOpen({ 93240: true });
  const open = S.buySection(hs([ROW_A]), []);
  ok(open.indexOf('Pôvod:') > -1, 'rozkliknuty riadok ukaze povod');
  eq((open.match(/class="hwsrcg"/g) || []).length, 2, 'a v nom JEDEN riadok na skrinku');
  ok(open.indexOf('<a class="hwsrccab" data-src-cab="CAB-3"') > -1,
     'hlavicka skupiny je KLIKATELNA a nesie ID skrinky');
  ok(open.indexOf('6 ks') > -1 && open.indexOf('3 ks') > -1, 'a sucet skupiny');
  ok(open.indexOf('data-src-key="front:F1/wing:left"') > -1,
     'polozka nesie kluc vlastnika (adresa vyberu dielca)');
  ok(open.indexOf('celá skrinka · ručná ×3') > -1,
     'zdroj bez vlastnika sa prizna slovami (nie tichym vynechanim)');
  ok(open.indexOf('CAB-3 · F1') === -1,
     'ID skrinky sa v polozke UZ NEOPAKUJE (stoji v hlavicke skupiny)');
  // Codex #361 P2: tooltip nesmie slubit OTVORENIE Inspectora — `do_select` ho
  // nikdy neotvara, len zdvihne (konvencia Š3 ceruzky).
  ok(open.indexOf('title="Označí skrinku v modeli a zdvihne Inspector, ak je otvorený"') > -1 &&
     open.indexOf('title="Označí dielec v modeli a zdvihne Inspector, ak je otvorený"') > -1,
     'klikatelne prvky hovoria, co klik urobi');
  ok(open.indexOf('otvorí ju v Inspectore') === -1 && open.indexOf('a otvorí Inspector') === -1,
     'a NESLUBUJU otvorenie zavreteho Inspectora');

  // Skupina bez ID NIE JE klikatelna — nema kam viest.
  const dead = S.buySection(hs([{ code: 'X1', quantity: 1,
                                  sources: [{ cabinet_id: '', quantity: 1 }] }]), []);
  S.setBuyOpen({ x1: true });
  const deadOpen = S.buySection(hs([{ code: 'X1', quantity: 1,
                                      sources: [{ cabinet_id: '', quantity: 1 }] }]), []);
  eq(dead.indexOf('hwsrcdead'), -1, 'zbaleny riadok nekresli ani bezmennu skupinu');
  ok(deadOpen.indexOf('hwsrcdead') > -1, 'bezmenna skupina je tlmena');
  eq(deadOpen.indexOf('data-src-cab'), -1, 'a NEMA adresu vyberu (klik sa nevykona)');

  // Riadok bez zdrojov to prizna (stary payload).
  S.setBuyOpen({ x2: true });
  ok(S.buySection(hs([{ code: 'X2', quantity: 1 }]), []).indexOf('neniesol zdroje') > -1,
     'riadok bez zdrojov povie, ze povod nema');
  S.setBuyOpen({});
})();

// ===================== 3) IDENTITA RIADKU (pamat rozkliku) ===================

(function(){
  eq(S.hwRowKey({ code: '93240' }), '93240', 'kod je identitou setoveho riadku');
  eq(S.hwRowKey({ code: 'Ab-12' }), 'ab-12',
     'malymi pismenami — agregacny kluc servera je case-insensitive');
  eq(S.hwRowKey({ code: '', free: true, free_key: 'free:CAB-1:H2' }), 'free:CAB-1:H2',
     'volna polozka ma vlastny kluc (kod NEMA)');
  eq(S.hwRowKey(null), '', 'nezmysel nevyrobi kluc');

  // TOTO je dovod celej zmeny: cerstvy payload riadky PREUSPORIADA.
  S.setBuyOpen({ 93240: true });
  const before = S.buySection(hs([ROW_A, ROW_FREE]), []);
  const after = S.buySection(hs([ROW_FREE, ROW_A]), []);
  ok(before.indexOf('Pôvod:') > -1 && after.indexOf('Pôvod:') > -1,
     'rozkliknuty riadok ostava rozkliknuty aj po preusporiadani');
  eq((after.match(/class="hwsrcg"/g) || []).length, 2,
     'a je to STALE ten isty riadok (dve skupiny zdrojov kodu 93240)');

  S.setBuyOpen({ 'free:CAB-1:H2': true });
  const freeOpen = S.buySection(hs([ROW_A, ROW_FREE]), []);
  ok(freeOpen.indexOf('Pôvod:') > -1, 'volna polozka sa rozklikne cez `free_key`');
  ok(freeOpen.indexOf('celá skrinka · ručná ×1') > -1, 'a ukaze svoj jediny zdroj');
  S.setBuyOpen({});
})();

// ===================== 4) KLIK: zdroj -> vyber, riadok -> rozklik ============

(function(){
  push([ROW_A, ROW_FREE]);
  ok(body.innerHTML.indexOf('data-buy="93240"') > -1, 'sekcia Nakup sa naozaj vykreslila');
  eq(body.innerHTML.indexOf('Pôvod:'), -1, 'a po pushi je rozklik zbaleny');

  // Klik na riadok = rozklik (bez servera).
  SENT.length = 0;
  click({ 'tr.hwbuyrow': attr({ 'data-buy': '93240' }) });
  ok(body.innerHTML.indexOf('Pôvod:') > -1, 'klik na riadok rozbali povod');
  eq(SENT.length, 0, 'a NEVOLA server (je to cisté zobrazenie payloadu)');

  // Klik na hlavicku skupiny = vyber SKRINKY.
  click({ '[data-src-cab]': attr({ 'data-src-cab': 'CAB-3' }),
          'tr.hwbuyrow': attr({ 'data-buy': '93240' }) });
  eq(SENT.length, 1, 'klik na zdroj posle prave jednu ziadost');
  eq(SENT[0], { gen: 1, source_ref: { cabinet_id: 'CAB-3', owner_part_key: null },
                focus_inspector: true },
     'nesie IDENTITU zdroja + zdvih Inspectora; ziadne pids z DOM');
  ok(body.innerHTML.indexOf('Pôvod:') > -1,
     'a rozklik sa kliknutim na zdroj NEZBALIL (zdroj sa spracuva PRED riadkom)');

  // Klik na polozku skupiny = vyber DIELCA (kluc ide so ziadostou).
  SENT.length = 0;
  click({ '[data-src-cab]': attr({ 'data-src-cab': 'CAB-3',
                                   'data-src-key': 'front:F1/wing:left' }) });
  eq(SENT[0].source_ref, { cabinet_id: 'CAB-3', owner_part_key: 'front:F1/wing:left' },
     'polozka posiela aj kluc vlastnika');

  // Prazdny kluc (skupina bez adresy vlastnika) ide ako `null` = cela skrinka.
  SENT.length = 0;
  click({ '[data-src-cab]': attr({ 'data-src-cab': 'CAB-1', 'data-src-key': '' }) });
  eq(SENT[0].source_ref.owner_part_key, null, 'prazdny kluc = kovanie celej skrinky');

  // Zdroj bez ID skrinky sa neposiela vobec.
  SENT.length = 0;
  click({ '[data-src-cab]': attr({ 'data-src-cab': '' }) });
  eq(SENT.length, 0, 'bezmenny zdroj ziadnu ziadost neposiela');

  // Druhy klik na riadok rozklik ZBALI.
  click({ 'tr.hwbuyrow': attr({ 'data-buy': '93240' }) });
  eq(body.innerHTML.indexOf('Pôvod:'), -1, 'druhy klik na riadok povod zbali');
})();

// ===================== 5) PAMAT PREZIJE PUSH, ZMENA DOKUMENTU JU MAZE =======

(function(){
  push([ROW_A, ROW_FREE]);
  click({ 'tr.hwbuyrow': attr({ 'data-buy': '93240' }) });
  ok(body.innerHTML.indexOf('Pôvod:') > -1, 'riadok je rozkliknuty');

  // „Obnoviť" = novy payload TOHO ISTEHO dokumentu, riadky v inom poradi.
  push([ROW_FREE, ROW_A], 'DOC-A', 2);
  ok(body.innerHTML.indexOf('Pôvod:') > -1,
     'rozklik PREZIL push (kluc je identita riadku, nie jeho poradie)');

  // Prepnutie zakazky rozklik ZAHODI — patril inemu dokumentu.
  push([ROW_A], 'DOC-B', 3);
  eq(body.innerHTML.indexOf('Pôvod:'), -1, 'zmena dokumentu pamat maze');

  // Zdrojovy guard: reset STOJI ZA podmienkou `model_guid` (mutacia „maz pri
  // kazdom pushi" by prve tvrdenie zhodila, toto ju chyta aj v zdrojaku).
  const fs = require('node:fs');
  const src = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js',
                                        'studio.js'), 'utf8');
  ok(/ST\.model_guid !== data\.model_guid\) buyOpen = \{\};/.test(src),
     'pamat rozkliku sa maze VYHRADNE pri zmene dokumentu');
})();

console.log('OK test_d94_povod.js — ' + n + ' kontrol');
