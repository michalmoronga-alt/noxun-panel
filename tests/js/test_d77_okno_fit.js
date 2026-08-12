// Testy D-77: okno sa nesmie otvorit odseknute — ciste jadro win_fit.js
// (nxFitTarget / nxFitChrome). Dependency-free Node:
//   node tests/js/test_d77_okno_fit.js
// Kontrakt: dorovnava sa OBOMA smermi — nahor po deklarovane minimum okna,
// nadol po dostupnu plochu obrazovky (plocha ma prednost pred minimom); medzi
// tymito hranicami sa velkosti okna nikto nedotkne. Autorita „rozumneho rozmeru"
// je server (Engine.register_dialog_fit zahodi hodnoty mimo 240..2600 px) —
// toto je merac.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { nxFitTarget, nxFitChrome } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'win_fit.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const BIG = { w: 1920, h: 1040 };          // bezna dostupna plocha
const CHROME = { w: 16, h: 40 };           // ramik + titulok okna
const MIN = { w: 640, h: 540 };            // typicke minimum satelitu

// --- okno uz staci: nesiaha sa nan --------------------------------------------
eq(nxFitTarget({ w: 700, h: 600 }, MIN, BIG, CHROME), null,
   'vacsie okno ostava, ako si ho pouzivatel nastavil');
eq(nxFitTarget({ w: 640, h: 540 }, MIN, BIG, CHROME), null,
   'presne minimum sa uz nedorovnava');
eq(nxFitTarget({ w: 639, h: 539 }, MIN, BIG, CHROME), null,
   'rozdiel v ramci tolerancie (DPI zaokruhlenie) nespusti resize');

// --- male okno: dorovna sa po minimum + ramik ---------------------------------
eq(nxFitTarget({ w: 400, h: 300 }, MIN, BIG, CHROME), { w: 656, h: 580 },
   'zapamatane male okno sa dorovna na minimum + ramik');
eq(nxFitTarget({ w: 400, h: 900 }, MIN, BIG, CHROME), { w: 656, h: 940 },
   'uzke ale vysoke okno: vysku si NECHA (nikdy sa nezmensuje)');
eq(nxFitTarget({ w: 900, h: 300 }, MIN, BIG, CHROME), { w: 916, h: 580 },
   'siroke ale nizke okno: sirku si NECHA');

// --- obrazovka rozhoduje: na malom monitore sa okno neprelezie ---------------
(function(){
  const small = { w: 800, h: 600 }; // netbook / zdielana plocha
  const t = nxFitTarget({ w: 400, h: 300 }, MIN, small, CHROME);
  ok(t.w <= small.w, `sirka okna sa zmesti na plochu (${JSON.stringify(t)})`);
  ok(t.h <= small.h, `vyska okna sa zmesti na plochu (${JSON.stringify(t)})`);
  // Minimum sa este zmesti (640+16 < 800, 540+40 = 580 < 600) — orezanie nenastalo.
  eq(t, { w: 656, h: 580 }, 'minimum sa na tuto plochu zmesti cele');

  const tiny = { w: 600, h: 460 }; // plocha mensia nez minimum okna
  const t2 = nxFitTarget({ w: 300, h: 240 }, MIN, tiny, CHROME);
  eq(t2, { w: 600, h: 460 }, 'na malej ploche je stropom plocha, nie minimum okna');
})();

// --- Codex #164 P2: okno VACSIE nez plocha sa musi zmensit -------------------
// Zapamatane okno z vacsieho monitora (alebo po znizeni rozlisenia / pripojeni
// cez remote desktop) trca mimo obrazovky — to je presne choroba D-77, len z
// druhej strany. Skorsia verzia riesila iba „viewport >= ciel" a takto velke
// okno nechala orezane.
(function(){
  eq(nxFitTarget({ w: 2000, h: 1200 }, MIN, BIG, CHROME), { w: 1920, h: 1040 },
     'okno vacsie nez plocha sa zmensi presne na plochu');
  eq(nxFitTarget({ w: 2000, h: 600 }, MIN, BIG, CHROME), { w: 1920, h: 640 },
     'preteka len sirka — vyska (nad minimom) ostava');
  eq(nxFitTarget({ w: 700, h: 1200 }, MIN, BIG, CHROME), { w: 716, h: 1040 },
     'preteka len vyska — sirka ostava');
  eq(nxFitTarget({ w: 1904, h: 1000 }, MIN, BIG, CHROME), null,
     'okno presne na plochu sa uz nedorovnava (ziadny zbytocny set_size)');
  eq(nxFitTarget({ w: 1905, h: 1001 }, MIN, BIG, CHROME), null,
     'presah v ramci tolerancie sa neriesi (ziadne skakanie okna)');

  // Plocha mensia nez minimum okna: minimum sa NEvynuti — plocha vyhrava.
  const tiny = { w: 500, h: 400 };
  eq(nxFitTarget({ w: 600, h: 500 }, MIN, tiny, CHROME), { w: 500, h: 400 },
     'okno vacsie nez plocha a mensie nez minimum: plocha ma prednost');
  eq(nxFitTarget({ w: 200, h: 150 }, MIN, tiny, CHROME), { w: 500, h: 400 },
     'male okno na malej ploche rastie len po plochu, nie po minimum');

  // Kombinacia: sirka pod minimom, vyska nad plochou — opravia sa OBE.
  eq(nxFitTarget({ w: 300, h: 1500 }, MIN, BIG, CHROME), { w: 656, h: 1040 },
     'sirka sa zvacsi po minimum a vyska zmensi po plochu naraz');

  // Bez znamej plochy sa okno NIKDY nezmensuje (nehadame velkost obrazovky).
  eq(nxFitTarget({ w: 2000, h: 1200 }, MIN, null, CHROME), null,
     'neznama plocha: velke okno sa nechava tak');
  eq(nxFitTarget({ w: 2000, h: 1200 }, MIN, { w: 0, h: 0 }, CHROME), null,
     'plocha 0 sa neberie ako maly monitor');
})();

// --- bezny pripad ostava nezmeneny -------------------------------------------
eq(nxFitTarget({ w: 700, h: 600 }, MIN, BIG, CHROME), null,
   'okno medzi minimom a plochou sa nedotyka nikto');
eq(nxFitTarget({ w: 1200, h: 900 }, MIN, BIG, CHROME), null,
   'vedome zvacsene okno pod plochou ostava');

// --- degenerovane vstupy: radsej nerobit nic ---------------------------------
eq(nxFitTarget(null, MIN, BIG, CHROME), null, 'bez merania sa nic nemeni');
eq(nxFitTarget({ w: 0, h: 0 }, MIN, BIG, CHROME), null, 'nulovy viewport = neznamy stav');
eq(nxFitTarget({ w: NaN, h: 400 }, MIN, BIG, CHROME), null, 'NaN viewport sa ignoruje');
eq(nxFitTarget({ w: 400, h: 300 }, null, BIG, CHROME), null, 'okno bez deklarovaneho minima sa nedorovnava');
eq(nxFitTarget({ w: 400, h: 300 }, { w: 0, h: 0 }, BIG, CHROME), null, 'nulove minimum nic nevynucuje');

// --- chybajuce udaje o ploche/ramiku: minimum plati aj tak -------------------
eq(nxFitTarget({ w: 400, h: 300 }, MIN, null, null), { w: 640, h: 540 },
   'bez znamej plochy a ramika sa ciel rovna minimu');
eq(nxFitTarget({ w: 400, h: 300 }, MIN, { w: 0, h: 0 }, CHROME), { w: 656, h: 580 },
   'neznama plocha (0) sa neberie ako maly monitor');

// --- vysledok je vzdy cele cislo (set_size berie px) -------------------------
(function(){
  const t = nxFitTarget({ w: 400.4, h: 300.6 }, { w: 640.5, h: 540.5 }, BIG, { w: 16.5, h: 39.5 });
  ok(Number.isInteger(t.w) && Number.isInteger(t.h), `cele px: ${JSON.stringify(t)}`);
})();

// --- nxFitChrome: ramik z rozdielu outer/inner, inak zaloha ------------------
eq(nxFitChrome({ outerWidth: 816, innerWidth: 800, outerHeight: 640, innerHeight: 600 }),
   { w: 16, h: 40 }, 'ramik z rozdielu outer/inner');
eq(nxFitChrome({ outerWidth: 800, innerWidth: 800, outerHeight: 600, innerHeight: 600 }),
   { w: 16, h: 40 }, 'nulovy rozdiel (CEF nevie outer) = zaloha');
eq(nxFitChrome({}), { w: 16, h: 40 }, 'chybajuce hodnoty = zaloha');
eq(nxFitChrome({ outerWidth: 5000, innerWidth: 800, outerHeight: 5000, innerHeight: 600 }),
   { w: 16, h: 40 }, 'nezmyselny rozdiel sa nepouzije');
eq(nxFitChrome(null), { w: 16, h: 40 }, 'bez okna = zaloha');

// --- stabilita: po dorovnani dalsie otvorenie uz nic nerobi ------------------
(function(){
  const target = nxFitTarget({ w: 400, h: 300 }, MIN, BIG, CHROME);
  // Po set_size(target) ma okno vonkajsi rozmer target -> viewport = target - ramik.
  const viewport = { w: target.w - CHROME.w, h: target.h - CHROME.h };
  eq(nxFitTarget(viewport, MIN, BIG, CHROME), null,
     'druhe otvorenie uz okno nedorovnava (ziadna slucka rastu)');
})();

console.log(`OK — ${n} kontrol (D-77 velkost okna pri otvoreni)`);
