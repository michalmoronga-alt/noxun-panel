  // ===================== REGISTER SEKCIÍ ŠTÚDIA (H14a) =====================
  // Sekcia okna Štúdio sa prihlasuje NA JEDNOM MIESTE — riadkom tohto registra.
  // Z neho berú navigácia (skupina, ikona, názov, tooltip, badge), hlavička
  // sekcie (názov + nápoveda), hláška tlačidla „Obnoviť", filter deep-linku
  // v Inspectore (`NXShell.studioSection`) aj zoznam sekcií Nastavení
  // (`studio_settings.js`). Vlastný zoznam sekcií si nikto iný nedrží (guard
  // `tests/pure/test_h14a_register.rb`).
  //
  // AUTORITA: serverový whitelist `StudioDialog::SECTIONS` (Ruby) rozhoduje,
  // ktorú sekciu smie okno otvoriť; tento register je PREZENTÁCIA a jeho poradie
  // = poradie `SECTIONS`. Zhodu (aj poradie) stráži nezávislá fixtúra
  // `tests/fixtures/h14_studio_sections.json` — Ruby aj JS test ju porovnávajú
  // so svojou stranou (žiadny regex nad zdrojom druhej strany).
  //
  // Kľúče riadka: `id` · `grp` (skupina navigácie) · `ic` (ikona zo spritu
  // `icons.js`, každá iná) · `t` (názov v navigácii = nadpis sekcie) · `hint`
  // (len doplnok tooltipu navigácie) · `badge` (ktoré hotové počty zo servera
  // visia pri položke: `ctrl` = semafor zákazky, `appl` = „V zákazke") · `head`
  // (nápoveda v hlavičke sekcie) · `refresh` (hláška počas „Obnoviť"; bez nej
  // `REFRESH_DEFAULT`) · `module` (súbor, ktorý sekciu kreslí) · `data` (kľúč
  // payloadu `NX.setStudio`, ktorý sekcii skladá `StudioDialog.push_state`).
  //
  // Čisté API bez DOM a bez závislostí. Konzumenti si smú vziať referenciu na
  // objekt registra, ale zoznamy (`ids()`, `groups()`, `inModule()`) si pýtajú
  // AŽ PRI POUŽITÍ — nikdy ich neodvodzujú pri načítaní skriptu (poučenie H12).
  // Načítava sa v `studio.html` PRED `studio.js` a v `panel.html` PRED `shell.js`.
  (function(){
    var GROUPS = [
      { grp: 'job', t: 'ZÁKAZKA' },
      { grp: 'catalogs', t: 'KATALÓGY' },
      { grp: 'settings', t: 'NASTAVENIA' }
    ];

    var ROWS = [
      { id: 'bom', grp: 'job', ic: 'list', t: 'Kusovník',
        head: 'skupiny podľa materiálu · pohľady Dielce / Platne / ABS · živý zoznam',
        module: 'studio.js', data: 'rows' },
      // Pri Kontrole visia živé počty RED/ORANGE z posledného pushu.
      { id: 'ctrl', grp: 'job', ic: 'clipboard-check', t: 'Kontrola', badge: 'ctrl',
        head: 'semafor filtruje zoznam · klik na nález ho označí v modeli · prepínače hrán a kresby',
        refresh: 'Prepočítavam kontrolu…',
        module: 'studio.js', data: 'control' },
      { id: 'buy', grp: 'job', ic: 'cart', t: 'Nákup kovania',
        head: 'nákupný zoznam zo setov · nekompletné položky jantárovo · CSV pre objednávku',
        refresh: 'Prepočítavam nákupný zoznam…',
        module: 'studio.js', data: 'hardware_sets' },
      { id: 'budget', grp: 'job', ic: 'euro', t: 'Rozpočet',
        head: 'rozpočet zákazky · ceny kovania sú spoločné pre všetky zákazky',
        refresh: 'Prepočítavam rozpočet…',
        module: 'budget.js', data: 'budget' },
      // Zákaznícka projekcia toho istého rozpočtu (suma sa nikdy nelíši).
      { id: 'offer', grp: 'job', ic: 'file-text', t: 'Cenová ponuka',
        head: 'zákaznícky pohľad na ten istý rozpočet · rečou zákazníka, bez interných kódov',
        refresh: 'Prepočítavam cenovú ponuku…',
        module: 'budget.js', data: 'budget' },
      // Plán je podklad pre objednávku, reže VEPO — preto „horná hranica".
      { id: 'cut', grp: 'job', ic: 'scissors', t: 'Nárezový plán',
        hint: 'koľko platní stačí pri tomto rozložení (horná hranica)',
        head: 'koľko platní stačí pri tomto rozložení · podklad pre objednávku — reže VEPO',
        refresh: 'Prepočítavam nárezový plán…',
        module: 'sheet_layout.js', data: 'sheet_layout' },
      // Katalóg je globálny a chodí echom — z modelu sa prepočítava len použitie.
      { id: 'mat', grp: 'catalogs', ic: 'layers', t: 'Materiály',
        head: 'katalóg dekorov je spoločný pre všetky zákazky · predvoľby projektu platia pre túto',
        refresh: 'Prepočítavam použitie dekorov v projekte…',
        module: 'proj_materials.js', data: 'mat' },
      // „Obnoviť" si pýta čerstvý katalóg a sety z disku, z modelu nič.
      { id: 'hw', grp: 'catalogs', ic: 'hammer', t: 'Kovanie',
        head: 'katalóg položiek a sety sú spoločné pre všetky zákazky · predvoľby setov platia pre túto zákazku',
        refresh: 'Načítavam čerstvý katalóg kovania a sety…',
        module: 'hw_catalog.js', data: 'hw' },
      // Badge = riadky pohľadu „V zákazke" na vybavenie (počty skladá server).
      { id: 'appl', grp: 'catalogs', ic: 'appliance', t: 'Spotrebiče', badge: 'appl',
        head: 'katalóg modelov je tohto počítača · rozmery z listov výrobcov · bez cien (tie patria Rozpočtu)',
        module: 'appliances.js', data: 'appl' },
      { id: 'rules', grp: 'catalogs', ic: 'settings', t: 'Pravidlá',
        head: 'ABS podľa roly dielca (spoločné, len na čítanie) · kovanie podľa rozmerov — platí pre tento projekt',
        refresh: 'Načítavam pravidlá z aktuálneho modelu…',
        module: 'rules.js', data: 'rules' },
      // Bez vlastnej hlášky „Obnoviť" (predvolená) — vedomý stav, PACKAGE_H14 Q1.
      { id: 'tpl', grp: 'catalogs', ic: 'star', t: 'Šablóny',
        head: 'knižnica je spoločná pre všetky zákazky · novú uložíš v Inspectore z označenej skrinky',
        module: 'templates.js', data: 'tpl' },
      { id: 'sup', grp: 'settings', ic: 'truck', t: 'Dodávateľ / Demos',
        head: 'aktívny dodávateľ a stav väzby na Demos · väzba sa nastavuje pri konkrétnom dekore',
        module: 'studio_settings.js', data: 'settings' },
      // H4 · D-09: vlastná ikona — s `euro` sa v zbalenej navigácii zlievala s Rozpočtom.
      { id: 'bset', grp: 'settings', ic: 'sliders-horizontal', t: 'Nastavenia rozpočtu',
        head: 'sadzby, režimy a prahy · globálne pre všetky zákazky, do zákazky sa nemrazia',
        module: 'studio_settings.js', data: 'settings' },
      { id: 'about', grp: 'settings', ic: 'info', t: 'O plugine',
        head: 'to isté nájdeš v koliesku Inspectora',
        module: 'studio_settings.js', data: 'settings' }
    ];

    var REFRESH_DEFAULT = 'Prepočítavam kusovník…';

    GROUPS.forEach(function(g){ Object.freeze(g); });
    ROWS.forEach(function(r){ Object.freeze(r); });
    Object.freeze(GROUPS);
    Object.freeze(ROWS);

    var OWN = Object.prototype.hasOwnProperty;
    var BY_ID = {};
    ROWS.forEach(function(r){ BY_ID[r.id] = r; });

    // Je to id sekcie? Len reťazec zo zoznamu (nie `'__proto__'`, číslo ani null).
    function has(id){ return typeof id === 'string' && OWN.call(BY_ID, id); }
    // Riadok sekcie (zmrazený) alebo null.
    function get(id){ return has(id) ? BY_ID[id] : null; }
    // Id sekcií v poradí — vždy nové pole.
    function ids(){ return ROWS.map(function(r){ return r.id; }); }
    // Skupiny navigácie v poradí: [{ grp, t, items: [riadky] }].
    function groups(){
      return GROUPS.map(function(g){
        return { grp: g.grp, t: g.t, items: ROWS.filter(function(r){ return r.grp === g.grp; }) };
      });
    }
    // Id sekcií, ktoré kreslí daný súbor (napr. 'studio_settings.js').
    function inModule(file){
      return ROWS.filter(function(r){ return r.module === file; }).map(function(r){ return r.id; });
    }
    // Globálna funkcia podľa mena V ČASE VOLANIA (sekčné moduly sú globály okna
    // a načítavajú sa až za `studio.js`); nie funkcia = null. Len vlastné
    // vlastnosti globálu — `let`/`const` ani zdedené mená (`constructor`) nenájde.
    function fn(name){
      var g = (typeof globalThis !== 'undefined') ? globalThis : ((typeof window !== 'undefined') ? window : null);
      if (!g || typeof name !== 'string' || !OWN.call(g, name)) return null;
      var f = g[name];
      return (typeof f === 'function') ? f : null;
    }

    var API = Object.freeze({
      ids: ids, has: has, get: get, groups: groups, inModule: inModule, fn: fn,
      REFRESH_DEFAULT: REFRESH_DEFAULT
    });

    // Node testy: `require('./studio_sections.js')`; prehliadač: `window.NXStudioSections`.
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
    if (typeof window !== 'undefined') window.NXStudioSections = API;
  })();
