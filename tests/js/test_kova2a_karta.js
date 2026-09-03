// KOV-A2a — KARTA CELA: ciste jadro + cela cesta „riadok -> karta -> config".
//
// Preco su to testy a nie klikanie v paneli:
//   1. TROJSTAV SMERU sa neda vidiet. „Kluc chyba" (legacy, ziadny nalez)
//      a „neurcene" (RED nalez) vyzeraju v UI takmer rovnako — rozdiel je
//      v tom, CO sa ulozi. Jediny sposob, ako ustrazit, ze render, echo ani
//      editacia ineho pola z legacy cela nespravia „neurcene", je prejst
//      cele kolecko `addFrontRow -> karta -> collectFronts` nad polozkou
//      BEZ klucov a overit, ze je bez klucov aj na konci.
//   2. APLIKOVATELNOST SMERU je serverova. Karta smie kreslit LEN to, co
//      posle `front_slots`; keby si ju odvodila z poctu kridiel, dvojkridlo
//      by sa zacalo pytat na stranu pantov a 3/4-kridlove dvierka by sa
//      pytali aj na krajne kridla (tie su ODVODENE, A1 kontrakt).
//   3. DORMANT. Prepnutie typu ani navrat na 1/2 kridla nesmie ulozenu
//      hodnotu zmazat — inak by sa po naspatnom prepnuti stratila.
//   4. SYMBOLY NAHLADU sa v Node nedaju „pozriet", ale ich VYBER je cista
//      funkcia — a prave ten je nositelom pravidla „ziadny fallback na stranu".
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const C = require(path.join(JS, 'core.js'));
const UNSET = C.FRONT_DIR_UNSET;

// Tvar, v akom sloty chodia z Ruby (`Panel.front_slots_payload`).
function slot(wing, state){ return { wing: wing, part_key: 'front:F1/wing:' + wing, state: state }; }
// ZAZNAM cela: `wings_n` chodi SPOLU so slotmi (Codex #281 P2-A) — prazdne
// pole samo o sebe dvojkridlo NEZNAMENA (da ho aj stary cache bez `wings_n`).
function entry(wingsN, slots){ return { wings_n: wingsN, slots: slots || [] }; }
// Skratky nad view-modelom: ktore riadky karta ukaze a co je v nich aktivne.
function rowKeys(m){ return m.rows.filter(r => r.kind === 'seg').map(r => r.key + (r.wing ? ':' + r.wing : '')); }
function activeOf(m, key){
  const r = m.rows.find(x => x.kind === 'seg' && (x.key + (x.wing ? ':' + x.wing : '')) === key);
  return r ? r.active : undefined;
}
function infoTexts(m){ return m.rows.filter(r => r.kind === 'info').map(r => r.text); }

// ============ 1) VIEW-MODEL: matica 6 typov x sloty 0/1/2 ===================

eq(C.FRONT_CARD_TYPES, ['door', 'drawer_front', 'lift', 'fall', 'blind', 'none'],
   'typegrid ponuka VSETKYCH sest typov (aj „Bez čela" — D-18 je platny typ riadku)');

// Dlazdice: prave jedna je aktivna a zodpoveda typu polozky.
C.FRONT_CARD_TYPES.forEach(t => {
  const m = C.frontCardModel({ type: t }, entry(1, []));
  eq(m.tiles.length, 6, `${t}: sest dlazdic`);
  eq(m.tiles.filter(x => x.on).map(x => x.type), [t], `${t}: aktivna je prave jeho dlazdica`);
});
// Neznamy typ (config z novsej verzie) NEROZSVIETI ziadnu dlazdicu a prizna sa.
const unk = C.frontCardModel({ type: 'sliding_2027' }, entry(1, []));
eq(unk.tiles.filter(x => x.on).length, 0, 'neznamy typ sa nevydava za ziadny zo sestice');
eq(unk.known, false, 'a karta o nom vie');

// --- dvierka: smer sa pyta PRESNE tam, kde to povedal server ---------------
eq(rowKeys(C.frontCardModel({ type: 'door' }, entry(1, [slot('single', null)]))),
   ['direction:single', 'opening_mode'], '1 kridlo: smer + otvaranie');
eq(rowKeys(C.frontCardModel({ type: 'door' }, entry(2, []))),
   ['opening_mode'], '2 kridla (server nekladie otazku): ZIADNY riadok smeru');
ok(infoTexts(C.frontCardModel({ type: 'door' }, entry(2, []))).some(t => t.indexOf('Dvojkrídlo') === 0),
   'namiesto neho sa povie, co plati (lave = panty vlavo, prave vpravo)');
eq(rowKeys(C.frontCardModel({ type: 'door' }, entry(3, [slot('p2', null)]))),
   ['wing_direction:p2', 'opening_mode'], '3 kridla: len STREDNE kridlo');
eq(rowKeys(C.frontCardModel({ type: 'door' }, entry(4, [slot('p2', null), slot('p3', null)]))),
   ['wing_direction:p2', 'wing_direction:p3', 'opening_mode'], '4 kridla: obe stredne kridla');
// Popis krídla nesie aj CELKOVY pocet — „Krídlo 2/3" a „Krídlo 2/4" su ine veci.
eq(C.frontCardModel({ type: 'door' }, entry(3, [slot('p2', null)])).rows[0].label, 'Krídlo 2/3',
   '3 kridla: p2 je „Krídlo 2/3"');
eq(C.frontCardModel({ type: 'door' }, entry(4, [slot('p2', null), slot('p3', null)])).rows.map(r => r.label).slice(0, 2),
   ['Krídlo 2/4', 'Krídlo 3/4'], '4 kridla: p2 a p3 vedia, z kolkych su');
// Server sa este nevyjadril (novy riadok pred prvym echom) — nic sa neodvodzuje.
eq(rowKeys(C.frontCardModel({ type: 'door' }, null)), ['opening_mode'],
   'bez zaznamu sa smer NEPYTA (a ani sa netvrdi, ze je dvojkridlo)');
eq(infoTexts(C.frontCardModel({ type: 'door' }, null)), [],
   'a nekresli sa ani veta o dvojkridle');
// Codex #281 P2-A: prazdne pole slotov SAMO O SEBE dvojkridlo NEZNAMENA —
// da ho aj stary `front_items` (pred D-07) bez `wings_n`. Karta preto vetu
// o dvojkridle povie LEN pri `wings_n === 2`; pri neznamom pocte MLCI.
eq(rowKeys(C.frontCardModel({ type: 'door' }, entry(null, []))), ['opening_mode'],
   'neznamy pocet kridiel: ziadny riadok smeru');
eq(infoTexts(C.frontCardModel({ type: 'door' }, entry(null, []))), [],
   'a ANI veta o dvojkridle (tvrdit ju nad starym cache by bola lož)');
// Cela matica efektivneho poctu kridiel (co karta zobrazi):
[[1, [slot('single', null)], ['direction:single', 'opening_mode'], 0],
 [2, [], ['opening_mode'], 1],
 [3, [slot('p2', null)], ['wing_direction:p2', 'opening_mode'], 0],
 [4, [slot('p2', null), slot('p3', null)], ['wing_direction:p2', 'wing_direction:p3', 'opening_mode'], 0],
 [null, [], ['opening_mode'], 0]].forEach(([wn, sl, keys, infos]) => {
  const m = C.frontCardModel({ type: 'door' }, entry(wn, sl));
  eq(rowKeys(m), keys, `wings_n ${wn}: riadky karty`);
  eq(infoTexts(m).length, infos, `wings_n ${wn}: pocet informacnych viet`);
});

// --- ostatne typy ---------------------------------------------------------
eq(rowKeys(C.frontCardModel({ type: 'drawer_front' }, entry(1, []))),
   ['opening_mode', 'drawer_construction', 'drawer_variant'], 'zasuvka: otvaranie + klasifikacia');
eq(rowKeys(C.frontCardModel({ type: 'lift' }, entry(1, []))), ['opening_mode'], 'vyklop: len otvaranie');
eq(rowKeys(C.frontCardModel({ type: 'fall' }, entry(1, []))), ['opening_mode'], 'sklop: len otvaranie');
eq(rowKeys(C.frontCardModel({ type: 'blind' }, entry(1, []))), [], 'blenda nema smer ani otvaranie');
eq(rowKeys(C.frontCardModel({ type: 'none' }, entry(1, []))), [], '„Bez čela" nema co nastavovat');
ok(infoTexts(C.frontCardModel({ type: 'blind' }, entry(1, []))).some(t => t.indexOf('pevný výrobný dielec') > 0),
   'blenda povie, PRECO nema ovladace');
// Sloty smeru sa pri ne-dvierkach ignoruju aj keby prisli (dormant hodnota
// ostava v configu, ale otazka na nu sa nekladie).
eq(rowKeys(C.frontCardModel({ type: 'drawer_front', direction: 'left' }, entry(1, [slot('single', 'left')]))),
   ['opening_mode', 'drawer_construction', 'drawer_variant'],
   'zasuvka sa na stranu pantov NEPYTA ani so slotmi v ruke');

// ============ 2) AKTIVNA VOLBA: legacy = ZIADNA, ziadny default =============

eq(activeOf(C.frontCardModel({ type: 'door' }, entry(1, [slot('single', null)])), 'direction:single'), null,
   'LEGACY celo (kluc smeru chyba): ziadna aktivna volba');
eq(activeOf(C.frontCardModel({ type: 'door', direction: UNSET }, entry(1, [slot('single', UNSET)])), 'direction:single'),
   UNSET, 'vedome neurcene: aktivna je volba „Neurčené"');
eq(activeOf(C.frontCardModel({ type: 'door', direction: 'left' }, entry(1, [slot('single', 'left')])), 'direction:single'),
   'left', 'vyriesene: aktivna je strana');
eq(activeOf(C.frontCardModel({ type: 'door', wing_directions: { p2: 'right' } }, entry(3, [slot('p2', 'right')])),
            'wing_direction:p2'), 'right', 'stredne kridlo cita svoju hodnotu z wing_directions');
eq(activeOf(C.frontCardModel({ type: 'door', direction: 'left' }, entry(3, [slot('p2', null)])), 'wing_direction:p2'), null,
   'scalarny smer sa pri 3/4 kridlach NECITA (dormant)');
eq(activeOf(C.frontCardModel({ type: 'door' }, entry(2, [])), 'opening_mode'), null,
   'chybajuce otvaranie = ziadna aktivna volba (NIE „klasicke")');
ok(C.frontCardModel({ type: 'door' }, entry(2, [])).rows.find(r => r.key === 'opening_mode').hint.indexOf('predvolene') > 0,
   'namiesto tichej volby sa povie, co plati, kym to nikto neurci');
const drwLegacy = C.frontCardModel({ type: 'drawer_front' }, entry(1, []));
eq(activeOf(drwLegacy, 'drawer_construction'), null, 'zasuvka bez klasifikacie: ziadna konstrukcia');
eq(activeOf(drwLegacy, 'drawer_variant'), null, 'ani variant');
ok(infoTexts(drwLegacy).some(t => t.indexOf('bez klasifikácie') > 0),
   'a povie sa, ze system pride az po klasifikacii (KOV-C)');
eq(infoTexts(C.frontCardModel({ type: 'drawer_front', drawer: { construction: 'metal' } }, entry(1, []))), [],
   'ciastocna klasifikacia uz vetu o „bez klasifikácie" nekresli');

// NEGATIVNY TEST: render NIC NEMATERIALIZUJE.
const legacyItem = { type: 'door' };
const before = JSON.stringify(legacyItem);
C.frontCardModel(legacyItem, entry(1, [slot('single', null)]));
eq(JSON.stringify(legacyItem), before, 'frontCardModel je CISTA — vstup nemeni');

// ============ 3) VYROBCOVIA stavu „neurcene" ===============================

// (b) prepnutie dlazdice na dvierka
eq(C.frontExtraOnTypeChange({}, 'door'), { direction: UNSET },
   'dvierka bez ulozeneho smeru: pouzivatelska akcia stav PRIZNA');
eq(C.frontExtraOnTypeChange({ direction: 'left' }, 'door'), { direction: 'left' },
   'ulozeny smer sa NEPREPISUJE');
eq(C.frontExtraOnTypeChange({ direction: UNSET }, 'drawer_front'), { direction: UNSET },
   'prepnutie na iny typ NIC NEMAZE (dormant)');
eq(C.frontExtraOnTypeChange({ opening_mode: 'tipon' }, 'blind'), { opening_mode: 'tipon' },
   'ani otvaranie sa pri prepnuti typu nestraca');
eq(C.frontExtraOnTypeChange({}, 'drawer_front'), {},
   'zasuvka sa NEKLASIFIKUJE sama (ziadne metal+standard)');

// (d) pocet kridiel
eq(C.frontExtraOnWings({}, '3'), { wing_directions: { p2: UNSET } },
   '3 kridla: pribudne otazka na stredne kridlo');
eq(C.frontExtraOnWings({}, '4'), { wing_directions: { p2: UNSET, p3: UNSET } },
   '4 kridla: obe stredne kridla');
eq(C.frontExtraOnWings({ wing_directions: { p2: 'left' } }, '4'),
   { wing_directions: { p2: 'left', p3: UNSET } }, 'uz urcene kridlo sa NEPREPISUJE');
eq(C.frontExtraOnWings({ wing_directions: { p2: 'left' } }, '1'),
   { wing_directions: { p2: 'left' } }, 'navrat na 1 kridlo NIC NEMAZE (dormant)');
eq(C.frontExtraOnWings({ wing_directions: { p2: 'left', p3: 'right' } }, '2'),
   { wing_directions: { p2: 'left', p3: 'right' } }, 'ani navrat na dvojkridlo');
eq(C.frontExtraOnWings({}, 'auto'), {}, 'auto ziadnu otazku nevyraba (efektivny pocet urcuje server)');
eq(C.frontExtraOnWings({}, '2'), {}, 'dvojkridlo sa na stranu pantov nepyta');

// (c) klik na segrow
eq(C.frontExtraOnSegrow({}, 'direction', 'left'), { direction: 'left' }, 'klik na „Ľavé"');
eq(C.frontExtraOnSegrow({}, 'direction', UNSET), { direction: UNSET }, 'klik na „Neurčené"');
eq(C.frontExtraOnSegrow({ wing_directions: { p3: 'left' } }, 'wing_direction', 'right', 'p2'),
   { wing_directions: { p3: 'left', p2: 'right' } }, 'kridlo si nesiaha na susedne');
eq(C.frontExtraOnSegrow({}, 'wing_direction', 'right'), {},
   'bez krídla sa nic nezapise (poskodene volanie)');
eq(C.frontExtraOnSegrow({}, 'opening_mode', 'tipon'), { opening_mode: 'tipon' }, 'Tip-On');
eq(C.frontExtraOnSegrow({ drawer: { variant: 'internal' } }, 'drawer_construction', 'wood'),
   { drawer: { variant: 'internal', construction: 'wood' } }, 'pod-polia zasuvky su NEZAVISLE');
eq(C.frontExtraOnSegrow({ direction: 'left' }, 'neznamy_kluc', 'x'), { direction: 'left' },
   'neznamy kluc polozku nedotkne');

// VSETKY tri vracaju NOVY objekt (dataset riadku sa nesmie zmenit „mimochodom").
const src = { direction: 'left', wing_directions: { p2: 'right' } };
[C.frontExtraOnTypeChange(src, 'door'), C.frontExtraOnWings(src, '4'),
 C.frontExtraOnSegrow(src, 'opening_mode', 'tipon')].forEach((out, i) => {
  ok(out !== src, `vyrobca #${i + 1} vracia novy objekt`);
});
eq(src, { direction: 'left', wing_directions: { p2: 'right' } }, 'a vstup ostal nedotknuty');

// ============ 4) BADGE „smer?" =============================================

eq(C.frontDirBadge([slot('single', UNSET)]), true, 'neurceny smer = badge');
eq(C.frontDirBadge([slot('single', null)]), false, 'LEGACY celo badge NEDOSTANE');
eq(C.frontDirBadge([slot('single', 'left')]), false, 'vyrieseny smer badge nema');
eq(C.frontDirBadge([slot('p2', 'left'), slot('p3', UNSET)]), true, 'staci JEDNO neurcene kridlo');
eq(C.frontDirBadge([]), false, 'dvojkridlo badge nema');
eq(C.frontDirBadge(null), false, 'chybajuce sloty nespadnu');

// ============ 4b) KOMU PATRI OTVORENA KARTA (Codex #281 P2-B) ==============
// `front_id` (F1) ma KAZDA skrinka v zakazke, takze samotne ID cela identitu
// karty neurcuje — po prepnuti vyberu by sa otvorila karta cudzieho cela.
eq(C.frontCardKeepOpen('CAB-001', 'CAB-001', 'F1'), 'F1', 'echo TEJ ISTEJ skrinky kartu nechava');
eq(C.frontCardKeepOpen('CAB-001', 'CAB-002', 'F1'), null, 'ina skrinka = karta sa zatvara');
eq(C.frontCardKeepOpen(null, 'CAB-001', 'F1'), null,
   'neznamy predchodca (iny dokument, prazdny vyber) = zatvara sa');
eq(C.frontCardKeepOpen('CAB-001', null, 'F1'), null, 'odchod z korpusu (doska, vkladanie) tiez');
eq(C.frontCardKeepOpen('CAB-001', 'CAB-001', null), null, 'ked nic otvorene nie je, nic sa neotvara');

// ============ 4c) IDENTITA FOKUSU V KARTE (Codex #281 kolo 2, P2) =========
// Karta sa prekresluje CELA, takze fokusovane tlacidlo zanikne. Identita, cez
// ktoru sa fokus vrati, je cista funkcia — testuje sa bez DOM.
eq(C.frontCardFocusKey({ t: 'door' }), 't:door', 'dlazdica typu');
eq(C.frontCardFocusKey({ k: 'direction', v: 'left', w: 'single' }), 's:direction|left|single',
   'segment s kridlom');
eq(C.frontCardFocusKey({ k: 'opening_mode', v: 'tipon' }), 's:opening_mode|tipon|',
   'segment bez kridla (kridlo je volitelne)');
eq(C.frontCardFocusKey({}), null, 'bez atributov ziadna identita');
eq(C.frontCardFocusKey(null), null, 'chybajuci vstup nespadne');
eq(C.frontCardFocusKey({ k: 'direction' }), null, 'kluc bez hodnoty = ziadna identita');
eq(C.frontCardFocusKey({ k: 'direction', v: '' }), null, 'prazdna hodnota tiez nie');

eq(C.frontCardFocusSelector('t:door'), '[data-t="door"]', 'spatna cesta: dlazdica');
eq(C.frontCardFocusSelector('s:direction|left|single'),
   '[data-k="direction"][data-v="left"][data-w="single"]', 'spatna cesta: segment s kridlom');
eq(C.frontCardFocusSelector('s:opening_mode|tipon|'),
   '[data-k="opening_mode"][data-v="tipon"]', 'bez kridla sa atribut do selektora nedava');
eq(C.frontCardFocusSelector(null), null, 'ziadna identita = ziadny selektor');
eq(C.frontCardFocusSelector('t:'), null, 'poskodeny kluc dlazdice');
eq(C.frontCardFocusSelector('s:direction||single'), null, 'poskodeny kluc segmentu');
eq(C.frontCardFocusSelector('nezmysel'), null, 'neznamy prefix');
// Okruzna cesta drzi pre VSETKY reálne ovladace karty.
C.FRONT_CARD_TYPES.forEach(t => {
  eq(C.frontCardFocusSelector(C.frontCardFocusKey({ t: t })), `[data-t="${t}"]`, `okruh: dlazdica ${t}`);
});
C.FRONT_DIR_OPTIONS.forEach(o => {
  eq(C.frontCardFocusSelector(C.frontCardFocusKey({ k: 'direction', v: o.value, w: 'single' })),
     `[data-k="direction"][data-v="${o.value}"][data-w="single"]`, `okruh: smer ${o.value}`);
});

// ============ 5) SYMBOLY NAHLADU ===========================================

eq(C.frontDirSymbol('left'), 'left', 'panty vlavo = sipka na volnu hranu vpravo');
eq(C.frontDirSymbol('right'), 'right');
eq(C.frontDirSymbol(UNSET), 'unknown', 'neurcene = otaznik, NIE strana');
eq(C.frontDirSymbol(null), null, 'LEGACY sa NEKRESLI (ziadny fallback na stranu)');
eq(C.frontDirSymbol(undefined), null, 'ani chybajuci stav');
eq(C.frontTypeSymbol('lift'), 'up');
eq(C.frontTypeSymbol('fall'), 'down');
eq(C.frontTypeSymbol('blind'), 'cross');
eq(C.frontTypeSymbol('drawer_front'), 'xdash',
   'D-115: zasuvka ma PRERUSOVANE X (od plneho X blendy ju lisi prave ciara)');
eq(C.frontTypeSymbol('door'), null, 'dvierka riesia kridla, nie typ');
eq(C.frontTypeSymbol('none'), null);

eq(C.frontWingSymbols(1, [slot('single', 'left')]), ['left'], '1 kridlo podla slotu');
eq(C.frontWingSymbols(1, [slot('single', null)]), [null], '1 kridlo LEGACY: nic');
eq(C.frontWingSymbols(1, []), [null], 'bez slotu sa strana NEHADA');
eq(C.frontWingSymbols(2, []), ['left', 'right'], 'dvojkridlo je ODVODENE (geometricky iste)');
eq(C.frontWingSymbols(3, [slot('p2', UNSET)]), ['left', 'unknown', 'right'],
   '3 kridla: krajne odvodene, stredne podla slotu');
eq(C.frontWingSymbols(3, []), ['left', null, 'right'],
   '3 kridla bez slotu: stredne sa NEKRESLI, krajne ano');
eq(C.frontWingSymbols(4, [slot('p2', 'left'), slot('p3', 'right')]),
   ['left', 'left', 'right', 'right'], '4 kridla');
eq(C.frontWingSymbols(0, []), [], 'ziadne kridlo = ziadny symbol');

// ============ 6) DOM: cela cesta riadok -> karta -> collectFronts ===========
//
// form.js kresli riadky nad globalmi, ktore v paneli zakladaju skripty pred nim
// (core.js, expr.js, settings.js, preview.js). V Node ich stavia tento blok —
// stubuju sa LEN cudzie zavislosti, cesta ciel bezi v originali.
const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.mmLabel = v => String(v);
// Zhodne s `NXIcons.svg` v `icons.js` — `<use …/>` je SAMOUZATVARACI, inak by
// mini-DOM parser zavrel nadradeny `<svg>` a rozbil strom riadku.
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
require(path.join(JS, 'preview.js'));
require(path.join(JS, 'board_card.js'));
Object.keys(C).forEach(k => { global[k] = C[k]; });
// Stav, ktory v paneli zije v core.js (v Node su to moduly, preto globaly).
global.FRONT_PROFILES = [];
global.frontItems = null;
global.frontSlots = null;
global.selectedCabId = null;
global.applyTimer = null;
// Cudzie zavislosti riadku (rady rozmerov, vyrazy, materialy, informacny stlpec).
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
// (a vrati sa skor len pri rozpisanom vyraze, co tu stubujeme na false) —
// pocitadlo nad nou je teda pocitadlo APPLY ciest (Codex #281 P2-C).
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
const FM = require(path.join(JS, 'form.js'));

const rows = mkEl('div');
rows.attrs.id = 'frontRows';
DOC.body.appendChild(rows);
function resetRows(){ rows.children = []; global.frontSlots = null; }
function rowOf(fid){
  return rows.querySelectorAll('.frow').find(r => r.dataset.frontId === fid);
}
function items(){ return FM.collectFronts().items; }
// Karta sa drzi cez IDENTITU cela a prezije prestavbu riadkov (to je vlastnost,
// nie chyba) — helper preto najprv zosynchronizuje stav s prave vykreslenymi
// riadkami, presne ako to robi `renderFronts`, a az potom klikne.
function openCard(fid){
  FM.refreshFrontCards();
  const b = rowOf(fid).querySelector('.ftname');
  if (b.getAttribute('aria-expanded') !== 'true') FM.onFrontCardToggle(b);
}

// --- 6a) OBRATENE PORADIE (D-23) prezije aj karta ---------------------------
resetRows();
[{ id: 'F1', type: 'door', wings: '1' },
 { id: 'F2', type: 'drawer_front' },
 { id: 'F3', type: 'door', wings: '1' }].forEach(it => FM.addFrontRow(it));
eq(rows.querySelectorAll('.frow').map(r => r.dataset.frontId), ['F3', 'F2', 'F1'],
   'DOM je obrateny (najvyssie celo hore)');
eq(items().map(x => x.id), ['F1', 'F2', 'F3'], 'collectFronts vracia DATOVE poradie (F1 dole)');

// --- 6b) klik na nazov typu otvori KARTU pod svojim riadkom -----------------
global.frontSlots = { F1: entry(1, [slot('single', null)]), F2: entry(1, []),
                      F3: entry(1, [slot('single', UNSET)]) };
FM.updateFrontDirBadges();
FM.refreshFrontCards();
eq(rows.querySelectorAll('.fcard').length, 0, 'na zaciatku je zbalene vsetko');
FM.onFrontCardToggle(rowOf('F1').querySelector('.ftname'));
eq(rows.querySelectorAll('.fcard').length, 1, 'otvorena je prave jedna karta');
ok(rowOf('F1').querySelector('.fcard'), 'a je v riadku, ktoreho sa tyka');
eq(rowOf('F1').querySelector('.ftname').getAttribute('aria-expanded'), 'true', 'stav nesie aria-expanded');
// Karta je POSLEDNA v stlpci — `.fmain` (nezalamovaci rad) ostava nedotknuty.
eq(rowOf('F1').children[rowOf('F1').children.length - 1].attrs.class, 'fcard',
   'karta je posledny potomok `.frow`');
eq(rowOf('F1').querySelectorAll('.fmain .fcard').length, 0, 'a NIE JE v rade ovladacov');
// Druhy klik ju zbali, klik na ine celo ju presunie.
FM.onFrontCardToggle(rowOf('F1').querySelector('.ftname'));
eq(rows.querySelectorAll('.fcard').length, 0, 'opatovny klik kartu zbali');
FM.onFrontCardToggle(rowOf('F1').querySelector('.ftname'));
FM.onFrontCardToggle(rowOf('F3').querySelector('.ftname'));
eq(rows.querySelectorAll('.fcard').length, 1, 'stale najviac jedna');
ok(rowOf('F3').querySelector('.fcard'), 'a je pri poslednom kliknutom cele');

// --- 6c) badge „smer?" chodi zo SERVERA -------------------------------------
eq(rowOf('F3').querySelector('.fbadge').textContent, 'smer?', 'neurceny smer sa v riadku prizna');
eq(rowOf('F1').querySelector('.fbadge'), null, 'LEGACY celo badge NEMA');
eq(rowOf('F2').querySelector('.fbadge'), null, 'zasuvka tiez nie');

// --- 6d) klik na dlazdicu zmeni typ a PRIZNA smer ---------------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'drawer_front' });
global.frontSlots = { F1: entry(2, []) };
openCard('F1');
eq(items()[0].type, 'drawer_front', 'vychodzi stav');
ok(items()[0].direction === undefined, 'a bez smeru');
const tileDoor = rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === 'door');
FM.onFrontTile(tileDoor);
eq(items()[0].type, 'door', 'dlazdica zmenila typ');
eq(items()[0].direction, UNSET, 'a smer sa PRIZNAL ako neurceny (pouzivatelska akcia)');
eq(rowOf('F1').querySelector('.ftname .ftl').textContent, 'Dvierka', 'nazov v riadku sa zmenil');
ok(rowOf('F1').querySelector('.ftico use').getAttribute('href') === '#i-door',
   'a ikona typu tiez (meni sa `href`, nie cely uzol)');
// Prepnutie SPAT nic nemaze (dormant).
FM.onFrontTile(rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === 'blind'));
eq(items()[0].type, 'blind', 'typ je blenda');
eq(items()[0].direction, UNSET, 'ale ulozeny smer ostal v configu (dormant)');
ok(rowOf('F1').querySelector('.ftico use').getAttribute('href') === '#i-front-blind',
   'blenda ma vlastnu ikonu (uz nie fallback)');
// Klik na UZ NASADENY typ nesmie vyrobit prazdny krok Spat.
const extraBefore = rowOf('F1').dataset.frontExtra;
FM.onFrontTile(rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === 'blind'));
eq(rowOf('F1').dataset.frontExtra, extraBefore, 'klik na nasadeny typ nic nemeni');

// --- 6e) klik na segrow zapise PRESNE hodnotu tlacidla ----------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: '1' });
global.frontSlots = { F1: entry(1, [slot('single', null)]) };
openCard('F1');
const segs = rowOf('F1').querySelectorAll('.segrow button');
eq(segs.filter(b => b.dataset.k === 'direction').map(b => b.dataset.v), ['left', UNSET, 'right'],
   'ponuka smeru: Ľavé · Neurčené · Pravé');
eq(segs.filter(b => b.dataset.k === 'direction').filter(b => b.attrs.class.indexOf('on') >= 0).length, 0,
   'LEGACY celo nema ziadnu volbu zvyraznenu');
FM.onFrontSeg(segs.find(b => b.dataset.k === 'direction' && b.dataset.v === 'right'));
eq(items()[0].direction, 'right', 'klik zapisal stranu');
FM.onFrontSeg(rowOf('F1').querySelectorAll('.segrow button')
  .find(b => b.dataset.k === 'direction' && b.dataset.v === UNSET));
eq(items()[0].direction, UNSET, 'a „Neurčené" sa da zvolit spat');
FM.onFrontSeg(rowOf('F1').querySelectorAll('.segrow button')
  .find(b => b.dataset.k === 'opening_mode' && b.dataset.v === 'tipon'));
eq(items()[0].opening_mode, 'tipon', 'Tip-On sa ulozi');
eq(items()[0].drawer, undefined, 'a klasifikacia zasuvky sa tym NEVYROBILA');

// --- 6f) pocet kridiel: 3/4 pridaju otazku na STREDNE kridla ---------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: '1', direction: 'left' });
global.frontSlots = { F1: entry(1, [slot('single', 'left')]) };
const fw = rowOf('F1').querySelector('.fw');
fw.value = '4';
FM.onFrontWings(fw);
eq(items()[0].wing_directions, { p2: UNSET, p3: UNSET }, '4 kridla: obe stredne su neurcene');
eq(items()[0].direction, 'left', 'a scalarny smer ostal (dormant pre navrat na 1 kridlo)');
fw.value = '1';
FM.onFrontWings(fw);
eq(items()[0].wing_directions, { p2: UNSET, p3: UNSET }, 'navrat na 1 kridlo NIC NEMAZE');

// --- 6g) NEGATIVNY TEST: legacy celo prejde celym koleckom BEZ klucov -------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: 'auto' }); // ziadne dormant polia
global.frontSlots = { F1: entry(1, [slot('single', null)]) };
eq(rowOf('F1').dataset.frontExtra, undefined, 'riadok nenesie ani prazdny dataset');
openCard('F1');                                             // render karty
FM.refreshFrontCards();                                     // a este raz (echo)
const it0 = items()[0];
eq(it0.direction, undefined, 'render smer NEVYROBIL');
eq(it0.opening_mode, undefined, 'ani otvaranie');
eq(it0.drawer, undefined, 'ani klasifikaciu zasuvky');
eq(it0.wing_directions, undefined, 'ani kridla');
// Editacia INEHO pola (vyska) polozku tiez nesmie „doplnit".
rowOf('F1').querySelector('.fh').value = '355';
eq(items()[0].direction, undefined, 'editacia vysky smer nevyrobi');
eq(items()[0].height, 355, 'a vyska sa normalne ulozi');
eq(rowOf('F1').dataset.frontExtra, undefined, 'dataset ostal prazdny po CELOM kolecku');

// --- 6h) P1: „+ pridaj dvere" JE pouzivatelska akcia -----------------------
// Bez tohto by kazde NOVE celo natrvalo obislo RED nalez, badge aj `?`
// v nahlade: Ruby by ho citalo ako legacy (kluc smeru chyba), takze by sa
// nikdy nikoho nespytalo, na ktoru stranu ma panty.
resetRows();
FM.addFrontKind('door');
eq(items().length, 1, '„+ pridaj dvere" pridalo riadok');
eq(items()[0].type, 'door', 'a je to typ dvierka');
eq(items()[0].direction, UNSET, 'NOVE dvierka maju smer PRIZNANY ako neurceny');
eq(items()[0].opening_mode, undefined, 'ale otvaranie sa NEVYMYSLA');
eq(items()[0].drawer, undefined, 'ani klasifikacia zasuvky');
// D-84 „+ pridaj čelo" (zasuvkove) nevyraba NIC — smer sa zasuvky netyka.
resetRows();
FM.addFrontKind('drawer_front');
eq(items()[0].type, 'drawer_front', 'druhe tlacidlo pridava zasuvkove celo');
eq(rowOf(items()[0].id).dataset.frontExtra, undefined, 'a riadok nenesie ziadne dormant pole');
// RENDER existujucej polozky (nie userAdd) sa dalej nedotkne NICOHO.
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: '1' });
eq(items()[0].direction, undefined, 'render ulozeneho cela smer NEVYROBI (nematerializacia plati)');

// --- 6i) P2-B: otvorena karta patri KONKRETNEJ skrinke ---------------------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: '1' });
global.frontSlots = { F1: entry(1, [slot('single', null)]) };
openCard('F1');
eq(rows.querySelectorAll('.fcard').length, 1, 'karta F1 je otvorena');
// Echo TEJ ISTEJ skrinky ju necha.
FM.syncFrontCardOwner('CAB-001', 'CAB-001');
FM.refreshFrontCards();
eq(rows.querySelectorAll('.fcard').length, 1, 'echo tej istej skrinky kartu NECHAVA');
// Payload INEJ skrinky (ktora ma tiez celo F1) ju musi zavriet.
FM.syncFrontCardOwner('CAB-001', 'CAB-002');
FM.refreshFrontCards();
eq(rows.querySelectorAll('.fcard').length, 0, 'ina skrinka s tym istym F1 = karta sa ZATVARA');
// Odchod z korpusu uplne (doska, prazdny vyber, navrh vkladania).
openCard('F1');
eq(rows.querySelectorAll('.fcard').length, 1, 'karta sa da otvorit znova');
FM.closeFrontCard();
FM.refreshFrontCards();
eq(rows.querySelectorAll('.fcard').length, 0, 'odchod z korpusu kartu zavrie');

// --- 6j) P2-C: klik na UZ AKTIVNU volbu = ziadny prazdny krok Spat ---------
resetRows();
FM.addFrontRow({ id: 'F1', type: 'door', wings: '1' });
global.frontSlots = { F1: entry(1, [slot('single', null)]) };
openCard('F1');
function segBtn(k, v){
  return rowOf('F1').querySelectorAll('.segrow button').find(b => b.dataset.k === k && b.dataset.v === v);
}
FM.onFrontSeg(segBtn('direction', 'left'));
eq(items()[0].direction, 'left', 'prvy klik zapisal stranu');
const applyAfterFirst = applyCalls;
const dsAfterFirst = rowOf('F1').dataset.frontExtra;
eq(segBtn('direction', 'left').getAttribute('aria-pressed'), 'true', 'volba je aktivna');
FM.onFrontSeg(segBtn('direction', 'left'));
eq(applyCalls, applyAfterFirst, 'druhy klik na TU ISTU volbu NESPUSTI apply (ziadny krok Spat)');
eq(rowOf('F1').dataset.frontExtra, dsAfterFirst, 'a dataset ostal bitovo rovnaky');
// Klik na INU volbu samozrejme zapisuje dalej.
FM.onFrontSeg(segBtn('direction', 'right'));
eq(items()[0].direction, 'right', 'zmena volby sa zapise');
ok(applyCalls > applyAfterFirst, 'a apply sa spusti');

// --- 6k) kolo 2 P2: prekreslenie karty NESMIE zhodit fokus -----------------
// Bez obnovy by po KAZDEJ klavesovej zmene (dlazdica/segment) fokus spadol na
// `<body>` a pouzivatel klavesnice by musel pretabovat cely Inspector.
resetRows();
FM.addFrontRow({ id: 'F1', type: 'drawer_front' });
// Zaznam servera pre jednokridlove dvierka — po prepnuti typu sa v karte
// objavi riadok smeru, na ktorom sa da fokus overit.
global.frontSlots = { F1: entry(1, [slot('single', null)]) };
openCard('F1');
function tileBtn(t){ return rowOf('F1').querySelectorAll('.typetile').find(b => b.dataset.t === t); }
// (a) DLAZDICA typu: fokus ostane na dlazdici, ktora sa prave zapla.
const doorTile = tileBtn('door');
doorTile.focus();
ok(DOC.activeElement === doorTile, 'fokus je na dlazdici pred zmenou');
FM.onFrontTile(doorTile);
// POZN.: mini-DOM (na rozdiel od prehliadaca) nechava `activeElement` aj na
// ODPOJENOM uzle, preto sa neoveruje „nie je null", ale to podstatne: fokus
// sedi na uzle, ktory je v ZIVEJ karte — teda na cerstvo vykreslenom tlacidle.
ok(DOC.activeElement !== doorTile, 'fokus NEostal na uzle, ktory prekreslenim zanikol');
ok(DOC.activeElement && DOC.activeElement.closest('.fcard') === rowOf('F1').querySelector('.fcard'),
   'fokus je v ZIVEJ karte, nie na odpojenom zvysku');
eq(DOC.activeElement && DOC.activeElement.dataset.t, 'door',
   'fokus sa vratil na dlazdicu S ROVNAKOU identitou');
eq(DOC.activeElement.attrs.class.indexOf('on') >= 0, true, 'a je to uz tá aktivna');
// (b) SEGMENT: to iste pre smer (a kridlo je sucastou identity).
const rightSeg = rowOf('F1').querySelectorAll('.segrow button')
  .find(b => b.dataset.k === 'direction' && b.dataset.v === 'right');
rightSeg.focus();
FM.onFrontSeg(rightSeg);
eq(items()[0].direction, 'right', 'zmena sa zapisala');
eq(DOC.activeElement && DOC.activeElement.dataset.k, 'direction', 'fokus ostal na segmente smeru');
eq(DOC.activeElement && DOC.activeElement.dataset.v, 'right', 'a na tej istej volbe');
eq(DOC.activeElement && DOC.activeElement.dataset.w, 'single', 'kridlo je sucastou identity');
ok(DOC.activeElement.closest('.fcard') === rowOf('F1').querySelector('.fcard'),
   'a aj tu je fokus v ZIVEJ karte');
// (c) Fokus MIMO karty sa prekreslenim nesmie hnut.
const fh = rowOf('F1').querySelector('.fh');
fh.focus();
FM.refreshFrontCards();
ok(DOC.activeElement === fh, 'fokus mimo karty ostava, kde bol');

console.log(`OK test_kova2a_karta.js — ${n} kontrol`);
