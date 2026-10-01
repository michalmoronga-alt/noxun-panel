// Testy vyberu suborov prehravaca fotenia okien (davka H2, scripts/ui_foto/nx_stub.js) —
// dependency-free Node (node tests/js/test_ui_foto_stub.js). Fixtura je LEN zoznam mien
// suborov nahravky (tests/fixtures/ui_foto/index.json), nie cela nahravka.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');
const { select, parseMark } = require(path.join(__dirname, '..', '..', 'scripts', 'ui_foto', 'nx_stub.js'));

const list = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'ui_foto', 'index.json'), 'utf8'));
let n = 0;
function eq(actual, expected, msg) { n++; assert.deepStrictEqual(actual, expected, msg); }

// znacky
eq(parseMark('0013_mark_studio_cut.txt'), 'studio_cut', 'parseMark: meno znacky');
eq(parseMark('0014_studio.js'), null, 'parseMark: skript nie je znacka');
eq(parseMark('mark_x.txt'), null, 'parseMark: bez poradoveho cisla nie je znacka');

// Inspector bez vyberu: len skripty panela PO znacku vyberu
let r = select(list, 'panel_open', 'panel');
eq(r.found, true, 'panel_open najdena');
eq(r.files, ['0002_panel.js', '0003_panel.js'], 'panel_open: skripty do dalsej znacky');

// Inspector s vyberom: stav sa kumuluje (aj skripty pred cielovou znackou)
r = select(list, 'panel_select_cab1', 'panel');
eq(r.files, ['0002_panel.js', '0003_panel.js', '0005_panel.js'], 'panel_select_cab1: kumulativne, len kind panel');

// Studio: skripty studia od zaciatku az po znacku za sekciou; panelove sa preskocia
r = select(list, 'studio_ctrl', 'studio');
eq(r.files, ['0006_studio.js', '0008_studio.js', '0011_studio.js', '0012_studio.js'], 'studio_ctrl: vratane lenivych doplnkov sekcie');
r = select(list, 'studio_cut', 'studio');
eq(r.files[r.files.length - 1], '0014_studio.js', 'studio_cut: posledny skript pred znackou end');
eq(r.files.includes('0016_studio.js'), false, 'skript za koncovou znackou sa neprehra');

// chybajuca znacka = found false (prehravac to ohlasi ako chybu, nie tichu fotku)
r = select(list, 'studio_tpl', 'studio');
eq(r.found, false, 'neznama znacka: found false');

// subory mimo nahravky (index.json, meta.json, model.png) sa ignoruju; poradie podla mena
r = select(['0003_studio.js', 'meta.json', '0001_mark_studio_bom.txt', '0002_studio.js', 'model.png', 'index.json'], 'studio_bom', 'studio');
eq(r.files, ['0002_studio.js', '0003_studio.js'], 'zoradene podla cisla, cudzie subory von');

// kind sa nezamiena (panel.js vs studio.js) a prazdny vstup nepada
eq(select(list, 'studio_bom', 'panel').files.every(f => f.endsWith('_panel.js')), true, 'kind panel v studiovej sekcii');
eq(select(null, 'studio_bom', 'studio'), { files: [], found: false, marks: [] }, 'null zoznam');

console.log(`test_ui_foto_stub: ${n} OK`);
