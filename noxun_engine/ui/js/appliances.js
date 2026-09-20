  // ===================== Spotrebiče — sekcia `appl` v okne Štúdio ============
  //
  // S1-A2: katalóg modelov spotrebičov TOHTO POČÍTAČA (%APPDATA%) — strom po
  // kategóriách vľavo, karta záznamu vpravo. Pohľad „V zákazke" je zatiaľ
  // priznaný placeholder (D-78): zapne ho S1-B.
  //
  // PREFIX `ap*` / `AP_*`: súbor beží v TOM ISTOM globálnom scope ako
  // `studio.js` (kolízia mena `render`/`el`/`esc` by prepísala okno), preto má
  // všetko vlastný názov — presne ako `tpl*` v templates.js a `rd*` v rules.js.
  //
  // ČO JE ČIE:
  //   * SERVER (`ui/appliance_dialog.rb`) skladá strom, jeho PORADIE, počty,
  //     podtitul riadku, texty polí karty aj polia formulára. Tento súbor
  //     kreslí presne to, čo dostal — nič nedopĺňa a nič nepreskladáva.
  //   * KLIENT vlastní POHĽAD: vybraný záznam, text hľadania, prepínač
  //     „vyradené", zbalené skupiny a cache miniatúr. Je to pamäť OKNA —
  //     nikam sa neukladá a nový dokument ju nezhadzuje (katalóg nie je
  //     zákazka).

  var AP_TREE = null;     // posledný strom zo servera
  var AP_CARD = null;     // posledná karta zo servera
  var AP_FORM = null;     // polia modalu pre všetky kategórie (pýta sa raz)
  var AP_FORM_WAIT = false;
  var AP_FORM_TRIED = false;
  var AP_FORM_THEN = null; // čo otvoriť, keď formulár dorazí ('create'/'edit')
  var AP_TRIGGER = null;   // uzol, na ktorý sa vráti fokus po zatvorení modalu
  var AP_SEL = '';        // vybraný záznam (pamäť okna)
  var AP_Q = '';          // text hľadania
  var AP_DEL = false;     // prepínač „vyradené"
  var AP_GEN = 0;         // generácia ODOSLANÉHO dotazu stromu
  // Generácia stromu, ktorý je PRÁVE V OKNE. Hľadanie je debounced a odpovede
  // chodia asynchrónne, takže pomalšie kolo môže doraziť až po čerstvejšom —
  // a to by používateľovi ukázalo výsledky pre text, ktorý už prepísal.
  // Porovnáva sa proti VYKRESLENÉMU stavu (nie proti počítadlu dotazov), lebo
  // strom chodí aj plným pushom, ktorý si klient nevyžiadal.
  var AP_SEEN = -1;
  var AP_CLOSED = {};     // zbalené skupiny stromu (kód kategórie -> true)
  // Cache miniatúr: id prílohy -> data URI alebo `null` (= server povedal
  // „náhľad nebude"). Názov uloženej prílohy je NEMENNÝ a nikdy sa
  // nerecykluje (kontrakt S1-A1), takže táto cache nemôže zastarať.
  var AP_THUMBS = {};
  var AP_THUMB_WAIT = false;
  // Veľkosť cache pri poslednom dotaze na miniatúry. Keď ďalšie kolo NIČ
  // nedonieslo, ďalej sa nepýta — inak by sa dve strany dohadovali donekonečna.
  var AP_THUMB_MARK = -1;
  var AP_TOKEN = '';      // identita JEDNÉHO odoslania modalu
  var AP_MODE = '';       // 'create' | 'edit'
  var AP_CARD_EDIT = null; // karta, ktorú modal upravuje (drží sa cez prekreslenie)
  // Baseline OTVORENIA modalu: polia (pre pamäť D-15 naprieč prekresleniami)
  // a hodnoty zo servera (proti nim sa počíta, čo sa naozaj zmenilo).
  var AP_BASE_FIELDS = null;
  var AP_BASE_VALUES = {};
  var AP_QTIMER = null;
  var AP_Q_DEBOUNCE = 200;

  // --- S1-B2: pohľad „V zákazke" ---------------------------------------------
  // POHĽAD je pamäť OKNA (ako vybraný záznam alebo zbalená skupina): prepnutie
  // segmentu NEJDE na server a nikdy nečaká na kolo. Tabuľku aj jej PORADIE
  // skladá server (`ST.appl.job`) — tu sa len kreslí a filtruje.
  var AP_VIEW = 'cat';     // 'job' | 'cat'
  var AP_JOB = null;       // posledná tabuľka zo servera
  var AP_JOB_Q = '';       // hľadanie v tabuľke (ČISTO klientske — je to pohľad)
  var AP_JOB_CAT = '';     // filter kategórie (to isté)
  var AP_JOB_FOCUS = '';   // item_id prisvieteného riadku (kotva z Kontroly)
  // IDENTITA PAYLOADU, z ktorého je tabuľka vykreslená: dokument a generácia
  // okna. Posiela sa s „okom" (jediná akcia sekcie, ktorá siaha do modelu) —
  // klik zo zastaraného pohľadu by inak zhodou ID a PID označil cudziu
  // skrinku (Codex #383 kolo 1 P2).
  var AP_JOB_DOC = { guid: '', gen: 0 };

  var AP_STUDIO = (typeof module !== 'undefined' && module.exports)
    ? require('./studio.js')            // Node testy
    : null;

  function apEl(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }

  function apEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function apIco(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

  // Je sekcia Spotrebiče práve otvorená? Autoritou je `studio.js`. Keď sa to
  // zistiť nedá, odpoveď je NIE — `#secbody` a `#sectools` sú ZDIEĽANÉ uzly
  // celého okna a echo katalógu do nich nesmie písať, kým je otvorená INÁ
  // sekcia (review #225 P1). Obsah aj tak dokreslí `renderBody` pri vstupe.
  function apIsActive(){
    if (typeof studioActiveSection === 'function') return studioActiveSection() === 'appl';
    if (AP_STUDIO && typeof AP_STUDIO.studioActiveSection === 'function'){
      return AP_STUDIO.studioActiveSection() === 'appl';
    }
    return false;
  }

  function apSend(name, payload){
    if (typeof window === 'undefined' || !window.sketchup || !sketchup[name]){
      AP.setStatus('Okno stratilo spojenie so SketchUpom — zavri a otvor Štúdio znova.', true);
      return false;
    }
    sketchup[name](JSON.stringify(payload || {}));
    return true;
  }

  // --- prijímače zo servera ---------------------------------------------------

  var AP = {
    setStatus: function(msg, err){
      var e = apEl('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    }
  };
  if (typeof window !== 'undefined') window.AP = AP;

  // STROM. `gen` je generácia dotazu KLIENTA, ktorú server iba echuje:
  // hľadanie je debounced a odpovede chodia asynchrónne, takže pomalšie kolo
  // NESMIE prepísať čerstvejší strom. Echo po zápise nesie `gen` posledného
  // dotazu, takže prejde.
  function apSetTree(p){
    if (!p) return;
    var g = Number(p.gen || 0);
    if (g < AP_SEEN) return;                      // staršia odpoveď — zahodiť
    AP_SEEN = g;
    // Generácia PRICHÁDZA aj zo servera (plný push, echo po zápise) a po
    // znovuotvorení Štúdia štartuje klient od nuly, kým server si pamätá
    // vyššie číslo. Bez tohto prevzatia by každý ďalší dotaz odišiel
    // so `gen`, ktoré je pod už videným — a vlastnú odpoveď by klient zahodil
    // ako staršiu (hľadanie aj formulár by „nereagovali"). Codex #378 kolo 1 P2.
    if (g > AP_GEN) AP_GEN = g;
    AP_TREE = p;
    // Kolo dotazu je vybavené bez ohľadu na to, či formulár naozaj prišiel —
    // inak by jediná stratená odpoveď nechala príznak „čaká sa" navždy
    // a tlačidlo „Nový spotrebič" by už nikdy nič neotvorilo.
    AP_FORM_WAIT = false;
    if (p.form) AP_FORM = p.form;
    // S1-B2: tabuľka „V zákazke" chodí LEN plným pushom (patrí dokumentu),
    // kým strom aj echo po zápise do katalógu chodia bez nej. Bez tejto
    // podmienky by echo katalógu vymazalo tabuľku a pohľad by sa vyprázdnil
    // po uložení modelu, s ktorým nemá nič spoločné.
    if (p.job) AP_JOB = p.job;
    if (!apIsActive()) return;
    apRenderTools();
    apRenderBody();
    apOpenPending();
  }

  // KARTA. Miniatúry prichádzajú v tom istom payloade (lazy kanál) — vlievajú
  // sa do cache VRÁTANE `null` hodnôt, aby sa o tú istú prílohu už nikto
  // nepýtal (záporná cache, vzor `TPL_PNG`).
  function apSetCard(p){
    AP_THUMB_WAIT = false;
    if (!p){ AP_CARD = null; AP_SEL = ''; if (apIsActive()) apRenderBody(); return; }
    if (p.thumbs){
      Object.keys(p.thumbs).forEach(function(k){ AP_THUMBS[k] = p.thumbs[k]; });
    }
    AP_CARD = p;
    AP_SEL = String(p.id || '');
    // OPTIMISTICKÝ ZÁMOK otvoreného modalu sa obnovuje z echa: po konflikte
    // (alebo po zápise z druhej inštancie) drží formulár starú `rev` a každé
    // ďalšie „Uložiť" by narazilo na ten istý konflikt. Hodnoty, ktoré
    // používateľ rozpísal, sa NEDOTÝKAJÚ — mení sa len zámok.
    if (AP_CARD_EDIT && String(AP_CARD_EDIT.id) === AP_SEL) AP_CARD_EDIT.rev = p.rev;
    if (!apIsActive()) return;
    apRenderBody();
  }

  // VÝSLEDOK ZÁPISU pre modal (D-15). Prijíma sa LEN odpoveď na TOTO odoslanie
  // (`token`) — výsledok formulára, ktorý používateľ medzitým zavrel a otvoril
  // iný, by mu inak zavrel rozpísaný koncept.
  function apResult(ok, msg, errors, op, token, info){
    if (!AP_TOKEN || String(token || '') !== AP_TOKEN) return;
    AP_TOKEN = '';
    // `info.rev` nesie konflikt: server poslal ČERSTVÝ zámok záznamu. Berie sa
    // aj vtedy, keď modal medzitým zanikol — `AP_CARD_EDIT` je to, s čím sa
    // pracuje ďalej.
    if (info && info.rev && AP_CARD_EDIT) AP_CARD_EDIT.rev = String(info.rev);
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    if (!m || !m.isOpen()) return;
    if (ok){
      m.setBusy(false, { clear: true });
      m.close();
      return;
    }
    m.setBusy(false);
    m.showErrors(Array.isArray(errors) && errors.length ? errors : [{ msg: msg }]);
  }

  if (typeof window !== 'undefined' && window.NX){
    NX.applTree = apSetTree;
    NX.applCard = apSetCard;
    NX.applResult = apResult;
  }

  // --- LIŠTA sekcie -----------------------------------------------------------

  function apToolsState(){
    var t = AP_TREE || {};
    return { view: AP_VIEW, query: AP_Q, deleted: AP_DEL,
             total: Number(t.total || 0), seed: Number(t.seed_total || 0),
             writable: t.writable !== false,
             job: AP_JOB, jobQuery: AP_JOB_Q, jobCat: AP_JOB_CAT };
  }

  // Segment pohľadov (S1-B2: OBA sú aktívne — „V zákazke" už nie je
  // `aria-disabled` placeholder z A2).
  function apViewSegHtml(view){
    var job = view === 'job';
    return '<div class="bomviews">' +
      '<button type="button" class="bomvw' + (job ? ' on' : '') + '" data-ap="view" data-v="job"' +
      ' title="Spotrebiče TEJTO zákazky — kde patria a čo hovorí kontrola">V zákazke</button>' +
      '<button type="button" class="bomvw' + (job ? '' : ' on') + '" data-ap="view" data-v="cat"' +
      ' title="Katalóg modelov tohto počítača">Katalóg</button></div>';
  }

  // Čistá funkcia (Node test).
  function apToolsHtml(s){
    var st = s || {};
    if (st.view === 'job') return apJobToolsHtml(st);
    var h = apViewSegHtml('cat');
    h += '<button type="button" class="primary" data-ap="new"' +
         (st.writable ? '' : ' aria-disabled="true"') +
         ' title="Nový model do katalógu tohto počítača">' + apIco('plus') + ' Nový spotrebič</button>';
    h += '<div class="searchbox">' + apIco('search') +
         '<input type="text" id="apQ" placeholder="Hľadať model, výrobcu…" value="' +
         apEsc(st.query) + '"></div>';
    h += '<label class="apdel"><input type="checkbox" id="apDel"' +
         (st.deleted ? ' checked' : '') + '> vyradené</label>';
    h += '<span class="spacer"></span><span class="sechint">Katalóg je tohto počítača · bez cien · ' +
         apEsc(apCountLabel(st.total, st.seed)) + '</span>';
    return h;
  }

  // Lišta pohľadu „V zákazke" (mockup R3). Hľadanie aj kategória sú ČISTO
  // klientske — zužujú TO, ČO UŽ V OKNE JE, takže nechodia na server a ani
  // nemôžu preskladať poradie, ktoré server poslal.
  function apJobToolsHtml(s){
    var st = s || {};
    var job = st.job || {};
    var h = apViewSegHtml('job');
    h += '<button type="button" class="primary" data-ap="jadd"' +
         ' title="Vyber model z katalógu a priraď mu vlastníka">' +
         apIco('plus') + ' Pridať do zákazky</button>';
    h += '<div class="searchbox">' + apIco('search') +
         '<input type="text" id="apJobQ" placeholder="Hľadať model, skrinku…" value="' +
         apEsc(st.jobQuery) + '"></div>';
    h += '<select id="apJobCat" title="Kategória"><option value="">Všetky kategórie</option>';
    (job.categories || []).forEach(function(c){
      var code = String(c[0]);
      h += '<option value="' + apEsc(code) + '"' + (code === st.jobCat ? ' selected' : '') + '>' +
           apEsc(c[1]) + '</option>';
    });
    h += '</select>';
    h += '<span class="spacer"></span><span class="sechint">' +
         apEsc(job.summary || 'zatiaľ žiadne spotrebiče') + '</span>';
    return h;
  }

  // „9 modelov (9 seed)" — jednotné/množné číslo je vec jazyka, nie výpočtu.
  function apCountLabel(total, seed){
    var n = Number(total || 0);
    var word = n === 1 ? 'model' : (n >= 2 && n <= 4 ? 'modely' : 'modelov');
    var s = Number(seed || 0);
    return n + ' ' + word + (s > 0 ? ' (' + s + ' seed)' : '');
  }

  // Lišta sa NEPREKRESĽUJE, kým používateľ píše do hľadania: odpoveď servera
  // chodí uprostred písania (debounce 200 ms) a výmena uzla by vzala fokus aj
  // pozíciu kurzora. Obnoví sa vtedy LEN počet modelov — presne ten vzor, aký
  // má `NX.setVepoBar` v studio.js pri poli „Projekt".
  function apRenderTools(){
    var box = apEl('sectools');
    if (!box) return;
    // S1-B2: to isté pre hľadanie v pohľade „V zákazke" — plný push chodí aj
    // uprostred písania (prepočet zákazky), a výmena uzla by vzala fokus.
    // Text je čisto klientsky, takže sa nemá čím rozísť; prekreslenie sa len
    // odloží na chvíľu, keď v poli nikto nepíše.
    var jq = apEl('apJobQ');
    if (typeof document !== 'undefined' && jq && document.activeElement === jq) return;
    var q = apEl('apQ');
    if (typeof document !== 'undefined' && q && document.activeElement === q){
      var hint = box.querySelector ? box.querySelector('.sechint') : null;
      var st = apToolsState();
      if (hint) hint.textContent = 'Katalóg je tohto počítača · bez cien · ' +
                                   apCountLabel(st.total, st.seed);
      return;
    }
    box.innerHTML = apToolsHtml(apToolsState());
  }

  // --- TELO sekcie: strom + karta ---------------------------------------------

  function apBannerHtml(t){
    var st = t || {};
    if (!st.state || st.state === 'ok') return '';
    return '<div class="hwbanner">' + apIco('alert') + '<span><b>Katalóg spotrebičov je len na čítanie.</b> ' +
           apEsc(st.state_reason || '') + ' Zápisy sú vypnuté, kým sa súbor neopraví.</span></div>';
  }

  function apTreeHtml(t){
    var tree = t || {};
    var groups = tree.groups || [];
    var h = '<div class="aptree">';
    if (!groups.length) h += '<div class="apempty">Katalóg je prázdny.</div>';
    groups.forEach(function(g){
      var closed = AP_CLOSED[g.code] === true;
      h += '<button type="button" class="apgrp' + (closed ? ' off' : '') +
           '" data-ap="grp" data-g="' + apEsc(g.code) + '">' +
           apIco(closed ? 'chevron-right' : 'chevron-down') + apEsc(g.label) +
           '<span class="cnt">' + Number(g.total || 0) + '</span></button>';
      if (closed) return;
      (g.items || []).forEach(function(it){
        h += '<button type="button" class="apitem' + (it.id === AP_SEL ? ' on' : '') +
             (it.deleted ? ' tomb' : '') + '" data-ap="sel" data-id="' + apEsc(it.id) + '">' +
             apEsc(it.title) + '<small>' + apEsc(it.sub) + '</small></button>';
      });
    });
    return h + '</div>';
  }

  // Hodnota riadku karty: neznáme pole je „—" kurzívou (list to nekótuje),
  // odvodená hodnota nesie „(odvodené)". O oboch znamienkach rozhoduje SERVER
  // (`value === null`, `derived`), tu sa len kreslia.
  function apRowHtml(r){
    var row = r || {};
    var v;
    if (row.value == null || row.value === ''){
      v = '<i>— <span class="apnote">(list nekótuje)</span></i>';
    } else {
      v = '<b>' + apEsc(row.value) + (row.unit ? ' ' + apEsc(row.unit) : '') + '</b>';
      if (row.derived) v += ' <span class="apder">(odvodené)</span>';
    }
    return '<span>' + apEsc(row.label) + '</span>' + v;
  }

  function apBlockHtml(b){
    var blk = b || {};
    var rows = blk.rows || [];
    var h = '<div class="apblk"><h5>' + apIco(blk.icon || 'box') + apEsc(blk.title) + '</h5>';
    if (!rows.length){
      h += '<div class="apnote">táto kategória tu nemá kótované polia</div></div>';
      return h;
    }
    h += '<div class="apkv">' + rows.map(apRowHtml).join('') + '</div></div>';
    return h;
  }

  function apLinksHtml(c){
    var card = c || {};
    var shop = card.shop_urls || [];
    var sheets = card.sheet_urls || [];
    if (!shop.length && !sheets.length){
      return '<div class="apblk full"><h5>' + apIco('link') + 'Odkazy</h5>' +
             '<div class="apnote">Žiadne odkazy — doplň ich cez Upraviť.</div></div>';
    }
    var h = '<div class="apblk full"><h5>' + apIco('link') + 'Odkazy</h5><div class="aplinks">';
    if (shop.length){
      h += '<b>obchod</b>' + shop.map(function(u){
        return '<button type="button" class="linkbtn" data-ap="url" data-u="' + apEsc(u.url) + '">' +
               apIco('external-link') + apEsc(u.label) + '</button>';
      }).join('');
    }
    if (sheets.length){
      h += '<b>listy</b>' + sheets.map(function(u){
        return '<button type="button" class="linkbtn" data-ap="url" data-u="' + apEsc(u.url) + '">' +
               apIco('file-text') + apEsc(u.label) + '</button>';
      }).join('');
    }
    return h + '</div></div>';
  }

  // Dlaždica prílohy. Obrázok kreslí miniatúru z cache (kým nedorazí, ostáva
  // ikona — presne ako schéma pri šablónach), PDF má ikonu vždy. Náhľad
  // (`thumbnail`) má teal rám a štítok.
  function apFileHtml(a, thumbs, writable){
    var at = a || {};
    var cache = thumbs || {};
    var png = at.image ? cache[at.id] : null;
    var inner = png ? '<img src="' + apEsc(png) + '" alt="">'
                    : apIco(at.image ? 'image' : 'file-text');
    var h = '<div class="apfile' + (at.thumbnail ? ' main' : '') + '">' +
      '<button type="button" class="apthumb" data-ap="open" data-id="' + apEsc(at.id) + '"' +
      ' title="' + apEsc(at.image ? 'Otvoriť obrázok' : 'Otvoriť v systémovom prehliadači') + '">' +
      inner + '</button>' +
      '<div class="apfn" title="' + apEsc(at.name) + '">' +
      (at.thumbnail ? '<span class="aptag">náhľad</span>' : '') + apEsc(at.name) + '</div>';
    // Pri read-only katalógu sa akcie dlaždice NEKRESLIA vôbec — obe sú zápis
    // a server by ich odmietol (to isté pravidlo ako v hlavičke karty).
    if (writable === false) return h + '</div>';

    h += '<div class="apfacts">';
    if (at.image && !at.thumbnail){
      h += '<button type="button" class="ibtn" data-ap="thumb" data-id="' + apEsc(at.id) + '"' +
           ' title="Nastaviť ako náhľad záznamu" aria-label="Nastaviť ako náhľad">' + apIco('eye') + '</button>';
    }
    h += '<button type="button" class="ibtn" data-ap="unfile" data-id="' + apEsc(at.id) + '"' +
         ' title="Odobrať zo zoznamu (súbor na disku ostáva)" aria-label="Odobrať prílohu">' +
         apIco('trash') + '</button>';
    return h + '</div></div>';
  }

  function apFilesHtml(c, thumbs){
    var card = c || {};
    var items = card.attachments || [];
    var h = '<div class="apblk full"><h5>' + apIco('image') + 'Prílohy ' +
      '<span class="apnote">· súbory na tomto počítači · jeden náhľad</span></h5><div class="apfiles">';
    h += items.map(function(a){ return apFileHtml(a, thumbs, card.writable !== false); }).join('');
    if (card.writable !== false){
      h += '<button type="button" class="apfile add" data-ap="add"' +
           ' title="Systémový dialóg — jeden súbor naraz (PDF, JPG, PNG, WEBP)">' +
           '<span class="apthumb">' + apIco('plus') + '</span><span class="apfn">Pridať</span></button>';
    }
    return h + '</div></div>';
  }

  function apCardHtml(c, thumbs){
    if (!c) return '<div class="apcard empty"><div class="apnote">Vyber model v strome vľavo.</div></div>';
    var card = c;
    var h = '<div class="apcard"><div class="apchead"><h3>' + apEsc(card.name) + '</h3>' +
      '<span class="man">' + apEsc([card.manufacturer, card.category_label].filter(Boolean).join(' · ')) +
      '</span>' + (card.seed ? '<span class="apbadge">seed</span>' : '') +
      (card.deleted ? '<span class="apbadge tomb">vyradený</span>' : '') +
      '<span class="acts">' +
      // S1-B2 (R2): druhé vstupné miesto TOHO ISTÉHO modalu — s modelom už
      // vybraným. Vyradený záznam ponuku nemá (zákazka si ho nepriradí).
      (card.deleted ? ''
        : '<button type="button" class="primary" data-ap="tojob"' +
          ' title="Pridá do tejto zákazky s kópiou rozmerov a výberom vlastníka">' +
          apIco('plus') + ' Do zákazky</button>');
    if (card.writable !== false){
      h += '<button type="button" class="ghostbtn" data-ap="edit" title="Upraviť záznam katalógu">' +
           apIco('pencil') + ' Upraviť</button>';
      h += card.deleted
        ? '<button type="button" class="ghostbtn" data-ap="restore" title="Vrátiť záznam do katalógu">' +
          apIco('rotate-ccw') + ' Obnoviť</button>'
        : '<button type="button" class="ghostbtn danger" data-ap="del"' +
          ' title="Vyradiť z katalógu — prílohy ostávajú" aria-label="Vyradiť">' + apIco('trash') + '</button>';
    }
    h += '</span></div><div class="apbody">';
    (card.blocks || []).forEach(function(b){ h += apBlockHtml(b); });
    h += apLinksHtml(card);
    h += apFilesHtml(card, thumbs);
    if (card.note){
      h += '<div class="apblk full"><h5>' + apIco('info') + 'Poznámka</h5>' +
           '<div class="apnotetext">' + apEsc(card.note) + '</div></div>';
    }
    return h + '</div></div>';
  }

  function apBodyHtml(){
    if (AP_VIEW === 'job') return apJobHtml(AP_JOB);
    return apBannerHtml(AP_TREE) + '<div class="apwrap">' +
           apTreeHtml(AP_TREE) + apCardHtml(AP_CARD, AP_THUMBS) + '</div>';
  }

  // --- S1-B2: TABUĽKA „V zákazke" ---------------------------------------------
  //
  // Riadky, ich poradie, stav aj ceny skladá SERVER (`ui/appliance_dialog.rb`,
  // `job_view`). Tento kód kreslí presne to, čo dostal — NIČ nedopočítava,
  // NIČ nepreskladáva a ani neradí; jediné, čo robí sám, je ZÚŽENIE zoznamu
  // podľa hľadania a kategórie (to je pohľad, nie dáta).

  // Čistá funkcia (Node test): payload + filtre -> riadky na vykreslenie.
  function apJobRows(job, query, category){
    var rows = (job && job.rows) ? job.rows : [];
    var q = String(query == null ? '' : query).trim().toLowerCase();
    var cat = String(category == null ? '' : category);
    return rows.filter(function(r){
      if (cat && String(r.category || '') !== cat) return false;
      if (!q) return true;
      var hay = [r.model, r.model_sub, r.owner_label, r.owner_desc, r.category_label]
        .map(function(x){ return String(x == null ? '' : x).toLowerCase(); }).join(' ');
      return hay.indexOf(q) >= 0;
    });
  }

  function apJobChip(row){
    var tone = String((row && row.tone) || 'info');
    var ic = tone === 'ok' ? 'check' : (tone === 'info' ? 'info' : 'alert');
    var title = row && row.status_title ? ' title="' + apEsc(row.status_title) + '"' : '';
    return '<span class="apchip ' + apEsc(tone) + '"' + title + '>' + apIco(ic) +
           apEsc(row ? row.status_text : '') + '</span>';
  }

  function apJobActsHtml(r){
    var a = r.actions || {};
    var id = apEsc(r.item_id || '');
    var h = '<span class="rowact">';
    if (a.select){
      h += '<button type="button" data-ap="jsel" data-id="' + id + '"' +
           ' title="Označiť vlastníka v modeli" aria-label="Označiť vlastníka">' +
           apIco('eye') + '</button>';
    }
    if (a.edit){
      h += '<button type="button" data-ap="jedit" data-id="' + id + '"' +
           ' title="Upraviť položku (názov, cena, vlastník…)" aria-label="Upraviť položku">' +
           apIco('pencil') + '</button>';
    }
    if (a.shop){
      h += '<button type="button" data-ap="url" data-u="' + apEsc(r.shop_url) + '"' +
           ' title="Otvoriť odkaz na obchod" aria-label="Odkaz na obchod">' +
           apIco('external-link') + '</button>';
    }
    if (a.sheet){
      h += '<button type="button" data-ap="url" data-u="' + apEsc(r.sheet_url) + '"' +
           ' title="Otvoriť technický list" aria-label="Technický list">' +
           apIco('file-text') + '</button>';
    }
    if (a.assign){
      h += '<button type="button" class="linkbtn" data-ap="jassign" data-c="' + apEsc(r.category) +
           '" data-ok="' + apEsc(r.owner.kind) + '" data-oid="' + apEsc(r.owner.id) + '"' +
           ' title="Vybrať model a priradiť ho tomuto vlastníkovi">vybrať…</button>';
    }
    if (a.unbind){
      h += '<button type="button" data-ap="junbind" data-id="' + id + '"' +
           ' title="Odpojiť od vlastníka (ostane v zákazke)" aria-label="Odpojiť">' +
           apIco('unlink') + '</button>';
    }
    if (a.remove){
      h += '<button type="button" data-ap="jdel" data-id="' + id + '"' +
           ' title="Zmazať položku zo zákazky" aria-label="Zmazať položku">' + apIco('trash') + '</button>';
    }
    return h + '</span>';
  }

  function apJobRowHtml(r){
    var warn = r.tone === 'warn';
    var focus = AP_JOB_FOCUS && r.item_id && String(r.item_id) === AP_JOB_FOCUS;
    return '<tr class="apjrow' + (warn ? ' warn' : '') + (focus ? ' focus' : '') + '"' +
      ' data-apjob="' + apEsc(r.item_id || ('x:' + r.owner.kind + ':' + r.owner.id + ':' + r.category)) + '">' +
      '<td><span class="apjcat">' + apIco('appliance') + apEsc(r.category_label) + '</span></td>' +
      '<td class="apjmodel"><b>' + apEsc(r.model) + '</b><small>' + apEsc(r.model_sub) + '</small></td>' +
      '<td class="apjowner"><span class="oid">' + apEsc(r.owner_label) + '</span>' +
      '<span class="odesc">' + apEsc(r.owner_desc) + '</span></td>' +
      '<td>' + apJobChip(r) + '</td>' +
      '<td class="num">' + (r.customer_supplied
        ? '<span class="apchip cust">' + apEsc(r.price_text) + '</span>' : apEsc(r.price_text)) + '</td>' +
      '<td class="acth">' + apJobActsHtml(r) + '</td></tr>';
  }

  function apJobHtml(job){
    if (!job){
      return '<div class="apempty">Zákazka sa ešte nenačítala — otvor Štúdio znova alebo daj „Obnoviť".</div>';
    }
    var rows = apJobRows(job, AP_JOB_Q, AP_JOB_CAT);
    var h = '<table class="bomtab apjob"><thead><tr><th>Kategória</th><th>Model</th>' +
      '<th>Vlastník</th><th>Kontrola</th><th class="num">Cena (Rozpočet)</th>' +
      '<th class="acth"></th></tr></thead><tbody>';
    if (!rows.length){
      h += '<tr><td colspan="6" class="apempty">' +
           ((job.rows || []).length ? 'Filtru nič nezodpovedá.'
             : 'Zákazka zatiaľ žiadny spotrebič nemá — pridaj ho tlačidlom vyššie.') +
           '</td></tr>';
    }
    rows.forEach(function(r){ h += apJobRowHtml(r); });
    h += '</tbody></table>';
    h += '<div class="totrow"><span><b>' + apEsc(job.summary || '') + '</b></span>' +
      '<span class="spacer"></span><span class="tmuted">Rozpočet → </span>' +
      '<button type="button" class="linkbtn" data-ap="jbudget"' +
      ' title="Otvoriť sekciu Rozpočet na spotrebičoch">Spotrebiče a vybavenie: ' +
      apEsc(job.subtotal_text || '—') + ' ' + apIco('external-link') + '</button>' +
      (job.subtotal_included ? '' : '<span class="apnote">(nezapočítané do SPOLU — prepínač v Rozpočte)</span>') +
      '</div>';
    h += '<div class="apnote apjhint">Vlastník podľa kategórie: rúra · mikrovlnka · chladnička = skrinka; ' +
      'umývačka = slot; varná doska · drez = pracovná doska; digestor · iné = len zákazka. ' +
      'Kontrola varuje, nikdy neblokuje. Zákazka drží kópiu rozmerov z katalógu — zmena katalógu ňou nepohne.</div>';
    return h;
  }

  function apRenderBody(){
    var box = apEl('secbody');
    if (!box) return;
    box.innerHTML = apBodyHtml();
    // S1-B2: pohľad „V zákazke" nemá strom, kartu ani modal katalógu, takže
    // si nepýta ani formulár, ani miniatúry — jediný payload, z ktorého
    // kreslí, už v okne je.
    if (AP_VIEW === 'job') return;
    apRequestForm(null);
    apHealFilter();
    // Miniatúry sa pýtajú PO každom vykreslení, nielen po príchode karty
    // (Codex #378 kolo 1 P2): karta s viac než `THUMB_BATCH` obrázkami dostane
    // prvú dávku, a bez tohto volania by sa o zvyšok nikto neprihlásil —
    // dlaždice by ostali na ikone navždy, aj po návrate do sekcie.
    apRequestThumbs();
  }

  // SAMOLIEČBA pohľadu. Filter je stav KLIENTA, strom skladá SERVER — a tie dva
  // sa vedia rozísť: odchod zo sekcie filter zabudne na oboch stranách, ale
  // v okne ostane visieť naposledy vykreslený (zúžený) strom. Pri vstupe do
  // sekcie sa preto porovná, čo strom hovorí, s tým, čo je v lište, a rozdiel
  // sa dorovná jedným dotazom. Bez toho by sa prázdne hľadanie tvárilo, že
  // katalóg má jeden model.
  function apHealFilter(){
    if (!AP_TREE) return false;
    if (String(AP_TREE.query || '') === AP_Q && (AP_TREE.include_deleted === true) === AP_DEL) return false;

    apAskTree();
    return true;
  }

  // --- lazy miniatúry ----------------------------------------------------------

  function apThumbMissing(card){
    var out = [];
    ((card && card.attachments) || []).forEach(function(a){
      if (!a || !a.image) return;
      if (Object.prototype.hasOwnProperty.call(AP_THUMBS, a.id)) return;
      out.push(a.id);
    });
    return out;
  }

  function apCacheKeys(){ return Object.keys(AP_THUMBS); }

  // Server posiela najviac pár miniatúr naraz (dávkovanie), takže sa o zvyšok
  // treba prihlásiť znova. Poistka proti nekonečnému kolu: keď ďalšie kolo
  // NEPRIDALO do cache nič, prestane sa pýtať.
  function apRequestThumbs(){
    if (!AP_CARD || AP_THUMB_WAIT) return false;
    if (!apThumbMissing(AP_CARD).length) return false;
    var size = apCacheKeys().length;
    if (size === AP_THUMB_MARK) return false;
    AP_THUMB_MARK = size;
    AP_THUMB_WAIT = true;
    return apSend('appl_card', { id: AP_CARD.id, thumbs: true, have: apCacheKeys() });
  }

  // --- akcie -------------------------------------------------------------------

  function apAskTree(opts){
    var o = opts || {};
    AP_GEN += 1;
    apSend('appl_tree', { query: AP_Q, include_deleted: AP_DEL, gen: AP_GEN,
                          form: o.form === true });
  }

  // Formulár (polia modalu pre všetky kategórie) sa pýta RAZ za okno —
  // v payloade každého pushu by to boli kilobajty navyše pri každom prepočte.
  // `then` = čo otvoriť, keď dorazí (aby tlačidlo nebolo mŕtve).
  //
  // AUTOMATICKY (pri prvom vykreslení sekcie) sa pýta NAJVIAC RAZ: keby sa
  // pokus opakoval pri každom renderi a odpoveď formulár nepriniesla, sekcia
  // by sa so serverom dohadovala donekonečna. Klik na „Nový spotrebič"
  // je výslovná žiadosť, takže ten sa spýtať smie vždy.
  function apRequestForm(then){
    if (then) AP_FORM_THEN = then;
    if (AP_FORM || AP_FORM_WAIT) return;
    if (!then && AP_FORM_TRIED) return;
    AP_FORM_TRIED = true;
    AP_FORM_WAIT = true;
    apAskTree({ form: true });
  }

  function apOpenPending(){
    var then = AP_FORM_THEN;
    if (!then || !AP_FORM) return;
    AP_FORM_THEN = null;
    apOpenModal(then);
  }

  function apSelect(id){
    AP_SEL = String(id || '');
    AP_THUMB_MARK = -1;
    apSend('appl_card', { id: AP_SEL, thumbs: true, have: apCacheKeys() });
  }

  function apSearch(q){
    AP_Q = String(q == null ? '' : q);
    if (typeof setTimeout !== 'function'){ apAskTree(); return; }
    if (AP_QTIMER != null && typeof clearTimeout === 'function') clearTimeout(AP_QTIMER);
    AP_QTIMER = setTimeout(function(){
      AP_QTIMER = null;
      apAskTree();
    }, AP_Q_DEBOUNCE);
    if (AP_QTIMER && typeof AP_QTIMER.unref === 'function') AP_QTIMER.unref();
  }

  function apToggleDeleted(on){
    AP_DEL = on === true;
    apAskTree();
  }

  function apToggleGroup(code){
    AP_CLOSED[code] = !AP_CLOSED[code];
    if (apIsActive()) apRenderBody();
  }

  // Odchod zo sekcie: zavri modal (žije MIMO tela sekcie, inak by visel nad
  // Kusovníkom) a povedz serveru, aby zabudol filter stromu — najbližší plný
  // push by inak nakreslil strom zúžený hľadaním, ktoré už nikto nevidí.
  function apOnLeaveSection(){
    if (AP_QTIMER != null && typeof clearTimeout === 'function'){
      clearTimeout(AP_QTIMER);
      AP_QTIMER = null;
    }
    // Poistka „posledné kolo nič neprinieslo" platí pre JEDEN pobyt v sekcii.
    // Návrat je nový pokus — inak by sa raz zaseknuté miniatúry už nikdy
    // nedopýtali.
    AP_THUMB_MARK = -1;
    AP_THUMB_WAIT = false;
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    if (m && m.isOpen() && !m.busyLocked()) m.close();
    AP_TOKEN = '';
    AP_Q = '';
    AP_DEL = false;
    // Prisvietený riadok je JEDNORAZOVÁ kotva z Kontroly — po odchode zo
    // sekcie už nemá čo zvýrazňovať. Pohľad (segment) si okno PAMÄTÁ: je to
    // to isté rozhodnutie ako vybraný záznam v strome.
    AP_JOB_FOCUS = '';
    apSend('appl_leave', {});
  }
  if (typeof window !== 'undefined') window.apOnLeaveSection = apOnLeaveSection;

  function apWritable(){
    return !(AP_TREE && AP_TREE.writable === false);
  }

  function apReadOnlyStatus(){
    AP.setStatus((AP_TREE && AP_TREE.state_reason) ||
                 'Katalóg spotrebičov je len na čítanie.', true);
  }

  // --- MAZANIE / OBNOVA --------------------------------------------------------
  //
  // Potvrdenie je D-15 danger modal, NIKDY `UI.messagebox`: natívny modal
  // v callbacku HtmlDialogu blokuje celý kanál okna.
  function apDelete(){
    if (!AP_CARD) return;
    var card = AP_CARD;
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    // FAIL CLOSED (Codex #378 kolo 1 P2): bez kostry D-15 sa NEVYRADI NIC.
    // Fallback „posli to rovno" robil z jedneho kliknutia tombstone bez
    // jedineho potvrdenia — a prave potvrdenie je cely zmysel tohto kroku.
    if (!m || typeof m.open !== 'function'){
      AP.setStatus('Vyradenie potrebuje dialóg Štúdia — zavri a otvor Štúdio znova.', true);
      return;
    }
    m.open({
      title: 'Vyradiť spotrebič',
      sub: 'Model „' + card.name + '" vyradiť z katalógu?',
      note: 'Záznam ostáva v súbore ako vyradený (zobrazí ho prepínač „vyradené") a jeho prílohy ' +
            'sa NEMAŽÚ — zákazky, ktoré model použili, na ne odkazujú. Obnoviť sa dá kedykoľvek.',
      okLabel: 'Vyradiť',
      danger: true,
      fields: [],
      onSubmit: function(){
        m.close();
        apSend('appl_delete', { id: card.id, rev: card.rev });
      }
    });
  }

  function apRestore(){
    if (!AP_CARD) return;
    apSend('appl_restore', { id: AP_CARD.id, rev: AP_CARD.rev });
  }

  // --- MODAL Nový / Upraviť (D-15) ---------------------------------------------

  function apCategoryOptions(){
    return ((AP_TREE && AP_TREE.categories) || []).map(function(c){ return [c[0], c[1]]; });
  }

  function apUrlRows(list){
    return (list || []).map(function(u){ return { url: String(u || '') }; });
  }

  // Polia formulára skladá SERVER (`AP_FORM`), tu sa len prekladajú na
  // špecifikáciu NXModalu. KĽÚČ POĽA je PRESNE tá cesta, ktorú katalóg vracia
  // v chybe (`dims.niche.width_min`), takže `showErrors` posadí hlášku k poľu
  // bez akejkoľvek prekladovej tabuľky.
  function apModalFields(mode, category, values){
    var v = values || {};
    var out = [{ type: 'group', label: 'Identita' },
               { key: 'category', label: 'Kategória', type: 'select',
                 options: apCategoryOptions(), value: category,
                 disabled: mode === 'edit',
                 hint: mode === 'edit' ? 'kategóriu záznamu už nemožno zmeniť' : '' },
               { key: 'manufacturer', label: 'Výrobca', value: v.manufacturer || '',
                 placeholder: 'Bosch, Whirlpool…' },
               { key: 'name', label: 'Model / názov', value: v.name || '',
                 placeholder: 'ako v obchode' }];
    ((AP_FORM && AP_FORM[category]) || []).forEach(function(f){
      if (f.type === 'group'){ out.push({ type: 'group', label: f.label }); return; }
      var field = { key: f.key, label: f.label, value: v[f.key] == null ? '' : v[f.key] };
      if (f.type === 'select'){ field.type = 'select'; field.options = f.options || []; }
      else { field.cls = 'mshort'; field.hint = f.unit || ''; }
      out.push(field);
    });
    out.push({ type: 'group', label: 'Odkazy a listy' });
    out.push({ key: 'shop_urls', type: 'rows', label: 'Obchod', addLabel: 'ďalší odkaz na obchod',
               empty: 'Žiadny odkaz na obchod.',
               cols: [{ key: 'url', label: 'Adresa', placeholder: 'https://…' }],
               value: apUrlRows(v.shop_urls) });
    out.push({ key: 'sheet_urls', type: 'rows', label: 'Technické listy', addLabel: 'ďalší list',
               empty: 'Žiadny technický list.',
               cols: [{ key: 'url', label: 'Adresa', placeholder: 'https://… (URL listu)' }],
               value: apUrlRows(v.sheet_urls) });
    out.push({ type: 'group', label: 'Poznámka' });
    out.push({ key: 'note', label: 'Poznámka', value: v.note || '',
               placeholder: 'čo list hovorí navyše — vetranie, alternatívna nika…' });
    return out;
  }

  // Hodnoty z modalu -> payload pre server. Opakovateľné riadky sa menia na
  // pole reťazcov; prázdne pole ostáva PRÁZDNE (server ho číta ako „zmaž
  // kľúč"), nikdy sa nedopĺňa odhadom.
  function apValuesToFields(values){
    var v = values || {};
    var out = {};
    Object.keys(v).forEach(function(k){
      if (k === 'shop_urls' || k === 'sheet_urls'){
        // Z modalu prídu RIADKY (`[{url}]`), zo servera holé reťazce — tá istá
        // funkcia skladá aj BASELINE otvorenia, takže musí zvládnuť oba tvary.
        // Inak by sa odkazy vždy tvárili ako zmenené.
        out[k] = (v[k] || []).map(function(r){
          return String((r && typeof r === 'object') ? (r.url || '') : (r == null ? '' : r)).trim();
        }).filter(function(s){ return s.length > 0; });
        return;
      }
      out[k] = v[k];
    });
    return out;
  }

  function apNewToken(){
    return 'ap' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  function apOpenModal(mode){
    if (!apWritable()){ apReadOnlyStatus(); return; }
    if (mode === 'edit' && !AP_CARD) return;
    if (!AP_FORM){
      AP.setStatus('Načítavam polia formulára…');
      apRequestForm(mode);
      return;
    }
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    if (!m){
      AP.setStatus('Formulár potrebuje dialóg Štúdia — zavri a otvor Štúdio znova.', true);
      return;
    }
    var card = mode === 'edit' ? AP_CARD : null;
    var category = card ? card.category : (apCategoryOptions()[0] || ['fridge'])[0];
    var values = card ? card.fields : {};
    AP_MODE = mode;
    AP_CARD_EDIT = card;
    AP_TRIGGER = (typeof document !== 'undefined') ? (document.activeElement || null) : null;
    // BASELINE otvorenia. Dve ulohy naraz:
    //   * `AP_BASE_FIELDS` je VYCHODISKOVA specifikacia pre pamat D-15 —
    //     vnutorne prekreslenie (zmena kategorie) ju podava dalej ako
    //     `baseFields`, inak by sa vychodiskom stalo to, co pouzivatel prave
    //     napisal, a `remember()` by na Escape neulozil nic (Codex #378 P2).
    //   * `AP_BASE_VALUES` su hodnoty ZO SERVERA, proti ktorym sa pri ulozeni
    //     pocita, co sa naozaj zmenilo.
    AP_BASE_VALUES = apValuesToFields(values);
    AP_BASE_FIELDS = apModalFields(mode, category, values);
    apOpenModalWith(m, mode, category, values, card, false);
  }

  // Polia, ktore sa LISIA od baseline otvorenia. Patch posiela len tie: modal
  // vracia VSETKY rozmery, takze oprava nazvu by inak prepisala aj cisla,
  // ktorych sa pouzivatel nedotkol — a pri rozmere s dvoma desatinnymi
  // miestami by to bolo tiche zaokruhlenie (Codex #378 kolo 1 P2).
  function apChangedFields(fields, base){
    var b = base || {};
    var out = {};
    Object.keys(fields || {}).forEach(function(k){
      if (apSameValue(fields[k], b[k])) return;
      out[k] = fields[k];
    });
    return out;
  }

  function apSameValue(a, b){
    if (Array.isArray(a) || Array.isArray(b)){
      return JSON.stringify(a || []) === JSON.stringify(b || []);
    }
    return String(a == null ? '' : a) === String(b == null ? '' : b);
  }

  // Zmena kategórie prekresľuje SADU POLÍ (`apOnCategoryChange`). Rozpísané
  // hodnoty spoločných polí sa NESTRÁCAJÚ — prenesú sa do novej špecifikácie
  // (kľúč poľa je tá istá cesta), takže preklik kategórie nie je tichá strata
  // práce. `skipMemory` pri prekreslení je povinné: na obrazovke sú
  // ČERSTVEJŠIE hodnoty než v pamäti konceptu a vliata pamäť by vrátila polia
  // kategórie, ktorú používateľ práve opustil.
  function apOpenModalWith(m, mode, category, values, card, skipMemory){
    m.open({
      title: mode === 'edit' ? 'Upraviť spotrebič' : 'Nový spotrebič',
      sub: 'katalóg · bez ceny (cena patrí zákazke)',
      note: 'Prílohy (listy, obrázky, náhľad) sa pridávajú až v karte uloženého záznamu — po jednom ' +
            'cez systémový dialóg. Neznáme pole nechaj prázdne, nikdy sa nedoplní odhadom.',
      okLabel: mode === 'edit' ? 'Uložiť' : 'Uložiť do katalógu',
      size: 'wide',
      trigger: AP_TRIGGER,
      skipMemory: skipMemory === true,
      // Kostra si `base` inak berie z PRÁVE podanej špecifikácie — pri
      // prekreslení (zmena kategórie) by sa teda východiskom stalo to, čo
      // používateľ napísal, a pamäť rozpísaného konceptu by na Escape
      // neuložila nič. `baseFields` je jediná cesta, ako ju udržať.
      baseFields: AP_BASE_FIELDS || undefined,
      memoryKey: mode === 'edit' ? ('appl:edit:' + (card ? card.id : '')) : 'appl:create',
      fields: apModalFields(mode, category, values),
      onSubmit: function(vals){
        var fields = apValuesToFields(vals);
        if (mode !== 'edit'){
          AP_TOKEN = apNewToken();
          apSend('appl_create', { token: AP_TOKEN, fields: fields });
          return;
        }
        delete fields.category;   // kategóriu už nemožno zmeniť (server to odmietne)
        var changed = apChangedFields(fields, AP_BASE_VALUES);
        if (!Object.keys(changed).length){
          // Prázdny patch by server odmietol ako „nie je čo uložiť" a modal by
          // ostal otvorený s chybou — pritom sa naozaj nič nezmenilo.
          m.setBusy(false, { clear: true });
          m.close();
          AP.setStatus('Nič sa nezmenilo.');
          return;
        }
        var target = AP_CARD_EDIT || card;
        AP_TOKEN = apNewToken();
        apSend('appl_patch', { id: target.id, rev: target.rev, token: AP_TOKEN, fields: changed });
      }
    });
  }

  // Prepnutie kategórie v modale „Nový spotrebič". Kostra D-15 vlastný
  // `onChange` nemá (a pridávať ho kvôli jednej sekcii by znamenalo meniť
  // ZDIEĽANÝ komponent), takže sa počúva `change` na poli `nxm_category`
  // a modal sa prekreslí s prenesenými hodnotami.
  function apOnCategoryChange(category){
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    if (!m || !m.isOpen() || AP_MODE !== 'create') return false;
    apOpenModalWith(m, 'create', String(category || ''), apValuesToFields(m.values()),
                    AP_CARD_EDIT, true);
    return true;
  }

  // --- prílohy -----------------------------------------------------------------

  function apAddAttachment(){
    if (!AP_CARD) return;
    if (!apWritable()){ apReadOnlyStatus(); return; }
    apSend('appl_attach', { id: AP_CARD.id, rev: AP_CARD.rev });
  }

  function apSetThumb(attId){
    if (!AP_CARD) return;
    apSend('appl_thumbnail', { id: AP_CARD.id, attachment_id: attId, rev: AP_CARD.rev });
  }

  function apRemoveAttachment(attId){
    if (!AP_CARD) return;
    apSend('appl_remove_attachment', { id: AP_CARD.id, attachment_id: attId, rev: AP_CARD.rev });
  }

  function apOpenAttachment(attId){
    if (!AP_CARD) return;
    apSend('appl_open_attachment', { id: AP_CARD.id, attachment_id: attId });
  }

  // Adresu otvára SERVER (overí schému a zavolá `UI.openURL`) — v okne nie je
  // žiadny `href`, takže sa HtmlDialog nemôže omylom prenavigovať na cudziu
  // stránku a stratiť celý stav Štúdia.
  function apOpenUrl(url){ apSend('appl_open_url', { url: url }); }

  // --- S1-B2: akcie pohľadu „V zákazke" ---------------------------------------
  //
  // ZÁPISY IDÚ CEZ ROZPOČET. Väzba spotrebiča má JEDEN transakčný vstup
  // (`ApplianceBinding.apply!`) a jeden kanál, ktorým sa k nemu chodí
  // (`budget_mutate` v `budget.js`) — druhý kanál by znamenal druhú sadu
  // guardov, druhý spôsob, ako spraviť krok Späť, a dve miesta, ktoré by sa
  // časom rozišli. `budget.js` beží v TOM ISTOM okne aj scope, takže sa volá
  // priamo; keď tam z akéhokoľvek dôvodu nie je, akcia to POVIE (nikdy ticho).
  function apBudMissing(){
    AP.setStatus('Rozpočet sa nenačítal — zavri a otvor Štúdio znova.', true);
    return false;
  }

  function apJobSend(op, extra){
    if (typeof budSend !== 'function') return apBudMissing();

    budSend(op, extra);
    return true;
  }

  // JEDEN modal pre OBE vstupné miesta (R2): „Pridať do zákazky" v tomto
  // pohľade aj „Do zákazky" v karte katalógu. Je to TEN ISTÝ komponent, aký
  // otvára Rozpočet (`budOpenDraft('appliance')`) — vrátane našepkávača
  // katalógu, ponuky vlastníkov podľa matice a príznaku „dodáva zákazník".
  function apOpenApplDraft(values){
    if (typeof budOpenDraft !== 'function') return apBudMissing();

    budOpenDraft('appliance', values || null);
    return true;
  }

  // Zobrazovaný názov modelu skladá server všade rovnako („výrobca model") —
  // tu sa lepí len preto, že karta nesie obe polia zvlášť; presne ten istý
  // reťazec dá našepkávač katalógu (`appliance_lookup_item`).
  function apCardTitle(card){
    var c = card || {};
    return [String(c.manufacturer || ''), String(c.name || '')]
      .filter(function(x){ return x !== ''; }).join(' ');
  }

  // „Do zákazky" z karty katalógu (R2) = ten istý modal, len s predvyplneným
  // modelom. VYRADENÝ záznam sa nepriraďuje — server ho odmietne
  // (`snapshot_for` -> `:deleted`), takže tlačidlo o tom povie hneď.
  function apCardToJob(){
    var card = AP_CARD;
    if (!card){ AP.setStatus('Vyber model v strome vľavo.', true); return false; }
    if (card.deleted){
      AP.setStatus('Vyradený model sa do zákazky nepriraďuje — najprv ho obnov.', true);
      return false;
    }
    var title = apCardTitle(card);
    return apOpenApplDraft({ catalog_id: card.id, catalog_text: title,
                             typ: card.category, nazov: title,
                             dodavatel: String(card.manufacturer || '') });
  }

  function apJobRow(id){
    var rows = (AP_JOB && AP_JOB.rows) ? AP_JOB.rows : [];
    var found = null;
    rows.forEach(function(r){ if (String(r.item_id || '') === String(id || '')) found = r; });
    return found;
  }

  // „Oko": označenie vlastníka v modeli. Identitu (druh + ID + PID) posiela
  // SERVER v riadku — klient si ju nikdy neskladá z textu.
  function apJobSelect(id){
    var r = apJobRow(id);
    if (!r || !r.owner) return false;

    return apSend('appl_job_select', { kind: r.owner.kind, id: r.owner.id, pid: r.owner.pid,
                                       model_guid: AP_JOB_DOC.guid, gen: AP_JOB_DOC.gen });
  }

  function apJobUnbind(id){
    return apJobSend('appliance_owner', { id: id, owner: { kind: 'job', id: '', pid: null } });
  }

  // Zmazanie položky = D-15 DANGER potvrdenie (rovnaký kontrakt ako vyradenie
  // z katalógu). Viazanú položku odpojí SERVER v tej istej operácii
  // (`ApplianceBinding` op `remove`), takže je to jeden krok Späť.
  function apJobDelete(id){
    var r = apJobRow(id);
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    if (!r) return false;
    if (!m || typeof m.open !== 'function'){
      AP.setStatus('Mazanie potrebuje dialóg Štúdia — zavri a otvor Štúdio znova.', true);
      return false;
    }
    m.open({
      title: 'Zmazať zo zákazky',
      sub: 'Položku „' + r.model + '" odstrániť z rozpočtu?',
      note: (r.actions && r.actions.unbind)
        ? 'Spotrebič sa zároveň odpojí od vlastníka — jedna zmena, jeden krok Späť.'
        : 'Riadok zmizne z rozpočtu aj z cenovej ponuky. Vrátiť sa dá krokom Späť.',
      okLabel: 'Zmazať', danger: true, fields: [],
      onSubmit: function(){
        m.close();
        apJobSend('appliance_remove', { id: id });
      }
    });
    return true;
  }

  function apJobBudget(){
    if (typeof studioGoSection === 'function') studioGoSection('budget');
    if (typeof budGoto === 'function') budGoto('appliances');
  }

  function apJobSearch(text){
    AP_JOB_Q = String(text == null ? '' : text);
    if (apIsActive()) apRenderBody();
    return AP_JOB_Q;
  }

  function apJobFilter(code){
    AP_JOB_CAT = String(code == null ? '' : code);
    if (apIsActive()) apRenderBody();
    return AP_JOB_CAT;
  }

  function apSetView(view){
    var v = view === 'job' ? 'job' : 'cat';
    if (AP_VIEW === v) return false;

    AP_VIEW = v;
    if (v !== 'job') AP_JOB_FOCUS = '';
    if (apIsActive()){ apRenderTools(); apRenderBody(); }
    return true;
  }

  // DEEP-LINK z Kontroly (`route: 'appl'`, kotva `appliance:<uuid>`): prepne
  // pohľad na „V zákazke" a riadok prisvieti. Riadok, ktorý medzitým zanikol,
  // NIE JE tichý no-op — volajúci (studio.js) to povie nahlas.
  function apOpenAnchor(anchor){
    var raw = String(anchor == null ? '' : anchor);
    if (raw.indexOf('appliance:') !== 0) return false;

    var id = raw.slice('appliance:'.length);
    AP_VIEW = 'job';
    AP_JOB_FOCUS = id;
    AP_JOB_Q = '';
    AP_JOB_CAT = '';
    if (apIsActive()){ apRenderTools(); apRenderBody(); }
    if (!apJobRow(id)) return false;

    var el = (typeof document !== 'undefined')
      ? document.querySelector('[data-apjob="' + id + '"]') : null;
    if (el && el.scrollIntoView) el.scrollIntoView({ block: 'center' });
    return true;
  }
  if (typeof window !== 'undefined') window.apOpenAnchor = apOpenAnchor;

  // --- listenery ---------------------------------------------------------------

  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(ev){
      if (!apIsActive()) return;
      var t = ev.target;
      if (!t || !t.closest) return;
      var act = t.closest('[data-ap]');
      if (!act) return;
      var a = act.getAttribute('data-ap');
      var id = act.getAttribute('data-id');
      if (a === 'view'){ apSetView(act.getAttribute('data-v')); return; }
      // S1-B2: riadky pohľadu „V zákazke".
      if (a === 'jadd'){ apOpenApplDraft(null); return; }
      if (a === 'jassign'){
        apOpenApplDraft({ typ: act.getAttribute('data-c'),
                          owner: act.getAttribute('data-ok') + ':' + act.getAttribute('data-oid') });
        return;
      }
      if (a === 'jsel'){ apJobSelect(id); return; }
      if (a === 'jedit'){
        if (typeof budOpenApplEdit === 'function') budOpenApplEdit(id);
        else apBudMissing();
        return;
      }
      if (a === 'junbind'){ apJobUnbind(id); return; }
      if (a === 'jdel'){ apJobDelete(id); return; }
      if (a === 'jbudget'){ apJobBudget(); return; }
      if (a === 'grp'){ apToggleGroup(act.getAttribute('data-g')); return; }
      if (a === 'sel'){ apSelect(id); return; }
      if (a === 'new'){ apOpenModal('create'); return; }
      if (a === 'edit'){ apOpenModal('edit'); return; }
      if (a === 'del'){ apDelete(); return; }
      if (a === 'restore'){ apRestore(); return; }
      if (a === 'add'){ apAddAttachment(); return; }
      if (a === 'thumb'){ apSetThumb(id); return; }
      if (a === 'unfile'){ apRemoveAttachment(id); return; }
      if (a === 'open'){ apOpenAttachment(id); return; }
      if (a === 'tojob'){ apCardToJob(); return; }
      if (a === 'url'){ apOpenUrl(act.getAttribute('data-u')); }
    });

    document.addEventListener('input', function(ev){
      if (!apIsActive()) return;
      var t = ev.target;
      if (!t) return;
      // S1-B2: hľadanie v tabuľke je ČISTO klientske — žiadny dotaz, žiadny
      // debounce, len prekreslenie tela (lišta ostáva, inak by pole stratilo
      // fokus pri každom písmene).
      if (t.id === 'apJobQ'){ apJobSearch(t.value); return; }
      if (t.id !== 'apQ') return;
      apSearch(t.value);
    });

    document.addEventListener('change', function(ev){
      if (!apIsActive()) return;
      var t = ev.target;
      if (!t) return;
      if (t.id === 'apDel'){ apToggleDeleted(t.checked === true); return; }
      if (t.id === 'apJobCat'){ apJobFilter(t.value); return; }
      // Kategória v modale „Nový spotrebič" mení SADU POLÍ.
      if (t.id === 'nxm_category') apOnCategoryChange(t.value);
    });
  }

  // Prvotný stav sekcie z payloadu Štúdia (`ST.appl`). Strom je malý JSON,
  // takže chodí celý; KARTU si sekcia pýta sama. Vlastné (novšie) echo sa
  // NEPREPISUJE: plný push nesie filter, ktorý server pozná, takže generácia
  // rozhodne rovnako ako pri odpovedi na hľadanie.
  function apApplyState(t){
    if (!t) return;
    apSetTree(t);
  }

  // Identita payloadu, ktorý tabuľku priniesol. Drží sa TU (nie v `AP_JOB`):
  // je to vlastnosť PUSHU, nie dát — a s ňou odchádza aj platnosť akcií
  // pohľadu (Codex #383 kolo 1 P2).
  function apSetJobDoc(data){
    var d = data || {};
    AP_JOB_DOC = { guid: String(d.model_guid || ''), gen: Number(d.gen || 0) };
    return AP_JOB_DOC;
  }

  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var apPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      // PORADIE: identita sa preberá PRED dosadením tabuľky — obe patria
      // k tomu istému pushu a akcia sa nesmie odoslať s identitou minulého.
      apSetJobDoc(data);
      apApplyState(data && data.appl);
      apPrevSetStudio(data);
    };
  }

  // Node testy (tests/js/test_s1a2_sekcia.js) — ČISTÉ funkcie bez DOM
  // (`apToolsHtml`, `apTreeHtml`, `apCardHtml`, `apRowHtml`, `apModalFields`,
  // `apValuesToFields`) + prijímače a stavové prepínače, ktoré sa inak
  // nedajú overiť ničím než klikaním.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = {
      apToolsHtml: apToolsHtml, apToolsState: apToolsState, apCountLabel: apCountLabel,
      apTreeHtml: apTreeHtml, apCardHtml: apCardHtml, apRowHtml: apRowHtml,
      apBlockHtml: apBlockHtml, apFileHtml: apFileHtml, apBannerHtml: apBannerHtml,
      apBodyHtml: apBodyHtml, apRenderBody: apRenderBody, apRenderTools: apRenderTools,
      apModalFields: apModalFields, apValuesToFields: apValuesToFields,
      apChangedFields: apChangedFields,
      apApplyState: apApplyState, apIsActive: apIsActive,
      apRequestThumbs: apRequestThumbs, apThumbMissing: apThumbMissing,
      apHealFilter: apHealFilter,
      apSelect: apSelect, apSearch: apSearch, apToggleDeleted: apToggleDeleted,
      apToggleGroup: apToggleGroup, apOnLeaveSection: apOnLeaveSection,
      // S1-B2: pohľad „V zákazke" (tests/js/test_s1b2_pohlad.js). Čisté
      // funkcie (`apJobHtml`, `apJobRowHtml`, `apJobRows`, `apViewSegHtml`,
      // `apJobToolsHtml`, `apCardTitle`) + prepínače pohľadu a akcie riadku,
      // ktoré sa inak nedajú overiť ničím než klikaním.
      apJobHtml: apJobHtml, apJobRowHtml: apJobRowHtml, apJobRows: apJobRows,
      apJobToolsHtml: apJobToolsHtml, apViewSegHtml: apViewSegHtml,
      apJobChip: apJobChip, apJobActsHtml: apJobActsHtml, apCardTitle: apCardTitle,
      apSetView: apSetView, apJobSearch: apJobSearch, apJobFilter: apJobFilter,
      apSetJobDoc: apSetJobDoc,
      apJobSelect: apJobSelect, apJobUnbind: apJobUnbind, apJobDelete: apJobDelete,
      apJobRow: apJobRow, apCardToJob: apCardToJob, apOpenApplDraft: apOpenApplDraft,
      apOpenAnchor: apOpenAnchor, apJobBudget: apJobBudget,
      apOpenModal: apOpenModal, apDelete: apDelete, apOnCategoryChange: apOnCategoryChange,
      apSetTree: apSetTree, apSetCard: apSetCard, apResult: apResult,
      apState: function(){
        return { sel: AP_SEL, q: AP_Q, deleted: AP_DEL, gen: AP_GEN, seen: AP_SEEN,
                 token: AP_TOKEN, thumbs: AP_THUMBS, form: AP_FORM,
                 tree: AP_TREE, card: AP_CARD,
                 view: AP_VIEW, job: AP_JOB, jobQuery: AP_JOB_Q, jobCat: AP_JOB_CAT,
                 jobFocus: AP_JOB_FOCUS, jobDoc: AP_JOB_DOC };
      },
      apReset: function(){
        AP_VIEW = 'cat'; AP_JOB = null; AP_JOB_Q = ''; AP_JOB_CAT = ''; AP_JOB_FOCUS = '';
        AP_JOB_DOC = { guid: '', gen: 0 };
        AP_TREE = null; AP_CARD = null; AP_FORM = null; AP_FORM_WAIT = false;
        AP_FORM_TRIED = false; AP_FORM_THEN = null;
        AP_SEL = ''; AP_Q = ''; AP_DEL = false; AP_GEN = 0; AP_SEEN = -1;
        AP_CLOSED = {}; AP_THUMBS = {}; AP_THUMB_WAIT = false; AP_THUMB_MARK = -1;
        AP_TOKEN = ''; AP_MODE = ''; AP_CARD_EDIT = null; AP_TRIGGER = null;
        AP_BASE_FIELDS = null; AP_BASE_VALUES = {};
        if (AP_QTIMER != null && typeof clearTimeout === 'function') clearTimeout(AP_QTIMER);
        AP_QTIMER = null;
      },
      apSetToken: function(t){ AP_TOKEN = String(t || ''); },
      AP: AP
    };
  }
