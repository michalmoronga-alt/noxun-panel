  // ============ ZDIELANE 3-STAVOVE NASTAVENIE KONTROLY HRAN (D-105) =========
  // JEDNO nastavenie pre DVA vstupne body:
  //   * okno Štúdio -> sekcia KONTROLA -> roh tlačidla „Zvýrazniť hrany",
  //   * Inspector   -> rail -> rohový trojuholník pri ABS kontrole (v0.7.28).
  // Nie su to dve kopie: markup, texty aj payload do Ruby zije TU, stav
  // prepinacov a pocty nesie VYHRADNE server (EdgeCheck v %APPDATA%) a chodi
  // oboma kanalmi naraz (Engine.broadcast_edge_check). Zmena v jednom okne je
  // preto okamzite vidiet v druhom — vratane zivych poctov.
  //
  // Modul je CISTY (ziadny DOM, ziadny stav): dostane serverovy stav, vrati
  // retazec markupu. Otvorenost okna si drzi kazde okno samo (cisto zobrazovacia
  // vec, nikam sa neuklada).
  (function(global){
    'use strict';

    // Poradie = poradie v UI. Nazvy su ZRKADLOM ProductionCore::EDGE_OPTION_LABELS
    // (server je jediny zdroj textov) a klucov EdgeCheck::SHOW_KEY.
    var ROWS = [
      { key: 'show_missing', state: 'missing', label: 'Chýba podľa pravidla' },
      { key: 'show_extra',   state: 'extra',   label: 'Neolepené mimo pravidla' },
      { key: 'show_taped',   state: 'taped',   label: 'Olepené' }
    ];
    var SUB_KEY = 'taped_selected_only';

    function num(v){ return (v == null || isNaN(v)) ? 0 : Number(v); }

    // Prazdny vyber pri zapnutom „len vybrané" = zelena sa nekresli. Povedz to
    // nahlas (tiche zobrazenie vsetkeho by klamalo).
    function selectionHint(st){
      if (!st || !st.active) return false;
      var o = st.options || {};
      return o.show_taped === true && o[SUB_KEY] === true && st.selection_empty === true;
    }

    // Rozbalovacie okno: tri stavy (checkbox + farebny stvorcek + nazov + ZIVY
    // POCET) a pod zelenou odsadeny podriadeny prepinac „len vybrané".
    //
    // opts.fn    — meno globalnej funkcie, ktora prepnutie posle do Ruby
    //              (Studio `edgeCheckOption`, rail `onEdgeMenuOption`);
    // opts.id    — id uzla (kazde okno ma vlastne),
    // opts.cls   — doplnkova trieda (rail pridava `ecmenu-rail` = ina pozicia).
    function menuHtml(st, open, opts){
      var o = (st && st.options) || {};
      var c = (st && st.counts) || null;
      var cfg = opts || {};
      var fn = cfg.fn || 'edgeCheckOption';
      var id = cfg.id || 'ecMenu';
      var cls = 'ecmenu' + (cfg.cls ? ' ' + cfg.cls : '') + (open ? ' open' : '');
      var h = '<div class="' + cls + '" id="' + id + '" role="group"' +
              ' aria-label="Nastavenie ABS kontroly — ktoré stavy hrán sa zvýraznia">';
      ROWS.forEach(function(r){
        h += '<label class="ecopt"><input type="checkbox"' + (o[r.key] ? ' checked' : '') +
             ' onchange="' + fn + '(\'' + r.key + '\', this.checked)">' +
             '<i class="ecsw ecsw-' + r.state + '" aria-hidden="true"></i>' +
             '<span>' + r.label + '</span>' +
             '<b class="eccnt">' + (c ? num(c[r.state]) : '—') + '</b></label>';
        if (r.key !== 'show_taped') return;
        h += '<label class="ecopt ecsub"><input type="checkbox"' +
             (o[SUB_KEY] ? ' checked' : '') +
             ' onchange="' + fn + '(\'' + SUB_KEY + '\', this.checked)">' +
             '<span>len vybrané</span>' +
             (selectionHint(st) ? '<b class="ecnote">označ skrinky v modeli</b>' : '') +
             '</label>';
      });
      return h + '</div>';
    }

    // Payload do Ruby: klient posiela LEN identitu + kluc + boolean. O platnosti
    // kluca aj o zapise rozhoduje SERVER (whitelist + striktny boolean) —
    // retazec "false" je v Ruby pravdivy, preto sa hodnota porovnava === true.
    function optionPayload(base, key, value){
      var b = base || {};
      var p = { gen: b.gen || 0, model_guid: b.model_guid || '' };
      p.key = String(key == null ? '' : key);
      p.value = value === true;
      return p;
    }

    var API = { ROWS: ROWS, SUB_KEY: SUB_KEY, num: num,
                menuHtml: menuHtml, selectionHint: selectionHint,
                optionPayload: optionPayload };
    global.NXEdgeMenu = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
