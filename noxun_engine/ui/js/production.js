  // ===================== VYROBA (V0.5 B) =====================
  // Kusovnik + supisy z Bom (Ruby). READ-ONLY — klik na riadok IBA vybera
  // entity v modeli (cez Ruby select_row s generacnym tokenom; server je
  // autorita — stale klik = odmietnut + re-push). Tabulky sa skladaju jednym
  // innerHTML a klik ide DELEGACIOU (Codex N9 — stovky riadkov bez lagov).

  var BOM = null;          // posledny push z Ruby
  // ST-1a: taby Kusovník/Materiály/ABS sa presunuli do okna ŠTÚDIO (sekcia
  // Kusovník, pohľady Dielce · Platne · ABS). Prvý tab zľava je odteraz Kovanie.
  var prodTab = 'hardware';
  // D-104: stav zvyraznenia hran. SERVER je autorita (pocty, zapnutost aj stav
  // prepinacov) — JS si nic neprepocitava a stav si NEPAMATA sam (kazdy push ho
  // prepise). D-105: jedina vec, ktoru si drzi klient, je ci je rozbalovacie
  // okno prepinacov otvorene (cisto zobrazovacia vec, nikam sa neuklada).
  var EDGE = null;
  var ecMenuOpen = false;
  // K2/D-87: stav kresby smeru dekoru. Rovnaké pravidlo ako pri EDGE — SERVER
  // je autorita (zapnutosť aj počty), JS si nič neprepočítava a nič si
  // nepamätá; každý push stav prepíše.
  var GRAIN = null;

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function num(v, dec){ return (v==null||isNaN(v)) ? '—' : Number(v).toFixed(dec==null?0:dec).replace('.', ','); }

  window.NX = {
    setBom: function(data){
      BOM = data || null;
      EDGE = (BOM && BOM.edge_check) ? BOM.edge_check : null;
      GRAIN = (BOM && BOM.grain_check) ? BOM.grain_check : null;
      el('prodModel').textContent = BOM ? ('model: ' + BOM.model_title + ' · v' + BOM.version) : '…';
      renderProject(); renderSummary(); renderBadge();
      // UI-D3: deep-link z Inspectora (⚠ warnpanel -> Kontrola, „Materiál" ->
      // Kusovník). Server posiela `open_tab` PRAVE RAZ; setProdTab uz kresli
      // listu aj telo, takze sa nekresli dvakrat. Ked uz na tom tabe stojime
      // (alebo deep-link nie je), ide bezna cesta.
      var want = (BOM && BOM.open_tab) ? BOM.open_tab : null;
      if (want && want !== prodTab){ setProdTab(want); return; }
      renderEdgeBar(); renderBody();
    },
    // D-104: maly echo push (prepnutie / prepocet po prestavbe / zmena vyberu)
    // — prekresli sa LEN lista zvyraznenia, zoznam kontroly sa nedotkne
    // (pri zmene vyberu chodi casto a tabulka moze mat stovky riadkov).
    setEdgeCheck: function(state){
      EDGE = state || null;
      renderEdgeBar();
    },
    // K2/D-87: to isté pre kresbu smeru (prepnutie / prepočet po prestavbe).
    setGrainCheck: function(state){
      GRAIN = state || null;
      renderEdgeBar();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; },
    // v0.7.28: to iste 3-stavove nastavenie sa da otvorit aj z railu Inspectora.
    // Ked ho pouzivatel otvori tam, toto sa zavrie — na obrazovke nikdy nestoja
    // dve kopie tych istych prepinacov.
    closeEdgeMenu: function(){ edgeCheckMenuClose(); }
  };

  // ===================== NAZOV PROJEKTU (ST-1a, audit #1) =====================
  // Nazov projektu je od tejto davky SERVEROVY udaj (mapa `project_names`
  // v %APPDATA%, kluc = model_guid) a EDITUJE sa v liste Kusovnika v okne
  // Studio. Okno Vyroba ho preto ukazuje ako TEXT — vystup sa nesmie tvarit
  // ako vstup (trvala zasada UI 2.0). Bez toho by sa dve okna mohli rozist
  // a exporty tej istej zakazky by niesli rozne mena.
  function renderProject(){
    var box = el('prodProject');
    if (!box) return;
    var v = (BOM && BOM.vepo) ? BOM.vepo : null;
    box.textContent = v ? ('projekt: ' + (v.project || '—')) : '';
  }

  function requestRefresh(){ if (window.sketchup && sketchup.refresh_bom) sketchup.refresh_bom(''); }

  // ST-1a (audit #9): zoznam tabov sa cita z DOM, nie z natvrdo pisaneho pola —
  // odstranenie tabu by inak skoncilo na `el(null).classList` (TypeError) a
  // okno by ostalo cierne.
  function prodTabIds(){
    var out = [];
    var box = el('prodTabs');
    if (!box) return out;
    var btns = box.querySelectorAll('button[id^="pt_"]');
    for (var i = 0; i < btns.length; i++) out.push(btns[i].id.slice(3));
    return out;
  }

  function setProdTab(t){
    prodTab = t;
    prodTabIds().forEach(function(k){
      var b = el('pt_' + k);
      if (b) b.classList.toggle('on', k === t);
    });
    // klik na riadok vybera v modeli v kovani AJ kontrole
    el('prodHint').style.display = (t === 'hardware' || t === 'control') ? '' : 'none';
    if (t !== 'control') ecMenuOpen = false; // odchod z tabu okno zavrie
    renderEdgeBar();
    renderBody();
  }

  // D-105: lista zvyraznenia hran zije MIMO scrollovacieho #prodBody (jeho
  // overflow by orezal rozbalovacie okno). Mimo tabu Kontrola je prazdna a
  // skryta — vertikalny priestor okna sa nemeni.
  function renderEdgeBar(){
    var box = el('ecBar');
    if (!box) return;
    if (prodTab !== 'control'){
      box.style.display = 'none';
      box.innerHTML = '';
      return;
    }
    box.style.display = '';
    // K2/D-87: dva nástroje TEJ ISTEJ lišty — zvýraznenie hrán (split tlačidlo
    // s nastavením) a smer kresby (obyčajný prepínač). Žiadny nový riadok.
    box.innerHTML = edgeCheckBarHtml(EDGE, ecMenuOpen, GRAIN);
  }

  function renderSummary(){
    if (!BOM){ el('prodSummary').textContent = '…'; return; }
    var s = BOM.summary || {};
    el('prodSummary').innerHTML =
      '<b>' + num(s.cabinets) + '</b> skriniek · <b>' + num(s.boards) + '</b> dosiek · ' +
      '<b>' + num(s.quantity) + '</b> dielcov (' + num(s.rows) + ' riadkov) · ' +
      '<b>' + num(s.m2_total, 2) + '</b> m² · <b>' + num(s.bm_total, 1) + '</b> bm ABS · ' +
      '<b>' + num(s.hardware_quantity) + '</b> ks kovania';
  }

  // V0.5 D: semafor badge — cisla PRIAMO zo servera (BOM.counts), JS ich NIKDY
  // neprepocitava z control poloziek (nalez 11: header, status aj LOG rovnake cisla).
  function renderBadge(){
    var c = (BOM && BOM.counts) ? BOM.counts : { red: 0, orange: 0, total: 0 };
    var red = c.red || 0, orange = c.orange || 0, total = red + orange;
    var b = el('ctrlBadge');
    if (b){
      b.style.display = total ? '' : 'none';
      b.innerHTML = (red ? '<span class="cb-red">🔴 ' + red + '</span>' : '') +
                    (red && orange ? ' ' : '') +
                    (orange ? '<span class="cb-orange">🟠 ' + orange + '</span>' : '');
    }
    var tb = el('ctrlTabBadge');
    if (tb){
      tb.style.display = total ? '' : 'none';
      tb.textContent = total;
      tb.className = 'wbadge' + (red ? ' wbadge-red' : '');
    }
  }

  function renderBody(){
    var box = el('prodBody');
    if (!BOM){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (prodTab === 'hardware') return renderHardware(box);
    if (prodTab === 'budget') return renderBudget(box); // V0.6 E-b (js/budget.js)
    renderControl(box);
  }

  // ST-1a: `renderRows` / `renderSheets` / `renderEdging` a ich pomocníci
  // (`edgesLabel`, `plateCell`, `budgetRowMap`, `budgetSubtotal`, `budgetSumRow`)
  // ZANIKLI spolu s tabmi Kusovník, Materiály a ABS — ich obsah žije v okne
  // ŠTÚDIO ako sekcia Kusovník (pohľady Dielce · Platne · ABS). Tab Rozpočet má
  // vlastné helpery (`js/budget.js`); `price()` nižšie OSTÁVA — používa ho tab
  // Kovanie. Payload z Ruby sa NEMENÍ: globálny `BOM` číta aj budget.js.
  // V0.6 D1b: cena — nil/undefined = „nezadaná" (—), NIKDY 0 (audit N11).
  function price(v){ return (v == null || isNaN(v)) ? '—' : num(v, 2) + ' €'; }

  // D-93: drobné znamienko „ručne prepísané" pri počte. Text skladá VÝHRADNE
  // server (HardwareSets.manual_note / Bom.manual_note) — JS ho len vypíše;
  // žiadne emoji, sprite ikona (ceruzka = ručný zásah).
  function hwManualMark(note){
    if (!note) return '';
    return ' <span class="hwmanual" title="' + esc(note) + '">'
         + '<svg class="ic" aria-hidden="true"><use href="#i-pencil"/></svg></span>';
  }

  function hwCsvExport(){
    if (!BOM || !window.sketchup || !sketchup.hw_csv_export) return;
    NX.setStatus('Exportujem nákupný zoznam…', false);
    // ST-1a (audit #1): nazov projektu sa uz NEPOSIELA z DOM — cita ho SERVER
    // (`ProductionCore.project_name`), takze vsetky styri exporty pomenuju
    // zakazku rovnako bez ohladu na to, z ktoreho okna ich pouzivatel spusti.
    sketchup.hw_csv_export(JSON.stringify({ gen: BOM.gen }));
  }

  // V0.6 D1b: tab Kovanie = NÁKUPNÝ ZOZNAM zo setov (hore) + generika podľa
  // pravidiel (dole, klik-select cez .hwrow ostáva). Dáta VÝHRADNE zo servera
  // (BOM.hardware_sets = HardwareSets.expand) — JS len renderuje.
  function renderHardware(box){
    var hs = BOM.hardware_sets || null;
    var list = BOM.hardware || [];
    var h = '<div class="hwsec"><span>Nákupný zoznam (sety)</span>'
          + '<button class="ghostbtn" onclick="hwCsvExport()" title="CSV nákupného zoznamu — počíta sa z čerstvého modelu">⇩ CSV kovania</button></div>';
    if (!hs){
      h += '<div class="muted">Nákupný zoznam sa nepodarilo zostaviť (pozri Ruby konzolu).</div>';
    } else {
      if (hs.state_status === 'invalid'){
        h += '<div class="hwbanner">Sety projektu sú poškodené — nič sa nemapuje. Otvor Katalóg kovania → Predvoľby projektu a vyber sety nanovo.</div>';
      }
      var rows = hs.rows || [];
      if (!rows.length){
        h += '<div class="muted">Žiadne namapované kovanie' + ((hs.unmapped || []).length ? '' : ' (model nemá kovanie)') + '.</div>';
      } else {
        h += '<table class="bomtab"><thead><tr><th>Kód</th><th>Názov</th><th>ks</th><th>MJ</th><th>€ s DPH</th><th>Spolu</th></tr></thead><tbody>';
        var cat = null;
        rows.forEach(function(r){
          var c = r.missing ? 'MIMO KATALÓGU' : (r.category || '—');
          if (c !== cat){ cat = c; h += '<tr class="hwcat"><td colspan="6">' + esc(c) + '</td></tr>'; }
          h += '<tr' + (r.missing ? ' class="hwmiss"' : '') + '><td>' + esc(r.code) + '</td>'
             + '<td>' + esc(r.missing ? 'nie je v katalógu kovania' : (r.name_sk || '')) + '</td>'
             + '<td><b>' + num(r.quantity) + '</b>' + hwManualMark(r.manual_note) + '</td>'
             + '<td>' + esc(r.unit || '—') + '</td>'
             + '<td>' + price(r.price_eur_vat) + '</td><td>' + price(r.subtotal_eur_vat) + '</td></tr>';
        });
        var sum = hs.summary || {};
        h += '<tr class="hwsum"><td colspan="5">SPOLU — len známe ceny'
           + (sum.unknown_prices ? ' (' + sum.unknown_prices + '× cena nezadaná)' : '')
           + '</td><td><b>' + price(sum.total_eur_vat) + '</b></td></tr></tbody></table>';
      }
      var un = hs.unmapped || [];
      if (un.length){
        h += '<div class="hwsec hwsec-warn"><span>Bez kódov (' + un.length + ') — nenacenené, detail v tabe Kontrola</span></div>'
           + '<table class="bomtab"><tbody>';
        un.forEach(function(u){
          // H1b: krátky SK text dôvodu skladá SERVER (HardwareSets.unmapped_reason_sk
          // → payload 'reason_sk') — ten istý text ide aj do CSV. JS už žiadny
          // vlastný preklad enumu nemá; fallback je len pre starý payload.
          var reason = u.reason_sk || ('bez kódov (' + (u.reason || '?') + ')');
          // D-90: 'params_label' („rez 597 mm") zo servera — bez neho by pri
          // dĺžkovom kovaní nebolo v zozname vidieť, aký rozmer objednať.
          if (u.params_label) reason += ' · ' + u.params_label;
          h += '<tr class="hwmiss"><td>' + esc(u.generic_type) + '</td>'
             + '<td>' + esc(u.cabinet_id + (u.owner_part_key ? ' · ' + u.owner_part_key : '')) + '</td>'
             + '<td>' + num(u.quantity) + '</td><td>' + esc(reason) + '</td></tr>';
        });
        h += '</tbody></table>';
      }
    }
    h += '<div class="hwsec"><span>Podľa pravidiel (generika)</span></div>';
    if (!list.length){
      h += '<div class="muted">Žiadne kovanie (kovanie sa počíta z pravidiel korpusov).</div>';
    } else {
      h += '<table class="bomtab"><thead><tr><th>Typ</th><th>Parametre</th><th>ks</th><th>Kde</th></tr></thead><tbody>';
      list.forEach(function(g, i){
        // D-90: 'params_label' je SERVEROVY text („rez 597 mm") — ked ho polozka
        // ma, zobrazi sa NAMIESTO surovych key/value (JS nic neformatuje).
        var params = g.params_label
          ? esc(g.params_label)
          : (Object.keys(g.params || {}).map(function(k){ return esc(k) + ' ' + esc(g.params[k]); }).join(', ') || '—');
        // D-93: pri ručne zamknutej dĺžke nesie riadok serverový popis
        // („ručne prepísaná dĺžka (automat: 470 mm)") ako tooltip.
        var kde = (g.breakdown || []).map(function(b){
          var t = esc(b.owner_id) + '×' + b.quantity + (b.source === 'manual' ? ' (ručne)' : '');
          return b.manual_note ? '<span title="' + esc(b.manual_note) + '">' + t + '</span>' : t;
        }).join(', ');
        // V0.6 C-2 (audit F11): slovensky label zo SERVERA (fallback surovy typ)
        h += '<tr class="hwrow" data-i="' + i + '"><td>' + esc(g.label || g.generic_type) + '</td><td>' + params + '</td>' +
             '<td><b>' + num(g.quantity) + '</b></td><td>' + kde + '</td></tr>';
      });
      h += '</tbody></table>';
    }
    box.innerHTML = h;
  }

  // D-104/D-105: prepinac zvyraznenia hran — CISTE funkcie (node testy).
  // Pocty, zapnutost aj STAV PREPINACOV prichadzaju zo servera; JS ich len
  // vypise a nikdy si ich neprepocitava ani nepamata.
  //
  // D-105 tvar: split tlacidlo (lava polovica = zap/vyp, prava = rozbalovacie
  // okno s tromi stavmi). Okno je OVERLAY pod tlacidlom — ziadny novy riadok
  // v layoute (vertikalny priestor je vzacny).
  //
  // v0.7.28: samotne 3-stavove okno uz TU NEZIJE — je to ZDIELANY komponent
  // (js/edge_menu.js), ktory to iste nastavenie kresli aj v raile Inspectora.
  // Dva vstupne body, JEDEN markup a JEDEN stav (server).
  var ECM = (typeof module !== 'undefined' && module.exports)
    ? require('./edge_menu.js')            // Node testy
    : (typeof window !== 'undefined' ? window.NXEdgeMenu : null);

  function ecNum(v){ return ECM.num(v); }

  function edgeCheckBarHtml(st, menuOpen, grain){
    if (!st || !st.available){
      return '<div class="ecbar ecoff">Zvýraznenie hrán a smer kresby vyžadujú SketchUp 2023 alebo novší.</div>';
    }
    var on = st.active === true;
    return '<div class="ecbar"><div class="ecsplit">' +
      '<button type="button" id="ecBtn" class="ecbtn ecmain' + (on ? ' on' : '') + '"' +
      ' onclick="edgeCheckToggle()" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Farebné zvýraznenie stavu olepu priamo v modeli. Model sa nemení — kreslí sa nad ním.">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-' + (on ? 'eye-off' : 'eye') + '"/></svg>' +
      'Zvýrazniť hrany</button>' +
      '<button type="button" id="ecMore" class="ecbtn ecmore' + (on ? ' on' : '') + '"' +
      ' onclick="edgeCheckMenuToggle()" aria-expanded="' + (menuOpen ? 'true' : 'false') + '"' +
      ' aria-label="Nastavenie zvýraznenia hrán" title="Nastavenie — ktoré stavy hrán sa zvýraznia">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-chevron-down"/></svg></button>' +
      edgeCheckMenuHtml(st, menuOpen) +
      '</div>' + grainBtnHtml(grain) +
      '<span class="ecinfo">' + edgeCheckText(st) + grainInfoHtml(grain) + '</span></div>';
  }

  // K2/D-87: prepínač smeru kresby. ZÁMERNE obyčajné tlačidlo (nie split ako
  // zvýraznenie hrán) — nemá čo nastavovať: buď kresbu vidíš, alebo nie.
  function grainBtnHtml(g){
    if (!g || !g.available) return '';
    var on = g.active === true;
    return '<button type="button" id="gcBtn" class="ecbtn gcbtn' + (on ? ' on' : '') + '"' +
      ' onclick="grainCheckToggle()" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Nakreslí na dielce čiary v smere kresby dekoru — blenda vs. dvere na prvý pohľad.' +
      ' Model sa nemení, kreslí sa nad ním.">' +
      // v0.7.27: ta ista kresba ako prepinac v raile Inspectora — rovnaky
      // vyznam = rovnaka ikona (UI_DIZAJN §4). Povodny `rows-3` bol nahrada,
      // kym vlastny symbol neexistoval.
      '<svg class="ic" aria-hidden="true"><use href="#i-grain"/></svg>Smer kresby</button>';
  }

  // Doveta k textu lišty. Vypnutý prepínač mlčí (o vypnutom stave už hovorí
  // samotné tlačidlo) — inak by lišta niesla dve „vypnuté" vety vedľa seba.
  function grainInfoHtml(g){
    var t = grainCheckText(g);
    return t ? ' · <span class="gcinfo">' + t + '</span>' : '';
  }

  function grainCheckText(g){
    if (!g || !g.available || !g.active) return '';
    var parts = ecNum(g.parts);
    var t = parts + ' ' + grainPartPluralSk(parts) + ' s kresbou';
    if (ecNum(g.skipped)) t += ' · ' + ecNum(g.skipped) + ' bez kresby (materiál bez smeru)';
    if (ecNum(g.unresolved)) t += ' · ' + ecNum(g.unresolved) + ' sa nedá nakresliť (neznáma orientácia dielca)';
    return t;
  }

  // 1 dielec / 2–4 dielce / 5+ dielcov (slovenske sklonovanie poctu)
  function grainPartPluralSk(n){
    var v = Math.abs(n);
    if (v === 1) return 'dielec';
    if (v >= 2 && v <= 4) return 'dielce';
    return 'dielcov';
  }

  function grainCheckToggle(){
    if (!BOM || !window.sketchup || !sketchup.grain_check_toggle) return;
    sketchup.grain_check_toggle(JSON.stringify(edgeCheckPayload(BOM)));
  }

  // Rozbalovacie okno = ZDIELANY komponent (js/edge_menu.js). Okno Vyroba mu
  // len povie, ktora funkcia posiela prepnutie do Ruby — markup, texty, farebne
  // stvorceky aj zive pocty su spolocne s railom Inspectora.
  function edgeCheckMenuHtml(st, menuOpen){
    return ECM.menuHtml(st, menuOpen, { fn: 'edgeCheckOption', id: 'ecMenu' });
  }

  function edgeCheckSelectionHint(st){
    return ECM.selectionHint(st);
  }

  function edgeCheckText(st){
    if (!st || !st.active) return 'Vypnuté — v modeli nie je nič nakreslené.';
    var o = st.options || {};
    var c = st.counts || {};
    var miss = ecNum(c.missing);
    var parts = [];
    if (o.show_missing) parts.push(miss + ' ' + edgePluralSk(miss) + ' bez olepu');
    if (o.show_extra) parts.push(ecNum(c.extra) + ' mimo pravidla');
    if (o.show_taped) parts.push(ecNum(c.taped) + ' olepených');
    if (!parts.length) return 'Žiadny stav nie je zapnutý — otvor nastavenie (▾).';
    if (o.show_missing && !o.show_extra && !o.show_taped && miss === 0){
      return 'Všetky hrany podľa pravidla sú olepené.';
    }
    var t = parts.join(' · ');
    if (edgeCheckSelectionHint(st)) t += ' · označ skrinky v modeli';
    if (st.unresolved) t += ' · ' + st.unresolved + ' sa nedá zvýrazniť (neznáma orientácia dielca)';
    if (st.multi) t += ' · dielec s viac kusmi je v modeli nakreslený raz';
    return t;
  }

  // 1 hrana / 2–4 hrany / 5+ hrán (slovenske sklonovanie poctu)
  function edgePluralSk(n){
    var v = Math.abs(n);
    if (v === 1) return 'hrana';
    if (v >= 2 && v <= 4) return 'hrany';
    return 'hrán';
  }

  // Relay do Ruby — gen aj model_guid overuje SERVER (stary DOM / prepnuty
  // dokument sa odmietne a v modeli sa nic nezapne).
  function edgeCheckPayload(bom){
    return { gen: (bom && bom.gen) || 0, model_guid: (bom && bom.model_guid) || '' };
  }

  // D-105: klient posiela LEN kluc a boolean — o platnosti kluca aj o zapise
  // rozhoduje server (whitelist + striktny boolean). Skladanie je v zdielanom
  // komponente, aby rail Inspectora posielal BAJT-ROVNAKY tvar.
  function edgeCheckOptionPayload(bom, key, value){
    return ECM.optionPayload(edgeCheckPayload(bom), key, value);
  }

  function edgeCheckToggle(){
    if (!BOM || !window.sketchup || !sketchup.edge_check_toggle) return;
    sketchup.edge_check_toggle(JSON.stringify(edgeCheckPayload(BOM)));
  }

  function edgeCheckOption(key, value){
    if (!BOM || !window.sketchup || !sketchup.edge_check_option) return;
    sketchup.edge_check_option(JSON.stringify(edgeCheckOptionPayload(BOM, key, value)));
  }

  // Otvorenie/zatvorenie rozbalovacieho okna je CISTO klientska vec (nikam sa
  // neuklada) — server ho neriesi; ecMenuOpen zije hore pri EDGE.
  //
  // v0.7.28: to iste nastavenie sa da otvorit aj z railu Inspectora. Aby na
  // obrazovke nikdy neboli DVE kopie tych istych prepinacov, otvorenie tu
  // zavrie to druhe (Ruby to len prepošle — ziadny stav, ziadny zapis).
  function edgeCheckMenuToggle(){
    ecMenuOpen = !ecMenuOpen;
    if (ecMenuOpen && window.sketchup && sketchup.edge_menu_open) sketchup.edge_menu_open('');
    renderEdgeBar();
  }

  function edgeCheckMenuClose(){
    if (!ecMenuOpen) return;
    ecMenuOpen = false;
    renderEdgeBar();
  }

  // V0.5 D: KONTROLA — deterministicky zoznam problemov (RED/ORANGE). Klik na
  // riadok oznaci problemovy dielec/korpus v modeli (relay cez stabilny kluc).
  // Poradie a dedup robi server; JS len renderuje.
  function renderControl(box){
    var list = (BOM && BOM.control) ? BOM.control : [];
    // D-104/D-105: lista zvyraznenia je nad zoznamom VZDY (renderEdgeBar, mimo
    // tohto scrollovacieho boxu) — hrany bez olepu nie su polozkou semaforu,
    // takze „kontrola bez nálezov" ich este nevylucuje.
    if (!list.length){ box.innerHTML = '<div class="muted">Kontrola bez nálezov — dáta výroby čisté.</div>'; return; }
    var h = '<table class="bomtab ctrltab"><thead><tr><th>!</th><th>Problém</th><th>Kde</th></tr></thead><tbody>';
    list.forEach(function(it, i){
      var red = it.severity === 'red';
      // V0.6 E-b: rozpočtové upozornenie nemá entitu v modeli — „Kde" ukazuje
      // cieľ v Rozpočte a klik prepne tab (nič sa v modeli neoznačuje).
      var bud = it.category === 'budget';
      h += '<tr class="ctrlrow ' + (red ? 'ctrl-red' : 'ctrl-orange') + '" data-i="' + i + '">' +
           '<td class="ctrlicon">' + (red ? '🔴' : '🟠') + '</td>' +
           '<td>' + esc(it.message_sk) + ctrlActionHtml(it) + '</td>' +
           '<td>' + (bud ? 'Rozpočet' : esc(it.owner_id || '—')) + '</td></tr>';
    });
    box.innerHTML = h + '</tbody></table>';
  }

  // D-83: pri riadku „materiál neurčený" (UNI) ponukne skratku rovno do
  // „Nahradiť UNI…" v okne Materiály — inak pouzivatel musel otvorit katalog,
  // najst spravnu UNI dlazdicu a modal spustit rucne. Ikona sedi v EXISTUJUCOM
  // riadku (vertikalny priestor); uni_id nesie SERVER, klient si ho nevymysla.
  function ctrlActionHtml(it){
    if (!it || it.category !== 'uni_material' || !it.uni_id) return '';
    return ' <button type="button" class="ctrlact" data-uni="' + esc(it.uni_id) + '"' +
      ' title="Nahradiť UNI…" aria-label="Nahradiť UNI reálnym dekorom">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-arrow-left-right"/></svg></button>';
  }
  // Relay do Ruby — gen aj model_guid overuje SERVER (stary DOM / prepnuty
  // dokument sa odmietne a nic sa neotvori).
  function requestReplaceUni(uniId){
    if (!uniId || !BOM || !window.sketchup || !sketchup.replace_uni) return;
    sketchup.replace_uni(JSON.stringify({ uni_id: uniId, gen: BOM.gen,
                                          model_guid: BOM.model_guid || '' }));
  }

  // Delegovany klik: posiela KLUC riadku (nie pids) — Ruby si po flushi editov
  // najde cerstve refs (Codex GH #48 P2: rebuild po flushi meni persistent id).
  document.addEventListener('click', function(ev){
    // D-105: klik MIMO split tlacidla zavrie rozbalovacie okno prepinacov.
    // Riesi sa TU (a nie druhym listenerom): stopPropagation medzi dvoma
    // listenermi na TOM ISTOM uzle nefunguje (lekcia D-83 nizsie).
    if (ecMenuOpen && !(ev.target && ev.target.closest && ev.target.closest('.ecsplit'))){
      edgeCheckMenuClose();
    }
    // D-83: ikona akcie v riadku KONTROLY ma VLASTNY klik — nesmie zaroven
    // oznacit dielec v modeli. Vetvenie je TU (a nie v druhom listeneri):
    // stopPropagation medzi dvoma listenermi na TOM ISTOM uzle nefunguje.
    var act = ev.target && ev.target.closest ? ev.target.closest('button.ctrlact') : null;
    if (act){
      ev.preventDefault();
      ev.stopPropagation();
      requestReplaceUni(act.getAttribute('data-uni'));
      return;
    }
    var tr = ev.target && ev.target.closest ? ev.target.closest('tr.bomrow, tr.hwrow, tr.ctrlrow') : null;
    if (!tr || !BOM || !window.sketchup || !sketchup.select_row) return;
    var i = parseInt(tr.getAttribute('data-i'), 10);
    var payload = { gen: BOM.gen };
    if (tr.className.indexOf('bomrow') >= 0){
      var r = (BOM.rows || [])[i];
      if (!r || !r.key) return;
      payload.parts_key = r.key;
    } else if (tr.className.indexOf('ctrlrow') >= 0){
      // V0.5 D: semafor klik nesie STABILNY kluc problemu (nie pids) — Ruby po
      // flushi editov prepocita validaciu a najde entity podla identity (nalez 4).
      var it = (BOM.control || [])[i];
      if (!it || !it.stable_key) return;
      // V0.6 E-b: rozpoctove upozornenie NEMA entitu — klik prepne na tab
      // Rozpocet a odscroluje na sekciu (server sa vobec nevola).
      if (it.category === 'budget'){
        setProdTab('budget');
        if (typeof budGoto === 'function' && it.budget_section) budGoto(it.budget_section);
        return;
      }
      payload.problem_key = it.stable_key;
    } else {
      var g = (BOM.hardware || [])[i];
      if (!g || !g.key) return;
      payload.hw_key = g.key;
    }
    sketchup.select_row(JSON.stringify(payload));
  });

  window.onload = function(){ if (window.sketchup && sketchup.ready) sketchup.ready(''); };

  // Node testy (tests/js/test_d104_kontrola_hran.js, test_d105_prepinace_hran.js)
  // — LEN ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { edgeCheckBarHtml: edgeCheckBarHtml, edgeCheckText: edgeCheckText,
      edgePluralSk: edgePluralSk, edgeCheckPayload: edgeCheckPayload,
      edgeCheckMenuHtml: edgeCheckMenuHtml, edgeCheckOptionPayload: edgeCheckOptionPayload,
      edgeCheckSelectionHint: edgeCheckSelectionHint,
      // K2/D-87 smer kresby (tests/js/test_k2_smer_kresby.js)
      grainBtnHtml: grainBtnHtml, grainCheckText: grainCheckText,
      grainPartPluralSk: grainPartPluralSk,
      // D-93 znamienko rucneho zasahu (tests/js/test_d93_nl_override.js)
      hwManualMark: hwManualMark };
  }
