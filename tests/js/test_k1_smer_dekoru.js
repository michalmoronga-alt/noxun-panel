// K1 / D-108 — SEGMENT „Smer dekoru" v karte dielca (ciste funkcie, bez DOM).
//
// Co sa tu strazi:
//   * VSETKY TEXTY SKLADA SERVER. JS nesmie poznat ani slovo „pozdĺžna", ani
//     rozmery — inak by panel vedel povedat nieco ine, nez postavi builder.
//   * Dedeny stav ukazuje VYSLEDOK (label prichadza uz s „— pozdĺžna"), nie
//     prazdne slovo „dedí": prave to bol slepy bod incidentu 19.8.2026.
//   * Rucny zasah je vizualne ODLISENY od dedenia (jantarove `ovr`, rovnaky
//     jazyk ako `select.ovr` pri materiali a hranach).
//   * ZAMKNUTY stav (material bez smeru) zamkne VSETKY tri volby a nesie hint.
//   * Chybajuci/poskodeny payload segment ZAMKNE — radsej nic nez nahodny stav,
//     ktory by tvrdil, ze kresba ide inak, nez ide.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

global.fmtmm = function (v) { return (v == null || v === '') ? '?' : Math.round(parseFloat(v)); };

const { nxGrainSegmentState, nxGrainWire } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'part_card.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// Payload presne v tvare, aky posiela `Panel.part_grain_payload` (server).
function pcPayload(over){
  return Object.assign({
    grain_value: 'inherit',
    grain_material: 'length',
    grain_effective: 'length',
    grain_locked: false,
    grain_hint: null,
    grain_options: [
      { value: 'inherit', label: 'Podľa materiálu — pozdĺžna', title: 'Pozdĺžna — výrobne 2000×250 mm' },
      { value: 'length', label: 'Pozdĺžna', title: 'Pozdĺžna — výrobne 2000×250 mm' },
      { value: 'width', label: 'Priečna', title: 'Priečna — výrobne 250×2000 mm' }
    ]
  }, over || {});
}

function byValue(st, v){ return st.buttons.filter(b => b.value === v)[0]; }

// --- 1) DEDENIE: aktivna je „Podľa materiálu" a ukazuje VYSLEDOK -------------
const INHERIT = nxGrainSegmentState(pcPayload());
eq(INHERIT.buttons.map(b => b.value), ['inherit', 'length', 'width'],
   'poradie volieb je pevne: dedenie, pozdĺžna, priečna');
eq(byValue(INHERIT, 'inherit').on, true, 'dedenie je aktivne');
eq(byValue(INHERIT, 'inherit').ovr, false, 'dedenie NIE JE rucny zasah');
eq(byValue(INHERIT, 'inherit').label, 'Podľa materiálu — pozdĺžna',
   'dedeny stav ukazuje VYSLEDOK — inak by pouzivatel nevidel, ako kresba naozaj ide');
eq(INHERIT.buttons.filter(b => b.on).length, 1, 'aktivna je vzdy prave JEDNA volba');
eq(INHERIT.locked, false, 'dekorovy material sa da otacat');
eq(INHERIT.hint, '', 'bez zamku sa hint nezobrazuje (vertikalny priestor je vzacny)');

// --- 2) VYROBNY ROZMER je v tooltipe KAZDEJ volby (jadro incidentu) ---------
// 2000×250 pozdlz kresby vs 250×2000 naprieč — presne ten rozdiel, ktory sa
// 19.8.2026 zistil az v objednavke.
eq(byValue(INHERIT, 'length').title, 'Pozdĺžna — výrobne 2000×250 mm', 'pozdlz kresby');
eq(byValue(INHERIT, 'width').title, 'Priečna — výrobne 250×2000 mm', 'naprieč kresbou');
eq(INHERIT.buttons.every(b => typeof b.title === 'string' && b.title.length > 0), true,
   'ziadna volba nesmie byt bez vysvetlenia');

// --- 3) RUCNY OVERRIDE je vizualne odliseny od dedenia ----------------------
const OVR = nxGrainSegmentState(pcPayload({ grain_value: 'width', grain_effective: 'width' }));
eq(byValue(OVR, 'width').on, true, 'priecna je aktivna');
eq(byValue(OVR, 'width').ovr, true, 'rucny zasah = jantarovy stav');
eq(byValue(OVR, 'inherit').on, false, 'dedenie sa vypne');
eq(byValue(OVR, 'inherit').ovr, false, 'a nikdy nie je oznacene ako rucne');
eq(OVR.buttons.filter(b => b.on).length, 1, 'stale prave jedna aktivna');

const OVR_L = nxGrainSegmentState(pcPayload({ grain_value: 'length' }));
eq(byValue(OVR_L, 'length').ovr, true,
   'aj override ZHODNY s materialom je rucny zasah — je to rozhodnutie, nie dedenie');

// --- 4) ZAMKNUTY stav: material bez smeru ------------------------------------
const LOCKED = nxGrainSegmentState(pcPayload({
  grain_locked: true, grain_material: 'none', grain_effective: 'none',
  grain_value: 'width',
  grain_hint: 'Materiál dielca nemá smer dekoru (jednofarebný alebo UNI) — otáčať sa nemá čo.'
}));
eq(LOCKED.locked, true, 'segment je zamknuty');
eq(LOCKED.buttons.every(b => b.disabled), true, 'zamknu sa VSETKY tri volby');
eq(LOCKED.hint.length > 0, true, 'zamknuty stav MUSI povedat preco (inak vyzera ako chyba)');
// Ulozeny override sa NEMAZE — segment ho aj v zamknutom stave stale ukazuje.
eq(byValue(LOCKED, 'width').on, true,
   'zapamataný smer ostava viditelny — po navrate dekoru znova plati');

// --- 5) CHYBAJUCI payload: radsej zamok nez vymysleny stav -------------------
const NOPAY = nxGrainSegmentState(null);
eq(NOPAY.locked, true, 'bez payloadu sa segment zamkne');
eq(NOPAY.buttons.length, 3, 'kostra ostava — nic sa neprekresluje na prazdno');
// Codex #185 kolo 2 (P2): popisy sa RESETUJU na neutralnu zalohu z kostry.
// Keby sa preskocili, segment by na novom dielci drzal popis a tooltip
// PREDOSLEHO — teda cudzi vyrobny rozmer.
eq(NOPAY.buttons.map(b => b.label), ['Podľa materiálu', 'Pozdĺžna', 'Priečna'],
   'bez serverovych textov sa popisy vratia na zalohu z kostry, nie na cudzie');
eq(NOPAY.buttons.map(b => b.title), ['', '', ''],
   'a tooltip s vyrobnym rozmerom zmizne — cudzie cislo je horsie nez ziadne');
eq(byValue(NOPAY, 'inherit').on, true, 'default je dedenie');

// Prechod „dielec s payloadom -> dielec bez payloadu" nesmie nechat stary text.
const AFTER = nxGrainSegmentState({ grain_value: 'inherit' });
eq(byValue(AFTER, 'width').label, 'Priečna', 'popis je zo zalohy, nie z predosleho dielca');
eq(byValue(AFTER, 'width').title, '', 'tooltip predosleho dielca sa NEPRENESIE');

const BADVAL = nxGrainSegmentState(pcPayload({ grain_value: 'diagonal' }));
eq(byValue(BADVAL, 'inherit').on, true,
   'neznama hodnota zo servera sa NEUKAZE ako aktivna volba — spadne na dedenie');

// --- 6) HODNOTA NA DROT: dedenie ma sentinel, ktory server pozna ------------
// Segment pouziva UI token `inherit`, zapisova cesta sentinel `__inherit__`
// (ten isty, akym sa hrana vracia „podľa pravidla"). Keby sa rozisli, klik na
// „Podľa materiálu" by server odmietol ako neznamy smer a override by aj
// s rotaciou vo VEPO ticho ostal — Codex #185 P1.
eq(nxGrainWire('inherit'), '__inherit__', 'dedenie ide na server ako sentinel');
eq(nxGrainWire('length'), 'length', 'konkretny smer sa neprekladá');
eq(nxGrainWire('width'), 'width', 'to iste pre priecnu');

console.log(`OK test_k1_smer_dekoru.js — ${n} asertov`);
