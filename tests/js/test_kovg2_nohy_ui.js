// KOV-G2 (D-111) — RIADOK „NOHY" a SEGMENT NÔH V GHOST PÁSIKU (klient).
//
// Preco su to testy a nie klikanie:
//   1. Riadok ma DVE cesty (vkladacia karta vs. oznacena skrinka) a jeden
//      vzhlad. Regresia sa prejavi tym, ze pri vkladani ostane visiet text
//      predtym oznacenej skrinky — cize klamstvo, ktore v CEF nikto nezbada.
//   2. Nahlad vkladania chodi ASYNCHRONNE s generaciou dotazu. Bez nej by
//      pomalsie kolo (sirka 900) prepisalo cerstvejsi vysledok (sirka 1200)
//      a riadok by ukazoval nohy, ktore skrinka nedostane.
//   3. Text nahladu je VYSTUP servera — nesmie sa dostat do `collectAll()`
//      ani do vkladacieho payloadu (inak by sa „6× noha AXILO" pokusilo
//      ulozit do configu).
//   4. Pasik ma segment kreslit LEN pre skrinku a LEN ked ho push naozaj
//      nesie (starsi server kluc neposiela).
//
// MUTACIE (kazda overena spustenim — po zaneseni chyby spadnu uvedene testy):
//   M1 `nxLegsInsertResult` prestane porovnavat `gen`
//      -> „(2): odpoved STARSIEHO kola sa zahodi"
//   M2 `nxGhostLegsText` nekontroluje subjekt (segment aj pre DOSKU)
//      -> „(3): pasik DOSKY segment noh nekresli"
//   M3 `nxLegsInsertMode` prestane pozerat na `selectedCabId`
//      -> „(2): odpoved, ktora dosla PO oznaceni skrinky, sa zahodi"
//   M4 (Codex #339 kolo 1 N1) `nxLegsInsertPayload` nepriklada kovanie SABLONY
//      -> „(4): mapovanie setov zo sablony ide TYM ISTYM zdrojom…"
//   M5 (N3) `nxLegsInsertDrop` nezdvihne generaciu
//      -> „(6): oneskorena odpoved na UZ NEPLATNY dotaz sa zahodi"
//   M6 (N3) `nxLegsInsertResult` prestane kontrolovat typ
//      -> „(6): riadok Noh patri VYHRADNE dolnej skrinke"
//   M7 (N4) `NX.setHardwareSets` prestane prekreslovat riadok Noh
//      -> „(7): lahky push prekresli aj riadok Noh"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// --- kostra panela: riadok Noh + pasik (id-cka su kontrakt HTML <-> JS) ------
const CARD = mkEl('div');
CARD.innerHTML =
  '<div class="legsrow" id="legsRow" hidden>' +
  '<span class="legslbl">Nohy</span><b class="legstxt" id="legsTxt">—</b>' +
  '<span class="legssel" id="legsSel"></span></div>' +
  '<input id="width" type="text"><input id="floor_height" type="text">' +
  '<select id="plinth_mode"><option value="none">none</option></select>';
DOC.body.appendChild(CARD);

const BAR = mkEl('div');
BAR.attrs.id = 'ghostBar';
BAR.hidden = true;
BAR.innerHTML =
  '<span class="gbanchor" id="gbAnchor">' +
  '<span class="gbdot" data-anchor="fl_bottom"></span></span>' +
  '<span class="gbtxt" id="gbRot">0°</span><span class="gbtxt" id="gbMode">zámok</span>' +
  '<span class="gbtxt gbori" id="gbOri"></span>' +
  '<span class="gbtxt gbphase" id="gbPhase" hidden></span>' +
  '<span class="gbtxt gblegs" id="gbLegs" hidden></span>' +
  '<span class="gblock" id="gbLockWrap"><input id="gbLockZ" type="text"></span>' +
  '<button class="gbinfo" id="gbInfo"></button>';
DOC.body.appendChild(BAR);

// --- globaly, ktore hardware.js a ghost_bar.js pouzivaju ---------------------
global.el = function(id){ return DOC.getElementById(id); };
global.esc = function(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
global.NXIcons = { svg: function(name){ return '<svg><use href="#i-' + name + '"/></svg>'; } };
global.NX = { setStatus: function(){} };

const SENT = [];
global.sketchup = new Proxy({}, {
  get: function(_t, name){
    return function(json){ SENT.push({ cb: String(name), data: JSON.parse(json) }); };
  },
  has: function(){ return true; }
});
global.window.sketchup = global.sketchup;
global.nxDocPayload = function(p){ const o = p || {}; o.model_guid = 'GUID-1'; return JSON.stringify(o); };

// Zrkadlo `collectAll()` z form.js — pozbiera POLIA formulara, nikdy vystupy.
global.collectAll = function(){
  return { type: global.__type, width: Number(global.el('width').value),
           floor_height: Number(global.el('floor_height').value) };
};

global.__type = 'lower';
global.getType = function(){ return global.__type; };
global.val = function(id){ const e = global.el(id); return e ? e.value : null; };
global.numv = function(id){
  const e = global.el(id);
  if (!e || String(e.value).trim() === '') return NaN;
  return Number(e.value);
};
global.selectedCabId = null;
global.NXInsert = { state: { kind: 'cabinet', lastMode: 'insert' } };

const HW = require(path.join(JS, 'hardware.js'));
const GB = require(path.join(JS, 'ghost_bar.js'));

function setFields(w, fh, mode){
  global.el('width').value = String(w);
  global.el('floor_height').value = String(fh);
  global.el('plinth_mode').value = mode || 'none';
}
function rowHidden(){ return !!global.el('legsRow').hidden; }

// minidom drzi text uzla v deti typu #text — pomocka na jeho precitanie.
function textOfEl(id){
  const e = global.el(id);
  if (!e) return '';
  return e.children.filter(function(c){ return c.tagName === '#text'; })
          .map(function(c){ return c.text; }).join('');
}

// ===========================================================================
// 1) OZNACENA SKRINKA: text + select setu
// ===========================================================================
const LEG_ENTRY = {
  generic_type: 'leg', label: 'Nohy',
  project_set_id: 'nohy-podla-sokla', project_set_name: 'Nohy podľa výšky sokla',
  project_label: 'podľa projektu — Nohy podľa výšky sokla',
  override_set_id: null, override_selector: null, override_label: null,
  owner_overrides: {}, owner_default_label: 'podľa projektu', compat: null, status: 'ok',
  options: [{ set_id: 'nohy-podla-sokla', name: 'Nohy podľa výšky sokla' },
            { set_id: 'nohy-vlastne', name: 'Moje nohy' }]
};
const SUMMARY_OK = {
  text: '6× noha AXILO H100 + platnička · 2× príchyt sokla AXILO',
  short: '6× noha AXILO H100 · 2× príchyt sokla AXILO',
  tone: 'ok', set_id: 'nohy-podla-sokla', set_name: 'Nohy podľa výšky sokla'
};

HW.refreshHardwareSets([LEG_ENTRY]);
ok(HW.renderLegsRow(SUMMARY_OK, 'CAB-001'), 'riadok Noh sa pri oznacenej skrinke kresli');
ok(!rowHidden(), 'a je viditelny');
eq(textOfEl('legsTxt'), SUMMARY_OK.text, 'text kresli SERVER — klient si nic nedopocitava');
ok(global.el('legsTxt').getAttribute('title').indexOf('Nohy podľa výšky sokla') >= 0,
   'tooltip prizna UCINNY set (do riadku sa uz nezmesti)');

const SEL = global.el('legsSel').children.filter(function(c){ return c.tagName === 'SELECT'; })[0];
ok(!!SEL, 'v riadku stoji select setu noh');
eq(SEL.getAttribute('data-gt'), 'leg', 'a je to ten isty ovladac ako v Kovanie -> Sety');
eq(SEL.getAttribute('data-cab'), 'CAB-001', 'nesie identitu RENDROVANEJ skrinky');
eq(SEL.getAttribute('data-owner'), '', 'vyber plati na CELU skrinku, nie na dielec');
eq(SEL.children.filter(function(c){ return c.tagName === 'OPTION'; }).length, 3,
   '„podľa projektu" + dva sety z ponuky servera');

// Zivy refresh ponuky (D-75) musi prekreslit AJ tento select — inak by novy
// set typu ostal viditelny len v skupine Sety.
HW.refreshHardwareSets([Object.assign({}, LEG_ENTRY, {
  options: LEG_ENTRY.options.concat([{ set_id: 'nohy-nove', name: 'Nové nohy' }])
})]);
eq(SEL.children.filter(function(c){ return c.tagName === 'OPTION'; }).length, 4,
   'riadok Noh je TRETI kontajner selectov (#legsRow)');

// Zapis ide EXISTUJUCOU akciou — ziadny novy zapisovy callback.
SENT.length = 0;
SEL.value = 'nohy-vlastne';
HW.onHwSet(SEL);
eq(SENT.length, 1, 'zmena setu odosle prave jeden zapis');
eq(SENT[0].cb, 'set_hardware_set', 'existujucou akciou (D1a), nie novym kanalom');
eq(SENT[0].data.generic_type, 'leg', 'pre typ `leg`');
eq(SENT[0].data.set_id, 'nohy-vlastne', 'a s vybranym setom');
eq(SENT[0].data.cabinet_id, 'CAB-001', 'identita skrinky ide s payloadom');

// „bez nôh" (horna skrinka, skrinka bez podstavca) riadok NEKRESLI.
eq(HW.renderLegsRow({ text: 'bez nôh', short: 'bez nôh', tone: 'none' }, 'CAB-001'), false,
   'ton `none` = riadok sa nekresli (vertikalny priestor panela je vzacny)');
ok(rowHidden(), 'a je skryty');
eq(global.el('legsSel').innerHTML, '',
   'skryty riadok sa aj VYPRAZDNI — inak by v nom ostal select cudzej skrinky');

// Jantarovy ton = trieda `warn` na riadku (farbu urcuje CSS, nie JS).
HW.renderLegsRow({ text: 'výška sokla 40 mm je mimo pásiem setu „nohy-podla-sokla“ (noha)',
                   short: 'výška sokla 40 mm je mimo…', tone: 'warn', set_id: 'nohy-podla-sokla',
                   set_name: 'Nohy podľa výšky sokla' }, 'CAB-001');
ok(global.el('legsRow').classList.contains('warn'), 'chybajuce pasmo setu je jantarove');
HW.renderLegsRow(SUMMARY_OK, 'CAB-001');
ok(!global.el('legsRow').classList.contains('warn'), 'a po naprave ton zhasne');

// ===========================================================================
// 2) VKLADANIE: dotaz s generaciou, odpoved, pass-through guard
// ===========================================================================
HW.nxLegsInsertReset();
global.selectedCabId = null;
global.__type = 'lower';
setFields(1200, 100);
SENT.length = 0;

ok(HW.nxLegsInsertSend(), 'vo vkladani sa dotaz odosle');
eq(SENT.length, 1, 'prave jeden dotaz');
eq(SENT[0].cb, 'insert_legs_preview', 'CITACIM callbackom (ziadna operacia, ziadny krok Spat)');
eq(Object.keys(SENT[0].data).sort(),
   ['floor_height', 'gen', 'model_guid', 'plinth_mode', 'type', 'width'].sort(),
   'payload je UZAVRETY — nahlad je pohlad na rozmery, nie druha vkladacia cesta');
eq(SENT[0].data.width, 1200, 'sirka rozhoduje o POCTE noh');
eq(SENT[0].data.floor_height, 100, 'vyska sokla o KODE');
ok(!rowHidden(), 'kym server odpoveda, riadok drzi miesto');
eq(textOfEl('legsTxt'), HW.LEGS_DASH, 'a stoji v nom pomlcka (starsi plugin pri nej ostane)');

const GEN1 = SENT[0].data.gen;
ok(HW.nxLegsInsertResult({ gen: GEN1, text: SUMMARY_OK.text, tone: 'ok' }),
   'odpoved AKTUALNEHO kola riadok naplni');
eq(textOfEl('legsTxt'), SUMMARY_OK.text, 'textom zo servera');

// (2): odpoved STARSIEHO kola sa zahodi
setFields(900, 100);
HW.nxLegsInsertSend();
const GEN2 = SENT[SENT.length - 1].data.gen;
ok(GEN2 > GEN1, 'generacia rastie');
eq(HW.nxLegsInsertResult({ gen: GEN1, text: '4× klzák', tone: 'ok' }), false,
   'pomalsie kolo NESMIE prepisat cerstvejsi vysledok');
eq(textOfEl('legsTxt'), HW.LEGS_DASH, 'riadok caka na odpoved NOVEHO kola');
ok(HW.nxLegsInsertResult({ gen: GEN2, text: '4× noha AXILO H100 + platnička', tone: 'ok' }),
   'a tu prijme');
eq(textOfEl('legsTxt'), '4× noha AXILO H100 + platnička', 'so styrmi nohami (sirka 900)');

// (2): odpoved, ktora dosla PO oznaceni skrinky, sa zahodi
setFields(1200, 100);
HW.nxLegsInsertSend();
const GEN3 = SENT[SENT.length - 1].data.gen;
global.selectedCabId = 'CAB-007';
eq(HW.nxLegsInsertResult({ gen: GEN3, text: '6× noha AXILO H100', tone: 'ok' }), false,
   'riadok uz patri payloadu OZNACENEJ skrinky');
global.selectedCabId = null;

// Ton `none` z odpovede riadok schova (skrinka bez podstavca).
HW.nxLegsInsertReset();
setFields(900, 0);
HW.nxLegsInsertSend();
const GEN4 = SENT[SENT.length - 1].data.gen;
eq(HW.nxLegsInsertResult({ gen: GEN4, text: 'bez nôh', tone: 'none' }), false,
   'ziadne nohy = ziadny riadok');
ok(rowHidden(), 'a riadok je skryty');

// (2): PASS-THROUGH GUARD — nic z nahladu sa nedostane do payloadu skrinky.
HW.nxLegsInsertReset();
setFields(1200, 100);
HW.nxLegsInsertSend();
HW.nxLegsInsertResult({ gen: SENT[SENT.length - 1].data.gen, text: SUMMARY_OK.text, tone: 'ok' });
const PAYLOAD = global.collectAll();
eq(Object.prototype.hasOwnProperty.call(PAYLOAD, 'legs_summary'), false,
   'text nôh je VYSTUP — do `collectAll()` nikdy nepatri');
eq(JSON.stringify(PAYLOAD).indexOf('AXILO'), -1,
   'a ziadna jeho cast sa do configu nedostane');

// Viditelnost podla typu — presne ako riadok Sokel (`#fhRow`).
eq(HW.nxLegsApplyVisibility('upper'), false, 'horna skrinka nohy nema');
ok(rowHidden(), 'riadok zmizne');
SENT.length = 0;
global.__type = 'upper';
eq(HW.nxLegsInsertSend(), false, 'a nic sa uz nedopytuje');
eq(SENT.length, 0, 'ziadny dotaz na server');
global.__type = 'lower';

// Doska nema nohy — a v kontexte dosky sa ani nepyta.
HW.nxLegsInsertReset();
global.NXInsert.state.kind = 'board';
eq(HW.nxLegsInsertMode(), false, 'v kontexte DOSKY nie je co ukazovat');
eq(HW.nxLegsInsertAsk(), false, 'takze sa ani nepyta');
global.NXInsert.state.kind = 'cabinet';

// Dotaz sa posiela LEN pri zmene toho, na com nohy zavisia.
HW.nxLegsInsertReset();
setFields(1200, 100);
ok(HW.nxLegsInsertAsk(), 'prva zmena si nahlad vypyta');
HW.nxLegsInsertSend();
HW.nxLegsInsertResult({ gen: SENT[SENT.length - 1].data.gen, text: SUMMARY_OK.text, tone: 'ok' });
eq(HW.nxLegsInsertAsk(), false, 'rovnake hodnoty uz server neobtazuju');
setFields(1200, 150);
ok(HW.nxLegsInsertAsk(), 'zmena vysky sokla ano');
setFields(900, 150);
HW.nxLegsInsertSend();
HW.nxLegsInsertResult({ gen: SENT[SENT.length - 1].data.gen, text: '4× noha', tone: 'ok' });
ok(HW.nxLegsInsertAsk(), 'a zmena sirky tiez');

// ===========================================================================
// 3) GHOST PASIK: segment noh
// ===========================================================================
function cabState(over){
  return Object.assign({
    active: true, type: 'lower', subject: 'cabinet', interaction: 'placement',
    anchor: 'fl_bottom', anchor_label: 'ľavá dolná', rotation: 0,
    z_mode: 'locked', lock_z: 0, orientation: '', orientation_label: ''
  }, over || {});
}

GB.apply(cabState({ legs_short: '6× noha AXILO H100 · 2× príchyt sokla AXILO', legs_tone: 'ok' }));
ok(!global.el('gbLegs').hidden, 'pasik SKRINKY segment noh kresli');
eq(textOfEl('gbLegs'), '6× noha AXILO H100 · 2× príchyt sokla AXILO',
   'kratkym textom zo SERVERA (pasik si nic neskracuje sam)');
ok(global.el('gbLegs').className.indexOf('warn') < 0, 'bez upozornenia je tlmeny');

GB.apply(cabState({ legs_short: 'výška sokla 40 mm je mimo…', legs_tone: 'warn' }));
ok(global.el('gbLegs').className.indexOf('warn') >= 0, 'chybajuce pasmo setu je jantarove');

// (3): pasik DOSKY segment noh nekresli
GB.apply({ active: true, type: 'board', subject: 'board', interaction: 'placement',
           anchor: 'fl_bottom', rotation: 0, z_mode: 'free', lock_z: 0,
           orientation: 'leziaca', orientation_label: 'Naležato',
           legs_short: '6× noha AXILO H100', legs_tone: 'ok' });
ok(global.el('gbLegs').hidden, 'doska nohy nema — segment neexistuje');
eq(GB.legsText({ subject: 'board', legs_short: '6× noha' }), '',
   'a server ho pre dosku ani neposiela');

// Starsi push kluc nenesie — segment sa nekresli (vzor `orientation_label`).
GB.apply(cabState({}));
ok(global.el('gbLegs').hidden, 'push BEZ kluca segment nekresli (starsi server)');
eq(GB.legsText(cabState({})), '', 'chybajuci kluc = prazdny text, nikdy „undefined"');
eq(GB.legsWarn(cabState({})), false, 'a ziadny ton');

// Kreslenie (doska, dva tahy) segment nema nikdy.
eq(GB.legsText({ subject: 'cabinet', interaction: 'drawing', legs_short: '6× noha' }), '',
   'pocas kreslenia sa o nohach nehovori');

// ===========================================================================
// 4) Codex #339 kolo 1 N1: KOVANIE ZO ŠABLÓNY IDE AJ DO NÁHĽADU
// ===========================================================================
// Šablóna nesie mapovanie setov a ich zmrazené definície; vložená skrinka ich
// naozaj dostane. Náhľad, ktorý ich neposlal, hovoril o projektovej predvoľbe
// — teda o nohách, ktoré skrinka po kliku NEDOSTANE.
const TPL_HW = {
  hardware_sets: { leg: 'kovg2-sablona-nohy' },
  hardware_set_defs: [{ set_id: 'kovg2-sablona-nohy', generic_type: 'leg',
                        members: [{ per: 'unit', qty: 1, code: '272212' }] }]
};
global.NXInsert.HARDWARE_KEYS = ['hardware_sets', 'hardware_set_defs'];
global.NXInsert.hardwarePayload = function(){ return global.__tplHw || {}; };

HW.nxLegsInsertReset();
global.__tplHw = {};
setFields(1200, 100);
SENT.length = 0;
HW.nxLegsInsertSend();
eq(Object.keys(SENT[0].data).sort(),
   ['floor_height', 'gen', 'model_guid', 'plinth_mode', 'type', 'width'].sort(),
   'bez šablóny je payload presne ten istý ako doteraz');

const KEY_PLAIN = HW.nxLegsInsertPeek();
global.__tplHw = TPL_HW;
SENT.length = 0;
HW.nxLegsInsertSend();
eq(SENT[0].data.hardware_sets, TPL_HW.hardware_sets,
   'mapovanie setov zo šablóny ide TÝM ISTÝM zdrojom ako do `insert_cabinet`');
eq(SENT[0].data.hardware_set_defs, TPL_HW.hardware_set_defs,
   'a s ním aj zmrazené definície (v projekte ešte nemusia byť)');
ok(HW.nxLegsInsertPeek() !== KEY_PLAIN,
   'dve šablóny s rovnakými rozmermi a INÝM setom nôh sú dva rôzne dotazy');
eq(HW.nxLegsTemplateHw(), TPL_HW, 'zdroj je `NXInsert.hardwarePayload()`, nič vlastné');

// Ad-hoc položky šablóny do náhľadu nepatria — nohy nikdy nevznikajú ručne.
global.__tplHw = Object.assign({ hardware_manual: [{ code: 'X' }] }, TPL_HW);
eq(Object.keys(HW.nxLegsTemplateHw()).sort(), ['hardware_set_defs', 'hardware_sets'],
   'do náhľadu ide LEN to, čo je v `HARDWARE_KEYS`');
global.__tplHw = {};

// ===========================================================================
// 5) Codex #339 kolo 1 N2: PREPNUTIE VKLADANIA NA DOSKU
// ===========================================================================
// Predikát `nxLegsInsertMode` po prepnutí na dosku len prestane odpovedať —
// samotný riadok neschová NIKTO, takže v doskovej karte ostal visieť text
// skrinky. Materializácia doskovej karty ho preto resetuje (form.js).
HW.nxLegsInsertReset();
global.NXInsert.state.kind = 'cabinet';
setFields(1200, 100);
HW.nxLegsInsertSend();
HW.nxLegsInsertResult({ gen: SENT[SENT.length - 1].data.gen, text: SUMMARY_OK.text, tone: 'ok' });
ok(!rowHidden(), 'PREMISA: riadok Nôh po náhľade dolnej skrinky stojí');
global.NXInsert.state.kind = 'board';
eq(HW.nxLegsInsertMode(), false, 'v kontexte dosky sa už nič nedopytuje');
ok(!rowHidden(), 'ale sám od seba riadok nezmizne — preto ten reset');
HW.nxLegsInsertReset(); // presne to, co robi `materializeInsertBoardCard`
ok(rowHidden(), 'doska riadok Nôh nemá');
eq(textOfEl('legsTxt'), HW.LEGS_DASH, 'a text skrinky sa z neho zmazal');
global.NXInsert.state.kind = 'cabinet';

// ===========================================================================
// 6) Codex #339 kolo 1 N3: ODPOVEĎ V LETE PO PREPNUTÍ TYPU
// ===========================================================================
// Skrytie riadku nestačí: odpoveď na dotaz vyslaný ešte za dolnú skrinku
// prišla po prepnutí na hornú a riadok znovu ODKRYLA — natrvalo.
HW.nxLegsInsertReset();
global.__type = 'lower';
setFields(1200, 100);
HW.nxLegsInsertSend();
const GEN_FLY = SENT[SENT.length - 1].data.gen;
global.__type = 'upper';
eq(HW.nxLegsApplyVisibility('upper'), false, 'horná skrinka riadok schová');
ok(rowHidden(), 'a je skrytý');
eq(HW.nxLegsInsertResult({ gen: GEN_FLY, text: SUMMARY_OK.text, tone: 'ok' }), false,
   'oneskorená odpoveď na UŽ NEPLATNÝ dotaz sa zahodí (generácia sa zdvihla)');
ok(rowHidden(), 'riadok ostáva skrytý');
ok(HW.legsGenState() > GEN_FLY, 'generácia sa pri odchode z dolnej skrinky zdvihla');

// Druhá poistka: aj odpoveď s AKTUÁLNOU generáciou riadok pri hornej skrinke
// neotvorí (iný klient, staršia cachovaná stránka).
const GEN_NOW = HW.legsGenState();
eq(HW.nxLegsInsertResult({ gen: GEN_NOW, text: SUMMARY_OK.text, tone: 'ok' }), false,
   'riadok Nôh patrí VÝHRADNE dolnej skrinke');
ok(rowHidden(), 'a ostáva skrytý');
global.__type = 'lower';
HW.nxLegsInsertReset();

console.log('OK ' + n + ' assertov (KOV-G2 riadok Noh + ghost segment)');
