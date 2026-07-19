  // --- zber ---
  // V0.4.7e: ciselne polia sa citaju cez evalDim — surovy vyrazovy string NIKDY
  // neodide do Ruby (to_f/parseFloat by '650-36' ticho orezali na 650).
  function collectConstruction(){
    var out = { type: getType() };
    CONSTRUCTION_FIELDS.forEach(function(f){
      if (f.kind === 'num'){
        var raw = val(f.id);
        if (raw === null || String(raw).trim() === ''){ out[f.id] = ''; return; }
        var v = evalDim(raw);
        out[f.id] = isNaN(v) ? '' : v; // NaN neprejde validaciou; '' = Ruby default
      } else {
        out[f.id] = val(f.id);
      }
    });
    return out;
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
      var hNum = hasH ? evalDim(hv) : NaN; // vyraz vo vyske cela -> cislo (NaN blokuje apply cez validateFields)
      items.push({ id: r.dataset.frontId || newStableId('F'), type: type, mode: hasH ? 'fixed' : 'auto',
        height: hasH ? (isNaN(hNum) ? null : hNum) : null, locked: hasH ? locked : false, wings: (type === 'door') ? wings : '1' });
    }
    return { split_axis: 'height', gap: frontGapVal('fr_gap', 3.0), gap_top: frontGapVal('fr_gap_top', 2.0),
             gap_bottom: frontGapVal('fr_gap_bottom', 2.0), gap_sides: frontGapVal('fr_gap_sides', 2.0), items: items };
  }
  // D-07: hodnota gap pola cez evalDim (vyrazy); prazdne/nezmysel = default.
  function frontGapVal(id, dflt){ var v = numv(id); return isNaN(v) ? dflt : v; }
  function resetFrontGaps(){ setNum('fr_gap', 3); setNum('fr_gap_top', 2); setNum('fr_gap_bottom', 2); setNum('fr_gap_sides', 2); onField(); }
  function collectAll(){ var c = collectConstruction(); c.fronts = collectFronts(); return c; }

  // --- validacia poli (cerveny okraj, ziadne modaly) ---
  // V0.4.7e: cita cez evalDim (vyraz = hodnota); ROZPISANY vyraz vo fokusovanom
  // poli sa preskoci (ani apply, ani cervene — hint bezi); COMMITNUTY neprazdny
  // nezmysel je PO NOVOM chyba (predtym NaN ticho presiel) a blokuje apply.
  var LIMITS = { width:[200,3000], height:[200,3000], depth:[150,2000], thickness:[6,50],
                 floor_height:[0,500], plinth_recess:[0,300], rail_depth:[20,400], rails_top_offset:[0,500],
                 // D-07: medzery/presahy cel — zaporny okraj = presah cez obrys (limit zhodny s Fronts::EDGE_LIMIT)
                 fr_gap:[0,50], fr_gap_top:[-100,100], fr_gap_bottom:[-100,100], fr_gap_sides:[-100,100] };
  function validateFields(){
    var ok = true;
    var ae = document.activeElement;
    for (var id in LIMITS){
      var e = el(id); if (!e) continue;
      if (e === ae && isExprStr(e.value)) continue; // rozpisany vyraz — nechaj tak
      if (e.value === ''){ e.classList.remove('bad'); continue; }
      var v = evalDim(e.value);
      if (isNaN(v)){ e.classList.add('bad'); ok = false; continue; }
      var lo = LIMITS[id][0], hi = LIMITS[id][1];
      if (v < lo || v > hi){ e.classList.add('bad'); ok = false; } else { e.classList.remove('bad'); }
    }
    // vysky ciel (.fh) — vyraz sa vyhodnoti, committnuty nezmysel blokuje apply
    var fhs = el('frontRows') ? el('frontRows').querySelectorAll('.fh') : [];
    for (var i = 0; i < fhs.length; i++){
      var f = fhs[i];
      if (f === ae && isExprStr(f.value)) continue;
      if (f.value.trim() === ''){ f.classList.remove('bad'); continue; }
      if (isNaN(evalDim(f.value))){ f.classList.add('bad'); ok = false; } else { f.classList.remove('bad'); }
    }
    return ok;
  }

  // fix #2: refresh nahladu BEZ auto-apply. Pouzity pri vybere sablony (sablona = len preview;
  // aplikuje ju vyhradne tlacidlo "Pouzi sablonu na oznaceny", vratane zon zo sablony).
  function refreshPreview(){ validateFields(); renderPreview(); updateAvailable(); }

  // D-02: debounce prekreslenia nahladu pri pisani (500 ms) — kazde pismeno uz
  // netrha 2D nahlad; ostatne cesty (vyber, sablona, zony) kreslia okamzite.
  var previewTimer = null;
  function schedulePreview(){
    if (previewTimer) clearTimeout(previewTimer);
    previewTimer = setTimeout(function(){ previewTimer = null; renderPreview(); }, 500);
  }

  // --- AUTO-APPLY (debounce 400 ms) ---
  // V0.4.7e: rozpisany VYRAZ vo fokusovanom poli nikdy nespusti apply ani nahlad
  // (medzistav '650-3' je validny vyraz s inou hodnotou) — aplikuje az Enter/blur
  // commit, ktory pole prepise cistym cislom a onField zavola znova.
  function onField(){
    var ae = document.activeElement;
    if (ae && isExprInput(ae) && isExprStr(ae.value)){
      if (applyTimer){ clearTimeout(applyTimer); applyTimer = null; }
      ae.classList.remove('bad');
      return; // zivy nahlad "= X" kresli listener v expr.js
    }
    validateFields();
    refreshMaterialFilters();              // FIX 2: hrubka sa mohla zmenit -> prefiltruj material selecty
    schedulePreview();                     // D-02: nahlad sa neprekresluje pri kazdom pismene
    updateAvailable();
    if (!selectedCabId) return;            // nic oznacene -> len nahlad, ziadny rebuild
    if (applyTimer) clearTimeout(applyTimer);
    var cabSnapshot = selectedCabId;       // Codex expr audit BLOCKER: identita z casu naplanovania
    applyTimer = setTimeout(function(){ flushCabinetEdits(cabSnapshot); }, 400);
  }

  // Okamzity/odlozeny apply korpusu. Snapshot cabinet_id ide s payloadom — Ruby
  // handler ho overi proti aktualnemu vyberu (oneskoreny zapis po prekliknuti
  // na iny korpus sa ticho zahodi namiesto zasiahnutia nespravneho objektu).
  function flushCabinetEdits(cabSnapshot){
    applyTimer = null;
    var ae = document.activeElement;
    if (ae && isExprInput(ae) && isExprStr(ae.value)) return; // vyraz stale rozpisany
    if (!selectedCabId) return;
    if (!validateFields()) { NX.setStatus('Skontroluj červené polia (mimo rozsahu).', true); return; }
    var payload = collectAll();
    payload.cabinet_id = cabSnapshot || selectedCabId;
    cabEditsInFlight = true; // D-07 Codex B2: echo tohto apply nesmie prepisat novsi vstup
    if (window.sketchup && sketchup.apply_all) sketchup.apply_all(JSON.stringify(payload));
  }
  function flushCabinetEditsNow(){
    if (applyTimer){ clearTimeout(applyTimer); applyTimer = null; }
    flushCabinetEdits(selectedCabId);
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
    writeConstruction(DEFAULTS[t] || {});
    applyVisibility(t);
  }
  function applyVisibility(t){
    el('plinthGroup').style.display = (t === 'upper') ? 'none' : '';
    el('fhRow').style.display = (t === 'upper') ? 'none' : ''; // D-11: vyska sokla v Zakladnych, horna ju nema
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
    writeConstruction(c);
    applyVisibility(c.type || 'lower');
    buildFrontHwBadges([]); // Codex PR #30: sablonovy nahlad nema kovanie (F1 sablony != F1 skrinky)
    renderFronts(c.fronts);
    currentZoneTree = c.zone_tree ? sanitizeTree(c.zone_tree) : defaultTree();
    // fix #2: vyber sablony NEspusti apply_all — len naplni polia + nahlad. Korpus sa NEZMENI,
    // kym uzivatel nestlaci "Pouzi sablonu na oznaceny".
    refreshPreview();
    refreshZoneUI();
  }
  // (saveTemplate/deleteTemplate/applyTemplateToSelected sa V0.4.5 D2 presunuli
  //  do okna Sablony — js/templates_dialog.js; panel drzi len quick-pick vyber.)

  // --- D-14: ulozit oznaceny korpus ako sablonu (in-panel modal, vzor D-15) ---
  // Input NIE JE vyrazove pole (ziadny onField/attachExprField — Codex F6);
  // Enter uklada, Esc zatvara, Tab ostava v modale (focus trap).
  var tplModalBound = false;
  function openSaveTemplateModal(){
    if (!selectedCabId){ NX.setStatus('Najprv označ korpus.', true); return; }
    var m = el('tplModal'); if (!m) return;
    el('tplSaveName').value = (typeof tplNameSuggestion === 'string' && tplNameSuggestion) ? tplNameSuggestion : '';
    m.style.display = 'flex';
    refreshTplModalWarn();
    bindTplModal();
    var inp = el('tplSaveName'); inp.focus(); inp.select();
  }
  function closeSaveTemplateModal(){
    var m = el('tplModal'); if (m) m.style.display = 'none';
  }
  function tplModalOpen(){ var m = el('tplModal'); return !!(m && m.style.display !== 'none'); }
  // Kolizia nazvu: CELE pole TEMPLATES (nie typovy filter selectu), trim,
  // case-sensitive presne ako Ruby store (Codex N8). Vola sa aj z NX.setTemplates,
  // aby varovanie zilo pri zmene kniznice pocas otvoreneho modalu (Codex F3).
  function refreshTplModalWarn(){
    if (!tplModalOpen()) return;
    var name = el('tplSaveName').value.trim();
    var exists = TEMPLATES.some(function(t){ return t.name === name; });
    el('tplSaveWarn').style.display = exists ? '' : 'none';
  }
  function saveTemplateAs(){
    var inp = el('tplSaveName');
    var name = inp.value.trim();
    if (!name){ inp.classList.add('bad'); inp.focus(); return; }
    inp.classList.remove('bad');
    if (window.sketchup && sketchup.save_template_as){
      sketchup.save_template_as(JSON.stringify({ name: name, cabinet_id: selectedCabId }));
    }
    closeSaveTemplateModal();
  }
  function bindTplModal(){
    if (tplModalBound) return; tplModalBound = true;
    var m = el('tplModal');
    el('tplSaveName').addEventListener('input', function(){ this.classList.remove('bad'); refreshTplModalWarn(); });
    m.addEventListener('keydown', function(ev){
      if (ev.key === 'Escape'){ ev.preventDefault(); closeSaveTemplateModal(); return; }
      if (ev.key === 'Enter'){ ev.preventDefault(); saveTemplateAs(); return; }
      if (ev.key === 'Tab'){
        var f = m.querySelectorAll('input, button');
        if (!f.length) return;
        var first = f[0], last = f[f.length - 1];
        if (ev.shiftKey && document.activeElement === first){ ev.preventDefault(); last.focus(); }
        else if (!ev.shiftKey && document.activeElement === last){ ev.preventDefault(); first.focus(); }
      }
    });
    // klik na tmave pozadie = zrusit (klik v karte nie)
    m.addEventListener('mousedown', function(ev){ if (ev.target === m) closeSaveTemplateModal(); });
  }

  // --- cela riadky ---
  function addFrontRow(item){
    item = item || {};
    var wrap = el('frontRows');
    var idx = wrap.querySelectorAll('.frow').length + 1;
    var row = document.createElement('div');
    row.className = 'frow';
    row.dataset.frontId = item.id || newStableId('F');
    var badge = frontHwBadge(row.dataset.frontId); // D3: kovanie cela (zavesy/vysuv) z planu
    row.innerHTML =
      '<span class="fnum">' + idx + '</span>' +
      '<select class="ftype" onchange="onFrontTypeChange(this); onField()">' +
        '<option value="door">Dvierka</option><option value="drawer_front">Zásuvkové čelo</option></select>' +
      '<input class="fh" type="text" placeholder="auto" oninput="onField()">' +
      '<select class="fw" onchange="onField()"><option value="auto">auto</option><option value="1">1</option><option value="2">2</option></select>' +
      '<input class="flock" type="checkbox" title="Zamknúť pevnú výšku" onchange="onField()">' +
      '<button class="fdel" title="Odstrániť" onclick="delFrontRow(this); onField()">✕</button>' +
      (badge ? '<span class="fhw" title="Kovanie tohto čela (sekcia Kovanie)">🔗 ' + esc(badge) + '</span>' : '');
    wrap.appendChild(row);
    if (item.type) row.querySelector('.ftype').value = item.type;
    if (item.height !== null && item.height !== undefined && item.height !== '') row.querySelector('.fh').value = item.height;
    if (item.wings) row.querySelector('.fw').value = item.wings;
    if (item.locked) row.querySelector('.flock').checked = true;
    attachExprField(row.querySelector('.fh'), { flushFn: flushCabinetEditsNow }); // V0.4.7e vyrazy vo vyske cela
    onFrontTypeChange(row.querySelector('.ftype'));
  }
  function onFrontTypeChange(sel){ var row = sel.closest('.frow'); row.querySelector('.fw').style.visibility = (sel.value === 'door') ? 'visible' : 'hidden'; }
  function delFrontRow(btn){ btn.closest('.frow').remove(); renumberFronts(); }
  function removeLastFront(){ var rows = el('frontRows').querySelectorAll('.frow'); if (rows.length) { rows[rows.length-1].remove(); renumberFronts(); } }
  function renumberFronts(){ var rows = el('frontRows').querySelectorAll('.frow'); for (var i=0;i<rows.length;i++){ rows[i].querySelector('.fnum').textContent = (i+1); } }
  // D-07 Codex B2: keepGaps=true pri echu apply toho isteho korpusu s cakajucimi
  // editmi — gap polia sa NEprepisu (lokalne hodnoty su novsie nez in-flight echo;
  // fokus guard nestaci — Reset presuva fokus na tlacidlo). Sablony/vyber = prepis.
  function renderFronts(fronts, keepGaps){
    el('frontRows').innerHTML = '';
    var items = (fronts && fronts.items) ? fronts.items : [];
    for (var i = 0; i < items.length; i++){ addFrontRow(items[i]); }
    if (keepGaps) return;
    // Gap polia su STATICKE (mimo frontRows) — plnia sa z kanonickeho configu;
    // 0 je platna hodnota, preto != null test (setNum by cez dflt finty 0 stratil).
    setNum('fr_gap', (fronts && fronts.gap != null) ? fronts.gap : 3);
    setNum('fr_gap_top', (fronts && fronts.gap_top != null) ? fronts.gap_top : 2);
    setNum('fr_gap_bottom', (fronts && fronts.gap_bottom != null) ? fronts.gap_bottom : 2);
    setNum('fr_gap_sides', (fronts && fronts.gap_sides != null) ? fronts.gap_sides : 2);
  }

