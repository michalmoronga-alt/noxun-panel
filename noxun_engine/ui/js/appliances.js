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
  var AP_QTIMER = null;
  var AP_Q_DEBOUNCE = 200;

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
    AP_TREE = p;
    // Kolo dotazu je vybavené bez ohľadu na to, či formulár naozaj prišiel —
    // inak by jediná stratená odpoveď nechala príznak „čaká sa" navždy
    // a tlačidlo „Nový spotrebič" by už nikdy nič neotvorilo.
    AP_FORM_WAIT = false;
    if (p.form) AP_FORM = p.form;
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
    if (!apIsActive()) return;
    apRenderBody();
    apRequestThumbs();
  }

  // VÝSLEDOK ZÁPISU pre modal (D-15). Prijíma sa LEN odpoveď na TOTO odoslanie
  // (`token`) — výsledok formulára, ktorý používateľ medzitým zavrel a otvoril
  // iný, by mu inak zavrel rozpísaný koncept.
  function apResult(ok, msg, errors, op, token){
    if (!AP_TOKEN || String(token || '') !== AP_TOKEN) return;
    AP_TOKEN = '';
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
    return { query: AP_Q, deleted: AP_DEL,
             total: Number(t.total || 0), seed: Number(t.seed_total || 0),
             writable: t.writable !== false };
  }

  // Čistá funkcia (Node test). Pohľad „V zákazke" je `aria-disabled` — nie
  // `disabled`: klik naň POVIE DÔVOD (D-78), zatiaľ čo HTML `disabled` by ho
  // vyhodilo z Tab poradia a mlčalo by.
  function apToolsHtml(s){
    var st = s || {};
    var h = '<div class="bomviews">' +
      '<button type="button" class="bomvw" data-ap="view" data-v="job" aria-disabled="true"' +
      ' title="Pohľad V zákazke — príde v S1-B (väzba spotrebiča na skrinku)">V zákazke</button>' +
      '<button type="button" class="bomvw on" data-ap="view" data-v="cat">Katalóg</button></div>';
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
      '<button type="button" class="primary" data-ap="tojob" aria-disabled="true"' +
      ' title="Pridanie do zákazky príde v S1-B (väzba na skrinku, kópia rozmerov)">' +
      apIco('plus') + ' Do zákazky</button>';
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
    return apBannerHtml(AP_TREE) + '<div class="apwrap">' +
           apTreeHtml(AP_TREE) + apCardHtml(AP_CARD, AP_THUMBS) + '</div>';
  }

  function apRenderBody(){
    var box = apEl('secbody');
    if (!box) return;
    box.innerHTML = apBodyHtml();
    apRequestForm(null);
    apHealFilter();
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
    var m = (typeof window !== 'undefined') ? window.NXModal : null;
    if (m && m.isOpen() && !m.busyLocked()) m.close();
    AP_TOKEN = '';
    AP_Q = '';
    AP_DEL = false;
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
    if (!m){
      apSend('appl_delete', { id: card.id, rev: card.rev });
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
        out[k] = (v[k] || []).map(function(r){ return String((r && r.url) || '').trim(); })
                             .filter(function(s){ return s.length > 0; });
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
    apOpenModalWith(m, mode, category, values, card, false);
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
      memoryKey: mode === 'edit' ? ('appl:edit:' + (card ? card.id : '')) : 'appl:create',
      fields: apModalFields(mode, category, values),
      onSubmit: function(vals){
        AP_TOKEN = apNewToken();
        var fields = apValuesToFields(vals);
        if (mode === 'edit'){
          delete fields.category;   // kategóriu už nemožno zmeniť (server to odmietne)
          apSend('appl_patch', { id: card.id, rev: card.rev, token: AP_TOKEN, fields: fields });
        } else {
          apSend('appl_create', { token: AP_TOKEN, fields: fields });
        }
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
      if (a === 'view'){
        if (act.getAttribute('data-v') === 'job'){
          AP.setStatus('Pohľad „V zákazke" príde v dávke S1-B — vtedy sa spotrebič naviaže na skrinku.', true);
        }
        return;
      }
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
      if (a === 'tojob'){
        AP.setStatus('Pridanie do zákazky príde v dávke S1-B (väzba na skrinku a kópia rozmerov).', true);
        return;
      }
      if (a === 'url'){ apOpenUrl(act.getAttribute('data-u')); }
    });

    document.addEventListener('input', function(ev){
      if (!apIsActive()) return;
      var t = ev.target;
      if (!t || t.id !== 'apQ') return;
      apSearch(t.value);
    });

    document.addEventListener('change', function(ev){
      if (!apIsActive()) return;
      var t = ev.target;
      if (!t) return;
      if (t.id === 'apDel'){ apToggleDeleted(t.checked === true); return; }
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

  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var apPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
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
      apApplyState: apApplyState, apIsActive: apIsActive,
      apRequestThumbs: apRequestThumbs, apThumbMissing: apThumbMissing,
      apHealFilter: apHealFilter,
      apSelect: apSelect, apSearch: apSearch, apToggleDeleted: apToggleDeleted,
      apToggleGroup: apToggleGroup, apOnLeaveSection: apOnLeaveSection,
      apOpenModal: apOpenModal, apDelete: apDelete, apOnCategoryChange: apOnCategoryChange,
      apSetTree: apSetTree, apSetCard: apSetCard, apResult: apResult,
      apState: function(){
        return { sel: AP_SEL, q: AP_Q, deleted: AP_DEL, gen: AP_GEN, seen: AP_SEEN,
                 token: AP_TOKEN, thumbs: AP_THUMBS, form: AP_FORM,
                 tree: AP_TREE, card: AP_CARD };
      },
      apReset: function(){
        AP_TREE = null; AP_CARD = null; AP_FORM = null; AP_FORM_WAIT = false;
        AP_FORM_TRIED = false; AP_FORM_THEN = null;
        AP_SEL = ''; AP_Q = ''; AP_DEL = false; AP_GEN = 0; AP_SEEN = -1;
        AP_CLOSED = {}; AP_THUMBS = {}; AP_THUMB_WAIT = false; AP_THUMB_MARK = -1;
        AP_TOKEN = ''; AP_MODE = ''; AP_CARD_EDIT = null; AP_TRIGGER = null;
        if (AP_QTIMER != null && typeof clearTimeout === 'function') clearTimeout(AP_QTIMER);
        AP_QTIMER = null;
      },
      apSetToken: function(t){ AP_TOKEN = String(t || ''); },
      AP: AP
    };
  }
