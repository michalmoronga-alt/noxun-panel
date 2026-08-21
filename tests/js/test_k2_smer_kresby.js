// Testy K2 / D-87 (JS zrkadlo) — prepinac „Smer kresby" v tabe KONTROLA okna
// Vyroba (vedla „Zvyraznit hrany").
//
// JS je LEN zobrazenie: zapnutost aj pocty nesie SERVER, klient si nic
// neprepocitava a nic si nepamata. Tento subor testuje CISTE funkcie bez DOM.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

global.window = {};
global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const P = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'production.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function no(cond, msg){ n++; assert.ok(!cond, msg); }

const EDGE = { available: true, active: false,
               options: { show_missing: true, show_extra: false, show_taped: false, taped_selected_only: true },
               counts: { missing: 0, extra: 0, taped: 0 } };
function grain(extra){
  return Object.assign({ available: true, active: true, parts: 12, lines: 96, skipped: 0, unresolved: 0 }, extra || {});
}

// --- tlacidlo -----------------------------------------------------------------
(function(){
  const on = P.grainBtnHtml(grain());
  ok(on.indexOf('id="gcBtn"') >= 0, 'prepinac ma stabilne id');
  ok(on.indexOf('gcbtn on') >= 0, 'zapnuty stav je na tlacidle');
  ok(on.indexOf('aria-pressed="true"') >= 0, 'zapnutost vidi aj citacka');
  ok(on.indexOf('Smer kresby') >= 0, 'nazov tlacidla');
  ok(on.indexOf('#i-grain') >= 0, 'ikona zo spritu — TA ISTA ako v raile (rovnaky vyznam = rovnaka kresba)');
  no(on.indexOf('ecmore') >= 0, 'smer kresby NEMA rozbalovacie okno — nie je co nastavovat');

  const off = P.grainBtnHtml(grain({ active: false, parts: null }));
  ok(off.indexOf('aria-pressed="false"') >= 0, 'vypnuty stav');
  no(off.indexOf('gcbtn on') >= 0, 'vypnute tlacidlo nenesie zapnuty vzhlad');

  eq(P.grainBtnHtml({ available: false }), '', 'stary SketchUp prepinac vobec neukaze');
  eq(P.grainBtnHtml(null), '', 'chybajuci stav = ziadny prepinac');
})();

// --- text listy ---------------------------------------------------------------
(function(){
  eq(P.grainCheckText(null), '', 'bez stavu lista o smere mlci');
  eq(P.grainCheckText(grain({ active: false })), '', 'vypnuty prepinac do textu nepridava nic');

  const t = P.grainCheckText(grain());
  ok(t.indexOf('12 dielcov s kresbou') >= 0, 'pocet dielcov s kresbou');
  no(t.indexOf('bez kresby') >= 0, 'ked netreba, o preskocenych sa nehovori');

  const skipped = P.grainCheckText(grain({ parts: 4, skipped: 7 }));
  ok(skipped.indexOf('4 dielce s kresbou') >= 0, 'sklonovanie 2-4');
  ok(skipped.indexOf('7 bez kresby (materiál bez smeru)') >= 0, 'UNI dielce sa priznaju');

  const un = P.grainCheckText(grain({ parts: 1, unresolved: 2 }));
  ok(un.indexOf('1 dielec s kresbou') >= 0, 'sklonovanie 1');
  ok(un.indexOf('2 sa nedá nakresliť') >= 0, 'neoveritelne osi sa priznaju (nemlci sa)');
})();

// --- sklonovanie --------------------------------------------------------------
(function(){
  eq(P.grainPartPluralSk(1), 'dielec', '1');
  eq(P.grainPartPluralSk(2), 'dielce', '2');
  eq(P.grainPartPluralSk(4), 'dielce', '4');
  eq(P.grainPartPluralSk(5), 'dielcov', '5');
  eq(P.grainPartPluralSk(0), 'dielcov', '0');
})();

// --- lista: dva nastroje, JEDEN riadok ----------------------------------------
(function(){
  const bar = P.edgeCheckBarHtml(EDGE, false, grain());
  ok(bar.indexOf('class="ecsplit"') >= 0, 'zvyraznenie hran ostava split tlacidlom');
  ok(bar.indexOf('id="gcBtn"') >= 0, 'smer kresby je v TEJ ISTEJ liste');
  eq(bar.split('class="ecbar"').length - 1, 1, 'stale JEDEN riadok listy (vertikalny priestor)');
  ok(bar.indexOf('12 dielcov s kresbou') >= 0, 'text smeru je pripojeny k textu listy');

  const without = P.edgeCheckBarHtml(EDGE, false);
  no(without.indexOf('id="gcBtn"') >= 0, 'bez stavu smeru sa prepinac nekresli');
  ok(without.indexOf('class="ecsplit"') >= 0, 'a zvyraznenie hran tym netrpi');

  const na = P.edgeCheckBarHtml({ available: false }, false, grain());
  ok(na.indexOf('SketchUp 2023') >= 0, 'stary SketchUp dostane vetu za oba nastroje');
  no(na.indexOf('id="gcBtn"') >= 0, 'a ziadne mrtve tlacidlo');
})();

// --- relay do Ruby ------------------------------------------------------------
(function(){
  const p = P.edgeCheckPayload({ gen: 7, model_guid: 'G1' });
  eq(p, { gen: 7, model_guid: 'G1' }, 'smer kresby posiela TU ISTU identitu ako zvyraznenie hran');
})();

// --- prepinac v raile Inspectora (v0.7.27) ------------------------------------
// Rail dostava PRESNE ten isty serverovy stav ako okno Vyroba (jeden zdroj
// stavu, dva vstupne body). `NXShell.grainRail` je cista funkcia — z toho stavu
// spravi prisvietenie a text bubliny; nic si neprepocitava ani nepamata.
(function(){
  const NXShell = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'shell.js'));

  const on = NXShell.grainRail(grain());
  eq(on.on, true, 'zapnuty stav prisvieti ikonu raily');
  eq(on.available, true, 'dostupnost je zo servera');
  ok(on.tip.indexOf('ZAPNUTÁ') >= 0, 'bublina povie, ze je kontrola zapnuta');
  ok(on.tip.indexOf('12 dielcov s kresbou') >= 0, 'a nesie ZIVE cislo zo servera');

  const off = NXShell.grainRail(grain({ active: false, parts: null }));
  eq(off.on, false, 'vypnuty stav nesvieti');
  eq(off.tip, 'Kontrola smeru kresby (zapnúť/vypnúť)', 'vypnuta bublina je pokyn, nie stav');

  const skipped = NXShell.grainRail(grain({ parts: 4, skipped: 7 }));
  ok(skipped.tip.indexOf('4 dielce s kresbou') >= 0, 'sklonovanie 2-4 je zhodne s oknom Vyroba');
  ok(skipped.tip.indexOf('7 bez kresby') >= 0, 'preskocene dielce sa priznaju aj v raile');

  // Stary SketchUp: tlacidlo NIE JE ticho mrtve — povie preco (vzor D-78).
  const na = NXShell.grainRail({ available: false, active: true });
  eq(na.available, false, 'bez Overlay API je prepinac neaktivny');
  eq(na.on, false, 'nedostupna kontrola NIKDY nesvieti ako zapnuta');
  ok(na.tip.indexOf('SketchUp 2023') >= 0, 'bublina povie dovod');

  // Chybajuci stav = zhasnuty prepinac (radsej nic nez nahodne „zapnute").
  eq(NXShell.grainRail(null).on, false, 'bez stavu prepinac nesvieti');
  eq(NXShell.grainRail(null).available, true, 'a ostava klikatelny (server odpovie sam)');

  // Sklonovanie je ZRKADLO Ruby `grain_part_plural` aj JS okna Vyroba.
  [1, 2, 4, 5, 0].forEach(function(v){
    eq(NXShell.grainPartWord(v), P.grainPartPluralSk(v), 'sklonovanie ' + v + ' sedi s oknom Vyroba');
  });
})();

console.log(`test_k2_smer_kresby.js OK (${n} kontrol)`);
