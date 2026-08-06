  // =============== NASTAVENIA ROZPOCTU (V0.6 E-b) ===============
  // Formular globalnych sadzieb dodavatela. SERVER je autorita: JS zbiera
  // hodnoty do PATCHU (len zmenene polia), validaciu aj all-or-nothing zapis
  // robi SupplierSettings.patch_active!. Baseline `revision` cestuje tam aj
  // spat — cudzia zmena medzitym = odmietnutie + nacitanie nanovo.
  //
  // XSS kontrakt (vzor hw_catalog.js): obsah VYHRADNE createElement +
  // textContent; ovladanie cez data-action delegaciou; ziadne innerHTML s datami.

  var SS_STATE = null;   // posledny push zo servera
  var SS_DIRTY = {};     // zmenene polia: "rate:olep" -> "0.95" (surovy text)

  function ssEl(id){ return document.getElementById(id); }

  function ssMk(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  // Cislo -> text formulara (desatinna CIARKA, slovenske UI). null/undefined =
  // prazdne pole ("nezadane"), NIKDY nula.
  function ssNumText(v){
    if (v === null || v === undefined || v === '') return '';
    var f = Number(v);
    if (isNaN(f)) return '';
    return (Math.round(f * 100) / 100).toString().replace('.', ',');
  }

  // Text formulara -> hodnota do patchu. Prazdne pole ma pri REZIMOVEJ hodnote
  // vyznam „zmaz — pouzi zakladnu sadzbu" (null), pri ostatnych „nemen".
  function ssParse(text){
    var s = String(text == null ? '' : text).trim().replace(',', '.');
    if (s === '') return null;
    var f = Number(s);
    return isNaN(f) ? NaN : f;
  }

  function ssInput(key, value){
    var i = document.createElement('input');
    i.type = 'text';
    i.setAttribute('data-ss', key);
    i.value = (SS_DIRTY[key] !== undefined) ? SS_DIRTY[key] : ssNumText(value);
    return i;
  }

  function ssCell(row, cls, node){
    var td = ssMk('td', cls);
    if (node) td.appendChild(node);
    row.appendChild(td);
    return td;
  }

  // --- render -----------------------------------------------------------

  function ssHeadRow(table, cols){
    var tr = document.createElement('tr');
    cols.forEach(function(c){ tr.appendChild(ssMk('th', null, c)); });
    table.appendChild(tr);
  }

  // Sadzby sluzieb: zaklad + 3 rezimove stlpce. Rezimova hodnota VYHRAVA nad
  // zakladom (SupplierSettings.rate) — keby okno ukazovalo len zaklad, uprava
  // by sa navonok „neprejavila" (pd_opracovanie ma rezimy uz v seede).
  function ssRenderRates(){
    var t = ssEl('ssRates');
    t.textContent = '';
    ssHeadRow(t, ['Položka', 'Sadzba', '€', '€€', '€€€', '']);
    (SS_STATE.rate_keys || []).forEach(function(key){
      var meta = (SS_STATE.rate_labels || {})[key] || [key, ''];
      var tr = document.createElement('tr');
      tr.appendChild(ssMk('td', null, meta[0]));
      ssCell(tr, 'n', ssInput('rate:' + key, (SS_STATE.supplier.rates || {})[key]));
      ssModeCells(tr, key);
      ssCell(tr, 'u', ssMk('span', null, meta[1]));
      t.appendChild(tr);
    });
  }

  function ssRenderRows(){
    var t = ssEl('ssRows');
    t.textContent = '';
    ssHeadRow(t, ['Položka', 'Sadzba', '€', '€€', '€€€', '']);
    (SS_STATE.standard_rows || []).forEach(function(r){
      var tr = document.createElement('tr');
      tr.appendChild(ssMk('td', null, r.name));
      ssCell(tr, 'n', ssInput('row:' + r.key, r.rate));
      ssModeCells(tr, r.key);
      ssCell(tr, 'u', ssMk('span', null, r.kind === 'per_m2' ? '€/m²' : '€ fix'));
      t.appendChild(tr);
    });
  }

  function ssModeCells(tr, key){
    var mv = (SS_STATE.supplier.mode_values || {})[key] || {};
    (SS_STATE.modes || []).forEach(function(mode){
      ssCell(tr, 'n', ssInput('mode:' + key + ':' + mode, mv[mode]));
    });
  }

  // Skalare — zvlast, lebo nemaju rezimy (su to parametre vypoctu, nie ceny).
  var SS_SCALARS = [
    ['abs_reserve_pct', 'ABS rezerva', '%'],
    ['montaz_m2_per_plate', 'm² na jednu platňu (montáž)', 'm²'],
    ['rounding_step', 'Zaokrúhlenie ponuky nahor na', '€'],
    ['stale_days', 'Upozorniť na cenu staršiu ako', 'dní'],
    // E-b2: od akej sumy navrhne cenová ponuka SAMOSTATNÝ riadok (rozhodnutie
    // per položka ostáva v zákazke — toto je len návrh).
    ['cp_highlight_threshold', 'Samostatný riadok v cenovej ponuke od', '€']
  ];

  function ssRenderScalars(){
    var t = ssEl('ssScalars');
    t.textContent = '';
    SS_SCALARS.forEach(function(s){
      var tr = document.createElement('tr');
      tr.appendChild(ssMk('td', null, s[1]));
      ssCell(tr, 'n', ssInput('scalar:' + s[0], SS_STATE.supplier[s[0]]));
      ssCell(tr, 'u', ssMk('span', null, s[2]));
      t.appendChild(tr);
    });
  }

  function ssRender(){
    if (!SS_STATE) return;
    ssEl('ssLine').textContent = 'dodávateľ: ' + (SS_STATE.supplier.name || '—') +
      ' · globálne pre všetky zákazky · v' + SS_STATE.version;
    ssRenderRates();
    ssRenderRows();
    ssRenderScalars();
  }

  // --- patch ------------------------------------------------------------

  // Zbiera LEN zmenene polia (SS_DIRTY) — nikdy sa neposiela cely dokument
  // (audit 10: klient nesmie prepisovat, co nevidel).
  // -> { patch: {...}, errors: [texty] }
  function ssBuildPatch(dirty){
    var patch = {};
    var errors = [];
    Object.keys(dirty || {}).forEach(function(key){
      var parts = key.split(':');
      var kind = parts[0];
      var value = ssParse(dirty[key]);
      if (typeof value === 'number' && isNaN(value)){
        errors.push(key + ': hodnota musí byť číslo');
        return;
      }
      if (kind === 'rate'){
        if (value === null){ errors.push('sadzba nesmie byť prázdna'); return; }
        patch.rates = patch.rates || {};
        patch.rates[parts[1]] = value;
      } else if (kind === 'row'){
        if (value === null){ errors.push('sadzba riadku nesmie byť prázdna'); return; }
        patch.standard_rows = patch.standard_rows || {};
        patch.standard_rows[parts[1]] = patch.standard_rows[parts[1]] || {};
        patch.standard_rows[parts[1]].rate = value;
      } else if (kind === 'mode'){
        // null = VEDOME zmazanie rezimovej hodnoty (padne na zakladnu sadzbu)
        patch.mode_values = patch.mode_values || {};
        patch.mode_values[parts[1]] = patch.mode_values[parts[1]] || {};
        patch.mode_values[parts[1]][parts[2]] = value;
      } else if (kind === 'scalar'){
        if (value === null){ errors.push(parts[1] + ': hodnota nesmie byť prázdna'); return; }
        patch[parts[1]] = value;
      }
    });
    return { patch: patch, errors: errors };
  }

  function ssSave(){
    if (!SS_STATE) return;
    var built = ssBuildPatch(SS_DIRTY);
    if (built.errors.length){
      SS.setStatus('Neuložené: ' + built.errors.join(' · '), true);
      return;
    }
    if (!Object.keys(built.patch).length){
      SS.setStatus('Nič sa nezmenilo.');
      return;
    }
    if (window.sketchup && sketchup.save){
      sketchup.save(JSON.stringify({ revision: SS_STATE.revision, patch: built.patch }));
    }
  }

  // V prehliadaci je SS vstupny bod z Ruby; v node teste (bez window) sa
  // preskoci — testuju sa LEN ciste funkcie nizsie.
  if (typeof window !== 'undefined') window.SS = {
    init: function(data){
      SS_STATE = data || null;
      SS_DIRTY = {};      // cerstvy stav zo servera = koniec rozpisanych zmien
      ssRender();
    },
    setStatus: function(msg, err){
      var e = ssEl('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    }
  };

  if (typeof document !== 'undefined'){
    document.addEventListener('input', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      var key = t.getAttribute('data-ss');
      if (!key) return;
      SS_DIRTY[key] = t.value;
      var v = ssParse(t.value);
      t.classList.toggle('bad', typeof v === 'number' && isNaN(v));
    });
    document.addEventListener('click', function(ev){
      var b = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
      if (!b) return;
      var a = b.getAttribute('data-action');
      if (a === 'ss-save') ssSave();
      else if (a === 'ss-reload'){ SS_DIRTY = {}; if (window.sketchup && sketchup.reload) sketchup.reload(''); }
    });
    window.onload = function(){ if (window.sketchup && sketchup.ready) sketchup.ready(''); };
  }

  // Node testy (tests/js/test_budget_ui.js) — len ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { ssBuildPatch: ssBuildPatch, ssParse: ssParse, ssNumText: ssNumText };
  }
