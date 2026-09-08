// KOV-F2 — EDITOR door guardov pravidla `bands` v sekcii Pravidlá (rules.js,
// mini-DOM). F1 vedela guardy len PRIZNAŤ jednou vetou; F2 z nich robí formulár.
//
// Prečo mini-DOM a nie stub: zber hodnôt (`rdCollectRules` -> `rdCollectGuards`)
// číta SKUTOČNÝ DOM, takže „prázdne pole = guard preč" ani „pridanie pásma
// nezhodí rozpísané hodnoty" sa stubom overiť nedá — a práve to sú dve veci,
// ktoré sa rozbijú TICHO (uloží sa pravidlo bez kontroly, ktorú tam používateľ
// napísal).
//
// Čo sa stráži:
//   R1 blok sa kreslí LEN tam, kam patrí: `bands` + výstup `hinge`, alebo
//      hociktoré `bands`, ktoré už guard nesie. Iné pravidlo vyzerá ako doteraz.
//   R2 zbalený blok POVIE, čo skrýva (súhrn v lište) — vertikálny priestor
//      panela je vzácny, takže blok je `<details>` a zavretý.
//   R3 zber píše kľúče presne v tvare F1 (`width_plus {over, add}`,
//      `width_warn_over`, `weight_bands [{max, quantity}]`, `finite`).
//   R4 prázdne pole guard ZMAŽE (jediný spôsob, ako kontrolu vypnúť) a
//      pravidlo bez editora sa nedotkne.
//   R5 klient CLAMPUJE (chýbajúci počet = 1, nekladná hranica = vypnuté),
//      takže neposiela tvar, ktorý by server ticho zahodil.
//   R6 prázdne KILOGRAMY sú výnimka: riadok, ktorý používateľ vedome pridal,
//      sa nezahadzuje — uloženie sa odmietne vetou (zrkadlo servera).
//   R7 pridanie/odobranie hmotnostného pásma prežije rozpísaný formulár a
//      posledné zmazané pásmo kľúč odstráni.
//   R8 otvorený blok prežije prekreslenie (inak by ho každé „+ pásmo" zavrelo).
//   R9 kľúč v NESPRÁVNOM tvare (hash/reťazec/číslo z cudzieho snapshotu)
//      sekciu NEZHODÍ — vykreslí sa ako prázdna tabuľka s hintom a uložením
//      sa opraví (Codex #330 kolo 1).
//
// MUTÁCIE (každá overená ručne — po zanesení chyby do rules.js spadne test):
//   M1 `rdHasGuardEditor` vracia true pre každé `bands` -> R1
//   M2 zber zapisuje `width_plus` aj pri prázdnom poli   -> R4
//   M3 chýbajúci počet ide na server ako NaN/null        -> R5
//   M4 prázdne kilogramy sa ticho zahodia                -> R6
//   M5 `rdAddWeight` nevolá `rdSyncFromForm`             -> R7
//   M6 stav otvorenia sa drží podľa indexu pravidla      -> R8
//   M7 `rdGuardHtml` kreslí pásma bez `rdArr`            -> R9
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const md = require(path.join(__dirname, 'minidom.js'));
const { mkEl, DOC } = md;

['rulesBox', 'rdSrcLine', 'status', 'secbody', 'sectools'].forEach(function(id){
  const el = mkEl('div');
  el.attrs.id = id;
  DOC.body.appendChild(el);
});

const SENT = [];
const BRIDGE = { save_rules: function(json){ SENT.push(JSON.parse(json)); } };
global.window.sketchup = BRIDGE;
global.sketchup = BRIDGE;

// `rules.js` sa v prehliadači načítava AŽ ZA `studio.js` a siaha na HOLÝ global
// `NX` (v okne je `window.NX` a `NX` tá istá vec, v Node nie).
require(path.join(JS, 'studio.js'));
if (global.window.NX && typeof global.NX === 'undefined') global.NX = global.window.NX;
const R = require(path.join(JS, 'rules.js'));

const BOX = DOC.getElementById('rulesBox');

// Pravidlo závesov v tvare, aký posiela server po KOV-F1.
function hingeRule(over){
  return Object.assign({
    rule_id: 'zavesy-podla-vysky', kind: 'bands', output: 'hinge', enabled: true,
    input: 'height', applies_to: { role: 'front_door' },
    bands: [{ max: 849, quantity: 2 }, { max: null, quantity: 7 }],
    finite: true, width_plus: { over: 600, add: 1 }, width_warn_over: 800,
    weight_bands: [{ max: 7.7, quantity: 2 }, { max: 22, quantity: 5 }]
  }, over || {});
}

function show(rules){
  R.RD.init({ version: '0.9.51', source: 'project', cabinets: 1, model_guid: 'G1',
              rules_rev: 'rev1', rules: rules,
              abs: { rows: [], source: '', hint: '' },
              overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } });
}

function guardBox(){ return DOC.querySelector('details.rgrd'); }
function field(cls){ return DOC.querySelector('.rgbody ' + cls); }
function rule(){ return R.rdCollectRules()[0]; }

// ---- R1: blok sa kreslí LEN tam, kam patrí ---------------------------------
(function(){
  show([hingeRule()]);
  ok(guardBox() !== null, 'R1: pravidlo závesov (bands + hinge) má editor kontrol');

  show([{ rule_id: 'nohy', kind: 'fixed', output: 'leg', enabled: true, quantity: 4,
          applies_to: { role: 'cabinet' } }]);
  ok(guardBox() === null, 'R1: `fixed` pravidlo editor nemá');

  show([{ rule_id: 'vysuvy', kind: 'fit_series', output: 'slide', enabled: true,
          series: [400], clearance: 10, quantity: 1, applies_to: { role: 'drawer_front' } }]);
  ok(guardBox() === null, 'R1: `fit_series` tiež nie (guardy nikdy nepočíta)');

  show([{ rule_id: 'uchytky-pasma', kind: 'bands', output: 'handle', enabled: true,
          bands: [{ max: null, quantity: 1 }], applies_to: { role: 'front_door' } }]);
  ok(guardBox() === null, 'R1: `bands` s iným výstupom a BEZ guardu vyzerá ako doteraz');

  show([{ rule_id: 'uchytky-pasma', kind: 'bands', output: 'handle', enabled: true,
          bands: [{ max: null, quantity: 1 }], width_warn_over: 700,
          applies_to: { role: 'front_door' } }]);
  ok(guardBox() !== null,
     'R1: ale keď guard UŽ NESIE, editor je — inak sa hodnota z cudzieho snapshotu nedá opraviť');
  eq(R.rdHasGuardEditor({ kind: 'bands', output: 'hinge' }), true, 'R1: čistá funkcia to hovorí rovnako');
  eq(R.rdHasGuardEditor({ kind: 'bands', output: 'handle' }), false, 'R1: aj v opačnom smere');
})();

// ---- R2: zbalený blok povie, čo skrýva -------------------------------------
(function(){
  show([hingeRule()]);
  const det = guardBox();
  ok(!det.hasAttribute('open'), 'R2: blok je ZBALENÝ — vertikálny priestor panela je vzácny');
  const sum = md.textOf(DOC.querySelector('.rgsum'));
  eq(sum, '+1 nad 600 mm · varovanie nad 800 mm · 2 hmotnostné pásma · konečná tabuľka',
     'R2: súhrn v lište vymenuje VŠETKY zapnuté kontroly');
  eq(R.rdGuardSummary({ kind: 'bands' }), 'zatiaľ nič', 'R2: prázdny stav sa prizná');
  eq(R.rdGuardSummary({ weight_bands: [{ max: 7.7, quantity: 2 }] }), '1 hmotnostné pásmo',
     'R2: slovenské tvary počtu (1 pásmo)');
  eq(R.rdGuardSummary({ weight_bands: [1, 2, 3, 4, 5].map(function(i){ return { max: i, quantity: 1 }; }) }),
     '5 hmotnostných pásiem', 'R2: …aj pri piatich');
  const html = BOX.innerHTML;
  ok(html.indexOf('style="') < 0, 'R2: žiadne natvrdo písané farby ani štýly (tokeny žijú v CSS)');
  ok(html.indexOf('Kontroly dvierok') > -1, 'R2: blok je pomenovaný rečou používateľa');
})();

// ---- R3 + R4: zber hodnôt a mazanie guardov --------------------------------
(function(){
  show([hingeRule()]);
  eq(rule().width_plus, { over: 600, add: 1 }, 'R3: nedotknutý formulár vráti pôvodný tvar');

  field('.rgover').value = '700';
  field('.rgadd').value = '2';
  field('.rgwarn').value = '900';
  DOC.querySelectorAll('.rgwb .wmax')[1].value = '25';
  DOC.querySelectorAll('.rgwb .wqty')[1].value = '6';
  const r = rule();
  eq(r.width_plus, { over: 700, add: 2 }, 'R3: šírka pre +N ide v tvare {over, add}');
  eq(r.width_warn_over, 900, 'R3: hranica varovania je číslo');
  eq(r.weight_bands, [{ max: 7.7, quantity: 2 }, { max: 25, quantity: 6 }],
     'R3: hmotnostné pásma sú [{max, quantity}]');
  eq(r.finite, true, 'R3: prepínač konečnej tabuľky');
  eq(r.bands, [{ max: 849, quantity: 2 }, { max: null, quantity: 7 }],
     'R3: tabuľka výšok sa nezmenila');

  field('.rgover').value = '';
  field('.rgwarn').value = '';
  field('.rgfin').checked = false;
  const off = rule();
  ok(!('width_plus' in off), 'R4: prázdna šírka = kľúč sa NEZAPÍŠE (kontrola vypnutá)');
  ok(!('width_warn_over' in off), 'R4: aj prázdna hranica varovania');
  ok(!('finite' in off), 'R4: odškrtnutý prepínač kľúč odstráni (nezapisuje sa `false`)');
  ok(Array.isArray(off.weight_bands), 'R4: ostatné guardy to nezhodí');
})();

// ---- R4b: pravidlo BEZ editora si guardy PONECHÁ ----------------------------
(function(){
  // Cudzí/legacy snapshot môže niesť guard aj pri `fit_series`. Editor sa naň
  // nekreslí (pravidlo ich nikdy nepočíta), takže sa ich zber nesmie dotknúť —
  // uloženie by ich inak potichu zmazalo.
  show([{ rule_id: 'vysuvy', kind: 'fit_series', output: 'slide', enabled: true,
          series: [400], clearance: 10, quantity: 1, weight_bands: [{ max: 7.7, quantity: 2 }],
          applies_to: { role: 'drawer_front' } }]);
  ok(guardBox() === null, 'R4b: editor sa nekreslí');
  eq(rule().weight_bands, [{ max: 7.7, quantity: 2 }], 'R4b: a guard uloženie prežije nedotknutý');
})();

// ---- R5: klient clampuje — neposiela tvar, ktorý by server zahodil ----------
(function(){
  show([hingeRule()]);
  field('.rgover').value = '700';
  field('.rgadd').value = '';
  eq(rule().width_plus, { over: 700, add: 1 },
     'R5: chýbajúci počet kusov = 1 (rovnaký clamp ako pri výškových pásmach)');

  field('.rgover').value = '0';
  ok(!('width_plus' in rule()), 'R5: nekladná šírka je VYPNUTÁ kontrola, nie neplatný guard');
  field('.rgover').value = '-5';
  ok(!('width_plus' in rule()), 'R5: aj záporná');
  field('.rgwarn').value = '0';
  ok(!('width_warn_over' in rule()), 'R5: a rovnako hranica varovania');

  field('.rgover').value = '600';
  field('.rgadd').value = '600';
  DOC.querySelectorAll('.rgwb .wqty')[0].value = '';
  eq(rule().weight_bands[0].quantity, 1, 'R5: aj počet v hmotnostnom pásme');
})();

// ---- R6: prázdne kilogramy sa NEZAHADZUJÚ, uloženie ich odmietne -----------
(function(){
  show([hingeRule()]);
  DOC.querySelectorAll('.rgwb .wmax')[0].value = '';
  const r = rule();
  eq(r.weight_bands[0].max, null,
     'R6: riadok, ktorý používateľ vedome pridal, ide na server aj bez kilogramov');
  const msg = R.rdValidate([r]);
  ok(/potrebuje kilogramy/.test(msg) && /Závesy/.test(msg),
     'R6: klient povie, ČO chýba a KTORÉHO pravidla sa to týka: ' + msg);

  SENT.length = 0;
  R.rdSaveRules();
  eq(SENT.length, 0, 'R6: a uloženie sa vôbec neodošle');
  ok(/kilogramy/.test(DOC.getElementById('status').textContent), 'R6: stav sekcie hovorí prečo');

  // Ostatne dve kriteria (zrkadlo servera; verdikty striezi spolocna fixtura).
  const base = hingeRule();
  ok(/prázdne/.test(R.rdValidate([Object.assign({}, base, { weight_bands: [] })])),
     'R6: prázdna tabuľka hmotností');
  ok(/rovnakú hmotnosť/.test(R.rdValidate([Object.assign({}, base, {
    weight_bands: [{ max: 7.7, quantity: 2 }, { max: 7.7, quantity: 3 }] })])),
     'R6: dve pásma s rovnakou hmotnosťou');
  eq(R.rdValidate([Object.assign({}, base, {
    weight_bands: [{ max: 22, quantity: 5 }, { max: 7.7, quantity: 2 }] })]), null,
     'R6: opačné poradie chyba NIE JE — pásma zoradí server');
  eq(R.rdValidate([hingeRule()]), null, 'R6: platné pravidlo prejde');
})();

// ---- R7: pridanie a odobranie hmotnostného pásma ----------------------------
(function(){
  show([hingeRule()]);
  field('.rgwarn').value = '950'; // ROZPÍSANÁ hodnota, ktorá sa nesmie stratiť
  R.rdAddWeight(DOC.querySelector('.rgbody .btnrow button'));
  const added = rule();
  eq(added.weight_bands.length, 3, 'R7: pribudlo pásmo');
  eq(added.weight_bands[2], { max: 27, quantity: 6 },
     'R7: nadväzuje na najťažšie (+5 kg, o jeden záves viac)');
  eq(added.width_warn_over, 950, 'R7: a rozpísaná hodnota iného poľa prežila prekreslenie');

  // Každý klik formulár PREKRESLÍ (ako v okne), takže sa maže vždy čerstvý riadok.
  while (DOC.querySelectorAll('.rgwb .bdel').length){
    R.rdDelWeight(DOC.querySelector('.rgwb .bdel'));
  }
  ok(!('weight_bands' in rule()),
     'R7: posledné zmazané pásmo kľúč ODSTRÁNI (tabuľka nie je prázdna, jednoducho nie je)');
  eq(R.rdValidate([rule()]), null, 'R7: a taký tvar je platný — guard je voliteľný');
})();

// ---- R8: otvorený blok prežije prekreslenie ---------------------------------
(function(){
  show([hingeRule({ rule_id: 'zavesy-podla-vysky' }),
        hingeRule({ rule_id: 'zavesy-sklop', output: 'hinge' })]);
  const dets = DOC.querySelectorAll('details.rgrd');
  eq(dets.length, 2, 'R8: obe pravidlá majú svoj blok');
  eq(dets[1].getAttribute('data-rid'), 'zavesy-sklop', 'R8: kľúčom stavu je `rule_id`, nie index');
  dets[1].setAttribute('open', '');
  R.rdGuardToggle(dets[1]);
  R.RD.setRules([hingeRule({ rule_id: 'zavesy-sklop' }),
                 hingeRule({ rule_id: 'zavesy-podla-vysky' })], 'global');
  const after = DOC.querySelectorAll('details.rgrd');
  ok(after[0].hasAttribute('open'), 'R8: otvorený ostal otvorený, aj keď sa pravidlá preskupili');
  ok(!after[1].hasAttribute('open'), 'R8: a zavretý zavretý');
})();

// ---- R9: kľúč v NESPRÁVNOM tvare sekciu NEZHODÍ ----------------------------
(function(){
  // Codex #330 kolo 1 (P2). Cudzí alebo pokazený snapshot môže niesť
  // `weight_bands` ako hash, reťazec či číslo — serverová `normalize_rules`
  // čistí LEN polia, takže taký tvar dojde až sem. Sekcia sa kreslí JEDNÝM
  // `innerHTML`, takže bezpodmienečný `.forEach` by zhodil CELÚ sekciu
  // Pravidlá — teda aj jediné miesto, kde sa tá hodnota dá opraviť.
  [{}, { max: 7.7, quantity: 2 }, 'sedem', 7, true].forEach(function(bad){
    show([hingeRule({ weight_bands: bad })]);
    ok(guardBox() !== null, 'R9: sekcia sa vykreslí aj pri tvare ' + JSON.stringify(bad));
    eq(DOC.querySelectorAll('.rgwb').length, 0, 'R9: a tabuľka je PRÁZDNA, nie pokazená');
  });

  show([hingeRule({ weight_bands: { max: 7.7, quantity: 2 } })]);
  const hint = md.textOf(DOC.querySelector('.rgbad'));
  ok(/nesprávnom tvare/.test(hint), 'R9: hint sa prizná, čo je s uloženými dátami: ' + hint);
  ok(md.textOf(DOC.querySelector('.rgsum')).indexOf('neplatný tvar') > -1,
     'R9: aj ZBALENÁ lišta to povie — blok je zavretý a inak by to nebolo vidieť');
  ok(!('weight_bands' in rule()),
     'R9: a ULOŽENIE pokazený kľúč z pravidla odstráni (formulár je autorita)');
  eq(R.rdValidate([rule()]), null, 'R9: taký zápis je platný — guard je voliteľný');

  eq(R.rdWeightBroken({ weight_bands: [] }), false, 'R9: prázdne POLE pokazený tvar NIE JE');
  eq(R.rdWeightBroken({}), false, 'R9: ani chýbajúci kľúč');
  eq(R.rdGuardSummary({ kind: 'bands', weight_bands: 'abc' }), 'hmotnostné pásma: neplatný tvar',
     'R9: reťazec má `.length` — súhrn by inak hlásil pásma, ktoré neexistujú');

  // Tá istá pasca je nad tabuľkou výšok a nad radom dĺžok — jedna brána (`rdArr`).
  show([{ rule_id: 'zavesy-hash', kind: 'bands', output: 'hinge', enabled: true,
          bands: { max: 900, quantity: 2 }, applies_to: { role: 'front_door' } }]);
  ok(guardBox() !== null, 'R9: `bands` v nesprávnom tvare sekciu tiež nezhodí');
  ok(/aspoň pásmo/.test(R.rdValidate(R.rdCollectRules())),
     'R9: a uloženie takého pravidla sa odmietne vetou');
  show([{ rule_id: 'vysuvy', kind: 'fit_series', output: 'slide', enabled: true,
          series: { a: 1 }, clearance: 10, quantity: 1, applies_to: { role: 'drawer_front' } }]);
  eq(DOC.querySelector('.rseries').value, '', 'R9: a rovnako rad dĺžok — pole ostane prázdne');
})();

// ---- escapovanie identity v atribúte ---------------------------------------
(function(){
  show([hingeRule({ rule_id: 'zle"id' })]);
  const det = guardBox();
  ok(det !== null, 'úvodzovka v `rule_id` blok nerozbije');
  eq(det.getAttribute('data-rid'), 'zle"id', 'a identita sa prenesie správne (escapovaná)');
})();

console.log('KOV-F2 editor door guardov: ' + n + ' assertov OK');
