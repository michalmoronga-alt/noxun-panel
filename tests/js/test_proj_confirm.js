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
