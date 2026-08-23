  // ===================== Katalog kovania (V0.6 C-2) =====================
  // Server (Ruby) je autorita: search poradie, hodnoty, revizie. JS len
  // renderuje a posiela flagy/payloady s row_rev. XSS kontrakt (vzor
  // demos_diff.js): obsah VYHRADNE createElement + textContent; ovladanie
  // data-action delegaciou; ziadne innerHTML s datami, ziadne inline
  // handlery s hodnotami. Cenove overenie = serverovy proposal (JS posiela
  // len kod; hodnotu nikdy).

  var MDH_ITEMS = {};   // item_code -> zaznam (s row_rev)
  var MDH_ORDER = [];   // poradie zo SERVEROVEHO searchu (F12)
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
  // Zoradenie poloziek podla SERVEROVEHO poradia kodov (neznamy kod sa
  // vynecha — polozka medzitym zmizla).
  function mdhOrderItems(map, codes){
    var out = [];
    (codes || []).forEach(function(c){ if (map[c]) out.push(map[c]); });
    return out;
  }
  // Create payload z formularovych hodnot — polia 1:1, server validuje.
  function mdhCreatePayload(vals){
    return { fields: { item_code: vals.code, name_sk: vals.name,
                       category: vals.category, unit: vals.unit,
                       price_eur_vat: vals.price, supplier: vals.supplier,
                       notes: vals.notes } };
  }

  // --- komunikacia so serverom --------------------------------------------

  function mdhSend(name, payload){
    if (window.sketchup && sketchup[name]) sketchup[name](JSON.stringify(payload));
  }

  // ŠT-3a-1: v SEKCII ziju filtre v LISTE, a tu NIE JE vykreslena, kym je
  // otvoreny pohlad Sety. Bez fallbacku na stav by vtedy kazdy push poslal
  // PRAZDNY dotaz — a navrat do pohladu Položky by ukazal nefiltrovany zoznam
  // pod vyplnenym polom hladania. V okne sa nic nemeni: uzly tam su vzdy.
  function mdhSearchNow(){
    var s = hwEl('hwSearch');
    var c = hwEl('hwCategory');
    var i = hwEl('hwInactive');
    mdhSend('hw_search', {
      query: s ? (s.value || '') : HW_Q,
      category: c ? (c.value || '') : HW_CAT,
      include_inactive: i ? !!i.checked : HW_INACTIVE
    });
  }

  function mdhSearchDebounced(){
    if (mdhSearchTimer) clearTimeout(mdhSearchTimer);
    mdhSearchTimer = setTimeout(mdhSearchNow, 150);
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

  function mdhSelect(item, field, options, current){
    var sel = mdhMk('select');
    options.forEach(function(o){
      var op = mdhMk('option', null, o);
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
    line1.appendChild(mdhSelect(item, 'category', MDH_CATS, item.category));
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
    var itemsArr = mdhOrderItems(MDH_ITEMS, MDH_ORDER);
    if (!itemsArr.length){
      list.appendChild(mdhMk('div', 'muted', 'Žiadne položky — uprav hľadanie alebo pridaj novú.'));
    }
    itemsArr.forEach(function(item){
      list.appendChild(mdhRow(item));
      if (MDH_OPEN === item.item_code) list.appendChild(mdhDetail(item));
    });
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
    if (data.units) MDH_UNITS = data.units;
    if (data.version) MDH_VERSION = data.version;
  }

  function mdhRenderEnums(){
    var line = hwEl('hwline');
    if (line) line.textContent = 'V' + MDH_VERSION + ' · položiek: ' + Object.keys(MDH_ITEMS).length;
    ['hn_category', 'hwCategory'].forEach(function(id){
      var sel = hwEl(id);
      if (!sel) return;
      var keep = sel.value;
      sel.textContent = '';
      if (id === 'hwCategory'){
        var all = mdhMk('option', null, 'Všetky kategórie');
        all.value = '';
        sel.appendChild(all);
      }
      MDH_CATS.forEach(function(c){
        var op = mdhMk('option', null, c);
        op.value = c;
        sel.appendChild(op);
      });
      if (keep) sel.value = keep; // filter prezije prekreslenie enumov
    });
    var us = hwEl('hn_unit');
    if (us){
      us.textContent = '';
      MDH_UNITS.forEach(function(u){
        var op = mdhMk('option', null, u);
        op.value = u;
        us.appendChild(op);
      });
    }
  }

  function mdhApplyItems(data){
    mdhSetItemsState(data);
    mdhRenderBanner();
    mdhRender();
    // Bez tela v DOM sa nema kam vykreslit — poradie si vypyta az render.
    if (hwEl('hwList')) mdhSearchNow();
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

  // --- V0.6 D2: Pridat z Demosu ---------------------------------------------
  // Jedno pole URL/nazov (vzor M-A): text -> zive zhody zo sitemap (server),
  // URL/klik na zhodu -> nahlad zo stranky (server proposal, pid) -> zapis.
  // Hodnoty polozky NIKDY necestuju z klienta — len pid + kategoria + notes.

  var MDH_DEMOS = null;      // posledny preview proposal (res zo servera)
  var mdhDemosTimer = null;

  function mdhDemosIsUrl(text){
    return /^https?:\/\//i.test(String(text == null ? '' : text).trim());
  }
  function mdhDemosCreatePayload(prop, category, notes){
    return { pid: (prop && prop.pid) || '', category: category || '', notes: notes || '' };
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

  function mdhDemosInput(){
    var inp = hwEl('hn_demos');
    var q = inp ? inp.value.trim() : '';
    if (mdhDemosIsUrl(q)){ mdhRenderDemosHits([]); return; }
    if (q.length < 3){ mdhRenderDemosHits([]); return; }
    if (mdhDemosTimer) clearTimeout(mdhDemosTimer);
    mdhDemosTimer = setTimeout(function(){ mdhSend('hw_demos_search', { query: q }); }, 200);
  }

  function mdhDemosLoad(url){
    MDH_DEMOS = { status: 'pending' };
    mdhRenderDemosPreview();
    mdhSend('hw_demos_preview', { url: url });
  }

  function mdhRenderDemosHits(results){
    var box = hwEl('hwDemosHits');
    if (!box) return;
    box.textContent = '';
    (results || []).forEach(function(r){
      var row = mdhMk('div', 'hwdemos-hit', r.label || r.slug);
      row.setAttribute('data-action', 'hw-demos-hit');
      row.setAttribute('data-url', r.url);
      box.appendChild(row);
    });
  }

  function mdhRenderDemosPreview(){
    var box = hwEl('hwDemosPreview');
    if (!box) return;
    var d = MDH_DEMOS;
    box.textContent = '';
    box.style.display = d ? '' : 'none';
    var manual = hwEl('hwManualHint');
    if (manual) manual.style.display = (d && d.ok) ? 'none' : '';
    if (!d) return;
    if (d.status === 'pending'){
      box.appendChild(mdhMk('div', 'muted', 'Načítavam stránku…'));
      // GH #128 P2: zrusit sa da aj POCAS fetchu (server bumpne generaciu)
      var pb = mdhMk('div', 'btnrow');
      var pc = mdhMk('button', 'ghostbtn', 'Zrušiť náhľad');
      pc.setAttribute('data-action', 'hw-demos-cancel');
      pb.appendChild(pc);
      box.appendChild(pb);
      return;
    }
    if (!d.ok){
      box.appendChild(mdhMk('div', 'err', 'Nedá sa načítať: ' + (d.error || 'neznáma chyba')));
      return;
    }
    var head = mdhMk('div', 'hwdemos-head');
    head.appendChild(mdhMk('b', null, d.code));
    head.appendChild(mdhMk('span', null, d.name_sk));
    box.appendChild(head);
    var meta = mdhMk('div', 'hwdemos-meta',
      (d.price_vat != null ? mdhFmtPrice(d.price_vat) + ' s DPH · ' : 'cena na stránke nie je · ') + d.unit);
    box.appendChild(meta);
    if (d.exists){
      box.appendChild(mdhMk('div', 'hwdemos-warn',
        'Tento kód už v katalógu je — cenu obnovíš cez „Overiť" na existujúcej položke.'));
    }
    var rel = mdhRelatedLine(d.related);
    if (rel) box.appendChild(mdhMk('div', 'hwdemos-rel', rel));
    var row = mdhMk('div', 'row');
    row.appendChild(mdhMk('label', null, 'Kategória'));
    var sel = mdhMk('select');
    sel.id = 'hn_demos_category';
    MDH_CATS.forEach(function(c){
      var op = mdhMk('option', null, c);
      op.value = c;
      if (c === d.category_guess) op.selected = true;
      sel.appendChild(op);
    });
    row.appendChild(sel);
    row.appendChild(mdhMk('span', 'unit', 'návrh'));
    box.appendChild(row);
    var row2 = mdhMk('div', 'row');
    row2.appendChild(mdhMk('label', null, 'Poznámka'));
    var notes = mdhMk('input');
    notes.type = 'text';
    notes.id = 'hn_demos_notes';
    row2.appendChild(notes);
    row2.appendChild(mdhMk('span', 'unit', ''));
    box.appendChild(row2);
    var btns = mdhMk('div', 'btnrow');
    if (!d.exists){
      var create = mdhMk('button', 'primary', 'Vytvoriť z Demosu');
      create.setAttribute('data-action', 'hw-demos-create');
      btns.appendChild(create);
    }
    var cancel = mdhMk('button', 'ghostbtn', 'Zrušiť náhľad');
    cancel.setAttribute('data-action', 'hw-demos-cancel');
    btns.appendChild(cancel);
    box.appendChild(btns);
  }

  // --- verejne API pre Ruby ------------------------------------------------

  var MDH = {
    init: function(data){
      mdhApplyEnums(data);
      mdhRenderEnums();
      mdhApplyItems(data); // vratane prvotneho serveroveho poradia
    },
    setItems: function(data){ mdhApplyItems(data); },
    results: function(data){ MDH_ORDER = data.codes || []; mdhRender(); },
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
    // V0.6 D2: zive zhody + nahlad + zapis z Demosu
    demosResults: function(d){
      var inp = hwEl('hn_demos');
      // neaktualne vysledky (pouzivatel medzitym pise dalej) sa zahadzuju
      if (!inp || inp.value.trim() !== (d.query || '')) return;
      if (d.refreshing){
        var box = hwEl('hwDemosHits');
        if (box){
          box.textContent = '';
          box.appendChild(mdhMk('div', 'muted', 'Sťahujem zoznam produktov Demosu (prvé použitie, chvíľu to trvá)…'));
        }
        return;
      }
      mdhRenderDemosHits(d.results || []);
    },
    // GH #128 P2: sitemap cache dobehla — zopakuj AKTUALNY dotaz
    demosRefreshDone: function(){
      var inp = hwEl('hn_demos');
      var q = inp ? inp.value.trim() : '';
      if (q.length >= 3 && !mdhDemosIsUrl(q)) mdhSend('hw_demos_search', { query: q });
    },
    demosPreview: function(res){
      MDH_DEMOS = res || { ok: false, error: 'prázdna odpoveď' };
      mdhRenderDemosHits([]);
      mdhRenderDemosPreview();
    },
    demosCreated: function(){
      MDH_DEMOS = null;
      var i = hwEl('hn_demos');
      if (i) i.value = '';
      mdhRenderDemosPreview();
      MDH.created();
    },
    created: function(){
      var f = hwEl('hwNewForm');
      if (f) f.style.display = 'none';
      ['hn_code', 'hn_name', 'hn_price', 'hn_supplier', 'hn_notes'].forEach(function(id){
        var i = hwEl(id);
        if (i) i.value = '';
      });
      // GH #100 P2: nova polozka musi byt hned viditelna — filter sa vycisti
      // a poradie pride zo servera (ziadne lokalne doplnanie).
      var q = hwEl('hwSearch');
      if (q) q.value = '';
      var c = hwEl('hwCategory');
      if (c) c.value = '';
      mdhSearchNow();
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
      } else if (action === 'hw-new'){
        var f = hwEl('hwNewForm');
        if (f) f.style.display = f.style.display === 'none' ? '' : 'none';
      } else if (action === 'hw-new-close'){
        var f2 = hwEl('hwNewForm');
        if (f2) f2.style.display = 'none';
      } else if (action === 'hw-create'){
        mdhSend('hw_create', mdhCreatePayload({
          code: (hwEl('hn_code') || {}).value || '', name: (hwEl('hn_name') || {}).value || '',
          category: (hwEl('hn_category') || {}).value || '', unit: (hwEl('hn_unit') || {}).value || '',
          price: (hwEl('hn_price') || {}).value || '', supplier: (hwEl('hn_supplier') || {}).value || '',
          notes: (hwEl('hn_notes') || {}).value || ''
        }));
      } else if (action === 'hw-del'){
        MDH_DEL = code;
        var txt = hwEl('hwDelText');
        var item = MDH_ITEMS[code];
        if (txt) txt.textContent = 'Zmazať ' + code + (item ? ' — ' + item.name_sk : '') + '?';
        var m = hwEl('hwDelModal');
        if (m) m.style.display = '';
      } else if (action === 'hw-del-close'){
        MDH_DEL = null;
        var m2 = hwEl('hwDelModal');
        if (m2) m2.style.display = 'none';
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
      } else if (action === 'hw-demos-load'){
        var di = hwEl('hn_demos');
        var val = di ? di.value.trim() : '';
        if (mdhDemosIsUrl(val)) mdhDemosLoad(val);
        else MDH.setStatus('Vlož URL produktu z demos-trade.sk, alebo klikni na zhodu z hľadania.', true);
      } else if (action === 'hw-demos-hit'){
        mdhDemosLoad(t.getAttribute('data-url') || '');
      } else if (action === 'hw-demos-create'){
        var catSel = hwEl('hn_demos_category');
        var notesInp = hwEl('hn_demos_notes');
        mdhSend('hw_demos_create', mdhDemosCreatePayload(MDH_DEMOS,
          catSel ? catSel.value : '', notesInp ? notesInp.value.trim() : ''));
      } else if (action === 'hw-demos-cancel'){
        // GH #128 P2: server bumpne generaciu — dobiehajuci fetch uz zruseny
        // nahlad znovu neotvori.
        mdhSend('hw_demos_cancel', {});
        MDH_DEMOS = null;
        mdhRenderDemosPreview();
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
      if (t.id === 'hwCategory'){ HW_CAT = t.value; mdhSearchNow(); return; }
      if (t.id === 'hwInactive'){ HW_INACTIVE = !!t.checked; mdhSearchNow(); return; }
      if (t.tagName === 'SELECT' && t.getAttribute('data-hw-field')) mdhChanged(t);
      else if (t.type === 'checkbox' && t.getAttribute('data-hw-field')) mdhChanged(t);
    });
    // Ten isty dovod pre textove vstupy (hladanie zije v liste sekcie,
    // pole „Z Demosu" v tele, ktore vznika az pri prvom vykresleni sekcie).
    document.addEventListener('input', function(ev){
      var t = ev.target;
      if (!t || !t.id) return;
      if (t.id === 'hwSearch'){ HW_Q = t.value; mdhSearchDebounced(); return; }
      if (t.id === 'hn_demos') mdhDemosInput();
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

  // Sekcia sa prihlasi do READ-ONLY rezimu predvolieb projektu hned pri
  // nacitani — este pred prvym `HWSETS.init` (ten uz kresli). `hw_sets.js`
  // sa nacitava PRED tymto suborom v OBOCH HTML, takze funkcia uz existuje.
  if (typeof window !== 'undefined' && window.NX_HW_SECTION &&
      typeof hwsSetProjReadOnly === 'function'){
    hwsSetProjReadOnly(true);
  }

  // Stav LISTY sekcie. Lista sa prekresluje pri KAZDOM pushi, takze hodnoty
  // vstupov musia zit aj v premennych (vzor `MD_Q`/`MD_MODE` v Materialoch) —
  // inak by pouzivatelovi zmizol filter pri prvom prepocte kusovnika.
  var HW_VIEW = 'items';    // items | sets (Š16)
  var HW_Q = '';
  var HW_CAT = '';
  var HW_INACTIVE = false;

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

  function hwCatOptions(s){
    var out = '<option value=""' + (s.cat ? '' : ' selected') + '>Všetky kategórie</option>';
    (s.cats || []).forEach(function(c){
      out += '<option value="' + hwEsc(c) + '"' + (s.cat === c ? ' selected' : '') + '>' +
             hwEsc(c) + '</option>';
    });
    return out;
  }

  // `stale` podava `studio.js` — jantarovy priznak je stav OKNA a ma jedinu
  // autoritu (`staleFlag`), sekcia si ho neodvodzuje.
  function hwToolsState(stale){
    return { view: HW_VIEW, q: HW_Q, cat: HW_CAT, cats: MDH_CATS,
             inactive: HW_INACTIVE, ro: MDH_RO, stale: stale === true };
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
    if (node.parentNode !== box){
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
      mdhSearchNow();
    }
  }

  // Odchod zo sekcie `hw` (vola `studioGoSection` v studio.js PRED prepnutim).
  // Poradie je zavazne (lekcia ŠT-2b): NAJPRV sa ohlasi SERVERU (ten zrusi
  // beziace overenie ceny / nahlad a napise preco), az potom sa lokalne
  // zatvoria modaly.
  function hwOnLeaveSection(){
    if (window.sketchup && sketchup.hw_leave) sketchup.hw_leave('');
    hwCloseModals();
  }

  function hwCloseModals(){
    var m = hwEl('hwDelModal');
    if (m) m.style.display = 'none';
    MDH_DEL = null;
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
    // Sety maju v OBOCH UI ten isty prijimac; jeho render je bezpecny aj ked
    // telo sekcie este nie je pripojene (uzly sa nenajdu a funkcia vypadne).
    if (h.sets && typeof HWSETS !== 'undefined') HWSETS.init(h.sets);
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
  }

  // Node testy (tests/js/test_hw_catalog.js, tests/js/test_st3a_hw.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { mdhFmtPrice: mdhFmtPrice, mdhCheckedLabel: mdhCheckedLabel,
      mdhPatchPayload: mdhPatchPayload, mdhOrderItems: mdhOrderItems,
      mdhCreatePayload: mdhCreatePayload, mdhCssEscape: mdhCssEscape,
      mdhDemosIsUrl: mdhDemosIsUrl, mdhDemosCreatePayload: mdhDemosCreatePayload,
      mdhRelatedLine: mdhRelatedLine,
      // ŠT-3a-1 — sekcia `hw`. `hwToolsHtml` je cista funkcia; `hwRenderBody`
      // a `hwSetView` DOM potrebuju a exportuju sa ZAMERNE — kontrakt „push
      // zo servera nezmaze rozpisany formular" sa inak nedal overit nicim
      // nez klikanim (rovnaky dovod ako pri `matRenderBody`).
      hwToolsHtml: hwToolsHtml, hwRenderBody: hwRenderBody, hwSetView: hwSetView,
      hwOnLeaveSection: hwOnLeaveSection, hwApplyState: hwApplyState, MDH: MDH };
  }
  // ŠT-3a-1 (vzor ŠT-2a audit #7): v okne ŠTÚDIO `ready` posiela `studio.js`
  // (window.onload) — druhe volanie odtialto by Studio prinutilo poslat CELY
  // payload dvakrat a spustit odlozene poziadavky znova. Okno „Katalóg
  // kovania" ale ZIJE dalej a svoj `ready` potrebuje (je jedinou cestou
  // k prvemu pushu), preto sa posiela LEN mimo sekcie.
  if (typeof window !== 'undefined' && !window.NX_HW_SECTION &&
      window.sketchup && sketchup.ready) sketchup.ready('');
