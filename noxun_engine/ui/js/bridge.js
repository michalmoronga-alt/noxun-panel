  // ===================== Ruby -> JS =====================
  // V0.4.5 D1: rezimy Inspectora — body class riadi viditelnost kontextovych kariet
  // (CSS: mode-insert zobrazi vkladaciu kartu; mode-cab nastavenia korpusu; mode-part
  // kartu dielca a skryje korpusove sekcie). Identita hore = setIdbar.
  var lastCabForFit = null;
  function setUiMode(mode){
    document.body.className = 'mode-' + mode;
    // D-14 (Codex F5): modal patri k oznacenemu korpusu — mimo mode-cab sa zatvara
    if (mode !== 'cab' && typeof closeSaveTemplateModal === 'function') closeSaveTemplateModal();
    // D-32 (audit B2): SKUTOCNY prechod cab|part|board -> insert = reset karty
    // z insert stavu (typ + sablona + zamky); insert -> insert sync NEresetuje,
    // rozpisane upravy v karte preziju. Jedine miesto zmeny rezimu = jedine
    // miesto resetu — plati pre kazdu buducu cestu do mode-insert.
    if (NXInsert.trackMode(mode)) materializeInsertCard();
    // D-78: rezimove taby su v mode-insert neaktivne — aria stav drzime pri KAZDEJ
    // zmene rezimu (className vyssie zmazal aj pripadne stare priznaky).
    if (typeof syncCabTabsLocked === 'function') syncCabTabsLocked();
  }
  // D-100: inline premenovanie skrinky. Editor zije v hlavicke (ziadny novy
  // riadok) a jeho stav je viazany na cabinet_id — Codex audit FIX 4: debounced
  // auto-apply posle echo, ktore prekresli idbar, a rozpisany nazov by bez tohto
  // guardu ticho zmizol. Rovnake ID = editor sa NEPREPISE; ine ID = zrusi sa.
  var renameFor = null;      // cabinet_id s otvorenym editorom (null = zavrety)
  var renameSending = false; // Escape/odoslanie uz zavrelo editor — blur nesmie strielat druhykrat
  var lastCabName = '';      // posledny nazov z Ruby (fallback pri zruseni editora)

  // Zrusi rozpisany editor BEZ odoslania (zmena vyberu, doska, prazdny vyber).
  function dropCabRename(){
    if (!renameFor) return;
    renameFor = null;
    renameSending = true;
  }

  function cabNameCellHtml(c){
    var nm = c.name || '';
    // A10 vzor: ovladac je skutocne <button> (fokusovatelne, Enter/Space) — nie
    // klikatelny span. Ceruzka je zo spritu, ziadne emoji (UI_DIZAJN).
    return '<button type="button" id="cnameBtn" class="cname" onclick="startCabRename()"' +
      ' title="Premenovať skrinku" aria-label="Premenovať skrinku — ' + esc(nm) + '">' +
      '<span class="cnametext">' + esc(nm) + '</span>' + NXIcons.svg('pencil') + '</button>';
  }

  function startCabRename(){
    var btn = el('cnameBtn'); if (!btn || !selectedCabId) return;
    var cur = btn.querySelector('.cnametext');
    var txt = cur ? cur.textContent : '';
    renameFor = selectedCabId;
    renameSending = false;
    var inp = document.createElement('input');
    inp.type = 'text'; inp.id = 'cnameInput'; inp.className = 'cnameinput';
    inp.value = txt; inp.maxLength = CAB_NAME_MAX;
    inp.title = 'Enter uloží, Escape zruší, prázdne pole vráti automatický názov';
    inp.setAttribute('aria-label', 'Názov skrinky');
    inp.onkeydown = function(ev){
      if (ev.key === 'Enter'){ ev.preventDefault(); commitCabRename(); }
      else if (ev.key === 'Escape'){ ev.preventDefault(); cancelCabRename(); }
    };
    inp.onblur = function(){ commitCabRename(); };
    btn.parentNode.replaceChild(inp, btn);
    inp.focus(); inp.select();
  }

  function commitCabRename(){
    var inp = el('cnameInput');
    if (!inp || renameSending) return;
    renameSending = true; // blur po Enter/odstraneni prvku nesmie poslat druhy callback
    var cid = renameFor;
    renameFor = null;
    var name = cabNameValue(inp.value);
    // Editor sa zatvara HNED (ziadny stuck input, ked server zapis zahodi);
    // spravny nazov dokresli push_selected — autorita je vzdy server.
    closeCabRenameEditor();
    // Identity guard aj na klientovi (server ma svoj vlastny, prisnejsi):
    // ak sa vyber medzitym presunul, zapis sa neposiela vobec.
    if (cid && cid === selectedCabId && window.sketchup && sketchup.rename_cabinet){
      sketchup.rename_cabinet(JSON.stringify({ cabinet_id: cid, name: name }));
    }
  }

  function cancelCabRename(){
    if (!el('cnameInput')) return;
    dropCabRename(); // NOTE 7: Escape uz cez nasledny blur NIC neodosle
    closeCabRenameEditor();
  }

  // Vrati bunku nazvu do textovej podoby BEZ zasahu do modelu (Escape, zmena vyberu).
  function closeCabRenameEditor(){
    var inp = el('cnameInput'); if (!inp) return;
    var span = document.createElement('span');
    span.innerHTML = cabNameCellHtml({ name: lastCabName });
    inp.parentNode.replaceChild(span.firstChild, inp);
  }

  // D3: klik na ⚠ chip rozbali/zbali zoznam upozorneni stavby pod identitou.
  function setIdbar(c){
    var bar = el('idbar'), list = el('warnList');
    if (!bar) return;
    if (!c){
      dropCabRename(); // vyber zmizol — rozpisany nazov konci bez zapisu
      bar.innerHTML = '<span class="free">Nič nie je označené — návrh nového objektu</span>';
      if (list){ list.style.display = 'none'; list.innerHTML = ''; }
      return;
    }
    lastCabName = c.name || '';
    var warns = c.warnings || [];
    // A10: warn chip = skutocne <button> (fokusovatelne, klavesova aktivacia).
    // Ikona zo spritu (staticky markup); pocet je cislo — bezpecne (B9).
    var wHtml = warns.length
      ? ' <button type="button" class="warnchip" onclick="toggleWarnList()" title="Zobraziť upozornenia stavby" aria-label="Zobraziť upozornenia stavby">' + NXIcons.svg('alert') + ' ' + warns.length + '</button>'
      : '';
    // FIX 4: echo TEJ ISTEJ skrinky nesmie zhltnut rozpisany nazov — prekresli
    // sa vsetko okrem bunky nazvu, ktora ostane v editacnom rezime.
    var keepEditor = renameFor && renameFor === (c.cabinet_id || '') && el('cnameInput');
    if (keepEditor){
      var idEl = bar.querySelector('.cid');
      if (idEl) idEl.textContent = c.cabinet_id || '?';
      var oldChip = bar.querySelector('.warnchip');
      if (oldChip) oldChip.parentNode.removeChild(oldChip);
      if (wHtml) bar.insertAdjacentHTML('beforeend', wHtml);
    } else {
      dropCabRename(); // ina skrinka = editor konci bez zapisu
      bar.innerHTML = '<span class="cid">' + esc(c.cabinet_id || '?') + '</span>' +
        cabNameCellHtml(c) + wHtml;
    }
    if (list){
      if (warns.length){
        var html = '';
        warns.forEach(function(w){ html += '<div class="warnrow">' + esc(w.message || '') + '</div>'; });
        list.innerHTML = html; // viditelnost necha na pouzivatelovi (toggle drzi stav)
        if (!warns.length) list.style.display = 'none';
      } else {
        list.style.display = 'none'; list.innerHTML = '';
      }
    }
  }
  function toggleWarnList(){
    var list = el('warnList'); if (!list || !list.innerHTML) return;
    var willOpen = (list.style.display === 'none' || !list.style.display);
    list.style.display = willOpen ? 'block' : 'none';
    // A1: warnlist je ukotveny hned pod sticky hlavickou — pri rozbaleni sa vratime
    // hore, aby bol viditelny aj po odscrollovani (klik na sticky ⚠ chip nesmie
    // rozbalit zoznam mimo viewportu).
    if (willOpen){ try { window.scrollTo(0, 0); } catch (e) {} }
  }

  window.NX = {
    init: function(data){
      DEFAULTS = data.defaults || { lower: {}, upper: {} };
      TEMPLATES = data.templates || [];
      MATERIALS = data.materials || { sheets: [], edges: [] };
      FRONT_PROFILES = data.front_profiles || []; // D-90: registry profilov z Ruby
      // D-39 (audit B5): zamky z Ruby pamate Panel modulu — PRED vetvami nizsie,
      // aby ich prvy reset karty (clearSelected -> materializeInsertCard) aplikoval.
      NXInsert.setLocksFlat(data.insert_locks);
      if (data.version) el('verline').textContent = 'V' + data.version; // verzia z Ruby (jediny zdroj)
      refreshMaterialFilters(); // (projektove predvolby zobrazi okno Materialy projektu)
      el('zonesChk').checked = !!data.zones_visible;
      // V0.4.7c: uz oznacena DOSKA pri otvoreni panela (selected_kind z Ruby)
      if (data.selected_kind === 'board' && data.selected){ setType('lower'); setDefaults('lower'); currentZoneTree = defaultTree(); renderFilteredTemplates(); NX.loadBoard(data.selected); }
      else if (data.selected){ NX.loadSelected(data.selected); }
      else { setType('lower'); setDefaults('lower'); currentZoneTree = defaultTree(); renderFilteredTemplates(); NX.clearSelected(); onField(); }
    },
    setTemplates: function(list){ TEMPLATES = list || []; renderFilteredTemplates(); refreshTplModalWarn(); }, // D-14: varovanie kolizie zije aj pri otvorenom modale
    // V0.5 B (Codex B1): okno Vyroba pyta select cez panel — najprv flush
    // rozpisanych editov (400 ms debounce) KORPUSU AJ DOSKY (Codex GH #48 P2:
    // zmena selection by boardPending zrusila), az potom sa meni selection.
    productionRelay: function(p){
      if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
      if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
      if (window.sketchup && sketchup.production_do_select) sketchup.production_do_select(JSON.stringify(p));
    },
    // V0.5 C: export VEPO cez panel — flush ako pri selecte, ALE pri neplatnych
    // poliach sa export zastavi (flushCabinetEdits by edity ticho neaplikoval
    // a exportoval by sa stary model = zla objednavka).
    productionRelayExport: function(p){
      var blocked = false;
      try {
        if (typeof validateFields === 'function' && typeof selectedCabId !== 'undefined' &&
            selectedCabId && !validateFields()) blocked = true;
        // GH P1: board karta neplatne hodnoty NEqueue-uje (pole .bad) — flush by
        // ich ticho obisiel a export by sol zo starych rozmerov. Cervene board
        // pole = export stoji rovnako ako pri korpuse.
        var badBoard = document.querySelector('#boardCard input.bad, #boardCard .bad');
        if (badBoard) blocked = true;
      } catch (e) { blocked = false; }
      if (!blocked){
        if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
        if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
      }
      p.flush_blocked = blocked;
      if (window.sketchup && sketchup.production_do_export) sketchup.production_do_export(JSON.stringify(p));
    },
    // V0.6 D1b (GH #127 P1): CSV kovania — rovnaky flush handshake ako VEPO
    // (neplatne pole = export stoji; inak flush editov PRED zberom modelu).
    productionRelayHwCsv: function(p){
      var blocked = false;
      try {
        if (typeof validateFields === 'function' && typeof selectedCabId !== 'undefined' &&
            selectedCabId && !validateFields()) blocked = true;
        var badBoard = document.querySelector('#boardCard input.bad, #boardCard .bad');
        if (badBoard) blocked = true;
      } catch (e) { blocked = false; }
      if (!blocked){
        if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
        if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
      }
      p.flush_blocked = blocked;
      if (window.sketchup && sketchup.production_do_hw_csv) sketchup.production_do_hw_csv(JSON.stringify(p));
    },
    // V0.6 E-b: XLSX rozpoctu — rovnaky flush handshake (rozpisany edit korpusu
    // meni kusovnik, teda aj platne, olep a montaz v rozpocte).
    productionRelayBudget: function(p){
      var blocked = false;
      try {
        if (typeof validateFields === 'function' && typeof selectedCabId !== 'undefined' &&
            selectedCabId && !validateFields()) blocked = true;
        var badBoard = document.querySelector('#boardCard input.bad, #boardCard .bad');
        if (badBoard) blocked = true;
      } catch (e) { blocked = false; }
      if (!blocked){
        if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
        if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
      }
      p.flush_blocked = blocked;
      if (window.sketchup && sketchup.production_do_budget) sketchup.production_do_budget(JSON.stringify(p));
    },
    // V0.6 E-b2: cenova ponuka pre zakaznika — CP je VIEW nad rozpoctom, takze
    // potrebuje presne ten isty flush handshake (inak by zakaznik dostal sumu
    // zo stareho modelu).
    productionRelayCp: function(p){
      var blocked = false;
      try {
        if (typeof validateFields === 'function' && typeof selectedCabId !== 'undefined' &&
            selectedCabId && !validateFields()) blocked = true;
        var badCp = document.querySelector('#boardCard input.bad, #boardCard .bad');
        if (badCp) blocked = true;
      } catch (e) { blocked = false; }
      if (!blocked){
        if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
        if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
      }
      p.flush_blocked = blocked;
      if (window.sketchup && sketchup.production_do_cp) sketchup.production_do_cp(JSON.stringify(p));
    },
    // D-05: zivy katalog materialov po CRUD v okne Materialy projektu. Obnovi
    // vsetky selecty s materialmi BEZ resetu formulara; zachovava vybrane hodnoty.
    // D-85 (Codex #167 P2): CERSTVE „Použité v projekte" pre otvoreny combobox.
    // Odpoved na nx_used_ids — meni LEN odvodeny zoznam id, ziadny render karty
    // (rozpisany formular sa nesmie dotknut). Otvoreny zoznam sa prekresli.
    setUsedIds: function(data){
      MATERIALS.used_ids = data || { sheets: [], edges: [] };
      if (typeof NXCombo !== 'undefined' && NXCombo) NXCombo.rerender();
    },
    setMaterials: function(data){
      MATERIALS = data || { sheets: [], edges: [] };
      refreshMaterialFilters();
      if (typeof refreshInsertBoardMaterials === 'function') refreshInsertBoardMaterials();
      if (typeof partCard !== 'undefined' && partCard) renderPartCard(partCard);
      if (typeof boardCard !== 'undefined' && boardCard) renderBoardCard(boardCard);
    },
    // D-75 (H1b): živý zoznam setov kovania po zmene v okne Katalóg kovania.
    // Obnoví LEN možnosti selectov setu (skrinka aj dielce) — riadky, rozpísané
    // počty ani výber sa nedotknú (vzor setMaterials, NIE push_selected).
    // D-92: tým istým kanálom chodí aj nákupný rozpis (set → kódy → názvy),
    // inak by po zmene setu/kódu/názvu ostal v paneli starý nákup.
    setHardwareSets: function(data){
      var d = data || {};
      // Identity guard: kým bežal callback, mohol sa zmeniť výber — vtedy panel
      // dostane vlastný loadSelected a tento (starý) payload sa zahodí.
      if ((d.cabinet_id || '') !== (selectedCabId || '')) return;
      if (typeof refreshHardwareSets === 'function') refreshHardwareSets(d.options || []);
      if (typeof refreshHardwarePurchase === 'function') refreshHardwarePurchase(d.items || []);
    },
    loadSelected: function(c){
      // V0.4.7c: odchod z kontextu dosky — zrus cakajuce board edity + kartu
      cancelBoardEdits();
      renderBoardCard(null);
      var t = c.type || 'lower';
      setType(t);
      writeConstruction(c);
      applyVisibility(t);
      buildFrontHwBadges(c.hardware || []); // D3: badge kovania PRED renderom riadkov ciel
      // D-23 (audit F5/4): frontItems PRED renderFronts — placeholder ≈ vysky
      // paruje s CERSTVYM payloadom (povodne poradie by parovalo so starou skrinkou).
      frontItems = c.front_items || [];
      // D-07 Codex B2: echo apply toho isteho korpusu s dalsimi cakajucimi editmi
      // nesmie prepisat gap polia (selectedCabId sa meni az nizsie v setSelected).
      // D-22: pod tym istym guardom je aj zamok presahov (edge_limit_off) —
      // starsie echo nesmie vratit novsi klik na zamok (renderFronts vo form.js).
      // D-23: a aj riadky ciel — pri keepGaps sa NEprestavaju (light-update).
      var keepGaps = (c.cabinet_id && c.cabinet_id === selectedCabId) && !!(applyTimer || cabEditsInFlight);
      cabEditsInFlight = false;
      renderFronts(c.fronts, keepGaps);
      currentZoneTree = c.zone_tree ? sanitizeTree(c.zone_tree) : defaultTree();
      tplNameSuggestion = c.template_name_suggestion || ''; // D-14 modal prefill
      // Codex GH #46 P2: preklik na INY korpus pri otvorenom modale = zavriet
      // (mode ostava cab, setUiMode guard nezabera; identitu navyse strazi server)
      if (typeof tplModalOpen === 'function' && tplModalOpen() &&
          tplModalCabId && c.cabinet_id !== tplModalCabId) closeSaveTemplateModal();
      // D-41 C2: novy vyber pocas otvoreneho ABS modalu = tiche zatvorenie bez
      // akcie (rozhodnutie by zasiahlo inu kartu; identitu navyse strazi server).
      if (typeof absModalCloseSilent === 'function') absModalCloseSilent();
      activeZoneId = c.active_zone || null;
      setSelected(c.cabinet_id || null);
      refreshMaterialFilters(); // FIX 2: prefiltruj podla hrubok tohto korpusu (pred nastavenim hodnot)
      setCabinetMaterials(c); // V0.3 korpusove material selecty (prazdne = dedi)
      renderFilteredTemplates();
      setIdbar(c);
      setUiMode(c.part_card ? 'part' : 'cab');
      // D-08 (Codex F3): dielec = vzdy ZONOVY nahlad (klik na zonu = vedomy odchod
      // z dielca, povodne spravanie); currentCabTab sa NEMENI — navrat do cab
      // obnovi pracovny tab. Atribut prezije setUiMode (className prepis).
      previewMode = c.part_card ? 'zones' : cabTabPreview(currentCabTab);
      // pohlad: ina skrinka -> fit; ta ista (auto-apply rebuild) -> pohlad DRZI
      if (c.cabinet_id !== lastCabForFit){ lastCabForFit = c.cabinet_id; fitPreview(); }
      // svetle rozmery presne z backendu ak su
      if (c.available_width!=null) setVal('av_width', Math.round(c.available_width));
      if (c.available_depth!=null) setVal('av_depth', Math.round(c.available_depth));
      if (c.available_height!=null) setVal('av_height', Math.round(c.available_height));
      renderPartCard(c.part_card || null); // V0.3 karta dielca (ak je vybraty dielec)
      renderHardware(c.hardware || [], c.hardware_overrides || [], c.hardware_set_options || [], c.cabinet_id || ''); // V0.4 kovanie + D1b sety
      renderPreview();
      refreshZoneUI();
    },
    // V0.4.7c: karta dosky. VYCISTI cely korpusovy stav (Codex audit c) — zonove
    // akcie a preview sa rozhoduju podla selectedCabId aj ked su skryte CSS.
    loadBoard: function(b){
      if (boardCard && b && boardCard.board_id !== b.board_id) cancelBoardEdits(); // ina doska
      if (applyTimer){ clearTimeout(applyTimer); applyTimer = null; } // korpusovy debounce nesmie strielat v kontexte dosky
      setSelected(null);
      activeZoneId = null; frontItems = null;
      invalidateFrontPlaceholders(); // D-23: bez resolved dat ziadne ≈ odhady
      buildFrontHwBadges([]);
      renderPartCard(null);
      renderHardware(null, []);
      clearCabinetMaterials();
      if (lastCabForFit !== null){ lastCabForFit = null; }
      renderBoardCard(b);
      setBoardIdbar(b);
      setUiMode('board');
      refreshZoneUI(); renderPreview();
    },
    clearSelected: function(){
      cancelBoardEdits();                    // V0.4.7c: koniec kontextu dosky
      renderBoardCard(null);
      if (applyTimer){ clearTimeout(applyTimer); applyTimer = null; }
      // D-32: identita prec PRED setUiMode — reset karty (materializeInsertCard
      // vnutri setUiMode) nesmie bezat nad zvyskami stareho vyberu.
      setSelected(null);
      activeZoneId = null; frontItems = null;
      buildFrontHwBadges([]); // Codex PR #30: badge patria oznacenej skrinke — bez nej ziadne
      setIdbar(null);
      setUiMode('insert');
      // D-78: vo vkladani su taby neaktivne a zobrazuje sa Korpus (effectiveCabTab);
      // zapamatany pracovny tab prezije a obnovi sa pri oznaceni korpusu.
      previewMode = cabTabPreview(effectiveCabTab());
      invalidateFrontPlaceholders(); // D-23: navrhovy rezim nema resolved vysky
      if (lastCabForFit !== null){ lastCabForFit = null; fitPreview(); }
      renderPartCard(null);      // schovaj kartu dielca
      renderHardware(null, []);  // kovanie len pre oznacenu skrinku
      clearCabinetMaterials();   // korpusove material selecty na "dedi" + disabled
      refreshZoneUI(); renderPreview();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  // Identita dosky v idbar (BRD-xxx + nazov; bez warnchipu — dosky warnings zatial nemaju).
  function setBoardIdbar(b){
    var bar = el('idbar'), list = el('warnList');
    if (!bar) return;
    dropCabRename(); // D-100: prechod na dosku ukoncuje rozpisany nazov skrinky bez zapisu
    if (list){ list.style.display = 'none'; list.innerHTML = ''; }
    if (!b){ setIdbar(null); return; }
    bar.innerHTML = '<span class="cid">' + esc(b.board_id || '?') + '</span>' +
      '<span class="cname">' + esc(b.name || '') + '</span>';
  }

