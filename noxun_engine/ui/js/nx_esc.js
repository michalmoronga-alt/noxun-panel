  // ============ R-23.1: ESCAPE RETAZ RUCNYCH MODALOV (`nx_esc.js`) ==========
  // Kontrakt UI 2.0 hovori „Escape zatvara modal". Do tejto davky to platilo LEN
  // pre modaly, ktore si vypytali zdielanu kostru D-15 (`nx_modal.js`), a pre
  // par rucnych, ktore mali vlastny handler. Sest rucnych modalov Escape nemalo
  // vobec — jedina cesta von bola mys:
  //   * Inspector: `absModal` (chybajuca ABS paska),
  //   * Studio:    `mdRestoreModal`, `mdDeleteModal`, `mdUniModal`, `demosModal`
  //                (sekcia Materialy) a `hwDelModal` (sekcia Kovanie).
  //
  // PRECO JEDEN HANDLER A NIE SEST NOVYCH: vsetky Escape listenery okna visia na
  // `document` a `stopPropagation` medzi nimi NEFUNGUJE (lekcia nx_modal.js
  // a studio.js — dva poslucháči toho isteho uzla). Sest nezavislych listenerov
  // by znamenalo, ze jedno stlacenie zatvori dve vrstvy naraz a ze o poradi
  // rozhoduje poradie `<script>` tagov. Preto je tu JEDEN dokumentovy handler
  // s PRIORITNYM ZOZNAMOM vrstiev — spolocny pre obe okna (ID modalov su naprie
  // Inspectorom a Studiom jedinecne, takze jedna tabulka staci; vrstva, ktorej
  // uzol v okne nie je, sa proste nikdy neoznaci za otvorenu).
  //
  // PRAVIDLO: jedno stlacenie Escape = zatvori sa NAJVYSSIA otvorena vrstva.
  //   * `FOREIGN` = vrstvy, ktorych Escape uz obsluhuje NIEKTO INY (kostra D-15,
  //     rozbalovacie nastavenia raily a listy, comboboxy, `nxdaModal`, rucne
  //     modaly s vlastnym handlerom) ALEBO ktorych sa Escape dotknut NESMIE:
  //     fazove okno prepoctu cien `budPrModal` riadi SERVER a vo faze `run` by
  //     zatvorenie nechalo beh visiet bez okna (kontrakt nx_modal.js, audit #9).
  //     Kym je taka vrstva NAD nami, tento handler NEROBI NIC a udalost pusti
  //     dalej — obsluzi ju jej vlastnik. Zavriet dve vrstvy naraz je horsie nez
  //     zavriet spodnu az druhym stlacenim. Co znamena „nad nami", riesi
  //     komentar pri `blockedBy()` nizsie — nie kazda cudzia vrstva nad nami
  //     naozaj je.
  //   * `OWN` = sest modalov vyssie. Zatvori sa PRVY otvoreny v poradi zoznamu
  //     a udalost sa SPOTREBUJE (`stopImmediatePropagation` — vzor nx_modal.js;
  //     `stopPropagation` by nestacilo), inak by ju za nami dostal este handler
  //     Studia a zavrel by aj svoje rozbalovacie nastavenie hran.
  //
  // ESCAPE = KLIK NA „ZRUSIT", nie holy `display:none`. Vola sa TA ISTA funkcia,
  // ktoru vola tlacidlo: `mddCancel` rusi bezuci Demos fetch na serveri,
  // `absModalChoose('cancel')` vracia povodnu hodnotu selectu, `mdUniClose`
  // zahadza pending odtlacok zo servera. Skryt okno bez nich by znamenalo tichy
  // rozdiel medzi mysou a klavesnicou.
  //
  // Vsetkych sest modalov je POTVRDZOVACICH/VYBEROVYCH — nenesu rozpisany
  // formular, takze Escape nema co ticho stratit (pamat rozpisanych hodnot rieši
  // kostra D-15 pre svoje pridavacky). Ziadny z nich nema ani „busy" fazu: ich
  // potvrdenie modal zatvara HNED a zapis dokoncuje server.
  //
  // Otvorenost sa pozna podla `style.display !== 'none'` — vsetkych sest sa
  // otvara zapisom do `style.display` (raz `'flex'`, raz `''`) a zatvara
  // `'none'`; `budPrModal` v DOM ani neexistuje, kym nie je otvoreny.
  (function(global){
    'use strict';

    function el(id){
      var d = global.document;
      return (d && d.getElementById) ? d.getElementById(id) : null;
    }

    // Vrstva je otvorena, ked jej uzol existuje a nie je schovany.
    function visible(id){
      var n = el(id);
      if (!n) return false;
      return !n.style || n.style.display !== 'none';
    }

    function callGlobal(name, arg){
      var f = global[name];
      if (typeof f !== 'function') return false;
      f(arg);
      return true;
    }

    // Tabulka vlastnych vrstiev. PORADIE V NEJ NIE JE PRIORITA (review #273
    // kolo 2): ked su otvorene dve naraz, rozhoduje DOKUMENTOVE PORADIE uzlov
    // — pri zhodnom `z-index` (vsetky `.nxmodal` maju 60) kresli prehliadac ako
    // posledny ten, ktory je v HTML nizsie, takze prave ten je VIDIET. Vid
    // `topOpen()` nizsie.
    var OWN = [
      { id: 'absModal', fn: 'absModalChoose', arg: 'cancel' },
      { id: 'demosModal', fn: 'mddCancel' },
      { id: 'mdUniModal', fn: 'mdUniClose' },
      { id: 'mdDeleteModal', fn: 'mdDeleteClose' },
      { id: 'mdRestoreModal', fn: 'mdRestoreClose' },
      { id: 'hwDelModal', fn: 'hwDelClose' }
    ];

    // ----- CUDZIE VRSTVY: DVE TRIEDY, LEBO NIE KAZDA JE NAD NAMI --------------
    // (a) SKUTOCNE MODALY — celoplosne prekrytie so scrimom. Ked je taky
    //     otvoreny, je nad vsetkym (`.nxmodal` ma z-index 60, kostra D-15 este
    //     vyssie) a nas modal sa pod nim otvorit ani nema. Blokuju VZDY.
    var FOREIGN_MODAL_IDS = [
      'budPrModal', // fazove okno prepoctu cien — SERVER, vo faze `run` sa zavriet NESMIE
      'nxdaModal',  // „Pridat z Demosu" — vlastny Escape na poli hladania
      'tplModal',   // ulozit ako sablonu — vlastny Escape na uzle modalu
      'simModal',   // podobne dielce — vlastny Escape na uzle modalu
      'cfgModal'    // nastavenia Inspectora — vlastny Escape + navrat fokusu
    ];
    // (b) FLYOUTY A MENU — male prekryvne okienka prilepene k svojmu tlacidlu,
    //     ktore ziju v stacking kontexte raila/listy (z-index 55 a nizsie).
    //     Tie pod modalom OSTAVAJU otvorene a su pod nim SCHOVANE: klavesnicova
    //     cesta „rohove menu ABS otvorene → combobox materialu → dekor bez
    //     pouzitelnej pasky" otvori `absModal` (z-index 60) NAD stale otvorenym
    //     menu (review #273 kolo 1, P2). Keby blokovali aj vtedy, prve stlacenie
    //     Escape by zavrelo NEVIDITELNU vrstvu a pouzivatel by musel stlacit
    //     dvakrat. Preto blokuju LEN vtedy, ked ziadny nas modal otvoreny nie je.
    //     Zatvarat ich pri otvarani modalu by znamenalo hacik v kazdom otvarani
    //     (a tichu stratu rozrobeneho nastavenia) — necha sa im vlastny Escape,
    //     len az po tom nasom.
    //     Funkcia „je otvoreny?" (Inspector) alebo top-level priznak okna (Studio).
    var FLYOUT_FNS = ['warnPanelOpen', 'nxEdgeMenuOpen', 'nxTagMenuOpen'];
    var FLYOUT_FLAGS = ['ecMenuOpen', 'vepoMenuOpen'];
    //
    // Combobox D-85 (`NXCombo`) je zamerne v triede (b): v ziadnom z tych
    // siestich modalov `select[data-nx-combo]` NIE JE (su to potvrdzovacie okna;
    // `mdUniModal` ma dva OBYCAJNE selecty) a `NXCombo.pick()` ponuku zatvara
    // EST PRED udalostou `change`, ktora `absModal` otvara — otvoreny combobox
    // NAD nasim modalom teda vzniknut nema ako. Keby do niektoreho z nich
    // combobox raz pribudol, patri do triedy (a): jeho `.cbpop` ma z-index 120,
    // teda NAD modalom.

    // Meno vrstvy, ktora Escape drzi nad nami (alebo null).
    function blockedBy(){
      var i;
      for (i = 0; i < FOREIGN_MODAL_IDS.length; i++){
        if (visible(FOREIGN_MODAL_IDS[i])) return FOREIGN_MODAL_IDS[i];
      }
      // Kostra D-15. Od KOV-H2 ju nacitavaju OBE okna (modal rucnej polozky
      // kovania v Inspectorovi), test na `typeof` ostava ako poistka pre
      // pripad, ze by ju niektore okno prestalo nacitavat.
      if (global.NXModal && typeof global.NXModal.isOpen === 'function' &&
          global.NXModal.isOpen() === true) return 'NXModal';
      // Trieda (b): kym je otvoreny NAS modal, je nad flyoutmi — Escape patri jemu.
      if (topOpen()) return null;
      for (i = 0; i < FLYOUT_FNS.length; i++){
        var f = global[FLYOUT_FNS[i]];
        if (typeof f === 'function' && f() === true) return FLYOUT_FNS[i];
      }
      for (i = 0; i < FLYOUT_FLAGS.length; i++){
        if (global[FLYOUT_FLAGS[i]] === true) return FLYOUT_FLAGS[i];
      }
      if (global.NXCombo && typeof global.NXCombo.isOpen === 'function' &&
          global.NXCombo.isOpen() === true) return 'NXCombo';
      return null;
    }

    // Je uzol `b` v dokumentovom poradi ZA uzlom `a`? (bit 4 =
    // `Node.DOCUMENT_POSITION_FOLLOWING`; konstanta sa pise cislom, lebo
    // `Node` v Node.js testoch neexistuje). Ked porovnanie nie je k dispozicii,
    // vrati `false` — retaz vtedy ostane pri poradi tabulky.
    function follows(a, b){
      if (!a || !b || typeof a.compareDocumentPosition !== 'function') return false;
      return (a.compareDocumentPosition(b) & 4) === 4;
    }

    // Vrstva, ktoru by Escape prave teraz zatvoril (alebo null).
    //
    // Ked su otvorene DVE vlastne vrstvy naraz, zatvara sa tá, ktora je
    // v dokumentovom poradi POSLEDNA — pri zhodnom `z-index` (vsetky `.nxmodal`
    // maju 60) ju prehliadac kresli navrch, takze prave ju pouzivatel vidi.
    // Review #273 kolo 2 (P2): stavalo sa to na scenari „preflight zmazania
    // materialu odosla, pouzivatel prepne sekciu na Kovanie a otvori `hwDelModal`,
    // oneskorena odpoved `MD.confirmDelete` otvori `mdDeleteModal` POD nim" —
    // podla poradia tabulky by Escape zavrel ten SKRYTY materialovy a navonok by
    // sa „nestalo nic". Rozhodovanie je genericke (ziadna logika per modal),
    // takze plati aj pre buduce dvojice.
    //
    // POZNAMKA (nie je to oprava tejto davky): ze `MD.confirmDelete` po odchode
    // zo sekcie modal vobec znova otvori, je SAMOSTATNA chyba toho toku — ta ista
    // trieda ako oneskorena odpoved „Nahradit UNI…", ktoru rieši generacia
    // relacie v `proj_materials.js`. Kandidat do registra; reťaz ju len prestane
    // zhorsovat.
    function topOpen(){
      var best = null, bestNode = null;
      for (var i = 0; i < OWN.length; i++){
        if (!visible(OWN[i].id)) continue;
        var node = el(OWN[i].id);
        if (!best || follows(bestNode, node)){ best = OWN[i]; bestNode = node; }
      }
      return best;
    }

    // Zatvorenie bez klavesnice (odchod zo sekcie a pod. si okna riesia samy —
    // toto je len testovatelny vstupny bod retaze).
    function closeTop(){
      var layer = topOpen();
      if (!layer) return null;
      if (!callGlobal(layer.fn, layer.arg)) return null;
      return layer.id;
    }

    function onKey(ev){
      if (!ev || ev.key !== 'Escape') return false;
      if (blockedBy()) return false;
      var id = closeTop();
      if (!id) return false;
      if (typeof ev.preventDefault === 'function') ev.preventDefault();
      // Udalost SPOTREBUJEME — bez toho by ju dostal aj handler Studia
      // a jedno stlacenie by zavrelo modal AJ rozbalovacie nastavenie.
      if (typeof ev.stopImmediatePropagation === 'function') ev.stopImmediatePropagation();
      return true;
    }

    if (global.document && typeof global.document.addEventListener === 'function'){
      global.document.addEventListener('keydown', onKey);
    }

    var API = { OWN: OWN, FOREIGN_MODAL_IDS: FOREIGN_MODAL_IDS,
                FLYOUT_FNS: FLYOUT_FNS, FLYOUT_FLAGS: FLYOUT_FLAGS,
                blockedBy: blockedBy, topOpen: topOpen, closeTop: closeTop,
                onKey: onKey };
    global.NXEsc = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
