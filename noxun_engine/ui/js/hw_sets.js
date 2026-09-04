  // ================= Sety kovania + predvolby projektu (V0.6 D1b) =================
  // Set = mapovacie pravidlo genericky typ -> zoznam Demos kodov s pomermi
  // (NIE polozka katalogu). Server (HardwareSets) je autorita: normalizacia,
  // validacia, revision guard kniznice, snapshot projektu (mapping + kopie
  // definicii — audit B2). JS len renderuje a posiela payloady.
  // XSS kontrakt ako hw_catalog.js: createElement + textContent, data-action
  // delegacia; ziadne innerHTML s datami.

  var HWS_DATA = null;   // posledny HWSETS.init payload
  // KOV-B3: INLINE editor setu (`HWS_EDIT` + `hwsEditorNode`) ZANIKOL a s nim
  // aj R-41 (draft posielal CERSTVU reviziu z posledneho pushu, takze cudzia
  // zmena toho isteho setu presla serverovym CAS-om ako vlastna). Set sa
  // odteraz upravuje v D-15 MODALI, ktory si reviziu PRIPINA pri otvoreni
  // (`rev`) a drzi si aj ZAKLADNU definiciu setu (`base`) — presne vzor
  // `hwsPinRev` z editora pasiem.
  var HWS_SET = null;    // otvoreny modal setu (null = zavrety)
  var HWS_TOKEN_SEQ = 0; // identita JEDNEHO odoslania (vzor KOV-B2 `hwItemArm`)
  var HWS_REOPEN = false; // prekreslenie modalu NIE JE jeho zatvorenie
  var HWS_NEW_OPT = '__new__'; // „+ Vytvoriť…" v selecte vyrobcu/rady
  var HWS_KEY_NEW = 'hw:set:new'; // memoryKey rozpisaneho NOVEHO setu
  var HWS_PREVIEW_MS = 300;    // debounce ziveho nahladu pri pisani
  var HWS_DEL_ARM = '';  // set_id cakajuci na druhy klik "Naozaj zmazat?"
  // H1b: rozpracovane editory VYBERU SETU PODLA PARAMETRA (selector mapovania).
  // Kluc = "<action>|<generic_type>" (projektova a globalna tabulka su oddelene);
  // hodnota = { param, rows: [{min, max, set_id}] } alebo null = editor zavrety.
  var HWS_SEL = {};
  var HWS_GLOBAL_OPEN = false; // <details> globálnych predvolieb prežije prerender
  // Hodnota volby „nastaviť podľa parametra…" v selecte mapovania — NIKDY sa
  // neposiela na server, len otvara editor pasiem.
  var HWS_PARAM_OPT = '__param__';
  // ŠT-3a-2: `HWS_PROJ_RO` (read-only rezim predvolieb projektu) ZANIKOL —
  // tri MODELOVE zapisy su od tejto davky v `SECTION_ACTIONS`, takze sekcia
  // ich ovlada priamo a premostenie do okna nema kam viest (okno zaniklo).

  function hwsEl(id){ return document.getElementById(id); }
  function hwsMk(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function hwsSend(name, payload){
    if (window.sketchup && sketchup[name]) sketchup[name](JSON.stringify(payload));
  }

  // --- ciste funkcie (Node testy: tests/js/test_hw_sets.js) -----------------

  // Slug identity noveho setu z nazvu (server normalize toleruje cokolvek
  // neprazdne; diakritika von, medzery -> pomlcky).
  function hwsSlug(name){
    var s = String(name == null ? '' : name);
    try { s = s.normalize('NFD').replace(/[̀-ͯ]/g, ''); } catch (e) { /* stary CEF */ }
    s = s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    return s || 'set';
  }
  // Sety daneho generickeho typu (poradie kniznice).
  function hwsSetsForType(sets, gt){
    return (sets || []).filter(function(s){ return s.generic_type === gt; });
  }
  function hwsTrim(v){ return String(v == null ? '' : v).trim(); }
  // R-07: kompatibilitná brána GLOBÁLNEJ knižnice. Server posiela
  // `library_state` ('ok' | 'read_only' | 'degraded') a `library_reason`
  // (hotová SK veta — JS si žiadny vlastný preklad neskladá). Knižnica
  // z novšej verzie sa nesmie ani meniť, ani potichu používať: sekcia vypne
  // GLOBÁLNE mutácie a dôvod povie bannerom. PROJEKTOVÉ predvoľby nad zdravým
  // snapshotom fungujú ďalej — ich zdrojom je .skp, nie knižnica.
  function hwsLibBlocked(data){ return !!(data && data.library_state === 'read_only'); }
  // R-11 DEGRADOVANÁ knižnica (poškodený primár + platná záloha): obsah je
  // POUŽITEĽNÝ — sety sa čítajú zo zálohy, dajú sa zmraziť do projektu
  // a projektové predvoľby sa menia ďalej. Zakázané sú VÝHRADNE zápisy do
  // globálneho SÚBORU; keby sa vykonali, primár by sa prepísal obsahom
  // odvodeným od STARŠEJ zálohy.
  function hwsLibDegraded(data){ return !!(data && data.library_state === 'degraded'); }
  // Smie sa zapisovať do globálnej knižnice? (read_only aj degraded = nie)
  function hwsLibWriteBlocked(data){ return hwsLibBlocked(data) || hwsLibDegraded(data); }
  // Akcie, ktoré menia knižnicu alebo z nej kopírujú do .skp (`hws-merge-seed`
  // a `hws-reset-proj` zapisujú do modelu, ale ich ZDROJOM je knižnica) —
  // vypína ich LEN `read_only` (pri degraded je zdroj v poriadku).
  // KOV-B3: `hws-save` zo zoznamu ZANIKLA spolu s inline editorom — set sa
  // uklada tlacidlom MODALU (kostra D-15), ktore sa bez `hws-new`/`hws-edit`
  // vobec neotvori; serverova brana (`library_write_blocked?`) je aj tak
  // posledne slovo.
  var HWS_LIB_ACTIONS = ['hws-new', 'hws-edit', 'hws-del',
                         'hws-merge-seed', 'hws-reset-proj'];
  // Akcie, ktoré ZAPISUJÚ do globálneho súboru — vypnuté aj pri degraded.
  var HWS_WRITE_ACTIONS = ['hws-new', 'hws-edit', 'hws-del'];
  function hwsLibReason(data){
    return (data && data.library_reason) || 'Knižnica setov kovania sa nedá bezpečne prečítať';
  }
  function hwsBlank(v){ return hwsTrim(v) === ''; }
  // Cislo pre ZOBRAZENIE: 17 -> "17", 17.5 -> "17,5" (zrkadlo Ruby fmt_mm).
  // GH #132 P2: hodnota sa NEZAOKRUHLUJE — cez tuto funkciu ide aj hranica
  // pasma do EDITORA, takze zo 120,25 by sa otvorenim a ulozenim editora
  // ticho stalo 120,3 (a hranica by vyberala iny set/kod).
  function hwsNum(v){
    var s = hwsTrim(v);
    if (s === '') return ''; // prázdne pole ostáva prázdne (Number('') je 0!)
    var n = Number(s.replace(',', '.'));
    if (!isFinite(n)) return s;
    return (Math.abs(n - Math.round(n)) < 1e-9)
      ? String(Math.round(n))
      : String(n).replace('.', ',');
  }
  // Cislo pre SERVER: SK ciarka -> bodka (Ruby Float("17,5") by spadlo).
  function hwsNumIn(v){ return hwsTrim(v).replace(',', '.'); }
  // Nazov parametra zo servera (payload params = HardwareSets::PARAM_OPTIONS).
  // form 'by' = "podľa výšky sokla", 'label' = "výška sokla".
  function hwsParamLabel(key, params, form){
    var list = params || [];
    for (var i = 0; i < list.length; i++){
      if (list[i] && list[i].key === key) return list[i][form || 'by'] || list[i].label;
    }
    return key ? ('podľa: ' + key) : 'podľa parametra';
  }
  // Citatelny suhrn clena: "104717 ×1", "TipOn ×1 na dvierka",
  // "rad NL: 420→357695, 470→357696", "podľa výšky sokla: 17–21 → 82744 · …".
  function hwsMemberSummary(m, params){
    if (!m) return '';
    if (m.code_by_nl){
      var pairs = Object.keys(m.code_by_nl).sort(function(a, b){ return Number(a) - Number(b); })
        .map(function(nl){ return nl + '→' + m.code_by_nl[nl]; });
      return 'rad NL: ' + (pairs.join(', ') || '—');
    }
    if (m.param_bands){
      return hwsParamLabel(m.param_bands.param, params) + ': ' + hwsBandsSummary(m.param_bands.bands, 'code');
    }
    var label = m.label ? m.label + ' ' : '';
    return label + m.code + ' ×' + (m.qty || 1) + (m.per === 'owner' ? ' na vlastníka (dvierka)' : '');
  }
  // „17–21 → 82744 · 140–160 → 367823"; names = mapa hodnota->citatelny nazov
  // (pri selectore su hodnoty set_id, pri clene setu kody).
  function hwsBandsSummary(bands, key, names){
    var list = (bands || []).map(function(b){
      var v = b[key];
      return hwsNum(b.min) + '–' + hwsNum(b.max) + ' → ' + ((names && names[v]) || v);
    });
    return list.join(' · ') || '—';
  }
  // Riadky editora -> pasma pre server. ZAHODI sa len uplne prazdny riadok
  // (nic vyplnene — vzor radu NL); ciastocne vyplneny ide na server, aby
  // pouzivatel dostal konkretnu chybu (validacia je all-or-nothing na SERVERI).
  function hwsBuildBands(rows, key){
    return (rows || []).filter(function(r){
      return !(hwsBlank(r.min) && hwsBlank(r.max) && hwsBlank(r[key]));
    }).map(function(r){
      var out = { min: hwsNumIn(r.min), max: hwsNumIn(r.max) };
      out[key] = hwsTrim(r[key]);
      return out;
    });
  }
  // --- KOV-B3: CLENOVIA SETU -------------------------------------------------
  //
  // Dátový tvar clena sa NEMENI (XOR `code` / `code_by_nl` / `param_bands`;
  // ziadne `code_by_height`). Meni sa len OTAZKA, ktorou ho editor sklada:
  // „Ako sa určí kód?" (`kind`) + „Koľko?" (`per`). Prepnutie sposobu polia
  // druheho sposobu ZAHADZUJE — polovicny clen by sa na serveri odmietol
  // a v editore by vyzeral hotovo.
  var HWS_KINDS = [['code', 'pevný kód'], ['nl', 'podľa dĺžky výsuvu (NL)'],
                   ['bands', 'podľa pásma parametra']];
  var HWS_PERS  = [['unit', 'na 1 kus kovania'], ['owner', 'na vlastníka (dvierka/zásuvku)']];

  function hwsMemberKind(m){
    if (!m) return 'code';
    if (m.is_series) return 'nl';
    if (m.is_bands) return 'bands';
    return 'code';
  }
  // Prazdny clen daneho sposobu (pre „+ Pridať člena" aj pre prepnutie).
  function hwsMemberBlank(kind, gt){
    var base = { per: 'unit', qty: 1, label: '' };
    if (kind === 'nl'){
      base.is_series = true;
      base.series = [{ nl: '', code: '' }];
    } else if (kind === 'bands'){
      base.is_bands = true;
      base.param = hwsDefaultParam(gt);
      base.bands = [{ min: '', max: '', code: '' }];
    } else {
      base.is_series = false;
      base.code = '';
    }
    return base;
  }
  // Prepnutie sposobu urcenia kodu: spolocne polia („Koľko?", počet, popis)
  // OSTAVAJU, polia druheho sposobu sa ZAHADZUJU.
  function hwsMemberSwitch(m, kind, gt){
    var out = hwsMemberBlank(kind, gt);
    out.per = (m && m.per === 'owner') ? 'owner' : 'unit';
    out.qty = (m && m.qty) || 1;
    out.label = (m && m.label) || '';
    if (kind === 'code' && m && m.code) out.code = m.code;
    return out;
  }
  // Cleny editora -> tvar servera (rad: riadky {nl, code} -> mapa;
  // pasma: riadky {min, max, code} -> { param, bands }).
  function hwsBuildMembers(members){
    return (members || []).map(function(m){
      var out = { per: m.per === 'owner' ? 'owner' : 'unit', qty: parseInt(m.qty, 10) || 1 };
      if (m.label) out.label = m.label;
      if (m.is_series){
        var map = {};
        (m.series || []).forEach(function(row){
          var nl = hwsTrim(row.nl);
          var code = hwsTrim(row.code);
          if (nl && code) map[nl] = code;
        });
        out.code_by_nl = map;
      } else if (m.is_bands){
        out.param_bands = { param: hwsTrim(m.param), bands: hwsBuildBands(m.bands, 'code') };
      } else {
        out.code = hwsTrim(m.code);
      }
      return out;
    });
  }
  // Set z kniznice -> cleny editora (kopia; rad -> riadky zoradene podla NL).
  function hwsMembersOf(set){
    return ((set && set.members) || []).map(function(m){
      if (m.code_by_nl){
        return { is_series: true, per: m.per || 'unit', qty: m.qty || 1, label: m.label || '',
                 series: Object.keys(m.code_by_nl).sort(function(a, b){ return Number(a) - Number(b); })
                   .map(function(nl){ return { nl: nl, code: m.code_by_nl[nl] }; }) };
      }
      if (m.param_bands){
        return { is_bands: true, per: m.per || 'unit', qty: m.qty || 1, label: m.label || '',
                 param: m.param_bands.param || '',
                 bands: (m.param_bands.bands || []).map(function(b){
                   return { min: hwsNum(b.min), max: hwsNum(b.max), code: b.code || '' };
                 }) };
      }
      return { is_series: false, per: m.per || 'unit', qty: m.qty || 1,
               label: m.label || '', code: m.code || '' };
    });
  }

  // Draft modalu + cleny -> SET payload pre server.
  //
  // KLASIFIKACIA SA POSIELA VZDY CELA (vsetkych pat klucov) — aj prazdna.
  // `save_set!` totiz MERGUJE: kluc, ktory vo vstupe NIE JE, sa preberie
  // z ULOZENEHO setu. Keby modal poslal len vyplnene kluce, prepnutie setu
  // zo zasuvky na dvierka by nechalo v ulozenom sete `drawer_construction`
  // a set by uz nikdy nepresiel validaciou („konštrukciu má len set na
  // zásuvky"). Prazdna hodnota = VEDOME vymazanie, uplna dvojica =
  // ALL-OR-NOTHING zaradenie. `active` z rovnakeho dovodu tiez vzdy.
  //
  // `generic_type` sa posiela LEN vtedy, ked ho NEMA CO ODVODIT (nezaradeny
  // set alebo `use_type: 'iné'`) — inak je autoritou vztahu SERVER
  // (`USE_TYPE_GENERIC`) a dva protirecive zapisy by o tom istom sete
  // vzniknut nemali.
  function hwsBuildSetPayload(draft, members){
    var d = draft || {};
    var ut = hwsTrim(d.use_type);
    var out = {
      set_id: hwsTrim(d.set_id),
      name: hwsTrim(d.name),
      use_type: ut,
      opening_mode: hwsTrim(d.opening_mode),
      // Konstrukcia patri VYHRADNE zasuvke — inde sa posiela PRAZDNA
      // (vedome vymazanie), nikdy sa nevynecha (viz merge vyssie).
      drawer_construction: ut === 'drawer' ? hwsTrim(d.drawer_construction) : '',
      manufacturer: hwsTrim(d.manufacturer),
      series: hwsTrim(d.series),
      active: d.active !== false,
      members: hwsBuildMembers(members)
    };
    if (hwsNeedsType(d)) out.generic_type = hwsTrim(d.generic_type);
    return out;
  }
  // Musi typ kovania vybrat CLOVEK? (nezaradeny set alebo `use_type: 'other'`)
  function hwsNeedsType(d){
    var ut = hwsTrim((d || {}).use_type);
    return ut === '' || ut === 'other';
  }

  // --- KOV-B3: KLASIFIKACIA — slovniky, popisky, auto-nazov ------------------
  //
  // Slovniky su UZAVRETE a ich JEDINY zoznam (aj s popiskami) zije v core
  // (`HardwareSets::CLASS_OPTIONS`) — klient ho dostava v payloade a ziadny
  // vlastny nema. Neznama hodnota (obsah novsej verzie) sa NEPREKLADA:
  // vypise sa tak, ako prisla.
  function hwsClassList(field){
    return ((HWS_DATA && HWS_DATA.class_options) || {})[field] || [];
  }
  function hwsClassLabel(field, value){
    var v = hwsTrim(value);
    var list = hwsClassList(field);
    for (var i = 0; i < list.length; i++){ if (String(list[i][0]) === v) return list[i][1]; }
    return v;
  }
  // Volby selectu klasifikacie. `emptyLabel` = prva (prazdna) volba; pri
  // type pouzitia je to „— nezaradený —", teda VEDOME prazdna klasifikacia.
  function hwsClassOptions(field, emptyLabel){
    var out = emptyLabel == null ? [] : [['', emptyLabel]];
    hwsClassList(field).forEach(function(o){ out.push([String(o[0]), String(o[1])]); });
    return out;
  }

  // Taxonomia (vyrobcovia a rady) — ten isty tvar aj tie iste pravidla ako
  // v modale polozky (KOV-B2): nedostupny zoznam = zamknuty select s ULOZENOU
  // hodnotou, „+ Vytvoriť…" len ked sa da zapisovat.
  function hwsTax(){ return (HWS_DATA && HWS_DATA.taxonomy) || {}; }
  function hwsTaxLocked(){
    var t = hwsTax();
    return t.read_only === true || !((t.manufacturers || []).length);
  }
  function hwsTaxLockedReason(){
    var t = hwsTax();
    return t.state_reason ? ('zoznam výrobcov nie je dostupný: ' + t.state_reason)
                          : 'zoznam výrobcov nie je dostupný — klasifikácia sa nedá meniť';
  }
  function hwsSeriesOf(manufacturer){
    var m = hwsTrim(manufacturer);
    return ((hwsTax().series) || []).filter(function(s){
      return s && String(s.manufacturer) === m;
    }).map(function(s){ return String(s.name); });
  }
  // Zamknuty select ukazuje ULOZENU hodnotu ako jedinu volbu — inak by
  // pouzivatel videl prazdno tam, kde set vyrobcu ma.
  function hwsLockedOptions(value, empty){
    var v = hwsTrim(value);
    var out = [['', empty]];
    if (v && v !== HWS_NEW_OPT) out.push([v, v]);
    return out;
  }
  function hwsManOptions(current){
    if (hwsTaxLocked()) return hwsLockedOptions(current, '— bez výrobcu');
    var out = [['', '— bez výrobcu']];
    (hwsTax().manufacturers || []).forEach(function(m){ out.push([String(m), String(m)]); });
    if (!hwsTax().write_blocked) out.push([HWS_NEW_OPT, '+ Vytvoriť výrobcu…']);
    return out;
  }
  function hwsSerOptions(manufacturer, current){
    if (hwsTaxLocked()) return hwsLockedOptions(current, '— bez rady');
    var m = hwsTrim(manufacturer);
    var out = [['', '— bez rady (voliteľná)']];
    hwsSeriesOf(m).forEach(function(s){ out.push([s, s]); });
    // Rada patri presne jednemu vyrobcovi (KOV-B1) — bez vybraneho vyrobcu
    // sa zalozit NEDA.
    if (m && m !== HWS_NEW_OPT && !hwsTax().write_blocked) out.push([HWS_NEW_OPT, '+ Vytvoriť radu…']);
    return out;
  }

  // AUTO-NAVRH NAZVU z klasifikacie (mockup `#msName`): „Výrobca · Rada ·
  // <popis klasifikácie>". Popis je to, co set ODLISUJE — pri zasuvke
  // KONSTRUKCIA (typ pouzitia uz hovori vyrobca+rada), inde typ pouzitia;
  // otvaranie sa pripaja, len ked sa naozaj uplatnuje.
  // Prepocitava sa LEN kym pouzivatel nazov neprepisal (`hwsApplyAutoName`).
  function hwsAutoName(d){
    var v = d || {};
    var parts = [];
    if (hwsTrim(v.manufacturer) && hwsTrim(v.manufacturer) !== HWS_NEW_OPT) parts.push(hwsTrim(v.manufacturer));
    if (hwsTrim(v.series) && hwsTrim(v.series) !== HWS_NEW_OPT) parts.push(hwsTrim(v.series));
    var ut = hwsTrim(v.use_type);
    if (ut === 'drawer' && hwsTrim(v.drawer_construction)){
      parts.push(hwsClassLabel('drawer_construction', v.drawer_construction));
    } else if (ut){
      parts.push(hwsClassLabel('use_type', ut));
    }
    var om = hwsTrim(v.opening_mode);
    if (om && om !== 'other') parts.push(hwsClassLabel('opening_mode', om));
    return parts.join(' · ');
  }
  // Nazov po zmene klasifikacie: rucne prepisany OSTAVA, inak sa prepocita.
  function hwsApplyAutoName(d, touched){
    var v = d || {};
    if (touched) return hwsTrim(v.name);
    return hwsAutoName(v) || hwsTrim(v.name);
  }

  // --- KOV-B3: CHIPY DLAZDICE ------------------------------------------------
  // Set bez klasifikacie je „nezaradený" (legacy) — a je to STAV, nie chyba:
  // spravá sa presne ako pred KOV-B1. Chip to hovori nahlas, aby sa naň dalo
  // kliknúť a doplniť ho.
  function hwsChips(set){
    var s = set || {};
    var out = [];
    if (hwsTrim(s.use_type)){
      out.push({ text: hwsClassLabel('use_type', s.use_type), cls: '' });
      if (hwsTrim(s.opening_mode)) out.push({ text: hwsClassLabel('opening_mode', s.opening_mode), cls: '' });
      if (hwsTrim(s.drawer_construction)){
        out.push({ text: hwsClassLabel('drawer_construction', s.drawer_construction), cls: '' });
      }
      if (hwsTrim(s.manufacturer)) out.push({ text: hwsTrim(s.manufacturer), cls: 'dim' });
      if (hwsTrim(s.series)) out.push({ text: hwsTrim(s.series), cls: 'dim' });
    } else {
      out.push({ text: 'nezaradený', cls: 'none' });
      out.push({ text: hwsTypeLabel(s.generic_type), cls: 'dim' });
    }
    if (s.active === false) out.push({ text: 'neaktívny', cls: 'off' });
    return out;
  }

  // --- KOV-B3: ZIVY NAHLAD ---------------------------------------------------
  // Text sklada SERVER (jeden vyklad nakupu) — klient ho len rozpada na
  // riadky a rozlisi hlavicku od ORANGE dovodu.
  function hwsPreviewLines(text){
    return String(text == null ? '' : text).split('\n').filter(function(l){ return l !== ''; })
      .map(function(l, i){
        if (l.charAt(0) === '!') return { text: l.slice(1).trim(), cls: 'warn' };
        return { text: l, cls: i === 0 ? 'head' : '' };
      });
  }
  // STARSIA odpoved nikdy neprepise novsiu: odpovede chodia asynchronne,
  // takze pomalsie kolo by inak prekreslilo nahlad spat na stary set.
  function hwsPreviewStale(gen, seen){
    return Number(gen || 0) < Number(seen || 0);
  }

  // STRUKTUROVANE chyby servera (`{row, field, msg}` zo `save_set!`) -> adresy
  // kostry D-15. Chyba CLENA nesie index riadku, takze pristane pri tom
  // clenovi (`members:<index>` = konvencia `data-nxm-row`); chyba CELEHO
  // zoznamu clenov nema pole, ktore by sa dalo ocervenit, takze ide do
  // zberneho pasu navrchu formulara.
  function hwsServerErrors(errors, fallback){
    var list = (errors || []).map(function(e){
      var row = (e && e.row != null) ? ('members:' + e.row) : null;
      var field = (e && e.field) ? String(e.field) : null;
      if (row) field = null;               // veta uz clena menuje
      if (field === 'members') field = null;
      return { row: row, field: field, msg: String((e && e.msg) || '') };
    }).filter(function(e){ return e.msg !== ''; });
    if (!list.length && fallback) list.push({ row: null, field: null, msg: String(fallback) });
    return list;
  }
  // Kluce rozpracovanych PROJEKTOVYCH pasiem (kluc = "<action>|<generic_type>").
  // Globalne drafty su viazane na kniznicu, nie na model — tie sa nezahadzuju.
  function hwsProjDraftKeys(keys){
    return (keys || []).filter(function(k){ return String(k).indexOf('hws-map-proj|') === 0; });
  }
  function hwsDropProjDrafts(){
    hwsProjDraftKeys(Object.keys(HWS_SEL)).forEach(function(k){ delete HWS_SEL[k]; });
  }
  // Selector mapovania (server tvar) -> stav editora pasiem; nie-selector = null.
  function hwsSelectorFrom(value){
    if (!value || typeof value !== 'object' || !value.bands) return null;
    return { param: value.param || '',
             rows: (value.bands || []).map(function(b){
               return { min: hwsNum(b.min), max: hwsNum(b.max), set_id: b.set_id || '' };
             }) };
  }
  // Stav editora -> hodnota mapovania pre server (tvar overi core parser).
  function hwsBuildSelector(state){
    return { param: hwsTrim(state && state.param), bands: hwsBuildBands(state && state.rows, 'set_id') };
  }

  // --- vstup zo servera ------------------------------------------------------

  // Top-level var = global v CEF (vzor MDH); ziadne window.* na module scope
  // (Node testy subor require-uju bez DOM).
  var HWSETS = {
    // ŠT-3a-3: kontrakt je ROZDELENY na „nastav data" a „kresli".
    //
    // V sekcii `hw` prichadzali sety DVAKRAT za sebou: `hwApplyState` volal
    // `HWSETS.init` (data + render) a hned za nim `hwRenderBody` volal
    // `hwsRenderAll` znova. Dva rendery = dvakrat zahodeny a znovu poskladany
    // zoznam setov aj predvolieb pri KAZDOM pushi (a s nim dvakrat strateny
    // fokus, kym ho nedrzal snapshot nizsie).
    //
    // `setData` je preto BEZ renderu — pouziva ho plny push, po ktorom telo
    // sekcie aj tak kresli `hwRenderBody`. `init` (data + render) ostava pre
    // ECHO, po ktorom uz ziadny render nepride (`NX.setHwSets` po odmietnutom
    // zapise) a pre okno, ktore by si render samo nevyziadalo.
    setData: function(data){
      var prev = HWS_DATA;
      HWS_DATA = data || null;
      // GH #132 P1: PREPNUTIE MODELU zahodi rozpracovane PROJEKTOVE pasma —
      // patrili inej zakazke a Ulozit by ich zapisalo do noveho projektu
      // (model_guid guard by presiel, GUID sa berie z CERSTVEHO payloadu).
      // Globalne (kniznicne) drafty na modeli nezavisia — tie ostavaju.
      if (prev && HWS_DATA && prev.model_guid !== HWS_DATA.model_guid) hwsDropProjDrafts();
    },
    render: function(){
      hwsRenderAll();
    },
    init: function(data){
      HWSETS.setData(data);
      // Rozpracovany MODAL setu NEZAHADZUJEME pri echu (vzor dirty buniek
      // okna Materialy) — zoznam a predvolby sa obnovia pod nim.
      hwsRenderAll();
    },
    // KOV-B3: vysledok zapisu SETU pre modal (vzor `MDH.itemResult`).
    // GH #127 P2 plati dalej: modal sa zatvara AZ pri USPESNOM ulozeni —
    // odmietnutie necha rozpisany navrh na doopravenie a len pusti zamok.
    setResult: function(ok, msg, errors, token, conflict){
      if (typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
      if (!HWS_SET) return;
      // Odpoved patriaca ZAVRETEMU oknu nesmie zavriet okno otvorene teraz
      // (vzor KOV-B2 review #290 P2).
      if (String(token == null ? '' : token) !== String(HWS_SET.token || '')){
        if (typeof console !== 'undefined' && console && console.warn){
          console.warn('HWSETS.setResult: odpoveď patrí inému odoslaniu — ignorujem.');
        }
        return;
      }
      HWS_SET.sent = false;
      HWS_SET.token = '';
      NXModal.setBusy(false);
      if (ok === true){
        if (typeof NXModal.clearMemory === 'function') NXModal.clearMemory(HWS_KEY_NEW);
        NXModal.close();
        hwsRenderSets();
        return;
      }
      if (conflict === true){
        // R-41: pripnuta revizia zachytila CUDZIU zmenu — draft ostava,
        // obnova je vedomy druhy klik (pas `hws-set-refresh`).
        HWS_SET.conflict = true;
        hwsSetRedraw(HWS_SET.draft, { conflict: true });
        return;
      }
      NXModal.showErrors(hwsServerErrors(errors, msg));
    },
    // KOV-B3: vysledok ZIVEHO NAHLADU. Staršia odpoveď NIKDY neprepíše
    // novšiu — poradie drzi generacia poziadavky, ktoru server len echuje.
    preview: function(data){
      var r = data || {};
      if (!HWS_SET) return;
      if (hwsPreviewStale(r.gen, HWS_SET.seen)) return;
      HWS_SET.seen = Number(r.gen || 0);
      HWS_SET.previewBusy = false;
      HWS_SET.preview = r;
      hwsPreviewRedraw();
    },
    // Echo zapisu do TAXONOMIE (`hw_tax_create_*`). Chodi aj vtedy, ked
    // zapis spustil modal POLOZKY — vtedy tu len obnovime zoznam, vybrat
    // novu hodnotu smie LEN okno, ktore o nu ziadalo (token).
    taxonomy: function(data){
      var r = data || {};
      if (HWS_DATA && r.taxonomy) HWS_DATA.taxonomy = r.taxonomy;
      if (typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
      if (!HWS_SET) return;
      if (String(r.token == null ? '' : r.token) !== String(HWS_SET.taxToken || '')) return;
      NXModal.setBusy(false);
      var op = (r.op === 'series') ? 'series' : 'manufacturer';
      HWS_SET.taxPending = null;
      HWS_SET.taxToken = '';
      if (r.ok !== true){
        NXModal.showErrors((r.errors || []).map(function(e){
          return { row: null,
                   field: (e && e.field === 'series') ? 'series_new' : 'manufacturer_new',
                   msg: String((e && e.msg) || 'zápis zlyhal') };
        }));
        return;
      }
      var d = hwsSetDraft(HWS_SET.draft || {}, { set_id: HWS_SET.set_id });
      if (op === 'manufacturer'){
        d.manufacturer = String(r.name || '');
        d.manufacturer_new = '';
        d.series = '';
        d.series_new = '';
      } else {
        d.series = String(r.name || '');
        d.series_new = '';
      }
      d.name = hwsApplyAutoName(d, HWS_SET.nameTouched);
      HWS_SET.draft = d;
      hwsSetRedraw(d);
    },
    // H1b: to iste pre editor pásiem výberu setu — server ho zavrie AŽ po
    // úspešnom zápise (echo kľúča editora); pri chybe ostane rozpísaný.
    mapSaved: function(key){
      if (key) delete HWS_SEL[key];
      hwsRenderProj();
    },
    // R-08 (review #258 kolo 2, P2): KONFLIKT revízie je jediný prípad, keď sa
    // rozpísaný editor pásiem ZAHODIŤ MUSÍ. Draft si revíziu PRIPÍNA pri
    // otvorení; keby po odmietnutí ostal otvorený, každý ďalší klik na
    // „Uložiť výber" by poslal tú istú zastaranú revíziu a konfliktoval by
    // donekonečna — hoci hláška tvrdí „obnovené, vyber znova". Zahodenie
    // draftu je zároveň jediné poctivé správanie: knižnica sa medzitým
    // zmenila, takže pásma poskladané nad starým stavom už nemusia dávať
    // zmysel (rovnaká logika ako `SS.saved()` pri konflikte Nastavení).
    mapConflict: function(key){
      if (key) delete HWS_SEL[key];
      hwsRenderProj();
    }
  };

  // ŠT-3a-2: `hwsSetTab` (prepinac tabov OKNA) zanikol — pohlady sekcie
  // (Polozky · Sety) riadi lista v `hw_catalog.js` (`hwSetView`).

  function hwsRenderAll(){
    hwsRenderSets();
    hwsRenderProj();
  }

  // --- ŠT-3a-3: FOKUS PREZIJE PREKRESLENIE -----------------------------------
  //
  // `hwsRenderSets` aj `hwsRenderProj` skladaju svoj blok od nuly
  // (`box.textContent = ''`). V OKNE to nevadilo — prekreslovalo sa len po
  // zapise; v SEKCII ich vola KAZDY `NX.setStudio`, takze pouzivatelovi mizol
  // kurzor z rozpisaneho editora pasiem uprostred pisania.
  // Vzor je `mdhRender` v `hw_catalog.js`: snapshot pred prekreslenim, obnova
  // po nom. Hodnoty poli sa NEOBNOVUJU — tie ziju v stave (`HWS_SEL`) a render
  // ich vykresli spravne sam.
  // KOV-B3: modalu setu sa to UZ NETYKA — zije v `#nxModalRoot` MIMO
  // prekresľovaného tela sekcie, takze ho push zo servera nezhodi vobec.

  // Kody a kluce su volny text (`hws-map-proj|hinge`) — do CSS selektora
  // VZDY cez escape (vzor `mdhCssEscape`; vlastny, lebo tento subor sa v Node
  // testoch nacitava samostatne).
  function hwsCssEscape(s){
    var v = String(s == null ? '' : s);
    if (typeof CSS !== 'undefined' && CSS.escape) return CSS.escape(v);
    return v.replace(/[^a-zA-Z0-9_-]/g, function(c){ return '\\' + c; });
  }

  // Atributy, ktore JEDNOZNACNE adresuju pole editora (index clena, riadku
  // radu/pasma a kluc rozpracovaneho vyberu setu).
  var HWS_FOCUS_ATTRS = ['data-hws-m', 'data-hws-s', 'data-hws-b', 'data-hws-sel'];

  function hwsFocusSnapshot(){
    if (typeof document === 'undefined') return null;
    var ae = document.activeElement;
    if (!ae || !ae.getAttribute || !ae.getAttribute('data-hws-field')) return null;

    var snap = { field: ae.getAttribute('data-hws-field'),
                 start: ae.selectionStart, end: ae.selectionEnd, at: {} };
    HWS_FOCUS_ATTRS.forEach(function(a){ snap.at[a] = ae.getAttribute(a); });
    return snap;
  }

  // Chybajuci atribut je SUCASTOU identity (`:not([...])`) — bez toho by sa
  // fokus z pola clena mohol vratit do rovnomenneho pola v riadku radu.
  function hwsFocusSelector(snap){
    var sel = '[data-hws-field="' + hwsCssEscape(snap.field) + '"]';
    HWS_FOCUS_ATTRS.forEach(function(a){
      sel += (snap.at[a] == null)
        ? ':not([' + a + '])'
        : '[' + a + '="' + hwsCssEscape(snap.at[a]) + '"]';
    });
    return sel;
  }

  function hwsRestoreFocus(box, snap){
    if (!snap || !box || !box.querySelector) return;
    var node = box.querySelector(hwsFocusSelector(snap));
    if (!node) return;
    try { node.focus(); } catch (e) { /* uzol medzitym zmizol */ }
    try { node.setSelectionRange(snap.start, snap.end); } catch (e2) { /* select nema range */ }
  }

  // --- tab SETY ---------------------------------------------------------------

  function hwsTypeLabel(gt){
    var list = (HWS_DATA && HWS_DATA.generic_types) || [];
    for (var i = 0; i < list.length; i++){ if (list[i].key === gt) return list[i].label; }
    return gt;
  }

  // Obal so snapshotom fokusu — telo ma viac vystupov (prazdna kniznica),
  // takze obnova patri SEM, nie na koniec tela.
  function hwsRenderSets(){
    var box = hwsEl('hwTabSets');
    if (!box || !HWS_DATA) return;
    var focus = hwsFocusSnapshot();
    hwsRenderSetsBody(box);
    hwsRestoreFocus(box, focus);
  }

  function hwsRenderSetsBody(box){
    box.textContent = '';
    var bar = hwsMk('div', 'mdbar');
    var nb = hwsMk('button', 'ghostbtn', '+ Nový set');
    nb.setAttribute('data-action', 'hws-new');
    bar.appendChild(nb);
    var hint = hwsMk('span', 'hint', 'Set = kódy, ktoré sa objednajú za 1 kus kovania. Zmena knižnice nemení staré zákazky (projekt drží kópiu).');
    bar.appendChild(hint);
    box.appendChild(bar);
    // R-07: nekompatibilná knižnica sa NEZOBRAZUJE (server posiela prázdny
    // zoznam) — vykreslený obsah by bol už orezaný o to, čomu táto verzia
    // nerozumie. Namiesto zavádzajúceho „Knižnica setov je prázdna." ide na
    // to isté miesto DÔVOD a všetky globálne mutácie sú vypnuté.
    if (hwsLibBlocked(HWS_DATA)){
      nb.disabled = true;
      box.appendChild(hwsMk('div', 'hwbanner', hwsLibReason(HWS_DATA) +
        '. Sety sa zatiaľ nedajú zobraziť ani meniť — predvoľby projektu nižšie fungujú ďalej.'));
      return;
    }
    // R-11: degradovaná knižnica sa ZOBRAZUJE (obsah zálohy je platný) —
    // vypnuté je len zakladanie a úprava setov, teda zápis do súboru.
    if (hwsLibDegraded(HWS_DATA)){
      nb.disabled = true;
      box.appendChild(hwsMk('div', 'hwbanner', hwsLibReason(HWS_DATA) +
        '. Sety vidíš a dajú sa použiť v projekte, ale meniť knižnicu sa zatiaľ nedá.'));
    }
    var sets = HWS_DATA.sets || [];
    if (!sets.length){
      box.appendChild(hwsMk('div', 'muted', 'Knižnica setov je prázdna.'));
      return;
    }
    var writeOff = hwsLibWriteBlocked(HWS_DATA); // R-11: degraded = len čítanie
    sets.forEach(function(s){ box.appendChild(hwsSetTile(s, writeOff)); });
  }

  // KOV-B3: DLAZDICA setu — nazov · chipy klasifikacie · akcie, pod tym
  // clenovia. Vertikalny priestor je vzacny, preto je to kompaktny riadok
  // s chipmi, nie karta na vysku.
  function hwsSetTile(s, writeOff){
    var card = hwsMk('div', 'hwsset' + (s.active === false ? ' off' : ''));
    var head = hwsMk('div', 'hwsset-head');
    head.appendChild(hwsMk('b', null, s.name));
    var eb = hwsMk('button', 'ghostbtn hwsbtn', 'Upraviť');
    eb.setAttribute('data-action', 'hws-edit');
    eb.setAttribute('data-set-id', s.set_id);
    if (writeOff) eb.disabled = true;
    head.appendChild(eb);
    var db = hwsMk('button', 'ghostbtn hwsbtn' + (HWS_DEL_ARM === s.set_id ? ' danger' : ''),
                   HWS_DEL_ARM === s.set_id ? 'Naozaj zmazať?' : 'Zmazať');
    db.setAttribute('data-action', 'hws-del');
    db.setAttribute('data-set-id', s.set_id);
    if (writeOff) db.disabled = true;
    head.appendChild(db);
    card.appendChild(head);
    var chips = hwsMk('div', 'hwsset-chips');
    hwsChips(s).forEach(function(c){
      chips.appendChild(hwsMk('span', 'hwschip' + (c.cls ? ' ' + c.cls : ''), c.text));
    });
    card.appendChild(chips);
    var ul = hwsMk('div', 'hwsset-members');
    (s.members || []).forEach(function(m){
      ul.appendChild(hwsMk('div', 'hwsset-m', hwsMemberSummary(m, HWS_DATA.params)));
    });
    card.appendChild(ul);
    return card;
  }

  // --- KOV-B3: ZOZNAM CLENOV V MODALI (pole `custom` kostry D-15) ------------
  //
  // Kostra vykresli hostitelsky uzol a zavola tento render; kliky vnutri neho
  // patria delegacii TOHTO suboru (`data-action`), zapisy do poli chodia cez
  // `hwsWriteField` do `HWS_SET.members` — presne ako v zaniknutom inline
  // editore, len o poschodie vyssie.
  function hwsMembersRender(host){
    if (!host) return;
    host.textContent = '';
    var members = (HWS_SET && HWS_SET.members) || [];
    if (!members.length){
      host.appendChild(hwsMk('div', 'mset-empty', 'Set zatiaľ nemá člena — bez neho sa neobjedná nič.'));
    }
    members.forEach(function(m, i){ host.appendChild(hwsMemberRow(m, i)); });
    var add = hwsMk('button', 'ghostbtn', '+ Pridať člena');
    add.setAttribute('data-action', 'hws-m-add');
    add.setAttribute('type', 'button');
    host.appendChild(add);
  }

  // Riadok clena: DVE OTAZKY navrchu („Ako sa určí kód?" + „Koľko?"), pod nimi
  // telo podla zvoleneho sposobu. `data-nxm-row` je konvencia kostry — chyba
  // servera s `row = "members:<index>"` pristane presne sem.
  function hwsMemberRow(m, i){
    var row = hwsMk('div', 'mset-m');
    row.setAttribute('data-nxm-row', i);
    var top = hwsMk('div', 'mset-mtop');
    top.appendChild(hwsSmallSelect('kind', hwsMemberKind(m), HWS_KINDS, i,
                                   'Ako sa určí kód?'));
    top.appendChild(hwsSmallSelect('per', m.per === 'owner' ? 'owner' : 'unit', HWS_PERS, i,
                                   'Koľko?'));
    var qty = hwsMk('input');
    qty.type = 'number'; qty.min = '1'; qty.max = '999';
    qty.value = m.qty || 1;
    qty.className = 'mset-qty';
    qty.title = 'Počet kusov';
    qty.setAttribute('data-hws-m', i);
    qty.setAttribute('data-hws-field', 'qty');
    top.appendChild(qty);
    var lbl = hwsMk('input');
    lbl.type = 'text'; lbl.value = m.label || '';
    lbl.className = 'mset-lbl';
    lbl.placeholder = 'popis (voliteľné)';
    lbl.setAttribute('data-hws-m', i);
    lbl.setAttribute('data-hws-field', 'label');
    top.appendChild(lbl);
    var del = hwsMk('button', 'ghostbtn mset-del', '×');
    del.setAttribute('type', 'button');
    del.setAttribute('data-action', 'hws-m-del');
    del.setAttribute('data-hws-m', i);
    del.title = 'Odobrať člena';
    top.appendChild(del);
    row.appendChild(top);
    row.appendChild(hwsMemberBody(m, i));
    return row;
  }

  function hwsSmallSelect(field, value, options, i, title){
    var sel = hwsMk('select');
    sel.title = title;
    sel.setAttribute('data-hws-m', i);
    sel.setAttribute('data-hws-field', field);
    options.forEach(function(o){
      var op = hwsMk('option', null, o[1]);
      op.value = o[0];
      if (String(o[0]) === String(value)) op.selected = true;
      sel.appendChild(op);
    });
    return sel;
  }

  function hwsMemberBody(m, i){
    var box = hwsMk('div', 'mset-mbody');
    if (m.is_series){
      (m.series || []).forEach(function(srow, j){
        var sr = hwsMk('div', 'hwsed-srow');
        var nl = hwsMk('input'); nl.type = 'text'; nl.value = srow.nl || '';
        nl.placeholder = 'NL'; nl.className = 'hwsed-band';
        nl.setAttribute('data-hws-m', i); nl.setAttribute('data-hws-s', j);
        nl.setAttribute('data-hws-field', 'nl');
        sr.appendChild(nl);
        sr.appendChild(hwsMk('span', null, '→'));
        var code = hwsMk('input'); code.type = 'text'; code.value = srow.code || '';
        code.placeholder = 'kód';
        code.setAttribute('data-hws-m', i); code.setAttribute('data-hws-s', j);
        code.setAttribute('data-hws-field', 'code');
        sr.appendChild(code);
        var del = hwsMk('button', 'ghostbtn hwsbtn', '×');
        del.setAttribute('type', 'button');
        del.setAttribute('data-action', 'hws-s-del');
        del.setAttribute('data-hws-m', i); del.setAttribute('data-hws-s', j);
        sr.appendChild(del);
        box.appendChild(sr);
      });
      var add = hwsMk('button', 'ghostbtn hwsbtn', '+ dĺžka');
      add.setAttribute('type', 'button');
      add.setAttribute('data-action', 'hws-s-add');
      add.setAttribute('data-hws-m', i);
      box.appendChild(add);
      return box;
    }
    if (m.is_bands){
      // H1b: kód podľa pásma parametra. Hranice sú UZAVRETÉ (min ≤ v ≤ max),
      // dotyk dvoch pásiem = prekryv → server zápis odmietne (all-or-nothing).
      box.appendChild(hwsParamSelect(m.param, i, null));
      (m.bands || []).forEach(function(brow, j){
        box.appendChild(hwsBandRow(brow, { m: i, b: j, valueField: 'code',
                                           placeholder: 'kód', delAction: 'hws-b-del' }));
      });
      var addb = hwsMk('button', 'ghostbtn hwsbtn', '+ pásmo');
      addb.setAttribute('type', 'button');
      addb.setAttribute('data-action', 'hws-b-add');
      addb.setAttribute('data-hws-m', i);
      box.appendChild(addb);
      box.appendChild(hwsMk('div', 'hint',
        'Hodnota mimo pásiem = ORANGE „doplň pásmo" — nikdy sa neberie najbližšie pásmo.'));
      return box;
    }
    var row = hwsMk('div', 'hwsed-srow');
    var code2 = hwsMk('input'); code2.type = 'text'; code2.value = m.code || '';
    code2.placeholder = 'Demos kód';
    code2.setAttribute('data-hws-m', i);
    code2.setAttribute('data-hws-field', 'code');
    row.appendChild(code2);
    box.appendChild(row);
    return box;
  }

  // --- KOV-B3: MODAL SETU (kostra D-15) --------------------------------------
  //
  // Poradie poli je poradie mockupu `#mSet` (1 → 6) a je KONTEXTOVE:
  //   1 použitie → 2 otváranie → 3 konštrukcia (LEN pri zásuvke)
  //   → 4 výrobca → 5 rada (závislá od výrobcu, VOLITEĽNÁ) → 6 názov.
  // `generic_type` je pri zaradenom sete ODVODENY NA SERVERI — select sa
  // ukaze LEN vtedy, ked ho nema co odvodit (nezaradeny set alebo „Iné").
  function hwsSetDraft(v, extra){
    var d = v || {};
    var out = { set_id: hwsTrim(d.set_id),
                use_type: hwsTrim(d.use_type),
                opening_mode: hwsTrim(d.opening_mode),
                drawer_construction: hwsTrim(d.drawer_construction),
                manufacturer: hwsTrim(d.manufacturer),
                manufacturer_new: hwsTrim(d.manufacturer_new),
                series: hwsTrim(d.series),
                series_new: hwsTrim(d.series_new),
                generic_type: hwsTrim(d.generic_type),
                name: String(d.name == null ? '' : d.name),
                active: d.active !== false };
    var e = extra || {};
    var k;
    for (k in e){ if (Object.prototype.hasOwnProperty.call(e, k)) out[k] = e[k]; }
    return out;
  }
  // Ulozeny set -> draft modalu. Legacy set (bez klasifikacie) sa otvara
  // s PRAZDNOU klasifikaciou — chip „nezaradený" hovori pravdu a doplnit sa
  // da len CELA (ALL-OR-NOTHING servera).
  function hwsSetDraftOf(set){
    var s = set || {};
    return hwsSetDraft({
      set_id: s.set_id, use_type: s.use_type, opening_mode: s.opening_mode,
      drawer_construction: s.drawer_construction, manufacturer: s.manufacturer,
      series: s.series, generic_type: s.generic_type, name: s.name,
      active: s.active !== false
    });
  }

  function hwsTypeOptions(){
    return ((HWS_DATA && HWS_DATA.generic_types) || []).map(function(t){
      return [String(t.key), String(t.label)];
    });
  }

  function hwsSetFields(d, opts){
    var v = d || {};
    var o = opts || {};
    var locked = hwsTaxLocked();
    var out = [];
    if (o.conflict){
      // R-41: cudzia zmena TOHO ISTEHO setu. Draft sa NEZAHADZUJE — obnova je
      // VEDOMY druhy klik, nie automatika (rozpisany set je praca navyse).
      out.push({ key: 'conflict', type: 'custom', render: hwsConflictRender });
    }
    out.push({ key: 'use_type', type: 'select', label: '1 · Použitie',
               options: hwsClassOptions('use_type', '— nezaradený —'),
               value: hwsTrim(v.use_type),
               hint: hwsTrim(v.use_type) ? undefined : 'set sa správa ako doteraz (bez zaradenia)' });
    out.push({ key: 'opening_mode', type: 'select', label: '2 · Otváranie',
               options: hwsClassOptions('opening_mode', '—'),
               value: hwsTrim(v.opening_mode) });
    if (hwsTrim(v.use_type) === 'drawer'){
      out.push({ key: 'drawer_construction', type: 'select', label: '3 · Konštrukcia',
                 options: hwsClassOptions('drawer_construction', '—'),
                 value: hwsTrim(v.drawer_construction) });
    }
    out.push({ key: 'manufacturer', type: 'select', label: '4 · Výrobca',
               options: hwsManOptions(v.manufacturer), value: hwsTrim(v.manufacturer),
               disabled: locked, hint: locked ? hwsTaxLockedReason() : undefined });
    if (hwsTrim(v.manufacturer) === HWS_NEW_OPT){
      // Vzor KOV-B2 (review #290 P1): zapis do TAXONOMIE spusta VYHRADNE toto
      // tlacidlo — nikdy `change`/blur (klik na „Zrušiť" vyvola blur skor nez
      // svoj vlastny klik a zruseny formular by stihol zalozit vyrobcu).
      out.push({ key: 'manufacturer_new', label: 'Názov nového výrobcu',
                 value: hwsTrim(v.manufacturer_new),
                 action: { act: 'hws-tax-create', key: 'manufacturer', label: 'Vytvoriť',
                           title: 'Pridá výrobcu do zoznamu (globálne, bez kroku Späť)' },
                 hint: 'pridá sa do zoznamu (globálne)' });
    }
    out.push({ key: 'series', type: 'select', label: '5 · Rada',
               options: hwsSerOptions(v.manufacturer, v.series), value: hwsTrim(v.series),
               disabled: locked, hint: 'voliteľná — podperky ani klzáky radu nemajú' });
    if (hwsTrim(v.series) === HWS_NEW_OPT){
      out.push({ key: 'series_new', label: 'Názov novej rady',
                 value: hwsTrim(v.series_new),
                 action: { act: 'hws-tax-create', key: 'series', label: 'Vytvoriť',
                           title: 'Pridá radu k výrobcovi vyššie (globálne, bez kroku Späť)' },
                 hint: 'priradí sa výrobcovi vyššie' });
    }
    // Typ kovania: pri zaradenom sete ho ODVODZUJE SERVER — pytat sa nan
    // druhykrat by znamenalo dva protirecive zapisy o tom istom sete.
    if (hwsNeedsType(v)){
      out.push({ key: 'generic_type', type: 'select', label: 'Typ kovania',
                 options: hwsTypeOptions(), value: hwsTrim(v.generic_type),
                 disabled: o.edit === true,
                 hint: o.edit ? 'typ existujúceho setu sa nemení' : undefined });
    }
    out.push({ key: 'name', label: '6 · Názov setu', value: String(v.name == null ? '' : v.name),
               hint: 'navrhnutý z klasifikácie — môžeš prepísať' });
    out.push({ key: 'active', type: 'checkbox', label: 'Aktívny', value: v.active !== false,
               hint: 'neaktívny sa už neponúka ako nový výber' });
    out.push({ key: 'members', type: 'custom', label: '7 · Členovia setu',
               value: (HWS_SET && HWS_SET.members) || [],
               render: function(host){ hwsMembersRender(host); },
               read: function(){ return (HWS_SET && HWS_SET.members) || []; } });
    out.push({ key: 'preview', type: 'custom', label: 'Náhľad expanzie',
               render: function(host){ hwsPreviewRender(host); } });
    return out;
  }

  function hwsSetSpec(d, opts){
    var o = opts || {};
    return {
      trigger: o.trigger,
      title: o.edit ? 'Upraviť set kovania' : 'Nový set kovania',
      sub: o.edit ? ('Identita ' + hwsTrim(d.set_id)) : 'klasifikácia → členovia → náhľad',
      size: 'wide',
      okLabel: o.edit ? 'Uložiť' : 'Uložiť set',
      // Konvencia kluca `<okno/domena>:<mode>[:<ciel>]`. UPRAVA pamat NEMA
      // (vzor D-69 a KOV-B2): predvyplnit editor cudzieho setu hodnotami
      // pisanymi do ineho by bola ticha zamena zaznamu.
      memoryKey: o.edit ? null : HWS_KEY_NEW,
      fields: hwsSetFields(d, o),
      onSubmit: function(vals){ hwsSetSubmit(vals); },
      onClose: function(){ hwsSetClosed(); }
    };
  }

  // Otvorenie modalu. `set` = ulozeny set (uprava) alebo null (novy).
  function hwsSetOpen(set, draft, opts){
    if (typeof NXModal === 'undefined' || !NXModal || typeof NXModal.open !== 'function') return;
    var o = opts || {};
    var edit = !!set;
    var d = draft || (edit ? hwsSetDraftOf(set) : hwsSetDraft({ active: true }));
    var keep = (o.keep && HWS_SET) ? HWS_SET : null;
    var members = o.members || (keep ? keep.members : (edit ? hwsMembersOf(set) : []));
    // R-41: revizia a ZAKLADNA definicia sa PRIPINAJU pri OTVORENI a prezivaju
    // kazdy push. Vnutorne prekreslenie (zmena vyrobcu, konflikt) ich NESMIE
    // omladit — inak by guard servera prešiel nad stavom, ktorý používateľ
    // nikdy nevidel (presne to bola R-41).
    var rev = keep ? keep.rev : hwsCurrentRev();
    var base = keep ? keep.base : (edit ? set : null);
    if (o.dropMemory && typeof NXModal.clearMemory === 'function') NXModal.clearMemory(HWS_KEY_NEW);
    var trigger = o.trigger || (keep ? keep.trigger : null) ||
      (typeof document !== 'undefined' ? document.activeElement : null);
    // Stav MUSI stat pred `open` — render vlastneho pola (`members`,
    // `preview`) bezi uz vnutri neho a cita `HWS_SET`.
    HWS_SET = { edit: edit, set_id: hwsTrim(d.set_id), draft: d, members: members,
                rev: rev, base: base, trigger: trigger,
                nameTouched: keep ? keep.nameTouched : !!(edit && hwsTrim(d.name)),
                conflict: !!o.conflict, sent: false, token: '',
                taxPending: null, taxToken: '',
                gen: keep ? keep.gen : 0, seen: keep ? keep.seen : 0,
                sample: (keep && keep.sample) || hwsSampleDefault(),
                preview: keep ? keep.preview : null, previewBusy: false, timer: null };
    HWS_REOPEN = true;
    try {
      NXModal.open(hwsSetSpec(d, { edit: edit, trigger: trigger, conflict: !!o.conflict }));
    } finally {
      HWS_REOPEN = false;
    }
    // `open` najprv ZATVARA predchadzajuci modal a jeho `onClose` by cerstvy
    // stav vynuloval — preto sa tu stav este raz potvrdzuje.
    if (!HWS_SET) return;
    hwsPreviewSchedule(0);
  }

  // VNUTORNE prekreslenie (zmena kontextu poli, konflikt) — NIE JE zatvorenie:
  // drzi si PRIPNUTU reviziu, zakladnu definiciu, clenov aj spustac.
  function hwsSetRedraw(d, over){
    if (!HWS_SET) return;
    var o = over || {};
    var edit = HWS_SET.edit;
    var stored = edit ? hwsSetById(HWS_SET.set_id) : null;
    hwsSetOpen(edit ? (stored || HWS_SET.base) : null, d,
               { keep: true, dropMemory: true, edit: edit,
                 conflict: o.conflict === undefined ? HWS_SET.conflict : o.conflict });
  }

  function hwsSetById(sid){
    return ((HWS_DATA && HWS_DATA.sets) || []).filter(function(x){ return x.set_id === sid; })[0] || null;
  }

  function hwsSetClosed(){
    if (HWS_REOPEN) return; // prekreslenie modalu nie je jeho zatvorenie
    if (HWS_SET && HWS_SET.timer && typeof clearTimeout === 'function') clearTimeout(HWS_SET.timer);
    HWS_SET = null;
  }

  function hwsSetArm(){
    HWS_TOKEN_SEQ += 1;
    var t = 'hws' + HWS_TOKEN_SEQ + '-' + Date.now();
    if (HWS_SET){ HWS_SET.sent = true; HWS_SET.token = t; }
    return t;
  }

  // Zmena klasifikacie meni SADU POLI (konstrukcia len pri zasuvke, zavisla
  // rada, pole „+ Vytvoriť…", explicitny typ pri „Iné") — kostra D-15 ju za
  // behu nevymiena, takze modal sa otvori znova s tym, CO UZ POUZIVATEL
  // NAPISAL (vzor `hwItemCtxSwitch`).
  function hwsSetCtxSwitch(changedKey){
    if (!HWS_SET || typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
    if (NXModal.isBusy && NXModal.isBusy()) return; // bezi zapis — nesahat
    var d = hwsSetDraft(NXModal.values(), { set_id: HWS_SET.set_id });
    if (changedKey === 'manufacturer'){
      // Rada patri presne jednemu vyrobcovi — po zmene vyrobcu uz vybrana
      // rada platit nemusi.
      if (d.series !== HWS_NEW_OPT && hwsSeriesOf(d.manufacturer).indexOf(d.series) < 0) d.series = '';
      d.series_new = '';
    }
    if (changedKey === 'use_type' && d.use_type !== 'drawer') d.drawer_construction = '';
    d.name = hwsApplyAutoName(d, HWS_SET.nameTouched);
    HWS_SET.draft = d;
    hwsSetRedraw(d);
  }

  // Odoslanie setu. „+ Vytvoriť…" NIE JE hodnota setu — je to zapis do
  // taxonomie; set sa pritom NEUKLADA (pouzivatel ho ulozi druhym klikom).
  function hwsSetSubmit(v){
    if (!HWS_SET){ NXModal.setBusy(false); return; }
    var d = hwsSetDraft(v, { set_id: HWS_SET.set_id });
    HWS_SET.draft = d;
    if (d.manufacturer === HWS_NEW_OPT || d.series === HWS_NEW_OPT){
      hwsTaxCreate(d);
      return;
    }
    var errs = hwsSetValidate(d);
    if (errs.length){ NXModal.showErrors(errs); NXModal.setBusy(false); return; }
    NXModal.clearErrors();
    // Identitu NOVEHO setu urcuje slug z nazvu (server odmietne koliziu).
    if (!HWS_SET.edit) HWS_SET.set_id = hwsSlug(d.name);
    d.set_id = HWS_SET.set_id;
    hwsSend('hws_save_set', { set: hwsBuildSetPayload(d, HWS_SET.members),
                              // R-41: PRIPNUTA revizia z chvile otvorenia —
                              // NIKDY `HWS_DATA.revision` z posledneho pushu.
                              revision: HWS_SET.rev || '',
                              create: !HWS_SET.edit,
                              token: hwsSetArm() });
  }

  // Klient strazi LEN to, co server odmietne bez uzitocnej vety. AUTORITA
  // validacie (klasifikacia, XOR clena, pasma, taxonomia) je SERVER.
  function hwsSetValidate(d){
    var out = [];
    if (hwsBlank(d.name)) out.push({ row: null, field: 'name', msg: 'Názov je povinný.' });
    return out;
  }

  // Zalozenie vyrobcu/rady z modalu setu — ta ista cesta ako v modale polozky
  // (`hw_tax_create_*`). Taxonomia je GLOBALNY subor bez kroku Späť, bez
  // premenovania a bez mazania, takze zapis robi VYHRADNE vyslovny pokyn.
  function hwsTaxCreate(v, forced){
    var d = v || {};
    var op = (forced === 'manufacturer' || forced === 'series')
      ? forced
      : ((hwsTrim(d.manufacturer) === HWS_NEW_OPT) ? 'manufacturer' : 'series');
    var key = op + '_new';
    var name = hwsTrim(d[key]);
    if (!name){
      NXModal.showErrors([{ row: null, field: key,
                            msg: op === 'manufacturer' ? 'Doplň názov nového výrobcu.'
                                                       : 'Doplň názov novej rady.' }]);
      NXModal.setBusy(false);
      return;
    }
    NXModal.clearErrors();
    HWS_TOKEN_SEQ += 1;
    var token = 'hwstax' + HWS_TOKEN_SEQ + '-' + Date.now();
    HWS_SET.draft = hwsSetDraft(d, { set_id: HWS_SET.set_id });
    HWS_SET.taxPending = op;
    HWS_SET.taxToken = token;
    if (op === 'manufacturer'){
      hwsSend('hw_tax_create_manufacturer', { name: name, token: token });
    } else {
      hwsSend('hw_tax_create_series', { name: name, token: token,
                                        manufacturer: hwsTrim(d.manufacturer) });
    }
  }

  // --- KOV-B3: ZIVY NAHLAD ---------------------------------------------------

  function hwsSampleDefault(){
    var s = (HWS_DATA && HWS_DATA.preview_sample) || {};
    var out = {};
    var k;
    for (k in s){ if (Object.prototype.hasOwnProperty.call(s, k)) out[k] = s[k]; }
    return out;
  }

  // Debounce pri pisani: kazdy znak by inak poslal vlastnu poziadavku.
  function hwsPreviewSchedule(ms){
    if (!HWS_SET || typeof setTimeout !== 'function') return;
    if (HWS_SET.timer && typeof clearTimeout === 'function') clearTimeout(HWS_SET.timer);
    HWS_SET.timer = setTimeout(hwsPreviewSend, ms === undefined ? HWS_PREVIEW_MS : ms);
  }

  function hwsPreviewSend(){
    if (!HWS_SET) return;
    HWS_SET.timer = null;
    HWS_SET.gen += 1;
    HWS_SET.previewBusy = true;
    hwsPreviewRedraw();
    var d = HWS_SET.draft || {};
    var payload = hwsBuildSetPayload(d, HWS_SET.members);
    // Nahlad potrebuje IDENTITU (validacia ju vyzaduje) — pri novom sete ju
    // este nikto nezadal, takze sa odvodi z nazvu rovnako ako pri ulozeni.
    if (!hwsTrim(payload.set_id)) payload.set_id = hwsSlug(d.name);
    hwsSend('hws_preview', { set: payload, gen: HWS_SET.gen, sample: HWS_SET.sample });
  }

  function hwsPreviewRedraw(){
    if (typeof NXModal === 'undefined' || !NXModal || typeof NXModal.redrawCustom !== 'function') return;
    if (!NXModal.isOpen || !NXModal.isOpen()) return;
    NXModal.redrawCustom('preview');
  }

  function hwsPreviewRender(host){
    if (!host) return;
    host.textContent = '';
    var box = hwsMk('div', 'mset-prev');
    var st = HWS_SET || {};
    if (hwsUsesNl(st.members)){
      var row = hwsMk('div', 'hwsed-srow');
      row.appendChild(hwsMk('span', 'hwsed-mlbl', 'Vzorová NL'));
      var inp = hwsMk('input');
      inp.type = 'text'; inp.className = 'hwsed-band';
      inp.value = hwsNum((st.sample || {}).nominal_length);
      inp.setAttribute('data-hws-sample', 'nominal_length');
      row.appendChild(inp);
      row.appendChild(hwsMk('span', 'hwsed-mlbl', 'mm'));
      box.appendChild(row);
    }
    if (st.previewBusy){
      box.appendChild(hwsMk('div', 'mset-prevbusy', 'Počítam náhľad…'));
    } else if (st.preview && st.preview.ok){
      hwsPreviewLines(st.preview.text).forEach(function(l){
        box.appendChild(hwsMk('div', 'mset-prevline' + (l.cls ? ' ' + l.cls : ''), l.text));
      });
    } else if (st.preview){
      box.appendChild(hwsMk('div', 'mset-preverr',
        'Náhľad sa zatiaľ nedá spočítať — doplň chýbajúce údaje vyššie.'));
    } else {
      box.appendChild(hwsMk('div', 'mset-preverr', 'Náhľad sa spočíta, keď set dostane člena.'));
    }
    host.appendChild(box);
  }

  function hwsUsesNl(members){
    return (members || []).some(function(m){ return !!(m && m.is_series); });
  }

  // Konfliktny pas (R-41): hlaska + VEDOMY druhy klik na obnovu.
  function hwsConflictRender(host){
    if (!host) return;
    host.textContent = '';
    var box = hwsMk('div', 'mset-conf');
    box.appendChild(hwsMk('div', null,
      'Set medzitým zmenil niekto iný. Tvoje zmeny sú stále tu — ulož ich znova, ' +
      'alebo si načítaj aktuálny set (tvoje zmeny sa pritom zahodia).'));
    var btn = hwsMk('button', 'ghostbtn mset-confbtn', 'Obnoviť — načítať aktuálny set');
    btn.setAttribute('type', 'button');
    btn.setAttribute('data-action', 'hws-set-refresh');
    box.appendChild(btn);
    host.appendChild(box);
  }

  // --- zdielane prvky pásiem (člen setu aj výber setu) ------------------------

  // Select parametra pásiem. mi = index člena (editor setu) ALEBO selKey =
  // kľúč rozpracovaného výberu setu (mapovanie) — vždy práve jedno z nich.
  function hwsParamSelect(param, mi, selKey){
    var wrap = hwsMk('div', 'hwsed-srow');
    wrap.appendChild(hwsMk('span', 'hwsed-mlbl', 'Podľa'));
    var sel = hwsMk('select');
    if (selKey != null) sel.setAttribute('data-hws-sel', selKey);
    if (mi != null) sel.setAttribute('data-hws-m', mi);
    sel.setAttribute('data-hws-field', 'param');
    ((HWS_DATA && HWS_DATA.params) || []).forEach(function(p){
      var o = hwsMk('option', null, p.label);
      o.value = p.key;
      if (p.key === param) o.selected = true;
      sel.appendChild(o);
    });
    wrap.appendChild(sel);
    return wrap;
  }

  function hwsBandAttrs(node, o, field){
    if (o.sel != null) node.setAttribute('data-hws-sel', o.sel);
    if (o.m != null) node.setAttribute('data-hws-m', o.m);
    node.setAttribute('data-hws-b', o.b);
    if (field) node.setAttribute('data-hws-field', field);
  }

  // Riadok pásma „[od] – [do] → [hodnota] ×". Hodnota = kód (člen setu) alebo
  // select zo setov daného typu (výber setu podľa parametra).
  function hwsBandRow(brow, o){
    var r = hwsMk('div', 'hwsed-srow');
    var mn = hwsMk('input');
    mn.type = 'text'; mn.value = brow.min == null ? '' : brow.min;
    mn.placeholder = 'od'; mn.className = 'hwsed-band';
    hwsBandAttrs(mn, o, 'min');
    r.appendChild(mn);
    r.appendChild(hwsMk('span', null, '–'));
    var mx = hwsMk('input');
    mx.type = 'text'; mx.value = brow.max == null ? '' : brow.max;
    mx.placeholder = 'do'; mx.className = 'hwsed-band';
    hwsBandAttrs(mx, o, 'max');
    r.appendChild(mx);
    r.appendChild(hwsMk('span', null, '→'));
    var cur = brow[o.valueField] || '';
    var val;
    if (o.setOptions){
      val = hwsMk('select');
      var none = hwsMk('option', null, '— vyber set —');
      none.value = '';
      val.appendChild(none);
      var found = false;
      o.setOptions.forEach(function(s){
        var op = hwsMk('option', null, s.name);
        op.value = s.set_id;
        if (s.set_id === cur){ op.selected = true; found = true; }
        val.appendChild(op);
      });
      if (cur && !found){ // set zmizol z knižnice — riadok nesmie klamať
        var miss = hwsMk('option', null, cur + ' (chýba)');
        miss.value = cur; miss.selected = true;
        val.appendChild(miss);
      }
    } else {
      val = hwsMk('input');
      val.type = 'text'; val.value = cur; val.placeholder = o.placeholder || '';
    }
    hwsBandAttrs(val, o, o.valueField);
    r.appendChild(val);
    var del = hwsMk('button', 'ghostbtn hwsbtn', '×');
    del.setAttribute('data-action', o.delAction);
    hwsBandAttrs(del, o, null);
    r.appendChild(del);
    return r;
  }

  // --- tab PREDVOLBY PROJEKTU ---------------------------------------------------

  // ŠT-3a-2: `hwsMappingValueText` (citatelna hodnota mapovania BEZ
  // ovladaca) zanikla spolu s read-only rezimom — predvolby projektu su
  // v sekcii plnohodnotne editovatelne, takze riadok kresli select.

  // Ten isty obal pre PREDVOĽBY PROJEKTU: editor pasiem vyberu setu zije tu
  // a `hwsRenderAll` ho prekresluje pri kazdom pushi rovnako ako zoznam setov.
  function hwsRenderProj(){
    var box = hwsEl('hwTabProj');
    if (!box || !HWS_DATA) return;
    var focus = hwsFocusSnapshot();
    hwsRenderProjBody(box);
    hwsRestoreFocus(box, focus);
  }

  function hwsRenderProjBody(box){
    box.textContent = '';
    var proj = HWS_DATA.project || {};
    // Hlavička tabu: model + doplnenie nových predvolieb v JEDNOM rade.
    var head = hwsMk('div', 'hwsproj-head');
    head.appendChild(hwsMk('div', 'hwsproj-title', 'Model: ' + (HWS_DATA.model_title || '—')));
    var mb = hwsMk('button', 'ghostbtn', 'Doplniť nové predvoľby');
    mb.setAttribute('data-action', 'hws-merge-seed');
    mb.title = 'Doplní do projektu globálne predvoľby, ktoré tu ešte nie sú (napr. nový typ kovania). Existujúce výbery nechá tak.';
    // R-07: doplnenie aj obnova KOPÍRUJÚ globálne definície do .skp — z
    // nekompatibilnej knižnice sa nerobia.
    var libBlocked = hwsLibBlocked(HWS_DATA);
    if (libBlocked) mb.disabled = true;
    head.appendChild(mb);
    box.appendChild(head);
    if (proj.status === 'invalid'){
      var ban = hwsMk('div', 'hwbanner',
        'Predvoľby setov v tomto projekte sú poškodené — súpis kovania sa nemapuje. ');
      var rb = hwsMk('button', 'ghostbtn', 'Obnoviť z globálnych predvolieb');
      rb.setAttribute('data-action', 'hws-reset-proj');
      if (libBlocked) rb.disabled = true;
      ban.appendChild(rb);
      if (libBlocked) box.appendChild(hwsMk('div', 'hwbanner', hwsLibReason(HWS_DATA) + '.'));
      box.appendChild(ban);
      return;
    }
    if (proj.status === 'missing'){
      // Bez snapshotu je jediným zdrojom globálna knižnica — keď sa nesmie
      // použiť, kovanie sa NENAMAPUJE (ORANGE v Kontrole aj v súpise) a výber
      // tu nemá z čoho stavať. Radšej to povedať rovno než ponúkať prázdny select.
      if (libBlocked){
        box.appendChild(hwsMk('div', 'hwbanner', hwsLibReason(HWS_DATA) +
          '. Projekt vlastné predvoľby ešte nemá, takže sa kovanie nenamapuje — v súpise bude oranžové.'));
        return;
      }
      box.appendChild(hwsMk('div', 'hint',
        'Projekt zatiaľ preberá globálne predvoľby — zmrazia sa doň pri prvej stavbe skrinky alebo prvej zmene tu.'));
    }
    var mapping = proj.status === 'ok' ? (proj.mapping || {}) : (HWS_DATA.global_mapping || {});
    // GH #127 P2 + H1b (audit BLOCKER 1): ponuku per typ sklada SERVER
    // (type_options) — pre set, ktory projekt uz pouziva, ukazuje nazov zo
    // SNAPSHOTU (podla neho sa nakupuje), nie neskor premenovany global.
    box.appendChild(hwsMappingTable(mapping, 'hws-map-proj', hwsProjOptions));

    // Globalne defaulty novych projektov — zbalene (vertikalny priestor).
    var det = document.createElement('details');
    det.open = HWS_GLOBAL_OPEN; // prerender (napr. + pásmo) nesmie zavrieť sekciu
    det.setAttribute('data-hws-det', 'global');
    det.appendChild(hwsMk('summary', null, 'Predvoľby nových projektov (globálne)'));
    // R-11: globálna predvoľba je ZÁPIS do knižnice — degradovaná knižnica ju
    // nepustí rovnako ako nekompatibilná (projektové predvoľby vyššie bežia).
    if (hwsLibWriteBlocked(HWS_DATA)){
      det.appendChild(hwsMk('div', 'hwbanner', hwsLibReason(HWS_DATA) +
        '. Globálne predvoľby sa zatiaľ nedajú meniť.'));
    } else {
      det.appendChild(hwsMappingTable(HWS_DATA.global_mapping || {}, 'hws-map-global', hwsGlobalOptions));
    }
    box.appendChild(det);
  }

  // Ponuka setov typu: projekt = server (snapshot > global, „(kópia projektu)"
  // pri sete, ktorý knižnica už nemá), globálne predvoľby = knižnica.
  function hwsProjOptions(gt){
    var list = ((HWS_DATA && HWS_DATA.type_options) || {})[gt] || [];
    return list.map(function(s){
      return { set_id: s.set_id, name: s.name + (s.project_copy ? ' (kópia projektu)' : '') };
    });
  }
  // KOV-B3: NEAKTIVNY set sa uz NENUKA ako novy default — ani v globalnej
  // tabulke. Ponuku PROJEKTU filtruje server (`HardwareSets.set_options`),
  // tu je to ta ista myslienka nad globalnym mapovanim: set, ktory sa
  // AKTUALNE pouziva, v ponuke OSTAVA (inak by select ukazoval prazdno tam,
  // kde hodnota je, a prvy klik vedla by ju ticho prepisal).
  function hwsGlobalRefs(gt){
    var v = ((HWS_DATA && HWS_DATA.global_mapping) || {})[gt];
    if (typeof v === 'string') return [v];
    if (hwsIsSelector(v)) return (v.bands || []).map(function(b){ return String(b.set_id || ''); });
    return [];
  }
  function hwsGlobalOptions(gt){
    var refs = hwsGlobalRefs(gt);
    return hwsSetsForType(HWS_DATA && HWS_DATA.sets, gt)
      .filter(function(s){ return s.active !== false || refs.indexOf(s.set_id) >= 0; })
      .map(function(s){ return { set_id: s.set_id, name: s.name }; });
  }
  function hwsSelKey(action, gt){ return action + '|' + gt; }
  function hwsDefaultParam(gt){
    if (gt === 'slide') return 'front_height'; // bočnice sa vyberajú podľa výšky čela
    var list = (HWS_DATA && HWS_DATA.params) || [];
    return list.length ? list[0].key : 'height';
  }

  function hwsMappingTable(mapping, action, optionsFor){
    var t = hwsMk('div', 'hwsmap');
    ((HWS_DATA && HWS_DATA.generic_types) || []).forEach(function(gt){
      var opts = optionsFor(gt.key);
      var value = mapping[gt.key];
      var key = hwsSelKey(action, gt.key);
      var edit = HWS_SEL[key] || null;
      if (!opts.length && !value) return; // typ bez setov nezobrazuj
      var row = hwsMk('div', 'hwsmap-row');
      row.appendChild(hwsMk('label', null, gt.label));
      row.appendChild(hwsMapSelect(gt.key, action, key, value, opts, edit));
      t.appendChild(row);
      if (edit){
        t.appendChild(hwsSelectorEditor(key, gt.key, action, opts, edit));
      } else if (hwsIsSelector(value)){
        t.appendChild(hwsSelectorSummaryRow(key, value, opts));
      }
    });
    return t;
  }

  function hwsIsSelector(v){ return !!(v && typeof v === 'object' && v.bands); }

  // Select mapovania: „bez setu" + sety typu + POSLEDNÁ voľba „podľa
  // parametra…" (otvorí editor pásiem; na server sa nikdy neposiela).
  function hwsMapSelect(gt, action, key, value, opts, edit){
    var sel = hwsMk('select');
    sel.setAttribute('data-action-change', action);
    sel.setAttribute('data-hws-gt', gt);
    sel.setAttribute('data-hws-key', key);
    var byParam = !!edit || hwsIsSelector(value);
    var none = hwsMk('option', null, '— bez setu (ORANGE)');
    none.value = '';
    none.selected = !byParam && !value;
    sel.appendChild(none);
    opts.forEach(function(s){
      var o = hwsMk('option', null, s.name);
      o.value = s.set_id;
      if (!byParam && value === s.set_id) o.selected = true;
      sel.appendChild(o);
    });
    var po = hwsMk('option', null, byParam
      ? hwsParamLabel(edit ? edit.param : value.param, HWS_DATA && HWS_DATA.params)
      : 'nastaviť podľa parametra…');
    po.value = HWS_PARAM_OPT;
    po.selected = byParam;
    sel.appendChild(po);
    return sel;
  }

  // Zavretý výber podľa parametra — čitateľný prehľad pásiem + „Upraviť".
  function hwsSelectorSummaryRow(key, value, opts){
    var names = {};
    (opts || []).forEach(function(s){ names[s.set_id] = s.name; });
    var box = hwsMk('div', 'hwssel-sum');
    box.appendChild(hwsMk('span', null, hwsBandsSummary(value.bands, 'set_id', names)));
    var eb = hwsMk('button', 'ghostbtn hwsbtn', 'Upraviť pásma');
    eb.setAttribute('data-action', 'hws-sel-edit');
    eb.setAttribute('data-hws-key', key);
    box.appendChild(eb);
    return box;
  }

  // Editor výberu setu podľa parametra (automatika bočníc podľa výšky čela).
  function hwsSelectorEditor(key, gt, action, opts, state){
    var box = hwsMk('div', 'hwssel');
    box.appendChild(hwsParamSelect(state.param, null, key));
    (state.rows || []).forEach(function(r, j){
      box.appendChild(hwsBandRow(r, { sel: key, b: j, valueField: 'set_id',
                                      setOptions: opts, delAction: 'hws-sb-del' }));
    });
    var add = hwsMk('button', 'ghostbtn hwsbtn', '+ pásmo');
    add.setAttribute('data-action', 'hws-sb-add');
    add.setAttribute('data-hws-key', key);
    box.appendChild(add);
    var save = hwsMk('button', 'primary', 'Uložiť výber');
    save.setAttribute('data-action', 'hws-sel-save');
    save.setAttribute('data-hws-key', key);
    save.setAttribute('data-hws-gt', gt);
    save.setAttribute('data-hws-act', action);
    box.appendChild(save);
    var cancel = hwsMk('button', 'ghostbtn', 'Zrušiť');
    cancel.setAttribute('data-action', 'hws-sel-cancel');
    cancel.setAttribute('data-hws-key', key);
    box.appendChild(cancel);
    box.appendChild(hwsMk('div', 'hint',
      'Hodnota mimo pásiem = ORANGE „doplň pásmo" — nikdy sa neberie najbližšie pásmo. Pásma sa nesmú prekrývať (aj dotyk je prekryv).'));
    return box;
  }

  // --- delegacia ------------------------------------------------------------------

  function hwsMember(i){ return (HWS_SET && HWS_SET.members && HWS_SET.members[i]) || null; }

  // Zmena v ZOZNAME CLENOV: prekresli sa LEN vlastny uzol modalu (nie cely
  // modal — prekreslenie karty by zahodilo fokus) a prepocita sa nahlad.
  function hwsMembersChanged(){
    if (!HWS_SET) return;
    if (typeof NXModal !== 'undefined' && NXModal && typeof NXModal.redrawCustom === 'function'){
      NXModal.redrawCustom('members');
    }
    hwsPreviewSchedule(0);
  }

  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('click', function(ev){
      var t = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
      if (t){
        var a = t.getAttribute('data-action');
        // R-07: druhá poistka k `disabled` — akcie, ktoré MENIA globálnu
        // knižnicu alebo z nej kopírujú do .skp, sa pri nekompatibilnej
        // knižnici nesmú odoslať ani zo zastaraného DOM-u (server ich aj tak
        // odmietne, ale používateľ by dostal zbytočnú chybovú hlášku).
        if (hwsLibBlocked(HWS_DATA) && HWS_LIB_ACTIONS.indexOf(a) !== -1) return;
        // R-11: degradovaná knižnica sa SMIE používať (doplnenie predvolieb
        // aj obnova z globálu bežia ďalej) — zastavia sa len ZÁPISY do súboru.
        if (hwsLibDegraded(HWS_DATA) && HWS_WRITE_ACTIONS.indexOf(a) !== -1) return;
        if (a === 'hws-new'){
          hwsSetOpen(null, null, { trigger: t,
                                   members: [hwsMemberBlank('code', 'hinge')] });
          return;
        }
        if (a === 'hws-edit'){
          var sid = t.getAttribute('data-set-id');
          var s = hwsSetById(sid);
          if (s) hwsSetOpen(s, null, { trigger: t });
          return;
        }
        // R-41: VEDOMA obnova po konflikte — cerstvy set nahradi polia AZ TU,
        // teda az na druhy, vyslovny klik. Draft sa nikdy nezahadzuje sam.
        if (a === 'hws-set-refresh'){
          if (HWS_SET && HWS_SET.edit){
            var fresh = hwsSetById(HWS_SET.set_id);
            var keepTrigger = HWS_SET.trigger;
            HWS_SET = null; // obnova zahadza PRIPNUTU reviziu aj stary draft
            if (fresh) hwsSetOpen(fresh, null, { trigger: keepTrigger, dropMemory: true });
          }
          return;
        }
        // „+ Vytvoriť výrobcu/radu" z modalu setu (vzor KOV-B2). Kostra D-15
        // tlacidlo len vykresli — klik prebubla sem a nikam inam.
        if (a === 'hws-tax-create'){
          if (HWS_SET && typeof NXModal !== 'undefined' && NXModal.isOpen && NXModal.isOpen()){
            hwsTaxCreate(hwsSetDraft(NXModal.values(), { set_id: HWS_SET.set_id }),
                         t.getAttribute('data-nxm-for'));
          }
          return;
        }
        if (a === 'hws-del'){
          var did = t.getAttribute('data-set-id');
          if (HWS_DEL_ARM === did){
            HWS_DEL_ARM = '';
            hwsSend('hws_delete_set', { set_id: did, revision: HWS_DATA.revision || '' });
          } else {
            HWS_DEL_ARM = did;
            hwsRenderSets();
          }
          return;
        }
        // KOV-B3: JEDNO tlacidlo „+ Pridať člena" — sposob urcenia kodu je
        // OTAZKA V RIADKU, nie tri rozne tlacidla.
        if (a === 'hws-m-add'){
          if (HWS_SET){
            HWS_SET.members.push(hwsMemberBlank('code', HWS_SET.draft && HWS_SET.draft.generic_type));
            hwsMembersChanged();
          }
          return;
        }
        // pásma člena setu
        if (a === 'hws-b-add'){
          var mb = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (mb){ (mb.bands = mb.bands || []).push({ min: '', max: '', code: '' }); hwsMembersChanged(); }
          return;
        }
        if (a === 'hws-b-del'){
          var mb2 = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (mb2 && mb2.bands){
            mb2.bands.splice(parseInt(t.getAttribute('data-hws-b'), 10), 1);
            hwsMembersChanged();
          }
          return;
        }
        if (a === 'hws-m-del'){
          var mi = parseInt(t.getAttribute('data-hws-m'), 10);
          if (HWS_SET){ HWS_SET.members.splice(mi, 1); hwsMembersChanged(); }
          return;
        }
        if (a === 'hws-s-add'){
          var m1 = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (m1){ (m1.series = m1.series || []).push({ nl: '', code: '' }); hwsMembersChanged(); }
          return;
        }
        if (a === 'hws-s-del'){
          var m2 = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (m2 && m2.series){
            m2.series.splice(parseInt(t.getAttribute('data-hws-s'), 10), 1);
            hwsMembersChanged();
          }
          return;
        }
        if (a === 'hws-reset-proj'){
          hwsSend('hws_reset_project', { model_guid: (HWS_DATA && HWS_DATA.model_guid) || '' });
          return;
        }
        // H1b (FIX 10): doplnenie chýbajúcich globálnych predvolieb do projektu
        if (a === 'hws-merge-seed'){
          hwsSend('hws_merge_seed', { model_guid: (HWS_DATA && HWS_DATA.model_guid) || '' });
          return;
        }
        // --- výber setu podľa parametra (selector mapovania) ---
        if (a === 'hws-sel-edit'){
          var ekey = t.getAttribute('data-hws-key');
          HWS_SEL[ekey] = hwsPinRev(hwsSelectorFrom(hwsMappingValue(ekey)) ||
                                    { param: hwsDefaultParam(hwsGtOfKey(ekey)), rows: [{ min: '', max: '', set_id: '' }] },
                                    hwsCurrentRev());
          hwsRenderProj();
          return;
        }
        if (a === 'hws-sel-cancel'){
          delete HWS_SEL[t.getAttribute('data-hws-key')];
          hwsRenderProj();
          return;
        }
        if (a === 'hws-sb-add'){
          var sk = t.getAttribute('data-hws-key');
          if (HWS_SEL[sk]){ (HWS_SEL[sk].rows = HWS_SEL[sk].rows || []).push({ min: '', max: '', set_id: '' }); hwsRenderProj(); }
          return;
        }
        if (a === 'hws-sb-del'){
          var sk2 = t.getAttribute('data-hws-sel');
          if (HWS_SEL[sk2] && HWS_SEL[sk2].rows){
            HWS_SEL[sk2].rows.splice(parseInt(t.getAttribute('data-hws-b'), 10), 1);
            hwsRenderProj();
          }
          return;
        }
        if (a === 'hws-sel-save'){
          var savKey = t.getAttribute('data-hws-key');
          var st = HWS_SEL[savKey];
          if (st){
            // Editor sa NEZATVÁRA tu — až echom HWSETS.mapSaved po ÚSPEŠNOM
            // zápise. Tvar aj prekryvy pásiem posudzuje VÝHRADNE server.
            // R-08 (review #258 P1): posiela sa revízia PRIPNUTÁ pri otvorení
            // editora, nie aktuálna — rozpísaný draft plný push ZÁMERNE
            // prežíva, takže čerstvá revízia by guard urobila slepým presne
            // v scenári, na ktorý je (vzor #227 P1 v Nastaveniach).
            hwsSendMap(t.getAttribute('data-hws-act'), t.getAttribute('data-hws-gt'),
                       hwsBuildSelector(st), savKey, st.rev);
          }
          return;
        }
      }
      // klik mimo "Naozaj zmazat?" odzbroji potvrdenie — prekresli sa VZDY
      // (`hwsRenderSets` je bez `#hwTabSets` no-op a nad skrytym uzlom lacne).
      if (HWS_DEL_ARM && !(t && t.getAttribute('data-action') === 'hws-del')){
        HWS_DEL_ARM = '';
        hwsRenderSets();
      }
    });
    // Editor setu aj editor pásiem: inputs píšu do stavu (input event — bez
    // prerenderu); selecty menia hodnotu až na change, preto ten istý zápis
    // beží v oboch listeneroch (JEDNA cesta = hwsWriteField).
    document.addEventListener('input', function(ev){
      var ti = ev.target;
      if (hwsWriteField(ti)) return;
      if (!ti || !ti.getAttribute) return;
      // Pisanie do MODALU: nazov (rucny prepis) a vzorova NL nahladu.
      // Selecty klasifikacie sa riesia AZ na `change` — prekreslovat modal
      // pri kazdom znaku by zhodilo fokus.
      var k = ti.getAttribute('data-nxm');
      if (k === 'name' || ti.getAttribute('data-hws-sample')) hwsModalChange(ti);
    });
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      if (hwsModalChange(t)) return;
      var act = t.getAttribute('data-action-change');
      if (act === 'hws-map-proj' || act === 'hws-map-global'){
        var gt = t.getAttribute('data-hws-gt');
        var key = t.getAttribute('data-hws-key') || hwsSelKey(act, gt);
        if (t.value === HWS_PARAM_OPT){
          // „podľa parametra…" NIE JE hodnota — otvorí editor pásiem;
          // na server ide až Uložiť výber.
          HWS_SEL[key] = HWS_SEL[key] || hwsPinRev(hwsSelectorFrom(hwsMappingValue(key)) ||
                         { param: hwsDefaultParam(gt), rows: [{ min: '', max: '', set_id: '' }] },
                         hwsCurrentRev());
          hwsRenderProj();
          return;
        }
        delete HWS_SEL[key]; // pevný set / bez setu = editor pásiem zavretý
        hwsSendMap(act, gt, t.value, key);
        return;
      }
      hwsWriteField(t);
    });
    // Zbalená sekcia globálnych predvolieb si pamätá stav — prerender pri
    // úprave pásiem ju inak zakaždým zavrie.
    document.addEventListener('toggle', function(ev){
      var t = ev.target;
      if (t && t.getAttribute && t.getAttribute('data-hws-det') === 'global') HWS_GLOBAL_OPEN = !!t.open;
    }, true);
  }

  // Zápis hodnoty poľa do rozpracovaného stavu (členovia setu / editor pásiem).
  function hwsWriteField(t){
    if (!t || !t.getAttribute) return false;
    var field = t.getAttribute('data-hws-field');
    if (!field) return false;
    var selKey = t.getAttribute('data-hws-sel');
    if (selKey != null){
      var st = HWS_SEL[selKey];
      if (!st) return false;
      var sbi = t.getAttribute('data-hws-b');
      if (sbi == null){ st[field] = t.value; return true; } // param výberu
      var srow2 = (st.rows || [])[parseInt(sbi, 10)];
      if (srow2) srow2[field] = t.value;
      return true;
    }
    if (!HWS_SET) return false;
    var mi = t.getAttribute('data-hws-m');
    if (mi == null) return false;
    var m = hwsMember(parseInt(mi, 10));
    if (!m) return false;
    // „Ako sa určí kód?" NIE JE hodnota člena — je to jeho TVAR: polia
    // druhého spôsobu sa pri prepnutí ZAHADZUJÚ (XOR ostáva, polovičný člen
    // by na serveri aj tak spadol).
    if (field === 'kind'){
      HWS_SET.members[parseInt(mi, 10)] =
        hwsMemberSwitch(m, t.value, HWS_SET.draft && HWS_SET.draft.generic_type);
      hwsMembersChanged();
      return true;
    }
    var si = t.getAttribute('data-hws-s');
    if (si != null && m.series){
      var srow = m.series[parseInt(si, 10)];
      if (srow) srow[field] = t.value;
      hwsPreviewSchedule();
      return true;
    }
    var bi = t.getAttribute('data-hws-b');
    if (bi != null && m.bands){
      var brow = m.bands[parseInt(bi, 10)];
      if (brow) brow[field] = t.value;
      hwsPreviewSchedule();
      return true;
    }
    m[field] = t.value;
    hwsPreviewSchedule();
    return true;
  }

  // --- KOV-B3: polia MODALU (kostra D-15 ich kresli do `#nxModalRoot`) -------
  //
  // Klasifikacia meni SADU POLI, takze modal sa PREKRESLI; nazov a vzorova NL
  // menia len stav a nahlad.
  var HWS_CTX_FIELDS = { use_type: 1, opening_mode: 1, drawer_construction: 1,
                         manufacturer: 1, series: 1 };

  function hwsModalChange(t){
    if (!HWS_SET || !t || !t.getAttribute) return false;
    var sample = t.getAttribute('data-hws-sample');
    if (sample){
      HWS_SET.sample[sample] = Number(hwsNumIn(t.value));
      hwsPreviewSchedule();
      return true;
    }
    var key = t.getAttribute('data-nxm');
    if (!key) return false;
    if (HWS_CTX_FIELDS[key]){ hwsSetCtxSwitch(key); return true; }
    if (key === 'name'){
      // Rucne prepisany nazov auto-navrh UZ NEPREPISUJE — inak by sa vlastne
      // meno stratilo pri najblizsej zmene klasifikacie.
      HWS_SET.nameTouched = true;
      HWS_SET.draft.name = t.value;
      return true;
    }
    if (key === 'active'){ HWS_SET.draft.active = !!t.checked; hwsPreviewSchedule(); return true; }
    if (key === 'generic_type'){ HWS_SET.draft.generic_type = t.value; hwsPreviewSchedule(); return true; }
    return false;
  }

  // Odoslanie mapovania. value = set_id String ('' = bez setu) alebo selector
  // Hash; ui_key je len echo pre zatvorenie editora po ÚSPECHU.
  // R-08 (review #258 P1): draft editora pásiem si PRIPNE revíziu knižnice
  // z chvíle, keď ho používateľ otvoril. Draft plný push ZÁMERNE prežíva
  // (rozpísané hodnoty sa nesmú stratiť), takže keby sa pri Uložiť poslala
  // ČERSTVÁ revízia, guard by prešiel nad stavom, ktorý používateľ nikdy
  // nevidel — a cudzie mapovanie toho istého typu by ticho zmizlo.
  // (Rovnaká lekcia ako #227 P1 v Nastaveniach.)
  function hwsPinRev(state, rev){
    if (state) state.rev = rev || '';
    return state;
  }

  // Revízia do payloadu: PRIPNUTÁ z draftu vyhráva. Chýbajúci draft (priamy
  // výber zo selectu) = aktuálna revízia — select prekreslí každý push
  // SPOLU s ňou, takže je to presne stav, nad ktorým sa klikalo. Pripnutá
  // PRÁZDNA hodnota sa NEDOPĹŇA čerstvou (bola by to tá istá slepota).
  function hwsMapRev(pinned, current){
    return (pinned === undefined || pinned === null) ? (current || '') : pinned;
  }

  function hwsCurrentRev(){ return (HWS_DATA && HWS_DATA.revision) || ''; }

  function hwsSendMap(action, gt, value, key, pinnedRev){
    // R-07: globálna predvoľba je zápis do knižnice — pri nekompatibilnej sa
    // neodosiela (select ju ani nevykreslí, toto je poistka pre zmenu selectu
    // zo zastaraného DOM-u).
    if (action === 'hws-map-global' && hwsLibWriteBlocked(HWS_DATA)) return;
    if (action === 'hws-map-global'){
      // R-08: globálna predvoľba nesie REVÍZIU knižnice (rovnako ako uloženie
      // a mazanie setu) — dve otvorené okná si ju inak ticho prepíšu.
      hwsSend('hws_map_global', { generic_type: gt, value: value, ui_key: key || '',
                                  revision: hwsMapRev(pinnedRev, hwsCurrentRev()) });
    } else {
      hwsSend('hws_map_project', { generic_type: gt, value: value, ui_key: key || '',
                                   model_guid: (HWS_DATA && HWS_DATA.model_guid) || '' });
    }
  }
  function hwsGtOfKey(key){ return String(key || '').split('|')[1] || ''; }
  // Aktuálna hodnota mapovania pre kľúč editora ("<action>|<generic_type>").
  function hwsMappingValue(key){
    var parts = String(key || '').split('|');
    var proj = (HWS_DATA && HWS_DATA.project) || {};
    var global = (HWS_DATA && HWS_DATA.global_mapping) || {};
    var mapping = (parts[0] === 'hws-map-global') ? global
                : (proj.status === 'ok' ? (proj.mapping || {}) : global);
    return mapping[parts[1]];
  }

  // Node testy — len ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { hwsSlug: hwsSlug, hwsSetsForType: hwsSetsForType,
      hwsMemberSummary: hwsMemberSummary, hwsBuildSetPayload: hwsBuildSetPayload,
      hwsMembersOf: hwsMembersOf, hwsBuildMembers: hwsBuildMembers,
      // KOV-B3: modal setu — clenovia (dve otazky), klasifikacia, auto-nazov,
      // chipy dlazdice, adresovanie chyb servera a poradie odpovedi nahladu.
      hwsMemberKind: hwsMemberKind, hwsMemberBlank: hwsMemberBlank,
      hwsMemberSwitch: hwsMemberSwitch, hwsNeedsType: hwsNeedsType,
      hwsClassOptions: hwsClassOptions, hwsClassLabel: hwsClassLabel,
      hwsManOptions: hwsManOptions, hwsSerOptions: hwsSerOptions,
      hwsTaxLocked: hwsTaxLocked, hwsSeriesOf: hwsSeriesOf,
      hwsAutoName: hwsAutoName, hwsApplyAutoName: hwsApplyAutoName,
      hwsSetFields: hwsSetFields, hwsSetDraft: hwsSetDraft, hwsSetDraftOf: hwsSetDraftOf,
      hwsChips: hwsChips, hwsServerErrors: hwsServerErrors,
      hwsPreviewLines: hwsPreviewLines, hwsPreviewStale: hwsPreviewStale,
      hwsGlobalOptions: hwsGlobalOptions,
      HWS_NEW_OPT: HWS_NEW_OPT, HWS_KEY_NEW: HWS_KEY_NEW,
      HWS_KINDS: HWS_KINDS, HWS_PERS: HWS_PERS,
      // H1b: pásma člena setu + výber setu podľa parametra
      hwsNum: hwsNum, hwsParamLabel: hwsParamLabel, hwsBandsSummary: hwsBandsSummary,
      hwsBuildBands: hwsBuildBands, hwsSelectorFrom: hwsSelectorFrom,
      hwsBuildSelector: hwsBuildSelector, hwsProjDraftKeys: hwsProjDraftKeys,
      // R-08 (review #258 P1): pripnutie revízie do draftu editora pásiem
      hwsPinRev: hwsPinRev, hwsMapRev: hwsMapRev,
      // R-07: kompatibilitná brána knižnice (banner + vypnuté globálne mutácie)
      hwsLibBlocked: hwsLibBlocked, hwsLibReason: hwsLibReason,
      HWS_LIB_ACTIONS: HWS_LIB_ACTIONS,
      // R-11: degradovaná knižnica (poškodený primár + platná záloha)
      hwsLibDegraded: hwsLibDegraded, hwsLibWriteBlocked: hwsLibWriteBlocked,
      HWS_WRITE_ACTIONS: HWS_WRITE_ACTIONS,
      // ŠT-3a-3: `HWSETS` a helpery fokusu potrebuju DOM a exportuju sa
      // ZAMERNE — kontrakty „setData NEKRESLI" a „fokus prezije prekreslenie"
      // sa inak nedaju overit nicim nez klikanim (tests/js/test_st3a_hw.js).
      HWSETS: HWSETS, hwsFocusSelector: hwsFocusSelector, hwsCssEscape: hwsCssEscape };
  }
