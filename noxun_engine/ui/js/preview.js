  // ===================== 2D NAHLAD (SVG) =====================
  var PV_PAD = 14; // padding viewBoxu nahladu (mm) — zdielaju ho renderPreview aj prevod px->mm v dragu
  var dragState = null;
  function setPreviewMode(m){ previewMode=m; el('tabZones').classList.toggle('on', m==='zones'); el('tabFronts').classList.toggle('on', m==='fronts'); renderPreview(); }

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
  function sceneSize(){
    var W = numv('width')||600, H = numv('height')||720;
    var e = frontsExtent();
    var minX = e ? e.minX : 0, maxX = e ? e.maxX : W;
    var minZ = e ? e.minZ : 0, maxZ = e ? e.maxZ : H;
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

  function renderPreview(){
    var svg = el('preview'); if (!svg) return;
    var t = numv('thickness')||18, W = numv('width')||600, H = numv('height')||720;
    if (!(W>0 && H>0)){ svg.innerHTML=''; return; }
    var pad = PV_PAD;
    applyViewBox(svg);
    var fh = (getType()==='upper')?0:(numv('floor_height')||0);
    var topNone = val('top_mode')==='none';
    var S = [];
    // helper: model (x,z) -> svg (flip Z). y = pad + (H - z)
    function rx(x){ return pad + x; }
    function ry(z){ return pad + (H - z); }
    // obrys korpusu
    S.push('<rect x="'+rx(0)+'" y="'+ry(H)+'" width="'+W+'" height="'+H+'" fill="#ffffff" stroke="#90a4ae" stroke-width="2"/>');
    // dielce schematicky (boky + dno + vrch)
    var partFill='#e5d8b8', partStroke='#c9b784';
    S.push('<rect x="'+rx(0)+'" y="'+ry(H)+'" width="'+t+'" height="'+H+'" fill="'+partFill+'" stroke="'+partStroke+'"/>');       // bok L
    S.push('<rect x="'+rx(W-t)+'" y="'+ry(H)+'" width="'+t+'" height="'+H+'" fill="'+partFill+'" stroke="'+partStroke+'"/>');     // bok R
    S.push('<rect x="'+rx(0)+'" y="'+ry(fh+t)+'" width="'+W+'" height="'+t+'" fill="'+partFill+'" stroke="'+partStroke+'"/>');    // dno
    if (!topNone) S.push('<rect x="'+rx(t)+'" y="'+ry(H)+'" width="'+(W-2*t)+'" height="'+t+'" fill="'+partFill+'" stroke="'+partStroke+'"/>'); // vrch
    if (fh>0) S.push('<rect x="'+rx(0)+'" y="'+ry(fh)+'" width="'+W+'" height="'+fh+'" fill="#f4f5f7" stroke="#cfd8dc" stroke-dasharray="4 3"/>'); // podstavec

    if (previewMode==='zones'){
      var zones = computeZones();
      var leafIdx = 0;
      zones.forEach(function(z){
        if (z.leaf){
          var col = PALETTE[leafIdx % PALETTE.length]; leafIdx++;
          var active = (fullZoneId(z.id) === activeZoneId);
          S.push('<rect class="zrect" data-zid="'+z.id+'" x="'+rx(z.x)+'" y="'+ry(z.z+z.h)+'" width="'+z.w+'" height="'+z.h+'" fill="'+col+'" fill-opacity="'+(active?0.55:0.32)+'" stroke="'+(active?'#1565c0':col)+'" stroke-width="'+(active?4:1.5)+'" style="cursor:pointer"/>');
          // police (tenke ciary)
          if (z.shelves>0){ for (var s=1;s<=z.shelves;s++){ var zs = z.z + z.h*s/(z.shelves+1); S.push('<line x1="'+rx(z.x)+'" y1="'+ry(zs)+'" x2="'+rx(z.x+z.w)+'" y2="'+ry(zs)+'" stroke="#8d6e63" stroke-width="2"/>'); } }
          // rozmer text
          if (z.w>60 && z.h>30) S.push('<text x="'+rx(z.x+z.w/2)+'" y="'+ry(z.z+z.h/2)+'" font-size="'+Math.min(22,z.w/5)+'" fill="#37474f" text-anchor="middle" dominant-baseline="middle" pointer-events="none">'+Math.round(z.w)+'×'+Math.round(z.h)+'</text>');
        } else if (z.split){
          // priecky (hrube ciary), tahatelne
          drawDividers(z, S, rx, ry, t, fh, topNone, H);
        }
      });
    } else {
      // cela pohlad
      renderFrontsPreview(S, rx, ry, W, H, fh, t);
    }
    svg.innerHTML = S.join('');
    // POZN: ziadne per-element bindovanie tu — pouzivame event delegaciu (setupPreviewDelegation),
    // takze nove <rect> po kazdom re-renderi reaguju bez opätovného naväzovania listenerov.
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

  function renderFrontsPreview(S, rx, ry, W, H, fh, t){
    var items = frontItems;
    if (!items || !items.length){
      // odhad z formulara (bez presnych vysok) — len info
      S.push('<text x="'+rx(W/2)+'" y="'+ry(H/2)+'" font-size="20" fill="#90a4ae" text-anchor="middle">Čelá: nastav v sekcii Čelá</text>');
      return;
    }
    // D-07: okraje/medzera z poli (0 je platna hodnota — NIE || default);
    // zaporny bocny okraj = cela sirsie nez korpus (presah).
    var gs = 2; var gsv = numv('fr_gap_sides'); if (!isNaN(gsv)) gs = gsv;
    var gap = 3; var gv = numv('fr_gap'); if (!isNaN(gv)) gap = gv;
    var ow = W - 2*gs;
    items.forEach(function(it, i){
      var z = it.z, h = it.height, col = (it.type==='drawer_front')?'#b3e5fc':'#e1f5fe';
      if (it.type === 'door' && it.wings_n === 2){
        // dvojkridlove dvierka = 2 panely s medzerou gap (Codex F5)
        var dw = (ow - gap) / 2;
        S.push('<rect x="'+rx(gs)+'" y="'+ry(z+h)+'" width="'+dw+'" height="'+h+'" fill="'+col+'" stroke="#4fc3f7" stroke-width="1.5"/>');
        S.push('<rect x="'+rx(gs+dw+gap)+'" y="'+ry(z+h)+'" width="'+dw+'" height="'+h+'" fill="'+col+'" stroke="#4fc3f7" stroke-width="1.5"/>');
      } else {
        S.push('<rect x="'+rx(gs)+'" y="'+ry(z+h)+'" width="'+ow+'" height="'+h+'" fill="'+col+'" stroke="#4fc3f7" stroke-width="1.5"/>');
      }
      S.push('<text x="'+rx(W/2)+'" y="'+ry(z+h/2)+'" font-size="18" fill="#0277bd" text-anchor="middle" dominant-baseline="middle">'+(it.type==='drawer_front'?'zásuvka':'dvierka')+' '+Math.round(h)+'</text>');
    });
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
      var t = closestClass(ev.target, 'zrect');
      if (t) pickZone(t.getAttribute('data-zid'));
    });
    // Zoom kolieskom k bodu pod kurzorom. Limity: detail max 8x, oddialenie max 3x sceny.
    svg.addEventListener('wheel', function(ev){
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

  function pickZone(localId){
    activeZoneId = fullZoneId(localId);
    refreshZoneUI();
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

