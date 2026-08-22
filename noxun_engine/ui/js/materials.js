  // ===================== V0.3 MATERIALY (korpus) =====================
  // Projektove predvolby sa V0.4.5 D2 presunuli do okna Materialy projektu;
  // to v ŠT-2b ZANIKLO a katalog aj predvolby ziju v SEKCII `mat` okna Studio
  // (js/proj_materials.js). Panel drzi len materialy OZNACENEJ skrinky
  // (override dedenia projekt -> skrinka) a do katalogu vedie deep-linkom
  // `openStudio('mat')` — vlastnu otvaraciu funkciu uz nema.
  function setCabinetMaterials(c){
    var on = !!c.cabinet_id;
    // UI-C3: `cab_front_c` je DRUHY ovladac materialu ciel (zoznam ciel v
    // kontexte Cela) — sektor Materialy patri Korpusu a v kontexte Cela je
    // skryty. Ta ista hodnota, dva vstupne body; drzat ich v synchro MUSI
    // KAZDA cesta, ktora sa dotkne `cab_front`.
    ['cab_body','cab_front','cab_front_c','cab_back'].forEach(function(id){ var e=el(id); if(e) e.disabled = !on; });
    setVal('cab_body', c.material_id || '');
    setVal('cab_front', c.front_material_id || '');
    setVal('cab_front_c', c.front_material_id || ''); // UI-C3: zrkadlo v zozname ciel
    setVal('cab_back', c.back_material_id || '');
    el('cabMatHint').textContent = on ? 'Materiály tejto skrinky — prázdne = dediť z projektu.'
                                      : 'Označ skrinku pre nastavenie jej materiálov.';
    // D-85: zmena `value`/`disabled` nevystreli ziadnu udalost — trigger comboboxu
    // treba obnovit vyslovne (inak by ukazoval material predoslej skrinky).
    nxComboSync();
  }
  function clearCabinetMaterials(){
    // UI-C3: `cab_front_c` je DRUHY ovladac materialu ciel (zoznam ciel v
    // kontexte Cela) — sektor Materialy patri Korpusu a v kontexte Cela je
    // skryty. Ta ista hodnota, dva vstupne body; drzat ich v synchro MUSI
    // KAZDA cesta, ktora sa dotkne `cab_front`.
    ['cab_body','cab_front','cab_front_c','cab_back'].forEach(function(id){ var e=el(id); if(e){ e.value=''; e.disabled=true; } });
    el('cabMatHint').textContent = 'Označ skrinku pre nastavenie jej materiálov.';
    nxComboSync();
  }
  // D-45 (audit F9): payload nesie cabinet_id z casu kliku — server ho overi proti
  // aktualnemu vyberu (preklik medzi klikom a callbackom nesmie zasiahnut iny
  // korpus; zmena materialu tela navyse meni hrubku, tam je zamena drahá).
  function onCabinetMaterial(which, value){
    if (!selectedCabId){ NX.setStatus('Najprv označ skrinku.', true); return; }
    if (window.sketchup && sketchup.set_cabinet_material)
      sketchup.set_cabinet_material(JSON.stringify({ which: which, value: value, cabinet_id: selectedCabId }));
  }
  function openTemplatesDialog(){
    if (window.sketchup && sketchup.open_templates) sketchup.open_templates('');
  }
