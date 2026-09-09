// KOV-C2c — UI ZASUVIEK: riadok karty cela + zastavujuci riadok Nakupu.
//
// Preco su to testy a nie klikanie v paneli:
//   1. SERVER JE AUTORITA. Karta smie kreslit LEN to, co poslal `front_drawer`.
//      Keby si stav (system, vysku, NL) odvodila z klasifikacie alebo
//      z polozky kovania, ukazovala by cisla, ktore stavba nikdy nevydala —
//      a pri fail-closed zasuvke by tvrdila, ze zasuvka existuje.
//   2. VERTIKALNY PRIESTOR. Vyriesena zasuvka smie zabrat PRAVE JEDEN riadok;
//      vety receptu ziju v rozbalitelnom detaile. Regresiu (druhy blok navyse)
//      je z obrazovky tazke vsimnut, z view-modelu trivialne.
//   3. KONFLIKT NAHRADZA. Cerveny dovod nesmie stat VEDLA hodnot — inak by
//      karta hovorila dve veci naraz.
//   4. ZAVAZNOST V NAKUPE URCUJE SERVER. Klient nepozna enum dovodov; cerveny
//      riadok kresli VYHRADNE podla priznaku `blocks_export`.
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

// Tvar zaznamu zo servera (`Panel.front_drawer_payload`).
const OKROW = { state: 'ok', text: 'Atira · H70 · NL 470 · 30 kg · SiSy · recept v1',
                detail: ['Recept: Atira SiSy v1 (atira_sisy_v1)', 'Nosnosť bunky: 30 kg'] };
function drawerItem(){ return { type: 'drawer_front', opening_mode: 'classic',
                                drawer: { construction: 'metal', variant: 'standard' } }; }
function entry(){ return { wings_n: 1, slots: [] }; }
function kinds(m){ return m.rows.map(r => r.kind); }
function rowOf(m, kind){ return m.rows.filter(r => r.kind === kind); }

// ============ 1) ciste jadro: frontDrawerRows ==============================

eq(C.frontDrawerRows(null), [], 'ziadny zaznam servera = ziadny riadok zasuvky');
eq(C.frontDrawerRows(undefined), [], 'chybajuci zaznam = ziadny riadok');
eq(C.frontDrawerRows({ state: 'pending' }), [],
   'klasifikovane celo bez vysledku stavby MLCI (nic sa nedomyslá)');

const okRows = C.frontDrawerRows(OKROW);
eq(okRows.length, 1, 'vyriesena zasuvka = PRAVE JEDEN riadok (vertikalny priestor)');
eq(okRows[0].kind, 'resolved', 'riadok je read-only zhrnutie');
eq(okRows[0].text, OKROW.text, 'text riadku sklada SERVER — klient ho nemeni');
eq(okRows[0].detail, OKROW.detail, 'vety receptu idu do rozbalitelneho detailu');
eq(okRows[0].note, null, 'bez rucneho zamku ziadna poznamka');

const locked = C.frontDrawerRows(Object.assign({}, OKROW, { locked_note: 'Dĺžka je zamknutá.' }));
eq(locked[0].note, 'Dĺžka je zamknutá.', 'poznamka o zamku je SERVEROVY text');
eq(locked.length, 1, 'zamok NEPRIDAVA riadok (chipy zamkov su KOV-D)');

const conflict = C.frontDrawerRows({ state: 'conflict', message: 'Nezmestí sa.' });
eq(conflict.length, 1, 'konflikt = jeden riadok');
eq(conflict[0].kind, 'info', 'konflikt kresli informacny riadok, nie zhrnutie');
eq(conflict[0].tone, 'err', 'konflikt je CERVENY');
eq(conflict[0].text, 'Nezmestí sa.', 'veta je zo STAVBY (klient ju neskladá)');
ok(conflict[0].icon, 'cerveny riadok nesie ikonu (sprite, ziadne emoji)');
eq(C.frontDrawerRows({ state: 'conflict', message: '' }), [],
   'konflikt bez vety sa nekresli (prazdny cerveny riadok je horsi nez ziadny)');

const stale = C.frontDrawerRows({ state: 'stale' });
eq(stale.length, 1, 'nemigrovana zasuvka = jeden cerveny riadok');
eq(stale[0].tone, 'err', 'nemigrovana zasuvka blokuje exporty — je cervena');
ok(stale[0].text.indexOf('prestav') >= 0, 'veta menuje NAPRAVU (prestavbu)');

const sync = C.frontDrawerRows(Object.assign({}, OKROW, { sync: 'Pridaj sync tyč.' }));
eq(sync.length, 2, 'sync odporucanie je riadok NAVIAC k vyriesenej zasuvke');
eq(sync[1].tone, 'warn', 'sync je JANTAROVE odporucanie, nie chyba');
eq(sync[1].text, 'Pridaj sync tyč.', 'text sklada server');

// ============ 2) view-model karty ==========================================

const mNone = C.frontCardModel(drawerItem(), entry());
ok(kinds(mNone).indexOf('resolved') < 0,
   'bez `front_drawer` karta riadok zasuvky NEKRESLI (stary payload, navrh vkladania)');

const mOk = C.frontCardModel(drawerItem(), entry(), OKROW);
eq(rowOf(mOk, 'resolved').length, 1, 'karta zasuvky ma prave jeden resolved riadok');
const segKeys = mOk.rows.filter(r => r.kind === 'seg').map(r => r.key);
eq(segKeys, ['opening_mode', 'drawer_construction', 'drawer_variant'],
   'klasifikacne segmenty ostavaju nezmenene (C2c nemeni KOV-A2a)');
ok(mOk.rows.indexOf(rowOf(mOk, 'resolved')[0]) > mOk.rows.indexOf(mOk.rows.filter(r => r.kind === 'seg').pop()),
   'resolved riadok je POD klasifikaciou (mockup scena 1)');

const mDoor = C.frontCardModel({ type: 'door' }, entry(), OKROW);
ok(kinds(mDoor).indexOf('resolved') < 0,
   'zaznam zasuvky sa na DVIERKA nikdy nelepi');

// Karta bez klasifikacie: informacna veta ostava, riadok zasuvky nie.
const mBare = C.frontCardModel({ type: 'drawer_front' }, entry());
const info = rowOf(mBare, 'info').map(r => r.text).join(' ');
ok(info.indexOf('bez klasifikácie') >= 0, 'nezklasifikovana zasuvka to prizna');
ok(info.indexOf('KOV-C') < 0, 'text uz neodkazuje na dávku, ktorá je hotová');

// Codex #306 P2: CIASTOCNA klasifikacia. Pre server je celo, ktore ma UZ LEN
// otvaranie, klasifikovane (`recipe_key_for` != :legacy) — vyda k nemu konflikt.
// Veta „bez klasifikácie" nad cervenym dovodom = dve tvrdenia naraz.
function infoTextsOf(m){ return rowOf(m, 'info').map(r => r.text).join(' '); }
const CONF = { state: 'conflict', message: 'Zásuvka nie je klasifikovaná.' };

const mPartial = C.frontCardModel({ type: 'drawer_front', opening_mode: 'classic' }, entry(), CONF);
ok(infoTextsOf(mPartial).indexOf('bez klasifikácie') < 0,
   'pri ciastocnej klasifikacii veta „bez klasifikácie" ZMIZNE (server uz hovori)');
eq(rowOf(mPartial, 'info').length, 1, 'ostane PRAVE JEDEN informacny riadok — ten cerveny');
eq(rowOf(mPartial, 'info')[0].tone, 'err', 'a je to dovod zo servera');

// To iste bez zaznamu servera: samotne otvaranie uz nie je „bez klasifikácie"
// (server by ho tak nenazval), takze veta sa nekresli ani vtedy.
ok(infoTextsOf(C.frontCardModel({ type: 'drawer_front', opening_mode: 'classic' }, entry()))
     .indexOf('bez klasifikácie') < 0,
   'zvolene otvaranie samo o sebe uz klasifikaciu ZACALO');
ok(infoTextsOf(C.frontCardModel({ type: 'drawer_front', drawer: { construction: 'metal' } }, entry()))
     .indexOf('bez klasifikácie') < 0,
   'zvolena konstrukcia tiez');
// A vyriesena zasuvka uz vetu nema tym skor.
ok(infoTextsOf(C.frontCardModel(drawerItem(), entry(), OKROW)).indexOf('bez klasifikácie') < 0,
   'vyriesena zasuvka vetu „bez klasifikácie" NEMA');

// ============ 3) render karty (DOM) ========================================

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
global.el = id => DOC.getElementById(id);
global.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
global.window = global.window || {};
global.mmLabel = v => String(v);
// Zhodne s `NXIcons.svg` v `icons.js` — `<use …/>` je SAMOUZATVARACI, inak by
// mini-DOM parser zavrel nadradeny `<svg>` a rozbil strom riadku.
global.NXIcons = {
  svg: (id, cls) => '<svg class="ic' + (cls ? ' ' + cls : '') + '"><use href="#i-' + id + '"/></svg>',
  set: (node, id) => { const u = node.querySelector('use'); if (u) u.setAttribute('href', '#i-' + id); }
};
global.window.NXIcons = global.NXIcons;
global.NXInsert = require(path.join(JS, 'insert_state.js'));
global.NXShell = { ctxEnabled: () => true, setViewContext: () => {} };
global.FRONT_PROFILES = [];
global.frontItems = null;
global.frontSlots = null;
global.frontDrawer = null;
global.frontLift = null;     // KOV-E2: zaznam vyklopu (front_lift) — form.js ho cita
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
global.refreshMaterialFilters = () => {};
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
// V paneli ziju vsetky skripty v JEDNOM globalnom rozsahu — v Node treba
// ciste jadro (`core.js`) vystavit rovnako, inak `form.js` nevidi jeho funkcie.
Object.keys(C).forEach(k => { global[k] = C[k]; });
const FM = require(path.join(JS, 'form.js'));

const rows = mkEl('div');
rows.attrs.id = 'frontRows';
DOC.body.appendChild(rows);

function renderCard(fid, drawerRec){
  rows.children = [];
  global.frontDrawer = drawerRec ? { [fid]: drawerRec } : null;
  FM.addFrontRow({ id: fid, type: 'drawer_front', opening_mode: 'classic',
                   drawer: { construction: 'metal', variant: 'standard' } });
  FM.refreshFrontCards();
  const row = rows.querySelectorAll('.frow')[0];
  const b = row.querySelector('.ftname');
  if (b.getAttribute('aria-expanded') !== 'true') FM.onFrontCardToggle(b);
  return row.querySelector('.fcard').innerHTML;
}

const htmlOk = renderCard('F2', OKROW);
ok(htmlOk.indexOf('class="drow"') >= 0, 'karta kresli riadok zasuvky');
ok(htmlOk.indexOf('Atira · H70 · NL 470') >= 0, 'riadok nesie serverovy text');
ok(htmlOk.indexOf('<details class="ddet">') >= 0, 'vety receptu su ROZBALITELNE (nie trvaly blok)');
ok(htmlOk.indexOf('Nosnosť bunky: 30 kg') >= 0, 'detail nesie vety zo servera');

const htmlConf = renderCard('F2', { state: 'conflict', message: 'Nezmestí sa <b>tu</b>.' });
ok(htmlConf.indexOf('inforow err') >= 0, 'konflikt je cerveny riadok');
ok(htmlConf.indexOf('Nezmestí sa &lt;b&gt;tu&lt;/b&gt;.') >= 0,
   'serverovy text sa ESKAPUJE (payload moze niest cudzie znaky)');
ok(htmlConf.indexOf('class="drow"') < 0, 'pri konflikte sa hodnoty NEKRESLIA');

const htmlSync = renderCard('F2', Object.assign({}, OKROW, { sync: 'Pridaj sync tyč.' }));
ok(htmlSync.indexOf('inforow warn') >= 0, 'sync je jantarovy riadok');
ok(htmlSync.indexOf('i-alert') >= 0, 'riadok nesie sprite ikonu (ziadne emoji)');
ok(htmlSync.indexOf('class="drow"') >= 0, 'sync riadok NENAHRADZA zhrnutie');

const htmlNone = renderCard('F2', null);
ok(htmlNone.indexOf('class="drow"') < 0, 'bez zaznamu servera karta riadok nekresli');
ok(htmlNone.indexOf('typegrid') >= 0, 'zvysok karty sa tym nemeni');

// ============ 4) NAKUP: zastavujuci riadok =================================

global.document = { addEventListener: function(){}, getElementById: function(){ return null; } };
const S = require(path.join(JS, 'studio.js'));

const STOP = { generic_type: 'slide', cabinet_id: 'CAB-2', owner_part_key: 'front:F2/panel',
               quantity: 1, reason: 'drawer_kit_missing', base_reason: 'nl_missing',
               reason_sk: 'set „atira" nemá kód pre dĺžku NL 470', blocks_export: true };
const SOFT = { generic_type: 'slide', cabinet_id: 'CAB-1', owner_part_key: 'front:F1/panel',
               quantity: 2, reason: 'nl_missing', reason_sk: 'set „x" nemá kód pre dĺžku NL 470' };

ok(S.hwRowStops(STOP), 'zastavujuca polozka sa pozna podla SERVEROVEHO priznaku');
ok(!S.hwRowStops(SOFT), 'bezna nemapovana polozka exporty nezastavuje');
ok(!S.hwRowStops(null), 'chybajuca polozka nic nezastavuje');
ok(!S.hwRowStops({ reason: 'drawer_kit_missing' }),
   'sam dovod NESTACI — klient enum dovodov nepozna (zavaznost urcuje server)');
// Codex #306 P2: veta hovori o ZASUVKACH, nie o riadkoch. Set s viacerymi
// clenmi bez kodu vyda VIAC zaznamov na TU ISTU zasuvku (`expand_members`) —
// „2× zásuvka" pri jednej zasuvke by bola lož.
const STOP_M2 = Object.assign({}, STOP, { member_index: 1,
                                          reason_sk: 'set „atira" nemá pásmo pre člena 2' });
const STOP_OTHER = Object.assign({}, STOP, { cabinet_id: 'CAB-3',
                                             owner_part_key: 'front:F5/panel' });
eq(S.hwStopCount([STOP, STOP_M2]), 1,
   'dva chybajuce kody JEDNEJ zasuvky su JEDNA zasuvka');
eq(S.hwStopCount([STOP, STOP_M2, STOP_OTHER]), 2,
   'ina skrinka/vlastnik = ina zasuvka');
eq(S.hwStopOwners([STOP, STOP_M2, STOP_OTHER]),
   ['CAB-2|front:F2/panel', 'CAB-3|front:F5/panel'],
   'identita zasuvky = skrinka + vlastnik (poradie zo servera)');
eq(S.hwStopCount([STOP, SOFT, STOP]), 1, 'pocita sa len to, co server oznacil — a raz');
eq(S.hwStopNoteHtml([SOFT]), '', 'bez zastavujucej polozky ziadna veta');
ok(S.hwStopNoteHtml([STOP, STOP_M2]).indexOf('1× zásuvka') >= 0,
   'veta menuje POCET ZASUVIEK, nie pocet riadkov');
// Tabulka pod vetou ostava po RIADKOCH — kazdy z nich je naozaj chybajuci kod.
const HS2 = { state_status: 'ok', rows: [], unmapped: [STOP, STOP_M2], summary: {} };
eq((S.buySection(HS2, []).match(/hwmiss hwstop/g) || []).length, 2,
   'dva chybajuce kody = dva cervene riadky (aj ked je to jedna zasuvka)');

const note = S.hwStopNoteHtml([STOP, SOFT]);
ok(note.indexOf('hwbanner-stop') >= 0, 'veta ma vlastnu (cervenu) triedu');
ok(note.indexOf('VEPO') >= 0, 'veta hovori, ze sa nevytvori ANI VEPO');

const HS = { state_status: 'ok', rows: [], unmapped: [STOP, SOFT], summary: {} };
const H = S.buySection(HS, []);
ok(H.indexOf('class="hwmiss hwstop"') >= 0, 'zastavujuci riadok je CERVENY');
ok(H.indexOf('<tr class="hwmiss">') >= 0, 'bezny nemapovany riadok ostava jantarovy');
ok(H.indexOf('hwbanner-stop') >= 0, 'nad tabulkou stoji vysvetlujuca veta');
ok(H.indexOf('nemá kód pre dĺžku NL 470') >= 0, 'dovod je SERVEROVY text (base_reason)');

console.log(`test_kovc2c_karta: ${n} assertov OK`);
