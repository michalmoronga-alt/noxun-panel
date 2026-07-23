  // ===================== Materialy projektu =====================
  // Horna cast: 3 selecty projektovych predvolieb (korpus / cela / chrbat) —
  // hrubkovu kompatibilitu skriniek strazi Ruby pri ulozeni.
  // Davka 2 (D-05): sprava GLOBALNEHO katalogu (dosky + ABS). ID generuje SERVER
  // (JS ho nikdy nevymysla); create/edit su oddelene callbacky; hrubka
  // existujuceho materialu je nemenna (hrubka definuje variant).
  // MD.init NEZATVARA rozpisany formular (Codex audit) — prekresli len zoznamy
  // a selecty; editor stav zije oddelene v mdEditing.

  var MD_SHEETS = [];      // zuzeny payload pre selecty predvolieb (id/label/thickness)
  var MD_CATALOG = { sheets: [], edges: [] }; // plne zaznamy pre spravu
  var MD_PROTECTED = [];
  var MD_REV = '';         // D-41: baseline katalogu — server odmietne zapis nad starsim stavom
  var mdEditing = null;    // null | {kind:'sheet'|'edge', id:null|'...'}

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

  // --- farba: '#rrggbb' <-> [r,g,b] ---
  function rgbToHex(rgb){
    if (!rgb || rgb.length !== 3) return '#d8c4a0';
    return '#' + rgb.map(function(c){ c = Math.max(0, Math.min(255, parseInt(c,10)||0)); return ('0'+c.toString(16)).slice(-2); }).join('');
  }
  function hexToRgb(hex){
    var m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(String(hex||''));
    return m ? [parseInt(m[1],16), parseInt(m[2],16), parseInt(m[3],16)] : [216,196,160];
  }

  // --- zoznamy katalogu ---
  function mdRenderLists(){
    var sl = el('mdSheetList');
    if (sl){
      var html = '';
      MD_CATALOG.sheets.forEach(function(s){
        var prot = MD_PROTECTED.indexOf(s.material_id) >= 0;
        html += '<div class="tplrow">' +
          '<i style="flex:0 0 14px;height:14px;border-radius:3px;background:'+esc(rgbToHex(s.color))+'"></i>' +
          '<span class="tpln">'+esc(s.label)+(prot ? ' <span class="tplt">predvoľba</span>' : '')+'</span>' +
          '<button class="ghostbtn tplbtn" onclick="mdOpenSheetForm(\''+esc(s.material_id)+'\')">Upraviť</button>' +
          (prot ? '' : '<button class="ghostbtn tpldel" title="Zmazať" onclick="mdDeleteSheet(\''+esc(s.material_id)+'\')">✕</button>') +
          '</div>';
      });
      sl.innerHTML = html || '<div class="muted">Katalóg je prázdny.</div>';
    }
    var elist = el('mdEdgeList');
    if (elist){
      var h2 = '';
      MD_CATALOG.edges.forEach(function(a){
        h2 += '<div class="tplrow">' +
          '<i style="flex:0 0 14px;height:14px;border-radius:3px;background:'+esc(rgbToHex(a.color))+'"></i>' +
          '<span class="tpln">'+esc(a.label)+'</span>' +
          '<button class="ghostbtn tplbtn" onclick="mdOpenEdgeForm(\''+esc(a.abs_id)+'\')">Upraviť</button>' +
          '<button class="ghostbtn tpldel" title="Zmazať" onclick="mdDeleteEdge(\''+esc(a.abs_id)+'\')">✕</button>' +
          '</div>';
      });
      elist.innerHTML = h2 || '<div class="muted">Žiadne ABS pásky.</div>';
    }
  }

  // --- formulare (create: id=null; edit: id zaznamu) ---
  function mdOpenSheetForm(id){
    mdCloseForms();
    var s = id ? MD_CATALOG.sheets.find(function(x){ return x.material_id === id; }) : null;
    mdEditing = { kind: 'sheet', id: id };
    el('ms_decor').value = s ? (s.decor || '') : '';
    el('ms_type').value = s ? (s.type || '') : 'DTDL';
    el('ms_thickness').value = s ? s.thickness : '';
    el('ms_thickness').disabled = !!s;                       // hrubka = variant, pri edite nemenna
    el('ms_thick_hint').style.display = s ? '' : 'none';
    el('ms_grain').value = s ? (s.grain || 'none') : 'length';
    el('ms_price').value = s ? (s.price_per_m2 || 0) : '0';
    el('ms_color').value = rgbToHex(s ? s.color : null);
    el('ms_family').value = s ? (s.family || '') : '';
    el('ms_manufacturer').value = s ? (s.manufacturer || '') : '';
    // D-19: format platne — prazdne pri novom materiali = serverovy default 2800x2070
    var ss = s && s.sheet_size;
    el('ms_sheet_l').value = ss ? ss[0] : '';
    el('ms_sheet_w').value = ss ? ss[1] : '';
    el('mdSheetForm').style.display = '';
  }
  function mdOpenEdgeForm(id){
    mdCloseForms();
    var a = id ? MD_CATALOG.edges.find(function(x){ return x.abs_id === id; }) : null;
    mdEditing = { kind: 'edge', id: id };
    el('me_decor').value = a ? (a.decor || '') : '';
    el('me_thickness').value = a ? String(parseFloat(a.thickness).toFixed(1)) : '1.0';
    el('me_thickness').disabled = !!a; // hrubka = variant (ID _10/_20), pri edite nemenna
    el('me_price').value = a ? (a.price_per_bm || 0) : '0';
    el('me_color').value = rgbToHex(a ? a.color : null);
    el('mdEdgeForm').style.display = '';
  }
  function mdCloseForms(){
    mdEditing = null;
    if (el('mdSheetForm')) el('mdSheetForm').style.display = 'none';
    if (el('mdEdgeForm')) el('mdEdgeForm').style.display = 'none';
  }

  // D-19: parse rozmeru platne — cislo s ciarkou/bodkou, inak null (NIE 0).
  function mdSheetDim(v){
    var s = String(v == null ? '' : v).trim().replace(',', '.');
    if (!s) return null;
    var n = Number(s);
    return isFinite(n) && n > 0 ? n : NaN; // NaN = vyplnene ale neplatne
  }

  function mdSaveSheet(){
    var payload = {
      material_id: mdEditing && mdEditing.id ? mdEditing.id : null,
      catalog_rev: MD_REV,
      decor: el('ms_decor').value,
      type: el('ms_type').value,
      thickness: el('ms_thickness').value,
      grain: el('ms_grain').value,
      price_per_m2: el('ms_price').value,
      color: hexToRgb(el('ms_color').value),
      family: el('ms_family').value,
      manufacturer: el('ms_manufacturer').value
    };
    // D-19: format platne sa posiela LEN ako kompletny platny par; polovicny
    // alebo neplatny vstup zastavi ulozenie (ziadne tiche 0/reset — Codex F4).
    var sl = mdSheetDim(el('ms_sheet_l').value);
    var sw = mdSheetDim(el('ms_sheet_w').value);
    if ((sl === null) !== (sw === null) || (sl !== null && (isNaN(sl) || isNaN(sw)))){
      MD.setStatus('Formát platne: vyplň obe čísla (mm), alebo nechaj obe prázdne.', true); // GH P3: toto okno ma MD, nie NX
      return;
    }
    if (sl !== null) payload.sheet_size = [sl, sw];
    var fn = mdEditing && mdEditing.id ? 'update_sheet' : 'add_sheet';
    if (window.sketchup && sketchup[fn]) sketchup[fn](JSON.stringify(payload));
    mdCloseForms();
  }
  function mdSaveEdge(){
    var payload = {
      abs_id: mdEditing && mdEditing.id ? mdEditing.id : null,
      catalog_rev: MD_REV,
      decor: el('me_decor').value,
      thickness: el('me_thickness').value,
      price_per_bm: el('me_price').value,
      color: hexToRgb(el('me_color').value)
    };
    var fn = mdEditing && mdEditing.id ? 'update_edge' : 'add_edge';
    if (window.sketchup && sketchup[fn]) sketchup[fn](JSON.stringify(payload));
    mdCloseForms();
  }
  function mdDeleteSheet(id){
    if (window.sketchup && sketchup.delete_sheet) sketchup.delete_sheet(JSON.stringify({ material_id: id, catalog_rev: MD_REV }));
  }
  function mdDeleteEdge(id){
    if (window.sketchup && sketchup.delete_edge) sketchup.delete_edge(JSON.stringify({ abs_id: id, catalog_rev: MD_REV }));
  }

  window.MD = {
    init: function(data){
      MD_SHEETS = (data.materials && data.materials.sheets) ? data.materials.sheets : [];
      MD_CATALOG = data.catalog || { sheets: [], edges: [] };
      MD_PROTECTED = data.protected_ids || [];
      MD_REV = data.catalog_rev || '';
      el('mdline').textContent = 'V' + (data.version || '') + ' · skriniek v modeli: ' + (data.cabinets || 0);
      var p = data.project || {};
      fillSelect(el('md_body'), MD_SHEETS, p.default_material_id);
      fillSelect(el('md_front'), frontSheets(), p.default_front_material_id);
      fillSelect(el('md_back'), MD_SHEETS, p.default_back_material_id);
      mdRenderLists(); // rozpisany formular sa NECHAVA (mdEditing drzi stav)
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  function onProjMaterial(key, value){
    if (window.sketchup && sketchup.set_project_material)
      sketchup.set_project_material(JSON.stringify({ key: key, value: value }));
  }

  if (window.sketchup && sketchup.ready) sketchup.ready('');
