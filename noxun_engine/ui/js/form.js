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
      // D-130a (R5): POCET KRIDIEL uz nie je hodnota rozbalovacky v riadku
      // (`select.fw` zanikol — rozbijal mriezku), ale STAV RIADKU
      // `dataset.frontWings`, ktory meni segment „Krídla" v karte cela.
      // Vzor je `dataset.frontType` z KOV-A2a. Legacy riadok bez kluca ide na
      // `auto` — presne to posielal aj select, ked mu hodnota nesadla.
      var wings = r.dataset.frontWings || 'auto';
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
      if (r.dataset.frontProfileEdge !== undefined) item.profile_edge = r.dataset.frontProfileEdge;
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
             gap_bottom: frontGapVal('fr_gap_bottom', 2.0),
             gap_left: frontGapVal('fr_gap_left', 2.0), gap_right: frontGapVal('fr_gap_right', 2.0),
             edge_limit_off: edgeLimitOff, items: items };
  }
  // --- D-22: zamok limitu presahov (okraje +-100 zamknute / +-2000 odomknute) ---
  // Stav zije v JS premennej (nie v DOM triede) — collectFronts ho posiela s configom,
  // renderFronts ho obnovuje z kanonickeho configu pod TYM ISTYM echo-guardom ako
  // gap polia (keepGaps): starsie echo apply nesmie prepisat novsi klik na zamok.
  var edgeLimitOff = false;
  // D-130b: zamok je IKONA v hlavicke skupiny `cabfront` — textovy label
  // `.lblLimit` zanikol. Stav nesie ikona (lock/lock-open), `title`, farba
  // (`amber` = odomknute) a `aria-pressed`; vsetko musi byt citatelne aj pri
  // ZBALENEJ skupine, preto farba a nie veta v tele.
  var EDGE_LIMIT_TITLE_ON = 'Limit presahov: zamknuté ±100 mm — klik odomkne až ±2000 (obklady, pilastre)';
  var EDGE_LIMIT_TITLE_OFF = 'Odomknuté ±2000 mm — klik zamkne';
  function setEdgeLimitOff(off){
    edgeLimitOff = !!off;
    var b = el('edgeLimitLock');
    if (b){
      // B3: NEprepisovat cely obsah tlacidla textContentom (zmazal by ikonu) —
      // meni sa len symbol v <use>, title a farba; aria-pressed drzi stav (B11).
      if (typeof window !== 'undefined' && window.NXIcons) NXIcons.set(b, edgeLimitOff ? 'lock-open' : 'lock');
      if (b.setAttribute) b.setAttribute('title', edgeLimitOff ? EDGE_LIMIT_TITLE_OFF : EDGE_LIMIT_TITLE_ON);
      if (b.setAttribute) b.setAttribute('aria-pressed', edgeLimitOff ? 'false' : 'true'); // pressed = zamknuty limit
      if (b.classList) b.classList.toggle('amber', edgeLimitOff);
    }
  }
  // D-130b: tlacidlo zije v <summary> — bez `nxTipStop` by klik skupinu zbalil.
  function toggleEdgeLimit(ev){
    nxTipStop(ev);
    setEdgeLimitOff(!edgeLimitOff);
    onField(); // apply pre oznaceny korpus + prevalidovanie okrajovych poli
  }
  // D-07: hodnota gap pola cez evalDim (vyrazy); prazdne/nezmysel = default.
  function frontGapVal(id, dflt){ var v = numv(id); return isNaN(v) ? dflt : v; }
  // D-130b: `resetFrontGaps` je tiez ikona v hlavicke (ten isty stop-guard).
  // PREDVOLBY SA NEMENIA — 3 / 2 / 2 / 2 / 2 je stav, ktory server normalizuje.
  function resetFrontGaps(ev){ nxTipStop(ev); setNum('fr_gap', 3); setNum('fr_gap_top', 2); setNum('fr_gap_bottom', 2); setNum('fr_gap_left', 2); setNum('fr_gap_right', 2); onField(); }
  // Meta hlavicky `cabfront`: dekor · medzera · styri okraje. Text sklada
  // CISTA funkcia v core.js; tu sa len zbieraju hodnoty z DOM.
  // Bez oznacenej skrinky je meta prazdna (`cabfrontMetaText(null)`).
  function updateCabfrontMeta(){
    var node = el('cabfrontMeta'); if (!node) return;
    if (typeof cabfrontMetaText !== 'function') return;
    var picked = (typeof selectedCabId !== 'undefined') && selectedCabId;
    var gaps = picked ? { gap: frontGapVal('fr_gap', 3.0), top: frontGapVal('fr_gap_top', 2.0),
                                 bottom: frontGapVal('fr_gap_bottom', 2.0), left: frontGapVal('fr_gap_left', 2.0),
                                 right: frontGapVal('fr_gap_right', 2.0) } : null;
    node.textContent = cabfrontMetaText(cabfrontDecorName(), gaps);
  }
  // Nazov dekoru berieme z TEXTU vybranej option uz existujuceho selectu
  // `cab_front_c` — ziadny druhy zdroj pravdy, ziadny novy dotaz na server.
  function cabfrontDecorName(){
    var sel = el('cab_front_c');
    if (!sel || !sel.value) return '';
    var opts = sel.options || (sel.querySelectorAll ? sel.querySelectorAll('option') : null) || [];
    for (var i = 0; i < opts.length; i++){
      var o = opts[i];
      // ATRIBUT ma prednost pred vlastnostou: `<option value="X">` je to, co
      // porovnavame so `sel.value`. Ked atribut chyba, hodnotou je text —
      // vtedy rozhodne vlastnost (tak to robi aj prehliadac).
      var a = o.getAttribute ? o.getAttribute('value') : null;
      var v = (a === null) ? o.value : a;
      if (v === sel.value) return o.textContent || '';
    }
    return '';
  }
  function frontSideGap(fronts, key){
    if (fronts && Object.prototype.hasOwnProperty.call(fronts, key)) return fronts[key];
    return (fronts && fronts.gap_sides != null) ? fronts.gap_sides : 2;
  }
  // KOV-H1: ad-hoc polozky kovania idu SPAT nezmenene (pass-through). Sú
  // ECHOM servera z `cabinet_payload` — panel ich v H1 nijako neupravuje
  // (UI je H2). Kluc sa posiela LEN ked ho payload naozaj mal: `|| []` by
  // z „o polozkach neviem" spravilo „polozky nie su" a apply by ich zmazal.
  function collectAll(){
    var c = collectConstruction();
    c.fronts = collectFronts();
    if (hwManual) c.hardware_manual = hwManual;
    return c;
  }

  // --- validacia poli (cerveny okraj, ziadne modaly) ---
  // V0.4.7e: cita cez evalDim (vyraz = hodnota); ROZPISANY vyraz vo fokusovanom
  // poli sa preskoci (ani apply, ani cervene — hint bezi); COMMITNUTY neprazdny
  // nezmysel je PO NOVOM chyba (predtym NaN ticho presiel) a blokuje apply.
  // S1-E0: VYSKA od 80 mm (korpus na dorovnanie nad umyvackou) — sirka a hlbka
  // ostavaju. Cisla su zrkadlom Ruby `CabinetBuilder::MIN` / `ScaleWatch::MIN`;
  // zhodu vsetkych troch miest strazi `tests/pure/test_s1e0_min_vyska.rb`.
  var LIMITS = { width:[200,3000], height:[80,3000], depth:[150,2000], thickness:[6,50],
                 floor_height:[0,500], plinth_recess:[0,300], rail_depth:[20,400], rails_top_offset:[0,500],
                 // D-07: medzery/presahy cel — zaporny okraj = presah cez obrys (limit zhodny s Fronts::EDGE_LIMIT)
                 fr_gap:[0,50], fr_gap_top:[-100,100], fr_gap_bottom:[-100,100], fr_gap_left:[-100,100], fr_gap_right:[-100,100] };
  // D-22: okraje cel maju dynamicky limit podla zamku (Fronts::EDGE_LIMIT_UNLOCKED);
  // fr_gap (medzera medzi celami) ostava 0..50 VZDY.
  var EDGE_LIMIT_FIELDS = { fr_gap_top:1, fr_gap_bottom:1, fr_gap_left:1, fr_gap_right:1 };

  // S1-E0: KRIZOVA KONTROLA VYSKY. Samotny limit 80 mm uz nestaci — vyska je
  // CELKOVA (vratane sokla), takze dolna skrinka s predvolenym soklom 100 by
  // pri vyske 90 nedavala ziadne vnutro a builder by rebuild ODMIETOL vynimkou
  // (`Construction.validate!`). Pole preto zocervenie UZ V PANELI a apply sa
  // zastavi. Je to ZRKADLO dvoch Ruby pravidiel a pocita sa JEDINOU zdielanou
  // funkciou `nxInteriorZ` (core.js) — ziadna druha kopia vzorca.
  var MIN_AVAIL_H = 10.0;     // Construction.validate!: vnutro <= 10 mm = odmietnutie
  // S1-E0 (Codex #375 P2): PRAZDNE pole NIE JE nula — Ruby `normalize` doplni
  // PREDVOLBU TYPU (dolna skrinka ma sokel 100 mm). Validacia preto musi citat
  // tu istu hodnotu, akou bude server pocitat; inak by vyska 90 mm s prazdnym
  // soklom presla klientom a padla az na serveri. Predvolby su DOSLOVA cisla
  // zo servera (`CabinetBuilder::LOWER_DEFAULTS` / `UPPER_DEFAULTS` -> DEFAULTS
  // v `bridge.js`), takze druhy zdroj pravdy nevznika — parita je strazena
  // testom `tests/pure/test_s1e0_min_vyska.rb`.
  function cabFieldOrDefault(id){
    var e = el(id), d = DEFAULTS[getType()] || {};
    var raw = (e && e.value !== '') ? evalDim(e.value) : NaN;
    if (!isNaN(raw)) return raw;
    var dv = parseFloat(d[id]);
    return isNaN(dv) ? NaN : dv;   // NaN = predvolby zo servera este nedosli
  }
  function cabinetHeightError(){
    var he = el('height');
    if (!he || he.value === '') return '';
    var h = evalDim(he.value);
    if (isNaN(h)) return ''; // nezmysel uz oznacil hlavny cyklus
    var sokel = (getType() === 'upper') ? 0 : cabFieldOrDefault('floor_height');
    var hrubka = cabFieldOrDefault('thickness');
    // Bez predvolieb zo servera sa NEHADA — radsej ziadna hlaska nez falosna.
    if (isNaN(sokel) || isNaN(hrubka)) return '';
    var c = currentCarcass({ height: h, floor_height: sokel, thickness: hrubka });
    var avail = nxInteriorZ(c).availH;
    if (avail <= MIN_AVAIL_H){
      return 'Výška ' + Math.round(h) + ' mm nenechá žiadne vnútro (podstavec ' +
             Math.round(c.floor_height) + ' mm + hrúbky ' + Math.round(c.thickness) +
             ' mm). Zväčši výšku alebo zmenši podstavec.';
    }
    // D-80: pri vrchu „dve výstuhy" pod nimi musí ostať rezerva MIN_INTERIOR_H.
    if (c.top_mode === 'two_rails' && avail < NX_MIN_INTERIOR_H - 0.01){
      return 'Vnútro je príliš nízke na výstuhy (ostáva ' + Math.round(avail) +
             ' mm) — zväčši výšku, zmenši podstavec alebo prepni vrch na plný.';
    }
    return '';
  }
  // Oznaci/odznaci vysku a podstavec. Dovod ide do `title` (tooltip) samotneho
  // pola — panel nedostava novy DOM ani nove CSS (obe polia su v HTML BEZ
  // titlu, takze sa nic neprepisuje) a stavovy riadok „Skontroluj červené
  // polia" uz existuje v `actions.js`.
  function markHeightError(message){
    ['height', 'floor_height'].forEach(function(id){
      var e = el(id); if (!e) return;
      if (message){ e.classList.add('bad'); e.title = message; } else { e.title = ''; }
    });
  }

  function validateFields(skipFrontDraft){
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
    // S1-E0: krizova kontrola AZ TU — hlavny cyklus vyssie uz `bad` nastavil
    // aj zrusil podla rozsahov, takze nas priznak nic neprepise.
    var hErr = cabinetHeightError();
    markHeightError(hErr);
    if (hErr) ok = false;
    if (!skipFrontDraft && typeof nxFrontDraftReady === 'function' && !nxFrontDraftReady()) ok = false;
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

  // D-120: jeden navrh na jeden dokument/vyber alebo vkladaciu relaciu.
  // Preflight nema zapis; potvrdenie apply uvolni najviac jednu naviazanu akciu.
  var frontDraftSession = 1, frontDraftRevision = 0, frontDraft = null;
  var cabDraftRevision = 0, cabDraftDirty = false, cabApplyRequest = null, cabAfterApply = null;
  function nxFrontDraftReset(){
    var cancelled = cabAfterApply;
    frontDraftSession++;
    frontDraft = null; cabDraftDirty = false; cabApplyRequest = null; cabAfterApply = null;
    cabEditsInFlight = false;
    cancelCabinetEdits();
    nxFrontDraftMessage('');
    if (cancelled && cancelled.fail) cancelled.fail();
  }
  function nxFrontDraftData(){
    var c = collectConstruction(), d = DEFAULTS[getType()] || {};
    return { width: c.width === '' ? d.width : c.width,
      height: c.height === '' ? d.height : c.height,
      floor_height: getType() === 'upper' ? 0 : (c.floor_height === '' ? d.floor_height : c.floor_height),
      fronts: collectFronts(), model_guid: nxDocGuid(), cabinet_id: selectedCabId || '',
      insert_session: frontDraftSession };
  }
  function nxFrontDraftSignature(){ return JSON.stringify(nxFrontDraftData()); }
  function nxFrontDraftMessage(message){
    var n = el('frontDraftMessage'); if (!n) return;
    n.textContent = message || ''; n.hidden = !message;
  }
  function nxFrontDraftAsk(){
    if (!el('frontRows') || !nxDocGuid()) return;
    if (!selectedCabId && typeof getInsertKind === 'function' && getInsertKind() === 'board') return;
    var data = nxFrontDraftData(), signature = JSON.stringify(data);
    if (frontDraft && frontDraft.signature === signature) return;
    data.revision = ++frontDraftRevision;
    frontDraft = { signature: signature, request: data, pending: true, valid: false, items: null,
      message: 'Overujem rozmery čiel a hrany profilov…' };
    frontSlots = null; // sloty predchadzajuceho navrhu sa nikdy nededia
    nxFrontDraftMessage(frontDraft.message);
    if (window.sketchup && sketchup.front_preflight) sketchup.front_preflight(JSON.stringify(data));
    else {
      frontDraft.pending = false;
      frontDraft.message = 'Kontrola čiel nie je dostupná. Otvor panel znova.';
      nxFrontDraftMessage(frontDraft.message);
    }
  }
  function nxFrontDraftReady(){
    if (!el('frontRows') || !nxDocGuid()) return true;
    if (!selectedCabId && typeof getInsertKind === 'function' && getInsertKind() === 'board') return true;
    nxFrontDraftAsk();
    return !!(frontDraft && !frontDraft.pending && frontDraft.valid);
  }
  function nxFrontPreflightResult(result){
    var f = frontDraft, r = f && f.request;
    if (!r || !result || result.revision !== r.revision || result.model_guid !== nxDocGuid() ||
        result.cabinet_id !== (selectedCabId || '') || result.insert_session !== frontDraftSession ||
        f.signature !== nxFrontDraftSignature()) return;
    f.pending = false; f.valid = result.valid === true; f.items = result.items || [];
    f.message = (result.errors || []).map(function(e){ return e.message; }).join(' ');
    frontSlots = result.slots || {};
    frontItems = f.items;
    nxFrontDraftMessage(f.message);
    updateFrontDirBadges(); updateFrontPlaceholders();
    refreshFrontCards(); renderPreview();
    if (f.valid && cabDraftDirty && selectedCabId) nxScheduleCabinetApply();
  }
  function nxFrontDraftItems(){
    return frontDraft && frontDraft.signature === nxFrontDraftSignature() ? frontDraft.items : null;
  }
  function nxCabinetDraftHeld(){ return !!(cabDraftDirty || cabApplyRequest); }
  function nxScheduleCabinetApply(){
    if (!selectedCabId) return;
    if (applyTimer) clearTimeout(applyTimer);
    var cid = selectedCabId, guid = nxDocGuid();
    applyPendingGuid = guid;
    applyTimer = setTimeout(function(){ flushCabinetEdits(cid, guid); }, 400);
  }
  function nxStampCabinetApply(payload){
    var token = 'fa-' + frontDraftSession + '-' + (++frontDraftRevision);
    payload.front_apply_token = token;
    cabApplyRequest = { token: token, revision: cabDraftRevision, cabinet_id: selectedCabId,
      model_guid: nxDocGuid() };
  }
  function nxRememberCabinetEcho(c){
    var r = cabApplyRequest;
    if (r && c && c.model_guid === r.model_guid && c.cabinet_id === r.cabinet_id) r.echo = c;
  }
  function nxFrontApplyResult(result){
    var r = cabApplyRequest;
    if (!r || !result || result.front_apply_token !== r.token || result.model_guid !== r.model_guid ||
        result.cabinet_id !== r.cabinet_id || r.model_guid !== nxDocGuid() || r.cabinet_id !== selectedCabId) return;
    cabApplyRequest = null; cabEditsInFlight = false;
    var after = cabAfterApply; cabAfterApply = null;
    if (!result.ok){
      cabDraftDirty = true;
      if (after && after.fail) after.fail();
      var restored = r.echo && r.revision === cabDraftRevision;
      if (restored){
        // Odmietnuty apply vracia ulozene hodnoty. Novsi rozpisany edit sa
        // vsak starsim odmietnutim nikdy neprepise.
        cabDraftDirty = false; frontDraft = null; cancelCabinetEdits();
        NX.loadSelected(r.echo);
      }
      NX.setStatus(restored ? 'Zmena sa neuložila. Obnovili sa uložené hodnoty; ďalšia akcia sa nevykonala.' :
        'Zmena sa neuložila. Skontroluj formulár; ďalšia akcia sa nevykonala.', true);
      return;
    }
    if (r.revision === cabDraftRevision) cabDraftDirty = false;
    if (cabDraftDirty){
      if (after && after.fail) after.fail();
      nxScheduleCabinetApply(); return;
    }
    if (after && after.revision === cabDraftRevision && after.session === frontDraftSession) after.run();
  }
  // false = akcia bud caka na potvrdenie, alebo bola odmietnuta.
  function nxCabinetAction(run, fail){
    if (!selectedCabId) return true;
    var ae = document.activeElement;
    if ((ae && isExprInput(ae) && isExprStr(ae.value)) || !validateFields()){
      NX.setStatus((frontDraft && frontDraft.message) || 'Dokonči alebo oprav rozpísané polia.', true);
      if (fail) fail(); return false;
    }
    if (!cabDraftDirty && !cabApplyRequest && !applyTimer) return true;
    if (cabAfterApply){ if (fail) fail(); return false; }
    cabAfterApply = { run: run, fail: fail, revision: cabDraftRevision, session: frontDraftSession };
    if (!cabApplyRequest) flushCabinetEditsNow();
    return false;
  }

  // --- AUTO-APPLY (debounce 400 ms) ---
  // V0.4.7e: rozpisany VYRAZ vo fokusovanom poli nikdy nespusti apply ani nahlad
  // (medzistav '650-3' je validny vyraz s inou hodnotou) — aplikuje az Enter/blur
  // commit, ktory pole prepise cistym cislom a onField zavola znova.
  function onField(){
    cabDraftRevision++;
    if (selectedCabId) cabDraftDirty = true;
    if (cabAfterApply){ var cancelled = cabAfterApply; cabAfterApply = null; if (cancelled.fail) cancelled.fail(); }
    nxFrontDraftAsk();
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
    updateCabfrontMeta();                  // D-130b: meta skupiny „Spoločné" ukazuje PRAVE napisane cisla
    // KOV-G2 (D-111): riadok Noh vo VKLADANI. Dotaz odide LEN pri zmene toho,
    // na com nohy zavisia (typ, sirka, sokel, rezim sokla) — funkcia si to
    // stripuje sama, aby `onField` nemusel vediet, ktore pole sa menilo.
    if (typeof nxLegsInsertAsk === 'function') nxLegsInsertAsk();
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
    nxScheduleCabinetApply();
  }

  // Okamzity/odlozeny apply korpusu. Snapshot cabinet_id ide s payloadom — Ruby
  // handler ho overi proti aktualnemu vyberu (oneskoreny zapis po prekliknuti
  // na iny korpus sa ticho zahodi namiesto zasiahnutia nespravneho objektu).
  // `guidSnapshot` = dokument z času NAPLÁNOVANIA (R-02, review #264 P1).
  // `null`/`undefined` = žiadne rozpísané edity, platí aktuálny dokument.
  // `nativeOp` (NASTROJE-1) = handshake pred kopiou nastrojom: apply nesie
  // korelacny token a Ruby kopiu vykona AZ po nom. Kazda vetva, ktora apply
  // NEODOSLE, musi Ruby odpovedat sama — inak by cakalo do timeoutu.
  function flushCabinetEdits(cabSnapshot, guidSnapshot, nativeOp){
    applyTimer = null;
    applyPendingGuid = null;
    var ae = document.activeElement;
    if (ae && isExprInput(ae) && isExprStr(ae.value)){
      if (nativeOp) nxNativeFlushDone(nativeOp.token, 'invalid');
      return; // vyraz stale rozpisany
    }
    if (!selectedCabId){ if (nativeOp) nxNativeFlushDone(nativeOp.token, 'nothing'); return; }
    if (!validateFields()) {
      NX.setStatus((frontDraft && frontDraft.message) || 'Skontroluj červené polia (mimo rozsahu).', true);
      if (nativeOp) nxNativeFlushDone(nativeOp.token, 'invalid');
      return;
    }
    if (cabApplyRequest){ if (nativeOp) nxNativeFlushDone(nativeOp.token, 'invalid'); return; }
    var payload = collectAll();
    nxStampCabinetApply(payload);
    payload.cabinet_id = cabSnapshot || selectedCabId;
    if (nativeOp) payload.native_op = nativeOp;
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

  // NASTROJE-1 (Codex #293 kolo 1, P2): Ruby si pred kopiou spustenou z TOOLBARU
  // vypyta flush rozpisanych editov — kopia by inak vznikla zo STAREHO configu
  // (auto-apply ma 400 ms debounce a klik na tlacidlo nastroja cez JS nejde).
  // Kontrakt: server dostane odpoved v KAZDEJ vetve.
  //   'invalid' — cervene polia alebo rozpisany vyraz (kopia sa ODMIETNE)
  //   'nothing' — niet co flushnut, server kopiruje hned
  //   apply_all s `native_op` — zmena sa dopisuje, kopia bezi az v tom callbacku
  function nxFlushForNative(token, op){
    try {
      if (!selectedCabId){ nxNativeFlushDone(token, 'nothing'); return; }
      var ae = document.activeElement;
      if (ae && isExprInput(ae) && isExprStr(ae.value)){
        NX.setStatus('Dokonči rozpísaný výraz v poli — kópia by vznikla zo starých hodnôt.', true);
        nxNativeFlushDone(token, 'invalid');
        return;
      }
      if (typeof validateFields === 'function' && !validateFields()){
        NX.setStatus((frontDraft && frontDraft.message) || 'Skontroluj červené polia — kópia by vznikla zo starých hodnôt.', true);
        nxNativeFlushDone(token, 'invalid');
        return;
      }
      if (cabApplyRequest){ nxNativeFlushDone(token, 'invalid'); return; }
      if (!applyTimer && !cabDraftDirty){ nxNativeFlushDone(token, 'nothing'); return; }
      var g = applyPendingGuid;                       // R-02: dokument z casu naplanovania
      cancelCabinetEdits();
      flushCabinetEdits(selectedCabId, g, { kind: (op && op.kind) || 'copy',
                                            dir: (op && op.dir) || '', token: token });
    } catch (e){
      nxNativeFlushDone(token, 'invalid'); // pad nesmie nechat Ruby visiet
    }
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
    // KOV-W: hmotnosť vo VKLADANÍ odhad NEMÁ (materiály sa riešia až pri
    // vložení) — riadok sa vynuluje, aby nedržal číslo predtým označenej
    // skrinky.
    setOut('inf_weight', '—');
    var wn = el('infWeight');
    if (wn) wn.title = 'Hmotnosť dá skrinka po vložení (počíta sa z materiálov dielcov)';
  }

  // --- defaulty / viditelnost ---
  function setDefaults(t){
    writeConstruction(DEFAULTS[t] || {});
    applyVisibility(t);
  }
  function applyVisibility(t){
    el('plinthGroup').style.display = (t === 'upper') ? 'none' : '';
    el('fhRow').style.display = (t === 'upper') ? 'none' : ''; // D-11: vyska sokla v Zakladnych, horna ju nema
    // KOV-G2 (D-111): riadok Noh ide s riadkom Sokel — horna skrinka nohy nema.
    // Vo VKLADANI si zaroven vypyta cerstvy nahlad (typ sa prave zmenil).
    if (typeof nxLegsApplyVisibility === 'function') nxLegsApplyVisibility(t);
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
  // KOV-I: server posiela JEDEN odvodeny suhrn; klient necita mapovanie ani defs.
  function nxTplHardwareText(tp, prefix){
    var hw = tp && tp.hardware;
    if (!hw || hw.has !== true) return '';
    return (prefix || 'Kovanie: ') + (hw.labels || []).join(' · ') + ' — zámky sa neprenášajú';
  }
  function nxTplHardwareBadge(tp){
    var text = nxTplHardwareText(tp);
    return text ? '<i class="tplhw" role="img" aria-label="' + esc(text) + '">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-wrench"/></svg></i>' : '';
  }
  function nxTplTitle(tp){
    var note = nxTplOrientationNote(tp);
    var hw = nxTplHardwareText(tp);
    return tp.name + (note ? ' · ' + note : '') + ' — klik = vybrať · dvojklik = vlož hneď' +
      (hw ? '\n' + hw : '');
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
      '<span class="tplcaption">' + nxTplHardwareBadge(tp) + '<span>' + esc(tp.name) +
      (badge ? ' <i>· ' + esc(badge) + '</i>' : '') + '</span></span></button>';
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
    var m = el('insTplMeta');
    var kind = (NXInsert.insertType() === 'board') ? 'board' : 'cabinet';
    var name = NXInsert.templateName(kind);
    if (m) m.textContent = name || 'bez šablóny';
    // Ten isty riadok ako pomoc ku klikaniu: ziadny novy blok vo vkladacej karte.
    var hint = el('tplHint'); if (!hint) return;
    var tp = NXInsert.findTemplate(TEMPLATES, kind, name);
    var text = nxTplHardwareText(tp, 'Kovanie zo šablóny: ');
    hint.textContent = text ? (text.length > 80 ? text.slice(0, 79) + '…' : text) :
      'Klik = vybrať a doladiť · dvojklik = vlož hneď.';
    hint.title = text;
    hint.classList.toggle('tplhwhint', !!text);
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
    nxFrontDraftReset();
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
    // KOV-G2 (Codex #339 kolo 1 N2): DOSKA nohy nema. Prepnutie vkladania
    // z dolnej skrinky na dosku by inak nechalo v karte visiet riadok Noh
    // s textom skrinky (predikat `nxLegsInsertMode` len prestane odpovedat,
    // riadok samotny nikto neschova) — reset ho schova aj s pamatou vstupov
    // a zneplatni dotaz v lete.
    if (typeof nxLegsInsertReset === 'function') nxLegsInsertReset();
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
    // KOV-C2c: to iste plati pre riadok zasuvky — navrh vkladania nema za sebou
    // stavbu, takze server o systeme, vyske ani NL nic nevie.
    frontDrawer = null;
    // KOV-E2: a rovnako pre vyklop — navrh nema za sebou stavbu, takze server
    // nepozna triedu mechanizmu, hmotnost cela ani pocet tyci.
    frontLift = null;
    closeFrontCard();                        // ani otvorena karta cela (Codex #281 P2-B)
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
  var tplModalSession = 0;
  function cancelTplDeferredSave(){
    tplModalSession++;
    if (cabAfterApply && cabAfterApply.tplSession != null) cabAfterApply = null;
  }
  // KOV-I: pamat poslednej volby patri pocitacu (vzor rozbalenia sekcii).
  var TPL_SAVE_HARDWARE_KEY = 'noxun.tpl.with_hardware';
  function tplSavedHardwareChoice(){
    try { return localStorage.getItem(TPL_SAVE_HARDWARE_KEY) !== '0'; } catch(e){ return true; }
  }
  function rememberTplHardwareChoice(){
    var input = el('tplSaveHardware');
    try { localStorage.setItem(TPL_SAVE_HARDWARE_KEY, input.checked ? '1' : '0'); } catch(e){}
  }
  // Je otvoreny modal uz „o inej skrinke"? (zmena ID ALEBO dokumentu)
  function tplModalStale(c){
    if (!tplModalCabId) return false;
    var p = c || {};
    return (p.cabinet_id !== tplModalCabId) || (String(p.model_guid || '') !== String(tplModalGuid || ''));
  }
  function openSaveTemplateModal(){
    if (!selectedCabId){ NX.setStatus('Najprv označ korpus.', true); return; }
    var m = el('tplModal'); if (!m) return;
    cancelTplDeferredSave();
    tplModalCabId = selectedCabId;
    tplModalGuid = (typeof nxModelGuid === 'string') ? nxModelGuid : '';
    el('tplSaveName').value = (typeof tplNameSuggestion === 'string' && tplNameSuggestion) ? tplNameSuggestion : '';
    // UI-B3: typ sa predvyplni z TYPU OZNACENEJ SKRINKY (radio vo vkladacej
    // karte je pri oznacenom korpuse zrkadlom jeho typu — setType v loadSelected).
    setVal('tplSaveType', getType());
    el('tplSaveHardware').checked = tplSavedHardwareChoice();
    m.style.display = 'flex';
    refreshTplModalWarn();
    bindTplModal();
    var inp = el('tplSaveName'); inp.focus(); inp.select();
  }
  function closeSaveTemplateModal(){
    cancelTplDeferredSave();
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
    if (typeof nxCabinetAction === 'function'){
      var session = tplModalSession;
      var resume = function(){ if (session === tplModalSession && tplModalOpen()) saveTemplateAs(); };
      if (!nxCabinetAction(resume)){
        if (cabAfterApply && cabAfterApply.run === resume) cabAfterApply.tplSession = session;
        return;
      }
    } else if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (window.sketchup && sketchup.save_template_as){
      // identita z casu OTVORENIA modalu — preklik na inu skrinku ANI iny
      // dokument server neprepusti; UI-B3: typ urcuje, pod ktorym typom sa
      // sablona ponuka (whitelist v Ruby)
      sketchup.save_template_as(JSON.stringify({ name: name, cabinet_id: tplModalCabId || selectedCabId,
                                                 model_guid: tplModalGuid || '',
                                                 with_hardware: el('tplSaveHardware').checked,
                                                 type: val('tplSaveType') || getType() }));
    }
    closeSaveTemplateModal();
  }
  function bindTplModal(){
    if (tplModalBound) return; tplModalBound = true;
    var m = el('tplModal');
    el('tplSaveName').addEventListener('input', function(){ cancelTplDeferredSave(); this.classList.remove('bad'); refreshTplModalWarn(); });
    el('tplSaveType').addEventListener('change', cancelTplDeferredSave);
    el('tplSaveHardware').addEventListener('change', function(){ cancelTplDeferredSave(); rememberTplHardwareChoice(); });
    m.addEventListener('keydown', function(ev){
      if (ev.key === 'Escape'){ ev.preventDefault(); closeSaveTemplateModal(); return; }
      if (ev.key === 'Enter'){ ev.preventDefault(); saveTemplateAs(); return; }
      if (ev.key === 'Tab'){
        var f = m.querySelectorAll('input, select, button');
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
  // D-130a R6-d: dva typy potrebuju v dlazdici VIAC nez nazov — ludia si ich
  // pletu. Blenda NIE JE „bez kovania": s uchytkovym profilom ho dostava
  // z pravidla `uchytkovy-profil-blenda`, takze tooltip to nesmie poprieť.
  var FRONT_TYPE_TIP = {
    blind: 'Blenda — pevný dielec bez smeru a otvárania; kovanie vzniká len z úchytkového profilu.',
    none: 'Bez čela — riadok drží výšku v rade, panel sa nepostaví (otvorená nika).'
  };
  function frontTypeTileTitle(t){ return FRONT_TYPE_TIP[t] || frontTypeLabel(t); }

  // --- KOV-A1: PASS-THROUGH polí, ktoré A1 ešte needituje --------------------
  // `direction` · `wing_directions` · `opening_mode` · `drawer` žijú v datasete
  // riadku a `collectFronts` ich posiela naspäť NEZMENENÉ. Ovládače prídu v A2.
  // ŽELEZNÉ PRAVIDLO: kľúč, ktorý config nemá, sa tu NIKDY nevyrobí — žiadny
  // `||` fallback na neurčený stav, na klasické otváranie ani na stranu pántov.
  // (Guard v tests/pure/test_kova1_cela.rb stráži aj tento súbor, preto tu
  // taký literál nesmie stáť ani v komentári.)
  // KOV-E1b: `lift` (= `{ system: 'hk_top' | 'hl_top' }`) je tu z toho istého
  // dôvodu ako `drawer` — je to VNORENÝ objekt, ktorý panel iba prenáša.
  // Bez neho by Inspector pri každom uložení prepísal HL top späť na HK
  // (Astra FIX 10, Codex #331 kolo 2 P1): riadok ide na server VCELKU, takže
  // kľúč, ktorý serializér nepozná, zanikne.
  var FRONT_EXTRA_KEYS = ['direction', 'wing_directions', 'opening_mode', 'drawer', 'lift'];
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
  // KOV-A2a: ZÁZNAM SERVERA pre dané čelo (`front_slots[fid]` = `{ wings_n,
  // slots }`). `undefined` = server sa k tomuto čelu ešte nevyjadril (nový
  // riadok pred prvým echom, návrh vkladania) — karta vtedy smerový riadok
  // NEKRESLÍ a nič si neodvodzuje.
  function frontSlotsOf(fid){
    if (!frontSlots || !fid) return undefined;
    return Object.prototype.hasOwnProperty.call(frontSlots, fid) ? frontSlots[fid] : undefined;
  }

  // KOV-C2c: ZAZNAM SERVERA o zasuvke daneho cela (`front_drawer[fid]`).
  // `undefined` = server sa k nej nevyjadril (celo bez klasifikacie, navrh
  // vkladania, stary payload) — karta riadok zasuvky nekresli.
  function frontDrawerOf(fid){
    if (!frontDrawer || !fid) return undefined;
    return Object.prototype.hasOwnProperty.call(frontDrawer, fid) ? frontDrawer[fid] : undefined;
  }

  // KOV-E2: ZAZNAM SERVERA o vyklope daneho cela (`front_lift[fid]`).
  // `undefined` = server sa k nemu nevyjadril (nove celo pred prvym echom,
  // navrh vkladania, stary payload) — karta riadok vyklopu nekresli.
  function frontLiftOf(fid){
    if (!frontLift || !fid) return undefined;
    return Object.prototype.hasOwnProperty.call(frontLift, fid) ? frontLift[fid] : undefined;
  }

  // KOV-E2: LAHKY refresh zaznamu vyklopu — vzor `refreshFrontDrawer` (D1b).
  // Rozklik „Technický detail" vyklopu nesie NAZOV SETU a KODY, ktore push
  // `NX.setHardwareSets` prave meni (vyber tmaveho setu!), takze bez neho by
  // karta ukazovala stary nakup. Riadky ciel sa NEPRESTAVUJU — prekresli sa
  // len OTVORENA karta.
  function refreshFrontLift(map){
    frontLift = map || {};
    if (openFrontCardId) refreshFrontCards();
  }

  // KOV-D1b (Codex #310 kolo 1 P2-5): ĽAHKÝ refresh záznamu zásuvky
  // (`NX.setHardwareSets` po zmene mapovania alebo katalógu v Štúdiu).
  // Rozklik „Technický detail" nesie NÁZOV SETU a KÓDY, ktoré presne tento
  // push mení — bez neho by riadok Kovania ukazoval nový kit a detail vedľa
  // starý. Riadky čiel sa **neprestavujú**: prekreslí sa len OTVORENÁ karta
  // (rovnaká úspornosť ako `refreshHardwarePurchase`, ktorý mení len
  // sekundárne riadky). Zatvorená karta sa vykreslí z čerstvých dát pri
  // najbližšom otvorení.
  function refreshFrontDrawer(map){
    frontDrawer = map || {};
    if (openFrontCardId) refreshFrontCards();
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
    if (Object.prototype.hasOwnProperty.call(item, 'profile_edge')) row.dataset.frontProfileEdge = String(item.profile_edge);
    // KOV-A2a: TYP riadku zije v datasete rovnako ako profil — rozbalovacka
    // zanikla, meni ho dlazdica typegridu v karte cela.
    row.dataset.frontType = item.type || 'door';
    // D-130a (R5): POCET KRIDIEL zije v datasete rovnako ako typ a profil —
    // ovladacom je segment „Krídla" v karte cela. Legacy polozka bez kluca
    // dostane 'auto' (to iste posielal doterajsi `select.fw`).
    row.dataset.frontWings = item.wings || 'auto';
    frontExtraStore(row, item); // KOV-A1: smer/otváranie/klasifikácia (bez defaultov)
    // KOV-A2a (Codex #281 P1): „+ pridaj dvere" JE používateľská akcia (pravidlo
    // (a) z kontraktu) — nové dvierka bez uloženého smeru sa musia PRIZNAŤ ako
    // neurčené. Bez toho by každé nové čelo natrvalo obišlo RED nález, badge aj
    // „?" v náhľade, lebo Ruby by ho čítalo ako legacy (kľúč chýba). Rozhoduje
    // JEDINÝ výrobca v core.js — typ mu ide z datasetu, takže „+ pridaj čelo"
    // (zásuvkové) nevyrobí nič a v tomto súbore nestojí žiadny literál stavu.
    // Render UŽ EXISTUJÚCICH položiek (userAdd nie je) sa nedotkne ničoho.
    if (userAdd) frontExtraSet(row, frontExtraOnTypeChange(frontExtraOf(row), row.dataset.frontType));
    var fhId = frontHeightInputId(row.dataset.frontId);
    // D-130a: RIADOK CELA je CSS GRID so STALYMI STLPCAMI
    // ([cislo][nazov+suhrn][pole vysky][✕]) — polia uz „nelietaju" podla toho,
    // co v riadku prave je (D-130). Deti sa preto do gridu kladu PRIAMO, bez
    // obalu `.fmain`; kazde ma svoju poziciu v CSS, nie v poradi. DOM zoznamu
    // ostava „jeden .frow = jedno celo" — obrateny render (D-23), citanie
    // odspodu aj `closest('.frow')` platia bez zmeny, lebo sa hlada VYHRADNE
    // cez triedy, nikdy cez indexy deti.
    row.innerHTML =
      '<span class="fnum">F' + idx + '</span>' +
      // KOV-A2a: NAZOV TYPU je TLACIDLO, ktore otvara kartu cela (typegrid,
      // kridla, smer, otváranie, klasifikácia, úchytka). Rozbalovacka typu tým
      // ZANIKLA — typ sa vyberá piktogramom, nie zoznamom. Ikona žije UVNÚTRI
      // tlačidla, aby bol cieľ kliku celý „ikona + názov" (nie len text).
      // Je to NATIVNE `<button>`: rolu, Enter aj medzernik dava prehliadac —
      // vlastny `keydown` by len zdvojil klik.
      '<button type="button" class="ftname" aria-expanded="false" data-nx-usage="fronts:karta"' +
        ' onclick="onFrontCardToggle(this)">' +
        '<span class="ftico" aria-hidden="true">' +
          NXIcons.svg(frontTypeIcon(item.type || 'door')) + '</span>' +
        '<span class="ftl"></span>' +
        '<span class="fchev" aria-hidden="true">' + NXIcons.svg('chevron-down') + '</span></button>' +
      // D-130a R3: SUHRN cela pod nazvom. Druhy riadok mriezky je OBAL
      // `.fsubwrap` s DVOMA SURODENCAMI (R3-f):
      //   `.fsub`    = suhrn stavu, rastie a oreze sa; klik = toggle karty
      //   `.fhwlink` = naviazane kovanie; klik = karta rovno na tabe Kovanie
      // SU to SURODENCI, nie ovladac vnoreny v ovladaci: tlacidlo v tlacidle
      // je neplatne HTML, neda sa fokusovat a ellipsis susedu by ho orezal.
      '<span class="fsubwrap">' +
        '<button type="button" class="fsub" data-nx-usage="fronts:suhrn"' +
          ' onclick="onFrontCardToggle(this)"></button>' +
        '<button type="button" class="fhwlink" data-nx-usage="fronts:suhrn-kovanie" hidden' +
          ' onclick="onFrontSummaryHw(event, this)"></button>' +
      '</span>' +
      // D-130a R4: POLE VYSKY je JEDEN BOX s PEVNOU sirkou — chip AUTO, „mm"
      // aj sipka VYSKOVEHO RADU (N25) ziju VNUTRI neho, takze susedne stlpce
      // sa pri vypisanej hodnote nehybu. Rad len DOSADI hodnotu a ohlasi ju
      // povodnou udalostou — vyrazy, validacia aj debounce apply beziat
      // nezmenene. Zamok pri vyske ZANIKOL: zamknute ⇔ vypisane (to iste
      // pravidlo ma pole „Prvá zóna" z UI-C2), chip AUTO hodnotu vracia.
      '<span class="hbox" title="AUTO — výška sa dopočítava z voľného miesta; vypíš číslo = pevná výška">' +
        '<button type="button" class="fauto" onclick="frontHeightAuto(this, event)"' +
          ' title="Vrátiť na AUTO — výška sa dopočíta z voľného miesta"' +
          ' aria-label="Vrátiť výšku čela na AUTO">AUTO</button>' +
        '<input class="fh" id="' + esc(fhId) + '" type="text" placeholder="auto" oninput="onFrontHeight(this)">' +
        '<span class="funit">mm</span>' +
        '<span class="dwrap">' +
          '<button type="button" class="pbtn" data-nx-usage="rad:vyska_cela" onclick="nxDimToggle(this, event)"' +
            ' title="Výškový rad čiel" aria-label="Výškový rad čiel">' + NXIcons.svg('chevron-down') + '</button>' +
          '<span class="miniopts" data-dim-key="vyska_cela" data-dim-input="' + esc(fhId) + '"></span>' +
        '</span>' +
      '</span>' +
      '<button class="fdel" title="Odstrániť" aria-label="Odstrániť čelo" onclick="delFrontRow(this); onField()">' + NXIcons.svg('x') + '</button>';
    wrap.insertBefore(row, wrap.firstChild); // D-23: navrch — DOM je obrateny
    if (item.height !== null && item.height !== undefined && item.height !== '') row.querySelector('.fh').value = item.height;
    // UI-C3: `item.locked` sa uz necita — zamok JE vypisana hodnota.
    attachExprField(row.querySelector('.fh'), { flushFn: flushCabinetEditsNow }); // V0.4.7e vyrazy vo vyske cela
    nxDimFillRow(row);         // N25: hodnoty radu do mini-ponuky riadku
    syncFrontAuto(row);        // chip AUTO podla toho, ci je vyska vypisana
    onFrontTypeChange(row);    // nazov, ikona a suhrn riadku
    if (userAdd){
      // D-23: novy riadok vznika NAVRCHU zoznamu — dotiahni ho do pohladu a fokusni vysku
      row.scrollIntoView({ block: 'nearest' });
      var fh0 = row.querySelector('.fh'); if (fh0) fh0.focus();
    }
  }
  // D-114: rovnake typy a ikony ako karta. Staticky rad sa pri echu
  // neprestava, aby klavesnica nestratila fokus na tlacidle.
  function renderFrontAddTypes(){
    var box = el('frontAddTypes');
    if (!box || box.dataset.ready === '1') return;
    box.innerHTML = FRONT_CARD_TYPES.map(function(type){
      var label = 'Pridať: ' + frontTypeTile(type);
      var usage = type === 'drawer_front' ? 'drawer' : type;
      return '<button type="button" class="ghostbtn" title="' + esc(label) +
        '" aria-label="' + esc(label) + '" data-nx-usage="fronts:add-' + usage +
        '" onclick="addFrontKind(\'' + type + '\')">' + NXIcons.svg(frontTypeIcon(type)) +
        '<span class="front-add-plus">' + NXIcons.svg('plus') + '</span></button>';
    }).join('');
    box.dataset.ready = '1';
  }
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
  // D-130a R4: chip AUTO sa ukazuje LEN pri VYPISANEJ vyske (prazdne pole uz
  // AUTO JE a vracat sa niet odkial); „mm" je VZDY vidno — jednotka patri
  // k poliu, nie k hodnote, a jej miznutie hybalo obsahom boxu.
  // Stav nesie `.hbox.fixed` (nie `.frow.fixed`): tuci sa hodnota a odkryva
  // chip, oboje VNUTRI boxu, takze sirka boxu ostava konstantna.
  function syncFrontAuto(row){
    var inp = row.querySelector('.fh'); if (!inp) return;
    var box = row.querySelector('.hbox'); if (!box) return;
    box.classList.toggle('fixed', inp.value.trim() !== '');
  }
  // Zmena typu riadku: ikona, nazov, suhrn a profil.
  // KOV-A2a: parametrom je RIADOK (typ zije v `dataset.frontType`), nie select —
  // rozbalovacka zanikla spolu s typegridom v karte.
  // D-130a: `select.fw` (kridla) a `.fprof` (indikator profilu) z riadku
  // ZANIKLI — kridla su segment v karte, profil hovori SUHRN slovom.
  function onFrontTypeChange(row){
    if (!row) return;
    var type = row.dataset.frontType || 'door';
    // N27: ikona typu je zrkadlom stavu riadku — meni sa `href` v <use>, NIE
    // innerHTML celeho span-u (vzor NXIcons.set pri zamkoch).
    var ico = row.querySelector('.ftico');
    if (ico && window.NXIcons) NXIcons.set(ico, frontTypeIcon(type));
    // Nazov typu + plne znenie v `title` tlacidla (nazov sa v uzkom rade oreze).
    var btn = row.querySelector('.ftname');
    if (btn){
      var lbl = btn.querySelector('.ftl');
      if (lbl) lbl.textContent = frontTypeLabel(type);
      btn.title = frontTypeLabel(type) + ' — klik otvorí kartu čela';
      btn.setAttribute('aria-label', 'Čelo ' + (row.dataset.frontId || '') + ': ' +
                       frontTypeLabel(type) + ' — otvoriť kartu');
    }
    // D-90: „Bez čela" nemá na čom profil držať — stav sa zhodí na 'none'
    // (rovnako to robí Ruby normalize; UI sa mu nesmie rozísť).
    // KOV-A1 (Codex #280 P2-D): zoznam je JEDEN (`PROFILELESS_FRONT_TYPES`
    // v core.js, zrkadlo servera), nie druhá podmienka, ktorá by sa rozišla.
    if (frontProfileless(type) && row.dataset.frontProfile !== 'none')
      row.dataset.frontProfile = 'none';
    updateFrontRowSummary(row); // suhrn hovori o type, kridlach, uchytke aj kovani
    refreshFrontProfileUI();    // D-96: zmena typu meni rozsah aj vetu stavu
  }
  function delFrontRow(btn){
    var row = btn.closest('.frow');
    if (row && row.dataset.frontId === openFrontCardId) openFrontCardId = null;
    row.remove(); renumberFronts(); refreshFrontProfileUI();
  }

  // ===== KOV-A2a: KARTA CELA =============================================
  //
  // Karta zije UVNUTRI `.frow` (posledny potomok, v mriezke D-130a treti riadok
  // gridu) — DOM zoznamu tak ostava „jeden `.frow` = jedno celo" a obrateny
  // render (D-23), citanie odspodu aj `closest('.frow')` platia bez zmeny.
  // Otvorena je VZDY NAJVIAC JEDNA (identita cela, nie index riadku —
  // prestavba riadkov ju musi vediet obnovit).
  //
  // ZIADNY NOVY CALLBACK SERVERA: kazda zmena v karte prepise dataset riadku
  // a ide POVODNOU cestou `onField()` -> `collectFronts` -> `apply_all`, teda
  // jeden krok Spat a server ostava autoritou.
  var openFrontCardId = null;
  // D-130a R6: OTVORENY TAB karty. Default je „Čelo" pri KAZDOM otvoreni inej
  // karty; `refreshFrontCards` (echo, lahky push) ho ZACHOVA — inak by kazde
  // echo hodilo pouzivatela z tabu Kovanie spat (vzor obnovy fokusu D2b).
  var openFrontCardTab = 'celo';

  // D-130a: badge „smer?" sa PRESUNUL z nazvu do SUHRNU riadku (`.fsub`) —
  // stav riadku tak hovori jedna veta, nie tlacidlo s prilepkom. Obnova preto
  // bezi cez `updateFrontRowSummary`; nazov zostava len nazvom. Meno funkcie
  // ostava (volaju ju `nxFrontPreflightResult` aj Node sady).
  function updateFrontDirBadges(){ updateFrontRowSummaries(); updateFrontMeta(); }

  // KOV-A2a (Codex #281 P2-B): otvorená karta patrí KONKRÉTNEJ SKRINKE.
  // `front_id` (F1) má každá skrinka, takže bez tejto brány by sa po prepnutí
  // výberu otvorila karta CUDZIEHO čela — a stav by unikol aj do režimu
  // vkladania. Volá sa PRED `renderFronts` (bridge.js), aby sa cudzia karta ani
  // nestihla vykresliť; rozhodnutie robí čistá funkcia v core.js.
  function syncFrontCardOwner(prevCabId, nextCabId){
    openFrontCardId = frontCardKeepOpen(prevCabId, nextCabId, openFrontCardId);
  }
  // Odchod z korpusu úplne (doska, prázdny výber, návrh vkladania).
  function closeFrontCard(){ openFrontCardId = null; }

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
    // D-130a R6: kazde OTVORENIE INEJ karty zacina na tabe Čelo — tab je stav
    // prace nad JEDNYM celom, nie nastavenie panela.
    if (openFrontCardId !== fid) openFrontCardTab = 'celo';
    openFrontCardId = (openFrontCardId === fid) ? null : fid;
    refreshFrontCards();
  }
  // R3-e/R3-f: koncovka kovania v riadku otvara kartu rovno na tabe KOVANIE.
  // Je to NATIVNE `<button>` (surodenec suhrnu), takze Enter aj medzernik
  // obsluhuje prehliadac; `stopPropagation` ostava ako poistka pre pripad,
  // ze by okolo riadku niekedy pribudol delegovany handler.
  function onFrontSummaryHw(ev, node){
    if (ev && typeof ev.stopPropagation === 'function') ev.stopPropagation();
    var row = node.closest('.frow'); if (!row) return;
    openFrontCardId = row.dataset.frontId;
    openFrontCardTab = 'hw';
    refreshFrontCards();
  }
  // D-130a R6: prepnutie tabu karty. Ziadny zapis — je to len iny pohlad na tie
  // iste data, takze ZIADNY `onField` a ziadny krok Spat.
  function onFrontCardTab(btn){
    var t = btn && btn.dataset ? btn.dataset.tab : null;
    if (!t || t === openFrontCardTab) return;
    openFrontCardTab = t;
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
      // D-130a: otvoreny riadok sa prizna aj cislom (grid nema ram karty hore).
      if (open) row.dataset.open = '1'; else delete row.dataset.open;
      var card = row.querySelector('.fcard');
      if (!open){ if (card) card.remove(); continue; }
      if (!card){
        card = document.createElement('div');
        card.className = 'fcard';
        row.appendChild(card); // karta je VZDY posledna v riadku
      }
      // Codex #281 kolo 2 (P2): karta sa prekresluje CELA, takze tlacidlo,
      // ktore prave drzalo fokus, zanikne a fokus spadne na `<body>` —
      // pouzivatel klavesnice by po KAZDEJ zmene typu ci segmentu musel
      // pretabovat cely Inspector. Render ostava celistvy (ziadny inkrementalny
      // prepis); obnovi sa LEN fokus, a to podla LOGICKEJ identity ovladaca
      // (ciste funkcie v core.js), nie podla indexu deti.
      var focusKey = frontCardFocusOf(card);
      card.innerHTML = frontCardHtml(row);
      frontCardRefocus(card, focusKey);
    }
  }
  // Identita fokusovaneho ovladaca, ak lezi V TEJTO karte (inak null —
  // fokus mimo karty sa prekreslenim nedotkne a nesmie sa nikam presuvat).
  function frontCardFocusOf(card){
    if (!card || typeof document === 'undefined') return null;
    var ae = document.activeElement;
    if (!ae || typeof ae.closest !== 'function' || ae.closest('.fcard') !== card) return null;
    var d = ae.dataset || {};
    // KOV-D2b (Codex #313 kolo 1 P2-4): chipy osi maju vlastnu identitu
    // (`data-ax` = os, `data-axc` = druh ovladaca) — bez nej by fokus po
    // KAZDOM prekresleni karty spadol na dokument prave pri klavesovej praci
    // so zamkom, teda tam, kde je najdrahsi.
    // D-130a: k identitam pribudli TABY (`data-tab`) — bez nich by fokus po
    // prepnuti tabu spadol na dokument prave na ceste, ktoru klavesnica
    // pouziva najcastejsie (tab -> obsah -> tab).
    return frontCardFocusKey({ t: d.t, k: d.k, v: d.v, w: d.w, ax: d.ax, axc: d.axc,
                               pc: d.pc, tab: d.tab });
  }
  // Najde v CERSTVO vykreslenej karte tlacidlo s rovnakou identitou a vrati mu
  // fokus. `preventScroll` je zamer: karta sa nema pod rukou posunut; staršie
  // jadra ten parameter nepoznaju, preto fallback na obycajny `focus()`.
  function frontCardRefocus(card, key){
    var sel = frontCardFocusSelector(key);
    if (!sel || !card) return;
    var target = card.querySelector(sel);
    if (!target || typeof target.focus !== 'function') return;
    try { target.focus({ preventScroll: true }); } catch (e) { target.focus(); }
  }

  // D-130a R8: TOOLTIP `?` pri popisku. Pomocny text uz nestoji ako `.hint`
  // pod ovladacom (vertikalny priestor panela je vzacny) — zije za ikonou.
  // Text ide cez `esc`: `data-tip` sa kresli pseudo-elementom, teda by inak
  // uvodzovka v texte rozbila atribut.
  function nxTipHtml(text, cls){
    if (!text) return '';
    return '<button type="button" class="nxtip' + (cls ? ' ' + cls : '') + '"' +
           ' aria-label="Pomoc" data-tip="' + esc(text) + '" onclick="nxTipStop(event)">' +
           NXIcons.svg('help-circle') + '</button>';
  }
  // Tooltip NIKAM NEVEDIE — klik na neho nesmie zbalit skupinu (`<summary>`
  // toggluje na klik kdekolvek v hlavicke) ani otvorit kartu cela.
  function nxTipStop(ev){
    if (!ev) return;
    if (typeof ev.preventDefault === 'function') ev.preventDefault();
    if (typeof ev.stopPropagation === 'function') ev.stopPropagation();
  }

  // HTML karty z ciseho view-modelu (`frontCardModel` v core.js). Panel tu
  // NEROZHODUJE, ktory riadok sa zobrazi ani ktora volba je aktivna — len
  // kresli. Vsetky texty idu cez `esc` (dataset moze niest cudzie data).
  // D-130a R6: karta ma DVA TABY — „Čelo" (co nastavujem) a „Kovanie" (co
  // z toho vzislo). Tab je JEDEN pre celu kartu (`openFrontCardTab`).
  function frontCardHtml(row){
    var item = frontRowItem(row);
    var m = frontCardModel(item, frontSlotsOf(row.dataset.frontId),
                           frontDrawerOf(row.dataset.frontId),
                           frontLiftOf(row.dataset.frontId));
    // Tab, ktory NEEXISTUJE (blenda, „bez čela" kovanie nemaju), sa ticho
    // vrati na „Čelo" — stav panela nesmie ukazat prazdno.
    var has = m.tabs.some(function(t){ return t.key === openFrontCardTab; });
    var tab = has ? openFrontCardTab : 'celo';
    var h = '';
    if (m.tabs.length > 1){
      h += '<div class="ctabs" role="tablist">';
      m.tabs.forEach(function(t){
        h += '<button type="button" class="' + (t.key === tab ? 'on' : '') + '"' +
             ' data-tab="' + esc(t.key) + '" role="tab" aria-selected="' +
             (t.key === tab ? 'true' : 'false') + '" onclick="onFrontCardTab(this)">' +
             (t.key === 'hw' ? NXIcons.svg('hammer') : '') + esc(t.label) +
             (t.badge ? '<span class="fbadge">' + esc(t.badge) + '</span>' : '') + '</button>';
      });
      h += '</div>';
    }
    if (tab === 'hw') return h + frontCardHwHtml(row, m);
    h += '<div class="typegrid" role="group" aria-label="Typ čela">';
    m.tiles.forEach(function(t){
      h += '<button type="button" class="typetile' + (t.on ? ' on' : '') + '"' +
           ' data-t="' + esc(t.type) + '" aria-pressed="' + (t.on ? 'true' : 'false') + '"' +
           ' title="' + esc(frontTypeTileTitle(t.type)) + '" onclick="onFrontTile(this)">' +
           NXIcons.svg(frontTypeIcon(t.type)) +
           '<span class="tl">' + esc(frontTypeTile(t.type)) + '</span></button>';
    });
    h += '</div>';
    h += frontCardRowsHtml(m.rows);
    // D-130a R7: UCHYTKA stoji AZ POD nastaveniami typu — je to posledna
    // otazka o cele a jedine miesto, kde sa profil a hrana menia.
    h += frontProfileCardHtml(row);
    return h;
  }
  // Riadky view-modelu -> HTML. Spolocne pre oba taby (obsah rozhoduje model).
  function frontCardRowsHtml(rows){
    var h = '';
    (rows || []).forEach(function(r){
      if (r.kind === 'info'){
        // KOV-C2c: ikona LEN ked ju view-model vyslovne ziada (cerveny dovod,
        // jantarove odporucanie) — informacne vety karty ostavaju bez nej.
        h += '<div class="inforow' + (r.tone === 'muted' ? '' : ' ' + r.tone) + '">' +
             (r.icon ? NXIcons.svg(r.icon) : '') + esc(r.text) + '</div>';
        return;
      }
      // D-130a R8/R9: riadok `kind: 'hint'` ZANIKOL — pomocny text uz nie je
      // riadok karty (bral vertikalny priestor v KAZDEJ karte), ale tooltip
      // `?` pri popisku segmentu (`r.tip` nizsie). STAVOVE vety (`info`
      // s `tone: 'err' | 'warn'`) ostavaju viditelne.
      // KOV-D2b: chipy osi zamku kresli TEN ISTY markup ako kontext Kovanie
      // (`hwAxHtml` v hardware.js) — jeden zdroj stavu aj jeden zapis. Karta
      // si nekresli vlastnu verziu, aby sa obe miesta nemohli rozist.
      if (r.kind === 'axes'){
        if (typeof hwAxHtml === 'function') h += hwAxHtml(r.axes, r.ident);
        return;
      }
      // KOV-D3b: ponuka novej verzie receptu. Markup aj klik ziju v
      // `hardware.js` pri ostatnych zapisovych cestach kovania — karta je
      // renderer, nie druhe miesto, kde by sa skladal payload servera.
      if (r.kind === 'upgrade'){
        if (typeof hwUpHtml === 'function') h += hwUpHtml(r.upgrade);
        return;
      }
      // KOV-C2c: JEDEN read-only riadok vyriesenej zasuvky + rozbalitelny
      // technicky detail (vety receptu). Ziadne tlacidla, ziadny zapis —
      // hodnoty su vysledok stavby a menia sa klasifikaciou nad nou.
      if (r.kind === 'resolved'){
        h += '<div class="drow"><span class="dl">' + esc(r.label) + '</span>' +
             '<span class="dv">' + esc(r.text) + '</span></div>';
        if (r.note) h += '<div class="hint">' + esc(r.note) + '</div>';
        if (r.detail && r.detail.length){
          h += '<details class="ddet"><summary>Technický detail</summary><ul>';
          r.detail.forEach(function(t){ h += '<li>' + esc(t) + '</li>'; });
          h += '</ul></details>';
        }
        return;
      }
      // D-130a R8/R9: pomocny text riadku uz nie je `.hint` POD segmentom, ale
      // tooltip `?` PRI POPISKU — text je ten isty, len nezabera riadok.
      h += '<div class="prow"><span class="pl">' + esc(r.label) +
           nxTipHtml(r.tip, 'inl') + '</span>' +
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
    });
    return h;
  }
  // D-130a R6: TAB KOVANIE — co z nastaveni cela VZISLO. Ziadne nove data:
  // su to tie iste riadky (`resolved` · `axes` · `upgrade` · vety vyklopu),
  // ktore karta kreslila doteraz pod segmentmi. Dole stoji JEDINY ovladac —
  // navigacia do kontextu Kovanie (nahradila preklik zaniknuteho riadku `.fhw`).
  function frontCardHwHtml(row, m){
    var fid = row.dataset.frontId || '';
    var h = frontCardRowsHtml(m.hwRows);
    // D-78: ovladac, ktory NEMA kam viest, sa NESKRYVA — ostava viditelny
    // a `aria-disabled` s dovodom v `title` povie preco. Box vlastnika
    // vznikne az po echu apply, takze pri novom cele este nemusi existovat.
    var has = (typeof hwBoxByGroup === 'function' && typeof hwFrontGroup === 'function')
      ? !!hwBoxByGroup(hwFrontGroup(fid)) : false;
    // Codex #371 P2: „Bez kovania" sa NESMIE odvodzovat len z `m.hwRows`.
    // Vyriesne riadky (`front_drawer` / `front_lift`) ma LEN zasuvka a vyklop —
    // dvierka, sklop aj blenda s uchytkovym profilom kovanie MAJU, len o nom
    // hovori plan a nakup (`frontHwBadge` + `frontHwBuy`), nie samostatny
    // serverovy zaznam. Prazdny stav preto rozhoduje REALNE kovanie vlastnika
    // (text alebo existujuci box) A AZ POTOM absencia riadkov.
    var badge = (typeof frontHwBadge === 'function') ? frontHwBadge(fid) : null;
    var buy = (typeof frontHwBuy === 'function') ? frontHwBuy(fid) : null;
    var text = [badge, buy].filter(function(t){ return !!t; }).join(' → ');
    if (!m.hwRows.length){
      if (text){
        // Ten isty read-only riadok ako vyriesena zasuvka — je to vysledok,
        // nie nastavenie; text skladaju TIE ISTE dva zdroje ako suhrn riadku.
        h += '<div class="drow"><span class="dl">Kovanie</span>' +
             '<span class="dv">' + esc(text) + '</span></div>';
      } else if (has){
        h += '<div class="inforow">Položky tohto čela nájdeš v kontexte Kovanie.</div>';
      } else {
        h += '<div class="inforow">Bez kovania.</div>';
      }
    }
    h += '<div class="cfoot"><button type="button" class="ghostbtn" data-nx-usage="fronts:do-kovania"' +
         (has ? ' title="Prepne kontext Kovanie a doskočí na box tohto čela"'
              : ' aria-disabled="true" title="Toto čelo zatiaľ nemá naviazané kovanie — položky vzniknú po prestavaní skrinky."') +
         ' onclick="onFrontOpenHardware(this, \'' + esc(fid) + '\')">' + NXIcons.svg('hammer') +
         'Otvoriť v Kovaní' + NXIcons.svg('arrow-right') + '</button></div>';
    return h;
  }
  // Codex #371 P2: `aria-disabled` (vzor D-78) ovladac NESKRYVA, ale ani ho
  // NESMIE nechat fungovat — inak by klik na stlmene tlacidlo prepol kontext
  // a pouzivatel by skoncil v Kovani bez toho, na co klikol. Dovod uz nesie
  // `title`, takze sa nic nehlasi znova.
  function onFrontOpenHardware(btn, fid){
    if (btn && btn.getAttribute('aria-disabled') === 'true') return;
    openFrontHardware(fid);
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
    // Codex #281 P2-C: klik na UŽ AKTÍVNU voľbu = žiadny prázdny krok Späť
    // (ten istý guard má dlaždica typu). Aktívny stav nesie `aria-pressed`,
    // ktorý karta kreslí z view-modelu — netreba druhý výpočet toho istého.
    if (btn.getAttribute('aria-pressed') === 'true') return;
    // D-130a R5: KRIDLA su jediny segment, ktoreho hodnota nezije v dormant
    // poliach, ale vo VLASTNOM datasete riadku (`frontWings`) — presne tam,
    // odkial ju cita `collectFronts`. Zapis preto ide svojou cestou.
    if (btn.dataset.k === 'wings'){ onFrontWings(row, btn.dataset.v); return; }
    frontExtraSet(row, frontExtraOnSegrow(frontExtraOf(row), btn.dataset.k,
                                          btn.dataset.v, btn.dataset.w));
    updateFrontRowSummary(row);
    refreshFrontCards();
    onField();
  }
  // Pocet kridiel: 3/4 kridla PRIDAJU otazku na STREDNE kridla (krajne su
  // odvodene). Navrat na 1/2/auto NIC NEMAZE — ulozena hodnota ostava dormant.
  // D-130a: parametrom je RIADOK a HODNOTA (vzor `onFrontTile`) — rozbalovacka
  // `select.fw` v riadku zanikla, ovladacom je segment „Krídla" v karte.
  function onFrontWings(row, value){
    if (!row) return;
    var v = (value == null || value === '') ? 'auto' : String(value);
    if (row.dataset.frontWings === v) return; // klik na nasadenu hodnotu = ziadny prazdny krok Spat
    row.dataset.frontWings = v;
    frontExtraSet(row, frontExtraOnWings(frontExtraOf(row), v));
    updateFrontRowSummary(row);
    refreshFrontCards();
    onField();
  }

  // ===== D-96 / D-130a R7: UCHYTKA NA JEDNOM MIESTE =======================
  // JEDINE MIESTO STAVU je KARTA CELA (riadok „Úchytka" = Profil + Hrana).
  // Skupina „Úchytky" (`fhandles`) ZANIKLA — bola DRUHYM stavom tych istych
  // dvoch poli a pouzivatel nevedel, ktore z dvoch miest plati (D-129).
  //
  // Hromadna zmena ostava ako AKCIA: popover „všetkým" v hlavicke skupiny.
  // Jeho selecty NIC NEZAPISUJU — zapise az „Použiť" (jeden `onField`, jeden
  // apply, jeden krok Späť). Zmena ide POVODNOU cestou (dataset ->
  // collectFronts -> apply_all), takze vsetky guardy beziat nezmenene
  // a server ostava autoritou (Fronts.normalize_config neznamy profil zhodi
  // na 'none').
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
                 profile: r.dataset.frontProfile || 'none',
                 profile_edge: r.dataset.frontProfileEdge === undefined ? 'top' : r.dataset.frontProfileEdge });
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
    refreshFrontProfileEdgeUI(items);
    var st = el('frontProfileState');
    if (st) st.textContent = empty ? 'V tomto rozsahu nie je žiadne čelo.' : frontProfileStateText(items);
    // D-130a R7: tlacidlo pomenuva POCET ciel, ktorych sa zapis dotkne —
    // pouzivatel vidi rozsah akcie EST PRED tym, nez ju spusti.
    var btn = el('frontBulkApply');
    if (btn){
      var n = frontProfileScopeItems(items, frontProfileScopeNow()).length;
      btn.textContent = 'Použiť na ' + n;
      btn.disabled = !n;
    }
  }
  // D-130a R7: selecty popoveru su len NAVRH — zmena profilu/hrany NIC
  // NEZAPISUJE. Pred touto davkou zapisoval kazdy `change` (dva ovladace = dve
  // cesty, dva kroky Späť a hrana sa nedala zvolit „vopred"). Teraz sa len
  // prestavi ponuka hran a veta stavu.
  function onFrontProfilePick(){ refreshFrontProfileEdgeUI(frontRowsState()); }
  function onFrontProfileEdgePick(){ /* stav popoveru; zapisuje az „Použiť" */ }
  // JEDINY ZAPIS hromadnej uchytky. Profil aj hranu nasadi VSETKYM celam
  // rozsahu naraz — jeden `onField` = jeden apply = jeden krok Späť.
  function onFrontBulkApply(){
    var sel = el('frontProfileSel'); if (!sel) return;
    var id = sel.value;
    if (id === FRONT_PROFILE_MIXED) return; // stav, nie volba
    var eSel = el('frontProfileEdge');
    var items = frontRowsState(), scope = frontProfileScopeNow();
    // Hrana sa nasadzuje LEN ked je pre CELY rozsah platna (bocne hrany maju
    // dvierka a zasuvky rozne) — inak by zapis ulozil hranu, ktoru cast ciel
    // nema kam dat a server by ju aj tak zhodil.
    var edge = (eSel && eSel.value && frontProfileScopeEdges(items, scope).indexOf(eSel.value) >= 0)
      ? eSel.value : null;
    var changed = false;
    frontProfileScopeItems(items, scope).forEach(function(it){
      if ((it.profile || 'none') !== id){ frontRowProfileSet(it.row, id); changed = true; }
      if (edge && it.row.dataset.frontProfileEdge !== edge){
        it.row.dataset.frontProfileEdge = edge; changed = true;
      }
      updateFrontRowSummary(it.row);
    });
    closeFrontBulk();
    refreshFrontProfileUI();
    refreshFrontCards();
    if (!changed) return;   // „Použiť" nad uz nasadenym stavom = ziadny prazdny krok Spat
    renderPreview();        // pasmo profilu nad celom sa meni hned
    onField();
  }
  // --- popover „všetkým": otvorenie, zatvorenie, Escape, klik mimo ---------
  function frontBulkOpen(){ var p = el('frontBulkPop'); return !!(p && !p.hidden); }
  function openFrontBulk(){
    var p = el('frontBulkPop'); if (!p) return;
    // R7-c: popover je DIETA `<details>` (surodenec za hlavickou), takze pri
    // ZBALENEJ skupine ho prehliadac nevykresli vobec. Trigger preto skupinu
    // najprv OTVORI — inak by klik na „všetkým" navonok neurobil nic.
    var grp = (typeof p.closest === 'function') ? p.closest('details') : null;
    if (grp && !grp.open) grp.open = true;
    p.hidden = false;
    var b = el('frontBulkBtn'); if (b) b.setAttribute('aria-expanded', 'true');
    refreshFrontProfileUI();      // ponuka a veta patria PRAVE vykreslenym riadkom
    var s = el('frontProfileScope'); if (s && s.focus) s.focus();
  }
  function closeFrontBulk(){
    var p = el('frontBulkPop'); if (!p || p.hidden) return;
    // R7-b: fokus sa vracia na tlacidlo — ale LEN ked bol V POPOVERI. Pri
    // zatvoreni klikom mimo uz fokus patri tomu, na co pouzivatel klikol,
    // a stiahnut mu ho spat by bol skok, ktory nikto nezadal.
    var inside = false;
    try {
      var ae = document.activeElement;
      inside = !!(ae && typeof ae.closest === 'function' && ae.closest('#frontBulkPop'));
    } catch (e) { inside = false; }
    p.hidden = true;
    var b = el('frontBulkBtn');
    if (b){
      b.setAttribute('aria-expanded', 'false');
      if (inside && b.focus) b.focus();
    }
  }
  // Tlacidlo zije v `<summary>` — bez `preventDefault` by klik zbalil CELU
  // skupinu (natívne spravanie `<details>`) a popover by sa otvoril do zbalena.
  function onFrontBulkToggle(ev){
    nxTipStop(ev);
    if (frontBulkOpen()) closeFrontBulk(); else openFrontBulk();
  }
  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('mousedown', function(ev){
      if (!frontBulkOpen()) return;
      var t = ev.target;
      if (t && typeof t.closest === 'function' &&
          (t.closest('#frontBulkPop') || t.closest('#frontBulkBtn'))) return;
      closeFrontBulk();
    });
    // Codex #371 P2: Escape SPOTREBUJEME. Vsetky Escape listenery okna visia
    // na `document` a `stopPropagation` medzi nimi NEFUNGUJE (lekcia
    // `nx_esc.js`) — bez `stopImmediatePropagation` by jedno stlacenie zavrelo
    // popover AJ flyout z `boot.js` (warnpanel, rohove menu ABS, tagy), ktore
    // sa registruju NESKOR (`window.onload`). Pravidlo repa: jedno stlacenie =
    // NAJVYSSIA otvorena vrstva.
    //
    // PORADIE JE ZAMER: `nx_esc.js` je v `panel.html` NACITANY PRED `form.js`,
    // takze retaz modalov bezi PRVA a svoje Escape spotrebuje sama — modal
    // (z-index 60) je nad popoverom (125 v ramci skupiny, ale pod scrimom),
    // takze popover sa pod nim zatvarat nema.
    document.addEventListener('keydown', function(ev){
      if (!ev || ev.key !== 'Escape' || !frontBulkOpen()) return;
      closeFrontBulk(); // fokus sa vracia na tlacidlo (bol v popoveri)
      if (typeof ev.preventDefault === 'function') ev.preventDefault();
      if (typeof ev.stopImmediatePropagation === 'function') ev.stopImmediatePropagation();
    });
  }
  // D-120: karta aj hromadne ovladanie zapisuju tie iste dve item polia.
  function frontEdgeOptionsHtml(edges, value){
    var h = '';
    if (edges.indexOf(value) < 0) h += '<option value="" selected disabled>' +
      (value === null ? 'Rôzne' : 'Vyber hranu') + '</option>';
    edges.forEach(function(edge){ h += '<option value="' + edge + '"' +
      (edge === value ? ' selected' : '') + '>' + esc(FRONT_EDGE_LABELS[edge]) + '</option>'; });
    return h;
  }
  function frontRowProfileSet(row, id){
    if ((row.dataset.frontProfile || 'none') === 'none' && id !== 'none' &&
        frontProfileEdges(row.dataset.frontType).indexOf(row.dataset.frontProfileEdge) < 0)
      row.dataset.frontProfileEdge = 'top';
    row.dataset.frontProfile = id;
  }
  // D-130a R7: UCHYTKA v karte = JEDEN riadok (popisok + Profil + Hrana vedla
  // seba). Doteraz to boli DVA riadky pod sebou — na jeden udaj dva riadky
  // v kazdej karte je pri 470 px zbytocna dan.
  function frontProfileCardHtml(row){
    var type = row.dataset.frontType;
    if (frontProfileless(type) || !FRONT_PROFILES.length) return '';
    var id = row.dataset.frontProfile || 'none';
    var edge = row.dataset.frontProfileEdge === undefined ? 'top' : row.dataset.frontProfileEdge;
    var key = 'fp-' + row.dataset.frontId;
    var h = '<div class="prow fprofile-row"><span class="pl">Úchytka' +
      nxTipHtml('Profil skracuje panel pri zvolenej hrane; ABS aj smer dekoru zostávajú. ' +
                'Viacerým čelám naraz: „všetkým" v hlavičke skupiny Čelá.', 'inl') +
      '</span><span class="phalf">' +
      '<select id="' + esc(key) + '" aria-label="Úchytkový profil" data-pc="profile"' +
      ' onchange="onFrontCardProfile(this)">';
    frontProfileOptionList().forEach(function(o){ h += '<option value="' + esc(o.id) + '"' +
      (id === o.id ? ' selected' : '') + '>' + esc(o.name) + '</option>'; });
    h += '</select>' +
      '<select id="' + esc(key + '-edge') + '" aria-label="Hrana úchytky" data-pc="edge"' +
      (id === 'none' ? ' disabled' : '') + ' onchange="onFrontCardEdge(this)">' +
      frontEdgeOptionsHtml(frontProfileEdges(type), edge) + '</select></span></div>';
    return h;
  }
  function onFrontCardProfile(sel){
    var row = sel.closest('.frow'); if (!row) return;
    frontRowProfileSet(row, sel.value);
    updateFrontRowSummary(row); refreshFrontProfileUI(); refreshFrontCards(); onField();
  }
  function onFrontCardEdge(sel){
    var row = sel.closest('.frow'); if (!row || !sel.value) return;
    row.dataset.frontProfileEdge = sel.value;
    updateFrontRowSummary(row); refreshFrontProfileUI(); refreshFrontCards(); onField();
  }
  // Ponuka hran popoveru = PRIENIK hran platnych pre cely rozsah. Hint
  // „Bočné hrany nastav v karte čela" ZANIKOL (D-130a R9) — je to pomocny
  // text a zije v tooltipe `?` v hlavicke popoveru.
  function refreshFrontProfileEdgeUI(items){
    var sel = el('frontProfileEdge'); if (!sel) return;
    var scope = frontProfileScopeNow(), edges = frontProfileScopeEdges(items, scope);
    sel.innerHTML = frontEdgeOptionsHtml(edges, frontProfileCommon(items, scope, 'profile_edge'));
    sel.disabled = !edges.length;
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
  // Obnovia sa len bezpecne udaje viazane cez ID: placeholder ≈ vysky
  // a SUHRN riadku. Plny rebuild riadkov = zmena vyberu alebo echo bez
  // cakajucich editov.
  function renderFronts(fronts, keepGaps){
    renderFrontAddTypes();
    if (keepGaps){
      // D-130a: SUHRN (vratane badge „smer?" a textu kovania) je BEZPECNY udaj
      // viazany cez ID — obnovi sa aj pri light-update, kde sa riadky
      // NEPRESTAVUJU. Karta ostava otvorena a prekresli sa z cerstvych slotov.
      updateFrontRowSummaries();
      updateFrontMeta();
      updateCabfrontMeta(); // D-130b: meta skupiny „Spoločné pre skrinku"
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
    setNum('fr_gap_left', frontSideGap(fronts, 'gap_left'));
    setNum('fr_gap_right', frontSideGap(fronts, 'gap_right'));
    setEdgeLimitOff(!!(fronts && fronts.edge_limit_off));
    // KOV-A2a: badge „smer?" + otvorena karta patria k PRAVE vykresleným
    // riadkom. Karta sa drzi cez IDENTITU cela (`openFrontCardId`), nie cez
    // index — klik na segrow spusti apply, echo prestava riadky a karta by
    // pod rukou zmizla. Cielove celo uz v zozname byt nemusi (zmena vyberu,
    // zmazany riadok) — vtedy stav ticho zanikne.
    if (openFrontCardId && !frontRowById(openFrontCardId)) openFrontCardId = null;
    updateFrontRowSummaries();
    updateFrontMeta();
    updateCabfrontMeta(); // D-130b: meta skupiny „Spoločné pre skrinku"
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
  // D-130a R3: SUHRN RIADKU. Jeden tlmeny riadok pod nazvom cela —
  // „1 krídlo (auto) · smer? · bez úchytky · Sensys klasik · 2 ks →". Zlucil
  // tri veci, ktore boli predtym rozsypane po riadku: badge „smer?" (KOV-A2a),
  // indikator profilu `.fprof` (D-90) a samostatny riadok kovania `.fhw`
  // (UI-C3). Stav vsetkych ciel tak vidno bez otvarania kariet (D-130).
  //
  // Text sklada CISTE JADRO `frontRowSummary` (core.js) z tych istych zdrojov
  // ako doteraz: dataset riadku, `front_slots` a hotovy text kovania (badge
  // z planu `frontHwBadge` + nakupny rozpis servera `frontHwBuy`, D-92).
  // Panel NIC NEDOPOCITAVA a ziadne nove data neprisli.
  //
  // Obnova bezi tam, kde doteraz bezali badge (light push aj plny render) —
  // je to BEZPECNY udaj viazany cez ID, takze riadky sa NEPRESTAVUJU (D-23
  // `keepGaps` guard). `.fsub` sa hlada VYHRADNE cez triedu, nikdy cez index.
  function frontRowItem(row){
    var item = frontExtraOf(row);
    item.type = row.dataset.frontType || 'door';
    item.wings = row.dataset.frontWings || 'auto';
    item.profile = row.dataset.frontProfile || 'none';
    if (row.dataset.frontProfileEdge !== undefined) item.profile_edge = row.dataset.frontProfileEdge;
    return item;
  }
  function updateFrontRowSummary(row){
    var sub = row.querySelector('.fsub'); if (!sub) return;
    var fid = row.dataset.frontId;
    var badge = (typeof frontHwBadge === 'function') ? frontHwBadge(fid) : null;
    var buy = (typeof frontHwBuy === 'function') ? frontHwBuy(fid) : null;
    var hw = [badge, buy].filter(function(t){ return !!t; }).join(' → ');
    var parts = frontRowSummary(frontRowItem(row), frontSlotsOf(fid), hw, FRONT_PROFILES,
                                frontDrawerOf(fid));
    var html = '', plain = [], hwText = '';
    parts.forEach(function(p){
      // R3-f: kovanie NIE JE cast textu suhrnu — je to SURODENE tlacidlo.
      if (p.hw){ hwText = p.hw; plain.push(p.hw); return; }
      if (html) html += '<span class="fsep">·</span>';
      if (p.badge){ html += '<span class="fbadge">' + esc(p.badge) + '</span>'; plain.push(p.badge); return; }
      html += (p.tone ? '<span class="fbadge">' + esc(p.text) + '</span>'
                      : esc(p.text));
      plain.push(p.text);
    });
    sub.innerHTML = html; // B3/B9: ikona staticka, kazdy text cez esc
    // Riadok je JEDNORIADKOVY s ellipsis — plne znenie nesie `title` (vzor D-92).
    sub.title = plain.join(' · ') + ' — klik otvorí kartu čela';
    sub.setAttribute('aria-label', 'Čelo ' + (fid || '') + ': ' + plain.join(', ') +
                     ' — otvoriť kartu');
    // R3-e/R3-f: koncovka kovania = VLASTNE, FOKUSOVATELNE tlacidlo vedla
    // suhrnu. Klik NEotvara kartu na tabe Čelo (to robi suhrn), ale rovno na
    // tabe KOVANIE; prepnutie kontextu je az tlacidlo „Otvoriť v Kovaní"
    // v tom tabe (N13: klikatelne vedie tam, kam ukazuje).
    var link = row.querySelector('.fhwlink');
    if (!link) return;
    link.hidden = !hwText;
    if (!hwText){ link.innerHTML = ''; return; }
    link.innerHTML = esc(hwText) + NXIcons.svg('arrow-right');
    link.title = hwText + ' — klik otvorí kartu na tabe Kovanie';
    link.setAttribute('aria-label', 'Kovanie tohto čela — otvoriť tab Kovanie');
  }
  function updateFrontRowSummaries(){
    var wrap = el('frontRows'); if (!wrap) return;
    var rows = wrap.querySelectorAll('.frow');
    for (var i = 0; i < rows.length; i++) updateFrontRowSummary(rows[i]);
  }
  // D-130a R1: META v hlavicke skupiny („3 čelá · 1 bez smeru"). Pocet ciel
  // cita z DOM, „bez smeru" VYHRADNE zo servera (`front_slots`) — bez slotov
  // ostane len pocet a nic sa neodvodzuje.
  function updateFrontMeta(){
    var node = el('frontMeta'); if (!node) return;
    var wrap = el('frontRows');
    var rows = wrap ? wrap.querySelectorAll('.frow') : [];
    var n = rows.length, unset = 0;
    for (var i = 0; i < n; i++){
      var entry = frontSlotsOf(rows[i].dataset.frontId);
      if (entry && frontDirBadge(entry.slots)) unset++;
    }
    var word = (n === 1) ? 'čelo' : (n < 5 ? 'čelá' : 'čiel');
    node.textContent = n ? (n + ' ' + word + (unset ? ' · ' + unset + ' bez smeru' : '')) : '';
  }
  // Klik na naviazane kovanie: prepni kontext na Kovanie a dotiahni do pohladu
  // BOX VLASTNIKA tohto cela. Ziadny zapis — je to navigacia (N13: klikatelne
  // vedie tam, kam ukazuje).
  function openFrontHardware(fid){
    if (!fid) return;
    // UI-C4: cielom skoku je BOX VLASTNIKA (`.hwbox[data-group="front:<id>"]`),
    // nie jednotlivy riadok — kluc skupiny sklada `hwFrontGroup`, teda JEDINE
    // miesto konvencie, takze sa doskocenie a render nemozu rozist.
    //
    // Codex #371 P2: ciel sa overuje PRED prepnutim kontextu. Predtym sa
    // kontext prepol vzdy a pri chybajucom boxe pouzivatel skoncil v Kovani
    // s hlaskou „toto celo kovanie nema" — teda inde, nez kde klikol, a bez
    // cesty spat. Neuspesny skok teraz NEMENI kontext.
    var target = (typeof hwBoxByGroup === 'function') ? hwBoxByGroup(hwFrontGroup(fid)) : null;
    if (!target){ NX.setStatus('Toto čelo zatiaľ nemá naviazané kovanie.', false); return; }
    if (typeof setViewContext === 'function') setViewContext('kovanie');
    if (typeof nxRevealTarget === 'function') nxRevealTarget(target);
    target.scrollIntoView({ block: 'nearest' });
    // Kratke zvyraznenie: bez neho by pouzivatel po skoku hladal, KTORY box je
    // ten jeho (poloziek kovania byva viac, nez sa zmesti na obraz).
    hwFlash(target);
  }
  // KOV-A2b DEEP-LINK: „klik na RED nález smeru v Kontrole otvorí kartu čela".
  // Server posiela LEN ID cela (`NX.focusFront`) — VSETKO ostatne je klientske:
  // prepni kontext na Cela, otvor kartu prave tohto cela, rozbal cestu k nemu
  // a doscrolluj. Ked riadok neexistuje (medzitym prestavana skrinka, iny
  // vyber), NEROBI SA NIC — falosne otvorena cudzia karta by klamala.
  // Vracia true/false, aby sa cesta dala overit v Node testoch.
  function nxFocusFront(fid){
    var id = (fid == null) ? '' : String(fid);
    if (!id) return false;
    var row = frontRowById(id);
    if (!row) return false;
    if (typeof setViewContext === 'function') setViewContext('cela');
    openFrontCardId = id;
    // Codex #371 P2: deep-link z RED nalezu SMERU vedie na otazku, ktora zije
    // v tabe Čelo. Bez resetu by sa cielova karta otvorila na tabe Kovanie —
    // stav ostal po PREDCHADZAJUCEJ karte — a pouzivatel by po kliku na nalez
    // videl vyriesny set namiesto segmentu smeru. Tab je stav prace nad
    // JEDNYM celom, takze kazde otvorenie INEJ karty zacina na Čele.
    openFrontCardTab = 'celo';
    refreshFrontCards();
    if (typeof nxRevealTarget === 'function') nxRevealTarget(row);
    if (row.scrollIntoView) row.scrollIntoView({ block: 'nearest' });
    var btn = row.querySelector('.ftname');
    if (btn && btn.focus) btn.focus();
    // KOV-D4: kratke prisvietenie riadku — ten isty vzor ako skok do Kovania
    // (`hwFlash`, trieda `hwfocus`). Bez neho pouzivatel po skoku hlada, KTORY
    // z riadkov ciel je „jeho": karta sa otvori, ale zoznam moze byt dlhy.
    if (typeof hwFlash === 'function') hwFlash(row);
    return true;
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
                       // KOV-I: mini-DOM overuje skutocny modal a existujuci hint.
                       nxTplHardwareText: nxTplHardwareText, nxTplHardwareBadge: nxTplHardwareBadge,
                       openSaveTemplateModal: openSaveTemplateModal, closeSaveTemplateModal: closeSaveTemplateModal,
                       saveTemplateAs: saveTemplateAs, setTplMeta: setTplMeta,
                       // UI-D2: dlazdica s PNG nahladom — kluc cache, ciste jadro
                       // pull/cache rozhodovania a nasadenie obrazka na dlazdicu.
                       tplPrevKey: tplPrevKey, tplPicHtml: tplPicHtml, tplTileHtml: tplTileHtml,
                       nxTplPreviewPlan: nxTplPreviewPlan, nxTplPreviewStore: nxTplPreviewStore,
                       tplBindPreview: tplBindPreview,
                       // KOV-A2a: cesta „riadok -> karta -> collectFronts" sa da
                       // overit LEN nad skutocnym DOM (mini-DOM sady). V CEF su
                       // tieto funkcie GLOBALNE (volaju ich inline `onclick`
                       // v markupe riadku), v Node ich treba vyviest vyslovne.
                       // Ziadna z nich nie je „ciste jadro" — logika zije
                       // v `core.js`, tu sa len napaja na DOM.
                       addFrontRow: addFrontRow, collectFronts: collectFronts,
                       onFrontCardToggle: onFrontCardToggle, onFrontTile: onFrontTile,
                       onFrontSeg: onFrontSeg, onFrontWings: onFrontWings,
                       frontExtraOf: frontExtraOf, refreshFrontCards: refreshFrontCards,
                       updateFrontDirBadges: updateFrontDirBadges,
                       // D-130a: suhrn riadku, meta hlavicky, taby karty
                       // a POPOVER „všetkým" (akcia, nie druhy stav).
                       updateFrontRowSummary: updateFrontRowSummary,
                       updateFrontRowSummaries: updateFrontRowSummaries,
                       updateFrontMeta: updateFrontMeta, frontRowItem: frontRowItem,
                       onFrontCardTab: onFrontCardTab, onFrontSummaryHw: onFrontSummaryHw,
                       nxTipStop: nxTipStop,
                       onFrontOpenHardware: onFrontOpenHardware,
                       openFrontHardware: openFrontHardware,
                       openFrontBulk: openFrontBulk, closeFrontBulk: closeFrontBulk,
                       onFrontBulkToggle: onFrontBulkToggle, frontBulkOpen: frontBulkOpen,
                       onFrontBulkApply: onFrontBulkApply,
                       onFrontProfilePick: onFrontProfilePick,
                       onFrontProfileEdgePick: onFrontProfileEdgePick,
                       onFrontProfileScope: onFrontProfileScope,
                       refreshFrontProfileUI: refreshFrontProfileUI,
                       onFrontCardProfile: onFrontCardProfile, onFrontCardEdge: onFrontCardEdge,
                       addFrontKind: addFrontKind, syncFrontCardOwner: syncFrontCardOwner,
                       closeFrontCard: closeFrontCard,
                       // KOV-A2b: deep-link zo Studia (`NX.focusFront`).
                       nxFocusFront: nxFocusFront,
                       // D-130b: skupina „Spoločné pre skrinku" — zamok limitu
                       // a reset su IKONY v <summary> (inline `onclick`), meta
                       // hlavicky kresli panel z ciseho textu core.js.
                       toggleEdgeLimit: toggleEdgeLimit, setEdgeLimitOff: setEdgeLimitOff,
                       resetFrontGaps: resetFrontGaps, updateCabfrontMeta: updateCabfrontMeta,
                       cabfrontDecorName: cabfrontDecorName };
  }

