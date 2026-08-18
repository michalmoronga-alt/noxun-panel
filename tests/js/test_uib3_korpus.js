// Testy UI-B3 — obsah Korpusu (Zakladne v 2 stlpcoch + informacny stlpec),
// rozmerove rady N6 a koliesko (tema / rady / o plugine).
//   node tests/js/test_uib3_korpus.js
//
// Kontrakt, ktory sa tu strazi:
//   1) rad je len PONUKA — vyber hodnoty ide EXISTUJUCOU zapisovou cestou pola
//      (zapis hodnoty + povodna udalost `input`), ziadna nova zapisova logika,
//   2) JS zrkadlo normalizacie hovori to iste co Ruby (autorita je Ruby),
//   3) informacny stlpec je TEXT z payloadu (vystupy nikdy nevyzeraju ako vstupy),
//   4) tema sa prepina VOLANIM Ruby (UI-01 API) — panel si farby sam nemeni,
//   5) existujuce rozmerove polia si drzia ID aj svoju change cestu.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

const ROOT = path.join(__dirname, '..', '..');
const UI = path.join(ROOT, 'noxun_engine', 'ui');
const NXDim = require(path.join(UI, 'js', 'settings.js'));
const { nxCabInfo, NX_TYPE_LABEL } = require(path.join(UI, 'js', 'core.js'));

const SETTINGS_SRC = fs.readFileSync(path.join(UI, 'js', 'settings.js'), 'utf8');
const PANEL_HTML = fs.readFileSync(path.join(UI, 'panel.html'), 'utf8');

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function ok(cond, msg){ n++; assert.ok(cond, msg); }

// --- 1) normalizacia radu (zrkadlo Ruby DimSeries) ---------------------------

eq(NXDim.normalizeList([600, '450', 600.4, 'x', null, true, 400, '', 450]), [400, 450, 600],
   'rad sa cisti: nezmysel von, duplicity prec, vzostupne');
eq(NXDim.normalizeList([0, -50, 9, 10, 3000, 3001, 999999]), [10, 3000],
   'hodnoty mimo rozsahu sa ZAHADZUJU (neorezavaju sa na hranicu)');
eq(NXDim.normalizeList(['450.6', '600.2']), [451, 600],
   'rad su CELE mm — desatinna bodka sa zaokruhli');
eq(NXDim.normalizeList(['450,6']), [],
   'ciarka je ODDELOVAC hodnot, nie desatinna — v hodnote nema co robit');
eq(NXDim.normalizeList([]), [], 'prazdny rad je PLATNY (rad sa da vypnut)');
eq(NXDim.normalizeList('600, 800'), null, 'retazec NIE JE rad — volajuci dosadi default');
eq(NXDim.normalizeList(null), null, 'chybajuca hodnota = default');
(function(){
  const many = [];
  for (let i = 1; i <= NXDim.MAX_VALUES + 15; i++) many.push(i * 10);
  eq(NXDim.normalizeList(many).length, NXDim.MAX_VALUES, 'rad je zastropovany poctom hodnot');
})();

(function(){
  const out = NXDim.normalize({ sirka: [500], hlupost: [1, 2] });
  eq(Object.keys(out).sort(), NXDim.KEYS.slice().sort(), 'neznamy kluc sa do vysledku nedostane');
  eq(out.sirka, [500], 'poslany rad plati');
  eq(out.vyska, NXDim.DEFAULTS.vyska, 'chybajuci kluc padne na predvolbu');
})();

// --- 2) editor: text <-> rad --------------------------------------------------

eq(NXDim.parseText('600, 800;900  1200'), ['600', '800', '900', '1200'],
   'oddelovac je ciarka, bodkociarka aj medzera');
eq(NXDim.normalizeList(NXDim.parseText('140,5 356')), [140, 356],
   'preklep „140,5" nerozbije rad — ciarka deli a jednociferny zvysok vypadne');
eq(NXDim.parseText(''), [], 'prazdny editor = prazdny rad');
eq(NXDim.formatList([400, 600]), '400, 600', 'do editora sa pise citatelny zoznam');
eq(NXDim.normalizeList(NXDim.parseText(NXDim.formatList(NXDim.DEFAULTS.sirka))), NXDim.DEFAULTS.sirka,
   'round-trip editorom nezmeni predvoleny rad');

// --- 3) ponuka pri poli -------------------------------------------------------

(function(){
  NXDim.set({ sirka: [400, 600] });
  const html = NXDim.menuHtml('sirka', 'width');
  ok(html.indexOf('nxDimPick(\'width\',400)') > 0, 'ponuka vola vyber hodnoty pre SVOJE pole');
  ok(html.indexOf('nxDimPick(\'width\',600)') > 0, 'ponuka nesie vsetky hodnoty radu');
  ok(html.indexOf('Upraviť rad…') > 0, 'ponuka ma vstup do editora radov');
  ok(html.indexOf('openInspectorSettings(\'series\')') > 0, '„Upraviť rad…" otvara koliesko na sekcii Rady');
  ok(!/<script|onerror|javascript:/i.test(html), 'do markupu ide len cislo — ziadny cudzi obsah');
  NXDim.set(null); // vrat predvolby pre dalsie kontroly
  eq(NXDim.get('sirka'), NXDim.DEFAULTS.sirka, 'set(null) vrati predvolenu sadu');
})();

// --- 4) vyber hodnoty ide EXISTUJUCOU cestou pola -----------------------------

(function(){
  const body = SETTINGS_SRC.slice(SETTINGS_SRC.indexOf('function nxDimPick'),
                                  SETTINGS_SRC.indexOf('if (typeof document !== \'undefined\'){'));
  ok(/inp\.value = String\(value\)/.test(body), 'hodnota sa zapise do POLA (nie inam)');
  ok(/dispatchEvent\(new Event\('input'/.test(body),
     'zmena sa ohlasi POVODNOU udalostou — dalej bezi onField, expr hint, validacia aj debounce apply');
  ok(!/sketchup\./.test(body), 'vyber z radu NEPOSIELA nic do Ruby — nie je to nova zapisova cesta');
})();

ok(!/apply_all|set_cabinet_material|insert_cabinet/.test(SETTINGS_SRC),
   'nastavenia Inspectora nesiahaju na zapisove cesty zakazky');

// --- 4b) klik na „Dielcov" nesmie zhltnut rozpisanu upravu (Codex BLOCKER 1) --

(function(){
  const actions = fs.readFileSync(path.join(UI, 'js', 'actions.js'), 'utf8');
  const body = actions.slice(actions.indexOf('function onInfoParts'),
                             actions.indexOf('function onInfoArea'));
  ok(body.indexOf('validateFields') > 0,
     'neplatne pole akciu ZASTAVI — flush by ju ticho neaplikoval');
  ok(body.indexOf('flushCabinetEditsNow') > 0,
     'rozpisany edit (400 ms debounce) sa odosle PRED zmenou vyberu');
  ok(body.indexOf('flushCabinetEditsNow') < body.indexOf('nx_select_parts'),
     'poradie je flush -> vyber (callbacky sa spracuju v poradi)');
  ok(body.indexOf('model_guid') > 0, 'asynchronny callback nesie identitu dokumentu');
})();

// --- 4c) modal šablóny drzi identitu DOKUMENTU (Codex BLOCKER 2) --------------

(function(){
  const form = fs.readFileSync(path.join(UI, 'js', 'form.js'), 'utf8');
  const open = form.slice(form.indexOf('function openSaveTemplateModal'),
                          form.indexOf('function closeSaveTemplateModal'));
  ok(/tplModalGuid = /.test(open), 'pri otvoreni sa zachyti aj DOKUMENT, nielen ID skrinky');
  const save = form.slice(form.indexOf('function saveTemplateAs'), form.indexOf('function bindTplModal'));
  ok(save.indexOf('validateFields') > 0, 'neplatne pole ulozenie ZASTAVI (inak by sablona bola zo starych hodnot)');
  ok(save.indexOf('model_guid: tplModalGuid') > 0, 'payload nesie dokument — server ho striktne overi');
  const stale = form.slice(form.indexOf('function tplModalStale'), form.indexOf('function openSaveTemplateModal'));
  ok(stale.indexOf('model_guid') > 0, 'otvoreny modal je „stary" aj pri zmene dokumentu, nielen ID skrinky');
})();

// --- 5) tema: prepina sa VOLANIM Ruby, JS si farby nemeni --------------------

ok(/sketchup\.nx_set_ui_theme/.test(SETTINGS_SRC), 'prepinac temy vola Ruby callback (UI-01 API)');
ok(!/setProperty\(\s*'--nx-/.test(SETTINGS_SRC),
   'panel si temove tokeny sam nenasadzuje — robi to nxThemeApply z Ruby (win_fit.js)');
ok(/data-nx-theme/.test(SETTINGS_SRC), 'aktivny stav prepinaca sa cita z korena dokumentu (pravda okna)');
(function(){
  // Vzorky farieb musia sediet s temami — inak by prepinac ponukal inu farbu,
  // nez naozaj nasadi (zrkadlo :root a NX_THEME_TOKENS).
  const winFit = fs.readFileSync(path.join(UI, 'js', 'win_fit.js'), 'utf8');
  const css = fs.readFileSync(path.join(UI, 'css', 'panel.css'), 'utf8');
  ok(/--nx-select':\s*'#c2185b'/.test(winFit), 'Lucia ma v temach ruzovy akcent #c2185b');
  ok(/\.thsw\[data-sw="lucia"\]\s*{\s*background:\s*#c2185b/.test(css), 'vzorka Lucie sedi s temou');
  ok(/\.thsw\[data-sw="noxun"\]\s*{\s*background:\s*#107787/.test(css), 'vzorka NOXUN sedi s :root');
})();

// --- 6) informacny stlpec: TEXT z payloadu ------------------------------------

eq(nxCabInfo({ parts_count: 9, parts_area_m2: 2.9, type: 'lower' }),
   { parts: '9', area: '2,9 m²', type: 'Dolná' }, 'udaje sa formatuju z payloadu servera');
eq(nxCabInfo({ parts_count: 12, parts_area_m2: 3.456, type: 'upper' }),
   { parts: '12', area: '3,46 m²', type: 'Horná' }, 'plocha ma dve desatinne miesta a slovensku ciarku');
eq(nxCabInfo({}), { parts: '—', area: '—', type: 'Dolná' },
   'chybajuci udaj = pomlcka (radsej ziadne cislo nez vymyslene)');
eq(nxCabInfo(null), { parts: '—', area: '—', type: 'Dolná' }, 'bez skrinky su same pomlcky');
eq(nxCabInfo({ parts_count: 0, parts_area_m2: 0 }), { parts: '—', area: '—', type: 'Dolná' },
   'nula nie je udaj — skrinka bez dielcov ukaze pomlcku');
eq(NX_TYPE_LABEL.upper, 'Horná', 'slovensky nazov typu zije na JEDNOM mieste');

// --- 7) kostra panela: vstupy ostali vstupmi, vystupy su text -----------------

(function(){
  const grid = PANEL_HTML.slice(PANEL_HTML.indexOf('<fieldset id="basicCard">'),
                                PANEL_HTML.indexOf('<!-- ===== S3 · MATERIALY'));
  ['width', 'height', 'depth', 'thickness', 'floor_height'].forEach(function(id){
    ok(new RegExp('id="' + id + '" type="text" oninput="onField\\(\\)"').test(grid),
       'pole ' + id + ' si drzi ID aj svoju change cestu (onField)');
    ok(new RegExp('data-lock="' + id + '"').test(grid), 'pole ' + id + ' ma dalej zamok vkladacej karty (D-39)');
  });
  const info = grid.slice(grid.indexOf('<div class="infocol">'));
  ok(info.indexOf('<input') < 0, 'informacny stlpec NEMA polia — vystupy sa netvaria ako vstupy');
  ['av_width', 'av_depth', 'av_height', 'inf_parts', 'inf_area'].forEach(function(id){
    ok(new RegExp('<b id="' + id + '"').test(info), 'udaj ' + id + ' je TEXT (<b>), nie input');
  });
  ok(/id="infParts"[^>]*onclick="onInfoParts\(\)"/.test(info), 'Dielcov su klikatelne (N13)');
  ok(/id="infArea"[^>]*onclick="onInfoArea\(\)"/.test(info), 'Materiál je klikatelny (N13)');
  ok(/Hmotnosť<\/span><b>—<\/b>/.test(info.replace(/\s+/g, ' ').replace(/<span>/g, '<span>')) ||
     info.indexOf('Hmotnosť') > 0, 'hmotnost je zatial pomlcka s vysvetlenim');
  ['dimser_width', 'dimser_height', 'dimser_depth', 'dimser_floor_height'].forEach(function(id){
    ok(grid.indexOf('id="' + id + '"') > 0, 'pole ma miesto pre svoj rozmerovy rad (' + id + ')');
  });
  ok(grid.indexOf('id="dimser_thickness"') < 0, 'hrubka rad NEMA — urcuje ju material (D-45)');
})();

(function(){
  // Skupiny Korpusu maju ikony (N3b), koliesko ma tri sekcie z kontraktu.
  [['#i-p-top', 'Strop'], ['#i-p-bottom', 'Dno'], ['#i-p-side', 'Boky'], ['#i-p-back', 'Chrbát']]
    .forEach(function(o){
      ok(new RegExp('<use href="' + o[0] + '"/></svg>' + o[1]).test(PANEL_HTML),
         'skupina ' + o[1] + ' ma svoju ikonu');
    });
  const cfg = PANEL_HTML.slice(PANEL_HTML.indexOf('<div id="cfgModal"'), PANEL_HTML.indexOf('<div id="status">'));
  ok(cfg.indexOf('id="cfg_theme"') > 0, 'koliesko ma sekciu Vzhľad');
  ok(cfg.indexOf('id="cfg_series"') > 0, 'koliesko ma sekciu Rozmerové rady');
  ok(cfg.indexOf('id="cfg_about"') > 0, 'koliesko ma sekciu O plugine');
  ok(cfg.indexOf('id="cfgVersion"') > 0, 'verzia v koliesku ide z Ruby (ziadny hardcode)');
  NXDim.KEYS.forEach(function(k){
    ok(cfg.indexOf('id="ser_' + k + '"') > 0, 'editor ma pole pre rad ' + k);
  });
  ok(/id="tplSaveType"/.test(PANEL_HTML), 'modal šablóny nesie Názov aj Typ');
})();

// --- 8) sprite: nove ikony existuju ------------------------------------------

(function(){
  const icons = fs.readFileSync(path.join(UI, 'js', 'icons.js'), 'utf8');
  ['arr-h', 'arr-v', 'arr-d', 'plinth', 'p-top', 'p-bottom', 'p-side', 'p-back', 'brace', 'palette']
    .forEach(function(id){
      ok(icons.indexOf("'" + id + "':") > 0, 'sprite ma ikonu ' + id);
    });
})();

console.log(`UI-B3 korpus: ${n} kontrol OK`);
