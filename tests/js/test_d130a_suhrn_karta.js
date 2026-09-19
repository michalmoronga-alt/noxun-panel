global.nxDocGuid = () => ''; // samostatna karta bez dokumentoveho bridge
// D-130a — SUHRN RIADKU + KARTA S TABMI + POPOVER „všetkým".
//
// PRECO SU TO TESTY A NIE KLIKANIE:
//   1. SUHRN je jediny text, z ktoreho Michal cita stav VSETKYCH ciel bez
//      otvarania kariet. Ked bude klamat, chyba sa prejavi az vo vyrobe —
//      napr. „1 krídlo" nad dvierkami, ktore server rozdelil na dve.
//      Pocet kridiel preto MUSI ist zo servera (`front_slots[fid].wings_n`),
//      nie z `wings`: AUTO nad 600 mm su DVE kridla a to vie len server.
//   2. TROJSTAV SMERU sa neda vidiet. „Kluc chyba" (legacy) a „neurcene"
//      vyzeraju rovnako; rozdiel je v tom, CO sa ulozi a ci Kontrola vyda
//      cerveny nalez. Suhrn preto nesmie badge vyrobit zo `slotu`, ktory
//      o legacy cele nic nevie.
//   3. POPOVER je AKCIA, nie druhy stav (D-129). Keby selecty zapisovali,
//      vznikli by dva-tri kroky Späť na jedno rozhodnutie a hrana by sa
//      nedala zvolit „vopred".
//   4. TAB je stav prace nad jednym celom — musi prezit echo (`refreshFrontCards`),
//      inak by kazdy push hodil pouzivatela z Kovania spat na Čelo.
//
// MUTACIE, ktore sada chyta:
//   M1 „Použiť" zapise len profil bez hrany            -> E)
//   M2 `collectFronts` stratí `wings` (legacy)          -> D)
//   M3 tab Kovanie sa po `refreshFrontCards` vrati na Čelo -> F)
//   M4 klik na ikonu v `summary` zbali skupinu          -> G)
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const C = require(path.join(JS, 'core.js'));
const UNSET = C.FRONT_DIR_UNSET;

// Register profilov, ktory v paneli chodi z Ruby (`FrontProfiles.options`).
const REG = [{ id: 'ukw7', name: 'UKW-7', short: 'UKW-7', reduction: 22 }];
function entry(wingsN, slots){ return { wings_n: wingsN, slots: slots || [] }; }
function slot(wing, state){ return { wing: wing, part_key: 'front:F1/wing:' + wing, state: state }; }
// Suhrn ako CITATELNY retazec — badge sa prizna zatvorkami, aby sa v teste
// dalo rozlisit „slovo" od „jantaroveho chipu".
function sum(item, e, hw, drawer){
  return C.frontRowSummary(item, e, hw, REG, drawer)
    .map(p => p.badge ? '[' + p.badge + ']' : (p.hw ? '->' + p.hw : (p.tone ? '(' + p.text + ')' : p.text)))
    .join(' · ');
}

// ============ A) SUHRN: dvierka =============================================

eq(sum({ type: 'door' }, entry(1, [])), '1 krídlo (auto) · bez úchytky',
   'A: AUTO dvierka bez ulozeneho smeru — LEGACY celo badge NEMA (kluc chyba)');
eq(sum({ type: 'door', direction: UNSET }, entry(1, [slot('single', UNSET)])),
   '1 krídlo (auto) · [smer?] · bez úchytky',
   'A: ulozene „neurčené" = jantarovy badge');
eq(sum({ type: 'door', direction: 'left', wings: '1' }, entry(1, [slot('single', 'left')])),
   '1 krídlo · ľavé · bez úchytky',
   'A: vyriesene dvierka povedia stranu pantov');
// R3-a: AUTO nad 600 mm su DVE kridla — a to vie LEN server.
eq(sum({ type: 'door' }, entry(2, [])), '2 krídla (auto) · bez úchytky',
   'A: pocet kridiel ide zo servera, nie z `wings` (AUTO nad 600 mm = 2)');
eq(sum({ type: 'door', wings: '2', direction: 'left' }, entry(2, [])),
   '2 krídla · bez úchytky',
   'A: dvojkridlo o smere MLCI — je odvodeny z geometrie');
eq(sum({ type: 'door', wings: '3', wing_directions: { p2: UNSET } }, entry(3, [slot('p2', UNSET)])),
   '3 krídla · [smer?] · bez úchytky',
   'A: neurcene STREDNE kridlo badge vyrobi');
eq(sum({ type: 'door', wings: '3', wing_directions: { p2: 'left' } }, entry(3, [slot('p2', 'left')])),
   '3 krídla · bez úchytky',
   'A: a urcene uz nie');
// Bez zaznamu servera sa pocet NEODVODZUJE.
eq(sum({ type: 'door', wings: '2' }, null), 'auto · bez úchytky',
   'A: novy riadok pred echom povie len „auto" (server sa este nevyjadril)');

// ============ B) SUHRN: ostatne typy ========================================

eq(sum({ type: 'drawer_front', drawer: { construction: 'wood' }, opening_mode: 'classic' }, entry(1, [])),
   'drevený box · bez úchytky', 'B: zasuvka povie konstrukciu');
eq(sum({ type: 'drawer_front', drawer: { construction: 'metal', variant: 'internal' },
         opening_mode: 'tipon' }, entry(1, [])),
   'kovové bočnice · vnútorná · Tip-On · bez úchytky',
   'B: vnutorna zasuvka s Tip-On');
eq(sum({ type: 'drawer_front' }, entry(1, [])), '(bez klasifikácie) · bez úchytky',
   'B: zasuvka bez klasifikacie = JANTAROVA cast (dielce sa nevyrobia)');
// Ked server o zasuvke UZ NIECO POVEDAL, veta „bez klasifikácie" zmizne —
// rovnaky predikat ako `frontCardModel` (dve verzie by sa rozisli).
eq(sum({ type: 'drawer_front' }, entry(1, []), '', { state: 'ok', text: 'x', detail: [] }),
   'bez úchytky', 'B: so zaznamom servera uz suhrn „bez klasifikácie" netvrdi');
eq(sum({ type: 'lift', lift: { system: 'hl_top' } }, entry(1, [])), 'HL top · bez úchytky',
   'B: vyklop povie system');
eq(sum({ type: 'none' }, entry(1, [])), 'otvorená nika', 'B: „Bez čela" ma jedno slovo');
eq(sum({ type: 'blind' }, entry(1, [])), 'pevný dielec · bez úchytky · bez kovania',
   'B: blenda bez profilu — R6-d: „bez kovania" sa POVIE, netvrdi sa nic ine');
eq(sum({ type: 'blind', profile: 'ukw7' }, entry(1, []), 'Úchytkový profil UKW-7 · 1 ks'),
   'pevný dielec · UKW-7 hore · ->Úchytkový profil UKW-7 · 1 ks',
   'B: blenda S PROFILOM kovanie MA (pravidlo `uchytkovy-profil-blenda`)');

// ============ C) SUHRN: uchytka a kovanie ===================================

eq(sum({ type: 'door', profile: 'ukw7', profile_edge: 'bottom' }, entry(1, [])),
   '1 krídlo (auto) · UKW-7 dole', 'C: profil sa povie SLOVOM aj s hranou');
eq(sum({ type: 'door', profile: 'ukw7', profile_edge: 'left' }, entry(1, [])),
   '1 krídlo (auto) · UKW-7',
   'C: hrana, ktoru typ nema, sa NEVYPISE (dvierka nemaju „vľavo")');
eq(sum({ type: 'none', profile: 'ukw7' }, entry(1, [])), 'otvorená nika',
   'C: profileless typ o uchytke mlci');
eq(sum({ type: 'door' }, entry(1, []), 'Sensys klasik · 2 ks'),
   '1 krídlo (auto) · bez úchytky · ->Sensys klasik · 2 ks',
   'C: kovanie je POSLEDNA cast (preklik do tabu Kovanie)');

// ============ D) KARTA: taby + kridla v datasete ============================

eq(C.frontCardTabs('door', false).map(t => t.key), ['celo', 'hw'], 'D: dvierka maju oba taby');
eq(C.frontCardTabs('blind', false).map(t => t.key), ['celo', 'hw'],
   'D (R6-b): blenda tab Kovanie MA — s profilom kovanie vznika');
eq(C.frontCardTabs('none', false).map(t => t.key), ['celo'],
   'D: „Bez čela" tab Kovanie NEMA (nie je to dielec)');
eq(C.frontCardTabs('door', true)[0].badge, 'smer?',
   'D: otvorena otazka smeru sa prizna NA TABE — vidno ju aj z tabu Kovanie');
eq(C.frontCardTabs('door', false)[0].badge, null, 'D: inak badge nie je');
eq(C.frontCardModel({ type: 'door', direction: UNSET }, entry(1, [slot('single', UNSET)])).tabs[0].badge,
   'smer?', 'D: view-model badge odvodi z ULOZENEJ hodnoty');
eq(C.frontCardModel({ type: 'door' }, entry(1, [slot('single', UNSET)])).tabs[0].badge, null,
   'D: LEGACY celo (kluc chyba) badge NEMA ani na tabe');

// ============ E) DOM: riadok, popover, taby =================================
//
// form.js kresli riadky nad globalmi, ktore v paneli zakladaju skripty pred nim.
// V Node ich stavia tento blok — stubuju sa LEN cudzie zavislosti.
const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { global[k] = C[k]; });
global.FRONT_PROFILES = REG;
global.frontItems = null;
global.frontSlots = null;
global.frontDrawer = null;
global.frontLift = null;
global.selectedCabId = null;
global.applyTimer = null;
global.newStableId = p => p + (++global.__nxid || (global.__nxid = 1));
global.attachExprField = () => {};
global.nxDimFillRow = () => {};
global.evalDim = v => parseFloat(v);
global.numv = () => NaN;
global.val = () => '';
global.setNum = () => {};
global.setOut = () => {};
global.isExprInput = () => false;
global.isExprStr = () => false;
// `onField` je vo `form.js` privatna, ale VZDY prejde cez `refreshMaterialFilters`
// — pocitadlo nad nou je teda pocitadlo APPLY ciest (vzor KOV-A2a).
let applyCalls = 0;
global.refreshMaterialFilters = () => { applyCalls++; };
global.renderPreview = () => {};
global.clearFrontHover = () => {};
global.currentCarcass = () => ({});
global.nxInteriorZ = () => ({ availH: 0 });
global.pvGeom = () => ({ W: 0, H: 0 });
global.computeZones = () => [];
global.pvInsertFronts = () => [];
global.nxDraftStats = () => ({});
global.setCabInfo = () => {};
global.frontHwBadge = () => '';
global.frontHwBuy = () => '';
global.hwAxHtml = require(path.join(JS, 'hardware.js')).hwAxHtml;
const FM = require(path.join(JS, 'form.js'));

// Skupina `fronts` s hlavickou a popoverom — presna kopia kostry z panel.html
// (test musi klikat do TOHO ISTEHO tvaru, inak nic neoveri).
const grp = mkEl('details');
grp.attrs['data-key'] = 'fronts';
DOC.body.appendChild(grp);
const summary = mkEl('summary');
grp.appendChild(summary);
const bulkBtn = mkEl('button');
bulkBtn.attrs.id = 'frontBulkBtn';
summary.appendChild(bulkBtn);
const pop = mkEl('div');
pop.attrs.id = 'frontBulkPop';
pop.attrs.hidden = '';
pop.hidden = true;
grp.appendChild(pop);
function mkSel(id, values){
  const s = mkEl('select');
  s.attrs.id = id;
  values.forEach(v => { const o = mkEl('option'); o.attrs.value = v; s.appendChild(o); });
  s.value = values[0] || '';
  pop.appendChild(s);
  DOC.body.appendChild(s); // `el(id)` hlada v dokumente
  return s;
}
const scopeSel = mkSel('frontProfileScope', ['all', 'drawer_front', 'door']);
const profSel = mkSel('frontProfileSel', []);
const edgeSel = mkSel('frontProfileEdge', []);
const stateNode = mkEl('span'); stateNode.attrs.id = 'frontProfileState'; DOC.body.appendChild(stateNode);
const applyBtn = mkEl('button'); applyBtn.attrs.id = 'frontBulkApply'; DOC.body.appendChild(applyBtn);
const metaNode = mkEl('span'); metaNode.attrs.id = 'frontMeta'; DOC.body.appendChild(metaNode);
const rows = mkEl('div');
rows.attrs.id = 'frontRows';
DOC.body.appendChild(rows);

function resetRows(){ rows.children = []; global.frontSlots = null; global.frontDrawer = null; }
function rowOf(fid){ return rows.querySelectorAll('.frow').find(r => r.dataset.frontId === fid); }
function items(){ return FM.collectFronts().items; }
function openCard(fid){
  FM.refreshFrontCards();
  const b = rowOf(fid).querySelector('.ftname');
  if (b.getAttribute('aria-expanded') !== 'true') FM.onFrontCardToggle(b);
}
function tabBtn(fid, key){ return rowOf(fid).querySelector('.ctabs button[data-tab="' + key + '"]'); }

// --- D) KRIDLA ZIJU V DATASETE (M2) ----------------------------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: '2' });
eq(rowOf('F1').dataset.frontWings, '2', 'D: hodnota sa ulozila do datasetu riadku');
eq(rowOf('F1').querySelector('.fw'), null, 'D: rozbalovacka kridel v riadku uz NEEXISTUJE');
eq(items()[0].wings, '2', 'D: a `collectFronts` ju cita odtial');
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door' }); // legacy: kluc `wings` v configu chyba
eq(items()[0].wings, 'auto', 'D (M2): legacy celo ide na `auto` — 1:1 s dnesnym selectom');
// Zapis cez segment karty.
global.frontSlots = { F1: entry(1, [slot('single', null)]) };
openCard('F1');
const wingsBtn = rowOf('F1').querySelectorAll('.segrow button')
  .find(b => b.dataset.k === 'wings' && b.dataset.v === '2');
ok(wingsBtn, 'D: karta ma segment „Krídla"');
const beforeWings = applyCalls;
FM.onFrontSeg(wingsBtn);
eq(items()[0].wings, '2', 'D: klik na segment zapisal pocet');
eq(applyCalls - beforeWings, 1, 'D: PRESNE jeden apply = jeden krok Späť');
FM.onFrontSeg(rowOf('F1').querySelectorAll('.segrow button')
  .find(b => b.dataset.k === 'wings' && b.dataset.v === '2'));
eq(applyCalls - beforeWings, 1, 'D: klik na uz nasadenu hodnotu NESPUSTI prazdny apply');

// --- E) POPOVER: selecty NEZAPISUJU, zapisuje „Použiť" (M1) -----------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'drawer_front' });
FM.addFrontRow({ id: 'F2', type: 'drawer_front' });
FM.addFrontRow({ id: 'F3', type: 'door' });
FM.refreshFrontProfileUI();
// R7-c: pri ZBALENEJ skupine trigger skupinu najprv OTVORI.
grp.open = false;
FM.onFrontBulkToggle({ preventDefault(){}, stopPropagation(){} });
eq(grp.open, true, 'E (R7-c): klik na „všetkým" zbalenu skupinu OTVORI…');
eq(pop.hidden, false, 'E: …a az potom ukaze popover');
eq(bulkBtn.getAttribute('aria-expanded'), 'true', 'E: stav tlacidla sedi');

// M4: tlacidla v `<summary>` MUSIA zastavit natívny toggle `<details>` —
// inak by klik na „všetkým" (alebo na `?`) skupinu zbalil a popover by sa
// otvoril do zbalena. Mini-DOM natívny toggle nesimuluje, preto sa overuje
// PRIAMO to, co ho zastavuje: `preventDefault` + `stopPropagation`.
(function(){
  let prevented = 0, stopped = 0;
  const ev = { preventDefault(){ prevented++; }, stopPropagation(){ stopped++; } };
  FM.onFrontBulkToggle(ev);           // zatvori (popover je otvoreny)
  eq([prevented, stopped], [1, 1], 'E (M4): „všetkým" zastavi natívny toggle `<details>`');
  let p2 = 0, s2 = 0;
  FM.nxTipStop({ preventDefault(){ p2++; }, stopPropagation(){ s2++; } });
  eq([p2, s2], [1, 1], 'E (M4): a tooltip `?` v hlavicke tiez');
  FM.onFrontBulkToggle({ preventDefault(){}, stopPropagation(){} }); // spat otvorit
  eq(pop.hidden, false, 'E: popover je znova otvoreny');
})();

scopeSel.value = 'drawer_front';
FM.onFrontProfileScope();
profSel.value = 'ukw7';
const beforePick = applyCalls;
FM.onFrontProfilePick();
eq(applyCalls, beforePick, 'E: zmena PROFILU v popoveri NIC nezapisuje');
edgeSel.value = 'bottom';
FM.onFrontProfileEdgePick();
eq(applyCalls, beforePick, 'E: ani zmena HRANY');
eq(items().map(x => x.profile), ['none', 'none', 'none'], 'E: riadky su nedotknute');

FM.onFrontBulkApply();
eq(applyCalls - beforePick, 1, 'E: „Použiť" = PRESNE jeden apply (jeden krok Späť)');
eq(items().map(x => x.profile), ['ukw7', 'ukw7', 'none'],
   'E: profil dostali LEN zasuvkove cela, dvierka ostali');
eq(items().map(x => x.profile_edge), ['bottom', 'bottom', undefined],
   'E (M1): a spolu s nim aj PLATNA hrana — profil bez hrany by nechal „Hore"');
eq(pop.hidden, true, 'E: po „Použiť" sa popover zatvara');

// --- F) TAB prezije echo (M3) ----------------------------------------------
resetRows();
global.frontSlots = { F1: entry(1, []) };
global.frontDrawer = { F1: { state: 'ok', text: 'Atira · H70 · NL 470', detail: [] } };
FM.addFrontRow({ id: 'F1', type: 'drawer_front', opening_mode: 'classic',
                 drawer: { construction: 'metal', variant: 'standard' } });
openCard('F1');
eq(tabBtn('F1', 'celo').attrs.class, 'on', 'F: karta sa otvara na tabe Čelo');
FM.onFrontCardTab(tabBtn('F1', 'hw'));
eq(tabBtn('F1', 'hw').attrs.class, 'on', 'F: prepnutie na Kovanie');
ok(rowOf('F1').querySelector('.drow'), 'F: a je v nom vyriesena zasuvka');
const beforeTab = applyCalls;
FM.refreshFrontCards(); // echo / lahky push
eq(applyCalls, beforeTab, 'F: prekreslenie NIC nezapisuje');
eq(tabBtn('F1', 'hw').attrs.class, 'on', 'F (M3): tab Kovanie PREZIL echo');
// Otvorenie INEJ karty vsak zacina na Čele — tab je stav prace nad JEDNYM celom.
FM.addFrontRow({ id: 'F2', type: 'door' });
FM.onFrontCardToggle(rowOf('F2').querySelector('.ftname'));
eq(tabBtn('F2', 'celo').attrs.class, 'on', 'F: ina karta zacina na tabe Čelo');

// --- G) SUHRN v DOM: koncovka kovania je SURODENEC (R3-f, M4) ---------------
resetRows();
global.frontHwBadge = () => '2× závesy';
global.frontHwBuy = () => 'Sensys klasik';
global.frontSlots = { F1: entry(1, [slot('single', UNSET)]) };
FM.addFrontRow({ id: 'F1', type: 'door', direction: UNSET });
FM.updateFrontRowSummaries();
const sub = rowOf('F1').querySelector('.fsub');
const link = rowOf('F1').querySelector('.fhwlink');
ok(sub && link, 'G: suhrn aj koncovka kovania existuju');
eq(link.parent, sub.parent, 'G (R3-f): su to SURODENCI, nie ovladac v ovladaci');
eq(sub.querySelector('.fhwlink'), null, 'G: koncovka NIE JE vnorena v suhrne');
eq(link.tagName, 'BUTTON', 'G: a je to natívne tlacidlo (Enter aj medzernik dava prehliadac)');
eq(link.hidden, false, 'G: pri naviazanom kovani je viditelna');
ok(sub.querySelector('.fbadge'), 'G: badge „smer?" zije v SUHRNE');
// Klik na koncovku otvori kartu ROVNO na tabe Kovanie.
FM.onFrontSummaryHw({ stopPropagation(){} }, link);
eq(tabBtn('F1', 'hw').attrs.class, 'on', 'G: klik na kovanie otvori tab Kovanie');
// A klik na zvysok suhrnu prepne na Čelo (toggle karty).
FM.onFrontCardToggle(rowOf('F1').querySelector('.fsub'));
FM.onFrontCardToggle(rowOf('F1').querySelector('.fsub'));
eq(tabBtn('F1', 'celo').attrs.class, 'on', 'G: suhrn otvara kartu na tabe Čelo');
// Bez kovania je koncovka SKRYTA (prazdne tlacidlo by bralo tab-stop).
global.frontHwBadge = () => '';
global.frontHwBuy = () => '';
FM.updateFrontRowSummaries();
eq(rowOf('F1').querySelector('.fhwlink').hidden, true, 'G: bez kovania je koncovka skryta');

// --- G2) META v hlavicke ----------------------------------------------------
FM.addFrontRow({ id: 'F2', type: 'door' });
FM.updateFrontMeta();
eq(metaNode.textContent, '2 čelá · 1 bez smeru',
   'G2: meta hovori pocet a kolko ciel caka na smer (zo servera)');
global.frontSlots = null;
FM.updateFrontMeta();
eq(metaNode.textContent, '2 čelá', 'G2: bez slotov ostane LEN pocet — nic sa neodvodzuje');

// ===========================================================================
// H) CODEX #371 kolo 1 — sest P2 nalezov
// ===========================================================================

// --- H1) prazdny tab Kovanie sa odvodzuje z REALNEHO kovania vlastnika -----
// Dvierka, sklop aj blenda s profilom kovanie MAJU, len o nom hovori plan
// a nakup (`frontHwBadge` / `frontHwBuy`), nie serverovy zaznam `hwRows`.
// Veta „Bez kovania" nad nimi by klamala.
resetRows();
global.frontSlots = { F1: entry(1, [slot('single', 'left')]) };
global.frontDrawer = null;
global.frontHwBadge = () => '2× závesy';
global.frontHwBuy = () => 'Sensys klasik';
FM.addFrontRow({ id: 'F1', type: 'door', direction: 'left' });
openCard('F1');
FM.onFrontCardTab(tabBtn('F1', 'hw'));
let hwHtml = rowOf('F1').querySelector('.fcard').innerHTML;
ok(hwHtml.indexOf('Bez kovania') < 0,
   'H1: dvierka s naviazanym kovanim NEHLASIA „Bez kovania" (hwRows su prazdne, kovanie NIE)');
ok(hwHtml.indexOf('2× závesy') >= 0 && hwHtml.indexOf('Sensys klasik') >= 0,
   'H1: ukaze sa jeho TEXT — tie iste zdroje ako suhrn riadku');
// A ked kovanie naozaj NIE JE, veta ostava.
global.frontHwBadge = () => '';
global.frontHwBuy = () => '';
FM.refreshFrontCards();
ok(rowOf('F1').querySelector('.fcard').innerHTML.indexOf('Bez kovania') >= 0,
   'H1: bez kovania a bez boxu vlastnika sa to POVIE');

// --- H3) deep-link `NX.focusFront` otvara kartu na tabe Čelo ---------------
// RED nalez SMERU vedie na otazku, ktora zije v tabe Čelo. Bez resetu by sa
// cielova karta otvorila na Kovani — stav po PREDCHADZAJUCEJ karte.
resetRows();
global.frontSlots = { F1: entry(1, [slot('single', UNSET)]), F2: entry(1, [slot('single', UNSET)]) };
FM.addFrontRow({ id: 'F1', type: 'door', direction: UNSET });
FM.addFrontRow({ id: 'F2', type: 'door', direction: UNSET });
openCard('F1');
FM.onFrontCardTab(tabBtn('F1', 'hw'));
eq(tabBtn('F1', 'hw').attrs.class, 'on', 'H3: predchadzajuca karta stoji na Kovani');
ok(FM.nxFocusFront('F2'), 'H3: deep-link na F2 presiel');
eq(tabBtn('F2', 'celo').attrs.class, 'on',
   'H3: cielova karta sa otvorila na tabe Čelo (tam je segment smeru)');

// --- H4) badge „smer?" rata LEN z AKTIVNYCH slotov -------------------------
// Navrat zo 4 kridiel na 2 necha `p2: unset` ako DORMANTNU hodnotu (A1: navrat
// nic nemaze). Badge by inak navzdy svietil na otazku, ktoru nikto nekladie.
const dormant = { type: 'door', wings: '2', wing_directions: { p2: UNSET, p3: UNSET } };
eq(sum(dormant, entry(2, [])), '2 krídla · bez úchytky',
   'H4: dormantne `wing_directions` po navrate na 2 kridla badge NEROBIA');
eq(C.frontCardModel(dormant, entry(2, [])).tabs[0].badge, null, 'H4: ani na tabe');
// Kym su sloty AKTIVNE, badge samozrejme plati.
eq(sum({ type: 'door', wings: '4', wing_directions: { p2: UNSET, p3: 'left' } },
       entry(4, [slot('p2', UNSET), slot('p3', 'left')])),
   '4 krídla · [smer?] · bez úchytky', 'H4: aktivny slot s `unset` badge DAVA');
eq(sum({ type: 'door', wings: '4', wing_directions: { p2: 'right', p3: 'left' } },
       entry(4, [slot('p2', 'right'), slot('p3', 'left')])),
   '4 krídla · bez úchytky', 'H4: a urcene stredne kridla uz nie');
// Dvojkridlo bez slotov o smere mlci aj pri ulozenom scalarnom `unset`.
eq(sum({ type: 'door', wings: '2', direction: UNSET }, entry(2, [])),
   '2 krídla · bez úchytky', 'H4: dvojkridlo ma smer ODVODENY — badge nedostane');
eq(sum({ type: 'door', direction: UNSET }, entry(1, [])),
   '1 krídlo (auto) · [smer?] · bez úchytky',
   'H4: bez slotov pri JEDNOM kridle rozhoduje scalarny `direction`');

// --- H5) „Otvoriť v Kovaní" s `aria-disabled` NEROBI NIC -------------------
resetRows();
global.frontSlots = { F1: entry(1, []) };
let ctxCalls = 0;
global.setViewContext = () => { ctxCalls++; };
global.hwBoxByGroup = () => null;        // box vlastnika neexistuje
global.hwFrontGroup = (fid) => 'front:' + fid;
global.NX = { setStatus: function(){} };
FM.addFrontRow({ id: 'F1', type: 'drawer_front' });
openCard('F1');
FM.onFrontCardTab(tabBtn('F1', 'hw'));
const openBtn = rowOf('F1').querySelector('.cfoot .ghostbtn');
eq(openBtn.getAttribute('aria-disabled'), 'true', 'H5: bez boxu vlastnika je tlacidlo stlmene (D-78)');
ok(openBtn.getAttribute('title').indexOf('nemá naviazané kovanie') >= 0, 'H5: a dovod nesie `title`');
FM.onFrontOpenHardware(openBtn, 'F1');
eq(ctxCalls, 0, 'H5: klik na `aria-disabled` tlacidlo NEPREPNE kontext');
// A aj priama cesta overi ciel PRED prepnutim kontextu.
FM.openFrontHardware('F1');
eq(ctxCalls, 0, 'H5: `openFrontHardware` bez ciela kontext NEMENI (neuspesny skok nikam nevedie)');

// --- H6) Escape popoveru SPOTREBUJE udalost --------------------------------
// Vsetky Escape listenery visia na `document`; bez `stopImmediatePropagation`
// by jedno stlacenie zavrelo popover AJ flyout z `boot.js`.
(function(){
  const src = require('node:fs')
    .readFileSync(path.join(JS, 'form.js'), 'utf8').replace(/\r\n/g, '\n');
  const esc = src.match(/document\.addEventListener\('keydown'[\s\S]*?\n    \}\);/);
  ok(esc, 'H6: Escape handler popoveru sa nasiel');
  ok(esc[0].indexOf('stopImmediatePropagation') >= 0,
     'H6: Escape sa SPOTREBUJE (inak zavrie dve vrstvy naraz)');
  ok(esc[0].indexOf('preventDefault') >= 0, 'H6: a zrusi natívne spravanie');
  // PORADIE: `nx_esc.js` (retaz modalov) MUSI byt v panel.html PRED `form.js`,
  // aby modal svoje Escape spotreboval skor, nez sa dostane k popoveru.
  const html = require('node:fs')
    .readFileSync(path.join(JS, '..', 'panel.html'), 'utf8').replace(/\r\n/g, '\n');
  ok(html.indexOf('js/nx_esc.js') < html.indexOf('js/form.js'),
     'H6: `nx_esc.js` je nacitany PRED `form.js` (modal je nad popoverom)');
  ok(html.indexOf('js/form.js') < html.indexOf('js/boot.js'),
     'H6: a `form.js` pred `boot.js` (popover je nad flyoutmi raily)');
})();

console.log('OK test_d130a_suhrn_karta.js — ' + n + ' kontrol');
