// PICKER-3 — KONTEXT RADÍ AJ RIADKY + duplák podľa hrúbky (čisté funkcie).
//
// Čo tu stojí (a prečo to klikaním nezistíš skôr, než sa to objaví vo výrobe):
//   C · „54 duplák" musí trafiť SVOJ duplák. Rodina môže mať duplák ×2 aj ×3;
//       slovo „duplák" sa dovtedy čítalo SKÔR než číslo, takže dotaz na 54
//       preselektoval prvý duplák (36) — iný materiál za iné peniaze.
//   E · Kontext výberu (`back` → 3 mm, `worktop` → 38) sa dovtedy uplatňoval
//       len VNÚTRI rodiny. V poli pre chrbát tak vyhral riadok DTDL 18 toho
//       istého dekoru a Enter vložil 18 mm chrbát. Kontext preto riadky RADÍ
//       (nefiltruje — 18 mm chrbát je nezvyklý, nie zakázaný) a kurzor po
//       dopísaní dotazu sadá na prvý riadok, ktorý kontextu vyhovuje.
//   Poradie prednosti z PICKER-2 platí ďalej: VÝSLOVNÝ dotaz o hrúbke kontext
//   odstaví aj v poradí riadkov.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const NXC = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'nx_combo.js'));
const { nxComboChipFromQuery, nxComboDecorRows, nxComboCtxThickness, nxComboCtxRank,
        nxComboSortByCtx, nxComboFirstCtx } = NXC;

// --- C) duplák ×2 aj ×3: slovo NESTAČÍ --------------------------------------
(function(){
  const vars = [
    { value: 'r18', label: 'Dub 18', thickness: 18 },
    { value: 'd36', label: 'Dub duplák 36', thickness: 36, duplak: true },
    { value: 'd54', label: 'Dub duplák 54', thickness: 54, duplak: true }
  ];
  eq(nxComboChipFromQuery('54 duplák', vars), 2,
     '„54 duplák" trafí SVOJ duplák, nie prvý v poradí');
  eq(nxComboChipFromQuery('duplak 54', vars), 2, 'poradie slov v dotaze nerozhoduje');
  eq(nxComboChipFromQuery('DUPLÁK 36', vars), 1, 'a „36 duplák" ostáva pri 36');
  eq(nxComboChipFromQuery('duplák', vars), 1,
     'samotné slovo padá na prvý duplák — dotaz o hrúbke nič nehovorí');
  eq(nxComboChipFromQuery('99 duplák', vars), 1,
     'neexistujúca hrúbka duplák nemení na obyčajnú dosku (slovo v dotaze platí)');
  eq(nxComboChipFromQuery('18', vars), 0, 'číslo bez slova ostáva pri reálnej doske');
  eq(nxComboChipFromQuery('54', vars), 2,
     'a samotná 54 nájde duplák, lebo inú 54 rodina nemá');
  eq(nxComboChipFromQuery('duplak', [{ value: 'a', thickness: 18 }]), -1,
     'rodina bez duplákov na slovo nereaguje');
})();

// --- fixtúra pre E: jeden dekor v DTDL 18/36 a v HDF 3 ----------------------
// Poradie je KATALÓGOVÉ — DTDL prvé, presne ako v `md_back` v Štúdiu.
const ITEMS = [
  { value: 'dtd18', label: 'Dub · DTDL', disabled: false },
  { value: 'dtd36', label: 'Dub · DTDL', disabled: false },
  { value: 'hdf3', label: 'Dub · HDF', disabled: false },
  { value: 'buk18', label: 'Buk · DTDL', disabled: false }
];
const META = {
  dtd18: { decor: 'Dub · DTDL', type: 'DTDL', thickness: 18, key: 'G|Dub|DTDL' },
  dtd36: { decor: 'Dub · DTDL', type: 'DTDL', thickness: 36, key: 'G|Dub|DTDL' },
  hdf3:  { decor: 'Dub · HDF', type: 'HDF', thickness: 3, key: 'G|Dub|HDF' },
  buk18: { decor: 'Buk · DTDL', type: 'DTDL', thickness: 18, key: 'G|Buk|DTDL' }
};
const rowsOf = () => nxComboDecorRows(ITEMS, v => META[v] || null);

// --- E1) kontextová hrúbka je pravidlo, nie tvar atribútu -------------------
(function(){
  eq(nxComboCtxThickness('back'), 3, 'chrbát chce 3 mm');
  eq(nxComboCtxThickness('worktop'), 38, 'pracovná doska 38');
  eq(nxComboCtxThickness('body'), null, 'korpus žiadnu konkrétnu hrúbku nemenuje');
  eq(nxComboCtxThickness(null), null, 'a bez kontextu sa neradí nič');
})();

// --- E2) rank riadku: ponúka riadok kontextovú hrúbku? ---------------------
(function(){
  const rows = rowsOf();
  const dtd = rows[0], hdf = rows[1];
  eq(nxComboCtxRank(hdf, 'back'), 0, 'HDF 3 chrbtu vyhovuje');
  eq(nxComboCtxRank(dtd, 'back'), 1, 'DTDL 18/36 nie');
  eq(nxComboCtxRank(dtd, 'body'), 0, 'bez kontextovej hrúbky sú si všetky rovné');
  eq(nxComboCtxRank({ value: 'x' }, 'back'), 0,
     'položka bez variantov (fixná voľba, ABS, katalóg bez resolvera) sa neposúva');
  // Duplák sa do rankingu neráta: je to vedomá voľba klikom na čip, nie
  // kontextová predvoľba — inak by kontext vytiahol hore zdvojenú dosku.
  const dupRow = nxComboDecorRows(
    [{ value: 'd3', label: 'X', disabled: false }, { value: 'r18', label: 'X', disabled: false }],
    v => ({ d3: { decor: 'X', type: 'DTDL', thickness: 3, duplak: true, key: 'K' },
            r18: { decor: 'X', type: 'DTDL', thickness: 18, key: 'K' } })[v])[0];
  eq(nxComboCtxRank(dupRow, 'back'), 1, 'duplák 3 mm riadok navrch NEVYTIAHNE');
  const offRow = nxComboDecorRows(
    [{ value: 'o3', label: 'Y', disabled: true }, { value: 'o18', label: 'Y', disabled: false }],
    v => ({ o3: { decor: 'Y', type: 'HDF', thickness: 3, key: 'K2' },
            o18: { decor: 'Y', type: 'HDF', thickness: 18, key: 'K2' } })[v])[0];
  eq(nxComboCtxRank(offRow, 'back'), 1, 'ani nedostupný variant — vybrať sa aj tak nedá');
})();

// --- E3) radenie je STABILNÉ a bez kontextu sa nedeje nič ------------------
(function(){
  const rows = rowsOf();
  eq(nxComboSortByCtx(rows, 'back').map(r => r.value), ['hdf3', 'dtd18', 'buk18'],
     'chrbtové 3 mm idú navrch, zvyšok drží KATALÓGOVÉ poradie');
  eq(nxComboSortByCtx(rows, 'body').map(r => r.value), ['dtd18', 'hdf3', 'buk18'],
     'bez kontextovej hrúbky sa poradie servera nemení ANI O RIADOK');
  eq(nxComboSortByCtx(rows, null).map(r => r.value), ['dtd18', 'hdf3', 'buk18'],
     'a bez kontextu tiež nie');
  // Rovnocenné riadky si nesmú preskakovať — inak by sa ponuka pri každom
  // písmene „prehadzovala" a človek by klikal naslepo.
  const many = [{ value: 'a' }, { value: 'b' }, { value: 'c' }];
  eq(nxComboSortByCtx(many, 'back').map(r => r.value), ['a', 'b', 'c'],
     'stabilné radenie: rovnaký rank = pôvodné poradie');
})();

// --- E4) kurzor: prvý riadok, ktorý kontextu VYHOVUJE ----------------------
(function(){
  const rows = rowsOf();
  // Sekcie („Použité v projekte") stoja NAD katalógom, takže samotné radenie
  // nestačí: fixtúra napodobňuje presne to — DTDL je prvé, lebo ho projekt
  // už používa.
  eq(nxComboFirstCtx(rows, 'back', ''), 1, 'kurzor preskočí DTDL a sadne na HDF 3');
  eq(nxComboFirstCtx(rows, 'body', ''), 0, 'bez kontextovej hrúbky je to prvý vyberateľný');
  eq(nxComboFirstCtx([{ value: 'x', disabled: true }, rows[0]], 'back', ''), 1,
     'keď kontextu nevyhovuje NIKTO, padá sa na prvý vyberateľný (nič sa neschová)');
  eq(nxComboFirstCtx([], 'back', ''), -1, 'prázdny zoznam nespadne');
})();

// --- E5) VÝSLOVNÝ dotaz o hrúbke prebíja kontext (aj v kurzore) ------------
(function(){
  const rows = rowsOf();   // [Dub·DTDL 18/36, Dub·HDF 3, Buk·DTDL 18]
  eq(nxComboFirstCtx(rows, 'back', '18'), 0,
     'kto v poli pre chrbát napíše „18", chce 18 — kontext ide bokom');
  eq(nxComboFirstCtx(rows, 'back', '3'), 1,
     'a „3" trafí HDF, hoci číslo 3 sedí aj v cudzom ID („dtd36")');
  eq(nxComboFirstCtx(rows, 'back', 'dub'), 1,
     'názov dekoru o hrúbke nehovorí — rozhoduje kontext');
  eq(nxComboFirstCtx(rows, 'back', ''), 1, 'prázdny dotaz tiež kontext neruší');
  eq(nxComboFirstCtx(rows, 'body', '18'), 0,
     'bez kontextovej hrúbky je to prvý zhodný riadok ako dovtedy');
  eq(nxComboFirstCtx(rows, 'back', '99'), 1,
     'neexistujúca hrúbka dotaz neplní — kontext platí ďalej');
  // Dotaz nesmie vytiahnuť riadok kvôli NEDOSTUPNEJ hrúbke: vybrať sa aj tak
  // nedá a kurzor by stál nad voľbou, ktorú server odmietne.
  // Riadok pritom ŽIJE (má použiteľnú 36) — neplatí len jeho 18.
  const off = nxComboDecorRows(
    [{ value: 'o18', label: 'X 18', disabled: true },
     { value: 'o36', label: 'X 36', disabled: false },
     { value: 'h3', label: 'X 3', disabled: false }],
    v => ({ o18: { decor: 'X', type: 'DTDL', thickness: 18, key: 'A' },
            o36: { decor: 'X', type: 'DTDL', thickness: 36, key: 'A' },
            h3: { decor: 'X', type: 'HDF', thickness: 3, key: 'B' } })[v]);
  eq(off.length, 2, 'fixtúra: živý DTDL riadok s neplatnou 18 + chrbtový HDF');
  eq(nxComboFirstCtx(off, 'back', '18'), 1,
     'nedostupnú 18 dotaz nevytiahne — kurzor sadne na kontextový riadok');
})();

console.log(`OK test_picker3_kontext.js — ${n} kontrol`);
