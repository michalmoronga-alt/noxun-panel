// Testy UI-C3 — kontext CELA (riadky, AUTO, rady vysok, Uchytky D-96).
// LEN ciste funkcie z core.js (bez DOM) — presne ten isty vzor ako
// test_d90_profil_ui.js: register profilov chodi z Ruby a do funkcii sa
// odovzdava parametrom.
'use strict';
const assert = require('node:assert');
const path = require('node:path');
const { frontProfileOptionList, frontProfileScopeItems, frontProfileCommon,
        frontProfileStateText, collectFrontHwBuy,
        PROFILELESS_FRONT_TYPES, frontProfileless } =
  require(path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js', 'core.js'));

let n = 0;
function eq(actual, expected, msg){
  n++;
  assert.deepStrictEqual(actual, expected, `${msg}: cakam ${JSON.stringify(expected)}, dostal ${JSON.stringify(actual)}`);
}

// Presna podoba payloadu z Ruby (FrontProfiles.options).
const REG = [{ id: 'ukw7', name: 'Profil UKW-7', short: 'UKW-7', reduction: 36.0 }];

// Typicka skrinka: dve zasuvkove cela a dvierka navrchu (F1 dole — D-23).
const F = [
  { label: 'F1', type: 'drawer_front', profile: 'ukw7' },
  { label: 'F2', type: 'drawer_front', profile: 'ukw7' },
  { label: 'F3', type: 'door',         profile: 'none' }
];

// --- D-96: ROZSAH ------------------------------------------------------------
eq(frontProfileScopeItems(F, 'all').map(x => x.label), ['F1', 'F2', 'F3'], 'rozsah „všetky"');
eq(frontProfileScopeItems(F, 'door').map(x => x.label), ['F3'], 'rozsah „len dvierka"');
eq(frontProfileScopeItems(F, 'drawer_front').map(x => x.label), ['F1', 'F2'], 'rozsah „len zásuvkové"');
// „Bez čela" nema na com profil drzat — do ziadneho rozsahu nepatri (rovnako to
// robi Ruby normalize, ktora mu profil zhodi na 'none').
eq(frontProfileScopeItems(F.concat([{ label: 'F4', type: 'none', profile: 'ukw7' }]), 'all')
     .map(x => x.label), ['F1', 'F2', 'F3'], '„Bez čela" nikdy nie je v rozsahu');
eq(frontProfileScopeItems([], 'all'), [], 'skrinka bez ciel = prazdny rozsah');
eq(frontProfileScopeItems(null, 'all'), [], 'chybajuce data nespadnu');

// --- KOV-A1 (Codex #280 P2-D): PROFILELESS typy ------------------------------
// Vyklop, sklop a blenda profil MAT NEMOZU (Ruby normalize im ho zhodi na
// 'none'), takze do rozsahu nepatria ANI v „všetky" — inak by UI ponukalo
// nastavenie, ktore server ticho zahodi.
eq(PROFILELESS_FRONT_TYPES, ['none', 'lift', 'fall', 'blind'],
   'zoznam je ZRKADLO servera (Fronts::PROFILELESS_TYPES) — Ruby guard ho strazi');
['none', 'lift', 'fall', 'blind'].forEach(t => {
  eq(frontProfileless(t), true, `${t} profil mat nemoze`);
});
['door', 'drawer_front'].forEach(t => {
  eq(frontProfileless(t), false, `${t} profil mat MOZE`);
});
eq(frontProfileless('sliding_2027'), false, 'neznamy typ sa nevydava za profileless');

const FK = F.concat([
  { label: 'F4', type: 'lift',  profile: 'ukw7' },
  { label: 'F5', type: 'fall',  profile: 'ukw7' },
  { label: 'F6', type: 'blind', profile: 'ukw7' },
  { label: 'F7', type: 'none',  profile: 'ukw7' }
]);
eq(frontProfileScopeItems(FK, 'all').map(x => x.label), ['F1', 'F2', 'F3'],
   'rozsah „všetky" vynecha vyklop, sklop, blendu aj „Bez čela"');
eq(frontProfileScopeItems(FK, 'door').map(x => x.label), ['F3'], 'rozsah dvierok sa nemeni');
eq(frontProfileScopeItems(FK, 'drawer_front').map(x => x.label), ['F1', 'F2'],
   'rozsah zasuvkovych sa nemeni');
// Spolocna hodnota ich TIEZ ignoruje — inak by select ukazal „(rôzne)" kvoli
// celu, ktore v rozsahu vobec nie je.
eq(frontProfileCommon(FK, 'all'), null, 'rozne profily DVIEROK a zasuviek = (rôzne)');
eq(frontProfileCommon([{ label: 'F1', type: 'drawer_front', profile: 'ukw7' },
                       { label: 'F2', type: 'lift', profile: 'none' }], 'all'), 'ukw7',
   'profileless celo NEROBI z jednotneho rozsahu „(rôzne)"');
eq(frontProfileCommon([{ label: 'F1', type: 'lift', profile: 'ukw7' },
                       { label: 'F2', type: 'blind', profile: 'none' }], 'all'), '',
   'skrinka so samymi profileless celami = prazdny rozsah');
// Veta stavu ma TEN ISTY filter — nesmie tvrdit „bez profilu: F2" o vyklope.
eq(frontProfileStateText([{ label: 'F1', type: 'door', profile: 'ukw7' },
                          { label: 'F2', type: 'lift', profile: 'none' }], REG),
   'UKW-7: F1', 'veta stavu profileless cela vobec nespomina');
eq(frontProfileStateText([{ label: 'F1', type: 'blind', profile: 'ukw7' }], REG),
   'Skrinka zatiaľ nemá čelá, na ktorých by profil sedel.',
   'same profileless cela = to iste ako ziadne cela');

// --- D-96: SPOLOCNA HODNOTA (co ukaze select) --------------------------------
eq(frontProfileCommon(F, 'drawer_front'), 'ukw7', 'zhodny profil v rozsahu = jeho hodnota');
eq(frontProfileCommon(F, 'door'), 'none', 'jedno celo bez profilu = neutral');
eq(frontProfileCommon(F, 'all'), null, 'rozne profily = null („(rôzne)", nikdy tichy vyber)');
eq(frontProfileCommon([], 'all'), '', 'prazdny rozsah = prazdny retazec (nie je co nastavovat)');
eq(frontProfileCommon([{ label: 'F1', type: 'door' }], 'all'), 'none',
   'chybajuci kluc profilu je neutral (starsi config bez pola)');

// --- D-96: VETA STAVU (co je NASADENE) ---------------------------------------
eq(frontProfileStateText(F, REG), 'UKW-7: F1, F2 · bez profilu: F3',
   'veta hovori, ktore cela profil maju — poradie podla prveho vyskytu');
eq(frontProfileStateText([{ label: 'F1', type: 'door', profile: 'none' }], REG),
   'Žiadne čelo nemá úchytkový profil.', 'jednoznacny stav sa povie vetou, nie zoznamom');
eq(frontProfileStateText([], REG), 'Skrinka zatiaľ nemá čelá, na ktorých by profil sedel.',
   'bez ciel sa povie preco, nie prazdno');
eq(frontProfileStateText([{ label: 'F1', type: 'none', profile: 'ukw7' }], REG),
   'Skrinka zatiaľ nemá čelá, na ktorých by profil sedel.',
   'same „Bez čela" = to iste ako ziadne cela');
// Profil z NOVSEJ verzie (registry ho nepozna) sa NEVYDAVA za znamy — rovnaka
// zasada ako frontProfileRec: neznamy = neutral.
eq(frontProfileStateText([{ label: 'F1', type: 'door', profile: 'ukw99' }], REG),
   'bez profilu: F1', 'neznamy profil sa nevydava za znamy');

// --- ponuka je zdrojom hodnot selectu ----------------------------------------
eq(frontProfileOptionList(REG).map(o => o.id), ['none', 'ukw7'], 'ponuka: neutral + registry');

// --- naviazane kovanie: NAZVY SETOV pod riadkom cela (Codex #178 P2) ---------
// Ten isty tvar chodi z `loadSelected` (plne polozky) aj zo ZIVEHO pushu
// `push_hardware_sets` (identita + purchase, bez poctov) — preto sa mapa setov
// pocita VYHRADNE z `owner_part_key` + `purchase.set_name`.
const HW = [
  { owner_part_key: 'front:F1/panel', generic_type: 'slide',
    purchase: { set_name: 'Atira biela H176', members: [], problems: [] } },
  { owner_part_key: 'front:F3/wing:left', generic_type: 'hinge',
    purchase: { set_name: 'CLIP top 110', members: [], problems: [] } },
  { owner_part_key: 'front:F3/wing:right', generic_type: 'hinge',
    purchase: { set_name: 'CLIP top 110', members: [], problems: [] } },
  { owner_part_key: 'front:F3/wing:left', generic_type: 'handle',
    purchase: { set_name: 'UKW 7', members: [], problems: [] } },
  { owner_part_key: 'cabinet/legs', generic_type: 'leg',
    purchase: { set_name: 'Nohy 100', members: [], problems: [] } },
  { owner_part_key: 'front:F2/panel', generic_type: 'slide', purchase: null }
];
eq(collectFrontHwBuy(HW), { F1: ['Atira biela H176'], F3: ['CLIP top 110', 'UKW 7'] },
   'set sa zapise raz per čelo, kovanie skrinky do mapy čiel nepatrí, položka bez nákupu sa vynechá');
eq(collectFrontHwBuy([]), {}, 'prázdny payload = prázdna mapa');
eq(collectFrontHwBuy(null), {}, 'chýbajúce dáta nespadnú');
eq(collectFrontHwBuy([{ owner_part_key: 'front:F1/panel', purchase: { set_name: '' } }]), {},
   'prázdny názov setu sa netvári ako nákup');

console.log(`OK test_uic3_cela.js — ${n} kontrol`);
