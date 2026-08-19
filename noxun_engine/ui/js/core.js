
  var DEFAULTS = { lower: {}, upper: {} };
  var TEMPLATES = [];
  var activeZoneId = null;
  var cabEditsInFlight = false; // D-07 Codex B2: apply odoslany, echo este nedoslo
  // (D-08 currentCabTab zanikol v UI-B1 — aktivny kontext drzi NXShell v js/shell.js)
  var tplNameSuggestion = '';   // D-14: navrh nazvu sablony z Ruby (cabinet_payload)
  var selectedCabId = null;
  var currentZoneTree = null;   // strukturny strom zon (nový vklad aj oznaceny)
  var previewMode = 'zones';
  var applyTimer = null;
  var frontItems = null;        // rozlozene cela z backendu
  // UI-B2: posledny payload kovania (config.hardware oznacenej skrinky). Drzi sa
  // LEN preto, aby z neho vedel kreslit nahlad (projekcia Kovanie a ghost
  // vrstva) — je to TEN ISTY payload, ktory dostava sekcia kovania, ziadne nove
  // pole a ziadny vlastny vypocet. null = nic oznacene.
  var hwItems = null;
  var PALETTE = ['#46beff','#6eff96','#ffaf50','#dc78ff','#ffeb5a'];
  // V0.3 materialy + ABS
  var MATERIALS = { sheets: [], edges: [] }; // katalog z backendu
  // D-90: uchytkove profily z Ruby registry (FrontProfiles.options) — poradie
  // volby v riadku cela AJ zdroj skratenia pre 2D nahlad. JS si ZIADNY vlastny
  // zoznam profilov nedrzi; prazdne pole = volba sa vobec nezobrazi.
  // (volitelny parameter `list` pouzivaju LEN Node testy — v paneli sa vzdy
  //  cita zivy register z Ruby)
  var FRONT_PROFILES = [];
  function frontProfileRec(id, list){
    if (!id || id === 'none') return null;
    var arr = list || FRONT_PROFILES;
    for (var i = 0; i < arr.length; i++){
      if (arr[i].id === id) return arr[i];
    }
    return null; // profil z novsej verzie = neutral (rovnako ako Ruby normalize)
  }
  // Skratenie cela (mm) pre nahlad — neznamy profil neskracuje nic.
  function frontProfileReduction(id, list){
    var r = frontProfileRec(id, list);
    return (r && r.reduction > 0) ? r.reduction : 0;
  }
  // ---- D-96: sekcia „Úchytky" (nahradila cyklenie ikonou v riadku) ---------
  // Ponuka profilov: NEUTRAL „Bez profilu" prvy, potom registry vo VLASTNOM
  // poradi (poradie urcuje Ruby, JS ho nemeni). -> [{ id, name }]
  function frontProfileOptionList(list){
    var out = [{ id: 'none', name: 'Bez profilu' }];
    (list || FRONT_PROFILES).forEach(function(p){
      if (p && p.id) out.push({ id: p.id, name: p.name || p.id });
    });
    return out;
  }
  // Cela, ktorych sa rozsah tyka. scope = 'all' | 'door' | 'drawer_front'.
  // „Bez čela" (type 'none') NIKDY — nema na com profil drzat (rovnako to
  // robi Ruby normalize, ktora mu profil zhodi na 'none').
  function frontProfileScopeItems(items, scope){
    return (items || []).filter(function(it){
      if (!it || it.type === 'none') return false;
      return scope === 'all' || it.type === scope;
    });
  }
  // Spolocna hodnota profilu v rozsahu:
  //   '<id>' = vsetky cela rozsahu maju ten isty profil ('none' = ziadny),
  //   ''     = rozsah je PRAZDNY (nie je co nastavovat),
  //   null   = cela rozsahu sa lisia (select ukaze „(rôzne)").
  function frontProfileCommon(items, scope){
    var list = frontProfileScopeItems(items, scope);
    if (!list.length) return '';
    var first = list[0].profile || 'none';
    for (var i = 1; i < list.length; i++){
      if ((list[i].profile || 'none') !== first) return null;
    }
    return first;
  }
  // Veta do skupiny Uchytky — co je NASADENE (nie co sa chysta).
  // items = [{ label:'F1', type, profile }] v DATOVOM poradi; reg = registry.
  function frontProfileStateText(items, reg){
    var list = (items || []).filter(function(it){ return it && it.type !== 'none'; });
    if (!list.length) return 'Skrinka zatiaľ nemá čelá, na ktorých by profil sedel.';
    var order = [], byId = {};
    list.forEach(function(it){
      var id = it.profile || 'none';
      if (!byId[id]){ byId[id] = []; order.push(id); }
      byId[id].push(it.label);
    });
    if (order.length === 1 && order[0] === 'none') return 'Žiadne čelo nemá úchytkový profil.';
    return order.map(function(id){
      var rec = frontProfileRec(id, reg);
      return (rec ? rec.short || rec.name : 'bez profilu') + ': ' + byId[id].join(', ');
    }).join(' · ');
  }
  var partCard = null;                        // aktualna karta dielca (null = ziadny dielec)
  // D3: mapa front_id -> texty kovania ("4× záves", "NL 500") pre badge v riadkoch ciel.
  var HW_FRONT_BADGES = {};
  // UI-C3: SETY, ktore sa pre cela naozaj kupia (D-92 `purchase.set_name`).
  // Autorita je server (HardwareSets.explain) — JS nerozhoduje, co sa kupuje,
  // len zbiera uz hotove nazvy pod ich vlastnika.
  var HW_FRONT_BUY = {};
  // Ciste (Node testy): front_id -> [nazvy setov]. Ten isty set pri viacerych
  // kridlach sa zapise RAZ. Polozka bez `purchase` (alebo bez setu) sa vynecha.
  function collectFrontHwBuy(hardware){
    var out = {};
    (hardware || []).forEach(function(it){
      var m = String((it && it.owner_part_key) || '').match(/^front:([^\/]+)\//);
      if (!m) return;
      var setName = (it.purchase && it.purchase.set_name) ? String(it.purchase.set_name) : '';
      if (!setName) return;
      var list = (out[m[1]] = out[m[1]] || []);
      if (list.indexOf(setName) < 0) list.push(setName);
    });
    return out;
  }
  function buildFrontHwBadges(hardware){
    HW_FRONT_BADGES = {};
    HW_FRONT_BUY = collectFrontHwBuy(hardware);
    var hinges = {}; // front_id -> sucet zavesov cez vsetky kridla
    (hardware || []).forEach(function(it){
      var m = String(it.owner_part_key || '').match(/^front:([^\/]+)\//);
      if (!m) return;
      var fid = m[1];
      if (it.generic_type === 'hinge'){
        hinges[fid] = (hinges[fid] || 0) + (it.quantity || 0);
      } else if (it.generic_type === 'slide'){
        var nl = (it.params || {}).nominal_length;
        (HW_FRONT_BADGES[fid] = HW_FRONT_BADGES[fid] || [])
          .push(nl != null ? ('výsuv NL ' + Math.round(nl)) : (it.quantity + '× výsuv'));
      }
    });
    for (var fid in hinges){
      var n = hinges[fid];
      (HW_FRONT_BADGES[fid] = HW_FRONT_BADGES[fid] || [])
        .unshift(n + '× ' + (n === 1 ? 'záves' : 'závesy'));
    }
  }
  // Codex #178 P2: ZIVY refresh po zmene v Katalógu kovania (`push_hardware_sets`).
  // Ten payload nesie identitu riadku + `purchase`, ale NIE počty ani parametre —
  // preto sa prestavuje LEN mapa setov. Badge z plánu (závesy, NL výsuvu) sa
  // zmenou katalógu nemení a ostáva z posledného `loadSelected`.
  function refreshFrontHwBuy(items){
    HW_FRONT_BUY = collectFrontHwBuy(items);
  }
  function frontHwBadge(fid){
    var arr = HW_FRONT_BADGES[fid];
    return arr && arr.length ? arr.join(' · ') : null;
  }
  function frontHwBuy(fid){
    var arr = HW_FRONT_BUY[fid];
    return arr && arr.length ? arr.join(' · ') : null;
  }
  var stableIdSeq = 0;
  function newStableId(prefix){
    stableIdSeq += 1;
    return prefix + Date.now().toString(36) + '-' + stableIdSeq.toString(36) + '-' +
      Math.random().toString(36).slice(2, 8);
  }

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function hasOwn(o,k){ return o && Object.prototype.hasOwnProperty.call(o, k); }
  function fmtmm(v){ return (v==null||v==='')?'?':Math.round(parseFloat(v)); }

  // Farba ABS podla hrubky (standard 7.6): 1,0 cervena / 2,0 zelena / bez siva.
  function absColorByThickness(th){
    if (th==null) return '#b0bec5';
    var t = parseFloat(th);
    if (Math.abs(t-1.0)<0.05) return '#e53935';
    if (Math.abs(t-2.0)<0.05) return '#43a047';
    return '#8e24aa'; // ina hrubka (mimo legendy)
  }
  function absThicknessOf(absId){
    if (!absId) return null;
    for (var i=0;i<MATERIALS.edges.length;i++){ if (MATERIALS.edges[i].id===absId) return MATERIALS.edges[i].thickness; }
    return null;
  }
  function absColorOf(absId){ return absId ? absColorByThickness(absThicknessOf(absId)) : '#b0bec5'; }

  // ===== D-85 (UI-03): napojenie zdielaneho comboboxu na katalog ================
  // nx_combo.js sam ZIADNY katalog nepozna — vsetky data mu podava panel dvoma
  // hookmi. Vdaka tomu je komponent prenositelny do dalsich okien bez toho, aby
  // si nosil kopiu MATERIALS.
  //   * farba stvorceka: dekor berie farbu z katalogu, ABS paska z HRUBKY
  //     (rovnaka legenda ako riadky hran a .absleg — standard 7.6),
  //   * "Pouzite v projekte": ciste odvodeny zoznam id zo serveroveho payloadu
  //     (materials.used_ids) — panel nic nedopocitava a nic si nepamata.
  // Farba dekoru je v katalogu POLE [r,g,b] (tak ju drzi Materials aj payload),
  // nie CSS retazec — do style atributu sa musi previest. Zrkadlo rgbToHex
  // z okna Materialy, ale BEZ nahradnej farby: neznamy vstup = ziadny stvorcek
  // (radsej nic nez vymyslena farba).
  function nxRgbHex(rgb){
    if (!rgb || rgb.length !== 3) return '';
    var out = '#';
    for (var i = 0; i < 3; i++){
      var c = parseInt(rgb[i], 10);
      if (isNaN(c)) return '';
      c = Math.max(0, Math.min(255, c));
      out += ('0' + c.toString(16)).slice(-2);
    }
    return out;
  }
  function nxComboColorOf(kind, value){
    if (!value) return '';
    if (kind === 'abs') return absColorOf(value);
    var rec = sheetRecOf(value);
    return rec ? nxRgbHex(rec.color) : '';
  }
  function nxComboUsedOf(kind){
    var u = MATERIALS.used_ids || {};
    return (kind === 'abs' ? u.edges : u.sheets) || [];
  }
  // Codex #167 P2: zoznam pouzitych sa meni pri KAZDOM zapise materialu (vratane
  // Spat/Znova a vkladania), ale CITA sa len pri otvoreni ponuky. Preto si ho
  // combobox pri otvoreni VYPYTA — server tak nemusi robit plny scan modelu pri
  // kazdom kliku vo vybere (push_selected je horuca cesta). Odpoved chodi cez
  // NX.setUsedIds a prekresli uz otvoreny zoznam.
  function nxComboRequestUsed(){
    if (window.sketchup && sketchup.nx_used_ids) sketchup.nx_used_ids('');
  }
  if (typeof NXCombo !== 'undefined' && NXCombo){
    NXCombo.setColorResolver(nxComboColorOf);
    NXCombo.setUsedResolver(nxComboUsedOf);
    NXCombo.setUsedRefresher(nxComboRequestUsed);
  }

  // D-45: rozsah hrubky korpusu/cela — zrkadlo Ruby CabinetBuilder::THICKNESS_RANGE.
  var TH_RANGE = [6, 50];
  // D-45 (audit F10): mm s desatinnou CIARKOU pre UI texty — cele cisla bez
  // desatin ('18'), inak jedno desatinne miesto ('18,6'). Zrkadlo Panel.fmt_mm.
  function mmLabel(v){
    // GH P2: 2 desatinne miesta — zhodne s Materials.fmt_mm (18,65 nesmie byt 18,7).
    var n = parseFloat(v);
    if (isNaN(n)) return '';
    var r = Math.round(n*100)/100;
    if (Math.abs(r - Math.round(r)) < 0.001) return String(Math.round(r));
    return String(r).replace('.', ',');
  }
  // UI-B3: texty informacneho stlpca Zakladnych z payloadu skrinky. CISTA
  // funkcia (testovana v Node) — panel nic nedopocitava, cisla posiela server
  // (parts_count / parts_area_m2 v cabinet_payload). Chybajuci udaj = '—'
  // (radsej pomlcka nez vymyslene cislo); typ badge je tiez odtialto, aby sa
  // slovenske nazvy typov nepisali na dvoch miestach.
  var NX_TYPE_LABEL = { lower: 'Dolná', upper: 'Horná' };
  function nxCabInfo(c){
    var p = c || {};
    var n = parseInt(p.parts_count, 10);
    var a = parseFloat(p.parts_area_m2);
    return {
      parts: (isNaN(n) || n <= 0) ? '—' : String(n),
      area: (isNaN(a) || a <= 0) ? '—' : (mmLabel(a) + ' m²'),
      type: NX_TYPE_LABEL[p.type] || NX_TYPE_LABEL.lower
    };
  }
  // FIX 2: hrubkove predikaty pre filter doskovych materialov (tolerancia 0,05 mm).
  // Prazdny/neplatny cielovy rozmer -> nefiltruj (radsej vsetko nez nic).
  function thMatch(target){
    var t = parseFloat(target);
    if (isNaN(t)) return function(){ return true; };
    // V0.6 M-B1: UNI prejde kazdym hrubkovym filtrom (hrubku urcuje dielec).
    return function(s){ return s.uni === true || Math.abs(parseFloat(s.thickness) - t) < 0.05; };
  }
  // D-45: doska je pouzitelna ako korpus/celo, ked je jej hrubka v rozsahu dosky —
  // konkretnu hrubku prevezme dielec z materialu (server), nie naopak.
  function rangeMatch(){
    return function(s){
      if (s.uni === true) return true; // M-B1: UNI bez hrubkoveho zavazku
      var t = parseFloat(s.thickness);
      return !isNaN(t) && t >= TH_RANGE[0]-0.001 && t <= TH_RANGE[1]+0.001;
    };
  }
  // D-45: cela uz NIE su natvrdo 18/19 — beru katalogovu hrubku sveho materialu
  // (geometriu prisposobi server, materialized_part). Filter drzi len rozsah dosky.
  function frontMatch(){ return rangeMatch(); }
  // D-45: dopad vyberu dosky KORPUSU na hrubku — inohrubkova doska sa NEZAKAZUJE,
  // len dopredu povie, ze hrubku korpusu prevezme (autorita je server). Vrati ''
  // ked sa hrubky zhoduju alebo je vstup neplatny.
  function bodyThicknessNote(sheetThickness, currentThickness){
    var t = parseFloat(sheetThickness), c = parseFloat(currentThickness);
    if (isNaN(t) || isNaN(c) || Math.abs(t-c) < 0.05) return '';
    if (t < TH_RANGE[0]-0.001 || t > TH_RANGE[1]+0.001) return ' · (mimo rozsahu ' + mmLabel(TH_RANGE[0]) + '–' + mmLabel(TH_RANGE[1]) + ' mm)';
    return ' · (prevezme hrúbku ' + mmLabel(t) + ')';
  }
  // FIX 2: naplni <select> doskami, ale hrubkovo NEKOMPATIBILNE su disabled + oznacene "(nekompatibilné)".
  // Aktualne vybranu (aj legacy nesuladnu) dosku nechaj vyberatelnu, nech ju vie zobrazit. Pri
  // prazdnom vysledku ostanu vsetky viditelne (disabled) — pouzivatel vidi katalog. Zachova hodnotu.
  // D-45: matchFn rozhoduje o DISABLED (co server odmietne), noteFn o texte pripony
  // pri KAZDEJ volbe (napr. „prevezme hrúbku 18,6" — legitimna volba, ktora len
  // zmeni hrubku). Bez noteFn ostava povodne spravanie „(nekompatibilné)".
  function fillSheetSelectFiltered(sel, includeInherit, matchFn, keepValue, inheritLabel, noteFn, withDuplakOffers){
    if (!sel) return;
    var cur = (keepValue !== undefined && keepValue !== null) ? keepValue : sel.value;
    var html = includeInherit ? '<option value="">'+esc(inheritLabel || '(dediť z projektu)')+'</option>' : '';
    MATERIALS.sheets.forEach(function(s){
      var ok = matchFn ? matchFn(s) : true;
      var keep = ok || (s.id === cur);
      var note = noteFn ? noteFn(s) : (ok ? '' : ' · (nekompatibilné)');
      html += '<option value="'+esc(s.id)+'"'+(keep?'':' disabled')+'>'+esc(s.label)+esc(note)+'</option>';
    });
    // D-49 (audit B3): virtualne duplaky "(duplak x2)" LEN na vyziadanie
    // volajuceho — telo korpusu, dielec, karta dosky. Vklad dosky, cela,
    // chrbat ani projektove selecty ich nikdy nedostanu. Vyber posle
    // "duplak2:<id>", realne ID rozriesi server (ensure_duplak_for).
    if (withDuplakOffers){
      (MATERIALS.duplak_offers || []).forEach(function(s){
        var ok = matchFn ? matchFn(s) : true;
        var note = noteFn ? noteFn(s) : (ok ? '' : ' · (nekompatibilné)');
        html += '<option value="'+esc(s.id)+'"'+(ok?'':' disabled')+'>'+esc(s.label)+esc(note)+'</option>';
      });
    }
    sel.innerHTML = html;
    sel.value = cur;
  }
  // D-36: normalizacia dekoru pre zoskupenie ABS — orez whitespace (legacy/prazdny),
  // NIE lowercase (B2: presna case-sensitive zhoda ako drzi katalog). nil/prazdny => ''.
  function normDecor(d){ return String(d==null?'':d).trim(); }
  // 2A-3b (audit F11): rezim katalogu VYHRADNE z payloadu servera
  // (materials_payload.catalog_schema) — ziadne inferovanie z pritomnosti
  // group_id. Chybajuci/nezmyselny udaj = legacy 1 (stary payload z CEF cache).
  function catalogSchemaOf(m){
    var n = parseInt(m && m.catalog_schema, 10);
    return isNaN(n) ? 1 : n;
  }
  function catalogSchemaNow(){ return catalogSchemaOf(MATERIALS); }
  // GH #91 P1 (2. kolo): CAPABILITY panela — FIXNA konstanta (vzor
  // MD_CLIENT_SCHEMA), NIE echo serveroveho markera. Echo by buducu schemu 3
  // falosne vydavalo za podporovanu a stary panel by smel mutovat novsi
  // katalog. Zdvihnut az ked panel novsi format REALNE podporuje.
  var PANEL_CLIENT_SCHEMA = 2;
  // 2A-3b: cely zaznam dosky z katalogu (group_id/structure pre zrkadlo). null = neznamy.
  // D-49 (GH #116 P2): virtualna hodnota "duplak2:<id>" — zrkadla (ABS
  // pouzitelnost, hrubkove poznamky) hodnotia ZDROJOVY zaznam s cielovou
  // hrubkou x nasobic; bez toho by modal hlasil prazdny dekor "bez pasky".
  function sheetRecOf(materialId){
    if (!materialId) return null;
    var vm = String(materialId).match(/^duplak([23]):(.+)$/);
    if (vm){
      for (var j=0;j<MATERIALS.sheets.length;j++){
        if (MATERIALS.sheets[j].id===vm[2]){
          var src = MATERIALS.sheets[j];
          var out = {};
          for (var k in src){ if (Object.prototype.hasOwnProperty.call(src,k)) out[k]=src[k]; }
          out.id = materialId;
          out.thickness = Math.round(parseFloat(src.thickness)*parseInt(vm[1],10)*100)/100;
          return out;
        }
      }
      return null;
    }
    for (var i=0;i<MATERIALS.sheets.length;i++){
      if (MATERIALS.sheets[i].id===materialId) return MATERIALS.sheets[i];
    }
    return null;
  }
  // 2A-3b: zrkadlo Ruby identity_norm (trim, viacnasobne medzery na jednu, upcase)
  // pre porovnanie struktury povrchu. Prazdna/nil => ''.
  function identityNorm(s){ return String(s==null?'':s).trim().replace(/\s+/g,' ').toUpperCase(); }
  // 2A-3b: group_id zaznamu ako trimnuty string ('' = ziadny/hybrid).
  function groupIdOf(rec){ return rec ? String(rec.group_id==null?'':rec.group_id).trim() : ''; }
  // D-36: resolved dekor doskoveho materialu podla id z AKTUALNEHO katalogu MATERIALS
  // (B1: odvodene PRI RENDERI zo zivého katalogu, nie z payloadu). Neznamy id => ''.
  function decorOfSheet(materialId){
    if (!materialId) return '';
    for (var i=0;i<MATERIALS.sheets.length;i++){
      if (MATERIALS.sheets[i].id===materialId) return normDecor(MATERIALS.sheets[i].decor);
    }
    return '';
  }
  // D-36 (cista funkcia — JEDEN zdroj pravdy pre dielec aj dosku): rozdeli ABS pasky na
  // skupiny podla zhody dekoru. Vstup: edges (katalog), decor (resolved dekor materialu
  // dielca/dosky), currentValue (aktualne vybrana ABS hodnota). Vystup:
  //   { recommended:[edge...], others:[edge...], preserve: value|null }.
  // B2 owner decision: recommended = VSETKY pasky s presne zhodnym (trim, case-sensitive)
  // dekorom, zoradene hrubkou VZOSTUPNE (1,0 -> 2,0). F4: prazdny dekor => recommended
  // prazdny (renderer da plochy fallback bez optgroup). F5: currentValue mimo katalogu
  // => preserve (zachovavacia volba, nech aktualna hodnota prezije regrouping).
  function groupAbsEdges(edges, decor, currentValue){
    edges = edges || [];
    var nd = normDecor(decor);
    var recommended = [], others = [], seen = {};
    edges.forEach(function(a){
      seen[a.id] = true;
      if (nd!=='' && normDecor(a.decor)===nd) recommended.push(a); else others.push(a);
    });
    // stabilne zoradenie odporucanych hrubkou vzostupne (Array.sort je v CEF stabilny);
    // D-41 sekundarne SIRKOU vzostupne — sirkove varianty (konkretne) pred legacy
    // paskou bez sirky (univerzalna ide na koniec skupiny rovnakej hrubky).
    recommended.sort(absEdgeSortAsc);
    // F5: '' (Bez ABS) a '__inherit__' su fixne volby, nie ABS id — tie nezachovavaj
    var preserve = (currentValue && currentValue!=='__inherit__' && !seen[currentValue]) ? currentValue : null;
    return { recommended: recommended, others: others, preserve: preserve };
  }
  // Zoradenie odporucanych pasok (zdielane schema 1 aj 2): hrubka vzostupne,
  // v ramci hrubky sirka vzostupne, legacy bez sirky na koniec skupiny hrubky.
  function absEdgeSortAsc(x,y){
    var t = (parseFloat(x.thickness)||0)-(parseFloat(y.thickness)||0);
    if (t) return t;
    var xw = (x.width===null || x.width===undefined) ? null : parseFloat(x.width);
    var yw = (y.width===null || y.width===undefined) ? null : parseFloat(y.width);
    if (xw===null && yw===null) return 0;
    if (xw===null) return 1;
    if (yw===null) return -1;
    return xw-yw;
  }
  // 2A-3b (audit F12): skupiny pri katalogu SCHEMA 2 — Odporucane = pasky
  // ROVNAKEJ skupiny (group_id dosky) s presnou NEPRAZDNOU strukturou dosky
  // ALEBO vedomym universal:true. Pasky CUDZEJ struktury tej istej skupiny idu
  // do "Ostatne" (vedoma manualna volba — picker cez struktury NIKDY neprechadza,
  // dve prazdne struktury NIE su zhoda). Zoradenie a preserve ako v schema 1.
  function groupAbsEdgesV2(edges, sheetRec, currentValue){
    edges = edges || [];
    var gid = groupIdOf(sheetRec);
    var st = identityNorm(sheetRec ? sheetRec.structure : '');
    var recommended = [], others = [], seen = {};
    edges.forEach(function(a){
      seen[a.id] = true;
      var sameGroup = gid!=='' && groupIdOf(a)===gid;
      var stMatch = st!=='' && identityNorm(a.structure)===st;
      if (sameGroup && (stMatch || a.universal===true)) recommended.push(a); else others.push(a);
    });
    recommended.sort(absEdgeSortAsc);
    var preserve = (currentValue && currentValue!=='__inherit__' && !seen[currentValue]) ? currentValue : null;
    return { recommended: recommended, others: others, preserve: preserve };
  }
  // 2A-3b: dispatcher skupin — SCHEMA >= 2 A doska nesie group_id => nova
  // logika; inak PRESNE dnesna (decor text). Hybridny zaznam bez group_id
  // v schema 2 katalogu drzi legacy vztah dekoru (zrkadlo servera —
  // ensure_edge_for_sheet). JS je LEN UX zrkadlo, autorita je server.
  function groupAbsForSheet(edges, sheetRec, catalogSchema, currentValue){
    if (catalogSchema >= 2 && groupIdOf(sheetRec) !== '')
      return groupAbsEdgesV2(edges, sheetRec, currentValue);
    return groupAbsEdges(edges, sheetRec ? sheetRec.decor : '', currentValue);
  }
  // D-36: zlozi HTML <option> zo skupin. prefixHtml = fixne volby PRED skupinami
  // (inherit/Bez ABS). Ak NIE su odporucane (prazdny dekor ALEBO ziadna zhoda) => plochy
  // zoznam bez optgroup (F4 cisty fallback). F5 zachovavacia volba ide do "Ostatne".
  function absOptionsHtml(prefixHtml, groups){
    function opt(a){ return '<option value="'+esc(a.id)+'">'+esc(a.label)+'</option>'; }
    function keep(v){ return '<option value="'+esc(v)+'">'+esc(v)+'</option>'; }
    var body;
    if (groups.recommended.length){
      var oth = groups.others.map(opt).join('') + (groups.preserve ? keep(groups.preserve) : '');
      body = '<optgroup label="Odporúčané k dekoru">'+groups.recommended.map(opt).join('')+'</optgroup>';
      if (oth) body += '<optgroup label="Ostatné">'+oth+'</optgroup>';
    } else {
      body = groups.others.map(opt).join('') + (groups.preserve ? keep(groups.preserve) : '');
    }
    return (prefixHtml||'') + body;
  }
  // D-41 C2: existuje k dekoru POUZITELNY variant danej hrubky ABS pre dielec
  // hrubky partTh? Zrkadlo Ruby pickera (sirka >= partTh+2 alebo univerzalna bez
  // sirky) — LEN boolean pre modal "chyba paska"; vyber aj tvorbu robi VZDY server.
  // Bez dekoru/hrubky sa NEvylucuje (true) — modal nesmie vyskakovat naprazdno.
  function absUsableExists(edges, decor, absTh, partTh){
    var nd = normDecor(decor);
    if (nd === '') return true;
    edges = edges || [];
    for (var i=0;i<edges.length;i++){
      var a = edges[i];
      if (normDecor(a.decor) !== nd) continue;
      if (Math.abs((parseFloat(a.thickness)||0) - absTh) > 0.01) continue;
      if (absEdgeWidthOk(a, partTh)) return true;
    }
    return false;
  }
  // Sirkovy check pasky (zdielany schema 1 aj 2): bez sirky = univerzalna sirka;
  // bez hrubky dielca sa nevylucuje; inak sirka >= hrubka+2 (presah na olep+orez).
  function absEdgeWidthOk(a, partTh){
    var w = (a.width===null || a.width===undefined) ? null : parseFloat(a.width);
    if (w === null) return true;
    if (partTh === null || partTh === undefined || !isFinite(partTh)) return true;
    return w >= partTh + 2 - 0.001;
  }
  // 2A-3b: nominalna trieda jednotka {0,8; 1; 1,2} — zrkadlo Ruby
  // EDGE_CLASS_PREFERENCE[:jednotka] (0,4 ani 1,5/2 sem NIKDY nepatria).
  function absUnitClass(th){
    var t = parseFloat(th)||0;
    return Math.abs(t-0.8)<0.01 || Math.abs(t-1.0)<0.01 || Math.abs(t-1.2)<0.01;
  }
  // 2A-3b (audit F11): zrkadlo Ruby abs_for_sheet(:jednotka) pre modal "chyba
  // paska" pri SCHEMA 2 — kandidati podla group_id dosky, vetva presnej
  // NEPRAZDNEJ struktury, potom vedomy universal:true (dve prazdne struktury
  // NIE su zhoda); nominalna trieda jednotka namiesto natvrdo 1,0; sirkovy
  // check plati v oboch vetvach. LEN boolean pre modal — vyber, tvorbu aj
  // konecne rozhodnutie robi VZDY server (create_missing_abs kontrakt bez zmeny).
  function absUsableExistsV2(edges, sheetRec, partTh){
    if (!sheetRec) return true; // neznamy material sa nevylucuje (modal nesmie vyskakovat naprazdno)
    edges = edges || [];
    var gid = groupIdOf(sheetRec);
    var st = identityNorm(sheetRec.structure);
    for (var i=0;i<edges.length;i++){
      var a = edges[i];
      if (gid==='' || groupIdOf(a) !== gid) continue;
      if (!absUnitClass(a.thickness) || !absEdgeWidthOk(a, partTh)) continue;
      if (st !== '' && identityNorm(a.structure) === st) return true;
      if (a.universal === true) return true;
    }
    return false;
  }
  // 2A-3b: dispatcher zrkadla modalu — schema VYHRADNE z payloadu (F11);
  // hybrid bez group_id = legacy dekor logika (zrkadlo servera).
  // M-C (GH #118 P2): typy, ktore sa NELEPIA (kompakt monolit / PD postforming)
  // — zrkadlo Materials.abs_default_suppression (server ma tvrdu stopku).
  function absSuppressedSheet(rec){
    if (!rec) return false;
    var t = String(rec.type || '').trim().toUpperCase();
    if (t === 'KOMPAKT') return true;
    return t === 'PD' && rec.pd_edge_subtype === 'postforming';
  }
  function absUsableForSheet(edges, sheetRec, catalogSchema, partTh){
    // V0.6 M-B1: UNI pasky nema ZO ZASADY — modal "Vytvorit pasku" sa nikdy
    // neotvara (server ma tvrdu stopku, toto je UX zrkadlo).
    if (sheetRec && sheetRec.uni === true) return true;
    // M-C: nelepitelne typy modal tiez nikdy neotvaraju.
    if (absSuppressedSheet(sheetRec)) return true;
    if (catalogSchema >= 2 && groupIdOf(sheetRec) !== '')
      return absUsableExistsV2(edges, sheetRec, partTh);
    return absUsableExists(edges, sheetRec ? sheetRec.decor : '', 1.0, partTh);
  }
  // 2A-3b: text chybajucej pasky do absModal hlasok — schema 1 presne dnesny
  // text, schema 2 nominalna trieda (hlaska s natvrdo "1,0" by klamala).
  function absMissingLabel(catalogSchema){
    return catalogSchema >= 2 ? 'jednotkovú ABS pásku (0,8–1,2 mm)' : '1,0 mm ABS pásku';
  }
  // Hrubka doskoveho materialu z katalogu (pre absUsable* check).
  function sheetThicknessOf(materialId){
    for (var i=0;i<MATERIALS.sheets.length;i++){
      if (MATERIALS.sheets[i].id===materialId) return parseFloat(MATERIALS.sheets[i].thickness);
    }
    return null;
  }
  // Volby ABS pre dropdown hrany DIELCA: fixne (podla pravidla / Bez ABS) + D-36 skupiny
  // (Odporucane k dekoru / Ostatne). 2A-3b: parameter je ID materialu dielca
  // (skupinu urcuje cely zaznam dosky — group_id/structure podla schemy),
  // currentValue = aktualna ABS hodnota tejto hrany (zachova sa aj mimo katalogu — F5).
  // D-102: inheritLabel = HOTOVY text zo servera „(podľa pravidla — 500 SM Biela 23/1 mm)".
  // Skladá ho VYHRADNE Ruby (payloads.edge_rule_options) — JS ho len ESCAPUJE a vlozi.
  // Bez textu (napr. po lokalnej zmene materialu, kym nedojde serverovy payload)
  // sa pouzije neutralne „(podľa pravidla)" — radsej ziadny udaj nez STARY udaj.
  function edgeOptionsHtml(materialId, currentValue, inheritLabel){
    var txt = (inheritLabel === null || inheritLabel === undefined || inheritLabel === '')
      ? '(podľa pravidla)' : inheritLabel;
    var prefix = '<option value="__inherit__">'+esc(txt)+'</option><option value="">Bez ABS</option>';
    return absOptionsHtml(prefix, groupAbsForSheet(MATERIALS.edges, sheetRecOf(materialId), catalogSchemaNow(), currentValue));
  }
  // Volby ABS pre dropdown hrany DOSKY: doska nema override vrstvu (fixne len Bez ABS).
  // D-102: noneLabel nesie serverovy text „Bez ABS (nelepí sa)" pri nelepitelnom materiali.
  function boardEdgeOptionsHtml(materialId, currentValue, noneLabel){
    var txt = (noneLabel === null || noneLabel === undefined || noneLabel === '') ? 'Bez ABS' : noneLabel;
    return absOptionsHtml('<option value="">'+esc(txt)+'</option>', groupAbsForSheet(MATERIALS.edges, sheetRecOf(materialId), catalogSchemaNow(), currentValue));
  }
  // D-102: popisok strany v 2D nahlade = nazov hrany + SKRATKA vyriesenej pasky
  // („Predná · 23/1"). Skratku sklada server (payloads.abs_short_text) — JS ju
  // len pripaja, aby nahlad nepotreboval novy riadok (vertikalny priestor).
  // Zdielaju ho karta dielca aj karta dosky (jeden zdroj, jedno spravanie).
  function edgeSideText(baseLabel, shortText){
    var b = (baseLabel === null || baseLabel === undefined) ? '' : String(baseLabel);
    var s = (shortText === null || shortText === undefined) ? '' : String(shortText);
    return s === '' ? b : (b === '' ? s : b + ' · ' + s);
  }
  // FIX 2: naplni/obnovi vsetky projektove + korpusove material selecty podla hrubky KONTEXTU
  // (korpus = pole 'thickness', chrbat = 'back_thickness', cela = rozsah dosky). Nekompatibilne
  // dosky disabled — OKREM korpusu (D-45: ten hrubku prevezme). Vola sa na init, pri vybere
  // korpusu aj po zmene hrubky (onField). Zachova hodnoty.
  function refreshMaterialFilters(){
    // D2: projektove selecty (proj_*) su v okne Materialy projektu — panel filtruje
    // uz len korpusove selecty podla hrubok aktualneho formulara.
    var bodyTh = numv('thickness'), backTh = numv('back_thickness');
    // D-45: korpusove dosky inej hrubky ostavaju VYBERATELNE (disabled je uz len
    // to, co server odmietne — hrubka mimo rozsahu dosky); hrubku korpusu po
    // vybere prevezme materiál a label to hovori dopredu.
    fillSheetSelectFiltered(el('cab_body'), true, rangeMatch(), undefined, undefined,
      function(s){ return s.uni === true ? '' : bodyThicknessNote(s.thickness, bodyTh); }, true);
    fillSheetSelectFiltered(el('cab_front'), true, frontMatch());
    fillSheetSelectFiltered(el('cab_front_c'), true, frontMatch()); // UI-C3: zrkadlo v zozname ciel
    fillSheetSelectFiltered(el('cab_back'), true, thMatch(backTh));
    nxComboSync(); // D-85: prekreslene <option>y -> obnov popisky comboboxov
  }
  // D-85: jeden vstupny bod pre "pripoj combobox na nove selecty + obnov existujuce".
  // Vola sa po KAZDOM renderi, ktory siaha na material/ABS selecty. Bez neho by
  // trigger ukazoval starý popis (zmena `value` ziadnu udalost nevystreli).
  function nxComboSync(root){
    if (typeof NXCombo !== 'undefined' && NXCombo) NXCombo.scan(root);
  }
  // D-85: "je pole prave obsluhovane pouzivatelom?" — fokus v nativnom poli ALEBO
  // otvoreny combobox nad nim. Guardy, ktore doteraz pozerali len na
  // document.activeElement, musia vidiet aj otvoreny popup (inak by zivy refresh
  // katalogu prestaval rozkliknuty vyber respektovat).
  function nxFieldBusy(node){
    if (!node) return false;
    if (document.activeElement === node) return true;
    return !!(typeof NXCombo !== 'undefined' && NXCombo && NXCombo.isOpen(node));
  }
  function val(id){ var e = el(id); return e ? e.value : null; }
  // V0.4.7e: numv cita cez evalDim — nahlad/svetle rozmery/filtre vidia hodnotu
  // vyrazu, nie parseFloat orezanie ('650-36' NIE JE 650).
  function numv(id){ var e = el(id); return e ? evalDim(e.value) : NaN; }
  function setVal(id, v){ var e = el(id); if (e && v !== null && v !== undefined) e.value = v; }
  // UI-B3: zapis DOPOCITANEHO udaja do informacneho stlpca. Vystupy su TEXT,
  // nie polia (zasada „výstupy nikdy nevyzerajú ako vstupy") — preto textContent
  // a nie .value. Prazdna hodnota = pomlcka, nikdy prazdne miesto.
  function setOut(id, v){
    var e = el(id); if (!e) return;
    e.textContent = (v === null || v === undefined || v === '') ? '—' : String(v);
  }
  function setNum(id, v){ var e = el(id); if (e && v !== null && v !== undefined) e.value = String(parseFloat(v)); }
  // UI-C1b: typ korpusu uz nedrzia radia (nahradili ich segmentove tlacidla
  // vkladacej karty), ale PREMENNA. Pri oznacenej skrinke je to zrkadlo JEJ typu
  // (setType v loadSelected), vo vkladani ho nastavuju tlacidla cez NXInsert —
  // jedna hodnota pre collectConstruction, defaulty aj modal „Uložiť ako šablónu".
  var cabTypeVal = 'lower';
  function getType(){ return cabTypeVal; }
  function setType(t){
    cabTypeVal = (t === 'upper') ? 'upper' : 'lower';
    if (typeof syncInsertTypeButtons === 'function') syncInsertTypeButtons();
  }

  // ===== D-80: VNUTRO A HORNE VYSTUHY (zrkadlo Ruby Construction) ==============
  // JEDINA JS autorita svetlej vysky. Pouzivaju ju VSETCI traja: zone_tree.js
  // (box zon), form.js ("Svetla vyska") aj preview.js (kreslenie vrchu) — ziadna
  // dalsia kopia vzorca sa uz nesmie rozist s Ruby.
  var NX_MIN_INTERIOR_H = 20.0; // Construction::MIN_INTERIOR_H (rezerva vnutra pod vystuhami)
  var NX_RAIL_MIN       = 20.0; // najmensia hlbka (flat) / vyska (upright) vystuhy
  var NX_BACK_TH_DFLT   = 3.0;  // Construction::BACK_THICKNESS_DEFAULT

  function nxNum(v, dflt){ var x = parseFloat(v); return isNaN(x) ? (dflt || 0) : x; }

  // Konstrukcna hlbka tela (D-37): overlay chrbat zabera zadnych bt z celkovej hlbky.
  function nxCarcassDepth(c){
    var bt = nxNum(c.back_thickness, NX_BACK_TH_DFLT);
    if (!(bt > 0)) bt = NX_BACK_TH_DFLT;
    var d = nxNum(c.depth);
    return (c.back_mode === 'overlay') ? (d - bt) : d;
  }

  // Geometria vystuh: odsadenie od vrchu + kolko zaberu na vysku. Clampy su
  // zhodne s Ruby Construction.rail_geometry (vratane rezervy MIN_INTERIOR_H).
  function nxRailGeom(c){
    var h = nxNum(c.height), t = nxNum(c.thickness), s = nxNum(c.floor_height);
    var head = Math.max(h - (s + t) - NX_MIN_INTERIOR_H, 0);
    var wantDepth = nxNum(c.rail_depth), wantOff = nxNum(c.rails_top_offset);
    var upright = (c.rails_orientation === 'upright');
    var limit = upright ? head : (nxCarcassDepth(c) / 2 - 10);
    var dep = Math.min(wantDepth, limit);
    if (dep < NX_RAIL_MIN) dep = NX_RAIL_MIN;
    var occupy = upright ? dep : t;
    var maxOff = Math.max(head - occupy, 0);
    var off = Math.min(Math.max(wantOff, 0), maxOff);
    return { offset:off, wantedOffset:wantOff, depth:dep, wantedDepth:wantDepth,
             occupy:occupy, upright:upright, zTop:(h - off), zBottom:(h - off - occupy) };
  }

  // Svetle vnutro korpusu: { zLo, zHi, availH }. two_rails konci na SPODNEJ hrane
  // vystuh (nie na h - t) — inak by zony/police siahali do priestoru varnej dosky.
  function nxInteriorZ(c){
    var h = nxNum(c.height), t = nxNum(c.thickness), s = nxNum(c.floor_height);
    var zLo = s + t, zHi;
    if (c.top_mode === 'none') zHi = h;
    else if (c.top_mode === 'two_rails') zHi = nxRailGeom(c).zBottom;
    else zHi = h - t;
    return { zLo:zLo, zHi:zHi, availH:(zHi - zLo) };
  }

  // DOM most: precita konstrukcne polia formulara (s rovnakymi fallbackmi ako
  // nahlad). `over` = bodove prepisanie hodnot volajucim (napr. uz precitana vyska).
  function currentCarcass(over){
    var c = {
      height: numv('height') || 720, thickness: numv('thickness') || 18,
      floor_height: (getType() === 'upper') ? 0 : (numv('floor_height') || 0),
      depth: numv('depth') || 0,
      back_mode: val('back_mode'), back_thickness: numv('back_thickness') || NX_BACK_TH_DFLT,
      top_mode: val('top_mode'), rails_orientation: val('rails_orientation'),
      rails_top_offset: numv('rails_top_offset') || 0, rail_depth: numv('rail_depth') || 100
    };
    if (over){ for (var k in over){ if (Object.prototype.hasOwnProperty.call(over, k)) c[k] = over[k]; } }
    return c;
  }

  // JEDINY zoznam konstrukcnych poli panela (predtym duplikovany na 6 miestach:
  // collectConstruction, setDefaults, materializeInsertCard, NX.loadSelected + 2x Ruby whitelist).
  // Nove pole (napr. kovanie) = pridat TU + <input>/<select> v HTML + kluc v Ruby PARAM_KEYS.
  // kind: 'num' (setNum) / 'sel' (setVal); dflt = fallback pri prazdnej/falsy hodnote zdroja.
  var CONSTRUCTION_FIELDS = [
    { id:'width', kind:'num' }, { id:'height', kind:'num' }, { id:'depth', kind:'num' },
    { id:'thickness', kind:'num' }, { id:'floor_height', kind:'num' },
    { id:'bottom_mode', kind:'sel' }, { id:'top_mode', kind:'sel' },
    { id:'back_mode', kind:'sel' }, { id:'back_thickness', kind:'num', dflt:3 },
    { id:'plinth_mode', kind:'sel' }, { id:'plinth_recess', kind:'num' },
    { id:'rails_orientation', kind:'sel' }, { id:'rails_top_offset', kind:'num' }, { id:'rail_depth', kind:'num' }
  ];
  // Zapise hodnoty zdroja (defaulty / sablona / oznaceny korpus) do formulara.
  // Prazdne hodnoty ostavaju nedotknute (ako povodne setNum/setVal), dflt zrkadli povodne "|| 3".
  function writeConstruction(src){
    src = src || {};
    CONSTRUCTION_FIELDS.forEach(function(f){
      var v = src[f.id];
      if (f.dflt !== undefined && !v) v = f.dflt;
      if (f.kind === 'num') setNum(f.id, v); else setVal(f.id, v);
    });
  }

  // D-100: ocistenie nazvu skrinky PRED odoslanim (zrkadlo Ruby
  // CabinetBuilder.sanitize_name — trim, jedna medzera, dlzka NAME_MAX_LEN).
  // JS je len UX zrkadlo: co je "automaticky nazov" a co sa naozaj ulozi
  // rozhoduje VYHRADNE server (rovnaky kontrakt ako absUsableExists).
  var CAB_NAME_MAX = 80;
  function cabNameValue(raw){
    return String(raw == null ? '' : raw).replace(/\s+/g, ' ').trim().slice(0, CAB_NAME_MAX).trim();
  }

  // D-36 Node testy (tests/js/test_abs_groups.js) — v CEF je module undefined, vetva
  // sa preskoci. Exportuju sa len CISTE grouping funkcie (bez DOM/MATERIALS zavislosti).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { groupAbsEdges: groupAbsEdges, absOptionsHtml: absOptionsHtml, normDecor: normDecor,
      absUsableExists: absUsableExists,
      // 2A-3b (tests/js/test_abs_mirror.js) — ciste funkcie zrkadla SCHEMA 2
      // catalogSchemaNow: GH #91 P2 — modal callbacky posielaju client schemu
      // (server ensure inak drzi legacy default a v SCHEMA 2 odmietne tvorbu).
      identityNorm: identityNorm, catalogSchemaOf: catalogSchemaOf,
      // (testovaci export; runtime callbacky citaju PRIAMO global konstantu —
      // GH #91 kolo 3: window.NX stavia bridge.js a tuto vlastnost nema)
      catalogSchemaNow: catalogSchemaNow, PANEL_CLIENT_SCHEMA: PANEL_CLIENT_SCHEMA,
      groupAbsEdgesV2: groupAbsEdgesV2, groupAbsForSheet: groupAbsForSheet,
      absUsableExistsV2: absUsableExistsV2, absUsableForSheet: absUsableForSheet,
      absMissingLabel: absMissingLabel, absUnitClass: absUnitClass,
      // D-102 (tests/js/test_d102_pravidlo.js) — serverove texty volieb a popiskov
      edgeOptionsHtml: edgeOptionsHtml, boardEdgeOptionsHtml: boardEdgeOptionsHtml,
      edgeSideText: edgeSideText,
      // D-45 (tests/js/test_thickness_labels.js) — ciste funkcie hrubkovych filtrov/labelov
      mmLabel: mmLabel, bodyThicknessNote: bodyThicknessNote, frontMatch: frontMatch,
      rangeMatch: rangeMatch, thMatch: thMatch, TH_RANGE: TH_RANGE,
      // D-80 (tests/js/test_interior_height.js) — zrkadlo Construction: svetla
      // vyska a geometria vystuh. currentCarcass sa NEexportuje (cita DOM).
      nxInteriorZ: nxInteriorZ, nxRailGeom: nxRailGeom, nxCarcassDepth: nxCarcassDepth,
      NX_MIN_INTERIOR_H: NX_MIN_INTERIOR_H,
      // D-90 (tests/js/test_d90_profil_ui.js) — ciste funkcie volby profilu;
      // register sa testom odovzdava parametrom (global plni az NX.init z Ruby).
      frontProfileRec: frontProfileRec, frontProfileReduction: frontProfileReduction,
      // D-96 / UI-C3 (tests/js/test_uic3_cela.js) — sekcia „Úchytky" nahradila
      // cyklenie ikonou v riadku, preto s nou zanikol aj `frontProfileNext`.
      frontProfileOptionList: frontProfileOptionList,
      collectFrontHwBuy: collectFrontHwBuy,
      frontProfileScopeItems: frontProfileScopeItems,
      frontProfileCommon: frontProfileCommon,
      frontProfileStateText: frontProfileStateText,
      // D-100 (tests/js/test_d100_nazvy.js) — zrkadlo ocistenia nazvu skrinky
      cabNameValue: cabNameValue, CAB_NAME_MAX: CAB_NAME_MAX,
      // UI-B3 (tests/js/test_uib3_korpus.js) — texty informacneho stlpca a typ badge
      nxCabInfo: nxCabInfo, NX_TYPE_LABEL: NX_TYPE_LABEL,
      // D-85 (tests/js/test_ui03_combobox.js) — prevod katalogovej farby [r,g,b]
      // na hex pre stvorcek comboboxu (nxComboColorOf uz cita globalny MATERIALS)
      nxRgbHex: nxRgbHex };
  }

