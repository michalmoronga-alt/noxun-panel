// Testy 2A-4b: okno Materialy na SCHEMA 2 (proj_materials.js) — skupiny cez
// group_id (mdGroupKeyOf + groupCatalogByDecor schema2), sekcie detailu per
// struktura (mdStructureSections), batch 3 buildery (mdBuildEdgeVariants,
// mdParseExtraThs/Abs), banner text a spolocna struktura skupiny.
// Dependency-free Node (node tests/js/test_md_schema2.js).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const M = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- mdGroupKeyOf: group_id kotva v schema2, text dekoru inak ---------------
eq(M.mdGroupKeyOf({ group_id: 'GRP-1', decor: 'K111' }, true), 'g:GRP-1', 'schema2 = group_id kotva');
eq(M.mdGroupKeyOf({ group_id: '  ', decor: 'K111' }, true), 'd:K111', 'prazdny gid = fallback text (hybrid)');
eq(M.mdGroupKeyOf({ group_id: 'GRP-1', decor: 'K111' }, false), 'd:K111', 'legacy rezim group_id ignoruje');
eq(M.mdGroupKeyOf({ decor: '  K111  ' }, false), 'd:K111', 'text dekoru sa trimuje');

// --- groupCatalogByDecor(catalog, true): rovnake cislo dvoch vyrobcov = 2 skupiny
const CAT2 = {
  sheets: [
    { material_id: 'EG_K111_18', group_id: 'GRP-EG', manufacturer: 'Egger', decor: 'K111',
      structure: 'ST9', type: 'DTDL', thickness: 18, color: [1, 2, 3] },
    { material_id: 'KR_K111_18', group_id: 'GRP-KR', manufacturer: 'Kronospan', decor: 'K111',
      structure: 'PW', type: 'DTDL', thickness: 18, color: [4, 5, 6] },
    { material_id: 'EG_U750_18', group_id: 'GRP-U750', manufacturer: 'Egger', decor: 'U750',
      decor_name: 'Taupe šedá', structure: 'ST9', type: 'DTDL', thickness: 18, color: [7, 8, 9],
      sheet_size: [2800, 2070] }
  ],
  edges: [
    { abs_id: 'ABS_EG_K111', group_id: 'GRP-EG', decor: 'K111', structure: 'ST9', thickness: 1, width: 23 },
    { abs_id: 'ABS_U750_UNI', group_id: 'GRP-U750', decor: 'U750', thickness: 1, width: 43, universal: true },
    { abs_id: 'ABS_HYBRID', decor: 'Sirota', thickness: 1 }
  ]
};
const SNAP2 = JSON.stringify(CAT2);
const G2 = M.groupCatalogByDecor(CAT2, true);
eq(JSON.stringify(CAT2), SNAP2, 'groupCatalogByDecor nemutuje vstup');
eq(G2.map(g => g.key), ['g:GRP-EG', 'g:GRP-KR', 'd:Sirota', 'g:GRP-U750'],
  'skupiny podla group_id (K111 2x — cislo abecedne, tie-break vyrobca), hybrid na text');
eq(G2[0].manufacturer, 'Egger', 'vyrobca skupiny z dosky');
eq(G2[1].manufacturer, 'Kronospan', 'druha K111 skupina ma vlastneho vyrobcu');
eq(G2[3].decor_name, 'Taupe šedá', 'decor_name skupiny z prveho zaznamu s nazvom');
eq(G2[0].count, 2, 'pocet variantov skupiny (doska + paska)');
eq(G2[0].usage_key, 'GRP-EG', 'usage_key = group_id (server model_decor_usage kluc)');
eq(G2[2].usage_key, 'Sirota', 'hybrid bez gid = usage_key text dekoru');

// Legacy rezim: presne dnesne spravanie (jedna skupina K111 podla textu).
const G1 = M.groupCatalogByDecor(CAT2, false);
eq(G1.map(g => g.decor), ['K111', 'Sirota', 'U750'], 'legacy zoskupenie podla textu dekoru');
eq(G1[0].sheets.length, 2, 'legacy: obe K111 dosky v jednej skupine');
eq(G1[0].usage_key, 'K111', 'legacy usage_key = text dekoru');

// --- mdBuildSections: pouzite cez usage_key (group_id), fallback decor ------
const secs = M.mdBuildSections(G2, { 'GRP-KR': 4 }, 'man', '');
eq(secs[0].title, 'Použité v projekte', 'pouzita skupina cez group_id kluc');
eq(secs[0].groups.map(g => g.key), ['g:GRP-KR'], 'len skupina s poctom > 0');
const legacySecs = M.mdBuildSections([{ decor: 'X', manufacturer: '', sheets: [], edges: [] }], { X: 2 }, 'man', '');
eq(legacySecs[0].title, 'Použité v projekte', 'stary tvar skupiny (bez usage_key) padne na decor');

// --- mdMatchGroup: + struktura a nazov skupiny ------------------------------
ok(M.mdMatchGroup(G2[0], 'st9'), 'hladanie podla struktury variantu');
ok(M.mdMatchGroup(G2[3], 'taupe'), 'hladanie podla nazvu skupiny (decor_name)');
ok(!M.mdMatchGroup(G2[1], 'st9'), 'PW skupina na ST9 dotaz nematchne');

// --- mdStructureSections: sekcie per struktura, bez struktury posledna ------
const SECG = {
  sheets: [
    { material_id: 'A', structure: 'ST9' },
    { material_id: 'B', structure: 'PW' },
    { material_id: 'C' }
  ],
  edges: [
    { abs_id: 'E1', structure: 'st9' },       // case-insensitive kluc, title prvy videny tvar
    { abs_id: 'E2', universal: true }          // universal bez struktury -> sekcia bez struktury
  ]
};
const ss = M.mdStructureSections(SECG);
eq(ss.map(s => s.key), ['PW', 'ST9', ''], 'sekcie abecedne, bez struktury posledna');
eq(ss[1].title, 'ST9', 'title = prvy videny tvar');
eq(ss[1].sheets.map(s => s.material_id), ['A'], 'doska v sekcii svojej struktury');
eq(ss[1].edges.map(e => e.abs_id), ['E1'], 'paska so strukturou (case-insensitive) v sekcii');
eq(ss[2].sheets.map(s => s.material_id), ['C'], 'doska bez struktury v poslednej sekcii');
eq(ss[2].edges.map(e => e.abs_id), ['E2'], 'universal paska v sekcii bez struktury');

// --- sheetDimLabel: typ · hrubka + format ako sub ---------------------------
eq(M.sheetDimLabel({ type: 'DTDL', thickness: 18, sheet_size: [2800, 2070] }),
  { dim: 'DTDL 18', sub: '2800×2070' }, 'dim + format');
eq(M.sheetDimLabel({ type: 'DTDL', thickness: 18 }), { dim: 'DTDL 18', sub: '' }, 'bez formatu bez sub');

// --- mdBuildEdgeVariants: struktura + universal per cip ---------------------
const ECHIPS = [
  { key: '23/1', width: '23', thickness: '1', label: '23/1' },
  { key: '43/2', width: '43', thickness: '2', label: '43/2' }
];
eq(M.mdBuildEdgeVariants(ECHIPS, { '23/1': { st: ' PW ', auto: false } }, { '43/2': true }),
  [{ width: '23', thickness: '1', structure: 'PW', universal: false },
   { width: '43', thickness: '2', structure: '', universal: true }],
  'edge_variants: struktura (trim) + vedomy universal priznak');
eq(M.mdBuildEdgeVariants([], {}, {}), [], 'ziadne cipy = prazdne pole');

// --- mdParseExtraThs/Abs: textove vynimky -> strukturovane varianty ---------
eq(M.mdParseExtraThs('', 'PW'), { variants: [], error: null }, 'prazdny text = nic');
eq(M.mdParseExtraThs('18.5, 25', 'PW'),
  { variants: [{ type: '', thickness: '18.5', structure: 'PW' }, { type: '', thickness: '25', structure: 'PW' }], error: null },
  'hrubky preberu SPOLOCNU strukturu');
// M-A3c (D-68, audit BLOCKER 3): NOVA gramatika — ciarka bez medzery medzi
// cislicami je DESATINNA (9,2 = 9.2; povodne sa 9,20 TICHO rozpadlo na 9 a 20).
// Kompaktny zoznam bez medzier ("18,36") tym VEDOME prestava byt zoznam —
// polozky oddeluje ciarka s medzerou alebo bodkociarka.
eq(M.mdParseExtraThs('18,5', 'PW'),
  { variants: [{ type: '', thickness: '18.5', structure: 'PW' }], error: null },
  'desatinna ciarka bez medzery = desatiny (slovenska klavesnica)');
ok(M.mdParseExtraThs('abc', '').error !== null, 'necislo = chyba');
ok(M.mdParseExtraThs('-3', '').error !== null, 'zaporna hrubka = chyba');
eq(M.mdParseExtraThs('18,36', 'ST9').variants.length, 1, 'bez medzery uz NIE JE zoznam — jedna hrubka 18.36');
eq(M.mdParseExtraAbs('28/2', 'ST9'),
  { variants: [{ width: '28', thickness: '2', structure: 'ST9', universal: false }], error: null },
  'ABS token sirka/hrubka so spolocnou strukturou, universal false');
ok(M.mdParseExtraAbs('28', '').error !== null, 'token bez lomky = chyba');
eq(M.mdParseExtraAbs('22,5/1', ''),
  { variants: [{ width: '22.5', thickness: '1', structure: '', universal: false }], error: null },
  'M-A3c: desatinna ciarka v sirke je legalna');
eq(M.mdParseExtraAbs('23/0,8', 'MG').variants[0].thickness, '0.8', 'desatinna ciarka v hrubke pasky');

// --- mdEdgeBannerText: sklonovanie ------------------------------------------
ok(M.mdEdgeBannerText(1).indexOf('1 páska nemá') === 0, 'jednotne cislo');
ok(M.mdEdgeBannerText(3).indexOf('3 pásky nemajú') === 0, '2-4');
ok(M.mdEdgeBannerText(5).indexOf('5 pások nemá') === 0, '5+');
ok(M.mdEdgeBannerText(3).indexOf('picker ich nevyberie') > 0, 'text vysvetluje dopad');

// --- mdGroupCommonStructure: predvolba "+ variant" --------------------------
eq(M.mdGroupCommonStructure({ sheets: [{ structure: 'PW' }], edges: [{ structure: 'pw' }] }), 'PW',
  'jedina struktura skupiny (case-insensitive) = predvolba');
eq(M.mdGroupCommonStructure({ sheets: [{ structure: 'PW' }], edges: [{ structure: 'ST9' }] }), '',
  'zmiesane struktury = ziadna predvolba');
eq(M.mdGroupCommonStructure({ sheets: [{}], edges: [] }), '', 'bez struktur = prazdne');

// --- GH #93 kolo 5: PD vlastna hrubka s inline formatom ---------------------
eq(M.mdParseExtraThs('20/4100x600', 'PW', 'PD'),
   { variants: [{ type: '', thickness: '20', structure: 'PW', sheet_size: [4100, 600] }], error: null },
   'PD extra hrubka s formatom prejde');
assert(M.mdParseExtraThs('20', '', 'PD').error !== null, 'PD extra hrubka BEZ formatu = chyba s navodom');
assert(M.mdParseExtraThs('20', '', 'PD').error.indexOf('4100x600') !== -1, 'chyba obsahuje priklad');
eq(M.mdParseExtraThs('19', 'ST9', 'DTDL'),
   { variants: [{ type: '', thickness: '19', structure: 'ST9' }], error: null },
   'ne-PD typ format nepotrebuje');
eq(M.mdParseExtraThs('19/2800x2070', '', 'DTDL'),
   { variants: [{ type: '', thickness: '19', structure: '', sheet_size: [2800, 2070] }], error: null },
   'volitelny format aj pri inych typoch');
assert(M.mdParseExtraThs('20/zle', '', 'PD').error !== null, 'pokazeny format = chyba');

// --- GH #93 kolo 7: PD cip bez formatu = klientska chyba (formular ostava) --
assert(M.mdBuildSheetVariants([{ key: 'pd38', label: 'PD 38', type: 'PD', th: '38' }], {}, {}).error !== null,
       'PD cip bez formatu = chyba uz na klientovi');
assert(M.mdBuildSheetVariants([{ key: 'g18', label: '18', type: '', th: '18' }], {}, {}, 'PD').error !== null,
       'genericky cip so zdielanym typom PD bez formatu = chyba');
eq(M.mdBuildSheetVariants([{ key: 'g18', label: '18', type: '', th: '18' }], {}, {}, 'DTDL'),
   { variants: [{ type: '', thickness: '18', structure: '' }], error: null },
   'ne-PD typ format nepotrebuje');
eq(M.mdBuildSheetVariants([{ key: 'pd38', label: 'PD 38', type: 'PD', th: '38' }],
                          { pd38: { l: '4100', w: '600' } }, {}).error, null,
   'PD s formatom prejde');

// --- 2B-1 (D-43): duplak render — riadok bez inline buniek, vazba viditelna --
const DUP = { material_id: 'TK_PW_DTDL_36', source_material_id: 'TK_PW_DTDL_18',
  source_multiplier: 2, type: 'DTDL', thickness: 36, row_rev: 'r1', label: 'Duplak 36' };
const dupRow = M.mdDuplakRow(DUP, '36');
ok(dupRow.indexOf('lep') >= 0 && dupRow.indexOf('TK_PW_DTDL_18') >= 0, 'duplak riadok ukazuje vazbu na zdroj');
ok(dupRow.indexOf('mdcell') < 0, 'duplak riadok NEMA inline bunky (kod/cena/dodavatel patria zdroju)');
ok(dupRow.indexOf('mdDeleteSheet') >= 0, 'duplak sa da zmazat');
ok(dupRow.indexOf('mdOpenSheetForm') < 0, 'duplak nema ceruzku (nic sa needituje)');

const secDup = M.mdSectionRows({ title: '', sheets: [DUP], edges: [] });
ok(secDup.indexOf('mdcell') < 0, 'sekcia s duplakom renderuje duplak vetvu (bez buniek)');
const SRC = { material_id: 'TK_PW_DTDL_18', type: 'DTDL', thickness: 18, row_rev: 'r2', label: '18' };
const secSrc = M.mdSectionRows({ title: '', sheets: [SRC], edges: [] });
ok(secSrc.indexOf('mdcell') >= 0, 'bezna doska ma inline bunky');
ok(secSrc.indexOf('mdCreateDuplak') < 0, 'duplak tlacidlo len v SCHEMA 2 rezime (MD_SCHEMA2 default false)');

// --- 2B-2: zastena — format required helper + rub v labeloch ----------------
ok(M.mdFormatRequired('PD') && M.mdFormatRequired('zastena'), 'PD aj ZASTENA vyzaduju format');
ok(!M.mdFormatRequired('DTDL') && !M.mdFormatRequired(''), 'ine typy nie');
ok(M.mdZastena(' Zastena ') && !M.mdZastena('PD'), 'mdZastena trim + case-insensitive');

assert(M.mdBuildSheetVariants([{ key: 'z10', label: 'Zastena 10', type: 'ZASTENA', th: '10' }], {}, {}).error !== null,
       'zastena cip bez formatu = klientska chyba');
eq(M.mdBuildSheetVariants([{ key: 'z10', label: 'Zastena 10', type: 'ZASTENA', th: '10' }],
                          { z10: { l: '4100', w: '640' } }, {}).error, null,
   'zastena s formatom prejde');
assert(M.mdParseExtraThs('10', '', 'ZASTENA').error !== null, 'extra hrubka zasteny bez formatu = chyba');
eq(M.mdParseExtraThs('10/4100x640', 'RT', 'ZASTENA'),
   { variants: [{ type: '', thickness: '10', structure: 'RT', sheet_size: [4100, 640] }], error: null },
   'extra hrubka zasteny s formatom prejde');

const zdl = M.sheetDimLabel({ type: 'ZASTENA', thickness: 10, sheet_size: [4100, 640],
  back_decor: 'K552', back_structure: 'RT' });
ok(zdl.sub.indexOf('rub K552 RT') >= 0, 'sub riadok nesie rub');
const zdl2 = M.sheetDimLabel({ type: 'ZASTENA', thickness: 10, back_decor: 'K552' });
ok(zdl2.sub === 'rub K552', 'rub bez formatu aj bez struktury');

// --- GH #95 P2: rub je hladatelny (mdMatchGroup) -----------------------------
const ZG = { decor: 'K551', decor_name: '', manufacturer: 'Kronospan',
  sheets: [{ material_id: 'Z1', type: 'ZASTENA', thickness: 10, back_decor: 'K552', back_structure: 'RT' }],
  edges: [] };
ok(M.mdMatchGroup(ZG, 'k552'), 'hladanie podla rubu najde skupinu');
ok(M.mdMatchGroup(ZG, 'rt') || M.mdMatchGroup(ZG, 'RT'.toLowerCase()), 'hladanie podla struktury rubu');
ok(!M.mdMatchGroup(ZG, 'k999'), 'nezname cislo nematchne');

// --- M-A3c (D-68): gramatika tokenov + pruhy vynimiek ------------------------
eq(M.mdSplitExtraTokens('18.5, 9,2').tokens, ['18.5', '9.2'], 'zoznam s medzerou + desatinna ciarka');
eq(M.mdSplitExtraTokens('9,20').tokens, ['9.20'], '9,20 je JEDNA hrubka 9.2 (nie 9 a 20 — povodny bug)');
eq(M.mdSplitExtraTokens('18.5; 9.2').tokens, ['18.5', '9.2'], 'bodkociarka oddeluje');
ok(M.mdSplitExtraTokens('18,5,9,2').error !== null, 'viac ciarok bez medzier = jasna chyba');
eq(M.mdSplitExtraTokens('9,2/4100x640').tokens, ['9.2/4100x640'], 'desatinna ciarka pred inline formatom');
eq(M.mdSplitExtraTokens('').tokens, [], 'prazdny vstup');
eq(M.mdExtraKey('9.2'), 'x:9.2', 'kanonicky kluc');
eq(M.mdExtraKey('9,2'.replace(',', '.')), M.mdExtraKey('9.20'), '9.2 = 9.20 = jeden variant');
eq(M.mdExtraKey('09.2'), 'x:9.2', 'vodiaca nula nerobi novy kluc');
eq(M.mdExtraFmtChips('18.5, 9,2'), [{ key: 'x:18.5', th: '18.5', inline: false }, { key: 'x:9.2', th: '9.2', inline: false }],
  'pruhy pre vynimky bez inline formatu');
eq(M.mdExtraFmtChips('9.2/4100x640')[0].inline, true, 'inline format = pruh netreba');
eq(M.mdExtraFmtChips('9.2, 9,20').length, 1, 'dedup 9.2 = 9,20 — jeden pruh');
eq(M.mdExtraFmtChips('zle'), [], 'nevalidny vstup = ziadne pruhy (chybu da az save)');
// pruh doplna sheet_size; inline ma prednost; required bez formatu = chyba s navodom
eq(M.mdParseExtraThs('9,2', 'RT', 'ZASTENA', { 'x:9.2': { l: '4100', w: '640' } }),
  { variants: [{ type: '', thickness: '9.2', structure: 'RT', sheet_size: [4100, 640] }], error: null },
  'zastena 9,2 s formatom z pruhu — koniec slepej ulicky (D-68)');
eq(M.mdParseExtraThs('9.2/4100x640', 'RT', 'ZASTENA', { 'x:9.2': { l: '1', w: '1' } }).variants[0].sheet_size,
  [4100, 640], 'inline format ma prednost pred pruhom');
ok(M.mdParseExtraThs('9,2', 'RT', 'ZASTENA', {}).error.indexOf('Formát výnimiek') >= 0 ||
   M.mdParseExtraThs('9,2', 'RT', 'ZASTENA', {}).error.indexOf('formát platne') >= 0,
   'required typ bez formatu = chyba s navodom kde ho vyplnit');
ok(M.mdParseExtraThs('19', 'ST9', 'DTDL', { 'x:19': { l: '2800', w: '' } }).error !== null,
   'polovicny format pruhu = chyba (nie tichy no-op)');
eq(M.mdParseExtraThs('19', 'ST9', 'DTDL', {}).variants[0].sheet_size, undefined,
   'ne-required typ bez pruhu = variant bez formatu (ako doteraz)');

// --- M-A3c (D-67): suggest filter (diakritika, prefix pred substring) --------
eq(M.mdNormText('Zástena'), 'zastena', 'diakritika von, lowercase');
eq(M.mdNormText('ŠTRUKTÚRA'), 'struktura', 'velke pismena s diakritikou');
eq(M.mdSuggestFilter(['DTDL', 'MDF', 'HDF', 'PD', 'Zástena', 'kompakt'], 'zas'), ['Zástena'],
  'dotaz bez diakritiky najde polozku s diakritikou');
eq(M.mdSuggestFilter(['DTDL', 'MDF', 'HDF'], ''), ['DTDL', 'MDF', 'HDF'], 'prazdny dotaz = vsetko (poradie servera)');
eq(M.mdSuggestFilter(['Kronospan', 'Kastamonu', 'Falco Krono'], 'kro'), ['Kronospan', 'Falco Krono'],
  'prefix zhoda pred substring zhodou');
eq(M.mdSuggestFilter(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'], '', 4).length, 4, 'limit');
eq(M.mdSuggestFilter(null, 'x'), [], 'null zoznam = prazdno');

// --- M-A3b (D-60): datum overenia ceny DD.M.RRRR -----------------------------
eq(M.mdDateLabel('2026-08-01T18:00:00Z'), '1.8.2026', 'ISO -> DD.M.RRRR bez nul');
eq(M.mdDateLabel('2026-12-24'), '24.12.2026', 'datum bez casu');
eq(M.mdDateLabel(''), '', 'prazdny vstup = prazdny label');
eq(M.mdDateLabel('nezmysel'), '', 'nevalidny vstup = prazdny label');
eq(M.mdDateLabel(null), '', 'null = prazdny label');

// --- M-A3b (D-60): tlacidlo vazby na Demos v riadku variantu -----------------
const DBTN = M.mdDemosBtn('sheet', 'EG_U750_18',
  { demos_url: 'https://www.demos-trade.sk/dtdl-u750-st9-x-2800-2070-18/', price_checked_at: '2026-08-01T10:00:00Z' });
ok(DBTN.indexOf('external-link') >= 0, 'demos tlacidlo nesie external-link ikonu');
ok(DBTN.indexOf('cena overená 1.8.2026') >= 0, 'title nesie datum overenia');
ok(DBTN.indexOf("mdDemosOpen('sheet', 'EG_U750_18')") >= 0, 'klik posiela LEN kind+id (URL drzi server)');
ok(DBTN.indexOf('demos-trade.sk') < 0, 'URL sa do DOM nedava (server autorita)');
eq(M.mdDemosBtn('sheet', 'X', { price_checked_at: '2026-08-01' }), '', 'bez demos_url ziadne tlacidlo');
eq(M.mdDemosBtn('sheet', 'X', null), '', 'bez zaznamu ziadne tlacidlo');
const DBTN2 = M.mdDemosBtn('edge', 'ABS_X', { demos_url: 'https://www.demos-trade.sk/absb-x-23-1/' });
ok(DBTN2.indexOf('cena overená') < 0, 'bez datumu title bez casti o overeni');

// --- M-A3b (D-56/D-63): dlazdica — badge vazby + title tooltip ---------------
const TG = { key: 'g:GRP-EG', decor: 'H1181', decor_name: 'Dub Halifax tabakový',
  manufacturer: 'Egger', count: 2, demos_n: 2, color: [200, 180, 150],
  sheets: [{ type: 'DTDL', thickness: 18 }], edges: [{ thickness: 1, width: 23 }] };
const TILE = M.mdTileHtml(TG, 0);
ok(TILE.indexOf('mddemos') >= 0 && TILE.indexOf('cloud-download') >= 0, 'badge vazby na Demos (D-56)');
ok(TILE.indexOf('(2 var.)') >= 0, 'badge title nesie pocet prepojenych variantov');
ok(TILE.indexOf('title="H1181 Dub Halifax tabakový · Egger"') >= 0, 'plny nazov v tooltipe (D-63)');
const TILE0 = M.mdTileHtml({ key: 'd:X', decor: 'X', decor_name: '', manufacturer: '',
  count: 0, color: null, sheets: [], edges: [] }, 0);
ok(TILE0.indexOf('mddemos') < 0, 'bez vazby ziadny badge');
ok(TILE0.indexOf('vlastný') >= 0, 'fallback vyrobcu v tooltipe aj podriadku');

// --- M-A3b (D-62): fotka v hlavicke detailu ----------------------------------
const DG = { key: 'g:GRP-EG', decor: 'H1181', decor_name: 'Dub Halifax tabakový',
  manufacturer: 'Egger', count: 1, color: [200, 180, 150], image: 'C:\\cache\\img.jpg',
  sheets: [{ material_id: 'S1', type: 'DTDL', thickness: 18, structure: 'ST37', row_rev: 'r1' }],
  edges: [] };
const DET = M.mdDetailHtml(DG);
ok(DET.indexOf('mdsw-photo') >= 0 && DET.indexOf('mdsw-lg') >= 0, 'detail ma fotku v swatchi (D-62)');
const DET0 = M.mdDetailHtml(Object.assign({}, DG, { image: null }));
ok(DET0.indexOf('mdsw-photo') < 0, 'bez fotky len farba (fallback)');

// --- M-A3b (D-60): demos tlacidlo v riadkoch sekcie --------------------------
const SECD = M.mdSectionRows({ key: 'ST37', title: 'ST37',
  sheets: [{ material_id: 'S1', type: 'DTDL', thickness: 18, row_rev: 'r1', code: '111',
             demos_url: 'https://www.demos-trade.sk/x-18/', price_checked_at: '2026-08-01' }],
  edges: [{ abs_id: 'A1', thickness: 1, width: 23, row_rev: 'r2' }] });
ok(SECD.indexOf("mdDemosOpen('sheet', 'S1')") >= 0, 'doska s vazbou ma demos tlacidlo');
ok(SECD.indexOf("mdDemosOpen('edge'") < 0, 'paska bez vazby tlacidlo nema');

console.log(JSON.stringify({ passed: n, failed: 0 }));
