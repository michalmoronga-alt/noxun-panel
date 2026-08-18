  // ===================== 2D NAHLAD (SVG) =====================
  var PV_PAD = 14; // padding viewBoxu nahladu (mm) — zdielaju ho renderPreview aj prevod px->mm v dragu
  // UI-01: kreslenie do SVG nevie citat CSS premenne cez var() v atributoch,
  // preto su farby vyberovej rodiny ZRKADLOM tokenov --nx-* z panel.css
  // (rovnaky vzor ako EdgeCheck::COLORS). Zmena tokenu = zmena aj tu.
  // POZN: nahlad zamerne NEREAGUJE na temu (UI-01 O4) — tema prepina LEN CSS
  // tokeny panela; kreslene farby ostavaju firemne teal.
  var PV_SELECT = '#107787';        // --nx-select (aktivna zona)
  var PV_SELECT_ACCENT = '#0e6b7a'; // --nx-select-accent (popis cela)
  var PV_FRONT_DOOR = '#e0f2f4';    // --nx-select-bg (vypln dvierok)
  var PV_FRONT_DRAWER = '#bfe3e8';  // tmavsi odtien rodiny (vypln zasuvky)
  var PV_FRONT_STROKE = '#7fc4cf';  // --nx-part-border (obrys cela)
  // UI-B2: koty su decentne — tenka ciara + tlmeny text. Zrkadlo tokenu
  // --nx-ink-faint (SVG atributy nevedia var(), rovnaky vzor ako farby vyssie).
  var PV_DIM = '#90a4ae';           // --nx-ink-faint (ciary a texty kot)
  var PV_GHOST = '#b0bec5';         // --nx-border-strong (tlmena ghost vrstva)
  var dragState = null;
  // ===== D-08 / UI-B1: kontext prepina nahlad AJ viditelne skupiny (CSS cez
  // data-view-ctx na <body>). Rezimove taby v hlavicke nahradil RAIL — stavovy
  // stroj a prepinanie ziju v js/shell.js (NXShell + setViewContext), tu ostava
  // uz len prevod kontextu na rezim nahladu. UI-B2: Kovanie ma UZ VLASTNU
  // projekciu ('hw' — pozicie kovania), nekresli korpusovy pohlad.
  // refreshZoneUI ma mode guard (D-03 Codex F2 — karta zony sa mimo kontextu
  // Zony skryva a pri navrate obnovi vratane auto-selectu).
  function cabTabPreview(t){
    if (t === 'zony') return 'zones';
    if (t === 'cela') return 'fronts';
    if (t === 'kovanie') return 'hw';
    return 'cab';
  }

  // --- POHLAD (V0.4.5 D1): nahlad je fixne OKNO — SVG ma pevnu vysku (CSS) a viewBox
  // je posuvatelne/zoomovatelne okno nad scenou v mm. Kym pouzivatel nezoomuje/nepanuje
  // (pvUserView=false), pohlad automaticky sleduje celu skrinku (fit). Po manualnom
  // zasahu pohlad DRZI (Michalov "lock") — reset tlacidlom ⛶ alebo pri zmene skrinky.
  var pvView = null;        // {x,y,w,h} v mm sceny
  var pvUserView = false;   // true = pouzivatel si pohlad nastavil sam
  // D-07: rozsah ciel v modelovych mm (presahy mozu ist mimo obrys korpusu).
  function frontsExtent(){
    var items = frontItems; if (!items || !items.length) return null;
    var W = numv('width')||600, H = numv('height')||720;
    var gs = 2; var gsv = numv('fr_gap_sides'); if (!isNaN(gsv)) gs = gsv;
    var e = { minX: Math.min(0, gs), maxX: Math.max(W, W - gs), minZ: 0, maxZ: H };
    items.forEach(function(it){
      e.minZ = Math.min(e.minZ, it.z);
      e.maxZ = Math.max(e.maxZ, it.z + it.height);
    });
    return e;
  }
  // Scena = korpus ∪ cela (fit ukaze aj presahy — Codex F3). Bez presahov je
  // vysledok identicky s povodnym {0,0,W+2p,H+2p}, drag prepocty sa nemenia.
  // D-08: v rezime 'cab' scenu rozsiruje rezerva na koty (dole a vpravo, Codex F5).
  // UI-B2: kazda projekcia si berie prave tolko miesta, kolko jej koty
  // potrebuju — inak by kota skoncila mimo okna a pouzivatel by ju nenasiel.
  var DIM_EXT = 70; // mm sceny pre kotovacie ciary a texty
  // Rezerva NAD kotou hlbky: odsadenie ciary (14) + znacka (7) + text (9) + vzduch.
  var DIM_TOP = 34;
  // Odsadenie kotovacej ciary hlbky od skosenej hornej plochy (zdielane so
  // scenou — inak by sa rezerva a kresba rozisli).
  var DIM_DEPTH_OFF = 14;
  // Naznak hlbky v korpusovej projekcii (skosena horna plocha, vzor mockupu).
  // Nie je to mierka hlbky — je to citatelny NAZNAK; presnu hodnotu nesie kota.
  function pvDepthSkew(){
    var D = numv('depth') || 0;
    return D > 0 ? Math.min(Math.max(D * 0.18, 24), 130) : 0;
  }
  // Kde LEZI kota hlbky a kam az musi siahat scena, aby ju fit neorezal.
  // Obe hodnoty su TU, aby sa rezerva a kresba nemohli rozist (Codex #169 P2).
  // Ciste (Node testy).
  function pvDepthDimZ(H, sk){ return H + sk + DIM_DEPTH_OFF; }
  function pvSceneTopZ(H, sk){ return sk > 0 ? (H + sk + DIM_TOP) : H; }
  function sceneSize(){
    var W = numv('width')||600, H = numv('height')||720;
    var solid = (previewMode === 'cab' || previewMode === 'hw');
    var e = solid ? null : frontsExtent();
    var minX = e ? e.minX : 0, maxX = e ? e.maxX : W;
    var minZ = e ? e.minZ : 0, maxZ = e ? e.maxZ : H;
    if (previewMode === 'cab'){
      // D-11: vlavo koty sokla/tela, vpravo vyska, dole sirka, hore naznak hlbky
      var sk = pvDepthSkew();
      minX = -DIM_EXT; maxX = W + DIM_EXT + sk; minZ = -DIM_EXT;
      // Codex #169 P2: nad skosenim este LEZI KOTA hlbky — scene musi patrit aj
      // jej ciara, znacky a text, inak ju fit orezal.
      maxZ = pvSceneTopZ(H, sk);
    } else if (previewMode === 'fronts'){
      maxX = Math.max(maxX, W) + DIM_EXT; // koty vysok riadkov vpravo
      minX = Math.min(minX, 0) - 34;      // cisla medzier pri lavom okraji
      minZ = Math.min(minZ, 0) - 46;      // kota celkovej sirky dole
    } else if (previewMode === 'zones'){
      minZ = Math.min(minZ, 0) - 46;      // koty sirok zon pod korpusom
    } else if (previewMode === 'hw'){
      minZ = Math.min(minZ, 0) - 96;      // nohy pod korpusom + suhrn kovania
    }
    return { x: minX, y: H - maxZ,
             w: (maxX - minX) + 2*PV_PAD, h: (maxZ - minZ) + 2*PV_PAD };
  }
  function fitPreview(){ pvUserView = false; pvView = null; renderPreview(); }
  function applyViewBox(svg){
    var base = sceneSize();
    if (!pvUserView || !pvView) pvView = { x: base.x, y: base.y, w: base.w, h: base.h };
    svg.setAttribute('viewBox', pvView.x + ' ' + pvView.y + ' ' + pvView.w + ' ' + pvView.h);
  }
  // Mapovanie px<->mm pri preserveAspectRatio meet (letterbox offsety).
  function viewMapping(rect){
    var s = Math.min(rect.width / pvView.w, rect.height / pvView.h);
    return { s: s, ox: (rect.width - pvView.w * s) / 2, oy: (rect.height - pvView.h * s) / 2 };
  }
  function clientToScene(ev, rect){
    var m = viewMapping(rect);
    return { x: pvView.x + (ev.clientX - rect.left - m.ox) / m.s,
             y: pvView.y + (ev.clientY - rect.top - m.oy) / m.s };
  }

  // ===================== UI-B2: VRSTVY NAHLADU (chipy spodneho pasu) ========
  // Nahlad je KONTEXTOVA PROJEKCIA: kazdy kontext railu kresli svoj vlastny
  // pohlad (vymena, nie vrstvenie). Chipy v spodnom pase vedia dalsie vrstvy
  // len PRISVIETIT ako tlmeny ghost — zakladny pohlad kontextu sa nikdy nemeni
  // a ghost do neho nikdy nezasahuje (ziadne kliky, ziadne vyplne).
  //
  // Ciste jadro (Node testy: tests/js/test_uib2_nahlad.js) — ziadny DOM.
  var NXLayers = (function(){
    'use strict';
    var KEYS = ['zony', 'cela', 'kovanie', 'olep'];
    var LABEL = { zony: 'Zóny', cela: 'Čelá', kovanie: 'Kovanie', olep: 'Olep' };
    // Ktora vrstva je ZAKLADOM ktorej projekcie. Zakladny chip sa neda zhasnut
    // (je to sam pohlad), preto nema stav zap/vyp.
    var BASE = { cab: null, zones: 'zony', fronts: 'cela', hw: 'kovanie', part: 'olep' };
    // Olep = farby ABS hran. Tie nesie VYHRADNE payload dielca (part_card);
    // korpusovy payload o hranach jednotlivych dielcov nic nevie, takze chip je
    // mimo kontextu Dielec zamerne NEAKTIVNY s vysvetlenim — nie ticho mrtvy.
    // V kontexte Dielec zas nema zmysel prisvecovat vrstvy skrinky (kresli sa
    // dielec, nie korpus).
    function ghostable(mode, key){
      if (key === 'olep') return false;
      return mode !== 'part';
    }
    var state = {};   // rezim projekcie -> { kluc: true }
    function bag(mode){ return (state[mode] = state[mode] || {}); }
    function baseOf(mode){ return BASE[mode] || null; }
    function has(avail, key){ return !avail || avail[key] !== false; }
    // Stav jedneho chipu: 'base' | 'on' | 'off' | 'disabled'.
    function stateOf(mode, key, avail){
      if (baseOf(mode) === key) return 'base';
      if (!ghostable(mode, key) || !has(avail, key)) return 'disabled';
      return bag(mode)[key] === true ? 'on' : 'off';
    }
    function titleOf(mode, key, st, avail){
      if (st === 'base') return 'Základný pohľad tohto kontextu';
      if (st === 'on') return 'Zhasnúť vrstvu ' + LABEL[key];
      if (st === 'off') return 'Prisvietiť ' + LABEL[key] + ' ako tlmenú vrstvu';
      if (key === 'olep'){
        return mode === 'part'
          ? 'Hrany tohto dielca s ABS farbami'
          : 'Farby ABS hrán vie náhľad ukázať len pri označenom dielci — korpusový pohľad hranové dáta nemá';
      }
      if (mode === 'part') return 'V náhľade dielca sa vrstvy skrinky neprisvecujú';
      // POZOR: popis sa sklada aj do aria-label ako „<vrstva> — <popis>", takze
      // sam nesmie zacinat menom vrstvy (inak ho citacka precita dvakrat).
      if (!has(avail, key)) return 'Zatiaľ niet čo prisvietiť';
      return 'Vrstva náhľadu';
    }
    // Zoznam chipov pre pas (poradie je fixne — vzor mockupu).
    // avail = { zony, cela, kovanie, olep } (false = niet dat)
    function chips(mode, avail){
      return KEYS.map(function(k){
        var st = stateOf(mode, k, avail);
        return { key: k, label: LABEL[k], state: st, title: titleOf(mode, k, st, avail) };
      });
    }
    // Vrstvy, ktore sa maju dokreslit ako ghost (bez zakladnej vrstvy kontextu).
    function ghosts(mode, avail){
      return KEYS.filter(function(k){ return stateOf(mode, k, avail) === 'on'; });
    }
    // Klik na chip. Vracia true = stav sa zmenil (treba prekreslit).
    function toggle(mode, key, avail){
      if (stateOf(mode, key, avail) === 'base') return false;
      if (stateOf(mode, key, avail) === 'disabled') return false;
      var b = bag(mode);
      b[key] = !b[key];
      return true;
    }
    // NOVA identita vyberu = cisty stol (rovnaka zasada ako viewContext v A1);
    // ECHO push tej istej identity stav chipov NEMENI.
    function reset(){ state = {}; }
    return { KEYS: KEYS, LABEL: LABEL, baseOf: baseOf, stateOf: stateOf,
             chips: chips, ghosts: ghosts, toggle: toggle, reset: reset };
  })();

  // ===================== UI-B2: geometria projekcie ==========================
  // JEDEN zdroj hodnot pre vsetky vrstvy (zakladne aj ghost) — ziadna vrstva si
  // necita formular sama, inak by sa dve kresby rozisli.
  function pvGeom(){
    var gs = 2; var gsv = numv('fr_gap_sides'); if (!isNaN(gsv)) gs = gsv;
    var gap = 3; var gv = numv('fr_gap'); if (!isNaN(gv)) gap = gv;
    return { W: numv('width')||600, H: numv('height')||720, t: numv('thickness')||18,
             D: numv('depth')||0,
             fh: (getType()==='upper') ? 0 : (numv('floor_height')||0),
             topNone: val('top_mode') === 'none',
             gapSides: gs, gap: gap,
             fronts: frontItems || [] };
  }

  // Kontexty chipov: chip patri tomu, CO POUZIVATEL VIDI. Pri oznacenom dielci
  // je zakladom Olep (hrany kresli #partSvg), aj ked nad nim ostava zonovy
  // nahlad skrinky (D-08 — dielec vynuti zonovy pohlad).
  function pvChipMode(){
    if (typeof NXShell !== 'undefined' && NXShell && NXShell.mode() === 'part') return 'part';
    return previewMode;
  }
  // Ktore vrstvy maju vobec z coho kreslit (poctivo — chip bez dat je neaktivny).
  function pvAvail(){
    return { zony: !!currentZoneTree,
             cela: !!(frontItems && frontItems.length),
             kovanie: !!(hwItems && hwItems.length),
             olep: !!partCard };
  }

  // ---- decentne koty (vzor mockupu dimH/dimV — tenka ciara, tlmeny text) ----
  function pvDimH(S, rx, ry, x1, x2, z, label, size){
    var f = size || 20;
    S.push('<g stroke="'+PV_DIM+'" stroke-width="1.4" fill="none" pointer-events="none">' +
      '<path d="M'+rx(x1)+' '+(ry(z)-7)+'V'+(ry(z)+7)+'M'+rx(x2)+' '+(ry(z)-7)+'V'+(ry(z)+7)+'"/>' +
      '<path d="M'+rx(x1)+' '+ry(z)+'H'+rx(x2)+'"/></g>' +
      '<text x="'+rx((x1+x2)/2)+'" y="'+(ry(z)-9)+'" font-size="'+f+'" fill="'+PV_DIM+
      '" text-anchor="middle" pointer-events="none">'+esc(label)+'</text>');
  }
  function pvDimV(S, rx, ry, x, z1, z2, label, size){
    var f = size || 20, ym = ry((z1+z2)/2);
    S.push('<g stroke="'+PV_DIM+'" stroke-width="1.4" fill="none" pointer-events="none">' +
      '<path d="M'+(rx(x)-7)+' '+ry(z1)+'H'+(rx(x)+7)+'M'+(rx(x)-7)+' '+ry(z2)+'H'+(rx(x)+7)+'"/>' +
      '<path d="M'+rx(x)+' '+ry(z1)+'V'+ry(z2)+'"/></g>' +
      '<text x="'+(rx(x)+10)+'" y="'+ym+'" font-size="'+f+'" fill="'+PV_DIM+
      '" text-anchor="middle" dominant-baseline="middle" pointer-events="none" transform="rotate(-90 '+
      (rx(x)+10)+' '+ym+')">'+esc(label)+'</text>');
  }
  function pvText(S, x, y, txt, size, anchor){
    S.push('<text x="'+x+'" y="'+y+'" font-size="'+(size||18)+'" fill="'+PV_DIM+
      '" text-anchor="'+(anchor||'middle')+'" pointer-events="none">'+esc(txt)+'</text>');
  }

  // ---- spolocny podklad: obrys korpusu + schematicke dielce ----------------
  function drawCarcass(S, rx, ry, g, skew){
    var W = g.W, H = g.H, t = g.t, fh = g.fh;
    if (skew > 0){
      // naznak hlbky — skosena horna plocha (kresli sa POD korpus, aby ho neprekryla)
      S.push('<polygon points="'+rx(0)+','+ry(H)+' '+rx(W)+','+ry(H)+' '+rx(W+skew)+','+ry(H+skew)+
             ' '+rx(skew)+','+ry(H+skew)+'" fill="#f4f5f7" stroke="#cfd8dc"/>');
    }
    S.push('<rect x="'+rx(0)+'" y="'+ry(H)+'" width="'+W+'" height="'+H+'" fill="#ffffff" stroke="#90a4ae" stroke-width="2"/>');
    var partFill='#e5d8b8', partStroke='#c9b784';
    S.push('<rect x="'+rx(0)+'" y="'+ry(H)+'" width="'+t+'" height="'+H+'" fill="'+partFill+'" stroke="'+partStroke+'"/>');       // bok L
    S.push('<rect x="'+rx(W-t)+'" y="'+ry(H)+'" width="'+t+'" height="'+H+'" fill="'+partFill+'" stroke="'+partStroke+'"/>');     // bok R
    S.push('<rect x="'+rx(0)+'" y="'+ry(fh+t)+'" width="'+W+'" height="'+t+'" fill="'+partFill+'" stroke="'+partStroke+'"/>');    // dno
    // D-80: vrch podla rezimu. Plny vrch = doska tesne pod hornou hranou;
    // two_rails = pas vystuh na SKUTOCNOM mieste (odsadenie od vrchu + orientacia:
    // flat je hruby t, upright az po celej vyske vystuhy); none = nic.
    // Geometriu dava zdielana core.js funkcia — nahlad nesmie mat vlastny vzorec.
    if (val('top_mode') === 'two_rails'){
      var rg = nxRailGeom(currentCarcass({ height: H, thickness: t }));
      S.push('<rect x="'+rx(t)+'" y="'+ry(rg.zTop)+'" width="'+(W-2*t)+'" height="'+(rg.zTop-rg.zBottom)+'" fill="'+partFill+'" stroke="'+partStroke+'"/>'); // vystuhy
    } else if (!g.topNone){
      S.push('<rect x="'+rx(t)+'" y="'+ry(H)+'" width="'+(W-2*t)+'" height="'+t+'" fill="'+partFill+'" stroke="'+partStroke+'"/>'); // vrch
    }
    if (fh>0) S.push('<rect x="'+rx(0)+'" y="'+ry(fh)+'" width="'+W+'" height="'+fh+'" fill="#f4f5f7" stroke="#cfd8dc" stroke-dasharray="4 3"/>'); // podstavec
  }

  function renderPreview(){
    var svg = el('preview'); if (!svg) return;
    clearFrontHover(); // D-23: rerender/tab/vyber rusi hover uzly — stav ide s nimi
    var g = pvGeom(), W = g.W, H = g.H;
    if (!(W>0 && H>0)){ svg.innerHTML=''; renderPvBar(); return; }
    var pad = PV_PAD;
    applyViewBox(svg);
    var S = [];
    // helper: model (x,z) -> svg (flip Z). y = pad + (H - z)
    function rx(x){ return pad + x; }
    function ry(z){ return pad + (H - z); }
    drawCarcass(S, rx, ry, g, previewMode === 'cab' ? pvDepthSkew() : 0);

    if (previewMode==='zones'){
      drawZonesBase(S, rx, ry, g);
    } else if (previewMode === 'fronts'){
      // cela pohlad + koty vysok a medzier
      renderFrontsPreview(S, rx, ry, g);
      drawFrontDims(S, rx, ry, g);
    } else if (previewMode === 'hw'){
      // UI-B2: kontext Kovanie ma vlastnu projekciu — pozicie kovania
      drawHwBase(S, rx, ry, g);
    } else {
      // D-08: kontext Korpus — kotovany celny rez (Š/V/sokel + naznak hlbky)
      renderCabOutline(S, rx, ry, W, H, g.fh);
    }
    drawGhostLayers(S, rx, ry, g);
    svg.innerHTML = S.join('');
    renderPvBar();
    // POZN: ziadne per-element bindovanie tu — pouzivame event delegaciu (setupPreviewDelegation),
    // takze nove <rect> po kazdom re-renderi reaguju bez opätovného naväzovania listenerov.
  }

  // ---- ZAKLADNA vrstva: zony (klikatelne, s tahatelnymi prieckami) ---------
  function drawZonesBase(S, rx, ry, g){
    var zones = computeZones();
    var leafIdx = 0;
    zones.forEach(function(z){
      if (z.leaf){
        var col = PALETTE[leafIdx % PALETTE.length]; leafIdx++;
        var active = (fullZoneId(z.id) === activeZoneId);
        S.push('<rect class="zrect" data-zid="'+z.id+'" x="'+rx(z.x)+'" y="'+ry(z.z+z.h)+'" width="'+z.w+'" height="'+z.h+'" fill="'+col+'" fill-opacity="'+(active?0.55:0.32)+'" stroke="'+(active?PV_SELECT:col)+'" stroke-width="'+(active?4:1.5)+'" style="cursor:pointer"/>');
        // police (tenke ciary)
        if (z.shelves>0){ for (var s=1;s<=z.shelves;s++){ var zs = z.z + z.h*s/(z.shelves+1); S.push('<line x1="'+rx(z.x)+'" y1="'+ry(zs)+'" x2="'+rx(z.x+z.w)+'" y2="'+ry(zs)+'" stroke="#8d6e63" stroke-width="2"/>'); } }
        // rozmer text
        if (z.w>60 && z.h>30) S.push('<text x="'+rx(z.x+z.w/2)+'" y="'+ry(z.z+z.h/2)+'" font-size="'+Math.min(22,z.w/5)+'" fill="#37474f" text-anchor="middle" dominant-baseline="middle" pointer-events="none">'+Math.round(z.w)+'×'+Math.round(z.h)+'</text>');
      } else if (z.split){
        // priecky (hrube ciary), tahatelne
        drawDividers(z, S, rx, ry, g.t, g.fh, g.topNone, g.H);
      }
    });
    // UI-B2: koty sirok zon pod korpusom — len ked je co porovnavat
    var spans = nxZoneSpans(zones);
    if (spans.length > 1 && spans.length <= 8){
      spans.forEach(function(sp){ pvDimH(S, rx, ry, sp.x, sp.x + sp.w, -26, String(Math.round(sp.w)), 18); });
    }
  }

  // Stlpce listovych zon (dedup podla x/sirky) — podklad kot sirok.
  // Ciste (Node testy).
  function nxZoneSpans(zones){
    var out = [], seen = {};
    (zones || []).forEach(function(z){
      if (!z || !z.leaf) return;
      var k = Math.round(z.x) + ':' + Math.round(z.w);
      if (seen[k]) return;
      seen[k] = true;
      out.push({ x: z.x, w: z.w });
    });
    out.sort(function(a, b){ return a.x - b.x; });
    return out;
  }

  function drawDividers(z, S, rx, ry, t, fh, topNone, H){
    var axis = z.split.axis, sizes = z.split.sizes;
    if (axis==='v'){
      var x = z.x;
      for (var c=0;c<z.split.count-1;c++){ x += sizes[c]; S.push('<rect class="divh" data-zid="'+z.id+'" data-idx="'+c+'" data-axis="v" x="'+rx(x)+'" y="'+ry(z.z+z.h)+'" width="'+t+'" height="'+z.h+'" fill="#8d6e63" stroke="#5d4037" style="cursor:ew-resize"/>'); x += t; }
    } else {
      var zz = z.z;
      for (var r=0;r<z.split.count-1;r++){ zz += sizes[r]; S.push('<rect class="divh" data-zid="'+z.id+'" data-idx="'+r+'" data-axis="h" x="'+rx(z.x)+'" y="'+ry(zz+t)+'" width="'+z.w+'" height="'+t+'" fill="#8d6e63" stroke="#5d4037" style="cursor:ns-resize"/>'); zz += t; }
    }
  }

  // D-23: kazdy item je obaleny do <g class="fgrp" data-front-id> — VSETKY kridla,
  // none ciarkovany pas AJ text su jeden interakcny ciel (klik/hover na hocaku
  // cast = ten isty item; pri viacerych kridlach sa zvyraznuju vsetky naraz).
  // F-cislo (kanonicka pozicia v datach, F1 dole) sa kresli raz per item.
  // UI-B2: geometriu berie z pvGeom (jeden zdroj pre vsetky vrstvy) — okraje
  // a medzera sa uz necitaju z formulara druhykrat.
  function renderFrontsPreview(S, rx, ry, g){
    var W = g.W, H = g.H, items = g.fronts;
    if (!items || !items.length){
      // odhad z formulara (bez presnych vysok) — len info
      S.push('<text x="'+rx(W/2)+'" y="'+ry(H/2)+'" font-size="20" fill="#90a4ae" text-anchor="middle">Čelá: nastav v sekcii Čelá</text>');
      return;
    }
    // D-07: okraje/medzera z poli (0 je platna hodnota — NIE || default);
    // zaporny bocny okraj = cela sirsie nez korpus (presah).
    var gs = g.gapSides, gap = g.gap;
    var ow = W - 2*gs;
    items.forEach(function(it, i){
      var z = it.z, h = it.height, col = (it.type==='drawer_front')?PV_FRONT_DRAWER:PV_FRONT_DOOR;
      var fnum = 'F' + (i + 1);
      S.push('<g class="fgrp" data-front-id="'+esc(it.id || '')+'">');
      if (it.type === 'none'){
        // D-18: pásmo Bez čela = čiarkovaný obrys bez výplne (otvorená nika v rade).
        // D-23: aj none pás je súčasťou skupiny — klik vedie na jeho riadok v zozname.
        S.push('<rect x="'+rx(gs)+'" y="'+ry(z+h)+'" width="'+ow+'" height="'+h+'" fill="none" stroke="#90a4ae" stroke-width="1.5" stroke-dasharray="7 5"/>');
        S.push('<text x="'+rx(W/2)+'" y="'+ry(z+h/2)+'" font-size="18" fill="#90a4ae" text-anchor="middle" dominant-baseline="middle">'+fnum+' · bez čela '+Math.round(h)+'</text>');
        S.push('</g>');
        return;
      }
      // Codex GH P2: legacy cache front_items (pred D-07) nema wings_n —
      // fallback zrkadli Ruby resolve_wings (explicitne '1'..'4' — D-24, auto nad 600).
      var wn = it.wings_n;
      if (wn == null){
        var wex = parseInt(it.wings, 10);
        wn = (wex >= 1 && wex <= 4) ? wex : (ow > 600 ? 2 : 1);
      }
      // Stlpce = kridla (D-24: 2/3/4 s medzerou gap medzi nimi), 1 kridlo = cely otvor.
      var cols = [];
      if (it.type === 'door' && wn > 1){
        var dw = (ow - (wn - 1) * gap) / wn;
        for (var w = 0; w < wn; w++) cols.push({ x: gs + w*(dw+gap), w: dw });
      } else {
        cols.push({ x: gs, w: ow });
      }
      // D-90: uchytkovy profil zaberá hornych `red` mm RIADKU — panel je o tolko
      // nizsi a nad nim sa kresli plny pruh profilu (kazde kridlo ma vlastny kus).
      // Skratenie ide z Ruby registry (FRONT_PROFILES), nie z konstanty v JS.
      var red = Math.min(frontProfileReduction(it.profile), h);
      var ph = h - red;
      cols.forEach(function(c){
        if (ph > 0){
          S.push('<rect x="'+rx(c.x)+'" y="'+ry(z+ph)+'" width="'+c.w+'" height="'+ph+'" fill="'+col+'" stroke="'+PV_FRONT_STROKE+'" stroke-width="1.5"/>');
        }
        if (red > 0){
          S.push('<rect class="fprofband" x="'+rx(c.x)+'" y="'+ry(z+h)+'" width="'+c.w+'" height="'+red+'"/>');
        }
      });
      // popis do stredu PANELU (pri profile nesmie skoncit v jeho pruhu);
      // cislo ostava vyskou RIADKU — presne to, co je v zozname ciel.
      S.push('<text x="'+rx(W/2)+'" y="'+ry(z+(ph > 0 ? ph : h)/2)+'" font-size="18" fill="'+PV_SELECT_ACCENT+'" text-anchor="middle" dominant-baseline="middle">'+fnum+' · '+(it.type==='drawer_front'?'zásuvka':'dvierka')+' '+Math.round(h)+'</text>');
      S.push('</g>');
    });
  }

  // D-08 / UI-B2: kontext Korpus = celny rez s kotami. Sirka dole, vyska vpravo,
  // sokel a telo vlavo, hlbka kotou na naznaku skosenia (nie textom v strede).
  // Obrys, dielce aj skosenie kresli spolocna drawCarcass; VSETKY hodnoty su
  // z payloadu/formulara — ziadne konstanty.
  function renderCabOutline(S, rx, ry, W, H, fh){
    var D = numv('depth') || 0, sk = pvDepthSkew();
    pvDimH(S, rx, ry, 0, W, -26, 'Š ' + Math.round(W) + ' mm', 22);
    pvDimV(S, rx, ry, W + 26, 0, H, 'V ' + Math.round(H), 22);
    // D-11: vlavo koty sokla (0..fh) a tela (fh..H) — len ked sokel existuje
    if (fh > 0){
      pvDimV(S, rx, ry, -26, 0, fh, 'sokel ' + Math.round(fh), 18);
      pvDimV(S, rx, ry, -26, fh, H, 'telo ' + Math.round(H - fh), 18);
    }
    // hlbka: kota na skosenej hornej ploche (naznak) — inak aspon text
    if (D > 0){
      if (sk > 0) pvDimH(S, rx, ry, W, W + sk, pvDepthDimZ(H, sk), 'H ' + Math.round(D), 18);
      else pvText(S, rx(W/2), ry(H/2), 'hĺbka ' + Math.round(D) + ' mm', 20);
    }
  }

  // ---- ZAKLADNA vrstva: koty ciel (vysky riadkov + medzery) ---------------
  // Vysky su RESOLVED z payloadu (front_items), medzery su rozdiely medzi nimi
  // — ziadny vlastny vzorec, ziadne nove pole. Jantarove zvyraznenie medzier
  // pri otvorenej skupine Medzery (N26) pride s davkou UI-C3.
  function drawFrontDims(S, rx, ry, g){
    var dims = nxFrontDims(g.fronts, g);
    if (!dims.length) return;
    var xr = Math.max(g.W, g.W - g.gapSides) + 26;
    dims.forEach(function(d){
      if (d.kind === 'front') pvDimV(S, rx, ry, xr, d.z1, d.z2, String(Math.round(d.size)), 18);
      else pvText(S, rx(-14), ry((d.z1 + d.z2)/2), String(Math.round(d.size)), 15, 'end');
    });
    pvDimH(S, rx, ry, g.gapSides, g.W - g.gapSides, -26, String(Math.round(g.W - 2*g.gapSides)), 18);
  }

  // Ciste (Node testy): rozklad radu ciel na kotovatelne useky.
  // items = front_items ([{ z, height }]), g = { H, fh }
  // -> [{ kind:'front'|'gap', z1, z2, size, id }]
  function nxFrontDims(items, g){
    var out = [];
    var list = (items || []).filter(function(it){ return it && it.height > 0; })
                            .slice().sort(function(a, b){ return a.z - b.z; });
    if (!list.length) return out;
    var MINGAP = 0.5; // pod pol milimetra nie je co kotovat
    var prev = (g && g.fh) || 0;
    list.forEach(function(it){
      if (it.z - prev >= MINGAP) out.push({ kind: 'gap', z1: prev, z2: it.z, size: it.z - prev, id: '' });
      out.push({ kind: 'front', z1: it.z, z2: it.z + it.height, size: it.height, id: it.id || '' });
      prev = it.z + it.height;
    });
    var top = (g && g.H) || 0;
    if (top - prev >= MINGAP) out.push({ kind: 'gap', z1: prev, z2: top, size: top - prev, id: '' });
    return out;
  }

  // ---- ZAKLADNA vrstva: kovanie (UI-B2, nova projekcia) -------------------
  // Znacky sa kreslia z payloadu config.hardware (owner_part_key + generic_type
  // + pocet) a z geometrie, ktoru nahlad uz pozna. Kovanie sa NIKDY necita
  // z geometrie modelu (invariant) — a ani tu sa nic nedopocitava do dat.
  function drawHwBase(S, rx, ry, g){
    // Zonove delenie tlmene, nech je citatelne KDE kovanie sedi (vzor mockupu).
    // Ked uzivatel zapol chip Zony, kresli ho uz ghost vrstva — inak by ta ista
    // ciara isla do SVG dvakrat.
    if (NXLayers.stateOf('hw', 'zony', pvAvail()) !== 'on') drawZonesGhost(S, rx, ry, g);
    var marks = nxHwMarks(hwItems, g);
    marks.forEach(function(m){ S.push(hwMarkSvg(m, rx, ry, false)); });
    var sum = nxHwSummary(hwItems);
    pvText(S, rx(g.W/2), ry(-44), sum || 'Skrinka zatiaľ nemá kovanie', 19);
    if (marks.length) pvText(S, rx(g.W/2), ry(-70), 'klik na značku = popis položky · pozície sú orientačné', 15);
  }

  // Ciste (Node testy): odvodenie znaciek z payloadu kovania.
  // items: [{ owner_part_key, generic_type, quantity, label, owner_label }]
  // g:     { W, H, fh, gapSides, gap, fronts: [{ id, z, height, type, wings_n }] }
  // ->     [{ kind:'hinge'|'slide'|'leg', x, z, w, h, r, owner, title }]
  // Typy bez kresitelnej pozicie (podperky, spojky, uchytky) znacku nedostanu —
  // su v suhrne pod projekciou, aby o nich pouzivatel vedel.
  function nxHwMarks(items, g){
    var out = [];
    if (!items || !items.length) return out;
    var W = g.W, fh = g.fh || 0;
    var gs = (g.gapSides == null) ? 2 : g.gapSides;
    var gap = (g.gap == null) ? 3 : g.gap;
    var ow = W - 2*gs;
    function frontOf(id){
      var fs = g.fronts || [];
      for (var i = 0; i < fs.length; i++){ if (String(fs[i].id) === id) return fs[i]; }
      return null;
    }
    // Stlpce kridiel — TA ISTA matematika ako kresba ciel (D-24).
    function wingCols(fr){
      var wn = fr.wings_n || 1;
      if (fr.type === 'door' && wn > 1){
        var dw = (ow - (wn - 1) * gap) / wn, cols = [];
        for (var i = 0; i < wn; i++) cols.push({ x: gs + i*(dw+gap), w: dw });
        return cols;
      }
      return [{ x: gs, w: ow }];
    }
    items.forEach(function(it){
      if (!it) return;
      var qty = Math.max(1, parseInt(it.quantity, 10) || 1);
      var owner = String(it.owner_part_key || '');
      var title = (it.label || it.generic_type || '') +
                  (it.owner_label ? ' · ' + it.owner_label : '') + ' · ' + qty + '×';
      if (it.generic_type === 'leg'){
        var n = Math.min(qty, 8), lw = 42, lh = fh > 0 ? Math.min(fh, 90) : 70;
        var z0 = fh > 0 ? 0 : -lh, ins = 60, span = W - 2*ins - lw;
        for (var i = 0; i < n; i++){
          var lx = (n === 1 || span <= 0) ? (W - lw)/2 : (ins + span * i / (n - 1));
          out.push({ kind: 'leg', x: lx, z: z0, w: lw, h: lh, owner: owner, title: title });
        }
        return;
      }
      var m = owner.match(/^front:([^\/]+)\/(?:wing:(left|right|single|p[1-4])|panel)$/);
      if (!m) return;
      var fr = frontOf(m[1]);
      if (!fr || !(fr.height > 0)) return;
      if (it.generic_type === 'hinge'){
        var cols = wingCols(fr), wkey = m[2] || 'single', idx = 0;
        if (wkey === 'right') idx = cols.length - 1;
        else if (wkey.charAt(0) === 'p') idx = Math.min(cols.length - 1, Math.max(0, parseInt(wkey.slice(1), 10) - 1));
        var col = cols[idx] || cols[0];
        // Zavesova HRANA: prave kridlo (a posledny panel viackridloveho cela) sa
        // otvara od praveho okraja, ostatne od laveho. Presnu stranu data nenesu,
        // preto je znacka ORIENTACNA — tooltip pomenuva vlastnika presne.
        var right = (wkey === 'right') ||
                    (wkey.charAt(0) === 'p' && cols.length > 1 && idx === cols.length - 1);
        var cx = right ? (col.x + col.w - 26) : (col.x + 26);
        var nh = Math.min(qty, 6), pad2 = Math.min(90, fr.height * 0.22);
        for (var k = 0; k < nh; k++){
          var cz = (nh === 1) ? (fr.z + fr.height/2)
                              : (fr.z + pad2 + (fr.height - 2*pad2) * k / (nh - 1));
          out.push({ kind: 'hinge', x: cx, z: cz, r: 16, owner: owner, title: title });
        }
        return;
      }
      if (it.generic_type === 'slide'){
        // dvojica kolajnic spredu vo vyske zasuvky (vzor mockupu)
        var rz = fr.z + fr.height * 0.42, rw = Math.max(40, ow - 36);
        out.push({ kind: 'slide', x: gs + 18, z: rz, w: rw, h: 10, owner: owner, title: title });
        out.push({ kind: 'slide', x: gs + 18, z: rz + 18, w: rw, h: 10, owner: owner, title: title });
      }
    });
    return out;
  }

  // Ciste (Node testy): suhrn pod projekciou — VSETKY typy vratane tych bez
  // znacky (poctivo: „podperky 8×" musia byt vidiet, aj ked sa nekreslia).
  function nxHwSummary(items){
    var order = [], sums = {};
    (items || []).forEach(function(it){
      if (!it) return;
      var name = it.label || it.generic_type;
      if (!name) return;
      if (sums[name] == null){ sums[name] = 0; order.push(name); }
      sums[name] += Math.max(0, parseInt(it.quantity, 10) || 0);
    });
    return order.map(function(n){ return n + ' ' + sums[n] + '×'; }).join(' · ');
  }

  function hwMarkSvg(m, rx, ry, ghost){
    var stroke = ghost ? PV_GHOST : PV_SELECT;
    var fill = ghost ? 'none' : PV_FRONT_DOOR;
    var body;
    if (m.kind === 'hinge'){
      body = '<circle cx="'+rx(m.x)+'" cy="'+ry(m.z)+'" r="'+m.r+'" fill="'+fill+'" stroke="'+stroke+'" stroke-width="2.5"/>' +
        '<path d="M'+(rx(m.x)-m.r*0.55)+' '+(ry(m.z)-m.r*0.55)+' l'+(m.r*1.1)+' '+(m.r*1.1)+
        ' M'+(rx(m.x)-m.r*0.55)+' '+(ry(m.z)+m.r*0.55)+' l'+(m.r*1.1)+' '+(-m.r*1.1)+
        '" stroke="'+stroke+'" stroke-width="2.2" fill="none"/>';
    } else {
      body = '<rect x="'+rx(m.x)+'" y="'+ry(m.z + m.h)+'" width="'+m.w+'" height="'+m.h+
        '" rx="3" fill="'+fill+'" stroke="'+stroke+'" stroke-width="2"/>';
    }
    if (ghost) return '<g pointer-events="none" opacity="0.75">' + body + '</g>';
    return '<g class="hwmk" data-tip="'+esc(m.title)+'" style="cursor:pointer"><title>'+esc(m.title)+'</title>' +
           body + '</g>';
  }

  // ---- GHOST vrstvy (chipy spodneho pasu) ---------------------------------
  // Ghost NIKDY nekresli vyplne ani klikatelne ciele — je to len tlmena linka
  // navrch zakladnej projekcie, aby bolo vidno suvislost (kde su zony pri
  // celach, kde sedi kovanie…).
  function drawGhostLayers(S, rx, ry, g){
    var mode = pvChipMode();
    if (mode === 'part') return;
    NXLayers.ghosts(mode, pvAvail()).forEach(function(k){
      if (k === 'zony') drawZonesGhost(S, rx, ry, g);
      else if (k === 'cela') drawFrontsGhost(S, rx, ry, g);
      else if (k === 'kovanie') drawHwGhost(S, rx, ry, g);
    });
  }
  function drawZonesGhost(S, rx, ry, g){
    var zones;
    try { zones = computeZones(); } catch (e){ return; }
    var L = [];
    (zones || []).forEach(function(z){
      if (z.leaf){
        if (z.shelves > 0){
          for (var s = 1; s <= z.shelves; s++){
            var zs = z.z + z.h * s / (z.shelves + 1);
            L.push('M'+rx(z.x)+' '+ry(zs)+'H'+rx(z.x + z.w));
          }
        }
      } else if (z.split){
        var sizes = z.split.sizes, i;
        if (z.split.axis === 'v'){
          var x = z.x;
          for (i = 0; i < z.split.count - 1; i++){ x += sizes[i]; L.push('M'+rx(x)+' '+ry(z.z)+'V'+ry(z.z + z.h)); x += g.t; }
        } else {
          var zz = z.z;
          for (i = 0; i < z.split.count - 1; i++){ zz += sizes[i]; L.push('M'+rx(z.x)+' '+ry(zz)+'H'+rx(z.x + z.w)); zz += g.t; }
        }
      }
    });
    if (L.length) S.push('<path d="'+L.join(' ')+'" stroke="'+PV_GHOST+'" stroke-width="2" stroke-dasharray="8 6" fill="none" pointer-events="none"/>');
  }
  function drawFrontsGhost(S, rx, ry, g){
    var items = g.fronts;
    if (!items || !items.length) return;
    var gs = g.gapSides, ow = g.W - 2*gs, L = [];
    items.forEach(function(it){
      if (!it || !(it.height > 0)) return;
      L.push('M'+rx(gs)+' '+ry(it.z)+'h'+ow+'V'+ry(it.z + it.height)+'h'+(-ow)+'Z');
    });
    if (L.length) S.push('<path d="'+L.join(' ')+'" stroke="'+PV_GHOST+'" stroke-width="2" stroke-dasharray="9 6" fill="none" pointer-events="none"/>');
  }
  function drawHwGhost(S, rx, ry, g){
    nxHwMarks(hwItems, g).forEach(function(m){ S.push(hwMarkSvg(m, rx, ry, true)); });
  }

  // ===================== UI-B2: SPODNY PAS NAHLADU ===========================
  // Chipy vrstiev vlavo, nastroje vpravo (kamera N7 + fit). Pas je STATICKA
  // kostra v panel.html — tu sa meni len obsah #pvChips a stav tlacidiel.
  // Podpis stavu pasu — renderPreview bezi aj pri KAZDOM kroku tahu priecky,
  // takze pas sa prestavuje LEN vtedy, ked sa naozaj zmenil (inak by sa 4
  // tlacidla prekreslovali 60x za sekundu a hover/fokus by blikal).
  var pvBarSig = null;
  function renderPvBar(){
    var box = el('pvChips');
    var mode = pvChipMode(), avail = pvAvail();
    var sig = mode + '|' + NXLayers.chips(mode, avail).map(function(c){ return c.key + ':' + c.state; }).join(',') +
              '|' + (selectedCabId ? '1' : '0');
    if (sig === pvBarSig) return;
    pvBarSig = sig;
    if (box){
      var h = '';
      NXLayers.chips(mode, avail).forEach(function(c){
        var dis = (c.state === 'disabled'), base = (c.state === 'base');
        var icon = (c.state === 'on' || base) ? 'eye' : 'eye-off';
        // aria-disabled (nie HTML disabled) — tlacidlo ostava fokusovatelne
        // a nesie vysvetlenie, presne vzor railu (D-78 / UI-B1).
        h += '<button type="button" class="lchip' + (base ? ' base' : '') + (c.state === 'on' ? ' on' : '') +
             (dis ? ' off' : '') + '" data-nx-usage="pv:vrstva:' + c.key + '"' +
             ' aria-pressed="' + ((c.state === 'on' || base) ? 'true' : 'false') + '"' +
             ' aria-disabled="' + ((dis || base) ? 'true' : 'false') + '"' +
             ' title="' + esc(c.title) + '" aria-label="' + esc(c.label + ' — ' + c.title) + '"' +
             ' onclick="onPvLayer(\'' + c.key + '\')">' +
             NXIcons.svg(icon) + '<span>' + esc(c.label) + '</span></button>';
      });
      box.innerHTML = h;
    }
    var cam = el('pvCam');
    if (cam){
      var on = !!selectedCabId;
      cam.setAttribute('aria-disabled', on ? 'false' : 'true');
      cam.title = on ? 'Pohľad na skrinku — zarovná kameru v SketchUpe (čelný pohľad)'
                     : 'Pohľad na skrinku — najprv označ skrinku v modeli';
    }
  }
  function onPvLayer(key){
    if (!NXLayers.toggle(pvChipMode(), key, pvAvail())){
      renderPvBar(); // neaktivny chip: nic sa nemeni, ale titul/stav ostava presny
      return;
    }
    renderPreview(); // prekreslenie projekcie aj pasu
  }
  // N7: kamera. Ruby LEN zarovna pohlad (view.camera + view.zoom) — ziadny
  // zapis do modelu, ziadna operacia, ziadny krok Spat (lekcia D-103).
  // Callback je asynchronny, preto nesie identitu dokumentu AJ skrinky.
  function onPvCamera(){
    if (!selectedCabId){
      NX.setStatus('Označ skrinku — pohľad sa zarovnáva na ňu.', true);
      return;
    }
    if (window.sketchup && sketchup.nx_camera_focus){
      sketchup.nx_camera_focus(JSON.stringify({
        cabinet_id: selectedCabId,
        model_guid: (typeof NXShell !== 'undefined' && NXShell) ? NXShell.identityGuid() : ''
      }));
    }
  }

  // Event DELEGACIA: jeden listener na SVG kontajneri (nie per-element pri kazdom re-renderi).
  // Cielovy .divh / .zrect hladame z ev.target. Predtym sa listenery bindovali na konkretne
  // elementy v renderPreview; po prekresleni (napr. po apply) mohli byt na starych/nahradenych
  // uzloch — jedna z pricin, preco po prvom drag-u priecka prestala reagovat.
  var previewBound = false;
  var panState = null, panMoved = false;
  function setupPreviewDelegation(){
    if (previewBound) return;
    var svg = el('preview'); if (!svg) return;
    svg.addEventListener('mousedown', function(ev){
      var t = closestClass(ev.target, 'divh');
      if (t){ startDivDrag(ev, t, svg); return; }
      startPan(ev); // pan pohladu (aj nad zonou — kratky tah bez pohybu ostava klikom)
    });
    svg.addEventListener('click', function(ev){
      if (panMoved){ panMoved = false; return; } // tah pohladu nie je klik na zonu
      // D-23: klik na celo (cely <g> item — kridla, none pas aj text) -> jeho
      // riadok v zozname. .fgrp existuje LEN vo fronts nahlade, takze zone klik
      // (.zrect) v tabe Zony bezi nedotknuty.
      var f = closestClass(ev.target, 'fgrp');
      if (f){ focusFrontRow(f.getAttribute('data-front-id')); return; }
      // UI-B2: klik na znacku kovania = jej popis v statuse (co to je, ciej to
      // je a kolko toho je). Vyber vlastnika v modeli patri az davke UI-C4,
      // kde kovanie dostane owner boxy — dovtedy sa nic neoznacuje.
      var hm = closestClass(ev.target, 'hwmk');
      if (hm){ NX.setStatus(hm.getAttribute('data-tip') || '', false); return; }
      var t = closestClass(ev.target, 'zrect');
      if (t) pickZone(t.getAttribute('data-zid'));
    });
    // D-23: hover sync celo <-> riadok VYHRADNE CSS triedou. renderPreview sa
    // pocas hoveru NEVOLA (zmazal by hoverovany uzol — blikanie, kolizia s
    // pan/drag aj 500 ms debounce); relatedTarget guard ignoruje presuny
    // v ramci toho isteho <g>.
    svg.addEventListener('mouseover', function(ev){
      var g = closestClass(ev.target, 'fgrp');
      if (g) setFrontHover(g.getAttribute('data-front-id'));
    });
    svg.addEventListener('mouseout', function(ev){
      var g = closestClass(ev.target, 'fgrp');
      if (!g) return;
      if (ev.relatedTarget && closestClass(ev.relatedTarget, 'fgrp') === g) return;
      clearFrontHover();
    });
    // Druha strana synku: riadky ciel. Kontajner #frontRows je staticky (riadky
    // v nom sa menia) — delegacia prezije kazdy rebuild zoznamu.
    var fr = el('frontRows');
    if (fr){
      fr.addEventListener('mouseover', function(ev){
        var r = frowOf(ev.target);
        if (r) setFrontHover(r.dataset.frontId);
      });
      fr.addEventListener('mouseout', function(ev){
        var r = frowOf(ev.target);
        if (!r) return;
        if (ev.relatedTarget && frowOf(ev.relatedTarget) === r) return;
        clearFrontHover();
      });
    }
    // Zoom kolieskom k bodu pod kurzorom. Limity: detail max 8x, oddialenie max 3x sceny.
    svg.addEventListener('wheel', function(ev){
      // D-12: zoom LEN s Ctrl — cisty scroll necha scrollovat panel (ziadny
      // preventDefault), Ctrl+koliesko zoomuje a blokuje CEF zoom stranky.
      if (!ev.ctrlKey) return;
      ev.preventDefault();
      if (!pvView) return;
      var rect = svg.getBoundingClientRect();
      var base = sceneSize();
      var k = ev.deltaY > 0 ? 1.2 : 1/1.2;
      var nw = Math.min(Math.max(pvView.w * k, base.w / 8), base.w * 3);
      var ratio = nw / pvView.w;
      var pt = clientToScene(ev, rect);
      pvView = { x: pt.x - (pt.x - pvView.x) * ratio, y: pt.y - (pt.y - pvView.y) * ratio,
                 w: nw, h: pvView.h * ratio };
      pvUserView = true;
      svg.setAttribute('viewBox', pvView.x + ' ' + pvView.y + ' ' + pvView.w + ' ' + pvView.h);
    }, { passive: false });
    previewBound = true;
  }

  // --- pan pohladu (tah prazdnej plochy / zony; priecky maju vlastny drag) ---
  function startPan(ev){
    panState = { sx: ev.clientX, sy: ev.clientY, vx: pvView ? pvView.x : 0, vy: pvView ? pvView.y : 0 };
    panMoved = false;
    document.addEventListener('mousemove', onPanMove);
    document.addEventListener('mouseup', endPan);
  }
  function onPanMove(ev){
    if (!panState || !pvView) return;
    var dx = ev.clientX - panState.sx, dy = ev.clientY - panState.sy;
    if (!panMoved && Math.abs(dx) + Math.abs(dy) < 5) return; // prah: klik ostava klikom
    panMoved = true;
    var svg = el('preview'); if (!svg) return;
    var m = viewMapping(svg.getBoundingClientRect());
    pvView.x = panState.vx - dx / m.s;
    pvView.y = panState.vy - dy / m.s;
    pvUserView = true;
    svg.setAttribute('viewBox', pvView.x + ' ' + pvView.y + ' ' + pvView.w + ' ' + pvView.h);
  }
  function endPan(){
    document.removeEventListener('mousemove', onPanMove);
    document.removeEventListener('mouseup', endPan);
    panState = null;
    // panMoved necha nastavene — najblizsi click handler ho skonzumuje (potlaci pick zony)
  }
  // Vlastny closest (SVG elementy — spolahame sa len na getAttribute('class'), nie className).
  function closestClass(node, cls){
    while (node && node.getAttribute){
      var c = ' ' + (node.getAttribute('class') || '') + ' ';
      if (c.indexOf(' ' + cls + ' ') >= 0) return node;
      node = node.parentNode;
    }
    return null;
  }

  // ===== D-23: sync riadok <-> celo (hover) ==================================
  // Zvyraznenie je VYHRADNE CSS trieda 'hov' na oboch stranach naraz (riadok
  // .frow v #frontRows + <g class="fgrp"> v nahlade); stav drzi hoverFrontId.
  // Po rerenderi/zmene tabu/vyberu stav cisti renderPreview (nove uzly triedu
  // nemaju) a plny rebuild riadkov (renderFronts).
  var hoverFrontId = null;
  // Striktne priamy potomok #frontRows s triedou .frow (audit: ziadne cudzie .frow).
  function frowOf(node){
    var wrap = el('frontRows');
    while (node && node !== wrap && node.getAttribute){
      var c = ' ' + (node.getAttribute('class') || '') + ' ';
      if (c.indexOf(' frow ') >= 0) return (node.parentNode === wrap) ? node : null;
      node = node.parentNode;
    }
    return null;
  }
  function setFrontHover(fid){
    if (!fid || fid === hoverFrontId) return; // presun v ramci itemu = ziadne blikanie
    clearFrontHover();
    hoverFrontId = fid;
    var svg = el('preview');
    if (svg){
      var gs = svg.querySelectorAll('g.fgrp');
      for (var i = 0; i < gs.length; i++){
        if (gs[i].getAttribute('data-front-id') === fid){ gs[i].classList.add('hov'); break; }
      }
    }
    var wrap = el('frontRows');
    if (wrap){
      var rows = wrap.querySelectorAll('.frow');
      for (var j = 0; j < rows.length; j++){
        if (rows[j].dataset.frontId === fid){ rows[j].classList.add('hov'); break; }
      }
    }
  }
  function clearFrontHover(){
    if (hoverFrontId === null) return;
    hoverFrontId = null;
    var svg = el('preview');
    if (svg){ var g = svg.querySelector('g.fgrp.hov'); if (g) g.classList.remove('hov'); }
    var wrap = el('frontRows');
    if (wrap){ var r = wrap.querySelector('.frow.hov'); if (r) r.classList.remove('hov'); }
  }

  function pickZone(localId){
    activeZoneId = fullZoneId(localId);
    refreshZoneUI();
    // UI-B1 (Codex #168 P2): karta Zona zije v sektore Nastavenia — klik na zonu
    // v nahlade ju musi aj UKAZAT (zbaleny sektor by ju schoval). Rozbaluje sa
    // LEN na tejto pouzivatelskej ceste, nie pri kazdom serverovom refreshi.
    if (typeof nxRevealTarget === 'function') nxRevealTarget(el('zoneCard'));
    renderPreview();
    if (selectedCabId && window.sketchup && sketchup.select_zone) sketchup.select_zone(JSON.stringify({ zone_id: activeZoneId }));
  }

  // --- drag priecky ---
  function startDivDrag(ev, d, svg){
    ev.preventDefault();
    // Obrana: ak by z predchadzajuceho dragu ostali visiet listenery (napr. mouseup mimo okna),
    // vycisti ich a zahod stary stav — inak by sa drag "zasekol" a dalsi neodstartoval cisto.
    document.removeEventListener('mousemove', onDivDrag);
    document.removeEventListener('mouseup', endDivDrag);
    dragState = null;
    var zid = d.getAttribute('data-zid'), idx = parseInt(d.getAttribute('data-idx'),10), axis = d.getAttribute('data-axis');
    // najdi rodicovsku zonu v computeZones pre span
    var zones = computeZones(); var parent = null;
    zones.forEach(function(z){ if (z.id === zid) parent = z; });
    if (!parent || !parent.split) return;
    // fix #5: zmraz aktualny layout -> pri tahani sa menia len 2 dotknute polia, ostatne drzia rozmer
    freezeLayout(zid);
    var t = numv('thickness')||18;
    var span = (axis==='v') ? parent.w : parent.h;
    dragState = { zid: zid, idx: idx, axis: axis, parent: parent, span: span, t: t,
                  sizes: parent.split.sizes.slice(), startX: ev.clientX, startY: ev.clientY, svg: svg };
    document.addEventListener('mousemove', onDivDrag);
    document.addEventListener('mouseup', endDivDrag);
  }
  function onDivDrag(ev){
    if (!dragState) return;
    var svg = dragState.svg; var rect = svg.getBoundingClientRect();
    // px->mm cez aktualne view okno (D1 fix: povodny prepocet cez sirku korpusu by bol
    // pri zoomnutom/panovanom pohlade nespravny — priecka by "utekala" kurzoru)
    var scale = viewMapping(rect).s; // px per mm
    var d_mm = (dragState.axis==='v') ? (ev.clientX - dragState.startX)/scale : -(ev.clientY - dragState.startY)/scale;
    var sizes = dragState.sizes.slice();
    var i = dragState.idx;
    // presun hranice medzi polom i a i+1: zvacsi i, zmensi i+1
    var newI = sizes[i] + d_mm, newN = sizes[i+1] - d_mm;
    if (newI < MINF){ newN -= (MINF-newI); newI = MINF; }
    if (newN < MINF){ newI -= (MINF-newN); newN = MINF; }
    sizes[i] = newI; sizes[i+1] = newN;
    // uloz do currentZoneTree (docasne, ako size hodnoty)
    var tree = sanitizeTree(currentZoneTree);
    var node = navTree(tree, pathOf(dragState.zid));
    if (node && node.split){ node.split.cuts[i] = { size: Math.round(newI), locked: node.split.cuts[i].locked };
                             node.split.cuts[i+1] = { size: Math.round(newN), locked: node.split.cuts[i+1].locked }; }
    currentZoneTree = tree;
    renderPreview();
    NX.setStatus('Pole '+(i+1)+': '+Math.round(newI)+' mm · pole '+(i+2)+': '+Math.round(newN)+' mm', false);
  }
  function endDivDrag(ev){
    document.removeEventListener('mousemove', onDivDrag);
    document.removeEventListener('mouseup', endDivDrag);
    if (!dragState) return;
    var i = dragState.idx, zid = dragState.zid;
    // fix #5: posli kompletny layout (vsetky polia uz maju explicitne sizes zo freeze + dragu)
    if (selectedCabId) pushFieldCuts(zid, i);
    dragState = null;
  }

  // Node testy (tests/js/test_uib2_nahlad.js) — LEN ciste jadro projekcii
  // (vyber projekcie, stav chipov, odvodenie znaciek kovania a kot). V CEF je
  // module undefined a DOM cast bezi normalne (vzor shell.js / usage.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { NXLayers: NXLayers, cabTabPreview: cabTabPreview,
                       nxHwMarks: nxHwMarks, nxHwSummary: nxHwSummary,
                       nxFrontDims: nxFrontDims, nxZoneSpans: nxZoneSpans,
                       pvDepthDimZ: pvDepthDimZ, pvSceneTopZ: pvSceneTopZ };
  }

