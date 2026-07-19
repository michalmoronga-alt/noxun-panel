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
    ['ib_length','ib_width'].forEach(function(id){ attachExprField(el(id)); });
    ['bc_length','bc_width'].forEach(function(id){ attachExprField(el(id), { flushFn: flushBoardEditsNow }); });
  }
  window.onload = function(){ bindDetails(); bindExprFields(); setupPreviewDelegation(); setupPartSvgDelegation(); setupBoardSvgDelegation(); setupFieldEditorDelegation(); document.body.setAttribute('data-insert-kind', getInsertKind()); if (window.sketchup && sketchup.ready) sketchup.ready(); };
