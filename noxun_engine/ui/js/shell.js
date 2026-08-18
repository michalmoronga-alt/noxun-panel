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
    // Codex #168 P2 (2. kolo): identita nesie aj DOKUMENT — ID su jedinecne LEN
    // v ramci modelu, takze dva otvorene dokumenty bezne obsahuju CAB-001 aj
    // BRD-001. Bez guidu by prepnutie dokumentu vyzeralo ako echo push a panel
    // by ostal v starom kontexte namiesto resetu na Korpus.
    function identityOf(mode, sel){
      var p = sel || {};
      var g = String(p.model_guid || '');
      if (mode === 'cab')   return g + '|cab:' + String(p.cabinet_id || '');
      if (mode === 'part')  return g + '|part:' + String(p.cabinet_id || '') + '/' + String(p.role_key || '');
      if (mode === 'board') return g + '|board:' + String(p.board_id || '');
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

    // Rozlozenie identity na dokument a objekt — vstup identity guardov
    // asynchronnych callbackov (server ich porovna s tym, co je NAOZAJ vybrate).
    // '<guid>|board:BRD-003' -> { model_guid:'<guid>', id:'BRD-003' }.
    function identityId(){
      var s = state.identity;
      var bar = s.indexOf('|');
      if (bar < 0) return '';
      var i = s.indexOf(':', bar);
      return i < 0 ? '' : s.slice(i + 1);
    }
    function identityGuid(){
      var bar = state.identity.indexOf('|');
      return bar < 0 ? '' : state.identity.slice(0, bar);
    }

    function setLabel(t){ state.label = String(t == null ? '' : t); }

    // --- viditelnost sektorov S2/S3 + kontextovy riadok (kontrakt UI 2.0) -----
    // JEDINA autorita pravidla. Zakladne a Materialy su vlastnosti SKRINKY:
    //   * dielec / doska  — nezobrazuju sa vobec (maju vlastnu kartu v S4),
    //   * vkladanie       — zobrazuju sa (vkladacia karta + material dosky),
    //   * oznaceny korpus — LEN v kontexte Korpus; v Zonach/Celach/Kovani ich
    //     nahradi tenky kontextovy riadok s preklikom spat na Korpus.
    // CSS (pravidla nad #secBasic/#secMat) je ZRKADLOM tejto funkcie — zhodu
    // strazi tests/pure/test_uib1_kostra.rb, maticu tests/js/test_uib1_kostra.js.
    function sectorVis(mode, ctx){
      var m = (mode === undefined ? state.mode : mode);
      if (m === 'part' || m === 'board') return { basic: false, mat: false, note: false };
      var cab = (m === 'cab');
      // Mimo oznaceneho korpusu je zobrazeny kontext vzdy Korpus (effectiveCtx).
      var korpus = !cab || normCtx(ctx === undefined ? state.ctx : ctx) === 'korpus';
      return { basic: korpus, mat: korpus, note: cab && !korpus };
    }

    // Suhrn skrinky do kontextoveho riadku: „900 × 720 × 560 · K2738 MO".
    // Cista funkcia — cisla aj popis materialu prichadzaju z payloadu, panel
    // nic nedopocitava. Chybajuci udaj sa VYNECHA (radsej kratsi riadok nez
    // vymyslene cislo); ked nie je nic, ostane pomlcka (vzor nxCabInfo).
    function ctxNoteText(dims, material){
      var d = dims || {};
      var out = [];
      var mm = ['w', 'h', 'd'].map(function(k){
        var n = parseFloat(d[k]);
        return (isNaN(n) || n <= 0) ? null : String(Math.round(n));
      });
      if (mm[0] && mm[1] && mm[2]) out.push(mm.join(' × '));
      var m = String(material == null ? '' : material).trim();
      if (m) out.push(m);
      return out.length ? out.join(' · ') : '—';
    }

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
      identityId: identityId,
      identityGuid: identityGuid,
      setLabel: setLabel,
      sectorVis: sectorVis,
      ctxNoteText: ctxNoteText,
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
      var txt = enabled ? o.label : (o.label + ' — ' + reason);
      n.classList.toggle('on', on);
      n.setAttribute('aria-pressed', on ? 'true' : 'false');
      n.setAttribute('aria-disabled', enabled ? 'false' : 'true');
      // Codex #168 P2: vysvetlenie patri do VLASTNEJ bubliny raily — natívny
      // `title` sa zámerne NEPOUŽÍVA (bublina sa ukazuje hneď a druhý,
      // oneskorený systémový tooltip by ju len zdvojil). Čítačke to isté
      // povie aria-label.
      var b = n.querySelector('.railtip');
      if (b) b.textContent = txt;
      n.setAttribute('aria-label', txt);
    });
    // Docasna polozka (dielec/doska): viditelnost riadi CSS podla rezimu,
    // popis je jediny udaj, ktory sa meni. Sama polozka je len ukazovatel —
    // akciou je susedny krizik (#railTempX).
    var tip = el('railTempTip'), close = el('railTempX');
    var kind = (mode === 'board') ? 'Doska' : 'Dielec';
    var label = NXShell.label() ? (kind + ' — ' + NXShell.label()) : kind;
    if (tip) tip.textContent = label;
    if (close){
      close.setAttribute('aria-label', mode === 'board'
        ? ('Zrušiť výber — ' + label)
        : ('Späť na skrinku — zrušiť výber dielca (' + label + ')'));
    }
    var s4 = el('s4Name');
    if (s4) s4.textContent = nxS4Title(mode, ctx);
    nxCtxNoteApply();
  }

  // ===== DOM: kontextovy riadok (nahrada S2/S3 mimo Korpusu) =================
  // Suhrn skrinky si panel drzi TU — kontext sa prepina bez serveroveho pushu,
  // takze text musi prezit prepnutie. Plni ho bridge pri kazdom pushi skrinky
  // (nxSetCtxNote), viditelnost rozhoduje NXShell.sectorVis.
  var nxCtxNoteSum = '—';

  function nxSetCtxNote(dims, material){
    nxCtxNoteSum = NXShell.ctxNoteText(dims, material);
    nxCtxNoteApply();
  }

  // Viditelnost riadku riadi JS (inline display — vzor renderPartCard /
  // renderBoardCard); CSS je len poistka pre rezimy, kde riadok nesmie byt.
  function nxCtxNoteApply(){
    var n = el('ctxNote');
    if (!n) return;
    var vis = NXShell.sectorVis();
    var sum = el('ctxNoteSum');
    if (sum) sum.textContent = nxCtxNoteSum;
    n.style.display = vis.note ? '' : 'none';
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
  //
  // Codex #168 P1: odchod z karty MUSI najprv DOKONCIT rozpisany zapis. Zmeny
  // dosky (nazov, rozmer, pocet, smer) su debounced 400 ms a `NX.clearSelected`
  // ich cez `cancelBoardEdits` zahodi — pouzivatel by o poslednu upravu ticho
  // prisiel. Rovnaky flush handshake maju vsetky relay cesty okna Vyroba.
  // Codex #168 P2: callback je asynchronny, preto nesie IDENTITU dosky —
  // ak sa vyber medzitym zmenil, server zapis odmietne a len obnovi panel.
  function railTempClose(){
    var mode = NXShell.mode();
    if (mode === 'part'){
      if (typeof backToCabinet === 'function') backToCabinet();
      return;
    }
    if (mode !== 'board') return;
    if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
    if (window.sketchup && sketchup.clear_selection){
      sketchup.clear_selection(JSON.stringify({ board_id: NXShell.identityId(),
                                                model_guid: NXShell.identityGuid() }));
    }
  }

  // Koliesko — Nastavenia Inspectora (tema, rozmerove rady, o plugine, UI-B3).
  // Otvara MODAL, nie novy kontext raily: su to nastavenia POCITACA a musia byt
  // dostupne aj vtedy, ked nie je oznacene nic (kontexty su platne len nad
  // korpusom). Stavovy stroj NXShell sa tym nedotkne.
  function onInspectorSettings(){
    if (typeof openInspectorSettings === 'function'){ openInspectorSettings(); return; }
    if (window.NX && NX.setStatus) NX.setStatus('Nastavenia Inspectora sa nepodarilo otvoriť.', true);
  }

  // Codex #168 P2 (2. kolo): akcie z NAHLADU (klik na celo, klik na hranu
  // dielca/dosky, klik na zonu) mieria na ovladace v sektore Nastavenia. Ked je
  // sektor alebo jeho skupina ZBALENA, ciel je skryty — fokus nema kam sadnut a
  // combobox by sa otvoril z nulovej plochy. Preto sa pred takou akciou cesta
  // k prvku ROZBALI (vsetky <details> predkovia). Exkluzivita S4 sa tym spusti
  // normalne (toggle), takze zvysok kontextu sa poslusne zavrie.
  function nxRevealTarget(node){
    var n = node;
    while (n && n !== document.body){
      if (n.tagName && n.tagName.toLowerCase() === 'details' && !n.open) n.open = true;
      n = n.parentNode;
    }
    return node;
  }

  // ===== DOM: ABS kontrola hran v raile (audit A2) ===========================
  // Prepinac vola TU ISTU logiku ako toolbar aj okno Vyroba (EdgeCheck.toggle);
  // panel si ZIADNY vlastny stav nedrzi — zobrazuje presne to, co posle server.
  // Codex #168 P2 (2. kolo): prepinac nesie DOKUMENT, z ktoreho klik vysiel —
  // callback HtmlDialogu je asynchronny a bez neho by po prepnuti dokumentu
  // zapol overlay v CUDZOM modeli (rovnaky guard ma D-105 v okne Vyroba).
  function onEdgeCheckToggle(){
    if (window.sketchup && sketchup.nx_edge_toggle)
      sketchup.nx_edge_toggle(JSON.stringify({ model_guid: nxModelGuid }));
  }
  // Identita dokumentu, ktoreho stav panel prave zobrazuje. Chodi v KAZDOM
  // pushi (init aj loadSelected/loadBoard); pri prazdnom vybere sa drzi
  // posledna znama — vtedy sa aj tak nic neoznacuje.
  var nxModelGuid = '';
  // Hodnota sa prepisuje LEN ked ju volajuci naozaj poslal — payload bez tohto
  // pola (starsi push, vnoreny objekt) nesmie zmazat platnu identitu.
  function nxSetModelGuid(g){ if (g !== undefined && g !== null) nxModelGuid = String(g); }

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
