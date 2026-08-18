  // ============ UI-B3: NASTAVENIA INSPECTORA (koliesko) + ROZMEROVE RADY ======
  //
  // Dve veci, obe su nastavenie POCITACA (%APPDATA%\NOXUN\Engine\), nie zakazky:
  //   * TEMA (NOXUN / Lucia) — prepinac volá EXISTUJUCE Ruby API z UI-01
  //     (Engine.set_ui_theme) cez tenky callback; farby nasadi Ruby vsetkym
  //     otvorenym oknam cez nxThemeApply (win_fit.js). JS ziadnu paletu nemeni.
  //   * ROZMEROVE RADY (N6) — bezne hodnoty ponukane sipkou pri rozmerovom poli.
  //     Vyber hodnoty ide EXISTUJUCOU zapisovou cestou pola (zapis hodnoty +
  //     povodna udalost `input`), takze vsetky guardy — vyrazy (expr.js),
  //     validacia, debounce apply, zamky vkladacej karty D-39 — bezia nezmenene.
  //     ZIADNA nova zapisova logika.
  //
  // Koliesko otvara MODAL (nie novy kontext raily): NXShell drzi stavovy stroj
  // „co je oznacene x co chce pouzivatel vidiet" a nastavenia pocitaca don
  // nepatria — musia byt dostupne aj vtedy, ked nie je oznacene nic.

  var NXDim = (function(){
    'use strict';
    // Zrkadlo Ruby DimSeries (core/dim_series.rb) — obe strany musia povedat
    // to iste. AUTORITA je Ruby: co sa naozaj ulozi, rozhoduje server a posle
    // to spat cez NX.setUiSettings.
    var KEYS = ['sirka', 'vyska', 'hlbka', 'sokel', 'vyska_cela'];
    var DEFAULTS = {
      sirka: [400, 450, 500, 600, 800, 900],
      vyska: [720, 820, 900],
      hlbka: [320, 510, 560],
      sokel: [100, 120, 150],
      vyska_cela: [140, 180, 280, 356]
    };
    // Rozsah je FILTER, nie clamp (Codex audit FIX 4): hodnota mimo rozsahu sa
    // ZAHODI — ponuka smie obsahovat len to, co pouzivatel naozaj napisal.
    // MIN 10 mm: rad ponuka ROZMERY nabytku — jednociferna hodnota je vzdy
    // preklep (typicky „140,5" s desatinnou ciarkou, ktoru editor deli).
    var MIN_MM = 10, MAX_MM = 3000, MAX_VALUES = 24;
    var state = { series: null };

    // Jedna hodnota: cislo alebo ciselny retazec. Vysledok su VZDY cele mm.
    // Codex audit FIX 5: CIARKA je v editore ODDELOVAC hodnot, takze sa tu
    // NEBERIE ako desatinna (inak by sa „140,5" rozpadlo na 140 a 5).
    // Nezmysel, prazdno, boolean a nekonecno vypadnu.
    function num(v){
      if (v === null || v === undefined || typeof v === 'boolean') return null;
      var n;
      if (typeof v === 'number'){
        n = v;
      } else {
        var s = String(v).replace(/^\s+|\s+$/g, '');
        if (!/^-?\d+(\.\d+)?$/.test(s)) return null;
        n = parseFloat(s);
      }
      if (!isFinite(n)) return null;
      return Math.round(n);
    }
    // Jeden rad: cele mm v rozsahu, bez duplicit, vzostupne, orezany poctom.
    // PRAZDNE pole je platny vysledok (pouzivatel smie rad vypnut); to, co
    // polom vobec nie je, vrati null — volajuci dosadi default.
    function normalizeList(raw){
      if (!raw || Object.prototype.toString.call(raw) !== '[object Array]') return null;
      var seen = {}, out = [];
      for (var i = 0; i < raw.length; i++){
        var n = num(raw[i]);
        if (n === null || n < MIN_MM || n > MAX_MM) continue;
        if (seen[n]) continue;
        seen[n] = true;
        out.push(n);
      }
      out.sort(function(a, b){ return a - b; });
      return out.slice(0, MAX_VALUES);
    }
    function normalize(raw){
      var src = (raw && typeof raw === 'object') ? raw : {};
      var out = {};
      KEYS.forEach(function(k){
        var list = normalizeList(src[k]);
        out[k] = list || DEFAULTS[k].slice();
      });
      return out;
    }
    function series(){
      if (!state.series) state.series = normalize(null);
      return state.series;
    }
    // Text editora -> pole cisel. Oddelovac je ciarka, bodkociarka aj medzera.
    function parseText(text){
      return String(text == null ? '' : text).split(/[,;\s]+/)
        .filter(function(s){ return s !== ''; });
    }
    function formatList(list){
      return (list || []).join(', ');
    }
    // HTML mini-ponuky pri poli. Hodnoty su CISLA po normalizacii — do markupu
    // nejde ziadny pouzivatelsky retazec.
    function menuHtml(key, inputId){
      var vals = series()[key] || [];
      var html = '';
      for (var i = 0; i < vals.length; i++){
        html += '<button type="button" onclick="nxDimPick(\'' + inputId + '\',' + vals[i] + ')">' +
                vals[i] + '</button>';
      }
      html += '<button type="button" class="miniedit" onclick="openInspectorSettings(\'series\')">' +
              (typeof NXIcons !== 'undefined' && NXIcons ? NXIcons.svg('settings') : '') +
              'Upraviť rad…</button>';
      return html;
    }

    return {
      KEYS: KEYS, DEFAULTS: DEFAULTS, MAX_VALUES: MAX_VALUES,
      normalizeList: normalizeList, normalize: normalize,
      parseText: parseText, formatList: formatList, menuHtml: menuHtml,
      get: function(key){ return (series()[key] || []).slice(); },
      all: function(){ return series(); },
      set: function(raw){ state.series = normalize(raw); return state.series; }
    };
  })();

  // Node testy (tests/js/test_uib3_korpus.js) — v CEF je module undefined a DOM
  // cast nizsie bezi normalne (rovnaky vzor ako shell.js / insert_state.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = NXDim;
  }

  // ===== DOM: mini-ponuka rozmeroveho radu ==================================
  // Ktore pole ma ktory rad. Pole 'thickness' rad NEMA — hrubku urcuje material.
  var NX_DIM_FIELDS = [
    { id: 'width',        key: 'sirka' },
    { id: 'height',       key: 'vyska' },
    { id: 'depth',        key: 'hlbka' },
    { id: 'floor_height', key: 'sokel' }
  ];

  function nxDimRenderMenus(){
    NX_DIM_FIELDS.forEach(function(f){
      var box = el('dimser_' + f.id);
      if (box) box.innerHTML = NXDim.menuHtml(f.key, f.id);
    });
  }

  function nxDimCloseMenus(){
    var open = document.querySelectorAll('.miniopts.on');
    for (var i = 0; i < open.length; i++) open[i].classList.remove('on');
  }

  // Sipka pri poli. Ponuka je otvorena najviac JEDNA (rovnako ako natívna
  // rozbalovacka) a klik mimo nej ju zavrie.
  function nxDimToggle(btn, ev){
    if (ev) ev.stopPropagation();
    var box = btn.parentNode.querySelector('.miniopts');
    if (!box) return;
    var on = box.classList.contains('on');
    nxDimCloseMenus();
    if (!on) box.classList.add('on');
  }

  // Vyber hodnoty z radu. Hodnota sa zapise do pola a ohlasi sa POVODNOU
  // udalostou — dalej uz bezi presne to, co pri pisani rukou (onField, expr
  // hint, validacia, debounce apply, zamky D-39).
  function nxDimPick(inputId, value){
    var inp = el(inputId);
    nxDimCloseMenus();
    if (!inp) return;
    inp.value = String(value);
    inp.dispatchEvent(new Event('input', { bubbles: true }));
    try { inp.focus(); } catch (e) {}
  }

  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(){ nxDimCloseMenus(); });
  }

  // ===== DOM: modal Nastavenia Inspectora ===================================
  // Farebne vzorky prepinaca temy. Su to LITERALY zamerne: vzorka musi ukazat
  // farbu temy, ktoru PONUKA — cez var(--nx-select) by obe vzorky ukazovali
  // prave nasadenu temu. Zrkadlo :root (panel.css) a NX_THEME_TOKENS
  // (win_fit.js) — rovnaky vzor ako kreslene farby nahladu.
  var NX_THEME_SWATCH = { noxun: '#107787', lucia: '#c2185b' };

  function nxThemeNow(){
    var root = document.documentElement;
    var v = root ? root.getAttribute('data-nx-theme') : null;
    return (v === 'lucia') ? 'lucia' : 'noxun';
  }

  function nxSyncThemeButtons(){
    var btns = document.querySelectorAll('#cfgModal .thbtn');
    var now = nxThemeNow();
    for (var i = 0; i < btns.length; i++){
      var on = btns[i].getAttribute('data-theme') === now;
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }

  // Prepnutie temy. Zapis aj nasadenie robi Ruby (Engine.apply_ui_theme) —
  // panel si ZIADNU temu nedrzi a farby si sam nemeni; spat pride nxThemeApply
  // do VSETKYCH otvorenych okien.
  function onSetUiTheme(name){
    if (window.sketchup && sketchup.nx_set_ui_theme)
      sketchup.nx_set_ui_theme(JSON.stringify({ theme: name }));
  }

  function nxFillSeriesEditor(){
    var all = NXDim.all();
    NXDim.KEYS.forEach(function(k){
      var inp = el('ser_' + k);
      if (inp) inp.value = NXDim.formatList(all[k]);
    });
  }

  // Ulozenie radov. Server normalizuje (cisla, rozsah, duplicity, poradie) a
  // vrati, co naozaj ulozil — az tym sa prekreslia ponuky pri poliach.
  function saveDimSeries(){
    var out = {};
    NXDim.KEYS.forEach(function(k){
      var inp = el('ser_' + k);
      out[k] = NXDim.parseText(inp ? inp.value : '');
    });
    if (window.sketchup && sketchup.nx_set_dim_series)
      sketchup.nx_set_dim_series(JSON.stringify({ series: out }));
  }

  // Predvolene rady — len do POLI editora (ulozi ich az „Uložiť rady").
  function resetDimSeriesFields(){
    NXDim.KEYS.forEach(function(k){
      var inp = el('ser_' + k);
      if (inp) inp.value = NXDim.formatList(NXDim.DEFAULTS[k]);
    });
  }

  // Otvorenie kolieska. `section` = ktora skupina sa ma rozbalit
  // ('theme' | 'series' | 'about'); bez nej ostane stav z minula.
  //
  // Codex audit FIX 9: fokus MUSI ist dovnutra modalu — inak ostane na koliesku
  // pod prekrytim, Escape sa k listeneru nedostane a Tab by chodil po prvkoch
  // pod modalom. Rovnaky vzor ako modal sablony (fokus dnu, trap, navrat).
  var cfgReturnFocus = null;
  function openInspectorSettings(section){
    var m = el('cfgModal');
    if (!m) return;
    nxDimCloseMenus();
    nxFillSeriesEditor();
    nxSyncThemeButtons();
    if (section){
      var target = el('cfg_' + section);
      if (target) target.open = true;
    }
    try { cfgReturnFocus = document.activeElement; } catch (e) { cfgReturnFocus = null; }
    m.style.display = 'flex';
    nxBindCfgModal();
    var first = m.querySelector('summary, button, input');
    if (first){ try { first.focus(); } catch (e) {} }
  }

  function closeInspectorSettings(){
    var m = el('cfgModal');
    if (m) m.style.display = 'none';
    if (cfgReturnFocus){ try { cfgReturnFocus.focus(); } catch (e) {} }
    cfgReturnFocus = null;
  }

  var cfgModalBound = false;
  function nxBindCfgModal(){
    if (cfgModalBound) return;
    cfgModalBound = true;
    var m = el('cfgModal');
    if (!m) return;
    m.addEventListener('keydown', function(ev){
      if (ev.key === 'Escape'){ ev.preventDefault(); closeInspectorSettings(); return; }
      if (ev.key !== 'Tab') return;
      // focus trap — fokus nesmie vypadnut na prvky pod prekrytim
      var f = m.querySelectorAll('summary, button, input, select');
      if (!f.length) return;
      var first = f[0], last = f[f.length - 1];
      if (ev.shiftKey && document.activeElement === first){ ev.preventDefault(); last.focus(); }
      else if (!ev.shiftKey && document.activeElement === last){ ev.preventDefault(); first.focus(); }
    });
    // klik na tmave pozadie = zavriet (klik v karte nie)
    m.addEventListener('mousedown', function(ev){ if (ev.target === m) closeInspectorSettings(); });
  }

  // Nastavenia z Ruby (push_init aj maly push po zmene). Meni LEN rady a stav
  // prepinaca — ziadny render karty, ziadny zasah do rozpisaneho formulara.
  function nxApplyUiSettings(data){
    var d = data || {};
    NXDim.set(d.dim_series);
    nxDimRenderMenus();
    nxSyncThemeButtons();
  }
