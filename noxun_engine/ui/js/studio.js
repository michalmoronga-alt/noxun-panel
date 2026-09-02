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
  // ŠT-3c-1 (review #225 P1): VEREJNY citatel aktivnej sekcie. `#secbody`
  // a `#sectools` su ZDIELANE uzly — echo jednej sekcie do nich nesmie
  // pisat, kym je otvorena INA (inak by ulozenie sablony z Inspectora
  // prepisalo rozpisany formular Rozpoctu). Cita sa, nikdy nenastavuje.
  function studioActiveSection(){ return studioSec; }
  // LEN pre Node testy: nastavi aktivnu sekciu BEZ kreslenia okna (`render`
  // potrebuje cely DOM). Produkcia prepina sekciu vyhradne `studioGoSection`.
  function studioSetSectionForTest(id){ studioSec = id; }
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
  var DIRECTION = null;
  var ecMenuOpen = false;
  // SMOKE 1A: to iste plati pre rohove nastavenie VEPO exportu — otvorenost je
  // CISTO klientska (nikam sa neuklada), hodnota checkboxu je zo servera.
  var vepoMenuOpen = false;

  // SMOKE 22.8. (schvalene): NEAKTUALNOST okna. Studio cisla neprepocitava samo
  // — kym sa nestlaci „Obnoviť", visia v nom cisla z posledneho prepoctu. Server
  // (StudioModelWatch) posle `NX.markStale()`, ked sa v modeli OD TOHO PREPOCTU
  // nieco zmenilo; tlacidlo zozltne. Je to stav OKNA (nie zakazky): nikam sa
  // neuklada a zhadzuje ho VYHRADNE prichod plneho payloadu (`setStudio`).
  // Premennú číta aj `js/budget.js` (lišty Rozpočtu a Ponuky) — presne tak, ako
  // číta `ST` a `studioSec`.
  var staleFlag = false;
  // Sirka signalu je PRIZNANA: server nevie, ci zmena naozaj hla kusovnikom
  // (posun cudzieho objektu ho nezmeni) — hovori „mozno neaktualne", nie
  // „urcite zmenene". Radsej jantar navyse ako export zo starych cisel.
  var STALE_TIP = 'V modeli nastali zmeny od posledného prepočtu — čísla môžu byť neaktuálne. ' +
                  'Platí pre akúkoľvek zmenu v dokumente, aj mimo skriniek.';

  // ZRKADLO `StudioDialog::SECTIONS` — autoritou whitelistu je RUBY, tento
  // zoznam len zabrani, aby z okna vyletela hodnota, ktora sekciu nepomenuva.
  var STUDIO_SECTIONS = ['bom', 'ctrl', 'buy', 'budget', 'offer', 'mat', 'hw', 'rules', 'tpl',
                         'sup', 'bset', 'about'];

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
      // Kovanie zo zaniknutého okna Výroba 1:1, bez redizajnu (ten príde s blokom KOVANIE).
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
      // ŠT-2a: Materiály sú SEKCIA — prvá živá položka skupiny KATALÓGY.
      // ŠT-2b: okno „Materiály projektu" ZANIKLO — sekcia vie všetko vrátane
      // Demos tokov a „Nahradiť UNI…", takže niet kam premosťovať.
      { id: 'mat',    ic: 'layers',   t: 'Materiály' },
      // ŠT-3a-1: Kovanie je SEKCIA (Š16 — pohľady Položky · Sety). Okno
      // „Katalóg kovania" ešte žije kvôli trom modelovým zápisom (predvoľby
      // setov projektu) — otvára ho premostenie Z VNÚTRA sekcie, nie
      // navigácia. Ikona = hammer (kontrakt „Ikony navigácie").
      { id: 'hw',     ic: 'hammer',   t: 'Kovanie' },
      // ŠT-3b-1: Pravidlá sú SEKCIA (Š17). Okno „Pravidlá kovania" zaniklo;
      // skupina „ABS podľa roly" pribudne v ŠT-3b-2.
      { id: 'rules',  ic: 'settings', t: 'Pravidlá' },
      // ŠT-3c-1: Šablóny sú SEKCIA (Š18) — okno „Šablóny" zaniklo.
      { id: 'tpl',    ic: 'star',     t: 'Šablóny' }
    ] },
    { grp: 'NASTAVENIA', items: [
      // ŠT-4a (Š19): posledné tri premostenia sa stali SEKCIAMI — okno
      // „Nastavenia rozpočtu" (posledný satelit) zaniklo a v navigácii už
      // nie je ani jedno premostenie.
      { id: 'sup',    ic: 'truck', t: 'Dodávateľ / Demos' },
      { id: 'bset',   ic: 'euro',  t: 'Nastavenia rozpočtu' },
      { id: 'about',  ic: 'info',  t: 'O plugine' }
    ] }
  ];

  var SEC_META = {
    bom: { t: 'Kusovník', hint: 'skupiny podľa materiálu · pohľady Dielce / Platne / ABS · živý zoznam' },
    ctrl: { t: 'Kontrola', hint: 'semafor filtruje zoznam · klik na nález ho označí v modeli · prepínače hrán a kresby' },
    buy: { t: 'Nákup kovania', hint: 'nákupný zoznam zo setov · nekompletné položky jantárovo · CSV pre objednávku' },
    budget: { t: 'Rozpočet',
              hint: 'jediná sekcia, ktorá mení model — každá zmena = 1 krok Späť · sumy počíta server' },
    offer: { t: 'Cenová ponuka',
             hint: 'zákaznícky pohľad na ten istý rozpočet · rečou zákazníka, bez interných kódov' },
    // ŠT-2a: hint nesie to, co v okne Materialy stal podtitul (`#mdline`) —
    // co sekcia spravuje a co je v nej GLOBALNE (katalog) vs projektove.
    mat: { t: 'Materiály',
           hint: 'katalóg dekorov je spoločný pre všetky zákazky · predvoľby projektu platia pre túto' },
    // ŠT-3a-1 (Š16): presun okna Katalóg kovania 1:1 — redizajn a D-15
    // pridávačky prídu s blokom KOVANIE.
    // ŠT-3b-1 (Š17): zatiaľ LEN skupina „Kovanie podľa rozmerov" — hint to
    // priznáva, aby prázdne miesto po ABS skupine nevyzeralo ako chyba.
    rules: { t: 'Pravidlá',
             hint: 'ABS podľa roly dielca (spoločné, len na čítanie) · kovanie podľa rozmerov — platí pre tento projekt' },
    hw: { t: 'Kovanie',
          hint: 'katalóg položiek a sety sú spoločné pre všetky zákazky · predvoľby setov projektu zatiaľ v okne' },
    // ŠT-3c-1 (Š18): knižnica je spoločná pre všetky zákazky; NOVÚ šablónu
    // ukladáš v Inspectore (má po ruke označenú skrinku), tu ich spravuješ.
    tpl: { t: 'Šablóny',
           hint: 'knižnica je spoločná pre všetky zákazky · novú uložíš v Inspectore z označenej skrinky' },
    // ŠT-4a (Š19). Hinty hovoria to, čo bolo v podtitule zaniknutého okna:
    // čo je GLOBÁLNE (platí pre všetky zákazky) a čo sa mení inde.
    sup: { t: 'Dodávateľ / Demos',
           hint: 'aktívny dodávateľ a stav väzby na Demos · väzba sa nastavuje pri konkrétnom dekore' },
    bset: { t: 'Nastavenia rozpočtu',
            hint: 'sadzby, režimy a prahy · globálne pre všetky zákazky, do zákazky sa nemrazia' },
    about: { t: 'O plugine', hint: 'to isté nájdeš v koliesku Inspectora — jeden obsah, dva vstupy' }
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

  // JEDINY markup tlacidla „Obnoviť" v celom okne. Pouzivaju ho VSETKY sekcie:
  // Kusovnik, Kontrola a Nakup tu, Rozpocet a Ponuka v `js/budget.js` (subor sa
  // nacitava AZ ZA týmto, takze funkciu vidi ako globalnu — rovnako ako `ST`).
  // Preco JEDEN helper: 5 kopii toho isteho tlacidla by znamenalo 5 miest, kde
  // sa jantarovy stav casom rozide — a sekcia bez neho by tvrdila, ze cisla su
  // v poriadku, hoci nie su.
  //   `stale` = jantarovy stav, `tip` = tooltip TEJ sekcie (co presne prepocita),
  //   `attrs` = doplnkove atributy volajuceho (lista Rozpoctu a Ponuky si nesie
  //   `data-bkey`, aby jej po prekresleni nespadol fokus).
  // ZELENA tu vedome NIE JE — vyznamove farby ostavaju semaforu Kontroly.
  function refreshBtnHtml(stale, tip, attrs){
    var s = stale === true;
    return '<button type="button" class="ghostbtn' + (s ? ' nxstale' : '') + '" id="refreshBtn"' +
      (attrs || '') + ' title="' + esc(s ? (tip + ' · ' + STALE_TIP) : tip) + '">' +
      ico('refresh-cw') + ' Obnoviť</button>';
  }

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

  // ABS kompakt „L1:1 · W1:2" s tooltipom plneho znenia — polozka „Kusovnik
  // (zoskupene dielce)" v tabulke UI_VIZIA (SYSTEM/archiv/UI_VIZIA_2026-07.md).
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

  // ŠT-4a: `navBridgeIds` (zrkadlo whitelistu premostení) ZANIKLO spolu
  // s posledným satelitom — v navigácii nie je čo premosťovať. Zoznam
  // premostených položiek zostáva v teste ako REFUTE: keby sa `bridge:`
  // niekedy vrátilo, znamenalo by to nový satelit.

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

  // ---- KOV-H2: PÔVOD nákupného riadku (chip „ručná" + rozklik) -------------
  // Riadok nákupu je SÚČET: ten istý kód môže prísť zo setu jednej skrinky aj
  // z ručne pridanej položky inej. Doteraz to z tabuľky nebolo vidieť vôbec —
  // teraz nesie riadok chip „ručná" (aspoň časť kusov je ručná) a KLIK naň
  // rozbalí zoznam zdrojov. Žiadny nový stĺpec (horizontálny priestor).
  //
  // Stav rozkliku ZÁMERNE neprežíva push: čerstvý payload môže riadky
  // preusporiadať a otvorený index by ukázal pôvod CUDZIEHO riadku.
  var buyOpen = {};

  // Aspoň časť kusov riadku pochádza z ručne pridanej položky. Voľná položka
  // je ručná VŽDY (vlastný riadok bez kódu). Čistá funkcia (Node testy).
  function hwRowManual(r){
    if (!r) return false;
    if (r.free === true) return true;
    var n = Number(r.adhoc_quantity);
    return isFinite(n) && n > 0;
  }
  // Jeden zdroj do vety: „CAB-2 · F1 · dvierka ľavé · ručná ×2".
  // `owner_label` skladá SERVER (`PartKeys.human_label`) — JS z part_key nič
  // neodvodzuje; prázdny popis = kovanie patrí celej skrinke.
  function hwSourceText(s){
    var d = s || {};
    var parts = [];
    if (d.cabinet_id) parts.push(String(d.cabinet_id));
    if (d.owner_label) parts.push(String(d.owner_label));
    if (String(d.origin || '') === 'adhoc') parts.push('ručná');
    else if (d.set_id) parts.push('set ' + d.set_id);
    else if (d.generic_type) parts.push(String(d.generic_type));
    var q = Number(d.quantity);
    var txt = parts.length ? parts.join(' · ') : '—';
    return txt + ((isFinite(q) && q > 0) ? ' ×' + q : '');
  }
  function hwSourcesHtml(r){
    var list = (r && r.sources) || [];
    if (!list.length){
      return '<tr class="hwsrc"><td colspan="6">Pôvod sa nedá zistiť — riadok neniesol zdroje.</td></tr>';
    }
    return '<tr class="hwsrc"><td colspan="6"><b>Pôvod:</b> '
         + list.map(function(s){ return esc(hwSourceText(s)); }).join(' &nbsp;·&nbsp; ')
         + '</td></tr>';
  }

  // Telo sekcie: NÁKUPNÝ ZOZNAM zo setov (hore) + generika podľa pravidiel
  // (dole, klik-select cez .hwgen ostáva). Vracia HTML — sekcie Štúdia si
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
        rows.forEach(function(r, i){
          var c = r.missing ? 'MIMO KATALÓGU' : (r.category || '—');
          if (c !== cat){ cat = c; h += '<tr class="hwcat"><td colspan="6">' + esc(c) + '</td></tr>'; }
          // KOV-H2: chip „ručná" + rozklik pôvodu. Voľná položka kód NEMÁ —
          // v stĺpci Kód je pomlčka, nie prázdno (prázdna bunka vyzerá ako chyba).
          var man = hwRowManual(r);
          var open = buyOpen[i] === true;
          var cls = 'hwbuyrow' + (r.missing ? ' hwmiss' : '') + (open ? ' on' : '');
          h += '<tr class="' + cls + '" data-buy="' + i + '"'
             + ' title="Klik ukáže pôvod — z ktorých skriniek, setov a ručných položiek riadok vznikol">'
             + '<td>' + esc(r.code || '—') + '</td>'
             + '<td>' + esc(r.missing ? 'nie je v katalógu kovania' : (r.name_sk || ''))
             + (man ? ' <span class="hwchip">ručná</span>' : '') + '</td>'
             + '<td><b>' + num(r.quantity) + '</b>' + hwManualMark(r.manual_note) + '</td>'
             + '<td>' + esc(r.unit || '—') + '</td>'
             + '<td>' + price(r.price_eur_vat) + '</td><td>' + price(r.subtotal_eur_vat) + '</td></tr>';
          if (open) h += hwSourcesHtml(r);
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
          // Review #256 P2: niektoré dôvody si rozmer nesú UŽ VO VETE (R-06
          // `length_unsupported` ho tam má, aby ho videl aj panel, ktorý
          // params_label nepripája) — vtedy sa NEpridáva druhýkrát.
          if (u.params_label && reason.indexOf(u.params_label) === -1) reason += ' · ' + u.params_label;
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
      // Trieda je `hwgen`, NIE `hwrow`: `.hwrow` je v zdielanom panel.css flex
      // riadok kovania Inspectora/Katalogu — na `<tr>` by `display: flex`
      // rozhodil stlpce pod hlavickou (guard tests/pure/test_tr_flex_kolizia.rb).
      h += '<tr class="hwgen" data-i="' + i + '"><td>' + esc(g.label || g.generic_type) + '</td><td>' + params + '</td>' +
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

  function edgeCheckBarHtml(st, menuOpen, grain, direction){
    if (!st || !st.available){
      return '<span class="ecoff">Zvýraznenie hrán, smer kresby a smer otvárania vyžadujú SketchUp 2023 alebo novší.</span>';
    }
    var on = st.active === true;
    return '<span class="echk"><button type="button" id="ecBtn" class="ecbtn' + (on ? ' on' : '') + '"' +
      ' data-ec="toggle" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Farebné zvýraznenie stavu olepu priamo v modeli. Model sa nemení — kreslí sa nad ním.">' +
      ico(on ? 'eye-off' : 'eye') + 'Zvýrazniť hrany</button>' +
      '<button type="button" id="ecMore" class="cornerzone" data-ec="menu"' +
      ' aria-expanded="' + (menuOpen ? 'true' : 'false') + '" aria-haspopup="true"' +
      ' aria-label="Nastavenie zvýraznenia hrán" title="Nastavenie — ktoré stavy hrán sa zvýraznia"></button>' +
      edgeCheckMenuHtml(st, menuOpen) + '</span>' + grainBtnHtml(grain) + directionBtnHtml(direction) +
      '<span class="ecinfo">' + edgeCheckText(st) + grainInfoHtml(grain) + directionInfoHtml(direction) + '</span>';
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

  // KOV-A2b: prepínač smeru otvárania. Rovnaký tvar ako „Smer kresby"
  // (obyčajné tlačidlo — nie je čo nastavovať), vlastné texty a vlastný stav.
  function directionBtnHtml(d){
    if (!d || !d.available) return '';
    var on = d.active === true;
    return '<button type="button" id="dcBtn" class="dcbtn' + (on ? ' on' : '') + '"' +
      ' data-dc="toggle" aria-pressed="' + (on ? 'true' : 'false') + '"' +
      ' title="Nakreslí na čelá symboly otvárania — šípka na voľnú hranu, ∧ výklop, ∨ sklop, X blenda.' +
      ' Model sa nemení, kreslí sa nad ním.">' + ico('direction') + 'Smer otvárania</button>';
  }

  // Doveta k textu lišty. Vypnutý prepínač mlčí (rovnaký dôvod ako pri kresbe).
  function directionInfoHtml(d){
    var t = directionCheckText(d);
    return t ? ' · <span class="dcinfo">' + t + '</span>' : '';
  }

  function directionCheckText(d){
    if (!d || !d.available || !d.active) return '';
    var w = ecNum(d.wings);
    var t = w + ' ' + directionWingPluralSk(w);
    if (ecNum(d.unknown)) t += ' · ' + ecNum(d.unknown) + ' neurčených';
    if (ecNum(d.legacy)) t += ' · ' + ecNum(d.legacy) + ' bez smeru (legacy)';
    return t;
  }

  // 1 krídlo / 2–4 krídla / 5+ krídel (slovenske sklonovanie poctu)
  function directionWingPluralSk(n){
    var v = Math.abs(n);
    if (v === 1) return 'krídlo';
    if (v >= 2 && v <= 4) return 'krídla';
    return 'krídel';
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
  // Priradenie do `window` je pod guardom: `js/budget.js` si TENTO subor v Node
  // testoch requiruje kvoli zdielanemu `refreshBtnHtml` (v prehliadaci ho vidi
  // ako globalnu funkciu) a bez guardu by mu holy `window` spadol. V prehliadaci
  // sa NIC nemeni — `window.NX` vznika presne ako doteraz, PRED nacitanim
  // budget.js, ktory ho obaluje.
  var NXAPI = {
    setStudio: function(data){
      ST = data || null;
      // KOV-H2: rozklikaný pôvod patrí riadkom, ktoré používateľ videl —
      // čerstvý payload ich môže preusporiadať, takže otvorený index by ukázal
      // pôvod CUDZIEHO riadku.
      buyOpen = {};
      // PLNY payload = cerstve cisla zo servera, takze „neaktuálne" padá —
      // a to PRED renderom, inak by lišta este raz nakreslila jantar.
      // Zhadzuje ho VYHRADNE tento push: echa nizsie (lista VEPO, prepinace,
      // vysledok zapisu rozpoctu) cisla NENESU.
      staleFlag = false;
      // P0-HF: ozbrojené potvrdenie „exportuj aj tak" platí pre ČÍSLA, ktoré
      // používateľ videl — čerstvý payload ho preto ruší. Inak by potvrdenie
      // z minulého stavu ticho pustilo export nad inými sumami.
      if (typeof budDisarm === 'function') budDisarm();
      // Š10: stav prepínačov chodí v KAŽDOM pushi (a medzitým aj samostatným
      // echom nižšie) — klient si ho nikdy neodvodzuje.
      EDGE = (ST && ST.edge_check) ? ST.edge_check : null;
      GRAIN = (ST && ST.grain_check) ? ST.grain_check : null;
      DIRECTION = (ST && ST.direction_check) ? ST.direction_check : null;
      var mdl = el('stModel');
      if (mdl) mdl.textContent = ST ? ('zákazka: ' + ST.model_title + ' · v' + ST.version) : '…';
      // Deep-link sekcie sa posiela PRAVE RAZ; kotva s nou.
      if (ST && ST.open_section && STUDIO_SECTIONS.indexOf(ST.open_section) >= 0){
        // Review #8: deep-link je PRESKOK do inej sekcie — otvorené rohové menu
        // patrilo tej, z ktorej sme odišli. Bez vynulovania by sa `vepoMenuOpen`
        // vrátilo pri najbližšom návrate do Kusovníka „samo otvorené".
        closeSectionMenus();
        // ŠT-2b: deep-link je DRUHA cesta preč zo sekcie (prvá je `onNav`) —
        // modály Materiálov žijú mimo tela sekcie, takže by inak ostali visieť
        // nad novou sekciou a Demos beh by dobehol do nikam.
        if (studioSec === 'mat' && ST.open_section !== 'mat' &&
            typeof matOnLeaveSection === 'function'){
          matOnLeaveSection();
        }
        // ŠT-3a-1: to isté pre sekciu Kovanie (modal potvrdenia mazania žije
        // mimo tela sekcie a na serveri môže bežať overenie ceny / náhľad).
        if (studioSec === 'hw' && ST.open_section !== 'hw' &&
            typeof hwOnLeaveSection === 'function'){
          hwOnLeaveSection();
        }
        // D-52b: DEEP-LINK je jeden z DVOCH vstupov do sekcie „O plugine"
        // (druhý je navigácia v `studioGoSection`) — a oba musia spustiť
        // PRESNE JEDEN explicitný check verzie. Zo `settings_payload` check
        // nechodí: plný push chodí pri každej zmene modelu a kontrola siaha na
        // sieťový share (F5).
        var wasAbout = (studioSec === 'about');
        studioSec = ST.open_section;
        if (studioSec === 'about' && !wasAbout && typeof ssOnAboutEnter === 'function'){
          ssOnAboutEnter();
        }
        // Kotva predvyplna hladanie KUSOVNIKA (N13 posiela ID skrinky). Pri inej
        // sekcii by potichu prestavila filter, ktory pouzivatel ani nevidí —
        // preto sa aplikuje LEN so sekciou, do ktorej patri (review #7).
        var a = (studioSec === 'bom') ? anchorFilter(ST) : null;
        if (a) bomQ = a;
        // ŠT-2d: sekcia Materiály spotrebuje kotvu INAK — nie ako text
        // hľadania, ale ako OTVORENIE DETAILU dekoru (deep-link z karty dielca
        // „klik na materiál"). Rovnako JEDNORAZOVO: server ju v ďalšom pushi
        // už neposiela, takže návrat do dlaždíc prežije refresh.
        // Review #3: neúspešné otvorenie NIE JE tichý no-op. Dekor sa mohol
        // medzitým zmazať alebo premenovať a používateľ, ktorý klikol na
        // materiál dielca, by inak skončil v zozname dlaždíc bez slova —
        // vyzeralo by to ako pokazený preklik.
        var ma = (studioSec === 'mat') ? anchorFilter(ST) : null;
        if (ma && typeof matOpenAnchor === 'function' && !matOpenAnchor(ma)){
          NXAPI.setStatus('Tento dekor už v katalógu nie je — otvorené v zozname materiálov.', true);
        }
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
      // SMOKE 1A: checkbox uz nie je v liste, ale v rohovom nastaveni VEPO.
      // V DOM je VZDY (okno sa len skryva triedou), takze echo prepise jeho
      // stav aj vtedy, ked ho ma pouzivatel prave otvoreny — a otvorene okno
      // sa nikdy nerozide s tym, co plati pre export.
      var chk = el('mergeChk');
      if (chk) chk.checked = v.merge_18_36 !== false;
    },
    // Š10: malé echo pushe stavu prepínačov (prepnutie odkiaľkoľvek — rail,
    // toto okno aj rail Inspectora — aj prepočet po prestavbe). Prekreslí sa LEN
    // lišta sekcie, zoznam nálezov sa nedotkne.
    setEdgeCheck: function(state){
      EDGE = state || null;
      if (studioSec === 'ctrl') renderTools();
    },
    setGrainCheck: function(state){
      GRAIN = state || null;
      if (studioSec === 'ctrl') renderTools();
    },
    setDirectionCheck: function(state){
      DIRECTION = state || null;
      if (studioSec === 'ctrl') renderTools();
    },
    // Server hlási, že sa v modeli OD POSLEDNÉHO PREPOČTU niečo zmenilo.
    // NIČ sa neprepočítava a na server sa nič neposiela — prekreslí sa LEN
    // lišta práve otvorenej sekcie (tabuľka aj zoznam nálezov ostávajú, sú to
    // stále tie čísla, ktoré sem prišli naposledy).
    markStale: function(){
      if (staleFlag) return;
      staleFlag = true;
      renderTools();
    },
    // To isté nastavenie sa dá otvoriť z troch miest — keď ho používateľ
    // otvorí inde, toto sa zavrie (nikdy dve kópie naraz).
    closeEdgeMenu: function(){
      if (!ecMenuOpen) return;
      ecMenuOpen = false;
      if (studioSec === 'ctrl') renderTools();
    }
  };
  if (typeof window !== 'undefined') window.NX = NXAPI;

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
        var on = (it.id === studioSec && !it.disabled);
        // ŠT-4a: vetva premostenia zanikla — tooltip je buď dôvod neaktivity,
        // alebo vlastný hint položky, alebo jej názov.
        var tip = it.disabled ? (it.t + ' — ' + it.disabled)
                : (it.hint ? (it.t + ' — ' + it.hint) : it.t);
        h += '<button type="button" class="navitem' + (on ? ' on' : '') + '"' +
             (it.disabled ? ' aria-disabled="true"' : '') +
             ' data-nav="' + esc(it.id) + '" title="' + esc(tip) + '">' +
             ico(it.ic) + '<span>' + esc(it.t) + '</span>' +
             // Š11: živé počty pri Kontrole — z counts KAŽDÉHO pushu.
             (it.badge ? navBadgeHtml(ST ? ST.counts : null) : '') + '</button>';
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
    // ŠT-2a: listu sekcie Materialy kresli `js/proj_materials.js` (nacitava sa
    // AZ ZA tymto suborom, preto cez `typeof`). Jantarovy priznak mu podavame
    // — `staleFlag` ma jedinu autoritu, tu.
    if (studioSec === 'mat'){
      if (typeof matRenderTools === 'function') matRenderTools(staleFlag);
      else box.innerHTML = '';
      return;
    }
    // ŠT-3a-1: to isté pre sekciu Kovanie — lištu kreslí `js/hw_catalog.js`
    // (načítava sa AŽ ZA týmto súborom, preto cez `typeof`).
    if (studioSec === 'hw'){
      if (typeof hwRenderTools === 'function') hwRenderTools(staleFlag);
      else box.innerHTML = '';
      return;
    }
    // ŠT-3b-1: to isté pre sekciu Pravidlá — lištu kreslí `js/rules.js`.
    if (studioSec === 'rules'){
      if (typeof rulesRenderTools === 'function') rulesRenderTools(staleFlag);
      else box.innerHTML = '';
      return;
    }
    // ŠT-3c-1: a pre sekciu Šablóny `js/templates.js`.
    if (studioSec === 'tpl'){
      if (typeof tplRenderTools === 'function') tplRenderTools(staleFlag);
      else box.innerHTML = '';
      return;
    }
    // ŠT-4a: tri sekcie NASTAVENÍ kreslí `js/studio_settings.js`. Lištu má len
    // `bset` (má čo ukladať) — `sup` a `about` sú čítanie, takže prázdna lišta
    // je poctivejšia než tlačidlá, ktoré nič nerobia (D-78).
    if (studioSec === 'sup' || studioSec === 'bset' || studioSec === 'about'){
      if (typeof ssRenderTools === 'function') ssRenderTools();
      else box.innerHTML = '';
      return;
    }
    // Š10: lišta sekcie Kontrola nesie OBA prepínače (a nič iné — exporty
    // kontrola nemá). Jeden riadok, žiadny nový blok: vertikálny priestor
    // je vzácny a nastavenie hrán je overlay pod tlačidlom.
    if (studioSec === 'ctrl'){
      box.innerHTML = edgeCheckBarHtml(EDGE, ecMenuOpen, GRAIN, DIRECTION) +
        '<span class="spacer"></span>' +
        '<span class="sechint">Zoradené podľa závažnosti — poradie určuje server.</span>' +
        // Review #7: Kontrola bola JEDINA sekcia BEZ „Obnoviť" — a pritom je to
        // sekcia, kvoli ktorej sa clovek do okna vracia po oprave v Inspectore.
        // Prestavba skrinky sem sama nedorazi, takze zoznam nalezov mohol
        // ukazovat uz opravenu chybu (rovnaky dovod ako v Kusovniku a Nakupe).
        // Zdielany `#refreshBtn` — jeden handler, jedna serverova cesta,
        // a od tejto davky aj JEDEN markup (`refreshBtnHtml`).
        refreshBtnHtml(staleFlag, 'Prepočítať kontrolu z aktuálneho modelu');
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
        refreshBtnHtml(staleFlag, 'Prepočítať nákupný zoznam z aktuálneho modelu') +
        '<span class="spacer"></span>' +
        '<span class="sechint">Klik na riadok generiky označí vlastníka v modeli.</span>';
      return;
    }
    box.innerHTML = bomToolsHtml(ST.vepo || {},
                                 { view: bomView, q: bomQ,
                                   cols: colMenuOpen, vepo: vepoMenuOpen, stale: staleFlag });
  }

  // LISTA sekcie KUSOVNIK — cista funkcia (testuje ju tests/js/test_st1a_studio.js).
  //
  // SMOKE 22.8. (1B/1C/1D), poradie schvalene Michalom: vlavo „co pozeram"
  // (pohlady · Projekt · hladanie), vpravo „co s tym robim" (VEPO · Stlpce ·
  // Obnoviť). Konkretne zmeny oproti ŠT-1a:
  //   * XLSX a CSV placeholdery su PREC. D-78 („neexistujuci export je
  //     viditelny a priznany") plati na sluby, ktore prichadzaju hned —
  //     tieto dva viseli neaktivne cez cely blok ŠT-1 a v smoke teste
  //     pusobili ako rozbite tlacidla. Vratia sa s REALNYM exportom.
  //   * checkbox „18+36 spolu" sa z listy odstahoval do ROHOVEHO NASTAVENIA
  //     tlacidla VEPO (patri k exportu, nie k pohladu na kusovnik).
  //   * „Projekt" dostal stitok a ram — je to VSTUP, ktory pomenuva zakazku
  //     pre vsetky exporty, takze nesmie vyzerat ako popisok medzi tlacidlami.
  //
  // Stav lišty chodí ARGUMENTOM (`st` = pohľad · hľadanie · otvorené menu),
  // nie z modulových premenných: rovnaký vzor ako zdieľaný `edge_menu.js`
  // (`menuHtml(st, open, opts)`) — funkcia je tým testovateľná bez DOM.
  function bomToolsHtml(vepo, st){
    var v = vepo || {};
    var s = st || {};
    var vw = function(id, t, tip){
      return '<button type="button" class="bomvw' + (s.view === id ? ' on' : '') +
             '" data-view="' + id + '" title="' + esc(tip) + '">' + esc(t) + '</button>';
    };
    var h = '<div class="bomviews">' +
      vw('parts', 'Dielce', 'Výrobné dielce po materiáloch') +
      vw('sheets', 'Platne', 'Súpis platní — odvodený z kusovníka') +
      vw('abs', 'ABS', 'Súpis ABS pások — odvodený z kusovníka') + '</div>' +
      '<label class="prjbox" title="Názov zákazky — pomenuje priečinok a súbory VEPO exportu,' +
      ' titulok rozpočtu aj cenovej ponuky. Platí pre všetky exporty.">' +
      '<span class="prjlbl">Projekt</span><input id="prjInput" type="text" value="' + esc(v.project || '') +
      '" placeholder="' + esc(v.default_project || 'projekt') + '"></label>' +
      '<div class="searchbox">' + ico('search') +
      '<input id="bomSearch" placeholder="Hľadať dielec / skrinku…" value="' + esc(s.q || '') + '"></div>' +
      '<span class="spacer"></span>' +
      vepoBtnHtml(v, s.vepo === true);
    if (s.view === 'parts'){
      // Review #1: menu stlpcov visi na SVOJOM tlacidle, nie na lište. Kym bolo
      // kotvene na `.sectools` (`right: 12px`), po presune tlacidla doprava sa
      // od neho vizualne odtrhlo — vzor je ten isty obal ako pri VEPO rohu.
      h += '<span class="colfly"><button type="button" class="ghostbtn" id="colBtn"' +
           ' title="Voliteľné stĺpce — voľba sa pamätá na tomto počítači" aria-expanded="' +
           (s.cols ? 'true' : 'false') + '">' + ico('columns-3') + ' Stĺpce ' +
           ico('chevron-down') + '</button>' + colMenuHtml(s.cols === true) + '</span>';
    }
    // Kusovnik je zivy (server pushuje pri prepnuti modelu a po zmene
    // katalogu), ale prestavba skrinky z Inspectora sem sama nedorazi — okno
    // musi mat rucnu cestu k cerstvym cislam, inak by sa VEPO exportovalo
    // zo starych.
    // Jantarovy stav chodi ARGUMENTOM (`s.stale`) z toho isteho dovodu ako
    // pohlad a hladanie — funkcia ostava testovatelna bez DOM.
    h += refreshBtnHtml(s.stale === true, 'Prepočítať kusovník z aktuálneho modelu');
    return h;
  }

  // SMOKE 1A: VEPO export s ROHOVYM NASTAVENIM — vzor „flyout roh"
  // (docs/UI_DIZAJN.md §5.11): klik na TELO exportuje ako doteraz, klik na
  // pravy dolny ROH otvori male nastavenie. Roh je SAMOSTATNE tlacidlo v
  // spolocnom obale (tlacidlo v tlacidle je neplatne HTML), znamienko je
  // pseudo-prvok. Klikaciu zonu `.cornerzone` a jej rozmery zdiela s railom
  // Inspectora aj s listou Kontroly; OBSAH okna je vlastny (jeden checkbox),
  // preto NIE zdielany edge_menu.js — ten kresli 3-stavovu kontrolu hran.
  function vepoBtnHtml(v, open){
    return '<span class="vepofly">' +
      '<button type="button" class="primary" id="vepoBtn"' +
      ' title="Exportuje prírezy (po odpočte ABS) do VEPO CSV — vyberieš priečinok">' +
      ico('download') + ' VEPO export</button>' +
      '<button type="button" id="vepoMore" class="cornerzone" data-vepo="menu"' +
      ' aria-expanded="' + (open ? 'true' : 'false') + '" aria-haspopup="true"' +
      ' aria-label="Nastavenie VEPO exportu"' +
      ' title="Nastavenie exportu — čo sa spojí do jedného súboru"></button>' +
      vepoMenuHtml(v, open) + '</span>';
  }

  // Male okno nastavenia (overlay pod spustacom, nikdy novy riadok layoutu).
  // Uzol je v DOM VZDY (skryva ho trieda, nie podmienka v markupe) — echo
  // `NX.setVepoBar` tak nasadzuje `checked` bez ohladu na to, ci je okno
  // otvorene. audit #16 ŠT-1a plati dalej: hodnota je Z PAYLOADU pri KAZDOM
  // pushi, klient si ju NIKDY neodvodzuje.
  function vepoMenuHtml(v, open){
    var s = v || {};
    return '<div class="vepomenu' + (open ? ' open' : '') + '" id="vepoMenu" role="group"' +
      ' aria-label="Nastavenie VEPO exportu">' +
      // Review #4: hlavicka `.mgrp` — TEN ISTY vzor ako menu stlpcov aj
      // zdielane nastavenie hran (a zhoda s mockupom). Bez nej sa okno otvara
      // rovno checkboxom a nepovie, co vlastne nastavuje.
      '<div class="mgrp">Nastavenie VEPO exportu</div>' +
      '<label class="vopt"><input type="checkbox" id="mergeChk"' +
      (s.merge_18_36 === false ? '' : ' checked') + '><span>18 + 36 spolu</span></label>' +
      '<div class="vnote">Materiály 18 a 36 mm idú do jedného súboru (bežná objednávka).</div>' +
      '</div>';
  }

  function colMenuHtml(open){
    if (!open) return '';
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
    // ŠT-2a (audit #2): telo sekcie Materialy si kresli `js/proj_materials.js`
    // SAM a ZAMERNE ho tento render NEPREPISUJE — v sekcii moze byt rozpisany
    // formular „Nový dekor" alebo rozpisana bunka ceny a `NX.setStudio` (napr.
    // po prepocte kusovnika) ich nesmie zmazat.
    if (studioSec === 'mat'){
      if (typeof matRenderBody === 'function') matRenderBody();
      else box.innerHTML = '<div class="muted">Materiály sa nenačítali (js/proj_materials.js).</div>';
      return;
    }
    // ŠT-3a-1: telo sekcie Kovanie si kreslí `js/hw_catalog.js` z TOHO ISTÉHO
    // dôvodu ako Materiály (audit #2): v sekcii môže byť rozpísaný formulár
    // novej položky, rozpísaný editor setu alebo rozpísaná bunka ceny a
    // `NX.setStudio` (napr. po prepočte kusovníka) ich nesmie zmazať.
    if (studioSec === 'hw'){
      if (typeof hwRenderBody === 'function') hwRenderBody();
      else box.innerHTML = '<div class="muted">Kovanie sa nenačítalo (js/hw_catalog.js).</div>';
      return;
    }
    // ŠT-3b-1: telo sekcie Pravidlá si kreslí `js/rules.js` SAM — v sekcii
    // môže byť ROZPÍSANÝ formulár pravidiel a `NX.setStudio` ho nesmie zmazať.
    if (studioSec === 'rules'){
      if (typeof rulesRenderBody === 'function') rulesRenderBody();
      else box.innerHTML = '<div class="muted">Pravidlá sa nenačítali (js/rules.js).</div>';
      return;
    }
    // ŠT-3c-1: telo sekcie Šablóny kreslí `js/templates.js` — dôvod je iný než
    // pri formulároch vyššie: sekcia si po vykreslení PÝTA PNG náhľady a
    // odpovede nasadzuje do UŽ EXISTUJÚCICH dlaždíc (výmena uzla by odpojila
    // cieľ kliku aj práve doručený obrázok).
    if (studioSec === 'tpl'){
      if (typeof tplRenderBody === 'function') tplRenderBody();
      else box.innerHTML = '<div class="muted">Šablóny sa nenačítali (js/templates.js).</div>';
      return;
    }
    // ŠT-4a: telo sekcií NASTAVENÍ si kreslí `js/studio_settings.js` SÁM — v `bset`
    // môže byť ROZPÍSANÝ formulár sadzieb a `NX.setStudio` ho nesmie zmazať
    // (plný push chodí pri každej zmene modelu, nielen pri otvorení sekcie).
    if (studioSec === 'sup' || studioSec === 'bset' || studioSec === 'about'){
      if (typeof ssRenderBody === 'function') ssRenderBody();
      else box.innerHTML = '<div class="muted">Nastavenia sa nenačítali (js/studio_settings.js).</div>';
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
  var REFRESH_STATUS = { ctrl: 'Prepočítavam kontrolu…',
                         buy: 'Prepočítavam nákupný zoznam…', budget: 'Prepočítavam rozpočet…',
                         offer: 'Prepočítavam cenovú ponuku…',
                         // ŠT-2a: v Materiáloch sa z modelu prepočítava JEDINÉ —
                         // koľko dielcov ktorý dekor používa (katalóg je globálny
                         // a chodí echom). Hláška to musí povedať presne, inak
                         // vyzerá, že sa prepočítava katalóg.
                         mat: 'Prepočítavam použitie dekorov v projekte…',
                         // ŠT-3b-1: v Pravidlách sa z modelu číta len počet skriniek,
                         // ktoré uloženie prestavá (a či projekt už má vlastné pravidlá).
                         rules: 'Načítavam pravidlá z aktuálneho modelu…',
                         // ŠT-3a-1: v Kovaní sa z modelu neprepočítava nič —
                         // „Obnoviť" si pýta čerstvý KATALÓG a sety z disku
                         // (mohlo ich zmeniť žijúce okno Katalóg kovania).
                         hw: 'Načítavam čerstvý katalóg kovania a sety…' };

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

  // KOV-A2b: ten istý relay (gen + model_guid overuje SERVER) pre smer otvárania.
  function directionCheckToggle(){
    if (!ST || !window.sketchup || !sketchup.direction_check_toggle) return;
    sketchup.direction_check_toggle(JSON.stringify(edgeCheckPayload(ST)));
  }

  // Otvorenie/zatvorenie nastavenia je CISTO klientska vec (nikam sa neukladá).
  // Otvorenie tu zavrie tú istú kópiu v raile Inspectora —
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

  // SMOKE 1A: rohove nastavenie VEPO. Otvorenost je cisto klientska —
  // na rozdiel od kontroly hran to NIE JE zdielane nastavenie, takze sa
  // nikomu inemu neohlasuje (druha kopia tohto okna nikde neexistuje).
  function vepoMenuToggle(){
    vepoMenuOpen = !vepoMenuOpen;
    renderTools();
  }

  function vepoMenuClose(){
    if (!vepoMenuOpen) return;
    vepoMenuOpen = false;
    renderTools();
  }

  // Review #8: otvorené overlaye lišty patria SEKCII, v ktorej vznikli. Pri
  // odchode z nej sa zhasínajú NAraz a BEZ prekreslenia — volajúci kreslí celé
  // okno hneď za tým (`render()`), takže druhý render by bol zbytočný.
  // Menu stĺpcov si zatváranie pri prepnutí pohľadu rieši samo (`data-view`),
  // ale prepnutie SEKCIE je ten istý prípad — preto je tu tiež.
  function closeSectionMenus(){
    vepoMenuOpen = false;
    ecMenuOpen = false;
    colMenuOpen = false;
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
    // ŠT-4a: vetva premostenia zanikla — každá položka je odteraz SEKCIA
    // (alebo jediný `disabled` Nárezový plán vyššie).
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
    closeSectionMenus();   // review #8 — overlay patrí sekcii, z ktorej odchádzame
    // ŠT-2b: sekcia Materiály má modály MIMO tela sekcie (`#matModalRoot`) a
    // dlhé behy Demosu na serveri. Odchod z nej preto musí modály zavrieť
    // a beh zrušiť — inak by modal ostal visieť nad Kusovníkom a sťahovanie
    // by dobehlo do sekcie, ktorú už nikto nepozerá. Autoritou zrušenia je
    // server (`mat_leave`), toto je jeho jediný ohlasovač.
    if (studioSec === 'mat' && id !== 'mat' && typeof matOnLeaveSection === 'function'){
      matOnLeaveSection();
    }
    // ŠT-3a-1: sekcia Kovanie má z rovnakých dôvodov vlastný odchodový hook.
    if (studioSec === 'hw' && id !== 'hw' && typeof hwOnLeaveSection === 'function'){
      hwOnLeaveSection();
    }
    // D-52b: NAVIGÁCIA je druhý vstup do sekcie „O plugine" — vstupný hook je
    // protipólom odchodových hookov vyššie a spúšťa PRESNE JEDEN check verzie
    // (znova otvorená tá istá sekcia check neopakuje).
    var wasAbout = (studioSec === 'about');
    studioSec = id;
    if (id === 'about' && !wasAbout && typeof ssOnAboutEnter === 'function') ssOnAboutEnter();
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
      // SMOKE 1A: to iste pre rohove nastavenie VEPO — a z TOHO ISTEHO dovodu
      // v tomto jedinom listeneri (stopPropagation medzi dvoma listenermi na
      // tom istom uzle nefunguje). Klik na roh sa nizsie este spracuje, klik
      // vnutri okna (checkbox) ho nezavrie.
      if (vepoMenuOpen && !t.closest('.vepofly')) vepoMenuClose();
      // Prepínače lišty Kontroly.
      var ec = t.closest('[data-ec]');
      if (ec){
        if (ec.getAttribute('data-ec') === 'menu') edgeMenuToggle();
        else edgeCheckToggle();
        return;
      }
      if (t.closest('[data-gc]')){ grainCheckToggle(); return; }
      if (t.closest('[data-dc]')){ directionCheckToggle(); return; }
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
      // SMOKE 1A: roh je SAMOSTATNE tlacidlo NAD telom exportu — klik nan sa
      // teda k hlavnej akcii vobec nedostane (`#vepoBtn` ho neobsahuje).
      if (t.closest('[data-vepo]')){ vepoMenuToggle(); return; }
      if (t.closest('#vepoBtn')){ vepoExport(); return; }
      if (t.closest('#hwCsvBtn')){ hwCsvExport(); return; }
      if (t.closest('#refreshBtn')){ requestRefresh(); return; }
      // KOV-H2: klik na riadok nákupu rozbalí/zbalí jeho PÔVOD (zoznam zdrojov).
      // Žiadny zápis, žiadny server — je to čisté zobrazenie toho, čo už payload
      // nesie. Ide PRED riadkom generiky: obe sú `<tr>` v tej istej sekcii.
      var buyr = t.closest('tr.hwbuyrow');
      if (buyr){
        var bi = parseInt(buyr.getAttribute('data-buy'), 10);
        if (!isNaN(bi)){ buyOpen[bi] = !buyOpen[bi]; renderBody(); }
        return;
      }
      // ŠT-1c PR A: riadok generiky kovania — klik označí vlastníka v modeli.
      var hwr = t.closest('tr.hwgen');
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
      // SMOKE 1A: rohove nastavenia su od tejto davky DVE (kontrola hran
      // v sekcii Kontrola, VEPO v Kusovníku). Su to sekcie, ktore nemozu byt
      // otvorene naraz, ale poradie je aj tak explicitne: MODAL > menu.
      if (ev.key !== 'Escape' || nxModalOpen()) return;
      if (ecMenuOpen){
        edgeMenuClose();
        var more = el('ecMore');
        if (more){ try { more.focus(); } catch (e) {} }
        return;
      }
      if (vepoMenuOpen){
        vepoMenuClose();
        var vmore = el('vepoMore');
        if (vmore){ try { vmore.focus(); } catch (e) {} }
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
      anchorFilter: anchorFilter, navItem: navItem,
      nxModalOpen: nxModalOpen,
      // SMOKE 1A–1D: lista sekcie Kusovnik + rohove nastavenie VEPO.
      // Testy nastavuju stav cez `setBomState` (bomView/bomQ/menu) — inak by
      // museli sahat do modulovych premennych, ktore Node nevidi.
      bomToolsHtml: bomToolsHtml, vepoBtnHtml: vepoBtnHtml, vepoMenuHtml: vepoMenuHtml,
      // Jantarovy indikator neaktualnosti: JEDEN markup pre vsetkych 5 mist
      // (Kusovnik · Kontrola · Nakup tu, Rozpocet · Ponuka v budget.js —
      // ten si ho v Node testoch berie requirom TOHTO suboru).
      refreshBtnHtml: refreshBtnHtml, STALE_TIP: STALE_TIP,
      // ŠT-3c-1: aktivna sekcia — sekcne subory podla nej rozhoduju, ci smu
      // pisat do ZDIELANEHO `#secbody` (viz `TPL.init`).
      studioActiveSection: studioActiveSection,
      setStudioSection: studioSetSectionForTest,
      // ŠT-1b sekcia Kontrola (Š8–Š11)
      semaforHtml: semaforHtml, ctrlRows: ctrlRows, ctrlRowHtml: ctrlRowHtml,
      ctrlActionsHtml: ctrlActionsHtml, navBadgeHtml: navBadgeHtml,
      // ŠT-1c PR A sekcia Nákup kovania (Š7) + D-93 znamienko ručného zásahu
      // (sada tests/js/test_d93_nl_override.js sa sem presunula z production.js)
      buySection: buySection, price: price, hwManualMark: hwManualMark,
      // KOV-H2: chip „ručná" + rozklik pôvodu (tests/js/test_kovh2_adhoc_ui.js)
      hwRowManual: hwRowManual, hwSourceText: hwSourceText, hwSourcesHtml: hwSourcesHtml,
      setBuyOpen: function(m){ buyOpen = m || {}; },
      // Š10 prepinace (sady D-104 / D-105 / K2 / ABS rail 3-stav)
      edgeCheckBarHtml: edgeCheckBarHtml, edgeCheckText: edgeCheckText,
      edgePluralSk: edgePluralSk, edgeCheckPayload: edgeCheckPayload,
      edgeCheckMenuHtml: edgeCheckMenuHtml, edgeCheckOptionPayload: edgeCheckOptionPayload,
      edgeCheckSelectionHint: edgeCheckSelectionHint,
      grainBtnHtml: grainBtnHtml, grainCheckText: grainCheckText,
      grainPartPluralSk: grainPartPluralSk,
      // KOV-A2b: tretie tlacidlo listy sekcie Kontrola.
      directionBtnHtml: directionBtnHtml, directionCheckText: directionCheckText,
      directionWingPluralSk: directionWingPluralSk
    };
  }
