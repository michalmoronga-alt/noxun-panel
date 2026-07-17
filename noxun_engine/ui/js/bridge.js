  // ===================== Ruby -> JS =====================
  window.NX = {
    init: function(data){
      DEFAULTS = data.defaults || { lower: {}, upper: {} };
      TEMPLATES = data.templates || [];
      MATERIALS = data.materials || { sheets: [], edges: [] };
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
      setNum('width', c.width); setNum('height', c.height); setNum('depth', c.depth); setNum('thickness', c.thickness);
      setNum('floor_height', c.floor_height);
      setVal('bottom_mode', c.bottom_mode); setVal('top_mode', c.top_mode); setVal('back_mode', c.back_mode);
      setNum('back_thickness', c.back_thickness || 3);
      setVal('plinth_mode', c.plinth_mode); setNum('plinth_recess', c.plinth_recess);
      setVal('rails_orientation', c.rails_orientation); setNum('rails_top_offset', c.rails_top_offset); setNum('rail_depth', c.rail_depth);
      applyVisibility(t);
      renderFronts(c.fronts);
      currentZoneTree = c.zone_tree ? sanitizeTree(c.zone_tree) : defaultTree();
      lastZones = c.zones || [];
      frontItems = c.front_items || [];
      activeZoneId = c.active_zone || null;
      setSelected(c.cabinet_id || null);
      refreshMaterialFilters(); // FIX 2: prefiltruj podla hrubok tohto korpusu (pred nastavenim hodnot)
      setCabinetMaterials(c); // V0.3 korpusove material selecty (prazdne = dedi)
      renderFilteredTemplates();
      el('selinfo').innerHTML = 'Označený: <b>' + (c.cabinet_id || '?') + '</b>';
      // svetle rozmery presne z backendu ak su
      if (c.available_width!=null) setVal('av_width', Math.round(c.available_width));
      if (c.available_depth!=null) setVal('av_depth', Math.round(c.available_depth));
      if (c.available_height!=null) setVal('av_height', Math.round(c.available_height));
      renderPartCard(c.part_card || null); // V0.3 karta dielca (ak je vybraty dielec)
      renderPreview();
      refreshZoneUI();
    },
    clearSelected: function(){
      el('selinfo').textContent = 'Nič nie je označené (náhľad z hodnôt panela).';
      setSelected(null);
      activeZoneId = null; lastZones = null; frontItems = null;
      renderPartCard(null);      // schovaj kartu dielca
      clearCabinetMaterials();   // korpusove material selecty na "dedi" + disabled
      refreshZoneUI(); renderPreview();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

