  // ===================== Demos diff modal (V0.6 B-2b) =====================
  // Lookup a apply kodov/cien dekorovej skupiny z demos-trade.sk.
  //
  // Bezpecnostny kontrakt (audit B-2 BLOCKER 6 — XSS):
  //   - VSETKY hodnoty z Demosu (nazvy, kody, URL, kandidati) sa do DOM davaju
  //     VYHRADNE cez createElement + textContent / setAttribute — v tomto
  //     module NIKDY innerHTML s datami a NIKDY inline onclick s hodnotou.
  //   - ovladanie modalu = event delegation na statickom #demosModal
  //     (data-action atributy), stav zije v JS modeli, nie v handleroch.
  //   - server (Ruby) je autorita hodnot: apply posiela LEN accept flagy +
  //     row_rev; hodnoty si server berie z vlastneho proposal store.
  //
  // Session: kazdy event nesie session cislo z Ruby (monotonne — ABA guard
  // BLOCKER 5). Novsia session = novy model; eventy starsej session sa zahodia.

  var MDD_STATE = null;

  // ŠT-2b (REGRESIA z ŠT-2a): tento subor volal globalne `el(id)`. To bola
  // funkcia z `proj_materials.js`, ktora sa v ŠT-2a premenovala na `mdEl`
  // (kolizia mien v okne Studio) — a modal „Aktualizovať z Demosu" tak od
  // v0.7.45 padal na `ReferenceError: el is not defined` hned pri otvoreni.
  // Vlastny pomocnik s prefixom modulu je jedina cesta, ktora sa uz nema ako
  // rozist: nezavisi na poradí skriptov ani na cudzich menach.
  function mddId(id){
    return (typeof document === 'undefined') ? null : document.getElementById(id);
  }

  function mddNewModel(session){
    return { session: session, order: [], byKey: {}, accessories: [],
             warnings: [], complete: null, progress: { done: 0, total: 0 },
             refreshing: false };
  }

  // Cista funkcia (Node test): aplikuj event na model. Vrati model (pri novej
  // session NOVY). Stary event (nizsia session) sa ignoruje.
  function mddApplyEvent(model, e){
    var s = e && e.session != null ? e.session : (model ? model.session : 0);
    if (!model || s > model.session) model = mddNewModel(s);
    else if (s < model.session) return model;
    if (e.type === 'sitemap'){ model.refreshing = e.state === 'refreshing'; }
    else if (e.type === 'progress'){ model.progress = { done: e.done || 0, total: e.total || 0 }; }
    else if (e.type === 'proposal' && e.proposal){
      var p = e.proposal;
      var key = p.kind + '|' + p.record_id;
      if (!model.byKey[key]) model.order.push(key);
      model.byKey[key] = p;
    } else if (e.type === 'manual_done'){
      // GH #98 P2: koniec MANUALNEHO fetchu NIE JE koniec skupinoveho lookupu
      // — terminalny stav (complete/Apply) patri vyhradne behu skupiny; navrh
      // manualu uz prisiel proposal eventom, netreba nic menit.
    } else if (e.type === 'complete'){
      model.complete = { ok: e.ok === true, error: e.error || null };
      model.warnings = (model.warnings || []).concat(e.warnings || []);
      model.accessories = e.accessories || [];
      model.refreshing = false;
    }
    return model;
  }

  // Cista funkcia: ponuky jedneho proposalu + checkbox defaulty (F16 — default
  // ON len PRAZDNE pole; existujuca hodnota sa prepisuje len vedome; potvrdenie
  // nezmenenej ceny je ON, lebo hodnotu NEMENI, len obnovi datum overenia).
  function mddOffers(p){
    if (!p || p.status !== 'match') return null;
    var out = { code: null, price: null, confirm: null };
    var codeNew = p.code && p.code['new'] ? String(p.code['new']) : '';
    var codeOld = p.code && p.code.old != null ? String(p.code.old) : '';
    if (codeNew && codeNew !== codeOld){
      out.code = { oldv: codeOld, newv: codeNew, def: codeOld === '' };
    }
    var pr = p.price || {};
    if (pr.unchanged === true){
      out.confirm = { def: true };
    } else if (pr['new'] != null){
      var oldP = pr.old != null ? Number(pr.old) : null;
      out.price = { oldv: oldP, newv: Number(pr['new']), def: oldP == null };
    }
    return (out.code || out.price || out.confirm) ? out : null;
  }

  // Cista funkcia: model -> view {updates, clean, attention, accessories}.
  // updates = match s aspon jednou ponukou; clean = match bez ponuky (vsetko
  // zhodne, cena nepotvrditelna); attention = vsetko ostatne s dovodom.
  function mddBuildView(model){
    var v = { updates: [], clean: [], attention: [], accessories: model ? model.accessories : [] };
    if (!model) return v;
    model.order.forEach(function(key){
      var p = model.byKey[key];
      if (!p) return;
      if (p.status === 'match'){
        var offers = mddOffers(p);
        if (offers) v.updates.push({ key: key, p: p, offers: offers });
        else v.clean.push({ key: key, p: p });
      } else {
        v.attention.push({ key: key, p: p,
                           manual: ['miss', 'ambiguous', 'identity_fail', 'fetch_error'].indexOf(p.status) >= 0 });
      }
    });
    return v;
  }

  // Cista funkcia: row_rev zaznamu z plneho katalogu (baseline pre apply).
  function mddRowRevOf(catalog, kind, id){
    var list = kind === 'edge' ? (catalog.edges || []) : (catalog.sheets || []);
    var idk = kind === 'edge' ? 'abs_id' : 'material_id';
    for (var i = 0; i < list.length; i++){
      if (list[i][idk] === id) return list[i].row_rev || '';
    }
    return '';
  }

  // Cista funkcia: zaskrtnutia -> accepts payload. checks = [{key, code, price}]
  // (stav checkboxov z DOM); posielaju sa LEN flagy + row_rev — ziadne hodnoty
  // (server autorita). Polozka bez zaskrtnutia sa vynecha.
  function mddAccepts(view, checks, catalog){
    var byKey = {};
    (checks || []).forEach(function(c){ byKey[c.key] = c; });
    var out = [];
    view.updates.forEach(function(u){
      var c = byKey[u.key] || {};
      var wantCode = !!(u.offers.code && c.code);
      var wantPrice = !!((u.offers.price || u.offers.confirm) && c.price);
      if (!wantCode && !wantPrice) return;
      out.push({ kind: u.p.kind, id: u.p.record_id, code: wantCode, price: wantPrice,
                 row_rev: mddRowRevOf(catalog, u.p.kind, u.p.record_id) });
    });
    return out;
  }

  // Cista funkcia: SK popis stavu pre sekciu "Nenajdene" / info riadky.
  function mddStatusLabel(status){
    return { miss: 'nenašlo sa v zozname produktov',
             ambiguous: 'viac kandidátov — vlož presnú adresu produktu',
             identity_fail: 'stránka nesedí s identitou záznamu',
             fetch_error: 'sťahovanie zlyhalo',
             no_width: 'ABS bez šírky — doplň šírku variantu',
             unsupported: 'typ sa nedá overiť voči Demosu',
             skipped_duplak: 'duplák — kupuje sa zdrojová doska' }[status] || status;
  }

  // D-70 (GH #111 P2): server dava k identity_fail/miss SPECIFICKEJSI dovod
  // do warnings (napr. "ulozena vazba uz nesedi — vloz novu adresu") — riadok
  // ho musi ukazat namiesto genericheho labelu, inak slub hlasky neplati.
  // Cista funkcia (Node test): posledny warning je serverov zaverecny dovod.
  function mddAttentionText(p){
    if (p && (p.status === 'identity_fail' || p.status === 'miss') &&
        p.warnings && p.warnings.length){
      return p.warnings[p.warnings.length - 1];
    }
    return mddStatusLabel(p ? p.status : '');
  }

  function mddFmtPrice(v){
    return v == null ? '—' : (Math.round(Number(v) * 100) / 100).toFixed(2) + ' €';
  }

  // ===== DOM cast (CEF only) ================================================

  function mddEl(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text; // XSS-safe: VZDY textContent
    return n;
  }

  function mddVariantLabel(p){
    // label riadku = katalogovy label zaznamu (z MD_CATALOG), fallback id
    var list = p.kind === 'edge' ? (MD_CATALOG.edges || []) : (MD_CATALOG.sheets || []);
    var idk = p.kind === 'edge' ? 'abs_id' : 'material_id';
    for (var i = 0; i < list.length; i++){
      if (list[i][idk] === p.record_id) return list[i].label || p.record_id;
    }
    return p.record_id;
  }

  function mddCheckbox(name, def){
    var cb = mddEl('input');
    cb.type = 'checkbox';
    cb.checked = !!def;
    cb.setAttribute('data-mdd-check', name);
    return cb;
  }

  function mddUpdateRow(u){
    var row = mddEl('div', 'mddrow');
    row.setAttribute('data-mdd-key', u.key);
    row.appendChild(mddEl('span', 'mddlbl', mddVariantLabel(u.p)));
    var body = mddEl('span', 'mddoffers');
    if (u.offers.code){
      var lc = mddEl('label', 'mddoffer');
      lc.appendChild(mddCheckbox('code', u.offers.code.def));
      lc.appendChild(mddEl('span', null,
        'kód ' + (u.offers.code.oldv || '—') + ' → ' + u.offers.code.newv + ' (dodávateľ → Demos)'));
      body.appendChild(lc);
    } else if (u.p.code && u.p.code['new']){
      body.appendChild(mddEl('span', 'mddsame', 'kód ' + u.p.code['new'] + ' ✓'));
    }
    if (u.offers.price){
      var lp = mddEl('label', 'mddoffer');
      lp.appendChild(mddCheckbox('price', u.offers.price.def));
      lp.appendChild(mddEl('span', null,
        'cena ' + mddFmtPrice(u.offers.price.oldv) + ' → ' + mddFmtPrice(u.offers.price.newv) +
        (u.p.kind === 'edge' ? ' /bm' : ' /m²') + ' s DPH'));
      body.appendChild(lp);
    } else if (u.offers.confirm){
      var lu = mddEl('label', 'mddoffer');
      lu.appendChild(mddCheckbox('price', u.offers.confirm.def));
      lu.appendChild(mddEl('span', null, 'cena nezmenená — potvrdiť dátum overenia'));
      body.appendChild(lu);
    }
    (u.p.warnings || []).forEach(function(w){ body.appendChild(mddEl('div', 'mddwarn', w)); });
    row.appendChild(body);
    return row;
  }

  function mddAttentionRow(a){
    var row = mddEl('div', 'mddrow mddmiss');
    row.setAttribute('data-mdd-key', a.key);
    row.appendChild(mddEl('span', 'mddlbl', mddVariantLabel(a.p)));
    var body = mddEl('span', 'mddoffers');
    body.appendChild(mddEl('span', 'mddwarn', mddAttentionText(a.p)));
    (a.p.candidates || []).slice(0, 3).forEach(function(c){
      body.appendChild(mddEl('div', 'mddcand', c));
    });
    if (a.manual){
      var wrap = mddEl('div', 'mddmanual');
      var inp = mddEl('input');
      inp.type = 'text';
      inp.placeholder = 'https://www.demos-trade.sk/…';
      inp.setAttribute('data-mdd-url', a.key);
      var btn = mddEl('button', 'ghostbtn tplbtn', 'Použiť adresu');
      btn.setAttribute('data-action', 'manual');
      btn.setAttribute('data-mdd-key', a.key);
      wrap.appendChild(inp);
      wrap.appendChild(btn);
      body.appendChild(wrap);
    }
    row.appendChild(body);
    return row;
  }

  function mddRender(){
    var body = mddId('mddBody');
    if (!body) return;
    body.textContent = '';
    var m = MDD_STATE;
    var v = mddBuildView(m);
    var status = mddId('mddStatus');
    if (status){
      var txt;
      if (!m) txt = '';
      else if (!m.complete){
        txt = m.refreshing ? 'Obnovujem zoznam produktov Demosu…'
          : 'Kontrolujem produkty ' + m.progress.done + '/' + (m.progress.total || '…') +
            ' (odstup 3 s na stránku)';
      } else if (!m.complete.ok) txt = m.complete.error || 'Lookup zlyhal.';
      else txt = 'Hotovo — vyber, čo sa má zapísať.';
      status.textContent = txt;
    }
    if (m && m.warnings && m.warnings.length){
      var wbox = mddEl('div', 'mddwarn');
      wbox.textContent = m.warnings.join(' · ');
      body.appendChild(wbox);
    }
    if (v.updates.length){
      body.appendChild(mddEl('div', 'mdsec', 'Navrhované zmeny'));
      v.updates.forEach(function(u){ body.appendChild(mddUpdateRow(u)); });
    }
    if (v.clean.length){
      body.appendChild(mddEl('div', 'mdsec', 'Bez zmeny'));
      v.clean.forEach(function(c){
        var row = mddEl('div', 'mddrow');
        row.appendChild(mddEl('span', 'mddlbl', mddVariantLabel(c.p)));
        row.appendChild(mddEl('span', 'mddsame', 'kód aj cena sedia ✓'));
        body.appendChild(row);
      });
    }
    if (v.attention.length){
      body.appendChild(mddEl('div', 'mdsec', 'Nenájdené / preskočené'));
      v.attention.forEach(function(a){ body.appendChild(mddAttentionRow(a)); });
    }
    if (m && m.complete && v.accessories.length){
      body.appendChild(mddEl('div', 'mdsec', 'Súvisiaci sortiment (len informácia)'));
      v.accessories.slice(0, 12).forEach(function(a){
        body.appendChild(mddEl('div', 'mddacc',
          (a.name || a.code) + ' · kód ' + a.code + (a.price_vat != null ? ' · ' + mddFmtPrice(a.price_vat) : '')));
      });
    }
    var apply = mddId('mddApplyBtn');
    if (apply) apply.disabled = !(m && m.complete && m.complete.ok && v.updates.length && !MD_RO);
  }

  function mddOpen(){
    var modal = mddId('demosModal');
    if (modal) modal.style.display = '';
  }

  function mddClose(){
    var modal = mddId('demosModal');
    if (modal) modal.style.display = 'none';
  }

  // Vstupny bod z detailu dekoru.
  function mddLookup(groupKey){
    if (MD_RO) return;
    MDD_STATE = null;
    mddOpen();
    mddRender();
    var status = mddId('mddStatus');
    if (status) status.textContent = 'Hľadám produkty skupiny…';
    if (window.sketchup && sketchup.demos_lookup)
      sketchup.demos_lookup(JSON.stringify({ group_key: groupKey, catalog_schema: MD_CLIENT_SCHEMA }));
  }

  function mddCancel(){
    if (window.sketchup && sketchup.demos_cancel) sketchup.demos_cancel('');
    mddClose();
  }

  function mddApply(){
    var v = mddBuildView(MDD_STATE);
    var checks = [];
    document.querySelectorAll('#mddBody .mddrow').forEach(function(row){
      var key = row.getAttribute('data-mdd-key');
      if (!key) return;
      var c = { key: key, code: false, price: false };
      row.querySelectorAll('input[data-mdd-check]').forEach(function(cb){
        if (cb.checked) c[cb.getAttribute('data-mdd-check')] = true;
      });
      checks.push(c);
    });
    var accepts = mddAccepts(v, checks, MD_CATALOG);
    if (!accepts.length) return;
    var btn = mddId('mddApplyBtn');
    if (btn) btn.disabled = true; // pocas zapisu; vysledok pride cez done/fail
    if (window.sketchup && sketchup.demos_apply)
      sketchup.demos_apply(JSON.stringify({ accepts: accepts, catalog_rev: MD_REV,
                                            catalog_schema: MD_CLIENT_SCHEMA }));
  }

  function mddManualSend(key){
    var inp = document.querySelector('#mddBody input[data-mdd-url="' + key.replace(/"/g, '\\"') + '"]');
    var url = inp ? inp.value.trim() : '';
    if (!url) return;
    var sep = key.indexOf('|');
    if (window.sketchup && sketchup.demos_manual_url)
      sketchup.demos_manual_url(JSON.stringify({ kind: key.slice(0, sep), record_id: key.slice(sep + 1),
                                                 url: url, catalog_schema: MD_CLIENT_SCHEMA }));
  }

  // FIX 14: konflikt NEZATVARA modal — vinny riadok sa oznaci a dovod sa
  // ukaze V modale (GH #98 P2: #status stranky je pod scrimom). Server pri
  // konflikte zneplatnil navrhy (baseline z casu lookupu) — dalsi zapis
  // vyzaduje novy lookup, hlaska to hovori.
  function mddFail(r){
    var apply = mddId('mddApplyBtn');
    if (apply) apply.disabled = false;
    var status = mddId('mddStatus');
    if (status && r && r.msg) status.textContent = r.msg;
    if (r && r.id){
      document.querySelectorAll('#mddBody .mddrow').forEach(function(row){
        var key = row.getAttribute('data-mdd-key') || '';
        row.classList.toggle('mdderr', key.slice(key.indexOf('|') + 1) === r.id);
      });
    }
  }

  var MDD = {
    event: function(e){ MDD_STATE = mddApplyEvent(MDD_STATE, e); mddRender(); },
    done: function(_r){ mddClose(); },
    fail: function(r){ mddFail(r); }
  };

  // Delegovane ovladanie modalu — ziadne inline handlery s datami (BLOCKER 6).
  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('click', function(ev){
      var t = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
      if (!t) return;
      var action = t.getAttribute('data-action');
      if (action === 'mdd-apply') mddApply();
      else if (action === 'mdd-cancel') mddCancel();
      else if (action === 'manual') mddManualSend(t.getAttribute('data-mdd-key') || '');
    });
  }

  // Node testy (tests/js/test_demos_diff.js) — len CISTE funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { mddNewModel: mddNewModel, mddApplyEvent: mddApplyEvent,
      mddOffers: mddOffers, mddBuildView: mddBuildView, mddRowRevOf: mddRowRevOf,
      mddAccepts: mddAccepts, mddStatusLabel: mddStatusLabel, mddFmtPrice: mddFmtPrice,
      mddAttentionText: mddAttentionText };
  }
