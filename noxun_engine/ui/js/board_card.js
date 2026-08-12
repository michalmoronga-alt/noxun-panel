  // ===================== V0.4.7c KARTA DOSKY (samostatny vyrobny dielec) =====================
  // Vlastny namespacovany stav + vlastne DOM ID (boardSvg/boardEdgeRows) — VEDOME kopia
  // vzoru part_card.js, nie zdielany modul (Codex audit c: extrakcia zdielaneho edge
  // editora by bola regresne rizikovy refaktor part karty; zjednotenie az samostatnym PR).
  //
  // Ochrana pred oneskorenym zapisom (Codex audit c, blocker A): debounce AKUMULUJE
  // zmeny do boardPending so snapshotom board_id z casu naplanovania; NX.loadSelected/
  // clearSelected/loadBoard(ina doska) pending rusia; Ruby naviac overuje echo board_id.
  var boardCard = null;      // aktualny payload karty dosky (null = ziadna)
  var boardPending = null;   // { board_id, fields:{...} } — akumulovane zmeny pred flushom
  var boardTimer = null;

  function cancelBoardEdits(){
    if (boardTimer){ clearTimeout(boardTimer); boardTimer = null; }
    boardPending = null;
  }
  function flushBoardEdits(){
    boardTimer = null;
    var p = boardPending; boardPending = null;
    if (!p || !p.board_id) return;
    if (window.sketchup && sketchup.set_board_fields) sketchup.set_board_fields(JSON.stringify(p));
  }
  // Okamzity flush (Enter commit) — VZDY najprv zrusi bezaici timeout, inak by
  // stary timer predcasne flushol nasledujuci novy edit (Codex expr audit).
  function flushBoardEditsNow(){
    if (boardTimer){ clearTimeout(boardTimer); boardTimer = null; }
    flushBoardEdits();
  }
  // Obycajne polia (name/length/width/quantity/grain_direction): akumulacia + debounce 400 ms.
  // V0.4.7e + Codex GH #35: rozmery sa queue-uju VZDY az VYHODNOTENE cez evalDim
  // ('10,5' by Ruby to_f ulozilo ako 10.0; '650mm' ako 650); rozpisany vyraz sa
  // nequeue-uje a STIAHNE aj svoj skorsi ciselny prefix z pendingu (pauza po
  // '650-' nesmie flushnut 650); neplatny vstup = cerveny okraj, nic sa neposle.
  function withdrawPending(key){
    if (!boardPending) return;
    delete boardPending.fields[key];
    if (!Object.keys(boardPending.fields).length) cancelBoardEdits();
  }
  function onBoardField(key, value){
    if (!boardCard) return;
    // M-B1: thickness sa edituje LEN pri UNI (readOnly pole inak input neda,
    // ale guard drzi aj proti programovym zmenam; server je autorita).
    if (key === 'thickness' && boardCard.uni !== true) return;
    var isDim = (key === 'length' || key === 'width' || key === 'thickness');
    if (isDim){
      var elm = el(key === 'length' ? 'bc_length' : (key === 'width' ? 'bc_width' : 'bc_thickness'));
      if (isExprStr(value)){ withdrawPending(key); return; } // zivy nahlad; commit az Enter/blur
      var v = String(value).trim() === '' ? NaN : evalDim(value);
      if (isNaN(v)){
        if (elm && String(value).trim() !== '') elm.classList.add('bad');
        withdrawPending(key);
        return;
      }
      if (elm) elm.classList.remove('bad');
      value = v;
    }
    if (!boardPending || boardPending.board_id !== boardCard.board_id){
      boardPending = { board_id: boardCard.board_id, fields: {} };
    }
    boardPending.fields[key] = value;
    if (boardTimer) clearTimeout(boardTimer);
    boardTimer = setTimeout(flushBoardEdits, 400);
  }
  // Material: okamzity zapis (select) — hrubka nasleduje katalog na Ruby strane.
  function onBoardMaterial(v){
    if (!boardCard) return;
    // D-41 C2: dekor bez pouzitelnej jednotkovej pasky pre NOVU hrubku dosky ->
    // modal pred odoslanim (server check je autorita, toto je len UX vrstva;
    // 2A-3b: dispatcher zrkadli schema 2 hierarchiu group/structure/universal).
    if (v && !absUsableForSheet(MATERIALS.edges, sheetRecOf(v), catalogSchemaNow(), sheetThicknessOf(v))){
      var prev = boardCard.material_id || '';
      openAbsModal('Dekor „' + decorOfSheet(v) + '" nemá použiteľnú ' + absMissingLabel(catalogSchemaNow()) + ' pre túto hrúbku — prevedené hrany by ostali bez ABS.',
        function(create){ sendBoardMaterial(v, create); },
        function(){ if (el('bc_material')) el('bc_material').value = prev; regroupBoardEdges(prev); });
      return;
    }
    sendBoardMaterial(v, false);
  }
  function sendBoardMaterial(v, createAbs){
    if (!boardCard) return;
    // F3: pregrupuj ABS hrany dosky LOKALNE podla noveho materialu — doska ma
    // vzdy konkretny material (ziadne dedenie => vzdy ratame). N7: ziadny change event.
    regroupBoardEdges(v);
    if (window.sketchup && sketchup.set_board_material)
      sketchup.set_board_material(JSON.stringify({ board_id: boardCard.board_id, material_id: v,
        create_missing_abs: !!createAbs,
        catalog_schema: (typeof PANEL_CLIENT_SCHEMA !== 'undefined' ? PANEL_CLIENT_SCHEMA : 1) }));
  }
  // F3/N7: prekresli options ABS selectov dosky podla materialu (2A-3b:
  // parameter je material_id), zachova hodnotu (aj F5).
  function regroupBoardEdges(materialId){
    var box = el('boardEdgeRows'); if (!box) return;
    var sels = box.querySelectorAll('select[data-edge]');
    for (var i=0;i<sels.length;i++){
      var cur = sels[i].value;
      sels[i].innerHTML = boardEdgeOptionsHtml(materialId, cur);
      sels[i].value = cur;
    }
  }
  // ABS hrana: okamzity zapis JEDNEJ hrany; kompletnu mapu sklada Ruby (read-modify-write).
  function onBoardEdgeChange(code, value){
    if (!boardCard) return;
    if (window.sketchup && sketchup.set_board_edge)
      sketchup.set_board_edge(JSON.stringify({ board_id: boardCard.board_id, edge: code, abs_id: value }));
  }
  // D-35: olep vsetky 4 hrany ABS 1.0 dekoru materialu dosky (1 rebuild = 1 undo).
  // PRED bulkom flush pending debounce editov (audit FIX 6) — cakajuci zapis poli
  // nesmie prist AZ PO bulku (callbacky sa vykonavaju v poradi odoslania).
  function onBoardEdgesAll(){
    if (!boardCard) return;
    // D-41 C2: chybajuca pouzitelna paska -> ponuka dovytvorenia pred bulkom.
    var decor = decorOfSheet(boardCard.material_id);
    var th = sheetThicknessOf(boardCard.material_id);
    if (!absUsableForSheet(MATERIALS.edges, sheetRecOf(boardCard.material_id), catalogSchemaNow(),
                           th === null ? parseFloat(boardCard.thickness) : th)){
      openAbsModal('Dekor „' + decor + '" nemá použiteľnú ' + absMissingLabel(catalogSchemaNow()) + ' — bez nej sa hrany nedajú olepiť.',
        function(create){ sendBoardEdgesAll(create); }, null);
      return;
    }
    sendBoardEdgesAll(false);
  }
  function sendBoardEdgesAll(createAbs){
    if (!boardCard) return;
    flushBoardEditsNow();
    if (window.sketchup && sketchup.set_board_edges_all)
      sketchup.set_board_edges_all(JSON.stringify({ board_id: boardCard.board_id, create_missing_abs: !!createAbs,
        catalog_schema: (typeof PANEL_CLIENT_SCHEMA !== 'undefined' ? PANEL_CLIENT_SCHEMA : 1) }));
  }

  // Zapis hodnoty len ked pole NEMA fokus — refresh z backendu nesmie prepisat
  // rozpisanu hodnotu pouzivatela (echo po auto-apply).
  function bset(id, v){
    var e = el(id);
    if (e && document.activeElement !== e) e.value = (v === null || v === undefined) ? '' : v;
  }
  // Editovatelny rozmer: zaokruhlenie na 2 des. miesta bez straty desatin.
  function fmtdim(v){
    if (v === null || v === undefined || v === '') return '';
    var n = parseFloat(v);
    return isNaN(n) ? '' : String(Math.round(n * 100) / 100);
  }

  function renderBoardCard(bc){
    boardCard = bc;
    var box = el('boardCard');
    if (!box) return;
    if (!bc){ box.style.display = 'none'; return; }
    box.style.display = '';
    if (el('bcHead')) el('bcHead').innerHTML = '<b>' + esc(bc.name || 'Doska') + '</b> · ' + esc(bc.role_label || bc.role || '');
    bset('bc_name', bc.name || '');
    // fmtdim (nie fmtmm): editovatelny rozmer nesmie vizualne stratit desatiny
    // (10/4 = 2.5 sa nesmie ukazat ako 3, ked ulozene je 2.5)
    bset('bc_length', fmtdim(bc.length));
    bset('bc_width', fmtdim(bc.width));
    bset('bc_quantity', bc.quantity || 1);
    if (el('bc_role')) el('bc_role').value = bc.role_label || bc.role || '';
    // V0.6 M-B1: hrubku UNI dosky urcuje dielec — pole sa odomyka (server
    // guard: pri realnom materiali sa thickness payload zahadzuje).
    var bcth = el('bc_thickness');
    if (bcth){
      bcth.value = fmtmm(bc.thickness);
      bcth.readOnly = bc.uni !== true;
      bcth.title = bc.uni === true ? 'UNI: hrúbku určuje doska (6–60 mm)' : 'Hrúbku určuje materiál';
    }
    if (el('bc_grain') && document.activeElement !== el('bc_grain')) el('bc_grain').value = bc.grain_direction || 'none';
    if (el('bc_diag')) el('bc_diag').textContent = 'Výrobná trieda: sheet · ide do výroby';
    var ms = el('bc_material');
    if (ms){ fillBoardMaterialSelect(ms, bc.material_id || '', true); }
    renderBoardEdgeRows(bc);
    renderBoardSvg(bc);
  }

  // Material select dosky: VSETKY doskove materialy bez hrubkoveho filtra a bez
  // "dedit" volby — doska ma vzdy konkretny katalogovy material (snapshot).
  // D-49 (audit B3): withOffers pridava virtualne duplaky — dostava ich LEN
  // karta OZNACENEJ dosky (set_board_material ma resolver); VKLADACI select
  // ich nesmie mat (add_board by poslal duplak2:* rovno do BoardBuilder).
  function fillBoardMaterialSelect(sel, keepValue, withOffers){
    var cur = (keepValue !== undefined && keepValue !== null) ? keepValue : sel.value;
    var html = '';
    MATERIALS.sheets.forEach(function(s){
      html += '<option value="' + esc(s.id) + '">' + esc(s.label) + '</option>';
    });
    if (withOffers){
      (MATERIALS.duplak_offers || []).forEach(function(s){
        html += '<option value="' + esc(s.id) + '">' + esc(s.label) + '</option>';
      });
    }
    sel.innerHTML = html;
    sel.value = cur;
  }

  function renderBoardEdgeRows(bc){
    var box = el('boardEdgeRows'); if (!box) return;
    box.innerHTML = '';
    ['L1', 'L2', 'W1', 'W2'].forEach(function(code){
      var lbl = (bc.edge_labels && bc.edge_labels[code]) || code;
      var absId = bc.edges ? bc.edges[code] : null;
      var row = document.createElement('div'); row.className = 'edgerow';
      row.innerHTML = '<span class="en"><i style="background:' + absColorOf(absId) + '"></i>' + esc(lbl) + '</span>';
      var sel = document.createElement('select');
      // D-36: skupiny podla resolved materialu dosky (2A-3b: cez material_id;
      // bez inherit — doska nema override vrstvu). curVal drzi hodnotu hrany
      // aj legacy mimo katalogu (F5).
      var curVal = absId == null ? '' : absId;
      // D-102: pri nelepitelnom materiali (KOMPAKT / PD postforming) volba povie
      // „Bez ABS (nelepí sa)" — text sklada server (bc.edge_none_option).
      sel.innerHTML = boardEdgeOptionsHtml(bc.material_id, curVal, bc.edge_none_option);
      sel.value = curVal;
      sel.setAttribute('data-edge', code);
      sel.onchange = (function(cc, ss){ return function(){ onBoardEdgeChange(cc, ss.value); }; })(code, sel);
      row.appendChild(sel);
      box.appendChild(row);
    });
  }

  // 2D doska: lezaci obdlznik (length vodorovne), hrany farebne podla ABS, klik = fokus dropdownu.
  // Mapu stran dava Ruby (edge_sides — free_panel je lying), rovnaky princip ako part SVG.
  function renderBoardSvg(bc){
    var svg = el('boardSvg'); if (!svg) return;
    var L = Math.max(1, parseFloat(bc.length) || 100), Wd = Math.max(1, parseFloat(bc.width) || 100);
    var sides = bc.edge_sides || { L1: 'bottom', L2: 'top', W1: 'left', W2: 'right' };
    var lVert = (sides.L1 === 'left' || sides.L1 === 'right');
    var horiz = lVert ? Wd : L, vert = lVert ? L : Wd;
    var pad = 28, availW = 300 - 2 * pad, availH = 200 - 2 * pad;
    var sc = Math.min(availW / horiz, availH / vert); if (!isFinite(sc) || sc <= 0) sc = 1;
    var rw = horiz * sc, rh = vert * sc, ox = (300 - rw) / 2, oy = (200 - rh) / 2, ew = 7;
    var edges = bc.edges || {}, lab = bc.edge_labels || {}, hints = bc.edge_hints || {};
    function ecol(code){ return absColorOf(edges[code]); }
    // D-102: tooltip s plnym textom pasky + skratka do EXISTUJUCEHO popisku strany
    // (ziadny novy riadok — pravidlo vertikalneho priestoru).
    function tip(code){ return (hints[code] && hints[code].title) ? hints[code].title : ''; }
    function sideText(code){
      return edgeSideText(lab[code], hints[code] ? hints[code].short : '');
    }
    function bar(side, code, fill){
      var t = tip(code) ? '<title>' + esc(tip(code)) + '</title>' : '';
      if (side === 'top')    return '<rect class="behit" data-edge="' + code + '" x="' + ox + '" y="' + (oy - ew / 2) + '" width="' + rw + '" height="' + ew + '" fill="' + fill + '" style="cursor:pointer">' + t + '</rect>';
      if (side === 'bottom') return '<rect class="behit" data-edge="' + code + '" x="' + ox + '" y="' + (oy + rh - ew / 2) + '" width="' + rw + '" height="' + ew + '" fill="' + fill + '" style="cursor:pointer">' + t + '</rect>';
      if (side === 'left')   return '<rect class="behit" data-edge="' + code + '" x="' + (ox - ew / 2) + '" y="' + oy + '" width="' + ew + '" height="' + rh + '" fill="' + fill + '" style="cursor:pointer">' + t + '</rect>';
      return '<rect class="behit" data-edge="' + code + '" x="' + (ox + rw - ew / 2) + '" y="' + oy + '" width="' + ew + '" height="' + rh + '" fill="' + fill + '" style="cursor:pointer">' + t + '</rect>';
    }
    function label(side, txt){
      txt = esc(txt || '');
      if (side === 'top')    return '<text x="150" y="' + (oy - 10) + '" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none">' + txt + '</text>';
      if (side === 'bottom') return '<text x="150" y="' + (oy + rh + 17) + '" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none">' + txt + '</text>';
      if (side === 'left')   return '<text x="' + (ox - 11) + '" y="' + (oy + rh / 2) + '" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none" transform="rotate(-90 ' + (ox - 11) + ' ' + (oy + rh / 2) + ')">' + txt + '</text>';
      return '<text x="' + (ox + rw + 11) + '" y="' + (oy + rh / 2) + '" font-size="11" fill="#78909c" text-anchor="middle" pointer-events="none" transform="rotate(90 ' + (ox + rw + 11) + ' ' + (oy + rh / 2) + ')">' + txt + '</text>';
    }
    var S = [];
    S.push('<rect x="' + ox + '" y="' + oy + '" width="' + rw + '" height="' + rh + '" fill="#faf6ee" stroke="#cfd8dc"/>');
    ['L1', 'L2', 'W1', 'W2'].forEach(function(code){
      var side = sides[code]; if (!side) return;
      S.push(bar(side, code, ecol(code)));
      S.push(label(side, sideText(code)));
    });
    S.push('<text x="150" y="100" font-size="12" fill="#b0bec5" text-anchor="middle" dominant-baseline="middle" pointer-events="none">' + Math.round(L) + '×' + Math.round(Wd) + '</text>');
    svg.innerHTML = S.join('');
  }

  function setupBoardSvgDelegation(){
    var svg = el('boardSvg'); if (!svg) return;
    svg.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'behit'); if (!t) return;
      var code = t.getAttribute('data-edge');
      var sel = el('boardEdgeRows').querySelector('select[data-edge="' + code + '"]');
      if (sel){ sel.focus(); NX.setStatus('Hrana ' + code + ' — vyber ABS v zozname.', false); }
    });
  }

  // ===================== VKLADACIA CAST (prepinac Korpus/Doska) =====================
  // Codex #142 P2: material, pre ktory je v poli Hrubka dosadena katalogova
  // hodnota — rozlisi ZMENU VYBERU od obycajneho refreshu katalogu (draft UNI
  // hrubky refresh neprezije, ked sa porovnava len fokus).
  var insertMatLast = null;
  var insertGrainTouched = false; // D-86: siahol pouzivatel na smer dekoru pri tomto materiali?
  function getInsertKind(){
    var r = document.querySelector('input[name=ikind]:checked');
    return r ? r.value : 'cabinet';
  }
  function onInsertKindChange(){
    var kind = getInsertKind();
    document.body.setAttribute('data-insert-kind', kind); // atribut PREZIJE setUiMode className prepis
    if (kind === 'board'){
      var ms = el('ib_material');
      if (ms && !ms.options.length){ fillBoardMaterialSelect(ms, ''); onInsertBoardMaterial(); }
    }
  }
  // D-05: po zmene katalogu (NX.setMaterials) sa vkladaci select NEplni "iba raz" —
  // force refill so zachovanim platneho vyberu + prepocet hrubky/grainu. Fokusovany
  // select sa nechava tak (nerozbit rozkliknuty dropdown).
  function refreshInsertBoardMaterials(){
    var ms = el('ib_material');
    if (!ms || !ms.options.length) return; // este nenaplneny — naplni onInsertKindChange
    if (document.activeElement === ms) return;
    var keep = ms.value;
    fillBoardMaterialSelect(ms, keep);
    if (ms.value !== keep || !ms.value){ ms.selectedIndex = ms.selectedIndex < 0 ? 0 : ms.selectedIndex; }
    onInsertBoardMaterial();
  }
  // --- E-03: hrubka vo vkladacej karte (ciste funkcie, testuje test_e03_board_insert.js) ---
  // UNI material nema hrubkovu identitu — hrubku urcuje DIELEC (M-B1), takze
  // vkladacie pole sa pri nom odomyka. Pri realnom materiali hrubku diktuje
  // katalog: pole ostava zamknute A payload ju ani nenesie. Autorita je server
  // (BoardBuilder.insert_thickness_for) — toto je len UX zrkadlo.
  function sheetIsUni(sheet){ return !!(sheet && sheet.uni === true); }
  function findSheetIn(sheets, id){
    for (var i = 0; i < (sheets || []).length; i++){
      if (sheets[i] && sheets[i].id === id) return sheets[i];
    }
    return null;
  }
  // Codex #142 P2: ma sa hrubka vo vkladacej karte PREPISAT z katalogu?
  // Rozpisany UNI draft ("12") nesmie zmiznut pri zivom sync katalogu
  // (NX.setMaterials po CRUD v okne Materialy vola refreshInsertBoardMaterials).
  // Fokus je slaby signal — pouzivatel klika v DRUHOM okne, tu ho nema nikto.
  // Preto rozhoduje ZMENA VYBERU materialu:
  //   iny material (aj UNI<->realny, aj zmizol z katalogu) -> prepis (novy default),
  //   ten isty UNI material -> NEPREPISUJ (drz draft pouzivatela),
  //   ten isty realny material -> prepis (pole je zamknute, ziadny draft neexistuje),
  //   pole ma prave fokus -> nikdy neprepisuj (pisanie v TOMTO okne).
  function insertThicknessShouldWrite(prevMaterialId, materialId, sheet, focused){
    if (focused) return false;
    if (materialId !== prevMaterialId) return true;
    return !sheetIsUni(sheet);
  }
  // D-86: ma sa SMER DEKORU vo vkladacej karte prepisat katalogovou predvolbou?
  // Rovnaka trieda chyby ako E-03 draft hrubky, ale insertThicknessShouldWrite sa
  // pouzit NEDA: ten pri rovnakom REALNOM materiali vracia true (pole je vtedy
  // zamknute, ziadny draft neexistuje) — smer dekoru sa vsak da menit pri KAZDOM
  // materiali, takze by zivy refresh katalogu (NX.setMaterials -> refreshInsert-
  // BoardMaterials) vedomu volbu ("Bez smeru") ticho vratil na predvolbu.
  // Rozhoduje preto dvojica ZMENA MATERIALU + siahol nan pouzivatel:
  //   iny material            -> prepis (predvolba noveho materialu),
  //   ten isty + touched      -> NEPREPISUJ (drz vedomu volbu pouzivatela),
  //   ten isty + netknuty     -> prepis sa smie (v poli je aj tak predvolba),
  //   katalog nema predvolbu  -> nic (select ma pevne moznosti, necisti sa),
  //   select ma prave fokus   -> nikdy (rozkliknuty dropdown v TOMTO okne).
  function insertGrainShouldWrite(prevMaterialId, materialId, sheet, touched, focused){
    if (!sheet || !sheet.grain) return false;
    if (focused) return false;
    if (materialId !== prevMaterialId) return true;
    return !touched;
  }
  // Poskladaj payload vkladanej dosky z HODNOT formulara (ziadny DOM, ziadne globaly).
  // vals: surove stringy {name,length,width,material_id,grain_direction,thickness}
  // sheet: katalogovy zaznam vybraneho materialu (alebo null)
  // -> { ok:true, payload:{...} } | { ok:false, error:'hlaska pre status' }
  function buildInsertBoardPayload(vals, sheet, evalFn){
    vals = vals || {};
    var ev = evalFn || (typeof evalDim === 'function' ? evalDim : null);
    // V0.4.7e: rozmery cez evalDim — vyraz sa vyhodnoti, nezmysel sa odmietne
    // (surovy '650-36' by Ruby to_f orezalo na 650)
    function dim(rawv){
      var s = String(rawv === null || rawv === undefined ? '' : rawv).trim();
      if (s === '') return '';
      return ev ? ev(s) : parseFloat(s);
    }
    var l = dim(vals.length), w = dim(vals.width);
    if ((l !== '' && isNaN(l)) || (w !== '' && isNaN(w))){
      return { ok: false, error: 'Skontroluj rozmery dosky (neplatný výraz).' };
    }
    var payload = {
      name: String(vals.name === null || vals.name === undefined ? '' : vals.name),
      length: l,
      width: w,
      material_id: String(vals.material_id === null || vals.material_id === undefined ? '' : vals.material_id),
      grain_direction: String(vals.grain_direction === null || vals.grain_direction === undefined ? '' : vals.grain_direction)
    };
    if (sheetIsUni(sheet)){
      var t = dim(vals.thickness);
      if (t !== '' && isNaN(t)) return { ok: false, error: 'Skontroluj hrúbku dosky (neplatný výraz).' };
      if (t !== '') payload.thickness = t; // prazdna = server dosadi default roly
    }
    return { ok: true, payload: payload };
  }
  // D-86: pouzivatel prave vedome zmenil smer dekoru — od tejto chvile ho zivy
  // refresh katalogu (pri NEZMENENOM materiali) nesmie prepisat.
  function onInsertGrainChange(){ insertGrainTouched = true; }
  // Zmena materialu vo vkladacej karte: dosad hrubku + default smer dekoru z katalogu.
  function onInsertBoardMaterial(){
    var ms = el('ib_material'); if (!ms) return;
    var prevMat = insertMatLast;
    var sheet = findSheetIn(MATERIALS.sheets, ms.value);
    var th = el('ib_thickness');
    if (th){
      var uni = sheetIsUni(sheet);
      th.readOnly = !uni; // UNI = odomknute (readonly styling riesi CSS)
      th.title = uni ? 'UNI: hrúbku určuje doska' : 'Hrúbku určuje materiál';
      if (insertThicknessShouldWrite(prevMat, ms.value, sheet, document.activeElement === th)){
        th.value = sheet ? fmtmm(sheet.thickness) : '';
        // Zivy nahlad vyrazu ("= 12") visi na input evente — po programovom
        // prepise ho zosynchronizuj, inak po zmene materialu ostane stary.
        // Nebubla: jediny poslucac je expr handler pripojeny na tomto poli.
        th.dispatchEvent(new Event('input'));
      }
    }
    insertMatLast = ms.value;
    // D-86: predvolba smeru sa dosadi len ked na to ma pravo (viz guard vyssie).
    // Po dosadeni je v poli katalogova hodnota, nie volba pouzivatela — priznak padne.
    var gs = el('ib_grain');
    if (gs && insertGrainShouldWrite(prevMat, ms.value, sheet, insertGrainTouched,
                                     document.activeElement === gs)){
      gs.value = sheet.grain;
      insertGrainTouched = false;
    }
  }
  function insertBoard(){
    var ms = el('ib_material');
    var res = buildInsertBoardPayload({
      name: el('ib_name') ? el('ib_name').value : '',
      length: el('ib_length') ? el('ib_length').value : '',
      width: el('ib_width') ? el('ib_width').value : '',
      material_id: ms ? ms.value : '',
      grain_direction: el('ib_grain') ? el('ib_grain').value : '',
      thickness: el('ib_thickness') ? el('ib_thickness').value : ''
    }, findSheetIn(MATERIALS.sheets, ms ? ms.value : ''));
    if (!res.ok){ NX.setStatus(res.error, true); return; }
    if (window.sketchup && sketchup.insert_board) sketchup.insert_board(JSON.stringify(res.payload));
  }

  // Node testy (tests/js/test_e03_board_insert.js) — v CEF je module undefined,
  // vetva sa preskoci. Exportuju sa LEN ciste funkcie (bez DOM/MATERIALS).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { buildInsertBoardPayload: buildInsertBoardPayload,
                       sheetIsUni: sheetIsUni, findSheetIn: findSheetIn,
                       insertThicknessShouldWrite: insertThicknessShouldWrite,
                       insertGrainShouldWrite: insertGrainShouldWrite };
  }
