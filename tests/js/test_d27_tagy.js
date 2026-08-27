// Testy D-27 „Rýchle zobraziť/skryť tagy modelu z panela".
//
// Okno tagov v raile Inspectora kresli CISTY modul (ui/js/tag_menu.js) —
// dostane serverovy stav, vrati markup. Testy stoja na tom, co je na tom
// rizikove:
//   1) riadky su LEN za tagy, ktore server poslal (D-78 — mrtve tlacidlo je
//      horsie nez ziadne), a prazdny zoznam sa PRIZNA vetou, nie mlcanim,
//   2) rozhodovanie o ikone raily je cista funkcia (svieti, ked nieco nevidno),
//   3) payload do Ruby je identita + kluc + STRIKTNY boolean,
//   4) skryty PRIECINOK tagov sa prizna (tag je zapnuty, vidiet ho aj tak nie),
//   5) panel si ziadny vlastny stav nedrzi a checkbox ghost zon ide TOU ISTOU
//      cestou (jeden zdroj, dva ovladace),
//   6) texty ani kluce sa neopisuju do shell.js.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

global.window = {};
const ROOT = path.join(__dirname, '..', '..');
const M = require(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'tag_menu.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function no(cond, msg){ n++; assert.ok(!cond, msg); }

function row(key, label, visible, folder){
  return { key: key, label: label, name: 'Noxun/' + label, visible: visible,
           folder_hidden: folder === true };
}
function state(rows, hidden){
  return { rows: rows, hidden: hidden == null ? rows.filter(function(r){
    return !r.visible || r.folder_hidden; }).length : hidden };
}

// --- 1) riadky su LEN za tagy zo servera --------------------------------------
(function(){
  const st = state([row('cela', 'Čelá', true), row('chrbat', 'Chrbát', false)]);
  const h = M.menuHtml(st, true, {});
  ok(h.indexOf('<span>Čelá</span>') >= 0, 'riadok Čelá je v ponuke');
  ok(h.indexOf('<span>Chrbát</span>') >= 0, 'riadok Chrbát je v ponuke');
  no(h.indexOf('<span>Kovanie</span>') >= 0, 'tag, ktory v modeli NIE JE, sa neponuka (D-78)');
  eq((h.match(/type="checkbox"/g) || []).length, 2, 'jeden checkbox na riadok');
  ok(h.indexOf('checked') >= 0, 'viditelny tag je zaskrtnuty');
  eq((h.match(/ checked/g) || []).length, 1, 'skryty tag zaskrtnuty NIE JE');
  ok(h.indexOf('tgmenu open') >= 0, 'otvorene okno ma triedu open');
  ok(h.indexOf('id="railTagsMenu"') >= 0, 'okno ma svoje id');
  ok(h.indexOf("onTagOption('cela', this.checked)") >= 0, 'klik posiela KLUC, nie meno tagu');
  // Review #249 P3: identita riadku pre vratenie FOKUSU po prekresleni okna.
  ok(h.indexOf('data-tagkey="cela"') >= 0, 'riadok nesie identitu pre navrat fokusu');
  eq((h.match(/data-tagkey=/g) || []).length, 2, 'kazdy riadok ma svoju identitu');
  no(M.menuHtml(st, false, {}).indexOf(' open"') >= 0, 'zatvorene okno triedu open nema');
})();

(function(){
  const h = M.menuHtml(state([]), true, {});
  ok(h.indexOf('Zatiaľ tu nie sú žiadne NOXUN tagy') >= 0,
     'prazdny zoznam sa PRIZNA vetou (nie prazdne okno bez vysvetlenia)');
  no(h.indexOf('type="checkbox"') >= 0, 'a neponuka ziadny prepinac');
  ok(M.menuHtml(null, true, {}).indexOf('tgempty') >= 0, 'chybajuci stav sa sprava rovnako');
  ok(M.menuHtml(undefined, true, {}).indexOf('tgmenu') >= 0, 'a nepada');
})();

// --- 2) ikona raily -----------------------------------------------------------
(function(){
  const empty = M.railState(state([]));
  eq(empty.empty, true, 'bez NOXUN tagov je zoznam prazdny');
  eq(empty.on, false, 'a ikona nesvieti');
  eq(empty.icon, 'eye', 'zakladna ikona je oko');
  ok(empty.tip.indexOf('nie sú NOXUN tagy') >= 0, 'bublina to povie aj z hoveru');

  const allOn = M.railState(state([row('cela', 'Čelá', true), row('dosky', 'Dosky', true)]));
  eq(allOn.empty, false, 'tagy su');
  eq(allOn.on, false, 'ked je vsetko vidno, ikona nesvieti');
  eq(allOn.icon, 'eye', 'a ostava oko');

  const some = M.railState(state([row('cela', 'Čelá', false), row('dosky', 'Dosky', true)]));
  eq(some.on, true, 'nieco je skryte — ikona svieti („nevidis vsetko")');
  eq(some.icon, 'eye-off', 'a prepne sa na preskrtnute oko');
  ok(some.tip.indexOf('skrytých je 1 z 2') >= 0, 'bublina nesie POCET zo servera');

  // Review #249 P2: prazdny model tlacidlo NEZAMYKA — okno sa otvori a vysvetli.
  const shell = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), 'utf8');
  const tagPart0 = shell.slice(shell.indexOf('D-27: OKNO VIDITELNOSTI TAGOV'),
                               shell.indexOf('K2/D-87: to iste pre KONTROLU KRESBY'));
  no(tagPart0.indexOf("setAttribute('aria-disabled'") >= 0,
     'tlacidlo tagov sa nezosedne — inak by bolo vysvetlenie prazdneho zoznamu nedosiahnutelne');
  no(tagPart0.indexOf("getAttribute('aria-disabled')") >= 0, 'a klik sa neodmieta');
})();

(function(){
  // Pocet skrytych POCITA SERVER — klient ho len tolerantne precita.
  eq(M.hiddenCount({ hidden: 3 }), 3, 'cislo zo servera');
  eq(M.hiddenCount({}), 0, 'chybajuce cislo = 0');
  eq(M.hiddenCount(null), 0, 'bez stavu = 0');
  eq(M.hiddenCount({ hidden: 'x' }), 0, 'nezmysel sa neprepocitava na NaN');
})();

// --- 3) payload do Ruby -------------------------------------------------------
(function(){
  eq(M.togglePayload({ model_guid: 'G-1' }, 'cela', true),
     { model_guid: 'G-1', key: 'cela', value: true },
     'klient posiela identitu dokumentu + kluc + boolean');
  eq(M.togglePayload({ model_guid: 'G-1' }, 'cela', 'true').value, false,
     'nebooleovska hodnota sa NEPOSLE ako true (server ju aj tak odmietne)');
  eq(M.togglePayload(null, null, false), { model_guid: '', key: '', value: false },
     'bez dat sa nepada');
  no(Object.keys(M.togglePayload({}, 'cela', true)).indexOf('name') >= 0,
     'meno tagu sa NEPOSIELA spat — je to zobrazovaci udaj');
  no(Object.keys(M.togglePayload({}, 'cela', true)).indexOf('rows') >= 0,
     'klient neposiela cely stav — meni sa vzdy jeden kluc');
})();

// --- 4) skryty priecinok tagov sa prizna --------------------------------------
(function(){
  const st = state([row('cela', 'Čelá', true, true)]);
  const h = M.menuHtml(st, true, {});
  ok(h.indexOf('priečinok skrytý') >= 0,
     'tag je zapnuty, ale v modeli ho vidiet nie je — povedz to nahlas');
  ok(h.indexOf(' checked') >= 0, 'vlastna viditelnost tagu ostava zaskrtnuta');
  eq(M.railState(st).on, true, 'ikona svieti aj vtedy, ked tag blokuje priecinok');
  no(M.menuHtml(state([row('cela', 'Čelá', true)]), true, {}).indexOf('priečinok skrytý') >= 0,
     'bez priecinka sa poznamka nekresli');
})();

// --- 5) escapovanie -----------------------------------------------------------
(function(){
  const h = M.menuHtml(state([row('x', '<b>hack</b>&"', true)]), true, {});
  no(h.indexOf('<b>hack</b>') >= 0, 'popis z payloadu sa escapuje (nikdy holy innerHTML)');
  ok(h.indexOf('&lt;b&gt;hack&lt;/b&gt;') >= 0, 'a je vidiet ako text');
})();

// --- 6) panel si nic nedrzi, checkbox ide TOU ISTOU cestou --------------------
(function(){
  const shell = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'shell.js'), 'utf8');
  ok(shell.indexOf('NXTagMenu.menuHtml') >= 0, 'rail kresli okno zdielanym modulom');
  ok(shell.indexOf('NXTagMenu.railState') >= 0, 'a rozhodovanie o ikone berie z neho');
  no(shell.indexOf('Chrbát') >= 0, 'shell.js si nazvy tagov NEVYMYSLA');
  ok(shell.indexOf('sketchup.nx_tag_visible') >= 0, 'zapis ide cez server');
  // Cast raily patriaca tagom nesmie mat vlastnu pamat — stav je serverovy.
  // (shell.js localStorage pouziva, ale na zbalenia sektorov, nie na tagy.)
  const tagPart = shell.slice(shell.indexOf('D-27: OKNO VIDITELNOSTI TAGOV'),
                              shell.indexOf('K2/D-87: to iste pre KONTROLU KRESBY'));
  ok(tagPart.length > 500, 'cast raily s tagmi sa nasla');
  no(tagPart.indexOf('localStorage') >= 0, 'viditelnost tagu patri modelu, nie prehliadacu');
  no(tagPart.indexOf('start_operation') >= 0, 'klient o operaciach nerozhoduje');
  // Review #249 P3: fokus prezije prekreslenie otvoreneho okna.
  ok(tagPart.indexOf('data-tagkey') >= 0, 'fokus sa vracia podla identity riadku');
  ok(tagPart.indexOf('function nxTagFocusKey') >= 0, 'zapamatanie fokusu ma vlastnu funkciu');
  ok(tagPart.indexOf('back.focus()') >= 0, 'a fokus sa po prekresleni naozaj vracia');

  const actions = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'actions.js'), 'utf8');
  ok(actions.indexOf('sketchup.nx_tag_visible') >= 0,
     'checkbox ghost zon ide TOU ISTOU cestou ako okno tagov');
  no(actions.indexOf('sketchup.toggle_zones') >= 0,
     'stary callback bez identity dokumentu zanikol');

  const bridge = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'js', 'bridge.js'), 'utf8');
  ok(bridge.indexOf('setTags: function') >= 0, 'push kanal existuje');
  ok(bridge.indexOf('nxApplyTags(data.tags)') >= 0, 'PULL pri otvoreni panela');
  no(bridge.indexOf('data.zones_visible') >= 0, 'druhy zdroj pravdy o zonach zanikol');

  const html = fs.readFileSync(path.join(ROOT, 'noxun_engine', 'ui', 'panel.html'), 'utf8');
  ok(html.indexOf('js/tag_menu.js') >= 0, 'panel modul naozaj nacitava');
  ok(html.indexOf('js/tag_menu.js') < html.indexOf('js/shell.js'),
     'poradie skriptov: modul musi byt skor nez shell, ktory ho vola');
})();

console.log(`test_d27_tagy.js: ${n} testov OK`);
