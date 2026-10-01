// Testy H10b/R-35 — rozmerove rady pri DVOCH oknach SketchUpu (klient).
//   node tests/js/test_h10b_rady.js
//
// Kontrakt, ktory sa tu strazi:
//   1) NXDim.changes — odchadzaju LEN zmenene rady (porovnanie normalizovanych
//      podob s pinom), ku kazdemu povodna hodnota; rad bez pinu ide s base null
//      (server ho odmietne — fail-closed),
//   2) PIN NXDIM_BASE sa nastavi LEN v nxFillSeriesEditor (otvorenie kolieska,
//      odpoved `refill_editor`); push temy/init ho NEMENI,
//   3) bez zmeny sa server nevola, polia sa zjednotia z pinu a status to povie,
//   4) „Predvolené" meni len polia (az Ulozit posle zmenene rady).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');

const SRC = fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'settings.js'), 'utf8');
const NXDim = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'settings.js'));

let n = 0;
// Porovnanie cez JSON: objekty zo sandboxu `vm` maju prototypy INEHO realmu
// a deepStrictEqual by ich povazoval za rozne aj pri rovnakom obsahu.
function plain(v){ return v === undefined ? v : JSON.parse(JSON.stringify(v)); }
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(plain(actual), plain(expected), `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const D = NXDim.DEFAULTS;
function texts(over){
  const t = {};
  NXDim.KEYS.forEach(function(k){ t[k] = NXDim.formatList(D[k]); });
  return Object.assign(t, over || {});
}

// --- 1) NXDim.changes (cista funkcia) ----------------------------------------

(function(){
  const base = NXDim.normalize(null);
  const c0 = NXDim.changes(texts(), base);
  eq(c0.keys, [], 'nic nezmenene = ziadny rad neodchadza');
  eq(c0.series, {}, 'a ziadne rady v payloade');

  const c1 = NXDim.changes(texts({ sirka: '900 800, 600;500 450 400 400' }), base);
  eq(c1.keys, [], 'ine poradie, duplicity a oddelovace = rovnaky rad (nie zmena)');

  const c2 = NXDim.changes(texts({ sirka: '400, 450, 500, 600, 700, 800, 900' }), base);
  eq(c2.keys, ['sirka'], 'zmeneny je LEN rad sirok');
  eq(Object.keys(c2.series), ['sirka'], 'a len ten odchadza (nie vsetkych 5)');
  eq(c2.series.sirka, ['400', '450', '500', '600', '700', '800', '900'], 'text ide tak, ako ho pouzivatel napisal (normalizuje server)');
  eq(c2.base, { sirka: D.sirka }, 'k radu ide jeho POVODNA hodnota z pinu');

  const c3 = NXDim.changes(texts({ vyska_cela: '' }), base);
  eq(c3.keys, ['vyska_cela'], 'vyprazdneny rad je zmena');
  eq(c3.series.vyska_cela, [], 'a odchadza ako prazdny rad');

  const c4 = NXDim.changes(texts(), null);
  eq(c4.keys, NXDim.KEYS, 'bez pinu je kazdy rad „zmeneny"');
  NXDim.KEYS.forEach(function(k){ eq(c4.base[k], null, 'a ide s base null (server = okno zo starsej verzie)'); });
  eq(JSON.parse(JSON.stringify(c4)).base.sirka, null, 'null prezije JSON (nezmizne ako undefined)');
})();

// --- 2) DOM: pin, ulozenie, push temy ----------------------------------------

function sandbox(){
  const inputs = {};
  NXDim.KEYS.forEach(function(k){ inputs['ser_' + k] = { value: '' }; });
  inputs.cfgModal = { style: {}, querySelector: function(){ return null; }, addEventListener: function(){} };
  const sent = [], status = [];
  const ctx = {
    el: function(id){ return inputs[id] || null; },
    document: {
      addEventListener: function(){},
      querySelectorAll: function(){ return []; },
      documentElement: { getAttribute: function(){ return 'noxun'; } },
      activeElement: null
    },
    sketchup: { nx_set_dim_series: function(s){ sent.push(JSON.parse(s)); } },
    NX: { setStatus: function(m, e){ status.push([m, !!e]); } }
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(SRC, ctx);
  return { ctx: ctx, inputs: inputs, sent: sent, status: status };
}

(function(){
  const s = sandbox();
  const S0 = NXDim.normalize({ sirka: [400, 600], sokel: [100] });
  s.ctx.nxApplyUiSettings({ dim_series: S0 });               // init panela
  eq(s.ctx.NXDIM_BASE, null, 'init panela pin NENASTAVI (editor este nikto nevidel)');

  s.ctx.openInspectorSettings('series');                      // otvorenie kolieska
  eq(s.ctx.NXDIM_BASE, S0, 'otvorenie kolieska pripne rady, ktore editor ukazal');
  eq(s.inputs.ser_sirka.value, '400, 600', 'editor ukazuje pripnute rady');

  // ine okno medzitym zmenilo siroky; push temy prinesie cerstve rady
  const S1 = NXDim.normalize({ sirka: [400, 600, 700], sokel: [100] });
  s.ctx.nxApplyUiSettings({ dim_series: S1, refill_editor: false });
  eq(s.ctx.NXDIM_BASE, S0, 'push temy pin NEPOSUNIE');
  eq(s.inputs.ser_sirka.value, '400, 600', 'a rozpisany editor neprepise');

  // pouzivatel meni TEN ISTY rad, ktory zmenilo ine okno
  s.inputs.ser_sirka.value = '400, 600, 800';
  s.ctx.saveDimSeries();
  eq(s.sent.length, 1, 'ulozenie zavolalo server');
  eq(Object.keys(s.sent[0].series), ['sirka'], 'odchadza len zmeneny rad');
  eq(s.sent[0].base, { sirka: [400, 600] }, 'povodna hodnota = to, co pouzivatel VIDEL (nie cerstvy push)');

  // odpoved servera (konflikt aj uspech) prekresli editor a pripne nove rady
  s.ctx.nxApplyUiSettings({ dim_series: S1, refill_editor: true });
  eq(s.ctx.NXDIM_BASE, S1, 'refill_editor pripne aktualne ulozene rady');
  eq(s.inputs.ser_sirka.value, '400, 600, 700', 'a editor ich ukazuje');

  // zmena INEHO radu -> odchadza len on, s povodnou hodnotou z noveho pinu
  s.inputs.ser_hlbka.value = '300 600';
  s.ctx.saveDimSeries();
  eq(Object.keys(s.sent[1].series), ['hlbka'], 'odchadzaju len hlbky');
  eq(s.sent[1].base, { hlbka: S1.hlbka }, 'k nim povodne hlbky');
})();

(function(){
  const s = sandbox();
  s.ctx.nxApplyUiSettings({ dim_series: null });
  s.ctx.openInspectorSettings('series');
  s.inputs.ser_sirka.value = '900,800 , 600 500 450 400';
  s.ctx.saveDimSeries();
  eq(s.sent.length, 0, 'bez skutocnej zmeny sa server NEVOLA');
  eq(s.status, [['Rozmerové rady sa nezmenili.', false]], 'status to povie');
  eq(s.inputs.ser_sirka.value, NXDim.formatList(D.sirka), 'polia sa zjednotia z pinu');

  s.ctx.resetDimSeriesFields();
  eq(s.sent.length, 0, '„Predvolené" meni len polia (server sa nevola)');
  s.inputs.ser_sokel.value = '90';
  s.ctx.resetDimSeriesFields();
  s.inputs.ser_vyska.value = '720, 820';
  s.ctx.saveDimSeries();
  eq(Object.keys(s.sent[0].series), ['vyska'], 'po „Predvolené" odchadza len rad odlisny od pinu');
})();

(function(){
  // ulozenie BEZ pinu (nikdy nenastane z UI) nesmie zapisat naslepo
  const s = sandbox();
  s.ctx.nxApplyUiSettings({ dim_series: null });
  NXDim.KEYS.forEach(function(k){ s.inputs['ser_' + k].value = NXDim.formatList(D[k]); });
  s.ctx.saveDimSeries();
  eq(s.sent.length, 1, 'bez pinu ide poziadavka na server');
  NXDim.KEYS.forEach(function(k){ eq(s.sent[0].base[k], null, 'kazdy rad s base null (fail-closed)'); });
})();

// --- 3) zdrojove guardy -------------------------------------------------------

ok(/NXDIM_BASE = NXDim\.normalize\(NXDim\.all\(\)\);/.test(SRC.slice(SRC.indexOf('function nxFillSeriesEditor'))),
   'pin vznika v nxFillSeriesEditor ako KOPIA stavu');
ok((SRC.match(/^\s*NXDIM_BASE = /gm) || []).length === 1, 'pin sa nastavuje na JEDINOM mieste (okrem deklaracie)');
ok(SRC.indexOf('sketchup.nx_set_dim_series(JSON.stringify({ series: c.series, base: c.base }))') > 0,
   'payload nesie zmenene rady aj povodne hodnoty');

console.log(`test_h10b_rady.js: OK (${n} kontrol)`);
