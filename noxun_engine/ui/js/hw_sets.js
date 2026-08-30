  // ================= Sety kovania + predvolby projektu (V0.6 D1b) =================
  // Set = mapovacie pravidlo genericky typ -> zoznam Demos kodov s pomermi
  // (NIE polozka katalogu). Server (HardwareSets) je autorita: normalizacia,
  // validacia, revision guard kniznice, snapshot projektu (mapping + kopie
  // definicii — audit B2). JS len renderuje a posiela payloady.
  // XSS kontrakt ako hw_catalog.js: createElement + textContent, data-action
  // delegacia; ziadne innerHTML s datami.

  var HWS_DATA = null;   // posledny HWSETS.init payload
  var HWS_EDIT = null;   // rozpracovany editor setu (null = zavrety)
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
  // `library_state` ('ok' | 'read_only') a `library_reason` (hotová SK veta —
  // JS si žiadny vlastný preklad neskladá). Knižnica z novšej verzie sa nesmie
  // ani meniť, ani potichu používať: sekcia vypne GLOBÁLNE mutácie a dôvod
  // povie bannerom. PROJEKTOVÉ predvoľby nad zdravým snapshotom fungujú ďalej
  // — ich zdrojom je .skp, nie knižnica.
  function hwsLibBlocked(data){ return !!(data && data.library_state === 'read_only'); }
  // Akcie, ktoré menia knižnicu alebo z nej kopírujú do .skp (`hws-merge-seed`
  // a `hws-reset-proj` zapisujú do modelu, ale ich ZDROJOM je knižnica).
  var HWS_LIB_ACTIONS = ['hws-new', 'hws-edit', 'hws-del', 'hws-save',
                         'hws-merge-seed', 'hws-reset-proj'];
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
  // Editor stav -> set payload pre server (rad: riadky {nl, code} -> mapa;
  // pasma: riadky {min, max, code} -> { param, bands }).
  function hwsBuildSetPayload(edit){
    var members = (edit.members || []).map(function(m){
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
    return { set_id: edit.set_id, name: hwsTrim(edit.name),
             generic_type: edit.generic_type, members: members };
  }
  // Set z kniznice -> editor stav (kopia; rad -> riadky zoradene podla NL).
  function hwsEditStateFrom(set){
    return {
      set_id: set.set_id, name: set.name, generic_type: set.generic_type,
      existing: true,
      members: (set.members || []).map(function(m){
        if (m.code_by_nl){
          return { is_series: true, per: 'unit', qty: m.qty || 1, label: m.label || '',
                   series: Object.keys(m.code_by_nl).sort(function(a, b){ return Number(a) - Number(b); })
                     .map(function(nl){ return { nl: nl, code: m.code_by_nl[nl] }; }) };
        }
        if (m.param_bands){
          return { is_bands: true, per: 'unit', qty: m.qty || 1, label: m.label || '',
                   param: m.param_bands.param || '',
                   bands: (m.param_bands.bands || []).map(function(b){
                     return { min: hwsNum(b.min), max: hwsNum(b.max), code: b.code || '' };
                   }) };
        }
        return { is_series: false, per: m.per || 'unit', qty: m.qty || 1,
                 label: m.label || '', code: m.code || '' };
      })
    };
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
      // Rozpracovany editor SETU NEZAHADZUJEME pri echu (vzor dirty buniek
      // okna Materialy) — render ho necha tak; zoznam a predvolby sa obnovia.
      hwsRenderAll();
    },
    // GH #127 P2: editor sa zatvara az pri USPESNOM ulozeni (server volanie)
    // — invalid/conflict necha rozpisany navrh na doopravenie.
    saved: function(){
      HWS_EDIT = null;
      hwsRenderSets();
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
  // kurzor z rozpisaneho editora setu (a z editora pasiem) uprostred pisania.
  // Vzor je `mdhRender` v `hw_catalog.js`: snapshot pred prekreslenim, obnova
  // po nom. Hodnoty poli sa NEOBNOVUJU — tie ziju v stave (`HWS_EDIT`,
  // `HWS_SEL`) a render ich vykresli spravne sam.

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
    if (HWS_EDIT){ box.appendChild(hwsEditorNode()); }
    var sets = HWS_DATA.sets || [];
    if (!sets.length && !HWS_EDIT){
      box.appendChild(hwsMk('div', 'muted', 'Knižnica setov je prázdna.'));
      return;
    }
    sets.forEach(function(s){
      var card = hwsMk('div', 'hwsset');
      var head = hwsMk('div', 'hwsset-head');
      head.appendChild(hwsMk('b', null, s.name));
      head.appendChild(hwsMk('span', 'hwsset-type', hwsTypeLabel(s.generic_type)));
      var eb = hwsMk('button', 'ghostbtn hwsbtn', 'Upraviť');
      eb.setAttribute('data-action', 'hws-edit');
      eb.setAttribute('data-set-id', s.set_id);
      head.appendChild(eb);
      var db = hwsMk('button', 'ghostbtn hwsbtn' + (HWS_DEL_ARM === s.set_id ? ' danger' : ''),
                     HWS_DEL_ARM === s.set_id ? 'Naozaj zmazať?' : 'Zmazať');
      db.setAttribute('data-action', 'hws-del');
      db.setAttribute('data-set-id', s.set_id);
      head.appendChild(db);
      card.appendChild(head);
      var ul = hwsMk('div', 'hwsset-members');
      (s.members || []).forEach(function(m){
        ul.appendChild(hwsMk('div', 'hwsset-m', hwsMemberSummary(m, HWS_DATA.params)));
      });
      card.appendChild(ul);
      box.appendChild(card);
    });
  }

  // Editor setu — formular z HWS_EDIT stavu; inputs pisu do stavu cez
  // data-hws-* delegaciu (change), Ulozit posle payload serveru.
  function hwsEditorNode(){
    var e = HWS_EDIT;
    var wrap = hwsMk('div', 'hwseditor');
    wrap.appendChild(hwsMk('div', 'hwsed-title', e.existing ? ('Úprava setu ' + e.set_id) : 'Nový set'));

    var r1 = hwsMk('div', 'row');
    r1.appendChild(hwsMk('label', null, 'Názov *'));
    var name = hwsMk('input');
    name.type = 'text'; name.value = e.name || '';
    name.setAttribute('data-hws-field', 'name');
    r1.appendChild(name);
    r1.appendChild(hwsMk('span', 'unit', ''));
    wrap.appendChild(r1);

    var r2 = hwsMk('div', 'row');
    r2.appendChild(hwsMk('label', null, 'Typ kovania'));
    var sel = hwsMk('select');
    sel.setAttribute('data-hws-field', 'generic_type');
    ((HWS_DATA && HWS_DATA.generic_types) || []).forEach(function(t){
      var o = hwsMk('option', null, t.label);
      o.value = t.key;
      if (t.key === e.generic_type) o.selected = true;
      sel.appendChild(o);
    });
    sel.disabled = !!e.existing; // typ existujuceho setu sa NEMENI (server guard)
    r2.appendChild(sel);
    r2.appendChild(hwsMk('span', 'unit', e.existing ? 'nemenné' : ''));
    wrap.appendChild(r2);

    var mbox = hwsMk('div', 'hwsed-members');
    (e.members || []).forEach(function(m, i){ mbox.appendChild(hwsMemberRow(m, i)); });
    wrap.appendChild(mbox);

    var addb = hwsMk('button', 'ghostbtn', '+ člen (kód)');
    addb.setAttribute('data-action', 'hws-m-add');
    wrap.appendChild(addb);
    var adds = hwsMk('button', 'ghostbtn', '+ rad podľa NL (výsuvy)');
    adds.setAttribute('data-action', 'hws-m-add-series');
    wrap.appendChild(adds);
    // H1b: tretí druh člena — kód podľa PÁSMA parametra (nohy podľa výšky sokla).
    var addp = hwsMk('button', 'ghostbtn', '+ pásma podľa parametra');
    addp.setAttribute('data-action', 'hws-m-add-bands');
    addp.title = 'Kód sa vyberie podľa rozmeru položky (napr. noha podľa výšky sokla).';
    wrap.appendChild(addp);

    var btns = hwsMk('div', 'btnrow');
    var save = hwsMk('button', 'primary', 'Uložiť set');
    save.setAttribute('data-action', 'hws-save');
    btns.appendChild(save);
    var cancel = hwsMk('button', 'ghostbtn', 'Zrušiť');
    cancel.setAttribute('data-action', 'hws-cancel');
    btns.appendChild(cancel);
    wrap.appendChild(btns);
    return wrap;
  }

  function hwsMemberRow(m, i){
    var row = hwsMk('div', 'hwsed-m');
    if (m.is_series){
      row.appendChild(hwsMk('span', 'hwsed-mlbl', 'Rad NL'));
      var sbox = hwsMk('div', 'hwsed-series');
      (m.series || []).forEach(function(srow, j){
        var sr = hwsMk('div', 'hwsed-srow');
        var nl = hwsMk('input'); nl.type = 'text'; nl.value = srow.nl || '';
        nl.placeholder = 'NL'; nl.setAttribute('data-hws-m', i); nl.setAttribute('data-hws-s', j);
        nl.setAttribute('data-hws-field', 'nl');
        sr.appendChild(nl);
        sr.appendChild(hwsMk('span', null, '→'));
        var code = hwsMk('input'); code.type = 'text'; code.value = srow.code || '';
        code.placeholder = 'kód'; code.setAttribute('data-hws-m', i); code.setAttribute('data-hws-s', j);
        code.setAttribute('data-hws-field', 'code');
        sr.appendChild(code);
        var del = hwsMk('button', 'ghostbtn hwsbtn', '×');
        del.setAttribute('data-action', 'hws-s-del');
        del.setAttribute('data-hws-m', i); del.setAttribute('data-hws-s', j);
        sr.appendChild(del);
        sbox.appendChild(sr);
      });
      var add = hwsMk('button', 'ghostbtn hwsbtn', '+ dĺžka');
      add.setAttribute('data-action', 'hws-s-add');
      add.setAttribute('data-hws-m', i);
      sbox.appendChild(add);
      row.appendChild(sbox);
    } else if (m.is_bands){
      // H1b: kód podľa pásma parametra. Hranice sú UZAVRETÉ (min ≤ v ≤ max),
      // dotyk dvoch pásiem = prekryv → server zápis odmietne (all-or-nothing).
      row.appendChild(hwsMk('span', 'hwsed-mlbl', 'Pásma'));
      var bbox = hwsMk('div', 'hwsed-series');
      bbox.appendChild(hwsParamSelect(m.param, i, null));
      (m.bands || []).forEach(function(brow, j){
        bbox.appendChild(hwsBandRow(brow, { m: i, b: j, valueField: 'code',
                                            placeholder: 'kód', delAction: 'hws-b-del' }));
      });
      var addb2 = hwsMk('button', 'ghostbtn hwsbtn', '+ pásmo');
      addb2.setAttribute('data-action', 'hws-b-add');
      addb2.setAttribute('data-hws-m', i);
      bbox.appendChild(addb2);
      var hintb = hwsMk('div', 'hint', 'Hodnota mimo pásiem = ORANGE „doplň pásmo" — nikdy sa neberie najbližšie pásmo.');
      bbox.appendChild(hintb);
      row.appendChild(bbox);
    } else {
      var code2 = hwsMk('input'); code2.type = 'text'; code2.value = m.code || '';
      code2.placeholder = 'Demos kód'; code2.setAttribute('data-hws-m', i);
      code2.setAttribute('data-hws-field', 'code');
      row.appendChild(code2);
      var qty = hwsMk('input'); qty.type = 'number'; qty.min = '1'; qty.max = '999';
      qty.value = m.qty || 1; qty.setAttribute('data-hws-m', i);
      qty.setAttribute('data-hws-field', 'qty');
      qty.className = 'hwsed-qty';
      row.appendChild(qty);
      var per = hwsMk('select');
      per.setAttribute('data-hws-m', i); per.setAttribute('data-hws-field', 'per');
      [['unit', 'na kus kovania'], ['owner', 'na dvierka/vlastníka']].forEach(function(p){
        var o = hwsMk('option', null, p[1]); o.value = p[0];
        if (m.per === p[0]) o.selected = true;
        per.appendChild(o);
      });
      row.appendChild(per);
      var lbl = hwsMk('input'); lbl.type = 'text'; lbl.value = m.label || '';
      lbl.placeholder = 'popis (voliteľné)'; lbl.setAttribute('data-hws-m', i);
      lbl.setAttribute('data-hws-field', 'label');
      row.appendChild(lbl);
    }
    var del2 = hwsMk('button', 'ghostbtn hwsbtn', '×');
    del2.setAttribute('data-action', 'hws-m-del');
    del2.setAttribute('data-hws-m', i);
    row.appendChild(del2);
    return row;
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
    if (libBlocked){
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
  function hwsGlobalOptions(gt){
    return hwsSetsForType(HWS_DATA && HWS_DATA.sets, gt).map(function(s){
      return { set_id: s.set_id, name: s.name };
    });
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

  function hwsMember(i){ return (HWS_EDIT && HWS_EDIT.members && HWS_EDIT.members[i]) || null; }

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
        if (a === 'hws-new'){
          HWS_EDIT = { set_id: '', name: '', generic_type: 'hinge', existing: false,
                       members: [{ is_series: false, per: 'unit', qty: 1, code: '', label: '' }] };
          hwsRenderSets(); return;
        }
        if (a === 'hws-edit'){
          var sid = t.getAttribute('data-set-id');
          var s = (HWS_DATA.sets || []).filter(function(x){ return x.set_id === sid; })[0];
          if (s){ HWS_EDIT = hwsEditStateFrom(s); hwsRenderSets(); }
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
        if (a === 'hws-cancel'){ HWS_EDIT = null; hwsRenderSets(); return; }
        if (a === 'hws-save'){
          if (HWS_EDIT){
            if (!HWS_EDIT.existing) HWS_EDIT.set_id = hwsSlug(HWS_EDIT.name);
            // GH #127 P2: create flag (server odmietne koliziu slugu) +
            // editor sa NEzatvara tu — az HWSETS.saved() pri uspechu.
            hwsSend('hws_save_set', { set: hwsBuildSetPayload(HWS_EDIT),
                                      revision: HWS_DATA.revision || '',
                                      create: !HWS_EDIT.existing });
          }
          return;
        }
        if (a === 'hws-m-add' || a === 'hws-m-add-series' || a === 'hws-m-add-bands'){
          if (HWS_EDIT){
            if (a === 'hws-m-add'){
              HWS_EDIT.members.push({ is_series: false, per: 'unit', qty: 1, code: '', label: '' });
            } else if (a === 'hws-m-add-series'){
              HWS_EDIT.members.push({ is_series: true, per: 'unit', qty: 1, label: '',
                                      series: [{ nl: '', code: '' }] });
            } else {
              HWS_EDIT.members.push({ is_bands: true, per: 'unit', qty: 1, label: '',
                                      param: hwsDefaultParam(HWS_EDIT.generic_type),
                                      bands: [{ min: '', max: '', code: '' }] });
            }
            hwsRenderSets();
          }
          return;
        }
        // pásma člena setu
        if (a === 'hws-b-add'){
          var mb = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (mb){ (mb.bands = mb.bands || []).push({ min: '', max: '', code: '' }); hwsRenderSets(); }
          return;
        }
        if (a === 'hws-b-del'){
          var mb2 = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (mb2 && mb2.bands){ mb2.bands.splice(parseInt(t.getAttribute('data-hws-b'), 10), 1); hwsRenderSets(); }
          return;
        }
        if (a === 'hws-m-del'){
          var mi = parseInt(t.getAttribute('data-hws-m'), 10);
          if (HWS_EDIT){ HWS_EDIT.members.splice(mi, 1); hwsRenderSets(); }
          return;
        }
        if (a === 'hws-s-add'){
          var m1 = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (m1){ (m1.series = m1.series || []).push({ nl: '', code: '' }); hwsRenderSets(); }
          return;
        }
        if (a === 'hws-s-del'){
          var m2 = hwsMember(parseInt(t.getAttribute('data-hws-m'), 10));
          if (m2 && m2.series){ m2.series.splice(parseInt(t.getAttribute('data-hws-s'), 10), 1); hwsRenderSets(); }
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
    document.addEventListener('input', function(ev){ hwsWriteField(ev.target); });
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
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

  // Zápis hodnoty poľa do rozpracovaného stavu (editor setu / editor pásiem).
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
    if (!HWS_EDIT) return false;
    var mi = t.getAttribute('data-hws-m');
    if (mi == null){
      if (field === 'name') HWS_EDIT.name = t.value;
      if (field === 'generic_type') HWS_EDIT.generic_type = t.value;
      return true;
    }
    var m = hwsMember(parseInt(mi, 10));
    if (!m) return false;
    var si = t.getAttribute('data-hws-s');
    if (si != null && m.series){
      var srow = m.series[parseInt(si, 10)];
      if (srow) srow[field] = t.value;
      return true;
    }
    var bi = t.getAttribute('data-hws-b');
    if (bi != null && m.bands){
      var brow = m.bands[parseInt(bi, 10)];
      if (brow) brow[field] = t.value;
      return true;
    }
    m[field] = t.value;
    return true;
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
    if (action === 'hws-map-global' && hwsLibBlocked(HWS_DATA)) return;
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
      hwsEditStateFrom: hwsEditStateFrom,
      // H1b: pásma člena setu + výber setu podľa parametra
      hwsNum: hwsNum, hwsParamLabel: hwsParamLabel, hwsBandsSummary: hwsBandsSummary,
      hwsBuildBands: hwsBuildBands, hwsSelectorFrom: hwsSelectorFrom,
      hwsBuildSelector: hwsBuildSelector, hwsProjDraftKeys: hwsProjDraftKeys,
      // R-08 (review #258 P1): pripnutie revízie do draftu editora pásiem
      hwsPinRev: hwsPinRev, hwsMapRev: hwsMapRev,
      // R-07: kompatibilitná brána knižnice (banner + vypnuté globálne mutácie)
      hwsLibBlocked: hwsLibBlocked, hwsLibReason: hwsLibReason,
      HWS_LIB_ACTIONS: HWS_LIB_ACTIONS,
      // ŠT-3a-3: `HWSETS` a helpery fokusu potrebuju DOM a exportuju sa
      // ZAMERNE — kontrakty „setData NEKRESLI" a „fokus prezije prekreslenie"
      // sa inak nedaju overit nicim nez klikanim (tests/js/test_st3a_hw.js).
      HWSETS: HWSETS, hwsFocusSelector: hwsFocusSelector, hwsCssEscape: hwsCssEscape };
  }
