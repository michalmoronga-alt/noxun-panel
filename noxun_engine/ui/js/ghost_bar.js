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
  // GHOST-D1: popisky umiestnenia dosky. Zrkadlo `BoardBuilder::ORIENTATION_LABELS`
  // — server ich posiela v pushi, toto je len fallback pre starší payload.
  var NX_GHOST_ORIENTATIONS = {
    leziaca: 'Naležato', stojaca: 'Nastojato', na_stenu: 'Na stenu'
  };
  // Nápoveda ovládania — pre KAŽDÝ subjekt vlastná (doska nemá zámok výšky,
  // má umiestnenie).
  var NX_GHOST_HELP = {
    cabinet: '←/→ otočí o 90° · Alt prepne kotvu · ↓ zámok výšky · ↑ voľná výška · Esc zruší · klik vloží',
    board: '←/→ otočí o 90° · ↑/↓ zmení umiestnenie · Alt prepne kotvu · Esc zruší · klik vloží',
    // GHOST-D2: kreslenie má inú nápovedu — kotva je pevná (počiatok), zato
    // pribudlo meracie pole a Shift.
    drawing: 'klik určí počiatok · ťahaj dĺžku a šírku · číslo + Enter · prázdny Enter = hodnota karty · ' +
      'Shift drží smer · ←/→ a ↑/↓ len PRED prvým klikom · Esc zruší'
  };
  // GHOST-D2: názvy fáz kreslenia. Zrkadlo `GhostTool::DRAW_PHASES` — server
  // posiela `phase_label`, toto je len fallback pre starší payload.
  var NX_GHOST_PHASES = {
    origin: 'Počiatok', length: 'Dĺžka', width: 'Šírka', done: 'Hotovo'
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

  // Subjekt session: 'cabinet' (default) | 'board'. Starší push subjekt
  // nenesie — vtedy platí skrinka, presne ako pred GHOST-D1.
  function nxGhostSubject(state){
    return (state && state.subject === 'board') ? 'board' : 'cabinet';
  }

  function nxGhostOriLabel(state){
    if (!state) return '';
    if (state.orientation_label) return String(state.orientation_label);
    return NX_GHOST_ORIENTATIONS[state.orientation] || '';
  }

  // GHOST-D2: kreslí sa (dva ťahy), alebo sa len umiestňuje? Starší push
  // `interaction` nenesie — vtedy platí umiestňovanie, presne ako pred D2.
  function nxGhostDrawing(state){
    return !!(state && state.interaction === 'drawing');
  }

  // Text fázy do pásika: „Dĺžka 2400 mm" / „Šírka — mm" / „Počiatok".
  // Zamknutá fáza to prizná (ťah sa preskočí).
  function nxGhostPhaseText(state){
    if (!nxGhostDrawing(state)) return '';
    var ph = String(state.phase || 'origin');
    var label = state.phase_label ? String(state.phase_label) : (NX_GHOST_PHASES[ph] || '');
    if (ph === 'origin') return NX_GHOST_PHASES.origin;
    if (ph === 'done') return NX_GHOST_PHASES.done;
    var v = (state.phase_value === null || state.phase_value === undefined) ? '' : nxGhostMm(state.phase_value);
    var txt = label + ' ' + (v === '' ? '—' : v) + ' mm';
    return state.phase_locked ? txt + ' (zamknutá)' : txt;
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

    // GHOST-D2: pri KRESLENÍ je počiatok pevná kotva (Alt nemá význam), takže
    // kotvové bodky sa skryjú a na ich mieste stojí FÁZA. Pásik nerastie
    // o riadok — mení sa len obsah toho istého.
    var drawing = nxGhostDrawing(state);
    var anchor = nxGhostEl('gbAnchor');
    if (anchor) anchor.hidden = drawing;
    var phase = nxGhostEl('gbPhase');
    if (phase){
      phase.hidden = !drawing;
      phase.textContent = nxGhostPhaseText(state);
      phase.setAttribute('title', 'Fáza kreslenia — číslo napíš a potvrď Enterom');
    }
    if (anchor && !drawing){
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
    // GHOST-D1: kabinetové ovládače výšky sú pri DOSKE skryté (prichytáva sa
    // plne v XYZ) a na ich mieste stojí UMIESTNENIE. Pole `ghost_lock_z` sa
    // pre dosku z JS nikdy neposiela a server ho navyše odmieta.
    var isBoard = nxGhostSubject(state) === 'board';
    var mode = nxGhostEl('gbMode');
    if (mode){
      mode.hidden = isBoard;
      mode.textContent = nxGhostModeLabel(state.z_mode);
      mode.setAttribute('title', '↓ drží skrinku na zamknutej výške · ↑ ju pustí do voľnej výšky');
    }
    var ori = nxGhostEl('gbOri');
    if (ori){
      ori.hidden = !isBoard;
      ori.textContent = nxGhostOriLabel(state);
      ori.setAttribute('title', 'Umiestnenie dosky — ↑/↓ ho prepínajú (naležato · nastojato · na stenu)');
    }
    var inp = nxGhostEl('gbLockZ');
    if (inp) inp.value = nxGhostMm(state.lock_z);
    var wrap = nxGhostEl('gbLockWrap');
    if (wrap){
      wrap.hidden = isBoard;
      // Vo volnej vyske pole hodnotu drzi (plati po stlaceni ↓), len je
      // stlmene — ovladac ostava pouzitelny, nie `disabled` (vzor D-78).
      wrap.className = state.z_mode === 'free' ? 'gblock dim' : 'gblock';
      wrap.setAttribute('title', state.z_mode === 'free'
        ? 'Výška zámku (mm) — použije sa, keď stlačíš ↓'
        : 'Výška, na ktorej ghost sedí (mm)');
    }
    var info = nxGhostEl('gbInfo');
    if (info) info.setAttribute('title', NX_GHOST_HELP[drawing ? 'drawing' : (isBoard ? 'board' : 'cabinet')]);
    if (isBoard) nxGhostSyncCard(state);
    return true;
  }

  // GHOST-D1: karta Dosky ukáže umiestnenie HNEĎ po ↑/↓ v modeli. Mení sa LEN
  // stav `NXInsert` + zrkadlo segmentov — ŽIADNA materializácia ani reset
  // karty (rozpísané rozmery, materiál a šablóna zostávajú nedotknuté).
  // Ďalšia session potom štartuje z tejto hodnoty.
  function nxGhostSyncCard(state){
    if (typeof NXInsert === 'undefined' || !NXInsert || !NXInsert.setBoardOrientation) return false;
    if (!state || !state.orientation) return false;
    if (!NXInsert.setBoardOrientation(state.orientation)) return false; // uz je nastavena
    if (typeof syncInsertOrientation === 'function') syncInsertOrientation();
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
    // GHOST-D1: pri DOSKE sa `ghost_lock_z` z JS neposiela NIKDY (pole je
    // skryte, ale skrytie nie je ochrana — server subjekt kontroluje tiez).
    if (nxGhostSubject(nxGhostState) === 'board') return;
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
      onLockZ: onGhostLockZ,
      subject: nxGhostSubject,
      oriLabel: nxGhostOriLabel,
      syncCard: nxGhostSyncCard,
      drawing: nxGhostDrawing,
      phaseText: nxGhostPhaseText,
      HELP: NX_GHOST_HELP,
      PHASES: NX_GHOST_PHASES
    };
  }
