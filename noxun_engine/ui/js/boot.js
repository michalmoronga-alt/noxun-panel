  // Pamatanie rozbalenia sekcii (localStorage).
  function bindDetails(){
    document.querySelectorAll('details[data-key]').forEach(function(d){
      var k = 'nxsec_' + d.dataset.key;
      try { var v = localStorage.getItem(k); if (v !== null) d.open = (v === '1'); } catch(e){}
      d.addEventListener('toggle', function(){ try { localStorage.setItem(k, d.open ? '1' : '0'); } catch(e){} });
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
  window.onload = function(){ bindDetails(); bindExprFields(); setupPreviewDelegation(); setupPartSvgDelegation(); setupBoardSvgDelegation(); setupFieldEditorDelegation(); nxComboSync(); document.body.setAttribute('data-insert-kind', getInsertKind()); setCabTab('korpus'); /* D-08 Codex F2: atribut+preview+tlacidla jednym volanim */ if (window.sketchup && sketchup.ready) sketchup.ready(); };
