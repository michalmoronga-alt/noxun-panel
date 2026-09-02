// D-52b — UPDATER v sekcii „O plugine" (klientska strana).
//
// Prečo sú to testy a nie klikanie:
//   1. „O plugine" je JEDEN OBSAH s DVOMA VSTUPMI. Updater smie žiť LEN
//      v štúdiovom vstupe — v koliesku Inspectora by bolo mŕtve tlačidlo
//      (D-78) a pole cesty, ktoré tam nikto neobslúži. Klikaním sa to overí
//      až vtedy, keď to niekto uvidí zle.
//   2. Cesta k distribučnému priečinku má VLASTNÝ namespace `data-updater-edit`
//      (F7). Keby spadla pod `data-ss`, písanie do nej by pripínalo revíziu
//      dodávateľa a uloženie sadzieb by sa začalo odmietať falošným
//      konfliktom — chyba, ktorá sa v UI prejaví úplne inde než vznikla.
//   3. Rozpísaná cesta musí PREŽIŤ plný push (chodí pri každej zmene modelu) —
//      inak by zmizla uprostred písania, presne ako trieda chyby z #227.
//   4. Kontrola verzie je EXPLICITNÁ: vstup do sekcie = PRESNE JEDEN check.
//      Zo `settings_payload` nechodí — každý posun skrinky by siahal na
//      sieťový share.
//   5. Tlačidlo „Aktualizovať" je aktívne VÝHRADNE pri novšej verzii; staršia
//      verzia je `aria-disabled` s vetou o ručnom INSTALL (B4).
//   6. Bez potvrdenia (D-15 modal) sa swap NESMIE spustiť — je to mutácia,
//      ktorá zavrie obe okná a prepíše súbory pluginu.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_st4a_settings.js) --------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], _html: '', _attrs: {}, value: '', className: '', title: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; n.children = []; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){ n._text = v; }
  });
  n.appendChild = function(c){
    n.children.push(c);
    n._html += (c && c.outerText) ? c.outerText : '';
    return c;
  };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.removeAttribute = function(k){ delete n._attrs[k]; };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  n.classList = { toggle: function(){} };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio', 'updState', 'updBtn', 'updDir']
  .forEach(function(id){ ELS[id] = stubEl(id); });

const SENT = [];
global.window = {
  sketchup: new Proxy({}, {
    get(_t, name){
      if (typeof name !== 'string') return undefined;
      return function(payload){ SENT.push([name, payload]); };
    },
    has(){ return true; }
  })
};
global.sketchup = global.window.sketchup;
const LISTEN = { input: [], click: [], focusin: [], keydown: [] };
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  querySelectorAll: function(){ return []; }
};

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const A = require(path.join(JS, 'about.js'));
const T = require(path.join(JS, 'studio_settings.js'));
// V prehliadači sú tieto funkcie GLOBÁLNE (súbory nie sú modulmi) a volajú sa
// cez `typeof …=== 'function'`; v Node žijú v module, preto tá istá väzba,
// akú robí poradie <script> tagov v studio.html.
global.ssRenderBody = T.ssRenderBody;
global.ssRenderTools = T.ssRenderTools;
global.ssOnAboutEnter = T.ssOnAboutEnter;
global.nxAboutFill = A.nxAboutFill;
global.nxUpdaterText = A.nxUpdaterText;
global.nxUpdaterEnabled = A.nxUpdaterEnabled;

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

const ABOUT = { version: '0.9.10', dir: 'C:\\APPDATA\\NOXUN\\Engine',
                updater: { enabled: true, source_dir: 'X:/dist', current: '0.9.10', locked: false } };
const STATE = {
  version: '0.9.10', revision: 'r-1',
  supplier: { name: 'Demos', rates: { montaz: 12 }, mode_values: {},
              stale_days: 30, rounding_step: 5, abs_reserve_pct: 10,
              montaz_m2_per_plate: 3, cp_highlight_threshold: 100 },
  modes: ['nizky'], mode_labels: { nizky: 'Nízky' },
  rate_keys: ['montaz'], rate_labels: { montaz: ['Montáž', '€/m²'] },
  standard_rows: [], path: 'C:\\APPDATA\\NOXUN\\Engine\\supplier_settings.json',
  demos: { crawl_delay_s: 3, stale_days: 30 },
  about: ABOUT
};

function fireInput(target){ LISTEN.input.forEach(function(fn){ fn({ target: target }); }); }
function fireKey(target, key){
  LISTEN.keydown.forEach(function(fn){ fn({ target: target, key: key, preventDefault: function(){} }); });
}
// Klik ide DELEGÁCIOU — cieľ musí vedieť `closest`, presne ako v prehliadači.
function fireClick(node){
  const ev = { target: { closest: function(sel){ return sel.indexOf('data-updater-act') >= 0 ? node : null; } } };
  LISTEN.click.forEach(function(fn){ fn(ev); });
}
function updEl(attrs, value){
  const t = stubEl('updDir');
  Object.keys(attrs).forEach(function(k){ t.setAttribute(k, attrs[k]); });
  t.value = value == null ? '' : value;
  return t;
}

// --- 1) JEDEN OBSAH, DVA VSTUPY: updater LEN v Štúdiu ------------------------

(function(){
  const wheel = A.nxAboutHtml(ABOUT);              // koliesko Inspectora
  ok(wheel.indexOf('id="cfgVersion"') > -1, 'zdieľaný obsah je v oboch vstupoch rovnaký');
  ok(wheel.indexOf('data-updater-edit') < 0, 'koliesko Inspectora NEMÁ pole distribučného priečinka');
  ok(wheel.indexOf('Aktualizovať') < 0, 'ani tlačidlo (mŕtve tlačidlo v druhom vstupe = D-78)');
  ok(wheel.indexOf('id="updState"') < 0, 'ani stavový riadok');

  const studio = A.nxAboutHtml(ABOUT, { enabled: true, state: 'newer', source_dir: 'X:/dist',
                                        current: '0.9.10', available: '0.9.11' });
  ok(studio.indexOf('id="cfgVersion"') > -1, 'štúdiový vstup nesie TEN ISTÝ obsah…');
  ok(studio.indexOf('data-updater-edit="source_dir"') > -1, '…a navyše pole priečinka');
  ok(studio.indexOf('id="updState"') > -1 && studio.indexOf('id="updBtn"') > -1,
     'stavový riadok aj tlačidlo');
  ok(studio.indexOf('X:/dist') > -1, 'pole je predvyplnené uloženou cestou');
  // XSS: cesta chodí zo servera, ale do HTML sa nikdy nevkladá surová.
  const esc = A.nxAboutHtml(ABOUT, { enabled: true, state: 'idle', source_dir: '<img src=x>' });
  ok(esc.indexOf('<img src=x>') < 0 && esc.indexOf('&lt;img') > -1, 'cesta je escapovaná');
})();

// --- 2) TROJSTAV + prevádzkové stavy tlačidla --------------------------------

(function(){
  function html(u){ return A.nxUpdaterHtml(u); }
  const base = { enabled: true, current: '0.9.10', source_dir: 'X:/dist' };

  const newer = Object.assign({}, base, { state: 'newer', available: '0.9.11' });
  ok(A.nxUpdaterEnabled(newer) === true, 'NOVŠIA verzia = tlačidlo aktívne');
  ok(html(newer).indexOf('aria-disabled') < 0, 'a v markupe nie je aria-disabled');
  ok(A.nxUpdaterText(newer).indexOf('V0.9.11') > -1, 'stavový riadok menuje dostupnú verziu');

  const same = Object.assign({}, base, { state: 'same', available: '0.9.10' });
  ok(A.nxUpdaterEnabled(same) === false, 'ROVNAKÁ verzia = tlačidlo neaktívne');
  ok(html(same).indexOf('aria-disabled="true"') > -1, 'cez aria-disabled, NIKDY cez HTML disabled');
  ok(html(same).indexOf(' disabled') < 0, 'HTML `disabled` sa nepoužíva (D-78)');
  ok(A.nxUpdaterText(same).indexOf('aktuálnu') > -1, 'a povie, že je aktuálna');

  const older = Object.assign({}, base, { state: 'older', available: '0.9.1' });
  ok(A.nxUpdaterEnabled(older) === false, 'STARŠIA verzia = tlačidlo neaktívne (B4)');
  ok(A.nxUpdaterText(older).indexOf('INSTALL') > -1,
     'a hláška posiela na ručný INSTALL — downgrade je vo V1 zakázaný');

  const err = Object.assign({}, base, { state: 'error', reason: 'zdrojový priečinok neexistuje (X:/dist)' });
  ok(A.nxUpdaterEnabled(err) === false, 'nedostupný zdroj = tlačidlo neaktívne');
  ok(A.nxUpdaterText(err).indexOf('X:/dist') > -1 && A.nxUpdaterText(err).indexOf('neexistuje') > -1,
     'hláška nesie CESTU aj DÔVOD');

  ok(A.nxUpdaterEnabled(Object.assign({}, base, { state: 'checking' })) === false,
     'počas kontroly sa klikať nedá');
  const dirty = Object.assign({}, base, { state: 'newer', available: '0.9.11', dirty: true });
  ok(A.nxUpdaterEnabled(dirty) === false,
     'ROZPÍSANÁ, neuložená cesta tlačidlo zamkne — aktualizovalo by sa z ULOŽENEJ');
  ok(A.nxUpdaterText(dirty).indexOf('nie je uložená') > -1, 'a povie, že ju treba uložiť');
  ok(A.nxUpdaterEnabled(Object.assign({}, base, { state: 'newer', available: '1.0.0', locked: true })) === false,
     'po úspešnej aktualizácii latch tlačidlo zamkne (D-52a B2)');
  ok(A.nxUpdaterText({ enabled: true, state: 'newer', locked: true }).indexOf('reštartuj') > -1,
     'a povie, že treba reštart');
  ok(A.nxUpdaterEnabled({ enabled: false, state: 'newer' }) === false,
     'bez načítaného jadra updatera sa neaktualizuje nič');
})();

// --- 3) `data-updater-edit` NEOVPLYVNÍ revíznu mechaniku dodávateľa ----------

(function(){
  S.setStudioSection('bset');
  T.ssApplyState(STATE);
  T.SS.saved();                                   // čistý štart
  ok(T.ssBaseRev() === null, 'bez rozpisu nie je čo pripínať');

  const inp = updEl({ 'data-updater-edit': 'source_dir' }, 'X:/nove');
  document.activeElement = inp;
  LISTEN.focusin.forEach(function(fn){ fn({ target: inp }); });
  fireInput(inp);
  ok(T.ssBaseRev() === null,
     'písanie do poľa CESTY NEPRIPÍNA revíziu dodávateľa (vlastný namespace, F7)');
  eq(T.updDirty(), 'X:/nove', 'ale updater si rozpísanú cestu pamätá');

  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'a `SS_DIRTY` ostalo prázdne — uloženie sadzieb nemá čo poslať');
  eq(ELS.status.textContent, 'Nič sa nezmenilo.', 'sekcia to aj povie');
  document.activeElement = null;
})();

// --- 4) ROZPÍSANÁ CESTA PREŽIJE PLNÝ PUSH ------------------------------------

(function(){
  S.setStudioSection('about');
  T.ssApplyState(STATE);
  eq(T.updMerged().source_dir, 'X:/nove',
     'rozpísaná cesta vyhráva nad tou z payloadu — push ju NEPREPÍŠE');

  // Payload s INOU uloženou cestou (druhá inštancia / ručný zásah) rozpis
  // rovnako neprepíše: zaniká výhradne na POTVRDENIE servera.
  const fresh = JSON.parse(JSON.stringify(STATE));
  fresh.about.updater.source_dir = 'Y:/ine';
  T.ssApplyState(fresh);
  eq(T.updMerged().source_dir, 'X:/nove', 'ani druhý push cestu nezoberie');

  ok(T.updMerged().dirty === true, 'a kým je rozpísaná, tlačidlo je zamknuté');

  T.SS.updater({ enabled: true, state: 'idle', source_dir: 'Y:/ulozene', saved: true, current: '0.9.10' });
  eq(T.updDirty(), null, 'POTVRDENÝ zápis rozpis zahodí (vzor `SS.saved()`)');
  eq(T.updMerged().source_dir, 'Y:/ulozene', 'a v poli je to, čo server naozaj uložil (normalizované)');
  ok(T.updMerged().dirty === false, 'a nič nie je rozpísané');
  T.ssApplyState(STATE);                          // späť na fixture
})();

// --- 4b) CUDZIA ZMENA CESTY ZNEPLATNÍ VÝSLEDOK (Codex #278 P1) --------------

(function(){
  S.setStudioSection('about');
  T.ssApplyState(STATE);
  // Používateľ skontroloval cestu z payloadu a videl „novšia verzia".
  T.SS.updater({ enabled: true, state: 'newer', source_dir: 'X:/dist', current: '0.9.11',
                 available: '0.9.12', token: 7 });
  ok(T.updMerged().state === 'newer' && T.updMerged().token === 7, 'stav je pripravený na klik');

  // Medzitým DRUHÁ inštancia uložila do updater_settings.json inú cestu —
  // plný push ju prinesie ako `about.updater.source_dir`.
  const cudzi = JSON.parse(JSON.stringify(STATE));
  cudzi.about.updater.source_dir = 'B:/nova';
  SENT.length = 0;
  T.ssApplyState(cudzi);
  eq(T.updMerged().state, 'idle',
     'živý výsledok patril STAREJ ceste — po cudzej zmene sa ZAHADZUJE');
  eq(T.updMerged().source_dir, 'B:/nova', 'a v poli je cesta, ktorá je naozaj uložená');
  ok(A.nxUpdaterEnabled(T.updMerged()) === false,
     'tlačidlo je neaktívne — inak by potvrdenie menovalo A a nasadilo B');
  eq(SENT.filter(function(x){ return x[0] === 'updater_check'; }).length, 1,
     'a rovno beží nová kontrola (sekcia je otvorená)');

  // Ten istý push druhýkrát už nič nezhadzuje ani nespúšťa.
  SENT.length = 0;
  T.ssApplyState(cudzi);
  eq(SENT.length, 0, 'push s NEZMENENOU cestou nespúšťa nič');

  // Mimo sekcie sa stav zahodí, ale kontrola sa nespúšťa (nikto sa nepozerá).
  T.SS.updater({ enabled: true, state: 'newer', source_dir: 'B:/nova', current: '0.9.11',
                 available: '0.9.12', token: 8 });
  S.setStudioSection('bom');
  const cudzi2 = JSON.parse(JSON.stringify(STATE));
  cudzi2.about.updater.source_dir = 'C:/tretia';
  SENT.length = 0;
  T.ssApplyState(cudzi2);
  eq(SENT.length, 0, 'zavretá sekcia kontrolu nespúšťa');
  S.setStudioSection('about');
  eq(T.updMerged().state, 'idle', 'ale zastaraný výsledok je aj tak preč');
  T.ssApplyState(STATE);
})();

// --- 4c) KLIK NESIE DOKLAD O KONTROLE ---------------------------------------

(function(){
  S.setStudioSection('about');
  T.ssApplyState(STATE);
  T.SS.updater({ enabled: true, state: 'newer', source_dir: 'X:/dist', current: '0.9.11',
                 available: '0.9.12', token: 11 });
  let sub = null;
  window.NXModal = { open: function(spec){ sub = spec; }, close: function(){} };
  SENT.length = 0;
  T.updApply();
  sub.onSubmit({});
  const sent = SENT.find(function(x){ return x[0] === 'updater_apply'; });
  const payload = JSON.parse(sent[1]);
  eq(payload.checked_path, 'X:/dist', 'klik posiela CESTU, ktorej výsledok mal človek pred očami');
  eq(payload.check_token, 11, 'a TOKEN tej kontroly — server bez zhody neaktualizuje');
})();

// --- 4d) ROZPÍSANÁ CESTA ZAMYKÁ TLAČIDLO HNEĎ (Codex #278 kolo 2, P2) -------

(function(){
  S.setStudioSection('about');
  T.ssApplyState(STATE);
  T.SS.updater({ enabled: true, state: 'newer', source_dir: 'X:/dist', current: '0.9.12',
                 available: '0.9.13', token: 3, saved: true });
  ELS.updBtn.removeAttribute('aria-disabled');
  eq(ELS.updBtn.getAttribute('aria-disabled'), null, 'východisko: tlačidlo je aktívne');

  // Používateľ začne prepisovať cestu. Kontrola pritom patrí tej ULOŽENEJ —
  // tlačidlo musí zhasnúť OKAMŽITE, nie až po prekreslení tela.
  const inp = updEl({ 'data-updater-edit': 'source_dir' }, 'X:/dist-INE');
  ELS.updDir.value = 'X:/dist-INE';
  fireInput(inp);
  eq(ELS.updBtn.getAttribute('aria-disabled'), 'true',
     'rozpísaná cesta tlačidlo ZAMKNE hneď pri písaní');
  ok(ELS.updState.textContent.indexOf('nie je uložená') > -1, 'a stavový riadok povie prečo');

  // Návrat na uloženú hodnotu ho zase odomkne (guard nie je „raz zamkni navždy").
  const back = updEl({ 'data-updater-edit': 'source_dir' }, 'X:/dist');
  ELS.updDir.value = 'X:/dist';
  fireInput(back);
  eq(ELS.updBtn.getAttribute('aria-disabled'), null, 'zhodná cesta tlačidlo vráti');
})();

// --- 4e) ACK PATRÍ TOMU, ČO SA ODOSLALO (Codex #278 kolo 2, P2) -------------

(function(){
  S.setStudioSection('about');
  T.ssApplyState(STATE);

  // Enter uloží A…
  ELS.updDir.value = 'A:/prva';
  SENT.length = 0;
  fireKey(updEl({ 'data-updater-edit': 'source_dir' }, 'A:/prva'), 'Enter');
  eq(JSON.parse(SENT[0][1]).source_dir, 'A:/prva', 'odoslala sa hodnota A');
  eq(T.updSent(), 'A:/prva', 'a klient si pamätá, čo poslal');

  // …používateľ ale medzitým píše B.
  ELS.updDir.value = 'B:/druha';
  fireInput(updEl({ 'data-updater-edit': 'source_dir' }, 'B:/druha'));
  eq(T.updDirty(), 'B:/druha', 'rozpis je B');

  // Až TERAZ dorazí potvrdenie uloženia A.
  T.SS.updater({ enabled: true, state: 'idle', source_dir: 'A:/prva', saved: true, current: '0.9.12' });
  eq(T.updDirty(), 'B:/druha', 'potvrdenie STARÉHO uloženia rozpis NEZAHODÍ');
  eq(ELS.updDir.value, 'B:/druha', 'ani neprepíše pole hodnotou A');
  ok(T.updMerged().dirty === true, 'a tlačidlo ostáva zamknuté (B nie je uložená)');

  // Uloženie B potvrdenie prijme — vrátane normalizovaného tvaru zo servera.
  ELS.updDir.value = 'B:/druha';
  fireKey(updEl({ 'data-updater-edit': 'source_dir' }, 'B:/druha'), 'Enter');
  T.SS.updater({ enabled: true, state: 'idle', source_dir: 'B:/druha', saved: true, current: '0.9.12' });
  eq(T.updDirty(), null, 'potvrdenie AKTUÁLNEHO uloženia rozpis zahodí');
  eq(ELS.updDir.value, 'B:/druha', 'a v poli je to, čo server uložil');
  eq(T.updSent(), null, 'pamäť odoslanej hodnoty sa vyčistí');
})();

// --- 5) VSTUP DO SEKCIE = PRESNE JEDEN CHECK ---------------------------------

(function(){
  function checks(){ return SENT.filter(function(x){ return x[0] === 'updater_check'; }).length; }

  // (a) DEEP-LINK (`open_section` z Ruby)
  S.setStudioSection('bom');
  SENT.length = 0;
  NX.setStudio({ model_title: 'T', version: '0.9.10', open_section: 'about', settings: STATE, bom: [] });
  eq(checks(), 1, 'deep-link do „O plugine" spustí PRESNE JEDEN check');

  // Ďalší plný push (zmena modelu) check NEOPAKUJE — inak by každý posun
  // skrinky siahal na sieťový share (F5).
  NX.setStudio({ model_title: 'T', version: '0.9.10', settings: STATE, bom: [] });
  eq(checks(), 1, 'plný push check NESPÚŠŤA');

  // (b) NAVIGÁCIA (klik v ľavom stĺpci)
  S.setStudioSection('bom');
  window.studioGoSection('about');
  eq(checks(), 2, 'navigácia do sekcie spustí ďalší jeden check');
  window.studioGoSection('about');
  eq(checks(), 2, 'znova otvorená TÁ ISTÁ sekcia check neopakuje');
  window.studioGoSection('bom');
  window.studioGoSection('about');
  eq(checks(), 3, 'odchod a návrat áno');
  eq(JSON.parse(SENT[SENT.length - 1][1]), {}, 'check si cestu pýta zo SERVERA (klient ju nediktuje)');
})();

// --- 6) ULOŽENIE CESTY: Enter aj mini-tlačidlo -------------------------------

(function(){
  S.setStudioSection('about');
  ELS.updDir.value = 'Z:/share/dist';
  SENT.length = 0;
  fireKey(updEl({ 'data-updater-edit': 'source_dir' }, 'Z:/share/dist'), 'Enter');
  eq(SENT.length, 1, 'Enter v poli cesty ukladá');
  eq(SENT[0][0], 'updater_set_dir', 'a je to VLASTNÁ akcia updatera, nie `ss_save`');
  eq(JSON.parse(SENT[0][1]).source_dir, 'Z:/share/dist', 'posiela sa hodnota z poľa');

  SENT.length = 0;
  fireKey(updEl({ 'data-ss': 'rate:montaz' }, '15'), 'Enter');
  eq(SENT.length, 0, 'Enter v poli SADZBY updater nespúšťa');

  SENT.length = 0;
  const save = stubEl('btn');
  save.setAttribute('data-updater-act', 'save-dir');
  fireClick(save);
  eq(SENT.map(function(x){ return x[0]; }), ['updater_set_dir'], 'mini-tlačidlo ukladá to isté');
})();

// --- 7) APLIKÁCIA: bez potvrdenia sa NESPUSTÍ --------------------------------

(function(){
  S.setStudioSection('about');
  // Potvrdené uloženie zahodí rozpis z predošlého bloku — inak by potvrdenie
  // menovalo cestu, ktorá ešte nie je uložená.
  T.SS.updater({ enabled: true, state: 'idle', source_dir: 'X:/dist', current: '0.9.10', saved: true });
  T.SS.updater({ enabled: true, state: 'newer', source_dir: 'X:/dist', current: '0.9.10',
                 available: '0.9.11' });

  // (a) neaktívne tlačidlo MLČAŤ nesmie — povie dôvod (D-78).
  const off = stubEl('btn');
  off.setAttribute('data-updater-act', 'apply');
  off.setAttribute('aria-disabled', 'true');
  SENT.length = 0;
  fireClick(off);
  eq(SENT.length, 0, 'klik na neaktívne tlačidlo NIČ neposiela');
  ok(ELS.status.textContent.length > 0, 'ale povie dôvod');

  // (b) bez kostry modalu sa swap NESPUSTÍ (mutácia „bariéra preskočená").
  const on = stubEl('btn');
  on.setAttribute('data-updater-act', 'apply');
  delete window.NXModal;
  SENT.length = 0;
  fireClick(on);
  eq(SENT.length, 0, 'bez D-15 potvrdenia sa aktualizácia NESPUSTÍ');
  ok(ELS.status.textContent.indexOf('nespustila') > -1, 'a sekcia to povie');

  // (c) s modalom: otvorí sa potvrdenie a AŽ jeho odoslanie posiela akciu.
  let opened = null;
  let closed = 0;
  window.NXModal = { open: function(spec){ opened = spec; },
                     close: function(){ closed += 1; } };
  SENT.length = 0;
  fireClick(on);
  eq(SENT.length, 0, 'samotný klik ešte nič nemení');
  ok(opened && opened.okLabel === 'Aktualizovať', 'otvorí sa D-15 potvrdenie');
  ok(opened.note.indexOf('ZATVORIA OBE OKNÁ') > -1, 'a hovorí, že sa zatvoria OBE okná');
  ok(opened.note.indexOf('REŠTARTUJ') > -1, 'aj že po dokončení treba reštart');
  ok(opened.sub.indexOf('X:/dist') > -1 && opened.sub.indexOf('V0.9.11') > -1,
     'potvrdenie menuje priečinok aj verziu');
  opened.onSubmit({});
  eq(SENT.map(function(x){ return x[0]; }), ['updater_apply'], 'až potvrdenie spustí aktualizáciu');
  eq(closed, 1, 'a modal sa zatvorí — okná sa o chvíľu zavrú aj s ním');
})();

// --- 8) STAVOVÝ RIADOK sa obnovuje CIELENE (fokus v poli prežije) ------------

(function(){
  S.setStudioSection('about');
  T.ssApplyState(STATE);
  ELS.secbody.innerHTML = 'TELO SEKCIE';
  ELS.updState.textContent = '';
  ELS.updBtn.setAttribute('aria-disabled', 'true');

  T.SS.updater({ enabled: true, state: 'newer', source_dir: 'X:/dist', current: '0.9.10',
                 available: '0.9.11' });
  eq(ELS.secbody.innerHTML, 'TELO SEKCIE',
     'výsledok checku telo sekcie NEPREKRESĽUJE (kurzor v poli cesty by prišiel o obsah)');
  ok(ELS.updState.textContent.indexOf('V0.9.11') > -1, 'ale stavový riadok je čerstvý');
  eq(ELS.updBtn.getAttribute('aria-disabled'), null, 'a tlačidlo sa odomklo');

  T.SS.updater({ enabled: true, state: 'same', source_dir: 'X:/dist', current: '0.9.10',
                 available: '0.9.10' });
  eq(ELS.updBtn.getAttribute('aria-disabled'), 'true', 'rovnaká verzia ho zase zamkne');

  // Kým sa píše do poľa cesty, telo sa neprekresľuje ani plným pushom.
  const inp = updEl({ 'data-updater-edit': 'source_dir' }, 'W:/rozpisane');
  document.activeElement = inp;
  ok(T.updTyping() === true, 'písanie do poľa cesty je rozpoznané');
  ELS.secbody.innerHTML = 'ROZPÍSANÁ CESTA';
  T.ssApplyState(STATE);
  eq(ELS.secbody.innerHTML, 'ROZPÍSANÁ CESTA', 'plný push telo sekcie NEPREPÍŠE, kým sa píše');
  document.activeElement = null;
  T.ssApplyState(STATE);
  ok(ELS.secbody.innerHTML !== 'ROZPÍSANÁ CESTA', 'po odchode z poľa sa telo prekreslí normálne');
})();

console.log(`OK ${n} kontrol (D-52b updater UI)`);
