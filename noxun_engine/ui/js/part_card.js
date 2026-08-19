  // ===================== V0.3 KARTA DIELCA (ABS editor) =====================
  function roleLabel(role){
    var m = { side_left:'Bok ľavý', side_right:'Bok pravý', bottom:'Dno', top:'Vrch', back:'Chrbát',
      shelf:'Polica', divider_v:'Priečka zvislá', divider_h:'Priečka vodorovná', front_door:'Dvierka',
      drawer_front:'Zásuvkové čelo', plinth:'Sokel', rail_front:'Výstuha predná', rail_back:'Výstuha zadná' };
    return m[role] || role;
  }
  function sheetLabelOf(id){
    for (var i=0; i<MATERIALS.sheets.length; i++){
      if (MATERIALS.sheets[i].id === id) return MATERIALS.sheets[i].label || id;
    }
    return id || 'nezaradený';
  }
  function renderPartCard(pc){
    partCard = pc;
    var box = el('partCard');
    // D-89a: karta sa prekresluje — uzly pod kurzorom idu prec a ich `mouseout`
    // uz nepride, takze zvyraznenie v modeli by ostalo visiet (vzor clearFrontHover).
    if (typeof nxHoverEdgeClear === 'function') nxHoverEdgeClear();
    if (!pc){ box.style.display='none'; return; }
    box.style.display='';
    // V0.4.5 D1: omrvinka "‹ CAB-003 › Bok lavy" — klik na CAB = spat na skrinku
    if (el('pcCab')) el('pcCab').textContent = pc.cabinet_id || '?';
    if (el('pcName2')) el('pcName2').textContent = pc.name || roleLabel(pc.role);
    el('pcName').innerHTML = '<b>'+esc(pc.name || roleLabel(pc.role))+'</b> · '+esc(roleLabel(pc.role));
    el('pcDim').textContent = fmtmm(pc.length)+' × '+fmtmm(pc.width)+' × '+fmtmm(pc.thickness)+' mm';
    // FIX 2: material dielca len z hrubkovo kompatibilnych dosiek (nekompatibilne disabled).
    // D-45: cela beru KATALOGOVU hrubku sveho materialu (frontMatch = rozsah dosky),
    // ostatne dielce presnu hrubku dielca — tu ju meni material/hrubka celej skrinky.
    var isFront = (pc.role === 'front_door' || pc.role === 'drawer_front');
    var matFn = isFront ? frontMatch() : thMatch(pc.thickness);
    var selectedMaterial = pc.has_material_override ? (pc.material_id || '') : '';
    var inheritLabel = '(dedí: '+sheetLabelOf(pc.material_id)+')';
    var ms = el('pcMaterial');
    // D-49: virtualne duplaky aj tu — thMatch ich pri nesediacej hrubke dielca
    // necha disabled (zrkadlo serveroveho D-45 guardu), pri 36 mm dielci su volne.
    fillSheetSelectFiltered(ms, true, matFn, selectedMaterial, inheritLabel, undefined, true);
    ms.value = selectedMaterial;
    ms.className = pc.has_material_override ? 'ovr' : '';
    renderEdgeRows(pc);
    renderPartSvg(pc);
    nxComboSync(box); // D-85: materialovy combobox + 4 comboboxy hran
  }
  function renderEdgeRows(pc){
    var box = el('edgeRows'); box.innerHTML='';
    ['L1','L2','W1','W2'].forEach(function(code){
      var lbl = (pc.edge_labels && pc.edge_labels[code]) || code;
      var absId = pc.edges ? pc.edges[code] : null;
      var isOvr = hasOwn(pc.edge_overrides, code);
      var row = document.createElement('div'); row.className='edgerow';
      // D-89a: cely riadok je hover-cielom (nielen rozbalovacka) — hrana sa
      // rozsvieti v modeli uz pri prejdeni jej NAZVU.
      row.setAttribute('data-edge', code);
      row.title = 'Kurzor nad hranou ju zvýrazní priamo v modeli.';
      row.innerHTML = '<span class="en"><i style="background:'+absColorOf(absId)+'"></i>'+esc(lbl)+'</span>';
      var sel = document.createElement('select');
      // D-36: skupiny podla resolved materialu dielca (2A-3b: cez material_id —
      // schema 2 grupuje group_id+strukturou); curVal drzi hodnotu tejto
      // hrany (aj legacy mimo katalogu — F5) a NEsmie ju prebit prva odporucana paska.
      var curVal = isOvr ? (absId==null?'':absId) : '__inherit__';
      // D-102: text „(podľa pravidla — …)" zo servera (pc.edge_rule_options).
      sel.innerHTML = edgeOptionsHtml(pc.material_id, curVal,
        pc.edge_rule_options ? pc.edge_rule_options[code] : null);
      sel.value = curVal;
      if (isOvr) sel.className='ovr';
      sel.setAttribute('data-edge', code);
      sel.setAttribute('data-nx-combo', 'abs'); // D-85: hrany su ABS combobox
      sel.onchange = (function(cc){ return function(){ onEdgeChange(cc, sel.value); }; })(code);
      row.appendChild(sel);
      box.appendChild(row);
    });
  }
  // 2D dielec: obdlznik. Orientaciu aj priradenie hran riadi mapa pc.edge_sides z Ruby (AbsRules —
  // jeden zdroj pravdy zdielany s labelmi): lezace dielce maju dlzku vodorovne (L1/L2 dole/hore,
  // W1/W2 vlavo/vpravo); cela dlzku zvisle (L1/L2 lava/prava, W1/W2 dole/hore). Hrany farebne podla
  // ABS; klik na hranu -> fokus jej dropdownu. Bez mapy fallback = lezaci dielec (spatna kompat).
  function renderPartSvg(pc){
    var svg = el('partSvg'); if(!svg) return;
    var L = Math.max(1, parseFloat(pc.length)||100), Wd = Math.max(1, parseFloat(pc.width)||100);
    var sides = pc.edge_sides || { L1:'bottom', L2:'top', W1:'left', W2:'right' };
    // L hrany na zvislej strane => dlzka sa kresli zvislo (cela); inak vodorovne (lezace dielce).
    var lVert = (sides.L1==='left' || sides.L1==='right');
    var horiz = lVert ? Wd : L, vert = lVert ? L : Wd;
    var pad=28, availW=300-2*pad, availH=200-2*pad;
    var sc = Math.min(availW/horiz, availH/vert); if(!isFinite(sc)||sc<=0) sc=1;
    var rw=horiz*sc, rh=vert*sc, ox=(300-rw)/2, oy=(200-rh)/2, ew=7;
    var edges = pc.edges||{}, lab = pc.edge_labels||{}, hints = pc.edge_hints||{};
    function ecol(code){ return absColorOf(edges[code]); }
    // D-102: plny text pasky ako tooltip pasu + skratka do EXISTUJUCEHO popisku
    // strany (ziadny novy riadok — vertikalny priestor panela je vzacny).
    function tip(code){ return (hints[code] && hints[code].title) ? hints[code].title : ''; }
    function sideText(code){
      return edgeSideText(lab[code], hints[code] ? hints[code].short : '');
    }
    // Farebny bar (klik-target) danej strany obdlznika.
    function bar(side, code, fill){
      var t = tip(code) ? '<title>'+esc(tip(code))+'</title>' : '';
      if (side==='top')    return '<rect class="ehit" data-edge="'+code+'" x="'+ox+'" y="'+(oy-ew/2)+'" width="'+rw+'" height="'+ew+'" fill="'+fill+'" style="cursor:pointer">'+t+'</rect>';
      if (side==='bottom') return '<rect class="ehit" data-edge="'+code+'" x="'+ox+'" y="'+(oy+rh-ew/2)+'" width="'+rw+'" height="'+ew+'" fill="'+fill+'" style="cursor:pointer">'+t+'</rect>';
      if (side==='left')   return '<rect class="ehit" data-edge="'+code+'" x="'+(ox-ew/2)+'" y="'+oy+'" width="'+ew+'" height="'+rh+'" fill="'+fill+'" style="cursor:pointer">'+t+'</rect>';
      return '<rect class="ehit" data-edge="'+code+'" x="'+(ox+rw-ew/2)+'" y="'+oy+'" width="'+ew+'" height="'+rh+'" fill="'+fill+'" style="cursor:pointer">'+t+'</rect>'; // right
    }
    // Popis (label) strany — vodorovne hore/dole, zvisle vlavo/vpravo (rotovane).
    function label(side, txt){
      txt = esc(txt||'');
      if (side==='top')    return '<text x="150" y="'+(oy-10)+'" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none">'+txt+'</text>';
      if (side==='bottom') return '<text x="150" y="'+(oy+rh+17)+'" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none">'+txt+'</text>';
      if (side==='left')   return '<text x="'+(ox-11)+'" y="'+(oy+rh/2)+'" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none" transform="rotate(-90 '+(ox-11)+' '+(oy+rh/2)+')">'+txt+'</text>';
      return '<text x="'+(ox+rw+11)+'" y="'+(oy+rh/2)+'" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none" transform="rotate(90 '+(ox+rw+11)+' '+(oy+rh/2)+')">'+txt+'</text>'; // right
    }
    var S=[];
    S.push('<rect x="'+ox+'" y="'+oy+'" width="'+rw+'" height="'+rh+'" fill="#faf6ee" stroke="#cfd8dc"/>');
    ['L1','L2','W1','W2'].forEach(function(code){
      var side = sides[code]; if(!side) return;
      S.push(bar(side, code, ecol(code)));
      S.push(label(side, sideText(code)));
    });
    S.push('<text x="150" y="100" font-size="12" fill="#b0bec5" text-anchor="middle" dominant-baseline="middle" pointer-events="none">'+Math.round(L)+'×'+Math.round(Wd)+'</text>');
    svg.innerHTML = S.join('');
  }
  function onPartMaterial(){
    if (!partCard) return;
    var v = el('pcMaterial').value;
    // D-41 C2: novy dekor bez pouzitelnej jednotkovej pasky -> modal (vytvorit /
    // bez ABS / zrusit) PRED odoslanim. Server check je autorita, toto je len UX
    // (2A-3b: dispatcher zrkadli schema 2 hierarchiu group/structure/universal).
    if (v && !absUsableForSheet(MATERIALS.edges, sheetRecOf(v), catalogSchemaNow(), sheetThicknessOf(v))){
      var prev = partCard.has_material_override ? (partCard.material_id || '') : '';
      openAbsModal('Dekor „' + decorOfSheet(v) + '" nemá použiteľnú ' + absMissingLabel(catalogSchemaNow()) + ' pre túto hrúbku — hrany podľa pravidla by ostali bez ABS.',
        function(create){ sendPartMaterial(v, create); },
        function(){ el('pcMaterial').value = prev; regroupPartEdges(prev || partCard.material_id); });
      return;
    }
    sendPartMaterial(v, false);
  }
  function sendPartMaterial(v, createAbs){
    if (!partCard) return;
    // F3: pri zmene materialu (override) pregrupuj ABS selecty LOKALNE podla noveho
    // materialu — netreba cakat na Ruby echo. Pri ZRUSENI override (v==='' = navrat na
    // dedenie) NErataj: JS zdedeny material nevie, necha skupiny a pocka na payload.
    if (v) regroupPartEdges(v);
    // D-41: cabinet_id = identity guard (Ruby zahodi echo po prekliknuti na iny korpus)
    if (window.sketchup && sketchup.set_part_material)
      sketchup.set_part_material(JSON.stringify({ role_key: partCard.role_key, material_id: v,
        cabinet_id: partCard.cabinet_id, create_missing_abs: !!createAbs,
        catalog_schema: (typeof PANEL_CLIENT_SCHEMA !== 'undefined' ? PANEL_CLIENT_SCHEMA : 1) }));
  }
  // F3/N7: prekresli options KAZDEHO ABS selectu dielca podla materialu (2A-3b:
  // parameter je material_id), zachova hodnotu (aj mimo katalogu — F5).
  // Programove nastavenie value NEstriela change event.
  // D-102 (audit F4): pri LOKALNOM pregrupovani po zmene materialu sa serverovy
  // text „podľa pravidla" VEDOME nepouzije — patri Este STAREMU materialu.
  // Ostane neutralne „(podľa pravidla)", spravnu hodnotu doplni Ruby echo.
  function regroupPartEdges(materialId){
    var box = el('edgeRows'); if (!box) return;
    var sels = box.querySelectorAll('select[data-edge]');
    for (var i=0;i<sels.length;i++){
      var cur = sels[i].value;
      sels[i].innerHTML = edgeOptionsHtml(materialId, cur);
      sels[i].value = cur;
    }
    nxComboSync(box); // D-85: pregrupovane volby -> obnov popisky triggerov
  }
  // Spat z karty dielca na skrinku (omrvinka) — Ruby oznaci korpus a poslе novy stav.
  // Codex #168 P2 (4. kolo): callback je asynchronny, takze nesie IDENTITU toho,
  // z coho sa odchadza — dokument aj dielec. Bez toho by oneskoreny klik oznacil
  // rovnomennu skrinku v CUDZOM dokumente (ID sa naprie dokumentmi opakuju),
  // pripadne prepisal novsi vyber v tom istom.
  function backToCabinet(){
    if (!partCard) return;
    if (window.sketchup && sketchup.select_cabinet)
      sketchup.select_cabinet(JSON.stringify({ cabinet_id: partCard.cabinet_id,
                                               role_key: partCard.role_key,
                                               model_guid: (typeof NXShell !== 'undefined' && NXShell)
                                                 ? NXShell.identityGuid() : '' }));
  }
  function onEdgeChange(code, value){
    if (!partCard) return;
    if (window.sketchup && sketchup.set_part_edge)
      sketchup.set_part_edge(JSON.stringify({ role_key: partCard.role_key, edge: code, abs_id: value, cabinet_id: partCard.cabinet_id }));
  }
  // D-35: olep vsetky 4 hrany ABS 1.0 dekoru materialu dielca — JEDEN callback,
  // Ruby spravi JEDEN rebuild (1 undo). Identity guard: payload nesie cabinet_id
  // AJ role_key, Ruby overi oboje proti aktualne oznacenemu dielcu.
  function onEdgesAll(){
    if (!partCard) return;
    // D-41 C2: dekor bez pouzitelnej pasky -> ponuka dovytvorenia; "Bez ABS" tu
    // znamena poslat bez flagu (server vrati dnesnu hlasku s navodom).
    var decor = decorOfSheet(partCard.material_id);
    if (!absUsableForSheet(MATERIALS.edges, sheetRecOf(partCard.material_id), catalogSchemaNow(), parseFloat(partCard.thickness))){
      openAbsModal('Dekor „' + decor + '" nemá použiteľnú ' + absMissingLabel(catalogSchemaNow()) + ' — bez nej sa hrany nedajú olepiť.',
        function(create){ sendEdgesAll(create); }, null);
      return;
    }
    sendEdgesAll(false);
  }
  function sendEdgesAll(createAbs){
    if (!partCard) return;
    if (window.sketchup && sketchup.set_part_edges_all)
      sketchup.set_part_edges_all(JSON.stringify({ cabinet_id: partCard.cabinet_id, role_key: partCard.role_key,
        create_missing_abs: !!createAbs,
        catalog_schema: (typeof PANEL_CLIENT_SCHEMA !== 'undefined' ? PANEL_CLIENT_SCHEMA : 1) }));
  }
  // ===== D-89 (a): HOVER HRANY -> ZVYRAZNENIE V MODELI =======================
  // Kurzor nad hranou (riadok zoznamu ALEBO farebny pas v 2D nahlade) rozsvieti
  // tu istu hranu priamo v modeli. Zvyraznenie kresli Ruby Overlay NAD modelom
  // (HoverEdge) — ziadny zapis, ziadny krok Spat, po odchode kurzora v modeli
  // nic neostane.
  //
  // Zasady:
  //  * POSIELA SA LEN ZMENA. Pohyb mysou vystreli desiatky `mouseover` udalosti
  //    v tom istom riadku — bez tohto filtra by kazda z nich bezala cez most do
  //    Ruby a prekreslila pohlad.
  //  * KOD HRANY je jediny udaj. Ktory dielec sa zvyraznuje, urcuje VYBER v
  //    modeli (karta je jeho zrkadlo) — JS ziadnu identitu dielca neposiela.
  //  * ZHASINA SA VZDY, ked karta zmizne alebo sa prekresli: `mouseout` na
  //    prekreslenom uzle uz nepride (vzor clearFrontHover).
  var nxHoverEdgeCode = '';
  function nxHoverEdgeSend(code){
    var c = String(code || '');
    if (c === nxHoverEdgeCode) return;
    nxHoverEdgeCode = c;
    if (window.sketchup && sketchup.nx_hover_edge){
      sketchup.nx_hover_edge(JSON.stringify({ code: c,
        model_guid: (typeof NXShell !== 'undefined' && NXShell) ? NXShell.identityGuid() : '' }));
    }
  }
  function nxHoverEdgeClear(){ nxHoverEdgeSend(''); }
  // Kontajnery, v ktorych hover znamena „hrana dielca": zoznam hran a 2D nahlad
  // karty DIELCA aj karty DOSKY. Mimo nich sa `data-edge` nevyskytuje, ale
  // zoznam je explicitny zamerne — hover nesmie zacat svietit z ineho miesta.
  var NX_HOVER_EDGE_BOXES = ['edgeRows', 'partSvg', 'boardEdgeRows', 'boardSvg'];
  function nxHoverEdgeCodeAt(node){
    var n = node;
    while (n && n !== document.body){
      if (n.getAttribute && n.getAttribute('data-edge')) return n.getAttribute('data-edge');
      if (n.id && NX_HOVER_EDGE_BOXES.indexOf(n.id) >= 0) return '';
      n = n.parentNode;
    }
    return '';
  }
  function nxHoverEdgeInBox(node){
    var n = node;
    while (n && n !== document.body){
      if (n.id && NX_HOVER_EDGE_BOXES.indexOf(n.id) >= 0) return true;
      n = n.parentNode;
    }
    return false;
  }
  function setupHoverEdge(){
    if (typeof document === 'undefined') return;
    document.addEventListener('mouseover', function(ev){
      if (!nxHoverEdgeInBox(ev.target)){ nxHoverEdgeClear(); return; }
      nxHoverEdgeSend(nxHoverEdgeCodeAt(ev.target));
    }, true);
    // Odchod kurzora z okna (CEF posiela relatedTarget null) — bez toho by
    // ploska ostala svietit, kym sa pouzivatel nevrati do panela.
    document.addEventListener('mouseout', function(ev){
      if (ev.relatedTarget) return;
      nxHoverEdgeClear();
    }, true);
  }

  // Klik na hranu v 2D dielci -> fokus jej dropdownu (delegovane, poucenie z drag fixu).
  function setupPartSvgDelegation(){
    var svg = el('partSvg'); if(!svg) return;
    svg.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'ehit'); if(!t) return;
      var code = t.getAttribute('data-edge');
      var sel = el('edgeRows').querySelector('select[data-edge="'+code+'"]');
      // len fokus + status; class 'ovr' (vizual override) patri az realnemu overridu z onEdgeChange
      // D-85: nativny select je skryty — klik na hranu preto rovno OTVORI combobox
      // (fokus zostava fallbackom, keby komponent nebezal).
      if (sel){
        // UI-B1 (Codex #168 P2): karta dielca zije v sektore Nastavenia — zbaleny
        // sektor by combobox otvoril z nulovej plochy, preto sa cesta rozbali.
        if (typeof nxRevealTarget === 'function') nxRevealTarget(sel);
        if (!(typeof NXCombo !== 'undefined' && NXCombo && NXCombo.open(sel))) sel.focus();
        NX.setStatus('Hrana '+code+' — vyber ABS v zozname.', false);
      }
    });
  }

