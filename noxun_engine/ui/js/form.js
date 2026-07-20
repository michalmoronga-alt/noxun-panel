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
    // D-23: DOM zoznam je OBRATENY (najvyssie celo hore) — citame ODSPODU,
    // aby items[0] = F1 = spodne celo. Datove poradie sa NEMENI, len prezentacia.
    var rows = el('frontRows').querySelectorAll('.frow');
    for (var i = rows.length - 1; i >= 0; i--){
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
             gap_bottom: frontGapVal('fr_gap_bottom', 2.0), gap_sides: frontGapVal('fr_gap_sides', 2.0),
             edge_limit_off: edgeLimitOff, items: items };
  }
  // --- D-22: zamok limitu presahov (okraje +-100 zamknute / +-2000 odomknute) ---
  // Stav zije v JS premennej (nie v DOM triede) — collectFronts ho posiela s configom,
  // renderFronts ho obnovuje z kanonickeho configu pod TYM ISTYM echo-guardom ako
  // gap polia (keepGaps): starsie echo apply nesmie prepisat novsi klik na zamok.
  var edgeLimitOff = false;
  function setEdgeLimitOff(off){
    edgeLimitOff = !!off;
    var b = el('edgeLimitLock');
    if (b){
      b.textContent = edgeLimitOff ? '🔓 ±2000 mm' : '🔒 ±100 mm';
      b.classList.toggle('unlocked', edgeLimitOff);
    }
  }
  function toggleEdgeLimit(){
    setEdgeLimitOff(!edgeLimitOff);
    onField(); // apply pre oznaceny korpus + prevalidovanie okrajovych poli
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
  // D-22: okraje cel maju dynamicky limit podla zamku (Fronts::EDGE_LIMIT_UNLOCKED);
  // fr_gap (medzera medzi celami) ostava 0..50 VZDY.
  var EDGE_LIMIT_FIELDS = { fr_gap_top:1, fr_gap_bottom:1, fr_gap_sides:1 };
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
      if (EDGE_LIMIT_FIELDS[id] && edgeLimitOff){ lo = -2000; hi = 2000; }
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
    invalidateFrontPlaceholders(); // D-23: lokalna zmena -> stare ≈ vysky neplatia (doplni az cerstve echo)
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
    // D-39: edit ZAMKNUTEHO pola vo vkladacej karte aktualizuje hodnotu zamku
    // (zamok drzi to, co pouzivatel vidi; nie starsiu zachytenu hodnotu).
    if (!selectedCabId && NXInsert.state.lastMode === 'insert' &&
        ae && ae.id && NXInsert.isLocked(ae.id)){
      var lv = evalDim(ae.value);
      if (!isNaN(lv) && NXInsert.updateLockValue(ae.id, lv)) pushInsertLocks();
    }
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
    // D-37: svetla hlbka zrkadli interior_dims — hlbka je CELKOVA vratane chrbta:
    // overlay/inset: d - bt; groove: d - 10 - bt; none: d (audit FIX 5 — bez tohto
    // by navrh noveho korpusu ukazoval zlu hodnotu az do prveho rebuildu).
    var bm = val('back_mode'), bt = numv('back_thickness') || 3;
    var ad = d;
    if (bm === 'overlay' || bm === 'inset') ad = d - bt;
    else if (bm === 'groove') ad = d - 10 - bt;
    setVal('av_depth', Math.max(0, Math.round(ad)));
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
    toggleRecess(); toggleTwoRails(); toggleBackTh(); // D-31: pokryva vyber korpusu, defaulty aj sablonu
  }
  function toggleRecess(){ el('recessRow').style.display = (val('plinth_mode') === 'front') ? '' : 'none'; }
  function toggleTwoRails(){ el('twoRailsGroup').style.display = (val('top_mode') === 'two_rails') ? '' : 'none'; }
  // D-31: Bez chrbta skryje riadok hrubky — HODNOTA selectu sa NEMENI (navrat
  // rezimu ju obnovi; sablony a config ju drzia dalej).
  function toggleBackTh(){ var r = el('backThRow'); if (r) r.style.display = (val('back_mode') === 'none') ? 'none' : ''; }

  function onTypeChange(){
    // D-32: typ patri do insert STAVU; zmena typu zahadzuje sablonu (zoznam je
    // typovo filtrovany) a karta sa materializuje nanovo — zamky preziju (D-39).
    NXInsert.state.type = getType();
    NXInsert.state.template = '';
    materializeInsertCard();
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
    // D-33: vyber sablony = zapis do insert STAVU + plna materializacia karty
    // (konstrukcia + cela + medzery + zamok presahov + zony + MATERIALY — audit F6).
    // Prazdna volba "— vyber —" vrati defaulty typu. Zamky prebiju sablonu (D-39).
    // fix #2 plati dalej: ziadny apply_all — sablona meni len navrh karty.
    NXInsert.state.template = val('template') || '';
    materializeInsertCard();
  }
  // (saveTemplate/deleteTemplate/applyTemplateToSelected sa V0.4.5 D2 presunuli
  //  do okna Sablony — js/templates_dialog.js; panel drzi len quick-pick vyber.)

  // ===== D-32/D-33/D-39: materializacia vkladacej karty z insert STAVU =====
  // Jedina cesta, ktorou sa vkladacia karta plni (reset pri prechode do insert,
  // zmena typu, vyber sablony). Poradie krokov = audit F7:
  //   1) CELY zdroj naraz: defaulty typu + sablona NAD nimi (konstrukcia, cela
  //      s medzerami a zamkom presahov, strom zon, materialy) — ziadne zvysky
  //      naposledy oznacenej skrinky (D-32),
  //   2) zamknute hodnoty prebiju zdroj (D-39),
  //   3) viditelnost + validacia + nahlad.
  function findTemplateFor(name, type){
    if (!name) return null;
    for (var i = 0; i < TEMPLATES.length; i++){
      var tp = TEMPLATES[i];
      if (tp.name !== name) continue;
      var tt = (tp.config && tp.config.type) ? tp.config.type : 'lower';
      return tt === type ? tp : null;
    }
    return null;
  }
  // Cela zdroja: objekt s items = sablonove cela; inak null (defaulty maju
  // legacy string 'none' -> prazdny zoznam + predvolene medzery 3/2/2/2).
  function insertFrontsOf(src){
    var f = src && src.fronts;
    return (f && typeof f === 'object' && f.items) ? f : null;
  }
  function materializeInsertCard(){
    var st = NXInsert.state;
    var tp = findTemplateFor(st.template, st.type);
    if (!tp && st.template) st.template = ''; // zmazana/inotypova sablona -> defaulty
    setType(st.type);
    renderFilteredTemplates();
    setVal('template', st.template);
    var src = NXInsert.composeSource(DEFAULTS[st.type] || {}, tp ? tp.config : null);
    writeConstruction(src);                  // krok 1: konstrukcia (plny obraz)
    buildFrontHwBadges([]);                  // navrh nema kovanie (Codex PR #30)
    frontItems = null;                       // ani resolved ≈ vysky
    renderFronts(insertFrontsOf(src));       //         cela + medzery + edge_limit_off
    currentZoneTree = src.zone_tree ? sanitizeTree(src.zone_tree) : defaultTree();
    activeZoneId = null;
    NXInsert.setMaterials(src);              //         materialy zo sablony (F6)
    applyInsertLockValues();                 // krok 2: zamky prebiju zdroj
    renderInsertLocks();
    applyVisibility(st.type);                // krok 3: viditelnost + validacia + nahlad
    refreshMaterialFilters();
    validateFields();
    updateAvailable();
    renderPreview();
    refreshZoneUI();
  }

  // --- D-39: zamky poli vkladacej karty (sirka/vyska/hlbka/hrubka/sokel) ---
  // Ikony 🔒 ziju v EXISTUJUCICH riadkoch poli (.inslock, CSS ich mimo
  // mode-insert skryva); stav drzi NXInsert a zrkadli sa do Ruby pamate
  // Panel modulu (audit B5 — prezije zatvorenie panela, zomrie s restartom SU).
  function applyInsertLockValues(){
    var flat = NXInsert.locksFlat();
    for (var f in flat){ if (Object.prototype.hasOwnProperty.call(flat, f)) setNum(f, flat[f]); }
  }
  function renderInsertLocks(){
    var btns = document.querySelectorAll('.inslock');
    for (var i = 0; i < btns.length; i++){
      var f = btns[i].getAttribute('data-lock');
      var on = NXInsert.isLocked(f);
      btns[i].textContent = on ? '🔒' : '🔓';
      btns[i].classList.toggle('on', on);
      btns[i].title = on
        ? 'Hodnota je zamknutá — prežije výber šablóny aj reset karty. Klik odomkne.'
        : 'Zamknúť hodnotu pre ďalšie vklady (prežije výber šablóny aj reset karty).';
    }
  }
  function toggleInsertLock(field){
    if (NXInsert.isLocked(field)){
      NXInsert.clearLock(field);
    } else {
      var v = evalDim(val(field));
      if (isNaN(v)){ NX.setStatus('Zamknúť sa dá len platná hodnota (mm).', true); return; }
      NXInsert.setLock(field, v);
    }
    renderInsertLocks();
    pushInsertLocks();
  }
  var insertLocksTimer = null;
  function pushInsertLocks(){
    if (insertLocksTimer) clearTimeout(insertLocksTimer);
    insertLocksTimer = setTimeout(function(){
      insertLocksTimer = null;
      if (window.sketchup && sketchup.set_insert_locks)
        sketchup.set_insert_locks(JSON.stringify({ locks: NXInsert.locksFlat() }));
    }, 200);
  }

  // --- D-14: ulozit oznaceny korpus ako sablonu (in-panel modal, vzor D-15) ---
  // Input NIE JE vyrazove pole (ziadny onField/attachExprField — Codex F6);
  // Enter uklada, Esc zatvara, Tab ostava v modale (focus trap).
  var tplModalBound = false;
  var tplModalCabId = null; // Codex GH #46 P2: identita ZACHYTENA pri otvoreni modalu
  function openSaveTemplateModal(){
    if (!selectedCabId){ NX.setStatus('Najprv označ korpus.', true); return; }
    var m = el('tplModal'); if (!m) return;
    tplModalCabId = selectedCabId;
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
    // Codex GH #46 P2: rozpisane edity (400 ms debounce) najprv flushnut — callbacky
    // sa spracuju v poradi, takze apply_all prebehne PRED save a config je cerstvy.
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (window.sketchup && sketchup.save_template_as){
      // identita z casu OTVORENIA modalu — preklik na inu skrinku server odmietne
      sketchup.save_template_as(JSON.stringify({ name: name, cabinet_id: tplModalCabId || selectedCabId }));
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
  // D-23: zoznam je OBRATENY oproti datam — data items[0]=F1=SPODNE celo, zoznam
  // zobrazuje skrinku pred sebou (najvyssie celo hore). Kontrakt cyklu:
  // data [F1,F2,F3] -> DOM [F3,F2,F1] -> collectFronts [F1,F2,F3]; po pridani
  // [F1,F2,F3,X]. Render ide datovo odspodu a KAZDY novy riadok PREDRADI navrch;
  // pouzivatelske "+ riadok" prida datovo NA KONIEC = tiez DOM navrch — obe cesty
  // maju jedinu vkladaciu operaciu (insertBefore firstChild).
  // .fnum je kanonicka pozicia v DATACH (F1 dole) — sync bezi VYHRADNE cez
  // dataset.frontId; cislo sa NIKDY neparsuje z ID a ID sa pri precislovani neprepisuje.
  function addFrontRow(item){
    var userAdd = (item == null); // "+ riadok" (bez argumentu) vs render s datami
    item = item || {};
    var wrap = el('frontRows');
    var idx = wrap.querySelectorAll('.frow').length + 1; // novy riadok = datovo posledny = najvyssia pozicia
    var row = document.createElement('div');
    row.className = 'frow';
    row.dataset.frontId = item.id || newStableId('F');
    var badge = frontHwBadge(row.dataset.frontId); // D3: kovanie cela (zavesy/vysuv) z planu
    row.innerHTML =
      '<span class="fnum">F' + idx + '</span>' +
      '<select class="ftype" onchange="onFrontTypeChange(this); onField()">' +
        '<option value="door">Dvierka</option><option value="drawer_front">Zásuvkové čelo</option>' +
        '<option value="none">Bez čela</option></select>' +
      '<input class="fh" type="text" placeholder="auto" oninput="onField()">' +
      '<select class="fw" onchange="onField()"><option value="auto">auto</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select>' +
      '<input class="flock" type="checkbox" title="Zamknúť pevnú výšku" onchange="onField()">' +
      '<button class="fdel" title="Odstrániť" onclick="delFrontRow(this); onField()">✕</button>' +
      (badge ? '<span class="fhw" title="Kovanie tohto čela (sekcia Kovanie)">🔗 ' + esc(badge) + '</span>' : '');
    wrap.insertBefore(row, wrap.firstChild); // D-23: navrch — DOM je obrateny
    if (item.type) row.querySelector('.ftype').value = item.type;
    if (item.height !== null && item.height !== undefined && item.height !== '') row.querySelector('.fh').value = item.height;
    if (item.wings) row.querySelector('.fw').value = item.wings;
    if (item.locked) row.querySelector('.flock').checked = true;
    attachExprField(row.querySelector('.fh'), { flushFn: flushCabinetEditsNow }); // V0.4.7e vyrazy vo vyske cela
    onFrontTypeChange(row.querySelector('.ftype'));
    if (userAdd){
      // D-23: novy riadok vznika NAVRCHU zoznamu — dotiahni ho do pohladu a fokusni vysku
      row.scrollIntoView({ block: 'nearest' });
      var fh0 = row.querySelector('.fh'); if (fh0) fh0.focus();
    }
  }
  // D-18: pri 'none' (Bez čela) sa skryje výber krídel (ako pri drawer_front) a hneď
  // aj badge kovania (dátovo zmizne až po echu apply — bez dielcov niet kovania).
  // Badge span nemusí existovať (vzniká len pri neprázdnom badge) — null guard (Codex F3).
  function onFrontTypeChange(sel){
    var row = sel.closest('.frow');
    row.querySelector('.fw').style.visibility = (sel.value === 'door') ? 'visible' : 'hidden';
    var hw = row.querySelector('.fhw');
    if (hw) hw.style.display = (sel.value === 'none') ? 'none' : '';
  }
  function delFrontRow(btn){ btn.closest('.frow').remove(); renumberFronts(); }
  // D-23: datovo posledne celo = HORNY riadok DOM (zoznam je obrateny); po
  // odobrati udrz kontext — novy horny riadok dotiahni do pohladu.
  function removeLastFront(){
    var rows = el('frontRows').querySelectorAll('.frow');
    if (!rows.length) return;
    rows[0].remove();
    renumberFronts();
    var first = el('frontRows').querySelector('.frow');
    if (first) first.scrollIntoView({ block: 'nearest' });
  }
  // D-23: cislo = kanonicka pozicia v datach — SPODNY DOM riadok je F1.
  function renumberFronts(){ var rows = el('frontRows').querySelectorAll('.frow'); for (var i=0;i<rows.length;i++){ rows[i].querySelector('.fnum').textContent = 'F' + (rows.length - i); } }
  // D-07 Codex B2: keepGaps=true pri echu apply toho isteho korpusu s cakajucimi
  // editmi — gap polia sa NEprepisu (lokalne hodnoty su novsie nez in-flight echo;
  // fokus guard nestaci — Reset presuva fokus na tlacidlo). Sablony/vyber = prepis.
  // D-22: zamok presahov (edge_limit_off) je pod TYM ISTYM guardom — klik na zamok
  // pocas in-flight apply nesmie starsie echo vratit spat.
  // D-23 (audit B1): pod TYM ISTYM guardom su aj RIADKY ciel — echo pocas
  // rozpisaneho editu ich uz NEprestavia (rebuild by zahodil pisany vstup aj
  // prave pridany/odobrany riadok — DOM s cakajucimi editmi je novsi nez echo).
  // Obnovia sa len bezpecne udaje viazane cez ID: placeholder ≈ vysky a badge
  // kovania. Plny rebuild riadkov = zmena vyberu alebo echo bez cakajucich editov.
  function renderFronts(fronts, keepGaps){
    if (keepGaps){
      updateFrontRowBadges();
      // applyTimer = pouzivatel pisal AJ PO flushi, ktory toto echo vyvolal —
      // jeho ≈ vysky su uz stare; placeholder doplni az echo najnovsieho editu.
      if (!applyTimer) updateFrontPlaceholders();
      return;
    }
    if (typeof clearFrontHover === 'function') clearFrontHover(); // D-23: riadky idu prec — hover stav s nimi
    el('frontRows').innerHTML = '';
    var items = (fronts && fronts.items) ? fronts.items : [];
    for (var i = 0; i < items.length; i++){ addFrontRow(items[i]); }
    updateFrontPlaceholders();
    // Gap polia su STATICKE (mimo frontRows) — plnia sa z kanonickeho configu;
    // 0 je platna hodnota, preto != null test (setNum by cez dflt finty 0 stratil).
    setNum('fr_gap', (fronts && fronts.gap != null) ? fronts.gap : 3);
    setNum('fr_gap_top', (fronts && fronts.gap_top != null) ? fronts.gap_top : 2);
    setNum('fr_gap_bottom', (fronts && fronts.gap_bottom != null) ? fronts.gap_bottom : 2);
    setNum('fr_gap_sides', (fronts && fronts.gap_sides != null) ? fronts.gap_sides : 2);
    setEdgeLimitOff(!!(fronts && fronts.edge_limit_off));
  }

  // --- D-23: placeholder ≈ dopocitanej vysky v AUTO poliach --------------------
  // Zdroj: resolved front_items z Ruby (globalna frontItems — bridge ju plni PRED
  // renderom). Parovanie VYHRADNE cez dataset.frontId; sivy odhad LEN pre PRAZDNE
  // pole, ktoreho resolved zaznam ma mode:'auto'. Pri lokalnej zmene (onField) sa
  // odhady zneplatnia — nove dopocty plati az cerstve echo (stare vysky by klamali).
  function updateFrontPlaceholders(){
    var wrap = el('frontRows'); if (!wrap) return;
    var byId = {};
    (frontItems || []).forEach(function(it){ if (it && it.id) byId[it.id] = it; });
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var inp = rows[i].querySelector('.fh'); if (!inp) continue;
      var it = byId[rows[i].dataset.frontId];
      inp.placeholder = (inp.value.trim() === '' && it && it.mode === 'auto' && it.height != null)
        ? ('≈ ' + Math.round(it.height)) : 'auto';
    }
  }
  function invalidateFrontPlaceholders(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var inp = rows[i].querySelector('.fh'); if (inp) inp.placeholder = 'auto';
    }
  }
  // D-23: obnova badge kovania podla ID bez prestavby riadkov (light-update pri
  // echu). .fhw sa VZDY hlada/vklada cez triedu a appendChild na koniec riadku —
  // NIKDY nie cez nextElementSibling/indexy deti (.exprhint zije hned za .fh).
  function updateFrontRowBadges(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var row = rows[i];
      var badge = frontHwBadge(row.dataset.frontId);
      var span = row.querySelector('.fhw');
      if (badge){
        if (!span){
          span = document.createElement('span');
          span.className = 'fhw';
          span.title = 'Kovanie tohto čela (sekcia Kovanie)';
          row.appendChild(span);
        }
        span.textContent = '🔗 ' + badge;
        var tsel = row.querySelector('.ftype'); // D-18: pri 'none' badge skryty
        span.style.display = (tsel && tsel.value === 'none') ? 'none' : '';
      } else if (span){
        span.remove();
      }
    }
  }
  // D-23: klik na celo v nahlade — otvor sekciu Cela, riadok do pohladu, fokus
  // pola vysky. Riadok sa hlada cez dataset.frontId (nie cez cislo).
  function focusFrontRow(fid){
    if (!fid) return;
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    var row = null;
    for (var i = 0; i < rows.length; i++){
      if (rows[i].dataset.frontId === fid){ row = rows[i]; break; }
    }
    if (!row) return;
    var det = document.querySelector('details[data-key="fronts"]');
    if (det) det.open = true; // zbalena sekcia by fokus/scroll zhltla
    row.scrollIntoView({ block: 'nearest' });
    var fh = row.querySelector('.fh');
    if (fh) fh.focus();
  }

