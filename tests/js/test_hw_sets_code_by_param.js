// KOV-E1a (9.9.2026) — nové tvary člena setu v editore knižnice (hw_sets.js).
//
// PREČO: člen výklopu nesie kód PODĽA TRIEDY (`code_by_param`) alebo počet
// Z PARAMETRA (`quantity_from`). Editor tieto tvary zatiaľ nevie upravovať
// (príde v E2) — ale NESMIE ich stratiť: `hwsMembersOf` ich rozobral na polia
// a `hwsBuildMembers` by z mechanizmu výklopu spravil člen s PRÁZDNYM kódom
// (Astra FIX 10). Set by sa uložil bez mechanizmu a nikto by si to nevšimol.
//
// ČO SA OVERUJE:
//   1) rozpoznanie nového tvaru (člen aj celý set)
//   2) BEZSTRATOVÝ round-trip: knižnica -> editor -> payload servera
//   3) súhrn člena vie nové tvary prečítať (nie prázdny riadok)
//   4) legacy tvary (pevný kód, rad NL, pásma) sa správajú PRESNE ako doteraz
//   5) `lift_system` prejde knižnica -> editor -> payload servera BEZ straty
//      (Codex #332 kolo 2 P1 — bez toho sa legacy výklop nedal doplniť)
//
// MUTÁCIE, ktoré sada chytá:
//   M1 `hwsMembersOf` rozoberie nový tvar na polia   -> round-trip
//   M2 `hwsBuildMembers` pošle `{code: ''}`          -> round-trip
//   M3 `quantity_from` sa cestou stratí              -> round-trip
//   M4 súhrn nového člena je prázdny reťazec         -> súhrn
//   M5 set s novým členom sa tvári upraviteľný       -> hwsSetIsNewShape
//   M6 `lift_system` sa cestou modal -> server stratí -> round-trip poľa
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwsMemberIsNew, hwsSetIsNewShape, hwsMembersOf, hwsBuildMembers,
        hwsMemberSummary, hwsBuildSetPayload, hwsSetDraftOf, HWS_LOCKED_HINT } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_sets.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(value, msg){
  n++;
  assert.ok(value, msg);
}

// Set výklopu presne v tvare, v akom ho posiela server (SEED_SETS).
const HL_SET = {
  set_id: 'vyklop-hl-klasik',
  name: 'Výklop HL top — klasik (biela)',
  generic_type: 'lift',
  use_type: 'lift',
  opening_mode: 'classic',
  lift_system: 'hl_top',
  manufacturer: 'Blum',
  series: 'AVENTOS',
  members: [
    { per: 'unit', qty: 1, label: 'mechanizmus HL top',
      code_by_param: { param: 'lift_class', codes: { '22L2200': '507351', '22L2500': '507352' } } },
    { per: 'owner', qty: 1, label: 'stabilizačná tyč', code: '507365', quantity_from: 'rod_count' },
    { per: 'unit', qty: 1, label: 'čelný príchyt (pár)', code: '13781' }
  ]
};

// --- 1) rozpoznanie tvaru -----------------------------------------------------
ok(hwsMemberIsNew(HL_SET.members[0]), 'kód podľa triedy je nový tvar');
ok(hwsMemberIsNew(HL_SET.members[1]), 'počet z parametra je nový tvar');
ok(!hwsMemberIsNew(HL_SET.members[2]), 'pevný kód je legacy tvar');
ok(!hwsMemberIsNew({ code_by_nl: { 420: '357695' } }), 'rad NL je legacy tvar');
ok(!hwsMemberIsNew(null), 'prázdny člen je bezpečný');
ok(hwsSetIsNewShape(HL_SET), 'set s takým členom je len na čítanie');
ok(!hwsSetIsNewShape({ members: [{ code: '104717' }] }), 'legacy set sa upravovať dá');
ok(!hwsSetIsNewShape(null), 'chýbajúci set je bezpečný');
ok(HWS_LOCKED_HINT.length > 10, 'read-only stav má vetu pre používateľa');

// --- 2) BEZSTRATOVÝ round-trip ------------------------------------------------
const edit = hwsMembersOf(HL_SET);
eq(edit.length, 3, 'každý člen prežije cestu do editora');
ok(edit[0].is_locked && edit[1].is_locked, 'nové tvary sú v editore zamknuté');
ok(!edit[2].is_locked, 'legacy člen ostáva editovateľný');
eq(hwsBuildMembers(edit), HL_SET.members, 'späť na server ide PRESNE to, čo prišlo');

// Zmena legacy člena nesmie poškodiť tie ostatné.
const zmena = hwsMembersOf(HL_SET);
zmena[2].code = '13782';
const poslane = hwsBuildMembers(zmena);
eq(poslane[0], HL_SET.members[0], 'mechanizmus ostal nedotknutý');
eq(poslane[1], HL_SET.members[1], 'tyč aj s počtom z parametra ostala nedotknutá');
eq(poslane[2].code, '13782', 'zmena legacy člena prešla');

// Celý payload setu (modal) — členovia sa nesmú stratiť ani cez neho.
const payload = hwsBuildSetPayload({ set_id: HL_SET.set_id, name: HL_SET.name,
                                     use_type: 'lift', opening_mode: 'classic',
                                     manufacturer: 'Blum', series: 'AVENTOS' },
                                   hwsMembersOf(HL_SET));
eq(payload.members, HL_SET.members, 'payload setu nesie členov bezstratovo');

// --- 3) SÚHRN ČLENA -----------------------------------------------------------
eq(hwsMemberSummary(HL_SET.members[0]),
   'podľa lift_class: 22L2200→507351, 22L2500→507352', 'kód podľa triedy sa dá prečítať');
eq(hwsMemberSummary(HL_SET.members[1]),
   'stabilizačná tyč 507365 — počet podľa rod_count (na vlastníka)',
   'počet z parametra sa dá prečítať');
eq(hwsMemberSummary({ code_by_param: { param: 'arm_class', codes: {} } }),
   'podľa arm_class: —', 'prázdny selektor sa prizná, nie zamlčí');

// --- 4) LEGACY tvary sa nemenia -----------------------------------------------
eq(hwsMemberSummary({ code: '104717', qty: 1, per: 'unit', label: 'záves' }),
   'záves 104717 ×1', 'pevný kód ako doteraz');
eq(hwsMemberSummary({ code_by_nl: { 420: '357695', 470: '357696' } }),
   'rad NL: 420→357695, 470→357696', 'rad NL ako doteraz');
const legacy = { set_id: 'zaves-klasik', generic_type: 'hinge',
                 members: [{ per: 'unit', qty: 1, label: 'záves', code: '104717' },
                           { per: 'unit', qty: 1,
                             code_by_nl: { 420: '357695', 470: '357696' } }] };
eq(hwsBuildMembers(hwsMembersOf(legacy)),
   [{ per: 'unit', qty: 1, label: 'záves', code: '104717' },
    { per: 'unit', qty: 1, code_by_nl: { 420: '357695', 470: '357696' } }],
   'legacy set round-trip bez zmeny');

// --- 5) `lift_system` v editore (Codex #332 kolo 2 P1) ------------------------
// Legacy set z v0.9.52 je `use_type: 'lift'` BEZ systému. Server ho číta ako
// zaradený (grandfather), ale zápis systém VYŽADUJE — takže modal ho musí
// vedieť poslať, inak sa taký set už nikdy neuloží.
const LEGACY_LIFT = { set_id: 'moj-vyklop', name: 'Môj výklop', generic_type: 'lift',
                      use_type: 'lift', opening_mode: 'classic', manufacturer: 'Blum',
                      members: [{ per: 'unit', qty: 1, code: '347810' }] };
eq(hwsSetDraftOf(HL_SET).lift_system, 'hl_top', 'uložený systém sa dostane do editora');
eq(hwsSetDraftOf(LEGACY_LIFT).lift_system, '', 'legacy set sa otvorí s prázdnym systémom');

const doplneny = hwsBuildSetPayload({ set_id: LEGACY_LIFT.set_id, name: LEGACY_LIFT.name,
                                      use_type: 'lift', opening_mode: 'classic',
                                      lift_system: 'hk_top', manufacturer: 'Blum' },
                                    hwsMembersOf(LEGACY_LIFT));
eq(doplneny.lift_system, 'hk_top', 'doplnený systém odchádza na server');
// Kľúč sa posiela VŽDY (aj prázdny) — `save_set!` merguje, takže vynechaný
// kľúč by v uloženom sete nechal systém po prepnutí typu použitia.
const zasuvka = hwsBuildSetPayload({ set_id: 'z', name: 'Z', use_type: 'drawer',
                                     opening_mode: 'classic', drawer_construction: 'metal',
                                     lift_system: 'hk_top', manufacturer: 'Hettich' }, []);
eq(zasuvka.lift_system, '', 'pri zásuvke odchádza PRÁZDNY systém (vedomé vymazanie)');
ok(Object.prototype.hasOwnProperty.call(zasuvka, 'lift_system'),
   'kľúč sa nikdy nevynechá — server merguje');

console.log(`OK — test_hw_sets_code_by_param.js: ${n} testov preslo`);
