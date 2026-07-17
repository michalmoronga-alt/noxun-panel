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
    if (!pc){ box.style.display='none'; return; }
    box.style.display='';
    el('pcName').innerHTML = '<b>'+esc(pc.name || roleLabel(pc.role))+'</b> · '+esc(roleLabel(pc.role));
    el('pcDim').textContent = fmtmm(pc.length)+' × '+fmtmm(pc.width)+' × '+fmtmm(pc.thickness)+' mm';
    // FIX 2: material dielca len z hrubkovo kompatibilnych dosiek (nekompatibilne disabled). Cela
    // beru 18/19 mm (rovnako ako builder guard aj korpusovy select), ostatne presnu hrubku dielca.
    var isFront = (pc.role === 'front_door' || pc.role === 'drawer_front');
    var matFn = isFront ? frontMatch() : thMatch(pc.thickness);
    var selectedMaterial = pc.has_material_override ? (pc.material_id || '') : '';
    var inheritLabel = '(dedí: '+sheetLabelOf(pc.material_id)+')';
    var ms = el('pcMaterial');
    fillSheetSelectFiltered(ms, true, matFn, selectedMaterial, inheritLabel);
    ms.value = selectedMaterial;
    ms.className = pc.has_material_override ? 'ovr' : '';
    renderEdgeRows(pc);
    renderPartSvg(pc);
  }
  function renderEdgeRows(pc){
    var box = el('edgeRows'); box.innerHTML='';
    ['L1','L2','W1','W2'].forEach(function(code){
      var lbl = (pc.edge_labels && pc.edge_labels[code]) || code;
      var absId = pc.edges ? pc.edges[code] : null;
      var isOvr = hasOwn(pc.edge_overrides, code);
      var row = document.createElement('div'); row.className='edgerow';
      row.innerHTML = '<span class="en"><i style="background:'+absColorOf(absId)+'"></i>'+esc(lbl)+'</span>';
      var sel = document.createElement('select');
      sel.innerHTML = edgeOptionsHtml();
      sel.value = isOvr ? (absId==null?'':absId) : '__inherit__';
      if (isOvr) sel.className='ovr';
      sel.setAttribute('data-edge', code);
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
    var edges = pc.edges||{}, lab = pc.edge_labels||{};
    function ecol(code){ return absColorOf(edges[code]); }
    // Farebny bar (klik-target) danej strany obdlznika.
    function bar(side, code, fill){
      if (side==='top')    return '<rect class="ehit" data-edge="'+code+'" x="'+ox+'" y="'+(oy-ew/2)+'" width="'+rw+'" height="'+ew+'" fill="'+fill+'" style="cursor:pointer"/>';
      if (side==='bottom') return '<rect class="ehit" data-edge="'+code+'" x="'+ox+'" y="'+(oy+rh-ew/2)+'" width="'+rw+'" height="'+ew+'" fill="'+fill+'" style="cursor:pointer"/>';
      if (side==='left')   return '<rect class="ehit" data-edge="'+code+'" x="'+(ox-ew/2)+'" y="'+oy+'" width="'+ew+'" height="'+rh+'" fill="'+fill+'" style="cursor:pointer"/>';
      return '<rect class="ehit" data-edge="'+code+'" x="'+(ox+rw-ew/2)+'" y="'+oy+'" width="'+ew+'" height="'+rh+'" fill="'+fill+'" style="cursor:pointer"/>'; // right
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
      S.push(label(side, lab[code]));
    });
    S.push('<text x="150" y="100" font-size="12" fill="#b0bec5" text-anchor="middle" dominant-baseline="middle" pointer-events="none">'+Math.round(L)+'×'+Math.round(Wd)+'</text>');
    svg.innerHTML = S.join('');
  }
  function onPartMaterial(){
    if (!partCard) return;
    var v = el('pcMaterial').value;
    if (window.sketchup && sketchup.set_part_material)
      sketchup.set_part_material(JSON.stringify({ role_key: partCard.role_key, material_id: v }));
  }
  function onEdgeChange(code, value){
    if (!partCard) return;
    if (window.sketchup && sketchup.set_part_edge)
      sketchup.set_part_edge(JSON.stringify({ role_key: partCard.role_key, edge: code, abs_id: value }));
  }
  // Klik na hranu v 2D dielci -> fokus jej dropdownu (delegovane, poucenie z drag fixu).
  function setupPartSvgDelegation(){
    var svg = el('partSvg'); if(!svg) return;
    svg.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'ehit'); if(!t) return;
      var code = t.getAttribute('data-edge');
      var sel = el('edgeRows').querySelector('select[data-edge="'+code+'"]');
      if (sel){ sel.focus(); sel.classList.add('ovr'); NX.setStatus('Hrana '+code+' — vyber ABS v zozname.', false); }
    });
  }

