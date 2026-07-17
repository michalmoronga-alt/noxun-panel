  // ===================== ZONE TREE (JS zrkadlo ZoneTree) =====================
  function defaultTree(sh, nodeId){
    return { id:(nodeId || 'Z1'), generation:0, split:null, shelves:(sh||0), children:[] };
  }
  function truthy(v){ return v===true || v==='true' || v==='1' || v===1; }
  function sanitizeTree(node, path){
    path = Array.isArray(path) ? path : [1];
    node = (node && typeof node === 'object') ? node : {};
    var nodeId = String(node.id || '').trim() || ('Z' + path.join('_'));
    var generation = Math.max(0, parseInt(node.generation || 0, 10) || 0);
    var sp = node.split;
    if (sp && typeof sp === 'object'){
      var axis = (sp.axis === 'h') ? 'h' : 'v';
      var count = Math.min(4, Math.max(2, parseInt(sp.count || 2, 10)));
      var cuts = sanitizeCuts(sp.cuts, count);
      var rawKids = node.children || [];
      var kids = [];
      for (var i=0; i<count; i++) kids.push(sanitizeTree(rawKids[i], path.concat(i+1)));
      return { id:nodeId, generation:generation,
        split:{ axis:axis, count:count, cuts:cuts }, shelves:0, children:kids };
    }
    return { id:nodeId, generation:generation, split:null,
      shelves:Math.min(4, Math.max(0, parseInt(node.shelves||0,10) || 0)), children:[] };
  }
  function sanitizeCuts(cuts, count){
    var arr = (cuts||[]).map(function(c){
      c = c||{}; var sz = (c.size!=null?c.size:(c.at_mm!=null?c.at_mm:null));
      return { size:(sz==null||sz===''?null:parseFloat(sz)), locked: truthy(c.locked) };
    });
    arr = arr.slice(0, count);
    while (arr.length < count) arr.push({ size:null, locked:false });
    return arr;
  }
  function navTree(tree, path){ var n = tree; for (var i=1;i<path.length;i++){ if(!n.children||!n.children[path[i]-1]) return null; n=n.children[path[i]-1]; } return n; }
  // fix #4: zvladne aj lokalne draft id 'Z1.2' (pred vlozenim korpusu), nielen 'CAB-001-Z1.2'.
  function pathOf(zid){ var s = String(zid); var m = s.match(/-Z([\d.]+)$/) || s.match(/^Z([\d.]+)$/); return m ? m[1].split('.').map(function(x){return parseInt(x,10);}) : [1]; }
  var MINF = 20;
  // fix #1 (zrkadlo Ruby ZoneTree.resolve_fields): kumulativny clamp zamknutych poli — Sigma(locked)
  // nikdy nepresiahne dostupny priestor (aj po rezervovani MINF na kazde nezamknute) -> priecky/zony
  // nevzniknu mimo rodica. Nezamknute: proporcny prepocet (nositel fix #5).
  function resolveFields(cuts, count, span, t){
    var clear = Math.max(0, span - (count-1)*t);
    cuts = sanitizeCuts(cuts, count);
    var lockedIdx = [], unlockedIdx = [];
    for (var i=0;i<count;i++){ if (cuts[i].locked && cuts[i].size!=null) lockedIdx.push(i); else unlockedIdx.push(i); }
    var lockedWant = lockedIdx.map(function(i){ return Math.max(cuts[i].size, MINF); });
    var lockedSum = lockedWant.reduce(function(a,b){return a+b;}, 0);
    var availLocked = Math.max(0, clear - MINF*unlockedIdx.length);
    if (lockedSum > availLocked && lockedSum > 0){
      var factor = availLocked/lockedSum;
      lockedWant = lockedWant.map(function(s){ return s*factor; });
      lockedSum = lockedWant.reduce(function(a,b){return a+b;}, 0);
    }
    var free = Math.max(0, clear - lockedSum);
    var known = unlockedIdx.map(function(i){return cuts[i].size;}).filter(function(x){return x!=null;});
    var avg = known.length ? known.reduce(function(a,b){return a+b;},0)/known.length : (free/Math.max(1,unlockedIdx.length));
    var wsum = unlockedIdx.reduce(function(s,i){ return s + (cuts[i].size!=null?cuts[i].size:avg); }, 0); if (wsum<=0) wsum=1;
    var sizes = new Array(count);
    lockedIdx.forEach(function(i,k){ sizes[i] = lockedWant[k]; });
    unlockedIdx.forEach(function(i){ var w = (cuts[i].size!=null?cuts[i].size:avg); sizes[i] = free*(w/wsum); });
    return sizes;
  }

  // Vypocet zon (2D: x,z) z currentZoneTree + rozmerov korpusu. Vrati pole {id,path,x,z,w,h,leaf,shelves,split,label}.
  function computeZones(){
    var t = numv('thickness')||18, W = numv('width')||600, H = numv('height')||720;
    var fh = (getType()==='upper') ? 0 : (numv('floor_height')||0);
    var topNone = val('top_mode')==='none';
    var x0 = t, x1 = W - t;
    var z0 = fh + t, z1 = topNone ? H : H - t;
    var out = [];
    walkZones(sanitizeTree(currentZoneTree||defaultTree()), [1], x0, x1, z0, z1, t, 'Celé vnútro', out);
    return out;
  }
  function walkZones(node, path, x0, x1, z0, z1, t, label, out){
    var leaf = !node.split;
    var o = { id:'Z'+path.join('.'), path:path.slice(), x:x0, z:z0, w:(x1-x0), h:(z1-z0), leaf:leaf,
              shelves:(leaf?node.shelves:0), split:null, label:label };
    if (leaf){ out.push(o); return; }
    var axis = node.split.axis, count = node.split.count;
    var span = (axis==='v') ? (x1-x0) : (z1-z0);
    var sizes = resolveFields(node.split.cuts, count, span, t);
    o.split = { axis:axis, count:count, cuts:node.split.cuts, sizes:sizes };
    out.push(o);
    if (axis==='v'){
      var x = x0;
      for (var c=0;c<count;c++){ var w=sizes[c]; walkZones(node.children[c], path.concat(c+1), x, x+w, z0, z1, t, 'Stĺpec '+(c+1), out); x+=w; if(c<count-1)x+=t; }
    } else {
      var z = z0;
      for (var r=0;r<count;r++){ var hh=sizes[r]; walkZones(node.children[r], path.concat(r+1), x0, x1, z, z+hh, t, 'Riadok '+(r+1), out); z+=hh; if(r<count-1)z+=t; }
    }
  }
  function fullZoneId(localId){ return (selectedCabId ? selectedCabId : 'NEW') + '-' + localId; }
  function localZoneId(fullId){ var m = String(fullId).match(/-(Z[\d.]+)$/); return m ? m[1] : fullId; }

  // ===================== fix #5: PERZISTENCIA LAYOUTU POLI =====================
  // Zisti clear-span (mm) delenej zony z aktualneho nahladu (podla osi delenia).
  function zoneSpan(localId){
    var span = null;
    computeZones().forEach(function(z){ if (z.id===localId && z.split){ span = (z.split.axis==='v') ? z.w : z.h; } });
    return span;
  }
  // Persistni CELY layout delenej zony ako explicitne sizes vsetkych poli. Editovane pole 'anchorIdx'
  // sa docasne zamkne na 'anchorSize' (kotva), zvysne nezamknute sa dopocitaju okolo neho a VSETKY sa
  // ulozia ako explicitna size (locked flag: anchor dostane 'anchorLocked', ostatne ponechaju svoj).
  // Vysledok: zadany rozmer NEzmizne; proporcny prepocet nezamknutych az pri resize korpusu (nova span).
  function persistLayout(localId, anchorIdx, anchorSize, anchorLocked){
    var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localId));
    if (!node || !node.split) return;
    var count = node.split.count, t = numv('thickness')||18;
    var span = zoneSpan(localId); if (span==null) return;
    var tempCuts = node.split.cuts.map(function(c, j){
      if (j===anchorIdx) return { size:(anchorSize==null?null:anchorSize), locked:(anchorSize!=null) };
      return { size:c.size, locked:c.locked };
    });
    var sizes = resolveFields(tempCuts, count, span, t);
    for (var j=0;j<count;j++){
      var lk = (j===anchorIdx) ? anchorLocked : node.split.cuts[j].locked;
      node.split.cuts[j] = { size: Math.round(sizes[j]), locked: lk };
    }
    currentZoneTree = tree;
  }
  // Zmraz aktualne resolved rozmery vsetkych poli zony do explicitnych sizes (zachovaj locky).
  // Na zaciatku dragu priecky — aby sa pri tahani menili len 2 dotknute polia a ostatne drzali.
  function freezeLayout(localId){
    var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localId));
    if (!node || !node.split) return;
    var sizes = null;
    computeZones().forEach(function(z){ if (z.id===localId && z.split) sizes = z.split.sizes; });
    if (!sizes) return;
    for (var j=0;j<node.split.count;j++){
      node.split.cuts[j] = { size: Math.round(sizes[j]), locked: node.split.cuts[j].locked };
    }
    currentZoneTree = tree;
  }
  // Posli kompletny cuts layout zony do Ruby (ulozi sa naraz cez ZoneTree.set_field_cuts!).
  function pushFieldCuts(localId, editedIndex){
    var node = navTree(sanitizeTree(currentZoneTree), pathOf(localId));
    if (!node || !node.split) return;
    if (selectedCabId && window.sketchup && sketchup.set_zone_field)
      sketchup.set_zone_field(JSON.stringify({ zone_id: fullZoneId(localId), index: editedIndex, cuts: node.split.cuts }));
  }

