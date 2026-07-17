  // ===================== V0.3 MATERIALY (projekt + korpus) =====================
  function setProjectMaterials(pm){
    setVal('proj_body', pm.default_material_id || '');
    setVal('proj_front', pm.default_front_material_id || '');
    setVal('proj_back', pm.default_back_material_id || '');
  }
  function setCabinetMaterials(c){
    var on = !!c.cabinet_id;
    ['cab_body','cab_front','cab_back'].forEach(function(id){ var e=el(id); if(e) e.disabled = !on; });
    setVal('cab_body', c.material_id || '');
    setVal('cab_front', c.front_material_id || '');
    setVal('cab_back', c.back_material_id || '');
    el('cabMatHint').textContent = on ? 'Prázdne = dediť z projektu.' : 'Označ skrinku pre nastavenie jej materiálov.';
  }
  function clearCabinetMaterials(){
    ['cab_body','cab_front','cab_back'].forEach(function(id){ var e=el(id); if(e){ e.value=''; e.disabled=true; } });
    el('cabMatHint').textContent = 'Označ skrinku pre nastavenie jej materiálov.';
  }
  function onProjectMaterial(key, value){
    if (window.sketchup && sketchup.set_project_material) sketchup.set_project_material(JSON.stringify({ key: key, value: value }));
  }
  function onCabinetMaterial(which, value){
    if (!selectedCabId){ NX.setStatus('Najprv označ skrinku.', true); return; }
    if (window.sketchup && sketchup.set_cabinet_material) sketchup.set_cabinet_material(JSON.stringify({ which: which, value: value }));
  }

