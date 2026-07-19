  // V0.5 B: otvorenie okna Vyroba (kusovnik/supisy). Najprv flush cakajucich
  // editov korpusu/dosky (Codex GH #48 P2) — BOM sa pocita az z cerstveho stavu
  // (callbacky sa spracuju v poradi: apply -> open -> push_state).
  function openProductionDialog(){
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
    if (window.sketchup && sketchup.open_production) sketchup.open_production('');
  }

  // ===================== ZONA UI (akcie / rozmery poli) =====================
  // V0.4.5 D1: karta zony (#zoneCard) sa zobrazuje LEN pri kliknutej zone — hned pod
  // nahladom, kde na nu pouzivatel klikol. Bez vyberu je cela karta skryta.
  function refreshZoneUI(){
    var zones = computeZones();
    var z = null; zones.forEach(function(x){ if (fullZoneId(x.id) === activeZoneId) z = x; });
    var card = el('zoneCard'), leafBox = el('leafActions'), fieldBox = el('fieldEditor');
    // D-03 (Codex F2): karta zony patri k zonovemu nahladu — v rezime Cela sa skryva
    if (previewMode !== 'zones'){
      if (card) card.style.display = 'none';
      setZoneButtons(false); fieldBox.innerHTML=''; renderZoneTree(zones); return;
    }
    // D-03: jednozonova skrinka = karta rovno (discoverability polic). Podmienka !z
    // pokryva prazdne AJ neplatne stale ID (Codex F3). Lokalny vyber — select_zone
    // do modelu sa neposiela (to robi len klik v pickZone). Pri vkladani DOSKY sa
    // auto-select nespusta (Codex GH #42: zoneCard by visela nad board formularom
    // a ovladala skryty korpusovy draft — CSS skrytie nie je ochrana stavu).
    if (!z && zones.length === 1 && zones[0].leaf &&
        !(!selectedCabId && getInsertKind() === 'board')){
      activeZoneId = fullZoneId(zones[0].id);
      z = zones[0];
      renderPreview(); // nahlad sa kreslil pred auto-selectom — zvyrazni zonu (Codex F1)
    }
    if (!z){
      if (card) card.style.display = 'none';
      setZoneButtons(false); fieldBox.innerHTML=''; renderZoneTree(zones); return;
    }
    if (card) card.style.display = '';
    el('zoneActive').innerHTML = '<b>' + z.label + '</b> — ' + Math.round(z.w) + '×' + Math.round(z.h) + ' mm';
    if (z.leaf){
      leafBox.style.display=''; fieldBox.innerHTML='';
      setVal('zoneShelves', z.shelves||0);
      setZoneButtons(true);
    } else {
      leafBox.style.display='none';
      renderFieldEditor(z);
      var b = document.querySelectorAll('.zbtn'); for (var i=0;i<b.length;i++) b[i].disabled=false; // clean zostava aktivne
    }
    renderZoneTree(zones);
  }
  // Riadky poli cez data-atributy + delegaciu (setupFieldEditorDelegation) — ziadne inline
  // handlery na prerendrovanych elementoch (poucenie z drag bugu).
  function renderFieldEditor(z){
    var box = el('fieldEditor'); var html = '<div class="hint">Presné rozmery polí (mm). 🔒 = drží rozmer pri zmene korpusu.</div>';
    var axisLbl = (z.split.axis==='h') ? 'Riadok' : 'Stĺpec';
    for (var i=0;i<z.split.count;i++){
      var c = z.split.cuts[i] || {size:null,locked:false};
      var sz = Math.round(z.split.sizes[i]);
      html += '<div class="fldrow"><span class="fldn">'+axisLbl+' '+(i+1)+'</span>' +
        '<input type="text" value="'+sz+'" data-zid="'+esc(z.id)+'" data-idx="'+i+'">' +
        '<div class="lockbtn'+(c.locked?' on':'')+'" title="Zamknúť rozmer" data-zid="'+esc(z.id)+'" data-idx="'+i+'">'+(c.locked?'🔒':'🔓')+'</div></div>';
    }
    box.innerHTML = html;
    // V0.4.7e: vyrazy v poliach zon — commit (Enter/blur) prepise pole cislom
    // a dispatchne 'change', ktory chyti delegacia nizsie.
    box.querySelectorAll('input[data-zid]').forEach(function(inp){
      attachExprField(inp, { commitEv: 'change' });
    });
  }
  // Jeden listener na kontajneri — prezije kazdy re-render riadkov.
  var fieldEditorBound = false;
  function setupFieldEditorDelegation(){
    if (fieldEditorBound) return;
    var box = el('fieldEditor'); if (!box) return;
    box.addEventListener('change', function(ev){
      var t = ev.target;
      if (t && t.tagName === 'INPUT' && t.getAttribute('data-zid'))
        setFieldSize(t.getAttribute('data-zid'), parseInt(t.getAttribute('data-idx'), 10), t.value);
    });
    box.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'lockbtn');
      if (t && t.getAttribute('data-zid'))
        toggleFieldLock(t.getAttribute('data-zid'), parseInt(t.getAttribute('data-idx'), 10), t);
    });
    fieldEditorBound = true;
  }
  function setFieldSize(localId, index, value){
    var node0 = navTree(sanitizeTree(currentZoneTree), pathOf(localId));
    if (!node0 || !node0.split) return;
    var locked = node0.split.cuts[index] ? node0.split.cuts[index].locked : false;
    // V0.4.7e: evalDim (vyraz uz je commitnuty na cislo, toto je belt-and-braces);
    // neplatny vstup NEmeni strom (parseFloat by '650-36' orezal na 650)
    var sz = (value===''? null : evalDim(value));
    if (sz !== null && isNaN(sz)) return;
    if (sz==null){
      // auto: toto pole na nil (ostatne necham; resolve ho rovnomerne dopocita)
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localId));
      node.split.cuts[index] = { size:null, locked:false }; currentZoneTree = tree;
    } else {
      // fix #5: kotva na zadany rozmer + persistni cely layout -> zadany rozmer nezmizne
      persistLayout(localId, index, sz, locked);
    }
    renderPreview();
    if (selectedCabId) pushFieldCuts(localId, index);
    else refreshZoneUI();
  }
  function toggleFieldLock(localId, index, elBtn){
    var node0 = navTree(sanitizeTree(currentZoneTree), pathOf(localId));
    if (!node0 || !node0.split) return;
    var cur = node0.split.cuts[index] || { size:null, locked:false };
    var newLocked = !cur.locked;
    var sizes = null; computeZones().forEach(function(z){ if(z.id===localId && z.split) sizes=z.split.sizes; });
    var anchorSize = (cur.size!=null) ? cur.size : (sizes ? Math.round(sizes[index]) : null);
    // fix #5: kotva na aktualny rozmer pola + persistni cely layout so zmenenym lockom
    persistLayout(localId, index, anchorSize, newLocked);
    renderPreview();
    if (selectedCabId) pushFieldCuts(localId, index);
    else refreshZoneUI();
  }

  // --- strom zon (citatelne nazvy) ---
  function renderZoneTree(zones){
    var c = el('zoneTree'); c.innerHTML = '';
    if (!zones || !zones.length){ c.innerHTML = '<div class="muted">Žiadny označený korpus.</div>'; return; }
    zones.forEach(function(z){
      var depth = z.path.length - 1;
      var div = document.createElement('div');
      div.className = 'znode' + (fullZoneId(z.id) === activeZoneId ? ' active' : '');
      div.style.paddingLeft = (6 + depth * 14) + 'px';
      var info = z.leaf ? (z.shelves>0 ? (z.shelves+' políc') : 'prázdna')
                        : ('delené ' + (z.split.axis==='h'?'vodorovne':'zvislo') + ' ×' + z.split.count);
      div.innerHTML = '<b>' + z.label + '</b> <span class="dim">' + Math.round(z.w) + '×' + Math.round(z.h) + '</span> <span class="zs">' + info + '</span>';
      div.onclick = (function(zz){ return function(){ pickZone(zz.id); }; })(z);
      c.appendChild(div);
    });
  }
  function setZoneButtons(on){ var b = document.querySelectorAll('.zbtn'); for (var i=0;i<b.length;i++) b[i].disabled = !on; }

  function splitZone(axis){
    if (!activeZoneId){ NX.setStatus('Najprv označ zónu.', true); return; }
    var count = parseInt(axis === 'h' ? val('splitHCount') : val('splitVCount'), 10);
    if (selectedCabId){
      if (window.sketchup && sketchup.split_zone) sketchup.split_zone(JSON.stringify({ zone_id: activeZoneId, axis: axis, count: count }));
    } else {
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localZoneId(activeZoneId)));
      if (node){
        node.generation = (node.generation || 0) + 1;
        node.split={axis:axis,count:count,cuts:sanitizeCuts(null,count)};
        node.shelves=0;
        node.children=[];
        for(var i=0;i<count;i++) node.children.push(defaultTree(0, newStableId('Z')));
      }
      currentZoneTree = tree; renderPreview(); refreshZoneUI();
    }
  }
  function setZoneShelves(){
    if (!activeZoneId){ NX.setStatus('Najprv označ zónu.', true); return; }
    var n = parseInt(val('zoneShelves'), 10);
    if (selectedCabId){
      if (window.sketchup && sketchup.set_zone_shelves) sketchup.set_zone_shelves(JSON.stringify({ zone_id: activeZoneId, count: n }));
    } else {
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localZoneId(activeZoneId)));
      if (node){ node.split=null; node.children=[]; node.shelves=n; }
      currentZoneTree = tree; renderPreview(); refreshZoneUI();
    }
  }
  function cleanZone(){
    if (!activeZoneId){ NX.setStatus('Najprv označ zónu.', true); return; }
    if (selectedCabId){
      if (window.sketchup && sketchup.clean_zone) sketchup.clean_zone(JSON.stringify({ zone_id: activeZoneId }));
    } else {
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localZoneId(activeZoneId)));
      if (node){ node.split=null; node.children=[]; node.shelves=0; }
      currentZoneTree = tree; renderPreview(); refreshZoneUI();
    }
  }

  // --- korpus akcie ---
  function insertCabinet(){
    // V0.4.7e (Codex GH #35): vlozenie MUSI prejst validaciou — neplatny rozmer
    // ('650mm') by sa inak ticho zmenil na default a neplatna vyska cela na auto.
    if (!validateFields()){ NX.setStatus('Skontroluj červené polia (neplatný rozmer).', true); return; }
    var p = collectAll(); p.zone_tree = currentZoneTree;
    if (window.sketchup && sketchup.insert_cabinet) sketchup.insert_cabinet(JSON.stringify(p));
  }
  function toggleZones(){ var on = el('zonesChk').checked; if (window.sketchup && sketchup.toggle_zones) sketchup.toggle_zones(on ? 'true' : 'false'); }

  function setSelected(cid){
    selectedCabId = cid;
    // (applyTplBtn zije v okne Sablony — disabled stav riesi TemplatesDialog.push_state)
  }

