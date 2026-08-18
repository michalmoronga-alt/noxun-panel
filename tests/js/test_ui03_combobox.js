// Testy UI-03 / D-85: zdielany combobox materialov a ABS — ciste funkcie
// noxun_engine/ui/js/nx_combo.js. Dependency-free Node:
//   node tests/js/test_ui03_combobox.js
//
// Kontext: combobox NENAHRADZA <select>, len ho obaluje — moznosti cita z jeho
// <option>/<optgroup> a vyber posiela spat cez `value` + `change`. Tu sa testuje
// mozog komponentu (normalizacia, sekcie, filter, klavesnica, recents) plus
// REGRESIA kontraktu, vdaka ktoremu prezili guardy E-03 a D-86.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const NXC = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'nx_combo.js'));
const BOARD = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'board_card.js'));
const fs = require('node:fs');

const { nxNormText, nxComboSections, nxComboHighlight, nxComboStep, nxComboFirst,
        nxComboFlatten, nxRecentPush, nxComboIsFixed, nxComboHit } = NXC;

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// Polozky v tvare, v akom ich komponent cita zo <select>u.
function it(value, label, group, disabled){
  return { value: value, label: label, group: group || '', disabled: !!disabled };
}
const DECORS = [
  it('', '(dediť z projektu)'),
  it('K2738_MO_DTDL_18', 'K2738 MO Cremona Oak · DTDL 18 mm'),
  it('U636_ST9_DTDL_18', 'U636 ST9 Pastelová modrá · DTDL 18 mm'),
  it('W1000_ST9_DTDL_18', 'W1000 ST9 Premium biela · DTDL 18 mm'),
  it('HDF_WHITE_3', 'HDF Biela · HDF 3 mm'),
  it('K350_SN_DTDL_36', 'K350 SN Antracit · DTDL 36 mm', '', true) // nekompatibilna hrubka
];
const ABS = [
  it('__inherit__', '(podľa pravidla — 500 SM Biela 23/1 mm)'),
  it('', 'Bez ABS'),
  it('ABS_K2738_23_10', 'ABS K2738 · 23/1,0 mm', 'Odporúčané k dekoru'),
  it('ABS_K2738_23_20', 'ABS K2738 · 23/2,0 mm', 'Odporúčané k dekoru'),
  it('ABS_U636_23_10', 'ABS U636 · 23/1,0 mm', 'Ostatné'),
  it('ABS_W1000_23_10', 'ABS W1000 · 23/1,0 mm', 'Ostatné')
];

// --- normalizacia bez diakritiky (jadro D-85 aj odlozenej D-16) ---------------
// Michalov realny scenar: napise "cremona" alebo "modra" a nechce riesit dlzne.
(function(){
  eq(nxNormText('Cremona Oak'), 'cremona oak', 'lowercase');
  eq(nxNormText('Pastelová modrá'), 'pastelova modra', 'dlzne von');
  eq(nxNormText('Čierna ŽLTÁ ťava ňu'), 'cierna zlta tava nu', 'makcene aj dlzne von');
  eq(nxNormText(null), '', 'null je prazdny retazec');
  eq(nxNormText(12), '12', 'cislo sa neprepadne');
  ok(nxNormText('modrá').length === nxNormText('modra').length,
     'normalizacia diakritiku len ODOBERA — dlzka sa zachova (na tom stoji zvyraznenie)');
})();

// --- filter -------------------------------------------------------------------
(function(){
  const cremona = DECORS[1], modra = DECORS[2];
  eq(nxComboHit(cremona, 'cremona'), true, 'zhoda bez ohladu na velkost pismen');
  eq(nxComboHit(modra, 'modra'), true, 'zhoda bez diakritiky');
  eq(nxComboHit(modra, 'modrá'), true, 'zhoda AJ s diakritikou (pise sa oboma sposobmi)');
  eq(nxComboHit(cremona, 'k2738'), true, 'hlada sa aj v id (nesie kod dekoru)');
  eq(nxComboHit(cremona, 'dtdl'), true, 'substring v strede labelu');
  eq(nxComboHit(cremona, 'xyz'), false, 'nezhoda');
  eq(nxComboHit(cremona, ''), true, 'prazdny dotaz berie vsetko');
})();

// --- zvyraznenie zhody (segmenty, nie HTML — escapovanie robi renderer) -------
(function(){
  eq(nxComboHighlight('Cremona Oak', 'crem'),
     [{ text: 'Crem', hit: true }, { text: 'ona Oak', hit: false }],
     'zhoda na zaciatku');
  eq(nxComboHighlight('Pastelová modrá', 'modra'),
     [{ text: 'Pastelová ', hit: false }, { text: 'modrá', hit: true }],
     'zvyraznuje sa POVODNY text s diakritikou, hoci sa hladalo bez nej');
  eq(nxComboHighlight('Cremona Oak', ''), [{ text: 'Cremona Oak', hit: false }],
     'bez dotazu ziadne zvyraznenie');
  eq(nxComboHighlight('Cremona Oak', 'zzz'), [{ text: 'Cremona Oak', hit: false }],
     'bez zhody ziadne zvyraznenie');
  eq(nxComboHighlight(null, 'a'), [{ text: '', hit: false }], 'null neprepadne');
})();

// --- fixne volby --------------------------------------------------------------
// '(dediť z projektu)' / '(podľa pravidla — …)' / 'Bez ABS' nie su katalogove id.
(function(){
  eq(nxComboIsFixed(''), true, 'prazdna hodnota = fixna volba');
  eq(nxComboIsFixed('__inherit__'), true, 'dedenie/pravidlo = fixna volba');
  eq(nxComboIsFixed('ABS_K2738_23_10'), false, 'katalogove id fixne nie je');
  eq(nxComboIsFixed(null), true, 'chybajuca hodnota sa berie ako prazdna');
})();

// --- poradie sekcii (kontrakt UI 2.0, mockup C) --------------------------------
(function(){
  const secs = nxComboSections(DECORS, '', 'decor',
    ['U636_ST9_DTDL_18', 'HDF_WHITE_3'],           // pouzite v projekte (zo servera)
    ['W1000_ST9_DTDL_18']);                        // naposledy pouzite (localStorage)
  eq(secs.map(s => s.title),
     [null, 'Použité v projekte', 'Naposledy použité', 'Katalóg dekorov (2)'],
     'poradie: fixne -> projekt -> naposledy -> katalog');
  eq(secs[0].items.map(x => x.value), [''], 'fixna volba stoji navrchu bez hlavicky');
  eq(secs[1].items.map(x => x.value), ['U636_ST9_DTDL_18', 'HDF_WHITE_3'],
     'projektove polozky v poradi katalogu');
  eq(secs[2].items.map(x => x.value), ['W1000_ST9_DTDL_18'], 'naposledy pouzite');
  eq(secs[3].items.map(x => x.value), ['K2738_MO_DTDL_18', 'K350_SN_DTDL_36'],
     'zvysok katalogu — polozka sa NIKDY neopakuje v dvoch sekciach');
})();

(function(){
  // Prienik: id je zaroven v projekte aj v recents -> patri do PROJEKTU (vyssia sekcia).
  const secs = nxComboSections(DECORS, '', 'decor',
    ['K2738_MO_DTDL_18'], ['K2738_MO_DTDL_18', 'HDF_WHITE_3']);
  eq(secs.map(s => s.title), [null, 'Použité v projekte', 'Naposledy použité', 'Katalóg dekorov (3)'],
     'obe sekcie existuju');
  eq(secs[1].items.map(x => x.value), ['K2738_MO_DTDL_18'], 'prienik ide do projektu');
  eq(secs[2].items.map(x => x.value), ['HDF_WHITE_3'], 'v recents ostane len zvysok');
})();

(function(){
  // Naposledy pouzite drzia poradie POUZITIA (najnovsie hore), nie poradie katalogu.
  const secs = nxComboSections(DECORS, '', 'decor', [],
    ['HDF_WHITE_3', 'K2738_MO_DTDL_18']);
  eq(secs[1].items.map(x => x.value), ['HDF_WHITE_3', 'K2738_MO_DTDL_18'],
     'najnovsie pouzity dekor je prvy, aj ked je v katalogu nizsie');
})();

(function(){
  // Prazdne sekcie sa nezobrazuju vobec (ziadne prazdne hlavicky).
  const secs = nxComboSections(DECORS, '', 'decor', [], []);
  eq(secs.map(s => s.title), [null, 'Katalóg dekorov (5)'], 'bez projektu a bez recents');
})();

// --- ABS: clenenie <optgroup> sa NESMIE stratit (D-36) ------------------------
(function(){
  const secs = nxComboSections(ABS, '', 'abs', [], []);
  eq(secs.map(s => s.title), [null, 'Odporúčané k dekoru', 'Ostatné'],
     'ABS sekcie kopiruju optgroupy z <select>u');
  eq(secs[0].items.map(x => x.value), ['__inherit__', ''],
     '„podľa pravidla" aj „Bez ABS" stoja navrchu');
  // ...a ked polozku vytiahne "Použité v projekte", meno skupiny ide s nou (podtitul).
  const used = nxComboSections(ABS, '', 'abs', ['ABS_K2738_23_20'], []);
  eq(used[1].title, 'Použité v projekte', 'projektova sekcia je nad skupinami');
  eq(used[1].items[0].group, 'Odporúčané k dekoru',
     'polozka si nesie svoju skupinu — clenenie D-36 sa v ponuke nestrati');
})();

// --- filter cez sekcie ---------------------------------------------------------
(function(){
  const secs = nxComboSections(DECORS, 'modra', 'decor', ['U636_ST9_DTDL_18'], []);
  eq(secs.map(s => s.title), ['Použité v projekte'], 'prazdne sekcie po filtri zmiznu');
  eq(secs[0].items.map(x => x.value), ['U636_ST9_DTDL_18'], 'jedina zhoda');
  eq(nxComboSections(DECORS, 'nic-take', 'decor', [], []), [], 'ziadna zhoda = ziadne sekcie');
  // Fixna volba je tiez filtrovatelna (inak by "Bez ABS" viselo pri kazdom dotaze).
  const abs = nxComboSections(ABS, 'k2738', 'abs', [], []);
  eq(abs.map(s => s.title), ['Odporúčané k dekoru'], 'fixne volby dotaz nesplnili a odisli');
})();

// --- klavesnica (ciste jadro sipiek) ------------------------------------------
(function(){
  const flat = nxComboFlatten(nxComboSections(DECORS, '', 'decor', [], []));
  eq(flat.map(x => x.value),
     ['', 'K2738_MO_DTDL_18', 'U636_ST9_DTDL_18', 'W1000_ST9_DTDL_18', 'HDF_WHITE_3', 'K350_SN_DTDL_36'],
     'plochy zoznam kopiruje poradie sekcii');
  eq(nxComboFirst(flat), 0, 'prvy vyberatelny index');
  eq(nxComboStep(flat, 0, 1), 1, 'sipka dole');
  eq(nxComboStep(flat, 1, -1), 0, 'sipka hore');
  eq(nxComboStep(flat, 0, -1), 0, 'na zaciatku sa NEZACYKLI (ostava stat)');
  eq(nxComboStep(flat, 4, 1), 4, 'posledna polozka je disabled -> kurzor ostane stat');
  eq(nxComboStep([], 0, 1), -1, 'prazdny zoznam');
  // disabled ("(nekompatibilné)") sa preskakuje — je to volba, ktoru by server odmietol
  const withGap = [it('a', 'A'), it('b', 'B', '', true), it('c', 'C')];
  eq(nxComboStep(withGap, 0, 1), 2, 'sipka preskoci disabled polozku');
  eq(nxComboFirst([it('x', 'X', '', true), it('y', 'Y')]), 1, 'prvy VYBERATELNY, nie prvy v zozname');
  eq(nxComboFirst([it('x', 'X', '', true)]), -1, 'same disabled = ziadny kurzor');
})();

// --- naposledy pouzite: max 5, dedup, bez fixnych volieb -----------------------
(function(){
  eq(nxRecentPush([], 'A', 5), ['A'], 'prve pouzitie');
  eq(nxRecentPush(['A'], 'B', 5), ['B', 'A'], 'najnovsie hore');
  eq(nxRecentPush(['A', 'B', 'C'], 'B', 5), ['B', 'A', 'C'], 'dedup — polozka sa presunie, nezdvoji');
  eq(nxRecentPush(['A', 'B', 'C', 'D', 'E'], 'F', 5), ['F', 'A', 'B', 'C', 'D'],
     'max 5 — najstarsie vypadne');
  eq(nxRecentPush(['A', 'B', 'C', 'D', 'E'], 'C', 5), ['C', 'A', 'B', 'D', 'E'],
     'dedup pri plnom zozname nic nezahodi');
  eq(nxRecentPush(['A'], '', 5), ['A'], '„Bez ABS" sa NEPAMATA (nie je to material)');
  eq(nxRecentPush(['A'], '__inherit__', 5), ['A'], '„podľa pravidla" sa NEPAMATA');
  eq(nxRecentPush(null, 'A', 5), ['A'], 'chybajuci zoznam neprepadne');
  eq(NXC.RECENT_MAX, 5, 'strop je 5 (zadanie D-85)');
})();

// --- REGRESIA: guardy E-03 a D-86 prezili cestu comboboxu ----------------------
// Combobox nemeni SPOSOB, akym sa hodnota dostane do panela: zapise `select.value`
// a vystreli `change` — teda presne to, co robil nativny klik. Guardy vkladacej
// karty preto bezia dalej nad tymi istymi cistymi funkciami. Tu sa overuje, ze
// (a) ich spravanie sa nezmenilo a (b) zdroj naozaj vola comboboxovu cestu.
(function(){
  const UNI = { id: 'UNI_DOSKA_18', thickness: 18, uni: true, grain: 'none' };
  const REAL = { id: 'REAL_19', thickness: 19, grain: 'length' };
  // E-03: rozpisany UNI draft prezije zivy refresh katalogu
  eq(BOARD.insertThicknessShouldWrite('UNI_DOSKA_18', 'UNI_DOSKA_18', UNI, false), false,
     'E-03 drzi: refresh pri nezmenenom UNI materiali draft neprepise');
  eq(BOARD.insertThicknessShouldWrite('REAL_19', 'UNI_DOSKA_18', UNI, false), true,
     'E-03 drzi: skutocna zmena materialu dosadi default');
  // D-86: vedome zvoleny smer dekoru prezije zivy refresh katalogu
  eq(BOARD.insertGrainShouldWrite('REAL_19', 'REAL_19', REAL, true, false), false,
     'D-86 drzi: nezmeneny material + vedoma volba = ziadny prepis');
  eq(BOARD.insertGrainShouldWrite('UNI_DOSKA_18', 'REAL_19', REAL, true, false), true,
     'D-86 drzi: novy material prinesie svoju predvolbu');
  // ...a marker sa pri fokusom potlacenom zapise stale drzi (Codex #163 P2)
  eq(BOARD.insertMatMarkAdvances('REAL_19', 'UNI_DOSKA_18', true), false,
     'marker sa drzi — zmena materialu sa nezahadzuje');
})();

// Zdrojovy kontrakt: guardy ostali na `change` ceste a vkladaci select ju pouziva.
(function(){
  const src = f => fs.readFileSync(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', f), 'utf8');
  const combo = src(path.join('js', 'nx_combo.js'));
  ok(/sel\.dispatchEvent\(new Event\('change'/.test(combo),
     'vyber MUSI ist cez `change` na povodnom <select>e — inak by guardy nikto nezavolal');
  ok(combo.indexOf('sel.value = it.value') >= 0,
     'hodnota sa zapisuje do povodneho <select>u (zdroj pravdy sa nemeni)');

  const board = src(path.join('js', 'board_card.js'));
  ok(/if \(nxFieldBusy\(ms\)\) return;/.test(board),
     'refreshInsertBoardMaterials respektuje aj OTVORENY combobox, nielen fokus selectu');
  ok(board.indexOf("sel.setAttribute('data-nx-combo', 'abs')") >= 0,
     'hrany dosky su ABS combobox');

  const part = src(path.join('js', 'part_card.js'));
  ok(part.indexOf("sel.setAttribute('data-nx-combo', 'abs')") >= 0,
     'hrany dielca su ABS combobox');

  // Inventura: kazdy STATICKY material/ABS select panela ma marker.
  const html = src('panel.html');
  ['cab_body', 'cab_front', 'cab_back', 'pcMaterial', 'bc_material', 'ib_material'].forEach(function(id){
    const re = new RegExp('<select id="' + id + '"[^>]*data-nx-combo=');
    ok(re.test(html), `select #${id} ma data-nx-combo (bez neho by ostal starou rozbalovackou)`);
  });
  // Selecty, ktore comboboxom BYT NESMU (nie su to materialy ani ABS).
  ['ib_grain', 'bc_grain', 'template'].forEach(function(id){
    const re = new RegExp('<select id="' + id + '"[^>]*data-nx-combo=');
    ok(!re.test(html), `select #${id} NIE JE material/ABS — combobox sem nepatri`);
  });
  ok(html.indexOf('js/nx_combo.js?v=') >= 0, 'panel.html nacitava komponent');
})();

console.log(`OK test_ui03_combobox.js — ${n} kontrol`);
