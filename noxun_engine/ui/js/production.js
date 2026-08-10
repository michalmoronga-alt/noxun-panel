  // ===================== VYROBA (V0.5 B) =====================
  // Kusovnik + supisy z Bom (Ruby). READ-ONLY — klik na riadok IBA vybera
  // entity v modeli (cez Ruby select_row s generacnym tokenom; server je
  // autorita — stale klik = odmietnut + re-push). Tabulky sa skladaju jednym
  // innerHTML a klik ide DELEGACIOU (Codex N9 — stovky riadkov bez lagov).

  var BOM = null;          // posledny push z Ruby
  var prodTab = 'rows';
  // D-104: stav zvyraznenia hran. SERVER je autorita (pocty, zapnutost aj stav
  // prepinacov) — JS si nic neprepocitava a stav si NEPAMATA sam (kazdy push ho
  // prepise). D-105: jedina vec, ktoru si drzi klient, je ci je rozbalovacie
  // okno prepinacov otvorene (cisto zobrazovacia vec, nikam sa neuklada).
  var EDGE = null;
  var ecMenuOpen = false;

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function num(v, dec){ return (v==null||isNaN(v)) ? '—' : Number(v).toFixed(dec==null?0:dec).replace('.', ','); }

  window.NX = {
    setBom: function(data){
      BOM = data || null;
      EDGE = (BOM && BOM.edge_check) ? BOM.edge_check : null;
      el('prodModel').textContent = BOM ? ('model: ' + BOM.model_title + ' · v' + BOM.version) : '…';
      vepoSync(); renderSummary(); renderBadge(); renderEdgeBar(); renderBody();
    },
    // D-104: maly echo push (prepnutie / prepocet po prestavbe / zmena vyberu)
    // — prekresli sa LEN lista zvyraznenia, zoznam kontroly sa nedotkne
    // (pri zmene vyberu chodi casto a tabulka moze mat stovky riadkov).
    setEdgeCheck: function(state){
      EDGE = state || null;
      renderEdgeBar();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  // ===================== VEPO export (V0.5 C) =====================
  // Lifecycle inputu (Codex F10): nazov projektu sa predvyplni z Ruby LEN pri
  // zmene modelu (novy model = novy default); pocas prace na tom istom modeli
  // sa pouzivatelova uprava NIKDY neprepise. Merge checkbox sa inicializuje
  // raz zo zapamataneho nastavenia.
  var vepoModelSeen = null;
  var vepoInited = false;

  function vepoSync(){
    if (!BOM || !BOM.vepo) return;
    var inp = el('vepoProject');
    // identita modelu = epocha prepnuti + cesta (GH P2: dva "Bez nazvu" modely
    // maju rovnaky titul — nazov projektu sa musi resetnut aj vtedy)
    var mkey = BOM.vepo.model_key || BOM.model_title;
    if (inp && mkey !== vepoModelSeen){
      inp.value = BOM.vepo.default_project || 'projekt';
      vepoModelSeen = mkey;
    }
    if (!vepoInited){
      var chk = el('vepoMerge');
      if (chk) chk.checked = BOM.vepo.merge_18_36 !== false;
      vepoInited = true;
    }
  }

  function vepoExport(){
    if (!BOM || !window.sketchup || !sketchup.vepo_export) return;
    var p = { gen: BOM.gen,
              project: (el('vepoProject') ? el('vepoProject').value : '').trim(),
              merge: el('vepoMerge') ? el('vepoMerge').checked : true };
    NX.setStatus('Exportujem VEPO…', false);
    sketchup.vepo_export(JSON.stringify(p));
  }

  function requestRefresh(){ if (window.sketchup && sketchup.refresh_bom) sketchup.refresh_bom(''); }

  function setProdTab(t){
    prodTab = t;
    ['rows','sheets','edging','hardware','budget','control'].forEach(function(k){
      el('pt_' + k).classList.toggle('on', k === t);
    });
    // klik na riadok vybera v modeli v kusovniku, kovani AJ kontrole
    el('prodHint').style.display = (t === 'rows' || t === 'hardware' || t === 'control') ? '' : 'none';
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
    box.innerHTML = edgeCheckBarHtml(EDGE, ecMenuOpen);
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

  function edgesLabel(edges){
    var codes = ['L1','L2','W1','W2'];
    var on = codes.filter(function(c){ return edges && edges[c]; });
    return on.length ? on.join('+') : '—';
  }

  function renderBody(){
    var box = el('prodBody');
    if (!BOM){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (prodTab === 'rows') return renderRows(box);
    if (prodTab === 'sheets') return renderSheets(box);
    if (prodTab === 'edging') return renderEdging(box);
    if (prodTab === 'hardware') return renderHardware(box);
    if (prodTab === 'budget') return renderBudget(box); // V0.6 E-b (js/budget.js)
    renderControl(box);
  }

  // V0.6 E-b: cenove bunky tabov Materialy/ABS citaju TEN ISTY payload rozpoctu
  // (BOM.budget) — okno nikde nema druhy vypocet ceny. Mapa podla identity
  // zaznamu (material_id / abs_id), nie podla indexu.
  function budgetRowMap(sectionKey, idField){
    var out = {};
    var b = BOM && BOM.budget;
    if (!b) return out;
    (b.sections || []).forEach(function(s){
      if (s.key !== sectionKey) return;
      (s.rows || []).forEach(function(r){ if (r[idField]) out[r[idField]] = r; });
    });
    return out;
  }

  function budgetSubtotal(sectionKey){
    var b = BOM && BOM.budget;
    if (!b || !b.totals || !b.totals.subtotals) return null;
    var v = b.totals.subtotals[sectionKey];
    return (v === undefined) ? null : v;
  }

  // Suma sekcie pod tabulkou — hodnota zo servera, JS ju NEskladá.
  function budgetSumRow(sectionKey, cols, label){
    var v = budgetSubtotal(sectionKey);
    if (v === null) return '';
    return '<tr class="hwsum"><td colspan="' + (cols - 1) + '">' + label + '</td>' +
           '<td><b>' + price(v) + '</b></td></tr>';
  }

  function renderRows(box){
    var rows = BOM.rows || [];
    if (!rows.length){ box.innerHTML = '<div class="muted">Žiadne výrobné dielce v modeli — vlož korpus alebo dosku.</div>'; return; }
    var h = '<table class="bomtab"><thead><tr><th>Názov</th><th>Dĺžka</th><th>Šírka</th><th>Hr.</th><th>ks</th><th>Materiál</th><th>ABS</th><th>Kde</th></tr></thead><tbody>';
    rows.forEach(function(r, i){
      var kde = (r.kde || []).map(function(k){ return esc(k.owner_id) + '×' + k.quantity; }).join(', ');
      h += '<tr class="bomrow" data-i="' + i + '"><td>' + esc((r.names || []).join(' / ')) + '</td>' +
           '<td>' + num(r.length) + '</td><td>' + num(r.width) + '</td><td>' + num(r.thickness) + '</td>' +
           '<td><b>' + num(r.quantity) + '</b></td><td>' + esc(r.material_id) + '</td>' +
           '<td>' + edgesLabel(r.edges) + '</td><td>' + kde + '</td></tr>';
    });
    box.innerHTML = h + '</tbody></table>';
  }

  function renderSheets(box){
    var list = BOM.sheets || [];
    if (!list.length){ box.innerHTML = '<div class="muted">Žiadne doskové materiály.</div>'; return; }
    // D-19: odhad platni — parovanie VYHRADNE mapou podla material_id (Codex F7:
    // indexy sa rozidu, ak material vypadol z katalogu; taky dostane fallback)
    var est = {};
    (BOM.sheet_estimate || []).forEach(function(e){ est[e.material_id] = e; });
    // 2B-1 (D-43): duplak vazby z BOM riadkov — duplak material nema vlastnu
    // platnu (kupuje sa zdroj), jeho bunka odhadu to povie namiesto pomlcky.
    // GH #94 P2: rovnaky material moze niest ROZNE vazby (katalog zmeneny medzi
    // rebuildmi — BOM ich drzi oddelene v kluci), preto zoznam, nie posledna.
    var dupSrc = {};
    (BOM.rows || []).forEach(function(r){
      if (!r.material_source) return;
      var lbl = 'lepí sa ' + r.material_source.multiplier + '× z ' + esc(r.material_source.material_id);
      var list = dupSrc[r.material_id] = dupSrc[r.material_id] || [];
      if (list.indexOf(lbl) < 0) list.push(lbl);
    });
    // D-61 (E-b): pri doske je primárna cena za TABUĽU, €/m² sekundárne.
    var bmat = budgetRowMap('materials', 'material_id');
    var seen = {};
    var h = '<table class="bomtab"><thead><tr><th>Materiál</th><th>m²</th><th>dielcov</th><th>Formát</th><th>Platne (odhad)</th><th>Cena</th></tr></thead><tbody>';
    list.forEach(function(s){
      seen[s.material_id] = true;
      var e = est[s.material_id];
      var fb = e && e.fallback;
      var fmt = e ? (num(e.sheet_size[0]) + '×' + num(e.sheet_size[1])) : '—';
      var pl = e ? (num(e.count_min, 1) + ' – ' + num(e.count_max, 1)) : '—';
      // V0.6 M-B1 (audit F7): UNI = material neurceny, pocet platni je len
      // orientacny (format je pracovny default) — NIE nakupne cislo.
      if (e && e.uni === true){ pl += ' <span class="muted">(orientačne — UNI)</span>'; }
      var ds = dupSrc[s.material_id];
      if (!e && ds){
        fmt = '—';
        pl = ds.join(' · ');
      }
      var m2cell = '<b>' + num(s.m2, 2) + '</b>';
      if (e && e.doubled_m2){
        m2cell = '<b>' + num(e.m2, 2) + '</b> <span class="muted" title="Nákup vrátane duplákov: vlastné dielce + ' +
                 num(e.doubled_m2, 2) + ' m² z ' + num(e.doubled_quantity) + ' ks duplákov">(+' + num(e.doubled_m2, 2) + ' dupl.)</span>';
      }
      var cls = 'estcell' + (fb ? ' estfb' : '');
      var tt = fb ? ' title="Materiál nemá formát v katalógu — použitý 2800×2070"' : '';
      h += '<tr><td>' + esc(s.material_id) + '</td><td>' + m2cell + '</td><td>' + num(s.quantity) + '</td>' +
           '<td class="' + cls + '"' + tt + '>' + fmt + '</td><td class="' + cls + '"' + tt + '><b>' + pl + '</b></td>' +
           '<td class="estcell">' + plateCell(bmat[s.material_id]) + '</td></tr>';
    });
    // 2B-1: nakupny riadok zdroja, ktory NEMA vlastne dielce (odhad ho pozna,
    // vyrobny zoznam nie) — bez neho by nakup zdrojovych platni z tabulky zmizol.
    (BOM.sheet_estimate || []).forEach(function(e){
      if (seen[e.material_id]) return;
      var fb = e.fallback;
      var cls = 'estcell' + (fb ? ' estfb' : '');
      var tt = fb ? ' title="Materiál nemá formát v katalógu — použitý 2800×2070"' : '';
      h += '<tr><td>' + esc(e.material_id) + ' <span class="muted">(nákup pre dupláky)</span></td>' +
           '<td><b>' + num(e.m2, 2) + '</b></td><td>—</td>' +
           '<td class="' + cls + '"' + tt + '>' + num(e.sheet_size[0]) + '×' + num(e.sheet_size[1]) + '</td>' +
           '<td class="' + cls + '"' + tt + '><b>' + num(e.count_min, 1) + ' – ' + num(e.count_max, 1) + '</b></td>' +
           '<td class="estcell">' + plateCell(bmat[e.material_id]) + '</td></tr>';
    });
    h += budgetSumRow('materials', 6, 'Odhad ceny — celé tabule (ceny s DPH)');
    box.innerHTML = h + '</tbody></table>' +
      '<div class="hint">Odhad = plocha × prerez 10–25 % ÷ platňa. Orientačný rozsah, NIE nárezový plán. Duplák sa lepí zo zdrojových platní — jeho plocha sa počíta do nákupu zdroja. Formát platne sa nastavuje v katalógu materiálov (okno Materiály projektu). Cena = celé tabule × cena za tabuľu; rozpis v tabe Rozpočet.</div>';
  }

  // D-61: „€ / tabuľa" primárne, €/m² v zátvorke. Obe čísla nesie payload
  // rozpočtu (Budget.price_per_plate je JEDINÁ konverzia €/m² → €/tabuľa).
  function plateCell(row){
    if (!row) return '<span class="muted">—</span>';
    if (row.price_missing) return '<span class="muted" title="Materiál nemá cenu v katalógu">chýba cena</span>';
    var m2 = (row.price_per_m2 == null) ? '' :
      ' <span class="muted">(' + num(row.price_per_m2, 2) + ' €/m²)</span>';
    return '<b>' + price(row.cena_mj) + '</b>/tab.' + m2;
  }

  function renderEdging(box){
    var list = BOM.edging || [];
    if (!list.length){ box.innerHTML = '<div class="muted">Žiadne ABS hrany.</div>'; return; }
    // E-b: nákupné bm (vrátane rezervy) aj cena idú z payloadu rozpočtu.
    var babs = budgetRowMap('abs', 'abs_id');
    var h = '<table class="bomtab"><thead><tr><th>ABS páska</th><th>bm</th><th>hrán</th><th>bm s rezervou</th><th>€ / bm</th></tr></thead><tbody>';
    list.forEach(function(e){
      var br = babs[e.abs_id];
      var res = br ? ('<b>' + num(br.mnozstvo, 1) + '</b>') : '<span class="muted">—</span>';
      var pb = br ? (br.price_missing ? '<span class="muted">chýba cena</span>' : price(br.cena_mj))
                  : '<span class="muted">—</span>';
      h += '<tr><td>' + esc(e.abs_id) + '</td><td><b>' + num(e.bm, 1) + '</b></td><td>' + num(e.edges) + '</td>' +
           '<td>' + res + '</td><td>' + pb + '</td></tr>';
    });
    h += budgetSumRow('abs', 5, 'Odhad ceny — s rezervou (ceny s DPH)');
    box.innerHTML = h + '</tbody></table>' +
      '<div class="hint">Rezerva na olep sa nastavuje v ⚙ Nastaveniach rozpočtu; rozpis v tabe Rozpočet.</div>';
  }

  // V0.6 D1b: cena — nil/undefined = „nezadaná" (—), NIKDY 0 (audit N11).
  function price(v){ return (v == null || isNaN(v)) ? '—' : num(v, 2) + ' €'; }

  function hwCsvExport(){
    if (!BOM || !window.sketchup || !sketchup.hw_csv_export) return;
    NX.setStatus('Exportujem nákupný zoznam…', false);
    sketchup.hw_csv_export(JSON.stringify({
      gen: BOM.gen,
      project: (el('vepoProject') ? el('vepoProject').value : '').trim()
    }));
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
             + '<td><b>' + num(r.quantity) + '</b></td><td>' + esc(r.unit || '—') + '</td>'
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
        var kde = (g.breakdown || []).map(function(b){ return esc(b.owner_id) + '×' + b.quantity + (b.source === 'manual' ? ' (ručne)' : ''); }).join(', ');
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
  var EC_ROWS = [
    { key: 'show_missing', state: 'missing', label: 'Chýba podľa pravidla' },
    { key: 'show_extra',   state: 'extra',   label: 'Neolepené mimo pravidla' },
    { key: 'show_taped',   state: 'taped',   label: 'Olepené' }
  ];

  function ecNum(v){ return (v == null || isNaN(v)) ? 0 : Number(v); }

  function edgeCheckBarHtml(st, menuOpen){
    if (!st || !st.available){
      return '<div class="ecbar ecoff">Zvýraznenie hrán vyžaduje SketchUp 2023 alebo novší.</div>';
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
      '</div><span class="ecinfo">' + edgeCheckText(st) + '</span></div>';
  }

  // Rozbalovacie okno: tri stavy (checkbox + farebny stvorcek + nazov + ZIVY
  // POCET) a pod zelenou odsadeny podriadeny prepinac „len vybrané".
  function edgeCheckMenuHtml(st, menuOpen){
    var o = (st && st.options) || {};
    var c = (st && st.counts) || null;
    var h = '<div class="ecmenu' + (menuOpen ? ' open' : '') + '" id="ecMenu">';
    EC_ROWS.forEach(function(r){
      h += '<label class="ecopt"><input type="checkbox"' + (o[r.key] ? ' checked' : '') +
           ' onchange="edgeCheckOption(\'' + r.key + '\', this.checked)">' +
           '<i class="ecsw ecsw-' + r.state + '" aria-hidden="true"></i>' +
           '<span>' + r.label + '</span>' +
           '<b class="eccnt">' + (c ? ecNum(c[r.state]) : '—') + '</b></label>';
      if (r.key !== 'show_taped') return;
      h += '<label class="ecopt ecsub"><input type="checkbox"' +
           (o.taped_selected_only ? ' checked' : '') +
           ' onchange="edgeCheckOption(\'taped_selected_only\', this.checked)">' +
           '<span>len vybrané</span>' +
           (edgeCheckSelectionHint(st) ? '<b class="ecnote">označ skrinky v modeli</b>' : '') +
           '</label>';
    });
    return h + '</div>';
  }

  // Prazdny vyber pri zapnutom „len vybrané" = zelená sa nekreslí. Povedz to
  // nahlas (tiché zobrazenie všetkého by klamalo).
  function edgeCheckSelectionHint(st){
    if (!st || !st.active) return false;
    var o = st.options || {};
    return o.show_taped === true && o.taped_selected_only === true && st.selection_empty === true;
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
  // rozhoduje server (whitelist + striktny boolean).
  function edgeCheckOptionPayload(bom, key, value){
    var p = edgeCheckPayload(bom);
    p.key = String(key == null ? '' : key);
    p.value = value === true;
    return p;
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
  function edgeCheckMenuToggle(){
    ecMenuOpen = !ecMenuOpen;
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
      edgeCheckSelectionHint: edgeCheckSelectionHint };
  }
