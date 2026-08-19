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

  // ---- D-93: rucny override nominalnej dlzky vysuvu (zamok) ----------------
  // Server posiela pri polozkach pravidla 'fit_series' blok `nl`
  // { series, value, locked, auto, auto_known }. Zamok = existencia rucnej
  // hodnoty na serveri — JS si stav NIKDY nepamata ani neodvodzuje.
  // Ciste funkcie (Node testy: tests/js/test_d93_nl_override.js).
  function hwNlFmt(v){
    var f = Number(v);
    if (!isFinite(f)) return '';
    return (Math.abs(f - Math.round(f)) < 0.05) ? String(Math.round(f))
                                                : f.toFixed(1).replace('.', ',');
  }
  // Ponuka selectu NL: hodnoty radu z pravidla; ULOZENA hodnota mimo radu
  // (rad sa medzitým upravil) sa NEMAZE — pridá sa ako doplnená voľba, inak by
  // select klamal (F5). -> [{ value, text, selected }]
  function hwNlOptionList(nl){
    var out = [];
    var series = (nl && nl.series) || [];
    var value = (nl && nl.value != null) ? Number(nl.value) : null;
    var found = false;
    series.forEach(function(s){
      var sel = value != null && Math.abs(Number(s) - value) < 0.001;
      if (sel) found = true;
      out.push({ value: String(s), text: hwNlFmt(s), selected: sel });
    });
    if (value != null && !found){
      out.push({ value: String(value), text: hwNlFmt(value) + ' (mimo radu)', selected: true });
    }
    return out;
  }
  function hwNlAutoText(nl){
    return (nl && nl.auto_known) ? (hwNlFmt(nl.auto) + ' mm') : 'nezmestí sa';
  }
  function hwNlSelectTitle(nl){
    return (nl && nl.locked)
      ? ('Dĺžka výsuvu je ručne zamknutá (automat: ' + hwNlAutoText(nl) + ')')
      : 'Dĺžku výsuvu určuje automat podľa svetlej hĺbky — výberom hodnoty ju zamkneš';
  }
  function hwNlLockTitle(nl){
    return (nl && nl.locked)
      ? ('Odomknúť — vráti sa automat (' + hwNlAutoText(nl) + ')')
      : 'Zamknúť túto dĺžku (zmena hĺbky skrinky ju už nezmení)';
  }
  function hwKey(owner, type, rule){ return (owner||'') + '||' + type + '||' + rule; }

  // ---- UI-C4: BOXY PODLA VLASTNIKA ----------------------------------------
  // Kontrakt UI 2.0 (sekcia Kovanie): polozky nie su jeden dlhy zoznam, ale
  // horizontalne boxy — „Skrinka", potom box KAZDEHO cela. Je to ZOBRAZENIE
  // tych istych dat: identita polozky (owner_part_key, generic_type, rule_id)
  // ani zapisove cesty sa nemenia, len sa riadky preskupia.
  //
  // Kluc skupiny (`data-group` na boxe) je ODVODENY z owner_part_key — nie je
  // to nove datove pole:
  //   ''                      -> 'cab'          (kovanie celej skrinky)
  //   'front:<id>/wing:left'  -> 'front:<id>'   (obe kridla su JEDNO celo)
  //   'zone:<z>/shelf:1'      -> 'inside'       (podperky, priecky — spolocny box)
  // Ciste funkcie (Node testy: tests/js/test_uic4_kovanie.js).
  var HW_GROUP_CAB = 'cab';
  var HW_GROUP_INSIDE = 'inside';

  function hwGroupKeyOf(owner){
    var o = String(owner == null ? '' : owner);
    if (!o) return HW_GROUP_CAB;
    var m = o.match(/^front:([^\/]+)\//);
    return m ? ('front:' + m[1]) : HW_GROUP_INSIDE;
  }
  // Popis vlastnika sklada SERVER (PartKeys.human_label) v tvare „F2 · zásuvkové
  // čelo". Hlavicka boxu berie PRVU cast, riadok v boxe DRUHU — cislo cela sa
  // tak nikdy neopakuje dvakrat pod sebou a panel si nic nedopocitava.
  function hwLabelHead(label){
    var s = String(label == null ? '' : label);
    var i = s.indexOf(' · ');
    return i < 0 ? s : s.slice(0, i);
  }
  function hwLabelTail(label){
    var s = String(label == null ? '' : label);
    var i = s.indexOf(' · ');
    return i < 0 ? '' : s.slice(i + 3);
  }
  // Text riadku o vlastnikovi. V boxe cela staci upresnenie („ľavé krídlo"),
  // v spolocnom boxe Vnutro musi ostat CELY popis („Polica 2").
  function hwRowOwnerText(groupKey, ownerLabel){
    if (!groupKey || groupKey === HW_GROUP_CAB) return '';
    if (groupKey === HW_GROUP_INSIDE) return String(ownerLabel == null ? '' : ownerLabel);
    return hwLabelTail(ownerLabel);
  }
  function hwGroupTitle(groupKey, sampleLabel, cabId){
    if (groupKey === HW_GROUP_CAB) return cabId ? ('Skrinka ' + cabId) : 'Skrinka';
    if (groupKey === HW_GROUP_INSIDE) return 'Vnútro skrinky';
    var head = hwLabelHead(sampleLabel);
    // Ked server popis nedodal (alebo je to surovy kluc, lebo sa celo v resolved
    // zozname nenaslo), NIC sa nevymysla — hlavicka ostane holy „Čelo". Surovy
    // kluc v hlavicke by vyzeral ako nazov a pritom by nic nehovoril.
    if (!head || head.indexOf('/') >= 0 || head.indexOf(':') >= 0) return 'Čelo';
    return 'Čelo ' + head;
  }
  // Meta sumar v hlavicke boxu. Zamerne POCET (nie vypocet typov) — typy su
  // vypisane hned pod hlavickou a zopakovat ich by bola len redundancia.
  function hwGroupCountText(n){
    var c = Math.max(0, parseInt(n, 10) || 0);
    if (c === 1) return '1 položka';
    if (c >= 2 && c <= 4) return c + ' položky';
    return c + ' položiek';
  }
  // Poradie boxov: Skrinka -> cela v poradi ZOZNAMU CIEL (frontIds, teda presne
  // to, co pouzivatel vidi v kontexte Čelá) -> Vnútro. Cela mimo zoznamu
  // (stary payload) idu za znamymi v poradi vyskytu — nikdy nezmiznu.
  function hwGroupOrder(key, frontIds){
    if (key === HW_GROUP_CAB) return -1;
    if (key === HW_GROUP_INSIDE) return 1e6;
    var ids = frontIds || [];
    for (var i = 0; i < ids.length; i++){
      if ('front:' + String(ids[i]) === key) return i;
    }
    return 1e5;
  }
  // items: config.hardware; offs: `disabled` overridy BEZ zodpovedajucej polozky;
  // frontIds: poradie ciel (id). -> [{ key, title, ownerKeys[], items[], offs[] }]
  function hwGroups(items, offs, frontIds, cabId){
    var map = {}, seq = 0;
    function bucket(owner, label){
      var key = hwGroupKeyOf(owner);
      if (!map[key]){
        map[key] = { key: key, title: hwGroupTitle(key, label, cabId), ownerKeys: [],
                     items: [], offs: [], seq: seq++ };
      }
      var o = String(owner == null ? '' : owner);
      if (o && map[key].ownerKeys.indexOf(o) < 0) map[key].ownerKeys.push(o);
      return map[key];
    }
    (items || []).forEach(function(it){
      if (!it) return;
      bucket(it.owner_part_key, it.owner_label).items.push(it);
    });
    (offs || []).forEach(function(ov){
      if (!ov) return;
      bucket(ov.owner_part_key, ov.owner_label).offs.push(ov);
    });
    var out = [];
    for (var k in map){ if (Object.prototype.hasOwnProperty.call(map, k)) out.push(map[k]); }
    out.sort(function(a, b){
      var oa = hwGroupOrder(a.key, frontIds), ob = hwGroupOrder(b.key, frontIds);
      return oa === ob ? (a.seq - b.seq) : (oa - ob);
    });
    return out;
  }
  // `disabled` overridy, ktorym uz nezodpoveda ziadna polozka (evaluate ju
  // vyradil) — presne ta ista podmienka ako doteraz, len vytiahnuta zvlast,
  // aby sa dala zaradit do boxu vlastnika (a testovat bez DOM).
  function hwDisabledOffs(items, overrides){
    var present = {};
    (items || []).forEach(function(it){
      if (it) present[hwKey(it.owner_part_key, it.generic_type, it.rule_id)] = true;
    });
    return (overrides || []).filter(function(ov){
      if (!ov || ov.disabled !== true) return false;
      return !present[hwKey(ov.owner_part_key, ov.generic_type, ov.rule_id)];
    });
  }

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
    // UI-C4: selecty setov ziju v DVOCH kontajneroch — per vlastnik v boxoch
    // (#hwRows) a per typ pre celu skrinku v skupine Sety (#hwSetRows).
    ['hwRows', 'hwSetRows'].forEach(function(id){
      var box = el(id); if (!box) return;
      var sels = box.querySelectorAll('select.hwsetsel');
      for (var i = 0; i < sels.length; i++){
        var sel = sels[i];
        var entry = hwSetEntry(sel.getAttribute('data-gt'));
        var owner = sel.getAttribute('data-owner') || '';
        sel.innerHTML = hwOptionsHtml(owner ? hwOwnerOptionList(entry, owner) : hwCabOptionList(entry));
        sel.title = owner ? hwOwnerTitle(entry) : hwCabTitle(entry);
      }
    });
  }
  // D-92: zivy refresh SEKUNDARNYCH riadkov (nakup) bez prekreslenia poloziek —
  // rozpisany pocet, fokus aj vyber setu ostavaju. Parovanie cez identitu
  // riadku (owner_part_key + generic_type + rule_id), presne tak, ako ju
  // posiela server; polozka, ktora sa uz nezhoduje, sa ticho preskoci
  // (nasledujuci push_selected riadky aj tak prestavia).
  function refreshHardwarePurchase(items){
    // Codex #178 P2 (UI-C3): naviazané kovanie pod riadkom čela ukazuje NÁZOV
    // SETU — ten sa mení presne týmto pushom. Mapa aj riadky sa preto obnovia
    // TU (mimo `#hwRows`), inak by pod čelami visel starý set až do nového
    // označenia skrinky. Robí sa to PRED riadkami Kovania a z CELÉHO payloadu
    // (nie len z položiek, ktorým sa našiel riadok).
    if (typeof refreshFrontHwBuy === 'function') refreshFrontHwBuy(items);
    if (typeof updateFrontRowBadges === 'function') updateFrontRowBadges();
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

  // Jedna polozka = hlavny riadok + JEDEN sekundarny riadok s nakupom (D-92).
  // Obal .hwitem drzi obe casti pokope; .hwrow ostava nedotknuty, takze
  // hwPayload/closest('.hwrow'), refreshHardwareSets aj refreshHardwarePurchase
  // funguju presne ako pred UI-C4 (preskupenie do boxov je len ZOBRAZENIE).
  function hwItemHtml(it, cabId, groupKey){
    var name = it.label || hwLabel(it.generic_type);
    // D-92: vlastnika pomenuva SERVER (owner_label — „F2 · zásuvkové čelo").
    // hwOwnerDesc ostava LEN ako fallback pre stary payload. UI-C4: v boxe cela
    // sa cislo cela uz nesie hlavicka, riadok drzi len upresnenie kridla.
    var full = it.owner_label || hwOwnerDesc(it.owner_part_key);
    var owner = hwRowOwnerText(groupKey, full);
    // D-93: pri výsuvoch nahradí popis „NL 470" priamo ovládateľný select —
    // žiadny nový riadok, len iný obsah toho istého miesta.
    var extra = it.nl ? '' : hwParamsDesc(it);
    // D-93: „ručne" pri POČTE je vlastné pole overridu (samotný zámok dĺžky
    // už tiež robí položku manual, ale počet pravidla nemení).
    var manual = (it.quantity_manual != null) ? (it.quantity_manual === true)
                                              : (it.source === 'manual');
    var nlHtml = it.nl ? hwNlHtml(it.nl) : '';
    // D-81: kovanie viazane na DIELEC (čelo/zásuvka) má vlastný výber setu
    // PRIAMO v riadku — žiadny nový riadok (vertikálny priestor). Platí pre
    // každý typ s vlastníkom (výsuv per zásuvka, závesy per krídlo) — server
    // (apply_cabinet_override) overuje, že dielec také kovanie naozaj má.
    var entry = it.owner_part_key ? hwSetEntry(it.generic_type) : null;
    var setSel = entry
      ? hwSetSelectHtml(hwOwnerOptionList(entry, it.owner_part_key), it.generic_type,
                        it.owner_part_key, cabId, hwOwnerTitle(entry))
      : '';
    return '<div class="hwitem">'
      + '<div class="hwrow" data-owner="'+esc(it.owner_part_key||'')+'" data-type="'+esc(it.generic_type)+'" data-rule="'+esc(it.rule_id)+'" data-cab="'+esc(cabId||'')+'">'
      // title = celý popis riadku (aj s PLNYM vlastníkom) — na úzkom paneli
      // (<400 px) sa .hwext skrýva
      + '<span class="hwname" title="'+esc(name+(full?' · '+full:'')+(extra?' · '+extra:''))+'">'
      + esc(name)+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
      + (extra?' <span class="hwext">'+esc(extra)+'</span>':'')+'</span>'
      + nlHtml
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
  }
  // Vypnuta kategoria (disabled override bez zodpovedajucej polozky).
  function hwOffHtml(ov, cabId, groupKey){
    var full = ov.owner_label || hwOwnerDesc(ov.owner_part_key); // D-92
    var owner = hwRowOwnerText(groupKey, full);
    return '<div class="hwrow hwoff" data-owner="'+esc(ov.owner_part_key||'')+'" data-type="'+esc(ov.generic_type)+'" data-rule="'+esc(ov.rule_id)+'" data-cab="'+esc(cabId||'')+'">'
      + '<span class="hwname">'+esc(hwLabel(ov.generic_type))+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
      + ' <span class="hwext">vypnuté</span></span>'
      + '<button class="ghostbtn hwbtn" title="Obnoviť (platí pravidlo)" onclick="onHwEnable(this)">'+NXIcons.svg('rotate-ccw')+' obnoviť</button>'
      + '</div>';
  }
  // UI-C4: box vlastnika. Hlavicka je TLACIDLO (klavesnica aj citacka) a nesie
  // `data-keys` = part_key vlastnikov, ktore ma klik oznacit v modeli. Box sa
  // NEZBALUJE — exkluzivita skupin S4 na skratenie panela staci.
  function hwBoxHtml(g, cabId){
    var body = g.items.map(function(it){ return hwItemHtml(it, cabId, g.key); }).join('')
             + g.offs.map(function(ov){ return hwOffHtml(ov, cabId, g.key); }).join('');
    var n = g.items.length + g.offs.length;
    var tip = (g.key === HW_GROUP_CAB)
      ? 'Označí skrinku v modeli'
      : 'Označí tento dielec v modeli (panel ostáva v Kovaní)';
    return '<div class="hwbox" data-group="'+esc(g.key)+'" data-keys="'+esc(g.ownerKeys.join(','))+'">'
      + '<button type="button" class="hwboxh" data-cab="'+esc(cabId||'')+'" title="'+esc(g.title+' — '+tip)+'"'
      + ' aria-label="'+esc(g.title+' — '+tip)+'" onclick="onHwOwnerPick(this)">'
      + NXIcons.svg('eye')
      + '<span class="hwboxt">'+esc(g.title)+'</span>'
      + '<span class="hwboxsub">'+esc(hwGroupCountText(n))+'</span></button>'
      + '<div class="hwboxb">'+body+'</div></div>';
  }

  // items: config.hardware (pole) alebo null (nic neoznacene); overrides: hardware_overrides;
  // setOptions (D1b): ponuka setu per typ (server payloads.hardware_set_options);
  // cabId (GH #127 P2): identita RENDROVANEJ skrinky — cestuje s payloadom.
  function renderHardware(items, overrides, setOptions, cabId){
    var box = el('hwRows'); if (!box) return;
    var setBox = el('hwSetRows');
    // Prestavbou zaniknu uzly, na ktorych visi zvyraznenie hoveru (vzor
    // clearFrontHover v renderPreview) — inak by v SVG ostala svietit znacka
    // boxu, ktory uz neexistuje.
    hwClearHover();
    HW_SET_OPTIONS = setOptions || [];
    if (items === null){
      box.innerHTML = '<div class="muted">Označ skrinku v modeli — kovanie sa počíta na vloženej skrinke.</div>';
      if (setBox) setBox.innerHTML = '<div class="muted">Označ skrinku v modeli.</div>';
      return;
    }
    // UI-C4: poradie boxov ciel = poradie ZOZNAMU CIEL (globalne `frontItems`,
    // ten isty payload, ktorym sa kreslia riadky v kontexte Čelá).
    var fis = (typeof frontItems !== 'undefined' && frontItems) ? frontItems : [];
    var frontIds = fis.map(function(f){ return f && f.id; });
    var groups = hwGroups(items, hwDisabledOffs(items, overrides), frontIds, cabId);
    var html = groups.map(function(g){ return hwBoxHtml(g, cabId); }).join('');
    if (!html) html = '<div class="muted">Skrinka nemá žiadne kovanie (bez čiel, bez podstavca).</div>';
    box.innerHTML = html;
    // V0.6 D1b: vyber setu per typ — override projektovej predvolby na CELEJ
    // skrinke. Kompaktne (vertikalny priestor): 1 riadok na pritomny typ.
    // D-75: riadok je aj pri PRAZDNEJ ponuke (server posiela len typy, ktore
    // skrinka naozaj ma) — inak by sa prvy novy set typu neobjavil hned, ale
    // az po novom vybere (zivy push obnovuje EXISTUJUCE selecty).
    if (!setBox) return;
    var sets = (setOptions || []).filter(function(o){ return !!o; }).map(function(o){
      return '<div class="hwrow hwsetrow"><span class="hwname">'+esc(o.label)
           + ' <span class="hwown">set</span></span>'
           + hwSetSelectHtml(hwCabOptionList(o), o.generic_type, '', cabId, hwCabTitle(o))
           + '</div>';
    }).join('');
    setBox.innerHTML = sets || '<div class="muted">Táto skrinka nemá kovanie, pre ktoré by sa dal vybrať set.</div>';
  }

  // ---- UI-C4: klik na hlavicku boxu = OZNAC VLASTNIKA V MODELI -------------
  // Ziadny zapis, ziadny krok Spat — je to zmena VYBERU (vzor „Dielcov" z
  // UI-B3). Panel po nej ZAMERNE ostava v Kovani (server nerobi push_selected),
  // aby box, z ktoreho pouzivatel klikol, nezmizol pod rukami.
  //
  // A prave preto TU NIE JE flush handshake, aky ma „Dielcov" (UI-B3) a
  // „Vložiť kópiu": ten existuje kvoli tomu, ze zmena vyberu si vypyta push
  // CELEJ skrinky, ktory prepise formular a rozpisany edit (400 ms debounce) by
  // sa ticho stratil. Tato cesta ziadny push nevyvola, takze nie je co chranit
  // — a flush by naopak odoslal rozpisanu hodnotu skor, nez ju pouzivatel
  // dopisal.
  function onHwOwnerPick(btn){
    var box = btn.closest ? btn.closest('.hwbox') : null;
    if (!box) return;
    var raw = box.getAttribute('data-keys') || '';
    var keys = raw ? raw.split(',').filter(function(k){ return k !== ''; }) : [];
    hwFlash(box);
    if (window.sketchup && sketchup.nx_select_hw_owner){
      sketchup.nx_select_hw_owner(JSON.stringify({
        model_guid: (typeof nxModelGuid === 'string') ? nxModelGuid : '',
        cabinet_id: btn.getAttribute('data-cab') || '',
        part_keys: keys }));
    }
  }
  // Kratke prisvietenie ciela skoku — bez neho pouzivatel po skoku hlada, KTORY
  // box je ten jeho (poloziek kovania byva viac, nez sa zmesti na obraz).
  function hwFlash(target){
    if (!target || !target.classList) return;
    target.classList.add('hwfocus');
    setTimeout(function(){ target.classList.remove('hwfocus'); }, 1600);
  }
  // Box vlastnika podla owner_part_key (klik na znacku v nahlade). Vracia uzol
  // alebo null.
  function hwBoxOf(owner){ return hwBoxByGroup(hwGroupKeyOf(owner)); }
  function hwBoxByGroup(key){
    var box = el('hwRows'); if (!box || !key) return null;
    return box.querySelector('.hwbox[data-group="' + cssEsc(key) + '"]');
  }
  // Kluc boxu jedneho CELA — jedine miesto, ktorym sa na box cela odkazuju iné
  // sekcie (preklik „naviazané kovanie" z kontextu Čelá, UI-C3).
  function hwFrontGroup(fid){ return 'front:' + String(fid == null ? '' : fid); }
  // UI-C4: klik na ZNACKU KOVANIA v nahlade. Dve veci naraz — vlastnik sa
  // oznaci v modeli a jeho box sa dotiahne do pohladu a prisvieti.
  function nxHwMarkPick(owner, tip){
    var box = hwBoxOf(owner);
    if (!box){ NX.setStatus(tip || '', false); return; }
    if (typeof nxRevealTarget === 'function') nxRevealTarget(box);
    box.scrollIntoView({ block: 'nearest' });
    var head = box.querySelector('.hwboxh');
    if (head) onHwOwnerPick(head); else hwFlash(box);
  }
  // OBOJSMERNE prepojenie box <-> znacka. Zvyraznenie je CSS trieda `hov` nad
  // UZ VYKRESLENYM SVG a nad boxom (renderPreview sa pocas hoveru NEVOLA —
  // lekcia D-23), takze nulova cena; obe strany zapina JEDNA funkcia, aby sa
  // smery nemohli rozist (vzor setFrontHover/clearFrontHover z D-23).
  var hwHoverKey = null;
  function hwSetHover(groupKey){
    if (!groupKey || groupKey === hwHoverKey) return; // presun v ramci ciela = ziadne blikanie
    hwClearHover();
    hwHoverKey = groupKey;
    hwPaintHover(groupKey, true);
  }
  function hwClearHover(){
    if (hwHoverKey == null) return;
    hwPaintHover(hwHoverKey, false);
    hwHoverKey = null;
  }
  function hwPaintHover(groupKey, on){
    var svg = el('preview');
    if (svg){
      var gs = svg.querySelectorAll('g.hwmk');
      for (var i = 0; i < gs.length; i++){
        if (hwGroupKeyOf(gs[i].getAttribute('data-owner') || '') !== groupKey) continue;
        if (on) gs[i].classList.add('hov'); else gs[i].classList.remove('hov');
      }
    }
    var b = hwBoxByGroup(groupKey);
    if (!b) return;
    if (on) b.classList.add('hov'); else b.classList.remove('hov');
  }
  // Druha strana synku pre nahlad: prevod znacky na kluc skupiny. Nahlad o
  // konvencii boxov nevie — pyta sa TEJTO funkcie (jedno miesto pravdy).
  function hwHoverByOwner(owner){ hwSetHover(hwGroupKeyOf(owner)); }
  function bindHwOwnerHover(){
    var box = el('hwRows'); if (!box || box.dataset.hwHoverBound === '1') return;
    // Delegacia na STATICKOM kontajneri — boxy sa prestavuju pri kazdom pushi.
    box.addEventListener('mouseover', function(ev){
      var b = hwBoxFrom(ev.target); if (b) hwSetHover(b.getAttribute('data-group'));
    });
    box.addEventListener('mouseout', function(ev){
      var b = hwBoxFrom(ev.target); if (!b) return;
      if (ev.relatedTarget && hwBoxFrom(ev.relatedTarget) === b) return;
      hwClearHover();
    });
    box.dataset.hwHoverBound = '1';
  }
  function hwBoxFrom(node){
    var n = node;
    while (n && n !== document){
      if (n.classList && n.classList.contains('hwbox')) return n;
      n = n.parentNode;
    }
    return null;
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

  // D-93: select dlzky + zamok v TOM ISTOM riadku (vertikalny priestor).
  function hwNlHtml(nl){
    var opts = '';
    hwNlOptionList(nl).forEach(function(o){
      opts += '<option value="'+esc(o.value)+'"'+(o.selected?' selected':'')+'>'+esc(o.text)+'</option>';
    });
    var locked = nl.locked === true;
    return '<select class="hwnlsel'+(locked?' manual':'')+'" title="'+esc(hwNlSelectTitle(nl))+'"'
         + ' aria-label="Nominálna dĺžka výsuvu" onchange="onHwNl(this)">'+opts+'</select>'
         + '<button class="ghostbtn hwbtn hwlock'+(locked?' on':'')+'" aria-pressed="'+(locked?'true':'false')+'"'
         + ' aria-label="'+(locked?'Odomknúť dĺžku výsuvu':'Zamknúť dĺžku výsuvu')+'"'
         + ' title="'+esc(hwNlLockTitle(nl))+'" onclick="onHwLock(this)">'
         + NXIcons.svg(locked ? 'lock' : 'lock-open')+'</button>';
  }

  function hwPayload(node, extra){
    var row = node.closest('.hwrow');
    var out = { owner_part_key: row.dataset.owner || null,
                generic_type: row.dataset.type, rule_id: row.dataset.rule,
                cabinet_id: row.dataset.cab || '' }; // D-93 F6: identity guard
    for (var k in extra) out[k] = extra[k];
    return out;
  }
  function hwSend(payload){
    if (window.sketchup && sketchup.set_hardware_override)
      sketchup.set_hardware_override(JSON.stringify(payload));
  }
  // Zapis ide PO POLIACH (field + value; value null = zrus len toto pole) —
  // zmena dlzky nesmie zmazat rucny pocet a naopak.
  function onHwQty(inp){
    var q = parseInt(inp.value, 10);
    if (isNaN(q) || q < 1){ NX.setStatus('Počet musí byť aspoň 1 (alebo položku vypni).', true); return; }
    hwSend(hwPayload(inp, { field: 'quantity', value: q }));
  }
  function onHwDisable(btn){ hwSend(hwPayload(btn, { field: 'disabled', value: true })); }
  function onHwReset(btn){ hwSend(hwPayload(btn, { field: 'quantity', value: null })); }
  function onHwEnable(btn){ hwSend(hwPayload(btn, { field: 'disabled', value: null })); }
  function onHwNl(sel){
    var v = parseFloat(sel.value);
    if (isNaN(v)){ NX.setStatus('Neplatná dĺžka výsuvu.', true); return; }
    hwSend(hwPayload(sel, { field: 'nominal_length', value: v }));
  }
  // Zamknutý zámok odomyká; odomknutý zamkne PRÁVE ZOBRAZENÚ hodnotu.
  function onHwLock(btn){
    if (btn.getAttribute('aria-pressed') === 'true'){
      hwSend(hwPayload(btn, { field: 'nominal_length', value: null }));
      return;
    }
    var row = btn.closest('.hwrow');
    var sel = row ? row.querySelector('select.hwnlsel') : null;
    var v = sel ? parseFloat(sel.value) : NaN;
    if (isNaN(v)){ NX.setStatus('Vyber dĺžku výsuvu.', true); return; }
    hwSend(hwPayload(btn, { field: 'nominal_length', value: v }));
  }
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
      hwMemberText: hwMemberText, hwBuyLine: hwBuyLine, HW_NO_CATALOG: HW_NO_CATALOG,
      // D-93 rucny NL vysuvu (tests/js/test_d93_nl_override.js) — hwNlHtml a
      // hwPayload potrebuju globalne esc/NXIcons, test si ich podstrci.
      hwNlFmt: hwNlFmt, hwNlOptionList: hwNlOptionList, hwNlAutoText: hwNlAutoText,
      hwNlSelectTitle: hwNlSelectTitle, hwNlLockTitle: hwNlLockTitle,
      hwNlHtml: hwNlHtml, hwPayload: hwPayload,
      // UI-C4 boxy vlastnikov (tests/js/test_uic4_kovanie.js) — ciste skladanie
      // skupin z owner dat, ziadny DOM.
      hwGroupKeyOf: hwGroupKeyOf, hwLabelHead: hwLabelHead, hwLabelTail: hwLabelTail,
      hwRowOwnerText: hwRowOwnerText, hwGroupTitle: hwGroupTitle,
      hwGroupCountText: hwGroupCountText, hwGroupOrder: hwGroupOrder,
      hwGroups: hwGroups, hwDisabledOffs: hwDisabledOffs,
      HW_GROUP_CAB: HW_GROUP_CAB, HW_GROUP_INSIDE: HW_GROUP_INSIDE };
  }
