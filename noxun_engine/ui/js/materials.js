  // ===================== V0.3 MATERIALY (korpus) =====================
  // Projektove predvolby sa V0.4.5 D2 presunuli do okna Materialy projektu
  // (proj_materials.html + js/proj_materials.js) — panel drzi len materialy
  // OZNACENEJ skrinky (override dedenia projekt -> skrinka).
  function setCabinetMaterials(c){
    var on = !!c.cabinet_id;
    ['cab_body','cab_front','cab_back'].forEach(function(id){ var e=el(id); if(e) e.disabled = !on; });
    setVal('cab_body', c.material_id || '');
    setVal('cab_front', c.front_material_id || '');
    setVal('cab_back', c.back_material_id || '');
    el('cabMatHint').textContent = on ? 'Materiály tejto skrinky — prázdne = dediť z projektu.'
                                      : 'Označ skrinku pre nastavenie jej materiálov.';
  }
  function clearCabinetMaterials(){
    ['cab_body','cab_front','cab_back'].forEach(function(id){ var e=el(id); if(e){ e.value=''; e.disabled=true; } });
    el('cabMatHint').textContent = 'Označ skrinku pre nastavenie jej materiálov.';
  }
  function onCabinetMaterial(which, value){
    if (!selectedCabId){ NX.setStatus('Najprv označ skrinku.', true); return; }
    if (window.sketchup && sketchup.set_cabinet_material) sketchup.set_cabinet_material(JSON.stringify({ which: which, value: value }));
  }
  function openProjectMaterialsDialog(){
    if (window.sketchup && sketchup.open_project_materials) sketchup.open_project_materials('');
  }
  function openTemplatesDialog(){
    if (window.sketchup && sketchup.open_templates) sketchup.open_templates('');
  }
