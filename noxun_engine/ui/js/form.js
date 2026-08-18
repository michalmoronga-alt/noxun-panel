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
      // D-90 (Codex #144 P1): 'profile' este NEMA ovladac (pride v PR 2), ale
      // MUSI prezit round-trip — inak by kazda zmena ineho pola poslala riadok
      // bez profilu a server by ho znormalizoval na 'none' (celo by sa ticho
      // vratilo na plnu vysku a profil by vypadol z kovania).
      items.push({ id: r.dataset.frontId || newStableId('F'), type: type, mode: hasH ? 'fixed' : 'auto',
        height: hasH ? (isNaN(hNum) ? null : hNum) : null, locked: hasH ? locked : false, wings: (type === 'door') ? wings : '1',
        profile: r.dataset.frontProfile || 'none' });
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
      // B3: NEprepisovat cely obsah tlacidla textContentom (zmazal by ikonu) —
      // meni sa len symbol v <use> a textovy label; aria-pressed drzi stav (B11).
      if (window.NXIcons) NXIcons.set(b, edgeLimitOff ? 'lock-open' : 'lock');
      var lbl = b.querySelector('.lblLimit');
      if (lbl) lbl.textContent = edgeLimitOff ? '±2000 mm' : '±100 mm';
      b.setAttribute('aria-pressed', edgeLimitOff ? 'false' : 'true'); // pressed = zamknuty limit
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
    // (zamok drzi to, co pouzivatel vidi). GH P3: NIE cez activeElement — pri
    // expr commite na blur uz fokus odisiel; synchronizuju sa VSETKY zamknute
    // polia z DOM (5 poli, lacne a deterministicke).
    if (!selectedCabId && NXInsert.state.lastMode === 'insert'){
      var changedLock = false;
      NXInsert.lockedFields().forEach(function(fid){
        var fe = el(fid);
        if (!fe) return;
        var lv = evalDim(fe.value);
        if (!isNaN(lv) && NXInsert.updateLockValue(fid, lv)) changedLock = true;
      });
      if (changedLock) pushInsertLocks();
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
    // UI-B3: svetle rozmery su TEXT v informacnom stlpci (setOut), nie readonly polia.
    setOut('av_width', Math.max(0, Math.round(w - 2*t)));
    // D-37: svetla hlbka zrkadli interior_dims — hlbka je CELKOVA vratane chrbta:
    // overlay/inset: d - bt; groove: d - 10 - bt; none: d (audit FIX 5 — bez tohto
    // by navrh noveho korpusu ukazoval zlu hodnotu az do prveho rebuildu).
    var bm = val('back_mode'), bt = numv('back_thickness') || 3;
    var ad = d;
    if (bm === 'overlay' || bm === 'inset') ad = d - bt;
    else if (bm === 'groove') ad = d - 10 - bt;
    setOut('av_depth', Math.max(0, Math.round(ad)));
    // D-80: svetla vyska cez JEDINU zdielanu funkciu (core.js nxInteriorZ) —
    // pri two_rails ju urcuje spodna hrana vystuh (odsadenie + orientacia).
    // Vyska/hrubka sa posielaju z uz precitanych poli (prazdne pole = 0 ako predtym).
    var iv = nxInteriorZ(currentCarcass({ height: h, thickness: t }));
    setOut('av_height', Math.max(0, Math.round(iv.availH)));
    // UI-C1b: vo VKLADANI KORPUSU nesu „Dielcov" a „Materiál" ODHAD zo sablony —
    // server dopocet (Panel.cabinet_stats) cita snapshoty uz vlozenej skrinky
    // a builder sa kvoli informacnemu riadku nespusta.
    if (!selectedCabId && NXInsert.state.kind !== 'board') setInsertCabInfo();
  }
  // Odhad je ZNACENY (≈) a riadky ostavaju neklikatelne (nie je co oznacit v
  // modeli) — vzor D-78: aria-disabled + vysvetlenie, nikdy ticho mrtve.
  function setInsertCabInfo(){
    var st = nxDraftStats(pvGeom(), computeZones(), pvInsertFronts());
    setOut('inf_parts', st.count > 0 ? ('≈ ' + st.count) : '—');
    setOut('inf_area', st.area > 0 ? ('≈ ' + mmLabel(st.area) + ' m²') : '—');
    var pn = el('infParts'), an = el('infArea');
    if (pn) pn.title = 'Odhad počtu výrobných dielcov zo šablóny — presné číslo dá skrinka po vložení';
    if (an) an.title = 'Odhad plochy dosky zo šablóny — presné číslo dá skrinka po vložení';
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

  // ===== UI-C1b: TYP VKLADANEHO OBJEKTU (tri segmentove tlacidla) ===========
  // Nahradilo dvojicu radiov (kind Korpus/Doska + ctype Dolna/Horna). Autorita
  // je NXInsert (cisty stav), DOM je len jeho zrkadlo — kostra sa neprekresluje.
  function onInsertType(t){
    if (!NXInsert.setInsertType(t)) return; // klik na uz zvoleny typ nic nerobi
    onInsertKindChange();                   // body atribut + material dosky (board_card.js)
    // Novy vyjav = cisty fit (rovnaka zasada ako pri prepnuti kontextu raily):
    // zoom na 600 mm skrinke by na 2600 mm doske mieril mimo.
    pvUserView = false; pvView = null;
    materializeInsertCard();
  }
  function syncInsertTypeButtons(){
    var cur = NXInsert.insertType();
    var btns = document.querySelectorAll('#insertTypeRow button[data-ins-type]');
    for (var i = 0; i < btns.length; i++){
      var on = btns[i].getAttribute('data-ins-type') === cur;
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }

  // ===== UI-C1b: DLAZDICE SABLON (N16 nedavne prve, N17 dvojklik vlozi) =====
  // Mriezka sa PRESTAVUJE len vtedy, ked sa zmenil typ vkladania alebo prisla
  // nova kniznica (push_templates). Vyber sablony mriezku NEPRESTAVUJE — meni
  // sa iba trieda `.on` (Codex FIX 14 + pasca CEF: klik, ktory zahodi uzol,
  // by druhy klik dvojkliku uz nemal na com dokoncit).
  var TPL_RECENT_MAX = 3;
  // Schematicky nahlad sablony — JEDNODUCHA kresba z configu (REALNE PNG nahlady
  // su az UI-D2). Ciste (Node testy): vracia INNER markup SVG bez jedinej farby
  // — obrys aj vypln davaju CSS tokeny (`.tpltile svg` v panel.css), rovnaka
  // zasada ako inde: ziadny hex mimo palety.
  function nxTplGlyph(tp){
    var cfg = (tp && tp.config) || {};
    var box = '<rect x="2" y="2" width="56" height="36"/>';
    if (NXInsert.templateKind(tp) === 'board'){
      // doska: obdlznik s uhlopriecnym naznakom plochy
      return box + '<path d="M8 30 52 10"/>';
    }
    var g = '';
    var items = (cfg.fronts && cfg.fronts.items) ? cfg.fronts.items : [];
    var n = items.length;
    if (n > 1){
      // vodorovne delenie radov ciel (max 4 ciary, nech dlazdica ostane citatelna)
      var lines = Math.min(n - 1, 4);
      for (var i = 1; i <= lines; i++){
        var y = 2 + 36 * i / (lines + 1);
        g += '<path d="M2 ' + y.toFixed(1) + 'h56"/>';
      }
    }
    if (n === 1 && String(items[0] && items[0].wings) === '2'){
      g += '<path d="M30 2v36"/>';
    }
    if (!g){
      // bez ciel: naznac police zo stromu zon (prazdny korpus ostane prazdny)
      var sh = (cfg.zone_tree && parseInt(cfg.zone_tree.shelves, 10)) || 0;
      var s = Math.min(sh, 4);
      for (var k = 1; k <= s; k++){
        var zy = 2 + 36 * k / (s + 1);
        g += '<path d="M6 ' + zy.toFixed(1) + 'h48" stroke-dasharray="3 3"/>';
      }
    }
    return box + g;
  }
  // Popisok pod kresbou: nazov + (pri doske) badge hrubky.
  // Ciste (Node testy) — vracia TEXT, escapuje az volajuci.
  function nxTplBadge(tp){
    if (NXInsert.templateKind(tp) !== 'board') return '';
    var th = tp && tp.config ? parseFloat(tp.config.thickness) : NaN;
    return (isNaN(th) || th <= 0) ? '' : (mmLabel(th) + ' mm');
  }
  function tplTileHtml(tp, sel){
    var badge = nxTplBadge(tp);
    return '<button type="button" class="tpltile' + (tp.name === sel ? ' on' : '') + '"' +
      ' data-tpl-name="' + esc(tp.name) + '" title="' + esc(tp.name) + ' — klik = vybrať · dvojklik = vlož hneď">' +
      '<svg viewBox="0 0 60 40" aria-hidden="true">' + nxTplGlyph(tp) + '</svg>' +
      '<span>' + esc(tp.name) + (badge ? ' <i>· ' + esc(badge) + '</i>' : '') + '</span></button>';
  }
  function renderTemplateTiles(force){
    var box = el('tplTiles'); if (!box) return;
    var type = NXInsert.insertType();
    var kind = (type === 'board') ? 'board' : 'cabinet';
    var sel = NXInsert.templateName(kind);
    // Prestavba LEN pri zmene typu / novej kniznici; inak staci prepnut triedy.
    if (!force && box.dataset.forType === type){ syncTemplateTiles(); return; }
    var groups = NXInsert.templateGroups(TEMPLATES, type, TPL_RECENT_MAX);
    var h = '';
    if (groups.recent.length){
      h += '<div class="tplsec">Naposledy použité</div><div class="tpltiles">';
      groups.recent.forEach(function(tp){ h += tplTileHtml(tp, sel); });
      h += '</div><div class="tplsec">Všetky šablóny</div>';
    }
    if (groups.all.length){
      h += '<div class="tpltiles">';
      groups.all.forEach(function(tp){ h += tplTileHtml(tp, sel); });
      h += '</div>';
    } else {
      h += '<div class="tplempty">Zatiaľ žiadna šablóna tohto typu — ulož si ju z hotovej skrinky.</div>';
    }
    box.dataset.forType = type;
    box.innerHTML = h;
    setTplMeta();
  }
  // Prepnutie vybranej dlazdice BEZ prestavby mriezky (ten isty nazov moze byt
  // v oboch skupinach — „naposledy použité" aj „všetky", preto sa prechadzaju
  // VSETKY dlazdice).
  function syncTemplateTiles(){
    var box = el('tplTiles'); if (!box) return;
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    var sel = NXInsert.templateName(kind);
    var tiles = box.querySelectorAll('.tpltile');
    for (var i = 0; i < tiles.length; i++){
      tiles[i].classList.toggle('on', tiles[i].getAttribute('data-tpl-name') === sel);
    }
    setTplMeta();
  }
  function setTplMeta(){
    var m = el('insTplMeta'); if (!m) return;
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    m.textContent = NXInsert.templateName(kind) || 'bez šablóny';
  }
  // Vyber sablony = zapis do insert STAVU + plna materializacia karty (D-33:
  // konstrukcia + cela + medzery + zamok presahov + zony + MATERIALY — audit F6).
  // Klik na UZ vybranu dlazdicu je NO-OP (nie odznacenie): dvojklik posiela dva
  // kliky za sebou a odznacenie by medzi nimi kartu vratilo na defaulty typu.
  // fix #2 plati dalej: ziadny apply_all, sablona meni len navrh karty.
  function pickTemplateTile(name){
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    if (!name || NXInsert.templateName(kind) === name) return;
    NXInsert.setTemplateName(kind, name);
    materializeInsertCard();
  }
  // JEDNA delegacia na kontajneri (Codex FIX 14): dlazdice sa prekresluju, ale
  // listener zije na statickom #tplTiles. Dvojklik vklada TOU ISTOU validovanou
  // cestou ako zelene tlacidlo (ziadne priame volanie bridgu odtialto — N17).
  var tplTilesBound = false;
  function setupTemplateTiles(){
    if (tplTilesBound) return;
    var box = el('tplTiles'); if (!box) return;
    box.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'tpltile'); if (!t) return;
      pickTemplateTile(t.getAttribute('data-tpl-name'));
    });
    box.addEventListener('dblclick', function(ev){
      var t = closestClass(ev.target, 'tpltile'); if (!t) return;
      // N17: klik uz sablonu vybral a karta sa z nej materializovala — dvojklik
      // len spusti TO ISTE vlozenie ako zelene tlacidlo (validacia, zamky aj
      // peciatka pouzitia ostavaju v jednej ceste).
      pickTemplateTile(t.getAttribute('data-tpl-name'));
      if (NXInsert.insertType() === 'board') insertBoard(); else insertCabinet();
    });
    tplTilesBound = true;
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
    // UI-C1a: rovnomenna doskova sablona NIE JE tato (identita je kind+name).
    var tp = NXInsert.findTemplate(TEMPLATES, 'cabinet', name);
    return (tp && NXInsert.templateType(tp) === type) ? tp : null;
  }
  // Cela zdroja: objekt s items = sablonove cela; inak null (defaulty maju
  // legacy string 'none' -> prazdny zoznam + predvolene medzery 3/2/2/2).
  function insertFrontsOf(src){
    var f = src && src.fronts;
    return (f && typeof f === 'object' && f.items) ? f : null;
  }
  function materializeInsertCard(){
    var st = NXInsert.state;
    syncInsertTypeButtons();
    renderTemplateTiles();  // prestavba len pri zmene typu; inak sa prepnu triedy
    if (st.kind === 'board'){
      materializeInsertBoardCard();
      renderInsertLocks();
      if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
      return;
    }
    materializeInsertCabCard();
  }
  // UI-C1b: doskova vetva vkladacej karty (rozmery + material + hrubka + smer).
  // Detail (kontrakt hrubky, UNI material, zamky) zije v board_card.js — tu je
  // len poradie krokov, aby bola cesta rovnaka ako pri korpuse.
  function materializeInsertBoardCard(){
    var name = NXInsert.templateName('board');
    var tp = NXInsert.findTemplate(TEMPLATES, 'board', name);
    if (!tp && name) NXInsert.setTemplateName('board', ''); // zmazana sablona -> defaulty karty
    if (tp) applyBoardTemplate(tp.config || {});
    applyInsertLockValues('board');       // krok 2: zamky prebiju sablonu (D-39)
    refreshInsertBoardInfo();
    syncTemplateTiles();
    renderPreview();
  }
  function materializeInsertCabCard(){
    var st = NXInsert.state;
    var tp = findTemplateFor(st.template, st.type);
    if (!tp && st.template) st.template = ''; // zmazana/inotypova sablona -> defaulty
    setType(st.type);
    syncTemplateTiles();
    var src = NXInsert.composeSource(DEFAULTS[st.type] || {}, tp ? tp.config : null);
    writeConstruction(src);                  // krok 1: konstrukcia (plny obraz)
    buildFrontHwBadges([]);                  // navrh nema kovanie (Codex PR #30)
    frontItems = null;                       // ani resolved ≈ vysky
    renderFronts(insertFrontsOf(src));       //         cela + medzery + edge_limit_off
    currentZoneTree = src.zone_tree ? sanitizeTree(src.zone_tree) : defaultTree();
    activeZoneId = null;
    NXInsert.setMaterials(src);              //         materialy zo sablony (F6)
    NXInsert.setHardware(src);               //         sety kovania zo sablony (H2/D-76)
    applyInsertLockValues();                 // krok 2: zamky prebiju zdroj
    renderInsertLocks();
    applyVisibility(st.type);                // krok 3: viditelnost + validacia + nahlad
    refreshMaterialFilters();
    validateFields();
    updateAvailable();
    renderPreview();
    refreshZoneUI();
    // Codex #173 P2: karta sa prave PROGRAMOVO prepisala (rozmery zo sablony,
    // viditelnost sokla podla typu) — ziadne `input`/`change` sa nevystreli,
    // takze meta listy sektorov treba obnovit vyslovne.
    if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
  }

  // --- D-39: zamky poli vkladacej karty (sirka/vyska/hlbka/hrubka/sokel) ---
  // Ikony 🔒 ziju v EXISTUJUCICH riadkoch poli (.inslock, CSS ich mimo
  // mode-insert skryva); stav drzi NXInsert a zrkadli sa do Ruby pamate
  // Panel modulu (audit B5 — prezije zatvorenie panela, zomrie s restartom SU).
  // UI-C1b: pole zamku -> ID inputu. Korpusove kluce SU ID poli; doskove maju
  // prefix `ib_` (vkladacia doska) — mapovanie zije LEN tu.
  function insertLockElId(field, scope){ return (scope === 'board') ? ('ib_' + field) : field; }
  function applyInsertLockValues(scope){
    var flat = NXInsert.locksFlat(scope);
    for (var f in flat){
      if (Object.prototype.hasOwnProperty.call(flat, f)) setNum(insertLockElId(f, scope), flat[f]);
    }
  }
  function renderInsertLocks(){
    var btns = document.querySelectorAll('.inslock');
    for (var i = 0; i < btns.length; i++){
      var f = btns[i].getAttribute('data-lock');
      var scope = btns[i].getAttribute('data-lock-scope') || 'cabinet';
      var on = NXInsert.isLocked(f, scope);
      // B3: meni sa len symbol v <use>, nie textContent celeho tlacidla (zmazal by SVG).
      if (window.NXIcons) NXIcons.set(btns[i], on ? 'lock' : 'lock-open');
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false'); // B11
      btns[i].title = on
        ? 'Hodnota je zamknutá — prežije výber šablóny aj reset karty. Klik odomkne.'
        : 'Zamknúť hodnotu pre ďalšie vklady (prežije výber šablóny aj reset karty).';
    }
  }
  function toggleInsertLock(field, scope){
    if (NXInsert.isLocked(field, scope)){
      NXInsert.clearLock(field, scope);
    } else {
      var v = evalDim(val(insertLockElId(field, scope)));
      if (isNaN(v)){ NX.setStatus('Zamknúť sa dá len platná hodnota (mm).', true); return; }
      // (hodnota sa nastavi v NXInsert.setLock nizsie)
      NXInsert.setLock(field, v, scope);
    }
    renderInsertLocks();
    // Doskove zamky su LEN v UI — server o nich nevie (vlastne kluce length/width,
    // whitelist Panel::INSERT_LOCK_FIELDS je korpusovy). Posiela sa preto len
    // korpusova sada; doskovy zamok zomrie so zatvorenim panela.
    if (scope !== 'board') pushInsertLocksNow(); // GH P3: klik na zamok = okamzity zapis do Ruby
  }
  // Edit rozmeru vkladanej DOSKY: zamok drzi to, co pouzivatel vidi (rovnaka
  // zasada ako D-39 pri korpuse v onField), plus zive info a nahlad.
  function onInsertBoardField(){
    NXInsert.lockedFields('board').forEach(function(f){
      var v = evalDim(val(insertLockElId(f, 'board')));
      if (!isNaN(v)) NXInsert.updateLockValue(f, v, 'board');
    });
    refreshInsertBoardInfo();
    schedulePreview();
  }
  var insertLocksTimer = null;
  function pushInsertLocksNow(){
    if (insertLocksTimer){ clearTimeout(insertLocksTimer); insertLocksTimer = null; }
    if (window.sketchup && sketchup.set_insert_locks)
      sketchup.set_insert_locks(JSON.stringify({ locks: NXInsert.locksFlat() }));
  }
  function pushInsertLocks(){
    if (insertLocksTimer) clearTimeout(insertLocksTimer);
    insertLocksTimer = setTimeout(function(){
      insertLocksTimer = null;
      pushInsertLocksNow();
    }, 200);
  }

  // --- D-41 C2: modal "chyba ABS paska" (vzor D-15) ---------------------------
  // Otvara sa PRED odoslanim zmeny materialu/bulk olepu, ked absUsableExists
  // nenajde pouzitelny 1,0 mm variant. Rozhodnutie vola POVODNY callback s
  // flagom create_missing_abs — server vsetko overi znova (JS sa neveri).
  var absModalPending = null; // {send: fn(createBool), revert: fn()|null}
  function openAbsModal(text, send, revert){
    var m = el('absModal'); if (!m){ send(false); return; }
    absModalPending = { send: send, revert: revert };
    el('absModalText').textContent = text;
    m.style.display = 'flex';
  }
  function absModalChoose(choice){
    var p = absModalPending;
    absModalCloseSilent();
    if (!p) return;
    if (choice === 'create') p.send(true);
    else if (choice === 'without') p.send(false);
    else if (p.revert) p.revert();
  }
  // Tiche zatvorenie BEZ akcie — vola sa aj pri zmene vyberu (bridge), aby
  // oneskorene rozhodnutie nezasiahlo inu kartu.
  function absModalCloseSilent(){
    absModalPending = null;
    var m = el('absModal'); if (m) m.style.display = 'none';
  }

  // --- D-14: ulozit oznaceny korpus ako sablonu (in-panel modal, vzor D-15) ---
  // Input NIE JE vyrazove pole (ziadny onField/attachExprField — Codex F6);
  // Enter uklada, Esc zatvara, Tab ostava v modale (focus trap).
  var tplModalBound = false;
  var tplModalCabId = null; // Codex GH #46 P2: identita ZACHYTENA pri otvoreni modalu
  // Codex audit BLOCKER 2 (UI-B3): identita skrinky NESTACI — ID sa naprie
  // dokumentmi opakuju (CAB-001 je v kazdom modeli), takze modal otvoreny nad
  // jednym dokumentom by po prepnuti ulozil skrinku z ineho. Zachytava sa aj
  // DOKUMENT a server ho striktne overuje (vzor clear_selection / kamera).
  var tplModalGuid = null;
  // Je otvoreny modal uz „o inej skrinke"? (zmena ID ALEBO dokumentu)
  function tplModalStale(c){
    if (!tplModalCabId) return false;
    var p = c || {};
    return (p.cabinet_id !== tplModalCabId) || (String(p.model_guid || '') !== String(tplModalGuid || ''));
  }
  function openSaveTemplateModal(){
    if (!selectedCabId){ NX.setStatus('Najprv označ korpus.', true); return; }
    var m = el('tplModal'); if (!m) return;
    tplModalCabId = selectedCabId;
    tplModalGuid = (typeof nxModelGuid === 'string') ? nxModelGuid : '';
    el('tplSaveName').value = (typeof tplNameSuggestion === 'string' && tplNameSuggestion) ? tplNameSuggestion : '';
    // UI-B3: typ sa predvyplni z TYPU OZNACENEJ SKRINKY (radio vo vkladacej
    // karte je pri oznacenom korpuse zrkadlom jeho typu — setType v loadSelected).
    setVal('tplSaveType', getType());
    m.style.display = 'flex';
    refreshTplModalWarn();
    bindTplModal();
    var inp = el('tplSaveName'); inp.focus(); inp.select();
  }
  function closeSaveTemplateModal(){
    var m = el('tplModal'); if (m) m.style.display = 'none';
  }
  function tplModalOpen(){ var m = el('tplModal'); return !!(m && m.style.display !== 'none'); }
  // Kolizia nazvu: VSETKY KORPUSOVE sablony (nie typovy filter selectu), trim,
  // case-sensitive presne ako Ruby store (Codex N8). Vola sa aj z NX.setTemplates,
  // aby varovanie zilo pri zmene kniznice pocas otvoreneho modalu (Codex F3).
  // UI-C1a: doskova sablona rovnakeho mena kolizia NIE JE — identita v sklade
  // je dvojica (kind, name) a modal uklada vzdy korpusovu.
  function refreshTplModalWarn(){
    if (!tplModalOpen()) return;
    var name = el('tplSaveName').value.trim();
    var exists = TEMPLATES.some(function(t){
      return NXInsert.templateKind(t) === 'cabinet' && t.name === name;
    });
    el('tplSaveWarn').style.display = exists ? '' : 'none';
  }
  function saveTemplateAs(){
    var inp = el('tplSaveName');
    var name = inp.value.trim();
    if (!name){ inp.classList.add('bad'); inp.focus(); return; }
    inp.classList.remove('bad');
    // Codex audit FIX 3 (UI-B3): flush pri NEPLATNYCH poliach edity ticho
    // NEaplikuje — sablona by sa ulozila zo starych hodnot a este by ohlasila
    // uspech. Ukladanie preto stoji, kym cervene pole neopravis (modal ostava
    // otvoreny; vzor „Vložiť kópiu").
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — šablóna by sa uložila zo starých hodnôt.', true);
      return;
    }
    // Codex GH #46 P2: rozpisane edity (400 ms debounce) najprv flushnut — callbacky
    // sa spracuju v poradi, takze apply_all prebehne PRED save a config je cerstvy.
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (window.sketchup && sketchup.save_template_as){
      // identita z casu OTVORENIA modalu — preklik na inu skrinku ANI iny
      // dokument server neprepusti; UI-B3: typ urcuje, pod ktorym typom sa
      // sablona ponuka (whitelist v Ruby)
      sketchup.save_template_as(JSON.stringify({ name: name, cabinet_id: tplModalCabId || selectedCabId,
                                                 model_guid: tplModalGuid || '',
                                                 type: val('tplSaveType') || getType() }));
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
    // D-90: profil riadku zije v datasete (ovladac = tlacidlo .fprof nizsie) —
    // collectFronts ho posiela spat, takze editacia inych poli profil nezhodi.
    row.dataset.frontProfile = item.profile || 'none';
    var badge = frontHwBadge(row.dataset.frontId); // D3: kovanie cela (zavesy/vysuv) z planu
    row.innerHTML =
      '<span class="fnum">F' + idx + '</span>' +
      '<select class="ftype" onchange="onFrontTypeChange(this); onField()">' +
        '<option value="door">Dvierka</option><option value="drawer_front">Zásuvkové čelo</option>' +
        '<option value="none">Bez čela</option></select>' +
      '<input class="fh" type="text" placeholder="auto" oninput="onField()">' +
      '<select class="fw" onchange="onField()"><option value="auto">auto</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select>' +
      // D-90: volba uchytkoveho profilu — IKONOVE tlacidlo v EXISTUJUCOM rade
      // (pravidlo vertikalneho priestoru; ziadny novy riadok ani popisok).
      // Klik cykli „bez profilu -> profily z registry", stav drzi dataset +
      // aria-pressed; ked Ruby ziadny profil nepozna, tlacidlo sa nevykresli.
      (FRONT_PROFILES.length
        ? '<button class="fprof" type="button" aria-pressed="false" onclick="toggleFrontProfile(this); onField()">' +
          NXIcons.svg('profile') + '</button>'
        : '') +
      '<input class="flock" type="checkbox" title="Zamknúť pevnú výšku" onchange="onField()">' +
      '<button class="fdel" title="Odstrániť" aria-label="Odstrániť čelo" onclick="delFrontRow(this); onField()">' + NXIcons.svg('x') + '</button>' +
      (badge ? '<span class="fhw" title="Kovanie tohto čela (sekcia Kovanie)">' + NXIcons.svg('link') + esc(badge) + '</span>' : '');
    wrap.insertBefore(row, wrap.firstChild); // D-23: navrch — DOM je obrateny
    if (item.type) row.querySelector('.ftype').value = item.type;
    if (item.height !== null && item.height !== undefined && item.height !== '') row.querySelector('.fh').value = item.height;
    if (item.wings) row.querySelector('.fw').value = item.wings;
    if (item.locked) row.querySelector('.flock').checked = true;
    attachExprField(row.querySelector('.fh'), { flushFn: flushCabinetEditsNow }); // V0.4.7e vyrazy vo vyske cela
    syncFrontProfileBtn(row); // D-90: stav tlacidla profilu z datasetu
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
    // D-90: „Bez čela" nemá na čom profil držať — voľba zmizne a stav sa zhodí
    // na 'none' (rovnako to robí Ruby normalize; UI sa mu nesmie rozísť).
    var pb = row.querySelector('.fprof');
    if (pb){
      var off = (sel.value === 'none');
      pb.style.visibility = off ? 'hidden' : 'visible';
      if (off && row.dataset.frontProfile !== 'none'){
        row.dataset.frontProfile = 'none';
        syncFrontProfileBtn(row);
      }
    }
  }
  // D-90: klik cykli profil riadku (bez profilu -> UKW-7 -> …). Autorita je
  // server (Fronts.normalize_config neznámu hodnotu zhodí na 'none'); tu ide
  // len o pohodlie a čitateľný stav.
  function toggleFrontProfile(btn){
    var row = btn.closest('.frow'); if (!row) return;
    row.dataset.frontProfile = frontProfileNext(row.dataset.frontProfile || 'none');
    syncFrontProfileBtn(row);
  }
  function syncFrontProfileBtn(row){
    var btn = row.querySelector('.fprof'); if (!btn) return;
    var id = row.dataset.frontProfile || 'none';
    var rec = frontProfileRec(id);
    var nxt = frontProfileNext(id);
    var nxtRec = frontProfileRec(nxt);
    var nxtTxt = nxtRec ? nxtRec.name : 'bez profilu';
    var txt = rec
      ? ('Úchytkový profil: ' + rec.name + ' — čelo sa skráti o ' + Math.round(rec.reduction) +
         ' mm (klik = ' + nxtTxt + ')')
      : ('Úchytkový profil: bez profilu (klik = ' + nxtTxt + ')');
    btn.classList.toggle('on', !!rec);
    btn.setAttribute('aria-pressed', rec ? 'true' : 'false');
    btn.title = txt;
    btn.setAttribute('aria-label', txt);
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
        span.innerHTML = NXIcons.svg('link') + esc(badge); // B3/B9: ikona staticka, badge cez esc
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
    // UI-B1 (Codex #168 P2): rozbal CELU cestu k riadku — od sektora Nastavenia
    // po skupinu Cela. Zbalený predok by fokus aj scroll zhltol.
    if (typeof nxRevealTarget === 'function') nxRevealTarget(row);
    row.scrollIntoView({ block: 'nearest' });
    var fh = row.querySelector('.fh');
    if (fh) fh.focus();
  }

  // Node testy (tests/js/test_uic1b_vkladanie.js) — v CEF je module undefined
  // a zvysok suboru bezi normalne (vzor board_card.js / preview.js). Exportuju
  // sa LEN ciste funkcie kreslenia dlazdic sablon (ziadny DOM).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { nxTplGlyph: nxTplGlyph, nxTplBadge: nxTplBadge };
  }

