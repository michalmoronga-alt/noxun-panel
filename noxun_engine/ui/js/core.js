
  var DEFAULTS = { lower: {}, upper: {} };
  var TEMPLATES = [];
  var activeZoneId = null;
  var cabEditsInFlight = false; // D-07 Codex B2: apply odoslany, echo este nedoslo
  var currentCabTab = 'korpus'; // D-08: aktivny rezimovy tab (korpus|zony|cela) — drzi sa cez zmeny vyberu
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

  // FIX 2: hrubkove predikaty pre filter doskovych materialov (tolerancia 0,05 mm).
  // Prazdny/neplatny cielovy rozmer -> nefiltruj (radsej vsetko nez nic).
  function thMatch(target){
    var t = parseFloat(target);
    if (isNaN(t)) return function(){ return true; };
    return function(s){ return Math.abs(parseFloat(s.thickness) - t) < 0.05; };
  }
  // Cela: standardne dosky 18 alebo 19 mm (front hrubka; pozri Fronts::FRONT_THICKNESS = 19).
  function frontMatch(){
    return function(s){ var t = parseFloat(s.thickness); return Math.abs(t-18)<0.05 || Math.abs(t-19)<0.05; };
  }
  // FIX 2: naplni <select> doskami, ale hrubkovo NEKOMPATIBILNE su disabled + oznacene "✕".
  // Aktualne vybranu (aj legacy nesuladnu) dosku nechaj vyberatelnu, nech ju vie zobrazit. Pri
  // prazdnom vysledku ostanu vsetky viditelne (disabled) — pouzivatel vidi katalog. Zachova hodnotu.
  function fillSheetSelectFiltered(sel, includeInherit, matchFn, keepValue, inheritLabel){
    if (!sel) return;
    var cur = (keepValue !== undefined && keepValue !== null) ? keepValue : sel.value;
    var html = includeInherit ? '<option value="">'+esc(inheritLabel || '(dediť z projektu)')+'</option>' : '';
    MATERIALS.sheets.forEach(function(s){
      var ok = matchFn ? matchFn(s) : true;
      var keep = ok || (s.id === cur);
      html += '<option value="'+esc(s.id)+'"'+(keep?'':' disabled')+'>'+esc(s.label)+(ok?'':' · ✕')+'</option>';
    });
    sel.innerHTML = html;
    sel.value = cur;
  }
  // Volby ABS pre dropdown hrany: podla pravidla / bez ABS / konkretne varianty.
  function edgeOptionsHtml(){
    var html = '<option value="__inherit__">(podľa pravidla)</option><option value="">Bez ABS</option>';
    MATERIALS.edges.forEach(function(a){ html += '<option value="'+esc(a.id)+'">'+esc(a.label)+'</option>'; });
    return html;
  }
  // FIX 2: naplni/obnovi vsetky projektove + korpusove material selecty podla hrubky KONTEXTU
  // (korpus = pole 'thickness', chrbat = 'back_thickness', cela = 18/19). Nekompatibilne dosky
  // disabled. Vola sa na init, pri vybere korpusu aj po zmene hrubky (onField). Zachova hodnoty.
  function refreshMaterialFilters(){
    // D2: projektove selecty (proj_*) su v okne Materialy projektu — panel filtruje
    // uz len korpusove selecty podla hrubok aktualneho formulara.
    var bodyTh = numv('thickness'), backTh = numv('back_thickness');
    fillSheetSelectFiltered(el('cab_body'), true, thMatch(bodyTh));
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

