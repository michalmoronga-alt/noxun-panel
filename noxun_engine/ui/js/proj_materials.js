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
  // tejto verzie kodu, NIE echo servera. 2B-2: toto okno pozna duplak polia
  // (schema 3) AJ rub zasteny (back_decor/back_structure — schema 4);
  // V0.6 B-2b demos polia (demos_url/price_checked_at — schema 5);
  // V0.6 M-A2 obrazok dekoru (image_url — schema 6); V0.6 M-B1 UNI polia
  // (uni/uni_role — schema 7) => konstanta je 7 (audit M-B B2: marker 7 z boot
  // doplnenia UNI sady nesmie zamknut cele okno); katalog s novsim markerom by
  // staremu oknu zapis odmietol (nove polia by ticho zahodilo). Pri katalogu,
  // ktory je este SCHEMA 1 (nerozhodnutelna migracia), server batch 3 odmietne.
  // V0.6 M-C hranova uprava PD (pd_edge_subtype — schema 8) => konstanta je 8.
  var MD_CLIENT_SCHEMA = 8;
  // 2B-2 (F10 zrkadlo registra): typy s formatom v identite — batch/formular
  // format VYZADUJU. Server je autorita (format_in_identity?), toto je UX.
  var MD_FORMAT_TYPES = ['PD', 'ZASTENA'];
  function mdFormatRequired(type){
    return MD_FORMAT_TYPES.indexOf(String(type || '').trim().toUpperCase()) >= 0;
  }
  function mdZastena(type){
    return String(type || '').trim().toUpperCase() === 'ZASTENA';
  }
  // 2A-4b: rezim SERVEROVEHO katalogu (payload catalog_schema) — riadi
  // zoskupenie dlazdic (group_id vs text dekoru), universal toggle a banner.
  var MD_SCHEMA2 = false;
  // 2A-4b (audit B4/O1): nudzovy read-only rezim + dovod + pocet nepouzitelnych
  // pasok (VYHRADNE zo servera — JS nikdy nepocita sam).
  var MD_RO = false;
  var MD_CUTOVER_ISSUE = '';  // GH #93 P2: dovod nevykonaneho cutoveru (banner)
  var MD_HAS_BACKUP = false;  // GH #93 P2 (10. kolo): existuje predmigracna zaloha
  var MD_RO_REASON = '';
  var MD_UNUSABLE = 0;
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

  // --- D-41 PR B: katalog zoskupeny podla SKUPIN --------------------------
  // Cista funkcia (Node test): catalog {sheets,edges} -> pole skupin
  // [{key, gid, decor, decor_name, manufacturer, color, sheets, edges,
  //   usage_key, count}] zoradene cislom dekoru (tie-break vyrobca — dve
  // skupiny s rovnakym cislom su legalne), prazdny dekor posledny.
  // 2A-4b (audit O2/B3): schema2=true klucuje skupiny cez group_id (kotva
  // skupiny — NIKDY textova zhoda); zaznam bez group_id (hybrid) a cely
  // rezim schema2=false padaju na text dekoru (presne dnesne spravanie).
  // Dosky v skupine: typ+hrubka vzostupne; ABS: hrubka, potom sirka (legacy
  // bez sirky na konci — rovnaka logika ako D-41 sort v core.js).
  function mdGroupKeyOf(rec, schema2){
    if (schema2){
      var gid = String(rec.group_id == null ? '' : rec.group_id).trim();
      if (gid) return 'g:' + gid;
    }
    return 'd:' + String(rec.decor == null ? '' : rec.decor).trim();
  }
  function groupCatalogByDecor(catalog, schema2){
    var map = {}, order = [];
    function grp(rec){
      var key = mdGroupKeyOf(rec, schema2);
      if (!map[key]){
        map[key] = { key: key,
                     gid: (schema2 && String(rec.group_id == null ? '' : rec.group_id).trim()) || '',
                     decor: String(rec.decor == null ? '' : rec.decor).trim(),
                     decor_name: '', manufacturer: '', color: null, sheets: [], edges: [] };
        order.push(key);
      }
      var g = map[key];
      if (!g.decor_name && rec.decor_name) g.decor_name = String(rec.decor_name).trim();
      return g;
    }
    (catalog.sheets || []).forEach(function(s){
      var g = grp(s);
      g.sheets.push(s);
      if (!g.manufacturer && s.manufacturer) g.manufacturer = s.manufacturer;
      if (!g.color && s.color) g.color = s.color;
      // V0.6 M-A2: obrazok skupiny = prvy sheet s LOKALNYM suborom (image_file
      // stavia server z DemosImageCache — remote URL do CEF nikdy nejde).
      if (!g.image && s.image_file) g.image = s.image_file;
      // M-A3b (D-56): pocet variantov s ulozenou vazbou na Demos (badge dlazdice).
      if (s.demos_url) g.demos_n = (g.demos_n || 0) + 1;
      // V0.6 M-B2: UNI skupina (badge + vlastna sekcia + tlacidlo Nahradit).
      if (s.uni === true){ g.uni = true; if (!g.uni_role && s.uni_role) g.uni_role = s.uni_role; }
    });
    (catalog.edges || []).forEach(function(a){
      var g = grp(a);
      g.edges.push(a);
      if (!g.color && a.color) g.color = a.color;
      if (a.demos_url) g.demos_n = (g.demos_n || 0) + 1;
    });
    order.sort(function(x, y){
      var a = map[x], b = map[y];
      if (a.decor === '' && b.decor !== '') return 1;
      if (b.decor === '' && a.decor !== '') return -1;
      return a.decor.localeCompare(b.decor) ||
        String(a.manufacturer || '').localeCompare(String(b.manufacturer || ''));
    });
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
      // Kluc pouzitia v modeli: server (model_decor_usage) kluci SCHEMA 2 cez
      // group_id, legacy cez text dekoru — presne zrkadlo.
      g.usage_key = g.gid || g.decor;
      g.count = g.sheets.length + g.edges.length;
      return g;
    });
  }
  function fmtNum(v){ var f = parseFloat(v); return (f === Math.round(f)) ? String(Math.round(f)) : String(f); }
  function sheetChipLabel(s){ return (s.type ? s.type + ' ' : '') + fmtNum(s.thickness); }
  function edgeChipLabel(a){
    return (a.width === null || a.width === undefined) ? fmtNum(a.thickness) + ' mm' : fmtNum(a.width) + '/' + fmtNum(a.thickness);
  }
  // 2A-4b: riadok dosky v detaile = typ · hrubka · format (format ako druhy
  // riadok bunky — stlpec rozmeru ostava uzky).
  function sheetDimLabel(s){
    var ss = s.sheet_size;
    var fmt = (ss && ss.length === 2) ? fmtNum(ss[0]) + '×' + fmtNum(ss[1]) : '';
    // 2B-2: rub zasteny do sub riadku ("4100×640 · rub K552 RT") — obchodna
    // identita produktu musi byt v detaile citatelna.
    if (s.back_decor){
      var back = 'rub ' + [s.back_decor, s.back_structure || ''].filter(Boolean).join(' ');
      fmt = fmt ? fmt + ' · ' + back : back;
    }
    return { dim: sheetChipLabel(s), sub: fmt };
  }

  // D-42 (audit FIX 9): dekor matchne hladanie, ak sa dotaz najde v nazve,
  // vyrobcovi, ALEBO v kode/dodavatelovi KTOREHOKOLVEK jeho variantu (kod je
  // variantovy). 2A-4b: + zobrazovaci nazov skupiny a STRUKTURA variantu
  // (hladanie "ST9" najde vsetky skupiny s ST9 variantmi). Prazdny dotaz = vsetko.
  function mdMatchGroup(g, q){
    if (!q) return true;
    if (String(g.decor).toLowerCase().indexOf(q) >= 0) return true;
    if (String(g.decor_name || '').toLowerCase().indexOf(q) >= 0) return true;
    if (String(g.manufacturer || '').toLowerCase().indexOf(q) >= 0) return true;
    var vs = g.sheets.concat(g.edges);
    for (var i = 0; i < vs.length; i++){
      if (String(vs[i].code || '').toLowerCase().indexOf(q) >= 0) return true;
      if (String(vs[i].supplier || '').toLowerCase().indexOf(q) >= 0) return true;
      // 2B-2 (GH #95 P2): rub zasteny je objednavkova identita — "K552" musi
      // najst skupinu K551/K552 (aj struktura rubu).
      if (String(vs[i].back_decor || '').toLowerCase().indexOf(q) >= 0) return true;
      if (String(vs[i].back_structure || '').toLowerCase().indexOf(q) >= 0) return true;
      if (String(vs[i].structure || '').toLowerCase().indexOf(q) >= 0) return true;
    }
    return false;
  }
  // D-42 PR B (cista funkcia, Node test): rozdeli dekorove skupiny do SEKCII
  // mriezky. query aktivne => jedina plocha sekcia "Vysledky". Rezim 'man' =>
  // pas "Pouzite v projekte" (podla poctu dielcov v modeli, zostupne) + sekcie
  // podla vyrobcu (abecedne, "Bez vyrobcu" posledna — patri sem aj edge-only
  // dekor bez dosky a legacy "(bez dekoru)"). Rezim 'az' => plochy zoznam.
  // 2A-4b: kluc pouzitia skupiny — usage_key (SCHEMA 2 = group_id), fallback
  // text dekoru (stare volania/testy bez usage_key).
  function mdUsageKey(g){ return g.usage_key === undefined ? g.decor : g.usage_key; }
  function mdBuildSections(groups, used, mode, query){
    if (query) return [{ title: 'Výsledky', kind: 'flat', groups: groups }];
    // V0.6 M-B2 (audit N8): UNI pracovne materialy = vlastna sekcia NAVRCHU
    // v OBOCH rezimoch (vyrobca aj A–Z); pri hladani filtruju normalne.
    var uniGroups = groups.filter(function(g){ return g.uni === true; });
    var rest = groups.filter(function(g){ return g.uni !== true; });
    var uniSec = uniGroups.length ? [{ title: 'Pracovné (UNI)', kind: 'uni', groups: uniGroups }] : [];
    if (mode !== 'man') return uniSec.concat([{ title: '', kind: 'flat', groups: rest }]);
    groups = rest;
    var out = uniSec;
    used = used || {};
    var usedGroups = groups.filter(function(g){ return (used[mdUsageKey(g)] || 0) > 0; })
      .slice().sort(function(a, b){
        return (used[mdUsageKey(b)] || 0) - (used[mdUsageKey(a)] || 0) || a.decor.localeCompare(b.decor);
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

  var mdRenaming = null;      // kluc skupiny s otvorenym inline rename inputom
  var mdNaming = null;        // kluc skupiny s otvorenym inline editom NAZVU (GH #93 P2)
  var mdView = null;          // null = mriezka | kluc skupiny = otvoreny detail (drill-in)
  function mdSearchInput(){
    mdView = null; // pisanie do hladania vzdy vracia do mriezky (vysledky)
    mdRenderLists();
  }
  function mdOpenDetail(key){ mdView = key; mdRenderLists(); }
  function mdCloseDetail(){ mdView = null; mdRenderLists(); }
  // Skupina podla kluca z CERSTVEHO zoskupenia (po rename/zmazani null).
  function mdGroupByKey(key){
    return groupCatalogByDecor(MD_CATALOG, MD_SCHEMA2).find(function(g){ return g.key === key; }) || null;
  }

  // 2A-4b (audit O2/B4): bannery — render pri KAZDOM apply (init aj echo),
  // ziadny jednorazovy flag. Pocet aj dovod su VYHRADNE zo servera.
  function mdRenderBanners(){
    var ro = el('mdRoBanner'), rt = el('mdRoText');
    if (ro){
      ro.style.display = MD_RO ? 'flex' : 'none';
      if (rt && MD_RO){
        rt.textContent = 'Katalóg je len na čítanie — ' + (MD_RO_REASON || 'neznámy dôvod') +
          ' Zmeny sú vypnuté; obnov predmigračnú zálohu alebo oprav súbor a reštartuj SketchUp.';
      }
    }
    var eb = el('mdEdgeBanner'), et = el('mdEdgeBannerText');
    if (eb){
      eb.style.display = MD_UNUSABLE > 0 ? 'flex' : 'none';
      if (et && MD_UNUSABLE > 0) et.textContent = mdEdgeBannerText(MD_UNUSABLE);
    }
    // GH #93 P2 (4. kolo): cutover problem (poskodena zaloha / nerozhodnutelne
    // polozky) — zlty informacny pas; katalog bezi dalej, mutacie NEblokuje.
    var cb2 = el('mdCutoverBanner'), ct2 = el('mdCutoverBannerText');
    if (cb2){
      cb2.style.display = MD_CUTOVER_ISSUE ? 'flex' : 'none';
      if (ct2 && MD_CUTOVER_ISSUE) ct2.textContent = MD_CUTOVER_ISSUE;
    }
    var nb = el('mdNewDecorBtn');
    if (nb) nb.disabled = MD_RO;
    // GH #102 P2: aj primarna Demos cesta je katalogova mutacia — v read-only
    // rezime sa vypina rovnako ako rucny batch (server by create odmietol az
    // po celom fetchovani rodiny).
    var db = el('mdDemosAddBtn');
    if (db) db.disabled = MD_RO;
    // GH #93 P2 (10. kolo): rollback aj pri zdravej SCHEMA 2 (zaloha existuje);
    // v read-only stave ho nesie nudzovy banner, tu by bol duplicitny.
    var rb = el('mdRestoreBtn');
    if (rb) rb.style.display = (MD_SCHEMA2 && !MD_RO && MD_HAS_BACKUP) ? '' : 'none';
  }
  // Cista funkcia (Node test): text banneru so slovenskym sklonovanim.
  function mdEdgeBannerText(n){
    var few = n >= 2 && n <= 4;
    var noun = n === 1 ? 'páska nemá' : (few ? 'pásky nemajú' : 'pások nemá');
    return n + ' ' + noun + ' štruktúru ani príznak univerzálna — picker ich nevyberie. ' +
      'Označ univerzálne (prepínač pri páske) alebo ich nechaj na ručný výber.';
  }

  function mdRenderLists(){
    var box = el('mdDecorList');
    if (!box) return;
    var q = (el('mdSearch') && el('mdSearch').value || '').trim().toLowerCase();
    // detail drzi len existujucu skupinu (po rename/zmazani spadne na mriezku)
    if (mdView !== null){
      var dg = mdGroupByKey(mdView);
      if (dg){ box.innerHTML = mdDetailHtml(dg); mdFocusInline(); return; }
      mdView = null;
    }
    var groups = groupCatalogByDecor(MD_CATALOG, MD_SCHEMA2).filter(function(g){ return mdMatchGroup(g, q); });
    var mode = (el('mdGroupMode') && el('mdGroupMode').value) || 'man';
    var sections = mdBuildSections(groups, MD_USED, mode, q);
    var html = '';
    sections.forEach(function(sec){
      if (sec.title){
        html += '<div class="mdsechead">' +
          (sec.kind === 'used' ? '<svg class="ic" aria-hidden="true"><use href="#i-check"/></svg>'
            : sec.kind === 'uni' ? '<svg class="ic" aria-hidden="true"><use href="#i-layers"/></svg>'
                                 : '<svg class="ic" aria-hidden="true"><use href="#i-factory"/></svg>') +
          ' ' + esc(sec.title) + '</div>';
      }
      html += '<div class="mdgrid">';
      sec.groups.forEach(function(g){ html += mdTileHtml(g, sec.kind === 'used' ? (MD_USED[mdUsageKey(g)] || 0) : 0); });
      html += '</div>';
    });
    box.innerHTML = html || '<div class="muted">' + (q ? 'Nič sa nenašlo.' : 'Katalóg je prázdny.') + '</div>';
  }

  // Dlazdica skupiny: swatch + hlavicka (cislo + nazov; vyrobca · pocet
  // variantov) + suhrn variantov (chips su len prehlad — sprava variantov zije
  // v detaile po rozkliku, audit BLOCKER 6).
  // V0.6 M-A2: lokalna cesta obrazka -> file:/// URL pre CEF (backslash na
  // slash + encodeURI kvoli medzeram v ceste). Cista funkcia (Node test).
  function mdImageSrc(path){
    var p = String(path == null ? '' : path).trim();
    if (!p) return '';
    return 'file:///' + encodeURI(p.replace(/\\/g, '/').replace(/^\/+/, ''));
  }

  function mdTileHtml(g, usedCount){
    var name = g.decor === '' ? '(bez dekoru)' : g.decor + (g.decor_name ? ' ' + g.decor_name : '');
    var sub = (g.manufacturer || 'vlastný') + ' · ' + g.count + ' var.';
    var chips = '';
    g.sheets.forEach(function(s){ chips += '<span class="vchip">' + esc(sheetChipLabel(s)) + '</span>'; });
    g.edges.forEach(function(a){ chips += '<span class="vchip vchip-abs">' + esc(edgeChipLabel(a)) + '</span>'; });
    // V0.6 M-A2: realna fotka dekoru zo stiahnutej cache; pri chybe suboru
    // inline onerror (bez dat) schova <img> a ostane fallback farba swatchu.
    var sw = '<i class="mdsw" style="background:' + esc(rgbToHex(g.color)) + '">' +
      (g.image ? '<img class="mdsw-photo" src="' + esc(mdImageSrc(g.image)) + '" alt="" onerror="this.style.display=\'none\'">' : '') +
      '</i>';
    // M-A3b: D-63 plny nazov v tooltipe (dvojriadkovy clamp ho moze orezat);
    // D-56 badge vazby na Demos (aspon 1 variant s ulozenou URL).
    var full = name + ' · ' + (g.manufacturer || 'vlastný');
    return '<div class="mdtile" title="' + esc(full) + '" onclick="mdOpenDetail(' + esc(JSON.stringify(g.key)) + ')">' +
      '<div class="mdtile-head">' +
      sw +
      '<span class="mdtile-name"><b>' + esc(name) + '</b>' +
      '<span class="mans">' + esc(sub) + '</span></span>' +
      (g.uni ? '<span class="mdunib" title="Pracovný UNI materiál — pred výrobou nahraď reálnym dekorom">UNI</span>' : '') +
      (g.demos_n ? '<span class="mddemos" title="Prepojené s Demosom (' + g.demos_n + ' var.)"><svg class="ic" aria-hidden="true"><use href="#i-cloud-download"/></svg></span>' : '') +
      (usedCount ? '<span class="mdused">' + usedCount + '×</span>' : '') +
      '</div><div class="mdtile-chips">' + (chips || '<span class="muted">bez variantov</span>') + '</div></div>';
  }

  // M-A3b (D-60): "cena overená" datum z ISO price_checked_at -> DD.MM.RRRR
  // (cista funkcia, Node test; nevalidny vstup = prazdny string).
  function mdDateLabel(iso){
    var m = String(iso == null ? '' : iso).match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (!m) return '';
    return parseInt(m[3], 10) + '.' + parseInt(m[2], 10) + '.' + m[1];
  }

  // M-A3b (D-60): ikona vazby na Demos v riadku variantu — klik otvori stranku
  // u dodavatela (URL drzi VYHRADNE server: klient posiela len kind+id, audit
  // BLOCKER 2). Bez ulozenej vazby ziadne tlacidlo (ziadny mrtvy priestor).
  function mdDemosBtn(kind, id, rec){
    if (!rec || !rec.demos_url) return '';
    var when = mdDateLabel(rec.price_checked_at);
    var title = 'Prepojené s Demosom' + (when ? ' · cena overená ' + when : '') + ' — otvoriť u dodávateľa';
    return '<button class="mduni mddm" title="' + esc(title) + '" aria-label="Otvoriť u dodávateľa"' +
      ' onclick="mdDemosOpen(\'' + kind + '\', \'' + esc(id) + '\')">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-external-link"/></svg></button>';
  }
  function mdDemosOpen(kind, id){
    if (window.sketchup && sketchup.open_demos_url)
      sketchup.open_demos_url(JSON.stringify({ kind: kind, id: id }));
  }

  // 2A-4b: sekcie detailu per STRUKTURA povrchu (cista funkcia, Node test).
  // Kluc = normalizovana struktura (trim+kolaps medzier+upper), title = prvy
  // videny tvar; sekcia bez struktury posledna (patria sem aj universal pasky).
  function mdStructureSections(g){
    var map = {}, order = [];
    function sec(st){
      var raw = String(st == null ? '' : st).trim();
      var key = raw.replace(/\s+/g, ' ').toUpperCase();
      if (!map[key]){ map[key] = { key: key, title: raw, sheets: [], edges: [] }; order.push(key); }
      return map[key];
    }
    (g.sheets || []).forEach(function(s){ sec(s.structure).sheets.push(s); });
    (g.edges || []).forEach(function(a){ sec(a.structure).edges.push(a); });
    order.sort(function(x, y){ return x === '' ? 1 : y === '' ? -1 : x.localeCompare(y); });
    return order.map(function(k){ return map[k]; });
  }

  // Detail skupiny (drill-in): hlavicka s akciami skupiny + sekcie per
  // struktura, v nich riadky variantov (rozmer · kod · cena · dodavatel)
  // s Upravit/zmazat — EXISTUJUCE formulare (audit BLOCKER 6: sprava variantov
  // ostava plne dostupna). Read-only rezim (MD_RO) vypina mutacne prvky —
  // len UX, autorita odmietnutia je server.
  function mdDetailHtml(g){
    var name = g.decor === '' ? '(bez dekoru)' : g.decor + (g.decor_name ? ' ' + g.decor_name : '');
    var dis = MD_RO ? ' disabled' : '';
    var h = '<div class="mdcard mdet">';
    h += '<div class="tplrow mdhead">' +
      '<button class="ghostbtn tplbtn" onclick="mdCloseDetail()" title="Späť na katalóg" aria-label="Späť na katalóg"><svg class="ic" aria-hidden="true"><use href="#i-arrow-left"/></svg></button>' +
      // M-A3b (D-62): fotka dekoru aj v hlavicke detailu (vzor dlazdice —
      // onerror schova <img>, fallback farba swatchu ostava pod nou).
      '<i class="mdsw mdsw-lg" style="background:' + esc(rgbToHex(g.color)) + '">' +
      (g.image ? '<img class="mdsw-photo" src="' + esc(mdImageSrc(g.image)) + '" alt="" onerror="this.style.display=\'none\'">' : '') +
      '</i>' +
      '<span class="tpln"><b>' + esc(name) + '</b>' + (g.manufacturer ? ' <span class="tplt">' + esc(g.manufacturer) + '</span>' : '') +
      (g.uni ? ' <span class="mdunib">UNI</span>' : '') + '</span>' +
      // V0.6 M-B2: hromadna zamena UNI za realny dekor (nazov drzat presne —
      // semafor ORANGE „material neurceny" nan odkazuje textom).
      (g.uni ? '<button class="primary tplbtn"' + dis + ' onclick="mdUniOpen(' + esc(JSON.stringify(g.key)) + ')">Nahradiť UNI…</button>' : '') +
      (g.decor === '' ? '' :
        '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdOpenDecorForm(' + esc(JSON.stringify(g.key)) + ')">+ variant</button>' +
        '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdManufacturerOpen(' + esc(JSON.stringify(g.key)) + ')">Výrobca</button>' +
        (MD_SCHEMA2 ? '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdNameOpen(' + esc(JSON.stringify(g.key)) + ')">Názov</button>' : '') +
        '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdRenameOpen(' + esc(JSON.stringify(g.key)) + ')">Premenovať</button>' +
        // V0.6 B-2b (N17): ikonove tlacidlo v EXISTUJUCOM rade akcii (vertikalny
        // priestor) — lookup kodov a cien celej dekorovej skupiny na Demose.
        '<button class="ghostbtn tplbtn"' + dis + ' title="Aktualizovať kódy a ceny z Demosu" aria-label="Aktualizovať z Demosu" onclick="mddLookup(' + esc(JSON.stringify(g.key)) + ')"><svg class="ic" aria-hidden="true"><use href="#i-refresh-cw"/></svg></button>') +
      '</div>';
    // GH #93 P2: editacia NAZVU skupiny (decor_name — zobrazovacia vlastnost,
    // meni sa atomicky celej skupine cez group_id; prazdny nazov = vymazanie).
    if (mdNaming === g.key && MD_SCHEMA2){
      h += '<div class="tplrow"><input id="md_gname_input" type="text" value="' + esc(g.decor_name || '') + '" placeholder="Názov skupiny (napr. Dub Halifax)" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdNameSave(' + esc(JSON.stringify(g.key)) + ')">Uložiť</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdNameOpen(null)">Zrušiť</button></div>';
    }
    if (mdManufacturing === g.key){
      // D-44: naseptavac (datalist mdManList) + VLASTNE tlacidlo na vymazanie —
      // prazdny input uz vyrobcu nezmaze (server odmietne bez flagu, audit F9).
      h += '<div class="tplrow"><input id="md_man_input" type="text" value="' + esc(g.manufacturer || '') + '" placeholder="Výrobca (napr. Egger)" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdManufacturerSave(' + esc(JSON.stringify(g.key)) + ')">Uložiť</button>' +
        (g.manufacturer ? '<button class="ghostbtn tpldel" title="Zmazať výrobcu" aria-label="Zmazať výrobcu" onclick="mdManufacturerClear(' + esc(JSON.stringify(g.key)) + ')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>' : '') +
        '<button class="ghostbtn tplbtn" onclick="mdManufacturerOpen(null)">Zrušiť</button></div>';
    }
    if (mdRenaming === g.key){
      h += '<div class="tplrow"><input id="md_rename_input" type="text" value="' + esc(g.decor) + '" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdRenameSave(' + esc(JSON.stringify(g.key)) + ')">Uložiť</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdRenameOpen(null)">Zrušiť</button></div>';
    }
    var sections = mdStructureSections(g);
    var multi = sections.length > 1 || (sections.length === 1 && sections[0].key !== '');
    sections.forEach(function(sec){
      if (multi) h += '<div class="mdstsec">' + esc(sec.title || 'Bez štruktúry') + '</div>';
      h += mdSectionRows(sec);
    });
    if (!sections.length) h += '<div class="muted">žiadne varianty</div>';
    h += '</div>';
    return h;
  }

  // Riadky jednej strukturnej sekcie: blok Dosky + blok ABS (len nepradzne).
  function mdSectionRows(sec){
    var h = '';
    if (sec.sheets.length){
      h += '<div class="mdsec">Dosky</div>';
      h += '<div class="mdvhead"><span class="mdvdim"></span><span class="mdvi">Kód</span><span class="mdvi mdvp">€/m²</span><span class="mdvi">Dodávateľ</span><span class="mdvact"></span></div>';
      sec.sheets.forEach(function(s){
        var prot = MD_PROTECTED.indexOf(s.material_id) >= 0;
        var dl = sheetDimLabel(s);
        var dim = esc(dl.dim) + (dl.sub ? '<small>' + esc(dl.sub) + '</small>' : '');
        // 2B-1 (D-43): duplak nema editovatelne bunky — vsetko derivuje zo
        // zdroja (server edit/patch odmietne); riadok ukazuje vazbu + delete.
        if (s.source_material_id){
          h += mdDuplakRow(s, dim);
        } else {
          h += mdVariantRow('sheet', s.material_id, s.row_rev, dim,
            s.code, s.price_per_m2, s.supplier, s.label,
            'mdOpenSheetForm(\'' + esc(s.material_id) + '\')',
            prot ? null : 'mdDeleteSheet(\'' + esc(s.material_id) + '\')', prot,
            mdDuplakBtn(s) + mdDemosBtn('sheet', s.material_id, s));
        }
      });
    }
    if (sec.edges.length){
      h += '<div class="mdsec">ABS pásky</div>';
      h += '<div class="mdvhead"><span class="mdvdim"></span><span class="mdvi">Kód</span><span class="mdvi mdvp">€/bm</span><span class="mdvi">Dodávateľ</span><span class="mdvact"></span></div>';
      sec.edges.forEach(function(a){
        h += mdVariantRow('edge', a.abs_id, a.row_rev, esc(edgeChipLabel(a)),
          a.code, a.price_per_bm, a.supplier, a.label,
          'mdOpenEdgeForm(\'' + esc(a.abs_id) + '\')',
          'mdDeleteEdge(\'' + esc(a.abs_id) + '\')', false,
          mdUniBtn(a) + mdDemosBtn('edge', a.abs_id, a));
      });
    }
    return h;
  }

  // 2A-4b: universal toggle ABS pasky (vlastnost VYBERU, standard 7.5) —
  // ikona globe s aria-pressed; klik posle patch_edge {universal}; pocas
  // zapisu disabled, stav VZDY obnovi serverove echo (push_catalog) — aj pri
  // :conflict/:write_failed/:catalog_read_only sa checkbox vrati podla servera.
  function mdUniBtn(a){
    if (!MD_SCHEMA2) return '';
    var on = a.universal === true;
    return '<button class="mduni' + (on ? ' on' : '') + '" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Univerzálna páska — pasuje na každú štruktúru" aria-label="Univerzálna páska"' + (MD_RO ? ' disabled' : '') +
      ' onclick="mdUniToggle(this, \'' + esc(a.abs_id) + '\', ' + (on ? 'false' : 'true') + ', \'' + esc(a.row_rev || '') + '\')">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-globe"/></svg></button>';
  }
  function mdUniToggle(btn, id, value, rev){
    if (MD_RO) return;
    if (btn) btn.disabled = true; // pocas zapisu; re-render z echa ho obnovi
    var payload = { id: id, patch: { universal: value }, row_rev: rev || '',
                    catalog_schema: MD_CLIENT_SCHEMA };
    if (window.sketchup && sketchup.patch_edge) sketchup.patch_edge(JSON.stringify(payload));
  }

  // 2B-1 (D-43): riadok duplaku — bez inline buniek (kod/cena/dodavatel patria
  // ZDROJU, duplak sa nekupuje), namiesto nich vazba. Ceruzka nie je (nema co
  // editovat), delete ostava.
  function mdDuplakRow(s, dimHtml){
    var dis = MD_RO ? ' disabled' : '';
    return '<div class="mdvrow" title="' + esc(s.label || '') + '">' +
      '<span class="mdvdim">' + dimHtml + '</span>' +
      '<span class="mdvi mdvdup" title="Duplák: lepí sa z ' + s.source_multiplier + '× zdrojovej dosky — nakupuje a oceňuje sa zdroj">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-layers"/></svg> lepené ' + s.source_multiplier + '× z ' + esc(s.source_material_id) + '</span>' +
      '<span class="mdvact">' +
      '<button class="ghostbtn tpldel"' + dis + ' title="Zmazať duplák" aria-label="Zmazať duplák" onclick="mdDeleteSheet(\'' + esc(s.material_id) + '\')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>' +
      '</span></div>';
  }

  // 2B-1: akcia "+duplak" pri beznej doske (DTDL/MDF — telove typy; PD/zastena
  // sa nelepia). Vytvori variant 2x hrubka viazany na tuto dosku (server
  // create_duplak_sheet — vsetky guardy tam).
  function mdDuplakBtn(s){
    if (!MD_SCHEMA2 || MD_RO) return '';
    var t = String(s.type || '').toUpperCase();
    if (t !== 'DTDL' && t !== 'MDF') return '';
    return '<button class="mduni" title="Vytvoriť duplák (' + fmtNum(s.thickness * 2) + ' mm lepené z 2× tejto dosky)"' +
      ' aria-label="Vytvoriť duplák" onclick="mdCreateDuplak(\'' + esc(s.material_id) + '\')">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-layers"/></svg></button>';
  }
  function mdCreateDuplak(id){
    if (MD_RO) return;
    if (window.sketchup && sketchup.create_duplak)
      sketchup.create_duplak(JSON.stringify({ source_material_id: id, source_multiplier: 2,
        catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
  }

  // Riadok variantu v detaile — kod/cena/dodavatel su EDITOVATELNE bunky
  // (D-42 PR C, audit BLOCKER 1): flush na blur/Enter posle PATCH len meneneho
  // pola + row_rev baseline. Farba/format/smer ostavaju vo formulari (ceruzka).
  // Cena NEZADANA (nil) = prazdna bunka s placeholderom "—" (FIX 11).
  function mdCellHtml(kind, id, rev, field, value, extraCls, ph){
    var v = (value === null || value === undefined) ? '' : String(value);
    return '<input class="mdcell ' + extraCls + '" type="text" value="' + esc(v) + '" placeholder="' + ph + '"' +
      (MD_RO ? ' readonly' : '') +
      ' data-kind="' + kind + '" data-id="' + esc(id) + '" data-field="' + field + '" data-rev="' + esc(rev || '') + '"' +
      ' data-orig="' + esc(v) + '" onblur="mdCellFlush(this)" onkeydown="mdCellKey(event, this)">';
  }
  // dimHtml je UZ escapovane (moze niest <small> formatu dosky); extra = dalsi
  // ovladaci prvok pred akciami (universal toggle ABS).
  function mdVariantRow(kind, id, rev, dimHtml, code, price, supplier, title, editCall, delCall, prot, extra){
    var priceField = kind === 'edge' ? 'price_per_bm' : 'price_per_m2';
    var dis = MD_RO ? ' disabled' : '';
    return '<div class="mdvrow" title="' + esc(title || '') + '">' +
      '<span class="mdvdim">' + dimHtml + '</span>' +
      mdCellHtml(kind, id, rev, 'code', code, '', 'kód') +
      mdCellHtml(kind, id, rev, priceField, price, 'mdvp', '—') +
      mdCellHtml(kind, id, rev, 'supplier', supplier, '', 'dodávateľ') +
      (extra || '') +
      '<span class="mdvact">' +
      '<button class="ghostbtn tplbtn"' + dis + ' title="Ďalšie vlastnosti (farba, formát…)" aria-label="Ďalšie vlastnosti" onclick="' + editCall + '"><svg class="ic" aria-hidden="true"><use href="#i-pencil"/></svg></button>' +
      (prot ? '<span class="tplt">predvoľba</span>'
            : '<button class="ghostbtn tpldel"' + dis + ' title="Zmazať" aria-label="Zmazať" onclick="' + delCall + '"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>') +
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
    var gi = el('md_gname_input');
    if (gi){ gi.focus(); gi.select(); return; }
    var mi = el('md_man_input');
    // M-A3c (D-67, audit FIX 6): inline editor vyrobcu bol jediny dalsi
    // spotrebitel datalistu — dostava ten isty suggest komponent.
    if (mi){ mdSgBind('md_man_input', function(){ return MD_SUGGEST.manufacturers; }, null); mi.focus(); mi.select(); }
  }
  function mdRenameOpen(key){
    mdRenaming = key; mdManufacturing = null; mdNaming = null;
    mdRenderLists();
  }
  function mdNameOpen(key){
    mdNaming = key; mdRenaming = null; mdManufacturing = null;
    mdRenderLists();
  }
  function mdNameSave(key){
    var input = el('md_gname_input');
    var g = mdGroupByKey(key);
    if (!input || !g) return;
    if (window.sketchup && sketchup.set_decor_name)
      sketchup.set_decor_name(JSON.stringify({ group_id: g.gid || '', name: input.value,
        catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    mdNaming = null;
  }
  // 2A-4b (audit B3): skupinove operacie nesu group_id — server v SCHEMA 2
  // meni VYHRADNE zaznamy danej skupiny (text dekoru je len legacy fallback).
  function mdRenameSave(key){
    var input = el('md_rename_input');
    var g = mdGroupByKey(key);
    if (!input || !g) return;
    if (window.sketchup && sketchup.rename_decor)
      sketchup.rename_decor(JSON.stringify({ old_decor: g.decor, new_decor: input.value,
        group_id: g.gid || '', catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    mdRenaming = null;
  }
  // D-42 (audit FIX 7): vyrobca je vlastnost dekoru — inline editor nad celou skupinou.
  var mdManufacturing = null;
  function mdManufacturerOpen(key){
    mdManufacturing = key; mdRenaming = null; mdNaming = null;
    mdRenderLists();
    var mi = el('md_man_input'); if (mi){ mi.focus(); mi.select(); }
  }
  function mdManufacturerSave(key){
    var input = el('md_man_input');
    var g = mdGroupByKey(key);
    if (!input || !g) return;
    if (window.sketchup && sketchup.set_decor_manufacturer)
      sketchup.set_decor_manufacturer(JSON.stringify({ decor: g.decor, manufacturer: input.value,
        group_id: g.gid || '', catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    mdManufacturing = null;
  }
  // D-44 (audit F9): vymazanie vyrobcu CELEJ skupiny je vedomy krok s flagom —
  // prazdne pole samo o sebe je omyl a server ho odmietne.
  function mdManufacturerClear(key){
    var g = mdGroupByKey(key);
    if (!g) return;
    if (window.sketchup && sketchup.set_decor_manufacturer)
      sketchup.set_decor_manufacturer(JSON.stringify({ decor: g.decor, manufacturer: '',
        group_id: g.gid || '', clear_manufacturer: true, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    mdManufacturing = null;
  }

  // --- formulare (create: id=null; edit: id zaznamu) ---
  function mdOpenSheetForm(id){
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
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
    // M-A3e (D-71): rucna vazba na Demos — prefill + hint s datumom overenia.
    mdDemosField('ms', s);
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
    // 2B-2: rub zasteny — pole len pre typ ZASTENA; vyplneny rub je identita
    // (nemenny — server guard, input len readonly zrkadlo). Prazdny rub na
    // existujucej zastene = first-fill (dovoleny, s dup kontrolou servera).
    el('ms_back_decor').value = s ? (s.back_decor || '') : '';
    el('ms_back_structure').value = s ? (s.back_structure || '') : '';
    var backFilled = !!(s && s.back_decor);
    el('ms_back_decor').readOnly = backFilled;
    el('ms_back_structure').readOnly = !!(s && s.back_structure);
    // M-C: hranova uprava PD (postforming/abs; prazdne = neurcena — standardne
    // ABS defaulty). Editovatelna vlastnost, nie identita.
    if (el('ms_pd_edge')) el('ms_pd_edge').value = s ? (s.pd_edge_subtype || '') : '';
    mdSheetTypeChanged();
    el('mdSheetForm').style.display = '';
  }
  // M-C: PD rozpoznanie pre formular (zrkadlo registra; server je autorita).
  function mdPdType(type){
    return String(type == null ? '' : type).trim().toUpperCase() === 'PD';
  }
  // 2B-2: viditelnost rub polí podla typu vo formulari (create aj edit).
  function mdSheetTypeChanged(){
    var show = mdZastena(el('ms_type').value);
    el('ms_back_row').style.display = show ? '' : 'none';
    el('ms_back_hint').style.display = show ? '' : 'none';
    // M-C: riadok hranovej upravy LEN pre typ PD.
    if (el('ms_pd_row')) el('ms_pd_row').style.display = mdPdType(el('ms_type').value) ? '' : 'none';
  }
  // D-42: prazdny string ak cena nie je zadana (nil/undefined), inak hodnota
  // (aj 0 = zadana nula). Rozlisuje "nezadana" od "0".
  function mdPriceVal(v){ return (v === null || v === undefined || v === '') ? '' : String(v); }
  // M-A3e (D-71): pole rucnej vazby vo formulari (prefix 'ms'/'me') — prefill
  // z existujuceho zaznamu + hint s datumom overenia ceny (mdDateLabel).
  // Prazdne pole pri ulozeni = vedome zmazanie vazby (server kontrakt).
  // Audit FIX 5: UNI je bez nakupnych poli — riadok sa pri UNI zazname SKRYJE
  // (server by neprazdnu URL aj tak odmietol, ale pole by bola slepa ulicka).
  function mdDemosField(prefix, rec){
    var inp = el(prefix + '_demos_url');
    if (!inp) return;
    inp.value = rec ? (rec.demos_url || '') : '';
    var row = inp.closest ? inp.closest('.row') : null;
    if (row) row.style.display = (rec && rec.uni === true) ? 'none' : '';
    var hint = el(prefix + '_demos_hint');
    if (!hint) return;
    var when = (rec && !rec.uni) ? mdDateLabel(rec.price_checked_at) : '';
    if (when){
      hint.textContent = 'Cena overená ' + when + ' — zmena alebo zmazanie adresy dátum zruší.';
      hint.style.display = '';
    } else {
      hint.textContent = '';
      hint.style.display = 'none';
    }
  }
  // Audit FIX 4: klientska kontrola PRED odoslanim — formular ostava otvoreny
  // s hlaskou (server po odoslani formular zatvara a jeho odmietnutie by
  // stalo cely prepis). GH #112 P2: zrkadli CELU serverovu validaciu vratane
  // zakazanej cesty /vyhledavani (same-host URL by inak presla guardom,
  // server ju odmietol a rozpisane edity by prepadli). Server ostava autorita.
  function mdDemosUrlLocalError(v){
    var s = String(v == null ? '' : v).trim();
    if (!s) return null;
    if (!/^https:\/\//i.test(s)) return 'Adresa u dodávateľa musí začínať https:// (alebo pole nechaj prázdne).';
    if (!/^https:\/\/(www\.)?demos-trade\.sk\//i.test(s)) return 'Adresa musí byť produktová stránka demos-trade.sk.';
    if (/^https:\/\/(www\.)?demos-trade\.sk\/vyhledavani([\/?]|$)/i.test(s)){
      return 'Vyhľadávanie Demosu sa nesmie volať (robots.txt) — vlož adresu produktu.';
    }
    return null;
  }
  function mdOpenEdgeForm(id){
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
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
    // M-A3e (D-71): rucna vazba na Demos — prefill + hint s datumom overenia.
    mdDemosField('me', a);
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
  // 2A-4b: + struktura per cip (predvyplnena spolocnym polom nd_structure —
  // auto semantika ako format) a universal checkbox na ABS cipe.
  var mdFmt = {};  // {kluc_cipu: {l, w, auto}} — auto = hodnota z navrhu, nie od pouzivatela
  var mdStS = {};  // {kluc_cipu dosky: {st, auto}} — struktura povrchu variantu
  var mdStE = {};  // {kluc_cipu ABS: {st, auto}}
  var mdUni = {};  // {kluc_cipu ABS: bool} — vedomy priznak "univerzalna"

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
      return { key: mdChipKey(c), width: c.getAttribute('data-w'), thickness: c.getAttribute('data-t'),
               label: c.textContent.trim() };
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
        if (rid === 'nd_sheet_chips'){
          if (c.classList.contains('on')) mdFmtPrefill(mdChipKey(c), mdChipType(c));
          mdRenderFmtRow();
        } else {
          mdRenderAbsRow();
        }
      });
    });
  }

  // --- 2A-4b: struktura per cip (spolocne pole = auto predvolba) -----------
  function mdCommonSt(){ return ((el('nd_structure') && el('nd_structure').value) || '').trim(); }
  // Stav struktury cipu: auto entries sleduju SPOLOCNE pole, rucne prepisane
  // (auto=false) drzia svoju hodnotu (rovnaka semantika ako format hintov).
  function mdStState(map, key){
    if (!map[key]) map[key] = { st: mdCommonSt(), auto: true };
    else if (map[key].auto) map[key].st = mdCommonSt();
    return map[key];
  }
  function mdStInput(inp, kind){
    var map = kind === 'e' ? mdStE : mdStS;
    map[inp.getAttribute('data-key')] = { st: inp.value, auto: false };
  }
  function mdUniInput(inp){
    mdUni[inp.getAttribute('data-key')] = !!inp.checked;
  }
  function mdCommonStructureChanged(){
    mdRenderFmtRow();
    mdRenderAbsRow();
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
  // M-A3c: + auto pruhy vynimiek (rucne hodnoty auto=false ostavaju).
  function mdTypeChanged(){
    mdActiveSheetChips().forEach(function(c){ if (!c.type) mdFmtPrefill(c.key, c.hintType); });
    var t = ((el('nd_type') && el('nd_type').value) || '').trim();
    Object.keys(mdFmtX).forEach(function(k){
      if (!mdFmtX[k].auto) return;
      var hint = mdFormatRequired(t) ? null : mdFormatHint(t, MD_FORMAT_HINTS);
      mdFmtX[k].l = hint ? mdFmtStr(hint[0]) : '';
      mdFmtX[k].w = hint ? mdFmtStr(hint[1]) : '';
    });
    mdRenderFmtRow();
    mdRenderExtraFmtRow();
  }
  // Kompaktny pruh: 1 riadok, LEN prave aktivne cipy (viac cipov = mini-polia
  // vedla seba so skratkou typu). Ziadny aktivny cip = riadok je skryty.
  // 2A-4b: + pole struktury (predvyplnene spolocnym polom, auto semantika).
  function mdRenderFmtRow(){
    var row = el('nd_fmt_row'), box = el('nd_fmt_fields');
    if (!row || !box) return;
    var chips = mdActiveSheetChips();
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var f = mdFmtState(c.key);
      var st = mdStState(mdStS, c.key);
      var lbl = c.type ? c.label : ((c.hintType ? c.hintType + ' ' : '') + c.label);
      html += '<span class="mdfmt">' +
        '<i>' + esc(lbl) + '</i>' +
        '<input type="text" class="fmtst" data-key="' + esc(c.key) + '" value="' + esc(st.st) + '"' +
        ' placeholder="štrukt." title="Štruktúra povrchu variantu (napr. PW, ST9)" oninput="mdStInput(this, \'s\')">' +
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
  // M-A3c (D-68): formatovy pruh pre DOPISANE hrubky ("Dalsie hrubky") —
  // zastena 9,2 uz nie je slepa ulicka: server format v identite vyzaduje a
  // pole na jeho zadanie tu KONECNE existuje. Pruh sa ukaze len pre vynimky
  // bez inline formatu; prefill z hintov LEN pri type bez formatu v identite
  // (audit BLOCKER 1: PD/zastena NIKDY — formaty sa liseia, identita sa nesmie
  // vymysliet). Klucom je kanonicka hrubka (9,2 = 9.2 = 09.2 — jeden pruh).
  var mdFmtX = {}; // {'x:9.2': {l, w, auto}}
  function mdFmtXState(key, type){
    if (!mdFmtX[key]){
      mdFmtX[key] = { l: '', w: '', auto: true };
      if (!mdFormatRequired(type)){
        var hint = mdFormatHint(type, MD_FORMAT_HINTS);
        if (hint){ mdFmtX[key].l = mdFmtStr(hint[0]); mdFmtX[key].w = mdFmtStr(hint[1]); }
      }
    }
    return mdFmtX[key];
  }
  function mdFmtXInput(inp){
    var f = mdFmtXState(inp.getAttribute('data-key'), (el('nd_type') && el('nd_type').value) || '');
    f[inp.getAttribute('data-dim')] = inp.value;
    f.auto = false;
  }
  function mdRenderExtraFmtRow(){
    var row = el('nd_xfmt_row'), box = el('nd_xfmt_fields');
    if (!row || !box) return;
    var type = ((el('nd_type') && el('nd_type').value) || '').trim();
    var chips = mdExtraFmtChips((el('nd_ths') && el('nd_ths').value) || '').filter(function(c){ return !c.inline; });
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var f = mdFmtXState(c.key, type);
      html += '<span class="mdfmt">' +
        '<i>' + esc(c.th) + '</i>' +
        '<input type="text" class="fmtdim" data-key="' + esc(c.key) + '" data-dim="l" value="' + esc(f.l) + '"' +
        ' placeholder="dĺžka" title="Formát platne výnimky — dĺžka (mm)" oninput="mdFmtXInput(this)">' +
        '<span class="sheetx">×</span>' +
        '<input type="text" class="fmtdim" data-key="' + esc(c.key) + '" data-dim="w" value="' + esc(f.w) + '"' +
        ' placeholder="šírka" title="Formát platne výnimky — šírka (mm)" oninput="mdFmtXInput(this)">' +
        '</span>';
    });
    box.innerHTML = html;
    row.style.display = '';
  }

  // 2A-4b: pruh detailu ABS cipov — struktura + vedomy priznak "univerzalna".
  function mdRenderAbsRow(){
    var row = el('nd_abs_row'), box = el('nd_abs_fields');
    if (!row || !box) return;
    var chips = mdActiveEdgeChips();
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var st = mdStState(mdStE, c.key);
      html += '<span class="mdfmt">' +
        '<i>' + esc(c.label) + '</i>' +
        '<input type="text" class="fmtst" data-key="' + esc(c.key) + '" value="' + esc(st.st) + '"' +
        ' placeholder="štrukt." title="Štruktúra povrchu pásky (napr. PW, ST9)" oninput="mdStInput(this, \'e\')">' +
        '<label class="fmtuni" title="Univerzálna — pasuje na každú štruktúru">' +
        '<input type="checkbox" data-key="' + esc(c.key) + '"' + (mdUni[c.key] ? ' checked' : '') +
        ' onchange="mdUniInput(this)"> univ.</label>' +
        '</span>';
    });
    box.innerHTML = html;
    row.style.display = '';
  }
  // D-44 + 2A-4b (cista funkcia, Node test): aktivne cipy + stav formatov a
  // struktur -> payload sheet_variants pre batch 3. Format ide LEN ako
  // KOMPLETNY par; polovicny/neplatny vstup zastavi odoslanie s hlaskou (vzor
  // mdSaveSheet) — server ma vlastnu striktnu kontrolu, toto je len rychla
  // spatna vazba.
  function mdBuildSheetVariants(chips, fmt, sts, sharedType){
    var out = [], err = null;
    (chips || []).forEach(function(c){
      if (err) return;
      var f = (fmt && fmt[c.key]) || {};
      var l = mdSheetDim(f.l), w = mdSheetDim(f.w);
      if ((l === null) !== (w === null) || (l !== null && (isNaN(l) || isNaN(w)))){
        err = 'Formát platne pre ' + (c.label || c.key) + ': vyplň obe čísla (mm), alebo nechaj obe prázdne.';
        return;
      }
      var st = (sts && sts[c.key]) ? String(sts[c.key].st || '').trim() : '';
      var v = { type: c.type || '', thickness: c.th, structure: st };
      if (l !== null) v.sheet_size = [l, w];
      // GH #93 P2 (7. kolo): variant s formatom v identite BEZ formatu by
      // server odmietol az PO zavreti formulara (strata celej davky) —
      // efektivny typ (cip alebo zdielany) vyzaduje format uz na klientovi;
      // formular ostava otvoreny. 2B-2 (F10): PD + ZASTENA cez helper.
      var effType = String(v.type || sharedType || '').trim();
      if (mdFormatRequired(effType) && l === null){
        err = 'Formát platne pre ' + (c.label || c.key) + ' je pri tomto type povinný (napr. 4100 × 600).';
        return;
      }
      out.push(v);
    });
    return { variants: out, error: err };
  }
  // 2A-4b (cista funkcia, Node test): ABS cipy -> edge_variants pre batch 3
  // (struktura per cip + vedomy universal priznak; default false).
  function mdBuildEdgeVariants(chips, sts, uni){
    return (chips || []).map(function(c){
      var st = (sts && sts[c.key]) ? String(sts[c.key].st || '').trim() : '';
      return { width: c.width, thickness: c.thickness, structure: st,
               universal: !!(uni && uni[c.key]) };
    });
  }
  // M-A3c (D-68, audit BLOCKER 3): JEDNA gramatika "Dalsich hrubok/ABS" —
  // polozky oddeluje bodkociarka alebo ciarka S MEDZEROU; ciarka BEZ medzery
  // medzi cislicami je DESATINNA (9,2 = 9.2 — slovenska klavesnica; povodne
  // sa "9,20" TICHO rozpadlo na hrubky 9 a 20). Kompaktny zoznam bez medzier
  // ("18,36") tym prestava byt zoznam — hint aj placeholder to hovoria a novy
  // formatovy pruh kazdu parsovanu hrubku VIDITELNE ukaze. Viac ciarok
  // v tokene = jasna chyba, ziadny tichy vyklad.
  function mdSplitExtraTokens(text){
    var s = String(text == null ? '' : text).trim();
    if (!s) return { tokens: [], error: null };
    var toks = s.split(/;|,\s+/);
    var out = [];
    for (var i = 0; i < toks.length; i++){
      var t = toks[i].trim();
      if (!t) continue;
      var commas = (t.match(/,/g) || []).length;
      if (commas > 1){
        return { tokens: [], error: 'Nejednoznačný zápis „' + t + '“ — položky oddeľuj medzerou za čiarkou (18.5, 9,2).' };
      }
      if (commas === 1){
        var fixed = t.replace(/(\d),(\d)/, '$1.$2');
        if (fixed.indexOf(',') >= 0){
          return { tokens: [], error: 'Nejednoznačný zápis „' + t + '“ — desatiny píš 9,2 alebo 9.2, položky oddeľuj medzerou za čiarkou.' };
        }
        t = fixed;
      }
      out.push(t);
    }
    return { tokens: out, error: null };
  }
  // 2A-4b (ciste funkcie, Node test): batch 3 NEPRIJIMA surove textove polia
  // (server ich odmieta — struktura by sa ticho stratila), preto "Dalsie
  // hrubky/ABS" parsuje KLIENT do strukturovanych variantov so SPOLOCNOU
  // strukturou. Server vsetko validuje znova.
  // GH #93 P2 (5. kolo): PD typ vyzaduje format v identite — vlastna hrubka
  // ho zapise INLINE ("20/4100x600") ALEBO cez formatovy pruh vynimiek
  // (M-A3c D-68: fmtx mapa 'x:<hrubka>' => {l, w}); inline ma prednost.
  // Pri type s formatom v identite je format povinny; inde volitelny.
  function mdParseExtraThs(text, commonSt, sharedType, fmtx){
    var sp = mdSplitExtraTokens(text);
    if (sp.error) return { variants: [], error: sp.error };
    var needFmt = mdFormatRequired(sharedType);
    var out = [];
    for (var i = 0; i < sp.tokens.length; i++){
      var t = sp.tokens[i];
      var parts = t.split('/');
      var f = Number(parts[0]);
      if (!isFinite(f) || f <= 0) return { variants: [], error: 'Hrúbka „' + t + '“ nie je kladné číslo.' };
      var v = { type: '', thickness: parts[0].trim(), structure: commonSt || '' };
      if (parts.length > 1){
        var fm = parts.slice(1).join('/').trim().toLowerCase().split(/[x×]/);
        var d = Number(fm[0]), w = Number(fm[1]);
        if (fm.length !== 2 || !isFinite(d) || d <= 0 || !isFinite(w) || w <= 0){
          return { variants: [], error: 'Formát pri hrúbke „' + t + '“ zapíš ako DĺžkaxŠírka (napr. 20/4100x600).' };
        }
        v.sheet_size = [d, w];
      } else {
        var fx = fmtx ? fmtx[mdExtraKey(parts[0])] : null;
        var l2 = fx ? mdSheetDim(fx.l) : null;
        var w2 = fx ? mdSheetDim(fx.w) : null;
        if (l2 !== null || w2 !== null){
          if (l2 === null || w2 === null || isNaN(l2) || isNaN(w2)){
            return { variants: [], error: 'Formát výnimky ' + parts[0] + ': vyplň obe čísla (mm), alebo nechaj obe prázdne.' };
          }
          v.sheet_size = [l2, w2];
        } else if (needFmt){
          return { variants: [], error: 'Hrúbka „' + t + '“ pri tomto type potrebuje formát platne — vyplň ho v riadku Formát výnimiek (alebo zapíš 20/4100x600).' };
        }
      }
      out.push(v);
    }
    return { variants: out, error: null };
  }
  // M-A3c (D-68): kanonicky kluc vynimkovej hrubky — 9.2, 9.20 aj 09.2 su TEN
  // ISTY variant (jeden pruh, jedna serverova identita).
  function mdExtraKey(th){
    var f = parseFloat(th);
    return 'x:' + (isFinite(f) ? String(f) : String(th).trim());
  }
  // Parsovane vynimky -> podklad pruhov: [{key, th, inline}] (dedup podla
  // kanonickeho kluca; inline = format uz zapisany v tokene, pruh netreba).
  function mdExtraFmtChips(text){
    var sp = mdSplitExtraTokens(text);
    if (sp.error) return [];
    var seen = {};
    var out = [];
    sp.tokens.forEach(function(t){
      var parts = t.split('/');
      var f = Number(parts[0]);
      if (!isFinite(f) || f <= 0) return;
      var key = mdExtraKey(parts[0]);
      if (seen[key]) return;
      seen[key] = true;
      out.push({ key: key, th: String(parseFloat(parts[0])), inline: parts.length > 1 });
    });
    return out;
  }
  // M-A3c (D-68): rovnaka gramatika ako hrubky — "22/0,8" je legalny zapis
  // desatinnej hrubky pasky.
  function mdParseExtraAbs(text, commonSt){
    var sp = mdSplitExtraTokens(text);
    if (sp.error) return { variants: [], error: sp.error };
    var out = [];
    for (var i = 0; i < sp.tokens.length; i++){
      var t = sp.tokens[i];
      var m = /^(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$/.exec(t);
      if (!m) return { variants: [], error: 'ABS „' + t + '“ zapíš ako šírka/hrúbka (napr. 23/1 alebo 23/0,8).' };
      out.push({ width: m[1], thickness: m[2], structure: commonSt || '', universal: false });
    }
    return { variants: out, error: null };
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
  // 2A-4b (cista funkcia, Node test): spolocna struktura skupiny pre "+
  // variant" — prave JEDNA odlisna neprazdna struktura variantov = predvolba,
  // inak prazdne (zmiesane skupiny si strukturu urcia per cip).
  function mdGroupCommonStructure(g){
    var seen = {};
    (g.sheets || []).concat(g.edges || []).forEach(function(r){
      var st = String(r.structure == null ? '' : r.structure).trim();
      if (!st) return;
      var key = st.replace(/\s+/g, ' ').toUpperCase();
      if (!Object.prototype.hasOwnProperty.call(seen, key)) seen[key] = st; // prvy videny tvar
    });
    var keys = Object.keys(seen);
    return keys.length === 1 ? seen[keys[0]] : '';
  }
  // --- M-A3c (D-67): vlastny suggest dropdown --------------------------------
  // Nativny <datalist> v CEF okne NEZAPISUJE kliknutu polozku (smoke F8100 —
  // klik na typ „Zástena" nespravil nic). Nahrada: jeden zdielany overlay
  // (#mdSgBox, position:fixed — audit FIX 7: ziadne clipovanie formularom),
  // vyber MOUSEDOWN-om (audit FIX 4: blur by dropdown zavrel skor, nez klik
  // dopadne), klavesnica sipky/Enter/Escape (FIX 5 — datalist ju daval
  // zadarmo), diakriticky necitlivy filter (FIX 5). Vyber ide cez onPick
  // COMMIT cestu pola (audit BLOCKER 2 — nd_type musi prepocitat formaty).
  function mdNormText(s){
    // \u0300-\u036f = combining diakritika po NFD rozklade (explicitne escapy,
    // ziadne neviditelne znaky v kode).
    return String(s == null ? '' : s).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  }
  // Cista funkcia (Node test): prefix zhody pred substring, poradie zoznamu
  // stabilne (server ho dodava dedupnute a zoradene), prazdny dotaz = vsetko.
  function mdSuggestFilter(list, query, limit){
    var q = mdNormText(String(query == null ? '' : query).trim());
    var pref = [], sub = [];
    (list || []).forEach(function(v){
      var n = mdNormText(v);
      if (!q || n.indexOf(q) === 0) pref.push(v);
      else if (n.indexOf(q) > 0) sub.push(v);
    });
    return pref.concat(sub).slice(0, limit || 8);
  }
  var mdSg = { input: null, getList: null, onPick: null, items: [], active: -1 };
  function mdSgBox(){
    var b = el('mdSgBox');
    if (!b){
      b = document.createElement('div');
      b.id = 'mdSgBox';
      b.style.display = 'none';
      document.body.appendChild(b);
      // FIX 4: mousedown vyhrava nad blur; click uz len pre istotu.
      b.addEventListener('mousedown', function(ev){
        var r = ev.target && ev.target.closest ? ev.target.closest('.mdsg-row') : null;
        if (!r) return;
        ev.preventDefault();
        mdSgPick(parseInt(r.getAttribute('data-i'), 10) || 0);
      });
      // fixed pozicia sa pri scrolle rozide s inputom — radsej zavriet.
      window.addEventListener('scroll', mdSgClose, true);
    }
    return b;
  }
  function mdSgClose(){
    mdSg.input = null;
    mdSg.items = [];
    mdSg.active = -1;
    var b = el('mdSgBox');
    if (b) b.style.display = 'none';
  }
  function mdSgPick(i){
    var inp = mdSg.input, v = mdSg.items[i], cb = mdSg.onPick;
    mdSgClose();
    if (!inp || v == null) return;
    inp.value = v;
    if (cb) cb(); // commit cesta pola (nd_type -> mdTypeChanged)
    inp.focus();
  }
  function mdSgRender(){
    var b = mdSgBox(), inp = mdSg.input;
    if (!inp || !mdSg.items.length){ b.style.display = 'none'; return; }
    b.textContent = '';
    mdSg.items.forEach(function(v, i){
      var r = document.createElement('div');
      r.className = 'mdsg-row' + (i === mdSg.active ? ' on' : '');
      r.setAttribute('data-i', String(i));
      r.textContent = v; // XSS kontrakt: textContent, ziadny innerHTML
      b.appendChild(r);
    });
    var rect = inp.getBoundingClientRect();
    b.style.left = Math.round(rect.left) + 'px';
    b.style.top = Math.round(rect.bottom + 2) + 'px';
    b.style.minWidth = Math.round(rect.width) + 'px';
    b.style.display = '';
  }
  function mdSgUpdate(){
    if (!mdSg.input) return;
    mdSg.items = mdSuggestFilter(mdSg.getList ? mdSg.getList() : [], mdSg.input.value);
    mdSg.active = -1;
    mdSgRender();
  }
  // Bind na input (idempotentne — data-sg marker; konfiguracia _sgList/_sgPick
  // sa obnovi pri kazdom volani). getList sa cita az PRI otvoreni dropdownu
  // (katalogove echo medzitym MD_SUGGEST vymeni — ziadne stale data).
  function mdSgBind(id, getList, onPick){
    var inp = el(id);
    if (!inp) return;
    if (!inp.getAttribute('data-sg')){
      inp.setAttribute('data-sg', '1');
      inp.setAttribute('autocomplete', 'off');
      inp.addEventListener('focus', function(){ mdSg.input = inp; mdSg.getList = inp._sgList; mdSg.onPick = inp._sgPick; mdSgUpdate(); });
      inp.addEventListener('input', function(){ if (mdSg.input === inp) mdSgUpdate(); });
      inp.addEventListener('blur', function(){ setTimeout(function(){ if (mdSg.input === inp) mdSgClose(); }, 120); });
      inp.addEventListener('keydown', function(ev){
        if (mdSg.input !== inp || !mdSg.items.length) return;
        if (ev.key === 'ArrowDown'){ ev.preventDefault(); mdSg.active = (mdSg.active + 1) % mdSg.items.length; mdSgRender(); }
        else if (ev.key === 'ArrowUp'){ ev.preventDefault(); mdSg.active = (mdSg.active - 1 + mdSg.items.length) % mdSg.items.length; mdSgRender(); }
        else if (ev.key === 'Enter'){ ev.preventDefault(); mdSgPick(mdSg.active >= 0 ? mdSg.active : 0); }
        else if (ev.key === 'Escape'){ mdSgClose(); }
      });
    }
    inp._sgList = getList;
    inp._sgPick = onPick;
  }

  function mdOpenDecorForm(key){
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
    mdCloseForms();
    mdBindChips();
    var g = key ? mdGroupByKey(key) : null;
    mdEditing = { kind: 'decor', id: key };
    el('nd_decor').value = g ? g.decor : '';
    el('nd_decor').disabled = !!g;
    // 2A-4b: nazov + vyrobca su vlastnosti SKUPINY — pri "+ variant" su
    // zamknute (zmena by cielila inu/novu skupinu; menia sa v katalogu).
    if (el('nd_decor_name')){
      el('nd_decor_name').value = g ? (g.decor_name || '') : '';
      el('nd_decor_name').disabled = !!g;
    }
    el('nd_manufacturer').value = g ? (g.manufacturer || '') : '';
    el('nd_manufacturer').disabled = !!g;
    // Spolocna struktura: pri "+ variant" predvolba z jedinej struktury skupiny.
    if (el('nd_structure')) el('nd_structure').value = g ? mdGroupCommonStructure(g) : '';
    var firstSheet = g && g.sheets.length ? g.sheets[0] : null;
    el('nd_type').value = firstSheet ? (firstSheet.type || 'DTDL') : 'DTDL';
    el('nd_grain').value = firstSheet ? (firstSheet.grain || 'length') : 'length';
    el('nd_color').value = rgbToHex(g ? g.color : null);
    el('nd_ths').value = '';
    el('nd_abs').value = '';
    // NOVY dekor = predvyplnit poslednou sadou; "+ variant" zacina prazdny
    // (doplna sa konkretna vec do existujucej skupiny).
    mdFmt = {};
    mdFmtX = {}; // M-A3c: pruhy vynimiek zacinaju cisto (audit NOTE 9: obnoveny
                 // ths ich vyrenderuje s hintom podla typu — formaty vynimiek
                 // sa do zapamatanej sady neukladaju)
    mdStS = {};
    mdStE = {};
    mdUni = {};
    var last = key ? null : mdLoadLastSet();
    mdChipsSet('nd_sheet_chips', last && last.sheet_keys ? last.sheet_keys : []);
    mdChipsSet('nd_edge_chips', last && last.edge_keys ? last.edge_keys : []);
    if (last && !key){
      el('nd_ths').value = last.ths || '';
      el('nd_abs').value = last.abs || '';
      // Ulozeny format = vedome zadany (auto=false) — navrh ho neprepise.
      // (Struktura sa NEpamata — je dekorova, nie sadova; predvolbu dava
      // spolocne pole nd_structure.)
      var fmts = (last.formats && typeof last.formats === 'object') ? last.formats : {};
      Object.keys(fmts).forEach(function(k){
        var f = fmts[k] || {};
        mdFmt[k] = { l: mdFmtStr(f.l), w: mdFmtStr(f.w), auto: false };
      });
    }
    // Cipy bez ulozeneho formatu dostanu NAVRH podla typu (viditelne v poli).
    mdActiveSheetChips().forEach(function(c){ mdFmtPrefill(c.key, c.hintType); });
    mdRenderFmtRow();
    mdRenderAbsRow();
    mdRenderExtraFmtRow(); // M-A3c (D-68): pruhy pre obnovene "Dalsie hrubky"
    mdSgBind('nd_type', function(){ return MD_SUGGEST.types; }, mdTypeChanged);
    mdSgBind('nd_manufacturer', function(){ return MD_SUGGEST.manufacturers; }, null);
    el('mdDecorForm').style.display = '';
  }
  // 2A-4b: pri SCHEMA 2 katalogu davka batch_schema 3 (skupiny/struktura/
  // universal). GH #93 P1: pri LEGACY katalogu (:undecidable fallback —
  // dokumentovany rezim, mutacie bezia) klient posiela povodny D-44 tvar
  // (batch_schema 2 BEZ struktur/universal/nazvu) — server batch 3 do
  // katalogu 1 spravne odmieta a bez fallbacku by sa nedalo NIC zalozit.
  function mdSaveDecorBatch(){
    var sheetChips = mdActiveSheetChips();
    var edgeChips = mdActiveEdgeChips();
    var built = mdBuildSheetVariants(sheetChips, mdFmt, mdStS, el('nd_type').value);
    // Polovicny format = formular OSTAVA otvoreny (hodnoty sa nestratia).
    if (built.error){ MD.setStatus(built.error, true); return; }
    var commonSt = mdCommonSt();
    // M-A3c (D-68): pruhy vynimiek (mdFmtX) doplnaju format hrubkam bez
    // inline zapisu — inline "20/4100x600" ma prednost.
    var extraS = mdParseExtraThs(el('nd_ths').value, commonSt, el('nd_type').value, mdFmtX);
    if (extraS.error){ MD.setStatus(extraS.error, true); return; }
    var extraE = mdParseExtraAbs(el('nd_abs').value, commonSt);
    if (extraE.error){ MD.setStatus(extraE.error, true); return; }
    var sheetVars = built.variants.concat(extraS.variants);
    var edgeVars = mdBuildEdgeVariants(edgeChips, mdStE, mdUni).concat(extraE.variants);
    var payload;
    if (MD_SCHEMA2){
      payload = {
        batch_schema: 3,
        catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
        decor: el('nd_decor').value,
        decor_name: el('nd_decor_name') ? el('nd_decor_name').value : '',
        manufacturer: el('nd_manufacturer').value,
        type: el('nd_type').value,
        grain: el('nd_grain').value,
        color: hexToRgb(el('nd_color').value),
        sheet_variants: sheetVars,
        edge_variants: edgeVars
      };
    } else {
      payload = {
        batch_schema: 2,
        catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
        decor: el('nd_decor').value,
        manufacturer: el('nd_manufacturer').value,
        type: el('nd_type').value,
        grain: el('nd_grain').value,
        color: hexToRgb(el('nd_color').value),
        sheet_variants: sheetVars.map(function(v){
          var o = { thickness: v.thickness };
          if (v.type) o.type = v.type;
          if (v.sheet_size) o.sheet_size = v.sheet_size;
          return o;
        }),
        edge_variants: edgeVars.map(function(v){
          return { width: v.width, thickness: v.thickness };
        })
      };
    }
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
    mdSgClose(); // M-A3c: otvoreny suggest nesmie prezit zatvorenie formulara
    if (el('mdSheetForm')) el('mdSheetForm').style.display = 'none';
    if (el('mdEdgeForm')) el('mdEdgeForm').style.display = 'none';
    if (el('mdDecorForm')) el('mdDecorForm').style.display = 'none';
    // 2A-4b: zamknute skupinove polia sa musia odomknut pre buduce "Novy dekor"
    if (el('nd_decor')) el('nd_decor').disabled = false;
    if (el('nd_decor_name')) el('nd_decor_name').disabled = false;
    if (el('nd_manufacturer')) el('nd_manufacturer').disabled = false;
  }

  // --- 2A-4b (audit B2): potvrdenie obnovy predmigracnej zalohy ------------
  function mdRestoreOpen(){ var m = el('mdRestoreModal'); if (m) m.style.display = 'flex'; }
  function mdRestoreClose(){ var m = el('mdRestoreModal'); if (m) m.style.display = 'none'; }
  function mdRestoreConfirm(){
    mdRestoreClose();
    if (window.sketchup && sketchup.restore_pre_schema2) sketchup.restore_pre_schema2('');
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
      demos_url: el('ms_demos_url').value,   // M-A3e (D-71): prazdne = zmazat vazbu
      color: hexToRgb(el('ms_color').value),
      family: el('ms_family').value,
      manufacturer: el('ms_manufacturer').value,
      allow_duplicate_code: mdDupAllow === 'sheet' // potvrdenie duplicitneho kodu (2. ulozenie)
    };
    // 2B-2 (GH #95 P2): rub polia idu do payloadu LEN pri type Zastena —
    // zmena typu formular len skryje, hodnoty by inak leteli na server a ten
    // by save odmietal kvoli poliam, ktore uz nie su vidiet.
    if (mdZastena(payload.type)){
      payload.back_decor = el('ms_back_decor').value;
      payload.back_structure = el('ms_back_structure').value;
    }
    // M-C: hranova uprava LEN pri type PD (vzor rub polia — skryte pole nesmie
    // letiet na server); prazdna hodnota = vedome "neurcena" (vymaze pole).
    if (mdPdType(payload.type) && el('ms_pd_edge')){
      payload.pd_edge_subtype = el('ms_pd_edge').value;
    }
    // D-19: format platne sa posiela LEN ako kompletny platny par; polovicny
    // alebo neplatny vstup zastavi ulozenie (ziadne tiche 0/reset — Codex F4).
    // M-A3e (audit FIX 4): zla adresa NEZATVARA formular — server ju sice
    // odmietne tiez, ale az po zavreti a prepis by prepadol.
    var due = mdDemosUrlLocalError(payload.demos_url);
    if (due){ MD.setStatus(due, true); return; }
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
      demos_url: el('me_demos_url').value,   // M-A3e (D-71): prazdne = zmazat vazbu
      color: hexToRgb(el('me_color').value),
      allow_duplicate_code: mdDupAllow === 'edge'
    };
    // M-A3e (audit FIX 4): zla adresa nezatvara formular (vzor mdSaveSheet).
    var due = mdDemosUrlLocalError(payload.demos_url);
    if (due){ MD.setStatus(due, true); return; }
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
      el('ms_demos_url').value = p.demos_url || ''; // M-A3e (audit FIX 2)
      if (el('ms_pd_edge')) el('ms_pd_edge').value = p.pd_edge_subtype || ''; // M-C
    } else {
      mdOpenEdgeForm(p.abs_id || null);
      el('me_decor').value = p.decor || ''; el('me_price').value = p.price_per_bm || '';
      el('me_code').value = p.code || ''; el('me_supplier').value = p.supplier || '';
      el('me_width').value = (p.width === null || p.width === undefined) ? '' : p.width;
      el('me_thickness').value = p.thickness || '1.0';
      if (p.color) el('me_color').value = rgbToHex(p.color);
      el('me_demos_url').value = p.demos_url || ''; // M-A3e (audit FIX 2)
    }
  }
  // V0.6 M-A2 (Halifax lekcia / audit F9): mazanie ide VZDY cez serverovy
  // preflight — modal ukaze presne CO sa maze (kod, cena, pouzitie v modeli)
  // a az potvrdenie posle skutocny delete. Guardy vyhodnoti server ZNOVA.
  var MD_DEL = null; // {kind, id} cakajuce potvrdenie
  function mdDeleteSheet(id){
    if (window.sketchup && sketchup.delete_preflight) sketchup.delete_preflight(JSON.stringify({ kind: 'sheet', id: id }));
  }
  function mdDeleteEdge(id){
    if (window.sketchup && sketchup.delete_preflight) sketchup.delete_preflight(JSON.stringify({ kind: 'edge', id: id }));
  }
  // Cista funkcia (Node test): riadky rozpisu modalu z preflight payloadu.
  // -> {lines: [text...], warn: text|null, block: text|null}
  function mdDeleteSummary(p){
    var lines = [];
    if (p.code) lines.push('Kód: ' + p.code + (p.supplier ? ' (' + p.supplier + ')' : ''));
    if (p.price != null && p.price !== '') lines.push('Cena: ' + p.price + (p.kind === 'edge' ? ' €/bm' : ' €/m²'));
    if (p.demos_url) lines.push('Má uloženú väzbu na Demos — po zmazaní sa stratí.');
    var warn = null, block = null;
    if (p.used_count > 0){
      warn = 'Používa sa v modeli (' + p.used_count + '×: ' + (p.used || []).join(', ') +
        (p.used_count > (p.used || []).length ? '…' : '') + ') — server mazanie odmietne.';
    }
    if (p.protected) block = 'Systémová predvoľba nových projektov — nedá sa zmazať.';
    else if (p.duplak_deps && p.duplak_deps.length) block = 'Na dosku sa odkazuje duplák ' + p.duplak_deps.join(', ') + ' — najprv zmaž duplák.';
    return { lines: lines, warn: warn, block: block };
  }
  function mdDeleteConfirm(){
    var d = MD_DEL;
    mdDeleteClose();
    if (!d || !window.sketchup) return;
    if (d.kind === 'edge'){
      if (sketchup.delete_edge) sketchup.delete_edge(JSON.stringify({ abs_id: d.id, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    } else if (sketchup.delete_sheet){
      sketchup.delete_sheet(JSON.stringify({ material_id: d.id, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
    }
  }
  function mdDeleteClose(){
    MD_DEL = null;
    var m = el('mdDeleteModal');
    if (m) m.style.display = 'none';
  }

  // --- V0.6 M-B2: „Nahradiť UNI…" — modal s výberom cieľa a rozpisom -------
  // Autorita je server (scan+klasifikácia+odtlačok plánu); JS len zbiera výber
  // a renderuje rozpis. Katalógové echo/init modal aj ponuku RUŠÍ (audit F6).
  var MD_UNI = null;          // { uni_id, key } otvoreného modalu
  var MD_UNI_PENDING = null;  // pending odtlačok aktuálnej ponuky zo servera

  // Čistá funkcia (Node test): kandidáti cieľa = non-UNI skupiny s doskami.
  function mdUniTargets(catalog, schema2){
    return groupCatalogByDecor(catalog || { sheets: [], edges: [] }, schema2)
      .filter(function(g){ return g.uni !== true && g.sheets.length; });
  }
  // Čistá funkcia (Node test): riadky rozpisu dopadu zo summary payloadu.
  function mdUniSummaryLines(s){
    var lines = [];
    var cabsN = (s.adopting_n || 0) + (s.recompute_n || 0);
    if (s.project && s.project.length) lines.push('Predvoľby projektu: ' + s.project.join(', ') + ' → ' + s.target_label);
    if (cabsN){
      var t = 'Skrinky: ' + cabsN + ' sa prepočíta';
      if (s.adopting_n) t += ', ' + s.adopting_n + ' prevezme hrúbku ' + fmtNum(s.target_th) + ' mm';
      lines.push(t);
    }
    (s.th_changes || []).forEach(function(t){ lines.push('Zmena hrúbky ' + t.change + ' mm: ' + t.n + '×'); });
    if (s.overrides_n) lines.push('Dielce s vlastným UNI materiálom: ' + s.overrides_n + '×');
    if (s.boards && s.boards.length){
      lines.push('Dosky: ' + s.boards.map(function(b){
        return b.bid + (b.from !== b.to ? ' (' + fmtNum(b.from) + '→' + fmtNum(b.to) + ' mm)' : '');
      }).join(', '));
    }
    var abs = s.abs || {};
    if (abs.changed) lines.push('ABS hrany sa prevedú na nový dekor (' + abs.changed + '×)');
    if (abs.lost_n){
      lines.push('ABS bez náhrady: ' + (abs.lost || []).join(', ') +
        (abs.lost_n > (abs.lost || []).length ? '…' : ''));
    }
    lines.push('Šablóny sa nemenia — sú globálna knižnica, nie projekt.');
    return lines;
  }

  function mdUniOpen(key){
    var g = mdGroupByKey(key);
    var us = g && g.sheets.filter(function(s){ return s.uni === true; })[0];
    if (!us) return;
    MD_UNI = { uni_id: us.material_id, key: key };
    MD_UNI_PENDING = null;
    var name = el('mdUniName');
    if (name) name.textContent = 'Nahradiť ' + (g.decor || 'UNI') + ' reálnym dekorom';
    var gsel = el('mdUniGroup');
    if (gsel){
      gsel.innerHTML = '';
      mdUniTargets(MD_CATALOG, MD_SCHEMA2).forEach(function(t){
        var o = document.createElement('option');
        o.value = t.key;
        o.textContent = (t.decor + ' ' + (t.decor_name || '')).trim() + (t.manufacturer ? ' · ' + t.manufacturer : '');
        gsel.appendChild(o);
      });
    }
    mdUniGroupChange();
    mdUniStep(1);
    var m = el('mdUniModal');
    if (m) m.style.display = '';
  }
  function mdUniGroupChange(){
    var gsel = el('mdUniGroup'), vsel = el('mdUniVariant');
    if (!gsel || !vsel) return;
    vsel.innerHTML = '';
    var g = mdGroupByKey(gsel.value);
    ((g && g.sheets) || []).filter(function(s){ return s.uni !== true; }).forEach(function(s){
      var o = document.createElement('option');
      o.value = s.material_id;
      var dim = sheetDimLabel(s);
      o.textContent = dim.dim + ' mm' + (dim.sub ? ' · ' + dim.sub : '');
      vsel.appendChild(o);
    });
  }
  function mdUniStep(n){
    var s1 = el('mdUniStep1'), s2 = el('mdUniStep2'), ok = el('mdUniConfirmBtn'), nx = el('mdUniNextBtn');
    if (s1) s1.style.display = n === 1 ? '' : 'none';
    if (s2) s2.style.display = n === 2 ? '' : 'none';
    if (ok) ok.style.display = n === 2 ? '' : 'none';
    if (nx) nx.style.display = n === 1 ? '' : 'none';
  }
  function mdUniPreview(){
    var vsel = el('mdUniVariant');
    if (!MD_UNI || !vsel || !vsel.value) return;
    if (window.sketchup && sketchup.replace_uni_preview){
      sketchup.replace_uni_preview(JSON.stringify({
        uni_id: MD_UNI.uni_id, target_id: vsel.value, model_guid: MD_MODEL_GUID }));
    }
  }
  function mdUniConfirm(){
    var pending = MD_UNI_PENDING;
    mdUniClose();
    if (pending && window.sketchup && sketchup.replace_uni_apply)
      sketchup.replace_uni_apply(JSON.stringify({ confirm: pending, model_guid: MD_MODEL_GUID }));
  }
  function mdUniClose(){
    MD_UNI = null;
    MD_UNI_PENDING = null;
    var m = el('mdUniModal');
    if (m) m.style.display = 'none';
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
    mdUniClose();     // M-B2 (audit F6): aj UNI modal s pending odtlackom
    MD_SHEETS = (data.materials && data.materials.sheets) ? data.materials.sheets : [];
    MD_CATALOG = data.catalog || { sheets: [], edges: [] };
    MD_PROTECTED = data.protected_ids || [];
    MD_REV = data.catalog_rev || '';
    // 2A-4b: rezim SERVEROVEHO katalogu (zoskupenie/toggle/banner) + nudzovy
    // read-only stav + pocet nepouzitelnych pasok — vsetko zo servera.
    MD_SCHEMA2 = (parseInt(data.catalog_schema, 10) || 0) >= 2;
    MD_RO = data.catalog_state === 'read_only';
    MD_RO_REASON = data.catalog_state_reason || '';
    MD_UNUSABLE = parseInt(data.unusable_edges, 10) || 0;
    MD_CUTOVER_ISSUE = (data.cutover_issue || '').toString();
    MD_HAS_BACKUP = data.pre_schema2_backup === true;
    mdRenderBanners();
    // GH P1: serverova schema sa NEpreberá do mutacii — klient posiela vlastnu
    // MD_CLIENT_SCHEMA konstantu (echo servera by falosne "povysilo" stare
    // okno bez novych poli); MD_SCHEMA2 je len ZOBRAZOVACI rezim.
    // D-44: naseptavace + navrhy formatu — jedna autorita (server), JS renderuje.
    // M-A3c (D-67): <datalist> nahradil vlastny suggest (CEF klik bug) —
    // dropdown cita MD_SUGGEST zivo pri otvoreni; otvoreny sa pri echu zavrie.
    MD_SUGGEST = data.suggest || { manufacturers: [], types: [] };
    MD_FORMAT_HINTS = data.format_hints || {};
    mdSgClose();
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
    resetProject: function(p){ mdClearPending(); mdSetProjectSelect(p.key, p.current); },
    // V0.6 M-A2 (audit F9): serverovy preflight mazania — modal s rozpisom.
    // Render VYHRADNE cez DOM API (textContent); potvrdenie posle skutocny
    // delete, guardy vyhodnoti server znova (preflight nie je autorita).
    confirmDelete: function(p){
      MD_DEL = { kind: p.kind, id: p.id };
      var body = el('mdDelBody');
      if (body){
        body.textContent = '';
        function div(cls, text){
          var d = document.createElement('div');
          if (cls) d.className = cls;
          d.textContent = text;
          body.appendChild(d);
        }
        div('mddel-name', p.label || p.id);
        var s = mdDeleteSummary(p);
        s.lines.forEach(function(t){ div('mddel-line', t); });
        if (s.warn) div('mddel-warn', s.warn);
        if (s.block) div('mddel-warn', s.block);
        if (!s.lines.length && !s.warn && !s.block) div('mddel-line', 'Bez kódu a ceny — nič sa nestratí.');
      }
      var btn = el('mdDelConfirmBtn');
      if (btn) btn.disabled = !!(p.protected || (p.duplak_deps && p.duplak_deps.length));
      var m = el('mdDeleteModal');
      if (m) m.style.display = '';
    },
    // V0.6 M-B2: odpoveď servera na „Nahradiť UNI…" — rozpis dopadu / blokácia
    // / nič na nahradenie. Render VÝHRADNE cez DOM API (textContent); autorita
    // potvrdenia je server (pending odtlačok plánu ide celý späť).
    replaceUniOffer: function(p){
      if (p.empty){
        mdUniClose();
        MD.setStatus(p.empty, false);
        return;
      }
      var body = el('mdUniBody');
      if (!body) return;
      body.textContent = '';
      function div(cls, text){
        var d = document.createElement('div');
        if (cls) d.className = cls;
        d.textContent = text;
        body.appendChild(d);
      }
      if (p.blocked){
        MD_UNI_PENDING = null;
        div('mddel-warn', 'Nahradenie je blokované — najprv vyrieš:');
        (p.blocked || []).forEach(function(t){ div('mddel-line', t); });
      } else {
        MD_UNI_PENDING = p.pending || null;
        if (p.stale) div('mddel-warn', 'Stav sa medzitým zmenil — toto je čerstvý rozpis, potvrď nanovo.');
        mdUniSummaryLines(p.summary || {}).forEach(function(t){ div('mddel-line', t); });
      }
      mdUniStep(2);
      var ok = el('mdUniConfirmBtn');
      if (ok) ok.style.display = MD_UNI_PENDING ? '' : 'none';
      var m = el('mdUniModal');
      if (m) m.style.display = '';
    }
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
      mdProjectSelectId: mdProjectSelectId, mdConfirmPayload: mdConfirmPayload,
      // 2A-4b (tests/js/test_md_schema2.js) — skupiny, sekcie struktur, batch 3
      mdGroupKeyOf: mdGroupKeyOf, mdStructureSections: mdStructureSections,
      mdBuildEdgeVariants: mdBuildEdgeVariants, mdParseExtraThs: mdParseExtraThs,
      mdParseExtraAbs: mdParseExtraAbs, mdEdgeBannerText: mdEdgeBannerText,
      sheetDimLabel: sheetDimLabel, mdGroupCommonStructure: mdGroupCommonStructure,
      // 2B-1 (tests/js/test_md_schema2.js) — duplak render bez DOM
      mdDuplakRow: mdDuplakRow, mdDuplakBtn: mdDuplakBtn, mdSectionRows: mdSectionRows,
      // 2B-2 — zastena (format-required helper, ciste funkcie)
      mdFormatRequired: mdFormatRequired, mdZastena: mdZastena,
      // V0.6 M-A2 — dlazdice s obrazkom + delete preflight (ciste funkcie)
      mdImageSrc: mdImageSrc, mdDeleteSummary: mdDeleteSummary,
      // M-A3b — vazby na Demos v UI (D-56/D-60/D-62/D-63)
      mdTileHtml: mdTileHtml, mdDateLabel: mdDateLabel, mdDemosBtn: mdDemosBtn,
      mdDetailHtml: mdDetailHtml,
      // M-A3c — editor variantov (D-67 suggest, D-68 gramatika + pruhy vynimiek)
      mdNormText: mdNormText, mdSuggestFilter: mdSuggestFilter,
      mdSplitExtraTokens: mdSplitExtraTokens, mdExtraKey: mdExtraKey,
      mdExtraFmtChips: mdExtraFmtChips,
      // M-A3e — rucna vazba (D-71): klientske zrkadlo serverovej validacie
      mdDemosUrlLocalError: mdDemosUrlLocalError,
      // M-B2 — „Nahradit UNI…" (ciste funkcie bez DOM)
      mdUniTargets: mdUniTargets, mdUniSummaryLines: mdUniSummaryLines };
  }
  if (typeof window !== 'undefined' && window.sketchup && sketchup.ready) sketchup.ready('');
