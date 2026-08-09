// Testy D-90 (PR 2) — volba uchytkoveho profilu v paneli.
// LEN ciste funkcie z core.js (bez DOM): register profilov chodi z Ruby
// (FrontProfiles.options), JS si ziadny zoznam nedrzi — preto sa do funkcii
// odovzdava parametrom. Zrkadlo Ruby sady tests/pure/test_d90_ukw_profil.rb.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { frontProfileRec, frontProfileReduction, frontProfileNext } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// Presna podoba payloadu z Ruby (FrontProfiles.options).
const REG = [{ id: 'ukw7', name: 'Profil UKW-7', short: 'UKW-7', reduction: 36.0 }];

// --- vyhladanie zaznamu --------------------------------------------------------
eq(frontProfileRec('ukw7', REG).name, 'Profil UKW-7', 'znamy profil');
eq(frontProfileRec('none', REG), null, "'none' nie je profil, ale jeho absencia");
eq(frontProfileRec('', REG), null, 'prazdna hodnota = neutral');
eq(frontProfileRec(null, REG), null, 'chybajuca hodnota = neutral');
eq(frontProfileRec('ukw11', REG), null, 'profil z NOVSEJ verzie = neutral (ako Ruby normalize)');
eq(frontProfileRec('ukw7', []), null, 'prazdny register (Ruby nic neposlalo) = ziadny profil');

// --- skratenie cela pre nahlad -------------------------------------------------
eq(frontProfileReduction('ukw7', REG), 36, 'skratenie ide z registry, nie z konstanty v JS');
eq(frontProfileReduction('none', REG), 0, 'bez profilu sa celo neskracuje');
eq(frontProfileReduction('ukw11', REG), 0, 'neznamy profil nikdy neskracuje panel');
eq(frontProfileReduction('ukw7', []), 0, 'bez registry ziadne pasmo v nahlade');
eq(frontProfileReduction('ukw7', [{ id: 'ukw7', name: 'x', short: 'x', reduction: 0 }]), 0,
   'nulove skratenie = ziadne pasmo (nekreslime pruh vysky 0)');

// --- cyklus klikom -------------------------------------------------------------
eq(frontProfileNext('none', REG), 'ukw7', 'prvy klik zapne profil');
eq(frontProfileNext('ukw7', REG), 'none', 'dalsi klik ho vypne');
eq(frontProfileNext(null, REG), 'ukw7', 'riadok bez hodnoty startuje z neutralu');
eq(frontProfileNext('ukw11', REG), 'none', 'neznama hodnota sa klikom uprace na neutral');
eq(frontProfileNext('none', []), 'none', 'bez registry sa niet kam prepnut');
// rozsiritelnost: dalsi profil v registry sa do cyklu zaradi bez zmeny kodu
const REG2 = REG.concat([{ id: 'ukw9', name: 'Profil UKW-9', short: 'UKW-9', reduction: 30.0 }]);
eq(frontProfileNext('none', REG2), 'ukw7', 'poradie drzi registry');
eq(frontProfileNext('ukw7', REG2), 'ukw9', 'druhy profil je dalsi v poradi');
eq(frontProfileNext('ukw9', REG2), 'none', 'cyklus sa uzatvara na neutral');
eq(frontProfileReduction('ukw9', REG2), 30, 'kazdy profil ma vlastne skratenie');

// --- geometria pasma v nahlade (zrkadlo vypoctu v preview.js) -------------------
// panel = vyska RIADKU - skratenie; pruh profilu sedi na vrchu riadku.
function band(rowH, profile, reg){
  const red = Math.min(frontProfileReduction(profile, reg), rowH);
  return { panel: rowH - red, band: red };
}
eq(band(500, 'ukw7', REG), { panel: 464, band: 36 }, 'celo 500 mm: panel 464 + profil 36');
eq(band(500, 'none', REG), { panel: 500, band: 0 }, 'bez profilu je panel cely riadok');
ok(band(20, 'ukw7', REG).panel === 0 && band(20, 'ukw7', REG).band === 20,
   'degenerovany riadok (server ho odmietne) nikdy nekresli zaporny panel');

console.log(`OK test_d90_profil_ui.js — ${n} kontrol`);
