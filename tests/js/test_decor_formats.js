// Testy D-44: format platne pri preset cipoch batchu "Novy dekor" a verziovana
// zapamatana sada (proj_materials.js) — dependency-free Node
// (node tests/js/test_decor_formats.js). Rovnaky vzor ako test_decor_groups.js.
// Testuju sa LEN ciste funkcie bez DOM: navrh formatu podla typu, zlozenie
// payloadu sheet_variants z aktivnych cipov a migracia starej ulozenej sady.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mdFormatHint, mdBuildSheetVariants, mdMigrateLastSet, mdSheetDim, mdManualFormats } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- mdFormatHint: navrhy stavia SERVER (Materials::TYPE_FORMAT_HINTS), JS ich
//     len hlada podla napisaneho typu (case-insensitive, trim) ---
const HINTS = { DTDL: [2800, 2070], MDF: [2800, 2070], HDF: [2800, 2070], PD: null };
eq(mdFormatHint('DTDL', HINTS), [2800, 2070], 'DTDL ma standardny format');
eq(mdFormatHint('dtdl', HINTS), [2800, 2070], 'typ je case-insensitive (zrkadlo Ruby identity)');
eq(mdFormatHint('  MDF  ', HINTS), [2800, 2070], 'trim okolo napisaneho typu');
eq(mdFormatHint('PD', HINTS), null, 'PD: sirok je vela — vedome zadanie, ziadny navrh');
eq(mdFormatHint('kompakt', HINTS), null, 'neznamy typ = bez navrhu');
eq(mdFormatHint('', HINTS), null, 'prazdny typ = bez navrhu');
eq(mdFormatHint('DTDL', null), null, 'chybajuce hinty (stary payload) = bez navrhu');
eq(mdFormatHint('DTDL', { DTDL: [2800] }), null, 'poskodeny navrh sa ignoruje (ziadny polovicny format)');

// --- mdSheetDim: null = prazdne, NaN = vyplnene ale neplatne (D-19 vzor) ---
eq(mdSheetDim(''), null, 'prazdne pole = ziadny format');
eq(mdSheetDim('  '), null, 'medzery = prazdne');
eq(mdSheetDim('2800'), 2800, 'cele cislo');
eq(mdSheetDim('2050,5'), 2050.5, 'desatinna ciarka aj bodka');
eq(Number.isNaN(mdSheetDim('abc')), true, 'necislo = NaN (nie 0)');
eq(Number.isNaN(mdSheetDim('0')), true, 'nula nie je format');
eq(Number.isNaN(mdSheetDim('-5')), true, 'zaporne nie je format');

// --- mdBuildSheetVariants: aktivne cipy + stav formatov -> payload ---
const CHIPS = [
  { key: '18', type: '', th: '18', label: 'DTDL 18' },
  { key: 'PD 38', type: 'PD', th: '38', label: 'PD 38' }
];

// 2A-4b: builder VZDY nesie structure (batch 3) — bez stavu struktur prazdnu.
// GH #93 P2 (7. kolo): PD cip BEZ formatu je klientska chyba (server by variant
// odmietol az po zavreti formulara a cela davka by sa stratila) — ne-PD cipy
// bez formatu ostavaju legalne.
let out = mdBuildSheetVariants([CHIPS[0]], {});
eq(out.error, null, 'ne-PD cip bez formatu ziadna chyba');
eq(out.variants, [{ type: '', thickness: '18', structure: '' }],
  'bez formatu sa sheet_size vobec neposiela (server ho neulozi)');
out = mdBuildSheetVariants(CHIPS, {});
if (out.error === null) throw new Error('PD cip bez formatu MUSI byt klientska chyba');

out = mdBuildSheetVariants(CHIPS, { '18': { l: '2800', w: '2050' }, 'PD 38': { l: '4100', w: '600' } });
eq(out.variants, [{ type: '', thickness: '18', structure: '', sheet_size: [2800, 2050] },
                  { type: 'PD', thickness: '38', structure: '', sheet_size: [4100, 600] }],
  'format per cip ide do payloadu (MG 2800x2050, PD 4100x600)');

// 2A-4b: struktura per cip (auto zo spolocneho pola / rucny prepis) ide do payloadu.
// (GH #93 kolo 7: PD cip potrebuje format — inak klientska chyba.)
out = mdBuildSheetVariants(CHIPS, { 'PD 38': { l: '4100', w: '600' } },
                           { '18': { st: 'PW', auto: true }, 'PD 38': { st: ' ST9 ', auto: false } });
eq(out.variants, [{ type: '', thickness: '18', structure: 'PW' },
                  { type: 'PD', thickness: '38', structure: 'ST9', sheet_size: [4100, 600] }],
  'structure per cip (trim) ide do payloadu batch 3');

out = mdBuildSheetVariants(CHIPS, { '18': { l: '2800', w: '' } });
eq(out.error !== null, true, 'polovicny format zastavi odoslanie');
eq(out.error.indexOf('DTDL 18') >= 0, true, 'hlaska menuje konkretny cip');

out = mdBuildSheetVariants(CHIPS, { 'PD 38': { l: '4100', w: 'abc' } });
eq(out.error !== null, true, 'neplatne cislo zastavi odoslanie');

out = mdBuildSheetVariants([], { '18': { l: '2800', w: '2070' } });
eq(out, { variants: [], error: null }, 'ziadny aktivny cip = prazdny payload (bez chyby)');

// Stav formatu neaktivneho cipu payload neovplyvni (mdFmt si pamata aj vypnute).
out = mdBuildSheetVariants([CHIPS[0]], { '18': { l: '2800', w: '2050' }, '36': { l: '9', w: '9' } });
eq(out.variants, [{ type: '', thickness: '18', structure: '', sheet_size: [2800, 2050] }],
  'do payloadu ide LEN to, co je zapnute');

// --- mdMigrateLastSet: stara sada (v1) prezije, ale BEZ vymyslenych formatov ---
eq(mdMigrateLastSet({ sheet_keys: ['18', 'PD 38'], edge_keys: ['22/1'], ths: '18.5', abs: '28/2' }),
  { schema: 2, sheet_keys: ['18', 'PD 38'], edge_keys: ['22/1'], ths: '18.5', abs: '28/2', formats: {} },
  'v1 sada sa zmigruje 1:1, formaty ostanu prazdne');
eq(mdMigrateLastSet({}), { schema: 2, sheet_keys: [], edge_keys: [], ths: '', abs: '', formats: {} },
  'prazdny objekt = prazdna sada, ziadny pad');
eq(mdMigrateLastSet({ sheet_keys: 'nezoznam', ths: 42 }),
  { schema: 2, sheet_keys: [], edge_keys: [], ths: '', abs: '', formats: {} },
  'poskodene typy sa zahodia (localStorage je len UX, nie autorita)');
eq(mdMigrateLastSet(null), null, 'ziadna ulozena sada = null');
eq(mdMigrateLastSet('retazec'), null, 'nepouzitelny obsah = null');

// --- mdManualFormats (GH P2): do zapamatanej sady iba RUCNE formaty — auto
//     navrh sa pri obnove dopocita z hintov a nesmie prezit zmenu typu ---
const MF_CHIPS = [{ key: 'DTDL|18' }, { key: 'PD|38' }, { key: 'HDF|3' }];
eq(mdManualFormats(MF_CHIPS, {
  'DTDL|18': { l: '2800', w: '2070', auto: true },   // auto navrh — NEuklada sa
  'PD|38':   { l: '4100', w: '600',  auto: false },  // rucne zadany — uklada sa
  'HDF|3':   { l: '', w: '', auto: false }           // prazdny — nema co ulozit
}), { 'PD|38': { l: '4100', w: '600' } }, 'auto navrhy sa nepamataju, rucne ano');
eq(mdManualFormats(MF_CHIPS, {}), {}, 'ziadne formaty = prazdna mapa');
eq(mdManualFormats([], { 'DTDL|18': { l: '1', w: '2', auto: false } }), {},
  'format bez aktivneho cipu sa neuklada');
eq(mdManualFormats(null, null), {}, 'null vstupy = prazdna mapa, ziadny pad');

console.log(JSON.stringify({ passed: n, failed: 0 }));
