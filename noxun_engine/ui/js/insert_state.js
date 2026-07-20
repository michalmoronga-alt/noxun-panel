  // ===================== D-32/D-33/D-39: STAV VKLADACEJ KARTY =====================
  // Cisty stavovy modul BEZ DOM — jediny zdroj pravdy vkladacej karty (audit B1:
  // DOM nie je zdroj stavu; loadSelected ho prepisuje hodnotami oznacenej skrinky).
  // Drzi: typ (dolna/horna), zvolenu sablonu, zamky poli (D-39) a draft materialov
  // zo sablony (D-33/F6). DOM sa MATERIALIZUJE z tohto stavu pri kazdom skutocnom
  // prechode do rezimu vkladania (audit B2 — sleduje lastMode; insert->insert sync
  // neresetuje, rozpisane upravy v karte preziju).
  // Testovatelne v Node: tests/js/test_insert_state.js (vzor expr.js/usage.js).
  var NXInsert = (function(){
    'use strict';
    var LOCK_FIELDS = ['width', 'height', 'depth', 'thickness', 'floor_height'];
    var MATERIAL_KEYS = ['material_id', 'front_material_id', 'back_material_id'];
    var state = {
      type: 'lower',
      template: '',   // nazov zvolenej sablony ('' = defaulty typu)
      locks: {},      // { width: { locked:true, value:950 }, ... } — chybajuci kluc = odomknute
      materials: { material_id: null, front_material_id: null, back_material_id: null },
      lastMode: null  // posledny UI rezim (insert|cab|part|board); null = pred prvym initom
    };

    function hasOwn(o, k){ return !!o && Object.prototype.hasOwnProperty.call(o, k); }
    function num(v){
      var n = parseFloat(v);
      return (isNaN(n) || !isFinite(n)) ? null : n;
    }

    // --- prechodovy automat rezimov (audit B2) -------------------------------
    // Reset karty patri LEN skutocnemu prechodu cab|part|board|null -> insert.
    function needsReset(prevMode, nextMode){
      return nextMode === 'insert' && prevMode !== 'insert';
    }
    // Zapamata rezim a vrati, ci tento prechod vyzaduje reset karty.
    function trackMode(mode){
      var reset = needsReset(state.lastMode, mode);
      state.lastMode = mode;
      return reset;
    }

    // --- zamky poli (D-39) ---------------------------------------------------
    function lockableField(f){ return LOCK_FIELDS.indexOf(f) >= 0; }
    function isLocked(f){ return !!(state.locks[f] && state.locks[f].locked); }
    function setLock(f, value){
      if (!lockableField(f)) return false;
      var v = num(value);
      if (v === null) return false;
      state.locks[f] = { locked: true, value: v };
      return true;
    }
    function clearLock(f){ delete state.locks[f]; }
    // Edit uz zamknuteho pola aktualizuje hodnotu zamku (zamok = "prezije sablonu
    // a reset", nie "read-only"); na odomknutom poli nic nerobi.
    function updateLockValue(f, value){
      if (!isLocked(f)) return false;
      var v = num(value);
      if (v === null) return false;
      state.locks[f].value = v;
      return true;
    }
    // Serializacia pre Ruby (audit B5: zamky ziju v pamati Panel modulu):
    // plochy tvar { width: 950 } LEN zamknutych poli.
    function lockedFields(){
      return Object.keys(state.locks);
    }
    function locksFlat(){
      var out = {};
      LOCK_FIELDS.forEach(function(f){ if (isLocked(f)) out[f] = state.locks[f].value; });
      return out;
    }
    // Obnova z Ruby (push_init) — neplatne/nezname kluce sa zahodia.
    function setLocksFlat(map){
      state.locks = {};
      if (!map) return;
      LOCK_FIELDS.forEach(function(f){
        if (!hasOwn(map, f)) return;
        var v = num(map[f]);
        if (v !== null) state.locks[f] = { locked: true, value: v };
      });
    }

    // --- zdroj hodnot karty (D-32/D-33, poradie audit F7) --------------------
    // Sablona NAD defaultmi typu = PLNY obraz karty (ziadne zvysky predosleho
    // vyberu). Vysledok je VZDY novy objekt — sablona sa NIKDY nemutuje (N11);
    // vnorene struktury (fronts/zone_tree) sa nesu referenciou a citaju read-only
    // (renderFronts iba cita, zony idu cez sanitizeTree = novy strom).
    function composeSource(defaults, templateConfig){
      var out = {};
      var k;
      for (k in (defaults || {})){ if (hasOwn(defaults, k)) out[k] = defaults[k]; }
      for (k in (templateConfig || {})){ if (hasOwn(templateConfig, k)) out[k] = templateConfig[k]; }
      return out;
    }
    // Krok 2 poradia F7: zamknute hodnoty prebiju zdroj (sablonu aj defaulty).
    // Mutuje ODOVZDANY objekt (volat na cerstvom compose vysledku, nie na sablone).
    function applyLocks(values){
      LOCK_FIELDS.forEach(function(f){ if (isLocked(f)) values[f] = state.locks[f].value; });
      return values;
    }
    // Draft materialov zo zdroja (D-33/F6): sablonove material_id/front/back;
    // prazdne/chybajuce = null (= dedit z projektu, ako doteraz).
    function materialsOf(src){
      var out = {};
      MATERIAL_KEYS.forEach(function(k){
        var v = src ? src[k] : null;
        out[k] = (v === undefined || v === null || String(v).trim() === '') ? null : String(v);
      });
      return out;
    }
    function setMaterials(map){ state.materials = materialsOf(map || {}); }

    return {
      state: state,
      LOCK_FIELDS: LOCK_FIELDS,
      MATERIAL_KEYS: MATERIAL_KEYS,
      needsReset: needsReset,
      trackMode: trackMode,
      lockableField: lockableField,
      isLocked: isLocked,
      setLock: setLock,
      clearLock: clearLock,
      updateLockValue: updateLockValue,
      locksFlat: locksFlat,
      lockedFields: lockedFields,
      setLocksFlat: setLocksFlat,
      composeSource: composeSource,
      applyLocks: applyLocks,
      materialsOf: materialsOf,
      setMaterials: setMaterials
    };
  })();

  // Node testy (tests/js/test_insert_state.js) — v CEF je module undefined.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = NXInsert;
  }
