  // ===================== VYROBA (V0.5 B) =====================
  // Kusovnik + supisy z Bom (Ruby). READ-ONLY — klik na riadok IBA vybera
  // entity v modeli (cez Ruby select_row s generacnym tokenom; server je
  // autorita — stale klik = odmietnut + re-push). Tabulky sa skladaju jednym
  // innerHTML a klik ide DELEGACIOU (Codex N9 — stovky riadkov bez lagov).

  var BOM = null;          // posledny push z Ruby
  var prodTab = 'rows';

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function num(v, dec){ return (v==null||isNaN(v)) ? '—' : Number(v).toFixed(dec==null?0:dec).replace('.', ','); }

  window.NX = {
    setBom: function(data){
      BOM = data || null;
      el('prodModel').textContent = BOM ? ('model: ' + BOM.model_title + ' · v' + BOM.version) : '…';
      vepoSync(); renderSummary(); renderBadge(); renderBody();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  // ===================== VEPO export (V0.5 C) =====================
  // Lifecycle inputu (Codex F10): nazov projektu sa predvyplni z Ruby LEN pri
  // zmene modelu (novy model = novy default); pocas prace na tom istom modeli
  // sa pouzivatelova uprava NIKDY neprepise. Merge checkbox sa inicializuje
  // raz zo zapamataneho nastavenia.
  var vepoModelSeen = null;
  var vepoInited = false;

  function vepoSync(){
    if (!BOM || !BOM.vepo) return;
    var inp = el('vepoProject');
    // identita modelu = epocha prepnuti + cesta (GH P2: dva "Bez nazvu" modely
    // maju rovnaky titul — nazov projektu sa musi resetnut aj vtedy)
    var mkey = BOM.vepo.model_key || BOM.model_title;
    if (inp && mkey !== vepoModelSeen){
      inp.value = BOM.vepo.default_project || 'projekt';
      vepoModelSeen = mkey;
    }
    if (!vepoInited){
      var chk = el('vepoMerge');
      if (chk) chk.checked = BOM.vepo.merge_18_36 !== false;
      vepoInited = true;
    }
  }

  function vepoExport(){
    if (!BOM || !window.sketchup || !sketchup.vepo_export) return;
    var p = { gen: BOM.gen,
              project: (el('vepoProject') ? el('vepoProject').value : '').trim(),
              merge: el('vepoMerge') ? el('vepoMerge').checked : true };
    NX.setStatus('Exportujem VEPO…', false);
    sketchup.vepo_export(JSON.stringify(p));
  }

  function requestRefresh(){ if (window.sketchup && sketchup.refresh_bom) sketchup.refresh_bom(''); }

  function setProdTab(t){
    prodTab = t;
    ['rows','sheets','edging','hardware','warnings'].forEach(function(k){
      el('pt_' + k).classList.toggle('on', k === t);
    });
    el('prodHint').style.display = (t === 'rows' || t === 'hardware') ? '' : 'none';
    renderBody();
  }

  function renderSummary(){
    if (!BOM){ el('prodSummary').textContent = '…'; return; }
    var s = BOM.summary || {};
    el('prodSummary').innerHTML =
      '<b>' + num(s.cabinets) + '</b> skriniek · <b>' + num(s.boards) + '</b> dosiek · ' +
      '<b>' + num(s.quantity) + '</b> dielcov (' + num(s.rows) + ' riadkov) · ' +
      '<b>' + num(s.m2_total, 2) + '</b> m² · <b>' + num(s.bm_total, 1) + '</b> bm ABS · ' +
      '<b>' + num(s.hardware_quantity) + '</b> ks kovania';
  }

  function renderBadge(){
    var n = BOM && BOM.warnings ? BOM.warnings.length : 0;
    var b = el('warnBadge');
    b.style.display = n ? '' : 'none';
    b.textContent = n;
  }

  function edgesLabel(edges){
    var codes = ['L1','L2','W1','W2'];
    var on = codes.filter(function(c){ return edges && edges[c]; });
    return on.length ? on.join('+') : '—';
  }

  function renderBody(){
    var box = el('prodBody');
    if (!BOM){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (prodTab === 'rows') return renderRows(box);
    if (prodTab === 'sheets') return renderSheets(box);
    if (prodTab === 'edging') return renderEdging(box);
    if (prodTab === 'hardware') return renderHardware(box);
    renderWarnings(box);
  }

  function renderRows(box){
    var rows = BOM.rows || [];
    if (!rows.length){ box.innerHTML = '<div class="muted">Žiadne výrobné dielce v modeli — vlož korpus alebo dosku.</div>'; return; }
    var h = '<table class="bomtab"><thead><tr><th>Názov</th><th>Dĺžka</th><th>Šírka</th><th>Hr.</th><th>ks</th><th>Materiál</th><th>ABS</th><th>Kde</th></tr></thead><tbody>';
    rows.forEach(function(r, i){
      var kde = (r.kde || []).map(function(k){ return esc(k.owner_id) + '×' + k.quantity; }).join(', ');
      h += '<tr class="bomrow" data-i="' + i + '"><td>' + esc((r.names || []).join(' / ')) + '</td>' +
           '<td>' + num(r.length) + '</td><td>' + num(r.width) + '</td><td>' + num(r.thickness) + '</td>' +
           '<td><b>' + num(r.quantity) + '</b></td><td>' + esc(r.material_id) + '</td>' +
           '<td>' + edgesLabel(r.edges) + '</td><td>' + kde + '</td></tr>';
    });
    box.innerHTML = h + '</tbody></table>';
  }

  function renderSheets(box){
    var list = BOM.sheets || [];
    if (!list.length){ box.innerHTML = '<div class="muted">Žiadne doskové materiály.</div>'; return; }
    // D-19: odhad platni — parovanie VYHRADNE mapou podla material_id (Codex F7:
    // indexy sa rozidu, ak material vypadol z katalogu; taky dostane fallback)
    var est = {};
    (BOM.sheet_estimate || []).forEach(function(e){ est[e.material_id] = e; });
    var h = '<table class="bomtab"><thead><tr><th>Materiál</th><th>m²</th><th>dielcov</th><th>Formát</th><th>Platne (odhad)</th></tr></thead><tbody>';
    list.forEach(function(s){
      var e = est[s.material_id];
      var fb = e && e.fallback;
      var fmt = e ? (num(e.sheet_size[0]) + '×' + num(e.sheet_size[1])) : '—';
      var pl = e ? (num(e.count_min, 1) + ' – ' + num(e.count_max, 1)) : '—';
      var cls = 'estcell' + (fb ? ' estfb' : '');
      var tt = fb ? ' title="Materiál nemá formát v katalógu — použitý 2800×2070"' : '';
      h += '<tr><td>' + esc(s.material_id) + '</td><td><b>' + num(s.m2, 2) + '</b></td><td>' + num(s.quantity) + '</td>' +
           '<td class="' + cls + '"' + tt + '>' + fmt + '</td><td class="' + cls + '"' + tt + '><b>' + pl + '</b></td></tr>';
    });
    box.innerHTML = h + '</tbody></table>' +
      '<div class="hint">Odhad = plocha × prerez 10–25 % ÷ platňa. Orientačný rozsah, NIE nárezový plán. Formát platne sa nastavuje v katalógu materiálov (okno Materiály projektu).</div>';
  }

  function renderEdging(box){
    var list = BOM.edging || [];
    if (!list.length){ box.innerHTML = '<div class="muted">Žiadne ABS hrany.</div>'; return; }
    var h = '<table class="bomtab"><thead><tr><th>ABS páska</th><th>bm</th><th>hrán</th></tr></thead><tbody>';
    list.forEach(function(e){
      h += '<tr><td>' + esc(e.abs_id) + '</td><td><b>' + num(e.bm, 1) + '</b></td><td>' + num(e.edges) + '</td></tr>';
    });
    box.innerHTML = h + '</tbody></table>';
  }

  function renderHardware(box){
    var list = BOM.hardware || [];
    if (!list.length){ box.innerHTML = '<div class="muted">Žiadne kovanie (kovanie sa počíta z pravidiel korpusov).</div>'; return; }
    var h = '<table class="bomtab"><thead><tr><th>Typ</th><th>Parametre</th><th>ks</th><th>Kde</th></tr></thead><tbody>';
    list.forEach(function(g, i){
      var params = Object.keys(g.params || {}).map(function(k){ return esc(k) + ' ' + esc(g.params[k]); }).join(', ') || '—';
      var kde = (g.breakdown || []).map(function(b){ return esc(b.owner_id) + '×' + b.quantity + (b.source === 'manual' ? ' (ručne)' : ''); }).join(', ');
      h += '<tr class="hwrow" data-i="' + i + '"><td>' + esc(g.generic_type) + '</td><td>' + params + '</td>' +
           '<td><b>' + num(g.quantity) + '</b></td><td>' + kde + '</td></tr>';
    });
    box.innerHTML = h + '</tbody></table>';
  }

  function renderWarnings(box){
    var list = BOM.warnings || [];
    if (!list.length){ box.innerHTML = '<div class="muted">Žiadne upozornenia — stavba čistá.</div>'; return; }
    var h = '<table class="bomtab"><thead><tr><th>Skrinka</th><th>Upozornenie</th></tr></thead><tbody>';
    list.forEach(function(w){
      h += '<tr><td>' + esc(w.owner_id || '—') + '</td><td>' + esc(w.message || w.code || '') + '</td></tr>';
    });
    box.innerHTML = h + '</tbody></table>';
  }

  // Delegovany klik: posiela KLUC riadku (nie pids) — Ruby si po flushi editov
  // najde cerstve refs (Codex GH #48 P2: rebuild po flushi meni persistent id).
  document.addEventListener('click', function(ev){
    var tr = ev.target && ev.target.closest ? ev.target.closest('tr.bomrow, tr.hwrow') : null;
    if (!tr || !BOM || !window.sketchup || !sketchup.select_row) return;
    var i = parseInt(tr.getAttribute('data-i'), 10);
    var payload = { gen: BOM.gen };
    if (tr.className.indexOf('bomrow') >= 0){
      var r = (BOM.rows || [])[i];
      if (!r || !r.key) return;
      payload.parts_key = r.key;
    } else {
      var g = (BOM.hardware || [])[i];
      if (!g || !g.key) return;
      payload.hw_key = g.key;
    }
    sketchup.select_row(JSON.stringify(payload));
  });

  window.onload = function(){ if (window.sketchup && sketchup.ready) sketchup.ready(''); };
