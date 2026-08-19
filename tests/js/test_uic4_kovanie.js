// Testy UI-C4: KOVANIE — boxy podla VLASTNIKA (hardware.js), dependency-free Node.
// LEN ciste funkcie bez DOM: odvodenie kluca skupiny z owner_part_key, poradie
// boxov podla zoznamu ciel, nazvy hlaviciek, delba popisu vlastnika medzi
// hlavicku a riadok, pocty a zaradenie vypnutych kategorii.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwGroupKeyOf, hwLabelHead, hwLabelTail, hwRowOwnerText, hwGroupTitle,
        hwGroupCountText, hwGroupOrder, hwGroups, hwDisabledOffs,
        HW_GROUP_CAB, HW_GROUP_INSIDE } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hardware.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// --- 1) kluc skupiny sa ODVODZUJE z owner_part_key (ziadne nove datove pole) ---
eq(hwGroupKeyOf(null), HW_GROUP_CAB, 'kovanie bez vlastnika patri skrinke');
eq(hwGroupKeyOf(''), HW_GROUP_CAB, 'prazdny vlastnik = skrinka');
eq(hwGroupKeyOf('front:F1/wing:left'), 'front:F1', 'lave kridlo patri svojmu celu');
eq(hwGroupKeyOf('front:F1/wing:right'), 'front:F1', 'obe kridla su JEDNO celo — jeden box');
eq(hwGroupKeyOf('front:Fabc-1-2/panel'), 'front:Fabc-1-2', 'zasuvkove celo (generovane id)');
eq(hwGroupKeyOf('zone:Z1/shelf:2'), HW_GROUP_INSIDE, 'podperky police idu do spolocneho boxu Vnutro');
eq(hwGroupKeyOf('cabinet/side:left'), HW_GROUP_INSIDE, 'iny dielec skrinky tiez do Vnutra');

// --- 2) popis vlastnika sa DELI medzi hlavicku a riadok ------------------------
// Server posiela „F2 · zásuvkové čelo" — cislo cela nesie hlavicka boxu,
// upresnenie ostava v riadku. Ziadne opakovanie pod sebou.
eq(hwLabelHead('F2 · zásuvkové čelo'), 'F2', 'hlavicka berie prvu cast');
eq(hwLabelTail('F2 · zásuvkové čelo'), 'zásuvkové čelo', 'riadok berie druhu cast');
eq(hwLabelHead('F1 · dvierka, krídlo 2/3'), 'F1', 'kridlo: hlavicka je stale celo');
eq(hwLabelTail('F1 · dvierka, krídlo 2/3'), 'dvierka, krídlo 2/3', 'riadok nesie cele upresnenie');
eq(hwLabelHead('Polica 2'), 'Polica 2', 'popis bez oddelovaca ostava cely');
eq(hwLabelTail('Polica 2'), '', 'a nema co dat riadku');

eq(hwRowOwnerText(HW_GROUP_CAB, 'F1 · dvierka'), '', 'v boxe skrinky ziadny vlastnik v riadku');
eq(hwRowOwnerText('front:F1', 'F1 · dvierka ľavé'), 'dvierka ľavé', 'v boxe cela len upresnenie');
eq(hwRowOwnerText(HW_GROUP_INSIDE, 'Polica 2'), 'Polica 2', 'vo Vnutre musi ostat CELY popis');

// --- 3) nazvy hlaviciek --------------------------------------------------------
eq(hwGroupTitle(HW_GROUP_CAB, null, 'CAB-005'), 'Skrinka CAB-005', 'box skrinky nesie jej ID');
eq(hwGroupTitle(HW_GROUP_CAB, null, ''), 'Skrinka', 'bez ID aspon „Skrinka"');
eq(hwGroupTitle('front:F3', 'F3 · zásuvkové čelo', 'CAB-005'), 'Čelo F3', 'box cela je pomenovany celom');
eq(hwGroupTitle('front:Fxyz', '', 'CAB-005'), 'Čelo', 'bez serveroveho popisu sa NIC nevymysla');
eq(hwGroupTitle(HW_GROUP_INSIDE, 'Polica 1', 'CAB-005'), 'Vnútro skrinky', 'spolocny box vnutra');

// --- 4) pocty v hlavicke (slovenske tvary) -------------------------------------
eq(hwGroupCountText(1), '1 položka', 'jednotne cislo');
eq(hwGroupCountText(2), '2 položky', 'dva az styri');
eq(hwGroupCountText(4), '4 položky', 'styri');
eq(hwGroupCountText(5), '5 položiek', 'pat a viac');
eq(hwGroupCountText(0), '0 položiek', 'nula');

// --- 5) poradie boxov: Skrinka -> cela v poradi ZOZNAMU -> Vnutro --------------
const FRONT_IDS = ['Fa', 'Fb', 'Fc'];
eq(hwGroupOrder(HW_GROUP_CAB, FRONT_IDS) < hwGroupOrder('front:Fa', FRONT_IDS), true,
   'skrinka je vzdy prva');
eq(hwGroupOrder('front:Fa', FRONT_IDS) < hwGroupOrder('front:Fc', FRONT_IDS), true,
   'cela idu v poradi zoznamu ciel');
eq(hwGroupOrder('front:Fc', FRONT_IDS) < hwGroupOrder(HW_GROUP_INSIDE, FRONT_IDS), true,
   'vnutro je posledne');
eq(hwGroupOrder('front:Fneznamy', FRONT_IDS) < hwGroupOrder(HW_GROUP_INSIDE, FRONT_IDS), true,
   'celo mimo zoznamu (stary payload) sa nestrati — ide za znamymi, pred Vnutro');

// --- 6) skladanie skupin z realneho payloadu ----------------------------------
const ITEMS = [
  { owner_part_key: null, owner_label: null, generic_type: 'leg', rule_id: 'nohy-zakladne', quantity: 4 },
  { owner_part_key: 'front:Fb/panel', owner_label: 'F2 · zásuvkové čelo',
    generic_type: 'slide', rule_id: 'vysuvy-nl-podla-hlbky', quantity: 1 },
  { owner_part_key: 'front:Fa/wing:left', owner_label: 'F1 · dvierka ľavé',
    generic_type: 'hinge', rule_id: 'zavesy-podla-vysky', quantity: 2 },
  { owner_part_key: 'front:Fa/wing:right', owner_label: 'F1 · dvierka pravé',
    generic_type: 'hinge', rule_id: 'zavesy-podla-vysky', quantity: 2 },
  { owner_part_key: 'zone:Z1/shelf:1', owner_label: 'Polica 1',
    generic_type: 'shelf_pin', rule_id: 'podperky-policove', quantity: 4 }
];

const groups = hwGroups(ITEMS, [], FRONT_IDS, 'CAB-005');
eq(groups.map(g => g.key), [HW_GROUP_CAB, 'front:Fa', 'front:Fb', HW_GROUP_INSIDE],
   'poradie boxov: skrinka, cela podla zoznamu, vnutro');
eq(groups.map(g => g.title), ['Skrinka CAB-005', 'Čelo F1', 'Čelo F2', 'Vnútro skrinky'],
   'hlavicky boxov');
eq(groups[1].items.length, 2, 'obe kridla F1 su v JEDNOM boxe');
eq(groups[1].ownerKeys, ['front:Fa/wing:left', 'front:Fa/wing:right'],
   'box nesie part_key VSETKYCH svojich vlastnikov (to oznaci klik v modeli)');
eq(groups[0].ownerKeys, [], 'box skrinky nema part_key — oznaci sa cela skrinka');

// Poradie poloziek V RAMCI boxu ostava poradim payloadu (server je autorita).
eq(groups[1].items.map(i => i.owner_part_key),
   ['front:Fa/wing:left', 'front:Fa/wing:right'], 'poradie v boxe = poradie payloadu');

// --- 7) vypnute kategorie patria do boxu svojho vlastnika ----------------------
const OVERRIDES = [
  // vypnuta polozka, ktora v `items` UZ NIE JE -> patri do zoznamu
  { owner_part_key: 'front:Fb/panel', owner_label: 'F2 · zásuvkové čelo',
    generic_type: 'handle', rule_id: 'uchytkovy-profil-zasuvky', disabled: true },
  // vypnuta polozka, ktorej ale zodpoveda ZIVA polozka -> nesmie sa zdvojit
  { owner_part_key: null, owner_label: null, generic_type: 'leg',
    rule_id: 'nohy-zakladne', disabled: true },
  // rucny pocet nie je vypnutie
  { owner_part_key: null, generic_type: 'leg', rule_id: 'ine', quantity: 6 }
];
const offs = hwDisabledOffs(ITEMS, OVERRIDES);
eq(offs.map(o => o.rule_id), ['uchytkovy-profil-zasuvky'],
   'do zoznamu ide LEN disabled override bez zodpovedajucej zivej polozky');

const g2 = hwGroups(ITEMS, offs, FRONT_IDS, 'CAB-005');
eq(g2.map(x => x.key), [HW_GROUP_CAB, 'front:Fa', 'front:Fb', HW_GROUP_INSIDE],
   'vypnuta polozka nezalozi novy box, ked jej celo uz box ma');
eq(g2[2].offs.length, 1, 'vypnuta polozka je v boxe svojho cela');
eq(g2[2].items.length + g2[2].offs.length, 2, 'pocet v hlavicke rata obe casti');

// Vypnuta polozka MOZE byt jediny obsah boxu (celo, ktore vsetko kovanie vypnute).
const onlyOff = hwGroups([], [{ owner_part_key: 'front:Fc/wing:single',
                                owner_label: 'F3 · dvierka', generic_type: 'hinge',
                                rule_id: 'zavesy-podla-vysky', disabled: true }],
                         FRONT_IDS, 'CAB-005');
eq(onlyOff.map(x => x.key), ['front:Fc'], 'box vznikne aj len z vypnutej polozky');
eq(onlyOff[0].ownerKeys, ['front:Fc/wing:single'], 'a vie, koho ma oznacit');

// --- 8) prazdne / poskodene vstupy nesmu padnut -------------------------------
eq(hwGroups(null, null, null, ''), [], 'ziadne data = ziadne boxy');
eq(hwGroups([null, undefined], [null], [], ''), [], 'prazdne polozky sa ticho preskocia');
eq(hwDisabledOffs(null, null), [], 'null overridy su bezpecne');

console.log(`OK — test_uic4_kovanie.js: ${n} testov preslo`);
