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

// Rozbalovacie nastavenie Studia (ecMenu) — to isté pravidlo.
reset();
open('mdDeleteModal');
W.ecMenuOpen = true;
r = esc();
ok(isOpen('mdDeleteModal'), 'otvorene rozbalovacie nastavenie: modal pod nim ostava');
ok(!r.consumed && r.after === 1, 'Escape pusti retaz dalej — nastavenie zavrie Studio');
eq(NXEsc.blockedBy(), 'ecMenuOpen', 'blockedBy() menuje ecMenu');
// Druhe stlacenie (uz bez menu) modal zavrie — vrstvy sa lupu po jednej.
W.ecMenuOpen = false;
r = esc();
ok(!isOpen('mdDeleteModal') && r.consumed, 'druhe stlacenie zavrie uz modal');

// Prekryvne ovladace Inspectora (warnpanel, rohove menu ABS, tagy).
['warnPanelOpen', 'nxEdgeMenuOpen', 'nxTagMenuOpen'].forEach(function(name){
  reset();
  open('absModal');
  W[name] = function(){ return true; };
  const rr = esc();
  ok(isOpen('absModal') && !rr.consumed, name + ': Escape patri prekryvnemu ovladacu, nie modalu');
  eq(NXEsc.blockedBy(), name, 'blockedBy() menuje ' + name);
});

// Otvoreny combobox materialov (D-85) — Escape zatvara ponuku, nie modal.
reset();
open('mdUniModal');
W.NXCombo = { isOpen: function(){ return true; } };
r = esc();
ok(isOpen('mdUniModal') && !r.consumed, 'otvorena ponuka comboboxu: modal ostava');

// Rucne modaly, ktore uz vlastny Escape MAJU, retaz neprebera.
['nxdaModal', 'tplModal', 'simModal', 'cfgModal'].forEach(function(id){
  reset();
  open('absModal');
  open(id);
  const rr = esc();
  ok(isOpen(id), id + ' ma vlastny Escape — retaz ho nezatvara');
  ok(isOpen('absModal') && !rr.consumed, 'a modal pod nim tiez nie (jedno stlacenie, jedna vrstva)');
});

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
ok(NXEsc.FOREIGN_IDS.indexOf('budPrModal') > -1, 'a JE v zozname cudzich vrstiev');

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
NXEsc.FOREIGN_FLAGS.forEach(function(flag){
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

console.log('OK test_r23_escape.js — ' + n + ' kontrol');
