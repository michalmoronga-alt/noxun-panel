// H4a · D-04 + D-11 (triedenie HARDENING, blok 9): JEDEN zápis čísel
// a jednotiek v okne Štúdio + ABS „dookola" v Kusovníku.
//
// Mení sa LEN ZÁPIS — hodnoty, payload, XLSX, CSV ani VEPO nie (charakterizácia:
// diff vetvy nesiaha na Ruby a zlaté/exportné sady ostali bez zmeny fixtúr —
// PR popis a KRONIKA, dávka H4a). Tu:
//   T1 tabuľka vstup → výstup formátovača `nxf*` (studio.js),
//   T2 zhoda `nxfMoney ≡ budFmtEur` (200 hodnôt) a `nxfMm ≡ mmLabel` (Inspector),
//   T3 okružná cesta peňažného poľa `budParse(nxfMoneyIn(x)) === x`,
//   T4 render riadkov Rozpočtu (bm, platne, paušály, MJ malým, pole „68,00" + €),
//   T5 Kusovník (hrúbka 18,6, ABS „0,8 mm", bm 2 desatinné) a žiadna desatinná
//      BODKA vo viditeľnom texte Rozpočtu, Kusovníka a Materiálov,
//   T6 D-11 „0,8 dookola" len pri štyroch hranách s TOU ISTOU páskou.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
const B = require(path.join(JS, 'budget.js'));
const C = require(path.join(JS, 'core.js'));
const M = require(path.join(JS, 'proj_materials.js'));

const NB = '\u00A0';   // nezalomiteľná medzera (tisíce)
const MINUS = '\u2212';

// Viditeľný text HTML reťazca (bez značiek a atribútov) — vzor textContent.
function visible(html){
  return String(html).replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
}
const DOT = /\d\.\d/;

// --- T1: tabuľka vstup → výstup ------------------------------------------------
(function(){
  eq(S.nxfMoney(1323.1), '1' + NB + '323,10 €', 'peniaze: tisíce + čiarka');
  eq(S.nxfMoney(0), '0,00 €', 'nula je platná suma');
  eq(S.nxfMoney(null), '—', 'nezadaná suma nikdy nie je 0');
  eq(S.nxfMoney(''), '—', 'prázdna suma = pomlčka');
  eq(S.nxfMoney(-12.5), MINUS + '12,50 €', 'záporná suma s U+2212');
  eq(S.nxfMoney(18.994), '18,99 €', 'zaokrúhlenie na centy');

  eq(S.nxfMoneyIn(68), '68,00', 'pole: celé číslo s ,00');
  eq(S.nxfMoneyIn(382.8), '382,80', 'pole: jedno desatinné doplnené');
  eq(S.nxfMoneyIn(40.987), '40,987', 'pole: presnosť 3 desatinných ostáva');
  eq(S.nxfMoneyIn(1234.5), '1234,50', 'pole: BEZ oddeľovača tisícov');
  eq(S.nxfMoneyIn(-12.5), '-12,50', 'pole: mínus ASCII (parser)');
  eq(S.nxfMoneyIn(null), '', 'pole: null = prázdne');
  eq(S.nxfMoneyIn(0), '0,00', 'pole: nula');

  eq(S.nxfQty(4, 'PLATŇA'), '4', 'kusové celé bez desatinných');
  eq(S.nxfQty(2.5, 'KS'), '2,5', 'kusové necelé NIKDY nie na celé');
  eq(S.nxfQty(2.4, 'BAL'), '2,4', 'balenie necelé');
  eq(S.nxfQty(0, 'KS'), '0', 'nula kusov');
  eq(S.nxfQty(37.26, 'BM'), '37,26', 'bm vždy 2 desatinné');
  eq(S.nxfQty(70.94, 'BM'), '70,94', 'bm 70,94 už nie 70,9');
  eq(S.nxfQty(8.8, 'BM'), '8,80', 'bm doplnené na 2');
  eq(S.nxfQty(23.2, 'M2'), '23,20', 'm² vždy 2 desatinné');
  eq(S.nxfQty(1, 'FIX'), '1', 'paušál');
  eq(S.nxfQty(null, 'KS'), '—', 'chýbajúce množstvo');
  eq(S.nxfQty(1.005, 'XYZ'), '1,005', 'neznámy kód max 3 desatinné');
  eq(S.nxfQty(2.4, 'ks'), '2,4', 'kód malým (katalóg kovania) = kusové');

  eq(S.nxfUnit('PLATŇA'), 'platňa', 'stĺpec MJ bez počtu');
  eq(S.nxfUnit('PLATŇA', 1), 'platňa', '1 platňa');
  eq(S.nxfUnit('PLATŇA', 4), 'platne', '4 platne');
  eq(S.nxfUnit('PLATŇA', 5), 'platní', '5 platní');
  eq(S.nxfUnit('PLATŇA', 0), 'platní', '0 platní');
  eq(S.nxfUnit('PLATŇA', 2.5), 'platne', '2,5 platne');
  eq(S.nxfUnit('FIX', 0), 'paušálov', '0 paušálov');
  eq(S.nxfUnit('FIX', 1), 'paušál', '1 paušál');
  eq(S.nxfUnit('FIX', 3), 'paušály', '3 paušály');
  eq(S.nxfUnit('FIX'), 'paušál', 'FIX bez počtu');
  eq(S.nxfUnit('BM'), 'bm', 'bm');
  eq(S.nxfUnit('M2'), 'm²', 'm²');
  eq(S.nxfUnit('KS'), 'ks', 'ks');
  eq(S.nxfUnit('SET'), 'set', 'set');
  eq(S.nxfUnit('PÁR'), 'pár', 'pár');
  eq(S.nxfUnit('BAL'), 'bal', 'bal');
  eq(S.nxfUnit('XYZ'), 'XYZ', 'neznámy kód bez zmeny');
  eq(S.nxfQtyUnit(37.26, 'BM'), '37,26 bm', 'množstvo + jednotka');
  eq(S.nxfQtyUnit(4, 'PLATŇA'), '4 platne', 'skloňovanie podľa množstva');

  eq(S.nxfMm(18.6), '18,6', 'hrúbka 18,6 (nie 19)');
  eq(S.nxfMm(18), '18', 'celé mm bez ,0');
  eq(S.nxfMm(18.65), '18,65', '2 desatinné');
  eq(S.nxfMm(0.45), '0,45', 'páska 0,45 (nie 0,5)');
  eq(S.nxfMm(null), '—', 'chýbajúca hrúbka');

  eq(S.nxfDim(762.5), '763', 'dĺžka: polovica nahor (= VEPO)');
  eq(S.nxfDim(762.4), '762', 'dĺžka: dole');
  eq(S.nxfDim(2800), '2800', 'BEZ oddeľovača tisícov');

  eq(S.nxfDec(0.5, 2), '0,5', 'kg: čiarka');
  eq(S.nxfDec(2, 2), '2', 'kg: bez koncových núl');
  eq(S.nxfDec(1.236, 2), '1,24', 'kg: max 2 desatinné');
})();

// --- T2: zhoda s existujúcimi formátovačmi ------------------------------------
(function(){
  let x = 7;
  for (let i = 0; i < 200; i++){
    x = (x * 9301 + 49297) % 233280;
    const v = ((x / 233280) - 0.3) * Math.pow(10, i % 7) * (i % 3 === 0 ? 1 : 1.0137);
    eq(S.nxfMoney(v), B.budFmtEur(v), 'nxfMoney ≡ budFmtEur pre ' + v);
  }
  [null, undefined, '', 0, -0.004, 0.005, 1e6, 999.995].forEach(function(v){
    eq(S.nxfMoney(v), B.budFmtEur(v), 'nxfMoney ≡ budFmtEur pre ' + v);
  });
  [18.6, 18, 18.65, 0.45, 0.8, 1, 2, 25, 36, 12.333, 0.005, 2800].forEach(function(v){
    eq(S.nxfMm(v), C.mmLabel(v), 'nxfMm ≡ mmLabel (Inspector) pre ' + v);
  });
})();

// --- T3: okružná cesta peňažného poľa -------------------------------------------
(function(){
  [0, 1, 68, 382.8, 40.99, 40.987, 1234.5, 12345.67, -12.5, -0.01, 0.001, 100000, 17.1, 0.3]
    .forEach(function(x){
      const t = S.nxfMoneyIn(x);
      eq(B.budParse(t), x, 'budParse(nxfMoneyIn(' + x + ')) === ' + x + ' (pole „' + t + '")');
      ok(t.indexOf('€') < 0 && t.indexOf(MINUS) < 0 && t.indexOf(NB) < 0 && t.indexOf(' ') < 0,
         'pole bez €, U+2212 a medzier: „' + t + '"');
    });
})();

// --- T4: render riadkov Rozpočtu (okno = studio.js + budget.js v jednom kontexte) -
const ctx = {
  console, document: { getElementById(){ return null; }, querySelector(){ return null; },
                       querySelectorAll(){ return []; }, addEventListener(){} },
  setTimeout, clearTimeout,
  localStorage: { getItem(){ return null; }, setItem(){} }
};
ctx.window = ctx;
vm.createContext(ctx);
['studio_sections.js', 'studio.js', 'budget.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(JS, f), 'utf8'), ctx, { filename: f });
});
const budgetPayload = { stale: { items: [] } };
(function(){
  const svc = function(r){ return ctx.budServiceRow(Object.assign({ key: 'service:x', nazov: 'Služba', spolu: 1, zdroj: 'auto' }, r), 1); };
  const s1 = svc({ mnozstvo: 37.26, mj: 'BM', cena_mj: 1.1 });
  ok(s1.includes('37,26 bm × 1,10 €'), 'služba: bm na 2 desatinné + cena (' + visible(s1) + ')');
  ok(svc({ mnozstvo: 4, mj: 'PLATŇA', cena_mj: 17 }).includes('4 platne × 17,00 €'), 'služba: 4 platne');
  ok(svc({ mnozstvo: 0, mj: 'KS', cena_mj: 50 }).includes('0 ks × 50,00 €'), 'služba: 0 ks');
  ok(svc({ mnozstvo: 0, mj: 'FIX', cena_mj: 100 }).includes('0 paušálov × 100,00 €'), 'služba: 0 paušálov');
  ok(svc({ mnozstvo: 1, mj: 'FIX', cena_mj: 100 }).includes('1 paušál × 100,00 €'), 'služba: 1 paušál');
  ok(svc({ mnozstvo: 23.2, mj: 'M2', cena_mj: 16.5 }).includes('23,20 m² × 16,50 €'), 'služba: m²');
  const s2 = svc({ mnozstvo: 4, mj: 'PLATŇA', cena_mj: 17, spolu: 68, poznamka: '4 platní × 5,8 m²' });
  ok(s2.includes('value="68,00"'), 'pole medzisúčtu „68,00"');
  ok(/value="68,00"[^>]*>\s*<span class="bfnt">€<\/span>/.test(s2), 'za poľom tlmené €');
  ok(s2.includes('4 platní × 5,8 m²'), 'serverová poznámka ostáva bez zmeny');
  ['PLATŇA', 'BM', 'M2', 'FIX'].forEach(function(code){
    ok(!new RegExp('>[^<]*\\b' + code + '\\b[^<]*<').test(s1 + svc({ mnozstvo: 1, mj: code, cena_mj: 1 })),
       'žiadny kód ' + code + ' ako text bunky');
  });

  const mat = ctx.budMaterialRow({ key: 'material:H18', material_id: 'H18', nazov: 'H1180 DTDL 18 mm', mnozstvo: 5,
                                   mj: 'PLATŇA', cena_mj: 180.84, spolu: 904.2 }, budgetPayload, 1);
  ok(mat.includes('<td class="bnum">5</td>') && mat.includes('<td class="bnum">platňa</td>'), 'materiál: 5 · platňa');
  ok(mat.includes('904,20 €'), 'materiál: suma ako doteraz');
  const abs = ctx.budSimpleRow({ abs_id: 'E43', nazov: 'ABS H1180', mj: 'BM', mnozstvo: 70.94, cena_mj: 0.39, spolu: 27.67 },
                               budgetPayload, 1);
  ok(abs.includes('<td class="bnum">70,94</td>') && abs.includes('<td class="bnum">bm</td>'), 'ABS: 70,94 bm');
  const hw = ctx.budHardwareRow({ kod: 'K1', nazov: 'Lišta', mnozstvo: 2.4, mj: 'BM', cena_mj: 4.5, spolu: 10.8 }, 1);
  ok(hw.includes('<td class="bnum">2,40</td>') && hw.includes('<td class="bnum">bm</td>'), 'kovanie v bm: 2,40 (nie 2)');
  const hw2 = ctx.budHardwareRow({ kod: 'K2', nazov: 'Noha', mnozstvo: 2.4, mj: 'BAL', cena_mj: 4.5, spolu: 10.8 }, 1);
  ok(hw2.includes('<td class="bnum">2,4</td>') && hw2.includes('<td class="bnum">bal</td>'), 'kovanie necelé: 2,4 (nie 2)');
  const hw3 = ctx.budHardwareRow({ kod: 'K3', nazov: 'Pánt', mnozstvo: 12, mj: 'KS', cena_mj: 1.2, spolu: 14.4 }, 1);
  ok(hw3.includes('<td class="bnum">12</td>') && hw3.includes('<td class="bnum">ks</td>'), 'kovanie celé: 12 ks');

  const cust = ctx.budCustomRow({ id: 'c1', key: 'custom:c1', nazov: 'Sklo', mnozstvo: 2, cena_mj: 40.987, spolu: 81.97 }, 1);
  ok(cust.includes('value="40,987"') && cust.includes('value="2"'), 'vlastná položka: cena 40,987, počet bez zmeny');
  ok(/data-field="cena"[^>]*>\s*<span class="bfnt">€<\/span>/.test(cust), 'vlastná položka: € za cenou');
  const std = ctx.budStandardRow({ key: 'std:balne', nazov: 'Balné', kind: 'fixed', multiplier: 1.5, rate: 20, spolu: 382.8,
                                   zdroj: 'auto' }, { viz_m2: null }, 1);
  ok(std.includes('value="382,80"') && std.includes('value="1,5"'), 'štandardný riadok: 382,80; násobok bez zmeny');

  // T5 (časť Rozpočet): žiadna desatinná bodka vo viditeľnom texte.
  [s1, s2, mat, abs, hw, hw2, cust, std].forEach(function(h){
    ok(!DOT.test(visible(h)), 'Rozpočet bez desatinnej bodky: ' + visible(h));
  });
})();

// --- T5: Kusovník ---------------------------------------------------------------
(function(){
  S.setStForTest({
    rows: [{ length: 762.5, width: 400, thickness: 18.6, quantity: 2, material_id: 'M1', name: 'Bok',
             edges: { L1: 'E1', L2: 'E1', W1: 'E2', W2: 'E2' }, kde: [{ owner_id: 'CAB-1', quantity: 2 }] }],
    sheets: [{ material_id: 'M1', m2: 1.23, quantity: 2 }],
    materials_meta: { M1: { label: 'DTDL Biela', th: 18.6 } },
    edges_meta: { E1: { th: 0.8, label: 'ABS 0,8' }, E2: { th: 1, label: 'ABS 1' } },
    totals: { parts: 2, m2: 1.23, materials: 1, bm: 70.94, edges: 4 },
    edging: [{ abs_id: 'E1', edges: 2, bm: 70.94 }, { abs_id: 'E2', edges: 2, bm: 3.1 }]
  });
  const parts = S.partsTable();
  const pv = visible(parts);
  ok(pv.includes('DTDL Biela 18,6 mm'), 'hlavička skupiny: 18,6 mm (nie 19)');
  ok(parts.includes('<td class="num c-th">18,6</td>'), 'stĺpec Hr.: 18,6');
  ok(parts.includes('<td class="num c-l">763</td>') && parts.includes('<td class="num c-w">400</td>'), 'Dĺžka/Šírka celé mm (= VEPO)');
  ok(pv.includes('ABS spolu 70,94 bm'), 'súčtový riadok: bm na 2 desatinné');
  const sheets = S.sheetsTable();
  ok(sheets.includes('<td class="num">18,6 mm</td>'), 'pohľad Platne: hrúbka 18,6 mm');
  const absv = S.absTable();
  ok(absv.includes('<td class="num">0,8 mm</td>') && absv.includes('<td class="num">1 mm</td>'), 'pohľad ABS: 0,8 mm a 1 mm');
  ok(absv.includes('<b>70,94</b>') && absv.includes('<b>3,10</b>'), 'pohľad ABS: bm na 2 desatinné');
  [parts, sheets, absv].forEach(function(h){
    ok(!DOT.test(visible(h)), 'Kusovník bez desatinnej bodky: ' + visible(h));
  });
  eq(S.cellNumText('q', 2), '2', 'ks celé');
  eq(S.cellNumText('l', 2000.5), '2001', 'dĺžka celé mm');
  S.setStForTest(null);

  // Materiály: štítky hrúbok a formátov.
  eq(M.sheetChipLabel({ type: 'DTDL', thickness: 18.6 }), 'DTDL 18,6', 'štítok dosky');
  eq(M.edgeChipLabel({ width: 23, thickness: 0.8 }), '23/0,8', 'štítok pásky');
  eq(M.edgeChipLabel({ width: null, thickness: 0.45 }), '0,45 mm', 'štítok pásky bez šírky');
  eq(M.sheetDimLabel({ type: 'DTDL', thickness: 18.6, sheet_size: [2800, 2070] }).sub.indexOf('2800×2070'), 0,
     'formát platne bez oddeľovača tisícov');
  ok(!DOT.test(M.sheetChipLabel({ type: 'DTDL', thickness: 18.6 }) + ' ' + M.edgeChipLabel({ width: 22.5, thickness: 2 })),
     'Materiály bez desatinnej bodky');
})();

// --- T6: D-11 „dookola" ---------------------------------------------------------
(function(){
  const meta = { E1: { th: 0.8, label: 'ABS Biela 0,8' }, E2: { th: 0.8, label: 'ABS Dub 0,8' },
                 E3: { th: 2, label: 'ABS Biela 2' }, E4: { th: 0.45, label: 'ABS 0,45' }, EX: { label: 'bez hrúbky' } };
  const all = function(id){ return { edges: { L1: id, L2: id, W1: id, W2: id } }; };
  eq(S.absCompact(all('E1'), meta), '0,8 dookola', 'štyri hrany, tá istá páska');
  eq(S.absCompact(all('E3'), meta), '2 dookola', 'celá hrúbka bez ,0');
  eq(S.absCompact(all('E4'), meta), '0,45 dookola', 'hrúbka 0,45 nie 0,5');
  eq(S.absCompact({ edges: { L1: 'E1', L2: 'E1', W1: 'E2', W2: 'E2' } }, meta), 'L1:0,8 · L2:0,8 · W1:0,8 · W2:0,8',
     'dve RÔZNE pásky rovnakej hrúbky = plný kompakt (nie „dookola")');
  eq(S.absCompact({ edges: { L1: 'E1', L2: 'E1', W1: 'E1' } }, meta), 'L1:0,8 · L2:0,8 · W1:0,8', 'tri hrany = plný kompakt');
  eq(S.absCompact(all('E9'), {}), 'L1 · L2 · W1 · W2', 'bez metadát = kódy bez hrúbky');
  eq(S.absCompact(all('EX'), meta), 'L1 · L2 · W1 · W2', 'neznáma hrúbka = kódy');
  eq(S.absCompact({ edges: {} }, meta), '—', 'bez ABS');
  eq(S.absFull(all('E1'), meta), 'L1 — ABS Biela 0,8 · L2 — ABS Biela 0,8 · W1 — ABS Biela 0,8 · W2 — ABS Biela 0,8',
     'titulok ostáva plný L1–W2 s menom pásky');
})();

// --- predrecenzia P3: okno mazania materiálu, MJ v Nákupe, cena v „Pridať z Demosu" -
(function(){
  const del = M.mdDeleteSummary({ kind: 'sheet', price: 12.5, used: [], used_count: 0, protected: false, duplak_deps: [] });
  ok(del.lines.indexOf('Cena: 12,50 €/m²') >= 0, 'mazanie dosky: „Cena: 12,50 €/m²" (' + del.lines.join(' | ') + ')');
  const delE = M.mdDeleteSummary({ kind: 'edge', price: 1234.5, used: [], used_count: 0, protected: false, duplak_deps: [] });
  ok(delE.lines.indexOf('Cena: 1' + NB + '234,50 €/bm') >= 0, 'mazanie pásky: tisíce + €/bm');

  eq(S.nxfHwUnitCode('m'), 'BM', 'katalóg „m" = bm (zrkadlo Budget::HW_UNIT_LABELS)');
  eq(S.nxfHwUnitCode('par'), 'PÁR', 'katalóg „par" = pár');
  eq(S.nxfHwUnitCode('sada'), 'SET', 'katalóg „sada" = set');
  eq(S.nxfHwUnitCode('balenie'), 'BAL', 'katalóg „balenie" = bal');
  eq(S.nxfHwUnitCode('xyz'), null, 'neznáma jednotka = null');
  const buy = S.buySection({ state_status: 'ok', rows: [
    { code: 'L1', name_sk: 'Lišta', category: 'X', category_label: 'Lišty', quantity: 2.4, unit: 'm',
      price_eur_vat: 1234.5, subtotal_eur_vat: 2962.8 },
    { code: 'P1', name_sk: 'Pánt', category: 'X', category_label: 'Lišty', quantity: 3, unit: 'par',
      price_eur_vat: 2, subtotal_eur_vat: 6 },
    { code: 'Z1', name_sk: 'Iné', category: 'X', category_label: 'Lišty', quantity: 1, unit: 'xyz',
      price_eur_vat: 1, subtotal_eur_vat: 1 }
  ], unmapped: [], summary: { total_eur_vat: 2969.8, unknown_prices: 0 } }, []);
  ok(buy.includes('<b>2,40</b>') && buy.includes('<td>bm</td>'), 'Nákup: „m" z katalógu = 2,40 bm (ako Rozpočet)');
  ok(buy.includes('<b>3</b>') && buy.includes('<td>pár</td>'), 'Nákup: „par" = pár');
  ok(buy.includes('<td>xyz</td>'), 'Nákup: neznáma jednotka surovo');
  ok(buy.includes('1' + NB + '234,50 €'), 'Nákup: cena s tisícami');
  ok(!/<td>(m|par)<\/td>/.test(buy), 'Nákup: žiadny surový kód „m"/„par"');

  const A = require(path.join(JS, 'demos_add.js'));
  eq(A.nxdaPriceLabel(1234.5, 'ks'), '1' + NB + '234,50 € / ks', 'Pridať z Demosu: tisíce cez nxfMoney');
  eq(A.nxdaPriceLabel(118.42, 'ks'), '118,42 € / ks', 'Pridať z Demosu: bežná cena bez zmeny');
})();

console.log('test_h4a_format: ' + n + ' asercii OK');
