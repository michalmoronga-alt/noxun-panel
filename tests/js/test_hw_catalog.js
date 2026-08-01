// Testy V0.6 C-2: okno Katalog kovania (hw_catalog.js) — dependency-free Node.
// LEN ciste funkcie bez DOM: format ceny, label datumu overenia, patch/create
// payload buildery (XSS kontrakt: payload nesie len pole+hodnotu+row_rev,
// server whitelist je autorita) a zoradenie podla SERVEROVEHO searchu (F12).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mdhFmtPrice, mdhCheckedLabel, mdhPatchPayload, mdhOrderItems,
        mdhCreatePayload } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_catalog.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- mdhFmtPrice -------------------------------------------------------------
eq(mdhFmtPrice(4.18), '4.18 €', 'cena na 2 desatiny');
eq(mdhFmtPrice(4.1849), '4.18 €', 'zaokruhlenie');
eq(mdhFmtPrice(null), '—', 'nil = pomlcka (nezadana != 0)');
eq(mdhFmtPrice(undefined), '—', 'undefined = pomlcka');
eq(mdhFmtPrice(0), '0.00 €', 'nula je legalna cena');

// --- mdhCheckedLabel ---------------------------------------------------------
eq(mdhCheckedLabel('2026-08-01T00:12:33Z'), 'overené 1.8.2026', 'ISO -> SK datum');
eq(mdhCheckedLabel('2026-12-24T10:00:00+02:00'), 'overené 24.12.2026', 'aj s offsetom');
eq(mdhCheckedLabel(''), null, 'prazdne = nic');
eq(mdhCheckedLabel('vcera'), null, 'nevalidne = nic');
eq(mdhCheckedLabel(null), null, 'null = nic');

// --- mdhPatchPayload (XSS/server-autorita kontrakt) --------------------------
const p = mdhPatchPayload('104717', 'rev-abc', 'price_eur_vat', '4,30');
eq(p, { code: '104717', patch: { price_eur_vat: '4,30' }, row_rev: 'rev-abc' },
   'patch = kod + jedno pole + row_rev');
eq(Object.keys(p.patch).length, 1, 'vzdy len JEDNO pole (bunka)');
eq(mdhPatchPayload('X', null, 'notes', 'a').row_rev, '', 'chybajuci rev = prazdny (server conflict)');
const xss = mdhPatchPayload("1' onmouseover='x", 'r', 'name_sk', '<img src=x onerror=y>');
eq(xss.patch.name_sk, '<img src=x onerror=y>',
   'hodnota ide SUROVA (server normalizuje; DOM render je textContent)');
ok(!('item_code' in xss.patch) && !('use_count' in xss.patch),
   'payload nikdy nenesie identitu ani use_count');

// --- mdhCreatePayload --------------------------------------------------------
const c = mdhCreatePayload({ code: '99', name: 'Test', category: 'NOHY', unit: 'ks',
                             price: '1,5', supplier: 'Demos', notes: '' });
eq(c.fields.item_code, '99', 'kod z formulara');
eq(c.fields.category, 'NOHY', 'kategoria 1:1 (server enum validuje)');
ok(!('demos_url' in c.fields) && !('price_checked_at' in c.fields),
   'create NIKDY neposiela cache polia (server ich aj tak ignoruje)');

// --- mdhOrderItems (serverove poradie, F12) ----------------------------------
const MAP = { A: { item_code: 'A' }, B: { item_code: 'B' }, C: { item_code: 'C' } };
eq(mdhOrderItems(MAP, ['B', 'A']).map(i => i.item_code), ['B', 'A'],
   'poradie VYHRADNE zo servera');
eq(mdhOrderItems(MAP, ['B', 'ZMIZLA', 'C']).map(i => i.item_code), ['B', 'C'],
   'neznamy kod sa vynecha (polozka medzitym zmazana)');
eq(mdhOrderItems(MAP, []), [], 'prazdny vysledok = prazdno (JS nedoplna vlastne poradie)');
eq(mdhOrderItems({}, ['A']), [], 'prazdna mapa');

console.log(JSON.stringify({ passed: n, failed: 0 }));
