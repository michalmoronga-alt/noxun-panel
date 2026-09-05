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

  // R-02 (review #264 kolo 2): CIEL odlozeneho rozhodnutia karty dosky =
  // dvojica DOSKA + DOKUMENT z casu, ked pouzivatel akciu spustil. Modal
  // chybajucej ABS je asynchronny (caka na klik) a `boardCard` je mutovatelny
  // globál — bez snapshotu by sa „Vytvoriť a pokračovať" aplikovalo na dosku,
  // ktora je na obrazovke TERAZ, nie na tu, o ktorej pouzivatel rozhodoval.
  function boardTarget(){
    return boardCard ? { id: boardCard.board_id, guid: nxDocGuid() } : null;
  }
  function boardTargetStale(t){
    return !t || !boardCard || t.id !== boardCard.board_id || t.guid !== nxDocGuid();
  }
  function flushBoardEdits(){
    boardTimer = null;
    var p = boardPending; boardPending = null;
    if (!p || !p.board_id) return;
    // R-02: identita dokumentu ide s KAZDYM zapisovym payloadom karty dosky —
    // tu ZACHYTENA pri naplanovani editu, nie precitana pri odosielani.
    var g = p.guid;
    delete p.guid; // pracovny kluc pendingu, nie pole payloadu
    if (window.sketchup && sketchup.set_board_fields) sketchup.set_board_fields(nxDocPayload(p, g));
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
    // R-02 (review #264 P1): s doskou sa zachytáva aj DOKUMENT z času
    // NAPLÁNOVANIA. `nxModelGuid` je globál, ktorý prepíše najbližší push —
    // bez snapshotu by sa zápis odložený o 400 ms opečiatkoval NOVÝM
    // dokumentom a guard by ho pustil do cudzej zákazky.
    //
    // Kolo 2: batch je kľúčovaný DVOJICOU dokument+doska. Samotné `board_id`
    // nestačí — `BRD-001` je v každej zákazke, takže edit v novom dokumente by
    // sa primiešal do batchu zo starého (a s jeho guidom): timer by ho poslal
    // ako cudzí (server odmietne, hodnota STRATENÁ), a návrat do pôvodného
    // dokumentu by hodnoty z toho druhého zapísal sem. Pri nesúlade sa starý
    // pending ZAHODÍ a založí nový.
    var pendGuid = nxDocGuid();
    if (!boardPending || boardPending.board_id !== boardCard.board_id ||
        boardPending.guid !== pendGuid){
      cancelBoardEdits();
      boardPending = { board_id: boardCard.board_id, guid: pendGuid, fields: {} };
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
      var tgt = boardTarget(); // R-02: doska + dokument z casu OTVORENIA modalu
      openAbsModal('Dekor „' + decorOfSheet(v) + '" nemá použiteľnú ' + absMissingLabel(catalogSchemaNow()) + ' pre túto hrúbku — prevedené hrany by ostali bez ABS.',
        function(create){ sendBoardMaterial(v, create, tgt); },
        function(){ if (el('bc_material')) el('bc_material').value = prev; regroupBoardEdges(prev); });
      return;
    }
    sendBoardMaterial(v, false);
  }
  // `forBoard` = snapshot { id, guid } z casu, ked pouzivatel akciu spustil
  // (cesta cez modal chybajucej ABS). Priame volanie ho vynecha — vtedy je
  // cielom prave to, na co sa pouzivatel pozera.
  function sendBoardMaterial(v, createAbs, forBoard){
    if (!boardCard) return;
    var tgt = forBoard || boardTarget();
    if (boardTargetStale(tgt)){
      NX.setStatus('Karta sa medzitým zmenila — materiál dosky sa nenastavil.', true);
      return;
    }
    // F3: pregrupuj ABS hrany dosky LOKALNE podla noveho materialu — doska ma
    // vzdy konkretny material (ziadne dedenie => vzdy ratame). N7: ziadny change event.
    regroupBoardEdges(v);
    if (window.sketchup && sketchup.set_board_material)
      sketchup.set_board_material(nxDocPayload({ board_id: tgt.id, material_id: v,
        create_missing_abs: !!createAbs,
        catalog_schema: (typeof PANEL_CLIENT_SCHEMA !== 'undefined' ? PANEL_CLIENT_SCHEMA : 1) }, tgt.guid));
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
    nxComboSync(box); // D-85: pregrupovane volby -> obnov popisky triggerov
  }
  // ABS hrana: okamzity zapis JEDNEJ hrany; kompletnu mapu sklada Ruby (read-modify-write).
  function onBoardEdgeChange(code, value){
    if (!boardCard) return;
    if (window.sketchup && sketchup.set_board_edge)
      sketchup.set_board_edge(nxDocPayload({ board_id: boardCard.board_id, edge: code, abs_id: value }));
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
      var tgt = boardTarget(); // R-02: doska + dokument z casu OTVORENIA modalu
      openAbsModal('Dekor „' + decor + '" nemá použiteľnú ' + absMissingLabel(catalogSchemaNow()) + ' — bez nej sa hrany nedajú olepiť.',
        function(create){ sendBoardEdgesAll(create, tgt); }, null);
      return;
    }
    sendBoardEdgesAll(false);
  }
  function sendBoardEdgesAll(createAbs, forBoard){
    if (!boardCard) return;
    var tgt = forBoard || boardTarget();
    if (boardTargetStale(tgt)){
      NX.setStatus('Karta sa medzitým zmenila — hrany sa neolepili.', true);
      return;
    }
    flushBoardEditsNow();
    if (window.sketchup && sketchup.set_board_edges_all)
      sketchup.set_board_edges_all(nxDocPayload({ board_id: tgt.id, create_missing_abs: !!createAbs,
        catalog_schema: (typeof PANEL_CLIENT_SCHEMA !== 'undefined' ? PANEL_CLIENT_SCHEMA : 1) }, tgt.guid));
  }

  // ===== UI-C1c: ORIENTACIA DOSKY (segmentove tlacidla) =====================
  // Spolocne prekreslenie trojice segmentov (vkladanie aj karta oznacenej dosky).
  // A11y (Codex audit C1c FIX 9): stav nesie `aria-pressed`, popis `aria-label`
  // + `title` su v HTML (kostra je staticka — JS nikdy nepise innerHTML segmentov).
  // Neznama hodnota (config z novsej verzie) NEROZSVIETI ziadny segment — karta
  // radsej neklame, nez by podsunula „naležato".
  function syncOrientationSegments(rowId, attr, cur){
    var row = el(rowId); if (!row) return;
    var btns = row.querySelectorAll('button[' + attr + ']');
    for (var i = 0; i < btns.length; i++){
      var on = btns[i].getAttribute(attr) === cur;
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }
  function syncInsertOrientation(){
    syncOrientationSegments('insBoardOriRow', 'data-ins-ori',
      (typeof NXInsert !== 'undefined') ? NXInsert.boardOrientation() : 'leziaca');
  }
  // Klik v REZIME VKLADANIA — mení len draft karty (ziadny zapis do modelu).
  function onInsertOrientation(o){
    if (typeof NXInsert === 'undefined') return;
    if (!NXInsert.setBoardOrientation(o)) return; // klik na uz zvolenu = no-op
    syncInsertOrientation();
  }
  // Klik na karte UZ VLOZENEJ dosky = 1 rebuild = 1 krok Spat (server robi
  // deltu transformacie). Codex audit C1c FIX 9: PRED odoslanim sa flushne
  // cakajuci debounce ostatnych poli — callbacky sa vykonavaju v poradi
  // odoslania a rozmer zapisany AZ PO otoceni by pracoval nad starym configom.
  function onBoardOrientation(o){
    if (!boardCard) return;
    if (boardCard.orientation === o) return; // klik na uz zvolenu = no-op
    flushBoardEditsNow();
    if (window.sketchup && sketchup.set_board_orientation)
      sketchup.set_board_orientation(nxDocPayload({ board_id: boardCard.board_id, orientation: o }));
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
    // D-89a: prekreslenie karty zahodi uzly pod kurzorom — zvyraznenie v modeli
    // by ostalo visiet (`mouseout` na zmazanom uzle uz nepride).
    if (typeof nxHoverEdgeClear === 'function') nxHoverEdgeClear();
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
    // UI-C1c: umiestnenie dosky — server posiela ulozenu hodnotu (chybajuca =
    // 'leziaca'), takze karta nikdy nehada.
    syncOrientationSegments('boardOriRow', 'data-bc-ori', bc.orientation || 'leziaca');
    if (el('bc_diag')) el('bc_diag').textContent = 'Výrobná trieda: sheet · ide do výroby';
    var ms = el('bc_material');
    if (ms){ fillBoardMaterialSelect(ms, bc.material_id || '', true); }
    renderBoardEdgeRows(bc);
    renderBoardSvg(bc);
    // ŠT-2d: TA ISTA cesta ako pri dielci (`nxDecorLinkState` zije v part_card.js
    // — jedna funkcia, dva vstupne body). Doska ma vzdy konkretny material,
    // takze tlacidlo je prakticky vzdy zive.
    if (typeof nxDecorLinkApply === 'function'){
      nxDecorLinkApply(el('bcMatLink'), nxDecorLinkState(bc.material_id));
    }
    nxComboSync(box); // D-85: materialovy combobox + 4 comboboxy hran dosky
    // GHOST-D1: AZ NAKONIEC — read-only prebije vsetko, co karta vyssie
    // odomkla (hrubka UNI dosky, comboboxy hran, odkaz na dekor).
    applyBoardReadOnly(bc);
  }

  // GHOST-D1 (STANDARD 8.3 bod 3): doska z NOVSEJ verzie pluginu sa ZOBRAZUJE,
  // ale NEUPRAVUJE. O stave rozhoduje VYHRADNE server (`newer_config`) — karta
  // si ho z niceho neodvodzuje. Zapisove cesty su chranene nezavisle
  // (`guarded_board`), takze toto je UX vrstva: pouzivatel ma vidiet PRECO
  // nemoze nic menit, nie naraziť na hlasku pri kazdom kliknuti.
  // `disabled` (nie len `readOnly`) — pri selectoch a tlacidlach je to jediny
  // sposob, ako ovladac naozaj umlcat.
  function applyBoardReadOnly(bc){
    var box = el('boardCard'); if (!box) return false;
    var lock = !!(bc && bc.newer_config);
    var note = el('bcNewer');
    if (note){
      note.hidden = !lock;
      note.textContent = lock ? String(bc.newer_config_note || '') : '';
    }
    var nodes = box.querySelectorAll('input, select, textarea, button');
    for (var i = 0; i < nodes.length; i++){
      var n = nodes[i];
      if (n === note) continue;
      n.disabled = lock;
      if (lock) n.setAttribute('aria-disabled', 'true');
      else n.removeAttribute('aria-disabled');
    }
    // Hrubka UNI dosky ostava `readOnly` aj bez zamku — jej pravidlo riadi
    // `renderBoardCard` vyssie a zamok ho nesmie prepisat spat na editovatelne.
    box.classList.toggle('locked', lock);
    return lock;
  }

  function openBoardDecor(){
    if (typeof nxDecorLinkGo !== 'function') return;
    nxDecorLinkGo(nxDecorLinkState(boardCard ? boardCard.material_id : ''));
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
      // D-89a: cely riadok je hover-cielom — hrana sa rozsvieti v modeli.
      row.setAttribute('data-edge', code);
      row.title = 'Kurzor nad hranou ju zvýrazní priamo v modeli.';
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
      sel.setAttribute('data-nx-combo', 'abs'); // D-85: hrany su ABS combobox
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
      // D-85: nativny select je skryty — klik na hranu rovno otvori combobox.
      if (sel){
        if (typeof nxRevealTarget === 'function') nxRevealTarget(sel); // UI-B1: rozbal sektor
        if (!(typeof NXCombo !== 'undefined' && NXCombo && NXCombo.open(sel))) sel.focus();
        NX.setStatus('Hrana ' + code + ' — vyber ABS v zozname.', false);
      }
    });
  }

  // ===================== VKLADACIA CAST (prepinac Korpus/Doska) =====================
  // Codex #142 P2: material, pre ktory je v poli Hrubka dosadena katalogova
  // hodnota — rozlisi ZMENU VYBERU od obycajneho refreshu katalogu (draft UNI
  // hrubky refresh neprezije, ked sa porovnava len fokus).
  var insertMatLast = null;
  // Codex #163 P2: marker je VLASTNY pre kazde pole — guardy sa potlacaju NEZAVISLE
  // (fokus je v jednom z poli), spolocny marker by rozhodnutie jedneho pola miesal
  // do druheho (drzanie kvoli fokusu v smere by pri UNI zmazalo draft hrubky).
  var insertGrainMatLast = null;
  var insertGrainTouched = false; // D-86: siahol pouzivatel na smer dekoru pri tomto materiali?
  // UI-C1b: druh vkladaneho objektu uz nedrzia radia (nahradili ich segmentove
  // tlacidla) — autorita je cisty stav NXInsert, DOM je jeho zrkadlo.
  function getInsertKind(){
    return (typeof NXInsert !== 'undefined' && NXInsert.state.kind === 'board') ? 'board' : 'cabinet';
  }
  function onInsertKindChange(){
    var kind = getInsertKind();
    document.body.setAttribute('data-insert-kind', kind); // atribut PREZIJE setUiMode className prepis
    if (kind === 'board'){
      var ms = el('ib_material');
      if (ms && !ms.options.length){ fillBoardMaterialSelect(ms, ''); nxComboSync(); onInsertBoardMaterial(); }
    }
    // Codex #173 P2: prepnutie Korpus/Doska meni, KTORE polia sektory ukazuju
    // (rozmery korpusu vs. dlzka/sirka dosky, material dosky) — meta v listach
    // musi ist s nimi. Atribut sa meni programovo, ziadna udalost sa nevystreli.
    if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
  }
  // D-05: po zmene katalogu (NX.setMaterials) sa vkladaci select NEplni "iba raz" —
  // force refill so zachovanim platneho vyberu + prepocet hrubky/grainu. Fokusovany
  // select sa nechava tak (nerozbit rozkliknuty dropdown).
  // D-85: "rozkliknuty" uz neznamena len fokus nativneho selectu — od UI-03 je nad
  // nim combobox, takze sa pyta nxFieldBusy (fokus ALEBO otvoreny popup). Bez toho
  // by zivy refresh katalogu prekreslil ponuku pod rukami pisuceho pouzivatela.
  function refreshInsertBoardMaterials(){
    var ms = el('ib_material');
    if (!ms || !ms.options.length) return; // este nenaplneny — naplni onInsertKindChange
    if (nxFieldBusy(ms)) return;
    var keep = ms.value;
    fillBoardMaterialSelect(ms, keep);
    if (ms.value !== keep || !ms.value){ ms.selectedIndex = ms.selectedIndex < 0 ? 0 : ms.selectedIndex; }
    nxComboSync();
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
  // Codex #163 P2: ma sa material zapamatat ako ten, s ktorym je pole ZOSYNCHRONIZOVANE?
  // NIE, ked zapis potlacil VYHRADNE fokus a material sa pritom naozaj zmenil (refresh
  // katalogu vymenil vyber, napr. po zmazani materialu, kym pouzivatel v poli stal).
  // Marker sa vtedy drzi na starom ID, takze zmena ostane "viditelna" a najblizsi beh
  // (blur pola alebo dalsi refresh) predvolbu dokona — inak by dalsie refreshe tvarili
  // stav ako "bez zmeny" a do vlozenej dosky by isla zatuchnuta hodnota zmazaneho
  // materialu. Kym sa material nezmenil, drzanie je aj tak bez ucinku (marker == ID).
  function insertMatMarkAdvances(prevMaterialId, materialId, focused){
    return !(focused && materialId !== prevMaterialId);
  }
  // Jeden krok synchronizacie SMERU DEKORU s katalogom — cisty automat bez DOM
  // (produkcna cesta aj testy pouzivaju TENTO kod, nie svoju kopiu pravidiel).
  // state: { mark, touched, value } -> novy state + priznak wrote.
  function insertGrainSync(state, materialId, sheet, focused){
    var st = state || {};
    var write = insertGrainShouldWrite(st.mark === undefined ? null : st.mark,
                                       materialId, sheet, !!st.touched, !!focused);
    return {
      mark: insertMatMarkAdvances(st.mark === undefined ? null : st.mark, materialId, focused)
              ? materialId : st.mark,
      touched: write ? false : !!st.touched,
      value: write ? sheet.grain : st.value,
      wrote: write
    };
  }
  // Poskladaj payload vkladanej dosky z HODNOT formulara (ziadny DOM, ziadne globaly).
  // vals: surove stringy {name,length,width,material_id,grain_direction,thickness}
  // sheet: katalogovy zaznam vybraneho materialu (alebo null)
  // -> { ok:true, payload:{...} } | { ok:false, error:'hlaska pre status' }
  // UI-C1c: `orientation` je v payloade VZDY (nikdy sa nevynecha) — server
  // whitelist ju prepusti do BoardBuilder.norm_orientation, ktora je jedina
  // autorita slovnika. Prazdna/neznama hodnota z formulara sa tu NEOPRAVUJE:
  // slovnik drzi NXInsert (setBoardOrientation) a chybu ma ohlasit server.
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
      grain_direction: String(vals.grain_direction === null || vals.grain_direction === undefined ? '' : vals.grain_direction),
      orientation: String(vals.orientation === null || vals.orientation === undefined ? '' : vals.orientation)
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
  // UI-C1b: smer dekoru je jediny udaj, ktory pri vkladani dosky vidno v nahlade
  // (N10 sipky) — vedoma volba ho musi prekreslit hned.
  function onInsertGrainChange(){
    insertGrainTouched = true;
    if (typeof renderPreview === 'function') renderPreview();
  }
  // Zmena materialu vo vkladacej karte: dosad hrubku + default smer dekoru z katalogu.
  function onInsertBoardMaterial(){
    var ms = el('ib_material'); if (!ms) return;
    var sheet = findSheetIn(MATERIALS.sheets, ms.value);
    var th = el('ib_thickness');
    var thFocused = false;
    if (th){
      var uni = sheetIsUni(sheet);
      th.readOnly = !uni; // UNI = odomknute (readonly styling riesi CSS)
      th.title = uni ? 'UNI: hrúbku určuje doska' : 'Hrúbku určuje materiál';
      thFocused = document.activeElement === th;
      if (insertThicknessShouldWrite(insertMatLast, ms.value, sheet, thFocused)){
        th.value = sheet ? fmtmm(sheet.thickness) : '';
        // Zivy nahlad vyrazu ("= 12") visi na input evente — po programovom
        // prepise ho zosynchronizuj, inak po zmene materialu ostane stary.
        // Nebubla: jediny poslucac je expr handler pripojeny na tomto poli.
        th.dispatchEvent(new Event('input'));
      }
    }
    // Codex #163 P2: marker sa posunie, LEN ked zapis nepotlacil samotny fokus
    // (inak by sa zmena materialu stratila — plati pre hrubku aj pre smer).
    if (insertMatMarkAdvances(insertMatLast, ms.value, thFocused)) insertMatLast = ms.value;
    // D-86: predvolba smeru sa dosadi len ked na to ma pravo (viz insertGrainSync).
    // Po dosadeni je v poli katalogova hodnota, nie volba pouzivatela — priznak padne.
    var gs = el('ib_grain');
    if (gs){
      var st = insertGrainSync({ mark: insertGrainMatLast, touched: insertGrainTouched,
                                 value: gs.value },
                               ms.value, sheet, document.activeElement === gs);
      if (st.wrote) gs.value = st.value;
      insertGrainMatLast = st.mark;
      insertGrainTouched = st.touched;
    } else {
      insertGrainMatLast = ms.value;
    }
    // UI-C1b: informacny stlpec Zakladnych je zrkadlom tychto poli.
    if (typeof refreshInsertBoardInfo === 'function') refreshInsertBoardInfo();
    // N10: smer dekoru kresli aj nahlad vkladanej dosky.
    if (typeof renderPreview === 'function' && typeof previewMode !== 'undefined' && previewMode === 'insert') renderPreview();
  }
  function insertBoard(){
    var ms = el('ib_material');
    var res = buildInsertBoardPayload({
      name: el('ib_name') ? el('ib_name').value : '',
      length: el('ib_length') ? el('ib_length').value : '',
      width: el('ib_width') ? el('ib_width').value : '',
      material_id: ms ? ms.value : '',
      grain_direction: el('ib_grain') ? el('ib_grain').value : '',
      thickness: el('ib_thickness') ? el('ib_thickness').value : '',
      // UI-C1c: orientacia NEZIJE v DOM poli — autorita je cisty stav NXInsert
      // (segmenty su len jeho zrkadlo, rovnako ako typ vkladania).
      orientation: (typeof NXInsert !== 'undefined') ? NXInsert.boardOrientation() : 'leziaca'
    }, findSheetIn(MATERIALS.sheets, ms ? ms.value : ''));
    if (!res.ok){ NX.setStatus(res.error, true); return; }
    // UI-C1a: identita pouzitej sablony (kind + nazov) — server ju z payloadu
    // odstrani PRED builderom a po uspesnom vlozeni ju opeciatkuje ako
    // „naposledy pouzite" (poradie dlazdic sa prekresli bez restartu).
    var ref = (typeof NXInsert !== 'undefined') ? NXInsert.templateRef() : null;
    if (ref && ref.kind === 'board'){
      res.payload.template_kind = ref.kind;
      res.payload.template_name = ref.name;
    }
    if (window.sketchup && sketchup.insert_board) sketchup.insert_board(nxDocPayload(res.payload)); // R-02
  }

  // GHOST-D2: „Nakresliť" — doska sa nakreslí DVOMA ŤAHMI (klik = počiatok,
  // ťah dĺžky, ťah šírky). Payload je ten istý ako pri vložení, navyše nesie
  // ČÍSELNÝ SNAPSHOT ZÁMKOV karty ako SAMOSTATNÉ pole:
  //   `NXInsert.boardLocks` je súkromný JS stav („NIKDY do Ruby"), preto ide
  //   cez `locksFlat('board')` = HODNOTY zamknutých polí ({length: 800});
  //   nezamknutý kľúč v mape CHÝBA. Žiadny prevod na Boolean — zámok z toho,
  //   že pole má hodnotu, NEEXISTUJE (polia sú vždy predvyplnené 800 × 600).
  // Server hodnoty znova overí (whitelist + limity) a zámky nikdy nezapíše
  // do výrobného configu.
  function buildDrawBoardPayload(payload, locks){
    var out = payload || {};
    var flat = locks || {};
    var keep = {};
    ['length', 'width'].forEach(function(k){
      var v = flat[k];
      if (typeof v === 'number' && isFinite(v)) keep[k] = v;
    });
    out.locks = keep;
    return out;
  }
  function drawBoard(){
    var ms = el('ib_material');
    var res = buildInsertBoardPayload({
      name: el('ib_name') ? el('ib_name').value : '',
      length: el('ib_length') ? el('ib_length').value : '',
      width: el('ib_width') ? el('ib_width').value : '',
      material_id: ms ? ms.value : '',
      grain_direction: el('ib_grain') ? el('ib_grain').value : '',
      thickness: el('ib_thickness') ? el('ib_thickness').value : '',
      orientation: (typeof NXInsert !== 'undefined') ? NXInsert.boardOrientation() : 'leziaca'
    }, findSheetIn(MATERIALS.sheets, ms ? ms.value : ''));
    if (!res.ok){ NX.setStatus(res.error, true); return; }
    var ref = (typeof NXInsert !== 'undefined') ? NXInsert.templateRef() : null;
    if (ref && ref.kind === 'board'){
      res.payload.template_kind = ref.kind;
      res.payload.template_name = ref.name;
    }
    var locks = (typeof NXInsert !== 'undefined') ? NXInsert.locksFlat('board') : {};
    var payload = buildDrawBoardPayload(res.payload, locks);
    if (window.sketchup && sketchup.draw_board) sketchup.draw_board(nxDocPayload(payload)); // R-02
  }

  // ===== UI-C1b: DOSKOVA SABLONA VO VKLADACEJ KARTE =========================
  // KONTRAKT HRUBKY (Codex #174 P2, zapisany v core/templates.rb board_tpl):
  // doskova sablona ma `material_id` EXPLICITNE nil => vklada sa cez UNI
  // mechanizmus (E-03 odomknuta hrubka), aby deklarovana hrubka sablony VZDY
  // platila. `BoardBuilder.insert_thickness_for` je a ostava JEDINOU autoritou:
  // hrubku z payloadu prijme LEN pri UNI materiali, pri realnom ju urcuje
  // katalog. Tu sa preto NEZAVADZA ziadna nova autorita — karta len predvyplni
  // UNI material a do (vtedy odomknuteho) pola dosadi hrubku sablony.
  // Ciste funkcie (Node testy): vyber materialu je oddeleny od DOM.
  function uniBoardSheetId(sheets){
    var any = null;
    for (var i = 0; i < (sheets || []).length; i++){
      var s = sheets[i];
      if (!s || s.uni !== true) continue;
      if (s.uni_role === 'board') return s.id; // UNI rola „Doska" ma prednost
      if (any === null) any = s.id;
    }
    return any;
  }
  // Ktory katalogovy material dosadit pre doskovu sablonu: ked ho sablona
  // vyslovne nesie (a este existuje), pouzije sa on; inak UNI (kontrakt vyssie).
  // null = katalog nema co dosadit — karta si necha svoj vyber.
  function boardTemplateMaterialId(sheets, wanted){
    var id = (wanted === undefined || wanted === null) ? '' : String(wanted);
    if (id && findSheetIn(sheets, id)) return id;
    return uniBoardSheetId(sheets);
  }
  // Aplikacia doskovej sablony na kartu. PORADIE JE KONTRAKT:
  //   1) material (onInsertBoardMaterial odomkne hrubku a dosadi katalogovy
  //      default UNI materialu — inak by prepisal nas draft),
  //   2) AZ POTOM hrubka sablony (dalsie refreshe ju uz drzia — E-03: ten isty
  //      UNI material sa neprepisuje),
  //   3) rozmery (zamky dosky prebiju sablonu — D-39),
  //   4) smer dekoru = VEDOMA volba (D-86 priznak, refresh katalogu ju nezmeni).
  function applyBoardTemplate(cfg){
    cfg = cfg || {};
    var ms = el('ib_material');
    if (ms){
      if (!ms.options.length) fillBoardMaterialSelect(ms, '');
      var want = boardTemplateMaterialId(MATERIALS.sheets, cfg.material_id);
      if (want && ms.value !== want){ ms.value = want; nxComboSync(); }
      onInsertBoardMaterial();
    }
    var th = el('ib_thickness');
    if (th && cfg.thickness !== undefined && cfg.thickness !== null){
      if (th.readOnly){
        // Realny material hrubku diktuje (D-45) — sablonovu by server aj tak
        // zahodil, preto sa nepredstiera, ze plati.
        NX.setStatus('Hrúbku ' + mmLabel(cfg.thickness) + ' mm zo šablóny drží len UNI materiál — ' +
                     'pri tomto materiáli platí katalógová hrúbka.');
      } else {
        // fmtdim (nie fmtmm): pole je pri UNI EDITOVATELNE, takze nesmie
        // vizualne stratit desatiny (10,5 mm sablona nie je 10 mm).
        th.value = fmtdim(cfg.thickness);
        // Zivy nahlad vyrazu visi na `input` — po programovom prepise ho zosynchronizuj.
        th.dispatchEvent(new Event('input'));
      }
    }
    if (cfg.length !== undefined && cfg.length !== null && !NXInsert.isLocked('length', 'board'))
      setNum('ib_length', cfg.length);
    if (cfg.width !== undefined && cfg.width !== null && !NXInsert.isLocked('width', 'board'))
      setNum('ib_width', cfg.width);
    var gs = el('ib_grain');
    if (gs && cfg.grain_direction){
      gs.value = cfg.grain_direction;
      insertGrainTouched = true; // D-86: volba zo sablony je vedoma, refresh ju nesmie prepisat
    }
  }
  // Informacny stlpec vkladanej dosky (VYSTUPY su text, nie polia): hrubka je
  // zrkadlom pola v sekcii Materialy (jedina autorita ostava tam), plocha je
  // dlzka x sirka. Ciste jadro je nxBoardArea (Node testy).
  function nxBoardArea(length, width){
    var l = parseFloat(length), w = parseFloat(width);
    if (isNaN(l) || isNaN(w) || l <= 0 || w <= 0) return null;
    return Math.round(l * w / 1000) / 1000; // mm2 -> m2 (3 des. miesta)
  }
  function refreshInsertBoardInfo(){
    var th = el('ib_thickness');
    // Rozpisany vyraz („18-2") sa este necita ako cislo — radsej pomlcka nez
    // prazdne „ mm" (vzor setOut: udaj, ktory nevieme, sa nevymysla).
    var tv = (th && th.value !== '') ? evalDim(th.value) : NaN;
    setOut('inf_b_th', isNaN(tv) ? '—' : (mmLabel(tv) + ' mm'));
    var a = nxBoardArea(numv('ib_length'), numv('ib_width'));
    setOut('inf_b_area', a === null ? '—' : (mmLabel(a) + ' m²'));
  }

  // Node testy (tests/js/test_e03_board_insert.js) — v CEF je module undefined,
  // vetva sa preskoci. Exportuju sa LEN ciste funkcie (bez DOM/MATERIALS).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { buildInsertBoardPayload: buildInsertBoardPayload,
                       sheetIsUni: sheetIsUni, findSheetIn: findSheetIn,
                       insertThicknessShouldWrite: insertThicknessShouldWrite,
                       insertGrainShouldWrite: insertGrainShouldWrite,
                       insertMatMarkAdvances: insertMatMarkAdvances,
                       insertGrainSync: insertGrainSync,
                       // UI-C1b: doskova sablona vo vkladacej karte
                       uniBoardSheetId: uniBoardSheetId,
                       boardTemplateMaterialId: boardTemplateMaterialId,
                       nxBoardArea: nxBoardArea,
                       // GHOST-D1: read-only karta pri doske z novsej verzie
                       // (sada tests/js/test_ghost_d1_karta.js nad mini-DOM).
                       applyBoardReadOnly: applyBoardReadOnly,
                       // GHOST-D2: ciselny snapshot zamkov do payloadu `draw_board`
                       // (sada tests/js/test_ghost_d2_karta.js).
                       buildDrawBoardPayload: buildDrawBoardPayload };
  }
