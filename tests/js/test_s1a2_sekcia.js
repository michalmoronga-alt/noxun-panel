// S1-A2 — sekcia SPOTREBIČE (`appl`) v okne Štúdio (klient).
//
// Prečo sú to testy a nie klikanie:
//   1. ECHO po zápise píše do ZDIEĽANÉHO `#secbody`. Keby kreslilo aj vtedy,
//      keď je otvorená iná sekcia, uloženie spotrebiča by prepísalo rozpísaný
//      formulár Rozpočtu — a navigácia by pritom stále ukazovala Rozpočet
//      (review #225 P1). Klikaním to uvidíš len náhodou.
//   2. HĽADANIE je debounced a odpovede chodia asynchrónne. Bez porovnania
//      `gen` by pomalšie kolo prepísalo čerstvejší strom a používateľ by
//      videl výsledky pre text, ktorý už dávno prepísal.
//   3. TOKEN odoslania: výsledok formulára, ktorý používateľ medzitým zavrel,
//      nesmie zavrieť ten nový a zahodiť jeho rozpísaný koncept.
//   4. PORADIE stromu skladá SERVER. Keby si ho klient preskladal (napr.
//      abecedne), prestali by sedieť počty v hlavičkách skupín a kategória by
//      sa mohla rozpadnúť na dve miesta.
//   5. Mená modelov píše používateľ — neescapovaný `<` rozbije celú sekciu.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

// --- DOM stub (vzor tests/js/test_st3c_tpl.js) -------------------------------
const ELS = {};
function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '', _attrs: {}, value: '' };
  Object.defineProperty(n, 'innerHTML', {
    get(){ return n._html; },
    set(v){ n._html = v; }
  });
  Object.defineProperty(n, 'textContent', {
    get(){ return n._text || ''; },
    set(v){ n._text = v; }
  });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.querySelector = function(){ return null; };
  n.querySelectorAll = function(){ return []; };
  return n;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio'].forEach(function(id){ ELS[id] = stubEl(id); });

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
const LISTEN = {};
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
global.NX = global.window.NX;           // poradie <script> v studio.html
const A = require(path.join(JS, 'appliances.js'));

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }
function ok(c, msg){ n++; assert.ok(c, msg); }

function sentOf(name){ return SENT.filter(function(x){ return x[0] === name; }); }
function lastPayload(name){
  const rows = sentOf(name);
  return rows.length ? JSON.parse(rows[rows.length - 1][1]) : null;
}
function reset(){
  SENT.length = 0;
  A.apReset();
  ELS.secbody._html = '';
  ELS.sectools._html = '';
  S.setStudioSection('appl');
}

// --- vzorové payloady (presne v tvare, aký skladá appliance_dialog.rb) -------

function tree(extra){
  return Object.assign({
    gen: 1, query: '', include_deleted: false, total: 3, deleted_total: 0, seed_total: 2,
    state: 'ok', state_reason: '', writable: true,
    categories: [['fridge', 'Chladnička'], ['oven', 'Rúra'], ['sink', 'Drez']],
    groups: [
      { code: 'fridge', label: 'Chladnička', total: 1,
        items: [{ id: 'f1', name: 'BCNA306E5ZSN', manufacturer: 'Beko',
                  title: 'Beko BCNA306E5ZSN', category: 'fridge',
                  sub: 'nika min 560 × 1940 – 1950 · seed', seed: true, deleted: false }] },
      { code: 'oven', label: 'Rúra', total: 2,
        items: [{ id: 'o1', name: 'HBG774KB1', manufacturer: 'Bosch', title: 'Bosch HBG774KB1',
                  category: 'oven', sub: 'nika 560 – 568 · seed', seed: true, deleted: false },
                { id: 'o2', name: 'OMSR58RU1SB', manufacturer: 'Whirlpool',
                  title: 'Whirlpool OMSR58RU1SB', category: 'oven',
                  sub: 'nika 560 – 568 · seed', seed: true, deleted: false }] },
      { code: 'sink', label: 'Drez', total: 0, items: [] }
    ]
  }, extra || {});
}

function card(extra){
  return Object.assign({
    id: 'f1', rev: 'r1', name: 'BCNA306E5ZSN', manufacturer: 'Beko', category: 'fridge',
    category_label: 'Chladnička', seed: true, deleted: false, note: 'Nosnosť dna list nekótuje.',
    state: 'ok', state_reason: '', writable: true,
    blocks: [
      { key: 'body', title: 'Telo (rozmery spotrebiča)', icon: 'box',
        rows: [{ label: 'Š × V × H', value: '540 × 1935 × 545', unit: 'mm', derived: false }] },
      { key: 'niche', title: 'Nika (výklenok v skrinke)', icon: 'cabinet',
        rows: [{ label: 'šírka', value: 'min 560', unit: 'mm', derived: false },
               { label: 'výška', value: null, unit: 'mm', derived: false }] },
      { key: 'front', title: 'Dvere spotrebiča (zdola)', icon: 'door',
        rows: [{ label: 'spodok', value: '40', unit: 'mm', derived: true }] },
      { key: 'install', title: 'Montáž', icon: 'settings', rows: [] }
    ],
    shop_urls: [{ url: 'https://nay.sk/beko', label: 'nay.sk' }],
    sheet_urls: [{ url: 'https://beko.com/list.pdf', label: 'beko.com' }],
    attachments: [
      { id: 'a1', kind: 'thumbnail', name: 'beko.jpg', ext: 'jpg', image: true, thumbnail: true },
      { id: 'a2', kind: 'sheet', name: 'Installation.pdf', ext: 'pdf', image: false, thumbnail: false }
    ],
    thumbs: {}, fields: { category: 'fridge', manufacturer: 'Beko', name: 'BCNA306E5ZSN',
                          note: '', shop_urls: [], sheet_urls: [], 'dims.body.width': '540' }
  }, extra || {});
}

const FORM = {
  fridge: [{ type: 'group', label: 'Telo (rozmery spotrebiča)' },
           { key: 'dims.body.width', label: 'šírka', block: 'body', field: 'width',
             type: 'text', unit: 'mm' },
           { key: 'dims.install.door_system', label: 'dvere', block: 'install',
             field: 'door_system', type: 'select',
             options: [['', '—'], ['sliding', 'posuvné lišty']] }],
  oven: [{ type: 'group', label: 'Čelo a presahy' },
         { key: 'dims.front.thickness', label: 'hrúbka čela', block: 'front', field: 'thickness',
           type: 'text', unit: 'mm' }],
  sink: [{ type: 'group', label: 'Drez a výrez' },
         { key: 'dims.front.bowl_depth', label: 'hĺbka vane', block: 'front', field: 'bowl_depth',
           type: 'text', unit: 'mm' }]
};

// --- 1) LIŠTA ----------------------------------------------------------------

reset();
A.apSetTree(tree());
{
  const h = A.apToolsHtml(A.apToolsState());
  ok(h.includes('data-ap="view" data-v="job"'), 'lišta má segment pohľadov');
  ok(h.includes('aria-disabled="true"') && h.includes('S1-B'),
     'pohľad V zákazke je aria-disabled s dôvodom (D-78)');
  ok(!/ disabled[ >]/.test(h), 'a NIE je HTML disabled — to by ho vyhodilo z Tab poradia');
  ok(h.includes('data-ap="new"'), 'je tam Nový spotrebič');
  ok(h.includes('id="apQ"') && h.includes('id="apDel"'), 'hľadanie aj prepínač vyradených');
  ok(h.includes('3 modely'), 'počet modelov skladá klient z čísla servera');
  ok(!h.includes('Obnoviť'), 'žiadne „Obnoviť" — katalóg nie je z modelu');
}
eq(A.apCountLabel(1, 0), '1 model', 'jednotné číslo');
eq(A.apCountLabel(5, 5), '5 modelov (5 seed)', 'množné číslo a počet seed záznamov');

// Read-only katalóg: zápisy sa vypnú a dôvod je nad stromom.
A.apSetTree(tree({ writable: false, state: 'degraded',
                   state_reason: 'katalóg je poškodený — číta sa záloha' }));
{
  const h = A.apToolsHtml(A.apToolsState());
  ok(h.includes('data-ap="new"') && h.includes('aria-disabled="true"'),
     'Nový spotrebič je pri read-only katalógu aria-disabled');
  const b = A.apBannerHtml(A.apState().tree);
  ok(b.includes('len na čítanie') && b.includes('poškodený'),
     'banner nesie DÔVOD zo servera, nie vlastnú vetu');
}
eq(A.apBannerHtml({ state: 'ok' }), '', 'zdravý katalóg banner nekreslí');

// --- 2) STROM ----------------------------------------------------------------

reset();
A.apSetTree(tree());
{
  const h = A.apTreeHtml(A.apState().tree);
  const order = (h.match(/Chladnička|Rúra|Drez/g) || []);
  eq(order, ['Chladnička', 'Rúra', 'Drez'], 'poradie skupín je PRESNE to, čo poslal server');
  const items = (h.match(/data-ap="sel" data-id="([a-z0-9]+)"/g) || []);
  eq(items.length, 3, 'tri položky');
  ok(h.indexOf('Bosch HBG774KB1') < h.indexOf('Whirlpool OMSR58RU1SB'),
     'a poradie položiek v skupine sa tiež nepreskladáva');
  ok(h.includes('<span class="cnt">0</span>'), 'prázdna kategória ostáva v strome s nulou');
  ok(h.includes('nika min 560'), 'podtitul riadku skladá server');
}

// Vyradené: skupina je v payloade len s prepínačom, klient si ju nedopĺňa.
{
  const t = tree({ include_deleted: true, deleted_total: 1, gen: 2 });
  t.groups.push({ code: 'deleted', label: 'Vyradené', total: 1,
                  items: [{ id: 'd1', name: 'ART 97101', manufacturer: 'Whirlpool',
                            title: 'Whirlpool ART 97101', category: 'fridge',
                            sub: 'nika · seed · vyradený', seed: true, deleted: true }] });
  A.apSetTree(t);
  const h = A.apTreeHtml(A.apState().tree);
  ok(h.includes('Vyradené'), 'skupina vyradených');
  ok(h.includes('apitem tomb'), 'a vyradený záznam je odlíšený');
}

// --- 3) generácia hľadania ---------------------------------------------------

reset();
A.apSetTree(tree({ gen: 5, total: 1 }));
A.apSetTree(tree({ gen: 3, total: 99 }));       // pomalšia odpoveď staršieho kola
eq(A.apState().tree.total, 1, 'staršia odpoveď NEPREPÍŠE čerstvejší strom');
A.apSetTree(tree({ gen: 6, total: 7 }));
eq(A.apState().tree.total, 7, 'novšia áno');

reset();
A.apSearch('beko');
eq(sentOf('appl_tree').length, 0, 'hľadanie je debounced — dotaz neodchádza pri každom znaku');
eq(A.apState().q, 'beko', 'ale text si klient pamätá hneď');

// --- 4) echo kreslí LEN v aktívnej sekcii ------------------------------------

reset();
S.setStudioSection('budget');                    // používateľ je v Rozpočte
ELS.secbody._html = '<b>rozpísaný formulár rozpočtu</b>';
A.apSetTree(tree());
A.apSetCard(card());
eq(ELS.secbody._html, '<b>rozpísaný formulár rozpočtu</b>',
   'echo katalógu NEPREPÍŠE cudziu sekciu (#secbody je zdieľaný uzol)');
ok(A.apState().tree !== null, 'stav sa napriek tomu ULOŽÍ — vykreslí ho vstup do sekcie');
S.setStudioSection('appl');
A.apRenderBody();
ok(ELS.secbody._html.includes('Beko BCNA306E5ZSN'), 'a pri vstupe do sekcie sa dokreslí');

// --- 5) KARTA ----------------------------------------------------------------

reset();
A.apSetTree(tree());
A.apSetCard(card());
{
  const h = A.apCardHtml(A.apState().card, A.apState().thumbs);
  eq((h.match(/class="apblk"/g) || []).length, 4, 'karta má štyri bloky');
  ok(h.includes('<b>540 × 1935 × 545 mm</b>'), 'hodnota aj jednotka');
  ok(h.includes('<i>— <span class="apnote">(list nekótuje)</span></i>'),
     'neznáme pole je „—" kurzívou, nikdy nula ani odhad');
  ok(h.includes('(odvodené)'), 'odvodená hodnota sa prizná');
  ok(h.includes('táto kategória tu nemá kótované polia'),
     'prázdny blok povie prečo — mlčiaci rám vyzerá ako chyba');
  ok(h.includes('data-ap="tojob" aria-disabled="true"'), '„Do zákazky" je aria-disabled (D-78)');
  ok(h.includes('data-ap="url" data-u="https://nay.sk/beko"'), 'odkaz je tlačidlo, nie href');
  ok(!h.includes('href="https://'), 'v karte NIE JE žiadny href — otvára server');
  ok(h.includes('apfile main'), 'náhľad má vlastný rám');
  ok(h.includes('data-ap="add"'), 'a je tam dlaždica Pridať');
  ok(h.includes('apbadge'), 'seed záznam je označený');
}
eq(A.apCardHtml(null, {}).includes('Vyber model'), true, 'bez výberu karta pozýva do stromu');

// Vyradený záznam: namiesto „Vyradiť" ponúka „Obnoviť".
{
  const h = A.apCardHtml(card({ deleted: true }), {});
  ok(h.includes('data-ap="restore"'), 'vyradený záznam má Obnoviť');
  ok(!h.includes('data-ap="del"'), 'a už nie Vyradiť');
}

// Read-only katalóg: karta neponúka zápisy.
{
  const h = A.apCardHtml(card({ writable: false }), {});
  ok(!h.includes('data-ap="edit"') && !h.includes('data-ap="del"') && !h.includes('data-ap="add"'),
     'pri read-only katalógu sa zápisové tlačidlá vôbec nekreslia');
  ok(!h.includes('data-ap="thumb"') && !h.includes('data-ap="unfile"'),
     'ani akcie dlaždice prílohy — obe sú zápis a server by ich odmietol');
  ok(h.includes('data-ap="open"'), 'otvoriť prílohu sa ale dá — je to čítanie');
}

// Escapovanie: meno modelu píše používateľ.
{
  const h = A.apCardHtml(card({ name: '<img src=x onerror=alert(1)>' }), {});
  ok(!h.includes('<img src=x'), 'meno modelu je escapované');
  ok(h.includes('&lt;img'), 'a vidno ho ako text');
}

// --- 6) lazy miniatúry -------------------------------------------------------

reset();
A.apSetTree(tree());
A.apSetCard(card());
eq(A.apThumbMissing(A.apState().card), ['a1'], 'chýba len obrázok — PDF miniatúru nemá');
{
  const p = lastPayload('appl_card');
  ok(p, 'sekcia si o chýbajúcu miniatúru požiada hneď po vykreslení karty');
  eq(p.thumbs, true, 'a to výslovne');
  eq(p.have, [], 'so zoznamom toho, čo už má');
  eq(A.apRequestThumbs(), false, 'kým odpoveď nedorazí, druhý raz sa nepýta');
}
A.apSetCard(card({ thumbs: { a1: 'data:image/png;base64,AAA' } }));
{
  const h = A.apCardHtml(A.apState().card, A.apState().thumbs);
  ok(h.includes('<img src="data:image/png;base64,AAA"'), 'miniatúra sa nakreslí z cache');
  eq(A.apThumbMissing(A.apState().card), [], 'a už nechýba nič');
  eq(A.apRequestThumbs(), false, 'takže sa o ňu sekcia druhý raz nepýta');
}
// Záporná odpoveď je PLATNÁ odpoveď — dlaždica ostane na ikone a nepýta sa znova.
reset();
A.apSetTree(tree());
A.apSetCard(card({ thumbs: { a1: null } }));
eq(A.apThumbMissing(A.apState().card), [], 'null v cache znamená „náhľad nebude"');
{
  const h = A.apCardHtml(A.apState().card, A.apState().thumbs);
  ok(h.includes('#i-image'), 'a dlaždica kreslí ikonu, nie prázdno');
}

// --- 7) MODAL: polia per kategória + memoryKey + token -----------------------

const MODAL = {
  _open: false, _spec: null, _busy: false, _errors: null, _vals: {},
  open(spec){ this._open = true; this._spec = spec; },
  close(){ this._open = false; },
  isOpen(){ return this._open; },
  busyLocked(){ return false; },
  setBusy(f, o){ this._busy = f; this._clear = o && o.clear === true; },
  showErrors(e){ this._errors = e; },
  values(){ return this._vals; }
};
global.window.NXModal = MODAL;

reset();
A.apSetTree(tree({ form: FORM }));
A.apOpenModal('create');
ok(MODAL._open, 'modal sa otvoril');
{
  const spec = MODAL._spec;
  eq(spec.memoryKey, 'appl:create', 'memoryKey nového záznamu');
  ok(spec.title.includes('Nový'), 'titulok');
  ok(spec.sub.includes('bez ceny'), 'podtitul hovorí, že cena patrí zákazke');
  const keys = spec.fields.filter(f => f.key).map(f => f.key);
  eq(keys.slice(0, 3), ['category', 'manufacturer', 'name'], 'identita je prvá');
  ok(keys.includes('dims.body.width'),
     'polia kategórie sú tie, ktoré poslal server — kľúč je cesta z chyby katalógu');
  ok(!keys.includes('dims.front.thickness'), 'a polia CUDZEJ kategórie tam nie sú');
  ok(keys.includes('shop_urls') && keys.includes('sheet_urls'), 'odkazy sú opakovateľné riadky');
  const cat = spec.fields.find(f => f.key === 'category');
  eq(cat.options.length, 3, 'kategórie do selectu dáva server');
  ok(!cat.disabled, 'pri novom zázname sa kategória vybrať dá');
}

// Prepnutie kategórie mení SADU POLÍ a nestráca rozpísané hodnoty.
MODAL._vals = { category: 'oven', manufacturer: 'Bosch', name: 'HBG', 'dims.body.width': '596',
                shop_urls: [{ url: 'https://a.sk' }], sheet_urls: [] };
A.apOnCategoryChange('oven');
{
  const spec = MODAL._spec;
  const keys = spec.fields.filter(f => f.key).map(f => f.key);
  ok(keys.includes('dims.front.thickness'), 'po prepnutí sú tam polia novej kategórie');
  ok(!keys.includes('dims.body.width'), 'a polia starej už nie');
  eq(spec.fields.find(f => f.key === 'manufacturer').value, 'Bosch',
     'rozpísaný výrobca prežil prepnutie kategórie');
  eq(spec.skipMemory, true,
     'prekreslenie NEVLIEVA pamäť — na obrazovke sú čerstvejšie hodnoty');
  eq(spec.fields.find(f => f.key === 'shop_urls').value, [{ url: 'https://a.sk' }],
     'aj rozpísané odkazy');
}

// Úprava: memoryKey nesie identitu záznamu a kategória je zamknutá.
reset();
A.apSetTree(tree({ form: FORM }));
A.apSetCard(card());
A.apOpenModal('edit');
eq(MODAL._spec.memoryKey, 'appl:edit:f1', 'memoryKey editu nesie id záznamu');
eq(MODAL._spec.fields.find(f => f.key === 'category').disabled, true,
   'kategóriu záznamu už nemožno zmeniť');
eq(MODAL._spec.fields.find(f => f.key === 'manufacturer').value, 'Beko',
   'formulár je predvyplnený hodnotami zo SERVERA');

// Odoslanie: token, payload a „zápis modal nezatvára".
MODAL._spec.onSubmit({ category: 'fridge', manufacturer: 'Beko', name: 'X',
                       'dims.body.width': '540', shop_urls: [{ url: 'https://a.sk' }, { url: '  ' }],
                       sheet_urls: [], note: '' });
{
  const p = lastPayload('appl_patch');
  ok(p, 'odišiel patch');
  eq(p.id, 'f1', 'nad správnym záznamom');
  eq(p.rev, 'r1', 'a s revíziou z karty (optimistický zámok)');
  ok(!('category' in p.fields), 'kategória sa pri edite neposiela');
  eq(p.fields.shop_urls, ['https://a.sk'], 'prázdne riadky odkazov vypadnú');
  ok(MODAL._open, 'modal po odoslaní ostáva OTVORENÝ — zatvorí ho až server (D-15)');
  ok(p.token && p.token.length > 4, 'odoslanie má token');
}

// Cudzí token: odpoveď na formulár, ktorý už nikto nečaká, sa IGNORUJE.
{
  const token = lastPayload('appl_patch').token;
  MODAL._busy = true;
  A.apResult(true, 'Uložené.', [], 'patch', 'cudzi-token');
  ok(MODAL._open, 'cudzia odpoveď modal NEZAVRELA');
  A.apResult(true, 'Uložené.', [], 'patch', token);
  ok(!MODAL._open, 'vlastná áno');
  eq(MODAL._clear, true, 'a potvrdený zápis zahodí pamäť konceptu');
}

// Odmietnutie: modal ostáva otvorený, chyba sedí pri poli.
reset();
A.apSetTree(tree({ form: FORM }));
A.apSetCard(card());
A.apOpenModal('edit');
MODAL._spec.onSubmit({ manufacturer: 'Beko', name: 'X' });
{
  const token = lastPayload('appl_patch').token;
  A.apResult(false, 'minimum nesmie byť väčšie než maximum',
             [{ field: 'dims.niche.width_min', msg: 'minimum nesmie byť väčšie než maximum' }],
             'patch', token);
  ok(MODAL._open, 'odmietnutý zápis modal NEZATVÁRA');
  eq(MODAL._busy, false, 'a odomkne odoslanie (inak by „Uložiť" ostalo navždy zosednuté)');
  eq(MODAL._errors[0].field, 'dims.niche.width_min',
     'chyba nesie cestu poľa — showErrors ju posadí k vstupu');
}

// --- 8) akcie príloh a odkazov ----------------------------------------------

reset();
A.apSetTree(tree());
A.apSetCard(card());
A.apSelect('o1');
eq(lastPayload('appl_card').id, 'o1', 'výber záznamu pýta kartu');
A.apToggleDeleted(true);
eq(lastPayload('appl_tree').include_deleted, true, 'prepínač vyradených ide na server');
A.apOnLeaveSection();
ok(sentOf('appl_leave').length === 1, 'odchod zo sekcie sa ohlási serveru');
eq(A.apState().q, '', 'a klient zabudne filter spolu so serverom');

// --- 8b) Codex kolo 1 (P2): konflikt, fail-closed mazanie, minimálny patch ---

// (P2 #1) Po konflikte drží modal ČERSTVÚ revíziu — inak by každé ďalšie
// „Uložiť" narazilo na ten istý konflikt a z formulára sa nedalo dostať inak
// než zahodením práce.
reset();
A.apSetTree(tree({ form: FORM }));
A.apSetCard(card());
A.apOpenModal('edit');
MODAL._spec.onSubmit({ manufacturer: 'Beko', name: 'Nové meno' });
{
  const first = lastPayload('appl_patch');
  eq(first.rev, 'r1', 'prvé uloženie ide so zámkom z karty');
  const token = first.token;
  // Server: echo karty s novou revíziou + applResult s `info.rev`.
  A.apSetCard(card({ rev: 'r2' }));
  A.apResult(false, 'Záznam medzitým zmenil iný SketchUp — skontroluj hodnoty a ulož znova.',
             [{ msg: 'Záznam medzitým zmenil iný SketchUp — skontroluj hodnoty a ulož znova.' }],
             'patch', token, { rev: 'r2' });
  ok(MODAL._open, 'konflikt modal NEZATVÁRA — rozpísané hodnoty ostávajú');
  eq(MODAL._busy, false, 'a odomkne odoslanie');
  ok(String(MODAL._errors[0].msg).includes('iný SketchUp'), 'veta povie, čo sa naozaj stalo');
  MODAL._spec.onSubmit({ manufacturer: 'Beko', name: 'Nové meno' });
  eq(lastPayload('appl_patch').rev, 'r2',
     'druhé uloženie ide s ČERSTVOU revíziou — konflikt sa nezacyklí');
}

// (P2 #1b) Zámok obnovuje aj SAMOTNÉ ECHO karty — zápis z druhej inštancie
// (alebo príloha pridaná v karte pod otvoreným modalom) posunie `rev` bez
// toho, aby k nemu prišiel akýkoľvek `applResult`.
reset();
A.apSetTree(tree({ form: FORM }));
A.apSetCard(card());
A.apOpenModal('edit');
A.apSetCard(card({ rev: 'r9' }));               // echo po cudzom zápise
MODAL._spec.onSubmit({ manufacturer: 'Beko', name: 'Iné meno' });
eq(lastPayload('appl_patch').rev, 'r9',
   'formulár ukladá s revíziou z posledného echa — nie s tou z času otvorenia');

// (P2 #2) Bez kostry D-15 sa NEVYRADÍ nič (fail closed).
reset();
A.apSetTree(tree());
A.apSetCard(card());
{
  const saved = global.window.NXModal;
  global.window.NXModal = null;
  A.apDelete();
  eq(sentOf('appl_delete').length, 0, 'bez modalu sa tombstone NEODOŠLE');
  ok(String(ELS.status.textContent).includes('Vyradenie potrebuje dialóg'),
     'a okno povie prečo');
  global.window.NXModal = saved;
}

// (P2 #3) Patch nesie LEN zmenené polia — oprava názvu sa nedotkne rozmerov.
reset();
A.apSetTree(tree({ form: FORM }));
A.apSetCard(card({ fields: { category: 'fridge', manufacturer: 'Beko', name: 'BCNA306E5ZSN',
                             note: '', shop_urls: ['https://nay.sk/beko'], sheet_urls: [],
                             'dims.body.width': '540', 'dims.front.thickness': '19,55' } }));
A.apOpenModal('edit');
MODAL._spec.onSubmit({ category: 'fridge', manufacturer: 'Beko', name: 'Beko Beyond',
                       note: '', shop_urls: [{ url: 'https://nay.sk/beko' }], sheet_urls: [],
                       'dims.body.width': '540', 'dims.front.thickness': '19,55' });
{
  const p = lastPayload('appl_patch');
  eq(Object.keys(p.fields), ['name'], 'ide LEN zmenený názov');
  eq(p.fields.name, 'Beko Beyond', 'a s novou hodnotou');
  ok(!('dims.front.thickness' in p.fields),
     'nedotknutý rozmer sa neposiela — inak by ho prepísalo zaokrúhlenie');
  ok(!('shop_urls' in p.fields), 'ani nezmenené odkazy (server ich posiela ako reťazce)');
}
eq(A.apChangedFields({ a: '1', b: '2' }, { a: '1', b: '3' }), { b: '2' }, 'diff po kľúčoch');
eq(A.apChangedFields({ u: ['x'] }, { u: ['x'] }), {}, 'zhodné polia sa nepočítajú za zmenu');

// Nič sa nezmenilo = nič sa neposiela a modal sa zavrie bez chyby servera.
reset();
A.apSetTree(tree({ form: FORM }));
A.apSetCard(card());
A.apOpenModal('edit');
MODAL._spec.onSubmit({ category: 'fridge', manufacturer: 'Beko', name: 'BCNA306E5ZSN',
                       note: '', shop_urls: [], sheet_urls: [], 'dims.body.width': '540' });
eq(sentOf('appl_patch').length, 0, 'prázdny patch sa NEODOSIELA');
ok(!MODAL._open, 'modal sa zavrie');
ok(String(ELS.status.textContent).includes('Nič sa nezmenilo'), 'a povie to');

// (P2 #4) Dávkovanie miniatúr pokračuje aj nad CACHOVANOU kartou.
reset();
A.apSetTree(tree());
{
  const many = [];
  for (let i = 1; i <= 8; i++){
    many.push({ id: 'i' + i, kind: 'image', name: 'x' + i + '.png', ext: 'png',
                image: true, thumbnail: false });
  }
  const first = {};
  for (let i = 1; i <= 6; i++) first['i' + i] = 'data:image/png;base64,AAA';
  SENT.length = 0;
  A.apSetCard(card({ attachments: many, thumbs: first }));
  eq(A.apThumbMissing(A.apState().card), ['i7', 'i8'], 'dve dlaždice ostali bez miniatúry');
  eq(sentOf('appl_card').length, 1, 'reťaz dávok POKRAČUJE sama — o zvyšok si sekcia požiada');
  eq(lastPayload('appl_card').have.length, 6, 'a povie, čo už má');

  // Odchod a návrat: poistka „posledné kolo nič neprinieslo" platí pre jeden
  // pobyt v sekcii, inak by sa raz zaseknuté dlaždice už nikdy nedopýtali.
  A.apOnLeaveSection();
  SENT.length = 0;
  A.apRenderBody();                              // návrat do sekcie nad cache
  eq(sentOf('appl_card').length, 1, 'po návrate do sekcie sa dávkovanie obnoví');
}

// (P2 #5) Generácia zo servera sa preberie — po znovuotvorení Štúdia sa
// dotazy neposielajú s číslom, ktoré je pod už videným.
reset();
A.apSetTree(tree({ gen: 12, form: FORM }));
ok(A.apState().gen >= 12, 'klient prevzal generáciu z payloadu (štartoval od nuly)');
A.apToggleDeleted(true);
{
  const g = lastPayload('appl_tree').gen;
  ok(g > 12, 'ďalší dotaz ide NAD ňou (' + g + ') — vlastnú odpoveď klient nezahodí');
  A.apSetTree(tree({ gen: g, total: 4 }));
  eq(A.apState().tree.total, 4, 'a odpoveď na ten dotaz sa naozaj prijme');
}

// (P2 #6) Prekreslenie pri zmene kategórie podáva PÔVODNÝ baseline.
reset();
A.apSetTree(tree({ form: FORM }));
A.apOpenModal('create');
{
  const base0 = MODAL._spec.fields;
  MODAL._vals = { category: 'oven', manufacturer: 'Bosch', name: 'HBG',
                  shop_urls: [], sheet_urls: [] };
  A.apOnCategoryChange('oven');
  ok(Array.isArray(MODAL._spec.baseFields), 'prekreslenie nesie `baseFields`');
  eq(MODAL._spec.baseFields, base0,
     'a je to PÔVODNÁ špecifikácia — pamäť D-15 má voči čomu porovnávať');
  eq(MODAL._spec.baseFields.find(f => f.key === 'category').value, 'fridge',
     'baseline drží kategóriu, s ktorou sa začalo');
}

// --- 9) MUTÁCIE (čo test naozaj chytí) ---------------------------------------
// M1 „echo kreslí aj mimo aktívnej sekcie" zabije test v bloku 4.
// M2 „token echo neporovnáva" zabije test v bloku 7 (cudzia odpoveď zavrie modal).
// M3 „poradie stromu preskladané na klientovi" zabije test v bloku 2.

console.log('OK test_s1a2_sekcia.js — ' + n + ' kontrol');
