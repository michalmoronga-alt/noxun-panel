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
      label: '',        // popis docasnej polozky raily (dielec/doska)
      // S1-E: TYP oznaceneho korpusu (surovy z payloadu; vlastnosti cita
      // `NXTypes`). Rozhoduje, ktore kontexty maju zmysel — slot umyvacky zony
      // NEMA. Bootstrap pred `NX.init` = `NXTypes.FALLBACK` (dolna).
      cabType: 'lower'
    };

    // CISTA otazka: ma tento typ korpusu tento kontext? -> '' (ma) alebo DOVOD
    // (ide do bubliny raily). H12c: typ bez vnutra (`zones: none` z registra
    // servera — slot umyvacky) nema Zony; dovod je jeho `zones_reason`.
    function ctxLockedBy(ctx, type){
      var t = (type === undefined ? state.cabType : type);
      if (String(ctx) !== 'zony') return '';
      var p = NXTypes.get(t);
      return (p.zones === 'none' && p.zones_reason) ? String(p.zones_reason) : '';
    }

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
      // S1-E: kontext, ktory typ korpusu nema, sa NEDA otvorit — autorita je
      // tento guard, nie CSS ani `aria-disabled` (vzor D-78).
      if (ctxLockedBy(next)) return false;
      if (next === state.ctx) return false;
      state.ctx = next;
      return true;
    }

    // ZOBRAZENY kontext: mimo oznaceneho korpusu vzdy 'korpus' (pamat sa tym
    // nemeni — po oznaceni skrinky sa aj tak resetuje, lebo identita je nova).
    function effectiveCtx(){
      if (!ctxEnabled()) return 'korpus';
      // S1-E: zapamatany kontext moze byt pri NOVOM type zakazany (Zony ->
      // slot umyvacky) — vtedy padne na Korpus. Pamat sa tym nemeni.
      return ctxLockedBy(state.ctx) ? 'korpus' : state.ctx;
    }

    // S1-E: typ oznaceneho korpusu. Nastavuje ho `NX.loadSelected` z payloadu;
    // mimo oznaceneho korpusu ostava posledna hodnota (nikto sa jej nepyta).
    function setCabType(t){ state.cabType = String(t == null ? NXTypes.FALLBACK : t); }
    function cabType(){ return state.cabType; }

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

    // --- viditelnost sektorov S2/S3 + odkaz v liste Nahladu (kontrakt UI 2.0) --
    // JEDINA autorita pravidla. Zakladne a Materialy su vlastnosti SKRINKY:
    //   * dielec / doska  — nezobrazuju sa vobec (maju vlastnu kartu v S4),
    //   * vkladanie       — zobrazuju sa (vkladacia karta + material dosky),
    //   * oznaceny korpus — LEN v kontexte Korpus; v Zonach/Celach/Kovani ich
    //     nahradi ODKAZ v liste Nahladu (`link`: rozmery skrinky, klik = Korpus).
    // CSS (pravidla nad #secBasic/#secMat) je ZRKADLOM tejto funkcie — zhodu
    // strazi tests/pure/test_uib1_kostra.rb, maticu tests/js/test_uib1_kostra.js.
    function sectorVis(mode, ctx){
      var m = (mode === undefined ? state.mode : mode);
      if (m === 'part' || m === 'board') return { basic: false, mat: false, link: false };
      var cab = (m === 'cab');
      // Mimo oznaceneho korpusu je zobrazeny kontext vzdy Korpus (effectiveCtx).
      var korpus = !cab || normCtx(ctx === undefined ? state.ctx : ctx) === 'korpus';
      return { basic: korpus, mat: korpus, link: cab && !korpus };
    }

    // Bublina odkazu v liste Nahladu (H6b, O6): povie MATERIAL korpusu — ten je
    // v Korpuse, v liste ostavaju len rozmery. Cista funkcia; popis dekoru
    // prichadza uz prelozeny z AKTUALNEHO katalogu (bridge.js renderCtxNote).
    // Bez materialu ostane len vyzva (nic sa nevymysla).
    function s1LinkTitle(material){
      var m = String(material == null ? '' : material).trim();
      return m ? ('Materiál korpusu: ' + m + ' — klik otvorí kontext Korpus')
               : 'Klik otvorí kontext Korpus';
    }

    // --- „?" pod nahladom: gesta podla toho, co sa v nahlade DA robit (H6a, O5) ---
    // Nahrada staleho riadku `.pvhint`. JEDEN zdroj textu (cista funkcia, Node
    // test): zonova veta len tam, kde nahlad kresli zony a priecky (kontext Zony
    // a DIELEC — jeho nahlad je zonovy), veta o celach len v Celach, veta o znackach
    // len v Kovani; vkladanie, doska a Korpus maju samotne gesta zoomu a posunu.
    var PV_HELP_ZONY = 'Klik na zónu = výber (police, delenie) · ťahaj priečku = posun (magnet 1/4 · 1/2 · 3/4, Alt ho vypne)';
    var PV_HELP_CELA = 'Klik na čelo = jeho riadok v zozname';
    var PV_HELP_ZNACKA = 'Klik na značku = označí vlastníka v modeli · pozície sú orientačné';
    var PV_HELP_GESTA = 'Ctrl+koliesko = zoom · ťahaj plochu = posun pohľadu';
    function pvHelpText(mode, ctx){
      var m = (mode === undefined ? state.mode : mode);
      var c = normCtx(ctx === undefined ? state.ctx : ctx);
      var lead = '';
      if (m === 'part') lead = PV_HELP_ZONY;
      else if (m === 'cab' && c === 'zony') lead = PV_HELP_ZONY;
      else if (m === 'cab' && c === 'cela') lead = PV_HELP_CELA;
      else if (m === 'cab' && c === 'kovanie') lead = PV_HELP_ZNACKA;
      return lead ? (lead + ' · ' + PV_HELP_GESTA) : PV_HELP_GESTA;
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
      // ROH-B2 (O12, mockup B3): rohova povie aj zbalena STRANU a DVEROVU CAST
      // („dvere vľavo 450") — bez cisla len strana (nic sa nevymysla).
      var c = d.corner;
      if (c && (c.side === 'left' || c.side === 'right')){
        var dw = metaMm(c.door);
        out.push('dvere ' + (c.side === 'right' ? 'vpravo' : 'vľavo') + (dw ? ' ' + dw : ''));
      }
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

    // S4 — SUHRN OBSAHU kontextu (H6b, O12): zbaleny aj rozbaleny sektor ukazuje
    // to iste a otvorena skupina ho NEMENI (jej nazov je vidno hned pod listou).
    // Skladanie je cista funkcia nad zivym stavom, ktory zbiera DOM obal
    // (`nxMetaContent`) — nic sa necachuje. Slova sa berú z hodnot selectov;
    // neznama hodnota (novsi plugin) cast VYNECHA, nic sa nehada.
    var META_TOP = { full: 'plný strop', two_rails: 'strop 2 výstuhy', none: 'bez stropu' };
    var META_BOTTOM = { under_sides: 'boky na dne', between_sides: 'dno medzi bokmi' };
    var META_BACK = { overlay: 'chrbát naložený', inset: 'chrbát vložený', groove: 'chrbát v drážke',
                      rails: 'chrbát z líšt', none: 'bez chrbta' };
    function metaWord(map, key){
      return Object.prototype.hasOwnProperty.call(map, key) ? map[key] : '';
    }
    // Slovenska mnozina: 1 · 2–4 · 5+ (zhodne s `shelfWord` v actions.js).
    function skPlural(n, one, few, many){ return n === 1 ? one : (n >= 2 && n <= 4 ? few : many); }

    // Korpus: „strop 2 výstuhy · boky na dne · chrbát v drážke". Typ bez korpusu
    // (slot umyvacky) tieto skupiny nema — meta je prazdna (D6).
    function metaKorpus(c){
      if (!c || c.carcass === false) return '';
      return [metaWord(META_TOP, c.top), metaWord(META_BOTTOM, c.bottom), metaWord(META_BACK, c.back)]
        .filter(function(s){ return !!s; }).join(' · ');
    }
    // Zony: pocet LISTOV (bez 4. urovne `deep`, ktoru strom len zachovava) a sucet
    // ich polic: „1 zóna · prázdna" / „2 zóny · 3 police".
    function metaZones(zones){
      var leaves = (zones || []).filter(function(z){ return z && z.leaf && !z.deep; });
      var n = leaves.length;
      if (!n) return '';
      var shelves = leaves.reduce(function(a, z){ return a + Math.max(0, parseInt(z.shelves, 10) || 0); }, 0);
      var head = n + ' ' + skPlural(n, 'zóna', 'zóny', 'zón');
      if (shelves > 0) return head + ' · ' + shelves + ' ' + skPlural(shelves, 'polica', 'police', 'políc');
      return n === 1 ? head + ' · prázdna' : head;
    }
    // Cela: „1 čelo · F206 ST9 · medzera 3 · okraje 2". Texty sklada core.js
    // (`frontCountText`, `cabfrontMetaText`) — tu sa len spoja. Bez ciel len „bez čiel".
    function metaFronts(f){
      if (!f) return '';
      if (!(parseInt(f.count, 10) > 0)) return 'bez čiel';
      return [f.count_text, f.common_text].filter(function(s){ return !!s; }).join(' · ');
    }
    // Kovanie: ten isty `nxHwSummary`, aky kreslil nahlad. `items === null` =
    // nic neoznacene (''), prazdne pole = skrinka kovanie nema.
    function metaHardware(h){
      if (!h || h.items == null) return '';
      if (!h.items.length) return 'bez kovania';
      return String(h.summary == null ? '' : h.summary);
    }
    function metaContent(mode, ctx, content){
      if (mode !== 'cab') return ''; // dielec/doska maju vlastnu kartu; vkladanie S4 nema
      var c = content || {};
      switch (normCtx(ctx)){
        case 'zony':    return metaZones(c.zones);
        case 'cela':    return metaFronts(c.fronts);
        case 'kovanie': return metaHardware(c.hw);
        default:        return metaKorpus(c.korpus);
      }
    }

    // Odkaz v liste Nahladu (O6): rozmery skrinky (ta ista metaDims ako S2) mimo
    // Korpusu; v Korpuse a inych rezimoch '' (lista nesie nazov projekcie).
    function metaS1Link(mode, ctx, dims){
      if (mode !== 'cab' || normCtx(ctx) === 'korpus') return '';
      return metaDims(dims);
    }

    // Vstup je STAV, nie hotove texty — volajuci posiela cisla a ID prelozene
    // na popisy AZ v okamihu kreslenia (lekcia Codex #171 P2: cachovany retazec
    // by po premenovani dekoru ukazoval stary nazov).
    function sectorMeta(s){
      var x = s || {};
      var mode = (x.mode === undefined) ? state.mode : x.mode;
      return {
        s1: metaTitle(mode, x.ctx, x.insert_kind),
        s1link: metaS1Link(mode, x.ctx, x.dims),
        s2: metaDims(x.dims),
        s3: metaMaterials(x.materials),
        s4: metaContent(mode, x.ctx, x.content)
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
    //
    // Sweep review P2: `shelf_skipped_shallow_zone` (`zone_tree.rb`) je presne
    // ten isty pripad — prilis plytka zona police NEPOSTAVI, ale kluc prvej z
    // nich si v upozorneni ponecha. V zozname chybal, takze oko na tom riadku
    // koncilo hlaskou „Dielec sa v modeli nenašiel". Serverova strana obe kody
    // uz drzi spolu (`ui/production_core.rb`) — panel sa tym zrovnal.
    var WARN_PART_NOT_BUILT = ['part_skipped_degenerate', 'shelf_skipped_shallow_zone'];
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

    // ŠT-1c PR B3: whitelist tabov okna Vyroba, jeho filter aj skladanie
    // payloadu deep-linku na tab tu ZANIKLI spolu s oknom. Vsetky jeho obsahy
    // su sekciami Studia, takze jediny deep-link je ten nizsie — na SEKCIU.

    // ===== ST-1a: deep-link do okna STUDIO ==================================
    // Sekcie Studia pozna register `js/studio_sections.js` (H14a; nacitava sa
    // v panel.html PRED tymto suborom) — autoritou whitelistu je RUBY
    // (`StudioDialog::SECTIONS`), register len zabrani, aby z panela vyletela
    // hodnota, ktora sekciu nepomenuva. Je staticky, takze filter funguje hned
    // (necaka na `NX.init`). Vlastny zoznam sekcii tu nie je.
    var SECREG = (typeof module !== 'undefined' && module.exports)
      ? require('./studio_sections.js')                                 // Node testy
      : (typeof window !== 'undefined' ? window.NXStudioSections : null);
    function studioSection(s){
      var v = String(s == null ? '' : s);
      return SECREG.has(v) ? v : null;
    }
    // `anchor` predvyplni hladanie sekcie (N13 posiela ID skrinky). Bez sekcie
    // kotva nema kam sadnut, preto ide von LEN spolu s nou.
    function studioOpenLink(section, anchor){
      var sec = studioSection(section);
      var a = (anchor == null) ? '' : String(anchor).trim();
      return { section: sec, anchor: (sec && a) ? a : null };
    }

    // ===== K2/D-87: prepinac „Kontrola kresby" v raile =======================
    // CISTA funkcia — z jedineho serveroveho stavu (`GrainCheck.ui_state`)
    // spravi to, co ma DOM nasadit. Klient si NIC neprepocitava a NIC si
    // nepamata: rovnaky vzor ako ABS kontrola, len s vlastnymi textami.
    // Chybajuci stav = prepinac zhasne (radsej nic nez nahodne „zapnute").
    // 1 dielec / 2–4 dielce / 5+ dielcov — zrkadlo `grain_part_plural` v Ruby.
    function grainPartWord(n){
      var v = Math.abs(Number(n) || 0);
      if (v === 1) return 'dielec';
      if (v >= 2 && v <= 4) return 'dielce';
      return 'dielcov';
    }
    function grainRail(st){
      var s = st || {};
      var available = (s.available !== false);
      var on = available && !!s.active;
      var tip;
      if (!available){
        tip = 'Kontrola kresby — vyžaduje SketchUp 2023 alebo novší';
      } else if (on){
        tip = 'Kontrola smeru kresby je zapnutá';
        if (s.parts != null) tip += ' — ' + s.parts + ' ' + grainPartWord(s.parts) + ' s kresbou';
        if (s.skipped) tip += ' · ' + s.skipped + ' bez kresby (materiál bez smeru)';
      } else {
        tip = 'Kontrola smeru kresby (zapnúť/vypnúť)';
      }
      return { available: available, on: on, tip: tip };
    }

    // ===== KOV-A2b: prepinac „Smer otvárania" v raile ========================
    // CISTA funkcia — z jedineho serveroveho stavu (`DirectionCheck.ui_state`)
    // spravi to, co ma DOM nasadit. Presne ten isty vzor ako `grainRail`, len
    // s vlastnymi textami; klient si NIC neprepocitava a NIC si nepamata.
    // 1 krídlo / 2–4 krídla / 5+ krídel — zrkadlo `direction_wing_plural` v Ruby.
    function directionWingWord(n){
      var v = Math.abs(Number(n) || 0);
      if (v === 1) return 'krídlo';
      if (v >= 2 && v <= 4) return 'krídla';
      return 'krídel';
    }
    function directionRail(st){
      var s = st || {};
      var available = (s.available !== false);
      var on = available && !!s.active;
      var tip;
      if (!available){
        tip = 'Smer otvárania — vyžaduje SketchUp 2023 alebo novší';
      } else if (on){
        tip = 'Smer otvárania čiel je zapnutý';
        if (s.wings != null) tip += ' — ' + s.wings + ' ' + directionWingWord(s.wings);
        if (s.unknown) tip += ' · ' + s.unknown + ' neurčených';
        if (s.legacy) tip += ' · ' + s.legacy + ' bez smeru (staršie čelá)';
      } else {
        tip = 'Smer otvárania čiel v modeli (zapnúť/vypnúť)';
      }
      return { available: available, on: on, tip: tip };
    }

    return {
      secKey: secKey,
      exclusiveClose: exclusiveClose,
      warnRows: warnRows,
      studioSection: studioSection,
      studioOpenLink: studioOpenLink,
      CONTEXTS: CONTEXTS,
      state: state,
      normCtx: normCtx,
      ctxEnabled: ctxEnabled,
      identityOf: identityOf,
      track: track,
      setCtx: setCtx,
      effectiveCtx: effectiveCtx,
      ctxLockedBy: ctxLockedBy,
      setCabType: setCabType,
      cabType: cabType,
      identityId: identityId,
      identityGuid: identityGuid,
      setLabel: setLabel,
      sectorVis: sectorVis,
      s1LinkTitle: s1LinkTitle,
      pvHelpText: pvHelpText,
      sectorMeta: sectorMeta,
      grainRail: grainRail,
      grainPartWord: grainPartWord,
      directionRail: directionRail,
      directionWingWord: directionWingWord,
      mode: function(){ return state.mode; },
      label: function(){ return state.label; }
    };
  })();

  // Node testy (tests/js/test_uib1_kostra.js) — v CEF je module undefined a
  // DOM cast nizsie bezi normalne (rovnaky vzor ako insert_state.js/usage.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = NXShell;
    // R-02 (tests/js/test_r02_doc_guard.js): zapisovy payload panela zije MIMO
    // NXShell namespace — pouziva modulovy `nxModelGuid`, ktory nie je sucastou
    // kostry Inspectora. Deklaracie funkcii su hoistovane, takze referencia tu
    // plati aj ked su definovane nizsie.
    module.exports.nxDocPayload = nxDocPayload;
    module.exports.nxDocGuid = nxDocGuid;
    module.exports.nxSetModelGuid = nxSetModelGuid;
    module.exports.nxDropDocState = nxDropDocState;
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
      // S1-E: kontext moze byt zakazany aj pri OZNACENEJ skrinke — vtedy ma
      // vlastny dovod (slot umyvacky zony nema).
      var lock = enabled ? NXShell.ctxLockedBy(o.ctx) : '';
      var live = enabled && !lock;
      var on = live && ctx === o.ctx;
      var txt = live ? o.label : (o.label + ' — ' + (lock || reason));
      n.classList.toggle('on', on);
      n.setAttribute('aria-pressed', on ? 'true' : 'false');
      n.setAttribute('aria-disabled', live ? 'false' : 'true');
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
    // „?" pod nahladom: text gest podla rezimu a kontextu (cista NXShell.pvHelpText).
    var pvh = el('pvHelp');
    if (pvh) pvh.setAttribute('data-tip', NXShell.pvHelpText(mode, ctx));
    nxSectorMetaApply(); // meta suhrny listy sektorov (rezim aj kontext ich menia)
  }

  // ===== DOM: odkaz na Korpus v liste Nahladu (nahrada pasu `#ctxNote`) =======
  // Mimo Korpusu stoji v liste S1 miesto nazvu projekcie ODKAZ s rozmermi
  // skrinky (statický <button id="s1Link"> v HTML — A4: kostra sa neprekresluje,
  // JS pise len text, `title` a `hidden`). Text zlozi nxSectorMetaApply z tych
  // istych poli ako lista Zakladne; bublina nesie MATERIAL korpusu. Popis
  // materialu si panel drzi TU (kontext sa prepina bez serveroveho pushu) —
  // plni ho bridge pri kazdom pushi skrinky a pri zmene katalogu.
  var nxS1LinkMaterial = '';

  function nxSetS1LinkTitle(material){
    nxS1LinkMaterial = String(material == null ? '' : material);
    nxS1LinkApplyTitle();
  }
  function nxS1LinkApplyTitle(){
    var b = el('s1Link');
    if (!b) return;
    var t = NXShell.s1LinkTitle(nxS1LinkMaterial);
    b.setAttribute('title', t);
    b.setAttribute('aria-label', t);
  }
  // Klik v <summary> by sektor zbalil — rovnaky stop ako „?" a ikony skupin.
  function nxS1Link(ev){
    if (typeof nxTipStop === 'function') nxTipStop(ev);
    setViewContext('korpus');
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
    var out = { w: numv('width'), h: numv('height'), d: numv('depth'),
                plinth: numv('floor_height'),
                plinth_visible: !(fh && fh.style.display === 'none') };
    // ROH-B2 (O12): strana dveri (prepinac riadku rohovej) a dverova cast
    // (pole riadku) — len pri rohovej, inak kluc nie je a meta je dnesna.
    if (typeof getType === 'function' && NXTypes.corner(getType()) && typeof nxCornerSide === 'function')
      out.corner = { side: nxCornerSide(), door: numv('corner_door_w') };
    return out;
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
  // S4 — ZIVY STAV obsahu kontextu (O12): hodnoty selectov Korpusu, listy stromu
  // zon, pocet ciel + spolocne nastavenia, polozky kovania. Zbiera sa LEN to,
  // co aktualny kontext potrebuje (pocitat zony v Celach by bola zbytocna praca
  // pri kazdom stlaceni klavesu). Slova a suhrny skladaju ciste funkcie v
  // NXShell (metaKorpus/metaZones/metaFronts/metaHardware) a core.js/preview.js
  // — otvorena skupina suhrn NEMENI, takze sa uz nezbiera ani jej nazov.
  function nxMetaContent(mode, ctx){
    var out = {};
    if (mode !== 'cab') return out;
    var v = function(id){ var n = el(id); return n ? n.value : ''; };
    if (ctx === 'zony'){
      if (typeof computeZones === 'function'){
        var max = (typeof NXZ !== 'undefined' && NXZ.MAX_LEVELS) ? NXZ.MAX_LEVELS : 3;
        out.zones = computeZones().map(function(z){
          return { leaf: z.leaf, shelves: z.shelves, deep: z.path.length > max };
        });
      }
    } else if (ctx === 'cela'){
      var fc = (typeof nxFrontCounts === 'function') ? nxFrontCounts() : { n: 0, unset: 0 };
      out.fronts = {
        count: fc.n,
        count_text: (typeof frontCountText === 'function') ? frontCountText(fc.n, fc.unset) : '',
        common_text: (typeof nxCabfrontText === 'function') ? nxCabfrontText() : ''
      };
    } else if (ctx === 'kovanie'){
      var items = (typeof hwItems !== 'undefined') ? hwItems : null;
      out.hw = { items: items,
                 summary: (items && typeof nxHwSummary === 'function') ? nxHwSummary(items) : '' };
    } else {
      out.korpus = {
        carcass: !(typeof getType === 'function' && typeof NXTypes !== 'undefined') || NXTypes.carcass(getType()),
        top: v('top_mode'), bottom: v('bottom_mode'), back: v('back_mode')
      };
    }
    return out;
  }
  function nxSectorMetaApply(){
    if (!document.body) return;
    var mode = NXShell.mode(), ctx = NXShell.effectiveCtx();
    var dims = nxMetaDims();
    var m = NXShell.sectorMeta({
      mode: mode, ctx: ctx, insert_kind: nxMetaInsertKind(),
      dims: dims, materials: nxMetaMaterials(),
      content: nxMetaContent(mode, ctx)
    });
    [['s1Meta', m.s1], ['s2Meta', m.s2], ['s3Meta', m.s3], ['s4Meta', m.s4]].forEach(function(o){
      var n = el(o[0]);
      if (n) n.textContent = o[1];
    });
    // Mimo Korpusu stoji v liste Nahladu odkaz s rozmermi MIESTO nazvu projekcie
    // (nazov uz hovori rail aj chip pod nahladom).
    var on = !!m.s1link;
    var link = el('s1Link'), lt = el('s1LinkTxt'), s1 = el('s1Meta');
    if (lt) lt.textContent = m.s1link;
    if (link) link.hidden = !on;
    if (s1) s1.hidden = on;
    if (on) nxS1LinkApplyTitle();
  }
  // ZIVA obnova pri praci pouzivatela: pisanie do rozmerov a zmena materialu.
  // JEDEN delegovany listener namiesto zasahov do form.js/materials.js — meta je
  // len ZOBRAZENIE, nesmie sa votierat do zapisovych ciest. Zmenu kontextu,
  // rezimu aj serverovy push pokryva nxShellApply, otvorenie skupiny boot.js.
  var NX_META_FIELDS = ['width', 'height', 'depth', 'floor_height', 'corner_door_w',
                        'ib_length', 'ib_width', 'ib_thickness',
                        'cab_body', 'cab_front', 'cab_front_c', 'cab_back', 'ib_material',
                        'top_mode', 'bottom_mode', 'back_mode',
                        'fr_gap', 'fr_gap_top', 'fr_gap_bottom', 'fr_gap_left', 'fr_gap_right'];
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
  // prisiel. Rovnaky flush handshake maju vsetky relay cesty Studia.
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
  // Prepinac vola TU ISTU logiku ako toolbar aj ŠTÚDIO (EdgeCheck.toggle);
  // panel si ZIADNY vlastny stav nedrzi — zobrazuje presne to, co posle server.
  // Codex #168 P2 (2. kolo): prepinac nesie DOKUMENT, z ktoreho klik vysiel —
  // callback HtmlDialogu je asynchronny a bez neho by po prepnuti dokumentu
  // zapol overlay v CUDZOM modeli (rovnaky guard ma D-105 v ŠTÚDIU).
  function onEdgeCheckToggle(){
    if (window.sketchup && sketchup.nx_edge_toggle)
      sketchup.nx_edge_toggle(JSON.stringify({ model_guid: nxModelGuid }));
  }
  // K2/D-87: KONTROLA KRESBY z raily. Ta ista cesta ako prepinac v ŠTÚDIU
  // (Engine.toggle_grain_check) — panel si ZIADNY vlastny stav nedrzi. Guard
  // dokumentu je rovnaky ako pri ABS (asynchronny callback HtmlDialogu).
  function onGrainCheckToggle(){
    if (window.sketchup && sketchup.nx_grain_toggle)
      sketchup.nx_grain_toggle(JSON.stringify({ model_guid: nxModelGuid }));
  }
  // KOV-A2b: SMER OTVARANIA z raily. Ta ista cesta ako prepinac v ŠTÚDIU
  // (Engine.toggle_direction_check) — panel si ZIADNY vlastny stav nedrzi.
  // Guard dokumentu je rovnaky ako pri ABS a kresbe.
  function onDirectionCheckToggle(){
    if (window.sketchup && sketchup.nx_direction_toggle)
      sketchup.nx_direction_toggle(JSON.stringify({ model_guid: nxModelGuid }));
  }
  // Identita dokumentu, ktoreho stav panel prave zobrazuje. Chodi v KAZDOM
  // pushi (init aj loadSelected/loadBoard); pri prazdnom vybere sa drzi
  // posledna znama — vtedy sa aj tak nic neoznacuje.
  var nxModelGuid = '';
  // Hodnota sa prepisuje LEN ked ju volajuci naozaj poslal — payload bez tohto
  // pola (starsi push, vnoreny objekt) nesmie zmazat platnu identitu.
  //
  // R-02 (review #264 kolo 2): toto je zaroven JEDINY DETEKTOR ZMENY DOKUMENTU
  // na klientovi — kazdy push (init, loadSelected, loadBoard, clearSelected) ide
  // cez neho. Pri SKUTOCNEJ zmene hodnoty sa zahodi vsetok rozpracovany stav
  // panela (nxDropDocState); echo push toho isteho dokumentu nezahodi NIC
  // (rozpisana praca musi prezit — rovnaka zasada ako pri NXShell.track).
  function nxSetModelGuid(g){
    if (g === undefined || g === null) return;
    var next = String(g);
    if (next === nxModelGuid) return;
    nxModelGuid = next;
    nxDropDocState();
  }

  // VSETOK stav panela, ktory drzi data MEDZI akciou pouzivatela a volanim
  // `sketchup.*`. Po prepnuti dokumentu uz ziadny z nich nema kam zapisat:
  // pending buffery patria starej zakazke a otvoreny editor ci modal by svoje
  // rozhodnutie aplikoval na kartu, ktora na obrazovke uz nie je.
  //
  // Je to PRVA obrana (druhou je zachytena identita v kazdom bufferi, tretou
  // serverovy `foreign_document?`). Zamerne sa NEVYMENOVAVA cez `window[...]`,
  // ale menami — zoznam je greppovatelny aj testovatelny a `typeof` na
  // nedeklarovanom identifikatore je bezpecny (Node aj CEF).
  //
  // MIMO zoznamu su vedome: `insertLocksTimer` (zamky vkladacej karty ziju
  // v pamati Panel modulu, do modelu nezapisuju), `previewTimer` (lokalny
  // re-render) a draft vkladacej karty (`NXInsert` — vklad peciatkuje identitu
  // az v okamihu kliku).
  function nxDropDocState(){
    if (typeof nxFrontDraftReset === 'function') nxFrontDraftReset();
    if (typeof cancelCabinetEdits === 'function') cancelCabinetEdits();   // auto-apply korpusu
    if (typeof cancelBoardEdits === 'function') cancelBoardEdits();       // polia karty dosky
    if (typeof dropCabRename === 'function') dropCabRename();             // inline premenovanie
    if (typeof closeCabRenameEditor === 'function') closeCabRenameEditor();
    if (typeof absModalCloseSilent === 'function') absModalCloseSilent(); // modal chybajucej ABS
    if (typeof closeSaveTemplateModal === 'function') closeSaveTemplateModal();
    if (typeof closeSimilarModal === 'function') closeSimilarModal();     // „Použiť na podobné"
    if (typeof aprMountClose === 'function') aprMountClose();             // D-140 popover osadenia
    // Zatvarka „apply odoslany, echo este nedoslo" je DRUHA polovica podmienky
    // `keepGaps`. Nuluje sa VYHRADNE tu, nie v `cancelCabinetEdits` (interne
    // review kola 4, P2): tam bezi aj jednodokumentove flow — zruseny okamzity
    // flush a rozpisany vyraz v poli — a zhodena zatvarka by nechala najblizsie
    // echo zmazat prave pridane celo. Tu bezi len pri REALNEJ zmene dokumentu.
    if (typeof cabEditsInFlight !== 'undefined') cabEditsInFlight = false;
    // Fokus: CEF drzi `document.activeElement` aj po strate fokusu okna, takze
    // `bset` (karta dosky) by po prepnuti dokumentu pole s kurzorom PRESKOCILO
    // a nechalo v nom hodnotu zo starej zakazky — Enter by ju poslal do novej.
    // Blur pred prekreslenim to zavrie; fokus nie je nikdy dovod, aby zahodenie
    // stavu zlyhalo, preto try/catch.
    try {
      if (typeof document !== 'undefined' && document.activeElement &&
          typeof document.activeElement.blur === 'function') document.activeElement.blur();
    } catch (e) { /* fokus sa nepodarilo zhodit — stav je aj tak uz zahodeny */ }
  }

  // R-02: JEDNO miesto, kde ZAPISOVY payload panela dostane identitu dokumentu.
  // Vzor `nxZonePayload` (zone_tree.js) — ten navyse pridava `cabinet_id`, tento
  // je pre cesty, ktoré si svoju vlastnú identitu (cabinet_id / board_id) nesú
  // samy alebo ju nemajú vôbec (vkladanie).
  //
  // PRECO: callback HtmlDialogu je asynchrónny a panel je JEDEN pre všetky
  // otvorené dokumenty. ID objektov sú jedinečné LEN v rámci modelu, takže echo
  // `cabinet_id` prepnutie dokumentu NEZACHYTÍ. Server payload bez zhodného
  // guidu ODMIETNE — prázdny guid je okno bez dobehnutého NX.init a to nesmie
  // zapisovať nikam.
  //
  // `guid` = ZACHYTENA identita (review #264 P1). `nxModelGuid` je mutovatelny
  // global, ktory prepise najblizsi push zo servera — pri debounced editoch
  // (auto-apply korpusu, polia karty dosky; 400 ms) by sa oneskoreny zapis
  // opeciatkoval NOVYM dokumentom a guard by ho pustil presne tam, kam nema.
  // Volajuci s odlozenym odoslanim preto cita `nxDocGuid()` uz pri NAPLANOVANI
  // a zachytenu hodnotu poda sem; okamzite cesty argument vynechaju (medzi
  // klikom a odoslanim sa v jednovlaknovom JS push vykonat nemoze).
  // Prazdny retazec je PLATNA zachytena hodnota (server ju odmietne) — preto sa
  // vetvi na undefined/null, nie na pravdivost.
  function nxDocPayload(obj, guid){
    var o = obj || {};
    o.model_guid = (guid === undefined || guid === null) ? nxDocGuid() : String(guid);
    return JSON.stringify(o);
  }

  // Identita dokumentu, ktory panel PRAVE zobrazuje. Citat ju treba v okamihu,
  // ked sa akcia NAPLANUJE — nie ked sa odosiela (viz nxDocPayload vyssie).
  function nxDocGuid(){ return (typeof nxModelGuid === 'string') ? nxModelGuid : ''; }

  // Posledny STAV zo servera. Drzi sa LEN preto, aby sa dalo rohove nastavenie
  // prekreslit s cerstvymi poctami — panel si z neho nic neodvodzuje ani nic
  // nedopocitava (kazdy push ho cely prepise).
  var nxEdgeState = null;

  function nxApplyEdgeCheck(st){
    nxEdgeState = st || null;
    var n = el('railAbs');
    if (!n) return;
    var s = st || {};
    var avail = (s.available !== false);
    var on = !!s.active;
    n.classList.toggle('on', on);
    n.setAttribute('aria-pressed', on ? 'true' : 'false');
    n.setAttribute('aria-disabled', avail ? 'false' : 'true');
    // Rohovy trojuholnik (flyout) ma zmysel len tam, kde je co nastavovat —
    // bez Overlay API sa nastavenie neotvara a nesvieti.
    var more = el('railAbsMore');
    if (more) more.setAttribute('aria-disabled', avail ? 'false' : 'true');
    // Okno s nastavenim je otvorene? Prekresli ho — POCTY su zive (zmena vyberu
    // aj prestavba skrinky posielaju novy stav).
    if (nxEdgeMenuOpen()) nxRenderEdgeMenu(true);
    var tip = el('railAbsTip');
    if (!tip) return;
    if (!avail){
      tip.textContent = 'ABS kontrola hrán — vyžaduje SketchUp 2023 alebo novší';
    } else if (on){
      var miss = (s.counts && s.counts.missing != null) ? s.counts.missing : null;
      tip.textContent = 'ABS kontrola hrán je zapnutá' +
        (miss != null ? ' — ' + miss + ' hrán chýba podľa pravidla' : '');
    } else {
      tip.textContent = 'ABS kontrola hrán — zvýrazní olep v modeli';
    }
  }

  // ===== v0.7.28: ROHOVE 3-STAVOVE NASTAVENIE ABS KONTROLY ==================
  // Vzor flyoutu (SketchUp/Photoshop): maly plny trojuholnik v pravom dolnom
  // rohu ikony hovori „tu je este nastavenie". KLIKACIA zona je cely pravy
  // dolny KVADRANT tlacidla (samotny trojuholnik by bol pre mys neterc), a je
  // to SAMOSTATNE tlacidlo vedla prepinaca (vnorene tlacidlo je neplatne HTML —
  // lekcia krizika docasnej polozky), takze klik na roh sa k toggle nikdy
  // nedostane.
  //
  // Obsah okna je ZDIELANY komponent (js/edge_menu.js) — to iste nastavenie,
  // ktore ma lista sekcie Kontrola v ŠTÚDIU. JEDEN stav (server, %APPDATA%), JEDEN
  // markup; panel si drzi len to, ci je okno otvorene.
  function nxEdgeMenuNode(){ return el('railAbsMenu'); }

  function nxEdgeMenuOpen(){
    var m = nxEdgeMenuNode();
    return !!(m && m.classList && m.classList.contains('open'));
  }

  // Jedno miesto, kde sa meni obsah aj viditelnost — `aria-expanded` rohoveho
  // tlacidla tak hovori pravdu bez ohladu na to, ktora cesta okno zavrela.
  function nxRenderEdgeMenu(open){
    var m = nxEdgeMenuNode();
    if (!m || !window.NXEdgeMenu) return;
    m.outerHTML = NXEdgeMenu.menuHtml(nxEdgeState, open === true,
                                      { fn: 'onEdgeMenuOption', id: 'railAbsMenu', cls: 'ecmenu-rail' });
    var more = el('railAbsMore');
    if (more) more.setAttribute('aria-expanded', open === true ? 'true' : 'false');
  }

  function nxCloseEdgeMenu(){
    if (!nxEdgeMenuOpen()) return;
    nxRenderEdgeMenu(false);
  }

  // Klik na rohovu zonu. Bublanie sa zastavuje z toho isteho dovodu ako pri ⚠
  // chipe: okno zatvara KLIK MIMO (delegacia na document), takze klik na roh by
  // ho inak v tom istom kliku otvoril a hned zavrel.
  function onEdgeMenuToggle(ev){
    if (ev && ev.stopPropagation) ev.stopPropagation();
    var more = el('railAbsMore');
    if (more && more.getAttribute('aria-disabled') === 'true') return;
    var open = !nxEdgeMenuOpen();
    // D-27 (review #249 kolo 2): druhe rohove/railove okno musi zhasnut —
    // obe su `position: absolute` nad railom a prekryli by sa.
    if (open) nxCloseTagMenu();
    nxRenderEdgeMenu(open);
    // Aby na obrazovke nikdy neboli DVE kopie tych istych prepinacov: otvorenie
    // tu zavrie rozbalovacie okno v otvorenom ŠTÚDIU (a naopak).
    if (open && window.sketchup && sketchup.nx_edge_menu_open) sketchup.nx_edge_menu_open('');
  }

  // Prepnutie jedneho stavu. Ide TOU ISTOU serverovou cestou ako ŠTÚDIO
  // (Engine.set_edge_check_option): nastavenie zije v %APPDATA%, do modelu sa
  // NEZAPISUJE nic a nevznika krok Spat. Novy stav rozposle server obom oknam.
  function onEdgeMenuOption(key, value){
    if (!window.sketchup || !sketchup.nx_edge_option) return;
    if (!window.NXEdgeMenu) return;
    sketchup.nx_edge_option(JSON.stringify(
      NXEdgeMenu.optionPayload({ model_guid: nxModelGuid }, key, value)));
  }

  // ===== D-27: OKNO VIDITELNOSTI TAGOV MODELU (rail) ========================
  // Tretia funkcna polozka raily. NEMA rohovy trojuholnik — nie je to „toggle
  // + nastavenie" (vzor §5.11), cele tlacidlo otvara okno so zoznamom tagov.
  // Panel si ZIADNY vlastny stav nedrzi: posledny serverovy stav sa pamata LEN
  // preto, aby sa otvorene okno dalo prekreslit (kazdy push ho cely prepise).
  var nxTagState = null;

  function nxTagMenuNode(){ return el('railTagsMenu'); }

  function nxTagMenuOpen(){
    var m = nxTagMenuNode();
    return !!(m && m.classList && m.classList.contains('open'));
  }

  // Jedno miesto, kde sa meni obsah aj viditelnost — `aria-expanded` tak
  // hovori pravdu bez ohladu na to, ktora cesta okno zavrela.
  //
  // Review #249 P3: prekreslenie cez `outerHTML` znici zafokusovany checkbox,
  // takze klavesnicovy pouzivatel po KAZDOM prepnuti z ponuky vypadol. Fokus sa
  // preto pred prekreslenim ZAPAMATA (podla `data-tagkey` riadku) a po nom
  // vrati — bez toho, aby si panel drzal akykolvek stav navyse.
  function nxTagFocusKey(){
    var a = document.activeElement;
    if (!a || !a.getAttribute) return '';
    var m = nxTagMenuNode();
    if (!m || !m.contains(a)) return '';
    return a.getAttribute('data-tagkey') || '';
  }

  function nxRenderTagMenu(open){
    var m = nxTagMenuNode();
    if (!m || !window.NXTagMenu) return;
    var keep = open === true ? nxTagFocusKey() : '';
    m.outerHTML = NXTagMenu.menuHtml(nxTagState, open === true,
                                     { fn: 'onTagOption', id: 'railTagsMenu' });
    var btn = el('railTagy');
    if (btn) btn.setAttribute('aria-expanded', open === true ? 'true' : 'false');
    if (!keep) return;
    var fresh = nxTagMenuNode();
    var back = fresh ? fresh.querySelector('input[data-tagkey="' + keep + '"]') : null;
    if (back){ try { back.focus(); } catch (err) {} }
  }

  function nxCloseTagMenu(){
    if (!nxTagMenuOpen()) return;
    nxRenderTagMenu(false);
  }

  // Klik na ikonu. Bublanie sa zastavuje z rovnakeho dovodu ako pri rohu ABS:
  // okno zatvara KLIK MIMO (delegacia na document), takze klik na tlacidlo by
  // ho inak v tom istom kliku otvoril a hned zavrel.
  // Okno sa otvara VZDY — aj v modeli bez tagov, kde vetou povie, ze vzniknu
  // s prvou skrinkou (review #249 P2: zamknute tlacidlo by to vysvetlenie
  // schovalo do bubliny).
  //
  // Review #249 kolo 2: klik na tlacidlo ZASTAVUJE bublanie (inak by okno
  // zavrel document listener v tom istom kliku), takze rohove nastavenie ABS
  // by pri nom neyzhaslo a DVE prekryte okna by stali nad railom naraz.
  // Zatvara sa preto VYSLOVNE — a recipročne to robi aj roh ABS.
  function onTagMenuToggle(ev){
    if (ev && ev.stopPropagation) ev.stopPropagation();
    var open = !nxTagMenuOpen();
    if (open) nxCloseEdgeMenu();
    nxRenderTagMenu(open);
  }

  // Prepnutie jedneho tagu. Klient posiela LEN identitu + kluc + boolean;
  // whitelist, striktny boolean aj samotny zapis (jedna operacia = jeden krok
  // Späť) rozhoduje server, ktory potom rozposle novy stav.
  function onTagOption(key, value){
    if (!window.sketchup || !sketchup.nx_tag_visible) return;
    if (!window.NXTagMenu) return;
    sketchup.nx_tag_visible(JSON.stringify(
      NXTagMenu.togglePayload({ model_guid: nxModelGuid }, key, value)));
  }

  // Nasadenie serveroveho stavu. JEDEN stav, JEDEN ovladac: ikona raily s oknom
  // tagov (obrysy zon su v nom riadok `zony`, H6a O8) — panel nema vlastnu kopiu.
  function nxApplyTags(st){
    nxTagState = st || null;
    var s = window.NXTagMenu ? NXTagMenu.railState(st) : null;
    var n = el('railTagy');
    if (n && s){
      n.classList.toggle('on', s.on);
      if (window.NXIcons && NXIcons.set) NXIcons.set(n, s.icon);
      var tip = el('railTagyTip');
      if (tip) tip.textContent = s.tip;
    }
    // Otvorene okno drzi ZIVY stav — prekresli ho.
    if (nxTagMenuOpen()) nxRenderTagMenu(true);
  }

  // K2/D-87: to iste pre KONTROLU KRESBY. Rozhodovanie je v CISTEJ funkcii
  // NXShell.grainRail (Node testy) — tu ostava len nasadenie do DOM.
  function nxApplyGrainCheck(st){
    var n = el('railKresba');
    if (!n) return;
    var s = NXShell.grainRail(st);
    n.classList.toggle('on', s.on);
    n.setAttribute('aria-pressed', s.on ? 'true' : 'false');
    n.setAttribute('aria-disabled', s.available ? 'false' : 'true');
    var tip = el('railKresbaTip');
    if (tip) tip.textContent = s.tip;
  }

  // KOV-A2b: to iste pre SMER OTVARANIA. Rozhodovanie je v CISTEJ funkcii
  // NXShell.directionRail (Node testy) — tu ostava len nasadenie do DOM.
  function nxApplyDirectionCheck(st){
    var n = el('railSmer');
    if (!n) return;
    var s = NXShell.directionRail(st);
    n.classList.toggle('on', s.on);
    n.setAttribute('aria-pressed', s.on ? 'true' : 'false');
    n.setAttribute('aria-disabled', s.available ? 'false' : 'true');
    var tip = el('railSmerTip');
    if (tip) tip.textContent = s.tip;
  }
