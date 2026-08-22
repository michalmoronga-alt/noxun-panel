  // V0.5 B: otvorenie okna Vyroba (kusovnik/supisy). Najprv flush cakajucich
  // editov korpusu/dosky (Codex GH #48 P2) — BOM sa pocita az z cerstveho stavu
  // (callbacky sa spracuju v poradi: apply -> open -> push_state).
  // UI-D3: volitelny DEEP-LINK — `tab` otvori okno rovno na danom tabe
  // (`rows` kusovnik, `control` kontrola…). Bez neho sa tab NEPREPINA a
  // pouzivatel ostane tam, kde naposledy skoncil (rail Štúdio). Hodnotu
  // preosieva NXShell.studioLink, ZAVAZNY whitelist je na strane Ruby.
  function openProductionDialog(tab){
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
    if (window.sketchup && sketchup.open_production)
      sketchup.open_production(JSON.stringify(NXShell.studioLink(tab)));
  }

  // ST-1a: otvorenie okna ŠTÚDIO. Rovnaky flush handshake ako pri Vyrobe —
  // kusovnik sa pocita az z cerstveho stavu. `section` je volitelny deep-link
  // (bez neho okno ostane tam, kde pouzivatel naposledy skoncil) a `anchor`
  // predvyplni hladanie sekcie (N13 posiela ID skrinky). ZAVAZNY whitelist
  // sekcii je na strane Ruby — tu sa hodnota len preosieva.
  function openStudio(section, anchor){
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (typeof flushBoardEditsNow === 'function') flushBoardEditsNow();
    if (window.sketchup && sketchup.open_studio)
      sketchup.open_studio(JSON.stringify(NXShell.studioOpenLink(section, anchor)));
  }

  // ===================== ZONA UI (akcie / rozmery poli) =====================
  // UI-C2: kontext Zony ma STATICKU kostru (Struktura · Delenie · Police · Vnutro)
  // a JS meni LEN obsah #zoneTree / #zoneFields a stavy uz existujucich uzlov.
  //
  // KLUCOVE PRAVIDLO KONTEXTU: dlazdice delenia aj pilulky polic su AKTIVNE LEN
  // NA LISTOVEJ zone. Na delenej zone su viditelne, ale neaktivne s vysvetlenim —
  // opakovane delenie by ticho zmazalo cely podstrom aj s materialmi a ABS
  // dielcov. Jedina destruktivna cesta je „Vycistit zonu". To iste pravidlo
  // vynucuje SERVER (`actions_zones.rb`) — HTML `disabled` nie je ochrana stavu.
  // Naopak pole „Prva zona" ma zmysel len na DELENEJ zone (edituje jej pole 1).
  var ZONE_TILE_HINT_SPLIT = 'Zóna je delená — najprv „Vyčistiť zónu", potom ju rozdeľ nanovo.';
  var ZONE_TILE_HINT_DEPTH = 'Hlbšie delenie sa nedá — strom zón má najviac 3 úrovne.';

  function activeZoneOf(zones){
    var z = null;
    zones.forEach(function(x){ if (fullZoneId(x.id) === activeZoneId) z = x; });
    return z;
  }
  function refreshZoneUI(){
    var zones = computeZones();
    var z = activeZoneOf(zones);
    // D-03 (Codex F2): karta zony patri k zonovemu nahladu — v inych kontextoch
    // sa skupiny sice nezobrazuju (CSS podla data-view-ctx), ale stav ovladacov
    // sa aj tak nesmie tvarit aktivny.
    if (previewMode !== 'zones'){ applyZoneState(null); renderZoneTree(zones); return; }
    // D-03: jednozonova skrinka = karta rovno (discoverability polic). Podmienka !z
    // pokryva prazdne AJ neplatne stale ID (Codex F3). Lokalny vyber — select_zone
    // do modelu sa neposiela (to robi len klik v pickZone). Pri vkladani DOSKY sa
    // auto-select nespusta (Codex GH #42: karta zony by visela nad board formularom
    // a ovladala skryty korpusovy draft — CSS skrytie nie je ochrana stavu).
    if (!z && zones.length === 1 && zones[0].leaf &&
        !(!selectedCabId && getInsertKind() === 'board')){
      activeZoneId = fullZoneId(zones[0].id);
      z = zones[0];
      renderPreview(); // nahlad sa kreslil pred auto-selectom — zvyrazni zonu (Codex F1)
    }
    applyZoneState(z);
    renderZoneTree(zones);
  }

  // Jedno miesto, kde sa stav kontextu Zony premieta do statickej kostry.
  function applyZoneState(z){
    var head = el('zoneActive');
    var leaf = !!(z && z.leaf);
    var deep = !!(z && z.path.length >= NXZ.MAX_LEVELS);
    if (head) head.textContent = z
      ? (z.label + ' — ' + mmLabel(z.w) + ' × ' + mmLabel(z.h) + ' mm'
         + (leaf ? '' : (' · delená ' + (z.split.axis === 'h' ? 'vodorovne' : 'zvislo') + ' ×' + z.split.count)))
      : 'Žiadna označená zóna.';

    // Dlazdice delenia: aktivne len na liste a len do MAX_LEVELS urovni.
    var why = !z ? 'Najprv označ zónu.' : (!leaf ? ZONE_TILE_HINT_SPLIT : (deep ? ZONE_TILE_HINT_DEPTH : ''));
    var tiles = document.querySelectorAll('#zoneTiles .ztile');
    for (var i = 0; i < tiles.length; i++) setZoneCtl(tiles[i], !why, why);

    // Pilulky polic: to iste pravidlo (police su modul LISTOVEJ zony).
    renderShelfPills(leaf ? (z.shelves || 0) : 0);
    var pwhy = !z ? 'Najprv označ zónu.'
                  : (!leaf ? 'Zóna je delená — police patria konkrétnemu stĺpcu/riadku. Označ zónu vnútri.' : '');
    var pills = document.querySelectorAll('#zoneShelfPills button');
    for (var p = 0; p < pills.length; p++) setZoneCtl(pills[p], !pwhy, pwhy);
    var phint = el('zoneShelfHint');
    if (phint) phint.textContent = pwhy || ('Police sa rozložia rovnomerne (0–' + NXZ.MAX_SHELVES +
      ') a hneď sa prekreslia v náhľade aj v strome.');

    // Presna cesta (pole „Prva zona" + rozmery vsetkych poli) zije na DELENEJ zone.
    renderZoneFields(leaf ? null : z);
    var first = el('zoneFirst'), pre = el('zoneFirstPre');
    var firstOn = !!(z && !leaf);
    if (first){
      first.disabled = !firstOn;
      if (!nxFieldBusy || !nxFieldBusy(first)){
        var c0 = firstOn ? (z.split.cuts[0] || { size: null }) : { size: null };
        first.value = (firstOn && c0.size != null) ? mmLabel(c0.size) : '';
      }
    }
    if (pre) setZoneCtl(pre, firstOn, firstOn ? '' : 'Zlomky sa dajú použiť až na delenej zóne.');
    var clean = el('zoneCleanBtn');
    if (clean) setZoneCtl(clean, !!z, z ? '' : 'Najprv označ zónu.');
    var hint = el('zoneSplitHint');
    if (hint) hint.textContent = firstOn
      ? 'Zadaná hodnota pole 1 zamkne — prázdne pole je AUTO. Priečku vieš ťahať aj v náhľade (magnet 1/4 · 1/2 · 3/4, Alt ho vypne).'
      : 'Vyber delenie dlaždicou. Presný rozmer prvej zóny sa zadáva až po rozdelení.';
  }
  // Neaktivny prvok je `aria-disabled` + trieda (vzor D-78) — HTML `disabled`
  // by zhltol hover aj tooltip a pouzivatel by sa dovod nedozvedel.
  function setZoneCtl(node, on, why){
    if (!node) return;
    node.classList.toggle('off', !on);
    node.setAttribute('aria-disabled', on ? 'false' : 'true');
    if (on) node.removeAttribute('title'); else node.setAttribute('title', why || '');
  }
  function zoneCtlOn(node){ return !!node && node.getAttribute('aria-disabled') !== 'true'; }

  function renderShelfPills(current){
    var box = el('zoneShelfPills'); if (!box) return;
    var want = NXZ.MAX_SHELVES + 1;
    if (box.children.length !== want){
      box.innerHTML = '';
      for (var n = 0; n <= NXZ.MAX_SHELVES; n++){
        var b = document.createElement('button');
        b.type = 'button'; b.textContent = String(n);
        b.setAttribute('data-n', String(n));
        b.setAttribute('aria-label', n + ' políc v zóne');
        box.appendChild(b);
      }
    }
    for (var i = 0; i < box.children.length; i++)
      box.children[i].classList.toggle('on', i === (current || 0));
  }

  // Riadky poli cez data-atributy + delegaciu (setupFieldEditorDelegation) — ziadne inline
  // handlery na prerendrovanych elementoch (poucenie z drag bugu).
  function renderZoneFields(z){
    var box = el('zoneFields'); if (!box) return;
    if (!z || !z.split){ box.innerHTML = ''; return; }
    var html = '<div class="hint">Rozmery všetkých polí (mm). ' + NXIcons.svg('lock', 'ic-inline') + ' = drží rozmer pri zmene korpusu.</div>';
    var axisLbl = (z.split.axis==='h') ? 'Riadok' : 'Stĺpec';
    for (var i=0;i<z.split.count;i++){
      var c = z.split.cuts[i] || {size:null,locked:false};
      var sz = mmLabel(nxRound2(z.split.sizes[i]));
      html += '<div class="fldrow"><span class="fldn">'+axisLbl+' '+(i+1)+'</span>' +
        '<input type="text" value="'+sz+'" data-zid="'+esc(z.id)+'" data-idx="'+i+'">' +
        '<div class="lockbtn'+(c.locked?' on':'')+'" title="Zamknúť rozmer" role="button" aria-label="Zamknúť rozmer" aria-pressed="'+(c.locked?'true':'false')+'" data-zid="'+esc(z.id)+'" data-idx="'+i+'">'+NXIcons.svg(c.locked?'lock':'lock-open')+'</div></div>';
    }
    box.innerHTML = html;
    // V0.4.7e: vyrazy v poliach zon — commit (Enter/blur) prepise pole cislom
    // a dispatchne 'change', ktory chyti delegacia nizsie.
    box.querySelectorAll('input[data-zid]').forEach(function(inp){
      attachExprField(inp, { commitEv: 'change' });
    });
  }
  // Jeden listener na kontajneri — prezije kazdy re-render riadkov.
  var fieldEditorBound = false;
  function setupFieldEditorDelegation(){
    if (fieldEditorBound) return;
    var box = el('zoneFields'); if (!box) return;
    box.addEventListener('change', function(ev){
      var t = ev.target;
      if (t && t.tagName === 'INPUT' && t.getAttribute('data-zid'))
        setFieldSize(t.getAttribute('data-zid'), parseInt(t.getAttribute('data-idx'), 10), t.value);
    });
    box.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'lockbtn');
      if (t && t.getAttribute('data-zid'))
        toggleFieldLock(t.getAttribute('data-zid'), parseInt(t.getAttribute('data-idx'), 10), t);
    });
    // Dlazdice delenia + pilulky polic: tiez delegaciou, na STATICKYCH uzloch.
    var tiles = el('zoneTiles');
    if (tiles) tiles.addEventListener('click', function(ev){
      var t = closestClass(ev.target, 'ztile'); if (!t) return;
      if (!zoneCtlOn(t)){ NX.setStatus(t.getAttribute('title') || 'Táto akcia tu nie je možná.', true); return; }
      splitZone(t.getAttribute('data-axis'), parseInt(t.getAttribute('data-count'), 10));
    });
    var pills = el('zoneShelfPills');
    if (pills) pills.addEventListener('click', function(ev){
      var t = ev.target; while (t && t !== pills && t.tagName !== 'BUTTON') t = t.parentNode;
      if (!t || t === pills || !t.getAttribute) return;
      if (!zoneCtlOn(t)){ NX.setStatus(t.getAttribute('title') || 'Táto akcia tu nie je možná.', true); return; }
      setZoneShelves(parseInt(t.getAttribute('data-n'), 10));
    });
    var first = el('zoneFirst');
    if (first){
      attachExprField(first, { commitEv: 'change' });
      first.addEventListener('change', function(){ setZoneFirstSize(first.value); });
    }
    fieldEditorBound = true;
  }

  // --- zlomkove presety pola „Prva zona" (N21) -------------------------------
  // Ponuka sa sklada zo ZDIELANEJ geometrie (nxZoneFractionOptions) — to iste
  // pocitanie, ake pouziva magnet tahania priecky, takze sa cislo v poli a
  // poloha priecky nemozu rozist. Nedosiahnutelny zlomok sa neponuka.
  function toggleZoneFractions(ev){
    if (ev) ev.stopPropagation();
    var box = el('zoneFracOpts'), btn = el('zoneFirstPre');
    if (!box) return;
    if (!zoneCtlOn(btn)){ NX.setStatus(btn.getAttribute('title') || '', true); return; }
    // Otvorena je vzdy NAJVIAC JEDNA mini-ponuka v paneli (vzor rozmerovych
    // radov N6) — zatvara ju spolocny `nxDimCloseMenus` aj klik mimo nej.
    var wasOn = box.classList.contains('on');
    if (typeof nxDimCloseMenus === 'function') nxDimCloseMenus(); else box.classList.remove('on');
    if (wasOn) return;
    var z = activeZoneOf(computeZones());
    if (!z || z.leaf) return;
    var t = numv('thickness')||18;
    var span = (z.split.axis === 'v') ? z.w : z.h;
    var opts = nxZoneFractionOptions(span, z.split.count, t, 0, NXZ.FIELD_FRACTIONS);
    if (!opts.length){ NX.setStatus('Žiadny zo zlomkov sa do tejto zóny nezmestí.', true); return; }
    box.innerHTML = '';
    opts.forEach(function(o){
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = mmLabel(o.cum) + ' (' + o.label + ')';
      b.onclick = function(e){ e.stopPropagation(); box.classList.remove('on'); setZoneFirstSize(o.cum); };
      box.appendChild(b);
    });
    box.classList.add('on');
  }
  // Pole „Prva zona" = SKRATKA na pole 1 (B5): zadana hodnota pole ZAMKNE,
  // prazdne pole ho odomkne. Per-pole zamky v zozname nizsie ostavaju v platnosti.
  function setZoneFirstSize(value){
    var z = activeZoneOf(computeZones());
    if (!z || z.leaf){ NX.setStatus('Presný rozmer sa zadáva až na delenej zóne.', true); return; }
    setFieldSize(z.id, 0, (value === null || value === undefined) ? '' : String(value), true);
  }
  // PRESNA CESTA (N21, audit F7): zadane cislo sa BUD zmesti, ALEBO sa odmietne.
  // Ziadne tiche zmensovanie — pouzivatel by vyrobil iny nabytok, nez zadal.
  // Zvysok sa deterministicky dorovna do posledneho odomknuteho pola a vsetko
  // sa uklada s presnostou 0,01 mm (mm Float; zaokruhlovanie na cele mm by pri
  // troch poliach „zjedlo" z korpusu az 2 mm).
  // `lockEdited` (Codex #177 P2): zámok editovaného poľa. VYNECHANÝ = ponechaj
  // ten, ktorý pole má — cez túto funkciu chodí aj úplný zoznam polí, kde má
  // zámok VLASTNÝ ovládač; natvrdo `true` by vedome odomknutý riadok pri každom
  // prepísaní hodnoty potichu zamkol a ten by potom držal rozmer pri resize
  // korpusu. `true` posiela iba skratka „Prvá zóna" (B5: vypísané ⇒ zamknuté).
  function setFieldSize(localId, index, value, lockEdited){
    var node0 = navTree(sanitizeTree(currentZoneTree), pathOf(localId));
    if (!node0 || !node0.split) return;
    var curCut = node0.split.cuts[index] || { size: null, locked: false };
    var lock = (lockEdited === undefined) ? !!curCut.locked : !!lockEdited;
    // V0.4.7e: evalDim (vyraz uz je commitnuty na cislo, toto je belt-and-braces);
    // neplatny vstup NEmeni strom (parseFloat by '650-36' orezal na 650)
    var sz = (value===''||value===null||value===undefined) ? null : evalDim(value);
    if (sz !== null && isNaN(sz)){ NX.setStatus('Rozmer poľa nie je platné číslo.', true); return; }
    if (sz==null){
      // auto: toto pole na nil (ostatne necham; resolve ho rovnomerne dopocita)
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localId));
      node.split.cuts[index] = { size:null, locked:false }; currentZoneTree = tree;
    } else {
      var z = null; computeZones().forEach(function(x){ if (x.id===localId && x.split) z = x; });
      if (!z) return;
      var t = numv('thickness')||18;
      var span = (z.split.axis==='v') ? z.w : z.h;
      var clear = nxZoneClear(span, z.split.count, t);
      var res = nxZoneExactCuts(node0.split.cuts, z.split.sizes, z.split.count, clear, index, sz, lock);
      if (res.error){
        NX.setStatus('Pole ' + (index+1) + ': ' + res.error, true);
        refreshZoneUI(); // vrat do poli hodnoty, ktore naozaj platia
        return;
      }
      var tr = sanitizeTree(currentZoneTree); var nd = navTree(tr, pathOf(localId));
      nd.split.cuts = res.cuts; currentZoneTree = tr;
    }
    renderPreview();
    if (selectedCabId) pushFieldCuts(localId, index);
    else { refreshZoneUI(); nxDraftChanged(); }
  }
  function toggleFieldLock(localId, index, elBtn){
    var node0 = navTree(sanitizeTree(currentZoneTree), pathOf(localId));
    if (!node0 || !node0.split) return;
    var cur = node0.split.cuts[index] || { size:null, locked:false };
    var newLocked = !cur.locked;
    var sizes = null; computeZones().forEach(function(z){ if(z.id===localId && z.split) sizes=z.split.sizes; });
    var anchorSize = (cur.size!=null) ? cur.size : (sizes ? Math.round(sizes[index]) : null);
    // fix #5: kotva na aktualny rozmer pola + persistni cely layout so zmenenym lockom
    persistLayout(localId, index, anchorSize, newLocked);
    renderPreview();
    if (selectedCabId) pushFieldCuts(localId, index);
    else { refreshZoneUI(); nxDraftChanged(); }
  }

  // --- strom zon so STROMOVYMI SPOJNICAMI (kontrakt UI 2.0) ------------------
  // Vnorenie sa stavia z ciest (zoznam z computeZones je pre-order DFS): kazda
  // uroven dostane vlastny kontajner `.zkids`, ktoremu spojnice kresli CSS.
  // Odsadenie paddingom by ziadnu spojnicu nakreslit nevedelo.
  //
  // NOTE 14: klikatelne su LEN skutocne zony. Uroven nad MAX_LEVELS (legacy
  // strom alebo sablona z inej verzie) sa kresli VAROVNYM riadkom bez kliku —
  // nedeli sa, ale ani sa neoreze (orezanie by zmazalo dielce zakazky).
  function renderZoneTree(zones){
    var c = el('zoneTree'); if (!c) return;
    c.innerHTML = '';
    if (!zones || !zones.length){ c.innerHTML = '<div class="muted">Žiadny označený korpus.</div>'; return; }
    var boxes = [c];
    zones.forEach(function(z){
      var depth = z.path.length - 1;
      var host = boxes[depth] || c;
      var div = document.createElement('div');
      var deep = z.path.length > NXZ.MAX_LEVELS;
      div.className = 'znode' + (deep ? ' deep' : '') + (fullZoneId(z.id) === activeZoneId ? ' active' : '');
      var info = z.leaf ? (z.shelves>0 ? (z.shelves + ' ' + shelfWord(z.shelves)) : 'prázdna')
                        : ('delená ' + (z.split.axis==='h'?'vodorovne':'zvislo') + ' ×' + z.split.count);
      div.innerHTML = '<b>' + esc(z.label) + '</b> <span class="dim">' + mmLabel(z.w) + ' × ' + mmLabel(z.h) +
        '</span> <span class="zs">' + info + '</span>' +
        (deep ? '<span class="zwarn" title="Táto úroveň je nad podporovanými 3 úrovňami — ostáva zachovaná, ale nedá sa deliť">' +
                NXIcons.svg('alert', 'ic-inline') + ' 4. úroveň</span>' : '');
      if (deep){ div.setAttribute('aria-disabled', 'true'); }
      else { div.onclick = (function(zz){ return function(){ pickZone(zz.id); }; })(z); }
      host.appendChild(div);
      var kids = document.createElement('div');
      kids.className = 'zkids';
      host.appendChild(kids);
      boxes[depth + 1] = kids;
    });
  }
  function shelfWord(n){ return n === 1 ? 'polica' : (n < 5 ? 'police' : 'políc'); }

  // Klientske zrkadlo serverovych guardov (audit F10): draft rezim vkladania
  // nema server, takze rovnake pravidla musia platit LOKALNE — inak by sa dala
  // v navrhu postavit struktura, ktoru skrinka po vlozeni odmietne.
  function zoneGuard(what){
    if (!activeZoneId){ NX.setStatus('Najprv označ zónu.', true); return null; }
    var z = activeZoneOf(computeZones());
    if (!z){ NX.setStatus(what + ' — označená zóna už neexistuje. Klikni na zónu znova.', true); return null; }
    return z;
  }
  function splitZone(axis, count){
    var z = zoneGuard('Zóna sa nerozdelila'); if (!z) return;
    axis = (axis === 'h') ? 'h' : 'v';
    count = Math.min(NXZ.MAX_FIELDS, Math.max(2, parseInt(count, 10) || 2));
    if (!z.leaf){ NX.setStatus(ZONE_TILE_HINT_SPLIT, true); return; }
    if (z.path.length >= NXZ.MAX_LEVELS){ NX.setStatus(ZONE_TILE_HINT_DEPTH, true); return; }
    if (selectedCabId){
      if (window.sketchup && sketchup.split_zone)
        sketchup.split_zone(nxZonePayload({ zone_id: activeZoneId, axis: axis, count: count }));
    } else {
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localZoneId(activeZoneId)));
      if (node){
        node.generation = (node.generation || 0) + 1;
        node.split={axis:axis,count:count,cuts:sanitizeCuts(null,count)};
        node.shelves=0;
        node.children=[];
        for(var i=0;i<count;i++) node.children.push(defaultTree(0, newStableId('Z')));
      }
      currentZoneTree = tree; renderPreview(); refreshZoneUI(); nxDraftChanged();
    }
  }
  function setZoneShelves(n){
    var z = zoneGuard('Police sa nenastavili'); if (!z) return;
    n = Math.min(NXZ.MAX_SHELVES, Math.max(0, parseInt(n, 10) || 0));
    if (!z.leaf){ NX.setStatus('Zóna je delená — police patria konkrétnemu stĺpcu/riadku.', true); return; }
    // Codex #177 P2: ZMESTIA SA vôbec? Zrkadlo `ZoneTree.validate_shelves!` —
    // n polic potrebuje n*hrúbka + (n+1)*MIN_FIELD svetlej výšky. Kontrola stojí
    // PRED vetvou draft/server, takže platí aj v návrhu vkladania, kde server
    // neexistuje: bez nej by nový počet 5–6 ticho prekreslil náhľad a skrinka by
    // sa potom nedala vložiť (builder ju odmietne až na konci).
    var tth = numv('thickness') || 18;
    var needMm = n * tth + (n + 1) * NXZ.MIN_FIELD;
    if (n > 0 && needMm > z.h + NXZ.EPS){
      NX.setStatus('Zóna je príliš nízka na ' + n + ' ' + shelfWord(n) + ' — potrebuje aspoň ' +
                   Math.ceil(needMm) + ' mm svetlej výšky (má ' + Math.round(z.h) + ' mm).', true);
      return;
    }
    if (selectedCabId){
      if (window.sketchup && sketchup.set_zone_shelves)
        sketchup.set_zone_shelves(nxZonePayload({ zone_id: activeZoneId, count: n }));
    } else {
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localZoneId(activeZoneId)));
      if (node){ node.split=null; node.children=[]; node.shelves=n; }
      currentZoneTree = tree; renderPreview(); refreshZoneUI(); nxDraftChanged();
    }
  }
  function cleanZone(){
    if (!zoneCtlOn(el('zoneCleanBtn'))){ NX.setStatus('Najprv označ zónu.', true); return; }
    var z = zoneGuard('Zóna sa nevyčistila'); if (!z) return;
    if (selectedCabId){
      if (window.sketchup && sketchup.clean_zone)
        sketchup.clean_zone(nxZonePayload({ zone_id: activeZoneId }));
    } else {
      var tree = sanitizeTree(currentZoneTree); var node = navTree(tree, pathOf(localZoneId(activeZoneId)));
      if (node){ node.split=null; node.children=[]; node.shelves=0; }
      currentZoneTree = tree; renderPreview(); refreshZoneUI(); nxDraftChanged();
    }
  }

  // --- korpus akcie ---
  function insertCabinet(){
    // V0.4.7e (Codex GH #35): vlozenie MUSI prejst validaciou — neplatny rozmer
    // ('650mm') by sa inak ticho zmenil na default a neplatna vyska cela na auto.
    if (!validateFields()){ NX.setStatus('Skontroluj červené polia (neplatný rozmer).', true); return; }
    var p = collectAll(); p.zone_tree = currentZoneTree;
    // D-33/F6: materialy zo sablony idu do insert payloadu EXPLICITNE (drzi ich
    // insert stav, nie disabled selecty). Vedome MIMO PARAM_KEYS/CONSTRUCTION_FIELDS:
    // PARAM_KEYS je zaroven apply whitelist a materialy maju vlastny kanal
    // set_cabinet_material — rozsirenie whitelistu by nechalo auto-apply prepisovat
    // materialy zo stavu formulara. Ruby handle_insert ich cez build/normalize
    // zapise do configu (normalize materialy pozna od V0.3).
    var mats = NXInsert.state.materials || {};
    NXInsert.MATERIAL_KEYS.forEach(function(k){ if (mats[k]) p[k] = mats[k]; });
    // H2 (D-76): sety kovania zo sablony (mapovanie + zmrazene definicie) idu
    // do payloadu rovnako ako materialy — server ich normalizuje a zmrazi do
    // projektu v operacii vlozenia. Bez sablony su kluce prazdne = neposlu sa.
    var hw = NXInsert.hardwarePayload();
    NXInsert.HARDWARE_KEYS.forEach(function(k){ if (hw[k]) p[k] = hw[k]; });
    // UI-C1a: identita pouzitej sablony (kind + nazov) — server si zaznam znovu
    // najde, metadata odstrani PRED builderom a az po uspesnom vlozeni z nich
    // spravi peciatku „naposledy pouzite". Do configu skrinky sa nedostanu.
    var ref = NXInsert.templateRef();
    if (ref && ref.kind === 'cabinet'){
      p.template_kind = ref.kind;
      p.template_name = ref.name;
    }
    if (window.sketchup && sketchup.insert_cabinet) sketchup.insert_cabinet(JSON.stringify(p));
  }
  // B3 „Vlozit kopiu": PRESNA SERVEROVA kopia oznacenej skrinky — config sa cita
  // z modelu (nie z DOM formulara), takze kopia nesie aj materialy, part_overrides,
  // hardware_overrides, cela, zony aj nazov. Zamky vkladacej karty sa NEaplikuju
  // (vedome — kopia je verny duplikat). Pred odoslanim flush rozpisanych editov,
  // aby kopia zachytila aj posledne zmeny (callbacky sa spracuju v poradi).
  function insertCopySelected(){
    if (!selectedCabId){ NX.setStatus('Najprv označ korpus.', true); return; }
    // GH P2: neplatne rozpisane pole by flush ticho NEaplikoval a kopia by
    // vznikla zo starsieho stavu — kopirovanie stoji, kym pole neopravis.
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — kópia by nezachytila rozpísanú úpravu.', true);
      return;
    }
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (window.sketchup && sketchup.insert_copy)
      sketchup.insert_copy(JSON.stringify({ cabinet_id: selectedCabId }));
  }
  function toggleZones(){ var on = el('zonesChk').checked; if (window.sketchup && sketchup.toggle_zones) sketchup.toggle_zones(on ? 'true' : 'false'); }

  // ===== UI-B3 (N13): klikatelny informacny stlpec Zakladnych ================
  // „Všetko informačné je klikateľné a vedie tam, kam ukazuje." Klik na pocet
  // dielcov ich OZNACI v modeli — ciste citanie + zmena vyberu na serveri
  // (ziadna operacia, ziadny krok Spat). Callback nesie identitu dokumentu aj
  // skrinky: kym dobehne, mohol pouzivatel oznacit nieco ine.
  //
  // Codex audit BLOCKER 1: zmena vyberu si vypyta push CELEJ skrinky, ktory
  // prepise formular — rozpisany edit caka 400 ms, takze bez flushu by sa ticho
  // stratil. Preto rovnaky handshake ako ma „Vložiť kópiu" a relay cesty okna
  // Vyroba: neplatne pole akciu ZASTAVI (flush by ju ticho neaplikoval),
  // platne edity sa najprv odosielaju (callbacky sa spracuju v poradi).
  function onInfoParts(){
    if (!selectedCabId){ NX.setStatus('Označ skrinku v modeli.', true); return; }
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — rozpísaná úprava by sa pri označení dielcov stratila.', true);
      return;
    }
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
    if (window.sketchup && sketchup.nx_select_parts)
      sketchup.nx_select_parts(JSON.stringify({ cabinet_id: selectedCabId, model_guid: nxModelGuid }));
  }
  // UI-D3 (N13): Materiál m² — klik vedie tam, kam ukazuje: do KUSOVNÍKA.
  // ST-1a (audit #12): kusovník je od tejto dávky sekciou okna ŠTÚDIO a
  // sľúbený filter na jednu skrinku sa SPLNIL — ID skrinky ide ako `anchor`,
  // ktorý predvyplní hľadanie sekcie (Š6). Status to hovorí nahlas, aby bolo
  // jasné, že zoznam je zúžený a ako sa zúženie zruší.
  function onInfoArea(){
    if (!selectedCabId){ NX.setStatus('Označ skrinku v modeli.', true); return; }
    // Status PRED otvorenim: pripadny flush rozpisaneho editu odpovie neskor
    // a jeho sprava je dolezitejsia — nechame ju vyhrat.
    NX.setStatus('Kusovník je otvorený v Štúdiu a vyfiltrovaný na ' + selectedCabId +
                 ' — vymazaním hľadania uvidíš celú zákazku.');
    openStudio('bom', selectedCabId);
  }

  function setSelected(cid){
    selectedCabId = cid;
    // (applyTplBtn zije v okne Sablony — disabled stav riesi TemplatesDialog.push_state)
  }

