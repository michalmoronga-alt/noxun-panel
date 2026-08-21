  // ===================== ŠTÚDIO (ST-1a) =====================
  // Okno zakazky: navigacia vlavo, sekcia vpravo. V tejto davke zije PRVA
  // sekcia — KUSOVNIK (Š1–Š6) s pohladmi Dielce · Platne · ABS.
  //
  // ZELEZNE PRAVIDLO: server je autorita CISEL aj TEXTOV. JS neprepocitava
  // ziadnu sumu (medzisucty skupin idu z `sheets`, sucty zo `totals`, odhad
  // platni zo `sheet_estimate`), nesklada nazvy materialov (`materials_meta`)
  // ani rol (`role_label` v riadku). Klient si pamata VYHRADNE zobrazovacie
  // veci tohto pocitaca — ktore stlpce chce videt, ktore skupiny ma zbalene
  // a ci je navigacia zbalena na ikony (localStorage, nikdy model).
  //
  // Klik do modelu ide RELAY cez panel (flush rozpisanych editov) — vlastnym
  // kanalom `NX.studioRelay`, aby odpoved prisla do TOHTO okna (kazde okno ma
  // vlastny generacny token).

  var ST = null;             // posledny push z Ruby
  var studioSec = 'bom';     // aktivna sekcia (v ST-1a je zivá jedina)
  var bomView = 'parts';     // Š4: parts | sheets | abs
  var bomQ = '';             // Š6: text hladania
  var colMenuOpen = false;   // Š2: rozbalene okno stlpcov (cisto zobrazovacie)
  var navMini = false;       // zbalena navigacia na ikony
  var groupClosed = {};      // Š1: zbalene skupiny per material_id

  // ZRKADLO `StudioDialog::SECTIONS` — autoritou whitelistu je RUBY, tento
  // zoznam len zabrani, aby z okna vyletela hodnota, ktora sekciu nepomenuva.
  var STUDIO_SECTIONS = ['bom'];

  // Š2: stlpce tabulky Dielce. `fixed` sa neda vypnut (bez nazvu dielca by
  // riadok nic nehovoril). „Poznámka" tu ZAMERNE nie je — v Ruby pre nu
  // neexistuje zdroj (vedoma odchylka davky ST-1a, audit #4).
  var COLS = [
    { k: 'name',  t: 'Dielec',       on: true, fixed: true },
    { k: 'cab',   t: 'Skrinka',      on: true },
    { k: 'l',     t: 'Dĺžka',        on: true, num: true },
    { k: 'w',     t: 'Šírka',        on: true, num: true },
    { k: 'th',    t: 'Hr.',          on: true, num: true },
    { k: 'q',     t: 'ks',           on: true, num: true },
    { k: 'abs',   t: 'ABS',          on: true },
    { k: 'grain', t: 'Smer dekoru',  on: false },
    { k: 'role',  t: 'Rola',         on: false }
  ];

  // Navigacia. Polozka je bud SEKCIA (zije tu), PREMOSTENIE (obsah je zatial
  // v inom okne — klik ho otvori a tooltip to prizna) alebo `disabled`
  // s vysvetlenim (vzor D-78: ziadne mrtve tlacidlo bez dovodu).
  var NAV = [
    { grp: 'ZÁKAZKA', items: [
      { id: 'bom',    ic: 'list',            t: 'Kusovník' },
      { id: 'ctrl',   ic: 'clipboard-check', t: 'Kontrola',
        bridge: 'zatiaľ v okne Výroba — presun v ŠT-1b' },
      { id: 'buy',    ic: 'cart',            t: 'Nákup kovania',
        bridge: 'zatiaľ v okne Výroba — presun v ŠT-1c' },
      { id: 'budget', ic: 'euro',            t: 'Rozpočet',
        bridge: 'zatiaľ v okne Výroba — presun v ŠT-1c' },
      { id: 'offer',  ic: 'file-text',       t: 'Cenová ponuka',
        bridge: 'zatiaľ v okne Výroba (súčasť Rozpočtu) — presun v ŠT-1c' },
      { id: 'cut',    ic: 'scissors',        t: 'Nárezový plán',
        disabled: 'fáza 2 — nárezový plán zatiaľ neexistuje' }
    ] },
    { grp: 'KATALÓGY', items: [
      { id: 'mat',    ic: 'layers',   t: 'Materiály', bridge: 'zatiaľ vlastné okno — presun v ŠT-2' },
      { id: 'hw',     ic: 'hammer',   t: 'Kovanie',   bridge: 'zatiaľ vlastné okno — presun v ŠT-3' },
      { id: 'rules',  ic: 'settings', t: 'Pravidlá',  bridge: 'zatiaľ vlastné okno — presun v ŠT-3' },
      { id: 'tpl',    ic: 'star',     t: 'Šablóny',   bridge: 'zatiaľ vlastné okno — presun v ŠT-3' }
    ] },
    { grp: 'NASTAVENIA', items: [
      { id: 'sup',    ic: 'truck', t: 'Dodávateľ / Demos', bridge: 'zatiaľ vlastné okno — presun v ŠT-4' },
      { id: 'bset',   ic: 'euro',  t: 'Nastavenia rozpočtu', bridge: 'zatiaľ vlastné okno — presun v ŠT-4' },
      { id: 'about',  ic: 'info',  t: 'O plugine', bridge: 'obsah je v koliesku Inspectora' }
    ] }
  ];

  var SEC_META = {
    bom: { t: 'Kusovník', hint: 'skupiny podľa materiálu · pohľady Dielce / Platne / ABS · živý zoznam' }
  };

  // ---------------------------------------------------------------- helpers
  function el(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }
  function esc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function num(v, dec){
    return (v == null || isNaN(v)) ? '—' : Number(v).toFixed(dec == null ? 0 : dec).replace('.', ',');
  }
  function ico(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

  // Hex zo serveroveho pola [r,g,b] (katalogova farba NIE JE CSS retazec).
  // Cokolvek ine = prazdny retazec, teda ziadna vzorka — radsej nic nez
  // nahodna farba (a zaroven uzky whitelist toho, co ide do `style`).
  function rgbHex(rgb){
    if (!rgb || rgb.length !== 3) return '';
    var out = '#';
    for (var i = 0; i < 3; i++){
      var v = Number(rgb[i]);
      if (isNaN(v)) return '';
      v = Math.max(0, Math.min(255, Math.round(v)));
      out += (v < 16 ? '0' : '') + v.toString(16);
    }
    return out;
  }

  // Hladanie BEZ DIAKRITIKY (Š6) — „ľavý" sa nájde aj ako „lavy".
  function normText(s){
    return String(s == null ? '' : s).normalize('NFD').split('').filter(function(ch){
      var c = ch.charCodeAt(0);
      return c < 0x300 || c > 0x36f;
    }).join('').toLowerCase();
  }

  // --------------------------------------------------------- ciste funkcie
  // (testuje ich tests/js/test_st1a_studio.js — bez DOM)

  // Text riadku, v ktorom hlada Š6: nazvy dielca, skrinky (`kde`), rola.
  // Poznamka v riadku NEEXISTUJE (vedoma odchylka — v Ruby nema zdroj).
  function rowText(row){
    var r = row || {};
    var names = (r.names || []).join(' ');
    var kde = (r.kde || []).map(function(k){ return k.owner_id; }).join(' ');
    return names + ' ' + kde + ' ' + (r.role_label || '') + ' ' + (r.material_id || '');
  }

  function rowHit(row, q){
    if (!q) return true;
    return normText(rowText(row)).indexOf(normText(q)) >= 0;
  }

  // Š1: riadky do skupin podla materialu. PORADIE aj MEDZISUCET urcuje SERVER
  // (`sheets` = m² a ks per material) — JS nescitava nic. Material, ktory sa
  // v supise nenachadza (nemal by), sa pripoji na koniec bez medzisuctu.
  function groupBom(rows, sheets, q){
    var byId = {};
    var order = [];
    (sheets || []).forEach(function(s){
      byId[s.material_id] = { id: s.material_id, rows: [], m2: s.m2, ks: s.quantity };
      order.push(s.material_id);
    });
    var shown = 0;
    var total = 0;
    (rows || []).forEach(function(r){
      total++;
      var id = r.material_id;
      if (!byId[id]){ byId[id] = { id: id, rows: [], m2: null, ks: null }; order.push(id); }
      if (!rowHit(r, q)) return;
      byId[id].rows.push(r);
      shown++;
    });
    var groups = [];
    order.forEach(function(id){
      var g = byId[id];
      if (g && g.rows.length) groups.push(g);
    });
    return { groups: groups, shown: shown, total: total };
  }

  // Š2: viditelne stlpce (poradie je poradie definicie, nie klikania).
  function activeCols(cols){
    return (cols || COLS).filter(function(c){ return c.on; });
  }

  // Hodnota bunky. `th` sa berie z riadku (hrubku urcuje DIELEC, nie skupina).
  function cellValue(row, key){
    var r = row || {};
    if (key === 'name') return (r.names || []).join(' / ');
    if (key === 'cab') return (r.kde || []).map(function(k){ return k.owner_id; }).join(', ');
    if (key === 'l') return r.length;
    if (key === 'w') return r.width;
    if (key === 'th') return r.thickness;
    if (key === 'q') return r.quantity;
    if (key === 'grain') return grainLabel(r.grain_direction);
    if (key === 'role') return r.role_label || '';
    return '';
  }

  // Smer dekoru rečou stolára (server posiela kanonicky enum).
  function grainLabel(v){
    if (v === 'length') return 'pozdĺžna';
    if (v === 'width') return 'priečna';
    return 'bez smeru';
  }

  // ABS kompakt „L1:1 · W1:2" s tooltipom plneho znenia (UI_VIZIA riadok 15).
  //
  // Kody hran ostavaju KANONICKE (L1/L2/W1/W2) a ZAMERNE sa neprekladaju na
  // „predná/zadná/ľavá/pravá": ten isty kod znamena pri kazdej role INU fyzicku
  // hranu (docs/ARCHITEKTURA.md, `part_faces`), takze pevny preklad by pri
  // policiach a dnach ukazal nespravnu stranu. Fyzicku stranu pozna karta
  // dielca v Inspectore, ktora ju zaroven kresli.
  var EDGE_CODES = ['L1', 'L2', 'W1', 'W2'];

  // Hrubka pasky do kompaktneho zapisu: „1", „2", „0,8" (bez zbytocnej nuly).
  function edgeThShort(th){
    if (th == null || isNaN(th)) return '';
    var v = Number(th);
    return (Math.round(v * 10) % 10 === 0) ? String(Math.round(v)) : v.toFixed(1).replace('.', ',');
  }

  function absCompact(row, meta){
    var e = (row || {}).edges || {};
    var out = [];
    EDGE_CODES.forEach(function(code){
      var id = e[code];
      if (!id) return;
      var th = edgeThShort(((meta || {})[id] || {}).th);
      out.push(code + (th ? ':' + th : ''));
    });
    return out.length ? out.join(' · ') : '—';
  }

  function absFull(row, meta){
    var e = (row || {}).edges || {};
    var out = [];
    EDGE_CODES.forEach(function(code){
      var id = e[code];
      if (!id) return;
      var m = (meta || {})[id] || {};
      out.push(code + ' — ' + (m.label || id));
    });
    return out.length ? out.join(' · ') : 'bez ABS';
  }

  // Premostenia navigacie: ZRKADLO whitelistu v `StudioDialog`. Klikatelne je
  // vsetko okrem aktivnej sekcie a polozky s `disabled`.
  function navBridgeIds(){
    var out = [];
    NAV.forEach(function(g){
      g.items.forEach(function(it){ if (it.bridge) out.push(it.id); });
    });
    return out;
  }

  // Deep-link kotva (audit #12): N13 „Materiál" posiela ID skrinky a to sa
  // stane textom hladania. Spotrebuje sa PRAVE RAZ — server ju v dalsom pushi
  // uz neposle, takze pouzivatelovo vymazanie filtra prezije refresh.
  function anchorFilter(payload){
    var a = payload && payload.anchor;
    return (a == null) ? null : String(a).trim() || null;
  }

  // --------------------------------------------------- pamat tohto pocitaca
  function lsGet(key){
    try { return window.localStorage.getItem(key); } catch (e){ return null; }
  }
  function lsSet(key, value){
    try { window.localStorage.setItem(key, value); } catch (e){ /* privatny rezim */ }
  }

  function loadPrefs(){
    var cols = lsGet('nx_bom_cols');
    if (cols){
      try {
        var on = JSON.parse(cols);
        COLS.forEach(function(c){ if (!c.fixed && on[c.k] != null) c.on = !!on[c.k]; });
      } catch (e){ /* poskodena pamat = default */ }
    }
    var grp = lsGet('nx_bom_groups');
    if (grp){
      try { groupClosed = JSON.parse(grp) || {}; } catch (e){ groupClosed = {}; }
    }
    navMini = lsGet('nx_studio_nav') === 'mini';
  }

  function savePrefs(){
    var on = {};
    COLS.forEach(function(c){ on[c.k] = c.on; });
    lsSet('nx_bom_cols', JSON.stringify(on));
    lsSet('nx_bom_groups', JSON.stringify(groupClosed));
    lsSet('nx_studio_nav', navMini ? 'mini' : 'full');
  }

  // ------------------------------------------------------------ Ruby -> JS
  window.NX = {
    setStudio: function(data){
      ST = data || null;
      var mdl = el('stModel');
      if (mdl) mdl.textContent = ST ? ('zákazka: ' + ST.model_title + ' · v' + ST.version) : '…';
      // Deep-link sekcie sa posiela PRAVE RAZ; kotva s nou.
      if (ST && ST.open_section && STUDIO_SECTIONS.indexOf(ST.open_section) >= 0){
        studioSec = ST.open_section;
        var a = anchorFilter(ST);
        if (a) bomQ = a;
      }
      render();
    },
    setStatus: function(msg, err){
      var e = el('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    }
  };

  // --------------------------------------------------------------- render
  function render(){
    renderNav();
    renderHead();
    renderTools();
    renderBody();
  }

  function renderNav(){
    var box = el('snav');
    if (!box) return;
    var h = '';
    NAV.forEach(function(g){
      h += '<div class="sgrp">' + esc(g.grp) + '</div>';
      g.items.forEach(function(it){
        var on = (it.id === studioSec && !it.bridge && !it.disabled);
        var tip = it.disabled ? (it.t + ' — ' + it.disabled)
                              : (it.bridge ? (it.t + ' — ' + it.bridge) : it.t);
        h += '<button type="button" class="navitem' + (on ? ' on' : '') + '"' +
             (it.disabled ? ' aria-disabled="true"' : '') +
             ' data-nav="' + esc(it.id) + '" title="' + esc(tip) + '">' +
             ico(it.ic) + '<span>' + esc(it.t) + '</span>' +
             (it.bridge ? '<i class="nbridge" aria-hidden="true">↗</i>' : '') + '</button>';
      });
    });
    h += '<div class="navfoot"><button type="button" class="navitem" data-navmini' +
         ' title="Zbaliť navigáciu na ikony">' + ico('panel-left') +
         '<span>Zbaliť na ikony</span></button></div>';
    box.innerHTML = h;
    var studio = el('studio');
    if (studio) studio.className = 'studio' + (navMini ? ' navmini' : '');
  }

  function renderHead(){
    var box = el('sechead');
    if (!box) return;
    var m = SEC_META[studioSec] || { t: '—', hint: '' };
    box.innerHTML = '<h2>' + esc(m.t) + '</h2><span class="sechint">' + esc(m.hint) + '</span>' +
      '<span class="secmodel" id="stModel">' + (ST ? esc('zákazka: ' + ST.model_title + ' · v' + ST.version) : '…') + '</span>';
  }

  // Lista sekcie: primarna akcia vlavo, exporty vedla nej, hladanie a stlpce
  // vpravo (kontrakt §3 — ziadna globalna lista exportov).
  function renderTools(){
    var box = el('sectools');
    if (!box) return;
    if (!ST){ box.innerHTML = ''; return; }
    var vw = function(id, t, tip){
      return '<button type="button" class="bomvw' + (bomView === id ? ' on' : '') +
             '" data-view="' + id + '" title="' + esc(tip) + '">' + esc(t) + '</button>';
    };
    var v = ST.vepo || {};
    var h = '<div class="bomviews">' +
      vw('parts', 'Dielce', 'Výrobné dielce po materiáloch') +
      vw('sheets', 'Platne', 'Súpis platní — odvodený z kusovníka') +
      vw('abs', 'ABS', 'Súpis ABS pások — odvodený z kusovníka') + '</div>' +
      '<button type="button" class="primary" id="vepoBtn"' +
      ' title="Exportuje prírezy (po odpočte ABS) do VEPO CSV — vyberieš priečinok">' +
      ico('download') + ' VEPO export</button>' +
      // audit #18: exporty, ktore este neexistuju, su VIDITELNE a neaktivne
      // s dovodom (D-78) — nie skryte a nie mrtve.
      '<button type="button" class="ghostbtn" aria-disabled="true"' +
      ' title="Export kusovníka do XLSX zatiaľ neexistuje — príde v ďalšej dávke">' +
      ico('download') + ' XLSX</button>' +
      '<button type="button" class="ghostbtn" aria-disabled="true"' +
      ' title="Export kusovníka do CSV zatiaľ neexistuje — príde v ďalšej dávke">' +
      ico('download') + ' CSV</button>' +
      '<label class="prjbox" title="Názov projektu — priečinok a súbory exportu, titulok rozpočtu aj cenovej ponuky">' +
      '<span>Projekt</span><input id="prjInput" type="text" value="' + esc(v.project || '') +
      '" placeholder="' + esc(v.default_project || 'projekt') + '"></label>' +
      // audit #16: stav checkboxu sa berie z payloadu pri KAZDOM pushi.
      '<label class="mergebox" title="Materiály 18 a 36 mm do jedného súboru (bežná objednávka)">' +
      '<input type="checkbox" id="mergeChk"' + (v.merge_18_36 === false ? '' : ' checked') + '> 18+36 spolu</label>' +
      '<span class="spacer"></span>' +
      '<div class="searchbox">' + ico('search') +
      '<input id="bomSearch" placeholder="Hľadať dielec / skrinku…" value="' + esc(bomQ) + '"></div>';
    if (bomView === 'parts'){
      h += '<button type="button" class="ghostbtn" id="colBtn"' +
           ' title="Voliteľné stĺpce — voľba sa pamätá na tomto počítači" aria-expanded="' +
           (colMenuOpen ? 'true' : 'false') + '">' + ico('columns-3') + ' Stĺpce ' +
           ico('chevron-down') + '</button>' + colMenuHtml();
    }
    box.innerHTML = h;
  }

  function colMenuHtml(){
    if (!colMenuOpen) return '';
    var h = '<div class="colmenu" id="colMenu"><div class="mgrp">Stĺpce tabuľky</div>';
    COLS.forEach(function(c, i){
      h += '<label class="' + (c.fixed ? 'fixed' : '') + '"><input type="checkbox" data-col="' + i + '"' +
           (c.on ? ' checked' : '') + (c.fixed ? ' disabled' : '') + '> ' + esc(c.t) + '</label>';
    });
    h += '</div>';
    return h;
  }

  function renderBody(){
    var box = el('secbody');
    if (!box) return;
    if (!ST){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (bomView === 'sheets') box.innerHTML = sheetsTable();
    else if (bomView === 'abs') box.innerHTML = absTable();
    else box.innerHTML = partsTable();
  }

  // Š6: pri pisani sa prekresluje LEN telo — inak by input stratil fokus.
  function renderBomBody(){ renderBody(); }

  // ------------------------------------------------------- pohlad DIELCE
  function partsTable(){
    var meta = ST.materials_meta || {};
    var emeta = ST.edges_meta || {};
    var g = groupBom(ST.rows, ST.sheets, bomQ);
    var cols = activeCols(COLS);
    var h = '';
    if (!(ST.rows || []).length){
      return '<div class="muted">Žiadne výrobné dielce v modeli — vlož korpus alebo dosku.</div>';
    }
    g.groups.forEach(function(grp){
      var m = meta[grp.id] || {};
      var closed = !bomQ && !!groupClosed[grp.id];
      var hex = rgbHex(m.color);
      h += '<div class="grp' + (closed ? ' closed' : '') + '">' +
        '<button type="button" class="grphead" data-grp="' + esc(grp.id) + '" aria-expanded="' +
          (closed ? 'false' : 'true') + '">' +
          '<span class="chev"></span>' +
          (hex ? '<span class="sw" style="background:' + hex + '"></span>' : '<span class="sw"></span>') +
          '<span class="gname">' + esc(m.label || grp.id) + '</span>' +
          '<span class="gsub">' + (m.th == null ? '' : num(m.th) + ' mm') +
          (m.uni ? ' · <span class="wtagchip">UNI</span>' : '') + '</span>' +
          '<span class="gsum">' + num(grp.ks) + ' ks · <b>' + num(grp.m2, 2) + ' m²</b></span></button>' +
        '<table class="bomtab"><thead><tr>' +
          cols.map(function(c){ return '<th class="' + (c.num ? 'num' : '') + '">' + esc(c.t) + '</th>'; }).join('') +
          '<th class="acth"></th></tr></thead><tbody>';
      grp.rows.forEach(function(r){
        // Adresa riadku = jeho INDEX v serverovom poli `rows` (vzor okna
        // Vyroba). Klik potom posiela KLUC riadku, nie pids — Ruby si po flushi
        // editov najde cerstve refs (GH #48 P2).
        h += '<tr class="bomrow" data-i="' + (ST.rows || []).indexOf(r) + '">' +
          cols.map(function(c){
            if (c.k === 'abs'){
              return '<td class="absc" title="' + esc(absFull(r, emeta)) + '">' +
                     esc(absCompact(r, emeta)) + '</td>';
            }
            var v = cellValue(r, c.k);
            var txt = c.num ? num(v) : (String(v == null ? '' : v) || '—');
            return '<td class="' + (c.num ? 'num' : '') + '">' + esc(txt) + '</td>';
          }).join('') +
          '<td class="acth"><span class="rowact">' +
            '<button type="button" class="ract" data-act="eye" title="Označiť v modeli">' + ico('eye') + '</button>' +
            '<button type="button" class="ract" data-act="edit" title="Upraviť dielec v Inspectore">' + ico('pencil') + '</button>' +
          '</span></td></tr>';
      });
      h += '</tbody></table></div>';
    });
    if (!g.shown){
      h += '<div class="muted" style="padding:14px 4px">Filtru „' + esc(bomQ) +
           '" nezodpovedá žiadny dielec — skús kratší text (hľadá sa aj bez diakritiky).</div>';
    }
    h += totalRow(g);
    h += '<div class="hint">Klik na riadok označí dielec v modeli. Ceruzka ho navyše otvorí v Inspectore.</div>';
    return h;
  }

  // Sucty su SERVEROVE cisla (`totals`) — JS ich len vypise. Pri filtri sa
  // namiesto nich ukaze POCITADLO filtra (to je pocet riadkov, nie suma).
  function totalRow(g){
    var t = ST.totals || {};
    var left = bomQ
      ? 'Filter: <b>' + g.shown + ' z ' + g.total + ' riadkov</b>'
      : 'Spolu <b>' + num(t.parts) + ' dielcov</b> · <b>' + num(t.m2, 2) + ' m²</b> · ' +
        num(t.materials) + ' materiálov';
    return '<div class="totrow"><span>' + left + '</span><span class="spacer"></span>' +
      '<span class="tmuted">ABS spolu ' + num(t.bm, 1) + ' bm · odhad ' +
      num(t.plates_min, 1) + ' – ' + num(t.plates_max, 1) + ' platní</span></div>';
  }

  // ------------------------------------------------------- pohlad PLATNE
  function sheetsTable(){
    var meta = ST.materials_meta || {};
    var est = {};
    (ST.sheet_estimate || []).forEach(function(e){ est[e.material_id] = e; });
    var list = (ST.sheets || []).filter(function(s){
      if (!bomQ) return true;
      var m = meta[s.material_id] || {};
      return normText((m.label || '') + ' ' + s.material_id).indexOf(normText(bomQ)) >= 0;
    });
    var h = '<table class="bomtab flat"><thead><tr><th>Materiál</th><th class="num">Hrúbka</th>' +
      '<th>Formát platne</th><th class="num">Dielcov</th><th class="num">m² dielcov</th>' +
      '<th class="num">Odhad platní</th></tr></thead><tbody>';
    list.forEach(function(s){
      var m = meta[s.material_id] || {};
      var e = est[s.material_id];
      var hex = rgbHex(m.color);
      var fmt = e ? (num(e.sheet_size[0]) + ' × ' + num(e.sheet_size[1])) : '—';
      var pl = e ? (num(e.count_min, 1) + ' – ' + num(e.count_max, 1)) : '—';
      var fb = e && e.fallback;
      h += '<tr class="sheetrow" data-mid="' + esc(s.material_id) + '">' +
        '<td>' + (hex ? '<span class="cellsw" style="background:' + hex + '"></span>' : '') +
          esc(m.label || s.material_id) +
          (e && e.uni === true ? ' <span class="wtagchip">UNI</span>' : '') + '</td>' +
        '<td class="num">' + (m.th == null ? '—' : num(m.th) + ' mm') + '</td>' +
        '<td' + (fb ? ' class="estfb" title="Materiál nemá formát v katalógu — použitý 2800×2070"' : '') +
          '>' + esc(fmt) + '</td>' +
        '<td class="num">' + num(s.quantity) + '</td>' +
        '<td class="num">' + num(s.m2, 2) + '</td>' +
        '<td class="num"><b>' + esc(pl) + '</b></td></tr>';
    });
    h += '</tbody></table>';
    if (!list.length) h += '<div class="muted" style="padding:14px 4px">Filtru nezodpovedá žiadny materiál.</div>';
    var t = ST.totals || {};
    h += '<div class="totrow" style="margin-top:10px"><span>Spolu <b>odhad ' +
      num(t.plates_min, 1) + ' – ' + num(t.plates_max, 1) + ' platní</b> · ' + num(t.m2, 2) +
      ' m² dielcov</span><span class="spacer"></span>' +
      '<span class="tmuted">orientačný rozsah (prerez 10–25 %), NIE nárezový plán</span></div>';
    return h;
  }

  // ---------------------------------------------------------- pohlad ABS
  function absTable(){
    var meta = ST.edges_meta || {};
    var list = (ST.edging || []).filter(function(e){
      if (!bomQ) return true;
      var m = meta[e.abs_id] || {};
      return normText((m.label || '') + ' ' + (m.decor || '') + ' ' + e.abs_id).indexOf(normText(bomQ)) >= 0;
    });
    var h = '<table class="bomtab flat"><thead><tr><th>ABS páska</th><th>K dekoru</th>' +
      '<th class="num">Hrúbka</th><th class="num">Hrán</th><th class="num">bm</th>' +
      '</tr></thead><tbody>';
    list.forEach(function(e){
      var m = meta[e.abs_id] || {};
      var hex = rgbHex(m.color);
      h += '<tr class="absrow" data-aid="' + esc(e.abs_id) + '">' +
        '<td>' + (hex ? '<span class="cellsw" style="background:' + hex + '"></span>' : '') +
          esc(m.label || e.abs_id) + '</td>' +
        '<td>' + esc(m.decor || '—') + '</td>' +
        '<td class="num">' + (m.th == null ? '—' : num(m.th, 1) + ' mm') + '</td>' +
        '<td class="num">' + num(e.edges) + '</td>' +
        '<td class="num"><b>' + num(e.bm, 1) + '</b></td></tr>';
    });
    h += '</tbody></table>';
    if (!list.length) h += '<div class="muted" style="padding:14px 4px">Filtru nezodpovedá žiadna páska.</div>';
    var t = ST.totals || {};
    h += '<div class="totrow" style="margin-top:10px"><span>Spolu <b>' + num(t.bm, 1) +
      ' bm</b> · ' + num(t.edges) + ' pások</span><span class="spacer"></span>' +
      '<span class="tmuted">bm bez rezervy — nákupné bm sú v Rozpočte</span></div>';
    return h;
  }

  // ----------------------------------------------------------- akcie -> Ruby
  function selectRow(key, focusInspector){
    if (!ST || typeof window === 'undefined' || !window.sketchup || !sketchup.nx_select) return;
    sketchup.nx_select(JSON.stringify({ gen: ST.gen, parts_key: key,
                                        focus_inspector: !!focusInspector }));
  }

  function vepoExport(){
    if (!ST || !window.sketchup || !sketchup.vepo_export) return;
    NX.setStatus('Exportujem VEPO…', false);
    sketchup.vepo_export(JSON.stringify({ gen: ST.gen }));
  }

  // Nazov projektu aj merge zapisuje SERVER (audit #1) — okno posiela iba
  // hodnotu a svoju identitu; po zapise pride cerstvy payload OBOM oknam.
  function sendVepoOpts(attrs){
    if (!ST || !window.sketchup || !sketchup.studio_set_vepo_opts) return;
    var p = { gen: ST.gen, model_guid: ST.model_guid || '' };
    if (attrs.project !== undefined) p.project = attrs.project;
    if (attrs.merge !== undefined) p.merge = attrs.merge;
    sketchup.studio_set_vepo_opts(JSON.stringify(p));
  }

  function bridgeTo(id){
    if (!window.sketchup || !sketchup.studio_bridge) return;
    sketchup.studio_bridge(JSON.stringify({ section: id }));
  }

  function navItem(id){
    var found = null;
    NAV.forEach(function(g){
      g.items.forEach(function(it){ if (it.id === id) found = it; });
    });
    return found;
  }

  function onNav(id){
    var it = navItem(id);
    if (!it) return;
    if (it.disabled){ NX.setStatus(it.t + ' — ' + it.disabled, true); return; }
    if (it.bridge){ bridgeTo(id); return; }
    studioSec = id;
    render();
  }

  // ------------------------------------------------------------- listenery
  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(ev){
      var t = ev.target;
      if (!t || !t.closest) return;
      // Rozbalene okno stlpcov zatvara klik mimo neho (aj mimo jeho tlacidla).
      if (colMenuOpen && !t.closest('#colMenu') && !t.closest('#colBtn')){
        colMenuOpen = false;
        renderTools();
      }
      var nav = t.closest('[data-nav]');
      if (nav){ onNav(nav.getAttribute('data-nav')); return; }
      if (t.closest('[data-navmini]')){ navMini = !navMini; savePrefs(); renderNav(); return; }
      if (t.closest('#colBtn')){ colMenuOpen = !colMenuOpen; renderTools(); return; }
      if (t.closest('#vepoBtn')){ vepoExport(); return; }
      var vbtn = t.closest('[data-view]');
      if (vbtn){ bomView = vbtn.getAttribute('data-view'); colMenuOpen = false; renderTools(); renderBody(); return; }
      var grp = t.closest('[data-grp]');
      if (grp){
        var gid = grp.getAttribute('data-grp');
        groupClosed[gid] = !groupClosed[gid];
        savePrefs();
        renderBody();
        return;
      }
      // Š3: ceruzka = vyber + Inspector dopredu; oko aj klik na riadok = vyber.
      var act = t.closest('button.ract');
      var row = t.closest('tr.bomrow');
      if (row){
        var i = parseInt(row.getAttribute('data-i'), 10);
        var r = (ST && ST.rows) ? ST.rows[i] : null;
        if (!r || !r.key) return;
        selectRow(r.key, !!(act && act.getAttribute('data-act') === 'edit'));
      }
    });

    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t) return;
      if (t.hasAttribute && t.hasAttribute('data-col')){
        var i = parseInt(t.getAttribute('data-col'), 10);
        if (!isNaN(i) && COLS[i] && !COLS[i].fixed){
          COLS[i].on = !!t.checked;
          savePrefs();
          renderBody();
        }
        return;
      }
      if (t.id === 'mergeChk'){ sendVepoOpts({ merge: !!t.checked }); return; }
      if (t.id === 'prjInput'){ sendVepoOpts({ project: t.value }); }
    });

    document.addEventListener('input', function(ev){
      if (ev.target && ev.target.id === 'bomSearch'){
        bomQ = ev.target.value;
        renderBomBody();
      }
    });

    document.addEventListener('keydown', function(ev){
      if (ev.key === 'Enter' && ev.target && ev.target.id === 'prjInput') ev.target.blur();
    });
  }

  if (typeof window !== 'undefined'){
    window.onload = function(){
      loadPrefs();
      if (window.sketchup && sketchup.ready) sketchup.ready('');
    };
  }

  // Node testy (tests/js/test_st1a_studio.js) — LEN ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = {
      STUDIO_SECTIONS: STUDIO_SECTIONS, COLS: COLS, NAV: NAV,
      normText: normText, rowText: rowText, rowHit: rowHit, groupBom: groupBom,
      activeCols: activeCols, cellValue: cellValue, grainLabel: grainLabel,
      absCompact: absCompact, absFull: absFull, rgbHex: rgbHex,
      navBridgeIds: navBridgeIds, anchorFilter: anchorFilter, navItem: navItem
    };
  }
