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
  // S1-E: SLOT UMYVACKY. Telo spotrebica je REFERENCIA, nie dielec — kresli sa
  // PRERUSOVANE vo vyberovej (firemnej) farbe, presne ako ghost zony. Pasmo
  // „vyplň hore" je JANTAROVE: nie je to chyba, je to prace, ktora este caka
  // (nizky korpus alebo doska) — zrkadlo tokenu --nx-warn-fg.
  var PV_SLOT_FILL = '#e65100';     // --nx-warn-fg (jantar: kolizia niky, pasmo pripustnej hrany)
  // Rozmery generickeho tela per trieda — ZRKADLO Ruby `Construction::DW_CLASSES`
  // (guard test `tests/pure/test_s1e_slot.rb` ich porovnava). Nahlad ich
  // potrebuje aj vo VKLADANI, kde ziadny serverovy payload neexistuje.
  var PV_DW_BODY = { 600: { w: 598, d: 555 }, 450: { w: 448, d: 550 } };
  // Zakladna tela (nohy a sokel spotrebica) — zrkadlo `Construction::DW_BASE_*`.
  var PV_DW_BASE_H = 200, PV_DW_BASE_SIDE = 20;
  // S1-F: KONTROLNA GEOMETRIA CHLADNICKY. Box niky je referencia — prerusovane
  // vo firemnej teal (rovnako ako telo slotu); ked sa nezmesti, prekresli sa
  // jantarom (`PV_SLOT_FILL` = --nx-warn-fg), lebo je to prave to, o com hovori
  // Kontrola. PASMO PRIPUSTNEJ HRANY ciel je jantarovy prizvuk vlavo od boxu
  // (mockup R12) a sirku gutteru potrebuje aj scena, inak ho fit oreze.
  var PV_APPL_GUTTER = 22;
  // ROH-B2 (mockup C): ROHOVA ZOSTAVA. Dielce korpusu (blenda, rohova vystuha)
  // maju tie iste farby ako dielce v `drawCarcass`, CR listy farbu ciel;
  // NEZMESTENA zostava sa kresli cervenou chybneho pola (zrkadlo tokenov
  // --nx-danger-line / --nx-err-bg). Slepa cast = blenda TLMENA a SRAFOVANA.
  var PV_PART_FILL = '#e5d8b8', PV_PART_STROKE = '#c9b784';
  var PV_DANGER = '#e53935';        // --nx-danger-line
  var PV_DANGER_BG = '#fdecea';     // --nx-err-bg
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
  // ===== ROH-A2: CELNY OTVOR (kde sa cela kreslia) ==========================
  // Ciste (Node testy). Rohova ma cela LEN v dverovej casti — otvor `{x0, w}`
  // posiela SERVER (`front_opening` v payloade, `opening` v preflighte); panel
  // si ho neodvodzuje. Ostatne typy maju otvor = celu sirku a serverovu
  // hodnotu ZAMERNE ignoruju: ich kresba sa nesmie pohnut ani o pixel
  // (parita v tests/js/test_roha2_vkladanie.js). null = rohova, ktorej otvor
  // este nepozname (prvy preflight bezi) — cela sa vtedy NEKRESLIA, lebo
  // dvere cez celu sirku by boli klamstvo.
  // H12c: „otvor = dverova cast" je vlastnost typu (`front_opening` registra).
  function nxFrontOpeningFor(type, W, op){
    if (!NXTypes.has(type, 'front_opening', 'corner_door')) return { x0: 0, w: W };
    if (!op || typeof op !== 'object') return null;
    var x0 = nxNumOr(op.x0, NaN), w = nxNumOr(op.w, NaN);
    if (isNaN(x0) || !(w > 0)) return null;
    return { x0: x0, w: w };
  }
  // Otvor pre AKTUALNY typ nad posledným otvorom servera. `W` je sirka, s akou
  // kresli volajuci (kazdy si ju cita po svojom — `|| 600` vs `|| 0`), takze
  // ostatne typy dostanu presne jeho dnesne cislo.
  function pvFrontOpening(W){
    var t = (typeof getType === 'function') ? getType() : NXTypes.FALLBACK;
    return nxFrontOpeningFor(t, W, (typeof frontOpening !== 'undefined') ? frontOpening : null);
  }
  // ROH-A2 (predrecenzia P3): zdroj slotov smeru pre znacky zavesov.
  function pvHingeSlots(){
    if (typeof frontSlotsSaved !== 'undefined' && frontSlotsSaved) return frontSlotsSaved;
    return (typeof frontSlots !== 'undefined') ? frontSlots : null;
  }
  // D-07: rozsah ciel v modelovych mm (presahy mozu ist mimo obrys korpusu).
  // ROH-A2: bocne okraje sa merajú od OTVORU (pri ostatnych typoch 0…W).
  // Rozsah dielcov rohovej zostavy (server posiela x0/x1/z0/z1 v mm) pre scenu —
  // `cr_front` moze siahat pod korpus. Ciste (Node testy). Bez zostavy null.
  function pvCornerExtent(){
    var cp = (typeof pvCornerPreview === 'function') ? pvCornerPreview() : null;
    if (!cp) return null;
    var e = null;
    cp.parts.forEach(function(p){
      if (!p) return;
      var x0 = nxNumOr(p.x0, NaN), x1 = nxNumOr(p.x1, NaN), z0 = nxNumOr(p.z0, NaN), z1 = nxNumOr(p.z1, NaN);
      if (isNaN(x0) || isNaN(x1) || isNaN(z0) || isNaN(z1)) return;
      if (!e) e = { minX: x0, maxX: x1, minZ: z0, maxZ: z1 };
      e.minX = Math.min(e.minX, x0); e.maxX = Math.max(e.maxX, x1);
      e.minZ = Math.min(e.minZ, z0); e.maxZ = Math.max(e.maxZ, z1);
    });
    return e;
  }
  function frontsExtent(){
    var items = frontItems; if (!items || !items.length) return null;
    var W = numv('width')||600, H = numv('height')||720;
    var gl = nxNumOr(numv('fr_gap_left'), 2), gr = nxNumOr(numv('fr_gap_right'), 2);
    var op = pvFrontOpening(W);
    if (!op) return null;
    var e = { minX: Math.min(0, op.x0 + gl), maxX: Math.max(W, op.x0 + op.w - gr), minZ: 0, maxZ: H };
    items.forEach(function(it){
      e.minZ = Math.min(e.minZ, it.z);
      e.maxZ = Math.max(e.maxZ, it.z + it.height);
    });
    return e;
  }
  // ===== H6c (D-02, O10 A / O11 A): KOTY V PIXELOCH ============================
  // Kresba (viewBox) ostava v mm modelu — tahanie priecky, vyber zony a klik na
  // znacku kovania sa nemenia. Kazdy TEXT a kazda CIARA kot ma ale stalu velkost
  // NA OBRAZOVKE: font = DIM_FONT_PX / s (s = px na mm prave kreslenej kresby,
  // `pvS`), ciara 1 px (`non-scaling-stroke`). Rezerva okraja na koty je v px
  // (`nxDimScene`), nie v mm — inak by kota pri vysokej skrinke vysla mimo okna.
  var DIM_FONT_PX = 11;      // koty, popisy cel, zon, pasiem
  var DIM_GAP_FONT_PX = 10;  // cisla medzier medzi celami
  var DIM_TICK_PX = 4;       // pol-dlzka koncovej ciarky
  var DIM_OFF_PX = 18;       // vodorovna kota pod najnizsim prvkom kresby
  var DIM_OFF_V_PX = 20;     // zvisla kota vedla obrysu
  var DIM_TXT_PX = 5;        // text NAD vodorovnou ciarou
  var DIM_TXT_V_PX = 9;      // stred textu vedla zvislej ciary
  var DIM_ROW_PX = 18;       // druhy rad kot (rohova: sirka pod dverovou castou)
  var DIM_DEPTH_OFF_PX = 12; // kota hlbky nad skosenim
  var PV_PAD_PX = 6;         // vzduch okolo kresby
  var DIM_CHAR_W = 0.56;     // odhad sirky znaku: 0,56 · font (parita s mockupom, D10)
  var PV_REF_RECT = { w: 404, h: 323 }; // nahlad pri okne 850 px (D8) — ked #preview nema rozmer
  var pvS = 1;               // px na mm AKTUALNEJ kresby (nastavuje applyViewBox)
  var pvBaseZ = 0;           // najnizsi kresleny bod projekcie (mm) — pod nim visia vodorovne koty
  var pvLastRect = null;     // posledny REALNY rozmer #preview, s ktorym sa kreslilo
  function pvU(px){ return px / (pvS > 0 ? pvS : 1); }
  function pvN(v){ return Math.round(v * 100) / 100; }
  function pvN3(v){ return Math.round(v * 1000) / 1000; }
  function pvTextW(txt, fontPx){ return DIM_CHAR_W * fontPx * String(txt).length; }
  // Kolko px ma kota dlzky `lenPx`: prvy popis zo zoznamu (dlhy -> kratky), ktory
  // sa zmesti (s rezervou 4 px); '' = nezmesti sa ziadny. Ciste (Node testy).
  function pvFitLabel(lenPx, labels, fontPx){
    var list = Array.isArray(labels) ? labels : [labels];
    for (var i = 0; i < list.length; i++){
      if (pvTextW(list[i], fontPx || DIM_FONT_PX) <= lenPx - 4) return String(list[i]);
    }
    return '';
  }
  // Popis cela v troch stupnoch (dlhy -> „F1 · 760" -> „F1") podla sirky panelu
  // v px; panel nizsi ako 12 px popis nema (''). Ciste (Node testy).
  function pvFrontLabel(labels, widthPx, heightPx){
    if (!(heightPx >= 12)) return '';
    return pvFitLabel(widthPx, labels, DIM_FONT_PX) || String(labels[labels.length - 1]);
  }
  // Rozmer #preview v px; bez rozmeru (zbaleny sektor, skryty panel, Node) sa
  // kresli na referencii 404 x 323 a `real` je false.
  function pvRect(){
    var svg = (typeof el === 'function') ? el('preview') : null;
    if (svg && typeof svg.getBoundingClientRect === 'function'){
      var b = svg.getBoundingClientRect();
      if (b && b.width >= 50 && b.height >= 50) return { w: b.width, h: b.height, real: true };
    }
    return { w: PV_REF_RECT.w, h: PV_REF_RECT.h, real: false };
  }
  // Ciste (Node testy): scena z OBSAHU v mm (`content` = {minX, maxX, minZ, maxZ})
  // a okrajov v px (`margins` = {l, r, t, b}) pre okno `rect` = {w, h} px. Mierka
  // `s` je najvacsia, pri ktorej sa obsah AJ okraje zmestia; scena = obsah
  // rozsireny o (okraj + vzduch) / s na kazdej strane, takze pri `meet` ma
  // vysledny viewBox presne mierku `s`. Neplatny vstup scenu nezrusi (s = 0,05).
  function nxDimScene(content, margins, rect){
    var c = content || {}, m = margins || {};
    var minX = nxNumOr(c.minX, 0), minZ = nxNumOr(c.minZ, 0);
    var cw = Math.max(1, nxNumOr(c.maxX, 1) - minX), ch = Math.max(1, nxNumOr(c.maxZ, 1) - minZ);
    var rw = (rect && rect.w > 0) ? rect.w : PV_REF_RECT.w, rh = (rect && rect.h > 0) ? rect.h : PV_REF_RECT.h;
    var l = Math.max(0, nxNumOr(m.l, 0)), r = Math.max(0, nxNumOr(m.r, 0));
    var t = Math.max(0, nxNumOr(m.t, 0)), b = Math.max(0, nxNumOr(m.b, 0));
    var P = PV_PAD_PX;
    var s = Math.min((rw - 2 * P - l - r) / cw, (rh - 2 * P - t - b) / ch);
    if (!isFinite(s) || s <= 0) s = 0.05;
    return { x0: minX - (l + P) / s, x1: minX + cw + (r + P) / s,
             z0: minZ - (b + P) / s, z1: minZ + ch + (t + P) / s,
             w: cw + (l + r + 2 * P) / s, h: ch + (t + b + 2 * P) / s, s: s };
  }
  // Naznak hlbky v korpusovej projekcii (skosena horna plocha, vzor mockupu).
  // Nie je to mierka hlbky — je to citatelny NAZNAK; presnu hodnotu nesie kota.
  function pvDepthSkew(){
    var D = numv('depth') || 0;
    return D > 0 ? Math.min(Math.max(D * 0.18, 24), 130) : 0;
  }
  // Okraje (px) korpusovej projekcie a vkladania: vlavo koty sokla/tela, vpravo
  // vyska, dole sirka (rohova: o rad nizsie), hore kota hlbky nad skosenim
  // (ciara 12 + text 5 + vyska pisma 11 + vzduch). Ciste (Node testy).
  function pvCabMargins(sk, corner){
    return { l: 46, r: 40, t: sk > 0 ? 30 : 8, b: 28 + (corner ? DIM_ROW_PX : 0) };
  }
  // UI-C1b: scena vkladanej DOSKY je samotna doska (dlzka x sirka) + okraj na
  // koty. Vlastna funkcia — korpusove polia (#width/#height) v tomto rezime nic
  // neznamenaju. Ciste (Node testy): rozmery dnu, obdlznik sceny von (v suradniciach
  // SVG: x vodorovne, y zhora nadol, dlzka vodorovne). Vpravo (kota sirky) a dole
  // (kota dlzky) musi ostat miesto na ciaru aj text — inak by ich fit orezal.
  function pvBoardScene(L, Wd, rect){
    var l = Math.max(1, nxNumOr(L, 0)), w = Math.max(1, nxNumOr(Wd, 0));
    var sc = nxDimScene({ minX: 0, maxX: l, minZ: 0, maxZ: w }, { l: 0, r: 40, t: 0, b: 28 }, rect);
    return { x: sc.x0, y: w - sc.z1, w: sc.w, h: sc.h, s: sc.s, baseZ: 0 };
  }
  // Rozsah DRAFT ciel vkladanej sablony v mm modelu (Codex #175 P2). Zrkadlo
  // `frontsExtent`, ale nad draftom — vo vkladani `frontItems` neexistuje.
  // null = kresli sa doska alebo sablona ziadne cela nema. Ciste jadro je
  // `nxFrontsExtent` (Node testy).
  function insertFrontsExtent(){
    if (previewMode !== 'insert' || pvInsertBoard()) return null;
    var W = numv('width') || 0;
    var op = pvFrontOpening(W);
    if (!op) return null;
    return nxFrontsExtent(pvInsertFronts(), W, numv('height') || 0,
                          numv('fr_gap_left'), numv('fr_gap_right'), op.x0, op.w);
  }
  // Ciste (Node testy): obalka korpus ∪ cela. Zaporny bocny okraj = cela sirsie
  // nez korpus; zaporne medzery hore/dole = cela nad/pod obrysom.
  // ROH-A2: `x0`/`ow` = celny otvor (rohova: dverova cast); bez nich cela sirka.
  function nxFrontsExtent(items, W, H, gapLeft, gapRight, x0, ow){
    if (!items || !items.length) return null;
    var gl = nxNumOr(gapLeft, 2), gr = nxNumOr(gapRight, gl), w = nxNumOr(W, 0), h = nxNumOr(H, 0);
    var ox = nxNumOr(x0, 0), owv = nxNumOr(ow, w);
    var e = { minX: Math.min(0, ox + gl), maxX: Math.max(w, ox + owv - gr), minZ: 0, maxZ: h };
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
  // PR #381 (Codex kolo 1, P2): OBALKA SLOTU PRE SCENU — telo sa nikdy
  // nedeformuje podla slotu, takze pri uzkom slote TRCI do stran a pri
  // prehnanej vyske tela aj nad linku. Prave vtedy, ked Kontrola hlasi
  // `dw_body_fit` / `dw_height_fit`, by fit telo OREZAL a pouzivatel by na
  // nahlade nevidel to, o com mu semafor hovori. Vracia rozsah v mm sceny
  // alebo null (nie je to slot). Ciste (Node testy).
  function nxSlotExtent(sl, W){
    if (!sl) return null;
    var bw = sl.bodyW;
    var bx = (W - bw) / 2;
    return { minX: Math.min(0, bx), maxX: Math.max(W, bx + bw),
             minZ: 0, maxZ: Math.max(sl.bodyH, sl.fb + sl.fh) };
  }
  // S1-F (Astra FIX F11): OBALKA VSETKYCH REFERENCII — tela slotu AJ boxov
  // niky. Box niky sa NIKDY nedeformuje podla skrinky, takze pri uzkej alebo
  // nizkej skrinke TRCI (a prave vtedy o nom Kontrola hovori) — scena mu musi
  // nechat miesto vratane jantaroveho pasma hrany vlavo. Ciste (Node testy).
  function nxRefExtent(sl, appl, W){
    var e = nxSlotExtent(sl, W);
    var list = appl || [];
    list.forEach(function(a){
      if (!a || !a.box) return;
      var b = a.box, x0 = nxNumOr(b.x, 0), z0 = nxNumOr(b.z, 0);
      var x1 = x0 + nxNumOr(b.w, 0), z1 = z0 + nxNumOr(b.h, 0);
      // Pasmo hrany a jeho popisky lezia VLAVO od boxu.
      var gx = (a.split ? x0 - PV_APPL_GUTTER : x0);
      var n = { minX: Math.min(0, gx), maxX: Math.max(W, x1),
                minZ: Math.min(0, z0), maxZ: z1 };
      e = e ? { minX: Math.min(e.minX, n.minX), maxX: Math.max(e.maxX, n.maxX),
                minZ: Math.min(e.minZ, n.minZ), maxZ: Math.max(e.maxZ, n.maxZ) } : n;
    });
    return e;
  }

  // H6c (R1): scena = OBSAH v mm (korpus ∪ cela ∪ referencie) + okraje na koty
  // v PX (`nxDimScene`) pre aktualny rozmer #preview (`pvRect`). Vracia viewBox
  // v suradniciach SVG (rx = PV_PAD + x, ry = PV_PAD + H − z) a `baseZ` — najnizsi
  // kresleny bod (D11: vodorovna kota visi pod nim, nie na pevnom −26 mm).
  function sceneSize(){
    var rect = pvRect();
    if (pvInsertBoard()) return pvBoardScene(numv('ib_length'), numv('ib_width'), rect);
    var W = numv('width')||600, H = numv('height')||720;
    var solid = (previewMode === 'cab' || previewMode === 'hw');
    var e = solid ? null : frontsExtent();
    var minX = e ? e.minX : 0, maxX = e ? e.maxX : W;
    var minZ = e ? e.minZ : 0, maxZ = e ? e.maxZ : H;
    var mg = { l: 0, r: 0, t: 0, b: 0 };
    function union(x){
      if (!x) return;
      minX = Math.min(minX, x.minX); maxX = Math.max(maxX, x.maxX);
      minZ = Math.min(minZ, x.minZ); maxZ = Math.max(maxZ, x.maxZ);
    }
    // Rohova zostava (`cr_front` moze siahat pod korpus) patri do obsahu vsade, kde sa kresli.
    var ce = pvCornerExtent();
    if (previewMode === 'cab' || previewMode === 'insert'){
      // D-11: vlavo koty sokla/tela, vpravo vyska, dole sirka, hore naznak hlbky
      // (UI-C1b: vkladanie kresli sablonu tym istym celnym rezom + kotami)
      var sk = pvDepthSkew();
      minX = 0; maxX = W + sk; minZ = 0; maxZ = H + sk;
      mg = pvCabMargins(sk, !!ce);
      union(ce);
      // Codex #175 P2: vo VKLADANI sa cela naozaj kreslia, a s odomknutym limitom
      // presahov (D-22) mozu sablonove cela vytrcat MIMO obrys korpusu — scena sa
      // roztiahne o ich skutocny rozsah (frontsExtent cita `frontItems`, ktore su
      // tu null — pasca FIX 11).
      union(insertFrontsExtent());
      // S1-E: celo slotu SMIE presahovat vysku linky — scena mu musi nechat
      // miesto, inak by fit odrezal jeho hornu hranu.
      var sl = pvSlot();
      if (sl) maxZ = Math.max(maxZ, sl.fb + sl.fh);
    } else if (previewMode === 'fronts'){
      union(ce);
      mg = { l: 34, r: 40, t: 8, b: 28 }; // cisla medzier vlavo, koty vysok vpravo, sirka dole
    } else if (previewMode === 'zones'){
      // koty sirok zon pod korpusom — len ked je co porovnavat (1 < stlpcov <= 8)
      var sp = [];
      try { sp = nxZoneSpans(computeZones()); } catch (ex) { sp = []; }
      if (sp.length > 1 && sp.length <= 8) mg.b = 28;
    } else if (previewMode === 'hw'){
      // H6b (O9): suhrn kovania je v liste sektora, nie v kresbe — okraj dole je
      // len to, co sa KRESLI: nohy pod korpusom (pri sokli stoja v sokli, okraj 0).
      minZ = Math.min(minZ, nxHwLowestZ(hwItems, nxCabFloorHeight()));
      // Cela (ghost vrstva) a rohova zostava mozu siahat mimo korpus (okraj dole −20,
      // `cr_front`) — ich rozsah patri do sceny.
      union(frontsExtent()); union(ce);
    }
    // PR #381 (P2): telo slotu sa do sceny priklada v KAZDOM kontexte —
    // od opravy projekcii ho vidno aj v Celach a v Kovani. S1-F: box niky sa
    // kresli LEN v kontexte Korpus, takze sa aj do sceny priklada len tam
    // (inak by Cela a Kovanie mali prazdny okraj po neviditelnom boxe).
    union(nxRefExtent(pvSlot(), pvApplianceRefs(), W));
    var sc = nxDimScene({ minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ }, mg, rect);
    return { x: PV_PAD + sc.x0, y: PV_PAD + H - sc.z1, w: sc.w, h: sc.h, s: sc.s, baseZ: minZ };
  }
  function fitPreview(){ pvUserView = false; pvView = null; renderPreview(); }
  // Nastavi viewBox (fit alebo pohlad pouzivatela) A mierku kresby `pvS` — tu sa
  // ROZHODUJE, kolko mm je 11 px (R1.4): mierka sa berie z AKTUALNEHO viewBoxu,
  // takze po zoome je ina nez pri fite.
  function applyViewBox(svg){
    var base = sceneSize();
    if (!pvUserView || !pvView) pvView = { x: base.x, y: base.y, w: base.w, h: base.h };
    var rect = pvRect();
    var s = Math.min(rect.w / pvView.w, rect.h / pvView.h);
    pvS = (isFinite(s) && s > 0) ? s : 1;
    pvBaseZ = base.baseZ;
    pvLastRect = rect.real ? { w: rect.w, h: rect.h } : null;
    svg.setAttribute('viewBox', pvView.x + ' ' + pvView.y + ' ' + pvView.w + ' ' + pvView.h);
  }
  // R6: prekreslenie kot po zoome a po zmene velkosti okna — najviac raz za snimku
  // (rAF; bez neho setTimeout 16). Pocas tahania priecky sa nenaplanuje (tahanie
  // si kresli samo). Hover zvyraznenie po prekresleni zanikne (dnesne spravanie).
  var pvRenderPending = false;
  function pvScheduleRender(){
    if (pvRenderPending || dragState) return;
    pvRenderPending = true;
    var run = function(){ pvRenderPending = false; if (!dragState) renderPreview(); };
    if (typeof requestAnimationFrame === 'function') requestAnimationFrame(run);
    else setTimeout(run, 16);
  }
  // Zmena velkosti #preview (okno, rozbalenie sektora): prekresli len ked sa sirka
  // alebo vyska zmenila o >= 1 px a obe su >= 50 (zbaleny sektor = 0 → ignoruje sa).
  function pvOnResize(w, h){
    if (!(w >= 50 && h >= 50)) return false;
    if (pvLastRect && Math.abs(w - pvLastRect.w) < 1 && Math.abs(h - pvLastRect.h) < 1) return false;
    pvScheduleRender();
    return true;
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
  // S1-E: udaje SLOTU z formulara (vklad aj oznaceny slot idu tou istou
  // cestou ako zvysok nahladu — `numv`). nil = nie je to slot.
  function pvSlot(){
    if (typeof getType !== 'function' || NXTypes.carcass(getType())) return null;
    var cls = parseInt(val('dw_class'), 10);
    var b = PV_DW_BODY[cls] || PV_DW_BODY[600];
    var fb = numv('dw_front_bottom') || 0;
    // D-139: vyska cela je ODVODENA (linka − sokel − medzera hore) — ta ista
    // `nxSlotFrontEval` ako krizova kontrola aj server. Zaporne = nekresli sa.
    var fh = (typeof nxSlotFrontEval === 'function')
      ? nxSlotFrontEval(numv('height') || 0, fb, nxNumOr(numv('fr_gap_top'), 2)).value : 0;
    return { cls: PV_DW_BODY[cls] ? cls : 600, bodyW: b.w, bodyD: b.d,
             bodyH: numv('dw_body_height') || 0,
             fb: fb, fh: fh > 0 ? fh : 0 };
  }

  // D-139 (Astra B2 FIX 4): cela SLOTU pre nahlad — jedno pevne celo na
  // sokli s odvodenou vyskou. Vseobecny resolver by ho polozil na z = 0 so
  // STAROU vyskou z riadku (slot podstavec korpusu nema) — preto ma slot
  // vlastnu projekciu vo VSETKYCH cestach, kde nahlad nema cela zo servera.
  function nxSlotFrontItems(sl){
    var cfg = (typeof collectFronts === 'function') ? collectFronts() : null;
    var src = (cfg && cfg.items && cfg.items[0]) ? cfg.items[0] : {};
    var it = { id: src.id || 'F1', type: 'blind', mode: 'fixed', wings: 1,
               profile: src.profile || 'none',
               height: Math.round(sl.fh * 100) / 100, z: Math.round(sl.fb * 100) / 100 };
    if (Object.prototype.hasOwnProperty.call(src, 'profile_edge')) it.profile_edge = src.profile_edge;
    return [it];
  }

  // S1-F: KONTROLNA GEOMETRIA zo SERVERA (`preview.appliances[]`). Panel z nej
  // NIC nepocita — box, pasma aj pasmo pripustnej hrany prichadzaju hotove
  // v mm suradniciach korpusu (z od podlahy). Kresli sa LEN v kontexte Korpus.
  function pvApplianceRefs(){
    if (previewMode !== 'cab') return [];
    return (typeof applPreview !== 'undefined' && applPreview) ? applPreview : [];
  }

  // ===== ROH-B2 (mockup C): KRESBA ROHOVEJ ZOSTAVY ==========================
  // Geometriu posiela SERVER (`cornerPreview` v core.js — payload oznacenej
  // rohovej a kazda odpoved preflightu so zivymi polami); panel NIC nepocita,
  // len kresli obdlzniky a koty. Iny typ = null, teda jeho kresba sa nemeni.
  function pvCornerPreview(){
    if (typeof getType !== 'function' || !NXTypes.corner(getType())) return null;
    var cp = (typeof cornerPreview !== 'undefined') ? cornerPreview : null;
    return (cp && typeof cp === 'object' && Array.isArray(cp.parts)) ? cp : null;
  }
  // Ciste (Node testy): odhad navrhu + dielce zostavy (pocet a plocha zo
  // servera, `stats`). Bez kresby = odhad bez zmeny.
  function nxCornerStatsAdd(st, cp){
    var s = st || { count: 0, area: 0 };
    var x = (cp && cp.stats && typeof cp.stats === 'object') ? cp.stats : null;
    if (!x) return s;
    return { count: nxNumOr(s.count, 0) + nxNumOr(x.count, 0),
             area: Math.round((nxNumOr(s.area, 0) + nxNumOr(x.area, 0)) * 1000) / 1000 };
  }
  // Ciste (Node testy): dielce zostavy do SVG v PORADI servera (blenda vzadu,
  // potom vystuha a CR listy). `mute` = kontext, ktoreho zakladom su cela alebo
  // kovanie — dielce KORPUSU (blenda, vystuha) su tlmene. Nezmestena zostava
  // (`fits === false`) ma vystuhu a CR listy cervene — vidno, kde nesedi.
  // Kazdy dielec nesie bublinu servera (`<title>`); klik nikam nevedie.
  function drawCornerAssembly(S, rx, ry, cp, mute){
    if (!cp || !Array.isArray(cp.parts) || !cp.parts.length) return;
    var bad = cp.fits === false;
    S.push('<defs><pattern id="pvCornerHatch" width="24" height="24" patternUnits="userSpaceOnUse"' +
           ' patternTransform="rotate(45)"><path d="M0 0V24" stroke="' + PV_PART_STROKE +
           '" stroke-width="3" opacity=".6"/></pattern></defs>');
    cp.parts.forEach(function(p){
      if (!p) return;
      var x0 = nxNumOr(p.x0, NaN), x1 = nxNumOr(p.x1, NaN), z0 = nxNumOr(p.z0, NaN), z1 = nxNumOr(p.z1, NaN);
      if (isNaN(x0) || isNaN(x1) || isNaN(z0) || isNaN(z1) || !(x1 > x0) || !(z1 > z0)) return;
      var at = 'x="' + rx(x0) + '" y="' + ry(z1) + '" width="' + (x1 - x0) + '" height="' + (z1 - z0) + '"';
      var body, korpus = false;
      if (p.role === 'corner_blind_panel'){
        korpus = true;
        body = '<rect ' + at + ' fill="' + PV_PART_FILL + '" fill-opacity=".35" stroke="' + PV_PART_STROKE + '"/>' +
               '<rect ' + at + ' fill="url(#pvCornerHatch)" stroke="none"/>';
      } else if (p.role === 'corner_rail'){
        korpus = true;
        body = '<rect ' + at + ' fill="' + (bad ? PV_DANGER_BG : PV_PART_FILL) + '" stroke="' +
               (bad ? PV_DANGER : PV_PART_STROKE) + '"' + (bad ? ' stroke-width="2"' : '') + '/>';
      } else if (p.role === 'cr_front'){
        body = '<rect ' + at + ' fill="' + PV_FRONT_DOOR + '" stroke="' + (bad ? PV_DANGER : PV_FRONT_STROKE) +
               '" stroke-width="' + (bad ? 2 : 1.5) + '"/>';
      } else {
        body = '<rect ' + at + ' fill="' + PV_FRONT_STROKE + '" stroke="' + (bad ? PV_DANGER : PV_FRONT_STROKE) + '"' +
               (bad ? ' stroke-width="2"' : '') + '/>';
      }
      S.push('<g class="pvcorner" data-role="' + esc(p.role || '') + '"' +
             ((mute && korpus) ? ' opacity=".55"' : '') + '><title>' + esc(p.title || '') + '</title>' +
             body + '</g>');
    });
  }
  // Koty dverovej casti a CR 1 (rozsahy zo servera, zrkadlene pri dverach
  // vpravo) tesne pod skrinkou (18 px) — sirka skrinky ide o DIM_ROW_PX nizsie.
  function drawCornerDims(S, rx, ry, cp){
    ((cp && cp.dims) || []).forEach(function(d){
      if (!d) return;
      var x0 = nxNumOr(d.x0, NaN), x1 = nxNumOr(d.x1, NaN);
      if (isNaN(x0) || isNaN(x1) || !(x1 > x0)) return;
      pvDimH(S, rx, ry, x0, x1, pvBaseZ, DIM_OFF_PX, [String(d.label == null ? '' : d.label)]);
    });
  }

  // S1-E: výška sokla KORPUSU. Horná skrinka ju nemá a slot umývačky tiež nie
  // (jeho „sokel" je spodná hrana ČELA a žije vo vlastnom poli) — bez tejto
  // jednej otázky by stará hodnota po prepnutí typu posunula kresbu čiel.
  function nxCabFloorHeight(){
    if (typeof getType !== 'function') return numv('floor_height') || 0;
    return NXTypes.onFloor(getType()) ? (numv('floor_height') || 0) : 0;
  }

  function pvGeom(){
    var gl = nxNumOr(numv('fr_gap_left'), 2), gr = nxNumOr(numv('fr_gap_right'), 2);
    var gap = 3; var gv = numv('fr_gap'); if (!isNaN(gv)) gap = gv;
    // ROH-A2: celny otvor — vsetky vrstvy kreslia cela od `fx0` v sirke `fw`
    // (ostatne typy 0…W, teda presne ako doteraz). Rohova bez znameho otvoru
    // cela nekresli vobec (`frontsPending`), kym nepride preflight.
    var W0 = numv('width')||600;
    var op = pvFrontOpening(W0);
    return pvSetbackDepths({ W: W0, H: numv('height')||720, t: numv('thickness')||18,
             fx0: op ? op.x0 : 0, fw: op ? op.w : 0, frontsPending: !op,
             // ROH-A2 (C8): sloty smeru zo servera — znacky zavesov sa kreslia
             // na strane pantov, nie natvrdo vlavo. Predrecenzia P3: ULOZENE
             // sloty oznacenej skrinky (patria ulozenemu kovaniu `hwItems`
             // a preflight ich nezhodi); bez nich sloty posledneho preflightu.
             slots: pvHingeSlots(),
             D: numv('depth')||0,
             fh: nxCabFloorHeight(),
             topNone: val('top_mode') === 'none',
             // UI-C1b: konstrukcne volby pre ODHAD kusov/plochy navrhu (nxDraftStats).
             topMode: val('top_mode'), backMode: val('back_mode'),
             bottomBetween: val('bottom_mode') === 'between_sides',
             railDepth: numv('rail_depth') || 100,
             gapLeft: gl, gapRight: gr, gap: gap,
             // UI-C1b: vo VKLADANI server resolved cela nema (skrinka este
             // neexistuje a `frontItems` je tu null — pasca Codex FIX 11),
             // preto ich dopocita cisty draft resolver z hodnot karty.
             fronts: op ? pvLiveFronts() : [] });
  }

  // KON-A · K1 (audit FIX 2 + NOTE 7): most pvGeom -> komin a zapustenie.
  // Hlbky dielcov pre ODHAD (`nxDraftStats`) z TYCH ISTYCH pomocnikov core.js
  // ako „Vnút. hĺbka" (nxBackStop / nxSideDepth / nxInteriorDepth). Pri X = Y
  // = 0 sa kluce NEPRIDAVAJU — odhad ostava presne dnesny (celkova D).
  function pvSetbackDepths(g){
    if (typeof currentCarcass !== 'function' || typeof nxBackSetback !== 'function') return g;
    var c = currentCarcass({ depth: g.D, thickness: g.t });
    g.backSetback = nxBackSetback(c);
    g.topFrontSetback = nxTopFrontSetback(c);
    // KON-B · K2 (audit NOTE 4): chrbat z list plati AJ bez komina — vyska
    // list pre odhad dvoch dielcov a vnutro R − t pre police a priecky sa
    // doplnia PRED skorym navratom pri X = Y = 0.
    if (typeof nxBackRails === 'function' && nxBackRails(c)){
      g.backRailH = nxBackRailHeight(c);
      g.innerD = nxInteriorDepth(c);
    }
    if (!(g.backSetback > 0) && !(g.topFrontSetback > 0)) return g;
    var r = nxBackStop(c);
    g.sideD = nxSideDepth(c);
    g.bottomD = r;
    g.topD = r - g.topFrontSetback;
    g.innerD = nxInteriorDepth(c);
    // PR #402 (Codex kolo 1 P2): pas vystuh v intervale Y … R builder OREZE
    // (`rail_geometry`) — odhad musi pocitat UCINNU hlbku, nie pozadovanu.
    if (c.top_mode === 'two_rails') g.railDepth = nxRailGeom(c).depth;
    // Nalozeny chrbat pri komine sedi MEDZI bokmi (w − 2t).
    if (g.backSetback > 0 && c.back_mode === 'overlay') g.backW = Math.max(0, g.W - 2 * g.t);
    return g;
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
  // D-119: spolocna projekcia oboch stran; gapSides len pre legacy volania.
  function nxFrontSide(g, key){ return nxNumOr(g[key], nxNumOr(g.gapSides, 2)); }
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
      ['direction','wing_directions','profile_edge'].forEach(function(key){
        if (it && Object.prototype.hasOwnProperty.call(it, key)) out[out.length - 1][key] = it[key];
      });
      z += h + gap;
    });
    return out;
  }
  function pvLiveFronts(){
    if (typeof frontDraft !== 'undefined' && frontDraft){
      var current = nxFrontDraftItems();
      if (current) return current;
      var sl = pvSlot();
      if (sl) return nxSlotFrontItems(sl);
      return nxFrontsResolve(collectFronts(), numv('height') || 0,
        nxCabFloorHeight());
    }
    return previewMode === 'insert' ? pvInsertFronts() : (frontItems || []);
  }
  // Len premietnutie fyzickej hrany vratenej serverom; `free` tu nema heuristiku.
  function nxProfilePanel(it, index, x, z, w, h){
    var edge = Array.isArray(it.profile_edges) ? it.profile_edges[index] :
      (Object.prototype.hasOwnProperty.call(it, 'profile_edge') ? it.profile_edge : 'top');
    var vertical = edge === 'left' || edge === 'right';
    var red = ['top','bottom','left','right'].indexOf(edge) >= 0 ? frontProfileReduction(it.profile) : 0;
    red = Math.min(red, vertical ? w : h);
    var p = { x:x, z:z, w:w, h:h, band:null };
    if (!(red > 0)) return p;
    if (vertical){ p.w -= red; if (edge === 'left') p.x += red; }
    else { p.h -= red; if (edge === 'bottom') p.z += red; }
    p.band = { x: edge === 'right' ? x + w - red : x,
      z: edge === 'top' ? z + h - red : z, w: vertical ? red : w, h: vertical ? h : red };
    return p;
  }
  // Draft ciel z aktualnej vkladacej karty (DOM -> cisty resolver). Doska cela
  // nema; mimo vkladania sa nevola vobec.
  function pvInsertFronts(){
    if (typeof collectFronts !== 'function') return [];
    if (typeof getInsertKind === 'function' && getInsertKind() === 'board') return [];
    var sl = pvSlot();
    if (sl) return nxSlotFrontItems(sl);
    return nxFrontsResolve(collectFronts(), numv('height') || 0,
                           nxCabFloorHeight());
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
    // KON-A (NOTE 7): hlbky dielcov pri komine/zapusteni dodava `pvSetbackDepths`;
    // chybajuci kluc = dnesny odhad (celkova D).
    var sideD = nxNumOr(g.sideD, D), botD = nxNumOr(g.bottomD, D), topD = nxNumOr(g.topD, D);
    var innD = nxNumOr(g.innerD, D), backW = nxNumOr(g.backW, W);
    add(2, bodyH * sideD);                                        // boky
    add(1, (g.bottomBetween ? Math.max(0, W - 2 * t) : W) * botD); // dno
    if (g.topMode === 'two_rails') add(2, Math.max(0, W - 2 * t) * nxNumOr(g.railDepth, 100));
    else if (g.topMode !== 'none') add(1, Math.max(0, W - 2 * t) * topD);
    // KON-B · K2: chrbat z list = 2 × (W − 2t) × H z korpusu namiesto dosky chrbta.
    if (g.backMode === 'rails') add(2, Math.max(0, W - 2 * t) * nxNumOr(g.backRailH, 100));
    else if (g.backMode && g.backMode !== 'none') add(1, backW * bodyH);
    (zones || []).forEach(function(z){
      if (!z) return;
      if (z.leaf){
        var sh = parseInt(z.shelves, 10) || 0;
        if (sh > 0) add(sh, nxNumOr(z.w, 0) * innD);
      } else if (z.split){
        var c = (parseInt(z.split.count, 10) || 1) - 1;
        if (c > 0) add(c, (z.split.axis === 'v' ? nxNumOr(z.h, 0) : nxNumOr(z.w, 0)) * innD);
      }
    });
    // ROH-A2: sirka ciel = celny OTVOR (rohova: dverova cast), inak cela sirka.
    var ow = Math.max(0, nxNumOr(g.fw, W) - nxFrontSide(g, 'gapLeft') - nxFrontSide(g, 'gapRight'));
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
    // PR #381 (P2 #5, dosledok): SLOT ZONY NEMA — `zone_tree` v jeho payloade
    // je len prazdny kanonicky strom, takze bez tejto otazky by chip „Zóny"
    // ostal aktivny a ghost vrstva by nad slotom kreslila FANTOMOVE zony
    // (pred opravou #5 ich skryl `return`, teraz by sa naozaj nakreslili).
    // Je to ta ista pravda, akou rail zhasina kontext Zóny (`NXShell.ctxLockedBy`
    // — typ bez vnutra `zones: none` z registra).
    return { zony: !!currentZoneTree && !pvSlot(),
             // Vo vkladani su cela DRAFT z karty (server ich este nema).
             cela: (previewMode === 'insert') ? pvInsertFronts().length > 0
                                              : !!(frontItems && frontItems.length),
             kovanie: !!(hwItems && hwItems.length),
             olep: !!partCard };
  }

  // ---- decentne koty v PX (H6c; vzor mockupu dimH/dimV — tenka ciara, tlmeny text) ----
  // Suradnice `x1, x2, z` su v mm modelu (kotovany prvok), odsadenie `dyPx`/`dxPx`,
  // znacky a pismo v PIXELOCH obrazovky (prevod `/ pvS` robi `pvU`). `labels` = dlhy
  // popis -> kratky (len cislo); vodorovna kota ostane vzdy s textom NAD ciarou
  // (D9), zvisla ho pri tesnom useku napise cislom VEDLA kota (R3).
  var PV_DIM_LINE = ' stroke-width="1" vector-effect="non-scaling-stroke"';
  function pvDimH(S, rx, ry, x1, x2, z, dyPx, labels, fontPx){
    var f = fontPx || DIM_FONT_PX, list = Array.isArray(labels) ? labels : [labels];
    var label = pvFitLabel(Math.abs(x2 - x1) * pvS, list, f) || list[list.length - 1];
    var y = ry(z) + pvU(dyPx), tk = pvU(DIM_TICK_PX), xa = rx(x1), xb = rx(x2);
    S.push('<g stroke="'+PV_DIM+'" stroke-width="1" vector-effect="non-scaling-stroke" fill="none" pointer-events="none">' +
      '<path'+PV_DIM_LINE+' d="M'+pvN3(xa)+' '+pvN3(y-tk)+'V'+pvN3(y+tk)+'M'+pvN3(xb)+' '+pvN3(y-tk)+'V'+pvN3(y+tk)+'"/>' +
      '<path'+PV_DIM_LINE+' d="M'+pvN3(xa)+' '+pvN3(y)+'H'+pvN3(xb)+'"/></g>' +
      '<text x="'+pvN3(rx((x1+x2)/2))+'" y="'+pvN3(y-pvU(DIM_TXT_PX))+'" font-size="'+pvN3(pvU(f))+'" fill="'+PV_DIM+
      '" text-anchor="middle" pointer-events="none">'+esc(label)+'</text>');
  }
  function pvDimV(S, rx, ry, x, dxPx, z1, z2, labels, fontPx){
    var f = fontPx || DIM_FONT_PX, list = Array.isArray(labels) ? labels : [labels];
    var xl = rx(x) + pvU(dxPx), tk = pvU(DIM_TICK_PX), ya = ry(z1), yb = ry(z2), ym = ry((z1+z2)/2);
    var g = '<g stroke="'+PV_DIM+'" stroke-width="1" vector-effect="non-scaling-stroke" fill="none" pointer-events="none">' +
      '<path'+PV_DIM_LINE+' d="M'+pvN3(xl-tk)+' '+pvN3(ya)+'H'+pvN3(xl+tk)+'M'+pvN3(xl-tk)+' '+pvN3(yb)+'H'+pvN3(xl+tk)+'"/>' +
      '<path'+PV_DIM_LINE+' d="M'+pvN3(xl)+' '+pvN3(ya)+'V'+pvN3(yb)+'"/></g>';
    var label = pvFitLabel(Math.abs(z2 - z1) * pvS, list, f);
    if (label){
      var xt = xl + pvU(DIM_TXT_V_PX);
      S.push(g + '<text x="'+pvN3(xt)+'" y="'+pvN3(ym)+'" font-size="'+pvN3(pvU(f))+'" fill="'+PV_DIM+
        '" text-anchor="middle" dominant-baseline="middle" pointer-events="none" transform="rotate(-90 '+
        pvN3(xt)+' '+pvN3(ym)+')">'+esc(label)+'</text>');
    } else {
      // usek je prilis kratky aj na cislo: cislo VODOROVNE vedla kota (vlavo od lavych, vpravo od pravych)
      var left = dxPx < 0;
      S.push(g + '<text x="'+pvN3(xl + (left ? -1 : 1) * pvU(4))+'" y="'+pvN3(ym)+'" font-size="'+pvN3(pvU(f))+'" fill="'+PV_DIM+
        '" text-anchor="'+(left ? 'end' : 'start')+'" dominant-baseline="middle" pointer-events="none">'+
        esc(list[list.length - 1])+'</text>');
    }
  }
  // Popis v px: `x`, `y` v suradniciach kresby, `fontPx` na obrazovke. `fill` je
  // volitelny (N26: medzery pri editacii svietia jantarovo) — bez neho plati
  // tlmena kotova farba. `extra` = dalsie SVG atributy (napr. dominant-baseline).
  function pvText(S, x, y, txt, fontPx, anchor, fill, extra){
    S.push('<text x="'+pvN3(x)+'" y="'+pvN3(y)+'" font-size="'+pvN3(pvU(fontPx || DIM_FONT_PX))+'" fill="'+(fill||PV_DIM)+
      '" text-anchor="'+(anchor||'middle')+'"'+(extra ? ' '+extra : '')+' pointer-events="none">'+esc(txt)+'</text>');
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

  // S1-E: PODKLAD SLOTU — telo so zakladnou (referencia, preto prerusovane)
  // a linia linky. Kresli sa v KAZDOM kontexte namiesto `drawCarcass`: slot
  // korpus nema, takze boky, dno a strop by boli vymyslene dielce.
  // PR #381 (Codex kolo 1, P2): rozdelene z povodneho `drawSlot` — detail
  // (celo, pasmo výplne, koty) patri LEN kontextu Korpus a vkladaniu; Cela
  // a Kovanie kreslia svoje projekcie standardnymi rendererMI nad TYMTO
  // podkladom (inak by zmizli koty ciel, znacky kovania aj hover).
  function drawSlotBase(S, rx, ry, g, sl){
    var W = g.W, H = g.H;
    var bw = Math.min(sl.bodyW, W * 3);
    var bx = (W - bw) / 2;
    var baseH = Math.min(PV_DW_BASE_H, sl.bodyH);
    var bodyTop = sl.bodyH;
    // LINIA LINKY — horna hrana susednych korpusov (naznak vlavo aj vpravo).
    S.push('<path d="M' + rx(-40) + ' ' + ry(H) + 'H' + rx(W + 40) + '" stroke="' + PV_DIM +
           '" stroke-width="2" fill="none"/>');
    // TELO (nad zakladnou) + ZAKLADNA (uzsia, odsadena) — obe prerusovane.
    if (bodyTop - baseH > 0){
      S.push('<rect x="' + rx(bx) + '" y="' + ry(bodyTop) + '" width="' + bw + '" height="' +
             (bodyTop - baseH) + '" fill="' + PV_FRONT_DOOR + '" fill-opacity=".35" stroke="' +
             PV_SELECT + '" stroke-width="2" stroke-dasharray="10 7"/>');
    }
    if (baseH > 0){
      S.push('<rect x="' + rx(bx + PV_DW_BASE_SIDE) + '" y="' + ry(baseH) + '" width="' +
             Math.max(bw - 2 * PV_DW_BASE_SIDE, 1) + '" height="' + baseH + '" fill="none" stroke="' +
             PV_SELECT + '" stroke-width="2" stroke-dasharray="6 5"/>');
    }
  }

  // S1-E: DETAIL SLOTU (mockup R16) — celo (jediny vyrobny dielec, preto plne),
  // jantarove pasmo „výplň N · ručne" po liniu linky a koty sirky, vysky linky
  // a sokla. LEN kontext Korpus a vkladanie.
  function drawSlotDetail(S, rx, ry, g, sl){
    var W = g.W, H = g.H;
    // CELO — jediny VYROBNY dielec slotu, preto plna ciara a plna vypln.
    var ftop = sl.fb + sl.fh;
    if (sl.fh > 0){
      S.push('<rect x="' + rx(g.gapLeft) + '" y="' + ry(ftop) + '" width="' +
             Math.max(W - g.gapLeft - g.gapRight, 1) + '" height="' + sl.fh + '" fill="' +
             PV_FRONT_DOOR + '" stroke="' + PV_FRONT_STROKE + '" stroke-width="2"/>');
    }
    // D-139: pasmo „výplň hore" ZANIKLO — celo siaha po linku mínus medzeru
    // hore; vyplň nad umyvackou je samostatny nizky korpus a slot sa nastavi
    // po jej spodok. Kota vysky cela ukaze odvodene cislo.
    if (sl.fh > 0) pvDimV(S, rx, ry, g.gapLeft, DIM_OFF_V_PX, sl.fb, ftop, [String(Math.round(sl.fh))]);
    pvDimH(S, rx, ry, 0, W, pvBaseZ, DIM_OFF_PX, [String(Math.round(W))]);
    pvDimV(S, rx, ry, W, DIM_OFF_V_PX, 0, H, [String(Math.round(H))]);
    if (sl.fb > 0) pvDimV(S, rx, ry, 0, -DIM_OFF_V_PX, 0, sl.fb, [String(Math.round(sl.fb))]);
  }

  // ---- S1-F: BOX NIKY + PASMA DVERI + PASMO PRIPUSTNEJ HRANY --------------
  //
  // Kresli PRESNE to, co poslal server (`preview.appliances[]`): box je
  // referencia (prerusovana ciara, nikdy vypln dielca), pasma su jeho vnutorne
  // delenie podla listu vyrobcu a jantarovy prizvuk vlavo je pasmo, v ktorom
  // smie lezat hrana medzi dolnym a hornym celom. ZIADNY vypocet — cisla
  // (669, 71, 679–727) su v payloade.
  function drawApplianceRefs(S, rx, ry, g, list){
    (list || []).forEach(function(a){
      if (!a || !a.box) return;
      var b = a.box, x = nxNumOr(b.x, 0), z = nxNumOr(b.z, 0);
      var w = nxNumOr(b.w, 0), h = nxNumOr(b.h, 0);
      if (!(w > 0 && h > 0)) return;
      var clash = (a.state === 'clash' || a.state === 'unsatisfiable');
      var col = clash ? PV_SLOT_FILL : PV_SELECT;
      S.push('<rect x="' + rx(x) + '" y="' + ry(z + h) + '" width="' + w + '" height="' + h +
             '" fill="' + col + '" fill-opacity=".08" stroke="' + col +
             '" stroke-width="2" stroke-dasharray="12 8"/>');
      (a.bands || []).forEach(function(bd){
        if (!bd) return;
        var z0 = nxNumOr(bd.z0, 0), z1 = nxNumOr(bd.z1, 0);
        if (z1 - z0 <= 0) return;
        if (z0 > z + 0.01){
          S.push('<line x1="' + rx(x) + '" y1="' + ry(z0) + '" x2="' + rx(x + w) +
                 '" y2="' + ry(z0) + '" stroke="' + col + '" stroke-width="1.5"/>');
        }
        // H6c: cislo pasma (11 px) sa napise, len ked sa pasmo zmesti na vysku pisma —
        // pri zoome sa dokresli (R6).
        if ((z1 - z0) * pvS >= DIM_FONT_PX){
          pvText(S, rx(x + w / 2), ry(z0 + (z1 - z0) / 2),
                 String(Math.round(nxNumOr(bd.size, z1 - z0))), DIM_FONT_PX, 'middle', col, 'dominant-baseline="middle"');
        }
      });
      drawApplianceSplit(S, rx, ry, a, x, w);
    });
  }

  // Pasmo pripustnej hrany ciel (jantar) + ciara SUCASNEJ hrany. Jednostranny
  // rozsah (list dal len min alebo len max) sa kresli od/po hranu boxu.
  function drawApplianceSplit(S, rx, ry, a, x, w){
    var sp = a.split;
    if (!sp) return;
    var lo = nxNumOr(sp.lo, NaN), hi = nxNumOr(sp.hi, NaN);
    var b = a.box, z = nxNumOr(b.z, 0), h = nxNumOr(b.h, 0);
    if (isNaN(lo)) lo = z;
    if (isNaN(hi)) hi = z + h;
    if (hi - lo > 0){
      S.push('<rect x="' + rx(x - PV_APPL_GUTTER) + '" y="' + ry(hi) + '" width="' +
             (PV_APPL_GUTTER - 4) + '" height="' + (hi - lo) + '" fill="' + PV_SLOT_FILL +
             '" fill-opacity=".55" stroke="' + PV_SLOT_FILL + '" stroke-width="1"/>');
      if (sp.lo_mm != null && sp.hi_mm != null){
        // Konce pasma hrany (11 px) VLAVO od jantaroveho pasma: horny tesne nad nim, dolny pod nim.
        pvText(S, rx(x - PV_APPL_GUTTER) - pvU(4), ry(hi) - pvU(3),
               String(Math.round(sp.hi_mm)), DIM_FONT_PX, 'end', PV_SLOT_FILL);
        pvText(S, rx(x - PV_APPL_GUTTER) - pvU(4), ry(lo) + pvU(DIM_FONT_PX + 2),
               String(Math.round(sp.lo_mm)), DIM_FONT_PX, 'end', PV_SLOT_FILL);
      }
    }
    var e = nxNumOr(sp.edge, NaN);
    if (isNaN(e)) return;
    var ecol = sp.state === 'clash' ? PV_SLOT_FILL : PV_SELECT_ACCENT;
    S.push('<line x1="' + rx(x - PV_APPL_GUTTER) + '" y1="' + ry(e) + '" x2="' + rx(x + w) +
           '" y2="' + ry(e) + '" stroke="' + ecol + '" stroke-width="2.5"/>');
    if (sp.edge_mm != null){
      // Cislo hrany nad ciarou, zarovnane k pravemu okraju boxu DOVNUTRA — 11 px text
      // „hrana 695" (~55 px) by zvonka siahol cez kotu vysky.
      pvText(S, rx(x + w) - pvU(4), ry(e) - pvU(4), 'hrana ' + Math.round(sp.edge_mm), DIM_FONT_PX, 'end', ecol);
    }
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
    // S1-E: SLOT UMYVACKY ma VLASTNY PODKLAD — nema boky, dno ani vrch, takze
    // korpusovy podklad by kreslil dielce, ktore neexistuju. PR #381 (P2):
    // podklad NEnahradza cely nahlad — kontexty Cela a Kovanie kreslia svoje
    // projekcie dalej, len nad nim.
    var slot = pvSlot();
    if (slot){
      drawSlotBase(S, rx, ry, g, slot);
    } else {
      drawCarcass(S, rx, ry, g, (previewMode === 'cab' || previewMode === 'insert') ? pvDepthSkew() : 0);
    }

    // ROH-B2 (mockup C): rohova zostava zo servera — len pri rohovej, inak null
    // a kazda vetva nizsie kresli presne to, co doteraz.
    var corner = pvCornerPreview();
    if (previewMode==='zones'){
      drawZonesBase(S, rx, ry, g);
    } else if (previewMode === 'fronts'){
      // cela pohlad + koty vysok a medzier
      if (corner) drawCornerAssembly(S, rx, ry, corner, true);
      renderFrontsPreview(S, rx, ry, g);
      drawFrontDims(S, rx, ry, g);
    } else if (previewMode === 'hw'){
      // UI-B2: kontext Kovanie ma vlastnu projekciu — pozicie kovania
      if (corner) drawCornerAssembly(S, rx, ry, corner, true);
      drawHwBase(S, rx, ry, g);
    } else if (previewMode === 'insert' && slot){
      // S1-E: vkladany slot kresli TEN ISTY detail ako oznaceny slot —
      // sablona nema zony ani viacriadkove cela, ktore by sa dali prepinat.
      drawSlotDetail(S, rx, ry, g, slot);
    } else if (previewMode === 'insert'){
      // UI-C1b (N9): sablona TAK, AKO BUDE VLOZENA. Cela su PREPINATELNA vrstva
      // (chip Čelá je defaultne zapnuty) — po zhasnuti vidno vnutro sablony.
      if (NXLayers.stateOf('insert', 'cela', pvAvail()) === 'on'){
        // ROH-B2: rohova sa vklada aj so zostavou (mockup A6) — zhasnute cela
        // odkryvaju vnutro, preto vtedy zostava (blenda pred vnutrom) nie.
        if (corner) drawCornerAssembly(S, rx, ry, corner, false);
        renderFrontsPreview(S, rx, ry, g);
      } else if (NXLayers.stateOf('insert', 'zony', pvAvail()) !== 'on'){
        // Codex #175 P2: zhasnute cela ODKRYVAJU vnutro — zony sa vtedy kreslia
        // ako podklad. Ked ich uz prisvietil CHIP, kresli ich ghost vrstva, takze
        // sa tu preskocia (inak by tie iste ciary isli do SVG dvakrat).
        // Je to ten isty vzor ako v projekcii Kovanie (drawHwBase).
        drawZonesGhost(S, rx, ry, g);
      }
      renderCabOutline(S, rx, ry, W, H, g.fh, corner);
    } else if (slot){
      // S1-E: kontext Korpus nad slotom — celo, pasmo výplne a koty.
      drawSlotDetail(S, rx, ry, g, slot);
    } else {
      // ROH-B2 (O12, mockup B2): Korpus rohovej kresli aj DVERE a ZOSTAVU —
      // inak by koty dverovej casti a CR 1 viseli nad prazdnom (vzor slotu,
      // ktory v Korpuse kresli svoje celo). Dvere su tu len kresba (klik na
      // celo patri kontextu Čelá), preto bez interakcie.
      if (corner){
        drawCornerAssembly(S, rx, ry, corner, false);
        S.push('<g pointer-events="none">');
        renderFrontsPreview(S, rx, ry, g);
        S.push('</g>');
      }
      // D-08: kontext Korpus — kotovany celny rez (Š/V/sokel + naznak hlbky)
      renderCabOutline(S, rx, ry, W, H, g.fh, corner);
    }
    // S1-F: kontrolna geometria chladnicky NAD podkladom korpusu (kontext
    // Korpus) — je to referencia, nie dielec, takze sa kresli ako posledna
    // vrstva a nikdy nenahradza obrys.
    drawApplianceRefs(S, rx, ry, g, pvApplianceRefs());
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
        // rozmer zony (11 px) — len ked sa zmesti: sirka textu <= sirka zony − 4 px a vyska zony >= 13 px (R3)
        var zlab = Math.round(z.w)+'×'+Math.round(z.h);
        if (z.w * pvS - 4 >= pvTextW(zlab, DIM_FONT_PX) && z.h * pvS >= 13){
          pvText(S, rx(z.x+z.w/2), ry(z.z+z.h/2), zlab, DIM_FONT_PX, 'middle', '#37474f', 'dominant-baseline="middle"');
        }
      } else if (z.split){
        // priecky (hrube ciary), tahatelne
        drawDividers(z, S, rx, ry, g.t, g.fh, g.topNone, g.H);
      }
    });
    // UI-B2: koty sirok zon pod korpusom — len ked je co porovnavat
    var spans = nxZoneSpans(zones);
    if (spans.length > 1 && spans.length <= 8){
      spans.forEach(function(sp){ pvDimH(S, rx, ry, sp.x, sp.x + sp.w, pvBaseZ, DIM_OFF_PX, [String(Math.round(sp.w))]); });
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
    // ROH-A2: rohova, ktorej otvor este nepozname, necha cela prazdne — veta
    // „nastav v sekcii Čelá" by klamala (cela ma, len sa pocitaju).
    if (g.frontsPending) return;
    if (!items || !items.length){
      // odhad z formulara (bez presnych vysok) — len info
      pvText(S, rx(W/2), ry(H/2), 'Čelá: nastav v sekcii Čelá', DIM_FONT_PX, 'middle', '#90a4ae');
      return;
    }
    // D-07: okraje/medzera z poli (0 je platna hodnota — NIE || default);
    // zaporny bocny okraj = cela sirsie nez korpus (presah).
    // ROH-A2: vsetko sa meria od CELNEHO OTVORU `fx0`/`fw` (rohova: dverova
    // cast); ostatne typy maju fx0 = 0 a fw = W, teda dnesne cisla.
    var fx0 = nxNumOr(g.fx0, 0), fw = nxNumOr(g.fw, W), fxc = fx0 + fw / 2;
    var gs = fx0 + nxFrontSide(g, 'gapLeft'), gap = g.gap;
    var ow = fw - nxFrontSide(g, 'gapLeft') - nxFrontSide(g, 'gapRight');
    items.forEach(function(it, i){
      var z = it.z, h = it.height, col = (it.type==='drawer_front')?PV_FRONT_DRAWER:PV_FRONT_DOOR;
      var fnum = 'F' + (i + 1);
      S.push('<g class="fgrp" data-front-id="'+esc(it.id || '')+'">');
      if (it.type === 'none'){
        // D-18: pásmo Bez čela = čiarkovaný obrys bez výplne (otvorená nika v rade).
        // D-23: aj none pás je súčasťou skupiny — klik vedie na jeho riadok v zozname.
        S.push('<rect x="'+rx(gs)+'" y="'+ry(z+h)+'" width="'+ow+'" height="'+h+'" fill="none" stroke="#90a4ae" stroke-width="1.5" stroke-dasharray="7 5"/>');
        var nlab = pvFrontLabel([fnum + ' · bez čela ' + Math.round(h), fnum + ' · ' + Math.round(h), fnum], ow * pvS, h * pvS);
        if (nlab) S.push('<text x="'+pvN3(rx(fxc))+'" y="'+pvN3(ry(z+h/2))+'" font-size="'+pvN3(pvU(DIM_FONT_PX))+'" fill="#90a4ae" text-anchor="middle" dominant-baseline="middle">'+esc(nlab)+'</text>');
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
      cols = cols.map(function(c, j){ return nxProfilePanel(it, j, c.x, z, c.w, h); });
      cols.forEach(function(c){
        if (c.h > 0 && c.w > 0) S.push('<rect x="'+rx(c.x)+'" y="'+ry(c.z+c.h)+'" width="'+c.w+'" height="'+c.h+'" fill="'+col+'" stroke="'+PV_FRONT_STROKE+'" stroke-width="1.5"/>');
        var b = c.band;
        if (b) S.push('<rect class="fprofband" x="'+rx(b.x)+'" y="'+ry(b.z+b.h)+'" width="'+b.w+'" height="'+b.h+'"/>');
      });
      var ph = cols.length ? cols[0].h : h;
      var panelZ = cols.length ? cols[0].z : z;
      // KOV-A2a / D-115: symboly otvarania. Kreslia sa PRED popisom, aby text
      // ostal navrchu (SVG kresli v poradi zdroja); ciary uz idu Z ROHOV cez
      // cele kridlo, takze stredom panela naozaj prechadzaju.
      drawFrontSymbols(S, rx, ry, it, cols, panelZ, ph > 0 ? ph : h);
      // popis do stredu PANELU (pri profile nesmie skoncit v jeho pruhu);
      // cislo ostava vyskou RIADKU — presne to, co je v zozname ciel.
      // D-115 HALO: text dostane obrys farbou VYPLNE panelu (`col`, PV_* zrkadlo
      // tokenu), inak by ho X zasuvky/blendy preskrtlo. Ziadna nova farba.
      // H6c (R3): popis v 3 stupnoch — „F1 · zásuvka 760" → „F1 · 760" → „F1" podľa
      // sirky panelu v px; pri vyske panelu < 12 px popis nie je. HALO 2,75 px.
      var plab = pvFrontLabel([fnum+' · '+frontTypeDesc(it.type)+' '+Math.round(h), fnum+' · '+Math.round(h), fnum],
                              ow * pvS, (ph > 0 ? ph : h) * pvS);
      if (plab) S.push('<text x="'+pvN3(rx(fxc))+'" y="'+pvN3(ry(panelZ+(ph > 0 ? ph : h)/2))+'" font-size="'+pvN3(pvU(DIM_FONT_PX))+'" fill="'+PV_SELECT_ACCENT+'" paint-order="stroke" stroke="'+col+'" stroke-width="'+pvN3(pvU(2.75))+'" text-anchor="middle" dominant-baseline="middle">'+esc(plab)+'</text>');
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
    // D-138: slot umyvacky kresli svoje celo ako sklop (typ skrinky z formulara).
    var tsym = frontTypeSymbol(it.type, (typeof getType === 'function') ? getType() : null);
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
  // ROH-B2: `corner` (kresba rohovej zo servera) prida koty dverovej casti
  // a CR 1 tesne pod skrinku (mockup C: 450 / 80) a sirku posunie o riadok
  // nizsie; bez nej je kresba presne dnesna.
  function renderCabOutline(S, rx, ry, W, H, fh, corner){
    var D = numv('depth') || 0, sk = pvDepthSkew();
    if (corner) drawCornerDims(S, rx, ry, corner);
    // H6c (O11 A): bez „mm"; dlhy popis sa pri tesnom useku skrati na cislo (R3).
    pvDimH(S, rx, ry, 0, W, pvBaseZ, corner ? DIM_OFF_PX + DIM_ROW_PX : DIM_OFF_PX,
           ['Š ' + Math.round(W), String(Math.round(W))]);
    pvDimV(S, rx, ry, W, DIM_OFF_V_PX, 0, H, ['V ' + Math.round(H), String(Math.round(H))]);
    // D-11: vlavo koty sokla (0..fh) a tela (fh..H) — len ked sokel existuje
    if (fh > 0){
      pvDimV(S, rx, ry, 0, -DIM_OFF_V_PX, 0, fh, ['sokel ' + Math.round(fh), String(Math.round(fh))]);
      pvDimV(S, rx, ry, 0, -DIM_OFF_V_PX, fh, H, ['telo ' + Math.round(H - fh), String(Math.round(H - fh))]);
    }
    // hlbka: kota na skosenej hornej ploche (naznak). Pri D > 0 je skosenie vzdy
    // >= 24 mm (`pvDepthSkew`), takze nahradna vetva „hĺbka … mm" bola mrtva (S24).
    if (D > 0 && sk > 0){
      pvDimH(S, rx, ry, W, W + sk, H + sk, -DIM_DEPTH_OFF_PX, ['H ' + Math.round(D), String(Math.round(D))]);
    }
  }

  // ---- N26: MEDZERY JANTAROVO PRI EDITACII --------------------------------
  // Kym stoji kurzor v niektorom poli SCHEMY medzier (skupina „Spoločné pre
  // skrinku") alebo mys nad schemou, medzery v projekcii Cela sa prisvietia —
  // clovek vidi, KTORU skaru prave meni.
  // Je to LEN zvyraznenie: ziadne nove data, ziadny novy vypocet (pasy vznikaju
  // z toho isteho `nxFrontDims`, ktorym sa uz kotuju).
  var NX_GAP_FIELDS = { fr_gap: 1, fr_gap_top: 1, fr_gap_bottom: 1, fr_gap_left: 1, fr_gap_right: 1 };
  var PV_GAP_FILL = '#fff3e0';   // --nx-warn-bg-soft
  var PV_GAP_LINE = '#ffb74d';   // --nx-warn
  var PV_GAP_TEXT = '#b26a00';   // --nx-warnchip-fg
  // „Editacia" = kurzor v niektorom z piatich poli SCHEMY, alebo mys nad
  // schemou. D-130b ZRUSIL vazbu na OTVORENU skupinu: schema zije v skupine
  // „Spoločné pre skrinku" (`cabfront`), kde je aj material ciel, takze
  // skupina byva otvorena pri bezne praci — medzery by svietili stale a
  // zvyraznenie by prestalo nieco znamenat. Hover je lacna nahrada: kto sa
  // na schemu pozera, ide na nu aj mysou.
  var pvGapFocus = false, pvGapHover = false;
  function pvGapsHot(){ return pvGapFocus || pvGapHover; }
  function pvSetGapFocus(on){
    if (pvGapFocus === !!on) return;
    pvGapFocus = !!on;
    renderPreview();
  }
  function pvSetGapHover(on){
    if (pvGapHover === !!on) return;
    pvGapHover = !!on;
    renderPreview();
  }
  // Schema je jeden kontajner `.gapdiag` — patri do nej aj kazde z piatich
  // poli, takze `closest` staci na cely blok (ziadny zoznam selektorov).
  function pvInGapDiag(node){
    return !!(node && typeof node.closest === 'function' && node.closest('.gapdiag'));
  }
  if (typeof document !== 'undefined'){
    document.addEventListener('focusin', function(ev){
      pvSetGapFocus(!!(ev.target && ev.target.id && NX_GAP_FIELDS[ev.target.id]));
    }, true);
    document.addEventListener('focusout', function(ev){
      if (ev.target && ev.target.id && NX_GAP_FIELDS[ev.target.id]) pvSetGapFocus(false);
    }, true);
    // `mouseover`/`mouseout` (nie `mouseenter`) — delegovane cez capture na
    // dokumente, takze prezijú kazde prekreslenie panela. `relatedTarget`
    // odfiltruje prechod MEDZI uzlami schemy (pole -> obrys), ktory by inak
    // zvyraznenie zbytocne zhasol a zase rozsvietil.
    document.addEventListener('mouseover', function(ev){
      pvSetGapHover(pvInGapDiag(ev.target));
    }, true);
    document.addEventListener('mouseout', function(ev){
      if (pvInGapDiag(ev.target) && !pvInGapDiag(ev.relatedTarget)) pvSetGapHover(false);
    }, true);
  }

  // ---- ZAKLADNA vrstva: koty ciel (vysky riadkov + medzery) ---------------
  // Vysky su RESOLVED z payloadu (front_items), medzery su rozdiely medzi nimi
  // — ziadny vlastny vzorec, ziadne nove pole.
  function drawFrontDims(S, rx, ry, g){
    var dims = nxFrontDims(g.fronts, g);
    if (!dims.length) return;
    var gl = nxFrontSide(g, 'gapLeft'), gr = nxFrontSide(g, 'gapRight');
    // ROH-A2: medzery, pasy aj kota sirky patria CELNEMU OTVORU (rohova:
    // dverova cast) — ostatne typy fx0 = 0, fw = W, teda dnesne cisla.
    var fx0 = nxNumOr(g.fx0, 0), fw = nxNumOr(g.fw, g.W);
    var xr = Math.max(g.W, fx0 + fw - gr);
    // N26: pasy medzier sa kreslia PRED kotami, aby cisla ostali navrchu.
    var hot = pvGapsHot();
    if (hot){
      var x0 = Math.min(fx0 + gl, fx0), x1 = Math.max(fx0 + fw, fx0 + fw - gr);
      dims.forEach(function(d){
        if (d.kind !== 'gap') return;
        S.push('<rect x="' + rx(x0) + '" y="' + ry(d.z2) + '" width="' + (x1 - x0) + '" height="' + (d.z2 - d.z1) +
               '" fill="' + PV_GAP_FILL + '" stroke="' + PV_GAP_LINE + '" stroke-width="1.2"/>');
      });
    }
    // H6c (R3): cisla medzier (10 px) zarovnane doprava 6 px vlavo od otvoru, BEZ
    // PREKRYVU — zoradene zdola nahor, rozostup >= 11 px (vzor mockupu); tesne
    // medzery sa rozotlacia nahor (a od horneho okraja spat), nepretnu sa.
    var gapDims = [];
    dims.forEach(function(d){
      if (d.kind === 'front') pvDimV(S, rx, ry, xr, DIM_OFF_V_PX, d.z1, d.z2, [String(Math.round(d.size))]);
      else gapDims.push(d);
    });
    var gapY = nxSpreadLabels(gapDims.map(function(d){ return ry((d.z1 + d.z2)/2); }), pvU(11),
                              pvView ? pvView.y + pvU(PV_PAD_PX + 6) : -Infinity);
    gapDims.forEach(function(d, i){
      pvText(S, rx(fx0) - pvU(6), gapY[i], String(Math.round(d.size)), DIM_GAP_FONT_PX, 'end',
             hot ? PV_GAP_TEXT : null, 'dominant-baseline="middle"');
    });
    // D11: kota sirky visi pod NAJNIZSIM kreslenym prvkom (aj pod presahom cela dole).
    pvDimH(S, rx, ry, fx0 + gl, fx0 + fw - gr, pvBaseZ, DIM_OFF_PX, [String(Math.round(fw - gl - gr))]);
  }

  // Ciste (Node testy): rozotlacenie popiskov v jednom stlpci. `ys` = suradnice
  // y (px kresby rastu NADOL) zoradene ZDOLA NAHOR (klesajuce y); kazdy dalsi je
  // aspon o `step` vyssie nez predosly; ked rad siaha nad `minY`, posunie sa spat
  // nadol (poradie a rozostup ostavaju). Nemeni vstup.
  function nxSpreadLabels(ys, step, minY){
    var out = ys.slice(), i;
    for (i = 1; i < out.length; i++){
      if (out[i] > out[i - 1] - step) out[i] = out[i - 1] - step;
    }
    if (out.length && out[out.length - 1] < minY){
      out[out.length - 1] = minY;
      for (i = out.length - 2; i >= 0; i--){
        if (out[i] < out[i + 1] + step) out[i] = out[i + 1] + step;
      }
    }
    return out;
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
    // H6a (O5): veta „klik na značku…" je v „?" pod náhľadom (NXShell.pvHelpText,
    // kontext Kovanie). H6b (O9): súhrn položiek („Nohy 4× · Výsuv 1× · …") je
    // v lište sektora Kovanie (`nxHwSummary` číta `nxMetaContent`, shell.js) —
    // z kresby zmizol spolu s náhradnou vetou „Skrinka zatiaľ nemá kovanie"
    // (ju hovorí lišta: „bez kovania"); kresba je väčšia.
  }

  // Geometria nohy v kresbe Kovania (mm sceny): pri sokli (fh > 0) stoji v sokli
  // (0…min(fh, 90)), bez sokla visi POD korpusom (−70…0). Jedno miesto pre znacky
  // aj rezervu sceny.
  function nxLegGeom(fh){
    var lh = fh > 0 ? Math.min(fh, 90) : 70;
    return { lw: 42, lh: lh, z0: fh > 0 ? 0 : -lh };
  }
  // Najnizsi kresleny bod znaciek kovania (z, mm; najviac 0) — rezerva sceny pod
  // korpusom. Ciste (Node testy).
  function nxHwLowestZ(items, fh){
    var low = 0;
    (items || []).forEach(function(it){
      if (it && it.generic_type === 'leg') low = Math.min(low, nxLegGeom(fh).z0);
    });
    return low;
  }

  // Ciste (Node testy): odvodenie znaciek z payloadu kovania.
  // items: [{ owner_part_key, generic_type, quantity, label, owner_label }]
  // g:     { W, H, fh, gapSides, gap, fronts: [{ id, z, height, type, wings_n }] }
  // ->     [{ kind:'hinge'|'slide'|'leg', x, z, w, h, r, owner, title }]
  // Typy bez kresitelnej pozicie (podperky, spojky, uchytky) znacku nedostanu —
  // su v suhrne v liste sektora Kovanie, aby o nich pouzivatel vedel.
  function nxHwMarks(items, g){
    var out = [];
    if (!items || !items.length) return out;
    var W = g.W, fh = g.fh || 0;
    // ROH-A2: cela a ich kridla lezia v CELNOM OTVORE (rohova: dverova cast).
    var fx0 = nxNumOr(g.fx0, 0), fw = nxNumOr(g.fw, W);
    var gs = fx0 + nxFrontSide(g, 'gapLeft');
    var gap = (g.gap == null) ? 3 : g.gap;
    var ow = fw - nxFrontSide(g, 'gapLeft') - nxFrontSide(g, 'gapRight');
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
        var n = Math.min(qty, 8), lg = nxLegGeom(fh), lw = lg.lw, lh = lg.lh;
        var z0 = lg.z0, ins = 60, span = W - 2*ins - lw;
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
        // ROH-A2 (C8): STRANA PANTOV. Krajne kridla viackridlovych dvierok su
        // ODVODENE (lave = panty vlavo, posledne = vpravo — A1 kontrakt);
        // jednokridlove a stredne kridla maju stranu v SLOTE servera
        // (`front_slots`, stav smeru). Nic sa nehada: `unset` = znacka „?"
        // v strede kridla, legacy (kluc smeru v configu nie je) = ziadna znacka.
        var side = nxHingeSide(wkey, idx, cols.length, g.slots ? g.slots[fr.id] : null);
        if (!side) return;
        var cx = (side === 'right') ? (col.x + col.w - 26)
               : (side === 'left') ? (col.x + 26) : (col.x + col.w / 2);
        var nh = Math.min(qty, 6), pad2 = Math.min(90, fr.height * 0.22);
        for (var k = 0; k < nh; k++){
          var cz = (nh === 1) ? (fr.z + fr.height/2)
                              : (fr.z + pad2 + (fr.height - 2*pad2) * k / (nh - 1));
          var mk = { kind: 'hinge', x: cx, z: cz, r: 16, owner: owner, title: title };
          if (side === 'unknown') mk.unknown = true;
          out.push(mk);
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

  // ROH-A2 (C8) · ciste (Node testy): STRANA PANTOV znacky zavesu.
  //   wkey  = kluc kridla z `owner_part_key` (single | left | right | p1…p4)
  //   idx   = index stlpca kridla, n = pocet kridiel v kresbe
  //   entry = zaznam `front_slots[front_id]` zo servera ({ wings_n, slots })
  // -> 'left' | 'right' | 'unknown' (neurcene — kresli sa „?") | null (LEGACY
  //    bez kluca smeru: znacka sa nekresli vobec, stranu nehadame — O1).
  // Krajne kridla viackridlovych dvierok su odvodene geometricky (A1 kontrakt:
  // prve = panty vlavo, posledne = vpravo) — rovnako ako `frontWingSymbols`.
  function nxHingeSide(wkey, idx, n, entry){
    var k = String(wkey || 'single');
    if (k === 'left') return 'left';
    if (k === 'right') return 'right';
    if (k.charAt(0) === 'p' && n > 1){
      if (idx === 0) return 'left';
      if (idx === n - 1) return 'right';
    }
    var slots = (entry && Array.isArray(entry.slots)) ? entry.slots : [];
    var state = null;
    slots.forEach(function(s){ if (s && s.wing === k) state = s.state; });
    return (typeof frontDirSymbol === 'function') ? frontDirSymbol(state) : null;
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

  // Ciste (Node testy): suhrn kovania v liste sektora Kovanie (H6b; do kresby uz
  // nejde) — VSETKY typy vratane tych bez znacky (poctivo: „podperky 8×" musia
  // byt vidiet, aj ked sa nekreslia).
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
    if (m.kind === 'hinge' && m.unknown){
      // ROH-A2 (C8): strana pantov NEURCENA — ten isty jazyk ako symbol v celach
      // a overlay v modeli: prerusovany kruh s „?" (jantar), nie krizik na hrane.
      var qc = ghost ? PV_GHOST : PV_DIR_WARN;
      body = '<circle cx="'+rx(m.x)+'" cy="'+ry(m.z)+'" r="'+m.r+'" fill="'+fill+'" stroke="'+qc+
        '" stroke-width="2.5" stroke-dasharray="5 4"/>' +
        '<text x="'+rx(m.x)+'" y="'+ry(m.z)+'" font-size="'+Math.round(m.r*1.3)+'" font-weight="700" fill="'+qc+
        '" text-anchor="middle" dominant-baseline="middle">?</text>';
    } else if (m.kind === 'hinge'){
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
      pvText(S, L / 2, ry(Wd / 2), 'bez smeru dekoru', DIM_FONT_PX, 'middle', null, 'dominant-baseline="middle"');
    }
    // H6c: popisky maju stalych 11 px na obrazovke (kedysi pismo v mm odvodene od
    // vacsieho rozmeru dosky) — rovnako velke pri doske 300 aj 2600 mm.
    pvDimH(S, rx, ry, 0, L, pvBaseZ, DIM_OFF_PX, [String(Math.round(L))]);
    pvDimV(S, rx, ry, L, DIM_OFF_V_PX, 0, Wd, [String(Math.round(Wd))]);
    svg.innerHTML = S.join('');
  }
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
    // ROH-A2: od celneho otvoru (ostatne typy fx0 = 0, fw = W).
    var fx0 = nxNumOr(g.fx0, 0), fw = nxNumOr(g.fw, g.W);
    var gs = fx0 + nxFrontSide(g, 'gapLeft'), ow = fw - nxFrontSide(g, 'gapLeft') - nxFrontSide(g, 'gapRight'), L = [];
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
      // H6c (R6): zoom meni mierku, takze koty (stalych 11 px) sa musia prekreslit
      // — najviac raz za snimku. Posun (pan) mierku nemeni, tam sa neprekresluje.
      pvScheduleRender();
    }, { passive: false });
    // H6c (R6): zmena velkosti #preview (okno, rozbalenie sektora) — koty sa prekreslia
    // pre novu mierku. Bez ResizeObserver (Node) sa nic neregistruje.
    if (typeof ResizeObserver === 'function'){
      new ResizeObserver(function(){
        var b = svg.getBoundingClientRect();
        pvOnResize(b.width, b.height);
      }).observe(svg);
    }
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
                       nxLegGeom: nxLegGeom, nxHwLowestZ: nxHwLowestZ,
                       nxFrontDims: nxFrontDims, nxZoneSpans: nxZoneSpans, nxSpreadLabels: nxSpreadLabels,
                       // H6c (tests/js/test_h6c_koty.js): kóty v px — čistá scéna, výber popisu,
                       // plánovač prekreslenia, okraje a konštanty px modelu
                       nxDimScene: nxDimScene, pvFitLabel: pvFitLabel, pvFrontLabel: pvFrontLabel,
                       pvCabMargins: pvCabMargins, pvOnResize: pvOnResize, pvScheduleRender: pvScheduleRender,
                       sceneSize: sceneSize, setupPreviewDelegation: setupPreviewDelegation,
                       DIM_FONT_PX: DIM_FONT_PX, DIM_GAP_FONT_PX: DIM_GAP_FONT_PX, DIM_OFF_PX: DIM_OFF_PX,
                       DIM_OFF_V_PX: DIM_OFF_V_PX, DIM_TXT_PX: DIM_TXT_PX, DIM_ROW_PX: DIM_ROW_PX,
                       DIM_DEPTH_OFF_PX: DIM_DEPTH_OFF_PX, PV_PAD_PX: PV_PAD_PX,
                       // UI-C1b: draft ciel, odhad navrhu a doskova projekcia
                       nxFrontsResolve: nxFrontsResolve, nxDraftStats: nxDraftStats,
                       nxGrainArrows: nxGrainArrows, pvBoardScene: pvBoardScene,
                       nxFrontsExtent: nxFrontsExtent,
                       // KOV-A1 (P2-C): popis typu cela v nahlade
                       frontTypeDesc: frontTypeDesc, PV_FRONT_TYPE_DESC: PV_FRONT_TYPE_DESC,
                       // D-115 (tests/js/test_kova2b_smer_overlay.js) — kresba symbolov
                       // otvarania; test ju vola nad hotovymi stlpcami kridiel
                       drawFrontSymbols: drawFrontSymbols,
                       // D-130b (tests/js/test_d130b_spolocne.js): N26 stav je
                       // FOKUS/HOVER, nie otvorena skupina — test to overuje
                       // priamo nad prepinacmi, bez kreslenia.
                       pvGapsHot: pvGapsHot, pvSetGapFocus: pvSetGapFocus,
                       pvSetGapHover: pvSetGapHover, pvInGapDiag: pvInGapDiag,
                       NX_GAP_FIELDS: NX_GAP_FIELDS,
                       // S1-E: projekcia SLOTU UMYVACKY (celny rez) + zrkadla
                       // rozmerov generickeho tela a zakladne.
                       // PR #381 (P2 #5): Node sada overuje CELY nahlad nad
                       // slotom (ze kontexty Cela a Kovanie kreslia dalej).
                       renderPreview: renderPreview, pvAvail: pvAvail,
                       pvSlot: pvSlot, drawSlotBase: drawSlotBase,
                       drawSlotDetail: drawSlotDetail, nxSlotExtent: nxSlotExtent,
                       // D-139: slotova projekcia ciel (vsetky cesty bez ciel servera).
                       nxSlotFrontItems: nxSlotFrontItems, pvLiveFronts: pvLiveFronts,
                       pvInsertFronts: pvInsertFronts,
                       PV_DW_BODY: PV_DW_BODY,
                       PV_DW_BASE_H: PV_DW_BASE_H, PV_DW_BASE_SIDE: PV_DW_BASE_SIDE,
                       // S1-F: kontrolna geometria chladnicky (box, pasma,
                       // pasmo pripustnej hrany) — Node sada ju kresli nad
                       // payloadom servera a overuje, ze si nic nedopocitava.
                       nxRefExtent: nxRefExtent, drawApplianceRefs: drawApplianceRefs,
                       drawApplianceSplit: drawApplianceSplit,
                       pvApplianceRefs: pvApplianceRefs,
                       PV_APPL_GUTTER: PV_APPL_GUTTER,
                       // ROH-A2 (tests/js/test_roha2_vkladanie.js): celny otvor
                       // rohovej, strana pantov znacky zavesu a geometria nahladu.
                       nxFrontOpeningFor: nxFrontOpeningFor, nxHingeSide: nxHingeSide,
                       pvGeom: pvGeom, hwMarkSvg: hwMarkSvg, pvHingeSlots: pvHingeSlots,
                       // ROH-B2 (tests/js/test_rohb2_nahlad.js): kresba rohovej zostavy.
                       pvCornerPreview: pvCornerPreview, nxCornerStatsAdd: nxCornerStatsAdd,
                       drawCornerAssembly: drawCornerAssembly, drawCornerDims: drawCornerDims };
  }

