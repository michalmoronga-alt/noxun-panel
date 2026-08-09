  // ===================== KOVANIE (V0.4 faza 1) =====================
  // Sekcia zobrazuje vypocitane polozky (config.hardware oznacenej skrinky) a rucne
  // zasahy. Identita polozky = (owner_part_key, generic_type, rule_id) — presne tak
  // ju posiela set_hardware_override do Ruby. Bez oznacenej skrinky len hint
  // (kovanie sa pocita na realnej skrinke, nie z hodnot panela).

  // V0.6 C-2 (audit F11): autorita labelov je SERVER (HardwareRules.label_for,
  // payload nesie it.label) — tato mapa je uz LEN fallback pre stary payload.
  function hwLabel(t){
    return { leg:'Nohy', hinge:'Závesy', slide:'Výsuv', handle:'Úchytky',
             shelf_pin:'Podperky', connector:'Spojky' }[t] || t;
  }
  function hwUnit(t){ return t === 'slide' ? 'sada' : 'ks'; }
  // Ludsky popis vlastnika: front:F2/wing:left -> "F2 · ľavé krídlo".
  // D-24: wing:p1..p4 (3/4-kridlove dvierka) -> "F1 · krídlo 1/3"; celkovy pocet
  // kridiel berie z frontItems (wings_n z Ruby), bez neho aspon "krídlo 1".
  function hwOwnerDesc(owner){
    if (!owner) return '';
    var m = owner.match(/^front:([^\/]+)\/wing:(left|right|single|p[1-4])$/);
    if (m){
      var wkey = m[2];
      if (wkey === 'left') return m[1] + ' · ľavé krídlo';
      if (wkey === 'right') return m[1] + ' · pravé krídlo';
      if (wkey === 'single') return m[1];
      var i = parseInt(wkey.slice(1), 10);
      var n = null;
      var fis = (typeof frontItems !== 'undefined' && frontItems) ? frontItems : [];
      for (var k = 0; k < fis.length; k++){
        if (String(fis[k].id) === m[1]){ n = fis[k].wings_n; break; }
      }
      return m[1] + ' · krídlo ' + i + ((n && n >= i) ? '/' + n : '');
    }
    var p = owner.match(/^front:([^\/]+)\/panel$/);
    if (p) return p[1] + ' · zásuvka';
    return owner;
  }
  function hwParamsDesc(it){
    var ps = it.params || {};
    if (ps.nominal_length != null) return 'NL ' + Math.round(ps.nominal_length);
    if (ps.height != null) return Math.round(ps.height) + ' mm';
    return '';
  }
  function hwKey(owner, type, rule){ return (owner||'') + '||' + type + '||' + rule; }

  // ---- D-92: „co sa realne kupi" (sekundarny riadok polozky) ----------------
  // Server (HardwareSets.explain) posle rozpis: nazov setu + clenovia s kodmi,
  // nazvami z katalogu a poctami, plus slovenske problemy (nemapovane).
  // TU sa uz len sklada text — ziadne rozhodovanie o nakupe (autorita je server).
  // Ciste funkcie (Node testy: tests/js/test_d92_hw_nakup.js).
  var HW_NO_CATALOG = 'mimo katalógu'; // kod, ktory v katalogu kovania nie je

  function hwMemberText(m){
    if (!m) return '';
    var q = (m.qty && m.qty > 1) ? (m.qty + '× ') : '';
    return q + (m.code || '') + ' · ' + (m.name || HW_NO_CATALOG);
  }
  // -> null (nic na zobrazenie) | { text, warn }
  // warn = true, ked nakup NIE JE kompletny (chyba set/kod/pasmo) — riadok
  // dostane jantarovu farbu upozornenia (NIE semaforove --nx-state-*).
  function hwBuyLine(p){
    if (!p) return null;
    var parts = (p.members || []).map(hwMemberText).filter(function(t){ return t !== ''; });
    var problems = (p.problems || []).filter(function(t){ return !!t; });
    var text = '';
    if (parts.length){
      text = (p.set_name ? p.set_name + ' → ' : '') + parts.join(' + ');
      if (problems.length) text += ' · ' + problems.join(' · ');
    } else if (problems.length){
      text = problems.join(' · ');
    } else {
      return null;
    }
    return { text: text, warn: problems.length > 0 };
  }
  function hwBuyHtml(p){
    var line = hwBuyLine(p);
    if (!line) return '';
    // title = plny text (riadok je jednoriadkovy s ellipsis — vertikalny priestor)
    return '<div class="hwbuy' + (line.warn ? ' hwbuy-warn' : '') + '" title="' + esc(line.text) + '">'
         + esc(line.text) + '</div>';
  }

  // ---- V0.6 H1b: vyber setu (skrinka + D-81 per dielec) --------------------
  // Posledna ponuka zo servera (payload hardware_set_options). Zivy push
  // NX.setHardwareSets ju vymeni a prekresli LEN <select>y — riadky, rozpisane
  // pocty ani vyber sa nedotknu.
  var HW_SET_OPTIONS = [];
  // Hodnota volby „vyber podla parametra" — je len ZOBRAZENIE stavu (disabled),
  // nikdy sa neposiela na server.
  var HW_SET_PARAM = '__param__';

  function hwFindEntry(list, gt){
    var l = list || [];
    for (var i = 0; i < l.length; i++){
      if (l[i] && l[i].generic_type === gt) return l[i];
    }
    return null;
  }
  function hwSetEntry(gt){ return hwFindEntry(HW_SET_OPTIONS, gt); }
  function hwOwnerOverride(entry, owner){
    var m = (entry && entry.owner_overrides) || {};
    return (owner && m[owner]) ? m[owner] : null;
  }

  // Ciste funkcie (Node testy: tests/js/test_hw_panel_sets.js).
  // Ponuka jedneho selectu setu: 1. volba = „dedi" (projekt / skrinka), potom
  // sety daneho typu. current = zapisany set_id ('' = dedi), paramLabel = text,
  // ked je zapisany vyber PODLA PARAMETRA (selector — panel ho needituje).
  // -> [{ value, text, selected, disabled }]
  function hwSetOptionList(entry, current, defaultText, paramLabel){
    var out = [{ value: '', text: defaultText, selected: !current && !paramLabel, disabled: false }];
    if (paramLabel){
      out.push({ value: HW_SET_PARAM, text: paramLabel, selected: true, disabled: true });
    }
    var opts = (entry && entry.options) || [];
    var found = false;
    opts.forEach(function(s){
      if (s.set_id === current) found = true;
      out.push({ value: s.set_id, text: s.name,
                 selected: !paramLabel && s.set_id === current, disabled: false });
    });
    // Set, ktory uz nie je v ponuke (zmazany z kniznice), je v modeli STALE
    // zapisany — musi ostat viditelny, inak by select klamal.
    if (current && !found){
      out.push({ value: current, text: current + ' (chýba)', selected: !paramLabel, disabled: false });
    }
    return out;
  }
  // Ponuka pre riadok DIELCA (owner-level override, D-81).
  function hwOwnerOptionList(entry, owner){
    var ov = hwOwnerOverride(entry, owner);
    return hwSetOptionList(entry, (ov && ov.set_id) || '', '(podľa skrinky/projektu)',
                           (ov && ov.selector) ? (ov.label || 'podľa parametra') : null);
  }
  // Ponuka pre riadok SKRINKY (override projektovej predvolby).
  function hwCabOptionList(entry){
    return hwSetOptionList(entry, (entry && entry.override_set_id) || '',
                           (entry && entry.project_label) || 'podľa projektu',
                           (entry && entry.override_selector) ? (entry.override_label || 'podľa parametra') : null);
  }
  function hwOptionsHtml(list){
    var h = '';
    list.forEach(function(o){
      h += '<option value="' + esc(o.value) + '"' + (o.selected ? ' selected' : '')
         + (o.disabled ? ' disabled' : '') + '>' + esc(o.text) + '</option>';
    });
    return h;
  }
  function hwSetSelectHtml(list, gt, owner, cabId, title){
    return '<select class="hwsetsel" data-gt="' + esc(gt) + '" data-owner="' + esc(owner || '')
         + '" data-cab="' + esc(cabId || '') + '" title="' + esc(title) + '" onchange="onHwSet(this)">'
         + hwOptionsHtml(list) + '</select>';
  }
  // D-75: zivy refresh ponuky bez prekreslenia riadkov (rozpisany pocet
  // ostava). Vybranu hodnotu urcuje SERVER — payload nesie aktualne overridy.
  function refreshHardwareSets(options){
    HW_SET_OPTIONS = options || [];
    var box = el('hwRows'); if (!box) return;
    var sels = box.querySelectorAll('select.hwsetsel');
    for (var i = 0; i < sels.length; i++){
      var sel = sels[i];
      var entry = hwSetEntry(sel.getAttribute('data-gt'));
      var owner = sel.getAttribute('data-owner') || '';
      sel.innerHTML = hwOptionsHtml(owner ? hwOwnerOptionList(entry, owner) : hwCabOptionList(entry));
      sel.title = owner ? hwOwnerTitle(entry) : hwCabTitle(entry);
    }
  }
  // D-92: zivy refresh SEKUNDARNYCH riadkov (nakup) bez prekreslenia poloziek —
  // rozpisany pocet, fokus aj vyber setu ostavaju. Parovanie cez identitu
  // riadku (owner_part_key + generic_type + rule_id), presne tak, ako ju
  // posiela server; polozka, ktora sa uz nezhoduje, sa ticho preskoci
  // (nasledujuci push_selected riadky aj tak prestavia).
  function refreshHardwarePurchase(items){
    var box = el('hwRows'); if (!box) return;
    (items || []).forEach(function(it){
      if (!it) return;
      var sel = '.hwrow[data-owner="' + cssEsc(it.owner_part_key || '') + '"]'
              + '[data-type="' + cssEsc(it.generic_type || '') + '"]'
              + '[data-rule="' + cssEsc(it.rule_id || '') + '"]';
      var row = box.querySelector(sel);
      var item = row ? row.parentNode : null;
      if (!item || !item.classList || !item.classList.contains('hwitem')) return;
      var old = item.querySelector('.hwbuy');
      if (old) old.parentNode.removeChild(old);
      var html = hwBuyHtml(it.purchase);
      if (html) item.insertAdjacentHTML('beforeend', html);
    });
  }
  // Hodnoty v atributovom selektore su datove (part_key, rule_id) — uvodzovky
  // a spatne lomitka treba escapovat, inak by selektor spadol.
  function cssEsc(v){ return String(v).replace(/(["\\])/g, '\\$1'); }

  function hwOwnerTitle(entry){
    return 'Set kovania pre tento dielec · bez vlastného výberu platí: '
         + ((entry && entry.owner_default_label) || 'predvoľba projektu');
  }
  function hwCabTitle(entry){
    return 'Set kovania pre celú skrinku · bez vlastného výberu platí: '
         + ((entry && entry.project_label) || 'predvoľba projektu');
  }

  // items: config.hardware (pole) alebo null (nic neoznacene); overrides: hardware_overrides;
  // setOptions (D1b): ponuka setu per typ (server payloads.hardware_set_options);
  // cabId (GH #127 P2): identita RENDROVANEJ skrinky — cestuje s payloadom.
  function renderHardware(items, overrides, setOptions, cabId){
    var box = el('hwRows'); if (!box) return;
    HW_SET_OPTIONS = setOptions || [];
    if (items === null){
      box.innerHTML = '<div class="muted">Označ skrinku v modeli — kovanie sa počíta na vloženej skrinke.</div>';
      return;
    }
    var html = '';
    var present = {};
    items.forEach(function(it){
      present[hwKey(it.owner_part_key, it.generic_type, it.rule_id)] = true;
      var name = it.label || hwLabel(it.generic_type);
      // D-92: vlastnika pomenuva SERVER (owner_label — „F2 · zásuvkové čelo").
      // hwOwnerDesc ostava LEN ako fallback pre stary payload.
      var owner = it.owner_label || hwOwnerDesc(it.owner_part_key);
      var extra = hwParamsDesc(it);
      var manual = it.source === 'manual';
      // D-81: kovanie viazane na DIELEC (čelo/zásuvka) má vlastný výber setu
      // PRIAMO v riadku — žiadny nový riadok (vertikálny priestor). Platí pre
      // každý typ s vlastníkom (výsuv per zásuvka, závesy per krídlo) — server
      // (apply_cabinet_override) overuje, že dielec také kovanie naozaj má.
      var entry = it.owner_part_key ? hwSetEntry(it.generic_type) : null;
      var setSel = entry
        ? hwSetSelectHtml(hwOwnerOptionList(entry, it.owner_part_key), it.generic_type,
                          it.owner_part_key, cabId, hwOwnerTitle(entry))
        : '';
      // D-92: polozka = hlavny riadok + JEDEN sekundarny riadok s nakupom
      // (obal .hwitem drzi obe casti pokope; .hwrow ostava nedotknuty, takze
      // hwPayload/closest('.hwrow') aj refreshHardwareSets funguju dalej).
      html += '<div class="hwitem">'
        + '<div class="hwrow" data-owner="'+esc(it.owner_part_key||'')+'" data-type="'+esc(it.generic_type)+'" data-rule="'+esc(it.rule_id)+'">'
        // title = celý popis riadku — na úzkom paneli (<400 px) sa .hwext skrýva
        + '<span class="hwname" title="'+esc(name+(owner?' · '+owner:'')+(extra?' · '+extra:''))+'">'
        + esc(name)+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
        + (extra?' <span class="hwext">'+esc(extra)+'</span>':'')+'</span>'
        + setSel
        + '<input class="hwqty'+(manual?' manual':'')+'" type="number" min="1" max="999" step="1" value="'+esc(it.quantity)+'" onchange="onHwQty(this)">'
        + '<span class="unit">'+hwUnit(it.generic_type)+'</span>'
        + (manual
            ? '<button class="ghostbtn hwbtn" title="Vrátiť na pravidlo ('+esc(it.rule_quantity)+')" aria-label="Vrátiť na pravidlo" onclick="onHwReset(this)">'+NXIcons.svg('rotate-ccw')+'</button>'
            : '<span class="hwsrc" title="Počet z pravidla"></span>')
        + '<button class="ghostbtn hwbtn" title="Vypnúť položku" aria-label="Vypnúť položku" onclick="onHwDisable(this)">'+NXIcons.svg('x')+'</button>'
        + '</div>'
        + hwBuyHtml(it.purchase)
        + '</div>';
    });
    // Vypnute kategorie: disabled override bez zodpovedajucej polozky (evaluate ju vyradil).
    (overrides || []).forEach(function(ov){
      if (!ov || ov.disabled !== true) return;
      if (present[hwKey(ov.owner_part_key, ov.generic_type, ov.rule_id)]) return;
      var owner = ov.owner_label || hwOwnerDesc(ov.owner_part_key); // D-92
      html += '<div class="hwrow hwoff" data-owner="'+esc(ov.owner_part_key||'')+'" data-type="'+esc(ov.generic_type)+'" data-rule="'+esc(ov.rule_id)+'">'
        + '<span class="hwname">'+esc(hwLabel(ov.generic_type))+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
        + ' <span class="hwext">vypnuté</span></span>'
        + '<button class="ghostbtn hwbtn" title="Obnoviť (platí pravidlo)" onclick="onHwReset(this)">'+NXIcons.svg('rotate-ccw')+' obnoviť</button>'
        + '</div>';
    });
    if (!html) html = '<div class="muted">Skrinka nemá žiadne kovanie (bez čiel, bez podstavca).</div>';
    // V0.6 D1b: vyber setu per typ — override projektovej predvolby na CELEJ
    // skrinke. Kompaktne (vertikalny priestor): 1 riadok na pritomny typ.
    // D-75: riadok je aj pri PRAZDNEJ ponuke (server posiela len typy, ktore
    // skrinka naozaj ma) — inak by sa prvy novy set typu neobjavil hned, ale
    // az po novom vybere (zivy push obnovuje EXISTUJUCE selecty).
    (setOptions || []).forEach(function(o){
      if (!o) return;
      html += '<div class="hwrow hwsetrow"><span class="hwname">'+esc(o.label)
            + ' <span class="hwown">set</span></span>'
            + hwSetSelectHtml(hwCabOptionList(o), o.generic_type, '', cabId, hwCabTitle(o))
            + '</div>';
    });
    box.innerHTML = html;
  }
  function onHwSet(sel){
    // Volba „podľa parametra" je len zobrazenie stavu (disabled) — nikdy sa
    // neodosiela; server by ju aj tak odmietol ako neznamy set.
    if (sel.value === HW_SET_PARAM) return;
    if (window.sketchup && sketchup.set_hardware_set)
      sketchup.set_hardware_set(JSON.stringify({ generic_type: sel.getAttribute('data-gt'),
                                                 owner_part_key: sel.getAttribute('data-owner') || null,
                                                 set_id: sel.value,
                                                 cabinet_id: sel.getAttribute('data-cab') || '' })); // GH #127 P2
  }

  function hwPayload(node, extra){
    var row = node.closest('.hwrow');
    var out = { owner_part_key: row.dataset.owner || null,
                generic_type: row.dataset.type, rule_id: row.dataset.rule };
    for (var k in extra) out[k] = extra[k];
    return out;
  }
  function hwSend(payload){
    if (window.sketchup && sketchup.set_hardware_override)
      sketchup.set_hardware_override(JSON.stringify(payload));
  }
  function onHwQty(inp){
    var q = parseInt(inp.value, 10);
    if (isNaN(q) || q < 1){ NX.setStatus('Počet musí byť aspoň 1 (alebo položku vypni).', true); return; }
    hwSend(hwPayload(inp, { quantity: q }));
  }
  function onHwDisable(btn){ hwSend(hwPayload(btn, { disabled: true })); }
  function onHwReset(btn){ hwSend(hwPayload(btn, { reset: true })); }
  function openRulesDialog(){
    if (window.sketchup && sketchup.open_rules) sketchup.open_rules('');
  }
  // D-91: Katalog kovania z hlavicky panela — rovnaky mechanizmus ako
  // "Pravidla kovania..." (satelitne okno, ziadny zasah do modelu).
  function openHardwareCatalogDialog(){
    if (window.sketchup && sketchup.open_hardware_catalog) sketchup.open_hardware_catalog('');
  }

  // Node testy (tests/js/test_hw_panel_sets.js) — LEN ciste funkcie ponuky
  // setov (bez DOM). V CEF je module undefined a vetva sa preskoci.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { hwSetOptionList: hwSetOptionList, hwOwnerOptionList: hwOwnerOptionList,
      hwCabOptionList: hwCabOptionList, hwFindEntry: hwFindEntry, hwOwnerDesc: hwOwnerDesc,
      HW_SET_PARAM: HW_SET_PARAM,
      // D-92 rozpis nakupu (tests/js/test_d92_hw_nakup.js)
      hwMemberText: hwMemberText, hwBuyLine: hwBuyLine, HW_NO_CATALOG: HW_NO_CATALOG };
  }
