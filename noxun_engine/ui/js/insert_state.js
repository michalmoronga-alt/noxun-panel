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
    // UI-C1b: doska ma VLASTNE kluce zamkov (`length`/`width`) a VLASTNE
    // ulozisko. Zamerne ziadne mapovanie na korpusove width/height (Codex FIX
    // 12): su to ine veliciny a Ruby o doskovych zamkoch NEVIE — server cita
    // vyhradne korpusovy whitelist (Panel::INSERT_LOCK_FIELDS), takze doskovy
    // zamok drzi hodnotu LEN v UI pri prepnuti sablony (presne ako korpusovy
    // pred odoslanim). Do `locksFlat()` (kanal do Ruby) sa preto NIKDY nedostane.
    var BOARD_LOCK_FIELDS = ['length', 'width'];
    var MATERIAL_KEYS = ['material_id', 'front_material_id', 'back_material_id'];
    // H2 (D-76): kovanie zo sablony — mapovanie setov + zmrazene definicie.
    var HARDWARE_KEYS = ['hardware_sets', 'hardware_set_defs'];
    // UI-C1b: typ vkladaneho objektu = JEDNA volba z troch segmentovych
    // tlacidiel (Dolna · Horna · Doska). Nahradila dvojicu radiov kind+ctype;
    // stav je tu, nie v DOM (kostra panela sa neprekresluje).
    var INSERT_TYPES = ['lower', 'upper', 'board'];
    var state = {
      type: 'lower',  // typ KORPUSU (lower|upper) — drzi sa aj kym je zvolena Doska
      kind: 'cabinet',// co sa vklada: 'cabinet' | 'board'
      template: '',   // nazov zvolenej KORPUSOVEJ sablony ('' = defaulty typu)
      boardTemplate: '', // nazov zvolenej DOSKOVEJ sablony ('' = predvolene rozmery karty)
      locks: {},      // { width: { locked:true, value:950 }, ... } — chybajuci kluc = odomknute
      boardLocks: {}, // to iste pre dosku (kluce length/width) — NIKDY do Ruby
      materials: { material_id: null, front_material_id: null, back_material_id: null },
      hardware: { hardware_sets: null, hardware_set_defs: null }, // H2 (D-76)
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

    // --- typ vkladaneho objektu (UI-C1b) -------------------------------------
    // Jedna hodnota pre segmentove tlacidla: 'lower' | 'upper' | 'board'.
    function insertType(){ return state.kind === 'board' ? 'board' : state.type; }
    // Prepnutie typu. Vracia true = stav sa naozaj zmenil (volajuci prekresli).
    // Zmena TYPU KORPUSU zahadzuje vyber korpusovej sablony (ponuka je typovo
    // filtrovana — D-32); prepnutie Korpus<->Doska vybery NEZAHADZUJE, kazdy
    // druh si drzi svoj (navrat na Dolnu ukaze presne to, co bolo).
    function setInsertType(t){
      var next = (INSERT_TYPES.indexOf(t) >= 0) ? t : 'lower';
      if (next === insertType()) return false;
      if (next === 'board'){
        state.kind = 'board';
        return true;
      }
      var typeChanged = (state.type !== next);
      state.kind = 'cabinet';
      state.type = next;
      if (typeChanged) state.template = '';
      return true;
    }
    // Nazov sablony podla druhu — jedno miesto, aby sa dva sklady nemiesali.
    function templateName(kind){ return kind === 'board' ? state.boardTemplate : state.template; }
    function setTemplateName(kind, name){
      var n = (name === undefined || name === null) ? '' : String(name);
      if (kind === 'board') state.boardTemplate = n; else state.template = n;
    }
    // Identita zvolenej sablony do insert payloadu (UI-C1a kontrakt) —
    // null = vklada sa bez sablony a peciatka sa neposiela.
    function templateRef(){
      var kind = state.kind === 'board' ? 'board' : 'cabinet';
      var name = templateName(kind);
      return name ? { kind: kind, name: name } : null;
    }

    // --- zamky poli (D-39) ---------------------------------------------------
    // Korpus a doska maju VLASTNE whitelisty aj vlastne ulozisko (`scope`);
    // meno 'width' je v oboch, ale znamena inu velicinu.
    function fieldsOf(scope){ return scope === 'board' ? BOARD_LOCK_FIELDS : LOCK_FIELDS; }
    function bagOf(scope){ return scope === 'board' ? state.boardLocks : state.locks; }
    function lockableField(f, scope){ return fieldsOf(scope).indexOf(f) >= 0; }
    function isLocked(f, scope){
      var b = bagOf(scope);
      return !!(b[f] && b[f].locked);
    }
    function setLock(f, value, scope){
      if (!lockableField(f, scope)) return false;
      var v = num(value);
      if (v === null) return false;
      bagOf(scope)[f] = { locked: true, value: v };
      return true;
    }
    function clearLock(f, scope){ delete bagOf(scope)[f]; }
    // Edit uz zamknuteho pola aktualizuje hodnotu zamku (zamok = "prezije sablonu
    // a reset", nie "read-only"); na odomknutom poli nic nerobi.
    function updateLockValue(f, value, scope){
      if (!isLocked(f, scope)) return false;
      var v = num(value);
      if (v === null) return false;
      bagOf(scope)[f].value = v;
      return true;
    }
    // Serializacia pre Ruby (audit B5: zamky ziju v pamati Panel modulu):
    // plochy tvar { width: 950 } LEN zamknutych poli. UI-C1b: `scope` je LEN
    // pre UI (doskove zamky do Ruby nikdy nejdu — server ich nepozna).
    function lockedFields(scope){
      return Object.keys(bagOf(scope));
    }
    function locksFlat(scope){
      var out = {};
      fieldsOf(scope).forEach(function(f){ if (isLocked(f, scope)) out[f] = bagOf(scope)[f].value; });
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
    function applyLocks(values, scope){
      fieldsOf(scope).forEach(function(f){ if (isLocked(f, scope)) values[f] = bagOf(scope)[f].value; });
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

    // --- H2 (D-76): kovanie zo sablony --------------------------------------
    // Stav je LEN prenasac do insert payloadu — autorita je server (normalizuje
    // mapovanie s allow_owner:false a zmrazi definicie v operacii vlozenia).
    // Sablona sa NIKDY nemutuje (N11): mapa sa kopiruje, hodnoty sa len citaju.
    // Chybajuci/prazdny kluc = null, takze zrusenie vyberu sablony stav VYCISTI;
    // definicie bez mapovania nemaju co zmrazit -> tiez null.
    function plainMap(v){
      if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
      var out = {}, any = false, k;
      for (k in v){
        if (!Object.prototype.hasOwnProperty.call(v, k)) continue;
        out[k] = v[k];
        any = true;
      }
      return any ? out : null;
    }
    function hardwareOf(src){
      var out = { hardware_sets: null, hardware_set_defs: null };
      HARDWARE_KEYS.forEach(function(k){ out[k] = plainMap(src ? src[k] : null); });
      if (!out.hardware_sets) out.hardware_set_defs = null;
      return out;
    }
    function setHardware(src){ state.hardware = hardwareOf(src || {}); }

    // --- UI-C1a: druh sablony (identita je dvojica kind+name) ----------------
    // Zaznam zo servera nesie `kind` ('cabinet' | 'board'). Zaznam BEZ neho je
    // legacy korpusova sablona; 'board' sa da odvodit este z redundantneho
    // `config.type` (to isté poistne pole, ktore chrani starsieho klienta).
    // ZRKADLO Ruby kind_of_record (Codex #174 P2): EXPLICITNY kind sa NIKDY
    // nepreklasifikuje — neznamy druh z novsej verzie prejde filtrami ako
    // „ani cabinet, ani board", takze sa nikde neponukne.
    function templateKind(tp){
      var k = tp && tp.kind;
      if (typeof k === 'string' && k !== '') return k;
      return (tp && tp.config && tp.config.type === 'board') ? 'board' : 'cabinet';
    }
    function templatesOfKind(list, kind){
      var want = (kind === 'board') ? 'board' : 'cabinet';
      return (list || []).filter(function(tp){ return templateKind(tp) === want; });
    }
    // Typ korpusovej sablony (legacy zaznam bez `type` je dolna skrinka).
    function templateType(tp){
      var t = tp && tp.config && tp.config.type;
      return (t === 'upper') ? 'upper' : 'lower';
    }
    // UI-C1b: ponuka pre ZVOLENY typ vkladania. 'board' = doskove sablony,
    // 'lower'/'upper' = korpusove sablony toho typu.
    function templatesForType(list, type){
      if (type === 'board') return templatesOfKind(list, 'board');
      var want = (type === 'upper') ? 'upper' : 'lower';
      return templatesOfKind(list, 'cabinet').filter(function(tp){ return templateType(tp) === want; });
    }
    // Poradove cislo posledneho pouzitia (UI-C1a: `used_seq` z template_usage.json;
    // chybajuce/neplatne = nikdy nepouzita). Je to MONOTONNE POCITADLO, nie cas.
    function usedSeq(tp){
      var v = tp ? tp.used_seq : null;
      if (v === undefined || v === null) return null;
      var n = parseFloat(v);
      return (isNaN(n) || !isFinite(n)) ? null : n;
    }
    // N16 „nedavne prve": max `max` naposledy pouzitych, od najnovsieho.
    // Tie-break je PORADIE V KNIZNICI (stabilne triedenie) — dve rovnake cisla
    // by inak medzi prekresleniami preskakovali.
    function recentTemplates(list, max){
      var n = (max === undefined || max === null) ? 3 : max;
      var idx = 0;
      return (list || []).filter(function(tp){ return usedSeq(tp) !== null; })
        .map(function(tp){ return { tp: tp, i: idx++ }; })
        .sort(function(a, b){
          var d = usedSeq(b.tp) - usedSeq(a.tp);
          return d !== 0 ? d : (a.i - b.i);
        })
        .slice(0, n)
        .map(function(x){ return x.tp; });
    }
    // Dve skupiny dlazdic sektora Sablona: „Naposledy pouzite" (moze byt prazdna
    // — potom sa hlavicka vobec nekresli) + „Vsetky sablony" (v poradi kniznice).
    function templateGroups(list, type, maxRecent){
      var all = templatesForType(list, type);
      return { recent: recentTemplates(all, maxRecent), all: all };
    }
    // Zaznam podla identity (kind, name) — rovnomenna sablona ineho druhu NIE JE tato.
    function findTemplate(list, kind, name){
      if (!name) return null;
      var want = (kind === 'board') ? 'board' : 'cabinet';
      var found = null;
      (list || []).forEach(function(tp){
        if (found || !tp || tp.name !== name) return;
        if (templateKind(tp) === want) found = tp;
      });
      return found;
    }
    // Kluce do insert payloadu — prazdne kluce sa NEposielaju.
    function hardwarePayload(){
      var hw = state.hardware || {};
      var out = {};
      HARDWARE_KEYS.forEach(function(k){ if (hw[k]) out[k] = hw[k]; });
      return out;
    }

    return {
      state: state,
      LOCK_FIELDS: LOCK_FIELDS,
      BOARD_LOCK_FIELDS: BOARD_LOCK_FIELDS,
      INSERT_TYPES: INSERT_TYPES,
      MATERIAL_KEYS: MATERIAL_KEYS,
      HARDWARE_KEYS: HARDWARE_KEYS,
      insertType: insertType,
      setInsertType: setInsertType,
      templateName: templateName,
      setTemplateName: setTemplateName,
      templateRef: templateRef,
      templateType: templateType,
      templatesForType: templatesForType,
      usedSeq: usedSeq,
      recentTemplates: recentTemplates,
      templateGroups: templateGroups,
      findTemplate: findTemplate,
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
      setMaterials: setMaterials,
      hardwareOf: hardwareOf,
      setHardware: setHardware,
      hardwarePayload: hardwarePayload,
      templateKind: templateKind,
      templatesOfKind: templatesOfKind
    };
  })();

  // Node testy (tests/js/test_insert_state.js) — v CEF je module undefined.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = NXInsert;
  }
