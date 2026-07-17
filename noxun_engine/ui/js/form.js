  // --- zber ---
  function collectConstruction(){
    return {
      type: getType(),
      width: val('width'), height: val('height'), depth: val('depth'), thickness: val('thickness'),
      floor_height: val('floor_height'),
      bottom_mode: val('bottom_mode'), top_mode: val('top_mode'), back_mode: val('back_mode'),
      back_thickness: val('back_thickness'),
      plinth_mode: val('plinth_mode'), plinth_recess: val('plinth_recess'),
      rail_depth: val('rail_depth'), rails_orientation: val('rails_orientation'), rails_top_offset: val('rails_top_offset')
    };
  }
  function collectFronts(){
    var items = [];
    var rows = el('frontRows').querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var r = rows[i];
      var type = r.querySelector('.ftype').value;
      var hv = r.querySelector('.fh').value.trim();
      var locked = r.querySelector('.flock').checked;
      var wings = r.querySelector('.fw').value;
      var hasH = hv !== '';
      items.push({ id: r.dataset.frontId || newStableId('F'), type: type, mode: hasH ? 'fixed' : 'auto',
        height: hasH ? hv : null, locked: hasH ? locked : false, wings: (type === 'door') ? wings : '1' });
    }
    return { split_axis: 'height', gap: 3.0, gap_top: 2.0, gap_bottom: 2.0, gap_sides: 2.0, items: items };
  }
  function collectAll(){ var c = collectConstruction(); c.fronts = collectFronts(); return c; }

  // --- validacia poli (clamp + cerveny okraj, ziadne modaly) ---
  var LIMITS = { width:[200,3000], height:[200,3000], depth:[150,2000], thickness:[6,50],
                 floor_height:[0,500], plinth_recess:[0,300], rail_depth:[20,400], rails_top_offset:[0,500] };
  function validateFields(){
    var ok = true;
    for (var id in LIMITS){
      var e = el(id); if (!e) continue;
      var v = parseFloat(e.value);
      if (e.value === '' || isNaN(v)){ e.classList.remove('bad'); continue; }
      var lo = LIMITS[id][0], hi = LIMITS[id][1];
      if (v < lo || v > hi){ e.classList.add('bad'); ok = false; } else { e.classList.remove('bad'); }
    }
    return ok;
  }

  // fix #2: refresh nahladu BEZ auto-apply. Pouzity pri vybere sablony (sablona = len preview;
  // aplikuje ju vyhradne tlacidlo "Pouzi sablonu na oznaceny", vratane zon zo sablony).
  function refreshPreview(){ validateFields(); renderPreview(); updateAvailable(); }

  // --- AUTO-APPLY (debounce 400 ms) ---
  function onField(){
    validateFields();
    refreshMaterialFilters();              // FIX 2: hrubka sa mohla zmenit -> prefiltruj material selecty
    renderPreview();
    updateAvailable();
    if (!selectedCabId) return;            // nic oznacene -> len nahlad, ziadny rebuild
    if (applyTimer) clearTimeout(applyTimer);
    applyTimer = setTimeout(function(){
      if (!validateFields()) { NX.setStatus('Skontroluj červené polia (mimo rozsahu).', true); return; }
      if (window.sketchup && sketchup.apply_all) sketchup.apply_all(JSON.stringify(collectAll()));
    }, 400);
  }

  function updateAvailable(){
    // pri oznacenom pouzijeme presne z backendu; inak lokalny odhad
    var t = numv('thickness') || 18, w = numv('width') || 0, h = numv('height') || 0, d = numv('depth') || 0;
    var fh = numv('floor_height') || 0;
    var topNone = val('top_mode') === 'none';
    setVal('av_width', Math.max(0, Math.round(w - 2*t)));
    setVal('av_depth', Math.round(d));
    setVal('av_height', Math.max(0, Math.round(h - fh - t - (topNone ? 0 : t))));
  }

  // --- defaulty / viditelnost ---
  function setDefaults(t){
    var d = DEFAULTS[t] || {};
    setNum('width', d.width); setNum('height', d.height); setNum('depth', d.depth); setNum('thickness', d.thickness);
    setNum('floor_height', d.floor_height);
    setVal('bottom_mode', d.bottom_mode); setVal('top_mode', d.top_mode); setVal('back_mode', d.back_mode);
    setNum('back_thickness', d.back_thickness || 3);
    setVal('plinth_mode', d.plinth_mode); setNum('plinth_recess', d.plinth_recess);
    setVal('rails_orientation', d.rails_orientation); setNum('rails_top_offset', d.rails_top_offset); setNum('rail_depth', d.rail_depth);
    applyVisibility(t);
  }
  function applyVisibility(t){
    el('plinthGroup').style.display = (t === 'upper') ? 'none' : '';
    toggleRecess(); toggleTwoRails();
  }
  function toggleRecess(){ el('recessRow').style.display = (val('plinth_mode') === 'front') ? '' : 'none'; }
  function toggleTwoRails(){ el('twoRailsGroup').style.display = (val('top_mode') === 'two_rails') ? '' : 'none'; }

  function onTypeChange(){
    setDefaults(getType());
    el('template').value = '';
    currentZoneTree = defaultTree();
    renderFilteredTemplates();
    onField();
  }

  // --- sablony (filter podla typu) ---
  function renderFilteredTemplates(){
    var t = getType();
    var sel = el('template'); var cur = sel.value;
    sel.innerHTML = '<option value="">— vyber —</option>';
    TEMPLATES.forEach(function(tp){
      var tt = (tp.config && tp.config.type) ? tp.config.type : 'lower';
      if (tt !== t) return;
      var o = document.createElement('option'); o.value = tp.name; o.textContent = tp.name; sel.appendChild(o);
    });
    sel.value = cur;
  }
  function onTemplateChange(){
    var name = val('template'); if (!name) return;
    var tp = null;
    for (var i = 0; i < TEMPLATES.length; i++){ if (TEMPLATES[i].name === name){ tp = TEMPLATES[i]; break; } }
    if (!tp) return;
    var c = tp.config || {};
    setType(c.type || 'lower');
    setNum('width', c.width); setNum('height', c.height); setNum('depth', c.depth); setNum('thickness', c.thickness);
    setNum('floor_height', c.floor_height);
    setVal('bottom_mode', c.bottom_mode); setVal('top_mode', c.top_mode); setVal('back_mode', c.back_mode);
    setNum('back_thickness', c.back_thickness || 3);
    setVal('plinth_mode', c.plinth_mode); setNum('plinth_recess', c.plinth_recess);
    setVal('rails_orientation', c.rails_orientation); setNum('rails_top_offset', c.rails_top_offset); setNum('rail_depth', c.rail_depth);
    applyVisibility(c.type || 'lower');
    renderFronts(c.fronts);
    currentZoneTree = c.zone_tree ? sanitizeTree(c.zone_tree) : defaultTree();
    // fix #2: vyber sablony NEspusti apply_all — len naplni polia + nahlad. Korpus sa NEZMENI,
    // kym uzivatel nestlaci "Pouzi sablonu na oznaceny".
    refreshPreview();
    refreshZoneUI();
  }
  function saveTemplate(){
    var p = collectConstruction(); p.fronts = collectFronts(); p.zone_tree = currentZoneTree;
    if (window.sketchup && sketchup.save_template) sketchup.save_template(JSON.stringify(p));
  }
  function deleteTemplate(){
    var name = val('template'); if (!name){ NX.setStatus('Vyber šablónu.', true); return; }
    if (window.sketchup && sketchup.delete_template) sketchup.delete_template(JSON.stringify({ template: name }));
  }
  function applyTemplateToSelected(){
    if (el('applyTplBtn').disabled) return;
    var name = val('template'); if (!name){ NX.setStatus('Vyber šablónu.', true); return; }
    if (window.sketchup && sketchup.apply_template) sketchup.apply_template(JSON.stringify({ template: name }));
  }

  // --- cela riadky ---
  function addFrontRow(item){
    item = item || {};
    var wrap = el('frontRows');
    var idx = wrap.querySelectorAll('.frow').length + 1;
    var row = document.createElement('div');
    row.className = 'frow';
    row.dataset.frontId = item.id || newStableId('F');
    row.innerHTML =
      '<span class="fnum">' + idx + '</span>' +
      '<select class="ftype" onchange="onFrontTypeChange(this); onField()">' +
        '<option value="door">Dvierka</option><option value="drawer_front">Zásuvkové čelo</option></select>' +
      '<input class="fh" type="number" step="1" placeholder="auto" oninput="onField()">' +
      '<select class="fw" onchange="onField()"><option value="auto">auto</option><option value="1">1</option><option value="2">2</option></select>' +
      '<input class="flock" type="checkbox" title="Zamknúť pevnú výšku" onchange="onField()">' +
      '<button class="fdel" title="Odstrániť" onclick="delFrontRow(this); onField()">✕</button>';
    wrap.appendChild(row);
    if (item.type) row.querySelector('.ftype').value = item.type;
    if (item.height !== null && item.height !== undefined && item.height !== '') row.querySelector('.fh').value = item.height;
    if (item.wings) row.querySelector('.fw').value = item.wings;
    if (item.locked) row.querySelector('.flock').checked = true;
    onFrontTypeChange(row.querySelector('.ftype'));
  }
  function onFrontTypeChange(sel){ var row = sel.closest('.frow'); row.querySelector('.fw').style.visibility = (sel.value === 'door') ? 'visible' : 'hidden'; }
  function delFrontRow(btn){ btn.closest('.frow').remove(); renumberFronts(); }
  function removeLastFront(){ var rows = el('frontRows').querySelectorAll('.frow'); if (rows.length) { rows[rows.length-1].remove(); renumberFronts(); } }
  function renumberFronts(){ var rows = el('frontRows').querySelectorAll('.frow'); for (var i=0;i<rows.length;i++){ rows[i].querySelector('.fnum').textContent = (i+1); } }
  function renderFronts(fronts){
    el('frontRows').innerHTML = '';
    var items = (fronts && fronts.items) ? fronts.items : [];
    for (var i = 0; i < items.length; i++){ addFrontRow(items[i]); }
  }

