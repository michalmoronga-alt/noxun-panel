  // ===================== Ruby -> JS =====================
  // V0.4.5 D1: rezimy Inspectora — body class riadi viditelnost kontextovych kariet
  // (CSS: mode-insert zobrazi vkladaciu kartu; mode-cab nastavenia korpusu; mode-part
  // kartu dielca a skryje korpusove sekcie). Identita hore = setIdbar.
  var lastCabForFit = null;
  function setUiMode(mode){ document.body.className = 'mode-' + mode; }
  function setIdbar(c){
    var bar = el('idbar'); if (!bar) return;
    if (!c){
      bar.innerHTML = '<span class="free">Nič nie je označené — návrh nového korpusu</span>';
      return;
    }
    var warns = c.warnings || [];
    var wHtml = warns.length
      ? ' <span class="warnchip" title="' + esc(warns.map(function(w){ return w.message; }).join('\n')) + '">⚠ ' + warns.length + '</span>'
      : '';
    bar.innerHTML = '<span class="cid">' + esc(c.cabinet_id || '?') + '</span>' +
      '<span class="cname">' + esc(c.name || '') + '</span>' + wHtml;
  }

  window.NX = {
    init: function(data){
      DEFAULTS = data.defaults || { lower: {}, upper: {} };
      TEMPLATES = data.templates || [];
      MATERIALS = data.materials || { sheets: [], edges: [] };
      if (data.version) el('verline').textContent = 'V' + data.version; // verzia z Ruby (jediny zdroj)
      refreshMaterialFilters();
      setProjectMaterials(data.project_materials || {});
      el('zonesChk').checked = !!data.zones_visible;
      if (data.selected){ NX.loadSelected(data.selected); }
      else { setType('lower'); setDefaults('lower'); currentZoneTree = defaultTree(); renderFilteredTemplates(); NX.clearSelected(); onField(); }
    },
    setTemplates: function(list){ TEMPLATES = list || []; renderFilteredTemplates(); },
    loadSelected: function(c){
      var t = c.type || 'lower';
      setType(t);
      writeConstruction(c);
      applyVisibility(t);
      renderFronts(c.fronts);
      currentZoneTree = c.zone_tree ? sanitizeTree(c.zone_tree) : defaultTree();
      frontItems = c.front_items || [];
      activeZoneId = c.active_zone || null;
      setSelected(c.cabinet_id || null);
      refreshMaterialFilters(); // FIX 2: prefiltruj podla hrubok tohto korpusu (pred nastavenim hodnot)
      setCabinetMaterials(c); // V0.3 korpusove material selecty (prazdne = dedi)
      renderFilteredTemplates();
      setIdbar(c);
      setUiMode(c.part_card ? 'part' : 'cab');
      // pohlad: ina skrinka -> fit; ta ista (auto-apply rebuild) -> pohlad DRZI
      if (c.cabinet_id !== lastCabForFit){ lastCabForFit = c.cabinet_id; fitPreview(); }
      // svetle rozmery presne z backendu ak su
      if (c.available_width!=null) setVal('av_width', Math.round(c.available_width));
      if (c.available_depth!=null) setVal('av_depth', Math.round(c.available_depth));
      if (c.available_height!=null) setVal('av_height', Math.round(c.available_height));
      renderPartCard(c.part_card || null); // V0.3 karta dielca (ak je vybraty dielec)
      renderHardware(c.hardware || [], c.hardware_overrides || []); // V0.4 kovanie
      renderPreview();
      refreshZoneUI();
    },
    clearSelected: function(){
      setIdbar(null);
      setUiMode('insert');
      setSelected(null);
      activeZoneId = null; frontItems = null;
      if (lastCabForFit !== null){ lastCabForFit = null; fitPreview(); }
      renderPartCard(null);      // schovaj kartu dielca
      renderHardware(null, []);  // kovanie len pre oznacenu skrinku
      clearCabinetMaterials();   // korpusove material selecty na "dedi" + disabled
      refreshZoneUI(); renderPreview();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

