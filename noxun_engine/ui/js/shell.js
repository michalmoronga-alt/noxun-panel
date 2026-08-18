  // ===================== UI-B1: KOSTRA INSPECTORA ============================
  // Rail kontextov + 4 sektory. Kostra v panel.html je STATICKA (audit A4) —
  // tento modul NIKDY neprepisuje innerHTML kostry, meni len triedy a atributy.
  // Dovod: innerHTML re-render by zabil listenery, otvorene comboboxy (D-85),
  // rozpisane hodnoty poli aj fokus.
  //
  // DVA ODDELENE STAVY (audit A1):
  //   * selectionMode — CO je oznacene v modeli (insert | cab | part | board).
  //     Autorita je server; do JS chodi cez setUiMode z bridge.js.
  //   * viewContext   — CO chce pouzivatel v paneli vidiet (korpus | zony |
  //     cela | kovanie). Je platny LEN pri selectionMode === 'cab'.
  // Prechody: push s NOVOU identitou vyberu (ine cabinet_id / iny dielec / ina
  // doska / iny rezim) resetuje viewContext na 'korpus'; ECHO push tej istej
  // identity kontext NEMENI (rozpisana praca a otvorene skupiny musia prezit).
  // Zbalenia sektorov aj skupin ziju v localStorage (boot.js bindDetails), takze
  // preziju vsetko — vratane echo pushu aj zatvorenia panela.
  var NXShell = (function(){
    'use strict';
    var CONTEXTS = ['korpus', 'zony', 'cela', 'kovanie'];
    var state = {
      mode: 'insert',   // selectionMode zo servera
      identity: '',     // identita vyberu (retazec na porovnanie)
      ctx: 'korpus',    // viewContext (platny len pri mode === 'cab')
      label: ''         // popis docasnej polozky raily (dielec/doska)
    };

    function normCtx(c){ return CONTEXTS.indexOf(c) >= 0 ? c : 'korpus'; }
    // Kontexty maju zmysel LEN nad oznacenym korpusom — nad navrhom niet zon
    // ani ciel, dielec a doska maju vlastnu kartu.
    function ctxEnabled(mode){ return (mode === undefined ? state.mode : mode) === 'cab'; }

    // Identita vyberu z payloadu. Retazec zamerne: porovnava sa cely (rezim aj
    // ID naraz), takze cab -> part tej istej skrinky je SPRAVNE nova identita.
    function identityOf(mode, sel){
      var p = sel || {};
      if (mode === 'cab')   return 'cab:' + String(p.cabinet_id || '');
      if (mode === 'part')  return 'part:' + String(p.cabinet_id || '') + '/' + String(p.role_key || '');
      if (mode === 'board') return 'board:' + String(p.board_id || '');
      return 'none';
    }

    // Prechod stavu. Vracia true = NOVA identita (viewContext sa resetoval),
    // false = ECHO push (kontext drzi).
    function track(mode, identity){
      var id = String(identity == null ? '' : identity);
      var changed = (mode !== state.mode) || (id !== state.identity);
      state.mode = mode;
      state.identity = id;
      if (changed) state.ctx = 'korpus';
      return changed;
    }

    // Klik na kontext v raile. Mimo oznaceneho korpusu NEROBI NIC (autorita je
    // tento guard, nie CSS — vzor D-78: klik, Enter aj Space koncia tu).
    function setCtx(c){
      if (!ctxEnabled()) return false;
      var next = normCtx(c);
      if (next === state.ctx) return false;
      state.ctx = next;
      return true;
    }

    // ZOBRAZENY kontext: mimo oznaceneho korpusu vzdy 'korpus' (pamat sa tym
    // nemeni — po oznaceni skrinky sa aj tak resetuje, lebo identita je nova).
    function effectiveCtx(){ return ctxEnabled() ? state.ctx : 'korpus'; }

    function setLabel(t){ state.label = String(t == null ? '' : t); }

    // --- zbalenia sektorov a skupin (audit A5) -------------------------------
    // Kluc pamate: sektory (S1–S4) su NEZAVISLE (`nxsec_s1`), skupiny sektora S4
    // su KVALIFIKOVANE KONTEXTOM (`nxsec_s4.korpus.top`) — dva kontexty tak
    // nikdy nezdielaju stav rovnomennej skupiny.
    function secKey(key, s4ctx){
      return s4ctx ? ('nxsec_s4.' + s4ctx + '.' + key) : ('nxsec_' + key);
    }
    // Ktore skupiny sa maju po otvoreni `openedKey` zavriet. Exkluzivita plati
    // LEN v ramci JEDNEHO kontextu S4; sektory (bez `s4`) sa navzajom nikdy
    // nezatvaraju a `solo` skupiny (strom zon) su z exkluzivity vynate — ani
    // ich nikto nezatvara, ani ony nikoho.
    // items = [{ key, s4, solo, open }]
    function exclusiveClose(items, openedKey){
      items = items || [];
      var opened = null, i;
      for (i = 0; i < items.length; i++){ if (items[i].key === openedKey) opened = items[i]; }
      if (!opened || !opened.s4 || opened.solo) return [];
      var out = [];
      for (i = 0; i < items.length; i++){
        var it = items[i];
        if (it.key === openedKey || it.solo || !it.open || it.s4 !== opened.s4) continue;
        out.push(it.key);
      }
      return out;
    }

    return {
      secKey: secKey,
      exclusiveClose: exclusiveClose,
      CONTEXTS: CONTEXTS,
      state: state,
      normCtx: normCtx,
      ctxEnabled: ctxEnabled,
      identityOf: identityOf,
      track: track,
      setCtx: setCtx,
      effectiveCtx: effectiveCtx,
      setLabel: setLabel,
      mode: function(){ return state.mode; },
      label: function(){ return state.label; }
    };
  })();

  // Node testy (tests/js/test_uib1_kostra.js) — v CEF je module undefined a
  // DOM cast nizsie bezi normalne (rovnaky vzor ako insert_state.js/usage.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = NXShell;
  }

  // ===== DOM: rail ==========================================================
  // Popisy kontextov ziju TU (jeden zdroj pre title aj aria-label).
  var NX_RAIL_CTX = [
    { id: 'railKorpus',  ctx: 'korpus',  label: 'Korpus' },
    { id: 'railZony',    ctx: 'zony',    label: 'Zóny' },
    { id: 'railCela',    ctx: 'cela',    label: 'Čelá' },
    { id: 'railKovanie', ctx: 'kovanie', label: 'Kovanie' }
  ];
  // Nazov sektora S4 podla toho, co v nom prave je.
  var NX_S4_NAME = { korpus: 'Nastavenia', zony: 'Zóny', cela: 'Čelá', kovanie: 'Kovanie' };

  // Preco su kontexty neaktivne — text ide do tooltipu (pouzivatel nesmie
  // klikat do sivého tlacidla bez vysvetlenia).
  function nxCtxLockReason(mode){
    if (mode === 'part')  return 'označený je dielec — krížikom sa vrátiš na skrinku';
    if (mode === 'board') return 'označená je doska — nemá zóny ani čelá';
    return 'označ skrinku v modeli';
  }

  function nxS4Title(mode, ctx){
    if (mode === 'part')  return 'Dielec';
    if (mode === 'board') return 'Doska';
    return NX_S4_NAME[ctx] || 'Nastavenia';
  }

  // Zrkadlo stavu do DOM. Vola sa pri KAZDEJ zmene rezimu aj kontextu —
  // setUiMode predtym prepisal cely body.className, takze priznaky treba
  // nasadit znova (rovnaky dovod ako mal D-78 syncCabTabsLocked).
  function nxShellApply(){
    var b = document.body;
    if (!b) return;
    var mode = NXShell.mode();
    var ctx = NXShell.effectiveCtx();
    var enabled = NXShell.ctxEnabled();
    // Atribut na <body> riadi CSS viditelnost skupin S4 aj hintov nahladu.
    // PREZIJE prepis className (vzor data-insert-kind, D-08/Codex audit c).
    b.setAttribute('data-view-ctx', ctx);
    var reason = nxCtxLockReason(mode);
    NX_RAIL_CTX.forEach(function(o){
      var n = el(o.id);
      if (!n) return;
      var on = enabled && ctx === o.ctx;
      n.classList.toggle('on', on);
      n.setAttribute('aria-pressed', on ? 'true' : 'false');
      n.setAttribute('aria-disabled', enabled ? 'false' : 'true');
      n.title = enabled ? o.label : (o.label + ' — ' + reason);
    });
    // Docasna polozka (dielec/doska): viditelnost riadi CSS podla rezimu,
    // popis je jediny udaj, ktory sa meni.
    var tip = el('railTempTip'), temp = el('railTemp');
    if (tip && temp){
      var kind = (mode === 'board') ? 'Doska' : 'Dielec';
      var txt = NXShell.label() ? (kind + ' — ' + NXShell.label()) : kind;
      tip.textContent = txt;
      temp.setAttribute('aria-label', txt);
      temp.title = txt;
    }
    var s4 = el('s4Name');
    if (s4) s4.textContent = nxS4Title(mode, ctx);
  }

  // Klik na kontext v raile (inline onclick). Prepnutie meni nahlad aj
  // viditelne skupiny — preto tie iste kroky ako mal D-08 setCabTab.
  function setViewContext(c){
    if (!NXShell.setCtx(c)) return;
    nxShellApply();
    previewMode = cabTabPreview(NXShell.effectiveCtx());
    pvUserView = false; pvView = null; // novy vyjav = cisty fit (stale zoom by ho minul)
    renderPreview();
    refreshZoneUI();
  }

  // Krizik docasnej polozky. DIELEC: existujuca cesta „spat na skrinku"
  // (select_cabinet -> handle_select_cabinet). DOSKA: vycistenie vyberu na
  // serveri pod suspend guardom (vzor toolbaru „Vložiť" — Panel.show_insert);
  // ziadna operacia, ziadny zapis do modelu.
  function railTempClose(){
    var mode = NXShell.mode();
    if (mode === 'part'){
      if (typeof backToCabinet === 'function') backToCabinet();
      return;
    }
    if (mode === 'board' && window.sketchup && sketchup.clear_selection){
      sketchup.clear_selection('');
    }
  }

  // Koliesko — Nastavenia Inspectora (tema, rozmerove rady, o plugine) pridu
  // v davke UI-B3. Do vtedy tlacidlo poctivo povie, ze este nic nerobi.
  function onInspectorSettings(){
    if (window.NX && NX.setStatus)
      NX.setStatus('Nastavenia Inspectora (téma, rozmerové rady, o plugine) pribudnú v ďalšej dávke.', false);
  }

  // ===== DOM: ABS kontrola hran v raile (audit A2) ===========================
  // Prepinac vola TU ISTU logiku ako toolbar aj okno Vyroba (EdgeCheck.toggle);
  // panel si ZIADNY vlastny stav nedrzi — zobrazuje presne to, co posle server.
  function onEdgeCheckToggle(){
    if (window.sketchup && sketchup.nx_edge_toggle) sketchup.nx_edge_toggle('');
  }

  function nxApplyEdgeCheck(st){
    var n = el('railAbs');
    if (!n) return;
    var s = st || {};
    var avail = (s.available !== false);
    var on = !!s.active;
    n.classList.toggle('on', on);
    n.setAttribute('aria-pressed', on ? 'true' : 'false');
    n.setAttribute('aria-disabled', avail ? 'false' : 'true');
    var tip = el('railAbsTip');
    if (!tip) return;
    if (!avail){
      tip.textContent = 'ABS kontrola hrán — vyžaduje SketchUp 2023 alebo novší';
    } else if (on){
      var miss = (s.counts && s.counts.missing != null) ? s.counts.missing : null;
      tip.textContent = 'ABS kontrola hrán je ZAPNUTÁ' +
        (miss != null ? ' — ' + miss + ' hrán chýba podľa pravidla' : '');
    } else {
      tip.textContent = 'ABS kontrola hrán — zvýrazní olep v modeli';
    }
  }
