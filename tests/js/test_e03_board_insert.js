// Testy E-03: vkladanie dosky s UNI materialom — ciste funkcie board_card.js
// (buildInsertBoardPayload / sheetIsUni / findSheetIn). Dependency-free Node:
//   node tests/js/test_e03_board_insert.js
// Kontext: UNI material nema hrubkovu identitu — hrubku urcuje DIELEC (M-B1),
// takze vkladacia karta ju musi vediet poslat. Pri REALNOM materiali sa
// thickness do payloadu nedostane vobec (hrubku diktuje katalog, D-45).
// Autorita je server (BoardBuilder.insert_thickness_for) — toto je UX zrkadlo.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { buildInsertBoardPayload, sheetIsUni, findSheetIn, insertThicknessShouldWrite,
        insertGrainShouldWrite, insertMatMarkAdvances, insertGrainSync } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'board_card.js'));
const { evalDim } = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'expr.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const SHEETS = [
  { id: 'UNI_DOSKA_18', label: 'Doska UNI · UNI', thickness: 18, uni: true, grain: 'none' },
  { id: 'REAL_19', label: 'R 19 mm', thickness: 19, grain: 'length' }
];
const UNI = SHEETS[0], REAL = SHEETS[1];

// --- sheetIsUni: prisne true, ziadne truthy stringy ---------------------------
eq(sheetIsUni(UNI), true, 'UNI zaznam');
eq(sheetIsUni(REAL), false, 'realny zaznam');
eq(sheetIsUni(null), false, 'ziadny material');
eq(sheetIsUni({ uni: 'true' }), false, 'string nie je priznak (zrkadlo Materials.uni?)');

// --- findSheetIn --------------------------------------------------------------
eq(findSheetIn(SHEETS, 'REAL_19'), REAL, 'najde podla id');
eq(findSheetIn(SHEETS, 'NIC'), null, 'nezname id = null');
eq(findSheetIn(null, 'REAL_19'), null, 'prazdny katalog neprepadne');

// --- Codex #142 P2: rozpisany UNI draft prezije refresh katalogu --------------
// Scenar: v paneli je UNI doska, pouzivatel prepise hrubku na 12 a NEODOSLE ju.
// Medzitym v okne Materialy urobi CRUD -> NX.setMaterials -> refreshInsertBoard-
// Materials() -> onInsertBoardMaterial(). Fokus je v DRUHOM okne, takze focus
// guard nepomoze — rozhodnut musi ZMENA VYBERU materialu.
(function(){
  eq(insertThicknessShouldWrite('UNI_DOSKA_18', 'UNI_DOSKA_18', UNI, false), false,
     'refresh katalogu pri NEZMENENOM UNI materiali draft NEPREPISE');
  eq(insertThicknessShouldWrite('UNI_DOSKA_18', 'UNI_DOSKA_18', UNI, true), false,
     'pole s fokusom sa neprepisuje uz vobec');
  eq(insertThicknessShouldWrite(null, 'UNI_DOSKA_18', UNI, false), true,
     'prve naplnenie karty dosadi default roly');
  eq(insertThicknessShouldWrite('REAL_19', 'UNI_DOSKA_18', UNI, false), true,
     'prepnutie realny -> UNI dosadi default roly');
  eq(insertThicknessShouldWrite('UNI_DOSKA_18', 'REAL_19', REAL, false), true,
     'prepnutie UNI -> realny vrati katalogovu hodnotu');
  eq(insertThicknessShouldWrite('UNI_DOSKA_18', 'UNI_INY', { id: 'UNI_INY', thickness: 38, uni: true }, false), true,
     'iny UNI zaznam = realna zmena vyberu, dosad jeho default');
  eq(insertThicknessShouldWrite('REAL_19', 'REAL_19', REAL, false), true,
     'realny material draft nema — hodnota vzdy z katalogu');
  eq(insertThicknessShouldWrite('UNI_DOSKA_18', 'UNI_DOSKA_18', null, false), true,
     'material medzitym zmizol z katalogu -> pole sa vycisti');
})();

// --- D-86: vedome zvoleny SMER DEKORU prezije refresh katalogu -----------------
// Scenar: vo vkladacej karte je materiál so smerom "po dĺžke", používateľ vedome
// prepne na "Bez smeru" a dosku ešte NEVLOŽÍ. Medzitým v okne Materiály urobí CRUD
// -> NX.setMaterials -> refreshInsertBoardMaterials() -> onInsertBoardMaterial().
// Hotový insertThicknessShouldWrite sa použiť NEDÁ: pri rovnakom REÁLNOM materiáli
// vracia true (hrúbka je vtedy zamknutá), kým smer sa dá meniť pri každom materiáli.
// Rozhoduje preto zmena materiálu + príznak "siahol naň používateľ".
(function(){
  eq(insertGrainShouldWrite('REAL_19', 'REAL_19', REAL, true, false), false,
     'refresh katalogu pri NEZMENENOM materiali drzi volbu pouzivatela');
  eq(insertGrainShouldWrite('UNI_DOSKA_18', 'UNI_DOSKA_18', UNI, true, false), false,
     'to iste plati aj pri UNI materiali (na type materialu nezalezi)');
  eq(insertGrainShouldWrite('REAL_19', 'REAL_19', REAL, false, false), true,
     'nezmeneny material, pouzivatel na smer NESIAHOL -> predvolba sa smie doplnit');
  eq(insertGrainShouldWrite(null, 'REAL_19', REAL, false, false), true,
     'prve naplnenie karty dosadi predvolbu materialu');
  eq(insertGrainShouldWrite('UNI_DOSKA_18', 'REAL_19', REAL, true, false), true,
     'skutocna zmena materialu prepise aj vedomu volbu (novy material = nova predvolba)');
  eq(insertGrainShouldWrite('REAL_19', 'REAL_19', REAL, true, true), false,
     'rozkliknuty select v TOMTO okne sa neprepisuje uz vobec');
  eq(insertGrainShouldWrite('REAL_19', 'REAL_19', REAL, false, true), false,
     'fokus prebije aj netknuty stav');
  eq(insertGrainShouldWrite('UNI_DOSKA_18', 'REAL_19', null, false, false), false,
     'material zmizol z katalogu -> select sa NEcisti (ma pevne moznosti)');
  eq(insertGrainShouldWrite('UNI_DOSKA_18', 'BEZ_SMERU', { id: 'BEZ_SMERU', thickness: 18 }, false, false), false,
     'zaznam bez kluca grain nema co dosadit');
  eq(insertGrainShouldWrite('UNI_DOSKA_18', 'BEZ_SMERU', { id: 'BEZ_SMERU', grain: '' }, false, false), false,
     'prazdna predvolba nie je predvolba');
})();

// --- Codex #163 P2: fokus nesmie zmenu materialu ZAHODIT ----------------------
// Diera povodneho fixu (a rovnako aj hrubkoveho guardu z E-03): ked refresh katalogu
// vymenil vybrany material (napr. ho niekto zmazal), kym pouzivatel stal v poli,
// fokusovy guard zapis potlacil — ale marker "pre ktory material je pole zosynchro-
// nizovane" sa aj tak posunul. Dalsie refreshe uz videli "bez zmeny" a do vlozenej
// dosky isla zatuchnuta hodnota. Marker sa preto pri fokusom potlacenom zapise DRZI.
(function(){
  eq(insertMatMarkAdvances('REAL_19', 'UNI_DOSKA_18', true), false,
     'fokus + ZMENENY material -> marker sa drzi (zapis sa dokona neskor)');
  eq(insertMatMarkAdvances('REAL_19', 'UNI_DOSKA_18', false), true,
     'bez fokusu sa marker posuva vzdy');
  eq(insertMatMarkAdvances('REAL_19', 'REAL_19', true), true,
     'fokus pri NEZMENENOM materiali marker nedrzi (bolo by to bez ucinku)');
  eq(insertMatMarkAdvances(null, 'REAL_19', true), false,
     'prve naplnenie s fokusom sa tiez odklada, nie zahadzuje');
})();

// Tu istu dieru mal aj hrubkovy guard z E-03 (uzsiu — prejavila by sa pri UNI
// materiali, kde je draft chraneny) a opravuje ju ten isty mechanizmus: zapis sa
// potlaci, ale marker sa drzi, takze po odchode fokusu default noveho materialu dobehne.
(function(){
  eq(insertThicknessShouldWrite('REAL_19', 'UNI_DOSKA_18', UNI, true), false,
     'hrubka: fokus zapis potlacil');
  eq(insertMatMarkAdvances('REAL_19', 'UNI_DOSKA_18', true), false,
     'hrubka: marker sa drzi na starom materiali (ten isty mechanizmus ako smer)');
  eq(insertThicknessShouldWrite('REAL_19', 'UNI_DOSKA_18', UNI, false), true,
     'hrubka: po odchode fokusu sa default noveho materialu dosadi');
})();

// Scenar cez CISTY automat insertGrainSync (produkcia aj test pouzivaju ten isty kod).
(function(){
  // 1) prve naplnenie karty: predvolba materialu sa dosadi ('none' z UNI zaznamu)
  var st = insertGrainSync({ mark: null, touched: false, value: '' }, 'UNI_DOSKA_18', UNI, false);
  eq([st.value, st.wrote, st.mark], ['none', true, 'UNI_DOSKA_18'],
     'prve naplnenie dosadi predvolbu materialu');
  // 2) pouzivatel vedome prepne smer na "po sirke"
  st = { mark: st.mark, touched: true, value: 'width' };
  // 3) refresh katalogu bez zmeny materialu (aj opakovany) volbu DRZI
  st = insertGrainSync(st, 'UNI_DOSKA_18', UNI, false);
  eq([st.value, st.wrote], ['width', false], 'refresh bez zmeny materialu drzi volbu');
  st = insertGrainSync(st, 'UNI_DOSKA_18', UNI, false);
  eq([st.value, st.touched], ['width', true], 'ani opakovany refresh na tom nic nemeni');
  // 4) refresh VYMENI material, kym pouzivatel stoji v selecte -> zapis sa odlozi
  st = insertGrainSync(st, 'REAL_19', REAL, true);
  eq([st.value, st.wrote, st.mark], ['width', false, 'UNI_DOSKA_18'],
     'fokus zapis potlacil — marker ostal na starom materiali (zmena sa NEZAHODILA)');
  // 5) ...a NAKONIEC sa dosadi (blur selectu alebo dalsi refresh)
  st = insertGrainSync(st, 'REAL_19', REAL, false);
  eq([st.value, st.wrote, st.mark, st.touched], ['length', true, 'REAL_19', false],
     'odlozena predvolba noveho materialu sa dokona a priznak "siahol" padne');
  // 6) netknute pole uz patri katalogu — dalsi refresh zapise tu istu hodnotu (bez ucinku)
  var after = insertGrainSync(st, 'REAL_19', REAL, false);
  eq([after.value, after.mark], ['length', 'REAL_19'], 'zosynchronizovany stav je stabilny');
})();

const FORM = { name: 'Polica', length: '800', width: '300',
               material_id: 'UNI_DOSKA_18', grain_direction: 'none', thickness: '12' };

// --- UNI: hrubka ide do payloadu ---------------------------------------------
(function(){
  const r = buildInsertBoardPayload(FORM, UNI, evalDim);
  eq(r.ok, true, 'UNI payload prejde');
  eq(r.payload.thickness, 12, 'UNI: hrubka z formulara');
  eq(r.payload.length, 800, 'dlzka');
  eq(r.payload.width, 300, 'sirka');
  eq(r.payload.material_id, 'UNI_DOSKA_18', 'material');
})();

// --- UNI: vyraz v hrubke sa vyhodnoti (18-6 = 12) ------------------------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { thickness: '18-6' }), UNI, evalDim);
  eq(r.ok, true, 'vyraz je platny vstup');
  eq(r.payload.thickness, 12, 'vyhodnoteny vyraz, nie surovy string');
})();

// --- UNI: neplatna hrubka = STOP so statusom (nic sa neposiela) -----------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { thickness: 'abc' }), UNI, evalDim);
  eq(r.ok, false, 'nezmysel sa odmietne');
  ok(/hrúbku/.test(r.error), 'hlaska hovori o hrubke');
  eq(r.payload, undefined, 'ziadny payload');
})();

// --- UNI: prazdna hrubka = kluc chyba (server dosadi default roly) --------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { thickness: '  ' }), UNI, evalDim);
  eq(r.ok, true, 'prazdna hrubka nie je chyba');
  eq('thickness' in r.payload, false, 'kluc sa neposiela');
})();

// --- REALNY material: thickness sa do payloadu NEDOSTANE ------------------------
(function(){
  const r = buildInsertBoardPayload(
    Object.assign({}, FORM, { material_id: 'REAL_19', thickness: '99' }), REAL, evalDim);
  eq(r.ok, true, 'payload prejde');
  eq('thickness' in r.payload, false, 'hrubku diktuje katalog (D-45)');
  const bad = buildInsertBoardPayload(
    Object.assign({}, FORM, { material_id: 'REAL_19', thickness: 'abc' }), REAL, evalDim);
  eq(bad.ok, true, 'zamknute pole nesmie blokovat vlozenie ani so smetim v hodnote');
})();

// --- rozmery: povodne spravanie ostava -----------------------------------------
(function(){
  const r = buildInsertBoardPayload(Object.assign({}, FORM, { length: '650-' }), UNI, evalDim);
  eq(r.ok, false, 'rozpisany vyraz sa odmietne');
  ok(/rozmery/.test(r.error), 'hlaska hovori o rozmeroch');
  const empty = buildInsertBoardPayload(
    Object.assign({}, FORM, { length: '', width: '' }), UNI, evalDim);
  eq(empty.ok, true, 'prazdne rozmery = defaulty na serveri');
  eq(empty.payload.length, '', 'prazdny retazec ostava');
})();

// --- odolnost: chybajuce polia neurobia "undefined" v payloade ------------------
(function(){
  const r = buildInsertBoardPayload({}, null, evalDim);
  eq(r.ok, true, 'prazdny formular prejde');
  eq(r.payload.name, '', 'nazov je vzdy string');
  eq(r.payload.material_id, '', 'material je vzdy string');
  eq('thickness' in r.payload, false, 'bez materialu ziadna hrubka');
})();

console.log(`OK test_e03_board_insert.js — ${n} kontrol`);
