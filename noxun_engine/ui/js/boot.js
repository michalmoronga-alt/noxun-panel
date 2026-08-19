  // ===== Pamatanie rozbalenia sekcii (localStorage) ==========================
  // UI-B1 (audit A5): kluc skupiny v sektore S4 je KVALIFIKOVANY KONTEXTOM
  // (`nxsec_s4.korpus.top`), aby sa stavy skupin rôznych kontextov nemiesali,
  // keby v buducnosti pribudla rovnomenna skupina v inom kontexte. Sektory
  // (S1–S4) su NEZAVISLE a perzistentne — ich zbalenia preziju echo push aj
  // zatvorenie panela, lebo ziju v localStorage a kostra sa nikdy neprekresluje.
  // Rozhodovacia logika (kluce + exkluzivita) zije v NXShell (js/shell.js), aby
  // sa dala testovat v Node bez DOM — tu ostava uz len praca s prvkami.
  function nxSecNodes(){
    return Array.prototype.slice.call(document.querySelectorAll('details[data-key]'));
  }
  function nxSecItem(d){
    return { key: d.dataset.key, s4: d.getAttribute('data-s4') || null,
             solo: d.hasAttribute('data-s4-solo'), open: !!d.open, node: d };
  }
  function nxSecWrite(d){
    try { localStorage.setItem(NXShell.secKey(d.dataset.key, d.getAttribute('data-s4')), d.open ? '1' : '0'); } catch(e){}
  }
  // A5: skupiny v ramci JEDNEHO kontextu S4 su EXKLUZIVNE — otvorenie zavrie
  // surodencov a ich zatvorenie sa aj ULOZI (inak by sa pri navrate otvorili
  // vsetky naraz). Sektory S1–S4 su nezavisle, `data-s4-solo` (strom zon) je
  // z exkluzivity vynaty.
  function nxSecExclusive(d){
    if (!d.open) return;
    var items = nxSecNodes().map(nxSecItem);
    var close = NXShell.exclusiveClose(items, d.dataset.key);
    if (!close.length) return;
    items.forEach(function(it){
      if (close.indexOf(it.key) < 0) return;
      it.node.open = false;
      nxSecWrite(it.node);
    });
  }
  function bindDetails(){
    nxSecNodes().forEach(function(d){
      try {
        var v = localStorage.getItem(NXShell.secKey(d.dataset.key, d.getAttribute('data-s4')));
        if (v !== null) d.open = (v === '1');
      } catch(e){}
      // Meta lista sektora S4 ukazuje OTVORENU skupinu (alebo pocet zbalenych),
      // takze kazde rozbalenie/zbalenie ju musi obnovit. `toggle` nebublinkuje —
      // delegovany listener v shell.js ho nezachyti, patri sem.
      d.addEventListener('toggle', function(){
        nxSecExclusive(d); nxSecWrite(d);
        if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
      });
    });
    // Po obnove z localStorage moze byt otvorenych viac surodencov naraz
    // (starsi stav, rucny zasah) — exkluzivitu presadime hned pri starte:
    // v kazdom kontexte ostane otvorena PRVA skupina, ostatne sa zavru.
    NXShell.CONTEXTS.forEach(function(ctx){
      var first = null;
      nxSecNodes().forEach(function(d){
        if (d.getAttribute('data-s4') !== ctx || d.hasAttribute('data-s4-solo') || !d.open) return;
        if (!first){ first = d; return; }
        d.open = false;
        nxSecWrite(d);
      });
    });
  }
  // V0.4.7e: staticke rozmerove polia s vyrazovou podporou (dynamicke — cela .fh
  // a polia zon — pripajaju ich rendery; bc_quantity je POCET, vyrazy nema).
  function bindExprFields(){
    ['width','height','depth','thickness','floor_height','plinth_recess','rails_top_offset','rail_depth',
     'fr_gap','fr_gap_top','fr_gap_bottom','fr_gap_sides'] // D-07 medzery/presahy cel
      .forEach(function(id){ attachExprField(el(id), { flushFn: flushCabinetEditsNow }); });
    // E-03: ib_thickness je pri UNI materiali editovatelne dim pole (pri realnom
    // je readOnly — expr handler sam zamknute pole nikdy nemeni).
    ['ib_length','ib_width','ib_thickness'].forEach(function(id){ attachExprField(el(id)); });
    // GH #103 P2: bc_thickness je pri UNI editovatelne dim pole — vyrazy
    // (18-6) potrebuju rovnaky expr handler ako dlzka/sirka.
    ['bc_length','bc_width','bc_thickness'].forEach(function(id){ attachExprField(el(id), { flushFn: flushBoardEditsNow }); });
  }
  // D-85 (UI-03): prve pripojenie zdielaneho comboboxu na STATICKE selecty panela
  // (korpus/celá/chrbát, materiál dielca, materiál dosky, vkladaci materiál).
  // Dynamicke (hrany dielca a dosky) si ho beru vlastnym nxComboSync pri renderi.
  // UI-B1: nxShellApply nahradilo setCabTab('korpus') — nasadi data-view-ctx,
  // stav raily aj nazov sektora S4 este pred prvym setUiMode.
  // UI-C1b: setupTemplateTiles = JEDNA delegacia nad mriezkou dlazdic sablon
  // (klik = vybrat, dvojklik = vlozit) — dlazdice sa prekresluju, listener nie.
  // UI-C4: bindHwOwnerHover = JEDNA delegacia nad #hwRows (hover boxu prisvieti
  // znacky kovania v projekcii) — boxy sa prestavuju, listener nie.
  // UI-D3 (N5): bindWarnPanel = zatvaranie warnpanelu (klik mimo + Escape).
  // Listenery visia na STATICKOM #warnList a na document — obsah panela sa
  // prekresluje pri kazdom pushi, listener nie.
  function bindWarnPanel(){
    var list = el('warnList'); if (!list) return;
    // Klik VNUTRI panela sa k documentu nedostane (inak by sa panel zavrel
    // skor, nez klik na oko doleti k svojmu handleru).
    list.addEventListener('click', function(ev){ ev.stopPropagation(); });
    document.addEventListener('click', function(){ closeWarnPanel(); });
    document.addEventListener('keydown', function(ev){
      if (ev.key !== 'Escape' || !warnPanelOpen()) return;
      closeWarnPanel();
      // Fokus patri spat na ⚠ chip — inak by po Escape skoncil v prazdne.
      var chip = document.querySelector('#idbar .warnchip');
      if (chip){ try { chip.focus(); } catch (e) {} }
    });
  }
  window.onload = function(){ bindDetails(); bindExprFields(); setupPreviewDelegation(); setupPartSvgDelegation(); setupBoardSvgDelegation(); setupHoverEdge(); setupFieldEditorDelegation(); setupTemplateTiles(); bindHwOwnerHover(); bindWarnPanel(); nxComboSync(); document.body.setAttribute('data-insert-kind', getInsertKind()); nxShellApply(); if (window.sketchup && sketchup.ready) sketchup.ready(); };
