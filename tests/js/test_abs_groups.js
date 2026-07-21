// Testy zoskupenia ABS pások D-36 (core.js groupAbsEdges/absOptionsHtml/normDecor) —
// dependency-free Node (node tests/js/test_abs_groups.js). core.js exportuje CISTE
// grouping funkcie cez module.exports (v CEF vetva spi, rovnaky vzor ako expr.js).
// Pokryva: B2 (presna zhoda dekoru + zoradenie hrubkou vzostupne), F4 (prazdny/nil/
// whitespace dekor = ziadna skupina, plochy fallback), F5 (hodnota mimo katalogu sa
// zachova), case-sensitivitu (B2: ziadne fuzzy) a stavbu HTML (optgroupy vs plochy).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { groupAbsEdges, absOptionsHtml, normDecor } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function ids(list){ return list.map(function(e){ return e.id; }); }

// Katalog ABS: K009 PW ma 2,0 aj 1,0 (schvalne v poradi 2,0 pred 1,0 — test zoradenia),
// W1000 je iny dekor. thickness ako cislo (payloads.rb posiela Float).
const EDGES = [
  { id: 'ABS_K009_20',  label: 'K009 PW 2.0 mm',          decor: 'K009 PW',          thickness: 2.0 },
  { id: 'ABS_K009_10',  label: 'K009 PW 1.0 mm',          decor: 'K009 PW',          thickness: 1.0 },
  { id: 'ABS_W1000_10', label: 'W1000 ST9 Biela 1.0 mm',  decor: 'W1000 ST9 Biela',  thickness: 1.0 }
];
const EDGES_JSON = JSON.stringify(EDGES);

// --- normDecor: trim (legacy/whitespace), NIE lowercase ---
eq(normDecor('  K009 PW  '), 'K009 PW', 'normDecor orezava whitespace');
eq(normDecor(null), '', 'normDecor(nil) = prazdne');
eq(normDecor(undefined), '', 'normDecor(undefined) = prazdne');
eq(normDecor('   '), '', 'normDecor(whitespace) = prazdne');
eq(normDecor('K009 pw'), 'K009 pw', 'normDecor NEmeni velkost pismen (case-sensitive)');

// --- B2: recommended = presna zhoda dekoru, zoradene hrubkou VZOSTUPNE (1,0 -> 2,0) ---
const g = groupAbsEdges(EDGES, 'K009 PW', '__inherit__');
eq(ids(g.recommended), ['ABS_K009_10', 'ABS_K009_20'], 'B2: zhoda dekoru zoradena hrubkou vzostupne');
eq(ids(g.others), ['ABS_W1000_10'], 'B2: iny dekor ide do Ostatne');
eq(g.preserve, null, 'inherit hodnota nema preserve');
eq(JSON.stringify(EDGES), EDGES_JSON, 'groupAbsEdges NEmutuje vstupny katalog');

// --- B2: dekor s trailing whitespace v katalogu aj cieli sa zhoduje (normalizacia) ---
eq(ids(groupAbsEdges(EDGES, '  K009 PW  ', '').recommended), ['ABS_K009_10', 'ABS_K009_20'],
  'B2: trim na oboch stranach — whitespace nebrani zhode');
// case-sensitive: iny case = ziadna zhoda (ziadne fuzzy)
eq(groupAbsEdges(EDGES, 'k009 pw', '').recommended.length, 0, 'B2: mala pismena = nezhoda (case-sensitive)');

// --- F4: prazdny / nil / whitespace dekor => ziadne odporucane (plochy fallback) ---
eq(groupAbsEdges(EDGES, '', '').recommended.length, 0, 'F4: prazdny dekor bez odporucanych');
eq(groupAbsEdges(EDGES, null, '').recommended.length, 0, 'F4: nil dekor bez odporucanych');
eq(groupAbsEdges(EDGES, '   ', '').recommended.length, 0, 'F4: whitespace dekor bez odporucanych');
eq(groupAbsEdges(EDGES, '', '').others.length, 3, 'F4: vsetky pasky v others (plochy zoznam)');

// --- Dekor neprazdny ALE ziadna zhoda => tiez plochy (recommended prazdny) ---
const gNoMatch = groupAbsEdges(EDGES, 'Neexistujuci Dekor', '');
eq(gNoMatch.recommended.length, 0, 'ziadna zhoda => recommended prazdny');
eq(gNoMatch.others.length, 3, 'ziadna zhoda => vsetko v others');

// --- F5: aktualna hodnota mimo katalogu (legacy/zmazana) => preserve ---
eq(groupAbsEdges(EDGES, 'K009 PW', 'ABS_LEGACY_ZMAZANA').preserve, 'ABS_LEGACY_ZMAZANA',
  'F5: hodnota mimo katalogu sa zachova');
eq(groupAbsEdges(EDGES, 'K009 PW', 'ABS_K009_10').preserve, null,
  'F5: hodnota v katalogu netreba zachovavat (uz je option)');
eq(groupAbsEdges(EDGES, 'K009 PW', '').preserve, null, 'F5: Bez ABS ("") nie je preserve');
eq(groupAbsEdges(EDGES, 'K009 PW', '__inherit__').preserve, null, 'F5: inherit nie je preserve');
eq(groupAbsEdges(EDGES, '', 'ABS_LEGACY').preserve, 'ABS_LEGACY',
  'F5: preserve funguje aj v plochom (prazdny dekor) rezime');

// --- absOptionsHtml: 2 optgroupy ked su odporucane, poradie prefix < Odporucane < Ostatne ---
const html = absOptionsHtml('<option value="">Bez ABS</option>', groupAbsEdges(EDGES, 'K009 PW', '__inherit__'));
ok(html.indexOf('<optgroup label="Odporúčané k dekoru">') >= 0, 'HTML: optgroup Odporucane');
ok(html.indexOf('<optgroup label="Ostatné">') >= 0, 'HTML: optgroup Ostatne');
ok(html.indexOf('Bez ABS') < html.indexOf('<optgroup label="Odporúčané'), 'HTML: prefix pred skupinami');
ok(html.indexOf('<optgroup label="Odporúčané') < html.indexOf('<optgroup label="Ostatné'),
  'HTML: Odporucane pred Ostatne');
// v Odporucane su obe K009 pasky, zoradene 1,0 pred 2,0
ok(html.indexOf('ABS_K009_10') < html.indexOf('ABS_K009_20'), 'HTML: 1,0 mm pred 2,0 mm');

// --- absOptionsHtml: F4 plochy fallback bez optgroup ---
const htmlFlat = absOptionsHtml('<option value="">Bez ABS</option>', groupAbsEdges(EDGES, '', ''));
ok(htmlFlat.indexOf('<optgroup') < 0, 'F4 HTML: ziadny optgroup pri prazdnom dekore');
ok(htmlFlat.indexOf('ABS_W1000_10') >= 0, 'F4 HTML: pasky su v plochom zozname');

// --- absOptionsHtml: F5 zachovavacia option (hodnota = label, ide do Ostatne) ---
const htmlKeep = absOptionsHtml('', groupAbsEdges(EDGES, 'K009 PW', 'LEGACY_X'));
ok(htmlKeep.indexOf('<option value="LEGACY_X">LEGACY_X</option>') >= 0, 'F5 HTML: zachovavacia option');
ok(htmlKeep.indexOf('LEGACY_X') > htmlKeep.indexOf('<optgroup label="Ostatné'),
  'F5 HTML: zachovavacia option je v Ostatne');

// --- absOptionsHtml: escapovanie HTML v zachovavacej hodnote (XSS guard cez esc) ---
const htmlEsc = absOptionsHtml('', groupAbsEdges(EDGES, 'K009 PW', '<x>&"'));
ok(htmlEsc.indexOf('&lt;x&gt;&amp;&quot;') >= 0, 'F5 HTML: zachovavacia hodnota je escapovana');

console.log(JSON.stringify({ passed: n, failed: 0 }));
