  // ===================== GHOST-FB4: GHOST PASIK ================================
  // Informacny pasik BEZIACEJ ghost session (skrinka visi na kurzore). Zije
  // VYHRADNE pocas session — po vlozeni aj po Esc sa schova, lebo vertikalny
  // priestor panela je vzacny a mimo vkladania by o nicom nehovoril.
  //
  // Panel si tu ZIADNY vlastny stav nedrzi ani nedopocitava: kazdy push z Ruby
  // (`NX.setGhost`) pasik CELY prepise. Jediny ovladac je pole locknutej vysky
  // — a aj to je len navrh: o platnej hodnote rozhoduje server (validacia bezi
  // na oboch stranach rovnako, klient len setri jedno kolo tam a spat).
  // Testovatelne v Node: tests/js/test_ghost_fb.js.
  'use strict';

  // Rozsah musi sedieť s Ruby (`GhostTool::LOCK_Z_MIN_MM` / `LOCK_Z_MAX_MM`).
  var NX_GHOST_LOCK_MIN = 0;
  var NX_GHOST_LOCK_MAX = 3000;
  var NX_GHOST_ANCHORS = {
    fl_bottom: 'ľavá dolná', fr_bottom: 'pravá dolná',
    fr_top: 'pravá horná', fl_top: 'ľavá horná'
  };
  // Posledny STAV zo servera — drzi sa LEN preto, aby sa dalo pole vratit na
  // platnu hodnotu, ked pouzivatel napise nezmysel (nikdy nespadne na 0).
  var nxGhostState = null;

  function nxGhostEl(id){
    return (typeof document !== 'undefined' && document.getElementById) ? document.getElementById(id) : null;
  }

  // 0 / 90 / 180 / 270 — normalizovane, aby pasik neukazal „-90°".
  function nxGhostRotLabel(deg){
    var d = Math.round(Number(deg));
    if (!isFinite(d)) d = 0;
    return (((d % 360) + 360) % 360) + '°';
  }

  function nxGhostModeLabel(mode){
    return mode === 'free' ? 'voľná výška' : 'zámok výšky';
  }

  function nxGhostAnchorLabel(anchor){
    return NX_GHOST_ANCHORS[anchor] || NX_GHOST_ANCHORS.fl_bottom;
  }

  // Zrkadlo `GhostTool::Calc.lock_z_value`: cislo v mm v rozumnom rozsahu,
  // inak null (= necitatelne, stara hodnota drzi). Ciarka aj bodka su desatinny
  // oddelovac; prazdno, text ani exponent neprejdu.
  function nxGhostLockValue(raw){
    var s = String(raw === undefined || raw === null ? '' : raw).trim().replace(',', '.');
    if (s === '') return null;
    if (!/^[+-]?\d+(\.\d+)?$/.test(s)) return null;
    var v = parseFloat(s);
    if (!isFinite(v)) return null;
    if (v < NX_GHOST_LOCK_MIN || v > NX_GHOST_LOCK_MAX) return null;
    return v;
  }

  // Cele cislo bez desatinnej nuly (vzor mmLabel, ale bez zavislosti na nom —
  // pasik sa nacitava skor nez form.js).
  function nxGhostMm(v){
    var n = Number(v);
    if (!isFinite(n)) return '';
    var r = Math.round(n * 10) / 10;
    return Math.abs(r - Math.round(r)) < 0.001 ? String(Math.round(r)) : String(r).replace('.', ',');
  }

  // Prekreslenie pasika z pushu Ruby. `active = false` (alebo prazdny stav) ho
  // SCHOVA — presne to chodi pri kazdom konci session.
  function nxGhostApply(state){
    var bar = nxGhostEl('ghostBar');
    if (!bar) return false;
    if (!state || !state.active){
      nxGhostState = null;
      bar.hidden = true;
      return false;
    }
    nxGhostState = state;
    bar.hidden = false;

    var anchor = nxGhostEl('gbAnchor');
    if (anchor){
      var label = state.anchor_label || nxGhostAnchorLabel(state.anchor);
      anchor.setAttribute('aria-label', 'Aktívna kotva: ' + label);
      anchor.setAttribute('title', 'Kotva ' + label + ' — Alt ju prepne (skrinka skočí pod kurzor)');
      var dots = anchor.querySelectorAll('.gbdot');
      for (var i = 0; i < dots.length; i++){
        dots[i].className = (dots[i].getAttribute('data-anchor') === state.anchor) ? 'gbdot on' : 'gbdot';
      }
    }
    var rot = nxGhostEl('gbRot');
    if (rot){
      rot.textContent = nxGhostRotLabel(state.rotation);
      rot.setAttribute('title', 'Otočenie okolo kotvy — ←/→ o 90°');
    }
    var mode = nxGhostEl('gbMode');
    if (mode){
      mode.textContent = nxGhostModeLabel(state.z_mode);
      mode.setAttribute('title', '↓ drží skrinku na zamknutej výške · ↑ ju pustí do voľnej výšky');
    }
    var inp = nxGhostEl('gbLockZ');
    if (inp) inp.value = nxGhostMm(state.lock_z);
    var wrap = nxGhostEl('gbLockWrap');
    if (wrap){
      // Vo volnej vyske pole hodnotu drzi (plati po stlaceni ↓), len je
      // stlmene — ovladac ostava pouzitelny, nie `disabled` (vzor D-78).
      wrap.className = state.z_mode === 'free' ? 'gblock dim' : 'gblock';
      wrap.setAttribute('title', state.z_mode === 'free'
        ? 'Výška zámku (mm) — použije sa, keď stlačíš ↓'
        : 'Výška, na ktorej ghost sedí (mm)');
    }
    return true;
  }

  // Pole vysky -> Ruby. Necitatelna hodnota sa NEODOSIELA: pole sa vrati na
  // poslednu platnu a status povie preco (server ma ten isty guard).
  function onGhostLockZ(){
    var inp = nxGhostEl('gbLockZ');
    if (!inp) return;
    // Bez BEZIACEJ session nie je co menit — pasik je vtedy schovany a
    // (napr. oneskorena) udalost pola by hovorila o niecom, co uz skoncilo.
    if (!nxGhostState) return;
    var v = nxGhostLockValue(inp.value);
    if (v === null){
      if (nxGhostState) inp.value = nxGhostMm(nxGhostState.lock_z);
      if (typeof NX !== 'undefined' && NX && NX.setStatus){
        NX.setStatus('Výška zámku musí byť číslo v mm od ' + NX_GHOST_LOCK_MIN + ' do ' +
                     NX_GHOST_LOCK_MAX + ' — ponechaná pôvodná hodnota.', true);
      }
      return;
    }
    if (nxGhostState && Math.abs(v - Number(nxGhostState.lock_z)) < 0.001) return; // no-op
    var payload = (typeof nxDocPayload === 'function')
      ? nxDocPayload({ lock_z: v })
      : JSON.stringify({ lock_z: v });
    if (typeof window !== 'undefined' && window.sketchup && window.sketchup.ghost_lock_z){
      window.sketchup.ghost_lock_z(payload);
    }
  }

  // Node testy (tests/js/test_ghost_fb.js) — v CEF je module undefined.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = {
      LOCK_MIN: NX_GHOST_LOCK_MIN,
      LOCK_MAX: NX_GHOST_LOCK_MAX,
      rotLabel: nxGhostRotLabel,
      modeLabel: nxGhostModeLabel,
      anchorLabel: nxGhostAnchorLabel,
      lockValue: nxGhostLockValue,
      mm: nxGhostMm,
      apply: nxGhostApply,
      onLockZ: onGhostLockZ
    };
  }
