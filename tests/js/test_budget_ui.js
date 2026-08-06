// Testy E-b (tab Rozpocet + okno Nastavenia) — CISTE funkcie budget.js
// a supplier_settings.js. DOM sa netestuje; kluc je, ze:
//   - JS NEPOCITA sumy (jedina aritmetika = zobrazovaci prepocet DPH),
//   - upozornenia sa len TRIEDIA z payloadu (texty sklada server),
//   - mutacie nesu identitu (gen + model_guid),
//   - patch nastaveni posiela LEN zmenene polia.
'use strict';
const assert = require('assert');
const path = require('path');
const B = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'budget.js'));
const S = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'supplier_settings.js'));

let passed = 0;
function eq(a, b, msg){ assert.deepStrictEqual(a, b, msg); passed += 1; }
function ok(c, msg){ assert.ok(c, msg); passed += 1; }
function close(a, b, msg){ assert.ok(Math.abs(a - b) < 0.005, msg + ' (' + a + ' vs ' + b + ')'); passed += 1; }

// --- formatovanie sum ---------------------------------------------------------
(function(){
  // Oddelovac tisicov je NEZALOMITELNA medzera (U+00A0) — v teste explicitne.
  eq(B.budFmtEur(1323.1), '1 323,10 €', 'tisice nezalomitelnou medzerou, desatinna ciarka');
  eq(B.budFmtEur(0), '0,00 €', 'nula je platna suma');
  eq(B.budFmtEur(null), '—', 'nezadana cena NIKDY nie je 0');
  eq(B.budFmtEur(undefined), '—', 'undefined = pomlcka');
  eq(B.budFmtEur(-12.5), '−12,50 €', 'zaporna suma (zlava/dorovnanie)');
  eq(B.budFmtNum(70.94, 1), '70,9', 'bm na jedno desatinne miesto');
  eq(B.budFmtNum(null, 1), '—', 'chybajuce mnozstvo = pomlcka');
})();

// --- DPH: JEDINA povolena aritmetika -----------------------------------------
(function(){
  eq(B.budDisplay(123, true, 1.23), 123, 's DPH sa cislo NIKDY nemeni');
  close(B.budDisplay(123, false, 1.23), 100, 'bez DPH = delenie divisorom z payloadu');
  eq(B.budDisplay(null, false, 1.23), null, 'nezadana suma ostava nezadana');
  eq(B.budDisplay(50, false, 0), 50, 'nezmyselny divisor nesmie cislo pokazit');
  eq(B.budDisplay(50, false, undefined), 50, 'chybajuci divisor = cislo bez zmeny');
})();

// --- slovenske sklonovanie ----------------------------------------------------
(function(){
  const f = ['cena', 'ceny', 'cien'];
  eq(B.budPluralSk(1, f), 'cena', '1');
  eq(B.budPluralSk(3, f), 'ceny', '2-4');
  eq(B.budPluralSk(7, f), 'cien', '5+');
  eq(B.budPluralSk(0, f), 'cien', '0 ide do mnozneho tvaru');
})();

// --- pas cenovej cerstvosti ---------------------------------------------------
(function(){
  eq(B.budStaleLabel({ stale_days: 30, counts: { stale: 0 } }), null, 'ziadna stara cena = ziadny chip');
  eq(B.budStaleLabel({ stale_days: 30, counts: { stale: 3 } }),
     '3 ceny staršie ako 30 dní', 'text pasu cenovej cerstvosti');
  eq(B.budStaleLabel({ stale_days: 45, counts: { stale: 1 } }),
     '1 cena staršia ako 45 dní', 'jednotne cislo');
  eq(B.budStaleLabel({}), null, 'prazdny payload nezhodi render');
})();

// --- tri oranzove upozornenia (mock v4) ---------------------------------------
function payload(over){
  const base = {
    stale: { stale_days: 30, counts: { stale: 2 }, items: [{ kind: 'sheet', id: 'X', label: 'X', state: 'stale', age_days: 34 }] },
    totals: { appliances_subtotal: 649, appliances_included: false },
    budget_check: [
      { stable_key: 'budget|custom:1|missing_price', section: 'custom', message: 'Položka bez ceny.' },
      { stable_key: 'budget|appliances|not_included', section: 'appliances', message: 'Spotrebiče nie sú v súčte.' }
    ]
  };
  return Object.assign(base, over || {});
}

(function(){
  const chips = B.budWarnChips(payload());
  eq(chips.length, 3, 'tri chipy: stare ceny + spotrebice + zvysne upozornenia');
  eq(chips[0].id, 'stale', 'prvy je pas cenovej cerstvosti');
  eq(chips[1].id, 'appl', 'druhy su spotrebice');
  eq(chips[1].included, false, 'spotrebice mimo suctu');
  eq(chips[1].amount, 649, 'suma spotrebicov ide z payloadu, JS ju neskladá');
  eq(chips[2].count, 1, 'spotrebicove upozornenie sa v tretom chipe NEopakuje');
  eq(chips[2].text, '1 upozornenie rozpočtu', 'sklonovany text chipu');
})();

(function(){
  const chips = B.budWarnChips(payload({ totals: { appliances_subtotal: 649, appliances_included: true } }));
  eq(chips[1].included, true, 'zapnute spotrebice = informacny variant');
})();

(function(){
  const chips = B.budWarnChips(payload({ totals: { appliances_subtotal: 0 }, budget_check: [] }));
  eq(chips.length, 1, 'bez spotrebicov a bez nalezov ostane len pas cerstvosti');
  eq(B.budWarnChips({}).length, 0, 'prazdny rozpocet = ziadne chipy');
  eq(B.budWarnChips(null).length, 0, 'null payload nezhodi render');
})();

// --- mutacie: identita zapisu -------------------------------------------------
(function(){
  const bom = { gen: 7, model_guid: 'GUID-1' };
  eq(B.budMutation(bom, 'mode', { mode: 'vysoky' }),
     { op: 'mode', gen: 7, model_guid: 'GUID-1', mode: 'vysoky' }, 'kazda mutacia nesie gen aj model_guid');
  eq(B.budMutation(null, 'viz_m2', { value: 10 }),
     { op: 'viz_m2', gen: 0, model_guid: '', value: 10 }, 'bez payloadu server zapis odmietne (gen 0)');
})();

// --- vstupy poli --------------------------------------------------------------
(function(){
  eq(B.budParse('1 200,50'), 1200.5, 'desatinna ciarka aj medzera v tisicoch');
  eq(B.budParse(''), null, 'prazdne pole = zrus prepis / vrat default');
  eq(B.budParse('   '), null, 'biele znaky = prazdne');
  ok(isNaN(B.budParse('abc')), 'necislo sa NEposiela ako 0');
  eq(B.budParse('0'), 0, 'nula je platny vstup (nulovy riadok ostava)');
  eq(B.budNumText(1200.5), '1200,5', 'do pola sa pise s ciarkou');
  eq(B.budNumText(null), '', 'nezadana hodnota = prazdne pole');
})();

// --- popisky sekcii (ziadna aritmetika nad sumami) ----------------------------
(function(){
  const sec = { key: 'materials', rows: [{}, {}, {}] };
  eq(B.budSectionCount(sec, {}), '3 položky', 'pocitadlo je dlzka pola, nie sucet');
  eq(B.budSectionCount({ key: 'standard_rows', rows: [{}] }, { mode_label: 'Štandard' }),
     '1 položka · režim Štandard', 'standardne riadky ukazuju rezim');
  eq(B.budSectionCount({ key: 'custom', rows: [] }, {}), 'len táto zákazka', 'vlastne polozky');
  eq(B.budSectionCount({ key: 'appliances', rows: [] }, {}), 'manuálne · katalóg príde v S1', 'spotrebice');
})();

// --- GH #138 P2: rozpisany novy riadok prezije odmietnuty zapis ---------------
(function(){
  eq(B.budDraftAttrs('custom', { popis: 'Doprava', cena: '42,5' }),
     { popis: 'Doprava', pocet: '1', cena: '42,5' }, 'chybajuci pocet ma default 1');
  eq(B.budDraftAttrs('custom', { popis: 'X', pocet: '3', cena: '' }),
     { popis: 'X', pocet: '3', cena: '' }, 'prazdna cena ostava prazdna (nie 0)');
  eq(B.budDraftAttrs('appliance', { nazov: 'Bosch', cena: '649' }),
     { typ: 'ine', nazov: 'Bosch', dodavatel: '', cena: '649' }, 'chybajuci typ padne na „iné"');
  eq(B.budDraftAttrs('custom', null), { popis: '', pocet: '1', cena: '' }, 'prazdny formular nezhodi render');
})();

(function(){
  eq(B.budDraftMissing('custom', { popis: '  ' }), 'Popis položky je povinný.', 'popis je povinny');
  eq(B.budDraftMissing('custom', { popis: 'X' }), null, 'so popisom mozeme odoslat');
  eq(B.budDraftMissing('appliance', { nazov: '' }), 'Názov spotrebiča je povinný.', 'nazov je povinny');
  eq(B.budDraftMissing('appliance', { nazov: 'Bosch' }), null, 'so nazvom mozeme odoslat');
  // Rozsahy a typy strazi SERVER — klient necislo NEblokuje, len ho posle
  // a pri odmietnutí ostanú hodnoty v drafte.
  eq(B.budDraftMissing('custom', { popis: 'X', cena: 'abc' }), null, 'cenu validuje server, nie klient');
})();

// --- E-b2: kontrolny pas cenovej ponuky ---------------------------------------
// `consistent` pocita SERVER (zostava je automaticky zvysok) — JS z neho len
// sklada text. Ziadna aritmetika nad sumami.
(function(){
  eq(B.budCpBand({ consistent: true, diff: 0, total: 18800 }),
     { ok: true, text: 'CP = Rozpočet' }, 'zhoda = zeleny pas');
  eq(B.budCpBand({ consistent: false, diff: -675.6 }),
     { ok: false, text: 'CP nesedí s rozpočtom o −675,60 €' }, 'nesulad sa musi ukazat s rozdielom');
  eq(B.budCpBand({ consistent: true, assembly_negative: true }).ok, false,
     'zaporna zostava je tiez chyba, aj ked suma sedi');
  // GH #139 P1: riadok bez ceny do suctu nevstupuje — ponuka by bola podhodnotena.
  eq(B.budCpBand({ consistent: true, complete: false, unknown_count: 2 }),
     { ok: false, text: 'Suma ponuky je podhodnotená — 2 riadky rozpočtu nemajú cenu' },
     'neuplna suma sa musi ukazat');
  eq(B.budCpBand({ consistent: true, complete: false, unknown_count: 1 }).text,
     'Suma ponuky je podhodnotená — 1 riadok rozpočtu nemá cenu', 'sklonovanie 1 riadok');
  eq(B.budCpBand({ consistent: true, complete: true }).ok, true, 'uplna suma = zeleny pas');
  eq(B.budCpBand({}), { ok: true, text: 'CP = Rozpočet' }, 'chybajuce polia nezhodia render');
  eq(B.budCpBand(null).ok, true, 'null payload nezhodi render');
})();

// --- E-b2: render nahladu CP (data VYHRADNE z payloadu, ziadny vypocet) -------
(function(){
  const cp = {
    total: 18800, budget_total: 18800, diff: 0, consistent: true, threshold: 150,
    total_label: 'SPOLU',
    rows: [
      { key: 'cp:assembly', polozka: 'Nábytková zostava', cena: 7778, mnozstvo: 1, mj: 'set', kind: 'assembly' },
      { key: 'cp:item:hw:317642', polozka: 'VÝSUVY Quadro', cena: 1157, mnozstvo: 30, mj: 'set',
        kind: 'item', source_key: 'hw:317642' },
      { key: 'cp:zameranie', polozka: 'Zameranie', cena: 0, mnozstvo: 1, mj: 'set', kind: 'fixed' }
    ],
    candidates: [
      { source_key: 'hw:317642', label: 'VÝSUVY Quadro', amount: 1157, state: 'samostatne' },
      { source_key: 'custom:U1', label: 'LED <b>pás</b>', amount: 85, state: 'zostava', overridden: true }
    ]
  };
  const h = B.budCpHtml({ cp_preview: cp, vat_divisor: 1.23 }, 1.23);
  ok(h.indexOf('Cenová ponuka — náhľad') > -1, 'sekcia ma nadpis');
  ok(h.indexOf('CP = Rozpočet') > -1, 'kontrolny pas');
  ok(h.indexOf('Nábytková zostava') > -1 && h.indexOf('VÝSUVY Quadro') > -1, 'riadky CP');
  ok(h.indexOf('data-bud="cp_group" data-source="hw:317642" data-group="zostava"') > -1,
     'samostatny riadok ponuka zlucenie do zostavy');
  ok(h.indexOf('data-group="samostatne"') > -1, 'zlucena polozka sa da vytiahnut');
  ok(h.indexOf('Zlúčené v zostave (1)') > -1, 'zoznam zlucenych je zbaleny a spocitany');
  ok(h.indexOf('LED &lt;b&gt;pás&lt;/b&gt;') > -1, 'nazvy polozek su escapovane');
  ok(h.indexOf('<b>pás</b>') === -1, 'ziadne surove HTML z dat');
  eq(B.budCpHtml({}, 1.23), '', 'bez cp_preview sa sekcia nevykresli');
  eq(B.budCpHtml(null, 1.23), '', 'null payload nezhodi render');
})();

// --- XSS: data do innerHTML idu VZDY escapovane -------------------------------
(function(){
  eq(B.budEsc('<img src=x onerror=alert(1)>'),
     '&lt;img src=x onerror=alert(1)&gt;', 'znacky sa neutralizuju');
  eq(B.budEsc('a & "b"'), 'a &amp; &quot;b&quot;', 'ampersand aj uvodzovky');
  eq(B.budEsc(null), '', 'null = prazdny retazec');
})();

// --- NASTAVENIA: patch posiela LEN zmenene polia ------------------------------
(function(){
  const r = S.ssBuildPatch({ 'rate:olep': '0,95', 'scalar:stale_days': '45' });
  eq(r.errors, [], 'platne hodnoty bez chyb');
  eq(r.patch, { rates: { olep: 0.95 }, stale_days: 45 }, 'do patchu ide len to, co sa zmenilo');
})();

(function(){
  const r = S.ssBuildPatch({ 'mode:doprava_zakaznik:vysoky': '', 'row:balne': '120' });
  eq(r.errors, [], 'prazdna rezimova hodnota je legalna');
  eq(r.patch, { mode_values: { doprava_zakaznik: { vysoky: null } }, standard_rows: { balne: { rate: 120 } } },
     'prazdny rezim = null (zmazanie), sadzba riadku ide do standard_rows');
})();

(function(){
  const r = S.ssBuildPatch({ 'rate:olep': 'x' });
  ok(r.errors.length > 0, 'necislo sa nesmie odoslat');
  eq(r.patch, {}, 'chybny vstup nesmie poslat nic');
  const empty = S.ssBuildPatch({ 'rate:olep': '' });
  ok(empty.errors.length > 0, 'zakladna sadzba nesmie byt prazdna');
  eq(S.ssBuildPatch({}).patch, {}, 'bez zmien = prazdny patch');
})();

(function(){
  eq(S.ssNumText(0.9), '0,9', 'sadzba do formulara s ciarkou');
  eq(S.ssNumText(null), '', 'nezadana hodnota = prazdne pole');
  eq(S.ssParse('17,00'), 17, 'ciarka aj desatinne nuly');
})();

console.log('test_budget_ui.js: ' + passed + ' OK');
