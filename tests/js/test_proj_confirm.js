// Testy D-46: potvrdzovacia lista projektovej predvolby (proj_materials.js) —
// dependency-free Node (node tests/js/test_proj_confirm.js).
// Testuju sa LEN ciste funkcie bez DOM: mapovanie kluca predvolby na select
// (zla mapa = select by po ponuke zostal vizualne na nepotvrdenom materiali)
// a zlozenie payloadu potvrdenia (CELY pending kontrakt ide serveru SPAT).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { mdProjectSelectId, mdConfirmPayload } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'proj_materials.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- mdProjectSelectId: kluc predvolby -> id selectu (zrkadlo Ruby TARGETS) ---
eq(mdProjectSelectId('default_material_id'), 'md_body', 'korpus');
eq(mdProjectSelectId('default_front_material_id'), 'md_front', 'cela');
eq(mdProjectSelectId('default_back_material_id'), 'md_back', 'chrbat');
eq(mdProjectSelectId('bogus'), null, 'neznamy kluc = ziadny select (nic sa neprepisuje)');
eq(mdProjectSelectId(''), null, 'prazdny kluc');
eq(mdProjectSelectId(null), null, 'chybajuci kluc');

// --- mdConfirmPayload: potvrdenie nesie CELY pending kontrakt spat ---
const PENDING = {
  model_guid: 'GUID-1',
  key: 'default_material_id',
  value: 'HALIFAX_DTDL_186',
  old_default: 'BIELA_DTDL_18',
  adopting_ids: ['CAB-001', 'CAB-002'],
  recompute_ids: ['CAB-003']
};

eq(mdConfirmPayload(PENDING, 'GUID-1'), {
  key: 'default_material_id',
  value: 'HALIFAX_DTDL_186',
  model_guid: 'GUID-1',
  confirm: PENDING
}, 'server dostane kluc+hodnotu z PENDINGU (select je uz vrateny na default) a cely kontrakt');

// Kontrakt sa posiela NEZMENENY — server ho porovnava s cerstvym dry-runom.
const sent = mdConfirmPayload(PENDING, 'GUID-1');
eq(sent.confirm.old_default, 'BIELA_DTDL_18', 'baseline predvolby ide spat nedotknuty');
eq(sent.confirm.adopting_ids, ['CAB-001', 'CAB-002'], 'mnozina skriniek ide spat nedotknuta');

// Guid sa berie z AKTUALNEHO stavu okna: po prepnuti modelu posle klient iny
// guid, nez je v pendingu — server taky suhlas zahodi (nezapise do zleho modelu).
eq(mdConfirmPayload(PENDING, 'GUID-2').model_guid, 'GUID-2', 'guid je aktualny, nie z pendingu');

// Ziadny pending (Zrusit / MD.init / iny vyber) = nie je co potvrdit.
eq(mdConfirmPayload(null, 'GUID-1'), null, 'prazdny pending neposiela nic');
eq(mdConfirmPayload({}, 'GUID-1'), null, 'kontrakt bez kluca neposiela nic');
eq(mdConfirmPayload(undefined, 'GUID-1'), null, 'undefined pending neposiela nic');

console.log(JSON.stringify({ passed: n, failed: 0 }));

function ok(cond, msg){ n++; if (!cond) throw new Error(msg); }

// --- PICKER-1: predvoľby bežia cez ZDIEĽANÝ vyhľadávač (nx_combo) -----------
// Kontrakt D-46 sa presunom komponenta NESMEL zmeniť: server pýta potvrdenie,
// select sa medzitým vráti na SKUTOČNÝ default a `change` sa pritom NESPUSTÍ
// (inak by to vyzeralo ako nová voľba používateľa). Natívny select sa prekreslí
// sám, vyhľadávač má vlastný trigger — preto musí prísť výslovný `sync`.
(function(){
  const fs = require('node:fs');
  const path2 = require('node:path');
  const UI = path2.join(__dirname, '..', '..', 'noxun_engine', 'ui');
  const src = fs.readFileSync(path2.join(UI, 'js', 'proj_materials.js'), 'utf8');
  const html = fs.readFileSync(path2.join(UI, 'studio.html'), 'utf8');
  const combo = fs.readFileSync(path2.join(UI, 'js', 'nx_combo.js'), 'utf8');

  ['md_body', 'md_front', 'md_back'].forEach(function(id){
    ok(new RegExp('id="' + id + '"[^>]*data-nx-combo="decor"').test(html),
       id + ' je pripojený na ZDIEĽANÝ vyhľadávač (jeden komponent, jedna pravda)');
  });
  ok(html.indexOf('js/nx_combo.js') > -1, 'Štúdio komponent načítava');
  ok(html.indexOf('js/nx_combo.js') < html.indexOf('js/proj_materials.js'),
     'a to PRED sekciou Materiály, ktorá ho volá');

  const body = src.slice(src.indexOf('function mdSetProjectSelect'),
                         src.indexOf('function mdClearPending'));
  ok(body.indexOf('NXCombo.sync(sel)') > -1,
     'programové vrátenie hodnoty (D-46 pending) trigger vyhľadávača ZOSYNCHRONIZUJE');
  ok(body.indexOf('sel.value = id') < body.indexOf('NXCombo.sync(sel)'),
     'a to AŽ PO nastavení hodnoty');
  ok(body.indexOf('dispatchEvent') < 0 && body.indexOf('.change()') < 0,
     'ale `change` sa NEVYVOLÁVA — vrátenie na default nie je voľba používateľa (D-46)');

  ok(src.indexOf('mdComboScan();') > -1, 'po naplnení options sa komponent pripojí/obnoví');
  // Review #230 P2: telo sekcie je PERZISTENTNÝ uzol, ktorý odchod odpojí.
  // Kým je odpojené, scan tam nemá čo robiť — katalógové echo na pozadí by
  // inak odregistrovalo polia, ktoré sa o chvíľu vrátia.
  const scanFn = src.slice(src.indexOf('function mdComboScan()'),
                           src.indexOf('function mdSectionAttached'));
  ok(scanFn.indexOf('if (!mdSectionAttached()) return false;') > -1,
     'scan má bránu na PRIPOJENÉ telo sekcie');
  ok(scanFn.indexOf('mdSectionAttached()') < scanFn.indexOf('NXCombo.scan(document)'),
     'a brána stojí PRED skenom');
  ok(src.indexOf("fillSelect(mdEl('md_back')") < src.indexOf('mdComboScan();'),
     'scan ide AŽ ZA napĺňaním (inak by trigger ukazoval staré položky)');

  ok(combo.indexOf('sync: function(sel){') > -1, 'komponent `sync` naozaj ponúka');
  ok(combo.indexOf('nxComboPopWidth') > -1, 'a šírka ponuky je jeho vlastné pravidlo');
})();
