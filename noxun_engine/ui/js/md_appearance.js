// MR2B: spoločný vzhľad povrchu. Katalóg dáva kotvu, server vlastní zdroj aj zápis.
(function(root){
  'use strict';
  var current = null, generation = 0, sequence = 0;
  var ids = { pick: 'mdaPick', edit: 'mdaEdit', save: 'mdaSave', reset: 'mdaReset', apply: 'mdaApply' };
  function el(id){ return document.getElementById(id); }
  function icon(name){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + name + '"/></svg>'; }
  function context(s){ return root.mdAppearanceContext(s.groupKey, s.surfaceKey, s.envelope); }
  function transport(action, payload){
    if (!root.sketchup || typeof root.sketchup[action] !== 'function') return false;
    root.sketchup[action](JSON.stringify(payload));
    return true;
  }
  function envelope(s, action){
    return Object.assign({}, s.envelope, { session_token: s.session, action_token: action });
  }
  function nextToken(prefix){ return prefix + '-' + (++sequence); }
  function matches(s, reply){
    if (!s || !reply || s.generation !== generation) return false;
    var c = context(s);
    return !!c && c.model_guid === s.envelope.model_guid && c.section === 'mat' &&
      ['request_token', 'model_guid', 'section', 'kind', 'anchor_id'].every(function(k){
        return reply[k] === s.envelope[k];
      });
  }
  function trigger(s){
    var nodes = document.querySelectorAll('[data-mda-group][data-mda-surface]');
    for (var i = 0; i < nodes.length; i++){
      if (nodes[i].getAttribute('data-mda-group') === s.groupKey &&
          nodes[i].getAttribute('data-mda-surface') === s.surfaceKey) return nodes[i];
    }
    return null;
  }
  function hex(rgb){
    if (!Array.isArray(rgb) || rgb.length !== 3 || !rgb.every(function(v){ return Number.isInteger(v) && v >= 0 && v <= 255; })) return null;
    return '#' + rgb.map(function(v){ return ('0' + v.toString(16)).slice(-2); }).join('');
  }
  function preview(url){
    return typeof url === 'string' && /^data:image\/png;base64,[A-Za-z0-9+/]+={0,2}$/.test(url) ? url : null;
  }
  function position(){
    if (!current) return;
    var t = trigger(current), card = el('mdaCard');
    if (!t || !card) return;
    var r = t.getBoundingClientRect(), width = card.offsetWidth || 384, height = card.offsetHeight || 430;
    card.style.left = Math.max(12, Math.min(r.left, root.innerWidth - width - 12)) + 'px';
    card.style.top = Math.max(12, Math.min(r.bottom + 7, root.innerHeight - height - 12)) + 'px';
  }
  function markup(){
    return '<section class="mda-card" id="mdaCard" role="dialog" aria-modal="true" aria-labelledby="mdaTitle" aria-describedby="mdaScope">' +
      '<div class="mda-head"><div><h3 id="mdaTitle">Vzhľad</h3><p id="mdaScope"></p></div>' +
      '<button type="button" class="ghostbtn mda-close" id="mdaClose" aria-label="Zavrieť Vzhľad">' + icon('x') + '</button></div>' +
      '<div class="mda-body"><div class="mda-preview-row"><div class="mda-preview" id="mdaPreview" role="img" aria-label="Ukážka vzhľadu"></div>' +
      '<div class="mda-meta"><b id="mdaLabel"></b><p id="mdaDescription"></p><span class="mda-tag" id="mdaTag"></span></div></div>' +
      '<div class="mda-color-line"><label for="mdaColor">Farba dekoru</label><input type="color" id="mdaColor" aria-describedby="mdaColorHint"><span id="mdaColorHint">Spoločná pre dosky aj ABS</span></div>' +
      '<p class="mda-help">Textúra je voliteľná. Vzhľad platí pre tento povrch vo všetkých hrúbkach, vrátane ABS.</p>' +
      '<div class="mda-actions"><button type="button" class="ghostbtn" id="mdaPick">' + icon('plus') + '<span id="mdaPickLabel">Priradiť textúru…</span></button>' +
      '<button type="button" class="ghostbtn" id="mdaEdit">' + icon('external-link') + '<span>Upraviť v SketchUpe</span></button>' +
      '<button type="button" class="primary" id="mdaSave">' + icon('check') + '<span>Uložiť vzhľad do knižnice</span></button>' +
      '<button type="button" class="ghostbtn" id="mdaReset">' + icon('rotate-ccw') + '<span>Použiť katalógovú farbu</span></button>' +
      '<button type="button" class="ghostbtn" id="mdaApply" style="display:none">' + icon('refresh-cw') + '<span>Znova použiť vzhľad</span></button></div>' +
      '<div class="mda-notice" id="mdaNotice" role="status" aria-live="polite"></div></div></section>';
  }
  function blocked(s, c){
    if (s.pending) return 'Načítavam vzhľad…';
    if (s.action) return 'Prebieha zmena vzhľadu…';
    if (c.read_only) return c.reason || 'Katalóg je len na čítanie.';
    if (!s.session) return s.message || 'Vzhľad sa nepodarilo načítať.';
    return '';
  }
  function render(){
    var s = current;
    if (!s) return;
    var c = context(s);
    if (!c || c.model_guid !== s.envelope.model_guid || c.section !== 'mat'){ invalidate(); return; }
    var state = s.state || {}, mode = state.mode, lock = blocked(s, c), color = hex(state.color) || hex(c.color), url = preview(state.preview_url);
    el('mdaTitle').textContent = 'Vzhľad · ' + c.title;
    el('mdaScope').textContent = c.scope_label;
    el('mdaLabel').textContent = s.pending ? 'Načítavam vzhľad…' : ({ color: 'Katalógová farba', native: 'Uložený vzhľad', working: 'Pracovný vzhľad', missing: 'Vzhľad nie je dostupný', conflict: 'Rozdielne vzhľady' }[mode] || 'Vzhľad nie je dostupný');
    el('mdaDescription').textContent = state.message || s.message || '';
    el('mdaTag').textContent = mode === 'color' ? 'Bez textúry' : (url ? 'Ukážka zo SketchUpu' : 'Bez ukážky');
    // Katalógová fotografia nie je textúra. Pri chýbajúcej ukážke ostáva neutrálne pole.
    el('mdaPreview').style.backgroundColor = mode === 'color' && color ? color : 'var(--nx-surface-sunken)';
    el('mdaPreview').style.backgroundImage = url ? 'url("' + url + '")' : 'none';
    el('mdaPreview').setAttribute('aria-label', url ? 'Ukážka vzhľadu zo SketchUpu' : (mode === 'color' ? 'Katalógová farba' : 'Ukážka vzhľadu nie je dostupná'));
    if (color) el('mdaColor').value = color;
    el('mdaColor').setAttribute('aria-disabled', lock || !color ? 'true' : 'false');
    el('mdaColor').title = lock || 'Farba dekoru — spoločná pre dosky aj ABS';
    el('mdaClose').setAttribute('aria-disabled', s.action ? 'true' : 'false');
    el('mdaClose').title = s.action ? 'Počkaj na dokončenie zmeny.' : 'Zavrieť';
    el('mdaCard').setAttribute('aria-busy', s.pending || s.action ? 'true' : 'false');
    Object.keys(ids).forEach(function(action){
      var node = el(ids[action]), reason = lock;
      if (!reason && state['can_' + action] !== true){
        reason = action === 'save' && mode === 'color' ? 'Samotná katalógová farba sa ukladá hneď. Najprv priraď alebo uprav vzhľad.' : (state.message || 'Táto akcia teraz nie je dostupná.');
      }
      node.setAttribute('aria-disabled', reason ? 'true' : 'false');
      node.title = reason || '';
    });
    el('mdaPickLabel').textContent = mode === 'native' || mode === 'working' ? 'Zmeniť textúru…' : 'Priradiť textúru…';
    var retryFocused = document.activeElement === el('mdaApply');
    el('mdaApply').style.display = state.can_apply === true ? '' : 'none';
    if (retryFocused && state.can_apply !== true) el('mdaPick').focus();
    el('mdaNotice').textContent = s.action ? 'Prebieha zmena vzhľadu…' : (c.read_only ? lock : s.message || '');
    el('mdaNotice').classList.toggle('mda-error', !!s.error && !s.action);
    el('mdaNotice').style.display = el('mdaNotice').textContent ? '' : 'none';
    var t = trigger(s);
    if (t) t.setAttribute('aria-expanded', 'true');
    position();
  }
  function dispose(restoreFocus){
    var s = current;
    if (!s) return true;
    var t = trigger(s);
    current = null;
    generation++;
    var host = el('mdAppearanceRoot');
    if (host){ host.style.display = 'none'; host.innerHTML = ''; }
    if (t){
      t.setAttribute('aria-expanded', 'false');
      if (restoreFocus && t.getAttribute('aria-disabled') !== 'true') t.focus();
    }
    if (s.session){
      try { transport('appearance_close', envelope(s, nextToken('close'))); } catch (_err) { /* Lokálny kontext už zanikol. */ }
    }
    return true;
  }
  function close(){ return current && current.action ? false : dispose(true); }
  function invalidate(){ return dispose(false); }
  function open(groupKey, surfaceKey, origin){
    if (current && current.action) return false;
    if (root.NXModal && root.NXModal.isOpen()) return false;
    var c = root.mdAppearanceContext(groupKey, surfaceKey), host = el('mdAppearanceRoot');
    if (!host || !c || c.read_only || c.section !== 'mat' || !c.model_guid) return false;
    invalidate();
    var s = current = { groupKey: groupKey, surfaceKey: surfaceKey, generation: ++generation, session: null,
      pending: true, action: null, state: null, message: '', error: false,
      envelope: { request_token: nextToken('appearance'), model_guid: c.model_guid, section: 'mat', kind: c.kind,
        anchor_id: c.anchor_id, catalog_schema: c.catalog_schema } };
    host.innerHTML = markup(); host.style.display = 'block';
    render();
    el('mdaClose').focus();
    try {
      if (!transport('appearance_prepare', s.envelope)) throw new Error('Spojenie so SketchUpom nie je dostupné.');
    } catch (_err){
      if (current === s){ s.pending = false; s.error = true; s.message = 'Vzhľad sa nepodarilo načítať. Zavri okno a skús znova.'; render(); }
    }
    return true;
  }
  function ready(reply){
    var s = current;
    if (!matches(s, reply) || !s.pending) return;
    s.pending = false;
    s.session = reply.ok === true && typeof reply.session_token === 'string' && reply.session_token ? reply.session_token : null;
    s.state = s.session ? Object.assign({}, reply.state) : null;
    s.message = reply.message || (s.session ? '' : 'Vzhľad sa nepodarilo načítať.');
    s.error = !s.session;
    render();
  }
  function begin(action){
    var s = current, c = s && context(s);
    if (!s || !c || c.section !== 'mat' || c.model_guid !== s.envelope.model_guid || blocked(s, c)) return null;
    if (action !== 'color' && (!s.state || s.state['can_' + action] !== true)) return null;
    s.action = { name: action, token: nextToken(action) }; s.error = false; s.message = '';
    render();
    return { session: s, payload: envelope(s, s.action.token) };
  }
  function dispatchFailed(s){
    if (current !== s) return;
    s.action = null; s.error = true; s.message = 'Akciu sa nepodarilo odoslať. Skús znova.'; render();
  }
  function act(action){
    if (!Object.prototype.hasOwnProperty.call(ids, action)) return false;
    var request = begin(action);
    if (!request) return false;
    try {
      if (!transport('appearance_' + action, request.payload)) dispatchFailed(request.session);
    } catch (_err){ dispatchFailed(request.session); }
    return true;
  }
  function colorChanged(value){
    if (!/^#[0-9a-f]{6}$/i.test(value)) return false;
    var request = begin('color');
    if (!request){ render(); return false; }
    try {
      if (!root.mdColorSave(request.session.groupKey, value, request.payload)) dispatchFailed(request.session);
    } catch (_err){ dispatchFailed(request.session); }
    return true;
  }
  function result(reply){
    var s = current;
    if (!matches(s, reply) || !s.action || reply.session_token !== s.session ||
        reply.action_token !== s.action.token || reply.action !== s.action.name) return;
    s.action = null;
    if (reply.state) s.state = Object.assign({}, reply.state);
    s.message = reply.message || '';
    s.error = reply.ok !== true;
    render();
  }
  function keydown(e){
    if (!current) return;
    if (e.key === 'Escape'){
      e.preventDefault(); e.stopImmediatePropagation(); close(); return;
    }
    if (e.target === el('mdaColor') && el('mdaColor').getAttribute('aria-disabled') === 'true' && e.key !== 'Tab'){
      e.preventDefault(); return;
    }
    if (e.key !== 'Tab') return;
    var nodes = Array.prototype.slice.call(el('mdaCard').querySelectorAll('button, input')).filter(function(n){
      return !n.disabled && n.style.display !== 'none';
    });
    var index = nodes.indexOf(document.activeElement);
    if (e.shiftKey && index <= 0){ e.preventDefault(); nodes[nodes.length - 1].focus(); }
    else if (!e.shiftKey && (index < 0 || index === nodes.length - 1)){ e.preventDefault(); nodes[0].focus(); }
    e.stopImmediatePropagation();
  }
  function catalogChanged(){
    var c = current && context(current);
    if (current && current.state && c) current.state.color = c.color;
    render();
  }
  root.MDAppearance = { open: open, close: close, invalidate: invalidate, ready: ready, result: result,
    catalogChanged: catalogChanged, isOpen: function(){ return !!current; }, isBusy: function(){ return !!(current && current.action); } };
  if (root.NXEsc && root.NXEsc.FOREIGN_MODAL_IDS.indexOf('mdAppearanceRoot') < 0) root.NXEsc.FOREIGN_MODAL_IDS.push('mdAppearanceRoot');
  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(e){
      var inside = e.target.closest && e.target.closest('#mdAppearanceRoot');
      if (inside){
        if (e.target === inside){ close(); return; }
        var button = e.target.closest('button');
        if (button && button.id === 'mdaClose') close();
        else if (button) Object.keys(ids).some(function(action){ if (button.id !== ids[action]) return false; act(action); return true; });
        if (e.target.id === 'mdaColor' && e.target.getAttribute('aria-disabled') === 'true') e.preventDefault();
        return;
      }
      var t = e.target.closest && e.target.closest('[data-mda-group][data-mda-surface]');
      if (!t || t.getAttribute('aria-disabled') === 'true') return;
      open(t.getAttribute('data-mda-group'), t.getAttribute('data-mda-surface'), t);
    });
    document.addEventListener('change', function(e){ if (current && e.target === el('mdaColor')) colorChanged(e.target.value); });
    document.addEventListener('keydown', keydown);
    root.addEventListener('resize', position);
    root.addEventListener('scroll', position, true);
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = root.MDAppearance;
})(typeof window !== 'undefined' ? window : globalThis);
