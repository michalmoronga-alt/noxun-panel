// H6b (blok 9 HARDENING, D-05 + pas D-01) - lišty sektorov a súhrny v Inspectore.
//   node tests/js/test_h6b_suhrny.js
//
// Co sa tu strazi (package H6, H6b T0-T7):
//   T0 golden STARYCH cistych funkcii `metaDims` / `metaMaterials` / `nxHwSummary`
//      (`tests/fixtures/h6b_suhrny.json`, vyrobeny jednorazovo nad mainom 0.17.17) -
//      H6b ich NEMENI, lista S1 a S4 Kovania ich len znovu pouzije,
//   T1 `sectorMeta().s1link` = rozmery (rovnaka funkcia ako S2) LEN pri cab x
//      {zony, cela, kovanie}; rohova nesie „dvere vlavo 450" aj v odkaze,
//   T2 S4 = SUHRN OBSAHU (O12): Korpus 3 x 2 x 5 kombinacii + neznama hodnota +
//      slot, Zony (listy bez `deep`, police), Cela, Kovanie (null / [] / typy);
//      otvorena skupina suhrn NEMENI,
//   T4 meta skupin Kovania: Polozky („6 ks · 2 ručne"), Sety („1 vlastný"),
//   T5 odkaz S1 v DOM (vm): viditelnost, text zo ZIVYCH poli, bublina z materialu
//      (zmeni sa po premenovani dekoru cez `NX.setMaterials`), klik odkaz
//      prepne na Korpus a zastavi natívny toggle <summary>,
//   T6 kresba Kovania BEZ textov (ziadny suhrn ani nahradna veta) a scena bez
//      rezervy −96 mm (nohy pod korpusom len ked sokel = 0),
//   T7 obnova: zdrojova kontrola v tests/pure/test_uib1_kostra.rb (guard).
// (T3 - O7 „Spolocne pre skrinku" - je v test_d130b_spolocne.js.)
// MUTACIE (kazda overena rucne - po zanesi chyby do kodu spadne uvedena aserciu):
//   M1 `s1link` aj v Korpuse                       -> T1 „Korpus: ziadny odkaz"
//   M2 `nxS1Link` bez `nxTipStop`                  -> T5 „klik odkazu nezbali sektor"
//   M3 S4 pri otvorenej skupine vrati jej nazov    -> T2 „otvorena skupina suhrn nemeni"
//   M4 `two_rails` ako „plný strop"                -> T2 „Korpus: vsetkych 30 kombinacii"
//   M5 Zony ratanie aj `deep`                      -> T2 „Zony: 4. uroven sa nerata"
//   M8 Sety ignoruju `override_selector`           -> T4 „Sety: selector"
//   M9 `drawHwBase` kresli suhrn                   -> T6 „kresba Kovania bez textov"
//   M11 `renderS1Link` vypadne zo `setMaterials`   -> T5 „premenovany dekor zmeni bublinu"
'use strict';
global.nxDocGuid = () => '';
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');

const ROOT = path.join(__dirname, '..', '..');
const JS = path.join(ROOT, 'noxun_engine', 'ui', 'js');
const NXShell = require(path.join(JS, 'shell.js'));
const PV = require(path.join(JS, 'preview.js'));
const CORE = require(path.join(JS, 'core.js'));
const TYPES = require('./nx_types_fixture.js');
const GOLD = JSON.parse(fs.readFileSync(path.join(ROOT, 'tests', 'fixtures', 'h6b_suhrny.json'), 'utf8'));

let n = 0;
function plain(v){ return (v && typeof v === 'object') ? JSON.parse(JSON.stringify(v)) : v; }
function eq(a, b, msg){ n++; assert.deepStrictEqual(plain(a), plain(b), msg + ': cakam ' + JSON.stringify(b) + ', dostal ' + JSON.stringify(a)); }
function ok(c, msg){ n++; assert.ok(c, msg); }
const meta = s => NXShell.sectorMeta(s);

// ============ T0 · golden starych funkcii ====================================
eq(GOLD.states.length, 9, 'T0: golden ma 9 stavov');
GOLD.states.forEach(function(s){
  const m = meta({ mode: 'cab', ctx: 'korpus', dims: s.dims, materials: s.materials });
  eq(m.s2, s.s2, 'T0 ' + s.id + ': metaDims (S2) sa nezmenil');
  eq(m.s3, s.s3, 'T0 ' + s.id + ': metaMaterials (S3) sa nezmenil');
  eq(PV.nxHwSummary(s.hw), s.hw_summary, 'T0 ' + s.id + ': nxHwSummary sa nezmenil');
});
eq(PV.nxHwSummary(null), GOLD.hw_summary_null, 'T0: nxHwSummary(null) sa nezmenil');

// ============ T1 · s1link =====================================================
{
  const SPODNA = { w: 800, h: 864, d: 520, plinth: 100 };
  ['zony', 'cela', 'kovanie'].forEach(function(c){
    eq(meta({ mode: 'cab', ctx: c, dims: SPODNA }).s1link, '800 × 864 × 520 · sokel 100',
       'T1: ' + c + ' - odkaz nesie rozmery (rovnaka funkcia ako S2)');
    eq(meta({ mode: 'cab', ctx: c, dims: SPODNA }).s1link, meta({ mode: 'cab', ctx: c, dims: SPODNA }).s2,
       'T1: ' + c + ' - s1link === s2');
    eq(meta({ mode: 'cab', ctx: c, dims: SPODNA }).s1, PV_TITLE_OF(c), 'T1: ' + c + ' - s1 ostava nazov projekcie (zaloha)');
  });
  eq(meta({ mode: 'cab', ctx: 'korpus', dims: SPODNA }).s1link, '', 'T1 (M1): Korpus - ziadny odkaz');
  eq(meta({ mode: 'cab', ctx: 'nieco', dims: SPODNA }).s1link, '', 'T1: neznamy kontext = Korpus - ziadny odkaz');
  ['part', 'board', 'insert'].forEach(function(m){
    eq(meta({ mode: m, ctx: 'zony', dims: SPODNA }).s1link, '', 'T1: ' + m + ' - ziadny odkaz');
  });
  // Rohova: „dvere vlavo 450" je aj v odkaze (odkaz preberá S2 rohovej).
  eq(meta({ mode: 'cab', ctx: 'cela', dims: { w: 1100, h: 864, d: 520, plinth: 100, corner: { side: 'left', door: 450 } } }).s1link,
     '1100 × 864 × 520 · sokel 100 · dvere vľavo 450', 'T1: rohova - odkaz nesie aj dvere');
  // Nekompletne rozmery: odkaz sa neukaze (nic sa nevymysla), lista nesie nazov projekcie.
  eq(meta({ mode: 'cab', ctx: 'zony', dims: { w: 800, h: 864 } }).s1link, '', 'T1: nekompletne rozmery - bez odkazu');
  // Horna skrinka: bez sokla.
  eq(meta({ mode: 'cab', ctx: 'cela', dims: { w: 800, h: 720, d: 320, plinth: 100, plinth_visible: false } }).s1link,
     '800 × 720 × 320', 'T1: horna - bez sokla');
}
function PV_TITLE_OF(c){ return { zony: 'Zóny', cela: 'Čelá', kovanie: 'Kovanie — pozície' }[c]; }

// ============ T2 · S4 = suhrn obsahu ==========================================
{
  const TOP = { full: 'plný strop', two_rails: 'strop 2 výstuhy', none: 'bez stropu' };
  const BOT = { under_sides: 'boky na dne', between_sides: 'dno medzi bokmi' };
  const BACK = { overlay: 'chrbát naložený', inset: 'chrbát vložený', groove: 'chrbát v drážke',
                 rails: 'chrbát z líšt', none: 'bez chrbta' };
  let combos = 0;
  Object.keys(TOP).forEach(function(t){ Object.keys(BOT).forEach(function(b){ Object.keys(BACK).forEach(function(k){
    combos++;
    eq(meta({ mode: 'cab', ctx: 'korpus', content: { korpus: { carcass: true, top: t, bottom: b, back: k } } }).s4,
       TOP[t] + ' · ' + BOT[b] + ' · ' + BACK[k], 'T2 (M4) Korpus: ' + [t, b, k].join('/'));
  }); }); });
  eq(combos, 30, 'T2: Korpus - vsetkych 30 kombinacii');
  eq(meta({ mode: 'cab', ctx: 'korpus', content: { korpus: { top: 'two_rails', bottom: 'under_sides', back: 'groove' } } }).s4,
     'strop 2 výstuhy · boky na dne · chrbát v drážke', 'T2: priklad z mockupu');
  // Neznama hodnota (novsi plugin) cast VYNECHA.
  eq(meta({ mode: 'cab', ctx: 'korpus', content: { korpus: { top: 'novy_strop', bottom: 'under_sides', back: 'groove' } } }).s4,
     'boky na dne · chrbát v drážke', 'T2: neznamy strop vypadne');
  eq(meta({ mode: 'cab', ctx: 'korpus', content: { korpus: { top: '', bottom: '', back: '' } } }).s4, '',
     'T2: prazdne hodnoty = ziadne meta');
  eq(meta({ mode: 'cab', ctx: 'korpus', content: { korpus: { top: 'toString', bottom: 'constructor', back: '__proto__' } } }).s4, '',
     'T2: kluce z prototypu nie su slova');
  // Slot umyvacky (typ bez korpusu) - D6.
  eq(meta({ mode: 'cab', ctx: 'korpus', content: { korpus: { carcass: false, top: 'full', bottom: 'under_sides', back: 'groove' } } }).s4,
     '', 'T2 (D6): slot - Korpus bez meta');

  // Zony.
  const leaf = (shelves, extra) => Object.assign({ leaf: true, shelves: shelves, deep: false }, extra || {});
  const split = { leaf: false, shelves: 0, deep: false };
  function zones(zs){ return meta({ mode: 'cab', ctx: 'zony', content: { zones: zs } }).s4; }
  eq(zones([leaf(0)]), '1 zóna · prázdna', 'T2: Zony - 1 prazdna');
  eq(zones([leaf(1)]), '1 zóna · 1 polica', 'T2: Zony - 1 zona s policou');
  eq(zones([leaf(3)]), '1 zóna · 3 police', 'T2: Zony - 1 zona, 3 police');
  eq(zones([leaf(5)]), '1 zóna · 5 políc', 'T2: Zony - 1 zona, 5 políc');
  eq(zones([split, leaf(1), leaf(2)]), '2 zóny · 3 police', 'T2: Zony - 2 zony (delena zona sa nerata)');
  eq(zones([split, leaf(0), leaf(0)]), '2 zóny', 'T2: Zony - viac listov bez políc = len pocet');
  eq(zones([split, leaf(0), leaf(0), leaf(0), leaf(0), leaf(0)]), '5 zón', 'T2: Zony - 5+ zon');
  eq(zones([split, leaf(0), leaf(0), leaf(0)]), '3 zóny', 'T2: Zony - 3 zony');
  eq(zones([split, leaf(1), leaf(1), leaf(1), leaf(1)].concat([leaf(1)])), '5 zón · 5 políc', 'T2: Zony - 5 zon, 5 políc');
  eq(zones([split, leaf(2), leaf(0, { deep: true })]), '1 zóna · 2 police', 'T2 (M5) Zony: 4. uroven (deep) sa nerata');
  eq(zones([]), '', 'T2: Zony - bez stromu');
  eq(zones(null), '', 'T2: Zony - chybajuce data');
  eq(zones([leaf('x')]), '1 zóna · prázdna', 'T2: Zony - neciselne police = 0');
  eq(zones([leaf(-3)]), '1 zóna · prázdna', 'T2: Zony - zaporne police = 0');

  // Cela - texty skladaju core.js funkcie (jedna cesta s metou skupin).
  function fronts(cnt, unset, decor, g, opts){
    return meta({ mode: 'cab', ctx: 'cela', content: { fronts: { count: cnt,
      count_text: CORE.frontCountText(cnt, unset), common_text: CORE.cabfrontMetaText(decor, g, opts) } } }).s4;
  }
  const GAPS = { gap: 3, top: 2, bottom: 2, left: 2, right: 2 };
  eq(fronts(1, 0, 'F206 ST9 Pietra Grigia čierna · DTDL 18 mm', GAPS), '1 čelo · F206 ST9 · medzera 3 · okraje 2',
     'T2: Cela - priklad z mockupu');
  eq(fronts(2, 0, '', GAPS), '2 čelá · medzera 3 · okraje 2', 'T2: Cela - 2 čelá, bez dekoru');
  eq(fronts(3, 1, 'Dub', GAPS), '3 čelá · 1 bez smeru · Dub · medzera 3 · okraje 2', 'T2: Cela - bez smeru');
  eq(fronts(5, 0, 'Dub', Object.assign({}, GAPS, { bottom: -20 })), '5 čiel · Dub · medzera 3 · okraje 2 · dole -20',
     'T2: Cela - vynimka okraja');
  eq(fronts(0, 0, 'Dub', GAPS), 'bez čiel', 'T2 (D6): Cela - 0 ciel = „bez čiel"');
  eq(fronts(1, 0, 'Dub', null), '1 čelo', 'T2: Cela - bez skrinky (g == null) ostane len pocet');
  eq(meta({ mode: 'cab', ctx: 'cela' }).s4, '', 'T2: Cela - chybajuci obsah = ziadne meta');

  // Kovanie - ten isty nxHwSummary ako kresba.
  const HW3 = [{ label: 'Nohy', generic_type: 'leg', quantity: 4 }, { label: 'Výsuv', generic_type: 'slide', quantity: 1 },
               { label: 'Príchyt sokla', generic_type: 'plinth_clip', quantity: 1 }];
  const hw = items => meta({ mode: 'cab', ctx: 'kovanie', content: { hw: { items: items, summary: PV.nxHwSummary(items) } } }).s4;
  eq(hw(HW3), 'Nohy 4× · Výsuv 1× · Príchyt sokla 1×', 'T2: Kovanie - 3 typy');
  eq(hw(null), '', 'T2: Kovanie - nic neoznacene');
  eq(hw([]), 'bez kovania', 'T2 (D6): Kovanie - prazdne pole');
  eq(meta({ mode: 'cab', ctx: 'kovanie' }).s4, '', 'T2: Kovanie - chybajuci obsah');
  // Rucne pridane polozky (hwManualView) su tiez kovanie (P2): „· N ručne", len rucne „N ručne",
  // „bez kovania" az ked su prazdne OBE (zhodne s metou skupiny Polozky, D14).
  const hwm = (items, manual) => meta({ mode: 'cab', ctx: 'kovanie',
    content: { hw: { items: items, summary: PV.nxHwSummary(items), manual: manual } } }).s4;
  eq(hwm(HW3, 2), 'Nohy 4× · Výsuv 1× · Príchyt sokla 1× · 2 ručne', 'T2 (P2): pravidla + rucne');
  eq(hwm([], 1), '1 ručne', 'T2 (P2): len rucna polozka - nie „bez kovania"');
  eq(hwm([], 0), 'bez kovania', 'T2 (P2): prazdne obe = „bez kovania"');
  eq(hwm(HW3, 0), 'Nohy 4× · Výsuv 1× · Príchyt sokla 1×', 'T2 (P2): bez rucnych bez zmeny');
  eq(hwm(null, 3), '', 'T2 (P2): nic neoznacene');
  eq(hwm([], undefined), 'bez kovania', 'T2: chybajuci pocet rucnych = 0');

  // Otvorena skupina suhrn NEMENI (O12) - ani zbalena, ani rozbalena.
  const c1 = { korpus: { top: 'full', bottom: 'under_sides', back: 'groove' } };
  ['Strop', 'Dno & podstavec', '', null].forEach(function(open){
    eq(meta({ mode: 'cab', ctx: 'korpus', content: c1, groups: { open: open, count: 4 }, s4_name: 'Nastavenia' }).s4,
       'plný strop · boky na dne · chrbát v drážke', 'T2 (M3): otvorena skupina "' + open + '" suhrn nemeni');
  });
  eq(meta({ mode: 'cab', ctx: 'cela', content: { fronts: { count: 1, count_text: '1 čelo', common_text: '' } },
            groups: { open: 'Čelá', count: 2 }, s4_name: 'Čelá' }).s4, '1 čelo', 'T2: Cela - nazov sektora v meta nie je');
  // Cistota: vstup sa nemeni.
  const vstup = { mode: 'cab', ctx: 'kovanie', content: { hw: { items: HW3, summary: 'x' } } };
  const kopia = JSON.parse(JSON.stringify(vstup));
  meta(vstup);
  eq(vstup, kopia, 'T2: sectorMeta nesiaha na vstup');
}

// ============ T4 · meta skupin Kovania =========================================
{
  const HW = require(path.join(JS, 'hardware.js'));
  const it = q => ({ generic_type: 'leg', quantity: q });
  eq(HW.hwItemsMetaText([it(4), { generic_type: 'hinge', quantity: 2 }], []), '6 ks', 'T4: Polozky - sucet poctov');
  eq(HW.hwItemsMetaText([it(4), it('x'), it(-2), it(0), null], []), '4 ks', 'T4: Polozky - nulove a necielne mnozstva sa nerataju');
  eq(HW.hwItemsMetaText([it('3')], []), '3 ks', 'T4: Polozky - cislo ako text');
  eq(HW.hwItemsMetaText([it(4)], [{ id: 'a' }, { id: 'b' }]), '4 ks · 2 ručne', 'T4 (D14): Polozky - rucne polozky');
  eq(HW.hwItemsMetaText([], [{ id: 'a' }]), '1 ručne', 'T4: Polozky - len rucne');
  eq(HW.hwItemsMetaText([], []), '', 'T4: Polozky - nic');
  eq(HW.hwItemsMetaText(null, [{ id: 'a' }]), '', 'T4: Polozky - bez skrinky je meta prazdna');
  eq(HW.hwItemsMetaText([it(2)], undefined), '2 ks', 'T4: Polozky - chybajuci zoznam rucnych');

  const E = o => Object.assign({ generic_type: 'hinge', override_set_id: null, override_selector: null, owner_overrides: {} }, o || {});
  eq(HW.hwSetsMetaText([]), '', 'T4 (D13): Sety - prazdna ponuka');
  eq(HW.hwSetsMetaText(null), '', 'T4: Sety - chybajuca ponuka');
  eq(HW.hwSetsMetaText([E()]), 'podľa projektu', 'T4: Sety - ziadny vlastny vyber');
  eq(HW.hwSetsMetaText([E({ override_set_id: 'S1' })]), '1 vlastný', 'T4: Sety - skrinkovy vyber');
  eq(HW.hwSetsMetaText([E({ override_selector: { param: 'x' } })]), '1 vlastný', 'T4 (M8): Sety - selector');
  eq(HW.hwSetsMetaText([E({ owner_overrides: { 'front:F1/wing:single': { set_id: 'S2' } } })]), '1 vlastný',
     'T4: Sety - vyber pri cele');
  eq(HW.hwSetsMetaText([E({ owner_overrides: { 'front:F1': { selector: true, label: 'p' }, 'front:F2': { invalid: true } } })]),
     '2 vlastné', 'T4: Sety - selector a poskodeny zapis pri celach');
  eq(HW.hwSetsMetaText([E({ override_set_id: 'S1', owner_overrides: { a: { set_id: 'x' }, b: { set_id: 'y' } } }),
                        E({ generic_type: 'slide', override_set_id: 'S3' })]), '4 vlastné', 'T4: Sety - 2-4');
  eq(HW.hwSetsMetaText([E({ override_set_id: 'S1', owner_overrides: { a: {}, b: {}, c: {}, d: {} } })]), '5 vlastných', 'T4: Sety - 5+');
  // Klasifikovana zasuvka: vyber je v `compat` (nie v override_set_id) a neratá sa dvakrat.
  const compat = { cab: { current: 'c1', stored: false }, owners: { 'front:F1': { current: null, stored: true }, 'front:F2': { current: null, stored: false } } };
  eq(HW.hwSetsMetaText([E({ generic_type: 'slide', compat: compat, owner_overrides: { 'front:F1': { set_id: 'c9' } } })]),
     '2 vlastné', 'T4: Sety - compat: skrinka + ulozeny vyber pri cele, bez dvojitého rátania');
  eq(HW.hwSetsMetaText([E({ generic_type: 'slide', compat: { cab: null, owners: {} } })]), 'podľa projektu',
     'T4: Sety - compat bez vyberu');
}

// ============ vm kontext pre DOM cesty (T5, T6) ================================
function fakeEl(attrs){
  const a = Object.assign({}, attrs || {});
  const cls = new Set();
  return {
    attrs: a, hidden: false, disabled: false, title: '', value: '', innerHTML: '', textContent: '', className: '', style: {},
    getAttribute(k){ return Object.prototype.hasOwnProperty.call(a, k) ? a[k] : null; },
    setAttribute(k, v){ a[k] = String(v); },
    removeAttribute(k){ delete a[k]; },
    querySelector(){ return null; }, querySelectorAll(){ return []; },
    classList: { add(c){ cls.add(c); }, remove(c){ cls.delete(c); }, contains(c){ return cls.has(c); },
                 toggle(c, on){ if (on === undefined ? !cls.has(c) : on) cls.add(c); else cls.delete(c); } }
  };
}
function mkCtx(ids){
  const byId = ids || {};
  const ctx = { console, setTimeout, clearTimeout, window: {}, JSON, Math };
  ctx.document = { getElementById: id => byId[id] || null, querySelectorAll: () => [], querySelector: () => null,
                   addEventListener(){}, body: fakeEl(), createElement: () => fakeEl() };
  ctx.el = id => byId[id] || null;
  vm.createContext(ctx);
  return ctx;
}
function load(ctx, file){
  vm.runInContext(fs.readFileSync(path.join(JS, file), 'utf8'), ctx, { filename: file });
  if (file === 'core.js') TYPES.fill(ctx);
}

// ============ T5 · odkaz S1 v DOM =============================================
{
  const ids = {};
  ['s1Meta', 's1Link', 's1LinkTxt', 's2Meta', 's3Meta', 's4Meta', 's4Name'].forEach(id => { ids[id] = fakeEl(); });
  ids.s1Link.hidden = true;
  const ctx = mkCtx(ids);
  load(ctx, 'core.js');
  ctx.NXTypes = TYPES.NXTypes;
  load(ctx, 'shell.js');
  // Formular: rozmery panela (zdroj lisity Zakladne aj odkazu).
  const F = { width: 800, height: 864, depth: 520, floor_height: 100, top_mode: 'two_rails', bottom_mode: 'under_sides', back_mode: 'groove' };
  ctx.numv = id => (F[id] === undefined ? NaN : parseFloat(F[id]));
  ids.top_mode = fakeEl(); ids.bottom_mode = fakeEl(); ids.back_mode = fakeEl();
  const sync = () => { ['top_mode', 'bottom_mode', 'back_mode'].forEach(k => { ids[k].value = F[k]; }); };
  sync();
  ctx.getType = () => 'lower';
  ctx.computeZones = () => [{ id: 'Z1', path: [1], leaf: false, shelves: 0 }, { id: 'Z1.1', path: [1, 1], leaf: true, shelves: 2 },
                            { id: 'Z1.2', path: [1, 2], leaf: true, shelves: 1 }];
  ctx.cabTabPreview = () => 'cab'; ctx.renderPreview = () => {}; ctx.refreshZoneUI = () => {};
  ctx.nxHwSummary = PV.nxHwSummary; // v CEF ho dodava preview.js (globalna funkcia)
  // Zhodne s form.js `nxTipStop` (D-130a): klik v <summary> nesmie zbalit sektor.
  ctx.nxTipStop = ev => { ev.preventDefault(); ev.stopPropagation(); };
  const sh = vm.runInContext('NXShell', ctx);
  sh.track('cab', sh.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: 'G' }));

  // Korpus: odkaz skryty, lista nesie nazov projekcie.
  sh.setCtx('korpus');
  ctx.nxSectorMetaApply();
  eq(ids.s1Link.hidden, true, 'T5: Korpus - odkaz skryty');
  eq(ids.s1Meta.hidden, false, 'T5: Korpus - nazov projekcie viditelny');
  eq(ids.s1Meta.textContent, 'Čelný rez + kóty', 'T5: Korpus - nazov projekcie');
  eq(ids.s4Meta.textContent, 'strop 2 výstuhy · boky na dne · chrbát v drážke', 'T5: Korpus - S4 suhrn zo ZIVYCH selectov');
  // Zmena selectu = nova lista (nic sa necachuje).
  F.back_mode = 'overlay'; sync();
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, 'strop 2 výstuhy · boky na dne · chrbát naložený', 'T5: zmena chrbta sa prejavi hned');
  // Zony: odkaz s rozmermi z polí, S1 nazov schovany, S4 suhrn stromu.
  sh.setCtx('zony');
  ctx.nxSetS1LinkTitle('K2738 MO');
  ctx.nxSectorMetaApply();
  eq(ids.s1Link.hidden, false, 'T5: Zony - odkaz viditelny');
  eq(ids.s1LinkTxt.textContent, '800 × 864 × 520 · sokel 100', 'T5: Zony - text odkazu = rozmery zo ZIVYCH poli');
  eq(ids.s1Meta.hidden, true, 'T5: Zony - nazov projekcie sa schova (odkaz ho nahradi)');
  eq(ids.s1Link.getAttribute('title'), 'Materiál korpusu: K2738 MO — klik otvorí kontext Korpus', 'T5: bublina nesie material');
  eq(ids.s1Link.getAttribute('aria-label'),
     '800 × 864 × 520 · sokel 100 — Materiál korpusu: K2738 MO — klik otvorí kontext Korpus',
     'T5 (P3-4): aria-label = viditelny text rozmerov + bublina (Label in Name)');
  eq(ids.s4Meta.textContent, '2 zóny · 3 police', 'T5: Zony - S4 suhrn (listy, police)');
  F.width = 900;
  ctx.nxSectorMetaApply();
  eq(ids.s1LinkTxt.textContent, '900 × 864 × 520 · sokel 100', 'T5: zmena sirky sa prejavi v odkaze hned');
  // Kovanie: suhrn z hwItems.
  sh.setCtx('kovanie');
  ctx.hwItems = [{ label: 'Nohy', generic_type: 'leg', quantity: 4 }];
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, 'Nohy 4×', 'T5: Kovanie - S4 suhrn kovania');
  ctx.hwItems = [];
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, 'bez kovania', 'T5: Kovanie - prazdne kovanie');
  ctx.hwItems = [];
  ctx.hwManualView = [{ id: 'm1' }];
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, '1 ručne', 'T5 (P2): Kovanie - len rucna polozka');
  ctx.hwItems = [{ label: 'Nohy', generic_type: 'leg', quantity: 4 }];
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, 'Nohy 4× · 1 ručne', 'T5 (P2): Kovanie - pravidla + rucna');
  ctx.hwManualView = [];
  ctx.hwItems = null;
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, '', 'T5: Kovanie - nic neoznacene');
  // Cela: pocet + spolocne.
  sh.setCtx('cela');
  ctx.nxFrontCounts = () => ({ n: 2, unset: 1 });
  ctx.nxCabfrontText = () => 'F206 ST9 · medzera 3 · okraje 2';
  ctx.nxSectorMetaApply();
  eq(ids.s4Meta.textContent, '2 čelá · 1 bez smeru · F206 ST9 · medzera 3 · okraje 2', 'T5: Cela - S4 suhrn');
  // Dielec: odkaz zmizne.
  sh.track('part', sh.identityOf('part', { cabinet_id: 'CAB-001', role_key: 'side_left', model_guid: 'G' }));
  ctx.nxSectorMetaApply();
  eq(ids.s1Link.hidden, true, 'T5: dielec - odkaz skryty');
  eq(ids.s4Meta.textContent, '', 'T5: dielec - S4 bez meta');
  sh.track('cab', sh.identityOf('cab', { cabinet_id: 'CAB-001', model_guid: 'G' }));
  sh.setCtx('zony');

  // Klik na odkaz: prepne na Korpus a ZASTAVI natívny toggle <summary> (M2).
  let prevented = 0, stopped = 0;
  const ev = { preventDefault(){ prevented++; }, stopPropagation(){ stopped++; } };
  ctx.nxS1Link(ev);
  eq([prevented, stopped], [1, 1], 'T5 (M2): klik odkazu nezbali sektor (preventDefault + stopPropagation)');
  eq(sh.effectiveCtx(), 'korpus', 'T5: klik prepol kontext na Korpus');
  ctx.nxSectorMetaApply();
  eq(ids.s1Link.hidden, true, 'T5: v Korpuse odkaz zmizne');
}

// ============ T5b · bublina sa meni po premenovani dekoru (bridge) =============
{
  const ctx = mkCtx();
  ctx.titles = [];
  ctx.nxSetS1LinkTitle = t => { ctx.titles.push(t); };
  ctx.nxSectorMetaApply = () => {};
  let name = 'Dub Halifax';
  ctx.sheetLabelOf = id => (id === 'm1' ? name : '');
  ['refreshMaterialFilters', 'refreshInsertBoardMaterials'].forEach(k => { ctx[k] = () => {}; });
  load(ctx, 'bridge.js');
  ctx.setS1Link({ cabinet_id: 'CAB-001', material_id: 'm1' });
  eq(ctx.titles.slice(-1)[0], 'Dub Halifax', 'T5b: bublina nesie popis materialu z katalogu');
  name = 'Dub Halifax tmavý';
  ctx.window.NX.setMaterials({ sheets: [], edges: [] });
  eq(ctx.titles.slice(-1)[0], 'Dub Halifax tmavý', 'T5b (M11): premenovany dekor zmeni bublinu bez noveho vyberu');
  ctx.setS1Link({ cabinet_id: 'CAB-002', material_id: '' });
  eq(ctx.titles.slice(-1)[0], 'dedí z projektu', 'T5b: prazdny material = dedi z projektu');
  ctx.setS1Link(null);
  eq(ctx.titles.slice(-1)[0], '', 'T5b: bez skrinky bez materialu');
}

// ============ T6 · kresba Kovania bez textov, scena bez rezervy −96 ============
{
  const svg = fakeEl();
  const ctx = mkCtx({ preview: svg });
  load(ctx, 'core.js');
  load(ctx, 'preview.js');
  ctx.__fields = {};
  ctx.numv = id => (ctx.__fields[id] === undefined ? NaN : parseFloat(ctx.__fields[id]));
  ctx.val = id => (ctx.__fields[id] === undefined ? '' : String(ctx.__fields[id]));
  ctx.esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  ctx.NXIcons = { svg: id => '<svg><use href="#i-' + id + '"/></svg>', set(){} };
  ctx.clearFrontHover = () => {};
  ctx.computeZones = () => [{ id: 'Z1', leaf: true, x: 18, z: 18, w: 764, h: 828, shelves: 0 }];
  ctx.fullZoneId = z => 'CAB-1-' + z;
  ctx.PALETTE = ['#aaa'];
  ctx.getInsertKind = () => 'cabinet';
  ctx.selectedCabId = 'CAB-1';
  ctx.currentZoneTree = null;
  const PAD = vm.runInContext('PV_PAD', ctx);
  function render(fh, items){
    vm.runInContext('pvUserView = false; pvView = null; frontDraft = null;', ctx);
    ctx.setType('lower');
    ctx.__fields = { width: 800, height: 864, depth: 520, thickness: 18, floor_height: fh, fr_gap_left: 2, fr_gap_right: 2,
                     fr_gap: 3, fr_gap_top: 2, top_mode: 'full', back_mode: 'overlay' };
    ctx.frontOpening = null; ctx.frontItems = []; ctx.frontSlots = {}; ctx.hwItems = items;
    vm.runInContext("previewMode = 'hw'", ctx);
    ctx.renderPreview();
    const vb = svg.getAttribute('viewBox').split(/\s+/).map(parseFloat);
    return { html: svg.innerHTML, vb: vb };
  }
  const LEG = { label: 'Nohy', generic_type: 'leg', quantity: 4 };
  const SLIDE = { label: 'Výsuv', generic_type: 'slide', quantity: 1 };
  const NOTXT = (r, msg) => {
    ok(r.html.indexOf('Nohy 4×') < 0 && r.html.indexOf('Výsuv 1×') < 0, 'T6 (M9): ' + msg + ' - kresba bez suhrnu');
    ok(r.html.indexOf('nemá kovanie') < 0, 'T6: ' + msg + ' - ani nahradna veta „Skrinka zatiaľ nemá kovanie"');
  };
  // Sokel 100: nohy stoja v sokli (z >= 0) - rezerva dole 0, scena = vyska skrinky + 2 PAD.
  let r = render(100, [LEG, SLIDE]);
  NOTXT(r, 'sokel');
  eq(r.vb[3], 864 + 2 * PAD, 'T6: sokel > 0 - scena nema rezervu dole (bola 96 mm)');
  // Bez sokla visia nohy POD korpusom (70 mm) - rezerva len na ne.
  r = render(0, [LEG]);
  NOTXT(r, 'bez sokla');
  eq(r.vb[3], 864 + 70 + 2 * PAD, 'T6: sokel = 0 - rezerva len na nohy (70 mm)');
  // Bez nohy ziadna rezerva ani pri sokli 0.
  r = render(0, [SLIDE]);
  eq(r.vb[3], 864 + 2 * PAD, 'T6: bez noh - ziadna rezerva dole');
  r = render(100, []);
  NOTXT(r, 'prazdne kovanie');
  ok(r.html.indexOf('<text') < 0 || r.html.indexOf('hrana') < 0, 'T6: prazdne kovanie - ziadne texty v kresbe');
  // P3-3: cela s okrajom dole −20 (horna skrinka bez sokla, ghost Čelá) a `cr_front` rohovej
  // nesmu byt v scene Kovania orezane (rezerva −96 mm uz nie je).
  {
    const FR = [{ id: 'F1', type: 'door', mode: 'auto', z: -20, height: 700, wings_n: 1, profile: 'none' }];
    vm.runInContext('pvUserView = false; pvView = null; frontDraft = null;', ctx);
    ctx.setType('upper');
    ctx.__fields = { width: 800, height: 720, depth: 320, thickness: 18, floor_height: 0, fr_gap_left: 2, fr_gap_right: 2,
                     fr_gap: 3, fr_gap_top: 2, top_mode: 'full', back_mode: 'overlay' };
    ctx.frontOpening = null; ctx.frontItems = FR; ctx.frontSlots = {}; ctx.hwItems = [SLIDE];
    vm.runInContext("previewMode = 'hw'", ctx);
    ctx.renderPreview();
    const vb2 = svg.getAttribute('viewBox').split(/\s+/).map(parseFloat);
    ok(vb2[1] + vb2[3] >= 720 + 20 + PAD, 'T6 (P3-3): cela presahujuce dole −20 je v scene Kovania (spodok viewBoxu ' + (vb2[1] + vb2[3]) + ')');
    // Rohova: dielec zostavy siaha pod korpus.
    ctx.setType('corner_blind');
    ctx.cornerPreview = { parts: [{ role: 'cr_front', x0: 650, x1: 1100, z0: -60, z1: 700 }], dims: [], fits: true };
    ctx.__fields = { width: 1100, height: 862, depth: 510, thickness: 18, floor_height: 0, fr_gap_left: 2, fr_gap_right: 2,
                     fr_gap: 3, fr_gap_top: 2, top_mode: 'full', back_mode: 'overlay' };
    ctx.frontOpening = { x0: 650, w: 450 }; ctx.frontItems = []; ctx.hwItems = [];
    vm.runInContext('pvUserView = false; pvView = null;', ctx);
    ctx.renderPreview();
    const vb3 = svg.getAttribute('viewBox').split(/\s+/).map(parseFloat);
    ok(vb3[1] + vb3[3] >= 862 + 60 + PAD, 'T6 (P3-3): cr_front rohovej je v scene Kovania (spodok viewBoxu ' + (vb3[1] + vb3[3]) + ')');
    ctx.cornerPreview = null;
  }
  // Ciste jadro rezervy.
  eq(PV.nxHwLowestZ([LEG], 0), -70, 'T6: nxHwLowestZ - nohy bez sokla');
  eq(PV.nxHwLowestZ([LEG], 100), 0, 'T6: nxHwLowestZ - nohy v sokli');
  eq(PV.nxHwLowestZ([SLIDE], 0), 0, 'T6: nxHwLowestZ - bez noh');
  eq(PV.nxHwLowestZ(null, 0), 0, 'T6: nxHwLowestZ - bez dat');
  eq(PV.nxLegGeom(0), { lw: 42, lh: 70, z0: -70 }, 'T6: geometria nohy bez sokla');
  eq(PV.nxLegGeom(100), { lw: 42, lh: 90, z0: 0 }, 'T6: geometria nohy v sokli');
  // Znacky noh sa nezmenili (rovnaka geometria ako pred refaktorom).
  const marks = PV.nxHwMarks([LEG], { W: 800, fh: 0, fronts: [] });
  eq(marks.length, 4, 'T6: 4 nohy');
  eq([marks[0].z, marks[0].h, marks[0].w], [-70, 70, 42], 'T6: znacka nohy bez sokla');
}

console.log('test_h6b_suhrny: ' + n + ' OK');
