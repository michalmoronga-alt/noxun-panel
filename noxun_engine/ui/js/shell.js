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

    // --- meta suhrny v listach sektorov (kontrakt UI 2.0) --------------------
    // Lista kazdeho sektora nesie vpravo jednoriadkovy SUHRN toho, co je vnutri
    // (mockup `sect(key, name, meta, …)`). Vidno ho ROVNAKO zbaleny aj rozbaleny
    // — zbaleny sektor tak povie, co skryva, a rozbaleny drzi ten isty udaj na
    // ocnom mieste. Skladanie je CISTA funkcia (testovana v Node): DOM cita az
    // obal `nxSectorMetaApply` nizsie.
    var PV_TITLE = { korpus: 'Čelný rez + kóty', zony: 'Zóny', cela: 'Čelá',
                     kovanie: 'Kovanie — pozície' };

    // mm do suhrnu: cele cislo (rozmer je cislo, nie veta). Neplatna alebo
    // nulova hodnota = null — radsej kratsi text nez vymyslene cislo.
    function metaMm(v){
      var n = parseFloat(v);
      return (isNaN(n) || n <= 0) ? null : String(Math.round(n));
    }

    // S1 — nazov PROJEKCIE, ktora sa prave kresli (nahlad je kontextovy, UI-B2).
    function metaTitle(mode, ctx, insertKind){
      if (mode === 'part')  return 'Dielec — hrany';
      if (mode === 'board') return 'Doska — hrany';
      // UI-C1b: vkladanie kresli sablonu TAK, AKO BUDE VLOZENA (N9) — nazov
      // projekcie je zrkadlom mockupu.
      if (mode === 'insert') return insertKind === 'board' ? 'Doska — smer dekoru' : 'Šablóna — ako bude vložená';
      return PV_TITLE[normCtx(ctx)];
    }

    // S2 — „900 × 720 × 560 · sokel 100". Trojica rozmerov je nedelitelna
    // (dva z troch by klamali); sokel sa pripaja len tam, kde vobec je
    // (horna skrinka ani doska ho nemaju).
    function metaDims(dims){
      var d = dims || {};
      var mm = [metaMm(d.w), metaMm(d.h), metaMm(d.d)];
      if (!(mm[0] && mm[1] && mm[2])) return '';
      var out = [mm.join(' × ')];
      var p = metaMm(d.plinth);
      if (p && d.plinth_visible !== false) out.push('sokel ' + p);
      return out.join(' · ');
    }

    // S3 — popisy materialov oddelene bodkou. Prazdny slot = dedenie, preto sa
    // vynecha; ked su prazdne VSETKY ponuknute sloty, povie sa to nahlas
    // (prazdna lista by vyzerala ako nedorobok). Ziadny slot (dielec, doska,
    // vkladanie korpusu) = ziadne meta.
    function metaMaterials(list){
      var src = list || [], out = [], i, s;
      for (i = 0; i < src.length; i++){
        s = String(src[i] == null ? '' : src[i]).trim();
        if (s) out.push(s);
      }
      if (out.length) return out.join(' · ');
      return src.length ? 'dedí z projektu' : '';
    }

    // S4 — otvorena skupina menom, inak pocet zbalenych. Slovenska mnozina:
    // 1 skupina · 2–4 skupiny · 5+ skupín. Meta NIKDY neopakuje nazov sektora
    // (kontext Cela ma jedinu skupinu „Čelá" — „ČELÁ Čelá" je sum, nie udaj).
    function metaGroups(groups, sectorName){
      var g = groups || {};
      var open = String(g.open == null ? '' : g.open).trim();
      if (open) return (open === String(sectorName == null ? '' : sectorName).trim()) ? '' : open;
      var n = parseInt(g.count, 10);
      if (isNaN(n) || n <= 0) return '';
      var w = (n === 1) ? 'skupina' : (n < 5 ? 'skupiny' : 'skupín');
      return n + ' ' + w + ' · všetko zbalené';
    }

    // Vstup je STAV, nie hotove texty — volajuci posiela cisla a ID prelozene
    // na popisy AZ v okamihu kreslenia (lekcia Codex #171 P2: cachovany retazec
    // by po premenovani dekoru ukazoval stary nazov).
    function sectorMeta(s){
      var x = s || {};
      var mode = (x.mode === undefined) ? state.mode : x.mode;
      return {
        s1: metaTitle(mode, x.ctx, x.insert_kind),
        s2: metaDims(x.dims),
        s3: metaMaterials(x.materials),
        s4: metaGroups(x.groups, x.s4_name)
      };
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

    // ===== UI-D3 (N5): riadky warnpanelu ===================================
    // Cista funkcia nad UZ PRIJATYMI upozorneniami stavby (BuildPlan kontrakt:
    // code / severity / message / part_key / data). Panel z nich kresli riadky
    // s okom — `keys` je presne to, co ma oko oznacit v modeli.
    //
    // PRAZDNE `keys` = korpusova uroven upozornenia (part_key nil): oznaci sa
    // CELA skrinka. Je to ta ista konvencia, aku uz ma box „Skrinka" v Kovani
    // (`handle_select_hw_owner` s prazdnym `part_keys`) — ziadna nova dohoda.
    //
    // Upozornenie bez textu sa ZAHODI: prazdny riadok s okom by sluboval, ze
    // sa da niekam skocit, a pritom by nepovedal preco.
    //
    // Codex #182 P2: NIEKTORE nalezy nesu `part_key` dielca, ktory sa do modelu
    // NIKDY nedostal — `part_skipped_degenerate` je presne o tom, ze plan dielec
    // VYRADIL (`construction.rb`), no kluc si v upozorneni ponechal, aby sa dalo
    // povedat KTORY to bol. Poslat taky kluc na vyber znamena zarucene „Dielec
    // sa v modeli nenašiel" — akcia, ktora nemoze uspiet. Preto taky nalez
    // spadne na KORPUSOVU uroven (prazdne kluce = oznaci sa skrinka): to je
    // najblizsia vec, ktora v modeli naozaj existuje.
    //
    // Zoznam je UZKY a explicitny — nie heuristika. Nepostavene dielce pozna
    // plan, nie panel; keby pribudol dalsi taky kod, patri SEM (a do testu).
    var WARN_PART_NOT_BUILT = ['part_skipped_degenerate'];
    function warnRows(warnings){
      var out = [];
      var list = warnings || [];
      for (var i = 0; i < list.length; i++){
        var w = list[i];
        if (!w) continue;
        var msg = String(w.message == null ? '' : w.message);
        if (!msg) continue;
        var code = String(w.code == null ? '' : w.code);
        var built = WARN_PART_NOT_BUILT.indexOf(code) < 0;
        var pk = (built && w.part_key != null) ? String(w.part_key) : '';
        out.push({ text: msg, keys: pk ? [pk] : [],
                   tip: pk ? 'Ukáž v modeli — označí dotknutý dielec'
                           : 'Ukáž v modeli — označí celú skrinku' });
      }
      return out;
    }

    // ===== UI-D3: deep-link do okna Vyroba (docasne „Štúdio") ==============
    // Taby okna Vyroba. Zoznam je ZRKADLO `ProductionDialog::TABS` — autoritou
    // whitelistu je RUBY (HTML/JS nie je ochrana), tento mirror len zabrani,
    // aby z panela vobec vyletela hodnota, ktora tab nepomenuva.
    var STUDIO_TABS = ['rows', 'sheets', 'edging', 'hardware', 'budget', 'control'];
    function studioTab(t){
      var s = String(t == null ? '' : t);
      return STUDIO_TABS.indexOf(s) >= 0 ? s : null;
    }
    // Payload prekliku. `tab: null` = „len otvor okno" (rail Štúdio) — server
    // vtedy tab NEPREPINA a pouzivatel ostane tam, kde naposledy skoncil.
    function studioLink(tab){ return { tab: studioTab(tab) }; }

    return {
      secKey: secKey,
      exclusiveClose: exclusiveClose,
      warnRows: warnRows,
      studioTab: studioTab,
      studioLink: studioLink,
      STUDIO_TABS: STUDIO_TABS,
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
      sectorMeta: sectorMeta,
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
    nxSectorMetaApply(); // meta suhrny listy sektorov (rezim aj kontext ich menia)
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

  // ===== DOM: meta suhrny v listach sektorov =================================
  // Cita ZIVY stav panela (polia S2, materialove selecty S3, otvorenu skupinu
  // S4) a prelozi ho cistou funkciou NXShell.sectorMeta. Ziadna vlastna kopia
  // dat — text sa sklada az v okamihu kreslenia, takze nikdy nezostarne.
  function nxMetaInsertKind(){
    var b = document.body;
    return (b && b.getAttribute('data-insert-kind')) || 'cabinet';
  }
  // Rozmery berie meta z TYCH ISTYCH poli, ktore sektor ukazuje — vratane
  // rozpisanej hodnoty (vyrazy prelozi numv rovnako ako zapisova cesta).
  function nxMetaDims(){
    if (NXShell.mode() === 'insert' && nxMetaInsertKind() === 'board')
      return { w: numv('ib_length'), h: numv('ib_width'), d: numv('ib_thickness') };
    var fh = el('fhRow');
    return { w: numv('width'), h: numv('height'), d: numv('depth'),
             plinth: numv('floor_height'),
             plinth_visible: !(fh && fh.style.display === 'none') };
  }
  // ID materialu -> popis z AKTUALNEHO katalogu (sheetLabelOf). Dielec a doska
  // maju vlastnu kartu v S4, vkladanie korpusu material v paneli nevolí (ten
  // urcuje sablona a projekt) — tam ziadne sloty neposielame.
  function nxMetaMaterials(){
    var mode = NXShell.mode();
    if (mode === 'part' || mode === 'board') return [];
    var lbl = function(id){
      var n = el(id), v = n ? n.value : '';
      if (!v) return '';
      return (typeof sheetLabelOf === 'function') ? sheetLabelOf(v) : v;
    };
    if (mode === 'insert'){
      if (nxMetaInsertKind() !== 'board') return [];
      var m = lbl('ib_material');
      return m ? [m] : [];
    }
    return [lbl('cab_body'), lbl('cab_front'), lbl('cab_back')];
  }
  // Skupiny S4 patria KONTEXTU (data-s4). Nazov otvorenej skupiny sa cita z jej
  // <summary> — slovenske nazvy tak ziju len v HTML (ikona je SVG, textContent
  // ju neberie).
  //
  // Codex #173 P2: `data-s4-solo` (strom zon) je vynaty z EXKLUZIVITY, NIE zo
  // zberu udajov — je to plnohodnotna skupina sektora. Ked sa preskakoval, mal
  // kontext Zony (jedine dieta S4 je prave solo strom) meta trvalo prazdne.
  function nxMetaGroups(){
    var mode = NXShell.mode();
    if (mode === 'part' || mode === 'board') return { open: '', count: 0 };
    var nodes = document.querySelectorAll('#secSet details[data-s4="' + NXShell.effectiveCtx() + '"]');
    var count = nodes.length, open = '', i, s;
    for (i = 0; i < nodes.length; i++){
      if (!nodes[i].open || open) continue;
      s = nodes[i].querySelector('summary');
      open = s ? (s.textContent || '').trim() : '';
    }
    return { open: open, count: count };
  }
  function nxSectorMetaApply(){
    if (!document.body) return;
    var mode = NXShell.mode(), ctx = NXShell.effectiveCtx();
    var m = NXShell.sectorMeta({
      mode: mode, ctx: ctx, insert_kind: nxMetaInsertKind(),
      dims: nxMetaDims(), materials: nxMetaMaterials(),
      groups: nxMetaGroups(), s4_name: nxS4Title(mode, ctx)
    });
    [['s1Meta', m.s1], ['s2Meta', m.s2], ['s3Meta', m.s3], ['s4Meta', m.s4]].forEach(function(o){
      var n = el(o[0]);
      if (n) n.textContent = o[1];
    });
  }
  // ZIVA obnova pri praci pouzivatela: pisanie do rozmerov a zmena materialu.
  // JEDEN delegovany listener namiesto zasahov do form.js/materials.js — meta je
  // len ZOBRAZENIE, nesmie sa votierat do zapisovych ciest. Zmenu kontextu,
  // rezimu aj serverovy push pokryva nxShellApply, otvorenie skupiny boot.js.
  var NX_META_FIELDS = ['width', 'height', 'depth', 'floor_height',
                        'ib_length', 'ib_width', 'ib_thickness',
                        'cab_body', 'cab_front', 'cab_front_c', 'cab_back', 'ib_material'];
  if (typeof document !== 'undefined'){
    var nxMetaWatch = function(ev){
      var t = ev.target;
      if (t && t.id && NX_META_FIELDS.indexOf(t.id) >= 0) nxSectorMetaApply();
    };
    document.addEventListener('input', nxMetaWatch, true);
    document.addEventListener('change', nxMetaWatch, true);
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
