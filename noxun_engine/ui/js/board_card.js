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
    var isDim = (key === 'length' || key === 'width');
    if (isDim){
      var elm = el(key === 'length' ? 'bc_length' : 'bc_width');
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
    // D-41 C2: dekor bez pouzitelnej 1,0 mm pasky pre NOVU hrubku dosky -> modal
    // pred odoslanim (server check je autorita, toto je len UX vrstva).
    if (v && !absUsableExists(MATERIALS.edges, decorOfSheet(v), 1.0, sheetThicknessOf(v))){
      var prev = boardCard.material_id || '';
      openAbsModal('Dekor „' + decorOfSheet(v) + '" nemá použiteľnú 1,0 mm ABS pásku pre túto hrúbku — prevedené hrany by ostali bez ABS.',
        function(create){ sendBoardMaterial(v, create); },
        function(){ if (el('bc_material')) el('bc_material').value = prev; regroupBoardEdges(decorOfSheet(prev)); });
      return;
    }
    sendBoardMaterial(v, false);
  }
  function sendBoardMaterial(v, createAbs){
    if (!boardCard) return;
    // F3: pregrupuj ABS hrany dosky LOKALNE podla noveho dekoru — doska ma vzdy
    // konkretny material (ziadne dedenie => vzdy ratame). N7: ziadny change event.
    regroupBoardEdges(decorOfSheet(v));
    if (window.sketchup && sketchup.set_board_material)
      sketchup.set_board_material(JSON.stringify({ board_id: boardCard.board_id, material_id: v,
        create_missing_abs: !!createAbs }));
  }
  // F3/N7: prekresli options ABS selectov dosky podla dekoru, zachova hodnotu (aj F5).
  function regroupBoardEdges(decor){
    var box = el('boardEdgeRows'); if (!box) return;
    var sels = box.querySelectorAll('select[data-edge]');
    for (var i=0;i<sels.length;i++){
      var cur = sels[i].value;
      sels[i].innerHTML = boardEdgeOptionsHtml(decor, cur);
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
    if (!absUsableExists(MATERIALS.edges, decor, 1.0, th === null ? parseFloat(boardCard.thickness) : th)){
      openAbsModal('Dekor „' + decor + '" nemá použiteľnú 1,0 mm ABS pásku — bez nej sa hrany nedajú olepiť.',
        function(create){ sendBoardEdgesAll(create); }, null);
      return;
    }
    sendBoardEdgesAll(false);
  }
  function sendBoardEdgesAll(createAbs){
    if (!boardCard) return;
    flushBoardEditsNow();
    if (window.sketchup && sketchup.set_board_edges_all)
      sketchup.set_board_edges_all(JSON.stringify({ board_id: boardCard.board_id, create_missing_abs: !!createAbs }));
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
    if (el('bc_thickness')) el('bc_thickness').value = fmtmm(bc.thickness);
    if (el('bc_grain') && document.activeElement !== el('bc_grain')) el('bc_grain').value = bc.grain_direction || 'none';
    if (el('bc_diag')) el('bc_diag').textContent = 'Výrobná trieda: sheet · ide do výroby';
    var ms = el('bc_material');
    if (ms){ fillBoardMaterialSelect(ms, bc.material_id || ''); }
    renderBoardEdgeRows(bc);
    renderBoardSvg(bc);
  }

  // Material select dosky: VSETKY doskove materialy bez hrubkoveho filtra a bez
  // "dedit" volby — doska ma vzdy konkretny katalogovy material (snapshot).
  function fillBoardMaterialSelect(sel, keepValue){
    var cur = (keepValue !== undefined && keepValue !== null) ? keepValue : sel.value;
    var html = '';
    MATERIALS.sheets.forEach(function(s){
      html += '<option value="' + esc(s.id) + '">' + esc(s.label) + '</option>';
    });
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
      // D-36: skupiny podla resolved dekoru materialu dosky (bez inherit — doska nema
      // override vrstvu). curVal drzi hodnotu hrany aj legacy mimo katalogu (F5).
      var curVal = absId == null ? '' : absId;
      sel.innerHTML = boardEdgeOptionsHtml(decorOfSheet(bc.material_id), curVal);
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
    var edges = bc.edges || {}, lab = bc.edge_labels || {};
    function ecol(code){ return absColorOf(edges[code]); }
    function bar(side, code, fill){
      if (side === 'top')    return '<rect class="behit" data-edge="' + code + '" x="' + ox + '" y="' + (oy - ew / 2) + '" width="' + rw + '" height="' + ew + '" fill="' + fill + '" style="cursor:pointer"/>';
      if (side === 'bottom') return '<rect class="behit" data-edge="' + code + '" x="' + ox + '" y="' + (oy + rh - ew / 2) + '" width="' + rw + '" height="' + ew + '" fill="' + fill + '" style="cursor:pointer"/>';
      if (side === 'left')   return '<rect class="behit" data-edge="' + code + '" x="' + (ox - ew / 2) + '" y="' + oy + '" width="' + ew + '" height="' + rh + '" fill="' + fill + '" style="cursor:pointer"/>';
      return '<rect class="behit" data-edge="' + code + '" x="' + (ox + rw - ew / 2) + '" y="' + oy + '" width="' + ew + '" height="' + rh + '" fill="' + fill + '" style="cursor:pointer"/>';
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
      S.push(label(side, lab[code]));
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
  // Zmena materialu vo vkladacej karte: dosad hrubku + default smer dekoru z katalogu.
  function onInsertBoardMaterial(){
    var ms = el('ib_material'); if (!ms) return;
    var sheet = null;
    for (var i = 0; i < MATERIALS.sheets.length; i++){
      if (MATERIALS.sheets[i].id === ms.value){ sheet = MATERIALS.sheets[i]; break; }
    }
    if (el('ib_thickness')) el('ib_thickness').value = sheet ? fmtmm(sheet.thickness) : '';
    if (el('ib_grain') && sheet && sheet.grain) el('ib_grain').value = sheet.grain;
  }
  function insertBoard(){
    // V0.4.7e: rozmery cez evalDim — vyraz sa vyhodnoti, nezmysel sa odmietne
    // (surovy '650-36' by Ruby to_f orezalo na 650)
    var lRaw = el('ib_length') ? el('ib_length').value : '';
    var wRaw = el('ib_width') ? el('ib_width').value : '';
    var l = String(lRaw).trim() === '' ? '' : evalDim(lRaw);
    var w = String(wRaw).trim() === '' ? '' : evalDim(wRaw);
    if ((l !== '' && isNaN(l)) || (w !== '' && isNaN(w))){
      NX.setStatus('Skontroluj rozmery dosky (neplatný výraz).', true);
      return;
    }
    var payload = {
      name: (el('ib_name') ? el('ib_name').value : ''),
      length: l,
      width: w,
      material_id: (el('ib_material') ? el('ib_material').value : ''),
      grain_direction: (el('ib_grain') ? el('ib_grain').value : '')
    };
    if (window.sketchup && sketchup.insert_board) sketchup.insert_board(JSON.stringify(payload));
  }
