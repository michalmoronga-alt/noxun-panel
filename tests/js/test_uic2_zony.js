// UI-C2 — ZONY: ciste jadro panela (dependency-free Node,
// `node tests/js/test_uic2_zony.js`). Pokryva to, co v CEF nevidno:
//   1) ZRKADLO konstant Ruby<->JS (MIN_FIELD, MAX_LEVELS, Shelves::MAX, EPS),
//   2) JEDNA geometria pre zlomky aj magnet tahania priecky (audit F6) —
//      zlomok sa pocita zo SVETLEHO priestoru a stred priecky sadne na zlomok,
//   3) PRESNA CESTA (audit F7): nezmestitelna hodnota sa ODMIETNE (nikdy sa
//      ticho nezmensi), zvysok ide do POSLEDNEHO odomknuteho pola, presnost
//      0,01 mm (zaokruhlenie na cele mm by z korpusu „zjedlo" az 2 mm),
//   4) DRAFT PARITA (audit F10): rezim vkladania nema server, takze rovnake
//      guardy (listovost, hlbka, strop polic) musia platit aj lokalne,
//   5) POINTER CAPTURE dragu (audit F11) — visiaci mouseup mimo okna.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const zt = require(path.join(JS, 'zone_tree.js'));
const NXZ = zt.NXZ;

const ACTIONS = fs.readFileSync(path.join(JS, 'actions.js'), 'utf8');
const PREVIEW = fs.readFileSync(path.join(JS, 'preview.js'), 'utf8');
const ZONEJS = fs.readFileSync(path.join(JS, 'zone_tree.js'), 'utf8');

let n = 0;
function t(name, fn){ fn(); n++; }
const near = (a, b, tol) => assert.ok(Math.abs(a - b) <= (tol == null ? 0.01 : tol),
  'ocakavane ' + b + ', dostal ' + a);

// --- 1) zrkadlo konstant ----------------------------------------------------

t('konstanty su zrkadlom Ruby (jedno cislo, dve strany)', () => {
  assert.strictEqual(NXZ.MIN_FIELD, 20);
  assert.strictEqual(NXZ.MAX_LEVELS, 3);
  assert.strictEqual(NXZ.MAX_SHELVES, 6);
  assert.strictEqual(NXZ.MAX_FIELDS, 4);
  assert.strictEqual(NXZ.EPS, 0.01);
});

t('sanitizeTree clampuje police na 6 (nie na 4)', () => {
  assert.strictEqual(zt.sanitizeTree({ shelves: 9 }).shelves, 6);
  assert.strictEqual(zt.sanitizeTree({ shelves: 6 }).shelves, 6);
  assert.strictEqual(zt.sanitizeTree({ shelves: -2 }).shelves, 0);
  // delena zona ma police vzdy 0 a pocet poli sa clampuje na 4
  const sp = zt.sanitizeTree({ shelves: 3, split: { axis: 'x', count: 9 } });
  assert.strictEqual(sp.shelves, 0);
  assert.strictEqual(sp.split.count, 4);
  assert.strictEqual(sp.split.axis, 'v');
});

// --- 2) JEDNA geometria: zlomky aj magnet -----------------------------------

t('zlomok sa pocita zo SVETLEHO priestoru, stred priecky sadne na zlomok', () => {
  const span = 864, tt = 18;
  near(zt.nxZoneClear(span, 2, tt), 846);
  const half = zt.nxZoneCumForFraction(span, 2, tt, 0, 0.5);
  near(half, 423);                                  // nie 432 (mockup ratal nahrubo)
  near(half, zt.nxZoneClear(span, 2, tt) / 2);
  near(half + tt / 2, span / 2);                    // stred priecky presne v polovici
  near(zt.nxZoneCumForFraction(span, 2, tt, 0, 0.25) + tt / 2, span / 4);
  near(zt.nxZoneCumForFraction(span, 2, tt, 0, 0.75) + tt / 2, 3 * span / 4);
});

t('tri polia — druha priecka rata OBE priecky pred sebou', () => {
  const span = 900, tt = 18;
  const cum = zt.nxZoneCumForFraction(span, 3, tt, 1, 0.5);
  near(cum + 1 * tt + tt / 2, span / 2);
});

t('magnet drzi prah a Alt (tolerancia 0) ho vypina', () => {
  const span = 864, tt = 18;
  const half = zt.nxZoneCumForFraction(span, 2, tt, 0, 0.5);
  near(zt.nxZoneSnapCum(span, 2, tt, 0, half + 3, 6), half);        // v prahu -> prilepi
  near(zt.nxZoneSnapCum(span, 2, tt, 0, half + 30, 6), half + 30);  // mimo prahu -> nedotknute
  near(zt.nxZoneSnapCum(span, 2, tt, 0, half + 0.4, 0), half + 0.4); // Alt -> ziadny magnet
  // magnet pozna 1/4 · 1/2 · 3/4 (N20)
  const q = zt.nxZoneCumForFraction(span, 2, tt, 0, 0.25);
  near(zt.nxZoneSnapCum(span, 2, tt, 0, q + 2, 6), q);
});

t('ponuka zlomkov vynecha tie, ktore sa do zony nezmestia', () => {
  const wide = zt.nxZoneFractionOptions(864, 2, 18, 0).map(o => o.label);
  assert.deepStrictEqual(wide, ['1/4', '1/3', '1/2']);
  const narrow = zt.nxZoneFractionOptions(100, 2, 18, 0).map(o => o.label);
  assert.ok(narrow.indexOf('1/4') < 0, '1/4 by prvemu polu nechalo 16 mm (< MIN_FIELD)');
  assert.ok(narrow.indexOf('1/2') >= 0);
});

// --- 3) presna cesta --------------------------------------------------------

const cuts2 = () => [{ size: null, locked: false }, { size: null, locked: false }];

t('presna cesta rozdeli zvysok a sucet presne sedi na svetly priestor', () => {
  const res = zt.nxZoneExactCuts(cuts2(), [423, 423], 2, 846, 0, 500, true);
  assert.ok(!res.error, res.error);
  near(res.cuts[0].size, 500);
  near(res.cuts[1].size, 346);
  near(res.cuts[0].size + res.cuts[1].size, 846);
  assert.strictEqual(res.cuts[0].locked, true, 'zadana hodnota pole ZAMKNE (B5)');
  assert.strictEqual(res.cuts[1].locked, false);
});

t('nezmestitelna hodnota sa ODMIETNE — nikdy sa ticho nezmensi', () => {
  const res = zt.nxZoneExactCuts(cuts2(), [423, 423], 2, 846, 0, 840, true);
  assert.ok(res.error, 'malo sa odmietnut');
  assert.ok(/nezmestí/.test(res.error), res.error);
  assert.ok(!res.cuts, 'odmietnutie nesmie vratit ziadne polia');
  // pod minimom tiez
  assert.ok(/najmenšie pole/.test(zt.nxZoneExactCuts(cuts2(), [423, 423], 2, 846, 0, 5, true).error));
  assert.ok(/platné číslo/.test(zt.nxZoneExactCuts(cuts2(), [423, 423], 2, 846, 0, NaN, true).error));
});

t('presnost je 0,01 mm — ziadne zaokruhlovanie na cele mm', () => {
  // 3 polia, svetly priestor 800: 250,05 + zvysok proporcne
  const c = [{ size: null, locked: false }, { size: null, locked: false }, { size: null, locked: false }];
  const res = zt.nxZoneExactCuts(c, [266.67, 266.67, 266.66], 3, 800, 0, 250.05, true);
  assert.ok(!res.error, res.error);
  near(res.cuts[0].size, 250.05, 0.001);
  near(res.cuts[0].size + res.cuts[1].size + res.cuts[2].size, 800, 0.001);
  // dorovnanie ide do POSLEDNEHO odomknuteho pola (deterministicky)
  assert.ok(res.cuts[2].size !== res.cuts[1].size || Math.abs(res.cuts[1].size - res.cuts[2].size) < 0.02);
});

t('zamknute susedne pole drzi svoj rozmer, dorovnava sa odomknute', () => {
  const c = [{ size: null, locked: false }, { size: 300, locked: true }, { size: null, locked: false }];
  const res = zt.nxZoneExactCuts(c, [266, 300, 234], 3, 800, 0, 260, true);
  assert.ok(!res.error, res.error);
  near(res.cuts[1].size, 300);
  assert.strictEqual(res.cuts[1].locked, true);
  near(res.cuts[0].size + res.cuts[1].size + res.cuts[2].size, 800);
});

t('vsetky ostatne zamknute a sucet nesedi = jasne odmietnutie', () => {
  const c = [{ size: null, locked: false }, { size: 300, locked: true }];
  const res = zt.nxZoneExactCuts(c, [546, 300], 2, 846, 0, 500, true);
  assert.ok(/zamknuté/.test(res.error), res.error);
  // ked sucet sedi, prejde
  const ok = zt.nxZoneExactCuts(c, [546, 300], 2, 846, 0, 546, true);
  assert.ok(!ok.error, ok.error);
});

// --- 4) draft parita + guardy klienta ---------------------------------------

t('draft rezim vkladania nesie TIE ISTE guardy ako server (F10)', () => {
  const split = ACTIONS.match(/function splitZone\([\s\S]*?\n  \}/)[0];
  assert.ok(split.indexOf('if (!z.leaf)') >= 0, 'delenie delenej zony musi odmietnut aj bez servera');
  assert.ok(split.indexOf('NXZ.MAX_LEVELS') >= 0, 'hlbka sa musi strazit aj v drafte');
  assert.ok(split.indexOf('NXZ.MAX_FIELDS') >= 0, 'pocet poli sa musi clampovat aj v drafte');
  // guardy stoja PRED vetvou draft/server, takze platia pre obe cesty
  assert.ok(split.indexOf('if (!z.leaf)') < split.indexOf('if (selectedCabId)'),
    'guard musi bezat pred rozvetvenim na server/draft');
  const sh = ACTIONS.match(/function setZoneShelves\([\s\S]*?\n  \}/)[0];
  assert.ok(sh.indexOf('NXZ.MAX_SHELVES') >= 0, 'strop polic musi platit aj v drafte');
  assert.ok(sh.indexOf('if (!z.leaf)') >= 0);
  // draft vetva nesmie zabudnut na prepocet odhadu navrhu
  ['splitZone', 'setZoneShelves', 'cleanZone'].forEach(fn => {
    const body = ACTIONS.match(new RegExp('function ' + fn + '\\([\\s\\S]*?\\n  \\}'))[0];
    assert.ok(body.indexOf('nxDraftChanged()') >= 0, fn + ' musi v drafte prepocitat odhad');
  });
});

t('zonove callbacky idu VYHRADNE cez nxZonePayload (identita dokumentu)', () => {
  assert.ok(ZONEJS.indexOf('function nxZonePayload') >= 0);
  assert.ok(ZONEJS.indexOf('o.model_guid') >= 0 && ZONEJS.indexOf('o.cabinet_id') >= 0);
  ['split_zone', 'set_zone_shelves', 'clean_zone', 'select_zone', 'set_zone_field'].forEach(cb => {
    const all = ACTIONS + ZONEJS + PREVIEW;
    assert.ok(all.indexOf('sketchup.' + cb + '(JSON.stringify(') < 0,
      cb + ' sa nesmie posielat bez metadat identity');
  });
});

t('dlazdice a pilulky su neaktivne cez aria-disabled, nie HTML disabled', () => {
  const fn = ACTIONS.match(/function setZoneCtl\([\s\S]*?\n  \}/)[0];
  assert.ok(fn.indexOf("setAttribute('aria-disabled'") >= 0);
  assert.ok(fn.indexOf("setAttribute('title'") >= 0, 'dovod musi byt citatelny');
  assert.ok(fn.indexOf('.disabled = true') < 0, 'HTML disabled by zhltol hover aj tooltip');
  // a klik na neaktivny prvok povie PRECO (nie ticho nic)
  const del = ACTIONS.match(/function setupFieldEditorDelegation\([\s\S]*?\n  \}/)[0];
  assert.ok(del.indexOf('zoneCtlOn(t)') >= 0 && del.indexOf('NX.setStatus') >= 0);
});

t('strom kresli spojnice a 4. uroven je NEklikatelny varovny riadok', () => {
  const fn = ACTIONS.match(/function renderZoneTree\([\s\S]*?\n  \}/)[0];
  assert.ok(fn.indexOf("'zkids'") >= 0, 'vnorenie musi mat vlastny kontajner (spojnice kresli CSS)');
  assert.ok(fn.indexOf('NXZ.MAX_LEVELS') >= 0, 'hlbsia uroven sa musi rozpoznat');
  assert.ok(fn.indexOf('if (deep)') >= 0 && fn.indexOf('else { div.onclick') >= 0,
    'varovny riadok nesmie byt klikatelny (NOTE 14)');
  const css = fs.readFileSync(path.join(JS, '..', 'css', 'panel.css'), 'utf8');
  assert.ok(css.indexOf('.zkids > .znode::before') >= 0, 'chybaju stromove spojnice v CSS');
  assert.ok(css.indexOf('.zkids:empty') >= 0, 'prazdny kontajner listu sa nesmie kreslit');
});

// --- 5) drag: pointer capture + magnet --------------------------------------

t('drag priecky drzi pointer capture a konci aj pri pointercancel (F11)', () => {
  const start = PREVIEW.match(/function startDivDrag\([\s\S]*?\n  \}/)[0];
  assert.ok(start.indexOf('setPointerCapture') >= 0, 'bez capture visi mouseup mimo okna');
  assert.ok(start.indexOf("addEventListener('pointerup'") >= 0);
  assert.ok(start.indexOf("addEventListener('pointercancel'") >= 0);
  assert.ok(PREVIEW.indexOf("svg.addEventListener('pointerdown'") >= 0,
    'bez pointerdown neexistuje pointerId a capture sa nastavit neda');
  const move = PREVIEW.match(/function onDivDrag\([\s\S]*?\n  \}/)[0];
  assert.ok(move.indexOf('nxZoneSnapCum(') >= 0, 'magnet musi ist cez ZDIELANU geometriu');
  assert.ok(move.indexOf('ev.altKey') >= 0 && move.indexOf('ev.altKey') < move.indexOf('nxZoneSnapCum('),
    'Alt musi vypnut magnet PRED aplikaciou');
  assert.ok(move.indexOf('DIV_SNAP_PX / scale') >= 0, 'prah musi byt v px prepocitany zoomom');
  assert.ok(move.indexOf('nxRound2(') >= 0, 'ulozeny rozmer je mm Float 0,01, nie cele mm');
  const end = PREVIEW.match(/function endDivDrag\([\s\S]*?\n  \}/)[0];
  assert.ok(end.indexOf('endDivListeners()') >= 0, 'listenery sa musia odviazat vzdy');
});

console.log('OK test_uic2_zony.js — ' + n + ' sad');
