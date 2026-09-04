  // ===================== Katalog kovania (V0.6 C-2) =====================
  // Server (Ruby) je autorita: search poradie, hodnoty, revizie. JS len
  // renderuje a posiela flagy/payloady s row_rev. XSS kontrakt (vzor
  // demos_diff.js): obsah VYHRADNE createElement + textContent; ovladanie
  // data-action delegaciou; ziadne innerHTML s datami, ziadne inline
  // handlery s hodnotami. Cenove overenie = serverovy proposal (JS posiela
  // len kod; hodnotu nikdy).

  var MDH_ITEMS = {};   // item_code -> zaznam (s row_rev)
  var MDH_ORDER = [];   // poradie zo SERVEROVEHO searchu (F12)
  // TEST-1: koľko zhôd server NAŠIEL vs. koľko ich POSLAL. Keď sa čísla líšia,
  // zoznam je orezaný a MUSÍ to byť vidieť — nová položka inak zmizne bez
  // slova (zásada „no silent caps").
  var MDH_TOTAL = 0;
  var MDH_SHOWN = 0;
  // Kód práve založenej položky. Klient ho NEZARAĎUJE sám (poradie skladá
  // server — kontrakt GH #100 P2): pošle ho v `pin`, server ju dá navrch.
  //
  // Sú to ZÁMERNE DVA držiaky (review #229 P2):
  //   `MDH_PIN_REQ` = ŽIADOSŤ a je JEDNORAZOVÁ — spotrebuje ju najbližší
  //      dotaz a hneď sa zabudne. Bez toho by sa posielala pri KAŽDOM ďalšom
  //      hľadaní a nesúvisiaci dotaz (iný text, iná kategória, prepnuté
  //      neaktívne) by ďalej ukazoval a zvýrazňoval novú položku navrchu,
  //      hoci filtru nevyhovuje — a to až do znovuotvorenia okna.
  //   `MDH_PIN` = to, čo server POTVRDIL pre PRÁVE VYKRESLENÝ zoznam; slúži
  //      len na zvýraznenie riadku a s ďalšou odpoveďou prirodzene zhasne.
  var MDH_PIN_REQ = '';
  var MDH_PIN = '';
  var MDH_CATS = [];
  var MDH_UNITS = [];
  var MDH_RO = false;
  var MDH_OPEN = null;  // rozbaleny detail (item_code)
  var MDH_PRICE = {};   // item_code -> posledny priceResult (len UX render)
  var MDH_DEL = null;   // kod cakajuci na potvrdenie zmazania
  var mdhSearchTimer = null;
  var MDH_VERSION = '';     // verzia do podtitulu okna
  var MDH_RO_REASON = '';   // dovod read-only rezimu (banner)
  // ŠT-3a-1: v SEKCII Studia telo este nemusi byt v DOM (uzol sa pripaja az
  // pri prvom vykresleni sekcie). Serverove poradie sa vtedy nevypytava —
  // vypyta si ho `hwRenderBody`, ked telo naozaj pripoji.
  var MDH_ORDER_PENDING = false;

  // --- KOV-B2: SERVEROVY STROM (Kategoria -> Vyrobca -> Rada) ---------------
  // `MDH_TREE` je POSLEDNA ODPOVED servera a kresli sa PRESNE ona: poradie
  // skupin, vyrobcov, rad aj kodov sklada server (kontrakt „JS poradie nikdy
  // nedopĺňa"). Klient posiela len to, CO CHCE VIDIEŤ — rozbalene uzly
  // (`HW_EXPAND`) a ziadost o dalsiu stranku listu (`HW_MORE`).
  //
  // `MDH_TREE_GEN` je generacia dotazu: hladanie je debounced a odpovede
  // chodia asynchronne, takze pomalsie kolo by inak prepisalo cerstvejsi strom
  // (vzor `seq` naseptavaca v `nx_modal.js`).
  var MDH_TREE = null;
  var MDH_TREE_GEN = 0;
  var MDH_LEAF_PAGE = 50;   // server ho posiela v odpovedi (`leaf_page`)
  // SK popisky kategorii zo servera (`CATEGORY_LABELS`) — jediny zdroj.
  var MDH_LABELS = {};
  // Taxonomia vyrobcov a rad pre selecty modalu polozky.
  var MDH_TAX = { manufacturers: [], series: [], read_only: false, state_reason: '' };

  function hwEl(id){ return document.getElementById(id); }
  function mdhMk(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  // GH #100 P2: kody su volny text — do CSS selektora VZDY cez escape
  // (spatne lomitko/uvodzovka by selektor rozbila alebo zmenila).
  function mdhCssEscape(s){
    var v = String(s == null ? '' : s);
    if (typeof CSS !== 'undefined' && CSS.escape) return CSS.escape(v);
    return v.replace(/[^a-zA-Z0-9_-]/g, function(c){ return "\\" + c; });
  }

  // --- ciste funkcie (Node testy) -----------------------------------------

  function mdhFmtPrice(v){
    return (v === null || v === undefined) ? '—'
      : (Math.round(Number(v) * 100) / 100).toFixed(2) + ' €';
  }
  // ISO8601 -> "overené 1.8.2026"; prazdne/zle -> null (nezobrazovat).
  function mdhCheckedLabel(iso){
    var m = /^(\d{4})-(\d{2})-(\d{2})T/.exec(String(iso || ''));
    if (!m) return null;
    return 'overené ' + parseInt(m[3], 10) + '.' + parseInt(m[2], 10) + '.' + m[1];
  }
  // Patch payload — LEN pole+hodnota+row_rev (server whitelist je autorita).
  function mdhPatchPayload(code, rowRev, field, value){
    var patch = {};
    patch[field] = value;
    return { code: code, patch: patch, row_rev: rowRev || '' };
  }
  // TEST-1: text o orezanom zozname. `null` = nič sa neorezalo (a vtedy sa
  // NIČ nevypisuje — hlásiť „zobrazených 12 z 12" je šum).
  function mdhCapHint(total, shown){
    var t = Number(total) || 0;
    var sh = Number(shown) || 0;
    if (!t || !sh || t <= sh) return null;
    return 'Zobrazených ' + sh + ' z ' + t + ' položiek — hľadaj alebo filtruj kategóriou.';
  }

  // Zoradenie poloziek podla SERVEROVEHO poradia kodov (neznamy kod sa
  // vynecha — polozka medzitym zmizla).
  function mdhOrderItems(map, codes){
    var out = [];
    (codes || []).forEach(function(c){ if (map[c]) out.push(map[c]); });
    return out;
  }
  // --- komunikacia so serverom --------------------------------------------

  function mdhSend(name, payload){
    if (window.sketchup && sketchup[name]) sketchup[name](JSON.stringify(payload));
  }

  // KOV-B2: pohlad Polozky si pyta STROM (`hw_tree`) — ploche `hw_search` ho
  // v Studiu nahradilo (serverova akcia ostava ako verejny kontrakt katalogu
  // a jej prijimac `MDH.results` tiez).
  //
  // ŠT-3a-1: v SEKCII ziju filtre v LISTE, a tá NIE JE vykreslena, kym je
  // otvoreny pohlad Sety. Bez fallbacku na stav by vtedy kazdy push poslal
  // PRAZDNY dotaz — a navrat do pohladu Položky by ukazal nefiltrovany zoznam
  // pod vyplnenym polom hladania.
  function mdhTreeNow(){
    var s = hwEl('hwSearch');
    var c = hwEl('hwCategory');
    var i = hwEl('hwInactive');
    MDH_TREE_GEN++;
    mdhSend('hw_tree', {
      query: s ? (s.value || '') : HW_Q,
      category: c ? (c.value || '') : HW_CAT,
      include_inactive: i ? !!i.checked : HW_INACTIVE,
      pin: MDH_PIN_REQ,
      expand: HW_EXPAND,
      more: HW_MORE,
      gen: MDH_TREE_GEN
    });
    // Žiadosť je spotrebovaná — ďalšie hľadanie už ide bez nej.
    MDH_PIN_REQ = '';
  }

  function mdhSearchDebounced(){
    if (mdhSearchTimer) clearTimeout(mdhSearchTimer);
    mdhSearchTimer = setTimeout(mdhTreeNow, 150);
  }

  // --- render --------------------------------------------------------------

  function mdhCellInput(item, field, value, ph, cls){
    var inp = mdhMk('input', 'mdcell ' + (cls || ''));
    inp.type = 'text';
    inp.value = value == null ? '' : String(value);
    inp.placeholder = ph || '';
    if (MDH_RO) inp.readOnly = true;
    inp.setAttribute('data-hw-code', item.item_code);
    inp.setAttribute('data-hw-field', field);
    inp.setAttribute('data-hw-rev', item.row_rev || '');
    inp.setAttribute('data-orig', inp.value);
    return inp;
  }

  // `label` je volitelny prevod hodnoty na to, co pouzivatel CITA (kategorie
  // maju SK popisky, MJ su same o sebe citatelne) — hodnota ostava kodom.
  function mdhSelect(item, field, options, current, label){
    var sel = mdhMk('select');
    options.forEach(function(o){
      var op = mdhMk('option', null, label ? label(o) : o);
      op.value = o;
      sel.appendChild(op);
    });
    sel.value = current;
    if (MDH_RO) sel.disabled = true;
    sel.setAttribute('data-hw-code', item.item_code);
    sel.setAttribute('data-hw-field', field);
    sel.setAttribute('data-hw-rev', item.row_rev || '');
    return sel;
  }

  function mdhRow(item){
    var row = mdhMk('div', 'mdvrow hwrow' + (item.active === false ? ' hwoff' : ''));
    row.setAttribute('data-hw-row', item.item_code);
    var head = mdhMk('span', 'mdvdim');
    // GH #100 P1: sprite ikona namiesto Unicode glyfu (UI_DIZAJN — ziadne
    // glyfy v ovladacich prvkoch); otvoreny stav rotuje chevron CSS triedou.
    var toggle = mdhMk('button', 'ghostbtn tplbtn hwtoggle' + (MDH_OPEN === item.item_code ? ' hwopen' : ''));
    toggle.innerHTML = '<svg class="ic" aria-hidden="true"><use href="#i-chevron-right"/></svg>';
    toggle.setAttribute('data-action', 'hw-toggle');
    toggle.setAttribute('data-hw-code', item.item_code);
    toggle.setAttribute('aria-label', 'Detail položky');
    toggle.setAttribute('aria-expanded', MDH_OPEN === item.item_code ? 'true' : 'false');
    head.appendChild(toggle);
    head.appendChild(mdhMk('b', null, item.item_code));
    row.appendChild(head);
    row.appendChild(mdhCellInput(item, 'name_sk', item.name_sk, 'názov', 'hwname'));
    row.appendChild(mdhMk('span', 'hwunit', item.unit));
    row.appendChild(mdhCellInput(item, 'price_eur_vat', item.price_eur_vat, '—', 'mdvp'));
    row.appendChild(mdhCellInput(item, 'supplier', item.supplier, 'dodávateľ', ''));
    return row;
  }

  function mdhDetail(item){
    var box = mdhMk('div', 'hwdetail');
    var line1 = mdhMk('div', 'tplrow');
    line1.appendChild(mdhMk('span', 'tplt', 'Kategória'));
    line1.appendChild(mdhSelect(item, 'category', MDH_CATS, item.category, mdhCatLabel));
    line1.appendChild(mdhMk('span', 'tplt', 'MJ'));
    line1.appendChild(mdhSelect(item, 'unit', MDH_UNITS, item.unit));
    var act = mdhMk('label', 'hwinactive');
    var cb = mdhMk('input');
    cb.type = 'checkbox';
    cb.checked = item.active !== false;
    if (MDH_RO) cb.disabled = true;
    cb.setAttribute('data-hw-code', item.item_code);
    cb.setAttribute('data-hw-field', 'active');
    cb.setAttribute('data-hw-rev', item.row_rev || '');
    act.appendChild(cb);
    act.appendChild(mdhMk('span', null, 'aktívna'));
    line1.appendChild(act);
    // KOV-B2: úprava celej položky ide cez modal (D-15) — inline bunky
    // ostávajú pre rýchlu opravu názvu a ceny priamo v riadku.
    var edit = mdhMk('button', 'ghostbtn tplbtn', 'Upraviť');
    edit.setAttribute('data-action', 'hw-edit');
    edit.setAttribute('data-hw-code', item.item_code);
    edit.setAttribute('title', 'Upraviť položku (kód, názov, cena, výrobca, rada)');
    if (MDH_RO) edit.disabled = true;
    line1.appendChild(edit);
    var del = mdhMk('button', 'ghostbtn tpldel', 'Zmazať');
    del.setAttribute('data-action', 'hw-del');
    del.setAttribute('data-hw-code', item.item_code);
    if (MDH_RO) del.disabled = true;
    line1.appendChild(del);
    box.appendChild(line1);
    var line2 = mdhMk('div', 'tplrow');
    line2.appendChild(mdhMk('span', 'tplt', 'Poznámka'));
    line2.appendChild(mdhCellInput(item, 'notes', item.notes, '—', 'hwnotes'));
    box.appendChild(line2);
    // Demos vazba + overenie ceny (serverovy proposal; use_count pride v D)
    var line3 = mdhMk('div', 'tplrow');
    line3.appendChild(mdhMk('span', 'tplt', 'Demos'));
    var url = mdhMk('input', 'hwurl');
    url.type = 'text';
    url.placeholder = item.demos_url || 'https://www.demos-trade.sk/…';
    url.value = item.demos_url || '';
    url.setAttribute('data-hw-url', item.item_code);
    line3.appendChild(url);
    var check = mdhMk('button', 'ghostbtn tplbtn', 'Overiť cenu');
    check.setAttribute('data-action', 'hw-check');
    check.setAttribute('data-hw-code', item.item_code);
    if (MDH_RO) check.disabled = true;
    line3.appendChild(check);
    if (item.demos_url){
      // GH #100 P2: ulozena vazba sa da VYMAZAT (zla URL by inak ostala navzdy
      // — prazdny input server chape ako "pouzi ulozenu").
      var clr = mdhMk('button', 'ghostbtn tpldel', 'Zrušiť väzbu');
      clr.setAttribute('data-action', 'hw-url-clear');
      clr.setAttribute('data-hw-code', item.item_code);
      if (MDH_RO) clr.disabled = true;
      line3.appendChild(clr);
    }
    box.appendChild(line3);
    var checked = mdhCheckedLabel(item.price_checked_at);
    if (checked) box.appendChild(mdhMk('div', 'mans', 'cena ' + checked));
    var pr = MDH_PRICE[item.item_code];
    if (pr){
      var line4 = mdhMk('div', 'tplrow hwprice');
      if (pr.status === 'proposal'){
        line4.appendChild(mdhMk('span', null,
          'Demos: ' + mdhFmtPrice(pr.old) + ' → ' + mdhFmtPrice(pr['new']) + ' s DPH'));
        var apply = mdhMk('button', 'primary tplbtn', 'Zapísať cenu');
        apply.setAttribute('data-action', 'hw-apply');
        apply.setAttribute('data-hw-code', item.item_code);
        line4.appendChild(apply);
      } else if (pr.status === 'unchanged'){
        line4.appendChild(mdhMk('span', null, 'Demos: cena sedí (' + mdhFmtPrice(pr['new']) + ')'));
        var conf = mdhMk('button', 'ghostbtn tplbtn', 'Potvrdiť dátum overenia');
        conf.setAttribute('data-action', 'hw-apply');
        conf.setAttribute('data-hw-code', item.item_code);
        line4.appendChild(conf);
      } else if (pr.status === 'pending'){
        line4.appendChild(mdhMk('span', 'mans', 'Overujem…'));
      } else {
        line4.appendChild(mdhMk('span', 'mddwarn', pr.error || 'Overenie zlyhalo.'));
      }
      box.appendChild(line4);
    }
    return box;
  }

  // Riadok polozky vo vnutri listu (rada). VYCLENENE, aby ho kreslil aj
  // plochy zoznam aj strom TOU ISTOU cestou — inline bunky, detail a `row_rev`
  // guard sa tym padom spravaju v oboch rovnako.
  function mdhAppendItem(box, code){
    var item = MDH_ITEMS[code];
    if (!item) return;   // polozka medzitym zmizla — server ju uz neposlal
    var row = mdhRow(item);
    // TEST-1: práve založená položka je navrchu (poradie dal server) a je
    // VIDIEŤ — bez toho sa v katalógu stratí medzi desiatkami riadkov.
    if (MDH_PIN && item.item_code === MDH_PIN) row.className += ' hwnew';
    box.appendChild(row);
    if (MDH_OPEN === item.item_code) box.appendChild(mdhDetail(item));
  }

  // Plochy zoznam (odpoved `hw_search`). Ostava pre volajucich, ktori strom
  // nepotrebuju — pohlad Polozky v Studiu od KOV-B2 kresli strom.
  function mdhRenderFlat(list){
    var arr = mdhOrderItems(MDH_ITEMS, MDH_ORDER);
    if (!arr.length){
      list.appendChild(mdhMk('div', 'muted', 'Žiadne položky — uprav hľadanie alebo pridaj novú.'));
    }
    arr.forEach(function(i){ mdhAppendItem(list, i.item_code); });
    // TEST-1: orezanie sa PRIZNÁVA — vždy, nielen pri prázdnom dotaze.
    var cap = mdhCapHint(MDH_TOTAL, MDH_SHOWN);
    if (cap) list.appendChild(mdhMk('div', 'muted hwcap', cap));
  }

  // Text v hlavičke kategórie. Čísla dáva server (`total`/`shown`), klient ich
  // len skladá do vety — poradie ani obsah tým nevzniká.
  function mdhGroupCount(g){
    var total = Number(g.total) || 0;
    var mans = (g.manufacturers || []).length;
    var t = total + (total === 1 ? ' položka' : (total < 5 ? ' položky' : ' položiek'));
    if (mans > 1) t += ' · ' + mans + ' výrobcovia';
    // „Zobrazených X z Y" sa píše LEN keď sa naozaj orezalo (zásada „no silent
    // caps"); zbalená kategória nič neorezala — nič neposlala.
    var shown = Number(g.shown) || 0;
    if (g.open === true && shown < total) t += ' · zobrazených ' + shown;
    return t;
  }

  // Hlavička kategórie: chevron (sprite — UI_DIZAJN zakazuje glyfy)
  // + názov + počty. Zbalená kategória = JEDEN riadok (vertikálny priestor).
  function mdhGroupHead(g){
    var btn = mdhMk('button', 'ghostbtn hwgrphead' + (g.open === true ? ' hwopen' : ''));
    btn.setAttribute('data-action', 'hw-grp');
    btn.setAttribute('data-hw-grp', g.key);
    btn.setAttribute('aria-expanded', g.open === true ? 'true' : 'false');
    var chev = mdhMk('span', 'hwchev');
    chev.innerHTML = '<svg class="ic" aria-hidden="true"><use href="#i-chevron-right"/></svg>';
    btn.appendChild(chev);
    btn.appendChild(mdhMk('span', 'hwgn', g.label || g.key));
    btn.appendChild(mdhMk('span', 'hwgc', mdhGroupCount(g)));
    return btn;
  }

  // Strom zo SERVEROVEJ odpovede. JS tu nič netriedi ani nedopĺňa — prechádza
  // skupiny, výrobcov a rady presne v poradí, v akom prišli.
  function mdhRenderTree(list){
    var groups = (MDH_TREE && MDH_TREE.groups) || [];
    if (!groups.length){
      list.appendChild(mdhMk('div', 'muted', 'Žiadne položky — uprav hľadanie alebo pridaj novú.'));
      return;
    }
    groups.forEach(function(g){
      var box = mdhMk('div', 'hwgrp' + (g.open === true ? ' hwopen' : ''));
      box.appendChild(mdhGroupHead(g));
      if (g.open !== true){ list.appendChild(box); return; }
      var body = mdhMk('div', 'hwgrpbody');
      (g.manufacturers || []).forEach(function(m){
        (m.series || []).forEach(function(s){
          body.appendChild(mdhMk('div', 'hwsub', (m.label || '') + ' · ' + (s.label || '')));
          (s.codes || []).forEach(function(c){ mdhAppendItem(body, c); });
          if (s.more === true){
            // „Žiadne tiché stropy": orezaný list to POVIE a dá cestu ďalej.
            var more = mdhMk('button', 'ghostbtn hwmore',
              'Načítať ďalšie (' + (Number(s.total) - Number(s.shown)) + ')');
            more.setAttribute('data-action', 'hw-more');
            more.setAttribute('data-hw-leaf', s.key);
            body.appendChild(more);
          }
        });
      });
      box.appendChild(body);
      list.appendChild(box);
    });
  }

  function mdhRender(){
    var list = hwEl('hwList');
    if (!list) return;
    var keepFocus = null;
    var ae = document.activeElement;
    if (ae && ae.getAttribute && ae.getAttribute('data-hw-field')){
      keepFocus = { code: ae.getAttribute('data-hw-code'),
                    field: ae.getAttribute('data-hw-field'),
                    value: ae.value, orig: ae.getAttribute('data-orig') || '',
                    rev: ae.getAttribute('data-hw-rev') || '',
                    s: ae.selectionStart, e: ae.selectionEnd };
    }
    list.textContent = '';
    if (MDH_TREE) mdhRenderTree(list);
    else mdhRenderFlat(list);
    if (keepFocus){
      var sel = '.mdcell[data-hw-code="' + mdhCssEscape(keepFocus.code) +
        '"][data-hw-field="' + mdhCssEscape(keepFocus.field) + '"]';
      var inp = list.querySelector(sel);
      if (inp){
        if (keepFocus.value !== keepFocus.orig){
          // dirty bunka si drzi rozpisany text + POVODNY baseline (vzor
          // mdApplyCatalog — cudzia zmena skonci konfliktom, nie prepisom)
          inp.value = keepFocus.value;
          inp.setAttribute('data-orig', keepFocus.orig);
          inp.setAttribute('data-hw-rev', keepFocus.rev);
        }
        inp.focus();
        try { inp.setSelectionRange(keepFocus.s, keepFocus.e); } catch (e2) { /* ok */ }
      }
    }
  }

  // ŠT-3a-1: rozdelene na STAV a DOM. Sekcia Studia dostava katalog uz
  // v payloade okna — ale jej telo v tej chvili este nemusi byt pripojene
  // (uzol sa klonuje az pri prvom vykresleni sekcie), takze render aj
  // serverovy search musia pockat. V okne sa NIC nemeni: `mdhApplyItems`
  // robi presne to, co robil.
  function mdhSetItemsState(data){
    MDH_ITEMS = {};
    (data.items || []).forEach(function(i){ MDH_ITEMS[i.item_code] = i; });
    MDH_RO = data.state === 'read_only';
    MDH_RO_REASON = data.state_reason || 'Katalóg je len na čítanie.';
    // GH #100 P2: poradie NIKDY nedoplna JS — zachovaju sa len kody
    // z posledneho SERVEROVEHO vysledku (zmiznute von) a hned sa vyziada
    // cerstvy search (mutacia mohla zmenit zhodu s filtrom/limitom).
    MDH_ORDER = MDH_ORDER.filter(function(c){ return !!MDH_ITEMS[c]; });
  }

  function mdhRenderBanner(){
    var banner = hwEl('hwRoBanner');
    if (banner) banner.style.display = MDH_RO ? '' : 'none';
    var txt = hwEl('hwRoText');
    if (txt) txt.textContent = MDH_RO_REASON;
  }

  // Enumy (kategorie, MJ, verzia) — opat stav zvlast od DOM.
  function mdhApplyEnums(data){
    if (data.categories) MDH_CATS = data.categories;
    if (data.category_labels) MDH_LABELS = data.category_labels;
    if (data.units) MDH_UNITS = data.units;
    if (data.version) MDH_VERSION = data.version;
    if (data.taxonomy) mdhApplyTaxonomy(data.taxonomy);
  }

  // KOV-B2: SK popisok kategorie. Neznamy kod ostava kodom — nech je VIDNO,
  // ze v katalogu je nieco, co popisok nema.
  function mdhCatLabel(code){
    var c = String(code == null ? '' : code);
    return (MDH_LABELS && MDH_LABELS[c]) ? MDH_LABELS[c] : c;
  }

  function mdhApplyTaxonomy(tax){
    if (!tax) return;
    MDH_TAX = { manufacturers: tax.manufacturers || [],
                series: tax.series || [],
                read_only: tax.read_only === true,
                state_reason: tax.state_reason || '' };
  }

  // Rady PATRIACE vybranemu vyrobcovi (KOV-B1: rada patri presne jednemu).
  // Bez vyrobcu sa rada vybrat neda — a to je kontrakt, nie UI detail.
  function mdhSeriesOf(manufacturer){
    var m = String(manufacturer == null ? '' : manufacturer).trim();
    if (!m) return [];
    return (MDH_TAX.series || []).filter(function(s){
      return s && String(s.manufacturer || '') === m;
    }).map(function(s){ return String(s.name || ''); });
  }

  // ŠT-3a-2 (dlh z review #216): `#hwCategory` (filter v LISTE sekcie) tu NIE
  // JE — mal dve autority (tuto a `hwToolsHtml`) a ktora vyhrala, zaviselo od
  // poradia renderu.
  //
  // KOV-B2: zanikli aj `#hn_category`/`#hn_unit` — STATICKY formular novej
  // polozky uz neexistuje (D-110: bol dole pod zoznamom a pri dlhom katalogu
  // ho nikto nenasiel). Enumy dnes kresli MODAL (D-15) z `MDH_CATS`/`MDH_UNITS`
  // pri KAZDOM otvoreni, takze pamat rozpisanych hodnot drzi kostra a ziadne
  // „keep" nad zivym uzlom netreba.
  function mdhRenderEnums(){
    var line = hwEl('hwline');
    if (line) line.textContent = 'V' + MDH_VERSION + ' · položiek: ' + Object.keys(MDH_ITEMS).length;
  }

  function mdhApplyItems(data){
    mdhSetItemsState(data);
    mdhRenderBanner();
    mdhRender();
    // Bez tela v DOM sa nema kam vykreslit — poradie si vypyta az render.
    if (hwEl('hwList')) mdhTreeNow();
    else MDH_ORDER_PENDING = true;
  }

  // --- flush buniek / selectov / checkboxov -------------------------------

  function mdhFlushCell(inp){
    var value = inp.value;
    if (value === (inp.getAttribute('data-orig') || '')) return;
    mdhSend('hw_patch', mdhPatchPayload(
      inp.getAttribute('data-hw-code'), inp.getAttribute('data-hw-rev'),
      inp.getAttribute('data-hw-field'), value
    ));
  }

  function mdhChanged(el){
    var field = el.getAttribute('data-hw-field');
    if (!field) return;
    var value = el.type === 'checkbox' ? el.checked : el.value;
    mdhSend('hw_patch', mdhPatchPayload(
      el.getAttribute('data-hw-code'), el.getAttribute('data-hw-rev'), field, value
    ));
  }

  // --- KOV-B2: MODAL POLOZKY (D-15) + Demos vetva ---------------------------
  //
  // D-110: staticky formular „Nová položka" ZIL DOLE POD ZOZNAMOM — pri
  // katalogu s tromi stovkami kodov ho pouzivatel nasiel az po odscrollovani
  // a rozpisanu polozku mu prekryl zoznam. Od tejto davky je to MODAL nad
  // zdielanou kostrou D-15 (`nx_modal.js`), takze plati cely jej kontrakt:
  // Escape/scrim zatvaraju, `submit` NEZATVARA (zatvara az potvrdenie servera),
  // zamok odoslania odomyka VOLAJUCI v OBOCH vetvach a chyby servera sadaju
  // PRI POLI, ktoreho sa tykaju.
  //
  // Demos vetva sa presunula DO modalu ako PRVE pole (`lookup`): nasepkavanie
  // podla nazvu aj vlozena URL vedu na SERVEROVY proposal (`pid`) — hodnoty
  // polozky z klienta necestuju nikdy (FIX 12 z KOV-H1). Ked pouzivatel
  // niektory z proposalovych udajov (kod, nazov, cena, MJ) prepise, polozka
  // sa uz uklada BEZNOU cestou `hw_create`: rucne zmeneny udaj nie je
  // „overeny", takze nedostane ani `demos_url`, ani datum overenia.

  var MDH_DEMOS = null;      // posledny preview proposal (res zo servera)
  var mdhDemosTimer = null;
  // Stav OTVORENEHO modalu polozky. Kostra o volajucom nevie nic, takze
  // „co som poslal a na co cakam" si drzime tu (vzor `HW_MAN` v hardware.js).
  var HW_ITEM = null;
  var HW_DEMOS_DONE = null;  // callback naseptavaca (kostra ho poda pri hladani)
  var HW_DEMOS_Q = '';
  var HW_ITEM_KEY = 'hw:item:new';
  // Hodnota selectu, ktora NIE JE hodnotou — je to ziadost „vytvor novy zaznam
  // v taxonomii". Submit ju NIKDY neposle do katalogu.
  var HW_NEW_OPT = '__new__';

  function mdhDemosIsUrl(text){
    return /^https?:\/\//i.test(String(text == null ? '' : text).trim());
  }
  // Zapis z proposalu: klient posiela LEN `pid` a to, co proposal nema —
  // kategoriu, poznamku, vyrobcu a radu.
  function mdhDemosCreatePayload(prop, category, notes, manufacturer, series){
    return { pid: (prop && prop.pid) || '', category: category || '',
             notes: notes || '', manufacturer: manufacturer || '',
             series: series || '' };
  }
  // "Suvisiaci sortiment: 106412 (podlozka), 105408 (krytka)…" — urychlovac
  // skladania setov (kody na rovnakej stranke ako zaves).
  function mdhRelatedLine(related){
    var rs = (related || []).filter(function(r){ return r && r.code; });
    if (!rs.length) return null;
    return 'Súvisiaci sortiment: ' + rs.map(function(r){
      return r.code + (r.name ? ' (' + r.name + ')' : '');
    }).join(', ');
  }

  function mdhDemosLoad(url){
    MDH_DEMOS = { status: 'pending' };
    if (HW_ITEM) HW_ITEM.demosPending = true;
    mdhSend('hw_demos_preview', { url: url });
  }

  // Naseptavac Demosu v modale. Kostra `lookup` vola `search(query, done)` pri
  // KAZDOM pisani, takze debounce je na nas (rovnaky, aky mal formular).
  // Vlozena URL sa nehlada — nacita sa ako produktova stranka.
  function hwDemosSearch(query, done){
    var q = String(query == null ? '' : query).trim();
    HW_DEMOS_Q = q;
    HW_DEMOS_DONE = done;
    if (mdhDemosTimer){ clearTimeout(mdhDemosTimer); mdhDemosTimer = null; }
    if (mdhDemosIsUrl(q)){
      done([], 0);
      mdhDemosTimer = setTimeout(function(){ mdhDemosLoad(q); }, 400);
      return;
    }
    if (q.length < 3){ done([], 0); return; }
    mdhDemosTimer = setTimeout(function(){ mdhSend('hw_demos_search', { query: q }); }, 200);
  }
  // Klik/Enter na zhodu = nacitanie PRODUKTOVEJ STRANKY (server proposal).
  function hwDemosPick(it){
    if (it && it.value) mdhDemosLoad(String(it.value));
  }
  function hwDemosHit(r){
    return { value: String((r && r.url) || ''),
             text: String((r && (r.label || r.slug)) || ''),
             hint: 'demos-trade.sk' };
  }

  // --- polia modalu (CISTE funkcie — Node testy) -----------------------------

  function hwItemCatOptions(){
    return (MDH_CATS || []).map(function(c){ return [c, mdhCatLabel(c)]; });
  }
  function hwItemUnitOptions(){
    return (MDH_UNITS || []).map(function(u){ return [u, u]; });
  }
  function hwItemManOptions(){
    var out = [['', '— bez výrobcu']];
    (MDH_TAX.manufacturers || []).forEach(function(m){ out.push([String(m), String(m)]); });
    // Nad nekompatibilnou taxonomiou sa zapisat neda — tlacidlo, ktore vzdy
    // zlyha, sa neponuka.
    if (!MDH_TAX.read_only) out.push([HW_NEW_OPT, '+ Vytvoriť výrobcu…']);
    return out;
  }
  function hwItemSerOptions(manufacturer){
    var m = String(manufacturer == null ? '' : manufacturer);
    var out = [['', '— bez rady']];
    mdhSeriesOf(m).forEach(function(s){ out.push([s, s]); });
    // Rada patri presne jednemu vyrobcovi (KOV-B1) — bez vybraneho vyrobcu
    // sa zalozit NEDA.
    if (m && m !== HW_NEW_OPT && !MDH_TAX.read_only) out.push([HW_NEW_OPT, '+ Vytvoriť radu…']);
    return out;
  }

  // Poradie poli je poradie DODAVATELSKEHO LISTU (mockup scena 3):
  // Démos -> kód -> názov -> cena -> MJ -> kategória -> výrobca -> rada ->
  // poznámka. Pri UPRAVE kod chyba: `item_code` je IDENTITA polozky a je
  // NEMENNA (server ho v `PATCHABLE` nema) — je preto v podtitule, nie v poli,
  // ktore by sa dalo prepisat.
  function hwItemFields(v, opts){
    var d = v || {};
    var o = opts || {};
    var out = [];
    if (!o.edit){
      out.push({ key: 'demos', type: 'lookup', label: 'Démos',
                 value: '', valueText: String(d.demos_q || ''),
                 placeholder: 'kód, názov… alebo https://www.demos-trade.sk/…',
                 search: hwDemosSearch, onPick: hwDemosPick });
      out.push({ key: 'code', label: 'Kód *', value: String(d.code || ''),
                 placeholder: 'Demos kód alebo vlastný' });
    }
    out.push({ key: 'name', label: 'Názov *', value: String(d.name || '') });
    out.push({ key: 'price', label: 'Cena', cls: 'mshort',
               value: String(d.price == null ? '' : d.price),
               placeholder: 'nezadaná', hint: '€ s DPH' });
    out.push({ key: 'unit', type: 'select', label: 'MJ', cls: 'mshort',
               options: hwItemUnitOptions(), value: String(d.unit || '') });
    out.push({ key: 'category', type: 'select', label: 'Kategória',
               options: hwItemCatOptions(), value: String(d.category || '') });
    out.push({ key: 'manufacturer', type: 'select', label: 'Výrobca',
               options: hwItemManOptions(), value: String(d.manufacturer || '') });
    if (String(d.manufacturer || '') === HW_NEW_OPT){
      out.push({ key: 'manufacturer_new', label: 'Názov nového výrobcu',
                 value: String(d.manufacturer_new || ''),
                 hint: 'pridá sa do zoznamu (globálne)' });
    }
    out.push({ key: 'series', type: 'select', label: 'Rada',
               options: hwItemSerOptions(d.manufacturer), value: String(d.series || '') });
    if (String(d.series || '') === HW_NEW_OPT){
      out.push({ key: 'series_new', label: 'Názov novej rady',
                 value: String(d.series_new || ''),
                 hint: 'priradí sa výrobcovi vyššie' });
    }
    out.push({ key: 'notes', label: 'Poznámka', value: String(d.notes || ''),
               placeholder: 'nepovinné' });
    return out;
  }

  // Klient strazi LEN povinne polia — AUTORITA validacie je server.
  function hwItemValidate(v, opts){
    var d = v || {};
    var o = opts || {};
    var out = [];
    if (!o.edit && String(d.code || '').trim() === ''){
      out.push({ field: 'code', msg: 'Kód je povinný — je to identita položky.' });
    }
    if (String(d.name || '').trim() === ''){
      out.push({ field: 'name', msg: 'Názov je povinný.' });
    }
    return out;
  }

  // Cena na porovnanie (2 desatinne miesta, ciarka aj bodka) — bez toho by
  // „18,90" vs. „18.9" vyzeralo ako rucna zmena a polozka by prisla o vazbu
  // na Demos.
  function hwPriceKey(v){
    var s = String(v == null ? '' : v).trim().replace(',', '.');
    if (s === '') return '';
    var f = parseFloat(s);
    return isFinite(f) ? String(Math.round(f * 100) / 100) : s;
  }
  // Prepisal pouzivatel niektory z udajov, ktore vlastni PROPOSAL? Potom to uz
  // nie je overena polozka z Demosu (R4) — uklada sa ako rucna.
  function hwDemosDirty(prop, v){
    if (!prop || !prop.pid) return true;
    var d = v || {};
    if (String(d.code || '').trim() !== String(prop.code || '')) return true;
    if (String(d.name || '').trim() !== String(prop.name_sk || '')) return true;
    if (String(d.unit || '') !== String(prop.unit || '')) return true;
    return hwPriceKey(d.price) !== hwPriceKey(prop.price_vat);
  }

  // Hodnoty modalu -> draft (to, co prezije prekreslenie modalu). CISTA.
  function hwItemDraft(v, extra){
    var d = v || {};
    var out = { code: String(d.code || ''), name: String(d.name || ''),
                price: String(d.price == null ? '' : d.price),
                unit: String(d.unit || ''), category: String(d.category || ''),
                manufacturer: String(d.manufacturer || ''),
                manufacturer_new: String(d.manufacturer_new || ''),
                series: String(d.series || ''),
                series_new: String(d.series_new || ''),
                notes: String(d.notes || ''),
                demos_q: String(d.demos_q || '') };
    var e = extra || {};
    var k;
    for (k in e){ if (Object.prototype.hasOwnProperty.call(e, k)) out[k] = e[k]; }
    return out;
  }

  // Draft z ULOZENEJ polozky (uprava).
  function hwItemDraftOf(item){
    var i = item || {};
    return hwItemDraft({
      code: i.item_code, name: i.name_sk,
      price: (i.price_eur_vat == null) ? '' : i.price_eur_vat,
      unit: i.unit, category: i.category,
      manufacturer: i.manufacturer, series: i.series, notes: i.notes
    });
  }

  // Predvyplnenie z Demosu. Kod, nazov, cena a MJ su z PROPOSALU; kategoria je
  // NAVRH servera; vyrobca je NAVRH z taxonomie (`manufacturer_guess`) —
  // RADU nehadame nikdy (inferencia z breadcrumbu je mimo tejto davky).
  function hwItemDraftFromProposal(v, prop){
    var d = v || {};
    var p = prop || {};
    var guess = String(p.manufacturer_guess || '');
    var known = (MDH_TAX.manufacturers || []).indexOf(guess) >= 0 ? guess : '';
    return hwItemDraft(d, {
      code: String(p.code || ''), name: String(p.name_sk || ''),
      price: (p.price_vat == null) ? '' : String(p.price_vat),
      unit: String(p.unit || ''),
      category: String(p.category_guess || d.category || ''),
      manufacturer: known || String(d.manufacturer || ''),
      manufacturer_new: '', series: '', series_new: '',
      demos_q: [String(p.code || ''), String(p.name_sk || '')].filter(Boolean).join(' · ')
    });
  }

  // Veta o vazbe na Demos + suvisiaci sortiment. Je STATICKA a vzdy pravdiva:
  // hovori, CO sa stane, ked pouzivatel proposalovy udaj zmeni — nie to, ci ho
  // uz zmenil (to by si vyzadovalo prekreslovat modal pri kazdom znaku).
  function hwItemNote(prop, opts){
    if ((opts || {}).edit) return 'Kód sa nemení — je to identita položky v katalógu.';
    if (!prop || !prop.pid) return null;
    var t = 'Kód, názov, cena a MJ sú z Démosu (položka dostane väzbu a dátum ' +
            'overenia). Keď niektorý z nich zmeníš, uloží sa ako ručná položka — ' +
            'bez väzby na Démos a bez dátumu overenia.';
    var rel = mdhRelatedLine(prop.related);
    return rel ? (t + ' ' + rel) : t;
  }

  // --- otvorenie a zapis -----------------------------------------------------

  function hwItemOpen(item, draft, opts){
    if (typeof NXModal === 'undefined' || !NXModal || typeof NXModal.open !== 'function') return;
    var o = opts || {};
    var edit = !!item;
    var d = draft || (edit ? hwItemDraftOf(item) : hwItemDraft({}));
    // VNUTORNE prekreslenie (predvyplnenie z Demosu, novy vyrobca) podava
    // KOMPLETNE hodnoty — pamat rozpisaneho konceptu by nad nimi vyhrala
    // STARYMI a prepisala by prave prijaty navrh zo servera. Pri otvoreni
    // z listy sa pamat NEZAHADZUJE (kontrakt D-15).
    if (o.dropMemory && typeof NXModal.clearMemory === 'function') NXModal.clearMemory(HW_ITEM_KEY);
    NXModal.open({
      title: edit ? 'Upraviť položku katalógu' : 'Nová položka katalógu',
      sub: edit ? ('Kód ' + String(item.item_code)) : 'z Démosu alebo ručne',
      size: 'md',
      okLabel: edit ? 'Uložiť' : 'Uložiť položku',
      // Konvencia kluca `<okno/domena>:<mode>[:<ciel>]`. UPRAVA pamat NEMA
      // (vzor D-69): predvyplnit editor cudzej polozky hodnotami pisanymi do
      // inej by bola ticha zamena zaznamu.
      memoryKey: edit ? null : HW_ITEM_KEY,
      note: hwItemNote(MDH_DEMOS && MDH_DEMOS.ok ? MDH_DEMOS : null, { edit: edit }),
      fields: hwItemFields(d, { edit: edit }),
      onSubmit: function(vals){ hwItemSubmit(vals); },
      onClose: function(){ hwItemClosed(); }
    });
    // AZ ZA `open`: kostra najprv zatvara predchadzajuci modal a jeho `onClose`
    // by cerstvy stav hned vynuloval.
    HW_ITEM = { code: edit ? String(item.item_code) : null,
                edit: edit,
                rowRev: edit ? String(item.row_rev || '') : '',
                base: edit ? hwItemDraftOf(item) : null,
                draft: d, sent: false, taxPending: null, demosPending: false };
  }

  function hwItemClosed(){
    // Nedokonceny nahlad musi zomriet s oknom — server bumpne generaciu
    // a dobiehajuci fetch uz nema komu prist.
    if (HW_ITEM && HW_ITEM.demosPending) mdhSend('hw_demos_cancel', {});
    if (mdhDemosTimer){ clearTimeout(mdhDemosTimer); mdhDemosTimer = null; }
    HW_ITEM = null;
    HW_DEMOS_DONE = null;
    MDH_DEMOS = null;
  }

  // Ktore polia sa patchom naozaj menia. Posielat VSETKO by pri kazdej uprave
  // zmazalo `price_checked_at` (server F5: zmena ceny/MJ/URL datum overenia
  // zneplatnuje) — aj keby sa ceny nikto nedotkol.
  var HW_PATCH_MAP = { name: 'name_sk', price: 'price_eur_vat', unit: 'unit',
                       category: 'category', manufacturer: 'manufacturer',
                       series: 'series', notes: 'notes' };

  function hwItemPatch(base, v){
    var d = v || {};
    var b = base || {};
    var patch = {};
    var k;
    for (k in HW_PATCH_MAP){
      if (!Object.prototype.hasOwnProperty.call(HW_PATCH_MAP, k)) continue;
      var now = String(d[k] == null ? '' : d[k]).trim();
      var was = String(b[k] == null ? '' : b[k]).trim();
      if (k === 'price' && hwPriceKey(now) === hwPriceKey(was)) continue;
      if (now === was) continue;
      patch[HW_PATCH_MAP[k]] = now;
    }
    return patch;
  }

  function hwItemCreatePayload(v){
    var d = v || {};
    return { fields: { item_code: String(d.code || '').trim(),
                       name_sk: String(d.name || '').trim(),
                       category: String(d.category || ''),
                       unit: String(d.unit || ''),
                       price_eur_vat: String(d.price == null ? '' : d.price),
                       manufacturer: String(d.manufacturer || ''),
                       series: String(d.series || ''),
                       notes: String(d.notes || '') } };
  }

  function hwItemSubmit(v){
    var d = v || {};
    if (!HW_ITEM){ NXModal.setBusy(false); return; }
    // „+ Vytvoriť…" nie je hodnota polozky — je to zapis do TAXONOMIE.
    // Polozka sa pritom NEUKLADA: pouzivatel po zalozeni vyrobcu/rady vidi
    // formular s vybranou novou hodnotou a ulozi ho druhym kliknutim.
    if (String(d.manufacturer || '') === HW_NEW_OPT ||
        String(d.series || '') === HW_NEW_OPT){
      hwTaxCreate(d);
      return;
    }
    var errs = hwItemValidate(d, { edit: HW_ITEM.edit });
    if (errs.length){ NXModal.showErrors(errs); NXModal.setBusy(false); return; }
    NXModal.clearErrors();
    HW_ITEM.draft = hwItemDraft(d);
    if (HW_ITEM.edit){
      var patch = hwItemPatch(HW_ITEM.base, d);
      if (!Object.keys(patch).length){
        // Prazdny patch server odmietne ako „žiadne editovateľné pole" —
        // hlasit chybu za to, ze pouzivatel nic nezmenil, je ale nezmysel.
        NXModal.setBusy(false);
        NXModal.close();
        MDH.setStatus('Nič sa nezmenilo.');
        return;
      }
      HW_ITEM.sent = true;
      mdhSend('hw_patch', { code: HW_ITEM.code, row_rev: HW_ITEM.rowRev,
                            from: 'modal', patch: patch });
      return;
    }
    HW_ITEM.sent = true;
    // Neporuseny proposal = zapis z Demosu (server doplna vazbu a datum
    // overenia). Cokolvek prepisane = bezna rucna polozka.
    if (MDH_DEMOS && MDH_DEMOS.ok && !hwDemosDirty(MDH_DEMOS, d)){
      mdhSend('hw_demos_create', mdhDemosCreatePayload(
        MDH_DEMOS, String(d.category || ''), String(d.notes || '').trim(),
        String(d.manufacturer || ''), String(d.series || '')));
      return;
    }
    mdhSend('hw_create', hwItemCreatePayload(d));
  }

  // Zalozenie vyrobcu/rady z modalu. Taxonomia je GLOBALNY subor, takze zapis
  // do nej NEROBI krok Spat — a preto ho robime az na vyslovny pokyn.
  function hwTaxCreate(v){
    var d = v || {};
    var op = (String(d.manufacturer || '') === HW_NEW_OPT) ? 'manufacturer' : 'series';
    var key = op + '_new';
    var name = String(d[key] || '').trim();
    if (!name){
      NXModal.showErrors([{ field: key,
                            msg: op === 'manufacturer'
                              ? 'Doplň názov nového výrobcu.'
                              : 'Doplň názov novej rady.' }]);
      NXModal.setBusy(false);
      return;
    }
    NXModal.clearErrors();
    if (HW_ITEM){
      HW_ITEM.draft = hwItemDraft(d);
      HW_ITEM.taxPending = op;
    }
    if (op === 'manufacturer') mdhSend('hw_tax_create_manufacturer', { name: name });
    else mdhSend('hw_tax_create_series', { name: name,
                                           manufacturer: String(d.manufacturer || '') });
  }

  // Zmena vyrobcu/rady meni SADU POLI (zavisly select rady, pole „+ Vytvoriť")
  // a tu kostra D-15 za behu nevymiena — modal sa preto otvori znova s tym,
  // CO UZ POUZIVATEL NAPISAL (vzor `hwManualCtxSwitch` v hardware.js).
  function hwItemCtxSwitch(changedKey){
    if (!HW_ITEM || typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
    if (NXModal.isBusy && NXModal.isBusy()) return;   // bezi zapis — nesahat
    var d = hwItemDraft(NXModal.values(), { demos_q: hwDemosQueryText() });
    if (changedKey === 'manufacturer'){
      // Rada patri presne jednemu vyrobcovi — po zmene vyrobcu uz vybrana rada
      // platit nemusi. Ostava LEN vtedy, ked novemu vyrobcovi naozaj patri.
      if (d.series !== HW_NEW_OPT && mdhSeriesOf(d.manufacturer).indexOf(d.series) < 0) d.series = '';
      d.series_new = '';
    }
    hwItemOpen(HW_ITEM.edit ? MDH_ITEMS[HW_ITEM.code] : null, d, { dropMemory: true });
  }

  // Nevybrany dotaz naseptavaca nie je vo `values()` (kontrakt `lookup` vracia
  // LEN hodnotu) — cita sa z pola hladania, inak by ho prekreslenie zmazalo.
  function hwDemosQueryText(){
    var n = hwEl('nxm_demos_q');
    return n ? String(n.value == null ? '' : n.value) : '';
  }

  // --- verejne API pre Ruby ------------------------------------------------

  var MDH = {
    init: function(data){
      mdhApplyEnums(data);
      mdhRenderEnums();
      mdhApplyItems(data); // vratane prvotneho serveroveho poradia
    },
    setItems: function(data){ mdhApplyItems(data); },
    // Plochy zoznam (`hw_search`). Pohlad Polozky uz chodi cez `MDH.tree` —
    // prijimac ostava, lebo `hw_search` je verejny kontrakt katalogu.
    results: function(data){
      MDH_TREE = null;
      MDH_ORDER = data.codes || [];
      MDH_TOTAL = data.total || MDH_ORDER.length;
      MDH_SHOWN = data.shown || MDH_ORDER.length;
      // Server pin potvrdí LEN keď taká položka naozaj je — zvýrazňuje sa
      // teda to, čo je aj v zozname.
      MDH_PIN = data.pin || '';
      mdhRender();
    },
    // KOV-B2: SERVEROVY STROM. Kresli sa PRESNE to, co prislo — poradie
    // skupin, vyrobcov, rad aj kodov sklada server.
    tree: function(data){
      var d = data || {};
      // Staršia odpoveď NESMIE prepísať čerstvejší strom (hľadanie je
      // debounced a odpovede chodia asynchronne).
      if (d.gen != null && Number(d.gen) !== MDH_TREE_GEN) return;
      MDH_TREE = d;
      MDH_ORDER = [];
      if (d.leaf_page) MDH_LEAF_PAGE = Number(d.leaf_page) || MDH_LEAF_PAGE;
      MDH_TOTAL = Number(d.total) || 0;
      MDH_SHOWN = Number(d.shown) || 0;
      MDH_PIN = d.pin || '';
      // Server rozbaľuje SÁM (práve založená položka, hľadanie). Do PAMÄTE
      // rozbalenia sa to premieta LEN pri prázdnom dotaze — inak by jedno
      // hľadanie natrvalo roztvorilo každú kategóriu, v ktorej niečo našlo.
      if (!String(d.q || '').trim()){
        (d.groups || []).forEach(function(g){
          if (g && g.open === true) HW_EXPAND[g.key] = true;
        });
      }
      mdhRender();
    },
    setStatus: function(msg, err){
      var e = hwEl('status');
      if (e){ e.textContent = msg; e.className = err ? 'err' : 'ok'; }
    },
    priceResult: function(r){
      MDH_PRICE[r.code] = r.ok ? r : { status: 'error', error: r.error };
      mdhRender();
    },
    // GH #100 P2: po zapise sa navrh zmaze A prekresli — stale tlacidlo
    // "Zapisat cenu" nesmie ostat viditelne (push_items bezal skor).
    priceApplied: function(r){
      delete MDH_PRICE[r.code];
      mdhRender();
    },
    // KOV-B2: vysledok zapisu polozky pre MODAL. Zamok odoslania odomyka
    // VOLAJUCI v OBOCH vetvach (kontrakt D-15) a zatvara sa AZ na potvrdenie
    // servera — odmietnuty zapis musi pouzivatel najst s rozpisanymi
    // hodnotami na mieste.
    itemResult: function(ok, msg, errors, op){
      if (typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
      // Inline bunka riadku ziadny modal neotvara — jej odpoved sem nepatri.
      if (!HW_ITEM || !HW_ITEM.sent) return;
      HW_ITEM.sent = false;
      if (ok === true){
        // Server potvrdil: pamat rozpisaneho konceptu zanika a okno sa zatvara.
        NXModal.setBusy(false, { clear: true });
        NXModal.close();
        return;
      }
      NXModal.setBusy(false);
      var list = (errors && errors.length) ? errors : [{ msg: String(msg == null ? '' : msg) }];
      NXModal.showErrors(list);
    },
    // KOV-B2: odpoved na „+ Vytvoriť výrobcu/radu…". Server posiela CERSTVU
    // taxonomiu a KANONICKE meno — modal sa prekresli a novu hodnotu VYBERIE.
    taxonomy: function(res){
      var r = res || {};
      mdhApplyTaxonomy(r.taxonomy);
      if (typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
      if (!HW_ITEM) return;
      NXModal.setBusy(false);
      var op = (r.op === 'series') ? 'series' : 'manufacturer';
      HW_ITEM.taxPending = null;
      if (r.ok !== true){
        // Chyba servera nesie pole `manufacturer`/`series`; v modale ju vidno
        // pri poli, do ktoreho sa pise NOVE meno.
        NXModal.showErrors((r.errors || []).map(function(e){
          return { field: (e && e.field === 'series') ? 'series_new' : 'manufacturer_new',
                   msg: String((e && e.msg) || 'zápis zlyhal') };
        }));
        return;
      }
      var d = hwItemDraft(HW_ITEM.draft || {});
      if (op === 'manufacturer'){
        d.manufacturer = String(r.name || '');
        d.manufacturer_new = '';
        d.series = '';
        d.series_new = '';
      } else {
        d.series = String(r.name || '');
        d.series_new = '';
      }
      hwItemOpen(HW_ITEM.edit ? MDH_ITEMS[HW_ITEM.code] : null, d, { dropMemory: true });
    },
    // V0.6 D2: zive zhody Demosu — od KOV-B2 idu do naseptavaca modalu.
    demosResults: function(d){
      var data = d || {};
      // neaktualne vysledky (pouzivatel medzitym pise dalej) sa zahadzuju
      if (String(data.query || '') !== HW_DEMOS_Q) return;
      if (typeof HW_DEMOS_DONE !== 'function') return;
      // Prve pouzitie stahuje sitemap — ponuka ostane prazdna a dorovna ju
      // `demosRefreshDone`.
      if (data.refreshing){ HW_DEMOS_DONE([], 0); return; }
      var hits = (data.results || []).map(hwDemosHit);
      HW_DEMOS_DONE(hits, hits.length);
    },
    // GH #128 P2: sitemap cache dobehla — zopakuj AKTUALNY dotaz
    demosRefreshDone: function(){
      var q = HW_DEMOS_Q;
      if (q.length >= 3 && !mdhDemosIsUrl(q)) mdhSend('hw_demos_search', { query: q });
    },
    demosPreview: function(res){
      MDH_DEMOS = res || { ok: false, error: 'prázdna odpoveď' };
      if (HW_ITEM) HW_ITEM.demosPending = false;
      if (typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
      if (!HW_ITEM) return;
      if (MDH_DEMOS.ok !== true){
        NXModal.setBusy(false);
        NXModal.showErrors([{ field: 'demos',
                              msg: 'Nedá sa načítať: ' + (MDH_DEMOS.error || 'neznáma chyba') }]);
        return;
      }
      // Predvyplnenie prekresľuje modal — hodnoty, ktoré používateľ už napísal
      // (kategória, poznámka), sa čítajú z formulára a NESTRÁCAJÚ sa.
      hwItemOpen(null, hwItemDraftFromProposal(NXModal.values(), MDH_DEMOS),
                 { dropMemory: true });
      if (MDH_DEMOS.exists === true){
        NXModal.showErrors([{ field: 'code',
                              msg: 'Tento kód už v katalógu je — cenu obnovíš cez „Overiť" ' +
                                   'na existujúcej položke.' }]);
      }
    },
    demosCreated: function(code){
      MDH_DEMOS = null;
      MDH.created(code);   // TEST-1: kód novej položky ide ďalej (pin navrch)
    },
    created: function(code){
      // TEST-1: nová položka sa MUSÍ objaviť hneď. Kód ide ako JEDNORAZOVÁ
      // žiadosť do najbližšieho dotazu (`mdhTreeNow`) — server ju dá navrch
      // SVOJHO listu a jeho kategóriu rozbalí. Ďalšie hľadanie už žiadosť
      // nenesie (review #229 P2).
      MDH_PIN_REQ = (code == null) ? '' : String(code);
      // GH #100 P2: nova polozka musi byt hned viditelna — filter sa vycisti
      // a poradie pride zo servera (ziadne lokalne doplnanie).
      //
      // ŠT-3a-3: filter zije v SEKCII na DVOCH miestach — v uzle listy a
      // v premennej (`HW_Q`/`HW_CAT`), lebo listu prekresluje kazdy push.
      // Cistilo sa len DOM, takze najblizsi push nakreslil listu so STARYM
      // filtrom nad zoznamom, ktory server vratil NEFILTROVANY — a pouzivatel
      // videl polozky, ktore filtru nezodpovedaju. Cistia sa preto OBE.
      //
      // KOV-B2: `hn_category`/`hn_unit` uz neexistuju — lepkava kategoria
      // a MJ ziju v PAMATI kostry D-15 (`hw:item:new`), takze zalozenie radu
      // poloziek toho isteho druhu funguje dalej, len o vrstvu vyssie.
      HW_Q = '';
      HW_CAT = '';
      var q = hwEl('hwSearch');
      if (q) q.value = '';
      var c = hwEl('hwCategory');
      if (c) c.value = '';
      mdhTreeNow();
    }
  };

  // --- delegovane ovladanie -------------------------------------------------

  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('click', function(ev){
      var t = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
      if (!t) return;
      var action = t.getAttribute('data-action');
      var code = t.getAttribute('data-hw-code') || '';
      if (action === 'hw-view'){
        // ŠT-3a-1: segment Položky · Sety v lište sekcie (Š16).
        hwSetView(t.getAttribute('data-view'));
      } else if (action === 'hw-toggle'){
        MDH_OPEN = MDH_OPEN === code ? null : code;
        mdhRender();
      } else if (action === 'hw-grp'){
        // KOV-B2: rozbalenie kategórie. Obsah rozhoduje SERVER — klient len
        // povie, čo chce vidieť, a počká na strom.
        var gk = t.getAttribute('data-hw-grp') || '';
        if (HW_EXPAND[gk]) delete HW_EXPAND[gk];
        else HW_EXPAND[gk] = true;
        mdhTreeNow();
      } else if (action === 'hw-more'){
        // „Žiadne tiché stropy": ďalšia stránka LISTU (rady) — o koľko viac,
        // hovorí klient, čo vráti, rozhoduje server.
        var lk = t.getAttribute('data-hw-leaf') || '';
        HW_MORE[lk] = (Number(HW_MORE[lk]) || MDH_LEAF_PAGE) + MDH_LEAF_PAGE;
        mdhTreeNow();
      } else if (action === 'hw-new'){
        hwItemOpen(null, null, {});
      } else if (action === 'hw-edit'){
        var toEdit = MDH_ITEMS[code];
        if (toEdit) hwItemOpen(toEdit, null, {});
        else MDH.setStatus('Položka sa medzitým zmenila — katalóg sa obnovil.', true);
      } else if (action === 'hw-del'){
        MDH_DEL = code;
        var txt = hwEl('hwDelText');
        var item = MDH_ITEMS[code];
        if (txt) txt.textContent = 'Zmazať ' + code + (item ? ' — ' + item.name_sk : '') + '?';
        var m = hwEl('hwDelModal');
        if (m) m.style.display = '';
      } else if (action === 'hw-del-close'){
        hwDelClose();
      } else if (action === 'hw-del-confirm'){
        var item2 = MDH_ITEMS[MDH_DEL];
        if (item2) mdhSend('hw_delete', { code: MDH_DEL, row_rev: item2.row_rev || '' });
        MDH_DEL = null;
        var m3 = hwEl('hwDelModal');
        if (m3) m3.style.display = 'none';
      } else if (action === 'hw-check'){
        var urlInp = document.querySelector('input[data-hw-url="' + mdhCssEscape(code) + '"]');
        MDH_PRICE[code] = { status: 'pending' };
        mdhRender();
        mdhSend('hw_check_price', { code: code, url: urlInp ? urlInp.value.trim() : '' });
      } else if (action === 'hw-url-clear'){
        // GH #100 P2: vymazanie ulozene vazby — prazdny demos_url patch je
        // jedina legalna cesta (server: neprazdnu URL patch odmieta).
        var it = MDH_ITEMS[code];
        if (it) mdhSend('hw_patch', mdhPatchPayload(code, it.row_rev, 'demos_url', ''));
      } else if (action === 'hw-apply'){
        // GH #99 P2: pid navrhu, ktory je prave ZOBRAZENY — server odmietne
        // zapis, ak medzitym dobehol iny check (prekryvajuce sa overenia).
        var shown = MDH_PRICE[code] || {};
        mdhSend('hw_apply_price', { code: code, pid: shown.pid || '' });
      }
    });
    document.addEventListener('focusout', function(ev){
      var t = ev.target;
      if (t && t.classList && t.classList.contains('mdcell') && t.getAttribute('data-hw-field')){
        mdhFlushCell(t);
      }
    });
    // GH #100 P2: Enter ulozi (blur -> focusout flush), Escape vrati povodnu
    // hodnotu bez ulozenia (vzor mdCellKey okna Materialy).
    document.addEventListener('keydown', function(ev){
      var t = ev.target;
      if (!t || !t.classList || !t.classList.contains('mdcell') || !t.getAttribute('data-hw-field')) return;
      if (ev.key === 'Enter'){ ev.preventDefault(); t.blur(); }
      else if (ev.key === 'Escape'){ t.value = t.getAttribute('data-orig') || ''; t.blur(); }
    });
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      // ŠT-3a-1: filtre ziju v SEKCII v liste, ktoru prekresluje KAZDY push —
      // priama vazba pri nacitani by po prvom prekresleni zanikla. Delegacia
      // funguje v obidvoch UI rovnako.
      if (t.id === 'hwCategory'){ HW_CAT = t.value; mdhTreeNow(); return; }
      if (t.id === 'hwInactive'){ HW_INACTIVE = !!t.checked; mdhTreeNow(); return; }
      // KOV-B2: polia MODALU polozky (kostra D-15 ich kresli do `#nxModalRoot`).
      // Vyrobca a rada menia SADU POLI, takze modal sa prekresli; potvrdeny
      // nazov v poli „+ Vytvoriť…" rovno zaklada zaznam v taxonomii.
      var nxm = t.getAttribute('data-nxm');
      if (nxm === 'manufacturer' || nxm === 'series'){ hwItemCtxSwitch(nxm); return; }
      if (nxm === 'manufacturer_new' || nxm === 'series_new'){
        if (String(t.value || '').trim() && typeof NXModal !== 'undefined' &&
            NXModal.isOpen && NXModal.isOpen() && HW_ITEM){
          hwTaxCreate(NXModal.values());
        }
        return;
      }
      if (t.tagName === 'SELECT' && t.getAttribute('data-hw-field')) mdhChanged(t);
      else if (t.type === 'checkbox' && t.getAttribute('data-hw-field')) mdhChanged(t);
    });
    // Ten isty dovod pre textove vstupy — hladanie zije v LISTE sekcie, ktoru
    // prekresluje kazdy push.
    document.addEventListener('input', function(ev){
      var t = ev.target;
      if (!t || !t.id) return;
      if (t.id === 'hwSearch'){ HW_Q = t.value; mdhSearchDebounced(); return; }
    });
  }

  // ================= ŠT-3a-1: SEKCIA `hw` v okne Studio =====================
  //
  // Bezi TU, nie v `studio.js`: obsah sekcie je presun 1:1 a jeho jedina
  // autorita je tento subor (vzor `js/proj_materials.js` a `js/budget.js`,
  // ktore si tiez kreslia listu aj telo svojej sekcie samy).

  // Zdielane helpery okna Studio (jantarove „Obnoviť"). V prehliadaci su
  // globalne — `studio.js` sa nacitava PRED tymto suborom; v Node testoch ich
  // treba requirovat (vzor `MAT_STUDIO`). V okne Katalog kovania je premenna
  // `null` a nikto ju nepouzije.
  var HW_STUDIO = (typeof module !== 'undefined' && module.exports)
    ? require('./studio.js')
    : null;

  // Stav LISTY sekcie. Lista sa prekresluje pri KAZDOM pushi, takze hodnoty
  // vstupov musia zit aj v premennych (vzor `MD_Q`/`MD_MODE` v Materialoch) —
  // inak by pouzivatelovi zmizol filter pri prvom prepocte kusovnika.
  var HW_VIEW = 'items';    // items | sets (Š16)
  var HW_Q = '';
  var HW_CAT = '';
  var HW_INACTIVE = false;
  // KOV-B2: pamat rozbalenia stromu a strankovania listov. Je to stav POHLADU
  // (rovnaka vrstva ako `HW_Q`/`HW_CAT`), takze prezije push zo servera aj
  // odchod do inej sekcie — inak by sa katalog po kazdom prepocte kusovnika
  // zabalil a pouzivatel by rozbaloval odznova.
  var HW_EXPAND = {};
  var HW_MORE = {};

  // Cisla `hwToolsHtml` su cista funkcia (Node test) — stav chodi ARGUMENTOM,
  // rovnaky vzor ako `bomToolsHtml` v studio.js a `matToolsHtml`.
  // Poradie (vzor listy Studia): vlavo „co pozeram" (pohlady · pridavacia
  // akcia · hladanie · filtre), vpravo „co s tym robim" (Obnoviť).
  function hwToolsHtml(st){
    var s = st || {};
    var ico = function(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; };
    var vw = function(id, t, tip){
      return '<button type="button" class="bomvw' + (s.view === id ? ' on' : '') +
             '" data-action="hw-view" data-view="' + id + '" title="' + hwEsc(tip) + '">' +
             hwEsc(t) + '</button>';
    };
    var h = '<div class="bomviews">' +
      vw('items', 'Položky', 'Katalóg nakupovaných položiek (kódy, ceny, väzba na Demos)') +
      vw('sets', 'Sety', 'Sety kovania + predvoľby, podľa ktorých sa skladá nákupný zoznam') +
      '</div>';
    if (s.view !== 'sets'){
      h += '<button type="button" class="primary" id="hwNewBtn" data-action="hw-new"' +
        (s.ro ? ' disabled' : '') + ' title="Pridať položku (z Demosu alebo ručne)">' +
        ico('plus') + ' Nová položka</button>' +
        '<div class="searchbox">' + ico('search') +
        '<input id="hwSearch" type="text" placeholder="Hľadať kód, názov, dodávateľa"' +
        ' value="' + hwEsc(s.q || '') + '"></div>' +
        '<select id="hwCategory" title="Kategória">' + hwCatOptions(s) + '</select>' +
        '<label class="hwinactive" title="Ukáž aj položky vyradené z ponuky">' +
        '<input type="checkbox" id="hwInactive"' + (s.inactive ? ' checked' : '') +
        '> neaktívne</label>';
    } else {
      h += '<span class="sechint">Set = kódy, ktoré sa objednajú za 1 kus kovania.</span>';
    }
    h += '<span class="spacer"></span>';
    // Jantarove „Obnoviť" je ZDIELANY markup celeho okna (`studio.js`) — sekcia
    // ho nesmie kreslit druhykrat (vzor `matToolsHtml`).
    var refresh = (typeof refreshBtnHtml === 'function')
      ? refreshBtnHtml
      : (HW_STUDIO ? HW_STUDIO.refreshBtnHtml : null);
    if (refresh) h += refresh(s.stale === true, 'Načítať čerstvý katalóg kovania a sety');
    return h;
  }

  function hwEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // KOV-B2: filter ukazuje SK popisky (`CATEGORY_LABELS` zo servera), hodnota
  // ostava KODOM — inak by sa do dotazu poslalo „Spojovací materiál" a server
  // by nenasiel nic.
  function hwCatOptions(s){
    var out = '<option value=""' + (s.cat ? '' : ' selected') + '>Všetky kategórie</option>';
    (s.cats || []).forEach(function(c){
      out += '<option value="' + hwEsc(c) + '"' + (s.cat === c ? ' selected' : '') + '>' +
             hwEsc(mdhCatLabel(c)) + '</option>';
    });
    return out;
  }

  // `stale` podava `studio.js` — jantarovy priznak je stav OKNA a ma jedinu
  // autoritu (`staleFlag`), sekcia si ho neodvodzuje.
  function hwToolsState(stale){
    return { view: HW_VIEW, q: HW_Q, cat: HW_CAT, cats: MDH_CATS,
             inactive: HW_INACTIVE, ro: MDH_RO, stale: stale === true };
  }

  // KOV-B2: stav STROMU (pamät rozbalenia a stránkovania). Bez neho sa nedá
  // overiť, že „Načítať ďalšie" pýta ďalšiu stránku LISTU a že rozbalenie
  // prežije push zo servera.
  function hwTreeState(){
    return { expand: HW_EXPAND, more: HW_MORE, gen: MDH_TREE_GEN,
             leafPage: MDH_LEAF_PAGE, tree: MDH_TREE };
  }

  function hwRenderTools(stale){
    var box = hwEl('sectools');
    if (box) box.innerHTML = hwToolsHtml(hwToolsState(stale));
  }

  // TELO sekcie. Je to JEDEN uzol naklonovany RAZ zo sablony v studio.html
  // a potom uz LEN putuje: prepnutie sekcie ho z `#secbody` vyberie, navrat
  // ho vrati aj s rozpisanym formularom novej polozky a rozpisanym editorom
  // setu. Bez toho by kazdy odchod do Kusovnika zmazal rozrobenu pracu.
  var HW_BODY = null;
  function hwBodyNode(){
    if (HW_BODY) return HW_BODY;
    var tpl = hwEl('hwBodyTpl');
    HW_BODY = document.createElement('div');
    HW_BODY.id = 'hwBody';
    if (tpl && tpl.content) HW_BODY.appendChild(tpl.content.cloneNode(true));
    else if (tpl) HW_BODY.innerHTML = tpl.innerHTML;
    return HW_BODY;
  }

  // Pohlad sekcie riadi VIDITELNOST troch blokov tela. „Predvoľby projektu"
  // patria k Setom (mockup ich kresli ako jeden pohlad) — su v nom READ-ONLY
  // s premostenim do okna, lebo zapisuju do MODELU (presun v ŠT-3a-2).
  function hwApplyView(){
    var show = function(id, on){
      var n = hwEl(id);
      if (n) n.style.display = on ? '' : 'none';
    };
    show('hwTabItems', HW_VIEW !== 'sets');
    show('hwTabSets', HW_VIEW === 'sets');
    show('hwTabProj', HW_VIEW === 'sets');
  }

  function hwSetView(v){
    HW_VIEW = (v === 'sets') ? 'sets' : 'items';
    hwRenderTools(hwStale());
    hwApplyView();
  }

  // Jantarovy priznak drzi `studio.js` — sekcia si ho pri vlastnom prekresleni
  // (prepnutie pohladu) precita presne tak ako `js/budget.js` (`budStaleFlag`):
  // v prehliadaci je to global suboru, ktory sa nacitava PRED tymto.
  function hwStale(){
    return (typeof staleFlag === 'undefined') ? false : staleFlag === true;
  }

  // KONTRAKT (vzor audit #2 zo ŠT-2a): `NX.setStudio` NESMIE zmazat rozpisany
  // formular. Telo sa preto NEPREKRESLUJE — len sa (pripadne) vrati do
  // `#secbody` a data sa nasadia do jeho uzlov.
  function hwRenderBody(){
    var box = hwEl('secbody');
    if (!box) return;
    var node = hwBodyNode();
    var entered = node.parentNode !== box; // vstup do sekcie (alebo prve kreslenie)
    if (entered){
      box.innerHTML = '';
      box.appendChild(node);
    }
    mdhRenderEnums();
    mdhRenderBanner();
    mdhRender();
    if (typeof hwsRenderAll === 'function') hwsRenderAll();
    hwApplyView();
    // Poradie zo servera sa nevypytalo, kym telo nebolo v DOM.
    if (MDH_ORDER_PENDING){
      MDH_ORDER_PENDING = false;
      mdhTreeNow();
    }
    // ŠT-3a-3 tu dorovnavala zhody „Pridať z Demosu" k hodnote pola po navrate
    // do sekcie. KOV-B2: pole Démos zije v MODALI (`#nxModalRoot`), ktory
    // odchod zo sekcie zatvara — nie je co dorovnavat.
  }

  // Odchod zo sekcie `hw` (vola `studioGoSection` v studio.js PRED prepnutim).
  // Poradie je zavazne (lekcia ŠT-2b): NAJPRV sa ohlasi SERVERU (ten zrusi
  // beziace overenie ceny / nahlad a napise preco), az potom sa lokalne
  // zatvoria modaly.
  function hwOnLeaveSection(){
    if (window.sketchup && sketchup.hw_leave) sketchup.hw_leave('');
    // Review #219 P2-2: naplanovany (debounced) dotaz do Demosu MUSI zomriet
    // s odchodom. Vstup do sekcie a rychly odchod by inak poslal
    // `hw_demos_search` do sekcie, ktoru uz nikto nepozera — server by beh
    // oznacil za beziaci a NAJBLIZSI odchod by vypisal falosne „Zrušené…".
    if (mdhDemosTimer){
      clearTimeout(mdhDemosTimer);
      mdhDemosTimer = null;
    }
    hwCloseModals();
  }

  // R-23.1: zatvorenie potvrdenia mazania ma MENO. Escape retaz (`nx_esc.js`)
  // vola tu istu cestu ako tlacidlo „Zrušiť" — potrebuje teda volatelnu funkciu,
  // nie vetvu schovanu v delegacii klikov.
  function hwDelClose(){
    MDH_DEL = null;
    var m = hwEl('hwDelModal');
    if (m) m.style.display = 'none';
  }

  function hwCloseModals(){
    hwDelClose();
    // KOV-B2: modal polozky (D-15) zije v `#nxModalRoot` MIMO `#secbody`, teda
    // by po odchode do inej sekcie visel nad cudzim obsahom. Zatvorenie ide
    // cez kostru, takze `onClose` (`hwItemClosed`) zrusi aj nedokonceny nahlad
    // z Demosu a rozpisane hodnoty si zapamata (kontrakt D-15).
    if (typeof NXModal !== 'undefined' && NXModal && NXModal.isOpen &&
        NXModal.isOpen() && HW_ITEM){
      NXModal.close();
    }
  }

  // Modelovy kontext sekcie z payloadu Studia (`ST.hw`). Katalog je v nom LEN
  // pri prvom pushi, po prepnuti dokumentu a po rucnom „Obnoviť" — inak chodi
  // echom (`NX.setHwCatalog`), viz `StudioDialog#hw_payload`.
  function hwApplyState(h){
    if (!h) return;
    if (h.catalog){
      mdhApplyEnums(h.catalog);
      mdhSetItemsState(h.catalog);
      MDH_ORDER_PENDING = true;   // poradie si vypyta render tela
    }
    // ŠT-3a-3: LEN DATA. Render tela (a s nim aj setov) robi `hwRenderBody`
    // hned za tymto — `HWSETS.init` (data + render) by znamenal DVA rendery
    // na kazdy push: dvakrat zahodeny a znovu poskladany zoznam setov aj
    // predvolieb. Ked je pouzivatel v inej sekcii, render nepride vobec
    // a data pockaju na navrat (telo sa vtedy klonuje a `hwRenderBody`
    // ich vykresli).
    if (h.sets && typeof HWSETS !== 'undefined') HWSETS.setData(h.sets);
  }

  // Napojenie na kanal Studia. `studio.js` (a za nim `budget.js`
  // a `proj_materials.js`) uz `window.NX` vytvorili — tento subor sa nacitava
  // AZ ZA nimi, takze obal je bezpecny.
  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var hwPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      // Stav sa nasadi PRED renderom Studia — `hwRenderBody` uz kresli
      // z cerstvych dat a nikto nekresli dvakrat.
      hwApplyState(data && data.hw);
      hwPrevSetStudio(data);
    };
    // Katalogove echo (BEZ zdvihu generacie) — po kazdom zapise do katalogu.
    NX.setHwCatalog = function(data){
      if (!data) return;
      mdhApplyItems(data);
    };
    // ZOTAVOVACIE echo setov (review P1 #1) — po ODMIETNUTOM zapise. Prijimac
    // je ten isty ako v okne (`HWSETS.init`), takze sekcia dostane cerstvu
    // `revision` a jej dalsi pokus uz nespadne na tom istom konflikte.
    NX.setHwSets = function(data){
      if (!data || typeof HWSETS === 'undefined') return;
      HWSETS.init(data);
    };
  }

  // Node testy (tests/js/test_hw_catalog.js, tests/js/test_st3a_hw.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { mdhFmtPrice: mdhFmtPrice, mdhCheckedLabel: mdhCheckedLabel,
      mdhPatchPayload: mdhPatchPayload, mdhOrderItems: mdhOrderItems,
      mdhCapHint: mdhCapHint,
      mdhCssEscape: mdhCssEscape,
      mdhDemosIsUrl: mdhDemosIsUrl, mdhDemosCreatePayload: mdhDemosCreatePayload,
      mdhRelatedLine: mdhRelatedLine,
      // ŠT-3a-1 — sekcia `hw`. `hwToolsHtml` je cista funkcia; `hwRenderBody`
      // a `hwSetView` DOM potrebuju a exportuju sa ZAMERNE — kontrakt „push
      // zo servera nezmaze rozpisany formular" sa inak nedal overit nicim
      // nez klikanim (rovnaky dovod ako pri `matRenderBody`).
      hwToolsHtml: hwToolsHtml, hwRenderBody: hwRenderBody, hwSetView: hwSetView,
      // ŠT-3a-3: stav listy — bez neho sa nedá overit, ze `MDH.created`
      // vycistil filter aj v PREMENNYCH, nielen v uzloch.
      hwToolsState: hwToolsState,
      // KOV-B2 — modal polozky a strom. Ciste funkcie (polia, validacia,
      // patch, payload, „zmenil som udaj z Demosu?") sa daju overit bez DOM;
      // `hwItemOpen`/`hwTreeState` DOM potrebuju a exportuju sa ZAMERNE, lebo
      // kontrakty „server rozhoduje poradie" a „modal sa zatvara az na
      // potvrdenie" sa inak nedaju overit nicim nez klikanim.
      hwItemFields: hwItemFields, hwItemValidate: hwItemValidate,
      hwItemDraft: hwItemDraft, hwItemDraftOf: hwItemDraftOf,
      hwItemDraftFromProposal: hwItemDraftFromProposal,
      hwItemCreatePayload: hwItemCreatePayload, hwItemPatch: hwItemPatch,
      hwItemNote: hwItemNote, hwDemosDirty: hwDemosDirty, hwPriceKey: hwPriceKey,
      hwItemManOptions: hwItemManOptions, hwItemSerOptions: hwItemSerOptions,
      hwItemCatOptions: hwItemCatOptions, hwDemosHit: hwDemosHit,
      hwItemOpen: hwItemOpen, hwTreeState: hwTreeState,
      mdhGroupCount: mdhGroupCount, mdhCatLabel: mdhCatLabel,
      hwOnLeaveSection: hwOnLeaveSection, hwApplyState: hwApplyState, MDH: MDH };
  }
  // ŠT-3a-2 (vzor `proj_materials.js` po ŠT-2b): `sketchup.ready('')` tu
  // ZANIKLO CELE. V okne „Katalóg kovania" bol tento subor POSLEDNY a jeho
  // `ready` znamenal „HTML je nacitane"; okno zaniklo a v Studiu `ready`
  // posiela `studio.js` (`window.onload`) — druhe volanie by prinutilo okno
  // poslat CELY payload dvakrat. `window.NX_HW_SECTION` v `studio.html`
  // ostava ako CITATELNE prihlasenie sa do rezimu sekcie (a marker poradia
  // skriptov pre guard test).
