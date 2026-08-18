  // ===================== ZONE TREE (JS zrkadlo ZoneTree) =====================
  //
  // UI-C2: konstanty a geometria su ZRKADLOM `core/zone_tree.rb` (MIN_FIELD,
  // MAX_LEVELS, Shelves::MAX, FIELD_EPS, zlomky). Zhodu strazi test
  // `tests/pure/test_uic2_zony.rb` — cislo sa nikdy nemeni len na jednej strane.
  var NXZ = {
    MIN_FIELD: 20,        // ZoneTree::MIN_FIELD
    MAX_LEVELS: 3,        // ZoneTree::MAX_LEVELS (N22)
    MAX_SHELVES: 6,       // Shelves::MAX (pills 0–6)
    EPS: 0.01,            // ZoneTree::FIELD_EPS — mm Float, ziadne cele mm
    MAX_FIELDS: 4,        // najviac 4 polia v jednom deleni
    FIELD_FRACTIONS: [[1,4],[1,3],[1,2]], // ponuka pola „Prva zona" (N21)
    SNAP_FRACTIONS: [[1,4],[1,2],[3,4]]   // magnet tahania priecky (N20)
  };

  // --- JEDNA geometria pre zlomky aj magnet (audit F6) -----------------------
  // Zlomok aj magnet hovoria o TOM ISTOM: kde ma sediet STRED priecky.
  //   stred priecky i        = frac * span
  //   svetly sucet poli 0..i = frac * span - i*t - t/2
  // Pri 2 poliach a 1/2 z toho vyjde polovica SVETLEHO priestoru (span - t)/2,
  // nie polovica rozpatia — priecka tak stoji stredom presne v polovici zony.
  function nxZoneClear(span, count, t){
    return Math.max(0, span - (Math.max(1, count) - 1) * t);
  }
  function nxZoneCumForFraction(span, count, t, index, frac){
    return frac * span - index * t - t / 2;
  }
  // Ktore zlomky su pre priecku `index` dosiahnutelne (ostatnym poliam musi
  // ostat aspon MIN_FIELD). Vrati [{ label, frac, cum }].
  function nxZoneFractionOptions(span, count, t, index, fracs){
    var list = fracs || NXZ.FIELD_FRACTIONS, out = [], clear = nxZoneClear(span, count, t);
    var lo = (index + 1) * NXZ.MIN_FIELD, hi = clear - (count - index - 1) * NXZ.MIN_FIELD;
    list.forEach(function(fr){
      var f = fr[0] / fr[1], cum = nxZoneCumForFraction(span, count, t, index, f);
      if (cum >= lo - NXZ.EPS && cum <= hi + NXZ.EPS)
        out.push({ label: fr[0] + '/' + fr[1], frac: f, cum: nxRound2(cum) });
    });
    return out;
  }
  // Magnet: prilep svetly sucet na najblizsi zlomok, ak je bliz nez tolMm.
  // tolMm <= 0 (drzany Alt) = magnet vypnuty, vstup sa vrati nedotknuty.
  function nxZoneSnapCum(span, count, t, index, cum, tolMm, fracs){
    if (!(tolMm > 0)) return cum;
    var list = fracs || NXZ.SNAP_FRACTIONS, best = null;
    list.forEach(function(fr){
      var target = nxZoneCumForFraction(span, count, t, index, fr[0] / fr[1]);
      var d = Math.abs(target - cum);
      if (d <= tolMm && (best === null || d < best.d)) best = { d: d, v: target };
    });
    return best ? best.v : cum;
  }
  // mm Float s presnostou 0,01 — ZIADNE zaokruhlovanie na cele mm (pri deleni
  // na 3 polia by sa z korpusu „stratili" az 2 mm; STANDARD zna mm Float).
  function nxRound2(v){ return Math.round(v * 100) / 100; }

  // --- PRESNA CESTA: rozmer pola cislom (audit F7) ---------------------------
  // Vrati { cuts: [...] } alebo { error: 'veta pre pouzivatela' }.
  // Nezmestitelna hodnota sa ODMIETNE — nikdy sa ticho nezmensi. Zvysok po
  // proporcnom rozdeleni sa deterministicky dorovna do POSLEDNEHO odomknuteho
  // pola, takze sucet presne sedi na svetly priestor.
  function nxZoneExactCuts(cuts, sizes, count, clear, index, newSize, lockEdited){
    if (!(newSize > 0) || !isFinite(newSize))
      return { error: 'rozmer nie je platné číslo.' };
    if (newSize < NXZ.MIN_FIELD - NXZ.EPS)
      return { error: 'najmenšie pole je ' + NXZ.MIN_FIELD + ' mm.' };

    var i, keep = [], flex = [], lockedSum = 0;
    for (i = 0; i < count; i++){
      if (i === index) continue;
      if (cuts[i] && cuts[i].locked && cuts[i].size != null){ keep.push(i); lockedSum += Math.max(NXZ.MIN_FIELD, cuts[i].size); }
      else flex.push(i);
    }
    var rest = clear - newSize - lockedSum;
    if (flex.length === 0){
      if (Math.abs(rest) <= NXZ.EPS) { /* sedi presne */ }
      else return { error: 'ostatné polia sú zamknuté — uvoľni aspoň jeden zámok.' };
    } else if (rest < flex.length * NXZ.MIN_FIELD - NXZ.EPS){
      return { error: 'nezmestí sa — pre ostatné polia by ostalo ' + Math.round(Math.max(0, rest)) +
                      ' mm (treba aspoň ' + (flex.length * NXZ.MIN_FIELD) + ' mm).' };
    }

    var out = new Array(count);
    out[index] = { size: nxRound2(newSize), locked: !!lockEdited };
    keep.forEach(function(j){ out[j] = { size: nxRound2(Math.max(NXZ.MIN_FIELD, cuts[j].size)), locked: true }; });
    if (flex.length){
      var sp = nxZoneSpread(flex, sizes, rest);
      if (sp.remaining < -NXZ.EPS)
        return { error: 'nezmestí sa — pre ostatné polia treba aspoň ' + (flex.length * NXZ.MIN_FIELD) + ' mm.' };
      flex.forEach(function(j){ if (sp.fixed[j] != null) out[j] = { size: sp.fixed[j], locked: false }; });
      var pend = sp.pending;
      if (!pend.length){
        // vsetky odomknute polia sedia na minime — zvysok deterministicky poslednemu
        var lastF = flex[flex.length - 1];
        out[lastF] = { size: nxRound2(out[lastF].size + sp.remaining), locked: false };
      } else {
        var base = 0;
        pend.forEach(function(j){ base += (sizes && sizes[j] > 0) ? sizes[j] : 0; });
        var acc = 0;
        pend.forEach(function(j, k){
          var v;
          if (k === pend.length - 1) v = nxRound2(sp.remaining - acc);   // dorovnanie zvysku
          else {
            v = base > 0 ? (sp.remaining * ((sizes && sizes[j] > 0 ? sizes[j] : 0) / base)) : (sp.remaining / pend.length);
            v = nxRound2(v);
            acc += v;
          }
          out[j] = { size: v, locked: false };
        });
        var last = pend[pend.length - 1];
        if (out[last].size < NXZ.MIN_FIELD - NXZ.EPS)
          return { error: 'nezmestí sa — poslednému poľu by ostalo ' + Math.round(out[last].size) + ' mm.' };
      }
    }
    return { cuts: out };
  }

  // Rozdelenie zvysku medzi odomknute polia s REŠPEKTOM k minimu (water-filling).
  //
  // Codex #177 P2: proporcny podiel sa nesmie len „orezat na MIN_FIELD" — ten
  // rozdiel treba odobrat z toho, co ostava ostatnym, inak posledne pole spadne
  // pod minimum a funkcia ODMIETNE hodnotu, ktora sa v skutocnosti zmesti.
  // Priklad: vahy [20, 440, 440] a zvysok 60 mm — platne riesenie je [20,20,20],
  // ale jednorazovy clamp vratil chybu. Pole, ktore by proporcne dostalo menej
  // nez minimum, sa preto ZAFIXUJE na minimum a zvysok sa prepocita pre ostatne;
  // opakuje sa, kym sa nieco meni (konverguje — poli je najviac 4).
  function nxZoneSpread(idxs, sizes, total){
    var pending = idxs.slice(), fixed = {}, remaining = total, changed = true;
    var wOf = function(j){ return (sizes && sizes[j] > 0) ? sizes[j] : 0; };
    while (changed && pending.length){
      changed = false;
      var base = 0, keep = [], i, j, w;
      for (i = 0; i < pending.length; i++) base += wOf(pending[i]);
      for (i = 0; i < pending.length; i++){
        j = pending[i];
        w = base > 0 ? (wOf(j) / base) : (1 / pending.length);
        if (remaining * w < NXZ.MIN_FIELD - NXZ.EPS){
          fixed[j] = NXZ.MIN_FIELD; remaining -= NXZ.MIN_FIELD; changed = true;
        } else keep.push(j);
      }
      pending = keep;
    }
    return { fixed: fixed, pending: pending, remaining: remaining };
  }

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
      var count = Math.min(NXZ.MAX_FIELDS, Math.max(2, parseInt(sp.count || 2, 10)));
      var cuts = sanitizeCuts(sp.cuts, count);
      var rawKids = node.children || [];
      var kids = [];
      for (var i=0; i<count; i++) kids.push(sanitizeTree(rawKids[i], path.concat(i+1)));
      return { id:nodeId, generation:generation,
        split:{ axis:axis, count:count, cuts:cuts }, shelves:0, children:kids };
    }
    // UI-C2: strop polic je 6 (Shelves::MAX) — zrkadlo servera, nie nezavisla hodnota.
    return { id:nodeId, generation:generation, split:null,
      shelves:Math.min(NXZ.MAX_SHELVES, Math.max(0, parseInt(node.shelves||0,10) || 0)), children:[] };
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
  var MINF = NXZ.MIN_FIELD;
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
    var x0 = t, x1 = W - t;
    // D-80: strop vnutra pocita JEDINA zdielana funkcia (core.js nxInteriorZ) —
    // pri two_rails konci zonovy box pod vystuhami, nie na H - t.
    var iv = nxInteriorZ(currentCarcass({ height: H, thickness: t }));
    var z0 = iv.zLo, z1 = iv.zHi;
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
      node.split.cuts[j] = { size: nxRound2(sizes[j]), locked: lk };
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
      node.split.cuts[j] = { size: nxRound2(sizes[j]), locked: node.split.cuts[j].locked };
    }
    currentZoneTree = tree;
  }
  // Posli kompletny cuts layout zony do Ruby (ulozi sa naraz cez ZoneTree.set_field_cuts!).
  function pushFieldCuts(localId, editedIndex){
    var node = navTree(sanitizeTree(currentZoneTree), pathOf(localId));
    if (!node || !node.split) return;
    if (selectedCabId && window.sketchup && sketchup.set_zone_field)
      sketchup.set_zone_field(nxZonePayload({ zone_id: fullZoneId(localId), index: editedIndex, cuts: node.split.cuts }));
  }

  // UI-C2 (audit F9): KAZDY zonovy callback nesie identitu dokumentu a skrinky.
  // ID zon sa medzi dokumentmi opakuju (`CAB-001-Z1.2` je v kazdom projekte),
  // takze oneskoreny callback CEF by po prepnuti dokumentu prestaval CUDZI model.
  // Server pri nezhode zmenu odmietne — jedno miesto, kde sa metadata pridavaju.
  function nxZonePayload(obj){
    var o = obj || {};
    o.model_guid = (typeof nxModelGuid !== 'undefined') ? nxModelGuid : '';
    o.cabinet_id = (typeof selectedCabId !== 'undefined' && selectedCabId) ? selectedCabId : '';
    return JSON.stringify(o);
  }

  // Node testy (tests/js/test_uic2_zony.js) — LEN ciste jadro (zrkadlo konstant,
  // geometria zlomkov/magnetu, presna cesta, sanitizacia stromu). DOM cast bezi
  // v CEF normalne (vzor preview.js / shell.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { NXZ: NXZ, nxZoneClear: nxZoneClear,
                       nxZoneCumForFraction: nxZoneCumForFraction,
                       nxZoneFractionOptions: nxZoneFractionOptions,
                       nxZoneSnapCum: nxZoneSnapCum, nxZoneExactCuts: nxZoneExactCuts,
                       nxZoneSpread: nxZoneSpread,
                       nxRound2: nxRound2,
                       sanitizeTree: sanitizeTree, sanitizeCuts: sanitizeCuts,
                       resolveFields: resolveFields, pathOf: pathOf, navTree: navTree };
  }

