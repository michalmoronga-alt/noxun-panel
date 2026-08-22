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

// --- E-c: PREPOCITAT CENY (vyber cielov, progres, report) ---------------------
// JS NEROZHODUJE, co sa stiahne — server si ciele sklada z cerstveho rozpoctu
// sam; tieto funkcie su ZRKADLO pre potvrdenie a zobrazenie.
(function(){
  const b = { stale: { items: [
    { kind: 'sheet', id: 'S1', label: 'H3303 DTDL 18', state: 'stale', age_days: 44,
      demos_url: 'https://www.demos-trade.sk/a/' },
    { kind: 'sheet', id: 'S1', label: 'H3303 DTDL 18', state: 'stale', age_days: 44,
      demos_url: 'https://www.demos-trade.sk/a/' },
    { kind: 'edge', id: 'A1', label: 'ABS H3303 22×1', state: 'unverified',
      demos_url: 'https://www.demos-trade.sk/b/' },
    { kind: 'hardware', id: '104717', label: 'Záves Sensys', state: 'stale', age_days: 60,
      demos_url: 'https://www.demos-trade.sk/c/' },
    { kind: 'sheet', id: 'S9', label: 'Ručná doska', state: 'manual' }
  ] } };
  const t = B.budPrTargets(b);
  eq(t.map(function(x){ return x.id; }), ['S1', 'A1', '104717'],
     'len viazane polozky, dedup podla (kind,id)');
  eq(B.budPrTargets({ stale: { items: [] } }), [], 'prazdny scan = nic na obnovu');
  eq(B.budPrTargets(null), [], 'chybajuci payload nezhodi render');
})();

(function(){
  eq(B.budPrEta(0), 'približne 0 s', 'nulovy odhad');
  eq(B.budPrEta(5), 'približne 20 s', '4 s na polozku (3 s pauza + fetch)');
  eq(B.budPrEta(30), 'približne 2 minúty', 'nad 90 s sa prepocita na minuty');
  eq(B.budPrEta(15), 'približne 1 minútu', 'sklonovanie 1');
  ok(B.budPrConfirmText({ total: 5 }).indexOf('Obnoviť 5 cien') > -1, 'potvrdenie nesie pocet');
  ok(B.budPrConfirmText({ total: 5 }).indexOf('3 s pauza') > -1, 'potvrdenie priznava crawl-delay');
  ok(B.budPrConfirmText({ total: 1, single: { label: 'ABS H3303' } }).indexOf('ABS H3303') > -1,
     'jedna polozka sa pyta menom');
  eq(B.budPrTitle({ phase: 'run' }), 'Sťahujem ceny z Demosu', 'titulok podla fazy');
  eq(B.budPrTitle({ phase: 'report' }), 'Prepočet cien — výsledok', 'titulok reportu');
})();

// Pending pid guard: kym nepride `start`, stav pid nema; potom sa beru LEN
// eventy TOHO behu (oneskoreny event stareho behu nesmie prepisat novy).
(function(){
  let s = { phase: 'run', pid: null, total: 3, done: 0, label: '', report: null,
            single: null, cancelling: false };
  s = B.budPrEvent(s, { type: 'progress', pid: 7, done: 1, total: 3, label: 'X' });
  eq(s.done, 0, 'event pred `start` sa ignoruje (pid este nepoznam)');
  s = B.budPrEvent(s, { type: 'start', pid: 7, total: 3 });
  eq([s.phase, s.pid, s.total], ['run', 7, 3], '`start` je autorita pid aj poctu');
  s = B.budPrEvent(s, { type: 'progress', pid: 7, done: 1, total: 3, label: 'H3303' });
  eq([s.done, s.label], [1, 'H3303'], 'progres nesie prave stahovanu polozku');
  s = B.budPrEvent(s, { type: 'progress', pid: 99, done: 3, total: 3, label: 'cudzie' });
  eq([s.done, s.label], [1, 'H3303'], 'event CUDZIEHO behu sa zahodi');
  s = B.budPrEvent(s, { type: 'item', pid: 7, done: 2, total: 3 });
  eq(s.done, 2, 'item posuva pocitadlo');
  s = B.budPrEvent(s, { type: 'complete', pid: 7, report: { changed: 1 } });
  eq([s.phase, s.report.changed], ['report', 1], 'complete prepne na report');
  const late = B.budPrEvent(s, { type: 'complete', pid: 4, report: { changed: 9 } });
  eq(late.report.changed, 1, 'oneskoreny complete stareho behu report neprepise');
})();

// GH #140 P2: odmietnuty START musi okno ODOMKNUT — klient prepne modal do
// „bezi" hned po kliku, takze bez terminalneho eventu by ostal zamknuty.
(function(){
  const pending = { phase: 'run', pid: null, total: 3, done: 0, label: '', report: null,
                    single: null, cancelling: false };
  eq(B.budPrEvent(pending, { type: 'rejected', error: 'Model sa medzitým prepol' }), null,
     'odmietnuty start zavrie modal a odomkne tlacidlo');
  eq(B.budPrEvent(null, { type: 'rejected', error: 'x' }), null, 'bez stavu sa nic nerozbije');
  const running = { phase: 'run', pid: 7, total: 3, done: 1, label: 'X', report: null,
                    single: null, cancelling: false };
  eq(B.budPrEvent(running, { type: 'rejected', error: 'x' }), running,
     'BEZIACI prepocet (uz ma pid) sa odmietnutim iného startu NEDA zabit');
})();

(function(){
  const report = { total: 4, done: 4, skipped: 0, cancelled: false, changed: 2, unchanged: 1, errors: 1,
    items: [
      { kind: 'sheet', id: 'S1', label: 'H3303 DTDL 18', status: 'changed',
        old_price: 15, new_price: 18.99, diff: 3.99 },
      { kind: 'edge', id: 'A1', label: 'ABS H3303', status: 'changed',
        old_price: 0.9, new_price: 0.8, diff: -0.1 },
      { kind: 'sheet', id: 'S2', label: 'W1000', status: 'unchanged', old_price: 13, new_price: 13 },
      { kind: 'hardware', id: '104717', label: 'Záves <b>Sensys</b>', status: 'error',
        error: 'stránka patrí kódu 999999' }
    ] };
  const s = B.budPrSummary(report);
  eq([s.changed.length, s.errors.length, s.unchanged], [2, 1, 1], 'riadky sa len triedia');
  eq(s.text, '2 ceny zmenené · 1 bez zmeny · 1 chyba', 'zhrnutie zo serverovych poctov');
  eq(B.budPrSummaryText({ changed: 0, unchanged: 0, errors: 0 }), '0 cien zmenených',
     'nic sa nezmenilo = cisty text');
  eq(B.budPrSummaryText({ changed: 1, unchanged: 2, errors: 0, cancelled: true, skipped: 5 }),
     '1 cena zmenená · 2 bez zmeny · zrušené — 5 preskočených', 'zrusenie sa priznava');
  eq(B.budPrDiffText({ diff: 3.99 }), '+3,99 €', 'zdrazenie s plusom');
  eq(B.budPrDiffText({ diff: -0.1 }), '−0,10 €', 'zlacnenie s minusom (typograficky)');
  eq(B.budPrDiffText({}), '', 'bez rozdielu ziadny text');
  const h = B.budPrReportHtml(report);
  ok(h.indexOf('15,00 € → 18,99 €') > -1, 'stara -> nova cena');
  ok(h.indexOf('stránka patrí kódu 999999') > -1, 'dovod chyby je v reporte');
  ok(h.indexOf('Záves &lt;b&gt;Sensys&lt;/b&gt;') > -1, 'nazvy su escapovane');
  ok(h.indexOf('<b>Sensys</b>') === -1, 'ziadne surove HTML z dat');
})();

(function(){
  eq(B.budPrProgressText({ total: 12, done: 3, label: 'ABS H3303' }), 'Sťahujem 4 z 12 · ABS H3303',
     'progres hovori, co sa prave stahuje');
  eq(B.budPrProgressText({ total: 3, done: 3, label: '' }), 'Sťahujem 3 z 3',
     'posledna polozka nepretecie nad total');
  eq(B.budPrProgressText({ total: 5, done: 2, cancelling: true }),
     'Ukončujem — dobehne ešte rozbehnutá položka…', 'Zrusit nezahadzuje rozbehnutu polozku');
  ok(B.budPrProgressHtml({ total: 4, done: 1 }).indexOf('width:25%') > -1, 'pas ukazuje podiel');
})();

// Zoznam starych cien: viazany riadok ma mini akciu, nevaizany len odporucanie.
(function(){
  const bound = B.budStaleActionHtml({ kind: 'sheet', id: 'S1', label: 'H3303',
                                       demos_url: 'https://www.demos-trade.sk/a/' });
  ok(bound.indexOf('data-bud="refresh_one"') > -1, 'viazany riadok ma akciu „obnoviť túto"');
  ok(bound.indexOf('data-kind="sheet"') > -1 && bound.indexOf('data-id="S1"') > -1,
     'akcia nesie identitu polozky');
  ok(bound.indexOf('#i-refresh-cw') > -1, 'sprite ikona (ziadne emoji)');
  const manual = B.budStaleActionHtml({ kind: 'sheet', id: 'S9', label: 'Ručná', state: 'manual' });
  eq(manual.indexOf('data-bud'), -1, 'polozka bez vazby sa NEDA stiahnut');
  ok(manual.indexOf('over v katalógu ručne') > -1, 'namiesto akcie odporucanie');
})();

// --- ŠT-1c PR B1: rozrezany render (LISTA sekcie vs TELO) --------------------
// Š12 hovori „1:1" o OBSAHU, nie o kode: v Studiu su lista a telo dve rozne
// miesta v DOM, takze render sa musel rozdelit. Tieto testy strazia, ze sa pri
// tom nic nestratilo a nic sa NEZDVOJILO (dva prepinace DPH by boli horsie nez
// ziadny — kazdy by ukazoval iny stav).
(function(){
  const B_BUDGET = { mode: 'nizky', mode_label: '€', vat_divisor: 1.23,
                     totals: { total: 1000, total_novat: 813.01 }, budget_check: [] };
  const tools = B.budToolsHtml(B_BUDGET);
  ok(tools.indexOf('data-bud="vat"') > -1, 'prepinac DPH je v LISTE sekcie');
  ok(tools.indexOf('data-bud="mode"') > -1, 'a rezim €·€€·€€€ tiez');
  ok(tools.indexOf('data-bud="refresh"') > -1, '„Prepočítať ceny" je v liste');
  ok(tools.indexOf('id="refreshBtn"') > -1,
     'a „Obnoviť" — prestavba skrinky z Inspectora sem sama nedorazi');
  ok(tools.indexOf('data-bud="xlsx"') > -1 && tools.indexOf('data-bud="cp"') > -1,
     'oba exporty su v liste (kontrakt §3 — akcie sekcie patria do listy)');
  ok(tools.indexOf('data-bud="settings"') > -1, '⚙ ostava ako kontextova skratka (#20)');
  ok(tools.indexOf('<span class="spacer">') > -1, 'exporty su az za medzerou (vpravo)');

  // Rezim sa berie z PAYLOADU (server je autorita) — nie z klientskej pamate.
  ok(B.budToolsHtml({ mode: 'vysoky' }).indexOf('data-v="vysoky" data-bkey="mode:vysoky"') > -1,
     'aktivny rezim sa cita z payloadu');
  ok(B.budModeSegHtml({ mode: 'vysoky' }).indexOf('class="on" data-bud="mode" data-v="vysoky"') > -1,
     'a je oznaceny ako zapnuty');
  eq(B.budToolsHtml(null).indexOf('class="on" data-bud="mode"'), -1,
     'chybajuci payload nezhodi listu a ziadny rezim nepodsvieti');

  // Fokus prezije prekreslenie aj v LISTE — tlacidla nesu `data-bkey`.
  ok(tools.indexOf('data-bkey="vat:1"') > -1 && tools.indexOf('data-bkey="mode:nizky"') > -1,
     'polia listy nesu kluc pre obnovu fokusu');

  // Pocas behu prepoctu je tlacidlo zamknute — ale LEN ono.
  const sum = B.budSummaryHtml(B_BUDGET, 1.23);
  eq(sum.indexOf('data-bud="vat"'), -1, 'telo uz prepinac DPH NEMA (zdvojenie by klamalo)');
  eq(sum.indexOf('data-bud="mode"'), -1, 'ani prepinac rezimu');
  ok(sum.indexOf('class="btotal"') > -1, 'zato nesie VELKY SUCET zakazky');
  ok(sum.indexOf('režim €') > -1, 'a povie, v ktorom rezime cislo plati');
  eq(sum.indexOf('class="bfoot"'), -1, 'patka s exportmi zanikla (su v liste)');
})();

// Jantarovy chip suctu vedie do KONTROLY (ten isty nalez, jedno miesto).
(function(){
  const chip = B.budChipHtml({ id: 'check', count: 2, text: '2 upozornenia rozpočtu' }, {}, 1.23);
  ok(chip.indexOf('data-bud="ctrl"') > -1, 'chip vedie do sekcie Kontrola');
  eq(chip.indexOf('data-bud="warns"'), -1, 'uz nerozbaluje DRUHU kopiu zoznamu nalezov');
  const appl = B.budChipHtml({ id: 'appl', included: false, amount: 649 }, {}, 1.23);
  ok(appl.indexOf('data-bud="goto" data-section="appliances"') > -1,
     'spotrebicovy chip stale skace na svoju sekciu rozpoctu');
})();

console.log('test_budget_ui.js: ' + passed + ' OK');
