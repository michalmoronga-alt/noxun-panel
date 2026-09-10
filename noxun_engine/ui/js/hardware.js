  // ===================== KOVANIE (V0.4 faza 1) =====================
  // Sekcia zobrazuje vypocitane polozky (config.hardware oznacenej skrinky) a rucne
  // zasahy. Identita polozky = (owner_part_key, generic_type, rule_id) — presne tak
  // ju posiela set_hardware_override do Ruby. Bez oznacenej skrinky len hint
  // (kovanie sa pocita na realnej skrinke, nie z hodnot panela).

  // V0.6 C-2 (audit F11): autorita labelov je SERVER (HardwareRules.label_for,
  // payload nesie it.label) — tato mapa je uz LEN fallback pre stary payload.
  // KOV-G1a: fallback mapa dobehla server — chybali v nej `wall_hanger`,
  // `lift` aj novy `plinth_clip`, takze stary payload by ich ukazal ako holy
  // kluc („plinth_clip" namiesto „Príchyt sokla").
  function hwLabel(t){
    return { leg:'Nohy', hinge:'Závesy', slide:'Výsuv', handle:'Úchytky',
             shelf_pin:'Podperky', connector:'Spojky',
             wall_hanger:'Zavesenie na stenu', lift:'Výklop / sklop',
             plinth_clip:'Príchyt sokla' }[t] || t;
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

  // ---- KOV-D2b: CHIPY OSI ZAMKU (vyska, NL) --------------------------------
  // JEDEN stav zo servera (`axes` z `Panel.drawer_axes_map`) kresli DVE miesta:
  // riadok vysuvu v kontexte Kovanie a riadok zasuvky v karte cela. Panel tu
  // NEPOCITA nic: ktore osi existuju, co plati, co sa da zamknut, ci je konflikt
  // a aky je navrh nahrady — vsetko su hotove udaje servera.
  //
  // Hodnota do ZAPISU ide VZDY z `axes[os].value` (resp. `options` / `proposal`)
  // ulozenej v `data-val`, NIKDY z textu chipu: text je popisok pre cloveka
  // („H144", „NL 470"), hodnota je cislo pre server.
  //
  // Ciste funkcie (Node testy: tests/js/test_kovd2b_ui.js).
  var HW_AX = [{ key: 'height', field: 'height_variant', label: 'výšku',
                 noun: 'Výška', suffix: 'výška' },
               { key: 'nl', field: 'nominal_length', label: 'dĺžku výsuvu',
                 noun: 'Dĺžka výsuvu', suffix: '' }];
  // Ponuka sa kresli az od DVOCH hodnot — jedna volba nie je vyber.
  var HW_AX_OPTS_MIN = 2;
  var HW_AX_NOVAL = 'Server pre túto os nemá hodnotu, ktorú by sa dalo zamknúť.';
  var HW_AX_NOMODAL = 'Potvrdzovacie okno sa nedá otvoriť — náhrada sa neodoslala.';
  var HW_AX_FIX_NOTE = 'Náhrada ostáva ZAMKNUTÁ (automat ju nezmení). Zámok druhej osi sa ' +
                       'nemení a znova sa overí.';
  var HW_AX_BLOCKED = 'Dĺžka výsuvu sa ponúkne, až keď vyriešiš výšku.';

  function hwAxDef(kind){
    for (var i = 0; i < HW_AX.length; i++){ if (HW_AX[i].key === kind) return HW_AX[i]; }
    return null;
  }
  // Stav osi je SERVEROVY enum; cokolvek ine je 'auto' (nikdy sa nedomyslá
  // stav, ktory server nepovedal).
  function hwAxState(ax){
    var s = ax ? String(ax.state || '') : '';
    return (s === 'locked' || s === 'conflict') ? s : 'auto';
  }
  // Popisok hodnoty: vyska „H144", dlzka „NL 470". Chybajuca hodnota sa PRIZNA
  // pomlckou — nula ani prazdny retazec by klamali.
  function hwAxValText(kind, v){
    if (v == null || !isFinite(Number(v))) return '—';
    return (kind === 'height') ? ('H' + Math.round(Number(v))) : ('NL ' + hwNlFmt(v));
  }
  function hwAxText(kind, ax){ return hwAxValText(kind, ax ? ax.value : null); }
  // Ponuka na zamknutie = VYHRADNE `options` zo servera. -> [{value,text,selected}]
  function hwAxOptionList(kind, ax){
    var out = [];
    var cur = (ax && ax.value != null) ? Number(ax.value) : null;
    var list = (ax && ax.options) ? ax.options : [];
    for (var i = 0; i < list.length; i++){
      var num = Number(list[i]);
      if (!isFinite(num)) continue;
      out.push({ value: String(num), text: hwAxValText(kind, num),
                 selected: cur != null && Math.abs(num - cur) < 0.001 });
    }
    return out;
  }
  function hwAxChipTitle(kind, ax){
    var d = hwAxDef(kind); if (!d) return '';
    var st = hwAxState(ax);
    if (st === 'locked') return 'Odomknúť — platí automat';
    if (st === 'conflict') return 'Zamknutá hodnota už neplatí — odomkni ju alebo nahraď';
    return 'Zamknúť ' + d.label + ' ' + hwAxText(kind, ax) + ' (automat by mohol zmeniť)';
  }
  function hwAxSelTitle(kind){
    var d = hwAxDef(kind);
    return d ? ('Zamknúť inú ' + d.label + ' z ponuky receptu') : '';
  }
  // Veta potvrdenia nahrady. Stavia sa z HODNOT servera (stara a navrhovana),
  // nie z dovodu konfliktu — ten je uz na obrazovke v cervenom riadku.
  function hwAxFixSub(kind, ax){
    var d = hwAxDef(kind); if (!d) return '';
    return d.noun + ' ' + hwAxText(kind, ax) + ' už neplatí. Nahradiť ju za ' +
           hwAxValText(kind, ax && ax.proposal) + '?';
  }
  function hwAxFixLabel(kind, ax){
    return 'Nahradiť za ' + hwAxValText(kind, ax && ax.proposal);
  }

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
  // KOV-C2b (Codex #304 P1): o tom, ktory rucny zasah je OSIROTENY, rozhoduje
  // SERVER (`orphan` v payloade) — len on vidi aj ulozene `drawer_conflicts`.
  // Fallback (payload bez kluca) je povodne pravidlo D-92: vypnuta kategoria
  // bez zodpovedajucej zivej polozky.
  function hwDisabledOffs(items, overrides){
    var present = {};
    (items || []).forEach(function(it){
      if (it) present[hwKey(it.owner_part_key, it.generic_type, it.rule_id)] = true;
    });
    return (overrides || []).filter(function(ov){
      if (!ov) return false;
      if (ov.orphan === true) return true;
      if (ov.orphan !== undefined) return false;
      if (ov.disabled !== true) return false;
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
    // D-118b: člen, ktorý má pre túto dĺžku VEDOME prázdnu bunku (`none`) —
    // súpis to prizná, inak by pri NL 620 vyzeralo, že modul niekto zabudol.
    if (m.skipped === true) return (m.label || 'člen') + ' · bez kódu (netreba)';
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
  // ---- KOV-D1b: ponuka pre KLASIFIKOVANU zasuvku --------------------------
  // Pri klasifikovanej polozke (celo nesie otvaranie + konstrukciu) plati
  // TRIEDNY kluc a ponuku sklada SERVER (`entry.compat`): len kompatibilne
  // moznosti, Atira ako RODINA „podľa výšky", Quadro ako pevny set. JS
  // nefiltruje, neprekladá a kluc neskladá — posle spat hodnotu, ktoru dostal.
  var HW_SET_STORED = '__stored__'; // ulozena volba mimo ponuky (len ZOBRAZENIE)

  function hwCompatScope(entry, owner){
    var c = entry && entry.compat;
    if (!c) return null;
    if (owner) return (c.owners && c.owners[owner]) || null;
    return c.cab || null;
  }
  function hwCompatPick(sc, id){
    var list = (sc && sc.options) || [];
    for (var i = 0; i < list.length; i++){ if (list[i] && list[i].id === id) return list[i]; }
    return null;
  }
  function hwCompatOptionList(sc){
    var out = [{ value: '', text: sc.none_label || 'podľa projektu',
                 selected: !sc.current && !sc.stored, disabled: false }];
    // F10: ulozena volba, ktora uz v ponuke NIE JE (neaktivny set), sa ZOBRAZI,
    // ale vybrat sa neda — inak by select ukazoval prazdno tam, kde hodnota je.
    if (sc.stored){
      out.push({ value: HW_SET_STORED, text: (sc.value_text || '') + ' (uložený výber)',
                 selected: true, disabled: true });
    }
    (sc.options || []).forEach(function(o){
      if (!o || !o.id) return;
      out.push({ value: o.id, text: o.label, selected: o.id === sc.current, disabled: false });
    });
    return out;
  }
  // Ponuka pre riadok DIELCA (owner-level override, D-81).
  function hwOwnerOptionList(entry, owner){
    var sc = hwCompatScope(entry, owner);
    if (sc) return hwCompatOptionList(sc);
    var ov = hwOwnerOverride(entry, owner);
    return hwSetOptionList(entry, (ov && ov.set_id) || '', '(podľa skrinky/projektu)',
                           (ov && ov.selector) ? (ov.label || 'podľa parametra') : null);
  }
  // KOV-D1b (Codex #310 kolo 1 P2-3): server ZÁMERNE pošle `compat.cab = null`,
  // keď má skrinka klasifikované zásuvky VIACERÝCH tried (alebo klasifikovanú
  // vedľa legacy) — jeden kľúč by platil len na časť položiek a
  // `apply_cabinet_override` taký zápis odmieta. Riadok skrinky sa vtedy
  // NEKRESLÍ vôbec; inak by sa vykreslil plochý zoznam setov, z ktorého by
  // KAŽDÁ voľba skončila hláškou. Rozlišuje sa **neprítomný** `compat`
  // (legacy/neklasifikovaná skrinka → pôvodná cesta) od prítomného s `cab: null`.
  function hwCabRowOff(entry){
    return !!(entry && entry.compat) && !entry.compat.cab;
  }
  // Ponuka pre riadok SKRINKY (override projektovej predvolby).
  // -> null = riadok sa nemá kresliť vôbec (zmiešaná skrinka)
  function hwCabOptionList(entry){
    if (hwCabRowOff(entry)) return null;
    var sc = hwCompatScope(entry, null);
    if (sc) return hwCompatOptionList(sc);
    return hwSetOptionList(entry, (entry && entry.override_set_id) || '',
                           (entry && entry.project_label) || 'podľa projektu',
                           (entry && entry.override_selector) ? (entry.override_label || 'podľa parametra') : null);
  }
  // Tooltip selectu: pri klasifikovanej zasuvke povie, PRE KOHO vyber plati
  // a akej triedy sa tyka („Set pre toto čelo — Výsuv · Tip-On · Kovové
  // bočnice"); inak ostava povodny text „čo platí bez vlastného výberu".
  function hwCompatTitle(sc, fallback){
    if (!sc) return fallback;
    var head = sc.scope_label || '';
    return sc.class_label ? (head + ' — ' + sc.class_label) : head;
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
  // Odstranenie skrinkoveho riadku setu — cely `.hwsetrow` aj s popiskom
  // (samotny select by nechal visiet holy nadpis bez ovladaca).
  function hwDropSetRow(sel){
    var row = (sel && sel.closest) ? sel.closest('.hwsetrow') : null;
    var node = row || sel;
    if (node && node.parentNode) node.parentNode.removeChild(node);
  }
  // D-75: zivy refresh ponuky bez prekreslenia riadkov (rozpisany pocet
  // ostava). Vybranu hodnotu urcuje SERVER — payload nesie aktualne overridy.
  function refreshHardwareSets(options){
    HW_SET_OPTIONS = options || [];
    // UI-C4: selecty setov ziju v DVOCH kontajneroch — per vlastnik v boxoch
    // (#hwRows) a per typ pre celu skrinku v skupine Sety (#hwSetRows).
    // KOV-G2: a od D-111 v TRETOM — riadok Noh v Zakladnych (`#legsRow`) nesie
    // ten isty select pre typ `leg`. Bez neho by sa nova ponuka setov objavila
    // len v skupine Sety a riadok Noh by drzal starú.
    ['hwRows', 'hwSetRows', 'legsRow'].forEach(function(id){
      var box = el(id); if (!box) return;
      var sels = box.querySelectorAll('select.hwsetsel');
      for (var i = 0; i < sels.length; i++){
        var sel = sels[i];
        var entry = hwSetEntry(sel.getAttribute('data-gt'));
        var owner = sel.getAttribute('data-owner') || '';
        var list = owner ? hwOwnerOptionList(entry, owner) : hwCabOptionList(entry);
        // KOV-D1b: skrinkový riadok sa medzitým mohol stať nepoužiteľným
        // (pribudla zásuvka inej triedy) — ľahký push preto odstráni CELÝ
        // riadok, nedopĺňa doň plochý zoznam, z ktorého by každá voľba zlyhala.
        if (!list){ hwDropSetRow(sel); continue; }
        sel.innerHTML = hwOptionsHtml(list);
        sel.title = owner ? hwOwnerTitle(entry, owner) : hwCabTitle(entry);
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

  function hwOwnerTitle(entry, owner){
    var sc = hwCompatScope(entry, owner);
    if (sc) return hwCompatTitle(sc, '') + ' · bez vlastného výberu platí: '
                  + (sc.none_label || 'predvoľba projektu');
    return 'Set kovania pre tento dielec · bez vlastného výberu platí: '
         + ((entry && entry.owner_default_label) || 'predvoľba projektu');
  }
  function hwCabTitle(entry){
    var sc = hwCompatScope(entry, null);
    if (sc) return hwCompatTitle(sc, '') + ' · bez vlastného výberu platí: '
                  + (sc.none_label || 'predvoľba projektu');
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
                        it.owner_part_key, cabId, hwOwnerTitle(entry, it.owner_part_key))
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
      // KOV-D2b: rad chipov osi zamku PATRI POD riadok a PRED nakup — `refresh
      // HardwarePurchase` prilepuje nakupny riadok na KONIEC `.hwitem`, takze
      // toto poradie prezije aj lahky push.
      + hwAxHtml(it.axes, { owner_part_key: it.owner_part_key, generic_type: it.generic_type,
                            rule_id: it.rule_id, cabinet_id: cabId })
      + hwBuyHtml(it.purchase)
      + '</div>';
  }
  // Osiroteny rucny zasah: „vypnuté" (D-92) alebo „neplatný ručný zásah"
  // (KOV-C2b — celo so systemom skoncilo konfliktom, polozka NEVZNIKLA).
  // Prvy sa OBNOVUJE (zrusi sa pole `disabled`), druhy sa CELY ZRUSI: zaznam
  // moze niest pocet aj zamok naraz a po konflikte nema co z neho zostat.
  function hwOffLabel(ov){
    if (ov && ov.orphan_kind === 'part_material') return 'neplatný ručný materiál';
    return (ov && ov.orphan_kind === 'invalid') ? 'neplatný ručný zásah' : 'vypnuté';
  }
  // Nazov riadku: server ho pri materialovom override posiela hotovy
  // (`orphan_label`) — genericky typ kovania taky zaznam nema.
  function hwOffName(ov){
    return (ov && ov.orphan_label) ? ov.orphan_label : hwLabel(ov && ov.generic_type);
  }
  function hwOffHtml(ov, cabId, groupKey){
    var full = ov.owner_label || hwOwnerDesc(ov.owner_part_key); // D-92
    var owner = hwRowOwnerText(groupKey, full);
    var ext = hwOffLabel(ov);
    var name = hwOffName(ov);
    var btn;
    if (ov.orphan_kind === 'part_material'){
      btn = '<button class="ghostbtn hwbtn" title="Zrušiť ručný materiál (dielec ho zdedí)" onclick="onHwOrphanPartReset(this)">'+NXIcons.svg('rotate-ccw')+' zrušiť</button>';
    } else if (ov.orphan_kind === 'invalid'){
      btn = '<button class="ghostbtn hwbtn" title="Zrušiť ručný zásah (obnoví sa výpočet)" onclick="onHwOrphanReset(this)">'+NXIcons.svg('rotate-ccw')+' zrušiť</button>';
    } else {
      btn = '<button class="ghostbtn hwbtn" title="Obnoviť (platí pravidlo)" onclick="onHwEnable(this)">'+NXIcons.svg('rotate-ccw')+' obnoviť</button>';
    }
    var row = '<div class="hwrow hwoff" data-owner="'+esc(ov.owner_part_key||'')+'" data-type="'+esc(ov.generic_type||'')+'" data-rule="'+esc(ov.rule_id||'')+'" data-part="'+esc(ov.part_key||'')+'" data-cab="'+esc(cabId||'')+'">'
      // SMOKE PACK 1: nazov je jednoriadkovy s ellipsis, takze plny text MUSI
      // niest `title` — inak by sa orezany popis nedal precitat vobec.
      + '<span class="hwname" title="'+esc(name+(full?' · '+full:'')+' · '+ext)+'">'
      + esc(name)+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
      + ' <span class="hwext">'+esc(ext)+'</span></span>'
      + btn
      + '</div>';
    // KOV-D2b: OSIROTENY zasah zasuvky nesie stav osi tiez (polozka vysuvu pri
    // konflikte NEVZNIKLA) — bez chipov by sa konfliktna zasuvka nedala
    // odomknut inak, nez zrusenim CELEHO zaznamu (a s nim druheho zamku).
    var ax = hwAxHtml(ov.axes, { owner_part_key: ov.owner_part_key, generic_type: ov.generic_type,
                                 rule_id: ov.rule_id, cabinet_id: cabId });
    return ax ? ('<div class="hwitem">' + row + ax + '</div>') : row;
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
    // KOV-D1b: typ, ktorého skrinkový výber je nepoužiteľný (zmiešané triedy
    // zásuviek), sa v skupine Sety NEKRESLÍ — set sa vtedy vyberá pri
    // konkrétnom čele a ovládač na skrinke by len ponúkal chybu.
    var all = (setOptions || []).filter(function(o){ return !!o; });
    var perFront = all.length > 0 && all.every(hwCabRowOff);
    var sets = all.filter(function(o){ return !hwCabRowOff(o); }).map(function(o){
      return '<div class="hwrow hwsetrow"><span class="hwname">'+esc(o.label)
           + ' <span class="hwown">set</span></span>'
           + hwSetSelectHtml(hwCabOptionList(o), o.generic_type, '', cabId, hwCabTitle(o))
           + '</div>';
    }).join('');
    setBox.innerHTML = sets || (perFront
      ? '<div class="muted">Zásuvky tejto skrinky sú rôznych druhov — set sa vyberá pri konkrétnom čele.</div>'
      : '<div class="muted">Táto skrinka nemá kovanie, pre ktoré by sa dal vybrať set.</div>');
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
  //
  // KOV-D4: prisvieteny je VZDY NAJVIAC JEDEN uzol. Dalsi skok stary highlight
  // SNIME HNED (nie az po jeho vlastnom casovaci) — inak by po dvoch skokoch
  // za sebou svietili dva riadky a pouzivatel by nevedel, ktory je „jeho".
  // Trvanie ostava rovnake ako doteraz (1600 ms).
  var HW_FLASH_MS = 1600;
  var hwFlashNode = null;
  var hwFlashTimer = null;
  function hwFlashClear(){
    if (hwFlashTimer){ clearTimeout(hwFlashTimer); hwFlashTimer = null; }
    if (hwFlashNode && hwFlashNode.classList) hwFlashNode.classList.remove('hwfocus');
    hwFlashNode = null;
  }
  function hwFlash(target){
    if (!target || !target.classList) return;
    hwFlashClear();
    hwFlashNode = target;
    target.classList.add('hwfocus');
    hwFlashTimer = setTimeout(function(){ hwFlashClear(); }, HW_FLASH_MS);
  }

  // ---- KOV-D4: DEEP-LINK Z KONTROLY NA KONKRETNY RIADOK KOVANIA -----------
  // Server posiela LEN ADRESU riadku (`NX.focusHardware`): `owner_part_key`
  // + `generic_type` + `rule_id` + `orphan`. Klient si NIC neodvodzuje —
  // ani to, ci je cielom osiroteny zaznam, ani z ktoreho `part_key` by sa dal
  // poskladat. Ked riadok neexistuje (medzitym prestavana skrinka, iny vyber),
  // NEROBI SA NIC: prisvietit cudzi riadok by klamalo.
  // Vracia true/false, aby sa cesta dala overit v Node testoch.
  function hwRowSelector(t){
    if (!t || !t.generic_type || !t.rule_id) return '';
    return '.hwrow' + (t.orphan === true ? '.hwoff' : '')
         + '[data-owner="' + cssEsc(t.owner_part_key == null ? '' : t.owner_part_key) + '"]'
         + '[data-type="' + cssEsc(t.generic_type) + '"]'
         + '[data-rule="' + cssEsc(t.rule_id) + '"]';
  }
  // Riadok naozaj TOHO druhu, aky server pomenoval. Identita (vlastnik + typ +
  // pravidlo) je v paneli jedinecna — osiroteny zaznam a ziva polozka nikdy
  // neziju sucasne — takze rozdiel triedy je KONTROLA, nie hladanie: ked sa
  // nezhoduje, payload je zastarany a prisvieti sa RADSEJ NIC.
  function hwRowKindOk(row, t){
    if (!row || !row.classList) return false;
    return row.classList.contains('hwoff') === (t.orphan === true);
  }
  // Prisvieti sa CELA polozka (`.hwitem`), ked existuje: nesie aj chipy osi
  // a nakupny riadok, takze samotny `.hwrow` by zvyraznil len jej vrsok.
  function hwFlashTargetOf(row){
    if (!row) return null;
    var item = row.closest ? row.closest('.hwitem') : null;
    return item || row;
  }
  function nxFocusHardware(target){
    var sel = hwRowSelector(target);
    if (!sel) return false;
    var box = el('hwRows');
    var row = box ? box.querySelector(sel) : null;
    if (!row || !hwRowKindOk(row, target)) return false;
    if (typeof setViewContext === 'function') setViewContext('kovanie');
    var node = hwFlashTargetOf(row);
    if (typeof nxRevealTarget === 'function') nxRevealTarget(node);
    if (node.scrollIntoView) node.scrollIntoView({ block: 'nearest' });
    hwFlash(node);
    return true;
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
  // Telo payloadu vyberu setu — CISTA funkcia (Node testy). `sc` = rozsah
  // KOV-D1b (`entry.compat`) alebo null pre povodny plochy zoznam setov.
  // -> payload | null (nic sa neodosiela)
  function hwSetPayload(sc, value, gt, owner, cabId){
    // Volba „podľa parametra" aj „(uložený výber)" su len ZOBRAZENIE stavu
    // (`disabled`) — nikdy sa neodosielaju.
    if (value === HW_SET_PARAM || value === HW_SET_STORED) return null;
    var body = { generic_type: gt, owner_part_key: owner || null, set_id: value,
                 cabinet_id: cabId || '' }; // GH #127 P2 + R-02
    if (!sc) return body;
    if (!value) return { generic_type: gt, owner_part_key: owner || null, set_id: '',
                         cabinet_id: cabId || '' }; // „vrátiť na projekt"
    var o = hwCompatPick(sc, value);
    if (!o) return null; // neznáme ID sa NEODOSIELA (radšej nič než hádanie)
    body.set_id = o.set_id || '';
    // Rodina (Atira) = výber podľa výškového variantu; server ho validuje
    // pásmo po pásme (`classified_value_problem`) PRED zápisom.
    if (o.selector) body.value = o.selector;
    return body;
  }

  function onHwSet(sel){
    var gt = sel.getAttribute('data-gt');
    var owner = sel.getAttribute('data-owner') || '';
    var body = hwSetPayload(hwCompatScope(hwSetEntry(gt), owner), sel.value, gt, owner,
                            sel.getAttribute('data-cab') || '');
    if (!body) return;
    if (window.sketchup && sketchup.set_hardware_set)
      sketchup.set_hardware_set(nxDocPayload(body));
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
  // KOV-C2b: zrusi CELY zaznam rucneho zasahu (serverova akcia `reset`) —
  // po nej prestavba konflikt zasuvky uz nevyda.
  function onHwOrphanReset(btn){ hwSend(hwPayload(btn, { reset: true })); }
  // KOV-C2b: zrusi OSIROTENY materialovy override dielca zasuvky (vlastna
  // serverova akcia — dielec po fail-closed konflikte neexistuje, takze sa
  // neda oznacit a karta dielca na neho nevie).
  function onHwOrphanPartReset(btn){
    var row = btn.closest('.hwrow'); if (!row) return;
    if (window.sketchup && sketchup.reset_part_override){
      sketchup.reset_part_override(nxDocPayload({
        cabinet_id: row.dataset.cab || '', part_key: row.dataset.part || '' }));
    }
  }
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
  // ---- KOV-D2b: markup a zapis chipov osi ---------------------------------
  // `ident` = identita ZAPISU (`owner_part_key`, `generic_type`, `rule_id`,
  // `cabinet_id`) — v kontexte Kovanie ju ma riadok, karte cela ju posiela
  // server (`front_drawer[fid].lock`). Chipy si ju nesu vo VLASTNOM obale
  // `.hwax`, takze ten isty markup funguje na oboch miestach a nepotrebuje
  // `.hwrow` (karta cela ziadny nema).
  function hwAxHtml(axes, ident){
    var ax = (axes && typeof axes === 'object') ? axes : null;
    var id = (ident && typeof ident === 'object') ? ident : null;
    if (!ax || !id) return '';
    var chips = '', notes = '';
    HW_AX.forEach(function(d){
      var a = ax[d.key];
      // QUADRO nema kluc `height` VOBEC — os, ktora neexistuje, sa nekresli.
      if (!a || typeof a !== 'object') return;
      chips += hwAxChipHtml(d.key, a);
      notes += hwAxNoteHtml(d.key, a);
    });
    if (!chips) return '';
    return '<div class="hwax" data-owner="'+esc(id.owner_part_key||'')+'"'
         + ' data-type="'+esc(id.generic_type||'')+'" data-rule="'+esc(id.rule_id||'')+'"'
         + ' data-cab="'+esc(id.cabinet_id||'')+'">'
         + '<div class="axchips">'+chips+'</div>'+notes+'</div>';
  }
  function hwAxChipHtml(kind, ax){
    var st = hwAxState(ax);
    var cls = 'axchip' + (st === 'locked' ? ' locked' : '') + (st === 'conflict' ? ' err' : '');
    var d = hwAxDef(kind);
    var val = (ax && ax.value != null) ? String(ax.value) : '';
    // `data-axc` = DRUH ovladaca. Je to logicka identita pre obnovu fokusu po
    // prekresleni karty cela (`frontCardFocusKey`) — `data-ax` sama nestaci,
    // lebo tu istu os nesie chip, ponuka aj obe tlacidla konfliktu.
    var h = '<button type="button" class="'+cls+'" data-ax="'+esc(kind)+'" data-axc="chip"'
          + ' data-state="'+esc(st)+'" data-val="'+esc(val)+'"'
          + ' aria-pressed="'+(st === 'auto' ? 'false' : 'true')+'"'
          + ' title="'+esc(hwAxChipTitle(kind, ax))+'" onclick="onHwAxChip(this)">'
          + NXIcons.svg(st === 'auto' ? 'lock-open' : 'lock')
          + '<b>'+esc(hwAxText(kind, ax))+'</b>'
          + ((d && d.suffix) ? '<span class="axsuf">'+esc(d.suffix)+'</span>' : '')
          + '</button>';
    // KONFLIKT NEMA PONUKU (Codex #313 kolo 1 P2-3). Server pri konflikte
    // `options` stale posiela (su to hodnoty, ktore by sa dali zamknut), ale
    // select vedla cerveneho chipu by bol DRUHA cesta k tej istej zmene — a to
    // BEZ potvrdenia, ktore vedla neho vyzaduje tlacidlo „Nahradiť za …".
    // Jedina cesta z konfliktu je preto nahrada (D-15) alebo odomknutie.
    var opts = (st === 'conflict') ? [] : hwAxOptionList(kind, ax);
    if (opts.length < HW_AX_OPTS_MIN) return h;   // `blocked_by` = prazdne options = ziadna ponuka
    var oh = '';
    opts.forEach(function(o){
      oh += '<option value="'+esc(o.value)+'"'+(o.selected?' selected':'')+'>'+esc(o.text)+'</option>';
    });
    return h + '<select class="axsel" data-ax="'+esc(kind)+'" data-axc="sel"'
             + ' aria-label="'+esc(hwAxSelTitle(kind))+'"'
             + ' title="'+esc(hwAxSelTitle(kind))+'" onchange="onHwAxPick(this)">'+oh+'</select>';
  }
  // CERVENY riadok konfliktu (veta je SERVEROVA — panel ziadnu vlastnu
  // neskladá) + cesty von: nahrada LEN ked server navrh naozaj dal
  // (`proposal`), odomknutie VZDY. Pri `blocked_by` je to len tlmena veta:
  // NL sa nema z coho ponukat, kym neplati vyska.
  function hwAxNoteHtml(kind, ax){
    if (hwAxState(ax) === 'conflict'){
      var msg = String((ax && ax.message) || '');
      var btns = '';
      if (ax && ax.proposal != null){
        btns += '<button type="button" class="ghostbtn hwbtn" data-ax="'+esc(kind)+'" data-axc="fix"'
              + ' data-val="'+esc(String(ax.proposal))+'"'
              + ' data-sub="'+esc(hwAxFixSub(kind, ax))+'"'
              + ' title="'+esc(hwAxFixSub(kind, ax))+'" onclick="onHwAxFix(this)">'
              + esc(hwAxFixLabel(kind, ax))+'</button>';
      }
      btns += '<button type="button" class="ghostbtn hwbtn" data-ax="'+esc(kind)+'" data-axc="unlock"'
            + ' title="Odomknúť — platí automat" onclick="onHwAxUnlock(this)">'
            + NXIcons.svg('lock-open')+' Odomknúť</button>';
      return '<div class="axconf">'+NXIcons.svg('alert')
           + (msg ? '<span>'+esc(msg)+'</span>' : '')
           + '<div class="cbtns">'+btns+'</div></div>';
    }
    if (kind === 'nl' && ax && ax.blocked_by === 'height'){
      return '<div class="axnote">'+esc(HW_AX_BLOCKED)+'</div>';
    }
    return '';
  }
  // Identita zapisu z obalu `.hwax` — TA ISTA na oboch miestach.
  function hwAxIdent(node){
    var box = (node && node.closest) ? node.closest('.hwax') : null;
    if (!box) return null;
    return { owner_part_key: box.getAttribute('data-owner') || null,
             generic_type: box.getAttribute('data-type') || '',
             rule_id: box.getAttribute('data-rule') || '',
             cabinet_id: box.getAttribute('data-cab') || '' };
  }
  function hwAxSend(node, kind, value){
    var d = hwAxDef(kind); if (!d) return false;
    var id = hwAxIdent(node); if (!id) return false;
    id.field = d.field;
    id.value = value;
    hwSend(id);
    return true;
  }
  // Klik na chip: `auto` ZAMKNE hodnotu zo SERVERA (`data-val`), `locked`
  // aj `conflict` odomknu LEN TUTO os (`value: null` — druhy zamok zije).
  function onHwAxChip(btn){
    var kind = btn.getAttribute('data-ax');
    if (btn.getAttribute('data-state') !== 'auto'){ hwAxSend(btn, kind, null); return; }
    var raw = btn.getAttribute('data-val');
    var v = (raw == null || raw === '') ? NaN : parseFloat(raw);
    if (isNaN(v)){ NX.setStatus(HW_AX_NOVAL, true); return; }
    hwAxSend(btn, kind, v);
  }
  // Volba z ponuky = zamknutie PRAVE TEJ hodnoty. Ponuka nesie len `options`
  // zo servera, takze sa neda odoslat nic, co server nedal.
  function onHwAxPick(sel){
    var v = parseFloat(sel.value);
    if (isNaN(v)){ NX.setStatus('Neplatná hodnota osi.', true); return; }
    hwAxSend(sel, sel.getAttribute('data-ax'), v);
  }
  function onHwAxUnlock(btn){ hwAxSend(btn, btn.getAttribute('data-ax'), null); }

  // ---- KOV-D2b: NAHRADA = D-15 POTVRDENIE SO ZAMKOM ODOSIELANIA -----------
  // Kontrakt kostry D-15: **zapis okno NEZATVARA** — zatvorit ho smie az
  // volajuci, ked SERVER zapis POTVRDI (GH #138 P2 / audit #10). Predtym sa
  // okno zatvaralo hned v `onSubmit`, takze odmietnutie servera (napr. navrh
  // medzitym zastaral, lebo pouzivatel zmenil vyber v SketchUpe) pouzivatel
  // uvidel uz len ako status pod prazdnou kartou — bez kontextu rozhodnutia
  // a bez nahrady (Codex #313 kolo 1 P2-1).
  //
  // Korelacia je TOKENOM, nie druhom operacie (lekcia KOV-H2, Codex #285
  // P2-A): kazde odoslanie ma vlastny rastuci token, server ho vracia v echu
  // a klient porovnava JEHO — inak by odpoved na starsie odoslanie zavrela
  // okno, ktore uz caka na nieco ine.
  var HW_AX_MODAL = null;   // { token, sent } | null = ziadne nase okno nebezi
  var HW_AX_SEQ = 0;
  function hwAxToken(){ HW_AX_SEQ += 1; return 'a' + HW_AX_SEQ; }

  // Nahrada je JEDNO rozhodnutie => kostra D-15 (potvrdenie bez poli).
  // Identita aj hodnota sa citaju PRED otvorenim okna — modal prekresluje
  // `#nxModalRoot`, nie panel, ale spoliehat sa na to by bola zbytocna vazba.
  // BEZ kostry sa nahrada NEODOSLE: zmena zamknutej hodnoty bez potvrdenia je
  // presne to, comu sa davka vyhyba.
  function onHwAxFix(btn){
    var kind = btn.getAttribute('data-ax');
    var d = hwAxDef(kind);
    var id = hwAxIdent(btn);
    var v = parseFloat(btn.getAttribute('data-val'));
    if (!d || !id || isNaN(v)) return;
    if (typeof NXModal === 'undefined' || !NXModal || typeof NXModal.open !== 'function'){
      NX.setStatus(HW_AX_NOMODAL, true);
      return;
    }
    NXModal.open({
      title: 'Nahradiť zamknutú hodnotu',
      sub: btn.getAttribute('data-sub') || '',
      note: HW_AX_FIX_NOTE,
      okLabel: 'Nahradiť',
      // KOV-D3b (Codex #315 kolo 1 P2): TA ISTA pasca ako pri prechode na novu
      // verziu — zatvorenie okna POCAS zapisu vycisti len nas stav, ale mutacia
      // na serveri bezi dalej a zasuvku aj tak prestavi. Zapnute az teraz, lebo
      // az teraz odpoveda `handle_set_hardware_override` aj z vetvy vynimky.
      busyLock: true,
      fields: [],
      onSubmit: function(){
        if (!HW_AX_MODAL || HW_AX_MODAL.sent) return;   // dvojklik nezapise dvakrat
        var tok = hwAxToken();
        HW_AX_MODAL.token = tok;
        HW_AX_MODAL.sent = true;
        NXModal.clearErrors();
        NXModal.setBusy(true);
        id.field = d.field;
        id.value = v;
        id.ax_token = tok;
        hwSend(id);
      },
      // Zatvorenie (Escape, scrim, krizik, „Zrušiť" aj nase vlastne) stav
      // VZDY vycisti — inak by odpoved na uz zavrete okno hlasila do prazdna.
      onClose: function(){ HW_AX_MODAL = null; }
    });
    // AZ ZA `open`: kostra najprv zatvara predchadzajuci modal, takze jeho
    // `onClose` by novy stav hned vynuloval.
    HW_AX_MODAL = { token: null, sent: false };
  }
  // Odpoved servera na zapis Z MODALU. Uspech okno zatvara, zlyhanie ho
  // ODOMKNE a hlasku ukaze V NOM — rozhodnutie tak ostane na obrazovke.
  function onHwAxResult(ok, msg, token){
    if (!HW_AX_MODAL || String(token || '') !== String(HW_AX_MODAL.token || '')) return;
    if (typeof NXModal === 'undefined' || !NXModal) return;
    if (ok){
      HW_AX_MODAL = null;
      NXModal.setBusy(false, { clear: true });   // server potvrdil -> pamat zaniká
      NXModal.close();
      return;
    }
    HW_AX_MODAL.sent = false;
    NXModal.setBusy(false);
    NXModal.showErrors([{ msg: msg || 'Náhrada sa neuložila.' }]);
  }

  // ---- KOV-D3b: PRECHOD NA NOVSIU VERZIU RECEPTU --------------------------
  // Recepty su NEMENNE: oprava hodnoty od vyrobcu nikdy neprepise stary subor,
  // ale vyda `_v2`. Uz postavena zasuvka na nu preto neprejde sama — je to
  // VEDOME rozhodnutie, lebo mení geometriu dielcov aj objednavacie kody.
  //
  // Panel o verziach NEROZHODUJE: `from`/`to` dostal v payloade (`upgrade`
  // blok) a posiela SPAT PRESNE ICH. Ci je `to` naozaj novsie, ci je vydane
  // a ci na cielovej verzii zasuvka vobec sadne, overuje server — dvakrat:
  // pri dopade (nasucho) aj pri zapise.
  //
  // Preco DVA kanaly: „ukaz dopad" je CITANIE (nic sa nezapisuje, moze
  // skoncit odmietnutim bez okna), „prejdi" je ZAPIS s potvrdenim. Jeden
  // kanal by musel niest oboje a modal by nevedel, na co prave caka.
  var HW_UP_ASK = null;   // { token, offer } = ziadost o dopad LETI
  var HW_UP = null;       // { token, sent, offer, impact } = nase okno BEZI
  var HW_UP_SEQ = 0;
  function hwUpToken(){ HW_UP_SEQ += 1; return 'u' + HW_UP_SEQ; }
  var HW_UP_NOMODAL = 'Potvrdzovacie okno sa nenačítalo — obnov panel (Inspector zavri a otvor).';

  // Ponuka v karte cela: tlmena veta + ghost tlacidlo. Ziadny novy blok, ked
  // v2 neexistuje — `frontDrawerRows` riadok vtedy vobec nevyrobi.
  //
  // `data-ax`/`data-axc` na tlacidle = LOGICKA IDENTITA ovladaca pre obnovu
  // fokusu po prekresleni karty (`frontCardFocusKey`, vzor D2b P2-4). Karta sa
  // prekresluje aj LAHKYM pushom (zmena mapovania alebo katalogu v Studiu),
  // takze bez nej by fokus pri klavesovej praci spadol na dokument. Ponuka je
  // v karte prave jedna, takze dvojica je jednoznacna.
  function hwUpHtml(up){
    var u = (up && typeof up === 'object') ? up : null;
    if (!u || u.available !== true) return '';
    var note = String(u.release_note || '');
    var lbl = String(u.to_label || '');
    return '<div class="dwup" data-cab="' + esc(u.cabinet_id || '') + '"'
         + ' data-fid="' + esc(u.front_id || '') + '"'
         + ' data-from="' + esc(u.from || '') + '" data-to="' + esc(u.to || '') + '">'
         + '<div class="inforow">' + NXIcons.svg('info')
         + esc('Dostupný recept ' + lbl + (note ? ' — ' + note : ''))
         + '</div>'
         + '<button type="button" class="ghostbtn" data-ax="upgrade" data-axc="upg"'
         + ' title="' + esc('Ukáže, čo sa zmení na tejto zásuvke, a spýta sa na potvrdenie') + '"'
         + ' onclick="onDrawerUpgrade(this)">' + esc('Prejsť na ' + lbl + '…') + '</button>'
         + '</div>';
  }
  // Identita ponuky z obalu `.dwup` — panel si ju NESKLADA, len ju cita spat
  // z toho, co vykreslil zo serveroveho payloadu.
  function hwUpOffer(node){
    var box = (node && node.closest) ? node.closest('.dwup') : null;
    if (!box) return null;
    var o = { cabinet_id: box.getAttribute('data-cab') || '',
              front_id: box.getAttribute('data-fid') || '',
              from: box.getAttribute('data-from') || '',
              to: box.getAttribute('data-to') || '' };
    return (o.front_id && o.from && o.to) ? o : null;
  }

  // Klik na ponuku = CITACIA otazka „co sa zmeni". Okno sa NEOTVARA hned:
  // preflight moze prechod odmietnut (napr. hrubka dielca), a vtedy nie je
  // co potvrdzovat — pouzivatel dostane vetu preco.
  function onDrawerUpgrade(btn){
    var o = hwUpOffer(btn);
    if (!o) return;
    if (HW_UP_ASK || HW_UP) return;   // dvojklik neposiela druhu otazku
    // Stav sa zaklada AZ ked mame kam poslat: bez kanala by uz nikdy neprisla
    // odpoved, ktora ho vycisti, a tlacidlo by ostalo natrvalo mrtve.
    if (!(window.sketchup && sketchup.drawer_upgrade_impact)) return;
    var tok = hwUpToken();
    HW_UP_ASK = { token: tok, offer: o };
    NX.setStatus('Počítam, čo prechod na novú verziu zmení…');
    sketchup.drawer_upgrade_impact(nxDocPayload({
      cabinet_id: o.cabinet_id, front_id: o.front_id,
      from: o.from, to: o.to, up_token: tok }));
  }

  // Odpoved citacieho callbacku. Cudzi token (starsia otazka) sa zahadzuje.
  function onHwUpgradeImpact(res, token){
    if (!HW_UP_ASK || String(token || '') !== String(HW_UP_ASK.token || '')) return;
    var offer = HW_UP_ASK.offer;
    HW_UP_ASK = null;
    var r = (res && typeof res === 'object') ? res : {};
    if (r.ok !== true){
      NX.setStatus('Na novú verziu sa prejsť nedá: ' + String(r.reason || 'neznámy dôvod'), true);
      return;
    }
    if (typeof NXModal === 'undefined' || !NXModal || typeof NXModal.open !== 'function'){
      NX.setStatus(HW_UP_NOMODAL, true);
      return;
    }
    NX.setStatus('');
    hwUpOpenModal(offer, r);
  }

  function hwUpOpenModal(offer, imp){
    NXModal.open({
      title: 'Prejsť na novú verziu receptu',
      sub: String(imp.to_title || offer.to || ''),
      note: String(imp.release_note || ''),
      okLabel: 'Prejsť',
      size: 'md',
      // Kym zapis bezi, okno sa NEDA zavriet: zatvorenie by vycistilo len nas
      // stav, ale mutacia by na serveri prebehla dalej — „zrušená" akcia by aj
      // tak prestavala zasuvku (Codex #315 kolo 1 P2). Smieme to zapnut, lebo
      // server odpoveda v KAZDEJ vetve vratane vynimky.
      busyLock: true,
      // Tabulka dopadu je ZOBRAZOVACI blok (`custom` bez `read`) — do
      // `values()` sa nedostane a odoslat sa z nej neda nic. Odosielaju sa
      // VYHRADNE `from`/`to` z payloadu.
      fields: [{ key: 'impact', type: 'custom',
                 render: function(host){ hwUpImpactRender(host, imp); } }],
      onSubmit: function(){
        if (!HW_UP || HW_UP.sent) return;      // dvojklik nezapise dvakrat
        // Zamknut okno smieme AZ ked mame kam poslat — inak by ho neodomkla
        // ziadna odpoved (odomyka VYHRADNE volajuci, kontrakt D-15).
        if (!(window.sketchup && sketchup.upgrade_drawer_recipe)) return;
        var tok = hwUpToken();
        HW_UP.token = tok;
        HW_UP.sent = true;
        NXModal.clearErrors();
        NXModal.setBusy(true);
        // `fingerprint` = ODTLACOK NAHLADU zo servera. Klient ho LEN VRACIA
        // (nic z neho neskladá a nic si nedopocitava); server ho pred zapisom
        // prepocita a pri nezhode zapis odmietne — bez neho by sa dal zapisat
        // iny dopad, nez ktory pouzivatel potvrdil (Codex #315 kolo 1 P1).
        sketchup.upgrade_drawer_recipe(nxDocPayload({
          cabinet_id: offer.cabinet_id, front_id: offer.front_id,
          from: offer.from, to: offer.to,
          fingerprint: String((HW_UP.impact && HW_UP.impact.fingerprint) || ''),
          up_token: tok }));
      },
      onClose: function(){ HW_UP = null; }
    });
    // AZ ZA `open`: kostra najprv zatvara predchadzajuci modal, takze jeho
    // `onClose` by novy stav hned vynuloval (vzor D2b).
    HW_UP = { token: null, sent: false, offer: offer, impact: imp };
  }

  // Odpoved servera na ZAPIS z modalu. Uspech okno zatvara (panel je vtedy uz
  // prekresleny plnym pushom), zlyhanie ho ODOMKNE a hlasku ukaze V NOM.
  function onHwUpgradeResult(ok, msg, token){
    if (!HW_UP || String(token || '') !== String(HW_UP.token || '')) return;
    if (typeof NXModal === 'undefined' || !NXModal) return;
    if (ok){
      HW_UP = null;
      NXModal.setBusy(false, { clear: true });
      NXModal.close();
      return;
    }
    HW_UP.sent = false;
    NXModal.setBusy(false);
    NXModal.showErrors([{ msg: msg || 'Prechod na novú verziu sa neuložil.' }]);
  }

  // TABULKA DOPADU. Vsetky cisla su zo servera — panel ich len parauje do
  // dvojic „teraz -> po prechode" a nikdy nic nedopocitava (verzia moze zmenit
  // prahy, rad NL, hrubky aj ABS bez zmeny konstant, Astra #20 F13).
  function hwUpImpactRender(host, imp){
    if (!host) return;
    var rows = '';
    rows += hwUpRow(hwUpHeightLabel(imp.height),
                    hwUpVal(imp.height), hwUpVal(imp.height, true));
    rows += hwUpRow('Dĺžka výsuvu (NL)', hwUpVal(imp.nl), hwUpVal(imp.nl, true));
    (Array.isArray(imp.parts) ? imp.parts : []).forEach(function(p){
      rows += hwUpRow(hwUpCap(p && p.label), hwUpDims(p && p.from), hwUpDims(p && p.to));
    });
    rows += hwUpRow('Objednávací kód', hwUpCodes(imp.kit && imp.kit.from),
                    hwUpCodes(imp.kit && imp.kit.to));
    var locks = (Array.isArray(imp.locks) ? imp.locks : []).map(function(l){
      return hwUpLockLabel(l);
    }).filter(function(t){ return !!t; });
    var note = locks.length
      ? 'Ručné zámky sa prenesú bez zmeny hodnoty: ' + locks.join(' · ') + '.'
      : 'Na tejto zásuvke nie je žiadny ručný zámok.';
    host.innerHTML = '<table class="dwuptab"><thead><tr><th></th><th>teraz</th>'
                   + '<th>po prechode</th></tr></thead><tbody>' + rows + '</tbody></table>'
                   + '<div class="hint">' + esc(note) + '</div>';
  }
  function hwUpRow(label, a, b){
    var same = (a === b);
    return '<tr' + (same ? ' class="same"' : '') + '><th>' + esc(label) + '</th>'
         + '<td>' + esc(a) + '</td><td>' + esc(b) + '</td></tr>';
  }
  // Hodnota jednej osi. Ktore pole os nesie a v akej jednotke, hovori SERVER
  // (`kind`): Atira ma vyskovy VARIANT („H144"), QUADRO vysku boxu v mm
  // (Codex #315 kolo 1 P2) — panel si to neodvodzuje zo systemu.
  function hwUpVal(pair, wantTo){
    var v = pair ? (wantTo ? pair.to : pair.from) : null;
    if (v == null || v === '') return '—';
    var k = pair && pair.kind;
    if (k === 'variant') return 'H' + String(v);
    if (k === 'box') return String(v).replace('.', ',') + ' mm';
    return String(v).replace('.', ',');
  }
  function hwUpHeightLabel(pair){
    return (pair && pair.kind === 'box') ? 'Výška boxu' : 'Výška';
  }
  // „791,5 × 480 × 16 mm" — rozmery su Cisla zo servera, formatuje sa len
  // desatinna ciarka (slovensky zapis, rovnako ako zvysok panela).
  function hwUpDims(dims){
    if (!Array.isArray(dims) || !dims.length) return '—';
    return dims.map(function(v){ return String(v).replace('.', ','); }).join(' × ') + ' mm';
  }
  function hwUpCodes(list){
    if (!Array.isArray(list) || !list.length) return '—';
    return list.join(', ');
  }
  function hwUpLockLabel(l){
    if (!l || l.value == null) return '';
    if (l.axis === 'height') return 'výška H' + String(l.value);
    if (l.axis === 'nl') return 'NL ' + String(l.value);
    return String(l.axis) + ' ' + String(l.value);
  }
  function hwUpCap(s){
    var t = String(s == null ? '' : s);
    return t ? t.charAt(0).toUpperCase() + t.slice(1) : 'Dielec';
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
  // OBAL a OBSAH su ZVLAST (vzor `rowsHtml`/`rowsInnerHtml` v nx_modal.js):
  // zivy refresh po zmene katalogu prepisuje LEN obsah, takze uzol bloku
  // prezije a nic ine v sekcii sa nedotkne.
  function hwManualInnerHtml(list){
    var items = list || ((typeof hwManualView !== 'undefined' && hwManualView) ? hwManualView : []);
    var rows = items.map(hwManualItemHtml).join('');
    return (rows ? '<div class="hwmanh">Ručne pridané</div>' + rows : '')
      + '<div class="hwmanadd"><button type="button" class="ghostbtn hwmanbtn"'
      + ' title="Konkrétna položka mimo setov — pripne sa ku skrinke alebo k dielcu"'
      + ' onclick="onHwManualAdd()">' + NXIcons.svg('plus')
      + ' Pridať konkrétnu položku (mimo setov)</button></div>';
  }
  function hwManualHtml(list){
    return '<div class="hwman" id="hwManBlock">' + hwManualInnerHtml(list) + '</div>';
  }

  // ZIVY refresh riadkov ad-hoc poloziek (Codex #285 P2-D) — bez plneho pushu
  // vyberu. Prekresluje LEN vlastny blok: boxy vlastnikov, rozpisany pocet ani
  // vyber setu sa nedotknu (vzor `refreshHardwarePurchase`).
  function refreshHardwareManual(view){
    hwManualView = Array.isArray(view) ? view : [];
    var block = el('hwManBlock');
    if (!block) return false;                        // sekcia nie je vykreslena
    block.innerHTML = hwManualInnerHtml();
    return true;
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
      onSubmit: function(v){ hwManualSubmit(v, item); },
      // P2-G: zatvorenie (Escape, scrim, krizik, „Zrušiť" aj nase vlastne)
      // stav VZDY vycisti. Bez toho by po beznom zatvoreni ostal visiet a
      // najblizsia zmena vyberu by hlasila „okno sa zavrelo, nič sa
      // neuložilo" — hoci ho pouzivatel zavrel sam.
      onClose: function(){ HW_MAN = null; }
    });
    // AZ ZA `open`: kostra najprv zatvara predchadzajuci modal, takze jeho
    // `onClose` by novy stav hned vynuloval.
    HW_MAN = { id: item ? String(item.id) : null, kind: item ? 'edit' : 'add',
               sent: false, token: null,
               // P2-F: draft prezije prepinanie zdroja — su v nom aj hodnoty
               // toho zdroja, ktory prave nie je vykresleny.
               draft: draft || hwManualDraft(item) };
  }
  function onHwManualAdd(){ hwManualOpen(null, null); }
  function onHwManualEdit(btn){
    var it = hwManualFind(btn.getAttribute('data-id'));
    if (!it){ NX.setStatus('Položka sa medzitým zmenila — panel sa obnovil.', true); return; }
    hwManualOpen(it, null);
  }
  // Vliatie VIDITELNYCH hodnot do draftu. Kluce, ktore prave vykreslene nie su
  // (druhy zdroj), sa NEPREPISUJU — draft si ich drzi dalej. CISTA funkcia.
  //
  // Codex #285 kolo 2 P2-F: predtym sa draft skladal z ULOZENEJ polozky +
  // prave vykreslenych poli, takze cesta „voľná -> katalóg -> voľná" zahodila
  // napisany nazov aj cenu (a rovnako nevybrany dotaz katalogu). Hodnoty
  // NEAKTIVNEHO zdroja ziju VYHRADNE v drafte — do `values()` ani do configu
  // sa nedostanu (`hwManualRecord` cita len polia svojho zdroja).
  var HW_MAN_DRAFT_KEYS = ['owner', 'qty', 'note', 'code', 'code_text', 'name', 'unit', 'price'];

  function hwManualMergeDraft(base, values, queryText){
    var d = {};
    var b = base || {};
    var k;
    for (k in b){ if (Object.prototype.hasOwnProperty.call(b, k)) d[k] = b[k]; }
    var v = values || {};
    HW_MAN_DRAFT_KEYS.forEach(function(key){
      if (v[key] != null) d[key] = String(v[key]);
    });
    if (v.source === 'free' || v.source === 'catalog') d.source = v.source;
    // Nevybrany dotaz katalogu nie je vo `values()` (kontrakt `lookup` vracia
    // LEN kod) — cita sa z pola hladania, inak by sa prepnutim stratil.
    if (queryText != null) d.code_text = String(queryText);
    return d;
  }

  // Prepnutie „Zdroj" meni SADU POLI, a tu kostra D-15 za behu nevymiena —
  // modal sa preto otvori znova s TYM, CO UZ POUZIVATEL NAPISAL. Hodnoty nesie
  // DRAFT MODALU (nie pamat: tá porovnava proti defaultom a hodnoty druheho,
  // prave nevykresleneho zdroja by nemala proti comu merat).
  function hwManualCtxSwitch(){
    if (!HW_MAN || typeof NXModal === 'undefined' || !NXModal.isOpen || !NXModal.isOpen()) return;
    if (NXModal.isBusy && NXModal.isBusy()) return;   // bezi zapis — nesahat
    var item = HW_MAN.id ? hwManualFind(HW_MAN.id) : null;
    var qn = (typeof el === 'function') ? el('nxm_code_q') : null;
    var base = HW_MAN.draft || hwManualDraft(item);
    var d = hwManualMergeDraft(base, NXModal.values(), qn ? qn.value : null);
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
    // P2-G: hlasi sa LEN skutocne zatvorenie. Ked uz okno otvorene nie je
    // (pouzivatel ho zavrel sam), nema sa co ohlasovat — hlaska „nič sa
    // neuložilo" by tvrdila, ze o nieco prisiel.
    if (!open){ HW_MAN = null; return false; }
    HW_MAN = null;
    HW_MAN_Q.gen++;      // bezuce hladanie uz nema komu odpovedat
    HW_MAN_Q.done = null;
    if (typeof NXModal.close === 'function') NXModal.close();
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

  // ===== KOV-G2 (D-111): RIADOK „NOHY" v Zakladnych ========================
  //
  // Doteraz sa dalo zistit, ake nohy skrinka dostane, az v Nakupe (predvolba
  // setu podla vysky sokla zila schovana v Predvolbach projektu). Riadok stoji
  // pod rozmermi a ma DVE cesty, ale JEDEN vzhlad:
  //   * OZNACENA skrinka — text z `legs_summary` (payload `cabinet_payload`,
  //     teda z ULOZENYCH poloziek) + select setu noh; ten select je TEN ISTY
  //     ovladac ako v Kovanie -> Sety (`hwCabOptionList` + `onHwSet`), takze
  //     zmena na jednom mieste sa cez server push objavi aj na druhom,
  //   * VKLADANIE — text z read-only callbacku `insert_legs_preview`; ziadny
  //     ovladac (override sa robi az na vlozenej skrinke).
  //
  // TEXT SKLADA SERVER. Panel z poloziek nic neodvodzuje ani nedopocitava —
  // inak by si vymyslel vlastne vety a pri prvej zmene expanzie by klamali.
  var LEGS_DASH = '—';
  var LEGS_TYPE = 'leg';

  function nxLegsRowEl(){ return el('legsRow'); }

  // Skryty riadok sa aj VYPRAZDNI — inak by pri prepnuti na hornu skrinku
  // ostal v DOM select cudzej skrinky a najblizsi `refreshHardwareSets` by mu
  // obnovoval ponuku.
  function nxLegsHideRow(){
    var row = nxLegsRowEl(); if (!row) return false;
    row.hidden = true;
    row.classList.remove('warn');
    var sel = el('legsSel'); if (sel) sel.innerHTML = '';
    var b = el('legsTxt'); if (b){ b.textContent = LEGS_DASH; b.setAttribute('title', ''); }
    return false;
  }

  // Text + ton do riadku. `title` nesie CELE znenie — riadok sa oreza (jeden
  // riadok panela), tooltip nie.
  function nxLegsSetText(text, tone, title){
    var row = nxLegsRowEl(); if (!row) return false;
    var b = el('legsTxt');
    var txt = String(text === null || text === undefined || text === '' ? LEGS_DASH : text);
    if (b){ b.textContent = txt; b.setAttribute('title', String(title || txt)); }
    row.classList.toggle('warn', tone === 'warn');
    row.hidden = false;
    return true;
  }

  // Tooltip riadku pri OZNACENEJ skrinke: cely text + ucinny set (ten sa do
  // riadku uz nezmesti, ale je to prave ta odpoved na „podla coho to je").
  function nxLegsTitle(summary){
    var t = String((summary && summary.text) || LEGS_DASH);
    var name = summary && summary.set_name ? String(summary.set_name) : '';
    return name ? (t + ' — set „' + name + '“') : t;
  }

  // OZNACENA skrinka. `summary` = `legs_summary` servera; ponuku setu berie
  // z TEJ ISTEJ mapy, akou sa kresli skupina Sety (`HW_SET_OPTIONS`), preto sa
  // vola AZ PO `renderHardware`.
  function renderLegsRow(summary, cabId){
    var tone = (summary && summary.tone) ? String(summary.tone) : 'none';
    if (!summary || tone === 'none') return nxLegsHideRow();
    nxLegsSetText(summary.text, tone, nxLegsTitle(summary));
    var box = el('legsSel');
    if (box){
      var entry = hwSetEntry(LEGS_TYPE);
      var list = entry ? hwCabOptionList(entry) : null;
      box.innerHTML = list
        ? hwSetSelectHtml(list, LEGS_TYPE, '', cabId || '', hwCabTitle(entry))
        : '';
    }
    return true;
  }

  // --- VKLADANIE: dotaz s generaciou ---------------------------------------
  // Odpovede chodia asynchronne; `gen` rastie a odpoved STARSIEHO kola sa
  // zahodi (vzor `hw_manual_search`). Debounce, aby pisanie sirky netrhalo
  // server pri kazdom pismene.
  var LEGS_DEBOUNCE_MS = 150;
  var legsGen = 0;
  var legsTimer = null;

  function nxLegsInsertMode(){
    if (typeof selectedCabId !== 'undefined' && selectedCabId) return false;
    if (typeof NXInsert === 'undefined' || !NXInsert || !NXInsert.state) return false;
    if (NXInsert.state.kind === 'board') return false;
    return NXInsert.state.lastMode === 'insert';
  }

  // KOV-G2 (Codex #339 kolo 1 N1): SABLONA nesie aj KOVANIE — mapovanie setov
  // a ich zmrazene definicie. Do nahladu ide TEN ISTY zdroj, aky pojde do
  // `insert_cabinet` (`NXInsert.hardwarePayload()` cez `HARDWARE_KEYS`), takze
  // karta aj ghost ukazu presne tie nohy, ktore vlozena skrinka dostane —
  // predtym nahlad vzdy hovoril o projektovej predvolbe. Ad-hoc polozky
  // (`HARDWARE_LIST_KEYS`) do nahladu NEIDU: nohy nikdy nevznikaju rucne.
  // Server ma pre tieto kluce VLASTNU branu (`INSERT_LEGS_HW_KEYS`) a nic
  // z nich neuklada.
  function nxLegsTemplateHw(){
    var out = {};
    if (typeof NXInsert === 'undefined' || !NXInsert ||
        typeof NXInsert.hardwarePayload !== 'function') return out;
    var hw = NXInsert.hardwarePayload() || {};
    (NXInsert.HARDWARE_KEYS || []).forEach(function(k){ if (hw[k]) out[k] = hw[k]; });
    return out;
  }

  // Payload je UZAVRETY: typ, sirka, vyska sokla, rezim sokla a kovanie
  // SABLONY. Nic z neho sa neuklada a nic z toho, co pride SPAT, sa nikdy
  // nedostane do `collectAll()` — riadok je VYSTUP, nie pole formulara.
  function nxLegsInsertPayload(){
    var w = numv('width');
    var fh = numv('floor_height');
    var body = { gen: ++legsGen, type: getType(),
                 width: isNaN(w) ? '' : w, floor_height: isNaN(fh) ? '' : fh,
                 plinth_mode: val('plinth_mode') };
    var hw = nxLegsTemplateHw();
    Object.keys(hw).forEach(function(k){ body[k] = hw[k]; });
    return body;
  }

  function nxLegsInsertSend(){
    legsTimer = null;
    if (!nxLegsInsertMode()) return false;
    if (getType() === 'upper') return nxLegsHideRow();
    var body = nxLegsInsertPayload();
    // Kym server odpovie, riadok drzi miesto s pomlckou — a ked odpoved
    // nepride vobec (starsi plugin bez callbacku), ostane pri nej.
    nxLegsSetText(LEGS_DASH, 'ok', 'Nohy sa dopočítavajú…');
    if (window.sketchup && sketchup.insert_legs_preview){
      sketchup.insert_legs_preview(typeof nxDocPayload === 'function'
        ? nxDocPayload(body) : JSON.stringify(body));
      return true;
    }
    return false;
  }

  // `onField` bezi pri KAZDOM poli karty — dotaz sa preto posiela len vtedy,
  // ked sa zmenilo nieco, na com nohy naozaj zavisia (typ, sirka, vyska sokla,
  // rezim sokla). Podmienka „a riadok uz stoji" je samoliecba: po navrate
  // z oznacenej skrinky je riadok skryty, hoci hodnoty su tie iste.
  var legsLastKey = null;

  function nxLegsInsertAsk(){
    if (!nxLegsInsertMode()) return false;
    var body = nxLegsInsertPeek();
    var row = nxLegsRowEl();
    if (legsLastKey === body && row && !row.hidden) return false;
    legsLastKey = body;
    if (legsTimer) clearTimeout(legsTimer);
    legsTimer = setTimeout(nxLegsInsertSend, LEGS_DEBOUNCE_MS);
    return true;
  }

  // Kluc vstupov BEZ zvysenia generacie (`nxLegsInsertPayload` ju zvysuje —
  // volat ho na porovnanie by generacie roztocilo a odpovede by sa zahadzovali).
  // KOV-G2 (N1): sucastou kluca je aj kovanie SABLONY — dve sablony s rovnakymi
  // rozmermi a INYM setom noh musia dat dva rozne dotazy.
  function nxLegsInsertPeek(){
    var w = numv('width');
    var fh = numv('floor_height');
    return [getType(), isNaN(w) ? '' : w, isNaN(fh) ? '' : fh, val('plinth_mode'),
            JSON.stringify(nxLegsTemplateHw())].join('|');
  }

  // KOV-G2 (Codex #339 kolo 1 N3): ZNEPLATNENIE DOTAZU V LETE. Odpovede chodia
  // asynchronne, takze samotne skrytie riadku nestaci — odpoved na dotaz, ktory
  // uz neplati (prepnutie na hornu skrinku, na dosku, oznacenie skrinky), by
  // riadok znova ukazala a ostal by v karte visiet. Generacia sa preto zdvihne
  // aj tu: cakajuca odpoved uz ziadnej negeneruje.
  function nxLegsInsertDrop(){
    if (legsTimer){ clearTimeout(legsTimer); legsTimer = null; }
    legsGen++;
    return false;
  }

  // Odchod z vkladania (oznacenie skrinky, doska) — riadok zmizne, dotaz v lete
  // sa zneplatni a pamat vstupov sa zrusi, aby sa po navrate poslal znova.
  function nxLegsInsertReset(){
    nxLegsInsertDrop();
    legsLastKey = null;
    return nxLegsHideRow();
  }

  // KOV-G2 (Codex #339 kolo 2 N1): ZNEPLATNENIE PAMATE VSTUPOV. Nohy zavisia
  // aj od veci, ktore v karte NESTOJA — projektove mapovanie setu noh, samotna
  // definicia setu a nazvy jeho katalogovych poloziek. Tie sa daju zmenit
  // v subezne otvorenom Studiu a prichadzaju lahkym pushom (`setHardwareSets`),
  // v kluci `nxLegsInsertPeek` vsak ziadna z nich nie je. Bez tohto kroku by
  // vkladacia karta slubovala STARE nohy az do zmeny rozmeru alebo prepnutia
  // vyberu. Pamat sa preto zahodi a nahlad sa vypyta znova TOU ISTOU cestou
  // (debounce + generacia); mimo vkladania sa nedeje nic.
  function nxLegsInsertInvalidate(){
    if (!nxLegsInsertMode()) return false;
    legsLastKey = null;
    return nxLegsInsertAsk();
  }

  // Odpoved servera. Starsia generacia sa ZAHODI (pomalsie kolo nesmie prepisat
  // cerstvejsi vysledok) a rovnako sa zahodi odpoved, ktora dosla uz po
  // oznaceni skrinky (vtedy riadok patri jej payloadu) alebo po prepnuti na iny
  // typ — riadok patri VYHRADNE dolnej skrinke (N3).
  function nxLegsInsertResult(res){
    if (!res || Number(res.gen) !== legsGen) return false;
    if (!nxLegsInsertMode()) return false;
    if (getType() !== 'lower') return false;
    if (String(res.tone || 'none') === 'none') return nxLegsHideRow();
    return nxLegsSetText(res.text, String(res.tone), res.text);
  }

  // Viditelnost podla typu — presne ako `#fhRow` (horna skrinka nohy nema).
  // Pri prechode na hornu skrinku sa uz nic nedopytuje a dotaz V LETE sa
  // zneplatni (N3) — inak by ho neskora odpoved riadok znova ukazala.
  function nxLegsApplyVisibility(t){
    if (t === 'upper'){ nxLegsInsertDrop(); return nxLegsHideRow(); }
    if (nxLegsInsertMode()) return nxLegsInsertAsk();
    return true;
  }

  // Node testy (tests/js/test_hw_panel_sets.js) — LEN ciste funkcie ponuky
  // setov (bez DOM). V CEF je module undefined a vetva sa preskoci.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { hwSetOptionList: hwSetOptionList, hwOwnerOptionList: hwOwnerOptionList,
      hwCabOptionList: hwCabOptionList, hwFindEntry: hwFindEntry, hwOwnerDesc: hwOwnerDesc,
      HW_SET_PARAM: HW_SET_PARAM,
      // KOV-D1b: ponuka setu pre KLASIFIKOVANU zasuvku (server posiela hotovy
      // rozsah `entry.compat`) — tests/js/test_kovd1b_ui.js
      HW_SET_STORED: HW_SET_STORED, hwCompatScope: hwCompatScope, hwCabRowOff: hwCabRowOff,
      hwCompatPick: hwCompatPick, hwCompatOptionList: hwCompatOptionList,
      hwCompatTitle: hwCompatTitle, hwSetPayload: hwSetPayload,
      hwOwnerTitle: hwOwnerTitle, hwCabTitle: hwCabTitle,
      // D-92 rozpis nakupu (tests/js/test_d92_hw_nakup.js)
      hwMemberText: hwMemberText, hwBuyLine: hwBuyLine, HW_NO_CATALOG: HW_NO_CATALOG,
      // D-93 rucny NL vysuvu (tests/js/test_d93_nl_override.js) — hwNlHtml a
      // hwPayload potrebuju globalne esc/NXIcons, test si ich podstrci.
      hwNlFmt: hwNlFmt, hwNlOptionList: hwNlOptionList, hwNlAutoText: hwNlAutoText,
      hwNlSelectTitle: hwNlSelectTitle, hwNlLockTitle: hwNlLockTitle,
      hwNlHtml: hwNlHtml, hwPayload: hwPayload,
      // KOV-D2b chipy osi zamku (tests/js/test_kovd2b_ui.js) — ciste texty
      // a ponuky + CELY tok kliku cez mini-DOM (chip -> payload servera).
      HW_AX: HW_AX, HW_AX_OPTS_MIN: HW_AX_OPTS_MIN, HW_AX_NOVAL: HW_AX_NOVAL,
      HW_AX_NOMODAL: HW_AX_NOMODAL, HW_AX_BLOCKED: HW_AX_BLOCKED,
      hwAxState: hwAxState, hwAxValText: hwAxValText, hwAxText: hwAxText,
      hwAxOptionList: hwAxOptionList, hwAxChipTitle: hwAxChipTitle,
      hwAxFixSub: hwAxFixSub, hwAxFixLabel: hwAxFixLabel, hwAxHtml: hwAxHtml,
      hwAxIdent: hwAxIdent, onHwAxChip: onHwAxChip, onHwAxPick: onHwAxPick,
      onHwAxUnlock: onHwAxUnlock, onHwAxFix: onHwAxFix, onHwAxResult: onHwAxResult,
      hwAxModalState: function(){ return HW_AX_MODAL; },
      // KOV-D3b prechod na novsiu verziu receptu (tests/js/test_kovd3b_ui.js) —
      // markup ponuky + CELY tok cez mini-DOM (klik -> dopad -> potvrdenie ->
      // odpoved servera).
      HW_UP_NOMODAL: HW_UP_NOMODAL,
      hwUpHtml: hwUpHtml, hwUpOffer: hwUpOffer, hwUpDims: hwUpDims,
      hwUpCodes: hwUpCodes, hwUpLockLabel: hwUpLockLabel, hwUpImpactRender: hwUpImpactRender,
      hwUpVal: hwUpVal, hwUpHeightLabel: hwUpHeightLabel,
      onDrawerUpgrade: onDrawerUpgrade, onHwUpgradeImpact: onHwUpgradeImpact,
      onHwUpgradeResult: onHwUpgradeResult,
      hwUpAskState: function(){ return HW_UP_ASK; },
      hwUpModalState: function(){ return HW_UP; },
      // UI-C4 boxy vlastnikov (tests/js/test_uic4_kovanie.js) — ciste skladanie
      // skupin z owner dat, ziadny DOM.
      hwGroupKeyOf: hwGroupKeyOf, hwLabelHead: hwLabelHead, hwLabelTail: hwLabelTail,
      hwRowOwnerText: hwRowOwnerText, hwGroupTitle: hwGroupTitle,
      hwGroupCountText: hwGroupCountText, hwGroupOrder: hwGroupOrder,
      hwGroups: hwGroups, hwDisabledOffs: hwDisabledOffs, hwOffLabel: hwOffLabel,
      hwOffName: hwOffName,
      // KOV-D4 deep-link z Kontroly (tests/js/test_kovd4_ui.js) — selektor
      // riadku je cisty, `nxFocusHardware` a `hwFlash` sa testuju cez mini-DOM.
      HW_FLASH_MS: HW_FLASH_MS, hwRowSelector: hwRowSelector, hwRowKindOk: hwRowKindOk,
      hwFlashTargetOf: hwFlashTargetOf, hwFlash: hwFlash, hwFlashClear: hwFlashClear,
      nxFocusHardware: nxFocusHardware,
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
      hwManualHtml: hwManualHtml, hwManualInnerHtml: hwManualInnerHtml,
      hwManualOwnerOptions: hwManualOwnerOptions,
      hwManualItemText: hwManualItemText, hwManualDraft: hwManualDraft,
      hwManualFields: hwManualFields, hwManualHit: hwManualHit,
      hwManualMergeDraft: hwManualMergeDraft,
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
      refreshHardwareManual: refreshHardwareManual,
      hwManualState: function(){ return HW_MAN; },
      // KOV-G2 riadok Noh (tests/js/test_kovg2_nohy_ui.js) — CELY tok cez
      // mini-DOM: viditelnost podla typu, dotaz s generaciou, odpoved servera
      // a select setu pri oznacenej skrinke.
      LEGS_DASH: LEGS_DASH, LEGS_TYPE: LEGS_TYPE, LEGS_DEBOUNCE_MS: LEGS_DEBOUNCE_MS,
      nxLegsHideRow: nxLegsHideRow, nxLegsSetText: nxLegsSetText, nxLegsTitle: nxLegsTitle,
      renderLegsRow: renderLegsRow, nxLegsInsertMode: nxLegsInsertMode,
      nxLegsInsertPayload: nxLegsInsertPayload, nxLegsInsertSend: nxLegsInsertSend,
      nxLegsInsertAsk: nxLegsInsertAsk, nxLegsInsertResult: nxLegsInsertResult,
      nxLegsInsertPeek: nxLegsInsertPeek, nxLegsInsertReset: nxLegsInsertReset,
      nxLegsTemplateHw: nxLegsTemplateHw, nxLegsInsertDrop: nxLegsInsertDrop,
      nxLegsApplyVisibility: nxLegsApplyVisibility,
      nxLegsInsertInvalidate: nxLegsInsertInvalidate,
      legsGenState: function(){ return legsGen; },
      // Zivy refresh ponuky setov a zapis vyberu — riadok Noh ich zdiela
      // s kontextom Kovanie (ziadny vlastny kanal).
      refreshHardwareSets: refreshHardwareSets, onHwSet: onHwSet, hwSetEntry: hwSetEntry };
  }
