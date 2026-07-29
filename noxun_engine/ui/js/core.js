
  var DEFAULTS = { lower: {}, upper: {} };
  var TEMPLATES = [];
  var activeZoneId = null;
  var cabEditsInFlight = false; // D-07 Codex B2: apply odoslany, echo este nedoslo
  var currentCabTab = 'korpus'; // D-08: aktivny rezimovy tab (korpus|zony|cela) — drzi sa cez zmeny vyberu
  var tplNameSuggestion = '';   // D-14: navrh nazvu sablony z Ruby (cabinet_payload)
  var selectedCabId = null;
  var currentZoneTree = null;   // strukturny strom zon (nový vklad aj oznaceny)
  var previewMode = 'zones';
  var applyTimer = null;
  var frontItems = null;        // rozlozene cela z backendu
  var PALETTE = ['#46beff','#6eff96','#ffaf50','#dc78ff','#ffeb5a'];
  // V0.3 materialy + ABS
  var MATERIALS = { sheets: [], edges: [] }; // katalog z backendu
  var partCard = null;                        // aktualna karta dielca (null = ziadny dielec)
  // D3: mapa front_id -> texty kovania ("4× záves", "NL 500") pre badge v riadkoch ciel.
  var HW_FRONT_BADGES = {};
  function buildFrontHwBadges(hardware){
    HW_FRONT_BADGES = {};
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
  function frontHwBadge(fid){
    var arr = HW_FRONT_BADGES[fid];
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
  // FIX 2: hrubkove predikaty pre filter doskovych materialov (tolerancia 0,05 mm).
  // Prazdny/neplatny cielovy rozmer -> nefiltruj (radsej vsetko nez nic).
  function thMatch(target){
    var t = parseFloat(target);
    if (isNaN(t)) return function(){ return true; };
    return function(s){ return Math.abs(parseFloat(s.thickness) - t) < 0.05; };
  }
  // D-45: doska je pouzitelna ako korpus/celo, ked je jej hrubka v rozsahu dosky —
  // konkretnu hrubku prevezme dielec z materialu (server), nie naopak.
  function rangeMatch(){
    return function(s){ var t = parseFloat(s.thickness); return !isNaN(t) && t >= TH_RANGE[0]-0.001 && t <= TH_RANGE[1]+0.001; };
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
  function fillSheetSelectFiltered(sel, includeInherit, matchFn, keepValue, inheritLabel, noteFn){
    if (!sel) return;
    var cur = (keepValue !== undefined && keepValue !== null) ? keepValue : sel.value;
    var html = includeInherit ? '<option value="">'+esc(inheritLabel || '(dediť z projektu)')+'</option>' : '';
    MATERIALS.sheets.forEach(function(s){
      var ok = matchFn ? matchFn(s) : true;
      var keep = ok || (s.id === cur);
      var note = noteFn ? noteFn(s) : (ok ? '' : ' · (nekompatibilné)');
      html += '<option value="'+esc(s.id)+'"'+(keep?'':' disabled')+'>'+esc(s.label)+esc(note)+'</option>';
    });
    sel.innerHTML = html;
    sel.value = cur;
  }
  // D-36: normalizacia dekoru pre zoskupenie ABS — orez whitespace (legacy/prazdny),
  // NIE lowercase (B2: presna case-sensitive zhoda ako drzi katalog). nil/prazdny => ''.
  function normDecor(d){ return String(d==null?'':d).trim(); }
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
    recommended.sort(function(x,y){
      var t = (parseFloat(x.thickness)||0)-(parseFloat(y.thickness)||0);
      if (t) return t;
      var xw = (x.width===null || x.width===undefined) ? null : parseFloat(x.width);
      var yw = (y.width===null || y.width===undefined) ? null : parseFloat(y.width);
      if (xw===null && yw===null) return 0;
      if (xw===null) return 1;
      if (yw===null) return -1;
      return xw-yw;
    });
    // F5: '' (Bez ABS) a '__inherit__' su fixne volby, nie ABS id — tie nezachovavaj
    var preserve = (currentValue && currentValue!=='__inherit__' && !seen[currentValue]) ? currentValue : null;
    return { recommended: recommended, others: others, preserve: preserve };
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
      var w = (a.width===null || a.width===undefined) ? null : parseFloat(a.width);
      if (w === null) return true;
      if (partTh === null || partTh === undefined || !isFinite(partTh)) return true;
      if (w >= partTh + 2 - 0.001) return true;
    }
    return false;
  }
  // Hrubka doskoveho materialu z katalogu (pre absUsableExists check).
  function sheetThicknessOf(materialId){
    for (var i=0;i<MATERIALS.sheets.length;i++){
      if (MATERIALS.sheets[i].id===materialId) return parseFloat(MATERIALS.sheets[i].thickness);
    }
    return null;
  }
  // Volby ABS pre dropdown hrany DIELCA: fixne (podla pravidla / Bez ABS) + D-36 skupiny
  // (Odporucane k dekoru / Ostatne). decor = resolved dekor materialu dielca,
  // currentValue = aktualna ABS hodnota tejto hrany (zachova sa aj mimo katalogu — F5).
  function edgeOptionsHtml(decor, currentValue){
    var prefix = '<option value="__inherit__">(podľa pravidla)</option><option value="">Bez ABS</option>';
    return absOptionsHtml(prefix, groupAbsEdges(MATERIALS.edges, decor, currentValue));
  }
  // Volby ABS pre dropdown hrany DOSKY: doska nema override vrstvu (fixne len Bez ABS).
  function boardEdgeOptionsHtml(decor, currentValue){
    return absOptionsHtml('<option value="">Bez ABS</option>', groupAbsEdges(MATERIALS.edges, decor, currentValue));
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
      function(s){ return bodyThicknessNote(s.thickness, bodyTh); });
    fillSheetSelectFiltered(el('cab_front'), true, frontMatch());
    fillSheetSelectFiltered(el('cab_back'), true, thMatch(backTh));
  }
  function val(id){ var e = el(id); return e ? e.value : null; }
  // V0.4.7e: numv cita cez evalDim — nahlad/svetle rozmery/filtre vidia hodnotu
  // vyrazu, nie parseFloat orezanie ('650-36' NIE JE 650).
  function numv(id){ var e = el(id); return e ? evalDim(e.value) : NaN; }
  function setVal(id, v){ var e = el(id); if (e && v !== null && v !== undefined) e.value = v; }
  function setNum(id, v){ var e = el(id); if (e && v !== null && v !== undefined) e.value = String(parseFloat(v)); }
  function getType(){ var r = document.querySelector('input[name=ctype]:checked'); return r ? r.value : 'lower'; }
  function setType(t){ var r = document.querySelector('input[name=ctype][value="' + t + '"]'); if (r) r.checked = true; }

  // JEDINY zoznam konstrukcnych poli panela (predtym duplikovany na 6 miestach:
  // collectConstruction, setDefaults, onTemplateChange, NX.loadSelected + 2x Ruby whitelist).
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

  // D-36 Node testy (tests/js/test_abs_groups.js) — v CEF je module undefined, vetva
  // sa preskoci. Exportuju sa len CISTE grouping funkcie (bez DOM/MATERIALS zavislosti).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { groupAbsEdges: groupAbsEdges, absOptionsHtml: absOptionsHtml, normDecor: normDecor,
      absUsableExists: absUsableExists,
      // D-45 (tests/js/test_thickness_labels.js) — ciste funkcie hrubkovych filtrov/labelov
      mmLabel: mmLabel, bodyThicknessNote: bodyThicknessNote, frontMatch: frontMatch,
      rangeMatch: rangeMatch, thMatch: thMatch, TH_RANGE: TH_RANGE };
  }

