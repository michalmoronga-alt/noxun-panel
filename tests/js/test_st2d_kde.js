// ŠT-2d — „Kde sa používa" v detaile dekoru · deep-link z karty dielca ·
// ⋯ editor riadku rozpočtu na zdieľanej D-15 kostre.
//
// Preco su to testy a nie klikanie:
//   1. ZOZNAM VLASTNIKOV je jedina obrazovka, kde pouzivatel vidi, KDE presne
//      dekor v zakazke je. Keby sa cisla alebo roly skladali v prehliadaci,
//      mal by druhu pravdu vedla Kusovnika — a dve rozne cisla o tom istom.
//   2. „OKO" posiela ADRESU VYBERU (material_id vlastnika / abs_id). Keby
//      poslalo nazov dekoru alebo pids z DOM, oznacilo by sa nieco ine, nez
//      riadok slubuje — a to sa da odhalit jedine odchytenim payloadu.
//   3. KOTVA deep-linku sa musi prelozit z `material_id` (jedina identita,
//      ktoru karta dielca ISTO ma) na SKUPINU dekoru. Bez toho by preklik
//      z Inspectora skoncil v prazdnych dlazdiciach.
//   4. ⋯ EDITOR je editor UZ EXISTUJUCEHO riadku — MUSI byt BEZ pamate
//      konceptu. Keby ju mal, otvorenie riadku B by predvyplnilo hodnoty
//      pisane do riadku A a ulozili by sa do nespravneho zaznamu.
//   5. Odmietnuty zapis NESMIE zavriet modal (kontrakt D-15) a zamok
//      odoslania sa musi pustit — inak by pouzivatel videl svoje hodnoty,
//      ale nemohol ich znova odoslat.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

const { mkEl, DOC, dispatch } = require(path.join(__dirname, 'minidom.js'));

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXModal = require(path.join(JS, 'nx_modal.js'));
// V CEF je `NXModal` GLOBAL (script tag); v Node ho `require` izoluje, takze
// sa musi zrkadlit do oboch mien — budget.js aj proj_materials.js ho volaju
// bez `window.` prefixu presne tak, ako v prehliadaci.
global.window.NXModal = NXModal;
global.NXModal = NXModal;

const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);
const STATUS = mkEl('div');
STATUS.attrs.id = 'status';
DOC.body.appendChild(STATUS);

// Most do Ruby: zachytavame, co by okno poslalo serveru.
const SENT = [];
global.sketchup = {
  nx_select: function(json){ SENT.push(['nx_select', JSON.parse(json)]); },
  budget_mutate: function(json){ SENT.push(['budget_mutate', JSON.parse(json)]); }
};
global.window.sketchup = global.sketchup;

require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
const B = require(path.join(JS, 'budget.js'));
const M = require(path.join(JS, 'proj_materials.js'));

// --- katalog jedneho dekoru (dve hrubky + dve pasky) -------------------------
const CAT = {
  catalog_rev: 'R1', catalog_schema: 9, catalog_state: 'ok',
  materials: { sheets: [] },
  catalog: {
    sheets: [
      { material_id: 'H3303_18', group_id: 'GRP1', decor: 'H3303', decor_name: 'Dub Halifax',
        manufacturer: 'Egger', type: 'DTDL', thickness: 18, color: [200, 180, 150], row_rev: 'r1' },
      { material_id: 'H3303_36', group_id: 'GRP1', decor: 'H3303', decor_name: 'Dub Halifax',
        manufacturer: 'Egger', type: 'DTDL', thickness: 36, color: [200, 180, 150], row_rev: 'r2' },
      { material_id: 'HDF_3', group_id: 'GRP2', decor: 'HDF', manufacturer: 'Kronospan',
        type: 'HDF', thickness: 3, color: [240, 240, 240], row_rev: 'r3' }
    ],
    edges: [
      { abs_id: 'ABS_22', group_id: 'GRP1', decor: 'H3303', width: 22, thickness: 1,
        color: [200, 180, 150], row_rev: 'r4' }
    ]
  }
};

// Rozpis zo servera (`StudioDialog#mat_used_where`).
const WHERE = {
  GRP1: {
    owners: [
      { owner_id: 'CAB-001', parts: 3, roles: ['Bok ľavý', 'Bok pravý', 'Strop'],
        material_ids: ['H3303_18', 'H3303_36'] },
      { owner_id: 'CAB-002', parts: 1, roles: ['Polica'], material_ids: ['H3303_18'] }
    ],
    edges: { ABS_22: 5 }
  },
  GRP2: { owners: [], edges: {} }
};

M.matApplyState({ model_guid: 'G1', cabinets: 2, project: {},
                  used: { GRP1: 4, GRP2: 1 }, used_where: WHERE, catalog: CAT });

function group(key){
  return M.groupCatalogByDecor(CAT.catalog, true).filter(function(g){ return g.key === key; })[0];
}

// ===================== 1) sklonovanie a prazdny stav =========================

(function(){
  eq(M.mdPartsSk(1), '1 dielec');
  eq(M.mdPartsSk(3), '3 dielce');
  eq(M.mdPartsSk(5), '5 dielcov');
  eq(M.mdPartsSk(0), '0 dielcov');

  const empty = M.mdWhereHtml(group('g:GRP2'), null);
  ok(empty.indexOf('Kde sa používa') > -1, 'sekcia je v detaile VZDY — aj ked je prazdna');
  ok(empty.indexOf('zatiaľ nepoužíva') > -1, '„nic tu nie je" musi byt VIDNO, nie tiche prazdno');
  ok(empty.indexOf('mdweye') === -1, 'a ziadne oko, ktore by neoznacilo nic');
})();

// ===================== 2) riadky vlastnikov + oko ============================

(function(){
  const h = M.mdWhereHtml(group('g:GRP1'), WHERE.GRP1);
  ok(h.indexOf('<b>CAB-001</b>') > -1, 'vlastnik je vidno');
  ok(h.indexOf('Bok ľavý · Bok pravý · Strop') > -1,
     'a ktore dielce to su — TEXTOM ZO SERVERA (klient preklad rol nema)');
  ok(h.indexOf('3 dielce') > -1 && h.indexOf('1 dielec') > -1, 'pocty su zo servera');
  ok(h.indexOf('#i-eye') > -1, 'kazdy riadok ma OKO (Lucide sprite, ziadne emoji)');
  ok(h.indexOf('mdWhereOwner(&quot;g:GRP1&quot;, &quot;CAB-001&quot;)') > -1,
     'oko vlastnika nesie kluc skupiny + owner_id');
  // paskovy riadok
  ok(h.indexOf('Páska') > -1 && h.indexOf('22') > -1, 'paska rodiny ma vlastny riadok');
  ok(h.indexOf('5 dielcov') > -1, 'a pocet DIELCOV (nie hran)');
  ok(h.indexOf('mdWhereEdge(&quot;g:GRP1&quot;, &quot;ABS_22&quot;)') > -1,
     'oko pasky nesie abs_id');

  // Nulovy pocet pasky sa NEKRESLI (paska katalogu, ktoru projekt nepouziva).
  const none = M.mdWhereHtml(group('g:GRP1'), { owners: [], edges: { ABS_22: 0 } });
  ok(none.indexOf('Páska') === -1, 'nepouzita paska v zozname nie je');
})();

(function(){
  // Detail dekoru sekciu naozaj kresli (nie je to osirela funkcia).
  const d = M.mdDetailHtml(group('g:GRP1'));
  ok(d.indexOf('Kde sa používa') > -1, 'sekcia je sucastou detailu dekoru');
  ok(d.indexOf('CAB-001') > -1, 'a nesie rozpis z payloadu');
})();

// ===================== 3) OKO -> payload vyberu ==============================

(function(){
  global.ST = { gen: 7, model_guid: 'G1' };
  SENT.length = 0;
  M.mdWhereOwner('g:GRP1', 'CAB-001');
  eq(SENT.length, 1, 'klik posle presne jeden vyber');
  eq(SENT[0][0], 'nx_select', 'a ide TOU ISTOU cestou ako klik v Kusovniku');
  const p = SENT[0][1];
  eq(p.material_key, ['H3303_18', 'H3303_36'],
     'adresa = varianty, ktore ten vlastnik naozaj ma (dekor mava viac hrubok)');
  eq(p.owner_id, 'CAB-001', 'a zuzenie na jeho korpus');
  eq(p.gen, 7, 'generacia okna — server odmietne klik zo stareho DOM');
  ok(p.pids === undefined, 'ziadne pids z DOM (po prestavbe by boli mrtve)');

  SENT.length = 0;
  M.mdWhereEdge('g:GRP1', 'ABS_22');
  eq(SENT[0][1].abs_key, 'ABS_22', 'paska sa vybera podla abs_id');
  ok(SENT[0][1].owner_id === undefined, 'paskovy riadok nie je viazany na vlastnika');

  SENT.length = 0;
  M.mdWhereOwner('g:GRP1', 'CAB-NEEXISTUJE');
  eq(SENT.length, 0, 'neznamy vlastnik nic neposiela');
})();

// ===================== 4) kotva deep-linku ===================================

(function(){
  const groups = M.groupCatalogByDecor(CAT.catalog, true);
  eq(M.mdAnchorGroupKey(groups, 'H3303_18'), 'g:GRP1',
     'kotva z karty dielca je `material_id` — preklada sa na SKUPINU');
  eq(M.mdAnchorGroupKey(groups, 'H3303_36'), 'g:GRP1', 'aj druha hrubka toho isteho dekoru');
  eq(M.mdAnchorGroupKey(groups, 'ABS_22'), 'g:GRP1', 'a paska rodiny tiez');
  eq(M.mdAnchorGroupKey(groups, 'g:GRP1'), 'g:GRP1', 'kluc skupiny sa prijme priamo');
  eq(M.mdAnchorGroupKey(groups, 'GRP1'), 'g:GRP1', 'aj holy group_id');
  eq(M.mdAnchorGroupKey(groups, 'NEZNAMY'), null, 'neznama kotva NEOTVARA nic');
  eq(M.mdAnchorGroupKey(groups, ''), null);

  eq(M.matOpenAnchor('H3303_18'), true, 'kotva otvorila detail dekoru');
  eq(M.matOpenAnchor('NEZNAMY'), false, 'neznama kotva necha sekciu tam, kde bola');
})();

// ===================== 5) deep-link v karte dielca ===========================

(function(){
  const PC = require(path.join(JS, 'part_card.js'));
  const on = PC.nxDecorLinkState('H3303_18');
  eq(on.enabled, true);
  eq(on.anchor, 'H3303_18', 'kotva je material dielca — ziadne hadanie dekoru v paneli');
  const off = PC.nxDecorLinkState('');
  eq(off.enabled, false, 'dielec bez rozhodnuteho materialu preklik nema');
  ok(off.title.indexOf('nemá') > -1, 'a povie DOVOD (D-78) — nie mlcanlivy mrtvy prvok');
})();

// ===================== 6) ⋯ editor riadku rozpoctu ===========================

const BUDGET = {
  sections: [
    { key: 'custom', rows: [
      { id: 'C1', nazov: 'Likvidácia starej kuchyne', kod: 'LIK', url: '', poznamka: 'do 3 dní' },
      { id: 'C2', nazov: 'Doprava', kod: '', url: '', poznamka: '' }
    ] },
    { key: 'appliances', rows: [
      { id: 'A1', nazov: 'Bosch SMV4HVX00E', url: 'https://demos.sk/x' }
    ] }
  ]
};

(function(){
  eq(B.budMoreFields('custom', BUDGET.sections[0].rows[0]).map(function(f){ return f.key; }),
     ['kod', 'url', 'poznamka'], 'vlastna polozka ma kod, adresu aj poznamku');
  eq(B.budMoreFields('appliance', BUDGET.sections[1].rows[0]).map(function(f){ return f.key; }),
     ['url'], 'spotrebic ma LEN adresu — kod ani poznamku jeho zaznam nenesie');
  eq(B.budMoreAttrs('custom', { kod: 'K', url: 'U', poznamka: 'P' }),
     { url: 'U', kod: 'K', poznamka: 'P' });
  eq(B.budMoreAttrs('appliance', { kod: 'K', url: 'U', poznamka: 'P' }), { url: 'U' },
     'zo spotrebica sa kod ani poznamka NEODOSIELAJU');
})();

(function(){
  global.ST = { gen: 11, model_guid: 'G1', budget: BUDGET };
  B.budOpenMore('custom', 'C1');
  ok(NXModal.isOpen(), '⋯ otvara D-15 modal (ziadny vlastny modalovy svet)');
  ok(DOC.querySelector('.nxscrim'), 'kostra kresli scrim komponentu');
  eq(DOC.getElementById('nxm_kod').value, 'LIK', 'polia su predvyplnene z PAYLOADU');
  eq(DOC.getElementById('nxm_poznamka').value, 'do 3 dní');
  ok(!DOC.querySelector('.mmemo'), 'editor existujuceho riadku NEMA pamat konceptu');

  DOC.getElementById('nxm_url').value = 'https://demos.sk/lik';
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 1, 'odoslalo sa presne raz');
  eq(SENT[0][0], 'budget_mutate');
  const p = SENT[0][1];
  eq(p.op, 'custom_update');
  eq(p.id, 'C1');
  eq(p.gen, 11, 'mutacia nesie generaciu okna');
  eq(p.attrs, { url: 'https://demos.sk/lik', kod: 'LIK', poznamka: 'do 3 dní' });
  ok(NXModal.isOpen(), 'zapis modal NEZATVARA — caka sa na potvrdenie servera');
  ok(NXModal.isBusy(), 'a zamok drzi (dvojity Enter = dva kroky Späť)');

  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT.length, 0, 'druhy klik pocas zapisu sa ZAHADZUJE');

  // ODMIETNUTY zapis: hodnoty ostavaju, tlacidlo ozije.
  NX.budgetResult('custom_update', false);
  ok(NXModal.isOpen(), 'odmietnutie NEZATVARA — pouzivatel opravuje svoje hodnoty');
  ok(!NXModal.isBusy(), 'a tlacidlo ozilo');
  eq(DOC.getElementById('nxm_url').value, 'https://demos.sk/lik', 'rozpisana hodnota je na mieste');

  // POTVRDENY zapis zatvara.
  NX.budgetResult('custom_update', true);
  ok(!NXModal.isOpen(), 'potvrdenie servera modal zatvara');
  repush();
})();

// Server po KAZDEJ mutacii posiela cerstvy payload — az ten uvolnuje frontu
// zapisov klienta (`budAfterPush`). Bez neho by dalsi zapis ostal visiet vo
// fronte, presne ako v okne.
function repush(){
  NX.setStudio({ gen: (global.ST.gen += 1), model_guid: 'G1', model_title: 'test',
                 version: '0', rows: [], budget: BUDGET });
}

(function(){
  // Editor NESMIE predvyplnat z konceptu: rozpisany a Escapom zavrety riadok
  // C1 sa nesmie objavit ani v C1, ani v inom riadku.
  B.budOpenMore('custom', 'C1');
  DOC.getElementById('nxm_kod').value = 'ROZPISANE';
  NXModal.close();
  B.budOpenMore('custom', 'C2');
  eq(DOC.getElementById('nxm_kod').value, '', 'iny riadok je CISTY (ziadna cudzia hodnota)');
  NXModal.close();
  B.budOpenMore('custom', 'C1');
  eq(DOC.getElementById('nxm_kod').value, 'LIK',
     'aj ten isty riadok sa plni z payloadu — koncept editora by bol pascou');
  ok(!DOC.querySelector('.mmemo'), 'a ziadny pas „predvyplnené z konceptu"');
  NXModal.close();
})();

(function(){
  // Spotrebic: iny op, iny tvar.
  B.budOpenMore('appliance', 'A1');
  ok(DOC.getElementById('nxm_kod') === null, 'spotrebic pole „Kód" vobec nema');
  eq(DOC.getElementById('nxm_url').value, 'https://demos.sk/x');
  SENT.length = 0;
  dispatch(DOC.querySelector('[data-nxm-act="submit"]'), 'click');
  eq(SENT[0][1].op, 'appliance_update');
  eq(SENT[0][1].attrs, { url: 'https://demos.sk/x' });
  NX.budgetResult('appliance_update', true);
  ok(!NXModal.isOpen());
  repush();

  // Neexistujuci riadok (payload sa medzitym zmenil) NEOTVARA prazdny formular.
  B.budOpenMore('custom', 'ZMAZANE');
  ok(!NXModal.isOpen(), 'zmazany riadok modal neotvara');
  ok(String(STATUS.textContent).indexOf('nenašla') > -1, 'a povie preco');
})();

console.log('OK test_st2d_kde.js — ' + n + ' kontrol');
