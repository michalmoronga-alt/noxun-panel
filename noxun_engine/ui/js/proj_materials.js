  // ===================== Materialy projektu — formular =====================
  // Tri selecty projektovych predvolieb (korpus / cela / chrbat). Cela ponukaju
  // 18/19 mm dosky (standard celovych hrubok); korpus a chrbat cely katalog —
  // hrubkovu kompatibilitu konkretnych skriniek straži Ruby pri ulozeni
  // (nekompatibilne skrinky vypise a zmenu odmietne).

  var MD_SHEETS = [];

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

  function fillSelect(sel, sheets, current){
    var html = '';
    sheets.forEach(function(s){
      html += '<option value="'+esc(s.id)+'">'+esc(s.label)+'</option>';
    });
    sel.innerHTML = html;
    if (current) sel.value = current;
  }
  function frontSheets(){
    return MD_SHEETS.filter(function(s){
      var t = parseFloat(s.thickness);
      return Math.abs(t-18) < 0.05 || Math.abs(t-19) < 0.05;
    });
  }

  window.MD = {
    init: function(data){
      MD_SHEETS = (data.materials && data.materials.sheets) ? data.materials.sheets : [];
      el('mdline').textContent = 'V' + (data.version || '') + ' · skriniek v modeli: ' + (data.cabinets || 0);
      var p = data.project || {};
      fillSelect(el('md_body'), MD_SHEETS, p.default_material_id);
      fillSelect(el('md_front'), frontSheets(), p.default_front_material_id);
      fillSelect(el('md_back'), MD_SHEETS, p.default_back_material_id);
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  function onProjMaterial(key, value){
    if (window.sketchup && sketchup.set_project_material)
      sketchup.set_project_material(JSON.stringify({ key: key, value: value }));
  }

  if (window.sketchup && sketchup.ready) sketchup.ready('');
