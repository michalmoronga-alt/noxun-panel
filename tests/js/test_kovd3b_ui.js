// KOV-D3b — PRECHOD NA NOVSIU VERZIU RECEPTU, UI: ponuka v karte cela, dopad
// na TOTO celo a D-15 potvrdenie so zamkom odosielania.
//
// Preco su to testy a nie klikanie v paneli:
//   1. V PRODUKCII SA PONUKA NEUKAZE. V repe su len recepty v1, takze jediny
//      sposob, ako cely tok prejst, je fixturny payload — kliknut sa neda.
//   2. SERVER JE AUTORITA NAD VERZIAMI. Panel sa nikdy nepyta „je `to` novsie
//      ako `from`?" — posiela PRESNE to, co dostal. Keby `to` cital z textu
//      tlacidla, prepol by zasuvku na verziu, ktoru nikto nevydal.
//   3. DOPAD SA PYTA PRED POTVRDENIM. Okno sa otvara az z odpovede servera:
//      preflight moze prechod odmietnut a vtedy nie je co potvrdzovat.
//   4. ZAPIS OKNO NEZATVARA (kontrakt D-15). Zatvorit ho smie len potvrdenie
//      servera — inak by odmietnutie pouzivatel videl pod prazdnou kartou.
//
// MUTACIE (kazda overena rucne — po zaneseni chyby do zdroja spadne uvedeny test):
//   M1 `onDrawerUpgrade` otvara modal hned (bez otazky na dopad)
//      -> „KOV-D3b (R3): klik NEOTVARA okno — najprv sa pyta na dopad"
//   M2 `hwUpOffer` cita `to` z textu tlacidla namiesto datasetu
//      -> „identita sa cita SPAT z obalu — panel si ju neskladá"
//      (a v odoslani „KOV-D3b (R4): odosielaju sa PRESNE `from`/`to` zo servera")
//   M3 `onHwUpgradeResult` netestuje token
//      -> „odpoved s CUDZIM tokenom okno nezatvori"
//   M4 `onHwUpgradeImpact` otvara okno aj pri `ok: false`
//      -> „KOV-D3b (R2): odmietnuty dopad potvrdenie NEPONUKNE"
//   M5 `frontDrawerUpgradeRow` netestuje `available`
//      -> „KOV-D3b (R1): bez `available` sa nekresli NIC"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, textOf } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// --- prostredie panela -------------------------------------------------------
const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);

global.esc = function(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
};
global.el = function(id){ return DOC.getElementById(id); };
global.NXIcons = { svg: function(name){ return '<svg class="ic"><use href="#i-' + name + '"/></svg>'; } };

const STATUS = [];
global.NX = { setStatus: function(msg, err){ STATUS.push({ msg: msg, err: !!err }); } };

const ASK = [];    // volania `drawer_upgrade_impact` (CITANIE)
const WRITE = [];  // volania `upgrade_drawer_recipe` (ZAPIS)
global.sketchup = {
  drawer_upgrade_impact: function(p){ ASK.push(JSON.parse(p)); },
  upgrade_drawer_recipe: function(p){ WRITE.push(JSON.parse(p)); },
  set_hardware_override: function(){ /* D2b kanal — tu sa nepouziva */ }
};
global.window.sketchup = global.sketchup;
global.nxDocPayload = function(p){ return JSON.stringify(p); };

global.NXModal = require(path.join(JS, 'nx_modal.js'));
const HW = require(path.join(JS, 'hardware.js'));
const C = require(path.join(JS, 'core.js'));

// Payload servera (`Panel.drawer_upgrade_offer`) — tvar je kontrakt D3b.
const OFFER = { available: true, from: 'atira_sisy_v1', to: 'atira_sisy_v2',
                to_label: 'v2', release_note: 'Chrbát H144 má 120 mm.',
                cabinet_id: 'CAB-1', front_id: 'F1' };
// Odpoved citacieho callbacku (`Panel.drawer_upgrade_impact`).
const IMPACT = {
  ok: true, from: 'atira_sisy_v1', to: 'atira_sisy_v2', to_title: 'Atira SiSy v2',
  release_note: 'Chrbát H144 má 120 mm.',
  height: { from: 144, to: 144 },
  nl: { from: 470, to: 470 },
  parts: [{ role: 'drawer_bottom', label: 'dno', from: [791.5, 480, 16], to: [787.5, 480, 16] },
          { role: 'drawer_back', label: 'chrbát', from: [780, 144, 16], to: [780, 120, 16] }],
  locks: [{ axis: 'nl', value: 470, kept: true }],
  kit: { from: ['357696'], to: ['357696'] }
};

function reset(){
  ASK.length = 0; WRITE.length = 0; STATUS.length = 0;
  if (global.NXModal.isOpen()) global.NXModal.close();
}
function render(up){
  const box = mkEl('div');
  DOC.body.appendChild(box);
  box.innerHTML = HW.hwUpHtml(up == null ? OFFER : up);
  return box;
}
function upBtn(box){ return box.querySelector('.dwup button'); }
function modalText(){ return textOf(DOC.getElementById('nxModalRoot')); }

// ===========================================================================
// A) VIEW-MODEL KARTY — kedy riadok VOBEC vznikne
// ===========================================================================

const CARD = { state: 'ok', text: 'Atira · H144 · NL 470', detail: [] };

eq(C.frontDrawerRows(CARD).map(r => r.kind), ['resolved'],
   'KOV-D3b (R1): bez kluca `upgrade` sa karta sprava PRESNE ako po D2b');

eq(C.frontDrawerRows(Object.assign({}, CARD, { upgrade: OFFER })).map(r => r.kind),
   ['resolved', 'upgrade'],
   'KOV-D3b (R1): s dostupnou v2 pribudne JEDEN blok (ziadny druhy riadok)');

eq(C.frontDrawerRows(Object.assign({}, CARD, { sync: 'Odporúčame synchro.', upgrade: OFFER }))
    .map(r => r.kind),
   ['resolved', 'info', 'upgrade'],
   'ponuka stoji AZ POD jantarovym odporucanim — to je upozornenie, toto prilezitost');

eq(C.frontDrawerUpgradeRow(Object.assign({}, CARD,
     { upgrade: Object.assign({}, OFFER, { available: false }) })), null,
   'KOV-D3b (R1): bez `available` sa nekresli NIC');
eq(C.frontDrawerUpgradeRow(Object.assign({}, CARD,
     { upgrade: Object.assign({}, OFFER, { front_id: '' }) })), null,
   'bez identity cela by klik nemal comu patrit — server ju posiela, panel neskladá');
eq(C.frontDrawerUpgradeRow(Object.assign({}, CARD,
     { upgrade: Object.assign({}, OFFER, { to: '' }) })), null,
   'bez cieloveho ref-u sa neposiela nic');
eq(C.frontDrawerUpgradeRow(Object.assign({}, CARD,
     { upgrade: Object.assign({}, OFFER, { from: '' }) })), null,
   'bez ocakavaneho stareho ref-u by server nespoznal medzicasnu zmenu');
// Konfliktna a nemigrovana zasuvka ponuku nedostanu ANI ked ju payload nesie
// (server ju tam nedava — panel sa na to ale nespolieha).
eq(C.frontDrawerRows({ state: 'conflict', message: 'Nezmestí sa.', upgrade: OFFER })
    .map(r => r.kind), ['info'], 'konflikt ma vlastnu cestu napravy, nie upgrade');
eq(C.frontDrawerRows({ state: 'stale', upgrade: OFFER }).map(r => r.kind), ['info'],
   'nemigrovana zasuvka nema z coho prechadzat');

// ===========================================================================
// B) MARKUP PONUKY
// ===========================================================================

eq(HW.hwUpHtml(null), '', 'bez ponuky ziadny markup');
eq(HW.hwUpHtml({ available: false }), '', 'a `available: false` tiez nie');

const box = render();
const wrap = box.querySelector('.dwup');
ok(wrap, 'ponuka ma vlastny obal `.dwup` (nesie identitu zapisu)');
eq(wrap.getAttribute('data-cab'), 'CAB-1', 'identita skrinky je v datasete');
eq(wrap.getAttribute('data-fid'), 'F1');
eq(wrap.getAttribute('data-from'), 'atira_sisy_v1');
eq(wrap.getAttribute('data-to'), 'atira_sisy_v2');
ok(textOf(box).indexOf('Dostupný recept v2') >= 0, 'veta menuje DOSTUPNU verziu');
ok(textOf(box).indexOf('Chrbát H144 má 120 mm.') >= 0,
   'a nesie autorsku poznamku vydania (`release_note` z receptu)');
ok(textOf(box).indexOf('Prejsť na v2') >= 0, 'tlacidlo menuje, kam sa prejde');
eq(box.querySelectorAll('.dwup button').length, 1,
   'vertikalny priestor: JEDNA veta a JEDNO tlacidlo');
ok(upBtn(box).attrs.class.indexOf('ghostbtn') >= 0,
   'je to GHOST tlacidlo — prilezitost, nie hlavna akcia karty');

// Bez poznamky vydania sa veta nezlomi (v1 ju smie vynechat).
const bare = render(Object.assign({}, OFFER, { release_note: '' }));
ok(textOf(bare).indexOf('Dostupný recept v2') >= 0, 'veta plati aj bez poznamky');

// Fokus prezije prekreslenie karty (vzor D2b P2-4): karta sa prekresluje aj
// LAHKYM pushom (zmena mapovania alebo katalogu v Studiu), pricom ponuka ostava
// — bez logickej identity by fokus spadol na dokument.
const upKey = C.frontCardFocusKey({ ax: 'upgrade', axc: 'upg' });
eq(upKey, 'a:upgrade|upg', 'tlacidlo ponuky MA logicku identitu fokusu');
eq(box.querySelectorAll(C.frontCardFocusSelector(upKey)).length, 1,
   'a selektor z nej najde v REALNOM markupe prave jeden uzol');

eq(HW.hwUpOffer(upBtn(box)),
   { cabinet_id: 'CAB-1', front_id: 'F1', from: 'atira_sisy_v1', to: 'atira_sisy_v2' },
   'identita sa cita SPAT z obalu — panel si ju neskladá');
eq(HW.hwUpOffer(mkEl('button')), null, 'mimo obalu `.dwup` sa neposiela nic');

// ===========================================================================
// C) KLIK = CITACIA OTAZKA NA DOPAD (okno sa NEOTVARA)
// ===========================================================================

reset();
HW.onDrawerUpgrade(upBtn(box));
eq(WRITE.length, 0, 'klik na ponuku NIC nezapisuje');
ok(!global.NXModal.isOpen(),
   'KOV-D3b (R3): klik NEOTVARA okno — najprv sa pyta na dopad');
eq(ASK.length, 1, 'a posiela PRAVE JEDNU citaciu otazku');
const askTok = ASK[0].up_token;
ok(askTok, 'otazka nesie KORELACNY token');
eq(Object.assign({}, ASK[0], { up_token: undefined }),
   { cabinet_id: 'CAB-1', front_id: 'F1', from: 'atira_sisy_v1', to: 'atira_sisy_v2',
     up_token: undefined },
   'KOV-D3b (R4): odosielaju sa PRESNE `from`/`to` zo servera');

HW.onDrawerUpgrade(upBtn(box));
eq(ASK.length, 1, 'dvojklik neposiela druhu otazku (odpoved by patrila starsej)');

// Cudzia (starsia) odpoved sa zahadzuje.
HW.onHwUpgradeImpact(IMPACT, 'u-cudzi');
ok(!global.NXModal.isOpen(), 'odpoved s CUDZIM tokenom okno neotvara');
ok(HW.hwUpAskState(), 'a otazka stale caka na SVOJU odpoved');

// ===========================================================================
// D) ODMIETNUTY DOPAD = ZIADNE POTVRDENIE, LEN DOVOD
// ===========================================================================

STATUS.length = 0;
HW.onHwUpgradeImpact({ ok: false, reason: 'Nová verzia na túto zásuvku nesadne: hrúbka 16 mm.' },
                     askTok);
ok(!global.NXModal.isOpen(),
   'KOV-D3b (R2): odmietnuty dopad potvrdenie NEPONUKNE');
ok(STATUS.length && STATUS[STATUS.length - 1].err === true,
   'dovod ide na obrazovku ako chyba');
ok(STATUS[STATUS.length - 1].msg.indexOf('hrúbka 16 mm') >= 0,
   'a je to VETA SERVERA, nie vlastna hlaska panela');
eq(HW.hwUpAskState(), null, 'stav otazky zaniká — dalsi klik sa da poslat');

// ===========================================================================
// E) DOPAD -> POTVRDENIE -> ZAPIS (kostra D-15)
// ===========================================================================

reset();
HW.onDrawerUpgrade(upBtn(box));
const tok2 = ASK[0].up_token;
ok(tok2 !== askTok, 'kazda otazka ma VLASTNY token');
HW.onHwUpgradeImpact(IMPACT, tok2);
ok(global.NXModal.isOpen(), 'potvrdeny dopad otvara D-15 potvrdenie');
eq(WRITE.length, 0, 'KOV-D3b (R3): BEZ potvrdenia sa nezapisuje nic');

const mt = modalText();
ok(mt.indexOf('Prejsť na novú verziu receptu') >= 0, 'okno hovori, o com rozhoduje');
ok(mt.indexOf('Chrbát H144 má 120 mm.') >= 0, 'a nesie poznamku vydania');
ok(mt.indexOf('teraz') >= 0 && mt.indexOf('po prechode') >= 0,
   'tabulka porovnava DVA stavy tejto zasuvky');
ok(mt.indexOf('144') >= 0 && mt.indexOf('120') >= 0,
   'a menuje KONKRETNE cisla dielca (nie diff konstant)');
ok(mt.indexOf('Chrbát') >= 0, 'roly su pomenovane po slovensky (popisok dava server)');
ok(mt.indexOf('357696') >= 0, 'objednavaci kod je sucastou dopadu');
ok(mt.indexOf('NL 470') >= 0, 'a zamok sa priznava s hodnotou, ktora sa prenesie');
ok(mt.indexOf('Prejsť') >= 0, 'potvrdzovacie tlacidlo menuje akciu');

global.NXModal.submit();
eq(WRITE.length, 1, 'potvrdenie posiela PRAVE JEDEN zapis');
const wTok = WRITE[0].up_token;
ok(wTok && wTok !== tok2, 'zapis ma VLASTNY token (nie ten z citacej otazky)');
eq(Object.assign({}, WRITE[0], { up_token: undefined }),
   { cabinet_id: 'CAB-1', front_id: 'F1', from: 'atira_sisy_v1', to: 'atira_sisy_v2',
     up_token: undefined },
   'zapis nesie PRESNE to, co dal server — ziadne cislo z obrazovky');
ok(global.NXModal.isOpen(), 'okno ostava OTVORENE, kym server zapis nepotvrdi');
ok(global.NXModal.isBusy(), 'a je ZAMKNUTE — druhy submit uz nezapise');
global.NXModal.submit();
eq(WRITE.length, 1, 'dvojklik na „Prejsť" nezapise dvakrat');

// Cudzi token (odpoved na starsie odoslanie) sa zahodi.
HW.onHwUpgradeResult(true, '', 'u-cudzi');
ok(global.NXModal.isOpen(), 'odpoved s CUDZIM tokenom okno nezatvori');

// ODMIETNUTIE servera: okno sa odomkne a hlaska je V NOM.
HW.onHwUpgradeResult(false, 'Stav zásuvky sa medzitým zmenil — skús znova.', wTok);
ok(global.NXModal.isOpen(), 'odmietnuty zapis okno NEZATVARA');
ok(!global.NXModal.isBusy(), 'a odomkne ho — rozhodnutie sa da poslat znova');
ok(modalText().indexOf('Stav zásuvky sa medzitým zmenil') >= 0,
   'dovod odmietnutia je V MODALI, nie len v statuse');

// Druhy pokus + USPECH: az teraz sa okno zatvara.
WRITE.length = 0;
global.NXModal.submit();
const wTok2 = WRITE[0] && WRITE[0].up_token;
ok(wTok2 && wTok2 !== wTok, 'kazde odoslanie ma VLASTNY token');
HW.onHwUpgradeResult(true, '', wTok2);
ok(!global.NXModal.isOpen(), 'potvrdeny zapis okno zatvara');
eq(HW.hwUpModalState(), null, 'a stav volajuceho zaniká');

// Zrusenie potvrdenia nezapise nic.
reset();
HW.onDrawerUpgrade(upBtn(box));
HW.onHwUpgradeImpact(IMPACT, ASK[0].up_token);
ok(global.NXModal.isOpen(), 'okno je otvorene');
global.NXModal.close();
eq(WRITE.length, 0, 'zavrete okno = ziadny zapis');
eq(HW.hwUpModalState(), null, '`onClose` stav vycisti (odpoved nema komu patrit)');
HW.onHwUpgradeResult(true, '', wTok2);
ok(!global.NXModal.isOpen(), 'oneskorena odpoved na zavrete okno nic neotvara');

// ===========================================================================
// F) TABULKA DOPADU — ciste formatovanie
// ===========================================================================

eq(HW.hwUpDims([791.5, 480, 16]), '791,5 × 480 × 16 mm',
   'rozmery su cisla SERVERA, panel meni len desatinnu ciarku');
eq(HW.hwUpDims(null), '—', 'chybajuca strana sa PRIZNA, nikdy nedopocitava');
eq(HW.hwUpDims([]), '—');
eq(HW.hwUpCodes(['357696', '357697']), '357696, 357697');
eq(HW.hwUpCodes([]), '—', 'ziadny kod = pomlcka (nie prazdna bunka)');
eq(HW.hwUpLockLabel({ axis: 'nl', value: 470 }), 'NL 470');
eq(HW.hwUpLockLabel({ axis: 'height', value: 144 }), 'výška H144');
eq(HW.hwUpLockLabel({ axis: 'nl', value: null }), '', 'zamok bez hodnoty sa neuvadza');

// Nezmeneny riadok sa TLMI — oko ma najst to, co sa naozaj meni.
const host = mkEl('div');
HW.hwUpImpactRender(host, IMPACT);
const rows = host.querySelectorAll('tbody tr');
ok(rows.length >= 4, 'tabulka ma riadok na vysku, NL, kazdy dielec a kod');
const same = rows.filter(r => (r.attrs.class || '').indexOf('same') >= 0);
ok(same.length >= 2, 'nezmenene riadky su oznacene (vyska, NL, kod)');
const changed = rows.filter(r => (r.attrs.class || '').indexOf('same') < 0);
ok(changed.length >= 2, 'a zmenene NIE su — inak by sa stratil rozdiel');
ok(textOf(host).indexOf('Ručné zámky sa prenesú') >= 0,
   'veta o zamkoch hovori, ze sa PRENESU bez zmeny hodnoty');
const noLock = mkEl('div');
HW.hwUpImpactRender(noLock, Object.assign({}, IMPACT, { locks: [] }));
ok(textOf(noLock).indexOf('žiadny ručný zámok') >= 0,
   'a bez zamku to POVIE — ticho by pouzivatel cital ako „zamok sa strati"');

// ===========================================================================
// G) KARTA DELEGUJE NA TEN ISTY RENDERER
// ===========================================================================

const fs = require('node:fs');
// Zdroje sa citaju s normalizovanymi koncami riadkov (Windows checkout = CRLF).
const readSrc = (name) => fs.readFileSync(path.join(JS, name), 'utf8').replace(/\r\n/g, '\n');
const formSrc = readSrc('form.js');
const cardFn = formSrc.match(/function frontCardHtml\(row\)\{[\s\S]*?\n  \}\n/)[0];
ok(/r\.kind === 'upgrade'/.test(cardFn) && /hwUpHtml\(r\.upgrade\)/.test(cardFn),
   'karta cela deleguje markup ponuky na `hardware.js` (jeden renderer)');

const bridgeSrc = readSrc('bridge.js');
ok(/hwUpgradeImpact: function\(res, token\)/.test(bridgeSrc) &&
   /hwUpgradeResult: function\(ok, msg, token\)/.test(bridgeSrc),
   'oba serverove kanaly su v moste — citaci aj zapisovy');
ok(bridgeSrc.indexOf('hwUpgradeImpact') !== bridgeSrc.indexOf('hwAxResult'),
   'a su VLASTNE: okno nahrady osi a okno prechodu su dva rozne modaly');

console.log('KOV-D3b UI: ' + n + ' assertov OK');
