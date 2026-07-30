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
  // 2A-1 (GH P1): klient hlasi SVOJU podporovanu schemu katalogu — KONSTANTU
  // tejto verzie kodu, NIE echo servera. UI v0.5.5 nema polia group_id ani
  // structure, takze po migracii na SCHEMA 2 ho server spravne odmietne
  // ("obnov okno"). 2A-4 (UI so strukturou) konstantu zdvihne na 2.
  var MD_CLIENT_SCHEMA = 1;
  // D-44: navrhy naseptavacov a navrhy formatu platne — obe STAVIA SERVER
  // (payload suggest/format_hints), JS ich len renderuje.
  var MD_SUGGEST = { manufacturers: [], types: [] };
  var MD_FORMAT_HINTS = {};
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
  // D-45: predvolba ciel uz NIE JE natvrdo 18/19 — celo prevezme katalogovu
  // hrubku sveho materialu (geometriu prisposobi server). Ostava rozsah dosky
  // (zrkadlo Ruby CabinetBuilder::THICKNESS_RANGE); hrubkovy guard drzi server.
  var MD_TH_RANGE = [6, 50];
  function frontSheets(){
    return MD_SHEETS.filter(function(s){
      var t = parseFloat(s.thickness);
      return !isNaN(t) && t >= MD_TH_RANGE[0]-0.001 && t <= MD_TH_RANGE[1]+0.001;
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
  // D-42 PR B (cista funkcia, Node test): rozdeli dekorove skupiny do SEKCII
  // mriezky. query aktivne => jedina plocha sekcia "Vysledky". Rezim 'man' =>
  // pas "Pouzite v projekte" (podla poctu dielcov v modeli, zostupne) + sekcie
  // podla vyrobcu (abecedne, "Bez vyrobcu" posledna — patri sem aj edge-only
  // dekor bez dosky a legacy "(bez dekoru)"). Rezim 'az' => plochy zoznam.
  function mdBuildSections(groups, used, mode, query){
    if (query) return [{ title: 'Výsledky', kind: 'flat', groups: groups }];
    if (mode !== 'man') return [{ title: '', kind: 'flat', groups: groups }];
    var out = [];
    used = used || {};
    var usedGroups = groups.filter(function(g){ return (used[g.decor] || 0) > 0; })
      .slice().sort(function(a, b){
        return (used[b.decor] || 0) - (used[a.decor] || 0) || a.decor.localeCompare(b.decor);
      });
    if (usedGroups.length) out.push({ title: 'Použité v projekte', kind: 'used', groups: usedGroups });
    var byMan = {}, order = [];
    groups.forEach(function(g){
      var key = g.decor === '' ? '' : (g.manufacturer || '');
      if (!byMan[key]){ byMan[key] = []; order.push(key); }
      byMan[key].push(g);
    });
    order.sort(function(x, y){ return x === '' ? 1 : y === '' ? -1 : x.localeCompare(y); });
    order.forEach(function(m){ out.push({ title: m || 'Bez výrobcu', kind: 'man', groups: byMan[m] }); });
    return out;
  }

  var mdRenaming = null;      // dekor s otvorenym inline rename inputom
  var mdView = null;          // null = mriezka | dekor = otvoreny detail (drill-in)
  function mdSearchInput(){
    mdView = null; // pisanie do hladania vzdy vracia do mriezky (vysledky)
    mdRenderLists();
  }
  function mdOpenDetail(decor){ mdView = decor; mdRenderLists(); }
  function mdCloseDetail(){ mdView = null; mdRenderLists(); }

  function mdRenderLists(){
    var box = el('mdDecorList');
    if (!box) return;
    var q = (el('mdSearch') && el('mdSearch').value || '').trim().toLowerCase();
    // detail drzi len existujuci dekor (po rename/zmazani spadne na mriezku)
    if (mdView !== null){
      var dg = groupCatalogByDecor(MD_CATALOG).find(function(g){ return g.decor === mdView; });
      if (dg){ box.innerHTML = mdDetailHtml(dg); mdFocusInline(); return; }
      mdView = null;
    }
    var groups = groupCatalogByDecor(MD_CATALOG).filter(function(g){ return mdMatchGroup(g, q); });
    var mode = (el('mdGroupMode') && el('mdGroupMode').value) || 'man';
    var sections = mdBuildSections(groups, MD_USED, mode, q);
    var html = '';
    sections.forEach(function(sec){
      if (sec.title){
        html += '<div class="mdsechead">' +
          (sec.kind === 'used' ? '<svg class="ic" aria-hidden="true"><use href="#i-check"/></svg>'
                               : '<svg class="ic" aria-hidden="true"><use href="#i-factory"/></svg>') +
          ' ' + esc(sec.title) + '</div>';
      }
      html += '<div class="mdgrid">';
      sec.groups.forEach(function(g){ html += mdTileHtml(g, sec.kind === 'used' ? (MD_USED[g.decor] || 0) : 0); });
      html += '</div>';
    });
    box.innerHTML = html || '<div class="muted">' + (q ? 'Nič sa nenašlo.' : 'Katalóg je prázdny.') + '</div>';
  }

  // Dlazdica dekoru: swatch + nazov + vyrobca + suhrn variantov (chips su len
  // prehlad — sprava variantov zije v detaile po rozkliku, audit BLOCKER 6).
  function mdTileHtml(g, usedCount){
    var name = g.decor === '' ? '(bez dekoru)' : g.decor;
    var chips = '';
    g.sheets.forEach(function(s){ chips += '<span class="vchip">' + esc(sheetChipLabel(s)) + '</span>'; });
    g.edges.forEach(function(a){ chips += '<span class="vchip vchip-abs">' + esc(edgeChipLabel(a)) + '</span>'; });
    return '<div class="mdtile" onclick="mdOpenDetail(' + esc(JSON.stringify(g.decor)) + ')">' +
      '<div class="mdtile-head">' +
      '<i class="mdsw" style="background:' + esc(rgbToHex(g.color)) + '"></i>' +
      '<span class="mdtile-name"><b>' + esc(name) + '</b>' +
      '<span class="mans">' + esc(g.manufacturer || 'vlastný') + '</span></span>' +
      (usedCount ? '<span class="mdused">' + usedCount + '×</span>' : '') +
      '</div><div class="mdtile-chips">' + (chips || '<span class="muted">bez variantov</span>') + '</div></div>';
  }

  // Detail dekoru (drill-in): hlavicka s akciami skupiny + riadky variantov
  // (rozmer · kod · cena · dodavatel) s Upravit/zmazat — EXISTUJUCE formulare
  // (audit BLOCKER 6: sprava variantov ostava plne dostupna).
  function mdDetailHtml(g){
    var name = g.decor === '' ? '(bez dekoru)' : g.decor;
    var h = '<div class="mdcard mdet">';
    h += '<div class="tplrow mdhead">' +
      '<button class="ghostbtn tplbtn" onclick="mdCloseDetail()" title="Späť na katalóg" aria-label="Späť na katalóg"><svg class="ic" aria-hidden="true"><use href="#i-arrow-left"/></svg></button>' +
      '<i class="mdsw mdsw-lg" style="background:' + esc(rgbToHex(g.color)) + '"></i>' +
      '<span class="tpln"><b>' + esc(name) + '</b>' + (g.manufacturer ? ' <span class="tplt">' + esc(g.manufacturer) + '</span>' : '') + '</span>' +
      (g.decor === '' ? '' :
        '<button class="ghostbtn tplbtn" onclick="mdOpenDecorForm(' + esc(JSON.stringify(g.decor)) + ')">+ variant</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdManufacturerOpen(' + esc(JSON.stringify(g.decor)) + ')">Výrobca</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdRenameOpen(' + esc(JSON.stringify(g.decor)) + ')">Premenovať</button>') +
      '</div>';
    if (mdManufacturing === g.decor){
      // D-44: naseptavac (datalist mdManList) + VLASTNE tlacidlo na vymazanie —
      // prazdny input uz vyrobcu nezmaze (server odmietne bez flagu, audit F9).
      h += '<div class="tplrow"><input id="md_man_input" type="text" list="mdManList" value="' + esc(g.manufacturer || '') + '" placeholder="Výrobca (napr. Egger)" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdManufacturerSave(' + esc(JSON.stringify(g.decor)) + ')">Uložiť</button>' +
        (g.manufacturer ? '<button class="ghostbtn tpldel" title="Zmazať výrobcu" aria-label="Zmazať výrobcu" onclick="mdManufacturerClear(' + esc(JSON.stringify(g.decor)) + ')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>' : '') +
        '<button class="ghostbtn tplbtn" onclick="mdManufacturerOpen(null)">Zrušiť</button></div>';
    }
    if (mdRenaming === g.decor){
      h += '<div class="tplrow"><input id="md_rename_input" type="text" value="' + esc(g.decor) + '" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdRenameSave(' + esc(JSON.stringify(g.decor)) + ')">Uložiť</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdRenameOpen(null)">Zrušiť</button></div>';
    }
    h += '<div class="mdsec">Dosky</div>';
    h += '<div class="mdvhead"><span class="mdvdim"></span><span class="mdvi">Kód</span><span class="mdvi mdvp">€/m²</span><span class="mdvi">Dodávateľ</span><span class="mdvact"></span></div>';
    if (g.sheets.length){
      g.sheets.forEach(function(s){
        var prot = MD_PROTECTED.indexOf(s.material_id) >= 0;
        h += mdVariantRow('sheet', s.material_id, s.row_rev, sheetChipLabel(s),
          s.code, s.price_per_m2, s.supplier, s.label,
          'mdOpenSheetForm(\'' + esc(s.material_id) + '\')',
          prot ? null : 'mdDeleteSheet(\'' + esc(s.material_id) + '\')', prot);
      });
    } else { h += '<div class="muted">žiadne dosky</div>'; }
    h += '<div class="mdsec">ABS pásky</div>';
    h += '<div class="mdvhead"><span class="mdvdim"></span><span class="mdvi">Kód</span><span class="mdvi mdvp">€/bm</span><span class="mdvi">Dodávateľ</span><span class="mdvact"></span></div>';
    if (g.edges.length){
      g.edges.forEach(function(a){
        h += mdVariantRow('edge', a.abs_id, a.row_rev, edgeChipLabel(a),
          a.code, a.price_per_bm, a.supplier, a.label,
          'mdOpenEdgeForm(\'' + esc(a.abs_id) + '\')',
          'mdDeleteEdge(\'' + esc(a.abs_id) + '\')', false);
      });
    } else { h += '<div class="muted">žiadne ABS pásky</div>'; }
    h += '</div>';
    return h;
  }

  // Riadok variantu v detaile — kod/cena/dodavatel su EDITOVATELNE bunky
  // (D-42 PR C, audit BLOCKER 1): flush na blur/Enter posle PATCH len meneneho
  // pola + row_rev baseline. Farba/format/smer ostavaju vo formulari (ceruzka).
  // Cena NEZADANA (nil) = prazdna bunka s placeholderom "—" (FIX 11).
  function mdCellHtml(kind, id, rev, field, value, extraCls, ph){
    var v = (value === null || value === undefined) ? '' : String(value);
    return '<input class="mdcell ' + extraCls + '" type="text" value="' + esc(v) + '" placeholder="' + ph + '"' +
      ' data-kind="' + kind + '" data-id="' + esc(id) + '" data-field="' + field + '" data-rev="' + esc(rev || '') + '"' +
      ' data-orig="' + esc(v) + '" onblur="mdCellFlush(this)" onkeydown="mdCellKey(event, this)">';
  }
  function mdVariantRow(kind, id, rev, dim, code, price, supplier, title, editCall, delCall, prot){
    var priceField = kind === 'edge' ? 'price_per_bm' : 'price_per_m2';
    return '<div class="mdvrow" title="' + esc(title || '') + '">' +
      '<span class="mdvdim">' + esc(dim) + '</span>' +
      mdCellHtml(kind, id, rev, 'code', code, '', 'kód') +
      mdCellHtml(kind, id, rev, priceField, price, 'mdvp', '—') +
      mdCellHtml(kind, id, rev, 'supplier', supplier, '', 'dodávateľ') +
      '<span class="mdvact">' +
      '<button class="ghostbtn tplbtn" title="Ďalšie vlastnosti (farba, formát…)" aria-label="Ďalšie vlastnosti" onclick="' + editCall + '"><svg class="ic" aria-hidden="true"><use href="#i-pencil"/></svg></button>' +
      (prot ? '<span class="tplt">predvoľba</span>'
            : '<button class="ghostbtn tpldel" title="Zmazať" aria-label="Zmazať" onclick="' + delCall + '"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>') +
      '</span></div>';
  }

  // Flush bunky: nezmenena hodnota = ziadny callback; inak PATCH {pole: hodnota}.
  // mdPatchDup drzi (kind,id) po serverovom code_conflict — dalsi flush TEJ ISTEJ
  // bunky posle allow_duplicate_code (2. potvrdenie, vzor formulara).
  var mdPatchDup = null;
  function mdCellKey(ev, inp){
    if (ev.key === 'Enter'){ ev.preventDefault(); inp.blur(); }
    else if (ev.key === 'Escape'){ inp.value = inp.getAttribute('data-orig') || ''; inp.blur(); }
  }
  function mdCellFlush(inp){
    var value = inp.value;
    if (value === (inp.getAttribute('data-orig') || '')) return;
    var kind = inp.getAttribute('data-kind');
    var id = inp.getAttribute('data-id');
    var patch = {};
    patch[inp.getAttribute('data-field')] = value;
    var payload = {
      id: id, patch: patch, row_rev: inp.getAttribute('data-rev') || '',
      catalog_schema: MD_CLIENT_SCHEMA, // 2A-1: row_rev strazi riadok, schema strazi format katalogu
      allow_duplicate_code: !!(mdPatchDup && mdPatchDup.kind === kind && mdPatchDup.id === id)
    };
    var fn = kind === 'edge' ? 'patch_edge' : 'patch_sheet';
    if (window.sketchup && sketchup[fn]) sketchup[fn](JSON.stringify(payload));
  }

  function mdFocusInline(){
    var ri = el('md_rename_input');
    if (ri){ ri.focus(); ri.select(); return; }
    var mi = el('md_man_input');
    if (mi){ mi.focus(); mi.select(); }
  }
  function mdRenameOpen(decor){
    mdRenaming = decor; mdManufacturing = null;
    mdRenderLists();
  }
  function mdRenameSave(oldDecor){
    var input = el('md_rename_input');
    if (!input) return;
    if (window.sketchup && sketchup.rename_decor)
      sketchup.rename_decor(JSON.stringify({ old_decor: oldDecor, new_decor: input.value, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
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
      sketchup.set_decor_manufacturer(JSON.stringify({ decor: decor, manufacturer: input.value, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    mdManufacturing = null;
  }
  // D-44 (audit F9): vymazanie vyrobcu CELEJ skupiny je vedomy krok s flagom —
  // prazdne pole samo o sebe je omyl a server ho odmietne.
  function mdManufacturerClear(decor){
    if (window.sketchup && sketchup.set_decor_manufacturer)
      sketchup.set_decor_manufacturer(JSON.stringify({ decor: decor, manufacturer: '',
        clear_manufacturer: true, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
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
  // D-42 PR C: preset cipy = strukturovane varianty (BLOCKER 5). Toggle .on;
  // payload sa sklada z aktivnych cipov (sheet_variants/edge_variants) + textov.
  // D-44 (audit F5): toggle bezi cez STABILNY data-key (nie textContent — popis
  // cipu sa smie zmenit, kluc nie) a format platne sa edituje v pruhu POD cipmi,
  // nie v klikacej ploche cipu (klik do inputu nesmie cip preplo).
  var mdFmt = {};  // {kluc_cipu: {l, w, auto}} — auto = hodnota z navrhu, nie od pouzivatela

  function mdChipKey(chip){ return chip.getAttribute('data-key') || chip.textContent.trim(); }
  // Efektivny typ cipu: vlastny data-type (PD 38) alebo spolocny typ formulara.
  function mdChipType(chip){
    var t = chip.getAttribute('data-type');
    if (t && t.trim()) return t.trim();
    return ((el('nd_type') && el('nd_type').value) || '').trim();
  }
  function mdActiveChips(rid){
    var row = el(rid), out = [];
    if (!row) return out;
    var cs = row.querySelectorAll('.mdpc.on');
    for (var i = 0; i < cs.length; i++) out.push(cs[i]);
    return out;
  }
  function mdActiveSheetChips(){
    return mdActiveChips('nd_sheet_chips').map(function(c){
      return { key: mdChipKey(c), type: c.getAttribute('data-type') || '',
               th: c.getAttribute('data-th'), label: c.textContent.trim(),
               hintType: mdChipType(c) };
    });
  }
  function mdActiveEdgeChips(){
    return mdActiveChips('nd_edge_chips').map(function(c){
      return { key: mdChipKey(c), width: c.getAttribute('data-w'), thickness: c.getAttribute('data-t') };
    });
  }
  function mdBindChips(){
    ['nd_sheet_chips', 'nd_edge_chips'].forEach(function(rid){
      var row = el(rid);
      if (!row || row.getAttribute('data-bound')) return;
      row.setAttribute('data-bound', '1');
      row.addEventListener('click', function(ev){
        var c = ev.target.closest ? ev.target.closest('.mdpc') : null;
        if (!c) return;
        c.classList.toggle('on');
        if (rid !== 'nd_sheet_chips') return;
        if (c.classList.contains('on')) mdFmtPrefill(mdChipKey(c), mdChipType(c));
        mdRenderFmtRow();
      });
    });
  }
  function mdChipsSet(rid, keys){
    var row = el(rid);
    if (!row) return;
    var cs = row.querySelectorAll('.mdpc');
    for (var i = 0; i < cs.length; i++) cs[i].classList.toggle('on', keys.indexOf(mdChipKey(cs[i])) >= 0);
  }

  // --- D-44: format platne pri novych variantoch ---------------------------
  // Navrh podla typu je AUTORITA SERVERA (TYPE_FORMAT_HINTS v payloade) — JS ho
  // len predvyplni do VIDITELNEHO pola (viditelne = potvrdene odoslanim).
  // Vrati [dlzka, sirka] alebo null (PD aj neznamy typ = vedome prazdne).
  function mdFormatHint(type, hints){
    var t = String(type == null ? '' : type).trim().toUpperCase();
    if (!t || !hints) return null;
    for (var k in hints){
      if (!Object.prototype.hasOwnProperty.call(hints, k)) continue;
      if (String(k).trim().toUpperCase() !== t) continue;
      var v = hints[k];
      return (v && v.length === 2) ? [v[0], v[1]] : null;
    }
    return null;
  }
  function mdFmtStr(v){ return (v === null || v === undefined) ? '' : String(v); }
  function mdFmtState(key){
    if (!mdFmt[key]) mdFmt[key] = { l: '', w: '', auto: true };
    return mdFmt[key];
  }
  // Predvyplni format cipu z navrhu — LEN ak ho pouzivatel sam nezadal (auto).
  function mdFmtPrefill(key, type){
    var f = mdFmtState(key);
    if (!f.auto) return;
    var hint = mdFormatHint(type, MD_FORMAT_HINTS);
    f.l = hint ? mdFmtStr(hint[0]) : '';
    f.w = hint ? mdFmtStr(hint[1]) : '';
  }
  function mdFmtInput(inp){
    var f = mdFmtState(inp.getAttribute('data-key'));
    f[inp.getAttribute('data-dim')] = inp.value;
    f.auto = false; // rucna hodnota — navrh ju uz neprepise
  }
  // GH P2: do zapamatanej sady iba MANUALNE formaty — auto-navrh sa pri obnove
  // deterministicky dopocita z hintov (mdFmtPrefill), takze ulozeny auto-format
  // by po zmene typu (DTDL -> PD) chybne prezil ako "rucny".
  function mdManualFormats(chips, fmtMap){
    var out = {};
    (chips || []).forEach(function(c){
      var f = fmtMap ? fmtMap[c.key] : null;
      if (f && !f.auto && (f.l || f.w)) out[c.key] = { l: f.l, w: f.w };
    });
    return out;
  }
  // Zmena spolocneho typu prepocita NAVRHY (PD navrh nema, takze DTDL -> PD
  // pole vyprazdni — inak by odoslal 2800x2070 pre pracovnu dosku).
  function mdTypeChanged(){
    mdActiveSheetChips().forEach(function(c){ if (!c.type) mdFmtPrefill(c.key, c.hintType); });
    mdRenderFmtRow();
  }
  // Kompaktny pruh: 1 riadok, LEN prave aktivne cipy (viac cipov = mini-polia
  // vedla seba so skratkou typu). Ziadny aktivny cip = riadok je skryty.
  function mdRenderFmtRow(){
    var row = el('nd_fmt_row'), box = el('nd_fmt_fields');
    if (!row || !box) return;
    var chips = mdActiveSheetChips();
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var f = mdFmtState(c.key);
      var lbl = c.type ? c.label : ((c.hintType ? c.hintType + ' ' : '') + c.label);
      html += '<span class="mdfmt">' +
        '<i>' + esc(lbl) + '</i>' +
        '<input type="text" class="fmtdim" data-key="' + esc(c.key) + '" data-dim="l" value="' + esc(f.l) + '"' +
        ' placeholder="dĺžka" title="Formát platne — dĺžka (mm)" oninput="mdFmtInput(this)">' +
        '<span class="sheetx">×</span>' +
        '<input type="text" class="fmtdim" data-key="' + esc(c.key) + '" data-dim="w" value="' + esc(f.w) + '"' +
        ' placeholder="šírka" title="Formát platne — šírka (mm)" oninput="mdFmtInput(this)">' +
        '</span>';
    });
    box.innerHTML = html;
    row.style.display = '';
  }
  // D-44 (cista funkcia, Node test): aktivne cipy + stav formatov -> payload
  // sheet_variants. Format ide LEN ako KOMPLETNY par; polovicny/neplatny vstup
  // zastavi odoslanie s hlaskou (vzor mdSaveSheet) — server ma vlastnu striktnu
  // kontrolu, toto je len rychla spatna vazba.
  function mdBuildSheetVariants(chips, fmt){
    var out = [], err = null;
    (chips || []).forEach(function(c){
      if (err) return;
      var f = (fmt && fmt[c.key]) || {};
      var l = mdSheetDim(f.l), w = mdSheetDim(f.w);
      if ((l === null) !== (w === null) || (l !== null && (isNaN(l) || isNaN(w)))){
        err = 'Formát platne pre ' + (c.label || c.key) + ': vyplň obe čísla (mm), alebo nechaj obe prázdne.';
        return;
      }
      var v = { type: c.type || '', thickness: c.th };
      if (l !== null) v.sheet_size = [l, w];
      out.push(v);
    });
    return { variants: out, error: err };
  }

  // Posledna pouzita sada (Michal: "zapamatat poslednu sadu") — localStorage je
  // len UX pohodlie (try/catch: CEF/file: ho moze zakazat), autorita je server.
  // D-44: verziovany format (schema 2 + formaty). Stara sada (v1) formaty nemala
  // a kluce v nej boli LABELY cipov — data-key je s labelmi zamerne zhodny,
  // takze migracia = prevzatie klucov BEZ formatov (ziadne rozbitie, ziadny
  // vymysleny format).
  var MD_SET_KEY = 'nx_decor_last_set_v2';
  var MD_SET_KEY_V1 = 'nx_decor_last_set';
  function mdMigrateLastSet(v1){
    if (!v1 || typeof v1 !== 'object') return null;
    return { schema: 2,
             sheet_keys: Array.isArray(v1.sheet_keys) ? v1.sheet_keys : [],
             edge_keys: Array.isArray(v1.edge_keys) ? v1.edge_keys : [],
             ths: typeof v1.ths === 'string' ? v1.ths : '',
             abs: typeof v1.abs === 'string' ? v1.abs : '',
             formats: {} };
  }
  function mdLoadLastSet(){
    try {
      var raw = localStorage.getItem(MD_SET_KEY);
      if (raw){
        var s = JSON.parse(raw);
        return (s && s.schema === 2) ? s : mdMigrateLastSet(s);
      }
      var old = localStorage.getItem(MD_SET_KEY_V1);
      return old ? mdMigrateLastSet(JSON.parse(old)) : null;
    } catch (e2) { return null; }
  }
  function mdStoreLastSet(set){
    try { localStorage.setItem(MD_SET_KEY, JSON.stringify(set)); } catch (e2) { /* bez perzistencie */ }
  }
  function mdOpenDecorForm(decor){
    mdCloseForms();
    mdBindChips();
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
    // NOVY dekor = predvyplnit poslednou sadou; "+ variant" zacina prazdny
    // (doplna sa konkretna vec do existujucej skupiny).
    mdFmt = {};
    var last = decor ? null : mdLoadLastSet();
    mdChipsSet('nd_sheet_chips', last && last.sheet_keys ? last.sheet_keys : []);
    mdChipsSet('nd_edge_chips', last && last.edge_keys ? last.edge_keys : []);
    if (last && !decor){
      el('nd_ths').value = last.ths || '';
      el('nd_abs').value = last.abs || '';
      // Ulozeny format = vedome zadany (auto=false) — navrh ho neprepise.
      var fmts = (last.formats && typeof last.formats === 'object') ? last.formats : {};
      Object.keys(fmts).forEach(function(k){
        var f = fmts[k] || {};
        mdFmt[k] = { l: mdFmtStr(f.l), w: mdFmtStr(f.w), auto: false };
      });
    }
    // Cipy bez ulozeneho formatu dostanu NAVRH podla typu (viditelne v poli).
    mdActiveSheetChips().forEach(function(c){ mdFmtPrefill(c.key, c.hintType); });
    mdRenderFmtRow();
    el('mdDecorForm').style.display = '';
  }
  function mdSaveDecorBatch(){
    var sheetChips = mdActiveSheetChips();
    var edgeChips = mdActiveEdgeChips();
    var built = mdBuildSheetVariants(sheetChips, mdFmt);
    // Polovicny format = formular OSTAVA otvoreny (hodnoty sa nestratia).
    if (built.error){ MD.setStatus(built.error, true); return; }
    var payload = {
      batch_schema: 2, // D-44: klient posiela format platne a znasa striktny parse
      catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
      decor: el('nd_decor').value,
      manufacturer: el('nd_manufacturer').value,
      type: el('nd_type').value,
      grain: el('nd_grain').value,
      color: hexToRgb(el('nd_color').value),
      thicknesses: el('nd_ths').value,
      abs_tokens: el('nd_abs').value,
      sheet_variants: built.variants,
      edge_variants: edgeChips.map(function(c){ return { width: c.width, thickness: c.thickness }; })
    };
    if (!mdEditing || !mdEditing.id){
      var formats = mdManualFormats(sheetChips, mdFmt);
      mdStoreLastSet({ schema: 2, sheet_keys: sheetChips.map(function(c){ return c.key; }),
                       edge_keys: edgeChips.map(function(c){ return c.key; }),
                       ths: el('nd_ths').value, abs: el('nd_abs').value, formats: formats });
    }
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
      catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
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
    // GH P2: edit s OBOMA prazdnymi polami = vedome VYMAZANIE ulozeneho formatu
    // (server inak merge-om stary par podrzi a "bez formatu" sa neda dosiahnut).
    else if (mdEditing && mdEditing.id) payload.clear_sheet_size = true;
    mdLastAttempt = { kind: 'sheet', payload: payload };
    var fn = mdEditing && mdEditing.id ? 'update_sheet' : 'add_sheet';
    if (window.sketchup && sketchup[fn]) sketchup[fn](JSON.stringify(payload));
    mdCloseForms();
  }
  function mdSaveEdge(){
    var payload = {
      abs_id: mdEditing && mdEditing.id ? mdEditing.id : null,
      catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
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
    if (window.sketchup && sketchup.delete_sheet) sketchup.delete_sheet(JSON.stringify({ material_id: id, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
  }
  function mdDeleteEdge(id){
    if (window.sketchup && sketchup.delete_edge) sketchup.delete_edge(JSON.stringify({ abs_id: id, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
  }

  // Top-level var v script tagu = window.MD v CEF; v Node require nepada na window.
  var MD_MODEL_GUID = ''; // D-42: identita modelu pre projektove predvolby (blocker 4)
  var MD_USED = {};       // D-42 PR B: {dekor => pocet dielcov v aktivnom modeli}
  var MD_PROJECT = {};    // posledne projektove predvolby (pre refill selectov pri setCatalog)
  // Spolocna katalogova cast init/setCatalog (audit FIX 13: katalogove echo
  // NEnesie modelovy kontext — ten ostava z posledneho MD.init).
  // D-42 PR C (audit BLOCKER 1): re-render NESMIE znicit aktivnu bunku — pred
  // renderom sa zachyti fokus + ROZPISANA (dirty) hodnota a po renderi obnovi.
  // Cista bunka (value == orig) dostane cerstvu hodnotu z payloadu, dirty drzi
  // pouzivatelov text; server aj tak strazi row_rev.
  // D-44: naplni <datalist> navrhmi zo servera (poradie aj dedup su serverove).
  function mdFillDatalist(id, items){
    var dl = el(id);
    if (!dl) return;
    var html = '';
    (items || []).forEach(function(v){ html += '<option value="' + esc(v) + '"></option>'; });
    dl.innerHTML = html;
  }

  // --- D-46: potvrdzovacia lista projektovej predvolby KORPUSU ------------
  // Projektove selecty nemaju Ulozit (onchange = zapis), takze suhlas so zmenou
  // hrubky dediacich skriniek pyta server: vrati ponuku, JS vrati select na
  // SKUTOCNY default a pod nim ukaze 1-riadkovu listu Potvrdiť/Zrušiť.
  // Autorita je server — pending sa mu posiela CELY spat a on ho znovu overi.
  var MD_PENDING = null;

  // Cista funkcia (Node test): kluc projektovej predvolby -> id selectu.
  function mdProjectSelectId(key){
    return { default_material_id: 'md_body', default_front_material_id: 'md_front',
             default_back_material_id: 'md_back' }[String(key || '')] || null;
  }
  // Cista funkcia (Node test): payload potvrdenia. Nesie CELY pending kontrakt
  // spat (key/value z NEHO, nie z DOM selectu — ten je uz vrateny na default).
  function mdConfirmPayload(pending, guid){
    if (!pending || !pending.key) return null;
    return { key: pending.key, value: pending.value, model_guid: guid, confirm: pending };
  }

  function mdSetProjectSelect(key, id){
    var sel = el(mdProjectSelectId(key)); // programovy zapis onchange NEspusti
    if (sel && id) sel.value = id;
  }
  function mdClearPending(){
    MD_PENDING = null;
    var bar = el('mdConfirmBar');
    if (bar) bar.style.display = 'none';
  }
  function mdConfirmProject(){
    var payload = mdConfirmPayload(MD_PENDING, MD_MODEL_GUID);
    mdClearPending();
    if (payload && window.sketchup && sketchup.set_project_material)
      sketchup.set_project_material(JSON.stringify(payload));
  }
  function mdCancelProject(){
    mdClearPending();
    MD.setStatus('Zmena predvoľby zrušená — nič sa nezmenilo.');
  }

  function mdApplyCatalog(data){
    mdClearPending(); // refresh (init aj katalogove echo) rusi nepotvrdenu ponuku
    MD_SHEETS = (data.materials && data.materials.sheets) ? data.materials.sheets : [];
    MD_CATALOG = data.catalog || { sheets: [], edges: [] };
    MD_PROTECTED = data.protected_ids || [];
    MD_REV = data.catalog_rev || '';
    // GH P1: serverova schema sa NEpreberá — klient posiela vlastnu
    // MD_CLIENT_SCHEMA konstantu (echo servera by po migracii falosne
    // "povysilo" stare okno na SCHEMA 2 bez novych poli).
    // D-44: naseptavace + navrhy formatu — jedna autorita (server), JS renderuje.
    MD_SUGGEST = data.suggest || { manufacturers: [], types: [] };
    MD_FORMAT_HINTS = data.format_hints || {};
    mdFillDatalist('mdManList', MD_SUGGEST.manufacturers);
    mdFillDatalist('mdTypeList', MD_SUGGEST.types);
    mdPatchDup = null; // uspesny zapis/refresh rusi pending potvrdenie duplicity
    var keep = null;
    var ae = document.activeElement;
    if (ae && ae.classList && ae.classList.contains('mdcell')){
      keep = { kind: ae.getAttribute('data-kind'), id: ae.getAttribute('data-id'),
               field: ae.getAttribute('data-field'), value: ae.value,
               dirty: ae.value !== (ae.getAttribute('data-orig') || ''),
               rev: ae.getAttribute('data-rev') || '', orig: ae.getAttribute('data-orig') || '',
               s: ae.selectionStart, e: ae.selectionEnd };
    }
    fillSelect(el('md_body'), MD_SHEETS, MD_PROJECT.default_material_id);
    fillSelect(el('md_front'), frontSheets(), MD_PROJECT.default_front_material_id);
    fillSelect(el('md_back'), MD_SHEETS, MD_PROJECT.default_back_material_id);
    mdRenderLists(); // rozpisany formular sa NECHAVA (mdEditing drzi stav)
    if (keep){
      var sel = '.mdcell[data-kind="' + keep.kind + '"][data-id="' + keep.id + '"][data-field="' + keep.field + '"]';
      var inp = document.querySelector(sel);
      if (inp){
        if (keep.dirty){
          // Codex GH #76: dirty bunka si drzi POVODNY baseline (rev + orig) —
          // cerstvy data-rev z refreshu by jej blur nechal prepisat zmenu ineho
          // okna bez konfliktu. So starym rev server pri cudzej zmene vrati
          // :conflict a hodnoty sa obnovia (ziadny tichy prepis).
          inp.value = keep.value;
          inp.setAttribute('data-rev', keep.rev);
          inp.setAttribute('data-orig', keep.orig);
        }
        inp.focus();
        try { inp.setSelectionRange(keep.s, keep.e); } catch (e2) { /* select nepodporene */ }
      }
    }
  }
  var MD = {
    init: function(data){
      MD_MODEL_GUID = data.model_guid || '';
      MD_USED = data.used || {};
      MD_PROJECT = data.project || {};
      el('mdline').textContent = 'V' + (data.version || '') + ' · skriniek v modeli: ' + (data.cabinets || 0);
      mdApplyCatalog(data);
    },
    // D-42 (audit FIX 13): echo po zapise do katalogu — bez scanu modelu,
    // modelovy kontext (predvolby/pouzite/guid) ostava.
    setCatalog: function(data){ mdApplyCatalog(data); },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; },
    // D-42 (audit FIX 8): server odmietol duplicitny kod — znovu otvor formular
    // s rozpisanymi hodnotami a nastav potvrdenie na druhe Ulozit.
    flagDuplicateCode: function(kind){ mdReopenFromAttempt(); mdDupAllow = kind; },
    // D-42 PR C: duplicitny kod z inline bunky — bunka OSTAVA rozpisana (server
    // neposlal refresh), dalsi flush tej istej bunky posle potvrdenie.
    flagDuplicatePatch: function(kind, id){ mdPatchDup = { kind: kind, id: id }; },
    // D-46: server pyta potvrdenie zmeny predvolby korpusu. Select sa VRATI na
    // skutocny default (nesmie vizualne zostat na nepotvrdenom materiali) a pod
    // nim sa ukaze lista s presnym rozpisom.
    confirmDefault: function(p){
      MD_PENDING = p.pending || null;
      mdSetProjectSelect(p.key, p.current);
      var bar = el('mdConfirmBar'), txt = el('mdConfirmText');
      if (txt) txt.textContent = p.message || '';
      if (bar) bar.style.display = MD_PENDING ? '' : 'none';
      MD.setStatus(p.message || '', false);
    },
    // D-46: odmietnutie (blokujuce dielce) — select spat na default, ziadna ponuka.
    resetProject: function(p){ mdClearPending(); mdSetProjectSelect(p.key, p.current); }
  };

  function onProjMaterial(key, value){
    // D-46: iny vyber v KTOROMKOLVEK projektovom selecte zahadzuje nepotvrdenu
    // ponuku — suhlas vzdy patri prave jednej zmene.
    mdClearPending();
    // D-42 (audit BLOCKER 4): posli identitu modelu — server odmietne zapis do
    // ineho modelu, ak sa medzitym prepol dokument.
    if (window.sketchup && sketchup.set_project_material)
      sketchup.set_project_material(JSON.stringify({ key: key, value: value, model_guid: MD_MODEL_GUID }));
  }

  // D-41 Node testy (tests/js/test_decor_groups.js) — v CEF je module undefined.
  // Exportuju sa len CISTE funkcie (bez DOM); ready() sa vola len v CEF (window).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { groupCatalogByDecor: groupCatalogByDecor, sheetChipLabel: sheetChipLabel,
      edgeChipLabel: edgeChipLabel, mdMatchGroup: mdMatchGroup, mdBuildSections: mdBuildSections,
      // D-44 (tests/js/test_decor_formats.js) — ciste funkcie bez DOM
      mdFormatHint: mdFormatHint, mdBuildSheetVariants: mdBuildSheetVariants,
      mdMigrateLastSet: mdMigrateLastSet, mdSheetDim: mdSheetDim,
      mdManualFormats: mdManualFormats,
      // D-46 (tests/js/test_proj_confirm.js) — ciste funkcie listy bez DOM
      mdProjectSelectId: mdProjectSelectId, mdConfirmPayload: mdConfirmPayload };
  }
  if (typeof window !== 'undefined' && window.sketchup && sketchup.ready) sketchup.ready('');
