// Testy V0.6 C-2: okno Katalog kovania (hw_catalog.js) — dependency-free Node.
// LEN ciste funkcie bez DOM: format ceny, label datumu overenia, patch/create
// payload buildery (XSS kontrakt: payload nesie len pole+hodnotu+row_rev,
// server whitelist je autorita) a zoradenie podla SERVEROVEHO searchu (F12).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mdhFmtPrice, mdhCheckedLabel, mdhPatchPayload, mdhOrderItems,
        hwItemCreatePayload, mdhCssEscape, mdhCapHint } =
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

// --- hwItemCreatePayload (KOV-B2: formular ZANIKOL, hodnoty dava MODAL) ------
const c = hwItemCreatePayload({ code: ' 99 ', name: ' Test ', category: 'NOHY', unit: 'ks',
                                price: '1,5', manufacturer: 'Hettich', series: 'Sensys',
                                notes: '' });
eq(c.fields.item_code, '99', 'kod z modalu (orezany — je to identita)');
eq(c.fields.name_sk, 'Test', 'nazov orezany');
eq(c.fields.category, 'NOHY', 'kategoria 1:1 (server enum validuje)');
// Review #290/2 P1: bez nacitanej taxonomie (tato sada bezi BEZ DOM, takze
// `MDH_TAX` je prazdna) sa klasifikacia NEPOSIELA — prazdny retazec by nad
// zaradenou polozkou zmazal vyrobcu aj radu. Nacitanu taxonomiu overuje
// `test_kovb2_katalog.js` (blok 19).
ok(!('manufacturer' in c.fields) && !('series' in c.fields),
   'nad nedostupnou taxonomiou klasifikacia v payloade NIE JE');
ok(!('demos_url' in c.fields) && !('price_checked_at' in c.fields),
   'create NIKDY neposiela cache polia (server ich aj tak ignoruje)');
ok(!('row_rev' in c.fields) && !('use_count' in c.fields),
   'nova polozka nenesie ani reviziu, ani pocitadlo pouzitia');

// --- mdhOrderItems (serverove poradie, F12) ----------------------------------
const MAP = { A: { item_code: 'A' }, B: { item_code: 'B' }, C: { item_code: 'C' } };
eq(mdhOrderItems(MAP, ['B', 'A']).map(i => i.item_code), ['B', 'A'],
   'poradie VYHRADNE zo servera');
eq(mdhOrderItems(MAP, ['B', 'ZMIZLA', 'C']).map(i => i.item_code), ['B', 'C'],
   'neznamy kod sa vynecha (polozka medzitym zmazana)');
eq(mdhOrderItems(MAP, []), [], 'prazdny vysledok = prazdno (JS nedoplna vlastne poradie)');
eq(mdhOrderItems({}, ['A']), [], 'prazdna mapa');

// --- mdhCssEscape (GH #100 P2 — kod v CSS selektore) -------------------------
eq(mdhCssEscape('104717'), '104717', 'bezny kod bez zmeny');
ok(mdhCssEscape('a"b').indexOf('"') === -1 || mdhCssEscape('a"b').indexOf('\\"') >= 0,
   'uvodzovka sa escapne');
ok(mdhCssEscape('x\\').endsWith('\\\\') || mdhCssEscape('x\\').indexOf('\\\\') >= 0,
   'koncove spatne lomitko sa escapne (nerozbije selektor)');
eq(mdhCssEscape(null), '', 'null = prazdny string');

console.log(JSON.stringify({ passed: n, failed: 0 }));

// --- V0.6 D2: Pridat z Demosu (ciste funkcie) --------------------------------
const { mdhDemosIsUrl, mdhDemosCreatePayload, mdhRelatedLine } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_catalog.js'));

eq(mdhDemosIsUrl('https://www.demos-trade.sk/zaves-x/'), true, 'URL sa pozna');
eq(mdhDemosIsUrl('zaves sensys'), false, 'text nie je URL');
eq(mdhDemosIsUrl('  HTTP://x  '), true, 'case/trim tolerantne');

// KOV-B2: klient nastavuje LEN to, co proposal nema — kategoriu, poznamku,
// vyrobcu a radu. Kod, nazov, cena a MJ ostavaju SERVER-OWNED (FIX 12).
eq(mdhDemosCreatePayload({ pid: 'p1', code: '357695', price_vat: 18.9 },
                         'ZAVESY', 'pozn', 'Hettich', 'Sensys'),
   { pid: 'p1', category: 'ZAVESY', notes: 'pozn',
     manufacturer: 'Hettich', series: 'Sensys' },
   'payload nesie len pid + kategoriu + poznamku + vyrobcu + radu');
ok(!('code' in mdhDemosCreatePayload({ pid: 'p1', code: '357695' }, '', '', '', '')) &&
   !('price_vat' in mdhDemosCreatePayload({ pid: 'p1', price_vat: 1 }, '', '', '', '')),
   'kod ani cena z klienta NIKDY neodchadzaju (FIX 12 z KOV-H1)');
eq(mdhDemosCreatePayload(null, '', '', '', ''),
   { pid: '', category: '', notes: '', manufacturer: '', series: '' },
   'bez proposalu bezpecne prazdne');

eq(mdhRelatedLine([{ code: '106412', name: 'podložka' }, { code: '105408', name: '' }]),
   'Súvisiaci sortiment: 106412 (podložka), 105408', 'related summary');
eq(mdhRelatedLine([]), null, 'bez related nic');

// --- TEST-1: OREZANY zoznam sa PRIZNAVA (zasada „no silent caps") -----------
// Nález z prvého testu v0.8.0: základný zoznam je serverový search s prázdnym
// dotazom a stropom, radený `score -> -use_count -> kód`. NOVÁ položka má
// use_count 0, takže vypadla za strop a z UI zmizla BEZ SLOVA — Michal ju po
// pridaní nenašiel a myslel si, že sa neuložila.
eq(mdhCapHint(137, 50), 'Zobrazených 50 z 137 položiek — hľadaj alebo filtruj kategóriou.',
   'orezanie sa povie číslom, nie mlčaním');
eq(mdhCapHint(12, 12), null, 'nič sa neorezalo = žiadny šum');
eq(mdhCapHint(0, 0), null, 'prázdny katalóg nehlási orezanie');
eq(mdhCapHint(50, 137), null, 'nezmyselné poradie (shown > total) radšej mlčí než klame');
eq(mdhCapHint(null, null), null, 'chýbajúce čísla = nič');
