// ŠT-1c PR B2 — sekcia CENOVÁ PONUKA (Š14–Š15) + D-15 modal kostra.
//
// Preco `vm` a nie `require`: v prehliadaci su `nx_modal.js`, `studio.js`
// a `budget.js` TRI klasicke skripty v JEDNOM globalnom scope — budget.js cita
// globalny payload `ST` zo studio.js, obaluje `NX.setStudio` a modaly otvara
// cez globalne `NXModal`. `require` by kazdy subor izoloval a prave tieto
// vazby by NEOVERIL.
//
// Co to chyta (a ziadna ina sada to nechyti):
//   1. sekcia `offer` sa naozaj vykresli z REALNEHO tvaru payloadu — lista aj
//      telo (skupiny, per-riadok „samostatne", jantarovy guard, placeholder),
//   2. ZIVOTNY CYKLUS D-15 modalu: otvorenie s fokusom v prvom poli, zatvorenie
//      Escapom aj klikom vedla, navrat fokusu na spustac,
//   3. KONTRAKT #9: Escape Studia (ecMenu) sa NESMIE spustit, kym zije modal —
//      oba listenery visia na `document` a stopPropagation medzi nimi nefunguje,
//   4. #10: ODMIETNUTY zapis modal NEZATVARA a jeho hodnoty ostavaju,
//   5. `#budPrModal` (fazove okno prepoctu cien) komponent NEPREBERA.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const JS_DIR = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
let n = 0;
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// ============================ minimalny DOM stub =============================
// Nie je to prehliadac — je to presne tolko DOM, kolko tieto tri subory naozaj
// pouzivaju: id-cka, `innerHTML`, delegovane listenery, `closest` a fokus.

function mkNode(tag, attrs, owner){
  const node = {
    tagName: String(tag || 'DIV').toUpperCase(),
    attrs: Object.assign({}, attrs || {}),
    children: [], parent: null, _html: '', value: '', style: {},
    classList: { add(){}, remove(){}, toggle(){}, contains(){ return false; } },
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null; },
    setAttribute(k, v){ this.attrs[k] = String(v); },
    removeAttribute(k){ delete this.attrs[k]; },
    hasAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k); },
    get innerHTML(){ return this._html; },
    set innerHTML(v){ this._html = String(v == null ? '' : v); this.children = []; },
    appendChild(c){ c.parent = this; this.children.push(c); return c; },
    querySelector(){ return null; },
    querySelectorAll(){ return []; },
    scrollIntoView(){},
    focus(){ if (owner) owner.activeElement = this; },
    blur(){ if (owner && owner.activeElement === this) owner.activeElement = null; },
    // `closest` po skutocnych rodicoch (uzly si drzia `parent`).
    closest(sel){
      let cur = this;
      while (cur){
        if (matches(cur, sel)) return cur;
        cur = cur.parent;
      }
      return null;
    }
  };
  return node;
}

// Podporene selektory: `[attr]`, `[attr="v"]`, `.trieda`, `#id`, `tag`.
function matches(node, sel){
  const s = String(sel).trim();
  let m = s.match(/^\[([a-z-]+)(?:="([^"]*)")?\]$/);
  if (m) return m[2] === undefined ? node.hasAttribute(m[1]) : node.getAttribute(m[1]) === m[2];
  if (s[0] === '#') return node.attrs.id === s.slice(1);
  if (s[0] === '.') return String(node.attrs.class || '').split(/\s+/).indexOf(s.slice(1)) >= 0;
  return node.tagName === s.toUpperCase();
}

const els = {};
const listeners = { click: [], keydown: [], change: [], input: [], toggle: [] };
const doc = {
  activeElement: null,
  addEventListener(type, fn){ (listeners[type] || (listeners[type] = [])).push(fn); },
  getElementById(id){ return els[id] || null; },
  createElement(tag){ return mkNode(tag, {}, doc); },
  querySelector(){ return null; },
  querySelectorAll(){ return []; },
  body: null
};
doc.body = mkNode('body', {}, doc);
['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel', 'nxModalRoot'].forEach(function(id){
  els[id] = mkNode('div', { id: id }, doc);
  doc.body.appendChild(els[id]);
});
// `stopImmediatePropagation` MUSI stub podporovat — presne na nom stoji
// kontrakt „Escape patri modalu" (oba listenery visia na `document`, takze
// bezny `stopPropagation` medzi nimi nefunguje).
function fire(type, target, extra){
  const list = (listeners[type] || []).slice();
  let stopped = false;
  const ev = Object.assign({
    type: type, target: target, preventDefault(){}, stopPropagation(){},
    stopImmediatePropagation(){ stopped = true; }
  }, extra || {});
  for (let i = 0; i < list.length; i++){
    list[i](ev);
    if (stopped) break;
  }
}

const sent = [];   // vsetko, co islo do Ruby
const sandbox = {
  console: console, document: doc, setTimeout: function(){}, clearTimeout: function(){},
  localStorage: { getItem(){ return null; }, setItem(){} },
  module: undefined,
  NXEdgeMenu: { num(v){ return Number(v) || 0; }, menuHtml(){ return ''; },
                selectionHint(){ return ''; }, optionPayload(p){ return p; } },
  sketchup: {
    budget_mutate(p){ sent.push(['budget_mutate', JSON.parse(p)]); },
    cp_xlsx(p){ sent.push(['cp_xlsx', JSON.parse(p)]); },
    budget_xlsx(p){ sent.push(['budget_xlsx', JSON.parse(p)]); },
    refresh_bom(){ sent.push(['refresh_bom', null]); }
  }
};
sandbox.window = sandbox;
vm.createContext(sandbox);

// PORADIE JE SUCASTOU TESTU — presne ako ich nacitava studio.html.
['nx_modal.js', 'studio.js', 'budget.js'].forEach(function(f){
  vm.runInContext(fs.readFileSync(path.join(JS_DIR, f), 'utf8'), sandbox, { filename: f });
});

ok(typeof sandbox.NXModal === 'object' && sandbox.NXModal !== null,
   'D-15 kostra je globalny zdielany komponent (vzor NXEdgeMenu)');
ok(typeof sandbox.NX.setStudio === 'function', 'okno ma prijimac payloadu');
ok(typeof sandbox.studioGoSection === 'function', 'prepnutie sekcie je globalne');

// ============================ realny tvar payloadu ===========================
const CP = {
  consistent: true, complete: true, threshold: 300, total: 6813.9, total_label: 'SPOLU',
  rows: [
    { polozka: 'Kuchynská zostava podľa návrhu', cena: 6278.3, mnozstvo: 1, mj: 'ks', kind: 'assembly' },
    { polozka: 'Pracovná doska KOMPAKT 12 mm', cena: 535.6, mnozstvo: 1, mj: 'ks',
      kind: 'item', source_key: 'material:PD1' },
    { polozka: 'Zameranie a vizualizácie', cena: 0, mnozstvo: 1, mj: 'ks', kind: 'fixed' }
  ],
  candidates: [
    { source_key: 'material:PD1', label: 'Pracovná doska', amount: 535.6, state: 'samostatne' },
    { source_key: 'custom:U1', label: 'LED pás', amount: 85, state: 'zostava' }
  ]
};
const PAYLOAD = {
  version: '0.0.0', gen: 7, model_title: 'T', model_guid: 'G',
  rows: [], sheets: [], edging: [], hardware: [], hardware_sets: null,
  summary: {}, sheet_estimate: [], totals: {}, materials_meta: {}, edges_meta: {},
  vepo: { project: 'p', default_project: 'p', merge_18_36: true },
  control: [], counts: { red: 0, orange: 0, clean: 1 },
  edge_check: null, grain_check: null, open_section: 'offer', anchor: null,
  budget: {
    mode: 'standard', mode_label: '€€', vat_divisor: 1.23,
    totals: { total: 6813.9, total_novat: 5539.76, rounding: 6.1 },
    stale: { stale_days: 30, counts: {}, items: [] },
    budget_check: [],
    sections: [
      { key: 'custom', name: 'Vlastné položky', subtotal: 100,
        rows: [{ id: 'c1', nazov: 'Likvidácia', mnozstvo: 1, cena_mj: 100, spolu: 100 }] },
      { key: 'appliances', name: 'Spotrebiče', subtotal: 0, counts_in_total: false, included: false, rows: [] },
      { key: 'rounding', name: 'Zaokrúhlenie', subtotal: 6.1,
        rows: [{ poznamka: 'na celé desiatky nahor' }] }
    ],
    cp_preview: CP
  }
};

// --- 1) deep-link otvori rovno sekciu `offer` a vykresli ju -------------------
sandbox.NX.setStudio(PAYLOAD);
let tools = els.sectools.innerHTML;
let body = els.secbody.innerHTML;

ok(els.sechead.innerHTML.indexOf('Cenová ponuka') > -1, 'hlavicka pomenuje sekciu');
ok(tools.indexOf('data-bud="cp"') > -1, 'lista sekcie nesie export cenovej ponuky (presun z Rozpoctu)');
ok(tools.indexOf('id="refreshBtn"') > -1, 'a „Obnoviť" — ponuka nesmie ist zo starych rozmerov');
eq(tools.indexOf('data-bud="xlsx"'), -1, 'XLSX rozpoctu tu NIE JE (patri Rozpoctu)');
eq(tools.indexOf('data-bud="vat"'), -1,
   'ani prepinac DPH — ponuka je projekcia rozpoctu, nie druhe miesto na prepinanie');

ok(body.indexOf('Suma ponuky') > -1, 'telo nesie sumu ponuky');
// Oddelovac tisicov je NEZALOMITELNA medzera (U+00A0) — v teste explicitne.
ok(body.indexOf('6 813,90 €') > -1, 'suma je SERVEROVE cislo (JS nic neprepocitava)');
ok(body.indexOf('Položky dokumentu (rečou zákazníka)') > -1, 'polozky su recou zakaznika');
ok(body.indexOf('Kuchynská zostava podľa návrhu') > -1, 'riadok zostavy');
ok(body.indexOf('data-bud="cp_sep" data-source="material:PD1"') > -1,
   'per-riadok prepinac „samostatne" (Š14)');
ok(body.indexOf('Zaokrúhlenie ponuky') > -1, 'riadok zaokruhlenia');
ok(body.indexOf('Zlúčené v zostave (1)') > -1, 'zbaleny zoznam zlucenych polozek');
ok(body.indexOf('po V1 — vedomý placeholder') > -1 && body.indexOf('DOCX / PDF') > -1,
   'DOCX/PDF je PRIZNANY wireframe, nie mrtve tlacidlo');
ok(body.indexOf('CP = Rozpočet') > -1, 'zeleny pas: ponuka sedi s rozpoctom');

// --- 2) jantarovy guard s preklikom do Rozpoctu (Š15) ------------------------
(function(){
  const band = sandbox.budCpBand({ consistent: true, complete: false, unknown_count: 2 });
  const guard = sandbox.budOfferGuardHtml(band);
  ok(guard.indexOf('data-bud="to_budget"') > -1, 'podhodnotena ponuka VEDIE do Rozpoctu');
  ok(guard.indexOf('podhodnotená') > -1, 'a povie preco (2 riadky bez ceny)');
  ok(sandbox.budOfferGuardHtml({ ok: true, text: 'CP = Rozpočet' }).indexOf('bcpband ok') > -1,
     'ked sedi, je to pokojny zeleny pas — nie tlacidlo');
})();

// --- 3) prepinac „samostatne" = TA ISTA mutacia `cp_group` -------------------
(function(){
  sent.length = 0;
  const chk = mkNode('input', { 'data-bud': 'cp_sep', 'data-source': 'material:PD1' }, doc);
  chk.checked = false;
  fire('change', chk);
  eq(sent.length, 1, 'prepnutie poslalo PRESNE jednu mutaciu');
  eq(sent[0][1].op, 'cp_group', 'a je to `cp_group` (1 zmena = 1 krok Späť)');
  eq(sent[0][1].group, 'zostava', 'vypnute = zluc do zostavy');
  eq(sent[0][1].gen, 7, 'nesie generaciu okna (stary DOM server odmietne)');
  eq(sent[0][1].model_guid, 'G', 'aj identitu dokumentu');
  // Zapis drzi frontu (BUD_BUSY) az do prichodu CERSTVEHO payloadu — bez neho
  // by kazdy dalsi zapis v tejto sade skoncil vo fronte.
  sandbox.NX.setStudio(PAYLOAD);
  sent.length = 0;
  const chk2 = mkNode('input', { 'data-bud': 'cp_sep', 'data-source': 'custom:U1' }, doc);
  chk2.checked = true;
  fire('change', chk2);
  eq(sent.length, 1, 'po prichode cerstveho payloadu sa fronta uvolnila (dalsi zapis odisiel hned)');
  eq(sent[0][1].group, 'samostatne', 'zapnute = ukaz v ponuke samostatne');
  sandbox.NX.setStudio(PAYLOAD);
})();

// --- 4) preklik Rozpocet -> Ponuka a spat ------------------------------------
(function(){
  sandbox.studioGoSection('budget');
  const b = els.secbody.innerHTML;
  ok(b.indexOf('data-bud="offer"') > -1, 'v tele Rozpoctu ostal TENKY preklik do Ponuky');
  eq(b.indexOf('Cenová ponuka — náhľad'), -1, 'ale DRUHA kopia tabulky uz nie');
  const link = mkNode('button', { 'data-bud': 'offer' }, doc);
  fire('click', link);
  ok(els.secbody.innerHTML.indexOf('Položky dokumentu') > -1, 'klik prepol na sekciu Ponuka');
})();

// ===================== D-15 modal: kostra a zivotny cyklus ===================

// --- 5) cisty markup kostry (mhead / mbody / mfoot) --------------------------
(function(){
  const h = sandbox.NXModal.modalHtml({
    title: 'Pridať položku', sub: 'len táto zákazka', okLabel: 'Pridať',
    note: 'poznámka', fields: [{ key: 'popis', label: 'Popis', value: 'X' }]
  });
  ok(h.indexOf('class="nxscrim"') > -1, 'scrim je sucastou kostry (klik vedla zatvara)');
  ok(h.indexOf('class="mhead"') > -1 && h.indexOf('class="mbody"') > -1 &&
     h.indexOf('class="mfoot"') > -1, 'tri casti kostry podla mockupu');
  ok(h.indexOf('<h3>Pridať položku</h3>') > -1 && h.indexOf('class="msub"') > -1,
     'titulok aj podtitul');
  ok(h.indexOf('data-nxm-act="close"') > -1, 'krizik aj „Zrušiť" zatvaraju');
  ok(h.indexOf('class="primary" data-nxm-act="submit"') > -1,
     'potvrdenie je ZELENA primarna akcia (.primary = --nx-action)');
  ok(h.indexOf('id="nxm_popis"') > -1 && h.indexOf('data-nxm="popis"') > -1,
     'pole nesie kluc, podla ktoreho sa cita hodnota');
  // XSS: data do innerHTML idu VZDY escapovane.
  const x = sandbox.NXModal.modalHtml({ title: '<img src=x>', fields: [{ key: 'a', label: '<b>', value: '"' }] });
  ok(x.indexOf('&lt;img src=x&gt;') > -1 && x.indexOf('<img src=x>') === -1, 'titulok je escapovany');
  ok(x.indexOf('value="&quot;"') > -1, 'aj hodnota pola');
  // Select so zoznamom moznosti (spotrebice).
  const sel = sandbox.NXModal.fieldHtml({ key: 'typ', label: 'Typ', type: 'select', value: 'rura',
                                          options: [['rura', 'Rúra'], ['ine', 'Iné']] });
  ok(sel.indexOf('<option value="rura" selected>Rúra</option>') > -1, 'predvolena moznost je oznacena');
})();

// --- 5b) review #1: varovny pas patri AJ do PONUKY ---------------------------
// Export zakazníckeho dokumentu je od tejto davky JEDINE v tejto sekcii —
// keby chipy ostali len v Rozpocte, dala by sa ponuka poslat zakaznikovi zo
// starych cien bez toho, aby o tom okno cokolvek povedalo. Cisla su TIE ISTE
// (`budWarnChips`), meni sa LEN ciel kliku.
(function(){
  const WARN = {
    vat_divisor: 1.23,
    totals: { total: 100, total_novat: 81.3, appliances_subtotal: 649, appliances_included: false },
    stale: { stale_days: 30, counts: { stale: 3 },
             items: [{ kind: 'sheet', id: 'S1', label: 'H3303', state: 'stale', age_days: 44 }] },
    budget_check: [{ stable_key: 'budget|services|no_rate', section: 'services' }],
    sections: [], cp_preview: CP
  };
  const chips = sandbox.budWarnChips(WARN);
  eq(chips.length, 3, 'server hlasi tri druhy upozorneni (stare ceny, spotrebice, nalezy)');

  const h = sandbox.budOfferHtml(WARN, 1.23);
  ok(h.indexOf('3 ceny staršie ako 30 dní') > -1,
     'review #1: chip starych cien je AJ v ponuke (inak by dokument isiel z neaktualnych cien)');
  ok(h.indexOf('data-bud="to_budget" data-bkey="ostale"') > -1,
     'a vedie do Rozpoctu — tam je „Prepočítať ceny" (Š15: v ponuke sa needituje)');
  ok(h.indexOf('Spotrebiče') > -1 && h.indexOf('data-section="appliances"') > -1,
     'chip spotrebicov vedie rovno na ICH sekciu Rozpoctu');
  ok(h.indexOf('data-bud="ctrl" data-bkey="octrl"') > -1,
     'rozpoctove upozornenia vedu do KONTROLY — to iste miesto ako z Rozpoctu');

  // Ciste: ten isty chip v Rozpocte a v Ponuke nesie ROVNAKY TEXT (jedno cislo),
  // lisi sa iba akciou.
  const inBudget = sandbox.budChipHtml(chips[0], WARN, 1.23);
  const inOffer = sandbox.budOfferChipHtml(chips[0], WARN, 1.23);
  ok(inBudget.indexOf('3 ceny staršie ako 30 dní') > -1 &&
     inOffer.indexOf('3 ceny staršie ako 30 dní') > -1, 'rovnaky text v oboch sekciach');
  ok(inBudget.indexOf('data-bud="stale"') > -1 && inOffer.indexOf('data-bud="stale"') === -1,
     'v Rozpocte chip rozbaluje zoznam, v ponuke tam VEDIE (zoznam tu nie je)');
})();

// --- 6) polia oboch instancii (drafty rozpoctu) ------------------------------
(function(){
  // POZOR: pole zo sandboxu ma INY Array prototyp (vlastny vm kontext) —
  // porovnava sa preto retazec, nie objekt.
  const c = sandbox.budDraftFields('custom', null).map(function(f){ return f.key; }).join(',');
  eq(c, 'popis,pocet,cena', 'vlastna polozka: tie iste polia ako inline draft');
  eq(sandbox.budDraftFields('custom', null)[1].value, '1', 'pocet ma default 1');
  const a = sandbox.budDraftFields('appliance', null).map(function(f){ return f.key; }).join(',');
  eq(a, 'typ,nazov,dodavatel,cena', 'spotrebic: typ + nazov + dodavatel + cena');
  eq(sandbox.budDraftFields('appliance', null)[0].type, 'select', 'typ je ponuka, nie volny text');
  // Odmietnuty zapis: hodnoty sa vratia do poli.
  const back = sandbox.budDraftFields('custom', { popis: 'Likvidácia', pocet: '2', cena: 'abc' });
  eq(back[0].value, 'Likvidácia', 'zapamatany popis');
  eq(back[2].value, 'abc', 'aj chybna cena — pouzivatel ju ma OPRAVIT, nie pisat znova');
})();

// --- 7) otvorenie: fokus do prveho pola, spustac si pamatame -----------------
(function(){
  sandbox.studioGoSection('budget');
  const trigger = mkNode('button', { 'data-bud': 'draft', 'data-kind': 'custom' }, doc);
  doc.activeElement = trigger;
  // Prve pole musi vediet querySelector kotvy — stub ho vrati na poziadanie.
  const first = mkNode('input', { id: 'nxm_popis', 'data-nxm': 'popis' }, doc);
  const submitNode = mkNode('button', { 'data-nxm-act': 'submit' }, doc);
  els.nxModalRoot.querySelector = function(sel){
    if (sel.indexOf('.mbody') === 0) return first;
    if (sel.indexOf('[data-nxm-act="submit"]') === 0) return submitNode;
    return null;
  };
  fire('click', trigger);
  ok(sandbox.NXModal.isOpen(), 'klik na „Pridať položku" otvoril D-15 modal');
  ok(els.nxModalRoot.innerHTML.indexOf('class="nxscrim"') > -1, 'kostra sa vykreslila do kotvy');
  ok(els.nxModalRoot.innerHTML.indexOf('Pridať položku rozpočtu') > -1, 's titulkom pridavacky');
  eq(doc.activeElement, first, 'fokus je v PRVOM poli (kontrakt D-15)');
  ok(sandbox.nxModalOpen(), 'Studio vidi, ze modal zije');

  // --- 8) review #2: DVOJITE odoslanie sa ZAHADZUJE -------------------------
  // `sketchup.*` je asynchronne: druhy Enter by prvu mutaciu nepredbehol, ale
  // padol by do fronty klienta a odosla sa AZ s cerstvou generaciou — server
  // by ho PRIJAL a polozka by v rozpocte bola dvakrat (dva kroky Späť).
  sent.length = 0;
  first.value = 'Likvidácia';
  els.nxm_popis = first;
  const origGet = doc.getElementById;
  doc.getElementById = function(id){ return els[id] || null; };
  const submitBtn = mkNode('button', { 'data-nxm-act': 'submit' }, doc);
  fire('click', submitBtn);
  fire('click', submitBtn);                       // druhy klik hned za prvym
  fire('keydown', first, { key: 'Enter' });       // a este Enter v poli
  eq(sent.length, 1, 'review #2: tri pokusy = JEDNA mutacia (zamok drzi)');
  eq(sent[0][1].op, 'custom_add', 'a je to pridanie vlastnej polozky');
  eq(sent[0][1].attrs.popis, 'Likvidácia', 'so zadanym popisom');
  ok(sandbox.NXModal.isBusy(), 'modal je po odoslani ZAMKNUTY');
  ok(submitNode.hasAttribute('disabled'),
     'a potvrdzovacie tlacidlo zosedlo — beziaci zapis musi byt vidno');
  ok(sandbox.NXModal.isOpen(),
     'audit #10: modal po odoslani ZOSTAVA otvoreny — caka na potvrdenie servera');

  // --- 9) ODMIETNUTY zapis: nezatvara, ale ODOMYKA --------------------------
  sandbox.NX.budgetResult('custom_add', false);
  ok(sandbox.NXModal.isOpen(),
     'audit #10: odmietnuty zapis necha modal otvoreny (hodnoty ostanu na mieste)');
  eq(els.nxm_popis.value, 'Likvidácia', 'a rozpisana hodnota sa nestratila');
  ok(!sandbox.NXModal.isBusy(),
     'review #2: zamok sa pusta AJ v neuspesnej vetve — inak by sa uz nedalo odoslat');
  ok(!submitNode.hasAttribute('disabled'), 'tlacidlo ozilo');

  // Opravene cislo sa uz odoslat DA (dokaz, ze odomknutie nie je len priznak).
  sent.length = 0;
  sandbox.NX.setStudio(PAYLOAD); // uvolni frontu zapisov po odmietnutom kole
  fire('click', submitBtn);
  eq(sent.length, 1, 'po odomknuti sa opraveny zapis odosle');

  // --- 10) POTVRDENY zapis modal zatvara a vracia fokus na spustac -----------
  sandbox.NX.budgetResult('custom_add', true);
  ok(!sandbox.NXModal.isOpen(), 'uspesny zapis modal zavrie');
  eq(els.nxModalRoot.innerHTML, '', 'a kotva ostane prazdna');
  eq(doc.activeElement, trigger, 'fokus sa vratil na spustac (kontrakt D-15)');
  doc.getElementById = origGet;
  delete els.nxm_popis;
  sandbox.NX.setStudio(PAYLOAD);
})();

// --- 11) review #3+#4: rozpisane hodnoty prezijú Escape ---------------------
// Zatvorenie Escapom bolo dovtedy TICHA STRATA rozpisaneho riadku. Hodnoty sa
// pamataju PER DRUH pridavacky a najblizsie otvorenie ich predvyplni; zmaze
// ich az USPESNY zapis.
(function(){
  const origGet = doc.getElementById;
  const popis = mkNode('input', { id: 'nxm_popis', 'data-nxm': 'popis' }, doc);
  const pocet = mkNode('input', { id: 'nxm_pocet', 'data-nxm': 'pocet' }, doc);
  const cena = mkNode('input', { id: 'nxm_cena', 'data-nxm': 'cena' }, doc);
  els.nxm_popis = popis; els.nxm_pocet = pocet; els.nxm_cena = cena;
  doc.getElementById = function(id){ return els[id] || null; };
  els.nxModalRoot.querySelector = function(sel){ return sel.indexOf('.mbody') === 0 ? popis : null; };

  eq(sandbox.budDraftMemory('custom'), null, 'na zaciatku pamat prazdna');
  sandbox.budOpenDraft('custom');
  popis.value = 'Rozpísaná položka'; pocet.value = '2'; cena.value = '30';
  fire('click', mkNode('button', { 'data-nxm-act': 'submit' }, doc));
  sandbox.NX.budgetResult('custom_add', false);   // server odmietol
  sandbox.NX.setStudio(PAYLOAD);
  fire('keydown', popis, { key: 'Escape' });      // pouzivatel okno zavrel
  ok(!sandbox.NXModal.isOpen(), 'Escape modal zavrel');
  eq(sandbox.budDraftMemory('custom').popis, 'Rozpísaná položka',
     'review #3+#4: hodnoty prezili zatvorenie (uz to nie je ticha strata)');

  sandbox.budOpenDraft('custom');
  const fields = sandbox.budDraftFields('custom', sandbox.budDraftMemory('custom'));
  eq(fields[0].value, 'Rozpísaná položka', 'a dalsie otvorenie ich PREDVYPLNI');
  eq(fields[1].value, '2', 'vratane poctu');
  // Pamat je PER DRUH — spotrebic o vlastnej polozke nevie.
  eq(sandbox.budDraftMemory('appliance'), null, 'pamat spotrebica ostala prazdna');

  // Uspesny zapis pamat zmaze — dalsie „Pridať položku" zacina od nuly.
  sandbox.NX.budgetResult('custom_add', true);
  eq(sandbox.budDraftMemory('custom'), null, 'uspesny zapis pamat zahodi');
  doc.getElementById = origGet;
  delete els.nxm_popis; delete els.nxm_pocet; delete els.nxm_cena;
})();

// --- 12) klik na scrim zatvara, klik do karty nie ---------------------------
(function(){
  els.nxModalRoot.querySelector = function(){ return null; };
  sandbox.NXModal.open({ title: 'X', fields: [] });
  const scrim = mkNode('div', { 'data-nxm-scrim': '1' }, doc);
  fire('click', scrim);
  ok(!sandbox.NXModal.isOpen(), 'klik VEDLA karty (na scrim) modal zavrel');

  sandbox.NXModal.open({ title: 'X', fields: [] });
  const card = mkNode('div', { class: 'nxmcard' }, doc);
  const inside = mkNode('div', {}, doc);
  inside.parent = card;
  fire('click', inside);
  ok(sandbox.NXModal.isOpen(), 'klik do karty modal nezavrie');
  sandbox.NXModal.close();
})();

// --- 13) review #10: Escape patri modalu — BEHAVIORALNE ---------------------
// Oba listenery visia na `document`, takze o poradí rozhoduje poradie skriptov
// (`nx_modal.js` pred `studio.js`). Keby modal Escape nespotreboval, jedno
// stlacenie by zavrelo AJ rozbaľovacie nastavenie hrán v Štúdiu — a pouzivatel
// by prisiel o nastavenie, ktoreho sa ani nedotkol.
(function(){
  els.nxModalRoot.querySelector = function(){ return null; };
  sandbox.ecMenuOpen = true;
  sandbox.NXModal.open({ title: 'X', fields: [] });
  ok(sandbox.NXModal.isOpen() && sandbox.ecMenuOpen === true,
     'vychodisko: otvorene OBOJE — modal aj nastavenie hran');

  fire('keydown', mkNode('input', {}, doc), { key: 'Escape' });
  ok(!sandbox.NXModal.isOpen(), 'prvy Escape zavrel MODAL');
  eq(sandbox.ecMenuOpen, true,
     'review #10: a nastavenie hran OSTALO otvorene (Escape spotreboval modal)');

  fire('keydown', mkNode('input', {}, doc), { key: 'Escape' });
  eq(sandbox.ecMenuOpen, false, 'az DRUHY Escape zavrel nastavenie hran');
})();

// --- 14) review #7: fokus zostava v karte (Tab cykli) -----------------------
(function(){
  const a = mkNode('input', { id: 'nxm_a' }, doc);
  const b = mkNode('input', { id: 'nxm_b' }, doc);
  const c = mkNode('button', { 'data-nxm-act': 'submit' }, doc);
  const card = mkNode('div', { class: 'nxmcard' }, doc);
  card.querySelectorAll = function(){ return [a, b, c]; };
  els.nxModalRoot.querySelector = function(sel){ return sel === '.nxmcard' ? card : null; };
  sandbox.NXModal.open({ title: 'X', fields: [] });

  doc.activeElement = c;                                   // stojim na poslednom
  let prevented = false;
  fire('keydown', c, { key: 'Tab', shiftKey: false, preventDefault(){ prevented = true; } });
  ok(prevented, 'Tab z posledneho prvku sa zachyti');
  eq(doc.activeElement, a, 'a fokus skoci na PRVY prvok karty (necekne do okna za nou)');

  prevented = false;
  fire('keydown', a, { key: 'Tab', shiftKey: true, preventDefault(){ prevented = true; } });
  ok(prevented, 'Shift+Tab z prveho prvku sa zachyti');
  eq(doc.activeElement, c, 'a fokus skoci na POSLEDNY prvok karty');

  // Tab UPROSTRED zoznamu komponent nechava tak — prehliadac to zvladne sam.
  doc.activeElement = a;
  prevented = false;
  fire('keydown', a, { key: 'Tab', shiftKey: false, preventDefault(){ prevented = true; } });
  ok(!prevented, 'Tab medzi polami sa nezachytava (prirodzene poradie ostava)');
  sandbox.NXModal.close();
  els.nxModalRoot.querySelector = function(){ return null; };
})();

// --- 15) review #8: zoznam „Zlúčené v zostave" si pamata rozbalenie ---------
(function(){
  const closed = sandbox.budCpMergedHtml(CP, 1.23);
  ok(closed.indexOf('data-section="cp_merged"') > -1,
     'zoznam nesie kluc stavu (inak by sa po kazdom prepnuti sam zabalil)');
  ok(closed.indexOf('<details class="bcpmerged" data-section="cp_merged">') > -1,
     'standardne ZBALENY — vertikalny priestor je vzacny');
  // Po otvoreni pouzivatelom ostane otvoreny aj cez prekreslenie.
  const details = mkNode('details', { class: 'bcpmerged', 'data-section': 'cp_merged' }, doc);
  details.classList = { contains(cls){ return cls === 'bcpmerged'; } };
  details.open = true;
  fire('toggle', details);
  ok(sandbox.budCpMergedHtml(CP, 1.23).indexOf('data-section="cp_merged" open>') > -1,
     'review #8: po otvoreni ostava otvoreny — fokus na prepinaci „samostatne" ma kam sadnut');
})();

// --- 16) KONTRAKT #9: `#budPrModal` komponent NEPREBERA ---------------------
// Toto su ZDROJOVE guardy (grep), nie behaviorálne scenáre: fázové okno riadi
// server a jeho beh sa v Node stube simulovať nedá. Overuje sa presne to, čo
// grep vie — že sa cesty nikde nepretínajú.
(function(){
  const src = fs.readFileSync(path.join(JS_DIR, 'budget.js'), 'utf8');
  const pr = src.slice(src.indexOf('function budPrModalHtml'), src.indexOf('function budPrStart'));
  ok(pr.indexOf('budPrModal') > -1, 'fazove okno prepoctu cien si kresli vlastny markup');
  ok(pr.indexOf('NXModal') === -1,
     'audit #9: `#budPrModal` NEIDE cez zdielanu kostru (vo faze `run` sa Escapom zavriet NESMIE)');
  const modalSrc = fs.readFileSync(path.join(JS_DIR, 'nx_modal.js'), 'utf8');
  // Komponent ho smie SPOMENUT (kontrakt v hlavicke to musi povedat nahlas),
  // ale nesmie sa ho dotknut — kazdy jeho vyskyt je KOMENTAR.
  ok(modalSrc.split('\n').filter(function(l){ return l.indexOf('budPrModal') > -1; })
       .every(function(l){ return l.trim().indexOf('//') === 0; }),
     'komponent sa `#budPrModal` nikde nedotyka (spomina ho len kontrakt v komentari)');
  // Druha poistka poradia listenerov (prva je behaviorálny scenár vyššie).
  // SMOKE 1A: rohove nastavenia su od tejto davky DVE (kontrola hran + VEPO),
  // takze podmienka uz nie je pribalena k jednemu z nich — je to JEDNA branka
  // na zaciatku Escape vetvy. Poradie musi ostat MODAL > menu.
  const studioSrc = fs.readFileSync(path.join(JS_DIR, 'studio.js'), 'utf8');
  ok(studioSrc.indexOf("if (ev.key !== 'Escape' || nxModalOpen()) return;") > -1,
     'Studio ma NAVYSE podmienku „ziadny modal otvoreny" (poistka pre opacne poradie skriptov)');
  const escIdx = studioSrc.indexOf("if (ev.key !== 'Escape' || nxModalOpen()) return;");
  const esc = studioSrc.slice(escIdx);
  ok(esc.indexOf('if (ecMenuOpen){') > -1 && esc.indexOf('if (vepoMenuOpen){') > -1,
     'obe rohove nastavenia Escape ZATVARA (ziadne nesmie ostat visiet)');
  ok(esc.indexOf('if (ecMenuOpen){') < esc.indexOf('if (vepoMenuOpen){'),
     'a obe su AZ ZA modalovou brankou — modal ma prednost');
})();

console.log('test_st1c_ponuka.js: ' + n + ' OK');
