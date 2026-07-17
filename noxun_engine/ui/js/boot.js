  // Pamatanie rozbalenia sekcii (localStorage).
  function bindDetails(){
    document.querySelectorAll('details[data-key]').forEach(function(d){
      var k = 'nxsec_' + d.dataset.key;
      try { var v = localStorage.getItem(k); if (v !== null) d.open = (v === '1'); } catch(e){}
      d.addEventListener('toggle', function(){ try { localStorage.setItem(k, d.open ? '1' : '0'); } catch(e){} });
    });
  }
  window.onload = function(){ bindDetails(); setupPreviewDelegation(); setupPartSvgDelegation(); if (window.sketchup && sketchup.ready) sketchup.ready(); };
