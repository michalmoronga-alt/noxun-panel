// Testy D-80: svetla vyska vnutra a geometria hornych vystuh (JS zrkadlo Ruby
// Construction). Dependency-free Node — LEN ciste funkcie z core.js (bez DOM).
// Hodnoty su ZRKADLOM tests/pure/test_construction.rb — ked sa rozidu, jedna
// z dvoch strán klame a nahlad/„Svetla vyska" prestanu sediet s modelom.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { nxInteriorZ, nxRailGeom, nxCarcassDepth, NX_MIN_INTERIOR_H } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function close(actual, expected, msg){
  n++;
  assert.ok(Math.abs(actual - expected) < 0.01, `${msg}: cakam ${expected}, dostal ${actual}`);
}
function eq(actual, expected, msg){
  n++;
  assert.strictEqual(actual, expected, `${msg}: cakam ${expected}, dostal ${actual}`);
}

// Zakladny korpus = raw_cfg z Ruby testov: 600x720x510, sokel 100, t 18,
// chrbat overlay 3 mm, rail_depth 100 -> z_lo = 118.
function cab(over){
  const c = { height:720, thickness:18, floor_height:100, depth:510,
              back_mode:'overlay', back_thickness:3,
              top_mode:'full', rails_orientation:'flat', rails_top_offset:0, rail_depth:100 };
  return Object.assign(c, over || {});
}

// --- konstanty -----------------------------------------------------------------
eq(NX_MIN_INTERIOR_H, 20, 'rezerva vnutra sedi s Ruby MIN_INTERIOR_H');

// --- carcassDepth (D-37) --------------------------------------------------------
close(nxCarcassDepth(cab()), 507, 'overlay 3 mm skracuje telo');
close(nxCarcassDepth(cab({ back_thickness:18 })), 492, 'overlay 18 mm');
close(nxCarcassDepth(cab({ back_mode:'inset' })), 510, 'inset telo neskracuje');
close(nxCarcassDepth(cab({ back_mode:'groove' })), 510, 'groove telo neskracuje');
close(nxCarcassDepth(cab({ back_thickness:0 })), 507, 'nulova hrubka -> default 3');

// --- matica vrch x orientacia x odsadenie (zrkadlo Ruby tabulky) ----------------
[
  ['full',      'flat',      0, 702, 584, 'plny vrch ignoruje parametre vystuh'],
  ['full',      'upright', 500, 702, 584, 'plny vrch: extremne odsadenie bez ucinku'],
  ['none',      'flat',     30, 720, 602, 'bez vrchu: vnutro az po vrch korpusu'],
  ['two_rails', 'flat',      0, 702, 584, 'flat bez odsadenia = povodne h - t'],
  ['two_rails', 'flat',     30, 672, 554, 'flat s odsadenim 30'],
  ['two_rails', 'flat',    500, 202,  84, 'flat extrem: odsadenie sa este zmesti'],
  ['two_rails', 'upright',   0, 620, 502, 'upright: vnutro konci pod CELOU vystuhou'],
  ['two_rails', 'upright',  30, 590, 472, 'upright + odsadenie 30'],
  ['two_rails', 'upright', 500, 138,  20, 'upright extrem: odsadenie orezane, vnutro drzi 20']
].forEach(function(row){
  const tm = row[0], ori = row[1], off = row[2], zHi = row[3], avail = row[4], label = row[5];
  const iv = nxInteriorZ(cab({ top_mode:tm, rails_orientation:ori, rails_top_offset:off }));
  const tag = `${tm}/${ori}/off ${off}`;
  close(iv.zHi, zHi, `${tag}: zHi — ${label}`);
  close(iv.availH, avail, `${tag}: availH — ${label}`);
  close(iv.zLo, 118, `${tag}: zLo sa nemeni`);
});

// --- realny pripad z hlasenia (860 / sokel 150 / flat / odsadenie 30) -----------
const real = nxInteriorZ(cab({ height:860, floor_height:150, top_mode:'two_rails',
                               rails_orientation:'flat', rails_top_offset:30 }));
close(real.zLo, 168, 'realny pripad: zLo');
close(real.zHi, 812, 'realny pripad: zHi = spodna hrana vystuhy');
close(real.availH, 644, 'realny pripad: svetla vyska 644 (pred opravou 674)');

// --- railGeom: clampy hlbky/vysky ----------------------------------------------
const flat0 = nxRailGeom(cab({ top_mode:'two_rails' }));
close(flat0.depth, 100, 'flat: hlbka v limite (d/2 - 10 = 243.5)');
close(flat0.occupy, 18, 'flat zabera hrubku dosky');
close(flat0.zTop, 720, 'flat: horna hrana na vrchu korpusu');
close(flat0.zBottom, 702, 'flat: spodna hrana = strop vnutra');
eq(flat0.upright, false, 'flat orientacia');

close(nxRailGeom(cab({ top_mode:'two_rails', rail_depth:5 })).depth, 20, 'flat: minimum hlbky 20');
close(nxRailGeom(cab({ top_mode:'two_rails', depth:150, rail_depth:400 })).depth, 63.5,
      'flat: hlbka orezana na (carcass 147)/2 - 10');

const up0 = nxRailGeom(cab({ top_mode:'two_rails', rails_orientation:'upright' }));
close(up0.depth, 100, 'upright: vyska v limite');
close(up0.occupy, 100, 'upright zabera celu svoju vysku');
close(up0.zBottom, 620, 'upright: spodna hrana = h - vyska');
eq(up0.upright, true, 'upright orientacia');

// Nizky korpus: vyska vystuhy sa oreze na dostupne miesto (h - z_lo - 20).
const low = nxRailGeom(cab({ top_mode:'two_rails', rails_orientation:'upright', height:200 }));
close(low.depth, 62, 'upright clamp vysky (200-118-20)');
close(low.zBottom, 138, 'upright clamp: spodna hrana');
close(nxRailGeom(cab({ top_mode:'two_rails', rails_orientation:'upright', rail_depth:5 })).zBottom, 700,
      'upright minimum 20 -> spodna hrana 700');

// --- railGeom: clamp odsadenia (BLOCKER 1 — nikdy pod rezervu vnutra) -----------
const ext = nxRailGeom(cab({ top_mode:'two_rails', rails_orientation:'upright',
                             rail_depth:400, rails_top_offset:500 }));
close(ext.wantedOffset, 500, 'ziadane odsadenie ostava v datach (podklad warningu)');
close(ext.offset, 182, 'odsadenie orezane na 182 (hlava 582 - vystuha 400)');
close(ext.zBottom, 138, 'spodna hrana vystuhy po oreze');
close(nxInteriorZ(cab({ top_mode:'two_rails', rails_orientation:'upright',
                        rail_depth:400, rails_top_offset:500 })).availH, 20,
      'vnutro po oreze drzi presne rezervu 20 mm');

const flatOff = nxRailGeom(cab({ top_mode:'two_rails', rails_top_offset:30 }));
close(flatOff.offset, 30, 'odsadenie v limite sa neoreze');
close(flatOff.zTop, 690, 'flat + odsadenie: horna hrana vystuhy');
close(flatOff.zBottom, 672, 'flat + odsadenie: spodna hrana vystuhy');

// Zaporne odsadenie sa neguje (vystuhy nikdy nad vrch korpusu).
close(nxRailGeom(cab({ top_mode:'two_rails', rails_top_offset:-50 })).offset, 0,
      'zaporne odsadenie -> 0');

console.log(`OK — test_interior_height.js: ${n} testov preslo`);
