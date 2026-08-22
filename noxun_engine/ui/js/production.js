  // ===================== VYROBA (V0.5 B) =====================
  // Kusovnik + supisy z Bom (Ruby). READ-ONLY — klik na riadok IBA vybera
  // entity v modeli (cez Ruby select_row s generacnym tokenom; server je
  // autorita — stale klik = odmietnut + re-push). Tabulky sa skladaju jednym
  // innerHTML a klik ide DELEGACIOU (Codex N9 — stovky riadkov bez lagov).

  var BOM = null;          // posledny push z Ruby
  // ST-1a: taby Kusovník/Materiály/ABS sa presunuli do okna ŠTÚDIO (sekcia
  // Kusovník, pohľady Dielce · Platne · ABS). Prvý tab zľava je odteraz Kovanie.
  // ŠT-1b: to isté sa stalo tabu KONTROLA — zoznam nálezov, akcia „Nahradiť
  // UNI…" aj prepínače „Zvýrazniť hrany" / „Smer kresby" žijú v sekcii Kontrola
  // okna ŠTÚDIO. Tu ostal len ⚠ chip hlavičky, ktorý tam vedie.
  var prodTab = 'hardware';

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function num(v, dec){ return (v==null||isNaN(v)) ? '—' : Number(v).toFixed(dec==null?0:dec).replace('.', ','); }

  window.NX = {
    setBom: function(data){
      BOM = data || null;
      el('prodModel').textContent = BOM ? ('model: ' + BOM.model_title + ' · v' + BOM.version) : '…';
      renderProject(); renderSummary(); renderWarnChip();
      // UI-D3: deep-link z Inspectora („Materiál" -> Kusovník). Server posiela
      // `open_tab` PRAVE RAZ; setProdTab uz kresli listu aj telo, takze sa
      // nekresli dvakrat. Ked uz na tom tabe stojime (alebo deep-link nie je),
      // ide bezna cesta.
      var want = (BOM && BOM.open_tab) ? BOM.open_tab : null;
      if (want && want !== prodTab){ setProdTab(want); return; }
      renderBody();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  // ŠT-1b: ⚠ chip hlavičky je JEDINÁ cesta z okna Výroba k zoznamu nálezov —
  // otvorí ŠTÚDIO rovno na sekcii Kontrola (o whiteliste sekcií rozhoduje Ruby).
  function openStudioControl(){
    if (window.sketchup && sketchup.open_studio) sketchup.open_studio('');
  }

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
    // klik na riadok vybera v modeli LEN v kovani
    el('prodHint').style.display = (t === 'hardware') ? '' : 'none';
    renderBody();
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

  // V0.5 D: semafor chip — cisla PRIAMO zo servera (BOM.counts), JS ich NIKDY
  // neprepocitava (nalez 11: chip, status aj LOG rovnake cisla).
  // ŠT-1b: badge tabu Kontrola zanikol spolu s tabom; ostal chip hlavicky,
  // ktory vedie do sekcie Kontrola v ŠTÚDIU.
  function renderWarnChip(){
    var c = (BOM && BOM.counts) ? BOM.counts : { red: 0, orange: 0, total: 0 };
    var red = c.red || 0, orange = c.orange || 0, total = red + orange;
    var b = el('ctrlBadge');
    if (!b) return;
    b.style.display = total ? '' : 'none';
    b.innerHTML = (red ? '<span class="cb-red">🔴 ' + red + '</span>' : '') +
                  (red && orange ? ' ' : '') +
                  (orange ? '<span class="cb-orange">🟠 ' + orange + '</span>' : '');
  }

  function renderBody(){
    var box = el('prodBody');
    if (!BOM){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (prodTab === 'budget') return renderBudget(box); // V0.6 E-b (js/budget.js)
    renderHardware(box);
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

  // Delegovany klik: posiela KLUC riadku (nie pids) — Ruby si po flushi editov
  // najde cerstve refs (Codex GH #48 P2: rebuild po flushi meni persistent id).
  document.addEventListener('click', function(ev){
    var tr = ev.target && ev.target.closest ? ev.target.closest('tr.hwrow') : null;
    if (!tr || !BOM || !window.sketchup || !sketchup.select_row) return;
    var i = parseInt(tr.getAttribute('data-i'), 10);
    var g = (BOM.hardware || [])[i];
    if (!g || !g.key) return;
    sketchup.select_row(JSON.stringify({ gen: BOM.gen, hw_key: g.key }));
  });

  window.onload = function(){ if (window.sketchup && sketchup.ready) sketchup.ready(''); };

  // Node testy — LEN ciste funkcie bez DOM. ŠT-1b: prepinace hran a kresby aj
  // zoznam KONTROLY sa presunuli do studio.js, preto sa tam presunuli aj ich
  // sady (test_d104/test_d105/test_k2/test_abs_rail_3stav).
  if (typeof module !== 'undefined' && module.exports){
    // D-93 znamienko rucneho zasahu (tests/js/test_d93_nl_override.js)
    module.exports = { hwManualMark: hwManualMark };
  }
