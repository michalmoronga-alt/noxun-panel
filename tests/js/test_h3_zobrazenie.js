// H3a (blok 9 HARDENING) — zavádzajúce údaje v okne Štúdia: KLIENT.
//
// Čo táto sada stráži (a prečo to klikaním neoveríš):
//   1. KONTROLA — zelený chip má menovateľ s predložkou z/zo („0 zo 7 skriniek"),
//      oranžový povie počet RIADKOV zoznamu („10 nálezov v 5 riadkoch") a ten
//      počet sedí s tým, čo `ctrlListHtml` naozaj nakreslí (parita). Veta lišty
//      „Vypnuté — v modeli nie je nič nakreslené." len keď je vypnuté všetko.
//   2. NÁKUP KOVANIA — SK nadpisy kategórií (surový `ZAVESY` nikde), ľudské
//      parametre, zlúčený stĺpec „Kde" zo servera, fallbacky starého payloadu.
//   3. CENOVÁ PONUKA — poradie Položka · Množstvo · MJ · Spolu, „v cene" LEN pri
//      fixnej nule (nikdy pri `info` ani neznámej cene), rámik DOCX/PDF preč.
//   4. KUSOVNÍK — súčtový riadok (Dielce aj Platne) nepíše súčet platní cez
//      materiály; je tam preklik do Nárezového plánu, ktorý naozaj prepne sekciu.
//   5. NASTAVENIA ROZPOČTU — sivé číslo v prázdnej bunke režimu je SERVEROVÉ
//      `effective` (nie bunka Základ), nie je to hodnota (uloženie nič nepošle),
//      hlavičky idú v poradí `modes`.
'use strict';
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, `${msg}: cakam ${JSON.stringify(b)}, dostal ${JSON.stringify(a)}`); }
function ok(c, msg){ n++; assert.ok(c, msg); }
function no(c, msg){ n++; assert.ok(!c, msg); }

// budget.js sa musí načítať PRED `global.window` (inak by sa v Node pokúsil
// obaliť `NX.setStudio`, ktoré tu ešte neexistuje).
const B = require(path.join(JS, 'budget.js'));

// --- DOM stub pre studio.js + studio_settings.js (vzor test_st4a_settings.js) --
const ELS = {};
function stubEl(id){
  const nd = { id, style: {}, children: [], _html: '', _attrs: {}, value: '', className: '' };
  Object.defineProperty(nd, 'innerHTML', { get(){ return nd._html; }, set(v){ nd._html = v; nd.children = []; } });
  Object.defineProperty(nd, 'textContent', { get(){ return nd._text || ''; }, set(v){ nd._text = v; } });
  nd.appendChild = function(c){ nd.children.push(c); return c; };
  nd.setAttribute = function(k, v){ nd._attrs[k] = String(v); };
  nd.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(nd._attrs, k) ? nd._attrs[k] : null; };
  nd.querySelector = function(){ return null; };
  nd.querySelectorAll = function(){ return []; };
  nd.classList = { toggle: function(){} };
  return nd;
}
['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio'].forEach(function(id){ ELS[id] = stubEl(id); });
const SENT = [];
global.window = {
  sketchup: new Proxy({}, {
    get(_t, name){ return typeof name === 'string' ? function(p){ SENT.push([name, p]); } : undefined; },
    has(){ return true; }
  })
};
global.sketchup = global.window.sketchup;
const LISTEN = { input: [], click: [], focusin: [] };
global.document = {
  activeElement: null,
  addEventListener: function(type, fn){ (LISTEN[type] || (LISTEN[type] = [])).push(fn); },
  getElementById: function(id){ return ELS[id] || null; },
  createElement: function(tag){ return stubEl('new-' + tag); },
  querySelector: function(){ return null; },
  querySelectorAll: function(){ return []; }
};
const S = require(path.join(JS, 'studio.js'));
global.NX = global.window.NX;
require(path.join(JS, 'about.js'));
const T = require(path.join(JS, 'studio_settings.js'));
global.ssRenderBody = T.ssRenderBody;
global.ssRenderTools = T.ssRenderTools;

// ============================ 1) KONTROLA ===================================

(function(){
  const want = { 1: 'z', 2: 'z', 4: 'zo', 5: 'z', 6: 'zo', 7: 'zo', 8: 'z', 10: 'z', 14: 'zo', 16: 'zo',
                 17: 'zo', 18: 'z', 20: 'z', 40: 'zo', 47: 'zo', 60: 'zo', 70: 'zo', 79: 'zo', 80: 'z',
                 100: 'zo', 150: 'zo', 200: 'z', 400: 'zo', 700: 'zo', 1000: 'z' };
  Object.keys(want).forEach(function(k){ eq(S.skZo(Number(k)), want[k], `skZo(${k})`); });
})();

(function(){
  const green = function(c){
    const h = S.semaforHtml(c, 'all');
    const m = h.match(/<div class="schip s-green"[^>]*><span class="dot"><\/span><span><span class="n">([^<]*)<\/span> <span class="t">([^<]*)<\/span>/);
    return m ? m[1] + ' ' + m[2] : null;
  };
  eq(green({ red: 0, orange: 0, cabinets: 7, clean: 0 }), '0 zo 7 skriniek bez nálezu', 'menovateľ so „zo"');
  eq(green({ red: 0, orange: 0, cabinets: 5, clean: 3 }), '3 z 5 skriniek bez nálezu', 'menovateľ so „z"');
  eq(green({ red: 0, orange: 0, cabinets: 1, clean: 1 }), '1 z 1 skrinky bez nálezu', 'jedna skrinka = „skrinky"');
  eq(green({ red: 0, orange: 0, cabinets: 0, clean: 0 }), '0 skriniek v modeli', 'prázdny model');
  eq(green({ red: 0, orange: 0, clean: 4 }), '4 skriniek bez nálezu', 'bez cabinets = dnešný tvar');
  eq(green({ red: 0, orange: 0, cabinets: 7, clean: null }), '— skriniek bez nálezu', 'clean null = pomlčka');
  ok(S.semaforHtml({ cabinets: 7, clean: 0 }, 'all').indexOf('z celkového počtu skriniek v modeli') >= 0,
     'tooltip zeleného chipu hovorí o menovateli');
})();

const UNI = function(i){ return { severity: 'orange', category: 'uni_material', owner_id: 'CAB-' + i, message_sk: 'UNI ' + i }; };
const LIST10 = [UNI(1), UNI(2), UNI(3), UNI(4), UNI(5), UNI(6),
                { severity: 'orange', category: 'budget', message_sk: 'r1' },
                { severity: 'orange', category: 'budget', message_sk: 'r2' },
                { severity: 'orange', category: 'budget', message_sk: 'r3' },
                { severity: 'orange', category: 'hardware', owner_id: 'CAB-9', message_sk: 'h' },
                { severity: 'red', category: 'material', owner_id: 'CAB-1', message_sk: 'red' }];

(function(){
  const orange = function(c, list){
    const h = S.semaforHtml(c, 'all', list);
    const m = h.match(/data-sev="orange"[^>]*><span class="dot"><\/span><span><span class="n">([^<]*)<\/span> <span class="t">([^<]*)<\/span>/);
    return m ? m[1] + ' ' + m[2] : null;
  };
  eq(orange({ red: 1, orange: 10 }, LIST10), '10 nálezov v 5 riadkoch · skontroluj pred objednávkou',
     '6 UNI + 3 rozpočet + 1 iný = 5 riadkov');
  const noUni = LIST10.filter(function(it){ return it.category !== 'uni_material'; });
  eq(orange({ red: 1, orange: 4 }, noUni), '4 nálezy · skontroluj pred objednávkou', 'bez UNI skupiny riadky = nálezy → bez „v … riadkoch"');
  eq(orange({ orange: 1 }, [noUni[0]]), '1 nález · skontroluj pred objednávkou', 'jeden nález');
  eq(orange({ orange: 10 }), '10 nálezov · skontroluj pred objednávkou', 'bez zoznamu sa počet riadkov nepíše');
  eq(orange({ orange: 7 }, [UNI(1), UNI(2), UNI(3), UNI(4), UNI(5), UNI(6), noUni[0]]),
     '7 nálezov v 2 riadkoch · skontroluj pred objednávkou', 'jedna skupina = jeden riadok');
  eq(S.ctrlOrangeRowCount([UNI(1)]), 1, 'jeden UNI nález = jeden riadok skupiny');
  eq(S.ctrlOrangeRowCount([]), 0, 'prázdny zoznam');
  eq(S.ctrlOrangeRowCount(LIST10.concat([{ severity: 'red', category: 'uni_material' }])), 5,
     'červené sa nepočítajú (ani červený UNI)');

  // PARITA: počet oranžových riadkov NAJVYŠŠEJ úrovne, ktoré naozaj nakreslí
  // `ctrlListHtml`, = `ctrlOrangeRowCount`. Počíta sa vnorením <div>.
  function topLevelOrange(html){
    const re = /<div\b[^>]*>|<\/div>/g;
    let depth = 0, count = 0, mm;
    while ((mm = re.exec(html))){
      if (mm[0] === '</div>'){ depth--; continue; }
      if (depth === 0 && /class="(ctrlrow ctrl-orange|ctrluni)"/.test(mm[0])) count++;
      depth++;
    }
    return count;
  }
  [LIST10, noUni, [UNI(1)], [UNI(1), noUni[0], UNI(2)], []].forEach(function(list, i){
    const html = S.ctrlListHtml(S.ctrlRows(list, 'all'), false);
    eq(topLevelOrange(html), S.ctrlOrangeRowCount(list), `parita počtu riadkov s ctrlListHtml (#${i})`);
    const htmlOpen = S.ctrlListHtml(S.ctrlRows(list, 'all'), true);
    eq(topLevelOrange(htmlOpen), S.ctrlOrangeRowCount(list), `parita aj pri rozbalenej skupine (#${i})`);
  });
  ok(S.ctrlUniGrouped(UNI(1)) && !S.ctrlUniGrouped({ severity: 'red', category: 'uni_material' }),
     'zdieľaný predikát UNI skupiny');
})();

(function(){
  const EDGE_ON = { available: true, active: true, options: { show_missing: true }, counts: { missing: 3 } };
  const EDGE_OFF = { available: true, active: false, options: { show_missing: true } };
  const GRAIN_ON = { available: true, active: true, parts: 12 };
  const GRAIN_OFF = { available: true, active: false };
  const DIR_ON = { available: true, active: true, wings: 0, legacy: 1 };
  const DIR_OFF = { available: true, active: false };
  const info = function(bar){ const m = bar.match(/<span class="ecinfo">([\s\S]*)<\/span>$/); return m ? m[1] : null; };
  const VYP = 'Vypnuté — v modeli nie je nič nakreslené.';

  eq(info(S.edgeCheckBarHtml(EDGE_OFF, false, GRAIN_OFF, DIR_OFF)), VYP, 'všetko vypnuté = veta o prázdnom modeli');
  const onlyDir = info(S.edgeCheckBarHtml(EDGE_OFF, false, GRAIN_OFF, DIR_ON));
  eq(onlyDir, '<span class="dcinfo">0 krídel · 1 bez smeru (staršie čelá)</span>', 'len smer otvárania: bez vety a bez úvodného „ · "');
  no(onlyDir.indexOf('Vypnuté') >= 0, 'veta „Vypnuté" pri zapnutom smere otvárania nie je');
  eq(info(S.edgeCheckBarHtml(EDGE_OFF, false, GRAIN_ON, DIR_OFF)), '<span class="gcinfo">12 dielcov s kresbou</span>',
     'len kresba');
  eq(info(S.edgeCheckBarHtml(EDGE_ON, false, GRAIN_OFF, DIR_ON)),
     '3 hrany bez olepu · <span class="dcinfo">0 krídel · 1 bez smeru (staršie čelá)</span>', 'hrany + smer');
  eq(info(S.edgeCheckBarHtml(EDGE_ON, false)), '3 hrany bez olepu', 'len hrany (bez stavov kresby a smeru)');
  ok(S.edgeCheckBarHtml({ available: false }, false, GRAIN_ON, DIR_ON).indexOf('class="ecoff"') >= 0,
     'nedostupné = ecoff bez zmeny');
  eq(S.edgeCheckText({ available: true, active: false }), VYP, 'edgeCheckText sa nemení (D-104)');
})();

// ============================ 2) NÁKUP KOVANIA ==============================

(function(){
  const HS = {
    state_status: 'ok',
    rows: [
      { code: '104717', name_sk: 'Záves', category: 'ZAVESY', category_label: 'Závesy', quantity: 2, unit: 'ks',
        price_eur_vat: 4.18, subtotal_eur_vat: 8.36 },
      { code: '93240', name_sk: 'Uholník', category: 'SPOJOVACI_MATERIAL', category_label: 'Spojovací materiál',
        quantity: 6, unit: 'ks', price_eur_vat: 0.37, subtotal_eur_vat: 2.22 },
      { code: 'XX', missing: true, category: 'NOHY', quantity: 1, unit: 'ks' }
    ],
    unmapped: [{ generic_type: 'hinge', label: 'Závesy', cabinet_id: 'CAB-2', owner_part_key: 'f1', quantity: 1,
                 reason_sk: 'bez setu' }],
    summary: { total_eur_vat: 10.58 }
  };
  const HW = [
    { key: 'S1', generic_type: 'slide', label: 'Výsuv', quantity: 2,
      params: { nominal_length: 470, front_height: 302 }, params_label: null,
      params_text: 'NL 470 mm · výška čela 302 mm',
      breakdown: [{ owner_id: 'CAB-003', quantity: 1, source: 'rule' }, { owner_id: 'CAB-003', quantity: 1, source: 'rule' }],
      where: [{ owner_id: 'CAB-003', quantity: 2, manual: false, manual_note: null }] },
    { key: 'S2', generic_type: 'slide', label: 'Výsuv', quantity: 2, params: {}, params_text: null,
      breakdown: [], where: [{ owner_id: 'CAB-2', quantity: 2, manual: true, manual_note: 'ručne (automat: 470 mm)' }] }
  ];
  const H = S.buySection(HS, HW);
  ok(H.indexOf('<td colspan="6">Závesy</td>') >= 0, 'nadpis skupiny = SK popisok');
  ok(H.indexOf('<td colspan="6">Spojovací materiál</td>') >= 0, 'aj pre spojovací materiál');
  no(H.indexOf('ZAVESY') >= 0 || H.indexOf('SPOJOVACI_MATERIAL') >= 0, 'surový kód kategórie v okne nie je');
  ok(H.indexOf('<td colspan="6">Mimo katalógu</td>') >= 0, 'missing = „Mimo katalógu"');
  ok(H.indexOf('NL 470 mm · výška čela 302 mm') >= 0, 'params_text zo servera');
  no(H.indexOf('nominal_length') >= 0, 'surové kľúče sa pri params_text nevypisujú');
  ok(H.indexOf('<td>CAB-003 ×2</td>') >= 0, 'where = zlúčený pôvod „CAB-003 ×2"');
  no(H.indexOf('CAB-003 ×1') >= 0, 'nie dva záznamy');
  ok(H.indexOf('<span title="ručne (automat: 470 mm)">CAB-2 ×2 (ručne)</span>') >= 0, 'ručný pôvod + tooltip');
  ok(H.indexOf('<tr class="hwmiss"><td>Závesy</td>') >= 0, 'nemapovaná položka má SK typ');

  // starý payload (bez category_label, params_text, where, label)
  const OLD = JSON.parse(JSON.stringify(HS));
  OLD.rows.forEach(function(r){ delete r.category_label; });
  delete OLD.unmapped[0].label;
  const OLDHW = [{ key: 'H1', generic_type: 'hinge', label: 'Závesy', quantity: 4, params: { use_type: 'door' },
                   breakdown: [{ owner_id: 'CAB-7', quantity: 2, source: 'rule' }, { owner_id: 'CAB-7', quantity: 2 }] }];
  const O = S.buySection(OLD, OLDHW);
  ok(O.indexOf('<td colspan="6">ZAVESY</td>') >= 0, 'starý payload bez popisku ukáže kód ako doteraz');
  ok(O.indexOf('use_type door') >= 0, 'starý payload: surové parametre');
  ok(O.indexOf('CAB-7 ×2, CAB-7 ×2') >= 0, 'starý payload: breakdown so zápisom „ ×"');
  ok(O.indexOf('<tr class="hwmiss"><td>hinge</td>') >= 0, 'starý payload: surový typ nemapovanej');
  const PL = S.buySection(OLD, [{ key: 'P', generic_type: 'handle', quantity: 1, params: { cut_length_mm: 597 },
                                  params_label: 'rez 597 mm', breakdown: [] }]);
  ok(PL.indexOf('rez 597 mm') >= 0 && PL.indexOf('cut_length_mm') < 0, 'bez params_text ide params_label');
  ok(S.buySection(OLD, [{ key: 'E', generic_type: 'x', quantity: 1, params: {}, breakdown: [] }]).indexOf('<td>—</td>') >= 0,
     'bez parametrov pomlčka');
})();

// ============================ 3) CENOVÁ PONUKA ==============================

(function(){
  const CP = { total: 587.24, total_label: 'SPOLU', rows: [
    { polozka: 'Nábytková zostava', cena: 415.68, mnozstvo: 1, mj: 'set', kind: 'assembly' },
    { polozka: 'Atira', cena: 171.56, mnozstvo: 4, mj: 'set', kind: 'item', source_key: 'hw:A' },
    { polozka: 'Zameranie', cena: 0, mnozstvo: 1, mj: 'set', kind: 'fixed' },
    { polozka: 'Montáž', cena: 120, mnozstvo: 1, mj: 'set', kind: 'fixed' },
    { polozka: 'Rúra (dodáva zákazník)', cena: 0, mnozstvo: 1, mj: 'ks', kind: 'info', source_key: 'appl:R' },
    { polozka: 'Zostava 0', cena: 0, mnozstvo: 1, mj: 'set', kind: 'assembly' },
    { polozka: 'Neznáma', cena: null, mnozstvo: 1, mj: 'ks', kind: 'fixed' }
  ] };
  const h = B.budCpTableHtml(CP, 1.23);
  const heads = (h.match(/<th[^>]*>[^<]*<\/th>/g) || []).map(function(t){ return t.replace(/<[^>]+>/g, ''); });
  eq(heads, ['Položka', 'Množstvo', 'MJ', 'Spolu', 'V ponuke'], 'poradie stĺpcov ako faktúra');
  ok(h.indexOf('title="Suma za celý riadok, nie cena za kus"') >= 0, '„Spolu" vysvetľuje, že je to suma riadku');
  const row = function(name){
    const m = h.match(new RegExp('<td>' + name.replace(/[()]/g, '\\$&') + '</td>((?:<td[^>]*>.*?</td>){4})</tr>'));
    return m ? m[1].replace(/<label[\s\S]*<\/label>/, '[sep]').replace(/<[^>]+>/g, '|').replace(/\|+/g, '|') : null;
  };
  eq(row('Atira'), '|4|set|171,56 €|[sep]|', '„4 · set · 171,56 €"');
  eq(row('Zameranie'), '|1|set|v cene|—|', 'fixná nula = „v cene"');
  eq(row('Montáž'), '|1|set|120,00 €|—|', 'fixná nenulová = suma');
  eq(row('Rúra (dodáva zákazník)'), '|1|ks|0,00 €|[sep]|', 'info nula = „0,00 €" (nie naša služba)');
  eq(row('Zostava 0'), '|1|set|0,00 €|—|', 'assembly nula = „0,00 €"');
  eq(row('Neznáma'), '|1|ks|—|—|', 'neznáma cena = „—" (nikdy 0 ani „v cene")');
  ok(h.indexOf('<tr class="bcptotal"><td>SPOLU</td><td></td><td></td><td class="bnum">587,24 €</td><td></td></tr>') >= 0,
     'SPOLU vo 4. stĺpci');
  eq(B.budCpAmountHtml({ kind: 'fixed', cena: 0.004 }, 1), '<span class="bfnt">v cene</span>', 'pod pol centa = v cene');
  eq(B.budCpAmountHtml({ kind: 'fixed', cena: '' }, 1), '—', 'prázdny reťazec nie je nula');
  no(typeof B.budOfferWireHtml === 'function', 'rámik DOCX/PDF zanikol');
  const src = fs.readFileSync(path.join(JS, 'budget.js'), 'utf8');
  no(src.indexOf('vedomý placeholder') >= 0 || src.indexOf('bwire') >= 0, 'ani jeho text a trieda');
  const html = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');
  no(html.indexOf('.bwire') >= 0, 'CSS rámika zaniklo');
  ok(src.indexOf('Zameranie a Vizualizácie sú v ponuke vždy „v cene" (náklad je rozpustený v zostave; v XLSX ponuky majú 0 €).') >= 0,
     'poznámka priznáva rozdiel okna a XLSX');
})();

// ============================ 4) NASTAVENIA ROZPOČTU ========================

(function(){
  const STATE = {
    version: '9.9.9', revision: 'r-1',
    supplier: { name: 'Demos', rates: { montaz: 12 }, mode_values: { montaz: { nizky: 9 } },
                stale_days: 30, rounding_step: 5, abs_reserve_pct: 10, montaz_m2_per_plate: 3,
                cp_highlight_threshold: 100 },
    modes: ['vysoky', 'nizky', 'standard'],
    mode_labels: { nizky: 'Nízky', standard: 'Štandard', vysoky: 'Vysoký' },
    rate_keys: ['montaz', 'porez'],
    rate_labels: { montaz: ['Montáž', '€/m²'], porez: ['Porez', '€/platňa'] },
    standard_rows: [{ key: 'doprava', name: 'Doprava', rate: 30, kind: 'fix' }],
    // Zámerne INÉ čísla než bunka Základ: porez nemá základ v súbore → seed 17.
    effective: { rates: { montaz: { nizky: 9, standard: 12, vysoky: 12 },
                          porez: { nizky: 17, standard: 17, vysoky: 17 } },
                 rows: { doprava: { nizky: 30, standard: 30, vysoky: 30 } } },
    path: 'C:\\x.json', demos: {}, about: { version: '9.9.9', dir: 'C:\\x' }
  };
  function walk(node, out){ (node.children || []).forEach(function(c){ out.push(c); walk(c, out); }); return out; }
  S.setStudioSection('bset');
  T.ssApplyState(STATE);
  T.SS.saved();
  T.ssRenderBody();
  const all = walk(ELS.secbody, []);
  const inp = function(k){ return all.filter(function(x){ return x.getAttribute && x.getAttribute('data-ss') === k; })[0]; };
  eq(inp('mode:porez:standard').getAttribute('placeholder'), '17', 'prázdna bunka: sivé číslo = effective (seed), nie prázdny Základ');
  eq(inp('mode:porez:standard').value, '', 'placeholder NIE JE hodnota');
  eq(inp('mode:porez:standard').getAttribute('title'), 'Prázdne — platí základ (17)', 'tooltip');
  eq(inp('mode:montaz:vysoky').getAttribute('placeholder'), '12', 'montáž €€€ = základ 12');
  eq(inp('mode:montaz:nizky').getAttribute('placeholder'), null, 'vyplnená bunka placeholder nemá');
  eq(inp('mode:montaz:nizky').value, '9', 'a drží svoju hodnotu');
  eq(inp('mode:doprava:nizky').getAttribute('placeholder'), '30', 'aj štandardné riadky');
  eq(inp('rate:porez').value, '', 'bunka Základ ostáva prázdna (sivé číslo nie je odtiaľ)');

  const heads = all.filter(function(x){ return x.id === 'new-th'; }).map(function(x){ return x.textContent; });
  eq(heads.slice(0, 6), ['Položka', 'Základ', '€€€ vysoký', '€ nízky', '€€ štandard', ''],
     'hlavičky v poradí `modes` (rovnako ako bunky)');
  const cellOrder = all.filter(function(x){ return /^mode:montaz:/.test(x.getAttribute && x.getAttribute('data-ss') || ''); })
    .map(function(x){ return x.getAttribute('data-ss').split(':')[2]; });
  eq(cellOrder, ['vysoky', 'nizky', 'standard'], 'bunky idú v tom istom poradí');

  SENT.length = 0;
  T.ssSave();
  eq(SENT.length, 0, 'uloženie bez písania nepošle nič (placeholder sa neukladá)');
  eq(T.ssBuildPatch(T.ssDirtyMap()).patch, {}, 'patch je prázdny');

  const hint = all.filter(function(x){ return x.className === 'sshint'; }).map(function(x){ return x.textContent; })[0];
  ok(hint.indexOf('Stĺpce € nízky · €€ štandard · €€€ vysoký sú sadzby pre cenový režim zákazky; ' +
     'v prázdnej bunke platí základ — ukazuje ho sivé číslo.') >= 0, 'nápoveda fieldsetu');
  ok(hint.indexOf('Sivé číslo ukazuje uložený základ — po zmene Základu sa obnoví až po Uložiť.') >= 0,
     'nápoveda priznáva, že sivé číslo je uložená sadzba (predrecenzia P3)');

  // starý payload bez `effective` — žiadne sivé číslo, žiadna chyba
  const OLD = JSON.parse(JSON.stringify(STATE));
  delete OLD.effective;
  OLD.modes = ['nizky', 'standard', 'vysoky'];
  T.ssApplyState(OLD);
  T.ssRenderBody();
  const all2 = walk(ELS.secbody, []);
  const p2 = all2.filter(function(x){ return x.getAttribute && x.getAttribute('data-ss') === 'mode:porez:standard'; })[0];
  eq(p2.getAttribute('placeholder'), null, 'bez effective placeholder nie je');
  const heads2 = all2.filter(function(x){ return x.id === 'new-th'; }).map(function(x){ return x.textContent; });
  eq(heads2.slice(0, 5), ['Položka', 'Základ', '€ nízky', '€€ štandard', '€€€ vysoký'], 'hlavičky „€ nízky · €€ štandard · €€€ vysoký"');
  S.setStudioSection('bom');
})();

// ============================ 5) KUSOVNÍK (vm sandbox) ======================
// Rovnaký vzor ako test_st1c_ponuka.js: studio.js + budget.js v JEDNOM scope,
// payload cez `NX.setStudio`, klik cez delegovaný listener na `document`.

(function(){
  function mkNode(tag, attrs){
    const node = {
      tagName: String(tag || 'DIV').toUpperCase(), attrs: Object.assign({}, attrs || {}),
      children: [], parent: null, _html: '', value: '', style: {},
      classList: { add(){}, remove(){}, toggle(){}, contains(){ return false; } },
      getAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null; },
      setAttribute(k, v){ this.attrs[k] = String(v); },
      removeAttribute(k){ delete this.attrs[k]; },
      hasAttribute(k){ return Object.prototype.hasOwnProperty.call(this.attrs, k); },
      get innerHTML(){ return this._html; },
      set innerHTML(v){ this._html = String(v == null ? '' : v); this.children = []; },
      appendChild(c){ c.parent = this; this.children.push(c); return c; },
      querySelector(){ return null; }, querySelectorAll(){ return []; },
      scrollIntoView(){}, focus(){}, blur(){},
      closest(sel){
        let cur = this;
        while (cur){
          const m = String(sel).match(/^\[([a-z-]+)(?:="([^"]*)")?\]$/);
          if (m && (m[2] === undefined ? cur.hasAttribute(m[1]) : cur.getAttribute(m[1]) === m[2])) return cur;
          cur = cur.parent;
        }
        return null;
      }
    };
    return node;
  }
  const els = {};
  const listeners = {};
  const doc = {
    activeElement: null,
    addEventListener(type, fn){ (listeners[type] || (listeners[type] = [])).push(fn); },
    getElementById(id){ return els[id] || null; },
    createElement(tag){ return mkNode(tag); },
    querySelector(){ return null; }, querySelectorAll(){ return []; }
  };
  doc.body = mkNode('body');
  ['snav', 'sechead', 'sectools', 'secbody', 'status', 'stModel', 'nxModalRoot'].forEach(function(id){
    els[id] = mkNode('div', { id: id });
    doc.body.appendChild(els[id]);
  });
  function click(target){
    (listeners.click || []).slice().forEach(function(fn){
      fn({ type: 'click', target: target, preventDefault(){}, stopPropagation(){}, stopImmediatePropagation(){} });
    });
  }
  const sb = {
    console: console, document: doc, setTimeout: function(){}, clearTimeout: function(){},
    localStorage: { getItem(){ return null; }, setItem(){} }, module: undefined,
    NXEdgeMenu: { num(v){ return Number(v) || 0; }, menuHtml(){ return ''; }, selectionHint(){ return ''; },
                  optionPayload(p){ return p; } },
    sketchup: new Proxy({}, { get(){ return function(){}; } })
  };
  sb.window = sb;
  vm.createContext(sb);
  ['nx_modal.js', 'studio.js', 'budget.js'].forEach(function(f){
    vm.runInContext(fs.readFileSync(path.join(JS, f), 'utf8'), sb, { filename: f });
  });
  const PAYLOAD = {
    version: '0.0.0', gen: 3, model_title: 'T', model_guid: 'G',
    rows: [{ key: 'r1', name: 'Bok', owner_id: 'CAB-1', length: 720, width: 560, thickness: 18, quantity: 2,
             material_id: 'M1', edges: {} }],
    sheets: [{ material_id: 'M1', m2: 0.81, quantity: 2 }], edging: [],
    sheet_estimate: [{ material_id: 'M1', m2: 0.81, count_min: 2.2, count_max: 2.4, sheet_size: [2800, 2070] }],
    totals: { parts: 2, rows: 1, m2: 0.81, bm: 5.4, materials: 1, edges: 0, plates_min: 2.2, plates_max: 2.4 },
    materials_meta: { M1: { label: 'Biela', th: 18 } }, edges_meta: {}, hardware: [], hardware_sets: null,
    summary: {}, vepo: { project: 'p', default_project: 'p', merge_18_36: true },
    control: [], counts: { red: 0, orange: 0, cabinets: 1, clean: 1 }, edge_check: null, grain_check: null,
    open_section: 'bom', anchor: null
  };
  sb.NX.setStudio(PAYLOAD);
  const tot = function(html){ const i = html.lastIndexOf('<div class="totrow"'); return i < 0 ? '' : html.slice(i); };
  const parts = tot(els.secbody.innerHTML);
  ok(parts.length > 0, 'pohľad Dielce má súčtový riadok');
  // Mutácia M1: súčtový riadok stále píše „odhad X – Y platní" (tooltip odkazu slovo „platní" smie mať).
  no(/odhad|2,2 – 2,4|\d – \d+(,\d)? platní/.test(parts), 'Dielce: súčtový riadok nepíše súčet platní');
  ok(parts.indexOf('data-nav="cut"') >= 0 && parts.indexOf('#i-scissors') >= 0, 'Dielce: preklik do Nárezového plánu s nožnicami');
  ok(parts.indexOf('platne na objednávku: ') >= 0, 'a vysvetlenie pred ním');

  click(mkNode('button', { 'data-view': 'sheets' }));
  const sheetsHtml = els.secbody.innerHTML;
  ok(sheetsHtml.indexOf('<th class="num">Odhad platní</th>') >= 0, 'Platne: stĺpec „Odhad platní" ostáva');
  ok(sheetsHtml.indexOf('<b>2,2 – 2,4</b>') >= 0, 'a v ňom odhad po materiáli');
  const st = tot(sheetsHtml);
  no(/2,2 – 2,4|odhad \d|\d – \d+(,\d)? platní/.test(st), 'Platne: súčtový riadok nepíše súčet platní');
  ok(st.indexOf('Spolu <b>0,81 m² dielcov</b>') >= 0, 'Platne: súčet m² dielcov ostal');
  ok(st.indexOf('data-nav="cut"') >= 0 && st.indexOf('#i-scissors') >= 0, 'Platne: rovnaký preklik');

  eq(sb.studioActiveSection(), 'bom', 'pred klikom je otvorený Kusovník');
  const btn = mkNode('button', { 'data-nav': 'cut', class: 'linkbtn' });
  click(btn);
  eq(sb.studioActiveSection(), 'cut', 'klik na preklik otvorí Nárezový plán (existujúca cesta data-nav)');
})();

// ============================ 6) guard ŠT-1a ================================
(function(){
  const src = fs.readFileSync(path.join(JS, 'studio.js'), 'utf8');
  no(/reduce\(|\+=\s*\w+\.m2|\+=\s*\w+\.quantity/.test(src), 'studio.js stále nesčítava (zlúčenie „Kde" je na serveri)');
  no(/plates_min|plates_max/.test(src), 'studio.js nečíta plates_* (súčet platní cez materiály sa nezobrazuje)');
})();

console.log(`test_h3_zobrazenie.js: ${n} kontrol OK`);
