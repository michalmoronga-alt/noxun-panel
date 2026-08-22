  // ============ D-15: ZDIELANA KOSTRA MODALOV („pridavaciek") ================
  // Schvaleny vzor kontraktu UI 2.0 (`SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`,
  // sekcia „D-15 pridavacky ako modal"): JEDNA kostra pre vsetky okna typu
  // „pridaj nieco" — titulok s podtitulom a krizikom (`mhead`) · polia (`mbody`)
  // · Zrusit + ZELENE potvrdenie (`mfoot`); Esc aj klik na scrim zatvaraju;
  // fokus ide do PRVEHO pola a pri zatvoreni sa vracia na spustac.
  //
  // Vzor je `edge_menu.js`: markup, texty aj spravanie ziju na JEDNOM mieste,
  // instancie sa lisia LEN poliami. Tato davka (ŠT-1c PR B2) prinasa PRVU
  // kodovu instanciu — drafty rozpoctu (vlastny riadok + spotrebic); dalsie
  // (D-69 editor materialu, polozka/set kovania) sa napoja bez kopirovania.
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

    function esc(s){
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function ico(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

    // Jedno pole. `type`: 'text' (default) alebo 'select' s `options`
    // ([hodnota, popis]). `cls` je doplnkova trieda vstupu (napr. `mshort`).
    function fieldHtml(f){
      var d = f || {};
      var key = esc(d.key);
      var id = 'nxm_' + key;
      var lbl = '<label for="' + id + '">' + esc(d.label) + '</label>';
      var input;
      if (d.type === 'select'){
        input = '<select id="' + id + '" data-nxm="' + key + '"' +
                (d.cls ? ' class="' + esc(d.cls) + '"' : '') + '>';
        (d.options || []).forEach(function(o){
          input += '<option value="' + esc(o[0]) + '"' +
                   (String(o[0]) === String(d.value == null ? '' : d.value) ? ' selected' : '') +
                   '>' + esc(o[1]) + '</option>';
        });
        input += '</select>';
      } else {
        input = '<input id="' + id + '" type="text" data-nxm="' + key + '"' +
                (d.cls ? ' class="' + esc(d.cls) + '"' : '') +
                ' value="' + esc(d.value == null ? '' : d.value) + '"' +
                (d.placeholder ? ' placeholder="' + esc(d.placeholder) + '"' : '') + '>';
      }
      return '<div class="mrow">' + lbl + input +
             (d.hint ? '<span class="munit">' + esc(d.hint) + '</span>' : '') + '</div>';
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
              (s.small === false ? '' : ' sm') + '" role="dialog" aria-modal="true"' +
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

    // Hodnoty polí -> objekt { key: retazec }. Cita sa VZDY z DOM, aby to, co
    // pouzivatel vidi, bolo presne to, co sa odosle.
    function values(){
      var out = {};
      if (!OPEN || typeof document === 'undefined') return out;
      (OPEN.spec.fields || []).forEach(function(f){
        var node = document.getElementById('nxm_' + f.key);
        out[f.key] = node ? String(node.value == null ? '' : node.value) : '';
      });
      return out;
    }

    function open(s){
      if (!s || typeof document === 'undefined') return;
      var r = root();
      if (!r) return;
      var trigger = document.activeElement || null;
      close(); // dva modaly naraz su vzdy chyba navrhu
      OPEN = { spec: s, trigger: trigger };
      r.innerHTML = modalHtml(s);
      // Fokus do PRVEHO pola (kontrakt D-15). `setTimeout` preto, ze CEF
      // priradi fokus az po dokresleni — okamzity `focus()` by sa stratil.
      var first = r.querySelector('.mbody input, .mbody select');
      if (first){
        try { first.focus(); } catch (e) { /* fokus nie je kriticky */ }
        setTimeout(function(){ try { first.focus(); } catch (e) {} }, 20);
      }
    }

    function close(){
      if (typeof document === 'undefined'){ OPEN = null; return; }
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
      var v = values();
      // Zatvorenie je na volajucom (audit #10) — server moze zapis odmietnut
      // a modal musi ostat otvoreny s hodnotami.
      if (typeof s.onSubmit === 'function') s.onSubmit(v);
    }

    if (typeof document !== 'undefined'){
      document.addEventListener('click', function(ev){
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.closest) return;
        var act = t.closest('[data-nxm-act]');
        if (act){
          if (act.getAttribute('data-nxm-act') === 'submit') submit();
          else close();
          return;
        }
        // Klik VEDLA karty (priamo na scrim) zatvara; klik dovnutra nie.
        if (t.getAttribute && t.getAttribute('data-nxm-scrim') === '1') close();
      });

      document.addEventListener('keydown', function(ev){
        if (!OPEN) return;
        if (ev.key === 'Escape'){ close(); return; }
        // Enter v poli = potvrdenie (vzor formulara). Do <select> nezasahuje —
        // tam Enter otvara/potvrdzuje vlastnu ponuku prehliadaca.
        if (ev.key !== 'Enter') return;
        var t = ev.target;
        if (!t || !t.getAttribute || !t.getAttribute('data-nxm')) return;
        if (t.tagName === 'SELECT') return;
        ev.preventDefault();
        submit();
      });
    }

    var API = { ROOT_ID: ROOT_ID, modalHtml: modalHtml, fieldHtml: fieldHtml,
                open: open, close: close, submit: submit,
                isOpen: isOpen, values: values, spec: spec };
    global.NXModal = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
