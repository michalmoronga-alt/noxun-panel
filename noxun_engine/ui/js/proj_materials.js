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

  // --- D-41 PR B: katalog zoskupeny podla DEKOROV -------------------------
  // Cista funkcia (Node test): catalog {sheets,edges} -> pole skupin
  // [{decor, manufacturer, color, sheets:[...], edges:[...]}] zoradene dekorom.
  // Dosky v skupine: typ+hrubka vzostupne; ABS: hrubka, potom sirka (legacy
  // bez sirky na konci — rovnaka logika ako D-41 sort v core.js).
  function groupCatalogByDecor(catalog){
    var map = {}, order = [];
    function grp(decor){
      var key = (decor == null || String(decor).trim() === '') ? '' : String(decor).trim();
      if (!map[key]){ map[key] = { decor: key, manufacturer: '', color: null, sheets: [], edges: [] }; order.push(key); }
      return map[key];
    }
    (catalog.sheets || []).forEach(function(s){
      var g = grp(s.decor);
      g.sheets.push(s);
      if (!g.manufacturer && s.manufacturer) g.manufacturer = s.manufacturer;
      if (!g.color && s.color) g.color = s.color;
    });
    (catalog.edges || []).forEach(function(a){
      var g = grp(a.decor);
      g.edges.push(a);
      if (!g.color && a.color) g.color = a.color;
    });
    order.sort(function(x, y){ return x === '' ? 1 : y === '' ? -1 : x.localeCompare(y); });
    return order.map(function(k){
      var g = map[k];
      g.sheets.sort(function(x, y){
        var t = String(x.type || '').localeCompare(String(y.type || ''));
        return t || (parseFloat(x.thickness) || 0) - (parseFloat(y.thickness) || 0);
      });
      g.edges.sort(function(x, y){
        var t = (parseFloat(x.thickness) || 0) - (parseFloat(y.thickness) || 0);
        if (t) return t;
        var xw = (x.width === null || x.width === undefined) ? null : parseFloat(x.width);
        var yw = (y.width === null || y.width === undefined) ? null : parseFloat(y.width);
        if (xw === null && yw === null) return 0;
        if (xw === null) return 1;
        if (yw === null) return -1;
        return xw - yw;
      });
      return g;
    });
  }
  function fmtNum(v){ var f = parseFloat(v); return (f === Math.round(f)) ? String(Math.round(f)) : String(f); }
  function sheetChipLabel(s){ return (s.type ? s.type + ' ' : '') + fmtNum(s.thickness); }
  function edgeChipLabel(a){
    return (a.width === null || a.width === undefined) ? fmtNum(a.thickness) + ' mm' : fmtNum(a.width) + '/' + fmtNum(a.thickness);
  }

  // D-42 (audit FIX 9): dekor matchne hladanie, ak sa dotaz najde v nazve,
  // vyrobcovi, ALEBO v kode/dodavatelovi KTOREHOKOLVEK jeho variantu (kod je
  // variantovy). Prazdny dotaz = vsetko.
  function mdMatchGroup(g, q){
    if (!q) return true;
    if (String(g.decor).toLowerCase().indexOf(q) >= 0) return true;
    if (String(g.manufacturer || '').toLowerCase().indexOf(q) >= 0) return true;
    var vs = g.sheets.concat(g.edges);
    for (var i = 0; i < vs.length; i++){
      if (String(vs[i].code || '').toLowerCase().indexOf(q) >= 0) return true;
      if (String(vs[i].supplier || '').toLowerCase().indexOf(q) >= 0) return true;
    }
    return false;
  }
  var mdRenaming = null; // dekor s otvorenym inline rename inputom
  function mdRenderLists(){
    var box = el('mdDecorList');
    if (!box) return;
    var q = (el('mdSearch') && el('mdSearch').value || '').trim().toLowerCase();
    var groups = groupCatalogByDecor(MD_CATALOG).filter(function(g){ return mdMatchGroup(g, q); });
    var html = '';
    groups.forEach(function(g){
      var name = g.decor === '' ? '(bez dekoru)' : g.decor;
      html += '<div class="mdcard">';
      html += '<div class="tplrow mdhead">' +
        '<i style="flex:0 0 14px;height:14px;border-radius:3px;background:' + esc(rgbToHex(g.color)) + '"></i>' +
        '<span class="tpln"><b>' + esc(name) + '</b>' + (g.manufacturer ? ' <span class="tplt">' + esc(g.manufacturer) + '</span>' : '') + '</span>' +
        (g.decor === '' ? '' :
          '<button class="ghostbtn tplbtn" onclick="mdOpenDecorForm(' + esc(JSON.stringify(g.decor)) + ')">+ variant</button>' +
          '<button class="ghostbtn tplbtn" onclick="mdManufacturerOpen(' + esc(JSON.stringify(g.decor)) + ')">Výrobca</button>' +
          '<button class="ghostbtn tplbtn" onclick="mdRenameOpen(' + esc(JSON.stringify(g.decor)) + ')">Premenovať</button>') +
        '</div>';
      if (mdManufacturing === g.decor){
        html += '<div class="tplrow"><input id="md_man_input" type="text" value="' + esc(g.manufacturer || '') + '" placeholder="Výrobca (napr. Egger)" style="flex:1">' +
          '<button class="primary tplbtn" onclick="mdManufacturerSave(' + esc(JSON.stringify(g.decor)) + ')">Uložiť</button>' +
          '<button class="ghostbtn tplbtn" onclick="mdManufacturerOpen(null)">Zrušiť</button></div>';
      }
      if (mdRenaming === g.decor){
        html += '<div class="tplrow"><input id="md_rename_input" type="text" value="' + esc(g.decor) + '" style="flex:1">' +
          '<button class="primary tplbtn" onclick="mdRenameSave(' + esc(JSON.stringify(g.decor)) + ')">Uložiť</button>' +
          '<button class="ghostbtn tplbtn" onclick="mdRenameOpen(null)">Zrušiť</button></div>';
      }
      if (g.sheets.length){
        html += '<div class="tplrow mdline"><span class="tplt">Dosky</span>';
        g.sheets.forEach(function(s){
          var prot = MD_PROTECTED.indexOf(s.material_id) >= 0;
          html += '<span class="mdchip">' +
            '<button class="ghostbtn" title="' + esc(s.label) + '" onclick="mdOpenSheetForm(\'' + esc(s.material_id) + '\')">' + esc(sheetChipLabel(s)) + '</button>' +
            (prot ? '<span class="tplt">predvoľba</span>'
                  : '<button class="ghostbtn tpldel" title="Zmazať ' + esc(s.label) + '" onclick="mdDeleteSheet(\'' + esc(s.material_id) + '\')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>') +
            '</span>';
        });
        html += '</div>';
      }
      if (g.edges.length){
        html += '<div class="tplrow mdline"><span class="tplt">ABS</span>';
        g.edges.forEach(function(a){
          html += '<span class="mdchip">' +
            '<button class="ghostbtn" title="' + esc(a.label) + '" onclick="mdOpenEdgeForm(\'' + esc(a.abs_id) + '\')">' + esc(edgeChipLabel(a)) + '</button>' +
            '<button class="ghostbtn tpldel" title="Zmazať ' + esc(a.label) + '" onclick="mdDeleteEdge(\'' + esc(a.abs_id) + '\')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>' +
            '</span>';
        });
        html += '</div>';
      }
      html += '</div>';
    });
    box.innerHTML = html || '<div class="muted">Katalóg je prázdny.</div>';
    var ri = el('md_rename_input');
    if (ri){ ri.focus(); ri.select(); }
  }
  function mdRenameOpen(decor){
    mdRenaming = decor; mdManufacturing = null;
    mdRenderLists();
  }
  function mdRenameSave(oldDecor){
    var input = el('md_rename_input');
    if (!input) return;
    if (window.sketchup && sketchup.rename_decor)
      sketchup.rename_decor(JSON.stringify({ old_decor: oldDecor, new_decor: input.value, catalog_rev: MD_REV }));
    mdRenaming = null;
  }
  // D-42 (audit FIX 7): vyrobca je vlastnost dekoru — inline editor nad celou skupinou.
  var mdManufacturing = null;
  function mdManufacturerOpen(decor){
    mdManufacturing = decor; mdRenaming = null;
    mdRenderLists();
    var mi = el('md_man_input'); if (mi){ mi.focus(); mi.select(); }
  }
  function mdManufacturerSave(decor){
    var input = el('md_man_input');
    if (!input) return;
    if (window.sketchup && sketchup.set_decor_manufacturer)
      sketchup.set_decor_manufacturer(JSON.stringify({ decor: decor, manufacturer: input.value, catalog_rev: MD_REV }));
    mdManufacturing = null;
  }

  // --- formulare (create: id=null; edit: id zaznamu) ---
  function mdOpenSheetForm(id){
    mdCloseForms();
    var s = id ? MD_CATALOG.sheets.find(function(x){ return x.material_id === id; }) : null;
    mdEditing = { kind: 'sheet', id: id };
    el('ms_decor').value = s ? (s.decor || '') : '';
    // D-41: dekor = identita skupiny — pri edite nemenny (server guard + disabled)
    el('ms_decor').disabled = !!s;
    el('ms_decor_hint').style.display = s ? '' : 'none';
    el('ms_type').value = s ? (s.type || '') : 'DTDL';
    el('ms_thickness').value = s ? s.thickness : '';
    el('ms_thickness').disabled = !!s;                       // hrubka = variant, pri edite nemenna
    el('ms_thick_hint').style.display = s ? '' : 'none';
    el('ms_grain').value = s ? (s.grain || 'none') : 'length';
    // D-42: cena rozlisuje nezadana (prazdne) vs 0 — nil/undefined => prazdny input.
    el('ms_price').value = mdPriceVal(s && s.price_per_m2);
    el('ms_code').value = s ? (s.code || '') : '';
    el('ms_supplier').value = s ? (s.supplier || '') : '';
    el('ms_color').value = rgbToHex(s ? s.color : null);
    el('ms_family').value = s ? (s.family || '') : '';
    el('ms_manufacturer').value = s ? (s.manufacturer || '') : '';
    // D-42: vyrobca je group-level — pri edite disabled + hint (mrekt cez kartu).
    el('ms_manufacturer').disabled = !!s;
    if (el('ms_man_hint')) el('ms_man_hint').style.display = s ? '' : 'none';
    // D-19: format platne — prazdne pri novom materiali = serverovy default 2800x2070
    var ss = s && s.sheet_size;
    el('ms_sheet_l').value = ss ? ss[0] : '';
    el('ms_sheet_w').value = ss ? ss[1] : '';
    el('mdSheetForm').style.display = '';
  }
  // D-42: prazdny string ak cena nie je zadana (nil/undefined), inak hodnota
  // (aj 0 = zadana nula). Rozlisuje "nezadana" od "0".
  function mdPriceVal(v){ return (v === null || v === undefined || v === '') ? '' : String(v); }
  function mdOpenEdgeForm(id){
    mdCloseForms();
    var a = id ? MD_CATALOG.edges.find(function(x){ return x.abs_id === id; }) : null;
    mdEditing = { kind: 'edge', id: id };
    el('me_decor').value = a ? (a.decor || '') : '';
    el('me_decor').disabled = !!a; // D-41: dekor pri edite nemenny
    el('me_decor_hint').style.display = a ? '' : 'none';
    // D-41: sirka = variant identity (vznika v batchi), iba informativne
    // zobrazenie — input je disabled v HTML, server ju drzi z existujuceho zaznamu.
    el('me_width').value = (a && a.width !== null && a.width !== undefined) ? fmtNum(a.width) : '';
    el('me_thickness').value = a ? String(parseFloat(a.thickness).toFixed(1)) : '1.0';
    el('me_thickness').disabled = !!a; // hrubka = variant (ID _10/_20), pri edite nemenna
    el('me_price').value = mdPriceVal(a && a.price_per_bm);
    el('me_code').value = a ? (a.code || '') : '';
    el('me_supplier').value = a ? (a.supplier || '') : '';
    el('me_color').value = rgbToHex(a ? a.color : null);
    el('mdEdgeForm').style.display = '';
  }
  // D-41: batch "Novy dekor" / "+ variant" (decor predvyplneny a zamknuty —
  // doplna sa DO skupiny; server preskoci existujuce varianty).
  function mdOpenDecorForm(decor){
    mdCloseForms();
    var g = decor ? groupCatalogByDecor(MD_CATALOG).find(function(x){ return x.decor === decor; }) : null;
    mdEditing = { kind: 'decor', id: decor };
    el('nd_decor').value = g ? g.decor : '';
    el('nd_decor').disabled = !!g;
    el('nd_manufacturer').value = g ? (g.manufacturer || '') : '';
    var firstSheet = g && g.sheets.length ? g.sheets[0] : null;
    el('nd_type').value = firstSheet ? (firstSheet.type || 'DTDL') : 'DTDL';
    el('nd_grain').value = firstSheet ? (firstSheet.grain || 'length') : 'length';
    el('nd_color').value = rgbToHex(g ? g.color : null);
    el('nd_ths').value = '';
    el('nd_abs').value = '';
    el('mdDecorForm').style.display = '';
  }
  function mdSaveDecorBatch(){
    var payload = {
      catalog_rev: MD_REV,
      decor: el('nd_decor').value,
      manufacturer: el('nd_manufacturer').value,
      type: el('nd_type').value,
      grain: el('nd_grain').value,
      color: hexToRgb(el('nd_color').value),
      thicknesses: el('nd_ths').value,
      abs_tokens: el('nd_abs').value
    };
    if (window.sketchup && sketchup.add_decor_batch) sketchup.add_decor_batch(JSON.stringify(payload));
    mdCloseForms();
  }
  function mdCloseForms(){
    mdEditing = null;
    mdDupAllow = null; // nove otvorenie formulara rusi potvrdenie duplicity
    if (el('mdSheetForm')) el('mdSheetForm').style.display = 'none';
    if (el('mdEdgeForm')) el('mdEdgeForm').style.display = 'none';
    if (el('mdDecorForm')) el('mdDecorForm').style.display = 'none';
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
      price_per_m2: el('ms_price').value,   // D-42: prazdne = nezadana (nie 0)
      code: el('ms_code').value,             // D-42 dodavatelsky kod
      supplier: el('ms_supplier').value,     // D-42 preferovany dodavatel
      color: hexToRgb(el('ms_color').value),
      family: el('ms_family').value,
      manufacturer: el('ms_manufacturer').value,
      allow_duplicate_code: mdDupAllow === 'sheet' // potvrdenie duplicitneho kodu (2. ulozenie)
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
    mdLastAttempt = { kind: 'sheet', payload: payload };
    var fn = mdEditing && mdEditing.id ? 'update_sheet' : 'add_sheet';
    if (window.sketchup && sketchup[fn]) sketchup[fn](JSON.stringify(payload));
    mdCloseForms();
  }
  function mdSaveEdge(){
    var payload = {
      abs_id: mdEditing && mdEditing.id ? mdEditing.id : null,
      catalog_rev: MD_REV,
      decor: el('me_decor').value,
      width: el('me_width').value,   // D-41: prazdna = univerzalna paska bez sirky
      thickness: el('me_thickness').value,
      price_per_bm: el('me_price').value,  // D-42: prazdne = nezadana (nie 0)
      code: el('me_code').value,
      supplier: el('me_supplier').value,
      color: hexToRgb(el('me_color').value),
      allow_duplicate_code: mdDupAllow === 'edge'
    };
    mdLastAttempt = { kind: 'edge', payload: payload };
    var fn = mdEditing && mdEditing.id ? 'update_edge' : 'add_edge';
    if (window.sketchup && sketchup[fn]) sketchup[fn](JSON.stringify(payload));
    mdCloseForms();
  }
  // D-42 (audit FIX 8): server pri duplicitnom kode odmietne 1. ulozenie a zavola
  // MD.flagDuplicateCode(kind); znovu otvorime formular s ROZPISANYMI hodnotami
  // (mdLastAttempt) a nastavime mdDupAllow — druhe Ulozit posle potvrdenie.
  var mdDupAllow = null;
  var mdLastAttempt = null;
  // Codex GH #74: obnov VSETKY polia z ulozeneho payloadu (nie len cast) — druhe
  // ulozenie po potvrdeni duplicity nesmie ticho ulozit default grain/farby/
  // rodiny/vyrobcu/formatu namiesto povodnej upravy.
  function mdReopenFromAttempt(){
    var at = mdLastAttempt; if (!at) return;
    var p = at.payload;
    if (at.kind === 'sheet'){
      mdOpenSheetForm(p.material_id || null);
      el('ms_decor').value = p.decor || ''; el('ms_type').value = p.type || '';
      el('ms_thickness').value = p.thickness || ''; el('ms_price').value = p.price_per_m2 || '';
      el('ms_code').value = p.code || ''; el('ms_supplier').value = p.supplier || '';
      el('ms_grain').value = p.grain || 'none'; el('ms_family').value = p.family || '';
      el('ms_manufacturer').value = p.manufacturer || '';
      if (p.color) el('ms_color').value = rgbToHex(p.color);
      el('ms_sheet_l').value = p.sheet_size ? p.sheet_size[0] : '';
      el('ms_sheet_w').value = p.sheet_size ? p.sheet_size[1] : '';
    } else {
      mdOpenEdgeForm(p.abs_id || null);
      el('me_decor').value = p.decor || ''; el('me_price').value = p.price_per_bm || '';
      el('me_code').value = p.code || ''; el('me_supplier').value = p.supplier || '';
      el('me_width').value = (p.width === null || p.width === undefined) ? '' : p.width;
      el('me_thickness').value = p.thickness || '1.0';
      if (p.color) el('me_color').value = rgbToHex(p.color);
    }
  }
  function mdDeleteSheet(id){
    if (window.sketchup && sketchup.delete_sheet) sketchup.delete_sheet(JSON.stringify({ material_id: id, catalog_rev: MD_REV }));
  }
  function mdDeleteEdge(id){
    if (window.sketchup && sketchup.delete_edge) sketchup.delete_edge(JSON.stringify({ abs_id: id, catalog_rev: MD_REV }));
  }

  // Top-level var v script tagu = window.MD v CEF; v Node require nepada na window.
  var MD_MODEL_GUID = ''; // D-42: identita modelu pre projektove predvolby (blocker 4)
  var MD = {
    init: function(data){
      MD_SHEETS = (data.materials && data.materials.sheets) ? data.materials.sheets : [];
      MD_CATALOG = data.catalog || { sheets: [], edges: [] };
      MD_PROTECTED = data.protected_ids || [];
      MD_REV = data.catalog_rev || '';
      MD_MODEL_GUID = data.model_guid || '';
      el('mdline').textContent = 'V' + (data.version || '') + ' · skriniek v modeli: ' + (data.cabinets || 0);
      var p = data.project || {};
      fillSelect(el('md_body'), MD_SHEETS, p.default_material_id);
      fillSelect(el('md_front'), frontSheets(), p.default_front_material_id);
      fillSelect(el('md_back'), MD_SHEETS, p.default_back_material_id);
      mdRenderLists(); // rozpisany formular sa NECHAVA (mdEditing drzi stav)
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; },
    // D-42 (audit FIX 8): server odmietol duplicitny kod — znovu otvor formular
    // s rozpisanymi hodnotami a nastav potvrdenie na druhe Ulozit.
    flagDuplicateCode: function(kind){ mdReopenFromAttempt(); mdDupAllow = kind; }
  };

  function onProjMaterial(key, value){
    // D-42 (audit BLOCKER 4): posli identitu modelu — server odmietne zapis do
    // ineho modelu, ak sa medzitym prepol dokument.
    if (window.sketchup && sketchup.set_project_material)
      sketchup.set_project_material(JSON.stringify({ key: key, value: value, model_guid: MD_MODEL_GUID }));
  }

  // D-41 Node testy (tests/js/test_decor_groups.js) — v CEF je module undefined.
  // Exportuju sa len CISTE funkcie (bez DOM); ready() sa vola len v CEF (window).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { groupCatalogByDecor: groupCatalogByDecor, sheetChipLabel: sheetChipLabel,
      edgeChipLabel: edgeChipLabel, mdMatchGroup: mdMatchGroup };
  }
  if (typeof window !== 'undefined' && window.sketchup && sketchup.ready) sketchup.ready('');
