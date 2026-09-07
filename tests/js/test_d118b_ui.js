// Testy D-118b (UI): vyhradena bunka `none` a titulok legacy pravidla vysuvov.
// Dependency-free Node, LEN ciste funkcie bez DOM.
//
// Co strazia:
//   R1 suhrn clena setu pise „bez kódu", nikdy surove `none` (a rozpozna aj
//      „NONE"/„None" — server ho uklada kanonicky, ale editor smie dostat coko)
//   R2 round-trip editora sentinel NEZAHODI (inak by sa pri prvom ulozeni setu
//      z bunky „vedome bez kodu" stalo „chybajuca bunka" = ORANGE v nakupe)
//   R3 pravidlo `vysuvy-nl-podla-hlbky` ma v zozname vlastny titulok a vetu,
//      ktora povie, KEDY sa vobec pouzije; ostatne pravidla su nedotknute
//   R4 `rdLabel` sa NEMENI — je to spolocny slovnik typov kovania so serverom
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwsMemberSummary, hwsBuildMembers, hwsMembersOf } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_sets.js'));
const { rdRuleTitle, rdIsLegacySlide, RD_LEGACY_SLIDE_HINT, rdLabel } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'rules.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- R1: suhrn clena ----------------------------------------------------------
eq(hwsMemberSummary({ per: 'unit', qty: 1, code_by_nl: { 350: '352908', 620: 'none' } }, []),
   'rad NL: 350→352908, 620→bez kódu',
   'sentinel sa pise po ludsky');
eq(hwsMemberSummary({ per: 'unit', qty: 1, code_by_nl: { 620: 'NONE' } }, []),
   'rad NL: 620→bez kódu',
   'rozpozna aj velke pismena');
eq(hwsMemberSummary({ per: 'unit', qty: 1, code_by_nl: { 420: '357695' } }, []),
   'rad NL: 420→357695',
   'bezny kod sa nemeni');

// --- R2: round-trip editora ---------------------------------------------------
const set = { set_id: 'x', name: 'X', generic_type: 'slide',
              members: [{ per: 'unit', qty: 1, label: 'PTOs mechanizmus',
                          code_by_nl: { 350: '352908', 620: 'none' } }] };
const back = hwsBuildMembers(hwsMembersOf(set));
eq(back[0].code_by_nl, { 350: '352908', 620: 'none' },
   'editor sentinel nezahodi (inak by z „vedome bez kodu" bola „chybajuca bunka")');

// --- R3: titulok a veta legacy pravidla ---------------------------------------
const legacy = { rule_id: 'vysuvy-nl-podla-hlbky', output: 'slide', kind: 'fit_series' };
const iny = { rule_id: 'zavesy-podla-vysky', output: 'hinge', kind: 'bands' };
ok(rdIsLegacySlide(legacy), 'legacy pravidlo sa rozpozna podla rule_id');
ok(!rdIsLegacySlide(iny), 'ine pravidlo nie');
ok(!rdIsLegacySlide({ output: 'slide' }), 'pravidlo BEZ rule_id nie (nove, pouzivatelske)');
eq(rdRuleTitle(legacy), 'Výsuv — staré zákazky bez systému zásuvky',
   'titulok prizna, cim pravidlo je');
eq(rdRuleTitle(iny), 'Závesy', 'ostatne pravidla maju titulok nezmeneny');
ok(RD_LEGACY_SLIDE_HINT.indexOf('bez systému zásuvky') >= 0
   && RD_LEGACY_SLIDE_HINT.indexOf('receptu') >= 0,
   'veta povie, kedy sa pravidlo pouzije a kedy nie');

// --- R4: spolocny slovnik so serverom ostava --------------------------------
eq(rdLabel('slide'), 'Výsuv', 'rdLabel sa NEMENI (guard test na zhodu s Ruby `label_for`)');

console.log(`OK test_d118b_ui.js (${n} kontrol)`);
