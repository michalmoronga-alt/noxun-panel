// Testy D-92: sekundarny riadok „co sa realne kupi" v sekcii Kovanie panela
// (hardware.js) — dependency-free Node, LEN ciste funkcie bez DOM.
// Autorita nakupu je SERVER (HardwareSets.explain); tu sa overuje iba to, ze
// sa jeho vystup poskladá do jedneho kompaktneho riadku a ze nekompletny
// nakup je oznaceny ako upozornenie.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { hwMemberText, hwBuyLine, HW_NO_CATALOG } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'hardware.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// Payload zo servera (HardwareSets.explain) — jednoclenny set vysuvu.
const SLIDE = {
  set_id: 'atira-h176',
  set_name: 'Atira biela H176',
  members: [{ code: '357783', name: 'K-Atira zásuvka 620/50kg', missing: false,
              qty: 1, per: 'unit', label: 'K-sada', nominal_length: null }],
  problems: []
};
const clone = o => JSON.parse(JSON.stringify(o));

// --- clen setu -----------------------------------------------------------------
eq(hwMemberText(SLIDE.members[0]), '357783 · K-Atira zásuvka 620/50kg', 'kod + nazov');
eq(hwMemberText({ code: '105408', name: 'Krytka misky', qty: 8 }),
   '8× 105408 · Krytka misky', 'pocet vacsi ako 1 je pred kodom');
eq(hwMemberText({ code: '367823', name: null, qty: 1 }),
   '367823 · ' + HW_NO_CATALOG, 'kod mimo katalogu sa priznava, nezamlci');
eq(hwMemberText(null), '', 'null clen nespadne');

// --- kompletny nakup -----------------------------------------------------------
eq(hwBuyLine(SLIDE),
   { text: 'Atira biela H176 → 357783 · K-Atira zásuvka 620/50kg', warn: false },
   'jeden clen: nazov setu -> kod a nazov polozky');

const HINGE = {
  set_id: 'zaves-klasik', set_name: 'Záves KLASIK',
  members: [
    { code: '104717', name: 'Záves Sensys 110°', missing: false, qty: 4, per: 'unit' },
    { code: '250831', name: 'TipOn na dvierka', missing: false, qty: 1, per: 'owner' }
  ],
  problems: []
};
eq(hwBuyLine(HINGE),
   { text: 'Záves KLASIK → 4× 104717 · Záves Sensys 110° + 250831 · TipOn na dvierka',
     warn: false },
   'viacclenny set: clenovia oddeleni " + "');

// --- nekompletny nakup (upozornenie) -------------------------------------------
const NO_CODE = { set_id: 'atira-h70', set_name: 'Atira biela H70', members: [],
                  problems: ['set „atira-h70“ nemá kód pre dĺžku NL 500'] };
eq(hwBuyLine(NO_CODE),
   { text: 'set „atira-h70“ nemá kód pre dĺžku NL 500', warn: true },
   'bez kodov ostane len slovensky dovod zo servera a riadok je upozornenie');

const PARTIAL = clone(HINGE);
PARTIAL.problems = ['výška sokla 100 mm je mimo pásiem setu „nohy“ (noha)'];
eq(hwBuyLine(PARTIAL).warn, true, 'ciastocny nakup je TIEZ upozornenie');
assert.ok(hwBuyLine(PARTIAL).text.indexOf('104717') > -1, 'zname kody ostanu viditelne'); n++;
assert.ok(hwBuyLine(PARTIAL).text.indexOf('mimo pásiem') > -1, 'aj s dovodom problemu'); n++;

// --- nic na zobrazenie ----------------------------------------------------------
eq(hwBuyLine(null), null, 'bez payloadu sa riadok nekresli (stary payload)');
eq(hwBuyLine({ set_id: null, set_name: null, members: [], problems: [] }), null,
   'prazdny rozpis bez problemov = ziadny riadok navyse');
eq(hwBuyLine({ members: [], problems: [''] }), null, 'prazdny text nie je problem');

// Set BEZ nazvu (legacy definicia) — kody sa aj tak ukazu.
eq(hwBuyLine({ set_name: null, members: [{ code: '82744', name: 'Klzák 17 mm', qty: 4 }],
               problems: [] }),
   { text: '4× 82744 · Klzák 17 mm', warn: false },
   'bez nazvu setu sa sipka nekresli');

console.log(`OK — test_d92_hw_nakup.js: ${n} testov preslo`);
