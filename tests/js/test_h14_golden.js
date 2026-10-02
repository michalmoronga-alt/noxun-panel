// H14 · T0 (R0) — CHARAKTERIZACNY ODTLACOK sekcii Studia pred registrom
// `NXStudioSections` (package `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H14.md`).
//   node tests/js/test_h14_golden.js
//
// H14 presuva zoznamy sekcii (navigacia, hlavicka, hlaska „Obnoviť", filter
// deep-linku Inspectora, sekcie Nastaveni) a neskor aj prepinanie sekcie na
// jeden register. Pre pouzivatela sa nesmie zmenit NIC — tento test zachytil
// spravanie NEZMENENEHO kodu (1. commit H14a) a po kazdej casti musi dat ten
// isty vysledok (G1–G10, popis v `h14_harness.js`):
//   G1 navigacia + hlavicka (14 sekcii, aj zbalena navigacia) · G2 dispatch
//   lista/telo (cerstve aj neaktualne cisla, modul chyba) · G3 prechody 14×14
//   navigaciou aj deep-linkom so STAVOM v okamihu volania + dokumentova matica
//   · G4 kotvy · G5 hlaska „Obnoviť" · G6 filter Inspectora · G7 sekcie
//   Nastaveni · G8 navrat do rozpracovanej sekcie · G9 pamat tohto pocitaca ·
//   G10 klik na navigaciu.
// Fixtury sa NEREGENERUJU (generator `tests/fixtures/h14_golden/generate.js`
// sa smie spustit len na nezmenenom kode) — rozdiel je nalez.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const H = require('./h14_harness.js');

let n = 0;
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// Haciky sekcii existuju AKO GLOBALY ESTE PRED instalaciou spehov — spehy ich
// len nahradzaju, nikdy nevytvaraju (§15 A5).
const L0 = H.load();
const miss = H.missingHooks(L0);
ok(miss.length === 0, 'haciky sekcii existuju pred spehmi: chybaju ' + miss.join(', '));
ok(H.ids().length === 14, 'fixtura kontraktu nesie 14 sekcii');

const fresh = H.golden();
const names = fs.readdirSync(H.GOLDEN_DIR).filter(function(f){ return /^g\d+_[a-z_]+\.json$/.test(f); })
  .map(function(f){ return f.replace(/\.json$/, ''); }).sort();
assert.deepStrictEqual(names, Object.keys(fresh).sort(), 'golden subory = skupiny G1–G10');
// H7b (R-B11): fixtury sa NEREGENERUJU — styri ohranicene fragmenty (hlavicka,
// pole Projekt, title + bodka #vepoBtn a #hwCsvBtn) sa normalizuju na OBOCH
// stranach a pocet nahradeni je PRESNY (inak by normalizacia skryla viac).
const ZERO = { HLAVICKA: 0, PRJBOX: 0, VEPO: 0, CSV: 0 };
names.forEach(function(name){
  const w = H.normalizeH7(JSON.parse(fs.readFileSync(path.join(H.GOLDEN_DIR, name + '.json'), 'utf8')), 'old');
  const g = H.normalizeH7(JSON.parse(H.serialize(fresh[name])), 'new');
  const exp = Object.assign({}, ZERO, H.H7_COUNTS[name] || {});
  n++;
  assert.deepStrictEqual(w.counts, exp, name + ': fixtura — presny pocet normalizovanych fragmentov H7b');
  n++;
  assert.deepStrictEqual(g.counts, Object.assign({}, exp, { PRJBOX: 0 }),
                         name + ': dnesny kod — presny pocet fragmentov H7b (pole Projekt zaniklo)');
  const want = w.value;
  const got = g.value;
  assert.deepStrictEqual(Object.keys(got), Object.keys(want), name + ': rovnake pripady v rovnakom poradi');
  Object.keys(want).forEach(function(k){
    n++;
    assert.deepStrictEqual(got[k], want[k], name + ' / ' + k + ': spravanie sa zmenilo\n  cakam ' +
      JSON.stringify(want[k]).slice(0, 600) + '\n  dostal ' + JSON.stringify(got[k]).slice(0, 600));
  });
});

console.log('test_h14_golden: ' + n + ' kontrol OK');
