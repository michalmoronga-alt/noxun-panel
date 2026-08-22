  // ============ D-15: ZDIELANA KOSTRA MODALOV („pridavaciek") ================
  // Schvaleny vzor kontraktu UI 2.0 (`SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`,
  // sekcia „D-15 pridavacky ako modal"): JEDNA kostra pre vsetky okna typu
  // „pridaj nieco" — titulok s podtitulom a krizikom (`mhead`) · polia (`mbody`)
  // · Zrusit + ZELENE potvrdenie (`mfoot`); Esc aj klik na scrim zatvaraju;
  // fokus ide do PRVEHO pola a pri zatvoreni sa vracia na spustac.
  //
  // Vzor je `edge_menu.js`: markup, texty aj spravanie ziju na JEDNOM mieste,
  // instancie sa lisia LEN poliami. Prvu kodovu instanciu priniesla ŠT-1c PR B2
  // (drafty rozpoctu — vlastny riadok + spotrebic); ŠT-2c PR 2c-1 kostru
  // rozsirila o to, co potrebuje D-69 editor materialu: typy poli `group`
  // (nadpis sekcie formulara), `rows` (opakovatelne riadky), `checkbox`,
  // `color`, sirkove varianty karty a PAMAT ROZPISANYCH HODNOT v komponente.
  //
  // KONTRAKT (audit #9): komponent spravuje VYHRADNE modaly, ktore si ho
  // vyziadaju cez `NXModal.open`. Fazove okno prepoctu cien (`#budPrModal`
  // v budget.js) ho NEPREBERA — ma vlastny zivotny cyklus riadeny SERVEROM
  // a vo faze `run` sa Escapom zatvorit NESMIE (beh by zostal visiet bez okna).
  // Preto:
  //   * Escape handler tohto komponentu zatvara LEN jeho vlastny modal,
  //   * okno, ktore ma vlastny Escape handler (Studio, ecMenu), sa musi
  //     podmienit `NXModal.isOpen() === false` — listenery visia na
  //     `document` a `stopPropagation` medzi nimi NEFUNGUJE (lekcia
  //     studio.js: dva listenery na tom istom uzle).
  //
  // ZAPIS NEZATVARA MODAL. `open` len posle hodnoty cez `onSubmit`; zavriet ho
  // musi volajuci az vtedy, ked SERVER zapis POTVRDI (GH #138 P2 / audit #10):
  // odmietnuty zapis musi pouzivatel najst s rozpisanymi hodnotami na mieste,
  // nie ako prazdny formular.
  (function(global){
    'use strict';

    var ROOT_ID = 'nxModalRoot';
    // Otvoreny modal: { spec, trigger } — trigger je uzol, na ktory sa vracia
    // fokus po zatvoreni. Naraz zije NAJVIAC JEDEN (dve „pridavacky" na
    // obrazovke naraz su vzdy chyba navrhu, nie stav).
    var OPEN = null;

    // --- PAMAT ROZPISANYCH HODNOT (audit ŠT-2c #12) --------------------------
    // Do ŠT-2c ju drzal KAZDY volajuci sam (rozpocet cez `BUD_DRAFT_VALUES`).
    // Teraz je v komponente, lebo je to sucast kontraktu D-15 („Esc nesmie byt
    // ticha strata rozpisaneho riadku") — nie vlastnost rozpoctu.
    //
    // Kluc `memoryKey` je MODE + CIEL, nie len druh okna: `custom`,
    // `appliance`, ale aj `edit:H3303`. Drzi sa NAJVIAC JEDEN zaznam na „mode"
    // (cast pred prvou dvojbodkou), takze otvorenie EDITORA INEHO dekoru je iny
    // ciel a stara rozpisana verzia ZANIKA — formular je cisty. Bez toho by sa
    // do dekoru B predvyplnili hodnoty, ktore pouzivatel pisal do dekoru A,
    // a ulozil by ich do nespravneho zaznamu.
    var MEM = {};

    function esc(s){
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function ico(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

    function optionsHtml(options, value){
      var h = '';
      (options || []).forEach(function(o){
        h += '<option value="' + esc(o[0]) + '"' +
             (String(o[0]) === String(value == null ? '' : value) ? ' selected' : '') +
             '>' + esc(o[1]) + '</option>';
      });
      return h;
    }

    function isHex(v){ return /^#[0-9a-fA-F]{6}$/.test(String(v == null ? '' : v)); }

    // Jedno pole. `type`:
    //   'text' (default) · 'select' (`options` = [hodnota, popis]) ·
    //   'checkbox' (hodnota je BOOLEAN) · 'color' (vzorka + textovy #RRGGBB) ·
    //   'group' (NADPIS sekcie formulara, hodnotu nema) ·
    //   'rows' (opakovatelne riadky, hodnota je POLE HASHOV).
    // `cls` je doplnkova trieda vstupu (napr. `mshort`).
    function fieldHtml(f){
      var d = f || {};
      if (d.type === 'group'){
        return '<div class="mgroup"><h4>' + esc(d.label) + '</h4>' +
               (d.hint ? '<span>' + esc(d.hint) + '</span>' : '') + '</div>';
      }
      if (d.type === 'rows') return rowsHtml(d, d.value);
      var key = esc(d.key);
      var id = 'nxm_' + key;
      var lbl = '<label for="' + id + '">' + esc(d.label) + '</label>';
      var cls = d.cls ? ' class="' + esc(d.cls) + '"' : '';
      var hint = d.hint ? '<span class="munit">' + esc(d.hint) + '</span>' : '';
      var input;
      if (d.type === 'select'){
        input = '<select id="' + id + '" data-nxm="' + key + '"' + cls + '>' +
                optionsHtml(d.options, d.value) + '</select>';
      } else if (d.type === 'checkbox'){
        // Zaskrtavatko ma popis VEDLA seba, nie pod stlpcom vstupov — inak by
        // sa v dlhom formulari citalo ako prazdny riadok.
        input = '<input id="' + id + '" type="checkbox" data-nxm="' + key + '"' + cls +
                (d.value === true ? ' checked' : '') + '>';
        return '<div class="mrow mcheck">' + lbl + input + hint + '</div>';
      } else if (d.type === 'color'){
        // Vzorka + text: farba sa v katalogu zapisuje ako #RRGGBB, takze
        // pouzivatel musi vediet hodnotu aj PRECITAT a skopirovat, nie iba
        // kliknut do palety.
        var col = String(d.value == null ? '' : d.value);
        input = '<span class="mswatch" id="' + id + '_sw" data-nxm-swatch="' + key + '"' +
                (isHex(col) ? ' style="background:' + esc(col) + '"' : '') + '></span>' +
                '<input id="' + id + '" type="text" data-nxm="' + key + '" data-nxm-color="1"' +
                ' class="' + esc(d.cls || 'mshort') + '" value="' + esc(col) + '"' +
                ' placeholder="#RRGGBB" maxlength="7">';
      } else {
        input = '<input id="' + id + '" type="text" data-nxm="' + key + '"' + cls +
                ' value="' + esc(d.value == null ? '' : d.value) + '"' +
                (d.placeholder ? ' placeholder="' + esc(d.placeholder) + '"' : '') + '>';
      }
      return '<div class="mrow">' + lbl + input + hint + '</div>';
    }

    // --- REPEATER `rows` (audit ŠT-2c #14) -----------------------------------
    // `cols` je definicia POD-poli jedneho riadku, hodnota pola je POLE HASHOV
    // (`values()` ho tak aj vracia — ploche polia ostavaju retazcami, aby sa
    // draftom rozpoctu nic nezmenilo).
    //
    // `hidden` su kluce, ktore riadok NESIE, ale nezobrazuje — typicky
    // `material_id`/`row_rev`. Podla nich server odlisi UPRAVU existujuceho
    // variantu od NOVEHO: riadok pridany tlacidlom „+" ich nema, takze je novy.
    // Identita variantu sa tym padom NIKDY neodvodzuje od kodu, ktory
    // pouzivatel prave prepisuje.
    function rowsInnerHtml(f, data){
      var d = f || {};
      var key = esc(d.key);
      var arr = (data && data.length) ? data : [];
      var min = Number(d.min || 0);
      var h = '';
      if (d.label) h += '<div class="mrhead">' + esc(d.label) + '</div>';
      if (arr.length && (d.cols || []).length){
        h += '<div class="mrcols">';
        (d.cols || []).forEach(function(c){ h += '<span>' + esc(c.label) + '</span>'; });
        h += '<span class="mrgap"></span></div>';
      }
      h += '<div class="mrlist" data-nxm-list="' + key + '">';
      if (!arr.length && d.empty) h += '<div class="mrempty">' + esc(d.empty) + '</div>';
      arr.forEach(function(row){
        h += '<div class="mrline" data-nxm-row="' + key + '">';
        (d.hidden || []).forEach(function(hk){
          var hv = row ? row[hk] : null;
          if (hv == null || hv === '') return;
          h += '<input type="hidden" data-nxm-col="' + esc(hk) + '" value="' + esc(hv) + '">';
        });
        (d.cols || []).forEach(function(c){ h += rowCellHtml(c, row ? row[c.key] : ''); });
        h += '<button type="button" class="mrdel" data-nxm-act="rowdel"' +
             (arr.length <= min ? ' disabled' : '') +
             ' title="Odobrať riadok" aria-label="Odobrať riadok">' + ico('trash') + '</button>' +
             '</div>';
      });
      h += '</div>';
      h += '<div class="mradd"><button type="button" class="ghostbtn mrbtn"' +
           ' data-nxm-act="rowadd" data-nxm-rows="' + key + '">' + ico('plus') + ' ' +
           esc(d.addLabel || 'Pridať riadok') + '</button></div>';
      return h;
    }

    function rowsHtml(f, data){
      var key = esc((f || {}).key);
      return '<div class="mrows" id="nxm_' + key + '" data-nxm-rows="' + key + '">' +
             rowsInnerHtml(f, data) + '</div>';
    }

    function rowCellHtml(c, v){
      var d = c || {};
      var k = esc(d.key);
      var cls = ' class="' + esc(d.cls || 'mrcell') + '"';
      if (d.type === 'select')
        return '<select data-nxm-col="' + k + '"' + cls + '>' + optionsHtml(d.options, v) + '</select>';
      if (d.type === 'checkbox')
        return '<input type="checkbox" data-nxm-col="' + k + '"' + cls +
               (v === true ? ' checked' : '') + '>';
      return '<input type="text" data-nxm-col="' + k + '"' + cls +
             ' value="' + esc(v == null ? '' : v) + '"' +
             (d.placeholder ? ' placeholder="' + esc(d.placeholder) + '"' : '') + '>';
    }

    // Sirka karty. `size`: 'sm' (420, default a `small` je jeho alias) ·
    // 'md' (560) · 'wide' (~640 — editor s opakovatelnymi riadkami). Stary
    // prepinac `small: false` (= md) ostava funkcny, aby sa existujuce
    // pridavacky nemuseli prepisovat.
    function cardCls(s){
      var d = s || {};
      var sz = d.size;
      if (sz == null) sz = (d.small === false) ? 'md' : 'sm';
      sz = String(sz);
      if (sz === 'small') sz = 'sm';
      if (sz === 'wide') return ' wide';
      if (sz === 'md') return '';
      return ' sm';
    }

    // CISTY markup modalu (testovatelny bez DOM). Scrim je SURODENEC karty,
    // nie jej rodic v zmysle klikov: klik na scrim zatvara len vtedy, ked
    // `event.target` je PRAVE on (klik do karty nesmie okno zavriet).
    // POZOR na mena tried: mockup kresli scrim ako `.nxscrim` a KARTU ako
    // `.nxmodal` — lenze `panel.css` (nacitava ho aj Studio) uz meno `.nxmodal`
    // pouziva pre SCRIM starsich modalov. Karta sa tu preto vola `.nxmcard`;
    // `mhead`/`mbody`/`mfoot`/`mrow` z mockupu ostavaju doslovne.
    function modalHtml(spec){
      var s = spec || {};
      var h = '<div class="nxscrim" data-nxm-scrim="1"><div class="nxmcard' +
              cardCls(s) + '" role="dialog" aria-modal="true"' +
              ' aria-label="' + esc(s.title) + '">' +
        '<div class="mhead"><h3>' + esc(s.title) + '</h3>' +
        (s.sub ? '<span class="msub">' + esc(s.sub) + '</span>' : '') +
        '<button type="button" class="mx" data-nxm-act="close"' +
        ' title="Zavrieť (Esc)" aria-label="Zavrieť">' + ico('x') + '</button></div>' +
        '<div class="mbody">';
      (s.fields || []).forEach(function(f){ h += fieldHtml(f); });
      if (s.note) h += '<div class="hint">' + esc(s.note) + '</div>';
      h += '</div><div class="mfoot"><span class="spacer"></span>' +
        '<button type="button" class="ghostbtn" data-nxm-act="close">Zrušiť</button>' +
        '<button type="button" class="primary" data-nxm-act="submit">' +
        ico('check') + ' ' + esc(s.okLabel || 'Pridať') + '</button></div>';
      return h + '</div></div>';
    }

    function root(){
      if (typeof document === 'undefined') return null;
      var r = document.getElementById(ROOT_ID);
      if (r) return r;
      // Kotva sa vytvori na poziadanie — okno ju v HTML mat nemusi.
      r = document.createElement('div');
      r.id = ROOT_ID;
      if (document.body) document.body.appendChild(r);
      return r;
    }

    function isOpen(){ return OPEN !== null; }

    function spec(){ return OPEN ? OPEN.spec : null; }

    // --- ZAMOK ODOSLANIA (review #2) -----------------------------------------
    // `sketchup.*` je ASYNCHRONNE. Bez zamku by dvojity Enter (alebo dvojklik na
    // „Pridať") odoslal DVE mutacie: prva ide na server, druha padne do fronty
    // klienta (BUD_BUSY/BUD_QUEUE) a odosle sa AZ s cerstvou generaciou — cize
    // ju server PRIJME. Vysledok: polozka v rozpocte DVAKRAT a dva kroky Spat.
    // Zamok patri do KOMPONENTU, nie do rozpoctu: je to zdielana kostra a tu
    // istu pascu by inak zdedila kazda dalsia „pridavacka" (D-69 editor
    // materialu, polozka/set kovania).
    //
    // Odomyka VYHRADNE volajuci — az ked vie, ako zapis dopadol (`setBusy(false)`
    // v OBOCH vetvach vysledku). Modal si to sam odhadnut nevie.
    function isBusy(){ return !!(OPEN && OPEN.busy); }

    // `opts.clear === true` navyse ZAHODI pamat rozpisanych hodnot — je to
    // signal „server zapis POTVRDIL". Rovnaka vec sa da povedat aj priamo cez
    // `clearMemory(key)`; volajuci si vyberie podla toho, ci pri uspechu okno
    // zaroven zatvara.
    function setBusy(flag, opts){
      if (!OPEN) return;
      OPEN.busy = flag === true;
      if (opts && opts.clear === true) clearMemory(OPEN.spec ? OPEN.spec.memoryKey : null);
      if (typeof document === 'undefined') return;
      var r = document.getElementById(ROOT_ID);
      var btn = r && r.querySelector ? r.querySelector('[data-nxm-act="submit"]') : null;
      if (!btn) return;
      // Zosednute tlacidlo je JEDINY viditelny znak, ze zapis prave bezi —
      // bez neho by pouzivatel klikal dalej do zamknuteho okna.
      if (OPEN.busy){
        btn.setAttribute('disabled', 'disabled');
        btn.setAttribute('aria-busy', 'true');
      } else {
        btn.removeAttribute('disabled');
        btn.removeAttribute('aria-busy');
      }
    }

    // Riadky repeatera sa citaju z DOM (nie z drzaneho pola) — pridanie
    // a odobranie riadku prekresluje LEN kontajner, takze rozpisane hodnoty
    // ostatnych riadkov musia prezit prave cez tento zapis.
    function readRows(key){
      var out = [];
      if (typeof document === 'undefined') return out;
      var box = document.getElementById('nxm_' + key);
      if (!box || !box.querySelectorAll) return out;
      var lines = box.querySelectorAll('[data-nxm-row]');
      for (var i = 0; i < lines.length; i++){
        var row = {};
        var cells = lines[i].querySelectorAll ? lines[i].querySelectorAll('[data-nxm-col]') : [];
        for (var j = 0; j < cells.length; j++){
          var c = cells[j];
          var ck = c.getAttribute('data-nxm-col');
          if (c.getAttribute('type') === 'checkbox') row[ck] = !!c.checked;
          else row[ck] = String(c.value == null ? '' : c.value);
        }
        out.push(row);
      }
      return out;
    }

    function fieldByKey(key){
      var found = null;
      ((OPEN && OPEN.spec && OPEN.spec.fields) || []).forEach(function(f){
        if (f && f.type === 'rows' && String(f.key) === String(key)) found = f;
      });
      return found;
    }

    function renderRows(f, data){
      var box = document.getElementById('nxm_' + f.key);
      if (!box) return;
      box.innerHTML = rowsInnerHtml(f, data);
    }

    function rowAdd(key){
      var f = fieldByKey(key);
      if (!f || typeof document === 'undefined') return;
      var cur = readRows(key);
      cur.push({});
      renderRows(f, cur);
      // Fokus do prveho pola PRAVE pridaneho riadku — pridanie riadku je
      // zaciatok pisania, nie samoucelne kliknutie.
      var box = document.getElementById('nxm_' + key);
      var lines = box && box.querySelectorAll ? box.querySelectorAll('[data-nxm-row]') : [];
      var last = lines.length ? lines[lines.length - 1] : null;
      var cells = last && last.querySelectorAll ? last.querySelectorAll('[data-nxm-col]') : [];
      for (var i = 0; i < cells.length; i++){
        if (cells[i].getAttribute('type') === 'hidden') continue;
        try { cells[i].focus(); } catch (e) { /* fokus nie je kriticky */ }
        break;
      }
    }

    function rowDel(btn){
      if (typeof document === 'undefined') return;
      var line = btn && btn.closest ? btn.closest('[data-nxm-row]') : null;
      if (!line) return;
      var key = line.getAttribute('data-nxm-row');
      var f = fieldByKey(key);
      if (!f) return;
      var box = document.getElementById('nxm_' + key);
      var lines = box && box.querySelectorAll ? box.querySelectorAll('[data-nxm-row]') : [];
      var idx = -1;
      for (var i = 0; i < lines.length; i++){ if (lines[i] === line) idx = i; }
      if (idx < 0) return;
      var cur = readRows(key);
      cur.splice(idx, 1);
      renderRows(f, cur);
    }

    // Hodnoty poli -> objekt. Cita sa VZDY z DOM, aby to, co pouzivatel vidi,
    // bolo presne to, co sa odosle. TVAR (audit ŠT-2c #14):
    //   text/select -> RETAZEC (nezmenene — drafty rozpoctu na tom stoja),
    //   checkbox    -> BOOLEAN,
    //   rows        -> POLE HASHOV,
    //   group       -> v hodnotach VOBEC NIE JE (je to nadpis, nie pole).
    function values(){
      var out = {};
      if (!OPEN || typeof document === 'undefined') return out;
      (OPEN.spec.fields || []).forEach(function(f){
        if (!f || f.type === 'group') return;
        if (f.type === 'rows'){ out[f.key] = readRows(f.key); return; }
        var node = document.getElementById('nxm_' + f.key);
        if (f.type === 'checkbox'){ out[f.key] = !!(node && node.checked); return; }
        out[f.key] = node ? String(node.value == null ? '' : node.value) : '';
      });
      return out;
    }

    // --- pamat: kluc, citanie, mazanie, zapis --------------------------------
    function memSlot(key){
      var k = String(key);
      var i = k.indexOf(':');
      return i > 0 ? k.slice(0, i) : k;
    }

    function memory(key){
      if (key == null || key === '') return null;
      var slot = MEM[memSlot(key)];
      return (slot && slot.key === String(key)) ? slot.values : null;
    }

    function clearMemory(key){
      if (key == null || key === '') return;
      var s = memSlot(key);
      if (MEM[s] && MEM[s].key === String(key)) delete MEM[s];
      // Zatvorenie modalu hodnoty zapamätáva — keby sa pamat mazala PRED nim,
      // close() by ju hned zapisal spat. Preto sa zaroven zhasina zapis.
      if (OPEN && OPEN.spec && String(OPEN.spec.memoryKey) === String(key)) OPEN.memSkip = true;
    }

    function hasContent(v){
      var any = false;
      Object.keys(v || {}).forEach(function(k){
        var x = v[k];
        if (x === true) any = true;
        else if (typeof x === 'string' && x !== '') any = true;
        else if (x && typeof x.forEach === 'function'){
          x.forEach(function(r){
            Object.keys(r || {}).forEach(function(rk){
              var rv = r[rk];
              if (rv === true || (typeof rv === 'string' && rv !== '')) any = true;
            });
          });
        }
      });
      return any;
    }

    // Zapamätanie prebieha pri ODOSLANI aj pri ZATVORENI — Escape ani klik
    // vedla nesmie byt ticha strata rozpisaneho formulara. Prazdny formular sa
    // NEPAMÄTÁ (inak by v pamati zostal balast, ktory nikomu nic nepredvyplni).
    function remember(){
      if (!OPEN || OPEN.memSkip) return;
      var key = OPEN.spec ? OPEN.spec.memoryKey : null;
      if (key == null || key === '') return;
      var v = values();
      if (!hasContent(v)){
        var s = memSlot(key);
        if (MEM[s] && MEM[s].key === String(key)) delete MEM[s];
        return;
      }
      MEM[memSlot(key)] = { key: String(key), values: v };
    }

    // Otvorenie INEHO ciela v tom istom rezime stary rozpis ZAHADZUJE — nie
    // az pri najblizsom zapise, ale HNED. Inak by rozpisana verzia dekoru A
    // zila dalej a po zavreti editora dekoru B by sa vratila na obrazovku.
    function dropForeign(key){
      if (key == null || key === '') return;
      var s = memSlot(key);
      if (MEM[s] && MEM[s].key !== String(key)) delete MEM[s];
    }

    // Zapamätane hodnoty sa vlievaju do POLI specifikacie — volajuci teda
    // nemusi o pamati vediet vobec.
    function withMemory(s){
      dropForeign(s.memoryKey);
      var mem = memory(s.memoryKey);
      if (!mem) return s;
      var out = {}, k;
      for (k in s){ if (Object.prototype.hasOwnProperty.call(s, k)) out[k] = s[k]; }
      out.fields = (s.fields || []).map(function(f){
        if (!f || f.type === 'group') return f;
        if (!Object.prototype.hasOwnProperty.call(mem, f.key)) return f;
        var g = {}, kk;
        for (kk in f){ if (Object.prototype.hasOwnProperty.call(f, kk)) g[kk] = f[kk]; }
        g.value = mem[f.key];
        return g;
      });
      return out;
    }

    // Prve pole na fokus. Skryte polia riadkov (`type="hidden"`) sa preskakuju
    // — fokus v nich by nebolo vidno.
    function firstField(r){
      var list = r.querySelectorAll ? r.querySelectorAll('.mbody input, .mbody select') : null;
      if (list && list.length){
        for (var i = 0; i < list.length; i++){
          if (list[i].getAttribute && list[i].getAttribute('type') === 'hidden') continue;
          return list[i];
        }
        return null;
      }
      return r.querySelector ? r.querySelector('.mbody input, .mbody select') : null;
    }

    function open(s){
      if (!s || typeof document === 'undefined') return;
      var r = root();
      if (!r) return;
      var trigger = document.activeElement || null;
      close(); // dva modaly naraz su vzdy chyba navrhu
      var eff = withMemory(s);
      OPEN = { spec: eff, trigger: trigger, busy: false, memSkip: false };
      r.innerHTML = modalHtml(eff);
      // Fokus do PRVEHO pola (kontrakt D-15). `setTimeout` preto, ze CEF
      // priradi fokus az po dokresleni — okamzity `focus()` by sa stratil.
      var first = firstField(r);
      if (first){
        try { first.focus(); } catch (e) { /* fokus nie je kriticky */ }
        setTimeout(function(){ try { first.focus(); } catch (e) {} }, 20);
      }
    }

    function close(){
      if (typeof document === 'undefined'){ OPEN = null; return; }
      remember();                       // Esc nesmie byt ticha strata hodnot
      var r = document.getElementById(ROOT_ID);
      if (r) r.innerHTML = '';
      var back = OPEN && OPEN.trigger;
      OPEN = null;
      // Fokus patri spat na spustac — inak by po zatvoreni skoncil na <body>
      // a klavesnicova cesta by sa prerusila presne tam, kde zacala.
      if (back && back.focus){
        try { back.focus(); } catch (e) { /* uzol uz nemusi zit */ }
      }
    }

    function submit(){
      var s = OPEN && OPEN.spec;
      if (!s) return;
      if (OPEN.busy) return; // review #2: druhy Enter/klik sa ZAHADZUJE
      var v = values();
      remember();            // hodnoty su zapamatane PRED odoslanim
      setBusy(true);
      // Zatvorenie je na volajucom (audit #10) — server moze zapis odmietnut
      // a modal musi ostat otvoreny s hodnotami. Odomknutie tiez: volajuci
      // vola `setBusy(false)` v OBOCH vetvach vysledku.
      if (typeof s.onSubmit === 'function') s.onSubmit(v);
    }

    // --- FOKUS ZOSTAVA V KARTE (review #7) -----------------------------------
    // Tab z posledneho prvku modalu by inak skocil do okna ZA nim — do tabulky
    // rozpoctu, ktoru pouzivatel prave nemoze ovladat. Je to vzor pre VSETKY
    // buduce pridavacky, preto to zije v komponente.
    function focusables(){
      if (typeof document === 'undefined') return [];
      var r = document.getElementById(ROOT_ID);
      var card = r && r.querySelector ? r.querySelector('.nxmcard') : null;
      if (!card || !card.querySelectorAll) return [];
      // POZOR na `[href]`: ikony su inline SVG a `<use href="#i-…">` ten
      // selektor SPLNA — posledny „zameratelny" prvok karty by tak bol kus
      // ikony vnutri potvrdzovacieho tlacidla a Tab by cyklil do prazdna.
      // Odkaz je `a[href]`, nic ine.
      var all = card.querySelectorAll('input, select, textarea, button, a[href], [tabindex]');
      var out = [];
      for (var i = 0; i < all.length; i++){
        var n = all[i];
        if (n.hasAttribute && n.hasAttribute('disabled')) continue;
        if (n.getAttribute && n.getAttribute('tabindex') === '-1') continue;
        // Skryte polia riadkov (id/rev variantu) nie su ovladacie prvky.
        if (n.getAttribute && n.getAttribute('type') === 'hidden') continue;
        out.push(n);
      }
      return out;
    }

    function trapTab(ev){
      var list = focusables();
      if (!list.length) return;           // prazdna karta = niet co cyklit
      var first = list[0];
      var last = list[list.length - 1];
      var at = document.activeElement;
      if (ev.shiftKey){
        if (at !== first && list.indexOf(at) >= 0) return;
        ev.preventDefault();
        try { last.focus(); } catch (e) { /* fokus nie je kriticky */ }
        return;
      }
      if (at !== last && list.indexOf(at) >= 0) return;
      ev.preventDefault();
      try { first.focus(); } catch (e) { /* fokus nie je kriticky */ }
    }

    if (typeof document !== 'undefined'){
      document.addEventListener('click', function(ev){
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.closest) return;
        var act = t.closest('[data-nxm-act]');
        if (act){
          var a = act.getAttribute('data-nxm-act');
          if (a === 'submit') submit();
          else if (a === 'rowadd') rowAdd(act.getAttribute('data-nxm-rows'));
          else if (a === 'rowdel') rowDel(act);
          else close();
          return;
        }
        // Klik VEDLA karty (priamo na scrim) zatvara; klik dovnutra nie.
        if (t.getAttribute && t.getAttribute('data-nxm-scrim') === '1') close();
      });

      // Vzorka farby ide za textom — pouzivatel musi vidiet, co si prave napisal.
      document.addEventListener('input', function(ev){
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.getAttribute || t.getAttribute('data-nxm-color') !== '1') return;
        var sw = document.getElementById('nxm_' + t.getAttribute('data-nxm') + '_sw');
        if (sw && sw.style) sw.style.background = isHex(t.value) ? String(t.value) : '';
      });

      document.addEventListener('keydown', function(ev){
        if (!OPEN) return;
        if (ev.key === 'Escape'){
          close();
          // Escape SPOTREBUJE modal — okno za nim (Studio zatvara Escapom svoje
          // rozbalovacie nastavenie hran) ho uz vidiet nesmie, inak by jedno
          // stlacenie zavrelo OBOJE. `stopPropagation` by nestacilo: oba
          // listenery visia na TOM ISTOM uzle (`document`) a ten ich nezastavi
          // — musi to byt `stopImmediatePropagation`, ktore zastavi aj dalsich
          // poslucháčov toho isteho uzla. Funguje to preto, ze `nx_modal.js` sa
          // nacitava PRED `studio.js` (stráži guard test), takze jeho listener
          // je v poradi prvy; podmienka `!nxModalOpen()` v Studiu ostava ako
          // druha poistka pre pripad opacneho poradia.
          if (ev.stopImmediatePropagation) ev.stopImmediatePropagation();
          return;
        }
        if (ev.key === 'Tab'){ trapTab(ev); return; }
        // Enter v poli = potvrdenie (vzor formulara). Do <select> nezasahuje —
        // tam Enter otvara/potvrdzuje vlastnu ponuku prehliadaca. Plati aj pre
        // bunky opakovatelnych riadkov (`data-nxm-col`), aby sa formular
        // nespraval inak podla toho, v ktorom poli pouzivatel stoji.
        if (ev.key !== 'Enter') return;
        var t = ev.target;
        if (!t || !t.getAttribute) return;
        if (!t.getAttribute('data-nxm') && !t.getAttribute('data-nxm-col')) return;
        if (t.tagName === 'SELECT') return;
        ev.preventDefault();
        submit();
      });
    }

    var API = { ROOT_ID: ROOT_ID, modalHtml: modalHtml, fieldHtml: fieldHtml,
                rowsHtml: rowsHtml, cardCls: cardCls,
                open: open, close: close, submit: submit,
                isOpen: isOpen, isBusy: isBusy, setBusy: setBusy,
                values: values, spec: spec,
                memory: memory, clearMemory: clearMemory };
    global.NXModal = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
