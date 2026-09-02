// Testy stavu vkladacej karty D-32/D-33/D-39 (insert_state.js) — dependency-free
// Node (node tests/js/test_insert_state.js). Modul je cisty (bez DOM), exportuje
// cez module.exports (rovnaky vzor ako expr.js/usage.js). Pokryva: prechodovy
// automat rezimov (reset LEN pri skutocnom prechode do insert — audit B2), zamky
// poli (whitelist, hodnoty, roundtrip Ruby<->JS — audit B5), skladanie zdroja
// karty (sablona NAD defaultmi — D-32/D-33), zamok prebije sablonu (D-39),
// materialy zo sablony (audit F6) a IMUTABILITU sablony (audit N11 — deep freeze).
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const ins = require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'insert_state.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}
function deepFreeze(o){
  Object.freeze(o);
  Object.keys(o).forEach(function(k){
    if (o[k] && typeof o[k] === 'object' && !Object.isFrozen(o[k])) deepFreeze(o[k]);
  });
  return o;
}

// --- needsReset: reset LEN pri skutocnom prechode do insert (audit B2) ---
eq(ins.needsReset(null, 'insert'), true, 'boot -> insert resetuje');
eq(ins.needsReset('cab', 'insert'), true, 'cab -> insert resetuje');
eq(ins.needsReset('part', 'insert'), true, 'part -> insert resetuje');
eq(ins.needsReset('board', 'insert'), true, 'board -> insert resetuje');
eq(ins.needsReset('insert', 'insert'), false, 'insert -> insert NEresetuje (rozpisane upravy preziju)');
eq(ins.needsReset('insert', 'cab'), false, 'insert -> cab neresetuje');
eq(ins.needsReset('cab', 'part'), false, 'cab -> part neresetuje');

// --- trackMode: pamata rezim a hlasi reset ---
ins.state.lastMode = null;
eq(ins.trackMode('insert'), true, 'trackMode: prvy vstup do insert');
eq(ins.trackMode('insert'), false, 'trackMode: insert sync bez resetu');
eq(ins.trackMode('cab'), false, 'trackMode: odchod na cab');
eq(ins.trackMode('insert'), true, 'trackMode: navrat cab -> insert');
eq(ins.trackMode('board'), false, 'trackMode: odchod na board');
eq(ins.trackMode('insert'), true, 'trackMode: navrat board -> insert');
eq(ins.state.lastMode, 'insert', 'trackMode: lastMode aktualny');

// --- zamky: whitelist poli + platne hodnoty (D-39) ---
ins.setLocksFlat({});
eq(ins.setLock('width', 950), true, 'setLock sirka 950');
eq(ins.isLocked('width'), true, 'isLocked po setLock');
eq(ins.setLock('bogus', 100), false, 'setLock mimo whitelistu odmietnuty');
eq(ins.setLock('height', 'abc'), false, 'setLock s nezmyslom odmietnuty');
eq(ins.isLocked('height'), false, 'neplatny setLock nezamkol');
eq(ins.setLock('floor_height', '150'), true, 'setLock cislo v stringu (JSON z Ruby)');
eq(ins.updateLockValue('depth', 500), false, 'updateLockValue na odomknutom = false');
eq(ins.updateLockValue('width', 900), true, 'updateLockValue na zamknutom');
eq(ins.locksFlat(), { width: 900, floor_height: 150 }, 'locksFlat = ploche zamknute polia');
ins.clearLock('floor_height');
eq(ins.locksFlat(), { width: 900 }, 'clearLock odstranil zamok');

// --- serializacia Ruby <-> JS (audit B5): roundtrip + sanitizacia ---
ins.setLocksFlat({ width: 950, floor_height: 150, bogus: 9, height: 'x' });
eq(ins.locksFlat(), { width: 950, floor_height: 150 }, 'setLocksFlat: whitelist + cisla, zvysok zahodeny');
eq(ins.state.locks.width, { locked: true, value: 950 }, 'vnutorny tvar {locked, value} (audit B1)');
ins.setLocksFlat(null);
eq(ins.locksFlat(), {}, 'setLocksFlat(null) = ziadne zamky');

// --- composeSource: sablona NAD defaultmi = plny obraz karty (D-32/D-33) ---
const DEFAULTS = { type: 'lower', width: 600, height: 720, depth: 510, thickness: 18,
                   floor_height: 100, plinth_recess: 40, fronts: 'none' };
const TPL = deepFreeze({ type: 'lower', width: 450, height: 900,
                         material_id: 'K009_PW_DTDL_18', front_material_id: 'FRONT_W_18',
                         fronts: { gap: 3, items: [{ id: 'F1', type: 'door' }] },
                         zone_tree: { id: 'Z1', shelves: 2, children: [] } });
const src = ins.composeSource(DEFAULTS, TPL);
eq(src.width, 450, 'compose: sablona prebije default');
eq(src.depth, 510, 'compose: chybajuci kluc sablony = default (ziadne zvysky karty)');
eq(src.plinth_recess, 40, 'compose: legacy sablona bez plinth_recess dostane default');
eq(src.material_id, 'K009_PW_DTDL_18', 'compose: material sablony sa nesie (audit F6)');
src.width = 111; // mutacia vysledku...
eq(TPL.width, 450, 'compose: ...sa NEDOTKNE sablony (novy objekt)');
eq(DEFAULTS.width, 600, 'compose: ...ani defaultov');

// --- applyLocks: zamok prebije sablonu aj defaulty (D-39, poradie F7) ---
ins.setLocksFlat({ height: 950 });
const src2 = ins.applyLocks(ins.composeSource(DEFAULTS, TPL));
eq(src2.height, 950, 'zamknuta vyska prebila sablonu (900 -> 950)');
eq(src2.width, 450, 'nezamknute pole ostava zo sablony');
eq(TPL.height, 900, 'applyLocks nemutuje sablonu (bezi na compose kopii)');

// --- materialsOf: sablonove materialy / prazdne = null (dedenie z projektu) ---
eq(ins.materialsOf({}), { material_id: null, front_material_id: null, back_material_id: null },
  'bez sablony ziadne materialy (dedenie)');
eq(ins.materialsOf({ material_id: 'K009', front_material_id: '', back_material_id: null }),
  { material_id: 'K009', front_material_id: null, back_material_id: null },
  'prazdny string = null (dedenie), hodnota sa nesie');
ins.setMaterials(TPL);
eq(ins.state.materials.material_id, 'K009_PW_DTDL_18', 'setMaterials do stavu karty');
ins.setMaterials(null);
eq(ins.state.materials, { material_id: null, front_material_id: null, back_material_id: null },
  'setMaterials(null) = cisty draft');

// --- N11: cela cesta compose+locks+materials NAD ZAMRAZENOU sablonou nehodi
//     vynimku a sablona ostava byte-identicka (JS strana imutability) ---
const tplJson = JSON.stringify(TPL);
ins.setLocksFlat({ width: 950, thickness: 18 });
const full = ins.applyLocks(ins.composeSource(DEFAULTS, TPL));
ins.setMaterials(full);
eq(JSON.stringify(TPL), tplJson, 'sablona po celom insert toku byte-nezmenena');
eq(full.width, 950, 'zamok v plnom toku aplikovany');

// --- H2 (D-76): kovanie zo sablony vo vkladacej karte ---
const TPL_HW = deepFreeze({
  type: 'lower', width: 600,
  hardware_sets: { hinge: 'zaves-klasik', slide: { param: 'front_height', bands: [] } },
  hardware_set_defs: { 'zaves-klasik': { set_id: 'zaves-klasik', generic_type: 'hinge' } }
});
// KOV-H1: `hardware_manual` je TRETI kluc kovania sablony (pole, nie mapa).
const HW_EMPTY = { hardware_sets: null, hardware_set_defs: null, hardware_manual: null };
eq(ins.hardwareOf({}), HW_EMPTY, 'sablona bez kovania = ziadne kluce');
eq(ins.hardwareOf({ hardware_sets: {}, hardware_set_defs: {}, hardware_manual: [] }),
  HW_EMPTY, 'prazdne mapy AJ prazdne pole = null (do payloadu sa neposielaju)');
eq(ins.hardwareOf({ hardware_set_defs: { x: {} } }), HW_EMPTY,
  'definicie BEZ mapovania nemaju co zmrazit');
eq(ins.hardwareOf({ hardware_sets: 'nezmysel', hardware_manual: 'nezmysel' }), HW_EMPTY,
  'necakany tvar sa zahodi (server je aj tak autorita)');
const hw = ins.hardwareOf(TPL_HW);
eq(hw.hardware_sets, TPL_HW.hardware_sets, 'mapovanie sablony sa nesie');
eq(Object.keys(hw.hardware_set_defs), ['zaves-klasik'], 'definicie sa nesu');
hw.hardware_sets.hinge = 'zmena'; // mutacia vysledku...
eq(TPL_HW.hardware_sets.hinge, 'zaves-klasik', '...sa NEDOTKNE sablony (kopia mapy, N11)');

ins.setHardware(TPL_HW);
eq(ins.hardwarePayload().hardware_sets.hinge, 'zaves-klasik', 'payload nesie mapovanie');
eq(Object.keys(ins.hardwarePayload()).sort(), ['hardware_set_defs', 'hardware_sets'],
  'payload nesie oba kluce');
ins.setHardware(ins.composeSource(DEFAULTS, null)); // zrusenie vyberu sablony
eq(ins.hardwarePayload(), {}, 'zrusenie sablony stav VYCISTI (bezny vklad nenesie kovanie)');
ins.setHardware(ins.composeSource(DEFAULTS, TPL_HW));
eq(ins.hardwarePayload().hardware_sets.hinge, 'zaves-klasik',
  'vyber sablony cez composeSource stav naplni');
ins.setHardware(ins.composeSource(DEFAULTS, TPL)); // ina sablona BEZ kovania
eq(ins.hardwarePayload(), {}, 'prepnutie na sablonu bez kovania stav vycisti');

// --- KOV-H1: ad-hoc polozky kovania zo sablony (pole, pass-through) ---
const TPL_ADHOC = deepFreeze({
  type: 'lower', width: 600,
  hardware_manual: [{ id: 'H1', source: 'free', code: '', name: 'Zámok Abloy',
    unit: 'ks', price_eur_vat: 12.0, qty: 1, note: '', owner_part_key: null }]
});
const adhoc = ins.hardwareOf(TPL_ADHOC);
eq(adhoc.hardware_manual.length, 1, 'ad-hoc polozky sablony sa nesu');
eq(adhoc.hardware_manual[0].name, 'Zámok Abloy', 'zaznam ide TAK, AKO PRISIEL zo servera');
eq(adhoc.hardware_sets, null, 'ad-hoc polozky su NEZAVISLE od mapovania setov');
adhoc.hardware_manual.push({ id: 'X' }); // mutacia vysledku...
eq(TPL_ADHOC.hardware_manual.length, 1, '...sa NEDOTKNE sablony (kopia pola, N11)');

ins.setHardware(TPL_ADHOC);
eq(Object.keys(ins.hardwarePayload()), ['hardware_manual'],
  'sablona LEN s ad-hoc polozkami posiela LEN ten kluc');
ins.setHardware(ins.composeSource(DEFAULTS, TPL)); // sablona bez kovania
eq(ins.hardwarePayload(), {}, 'prepnutie na sablonu bez ad-hoc poloziek stav vycisti');
eq(ins.HARDWARE_LIST_KEYS, ['hardware_manual'], 'zoznam POLOVYCH klucov kovania je kontrakt');

// --- UI-C1a: druh sablony (identita = kind + name) ---
eq(ins.templateKind({ name: 'A', kind: 'cabinet' }), 'cabinet', 'explicitny kind cabinet');
eq(ins.templateKind({ name: 'A', kind: 'board' }), 'board', 'explicitny kind board');
eq(ins.templateKind({ name: 'A', config: { type: 'lower' } }), 'cabinet',
  'legacy zaznam bez kind je korpusovy');
eq(ins.templateKind({ name: 'A', config: { type: 'board' } }), 'board',
  'bez kind sa druh odvodi z redundantneho config.type');
// Codex #174 P2: EXPLICITNY neznamy kind (zaznam z novsej verzie) sa NIKDY
// nepreklasifikuje na korpus — prejde filtrami ako „ani cabinet, ani board".
eq(ins.templateKind({ name: 'A', kind: 'fancy', config: { type: 'lower' } }), 'fancy',
  'neznamy kind ostava neznamy (nie korpusovy)');
eq(ins.templateKind({ name: 'A', kind: '', config: { type: 'board' } }), 'board',
  'prazdny kind = odvodenie z config.type');
eq(ins.templateKind(null), 'cabinet', 'prazdny vstup nespadne');

const LIB = [
  { name: 'Dolna klasik', kind: 'cabinet', config: { type: 'lower' } },
  { name: 'Zástena', kind: 'board', config: { type: 'board' } },
  { name: 'Zástena', kind: 'cabinet', config: { type: 'upper' } },
  { name: 'Legacy', config: { type: 'lower' } },
  { name: 'Zostava', kind: 'fancy', config: { type: 'lower' } } // z novsej verzie
];
eq(ins.templatesOfKind(LIB, 'cabinet').map(function(t){ return t.name; }),
  ['Dolna klasik', 'Zástena', 'Legacy'], 'filter kind: korpusove (vratane legacy bez kind)');
eq(ins.templatesOfKind(LIB, 'board').length, 1, 'filter kind: doskove');
eq(ins.templatesOfKind(LIB, 'board')[0].name, 'Zástena',
  'rovnake meno v inom druhu je INA sablona');
eq(ins.templatesOfKind(LIB, 'cabinet').concat(ins.templatesOfKind(LIB, 'board'))
    .some(function(t){ return t.name === 'Zostava'; }), false,
  'neznamy druh sa NEPONUKNE ani ako korpus, ani ako doska');
eq(ins.templatesOfKind(null, 'cabinet'), [], 'prazdna kniznica nespadne');

// ===== UI-C1b: typ vkladania, vyber sablony, zamky dosky, poradie dlazdic =====

// --- typ = JEDNA volba z troch (segmentove tlacidla) ---
ins.state.type = 'lower'; ins.state.kind = 'cabinet';
ins.state.template = ''; ins.state.boardTemplate = '';
eq(ins.insertType(), 'lower', 'vychodzi typ je dolna skrinka');
eq(ins.setInsertType('lower'), false, 'klik na uz zvoleny typ nic nemeni');
eq(ins.setInsertType('upper'), true, 'prepnutie na hornu');
eq(ins.insertType(), 'upper', 'typ sa zapamatal');
eq(ins.setInsertType('nezmysel'), true, 'neznamy typ padne na dolnu…');
eq(ins.insertType(), 'lower', '…a je to dolna skrinka');
eq(ins.setInsertType('board'), true, 'prepnutie na dosku');
eq(ins.insertType(), 'board', 'doska je vlastny typ');
eq(ins.state.type, 'lower', 'typ KORPUSU sa pri doske nezabuda');
eq(ins.setInsertType('lower'), true, 'navrat na korpus');
eq(ins.state.kind, 'cabinet', 'druh je zase korpus');

// --- vyber sablony: dva sklady (korpus / doska), identita = kind + name ---
ins.setTemplateName('cabinet', 'Dolna klasik');
ins.setTemplateName('board', 'Zástena');
eq(ins.templateName('cabinet'), 'Dolna klasik', 'korpusovy vyber');
eq(ins.templateName('board'), 'Zástena', 'doskovy vyber je INY sklad');
eq(ins.templateRef(), { kind: 'cabinet', name: 'Dolna klasik' }, 'payload ref podla zvoleneho typu');
ins.setInsertType('board');
eq(ins.templateRef(), { kind: 'board', name: 'Zástena' }, 'pri doske ide do payloadu doskova sablona');
ins.setInsertType('lower');
eq(ins.templateRef(), { kind: 'cabinet', name: 'Dolna klasik' }, 'navrat ukaze povodny korpusovy vyber');
// Zmena TYPU KORPUSU vyber zahadzuje (ponuka je typovo filtrovana — D-32),
// prepnutie Korpus<->Doska NIE (kazdy druh si drzi svoj).
ins.setInsertType('upper');
eq(ins.templateName('cabinet'), '', 'zmena typu korpusu zahodila sablonu');
eq(ins.templateName('board'), 'Zástena', 'doskovy vyber zmenou typu korpusu netrpi');
ins.setInsertType('board');
ins.setInsertType('upper');
eq(ins.templateName('board'), 'Zástena', 'prepnutie Doska->Korpus doskovy vyber nezhodilo');
ins.setTemplateName('cabinet', null);
eq(ins.templateRef(), null, 'bez sablony sa peciatka neposiela');

// --- zamky DOSKY: vlastne kluce a VLASTNE ulozisko (Codex FIX 12) ---
ins.setLocksFlat({ width: 950 });                  // korpusovy zamok
eq(ins.setLock('length', 2600, 'board'), true, 'zamok dlzky dosky');
eq(ins.setLock('width', 580, 'board'), true, 'zamok sirky dosky');
eq(ins.setLock('height', 700, 'board'), false, 'korpusove pole doska nezamkne');
eq(ins.isLocked('width', 'board'), true, 'doskova sirka je zamknuta');
eq(ins.locksFlat('board'), { length: 2600, width: 580 }, 'doskove zamky maju vlastnu sadu');
eq(ins.locksFlat(), { width: 950 },
  'kanal do Ruby nesie LEN korpusove zamky (server doskove nepozna)');
eq(ins.applyLocks({ length: 800, width: 600 }, 'board'), { length: 2600, width: 580 },
  'doskovy zamok prebije sablonu');
eq(ins.applyLocks({ width: 450, height: 720 }), { width: 950, height: 720 },
  'korpusovy zamok pracuje nezmenene (rovnake meno, ina velicina)');
ins.clearLock('length', 'board');
eq(ins.locksFlat('board'), { width: 580 }, 'odomknutie dosky');
eq(ins.updateLockValue('width', 620, 'board'), true, 'edit zamknuteho doskoveho pola');
eq(ins.locksFlat('board').width, 620, 'zamok drzi to, co pouzivatel vidi');
eq(ins.locksFlat().width, 950, 'korpusovy zamok sa tym NEZMENIL');
ins.clearLock('width', 'board');
ins.setLocksFlat(null);

// --- ponuka dlazdic: filter podla typu + „nedavne prve" (N16) ---
const LIB2 = [
  { name: 'Dolna 2 dvierka', kind: 'cabinet', config: { type: 'lower' }, used_seq: 2 },
  { name: 'Horna klasik', kind: 'cabinet', config: { type: 'upper' }, used_seq: 9 },
  { name: 'Drezova 900', kind: 'cabinet', config: { type: 'lower' }, used_seq: 7 },
  { name: 'Legacy dolna', config: { type: 'lower' } },              // bez kind aj bez pouzitia
  { name: 'Varna 600', kind: 'cabinet', config: { type: 'lower' }, used_seq: 5 },
  { name: 'Diel', kind: 'board', config: { type: 'board', thickness: 18 }, used_seq: 3 },
  { name: 'Pracovná doska', kind: 'board', config: { type: 'board', thickness: 38 } }
];
eq(ins.templatesForType(LIB2, 'lower').map(function(t){ return t.name; }),
  ['Dolna 2 dvierka', 'Drezova 900', 'Legacy dolna', 'Varna 600'],
  'dolna: korpusove sablony typu lower (legacy bez type = lower)');
eq(ins.templatesForType(LIB2, 'upper').map(function(t){ return t.name; }), ['Horna klasik'],
  'horna: len upper');
eq(ins.templatesForType(LIB2, 'board').map(function(t){ return t.name; }), ['Diel', 'Pracovná doska'],
  'doska: len doskove sablony');
eq(ins.usedSeq({ used_seq: 4 }), 4, 'used_seq je cislo');
eq(ins.usedSeq({ used_seq: null }), null, 'nikdy nepouzita');
eq(ins.usedSeq({ used_seq: 'x' }), null, 'nezmysel = nikdy nepouzita');
eq(ins.recentTemplates(ins.templatesForType(LIB2, 'lower'), 3).map(function(t){ return t.name; }),
  ['Drezova 900', 'Varna 600', 'Dolna 2 dvierka'],
  'nedavne prve: od najvyssieho used_seq, max 3, nepouzite von');
eq(ins.recentTemplates(ins.templatesForType(LIB2, 'lower'), 2).length, 2, 'limit sa dodrzi');
eq(ins.recentTemplates([{ name: 'A', kind: 'cabinet', config: {}, used_seq: 5 },
                        { name: 'B', kind: 'cabinet', config: {}, used_seq: 5 }], 2)
     .map(function(t){ return t.name; }), ['A', 'B'],
  'rovnake poradove cislo = stabilne poradie kniznice (ziadne preskakovanie)');
const G = ins.templateGroups(LIB2, 'board', 3);
eq(G.recent.map(function(t){ return t.name; }), ['Diel'], 'skupina Naposledy pouzite (doska)');
eq(G.all.map(function(t){ return t.name; }), ['Diel', 'Pracovná doska'], 'skupina Vsetky sablony');
eq(ins.templateGroups(LIB2, 'upper', 3).recent.map(function(t){ return t.name; }), ['Horna klasik'],
  'nedavne su LEN z ponuky daneho typu');
eq(ins.templateGroups([], 'lower', 3), { recent: [], all: [] }, 'prazdna kniznica nespadne');

// --- findTemplate: identita je DVOJICA (kind, name) ---
eq(ins.findTemplate(LIB2, 'board', 'Diel').name, 'Diel', 'doskova sablona podla mena');
eq(ins.findTemplate(LIB2, 'cabinet', 'Diel'), null, 'rovnomenna korpusova NEEXISTUJE');
eq(ins.findTemplate(LIB, 'board', 'Zástena').kind, 'board',
  'rovnake meno v dvoch druhoch: vrati sa ten spravny');
eq(ins.findTemplate(LIB2, 'cabinet', ''), null, 'prazdne meno = ziadna sablona');
eq(ins.findTemplate(null, 'cabinet', 'A'), null, 'prazdna kniznica nespadne');

console.log(JSON.stringify({ passed: n, failed: 0 }));
