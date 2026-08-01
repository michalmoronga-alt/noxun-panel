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

  function hwEl(id){ return document.getElementById(id); }
  function mdhMk(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
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

  function mdhSearchNow(){
    mdhSend('hw_search', {
      query: (hwEl('hwSearch') || {}).value || '',
      category: (hwEl('hwCategory') || {}).value || '',
      include_inactive: !!(hwEl('hwInactive') && hwEl('hwInactive').checked)
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
    var toggle = mdhMk('button', 'ghostbtn tplbtn', MDH_OPEN === item.item_code ? '▾' : '▸');
    toggle.setAttribute('data-action', 'hw-toggle');
    toggle.setAttribute('data-hw-code', item.item_code);
    toggle.setAttribute('aria-label', 'Detail položky');
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
      var sel = '.mdcell[data-hw-code="' + keepFocus.code.replace(/"/g, '\\"') +
        '"][data-hw-field="' + keepFocus.field + '"]';
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

  function mdhApplyItems(data){
    MDH_ITEMS = {};
    (data.items || []).forEach(function(i){ MDH_ITEMS[i.item_code] = i; });
    MDH_RO = data.state === 'read_only';
    var banner = hwEl('hwRoBanner');
    if (banner) banner.style.display = MDH_RO ? '' : 'none';
    var txt = hwEl('hwRoText');
    if (txt) txt.textContent = data.state_reason || 'Katalóg je len na čítanie.';
    // poradie: zachovaj posledny search vysledok; nove/neexistujuce kody
    // dopln na koniec (cerstvo pridana polozka musi byt hned viditelna)
    var known = {};
    MDH_ORDER = MDH_ORDER.filter(function(c){ if (!MDH_ITEMS[c] || known[c]) return false; known[c] = true; return true; });
    Object.keys(MDH_ITEMS).forEach(function(c){ if (!known[c]){ MDH_ORDER.push(c); known[c] = true; } });
    mdhRender();
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

  // --- verejne API pre Ruby ------------------------------------------------

  var MDH = {
    init: function(data){
      MDH_CATS = data.categories || [];
      MDH_UNITS = data.units || [];
      var line = hwEl('hwline');
      if (line) line.textContent = 'V' + (data.version || '') + ' · položiek: ' + (data.items || []).length;
      ['hn_category', 'hwCategory'].forEach(function(id){
        var sel = hwEl(id);
        if (!sel) return;
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
      mdhApplyItems(data);
      mdhSearchNow(); // prvotne serverove poradie
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
    priceApplied: function(r){ delete MDH_PRICE[r.code]; },
    created: function(){
      var f = hwEl('hwNewForm');
      if (f) f.style.display = 'none';
      ['hn_code', 'hn_name', 'hn_price', 'hn_supplier', 'hn_notes'].forEach(function(id){
        var i = hwEl(id);
        if (i) i.value = '';
      });
    }
  };

  // --- delegovane ovladanie -------------------------------------------------

  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('click', function(ev){
      var t = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
      if (!t) return;
      var action = t.getAttribute('data-action');
      var code = t.getAttribute('data-hw-code') || '';
      if (action === 'hw-toggle'){
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
        var urlInp = document.querySelector('input[data-hw-url="' + code.replace(/"/g, '\\"') + '"]');
        MDH_PRICE[code] = { status: 'pending' };
        mdhRender();
        mdhSend('hw_check_price', { code: code, url: urlInp ? urlInp.value.trim() : '' });
      } else if (action === 'hw-apply'){
        mdhSend('hw_apply_price', { code: code });
      }
    });
    document.addEventListener('focusout', function(ev){
      var t = ev.target;
      if (t && t.classList && t.classList.contains('mdcell') && t.getAttribute('data-hw-field')){
        mdhFlushCell(t);
      }
    });
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.tagName === 'SELECT' && t.getAttribute('data-hw-field')) mdhChanged(t);
      else if (t.type === 'checkbox' && t.getAttribute('data-hw-field')) mdhChanged(t);
    });
    var si = hwEl('hwSearch');
    if (si) si.addEventListener('input', mdhSearchDebounced);
    var ci = hwEl('hwCategory');
    if (ci) ci.addEventListener('change', mdhSearchNow);
    var ii = hwEl('hwInactive');
    if (ii) ii.addEventListener('change', mdhSearchNow);
  }

  // Node testy (tests/js/test_hw_catalog.js) — len ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { mdhFmtPrice: mdhFmtPrice, mdhCheckedLabel: mdhCheckedLabel,
      mdhPatchPayload: mdhPatchPayload, mdhOrderItems: mdhOrderItems,
      mdhCreatePayload: mdhCreatePayload };
  }
  if (typeof window !== 'undefined' && window.sketchup && sketchup.ready) sketchup.ready('');
