  // --- zber ---
  // V0.4.7e: ciselne polia sa citaju cez evalDim — surovy vyrazovy string NIKDY
  // neodide do Ruby (to_f/parseFloat by '650-36' ticho orezali na 650).
  function collectConstruction(){
    var out = { type: getType() };
    CONSTRUCTION_FIELDS.forEach(function(f){
      if (f.kind === 'num'){
        var raw = val(f.id);
        if (raw === null || String(raw).trim() === ''){ out[f.id] = ''; return; }
        var v = evalDim(raw);
        out[f.id] = isNaN(v) ? '' : v; // NaN neprejde validaciou; '' = Ruby default
      } else {
        out[f.id] = val(f.id);
      }
    });
    return out;
  }
  function collectFronts(){
    var items = [];
    // D-23: DOM zoznam je OBRATENY (najvyssie celo hore) — citame ODSPODU,
    // aby items[0] = F1 = spodne celo. Datove poradie sa NEMENI, len prezentacia.
    var rows = el('frontRows').querySelectorAll('.frow');
    for (var i = rows.length - 1; i >= 0; i--){
      var r = rows[i];
      // KOV-A2a: typ uz nie je hodnota rozbalovacky, ale STAV RIADKU
      // (`dataset.frontType`) — meni ho dlazdica typegridu v karte cela.
      // Fallback na dvierka je tu len pre poskodeny DOM; `addFrontRow` dataset
      // nastavuje VZDY (rovnaky vzor ako `dataset.frontProfile` z D-90).
      var type = r.dataset.frontType || 'door';
      var hv = r.querySelector('.fh').value.trim();
      var wings = r.querySelector('.fw').value;
      var hasH = hv !== '';
      var hNum = hasH ? evalDim(hv) : NaN; // vyraz vo vyske cela -> cislo (NaN blokuje apply cez validateFields)
      // D-90 (Codex #144 P1): 'profile' este NEMA ovladac (pride v PR 2), ale
      // MUSI prezit round-trip — inak by kazda zmena ineho pola poslala riadok
      // bez profilu a server by ho znormalizoval na 'none' (celo by sa ticho
      // vratilo na plnu vysku a profil by vypadol z kovania).
      // UI-C3: ZAMOK PRI VYSKE ZANIKOL — zamknute ⇔ vypisane. Samostatny
      // checkbox (D-23) sa dal zapnut aj nad prazdnym polom a nerobil nic;
      // teraz je `locked` presne to, co pouzivatel vidi: vypisana hodnota drzi.
      var item = { id: r.dataset.frontId || newStableId('F'), type: type, mode: hasH ? 'fixed' : 'auto',
        height: hasH ? (isNaN(hNum) ? null : hNum) : null, locked: hasH, wings: (type === 'door') ? wings : '1',
        profile: r.dataset.frontProfile || 'none' };
      // KOV-A1: smer otvárania, spôsob otvárania a klasifikácia zásuvky NEMAJÚ
      // v A1 ovládač (ten je A2) — musia však prežiť round-trip, inak by prvá
      // editácia iného poľa poslala riadok bez nich a hodnota by ticho zmizla
      // (vzor D-90 `profile`). ROZDIEL oproti profilu: ŽIADNY default sa
      // nedopĺňa. Kľúč, ktorý v configu nebol, sa tu NESMIE objaviť — inak by
      // legacy zákazka dostala RED nález o neurčenom smere.
      frontExtraApply(item, r);
      items.push(item);
    }
    return { split_axis: 'height', gap: frontGapVal('fr_gap', 3.0), gap_top: frontGapVal('fr_gap_top', 2.0),
             gap_bottom: frontGapVal('fr_gap_bottom', 2.0), gap_sides: frontGapVal('fr_gap_sides', 2.0),
             edge_limit_off: edgeLimitOff, items: items };
  }
  // --- D-22: zamok limitu presahov (okraje +-100 zamknute / +-2000 odomknute) ---
  // Stav zije v JS premennej (nie v DOM triede) — collectFronts ho posiela s configom,
  // renderFronts ho obnovuje z kanonickeho configu pod TYM ISTYM echo-guardom ako
  // gap polia (keepGaps): starsie echo apply nesmie prepisat novsi klik na zamok.
  var edgeLimitOff = false;
  function setEdgeLimitOff(off){
    edgeLimitOff = !!off;
    var b = el('edgeLimitLock');
    if (b){
      // B3: NEprepisovat cely obsah tlacidla textContentom (zmazal by ikonu) —
      // meni sa len symbol v <use> a textovy label; aria-pressed drzi stav (B11).
      if (window.NXIcons) NXIcons.set(b, edgeLimitOff ? 'lock-open' : 'lock');
      var lbl = b.querySelector('.lblLimit');
      if (lbl) lbl.textContent = edgeLimitOff ? '±2000 mm' : '±100 mm';
      b.setAttribute('aria-pressed', edgeLimitOff ? 'false' : 'true'); // pressed = zamknuty limit
      b.classList.toggle('unlocked', edgeLimitOff);
    }
  }
  function toggleEdgeLimit(){
    setEdgeLimitOff(!edgeLimitOff);
    onField(); // apply pre oznaceny korpus + prevalidovanie okrajovych poli
  }
  // D-07: hodnota gap pola cez evalDim (vyrazy); prazdne/nezmysel = default.
  function frontGapVal(id, dflt){ var v = numv(id); return isNaN(v) ? dflt : v; }
  function resetFrontGaps(){ setNum('fr_gap', 3); setNum('fr_gap_top', 2); setNum('fr_gap_bottom', 2); setNum('fr_gap_sides', 2); onField(); }
  function collectAll(){ var c = collectConstruction(); c.fronts = collectFronts(); return c; }

  // --- validacia poli (cerveny okraj, ziadne modaly) ---
  // V0.4.7e: cita cez evalDim (vyraz = hodnota); ROZPISANY vyraz vo fokusovanom
  // poli sa preskoci (ani apply, ani cervene — hint bezi); COMMITNUTY neprazdny
  // nezmysel je PO NOVOM chyba (predtym NaN ticho presiel) a blokuje apply.
  var LIMITS = { width:[200,3000], height:[200,3000], depth:[150,2000], thickness:[6,50],
                 floor_height:[0,500], plinth_recess:[0,300], rail_depth:[20,400], rails_top_offset:[0,500],
                 // D-07: medzery/presahy cel — zaporny okraj = presah cez obrys (limit zhodny s Fronts::EDGE_LIMIT)
                 fr_gap:[0,50], fr_gap_top:[-100,100], fr_gap_bottom:[-100,100], fr_gap_sides:[-100,100] };
  // D-22: okraje cel maju dynamicky limit podla zamku (Fronts::EDGE_LIMIT_UNLOCKED);
  // fr_gap (medzera medzi celami) ostava 0..50 VZDY.
  var EDGE_LIMIT_FIELDS = { fr_gap_top:1, fr_gap_bottom:1, fr_gap_sides:1 };
  function validateFields(){
    var ok = true;
    var ae = document.activeElement;
    for (var id in LIMITS){
      var e = el(id); if (!e) continue;
      if (e === ae && isExprStr(e.value)) continue; // rozpisany vyraz — nechaj tak
      if (e.value === ''){ e.classList.remove('bad'); continue; }
      var v = evalDim(e.value);
      if (isNaN(v)){ e.classList.add('bad'); ok = false; continue; }
      var lo = LIMITS[id][0], hi = LIMITS[id][1];
      if (EDGE_LIMIT_FIELDS[id] && edgeLimitOff){ lo = -2000; hi = 2000; }
      if (v < lo || v > hi){ e.classList.add('bad'); ok = false; } else { e.classList.remove('bad'); }
    }
    // vysky ciel (.fh) — vyraz sa vyhodnoti, committnuty nezmysel blokuje apply
    var fhs = el('frontRows') ? el('frontRows').querySelectorAll('.fh') : [];
    for (var i = 0; i < fhs.length; i++){
      var f = fhs[i];
      if (f === ae && isExprStr(f.value)) continue;
      if (f.value.trim() === ''){ f.classList.remove('bad'); continue; }
      if (isNaN(evalDim(f.value))){ f.classList.add('bad'); ok = false; } else { f.classList.remove('bad'); }
    }
    return ok;
  }

  // fix #2: refresh nahladu BEZ auto-apply. Pouzity pri vybere sablony (sablona = len preview;
  // aplikuje ju vyhradne tlacidlo "Pouzi sablonu na oznaceny", vratane zon zo sablony).
  function refreshPreview(){ validateFields(); renderPreview(); updateAvailable(); }

  // D-02: debounce prekreslenia nahladu pri pisani (500 ms) — kazde pismeno uz
  // netrha 2D nahlad; ostatne cesty (vyber, sablona, zony) kreslia okamzite.
  var previewTimer = null;
  function schedulePreview(){
    if (previewTimer) clearTimeout(previewTimer);
    previewTimer = setTimeout(function(){ previewTimer = null; renderPreview(); }, 500);
  }

  // --- AUTO-APPLY (debounce 400 ms) ---
  // V0.4.7e: rozpisany VYRAZ vo fokusovanom poli nikdy nespusti apply ani nahlad
  // (medzistav '650-3' je validny vyraz s inou hodnotou) — aplikuje az Enter/blur
  // commit, ktory pole prepise cistym cislom a onField zavola znova.
  function onField(){
    invalidateFrontPlaceholders(); // D-23: lokalna zmena -> stare ≈ vysky neplatia (doplni az cerstve echo)
    var ae = document.activeElement;
    if (ae && isExprInput(ae) && isExprStr(ae.value)){
      cancelCabinetEdits(); // R-02: s timerom odchadza aj zachyteny dokument
      ae.classList.remove('bad');
      return; // zivy nahlad "= X" kresli listener v expr.js
    }
    validateFields();
    refreshMaterialFilters();              // FIX 2: hrubka sa mohla zmenit -> prefiltruj material selecty
    schedulePreview();                     // D-02: nahlad sa neprekresluje pri kazdom pismene
    updateAvailable();
    // D-39: edit ZAMKNUTEHO pola vo vkladacej karte aktualizuje hodnotu zamku
    // (zamok drzi to, co pouzivatel vidi). GH P3: NIE cez activeElement — pri
    // expr commite na blur uz fokus odisiel; synchronizuju sa VSETKY zamknute
    // polia z DOM (5 poli, lacne a deterministicke).
    if (!selectedCabId && NXInsert.state.lastMode === 'insert'){
      var changedLock = false;
      NXInsert.lockedFields().forEach(function(fid){
        var fe = el(fid);
        if (!fe) return;
        var lv = evalDim(fe.value);
        if (!isNaN(lv) && NXInsert.updateLockValue(fid, lv)) changedLock = true;
      });
      if (changedLock) pushInsertLocks();
    }
    if (!selectedCabId) return;            // nic oznacene -> len nahlad, ziadny rebuild
    if (applyTimer) clearTimeout(applyTimer);
    var cabSnapshot = selectedCabId;       // Codex expr audit BLOCKER: identita z casu naplanovania
    // R-02 (review #264 P1): s korpusom sa zachytava aj DOKUMENT. `nxModelGuid`
    // je globál, ktorý prepíše najbližší push — bez snapshotu by sa oneskorený
    // zápis opečiatkoval NOVÝM dokumentom a guard by ho pustil do cudzej zákazky.
    // Kolo 2: guid zije aj v MODULOVEJ premennej, lebo rozpisane edity vie
    // odoslat aj OKAMZITY flush (`flushCabinetEditsNow` — Studio, „Vlozit
    // kopiu", „Dielcov", vlastnik kovania). Ten o lokalnu premennu timera
    // nezavadi a bez toho by stare hodnoty opeciatkoval NOVYM dokumentom.
    applyPendingGuid = nxDocGuid();
    applyTimer = setTimeout(function(){ flushCabinetEdits(cabSnapshot, applyPendingGuid); }, 400);
  }

  // Okamzity/odlozeny apply korpusu. Snapshot cabinet_id ide s payloadom — Ruby
  // handler ho overi proti aktualnemu vyberu (oneskoreny zapis po prekliknuti
  // na iny korpus sa ticho zahodi namiesto zasiahnutia nespravneho objektu).
  // `guidSnapshot` = dokument z času NAPLÁNOVANIA (R-02, review #264 P1).
  // `null`/`undefined` = žiadne rozpísané edity, platí aktuálny dokument.
  function flushCabinetEdits(cabSnapshot, guidSnapshot){
    applyTimer = null;
    applyPendingGuid = null;
    var ae = document.activeElement;
    if (ae && isExprInput(ae) && isExprStr(ae.value)) return; // vyraz stale rozpisany
    if (!selectedCabId) return;
    if (!validateFields()) { NX.setStatus('Skontroluj červené polia (mimo rozsahu).', true); return; }
    var payload = collectAll();
    payload.cabinet_id = cabSnapshot || selectedCabId;
    cabEditsInFlight = true; // D-07 Codex B2: echo tohto apply nesmie prepisat novsi vstup
    if (window.sketchup && sketchup.apply_all) sketchup.apply_all(nxDocPayload(payload, guidSnapshot)); // R-02
  }
  // R-02 (review #264 kolo 2): okamzity flush PREBERA zachyteny dokument
  // rozpisanych editov. Predtym len zrusil timer a poslal DNESNYM guidom —
  // po prepnuti dokumentu tak stare hodnoty formulara dostali NOVU identitu
  // a serverovy guard ich pustil do cudzej zakazky.
  function flushCabinetEditsNow(){
    var g = applyPendingGuid;              // null = ziadne rozpisane edity
    cancelCabinetEdits();
    flushCabinetEdits(selectedCabId, g);
  }

  // Zahodenie rozpisanych editov BEZ odoslania. Vola sa aj centralne pri zmene
  // dokumentu (`nxDropDocState` v shell.js) — pending patri starej zakazke.
  //
  // `cabEditsInFlight` sa TU VEDOME NENULUJE (interne review kola 4, P2):
  // tato funkcia bezi aj v JEDNODOKUMENTOVOM flow — pri zrusenom okamzitom
  // flushi (cervene pole zastavi validacia) a pri rozpisanom vyraze v poli.
  // Zhodenim zatvarky by najblizsie echo dostalo `keepGaps = false` a zmazalo
  // by prave pridane celo aj rozpisane gap hodnoty. Pre prepnutie dokumentu je
  // to zbytocne (`sameDoc` v `keepGaps` + bezpodmienecne nulovanie v `bridge.js`
  // to kryju) — zatvarku preto nuluje `nxDropDocState`, ktore bezi VYHRADNE
  // pri realnej zmene dokumentu.
  function cancelCabinetEdits(){
    if (applyTimer){ clearTimeout(applyTimer); applyTimer = null; }
    applyPendingGuid = null;
  }

  function updateAvailable(){
    // pri oznacenom pouzijeme presne z backendu; inak lokalny odhad
    var t = numv('thickness') || 18, w = numv('width') || 0, h = numv('height') || 0, d = numv('depth') || 0;
    // UI-B3: svetle rozmery su TEXT v informacnom stlpci (setOut), nie readonly polia.
    setOut('av_width', Math.max(0, Math.round(w - 2*t)));
    // D-37: svetla hlbka zrkadli interior_dims — hlbka je CELKOVA vratane chrbta:
    // overlay/inset: d - bt; groove: d - 10 - bt; none: d (audit FIX 5 — bez tohto
    // by navrh noveho korpusu ukazoval zlu hodnotu az do prveho rebuildu).
    var bm = val('back_mode'), bt = numv('back_thickness') || 3;
    var ad = d;
    if (bm === 'overlay' || bm === 'inset') ad = d - bt;
    else if (bm === 'groove') ad = d - 10 - bt;
    setOut('av_depth', Math.max(0, Math.round(ad)));
    // D-80: svetla vyska cez JEDINU zdielanu funkciu (core.js nxInteriorZ) —
    // pri two_rails ju urcuje spodna hrana vystuh (odsadenie + orientacia).
    // Vyska/hrubka sa posielaju z uz precitanych poli (prazdne pole = 0 ako predtym).
    var iv = nxInteriorZ(currentCarcass({ height: h, thickness: t }));
    setOut('av_height', Math.max(0, Math.round(iv.availH)));
    // UI-C1b: vo VKLADANI KORPUSU nesu „Dielcov" a „Materiál" ODHAD zo sablony —
    // server dopocet (Panel.cabinet_stats) cita snapshoty uz vlozenej skrinky
    // a builder sa kvoli informacnemu riadku nespusta.
    if (!selectedCabId && NXInsert.state.kind !== 'board') setInsertCabInfo();
  }
  // Codex #175 P2: zmena STROMU ZON v navrhu (delenie, police, vycistenie,
  // rozmery poli) mala vlastnu cestu — renderPreview + refreshZoneUI — takze
  // odhad „≈ Dielcov / ≈ Materiál" ostaval zatuchnuty az do editu ineho pola.
  // Toto je jeho jediny obnovovaci bod mimo updateAvailable.
  function nxDraftChanged(){
    if (selectedCabId || NXInsert.state.kind === 'board') return;
    setInsertCabInfo();
  }
  // Odhad je ZNACENY (≈) a riadky ostavaju neklikatelne (nie je co oznacit v
  // modeli) — vzor D-78: aria-disabled + vysvetlenie, nikdy ticho mrtve.
  function setInsertCabInfo(){
    var st = nxDraftStats(pvGeom(), computeZones(), pvInsertFronts());
    setOut('inf_parts', st.count > 0 ? ('≈ ' + st.count) : '—');
    setOut('inf_area', st.area > 0 ? ('≈ ' + mmLabel(st.area) + ' m²') : '—');
    var pn = el('infParts'), an = el('infArea');
    if (pn) pn.title = 'Odhad počtu výrobných dielcov zo šablóny — presné číslo dá skrinka po vložení';
    if (an) an.title = 'Odhad plochy dosky zo šablóny — presné číslo dá skrinka po vložení';
  }

  // --- defaulty / viditelnost ---
  function setDefaults(t){
    writeConstruction(DEFAULTS[t] || {});
    applyVisibility(t);
  }
  function applyVisibility(t){
    el('plinthGroup').style.display = (t === 'upper') ? 'none' : '';
    el('fhRow').style.display = (t === 'upper') ? 'none' : ''; // D-11: vyska sokla v Zakladnych, horna ju nema
    toggleRecess(); toggleTwoRails(); toggleBackTh(); // D-31: pokryva vyber korpusu, defaulty aj sablonu
  }
  function toggleRecess(){ el('recessRow').style.display = (val('plinth_mode') === 'front') ? '' : 'none'; }
  function toggleTwoRails(){ el('twoRailsGroup').style.display = (val('top_mode') === 'two_rails') ? '' : 'none'; }
  // D-31: Bez chrbta skryje riadok hrubky — HODNOTA selectu sa NEMENI (navrat
  // rezimu ju obnovi; sablony a config ju drzia dalej).
  function toggleBackTh(){ var r = el('backThRow'); if (r) r.style.display = (val('back_mode') === 'none') ? 'none' : ''; }

  // ===== UI-C1b: TYP VKLADANEHO OBJEKTU (tri segmentove tlacidla) ===========
  // Nahradilo dvojicu radiov (kind Korpus/Doska + ctype Dolna/Horna). Autorita
  // je NXInsert (cisty stav), DOM je len jeho zrkadlo — kostra sa neprekresluje.
  function onInsertType(t){
    if (!NXInsert.setInsertType(t)) return; // klik na uz zvoleny typ nic nerobi
    onInsertKindChange();                   // body atribut + material dosky (board_card.js)
    // Novy vyjav = cisty fit (rovnaka zasada ako pri prepnuti kontextu raily):
    // zoom na 600 mm skrinke by na 2600 mm doske mieril mimo.
    pvUserView = false; pvView = null;
    materializeInsertCard();
  }
  function syncInsertTypeButtons(){
    var cur = NXInsert.insertType();
    var btns = document.querySelectorAll('#insertTypeRow button[data-ins-type]');
    for (var i = 0; i < btns.length; i++){
      var on = btns[i].getAttribute('data-ins-type') === cur;
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }

  // ===== UI-C1b: DLAZDICE SABLON (N16 nedavne prve, N17 dvojklik vlozi) =====
  // Mriezka sa PRESTAVUJE len vtedy, ked sa zmenil typ vkladania alebo prisla
  // nova kniznica (push_templates). Vyber sablony mriezku NEPRESTAVUJE — meni
  // sa iba trieda `.on` (Codex FIX 14 + pasca CEF: klik, ktory zahodi uzol,
  // by druhy klik dvojkliku uz nemal na com dokoncit).
  var TPL_RECENT_MAX = 3;
  // Schematicky nahlad sablony — JEDNODUCHA kresba z configu (REALNE PNG nahlady
  // su az UI-D2). Ciste (Node testy): vracia INNER markup SVG bez jedinej farby
  // — obrys aj vypln davaju CSS tokeny (`.tpltile svg` v panel.css), rovnaka
  // zasada ako inde: ziadny hex mimo palety.
  function nxTplGlyph(tp){
    var cfg = (tp && tp.config) || {};
    var box = '<rect x="2" y="2" width="56" height="36"/>';
    if (NXInsert.templateKind(tp) === 'board'){
      // doska: obdlznik s uhlopriecnym naznakom plochy
      return box + '<path d="M8 30 52 10"/>';
    }
    var g = '';
    var items = (cfg.fronts && cfg.fronts.items) ? cfg.fronts.items : [];
    var n = items.length;
    if (n > 1){
      // vodorovne delenie radov ciel (max 4 ciary, nech dlazdica ostane citatelna)
      var lines = Math.min(n - 1, 4);
      for (var i = 1; i <= lines; i++){
        var y = 2 + 36 * i / (lines + 1);
        g += '<path d="M2 ' + y.toFixed(1) + 'h56"/>';
      }
    }
    if (n === 1 && String(items[0] && items[0].wings) === '2'){
      g += '<path d="M30 2v36"/>';
    }
    if (!g){
      // bez ciel: naznac police zo stromu zon (prazdny korpus ostane prazdny)
      var sh = (cfg.zone_tree && parseInt(cfg.zone_tree.shelves, 10)) || 0;
      var s = Math.min(sh, 4);
      for (var k = 1; k <= s; k++){
        var zy = 2 + 36 * k / (s + 1);
        g += '<path d="M6 ' + zy.toFixed(1) + 'h48" stroke-dasharray="3 3"/>';
      }
    }
    return box + g;
  }
  // Popisok pod kresbou: nazov + (pri doske) badge hrubky.
  // Ciste (Node testy) — vracia TEXT, escapuje az volajuci.
  function nxTplBadge(tp){
    if (NXInsert.templateKind(tp) !== 'board') return '';
    var th = tp && tp.config ? parseFloat(tp.config.thickness) : NaN;
    return (isNaN(th) || th <= 0) ? '' : (mmLabel(th) + ' mm');
  }
  // UI-C1c: doskova dlazdica hovori aj o UMIESTNENI. Text ide do TOOLTIPU (nie
  // do popisku pod kresbou) — badge uz nesie hrubku a druhy riadok by dlazdicu
  // predlzil (pravidlo „vertikalny priestor panela je vzacny“).
  // Ciste (Node testy): vracia TEXT, escapuje az volajuci.
  var TPL_ORI_LABELS = { leziaca: 'naležato', stojaca: 'nastojato', na_stenu: 'na stenu' };
  function nxTplOrientationNote(tp){
    if (NXInsert.templateKind(tp) !== 'board') return '';
    var o = tp && tp.config ? tp.config.orientation : null;
    return TPL_ORI_LABELS[o] || '';
  }
  function nxTplTitle(tp){
    var note = nxTplOrientationNote(tp);
    return tp.name + (note ? ' · ' + note : '') + ' — klik = vybrať · dvojklik = vlož hneď';
  }
  // UI-D2: KLUC nahladu v cache. Nahlad je viazany na TROJICU (druh, nazov,
  // revizia suboru) — po prepise sablony sa `rev` zmeni a stary obrazok sa uz
  // nikdy netrafi. Oddelovac je NUL — v nazve sablony sa vyskytnut nemoze.
  // Pise sa VYHRADNE ako escape `\u0000` (Codex #181 P2): surovy NUL bajt
  // v zdrojaku by z form.js spravil pre rg/grep BINARNY subor a buduce
  // hladanie handlerov ci regresii by ho ticho preskocilo.
  var TPL_PREV_SEP = '\u0000';
  function tplPrevKey(kind, name, rev){
    return String(kind || '') + TPL_PREV_SEP + String(name || '') + TPL_PREV_SEP + String(rev || '');
  }
  // Cache odpovedi servera: kluc -> data URI, alebo '' = „server nahlad nema"
  // (zaporna odpoved sa cachuje TIEZ, inak by sa panel pytal donekonecna).
  var TPL_PREVIEWS = {};
  // Kluce, na ktore uz odisla ziadost — pull ide na kazdu reviziu PRESNE RAZ.
  var TPL_PREV_ASKED = {};
  // UI-D2: dlazdica ma PNG aj schemu v TOM ISTOM boxe — vyska sa nemeni ani
  // ked nahlad chyba, prichadza neskoro alebo sa nepodari nacitat (pravidlo
  // „vertikalny priestor panela je vzacny"). `<img>` sa NIKDY nevytvara ani
  // neodstranuje dodatocne: je v dlazdici od zaciatku, len bez `src`. Vymena
  // uzla by uprostred dvojkliku odpojila ciel udalosti (pasca CEF, FIX 14).
  function tplPicHtml(tp){
    return '<span class="tplpic"><img alt="" aria-hidden="true">' +
      '<svg viewBox="0 0 60 40" aria-hidden="true">' + nxTplGlyph(tp) + '</svg></span>';
  }
  // SMOKE PACK 1 (6A) — POZNAMKA, PRECO TU KAMERA NIE JE:
  // Zadanie chcelo ikonu „Odfotiť náhľad z označenej skrinky" na vybranej
  // dlazdici. Dlazdice ziju vo VKLADACEJ karte, ktora sa ukazuje VYHRADNE
  // vtedy, ked nie je oznacene NIC (`clearSelected` -> `setUiMode('insert')`,
  // `body.mode-cab #insertCard { display: none }`). Kamera by tam teda nemala
  // ako najst oznacenu skrinku a bola by to trvalo mrtva ikona (presny opak
  // pravidla „klikatelne je len to, co niekam vedie"). Akcia preto zije v okne
  // Sablony (sekcia `tpl` Studia, `js/templates.js`), kde vyber v modeli a zoznam sablon
  // existuju SUCASNE — a foti sa TOU ISTOU cestou (TemplatePreviews.capture).
  function tplTileHtml(tp, sel){
    var badge = nxTplBadge(tp);
    var rev = (tp && tp.preview_rev) ? String(tp.preview_rev) : '';
    return '<button type="button" class="tpltile' + (tp.name === sel ? ' on' : '') + '"' +
      ' data-tpl-name="' + esc(tp.name) + '"' +
      ' data-tpl-kind="' + esc(NXInsert.templateKind(tp)) + '"' +
      ' data-tpl-rev="' + esc(rev) + '" title="' + esc(nxTplTitle(tp)) + '">' +
      tplPicHtml(tp) +
      '<span>' + esc(tp.name) + (badge ? ' <i>· ' + esc(badge) + '</i>' : '') + '</span></button>';
  }
  // Nasadenie data URI na jednu dlazdicu. `onload` az potom odkryje obrazok —
  // `onerror` ho necha skryty, takze zostane vidiet SCHEMA (nikdy prazdny box).
  function tplBindPreview(tile, png){
    var pic = tile.querySelector('.tplpic');
    var img = pic ? pic.querySelector('img') : null;
    if (!img || !png) return;
    if (img.getAttribute('src') === png) return;
    img.onload = function(){ pic.classList.add('has'); };
    img.onerror = function(){ pic.classList.remove('has'); img.removeAttribute('src'); };
    img.src = png;
  }
  // CISTE JADRO rozhodovania (Node testy): pre zoznam popisov dlazdic
  // `{ kind, name, rev }` povie, ktorym sa da nasadit uz znamy obrazok a na
  // ktore treba poslat ziadost. Pravidla:
  //   * dlazdica bez `rev` = sablona nahlad NEMA -> nic (ani ziadost),
  //   * cache '' = server uz povedal „nemam" -> ziadna dalsia ziadost,
  //   * `asked` sa PLNI TU, takze na jednu reviziu odide ziadost PRESNE RAZ
  //     (opakovana prestavba mriezky most nezahlti).
  function nxTplPreviewPlan(descs, cache, asked){
    var out = { apply: [], ask: [] };
    (descs || []).forEach(function(d){
      if (!d || !d.rev || !d.name) return;
      var k = tplPrevKey(d.kind, d.name, d.rev);
      var hit = Object.prototype.hasOwnProperty.call(cache, k) ? cache[k] : null;
      if (hit){ out.apply.push({ desc: d, png: hit }); return; }
      if (hit === '') return;                       // zaporna odpoved je tiez odpoved
      if (asked[k]) return;
      asked[k] = true;
      out.ask.push(d);
    });
    return out;
  }
  // CISTE JADRO odpovede servera: zapise ju do cache (aj ZAPORNU — inak by sa
  // panel pytal donekonecna) a vrati normalizovany popis, alebo null pri
  // nepouzitelnom payloade. Nasadenie na DOM robi az volajuci.
  function nxTplPreviewStore(cache, data){
    var d = data || {};
    var kind = String(d.kind || '');
    var name = String(d.name || '');
    var rev = String(d.rev || '');
    if (!name || !rev) return null;
    var png = d.png ? String(d.png) : '';
    cache[tplPrevKey(kind, name, rev)] = png;
    return { kind: kind, name: name, rev: rev, png: png };
  }
  // Popisy dlazdic z DOM (jediny bod, kde sa cita mriezka).
  function tplTileDescs(){
    var box = el('tplTiles'); if (!box) return [];
    var tiles = box.querySelectorAll('.tpltile[data-tpl-rev]');
    var out = [];
    for (var i = 0; i < tiles.length; i++){
      var t = tiles[i];
      out.push({ kind: t.getAttribute('data-tpl-kind') || '',
                 name: t.getAttribute('data-tpl-name') || '',
                 rev: t.getAttribute('data-tpl-rev') || '', node: t });
    }
    return out;
  }
  // Po kazdej prestavbe mriezky: dlazdicam s uz znamym nahladom ho nasadi,
  // za zvysok posle PULL (raz na reviziu).
  function refreshTemplatePreviews(){
    // Bez mosta do Ruby sa do `TPL_PREV_ASKED` NESMIE nic zapisat — zaznam je
    // jednosmerny, takze by revizia ostala navzdy „vypytana" a nikdy by o nu
    // ziadost neodisla. Vtedy sa planuje nad odhodenou mapou (len nasadenie
    // uz znamych obrazkov) a pri dalsej prestavbe mriezky sa pyta znova.
    var canAsk = !!(window.sketchup && sketchup.nx_template_preview);
    var plan = nxTplPreviewPlan(tplTileDescs(), TPL_PREVIEWS, canAsk ? TPL_PREV_ASKED : {});
    plan.apply.forEach(function(a){ tplBindPreview(a.desc.node, a.png); });
    if (!canAsk) return;
    plan.ask.forEach(function(d){
      sketchup.nx_template_preview(JSON.stringify({ kind: d.kind, name: d.name, rev: d.rev }));
    });
  }
  // Odpoved servera (NX.setTemplatePreview). Nasadi sa LEN na dlazdice s TOU
  // ISTOU reviziou — medzitym mohla prist nova kniznica a stary obrazok by
  // prekryl novy tvar.
  function applyTemplatePreview(data){
    var hit = nxTplPreviewStore(TPL_PREVIEWS, data);
    if (!hit || !hit.png) return;
    tplTileDescs().forEach(function(d){
      if (d.name === hit.name && d.kind === hit.kind && d.rev === hit.rev) tplBindPreview(d.node, hit.png);
    });
  }
  // Codex #175 P2: CESTA SPAT NA PREDVOLBY. Klik na uz vybranu dlazdicu je no-op
  // (dvojklik posiela dva kliky za sebou), takze bez tejto dlazdice by sa vyber
  // sablony nedal zrusit — najma pri doske, ktora si ho drzi aj cez prepnutie
  // typu. Je to nahrada za zaniknutu volbu „— vyber —" v selecte.
  function tplClearTileHtml(sel){
    return '<button type="button" class="tpltile tplclear' + (sel ? '' : ' on') + '"' +
      ' data-tpl-clear="1" title="Bez šablóny — vráti predvolené hodnoty tohto typu">' +
      '<svg viewBox="0 0 60 40" aria-hidden="true">' +
      '<rect x="2" y="2" width="56" height="36" stroke-dasharray="4 3"/></svg>' +
      '<span>Bez šablóny</span></button>';
  }
  function renderTemplateTiles(force){
    var box = el('tplTiles'); if (!box) return;
    var type = NXInsert.insertType();
    var kind = (type === 'board') ? 'board' : 'cabinet';
    var sel = NXInsert.templateName(kind);
    // Prestavba LEN pri zmene typu / novej kniznici; inak staci prepnut triedy.
    if (!force && box.dataset.forType === type){ syncTemplateTiles(); return; }
    var groups = NXInsert.templateGroups(TEMPLATES, type, TPL_RECENT_MAX);
    var h = '';
    if (groups.recent.length){
      h += '<div class="tplsec">Naposledy použité</div><div class="tpltiles">';
      groups.recent.forEach(function(tp){ h += tplTileHtml(tp, sel); });
      h += '</div><div class="tplsec">Všetky šablóny</div>';
    }
    // „Bez šablóny" stoji ako PRVA dlazdica skupiny „Všetky šablóny" — je to
    // rovnocenna volba (predvolby typu), nie skryta akcia.
    h += '<div class="tpltiles">' + tplClearTileHtml(sel);
    groups.all.forEach(function(tp){ h += tplTileHtml(tp, sel); });
    h += '</div>';
    if (!groups.all.length){
      h += '<div class="tplempty">Zatiaľ žiadna šablóna tohto typu — ulož si ju z hotovej skrinky.</div>';
    }
    box.dataset.forType = type;
    box.innerHTML = h;
    refreshTemplatePreviews(); // UI-D2: znamy nahlad hned, za zvysok pull
    setTplMeta();
  }
  // Prepnutie vybranej dlazdice BEZ prestavby mriezky (ten isty nazov moze byt
  // v oboch skupinach — „naposledy použité" aj „všetky", preto sa prechadzaju
  // VSETKY dlazdice).
  function syncTemplateTiles(){
    var box = el('tplTiles'); if (!box) return;
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    var sel = NXInsert.templateName(kind);
    var tiles = box.querySelectorAll('.tpltile');
    for (var i = 0; i < tiles.length; i++){
      var on = tiles[i].hasAttribute('data-tpl-clear')
        ? !sel                                                   // „Bez šablóny"
        : (tiles[i].getAttribute('data-tpl-name') === sel);
      tiles[i].classList.toggle('on', on);
    }
    setTplMeta();
  }
  function setTplMeta(){
    var m = el('insTplMeta'); if (!m) return;
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    m.textContent = NXInsert.templateName(kind) || 'bez šablóny';
  }
  // Vyber sablony = zapis do insert STAVU + plna materializacia karty (D-33:
  // konstrukcia + cela + medzery + zamok presahov + zony + MATERIALY — audit F6).
  // Klik na UZ vybranu dlazdicu je NO-OP (nie odznacenie): dvojklik posiela dva
  // kliky za sebou a odznacenie by medzi nimi kartu vratilo na defaulty typu.
  // fix #2 plati dalej: ziadny apply_all, sablona meni len navrh karty.
  // `name` = '' (dlazdica „Bez šablóny") vracia kartu na PREDVOLBY typu.
  function pickTemplateTile(name){
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    var next = (name === undefined || name === null) ? '' : String(name);
    if (NXInsert.templateName(kind) === next) return;
    NXInsert.setTemplateName(kind, next);
    materializeInsertCard();
  }
  // JEDNA delegacia na kontajneri (Codex FIX 14): dlazdice sa prekresluju, ale
  // listener zije na statickom #tplTiles. Dvojklik vklada TOU ISTOU validovanou
  // cestou ako zelene tlacidlo (ziadne priame volanie bridgu odtialto — N17).
  // Meno sablony z dlazdice; dlazdica „Bez šablóny" vracia prazdny retazec.
  function tplTileName(node){
    return node.hasAttribute('data-tpl-clear') ? '' : (node.getAttribute('data-tpl-name') || '');
  }
  var tplTilesBound = false;
  function setupTemplateTiles(){
    if (tplTilesBound) return;
    var box = el('tplTiles'); if (!box) return;
    box.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'tpltile'); if (!t) return;
      pickTemplateTile(tplTileName(t));
    });
    box.addEventListener('dblclick', function(ev){
      var t = closestClass(ev.target, 'tpltile'); if (!t) return;
      // N17: klik uz sablonu vybral a karta sa z nej materializovala — dvojklik
      // len spusti TO ISTE vlozenie ako zelene tlacidlo (validacia, zamky aj
      // peciatka pouzitia ostavaju v jednej ceste). Na dlazdici „Bez šablóny"
      // vlozi predvolby typu — tiez tou istou cestou.
      pickTemplateTile(tplTileName(t));
      if (NXInsert.insertType() === 'board') insertBoard(); else insertCabinet();
    });
    tplTilesBound = true;
  }
  // (saveTemplate/deleteTemplate/applyTemplateToSelected sa V0.4.5 D2 presunuli
  //  do sekcie Sablony Studia — js/templates.js; panel drzi len quick-pick vyber.)

  // ===== D-32/D-33/D-39: materializacia vkladacej karty z insert STAVU =====
  // Jedina cesta, ktorou sa vkladacia karta plni (reset pri prechode do insert,
  // zmena typu, vyber sablony). Poradie krokov = audit F7:
  //   1) CELY zdroj naraz: defaulty typu + sablona NAD nimi (konstrukcia, cela
  //      s medzerami a zamkom presahov, strom zon, materialy) — ziadne zvysky
  //      naposledy oznacenej skrinky (D-32),
  //   2) zamknute hodnoty prebiju zdroj (D-39),
  //   3) viditelnost + validacia + nahlad.
  function findTemplateFor(name, type){
    // UI-C1a: rovnomenna doskova sablona NIE JE tato (identita je kind+name).
    var tp = NXInsert.findTemplate(TEMPLATES, 'cabinet', name);
    return (tp && NXInsert.templateType(tp) === type) ? tp : null;
  }
  // Cela zdroja: objekt s items = sablonove cela; inak null (defaulty maju
  // legacy string 'none' -> prazdny zoznam + predvolene medzery 3/2/2/2).
  function insertFrontsOf(src){
    var f = src && src.fronts;
    return (f && typeof f === 'object' && f.items) ? f : null;
  }
  function materializeInsertCard(){
    var st = NXInsert.state;
    syncInsertTypeButtons();
    renderTemplateTiles();  // prestavba len pri zmene typu; inak sa prepnu triedy
    if (st.kind === 'board'){
      materializeInsertBoardCard();
      renderInsertLocks();
      if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
      return;
    }
    materializeInsertCabCard();
  }
  // UI-C1b: doskova vetva vkladacej karty (rozmery + material + hrubka + smer).
  // Detail (kontrakt hrubky, UNI material, zamky) zije v board_card.js — tu je
  // len poradie krokov, aby bola cesta rovnaka ako pri korpuse.
  function materializeInsertBoardCard(){
    var name = NXInsert.templateName('board');
    var tp = NXInsert.findTemplate(TEMPLATES, 'board', name);
    if (!tp && name) NXInsert.setTemplateName('board', ''); // zmazana sablona -> defaulty karty
    // UI-C1c (Codex FIX 8): orientacia sa nastavuje EXPLICITNE pri KAZDEJ
    // materializacii — aj bez sablony a pri sablone bez pola (vtedy 'leziaca').
    // Preto stoji PRED applyBoardTemplate a nie je podmienena existenciou tp.
    NXInsert.setBoardOrientation(NXInsert.orientationOf(tp ? tp.config : null));
    syncInsertOrientation();
    if (tp) applyBoardTemplate(tp.config || {});
    applyInsertLockValues('board');       // krok 2: zamky prebiju sablonu (D-39)
    refreshInsertBoardInfo();
    syncTemplateTiles();
    renderPreview();
  }
  function materializeInsertCabCard(){
    var st = NXInsert.state;
    var tp = findTemplateFor(st.template, st.type);
    if (!tp && st.template) st.template = ''; // zmazana/inotypova sablona -> defaulty
    setType(st.type);
    syncTemplateTiles();
    var src = NXInsert.composeSource(DEFAULTS[st.type] || {}, tp ? tp.config : null);
    writeConstruction(src);                  // krok 1: konstrukcia (plny obraz)
    buildFrontHwBadges([]);                  // navrh nema kovanie (Codex PR #30)
    frontItems = null;                       // ani resolved ≈ vysky
    // KOV-A2a: NAVRH nemá resolved čelá, takže server nevie povedať, kde sa
    // smer pýta — sloty sú preto prázdne a karta smerový riadok nekreslí.
    // Odvodiť si ho z počtu krídel by znamenalo druhú pravdu (pasca FIX 11).
    frontSlots = null;
    renderFronts(insertFrontsOf(src));       //         cela + medzery + edge_limit_off
    currentZoneTree = src.zone_tree ? sanitizeTree(src.zone_tree) : defaultTree();
    activeZoneId = null;
    NXInsert.setMaterials(src);              //         materialy zo sablony (F6)
    NXInsert.setHardware(src);               //         sety kovania zo sablony (H2/D-76)
    applyInsertLockValues();                 // krok 2: zamky prebiju zdroj
    renderInsertLocks();
    applyVisibility(st.type);                // krok 3: viditelnost + validacia + nahlad
    refreshMaterialFilters();
    validateFields();
    updateAvailable();
    renderPreview();
    refreshZoneUI();
    // Codex #173 P2: karta sa prave PROGRAMOVO prepisala (rozmery zo sablony,
    // viditelnost sokla podla typu) — ziadne `input`/`change` sa nevystreli,
    // takze meta listy sektorov treba obnovit vyslovne.
    if (typeof nxSectorMetaApply === 'function') nxSectorMetaApply();
  }

  // --- D-39: zamky poli vkladacej karty (sirka/vyska/hlbka/hrubka/sokel) ---
  // Ikony 🔒 ziju v EXISTUJUCICH riadkoch poli (.inslock, CSS ich mimo
  // mode-insert skryva); stav drzi NXInsert a zrkadli sa do Ruby pamate
  // Panel modulu (audit B5 — prezije zatvorenie panela, zomrie s restartom SU).
  // UI-C1b: pole zamku -> ID inputu. Korpusove kluce SU ID poli; doskove maju
  // prefix `ib_` (vkladacia doska) — mapovanie zije LEN tu.
  function insertLockElId(field, scope){ return (scope === 'board') ? ('ib_' + field) : field; }
  function applyInsertLockValues(scope){
    var flat = NXInsert.locksFlat(scope);
    for (var f in flat){
      if (Object.prototype.hasOwnProperty.call(flat, f)) setNum(insertLockElId(f, scope), flat[f]);
    }
  }
  function renderInsertLocks(){
    var btns = document.querySelectorAll('.inslock');
    for (var i = 0; i < btns.length; i++){
      var f = btns[i].getAttribute('data-lock');
      var scope = btns[i].getAttribute('data-lock-scope') || 'cabinet';
      var on = NXInsert.isLocked(f, scope);
      // B3: meni sa len symbol v <use>, nie textContent celeho tlacidla (zmazal by SVG).
      if (window.NXIcons) NXIcons.set(btns[i], on ? 'lock' : 'lock-open');
      btns[i].classList.toggle('on', on);
      btns[i].setAttribute('aria-pressed', on ? 'true' : 'false'); // B11
      btns[i].title = on
        ? 'Hodnota je zamknutá — prežije výber šablóny aj reset karty. Klik odomkne.'
        : 'Zamknúť hodnotu pre ďalšie vklady (prežije výber šablóny aj reset karty).';
    }
  }
  function toggleInsertLock(field, scope){
    if (NXInsert.isLocked(field, scope)){
      NXInsert.clearLock(field, scope);
    } else {
      var v = evalDim(val(insertLockElId(field, scope)));
      if (isNaN(v)){ NX.setStatus('Zamknúť sa dá len platná hodnota (mm).', true); return; }
      // (hodnota sa nastavi v NXInsert.setLock nizsie)
      NXInsert.setLock(field, v, scope);
    }
    renderInsertLocks();
    // Doskove zamky su LEN v UI — server o nich nevie (vlastne kluce length/width,
    // whitelist Panel::INSERT_LOCK_FIELDS je korpusovy). Posiela sa preto len
    // korpusova sada; doskovy zamok zomrie so zatvorenim panela.
    if (scope !== 'board') pushInsertLocksNow(); // GH P3: klik na zamok = okamzity zapis do Ruby
  }
  // Edit rozmeru vkladanej DOSKY: zamok drzi to, co pouzivatel vidi (rovnaka
  // zasada ako D-39 pri korpuse v onField), plus zive info a nahlad.
  function onInsertBoardField(){
    NXInsert.lockedFields('board').forEach(function(f){
      var v = evalDim(val(insertLockElId(f, 'board')));
      if (!isNaN(v)) NXInsert.updateLockValue(f, v, 'board');
    });
    refreshInsertBoardInfo();
    schedulePreview();
  }
  var insertLocksTimer = null;
  function pushInsertLocksNow(){
    if (insertLocksTimer){ clearTimeout(insertLocksTimer); insertLocksTimer = null; }
    if (window.sketchup && sketchup.set_insert_locks)
      sketchup.set_insert_locks(JSON.stringify({ locks: NXInsert.locksFlat() }));
  }
  function pushInsertLocks(){
    if (insertLocksTimer) clearTimeout(insertLocksTimer);
    insertLocksTimer = setTimeout(function(){
      insertLocksTimer = null;
      pushInsertLocksNow();
    }, 200);
  }

  // --- D-41 C2: modal "chyba ABS paska" (vzor D-15) ---------------------------
  // Otvara sa PRED odoslanim zmeny materialu/bulk olepu, ked absUsableExists
  // nenajde pouzitelny 1,0 mm variant. Rozhodnutie vola POVODNY callback s
  // flagom create_missing_abs — server vsetko overi znova (JS sa neveri).
  var absModalPending = null; // {send: fn(createBool), revert: fn()|null}
  function openAbsModal(text, send, revert){
    var m = el('absModal'); if (!m){ send(false); return; }
    absModalPending = { send: send, revert: revert };
    el('absModalText').textContent = text;
    m.style.display = 'flex';
  }
  function absModalChoose(choice){
    var p = absModalPending;
    absModalCloseSilent();
    if (!p) return;
    if (choice === 'create') p.send(true);
    else if (choice === 'without') p.send(false);
    else if (p.revert) p.revert();
  }
  // Tiche zatvorenie BEZ akcie — vola sa aj pri zmene vyberu (bridge), aby
  // oneskorene rozhodnutie nezasiahlo inu kartu.
  function absModalCloseSilent(){
    absModalPending = null;
    var m = el('absModal'); if (m) m.style.display = 'none';
  }

  // --- D-14: ulozit oznaceny korpus ako sablonu (in-panel modal, vzor D-15) ---
  // Input NIE JE vyrazove pole (ziadny onField/attachExprField — Codex F6);
  // Enter uklada, Esc zatvara, Tab ostava v modale (focus trap).
  var tplModalBound = false;
  var tplModalCabId = null; // Codex GH #46 P2: identita ZACHYTENA pri otvoreni modalu
  // Codex audit BLOCKER 2 (UI-B3): identita skrinky NESTACI — ID sa naprie
  // dokumentmi opakuju (CAB-001 je v kazdom modeli), takze modal otvoreny nad
  // jednym dokumentom by po prepnuti ulozil skrinku z ineho. Zachytava sa aj
  // DOKUMENT a server ho striktne overuje (vzor clear_selection / kamera).
  var tplModalGuid = null;
  // Je otvoreny modal uz „o inej skrinke"? (zmena ID ALEBO dokumentu)
  function tplModalStale(c){
    if (!tplModalCabId) return false;
    var p = c || {};
    return (p.cabinet_id !== tplModalCabId) || (String(p.model_guid || '') !== String(tplModalGuid || ''));
  }
  function openSaveTemplateModal(){
    if (!selectedCabId){ NX.setStatus('Najprv označ korpus.', true); return; }
    var m = el('tplModal'); if (!m) return;
    tplModalCabId = selectedCabId;
    tplModalGuid = (typeof nxModelGuid === 'string') ? nxModelGuid : '';
    el('tplSaveName').value = (typeof tplNameSuggestion === 'string' && tplNameSuggestion) ? tplNameSuggestion : '';
    // UI-B3: typ sa predvyplni z TYPU OZNACENEJ SKRINKY (radio vo vkladacej
    // karte je pri oznacenom korpuse zrkadlom jeho typu — setType v loadSelected).
    setVal('tplSaveType', getType());
    m.style.display = 'flex';
    refreshTplModalWarn();
    bindTplModal();
    var inp = el('tplSaveName'); inp.focus(); inp.select();
  }
  function closeSaveTemplateModal(){
    var m = el('tplModal'); if (m) m.style.display = 'none';
  }
  function tplModalOpen(){ var m = el('tplModal'); return !!(m && m.style.display !== 'none'); }
  // Kolizia nazvu: VSETKY KORPUSOVE sablony (nie typovy filter selectu), trim,
  // case-sensitive presne ako Ruby store (Codex N8). Vola sa aj z NX.setTemplates,
  // aby varovanie zilo pri zmene kniznice pocas otvoreneho modalu (Codex F3).
  // UI-C1a: doskova sablona rovnakeho mena kolizia NIE JE — identita v sklade
  // je dvojica (kind, name) a modal uklada vzdy korpusovu.
  function refreshTplModalWarn(){
    if (!tplModalOpen()) return;
    var name = el('tplSaveName').value.trim();
    var exists = TEMPLATES.some(function(t){
      return NXInsert.templateKind(t) === 'cabinet' && t.name === name;
    });
    el('tplSaveWarn').style.display = exists ? '' : 'none';
  }
  function saveTemplateAs(){
    var inp = el('tplSaveName');
    var name = inp.value.trim();
    if (!name){ inp.classList.add('bad'); inp.focus(); return; }
    inp.classList.remove('bad');
    // Codex audit FIX 3 (UI-B3): flush pri NEPLATNYCH poliach edity ticho
    // NEaplikuje — sablona by sa ulozila zo starych hodnot a este by ohlasila
    // uspech. Ukladanie preto stoji, kym cervene pole neopravis (modal ostava
    // otvoreny; vzor „Vložiť kópiu").
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — šablóna by sa uložila zo starých hodnôt.', true);
      return;
    }
    // Codex GH #46 P2: rozpisane edity (400 ms debounce) najprv flushnut — callbacky
    // sa spracuju v poradi, takze apply_all prebehne PRED save a config je cerstvy.
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (window.sketchup && sketchup.save_template_as){
      // identita z casu OTVORENIA modalu — preklik na inu skrinku ANI iny
      // dokument server neprepusti; UI-B3: typ urcuje, pod ktorym typom sa
      // sablona ponuka (whitelist v Ruby)
      sketchup.save_template_as(JSON.stringify({ name: name, cabinet_id: tplModalCabId || selectedCabId,
                                                 model_guid: tplModalGuid || '',
                                                 type: val('tplSaveType') || getType() }));
    }
    closeSaveTemplateModal();
  }
  function bindTplModal(){
    if (tplModalBound) return; tplModalBound = true;
    var m = el('tplModal');
    el('tplSaveName').addEventListener('input', function(){ this.classList.remove('bad'); refreshTplModalWarn(); });
    m.addEventListener('keydown', function(ev){
      if (ev.key === 'Escape'){ ev.preventDefault(); closeSaveTemplateModal(); return; }
      if (ev.key === 'Enter'){ ev.preventDefault(); saveTemplateAs(); return; }
      if (ev.key === 'Tab'){
        var f = m.querySelectorAll('input, button');
        if (!f.length) return;
        var first = f[0], last = f[f.length - 1];
        if (ev.shiftKey && document.activeElement === first){ ev.preventDefault(); last.focus(); }
        else if (!ev.shiftKey && document.activeElement === last){ ev.preventDefault(); first.focus(); }
      }
    });
    // klik na tmave pozadie = zrusit (klik v karte nie)
    m.addEventListener('mousedown', function(ev){ if (ev.target === m) closeSaveTemplateModal(); });
  }

  // --- cela riadky ---
  // D-23: zoznam je OBRATENY oproti datam — data items[0]=F1=SPODNE celo, zoznam
  // zobrazuje skrinku pred sebou (najvyssie celo hore). Kontrakt cyklu:
  // data [F1,F2,F3] -> DOM [F3,F2,F1] -> collectFronts [F1,F2,F3]; po pridani
  // [F1,F2,F3,X]. Render ide datovo odspodu a KAZDY novy riadok PREDRADI navrch;
  // pouzivatelske "+ riadok" prida datovo NA KONIEC = tiez DOM navrch — obe cesty
  // maju jedinu vkladaciu operaciu (insertBefore firstChild).
  // .fnum je kanonicka pozicia v DATACH (F1 dole) — sync bezi VYHRADNE cez
  // dataset.frontId; cislo sa NIKDY neparsuje z ID a ID sa pri precislovani neprepisuje.
  // UI-C3 (N27): IKONA TYPU CELA. Mapa je JEDINE miesto, kde typ -> symbol;
  // ikona je odpoved na „co to je" skor, nez sa oko dostane k textu.
  // KOV-A2a: vyklop, sklop a blenda uz maju VLASTNE symboly v sprite
  // (`front-lift` / `front-fall` / `front-blind`) — do A1 mali fallback `front`.
  // Ta ista mapa kresli aj DLAZDICE typegridu v karte cela.
  var FRONT_TYPE_ICON = { door: 'door', drawer_front: 'rows-2', none: 'front',
                          lift: 'front-lift', fall: 'front-fall', blind: 'front-blind' };
  var FRONT_TYPE_LABEL = { door: 'Dvierka', drawer_front: 'Zásuvkové čelo', none: 'Bez čela',
                           lift: 'Výklop', fall: 'Sklop', blind: 'Blenda' };
  // KOV-A2a: KRATKY popis pre dlazdicu typegridu — sest dlazdic v jednom rade
  // ma pri 470 px asi 50 px, takze „Zásuvkové čelo" by sa len orezalo. Plny
  // nazov nesie `title` dlazdice (a riadok nad kartou ho pise cely).
  var FRONT_TYPE_TILE = { door: 'Dvierka', drawer_front: 'Zásuvka', none: 'Bez čela',
                          lift: 'Výklop', fall: 'Sklop', blind: 'Blenda' };

  // --- KOV-A1: PASS-THROUGH polí, ktoré A1 ešte needituje --------------------
  // `direction` · `wing_directions` · `opening_mode` · `drawer` žijú v datasete
  // riadku a `collectFronts` ich posiela naspäť NEZMENENÉ. Ovládače prídu v A2.
  // ŽELEZNÉ PRAVIDLO: kľúč, ktorý config nemá, sa tu NIKDY nevyrobí — žiadny
  // `||` fallback na neurčený stav, na klasické otváranie ani na stranu pántov.
  // (Guard v tests/pure/test_kova1_cela.rb stráži aj tento súbor, preto tu
  // taký literál nesmie stáť ani v komentári.)
  var FRONT_EXTRA_KEYS = ['direction', 'wing_directions', 'opening_mode', 'drawer'];
  function frontExtraStore(row, item){
    var out = {}, n = 0;
    for (var i = 0; i < FRONT_EXTRA_KEYS.length; i++){
      var k = FRONT_EXTRA_KEYS[i];
      if (item[k] === undefined || item[k] === null) continue;
      out[k] = item[k]; n++;
    }
    // Prázdny dataset sa NENASTAVUJE (legacy riadok nesmie niesť ani prázdny
    // objekt — `collectFronts` by z neho aj tak nič nevrátil, ale rozdiel medzi
    // „nemá" a „má prázdne" má ostať čitateľný aj v DOM).
    if (n) row.dataset.frontExtra = JSON.stringify(out);
  }
  function frontExtraApply(item, row){
    var raw = row.dataset.frontExtra;
    if (!raw) return;
    var obj;
    try { obj = JSON.parse(raw); } catch (e) { return; } // poškodený dataset = akoby tam nebol
    if (!obj || typeof obj !== 'object') return;
    for (var i = 0; i < FRONT_EXTRA_KEYS.length; i++){
      var k = FRONT_EXTRA_KEYS[i];
      if (obj[k] === undefined || obj[k] === null) continue;
      item[k] = obj[k];
    }
  }
  // KOV-A2a: CITANIE a ZAPIS dormant polí riadku. Sú to tie isté dáta, ktoré
  // A1 iba prenášala — karta ich teraz aj mení, ale VÝHRADNE cez čisté funkcie
  // z `core.js` (jediný klientsky výrobca stavu „neurčené"). Prázdny objekt sa
  // z datasetu ODSTRÁNI, aby riadok bez kľúčov ostal riadkom bez kľúčov.
  function frontExtraOf(row){
    var out = {};
    frontExtraApply(out, row);
    return out;
  }
  function frontExtraSet(row, extra){
    var out = {}, n = 0;
    for (var i = 0; i < FRONT_EXTRA_KEYS.length; i++){
      var k = FRONT_EXTRA_KEYS[i];
      if (!extra || extra[k] === undefined || extra[k] === null) continue;
      out[k] = extra[k]; n++;
    }
    if (n) row.dataset.frontExtra = JSON.stringify(out);
    else delete row.dataset.frontExtra;
  }
  function frontTypeIcon(t){ return FRONT_TYPE_ICON[t] || 'front'; }
  function frontTypeLabel(t){ return FRONT_TYPE_LABEL[t] || 'Čelo'; }
  function frontTypeTile(t){ return FRONT_TYPE_TILE[t] || 'Čelo'; }
  // KOV-A2a: sloty SERVERA pre dané čelo (`front_slots`). `undefined` = server
  // sa k tomuto čelu ešte nevyjadril (nový riadok pred prvým echom) — karta
  // vtedy smerový riadok NEKRESLÍ a nič si neodvodzuje.
  function frontSlotsOf(fid){
    if (!frontSlots || !fid) return undefined;
    return Object.prototype.hasOwnProperty.call(frontSlots, fid) ? frontSlots[fid] : undefined;
  }

  // UI-C3: pole vysky ma svoje ID kvoli vyskovemu radu (N25) — `nxDimPick`
  // zapisuje hodnotu cez `el(id)` a ohlasuje ju POVODNOU udalostou.
  function frontHeightInputId(fid){ return 'fh_' + fid; }

  function addFrontRow(item, userAdd){
    // `userAdd` je od UI-C3 EXPLICITNY (D-84: „+ pridaj dvere / + pridaj čelo"
    // posielaju typ, takze `item == null` uz uzivatelsky pridanok nerozlisi).
    item = item || {};
    var wrap = el('frontRows');
    var idx = wrap.querySelectorAll('.frow').length + 1; // novy riadok = datovo posledny = najvyssia pozicia
    var row = document.createElement('div');
    row.className = 'frow';
    row.dataset.frontId = item.id || newStableId('F');
    // D-90: profil riadku zije v datasete — collectFronts ho posiela spat, takze
    // editacia inych poli profil nezhodi. D-96: ovladacom uz NIE je ikona v
    // riadku (cyklila by sa nepouzitelne pri viacerych profiloch), ale skupina
    // „Úchytky"; ikona ostala INDIKATOR.
    row.dataset.frontProfile = item.profile || 'none';
    // KOV-A2a: TYP riadku zije v datasete rovnako ako profil — rozbalovacka
    // zanikla, meni ho dlazdica typegridu v karte cela.
    row.dataset.frontType = item.type || 'door';
    frontExtraStore(row, item); // KOV-A1: smer/otváranie/klasifikácia (bez defaultov)
    var fhId = frontHeightInputId(row.dataset.frontId);
    // SMOKE PACK 1: ovladace cela ziju v `.fmain` — PEVNOM, NEZALAMOVACOM rade.
    // `.frow` je od tejto davky STLPEC (rad ovladacov + riadok kovania pod nim),
    // takze pri vypisanej vyske (pribudne „mm" a chip AUTO) uz krizik ✗ nemoze
    // spadnut o riadok nizsie. DOM zoznamu ostava „jeden .frow = jedno celo" —
    // obrateny render (D-23), citanie odspodu aj `closest('.frow')` platia bez
    // zmeny, lebo sa hlada VYHRADNE cez triedy, nikdy cez indexy deti.
    row.innerHTML = '<span class="fmain">' +
      '<span class="fnum">F' + idx + '</span>' +
      // KOV-A2a: NAZOV TYPU je TLACIDLO, ktore otvara kartu cela (typegrid,
      // smer, otváranie, klasifikácia). Rozbalovacka typu tým ZANIKLA — typ
      // sa vyberá piktogramom, nie zoznamom. Ikona žije UVNÚTRI tlačidla, aby
      // bol cieľ kliku celý „ikona + názov" (nie len text).
      // Je to NATIVNE `<button>`: rolu, Enter aj medzernik dava prehliadac —
      // vlastny `keydown` by len zdvojil klik.
      '<button type="button" class="ftname" aria-expanded="false" onclick="onFrontCardToggle(this)">' +
        '<span class="ftico" aria-hidden="true">' +
          NXIcons.svg(frontTypeIcon(item.type || 'door')) + '</span>' +
        '<span class="ftl"></span></button>' +
      // Uzke pole vysky (46 px) + sipka VYSKOVEHO RADU (N25). Rad len DOSADI
      // hodnotu a ohlasi ju povodnou udalostou — vyrazy, validacia aj debounce
      // apply beziat nezmenene.
      '<span class="dwrap">' +
        '<input class="fh" id="' + esc(fhId) + '" type="text" placeholder="auto" oninput="onFrontHeight(this)">' +
        '<button type="button" class="pbtn" data-nx-usage="rad:vyska_cela" onclick="nxDimToggle(this, event)"' +
          ' title="Výškový rad čiel" aria-label="Výškový rad čiel">' + NXIcons.svg('chevron-down') + '</button>' +
        '<span class="miniopts" data-dim-key="vyska_cela" data-dim-input="' + esc(fhId) + '"></span>' +
      '</span>' +
      // „mm" pri hodnote + chip AUTO — obe sa ukazu LEN pri vypisanej vyske
      // (prazdne pole je AUTO a nema co vracat). Zamok pri vyske ZANIKOL:
      // zamknute ⇔ vypisane (to iste pravidlo ma pole „Prvá zóna" z UI-C2).
      '<span class="funit">mm</span>' +
      '<button type="button" class="fauto" onclick="frontHeightAuto(this, event)"' +
        ' title="Vrátiť na AUTO — výška sa dopočíta z voľného miesta"' +
        ' aria-label="Vrátiť výšku čela na AUTO">AUTO</button>' +
      '<select class="fw" aria-label="Počet krídel" onchange="onFrontWings(this)"><option value="auto">auto</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option></select>' +
      (FRONT_PROFILES.length ? '<span class="fprof" aria-hidden="true">' + NXIcons.svg('profile') + '</span>' : '') +
      '<button class="fdel" title="Odstrániť" aria-label="Odstrániť čelo" onclick="delFrontRow(this); onField()">' + NXIcons.svg('x') + '</button>' +
      '</span>';
    wrap.insertBefore(row, wrap.firstChild); // D-23: navrch — DOM je obrateny
    if (item.height !== null && item.height !== undefined && item.height !== '') row.querySelector('.fh').value = item.height;
    if (item.wings) row.querySelector('.fw').value = item.wings;
    // UI-C3: `item.locked` sa uz necita — zamok JE vypisana hodnota.
    attachExprField(row.querySelector('.fh'), { flushFn: flushCabinetEditsNow }); // V0.4.7e vyrazy vo vyske cela
    nxDimFillRow(row);         // N25: hodnoty radu do mini-ponuky riadku
    syncFrontProfileBtn(row);  // D-90/D-96: indikator profilu z datasetu
    syncFrontAuto(row);        // chip AUTO + „mm" podla toho, ci je vyska vypisana
    updateFrontRowBadge(row);  // naviazane kovanie pod riadkom
    onFrontTypeChange(row);
    if (userAdd){
      // D-23: novy riadok vznika NAVRCHU zoznamu — dotiahni ho do pohladu a fokusni vysku
      row.scrollIntoView({ block: 'nearest' });
      var fh0 = row.querySelector('.fh'); if (fh0) fh0.focus();
    }
  }
  // D-84: rec stolara — „+ pridaj dvere" (kridlove) a „+ pridaj čelo"
  // (zasuvkove). Typ ide rovno do noveho riadku, aby ho pouzivatel nemusel
  // prestavovat po pridani.
  function addFrontKind(type){
    addFrontRow({ type: type }, true);
    onField();
  }
  // Vyska cela: chip AUTO a „mm" sa riadia TYM, ci je pole vypisane.
  function onFrontHeight(inp){
    var row = inp.closest('.frow');
    if (row) syncFrontAuto(row);
    onField();
  }
  // Chip AUTO = navrat na automat (vyprazdni pole). Udalost `input` sa vystreli
  // vyslovne — bezi po nej presne to, co pri zmazani rukou (expr hint, validacia,
  // debounce apply). stopPropagation: chip zije v riadku plnom ovladacov.
  function frontHeightAuto(btn, ev){
    if (ev) ev.stopPropagation();
    var row = btn.closest('.frow'); if (!row) return;
    var inp = row.querySelector('.fh'); if (!inp) return;
    if (inp.value === '') return; // uz je AUTO — ziadny prazdny apply
    inp.value = '';
    inp.classList.remove('bad');
    inp.dispatchEvent(new Event('input', { bubbles: true }));
  }
  // „mm" a chip AUTO sa ukazu LEN pri vypisanej vyske. Prazdne pole je AUTO —
  // vracat sa niet odkial a jednotka by patrila k nicomu.
  function syncFrontAuto(row){
    var inp = row.querySelector('.fh'); if (!inp) return;
    var on = inp.value.trim() !== '';
    var u = row.querySelector('.funit'), a = row.querySelector('.fauto');
    if (u) u.style.display = on ? '' : 'none';
    if (a) a.style.display = on ? '' : 'none';
    row.classList.toggle('fixed', on);
  }
  // D-18: pri 'none' (Bez čela) sa skryje výber krídel (ako pri drawer_front) a hneď
  // aj badge kovania (dátovo zmizne až po echu apply — bez dielcov niet kovania).
  // Badge span nemusí existovať (vzniká len pri neprázdnom badge) — null guard (Codex F3).
  // KOV-A2a: parametrom je RIADOK (typ zije v `dataset.frontType`), nie select —
  // rozbalovacka zanikla spolu s typegridom v karte.
  function onFrontTypeChange(row){
    if (!row) return;
    var type = row.dataset.frontType || 'door';
    row.querySelector('.fw').style.visibility = (type === 'door') ? 'visible' : 'hidden';
    // N27: ikona typu je zrkadlom stavu riadku — meni sa `href` v <use>, NIE
    // innerHTML celeho span-u (vzor NXIcons.set pri zamkoch).
    var ico = row.querySelector('.ftico');
    if (ico && window.NXIcons) NXIcons.set(ico, frontTypeIcon(type));
    // Nazov typu + plne znenie v `title` tlacidla (nazov sa v uzkom rade oreze).
    var btn = row.querySelector('.ftname');
    if (btn){
      var lbl = btn.querySelector('.ftl');
      if (lbl) lbl.textContent = frontTypeLabel(type);
      btn.title = frontTypeLabel(type) + ' — klik otvorí nastavenie čela';
      btn.setAttribute('aria-label', 'Čelo ' + (row.dataset.frontId || '') + ': ' +
                       frontTypeLabel(type) + ' — otvoriť nastavenie');
    }
    var hw = row.querySelector('.fhw');
    if (hw) hw.style.display = (type === 'none') ? 'none' : '';
    // D-90: „Bez čela" nemá na čom profil držať — indikátor zmizne a stav sa
    // zhodí na 'none' (rovnako to robí Ruby normalize; UI sa mu nesmie rozísť).
    // KOV-A1 (Codex #280 P2-D): to isté platí pre výklop, sklop aj blendu —
    // zoznam je JEDEN (`PROFILELESS_FRONT_TYPES` v core.js, zrkadlo servera),
    // nie druhá podmienka, ktorá by sa časom rozišla.
    var pb = row.querySelector('.fprof');
    if (pb){
      var off = frontProfileless(type);
      pb.style.visibility = off ? 'hidden' : 'visible';
      if (off && row.dataset.frontProfile !== 'none'){
        row.dataset.frontProfile = 'none';
        syncFrontProfileBtn(row);
      }
    }
    updateFrontRowBadge(row);   // D-18: „Bez čela" nema kovanie
    syncFrontDirBadge(row);     // KOV-A2a: badge „smer?" patri k typu aj k slotom
    refreshFrontProfileUI();    // D-96: zmena typu meni rozsah aj vetu stavu
  }
  // D-96: ikona profilu v riadku je LEN INDIKATOR (ovladac zije v skupine
  // „Úchytky"). Preto uz nie je `<button>` ani nenesie `aria-pressed` — je to
  // stav, nie prepinac; tooltip povie, kde sa meni.
  function syntheticProfileTitle(rec){
    return rec
      ? ('Úchytkový profil: ' + rec.name + ' — čelo sa skráti o ' + Math.round(rec.reduction) +
         ' mm (mení sa v skupine Úchytky)')
      : 'Bez úchytkového profilu (profil sa volí v skupine Úchytky)';
  }
  function syncFrontProfileBtn(row){
    var ind = row.querySelector('.fprof'); if (!ind) return;
    var rec = frontProfileRec(row.dataset.frontProfile || 'none');
    var txt = syntheticProfileTitle(rec);
    // `aria-label` sa tu VEDOME nedava: span je `aria-hidden` (je to indikator,
    // nie ovladac) a stav profilu cita citacka zo skupiny „Úchytky", kde sa aj
    // meni. Dva popisy toho isteho by si odporovali.
    ind.classList.toggle('on', !!rec);
    ind.title = txt;
  }
  function delFrontRow(btn){
    var row = btn.closest('.frow');
    if (row && row.dataset.frontId === openFrontCardId) openFrontCardId = null;
    row.remove(); renumberFronts(); refreshFrontProfileUI();
  }

  // ===== KOV-A2a: KARTA CELA =============================================
  //
  // Karta zije UVNUTRI `.frow` (treti potomok stlpca, za `.fmain` a `.fhw`) —
  // DOM zoznamu tak ostava „jeden `.frow` = jedno celo" a obrateny render
  // (D-23), citanie odspodu aj `closest('.frow')` platia bez zmeny. Otvorena
  // je VZDY NAJVIAC JEDNA (identita cela, nie index riadku — prestavba riadkov
  // ju musi vediet obnovit).
  //
  // ZIADNY NOVY CALLBACK SERVERA: kazda zmena v karte prepise dataset riadku
  // a ide POVODNOU cestou `onField()` -> `collectFronts` -> `apply_all`, teda
  // jeden krok Spat a server ostava autoritou.
  var openFrontCardId = null;

  // Badge „smer?" v riadku — rozhoduje VYHRADNE stav zo SERVERA (`front_slots`).
  // Legacy celo (kluc smeru v configu nie je) badge NIKDY nedostane.
  function syncFrontDirBadge(row){
    if (!row) return;
    var btn = row.querySelector('.ftname'); if (!btn) return;
    var want = frontDirBadge(frontSlotsOf(row.dataset.frontId));
    var badge = btn.querySelector('.fbadge');
    if (!want){ if (badge) badge.remove(); return; }
    if (!badge){
      badge = document.createElement('span');
      badge.className = 'fbadge';
      badge.textContent = 'smer?';
      btn.appendChild(badge);
    }
    badge.title = 'Smer otvárania nie je určený — otvor kartu čela a vyber stranu pántov.';
  }
  function updateFrontDirBadges(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++) syncFrontDirBadge(rows[i]);
  }

  function frontRowById(fid){
    var wrap = el('frontRows'); if (!wrap || !fid) return null;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      if (rows[i].dataset.frontId === fid) return rows[i];
    }
    return null;
  }

  // Klik na nazov typu: otvor kartu tohto cela (a zatvor tu predchadzajucu),
  // opatovny klik ju zbali.
  function onFrontCardToggle(btn){
    var row = btn.closest('.frow'); if (!row) return;
    var fid = row.dataset.frontId;
    openFrontCardId = (openFrontCardId === fid) ? null : fid;
    refreshFrontCards();
  }
  // Prekresli VSETKY riadky do stavu „otvorena je najviac jedna karta".
  function refreshFrontCards(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var row = rows[i];
      var open = row.dataset.frontId === openFrontCardId;
      var btn = row.querySelector('.ftname');
      if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      var card = row.querySelector('.fcard');
      if (!open){ if (card) card.remove(); continue; }
      if (!card){
        card = document.createElement('div');
        card.className = 'fcard';
        row.appendChild(card); // karta je VZDY posledna v stlpci
      }
      card.innerHTML = frontCardHtml(row);
    }
  }

  // HTML karty z ciseho view-modelu (`frontCardModel` v core.js). Panel tu
  // NEROZHODUJE, ktory riadok sa zobrazi ani ktora volba je aktivna — len
  // kresli. Vsetky texty idu cez `esc` (dataset moze niest cudzie data).
  function frontCardHtml(row){
    var item = frontExtraOf(row);
    item.type = row.dataset.frontType || 'door';
    var m = frontCardModel(item, frontSlotsOf(row.dataset.frontId));
    var h = '<div class="typegrid" role="group" aria-label="Typ čela">';
    m.tiles.forEach(function(t){
      h += '<button type="button" class="typetile' + (t.on ? ' on' : '') + '"' +
           ' data-t="' + esc(t.type) + '" aria-pressed="' + (t.on ? 'true' : 'false') + '"' +
           ' title="' + esc(frontTypeLabel(t.type)) + '" onclick="onFrontTile(this)">' +
           NXIcons.svg(frontTypeIcon(t.type)) +
           '<span class="tl">' + esc(frontTypeTile(t.type)) + '</span></button>';
    });
    h += '</div>';
    m.rows.forEach(function(r){
      if (r.kind === 'info'){
        h += '<div class="inforow' + (r.tone === 'muted' ? '' : ' ' + r.tone) + '">' + esc(r.text) + '</div>';
        return;
      }
      if (r.kind === 'hint'){
        h += '<div class="hint">' + esc(r.text) + '</div>';
        return;
      }
      h += '<div class="prow"><span class="pl">' + esc(r.label) + '</span>' +
           '<span class="segrow" role="group" aria-label="' + esc(r.label) + '">';
      r.options.forEach(function(o){
        h += '<button type="button" class="' + (o.warn ? 'warnstate ' : '') +
             (o.value === r.active ? 'on' : '') + '"' +
             ' data-k="' + esc(r.key) + '" data-v="' + esc(o.value) + '"' +
             (r.wing ? ' data-w="' + esc(r.wing) + '"' : '') +
             ' aria-pressed="' + (o.value === r.active ? 'true' : 'false') + '"' +
             (o.title ? ' title="' + esc(o.title) + '"' : '') +
             ' onclick="onFrontSeg(this)">' +
             (o.icon ? NXIcons.svg(o.icon) : '') + esc(o.label) + '</button>';
      });
      h += '</span></div>';
      if (r.hint) h += '<div class="hint">' + esc(r.hint) + '</div>';
    });
    return h;
  }

  // Dlazdica typu = zmena typu riadku. Na dvierka BEZ ulozeneho smeru sa smer
  // PRIZNA ako neurceny (jedina cesta je cista funkcia v core.js) — prepnutie
  // na iny typ NIC NEMAZE (dormant).
  function onFrontTile(btn){
    var row = btn.closest('.frow'); if (!row) return;
    var t = btn.dataset.t;
    if (!t || row.dataset.frontType === t) return; // klik na uz nasadeny typ = ziadny prazdny krok Spat
    row.dataset.frontType = t;
    frontExtraSet(row, frontExtraOnTypeChange(frontExtraOf(row), t));
    onFrontTypeChange(row);
    refreshFrontCards();
    onField();
  }
  // Klik na segment: hodnota chodi z TLACIDLA (teda z ponuky v core.js) —
  // panel si ziadny stav nevymysla.
  function onFrontSeg(btn){
    var row = btn.closest('.frow'); if (!row) return;
    frontExtraSet(row, frontExtraOnSegrow(frontExtraOf(row), btn.dataset.k,
                                          btn.dataset.v, btn.dataset.w));
    refreshFrontCards();
    onField();
  }
  // Pocet kridiel: 3/4 kridla PRIDAJU otazku na STREDNE kridla (krajne su
  // odvodene). Navrat na 1/2/auto NIC NEMAZE — ulozena hodnota ostava dormant.
  function onFrontWings(sel){
    var row = sel.closest('.frow');
    if (row){
      frontExtraSet(row, frontExtraOnWings(frontExtraOf(row), sel.value));
      refreshFrontCards();
    }
    onField();
  }

  // ===== D-96: skupina „Úchytky" ==========================================
  // Cita a zapisuje PRESNE tie iste data ako riadky (`dataset.frontProfile`) —
  // ziadne nove pole, ziadny novy callback. Zmena ide POVODNOU cestou
  // (dataset -> collectFronts -> apply_all), takze vsetky guardy beziat
  // nezmenene a server ostava autoritou (Fronts.normalize_config neznamy
  // profil zhodi na 'none').
  var FRONT_PROFILE_MIXED = '__mixed__'; // len ZOBRAZENIE stavu, nikdy sa nezapisuje
  // Stav riadkov v DATOVOM poradi (DOM je obrateny — D-23).
  function frontRowsState(){
    var wrap = el('frontRows'); if (!wrap) return [];
    var rows = wrap.querySelectorAll('.frow');
    var out = [];
    for (var i = rows.length - 1; i >= 0; i--){
      var r = rows[i];
      var num = r.querySelector('.fnum');
      out.push({ row: r, label: num ? num.textContent : '',
                 type: r.dataset.frontType || 'door',
                 profile: r.dataset.frontProfile || 'none' });
    }
    return out;
  }
  function frontProfileScopeNow(){ var s = el('frontProfileScope'); return s ? s.value : 'all'; }
  function refreshFrontProfileUI(){
    var sel = el('frontProfileSel'); if (!sel) return;
    var items = frontRowsState();
    var common = frontProfileCommon(items, frontProfileScopeNow());
    var html = '';
    if (common === null){
      // Rozne profily v rozsahu: volba je viditelna, ale NEodosielatelna —
      // inak by select klamal, ze vsetky cela maju to iste (vzor D-75 „podľa
      // parametra" v sekcii Kovanie).
      html += '<option value="' + FRONT_PROFILE_MIXED + '" selected disabled>(rôzne — vyber profil pre celý rozsah)</option>';
    }
    frontProfileOptionList().forEach(function(o){
      html += '<option value="' + esc(o.id) + '"' + (common === o.id ? ' selected' : '') + '>' + esc(o.name) + '</option>';
    });
    sel.innerHTML = html;
    // Prazdny rozsah = nie je co nastavovat. `aria-disabled` nestaci pri
    // <select> (natívna rozbalovacka by sa aj tak otvorila), preto tu VEDOME
    // ide o `disabled` — je to vstupne pole, nie akcny prvok vzoru D-78.
    //
    // Podmienkou je VYLUCNE obsah rozsahu, NIE `selectedCabId`: tato funkcia
    // bezi z `renderFronts`, teda EST PRED tym, nez `loadSelected` nastavi
    // identitu skrinky — gate na vybere by sekciu drzal navzdy neaktivnu.
    var empty = (common === '');
    sel.disabled = empty;
    var st = el('frontProfileState');
    if (st) st.textContent = empty ? 'V tomto rozsahu nie je žiadne čelo.' : frontProfileStateText(items);
  }
  // Vyber profilu = zapis do VSETKYCH ciel rozsahu naraz (D-96: „profil, hrana
  // a rozsah na jednom mieste"). Jeden `onField` = jeden apply = jeden krok Spat.
  function onFrontProfilePick(){
    var sel = el('frontProfileSel'); if (!sel) return;
    var id = sel.value;
    if (id === FRONT_PROFILE_MIXED) return; // stav, nie volba
    var changed = false;
    frontProfileScopeItems(frontRowsState(), frontProfileScopeNow()).forEach(function(it){
      if ((it.profile || 'none') === id) return;
      it.row.dataset.frontProfile = id;
      syncFrontProfileBtn(it.row);
      changed = true;
    });
    refreshFrontProfileUI();
    if (!changed) return;   // klik na uz nasadenu hodnotu = ziadny prazdny krok Spat
    renderPreview();        // pasmo profilu nad celom sa meni hned
    onField();
  }
  // Rozsah je FILTER, nie akcia — sam nic nemeni, len prestavi ponuku a vetu.
  function onFrontProfileScope(){ refreshFrontProfileUI(); }
  // D-23: cislo = kanonicka pozicia v datach — SPODNY DOM riadok je F1.
  function renumberFronts(){ var rows = el('frontRows').querySelectorAll('.frow'); for (var i=0;i<rows.length;i++){ rows[i].querySelector('.fnum').textContent = 'F' + (rows.length - i); } }
  // D-07 Codex B2: keepGaps=true pri echu apply toho isteho korpusu s cakajucimi
  // editmi — gap polia sa NEprepisu (lokalne hodnoty su novsie nez in-flight echo;
  // fokus guard nestaci — Reset presuva fokus na tlacidlo). Sablony/vyber = prepis.
  // D-22: zamok presahov (edge_limit_off) je pod TYM ISTYM guardom — klik na zamok
  // pocas in-flight apply nesmie starsie echo vratit spat.
  // D-23 (audit B1): pod TYM ISTYM guardom su aj RIADKY ciel — echo pocas
  // rozpisaneho editu ich uz NEprestavia (rebuild by zahodil pisany vstup aj
  // prave pridany/odobrany riadok — DOM s cakajucimi editmi je novsi nez echo).
  // Obnovia sa len bezpecne udaje viazane cez ID: placeholder ≈ vysky a badge
  // kovania. Plny rebuild riadkov = zmena vyberu alebo echo bez cakajucich editov.
  function renderFronts(fronts, keepGaps){
    if (keepGaps){
      updateFrontRowBadges();
      // KOV-A2a: badge „smer?" je BEZPECNY udaj viazany cez ID (rovnako ako
      // badge kovania) — obnovi sa aj pri light-update, kde sa riadky
      // NEPRESTAVUJU. Karta ostava otvorena a prekresli sa z cerstvych slotov.
      updateFrontDirBadges();
      refreshFrontCards();
      // applyTimer = pouzivatel pisal AJ PO flushi, ktory toto echo vyvolal —
      // jeho ≈ vysky su uz stare; placeholder doplni az echo najnovsieho editu.
      if (!applyTimer) updateFrontPlaceholders();
      return;
    }
    if (typeof clearFrontHover === 'function') clearFrontHover(); // D-23: riadky idu prec — hover stav s nimi
    el('frontRows').innerHTML = '';
    var items = (fronts && fronts.items) ? fronts.items : [];
    for (var i = 0; i < items.length; i++){ addFrontRow(items[i]); }
    updateFrontPlaceholders();
    // Gap polia su STATICKE (mimo frontRows) — plnia sa z kanonickeho configu;
    // 0 je platna hodnota, preto != null test (setNum by cez dflt finty 0 stratil).
    setNum('fr_gap', (fronts && fronts.gap != null) ? fronts.gap : 3);
    setNum('fr_gap_top', (fronts && fronts.gap_top != null) ? fronts.gap_top : 2);
    setNum('fr_gap_bottom', (fronts && fronts.gap_bottom != null) ? fronts.gap_bottom : 2);
    setNum('fr_gap_sides', (fronts && fronts.gap_sides != null) ? fronts.gap_sides : 2);
    setEdgeLimitOff(!!(fronts && fronts.edge_limit_off));
    // KOV-A2a: badge „smer?" + otvorena karta patria k PRAVE vykresleným
    // riadkom. Karta sa drzi cez IDENTITU cela (`openFrontCardId`), nie cez
    // index — klik na segrow spusti apply, echo prestava riadky a karta by
    // pod rukou zmizla. Cielove celo uz v zozname byt nemusi (zmena vyberu,
    // zmazany riadok) — vtedy stav ticho zanikne.
    if (openFrontCardId && !frontRowById(openFrontCardId)) openFrontCardId = null;
    updateFrontDirBadges();
    refreshFrontCards();
    refreshFrontProfileUI(); // D-96: ponuka a veta stavu patria k prave vykreslenym riadkom
  }

  // --- D-23: placeholder ≈ dopocitanej vysky v AUTO poliach --------------------
  // Zdroj: resolved front_items z Ruby (globalna frontItems — bridge ju plni PRED
  // renderom). Parovanie VYHRADNE cez dataset.frontId; sivy odhad LEN pre PRAZDNE
  // pole, ktoreho resolved zaznam ma mode:'auto'. Pri lokalnej zmene (onField) sa
  // odhady zneplatnia — nove dopocty plati az cerstve echo (stare vysky by klamali).
  function updateFrontPlaceholders(){
    var wrap = el('frontRows'); if (!wrap) return;
    var byId = {};
    (frontItems || []).forEach(function(it){ if (it && it.id) byId[it.id] = it; });
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var inp = rows[i].querySelector('.fh'); if (!inp) continue;
      var it = byId[rows[i].dataset.frontId];
      inp.placeholder = (inp.value.trim() === '' && it && it.mode === 'auto' && it.height != null)
        ? ('≈ ' + Math.round(it.height)) : 'auto';
    }
  }
  function invalidateFrontPlaceholders(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++){
      var inp = rows[i].querySelector('.fh'); if (inp) inp.placeholder = 'auto';
    }
  }
  // D-23 / UI-C3: NAVIAZANE KOVANIE POD RIADKOM. Jeden DROBNY riadok (nie
  // tabulka — vertikalny priestor je vzacny): „2× závesy · výsuv NL 470 →
  // Atira biela H176". Text skladaju dohromady dva EXISTUJUCE zdroje: badge
  // z planu (`frontHwBadge`, D-23) a nakupny rozpis servera (`frontHwBuy`,
  // D-92) — panel nic nedopocitava a ziadne nove data neprisli.
  //
  // Riadok zije UVNUTRI `.frow` (flex-wrap, `flex: 1 0 100%`) — DOM zoznamu
  // ostava „jeden .frow = jedno celo", takze obrateny render (D-23), citanie
  // odspodu aj prestavba riadkov platia bez zmeny.
  //
  // .fhw sa VZDY hlada/vklada cez triedu a appendChild na koniec riadku —
  // NIKDY nie cez nextElementSibling/indexy deti (.exprhint zije hned za .fh).
  // KOV-A2a: ked je otvorena KARTA CELA, riadok kovania patri NAD nu (karta je
  // vzdy posledna v stlpci) — preto `insertBefore` s kartou ako referenciou;
  // bez karty je referencia null, cize presne povodny `appendChild`.
  function updateFrontRowBadge(row){
    var fid = row.dataset.frontId;
    var badge = frontHwBadge(fid);
    var buy = (typeof frontHwBuy === 'function') ? frontHwBuy(fid) : null;
    var text = [badge, buy].filter(function(t){ return !!t; }).join(' → ');
    var span = row.querySelector('.fhw');
    if (!text){ if (span) span.remove(); return; }
    if (!span){
      span = document.createElement('span');
      span.className = 'fhw fhwline';
      span.setAttribute('role', 'button');
      span.setAttribute('tabindex', '0');
      span.setAttribute('aria-label', 'Kovanie tohto čela — otvorí kontext Kovanie');
      // stopPropagation: riadok je plny ovladacov a klik sem nesmie zamiesat
      // nic ineho (lekcia „select sa zatvaral").
      span.onclick = function(ev){ ev.stopPropagation(); openFrontHardware(fid); };
      span.onkeydown = function(ev){
        if (ev.key !== 'Enter' && ev.key !== ' ') return;
        ev.preventDefault(); ev.stopPropagation(); openFrontHardware(fid);
      };
      var card = row.querySelector('.fcard');
      if (card) row.insertBefore(span, card);
      else row.appendChild(span);
    }
    // Riadok je JEDNORIADKOVY s ellipsis — plny text nesie `title` (vzor D-92).
    span.title = text + ' — klik otvorí Kovanie';
    span.innerHTML = NXIcons.svg('link') + esc(text); // B3/B9: ikona staticka, text cez esc
    // D-18: pri „Bez čela" riadok skryty (typ zije v datasete — KOV-A2a).
    span.style.display = (row.dataset.frontType === 'none') ? 'none' : '';
  }
  function updateFrontRowBadges(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++) updateFrontRowBadge(rows[i]);
  }
  // Klik na naviazane kovanie: prepni kontext na Kovanie a dotiahni do pohladu
  // BOX VLASTNIKA tohto cela. Ziadny zapis — je to navigacia (N13: klikatelne
  // vedie tam, kam ukazuje).
  function openFrontHardware(fid){
    if (typeof setViewContext === 'function') setViewContext('kovanie');
    if (!fid) return;
    // UI-C4: cielom skoku je BOX VLASTNIKA (`.hwbox[data-group="front:<id>"]`),
    // nie jednotlivy riadok — kluc skupiny sklada `hwFrontGroup`, teda JEDINE
    // miesto konvencie, takze sa doskocenie a render nemozu rozist.
    var target = (typeof hwBoxByGroup === 'function') ? hwBoxByGroup(hwFrontGroup(fid)) : null;
    if (!target){ NX.setStatus('Toto čelo zatiaľ nemá naviazané kovanie.', false); return; }
    if (typeof nxRevealTarget === 'function') nxRevealTarget(target);
    target.scrollIntoView({ block: 'nearest' });
    // Kratke zvyraznenie: bez neho by pouzivatel po skoku hladal, KTORY box je
    // ten jeho (poloziek kovania byva viac, nez sa zmesti na obraz).
    hwFlash(target);
  }
  // D-23: klik na celo v nahlade — otvor sekciu Cela, riadok do pohladu, fokus
  // pola vysky. Riadok sa hlada cez dataset.frontId (nie cez cislo).
  function focusFrontRow(fid){
    if (!fid) return;
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    var row = null;
    for (var i = 0; i < rows.length; i++){
      if (rows[i].dataset.frontId === fid){ row = rows[i]; break; }
    }
    if (!row) return;
    // UI-B1 (Codex #168 P2): rozbal CELU cestu k riadku — od sektora Nastavenia
    // po skupinu Cela. Zbalený predok by fokus aj scroll zhltol.
    if (typeof nxRevealTarget === 'function') nxRevealTarget(row);
    row.scrollIntoView({ block: 'nearest' });
    var fh = row.querySelector('.fh');
    if (fh) fh.focus();
  }

  // Node testy (tests/js/test_uic1b_vkladanie.js) — v CEF je module undefined
  // a zvysok suboru bezi normalne (vzor board_card.js / preview.js). Exportuju
  // sa LEN ciste funkcie kreslenia dlazdic sablon (ziadny DOM).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { nxTplGlyph: nxTplGlyph, nxTplBadge: nxTplBadge,
                       nxTplOrientationNote: nxTplOrientationNote, nxTplTitle: nxTplTitle,
                       // UI-D2: dlazdica s PNG nahladom — kluc cache, ciste jadro
                       // pull/cache rozhodovania a nasadenie obrazka na dlazdicu.
                       tplPrevKey: tplPrevKey, tplPicHtml: tplPicHtml, tplTileHtml: tplTileHtml,
                       nxTplPreviewPlan: nxTplPreviewPlan, nxTplPreviewStore: nxTplPreviewStore,
                       tplBindPreview: tplBindPreview };
  }

