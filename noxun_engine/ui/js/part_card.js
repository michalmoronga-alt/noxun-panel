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
    // UI-D1: „Zakladne hore" — rozmery a smer dekoru ako INFORMACNE riadky.
    renderPartBasic(pc);
    // UI-D1: otvoreny modal „Použiť na podobné…" patri KONKRETNEMU dielcu —
    // prekreslenie karty na iny dielec (alebo inu skrinku) ho musi zavriet,
    // inak by oneskorene „Použiť" zapisalo olep z dielca, ktory uz nie je na
    // obrazovke (vzor tplModalStale + absModalCloseSilent).
    if (simModalStale(pc)) closeSimilarModal();
    // Codex #180 P2: prekreslenie karty s TOU ISTOU identitou (Späť/Znova, zmena
    // katalógu, echo push) modal nezavrie — ale mohlo zmenit material dielca
    // alebo pocet cielov. Bez noveho dopytu by okno drzalo STARY pocet a slubilo
    // by zmenu piatich dielcov tam, kde uz ziadny nie je (server pri zapise ráta
    // nanovo). Pocet sa preto vypyta znova; odpoved meni LEN obsah modalu.
    // Pocet sa najprv zhodi na „počítam" (tlacidlo je dovtedy neaktivne) — inak
    // by okno v case letu odpovede stale ukazovalo staru hodnotu ako platnu.
    else if (simModalOpen()){ simCount = null; applySimCountView(); requestSimilarCount(); }
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
  // ===== UI-D1: ZAKLADNE HORE (kontrakt UI 2.0, sekcia Dielec) ==============
  // Rozmery dielca su VYSTUP — pocita ich korpus zo svojich rozmerov a hrubky.
  // Preto su to informacne riadky (text), nie polia: „vystup nikdy nevyzera ako
  // vstup" (trvala zasada z kol 15.8., rovnaky vzor ako `.infocol` Zakladnych).
  //
  // VEDOMA ODCHYLKA od mockupu: `Smer dekoru` je tu tiez INFORMACIA, nie
  // rozbalovacka. Smer dielca korpusu urcuje jeho MATERIAL (katalogove pole
  // `grain` sheetu) — per-dielec override by bol novy kluc v `part_overrides`,
  // teda zmena vyrobneho kontraktu (kusovnik, VEPO rotacia, validacia narezu).
  // To je vlastna davka s auditom; tvarit sa, ze pole funguje, by bola lož.
  var PC_GRAIN_LABEL = { length: 'Po dĺžke', width: 'Po šírke', none: 'Bez smeru' };
  function nxGrainLabel(g){ return PC_GRAIN_LABEL[String(g == null ? '' : g)] || 'Bez smeru'; }
  // Ciste skladanie riadkov (testovane v Node): dva a dva, aby karta narastla
  // o JEDEN riadok oproti povodnemu `pcDim` — vertikalny priestor je vzacny.
  function nxPartBasicRows(pc){
    var p = pc || {};
    return {
      left: [ { label: 'Dĺžka', value: fmtmm(p.length), unit: 'mm' },
              { label: 'Šírka', value: fmtmm(p.width), unit: 'mm' } ],
      right: [ { label: 'Hrúbka', value: fmtmm(p.thickness), unit: 'mm',
                 title: 'Hrúbku dielca určuje materiál korpusu.' },
               { label: 'Smer dekoru', value: nxGrainLabel(p.grain_direction), unit: '',
                 title: 'Smer dekoru určuje materiál dielca — mení sa v katalógu materiálov.' } ]
    };
  }
  function nxInfoRowHtml(r){
    var v = esc(r.value) + (r.unit ? (' ' + esc(r.unit)) : '');
    return '<div class="inforow"' + (r.title ? (' title="' + esc(r.title) + '"') : '') + '>' +
           '<span>' + esc(r.label) + '</span><b>' + v + '</b></div>';
  }
  function renderPartBasic(pc){
    var L = el('pcBasicL'), R = el('pcBasicR');
    if (!L || !R) return;
    var rows = nxPartBasicRows(pc);
    L.innerHTML = rows.left.map(nxInfoRowHtml).join('');
    R.innerHTML = rows.right.map(nxInfoRowHtml).join('');
  }

  // Hranova ikona: JEDNA kresba (#i-edge), styri ROTACIE. Uhol sa berie zo
  // STRANY 2D nahladu (`pc.edge_sides` = AbsRules.edge_sides, jediny zdroj
  // pravdy o orientacii dielca), takze ikona ukazuje presne tu hranu, ktoru
  // nahlad nad zoznamom farebne kresli.
  var PC_EDGE_ROT = { top: 0, right: 90, bottom: 180, left: 270 };
  function nxEdgeRotOf(side){
    var r = PC_EDGE_ROT[String(side == null ? '' : side)];
    return (r === undefined) ? 0 : r;
  }
  function renderEdgeRows(pc){
    var box = el('edgeRows'); box.innerHTML='';
    var sides = pc.edge_sides || { L1:'bottom', L2:'top', W1:'left', W2:'right' };
    ['L1','L2','W1','W2'].forEach(function(code){
      var lbl = (pc.edge_labels && pc.edge_labels[code]) || code;
      var absId = pc.edges ? pc.edges[code] : null;
      var isOvr = hasOwn(pc.edge_overrides, code);
      var row = document.createElement('div'); row.className='edgerow';
      // D-89a: cely riadok je hover-cielom (nielen rozbalovacka) — hrana sa
      // rozsvieti v modeli uz pri prejdeni jej NAZVU.
      row.setAttribute('data-edge', code);
      row.title = 'Kurzor nad hranou ju zvýrazní priamo v modeli.';
      row.innerHTML = '<span class="en">' +
        '<svg class="ic eic" data-rot="'+nxEdgeRotOf(sides[code])+'" aria-hidden="true"><use href="#i-edge"/></svg>' +
        '<i style="background:'+absColorOf(absId)+'"></i>'+esc(lbl)+'</span>';
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

  // ===== UI-D1: „OZNACIT V MODELI" =========================================
  // Zmena VYBERU, nie zapis: ziadna operacia, ziadny krok Spat (lekcia D-103,
  // vzor „Dielcov" z UI-B3 a boxu vlastnika z UI-C4). Payload nesie identitu
  // DOKUMENTU aj skrinky — callback HtmlDialogu je asynchronny a ID skriniek
  // sa naprie dokumentmi opakuju; server oboje PRISNE overi.
  function selectPartInModel(){
    if (!partCard){ NX.setStatus('Najprv označ dielec v korpuse.', true); return; }
    if (window.sketchup && sketchup.nx_select_part){
      sketchup.nx_select_part(JSON.stringify({
        model_guid: (typeof nxModelGuid === 'string') ? nxModelGuid : '',
        cabinet_id: partCard.cabinet_id, role_key: partCard.role_key }));
    }
  }

  // ===== UI-D1: „POUZIT NA PODOBNE…" =======================================
  // Modal prenesie OLEP HRAN tohto dielca na dielce s ROVNAKOU ROLOU a ROVNAKYM
  // MATERIALOM. Autoritou je SERVER: JS posiela len kluc dielca + rozsah, pocet
  // aj zapis pocita Ruby TOU ISTOU funkciou (`similar_parts_map`) — inak by
  // modal slubil iny pocet, nez sa naozaj zapise.
  //
  // Identita sa ZACHYTAVA pri otvoreni (dokument + skrinka + dielec) a server ju
  // overuje znova; prekreslenie karty na iny dielec modal zavrie (simModalStale).
  var simFor = null; // { guid, cabinet_id, role_key }
  var simScope = 'cabinet';
  var simCount = null; // null = este sa pocita
  var simBound = false;
  // Codex #180 P2 (kolo 2): TOKEN DOPYTU. Kontrola samotneho rozsahu nestaci —
  // po zatvoreni a otvoreni modalu nad INYM dielcom (alebo po prepnuti
  // cabinet → project → cabinet) by oneskorena odpoved na STARY dopyt mala
  // rovnaky rozsah a prepisala by pocet aj stav tlacidla noveho ciela. Kazdy
  // dopyt preto nesie rastuce cislo a klient prijme LEN odpoved na ten posledny;
  // zatvorenie modalu token tiez posunie, takze odpoved „do prazdna" prepadne.
  var simReq = 0;

  function simModalOpen(){ var m = el('simModal'); return !!(m && m.style.display !== 'none'); }
  function simModalStale(pc){
    if (!simFor) return false;
    var p = pc || {};
    return String(p.cabinet_id || '') !== simFor.cabinet_id ||
           String(p.role_key || '') !== simFor.role_key ||
           String((typeof nxModelGuid === 'string') ? nxModelGuid : '') !== simFor.guid;
  }
  function openSimilarModal(){
    if (!partCard){ NX.setStatus('Najprv označ dielec v korpuse.', true); return; }
    var m = el('simModal'); if (!m) return;
    simFor = { guid: (typeof nxModelGuid === 'string') ? nxModelGuid : '',
               cabinet_id: String(partCard.cabinet_id || ''),
               role_key: String(partCard.role_key || '') };
    simScope = 'cabinet';
    simCount = null;
    el('simWhat').innerHTML = 'Olep hrán dielca <b>' +
      esc(partCard.name || roleLabel(partCard.role)) + '</b> (' + esc(roleLabel(partCard.role)) + ').';
    applySimScopeButtons();
    applySimCountView();
    m.style.display = 'flex';
    bindSimModal();
    requestSimilarCount();
  }
  function closeSimilarModal(){
    simFor = null;
    simCount = null;
    simReq++; // odpovede na uz nepotrebne dopyty prepadnu
    var m = el('simModal'); if (m) m.style.display = 'none';
  }
  function pickSimilarScope(scope){
    if (!simModalOpen()) return;
    if (scope !== 'cabinet' && scope !== 'project') return;
    if (scope === simScope) return; // no-op: rovnaky rozsah nic neprepocitava
    simScope = scope;
    simCount = null;
    applySimScopeButtons();
    applySimCountView();
    requestSimilarCount();
  }
  function applySimScopeButtons(){
    var box = el('simScope'); if (!box) return;
    var btns = box.querySelectorAll('button[data-sim-scope]');
    for (var i = 0; i < btns.length; i++){
      var on = btns[i].getAttribute('data-sim-scope') === simScope;
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }
  // Ciste texty (testovane v Node) — slovenske tvary poctu a stav tlacidla.
  function nxSimilarCountText(n){
    if (n === null || n === undefined) return 'Počítam podobné dielce…';
    if (n === 0) return 'Žiadny podobný dielec — rovnakú rolu a materiál nemá v tomto rozsahu nikto iný.';
    if (n === 1) return 'Zmení sa 1 podobný dielec.';
    return 'Zmení sa ' + n + (n < 5 ? ' podobné dielce.' : ' podobných dielcov.');
  }
  function nxSimilarBtnState(n){
    if (n === null || n === undefined) return { enabled: false, title: 'Počet podobných dielcov sa ešte zisťuje.' };
    if (n === 0) return { enabled: false, title: 'V tomto rozsahu nie je čo zmeniť — skús celý projekt.' };
    return { enabled: true, title: 'Prepíše olep hrán ' + n + ' dielcom (jeden krok Späť).' };
  }
  function applySimCountView(){
    var c = el('simCount'), b = el('simApplyBtn');
    if (c){
      c.textContent = nxSimilarCountText(simCount);
      c.classList.toggle('none', simCount === 0);
    }
    if (b){
      var st = nxSimilarBtnState(simCount);
      b.classList.toggle('off', !st.enabled);
      b.setAttribute('aria-disabled', st.enabled ? 'false' : 'true');
      b.title = st.title;
    }
  }
  function requestSimilarCount(){
    if (!simFor) return;
    simReq++;
    if (window.sketchup && sketchup.nx_similar_parts_count){
      sketchup.nx_similar_parts_count(JSON.stringify({
        model_guid: simFor.guid, cabinet_id: simFor.cabinet_id,
        role_key: simFor.role_key, scope: simScope, req: simReq }));
    }
  }
  // Odpoved servera. Prijme sa LEN odpoved na POSLEDNY odoslany dopyt (token),
  // takze oneskorena odpoved na zavretý modal, na iny dielec ani na uz prepnuty
  // rozsah nema ako prepisat to, co pouzivatel prave vidi.
  function setSimilarCount(data){
    if (!simModalOpen()) return;
    var d = data || {};
    if (parseInt(d.req, 10) !== simReq) return;
    if (d.error){
      simCount = 0;
      applySimCountView();
      var c = el('simCount');
      if (c){ c.textContent = String(d.error); c.classList.add('none'); }
      return;
    }
    simCount = (d.count === null || d.count === undefined) ? null : parseInt(d.count, 10);
    applySimCountView();
  }
  // POZOR — TU SA FLUSH HANDSHAKE ZAMERNE NEROBI (na rozdiel od `onHwOwnerPick`,
  // „Dielcov" a „Vložiť kópiu"). `flushCabinetEditsNow` posiela `apply_all`
  // BEZPODMIENECNE a ten VZDY prestava korpus a spravi `reselect(model, cab)` —
  // teda by (1) vyrobil prazdny krok Spat a (2) zhodil z vyberu DIELEC, takze by
  // nasledny `nx_apply_edges_similar` uz nemal na com pracovat a akciu by odmietol.
  // Karta dielca navyse ziadne debounce polia NEMA: material aj hrany sa posielaju
  // okamzite na `change` — rovnako ako `onEdgeChange`, `onPartMaterial` a
  // `onEdgesAll`, ktore tiez neflushuju. Toto je teda zhoda s okolim, nie vynimka.
  function applySimilarNow(){
    if (!simFor) return;
    var st = nxSimilarBtnState(simCount);
    if (!st.enabled){ NX.setStatus(st.title, true); return; }
    if (window.sketchup && sketchup.nx_apply_edges_similar){
      sketchup.nx_apply_edges_similar(JSON.stringify({
        model_guid: simFor.guid, cabinet_id: simFor.cabinet_id,
        role_key: simFor.role_key, scope: simScope }));
    }
    closeSimilarModal();
  }
  function bindSimModal(){
    if (simBound) return; simBound = true;
    var m = el('simModal'); if (!m) return;
    // Codex #180 P1: ENTER SA TU NEODCHYTAVA. Modal nema ziadne textove pole —
    // vsetko fokusovatelne su TLACIDLA, takze Enter uz spravnu vec robi sam
    // (nativna aktivacia toho, na com stoji fokus). Globalny odchyt s
    // `preventDefault()` by naopak spravil presny opak toho, co pouzivatel
    // chce: Enter nad „Zrušiť" by hromadnu zmenu POUZIL a Enter nad
    // prepinacom rozsahu by ho neprepol.
    m.addEventListener('keydown', function(ev){
      if (ev.key === 'Escape'){ ev.preventDefault(); closeSimilarModal(); }
    });
    // klik na tmave pozadie = zrusit (klik v karte nie)
    m.addEventListener('mousedown', function(ev){ if (ev.target === m) closeSimilarModal(); });
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

  // UI-D1: export CISTYCH funkcii karty dielca pre Node testy (tests/js/
  // test_uid1_dielec.js) — skladanie informacnych riadkov, rotacie hranovych
  // ikon a texty modalu „Použiť na podobné…". V CEF je `module` undefined a
  // vetva sa preskoci (vzor hardware.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { nxGrainLabel: nxGrainLabel, nxPartBasicRows: nxPartBasicRows,
      nxEdgeRotOf: nxEdgeRotOf, nxSimilarCountText: nxSimilarCountText,
      nxSimilarBtnState: nxSimilarBtnState };
  }

