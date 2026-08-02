  // ================= Sety kovania + predvolby projektu (V0.6 D1b) =================
  // Set = mapovacie pravidlo genericky typ -> zoznam Demos kodov s pomermi
  // (NIE polozka katalogu). Server (HardwareSets) je autorita: normalizacia,
  // validacia, revision guard kniznice, snapshot projektu (mapping + kopie
  // definicii — audit B2). JS len renderuje a posiela payloady.
  // XSS kontrakt ako hw_catalog.js: createElement + textContent, data-action
  // delegacia; ziadne innerHTML s datami.

  var HWS_DATA = null;   // posledny HWSETS.init payload
  var HWS_TAB = 'items'; // items | sets | proj
  var HWS_EDIT = null;   // rozpracovany editor setu (null = zavrety)
  var HWS_DEL_ARM = '';  // set_id cakajuci na druhy klik "Naozaj zmazat?"

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
  // Citatelny suhrn clena: "104717 ×1", "TipOn ×1 na dvierka", "rad NL: 420→357695, 470→357696".
  function hwsMemberSummary(m){
    if (!m) return '';
    if (m.code_by_nl){
      var pairs = Object.keys(m.code_by_nl).sort(function(a, b){ return Number(a) - Number(b); })
        .map(function(nl){ return nl + '→' + m.code_by_nl[nl]; });
      return 'rad NL: ' + (pairs.join(', ') || '—');
    }
    var label = m.label ? m.label + ' ' : '';
    return label + m.code + ' ×' + (m.qty || 1) + (m.per === 'owner' ? ' na vlastníka (dvierka)' : '');
  }
  // Editor stav -> set payload pre server (rad: riadky {nl, code} -> mapa).
  function hwsBuildSetPayload(edit){
    var members = (edit.members || []).map(function(m){
      var out = { per: m.per === 'owner' ? 'owner' : 'unit', qty: parseInt(m.qty, 10) || 1 };
      if (m.label) out.label = m.label;
      if (m.is_series){
        var map = {};
        (m.series || []).forEach(function(row){
          var nl = String(row.nl == null ? '' : row.nl).trim();
          var code = String(row.code == null ? '' : row.code).trim();
          if (nl && code) map[nl] = code;
        });
        out.code_by_nl = map;
      } else {
        out.code = String(m.code == null ? '' : m.code).trim();
      }
      return out;
    });
    return { set_id: edit.set_id, name: String(edit.name == null ? '' : edit.name).trim(),
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
        return { is_series: false, per: m.per || 'unit', qty: m.qty || 1,
                 label: m.label || '', code: m.code || '' };
      })
    };
  }

  // --- vstup zo servera ------------------------------------------------------

  // Top-level var = global v CEF (vzor MDH); ziadne window.* na module scope
  // (Node testy subor require-uju bez DOM).
  var HWSETS = {
    init: function(data){
      HWS_DATA = data || null;
      // Rozpracovany editor NEZAHADZUJEME pri echu (vzor dirty buniek okna
      // Materialy) — render ho necha tak; zoznam a predvolby sa obnovia.
      hwsRenderAll();
    }
  };

  function hwsSetTab(t){
    HWS_TAB = t;
    ['items', 'sets', 'proj'].forEach(function(k){
      var btn = hwsEl('hwt_' + k);
      if (btn) btn.classList.toggle('on', k === t);
      var box = hwsEl(k === 'items' ? 'hwTabItems' : (k === 'sets' ? 'hwTabSets' : 'hwTabProj'));
      if (box) box.style.display = (k === t) ? '' : 'none';
    });
    hwsRenderAll();
  }

  function hwsRenderAll(){
    hwsRenderSets();
    hwsRenderProj();
  }

  // --- tab SETY ---------------------------------------------------------------

  function hwsTypeLabel(gt){
    var list = (HWS_DATA && HWS_DATA.generic_types) || [];
    for (var i = 0; i < list.length; i++){ if (list[i].key === gt) return list[i].label; }
    return gt;
  }

  function hwsRenderSets(){
    var box = hwsEl('hwTabSets');
    if (!box || !HWS_DATA) return;
    box.textContent = '';
    var bar = hwsMk('div', 'mdbar');
    var nb = hwsMk('button', 'ghostbtn', '+ Nový set');
    nb.setAttribute('data-action', 'hws-new');
    bar.appendChild(nb);
    var hint = hwsMk('span', 'hint', 'Set = kódy, ktoré sa objednajú za 1 kus kovania. Zmena knižnice nemení staré zákazky (projekt drží kópiu).');
    bar.appendChild(hint);
    box.appendChild(bar);
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
        ul.appendChild(hwsMk('div', 'hwsset-m', hwsMemberSummary(m)));
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

  // --- tab PREDVOLBY PROJEKTU ---------------------------------------------------

  function hwsRenderProj(){
    var box = hwsEl('hwTabProj');
    if (!box || !HWS_DATA) return;
    box.textContent = '';
    var proj = HWS_DATA.project || {};
    box.appendChild(hwsMk('div', 'hwsproj-title', 'Model: ' + (HWS_DATA.model_title || '—')));
    if (proj.status === 'invalid'){
      var ban = hwsMk('div', 'hwbanner',
        'Predvoľby setov v tomto projekte sú poškodené — súpis kovania sa nemapuje. ');
      var rb = hwsMk('button', 'ghostbtn', 'Obnoviť z globálnych predvolieb');
      rb.setAttribute('data-action', 'hws-reset-proj');
      ban.appendChild(rb);
      box.appendChild(ban);
      return;
    }
    if (proj.status === 'missing'){
      box.appendChild(hwsMk('div', 'hint',
        'Projekt zatiaľ preberá globálne predvoľby — zmrazia sa doň pri prvej stavbe skrinky alebo prvej zmene tu.'));
    }
    var mapping = proj.status === 'ok' ? (proj.mapping || {}) : (HWS_DATA.global_mapping || {});
    box.appendChild(hwsMappingTable(mapping, 'hws-map-proj'));

    // Globalne defaulty novych projektov — zbalene (vertikalny priestor).
    var det = document.createElement('details');
    det.appendChild(hwsMk('summary', null, 'Predvoľby nových projektov (globálne)'));
    det.appendChild(hwsMappingTable(HWS_DATA.global_mapping || {}, 'hws-map-global'));
    box.appendChild(det);
  }

  function hwsMappingTable(mapping, action){
    var t = hwsMk('div', 'hwsmap');
    ((HWS_DATA && HWS_DATA.generic_types) || []).forEach(function(gt){
      var opts = hwsSetsForType(HWS_DATA.sets, gt.key);
      if (!opts.length && !mapping[gt.key]) return; // typ bez setov nezobrazuj
      var row = hwsMk('div', 'hwsmap-row');
      row.appendChild(hwsMk('label', null, gt.label));
      var sel = hwsMk('select');
      sel.setAttribute('data-action-change', action);
      sel.setAttribute('data-hws-gt', gt.key);
      var none = hwsMk('option', null, '— bez setu (ORANGE)');
      none.value = '';
      sel.appendChild(none);
      opts.forEach(function(s){
        var o = hwsMk('option', null, s.name);
        o.value = s.set_id;
        if (mapping[gt.key] === s.set_id) o.selected = true;
        sel.appendChild(o);
      });
      row.appendChild(sel);
      t.appendChild(row);
    });
    return t;
  }

  // --- delegacia ------------------------------------------------------------------

  function hwsMember(i){ return (HWS_EDIT && HWS_EDIT.members && HWS_EDIT.members[i]) || null; }

  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('click', function(ev){
      var t = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
      if (t){
        var a = t.getAttribute('data-action');
        if (a === 'hws-tab'){ hwsSetTab(t.getAttribute('data-tab')); return; }
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
            hwsSend('hws_save_set', { set: hwsBuildSetPayload(HWS_EDIT),
                                      revision: HWS_DATA.revision || '' });
            HWS_EDIT = null;
          }
          return;
        }
        if (a === 'hws-m-add' || a === 'hws-m-add-series'){
          if (HWS_EDIT){
            HWS_EDIT.members.push(a === 'hws-m-add'
              ? { is_series: false, per: 'unit', qty: 1, code: '', label: '' }
              : { is_series: true, per: 'unit', qty: 1, label: '', series: [{ nl: '', code: '' }] });
            hwsRenderSets();
          }
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
      }
      // klik mimo "Naozaj zmazat?" odzbroji potvrdenie
      if (HWS_DEL_ARM && !(t && t.getAttribute('data-action') === 'hws-del')){
        HWS_DEL_ARM = '';
        if (HWS_TAB === 'sets') hwsRenderSets();
      }
    });
    // Editor setu: inputs pisu do HWS_EDIT (input event — bez prerenderu);
    // selecty mapovania posielaju zmenu hned (change).
    document.addEventListener('input', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute || !HWS_EDIT) return;
      var field = t.getAttribute('data-hws-field');
      if (!field) return;
      var mi = t.getAttribute('data-hws-m');
      if (mi == null){
        if (field === 'name') HWS_EDIT.name = t.value;
        if (field === 'generic_type') HWS_EDIT.generic_type = t.value;
        return;
      }
      var m = hwsMember(parseInt(mi, 10));
      if (!m) return;
      var si = t.getAttribute('data-hws-s');
      if (si != null && m.series){
        var srow = m.series[parseInt(si, 10)];
        if (srow) srow[field] = t.value;
        return;
      }
      m[field] = (field === 'qty') ? t.value : t.value;
    });
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      var act = t.getAttribute('data-action-change');
      if (act === 'hws-map-proj'){
        hwsSend('hws_map_project', { generic_type: t.getAttribute('data-hws-gt'),
                                     set_id: t.value,
                                     model_guid: (HWS_DATA && HWS_DATA.model_guid) || '' });
      } else if (act === 'hws-map-global'){
        hwsSend('hws_map_global', { generic_type: t.getAttribute('data-hws-gt'),
                                    set_id: t.value });
      } else if (HWS_EDIT && t.getAttribute('data-hws-field') === 'generic_type' && t.tagName === 'SELECT'){
        HWS_EDIT.generic_type = t.value;
      }
    });
  }

  // Node testy — len ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { hwsSlug: hwsSlug, hwsSetsForType: hwsSetsForType,
      hwsMemberSummary: hwsMemberSummary, hwsBuildSetPayload: hwsBuildSetPayload,
      hwsEditStateFrom: hwsEditStateFrom };
  }
