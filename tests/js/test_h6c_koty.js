// H6c — citatelne koty v nahlade Inspectora (D-02, blok 9 HARDENING).
//   node tests/js/test_h6c_koty.js
//
// T0 golden popisov (tests/fixtures/h6c_koty/golden.json, vygenerovany nad
//    STARYM kodom): ziadna kota nesmie pribudnut ani zmiznut; po normalizacii
//    „ mm" (O11) a povolenych skratkach (R3) je kazdy popis rovnaky.
// T1 nxDimScene: mierka `meet` presne = s, okraje v px, neplatny vstup scenu nezrusi.
// T2 invarianty R7: nic sa neoreze (14 pripadov x 4 rozmery okna) a pismo kot ma
//    11 px (medzery 10 px) na obrazovke — aj po zoome.
// T3 pvFitLabel / pvFrontLabel: dlhy -> kratky -> vedla; popis cela v 3 stupnoch;
//    medzery Cel bez prekryvu; popis zony len ked sa zmesti.
// T4 bez „mm" v ziadnom popise; ciara kot 1 px `non-scaling-stroke`.
// T5 prekreslenie (R6): Ctrl+koliesko, ResizeObserver, pan, tahanie priecky.
// T6 interakcia sa nerozbila: zony, priecky a znacky kovania ostavaju v mm.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const H = require('./h6c_harness.js');
const PV = require(path.join(H.JS, 'preview.js'));

let n = 0;
function eq(actual, expected, msg){ n++; assert.deepStrictEqual(H.plain(actual), H.plain(expected), msg); }
function ok(cond, msg){ n++; assert.ok(cond, msg); }
function near(a, b, tol, msg){ n++; assert.ok(Math.abs(a - b) <= tol, `${msg}: cakam ${b} (±${tol}), dostal ${a}`); }

const GOLDEN = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'h6c_koty', 'golden.json'), 'utf8'));
const RECTS = [{ w: 404, h: 210 }, { w: 404, h: 323 }, { w: 404, h: 640 }, { w: 300, h: 323 }];

// ============ T0 · golden popisov ===========================================
// Povolene skratky R3: dlhy popis -> kratky (len cislo) a popis cela v 3 stupnoch.
// Volitelne (R3): popis zony a cislo pasma chladnicky sa nekresli, ked sa nezmesti.
function norm(t){ return t.replace(/ mm$/, ''); }
function variants(g){
  const out = [g];
  let m;
  if ((m = /^(?:Š|V|H|sokel|telo) (\d+)$/.exec(g))) out.push(m[1]);
  if ((m = /^(F\d+) · .*?(\d+)$/.exec(g))) { out.push(m[1] + ' · ' + m[2]); out.push(m[1]); }
  return out;
}
const OPTIONAL = { cab_fridge: /^(40|71)$/ }; // tenke pasma chladnicky (4,6 a 8 px) sa pri 404 x 323 nezmestia; popisy zon musia byt VSETKY
{
  const ctx = H.makeCtx();
  H.CASES.forEach(c => {
    const got = H.texts(H.renderCase(ctx, c, { w: 404, h: 323 })).map(t => t.text); // nové popisy: už BEZ „mm" (O11)
    const pool = got.slice();
    GOLDEN[c.id].map(norm).forEach(g => {
      const i = pool.findIndex(x => variants(g).indexOf(x) >= 0);
      if (i >= 0) { pool.splice(i, 1); n++; return; }
      ok(OPTIONAL[c.id] && OPTIONAL[c.id].test(g), `T0 ${c.id}: popis „${g}" zmizol (nasiel som: ${JSON.stringify(got)})`);
    });
    eq(pool, [], `T0 ${c.id}: pribudol nepovoleny popis`);
  });
}

// ============ T1 · nxDimScene ================================================
{
  const CONTENTS = [{ w: 800, h: 864 }, { w: 800, h: 720 }, { w: 600, h: 2200 }, { w: 1100, h: 720 }, { w: 2600, h: 600 }, { w: 300, h: 300 }];
  const MARGINS = [{ l: 46, r: 40, t: 30, b: 28 }, { l: 34, r: 40, t: 8, b: 28 }, { l: 0, r: 0, t: 0, b: 28 }, { l: 0, r: 0, t: 0, b: 0 }, { l: 46, r: 40, t: 30, b: 46 }];
  CONTENTS.forEach(c => RECTS.forEach(r => MARGINS.forEach(m => {
    const sc = PV.nxDimScene({ minX: 0, maxX: c.w, minZ: 0, maxZ: c.h }, m, r);
    const meet = Math.min(r.w / sc.w, r.h / sc.h);
    near(meet, sc.s, 1e-9, `T1 meet ${c.w}x${c.h} ${r.w}x${r.h}: mierka viewBoxu = s`);
    // okraje v px: vzdialenost obsahu od hrany scény * s = okraj + 6 px vzduchu
    near((0 - sc.x0) * sc.s, m.l + PV.PV_PAD_PX, 1e-6, 'T1 okraj vlavo v px');
    near((sc.x1 - c.w) * sc.s, m.r + PV.PV_PAD_PX, 1e-6, 'T1 okraj vpravo v px');
    near((0 - sc.z0) * sc.s, m.b + PV.PV_PAD_PX, 1e-6, 'T1 okraj dole v px');
    near((sc.z1 - c.h) * sc.s, m.t + PV.PV_PAD_PX, 1e-6, 'T1 okraj hore v px');
    ok(c.w * sc.s + m.l + m.r + 2 * PV.PV_PAD_PX <= r.w + 1e-6 && c.h * sc.s + m.t + m.b + 2 * PV.PV_PAD_PX <= r.h + 1e-6,
       'T1 obsah aj okraje sa zmestia do okna');
  })));
  // neplatny vstup: scena sa nezrúti
  [[null, null, null], [{}, {}, { w: 0, h: 0 }], [{ minX: 0, maxX: 0, minZ: 0, maxZ: 0 }, { l: -5 }, { w: -1, h: 10 }],
   [{ minX: NaN, maxX: Infinity, minZ: 0, maxZ: 10 }, null, undefined]].forEach((a, i) => {
    const sc = PV.nxDimScene(a[0], a[1], a[2]);
    ok(isFinite(sc.s) && sc.s > 0 && isFinite(sc.w) && sc.w > 0 && isFinite(sc.h) && sc.h > 0, 'T1 neplatný vstup #' + i + ' scénu nezrúti');
  });
  // okno menšie než okraje: mierka spadne na 0,05, nie na zápornú
  near(PV.nxDimScene({ minX: 0, maxX: 800, minZ: 0, maxZ: 800 }, { l: 46, r: 40, t: 30, b: 28 }, { w: 60, h: 60 }).s, 0.05, 1e-12, 'T1 príliš malé okno → s = 0,05');
}

// ---- T1b · okraje v px v skutocnom viewBoxe (suradnice SVG: rx = 14 + x, ry = 14 + H - z) ----
{
  const ctx = H.makeCtx();
  const r = { w: 404, h: 323 };
  H.renderCase(ctx, H.CASES[0], r); // spodna 800 x 864, hlbka 520 (skosenie 93,6)
  const vb = ctx.__svg.getAttribute('viewBox').split(/\s+/).map(parseFloat);
  const s = Math.min(r.w / vb[2], r.h / vb[3]);
  const sk = Math.min(Math.max(520 * 0.18, 24), 130);
  near((14 - vb[0]) * s, 46 + 6, 1e-6, 'T1b okraj vlavo (sokel/telo) = 46 + 6 px');
  near((vb[0] + vb[2] - (14 + 800 + sk)) * s, 40 + 6, 1e-6, 'T1b okraj vpravo (vyska) = 40 + 6 px');
  near((vb[1] + vb[3] - (14 + 864)) * s, 28 + 6, 1e-6, 'T1b okraj dole (sirka) = 28 + 6 px');
  near((14 - sk - vb[1]) * s, 30 + 6, 1e-6, 'T1b okraj hore (hlbka nad skosenim) = 30 + 6 px');
  // Cela: vlavo 34 (cisla medzier), vpravo 40, hore 8, dole 28 (+ 6 px vzduchu)
  H.renderCase(ctx, H.CASES.find(c => c.id === 'fronts_lower_drawer'), r);
  const vf = ctx.__svg.getAttribute('viewBox').split(/\s+/).map(parseFloat);
  const sf = Math.min(r.w / vf[2], r.h / vf[3]);
  near((14 - vf[0]) * sf, 34 + 6, 1e-6, 'T1b Cela: okraj vlavo = 34 + 6 px');
  near((vf[1] + vf[3] - (14 + 864)) * sf, 28 + 6, 1e-6, 'T1b Cela: okraj dole = 28 + 6 px');
  near((14 - vf[1]) * sf, 8 + 6, 1e-6, 'T1b Cela: okraj hore = 8 + 6 px');
}

// ============ T2 · invarianty R7 (nic sa neoreze, 11 px) =====================
function vbOf(ctx){ return ctx.__svg.getAttribute('viewBox').split(/\s+/).map(parseFloat); }
// obdlznik textu: odhad 0,56 · font · znaky; vodorovny aj otoceny o −90°
function box(t){
  const a = t.attrs, fs = parseFloat(a['font-size']), x = parseFloat(a.x), y = parseFloat(a.y);
  const w = 0.56 * fs * t.text.length;
  const mid = a['dominant-baseline'] === 'middle';
  const rot = /rotate\(-90/.test(a.transform || '');
  const anchor = a['text-anchor'] || 'start';
  if (rot) return { x0: x - fs / 2, x1: x + fs / 2, y0: y - w / 2, y1: y + w / 2 };
  const x0 = anchor === 'middle' ? x - w / 2 : (anchor === 'end' ? x - w : x);
  return { x0: x0, x1: x0 + w, y0: mid ? y - fs / 2 : y - 0.8 * fs, y1: mid ? y + fs / 2 : y + 0.2 * fs };
}
function checkCase(ctx, c, rect, label, opts){
  const svg = H.renderCase(ctx, c, rect, opts);
  const vb = vbOf(ctx);
  const s = Math.min(rect.w / vb[2], rect.h / vb[3]);
  H.texts(svg).forEach(t => {
    if (t.text === '?') return; // symbol v kresbe je geometria
    const px = parseFloat(t.attrs['font-size']) * s;
    ok(Math.abs(px - 11) < 0.011 || Math.abs(px - 10) < 0.011, `${label} „${t.text}": pismo ${px.toFixed(3)} px (ocakavam 11, medzery 10)`);
    const b = box(t);
    const EPS = 0.01;
    ok(b.x0 >= vb[0] - EPS && b.x1 <= vb[0] + vb[2] + EPS && b.y0 >= vb[1] - EPS && b.y1 <= vb[1] + vb[3] + EPS,
       `${label} „${t.text}" je orezany: text ${JSON.stringify(b)} vs viewBox ${JSON.stringify(vb)}`);
  });
  return { svg, vb, s };
}
{
  const ctx = H.makeCtx();
  H.CASES.concat(H.EXTRA_CASES).forEach(c => RECTS.forEach(r => {
    const out = checkCase(ctx, c, r, `T2 ${c.id} ${r.w}x${r.h}`);
    near(vm.runInContext('pvS', ctx), out.s, 1e-9, `T2 ${c.id}: pvS = mierka viewBoxu`);
  }));
  // po zoome: viewBox ×0.5 a ×2 (pvUserView) → pismo kot stale 11 px (R1.4)
  [0.5, 2].forEach(k => ['cab_lower', 'cab_tall', 'fronts_tall', 'zones_4', 'cab_corner_left', 'cab_fridge', 'insert_board'].forEach(id => {
    const c = H.CASES.find(x => x.id === id);
    const ctx2 = H.makeCtx();
    const r = { w: 404, h: 323 };
    H.renderCase(ctx2, c, r);
    vm.runInContext(`(function(){ var cx = pvView.x + pvView.w / 2, cy = pvView.y + pvView.h / 2;
      pvView = { x: cx - pvView.w * ${k} / 2, y: cy - pvView.h * ${k} / 2, w: pvView.w * ${k}, h: pvView.h * ${k} }; pvUserView = true; })()`, ctx2);
    const svg = H.renderCase(ctx2, c, r, { keepView: true });
    const vb = vbOf(ctx2), s = Math.min(r.w / vb[2], r.h / vb[3]);
    near(vm.runInContext('pvS', ctx2), s, 1e-9, `T2 zoom ×${k} ${id}: pvS sleduje aktualny viewBox`);
    H.texts(svg).forEach(t => {
      if (t.text === '?') return;
      const px = parseFloat(t.attrs['font-size']) * s;
      ok(Math.abs(px - 11) < 0.011 || Math.abs(px - 10) < 0.011, `T2 zoom ×${k} ${id} „${t.text}": ${px.toFixed(3)} px`);
    });
  }));
  // chybajuci rozmer okna (Node, zbaleny sektor) → referencia 404 × 323
  const ctx3 = H.makeCtx();
  const c0 = H.CASES[0];
  const noRect = H.renderCase(ctx3, c0, null), sceneNoRect = vbOf(ctx3);
  const ref = H.renderCase(ctx3, c0, { w: 404, h: 323 });
  eq(sceneNoRect, vbOf(ctx3), 'T2 bez rozmeru okna sa kresli ako 404 × 323');
  eq(noRect, ref, 'T2 a kresba je tá istá');
  eq(vm.runInContext('pvLastRect', ctx3) !== null, true, 'T2 skutočný rozmer sa zapamätá pre ResizeObserver');
  H.renderCase(ctx3, c0, null);
  eq(vm.runInContext('pvLastRect', ctx3), null, 'T2 kreslenie na referencii zabudne rozmer (po rozbalení sa musí prekresliť)');
}

// ---- T2b · texty sa navzajom neprekryvaju (vsetky pripady harnessu x 4 rozmery okna) ----
{
  const ctx = H.makeCtx();
  // + uzsia nika chladnicky (box 350 mm): cislo pasma „71" by lezalo pod popiskami hrany
  const narrowBox = { id: 'fridge_narrow', mode: 'cab', type: 'lower', fields: { width: 600, height: 2076, depth: 560 },
    appl: [Object.assign({}, H.BEKO, { box: { x: 20, z: 118, w: 350, h: 1940 } })] };
  H.CASES.concat(H.EXTRA_CASES, [narrowBox]).forEach(c => RECTS.forEach(r => {
    const ts = H.texts(H.renderCase(ctx, c, r)).filter(t => t.text !== '?');
    const bx = ts.map(box);
    for (let i = 0; i < ts.length; i++) for (let j = i + 1; j < ts.length; j++) {
      const a = bx[i], b = bx[j];
      const ox = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0), oy = Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0);
      const sc = Math.min(r.w / vbOf(ctx)[2], r.h / vbOf(ctx)[3]);
      ok(!(ox * sc > 0.5 && oy * sc > 0.5),
         `T2b ${c.id} ${r.w}x${r.h}: „${ts[i].text}" a „${ts[j].text}" sa prekryvaju (${(ox * sc).toFixed(1)} x ${(oy * sc).toFixed(1)} px)`);
    }
  }));
}

// ---- T2c · doska: obrys a sipky su CELE vo viewBoxe aj pri najmensich/najdlhsich rozmeroch (Codex #455 P2) ----
{
  const ctx = H.makeCtx();
  H.EXTRA_CASES.filter(c => c.board).forEach(c => RECTS.forEach(r => {
    const svg = H.renderCase(ctx, c, r);
    const vb = vbOf(ctx), s = Math.min(r.w / vb[2], r.h / vb[3]);
    const L = c.fields.ib_length, Wd = c.fields.ib_width;
    const m = /<rect x="0" y="0" width="([-\d.]+)" height="([-\d.]+)"[^>]*stroke-width="([-\d.]+)" vector-effect="non-scaling-stroke"\/>/.exec(svg);
    ok(m, `T2c ${c.id}: obrys dosky ma hrubku v px (non-scaling-stroke)`);
    const half = parseFloat(m[3]) / 2 / s; // pol hrubky ciary v mm sceny
    ok(0 - half >= vb[0] && L + half <= vb[0] + vb[2] && 0 - half >= vb[1] && Wd + half <= vb[1] + vb[3],
       `T2c ${c.id} ${r.w}x${r.h}: obrys dosky (vratane ciary) je cely vo viewBoxe ${JSON.stringify(vb)}`);
    // sipky smeru dekoru: vsetky body v obryse dosky (nesmu trcat von)
    const pd = /<path d="([^"]+)" stroke="#90a4ae" stroke-width="1.5"/.exec(svg);
    if (c.fields.ib_grain !== 'none') {
      ok(pd, `T2c ${c.id}: sipky su kreslene`);
      const nums = pd[1].match(/-?[\d.]+/g).map(parseFloat);
      for (let i = 0; i < nums.length; i += 2) {
        ok(nums[i] >= -1e-9 && nums[i] <= L + 1e-9 && nums[i + 1] >= -1e-9 && nums[i + 1] <= Wd + 1e-9,
           `T2c ${c.id}: bod sipky (${nums[i]}, ${nums[i + 1]}) lezi mimo dosky ${L} x ${Wd}`);
      }
    }
  }));
  // doska BEZ smeru dekoru: text sa nezmesti do uzkej dosky 10 x 600 (~98 px do 10 mm) -> vynecha sa; na 300 x 300 je
  const nt = id => H.texts(H.renderCase(ctx, H.EXTRA_CASES.find(c => c.id === id), { w: 404, h: 323 })).some(t => t.text === 'bez smeru dekoru');
  eq(nt('board_10x600_nograin'), false, 'T2c uzka doska bez smeru: „bez smeru dekoru" sa nevnuti cez kotu sirky');
  eq(nt('board_300x300'), true, 'T2c doska 300 x 300 bez smeru: text je');
  // bezne dosky maju sipky ako doteraz (hrot 6 mm .. 12 % dlzky, nezmenene)
  const a = PV.nxGrainArrows(2600, 600, 'length')[0];
  near(a.x2 - a.hx1, Math.max(6, 2600 * 0.42 * 0.12), 1e-9, 'T2c hrot sipky bezneho dielu ostal');
}

// ============ T3 · pvFitLabel · popis cela · medzery · popis zony ===========
{
  eq(PV.pvFitLabel(100, ['V 864', '864'], 11), 'V 864', 'T3 dlhý popis sa zmestí');
  eq(PV.pvFitLabel(30, ['sokel 100', '100'], 11), '100', 'T3 dlhý → krátky (len číslo)');
  eq(PV.pvFitLabel(20, ['100'], 11), '', 'T3 ani číslo → „vedľa" (prázdny výsledok)');
  eq(PV.pvFitLabel(PV.DIM_FONT_PX * 0.56 * 3 + 4, ['100'], 11), '100', 'T3 hranica: šírka textu + 4 px rezerva');
  eq(PV.pvFrontLabel(['F1 · zásuvka 760', 'F1 · 760', 'F1'], 150, 100), 'F1 · zásuvka 760', 'T3 popis čela stupeň 1');
  eq(PV.pvFrontLabel(['F1 · zásuvka 760', 'F1 · 760', 'F1'], 60, 100), 'F1 · 760', 'T3 popis čela stupeň 2');
  eq(PV.pvFrontLabel(['F1 · zásuvka 760', 'F1 · 760', 'F1'], 20, 100), 'F1', 'T3 popis čela stupeň 3');
  eq(PV.pvFrontLabel(['F1 · zásuvka 760', 'F1 · 760', 'F1'], 150, 11.9), '', 'T3 panel nižší ako 12 px popis nemá');
  eq(PV.pvFrontLabel(['F1 · zásuvka 760', 'F1 · 760', 'F1'], 150, 12), 'F1 · zásuvka 760', 'T3 panel 12 px popis má');

  // vzdialenost: zvisla kota s tesnym usekom pise cislo VEDLA (vlavo od lavych, vpravo od pravych kot)
  const ctx = H.makeCtx();
  const tall = H.CASES.find(c => c.id === 'cab_tall');
  const svg = H.renderCase(ctx, tall, { w: 404, h: 323 });
  const ts = H.texts(svg);
  const sokel = ts.find(t => t.text === '100');
  ok(sokel && !sokel.attrs.transform && sokel.attrs['text-anchor'] === 'end', 'T3 sokel 100 pri vysokej skrinke: číslo vodorovne VEDĽA kóty, vľavo');
  ok(ts.find(t => t.text === 'telo 2000' && /rotate\(-90/.test(t.attrs.transform || '')), 'T3 vysoká skrinka: dlhý popis „telo 2000" sa pri dlhom useku zmestí');
  ok(ts.find(t => t.text === 'V 2100' && /rotate\(-90/.test(t.attrs.transform || '')), 'T3 vysoká skrinka: „V 2100" pri kóte');
  const low = H.texts(H.renderCase(ctx, H.CASES[0], { w: 404, h: 323 }));
  ok(low.some(t => t.text === 'V 864' && /rotate\(-90/.test(t.attrs.transform)), 'T3 spodná skrinka: „V 864" dlhý popis pri kóte');
  ok(low.some(t => t.text === '100' && /rotate\(-90/.test(t.attrs.transform)), 'T3 spodná skrinka 404 × 323: sokel (26 px) len číslo pri kóte');
  const small = { id: 'small', mode: 'cab', type: 'lower', fields: { width: 300, height: 300, depth: 300 } };
  const lowSmall = H.texts(H.renderCase(ctx, small, { w: 404, h: 323 }));
  ok(lowSmall.some(t => t.text === 'sokel 100' && /rotate\(-90/.test(t.attrs.transform)), 'T3 malá skrinka 300 × 300: dlhý popis „sokel 100" sa zmestí');
  ok(lowSmall.every(t => Math.abs(parseFloat(t.attrs['font-size']) * vm.runInContext('pvS', ctx) - 11) < 0.011), 'T3 malá skrinka: kóty NEnafúknuté (11 px, nie ~15)');

  // popis cela vo vysokej skrinke: tretí stupeň a medzery bez prekryvu
  const ft = H.texts(H.renderCase(ctx, H.CASES.find(c => c.id === 'fronts_tall'), { w: 404, h: 323 }));
  ok(ft.some(t => /^F[12] ·? ?\d*$/.test(t.text) || t.text === 'F2 · 593'), 'T3 vysoké čelá: skrátený popis „F2 · 593"');
  // vysoka skrinka s 5 tesnymi medzerami (cela po 40 mm, pitch 43 mm ~ 5 px): medzery 10 px, rozostup >= 11 px
  const five = { id: 'five', mode: 'fronts', type: 'lower', fields: { width: 600, height: 2100, depth: 560 },
    items: [0, 1, 2, 3, 4, 5].map(i => ({ id: 'F' + (i + 1), type: 'drawer_front', mode: 'fixed', z: 102 + i * 43, height: 40, wings_n: 1, profile: 'none' })) };
  const fv = H.renderCase(ctx, five, { w: 404, h: 323 });
  const vbF = vbOf(ctx), sF = Math.min(404 / vbF[2], 323 / vbF[3]);
  const gaps = H.texts(fv).filter(t => parseFloat(t.attrs['font-size']) * sF < 10.5 && parseFloat(t.attrs['font-size']) * sF > 9.5);
  ok(gaps.length >= 5, 'T3 päť medzier = päť čísel (10 px): ' + gaps.length);
  const ys = gaps.map(t => parseFloat(t.attrs.y) * sF).sort((a, b) => a - b);
  for (let i = 1; i < ys.length; i++) ok(ys[i] - ys[i - 1] >= 11 - 1e-6, `T3 medzery sa neprekrývajú (rozostup ${(ys[i] - ys[i - 1]).toFixed(2)} px)`);
  // aj tesny zhluk medzier ostane v okne (R7) a ma stale 10 / 11 px
  RECTS.forEach(r => checkCase(ctx, five, r, `T3 five ${r.w}x${r.h}`));
  // rozotlacenie popiskov: ciste jadro (y rastie nadol, popisky zdola nahor = klesajuce y)
  eq(PV.nxSpreadLabels([100, 95, 90], 11, -Infinity), [100, 89, 78], 'T3 spread: tesne popisky sa rozotlacia nahor');
  eq(PV.nxSpreadLabels([100, 60, 20], 11, -Infinity), [100, 60, 20], 'T3 spread: vzdialene popisky sa nehybu');
  eq(PV.nxSpreadLabels([100, 95, 90], 11, 85), [107, 96, 85], 'T3 spread: nad horny okraj sa zhluk vrati nadol');
  ok(PV.nxSpreadLabels([100, 99, 98, 97], 11, 80).every((v, i, a) => i === 0 || a[i - 1] - v >= 11 - 1e-9), 'T3 spread: rozostup >= 11 aj po navrate');
  ok(PV.nxSpreadLabels([100, 99, 98, 97], 11, 80)[3] >= 80, 'T3 spread: posledny neprekroci horny okraj');
  // D11: kota sirky Cel visi 18 px pod NAJNIZSIM kreslenym prvkom - aj pod velkym presahom cela dole
  const presah = { id: 'presah80', mode: 'fronts', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    items: [{ id: 'F1', type: 'door', mode: 'fixed', z: -80, height: 400, wings_n: 1, profile: 'none' }] };
  const pr = H.renderCase(ctx, presah, { w: 404, h: 323 });
  const vbP = vbOf(ctx), sP = Math.min(404 / vbP[2], 323 / vbP[3]);
  const wText = H.texts(pr).find(t => /^7\d\d$/.test(t.text) && !/rotate/.test(t.attrs.transform || ''));
  const lineY = parseFloat(wText.attrs.y) + 5 / sP;
  const frontBottom = 14 + 864 + 80; // ry(-80)
  near((lineY - frontBottom) * sP, 18, 0.05, 'T3 D11: kota sirky ciel je 18 px pod presahom cela (nie na pevnom -26 mm)');
  // popis zony sa nekresli, ked sa nezmesti (uzke zony)
  const zn = { id: 'zn', mode: 'zones', type: 'lower', fields: { width: 800, height: 864, depth: 520 },
    zones: [{ id: 'Z1', leaf: false, split: { axis: 'v', count: 2, sizes: [30, 700] }, x: 18, z: 118, w: 764, h: 728, shelves: 0 },
            { id: 'Z1.1', leaf: true, x: 18, z: 118, w: 30, h: 728, shelves: 0 }, { id: 'Z1.2', leaf: true, x: 66, z: 118, w: 716, h: 728, shelves: 0 }] };
  const zt = H.texts(H.renderCase(ctx, zn, { w: 404, h: 323 })).map(t => t.text);
  ok(zt.indexOf('716×728') >= 0 && zt.indexOf('30×728') < 0, 'T3 popis úzkej zóny sa nekreslí, široká ho má');
}

// ---- T3b · cisla medzier po priblizeni (predrecenzia P2): horny okraj je okraj SCENY, nie vyrezu ----
{
  const ctx = H.makeCtx();
  const tall = H.CASES.find(c => c.id === 'fronts_tall');
  const r = { w: 404, h: 323 };
  H.renderCase(ctx, tall, r);
  // priblizit spodok 5 krokov (×1/1,2 na krok)
  vm.runInContext(`(function(){ var k = Math.pow(1 / 1.2, 5);
    pvView = { x: pvView.x, y: pvView.y + pvView.h * (1 - k), w: pvView.w * k, h: pvView.h * k }; pvUserView = true; })()`, ctx);
  const svg = H.renderCase(ctx, tall, r, { keepView: true });
  const vb = vbOf(ctx), s = Math.min(r.w / vb[2], r.h / vb[3]);
  const gaps = H.texts(svg).filter(t => Math.abs(parseFloat(t.attrs['font-size']) * s - 10) < 0.011);
  // medzera medzi F1 a F2: stred z = 1503,5; musi lezat na svojom mieste, nie na okraji vyrezu
  const g3 = gaps.find(t => t.text === '3');
  near(parseFloat(g3.attrs.y), 14 + 2100 - 1503.5, 0.01, 'T3b medzera 3 ostane na svojej vyske (mimo vyrezu), nestiahne sa k okraju priblizeneho vyrezu');
  const g2 = gaps.filter(t => t.text === '2').map(t => parseFloat(t.attrs.y));
  ok(g2.some(y => Math.abs(y - (14 + 2100 - 101)) < 0.01), 'T3b spodna medzera 2 je na svojom mieste');
}

// ---- T3d · ciara sucasnej hrany chladnicky neprestrtne cislo hrany (fit aj zoom) ----
{
  const ctx = H.makeCtx();
  const fr = H.CASES.find(c => c.id === 'cab_fridge');
  const r = { w: 404, h: 323 };
  function check(svg, label){
    const vb = vbOf(ctx), s = Math.min(r.w / vb[2], r.h / vb[3]);
    const edge = /<line x1="[-\d.]+" y1="([-\d.]+)" x2="[-\d.]+" y2="[-\d.]+" stroke="#0e6b7a" stroke-width="2.5"\/>/.exec(svg);
    ok(edge, label + ': ciara hrany existuje');
    const lineY = parseFloat(edge[1]);
    const t = H.texts(svg).find(x => /^(hrana )?695$/.test(x.text));
    ok(t, label + ': cislo hrany existuje');
    const b = box(t);
    ok(b.y1 <= lineY - 1.25 + 1e-6 || b.y0 >= lineY + 1.25 - 1e-6, `${label}: ciara hrany (y ${lineY}) nepretina cislo ${JSON.stringify(b)}`);
    ok(b.y1 <= lineY, label + ': cislo hrany lezi NAD ciarou');
  }
  check(H.renderCase(ctx, fr, r), 'T3d fit');
  [4, 6, 8].forEach(n => {
    H.renderCase(ctx, fr, r);
    // priblizenie n krokov okolo hrany 813 (y = 14 + 2076 − 813)
    vm.runInContext(`(function(){ var k = Math.pow(1 / 1.2, ${n}), cy = 14 + 2076 - 813;
      pvView = { x: pvView.x, y: cy - pvView.h * k / 2, w: pvView.w * k, h: pvView.h * k }; pvUserView = true; })()`, ctx);
    check(H.renderCase(ctx, fr, r, { keepView: true }), 'T3d zoom ' + n + '×');
  });
}

// ---- T3e · rad vodorovnych kot (pvDimHRow): POZITIVNE - popisy sa nestratia, ak je kde (review PR #455) ----
{
  const ctx = H.makeCtx();
  const r = { w: 404, h: 210 };
  const lineOf = svg => parseFloat(/<path stroke-width="1" vector-effect="non-scaling-stroke" d="M[-\d.]+ ([-\d.]+)H/.exec(svg)[1]);
  // zony 600 x 2100, 4 stlpce @404x210: vsetky styri popisy „128", dva v hornom pruhu a dva POD ciarou kot
  const z4 = H.renderCase(ctx, H.EXTRA_CASES.find(c => c.id === 'zones_4_tall'), r);
  const l4 = lineOf(z4);
  const t128 = H.texts(z4).filter(t => t.text === '128');
  eq(t128.length, 4, 'T3e zony 600x2100 @404x210: styri popisy „128" (ziadny sa nestratil)');
  eq(t128.filter(t => parseFloat(t.attrs.y) < l4).length, 2, 'T3e dva popisy nad ciarou kot');
  eq(t128.filter(t => parseFloat(t.attrs.y) > l4).length, 2, 'T3e a dva POD ciarou kot (druhy pruh)');
  // vysoka rohova @404x210: uzky usek CR 1 „50" sa nezmesti a nema kam -> chyba; po priblizeni ×0,25 je spat
  const ct = H.EXTRA_CASES.find(c => c.id === 'cab_corner_tall');
  const c0 = H.texts(H.renderCase(ctx, ct, r)).map(t => t.text);
  ok(c0.indexOf('250') >= 0 && c0.indexOf('50') < 0, 'T3e vysoka rohova @404x210: „250" je, „50" sa nezmesti a vynecha sa (nevnuti sa nad suseda)');
  vm.runInContext(`(function(){ var k = 0.25, cx = pvView.x + pvView.w / 2, cy = pvView.y + pvView.h / 2;
    pvView = { x: cx - pvView.w * k / 2, y: cy - pvView.h * k / 2, w: pvView.w * k, h: pvView.h * k }; pvUserView = true; })()`, ctx);
  const c1 = H.texts(H.renderCase(ctx, ct, r, { keepView: true })).map(t => t.text);
  ok(c1.indexOf('250') >= 0 && c1.indexOf('50') >= 0, 'T3e po priblizeni ×0,25 sa „50" vrati');
  // useky z roznych radov zon: „564" (spodny rad) a stredne „176" (horny rad) maju ten isty stred - obe zostanu, jedna pod ciarou
  const zo = H.renderCase(ctx, H.EXTRA_CASES.find(c => c.id === 'zones_overlap_rows'), { w: 404, h: 323 });
  const lo = lineOf(zo);
  const tz = H.texts(zo).filter(t => t.text === '564' || t.text === '176');
  eq(tz.map(t => t.text).sort(), ['176', '176', '176', '564'], 'T3e prekryvajuce sa useky: vsetky styri popisy su');
  const mid = tz.filter(t => Math.abs(parseFloat(t.attrs.x) - (14 + 300)) < 0.01);
  eq(mid.length, 2, 'T3e a dva z nich (564 a stredne 176) maju rovnaky stred');
  ok(mid.some(t => parseFloat(t.attrs.y) > lo) && mid.some(t => parseFloat(t.attrs.y) < lo), 'T3e jeden nad ciarou a jeden pod nou');
}

// ---- T3c · D11: dokreslene vrstvy su v obsahu sceny (predrecenzia P3) ----
{
  const r = { w: 404, h: 323 };
  function layerOn(ctx, mode, key){
    vm.runInContext(`NXLayers.reset(); NXLayers.toggle(${JSON.stringify(mode)}, ${JSON.stringify(key)}, pvAvail());`, ctx);
  }
  // spodny okraj druhych rozmerov sa meria v suradniciach kresby: ry(z) = 14 + H − z
  function lowestWidthDim(svg, ctx, label){
    const vb = vbOf(ctx), s = Math.min(r.w / vb[2], r.h / vb[3]);
    const t = H.texts(svg).find(x => x.text === label && !/rotate/.test(x.attrs.transform || ''));
    return { lineY: parseFloat(t.attrs.y) + 5 / s, vb: vb, s: s };
  }
  // 1) horna skrinka, cela s presahom −20, vrstva Cela zapnuta v Korpuse
  {
    const ctx = H.makeCtx();
    const c = { id: 'upper_presah', mode: 'cab', type: 'upper', fields: { width: 800, height: 720, depth: 320, floor_height: 0 },
      items: [{ id: 'F1', type: 'door', mode: 'fixed', z: -20, height: 740, wings_n: 1, profile: 'none' }] };
    H.renderCase(ctx, c, r);
    layerOn(ctx, 'cab', 'cela');
    const svg = H.renderCase(ctx, c, r);
    ok(svg.indexOf('stroke-dasharray="9 6"') >= 0, 'T3c-1 vrstva Cela (ghost obrys cela) sa v Korpuse naozaj kresli');
    const d = lowestWidthDim(svg, ctx, 'Š 800') ;
    const frontBottom = 14 + 720 + 20;
    near((d.lineY - frontBottom) * d.s, 18, 0.05, 'T3c-1 kota sirky je 18 px pod presahom cela (−20)');
    ok(d.vb[1] + d.vb[3] >= frontBottom + 6 / d.s - 0.01, 'T3c-1 presah cela nie je orezany');
    vm.runInContext('NXLayers.reset()', ctx);
    ok(H.renderCase(ctx, c, r).indexOf('stroke-dasharray="9 6"') < 0, 'T3c-1 bez zapnutej vrstvy ghost obrys cela nie je');
  }
  // 2) Zony, sokel 0 + nohy, vrstva Kovanie
  {
    const ctx = H.makeCtx();
    const base = H.CASES.find(c => c.id === 'zones_4');
    const c = Object.assign({}, base, { id: 'zones_legs', fields: Object.assign({}, base.fields, { floor_height: 0 }),
      hw: [{ owner_part_key: 'cabinet:leg', generic_type: 'leg', quantity: 4, label: 'Nohy' }] });
    H.renderCase(ctx, c, r);
    layerOn(ctx, 'zones', 'kovanie');
    const svg = H.renderCase(ctx, c, r);
    ok(svg.indexOf('<g pointer-events="none" opacity="0.75">') >= 0 && svg.indexOf('#b0bec5') >= 0, 'T3c-2 nohy (ghost Kovanie, tlmena znacka) sa v Zonach naozaj kreslia');
    const d = lowestWidthDim(svg, ctx, '178');
    const legBottom = 14 + 864 + 70;
    ok(d.lineY >= legBottom - 0.01, 'T3c-2 kota sirky zony nejde cez nohy (visi pod nimi)');
    near((d.lineY - legBottom) * d.s, 18, 0.05, 'T3c-2 a je 18 px pod nohami');
    ok(d.vb[1] + d.vb[3] >= legBottom + 6 / d.s - 0.01, 'T3c-2 nohy nie su orezane');
  }
  // 3) mala skrinka 300 x 300, sokel 0 + nohy, vrstva Kovanie v Korpuse
  {
    const ctx = H.makeCtx();
    const c = { id: 'small_legs', mode: 'cab', type: 'lower', fields: { width: 300, height: 300, depth: 300, floor_height: 0 },
      hw: [{ owner_part_key: 'cabinet:leg', generic_type: 'leg', quantity: 4, label: 'Nohy' }] };
    H.renderCase(ctx, c, r);
    layerOn(ctx, 'cab', 'kovanie');
    const svg = H.renderCase(ctx, c, r);
    const d = lowestWidthDim(svg, ctx, 'Š 300');
    const legBottom = 14 + 300 + 70;
    near((d.lineY - legBottom) * d.s, 18, 0.05, 'T3c-3 kota sirky je 18 px pod nohami (−70 mm)');
    ok(d.vb[1] + d.vb[3] >= legBottom + 6 / d.s - 0.01, 'T3c-3 nohy nie su orezane');
    // bez zapnutej vrstvy sa nic nerezervuje
    vm.runInContext('NXLayers.reset()', ctx);
    const plain = H.renderCase(ctx, c, r);
    const d0 = lowestWidthDim(plain, ctx, 'Š 300');
    near((d0.lineY - (14 + 300)) * d0.s, 18, 0.05, 'T3c-3 bez vrstvy kota visi 18 px pod korpusom');
  }
  vm.runInContext('NXLayers.reset()', H.makeCtx());
}

// ============ T4 · bez „mm"; čiara kót 1 px ===================================
{
  const ctx = H.makeCtx();
  H.CASES.forEach(c => {
    const svg = H.renderCase(ctx, c, { w: 404, h: 323 });
    H.texts(svg).forEach(t => ok(!/mm/.test(t.text), `T4 ${c.id}: v popise „${t.text}" je mm`));
    ok(!/stroke-width="1\.4"/.test(svg), `T4 ${c.id}: ciara kót nie je 1,4 mm`);
    const dimG = svg.match(/<g stroke="#90a4ae" stroke-width="1" vector-effect="non-scaling-stroke" fill="none" pointer-events="none">/g) || [];
    const paths = svg.match(/<path stroke-width="1" vector-effect="non-scaling-stroke" d=/g) || [];
    if (c.id !== 'hw_lower') ok(dimG.length >= 1, `T4 ${c.id}: kóty sú 1 px non-scaling-stroke (g)`);
    eq(paths.length, dimG.length * 2, `T4 ${c.id}: aj kazda ciara kóty (path) je non-scaling-stroke`);
  });
  // hlbka: mrtva vetva „hĺbka … mm" zanikla
  ok(!/hĺbka/.test(fs.readFileSync(path.join(H.JS, 'preview.js'), 'utf8').replace(/\/\/.*$/gm, '')), 'T4 mŕtva vetva „hĺbka … mm" je preč');
}

// ============ T5 · prekreslenie (R6) ===========================================
{
  function mkEnv(){
    const ctx = H.makeCtx();
    const raf = [];
    ctx.requestAnimationFrame = fn => { raf.push(fn); return raf.length; };
    let renders = 0;
    const orig = ctx.renderPreview;
    ctx.renderPreview = function(){ renders++; return orig.apply(this, arguments); };
    ctx.document.addEventListener = () => {};
    const handlers = {};
    ctx.__svg.addEventListener = (type, fn) => { handlers[type] = fn; };
    let roCb = null, observed = 0;
    ctx.ResizeObserver = function(cb){ roCb = cb; this.observe = () => { observed++; }; };
    return { ctx, raf, handlers, count: () => renders, ro: () => roCb, observed: () => observed };
  }
  const env = mkEnv(), ctx = env.ctx;
  H.renderCase(ctx, H.CASES[0], { w: 404, h: 323 });
  vm.runInContext('previewBound = false', ctx);
  ctx.setupPreviewDelegation();
  ok(typeof env.handlers.wheel === 'function', 'T5 koliesko je zaregistrované');
  ok(typeof env.ro() === 'function' && env.observed() === 1, 'T5 ResizeObserver sleduje #preview');
  const before = env.count();
  const wheel = d => env.handlers.wheel({ ctrlKey: true, deltaY: d, clientX: 100, clientY: 100, preventDefault(){} });
  wheel(100); wheel(100); wheel(-100);
  eq(env.raf.length, 1, 'T5 Ctrl+koliesko naplánuje práve JEDNO prekreslenie na snímku');
  env.raf.shift()();
  eq(env.count(), before + 1, 'T5 po snímke sa prekreslilo raz');
  wheel(100);
  eq(env.raf.length, 1, 'T5 ďalší krok = ďalšie jedno prekreslenie');
  env.raf.shift()();
  // koliesko bez Ctrl nič nenaplánuje
  env.handlers.wheel({ ctrlKey: false, deltaY: 100, preventDefault(){} });
  eq(env.raf.length, 0, 'T5 koliesko bez Ctrl nič nenaplánuje (scroll panela)');
  // pan nenaplánuje prekreslenie
  ctx.startPan({ clientX: 10, clientY: 10 });
  ctx.onPanMove({ clientX: 60, clientY: 40 });
  ctx.endPan();
  eq(env.raf.length, 0, 'T5 pan (posun pohľadu) prekreslenie nenaplánuje');
  // ResizeObserver: 1 px zmena prekreslí, rovnaká veľkosť nie, w < 50 nie
  const roFire = (w, h) => { ctx.__svg.rect = { w: w, h: h }; env.ro()(); };
  const r0 = env.count();
  roFire(404, 323);
  eq(env.raf.length, 0, 'T5 rovnaká veľkosť (ako sa kreslilo) nič nenaplánuje');
  roFire(405, 323);
  eq(env.raf.length, 1, 'T5 zmena šírky o 1 px naplánuje prekreslenie');
  env.raf.shift()();
  eq(env.count(), r0 + 1, 'T5 a prekreslilo sa');
  roFire(405, 323);
  eq(env.raf.length, 0, 'T5 po prekreslení rovnaká veľkosť už nie');
  roFire(30, 300);
  roFire(300, 40);
  roFire(0, 0);
  eq(env.raf.length, 0, 'T5 w < 50 / h < 50 (zbalený sektor) nič nenaplánuje');
  roFire(405, 324);
  eq(env.raf.length, 1, 'T5 zmena výšky o 1 px prekreslí');
  env.raf.shift()();
  // počas ťahania priečky sa neplánuje
  vm.runInContext('dragState = { zid: "x" }', ctx);
  wheel(100);
  roFire(500, 324);
  eq(env.raf.length, 0, 'T5 počas ťahania priečky sa prekreslenie neplánuje');
  vm.runInContext('dragState = null', ctx);
  // bez requestAnimationFrame: fallback setTimeout 16 (jedno prekreslenie)
  const e2 = mkEnv();
  delete e2.ctx.requestAnimationFrame;
  const timers = [];
  e2.ctx.setTimeout = (fn, ms) => { timers.push([fn, ms]); return timers.length; };
  H.renderCase(e2.ctx, H.CASES[0], { w: 404, h: 323 });
  e2.ctx.pvScheduleRender(); e2.ctx.pvScheduleRender();
  eq(timers.length, 1, 'T5 fallback: jeden setTimeout');
  eq(timers[0][1], 16, 'T5 fallback: 16 ms');
  // bez ResizeObserver (Node) sa nič neregistruje
  const e3 = mkEnv();
  delete e3.ctx.ResizeObserver;
  H.renderCase(e3.ctx, H.CASES[0], { w: 404, h: 323 });
  vm.runInContext('previewBound = false', e3.ctx);
  e3.ctx.setupPreviewDelegation();
  eq(e3.observed(), 0, 'T5 bez ResizeObserver sa nič neregistruje');
}

// ============ T6 · interakcia ostala v mm ======================================
{
  const ctx = H.makeCtx();
  const z = H.CASES.find(c => c.id === 'zones_4');
  const svg = H.renderCase(ctx, z, { w: 404, h: 323 });
  eq((svg.match(/class="zrect"/g) || []).length, 4, 'T6 štyri klikateľné zóny');
  const zr = [...svg.matchAll(/class="zrect" data-zid="([^"]+)" x="([-\d.]+)" y="([-\d.]+)" width="([-\d.]+)" height="([-\d.]+)"/g)];
  zr.forEach((m, i) => {
    const zone = z.zones[i + 1];
    near(parseFloat(m[4]), zone.w, 1e-9, 'T6 šírka zóny v mm modelu');
    near(parseFloat(m[5]), zone.h, 1e-9, 'T6 výška zóny v mm modelu');
    near(parseFloat(m[2]), 14 + zone.x, 1e-9, 'T6 poloha zóny: pad 14 mm + x');
  });
  eq((svg.match(/class="divh"/g) || []).length, 3, 'T6 tri ťahateľné priečky');
  (svg.match(/class="divh"[^>]*width="([-\d.]+)"/g) || []).forEach(m => ok(/width="18"/.test(m), 'T6 priečka je široká 18 mm (hrúbka dielca)'));
  // viewMapping (tahanie priecky) berie mierku z viewBoxu a rovna sa pvS
  const vb = vbOf(ctx);
  near(ctx.viewMapping({ width: 404, height: 323 }).s, vm.runInContext('pvS', ctx), 1e-9, 'T6 ťahanie priečky: viewMapping.s = pvS');
  ok(Math.abs(vb[0] + vb[2] / 2 - (14 + 400)) < 60, 'T6 viewBox ostáva v mm modelu (stred ~ stred skrinky)');
  // znacky kovania: ostavaju klikatelne a nesu vlastnika
  const hw = H.renderCase(ctx, H.CASES.find(c => c.id === 'hw_lower'), { w: 404, h: 323 });
  const marks = hw.match(/<g class="hwmk" data-owner="[^"]*"/g) || [];
  ok(marks.length >= 8, 'T6 znacky kovania sú klikateľné a nesú vlastníka: ' + marks.length);
  ok(hw.indexOf('front:F2/wing:left') >= 0 && hw.indexOf('data-tip=') >= 0, 'T6 vlastník aj bublina značky ostali');
  // KOVANIE ma bez textov: ziadny <text> okrem prip. symbolov
  eq(H.texts(hw).filter(t => t.text !== '?').length, 0, 'T6 Kovanie je bez textov (O9)');
  // čelá: klikateľná skupina čela ostáva
  const fr = H.renderCase(ctx, H.CASES.find(c => c.id === 'fronts_tall'), { w: 404, h: 323 });
  eq((fr.match(/<g class="fgrp" data-front-id="F\d"/g) || []).length, 2, 'T6 čelá sú klikateľné skupiny');
}

console.log('test_h6c_koty: ' + n + ' kontrol OK');
