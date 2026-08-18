// Testy UI-01: mechanizmus temy panela (NOXUN / Lucia) — ciste jadro
// win_fit.js (nxThemeName / nxThemeApply). Dependency-free Node:
//   node tests/js/test_ui01_tema.js
// Kontrakt (rozhodnutie O4, docs/UI_DIZAJN.md sekcia „Temy"):
//   - tema meni VYHRADNE vyberovu rodinu tokenov (8 tokenov --nx-select* a
//     --nx-part-*); vyznamove farby (danger/warn/ok/ABS/edge/semafor) NIKDY,
//   - neznama / prazdna / nesprava hodnota = zakladna tema 'noxun'
//     (rovnaky fallback ma Ruby strana — Engine.normalize_ui_theme),
//   - prepnutie spat na NOXUN musi ZHODIT vsetky temove prepisy (ziadne zvysky).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');
const { nxThemeName, nxThemeApply, NX_THEME_TOKENS, NX_THEME_DEFAULT } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'win_fit.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// Minimalna nahrada documentElement — drzi inline style premenne.
function fakeRoot(){
  const props = {};
  const attrs = {};
  return {
    props: props,
    attrs: attrs,
    style: {
      setProperty: function(k, v){ props[k] = v; },
      removeProperty: function(k){ delete props[k]; }
    },
    setAttribute: function(k, v){ attrs[k] = v; }
  };
}

// --- meno temy: tolerantne citanie -------------------------------------------
eq(nxThemeName('noxun'), 'noxun', 'zakladna tema');
eq(nxThemeName('lucia'), 'lucia', 'tema Lucia');
eq(nxThemeName('  LUCIA  '), 'lucia', 'medzery a velke pismena nevadia');
eq(nxThemeName('Noxun'), 'noxun', 'velke pismeno v zakladnej teme');
eq(nxThemeName('modra'), NX_THEME_DEFAULT, 'neznama tema = zakladna');
eq(nxThemeName(''), NX_THEME_DEFAULT, 'prazdna hodnota = zakladna');
eq(nxThemeName(null), NX_THEME_DEFAULT, 'null = zakladna');
eq(nxThemeName(undefined), NX_THEME_DEFAULT, 'undefined = zakladna');
eq(nxThemeName(42), NX_THEME_DEFAULT, 'cislo = zakladna');
eq(nxThemeName({}), NX_THEME_DEFAULT, 'objekt = zakladna');
eq(nxThemeName('constructor'), NX_THEME_DEFAULT,
   'dediene kluce Objectu nie su temy (hasOwnProperty guard)');

// --- rozsah temy: presne 8 tokenov vyberovej rodiny ---------------------------
const LUCIA_KEYS = Object.keys(NX_THEME_TOKENS.lucia).sort();
eq(LUCIA_KEYS, ['--nx-part-bg', '--nx-part-border', '--nx-select', '--nx-select-accent',
                '--nx-select-bg', '--nx-select-bg-hover', '--nx-select-bg-soft',
                '--nx-select-strong'],
   'tema prepisuje presne vyberovu rodinu (8 tokenov)');
eq(Object.keys(NX_THEME_TOKENS.noxun), [],
   'zakladna tema nema prepisy — jej hodnoty su v :root');

LUCIA_KEYS.forEach(function(k){
  ok(/^#[0-9a-f]{6}$/i.test(NX_THEME_TOKENS.lucia[k]), `hodnota ${k} je plny hex`);
});
['--nx-danger', '--nx-warn', '--nx-ok-bg', '--nx-abs-1mm', '--nx-abs-2mm',
 '--nx-edge-missing', '--nx-edge-extra', '--nx-edge-taped',
 '--nx-state-red', '--nx-state-orange', '--nx-state-green', '--nx-action'].forEach(function(k){
  ok(!Object.prototype.hasOwnProperty.call(NX_THEME_TOKENS.lucia, k),
     `vyznamovy token ${k} sa temou NIKDY nemeni`);
});

// --- aplikacia na koren dokumentu --------------------------------------------
(function(){
  const root = fakeRoot();
  eq(nxThemeApply('lucia', root), 'lucia', 'apply vracia meno pouzitej temy');
  eq(root.props['--nx-select'], '#c2185b', 'Lucia nasadila ruzovy akcent');
  eq(root.props['--nx-part-bg'], '#fff5f9', 'Lucia nasadila pozadie karty dielca');
  eq(Object.keys(root.props).sort(), LUCIA_KEYS, 'nasadila sa PRESNE vyberova rodina');
  eq(root.attrs['data-nx-theme'], 'lucia', 'koren nesie meno temy v atribute');
})();

(function(){
  const root = fakeRoot();
  nxThemeApply('lucia', root);
  eq(nxThemeApply('noxun', root), 'noxun', 'navrat na zakladnu temu');
  eq(Object.keys(root.props), [], 'prepnutie spat ZHODI vsetky ruzove prepisy');
  eq(root.attrs['data-nx-theme'], 'noxun', 'atribut sa prepise spat');
})();

(function(){
  const root = fakeRoot();
  nxThemeApply('lucia', root);
  nxThemeApply('cudzia-hodnota', root);
  eq(Object.keys(root.props), [], 'neznama hodnota sa sprava ako zakladna tema');
  eq(root.attrs['data-nx-theme'], 'noxun', 'a aj tak sa oznaci');
})();

(function(){
  // Okno bez korena (napr. volanie pred nacitanim DOM) nesmie spadnut.
  eq(nxThemeApply('lucia', { style: null }), 'lucia', 'chybajuci style nezhodi okno');
})();

// --- zrkadlo: hodnoty zakladnej temy zijú v panel.css -------------------------
(function(){
  const css = fs.readFileSync(
    path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'css', 'panel.css'), 'utf8');
  const root = css.slice(css.indexOf(':root'), css.indexOf('* { box-sizing'));
  const TEAL = {
    '--nx-select': '#107787', '--nx-select-strong': '#0B5661',
    '--nx-select-accent': '#0e6b7a', '--nx-select-bg': '#e0f2f4',
    '--nx-select-bg-soft': '#f0f9fa', '--nx-select-bg-hover': '#d6eef1',
    '--nx-part-border': '#7fc4cf', '--nx-part-bg': '#f2fafb'
  };
  Object.keys(TEAL).forEach(function(k){
    const m = new RegExp(k.replace(/-/g, '\\-') + '\\s*:\\s*([^;]+);').exec(root);
    ok(m && m[1].trim().toLowerCase() === TEAL[k].toLowerCase(),
       `panel.css :root ma ${k}: ${TEAL[k]} (NOXUN teal)`);
    ok(Object.prototype.hasOwnProperty.call(NX_THEME_TOKENS.lucia, k),
       `token ${k} vie prepnut aj tema Lucia`);
  });
})();

console.log(`UI-01 tema: ${n} kontrol OK`);
