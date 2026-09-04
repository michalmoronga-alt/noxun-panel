// KOV-B3 — EDITOR SETU: modal (D-15), členovia, klasifikácia, živý náhľad
// a dlaždice s chipmi. Mini-DOM so skutočným parsovaním HTML a bublaním
// udalostí (`tests/js/minidom.js`) — bez neho sa delegované kliky, prekreslenie
// modalu ani poradie odpovedí náhľadu overiť nedajú.
//
// Čo dávka sľubuje (a čo tieto testy strážia):
//   R1  modal nahradil inline editor; poradie polí 1→6 je KONTEXTOVÉ
//       (konštrukcia len pri zásuvke, explicitný typ len keď ho server nemá
//       z čoho odvodiť), auto-názov sa prepočítava LEN kým ho človek neprepísal
//   R2  PRIPNUTÁ revízia z chvíle otvorenia (R-41) — nikdy čerstvá z pushu;
//       konflikt necháva draft a ponúka VEDOMÚ obnovu
//   R3  člen = „Ako sa určí kód?" + „Koľko?"; prepnutie spôsobu zahodí polia
//       druhého (XOR ostáva, dátový tvar člena sa NEMENÍ)
//   R4  náhľad nesie generáciu požiadavky — STARŠIA odpoveď nikdy neprepíše
//       novšiu; písanie je debouncované (jedna požiadavka, nie jedna na znak)
//   R5  dlaždice s chipmi klasifikácie / „nezaradený" / „neaktívny";
//       neaktívny set sa NENÚKA ako nový default
//
// MUTÁCIE (každá overená ručne — po zanesení chyby do zdroja spadne uvedený test):
//   M1 `hwsSetSubmit` pošle `hwsCurrentRev()` namiesto `HWS_SET.rev`
//      -> „KOV-B3 (M1): Uložiť posiela PRIPNUTÚ revíziu…"
//   M2 `hwsMemberSwitch` nechá polia predchádzajúceho spôsobu
//      -> „KOV-B3: prepnutie spôsobu ZAHODÍ polia druhého…"
//   M3 `hwsGlobalOptions` neaktívny set nefiltruje
//      -> „KOV-B3 (M3): neaktívny set sa NENÚKA ako nový default"
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch, textOf } = require(path.join(__dirname, 'minidom.js'));

// Falosne casovace: debounce nahladu sa musi dat SPUSTIT riadene (a nesmie
// prezit test). Musia stat PRED prvym otvorenim modalu.
let TIMERS = [];
global.setTimeout = function(fn){ TIMERS.push(fn); return TIMERS.length; };
global.clearTimeout = function(id){ if (id) TIMERS[id - 1] = null; };
function pending(){ return TIMERS.filter(Boolean).length; }
function flush(){
  const list = TIMERS;
  TIMERS = [];
  list.forEach(function(fn){ if (fn) fn(); });
}

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXModal = require(path.join(JS, 'nx_modal.js'));
global.NXModal = NXModal;          // `hw_sets.js` siaha na HOLY global (CEF)

const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);
const TABSETS = mkEl('div');
TABSETS.attrs.id = 'hwTabSets';
DOC.body.appendChild(TABSETS);
const TABPROJ = mkEl('div');
TABPROJ.attrs.id = 'hwTabProj';
DOC.body.appendChild(TABPROJ);

// Kanal do Ruby: zachytavame VSETKO, co sekcia odosle.
const SENT = [];
const BRIDGE = {};
['hws_save_set', 'hws_delete_set', 'hws_preview', 'hws_map_project', 'hws_map_global',
 'hws_merge_seed', 'hws_reset_project', 'hw_tax_create_manufacturer',
 'hw_tax_create_series'].forEach(function(name){
  BRIDGE[name] = function(json){ SENT.push({ name: name, data: JSON.parse(json) }); };
});
global.window.sketchup = BRIDGE;
global.sketchup = BRIDGE;          // `window.sketchup && sketchup[name]`

const HWS = require(path.join(JS, 'hw_sets.js'));

// --- payload servera ---------------------------------------------------------
// Slovniky klasifikacie posiela SERVER (`HardwareSets::CLASS_OPTIONS`) — JS
// ziadny vlastny zoznam nema a tento test to strazi (sekcia 0).
const CLASS_OPTIONS = {
  use_type: [['door', 'Dvierka'], ['drawer', 'Zásuvka'], ['lift', 'Výklop'],
             ['fall', 'Sklopné'], ['other', 'Iné']],
  opening_mode: [['classic', 'Klasické'], ['tipon', 'Tip-On'],
                 ['other', 'Ostatné / neuplatňuje sa']],
  drawer_construction: [['metal', 'Kovové bočnice'], ['wood', 'Drevený box / skrytý výsuv'],
                        ['other', 'Ostatné / atyp']]
};
const PARAMS = [
  { key: 'height', label: 'výška sokla', by: 'podľa výšky sokla' },
  { key: 'front_height', label: 'výška čela', by: 'podľa výšky čela' }
];
const ATIRA = {
  set_id: 'atira-h176', name: 'Atira biela H176', generic_type: 'slide',
  use_type: 'drawer', opening_mode: 'classic', drawer_construction: 'metal',
  manufacturer: 'Hettich', series: 'InnoTech Atira',
  members: [{ per: 'unit', qty: 1, label: 'K-sada', code_by_nl: { '420': '357695', '470': '357696' } }]
};
const KLASIK = { set_id: 'zaves-klasik', name: 'Záves KLASIK', generic_type: 'hinge',
                 members: [{ code: '104717', per: 'unit', qty: 1 }] };
const STARY = { set_id: 'zaves-stary', name: 'Záves STARÝ', generic_type: 'hinge',
                active: false, members: [{ code: '104718', per: 'unit', qty: 1 }] };

function payload(over){
  const base = {
    sets: [ATIRA, KLASIK, STARY],
    global_mapping: { hinge: 'zaves-klasik' },
    revision: 'rev1',
    library_state: 'ok', library_reason: '',
    type_options: { hinge: [{ set_id: 'zaves-klasik', name: 'Záves KLASIK' }],
                    slide: [{ set_id: 'atira-h176', name: 'Atira biela H176' }] },
    params: PARAMS,
    class_options: CLASS_OPTIONS,
    preview_sample: { nominal_length: 470, front_height: 176, height: 100 },
    taxonomy: { manufacturers: ['Blum', 'Hettich'],
                series: [{ name: 'Sensys', manufacturer: 'Hettich' },
                         { name: 'InnoTech Atira', manufacturer: 'Hettich' }],
                revision: 'tax1', read_only: false, write_blocked: false, state_reason: '' },
    project: { status: 'ok', mapping: {}, sets: [] },
    generic_types: [{ key: 'hinge', label: 'Závesy' }, { key: 'slide', label: 'Výsuvy' },
                    { key: 'leg', label: 'Nohy' }],
    model_guid: 'G1', model_title: 'Test'
  };
  const out = {};
  Object.keys(base).forEach(function(k){ out[k] = base[k]; });
  Object.keys(over || {}).forEach(function(k){ out[k] = over[k]; });
  return out;
}

function el(id){ return DOC.getElementById(id); }
function click(node){ dispatch(node, 'click'); }
function setVal(id, value){
  const node = el(id);
  assert.ok(node, 'pole ' + id + ' v modale chýba');
  node.value = value;
  dispatch(node, 'change');
}
function typeIn(id, value){
  const node = el(id);
  assert.ok(node, 'pole ' + id + ' v modale chýba');
  node.value = value;
  dispatch(node, 'input');
}
function fieldKeys(){
  return ROOT.querySelectorAll('[data-nxm]').map(function(x){ return x.getAttribute('data-nxm'); });
}
function openNew(){
  const btn = TABSETS.querySelectorAll('[data-action="hws-new"]')[0];
  click(btn);
  flush(); // prvy nahlad
  SENT.length = 0;
}
function openEdit(sid){
  const btn = TABSETS.querySelectorAll('[data-set-id="' + sid + '"]')
    .filter(function(b){ return b.getAttribute('data-action') === 'hws-edit'; })[0];
  click(btn);
  flush();
  SENT.length = 0;
}
function lastToken(){
  for (let i = SENT.length - 1; i >= 0; i--){
    if (SENT[i].name === 'hws_save_set') return SENT[i].data.token;
  }
  return '';
}

// ============ 0) SLOVNIKY SU ZO SERVERA, nie z JS ============================
(function(){
  const fs = require('node:fs');
  const src = fs.readFileSync(path.join(JS, 'hw_sets.js'), 'utf8');
  ok(src.indexOf('Zásuvka') === -1 && src.indexOf('Kovové bočnice') === -1,
     'JS nemá VLASTNÝ zoznam hodnôt klasifikácie — jediná autorita je core');
  HWS.HWSETS.init(payload());
  eq(HWS.hwsClassLabel('use_type', 'drawer'), 'Zásuvka', 'popisok príde v payloade');
  eq(HWS.hwsClassLabel('use_type', 'sliding'), 'sliding',
     'hodnota z NOVŠEJ verzie sa NEPREKLADÁ — vypíše sa tak, ako prišla');
  eq(HWS.hwsClassOptions('use_type', '— nezaradený —')[0], ['', '— nezaradený —'],
     'prvá voľba je VEDOME prázdna klasifikácia (legacy set)');
})();

// ============ 1) DLAZDICE S CHIPMI (R5) ======================================
(function(){
  HWS.HWSETS.init(payload());
  const tiles = TABSETS.querySelectorAll('.hwsset');
  eq(tiles.length, 3, 'každý set knižnice má dlaždicu');
  const atira = textOf(tiles[0]);
  ok(atira.indexOf('Zásuvka') > -1 && atira.indexOf('Klasické') > -1 &&
     atira.indexOf('Kovové bočnice') > -1, 'chipy nesú OSI klasifikácie');
  ok(atira.indexOf('Hettich') > -1 && atira.indexOf('InnoTech Atira') > -1,
     'a k nim výrobcu a radu');
  ok(textOf(tiles[1]).indexOf('nezaradený') > -1,
     'legacy set (bez klasifikácie) má chip „nezaradený" — je to STAV, nie chyba');
  ok(textOf(tiles[2]).indexOf('neaktívny') > -1, 'neaktívny set to prizná chipom');

  eq(HWS.hwsChips(KLASIK).map(function(c){ return c.cls; }), ['none', 'dim'],
     'nezaradený chip má vlastnú triedu (nie je to bežný chip)');
  eq(HWS.hwsChips(ATIRA).length, 5, 'zaradený set: typ · otváranie · konštrukcia · výrobca · rada');
})();

// ============ 2) NEAKTIVNY SA NENUKA AKO NOVY DEFAULT (R5, M3) ===============
(function(){
  HWS.HWSETS.init(payload());
  eq(HWS.hwsGlobalOptions('hinge').map(function(s){ return s.set_id; }), ['zaves-klasik'],
     'KOV-B3 (M3): neaktívny set sa NENÚKA ako nový default');
  // Ale set, ktory sa PRAVE pouziva, v ponuke OSTAVA — inak by select ukazoval
  // prazdno tam, kde hodnota je, a prvy klik vedla by ju ticho prepisal.
  HWS.HWSETS.init(payload({ global_mapping: { hinge: 'zaves-stary' } }));
  eq(HWS.hwsGlobalOptions('hinge').map(function(s){ return s.set_id; }).sort(),
     ['zaves-klasik', 'zaves-stary'],
     'aktuálne použitý neaktívny set v ponuke OSTÁVA');
})();

// ============ 3) MODAL: PORADIE A KONTEXT POLI (R1) ==========================
(function(){
  HWS.HWSETS.init(payload());
  openNew();
  ok(NXModal.isOpen(), 'klik na „+ Nový set" otvorí MODAL (inline editor zanikol)');
  ok(TABSETS.querySelectorAll('.hwseditor').length === 0,
     'a v tele sekcie po ňom neostal žiadny inline formulár');
  eq(fieldKeys(), ['use_type', 'opening_mode', 'manufacturer', 'series',
                   'generic_type', 'name', 'active'],
     'poradie 1→6 podľa mockupu; nezaradený set si typ kovania vyberá SÁM');

  setVal('nxm_use_type', 'drawer');
  ok(fieldKeys().indexOf('drawer_construction') > -1,
     'konštrukcia zásuvky sa objaví LEN pri zásuvke');
  eq(fieldKeys().indexOf('generic_type'), -1,
     'a explicitný typ kovania zmizne — pri zaradenom sete ho ODVODZUJE server');
  eq(fieldKeys(), ['use_type', 'opening_mode', 'drawer_construction', 'manufacturer',
                   'series', 'name', 'active'], 'poradie ostáva 1→6');

  setVal('nxm_use_type', 'door');
  eq(fieldKeys().indexOf('drawer_construction'), -1,
     'po prepnutí na dvierka konštrukcia zmizne');

  setVal('nxm_use_type', 'other');
  ok(fieldKeys().indexOf('generic_type') > -1,
     '„Iné" je JEDINÝ prípad, kedy zaradený set pýta typ kovania explicitne');
  NXModal.close();
})();

// ============ 4) ZAVISLA RADA + „+ Vytvoriť…" (R1) ===========================
(function(){
  HWS.HWSETS.init(payload());
  openNew();
  setVal('nxm_manufacturer', 'Hettich');
  eq(HWS.hwsSerOptions('Hettich', '').map(function(o){ return o[0]; }),
     ['', 'Sensys', 'InnoTech Atira', HWS.HWS_NEW_OPT],
     'rada je závislá od výrobcu a ponúka „+ Vytvoriť radu…"');
  eq(HWS.hwsSerOptions('', '').map(function(o){ return o[0]; }), [''],
     'bez výrobcu sa rada založiť NEDÁ (patrí presne jednému)');
  setVal('nxm_series', 'Sensys');
  setVal('nxm_manufacturer', 'Blum');
  eq(el('nxm_series').value, '',
     'zmena výrobcu zahodí radu, ktorá mu nepatrí (nikdy tichá nezhoda)');

  setVal('nxm_manufacturer', HWS.HWS_NEW_OPT);
  ok(fieldKeys().indexOf('manufacturer_new') > -1, 'voľba „+ Vytvoriť…" otvorí pole názvu');
  SENT.length = 0;
  const btn = ROOT.querySelectorAll('[data-action="hws-tax-create"]')[0];
  ok(btn, 'zápis do taxonómie má VLASTNÉ tlačidlo (nikdy change/blur)');
  typeIn('nxm_manufacturer_new', 'Strong');
  click(btn);
  eq(SENT.map(function(s){ return s.name; }), ['hw_tax_create_manufacturer'],
     'klik založí výrobcu — set sa pritom NEUKLADÁ');
  const tok = SENT[0].data.token;
  ok(tok && tok.length > 3, 'a nesie identitu požiadavky');
  // Cudzia odpoved (iny token) NESMIE vybrat klasifikaciu v tomto okne.
  HWS.HWSETS.taxonomy({ ok: true, op: 'manufacturer', name: 'Cudzí', token: 'iny',
                        taxonomy: payload().taxonomy });
  ok(el('nxm_manufacturer').value === HWS.HWS_NEW_OPT,
     'odpoveď patriaca inej požiadavke hodnotu nemení');
  HWS.HWSETS.taxonomy({ ok: true, op: 'manufacturer', name: 'Strong', token: tok,
                        taxonomy: { manufacturers: ['Blum', 'Hettich', 'Strong'], series: [],
                                    read_only: false, write_blocked: false, state_reason: '' } });
  eq(el('nxm_manufacturer').value, 'Strong', 'vlastná odpoveď nového výrobcu VYBERIE');
  NXModal.close();
})();

// ============ 5) AUTO-NAZOV (R1) ============================================
(function(){
  eq(HWS.hwsAutoName({ manufacturer: 'Hettich', series: 'InnoTech Atira',
                       use_type: 'drawer', drawer_construction: 'metal',
                       opening_mode: 'classic' }),
     'Hettich · InnoTech Atira · Kovové bočnice · Klasické',
     'pri zásuvke rozlišuje KONŠTRUKCIA (vzor mockupu)');
  eq(HWS.hwsAutoName({ manufacturer: 'Hettich', series: 'Sensys',
                       use_type: 'door', opening_mode: 'classic' }),
     'Hettich · Sensys · Dvierka · Klasické', 'inde rozlišuje typ použitia');
  eq(HWS.hwsAutoName({ manufacturer: 'Strong', use_type: 'other', opening_mode: 'other' }),
     'Strong · Iné', '„neuplatňuje sa" sa do názvu nepíše');
  eq(HWS.hwsApplyAutoName({ manufacturer: 'Hettich', use_type: 'door',
                            opening_mode: 'classic', name: 'Moje meno' }, true),
     'Moje meno', 'ručne prepísaný názov auto-návrh UŽ NEPREPISUJE');

  HWS.HWSETS.init(payload());
  openNew();
  setVal('nxm_use_type', 'door');
  setVal('nxm_manufacturer', 'Hettich');
  setVal('nxm_series', 'Sensys');
  setVal('nxm_opening_mode', 'classic');
  eq(el('nxm_name').value, 'Hettich · Sensys · Dvierka · Klasické',
     'názov sa prepočítava z klasifikácie, kým ho človek neprepísal');
  typeIn('nxm_name', 'Záves na chatu');
  setVal('nxm_opening_mode', 'tipon');
  eq(el('nxm_name').value, 'Záves na chatu',
     'po ručnom prepise ho ďalšia zmena klasifikácie UŽ neprepíše');
  NXModal.close();
})();

// ============ 6) CLEN: 3 SPOSOBY × 2 „Koľko?" (R3) ==========================
(function(){
  // Ciste kombinacie: kazdy sposob × kazde uctovanie round-tripuje do payloadu
  // BEZ zvyskov druheho sposobu (XOR je datovy kontrakt clena).
  const filled = {
    code: function(m){ m.code = '104717'; return m; },
    nl: function(m){ m.series = [{ nl: '470', code: '357696' }]; return m; },
    bands: function(m){ m.param = 'height'; m.bands = [{ min: '17', max: '21', code: '82744' }]; return m; }
  };
  ['code', 'nl', 'bands'].forEach(function(kind){
    ['unit', 'owner'].forEach(function(per){
      const m = filled[kind](HWS.hwsMemberBlank(kind, 'hinge'));
      m.per = per;
      const built = HWS.hwsBuildMembers([m])[0];
      eq(built.per, per, kind + '/' + per + ': „Koľko?" sa nesie');
      const shape = ['code', 'code_by_nl', 'param_bands'].filter(function(k){
        return Object.prototype.hasOwnProperty.call(built, k);
      });
      eq(shape.length, 1, kind + '/' + per + ': člen nesie PRÁVE JEDEN spôsob (XOR)');
      ok(!Object.prototype.hasOwnProperty.call(built, 'code_by_height'),
         kind + '/' + per + ': `code_by_height` neexistuje a nevzniká');
    });
  });
  eq(HWS.hwsMemberKind({ is_series: true }), 'nl', 'rad NL sa rozpozná');
  eq(HWS.hwsMemberKind({ is_bands: true }), 'bands', 'pásma sa rozpoznajú');
  eq(HWS.hwsMemberKind({ code: 'x' }), 'code', 'pevný kód je východisko');

  const switched = HWS.hwsMemberSwitch(
    { is_series: true, per: 'owner', qty: 2, label: 'K-sada',
      series: [{ nl: '470', code: '357696' }] }, 'bands', 'slide');
  eq(switched.per, 'owner', 'prepnutie spôsobu zachová „Koľko?"');
  eq(switched.qty, 2, 'aj počet');
  eq(switched.label, 'K-sada', 'aj popis');
  ok(!switched.series && !switched.is_series,
     'KOV-B3: prepnutie spôsobu ZAHODÍ polia druhého (polovičný člen by spadol až na serveri)');
  ok(switched.is_bands && switched.bands.length === 1, 'a pripraví prázdny riadok nového spôsobu');
})();

// ============ 7) CLENOVIA V MODALI + PAYLOAD (R3) ===========================
(function(){
  HWS.HWSETS.init(payload());
  openNew();
  setVal('nxm_use_type', 'drawer');
  setVal('nxm_opening_mode', 'classic');
  setVal('nxm_drawer_construction', 'metal');
  setVal('nxm_manufacturer', 'Hettich');
  setVal('nxm_series', 'InnoTech Atira');
  const host = NXModal.customBox('members');
  ok(host, 'zoznam členov žije vo vlastnom uzle kostry (`custom`)');
  eq(host.querySelectorAll('[data-nxm-row]').length, 1,
     'nový set štartuje s jedným prázdnym členom');
  eq(host.querySelectorAll('[data-action="hws-m-add"]').length, 1,
     'JEDNO tlačidlo „+ Pridať člena" (nie tri druhy členov)');
  click(host.querySelectorAll('[data-action="hws-m-add"]')[0]);
  let rows = NXModal.customBox('members').querySelectorAll('[data-nxm-row]');
  eq(rows.length, 2, 'a pridáva ďalší riadok');
  click(rows[1].querySelectorAll('[data-action="hws-m-del"]')[0]);
  rows = NXModal.customBox('members').querySelectorAll('[data-nxm-row]');
  eq(rows.length, 1, 'krížik člena odoberie');
  click(rows[0].querySelectorAll('[data-action="hws-m-del"]')[0]);
  ok(textOf(NXModal.customBox('members')).indexOf('Set zatiaľ nemá člena') > -1,
     'prázdny zoznam to POVIE (set bez člena neobjedná nič)');
  click(NXModal.customBox('members').querySelectorAll('[data-action="hws-m-add"]')[0]);
  rows = NXModal.customBox('members').querySelectorAll('[data-nxm-row]');
  eq(rows.length, 1, 'a „+ Pridať člena" ho vráti');
  const kind = rows[0].querySelectorAll('[data-hws-field="kind"]')[0];
  const per = rows[0].querySelectorAll('[data-hws-field="per"]')[0];
  ok(kind && per, 'riadok člena kladie DVE otázky — „Ako sa určí kód?" a „Koľko?"');
  kind.value = 'nl';
  dispatch(kind, 'change');
  const nlRow = NXModal.customBox('members').querySelectorAll('[data-hws-field="nl"]')[0];
  ok(nlRow, 'prepnutie na rad NL vykreslí riadok dĺžky');
  nlRow.value = '470';
  dispatch(nlRow, 'input');
  const codeIn = NXModal.customBox('members')
    .querySelectorAll('[data-hws-s="0"][data-hws-field="code"]')[0];
  codeIn.value = '357696';
  dispatch(codeIn, 'input');
  typeIn('nxm_name', 'Atira 470');
  flush();
  SENT.length = 0;
  NXModal.submit();
  const sent = SENT.filter(function(s){ return s.name === 'hws_save_set'; })[0];
  ok(sent, 'Uložiť pošle set na server');
  eq(sent.data.set.members, [{ per: 'unit', qty: 1, code_by_nl: { '470': '357696' } }],
     'člen odchádza v NEZMENENOM dátovom tvare');
  eq(sent.data.set.use_type, 'drawer', 'klasifikácia ide s ním');
  eq(sent.data.set.drawer_construction, 'metal', 'aj konštrukcia zásuvky');
  ok(!Object.prototype.hasOwnProperty.call(sent.data.set, 'generic_type'),
     'ale `generic_type` NIE — je ODVODENÝ na serveri (dva zápisy o tom istom by si protirečili)');
  eq(sent.data.set.set_id, 'atira-470', 'identita nového setu je slug z názvu');
  eq(sent.data.create, true, 'a ide ako NOVÝ set (server odmietne kolíziu identity)');
  eq(sent.data.set.active, true, 'príznak Aktívny sa posiela VŽDY (server merguje)');

  // Prazdna klasifikacia sa posiela ZAMERNE — inak by `save_set!` prebral
  // klasifikaciu z ULOZENEHO setu a prepnutie zo zasuvky na nezaradeny set by
  // sa uz nikdy nepodarilo.
  const payloadEmpty = HWS.hwsBuildSetPayload({ set_id: 'x', name: 'X', generic_type: 'hinge' }, []);
  eq(payloadEmpty.use_type, '', 'nezaradený set posiela klasifikáciu PRÁZDNU, nie chýbajúcu');
  eq(payloadEmpty.drawer_construction, '',
     'a konštrukciu tiež — vynechať ju by znamenalo prevziať starú zo servera');
  eq(payloadEmpty.generic_type, 'hinge', 'typ kovania si vtedy nesie klient');
  NXModal.close();
})();

// ============ 8) PRIPNUTA REVIZIA + KONFLIKT (R2, R-41, M1) =================
(function(){
  HWS.HWSETS.init(payload());
  openEdit('atira-h176');
  ok(NXModal.isOpen(), 'úprava setu otvorí modal');
  eq(el('nxm_use_type').value, 'drawer', 'a predvyplní ULOŽENÚ klasifikáciu');
  const memberRows = NXModal.customBox('members').querySelectorAll('[data-nxm-row]');
  eq(memberRows.length, 1, 'aj členov');

  // Medzitym pride PUSH s NOVOU reviziou (cudzi zapis do kniznice).
  HWS.HWSETS.setData(payload({ revision: 'rev2' }));
  SENT.length = 0;
  NXModal.submit();
  const sent = SENT.filter(function(s){ return s.name === 'hws_save_set'; })[0];
  eq(sent.data.revision, 'rev1',
     'KOV-B3 (M1): Uložiť posiela PRIPNUTÚ revíziu z chvíle otvorenia, nie čerstvú z pushu');
  eq(sent.data.create, false, 'úprava nie je zakladanie');

  // Server hlasi KONFLIKT — draft OSTAVA, obnova je vedomy druhy klik.
  HWS.HWSETS.setResult(false, 'Set medzitým zmenil niekto iný.', [], sent.data.token, true);
  ok(NXModal.isOpen(), 'konflikt modal NEZATVÁRA — rozpísané hodnoty ostávajú');
  ok(textOf(ROOT).indexOf('zmenil niekto iný') > -1, 'a hláška to povie nahlas');
  const refresh = ROOT.querySelectorAll('[data-action="hws-set-refresh"]')[0];
  ok(refresh, 'obnova je EXPLICITNÉ tlačidlo (draft sa nezahadzuje sám)');
  ok(!NXModal.isBusy(), 'zámok odoslania je pustený — dá sa uložiť znova');

  typeIn('nxm_name', 'Moja verzia');
  ok(textOf(ROOT).indexOf('zmenil niekto iný') > -1, 'kým sa neklikne, draft aj hláška žijú');
  HWS.HWSETS.setData(payload({ revision: 'rev2',
                               sets: [{ set_id: 'atira-h176', name: 'Atira CUDZIA',
                                        generic_type: 'slide', use_type: 'drawer',
                                        opening_mode: 'tipon', drawer_construction: 'metal',
                                        manufacturer: 'Hettich', series: 'InnoTech Atira',
                                        members: [{ code: '999', per: 'unit', qty: 1 }] },
                                      KLASIK, STARY] }));
  click(ROOT.querySelectorAll('[data-action="hws-set-refresh"]')[0]);
  flush();
  eq(el('nxm_name').value, 'Atira CUDZIA', 'obnova AŽ PO potvrdení načíta čerstvý set');
  eq(el('nxm_opening_mode').value, 'tipon', 'vrátane cudzej klasifikácie');
  SENT.length = 0;
  NXModal.submit();
  eq(SENT.filter(function(s){ return s.name === 'hws_save_set'; })[0].data.revision, 'rev2',
     'a s ním sa PRIPNE aj čerstvá revízia (inak by konflikt bol nekonečný)');
  NXModal.close();
})();

// ============ 9) STRUKTUROVANE CHYBY SERVERA ================================
(function(){
  HWS.HWSETS.init(payload());
  openEdit('atira-h176');
  NXModal.submit();
  const tok = lastToken();
  HWS.HWSETS.setResult(false, 'Set sa nedá uložiť.',
                       [{ row: 0, field: 'members', msg: 'set „atira-h176“: člen nemá kód' },
                        { row: null, field: 'manufacturer', msg: 'set nemá výrobcu' }],
                       tok, false);
  ok(NXModal.isOpen(), 'odmietnutý zápis modal NEZATVÁRA');
  const line = NXModal.customBox('members').querySelectorAll('[data-nxm-row]')[0];
  ok(textOf(line).indexOf('člen nemá kód') > -1, 'chyba ČLENA pristane pri tom členovi');
  const manRow = el('nxm_manufacturer').closest('.mrow');
  ok(textOf(manRow).indexOf('nemá výrobcu') > -1, 'chyba POĽA pristane pri poli');

  // Odpoved patriaca uz odoslanemu inemu formularu okno NEZATVORI.
  HWS.HWSETS.setResult(true, 'ok', [], 'cudzi-token', false);
  ok(NXModal.isOpen(), 'odpoveď s cudzím tokenom sa IGNORUJE');
  NXModal.submit();
  HWS.HWSETS.setResult(true, 'Set uložený.', [], lastToken(), false);
  ok(!NXModal.isOpen(), 'úspešný zápis modal zatvorí');

  eq(HWS.hwsServerErrors([{ row: 2, field: 'members', msg: 'x' }]),
     [{ row: 'members:2', field: null, msg: 'x' }],
     'index člena sa prekladá na adresu riadku kostry');
  eq(HWS.hwsServerErrors([{ row: null, field: 'members', msg: 'set nemá členov' }]),
     [{ row: null, field: null, msg: 'set nemá členov' }],
     'chyba CELÉHO zoznamu ide do zberného pásu (nie je pole, ktoré by sa dalo očervenieť)');
  eq(HWS.hwsServerErrors([], 'niečo zlyhalo'),
     [{ row: null, field: null, msg: 'niečo zlyhalo' }],
     'bez štruktúry ostáva aspoň veta servera');
})();

// ============ 10) ZIVY NAHLAD: generacia a debounce (R4) ====================
(function(){
  HWS.HWSETS.init(payload());
  openEdit('atira-h176');
  SENT.length = 0;
  TIMERS = [];
  const mcode = NXModal.customBox('members')
    .querySelectorAll('[data-hws-s="0"][data-hws-field="code"]')[0];
  ok(mcode, 'rad NL má riadok s kódom');
  ['3', '35', '357'].forEach(function(v){ mcode.value = v; dispatch(mcode, 'input'); });
  eq(pending(), 1, 'písanie je DEBOUNCOVANÉ — nie jedna požiadavka na znak');
  flush();
  const reqs = SENT.filter(function(s){ return s.name === 'hws_preview'; });
  eq(reqs.length, 1, 'a po dobehnutí odíde JEDNA');
  const gen = reqs[0].data.gen;
  ok(gen > 0, 'požiadavka nesie generáciu');
  eq(reqs[0].data.sample.nominal_length, 470, 'a vzorové parametre vlastníka');
  ok(reqs[0].data.set.members.length === 1, 'náhľad počíta z DRAFTU, nie z uloženého setu');

  HWS.HWSETS.preview({ gen: gen, ok: true, text: 'Príklad: Zásuvka · NL 470 mm:\n357696 × 1 — 19,60 €' });
  const box = NXModal.customBox('preview');
  ok(textOf(box).indexOf('357696') > -1, 'odpoveď sa vykreslí');
  HWS.HWSETS.preview({ gen: gen - 1, ok: true, text: 'STARÝ VÝSLEDOK' });
  ok(textOf(NXModal.customBox('preview')).indexOf('STARÝ') === -1,
     'KOV-B3: STARŠIA odpoveď náhľadu NIKDY neprepíše novšiu');
  HWS.HWSETS.preview({ gen: gen + 1, ok: false, errors: [{ field: 'members', msg: 'x' }] });
  ok(textOf(NXModal.customBox('preview')).indexOf('nedá spočítať') > -1,
     'neplatný draft náhľad prizná — a formulár nezablokuje');

  eq(HWS.hwsPreviewStale(2, 3), true, 'staršia generácia = zahodiť');
  eq(HWS.hwsPreviewStale(4, 3), false, 'novšia = prijať');
  eq(HWS.hwsPreviewLines('Hlavička:\n357696 × 1\n!nemá kód'),
     [{ text: 'Hlavička:', cls: 'head' }, { text: '357696 × 1', cls: '' },
      { text: 'nemá kód', cls: 'warn' }],
     'text skladá SERVER — klient len rozlíši hlavičku a ORANGE dôvod');

  // Vzorova NL je ovladatelna a nahlad sa po nej prepocita.
  SENT.length = 0;
  const nl = ROOT.querySelectorAll('[data-hws-sample="nominal_length"]')[0];
  ok(nl, 'set s radom NL ponúka vzorovú dĺžku');
  nl.value = '420';
  dispatch(nl, 'input');
  flush();
  eq(SENT.filter(function(s){ return s.name === 'hws_preview'; })[0].data.sample.nominal_length, 420,
     'zmena vzorovej NL prepočíta náhľad');
  NXModal.close();
})();

// ============ 11) PAMAT ROZPISANEHO NOVEHO SETU =============================
(function(){
  HWS.HWSETS.init(payload());
  NXModal.clearMemory(HWS.HWS_KEY_NEW);
  openNew();
  typeIn('nxm_name', 'Rozpísaný set');
  const host = NXModal.customBox('members');
  const code = host.querySelectorAll('[data-hws-field="code"]')[0];
  code.value = '104717';
  dispatch(code, 'input');
  NXModal.close();               // Escape/krížik nesmie byť tichá strata
  openNew();
  eq(el('nxm_name').value, 'Rozpísaný set', 'rozpísaný názov prežije zatvorenie');
  const back = NXModal.customBox('members').querySelectorAll('[data-hws-field="code"]');
  eq(back.length, 1, 'aj ROZPÍSANÍ ČLENOVIA (vlastný uzol je súčasťou pamäte)');
  eq(back[0].value, '104717', 's hodnotami, ktoré do nich človek napísal');
  ok(textOf(ROOT).indexOf('rozpísaného konceptu') > -1,
     'a je to VIDNO — predvyplnenie z pamäte nesmie byť pasca');
  // PRIZNANA HRANICA (rovnaka ako v modale polozky KOV-B2): zmena
  // klasifikacie modal PREKRESLI a prekreslena podoba sa stava novym
  // VYCHODISKOM, takze uz vybrana klasifikacia sa do pamate nezapisuje.
  // Pas „Predvyplnené z rozpísaného konceptu" je preto povinny — pouzivatel
  // musi vidiet, ze pozera na koncept a klasifikaciu si ma prejst znova.
  eq(el('nxm_use_type').value, '', 'klasifikácia sa začína odznova (a je to vidieť)');
  NXModal.close();
  NXModal.clearMemory(HWS.HWS_KEY_NEW);
})();

console.log('OK test_kovb3_modal.js — ' + n + ' kontrol');
