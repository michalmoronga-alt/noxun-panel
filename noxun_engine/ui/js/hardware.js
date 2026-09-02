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
    var manual = hwItemManual(it);
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
      // SMOKE PACK 1: nazov je jednoriadkovy s ellipsis, takze plny text MUSI
      // niest `title` — inak by sa orezany popis nedal precitat vobec.
      + '<span class="hwname" title="'+esc(hwLabel(ov.generic_type)+(full?' · '+full:'')+' · vypnuté')+'">'
      + esc(hwLabel(ov.generic_type))+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
      + ' <span class="hwext">vypnuté</span></span>'
      + '<button class="ghostbtn hwbtn" title="Obnoviť (platí pravidlo)" onclick="onHwEnable(this)">'+NXIcons.svg('rotate-ccw')+' obnoviť</button>'
      + '</div>';
  }
  // UI-C4: box vlastnika. Hlavicka je TLACIDLO (klavesnica aj citacka) a nesie
  // `data-keys` = part_key vlastnikov, ktore ma klik oznacit v modeli. Box sa
  // NEZBALUJE — exkluzivita skupin S4 na skratenie panela staci.
  function hwBoxHtml(g, cabId){
    // SMOKE PACK 1: podperky polic sa v boxe „Vnútro skrinky" zbalia pod JEDEN
    // suhrnny riadok (dat sa nedotyka — je to zoskupenie zobrazenia).
    var split = hwSplitShelfPins(g.key, g.items, g.offs);
    var grouped = split.pins.length + split.offs.length;
    var body = split.rest.map(function(it){ return hwItemHtml(it, cabId, g.key); }).join('')
             + (grouped ? hwShelfPinsHtml(split.pins, split.offs, cabId, g.key) : '')
             + split.restOffs.map(function(ov){ return hwOffHtml(ov, cabId, g.key); }).join('');
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

  // ---- SMOKE PACK 1: PODPERKY POLIC SUHRNNE (box „Vnútro skrinky") ---------
  // Michal 20.8.: pri piatich policiach zabrali podperky pat riadkov, hoci
  // hovoria to iste. Po novom je nad nimi JEDEN suhrnny riadok
  // („Podperky políc — 5 políc: 20 ks") s rozklikom, pod ktorym ziju POVODNE
  // riadky — editovatelnost poctu per polica teda OSTAVA, len je zbalena.
  //
  // Je to CISTE UI ZOSKUPENIE: identita polozky (owner_part_key, generic_type,
  // rule_id), zapisove cesty, nakupny riadok D-92 aj `refreshHardwarePurchase`
  // ostavaju nedotknute — riadky su len o uroven hlbsie v DOM a hladaju sa
  // (ako doteraz) selektorom, nie indexom deti.
  var HW_SHELF_PIN = 'shelf_pin';
  // Prah zoskupenia: JEDNA polica sa nezbaluje — rozklik nad jedinym riadkom
  // je klik navyse bez zisku (a suhrn by bol dlhsi nez to, co skryva).
  var HW_PINS_MIN = 2;

  // „Rucne" v zmysle D-93: server posiela `quantity_manual`, stary payload len
  // `source`. Vytiahnute z hwItemHtml, aby o tom istom rozhodovalo JEDNO miesto
  // (suhrn aj riadok) — a aby sa to dalo testovat bez DOM.
  function hwItemManual(it){
    if (!it) return false;
    return (it.quantity_manual != null) ? (it.quantity_manual === true) : (it.source === 'manual');
  }
  // Suhrn podperiek: kolko POLIC (riadkov) a kolko KUSOV spolu; `edited` = do
  // niektorej police niekto siahol rucne, takze suhrn nesmie tvrdit, ze je
  // vsetko podla pravidla. Ciste (Node testy).
  //
  // Codex #183 P2: rata sa AJ z `offs` — VYPNUTA polica je stale polica.
  // Bez toho by pri piatich policiach s jednou vypnutou suhrn tvrdil „4 police"
  // a piata by visela mimo rozkliku ako samostatny riadok. Vypnuta polica
  // prispieva 0 ks a VZDY zapina `edited` (vypnutie je rucny zasah).
  function hwShelfPinSummary(items, offs){
    var out = { rows: 0, total: 0, edited: false };
    (items || []).forEach(function(it){
      if (!it || it.generic_type !== HW_SHELF_PIN) return;
      out.rows++;
      var q = parseInt(it.quantity, 10);
      out.total += (isFinite(q) && q > 0) ? q : 0;
      if (hwItemManual(it)) out.edited = true;
    });
    (offs || []).forEach(function(ov){
      if (!ov || ov.generic_type !== HW_SHELF_PIN) return;
      out.rows++;
      out.edited = true;
    });
    return out;
  }
  function hwShelfCountText(n){
    var c = Math.max(0, parseInt(n, 10) || 0);
    if (c === 1) return '1 polica';
    if (c >= 2 && c <= 4) return c + ' police';
    return c + ' políc';
  }
  function hwShelfPinTitle(s){
    var d = s || { rows: 0, total: 0 };
    return 'Podperky políc — ' + hwShelfCountText(d.rows) + ': ' + (d.total || 0) + ' ks';
  }
  function hwShelfPinTip(s){
    var d = s || {};
    return hwShelfPinTitle(d) + (d.edited ? ' · niektorá polica má ručne upravený počet' : '')
         + ' — rozklikom upravíš počet pri konkrétnej polici';
  }
  // Stav rozkliku je vec POCITACA (localStorage), nie zakazky — rovnaky dovod
  // ako pri sektoroch a teme: Michal a Lucia otvaraju tie iste zakazky.
  // ZBALENY je default (chybajuci kluc = zbalene).
  var HW_PINS_KEY = 'nx_hw_shelfpins_open';
  function hwShelfPinsOpen(){
    try {
      return (typeof localStorage !== 'undefined') && localStorage.getItem(HW_PINS_KEY) === '1';
    } catch (e) { return false; }
  }
  function onHwGrpToggle(node){
    try {
      if (typeof localStorage !== 'undefined') localStorage.setItem(HW_PINS_KEY, node.open ? '1' : '0');
    } catch (e) { /* bez perzistencie — zbalenie funguje aj tak */ }
  }
  // `<details>` zamerne (nie vlastny prepinac): nxRevealTarget vie otvorit
  // ZBALENEHO predka pri deep-linku, takze skok na konkretnu policu ju v
  // buducnosti najde aj zbalenu.
  function hwShelfPinsHtml(pins, offs, cabId, groupKey){
    var s = hwShelfPinSummary(pins, offs);
    return '<details class="hwgrp" data-hwgrp="' + esc(HW_SHELF_PIN) + '"'
      + (hwShelfPinsOpen() ? ' open' : '') + ' ontoggle="onHwGrpToggle(this)">'
      + '<summary class="hwgrph" title="' + esc(hwShelfPinTip(s)) + '">'
      + NXIcons.svg('chevron-right')
      + '<span class="hwgrpt">' + esc(hwShelfPinTitle(s)) + '</span>'
      + (s.edited ? '<span class="hwgrpw">upravené</span>' : '')
      + '</summary><div class="hwgrpb">'
      + (pins || []).map(function(it){ return hwItemHtml(it, cabId, groupKey); }).join('')
      // Vypnuta polica patri POD ten isty rozklik ako zapnute — inak by suhrn
      // sluboval jeden celok a jedna polica by mu utiekla vedla (Codex #183 P2).
      + (offs || []).map(function(ov){ return hwOffHtml(ov, cabId, groupKey); }).join('')
      + '</div></details>';
  }
  // Rozdelenie obsahu boxu na „podperky" a „zvysok" — a to v OBOCH zoznamoch:
  // `items` (zive polozky) aj `offs` (vypnute kategorie), lebo vypnuta polica
  // je stale polica. Ciste (Node testy): zoskupuje sa VYHRADNE v boxe Vnútro
  // a az od HW_PINS_MIN polic SPOLU.
  // -> { pins: [], offs: [], rest: [], restOffs: [] }
  //    (pri nezoskupeni su vsetky v `rest` / `restOffs`)
  function hwSplitShelfPins(groupKey, items, offs){
    var inside = (groupKey === HW_GROUP_INSIDE);
    var pins = [], rest = [], pinOffs = [], restOffs = [];
    (items || []).forEach(function(it){
      if (inside && it && it.generic_type === HW_SHELF_PIN) pins.push(it);
      else rest.push(it);
    });
    (offs || []).forEach(function(ov){
      if (inside && ov && ov.generic_type === HW_SHELF_PIN) pinOffs.push(ov);
      else restOffs.push(ov);
    });
    if (pins.length + pinOffs.length < HW_PINS_MIN){
      return { pins: [], offs: [], rest: (items || []).slice(), restOffs: (offs || []).slice() };
    }
    return { pins: pins, offs: pinOffs, rest: rest, restOffs: restOffs };
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
    // KOV-H2: pod boxmi vlastnikov ziju RUCNE PRIDANE polozky (ad-hoc kovanie
    // mimo setov) + tlacidlo na pridanie. Su to INE data (`hardware_manual`,
    // nie `config.hardware`), preto vlastny blok a nie box vlastnika — a preto
    // ho `hwGroups` ani `refreshHardwarePurchase` nevidia.
    box.innerHTML = html + hwManualHtml();
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
  // FLUSH HANDSHAKE (Codex #179 P2, kolo 4) — rovnaky ako ma „Dielcov"
  // (`onInfoParts`) a „Vložiť kópiu", ale z INEHO dovodu: nie kvoli prepisaniu
  // formulara (tato cesta ziadny push nevyvola), ale kvoli VYBERU. Rozpisany
  // edit caka 400 ms; keby timer dobehol AZ PO nasom vybere, `handle_apply_all`
  // by skrinku prestaval a `finish_cab` by reselectol CELY korpus — vlastnik,
  // ktoreho si pouzivatel prave klikol, by sa ticho stratil. Preto sa edit
  // odosle EST PRED vyberom (callbacky sa spracuju v poradi odoslania) a
  // NEPLATNE pole akciu ZASTAVI (flush by ju aj tak neaplikoval).
  function onHwOwnerPick(btn){
    var box = btn.closest ? btn.closest('.hwbox') : null;
    if (!box) return;
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — rozpísaná úprava by sa pri označení vlastníka stratila.', true);
      return;
    }
    if (typeof flushCabinetEditsNow === 'function') flushCabinetEditsNow();
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
      sketchup.set_hardware_set(nxDocPayload({ generic_type: sel.getAttribute('data-gt'),
                                               owner_part_key: sel.getAttribute('data-owner') || null,
                                               set_id: sel.value,
                                               cabinet_id: sel.getAttribute('data-cab') || '' })); // GH #127 P2 + R-02
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
    // R-02: identita dokumentu (echo `cabinet_id` z hwPayload prepnutie
    // dokumentu nezachyti — CAB-001 je v kazdej zakazke).
    if (window.sketchup && sketchup.set_hardware_override)
      sketchup.set_hardware_override(nxDocPayload(payload));
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
  // ŠT-3b-1: `openRulesDialog` ZANIKOL spolu s oknom „Pravidlá kovania" —
  // tlacidlo panela ide priamo deep-linkom `openStudio('rules')`.
  // ŠT-3a-2: `openHardwareCatalogDialog` ZANIKOL spolu s oknom „Katalóg
  // kovania" — tlacidlo panela ide priamo deep-linkom `openStudio('hw')`
  // (`js/actions.js`), rovnako ako „Materiály projektu…" od ŠT-2b.

  // ====================== KOV-H2: RUCNE PRIDANE POLOZKY =====================
  // Ad-hoc kovanie = KONKRETNA polozka MIMO setov, pripnuta ku skrinke alebo
  // k jednemu dielcu (datova vrstva je KOV-H1). Panel ju vie pridat, upravit
  // a zmazat — a to VZDY TOU ISTOU cestou ako kazdu inu zmenu skrinky:
  //   `hwManual` (echo servera) -> novy zoznam -> `collectAll()` -> `apply_all`
  // Ziadny novy zapisovy kanal, ziadny druhy tvar payloadu, 1 zmena = 1 krok
  // Spat (KOV-H1 audit #15 BLOCKER 1).
  //
  // CO PANEL NEROBI: nepocita ceny, neskladá popisky vlastnika a neoveruje
  // katalog. To vsetko je v payloade zo servera (`hardware_manual_view`,
  // `hardware_manual_owners`) — panel kresli, co dostal. Do configu sa
  // z obrazovky vracia LEN to, co si pouzivatel naozaj vybral: kod (pri
  // katalogovej polozke) alebo nazov/MJ/cena (pri volnej).

  // MJ su ZRKADLO serverovej `HardwareCatalog::UNITS` (jediny slovnik jednotiek).
  // Vedome NIE v payloade: menia sa raz za rok a kazdy push vyberu by ich niesol
  // zbytocne. Ze sa nerozidu, strazi guard `tests/pure/test_kovh2_payload.rb`.
  var HW_MANUAL_UNITS = [['ks', 'ks'], ['set', 'sada'], ['par', 'pár'],
                         ['bal', 'balenie'], ['m', 'bm (bežný meter)']];
  var HW_MANUAL_QTY_MAX = 999;    // zrkadlo CabinetBuilder::MANUAL_QTY_MAX
  var HW_MANUAL_NOTE_MAX = 200;   // zrkadlo CabinetBuilder::MANUAL_NOTE_MAX

  // Stav OTVORENEHO modalu: { id: '<id polozky>' | null, kind: 'add'|'edit',
  // sent: odoslali sme z neho zapis? }. `null` = ziadny nas modal nebezi.
  var HW_MAN = null;
  // Generacia hladania (odpoved so starsou generaciou sa zahadzuje) + callback
  // kostry, ktoremu vysledok patri.
  var HW_MAN_Q = { gen: 0, done: null };
  // TOKEN ODOSLANEJ OPERACIE (Codex #285 P2-A). Korelovat odpoved podla `kind`
  // nestaci: VSETKY `add` maju prazdne `id`, takze pri pomalej prestavbe
  // (pouzivatel medzitym zavrie modal a posle dalsiu operaciu toho isteho
  // druhu) by sa odpoved na A priradila k B — zavrela by cudzi modal a zahodila
  // jeho draft, alebo by ukazala cudzie odmietnutie. Kazde odoslanie ma preto
  // VLASTNY rastuci token; server ho vracia v echu a klient porovnava JEHO.
  var HW_MAN_SEQ = 0;
  function hwManualToken(){ HW_MAN_SEQ += 1; return 'h' + HW_MAN_SEQ; }

  function hwManualUnitLabel(u){
    var v = String(u == null ? '' : u);
    for (var i = 0; i < HW_MANUAL_UNITS.length; i++){
      if (HW_MANUAL_UNITS[i][0] === v) return HW_MANUAL_UNITS[i][1];
    }
    return v || 'ks';   // MJ z novsej verzie sa NEPREKLADA, ale ani nezahadzuje
  }
  // Cislo s desatinnou CIARKOU (slovensky zapis) — 2 desatiny, nikdy 0 miesto
  // „nezadana" (standard §11.3: nezadana cena je pomlcka, nie nula).
  function hwManualNum(v){
    var f = Number(v);
    if (v == null || !isFinite(f)) return '';
    return f.toFixed(2).replace('.', ',');
  }
  function hwManualPriceText(v){
    var s = hwManualNum(v);
    return s === '' ? '—' : (s + ' €');
  }
  // Vlastnik do vety. Popis sklada SERVER (`PartKeys.human_label`); prazdny
  // = polozka patri celej skrinke.
  function hwManualOwnerText(it){
    var l = String((it && it.owner_label) || '');
    return l === '' ? 'celá skrinka' : l;
  }
  function hwManualName(it){
    var n = String((it && it.name) || '').trim();
    if (n !== '') return n;
    var c = String((it && it.code) || '').trim();
    return c !== '' ? c : 'bez názvu';
  }
  // Chipy riadku. „ručná" je VZDY (je to jediny rozdiel oproti polozke
  // z pravidiel), zvysne dva su STAVY, ktore treba priznat.
  // -> [{ text, title, warn }]
  function hwManualChips(it){
    var out = [{ text: 'ručná', title: 'Pridané ručne — mimo setov a pravidiel', warn: false }];
    if (it && it.owner_missing === true){
      out.push({ text: 'bez vlastníka',
                 title: 'Dielec, ku ktorému bola pripnutá, už neexistuje — položka ostáva v nákupe',
                 warn: true });
    }
    if (it && it.catalog_missing === true){
      out.push({ text: 'chýba v katalógu',
                 title: 'Kód už nie je v katalógu kovania — v nákupe ostáva bez ceny',
                 warn: true });
    }
    return out;
  }
  function hwManualQtyText(it){
    var q = parseInt(it && it.qty, 10);
    return (isFinite(q) ? q : 0) + ' ' + hwManualUnitLabel(it && it.unit);
  }
  // Sekundarny riadok (vzor D-92 `.hwbuy`): kod · cena/MJ · patri · poznamka.
  function hwManualBuyText(it){
    var d = it || {};
    var parts = [];
    parts.push(d.source === 'free' ? 'voľná položka' : (String(d.code || '') || 'bez kódu'));
    parts.push(hwManualPriceText(d.price_eur_vat) + ' / ' + hwManualUnitLabel(d.unit));
    parts.push('patrí: ' + hwManualOwnerText(d));
    var note = String(d.note || '').trim();
    if (note !== '') parts.push('pozn.: ' + note);
    return parts.join(' · ');
  }
  function hwManualTitle(it){
    return hwManualName(it) + ' · ' + hwManualQtyText(it) + ' · ' + hwManualBuyText(it);
  }

  function hwManualItemHtml(it){
    var id = esc(String((it && it.id) || ''));
    var chips = hwManualChips(it).map(function(c){
      return ' <span class="hwchip' + (c.warn ? ' warn' : '') + '" title="' + esc(c.title) + '">'
           + esc(c.text) + '</span>';
    }).join('');
    var buy = hwManualBuyText(it);
    return '<div class="hwitem hwman-item" data-manid="' + id + '">'
      // `.hwrow` = ta ista geometria ako riadok polozky z pravidiel; identitne
      // atributy (data-owner/type/rule) tu ZAMERNE NIE SU — ad-hoc polozka
      // ziadne pravidlo nema a `refreshHardwarePurchase` ju hladat nesmie.
      + '<div class="hwrow hwman-row">'
      + '<span class="hwname" title="' + esc(hwManualTitle(it)) + '">'
      + esc(hwManualName(it)) + chips + '</span>'
      + '<span class="hwman-qty">' + esc(hwManualQtyText(it)) + '</span>'
      + '<button type="button" class="ghostbtn hwbtn" data-id="' + id + '"'
      + ' title="Upraviť ručnú položku" aria-label="Upraviť ručnú položku"'
      + ' onclick="onHwManualEdit(this)">' + NXIcons.svg('pencil') + '</button>'
      + '<button type="button" class="ghostbtn hwbtn" data-id="' + id + '"'
      + ' title="Odstrániť ručnú položku (Ctrl+Z ju vráti)" aria-label="Odstrániť ručnú položku"'
      + ' onclick="onHwManualDel(this)">' + NXIcons.svg('trash') + '</button>'
      + '</div>'
      + '<div class="hwbuy' + ((it && (it.owner_missing || it.catalog_missing)) ? ' hwbuy-warn' : '')
      + '" title="' + esc(buy) + '">' + esc(buy) + '</div>'
      + '</div>';
  }

  // Cely blok. Nadpis je LEN ked su polozky (prazdny nadpis nad tlacidlom by
  // zabral riadok a nepovedal nic — vertikalny priestor panela je vzacny).
  function hwManualHtml(list){
    var items = list || ((typeof hwManualView !== 'undefined' && hwManualView) ? hwManualView : []);
    var rows = items.map(hwManualItemHtml).join('');
    return '<div class="hwman" id="hwManBlock">'
      + (rows ? '<div class="hwmanh">Ručne pridané</div>' + rows : '')
      + '<div class="hwmanadd"><button type="button" class="ghostbtn hwmanbtn"'
      + ' title="Konkrétna položka mimo setov — pripne sa ku skrinke alebo k dielcu"'
      + ' onclick="onHwManualAdd()">' + NXIcons.svg('plus')
      + ' Pridať konkrétnu položku (mimo setov)</button></div></div>';
  }

  // ---- modal (D-15 kostra) -------------------------------------------------
  function hwManualFind(id){
    var list = (typeof hwManualView !== 'undefined' && hwManualView) ? hwManualView : [];
    for (var i = 0; i < list.length; i++){
      if (String(list[i].id) === String(id)) return list[i];
    }
    return null;
  }
  // Ponuka „Patrí k". Vlastnik, ktory uz v plane NIE JE (zmenena konstrukcia),
  // sa PRIZNA ako doplnena volba — inak by select klamal a uprava polozky by
  // ju ticho prepla na celu skrinku (vzor `hwSetOptionList`).
  function hwManualOwnerOptions(owners, current){
    var cur = String(current == null ? '' : current);
    var out = [];
    var found = false;
    (owners || []).forEach(function(o){
      if (!o) return;
      var k = String(o.key == null ? '' : o.key);
      if (k === cur) found = true;
      out.push([k, String(o.label || (k === '' ? 'celá skrinka' : k))]);
    });
    if (!out.length) out.push(['', 'celá skrinka']);
    if (cur !== '' && !found) out.push([cur, cur + ' (dielec už neexistuje)']);
    return out;
  }
  // Text vybranej katalogovej polozky do pola hladania.
  function hwManualItemText(it){
    var code = String((it && it.code) || '');
    var name = String((it && it.name) || '');
    if (code === '') return name;
    return name === '' ? code : (code + ' · ' + name);
  }
  // Hodnoty formulara pre polozku (alebo prazdny formular pri pridavani).
  function hwManualDraft(it){
    if (!it){
      return { owner: '', source: 'catalog', code: '', code_text: '',
               name: '', unit: 'ks', price: '', qty: '1', note: '' };
    }
    var free = it.source === 'free';
    return { owner: String(it.owner_part_key || ''),
             source: free ? 'free' : 'catalog',
             code: String(it.code || ''),
             code_text: hwManualItemText(it),
             name: free ? String(it.name || '') : '',
             unit: String(it.unit || 'ks'),
             price: free ? hwManualNum(it.price_eur_vat) : '',
             qty: String(it.qty == null ? 1 : it.qty),
             note: String(it.note || '') };
  }
  // Polia modalu. KONTEXTOVE: pri katalogovej polozke sa pyta KOD, pri volnej
  // nazov/MJ/cena. Cena KATALOGOVEJ polozky sa needituje ani neposiela —
  // oceni ju zivy katalog (KOV-H1 BLOCKER 2), takze je to len informacia
  // pod polom (vedoma odchylka od mockupu, ktory mal „Cena s DPH (snapshot)").
  // CISTA funkcia (Node testy).
  function hwManualFields(owners, draft){
    var v = draft || hwManualDraft(null);
    var src = (v.source === 'free') ? 'free' : 'catalog';
    var out = [
      { key: 'owner', label: 'Patrí k', type: 'select', value: String(v.owner || ''),
        options: hwManualOwnerOptions(owners, v.owner),
        hint: 'vo výrobe aj v nákupe bude vidieť, kam patrí' },
      { key: 'source', label: 'Zdroj', type: 'select', value: src,
        options: [['catalog', 'Z katalógu'], ['free', 'Voľná položka']] }
    ];
    if (src === 'catalog'){
      out.push({ key: 'code', label: 'Položka katalógu', type: 'lookup',
                 placeholder: 'kód alebo názov (napr. 93240 alebo uholník)',
                 value: String(v.code || ''), valueText: String(v.code_text || ''),
                 hintText: 'Cenu aj názov drží katalóg — do zákazky sa neukladajú.',
                 search: hwManualSearch });
    } else {
      out.push({ key: 'name', label: 'Názov', value: String(v.name || ''),
                 placeholder: 'napr. zámok Abloy' });
      out.push({ key: 'unit', label: 'MJ', type: 'select', cls: 'mshort',
                 value: String(v.unit || 'ks'), options: HW_MANUAL_UNITS });
      out.push({ key: 'price', label: 'Cena s DPH', cls: 'mshort',
                 value: String(v.price || ''), placeholder: '0,00',
                 hint: '€ za MJ · prázdne = bez ceny' });
    }
    out.push({ key: 'qty', label: 'Množstvo', cls: 'mshort', value: String(v.qty || '1'),
               hint: 'celé číslo 1 – ' + HW_MANUAL_QTY_MAX });
    out.push({ key: 'note', label: 'Poznámka', value: String(v.note || ''),
               placeholder: 'nepovinné — napr. podľa priania zákazníka' });
    return out;
  }

  // Hladanie v katalogu = SERVEROVA cesta (`hw_manual_search`). Panel poradie
  // NESKLADA — kresli, co pride.
  function hwManualSearch(query, done){
    HW_MAN_Q.gen++;
    HW_MAN_Q.done = done;
    if (!(window.sketchup && sketchup.hw_manual_search)){ done([], 0); return; }
    sketchup.hw_manual_search(JSON.stringify({ q: String(query == null ? '' : query),
                                               gen: HW_MAN_Q.gen }));
  }
  // Jedna polozka katalogu do tvaru, ktoremu rozumie kostra (`lookup`).
  function hwManualHit(i){
    var d = i || {};
    var code = String(d.code || '');
    var name = String(d.name_sk || '');
    var price = (d.price_eur_vat == null)
      ? 'cena nezadaná'
      : (hwManualPriceText(d.price_eur_vat) + ' s DPH / ' + hwManualUnitLabel(d.unit));
    return { value: code,
             text: (code === '' ? name : (name === '' ? code : code + ' · ' + name)),
             hint: price + ' · katalóg' + (d.category ? ' · ' + d.category : '') };
  }
  // Odpoved servera. STARSIA GENERACIA sa zahadzuje — odpovede chodia
  // asynchronne a pomalsie kolo by prepisalo cerstvejsie vysledky.
  function hwManualSearchResult(res){
    var r = res || {};
    if (Number(r.gen) !== HW_MAN_Q.gen) return;
    var done = HW_MAN_Q.done;
    if (typeof done !== 'function') return;
    done((r.items || []).map(hwManualHit), Number(r.total || 0));
  }

  function hwManualOpen(item, draft){
    if (typeof NXModal === 'undefined' || !NXModal || typeof NXModal.open !== 'function') return;
    var owners = (typeof hwManualOwners !== 'undefined' && hwManualOwners) ? hwManualOwners : [];
    HW_MAN = { id: item ? String(item.id) : null, kind: item ? 'edit' : 'add', sent: false };
    NXModal.open({
      title: item ? 'Upraviť ručnú položku' : 'Pridať konkrétnu položku (mimo setov)',
      sub: 'mimo setov — ide rovno do nákupu',
      size: 'md',
      okLabel: item ? 'Uložiť' : 'Pridať',
      // Konvencia kluca `<okno/domena>:<mode>[:<ciel>]` — `hw:manual:edit:<id>`
      // sa deli o jeden slot, takze otvorenie INEJ polozky stary rozpis zahodi.
      memoryKey: item ? ('hw:manual:edit:' + item.id) : 'hw:manual:add',
      note: 'Položka ide priamo do nákupu a rozpočtu. Katalógovú ocení živý katalóg — ' +
            'jej cena sa do zákazky neukladá.',
      fields: hwManualFields(owners, draft || hwManualDraft(item)),
      onSubmit: function(v){ hwManualSubmit(v, item); }
    });
  }
  function onHwManualAdd(){ hwManualOpen(null, null); }
  function onHwManualEdit(btn){
    var it = hwManualFind(btn.getAttribute('data-id'));
    if (!it){ NX.setStatus('Položka sa medzitým zmenila — panel sa obnovil.', true); return; }
    hwManualOpen(it, null);
  }
  // Prepnutie „Zdroj" meni SADU POLI, a tu kostra D-15 za behu nevymiena —
  // modal sa preto otvori znova s TYM, CO UZ POUZIVATEL NAPISAL (hodnoty
  // nesie draft, nie pamat: pamat by sa spoliehala na porovnanie s defaultmi).
  function hwManualCtxSwitch(){
    if (!HW_MAN || typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
    if (NXModal.isBusy && NXModal.isBusy()) return;   // bezi zapis — nesahat
    var v = NXModal.values() || {};
    var item = HW_MAN.id ? hwManualFind(HW_MAN.id) : null;
    var d = hwManualDraft(item);
    d.owner = String(v.owner == null ? d.owner : v.owner);
    d.source = (v.source === 'free') ? 'free' : 'catalog';
    d.qty = String(v.qty == null ? d.qty : v.qty);
    d.note = String(v.note == null ? d.note : v.note);
    if (v.code != null) d.code = String(v.code);
    if (v.name != null) d.name = String(v.name);
    if (v.unit != null) d.unit = String(v.unit);
    if (v.price != null) d.price = String(v.price);
    hwManualOpen(item, d);
  }
  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.getAttribute('data-nxm') !== 'source') return;
      hwManualCtxSwitch();
    });
  }

  // ---- validacia a zapis ---------------------------------------------------
  // Klient strazi LEN povinne polia a format. AUTORITA je server
  // (`manual_preflight`): vlastnik musi existovat v plane, kod v katalogu.
  // CISTA funkcia (Node testy) -> [] | [{ field, msg }]
  function hwManualValidate(v){
    var d = v || {};
    var out = [];
    var free = d.source === 'free';
    if (free){
      if (String(d.name || '').trim() === ''){
        out.push({ field: 'name', msg: 'Voľná položka musí mať názov.' });
      }
      if (hwManualParsePrice(d.price) === false){
        out.push({ field: 'price', msg: 'Cena musí byť nezáporné číslo (alebo prázdna).' });
      }
    } else if (String(d.code || '').trim() === ''){
      out.push({ field: 'code', msg: 'Vyber položku z katalógu — alebo prepni Zdroj na voľnú položku.' });
    }
    var q = String(d.qty == null ? '' : d.qty).trim();
    var n = /^\d+$/.test(q) ? parseInt(q, 10) : NaN;
    if (!isFinite(n) || n < 1 || n > HW_MANUAL_QTY_MAX){
      out.push({ field: 'qty', msg: 'Množstvo musí byť celé číslo 1 až ' + HW_MANUAL_QTY_MAX + '.' });
    }
    if (String(d.note || '').length > HW_MANUAL_NOTE_MAX){
      out.push({ field: 'note', msg: 'Poznámka je dlhšia než ' + HW_MANUAL_NOTE_MAX + ' znakov.' });
    }
    return out;
  }
  // -> null (prazdne = bez ceny) | Number | false (nezmysel)
  function hwManualParsePrice(raw){
    var s = String(raw == null ? '' : raw).trim().replace(',', '.');
    if (s === '') return null;
    if (!/^\d+(\.\d+)?$/.test(s)) return false;
    var f = parseFloat(s);
    return (isFinite(f) && f >= 0) ? f : false;
  }
  // Zaznam do configu. Pri KATALOGOVEJ polozke ide LEN kod (KOV-H1 FIX 12:
  // klientovi sa veri len kod — nazov, MJ aj cenu dopĺňa server z katalogu).
  // `id` je pri pridavani PRAZDNE: prideluje ho server (`norm_hardware_manual`).
  // CISTA funkcia (Node testy).
  function hwManualRecord(v, item){
    var d = v || {};
    var free = d.source === 'free';
    var rec = { id: item ? String(item.id) : '',
                owner_part_key: (String(d.owner || '') === '') ? null : String(d.owner),
                source: free ? 'free' : 'catalog',
                qty: parseInt(String(d.qty || '').trim(), 10),
                note: String(d.note == null ? '' : d.note) };
    if (free){
      rec.name = String(d.name || '').trim();
      rec.unit = String(d.unit || 'ks');
      var p = hwManualParsePrice(d.price);
      if (typeof p === 'number') rec.price_eur_vat = p;
    } else {
      rec.code = String(d.code || '').trim();
    }
    return rec;
  }
  // Novy CELY zoznam (panel posiela echo, nie diff). `null` = operacia sa
  // nedala vykonat (polozka v zozname nie je) — TICHY append by z upravy
  // spravil duplikat. CISTA funkcia (Node testy).
  function hwManualNextList(list, rec, op){
    var kind = (op || {}).kind;
    var id = String((op || {}).id || '');
    var out = [];
    var hit = false;
    (list || []).forEach(function(x){
      var xid = String((x && x.id) || '');
      if (id !== '' && xid === id){
        hit = true;
        if (kind === 'delete') return;
        if (kind === 'edit'){ out.push(rec); return; }
      }
      out.push(x);
    });
    if (kind === 'add'){ out.push(rec); return out; }
    return hit ? out : null;
  }

  function hwManualSend(next, op){
    // Cervene pole formulara by zapis aj tak zastavilo v `flushCabinetEdits` —
    // tu sa zastavi SKOR, aby sa modal nezamkol nad zapisom, ktory neodide.
    if (typeof validateFields === 'function' && !validateFields()){
      NX.setStatus('Skontroluj červené polia — kým sú v poriadku, položka sa neuloží.', true);
      return false;
    }
    // Rozpisany edit formulara ide S NAMI v tom istom payloade (`collectAll`),
    // takze cakajuci debounce sa RUSI — samostatny flush by znamenal DVA
    // rebuildy a dva kroky Spat pre jednu zmenu.
    if (typeof cancelCabinetEdits === 'function') cancelCabinetEdits();
    hwManual = next;
    var payload = collectAll();
    payload.cabinet_id = selectedCabId;
    payload.manual_op = op;
    cabEditsInFlight = true; // echo tohto apply nesmie prepisat novsi vstup
    if (window.sketchup && sketchup.apply_all) sketchup.apply_all(nxDocPayload(payload));
    return true;
  }

  function hwManualSubmit(values, item){
    var errs = hwManualValidate(values);
    if (errs.length){ NXModal.showErrors(errs); NXModal.setBusy(false); return; }
    if (!Array.isArray(hwManual)){
      // `|| []` je zakazane: „o polozkach neviem" nie je „polozky nie su".
      NXModal.showErrors([{ msg: 'Panel nemá zoznam ručných položiek — označ skrinku znova.' }]);
      NXModal.setBusy(false);
      return;
    }
    var op = { kind: item ? 'edit' : 'add', id: item ? String(item.id) : '',
               token: hwManualToken() };
    var next = hwManualNextList(hwManual, hwManualRecord(values, item), op);
    if (!next){
      NXModal.showErrors([{ msg: 'Položka sa medzitým zmenila — zavri okno a skús znova.' }]);
      NXModal.setBusy(false);
      return;
    }
    NXModal.clearErrors();
    if (!hwManualSend(next, op)){ NXModal.setBusy(false); return; }
    if (HW_MAN){ HW_MAN.sent = true; HW_MAN.token = op.token; }
  }

  // Mazanie ide BEZ potvrdzovacieho okna — poistka je JEDEN krok Spat (vzor
  // „Vrátiť na pravidlo"); potvrdzovacie okno pri kazdom mazani by bolo klik
  // navyse pri kazdej oprave. Status povie, CO sa odstranilo.
  function onHwManualDel(btn){
    var it = hwManualFind(btn.getAttribute('data-id'));
    if (!it){ NX.setStatus('Položka sa medzitým zmenila — panel sa obnovil.', true); return; }
    if (!Array.isArray(hwManual)){
      NX.setStatus('Panel nemá zoznam ručných položiek — označ skrinku znova.', true);
      return;
    }
    var op = { kind: 'delete', id: String(it.id), token: hwManualToken() };
    var next = hwManualNextList(hwManual, null, op);
    if (!next){ NX.setStatus('Položka sa medzitým zmenila — panel sa obnovil.', true); return; }
    hwManualSend(next, op);
  }

  // ---- ZATVORENIE MODALU PRI ZMENE IDENTITY (Codex #285 P1) ---------------
  // Modal drzi ROZPISANY zoznam JEDNEJ skrinky. Ked sa pod nim zmeni vyber
  // (ina skrinka, iny dokument, doska, prazdny vyber), `loadSelected` vymeni
  // `hwManual`/`hwManualView`/`hwManualOwners` aj `selectedCabId` — a odoslanie
  // stareho formulara by potom postavilo zoznam z NOVEJ skrinky a orazitkovalo
  // ho JEJ identitou. Polozka by pristala na nespravnej skrinke a pri zhode
  // `id` by dokonca PREPISALA cudzi zaznam.
  //
  // Zatvara sa preto VYHRADNE pri zmene IDENTITY. Echo TEJ ISTEJ skrinky (nas
  // vlastny apply, na ktory modal prave caka) modal zatvorit NESMIE — inak by
  // sa zavrel skor, nez by prisla odpoved, ktoru drzi otvoreny.
  function hwManualDropModal(reason){
    var open = (typeof NXModal !== 'undefined' && NXModal &&
                typeof NXModal.isOpen === 'function' && NXModal.isOpen());
    if (!HW_MAN && !open) return false;
    HW_MAN = null;
    HW_MAN_Q.gen++;      // bezuce hladanie uz nema komu odpovedat
    HW_MAN_Q.done = null;
    if (open && typeof NXModal.close === 'function') NXModal.close();
    if (reason && typeof NX !== 'undefined' && NX && NX.setStatus) NX.setStatus(reason, true);
    return true;
  }
  // Dovod je JEDEN text (JS ho nesklada z kusov) — pouzivatel musi vediet, ze
  // sa nic neulozilo, inak by cakal, ze polozka pribudla.
  var HW_MAN_DROP_SK = 'Výber sa zmenil — okno ručnej položky sa zavrelo, nič sa neuložilo.';

  // ROZHODNUTIE „je to iny vyber?" zije TU, nie v `bridge.js` — modal patri
  // tomuto suboru a podmienka sa nesmie rozist s tym, co modal drzi.
  // `sameDoc` dodava volajuci (identitu dokumentu pozna push), `cabId` je
  // skrinka CERSTVEHO payloadu. -> true = modal sa zavrel.
  function hwManualDropIfForeign(cabId, sameDoc){
    if (sameDoc === true && String(cabId == null ? '' : cabId) === String(selectedCabId || '')){
      return false;   // ECHO tej istej skrinky — modal caka prave na nu
    }
    return hwManualDropModal(HW_MAN_DROP_SK);
  }

  // Odpoved servera na zapis. Modal ZAMOK odomyka VYHRADNE volajuci (kontrakt
  // D-15) — a to v OBOCH vetvach: uspech okno zatvara a pamat draftu zahadza,
  // odmietnutie ho necha OTVORENE s hodnotami a len povie dovod.
  //
  // KORELACIA JE PO TOKENE (Codex #285 P2-A), nie po druhu operacie: `kind`
  // odpoved nerozlisi (vsetky `add` maju prazdne `id`), takze pomala prestavba
  // by odpoved na UZ ZAVRETY modal priradila k prave otvorenemu. Modal preberie
  // odpoved LEN vtedy, ked sedi token, ktory sam odoslal. Ten isty callback
  // pride aj po mazani z riadku (bez modalu) — vtedy staci status.
  function onHwManualResult(ok, msg, op){
    var text = String(msg == null ? '' : msg);
    var open = (typeof NXModal !== 'undefined' && NXModal &&
                typeof NXModal.isOpen === 'function' && NXModal.isOpen());
    var token = String((op && op.token) == null ? '' : op.token);
    var mine = !!(HW_MAN && HW_MAN.sent && open && op && token !== '' &&
                  token === String(HW_MAN.token == null ? '' : HW_MAN.token));
    if (!mine){
      if (text) NX.setStatus(text, ok !== true);
      return;
    }
    if (ok === true){
      NXModal.setBusy(false, { clear: true });   // server potvrdil -> pamat zaniká
      NXModal.close();
      HW_MAN = null;
      if (text) NX.setStatus(text, false);
      return;
    }
    HW_MAN.sent = false;
    NXModal.setBusy(false);
    NXModal.showErrors([{ msg: text || 'Položka sa neuložila.' }]);
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
      HW_GROUP_CAB: HW_GROUP_CAB, HW_GROUP_INSIDE: HW_GROUP_INSIDE,
      // SMOKE PACK 1: suhrnne podperky polic (tests/js/test_smoke1_ui.js) —
      // ciste zoskupenie a texty, ziadny DOM.
      hwItemManual: hwItemManual, hwShelfPinSummary: hwShelfPinSummary,
      hwShelfCountText: hwShelfCountText, hwShelfPinTitle: hwShelfPinTitle,
      hwShelfPinTip: hwShelfPinTip, hwSplitShelfPins: hwSplitShelfPins,
      HW_SHELF_PIN: HW_SHELF_PIN, HW_PINS_MIN: HW_PINS_MIN, HW_PINS_KEY: HW_PINS_KEY,
      // KOV-H2 ad-hoc polozky (tests/js/test_kovh2_adhoc_ui.js) — ciste
      // skladanie textov, poli modalu, validacia a novy zoznam; DOM sa testuje
      // cez mini-DOM nad kostrou D-15.
      HW_MANUAL_UNITS: HW_MANUAL_UNITS, HW_MANUAL_QTY_MAX: HW_MANUAL_QTY_MAX,
      HW_MANUAL_NOTE_MAX: HW_MANUAL_NOTE_MAX,
      hwManualUnitLabel: hwManualUnitLabel, hwManualPriceText: hwManualPriceText,
      hwManualOwnerText: hwManualOwnerText, hwManualName: hwManualName,
      hwManualChips: hwManualChips, hwManualQtyText: hwManualQtyText,
      hwManualBuyText: hwManualBuyText, hwManualItemHtml: hwManualItemHtml,
      hwManualHtml: hwManualHtml, hwManualOwnerOptions: hwManualOwnerOptions,
      hwManualItemText: hwManualItemText, hwManualDraft: hwManualDraft,
      hwManualFields: hwManualFields, hwManualHit: hwManualHit,
      hwManualValidate: hwManualValidate, hwManualParsePrice: hwManualParsePrice,
      hwManualRecord: hwManualRecord, hwManualNextList: hwManualNextList,
      // CELY tok modalu (mini-DOM): otvorenie -> hladanie -> odoslanie ->
      // odpoved servera. Testovat ho po castiach by znamenalo napisat si vlastnu
      // kopiu toku a overovat kopiu, nie produkt.
      hwManualOpen: hwManualOpen, hwManualSubmit: hwManualSubmit,
      hwManualSearchResult: hwManualSearchResult, hwManualCtxSwitch: hwManualCtxSwitch,
      onHwManualResult: onHwManualResult, onHwManualDel: onHwManualDel,
      onHwManualEdit: onHwManualEdit, onHwManualAdd: onHwManualAdd,
      hwManualDropModal: hwManualDropModal, HW_MAN_DROP_SK: HW_MAN_DROP_SK,
      hwManualDropIfForeign: hwManualDropIfForeign,
      hwManualState: function(){ return HW_MAN; } };
  }
