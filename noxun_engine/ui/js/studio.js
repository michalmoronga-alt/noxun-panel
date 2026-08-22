  // ===================== ŠTÚDIO (ST-1a) =====================
  // Okno zakazky: navigacia vlavo, sekcia vpravo. V tejto davke zije PRVA
  // sekcia — KUSOVNIK (Š1–Š6) s pohladmi Dielce · Platne · ABS.
  //
  // ZELEZNE PRAVIDLO: server je autorita CISEL aj TEXTOV. JS neprepocitava
  // ziadnu sumu (medzisucty skupin idu z `sheets`, sucty zo `totals`, odhad
  // platni zo `sheet_estimate`), nesklada nazvy materialov (`materials_meta`)
  // ani rol (`role_label` v riadku). Klient si pamata VYHRADNE zobrazovacie
  // veci tohto pocitaca — ktore stlpce chce videt, ktore skupiny ma zbalene
  // a ci je navigacia zbalena na ikony (localStorage, nikdy model).
  //
  // Klik do modelu ide RELAY cez panel (flush rozpisanych editov) — vlastnym
  // kanalom `NX.studioRelay`, aby odpoved prisla do TOHTO okna (kazde okno ma
  // vlastny generacny token).

  var ST = null;             // posledny push z Ruby
  var studioSec = 'bom';     // aktivna sekcia (ST-1a Kusovnik, ŠT-1b Kontrola)
  var bomView = 'parts';     // Š4: parts | sheets | abs
  var bomQ = '';             // Š6: text hladania
  var colMenuOpen = false;   // Š2: rozbalene okno stlpcov (cisto zobrazovacie)
  var navMini = false;       // zbalena navigacia na ikony
  var groupClosed = {};      // Š1: zbalene skupiny per material_id
  // Š8: filter semaforu — all | red | orange. Je to stav OKNA (nie zakazky):
  // neuklada sa nikam a zatvorenie okna ho zabudne. Zoznam sa nim LEN zuzuje,
  // poradie urcuje server.
  var ctrlFilter = 'all';
  // Š10: stav oboch prepinacov. SERVER je autorita (zapnutost, pocty aj stav
  // trojstavoveho nastavenia) — JS si nic neprepocitava a nic si nepamata;
  // kazdy push stav prepise. Jedina klientska vec je, ci je rozbalovacie okno
  // nastavenia otvorene (cisto zobrazovacie, nikam sa neuklada).
  var EDGE = null;
  var GRAIN = null;
  var ecMenuOpen = false;

  // ZRKADLO `StudioDialog::SECTIONS` — autoritou whitelistu je RUBY, tento
  // zoznam len zabrani, aby z okna vyletela hodnota, ktora sekciu nepomenuva.
  var STUDIO_SECTIONS = ['bom', 'ctrl', 'buy', 'budget', 'offer'];

  // ŠT-1b (Š10): 3-stavove nastavenie kontroly hran je ZDIELANY komponent —
  // TEN ISTY markup kresli rail Inspectora (rohovy trojuholnik pri ABS ikone)
  // aj toto okno. TRETIA instancia, ale ziadna tretia kopia: jeden markup,
  // jeden stav (server, %APPDATA%), jedna serverova cesta.
  var ECM = (typeof module !== 'undefined' && module.exports)
    ? require('./edge_menu.js')            // Node testy
    : (typeof window !== 'undefined' ? window.NXEdgeMenu : null);

  // Š2: stlpce tabulky Dielce. `fixed` sa neda vypnut (bez nazvu dielca by
  // riadok nic nehovoril). „Poznámka" tu ZAMERNE nie je — v Ruby pre nu
  // neexistuje zdroj (vedoma odchylka davky ST-1a, audit #4).
  var COLS = [
    { k: 'name',  t: 'Dielec',       on: true, fixed: true },
    { k: 'cab',   t: 'Skrinka',      on: true },
    { k: 'l',     t: 'Dĺžka',        on: true, num: true },
    { k: 'w',     t: 'Šírka',        on: true, num: true },
    { k: 'th',    t: 'Hr.',          on: true, num: true },
    { k: 'q',     t: 'ks',           on: true, num: true },
    { k: 'abs',   t: 'ABS',          on: true },
    { k: 'grain', t: 'Smer dekoru',  on: false },
    { k: 'role',  t: 'Rola',         on: false }
  ];

  // Navigacia. Polozka je bud SEKCIA (zije tu), PREMOSTENIE (obsah je zatial
  // v inom okne — klik ho otvori a tooltip to prizna) alebo `disabled`
  // s vysvetlenim (vzor D-78: ziadne mrtve tlacidlo bez dovodu).
  var NAV = [
    { grp: 'ZÁKAZKA', items: [
      { id: 'bom',    ic: 'list',            t: 'Kusovník' },
      // Š11: pri Kontrole visia ZIVE pocty RED/ORANGE z posledneho pushu.
      { id: 'ctrl',   ic: 'clipboard-check', t: 'Kontrola', badge: true },
      // ŠT-1c PR A (Š7): Nákup kovania je od tejto dávky SEKCIA — presun tabu
      // Kovanie okna Výroba 1:1, bez redizajnu (ten príde s blokom KOVANIE).
      { id: 'buy',    ic: 'cart',            t: 'Nákup kovania' },
      // ŠT-1c PR B1 (Š12): Rozpočet je od tejto dávky SEKCIA — JEDINÁ, ktorá
      // zapisuje do modelu (1 zmena = 1 krok Späť).
      { id: 'budget', ic: 'euro',            t: 'Rozpočet' },
      // ŠT-1c PR B2 (Š14–Š15): Cenová ponuka je od tejto dávky VLASTNÁ sekcia
      // — zákaznícka projekcia toho istého rozpočtu (suma sa nikdy nelíši).
      { id: 'offer',  ic: 'file-text',       t: 'Cenová ponuka' },
      { id: 'cut',    ic: 'scissors',        t: 'Nárezový plán',
        disabled: 'fáza 2 — nárezový plán zatiaľ neexistuje' }
    ] },
    { grp: 'KATALÓGY', items: [
      { id: 'mat',    ic: 'layers',   t: 'Materiály', bridge: 'zatiaľ vlastné okno — presun v ŠT-2' },
      { id: 'hw',     ic: 'hammer',   t: 'Kovanie',   bridge: 'zatiaľ vlastné okno — presun v ŠT-3' },
      { id: 'rules',  ic: 'settings', t: 'Pravidlá',  bridge: 'zatiaľ vlastné okno — presun v ŠT-3' },
      { id: 'tpl',    ic: 'star',     t: 'Šablóny',   bridge: 'zatiaľ vlastné okno — presun v ŠT-3' }
    ] },
    { grp: 'NASTAVENIA', items: [
      { id: 'sup',    ic: 'truck', t: 'Dodávateľ / Demos',
        bridge: 'sadzby sú v okne Nastavenia rozpočtu, väzba na Demos v okne Materiály — spoja sa v ŠT-4' },
      { id: 'bset',   ic: 'euro',  t: 'Nastavenia rozpočtu', bridge: 'zatiaľ vlastné okno — presun v ŠT-4' },
      { id: 'about',  ic: 'info',  t: 'O plugine', bridge: 'obsah je v koliesku Inspectora' }
    ] }
  ];

  var SEC_META = {
    bom: { t: 'Kusovník', hint: 'skupiny podľa materiálu · pohľady Dielce / Platne / ABS · živý zoznam' },
    ctrl: { t: 'Kontrola', hint: 'semafor filtruje zoznam · klik na nález ho označí v modeli · prepínače hrán a kresby' },
    buy: { t: 'Nákup kovania', hint: 'nákupný zoznam zo setov · nekompletné položky jantárovo · CSV pre objednávku' },
    budget: { t: 'Rozpočet',
              hint: 'jediná sekcia, ktorá mení model — každá zmena = 1 krok Späť · sumy počíta server' },
    offer: { t: 'Cenová ponuka',
             hint: 'zákaznícky pohľad na ten istý rozpočet · rečou zákazníka, bez interných kódov' }
  };

  // ---------------------------------------------------------------- helpers
  function el(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }
  function esc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function num(v, dec){
    return (v == null || isNaN(v)) ? '—' : Number(v).toFixed(dec == null ? 0 : dec).replace('.', ',');
  }
  function ico(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

  // Hex zo serveroveho pola [r,g,b] (katalogova farba NIE JE CSS retazec).
  // Cokolvek ine = prazdny retazec, teda ziadna vzorka — radsej nic nez
  // nahodna farba (a zaroven uzky whitelist toho, co ide do `style`).
  function rgbHex(rgb){
    if (!rgb || rgb.length !== 3) return '';
    var out = '#';
    for (var i = 0; i < 3; i++){
      var v = Number(rgb[i]);
      if (isNaN(v)) return '';
      v = Math.max(0, Math.min(255, Math.round(v)));
      out += (v < 16 ? '0' : '') + v.toString(16);
    }
    return out;
  }

  // Hladanie BEZ DIAKRITIKY (Š6) — „ľavý" sa nájde aj ako „lavy".
  function normText(s){
    return String(s == null ? '' : s).normalize('NFD').split('').filter(function(ch){
      var c = ch.charCodeAt(0);
      return c < 0x300 || c > 0x36f;
    }).join('').toLowerCase();
  }

  // --------------------------------------------------------- ciste funkcie
  // (testuje ich tests/js/test_st1a_studio.js — bez DOM)

  // Text riadku, v ktorom hlada Š6: nazvy dielca, skrinky (`kde`), rola.
  // Poznamka v riadku NEEXISTUJE (vedoma odchylka — v Ruby nema zdroj).
  function rowText(row){
    var r = row || {};
    var names = (r.names || []).join(' ');
    var kde = (r.kde || []).map(function(k){ return k.owner_id; }).join(' ');
    return names + ' ' + kde + ' ' + (r.role_label || '') + ' ' + (r.material_id || '');
  }

  function rowHit(row, q){
    if (!q) return true;
    return normText(rowText(row)).indexOf(normText(q)) >= 0;
  }

  // Š1: riadky do skupin podla materialu. PORADIE aj MEDZISUCET urcuje SERVER
  // (`sheets` = m² a ks per material) — JS nescitava nic. Material, ktory sa
  // v supise nenachadza (nemal by), sa pripoji na koniec bez medzisuctu.
  function groupBom(rows, sheets, q){
    var byId = {};
    var order = [];
    (sheets || []).forEach(function(s){
      byId[s.material_id] = { id: s.material_id, rows: [], m2: s.m2, ks: s.quantity };
      order.push(s.material_id);
    });
    var shown = 0;
    var total = 0;
    (rows || []).forEach(function(r){
      total++;
      var id = r.material_id;
      if (!byId[id]){ byId[id] = { id: id, rows: [], m2: null, ks: null }; order.push(id); }
      if (!rowHit(r, q)) return;
      byId[id].rows.push(r);
      shown++;
    });
    var groups = [];
    order.forEach(function(id){
      var g = byId[id];
      if (g && g.rows.length) groups.push(g);
    });
    return { groups: groups, shown: shown, total: total };
  }

  // Š2: viditelne stlpce (poradie je poradie definicie, nie klikania).
  function activeCols(cols){
    return (cols || COLS).filter(function(c){ return c.on; });
  }

  // Hodnota bunky. `th` sa berie z riadku (hrubku urcuje DIELEC, nie skupina).
  function cellValue(row, key){
    var r = row || {};
    if (key === 'name') return (r.names || []).join(' / ');
    // Skrinka nesie AJ pocet kusov na vlastnika (vzor okna Vyroba): riadok sa
    // agreguje naprieč skrinkami, takze bez poctu by sa nedalo povedat, kolko
    // ktora z nich potrebuje.
    if (key === 'cab'){
      return (r.kde || []).map(function(k){
        return k.owner_id + (k.quantity == null ? '' : ' ×' + k.quantity);
      }).join(', ');
    }
    if (key === 'l') return r.length;
    if (key === 'w') return r.width;
    if (key === 'th') return r.thickness;
    if (key === 'q') return r.quantity;
    if (key === 'grain') return grainLabel(r.grain_direction);
    if (key === 'role') return r.role_label || '';
    return '';
  }

  // Smer dekoru rečou stolára (server posiela kanonicky enum).
  function grainLabel(v){
    if (v === 'length') return 'pozdĺžna';
    if (v === 'width') return 'priečna';
    return 'bez smeru';
  }

  // ABS kompakt „L1:1 · W1:2" s tooltipom plneho znenia (UI_VIZIA riadok 15).
  //
  // Kody hran ostavaju KANONICKE (L1/L2/W1/W2) a ZAMERNE sa neprekladaju na
  // „predná/zadná/ľavá/pravá": ten isty kod znamena pri kazdej role INU fyzicku
  // hranu (docs/ARCHITEKTURA.md, `part_faces`), takze pevny preklad by pri
  // policiach a dnach ukazal nespravnu stranu. Fyzicku stranu pozna karta
  // dielca v Inspectore, ktora ju zaroven kresli.
  var EDGE_CODES = ['L1', 'L2', 'W1', 'W2'];

  // Hrubka pasky do kompaktneho zapisu: „1", „2", „0,8" (bez zbytocnej nuly).
  function edgeThShort(th){
    if (th == null || isNaN(th)) return '';
    var v = Number(th);
    return (Math.round(v * 10) % 10 === 0) ? String(Math.round(v)) : v.toFixed(1).replace('.', ',');
  }

  function absCompact(row, meta){
    var e = (row || {}).edges || {};
    var out = [];
    EDGE_CODES.forEach(function(code){
      var id = e[code];
      if (!id) return;
      var th = edgeThShort(((meta || {})[id] || {}).th);
      out.push(code + (th ? ':' + th : ''));
    });
    return out.length ? out.join(' · ') : '—';
  }

  function absFull(row, meta){
    var e = (row || {}).edges || {};
    var out = [];
    EDGE_CODES.forEach(function(code){
      var id = e[code];
      if (!id) return;
      var m = (meta || {})[id] || {};
      out.push(code + ' — ' + (m.label || id));
    });
    return out.length ? out.join(' · ') : 'bez ABS';
  }

  // Premostenia navigacie: ZRKADLO whitelistu v `StudioDialog`. Klikatelne je
  // vsetko okrem aktivnej sekcie a polozky s `disabled`.
  function navBridgeIds(){
    var out = [];
    NAV.forEach(function(g){
      g.items.forEach(function(it){ if (it.bridge) out.push(it.id); });
    });
    return out;
  }

  // ============ ŠT-1b: sekcia KONTROLA (Š8–Š11) — CISTE funkcie ============
  // Testuje ich tests/js/test_st1b_kontrola.js (a prepinace hran/kresby sady
  // test_d104/test_d105/test_k2/test_abs_rail_3stav, ktore sa sem presunuli
  // spolu s UI). ZELEZNE PRAVIDLO sekcie: KAZDE cislo je zo servera —
  // `counts` (vratane zeleneho „skriniek bez nálezu"), poradie aj text nalezu.
  // Klient rozhoduje VYHRADNE o tom, co je prave vidiet (filter, otvorene menu).

  // Š8: klikatelny semafor. RED a ORANGE su FILTRE (druhy klik zrusi), GREEN je
  // informacny — niet co filtrovat. Chybajuce zelene cislo (starsi payload) sa
  // priznane ukaze ako „—"; nikdy sa nedopocitava v prehliadaci.
  function semaforHtml(counts, filter){
    var c = counts || {};
    var chip = function(sev, n, t, hint){
      return '<button type="button" class="schip s-' + sev + (filter === sev ? ' on' : '') +
        '" data-sev="' + sev + '" title="' + esc(hint) + '" aria-pressed="' +
        (filter === sev ? 'true' : 'false') + '"><span class="dot"></span><span>' +
        '<span class="n">' + num(n) + '</span> <span class="t">' + esc(t) + '</span></span></button>';
    };
    return '<div class="semafor">' +
      chip('red', c.red || 0, 'blokuje výrobu',
           'Klik zúži zoznam na červené nálezy — druhý klik filter zruší.') +
      chip('orange', c.orange || 0, 'skontroluj pred objednávkou',
           'Klik zúži zoznam na oranžové nálezy — druhý klik filter zruší.') +
      '<div class="schip s-green" title="Skrinky, ktoré v zozname nálezov nefigurujú — počíta ich server.">' +
      '<span class="dot"></span><span><span class="n">' +
      (c.clean == null ? '—' : num(c.clean)) +
      '</span> <span class="t">skriniek bez nálezu</span></span></div></div>';
  }

  // Š8: filter LEN skryva — poradie ani obsah zoznamu sa nemeni (urcuje ich
  // server). Vracia POLE PAROV [nalez, index v serverovom zozname], aby klik
  // vedel adresovat povodny riadok aj pri zapnutom filtri.
  function ctrlRows(list, filter){
    var out = [];
    (list || []).forEach(function(it, i){
      if (filter === 'all' || it.severity === filter) out.push([it, i]);
    });
    return out;
  }

  // Š9: riadok nálezu — bodka závažnosti · text · miesto · akcie vpravo.
  // Text aj miesto skladá SERVER; „Rozpočet" je jediné miesto bez entity
  // v modeli — klik prepne na sekciu Rozpočet a otvorí TÚ jeho časť, ktorej sa
  // nález týka (`budget_section` nesie server).
  function ctrlRowHtml(it, i){
    var red = it.severity === 'red';
    var bud = it.category === 'budget';
    return '<div class="ctrlrow ' + (red ? 'ctrl-red' : 'ctrl-orange') + '" data-ci="' + i + '"' +
      ' title="' + esc(bud ? 'Prejde do sekcie Rozpočet — rovno na časť, ktorej sa nález týka.'
                           : 'Klik označí nález v modeli.') + '">' +
      '<span class="dot" aria-hidden="true"></span>' +
      '<span class="msg">' + esc(it.message_sk) + '</span>' +
      '<span class="where">' + (bud ? 'Rozpočet' : esc(it.owner_id || '—')) + '</span>' +
      '<span class="rowact">' + ctrlActionsHtml(it) + '</span></div>';
  }

  // Š9: akcie riadku. Kontextová oprava je LEN tam, kde naozaj existuje
  // (UNI nález → „Nahradiť UNI…", rozpočtový nález → prechod do Rozpočtu);
  // oko a ceruzka sú vzor Kusovníka (Š3).
  function ctrlActionsHtml(it){
    if (it.category === 'budget'){
      return '<button type="button" class="goact" data-act="budget"' +
        ' title="Otvoriť sekciu Rozpočet na mieste nálezu"' +
        ' aria-label="Otvoriť sekciu Rozpočet">' + ico('euro') + '</button>';
    }
    var h = '';
    // D-83: uni_id nesie SERVER — klient si ho nevymýšľa.
    if (it.category === 'uni_material' && it.uni_id){
      h += '<button type="button" class="goact" data-act="uni" data-uni="' + esc(it.uni_id) + '"' +
        ' title="Nahradiť UNI…" aria-label="Nahradiť UNI reálnym dekorom">' +
        ico('arrow-left-right') + '</button>';
    }
    return h +
      '<button type="button" class="goact" data-act="eye" title="Označiť v modeli">' + ico('eye') + '</button>' +
      '<button type="button" class="goact" data-act="edit"' +
      ' title="Označiť a upraviť v Inspectore">' + ico('pencil') + '</button>';
  }

  // Š11: živé počty pri navigačnej položke Kontrola. Čísla sú zo `counts`
  // KAŽDÉHO pushu — čistá zákazka badge nekreslí vôbec.
  function navBadgeHtml(counts){
    var c = counts || {};
    var r = c.red || 0;
    var o = c.orange || 0;
    if (!r && !o) return '';
    return '<span class="nbadge">' + (r ? '<i class="r">' + num(r) + '</i>' : '') +
           (o ? '<i class="o">' + num(o) + '</i>' : '') + '</span>';
  }

  // ============ ŠT-1c PR A: sekcia NÁKUP KOVANIA (Š7) — CISTE funkcie ======
  // PRESUN 1:1 z `js/production.js` (tab Kovanie okna Výroba zanikol). Š7
  // ZAKAZUJE redizajn — obsah, poradie stĺpcov aj texty ostávajú, mení sa
  // jedine to, že CSV export je v LIŠTE SEKCIE namiesto hlavičky tabuľky.
  // Dáta sú VÝHRADNE zo servera (`hardware_sets` = HardwareSets.expand,
  // `hardware` = generika obohatená v ProductionCore) — JS len renderuje.

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

  // Telo sekcie: NÁKUPNÝ ZOZNAM zo setov (hore) + generika podľa pravidiel
  // (dole, klik-select cez .hwrow ostáva). Vracia HTML — sekcie Štúdia si
  // telo skladajú do reťazca (na rozdiel od okna Výroba, ktoré písalo priamo
  // do boxu); obsah je inak znak po znaku ten istý.
  function buySection(hs, list){
    var h = '<div class="hwsec"><span>Nákupný zoznam (sety)</span></div>';
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
        h += '<table class="bomtab hwtab"><thead><tr><th>Kód</th><th>Názov</th><th>ks</th><th>MJ</th><th>€ s DPH</th><th>Spolu</th></tr></thead><tbody>';
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
        // ŠT-1c: pôvodný text hovoril „detail v tabe Kontrola" — Kontrola je od
        // ŠT-1b SEKCIA tohto okna, takže by veta klamala o mieste.
        h += '<div class="hwsec hwsec-warn"><span>Bez kódov (' + un.length + ') — nenacenené, detail v sekcii Kontrola</span></div>'
           + '<table class="bomtab hwtab"><tbody>';
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
    if (!(list || []).length){
      h += '<div class="muted">Žiadne kovanie (kovanie sa počíta z pravidiel korpusov).</div>';
      return h;
    }
    h += '<table class="bomtab hwtab"><thead><tr><th>Typ</th><th>Parametre</th><th>ks</th><th>Kde</th></tr></thead><tbody>';
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
    return h;
  }

  // ---- Š10: prepínače lišty (zvýraznenie hrán + smer kresby) --------------
  // Spúšťač zvýraznenia má tvar ROHOVÉHO TROJUHOLNÍKA (mockup): klik na telo
  // prepína, klik na roh otvára 3-stavové nastavenie. Roh je SAMOSTATNÉ
  // tlačidlo vedľa (vnorené tlačidlo je neplatné HTML) — vzor railu Inspectora.
  function ecNum(v){ return ECM.num(v); }

  function edgeCheckBarHtml(st, menuOpen, grain){
    if (!st || !st.available){
      return '<span class="ecoff">Zvýraznenie hrán a smer kresby vyžadujú SketchUp 2023 alebo novší.</span>';
    }
    var on = st.active === true;
    return '<span class="echk"><button type="button" id="ecBtn" class="ecbtn' + (on ? ' on' : '') + '"' +
      ' data-ec="toggle" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Farebné zvýraznenie stavu olepu priamo v modeli. Model sa nemení — kreslí sa nad ním.">' +
      ico(on ? 'eye-off' : 'eye') + 'Zvýrazniť hrany</button>' +
      '<button type="button" id="ecMore" class="cornerzone" data-ec="menu"' +
      ' aria-expanded="' + (menuOpen ? 'true' : 'false') + '" aria-haspopup="true"' +
      ' aria-label="Nastavenie zvýraznenia hrán" title="Nastavenie — ktoré stavy hrán sa zvýraznia"></button>' +
      edgeCheckMenuHtml(st, menuOpen) + '</span>' + grainBtnHtml(grain) +
      '<span class="ecinfo">' + edgeCheckText(st) + grainInfoHtml(grain) + '</span>';
  }

  // Rozbaľovacie okno = ZDIELANY komponent (js/edge_menu.js). Okno mu len
  // povie, ktorá funkcia posiela prepnutie do Ruby a kde má stáť — markup,
  // texty, farebné štvorčeky aj živé počty sú spoločné s railom Inspectora.
  function edgeCheckMenuHtml(st, menuOpen){
    return ECM.menuHtml(st, menuOpen, { fn: 'edgeCheckOption', id: 'ecMenu', cls: 'ecmenu-studio' });
  }

  function edgeCheckSelectionHint(st){ return ECM.selectionHint(st); }

  function edgeCheckText(st){
    if (!st || !st.active) return 'Vypnuté — v modeli nie je nič nakreslené.';
    var o = st.options || {};
    var c = st.counts || {};
    var miss = ecNum(c.missing);
    var parts = [];
    if (o.show_missing) parts.push(miss + ' ' + edgePluralSk(miss) + ' bez olepu');
    if (o.show_extra) parts.push(ecNum(c.extra) + ' mimo pravidla');
    if (o.show_taped) parts.push(ecNum(c.taped) + ' olepených');
    if (!parts.length) return 'Žiadny stav nie je zapnutý — otvor nastavenie (roh tlačidla).';
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

  // K2/D-87: prepínač smeru kresby. ZÁMERNE obyčajné tlačidlo (nemá čo
  // nastavovať: buď kresbu vidíš, alebo nie).
  function grainBtnHtml(g){
    if (!g || !g.available) return '';
    var on = g.active === true;
    return '<button type="button" id="gcBtn" class="gcbtn' + (on ? ' on' : '') + '"' +
      ' data-gc="toggle" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Nakreslí na dielce čiary v smere kresby dekoru — blenda vs. dvere na prvý pohľad.' +
      ' Model sa nemení, kreslí sa nad ním.">' + ico('grain') + 'Smer kresby</button>';
  }

  // Dovetá k textu lišty. Vypnutý prepínač mlčí (o vypnutom stave už hovorí
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

  // Relay do Ruby — gen aj model_guid overuje SERVER (starý DOM / prepnutý
  // dokument sa odmietne a v modeli sa nič nezapne).
  function edgeCheckPayload(st){
    return { gen: (st && st.gen) || 0, model_guid: (st && st.model_guid) || '' };
  }

  // Klient posiela LEN kľúč a boolean; skladanie je v zdieľanom komponente,
  // aby všetky tri vstupné body posielali BAJT-ROVNAKÝ tvar.
  function edgeCheckOptionPayload(st, key, value){
    return ECM.optionPayload(edgeCheckPayload(st), key, value);
  }

  // Deep-link kotva (audit #12): N13 „Materiál" posiela ID skrinky a to sa
  // stane textom hladania. Spotrebuje sa PRAVE RAZ — server ju v dalsom pushi
  // uz neposle, takze pouzivatelovo vymazanie filtra prezije refresh.
  function anchorFilter(payload){
    var a = payload && payload.anchor;
    return (a == null) ? null : String(a).trim() || null;
  }

  // --------------------------------------------------- pamat tohto pocitaca
  function lsGet(key){
    try { return window.localStorage.getItem(key); } catch (e){ return null; }
  }
  function lsSet(key, value){
    try { window.localStorage.setItem(key, value); } catch (e){ /* privatny rezim */ }
  }

  function loadPrefs(){
    var cols = lsGet('nx_bom_cols');
    if (cols){
      try {
        var on = JSON.parse(cols);
        COLS.forEach(function(c){ if (!c.fixed && on[c.k] != null) c.on = !!on[c.k]; });
      } catch (e){ /* poskodena pamat = default */ }
    }
    var grp = lsGet('nx_bom_groups');
    if (grp){
      try { groupClosed = JSON.parse(grp) || {}; } catch (e){ groupClosed = {}; }
    }
    navMini = lsGet('nx_studio_nav') === 'mini';
  }

  function savePrefs(){
    var on = {};
    COLS.forEach(function(c){ on[c.k] = c.on; });
    lsSet('nx_bom_cols', JSON.stringify(on));
    lsSet('nx_bom_groups', JSON.stringify(groupClosed));
    lsSet('nx_studio_nav', navMini ? 'mini' : 'full');
  }

  // ------------------------------------------------------------ Ruby -> JS
  window.NX = {
    setStudio: function(data){
      ST = data || null;
      // Š10: stav prepínačov chodí v KAŽDOM pushi (a medzitým aj samostatným
      // echom nižšie) — klient si ho nikdy neodvodzuje.
      EDGE = (ST && ST.edge_check) ? ST.edge_check : null;
      GRAIN = (ST && ST.grain_check) ? ST.grain_check : null;
      var mdl = el('stModel');
      if (mdl) mdl.textContent = ST ? ('zákazka: ' + ST.model_title + ' · v' + ST.version) : '…';
      // Deep-link sekcie sa posiela PRAVE RAZ; kotva s nou.
      if (ST && ST.open_section && STUDIO_SECTIONS.indexOf(ST.open_section) >= 0){
        studioSec = ST.open_section;
        // Kotva predvyplna hladanie KUSOVNIKA (N13 posiela ID skrinky). Pri inej
        // sekcii by potichu prestavila filter, ktory pouzivatel ani nevidí —
        // preto sa aplikuje LEN so sekciou, do ktorej patri (review #7).
        var a = (studioSec === 'bom') ? anchorFilter(ST) : null;
        if (a) bomQ = a;
      }
      render();
    },
    setStatus: function(msg, err){
      var e = el('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    },
    // Maly echo push LISTY (nazov projektu + merge) po zapise nastavenia.
    // ZAMERNE neprekresluje celu listu: pouzivatel moze mat kurzor v poli
    // Projekt a re-render by mu ho vzal pod rukami. Hodnota inputu sa preto
    // nasadzuje LEN ked v nom prave nepise.
    setVepoBar: function(state){
      if (!ST) return;
      ST.vepo = state || ST.vepo;
      var v = ST.vepo || {};
      var inp = el('prjInput');
      if (inp && (typeof document === 'undefined' || document.activeElement !== inp)){
        inp.value = v.project || '';
      }
      if (inp) inp.placeholder = v.default_project || 'projekt';
      var chk = el('mergeChk');
      if (chk) chk.checked = v.merge_18_36 !== false;
    },
    // Š10: malé echo pushe stavu prepínačov (prepnutie odkiaľkoľvek — rail,
    // toto okno, okno Výroba — aj prepočet po prestavbe). Prekreslí sa LEN
    // lišta sekcie, zoznam nálezov sa nedotkne.
    setEdgeCheck: function(state){
      EDGE = state || null;
      if (studioSec === 'ctrl') renderTools();
    },
    setGrainCheck: function(state){
      GRAIN = state || null;
      if (studioSec === 'ctrl') renderTools();
    },
    // To isté nastavenie sa dá otvoriť z troch miest — keď ho používateľ
    // otvorí inde, toto sa zavrie (nikdy dve kópie naraz).
    closeEdgeMenu: function(){
      if (!ecMenuOpen) return;
      ecMenuOpen = false;
      if (studioSec === 'ctrl') renderTools();
    }
  };

  // --------------------------------------------------------------- render
  function render(){
    renderNav();
    renderHead();
    renderTools();
    renderBody();
  }

  function renderNav(){
    var box = el('snav');
    if (!box) return;
    var h = '';
    NAV.forEach(function(g){
      h += '<div class="sgrp">' + esc(g.grp) + '</div>';
      g.items.forEach(function(it){
        var on = (it.id === studioSec && !it.bridge && !it.disabled);
        var tip = it.disabled ? (it.t + ' — ' + it.disabled)
                : (it.bridge ? (it.t + ' — ' + it.bridge)
                : (it.hint ? (it.t + ' — ' + it.hint) : it.t));
        h += '<button type="button" class="navitem' + (on ? ' on' : '') + '"' +
             (it.disabled ? ' aria-disabled="true"' : '') +
             ' data-nav="' + esc(it.id) + '" title="' + esc(tip) + '">' +
             ico(it.ic) + '<span>' + esc(it.t) + '</span>' +
             // Š11: živé počty pri Kontrole — z counts KAŽDÉHO pushu.
             (it.badge ? navBadgeHtml(ST ? ST.counts : null) : '') +
             (it.bridge ? '<i class="nbridge" aria-hidden="true">↗</i>' : '') + '</button>';
      });
    });
    h += '<div class="navfoot"><button type="button" class="navitem" data-navmini' +
         ' title="Zbaliť navigáciu na ikony">' + ico('panel-left') +
         '<span>Zbaliť na ikony</span></button></div>';
    box.innerHTML = h;
    var studio = el('studio');
    if (studio) studio.className = 'studio' + (navMini ? ' navmini' : '');
  }

  function renderHead(){
    var box = el('sechead');
    if (!box) return;
    var m = SEC_META[studioSec] || { t: '—', hint: '' };
    box.innerHTML = '<h2>' + esc(m.t) + '</h2><span class="sechint">' + esc(m.hint) + '</span>' +
      '<span class="secmodel" id="stModel">' + (ST ? esc('zákazka: ' + ST.model_title + ' · v' + ST.version) : '…') + '</span>';
  }

  // Lista sekcie: primarna akcia vlavo, exporty vedla nej, hladanie a stlpce
  // vpravo (kontrakt §3 — ziadna globalna lista exportov).
  function renderTools(){
    var box = el('sectools');
    if (!box) return;
    if (!ST){ box.innerHTML = ''; return; }
    // ŠT-1c PR B1: lišta sekcie Rozpočet (prepínače DPH a režimu, prepočet
    // cien, obnovenie, exporty, ⚙) si kreslí js/budget.js — ten sa načítava
    // AŽ ZA týmto súborom, preto sa volá cez `typeof`.
    if (studioSec === 'budget'){
      if (typeof budRenderTools === 'function') budRenderTools();
      else box.innerHTML = '';
      return;
    }
    // ŠT-1c PR B2 (Š14): lišta sekcie Cenová ponuka (XLSX ponuky + Obnoviť) —
    // ten istý súbor, lebo ponuka je projekciou toho istého payloadu.
    if (studioSec === 'offer'){
      if (typeof budRenderOfferTools === 'function') budRenderOfferTools();
      else box.innerHTML = '';
      return;
    }
    // Š10: lišta sekcie Kontrola nesie OBA prepínače (a nič iné — exporty
    // kontrola nemá). Jeden riadok, žiadny nový blok: vertikálny priestor
    // je vzácny a nastavenie hrán je overlay pod tlačidlom.
    if (studioSec === 'ctrl'){
      box.innerHTML = edgeCheckBarHtml(EDGE, ecMenuOpen, GRAIN) +
        '<span class="spacer"></span>' +
        '<span class="sechint">Zoradené podľa závažnosti — poradie určuje server.</span>';
      return;
    }
    // ŠT-1c PR A (Š7): lišta sekcie Nákup kovania. Export patrí SEKCII
    // (kontrakt §3) — v okne Výroba visel v hlavičke tabuľky, tu je jediná
    // vec v lište; hint nahrádza pôvodný riadok nad tabuľkou (vertikálny
    // priestor je vzácny, preto NEIDE na vlastný riadok).
    if (studioSec === 'buy'){
      box.innerHTML = '<button type="button" class="ghostbtn" id="hwCsvBtn"' +
        ' title="CSV nákupného zoznamu — počíta sa z čerstvého modelu">' +
        ico('download') + ' CSV kovania</button>' +
        // Review P3: sekcia musí mať vlastnú cestu k čerstvým číslam. Prestavba
        // skrinky z Inspectora sem sama nedorazí, takže bez „Obnoviť" by sa dal
        // objednávať nákupný zoznam zo starých počtov — a odísť po ne do
        // Kusovníka je skrytá cesta (rovnaký dôvod ako v lište Kusovníka).
        '<button type="button" class="ghostbtn" id="refreshBtn"' +
        ' title="Prepočítať nákupný zoznam z aktuálneho modelu">' +
        ico('refresh-cw') + ' Obnoviť</button>' +
        '<span class="spacer"></span>' +
        '<span class="sechint">Klik na riadok generiky označí vlastníka v modeli.</span>';
      return;
    }
    var vw = function(id, t, tip){
      return '<button type="button" class="bomvw' + (bomView === id ? ' on' : '') +
             '" data-view="' + id + '" title="' + esc(tip) + '">' + esc(t) + '</button>';
    };
    var v = ST.vepo || {};
    var h = '<div class="bomviews">' +
      vw('parts', 'Dielce', 'Výrobné dielce po materiáloch') +
      vw('sheets', 'Platne', 'Súpis platní — odvodený z kusovníka') +
      vw('abs', 'ABS', 'Súpis ABS pások — odvodený z kusovníka') + '</div>' +
      '<button type="button" class="primary" id="vepoBtn"' +
      ' title="Exportuje prírezy (po odpočte ABS) do VEPO CSV — vyberieš priečinok">' +
      ico('download') + ' VEPO export</button>' +
      // audit #18: exporty, ktore este neexistuju, su VIDITELNE a neaktivne
      // s dovodom (D-78) — nie skryte a nie mrtve.
      '<button type="button" class="ghostbtn" aria-disabled="true"' +
      ' title="Export kusovníka do XLSX zatiaľ neexistuje — príde v ďalšej dávke">' +
      ico('download') + ' XLSX</button>' +
      '<button type="button" class="ghostbtn" aria-disabled="true"' +
      ' title="Export kusovníka do CSV zatiaľ neexistuje — príde v ďalšej dávke">' +
      ico('download') + ' CSV</button>' +
      '<label class="prjbox" title="Názov projektu — priečinok a súbory exportu, titulok rozpočtu aj cenovej ponuky">' +
      '<span>Projekt</span><input id="prjInput" type="text" value="' + esc(v.project || '') +
      '" placeholder="' + esc(v.default_project || 'projekt') + '"></label>' +
      // audit #16: stav checkboxu sa berie z payloadu pri KAZDOM pushi.
      '<label class="mergebox" title="Materiály 18 a 36 mm do jedného súboru (bežná objednávka)">' +
      '<input type="checkbox" id="mergeChk"' + (v.merge_18_36 === false ? '' : ' checked') + '> 18+36 spolu</label>' +
      '<span class="spacer"></span>' +
      '<div class="searchbox">' + ico('search') +
      '<input id="bomSearch" placeholder="Hľadať dielec / skrinku…" value="' + esc(bomQ) + '"></div>' +
      // Kusovnik je zivy (server pushuje pri prepnuti modelu a po zmene
      // katalogu), ale prestavba skrinky z Inspectora sem sama nedorazi — okno
      // musi mat rucnu cestu k cerstvym cislam, inak by sa VEPO exportovalo
      // zo starych.
      '<button type="button" class="ghostbtn" id="refreshBtn"' +
      ' title="Prepočítať kusovník z aktuálneho modelu">' + ico('refresh-cw') + ' Obnoviť</button>';
    if (bomView === 'parts'){
      h += '<button type="button" class="ghostbtn" id="colBtn"' +
           ' title="Voliteľné stĺpce — voľba sa pamätá na tomto počítači" aria-expanded="' +
           (colMenuOpen ? 'true' : 'false') + '">' + ico('columns-3') + ' Stĺpce ' +
           ico('chevron-down') + '</button>' + colMenuHtml();
    }
    box.innerHTML = h;
  }

  function colMenuHtml(){
    if (!colMenuOpen) return '';
    var h = '<div class="colmenu" id="colMenu"><div class="mgrp">Stĺpce tabuľky</div>';
    COLS.forEach(function(c, i){
      h += '<label class="' + (c.fixed ? 'fixed' : '') + '"><input type="checkbox" data-col="' + i + '"' +
           (c.on ? ' checked' : '') + (c.fixed ? ' disabled' : '') + '> ' + esc(c.t) + '</label>';
    });
    h += '</div>';
    return h;
  }

  function renderBody(){
    var box = el('secbody');
    if (!box) return;
    if (!ST){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    // ŠT-1c PR B1: telo sekcie Rozpočet kreslí js/budget.js (píše si do
    // `#secbody` samo — potrebuje okolo zápisu obnovu fokusu v rozpísaných
    // políčkach).
    if (studioSec === 'budget'){
      if (typeof budRenderBody === 'function') budRenderBody();
      else box.innerHTML = '<div class="muted">Rozpočet sa nenačítal (js/budget.js).</div>';
      return;
    }
    if (studioSec === 'offer'){
      if (typeof budRenderOfferBody === 'function') budRenderOfferBody();
      else box.innerHTML = '<div class="muted">Cenová ponuka sa nenačítala (js/budget.js).</div>';
      return;
    }
    if (studioSec === 'ctrl') box.innerHTML = ctrlSection();
    else if (studioSec === 'buy') box.innerHTML = buySection(ST.hardware_sets || null, ST.hardware || []);
    else if (bomView === 'sheets') box.innerHTML = sheetsTable();
    else if (bomView === 'abs') box.innerHTML = absTable();
    else box.innerHTML = partsTable();
  }

  // Š6: pri pisani sa prekresluje LEN telo — inak by input stratil fokus.
  function renderBomBody(){ renderBody(); }

  // ---------------------------------------------------- sekcia KONTROLA
  // Zoznam skladá SERVER (poradie, dedup, texty aj počty) — klient LEN kreslí
  // a filtruje. „Kontrola bez nálezov" hovorí o VÝROBNÝCH dátach: hrany bez
  // olepu nie sú položkou semaforu (na tie je prepínač v lište).
  function ctrlSection(){
    var all = ST.control || [];
    var rows = ctrlRows(all, ctrlFilter);
    var h = semaforHtml(ST.counts, ctrlFilter);
    if (ctrlFilter !== 'all'){
      h += '<div class="hint ctrlfilter">Filter: len ' +
        (ctrlFilter === 'red' ? 'červené' : 'oranžové') +
        ' nálezy (' + rows.length + ' z ' + all.length + ') — klik na chip ho zruší.</div>';
    }
    if (!all.length){
      return h + '<div class="muted">Kontrola bez nálezov — dáta výroby čisté.</div>';
    }
    if (!rows.length){
      return h + '<div class="muted">Filtru nezodpovedá žiadny nález — klik na chip filter zruší.</div>';
    }
    rows.forEach(function(pair){ h += ctrlRowHtml(pair[0], pair[1]); });
    return h + '<div class="hint">Klik na riadok označí nález v modeli. Ceruzka ho navyše otvorí ' +
      'v Inspectore. Hrany bez olepu nie sú nálezom semaforu — na tie je prepínač v lište.</div>';
  }

  // ------------------------------------------------------- pohlad DIELCE
  function partsTable(){
    var meta = ST.materials_meta || {};
    var emeta = ST.edges_meta || {};
    var g = groupBom(ST.rows, ST.sheets, bomQ);
    var cols = activeCols(COLS);
    var h = '';
    if (!(ST.rows || []).length){
      return '<div class="muted">Žiadne výrobné dielce v modeli — vlož korpus alebo dosku.</div>';
    }
    g.groups.forEach(function(grp){
      var m = meta[grp.id] || {};
      var closed = !bomQ && !!groupClosed[grp.id];
      var hex = rgbHex(m.color);
      h += '<div class="grp' + (closed ? ' closed' : '') + '">' +
        '<button type="button" class="grphead" data-grp="' + esc(grp.id) + '" aria-expanded="' +
          (closed ? 'false' : 'true') + '">' +
          '<span class="chev"></span>' +
          (hex ? '<span class="sw" style="background:' + hex + '"></span>' : '<span class="sw"></span>') +
          '<span class="gname">' + esc(m.label || grp.id) + '</span>' +
          '<span class="gsub">' + (m.th == null ? '' : num(m.th) + ' mm') +
          (m.uni ? ' · <span class="wtagchip">UNI</span>' : '') + '</span>' +
          '<span class="gsum">' + num(grp.ks) + ' ks · <b>' + num(grp.m2, 2) + ' m²</b></span></button>' +
        '<table class="bomtab"><thead><tr>' +
          cols.map(function(c){ return '<th class="' + (c.num ? 'num' : '') + '">' + esc(c.t) + '</th>'; }).join('') +
          '<th class="acth"></th></tr></thead><tbody>';
      grp.rows.forEach(function(r){
        // Adresa riadku = jeho INDEX v serverovom poli `rows` (vzor okna
        // Vyroba). Klik potom posiela KLUC riadku, nie pids — Ruby si po flushi
        // editov najde cerstve refs (GH #48 P2).
        h += '<tr class="bomrow" data-i="' + (ST.rows || []).indexOf(r) + '">' +
          cols.map(function(c){
            if (c.k === 'abs'){
              return '<td class="absc" title="' + esc(absFull(r, emeta)) + '">' +
                     esc(absCompact(r, emeta)) + '</td>';
            }
            var v = cellValue(r, c.k);
            var txt = c.num ? num(v) : (String(v == null ? '' : v) || '—');
            return '<td class="' + (c.num ? 'num' : '') + '">' + esc(txt) + '</td>';
          }).join('') +
          '<td class="acth"><span class="rowact">' +
            '<button type="button" class="ract" data-act="eye" title="Označiť v modeli">' + ico('eye') + '</button>' +
            '<button type="button" class="ract" data-act="edit" title="Upraviť dielec v Inspectore">' + ico('pencil') + '</button>' +
          '</span></td></tr>';
      });
      h += '</tbody></table></div>';
    });
    if (!g.shown){
      h += '<div class="muted" style="padding:14px 4px">Filtru „' + esc(bomQ) +
           '" nezodpovedá žiadny dielec — skús kratší text (hľadá sa aj bez diakritiky).</div>';
    }
    h += totalRow(g);
    h += '<div class="hint">Klik na riadok označí dielec v modeli. Ceruzka ho navyše otvorí v Inspectore.</div>';
    return h;
  }

  // Sucty su SERVEROVE cisla (`totals`) — JS ich len vypise. Pri filtri sa
  // namiesto nich ukaze POCITADLO filtra (to je pocet riadkov, nie suma).
  function totalRow(g){
    var t = ST.totals || {};
    var left = bomQ
      ? 'Filter: <b>' + g.shown + ' z ' + g.total + ' riadkov</b>'
      : 'Spolu <b>' + num(t.parts) + ' dielcov</b> · <b>' + num(t.m2, 2) + ' m²</b> · ' +
        num(t.materials) + ' materiálov';
    return '<div class="totrow"><span>' + left + '</span><span class="spacer"></span>' +
      '<span class="tmuted">ABS spolu ' + num(t.bm, 1) + ' bm · odhad ' +
      num(t.plates_min, 1) + ' – ' + num(t.plates_max, 1) + ' platní</span></div>';
  }

  // ------------------------------------------------------- pohlad PLATNE
  //
  // 2B-1 / D-43 DUPLAK: material, ktoreho plocha vznikla LEN z duplakovych
  // dielcov, NIE JE v `sheets` (nema vlastne vyrobne dielce), ale JE
  // v `sheet_estimate` — lebo sa reálne nakupuje. Keby tabulka isla iba cez
  // `sheets`, ten nakup by z nej zmizol a suctovy riadok (ktory rata cez VSETKY
  // polozky odhadu) by s nou nesedel. Preto sa zoznam sklada z OBOCH zdrojov.
  function sheetRows(sheets, estimate, rows){
    var est = {};
    (estimate || []).forEach(function(e){ est[e.material_id] = e; });
    // Vazby duplakov z BOM riadkov. GH #94 P2: rovnaky material moze niest
    // ROZNE vazby (katalog sa zmenil medzi rebuildmi — BOM ich drzi oddelene
    // v kluci), preto ZOZNAM, nie posledna hodnota.
    var dup = {};
    (rows || []).forEach(function(r){
      if (!r || !r.material_source) return;
      var lbl = 'lepí sa ' + r.material_source.multiplier + '× z ' + r.material_source.material_id;
      var list = dup[r.material_id] = dup[r.material_id] || [];
      if (list.indexOf(lbl) < 0) list.push(lbl);
    });
    var out = [];
    var seen = {};
    (sheets || []).forEach(function(s){
      seen[s.material_id] = true;
      out.push({ mid: s.material_id, m2: s.m2, quantity: s.quantity,
                 est: est[s.material_id] || null, dup: dup[s.material_id] || [],
                 purchaseOnly: false });
    });
    (estimate || []).forEach(function(e){
      if (seen[e.material_id]) return;
      out.push({ mid: e.material_id, m2: e.m2, quantity: null, est: e,
                 dup: dup[e.material_id] || [], purchaseOnly: true });
    });
    return out;
  }

  function sheetsTable(){
    var meta = ST.materials_meta || {};
    var list = sheetRows(ST.sheets, ST.sheet_estimate, ST.rows).filter(function(s){
      if (!bomQ) return true;
      var m = meta[s.mid] || {};
      return normText((m.label || '') + ' ' + s.mid).indexOf(normText(bomQ)) >= 0;
    });
    var h = '<table class="bomtab flat"><thead><tr><th>Materiál</th><th class="num">Hrúbka</th>' +
      '<th>Formát platne</th><th class="num">Dielcov</th><th class="num">m² dielcov</th>' +
      '<th class="num">Odhad platní</th></tr></thead><tbody>';
    list.forEach(function(s){
      var m = meta[s.mid] || {};
      var e = s.est;
      var hex = rgbHex(m.color);
      var fb = e && e.fallback;
      var fmt = e ? (num(e.sheet_size[0]) + ' × ' + num(e.sheet_size[1])) : '—';
      var pl = e ? (num(e.count_min, 1) + ' – ' + num(e.count_max, 1)) : '—';
      // M-B1 (audit F7): UNI = materiál neurčený — počet platní je len
      // orientačný (formát je pracovný default), NIE nákupné číslo.
      var plNote = (e && e.uni === true) ? ' <span class="muted">(orientačne — UNI)</span>' : '';
      // Duplák bez vlastnej platne: kupuje sa ZDROJ, tak to bunka aj povie.
      if (!e && s.dup.length){ pl = esc(s.dup.join(' · ')); plNote = ''; }
      // Anotácia „+X dupl.": m² nákupu je väčšie než m² vlastných dielcov.
      var m2cell = '<b>' + num(s.m2, 2) + '</b>';
      if (e && e.doubled_m2){
        m2cell = '<b>' + num(e.m2, 2) + '</b> <span class="muted" title="Nákup vrátane duplákov: ' +
                 'vlastné dielce + ' + num(e.doubled_m2, 2) + ' m² z ' + num(e.doubled_quantity) +
                 ' ks duplákov">(+' + num(e.doubled_m2, 2) + ' dupl.)</span>';
      }
      h += '<tr class="sheetrow" data-mid="' + esc(s.mid) + '">' +
        '<td>' + (hex ? '<span class="cellsw" style="background:' + hex + '"></span>' : '') +
          esc(m.label || s.mid) +
          (e && e.uni === true ? ' <span class="wtagchip">UNI</span>' : '') +
          (s.purchaseOnly ? ' <span class="muted">(nákup pre dupláky)</span>' : '') + '</td>' +
        '<td class="num">' + (m.th == null ? '—' : num(m.th) + ' mm') + '</td>' +
        '<td' + (fb ? ' class="estfb" title="Materiál nemá formát v katalógu — použitý 2800×2070"' : '') +
          '>' + esc(fmt) + '</td>' +
        '<td class="num">' + (s.quantity == null ? '—' : num(s.quantity)) + '</td>' +
        '<td class="num">' + m2cell + '</td>' +
        '<td class="num"><b>' + pl + '</b>' + plNote + '</td></tr>';
    });
    h += '</tbody></table>';
    if (!list.length) h += '<div class="muted" style="padding:14px 4px">Filtru nezodpovedá žiadny materiál.</div>';
    var t = ST.totals || {};
    h += '<div class="totrow" style="margin-top:10px"><span>Spolu <b>odhad ' +
      num(t.plates_min, 1) + ' – ' + num(t.plates_max, 1) + ' platní</b> · ' + num(t.m2, 2) +
      ' m² dielcov</span><span class="spacer"></span>' +
      '<span class="tmuted">orientačný rozsah (prerez 10–25 %), NIE nárezový plán</span></div>' +
      '<div class="hint">Duplák sa lepí zo zdrojových platní — jeho plocha sa počíta do nákupu ' +
      'zdroja. Nákupné bm ABS s rezervou a ceny sú v sekcii Rozpočet.</div>';
    return h;
  }

  // ---------------------------------------------------------- pohlad ABS
  function absTable(){
    var meta = ST.edges_meta || {};
    var list = (ST.edging || []).filter(function(e){
      if (!bomQ) return true;
      var m = meta[e.abs_id] || {};
      return normText((m.label || '') + ' ' + (m.decor || '') + ' ' + e.abs_id).indexOf(normText(bomQ)) >= 0;
    });
    var h = '<table class="bomtab flat"><thead><tr><th>ABS páska</th><th>K dekoru</th>' +
      '<th class="num">Hrúbka</th><th class="num">Hrán</th><th class="num">bm</th>' +
      '</tr></thead><tbody>';
    list.forEach(function(e){
      var m = meta[e.abs_id] || {};
      var hex = rgbHex(m.color);
      h += '<tr class="absrow" data-aid="' + esc(e.abs_id) + '">' +
        '<td>' + (hex ? '<span class="cellsw" style="background:' + hex + '"></span>' : '') +
          esc(m.label || e.abs_id) + '</td>' +
        '<td>' + esc(m.decor || '—') + '</td>' +
        '<td class="num">' + (m.th == null ? '—' : num(m.th, 1) + ' mm') + '</td>' +
        '<td class="num">' + num(e.edges) + '</td>' +
        '<td class="num"><b>' + num(e.bm, 1) + '</b></td></tr>';
    });
    h += '</tbody></table>';
    if (!list.length) h += '<div class="muted" style="padding:14px 4px">Filtru nezodpovedá žiadna páska.</div>';
    var t = ST.totals || {};
    h += '<div class="totrow" style="margin-top:10px"><span>Spolu <b>' + num(t.bm, 1) +
      ' bm</b> · ' + num(t.edges) + ' pások</span><span class="spacer"></span>' +
      '<span class="tmuted">spotreba bez rezervy</span></div>' +
      // VEDOMA ODCHYLKA ST-1a (drzi dalej): stlpce „bm s rezervou" a „€/bm" tu
      // NIE SU — obe cisla pochadzaju z payloadu ROZPOCTU a patria do JEHO
      // sekcie ABS. Prazdny stlpec by klamal, dopocitat rezervu v klientovi je
      // zakazane; od ŠT-1c PR B1 je Rozpocet o jeden klik vedla (sekcia).
      '<div class="hint">Nákupné bm s rezervou a cena za bm sú v sekcii Rozpočet — ' +
      'rezerva na olep sa nastavuje v Nastaveniach rozpočtu.</div>';
    return h;
  }

  // ----------------------------------------------------------- akcie -> Ruby
  function selectRow(key, focusInspector){
    if (!ST || typeof window === 'undefined' || !window.sketchup || !sketchup.nx_select) return;
    sketchup.nx_select(JSON.stringify({ gen: ST.gen, parts_key: key,
                                        focus_inspector: !!focusInspector }));
  }

  // Jeden push prináša VŠETKY sekcie, takže sa prepočíta všetko — status ale
  // hovorí o tom, na čo sa používateľ práve pozerá (inak by po kliku v Nákupe
  // hlásil kusovník a vyzeralo by to ako zlé tlačidlo).
  var REFRESH_STATUS = { buy: 'Prepočítavam nákupný zoznam…', budget: 'Prepočítavam rozpočet…',
                         offer: 'Prepočítavam cenovú ponuku…' };

  function requestRefresh(){
    if (!window.sketchup || !sketchup.refresh_bom) return;
    NX.setStatus(REFRESH_STATUS[studioSec] || 'Prepočítavam kusovník…', false);
    sketchup.refresh_bom('');
  }

  function vepoExport(){
    if (!ST || !window.sketchup || !sketchup.vepo_export) return;
    NX.setStatus('Exportujem VEPO…', false);
    sketchup.vepo_export(JSON.stringify({ gen: ST.gen }));
  }

  // ŠT-1c PR A: CSV nákupného zoznamu kovania. Názov projektu sa NEPOSIELA —
  // číta ho SERVER (`ProductionCore.project_name`), aby všetky exporty
  // pomenovali zákazku rovnako. Od tejto dávky nesie aj `gen` (audit #15):
  // nákupný dokument nesmie vzniknúť z okna so zastaranými dátami.
  function hwCsvExport(){
    if (!ST || !window.sketchup || !sketchup.hw_csv_export) return;
    NX.setStatus('Exportujem nákupný zoznam…', false);
    sketchup.hw_csv_export(JSON.stringify({ gen: ST.gen }));
  }

  // Klik na riadok generiky = OZNAC VLASTNIKA v modeli. Posiela sa KLUC
  // riadku (nie pids) — Ruby si po flushi editov nájde čerstvé refs (Codex
  // GH #48 P2: rebuild po flushi mení persistent id). Ide TOU ISTOU cestou
  // ako klik v Kusovníku (`nx_select` → relay cez panel).
  function selectHwRow(key){
    if (!ST || typeof window === 'undefined' || !window.sketchup || !sketchup.nx_select) return;
    sketchup.nx_select(JSON.stringify({ gen: ST.gen, hw_key: key }));
  }

  // Nazov projektu aj merge zapisuje SERVER (audit #1) — okno posiela iba
  // hodnotu a svoju identitu; po zapise pride cerstvy payload OBOM oknam.
  function sendVepoOpts(attrs){
    if (!ST || !window.sketchup || !sketchup.studio_set_vepo_opts) return;
    var p = { gen: ST.gen, model_guid: ST.model_guid || '' };
    if (attrs.project !== undefined) p.project = attrs.project;
    if (attrs.merge !== undefined) p.merge = attrs.merge;
    sketchup.studio_set_vepo_opts(JSON.stringify(p));
  }

  function bridgeTo(id){
    if (!window.sketchup || !sketchup.studio_bridge) return;
    sketchup.studio_bridge(JSON.stringify({ section: id }));
  }

  // ---- ŠT-1b: akcie sekcie Kontrola -> Ruby -------------------------------

  // Š9: klik na nález. Posiela sa STABILNY kluc problemu (nie pids) — Ruby po
  // flushi editov validáciu prepočíta a entity dohľadá podľa identity.
  // Ceruzka navyše zdvihne Inspector (`focus_inspector`, vzor Kusovníka).
  function selectProblem(key, focusInspector){
    if (!ST || typeof window === 'undefined' || !window.sketchup || !sketchup.nx_select) return;
    sketchup.nx_select(JSON.stringify({ gen: ST.gen, problem_key: key,
                                        focus_inspector: !!focusInspector }));
  }

  // D-83: „Nahradiť UNI…" — modal patrí oknu Materiály, sem chodí len žiadosť.
  // Identitu (gen + model_guid) overuje SERVER.
  function requestReplaceUni(uniId){
    if (!uniId || !ST || !window.sketchup || !sketchup.replace_uni) return;
    sketchup.replace_uni(JSON.stringify({ uni_id: uniId, gen: ST.gen,
                                          model_guid: ST.model_guid || '' }));
  }

  function edgeCheckToggle(){
    if (!ST || !window.sketchup || !sketchup.edge_check_toggle) return;
    sketchup.edge_check_toggle(JSON.stringify(edgeCheckPayload(ST)));
  }

  // Volá ju zdieľané rozbaľovacie okno (`fn` v edge_menu.js) — musí byť
  // globálna, preto ju vešiame na window (súbor beží aj v Node testoch).
  function edgeCheckOption(key, value){
    if (!ST || !window.sketchup || !sketchup.edge_check_option) return;
    sketchup.edge_check_option(JSON.stringify(edgeCheckOptionPayload(ST, key, value)));
  }
  if (typeof window !== 'undefined') window.edgeCheckOption = edgeCheckOption;

  function grainCheckToggle(){
    if (!ST || !window.sketchup || !sketchup.grain_check_toggle) return;
    sketchup.grain_check_toggle(JSON.stringify(edgeCheckPayload(ST)));
  }

  // Otvorenie/zatvorenie nastavenia je CISTO klientska vec (nikam sa neukladá).
  // Otvorenie tu zavrie tú istú kópiu v raile Inspectora aj v okne Výroba —
  // Ruby to len prepošle (žiadny stav, žiadny zápis).
  function edgeMenuToggle(){
    ecMenuOpen = !ecMenuOpen;
    if (ecMenuOpen && window.sketchup && sketchup.edge_menu_open) sketchup.edge_menu_open('');
    renderTools();
  }

  function edgeMenuClose(){
    if (!ecMenuOpen) return;
    ecMenuOpen = false;
    renderTools();
  }

  // ŠT-1c PR B2 (kontrakt #9): žije práve teraz D-15 modal? Komponent
  // `js/nx_modal.js` sa načítava PRED studio.js, ale v Node testoch nemusí
  // existovať vôbec — preto obozretne.
  function nxModalOpen(){
    return typeof window !== 'undefined' && !!window.NXModal && NXModal.isOpen() === true;
  }

  function navItem(id){
    var found = null;
    NAV.forEach(function(g){
      g.items.forEach(function(it){ if (it.id === id) found = it; });
    });
    return found;
  }

  function onNav(id){
    var it = navItem(id);
    if (!it) return;
    if (it.disabled){ NX.setStatus(it.t + ' — ' + it.disabled, true); return; }
    if (it.bridge){ bridgeTo(id); return; }
    // ŠT-1c PR B2: klientske `goto` (položka navigácie, ktorej obsah bol ČASŤOU
    // inej sekcie) ZANIKLO spolu s náhľadom cenovej ponuky vnútri Rozpočtu —
    // `offer` je od tejto dávky plnohodnotná sekcia.
    studioGoSection(id);
  }

  // Prepnutie sekcie z KÓDU (navigácia, chip súčtu v Rozpočte, nález Kontroly).
  // Musí byť globálna — volá ju aj js/budget.js, ktorý sa načítava za týmto
  // súborom a vlastný stav sekcií nemá.
  function studioGoSection(id){
    if (STUDIO_SECTIONS.indexOf(id) < 0) return;
    studioSec = id;
    render();
  }
  if (typeof window !== 'undefined') window.studioGoSection = studioGoSection;

  // ------------------------------------------------------------- listenery
  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(ev){
      var t = ev.target;
      if (!t || !t.closest) return;
      // Rozbalene okno stlpcov zatvara klik mimo neho (aj mimo jeho tlacidla).
      if (colMenuOpen && !t.closest('#colMenu') && !t.closest('#colBtn')){
        colMenuOpen = false;
        renderTools();
      }
      // Š10: klik MIMO spúšťača zatvára 3-stavové nastavenie (vzor railu).
      // Rieši sa TU a nie druhým listenerom: stopPropagation medzi dvoma
      // listenermi na TOM ISTOM uzle nefunguje.
      if (ecMenuOpen && !t.closest('.echk')) edgeMenuClose();
      // Prepínače lišty Kontroly.
      var ec = t.closest('[data-ec]');
      if (ec){
        if (ec.getAttribute('data-ec') === 'menu') edgeMenuToggle();
        else edgeCheckToggle();
        return;
      }
      if (t.closest('[data-gc]')){ grainCheckToggle(); return; }
      var nav = t.closest('[data-nav]');
      if (nav){ onNav(nav.getAttribute('data-nav')); return; }
      // Š8: semaforový chip = filter (druhý klik ho zruší). Je to čisto
      // klientska vec — server sa nevolá a zoznam sa neprepočítava.
      var chip = t.closest('[data-sev]');
      if (chip){
        var sev = chip.getAttribute('data-sev');
        ctrlFilter = (ctrlFilter === sev) ? 'all' : sev;
        renderBody();
        return;
      }
      // Š9: riadok nálezu — klik/oko = označ, ceruzka = označ + Inspector
      // dopredu, „Nahradiť UNI…" a rozpočtové premostenie majú vlastnú akciu.
      var crow = t.closest('[data-ci]');
      if (crow){
        var ci = parseInt(crow.getAttribute('data-ci'), 10);
        var it = (ST && ST.control) ? ST.control[ci] : null;
        if (!it) return;
        var cact = t.closest('button.goact');
        var what = cact ? cact.getAttribute('data-act') : '';
        if (what === 'uni'){ requestReplaceUni(cact.getAttribute('data-uni')); return; }
        // ŠT-1c PR B1: rozpočtové upozornenie NEMÁ entitu v modeli — vedie do
        // sekcie Rozpočet TOHO ISTÉHO okna, rovno na časť, ktorej sa týka
        // (`budget_section` skladá server). Žiadne premostenie do iného okna.
        if (it.category === 'budget'){
          studioGoSection('budget');
          if (typeof budGoto === 'function') budGoto(it.budget_section);
          return;
        }
        if (!it.stable_key) return;
        selectProblem(it.stable_key, what === 'edit');
        return;
      }
      if (t.closest('[data-navmini]')){ navMini = !navMini; savePrefs(); renderNav(); return; }
      if (t.closest('#colBtn')){ colMenuOpen = !colMenuOpen; renderTools(); return; }
      if (t.closest('#vepoBtn')){ vepoExport(); return; }
      if (t.closest('#hwCsvBtn')){ hwCsvExport(); return; }
      if (t.closest('#refreshBtn')){ requestRefresh(); return; }
      // ŠT-1c PR A: riadok generiky kovania — klik označí vlastníka v modeli.
      var hwr = t.closest('tr.hwrow');
      if (hwr){
        var hi = parseInt(hwr.getAttribute('data-i'), 10);
        var g = (ST && ST.hardware) ? ST.hardware[hi] : null;
        if (g && g.key) selectHwRow(g.key);
        return;
      }
      var vbtn = t.closest('[data-view]');
      if (vbtn){ bomView = vbtn.getAttribute('data-view'); colMenuOpen = false; renderTools(); renderBody(); return; }
      var grp = t.closest('[data-grp]');
      if (grp){
        var gid = grp.getAttribute('data-grp');
        groupClosed[gid] = !groupClosed[gid];
        savePrefs();
        renderBody();
        return;
      }
      // Š3: ceruzka = vyber + Inspector dopredu; oko aj klik na riadok = vyber.
      var act = t.closest('button.ract');
      var row = t.closest('tr.bomrow');
      if (row){
        var i = parseInt(row.getAttribute('data-i'), 10);
        var r = (ST && ST.rows) ? ST.rows[i] : null;
        if (!r || !r.key) return;
        selectRow(r.key, !!(act && act.getAttribute('data-act') === 'edit'));
      }
    });

    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t) return;
      if (t.hasAttribute && t.hasAttribute('data-col')){
        var i = parseInt(t.getAttribute('data-col'), 10);
        if (!isNaN(i) && COLS[i] && !COLS[i].fixed){
          COLS[i].on = !!t.checked;
          savePrefs();
          renderBody();
        }
        return;
      }
      if (t.id === 'mergeChk'){ sendVepoOpts({ merge: !!t.checked }); return; }
      if (t.id === 'prjInput'){ sendVepoOpts({ project: t.value }); }
    });

    document.addEventListener('input', function(ev){
      if (ev.target && ev.target.id === 'bomSearch'){
        bomQ = ev.target.value;
        renderBomBody();
      }
    });

    document.addEventListener('keydown', function(ev){
      if (ev.key === 'Enter' && ev.target && ev.target.id === 'prjInput') ev.target.blur();
      // Š10 (audit #6): nastavenie zatvára klik mimo AJ Escape — vzor
      // warnpanelu a railu Inspectora. Fokus patrí späť na rohové tlačidlo,
      // inak by po Escape skončil v prázdne.
      // ŠT-1c PR B2 (kontrakt #9): keď je otvorený D-15 modal, Escape patrí
      // JEMU. Oba listenery visia na `document`, takže `stopPropagation`
      // medzi nimi NEFUNGUJE — podmienka musí byť tu (rovnaká lekcia ako pri
      // zatváraní `ecMenu` klikom mimo: rieši sa v JEDNOM listeneri).
      if (ev.key === 'Escape' && ecMenuOpen && !nxModalOpen()){
        edgeMenuClose();
        var more = el('ecMore');
        if (more){ try { more.focus(); } catch (e) {} }
      }
    });
  }

  if (typeof window !== 'undefined'){
    window.onload = function(){
      loadPrefs();
      if (window.sketchup && sketchup.ready) sketchup.ready('');
    };
  }

  // Node testy (tests/js/test_st1a_studio.js, test_st1b_kontrola.js a od ŠT-1b
  // aj test_d104/test_d105/test_k2/test_abs_rail_3stav) — LEN ciste funkcie
  // bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = {
      STUDIO_SECTIONS: STUDIO_SECTIONS, COLS: COLS, NAV: NAV,
      normText: normText, rowText: rowText, rowHit: rowHit, groupBom: groupBom,
      sheetRows: sheetRows,
      activeCols: activeCols, cellValue: cellValue, grainLabel: grainLabel,
      absCompact: absCompact, absFull: absFull, rgbHex: rgbHex,
      navBridgeIds: navBridgeIds, anchorFilter: anchorFilter, navItem: navItem,
      nxModalOpen: nxModalOpen,
      // ŠT-1b sekcia Kontrola (Š8–Š11)
      semaforHtml: semaforHtml, ctrlRows: ctrlRows, ctrlRowHtml: ctrlRowHtml,
      ctrlActionsHtml: ctrlActionsHtml, navBadgeHtml: navBadgeHtml,
      // ŠT-1c PR A sekcia Nákup kovania (Š7) + D-93 znamienko ručného zásahu
      // (sada tests/js/test_d93_nl_override.js sa sem presunula z production.js)
      buySection: buySection, price: price, hwManualMark: hwManualMark,
      // Š10 prepinace (sady D-104 / D-105 / K2 / ABS rail 3-stav)
      edgeCheckBarHtml: edgeCheckBarHtml, edgeCheckText: edgeCheckText,
      edgePluralSk: edgePluralSk, edgeCheckPayload: edgeCheckPayload,
      edgeCheckMenuHtml: edgeCheckMenuHtml, edgeCheckOptionPayload: edgeCheckOptionPayload,
      edgeCheckSelectionHint: edgeCheckSelectionHint,
      grainBtnHtml: grainBtnHtml, grainCheckText: grainCheckText,
      grainPartPluralSk: grainPartPluralSk
    };
  }
