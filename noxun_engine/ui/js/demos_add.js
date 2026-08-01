/*!
 * Noxun Engine — demos_add.js — V0.6 M-A2: modal "Pridať z Demosu".
 *
 * Flow (mockup s1-s4): jedno pole (URL alebo názov 3+ znaky) -> živé návrhy
 * zo servera (demos_name_search, offline sitemap cache) -> rodina dekoru
 * (demos_family: hlavička + Dosky / ABS / Mimo systému) -> čistý výber
 * s auto-návrhom 1 mm pásky -> demos_family_create (progres, Zrušiť) ->
 * po založení skok na detail skupiny.
 *
 * Kontrakty (audit M-A + vzory MDD):
 *  - server drží family store; JS posiela LEN iid vybraných položiek
 *    (BLOCKER 2 — žiadne URL/hodnoty z klienta),
 *  - render VÝHRADNE createElement + textContent (XSS kontrakt),
 *  - session echo v eventoch (ABA guard ako MDD), gen echo pri návrhoch
 *    (F10 — starý výsledok neprepíše novší dotaz),
 *  - HTML disabled je len UX — autorita každého guardu je server.
 * Čisté funkcie sú bez DOM (Node testy tests/js/test_demos_add.js).
 */

// --- čisté funkcie -----------------------------------------------------------

// Položky rodiny -> sekcie v poradí mockupu.
function nxdaSections(items){
  var out = { sheets: [], edges: [], others: [] };
  (items || []).forEach(function(it){
    if (!it) return;
    if (it.kind === 'sheet') out.sheets.push(it);
    else if (it.kind === 'edge') out.edges.push(it);
    else out.others.push(it);
  });
  return out;
}

// Auto-návrh pásky po zaškrtnutí dosky (mockup s2): najmenšia 1,0 mm páska
// so šírkou >= hrúbka dosky + 2 (slug hinty — len UX, server pri create
// všetko overuje). Vracia iid pásky alebo null. Návrh sa dáva IBA páske,
// ktorej checkbox je nedotknutý (checks[iid] === undefined) — vedomé
// odškrtnutie sa nikdy neprebíja.
function nxdaAutoEdgeSuggest(items, checks, sheetIid){
  var sheet = null;
  (items || []).forEach(function(it){ if (it && it.iid === sheetIid) sheet = it; });
  if (!sheet || sheet.kind !== 'sheet') return null;
  var th = parseFloat(sheet.thickness_hint);
  if (isNaN(th) || th <= 0) return null;
  function fits(it){
    var et = parseFloat(it.thickness_hint);
    var ew = parseFloat(it.width_hint);
    return !isNaN(et) && Math.abs(et - 1.0) <= 0.01 && !isNaN(ew) && ew >= th + 2;
  }
  var covered = false;
  var best = null;
  (items || []).forEach(function(it){
    if (!it || it.kind !== 'edge' || !fits(it)) return;
    // Vyhovujuca paska UZ zaskrtnuta (napr. navrh k predoslej doske) —
    // dalsia sirsia sa nepridava, jedna 1 mm paska na dekor staci.
    if (checks && checks[it.iid] === true){ covered = true; return; }
    if (checks && Object.prototype.hasOwnProperty.call(checks, it.iid)) return;
    if (!best || parseFloat(it.width_hint) < parseFloat(best.width_hint) ||
        (parseFloat(it.width_hint) === parseFloat(best.width_hint) && String(it.iid) < String(best.iid))) best = it;
  });
  if (covered) return null;
  return best ? best.iid : null;
}

function nxdaSelectedIids(checks){
  var out = [];
  Object.keys(checks || {}).forEach(function(k){ if (checks[k] === true) out.push(k); });
  out.sort();
  return out;
}

// Výber obsahuje LEN pásky (hint pri zakladaní novej skupiny — server guard
// "výrobcu nesie doska" by create odmietol, UX to povie vopred).
function nxdaEdgeOnly(items, checks){
  var iids = nxdaSelectedIids(checks);
  if (!iids.length) return false;
  var byIid = {};
  (items || []).forEach(function(it){ if (it) byIid[it.iid] = it; });
  return iids.every(function(id){ return byIid[id] && byIid[id].kind === 'edge'; });
}

// Cena položky rodiny do riadku ("118,42 € / ks" | "—").
function nxdaPriceLabel(priceVat, unit){
  var v = parseFloat(priceVat);
  if (isNaN(v)) return '—';
  var txt = (Math.round(v * 100) / 100).toFixed(2).replace('.', ',') + ' €';
  return unit ? txt + ' / ' + unit : txt;
}

// Session poradie eventov (ABA vzor MDD): novšia session preberá, staršia sa
// zahadzuje. Vracia 'new' | 'ok' | 'stale'.
function nxdaSessionCheck(current, incoming){
  var c = parseInt(current, 10) || 0;
  var s = parseInt(incoming, 10) || 0;
  if (s > c) return 'new';
  if (s < c) return 'stale';
  return 'ok';
}

// --- stav modalu ---------------------------------------------------------------

var NXDA_STATE = {
  open: false, mode: 'search',   // search | family | progress
  gen: 0,                        // gen echo návrhov (F10)
  session: 0,                    // session echo eventov (ABA)
  header: null, items: [], existing: null,
  checks: {}, autoIid: null,     // posledná auto-navrhnutá páska (badge)
  failed: {},                    // iid -> dôvod (all-or-nothing návrat)
  log: []                        // progres riadky
};
var nxdaDebounce = null;

function nxdaEl(tag, cls, text){
  var e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}
function nxdaIcon(name){
  var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  s.setAttribute('class', 'ic');
  s.setAttribute('aria-hidden', 'true');
  var u = document.createElementNS('http://www.w3.org/2000/svg', 'use');
  u.setAttribute('href', '#i-' + name);
  s.appendChild(u);
  return s;
}

function nxdaOpen(){
  NXDA_STATE = { open: true, mode: 'search', gen: NXDA_STATE.gen + 1, session: 0,
                 header: null, items: [], existing: null, checks: {}, autoIid: null,
                 failed: {}, log: [] };
  var m = document.getElementById('nxdaModal');
  if (m) m.style.display = '';
  nxdaRender();
  var inp = document.getElementById('nxdaInput');
  if (inp){ inp.value = ''; setTimeout(function(){ inp.focus(); }, 30); }
}

function nxdaClose(){
  NXDA_STATE.open = false;
  var m = document.getElementById('nxdaModal');
  if (m) m.style.display = 'none';
  // Server session bump — bežiaci lookup/create stratí alive (žiadny zápis).
  if (window.sketchup && sketchup.demos_family_cancel) sketchup.demos_family_cancel('');
}

// --- search krok ---------------------------------------------------------------

function nxdaInputChanged(){
  var inp = document.getElementById('nxdaInput');
  if (!inp) return;
  var v = inp.value.trim();
  // GH #102 P2: URL sa NEnačítava na každý úder klávesu (postupné písanie
  // https://… by strieľalo request za requestom do throttle radu) — URL
  // potvrdzuje Enter alebo paste (nxdaMaybeUrl), tu sa len utíši našepkávač.
  if (/^https?:\/\//i.test(v)){
    if (nxdaDebounce) clearTimeout(nxdaDebounce);
    nxdaSuggestRender([], 'Adresa produktu — potvrď klávesom Enter.');
    return;
  }
  if (nxdaDebounce) clearTimeout(nxdaDebounce);
  if (v.length < 3){ nxdaSuggestRender([], ''); return; }
  nxdaDebounce = setTimeout(function(){
    NXDA_STATE.gen += 1;
    if (window.sketchup && sketchup.demos_name_search)
      sketchup.demos_name_search(JSON.stringify({ query: v, gen: NXDA_STATE.gen }));
  }, 150);
}

// Vložená URL (paste) sa načíta hneď — písaná až Enterom.
function nxdaMaybeUrl(value){
  var v = String(value == null ? '' : value).trim();
  if (/^https?:\/\//i.test(v)){ nxdaLoadFamily(v); return true; }
  return false;
}

function nxdaSuggestRender(hits, note){
  var box = document.getElementById('nxdaSugg');
  if (!box) return;
  box.textContent = '';
  if (note){
    box.appendChild(nxdaEl('div', 'nxda-note', note));
    box.style.display = '';
    return;
  }
  if (!hits || !hits.length){ box.style.display = 'none'; return; }
  hits.forEach(function(h){
    var row = nxdaEl('div', 'nxda-sugg-row');
    row.setAttribute('data-url', h.url || '');
    row.appendChild(nxdaEl('span', 'nxda-tag', h.type || ''));
    row.appendChild(nxdaEl('span', 'nxda-sugg-label', h.label || h.slug || ''));
    box.appendChild(row);
  });
  box.style.display = '';
}

function nxdaLoadFamily(url){
  NXDA_STATE.mode = 'search';
  nxdaSuggestRender([], 'Načítavam rodinu dekoru zo stránky…');
  if (window.sketchup && sketchup.demos_family)
    sketchup.demos_family(JSON.stringify({ url: url }));
}

// --- family krok -----------------------------------------------------------------

function nxdaToggle(iid, on){
  NXDA_STATE.checks[iid] = on;
  if (on){
    var sug = nxdaAutoEdgeSuggest(NXDA_STATE.items, NXDA_STATE.checks, iid);
    if (sug){ NXDA_STATE.checks[sug] = true; NXDA_STATE.autoIid = sug; }
  }
  nxdaRender();
}

function nxdaCreate(){
  var iids = nxdaSelectedIids(NXDA_STATE.checks);
  if (!iids.length) return;
  NXDA_STATE.mode = 'progress';
  NXDA_STATE.log = [];
  NXDA_STATE.failed = {};
  nxdaRender();
  if (window.sketchup && sketchup.demos_family_create)
    sketchup.demos_family_create(JSON.stringify({
      iids: iids, catalog_rev: MD_REV, catalog_schema: MD_CLIENT_SCHEMA }));
}

function nxdaCancelCreate(){
  // Session bump na serveri — bežiaca položka dobehne do prázdna, NIČ sa
  // nezapíše (create zapisuje až po všetkých položkách). Návrat na výber.
  if (window.sketchup && sketchup.demos_family_cancel) sketchup.demos_family_cancel('');
  NXDA_STATE.mode = 'family';
  nxdaSetStatus('Zrušené — nič sa nezaložilo.', false);
  nxdaRender();
}

// --- render ---------------------------------------------------------------------

function nxdaSetStatus(msg, err){
  var e = document.getElementById('nxdaStatus');
  if (!e) return;
  e.textContent = msg || '';
  e.className = 'hint' + (err ? ' nxda-err' : '');
}

function nxdaRender(){
  var body = document.getElementById('nxdaBody');
  if (!body) return;
  body.textContent = '';
  if (NXDA_STATE.mode === 'family') nxdaRenderFamily(body);
  else if (NXDA_STATE.mode === 'progress') nxdaRenderProgress(body);
  else nxdaRenderSearch(body);
}

function nxdaRenderSearch(body){
  var bar = nxdaEl('div', 'nxda-search');
  bar.appendChild(nxdaIcon('search'));
  var inp = document.createElement('input');
  inp.type = 'text';
  inp.id = 'nxdaInput';
  inp.placeholder = 'Vlož URL produktu alebo píš názov… (napr. dub halifax)';
  inp.autocomplete = 'off';
  inp.addEventListener('input', nxdaInputChanged);
  inp.addEventListener('paste', function(){
    setTimeout(function(){ nxdaMaybeUrl(inp.value); }, 0); // hodnota až po paste
  });
  inp.addEventListener('keydown', function(ev){
    if (ev.key === 'Enter'){
      if (nxdaMaybeUrl(inp.value)) return;
      var first = document.querySelector('#nxdaSugg .nxda-sugg-row');
      if (first) nxdaLoadFamily(first.getAttribute('data-url'));
    } else if (ev.key === 'Escape'){ nxdaClose(); }
  });
  bar.appendChild(inp);
  body.appendChild(bar);
  var sugg = nxdaEl('div', 'nxda-sugg');
  sugg.id = 'nxdaSugg';
  sugg.style.display = 'none';
  body.appendChild(sugg);
  body.appendChild(nxdaEl('div', 'nxda-note',
    'Zhody sa hľadajú okamžite v stiahnutom zozname produktov Demosu — bez čakania na web. Enter potvrdí prvú zhodu aj vpísanú URL.'));
  // GH #102 P2: viditeľná cesta von aj pre myš (Escape nie je jediná).
  var foot = nxdaEl('div', 'nxda-foot');
  var close = nxdaEl('button', 'ghostbtn', 'Zavrieť');
  close.setAttribute('data-action', 'nxda-close');
  foot.appendChild(close);
  body.appendChild(foot);
}

function nxdaFamilyRow(it){
  var row = nxdaEl('div', 'nxda-row' + (it.kind === 'other' ? ' nxda-dis' : ''));
  var cb = document.createElement('input');
  cb.type = 'checkbox';
  cb.setAttribute('data-iid', it.iid);
  if (it.kind === 'other') cb.disabled = true;
  else cb.checked = NXDA_STATE.checks[it.iid] === true;
  row.appendChild(cb);
  var nm = nxdaEl('span', 'nxda-nm', it.name || '');
  if (NXDA_STATE.failed[it.iid]){
    row.className += ' nxda-fail';
    nm.appendChild(nxdaEl('small', 'nxda-why', NXDA_STATE.failed[it.iid]));
  } else if (it.kind === 'other' && it.reason){
    nm.appendChild(nxdaEl('small', 'nxda-why', it.reason));
  } else if (it.iid === NXDA_STATE.autoIid && NXDA_STATE.checks[it.iid] === true){
    nm.appendChild(nxdaEl('small', 'nxda-auto', 'návrh k doske — dá sa odškrtnúť'));
  }
  row.appendChild(nm);
  row.appendChild(nxdaEl('span', 'nxda-cd', it.code || ''));
  row.appendChild(nxdaEl('span', 'nxda-pr', nxdaPriceLabel(it.price_vat, it.unit)));
  return row;
}

function nxdaRenderFamily(body){
  var h = NXDA_STATE.header || {};
  var crumb = nxdaEl('div', 'nxda-crumb');
  var back = nxdaEl('button', 'ghostbtn tplbtn');
  back.setAttribute('data-action', 'nxda-back');
  back.appendChild(nxdaIcon('arrow-left'));
  back.appendChild(document.createTextNode(' späť'));
  crumb.appendChild(back);
  var title = [h.manufacturer, h.decor, h.structure, h.decor_name].filter(Boolean).join(' ');
  crumb.appendChild(nxdaEl('b', null, title));
  crumb.appendChild(nxdaEl('span', 'nxda-badge',
    NXDA_STATE.existing ? 'pridávam do existujúcej skupiny' : 'identita zo stránky'));
  body.appendChild(crumb);

  var secs = nxdaSections(NXDA_STATE.items);
  function section(label, arr){
    if (!arr.length) return;
    body.appendChild(nxdaEl('div', 'mdsec', label));
    arr.forEach(function(it){ body.appendChild(nxdaFamilyRow(it)); });
  }
  section('Dosky', secs.sheets);
  section('ABS pásky', secs.edges);
  section('Mimo systému', secs.others);

  var foot = nxdaEl('div', 'nxda-foot');
  var iids = nxdaSelectedIids(NXDA_STATE.checks);
  foot.appendChild(nxdaEl('span', 'nxda-count', 'vybrané: ' + iids.length));
  if (iids.length && !NXDA_STATE.existing && nxdaEdgeOnly(NXDA_STATE.items, NXDA_STATE.checks)){
    foot.appendChild(nxdaEl('span', 'nxda-why', 'nová skupina potrebuje aj dosku (výrobcu nesie doska)'));
  }
  var cancel = nxdaEl('button', 'ghostbtn', 'Zrušiť');
  cancel.setAttribute('data-action', 'nxda-close');
  foot.appendChild(cancel);
  var add = nxdaEl('button', 'primary', 'Pridať vybrané');
  add.setAttribute('data-action', 'nxda-create');
  add.disabled = !iids.length ||
    (!NXDA_STATE.existing && nxdaEdgeOnly(NXDA_STATE.items, NXDA_STATE.checks));
  foot.appendChild(add);
  body.appendChild(foot);
}

// GH #102 P1: fáza po overení všetkých položiek = zápis + obrázok — katalóg
// môže byť už zapísaný, Zrušiť tam nemá čo robiť. Čistá funkcia (Node test).
function nxdaImagePhase(logLen, total){
  return total > 0 && logLen >= total;
}

function nxdaRenderProgress(body){
  var h = NXDA_STATE.header || {};
  body.appendChild(nxdaEl('div', 'nxda-crumb',
    'Zakladám skupinu ' + [h.manufacturer, h.decor, h.decor_name].filter(Boolean).join(' ') + '…'));
  var barBox = nxdaEl('div', 'nxda-progress');
  var bar = nxdaEl('i');
  bar.id = 'nxdaBar';
  var total = nxdaSelectedIids(NXDA_STATE.checks).length || 1;
  bar.style.width = Math.round(NXDA_STATE.log.length / total * 100) + '%';
  barBox.appendChild(bar);
  body.appendChild(barBox);
  var log = nxdaEl('div', 'nxda-log');
  NXDA_STATE.log.forEach(function(line){ log.appendChild(nxdaEl('div', null, line)); });
  body.appendChild(log);
  var foot = nxdaEl('div', 'nxda-foot');
  if (nxdaImagePhase(NXDA_STATE.log.length, total)){
    foot.appendChild(nxdaEl('span', 'nxda-count', 'Zapisujem a sťahujem obrázok dekoru…'));
  } else {
    var cancel = nxdaEl('button', 'ghostbtn', 'Zrušiť (nič sa nezapíše)');
    cancel.setAttribute('data-action', 'nxda-cancel-create');
    foot.appendChild(cancel);
  }
  body.appendChild(foot);
}

// --- Ruby -> JS API ---------------------------------------------------------------

var NXDA = {
  // Návrhy hľadania: gen echo — starší výsledok sa zahodí (F10).
  suggest: function(p){
    if (!NXDA_STATE.open || NXDA_STATE.mode !== 'search') return;
    if ((parseInt(p.gen, 10) || 0) !== NXDA_STATE.gen && !p.refreshing && !p.refresh_done) return;
    if (p.refreshing){
      nxdaSuggestRender([], 'Sťahujem zoznam produktov Demosu (~1 min, jednorazovo)…');
      return;
    }
    if (p.refresh_done){
      nxdaInputChanged(); // zoznam je čerstvý — zopakuj aktuálny dotaz
      return;
    }
    nxdaSuggestRender(p.hits || [], p.hits && p.hits.length ? '' : 'Nič sa nenašlo — skús inak alebo vlož URL produktu.');
  },
  // Eventy family/create (session ABA vzor MDD).
  event: function(e){
    if (!NXDA_STATE.open) return;
    var chk = nxdaSessionCheck(NXDA_STATE.session, e.session);
    if (chk === 'stale') return;
    if (chk === 'new') NXDA_STATE.session = parseInt(e.session, 10) || 0;
    if (e.type === 'family'){
      NXDA_STATE.header = e.header || {};
      NXDA_STATE.items = e.items || [];
      NXDA_STATE.existing = e.existing === true;
      NXDA_STATE.checks = {};
      NXDA_STATE.autoIid = null;
      NXDA_STATE.failed = {};
      NXDA_STATE.mode = 'family';
      nxdaSetStatus((e.warnings && e.warnings.length) ? e.warnings.join(' · ') : 'Vyber, čo sa má založiť — nič nie je predzaškrtnuté.', false);
      nxdaRender();
    } else if (e.type === 'progress'){
      NXDA_STATE.log.push('Overujem ' + (e.label || '') + '… ✔');
      if (NXDA_STATE.mode === 'progress') nxdaRender();
    } else if (e.type === 'complete'){
      nxdaComplete(e);
    }
  },
  fail: function(p){ nxdaSetStatus(p && p.msg ? p.msg : 'Chyba.', true); }
};

function nxdaComplete(e){
  // GH #102 P1: úspešné založenie sa prizná VŽDY — aj keď medzitým prišlo
  // Zrušiť/iný stav (katalóg je reálne zapísaný, server complete po commite
  // doručí vždy). Hláška „zrušené" sa nesmie ponechať nad založenou skupinou.
  if (e.ok && e.result){
    var r = e.result;
    var n = (r.sheets || []).length + (r.edges || []).length;
    var skipped = (r.skipped || []).length;
    nxdaClose();
    MD.setStatus('Skupina založená z Demosu: ' + n + ' položiek' +
      (skipped ? ' (' + skipped + ' už v katalógu bolo)' : '') +
      (r.image === false ? ' — obrázok sa nepodarilo stiahnuť' : '') + '.', false);
    if (r.group_id && typeof mdOpenDetail === 'function') mdOpenDetail('g:' + r.group_id);
    return;
  }
  if (NXDA_STATE.mode === 'progress'){
    // all-or-nothing fail: návrat na výber s vyznačenými vinníkmi
    NXDA_STATE.mode = 'family';
    NXDA_STATE.failed = {};
    (e.failed || []).forEach(function(f){ if (f && f.iid) NXDA_STATE.failed[f.iid] = f.reason || 'zlyhalo'; });
    nxdaSetStatus((e.error || 'Založenie zlyhalo.') + ' Odškrtni vyznačené riadky a skús znova.', true);
    nxdaRender();
    return;
  }
  // complete z family loadu: ok=false = chyba načítania stránky
  if (!e.ok){
    NXDA_STATE.mode = 'search';
    nxdaRender();
    nxdaSuggestRender([], '');
    nxdaSetStatus(e.error || 'Stránku sa nepodarilo načítať.', true);
  }
}

// --- delegácia -------------------------------------------------------------------

if (typeof document !== 'undefined'){
  document.addEventListener('click', function(ev){
    // GH #102 P2: klik na scrim (mimo karty) zatvára — myš nesmie ostať
    // uväznená; počas progresu sa scrim ignoruje (zatvára Zrušiť/committed).
    if (ev.target && ev.target.id === 'nxdaModal' && NXDA_STATE.mode !== 'progress'){
      nxdaClose();
      return;
    }
    var sugg = ev.target && ev.target.closest ? ev.target.closest('.nxda-sugg-row') : null;
    if (sugg){ nxdaLoadFamily(sugg.getAttribute('data-url')); return; }
    var act = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
    if (!act) return;
    var a = act.getAttribute('data-action');
    if (a === 'nxda-close') nxdaClose();
    else if (a === 'nxda-back'){ NXDA_STATE.mode = 'search'; nxdaRender(); }
    else if (a === 'nxda-create') nxdaCreate();
    else if (a === 'nxda-cancel-create') nxdaCancelCreate();
  });
  document.addEventListener('change', function(ev){
    var t = ev.target;
    if (t && t.matches && t.matches('#nxdaBody input[type="checkbox"][data-iid]'))
      nxdaToggle(t.getAttribute('data-iid'), t.checked);
  });
}

// Node exporty (len čisté funkcie bez DOM).
if (typeof module !== 'undefined' && module.exports){
  module.exports = {
    nxdaSections: nxdaSections,
    nxdaAutoEdgeSuggest: nxdaAutoEdgeSuggest,
    nxdaSelectedIids: nxdaSelectedIids,
    nxdaEdgeOnly: nxdaEdgeOnly,
    nxdaPriceLabel: nxdaPriceLabel,
    nxdaSessionCheck: nxdaSessionCheck,
    nxdaImagePhase: nxdaImagePhase
  };
}
