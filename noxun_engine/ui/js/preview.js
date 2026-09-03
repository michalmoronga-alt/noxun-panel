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
  // KOV-A1 (Codex #280 P2-C): POPIS typu cela v nahlade — JEDNO miesto.
  // Do KOV-A1 sa kazde ne-zasuvkove a ne-`none` celo popisovalo ako „dvierka",
  // takze pri configu z API sa rozbalovacka volala „Výklop" a nahlad vedla nej
  // tvrdil „dvierka". Fallback ostava „dvierka" — ale UZ LEN pre NEZNAMY typ
  // (napr. z novsej verzie), nie pre kazdy typ, ktory tento zoznam nepozna.
  // ŠTÝL (výplň, symboly ∧/∨/X, smery) sa TU ZAMERNE NEMENI — to je KOV-A2;
  // tato oprava riesi vyhradne TEXT, aby si UI neprotirecilo.
  var PV_FRONT_TYPE_DESC = { door: 'dvierka', drawer_front: 'zásuvka',
                             lift: 'výklop', fall: 'sklop', blind: 'blenda' };
  function frontTypeDesc(type){ return PV_FRONT_TYPE_DESC[type] || 'dvierka'; }
  // KOV-A2a / D-115: SYMBOLY OTVARANIA v nahlade. Kreslia sa vo vyberovej
  // farbe (`PV_SELECT_ACCENT`) — prerusovana ciara = pohyb, plna = dielec;
  // to iste pravidlo maju sprite ikony typegridu. „Neurcene" je JEDINY symbol
  // v inej farbe: jantar `--nx-warn-fg` (je to otvorena otazka, nie chyba).
  // Jedina vynimka z prerusovania je BLENDA — plne X, lebo blenda sa NEHYBE.
  var PV_DIR_WARN = '#e65100';      // --nx-warn-fg (neurceny smer)
  var PV_SYM_DASH = 'stroke-dasharray="11 8" stroke-width="3" fill="none" stroke-linecap="round"';
  var PV_SYM_SOLID = 'stroke-width="3" fill="none" stroke-linecap="round"';
  // Co sa ma nakreslit, rozhoduju CISTE funkcie v core.js (`frontWingSymbols` /
  // `frontTypeSymbol`) nad `front_slots` zo SERVERA — preview zo `wings` nikdy
  // stranu neodvodzuje. A AKO to vyzera, urcuje `frontSymbolShape` (core.js) —
  // TA ISTA tabulka, akou kresli overlay v modeli. Tu ostava uz len prevod
  // jednotkovych suradnic na suradnice nahladu.
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
  // UI-C1b: scena vkladanej DOSKY je samotna doska (dlzka x sirka) + rezerva na
  // koty. Vlastna funkcia — korpusove polia (#width/#height) v tomto rezime nic
  // neznamenaju. Ciste (Node testy): rozmery dnu, obdlznik sceny von.
  // Vlavo a hore staci obycajny padding, vpravo (kota sirky) a dole (kota dlzky)
  // musi ostat miesto na ciaru aj text — inak by ich fit orezal.
  function pvBoardScene(L, Wd){
    var l = Math.max(1, nxNumOr(L, 0)), w = Math.max(1, nxNumOr(Wd, 0));
    return { x: -PV_PAD, y: -PV_PAD, w: l + PV_PAD + DIM_EXT, h: w + PV_PAD + DIM_EXT };
  }
  // Rozsah DRAFT ciel vkladanej sablony v mm modelu (Codex #175 P2). Zrkadlo
  // `frontsExtent`, ale nad draftom — vo vkladani `frontItems` neexistuje.
  // null = kresli sa doska alebo sablona ziadne cela nema. Ciste jadro je
  // `nxFrontsExtent` (Node testy).
  function insertFrontsExtent(){
    if (previewMode !== 'insert' || pvInsertBoard()) return null;
    var gs = 2; var gsv = numv('fr_gap_sides'); if (!isNaN(gsv)) gs = gsv;
    return nxFrontsExtent(pvInsertFronts(), numv('width') || 0, numv('height') || 0, gs);
  }
  // Ciste (Node testy): obalka korpus ∪ cela. Zaporny bocny okraj = cela sirsie
  // nez korpus; zaporne medzery hore/dole = cela nad/pod obrysom.
  function nxFrontsExtent(items, W, H, gapSides){
    if (!items || !items.length) return null;
    var gs = nxNumOr(gapSides, 2), w = nxNumOr(W, 0), h = nxNumOr(H, 0);
    var e = { minX: Math.min(0, gs), maxX: Math.max(w, w - gs), minZ: 0, maxZ: h };
    items.forEach(function(it){
      if (!it) return;
      e.minZ = Math.min(e.minZ, nxNumOr(it.z, 0));
      e.maxZ = Math.max(e.maxZ, nxNumOr(it.z, 0) + nxNumOr(it.height, 0));
    });
    return e;
  }
  // Je prave kreslena vkladana DOSKA? (projekcia 'insert' ma dve podoby)
  function pvInsertBoard(){
    return previewMode === 'insert' && typeof getInsertKind === 'function' && getInsertKind() === 'board';
  }
  function sceneSize(){
    if (pvInsertBoard()) return pvBoardScene(numv('ib_length'), numv('ib_width'));
    var W = numv('width')||600, H = numv('height')||720;
    var solid = (previewMode === 'cab' || previewMode === 'hw');
    var e = solid ? null : frontsExtent();
    var minX = e ? e.minX : 0, maxX = e ? e.maxX : W;
    var minZ = e ? e.minZ : 0, maxZ = e ? e.maxZ : H;
    if (previewMode === 'cab' || previewMode === 'insert'){
      // D-11: vlavo koty sokla/tela, vpravo vyska, dole sirka, hore naznak hlbky
      // (UI-C1b: vkladanie kresli sablonu tym istym celnym rezom + kotami)
      var sk = pvDepthSkew();
      minX = -DIM_EXT; maxX = W + DIM_EXT + sk; minZ = -DIM_EXT;
      // Codex #169 P2: nad skosenim este LEZI KOTA hlbky — scene musi patrit aj
      // jej ciara, znacky a text, inak ju fit orezal.
      maxZ = pvSceneTopZ(H, sk);
      // Codex #175 P2: vo VKLADANI sa cela naozaj kreslia, a s odomknutym limitom
      // presahov (D-22) mozu sablonove cela vytrcat MIMO obrys korpusu. Rezerva
      // na koty ich nemusi pokryt, preto sa scena roztiahne o ich skutocny rozsah
      // (frontsExtent cita `frontItems`, ktore su tu null — pasca FIX 11).
      var ie = insertFrontsExtent();
      if (ie){
        minX = Math.min(minX, ie.minX); maxX = Math.max(maxX, ie.maxX);
        minZ = Math.min(minZ, ie.minZ); maxZ = Math.max(maxZ, ie.maxZ);
      }
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
    // UI-C1b: projekcia 'insert' (sablona ako bude vlozena) zakladnu vrstvu NEMA
    // — kresli sa korpus a CELA su prepinatelna vrstva, aby sa dalo pozriet
    // dovnutra (kontrakt UI 2.0, N9). Preto je tu explicitne `null`.
    var BASE = { cab: null, insert: null, zones: 'zony', fronts: 'cela', hw: 'kovanie', part: 'olep' };
    // Vrstvy, ktore su v danej projekcii zapnute UZ PRI PRVOM otvoreni. Vkladanie
    // ukazuje sablonu tak, ako naozaj vyzera — teda s celami; zhasnut sa daju.
    var DEFAULT_ON = { insert: { cela: true } };
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
    function bag(mode){
      if (!state[mode]){
        var d = DEFAULT_ON[mode], out = {}, k;
        for (k in (d || {})){ if (Object.prototype.hasOwnProperty.call(d, k)) out[k] = d[k]; }
        state[mode] = out;
      }
      return state[mode];
    }
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
             // UI-C1b: konstrukcne volby pre ODHAD kusov/plochy navrhu (nxDraftStats).
             topMode: val('top_mode'), backMode: val('back_mode'),
             bottomBetween: val('bottom_mode') === 'between_sides',
             railDepth: numv('rail_depth') || 100,
             gapSides: gs, gap: gap,
             // UI-C1b: vo VKLADANI server resolved cela nema (skrinka este
             // neexistuje a `frontItems` je tu null — pasca Codex FIX 11),
             // preto ich dopocita cisty draft resolver z hodnot karty.
             fronts: (previewMode === 'insert') ? pvInsertFronts() : (frontItems || []) };
  }

  // ---- UI-C1b: cela NAVRHU (draft resolver) --------------------------------
  // ZRKADLO Fronts.layout (modules/fronts.rb): fixne vysky sa scitaju, zvysok
  // sa rozdeli rovnomerne medzi AUTO riadky a cela sa kladu ODSPODU
  // (z = floor_height + gap_bottom). ZIADNA validacia — nahlad nesmie padnut na
  // nezmyselnej sablone; autoritou pri vlozeni ostava server.
  // Ciste (Node testy).
  function nxNumOr(v, dflt){
    var n = parseFloat(v);
    return (isNaN(n) || !isFinite(n)) ? dflt : n;
  }
  function nxFrontsResolve(cfg, H, fh){
    var out = [];
    var items = (cfg && cfg.items) ? cfg.items : [];
    if (!items.length) return out;
    var gap = nxNumOr(cfg.gap, 3), gt = nxNumOr(cfg.gap_top, 2), gb = nxNumOr(cfg.gap_bottom, 2);
    var fixedSum = 0, autoCount = 0;
    items.forEach(function(it){
      if (it && it.mode === 'fixed') fixedSum += nxNumOr(it.height, 0);
      else autoCount++;
    });
    var remaining = nxNumOr(H, 0) - nxNumOr(fh, 0) - gt - gb - (items.length - 1) * gap - fixedSum;
    var autoH = autoCount ? (remaining / autoCount) : 0;
    if (!(autoH > 0)) autoH = 0; // prepchata sablona: AUTO riadok ma nulu, nie zaporno
    var z = nxNumOr(fh, 0) + gb;
    items.forEach(function(it, i){
      var fixed = !!(it && it.mode === 'fixed');
      var h = fixed ? nxNumOr(it.height, 0) : autoH;
      out.push({ id: (it && it.id) || ('F' + (i + 1)), type: (it && it.type) || 'door',
                 mode: fixed ? 'fixed' : 'auto', wings: it ? it.wings : 'auto',
                 profile: (it && it.profile) || 'none',
                 height: Math.round(h * 100) / 100, z: Math.round(z * 100) / 100 });
      z += h + gap;
    });
    return out;
  }
  // Draft ciel z aktualnej vkladacej karty (DOM -> cisty resolver). Doska cela
  // nema; mimo vkladania sa nevola vobec.
  function pvInsertFronts(){
    if (typeof collectFronts !== 'function') return [];
    if (typeof getInsertKind === 'function' && getInsertKind() === 'board') return [];
    return nxFrontsResolve(collectFronts(), numv('height') || 0,
                           (getType() === 'upper') ? 0 : (numv('floor_height') || 0));
  }

  // ---- UI-C1b: ODHAD kusov a plochy pre NAVRH -------------------------------
  // Server dopocet (`Panel.cabinet_stats`) cita snapshoty UZ VLOZENEJ skrinky —
  // pre navrh neexistuje a builder sa kvoli informacnemu riadku nespusta. Toto
  // je preto vedomy ODHAD zo sablony (v UI je oznaceny znackou ≈): pocita
  // VELKE plosne dielce, nie kazdu lastu. Ciste (Node testy).
  function nxDraftStats(g, zones, fronts){
    var W = nxNumOr(g && g.W, 0), H = nxNumOr(g && g.H, 0), D = nxNumOr(g && g.D, 0);
    var t = nxNumOr(g && g.t, 18), fh = nxNumOr(g && g.fh, 0);
    if (!(W > 0 && H > 0)) return { count: 0, area: 0 };
    var bodyH = Math.max(0, H - fh);
    var n = 0, mm2 = 0;
    function add(k, a){ n += k; mm2 += k * Math.max(0, a); }
    add(2, bodyH * D);                                        // boky
    add(1, (g.bottomBetween ? Math.max(0, W - 2 * t) : W) * D); // dno
    if (g.topMode === 'two_rails') add(2, Math.max(0, W - 2 * t) * nxNumOr(g.railDepth, 100));
    else if (g.topMode !== 'none') add(1, Math.max(0, W - 2 * t) * D);
    if (g.backMode && g.backMode !== 'none') add(1, W * bodyH);
    (zones || []).forEach(function(z){
      if (!z) return;
      if (z.leaf){
        var sh = parseInt(z.shelves, 10) || 0;
        if (sh > 0) add(sh, nxNumOr(z.w, 0) * D);
      } else if (z.split){
        var c = (parseInt(z.split.count, 10) || 1) - 1;
        if (c > 0) add(c, (z.split.axis === 'v' ? nxNumOr(z.h, 0) : nxNumOr(z.w, 0)) * D);
      }
    });
    var gs = nxNumOr(g.gapSides, 2), ow = Math.max(0, W - 2 * gs);
    (fronts || []).forEach(function(it){
      if (!it || it.type === 'none' || !(it.height > 0)) return;
      var wn = parseInt(it.wings_n, 10);
      if (!(wn >= 1)){
        var wex = parseInt(it.wings, 10);
        wn = (wex >= 1 && wex <= 4) ? wex : (ow > 600 ? 2 : 1);
      }
      add(wn, (ow / wn) * it.height);
    });
    return { count: n, area: Math.round(mm2 / 1000) / 1000 }; // mm2 -> m2 (3 des. miesta)
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
    // UI-C1b: vkladana DOSKA nema zony, cela, kovanie ani hranove data — vsetky
    // chipy su neaktivne s vysvetlenim (nie ticho mrtve).
    if (pvInsertBoard()) return { zony: false, cela: false, kovanie: false, olep: false };
    return { zony: !!currentZoneTree,
             // Vo vkladani su cela DRAFT z karty (server ich este nema).
             cela: (previewMode === 'insert') ? pvInsertFronts().length > 0
                                              : !!(frontItems && frontItems.length),
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
  // `fill` je volitelny (N26: medzery pri editacii svietia jantarovo) — bez
  // neho plati tlmena kotova farba.
  function pvText(S, x, y, txt, size, anchor, fill){
    S.push('<text x="'+x+'" y="'+y+'" font-size="'+(size||18)+'" fill="'+(fill||PV_DIM)+
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
    // UI-C4: to iste pre kovanie — prekreslenim zaniknu znacky, na ktorych
    // zvyraznenie visi, a box by ostal prisvieteny bez svojho protajska.
    if (typeof hwClearHover === 'function') hwClearHover();
    // UI-C1b (N10): vkladana DOSKA ma vlastnu projekciu — obdlznik so sipkami
    // smeru dekoru. Kresli sa z poli vkladacej karty, nie z korpusovych.
    if (pvInsertBoard()){ renderInsertBoardPreview(svg); renderPvBar(); return; }
    var g = pvGeom(), W = g.W, H = g.H;
    if (!(W>0 && H>0)){ svg.innerHTML=''; renderPvBar(); return; }
    var pad = PV_PAD;
    applyViewBox(svg);
    var S = [];
    // helper: model (x,z) -> svg (flip Z). y = pad + (H - z)
    function rx(x){ return pad + x; }
    function ry(z){ return pad + (H - z); }
    drawCarcass(S, rx, ry, g, (previewMode === 'cab' || previewMode === 'insert') ? pvDepthSkew() : 0);

    if (previewMode==='zones'){
      drawZonesBase(S, rx, ry, g);
    } else if (previewMode === 'fronts'){
      // cela pohlad + koty vysok a medzier
      renderFrontsPreview(S, rx, ry, g);
      drawFrontDims(S, rx, ry, g);
    } else if (previewMode === 'hw'){
      // UI-B2: kontext Kovanie ma vlastnu projekciu — pozicie kovania
      drawHwBase(S, rx, ry, g);
    } else if (previewMode === 'insert'){
      // UI-C1b (N9): sablona TAK, AKO BUDE VLOZENA. Cela su PREPINATELNA vrstva
      // (chip Čelá je defaultne zapnuty) — po zhasnuti vidno vnutro sablony.
      if (NXLayers.stateOf('insert', 'cela', pvAvail()) === 'on'){
        renderFrontsPreview(S, rx, ry, g);
      } else if (NXLayers.stateOf('insert', 'zony', pvAvail()) !== 'on'){
        // Codex #175 P2: zhasnute cela ODKRYVAJU vnutro — zony sa vtedy kreslia
        // ako podklad. Ked ich uz prisvietil CHIP, kresli ich ghost vrstva, takze
        // sa tu preskocia (inak by tie iste ciary isli do SVG dvakrat).
        // Je to ten isty vzor ako v projekcii Kovanie (drawHwBase).
        drawZonesGhost(S, rx, ry, g);
      }
      renderCabOutline(S, rx, ry, W, H, g.fh);
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
      // KOV-A2a / D-115: symboly otvarania. Kreslia sa PRED popisom, aby text
      // ostal navrchu (SVG kresli v poradi zdroja); ciary uz idu Z ROHOV cez
      // cele kridlo, takze stredom panela naozaj prechadzaju.
      drawFrontSymbols(S, rx, ry, it, cols, z, ph > 0 ? ph : h);
      // popis do stredu PANELU (pri profile nesmie skoncit v jeho pruhu);
      // cislo ostava vyskou RIADKU — presne to, co je v zozname ciel.
      // D-115 HALO: text dostane obrys farbou VYPLNE panelu (`col`, PV_* zrkadlo
      // tokenu), inak by ho X zasuvky/blendy preskrtlo. Ziadna nova farba.
      S.push('<text x="'+rx(W/2)+'" y="'+ry(z+(ph > 0 ? ph : h)/2)+'" font-size="18" fill="'+PV_SELECT_ACCENT+'" paint-order="stroke" stroke="'+col+'" stroke-width="4" text-anchor="middle" dominant-baseline="middle">'+fnum+' · '+frontTypeDesc(it.type)+' '+Math.round(h)+'</text>');
      S.push('</g>');
    });
  }

  // KOV-A2a / D-115: symboly otvarania jedneho cela. `cols` su uz spocitane
  // stlpce (kridla), `z`/`ph` su spodok a vyska PANELA (bez pasma profilu).
  //
  // Dvierka: symbol je PER KRIDLO — jednokridlove podla slotu servera, krajne
  // kridla 2/3/4-kridloveho cela su ODVODENE (A1 kontrakt: p1 = panty vlavo,
  // posledne = vpravo; nic sa neuklada), stredne opat podla slotov. LEGACY
  // (kluc smeru v configu nie je) sa NEKRESLI vobec.
  // Vyklop/sklop/blenda/zasuvka = JEDEN panel cez cely otvor.
  // Symbol vyplna CELE kridlo (ciary z jeho rohov), takze uz nema „velkost"
  // ani posun k volnej hrane — tvar sam hovori, kde su panty.
  function drawFrontSymbols(S, rx, ry, it, cols, z, ph){
    if (ph <= 0 || !cols.length) return;
    if (it.type === 'door'){
      var syms = frontWingSymbols(cols.length, frontSlotsFor(it.id));
      cols.forEach(function(c, i){
        var sym = syms[i];
        if (!sym) return;
        if (sym === 'unknown'){
          // „Neurcene" nema stranu — ostava kruh + otaznik v strede kridla.
          var s = Math.max(18, Math.min(Math.min(c.w, ph) * 0.42, 90));
          var cx = c.x + c.w / 2, cz = z + ph / 2;
          S.push('<circle cx="'+rx(cx)+'" cy="'+ry(cz)+'" r="'+(s/2)+'" fill="none" stroke="'+PV_DIR_WARN+'" '+PV_SYM_DASH+'/>');
          S.push('<text x="'+rx(cx)+'" y="'+ry(cz)+'" font-size="'+Math.round(s*0.8)+'" font-weight="700" fill="'+PV_DIR_WARN+'" text-anchor="middle" dominant-baseline="middle">?</text>');
          return;
        }
        pvSymLines(S, rx, ry, sym, c.x, c.w, z, ph);
      });
      return;
    }
    var tsym = frontTypeSymbol(it.type);
    if (!tsym) return;
    var c0 = cols[0];
    pvSymLines(S, rx, ry, tsym, c0.x, c0.w, z, ph);
  }
  // Prevod jednotkoveho tvaru (`frontSymbolShape` z core.js) na usecky nahladu:
  // u -> x = x0 + u*w, v -> zz = z + v*ph (ry preklapa Z, takze „hore" v tabulke
  // je hore aj na obrazovke). Neznamy symbol nenakresli nic.
  function pvSymLines(S, rx, ry, sym, x0, w, z, ph){
    var shape = frontSymbolShape(sym);
    if (!shape) return;
    var style = shape.dashed ? PV_SYM_DASH : PV_SYM_SOLID;
    shape.lines.forEach(function(ln){
      var a = ln[0], b = ln[1];
      S.push('<line x1="'+rx(x0 + a[0]*w)+'" y1="'+ry(z + a[1]*ph)+
             '" x2="'+rx(x0 + b[0]*w)+'" y2="'+ry(z + b[1]*ph)+
             '" stroke="'+PV_SELECT_ACCENT+'" '+style+'/>');
    });
  }
  // Sloty SERVERA pre dane celo — z jeho zaznamu `{ wings_n, slots }` (Codex
  // #281 P2-A). V rezime vkladania (`insert`) resolved cela neexistuju, takze
  // zaznam chyba — odvodene krajne kridla sa nakreslia aj tak (su geometricky
  // iste, plynu z poctu stlpcov), pytany smer nie.
  function frontSlotsFor(fid){
    if (!frontSlots || !fid) return null;
    var e = Object.prototype.hasOwnProperty.call(frontSlots, fid) ? frontSlots[fid] : null;
    return (e && Array.isArray(e.slots)) ? e.slots : null;
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

  // ---- N26: MEDZERY JANTAROVO PRI EDITACII --------------------------------
  // Kym stoji kurzor v niektorom poli skupiny „Medzery a presahy", medzery v
  // projekcii Cela sa prisvietia — clovek vidi, KTORU skaru prave meni.
  // Je to LEN zvyraznenie: ziadne nove data, ziadny novy vypocet (pasy vznikaju
  // z toho isteho `nxFrontDims`, ktorym sa uz kotuju).
  var NX_GAP_FIELDS = { fr_gap: 1, fr_gap_top: 1, fr_gap_bottom: 1, fr_gap_sides: 1 };
  var PV_GAP_FILL = '#fff3e0';   // --nx-warn-bg-soft
  var PV_GAP_LINE = '#ffb74d';   // --nx-warn
  var PV_GAP_TEXT = '#b26a00';   // --nx-warnchip-fg
  // „Editacia" = OTVORENA skupina „Medzery a presahy" (to je stav, kvoli
  // ktoremu clovek na projekciu pozera) ALEBO kurzor priamo v niektorom z jej
  // poli. Stav sa CITA z DOM, nedrzi sa nikde bokom — zbalenie skupiny tak
  // zvyraznenie zhasne bez akejkolvek dalsej synchronizacie.
  var pvGapFocus = false;
  function pvGapsHot(){
    if (pvGapFocus) return true;
    if (typeof document === 'undefined') return false;
    var d = document.querySelector('details[data-key="fgaps"]');
    return !!(d && d.open);
  }
  function pvSetGapFocus(on){
    if (pvGapFocus === !!on) return;
    pvGapFocus = !!on;
    renderPreview();
  }
  if (typeof document !== 'undefined'){
    document.addEventListener('focusin', function(ev){
      pvSetGapFocus(!!(ev.target && ev.target.id && NX_GAP_FIELDS[ev.target.id]));
    }, true);
    document.addEventListener('focusout', function(ev){
      if (ev.target && ev.target.id && NX_GAP_FIELDS[ev.target.id]) pvSetGapFocus(false);
    }, true);
    // `toggle` NEBUBLA — preto zachytavanie (capture). Rozbalenie/zbalenie
    // skupiny medzier musi projekciu prekreslit.
    document.addEventListener('toggle', function(ev){
      var t = ev.target;
      if (t && t.getAttribute && t.getAttribute('data-key') === 'fgaps') renderPreview();
    }, true);
  }

  // ---- ZAKLADNA vrstva: koty ciel (vysky riadkov + medzery) ---------------
  // Vysky su RESOLVED z payloadu (front_items), medzery su rozdiely medzi nimi
  // — ziadny vlastny vzorec, ziadne nove pole.
  function drawFrontDims(S, rx, ry, g){
    var dims = nxFrontDims(g.fronts, g);
    if (!dims.length) return;
    var xr = Math.max(g.W, g.W - g.gapSides) + 26;
    // N26: pasy medzier sa kreslia PRED kotami, aby cisla ostali navrchu.
    var hot = pvGapsHot();
    if (hot){
      var x0 = Math.min(g.gapSides, 0), x1 = Math.max(g.W, g.W - g.gapSides);
      dims.forEach(function(d){
        if (d.kind !== 'gap') return;
        S.push('<rect x="' + rx(x0) + '" y="' + ry(d.z2) + '" width="' + (x1 - x0) + '" height="' + (d.z2 - d.z1) +
               '" fill="' + PV_GAP_FILL + '" stroke="' + PV_GAP_LINE + '" stroke-width="1.2"/>');
      });
    }
    dims.forEach(function(d){
      if (d.kind === 'front') pvDimV(S, rx, ry, xr, d.z1, d.z2, String(Math.round(d.size)), 18);
      else pvText(S, rx(-14), ry((d.z1 + d.z2)/2), String(Math.round(d.size)), 15, 'end',
                  hot ? PV_GAP_TEXT : null);
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
    if (marks.length) pvText(S, rx(g.W/2), ry(-70), 'klik na značku = označí vlastníka v modeli · pozície sú orientačné', 15);
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
    // Svetly priestor KORPUSU (vnutorne lica bokov) — kovanie, ktore sa montuje
    // na bok (vysuv), sa kotvi sem; cela a ich kridla ostavaju na gs/ow.
    var t = (g.t > 0) ? g.t : 0, ix0 = t, ix1 = W - t;
    if (!(ix1 - ix0 > 0)){ ix0 = 0; ix1 = W; } // nezmyselna hrubka: radsej cely korpus nez ziadna znacka
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
        // Vysuv (schvalene Michalom 20.8. nad mini nahladom): UZ NIE pas naprieč
        // celom, ale to, co je pri otvorenej zasuvke naozaj vidno spredu —
        // pri OBOCH bokoch KOLAJNICA ako „L" profil (zvisla nozicka + vodorovna
        // patka dovnutra) a medzi nimi TELO SUFLIKA. Vsetko sa odvodzuje z vysky
        // cela, takze pri viacerych zasuvkach nad sebou rastu tela s celami.
        // Codex #184 P2: kolajnica sa montuje na BOK KORPUSU, nie na hranu cela —
        // kotvi sa preto na VNUTORNE LICA bokov (x = t … W-t, tie iste, ake kresli
        // drawCarcass), nie na `fr_gap_sides`. Pri gs=2 a hrubke 18 by rail lezal
        // NA doske boku a pri zapornom presahu cela dokonca mimo korpusu.
        var sg = nxSlideGeom(fr, ix0, ix1);
        if (!sg) return;
        out.push({ kind: 'slide_rail', side: 'left', x: sg.xL, z: sg.z, w: sg.foot, h: sg.legH,
                   owner: owner, title: title });
        out.push({ kind: 'slide_rail', side: 'right', x: sg.xR, z: sg.z, w: sg.foot, h: sg.legH,
                   owner: owner, title: title });
        out.push({ kind: 'drawer', x: sg.bx, z: sg.z, w: sg.bw, h: sg.bodyH,
                   owner: owner, title: title });
      }
    });
    return out;
  }

  // Ciste (Node testy): geometria znacky VYSUVU v mm sceny.
  // fr = celo ({ z, height }), x0/x1 = VNUTORNE LICA BOKOV korpusu (x = t … W-t) —
  // vysuv drzi bok, nie celo, preto sa nekotvi na `fr_gap_sides` (Codex #184 P2).
  // -> { z, foot, legH, xL, xR, bx, bw, bodyH } | null
  // Vsetko je pomer z vysky cela — ziadne nove data a ziadna konstanta, ktora by
  // pri vysokej zasuvke vyzerala inak nez pri nizkej.
  function nxSlideGeom(fr, x0, x1){
    var h = fr.height, iw = x1 - x0;
    if (!(h > 0) || !(iw > 0)) return null;
    var foot = Math.max(8, Math.min(iw * 0.12, 40));  // patka „L" smerom DOVNUTRA
    var bodyH = h * 0.58;                             // telo suflika (~55–60 % cela)
    var z = fr.z + h * 0.16;                          // uroven, na ktorej vysuv sedi
    var bx = x0 + foot + 2, bw = iw - 2*(foot + 2);   // telo je ZA patkami kolajnic
    if (!(bw > 0)){ bx = x0 + iw*0.25; bw = iw*0.5; } // uzka zasuvka: patky sa prekryju
    return { z: z, foot: foot, legH: bodyH, xL: x0, xR: x1, bx: bx, bw: bw, bodyH: bodyH };
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
    } else if (m.kind === 'slide_rail'){
      // „L" profil kolajnice z PREDNEHO pohladu: zvisla nozicka pri boku a na jej
      // spodku vodorovna patka smerom DOVNUTRA (na urovni, na ktorej vysuv sedi).
      var fx = rx(m.x + (m.side === 'right' ? -m.w : m.w));
      var d = 'M'+rx(m.x)+' '+ry(m.z + m.h)+'V'+ry(m.z)+'H'+fx;
      body = '<path d="'+d+'" fill="none" stroke="'+stroke+'" stroke-width="4"'+
             ' stroke-linecap="round" stroke-linejoin="round"/>';
      // Hit-oblast: samotny tah je na klik pritenky, preto ma kolajnica este
      // PRIEHLADNY siroky duplikat. Trieda `hwhit` ho drzi mimo hover CSS —
      // inak by sa pri prisvieteni boxu vyfarbil ako hruby pas cez zasuvku.
      if (!ghost) body += '<path class="hwhit" d="'+d+'" fill="none" stroke="transparent" stroke-width="18"/>';
    } else {
      body = '<rect x="'+rx(m.x)+'" y="'+ry(m.z + m.h)+'" width="'+m.w+'" height="'+m.h+
        '" rx="3" fill="'+fill+'" stroke="'+stroke+'" stroke-width="2"/>';
    }
    if (ghost) return '<g pointer-events="none" opacity="0.75">' + body + '</g>';
    // UI-C4: znacka nesie VLASTNIKA (owner_part_key) — klik ho oznaci v modeli
    // a dotiahne jeho box v sekcii Kovanie. Ziadne nove data: `owner` je presne
    // ten kluc, ktorym uz polozka prisla z payloadu.
    return '<g class="hwmk" data-owner="'+esc(m.owner||'')+'" data-tip="'+esc(m.title)+'" style="cursor:pointer">'
         + '<title>'+esc(m.title)+'</title>' + body + '</g>';
  }

  // ---- GHOST vrstvy (chipy spodneho pasu) ---------------------------------
  // Ghost NIKDY nekresli vyplne ani klikatelne ciele — je to len tlmena linka
  // navrch zakladnej projekcie, aby bolo vidno suvislost (kde su zony pri
  // celach, kde sedi kovanie…).
  function drawGhostLayers(S, rx, ry, g){
    var mode = pvChipMode();
    if (mode === 'part') return;
    NXLayers.ghosts(mode, pvAvail()).forEach(function(k){
      // UI-C1b: vo vkladani su zapnute Cela PLNA kresba (sablona tak, ako bude
      // vlozena) — uz ich nakreslil zakladny beh, ghost by isiel do SVG druhykrat.
      if (mode === 'insert' && k === 'cela') return;
      if (k === 'zony') drawZonesGhost(S, rx, ry, g);
      else if (k === 'cela') drawFrontsGhost(S, rx, ry, g);
      else if (k === 'kovanie') drawHwGhost(S, rx, ry, g);
    });
  }

  // ---- UI-C1b (N10): projekcia vkladanej DOSKY ------------------------------
  // Obdlznik v mierke (dlzka vodorovne) + SIPKY SMERU DEKORU + koty. Smer je
  // jediny udaj, ktory na doske pri vkladani vidno „naostro" — orientaciu
  // (lezi/stoji/na stenu) prinesie az UI-C1c.
  function renderInsertBoardPreview(svg){
    var L = numv('ib_length') || 0, Wd = numv('ib_width') || 0;
    if (!(L > 0 && Wd > 0)){ svg.innerHTML = ''; return; }
    applyViewBox(svg);
    var grain = val('ib_grain') || 'none';
    var S = [];
    function rx(x){ return x; }
    function ry(y){ return Wd - y; } // model (x,y) -> svg (flip Y): dlzka vodorovne
    // Vypln = farba zvoleneho DEKORU z katalogu (vzor mockupu); ked ju katalog
    // nema, ostava neutralna vyberova. Hrubka ciary sa skaluje so scenou —
    // pevne 2 mm su na 2600 mm doske neviditelne.
    var mc = (typeof nxComboColorOf === 'function') ? nxComboColorOf('decor', val('ib_material')) : '';
    var sw = Math.max(2, Math.round(Math.max(L, Wd) / 300));
    S.push('<rect x="0" y="0" width="' + L + '" height="' + Wd + '" fill="' + (mc || PV_FRONT_DOOR) +
           '" fill-opacity="' + (mc ? '.8' : '.55') + '" stroke="' + PV_FRONT_STROKE +
           '" stroke-width="' + sw + '"/>');
    var arrows = nxGrainArrows(L, Wd, grain);
    if (arrows.length){
      var d = arrows.map(function(a){
        return 'M' + a.x1 + ' ' + ry(a.y1) + 'L' + a.x2 + ' ' + ry(a.y2) +
               'M' + a.hx1 + ' ' + ry(a.hy1) + 'L' + a.x2 + ' ' + ry(a.y2) +
               'L' + a.hx2 + ' ' + ry(a.hy2);
      }).join(' ');
      S.push('<path d="' + d + '" stroke="' + PV_DIM + '" stroke-width="' +
             Math.max(2, Math.round(Math.min(L, Wd) / 90)) + '" fill="none" pointer-events="none"/>');
    } else {
      pvText(S, L / 2, ry(Wd / 2), 'bez smeru dekoru', pvBoardFont(L, Wd));
    }
    // Popisky su v mm SCENY — velkost sa odvija od VACSIEHO rozmeru, inak by
    // kota na 2600 mm doske bola necitatelne drobna a na 300 mm obria.
    pvDimH(S, rx, ry, 0, L, -26, String(Math.round(L)), pvBoardFont(L, Wd));
    pvDimV(S, rx, ry, L + 26, 0, Wd, String(Math.round(Wd)), pvBoardFont(L, Wd));
    svg.innerHTML = S.join('');
  }
  // Velkost pisma projekcie dosky (mm sceny). Ciste (Node testy).
  function pvBoardFont(L, Wd){ return Math.max(16, Math.round(Math.max(L, Wd) / 30)); }
  // Ciste (Node testy): tri sipky smeru dekoru v mm sceny dosky.
  // 'length' = po dlzke (vodorovne), 'width' = po sirke (zvisle), inak ziadne.
  function nxGrainArrows(L, Wd, grain){
    if (!(L > 0 && Wd > 0)) return [];
    if (grain !== 'length' && grain !== 'width') return [];
    var horiz = (grain === 'length');
    var len = (horiz ? L : Wd) * 0.42;         // dlzka sipky
    var head = Math.max(6, len * 0.12);        // ramienka hrotu
    var out = [];
    for (var i = 1; i <= 3; i++){
      var off = (horiz ? Wd : L) * i / 4;      // rozlozenie naprieč doskou
      var s = (horiz ? L : Wd) * 0.5 - len / 2;
      var x1 = horiz ? s : off, y1 = horiz ? off : s;
      var x2 = horiz ? (s + len) : off, y2 = horiz ? off : (s + len);
      out.push({ x1: x1, y1: y1, x2: x2, y2: y2,
                 hx1: horiz ? (x2 - head) : (x2 - head), hy1: horiz ? (y1 - head) : (y2 - head),
                 hx2: horiz ? (x2 - head) : (x2 + head), hy2: horiz ? (y1 + head) : (y2 - head) });
    }
    return out;
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
    // UI-C2: `pointerdown` (nie `mousedown`) — bez neho nie je `pointerId`, a bez
    // neho sa neda nastavit pointer capture. Kompatibilne `mousedown` sa uz
    // nekona (startDivDrag robi preventDefault), pan si listenery viaze sam.
    svg.addEventListener('pointerdown', function(ev){
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
      // UI-C4: klik na znacku kovania OZNACI VLASTNIKA v modeli a dotiahne jeho
      // box v sekcii Kovanie (scroll + kratke prisvietenie). Ked box neexistuje
      // (sekcia este nema data), ostava povodne spravanie z UI-B2 — popis
      // polozky v statuse; nikdy sa nemlci.
      var hm = closestClass(ev.target, 'hwmk');
      if (hm){ nxHwMarkPick(hm.getAttribute('data-owner') || '', hm.getAttribute('data-tip') || ''); return; }
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
      // UI-C4 (Codex #179 P2): DRUHY smer prepojenia box <-> znacka — hover nad
      // znackou prisvieti aj box jej vlastnika. Nahlad o konvencii boxov nevie,
      // preto sa pyta `hwHoverByOwner` (jedno miesto pravdy).
      var m = closestClass(ev.target, 'hwmk');
      if (m) hwHoverByOwner(m.getAttribute('data-owner') || '');
    });
    svg.addEventListener('mouseout', function(ev){
      var m = closestClass(ev.target, 'hwmk');
      if (m && !(ev.relatedTarget && closestClass(ev.relatedTarget, 'hwmk') === m)) hwClearHover();
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
    // UI-B1 (Codex #168 P2): skupiny zon ziju v sektore Nastavenia — klik na zonu
    // v nahlade ich musi aj UKAZAT (zbaleny sektor by ich schoval). Rozbaluje sa
    // LEN na tejto pouzivatelskej ceste, nie pri kazdom serverovom refreshi.
    // UI-C2: cielom je hlavicka vybranej zony v skupine Delenie zony.
    if (typeof nxRevealTarget === 'function') nxRevealTarget(el('zoneActive'));
    renderPreview();
    if (selectedCabId && window.sketchup && sketchup.select_zone)
      sketchup.select_zone(nxZonePayload({ zone_id: activeZoneId }));
  }

  // --- drag priecky (UI-C2: magnet N20 + pointer capture) --------------------
  // MAGNET: priecka sa prilepi na 1/4 · 1/2 · 3/4 zony. Pocita to TA ISTA
  // zdielana funkcia (`nxZoneSnapCum`), aku pouzivaju zlomky pola „Prva zona",
  // takze cislo v poli a poloha priecky sa nikdy nerozidu. Prah je v PIXELOCH
  // prepocitany aktualnym zoomom — pri priblizenom pohlade musi ist doladit na
  // desatiny milimetra, inak by magnet presnu pracu znemoznil.
  // ALT drzany pocas tahania magnet VYPINA (rozhoduje sa PRED aplikaciou).
  var DIV_SNAP_PX = 8;
  function startDivDrag(ev, d, svg){
    ev.preventDefault();
    endDivListeners();
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
                  count: parent.split.count,
                  sizes: parent.split.sizes.slice(), startX: ev.clientX, startY: ev.clientY,
                  svg: svg, pid: (ev.pointerId != null ? ev.pointerId : null) };
    // POINTER CAPTURE: `mouseup` mimo okna panela (CEF, pretiahnutie cez okraj)
    // sa do dokumentu uz nedostane — drag potom ostal visiet a neulozeny stav
    // sa stratil.
    //
    // Codex #177 P1: capture aj listenery patria SVG kontajneru, NIE uzlu
    // priecky. `onDivDrag` volá `renderPreview()`, ktorý prekresli obsah SVG —
    // tahany `.divh` uzol pri prvom pohybe ZANIKNE, capture s nim padne a
    // `pointerup` uz nema kam prist (drag by ostal visiet a layout by sa do
    // Ruby nikdy neulozil). SVG prekreslenie prezije.
    if (svg.setPointerCapture && dragState.pid != null){
      try { svg.setPointerCapture(dragState.pid); } catch (e) { /* starsi CEF — ostava fallback nizsie */ }
      svg.addEventListener('pointermove', onDivDrag);
      svg.addEventListener('pointerup', endDivDrag);
      svg.addEventListener('pointercancel', endDivDrag);
      dragState.captured = true;
    } else {
      document.addEventListener('mousemove', onDivDrag);
      document.addEventListener('mouseup', endDivDrag);
    }
    window.addEventListener('blur', endDivDrag); // strata fokusu okna = koniec tahania
  }
  function endDivListeners(){
    document.removeEventListener('mousemove', onDivDrag);
    document.removeEventListener('mouseup', endDivDrag);
    window.removeEventListener('blur', endDivDrag);
    if (dragState && dragState.captured && dragState.svg){
      var s = dragState.svg;
      s.removeEventListener('pointermove', onDivDrag);
      s.removeEventListener('pointerup', endDivDrag);
      s.removeEventListener('pointercancel', endDivDrag);
      if (s.releasePointerCapture && dragState.pid != null){
        try { s.releasePointerCapture(dragState.pid); } catch (e) { /* uz uvolnene */ }
      }
    }
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

    // MAGNET nad SVETLYM suctom poli 0..i (to je presne to, co zdielana
    // geometria pozna). Alt ho vypina — rozhodne sa PRED aplikaciou.
    var before = 0; for (var k = 0; k < i; k++) before += sizes[k];
    var tolMm = (ev.altKey || !(scale > 0)) ? 0 : (DIV_SNAP_PX / scale);
    var snapped = nxZoneSnapCum(dragState.span, dragState.count, dragState.t, i, before + newI, tolMm);
    var magnet = Math.abs((before + newI) - snapped) > 1e-9;
    if (magnet){ var shift = snapped - (before + newI); newI += shift; newN -= shift; }

    if (newI < MINF){ newN -= (MINF-newI); newI = MINF; }
    if (newN < MINF){ newI -= (MINF-newN); newN = MINF; }
    sizes[i] = newI; sizes[i+1] = newN;
    // uloz do currentZoneTree (docasne, ako size hodnoty; mm Float 0,01)
    var tree = sanitizeTree(currentZoneTree);
    var node = navTree(tree, pathOf(dragState.zid));
    if (node && node.split){ node.split.cuts[i] = { size: nxRound2(newI), locked: node.split.cuts[i].locked };
                             node.split.cuts[i+1] = { size: nxRound2(newN), locked: node.split.cuts[i+1].locked }; }
    currentZoneTree = tree;
    renderPreview();
    NX.setStatus('Pole '+(i+1)+': '+mmLabel(nxRound2(newI))+' mm · pole '+(i+2)+': '+mmLabel(nxRound2(newN)) +
                 ' mm' + (magnet ? ' · magnet' : ''), false);
  }
  function endDivDrag(ev){
    if (!dragState){ endDivListeners(); return; }
    var i = dragState.idx, zid = dragState.zid;
    endDivListeners();
    // fix #5: posli kompletny layout (vsetky polia uz maju explicitne sizes zo freeze + dragu)
    if (selectedCabId) pushFieldCuts(zid, i);
    // Codex #175 P2: v navrhu tah priecky meni plochy polic — odhad musi ist s nimi.
    else if (typeof nxDraftChanged === 'function') nxDraftChanged();
    dragState = null;
    if (typeof refreshZoneUI === 'function') refreshZoneUI(); // polia a „Prva zona" nesu novy rozmer
  }

  // Node testy (tests/js/test_uib2_nahlad.js) — LEN ciste jadro projekcii
  // (vyber projekcie, stav chipov, odvodenie znaciek kovania a kot). V CEF je
  // module undefined a DOM cast bezi normalne (vzor shell.js / usage.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { NXLayers: NXLayers, cabTabPreview: cabTabPreview,
                       nxHwMarks: nxHwMarks, nxHwSummary: nxHwSummary, nxSlideGeom: nxSlideGeom,
                       nxFrontDims: nxFrontDims, nxZoneSpans: nxZoneSpans,
                       pvDepthDimZ: pvDepthDimZ, pvSceneTopZ: pvSceneTopZ,
                       // UI-C1b: draft ciel, odhad navrhu a doskova projekcia
                       nxFrontsResolve: nxFrontsResolve, nxDraftStats: nxDraftStats,
                       nxGrainArrows: nxGrainArrows, pvBoardScene: pvBoardScene,
                       nxFrontsExtent: nxFrontsExtent,
                       // KOV-A1 (P2-C): popis typu cela v nahlade
                       frontTypeDesc: frontTypeDesc, PV_FRONT_TYPE_DESC: PV_FRONT_TYPE_DESC,
                       // D-115 (tests/js/test_kova2b_smer_overlay.js) — kresba symbolov
                       // otvarania; test ju vola nad hotovymi stlpcami kridiel
                       drawFrontSymbols: drawFrontSymbols };
  }

