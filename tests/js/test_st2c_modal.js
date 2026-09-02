// ŠT-2c PR 2c-1 — rozšírená zdieľaná kostra modalov (`ui/js/nx_modal.js`)
// + dve opravy našepkávača materiálov (`ui/js/proj_materials.js`).
//
// Preco su to testy a nie klikanie:
//   1. `values()` je KONTRAKT medzi kostrou a serverom. Keby `rows` vratili
//      cokolvek ine nez POLE HASHOV (alebo keby sa ploche polia zmenili
//      z retazcov), server by dostal tvar, ktoremu nerozumie — a padlo by to
//      az pri ZAPISE dekoru, teda po tom, co uz pouzivatel formular vyplnil.
//   2. Repeater prekresluje kontajner pri KAZDOM pridani/odobrani riadku.
//      Keby hodnoty necital z DOM, kazde „+" by ticho zmazalo rozpisane
//      riadky nad sebou.
//   3. Pamat kluc = mode + CIEL. Keby bola kluc len „druh okna", editor
//      dekoru B by sa otvoril s rozpisanymi hodnotami dekoru A a ulozil by
//      ich do NESPRAVNEHO zaznamu.
//   4. Escape nasepkavaca: bez `stopPropagation` na inpute jedno stlacenie
//      zavrie dropdown AJ cely formular (dokumentovy listener D-15 modalu).
//      To sa da overit iba BUBLANIM — preto ma stub skutocne bublanie.
//   5. Scroll VNUTRI karty modalu: `scroll` z vnutorneho kontajnera NEBUBLA,
//      takze bez capture by dropdown ostal visiet nad cudzim riadkom.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

let n = 0;
function ok(c, msg){ n++; assert.ok(c, msg); }
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// Mini-DOM (skutocne parsovanie HTML + bublanie udalosti) zije od ŠT-2c 2c-2a
// v `tests/js/minidom.js` — pouziva ho aj sada editora dekoru. Nie je to
// testovacia sada, CI beh `test_*.js` ju preto nespusta.
const { mkEl, DOC, dispatch, fireScroll } = require(path.join(__dirname, 'minidom.js'));

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');
const NXModal = require(path.join(JS, 'nx_modal.js'));
const ROOT = mkEl('div');
ROOT.attrs.id = 'nxModalRoot';
DOC.body.appendChild(ROOT);

// ===================== 1) NOVE TYPY POLI — cisty markup ======================

(function(){
  const g = NXModal.fieldHtml({ type: 'group', label: 'Identita', hint: 'kód · názov · výrobca' });
  ok(g.indexOf('<div class="mgroup"><h4>Identita</h4>') === 0,
     '`group` je NADPIS sekcie formulara, nie pole');
  ok(g.indexOf('kód · názov · výrobca') > -1, 'a smie niest doplnujuci text');
  ok(g.indexOf('data-nxm=') === -1, 'nadpis nema kluc — nema co odoslat');

  const c = NXModal.fieldHtml({ key: 'grain', label: 'Kresba', type: 'checkbox', value: true });
  ok(c.indexOf('type="checkbox"') > -1 && c.indexOf('data-nxm="grain"') > -1,
     '`checkbox` je normalne pole s klucom');
  ok(c.indexOf(' checked') > -1, 'a zapnuty stav sa vykresli');
  ok(NXModal.fieldHtml({ key: 'grain', label: 'K', type: 'checkbox', value: false })
       .indexOf('checked') === -1, 'vypnuty nie');

  const col = NXModal.fieldHtml({ key: 'rgb', label: 'Farba', type: 'color', value: '#A3B1C2' });
  ok(col.indexOf('class="mswatch" id="nxm_rgb_sw"') > -1, '`color` kresli VZORKU');
  ok(col.indexOf('style="background:#A3B1C2"') > -1, 'vo farbe hodnoty');
  ok(col.indexOf('value="#A3B1C2"') > -1 && col.indexOf('placeholder="#RRGGBB"') > -1,
     'a k nej TEXT — hodnotu musi byt vidno a dat skopirovat');
  ok(NXModal.fieldHtml({ key: 'rgb', label: 'F', type: 'color', value: 'nezmysel' })
       .indexOf('style=') === -1, 'nezmyselna hodnota vzorku nezafarbi');
})();

(function(){
  const f = { key: 'sheets', type: 'rows', label: 'Dosky', addLabel: 'Pridať dosku',
              hidden: ['material_id'], min: 1,
              cols: [{ key: 'kod', label: 'Kód', placeholder: 'H3303' },
                     { key: 'hr', label: 'Hrúbka', type: 'select', options: [['18', '18'], ['36', '36']] }],
              empty: 'Zatiaľ žiadna doska.' };
  const h = NXModal.rowsHtml(f, [{ material_id: 'M1', kod: 'H3303', hr: '36' }]);
  ok(h.indexOf('id="nxmr_sheets" data-nxm-rows="sheets"') > -1,
     'repeater ma svoj kontajner s VLASTNYM prefixom id (nezrazi sa s plochym polom)');
  ok(h.indexOf('data-nxm-row="sheets"') > -1, 'a riadok, ktory sa da najst');
  ok(h.indexOf('<input type="hidden" data-nxm-col="material_id" value="M1">') > -1,
     'existujuci riadok nesie SKRYTE id variantu — podla neho server pozna UPRAVU');
  ok(h.indexOf('data-nxm-col="kod" class="mrcell" aria-label="Kód" value="H3303"') > -1,
     'viditelne bunky nesu hodnoty (a od 2c-2a aj `aria-label` — bunka nema <label>)');
  ok(h.indexOf('<option value="36" selected>36</option>') > -1, 'aj v rozbalovacich bunkach');
  ok(h.indexOf('data-nxm-act="rowadd"') > -1 && h.indexOf('Pridať dosku') > -1, 'tlacidlo „+"');
  ok(h.indexOf('data-nxm-act="rowdel"') > -1, 'a „−" v riadku');
  // D-78: ziadne MRTVE tlacidlo — pri minime je `aria-disabled` (ostava
  // v Tab poradi) a titulok nesie DOVOD.
  ok(h.indexOf('aria-disabled="true"') > -1 && h.indexOf('Musí zostať aspoň jeden riadok.') > -1,
     'pri dosiahnutom minime je „−" aria-disabled a povie DOVOD');
  ok(h.indexOf('class="mrdel off" data-nxm-act="rowdel" disabled') === -1 &&
     h.indexOf("data-nxm-act=\"rowdel\" disabled") === -1,
     'tvrdy HTML `disabled` sa nepouziva — vyhodil by tlacidlo z klavesnice a mlcal by');
  const empty = NXModal.rowsHtml(f, []);
  ok(empty.indexOf('Zatiaľ žiadna doska.') > -1, 'prazdny repeater povie, ze je prazdny');
  ok(empty.indexOf('data-nxm-row=') === -1, 'a ziadny riadok nekresli');
  // XSS: hodnoty riadkov idu do innerHTML — VZDY escapovane.
  const x = NXModal.rowsHtml({ key: 'r', cols: [{ key: 'a', label: '<b>' }] }, [{ a: '"><img src=x>' }]);
  ok(x.indexOf('<img src=x>') === -1 && x.indexOf('&quot;&gt;&lt;img') > -1,
     'hodnota riadku je escapovana');
})();

// --- sirkove varianty karty --------------------------------------------------
(function(){
  eq(NXModal.cardCls({}), ' sm', 'default ostava uzka karta (spatna kompatibilita draftov)');
  eq(NXModal.cardCls({ small: false }), '', 'stary prepinac `small: false` = stredna karta');
  eq(NXModal.cardCls({ size: 'small' }), ' sm', '`small` je alias `sm`');
  eq(NXModal.cardCls({ size: 'md' }), '', '`md` = 560 px');
  eq(NXModal.cardCls({ size: 'wide' }), ' wide', '`wide` = 640 px pre editor s riadkami');
  ok(NXModal.modalHtml({ title: 'X', size: 'wide' }).indexOf('class="nxmcard wide"') > -1,
     'a karta triedu naozaj dostane');
})();

// ===================== 2) values(): TVAR kontraktu ===========================

const SPEC = {
  title: 'Upraviť dekor', size: 'wide', memoryKey: 'mat:edit:H3303',
  fields: [
    { type: 'group', label: 'Identita' },
    { key: 'kod', label: 'Kód', value: 'H3303' },
    { key: 'struktura', label: 'Štruktúra', type: 'select', value: 'ST9',
      options: [['ST9', 'ST9'], ['ST15', 'ST15']] },
    { key: 'grain', label: 'Kresba', type: 'checkbox', value: true },
    { key: 'rgb', label: 'Farba', type: 'color', value: '#334455' },
    { type: 'group', label: 'Dosky' },
    { key: 'sheets', type: 'rows', label: 'Dosky', hidden: ['material_id', 'row_rev'],
      cols: [{ key: 'kod', label: 'Kód' }, { key: 'cena', label: 'Cena', cls: 'mshort' }],
      value: [{ material_id: 'M1', row_rev: 'r7', kod: 'H3303 ST9', cena: '18,40' }] }
  ]
};

let submitted = null;
(function(){
  NXModal.open(Object.assign({ onSubmit: function(v){ submitted = v; } }, SPEC));
  ok(NXModal.isOpen(), 'modal zije');
  const v = NXModal.values();
  ok(!Object.prototype.hasOwnProperty.call(v, 'undefined') && Object.keys(v).length === 5,
     'nadpisy sekcii v hodnotach NIE SU (5 poli: kod, struktura, grain, rgb, sheets)');
  eq(v.kod, 'H3303', 'ploche textove pole ostava RETAZEC (drafty rozpoctu na tom stoja)');
  eq(v.struktura, 'ST9', 'aj rozbalovacie');
  eq(v.grain, true, '`checkbox` je BOOLEAN');
  eq(v.rgb, '#334455', '`color` je retazec #RRGGBB');
  eq(v.sheets, [{ material_id: 'M1', row_rev: 'r7', kod: 'H3303 ST9', cena: '18,40' }],
     '`rows` je POLE HASHOV — vratane skrytych id/rev, ktore riadok nesie');

  // Fokus NESMIE sadnut do skryteho pola riadku.
  ok(DOC.activeElement && DOC.activeElement.getAttribute('data-nxm') === 'kod',
     'fokus ide do prveho VIDITELNEHO pola (skryte id variantu sa preskakuje)');
})();

// ===================== 3) repeater: pridanie a odobranie =====================

(function(){
  // Do existujuceho riadku sa dopise cena, potom sa prida NOVY riadok.
  const cena = DOC.querySelector('[data-nxm-col="cena"]');
  cena.value = '19,90';
  const add = DOC.querySelector('[data-nxm-act="rowadd"]');
  dispatch(add, 'click');
  let rows = NXModal.values().sheets;
  eq(rows.length, 2, 'klik na „+" prida riadok');
  eq(rows[0].cena, '19,90', 'a rozpisana hodnota nad nim PREZIJE prekreslenie kontajnera');
  eq(rows[0].material_id, 'M1', 'vratane skryteho id variantu');
  eq(rows[1], { kod: '', cena: '' },
     'novy riadok je PRAZDNY a id NEMA — server ho preto zalozi ako novy variant');
  ok(DOC.activeElement && DOC.activeElement.getAttribute('data-nxm-col') === 'kod',
     'fokus sadol do prveho pola prave pridaneho riadku');

  // Vyplnenie druheho riadku a odobranie PRVEHO.
  const cells = DOC.querySelectorAll('[data-nxm-row] [data-nxm-col="kod"]');
  cells[1].value = 'H1180 ST15';
  const dels = DOC.querySelectorAll('[data-nxm-act="rowdel"]');
  dispatch(dels[0], 'click');
  rows = NXModal.values().sheets;
  eq(rows.length, 1, 'klik na „−" riadok odoberie');
  eq(rows[0].kod, 'H1180 ST15', 'a ZOSTANE ten, ktory pouzivatel nechal — nie prvy v poradi');
  eq(Object.prototype.hasOwnProperty.call(rows[0], 'material_id'), false,
     'novy riadok id stale nema (odobranie neprepisalo identitu susedov)');
})();

(function(){
  // D-78: pri minime „−" NEZMIZNE a nie je mrtve — klik povie DOVOD.
  // (SPEC repeater `min` nema, takze si ho na chvilu nastavime cez spec.)
  const f = NXModal.spec().fields.filter(function(x){ return x.type === 'rows'; })[0];
  f.min = 1;
  const add = DOC.querySelector('[data-nxm-act="rowadd"]');
  dispatch(add, 'click');
  const dels = DOC.querySelectorAll('[data-nxm-act="rowdel"]');
  dispatch(dels[0], 'click');                 // dolu na jeden riadok
  const del = DOC.querySelector('[data-nxm-act="rowdel"]');
  eq(del.getAttribute('aria-disabled'), 'true', 'pri minime je „−" aria-disabled…');
  eq(del.hasAttribute('disabled'), false, '…ale NIE tvrdo disabled (ostava na klavesnici)');
  ok(NXModal.values().sheets.length === 1, 'vychodisko: zostal jeden riadok');
  dispatch(del, 'click');
  eq(NXModal.values().sheets.length, 1, 'klik riadok NEODOBRAL');
  eq(DOC.querySelector('.mrnote').textContent, 'Musí zostať aspoň jeden riadok.',
     'a POVEDAL preco — ziadne tiche nic');
  f.min = 0;
})();

(function(){
  // Audit #5: neznama akcia bola dovtedy „vsetko ostatne = zavri". Tlacidlo
  // s preklepom v `data-nxm-act` by tak zmazalo rozpisany formular.
  const card = DOC.querySelector('.nxmcard');
  const bogus = mkEl('button');
  bogus.attrs['data-nxm-act'] = 'neznama';
  card.appendChild(bogus);
  dispatch(bogus, 'click');
  ok(NXModal.isOpen(), 'audit #5: neznama akcia modal NEZATVORILA');
})();

// ===================== 4) zamok, fokus, Escape — REGRESIA ====================

(function(){
  const btn = DOC.querySelector('[data-nxm-act="submit"]');
  submitted = null;
  dispatch(btn, 'click');
  dispatch(btn, 'click');                    // druhy klik hned za prvym
  ok(NXModal.isBusy(), 'prvy submit modal ZAMKNE');
  ok(btn.hasAttribute('disabled'), 'a potvrdzovacie tlacidlo zosedne');
  ok(submitted !== null && submitted.sheets.length === 1, 'odoslal sa TVAR s riadkami');
  ok(NXModal.isOpen(), 'audit #10: odoslanie modal NEZATVARA');

  // Enter v bunke riadku sa sprava rovnako ako v poli — a zamok drzi aj jeho.
  let calls = 0;
  const spy = NXModal.spec();
  spy.onSubmit = function(){ calls++; };
  dispatch(DOC.querySelector('[data-nxm-col="kod"]'), 'keydown', { key: 'Enter' });
  eq(calls, 0, 'druhe odoslanie sa ZAHADZUJE, kym zamok drzi');
  NXModal.setBusy(false);
  ok(!btn.hasAttribute('disabled'), 'odomknutie tlacidlo ozivi');
  dispatch(DOC.querySelector('[data-nxm-col="kod"]'), 'keydown', { key: 'Enter' });
  eq(calls, 1, 'Enter v bunke opakovatelneho riadku potvrdzuje formular ako kazde ine pole');
  NXModal.setBusy(false);
})();

(function(){
  // Focus trap s NOVYMI poliami: v karte teraz ziju aj skryte polia riadkov
  // a ikony (`<svg><use href="#i-…">`). Ani jedno nesmie byt zastavkou Tabu —
  // inak by cyklus skoncil na kuse ikony a fokus by zmizol.
  NXModal.close();
  NXModal.open(Object.assign({}, SPEC, { memoryKey: 'mat:fokus:test' }));
  ok(DOC.querySelectorAll('.nxmcard [type="hidden"]').length > 0,
     'vychodisko: karta SKUTOCNE obsahuje skryte polia riadkov');
  ok(DOC.querySelectorAll('.nxmcard [href]').length > 0, 'aj ikony s `href`');

  const close = DOC.querySelector('.nxmcard .mx');
  const submit = DOC.querySelector('[data-nxm-act="submit"]');
  DOC.activeElement = submit;
  let ev = dispatch(submit, 'keydown', { key: 'Tab', shiftKey: false });
  ok(ev._prevented, 'Tab z POSLEDNEHO ovladaca karty sa zachyti');
  eq(DOC.activeElement, close, 'a fokus skoci na prvy — krizik, nie na kus ikony za nim');

  ev = dispatch(close, 'keydown', { key: 'Tab', shiftKey: true });
  ok(ev._prevented, 'Shift+Tab z prveho sa zachyti tiez');
  eq(DOC.activeElement, submit,
     'a fokus skoci na POTVRDENIE — teda ani na `<use href>`, ani na skryte id variantu');
  NXModal.close();
})();

// ===================== 5) pamat hodnot v komponente ==========================

(function(){
  // Cisty start: predchadzajuce bloky s formularom pracovali, takze pamat
  // po nich vynulujeme (inak by tento blok testoval ich vysledok).
  NXModal.clearMemory('mat:edit:H3303');
  // Otvoril som a hned zavrel — NIC som nerozpisal, takze niet co pamatat.
  // Bez porovnania s VYCHODISKOVYMI hodnotami (audit #2) by sa pamat zalozila
  // uz tu a nabuduce by nad formularom svietil pas „predvyplnené" bez dôvodu.
  NXModal.open(SPEC);
  dispatch(DOC.querySelector('[data-nxm="kod"]'), 'keydown', { key: 'Escape' });
  eq(NXModal.memory('mat:edit:H3303'), null,
     'samotne otvorenie a zavretie okna pamat NEZAKLADA');

  // Escape PO ZMENE hodnoty — rozpis prezije (kontrakt D-15 z PR B2).
  NXModal.open(SPEC);
  DOC.querySelector('[data-nxm="kod"]').value = 'H3303 UPRAVENY';
  const ev = dispatch(DOC.querySelector('[data-nxm="kod"]'), 'keydown', { key: 'Escape' });
  ok(!NXModal.isOpen(), 'Escape modal zavrel');
  ok(ev._immediate, 'a Escape SPOTREBOVAL (okno za nim ho vidiet nesmie)');
  const mem = NXModal.memory('mat:edit:H3303');
  eq(mem, { kod: 'H3303 UPRAVENY' },
     'zapamätalo sa LEN pole, ktore sa lisi od vychodiskovych hodnot');
  eq(NXModal.memory('mat:edit:H1180'), null, 'INY ciel ma vlastnu (prazdnu) pamat');

  // Otvorenie s TYM ISTYM klucom hodnoty PREDVYPLNI — a MUSI to priznat.
  NXModal.open(SPEC);
  eq(NXModal.values().kod, 'H3303 UPRAVENY', 'to iste okno sa otvorilo s rozpisom');
  ok(DOC.querySelector('.mmemo') !== null,
     'audit #1: nad formularom svieti pas „Predvyplnené z rozpísaného konceptu"');
  ok(DOC.querySelector('[data-nxm-act="memreset"]') !== null, 'a s cestou von');

  // „Začať odznova" = vychodiskove hodnoty + pamat prec.
  dispatch(DOC.querySelector('[data-nxm-act="memreset"]'), 'click');
  ok(NXModal.isOpen(), 'formular ostal otvoreny');
  eq(NXModal.values().kod, 'H3303', 'a vratil sa na VYCHODISKOVE hodnoty');
  eq(DOC.querySelector('.mmemo'), null, 'pas zmizol — uz to nie je koncept');
  eq(NXModal.memory('mat:edit:H3303'), null, 'a pamat zanikla');
  NXModal.close();
  eq(NXModal.memory('mat:edit:H3303'), null, 'zatvorenie ju uz neobnovi');

  // ZMENA CIELA: editor ineho dekoru je CISTY formular a stara rozpisana
  // verzia zanika — inak by sa hodnoty dekoru A ulozili do dekoru B.
  NXModal.open(SPEC);
  DOC.querySelector('[data-nxm="kod"]').value = 'ROZPÍSANÉ A';
  NXModal.close();
  ok(NXModal.memory('mat:edit:H3303') !== null, 'vychodisko: dekor A ma rozpis');
  NXModal.open({ title: 'Upraviť dekor', memoryKey: 'mat:edit:H1180',
                 fields: [{ key: 'kod', label: 'Kód', value: 'H1180' }] });
  eq(NXModal.values().kod, 'H1180', 'iny ciel = ziadne cudzie predvyplnenie');
  eq(DOC.querySelector('.mmemo'), null, 'a ziadny pas — nie je z coho');
  eq(NXModal.memory('mat:edit:H3303'), null, 'pamat predchadzajuceho ciela ZANIKLA');
  NXModal.close();
})();

(function(){
  // #3: „ulož a pokračuj" nesmie byt ticha strata. Po `clear` (server potvrdil)
  // je zapis pamate zhasnuty — prve pisanie do karty ho MUSI zapalit spat,
  // inak by sa druha rozpisana polozka pri Escape stratila.
  NXModal.open({ title: 'A', memoryKey: 'bud:custom',
                 fields: [{ key: 'popis', label: 'Popis' }] });
  NXModal.setBusy(true);
  NXModal.setBusy(false, { clear: true });      // server potvrdil prvu polozku
  const inp = DOC.querySelector('[data-nxm="popis"]');
  inp.value = 'Druhá položka';
  dispatch(inp, 'input');                        // pouzivatel pise dalej
  NXModal.close();
  eq(NXModal.memory('bud:custom').popis, 'Druhá položka',
     '#3: pisanie po potvrdenom zapise pamat opat zapalilo');
  NXModal.clearMemory('bud:custom');
})();

(function(){
  // Rezimy su NEZAVISLE sloty — „Pridať položku" a „Pridať spotrebič"
  // sa nemiesaju (regresia draftov rozpoctu).
  NXModal.open({ title: 'A', memoryKey: 'bud:custom', fields: [{ key: 'popis', label: 'Popis' }] });
  DOC.querySelector('[data-nxm="popis"]').value = 'Likvidácia';
  NXModal.close();
  NXModal.open({ title: 'B', memoryKey: 'bud:appliance', fields: [{ key: 'nazov', label: 'Názov' }] });
  DOC.querySelector('[data-nxm="nazov"]').value = 'Bosch';
  NXModal.close();
  eq(NXModal.memory('bud:custom').popis, 'Likvidácia', 'vlastna polozka si pamata svoje');
  eq(NXModal.memory('bud:appliance').nazov, 'Bosch', 'spotrebic tiez — su to ine rezimy');

  // Uspesny zapis pamat zahadzuje. Dve cesty, obe musia fungovat — a obe
  // s ROZPISANOU hodnotou v poli, inak by test prechadzal aj bez mazania.
  NXModal.open({ title: 'A', memoryKey: 'bud:custom', fields: [{ key: 'popis', label: 'Popis' }] });
  DOC.querySelector('[data-nxm="popis"]').value = 'Likvidácia';
  NXModal.setBusy(true);
  NXModal.setBusy(false, { clear: true });
  NXModal.close();
  eq(NXModal.memory('bud:custom'), null, '`setBusy(false, {clear:true})` = server potvrdil, pamat prec');

  NXModal.open({ title: 'B', memoryKey: 'bud:appliance', fields: [{ key: 'nazov', label: 'Názov' }] });
  DOC.querySelector('[data-nxm="nazov"]').value = 'Bosch';
  NXModal.clearMemory('bud:appliance');
  NXModal.close();
  eq(NXModal.memory('bud:appliance'), null,
     '`clearMemory` pred zatvorenim pamat NEobnovi (inak by ju close() zapisal spat)');

  // Prazdny formular sa nepamata — inak by v pamati zostal balast.
  NXModal.open({ title: 'A', memoryKey: 'bud:custom', fields: [{ key: 'popis', label: 'Popis' }] });
  NXModal.close();
  eq(NXModal.memory('bud:custom'), null, 'zatvorenie prazdneho formulara pamat nezaklada');
})();

// ===================== 6) nasepkavac materialov vs modal =====================
// `proj_materials.js` sa nacitava az teraz — potrebuje hotovy `window`/`document`.
// `NX` je kanal Studia; tu staci prazdny (bez `setStudio` sa nenapaja na push).
global.NX = {};
global.window.NX = global.NX;
const M = require(path.join(JS, 'proj_materials.js'));

(function(){
  const card = mkEl('div');
  card.attrs.class = 'nxmcard';
  const body = mkEl('div');
  body.attrs.class = 'mbody';
  card.appendChild(body);
  const inp = mkEl('input');
  inp.attrs.id = 'nd_kod';
  body.appendChild(inp);
  DOC.body.appendChild(card);

  M.mdSgBind('nd_kod', function(){ return ['H3303 ST9', 'H1180 ST15']; }, null);
  dispatch(inp, 'focus');
  const box = DOC.getElementById('mdSgBox');
  ok(box && box.style.display === '', 'nasepkavac sa otvoril (dva navrhy)');

  // Modal zije POD nim. Escape musi zavriet LEN dropdown.
  NXModal.open({ title: 'Upraviť dekor', memoryKey: 'mat:edit:X',
                 fields: [{ key: 'kod', label: 'Kód' }] });
  const ev = dispatch(inp, 'keydown', { key: 'Escape' });
  eq(box.style.display, 'none', 'audit ŠT-2c #10: Escape zavrel nasepkavac');
  ok(ev._stopped, 'a bublanie ZASTAVIL na inpute');
  ok(NXModal.isOpen(),
     'takze formular pod nim OSTAL otvoreny — jedno stlacenie nesmie zmazat rozpisany dekor');

  // #9: pisanie do pola nasepkavac VRATI — bez toho by Escape pole „vypol"
  // az do opustenia a noveho kliknutia don.
  inp.value = 'H11';
  dispatch(inp, 'input');
  eq(box.style.display, '', 'audit ŠT-2c #9: pisanie nasepkavac obnovilo');
  dispatch(inp, 'keydown', { key: 'Escape' });
  eq(box.style.display, 'none', 'a Escape ho vie zavriet znova');

  // Druhy Escape (dropdown uz zavrety) uz patri modalu — inak by sa okno
  // nedalo zavriet vobec.
  const ev2 = dispatch(inp, 'keydown', { key: 'Escape' });
  ok(!NXModal.isOpen(), 'druhy Escape (bez nasepkavaca) uz zavrie formular');
  ok(ev2._immediate, 'a modal si ho spotreboval');
})();

(function(){
  // Scroll VNUTRI karty modalu: `scroll` z vnutorneho kontajnera NEBUBLA,
  // takze listener MUSI byt v capture faze na window. Bez toho by dropdown
  // ostal visiet na starom mieste — nad cudzim riadkom.
  const inp = DOC.getElementById('nd_kod');
  dispatch(inp, 'focus');
  const box = DOC.getElementById('mdSgBox');
  eq(box.style.display, '', 'nasepkavac je znovu otvoreny');
  const scroller = DOC.querySelector('.mbody');
  fireScroll(scroller);
  eq(box.style.display, 'none',
     'audit ŠT-2c #11/#13: scroll VNUTRI karty modalu nasepkavac zavrel');
})();

// ===================== 7) zdrojove guardy z-vrstiev ==========================
(function(){
  const fs = require('node:fs');
  const css = fs.readFileSync(path.join(JS, '..', 'css', 'panel.css'), 'utf8');
  const html = fs.readFileSync(path.join(JS, '..', 'studio.html'), 'utf8');
  ok(css.indexOf('#mdSgBox { position: fixed; z-index: var(--nx-z-suggest, 80)') > -1,
     'audit ŠT-2c #11: `panel.css` nema vlastne cislo vrstvy — cita premennu');
  // KOV-H2: kostru nacitavaju UZ OBE okna, takze jej CSS (a s nim aj definicia
  // vrstiev) sa presunulo zo `studio.html` do zdielaneho `panel.css`. Pravidlo
  // sa nezmenilo — obe cisla musia zit na JEDNOM mieste, pri `.nxscrim`.
  const scrim = css.match(/--nx-z-scrim:\s*(\d+);\s*--nx-z-suggest:\s*(\d+);/);
  ok(scrim, 'obe vrstvy su definovane na JEDNOM mieste — pri `.nxscrim`');
  ok(html.indexOf('--nx-z-scrim:') === -1,
     'a `studio.html` uz vlastnu kopiu definicie NEMA (dva modalove svety)');
  ok(html.indexOf('.nxmcard {') === -1,
     'ani vlastnu kopiu karty kostry — pravidla ziju v zdielanom `panel.css`');
  ok(Number(scrim[2]) > Number(scrim[1]),
     'a nasepkavac je NAD scrimom (inak by bol v modali viditelny, ale neklikatelny)');
})();

console.log('OK test_st2c_modal.js — ' + n + ' kontrol');
