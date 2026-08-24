// PICKER-2 — RIADOK = DEKOR, hrúbka čipom.
//
// Michal 25.8.: „ten istý dekor mám v zozname trikrát — 18, 36 a duplák."
// Riadok ponuky je odteraz dekor a hrúbky toho istého TYPU dosky sú čipy.
// Čo sa tu stráži (a prečo to klikaním nezistíš skôr, než sa to stane v cene):
//   1. HRANICA JE TYP DOSKY. HDF 3 mm ani kompakt nie sú „tenšia verzia" DTDL
//      toho istého dekoru — sú to iné materiály s inou cenou aj spracovaním;
//      prepínač čipov nesmie zmeniť typ.
//   2. DUPLÁK SA NIKDY NEPREDVOLÍ. Je to zdvojená doska za dvojnásobok —
//      vyberá sa vedomým klikom, nie tým, že bol prvý v zozname.
//   3. Kontext výberu určuje predvolenú hrúbku (chrbát HDF 3, PD 38, inak
//      najtenšia konštrukčná) — ale ROZPÍSANÝ DOTAZ má prednosť.
//   4. Zlúčenie NESMIE schovať hrúbku pred hľadaním („36", „duplák").
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const NXC = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'nx_combo.js'));
const { nxComboDecorRows, nxComboDefaultVariant, nxComboChipFromQuery, nxComboHit,
        nxComboSections, nxComboRowIds } = NXC;

// --- fixtúra: dekor „Dub" v DTDL 18/36 + duplák, ten istý dekor v HDF 3 -----
const ITEMS = [
  { value: '', label: '(dediť z projektu)', disabled: false },
  { value: 'dtd18', label: 'Dub sonoma 18', disabled: false },
  { value: 'dtd36', label: 'Dub sonoma 36', disabled: false },
  { value: 'duplak2:dtd18', label: 'Dub sonoma (duplák x2)', disabled: false },
  { value: 'hdf3', label: 'Dub sonoma HDF 3', disabled: false },
  { value: 'komp12', label: 'Dub sonoma kompakt 12', disabled: false },
  { value: 'buk18', label: 'Buk 18', disabled: false }
];
// `key` = identita variantovej rodiny zo servera (`row_key`) — presne to,
// co drzi pohromade hrubky JEDNEHO materialu.
const META = {
  dtd18: { decor: 'Dub sonoma', type: 'DTDL', thickness: 18, key: 'G1|Dub|DTDL' },
  dtd36: { decor: 'Dub sonoma', type: 'DTDL', thickness: 36, key: 'G1|Dub|DTDL' },
  'duplak2:dtd18': { decor: 'Dub sonoma', type: 'DTDL', thickness: 36, duplak: true, key: 'G1|Dub|DTDL' },
  hdf3: { decor: 'Dub sonoma', type: 'HDF', thickness: 3, key: 'G1|Dub|HDF' },
  komp12: { decor: 'Dub sonoma', type: 'KOMPAKT', thickness: 12, key: 'G1|Dub|KOMPAKT' },
  buk18: { decor: 'Buk', type: 'DTDL', thickness: 18, key: 'G1|Buk|DTDL' }
};
const meta = v => META[v] || null;

// --- 1) zoskupenie: dekor + typ ---------------------------------------------
(function(){
  const rows = nxComboDecorRows(ITEMS, meta);
  const labels = rows.map(r => r.label);
  eq(labels, ['(dediť z projektu)', 'Dub sonoma', 'Dub sonoma', 'Dub sonoma', 'Buk'],
     'z troch DTDL variantov je JEDEN riadok; HDF a kompakt ostávajú vlastnými riadkami');

  const dtd = rows[1], hdf = rows[2], komp = rows[3], buk = rows[4];
  eq(dtd.variants.map(v => v.value), ['dtd18', 'dtd36', 'duplak2:dtd18'],
     'varianty sú od najtenšieho a DUPLÁK je vždy posledný');
  eq([hdf.type, komp.type], ['HDF', 'KOMPAKT'],
     'HDF ani kompakt sa do DTDL riadku NEZLÚČIA — sú to iné materiály, nie iná hrúbka');
  eq(hdf.variants.length, 1, 'jediná hrúbka = žiadna voľba');
  ok(!rows[0].decorRow, 'položka bez metadát („dediť") ostáva samostatná');
  eq(buk.variants.length, 1, 'iný dekor sa neprilepí');
  eq(dtd.value, 'dtd18', 'riadok vkladá NAJTENŠÍ variant, nie prvý zo zoznamu');
})();

// --- 1b) HRANICA RODINY: identitu určuje KATALÓG, nie dekor + typ ----------
// Review #231 P1: v SCHEMA 2 sa to isté číslo dekoru legálne opakuje u dvoch
// výrobcov, tá istá skupina má viac štruktúr a typy s formátom v identite
// (PD, zástena) sa líšia formátom alebo rubom. Keby sa také záznamy zlúčili,
// dva čipy s ROVNAKOU hrúbkou by boli nerozlíšiteľné — a vybral by sa cudzí
// výrobca, povrch, formát aj cena.
(function(){
  const items = [
    { value: 'a18', label: '5981 MG 18', disabled: false },
    { value: 'a36', label: '5981 MG 36', disabled: false },
    { value: 'b18', label: '5981 BS 18', disabled: false }
  ];
  // Rovnaký DEKOR aj TYP, iná rodina (iný výrobca / iná štruktúra).
  const m = { a18: { decor: '5981', type: 'DTDL', thickness: 18, key: 'MG|5981|DTDL' },
              a36: { decor: '5981', type: 'DTDL', thickness: 36, key: 'MG|5981|DTDL' },
              b18: { decor: '5981', type: 'DTDL', thickness: 18, key: 'BS|5981|DTDL' } };
  const rows = nxComboDecorRows(items, v => m[v]);
  eq(rows.length, 2, 'dve rodiny = dva riadky (nie jeden so zdvojenou 18)');
  eq(rows[0].variants.map(v => v.value), ['a18', 'a36'], 'zlúči sa len to, čo má rovnakú identitu');
  eq(rows[1].variants.map(v => v.value), ['b18'], 'cudzí výrobca ostáva sám');

  // Bez identity (starší payload) sa padá na dekor + typ — teda na správanie
  // spred opravy, nie na výnimku.
  const legacy = nxComboDecorRows(items, v => {
    const c = Object.assign({}, m[v]); delete c.key; return c;
  });
  eq(legacy.length, 1, 'bez `key` ostáva pôvodné zoskupenie podľa dekoru a typu');
})();

// --- 2) default podľa kontextu ----------------------------------------------
(function(){
  const rows = nxComboDecorRows(ITEMS, meta);
  const v = rows[1].variants;
  eq(nxComboDefaultVariant(v, null).value, 'dtd18', 'bez kontextu najtenšia konštrukčná');
  eq(nxComboDefaultVariant(v, 'body').value, 'dtd18', 'korpus tiež');
  eq(nxComboDefaultVariant(v, 'front').value, 'dtd18', 'čelá tiež');
  // Keď dekor kontextovú hrúbku NEMÁ, padá sa na najtenšiu konštrukčnú —
  // vymýšľať „najbližšiu hrubšiu" by bolo hádanie a človek by to zistil až
  // na cene. Čip si preklikne sám.
  eq(nxComboDefaultVariant(v, 'worktop').value, 'dtd18',
     'chýbajúca kontextová hrúbka = najtenšia konštrukčná, nie tipovanie');

  const pd = [{ value: 'pd38', thickness: 38, label: 'PD 38' },
              { value: 'pd18', thickness: 18, label: 'PD 18' }];
  eq(nxComboDefaultVariant(pd, 'worktop').value, 'pd38', 'pracovná doska predvolí 38');
  // Chrbát: 3 mm sa predvolí AJ KEĎ NIE JE najtenšia (HDF sa vyrába aj v 2,5).
  // Bez tejto fixtúry by test prešiel aj vtedy, keby vetva „back" vôbec
  // neexistovala — 3 mm je totiž zvyčajne najtenšia a padlo by to na default.
  const back = [{ value: 'h25', thickness: 2.5, label: 'HDF 2,5' },
                { value: 'h3', thickness: 3, label: 'HDF 3' },
                { value: 'h18', thickness: 18, label: 'DTD 18' }];
  eq(nxComboDefaultVariant(back, 'back').value, 'h3', 'chrbát predvolí 3 mm');
  eq(nxComboDefaultVariant(back, null).value, 'h25', 'bez kontextu by to bola 2,5 — vetva naozaj rozhoduje');

  // DUPLÁK sa nesmie predvoliť ANI vtedy, keď je najtenší v zozname.
  const dup = [{ value: 'd', thickness: 12, duplak: true, label: 'duplák 12' },
               { value: 'r', thickness: 18, label: 'DTD 18' }];
  eq(nxComboDefaultVariant(dup, null).value, 'r',
     'duplák sa NIKDY nepredvolí — ani keď je tenší');
  // Aj s kontextom: chrbát chce 3 mm, ale duplák 3 mm je stále duplák.
  const dupBack = [{ value: 'dd', thickness: 3, duplak: true }, { value: 'rr', thickness: 18 }];
  eq(nxComboDefaultVariant(dupBack, 'back').value, 'rr',
     'ani kontextová hrúbka duplák nepredvolí');
  // A v dekorovom riadku to musí platiť tiež (nielen v samotnej funkcii).
  const rowsDup = nxComboDecorRows(
    [{ value: 'd12', label: 'X duplák', disabled: false }, { value: 'r18', label: 'X 18', disabled: false }],
    v => ({ d12: { decor: 'X', type: 'DTDL', thickness: 12, duplak: true },
            r18: { decor: 'X', type: 'DTDL', thickness: 18 } })[v]);
  eq(rowsDup[0].value, 'r18', 'riadok vkladá reálnu dosku, nie duplák');
  eq(nxComboDefaultVariant([{ value: 'd', thickness: 36, duplak: true }], null).value, 'd',
     'ale keď je JEDINÝ, riadok bez hodnoty nezostane');
  eq(nxComboDefaultVariant([], null), null, 'prázdny zoznam nespadne');

  // Nedostupný variant sa nepredvolí, kým je po ruke použiteľný.
  const off = [{ value: 'x', thickness: 18, disabled: true }, { value: 'y', thickness: 36 }];
  eq(nxComboDefaultVariant(off, null).value, 'y', 'nedostupný variant sa preskočí');
})();

// --- 3) dotaz preselektuje čip ----------------------------------------------
(function(){
  const v = nxComboDecorRows(ITEMS, meta)[1].variants;
  eq(nxComboChipFromQuery('36', v), 1, '„36" ukáže na 36 mm');
  eq(nxComboChipFromQuery('duplák', v), 2, '„duplák" na duplákový variant');
  eq(nxComboChipFromQuery('DUPLAK', v), 2, 'aj bez diakritiky a veľkosťou písmen');
  eq(nxComboChipFromQuery('dub 36', v), 1, 'číslo sa nájde aj v dlhšom dotaze');
  eq(nxComboChipFromQuery('dub', v), -1, 'dotaz bez hrúbky čip nemení');
  eq(nxComboChipFromQuery('', v), -1, 'prázdny dotaz tiež nie');
  eq(nxComboChipFromQuery('99', v), -1, 'neexistujúca hrúbka nič nepreselektuje');
})();

// --- 4) hľadanie vidí hrúbky aj duplák --------------------------------------
(function(){
  const rows = nxComboDecorRows(ITEMS, meta);
  const dtd = rows[1];
  ok(nxComboHit(dtd, 'dub'), 'riadok sa nájde podľa dekoru');
  ok(nxComboHit(dtd, '36'), 'aj podľa hrúbky, ktorú nesie iba variant');
  ok(nxComboHit(dtd, 'duplak'), 'aj podľa slova „duplák"');
  ok(!nxComboHit(dtd, 'javor'), 'a cudzí dotaz ho nenájde');
  ok(!nxComboHit(rows[4], '36'), 'Buk (len 18) sa na „36" neukáže');
})();

// --- 5) skupiny „Použité v projekte" / „Naposledy použité" ------------------
// Zlúčenie sa nesmie prejsť cez tieto skupiny: projekt používa 36 mm, ale
// riadok vkladá 18 — keby sa členstvo posudzovalo podľa hodnoty riadku,
// dekor by zo skupiny ticho vypadol a človek by ho hľadal v celom katalógu.
(function(){
  const rows = nxComboDecorRows(ITEMS, meta);
  const secs = nxComboSections(rows, '', 'decor', ['dtd36'], []);
  const used = secs.filter(s => s.title === 'Použité v projekte')[0];
  ok(!!used, 'skupina vznikla, hoci projekt používa INÚ hrúbku, než riadok vkladá');
  eq(used.items.map(r => r.label), ['Dub sonoma'], 'a je v nej dekorový riadok');
  eq(used.items[0].value, 'dtd18',
     'predvolená hrúbka sa tým NEMENÍ — skupina je zaradenie, nie voľba za používateľa');

  // Naposledy použité: riadok sa radí podľa svojho NAJNOVŠIEHO variantu.
  // Fixtúra je zámerne taká, že dekorový riadok bol použitý PRV (cez variant
  // 36) — keby sa poradie počítalo z hodnoty riadku (18, ktorá v zozname nie
  // je), spadol by na koniec a „naposledy" by klamalo.
  const secs2 = nxComboSections(rows, '', 'decor', [], ['dtd36', 'buk18']);
  const rec = secs2.filter(s => s.title === 'Naposledy použité')[0];
  eq(rec.items.map(r => r.label), ['Dub sonoma', 'Buk'],
     'poradie drží použitie, nie katalóg — a riadok sa doň dostane cez variant');

  eq(nxComboRowIds(rows[1]), ['dtd18', 'dtd36', 'duplak2:dtd18'],
     'riadok zastupuje VŠETKY svoje varianty');
  eq(nxComboRowIds(rows[4]), ['buk18'], 'bežná položka samu seba');
})();

// --- 6) hľadanie podľa ID a katalógový duplák -------------------------------
(function(){
  const rows = nxComboDecorRows(ITEMS, meta);
  const dtd = rows[1];
  // Pred zlúčením sa hľadalo cez `value` KAŽDEJ položky, takže dotaz na
  // neprehľadné ID fungoval. Po zlúčení nesie riadok len hodnotu predvoleného
  // variantu — bez `searchExtra` by taký dotaz prestal fungovať (review #231).
  ok(nxComboHit(dtd, 'dtd36'), 'riadok sa nájde aj podľa ID nepredvoleného variantu');
  ok(nxComboHit(dtd, 'Dub sonoma 36'), 'aj podľa jeho pôvodného labelu');
  ok(!nxComboHit(dtd, 'buk18'), 'a cudzie ID ho nenájde');

  // ULOŽENÝ duplák má bežné `material_id` (pozná sa podľa `source_material_id`,
  // payload to zrkadlí ako `duplak`) — nesmie vyzerať ako kúpená hrubá doska.
  const stored = nxComboDecorRows(
    [{ value: 'x18', label: 'X 18', disabled: false }, { value: 'zx99', label: 'X duplák 36', disabled: false }],
    v => ({ x18: { decor: 'X', type: 'DTDL', thickness: 18, key: 'K' },
            zx99: { decor: 'X', type: 'DTDL', thickness: 36, duplak: true, key: 'K' } })[v]);
  eq(stored[0].value, 'x18', 'uložený duplák sa nepredvolí — hoci jeho ID nič neprezrádza');
  eq(stored[0].variants[1].value, 'zx99', 'v poradí je posledný');
  ok(nxComboHit(stored[0], 'duplak'), 'a nájde sa hľadaním „duplák"');
})();

console.log(`OK test_picker2_chips.js — ${n} kontrol`);
