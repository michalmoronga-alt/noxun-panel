  // ===================== Materialy projektu =====================
  // Horna cast: 3 selecty projektovych predvolieb (korpus / cela / chrbat) —
  // hrubkovu kompatibilitu skriniek strazi Ruby pri ulozeni.
  // Davka 2 (D-05): sprava GLOBALNEHO katalogu (dosky + ABS). ID generuje SERVER
  // (JS ho nikdy nevymysla); create/edit su oddelene callbacky; hrubka
  // existujuceho materialu je nemenna (hrubka definuje variant).
  // Push zo servera NEZATVARA rozpisany formular (Codex audit) — prekresli len
  // zoznamy a selecty; editor stav zije oddelene v mdEditing.
  //
  // ŠT-2b: satelitne okno „Materiály projektu" ZANIKLO — tento subor bezi UZ LEN
  // ako SEKCIA `mat` okna Studio (`studio.html`), spolu s `demos_diff.js`
  // a `demos_add.js`. Co z presunu ostava platne:
  //   1. `window.NX_MAT_SECTION` (nastavuje studio.html) je explicitne
  //      prihlasenie sa do rezimu sekcie,
  //   2. LISTU kresli cista funkcia `matToolsHtml`, TELO `matRenderBody` —
  //      telo je JEDEN uzol, ktory prezije prepnutie sekcie (rozpisany
  //      formular ani rozpisana bunka sa nesmu stratit),
  //   3. dlhe behy (Demos pridat/aktualizovat) su viazane na SEKCIU: odchod
  //      z nej ich ZRUSI (`matOnLeaveSection` -> `mat_leave`) a modaly zavrie.
  // Pomocniky sa volaju `mdEl`/`mdEsc` (nie `el`/`esc`): v okne Studio bezi
  // tento subor vedla `studio.js` a `budget.js`, ktore maju vlastne `el`/`esc`
  // — rovnake meno by ticho prepisalo cudziu funkciu (guard test).

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
  // V0.6 M-C hranova uprava PD (pd_edge_subtype — schema 8); D-98 dekor u
  // dodavatela (supplier_decor — schema 9) => konstanta je 9.
  var MD_CLIENT_SCHEMA = 9;
  // 2B-2 (F10 zrkadlo registra): typy s formatom v identite — batch/formular
  // format VYZADUJU. Server je autorita (format_in_identity?), toto je UX.
  // D-73: + KOMPAKT (sirok vela ako PD — format je identita variantu).
  var MD_FORMAT_TYPES = ['PD', 'ZASTENA', 'KOMPAKT'];
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
  // D-97 (audit F4): KANONICKE typy z registra — SAMOSTATNE serverove pole,
  // NIE suggest.types (tie miesaju aj volne typy z katalogu, takze raz ulozeny
  // preklep „KD" by prestal byt „neznamy" a upozornenie by uz nikdy neprislo).
  var MD_KNOWN_TYPES = [];
  var MD_FORMAT_HINTS = {};
  var mdEditing = null;    // null | {kind:'sheet'|'edge', id:null|'...'}

  function mdEl(id){ return document.getElementById(id); }
  function mdEsc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

  function fillSelect(sel, sheets, current){
    // ŠT-2a: v sekcii Studia je telo ODPOJENE, kym je otvorena ina sekcia —
    // katalogove echo vtedy DOM nenajde a smie len aktualizovat premenne.
    if (!sel) return;
    var html = '';
    sheets.forEach(function(s){
      html += '<option value="'+mdEsc(s.id)+'">'+mdEsc(s.label)+'</option>';
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
  // ŠT-2c 2c-2b: `hexToRgb` ZANIKLA spolu s poľom farby v batch formulari —
  // farbu dnes posielaju obe zive cesty ako '#RRGGBB' (skupinovy swatch
  // `mdColorSave`, D-69 editor) a rozklad na [r,g,b] robi VYHRADNE server
  // (`parse_rgb`). Dva parsery tej istej hodnoty = dve pravdy o farbe.

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
    // D-98: dekor u dodavatela do toho isteho sub riadku ("4100×650 · dod. F8001")
    // — obchodne dolezity udaj, ale nesmie zabrat vlastny stlpec ani riadok.
    var sd = String(s.supplier_decor == null ? '' : s.supplier_decor).trim();
    if (sd) fmt = fmt ? fmt + ' · dod. ' + sd : 'dod. ' + sd;
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
      // D-98: dekor u dodavatela je objednavkove cislo — hladanie „F8001" musi
      // najst skupinu F800 (inak je alias v katalogu neviditelny).
      if (String(vs[i].supplier_decor || '').toLowerCase().indexOf(q) >= 0) return true;
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
  // ŠT-2a: dotaz hladania zije aj v PREMENNEJ, nielen v inpute. V sekcii
  // Studia je pole hladania v LISTE sekcie a listu prekresluje `studio.js`
  // pri kazdom pushi — bez zapamataneho dotazu by sa filter po prepocte ticho
  // vynuloval (a v mriezke by zrazu pribudli dekory, ktore pouzivatel odfiltroval).
  var MD_Q = '';
  // To iste plati pre zoskupenie dlazdic (vyrobca / A–Z) — v sekcii je select
  // v liste, ktoru prekresluje server.
  var MD_MODE = 'man';
  function mdGroupMode(){
    var s = mdEl('mdGroupMode');
    if (s && s.value) MD_MODE = s.value;
    return MD_MODE || 'man';
  }
  function mdQuery(){
    var s = mdEl('mdSearch');
    if (s) MD_Q = s.value;
    return (MD_Q || '').trim().toLowerCase();
  }
  function mdSearchInput(){
    mdView = null; // pisanie do hladania vzdy vracia do mriezky (vysledky)
    mdQuery();     // zapamataj dotaz (lista sekcie sa prekresluje zo servera)
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
    var ro = mdEl('mdRoBanner'), rt = mdEl('mdRoText');
    if (ro){
      ro.style.display = MD_RO ? 'flex' : 'none';
      if (rt && MD_RO){
        rt.textContent = 'Katalóg je len na čítanie — ' + (MD_RO_REASON || 'neznámy dôvod') +
          ' Zmeny sú vypnuté; obnov predmigračnú zálohu alebo oprav súbor a reštartuj SketchUp.';
      }
    }
    var eb = mdEl('mdEdgeBanner'), et = mdEl('mdEdgeBannerText');
    if (eb){
      eb.style.display = MD_UNUSABLE > 0 ? 'flex' : 'none';
      if (et && MD_UNUSABLE > 0) et.textContent = mdEdgeBannerText(MD_UNUSABLE);
    }
    // GH #93 P2 (4. kolo): cutover problem (poskodena zaloha / nerozhodnutelne
    // polozky) — zlty informacny pas; katalog bezi dalej, mutacie NEblokuje.
    var cb2 = mdEl('mdCutoverBanner'), ct2 = mdEl('mdCutoverBannerText');
    if (cb2){
      cb2.style.display = MD_CUTOVER_ISSUE ? 'flex' : 'none';
      if (ct2 && MD_CUTOVER_ISSUE) ct2.textContent = MD_CUTOVER_ISSUE;
    }
    var nb = mdEl('mdNewDecorBtn');
    if (nb) nb.disabled = MD_RO;
    // GH #102 P2: aj primarna Demos cesta je katalogova mutacia — v read-only
    // rezime sa vypina rovnako ako rucny batch (server by create odmietol az
    // po celom fetchovani rodiny).
    var db = mdEl('mdDemosAddBtn');
    if (db) db.disabled = MD_RO;
    // GH #93 P2 (10. kolo): rollback aj pri zdravej SCHEMA 2 (zaloha existuje);
    // v read-only stave ho nesie nudzovy banner, tu by bol duplicitny.
    var rb = mdEl('mdRestoreBtn');
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
    var box = mdEl('mdDecorList');
    if (!box) return;
    var q = mdQuery();
    // detail drzi len existujucu skupinu (po rename/zmazani spadne na mriezku)
    if (mdView !== null){
      var dg = mdGroupByKey(mdView);
      if (dg){ box.innerHTML = mdDetailHtml(dg); mdFocusInline(); return; }
      mdView = null;
    }
    var groups = groupCatalogByDecor(MD_CATALOG, MD_SCHEMA2).filter(function(g){ return mdMatchGroup(g, q); });
    var mode = mdGroupMode();
    var sections = mdBuildSections(groups, MD_USED, mode, q);
    var html = '';
    sections.forEach(function(sec){
      if (sec.title){
        html += '<div class="mdsechead">' +
          (sec.kind === 'used' ? '<svg class="ic" aria-hidden="true"><use href="#i-check"/></svg>'
            : sec.kind === 'uni' ? '<svg class="ic" aria-hidden="true"><use href="#i-layers"/></svg>'
                                 : '<svg class="ic" aria-hidden="true"><use href="#i-factory"/></svg>') +
          ' ' + mdEsc(sec.title) + '</div>';
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
    g.sheets.forEach(function(s){ chips += '<span class="vchip">' + mdEsc(sheetChipLabel(s)) + '</span>'; });
    g.edges.forEach(function(a){ chips += '<span class="vchip vchip-abs">' + mdEsc(edgeChipLabel(a)) + '</span>'; });
    // V0.6 M-A2: realna fotka dekoru zo stiahnutej cache; pri chybe suboru
    // inline onerror (bez dat) schova <img> a ostane fallback farba swatchu.
    var sw = '<i class="mdsw" style="background:' + mdEsc(rgbToHex(g.color)) + '">' +
      (g.image ? '<img class="mdsw-photo" src="' + mdEsc(mdImageSrc(g.image)) + '" alt="" onerror="this.style.display=\'none\'">' : '') +
      '</i>';
    // M-A3b: D-63 plny nazov v tooltipe (dvojriadkovy clamp ho moze orezat);
    // D-56 badge vazby na Demos (aspon 1 variant s ulozenou URL).
    var full = name + ' · ' + (g.manufacturer || 'vlastný');
    return '<div class="mdtile" title="' + mdEsc(full) + '" onclick="mdOpenDetail(' + mdEsc(JSON.stringify(g.key)) + ')">' +
      '<div class="mdtile-head">' +
      sw +
      '<span class="mdtile-name"><b>' + mdEsc(name) + '</b>' +
      '<span class="mans">' + mdEsc(sub) + '</span></span>' +
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
    return '<button class="mduni mddm" title="' + mdEsc(title) + '" aria-label="Otvoriť u dodávateľa"' +
      ' onclick="mdDemosOpen(\'' + kind + '\', \'' + mdEsc(id) + '\')">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-external-link"/></svg></button>';
  }
  function mdDemosOpen(kind, id){
    if (window.sketchup && sketchup.open_demos_url)
      sketchup.open_demos_url(JSON.stringify({ kind: kind, id: id }));
  }

  // --- D-82: farba dekoru = vlastnost SKUPINY -----------------------------
  // Doteraz ju niesol KAZDY variant zvlast (vlastne pole vo formulari dosky aj
  // pasky) — nikto ju neprepisoval po jednom, takze katalog ostal "hnede more".
  // Teraz sa meni RAZ pre cely dekor a nove varianty (aj z Demosu) ju dedia.
  // Ovladac je priamo SWATCH v hlavicke detailu: native paleta lezi cez neho
  // neviditelne, takze hlavicka nerastie do vysky (vertikalny priestor).
  // Cista funkcia (Node test): true = farba sa v tejto skupine da menit.
  function mdColorEditable(g, ro){
    return !!g && !ro && g.uni !== true && g.decor !== '';
  }
  function mdGroupSwatch(g){
    var photo = g.image
      ? '<img class="mdsw-photo" src="' + mdEsc(mdImageSrc(g.image)) + '" alt="" onerror="this.style.display=\'none\'">'
      : '';
    var bg = ' style="background:' + mdEsc(rgbToHex(g.color)) + '"';
    if (!mdColorEditable(g, MD_RO)){
      // UNI (farba rozlisuje rolu — server ju chrani) a read-only rezim:
      // swatch ostava len ukazkou, ziadna paleta.
      var t = g.uni === true ? ' title="UNI má farbu podľa role — nemení sa"' : '';
      return '<i class="mdsw mdsw-lg"' + bg + t + '>' + photo + '</i>';
    }
    return '<label class="mdsw mdsw-lg mdswpick"' + bg +
      ' title="Farba dekoru — platí pre celú skupinu (dosky aj ABS)">' + photo +
      '<input type="color" id="md_group_color" value="' + mdEsc(rgbToHex(g.color)) + '"' +
      ' aria-label="Farba dekoru — platí pre celú skupinu"' +
      ' onchange="mdColorSave(' + mdEsc(JSON.stringify(g.key)) + ', this.value)"></label>';
  }
  function mdColorSave(key, hex){
    var g = mdGroupByKey(key);
    if (!g) return;
    if (window.sketchup && sketchup.set_decor_color)
      sketchup.set_decor_color(JSON.stringify({ decor: g.decor, color: hex,
        group_id: g.gid || '', catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
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
      // D-82: swatch je zaroven SKUPINOVY vyber farby (bez noveho riadku).
      mdGroupSwatch(g) +
      '<span class="tpln"><b>' + mdEsc(name) + '</b>' + (g.manufacturer ? ' <span class="tplt">' + mdEsc(g.manufacturer) + '</span>' : '') +
      (g.uni ? ' <span class="mdunib">UNI</span>' : '') + '</span>' +
      // V0.6 M-B2: hromadna zamena UNI za realny dekor (nazov drzat presne —
      // semafor ORANGE „material neurceny" nan odkazuje textom).
      (g.uni ? '<button class="primary tplbtn"' + dis + ' title="' + mdEsc(mdUniTip()) + '" onclick="mdUniStart(' + mdEsc(JSON.stringify(g.key)) + ')">Nahradiť UNI…</button>' : '') +
      (g.decor === '' ? '' :
        // ŠT-2c 2c-2a (D-69): JEDEN formular na cely dekor — kod, nazov,
        // vyrobca, farba, dosky aj pasky naraz. UNI ho nedostava (pracovny
        // material sa nahradza, needituje) a v legacy katalogu (SCHEMA 1) tiez
        // nie: formular stoji na `group_id`, ktore vtedy neexistuje — rovnaka
        // brana ako pri susednom „Názov" (review #4). Doterajsie jednoucelove
        // cesty (Výrobca/Názov/Premenovať) ostavaju do 2c-2b.
        (g.uni || !MD_SCHEMA2 ? '' :
          '<button class="ghostbtn tplbtn"' + dis + ' title="Upraviť celý dekor — kód, názov, výrobca, farba, dosky aj ABS"' +
          ' onclick="mdEditOpen(' + mdEsc(JSON.stringify(g.key)) + ')">Upraviť…</button>') +
        '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdOpenDecorForm(' + mdEsc(JSON.stringify(g.key)) + ')">+ variant</button>' +
        '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdManufacturerOpen(' + mdEsc(JSON.stringify(g.key)) + ')">Výrobca</button>' +
        (MD_SCHEMA2 ? '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdNameOpen(' + mdEsc(JSON.stringify(g.key)) + ')">Názov</button>' : '') +
        '<button class="ghostbtn tplbtn"' + dis + ' onclick="mdRenameOpen(' + mdEsc(JSON.stringify(g.key)) + ')">Premenovať</button>' +
        // V0.6 B-2b (N17): ikonove tlacidlo v EXISTUJUCOM rade akcii (vertikalny
        // priestor) — lookup kodov a cien celej dekorovej skupiny na Demose.
        '<button class="ghostbtn tplbtn"' + dis + ' title="' + mdEsc(mdDemosUpdateTip()) + '" aria-label="Aktualizovať z Demosu" onclick="mdDemosUpdate(' + mdEsc(JSON.stringify(g.key)) + ')"><svg class="ic" aria-hidden="true"><use href="#i-refresh-cw"/></svg></button>') +
      '</div>';
    // GH #93 P2: editacia NAZVU skupiny (decor_name — zobrazovacia vlastnost,
    // meni sa atomicky celej skupine cez group_id; prazdny nazov = vymazanie).
    if (mdNaming === g.key && MD_SCHEMA2){
      h += '<div class="tplrow"><input id="md_gname_input" type="text" value="' + mdEsc(g.decor_name || '') + '" placeholder="Názov skupiny (napr. Dub Halifax)" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdNameSave(' + mdEsc(JSON.stringify(g.key)) + ')">Uložiť</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdNameOpen(null)">Zrušiť</button></div>';
    }
    if (mdManufacturing === g.key){
      // D-44: naseptavac (datalist mdManList) + VLASTNE tlacidlo na vymazanie —
      // prazdny input uz vyrobcu nezmaze (server odmietne bez flagu, audit F9).
      h += '<div class="tplrow"><input id="md_man_input" type="text" value="' + mdEsc(g.manufacturer || '') + '" placeholder="Výrobca (napr. Egger)" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdManufacturerSave(' + mdEsc(JSON.stringify(g.key)) + ')">Uložiť</button>' +
        (g.manufacturer ? '<button class="ghostbtn tpldel" title="Zmazať výrobcu" aria-label="Zmazať výrobcu" onclick="mdManufacturerClear(' + mdEsc(JSON.stringify(g.key)) + ')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>' : '') +
        '<button class="ghostbtn tplbtn" onclick="mdManufacturerOpen(null)">Zrušiť</button></div>';
    }
    if (mdRenaming === g.key){
      h += '<div class="tplrow"><input id="md_rename_input" type="text" value="' + mdEsc(g.decor) + '" style="flex:1">' +
        '<button class="primary tplbtn" onclick="mdRenameSave(' + mdEsc(JSON.stringify(g.key)) + ')">Uložiť</button>' +
        '<button class="ghostbtn tplbtn" onclick="mdRenameOpen(null)">Zrušiť</button></div>';
    }
    var sections = mdStructureSections(g);
    var multi = sections.length > 1 || (sections.length === 1 && sections[0].key !== '');
    sections.forEach(function(sec){
      if (multi) h += '<div class="mdstsec">' + mdEsc(sec.title || 'Bez štruktúry') + '</div>';
      h += mdSectionRows(sec);
    });
    if (!sections.length) h += '<div class="muted">žiadne varianty</div>';
    h += mdWhereHtml(g, mdWhereOf(g));
    h += '</div>';
    return h;
  }

  // ============ ŠT-2d: „Kde sa používa" (schvaleny bod konceptu) ============
  // Detail dekoru odpoveda na otazku „kde presne je tento dekor v zakazke" —
  // vlastnik (skrinka alebo samostatna doska), ktore dielce to su a kolko ich
  // je. „Oko" ich OZNACI V MODELI.
  //
  // Cisla ani texty rol si klient NERATA — cely rozpis chodí zo servera
  // (`ST.mat.used_where`), z TOHO ISTEHO zberu ako Kusovnik. Adresa vyberu su
  // `material_id`/`abs_id` (EFEKTIVNY material zo snapshotu), takze sa oznaci
  // aj dielec, ktory material iba DEDI po korpuse.
  function mdWhereOf(g){
    return MD_USED_WHERE[mdUsageKey(g)] || null;
  }

  // Slovenske sklonovanie (cisto zobrazovacia vec klienta — ziadne cislo).
  function mdPartsSk(n){
    var v = Number(n) || 0;
    if (v === 1) return '1 dielec';
    if (v >= 2 && v <= 4) return v + ' dielce';
    return v + ' dielcov';
  }

  // Review #6: „položka" je to, co sa OZNACI V MODELI — rovnake slovo, akym
  // to potvrdi stavovy riadok („Vybraných N položiek v modeli.").
  function mdItemsSk(n){
    var v = Number(n) || 0;
    if (v === 1) return '1 položku';
    if (v >= 2 && v <= 4) return v + ' položky';
    return v + ' položiek';
  }

  // Pocet v riadku. KUSY a OZNACENE OBJEKTY nie su to iste: doska s
  // `quantity: 3` je 3 kusy do vyroby, ale v modeli je JEDEN objekt. Kym sa
  // cisla rovnaju (bezny dielec), ukaze sa len jedno; ked nie, priznaju sa
  // obe — inak by riadok slubil „3 dielce" a stavovy riadok po kliku napisal
  // „Vybraných 1 položiek", co vyzera ako chyba vyberu.
  function mdWhereCount(parts, objects){
    var p = Number(parts) || 0;
    var o = Number(objects);
    if (!o || o === p) return mdPartsSk(p);
    return p + ' ks · ' + (o === 1 ? '1 objekt' : (o >= 2 && o <= 4 ? o + ' objekty' : o + ' objektov'));
  }

  // Cista funkcia (Node test): rozpis pouzitia -> HTML. Prazdny rozpis kresli
  // priznanu hlasku — „nic tu nie je" musi byt VIDNO, inak by pouzivatel
  // hladal chybajucu sekciu.
  function mdWhereHtml(g, where){
    var owners = (where && where.owners) || [];
    var edges = (where && where.edges) || {};
    var absIds = Object.keys(edges).filter(function(id){
      return Number((edges[id] || {}).parts) > 0;
    });
    var h = '<div class="mdsec mdwhead">Kde sa používa</div>';
    if (!owners.length && !absIds.length){
      return h + '<div class="muted mdwempty">Tento dekor sa v zákazke zatiaľ nepoužíva.</div>';
    }
    owners.forEach(function(o){
      var roles = (o.roles || []).join(' · ');
      h += '<div class="mdwrow"><span class="mdwn"><b>' + mdEsc(o.owner_id || '') + '</b>' +
        // Oddelovac „·" presne ako mockup („CAB-004 · boky, dno, police").
        (roles ? ' <span class="mdwr">· ' + mdEsc(roles) + '</span>' : '') + '</span>' +
        '<span class="mdwq">' + mdEsc(mdWhereCount(o.parts, o.objects)) + '</span>' +
        '<span class="mdwact">' + mdWhereEyeHtml('mdWhereOwner', g.key, o.owner_id,
                                                 'Označiť v modeli — označí ' + mdItemsSk(o.objects)) +
        '</span></div>';
    });
    absIds.forEach(function(id){
      var rec = (g.edges || []).filter(function(a){ return a.abs_id === id; })[0];
      var label = rec ? edgeChipLabel(rec) : id;
      var e = edges[id] || {};
      h += '<div class="mdwrow"><span class="mdwn">Páska <b>' + mdEsc(label) + '</b></span>' +
        '<span class="mdwq">' + mdEsc(mdWhereCount(e.parts, e.objects)) + '</span>' +
        '<span class="mdwact">' + mdWhereEyeHtml('mdWhereEdge', g.key, id,
                                                 'Označiť dielce s touto páskou — označí ' + mdItemsSk(e.objects)) +
        '</span></div>';
    });
    return h;
  }

  function mdWhereEyeHtml(fn, key, arg, title){
    return '<button class="mdweye" title="' + mdEsc(title) + '" aria-label="' + mdEsc(title) + '"' +
      ' onclick="' + fn + '(' + mdEsc(JSON.stringify(key)) + ', ' + mdEsc(JSON.stringify(String(arg == null ? '' : arg))) + ')">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-eye"/></svg></button>';
  }

  // Klik „oko": posle sa TA ISTA cesta, akou vyberá Kusovnik (`nx_select`
  // cez relay panela) — cize s generaciou okna. Server si dielce dohlada
  // v CERSTVOM zbere; ziadne pids z DOM sa neposielaju.
  function mdWhereSelect(payload){
    var st = (typeof ST === 'undefined') ? null : ST;
    if (!st || !window.sketchup || !sketchup.nx_select) return;
    payload.gen = st.gen || 0;
    sketchup.nx_select(JSON.stringify(payload));
  }

  function mdWhereOwner(key, ownerId){
    var g = mdGroupByKey(key);
    var where = g ? mdWhereOf(g) : null;
    var o = ((where && where.owners) || []).filter(function(x){ return String(x.owner_id) === String(ownerId); })[0];
    if (!o) return;
    // Adresa je zoznam `material_id`, ktore ma TENTO vlastnik z TEJTO skupiny
    // (dekor mava viac hrubkovych variantov) — zuzeny na jeho `owner_id`.
    mdWhereSelect({ material_key: o.material_ids || [], owner_id: o.owner_id });
  }

  function mdWhereEdge(key, absId){
    if (!absId) return;
    mdWhereSelect({ abs_key: absId });
  }

  // Deep-link z karty dielca/dosky (`openStudio('mat', <material_id|kluc>)`).
  // Cista funkcia (Node test): kotva -> kluc skupiny. Tolerantna zamerne —
  // panel posiela `material_id` (jedina identita, ktoru o materiali dielca
  // ISTO ma), ale kluc skupiny sa prijme tiez, aby sa deep-link dal poslat
  // aj zvnutra Studia.
  function mdAnchorGroupKey(groups, anchor){
    var a = String(anchor == null ? '' : anchor).trim();
    if (!a) return null;
    var hit = null;
    (groups || []).forEach(function(g){
      if (hit) return;
      if (g.key === a || g.usage_key === a || g.gid === a) hit = g.key;
    });
    if (hit) return hit;
    (groups || []).forEach(function(g){
      if (hit) return;
      var vs = (g.sheets || []).concat(g.edges || []);
      for (var i = 0; i < vs.length; i++){
        if (vs[i].material_id === a || vs[i].abs_id === a){ hit = g.key; return; }
      }
    });
    return hit;
  }

  // Spotreba kotvy: otvori DETAIL dekoru. Volá ju `studio.js` PRED renderom
  // (kotva chodi so sekciou a je JEDNORAZOVA), takze sa tu nekresli —
  // `matRenderBody` uz nakresli detail.
  function matOpenAnchor(anchor){
    var key = mdAnchorGroupKey(groupCatalogByDecor(MD_CATALOG, MD_SCHEMA2), anchor);
    if (!key) return false;
    MD_Q = '';                       // detail nesmie prekryt cudzi filter
    var s = mdEl('mdSearch');
    if (s) s.value = '';
    mdView = key;
    return true;
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
        var dim = mdEsc(dl.dim) + (dl.sub ? '<small>' + mdEsc(dl.sub) + '</small>' : '');
        // 2B-1 (D-43): duplak nema editovatelne bunky — vsetko derivuje zo
        // zdroja (server edit/patch odmietne); riadok ukazuje vazbu + delete.
        if (s.source_material_id){
          h += mdDuplakRow(s, dim);
        } else {
          h += mdVariantRow('sheet', s.material_id, s.row_rev, dim,
            s.code, s.price_per_m2, s.supplier, s.label,
            'mdOpenSheetForm(\'' + mdEsc(s.material_id) + '\')',
            prot ? null : 'mdDeleteSheet(\'' + mdEsc(s.material_id) + '\')', prot,
            mdDuplakBtn(s) + mdDemosBtn('sheet', s.material_id, s));
        }
      });
    }
    if (sec.edges.length){
      h += '<div class="mdsec">ABS pásky</div>';
      h += '<div class="mdvhead"><span class="mdvdim"></span><span class="mdvi">Kód</span><span class="mdvi mdvp">€/bm</span><span class="mdvi">Dodávateľ</span><span class="mdvact"></span></div>';
      sec.edges.forEach(function(a){
        h += mdVariantRow('edge', a.abs_id, a.row_rev, mdEsc(edgeChipLabel(a)),
          a.code, a.price_per_bm, a.supplier, a.label,
          'mdOpenEdgeForm(\'' + mdEsc(a.abs_id) + '\')',
          'mdDeleteEdge(\'' + mdEsc(a.abs_id) + '\')', false,
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
      ' onclick="mdUniToggle(this, \'' + mdEsc(a.abs_id) + '\', ' + (on ? 'false' : 'true') + ', \'' + mdEsc(a.row_rev || '') + '\')">' +
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
    return '<div class="mdvrow" title="' + mdEsc(s.label || '') + '">' +
      '<span class="mdvdim">' + dimHtml + '</span>' +
      '<span class="mdvi mdvdup" title="Duplák: lepí sa z ' + s.source_multiplier + '× zdrojovej dosky — nakupuje a oceňuje sa zdroj">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-layers"/></svg> lepené ' + s.source_multiplier + '× z ' + mdEsc(s.source_material_id) + '</span>' +
      '<span class="mdvact">' +
      '<button class="ghostbtn tpldel"' + dis + ' title="Zmazať duplák" aria-label="Zmazať duplák" onclick="mdDeleteSheet(\'' + mdEsc(s.material_id) + '\')"><svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button>' +
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
      ' aria-label="Vytvoriť duplák" onclick="mdCreateDuplak(\'' + mdEsc(s.material_id) + '\')">' +
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
    return '<input class="mdcell ' + extraCls + '" type="text" value="' + mdEsc(v) + '" placeholder="' + ph + '"' +
      (MD_RO ? ' readonly' : '') +
      ' data-kind="' + kind + '" data-id="' + mdEsc(id) + '" data-field="' + field + '" data-rev="' + mdEsc(rev || '') + '"' +
      ' data-orig="' + mdEsc(v) + '" onblur="mdCellFlush(this)" onkeydown="mdCellKey(event, this)">';
  }
  // dimHtml je UZ escapovane (moze niest <small> formatu dosky); extra = dalsi
  // ovladaci prvok pred akciami (universal toggle ABS).
  function mdVariantRow(kind, id, rev, dimHtml, code, price, supplier, title, editCall, delCall, prot, extra){
    var priceField = kind === 'edge' ? 'price_per_bm' : 'price_per_m2';
    var dis = MD_RO ? ' disabled' : '';
    return '<div class="mdvrow" title="' + mdEsc(title || '') + '">' +
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
    var ri = mdEl('md_rename_input');
    if (ri){ ri.focus(); ri.select(); return; }
    var gi = mdEl('md_gname_input');
    if (gi){ gi.focus(); gi.select(); return; }
    var mi = mdEl('md_man_input');
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
    var input = mdEl('md_gname_input');
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
    var input = mdEl('md_rename_input');
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
    var mi = mdEl('md_man_input'); if (mi){ mi.focus(); mi.select(); }
  }
  function mdManufacturerSave(key){
    var input = mdEl('md_man_input');
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

  // === ŠT-2c PR 2c-2a: D-69 JEDNOTNY EDITOR DEKORU („Upraviť…") =============
  //
  // JEDEN formular na cely dekor: identita skupiny + riadky dosiek + riadky
  // ABS. Vsetko odchadza JEDNOU akciou `save_decor`, ktorú server zapisuje
  // ATOMICKY (jeden zamok, validate-all, jeden write) — katalog cien realnych
  // objednavok sa nesmie ulozit „spolovice".
  //
  // BASELINE SA ZMRAZUJE PRI OTVORENI (audit ŠT-2c #1). `MD_REV` je ZIVA
  // premenna, ktorú prepise KAZDE katalogove echo; keby ju formular cital az
  // pri odoslani, guard by po cudzom zapise „omladol" a editor by prepisal
  // zmenu, ktorú pouzivatel nikdy nevidel. Odtlacok KAZDEHO riadku (`row_rev`)
  // ide so skrytymi polami riadku, takze konflikt sa pozna aj per zaznam.
  var mdEditBase = null;   // { key, gid, rev, decor } — snimok z CASU OTVORENIA
  // Suhlas s duplicitnym kodom je viazany na PRESNE TIE hodnoty, pri ktorych
  // ho server vypytal (review #5). Blanket suhlas „uz som raz potvrdil" by
  // prepustil aj duplicitu, ktoru pouzivatel vyrobil az potom — a nakupny
  // zoznam by mal dva rozne materialy pod jednym kodom.
  var mdEditDupSnap = null;

  // Kostra D-15 zije v `window.NXModal` (nacita ju `studio.html`). Pristupovy
  // bod je funkcia, aby sa dal subor requirovat aj v Node testoch bez okna.
  function mdModal(){
    return (typeof window !== 'undefined' && window.NXModal) ? window.NXModal : null;
  }

  // Konvencia kluca pamate D-15: `<domena>:<mode>:<ciel>` — slot je `mat:edit`,
  // takze otvorenie editora INEHO dekoru stary rozpis zahodi (inak by sa
  // hodnoty dekoru A predvyplnili do dekoru B).
  function mdEditKey(g){ return 'mat:edit:' + (g.gid || g.decor); }

  // Cislo do pola formulara: prazdne ostava prazdne (cena NEZADANA nie je 0)
  // a desatinna ciarka je SK zapis, ktory server aj tak parsuje oboma sposobmi.
  function mdEditNum(v){
    if (v === null || v === undefined || v === '') return '';
    var f = parseFloat(v);
    if (isNaN(f)) return String(v);
    return String(f === Math.round(f) ? Math.round(f) : f).replace('.', ',');
  }

  function mdEditSheetRow(s){
    return { material_id: s.material_id, row_rev: s.row_rev || '',
             type: String(s.type || ''), thickness: mdEditNum(s.thickness),
             sheet_size: (s.sheet_size && s.sheet_size.length === 2)
               ? mdEditNum(s.sheet_size[0]) + '×' + mdEditNum(s.sheet_size[1]) : '',
             code: String(s.code || ''), price_per_m2: mdEditNum(s.price_per_m2) };
  }

  function mdEditEdgeRow(a){
    return { abs_id: a.abs_id, row_rev: a.row_rev || '',
             width: mdEditNum(a.width), thickness: mdEditNum(a.thickness),
             code: String(a.code || ''), price_per_bm: mdEditNum(a.price_per_bm) };
  }

  // STLPCE REPEATEROV — JEDNA definicia pre OBA vstupy D-69 („Upraviť…" aj
  // „Pridať ručne"). Dve kopie by znamenali dva formulare, ktore sa casom
  // rozidu — presne to, co D-69 rusi („rovnaké polia bez ohľadu na vstup").
  // `roWhen` zamyka IDENTITNE pole EXISTUJUCEHO riadku (server takú zmenu aj
  // tak odmietne, UI ju nema PROVOKOVAT); novy riadok ID nenesie, takze
  // v prázdnom formulari je editovatelne vsetko.
  function mdSheetCols(){
    return [
      { key: 'type', label: 'Typ', cls: 'mtiny', roWhen: 'material_id',
        roTitle: 'Typ dosky definuje variant — pre iný typ pridaj nový riadok.' },
      { key: 'thickness', label: 'Hrúbka', cls: 'mtiny', roWhen: 'material_id',
        roTitle: 'Hrúbka definuje variant — pre inú hrúbku pridaj nový riadok.' },
      { key: 'sheet_size', label: 'Formát', cls: 'mshort', placeholder: '2800×2070' },
      { key: 'code', label: 'Kód', placeholder: 'kód dodávateľa' },
      { key: 'price_per_m2', label: '€/m²', cls: 'mtiny', placeholder: '—' }
    ];
  }
  function mdEdgeCols(){
    return [
      { key: 'width', label: 'Šírka', cls: 'mtiny', roWhen: 'abs_id',
        roTitle: 'Šírka definuje variant pásky — pre inú šírku pridaj nový riadok.' },
      { key: 'thickness', label: 'Hrúbka', cls: 'mtiny', roWhen: 'abs_id',
        roTitle: 'Hrúbka definuje variant pásky — pre inú hrúbku pridaj nový riadok.' },
      { key: 'code', label: 'Kód', placeholder: 'kód dodávateľa' },
      { key: 'price_per_bm', label: '€/bm', cls: 'mtiny', placeholder: '—' }
    ];
  }

  // Cista funkcia (Node test): skupina -> polia D-15 modalu.
  // Duplaky sa v editore nezobrazuju vobec — vsetko derivuju zo zdrojovej
  // dosky a nemaju co editovat.
  function mdEditFields(g){
    var sheets = (g.sheets || []).filter(function(s){ return !s.source_material_id; });
    var edges = g.edges || [];
    return [
      { type: 'group', label: 'Dekor', hint: 'platí pre celú skupinu' },
      { key: 'decor', label: 'Číslo dekoru', value: String(g.decor || '') },
      { key: 'decor_name', label: 'Názov', value: String(g.decor_name || ''),
        placeholder: 'napr. Dub Halifax' },
      { key: 'manufacturer', label: 'Výrobca', value: String(g.manufacturer || ''),
        placeholder: 'napr. Egger' },
      { key: 'color', label: 'Farba', type: 'color', value: rgbToHex(g.color) },
      { type: 'group', label: 'Dosky', hint: 'typ a hrúbka určujú variant' },
      { key: 'sheets', type: 'rows', addLabel: 'Pridať dosku', empty: 'Zatiaľ žiadna doska.',
        hidden: ['material_id', 'row_rev'], rowKey: 'material_id',
        cols: mdSheetCols(),
        value: sheets.map(mdEditSheetRow) },
      { type: 'group', label: 'ABS pásky', hint: 'šírka a hrúbka určujú variant' },
      { key: 'edges', type: 'rows', addLabel: 'Pridať pásku', empty: 'Zatiaľ žiadna páska.',
        hidden: ['abs_id', 'row_rev'], rowKey: 'abs_id',
        cols: mdEdgeCols(),
        value: edges.map(mdEditEdgeRow) }
    ];
  }

  // === 2c-2b: „Pridať ručne" — TEN ISTY formular, len prazdny ===============
  //
  // Rozdiely oproti editu su presne dva a oba su vlastnostou ZAKLADANIA:
  //   * identita skupiny je EDITOVATELNA cela (pri edite je cislo dekoru
  //     a vyrobca tiez editovatelny, ale riadky su zamknute svojou identitou),
  //   * pribudaju dve SKUPINOVE polia, ktore uz existujuca skupina ma a nova
  //     ich nema odkial vziat: ŠTRUKTÚRA povrchu (je sucastou identity
  //     variantu — dopisat sa uz NEDA) a SMER DEKORU (default novych dosiek).
  function mdCreateFields(){
    return [
      { type: 'group', label: 'Dekor', hint: 'platí pre celú skupinu' },
      { key: 'decor', label: 'Číslo dekoru', value: '', placeholder: 'napr. H3303' },
      { key: 'decor_name', label: 'Názov', value: '', placeholder: 'napr. Dub Halifax' },
      { key: 'manufacturer', label: 'Výrobca', value: '', placeholder: 'napr. Egger' },
      { key: 'structure', label: 'Štruktúra', value: '', placeholder: 'napr. ST10 / PW' },
      { key: 'grain', type: 'select', label: 'Smer dekoru', value: 'length',
        options: [['length', 'Po dĺžke'], ['width', 'Po šírke'], ['none', 'Bez smeru']] },
      { key: 'color', label: 'Farba', type: 'color', value: rgbToHex(null) },
      { type: 'group', label: 'Dosky', hint: 'typ a hrúbka určujú variant' },
      { key: 'sheets', type: 'rows', addLabel: 'Pridať dosku',
        empty: 'Zatiaľ žiadna doska — pridaj aspoň jednu.',
        hidden: ['material_id', 'row_rev'], rowKey: 'material_id',
        cols: mdSheetCols(), value: [] },
      { type: 'group', label: 'ABS pásky', hint: 'šírka a hrúbka určujú variant' },
      { key: 'edges', type: 'rows', addLabel: 'Pridať pásku', empty: 'Zatiaľ žiadna páska.',
        hidden: ['abs_id', 'row_rev'], rowKey: 'abs_id',
        cols: mdEdgeCols(), value: [] }
    ];
  }

  // (audit ŠT-2c #18) Otvorenie editora ZAHADZUJE rozpisane inline bunky toho
  // isteho dekoru. Dva rozpisane stavy tej istej ceny (bunka + formular) by sa
  // navzajom prepisali podla toho, kam pouzivatel nahodou klikne — a jeden
  // z nich by bol cena, o ktorej uz nevie, ze ju pisal. Vrati POCET zahodenych.
  function mdEditDropDirty(g){
    if (typeof document === 'undefined' || !document.querySelectorAll) return 0;
    var ids = {};
    (g.sheets || []).forEach(function(s){ ids[s.material_id] = true; });
    (g.edges || []).forEach(function(a){ ids[a.abs_id] = true; });
    var cells = document.querySelectorAll('.mdcell');
    var n = 0;
    for (var i = 0; i < cells.length; i++){
      var c = cells[i];
      if (!ids[c.getAttribute('data-id')]) continue;
      var orig = c.getAttribute('data-orig') || '';
      if (String(c.value) === orig) continue;
      c.value = orig; // blur uz nema co poslat (mdCellFlush porovnava s data-orig)
      n++;
    }
    return n;
  }

  // Cista funkcia (Node test): hodnoty modalu -> payload servera.
  function mdEditPayload(v, base){
    var d = v || {};
    return { mode: 'edit', group_id: (base && base.gid) || '',
             base_rev: (base && base.rev) || '', catalog_schema: MD_CLIENT_SCHEMA,
             decor: d.decor, decor_name: d.decor_name, manufacturer: d.manufacturer,
             color: d.color, sheets: d.sheets || [], edges: d.edges || [],
             allow_duplicate_code: !!(base && base.dup) };
  }

  // Cista funkcia (Node test): hodnoty prazdneho formulara -> payload servera.
  // ŠTRUKTÚRA je vlastnost SKUPINY, ale zapisuje sa na KAZDY zaznam (stlpec
  // v tabulke nie je) — preto ju klient vlieva do riadkov, ktore vlastnu
  // nemaju. Bez toho by novy dekor vznikol bez struktury a doplnit sa uz neda:
  // struktura je sucast identity variantu.
  function mdCreateRows(rows, structure){
    var st = String(structure == null ? '' : structure).trim();
    return (rows || []).map(function(r){
      var out = {}, k;
      for (k in r){ if (Object.prototype.hasOwnProperty.call(r, k)) out[k] = r[k]; }
      if (st && !String(out.structure == null ? '' : out.structure).trim()) out.structure = st;
      return out;
    });
  }

  function mdCreatePayload(v, base){
    var d = v || {};
    return { mode: 'create', group_id: '',
             // Baseline pri zakladani strazi jedinú vec, ktorá sa strážiť dá:
             // že ten istý dekor medzitým nezaložil niekto iný.
             base_rev: (base && base.rev) || '', catalog_schema: MD_CLIENT_SCHEMA,
             decor: d.decor, decor_name: d.decor_name, manufacturer: d.manufacturer,
             color: d.color, grain: d.grain,
             sheets: mdCreateRows(d.sheets, d.structure),
             edges: mdCreateRows(d.edges, d.structure),
             allow_duplicate_code: !!(base && base.dup) };
  }

  function mdEditOpen(key){
    var m = mdModal();
    if (!m) return;
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
    if (!MD_SCHEMA2){
      MD.setStatus('Editor dekoru potrebuje katalóg po migrácii na skupiny — dokonči migráciu.', true);
      return;
    }
    var g = mdGroupByKey(key);
    if (!g){ MD.setStatus('Dekor sa medzitým zmenil — obnov sekciu „Materiály“.', true); return; }
    if (g.uni === true){
      MD.setStatus('UNI je pracovný materiál — nahraď ho reálnym dekorom.', true);
      return;
    }
    var dropped = mdEditDropDirty(g);
    mdEditBase = { mode: 'edit', key: key, gid: g.gid || '', rev: MD_REV, decor: g.decor };
    mdEditDupSnap = null;
    m.open({
      title: 'Upraviť dekor',
      sub: g.decor + (g.decor_name ? ' · ' + g.decor_name : ''),
      size: 'wide', okLabel: 'Uložiť', memoryKey: mdEditKey(g),
      note: 'Typ, hrúbka a šírka existujúceho variantu sú jeho identita — pre iné hodnoty pridaj nový riadok. Riadok, ktorý tu nie je, sa nemaže. Zástenu a pracovnú dosku pridaj cez „+ variant“ — majú ďalšie povinné údaje (rub, hranová úprava).',
      fields: mdEditFields(g),
      onSubmit: mdEditSubmit
    });
    if (dropped) MD.setStatus('Rozpísané bunky dekoru ' + g.decor + ' sa zahodili — uprav ich v tomto formulári.');
  }

  // „Pridať ručne" — prazdny formular, TA ISTA kostra aj TEN ISTY odosielac.
  // Kluc pamate `mat:create` je vlastny slot (dva segmenty = cely kluc), takze
  // rozpisany NOVY dekor a rozpisana UPRAVA iného sa navzajom neprepisu.
  function mdCreateOpen(){
    var m = mdModal();
    if (!m) return;
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
    if (!MD_SCHEMA2){
      MD.setStatus('Zakladanie dekoru potrebuje katalóg po migrácii na skupiny — dokonči migráciu.', true);
      return;
    }
    mdEditBase = { mode: 'create', key: null, gid: '', rev: MD_REV, decor: '' };
    mdEditDupSnap = null;
    m.open({
      title: 'Pridať materiál ručne',
      sub: 'prázdny formulár — rovnaké polia ako pri úprave',
      size: 'wide', okLabel: 'Pridať do katalógu', memoryKey: 'mat:create',
      note: 'Číslo dekoru je povinné a musí byť presné — dekor, ktorý sa od existujúceho líši len zápisom, sa neuloží. Zásteny a pracovné dosky sem nepatria (majú ďalšie povinné údaje — rub, hranová úprava): založ dekor bez nich a variant pridaj v detaile cez „+ variant“.',
      fields: mdCreateFields(),
      onSubmit: mdEditSubmit
    });
  }

  function mdEditSubmit(v){
    var m = mdModal();
    if (!mdEditBase){ if (m) m.setBusy(false); return; }
    // Suhlas s duplicitou plati LEN pre hodnoty, pri ktorych ho server vypytal
    // (review #5): akakolvek zmena vo formulari ho rusi.
    mdEditBase.dup = (mdEditDupSnap !== null && JSON.stringify(v) === mdEditDupSnap);
    var payload = mdEditBase.mode === 'create'
      ? mdCreatePayload(v, mdEditBase)
      : mdEditPayload(v, mdEditBase);
    if (window.sketchup && sketchup.save_decor) sketchup.save_decor(JSON.stringify(payload));
    else if (m) m.setBusy(false); // bez mosta by okno ostalo navzdy zamknute
  }

  // (P1 #1b) ZOTAVENIE Z KONFLIKTU. Po `:stale` prichadza CERSTVY katalog —
  // editor z neho prekresli riadky, ZACHOVA hodnoty, ktore pouzivatel rozpisal,
  // OMLADI baseline a riadky zmenene zvonku viditelne oznaci. Bez toho by
  // formular drzal stare `row_rev` a KAZDY dalsi pokus by skoncil rovnako:
  // konflikt by nemal cestu von a pouzivatelovi by ostalo len zavriet okno
  // a napisat vsetko znova.
  function mdEditRefresh(){
    var m = mdModal();
    if (!m || !m.isOpen() || !mdEditBase) return false;
    if (mdEditBase.mode === 'create'){
      // Pri zakladani niet co dorovnavat — v katalogu este ziadny nas riadok
      // nie je. Baseline sa ale MUSI omladit, inak by kazdy dalsi pokus
      // skoncil tym istym konfliktom a cesta von by neexistovala.
      mdEditBase.rev = MD_REV;
      mdEditDupSnap = null;
      return { ok: true, touched: false };
    }
    var g = mdGroupByKey(mdEditBase.key);
    if (!g) return false;
    var cur = m.values();
    var fresh = mdEditFields(g);
    var touched = false;
    ['sheets', 'edges'].forEach(function(key){
      var f = fresh.filter(function(x){ return x.key === key; })[0];
      if (!f) return;
      var idk = key === 'edges' ? 'abs_id' : 'material_id';
      var cols = (f.cols || []).map(function(c){ return c.key; });
      var mine = {};
      (cur[key] || []).forEach(function(r){
        var id = r[idk];
        if (id) mine[id] = r;
      });
      var merged = (f.value || []).map(function(r){
        var was = mine[r[idk]];
        var out = {};
        var k;
        for (k in r){ if (Object.prototype.hasOwnProperty.call(r, k)) out[k] = r[k]; }
        if (!was){
          out._note = 'pribudlo mimo editora';
          touched = true;
          return out;
        }
        cols.forEach(function(c){
          if (Object.prototype.hasOwnProperty.call(was, c)) out[c] = was[c];
        });
        if (String(was.row_rev || '') !== String(r.row_rev || '')){
          out._note = 'zmenené mimo editora';
          touched = true;
        }
        delete mine[r[idk]];
        return out;
      });
      // Riadky, ktore pouzivatel rozpisal ako NOVE (bez id), ostavaju; riadky
      // s id, ktore uz v katalogu nie su, sa zahadzuju — zaznam je prec.
      (cur[key] || []).forEach(function(r){ if (!r[idk]) merged.push(r); });
      if (Object.keys(mine).length) touched = true;
      m.setRows(key, merged, { base: f.value });
    });
    mdEditBase.rev = MD_REV;
    mdEditDupSnap = null; // cerstve riadky = iny obsah, stary suhlas neplati
    return { ok: true, touched: touched };
  }

  function mdEditClose(){
    var m = mdModal();
    mdEditBase = null;
    mdEditDupSnap = null;
    if (m && m.isOpen()) m.close();
  }

  // --- formulare (create: id=null; edit: id zaznamu) ---
  function mdOpenSheetForm(id){
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
    mdCloseForms();
    var s = id ? MD_CATALOG.sheets.find(function(x){ return x.material_id === id; }) : null;
    mdEditing = { kind: 'sheet', id: id };
    mdEl('ms_decor').value = s ? (s.decor || '') : '';
    // D-41: dekor = identita skupiny — pri edite nemenny (server guard + disabled)
    mdEl('ms_decor').disabled = !!s;
    mdEl('ms_decor_hint').style.display = s ? '' : 'none';
    mdEl('ms_type').value = s ? (s.type || '') : 'DTDL';
    mdEl('ms_thickness').value = s ? s.thickness : '';
    mdEl('ms_thickness').disabled = !!s;                       // hrubka = variant, pri edite nemenna
    mdEl('ms_thick_hint').style.display = s ? '' : 'none';
    mdEl('ms_grain').value = s ? (s.grain || 'none') : 'length';
    // D-42: cena rozlisuje nezadana (prazdne) vs 0 — nil/undefined => prazdny input.
    mdEl('ms_price').value = mdPriceVal(s && s.price_per_m2);
    mdEl('ms_code').value = s ? (s.code || '') : '';
    mdEl('ms_supplier').value = s ? (s.supplier || '') : '';
    // D-98: alias cisla dekoru u dodavatela (nie identita — editovatelny vzdy).
    if (mdEl('ms_supplier_decor')) mdEl('ms_supplier_decor').value = s ? (s.supplier_decor || '') : '';
    // M-A3e (D-71): rucna vazba na Demos — prefill + hint s datumom overenia.
    mdDemosField('ms', s);
    mdEl('ms_family').value = s ? (s.family || '') : '';
    mdEl('ms_manufacturer').value = s ? (s.manufacturer || '') : '';
    // D-42: vyrobca je group-level — pri edite disabled + hint (mrekt cez kartu).
    mdEl('ms_manufacturer').disabled = !!s;
    if (mdEl('ms_man_hint')) mdEl('ms_man_hint').style.display = s ? '' : 'none';
    // D-19: format platne — prazdne pri novom materiali = serverovy default 2800x2070
    var ss = s && s.sheet_size;
    mdEl('ms_sheet_l').value = ss ? ss[0] : '';
    mdEl('ms_sheet_w').value = ss ? ss[1] : '';
    // 2B-2: rub zasteny — pole len pre typ ZASTENA; vyplneny rub je identita
    // (nemenny — server guard, input len readonly zrkadlo). Prazdny rub na
    // existujucej zastene = first-fill (dovoleny, s dup kontrolou servera).
    mdEl('ms_back_decor').value = s ? (s.back_decor || '') : '';
    mdEl('ms_back_structure').value = s ? (s.back_structure || '') : '';
    // D-72: protitahova zastena rub NIKDY nedostane (server guard; tu UX) —
    // first-fill by ju premenil na iny produkt.
    var singleSided = !!(s && s.single_sided === true);
    if (singleSided && !mdEl('ms_back_decor').value) mdEl('ms_back_decor').placeholder = '(protiťah — bez rubu)';
    var backFilled = !!(s && s.back_decor);
    mdEl('ms_back_decor').readOnly = backFilled || singleSided;
    mdEl('ms_back_structure').readOnly = !!(s && s.back_structure) || singleSided;
    // M-C: hranova uprava PD (postforming/abs; prazdne = neurcena — standardne
    // ABS defaulty). Editovatelna vlastnost, nie identita.
    if (mdEl('ms_pd_edge')) mdEl('ms_pd_edge').value = s ? (s.pd_edge_subtype || '') : '';
    mdSheetTypeChanged();
    mdEl('mdSheetForm').style.display = '';
  }
  // M-C: PD rozpoznanie pre formular (zrkadlo registra; server je autorita).
  function mdPdType(type){
    return String(type == null ? '' : type).trim().toUpperCase() === 'PD';
  }
  // 2B-2: viditelnost rub polí podla typu vo formulari (create aj edit).
  function mdSheetTypeChanged(){
    var type = mdEl('ms_type').value;
    var show = mdZastena(type);
    mdEl('ms_back_row').style.display = show ? '' : 'none';
    mdEl('ms_back_hint').style.display = show ? '' : 'none';
    // M-C: riadok hranovej upravy LEN pre typ PD.
    if (mdEl('ms_pd_row')) mdEl('ms_pd_row').style.display = mdPdType(type) ? '' : 'none';
    // D-98 (audit F3): zastena alias dekoru nema — riadok sa skryje a hodnota
    // sa na server neposiela (server ju aj tak odmietne).
    if (mdEl('ms_sd_row')) mdEl('ms_sd_row').style.display = show ? 'none' : '';
    if (mdEl('ms_sd_hint')) mdEl('ms_sd_hint').style.display = show ? 'none' : '';
    // D-97: nenasilne upozornenie na neznamy typ (nikdy neblokuje ulozenie).
    var warn = mdEl('ms_type_warn');
    if (warn){
      var txt = mdUnknownTypeWarning(type, MD_KNOWN_TYPES);
      warn.textContent = txt || '';
      warn.style.display = txt ? '' : 'none';
    }
  }
  // D-97 (cista funkcia, Node test): text upozornenia pre neznamy typ dosky,
  // alebo null. Porovnanie je case-insensitive a s trimom (zapis „dtdl" je ten
  // isty typ); prazdne pole nikdy nevarujeme (povinnost riesi validacia).
  // Typ ZOSTAVA volny string — toto je informacia, nie zakaz (D-67/D-68).
  function mdUnknownTypeWarning(type, known){
    var t = String(type == null ? '' : type).trim();
    if (!t) return null;
    var list = known || [];
    for (var i = 0; i < list.length; i++){
      if (String(list[i]).trim().toUpperCase() === t.toUpperCase()) return null;
    }
    if (!list.length) return null; // bez serverovho zoznamu sa nehada
    return 'Neznámy typ — skontroluj (známe: ' + list.slice(0, 3).join(', ') +
      (list.length > 3 ? '…' : '') + ').';
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
    var inp = mdEl(prefix + '_demos_url');
    if (!inp) return;
    inp.value = rec ? (rec.demos_url || '') : '';
    var row = inp.closest ? inp.closest('.row') : null;
    if (row) row.style.display = (rec && rec.uni === true) ? 'none' : '';
    var hint = mdEl(prefix + '_demos_hint');
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
    mdEl('me_decor').value = a ? (a.decor || '') : '';
    mdEl('me_decor').disabled = !!a; // D-41: dekor pri edite nemenny
    mdEl('me_decor_hint').style.display = a ? '' : 'none';
    // D-41: sirka = variant identity (vznika v batchi), iba informativne
    // zobrazenie — input je disabled v HTML, server ju drzi z existujuceho zaznamu.
    mdEl('me_width').value = (a && a.width !== null && a.width !== undefined) ? fmtNum(a.width) : '';
    mdEl('me_thickness').value = a ? String(parseFloat(a.thickness).toFixed(1)) : '1.0';
    mdEl('me_thickness').disabled = !!a; // hrubka = variant (ID _10/_20), pri edite nemenna
    mdEl('me_price').value = mdPriceVal(a && a.price_per_bm);
    mdEl('me_code').value = a ? (a.code || '') : '';
    mdEl('me_supplier').value = a ? (a.supplier || '') : '';
    // M-A3e (D-71): rucna vazba na Demos — prefill + hint s datumom overenia.
    mdDemosField('me', a);
    mdEl('mdEdgeForm').style.display = '';
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
    return ((mdEl('nd_type') && mdEl('nd_type').value) || '').trim();
  }
  function mdActiveChips(rid){
    var row = mdEl(rid), out = [];
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
      var row = mdEl(rid);
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
  function mdCommonSt(){ return ((mdEl('nd_structure') && mdEl('nd_structure').value) || '').trim(); }
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
    var row = mdEl(rid);
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
  // Zmena spolocneho typu prepocita NAVRHY (PD navrh nema, takze DTDL -> PD
  // pole vyprazdni — inak by odoslal 2800x2070 pre pracovnu dosku).
  // M-A3c: + auto pruhy vynimiek (rucne hodnoty auto=false ostavaju).
  function mdTypeChanged(){
    mdActiveSheetChips().forEach(function(c){ if (!c.type) mdFmtPrefill(c.key, c.hintType); });
    var t = ((mdEl('nd_type') && mdEl('nd_type').value) || '').trim();
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
    var row = mdEl('nd_fmt_row'), box = mdEl('nd_fmt_fields');
    if (!row || !box) return;
    var chips = mdActiveSheetChips();
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var f = mdFmtState(c.key);
      var st = mdStState(mdStS, c.key);
      var lbl = c.type ? c.label : ((c.hintType ? c.hintType + ' ' : '') + c.label);
      html += '<span class="mdfmt">' +
        '<i>' + mdEsc(lbl) + '</i>' +
        '<input type="text" class="fmtst" data-key="' + mdEsc(c.key) + '" value="' + mdEsc(st.st) + '"' +
        ' placeholder="štrukt." title="Štruktúra povrchu variantu (napr. PW, ST9)" oninput="mdStInput(this, \'s\')">' +
        '<input type="text" class="fmtdim" data-key="' + mdEsc(c.key) + '" data-dim="l" value="' + mdEsc(f.l) + '"' +
        ' placeholder="dĺžka" title="Formát platne — dĺžka (mm)" oninput="mdFmtInput(this)">' +
        '<span class="sheetx">×</span>' +
        '<input type="text" class="fmtdim" data-key="' + mdEsc(c.key) + '" data-dim="w" value="' + mdEsc(f.w) + '"' +
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
    var f = mdFmtXState(inp.getAttribute('data-key'), (mdEl('nd_type') && mdEl('nd_type').value) || '');
    f[inp.getAttribute('data-dim')] = inp.value;
    f.auto = false;
  }
  function mdRenderExtraFmtRow(){
    var row = mdEl('nd_xfmt_row'), box = mdEl('nd_xfmt_fields');
    if (!row || !box) return;
    var type = ((mdEl('nd_type') && mdEl('nd_type').value) || '').trim();
    var chips = mdExtraFmtChips((mdEl('nd_ths') && mdEl('nd_ths').value) || '').filter(function(c){ return !c.inline; });
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var f = mdFmtXState(c.key, type);
      html += '<span class="mdfmt">' +
        '<i>' + mdEsc(c.th) + '</i>' +
        '<input type="text" class="fmtdim" data-key="' + mdEsc(c.key) + '" data-dim="l" value="' + mdEsc(f.l) + '"' +
        ' placeholder="dĺžka" title="Formát platne výnimky — dĺžka (mm)" oninput="mdFmtXInput(this)">' +
        '<span class="sheetx">×</span>' +
        '<input type="text" class="fmtdim" data-key="' + mdEsc(c.key) + '" data-dim="w" value="' + mdEsc(f.w) + '"' +
        ' placeholder="šírka" title="Formát platne výnimky — šírka (mm)" oninput="mdFmtXInput(this)">' +
        '</span>';
    });
    box.innerHTML = html;
    row.style.display = '';
  }

  // 2A-4b: pruh detailu ABS cipov — struktura + vedomy priznak "univerzalna".
  function mdRenderAbsRow(){
    var row = mdEl('nd_abs_row'), box = mdEl('nd_abs_fields');
    if (!row || !box) return;
    var chips = mdActiveEdgeChips();
    if (!chips.length){ box.innerHTML = ''; row.style.display = 'none'; return; }
    var html = '';
    chips.forEach(function(c){
      var st = mdStState(mdStE, c.key);
      html += '<span class="mdfmt">' +
        '<i>' + mdEsc(c.label) + '</i>' +
        '<input type="text" class="fmtst" data-key="' + mdEsc(c.key) + '" value="' + mdEsc(st.st) + '"' +
        ' placeholder="štrukt." title="Štruktúra povrchu pásky (napr. PW, ST9)" oninput="mdStInput(this, \'e\')">' +
        '<label class="fmtuni" title="Univerzálna — pasuje na každú štruktúru">' +
        '<input type="checkbox" data-key="' + mdEsc(c.key) + '"' + (mdUni[c.key] ? ' checked' : '') +
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

  // ŠT-2c 2c-2b: „POSLEDNÁ POUŽITÁ SADA" (pamat preset cipov v localStorage)
  // ZANIKLA spolu so zakladanim dekoru z tohto formulara. Bola to pamat
  // preset cipov pre NOVY dekor — „+ variant" ju nikdy nepouzival (zacina
  // prazdny) a novy dekor sa zaklada v D-69 editore, ktory ma vlastnu,
  // VIDITELNU pamat rozpisu (`NXModal` + pas „Predvyplnené z konceptu").
  // Dve pamate na to iste by znamenali dve rozpisane verzie a ziadnu istotu,
  // ktora sa naozaj odosle.

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
    var b = mdEl('mdSgBox');
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
      // CAPTURE (`true`) je tu POVINNE: `scroll` z vnutorneho kontajnera
      // NEBUBLA, takze bez neho by scrollovanie VNUTRI karty D-15 modalu
      // (`.mbody`) nechalo dropdown visiet na starom mieste — nad cudzim
      // riadkom, do ktoreho by klik zapisal nespravnu hodnotu.
      window.addEventListener('scroll', mdSgClose, true);
    }
    return b;
  }
  function mdSgClose(){
    mdSg.input = null;
    mdSg.items = [];
    mdSg.active = -1;
    var b = mdEl('mdSgBox');
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
    var inp = mdEl(id);
    if (!inp) return;
    if (!inp.getAttribute('data-sg')){
      inp.setAttribute('data-sg', '1');
      inp.setAttribute('autocomplete', 'off');
      inp.addEventListener('focus', function(){ mdSg.input = inp; mdSg.getList = inp._sgList; mdSg.onPick = inp._sgPick; mdSgUpdate(); });
      // ŠT-2c #9: pisanie do pola nasepkavac VZDY obnovi — aj ked ho pouzivatel
      // predtym zavrel Escapom. Bez toho by sa dropdown vratil az po opusteni
      // a novom kliknuti do pola, cize by Escape pole „vypol" na celu editaciu.
      inp.addEventListener('input', function(){
        mdSg.input = inp; mdSg.getList = inp._sgList; mdSg.onPick = inp._sgPick;
        mdSgUpdate();
      });
      inp.addEventListener('blur', function(){ setTimeout(function(){ if (mdSg.input === inp) mdSgClose(); }, 120); });
      inp.addEventListener('keydown', function(ev){
        if (mdSg.input !== inp || !mdSg.items.length) return;
        if (ev.key === 'ArrowDown'){ ev.preventDefault(); mdSg.active = (mdSg.active + 1) % mdSg.items.length; mdSgRender(); }
        else if (ev.key === 'ArrowUp'){ ev.preventDefault(); mdSg.active = (mdSg.active - 1 + mdSg.items.length) % mdSg.items.length; mdSgRender(); }
        else if (ev.key === 'Enter'){ ev.preventDefault(); mdSgPick(mdSg.active >= 0 ? mdSg.active : 0); }
        // ŠT-2 audit #13: Escape patri NAJPRV nasepkavacu. Listener visi na
        // INPUTE, kdezto D-15 modal pocuva na `document` — bez zastavenia by
        // jedno stlacenie zavrelo dropdown AJ cely formular a pouzivatel by
        // prisiel o rozpisany dekor. `stopPropagation` staci a je SPRAVNY:
        // dokumentovy poslucháč je na INOM uzle, takze bublanie sa zastavi
        // uz tu (`stopImmediatePropagation` by zastavil len dalsich
        // poslucháčov toho isteho inputu — modal by sa aj tak zavrel).
        else if (ev.key === 'Escape'){ ev.stopPropagation(); mdSgClose(); }
      });
    }
    inp._sgList = getList;
    inp._sgPick = onPick;
  }

  // ŠT-2c 2c-2b: formular je UZ LEN „+ variant" do EXISTUJUCEJ skupiny.
  // Zakladanie dekoru odtialto ZANIKLO (D-69: jeden formular pre vsetky vstupy
  // — `mdCreateOpen`), takze `key` je POVINNY: bez neho by payload zalozil
  // skupinu s prazdnym cislom dekoru. Tento formular tu ostava pre typy,
  // ktorych identitu editor nepokryva (zastena = rub, PD = hranova uprava)
  // a pre skupiny s viacerymi strukturami.
  function mdOpenDecorForm(key){
    if (MD_RO){ MD.setStatus('Katalóg je len na čítanie — úpravy sú vypnuté.', true); return; }
    var g = key ? mdGroupByKey(key) : null;
    if (!g){
      MD.setStatus('Nový dekor sa zakladá tlačidlom „Pridať ručne“ — tento formulár pridáva variant do existujúceho dekoru.', true);
      return;
    }
    mdCloseForms();
    mdBindChips();
    mdEditing = { kind: 'decor', id: key };
    // Identita skupiny je tu LEN NA CITANIE — zmena by cielila inu/novu
    // skupinu; meni sa v editore dekoru („Upraviť…").
    mdEl('nd_decor').value = g.decor;
    mdEl('nd_decor').disabled = true;
    if (mdEl('nd_decor_name')){
      mdEl('nd_decor_name').value = g.decor_name || '';
      mdEl('nd_decor_name').disabled = true;
    }
    mdEl('nd_manufacturer').value = g.manufacturer || '';
    mdEl('nd_manufacturer').disabled = true;
    // Spolocna struktura: predvolba z jedinej struktury skupiny.
    if (mdEl('nd_structure')) mdEl('nd_structure').value = mdGroupCommonStructure(g);
    var firstSheet = g.sheets.length ? g.sheets[0] : null;
    mdEl('nd_type').value = firstSheet ? (firstSheet.type || 'DTDL') : 'DTDL';
    mdEl('nd_grain').value = firstSheet ? (firstSheet.grain || 'length') : 'length';
    mdEl('nd_ths').value = '';
    mdEl('nd_abs').value = '';
    // „+ variant" zacina VZDY prazdny — doplna sa konkretna vec do existujucej
    // skupiny. (Pamat poslednej sady patrila zaniknutemu zakladaniu dekoru.)
    mdFmt = {};
    mdFmtX = {}; // M-A3c: pruhy vynimiek zacinaju cisto
    mdStS = {};
    mdStE = {};
    mdUni = {};
    mdChipsSet('nd_sheet_chips', []);
    mdChipsSet('nd_edge_chips', []);
    mdRenderFmtRow();
    mdRenderAbsRow();
    mdRenderExtraFmtRow(); // M-A3c (D-68): pruhy pre obnovene "Dalsie hrubky"
    mdSgBind('nd_type', function(){ return MD_SUGGEST.types; }, mdTypeChanged);
    // Naseptavac vyrobcov tu ZANIKOL spolu so zakladanim dekoru — pole je
    // zamknute (vyrobcu meni editor dekoru), takze by nemal do coho pisat.
    mdEl('mdDecorForm').style.display = '';
  }
  // 2A-4b: pri SCHEMA 2 katalogu davka batch_schema 3 (skupiny/struktura/
  // universal). GH #93 P1: pri LEGACY katalogu (:undecidable fallback —
  // dokumentovany rezim, mutacie bezia) klient posiela povodny D-44 tvar
  // (batch_schema 2 BEZ struktur/universal/nazvu) — server batch 3 do
  // katalogu 1 spravne odmieta a bez fallbacku by sa nedalo NIC zalozit.
  // ŠT-2c 2c-2b: FARBA sa uz neposiela — skupina VZDY existuje („+ variant")
  // a server jej ulozenu farbu aj tak vnucuje (D-82). Pole vo formulari
  // zaniklo spolu so zakladanim dekoru.
  function mdSaveDecorBatch(){
    var sheetChips = mdActiveSheetChips();
    var edgeChips = mdActiveEdgeChips();
    var built = mdBuildSheetVariants(sheetChips, mdFmt, mdStS, mdEl('nd_type').value);
    // Polovicny format = formular OSTAVA otvoreny (hodnoty sa nestratia).
    if (built.error){ MD.setStatus(built.error, true); return; }
    var commonSt = mdCommonSt();
    // M-A3c (D-68): pruhy vynimiek (mdFmtX) doplnaju format hrubkam bez
    // inline zapisu — inline "20/4100x600" ma prednost.
    var extraS = mdParseExtraThs(mdEl('nd_ths').value, commonSt, mdEl('nd_type').value, mdFmtX);
    if (extraS.error){ MD.setStatus(extraS.error, true); return; }
    var extraE = mdParseExtraAbs(mdEl('nd_abs').value, commonSt);
    if (extraE.error){ MD.setStatus(extraE.error, true); return; }
    var sheetVars = built.variants.concat(extraS.variants);
    var edgeVars = mdBuildEdgeVariants(edgeChips, mdStE, mdUni).concat(extraE.variants);
    var payload;
    if (MD_SCHEMA2){
      payload = {
        batch_schema: 3,
        catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
        decor: mdEl('nd_decor').value,
        decor_name: mdEl('nd_decor_name') ? mdEl('nd_decor_name').value : '',
        manufacturer: mdEl('nd_manufacturer').value,
        type: mdEl('nd_type').value,
        grain: mdEl('nd_grain').value,
        sheet_variants: sheetVars,
        edge_variants: edgeVars
      };
    } else {
      payload = {
        batch_schema: 2,
        catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
        decor: mdEl('nd_decor').value,
        manufacturer: mdEl('nd_manufacturer').value,
        type: mdEl('nd_type').value,
        grain: mdEl('nd_grain').value,
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
    if (window.sketchup && sketchup.add_decor_batch) sketchup.add_decor_batch(JSON.stringify(payload));
    mdCloseForms();
  }
  function mdCloseForms(){
    mdEditing = null;
    mdDupAllow = null; // nove otvorenie formulara rusi potvrdenie duplicity
    mdSgClose(); // M-A3c: otvoreny suggest nesmie prezit zatvorenie formulara
    if (mdEl('mdSheetForm')) mdEl('mdSheetForm').style.display = 'none';
    if (mdEl('mdEdgeForm')) mdEl('mdEdgeForm').style.display = 'none';
    if (mdEl('mdDecorForm')) mdEl('mdDecorForm').style.display = 'none';
    // ŠT-2c 2c-2b: odomykanie skupinovych poli ZANIKLO — „+ variant" ich drzi
    // zamknute VZDY (identita skupiny sa meni v editore dekoru) a zakladanie
    // dekoru z tohto formulara uz neexistuje.
  }

  // --- 2A-4b (audit B2): potvrdenie obnovy predmigracnej zalohy ------------
  function mdRestoreOpen(){ var m = mdEl('mdRestoreModal'); if (m) m.style.display = 'flex'; }
  function mdRestoreClose(){ var m = mdEl('mdRestoreModal'); if (m) m.style.display = 'none'; }
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
    // Formular je od zaniku add_sheet VYHRADNE edit — create cesta bola z UI
    // nedosiahnutelna a payload bez group_id by nad skupinovym katalogom padol
    // na serverovom write guarde. Novy zaznam = batch (+ variant / Pridat rucne).
    if (!(mdEditing && mdEditing.id)){
      MD.setStatus('Nový materiál sa pridáva cez „+ variant" alebo „Pridať materiál ručne" — tento formulár upravuje existujúci záznam.', true);
      return;
    }
    var payload = {
      material_id: mdEditing && mdEditing.id ? mdEditing.id : null,
      catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
      decor: mdEl('ms_decor').value,
      type: mdEl('ms_type').value,
      thickness: mdEl('ms_thickness').value,
      grain: mdEl('ms_grain').value,
      price_per_m2: mdEl('ms_price').value,   // D-42: prazdne = nezadana (nie 0)
      code: mdEl('ms_code').value,             // D-42 dodavatelsky kod
      supplier: mdEl('ms_supplier').value,     // D-42 preferovany dodavatel
      demos_url: mdEl('ms_demos_url').value,   // M-A3e (D-71): prazdne = zmazat vazbu
      family: mdEl('ms_family').value,
      manufacturer: mdEl('ms_manufacturer').value,
      allow_duplicate_code: mdDupAllow === 'sheet' // potvrdenie duplicitneho kodu (2. ulozenie)
    };
    // 2B-2 (GH #95 P2): rub polia idu do payloadu LEN pri type Zastena —
    // zmena typu formular len skryje, hodnoty by inak leteli na server a ten
    // by save odmietal kvoli poliam, ktore uz nie su vidiet.
    if (mdZastena(payload.type)){
      payload.back_decor = mdEl('ms_back_decor').value;
      payload.back_structure = mdEl('ms_back_structure').value;
    }
    // M-C: hranova uprava LEN pri type PD (vzor rub polia — skryte pole nesmie
    // letiet na server); prazdna hodnota = vedome "neurcena" (vymaze pole).
    if (mdPdType(payload.type) && mdEl('ms_pd_edge')){
      payload.pd_edge_subtype = mdEl('ms_pd_edge').value;
    }
    // D-98: alias dekoru u dodavatela — vsade OKREM zasteny (skryte pole nesmie
    // letiet na server, vzor rub/hranova uprava). Prazdna hodnota = vymazanie.
    if (!mdZastena(payload.type) && mdEl('ms_supplier_decor')){
      payload.supplier_decor = mdEl('ms_supplier_decor').value;
    }
    // D-19: format platne sa posiela LEN ako kompletny platny par; polovicny
    // alebo neplatny vstup zastavi ulozenie (ziadne tiche 0/reset — Codex F4).
    // M-A3e (audit FIX 4): zla adresa NEZATVARA formular — server ju sice
    // odmietne tiez, ale az po zavreti a prepis by prepadol.
    var due = mdDemosUrlLocalError(payload.demos_url);
    if (due){ MD.setStatus(due, true); return; }
    var sl = mdSheetDim(mdEl('ms_sheet_l').value);
    var sw = mdSheetDim(mdEl('ms_sheet_w').value);
    if ((sl === null) !== (sw === null) || (sl !== null && (isNaN(sl) || isNaN(sw)))){
      MD.setStatus('Formát platne: vyplň obe čísla (mm), alebo nechaj obe prázdne.', true); // GH P3: toto okno ma MD, nie NX
      return;
    }
    if (sl !== null) payload.sheet_size = [sl, sw];
    // GH P2: edit s OBOMA prazdnymi polami = vedome VYMAZANIE ulozeneho formatu
    // (server inak merge-om stary par podrzi a "bez formatu" sa neda dosiahnut).
    else if (mdEditing && mdEditing.id) payload.clear_sheet_size = true;
    mdLastAttempt = { kind: 'sheet', payload: payload };
    if (window.sketchup && sketchup.update_sheet) sketchup.update_sheet(JSON.stringify(payload));
    mdCloseForms();
  }
  function mdSaveEdge(){
    // Edit-only — zrkadlo mdSaveSheet (add_edge zanikol s add_sheet).
    if (!(mdEditing && mdEditing.id)){
      MD.setStatus('Nová ABS páska sa pridáva cez „+ variant" (dávka dekoru) — tento formulár upravuje existujúci záznam.', true);
      return;
    }
    var payload = {
      abs_id: mdEditing && mdEditing.id ? mdEditing.id : null,
      catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA,
      decor: mdEl('me_decor').value,
      width: mdEl('me_width').value,   // D-41: prazdna = univerzalna paska bez sirky
      thickness: mdEl('me_thickness').value,
      price_per_bm: mdEl('me_price').value,  // D-42: prazdne = nezadana (nie 0)
      code: mdEl('me_code').value,
      supplier: mdEl('me_supplier').value,
      demos_url: mdEl('me_demos_url').value,   // M-A3e (D-71): prazdne = zmazat vazbu
      allow_duplicate_code: mdDupAllow === 'edge'
    };
    // M-A3e (audit FIX 4): zla adresa nezatvara formular (vzor mdSaveSheet).
    var due = mdDemosUrlLocalError(payload.demos_url);
    if (due){ MD.setStatus(due, true); return; }
    mdLastAttempt = { kind: 'edge', payload: payload };
    if (window.sketchup && sketchup.update_edge) sketchup.update_edge(JSON.stringify(payload));
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
      mdEl('ms_decor').value = p.decor || ''; mdEl('ms_type').value = p.type || '';
      mdEl('ms_thickness').value = p.thickness || ''; mdEl('ms_price').value = p.price_per_m2 || '';
      mdEl('ms_code').value = p.code || ''; mdEl('ms_supplier').value = p.supplier || '';
      mdEl('ms_grain').value = p.grain || 'none'; mdEl('ms_family').value = p.family || '';
      mdEl('ms_manufacturer').value = p.manufacturer || '';
      mdEl('ms_sheet_l').value = p.sheet_size ? p.sheet_size[0] : '';
      mdEl('ms_sheet_w').value = p.sheet_size ? p.sheet_size[1] : '';
      mdEl('ms_demos_url').value = p.demos_url || ''; // M-A3e (audit FIX 2)
      if (mdEl('ms_pd_edge')) mdEl('ms_pd_edge').value = p.pd_edge_subtype || ''; // M-C
      if (mdEl('ms_supplier_decor')) mdEl('ms_supplier_decor').value = p.supplier_decor || ''; // D-98
      mdSheetTypeChanged(); // typ z payloadu prekreslil polia — obnov viditelnost/varovanie
    } else {
      mdOpenEdgeForm(p.abs_id || null);
      mdEl('me_decor').value = p.decor || ''; mdEl('me_price').value = p.price_per_bm || '';
      mdEl('me_code').value = p.code || ''; mdEl('me_supplier').value = p.supplier || '';
      mdEl('me_width').value = (p.width === null || p.width === undefined) ? '' : p.width;
      mdEl('me_thickness').value = p.thickness || '1.0';
      mdEl('me_demos_url').value = p.demos_url || ''; // M-A3e (audit FIX 2)
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
    var m = mdEl('mdDeleteModal');
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

  // Čistá funkcia (Node test): kľúč skupiny, ktorá nesie daný UNI materiál.
  // D-83: skratka zo ŠTÚDIA pozná len uni_id — dlaždicu k nemu hľadá TU.
  function mdGroupKeyForUni(catalog, schema2, uniId){
    var id = String(uniId == null ? '' : uniId);
    if (!id) return null;
    var hit = null;
    groupCatalogByDecor(catalog || { sheets: [], edges: [] }, schema2).forEach(function(g){
      if (hit) return;
      var m = g.sheets.filter(function(s){ return s.uni === true && s.material_id === id; })[0];
      if (m) hit = g.key;
    });
    return hit;
  }

  // uniId (voliteľné, D-83) = KONKRÉTNY UNI materiál, ktorý sa má nahradiť;
  // bez neho sa berie prvý UNI variant skupiny (pôvodné správanie tlačidla).
  // Vráti true, keď sa modal otvoril.
  function mdUniOpen(key, uniId){
    var g = mdGroupByKey(key);
    var us = g && g.sheets.filter(function(s){
      return s.uni === true && (!uniId || s.material_id === uniId);
    })[0];
    if (!us) return false;
    MD_UNI = { uni_id: us.material_id, key: key };
    MD_UNI_PENDING = null;
    var name = mdEl('mdUniName');
    if (name) name.textContent = 'Nahradiť ' + (g.decor || 'UNI') + ' reálnym dekorom';
    var gsel = mdEl('mdUniGroup');
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
    var m = mdEl('mdUniModal');
    if (m) m.style.display = '';
    return true;
  }
  function mdUniGroupChange(){
    var gsel = mdEl('mdUniGroup'), vsel = mdEl('mdUniVariant');
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
    var s1 = mdEl('mdUniStep1'), s2 = mdEl('mdUniStep2'), ok = mdEl('mdUniConfirmBtn'), nx = mdEl('mdUniNextBtn');
    if (s1) s1.style.display = n === 1 ? '' : 'none';
    if (s2) s2.style.display = n === 2 ? '' : 'none';
    if (ok) ok.style.display = n === 2 ? '' : 'none';
    if (nx) nx.style.display = n === 1 ? '' : 'none';
  }
  function mdUniPreview(){
    var vsel = mdEl('mdUniVariant');
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
    var m = mdEl('mdUniModal');
    if (m) m.style.display = 'none';
  }

  // Top-level var v script tagu = window.MD v CEF; v Node require nepada na window.
  var MD_MODEL_GUID = ''; // D-42: identita modelu pre projektove predvolby (blocker 4)
  var MD_USED = {};       // D-42 PR B: {dekor => pocet dielcov v aktivnom modeli}
  // ŠT-2d: ROZPIS toho isteho cisla — {kluc skupiny => {owners:[], edges:{}}}.
  // Sklada ho SERVER z toho isteho zberu ako `used` (`StudioDialog#mat_used_where`).
  var MD_USED_WHERE = {};
  // PICKER-2: {sheets:[id], edges:[abs_id]} — ID materiálov, ktoré sú v zákazke.
  // Ten istý tvar aj zdroj ako v Inspectore; slúži skupine „Použité v projekte"
  // vo vyhľadávači predvolieb (`used` s počtami je iná otázka a iný kľúč).
  var MD_USED_IDS = { sheets: [], edges: [] };
  var MD_CABINETS = 0;    // pocet skriniek v modeli (podtitul okna / hint sekcie)
  var MD_PROJECT = {};    // posledne projektove predvolby (pre refill selectov pri setCatalog)
  // Spolocna katalogova cast (audit FIX 13: katalogove echo NEnesie modelovy
  // kontext — ten ostava z posledneho `matApplyState`).
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

  // PICKER-1: pripojenie/obnova vyhľadávača nad predvoľbami. Mimo prehliadača
  // (Node testy) alebo kým komponent nie je načítaný sa nič nestane — polia
  // ostanú natívnymi selectmi a všetko ostatné funguje ďalej.
  function mdComboScan(){
    if (typeof NXCombo === 'undefined' || !NXCombo || !NXCombo.scan) return false;
    // Review #230 P2: telo sekcie je PERZISTENTNÝ uzol, ktorý odchod zo sekcie
    // ODPOJÍ z dokumentu (a návrat ho aj s rozpísaným formulárom vráti). Kým je
    // odpojené, `mdRenderAll` je no-op (`mdEl` nič nenájde) — a scan tu preto
    // nemá čo robiť. Bez tejto brány by katalógové echo na pozadí odregistrovalo
    // polia, ktoré sa o chvíľu vrátia.
    if (!mdSectionAttached()) return false;
    mdComboHooks();
    NXCombo.scan(document);
    return true;
  }

  // Je telo sekcie práve v dokumente? (Mimo prehliadača — Node testy — vraciame
  // `false`: nie je čo skenovať.)
  function mdSectionAttached(){
    if (typeof document === 'undefined' || !document.body || !document.body.contains) return false;
    var node = mdEl('md_body');
    return !!(node && document.body.contains(node));
  }

  // PICKER-1: farbu štvorčeka a „Použité v projekte" dodáva komponentu HOSTITEĽ
  // (sám žiadny katalóg nepozná). V Inspectore to robí `core.js`; v Štúdiu je
  // zdrojom tá istá sekcia Materiály, takže ponuka vyzerá v oboch oknách
  // rovnako — bez toho by v Štúdiu boli prázdne štvorčeky a chýbala by skupina
  // „Použité v projekte", hoci tie dáta sekcia má.
  var MD_COMBO_HOOKED = false;
  function mdComboHooks(){
    if (MD_COMBO_HOOKED || typeof NXCombo === 'undefined' || !NXCombo) return;
    // PICKER-2: dekorové riadky aj v Štúdiu — zdroj je `MD_SHEETS`, teda ten
    // istý zoznam, z ktorého sa plnia predvoľby.
    if (NXCombo.setVariantResolver){
      NXCombo.setVariantResolver(function(kind, value){
        if (kind === 'abs' || !value) return null;
        var rec = (MD_SHEETS || []).find(function(s){ return String(s.id) === String(value); });
        if (!rec || !rec.decor) return null;
        // Ten isty kontrakt ako v Inspectore: menovku riadku, hranicu
        // zlucovania (`row_label`/`row_key`) aj PRIZNAK DUPLAKA dava server.
        // `MD_SHEETS` je ZUZENY payload (`Panel.materials_payload`) — surove
        // `source_material_id` v nom nie je, takze citat duplak z neho by
        // znamenalo, ze ulozeny duplak je v Studiu neviditelny (review #231
        // kolo 3). Tvar `duplak2:` ostava pre virtualnu ponuku.
        return { decor: rec.row_label || rec.decor, type: rec.type || '',
                 thickness: rec.thickness, key: rec.row_key || '',
                 duplak: rec.duplak === true || /^duplak[23]:/.test(String(value)) };
      });
    }
    if (NXCombo.setColorResolver){
      NXCombo.setColorResolver(function(kind, value){
        if (kind === 'abs' || !value) return '';
        var rec = (MD_SHEETS || []).find(function(s){ return String(s.id) === String(value); });
        return rec && rec.color ? rgbToHex(rec.color) : '';
      });
    }
    // PICKER-2 dorieši priznané obmedzenie PICKER-1: „Použité v projekte" už
    // v Štúdiu JE. Nemapuje sa tu nič — server posiela hotový zoznam ID
    // (`used_ids`) v tom istom tvare ako panel, takže tento hook je doslova ten
    // istý jednoriadkový výber ako v `core.js`.
    if (NXCombo.setUsedResolver){
      NXCombo.setUsedResolver(function(kind){
        return (kind === 'abs' ? MD_USED_IDS.edges : MD_USED_IDS.sheets) || [];
      });
    }
    MD_COMBO_HOOKED = true;
  }

  function mdSetProjectSelect(key, id){
    var sel = mdEl(mdProjectSelectId(key)); // programovy zapis onchange NEspusti
    if (sel && id) sel.value = id;
    // PICKER-1: `change` sa tu ZÁMERNE nespúšťa (D-46: vraciame predvoľbu na
    // skutočný default, kým sa zmena nepotvrdí — nesmie to vyzerať ako nová
    // voľba používateľa). Natívny select by sa prekreslil sám, vyhľadávač má
    // ale VLASTNÝ trigger, takže by ukazoval hodnotu, ktorá už neplatí —
    // preto ho treba zosynchronizovať výslovne.
    if (sel && typeof NXCombo !== 'undefined' && NXCombo && NXCombo.sync) NXCombo.sync(sel);
  }
  function mdClearPending(){
    MD_PENDING = null;
    var bar = mdEl('mdConfirmBar');
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

  // ŠT-2a: prijatie katalogu je rozdelene na STAV (`mdSetCatalog`) a KRESLENIE
  // (`mdRenderAll`). Dovod: v okne Studio pride katalog aj v payloade sekcie
  // (`ST.mat.catalog`) EST PRED tym, nez `studio.js` telo sekcie vykresli —
  // kreslit dvakrat by znamenalo dva prechody cez dlazdice a dve obnovy fokusu.
  function mdSetCatalog(data){
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
    // GH P1: serverova schema sa NEpreberá do mutacii — klient posiela vlastnu
    // MD_CLIENT_SCHEMA konstantu (echo servera by falosne "povysilo" stare
    // okno bez novych poli); MD_SCHEMA2 je len ZOBRAZOVACI rezim.
    // D-44: naseptavace + navrhy formatu — jedna autorita (server), JS renderuje.
    // M-A3c (D-67): <datalist> nahradil vlastny suggest (CEF klik bug) —
    // dropdown cita MD_SUGGEST zivo pri otvoreni; otvoreny sa pri echu zavrie.
    MD_SUGGEST = data.suggest || { manufacturers: [], types: [] };
    MD_KNOWN_TYPES = data.known_types || []; // D-97: kanonicke typy (registry)
    MD_FORMAT_HINTS = data.format_hints || {};
    mdSgClose();
    mdPatchDup = null; // uspesny zapis/refresh rusi pending potvrdenie duplicity
  }

  // Prekreslenie z UZ ULOZENEHO stavu. Rozpisany formular (mdEditing) ani
  // rozpisana bunka sa NESMU stratit — preto obnova fokusu okolo renderu.
  function mdRenderAll(){
    mdRenderBanners();
    var keep = null;
    var ae = document.activeElement;
    if (ae && ae.classList && ae.classList.contains('mdcell')){
      keep = { kind: ae.getAttribute('data-kind'), id: ae.getAttribute('data-id'),
               field: ae.getAttribute('data-field'), value: ae.value,
               dirty: ae.value !== (ae.getAttribute('data-orig') || ''),
               rev: ae.getAttribute('data-rev') || '', orig: ae.getAttribute('data-orig') || '',
               s: ae.selectionStart, e: ae.selectionEnd };
    }
    fillSelect(mdEl('md_body'), MD_SHEETS, MD_PROJECT.default_material_id);
    fillSelect(mdEl('md_front'), frontSheets(), MD_PROJECT.default_front_material_id);
    fillSelect(mdEl('md_back'), MD_SHEETS, MD_PROJECT.default_back_material_id);
    // PICKER-1: predvoľby projektu používajú TEN ISTÝ vyhľadávač ako karta
    // dielca a dosky (`nx_combo`) — jeden komponent, jedna pravda. Stačí
    // atribút v HTML a toto pripojenie: `scan` nové polia pripojí a už
    // pripojeným prekreslí trigger z čerstvých `<option>`ov (po `fillSelect`
    // by inak ukazovali starý text). Komponent posiela `change` rovnako ako
    // natívny select, takže D-46 potvrdzovanie aj `model_guid` guard bežia
    // NEZMENENOU cestou.
    mdComboScan();
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
  function mdApplyCatalog(data){
    mdSetCatalog(data);
    mdRenderAll();
  }
  // ŠT-2b: `MD.init` (plny stav s modelovym kontextom) ZANIKLO spolu s oknom —
  // v sekcii ho nesie payload Studia (`ST.mat` -> `matApplyState`), takze druha
  // cesta by bola druhy zdroj pravdy o tych istych cislach.
  var MD = {
    // D-42 (audit FIX 13): echo po zapise do katalogu — bez scanu modelu,
    // modelovy kontext (predvolby/pouzite/guid) ostava.
    setCatalog: function(data){ mdApplyCatalog(data); },
    setStatus: function(msg, err){ var e = mdEl('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; },
    // D-42 (audit FIX 8): server odmietol duplicitny kod — znovu otvor formular
    // s rozpisanymi hodnotami a nastav potvrdenie na druhe Ulozit.
    flagDuplicateCode: function(kind){ mdReopenFromAttempt(); mdDupAllow = kind; },
    // D-42 PR C: duplicitny kod z inline bunky — bunka OSTAVA rozpisana (server
    // neposlal refresh), dalsi flush tej istej bunky posle potvrdenie.
    flagDuplicatePatch: function(kind, id){ mdPatchDup = { kind: kind, id: id }; },
    // --- ŠT-2c 2c-2a: vysledok editora dekoru ---------------------------
    // Modal zatvara VYHRADNE POTVRDENY zapis (kontrakt D-15): odmietnuty
    // necha pouzivatelovi rozpisany formular na mieste — ma opravit cislo,
    // nie pisat celu tabulku znova.
    editSaved: function(res){
      var m = mdModal();
      var info = res || {};
      mdEditBase = null;
      mdEditDupSnap = null;
      if (m && m.isOpen()){
        m.setBusy(false, { clear: true }); // pamat rozpisu zanika az na potvrdenie
        m.close();
      }
      // 2c-2b: po ZALOZENI dekoru ma pouzivatel stat V NOM — inak by po
      // zatvoreni formulara hladal v mriezke dlazdic, ci vobec vznikol
      // (a ceny doplna prave tam, v detaile). Katalog uz prisiel echom PRED
      // touto hlaskou, takze dlazdica existuje.
      if (String(info.mode || '') !== 'create' || !info.group_id) return;
      var key = 'g:' + info.group_id;
      if (!mdGroupByKey(key)) return;
      mdView = key;
      mdRenderLists();
    },
    // Vsetky chyby NARAZ, kazda pri svojom poli (rows: pri svojom riadku).
    editErrors: function(list){
      var m = mdModal();
      if (!m) return;
      m.setBusy(false);
      m.showErrors(list || []);
    },
    // Duplicitny par kod+dodavatel: druhe „Uložiť" ho POTVRDI — ale LEN pre
    // hodnoty, pri ktorych server duplicitu vypytal (review #5).
    editDuplicateCode: function(){
      var m = mdModal();
      if (!m) return;
      mdEditDupSnap = JSON.stringify(m.values());
      m.setBusy(false);
    },
    // Katalog sa medzitym zmenil / read-only / zlyhal zapis: odomkni, hodnoty
    // OSTAVAJU. Ak prislo cerstve echo, riadky sa dorovnaju z noveho katalogu
    // (a baseline omladne), takze „ulož znova" je SPLNITELNE — inak by hlaska
    // sludovala cestu, ktora neexistuje.
    editBlocked: function(){
      var m = mdModal();
      if (!m) return;
      m.setBusy(false);
      m.clearErrors();
      var stale = !!(mdEditBase && mdEditBase.rev !== MD_REV);
      // Rezim treba precitat PRED refreshom — ten baseline omladi.
      var creating = !!(mdEditBase && mdEditBase.mode === 'create');
      var res = mdEditRefresh();
      if (!stale || !res || !res.ok) return;
      if (creating){
        // Pri zakladani sa NEDOROVNAVA nic (v katalogu ziadny nas riadok
        // nie je) — hlaska „riadky sme dorovnali" by klamala.
        MD.setStatus('Katalóg sa medzitým zmenil — skús uložiť znova.', true);
        return;
      }
      MD.setStatus(res.touched
        ? 'Katalóg sa medzitým zmenil — riadky sme dorovnali, tvoje hodnoty ostali. Skontroluj označené riadky a ulož znova.'
        : 'Katalóg sa medzitým zmenil — riadky sme dorovnali, tvoje hodnoty ostali. Môžeš uložiť znova.', true);
    },
    // D-46: server pyta potvrdenie zmeny predvolby korpusu. Select sa VRATI na
    // skutocny default (nesmie vizualne zostat na nepotvrdenom materiali) a pod
    // nim sa ukaze lista s presnym rozpisom.
    confirmDefault: function(p){
      MD_PENDING = p.pending || null;
      mdSetProjectSelect(p.key, p.current);
      var bar = mdEl('mdConfirmBar'), txt = mdEl('mdConfirmText');
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
      var body = mdEl('mdDelBody');
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
      var btn = mdEl('mdDelConfirmBtn');
      if (btn) btn.disabled = !!(p.protected || (p.duplak_deps && p.duplak_deps.length));
      var m = mdEl('mdDeleteModal');
      if (m) m.style.display = '';
    },
    // D-83: skratka zo ŠTÚDIA — otvor detail dekoru a rovno modal
    // „Nahradiť UNI…" s TÝM materiálom, na ktorý používateľ klikol v KONTROLE.
    // Server pred týmto volaním overil model aj to, že materiál je stále UNI;
    // tu ostáva už len zhoda s katalógom, ktorý má okno naozaj načítaný.
    openReplaceUni: function(uniId){
      var key = mdGroupKeyForUni(MD_CATALOG, MD_SCHEMA2, uniId);
      if (!key){
        MD.setStatus('UNI materiál sa v katalógu nenašiel — obnov sekciu Materiály (Obnoviť).', true);
        return;
      }
      mdCloseForms();
      mdView = key;      // detail skupiny ostane pod modalom (kontext)
      mdRenderLists();
      if (!mdUniOpen(key, uniId)) MD.setStatus('UNI materiál sa medzitým zmenil.', true);
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
      var body = mdEl('mdUniBody');
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
      var ok = mdEl('mdUniConfirmBtn');
      if (ok) ok.style.display = MD_UNI_PENDING ? '' : 'none';
      var m = mdEl('mdUniModal');
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

  // ================= ŠT-2a: SEKCIA `mat` v okne Studio =====================
  //
  // Bezi TU, nie v `studio.js`: obsah sekcie je presun 1:1 a jeho jedina
  // autorita je tento subor (vzor `js/budget.js`, ktore si tiez kresli listu
  // aj telo svojej sekcie samo).

  // Zdielane helpery okna Studio (jantarove „Obnoviť"). V prehliadaci su
  // globalne — `studio.js` sa nacitava PRED tymto suborom; v Node testoch ich
  // treba requirovat (vzor `BUD_STUDIO` v budget.js). V okne Materialy je
  // premenna `null` a nikto ju nepouzije.
  var MAT_STUDIO = (typeof module !== 'undefined' && module.exports)
    ? require('./studio.js')
    : null;

  // ŠT-2b: `mdInSection()` (prepinac medzi oknom a sekciou) ZANIKOL spolu
  // s oknom — vetva „bezim v okne" uz neexistuje. `window.NX_MAT_SECTION`
  // v `studio.html` ostava ako CITATELNE prihlasenie sa do rezimu sekcie
  // (a ako marker pre guard test poradia skriptov).

  // ŠT-2b: premostenie do okna Materialy (`mdBridgeToWindow`) ZANIKLO — vsetky
  // tri toky bezia TU. Modaly ziju v kotve `#matModalRoot` MIMO tela sekcie
  // (prekreslenie ich nezhodi), a preto ich musi zavriet ODCHOD zo sekcie —
  // inak by viseli nad Kusovnikom.
  function mdDemosUpdateTip(){ return 'Aktualizovať kódy a ceny z Demosu'; }
  function mdUniTip(){ return 'Nahradiť UNI reálnym dekorom v celom projekte'; }
  function mdDemosUpdate(key){
    if (typeof mddLookup === 'function') mddLookup(key);
  }
  function mdDemosAdd(){
    if (typeof nxdaOpen === 'function') nxdaOpen();
  }
  function mdUniStart(key){
    if (!mdUniOpen(key)) MD.setStatus('UNI materiál sa medzitým zmenil.', true);
  }

  // Odchod zo sekcie `mat` (vola `studioGoSection` v studio.js PRED prepnutim).
  // Poradie je zavazne: NAJPRV sa ohlasi SERVERU (ten zrusi bezaci Demos fetch
  // a napise preco), az potom sa lokalne pozatvaraju modaly. Opacne poradie by
  // `nxdaClose` poslal `demos_family_cancel` skor, server by uz nemal co rusit
  // — a pouzivatel by sa nedozvedel, ze mu stahovanie skoncilo.
  function matOnLeaveSection(){
    if (window.sketchup && sketchup.mat_leave) sketchup.mat_leave('');
    matCloseModals();
  }
  function matCloseModals(){
    mdUniClose();
    mdDeleteClose();
    mdRestoreClose();
    mdSgClose();
    // Kotva D-15 zije MIMO tela sekcie (`#nxModalRoot`), takze editor dekoru by
    // po odchode ostal visiet nad Kusovnikom. Zatvorenie hodnoty NEZAHADZUJE —
    // pamat kostry ich podrzi do najblizsieho otvorenia.
    mdEditClose();
    if (typeof mddClose === 'function') mddClose();
    if (typeof nxdaClose === 'function') nxdaClose();
  }

  // LISTA sekcie (#17) — CISTA funkcia (Node test). Stav chodi ARGUMENTOM
  // (rovnaky vzor ako `bomToolsHtml` v studio.js), takze sa da testovat bez DOM.
  // Poradie je vzor listy Studia: PRIMARNA akcia vlavo, nastroje vpravo.
  // Obsah je ten isty ako `.mdbar` okna, len preusporiadany — nic nepribudlo
  // ani nezmizlo.
  function matToolsHtml(st){
    var s = st || {};
    var dis = s.ro ? ' disabled' : '';
    // ŠT-2b (review ŠT-2a #9): „Pridať z Demosu" je zase PRIMARNA akcia. V ŠT-2a
    // bola docasne `ghostbtn`, lebo v sekcii len premostovala do ineho okna —
    // teraz Demos bezi TU, takze najvyraznejsie tlacidlo sekcie znovu vedie na
    // hlavnu (a v praxi jedinu pouzivanu) cestu zakladania dekoru.
    var h = '<button type="button" class="primary" id="mdDemosAddBtn"' + dis +
      ' title="Pridať dekor z Demosu" onclick="mdDemosAdd()">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-cloud-download"/></svg> Pridať z Demosu</button>' +
      // ŠT-2c 2c-2b: vedie na D-69 editor v rezime `create` (ten isty formular
      // ako „Upraviť…"). Batchovy formular s preset cipmi tu ZANIKOL — ostal
      // v detaile dekoru ako „+ variant" pre typy, ktore maju dalsiu identitu
      // (zastena, PD).
      '<button type="button" class="ghostbtn" id="mdNewDecorBtn"' + dis +
      ' title="Pridať materiál ručne (bez Demosu)" onclick="mdCreateOpen()">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-plus"/></svg> Pridať ručne</button>' +
      '<div class="searchbox"><svg class="ic" aria-hidden="true"><use href="#i-search"/></svg>' +
      '<input id="mdSearch" type="text" placeholder="Hľadať dekor, výrobcu alebo kód"' +
      ' value="' + mdEsc(s.q || '') + '" oninput="mdSearchInput()"></div>' +
      '<select id="mdGroupMode" onchange="mdRenderLists()" title="Zoskupenie dlaždíc">' +
      '<option value="man"' + (s.mode === 'az' ? '' : ' selected') + '>Podľa výrobcu</option>' +
      '<option value="az"' + (s.mode === 'az' ? ' selected' : '') + '>A–Z</option></select>' +
      '<span class="spacer"></span>';
    // GH #93 P2 (10. kolo): rollback sa ukazuje LEN so SCHEMA 2 a existujucou
    // predmigracnou zalohou; v nudzovom rezime ho nesie banner nad zoznamom.
    if (s.backup && !s.ro){
      h += '<button type="button" class="ghostbtn" id="mdRestoreBtn"' +
        ' title="Vráti katalóg do stavu pred migráciou (jednorazovo preskočí ďalšiu migráciu)"' +
        ' onclick="mdRestoreOpen()"><svg class="ic" aria-hidden="true"><use href="#i-info"/></svg>' +
        ' Obnoviť zálohu</button>';
    }
    // Jantarove „Obnoviť" je ZDIELANY markup celeho okna (`studio.js`) — sekcia
    // ho nesmie kreslit druhykrat (vzor `budRefreshBtnHtml` v budget.js).
    // V prehliadaci je to globalna funkcia, v Node testoch pride requirom.
    var refresh = (typeof refreshBtnHtml === 'function')
      ? refreshBtnHtml
      : (MAT_STUDIO ? MAT_STUDIO.refreshBtnHtml : null);
    if (refresh){
      h += refresh(s.stale === true,
                   'Prepočítať počty „Použité v projekte" z aktuálneho modelu');
    }
    return h;
  }

  // `stale` podava `studio.js` — jantarovy priznak je stav OKNA a ma jedinu
  // autoritu (`staleFlag`), sekcia si ho neodvodzuje.
  function matToolsState(stale){
    return { ro: MD_RO, q: MD_Q, mode: mdGroupMode(),
             backup: MD_SCHEMA2 && MD_HAS_BACKUP, stale: stale === true };
  }
  function matRenderTools(stale){
    var box = mdEl('sectools');
    if (box) box.innerHTML = matToolsHtml(matToolsState(stale));
  }

  // TELO sekcie. Je to JEDEN uzol, ktory sa vytvori RAZ zo sablony v
  // studio.html a potom uz LEN putuje: prepnutie sekcie ho z `#secbody`
  // vyberie (`innerHTML = ''` ineho renderu), navrat ho vrati aj s rozpisanym
  // formularom a hodnotami poli. Bez toho by kazdy odchod do Kusovnika zmazal
  // rozrobeny „Nový dekor".
  var MAT_BODY = null;
  function matBodyNode(){
    if (MAT_BODY) return MAT_BODY;
    var tpl = mdEl('matBodyTpl');
    MAT_BODY = document.createElement('div');
    MAT_BODY.id = 'matBody';
    if (tpl && tpl.content) MAT_BODY.appendChild(tpl.content.cloneNode(true));
    else if (tpl) MAT_BODY.innerHTML = tpl.innerHTML;
    return MAT_BODY;
  }

  // KONTRAKT (audit #2): `NX.setStudio` NESMIE zmazat rozpisany formular ani
  // rozpisanu bunku. Preto sa telo NEPREKRESLUJE — len sa (pripadne) vrati do
  // `#secbody` a data sa nasadia cez `mdRenderAll`, ktory si okolo renderu
  // odlozi a obnovi fokus (vzor `mdFocusInline` / dirty bunka).
  function matRenderBody(){
    var box = mdEl('secbody');
    if (!box) return;
    var node = matBodyNode();
    if (node.parentNode !== box){
      box.innerHTML = '';
      box.appendChild(node);
    }
    mdRenderAll();
  }

  // Modelovy kontext sekcie z payloadu Studia (`ST.mat`). Katalog je v nom LEN
  // pri prvom pushi a po prepnuti dokumentu — inak chodi echom
  // (`NX.setMatCatalog`), viz `StudioDialog#mat_payload`.
  function matApplyState(m){
    if (!m) return;
    MD_MODEL_GUID = m.model_guid || '';
    MD_USED = m.used || {};
    MD_USED_WHERE = m.used_where || {};
    // Zoznam ID drží aj starší payload bez `used_ids` pri živote — skupina
    // „Použité v projekte" vtedy len chýba, ponuka funguje ďalej.
    MD_USED_IDS = m.used_ids || { sheets: [], edges: [] };
    MD_PROJECT = m.project || {};
    MD_CABINETS = m.cabinets || 0;
    if (m.catalog) mdSetCatalog(m.catalog); // LEN stav — kresli az matRenderBody
  }

  // Napojenie na kanal Studia. `studio.js` (a za nim `budget.js`) uz `window.NX`
  // vytvorili — tento subor sa nacitava AZ ZA nimi, takze obal je bezpecny.
  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var matPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      // Stav sa nasadi PRED renderom Studia — `matRenderBody` uz kresli
      // z cerstvych dat a nikto nekresli dvakrat.
      matApplyState(data && data.mat);
      matPrevSetStudio(data);
    };
    // Katalogove echo (BEZ zdvihu generacie) — po kazdom zapise do katalogu.
    NX.setMatCatalog = function(cat){
      if (!cat) return;
      mdSetCatalog(cat);
      mdRenderAll(); // no-op, kym je telo sekcie odpojene (mdEl vrati null)
    };
  }

  // D-41 Node testy (tests/js/test_decor_groups.js) — v CEF je module undefined.
  // Exportuju sa len CISTE funkcie (bez DOM); ready() sa vola len v CEF (window).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { groupCatalogByDecor: groupCatalogByDecor, sheetChipLabel: sheetChipLabel,
      edgeChipLabel: edgeChipLabel, mdMatchGroup: mdMatchGroup, mdBuildSections: mdBuildSections,
      // D-44 (tests/js/test_decor_formats.js) — ciste funkcie bez DOM
      mdFormatHint: mdFormatHint, mdBuildSheetVariants: mdBuildSheetVariants,
      mdSheetDim: mdSheetDim,
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
      // D-82 — skupinova farba dekoru (swatch v hlavicke detailu)
      mdColorEditable: mdColorEditable, mdGroupSwatch: mdGroupSwatch,
      // D-83 — skratka z KONTROLY: dlazdica k danemu UNI materialu
      mdGroupKeyForUni: mdGroupKeyForUni,
      // M-A3b — vazby na Demos v UI (D-56/D-60/D-62/D-63)
      mdTileHtml: mdTileHtml, mdDateLabel: mdDateLabel, mdDemosBtn: mdDemosBtn,
      mdDetailHtml: mdDetailHtml,
      // M-A3c — editor variantov (D-67 suggest, D-68 gramatika + pruhy vynimiek)
      mdNormText: mdNormText, mdSuggestFilter: mdSuggestFilter,
      // ŠT-2c (audit #10/#11): nasepkavac ma DVA kontrakty voci D-15 modalu —
      // Escape patri jemu (nie modalu) a scroll VNUTRI karty ho zatvara.
      // Oba sa daju overit iba behom, preto sa `mdSgBind`/`mdSgClose`
      // exportuju (tests/js/test_st2c_modal.js).
      mdSgBind: mdSgBind, mdSgClose: mdSgClose,
      mdSplitExtraTokens: mdSplitExtraTokens, mdExtraKey: mdExtraKey,
      mdExtraFmtChips: mdExtraFmtChips,
      // M-A3e — rucna vazba (D-71): klientske zrkadlo serverovej validacie
      mdDemosUrlLocalError: mdDemosUrlLocalError,
      // D-97 — upozornenie na neznamy typ dosky (ciste, bez DOM)
      mdUnknownTypeWarning: mdUnknownTypeWarning,
      // M-B2 — „Nahradit UNI…" (ciste funkcie bez DOM)
      mdUniTargets: mdUniTargets, mdUniSummaryLines: mdUniSummaryLines,
      // ŠT-2a — sekcia `mat` v Studiu (tests/js/test_st2a_mat.js). `matToolsHtml`
      // je cista funkcia; `matRenderBody` DOM potrebuje a exportuje sa ZAMERNE —
      // kontrakt „push zo servera nezmaze rozpisany formular" (audit #2) sa inak
      // nedal overit nicim nez klikanim. V prehliadaci ho `studio.js` vola ako
      // globalnu funkciu, nie cez export.
      matToolsHtml: matToolsHtml, matRenderBody: matRenderBody,
      // ŠT-2b — odchod zo sekcie zavrie modaly a zrusi bezaci Demos fetch
      matOnLeaveSection: matOnLeaveSection,
      // ŠT-2d — „Kde sa používa" + deep-link z karty dielca
      // (tests/js/test_st2d_kde.js). `mdWhereHtml`/`mdPartsSk`/`mdAnchorGroupKey`
      // su CISTE funkcie; `matOpenAnchor` a `mdWhereOwner` potrebuju stav sekcie
      // a exportuju sa ZAMERNE — kontrakty „kotva otvori detail" a „oko posiela
      // material_ids vlastnika" sa inak nedaju overit nicim nez klikanim.
      mdWhereHtml: mdWhereHtml, mdPartsSk: mdPartsSk, mdItemsSk: mdItemsSk,
      mdWhereCount: mdWhereCount, mdAnchorGroupKey: mdAnchorGroupKey,
      matOpenAnchor: matOpenAnchor, mdWhereOwner: mdWhereOwner, mdWhereEdge: mdWhereEdge,
      // `matApplyState` je vstup payloadu `ST.mat` do stavu sekcie — exportuje
      // sa, aby sa dal rozpis „Kde sa používa" overit BEZ celeho renderu okna.
      matApplyState: matApplyState,
      // ŠT-2c 2c-2a — D-69 editor dekoru. `mdEditFields`/`mdEditPayload`/
      // `mdEditNum` su CISTE funkcie; `mdEditOpen`/`mdEditDropDirty`/`MD`
      // potrebuju DOM a exportuju sa ZAMERNE — kontrakty „base_rev zmrazeny
      // pri otvoreni" a „otvorenie zahodi dirty bunky" sa inak nedaju overit
      // nicim nez klikanim (tests/js/test_st2c_editor.js).
      mdEditFields: mdEditFields, mdEditPayload: mdEditPayload, mdEditNum: mdEditNum,
      mdEditSheetRow: mdEditSheetRow, mdEditEdgeRow: mdEditEdgeRow,
      mdEditOpen: mdEditOpen, mdEditDropDirty: mdEditDropDirty, mdEditKey: mdEditKey,
      mdEditRefresh: mdEditRefresh,
      // ŠT-2c 2c-2b — „Pridať ručne" (mode create). `mdCreateFields`/
      // `mdCreatePayload`/`mdCreateRows` su CISTE funkcie; `mdCreateOpen`
      // a `mdOpenDecorForm` potrebuju DOM a exportuju sa ZAMERNE — kontrakty
      // „prazdny formular", „uspech otvori detail noveho dekoru" a „zakladanie
      // z batch formulara ZANIKLO" sa inak overit nedaju
      // (tests/js/test_st2c_create.js).
      mdCreateFields: mdCreateFields, mdCreatePayload: mdCreatePayload,
      mdCreateRows: mdCreateRows, mdCreateOpen: mdCreateOpen,
      mdOpenDecorForm: mdOpenDecorForm,
      mdSetCatalog: mdSetCatalog, MD: MD };
  }
  // ŠT-2a (audit #7): `sketchup.ready('')` tu ZANIKLO. V okne Materialy bol
  // tento subor POSLEDNY a jeho `ready` znamenal „HTML je nacitane". V Studiu
  // ho posiela `studio.js` (window.onload) — druhe volanie by okno prinutilo
  // poslat CELY payload dvakrat. ŠT-2b: okno Materialy zaniklo, takze `ready`
  // uz ma jedineho odosielatela.
