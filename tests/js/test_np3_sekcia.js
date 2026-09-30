// NP-3 (blok 2 · Nárezový plán) — sekcia `cut` v Štúdiu (klient).
//
// Prečo sú to testy:
//   1. Karty, malé platne a súhrn kreslí klient VÝHRADNE z payloadu — vetu
//      o počte skladá server (`phrase`), klient ju len zobrazí.
//   2. Upozornenie na poslednú platňu (O2): pod 20 % ALEBO najviac 2 dielce,
//      len pri aspoň 2 platniach — hranice 19,9/20 % a 2/3 dielce.
//   3. Zbalená karta SVG nevytvára (F11) a zbalenie prežije prekreslenie.
//   4. Oko posiela NATÍVNY kľúč riadku (`parts_key`) + `gen`, nikdy pids.
//   5. SVG je téma-bezpečné: len triedy, žiadne inline farby (F12).
'use strict';
const assert = require('node:assert');

// --- minimálny DOM + sketchup stub -------------------------------------------
const ELS = {};
function mkEl(id){ return { id: id, innerHTML: '', scrollTop: 5, querySelectorAll: function(){ return []; } }; }
['sechead', 'sectools', 'secbody', 'snav', 'status', 'studio'].forEach(function(id){ ELS[id] = mkEl(id); });
const STORE = {};
const SENT = [];
let WENT = null;
global.document = {
  getElementById: function(id){ return ELS[id] || null; },
  addEventListener: function(){}
};
global.window = {
  localStorage: {
    getItem: function(k){ return Object.prototype.hasOwnProperty.call(STORE, k) ? STORE[k] : null; },
    setItem: function(k, v){ STORE[k] = String(v); }
  },
  sketchup: { nx_select: function(p){ SENT.push(JSON.parse(p)); } }
};
global.sketchup = global.window.sketchup;
global.studioGoSection = function(id){ WENT = id; };

const S = require('../../noxun_engine/ui/js/studio.js');
const NP = require('../../noxun_engine/ui/js/sheet_layout.js');
S.setStudioSection('cut');

let passed = 0;
function ok(c, m){ assert.ok(c, m); passed++; }
function eq(a, b, m){ assert.deepStrictEqual(a, b, m); passed++; }

// --- fixtúra v tvare `ProductionCore.sheet_layout_payload` --------------------
const KEY_A = [7200, 5600, 180, 'H18', ['', '', '', ''], 'length', null];
const KEY_D = [8200, 5800, 360, 'H36', ['', '', '', ''], 'length', ['H18', 2]];
const KEY_X = [27950, 5600, 180, 'W18', ['', '', '', ''], 'none', null];
function plate(u, n){ const p = []; for (let i = 0; i < n; i++) p.push([0, i * 725, 0]); return { u: u, p: p, o: [0, 600, 2780, 1400] }; }
function mat(over){
  return Object.assign({
    id: 'H18', label: 'H1181 ST37 Dub Halifax', manufacturer: 'Egger', th: 18, rgb: [124, 90, 58], grain: 'length',
    size: [2800, 2070], usable: [2780, 2050], trim: 10, no_trim: false, fallback: false, uni: false, orient: false,
    incomplete: false, upper_bound: true, invalid_params: false, blocked: null, sheets: 2, util: 50,
    phrase: { pre: '', n: '2 platne', post: '(horná hranica)', cls: '', text: '2 platne (horná hranica)' },
    est: [1.6, 1.8], est_budget: 2,
    rows: [{ k: KEY_A, n: 'Bok lavy / Bok pravy', s: 'Bok lavy', o: 'CAB-001', l: 720, w: 560, c: 6, d: false, m: 1, q: 6, fl: 720, fw: 560 },
           { k: KEY_D, n: 'Bočnica 36', s: 'Bočnica 36', o: 'BRD-001', l: 840, w: 600, c: 4, d: true, m: 2, q: 2, fl: 820, fw: 580 }],
    plates: [plate(80, 5), plate(30, 3)],
    unplaced: [], rejected: [], conflicts: []
  }, over || {});
}
function sl(mats, over){
  return Object.assign({ ok: true, params: { kerf: 5, trim: 10, dup_allowance: 10 }, source: 'file', unreliable: false,
                         blocked: null, without_material: { rows: 0, pieces: 0, items: [] }, materials: mats }, over || {});
}

// --- 1) upozornenie na poslednú platňu (O2) ---------------------------------
eq(NP.NP_WARN_UTIL, 20, 'prah O2 je 20 %');
ok(NP.npLastWarn(mat({ plates: [plate(80, 5), plate(19.9, 3)] })), '19,9 % = upozornenie');
eq(NP.npLastWarn(mat({ plates: [plate(80, 5), plate(20, 3)] })), null, '20 % a 3 dielce = nie');
ok(NP.npLastWarn(mat({ plates: [plate(80, 5), plate(60, 2)] })), '2 dielce = upozornenie aj pri 60 %');
eq(NP.npLastWarn(mat({ plates: [plate(80, 5), plate(60, 3)] })), null, '3 dielce a 60 % = nie');
eq(NP.npLastWarn(mat({ plates: [plate(5, 1)] })), null, 'len pri aspoň 2 platniach');
eq(NP.npLastWarn(mat({ plates: [plate(80, 5), plate(7, 1)] })).parts, 1);

// --- 2) karta, súhrn, veta zo servera ---------------------------------------
const A = sl([mat(), mat({ id: 'W18', label: 'W1000 Biela', grain: 'none', incomplete: true, upper_bound: false,
                           phrase: { pre: '', n: '1 platňa', post: 'pre zaradené dielce — celkový počet neznámy', cls: 'inc' },
                           plates: [plate(46, 4)],
                           rows: [{ k: KEY_X, n: 'Bok vysoky', s: 'Bok vysoky', o: 'CAB-004', l: 2795, w: 560, c: 2, d: false, m: 1, q: 2, fl: 2795, fw: 560 }],
                           unplaced: [{ r: 0, reason: 'oversize', c: 2, q: 2, t: 'nezmestí sa ani otočený — hlási aj Kontrola' }],
                           rejected: [{ reason: 'vepo', t: 'VEPO riadok odmietne — neznáma ABS X; plán ho preto nezaradí',
                                        n: 'Polica', k: null, q: 1, o: 'CAB-005', l: 500, w: 300 }] }),
                mat({ id: 'OK2', label: 'Tretí', plates: [plate(70, 4)] })]);
let body = NP.npBodyHtml(A, { closed: {}, detail: null });
ok(body.indexOf('<div class="npsum">') >= 0, 'súhrnný riadok');
ok(body.indexOf('3 materiály') >= 0, 'počet materiálov');
ok(/úplný plán: <b>4 platne<\/b> \(horná hranica\) pri 2 materiáloch/.test(body), 'súhrn úplného plánu');
ok(body.indexOf('VEPO optimalizuje sám a jeho počet sa môže líšiť') >= 0, 'tooltip súhrnu nesľubuje počet VEPO');
ok(body.indexOf('<b>2 platne</b> <small>(horná hranica)</small>') >= 0, 'veta karty zo servera');
ok(body.indexOf('npcount inc') >= 0 && body.indexOf('celkový počet neznámy') >= 0, 'neúplný plán');
ok(body.indexOf('data-np-param') < 0, 'chip parametrov patrí lište, nie telu');
ok(body.indexOf('vrátane 2 duplákov = 4 prírezy s prídavkom (820 × 580 → 840 × 600)') >= 0,
   'duplák = hotové kusy + prírezy s prídavkom');
// Codex #420 P2: viac duplákových riadkov — súčty za všetky; rozmer len keď je spoločný
const DUP2 = { k: null, n: 'Bočnica 36 vysoká', s: 'Bočnica', o: 'BRD-002', l: 2020, w: 600, c: 6, d: true, m: 2, q: 3, fl: 2000, fw: 580 };
const DUP_SAME = { k: null, n: 'Bočnica 36 B', s: 'Bočnica', o: 'BRD-003', l: 840, w: 600, c: 2, d: true, m: 2, q: 1, fl: 820, fw: 580 };
const rowsD = mat().rows;
let chip = NP.npDupChipHtml([rowsD[1], DUP2]);
ok(chip.indexOf('>vrátane 5 duplákov = 10 prírezov s prídavkom</span>') >= 0, 'rôzne rozmery: súčty bez rozmeru prvého riadku');
ok(chip.slice(chip.indexOf('">') + 2).indexOf('820') < 0, 'rozmer prvého riadku nie je v texte chipu');
ok(chip.indexOf('Bočnica 36: 2 ks (hotový 820 × 580) = 4 prírezy 840 × 600') >= 0 &&
   chip.indexOf('Bočnica 36 vysoká: 3 ks (hotový 2000 × 580) = 6 prírezov 2020 × 600') >= 0,
   'rozpis po riadkoch v tooltipe: hotový rozmer v zátvorke, prírezy s prídavkom');
// Slepá delta #420 (P3): meno riadku ide do atribútu `title` escapované.
chip = NP.npDupChipHtml([Object.assign({}, rowsD[1], { n: 'A"<b>' }), DUP2]);
ok(chip.indexOf('A&quot;&lt;b&gt;: 2 ks') >= 0, 'meno riadku v tooltipe je escapované');
ok(chip.indexOf('A"<b>') < 0, 'surové meno sa do HTML nedostane');
chip = NP.npDupChipHtml([rowsD[1], DUP_SAME]);
ok(chip.indexOf('>vrátane 3 duplákov = 6 prírezov s prídavkom (820 × 580 → 840 × 600)</span>') >= 0,
   'rovnaký rozmer vo viacerých riadkoch: rozmer ostáva');
body = NP.npBodyHtml(sl([mat({ rows: mat().rows.concat([DUP2]) })]), { closed: {} });
ok(body.indexOf('vrátane 5 duplákov = 10 prírezov s prídavkom</span>') >= 0, 'karta používa ten istý chip');
body = NP.npBodyHtml(A, { closed: {} });
ok(body.indexOf('Posledná platňa:') < 0 || /Posledná platňa:<\/b> 3 dielce/.test(body), 'upozornenie len kde má byť');
// predvolené otvorenie (F11): prvá karta + karta s problémom; tretia zbalená a BEZ SVG
const cards = body.split('<div class="npcard');
eq(cards.length - 1, 3, 'tri karty');
ok(cards[1].indexOf('<svg xmlns') >= 0, 'prvá karta otvorená');
ok(cards[2].indexOf('<svg xmlns') >= 0 && cards[2].indexOf('npmiss') >= 0, 'karta s problémom otvorená, s červeným zoznamom');
ok(cards[3].indexOf(' closed"') === 0 && cards[3].indexOf('<svg xmlns') < 0, 'bezproblémová karta zbalená a SVG nevytvára');
ok(cards[3].indexOf('npcount') >= 0, 'zbalená karta stále povie počet (2 riadky)');
// červený zoznam: dôvody zo servera, oko len pri kľúči
ok(cards[2].indexOf('nezmestí sa ani otočený — hlási aj Kontrola') >= 0);
ok(cards[2].indexOf('VEPO riadok odmietne — neznáma ABS X') >= 0);
eq((cards[2].match(/data-np-key=/g) || []).length, 1, 'oko len pri riadku s kľúčom (vyradený bez kľúča nemá)');

// --- 3) upozornenie a jeho „Ukázať platňu" ---------------------------------
const W = sl([mat({ plates: [plate(80, 5), plate(7, 1)] })]);
body = NP.npBodyHtml(W, { closed: {} });
ok(/<b>Posledná platňa:<\/b> 1 dielec — Bok lavy \/ Bok pravy 720 × 560 · využitie 7 %/.test(body), 'veta O2');
ok(body.indexOf('data-np-open="H18:1"') >= 0, 'tlačidlo na tú platňu');
ok(body.indexOf('np-part lone') >= 0, 'osamelý dielec jantárový');
ok(body.indexOf('npthumb warn') >= 0, 'malá platňa jantárová');

// --- 4) globálny stav (B4), chyba plánu (F7), parametre (O7) -----------------
body = NP.npBodyHtml(sl([], { blocked: 'VEPO export by sa zastavil: x', without_material: { rows: 1, pieces: 3, items: [{ n: 'Doska' }] } }), {});
ok(body.indexOf('Plán je neúplný pre celú zákazku') >= 0 && body.indexOf('VEPO export by sa zastavil: x') >= 0, 'blokácia celej zákazky');
ok(body.indexOf('3 dielce bez materiálu') >= 0, 'dielce bez materiálu aj bez kariet');
ok(NP.npBodyHtml({ ok: false }, {}).indexOf('Nárezový plán sa nepodarilo spočítať') >= 0, 'chyba plánu je veta, nie prázdno');
let tools = NP.npToolsHtml(A, false, null);
ok(tools.indexOf('prerez 5 mm · orez 10 mm · duplák +10 mm') >= 0, 'chip parametrov (mockup A2)');
ok(tools.indexOf('id="refreshBtn"') >= 0, 'Obnoviť zo zdieľaného helpera');
ok(NP.npToolsHtml(A, true, null).indexOf('nxstale') >= 0, 'jantárový Obnoviť po zmene modelu');
tools = NP.npToolsHtml(sl([mat()], { unreliable: true, params: { kerf: 4.4, trim: 10, dup_allowance: 10 } }), false, null);
ok(tools.indexOf('npparam warn') >= 0 && tools.indexOf('nastavenia sa nepodarilo načítať, predvolené hodnoty') >= 0,
   'predvolené hodnoty = jantárový chip s vetou');
ok(tools.indexOf('prerez 4,4 mm') >= 0, 'desatinná čiarka');

// --- 5) detail platne (B) a späť --------------------------------------------
const D = sl([mat()]);
eq(NP.npValidDetail(D, { mid: 'H18', pi: 9 }), { mid: 'H18', pi: 1 }, 'neexistujúca platňa sa skráti');
eq(NP.npValidDetail(D, { mid: 'NIC', pi: 0 }), null, 'zmiznutý materiál = späť na prehľad');
body = NP.npBodyHtml(D, { detail: { mid: 'H18', pi: 0 } });
ok(body.indexOf('class="npdsvg"') >= 0 && body.indexOf('<table class="nplist">') >= 0, 'detail = veľká platňa + zoznam');
ok(body.indexOf('npcard') < 0, 'detail nahradí karty v tom istom okne');
ok(body.indexOf('najväčší zvyšok <b>2780 × 1400</b>') >= 0, 'zvyšok s rozmerom');
tools = NP.npToolsHtml(D, false, { mid: 'H18', pi: 0 });
ok(tools.indexOf('data-np-back') >= 0 && tools.indexOf('Platňa 1 z 2') >= 0, 'Prehľad + listovanie');

// --- 6) udalosti: oko, zbalenie, preklik, späť ------------------------------
function tgt(attrs){
  return { getAttribute: function(k){ return attrs[k] === undefined ? null : attrs[k]; },
           closest: function(sel){ const m = sel.match(/^\[([a-z-]+)\]$/); return m && attrs[m[1]] !== undefined ? this : null; } };
}
NP.npSetState(Object.assign({ gen: 7 }, A));
ok(NP.npOnClick(tgt({ 'data-np-key': JSON.stringify(KEY_D) })), 'klik na oko sa spracuje');
eq(SENT.length, 1);
eq(SENT[0].parts_key, KEY_D, 'natívny kľúč riadku (pole), nie text');
eq(SENT[0].gen, 7, 'generácia okna');
eq(SENT[0].origin, 'cut', 'vlastná veta statusu');
ok(!('pids' in SENT[0]), 'nikdy pids');
// zbalenie prežije re-render (localStorage)
NP.npResetClosed();
NP.npRenderBody();
ok(ELS.secbody.innerHTML.split('<div class="npcard')[1].indexOf('<svg xmlns') >= 0, 'prvá karta otvorená');
NP.npOnClick(tgt({ 'data-np-card': 'H18' }));
ok(JSON.parse(STORE[NP.NP_CLOSED_KEY]).H18 === true, 'voľba sa uložila na tomto počítači');
NP.npResetClosed();
NP.npRenderBody();
const first = ELS.secbody.innerHTML.split('<div class="npcard')[1];
ok(first.indexOf(' closed"') === 0 && first.indexOf('<svg xmlns') < 0, 'po prekreslení (aj po obnovení pamäte) ostáva zbalená');
// localStorage, ktorý hádže, nič nezhodí
const saved = global.window.localStorage;
global.window.localStorage = { getItem: function(){ throw new Error('blok'); }, setItem: function(){ throw new Error('blok'); } };
NP.npResetClosed();
NP.npRenderBody();
ok(ELS.secbody.innerHTML.indexOf('npcard') >= 0, 'bez localStorage sa sekcia vykreslí');
global.window.localStorage = saved;
NP.npResetClosed();
// preklik z chipu parametrov do Nastavení rozpočtu
NP.npOnClick(tgt({ 'data-np-param': '' }));
eq(WENT, 'bset', 'chip parametrov otvorí Nastavenia rozpočtu');
// malá platňa -> detail -> ďalšia -> späť
NP.npOnClick(tgt({ 'data-np-thumb': 'H18:0' }));
eq(NP.npGetDetail(), { mid: 'H18', pi: 0 });
ok(ELS.secbody.innerHTML.indexOf('nplist') >= 0 && ELS.sectools.innerHTML.indexOf('Platňa 1 z 2') >= 0);
eq(ELS.secbody.scrollTop, 0, 'detail začína hore');
NP.npOnClick(tgt({ 'data-np-pg': '1' }));
eq(NP.npGetDetail().pi, 1, 'šípka listuje');
NP.npOnClick(tgt({ 'data-np-pg': '1' }));
eq(NP.npGetDetail().pi, 0, 'dokola');
NP.npOnClick(tgt({ 'data-np-back': '' }));
eq(NP.npGetDetail(), null, 'Prehľad vráti karty');
ok(ELS.secbody.innerHTML.indexOf('npcard') >= 0);
// v inej sekcii sa nič nekreslí ani nespracuje
S.setStudioSection('bom');
ELS.secbody.innerHTML = 'KUSOVNIK';
NP.npRenderBody();
eq(ELS.secbody.innerHTML, 'KUSOVNIK', 'cudziu sekciu neprepíše');
ok(!NP.npOnClick(tgt({ 'data-np-param': '' })), 'klik mimo sekcie ignoruje');
S.setStudioSection('cut');

// --- 7) téma (F12): SVG len triedy, obe témy = rovnaký markup ----------------
const svgAll = NP.npBodyHtml(A, { closed: { OK2: false } }) + NP.npBodyHtml(D, { detail: { mid: 'H18', pi: 0 } });
const svgs = svgAll.match(/<svg xmlns[\s\S]*?<\/svg>/g) || [];
ok(svgs.length >= 5, 'platne sa nakreslili');
svgs.forEach(function(s){
  ok(!/(fill|stroke|style)=/.test(s), 'SVG bez inline farieb');
  ok(!/#[0-9a-f]{3,6}\b|rgba?\(|hsla?\(/i.test(s.replace(/url\(#npHatch[SLD]\)/g, '')), 'SVG bez tvrdých farieb');
});
ok(/style="background:#7c5a3a"/.test(svgAll), 'jediná dátová farba = vzorka dekoru (mimo SVG)');
// Predrecenzia P3-2: dôkaz „obe témy" = každá trieda, ktorú SVG použije, má
// v studio.html pravidlo a jeho farby idú VÝHRADNE cez `var(--nx-*)` (téma
// prepína tokeny); kreslenie tému nečíta vôbec.
const fs = require('node:fs');
const path = require('node:path');
const HTML = fs.readFileSync(path.join(__dirname, '../../noxun_engine/ui/studio.html'), 'utf8');
const SRC = fs.readFileSync(path.join(__dirname, '../../noxun_engine/ui/js/sheet_layout.js'), 'utf8');
ok(!/data-nx-theme|nxTheme|lucia/i.test(SRC), 'kreslenie tému nečíta — rozhodujú tokeny v CSS');
const used = {};
svgs.join('').replace(/class="([^"]+)"/g, function(_m, c){ c.split(/\s+/).forEach(function(x){ if (/^np-/.test(x)) used[x] = true; }); });
ok(Object.keys(used).length >= 6, 'SVG používa triedy np-*');
Object.keys(used).forEach(function(cls){
  const rules = HTML.match(new RegExp('\\.' + cls + '(?![a-z-])[^{]*\\{([^}]*)\\}', 'g')) || [];
  ok(rules.length >= 1, 'trieda .' + cls + ' má pravidlo v studio.html');
  rules.forEach(function(r){
    const decl = r.slice(r.indexOf('{') + 1);
    (decl.match(/(?:^|;)\s*(?:fill|stroke|color|background)\s*:\s*[^;}]+/g) || []).forEach(function(d){
      const v = d.split(':').slice(1).join(':').trim();
      ok(/^(var\(--nx-[a-z-]+\)|url\(#npHatch[SLD]\)|none)$/.test(v), '.' + cls + ' ' + d.trim() + ' ide cez token');
    });
  });
});

// --- 8) výkon renderu (F9): ~2000 obdĺžnikov --------------------------------
const big = [];
for (let m = 0; m < 3; m++){
  const rows = [], plates = [];
  for (let r = 0; r < 130; r++) rows.push({ k: [r, m], n: 'P' + r, s: 'P' + r, o: 'CAB-' + r, l: 300 + r, w: 200, c: 5, d: false, m: 1, q: 5, fl: 300 + r, fw: 200 });
  for (let p = 0; p < 24; p++){
    const pp = [];
    for (let i = 0; i < 28; i++) pp.push([(p * 28 + i) % 130, (i % 7) * 390, Math.floor(i / 7) * 205]);
    plates.push({ u: 70, p: pp, o: [0, 1640, 2780, 400] });
  }
  big.push(mat({ id: 'M' + m, rows: rows, plates: plates, sheets: 24 }));
}
const BIG = sl(big);
const t0 = Date.now();
const out = NP.npBodyHtml(BIG, { closed: { M0: false, M1: false, M2: false } });
const ms = Date.now() - t0;
const rects = (out.match(/class="np-part/g) || []).length;
const nodes = (out.match(/<(rect|path|text|g)\b/g) || []).length;
console.log('    [NP-3 render] ' + rects + ' dielcov na ' + (out.match(/<svg xmlns/g) || []).length + ' platniach: ' +
            nodes + ' SVG uzlov, ' + out.length + ' znakov, ' + ms + ' ms');
eq(rects, 3 * 24 * 28);
ok(ms < 300, 'render celej sekcie pod 300 ms (' + ms + ' ms)');
const closedAll = NP.npBodyHtml(BIG, { closed: { M0: true, M1: true, M2: true } });
eq((closedAll.match(/<svg xmlns/g) || []).length, 0, 'zbalené karty = 0 SVG uzlov');

// --- NP-4 (predrecenzia P2): „v rozpočte N" = číslo HOTOVÉHO rozpočtu -------
let card = NP.npBodyHtml(sl([mat({ est_budget: 2 })]), { closed: {} });
ok(card.indexOf('(v rozpočte dnes 2)') >= 0, 'bez rozpočtu v payloade (starší server): odhad ako dnes');
card = NP.npBodyHtml(sl([mat({ est_budget: 2, budget_qty: 3, budget_src: 'plan' })]), { closed: {} });
ok(card.indexOf('(v rozpočte 3 podľa plánu)') >= 0, 'zapnuté ceny podľa plánu: číslo a zdroj z rozpočtu');
ok(card.indexOf('v rozpočte dnes 2') < 0, 'žiadna druhá pravda (odhad) pri karte');
card = NP.npBodyHtml(sl([mat({ est_budget: 2, budget_qty: 2, budget_src: 'estimate' })]), { closed: {} });
ok(card.indexOf('(v rozpočte 2 z odhadu)') >= 0, 'nespôsobilý materiál: z odhadu');
card = NP.npBodyHtml(sl([mat({ est_budget: 2, budget_qty: 2, budget_src: null })]), { closed: {} });
ok(card.indexOf('(v rozpočte dnes 2)') >= 0, 'vypnutý prepínač: dnešná veta');
// CENY-M2 (R7): materiál „podľa plochy" má v rozpočte m², nie platne.
card = NP.npBodyHtml(sl([mat({ est_budget: 1, budget_qty: 0.9, budget_src: 'area' })]), { closed: {} });
ok(card.indexOf('(v rozpočte 0,90 m² podľa plochy)') >= 0, 'area: m² na 2 desatinné s čiarkou');
ok(card.indexOf('v rozpočte dnes') < 0 && card.indexOf('v rozpočte 0.9') < 0, 'area: m² sa netvária ako počet platní');
ok(card.indexOf('nie sú zapnuté ceny podľa plánu') >= 0 && card.indexOf('toľko platní dnes počíta rozpočet') < 0,
   'tooltip súhrnu netvrdí, že rozpočet vždy počíta z odhadu');

console.log('test_np3_sekcia: ' + passed + ' OK');
