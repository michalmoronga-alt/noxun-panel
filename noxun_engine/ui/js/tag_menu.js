  // ============ D-27: OKNO VIDITELNOSTI NOXUN TAGOV (rail Inspectora) =======
  // Rychle „zobraz/skry" tagov MODELU (Čelá · Chrbát · …) priamo v paneli, aby
  // sa nemuselo preklikavat do natívneho okna Tags SketchUpu.
  //
  // NIE JE to spodny pas nahladu z UI-B2: tie chipy prepinaju vrstvy KRESBY
  // v paneli, tu ide o viditelnost v modeli.
  //
  // Vlastny maly markup (UI_DIZAJN §5.11: zdiela sa ZONA a SPRAVANIE, obsah len
  // ked je za oboma rohmi TO ISTE nastavenie — toto je ine nastavenie nez
  // 3-stavova kontrola hran, takze `edge_menu.js` sa naň nenatahuje).
  //
  // Modul je CISTY (ziadny DOM, ziadny stav): dostane serverovy stav, vrati
  // retazec markupu. Otvorenost okna si drzi panel sam (cisto zobrazovacia vec).
  (function(global){
    'use strict';

    function esc(s){
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function rowsOf(st){
      var r = st && st.rows;
      return Object.prototype.toString.call(r) === '[object Array]' ? r : [];
    }

    // Kolko NOXUN tagov v modeli NEVIDNO. Cislo pocita SERVER (`Tags.state`);
    // tu sa len tolerantne precita — panel si nic nedopocitava.
    function hiddenCount(st){
      var n = st && st.hidden;
      if (n == null || isNaN(n)) return 0;
      return Number(n);
    }

    // Stav ikony v raile. Ciste rozhodovanie (Node testy) — DOM nasadzuje shell.
    //   available — v modeli je aspon jeden NOXUN tag (inak sa neda co prepnut)
    //   on        — nieco je skryte (ikona sa rozsvieti: „pozor, nevidis vsetko")
    //   icon      — sprite kluc (`eye` / `eye-off`), ziadna nova kresba
    function railState(st){
      var rows = rowsOf(st);
      var hidden = hiddenCount(st);
      if (!rows.length){
        return { available: false, on: false, icon: 'eye',
                 tip: 'Viditeľnosť tagov — v modeli zatiaľ nie sú NOXUN tagy' };
      }
      if (hidden > 0){
        return { available: true, on: true, icon: 'eye-off',
                 tip: 'Viditeľnosť tagov — skrytých je ' + hidden + ' z ' + rows.length };
      }
      return { available: true, on: false, icon: 'eye',
               tip: 'Viditeľnosť tagov v modeli (Čelá · Chrbát · …)' };
    }

    // Riadok = checkbox + nazov tagu. Skryty PRIECINOK tagov sa PRIZNA
    // (tag sam je zapnuty, ale v modeli ho aj tak nevidno) — jantarova
    // poznamka, nikdy tiche klamstvo.
    //
    // opts.fn — meno globalnej funkcie, ktora prepnutie posle do Ruby,
    // opts.id — id uzla.
    function menuHtml(st, open, opts){
      var cfg = opts || {};
      var fn = cfg.fn || 'onTagOption';
      var id = cfg.id || 'railTagsMenu';
      var rows = rowsOf(st);
      var cls = 'tgmenu' + (open ? ' open' : '');
      var h = '<div class="' + cls + '" id="' + id + '" role="group"' +
              ' aria-label="Viditeľnosť tagov v modeli">' +
              '<div class="mgrp">Viditeľnosť v modeli</div>';
      if (!rows.length){
        return h + '<div class="tgempty">Zatiaľ tu nie sú žiadne NOXUN tagy — ' +
               'vzniknú s prvou skrinkou alebo doskou.</div></div>';
      }
      rows.forEach(function(r){
        var key = String(r && r.key != null ? r.key : '');
        var on = r && r.visible === true;
        h += '<label class="tgopt"><input type="checkbox"' + (on ? ' checked' : '') +
             ' onchange="' + fn + '(\'' + esc(key) + '\', this.checked)">' +
             '<span>' + esc(r && r.label) + '</span>';
        if (r && r.folder_hidden === true){
          h += '<b class="tgnote" title="Tag je zapnutý, ale jeho priečinok tagov je skrytý">' +
               'priečinok skrytý</b>';
        }
        h += '</label>';
      });
      return h + '</div>';
    }

    // Payload do Ruby: identita dokumentu + kluc + STRIKTNY boolean. O platnosti
    // kluca aj o zapise rozhoduje SERVER (whitelist `Tags::KEYS`) — retazec
    // "false" je v Ruby pravdivy, preto sa hodnota porovnava === true.
    function togglePayload(base, key, value){
      var b = base || {};
      return { model_guid: b.model_guid || '',
               key: String(key == null ? '' : key),
               value: value === true };
    }

    var API = { menuHtml: menuHtml, railState: railState,
                togglePayload: togglePayload, hiddenCount: hiddenCount };
    global.NXTagMenu = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
