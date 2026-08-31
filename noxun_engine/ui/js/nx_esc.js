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
  //     Kym je hocktora z nich otvorena, tento handler NEROBI NIC a udalost
  //     pusti dalej — obsluzi ju jej vlastnik. Zavriet dve vrstvy naraz je horsie
  //     nez zavriet spodnu az druhym stlacenim.
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

    // Poradie = od najvrchnejsej vrstvy. Dva z tychto modalov naraz otvorene
    // byt nemozu (kazdy patri inej sekcii a odchod zo sekcie ich zatvara,
    // `absModal` je jediny v Inspectorovi) — poradie je tu preto, aby bolo
    // spravanie deterministicke aj keby sa to raz zmenilo.
    var OWN = [
      { id: 'absModal', fn: 'absModalChoose', arg: 'cancel' },
      { id: 'demosModal', fn: 'mddCancel' },
      { id: 'mdUniModal', fn: 'mdUniClose' },
      { id: 'mdDeleteModal', fn: 'mdDeleteClose' },
      { id: 'mdRestoreModal', fn: 'mdRestoreClose' },
      { id: 'hwDelModal', fn: 'hwDelClose' }
    ];

    // Vrstvy, ktore Escape uz obsluhuje niekto iny (alebo sa ich dotknut nesmie).
    var FOREIGN_IDS = [
      'budPrModal', // fazove okno prepoctu cien — SERVER, vo faze `run` sa zavriet NESMIE
      'nxdaModal',  // „Pridat z Demosu" — vlastny Escape na poli hladania
      'tplModal',   // ulozit ako sablonu — vlastny Escape na uzle modalu
      'simModal',   // podobne dielce — vlastny Escape na uzle modalu
      'cfgModal'    // nastavenia Inspectora — vlastny Escape + navrat fokusu
    ];
    // Prekryvne ovladace s vlastnym Escapom: funkcia „je otvoreny?" (Inspector)
    // alebo top-level priznak skriptu okna (Studio).
    var FOREIGN_FNS = ['warnPanelOpen', 'nxEdgeMenuOpen', 'nxTagMenuOpen'];
    var FOREIGN_FLAGS = ['ecMenuOpen', 'vepoMenuOpen'];

    // Meno vrstvy, ktora Escape drzi nad nami (alebo null).
    function blockedBy(){
      var i;
      for (i = 0; i < FOREIGN_IDS.length; i++){
        if (visible(FOREIGN_IDS[i])) return FOREIGN_IDS[i];
      }
      for (i = 0; i < FOREIGN_FNS.length; i++){
        var f = global[FOREIGN_FNS[i]];
        if (typeof f === 'function' && f() === true) return FOREIGN_FNS[i];
      }
      for (i = 0; i < FOREIGN_FLAGS.length; i++){
        if (global[FOREIGN_FLAGS[i]] === true) return FOREIGN_FLAGS[i];
      }
      // Komponenty: kostra D-15 a combobox materialov. V Inspectorovi `NXModal`
      // vobec nie je nacitany, preto obozretne.
      if (global.NXModal && typeof global.NXModal.isOpen === 'function' &&
          global.NXModal.isOpen() === true) return 'NXModal';
      if (global.NXCombo && typeof global.NXCombo.isOpen === 'function' &&
          global.NXCombo.isOpen() === true) return 'NXCombo';
      return null;
    }

    // Vrstva, ktoru by Escape prave teraz zatvoril (alebo null).
    function topOpen(){
      for (var i = 0; i < OWN.length; i++){
        if (visible(OWN[i].id)) return OWN[i];
      }
      return null;
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

    var API = { OWN: OWN, FOREIGN_IDS: FOREIGN_IDS, FOREIGN_FNS: FOREIGN_FNS,
                FOREIGN_FLAGS: FOREIGN_FLAGS,
                blockedBy: blockedBy, topOpen: topOpen, closeTop: closeTop,
                onKey: onKey };
    global.NXEsc = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
