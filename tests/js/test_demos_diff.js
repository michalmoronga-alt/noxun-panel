// Testy V0.6 B-2b: Demos diff modal (demos_diff.js) — dependency-free Node.
// Testuju sa LEN ciste funkcie bez DOM: session lifecycle eventov (ABA guard),
// checkbox defaulty (F16 — ON len prazdne pole), view sekcie, accepts payload
// (XSS kontrakt: NIKDY nenesie hodnoty, len flagy + row_rev) a helpery.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mddNewModel, mddApplyEvent, mddOffers, mddBuildView, mddRowRevOf,
        mddAccepts, mddStatusLabel, mddFmtPrice } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'demos_diff.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

function prop(over){
  return Object.assign({
    record_id: 'M1', kind: 'sheet', status: 'match',
    url: 'https://www.demos-trade.sk/x/',
    code: { old: null, 'new': '175718' },
    supplier: { old: null, 'new': 'Demos' },
    price: { old: null, 'new': 18.99, unit_src: 'ks', unchanged: false },
    warnings: []
  }, over || {});
}

// --- mddApplyEvent: session lifecycle (BLOCKER 5 zrkadlo v UI) ---------------
let m = null;
m = mddApplyEvent(m, { type: 'proposal', session: 3, proposal: prop() });
eq(m.session, 3, 'prvy event zalozi model so session');
eq(m.order.length, 1, 'proposal sa zaradi');
m = mddApplyEvent(m, { type: 'proposal', session: 2, proposal: prop({ record_id: 'STARY' }) });
eq(m.order.length, 1, 'event STARSEJ session sa zahodi (ABA)');
m = mddApplyEvent(m, { type: 'progress', session: 3, done: 1, total: 2 });
eq(m.progress, { done: 1, total: 2 }, 'progress sa uklada');
m = mddApplyEvent(m, { type: 'proposal', session: 3, proposal: prop({ record_id: 'M1', status: 'match' }) });
eq(m.order.length, 1, 'proposal toho isteho zaznamu sa NEduplikuje (replace)');
m = mddApplyEvent(m, { type: 'complete', session: 3, ok: true, warnings: ['w1'],
                       accessories: [{ code: '111' }] });
eq(m.complete, { ok: true, error: null }, 'complete stav');
eq(m.accessories.length, 1, 'prislusenstvo z complete');
m = mddApplyEvent(m, { type: 'proposal', session: 4, proposal: prop({ record_id: 'NOVY' }) });
eq(m.session, 4, 'NOVSIA session resetuje model');
eq(m.order, ['sheet|NOVY'], 'stare proposaly su prec');
eq(m.complete, null, 'complete sa resetol');
// sitemap refreshing flag
m = mddApplyEvent(m, { type: 'sitemap', session: 4, state: 'refreshing' });
eq(m.refreshing, true, 'refreshing flag');

// --- mddOffers: checkbox defaulty (F16) --------------------------------------
let o = mddOffers(prop());
eq(o.code.def, true, 'prazdny kod -> default ON');
eq(o.price.def, true, 'prazdna cena -> default ON');
o = mddOffers(prop({ code: { old: '999', 'new': '175718' },
                     price: { old: 12.5, 'new': 18.99, unchanged: false } }));
eq(o.code.def, false, 'obsadeny kod -> default OFF (vedomy prepis)');
eq(o.price.def, false, 'existujuca cena -> default OFF');
o = mddOffers(prop({ code: { old: '175718', 'new': '175718' } }));
eq(o.code, null, 'zhodny kod = ziadna ponuka kodu');
ok(o.price, 'cena sa stale ponuka');
o = mddOffers(prop({ price: { old: 18.99, 'new': 18.99, unchanged: true } }));
eq(o.confirm, { def: true }, 'nezmenena cena -> potvrdenie datumu default ON (hodnotu NEMENI)');
eq(o.price, null, 'unchanged nema price ponuku');
o = mddOffers(prop({ code: { old: '175718', 'new': '175718' },
                     price: { old: null, 'new': null, unchanged: false } }));
eq(o, null, 'ziadna ponuka = null (riadok ide do sekcie Bez zmeny)');
eq(mddOffers(prop({ status: 'miss' })), null, 'nie-match nema ponuky');

// --- mddBuildView: sekcie ----------------------------------------------------
m = null;
[prop(),                                                        // update (kod+cena)
 prop({ record_id: 'CLEAN', code: { old: 'X', 'new': 'X' },
        price: { old: null, 'new': null, unchanged: false } }), // clean
 prop({ record_id: 'MISS', status: 'miss' }),                   // attention + manual
 prop({ record_id: 'AMB', status: 'ambiguous', candidates: ['u1', 'u2'] }),
 prop({ record_id: 'DUP', status: 'skipped_duplak' })           // attention bez manualu
].forEach(function(p){ m = mddApplyEvent(m, { type: 'proposal', session: 1, proposal: p }); });
const view = mddBuildView(m);
eq(view.updates.length, 1, 'jedna navrhovana zmena');
eq(view.clean.length, 1, 'jeden bez zmeny');
eq(view.attention.length, 3, 'traja v pozornosti');
eq(view.attention.map(a => a.manual), [true, true, false],
   'manual URL input len pre miss/ambiguous (skip duplaku nie)');

// --- mddAccepts: LEN flagy + row_rev, NIKDY hodnoty (XSS/server autorita) ----
const CAT = { sheets: [{ material_id: 'M1', row_rev: 'rev-abc' }],
              edges: [{ abs_id: 'E1', row_rev: 'rev-edge' }] };
let accepts = mddAccepts(view, [{ key: 'sheet|M1', code: true, price: true }], CAT);
eq(accepts, [{ kind: 'sheet', id: 'M1', code: true, price: true, row_rev: 'rev-abc' }],
   'accepts = flagy + row_rev z katalogu');
ok(!('175718' in accepts[0]) && JSON.stringify(accepts).indexOf('18.99') < 0,
   'payload NENESIE hodnoty (kod ani cenu) — server ich berie z vlastneho store');
accepts = mddAccepts(view, [{ key: 'sheet|M1', code: false, price: false }], CAT);
eq(accepts, [], 'nic zaskrtnute = ziadna polozka');
accepts = mddAccepts(view, [], CAT);
eq(accepts, [], 'bez checkov nic');

// --- XSS kontrakt: payloady ostavaju v MODELI surove (render = textContent) --
const XSS = ['<img src=x onerror=alert(1)>', "1' onmouseover='alert(1)", '"</script><script>alert(1)</script>'];
m = null;
XSS.forEach(function(payload, i){
  m = mddApplyEvent(m, { type: 'proposal', session: 1, proposal: prop({
    record_id: 'X' + i, code: { old: null, 'new': payload },
    warnings: [payload] }) });
});
XSS.forEach(function(payload, i){
  const p = m.byKey['sheet|X' + i];
  eq(p.code['new'], payload, 'payload v modeli SUROVY — ziadna interpretacia/serializacia do HTML');
});
const accAll = mddAccepts(mddBuildView(m),
  [{ key: 'sheet|X0', code: true }, { key: 'sheet|X1', code: true }, { key: 'sheet|X2', code: true }],
  { sheets: [], edges: [] });
ok(JSON.stringify(accAll).indexOf('onerror') < 0 && JSON.stringify(accAll).indexOf('script') < 0,
   'XSS payloady sa do apply payloadu NIKDY nedostanu (len flagy)');

// --- helpery -----------------------------------------------------------------
eq(mddRowRevOf(CAT, 'sheet', 'M1'), 'rev-abc', 'row_rev dosky');
eq(mddRowRevOf(CAT, 'edge', 'E1'), 'rev-edge', 'row_rev pasky');
eq(mddRowRevOf(CAT, 'sheet', 'NEEXISTUJE'), '', 'neznamy zaznam = prazdny rev (server vrati conflict)');
ok(mddStatusLabel('miss').length > 0 && mddStatusLabel('skipped_duplak').indexOf('dupl') >= 0,
   'SK popisy stavov');
eq(mddStatusLabel('nieco-nove'), 'nieco-nove', 'neznamy stav sa ukaze doslovne');
eq(mddFmtPrice(18.994), '18.99 €', 'cena na 2 desatiny');
eq(mddFmtPrice(null), '—', 'nil cena = pomlcka');
ok(mddNewModel(7).session === 7 && mddNewModel(7).order.length === 0, 'cisty model');

console.log(JSON.stringify({ passed: n, failed: 0 }));
