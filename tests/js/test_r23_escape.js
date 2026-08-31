// R-23.1 — ESCAPE RETAZ RUCNYCH MODALOV (`ui/js/nx_esc.js`).
//
// Preco su to testy a nie klikanie:
//   1. Sest rucnych modalov (`absModal` v Inspectorovi + pat studiovych) nemalo
//      Escape VOBEC — kontrakt UI 2.0 „Escape zatvara modal" pre ne neplatil.
//      Ze plati DNES, sa da overit len tym, ze sa udalost naozaj posle.
//   2. Escape listenery visia na `document` a `stopPropagation` medzi nimi
//      NEFUNGUJE. Bez `stopImmediatePropagation` by jedno stlacenie zavrelo
//      modal AJ rozbalovacie nastavenie Studia — to sa da chytit iba BUBLANIM
//      (preto mini-DOM, ktory poradie poslucháčov dokumentu naozaj dodrziava).
//   3. `budPrModal` (fazove okno prepoctu cien) sa vo faze `run` zavriet NESMIE
//      — beh na serveri by ostal visiet bez okna (kontrakt nx_modal.js,
//      audit #9). Je to tichy, drahy regres: viditelny az ked niekto stlaci
//      Escape nad bezucim stahovanim cien.
//   4. Escape musi volat TU ISTU funkciu ako tlacidlo „Zrusit" — `mddCancel`
//      rusi bezuci Demos fetch, `absModalChoose('cancel')` vracia povodnu
//      hodnotu selectu. Holy `display:none` by spravil klavesnicu inou nez mys.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const UI = path.join(__dirname, '..', '..', 'noxun_engine', 'ui');
const W = global.window;

// --- scena: vsetkych sest modalov + cudzie vrstvy, vsetky zatvorene ---------
const NODES = {};
['absModal', 'demosModal', 'mdUniModal', 'mdDeleteModal', 'mdRestoreModal', 'hwDelModal',
 'nxdaModal', 'tplModal', 'simModal', 'cfgModal'].forEach(function(id){
  const el = mkEl('div');
  el.attrs.id = id;
  el.style.display = 'none';
  const inner = mkEl('button');           // fokusovatelny obsah karty
  el.appendChild(inner);
  DOC.body.appendChild(el);
  NODES[id] = el;
});

// `budPrModal` v DOM NEEXISTUJE, kym nie je otvoreny (budget.js ho vytvara
// a odstranuje) — zavedieme ho az tam, kde ho testujeme.
function openBudPr(){
  const el = mkEl('div');
  el.attrs.id = 'budPrModal';
  DOC.body.appendChild(el);               // ziadny `style.display` — presne ako v okne
  return el;
}
function closeBudPr(el){
  DOC.body.children = DOC.body.children.filter(function(c){ return c !== el; });
}

function open(id){ NODES[id].style.display = id === 'absModal' ? 'flex' : ''; }
function closeAll(){
  Object.keys(NODES).forEach(function(id){ NODES[id].style.display = 'none'; });
}
function isOpen(id){ return NODES[id].style.display !== 'none'; }

// --- stuby zatvaracich funkcii (v okne su to top-level globaly skriptov) ----
const CALLS = [];
function stub(name, id){
  W[name] = function(arg){
    CALLS.push(arg === undefined ? name : name + ':' + arg);
    if (id) NODES[id].style.display = 'none';
  };
}
stub('absModalChoose', 'absModal');
stub('mddCancel', 'demosModal');
stub('mdUniClose', 'mdUniModal');
stub('mdDeleteClose', 'mdDeleteModal');
stub('mdRestoreClose', 'mdRestoreModal');
stub('hwDelClose', 'hwDelModal');

const NXEsc = require(path.join(JS, 'nx_esc.js'));

// Poslucháč ZA nami — zastupuje dokumentovy Escape handler Studia (`ecMenu`,
// `vepoMenu`). Ked retaz udalost spotrebuje, tento sa uz spustit NESMIE.
let afterHits = 0;
DOC.addEventListener('keydown', function(ev){ if (ev.key === 'Escape') afterHits++; });

function esc(){
  const before = afterHits;
  const ev = dispatch(NODES.absModal.children[0], 'keydown', { key: 'Escape' });
  return { consumed: !!ev._immediate, prevented: !!ev._prevented, after: afterHits - before };
}

function reset(){
  closeAll();
  CALLS.length = 0;
  delete W.NXModal;
  delete W.NXCombo;
  delete W.warnPanelOpen;
  delete W.nxEdgeMenuOpen;
  delete W.nxTagMenuOpen;
  W.ecMenuOpen = false;
  W.vepoMenuOpen = false;
}

// ============ 1) ESCAPE ZATVARA KAZDY ZO SIESTICH MODALOV ===================

[['absModal', 'absModalChoose:cancel'],
 ['demosModal', 'mddCancel'],
 ['mdUniModal', 'mdUniClose'],
 ['mdDeleteModal', 'mdDeleteClose'],
 ['mdRestoreModal', 'mdRestoreClose'],
 ['hwDelModal', 'hwDelClose']].forEach(function(pair){
  reset();
  open(pair[0]);
  const r = esc();
  ok(!isOpen(pair[0]), 'Escape zatvara ' + pair[0]);
  eq(CALLS, [pair[1]], pair[0] + ': Escape vola TU ISTU cestu ako tlacidlo Zrusit');
  ok(r.consumed, pair[0] + ': udalost sa SPOTREBUJE (stopImmediatePropagation)');
  ok(r.prevented, pair[0] + ': `preventDefault` — Escape uz nema robit nic ine');
  eq(r.after, 0, pair[0] + ': handler ZA nami sa uz nespusti — jedno stlacenie = jedna vrstva');
});

// `absModal` je VYBEROVY modal: Escape musi zodpovedat volbe „Zrusit"
// (revert selectu), nie „Vytvorit" ani „Bez ABS" — inak by klavesnica ticho
// zakladala ABS pasku v GLOBALNOM katalogu.
reset();
open('absModal');
esc();
eq(CALLS, ['absModalChoose:cancel'], 'absModal: Escape = volba `cancel`, nikdy `create`/`without`');

// ============ 2) ZATVARA SA NAJVYSSIA VRSTVA, NIKDY DVE NARAZ ===============

// Kostra D-15 (NXModal) je NAD nami — Escape patri jej, modal pod nou ostava.
reset();
open('mdUniModal');
W.NXModal = { isOpen: function(){ return true; } };
let r = esc();
ok(isOpen('mdUniModal'), 'otvoreny NXModal: modal POD nim sa Escapom nezatvara');
eq(CALLS, [], 'a nevola sa ziadna zatvaracia funkcia');
ok(!r.consumed, 'udalost sa nespotrebuje — musi doletiet ku kostre D-15');
eq(r.after, 1, 'handler okna ju teda dostane');
eq(NXEsc.blockedBy(), 'NXModal', 'blockedBy() menuje vrstvu, ktora Escape drzi');

// --- FLYOUTY A MENU: blokuju len vtedy, ked pod nimi NIE JE nas modal -------
// Review #273 kolo 1 (P2): rohove menu ABS, warnpanel, ecMenu/vepoMenu aj
// combobox ziju v stacking kontexte raila/listy (z-index 55 a nizsie), kdezto
// `.nxmodal` je 60 — takze pod otvorenym modalom su SCHOVANE. Keby blokovali aj
// vtedy, prve stlacenie Escape by zavrelo neviditelnu vrstvu a pouzivatel by
// musel stlacit dvakrat.

// Bez modalu blokuju: Escape patri im a retaz ho pusta dalej ich vlastnikovi.
['warnPanelOpen', 'nxEdgeMenuOpen', 'nxTagMenuOpen'].forEach(function(name){
  reset();
  W[name] = function(){ return true; };
  const rr = esc();
  ok(!rr.consumed && rr.after === 1, name + ': bez modalu Escape patri prekryvnemu ovladacu');
  eq(NXEsc.blockedBy(), name, 'blockedBy() menuje ' + name);
});
reset();
W.ecMenuOpen = true;
r = esc();
ok(!r.consumed && r.after === 1, 'ecMenu bez modalu: Escape pusti retaz dalej — nastavenie zavrie Studio');
eq(NXEsc.blockedBy(), 'ecMenuOpen', 'blockedBy() menuje ecMenu');
reset();
W.NXCombo = { isOpen: function(){ return true; } };
r = esc();
ok(!r.consumed && r.after === 1, 'combobox bez modalu: Escape zatvara ponuku');
eq(NXEsc.blockedBy(), 'NXCombo', 'blockedBy() menuje combobox');

// PRESNA SCENA NALEZU: rohove menu ABS ostane otvorene pod `absModal`
// (klavesnicova cesta menu → combobox → dekor bez pouzitelnej pasky).
// PRVE stlacenie musi zavriet VIDITELNY modal, nie schovane menu.
reset();
W.nxEdgeMenuOpen = function(){ return true; };
open('absModal');
eq(NXEsc.blockedBy(), null, 'otvoreny modal je nad flyoutom — nic retaz nedrzi');
r = esc();
ok(!isOpen('absModal'), 'prve stlacenie zavrie VIDITELNY modal, nie schovane rohove menu');
eq(CALLS, ['absModalChoose:cancel'], 'a to cestou „Zrusit" (revert selectu)');
ok(r.consumed && r.after === 0, 'udalost sa spotrebuje — menu sa v tom istom stlaceni NEZATVARA');
// Druhe stlacenie uz patri menu (modal je prec) — retaz ho pusta do boot.js.
r = esc();
eq(NXEsc.blockedBy(), 'nxEdgeMenuOpen', 'po zavreti modalu drzi Escape uz rohove menu');
ok(!r.consumed && r.after === 1, 'druhe stlacenie doleti k jeho vlastnikovi');

// To iste pre priznak Studia aj combobox — jeden modal, jedno stlacenie.
reset();
open('mdDeleteModal');
W.ecMenuOpen = true;
r = esc();
ok(!isOpen('mdDeleteModal') && r.consumed && r.after === 0,
   'ecMenu pod modalom: prve stlacenie zavrie modal');
reset();
open('mdUniModal');
W.NXCombo = { isOpen: function(){ return true; } };
r = esc();
ok(!isOpen('mdUniModal') && r.consumed, 'combobox pod modalom: prve stlacenie zavrie modal');

// Rucne modaly, ktore uz vlastny Escape MAJU, retaz neprebera.
['nxdaModal', 'tplModal', 'simModal', 'cfgModal'].forEach(function(id){
  reset();
  open('absModal');
  open(id);
  const rr = esc();
  ok(isOpen(id), id + ' ma vlastny Escape — retaz ho nezatvara');
  ok(isOpen('absModal') && !rr.consumed, 'a modal pod nim tiez nie (jedno stlacenie, jedna vrstva)');
});

// --- DVE VLASTNE VRSTVY NARAZ: rozhoduje DOKUMENTOVE PORADIE, nie tabulka ---
// Review #273 kolo 2 (P2): scenar zo Studia — preflight zmazania materialu uz
// odosiel, pouzivatel prepne sekciu na Kovanie a otvori `hwDelModal`; oneskorena
// odpoved `MD.confirmDelete` otvori `mdDeleteModal` POD nim. Oba maju z-index 60,
// takze VIDIET je ten, ktory je v HTML nizsie — a prave ten musi Escape zavriet.
// Podla poradia tabulky OWN by sa zavrel skryty materialovy a navonok by sa
// „nestalo nic".
reset();
open('mdDeleteModal');                    // v tabulke SKOR, v DOM VYSSIE
open('hwDelModal');                       // v DOM NIZSIE = kresli sa navrch
eq(NXEsc.topOpen().id, 'hwDelModal', 'topOpen() menuje ten, ktory je v DOM posledny');
r = esc();
ok(!isOpen('hwDelModal'), 'Escape zavrel VIDITELNY modal kovania');
ok(isOpen('mdDeleteModal'), 'a materialovy pod nim ostal otvoreny');
eq(CALLS, ['hwDelClose'], 'volala sa jeho vlastna zatvaracia cesta');
ok(r.consumed && r.after === 0, 'jedno stlacenie = jedna vrstva');
r = esc();
ok(!isOpen('mdDeleteModal') && r.consumed, 'druhe stlacenie zavrie uz ten spodny');

// ============ 3) `budPrModal` — ESCAPE SA HO NESMIE DOTKNUT ================
// Fazove okno prepoctu cien riadi SERVER. Vo faze `run` by zatvorenie nechalo
// beh visiet bez okna, takze retaz pri nom NEROBI NIC — ani sebe pod nim.

reset();
let bud = openBudPr();
r = esc();
ok(DOC.getElementById('budPrModal') !== null, 'budPrModal Escape NEZATVARA (faza run)');
ok(!r.consumed, 'a udalost nespotrebuje — okno si ju riesi samo');
eq(NXEsc.blockedBy(), 'budPrModal', 'blockedBy() menuje budPrModal');
open('mdDeleteModal');
esc();
ok(isOpen('mdDeleteModal'), 'ani modal POD budPrModalom sa nezavrie');
closeBudPr(bud);
eq(NXEsc.blockedBy(), null, 'po zaniku okna uz retaz nic nedrzi');
ok(NXEsc.OWN.every(function(l){ return l.id !== 'budPrModal'; }),
   'budPrModal NIE JE vo vlastnych vrstvach retaze');
ok(NXEsc.FOREIGN_MODAL_IDS.indexOf('budPrModal') > -1, 'a JE v zozname cudzich MODALOV');
ok(NXEsc.FLYOUT_FNS.indexOf('budPrModal') === -1 && NXEsc.FLYOUT_FLAGS.indexOf('budPrModal') === -1,
   'a nie medzi flyoutmi — tie modal pod sebou prepustaju, budPrModal nikdy');

// ============ 4) DROBNOSTI KONTRAKTU =======================================

reset();
open('absModal');
r = (function(){
  const before = afterHits;
  const ev = dispatch(NODES.absModal.children[0], 'keydown', { key: 'Enter' });
  return { consumed: !!ev._immediate, after: afterHits - before };
})();
ok(isOpen('absModal') && !r.consumed, 'ina klavesa nez Escape retaz nezaujima');

reset();
r = esc();
ok(!r.consumed && r.after === 1, 'ked nie je otvoreny ziadny modal, Escape ide dalej nedotknuty');
eq(NXEsc.topOpen(), null, 'topOpen() bez otvoreneho modalu je null');

// Chybajuca zatvaracia funkcia (okno, kde skript modalu nie je nacitany)
// nesmie udalost spotrebovat — inak by Escape „zhltol" a nic neurobil.
reset();
open('hwDelModal');
const savedHwClose = W.hwDelClose;
delete W.hwDelClose;
r = esc();
ok(isOpen('hwDelModal') && !r.consumed, 'bez zatvaracej funkcie sa udalost nespotrebuje');
W.hwDelClose = savedHwClose;

// ============ 5) ZDROJOVE GUARDY — retaz visi na MENACH z inych suborov =====
// Retaz vola globaly deklarovane v skriptoch okien. Premenovanie by ju ticho
// odpojilo (v JS neexistujuci global nie je chyba), preto sa mena kontroluju
// proti zdrojom.

const SRC = {
  'absModalChoose': fs.readFileSync(path.join(JS, 'form.js'), 'utf8'),
  'mddCancel': fs.readFileSync(path.join(JS, 'demos_diff.js'), 'utf8'),
  'mdUniClose': fs.readFileSync(path.join(JS, 'proj_materials.js'), 'utf8'),
  'mdDeleteClose': fs.readFileSync(path.join(JS, 'proj_materials.js'), 'utf8'),
  'mdRestoreClose': fs.readFileSync(path.join(JS, 'proj_materials.js'), 'utf8'),
  'hwDelClose': fs.readFileSync(path.join(JS, 'hw_catalog.js'), 'utf8')
};
NXEsc.OWN.forEach(function(layer){
  const src = SRC[layer.fn];
  ok(!!src, 'zdroj pre ' + layer.fn + ' je znamy');
  ok(src.indexOf('function ' + layer.fn + '(') > -1,
     layer.fn + ' existuje ako top-level funkcia (retaz ju vola menom)');
});

const STUDIO_JS = fs.readFileSync(path.join(JS, 'studio.js'), 'utf8');
NXEsc.FLYOUT_FLAGS.forEach(function(flag){
  ok(STUDIO_JS.indexOf('var ' + flag) > -1,
     flag + ' je top-level priznak studio.js (retaz ho cita cez window)');
});

// Porovnava sa poloha SKRIPT TAGOV, nie zmienok — mena suborov su aj v komentaroch.
function tagAt(html, file){ return html.indexOf('src="js/' + file + '.js'); }
const PANEL_HTML = fs.readFileSync(path.join(UI, 'panel.html'), 'utf8');
const STUDIO_HTML = fs.readFileSync(path.join(UI, 'studio.html'), 'utf8');
ok(PANEL_HTML.indexOf('js/nx_esc.js') > -1, 'panel.html nacitava zdielanu retaz');
ok(STUDIO_HTML.indexOf('js/nx_esc.js') > -1, 'studio.html nacitava TU ISTU retaz');
ok(tagAt(STUDIO_HTML, 'nx_esc') > -1 && tagAt(STUDIO_HTML, 'nx_esc') < tagAt(STUDIO_HTML, 'nx_modal'),
   'poradie skriptov: nx_esc.js PRED nx_modal.js');
ok(tagAt(STUDIO_HTML, 'nx_esc') < tagAt(STUDIO_HTML, 'studio'),
   'a PRED studio.js — jeho listener musi bezat prvy, aby vedel udalost spotrebovat');
ok(tagAt(PANEL_HTML, 'nx_esc') > -1 && tagAt(PANEL_HTML, 'nx_esc') < tagAt(PANEL_HTML, 'form'),
   'v Inspectorovi PRED form.js (absModal)');

// Predpoklad scenara „dve vlastne vrstvy naraz": v `studio.html` je `hwDelModal`
// (sekcia Kovanie, `#hwModalRoot`) naozaj NIZSIE nez `mdDeleteModal` (`#matModalRoot`),
// takze pri zhodnom z-index sa kresli navrch. Keby sa markup prehodil, prehodi sa
// aj to, co ma Escape zatvorit — a test scenara vyssie by tvrdil nepravdu.
ok(STUDIO_HTML.indexOf('id="mdDeleteModal"') < STUDIO_HTML.indexOf('id="hwDelModal"'),
   'studio.html: hwDelModal je v dokumentovom poradi ZA mdDeleteModal');

// Predpoklad, na ktorom stoji zaradenie comboboxu medzi FLYOUTY (trieda b):
// v ziadnom z tych siestich modalov `select[data-nx-combo]` NIE JE, takze
// otvorena ponuka (`.cbpop`, z-index 120) nad nimi vzniknut nema ako. Keby tam
// combobox raz pribudol, patri medzi cudzie MODALY — inak by Escape zavrel
// modal aj s otvorenou ponukou nad nim.
function modalMarkup(html, id){
  const clean = html.replace(/<!--[\s\S]*?-->/g, '');
  const start = clean.indexOf('<div id="' + id + '"');
  if (start < 0) return null;
  const re = /<(\/?)div\b[^>]*>/g;
  re.lastIndex = start;
  let m, depth = 0;
  while ((m = re.exec(clean)) !== null){
    depth += m[1] ? -1 : 1;
    if (depth === 0) return clean.slice(start, re.lastIndex);
  }
  return null;
}
NXEsc.OWN.forEach(function(layer){
  const html = layer.id === 'absModal' ? PANEL_HTML : STUDIO_HTML;
  const markup = modalMarkup(html, layer.id);
  ok(!!markup, layer.id + ': markup modalu sa nasiel');
  eq(markup.indexOf('data-nx-combo'), -1,
     layer.id + ' nema combobox D-85 — combobox smie byt vo flyoutoch');
});

console.log('OK test_r23_escape.js — ' + n + ' kontrol');
