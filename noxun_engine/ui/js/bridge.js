  // ===================== Ruby -> JS =====================
  // V0.4.5 D1: rezimy Inspectora — body class riadi viditelnost kontextovych kariet
  // (CSS: mode-insert zobrazi vkladaciu kartu; mode-cab nastavenia korpusu; mode-part
  // kartu dielca a skryje korpusove sekcie). Identita hore = setIdbar.
  var lastCabForFit = null;
  // UI-B1 (audit A1): JEDINE miesto zmeny rezimu je aj jedine miesto, kde sa
  // vyhodnocuje IDENTITA vyberu. `sel` je serverovy payload toho, co je
  // oznacene (cabinet_payload / part_card / board_payload; null = nic) — z neho
  // NXShell odvodi identitu aj popis docasnej polozky raily.
  function setUiMode(mode, sel){
    document.body.className = 'mode-' + mode;
    if (sel && typeof nxSetModelGuid === 'function') nxSetModelGuid(sel.model_guid);
    // D-14 (Codex F5): modal patri k oznacenemu korpusu — mimo mode-cab sa zatvara
    if (mode !== 'cab' && typeof closeSaveTemplateModal === 'function') closeSaveTemplateModal();
    // UI-D1: modal „Použiť na podobné…" patri karte DIELCA — mimo mode-part sa
    // zatvara (rovnaky dovod ako pri sablonovom modale: oneskorene rozhodnutie
    // by zapisalo olep do dielca, ktory uz nie je na obrazovke).
    if (mode !== 'part' && typeof closeSimilarModal === 'function') closeSimilarModal();
    // D-32 (audit B2): SKUTOCNY prechod cab|part|board -> insert = reset karty
    // z insert stavu (typ + sablona + zamky); insert -> insert sync NEresetuje,
    // rozpisane upravy v karte preziju. Jedine miesto zmeny rezimu = jedine
    // miesto resetu — plati pre kazdu buducu cestu do mode-insert.
    if (NXInsert.trackMode(mode)) materializeInsertCard();
    // UI-B1: nova identita vyberu => viewContext spat na Korpus; ECHO push tej
    // istej identity kontext NEMENI (rozpisana praca musi prezit).
    NXShell.setLabel(nxTempLabel(mode, sel));
    // UI-B2: rovnaka zasada plati pre chipy vrstiev nahladu — nova identita
    // zacina s cistym pasom, ECHO push prisvietene vrstvy NEZHASINA.
    if (NXShell.track(mode, NXShell.identityOf(mode, sel)) &&
        typeof NXLayers !== 'undefined') NXLayers.reset();
    // Zrkadlo stavu do DOM (rail + data-view-ctx) — className vyssie zmazal
    // aj pripadne stare priznaky, preto pri KAZDEJ zmene rezimu.
    if (typeof nxShellApply === 'function') nxShellApply();
  }
  // Popis docasnej polozky raily — meno dielca/dosky, alebo rola dielca.
  function nxTempLabel(mode, sel){
    if (!sel) return '';
    if (mode === 'part') return sel.name || (typeof roleLabel === 'function' ? roleLabel(sel.role) : '');
    if (mode === 'board') return sel.name || '';
    return '';
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

  // D3 / UI-D3 (N5): klik na ⚠ chip rozbali/zbali WARNPANEL pod identitou.
  function setIdbar(c){
    var bar = el('idbar'), list = el('warnList');
    if (!bar) return;
    if (!c){
      dropCabRename(); // vyber zmizol — rozpisany nazov konci bez zapisu
      bar.innerHTML = '<span class="free">Nič nie je označené — návrh nového objektu</span>';
      if (list){ setWarnPanel(false); list.innerHTML = ''; }
      return;
    }
    lastCabName = c.name || '';
    var warns = c.warnings || [];
    // A10: warn chip = skutocne <button> (fokusovatelne, klavesova aktivacia).
    // Ikona zo spritu (staticky markup); pocet je cislo — bezpecne (B9).
    // UI-D3: klik nesie `event` — warnpanel zatvara KLIK MIMO (delegacia na
    // document), takze klik na samotny chip musi bublanie zastavit, inak by
    // sa panel v tom istom kliku otvoril a hned zavrel.
    var wHtml = warns.length
      ? ' <button type="button" class="warnchip" data-nx-usage="warn:chip" onclick="toggleWarnList(event)" aria-expanded="false" title="Zobraziť upozornenia stavby" aria-label="Zobraziť upozornenia stavby">' + NXIcons.svg('alert') + ' ' + warns.length + '</button>'
      : '';
    // FIX 4: echo TEJ ISTEJ skrinky nesmie zhltnut rozpisany nazov — prekresli
    // sa vsetko okrem bunky nazvu, ktora ostane v editacnom rezime.
    var keepEditor = renameFor && renameFor === (c.cabinet_id || '') && el('cnameInput');
    // UI-B3: typ skrinky ako READONLY badge (Dolná/Horná). Typ sa nastavuje
    // VYHRADNE šablónou/vkladaním — badge ho len ukazuje a title to hovorí.
    var tHtml = ' <span class="typbadge" title="Typ korpusu — určuje ho šablóna pri vložení">' +
      esc(nxCabInfo(c).type) + '</span>';
    if (keepEditor){
      var idEl = bar.querySelector('.cid');
      if (idEl) idEl.textContent = c.cabinet_id || '?';
      var oldChip = bar.querySelector('.warnchip');
      if (oldChip) oldChip.parentNode.removeChild(oldChip);
      var oldBadge = bar.querySelector('.typbadge');
      if (oldBadge) oldBadge.parentNode.removeChild(oldBadge);
      bar.insertAdjacentHTML('beforeend', tHtml + wHtml);
    } else {
      dropCabRename(); // ina skrinka = editor konci bez zapisu
      bar.innerHTML = '<span class="cid">' + esc(c.cabinet_id || '?') + '</span>' +
        cabNameCellHtml(c) + tHtml + wHtml;
    }
    if (list){
      if (warns.length){
        list.innerHTML = warnPanelHtml(warns, c.cabinet_id || '');
        // Chip sa práve prekreslil (aria-expanded="false" v šablóne), ale panel
        // mohol ostať otvorený — echo push tej istej skrinky ho nezatvára.
        setWarnPanel(warnPanelOpen());
      } else {
        closeWarnPanel(); list.innerHTML = '';
      }
    }
  }

  // UI-D3 (N5): obsah warnpanelu. Riadky sklada CISTA funkcia NXShell.warnRows
  // (Node test) — tu sa uz len escapuje a vklada. Kazdy riadok ma OKO: klik
  // oznaci dotknuty dielec v modeli (prazdne kluce = cela skrinka). Dole je
  // JEDNA cesta von — deep-link do okna Vyroba na tab KONTROLA.
  function warnPanelHtml(warns, cabId){
    var rows = NXShell.warnRows(warns);
    // Codex #182 P2: riadky maju VLASTNY scroller (`.wrows`), aby dlhy zoznam
    // nálezov nevytlacil cestu von pod okraj okna — tlacidlo ostava dole.
    var h = '<div class="wrows">';
    rows.forEach(function(r){
      h += '<div class="warnrow"><span>' + esc(r.text) + '</span>' +
        '<button type="button" class="wgo" data-nx-usage="warn:oko"' +
        ' data-keys="' + esc(r.keys.join(',')) + '"' +
        ' data-cab="' + esc(cabId) + '" onclick="onWarnRowPick(this, event)"' +
        ' title="' + esc(r.tip) + '" aria-label="' + esc(r.tip) + '">' +
        NXIcons.svg('eye') + '</button></div>';
    });
    h += '</div>';
    h += '<button type="button" class="wgoto" data-nx-usage="warn:studio"' +
      ' onclick="onWarnStudio(event)"' +
      ' title="Otvorí okno Výroba na tabe KONTROLA — celý zoznam nálezov zákazky">' +
      'Otvoriť v Štúdiu → Kontrola</button>';
    return h;
  }

  // Panel je OVERLAY: otvara ho ⚠ chip, zatvara klik mimo, Escape a kazda
  // zmena vyberu, ktora zoznam prestavia (setIdbar bez upozorneni).
  function closeWarnPanel(){ setWarnPanel(false); }
  function warnPanelOpen(){
    var list = el('warnList');
    return !!(list && list.classList && list.classList.contains('open'));
  }
  // Jedno miesto, kde sa mení viditeľnosť — aj `aria-expanded` chipu tak
  // hovorí pravdu bez ohľadu na to, ktorá cesta panel zatvorila.
  //
  // Sweep review P2: prepína sa TRIEDA, nie inline `display`. Inline
  // `display: block` prebíjalo `display: flex` z CSS, takže panel prestal byť
  // stĺpcový flex a `.wrows` scroller bol mŕtvy — dlhý zoznam nálezov sa
  // neposúval. Inline hodnota sa navyše ČISTÍ (staré okno z CEF cache ju môže
  // mať zapečenú v HTML), inak by trieda nemala šancu sa presadiť.
  function setWarnPanel(open){
    var list = el('warnList'); if (!list) return;
    if (list.style.display) list.style.display = '';
    if (open) list.classList.add('open'); else list.classList.remove('open');
    var chip = document.querySelector('#idbar .warnchip');
    if (chip) chip.setAttribute('aria-expanded', open ? 'true' : 'false');
  }
  function toggleWarnList(ev){
    if (ev && ev.stopPropagation) ev.stopPropagation();
    var list = el('warnList'); if (!list || !list.innerHTML) return;
    setWarnPanel(!warnPanelOpen());
  }

  // Oko v riadku: oznaci v modeli to, o com nalez hovori. Ide TOU ISTOU
  // serverovou cestou ako box vlastnika v Kovani (`nx_select_hw_owner`) —
  // ciste citanie + zmena vyberu, ziadna operacia a ziadny krok Spat.
  //
  // FLUSH HANDSHAKE (vzor onInfoParts / onHwOwnerPick): rozpisany edit caka
  // 400 ms; keby timer dobehol AZ PO vybere, prestavba skrinky by reselectla
  // cely korpus a oznaceny dielec by sa ticho stratil. Neplatne (cervene) pole
  // akciu ZASTAVI — flush by ju aj tak neaplikoval.
  function onWarnRowPick(btn, ev){
    if (ev && ev.stopPropagation) ev.stopPropagation();
    var cab = btn.getAttribute('data-cab') || '';
    if (!cab){ NX.setStatus('Označ skrinku v modeli.', true); return; }
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — rozpísaná úprava by sa pri označení stratila.', true);
      return;
    }
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    var raw = btn.getAttribute('data-keys') || '';
    var keys = raw ? raw.split(',').filter(function(k){ return k !== ''; }) : [];
    if (window.sketchup && sketchup.nx_select_hw_owner){
      sketchup.nx_select_hw_owner(JSON.stringify({
        model_guid: (typeof nxModelGuid === 'string') ? nxModelGuid : '',
        cabinet_id: cab, part_keys: keys, origin: 'warn' }));
    }
  }

  // „Otvoriť v Štúdiu → Kontrola". Štúdio je zatial okno Vyroba, preto sa
  // otvara ONO — a rovno na tabe KONTROLA (deep-link; whitelist tabov je na
  // strane Ruby). Panel sa zavrie: pouzivatel odchadza do ineho okna.
  function onWarnStudio(ev){
    if (ev && ev.stopPropagation) ev.stopPropagation();
    closeWarnPanel();
    if (typeof openProductionDialog === 'function') openProductionDialog('control');
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
      if (data.version){
        el('verline').textContent = 'V' + data.version; // verzia z Ruby (jediny zdroj)
        // UI-B3: tá istá verzia v koliesku (sekcia O plugine) — ziadny hardcode.
        var cv = el('cfgVersion'); if (cv) cv.textContent = 'V' + data.version;
      }
      // UI-B3: nastavenia POCITACA (rozmerove rady + tema) — nie su to data
      // zakazky; menia LEN ponuky pri rozmeroch a stav prepinaca v koliesku.
      if (typeof nxApplyUiSettings === 'function') nxApplyUiSettings(data.ui_settings);
      // UI-B1 (audit A2): stav ABS kontroly hran pri OTVORENI panela (pull).
      // Dalsie zmeny chodia pushom — z panela, z toolbaru aj z okna Vyroba.
      if (typeof nxApplyEdgeCheck === 'function') nxApplyEdgeCheck(data.edge_check);
      // Codex #168 P2 (2. kolo): identita DOKUMENTU — chodi v kazdom pushi a
      // nesu ju identity guardy asynchronnych callbackov panela.
      if (typeof nxSetModelGuid === 'function') nxSetModelGuid(data.model_guid);
      refreshMaterialFilters(); // (projektove predvolby zobrazi okno Materialy projektu)
      el('zonesChk').checked = !!data.zones_visible;
      // V0.4.7c: uz oznacena DOSKA pri otvoreni panela (selected_kind z Ruby)
      if (data.selected_kind === 'board' && data.selected){ setType('lower'); setDefaults('lower'); currentZoneTree = defaultTree(); renderTemplateTiles(true); NX.loadBoard(data.selected); }
      else if (data.selected){ NX.loadSelected(data.selected); }
      else { setType('lower'); setDefaults('lower'); currentZoneTree = defaultTree(); renderTemplateTiles(true); NX.clearSelected(); onField(); }
    },
    // UI-C1b: nova kniznica = PRESTAVBA dlazdic (force) — po vlozeni zo sablony
    // posiela server push_templates s cerstvym `used_seq`, takze sa poradie
    // „Naposledy použité“ prekresli bez restartu panela.
    setTemplates: function(list){ TEMPLATES = list || []; renderTemplateTiles(true); refreshTplModalWarn(); }, // D-14: varovanie kolizie zije aj pri otvorenom modale
    // UI-D2: odpoved na `nx_template_preview` — PNG nahlad JEDNEJ sablony ako
    // data URI. Meni LEN obrazok v dlazdici (ziadny render karty, ziadna
    // prestavba mriezky — vzor NX.setUsedIds); `png: null` = bez nahladu,
    // dlazdica ostane na schematickej kresbe.
    setTemplatePreview: function(data){
      if (typeof applyTemplatePreview === 'function') applyTemplatePreview(data);
    },
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
    // UI-D1: odpoved na `nx_similar_parts_count` — ZIVY pocet podobnych dielcov
    // pre otvoreny modal „Použiť na podobné…". Meni LEN obsah modalu (ziadny
    // render karty, ziadny dotyk formulara — vzor NX.setUsedIds).
    setSimilarCount: function(data){
      if (typeof setSimilarCount === 'function') setSimilarCount(data);
    },
    setUsedIds: function(data){
      MATERIALS.used_ids = data || { sheets: [], edges: [] };
      if (typeof NXCombo !== 'undefined' && NXCombo) NXCombo.rerender();
    },
    // K1 (Codex #185 kolo 2, P2): CERSTVY payload karty dielca po zmene katalogu.
    // `setMaterials` nizsie kartu prekresluje z CACHOVANEHO payloadu, takze
    // serverom skladane udaje (segment „Smer dekoru", texty hran D-102) by
    // ostali stare. Ruby posiela tento push HNED za katalogom; posiela ho LEN
    // ked je vo vybere dielec, takze `null` sem nechodi a rezim panela sa
    // nemeni (schovanie karty patri vyhradne push_selected).
    setPartCard: function(data){
      if (!data) return;
      if (typeof renderPartCard === 'function') renderPartCard(data);
    },
    setMaterials: function(data){
      MATERIALS = data || { sheets: [], edges: [] };
      refreshMaterialFilters();
      if (typeof refreshInsertBoardMaterials === 'function') refreshInsertBoardMaterials();
      if (typeof partCard !== 'undefined' && partCard) renderPartCard(partCard);
      if (typeof boardCard !== 'undefined' && boardCard) renderBoardCard(boardCard);
      // Codex #171 P2: premenovanie dekoru v okne Materialy chodi TOUTO cestou
      // (bez loadSelected) — kontextovy riadok si preto popis prelozi znova.
      renderCtxNote();
      // Codex #173 P2: z rovnakeho dovodu aj meta lista sektora Materialy —
      // je to PROGRAMOVA zmena popisu, ziadne `change` sa nevystreli.
      if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
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
      hwItems = c.hardware || [];           // UI-B2: ten isty payload kresli projekciu Kovanie
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
      // (mode ostava cab, setUiMode guard nezabera; identitu navyse strazi server).
      // UI-B3 (Codex audit BLOCKER 2): „iny" znamena aj INY DOKUMENT — ID skriniek
      // sa naprie dokumentmi opakuju, takze samotne cabinet_id nestaci.
      if (typeof tplModalOpen === 'function' && tplModalOpen() &&
          typeof tplModalStale === 'function' && tplModalStale(c)) closeSaveTemplateModal();
      // D-41 C2: novy vyber pocas otvoreneho ABS modalu = tiche zatvorenie bez
      // akcie (rozhodnutie by zasiahlo inu kartu; identitu navyse strazi server).
      if (typeof absModalCloseSilent === 'function') absModalCloseSilent();
      activeZoneId = c.active_zone || null;
      setSelected(c.cabinet_id || null);
      refreshMaterialFilters(); // FIX 2: prefiltruj podla hrubok tohto korpusu (pred nastavenim hodnot)
      setCabinetMaterials(c); // V0.3 korpusove material selecty (prazdne = dedi)
      renderTemplateTiles(true);
      setIdbar(c);
      // Kontextovy riadok (nahrada S2/S3 v Zonach/Celach/Kovani) — PRED
      // setUiMode, aby nxShellApply uz pisal cerstvy suhrn. Ziadne nove data:
      // rozmery su z payloadu, popis materialu z katalogu, ktory panel uz ma.
      setCtxNote(c);
      // part_card je vnoreny payload — identitu dokumentu nesie obalka.
      if (c.part_card) c.part_card.model_guid = c.model_guid;
      setUiMode(c.part_card ? 'part' : 'cab', c.part_card ? c.part_card : c);
      // D-08 (Codex F3): dielec = vzdy ZONOVY nahlad (klik na zonu = vedomy odchod
      // z dielca, povodne spravanie). Atribut data-view-ctx prezije setUiMode
      // (className prepis) — nastavuje ho nxShellApply.
      previewMode = c.part_card ? 'zones' : cabTabPreview(NXShell.effectiveCtx());
      // pohlad: ina skrinka -> fit; ta ista (auto-apply rebuild) -> pohlad DRZI
      if (c.cabinet_id !== lastCabForFit){ lastCabForFit = c.cabinet_id; fitPreview(); }
      // svetle rozmery presne z backendu ak su (UI-B3: TEXT v informacnom stlpci)
      if (c.available_width!=null) setOut('av_width', Math.round(c.available_width));
      if (c.available_depth!=null) setOut('av_depth', Math.round(c.available_depth));
      if (c.available_height!=null) setOut('av_height', Math.round(c.available_height));
      // UI-B3: dopocitane udaje stlpca — pocet dielcov a plocha dosky. Cisla
      // pocita server (ciste citanie snapshotov), JS ich len formatuje.
      setCabInfo(c);
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
      activeZoneId = null; frontItems = null; hwItems = null;
      invalidateFrontPlaceholders(); // D-23: bez resolved dat ziadne ≈ odhady
      buildFrontHwBadges([]);
      setCabInfo(null); // UI-B3: kontext dosky — korpusove dopocty neplatia
      setCtxNote(null); // ani suhrn skrinky (doska ma vlastnu kartu)
      renderPartCard(null);
      renderHardware(null, []);
      clearCabinetMaterials();
      if (lastCabForFit !== null){ lastCabForFit = null; }
      renderBoardCard(b);
      setBoardIdbar(b);
      setUiMode('board', b);
      refreshZoneUI(); renderPreview();
    },
    clearSelected: function(guid){
      if (typeof nxSetModelGuid === 'function') nxSetModelGuid(guid); // identita dokumentu aj bez vyberu
      cancelBoardEdits();                    // V0.4.7c: koniec kontextu dosky
      renderBoardCard(null);
      if (applyTimer){ clearTimeout(applyTimer); applyTimer = null; }
      // D-32: identita prec PRED setUiMode — reset karty (materializeInsertCard
      // vnutri setUiMode) nesmie bezat nad zvyskami stareho vyberu.
      setSelected(null);
      activeZoneId = null; frontItems = null; hwItems = null;
      buildFrontHwBadges([]); // Codex PR #30: badge patria oznacenej skrinke — bez nej ziadne
      setCabInfo(null);       // UI-B3: bez skrinky niet dielcov ani plochy
      setCtxNote(null);       // ani suhrn skrinky do kontextoveho riadku
      setIdbar(null);
      // UI-C1b (N9/N10): vkladanie ma VLASTNU projekciu — sablona tak, ako bude
      // vlozena (korpus s celami), pri doske obdlznik so smerom dekoru. Kontexty
      // raily su vo vkladani neaktivne (D-78 / UI-B1), takze o pohlade nerozhoduju.
      // Nastavuje sa PRED setUiMode: ten cez materializeInsertCard uz kresli.
      previewMode = 'insert';
      setUiMode('insert', null);
      invalidateFrontPlaceholders(); // D-23: navrhovy rezim nema resolved vysky
      if (lastCabForFit !== null){ lastCabForFit = null; fitPreview(); }
      renderPartCard(null);      // schovaj kartu dielca
      renderHardware(null, []);  // kovanie len pre oznacenu skrinku
      clearCabinetMaterials();   // korpusove material selecty na "dedi" + disabled
      refreshZoneUI(); renderPreview();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; },
    // UI-B3: maly push nastaveni pocitaca po zmene v koliesku (rady/tema).
    // Meni LEN ponuky a stav prepinaca — ZIADNY render karty, rozpisany
    // formular sa nesmie dotknut (vzor NX.setUsedIds).
    setUiSettings: function(data){ if (typeof nxApplyUiSettings === 'function') nxApplyUiSettings(data); },
    // UI-B1 (audit A2): stav ABS kontroly hran do raily. Rovnaky kanal ako ma
    // okno Vyroba (D-105) — panel si ZIADNY vlastny stav nedrzi, len zobrazuje
    // to, co posle server (klik z panela, z toolbaru aj z okna Vyroba).
    setEdgeCheck: function(state){ if (typeof nxApplyEdgeCheck === 'function') nxApplyEdgeCheck(state); }
  };

  // UI-B3: informacny stlpec Zakladnych. Texty sklada cista funkcia nxCabInfo
  // (core.js) z payloadu skrinky; bez oznacenej skrinky su pomlcky a klikatelne
  // riadky su neaktivne — `aria-disabled`, NIE HTML `disabled` (vzor D-78:
  // tlacidlo ostava fokusovatelne a nesie vysvetlenie).
  // Suhrn skrinky do kontextoveho riadku. Vstupy si drzime ako DATA (rozmery
  // + ID materialu), NIE ako hotovy text: popis dekoru sa da premenovat v okne
  // Materialy a ten push (`NX.setMaterials`) kartu skrinky neposiela — cachovany
  // retazec by ukazoval stary nazov az do dalsieho vyberu (Codex #171 P2).
  var ctxNoteSrc = null;

  function setCtxNote(c){
    var p = c || {};
    ctxNoteSrc = p.cabinet_id
      ? { w: p.width, h: p.height, d: p.depth, material_id: p.material_id || '' }
      : null;
    renderCtxNote();
  }

  // Preklad ID -> popis dekoru sa robi AZ TU, z aktualneho katalogu. Prazdny
  // material_id znamena „dedi z projektu" — povedz to nahlas, nepis meno
  // cudzieho dekoru. Text sklada cista funkcia NXShell.ctxNoteText.
  function renderCtxNote(){
    if (typeof nxSetCtxNote !== 'function') return;
    if (!ctxNoteSrc){ nxSetCtxNote(null, ''); return; }
    var s = ctxNoteSrc;
    var mat = s.material_id
      ? (typeof sheetLabelOf === 'function' ? sheetLabelOf(s.material_id) : '')
      : 'dekor dedí z projektu';
    nxSetCtxNote({ w: s.w, h: s.h, d: s.d }, mat);
  }

  function setCabInfo(c){
    var info = nxCabInfo(c);
    setOut('inf_parts', info.parts);
    setOut('inf_area', info.area);
    var live = !!(c && c.cabinet_id);
    [['infParts', 'Klik = označí výrobné dielce tejto skrinky v modeli'],
     ['infArea', 'Klik = otvorí Kusovník (okno Výroba); filter na jednu skrinku pribudne v Štúdiu']].forEach(function(o){
      var n = el(o[0]); if (!n) return;
      n.setAttribute('aria-disabled', live ? 'false' : 'true');
      n.title = live ? o[1] : 'Označ skrinku v modeli';
    });
  }

  // Identita dosky v idbar (BRD-xxx + nazov; bez warnchipu — dosky warnings zatial nemaju).
  function setBoardIdbar(b){
    var bar = el('idbar'), list = el('warnList');
    if (!bar) return;
    dropCabRename(); // D-100: prechod na dosku ukoncuje rozpisany nazov skrinky bez zapisu
    if (list){ setWarnPanel(false); list.innerHTML = ''; }
    if (!b){ setIdbar(null); return; }
    bar.innerHTML = '<span class="cid">' + esc(b.board_id || '?') + '</span>' +
      '<span class="cname">' + esc(b.name || '') + '</span>';
  }

