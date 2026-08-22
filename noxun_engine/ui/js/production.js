  // ===================== VYROBA (V0.5 B) =====================
  // Kusovnik + supisy z Bom (Ruby). READ-ONLY — klik na riadok IBA vybera
  // entity v modeli (cez Ruby select_row s generacnym tokenom; server je
  // autorita — stale klik = odmietnut + re-push). Tabulky sa skladaju jednym
  // innerHTML a klik ide DELEGACIOU (Codex N9 — stovky riadkov bez lagov).

  var BOM = null;          // posledny push z Ruby
  // ST-1a: taby Kusovník/Materiály/ABS sa presunuli do okna ŠTÚDIO (sekcia
  // Kusovník, pohľady Dielce · Platne · ABS).
  // ŠT-1b: to isté sa stalo tabu KONTROLA — zoznam nálezov, akcia „Nahradiť
  // UNI…" aj prepínače „Zvýrazniť hrany" / „Smer kresby" žijú v sekcii Kontrola
  // okna ŠTÚDIO. Tu ostal len ⚠ chip hlavičky, ktorý tam vedie.
  // ŠT-1c PR A: a to isté tabu KOVANIE — nákupný zoznam (sety, generika,
  // CSV export, klik-select vlastníka) je sekcia „Nákup kovania" okna ŠTÚDIO
  // (presun 1:1 podľa Š7).
  // ŠT-1c PR B1: a POSLEDNÉMU tabu ROZPOČET — celý rozpočet zákazky vrátane
  // náhľadu cenovej ponuky, exportov XLSX a prepočtu cien je sekcia „Rozpočet"
  // okna ŠTÚDIO (js/budget.js sa načítava TAM). Oknu tak neostal ŽIADNY tab:
  // ostal ⚠ chip do sekcie Kontrola, súhrn zákazky a veta, kam sa obsah
  // presťahoval. Celé okno zanikne v PR B3.

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function num(v, dec){ return (v==null||isNaN(v)) ? '—' : Number(v).toFixed(dec==null?0:dec).replace('.', ','); }

  window.NX = {
    setBom: function(data){
      BOM = data || null;
      el('prodModel').textContent = BOM ? ('model: ' + BOM.model_title + ' · v' + BOM.version) : '…';
      renderProject(); renderSummary(); renderWarnChip();
      // ŠT-1c PR B1: deep-link na tab tu ZANIKOL spolu s poslednym tabom
      // (`TABS` je prazdne pole, takze `open_tab` je vzdy null). Deep-link
      // ZIJE — ale do SEKCII okna Studio (`StudioDialog::SECTIONS`).
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

  // ST-1a (audit #9): `prodTabIds` / `setProdTab` ZANIKLI — okno uz nema
  // ziadny tab, takze nie je co prepinat (ŠT-1c PR B1).

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

  // ŠT-1c PR B1: okno uz nema OBSAH — vsetkych pat tabov zije v Studiu. Telo
  // to POVIE nahlas namiesto prazdnej plochy: prazdne okno bez vysvetlenia
  // vyzera ako chyba (a Michal by hladal, kde sa rozpocet stratil). Okno
  // zanikne v PR B3, ktora sem uz nema co pisat.
  function renderBody(){
    var box = el('prodBody');
    if (!box) return;
    box.innerHTML = '<div class="muted">Obsah tohto okna sa presťahoval do <b>Štúdia</b> ' +
      '(Kusovník · Kontrola · Nákup kovania · Rozpočet). Okno Výroba zanikne v ďalšej dávke — ' +
      'otvor Štúdio z panela alebo z lišty nástrojov.</div>';
  }

  // ST-1a: `renderRows` / `renderSheets` / `renderEdging` a ich pomocníci
  // (`edgesLabel`, `plateCell`, `budgetRowMap`, `budgetSubtotal`, `budgetSumRow`)
  // ZANIKLI spolu s tabmi Kusovník, Materiály a ABS — ich obsah žije v okne
  // ŠTÚDIO ako sekcia Kusovník (pohľady Dielce · Platne · ABS).
  //
  // ŠT-1c PR A: to isté sa stalo tabu KOVANIE — `renderHardware`, `price`,
  // `hwManualMark`, `hwCsvExport` aj delegovaný klik na riadok generiky ŽIJÚ
  // v `js/studio.js` ako sekcia „Nákup kovania" (Š7, presun 1:1). S nimi
  // odišli aj payload polia `hardware` a `hardware_sets`.
  //
  // ŠT-1c PR B1: a to isté tabu ROZPOČET — `js/budget.js` sa načítava v okne
  // ŠTÚDIO (za `studio.js`) a číta jeho payload `ST.budget`; okno Výroba už
  // pole `budget` NEDOSTÁVA. Zostal mu globálny `BOM` s `summary`, `vepo`
  // a `counts` — teda presne to, čo kreslí hlavička a ⚠ chip.

  window.onload = function(){ if (window.sketchup && sketchup.ready) sketchup.ready(''); };

  // ŠT-1c PR A: súbor už NEEXPORTUJE nič pre Node testy — poslednou čistou
  // funkciou bola `hwManualMark` (D-93) a tá je v studio.js.
