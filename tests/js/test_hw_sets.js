// Testy V0.6 D1b: sety kovania v okne Katalog (hw_sets.js) — dependency-free
// Node. LEN ciste funkcie bez DOM: slug identity noveho setu, filter setov
// podla typu, citatelny suhrn clena, editor stav <-> server payload
// round-trip (rad NL -> mapa; prazdne riadky von — server validuje zvysok).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwsSlug, hwsSetsForType, hwsMemberSummary, hwsBuildSetPayload,
        hwsEditStateFrom } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hw_sets.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- hwsSlug ------------------------------------------------------------------
eq(hwsSlug('Záves KLASIK (Sensys 110°)'), 'zaves-klasik-sensys-110', 'diakritika von, medzery/zatvorky -> pomlcky');
eq(hwsSlug('  '), 'set', 'prazdny nazov = fallback');
eq(hwsSlug('Atira biela H70'), 'atira-biela-h70', 'bezne meno');

// --- hwsSetsForType -----------------------------------------------------------
const SETS = [
  { set_id: 'a', generic_type: 'hinge' },
  { set_id: 'b', generic_type: 'leg' },
  { set_id: 'c', generic_type: 'hinge' }
];
eq(hwsSetsForType(SETS, 'hinge').map(s => s.set_id), ['a', 'c'], 'filter typu, poradie kniznice');
eq(hwsSetsForType(SETS, 'slide'), [], 'typ bez setov');
eq(hwsSetsForType(null, 'hinge'), [], 'null vstup bezpecny');

// --- hwsMemberSummary ---------------------------------------------------------
eq(hwsMemberSummary({ code: '104717', qty: 1, per: 'unit', label: 'záves' }),
   'záves 104717 ×1', 'clen s labelom');
eq(hwsMemberSummary({ code: '250831', qty: 1, per: 'owner' }),
   '250831 ×1 na vlastníka (dvierka)', 'per owner popis');
eq(hwsMemberSummary({ code_by_nl: { '470': '357696', '420': '357695' }, qty: 1, per: 'unit' }),
   'rad NL: 420→357695, 470→357696', 'rad zoradeny ciselne podla NL');

// --- hwsBuildSetPayload -------------------------------------------------------
const built = hwsBuildSetPayload({
  set_id: 'zaves-p2o', name: ' Záves P2O ', generic_type: 'hinge',
  members: [
    { is_series: false, per: 'unit', qty: '2', code: ' 245723 ', label: 'záves P2O' },
    { is_series: false, per: 'owner', qty: 1, code: '250831', label: '' },
    { is_series: true, per: 'unit', qty: 1,
      series: [{ nl: ' 420 ', code: ' 357695 ' }, { nl: '', code: 'x' }, { nl: '470', code: '' }] }
  ]
});
eq(built.set_id, 'zaves-p2o', 'identita sa nesie');
eq(built.name, 'Záves P2O', 'nazov trim');
eq(built.members[0], { per: 'unit', qty: 2, label: 'záves P2O', code: '245723' },
   'clen: qty na cislo, kod trim, label len ked je');
eq(built.members[1], { per: 'owner', qty: 1, code: '250831' }, 'per owner bez labelu');
eq(built.members[2], { per: 'unit', qty: 1, code_by_nl: { '420': '357695' } },
   'rad: len kompletne riadky (NL aj kod), trim');

// --- hwsEditStateFrom (round-trip s buildom) -----------------------------------
const libSet = {
  set_id: 'vysuv-atira-biela-h70', name: 'Atira biela H70 (rad podľa NL)',
  generic_type: 'slide',
  members: [{ per: 'unit', qty: 1, label: 'K-sada',
              code_by_nl: { '470': '357696', '420': '357695' } }]
};
const edit = hwsEditStateFrom(libSet);
eq(edit.existing, true, 'edit stav existujuceho setu');
eq(edit.members[0].is_series, true, 'rad sa rozpozna');
eq(edit.members[0].series, [{ nl: '420', code: '357695' }, { nl: '470', code: '357696' }],
   'riadky radu zoradene podla NL');
const round = hwsBuildSetPayload(edit);
eq(round.members[0].code_by_nl, { '420': '357695', '470': '357696' },
   'edit -> payload round-trip bez straty');
eq(round.set_id, libSet.set_id, 'identita drzi');

const plain = hwsEditStateFrom({ set_id: 'k', name: 'K', generic_type: 'hinge',
                                 members: [{ code: '1', per: 'owner', qty: 3 }] });
eq(plain.members[0], { is_series: false, per: 'owner', qty: 3, label: '', code: '1' },
   'plochy clen do edit stavu');

console.log(`OK — test_hw_sets.js: ${n} testov preslo`);
