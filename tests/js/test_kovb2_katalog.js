// KOV-B2 — KATALÓG KOVANIA: serverový strom + modal položky (D-15) + Démos.
//
// Preco su to testy a nie klikanie:
//   1. „JS poradie NIKDY nedopĺňa" sa da rozbit jednym `sort()` — a rozbije sa
//      TICHO: zoznam vyzera spravne, len uz nezodpoveda tomu, co server posiela
//      inym volajucim (a KOV-D by na tom postavil filtre).
//   2. „Ziadne tiche stropy": ked klient ignoruje `more`, polozka za poradim 50
//      z UI zmizne BEZ SLOVA — presne to zhorelo pri prvom teste v0.8.0.
//   3. Modal D-15 sa pri ODMIETNUTOM zapise NESMIE zatvorit a zamok odoslania
//      odomyka VOLAJUCI. Keby to niekto obratil, pouzivatel by prisiel
//      o rozpisanu polozku alebo by ostal navzdy so zosednutym tlacidlom.
//   4. Rucne zmeneny udaj z Demosu NIE JE „overeny". Keby islo dalej cestou
//      `hw_demos_create`, polozka by dostala vazbu a datum overenia k cene,
//      ktoru nikto neoveril — a to je CENOVA chyba v ostrej objednavke.
//   5. Rada patri presne jednemu vyrobcovi: zavisly select sa nesmie dat obist.
//
// MUTACIE OVERENE (kazda zhodila aspon jeden assert tejto sady):
//   1. klient si strom TRIEDI sam (`groups.sort`) -> blok 1 „poradie je presne serverove";
//   2. „Načítať ďalšie" neposiela `more` -> blok 2 „dalsia stranka listu";
//   3. `hwDemosDirty` vzdy `false` (prepisana cena ide `hw_demos_create`)
//      -> blok 6 „prepisana cena = RUCNA polozka";
//   4. `hwItemSerOptions` ignoruje vyrobcu (ponuka vsetky rady)
//      -> blok 4 „rada je ZAVISLA od vyrobcu".
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch, textOf } = require(path.join(__dirname, 'minidom.js'));
const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

// --- prostredie sekcie -------------------------------------------------------
function addEl(tag, id){
  const e = mkEl(tag);
  e.attrs.id = id;
  DOC.body.appendChild(e);
  return e;
}
const MODAL_ROOT = addEl('div', 'nxModalRoot');
const LIST = addEl('div', 'hwList');
addEl('div', 'sectools');
addEl('div', 'secbody');
addEl('div', 'status');
addEl('div', 'hwline');

const SENT = [];
global.sketchup = new Proxy({}, {
  get(_t, name){
    if (typeof name !== 'string') return undefined;
    return function(payload){ SENT.push([name, JSON.parse(payload || '{}')]); };
  },
  has(){ return true; }
});
global.window.sketchup = global.sketchup;
global.window.NX_HW_SECTION = true;

global.NXModal = require(path.join(JS, 'nx_modal.js'));
global.window.NXModal = global.NXModal;
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const H = require(path.join(JS, 'hw_catalog.js'));

// Debounce naseptavaca aj nahladu bezi na `setTimeout` — sada ho nahradzuje,
// aby sa dala prejst REALNA cesta „napis URL -> fetch -> odpoved", nie len
// vstreknuty vysledok. Bez nej by test obisiel prave tie guardy, ktore strazi.
const TIMERS = [];
global.setTimeout = function(fn){ TIMERS.push(fn); return TIMERS.length; };
global.clearTimeout = function(id){ if (id) TIMERS[id - 1] = null; };
function flushTimers(){
  const list = TIMERS.slice();
  TIMERS.length = 0;
  list.forEach(function(f){ if (typeof f === 'function') f(); });
}

function sent(name){ return SENT.filter(function(x){ return x[0] === name; }); }
function last(name){ const l = sent(name); return l.length ? l[l.length - 1][1] : null; }
// Token POSLEDNÉHO odoslania danej akcie — server ho echuje v `itemResult`
// a klient prijme LEN zhodu (review #290 P2).
function tok(name){ const p = last(name); return p ? p.token : ''; }
function q(sel){ return DOC.querySelector(sel); }
// Napise do pola Démos hodnotu TAK, ako to robi pouzivatel (kostra `lookup`
// -> `hwDemosSearch` -> debounce -> `hw_demos_preview`).
function demosType(text){
  const qn = q('[data-nxm-lkq="demos"]');
  qn.value = text;
  dispatch(qn, 'input');
  flushTimers();
  return qn;
}
function qa(sel){ return DOC.querySelectorAll(sel); }

const CATS = ['ZAVESY', 'VYSUVY', 'NOHY'];
const LABELS = { ZAVESY: 'Závesy', VYSUVY: 'Výsuvy', NOHY: 'Nohy a montáž' };
const TAX = {
  manufacturers: ['Blum', 'Hettich'],
  series: [{ name: 'Sensys', manufacturer: 'Hettich' },
           { name: 'InnoTech Atira', manufacturer: 'Hettich' },
           { name: 'TIP-ON', manufacturer: 'Blum' }],
  read_only: false, state_reason: ''
};
const ITEMS = [
  { item_code: '104717', name_sk: 'Sensys 8645i', category: 'ZAVESY', unit: 'ks',
    price_eur_vat: 4.18, manufacturer: 'Hettich', series: 'Sensys', row_rev: 'r1' },
  { item_code: '250831', name_sk: 'TipOn 76 mm', category: 'ZAVESY', unit: 'ks',
    manufacturer: 'Blum', series: 'TIP-ON', row_rev: 'r2' },
  { item_code: '82744', name_sk: 'Klzák 17 mm', category: 'NOHY', unit: 'ks',
    price_eur_vat: 0.48, row_rev: 'r3' }
];

function boot(){
  SENT.length = 0;
  H.MDH.init({ items: ITEMS, state: 'ok', state_reason: '', revision: 'rev1',
               version: '0.9.23', categories: CATS, category_labels: LABELS,
               units: ['ks', 'set', 'par', 'bal', 'm'], taxonomy: TAX });
}

// Odpoved servera pre `hw_tree` — presne v tvare, aky posiela `build_tree`.
function treeResp(over){
  const base = {
    q: '', gen: null, leaf_page: 50, pin: null, total: 3, shown: 3,
    groups: [
      { key: 'ZAVESY', label: 'Závesy', open: true, total: 2, shown: 2,
        manufacturers: [
          { key: 'ZAVESY|Blum', label: 'Blum', total: 1, shown: 1,
            series: [{ key: 'ZAVESY|Blum|TIP-ON', label: 'TIP-ON', total: 1, shown: 1,
                       codes: ['250831'], more: false }] },
          { key: 'ZAVESY|Hettich', label: 'Hettich', total: 1, shown: 1,
            series: [{ key: 'ZAVESY|Hettich|Sensys', label: 'Sensys', total: 1, shown: 1,
                       codes: ['104717'], more: false }] }
        ] },
      { key: 'NOHY', label: 'Nohy a montáž', open: false, total: 1, shown: 0,
        manufacturers: [
          { key: 'NOHY|', label: '— bez výrobcu', total: 1, shown: 0,
            series: [{ key: 'NOHY||', label: '— bez rady', total: 1, shown: 0,
                       codes: [], more: false }] }
        ] }
    ]
  };
  return Object.assign(base, over || {});
}

// ===================== 1) STROM: render presne toho, co prislo ===============

(function(){
  boot();
  ok(sent('hw_tree').length > 0,
     'sekcia si po naplneni katalogu vypyta STROM (ploche hladanie uz nie)');
  const req = last('hw_tree');
  ok(Object.prototype.hasOwnProperty.call(req, 'expand') &&
     Object.prototype.hasOwnProperty.call(req, 'more'),
     'dotaz nesie rozbalenie aj stránkovanie — obsah rozhoduje server');

  H.MDH.tree(treeResp({ gen: last('hw_tree').gen }));
  const heads = qa('[data-action="hw-grp"]');
  eq(heads.length, 2, 'kazda kategoria ma hlavicku');
  eq(heads.map(function(h){ return h.getAttribute('data-hw-grp'); }), ['ZAVESY', 'NOHY'],
     'poradie je presne serverove (JS netriedi ani nedopĺňa)');
  ok(textOf(heads[0]).indexOf('Závesy') > -1, 'hlavicka ukazuje SK popisok, nie kod');
  ok(textOf(heads[1]).indexOf('Nohy a montáž') > -1, 'aj druha');

  const subs = qa('.hwsub');
  eq(subs.map(textOf), ['Blum · TIP-ON', 'Hettich · Sensys'],
     'pod hlavickou su podnadpisy „Výrobca · Rada" v serverovom poradí');
  const rows = qa('[data-hw-row]');
  eq(rows.map(function(r){ return r.getAttribute('data-hw-row'); }), ['250831', '104717'],
     'riadky su v poradi kodov, ktore poslal server');

  // ZBALENA kategoria = JEDEN riadok (vertikalny priestor je vzacny).
  const nohy = heads[1].parent;
  eq(nohy.querySelectorAll('[data-hw-row]').length, 0,
     'zbalena kategoria nekresli ani jeden riadok');
  ok(textOf(heads[1]).indexOf('1 položka') > -1,
     'ale POCET vidno — inak by hlavicka mlcala o tom, co v nej je');
})();

// ===================== 2) ZIADNE TICHE STROPY ================================

(function(){
  boot();
  const gen = last('hw_tree').gen;
  const big = treeResp({ gen: gen });
  big.groups[0].manufacturers[1].series[0] =
    { key: 'ZAVESY|Hettich|Sensys', label: 'Sensys', total: 520, shown: 50,
      codes: ['104717'], more: true };
  H.MDH.tree(big);
  const more = q('[data-action="hw-more"]');
  ok(!!more, 'orezany list PONUKNE „Načítať ďalšie" (zasada „no silent caps")');
  ok(textOf(more).indexOf('470') > -1, 'a povie, kolko ich este je (520 - 50)');

  SENT.length = 0;
  dispatch(more, 'click');
  const req = last('hw_tree');
  ok(req, 'klik si vypyta novy strom');
  eq(req.more['ZAVESY|Hettich|Sensys'], 100,
     'a poziada o DALSIU stranku LISTU (nasobok LEAF_PAGE) — nie o cely katalog');
  ok(textOf(q('.hwgrpbody')).indexOf('Sensys') > -1, 'strom sa medzitym nezhodil');
})();

// ===================== 3) ROZBALENIE + generacia =============================

(function(){
  boot();
  H.MDH.tree(treeResp({ gen: last('hw_tree').gen }));
  SENT.length = 0;
  const nohyHead = qa('[data-action="hw-grp"]')[1];
  dispatch(nohyHead, 'click');
  eq(last('hw_tree').expand.NOHY, true,
     'klik na hlavicku posle ROZBALENIE serveru — obsah si klient nedokresluje');
  dispatch(nohyHead, 'click');
  ok(!last('hw_tree').expand.NOHY, 'druhy klik ho zase zbali');

  // Server rozbaluje aj SAM (pin, hladanie). Pri PRAZDNOM dotaze si to klient
  // zapamata; pri hladani NIE — inak by jedno hladanie roztvorilo katalog
  // natrvalo.
  SENT.length = 0;
  H.MDH.tree(treeResp({ gen: last('hw_tree') ? last('hw_tree').gen : null, q: '' }));
  const st = H.hwTreeState();
  eq(st.expand.ZAVESY, true, 'pri prazdnom dotaze sa serverove rozbalenie zapamata');
  H.MDH.tree(treeResp({ gen: st.gen, q: 'tipon' }));
  ok(!H.hwTreeState().expand.NOHY,
     'pri hladani sa rozbalenie NEZAPAMATA (hladanie roztvara len docasne)');

  // STARSIA odpoved sa zahadzuje.
  const cur = H.hwTreeState().gen;
  const stale = treeResp({ gen: cur - 1 });
  stale.groups = [];
  H.MDH.tree(stale);
  ok(qa('[data-action="hw-grp"]').length > 0,
     'odpoved so STAROU generaciou strom neprepise (inak by blikal spatky)');
})();

// ===================== 4) MODAL: polia, poradie, zavisly select ==============

(function(){
  boot();
  const f = H.hwItemFields({}, {});
  eq(f.map(function(x){ return x.key; }),
     ['demos', 'code', 'name', 'price', 'unit', 'category', 'manufacturer', 'series', 'notes'],
     'poradie poli je poradie dodavatelskeho listu (mockup scena 3)');
  eq(f[0].type, 'lookup', 'Démos je nasepkavac nad SERVEROVYM hladanim');
  eq(f[5].options.map(function(o){ return o[1]; }), ['Závesy', 'Výsuvy', 'Nohy a montáž'],
     'kategorie sa ponukaju SK popiskom, hodnota ostava kodom');
  eq(f[5].options.map(function(o){ return o[0]; }), CATS, 'hodnota je kod');

  // UPRAVA: kod je IDENTITA — nesmie sa dat prepisat.
  const e = H.hwItemFields(H.hwItemDraftOf(ITEMS[0]), { edit: true });
  ok(!e.some(function(x){ return x.key === 'code'; }),
     'pri uprave sa kod needituje (server ho v PATCHABLE nema)');
  ok(!e.some(function(x){ return x.key === 'demos'; }),
     'ani Démos — proposal zaklada NOVU polozku');

  // MUTACIA 4: rada je ZAVISLA od vyrobcu (rada patri presne jednemu).
  const bez = H.hwItemSerOptions('');
  eq(bez.map(function(o){ return o[0]; }), [''],
     'bez vyrobcu sa rada vybrat NEDA — ani „+ Vytvoriť"');
  const het = H.hwItemSerOptions('Hettich').map(function(o){ return o[0]; });
  eq(het, ['', 'Sensys', 'InnoTech Atira', '__new__'],
     'ponukaju sa LEN rady toho vyrobcu (+ moznost zalozit novu)');
  ok(het.indexOf('TIP-ON') < 0, 'cudzia rada sa neponuka (server by ju aj tak odmietol)');

  const mans = H.hwItemManOptions().map(function(o){ return o[0]; });
  eq(mans, ['', 'Blum', 'Hettich', '__new__'], 'vyrobcovia + „+ Vytvoriť" ako POSLEDNA volba');

  // Validacia: klient strazi LEN povinne polia (autorita je server).
  eq(H.hwItemValidate({ code: '', name: '' }, {}).map(function(x){ return x.field; }),
     ['code', 'name'], 'kod aj nazov su povinne');
  eq(H.hwItemValidate({ code: 'X', name: 'Y' }, {}), [], 'vyplnene prejde');
  eq(H.hwItemValidate({ name: 'Y' }, { edit: true }), [],
     'pri uprave sa kod nepyta (nie je v poliach)');
})();

// ===================== 5) MODAL: zapis, chyby, busy lock ====================

(function(){
  boot();
  H.MDH.tree(treeResp({ gen: last('hw_tree').gen }));
  SENT.length = 0;
  dispatch(q('#hwNewBtn') || DOC.body, 'click');   // lista sa v tomto teste nekresli
  H.hwItemOpen(null, null, {});
  ok(global.NXModal.isOpen(), 'tlacidlo „Nová položka" otvara MODAL, nie formular v tele');
  ok(!DOC.getElementById('hwNewForm'), 'staticky formular v tele uz neexistuje (D-110)');

  DOC.getElementById('nxm_code').value = '999111';
  DOC.getElementById('nxm_name').value = 'Skrutka';
  DOC.getElementById('nxm_category').value = 'NOHY';
  DOC.getElementById('nxm_unit').value = 'ks';
  global.NXModal.submit();
  ok(global.NXModal.isBusy(), 'prve odoslanie ZAMKNE tlacidlo (dvojity Enter = dve polozky)');
  const created = last('hw_create');
  eq(created.fields.item_code, '999111', 'na server ide kod z modalu');
  eq(created.fields.category, 'NOHY', 'aj kategoria');
  ok(global.NXModal.isOpen(), 'submit modal NEZATVARA — zatvara az potvrdenie servera');

  // ODMIETNUTIE: modal ostava otvoreny, chyba sadne PRI POLI, zamok sa pusti.
  H.MDH.itemResult(false, 'Kód 999111 už v katalógu je.',
                   [{ field: 'code', msg: 'Kód 999111 už v katalógu je.' }], 'create',
                   tok('hw_create'));
  ok(global.NXModal.isOpen(), 'odmietnuty zapis necha rozpisane hodnoty na mieste');
  ok(!global.NXModal.isBusy(), 'a ODOMKNE tlacidlo (inak by okno ostalo mrtve)');
  eq(DOC.getElementById('nxm_code').value, '999111', 'hodnoty sa nestratili');
  const errRow = q('[data-nxm-lkrow], .mrow');
  ok(textOf(MODAL_ROOT).indexOf('už v katalógu je') > -1, 'hlaska je v karte');
  ok(!!q('.bad'), 'a pole je oznacene ako chybne');
  ok(!!errRow, 'karta ma riadky');

  // Odpoved, na ktoru sa NECAKA, sa zahadzuje — inak by inline oprava bunky
  // v riadku zatvorila rozpisany modal.
  H.MDH.itemResult(true, 'Uložené.', [], 'patch', 'iny-token');
  ok(global.NXModal.isOpen(),
     'signal bez cakania (napr. patch z bunky) modal NEZATVARA');

  // POTVRDENIE vlastneho odoslania: modal sa zatvara.
  DOC.getElementById('nxm_code').value = '999112';
  global.NXModal.submit();
  ok(global.NXModal.isBusy(), 'druhe odoslanie zase zamklo');
  H.MDH.itemResult(true, 'Položka 999112 pridaná.', [], 'create', tok('hw_create'));
  ok(!global.NXModal.isOpen(), 'potvrdeny zapis modal ZATVORI');
})();

// ===================== 6) DÉMOS: predvyplnenie a ručná položka ==============

const PROP = { ok: true, pid: 'p1', url: 'https://www.demos-trade.sk/k-atira/',
               code: '357695', name_sk: 'K-InnoTech Atira 470', unit: 'set',
               price_vat: 18.9, category_guess: 'VYSUVY',
               manufacturer_guess: 'Hettich', exists: false,
               related: [{ code: '294940', name: 'čelo' }] };

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  // Pouzivatel napise poznamku, potom nacita produkt z Demosu.
  DOC.getElementById('nxm_notes').value = 'moja poznamka';
  demosType(PROP.url);
  ok(!!last('hw_demos_preview'), 'vlozena URL spustila SERVEROVY nahlad');
  H.MDH.demosPreview(PROP);
  ok(global.NXModal.isOpen(), 'nahlad modal nezatvara — prekresli ho');
  eq(DOC.getElementById('nxm_code').value, '357695', 'kod je z proposalu');
  eq(DOC.getElementById('nxm_name').value, 'K-InnoTech Atira 470', 'nazov tiez');
  eq(DOC.getElementById('nxm_price').value, '18.9', 'aj cena');
  eq(DOC.getElementById('nxm_unit').value, 'set', 'aj MJ');
  eq(DOC.getElementById('nxm_category').value, 'VYSUVY', 'kategoria je SERVEROVY navrh');
  eq(DOC.getElementById('nxm_manufacturer').value, 'Hettich',
     'vyrobca je navrh z TAXONOMIE (znacka stranky -> kanonicke meno)');
  eq(DOC.getElementById('nxm_series').value, '',
     'radu NEHADAME nikdy (inferencia z breadcrumbu je mimo tejto davky)');
  eq(DOC.getElementById('nxm_notes').value, 'moja poznamka',
     'a rozpisana poznamka sa NESTRATILA');
  ok(textOf(MODAL_ROOT).indexOf('bez väzby na Démos') > -1,
     'modal VETOU povie, co sa stane pri rucnej zmene');

  // NEDOTKNUTY proposal = zapis z Demosu (server dopĺňa vazbu a datum).
  SENT.length = 0;
  global.NXModal.submit();
  const dc = last('hw_demos_create');
  ok(dc, 'nedotknuty proposal ide cestou `hw_demos_create`');
  eq(dc.pid, 'p1', 'a nesie LEN pid');
  eq(dc.manufacturer, 'Hettich', 'plus vyrobcu, ktoreho proposal nema');
  ok(!Object.prototype.hasOwnProperty.call(dc, 'price_eur_vat'),
     'cena z klienta NEODCHADZA (FIX 12 z KOV-H1)');
  H.MDH.itemResult(true, 'ok', [], 'create', tok('hw_demos_create'));
})();

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  demosType(PROP.url);
  H.MDH.demosPreview(PROP);
  // MUTACIA 3: pouzivatel PREPISE cenu -> uz to nie je overena polozka.
  DOC.getElementById('nxm_price').value = '15,00';
  SENT.length = 0;
  global.NXModal.submit();
  ok(!last('hw_demos_create'), 'prepisana cena UZ NEIDE cestou z Demosu');
  const c = last('hw_create');
  ok(c, 'ide beznou cestou — polozka je RUCNA');
  eq(c.fields.price_eur_vat, '15,00', 'a plati rucna cena');
  ok(!Object.prototype.hasOwnProperty.call(c.fields, 'demos_url'),
     'bez vazby na Demos (server ju pri `create_item` aj tak zahadzuje)');

  // Cista funkcia — porovnanie je odolne voci ciarke aj poctu desatin.
  eq(H.hwDemosDirty(PROP, { code: '357695', name: 'K-InnoTech Atira 470',
                            unit: 'set', price: '18,90' }), false,
     '„18,90" a 18.9 je TA ISTA cena — polozka o vazbu neprichadza kvoli formatu');
  eq(H.hwDemosDirty(PROP, { code: '357695', name: 'K-InnoTech Atira 470',
                            unit: 'set', price: '15' }), true, 'ina cena = rucna');
  eq(H.hwDemosDirty(PROP, { code: 'INY', name: 'K-InnoTech Atira 470',
                            unit: 'set', price: '18.9' }), true, 'iny kod = rucna');
  eq(H.hwDemosDirty(null, { code: 'X' }), true, 'bez proposalu je vzdy rucna');
})();

// ===================== 7) „+ Vytvoriť výrobcu/radu…" ========================

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  DOC.getElementById('nxm_name').value = 'Rozpisana polozka';
  const man = DOC.getElementById('nxm_manufacturer');
  man.value = '__new__';
  SENT.length = 0;
  dispatch(man, 'change');
  ok(!!DOC.getElementById('nxm_manufacturer_new'),
     'volba „+ Vytvoriť výrobcu…" prida POLE na nazov (nic mimo kostry D-15)');
  eq(DOC.getElementById('nxm_name').value, 'Rozpisana polozka',
     'a rozpisane hodnoty prezili prekreslenie modalu');
  ok(!sent('hw_tax_create_manufacturer').length,
     'samotna volba este NIC nezaklada');

  DOC.getElementById('nxm_manufacturer_new').value = 'Grass';
  // Review #290 P1: zapis spusta VYHRADNE tlacidlo pri poli (alebo Enter).
  dispatch(q('[data-action="hw-tax-create"][data-nxm-for="manufacturer"]'), 'click');
  const req = last('hw_tax_create_manufacturer');
  ok(req, 'potvrdenie zaklada vyrobcu v TAXONOMII');
  eq(req.name, 'Grass', 'a posiela jeho nazov');
  ok(!last('hw_create'), 'polozka sa pritom NEUKLADA (dve veci naraz = tichy zapis)');

  // Server vratil CERSTVU taxonomiu + kanonicke meno.
  H.MDH.taxonomy({ ok: true, op: 'manufacturer', name: 'Grass', errors: [],
                   token: tok('hw_tax_create_manufacturer'),
                   taxonomy: { manufacturers: ['Blum', 'Grass', 'Hettich'],
                               series: TAX.series, read_only: false, state_reason: '' } });
  ok(global.NXModal.isOpen(), 'modal ostava otvoreny');
  ok(!global.NXModal.isBusy(), 'a zamok odoslania je pusteny');
  eq(DOC.getElementById('nxm_manufacturer').value, 'Grass',
     'novy vyrobca je rovno VYBRANY (kanonicke meno zo servera)');
  ok(!DOC.getElementById('nxm_manufacturer_new'), 'pole na nazov zmizlo');
  eq(DOC.getElementById('nxm_name').value, 'Rozpisana polozka', 'a polozka sa nestratila');

  // ODMIETNUTIE zapisu do taxonomie sadne PRI POLI.
  DOC.getElementById('nxm_manufacturer').value = '__new__';
  dispatch(DOC.getElementById('nxm_manufacturer'), 'change');
  DOC.getElementById('nxm_manufacturer_new').value = 'x';
  dispatch(q('[data-action="hw-tax-create"][data-nxm-for="manufacturer"]'), 'click');
  H.MDH.taxonomy({ ok: false, op: 'manufacturer', name: '',
                   token: tok('hw_tax_create_manufacturer'),
                   errors: [{ field: 'manufacturer', msg: 'názov musí obsahovať písmeno' }],
                   taxonomy: TAX });
  ok(textOf(MODAL_ROOT).indexOf('musí obsahovať písmeno') > -1,
     'chyba servera je v karte');
  ok(!global.NXModal.isBusy(), 'a tlacidlo je odomknute');
  global.NXModal.close();
})();

// ===================== 8) zavisly select po zmene vyrobcu ===================

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  DOC.getElementById('nxm_manufacturer').value = 'Hettich';
  dispatch(DOC.getElementById('nxm_manufacturer'), 'change');
  DOC.getElementById('nxm_series').value = 'Sensys';
  dispatch(DOC.getElementById('nxm_series'), 'change');
  eq(DOC.getElementById('nxm_series').value, 'Sensys', 'rada sa vybrala');

  DOC.getElementById('nxm_manufacturer').value = 'Blum';
  dispatch(DOC.getElementById('nxm_manufacturer'), 'change');
  eq(DOC.getElementById('nxm_series').value, '',
     'zmena vyrobcu ZAHODI radu, ktora mu nepatri (server by ju odmietol)');
  const opts = qa('#nxm_series option').map(function(o){ return o.getAttribute('value'); });
  eq(opts, ['', 'TIP-ON', '__new__'], 'a ponuka sa zuzi na rady noveho vyrobcu');
  global.NXModal.close();
})();

// ===================== 9) ÚPRAVA: len zmenené polia + row_rev ================

(function(){
  boot();
  // Cista funkcia: patch nesie LEN to, co sa naozaj zmenilo. Posielat vsetko by
  // pri kazdom ulozeni zmazalo `price_checked_at` (server F5).
  const base = H.hwItemDraftOf(ITEMS[0]);
  eq(H.hwItemPatch(base, base), {}, 'bez zmeny nie je co patchovat');
  eq(H.hwItemPatch(base, Object.assign({}, base, { notes: 'nova' })), { notes: 'nova' },
     'patchuje sa LEN zmenene pole');
  eq(H.hwItemPatch(base, Object.assign({}, base, { price: '4,18' })), {},
     '„4,18" a 4.18 je ta ista cena — datum overenia sa zbytocne nezahadzuje');
  eq(H.hwItemPatch(base, Object.assign({}, base, { price: '5' })),
     { price_eur_vat: '5' }, 'skutocna zmena ceny sa posle');

  H.hwItemOpen(ITEMS[0], null, {});
  ok(textOf(MODAL_ROOT).indexOf('104717') > -1, 'kod je v podtitule (je to identita)');
  ok(!DOC.getElementById('nxm_code'), 'a NIE v poli, ktore by sa dalo prepisat');
  DOC.getElementById('nxm_notes').value = 'upravena poznamka';
  SENT.length = 0;
  global.NXModal.submit();
  const p = last('hw_patch');
  ok(p, 'uprava ide patchom');
  eq(p.code, '104717', 'identita ide zo stavu, nie z pola');
  eq(p.row_rev, 'r1', 'a revizia riadku ide SKRYTO (optimisticky zamok)');
  eq(p.from, 'modal', 'server vie, ze odpoved patri modalu (nie inline bunke)');
  eq(p.patch, { notes: 'upravena poznamka' }, 'patch nesie LEN zmenu');

  // Konflikt = hlaska + obnova, modal ostava otvoreny.
  H.MDH.itemResult(false, 'Položka sa medzitým zmenila — hodnoty sa obnovili, uprav znova.',
                   [{ msg: 'Položka sa medzitým zmenila — hodnoty sa obnovili, uprav znova.' }],
                   'patch', tok('hw_patch'));
  ok(global.NXModal.isOpen(), 'konflikt modal nezatvara');
  ok(textOf(MODAL_ROOT).indexOf('medzitým zmenila') > -1, 'a povie preco');
  global.NXModal.close();
})();

// ===================== 10) rozpísaná bunka a otvorený detail prežijú =========

(function(){
  boot();
  H.MDH.tree(treeResp({ gen: last('hw_tree').gen }));
  // Pouzivatel rozklikne detail a zacne prepisovat nazov v riadku.
  const toggle = q('[data-action="hw-toggle"][data-hw-code="250831"]');
  ok(!!toggle, 'riadok ma rozklik detailu');
  dispatch(toggle, 'click');
  ok(!!q('.hwdetail'), 'detail sa otvoril');

  const cell = q('.mdcell[data-hw-code="250831"][data-hw-field="name_sk"]');
  cell.value = 'Rozpisany novy nazov';
  DOC.activeElement = cell;
  cell.selectionStart = 5;
  cell.selectionEnd = 5;

  // Prisiel novy strom (napr. po prepocte kusovnika).
  H.MDH.tree(treeResp({ gen: H.hwTreeState().gen }));
  const after = q('.mdcell[data-hw-code="250831"][data-hw-field="name_sk"]');
  eq(after.value, 'Rozpisany novy nazov',
     'rozpisana bunka PREZILA prekreslenie stromu (inak by sa pisalo odznova)');
  eq(after.getAttribute('data-orig'), 'TipOn 76 mm',
     'a baseline ostal POVODNY — cudzia zmena skonci konfliktom, nie tichym prepisom');
  ok(!!q('.hwdetail'), 'a otvoreny detail tiez prezil');
  DOC.activeElement = null;
})();

// ===================== 11) prázdny výsledok = jeden riadok hlášky ============

(function(){
  boot();
  H.MDH.tree(treeResp({ gen: last('hw_tree').gen, groups: [], total: 0, shown: 0, q: 'xyz' }));
  eq(qa('[data-action="hw-grp"]').length, 0, 'ziadne skupiny');
  ok(textOf(LIST).indexOf('Žiadne položky') > -1,
     'prazdny vysledok je JEDEN riadok hlasky, nie prazdna plocha');
})();

// ============ 12) review #290 P1: „Zrušiť" NESMIE nič zapísať ================
// Klik na „Zrušiť" vyvolá NAJPRV blur textového poľa (`change`) a až potom
// svoj vlastný klik. Keby zápis do taxonómie visel na `change`, zrušený
// formulár by založil výrobcu, ktorého už nikto nezmaže: globálny súbor,
// žiadny krok Späť, žiadny rename ani delete.

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  const man = DOC.getElementById('nxm_manufacturer');
  man.value = '__new__';
  dispatch(man, 'change');
  const nameField = DOC.getElementById('nxm_manufacturer_new');
  ok(!!nameField, 'pole na názov nového výrobcu je vykreslené');
  ok(!!q('[data-action="hw-tax-create"][data-nxm-for="manufacturer"]'),
     'a PRI ŇOM je explicitné tlačidlo „Vytvoriť" (jediný klikací spúšťač)');

  SENT.length = 0;
  nameField.value = 'Nechcem to uložiť';
  dispatch(nameField, 'change');          // blur, ktorý predchádza kliku na Zrušiť
  eq(sent('hw_tax_create_manufacturer').length, 0,
     'blur poľa NEZAPISUJE do taxonómie (review #290 P1)');
  dispatch(q('[data-nxm-act="close"]'), 'click');   // „Zrušiť" (krížik/pätka)
  eq(sent('hw_tax_create_manufacturer').length, 0,
     'ani po zrušení formulára — zápis bez cesty späť sa nesmie stať omylom');
  ok(!global.NXModal.isOpen(), 'modal sa zavrel');

  // To isté pre RADU.
  boot();
  H.hwItemOpen(null, null, {});
  const m2 = DOC.getElementById('nxm_manufacturer');
  m2.value = 'Hettich';
  dispatch(m2, 'change');
  const ser = DOC.getElementById('nxm_series');
  ser.value = '__new__';
  dispatch(ser, 'change');
  const serField = DOC.getElementById('nxm_series_new');
  ok(!!serField, 'aj rada má pole na názov');
  SENT.length = 0;
  serField.value = 'Zrušená rada';
  dispatch(serField, 'change');
  eq(sent('hw_tax_create_series').length, 0, 'blur ani pri rade nič nezakladá');
  // A explicitné tlačidlo zapíše.
  dispatch(q('[data-action="hw-tax-create"][data-nxm-for="series"]'), 'click');
  eq(last('hw_tax_create_series').name, 'Zrušená rada',
     'tlačidlo „Vytvoriť" zápis SPUSTÍ (a pošle výrobcu)');
  eq(last('hw_tax_create_series').manufacturer, 'Hettich', 'rada ide pod svojho výrobcu');
  global.NXModal.close();
})();

// ====== 13) review #290 P2: token koreluje odpoveď s KONKRÉTNYM odoslaním ====

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  DOC.getElementById('nxm_code').value = 'A1';
  DOC.getElementById('nxm_name').value = 'Okno A';
  global.NXModal.submit();
  const tokenA = tok('hw_create');
  ok(!!tokenA, 'odoslanie nesie vlastnú identitu (token)');
  global.NXModal.close();                       // A sa zavrelo, zápis ešte beží

  H.hwItemOpen(null, null, {});                 // okno B
  DOC.getElementById('nxm_code').value = 'B1';
  DOC.getElementById('nxm_name').value = 'Okno B';
  global.NXModal.submit();
  const tokenB = tok('hw_create');
  ok(tokenB !== tokenA, 'druhé odoslanie má INÝ token');

  H.MDH.itemResult(true, 'Položka A1 pridaná.', [], 'create', tokenA);
  ok(global.NXModal.isOpen(),
     'odpoveď patriaca ZAVRETÉMU oknu nezavrie to, ktoré je otvorené teraz');
  ok(global.NXModal.isBusy(), 'a zámok odoslania B ostáva — B stále čaká');
  eq(DOC.getElementById('nxm_code').value, 'B1', 'koncept B sa nezahodil');

  H.MDH.itemResult(true, 'Položka B1 pridaná.', [], 'create', tokenB);
  ok(!global.NXModal.isOpen(), 'vlastná odpoveď B okno zavrie');
})();

// ====== 14) review #290 P2: konflikt úpravy prevezme ČERSTVÚ revíziu ========

(function(){
  boot();
  const item = ITEMS[0];
  H.hwItemOpen(item, null, {});
  DOC.getElementById('nxm_notes').value = 'moja zmena';
  global.NXModal.submit();
  eq(last('hw_patch').row_rev, 'r1', 'prvé uloženie posiela revíziu z času otvorenia');
  const t1 = tok('hw_patch');

  // Server medzitým pushol ČERSTVÝ katalóg (iná revízia + iné hodnoty) a až
  // potom prišla odpoveď o konflikte — presne to poradie robí `handle_patch`.
  H.MDH.setItems({ items: [{ item_code: '104717', name_sk: 'Sensys 8645i NOVÝ',
                             category: 'ZAVESY', unit: 'ks', price_eur_vat: 4.5,
                             manufacturer: 'Hettich', series: 'Sensys', row_rev: 'r9' },
                           ITEMS[1], ITEMS[2]],
                   state: 'ok' });
  H.MDH.itemResult(false, 'Položka sa medzitým zmenila — hodnoty sa obnovili, uprav znova.',
                   [{ msg: 'Položka sa medzitým zmenila — hodnoty sa obnovili, uprav znova.' }],
                   'patch', t1);
  ok(global.NXModal.isOpen(), 'konflikt modal NEZATVÁRA');
  ok(textOf(MODAL_ROOT).indexOf('medzitým zmenila') > -1, 'a povie prečo');
  eq(DOC.getElementById('nxm_name').value, 'Sensys 8645i NOVÝ',
     'hodnoty v poliach sú SERVEROVÉ (hláška „obnovili sa" hovorí pravdu)');

  DOC.getElementById('nxm_notes').value = 'druhý pokus';
  global.NXModal.submit();
  eq(last('hw_patch').row_rev, 'r9',
     'druhé uloženie posiela ČERSTVÚ revíziu — inak by konflikt trval donekonečna');
  ok(tok('hw_patch') !== t1, 'a má vlastný token');
  global.NXModal.close();
})();

// ====== 15) review #290 P2: rozbehnutý náhľad po zmene vstupu ================

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  demosType(PROP.url);
  ok(!!last('hw_demos_preview'), 'náhľad odišiel');

  // Používateľ pole PREPÍŠE skôr, než odpoveď dorazí — a to na text, ktorý
  // ŽIADNY nový náhľad nespustí (server teda svoju generáciu nezdvihne
  // a stará odpoveď by prešla). Zachytiť to musí KLIENT.
  SENT.length = 0;
  demosType('ab');
  eq(sent('hw_demos_preview').length, 0, 'krátky text nový náhľad nespúšťa');
  eq(sent('hw_demos_cancel').length, 1,
     'odchod od adresy bežiaci náhľad na serveri ZRUŠÍ');
  H.MDH.demosPreview(PROP);          // dobiehajúca odpoveď na STARÝ dotaz
  eq(DOC.getElementById('nxm_code').value, '',
     'stará odpoveď NEPREPÍŠE polia (inak by tam bol produkt, od ktorého odišiel)');

  // Vymazanie poľa už nemá čo rušiť — a druhýkrát to serveru neposiela.
  SENT.length = 0;
  demosType('');
  eq(sent('hw_demos_cancel').length, 0, 'zrušenie sa neposiela dvakrát');
  global.NXModal.close();
})();

// ====== 16) review #290 P2: spúšťač prežije interné prekreslenia ============

(function(){
  boot();
  const opener = mkEl('button');
  opener.attrs.id = 'hwNewBtnTest';
  DOC.body.appendChild(opener);
  opener.focus();
  eq(DOC.activeElement, opener, 'fokus je na tlačidle, ktoré okno otvára');

  H.hwItemOpen(null, null, {});
  demosType(PROP.url);
  H.MDH.demosPreview(PROP);                    // prekreslenie #1 (predvyplnenie)
  const man = DOC.getElementById('nxm_manufacturer');
  man.value = 'Blum';
  dispatch(man, 'change');                     // prekreslenie #2 (závislý select)
  ok(global.NXModal.isOpen(), 'modal po dvoch prekresleniach žije');

  global.NXModal.close();
  eq(DOC.activeElement, opener,
     'po zatvorení sa fokus vrátil na PÔVODNÝ spúšťač — nie na pole, ktoré prekreslením zaniklo');
  opener.remove();
})();

// ====== 17) review #290 P2: proposal z Démosu prežije zatvorenie ============

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  demosType(PROP.url);
  H.MDH.demosPreview(PROP);
  eq(DOC.getElementById('nxm_code').value, '357695', 'náhľad predvyplnil formulár');

  global.NXModal.close();                      // Escape / scrim / „Zrušiť"
  SENT.length = 0;
  H.hwItemOpen(null, null, {});                // „Nová položka" znova
  eq(DOC.getElementById('nxm_code').value, '357695',
     'vyhľadaný produkt sa NESTRATIL — lookup sa nemusí robiť odznova');
  eq(DOC.getElementById('nxm_manufacturer').value, 'Hettich', 'aj návrh výrobcu');

  // Po ÚSPEŠNOM zápise proposal zaniká — ďalšia položka začína načisto.
  global.NXModal.submit();
  H.MDH.itemResult(true, 'ok', [], 'create', tok('hw_demos_create'));
  H.hwItemOpen(null, null, {});
  eq(DOC.getElementById('nxm_code').value, '',
     'po uloženej položke je formulár čistý (proposal sa spotreboval)');
  global.NXModal.close();
})();

// ==== 18) review #290/2 P1: UI-only prekreslenie NEHÝBE baseline ============
// Cudzia zmena, ktorá dorazí počas otvoreného editora, sa NESMIE stať novým
// „pôvodným stavom": inak by patch poslal cudzie zmeny ako vlastné a s revíziou,
// ktorá prejde serverovou bránou — tichý prepis cudzej práce.

(function(){
  boot();
  H.hwItemOpen(ITEMS[0], null, {});          // otvorené nad revíziou r1
  DOC.getElementById('nxm_notes').value = 'moja poznámka';

  // Medzitým príde push s NOVŠOU revíziou a zmeneným názvom.
  H.MDH.setItems({ items: [{ item_code: '104717', name_sk: 'Sensys 8645i CUDZIA ZMENA',
                             category: 'ZAVESY', unit: 'ks', price_eur_vat: 9.99,
                             manufacturer: 'Hettich', series: 'Sensys', row_rev: 'r9' },
                           ITEMS[1], ITEMS[2]],
                   state: 'ok' });

  // Používateľ len prepne výrobcu → UI-only prekreslenie.
  const man = DOC.getElementById('nxm_manufacturer');
  man.value = 'Blum';
  dispatch(man, 'change');
  ok(global.NXModal.isOpen(), 'modal po prekreslení žije');
  eq(DOC.getElementById('nxm_notes').value, 'moja poznámka', 'rozpísané hodnoty prežili');

  SENT.length = 0;
  global.NXModal.submit();
  const p = last('hw_patch');
  ok(p, 'uloženie odišlo');
  eq(p.row_rev, 'r1',
     'posiela sa PÔVODNÁ revízia — server má konflikt odhaliť, nie ho obísť');
  ok(!Object.prototype.hasOwnProperty.call(p.patch, 'name_sk'),
     'cudzia zmena názvu sa NEPOSIELA ako moja (baseline sa neposunula)');
  ok(!Object.prototype.hasOwnProperty.call(p.patch, 'price_eur_vat'),
     'ani cudzia zmena ceny');
  eq(p.patch.notes, 'moja poznámka', 'ide len to, čo používateľ naozaj zmenil');
  eq(p.patch.manufacturer, 'Blum', 'a jeho vlastná zmena výrobcu');
  global.NXModal.close();
})();

// ==== 19) review #290/2 P1: nedostupná taxonómia ZAMKNE klasifikáciu ========
// Katalóg môže byť zapisovateľný, kým je taxonómia read-only alebo sa vôbec
// nenačítala. Prázdny select by nad už zaradenou položkou pri uložení
// hocijakej inej zmeny TICHO zmazal výrobcu aj radu.

(function(){
  boot();
  // Server posiela prázdny zoznam + príznak (fail-closed vetva `taxonomy_payload`).
  H.MDH.init({ items: ITEMS, state: 'ok', revision: 'rev1', version: '0.9.23',
               categories: CATS, category_labels: LABELS, units: ['ks', 'set'],
               taxonomy: { manufacturers: [], series: [], read_only: true,
                           state_reason: 'súbor je z novšej verzie' } });
  H.hwItemOpen(ITEMS[0], null, {});          // položka MÁ Hettich · Sensys

  const man = DOC.getElementById('nxm_manufacturer');
  const ser = DOC.getElementById('nxm_series');
  eq(man.value, 'Hettich', 'uložený výrobca je VIDIEŤ (nie prázdno)');
  eq(ser.value, 'Sensys', 'aj uložená rada');
  ok(man.hasAttribute('disabled') && man.getAttribute('aria-disabled') === 'true',
     'a select je ZAMKNUTÝ (pri `select` `aria-disabled` sám hodnotu neubráni)');
  ok(ser.hasAttribute('disabled'), 'oba');
  ok(textOf(MODAL_ROOT).indexOf('novšej verzie') > -1,
     'dôvod je na obrazovke (D-78 — nie tiché zamknutie)');
  const opts = qa('#nxm_manufacturer option').map(function(o){ return o.getAttribute('value'); });
  eq(opts, ['', 'Hettich'], 'ponuka je uložená hodnota — žiadne „+ Vytvoriť"');

  DOC.getElementById('nxm_notes').value = 'nesúvisiaca zmena';
  SENT.length = 0;
  global.NXModal.submit();
  const p = last('hw_patch');
  ok(p, 'uloženie prešlo — katalóg zapisovateľný je');
  ok(!Object.prototype.hasOwnProperty.call(p.patch, 'manufacturer'),
     'patch NEOBSAHUJE výrobcu (ani prázdneho) — klasifikácia sa nezmaže');
  ok(!Object.prototype.hasOwnProperty.call(p.patch, 'series'), 'ani radu');
  eq(p.patch.notes, 'nesúvisiaca zmena', 'ide len skutočná zmena');
  global.NXModal.close();

  // Čistá funkcia: prázdny zoznam bez príznaku je ten istý stav.
  H.MDH.init({ items: ITEMS, state: 'ok', categories: CATS, category_labels: LABELS,
               units: ['ks'], taxonomy: { manufacturers: [], series: [], read_only: false } });
  eq(H.hwItemManOptions('Hettich').map(function(o){ return o[0]; }), ['', 'Hettich'],
     'prázdny zoznam = to isté zamknutie (server ho nemusí označiť)');

  // A naopak: s NAČÍTANOU taxonómiou klasifikácia do payloadu PATRÍ.
  boot();
  H.hwItemOpen(null, null, {});
  DOC.getElementById('nxm_code').value = 'K1';
  DOC.getElementById('nxm_name').value = 'S klasifikáciou';
  const mm = DOC.getElementById('nxm_manufacturer');
  mm.value = 'Hettich';
  dispatch(mm, 'change');
  const ss = DOC.getElementById('nxm_series');
  ss.value = 'Sensys';
  dispatch(ss, 'change');
  SENT.length = 0;
  global.NXModal.submit();
  eq(last('hw_create').fields.manufacturer, 'Hettich',
     'výrobca ide serveru na overenie proti taxonómii');
  eq(last('hw_create').fields.series, 'Sensys', 'a rada tiež');
  global.NXModal.close();
})();

// ==== 20) review #290/2 P2: hotový proposal po zmene lookupu ================

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  demosType(PROP.url);
  H.MDH.demosPreview(PROP);                  // proposal A je hotový
  eq(DOC.getElementById('nxm_code').value, '357695', 'A predvyplnilo formulár');

  // Používateľ vloží INÚ adresu a uloží skôr, než nová dobehne.
  demosType('https://www.demos-trade.sk/iny-produkt/');
  SENT.length = 0;
  global.NXModal.submit();
  eq(sent('hw_demos_create').length, 0,
     'žiadny zápis s `pid` STARÉHO produktu (polia sa nezmenili, ale lookup áno)');
  eq(sent('hw_create').length, 0, 'a ani ručná cesta — čaká sa na náhľad');
  ok(global.NXModal.isOpen(), 'modal ostáva otvorený');
  ok(textOf(MODAL_ROOT).indexOf('Načítavam produkt z Démosu') > -1,
     'a povie, na čo sa čaká (aj ako z toho von)');

  // Keď náhľad dobehne, zápis sa pustí — a je to už produkt B.
  const PROP_B = { ok: true, pid: 'p2', url: 'https://www.demos-trade.sk/iny-produkt/',
                   code: '999000', name_sk: 'Iný produkt', unit: 'ks', price_vat: 5.5,
                   category_guess: 'NOHY', manufacturer_guess: '', exists: false, related: [] };
  H.MDH.demosPreview(PROP_B);
  eq(DOC.getElementById('nxm_code').value, '999000', 'formulár drží produkt B');
  SENT.length = 0;
  global.NXModal.submit();
  eq(last('hw_demos_create').pid, 'p2', 'a ukladá sa `pid` produktu B');
  H.MDH.itemResult(true, 'ok', [], 'create', tok('hw_demos_create'));
})();

// ==== 21) review #290/2 P2: token výsledku taxonómie ========================

(function(){
  boot();
  H.hwItemOpen(null, null, {});
  const m1 = DOC.getElementById('nxm_manufacturer');
  m1.value = '__new__';
  dispatch(m1, 'change');
  DOC.getElementById('nxm_manufacturer_new').value = 'Okno A';
  dispatch(q('[data-action="hw-tax-create"][data-nxm-for="manufacturer"]'), 'click');
  const tokenA = tok('hw_tax_create_manufacturer');
  ok(!!tokenA, 'požiadavka nesie vlastnú identitu');
  global.NXModal.close();                    // okno A sa zavrelo

  H.hwItemOpen(null, null, {});              // okno B
  DOC.getElementById('nxm_name').value = 'Položka B';
  H.MDH.taxonomy({ ok: true, op: 'manufacturer', name: 'Okno A', errors: [], token: tokenA,
                   taxonomy: { manufacturers: ['Blum', 'Hettich', 'Okno A'],
                               series: TAX.series, read_only: false, state_reason: '' } });
  eq(DOC.getElementById('nxm_manufacturer').value, '',
     'výsledok patriaci ZAVRETÉMU oknu nevyberie klasifikáciu v okne otvorenom teraz');
  eq(DOC.getElementById('nxm_name').value, 'Položka B', 'a koncept B sa nezahodil');
  ok(H.hwItemManOptions('').some(function(o){ return o[0] === 'Okno A'; }),
     'zoznam sa napriek tomu obnovil — je to globálny stav');
  global.NXModal.close();
})();

console.log(`OK ${n} kontrol (KOV-B2 katalóg: strom + modal + Démos)`);
