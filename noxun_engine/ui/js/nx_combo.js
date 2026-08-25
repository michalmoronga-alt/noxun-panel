  // ===================== D-85 / UI-03: ZDIELANY COMBOBOX MATERIALOV A ABS =====
  // JEDEN komponent pre VSETKY vybery materialu a ABS pasky v paneli. Merac D-25
  // naratal 400+ interakcii s tymito rozbalovackami — od tejto davky sa v nich
  // PISE (filter bez diakritiky), navrchu su "Pouzite v projekte" a "Naposledy
  // pouzite" a az potom cely katalog.
  //
  // ARCHITEKTURA (vedome najmenej invazivna):
  //   Komponent <select> NENAHRADZA — OBALUJE ho. Povodny <select> ostava v DOM
  //   (skryty, mimo tab poradia) a je NADALEJ JEDINYM zdrojom pravdy:
  //     * moznosti sa citaju z jeho <option>/<optgroup> — takze VSETKA logika,
  //       ktora ich sklada (hrubkove filtre D-45, ABS skupiny D-36/2A-3b, texty
  //       "(podla pravidla — …)" D-102, duplaky D-49, disabled "(nekompatibilne)")
  //       plati bez jedineho riadku duplikatu,
  //     * vyber zapise `sel.value` a vystreli `change` — teda IDENTICKA cesta ako
  //       klik v nativnej rozbalovacke. Vsetky guardy na nej (E-03 hrubka,
  //       D-86 smer dekoru, D-41 modal chybajucej pasky, identity guardy
  //       cabinet_id/board_id) preto prezivaju nedotknute.
  //   Skryvanie je na ATRIBUTE `data-nx-combo`, nie na triede: panel selectom
  //   prepisuje `className` ('ovr' override), co by triedu zmazalo.
  //
  // CEF poucenia (D-67 suggest, D-105 overlay):
  //   * <datalist> v CEF NEFUNGUJE (klik nezapise) — preto vlastny dropdown,
  //   * vyber ide MOUSEDOWN-om (blur by okno zavrel skor, nez klik dopadne),
  //   * popup je `position: fixed` NAD body — ziadny predok ho neoreze
  //     (`overflow:auto` kontajnera je klasicka pasca),
  //   * podla mockupu (SYSTEM/zdroje/ui20/mockup_inspector_c.html) sa otvara
  //     DOLAVA (`right` hrana lici s triggerom) a je siroky max(trigger, 270 px).
  (function(global){
    'use strict';

    var KIND_ATTR   = 'data-nx-combo';       // 'decor' | 'abs'
    // PICKER-2: kontext výberu pre PREDVOLENÚ hrúbku dekorového riadku
    // ('body' | 'front' | 'back' | 'worktop'); chýbajúci = najtenšia konštrukčná.
    var CTX_ATTR    = 'data-nx-combo-ctx';
    var RECENT_MAX  = 5;
    var RECENT_KEYS = { decor: 'nx_recent_decor', abs: 'nx_recent_abs' };
    // Volby, ktore NIE SU katalogove id — dedenie / "podla pravidla" / "Bez ABS".
    // Nikdy sa nedostanu do "naposledy pouzite" a v ponuke stoja navrchu bez hlavicky.
    var FIXED_VALUES = ['', '__inherit__'];
    var POP_MIN_W    = 270;
    // PICKER-1: strop citatelnosti. Ponuka sa roztiahne na to, co okno naozaj
    // ma (panel ~470 px, Štúdio aj cez 1200) — ale nie donekonecna: riadok
    // sirsi nez toto sa uz necita, len sa po nom oci naháňajú.
    var POP_MAX_W    = 620;
    var POP_MARGIN   = 6;

    // ---------------------------------------------------------------- ciste funkcie
    // (bez DOM — testuje ich tests/js/test_ui03_combobox.js)

    // Diakriticky necitlive porovnanie: NFD rozklad + zahodenie combining znakov
    // (\u0300-\u036f — explicitne escapy, ziadne neviditelne znaky v kode).
    // Zrkadlo mdNormText z okna Materialy (D-67): "cremona" najde "Cremona",
    // "modra" najde "Pastelová modrá".
    function nxNormText(s){
      return String(s == null ? '' : s).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
    }

    function nxComboIsFixed(value){
      return FIXED_VALUES.indexOf(String(value == null ? '' : value)) >= 0;
    }

    // Zhoda polozky s dotazom — hlada sa v labeli AJ v hodnote (id nesie kod).
    function nxComboHit(item, q){
      if (!q) return true;
      var n = nxNormText(q);
      // PICKER-2: dekorový riadok nesie aj hrúbky svojich variantov a slovo
      // „duplák" (`searchExtra`) — inak by zlúčenie schovalo „36" pred
      // vyhľadávaním, ktoré dovtedy fungovalo.
      return nxNormText(item.label).indexOf(n) >= 0 || nxNormText(item.value).indexOf(n) >= 0 ||
             (item.searchExtra ? nxNormText(item.searchExtra).indexOf(n) >= 0 : false);
    }

    // Rozpad textu na useky pre zvyraznenie zhody. CISTA funkcia — vracia
    // segmenty, escapovanie a <mark> robi az renderer (XSS kontrakt).
    function nxComboHighlight(text, q){
      var t = String(text == null ? '' : text);
      if (!q) return [{ text: t, hit: false }];
      var i = nxNormText(t).indexOf(nxNormText(q));
      if (i < 0) return [{ text: t, hit: false }];
      // Dlzka zhody v POVODNOM texte: normalizacia diakritiku len odstranuje
      // (1 znak = 1 znak), takze dlzka dotazu sedi.
      var len = String(q).length;
      var out = [];
      if (i > 0) out.push({ text: t.slice(0, i), hit: false });
      out.push({ text: t.slice(i, i + len), hit: true });
      if (i + len < t.length) out.push({ text: t.slice(i + len), hit: false });
      return out;
    }

    // Sekcie ponuky. Poradie je kontrakt UI 2.0 (mockup C, schvaleny 18.8.):
    //   1. fixne volby (dedit / podla pravidla / Bez ABS) — bez hlavicky, vzdy hore,
    //   2. Pouzite v projekte  (id zo serveroveho payloadu materials.used_ids),
    //   3. Naposledy pouzite   (localStorage tohto pocitaca, max 5),
    //   4. zvysok katalogu     — cleneny podla <optgroup> (ABS: "Odporucane k dekoru"
    //      / "Ostatne" — D-36 clenenie sa NESMIE stratit), inak jedna sekcia s poctom.
    // Polozka sa v ponuke objavi PRAVE RAZ (skupiny 2/3 ju zo zvysku vyberu); aby
    // sa clenenie katalogu nestratilo, nesie kazdy riadok meno svojej <optgroup>
    // ako podtitul (renderer).

    // ======================= PICKER-2: RIADOK = DEKOR =======================
    //
    // Michal 25.8.: „ten istý dekor mám v zozname trikrát — 18, 36 a duplák —
    // a musím sa v tom hrabať." Riadok ponuky je preto DEKOR; hrúbky toho
    // istého TYPU dosky sú na jeho konci ako čipy (`18 | 36`).
    //
    // HRANICA JE TYP DOSKY, nie dekor: HDF 3 mm ani kompakt NIE SÚ „tenšia
    // verzia" DTDL toho istého dekoru — sú to iné materiály s inou cenou aj
    // spracovaním. Prepínač čipov preto NIKDY nesmie zmeniť typ; takéto
    // položky ostávajú samostatnými riadkami.
    //
    // Výsledok voľby ostáva `material_id` KONKRÉTNEHO variantu — čip je čisto
    // klientske zúženie výberu, serverové cesty sa nemenia (E-03: hrúbku
    // určuje reálny materiál, nie UI).

    // Metadáta variantu dodáva HOSTITEĽ (`setVariantResolver`) — komponent sám
    // žiadny katalóg nepozná. Bez resolvera sa nič nezoskupuje a ponuka vyzerá
    // presne ako pred PICKER-2.
    function variantMetaOf(kind, value){
      if (!variantResolver || nxComboIsFixed(value)) return null;
      var m;
      try { m = variantResolver(kind, value); } catch (e){ return null; }
      if (!m || !m.decor) return null;
      return { decor: String(m.decor), type: String(m.type == null ? '' : m.type),
               thickness: (m.thickness == null ? null : Number(m.thickness)),
               duplak: !!m.duplak, key: String(m.key == null ? '' : m.key) };
    }

    // Zoskupenie položiek na dekorové riadky. `meta(value)` vracia
    // {decor,type,thickness,duplak} alebo null (položka ostáva samostatná).
    // Poradie riadkov = poradie PRVÉHO výskytu (katalógové poradie sa nemení).
    function nxComboDecorRows(items, meta){
      var rows = [], byKey = {};
      (items || []).forEach(function(it){
        var m = meta ? meta(it.value) : null;
        if (!m || !m.decor || !m.type){ rows.push(it); return; }
        // HRANICU URCUJE KATALOG (review #231 P1): `m.key` je identita
        // variantovej rodiny zo servera (vyrobca - dekor - struktura - typ -
        // format/rub). Samotny dekor + typ zlucuje dva ROZNE materialy
        // s rovnakym cislom dekoru: dva cipy s rovnakou hrubkou by boli
        // nerozlisitelne a dala by sa vybrat cudzia cena, povrch aj format.
        // Bez identity (starsi payload) sa pada na dekor + typ, teda na
        // spravanie spred opravy.
        var key = (m.key || (m.decor + '\u0000' + m.type)) + '\u0000' + (it.group || '');
        var variant = { value: it.value, label: it.label, disabled: !!it.disabled,
                        thickness: m.thickness, duplak: !!m.duplak };
        if (!Object.prototype.hasOwnProperty.call(byKey, key)){
          var row = { value: it.value, label: m.decor, group: it.group || '',
                      disabled: !!it.disabled, variants: [variant], decorRow: true,
                      type: m.type, key: key };
          byKey[key] = row;
          rows.push(row);
          return;
        }
        var r = byKey[key];
        r.variants.push(variant);
        if (!variant.disabled) r.disabled = false;   // riadok žije, kým žije aspoň jeden variant
      });
      rows.forEach(function(r){
        if (!r.decorRow) return;
        r.variants.sort(nxComboVariantCmp);
        // Hľadanie musí nájsť riadok aj podľa hrúbky („36") a podľa slova
        // „duplák" — inak by ich zlúčenie schovalo pred vyhľadávaním.
        // Riadok sa musi dat najst podla VSETKEHO, co zastupuje — nielen
        // podla hrubky, ale aj podla ID a labelu KAZDEHO variantu (review #231
        // P2). Pred zlucenim sa hladalo cez `value` kazdej polozky, takze
        // dotaz na opaknu ID („H3303_36") fungoval; po zluceni nesie riadok len
        // hodnotu predvoleneho variantu a bez tohto by taky dotaz prestal.
        r.searchExtra = r.variants.map(function(v){
          return [(v.thickness == null ? '' : v.thickness), (v.duplak ? 'duplak duplák' : ''),
                  v.value, v.label].join(' ');
        }).join(' ');
        var def = nxComboDefaultVariant(r.variants, null);
        if (def) r.value = def.value;
      });
      return rows;
    }

    // Tenšie hore, duplák VŽDY posledný (je to vedomá voľba, nie bežná hrúbka).
    function nxComboVariantCmp(a, b){
      if (!!a.duplak !== !!b.duplak) return a.duplak ? 1 : -1;
      var ta = (a.thickness == null) ? 1e9 : a.thickness;
      var tb = (b.thickness == null) ? 1e9 : b.thickness;
      if (ta !== tb) return ta - tb;
      return String(a.label).localeCompare(String(b.label));
    }

    // Kontext výberu -> predvolený variant. Michal 25.8.: korpus a čelá chcú
    // najtenšiu konštrukčnú (18/19), chrbát HDF 3, pracovná doska 38 — a
    // DUPLÁK sa nesmie predvoliť NIKDY (je to zdvojená doska za dvojnásobok,
    // vyberá sa vedome klikom na čip).
    function nxComboDefaultVariant(variants, ctx){
      var list = (variants || []).filter(function(v){ return !v.disabled; });
      if (!list.length) list = (variants || []).slice();
      if (!list.length) return null;
      var real = list.filter(function(v){ return !v.duplak; });
      var pool = real.length ? real : list;   // len duplák? potom nech je aspoň niečo
      var want = null;
      if (ctx === 'back') want = 3;
      else if (ctx === 'worktop') want = 38;
      if (want != null){
        var exact = pool.filter(function(v){ return v.thickness === want; });
        if (exact.length) return exact[0];
      }
      // Bez kontextu (a pre korpus/čelá) je to NAJTENŠIA neduplákový variant —
      // v praxi 18/19 mm, ale bez natvrdo písaného čísla: katalóg rozhoduje.
      var best = null;
      pool.forEach(function(v){
        if (!best) { best = v; return; }
        if (nxComboVariantCmp(v, best) < 0) best = v;
      });
      return best;
    }

    // Dotaz -> ktorý VARIANT bol menovaný priamo (ID alebo label). Materiálové
    // ID su zamerne neprehladne a pred zlucenim sa dal kazdy variant vybrat
    // samostatne — dotaz „ZXQ" teda musi vlozit prave ten variant, nie
    // predvolenu hrubku rodiny (review #231 kolo 3). Nejednoznacny dotaz
    // (sedi na viac variantov, napr. samotny nazov dekoru) nevybera nic —
    // radsej nechame rozhodnut hrubkove pravidlo nez hadat.
    function nxComboVariantFromQuery(q, variants){
      var list = variants || [];
      var text = nxNormText(q);
      if (!text || !list.length) return -1;
      var exact = -1, part = -1, parts = 0;
      for (var i = 0; i < list.length; i++){
        if (list[i].disabled) continue;
        var val = nxNormText(list[i].value), lab = nxNormText(list[i].label);
        if (text === val || text === lab){ if (exact < 0) exact = i; }
        else if (val.indexOf(text) > -1 || lab.indexOf(text) > -1){ part = i; parts++; }
      }
      if (exact >= 0) return exact;
      return parts === 1 ? part : -1;
    }

    // Dotaz -> ktorý čip má byť predvolený. „36" preselektuje 36 mm, „duplák"
    // duplákový variant. -1 = dotaz o hrúbke nič nehovorí.
    function nxComboChipFromQuery(q, variants){
      var list = variants || [];
      if (!list.length) return -1;
      var text = nxNormText(q);
      if (!text) return -1;
      if (text.indexOf('duplak') > -1){
        for (var d = 0; d < list.length; d++){ if (list[d].duplak) return d; }
      }
      var nums = text.match(/\d+([.,]\d+)?/g);
      if (!nums) return -1;
      for (var n = 0; n < nums.length; n++){
        var val = parseFloat(String(nums[n]).replace(',', '.'));
        for (var i = 0; i < list.length; i++){
          if (list[i].thickness != null && Math.abs(list[i].thickness - val) < 0.001) return i;
        }
      }
      return -1;
    }

    function nxComboSections(items, q, kind, usedIds, recentIds){
      items = items || [];
      var used = {}, recent = {}, i;
      for (i = 0; i < (usedIds || []).length; i++) used[String(usedIds[i])] = true;
      for (i = 0; i < (recentIds || []).length; i++) recent[String(recentIds[i])] = true;

      var fixed = [], inProject = [], recents = [], rest = [];
      items.forEach(function(it){
        if (!nxComboHit(it, q)) return;
        if (nxComboIsFixed(it.value)) { fixed.push(it); return; }
        // PICKER-2: dekorový riadok je „použitý", keď je použitý HOCIKTORÝ jeho
        // variant. Porovnávať len `it.value` (predvolenú hrúbku) by znamenalo,
        // že projekt s 36 mm by dekor v skupine „Použité v projekte" nenašiel —
        // skupina by po zlúčení ticho vypadla.
        var ids = nxComboRowIds(it);
        if (ids.some(function(v){ return used[v]; })) { inProject.push(it); return; }
        if (ids.some(function(v){ return recent[v]; })) { recents.push(it); return; }
        rest.push(it);
      });
      // Naposledy pouzite drzia poradie POUZITIA (najnovsie hore), nie katalogu.
      // Riadok sa radí podľa svojho NAJNOVŠIEHO variantu.
      recents.sort(function(a, b){
        return (rowRecentIndex(recentIds, a) - rowRecentIndex(recentIds, b));
      });

      var out = [];
      if (fixed.length)     out.push({ title: null, items: fixed });
      if (inProject.length) out.push({ title: 'Použité v projekte', items: inProject });
      if (recents.length)   out.push({ title: 'Naposledy použité', items: recents });
      if (rest.length)      out.push.apply(out, nxComboRestSections(rest, kind));
      return out;
    }

    // Všetky ID, ktoré riadok zastupuje: bežná položka jedno, dekorový riadok
    // všetky svoje varianty (18 · 36 · duplák).
    function nxComboRowIds(it){
      if (it && it.decorRow && it.variants && it.variants.length){
        return it.variants.map(function(v){ return String(v.value); });
      }
      return [String(it ? it.value : '')];
    }

    function rowRecentIndex(list, it){
      var best = 9999;
      nxComboRowIds(it).forEach(function(v){
        var i = usedIndex(list, v);
        if (i < best) best = i;
      });
      return best;
    }

    function usedIndex(list, value){
      var i = (list || []).indexOf(value);
      return i < 0 ? 9999 : i;
    }

    // Zvysok katalogu: ked maju polozky <optgroup>, clenenie sa zachova v poradi
    // prveho vyskytu; bez skupin je to jedna sekcia s poctom (vzor mockupu).
    function nxComboRestSections(rest, kind){
      var order = [], byGroup = {};
      rest.forEach(function(it){
        var g = it.group || '';
        if (!Object.prototype.hasOwnProperty.call(byGroup, g)) { byGroup[g] = []; order.push(g); }
        byGroup[g].push(it);
      });
      if (order.length === 1 && order[0] === ''){
        var label = (kind === 'abs' ? 'Katalóg ABS pások' : 'Katalóg dekorov');
        return [{ title: label + ' (' + rest.length + ')', items: rest }];
      }
      return order.map(function(g){
        return { title: g === '' ? 'Ostatné' : g, items: byGroup[g] };
      });
    }

    // Plochy zoznam vyberatelnych poloziek (disabled sa preskakuju — su to volby,
    // ktore by server aj tak odmietol; v ponuke ostavaju viditelne, ale mrtve).
    function nxComboFlatten(sections){
      var out = [];
      (sections || []).forEach(function(s){
        (s.items || []).forEach(function(it){ out.push(it); });
      });
      return out;
    }

    // Krok klavesnice po VYBERATELNYCH polozkach (disabled sa preskoci). Bez
    // zacyklenia: na koncoch zoznamu ostava index stat.
    function nxComboStep(list, active, dir){
      list = list || [];
      if (!list.length) return -1;
      var i = active;
      for (var n = 0; n < list.length; n++){
        i += dir;
        if (i < 0 || i >= list.length) return active;
        if (!list[i].disabled) return i;
      }
      return active;
    }

    // Prvy vyberatelny index (na otvorenie / po zmene filtra).
    function nxComboFirst(list){
      for (var i = 0; i < (list || []).length; i++){ if (!list[i].disabled) return i; }
      return -1;
    }

    // "Naposledy pouzite": id navrch, bez duplikatov, max N. Fixne volby
    // (dedit / podla pravidla / Bez ABS) sa nezapamatavaju — nie su to materialy.
    function nxRecentPush(list, id, max){
      var out = (list || []).slice();
      var v = String(id == null ? '' : id);
      if (v === '' || nxComboIsFixed(v)) return out;
      var i = out.indexOf(v);
      if (i >= 0) out.splice(i, 1);
      out.unshift(v);
      return out.slice(0, max || RECENT_MAX);
    }

    // ---------------------------------------------------------------- DOM cast
    // (v Node teste sa nespusti — document neexistuje)

    var ATTACHED = [];              // registrovane <select>y
    var OPEN = null;                // { sel, pop, items, active, q }
    var colorResolver = null;
    var variantResolver = null;       // fn(kind, value) -> css farba | ''
    var usedResolver = null;        // fn(kind) -> [id, …]
    var usedRefresher = null;       // fn() -> vypyta si od servera cerstve used_ids
    var docBound = false;

    function esc(s){
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function icon(name){
      return (global.NXIcons && global.NXIcons.svg) ? global.NXIcons.svg(name) : '';
    }
    function hasClass(node, cls){
      return (' ' + (node.getAttribute('class') || '') + ' ').indexOf(' ' + cls + ' ') >= 0;
    }

    function recentKey(kind){ return RECENT_KEYS[kind] || RECENT_KEYS.decor; }
    function loadRecent(kind){
      try {
        var raw = global.localStorage ? global.localStorage.getItem(recentKey(kind)) : null;
        var arr = raw ? JSON.parse(raw) : [];
        return Array.isArray(arr) ? arr.map(String).slice(0, RECENT_MAX) : [];
      } catch (e){ return []; }
    }
    function saveRecent(kind, list){
      try {
        if (global.localStorage) global.localStorage.setItem(recentKey(kind), JSON.stringify(list));
      } catch (e){ /* privatny rezim / plna kvota — recents su len UX, nie data */ }
    }

    // Moznosti PRIAMO z <select>u — jediny zdroj pravdy (ziadna kopia katalogu).
    function readItems(sel){
      var out = [], nodes = sel.getElementsByTagName('option');
      for (var i = 0; i < nodes.length; i++){
        var o = nodes[i];
        var parent = o.parentNode;
        out.push({
          value: o.value,
          label: (o.textContent || '').trim(),
          disabled: !!o.disabled,
          group: (parent && parent.tagName === 'OPTGROUP') ? (parent.label || '') : ''
        });
      }
      return out;
    }

    function selectedItem(sel){
      var idx = sel.selectedIndex;
      if (idx < 0) return null;
      var o = sel.options[idx];
      return o ? { value: o.value, label: (o.textContent || '').trim() } : null;
    }

    // Farba stvorceka. Hodnota konci v `style` atribute, preto sa prijima LEN
    // hex — nie lubovolny retazec od volajuceho (esc() sice uvodzovky zneskodni,
    // ale uzky whitelist je lacnejsi nez dovera). Nic = ziadny stvorcek.
    function colorOf(kind, value){
      if (!colorResolver || nxComboIsFixed(value)) return '';
      var c;
      try { c = colorResolver(kind, value); } catch (e){ return ''; }
      c = String(c == null ? '' : c);
      return /^#[0-9a-fA-F]{3,8}$/.test(c) ? c : '';
    }
    function usedOf(kind){
      if (!usedResolver) return [];
      try { return usedResolver(kind) || []; } catch (e){ return []; }
    }

    // --- trigger ---------------------------------------------------------------

    function refresh(sel){
      var c = sel && sel.__nxc;
      if (!c) return;
      var it = selectedItem(sel);
      var col = it ? colorOf(c.kind, it.value) : '';
      c.btn.innerHTML =
        (col ? '<i class="sw" style="background:' + esc(col) + '"></i>' : '') +
        '<span class="lbl">' + esc(it ? it.label : '— vyber —') + '</span>' +
        icon('chevron-down');
      c.btn.disabled = !!sel.disabled;
      c.btn.title = it ? it.label : '';
      // 'ovr' (jantarovy override) sa na selecte prepisuje cez className —
      // trigger ho len ZRKADLI, aby override ostal vidiet.
      c.btn.className = 'cbtrigger' + (hasClass(sel, 'ovr') ? ' ovr' : '');
      if (sel.disabled && OPEN && OPEN.sel === sel) close();
    }

    function attach(sel, kind){
      if (!sel || sel.__nxc) return null;
      kind = kind || sel.getAttribute(KIND_ATTR) || 'decor';
      sel.setAttribute(KIND_ATTR, kind);
      var wrap = document.createElement('div');
      wrap.className = 'nxcombo';
      // Presun selectu do obalu: hodnotu si poistne odlozime a vratime. Vyber
      // v DOM sice patri <option>om (presun ho drzi), ale je to jediny stav,
      // ktory tu mozeme stratit — a stratil by sa TICHO.
      var keep = sel.value;
      sel.parentNode.insertBefore(wrap, sel);
      wrap.appendChild(sel);
      if (sel.value !== keep) sel.value = keep;
      // Nativny select ostava v DOM (zdroj pravdy), ale mimo mysi aj tab poradia.
      sel.setAttribute('tabindex', '-1');
      sel.setAttribute('aria-hidden', 'true');

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'cbtrigger';
      btn.setAttribute('aria-haspopup', 'listbox');
      btn.setAttribute('aria-expanded', 'false');
      wrap.appendChild(btn);

      sel.__nxc = { wrap: wrap, btn: btn, kind: kind };
      btn.addEventListener('mousedown', function(ev){ ev.preventDefault(); ev.stopPropagation(); });
      btn.addEventListener('click', function(ev){ ev.preventDefault(); ev.stopPropagation(); toggle(sel); });
      sel.addEventListener('change', function(){ refresh(sel); });
      // Panel prekresluje <option>y zvonka (fillSheetSelectFiltered, edgeOptionsHtml,
      // regroup*Edges) BEZ akejkolvek udalosti — observer je jediny sposob, ako sa
      // o tom dozvediet. Callback bezi az po dobehnuti celeho bloku, takze uz vidi
      // aj dosadenu `value`.
      if (global.MutationObserver){
        var mo = new global.MutationObserver(function(){
          // Codex #167 P2: prestavba volieb zvonka = ponuka v popupe uz neplati.
          if (OPEN && OPEN.sel === sel) close();
          refresh(sel);
        });
        mo.observe(sel, { childList: true, subtree: true });
        sel.__nxc.mo = mo;
      }
      ATTACHED.push(sel);
      bindDocument();
      refresh(sel);
      return sel.__nxc;
    }

    // Pripoji komponent na vsetky NEobsluzene selecty pod `root` a obnovi triggery
    // uz pripojenych (odpojene z DOM zahodi). Vola sa po kazdom renderi karty —
    // je to lacne (querySelectorAll nad atributom) a deterministicke.
    //
    // Codex #167 P2: sync ZVONKA (serverovy push — iny korpus cez NX.loadSelected,
    // novy katalog cez NX.setMaterials) VZDY zavrie otvoreny popup. Popup si drzi
    // zoznam poloziek z casu otvorenia; keby prezil, klik by potvrdil volbu STAREHO
    // kontextu (iná skrinka, iny katalog) do NOVEHO. Nativna rozbalovacka sa pri
    // prestavbe sprava rovnako — zavrie sa.
    // Opak `attach`: vrati uzol do stavu, v akom sme ho nasli — tlacidlo prec,
    // select spat na miesto obalu, obal prec, atributy zrusene. Bez toho
    // ostane po odpojenom poli „polovicny" stav (obal + tlacidlo bez
    // registracie) a najblizsi `attach` prida DRUHE tlacidlo do toho isteho
    // obalu: pouzivatel vidi DVA ovladace a s kazdym dalsim katalogovym echom
    // o jeden viac (review #230 P2).
    //
    // Uzol pritom NEMUSI byt v dokumente — hostitel (sekcia Studia) si telo
    // drzi ODPOJENE a vracia ho pri navrate aj s rozpisanym formularom.
    // Rozbalenie odpojeneho stromu je bezpecne: menime len jeho vnutro.
    function detach(sel){
      var c = sel && sel.__nxc;
      if (!c) return false;
      if (c.mo) c.mo.disconnect();
      if (OPEN && OPEN.sel === sel) close();
      var wrap = c.wrap;
      if (wrap && wrap.parentNode) wrap.parentNode.insertBefore(sel, wrap);
      else if (wrap && sel.parentNode === wrap) wrap.removeChild(sel);
      if (c.btn && c.btn.parentNode) c.btn.parentNode.removeChild(c.btn);
      if (wrap && wrap.parentNode) wrap.parentNode.removeChild(wrap);
      sel.removeAttribute('tabindex');
      sel.removeAttribute('aria-hidden');
      sel.__nxc = null;
      return true;
    }

    function scan(root){
      var scope = root || document;
      var list = scope.querySelectorAll ? scope.querySelectorAll('select[' + KIND_ATTR + ']') : [];
      for (var i = 0; i < list.length; i++) attach(list[i]);
      for (var j = ATTACHED.length - 1; j >= 0; j--){
        var sel = ATTACHED[j];
        if (!document.body.contains(sel)){
          // Review #230 P2: odregistrovat NESTACI — uzol moze byt len DOCASNE
          // odpojeny (perzistentne telo sekcie) a vratit sa. Rozbalime ho, aby
          // ho navrat obalil CISTO RAZ.
          detach(sel);
          ATTACHED.splice(j, 1);
        } else {
          if (OPEN && OPEN.sel === sel) close();
          refresh(sel);
        }
      }
    }

    // --- popup -----------------------------------------------------------------

    function isOpen(sel){ return !!(OPEN && (!sel || OPEN.sel === sel)); }

    function close(){
      if (!OPEN) return;
      var c = OPEN.sel.__nxc;
      if (c) c.btn.setAttribute('aria-expanded', 'false');
      if (OPEN.pop && OPEN.pop.parentNode) OPEN.pop.parentNode.removeChild(OPEN.pop);
      OPEN = null;
    }

    function toggle(sel){
      if (isOpen(sel)) { close(); return; }
      open(sel);
    }

    function open(sel){
      var c = sel && sel.__nxc;
      if (!c || sel.disabled) return false;
      close();
      var pop = document.createElement('div');
      pop.className = 'cbpop';
      pop.innerHTML =
        '<div class="cbsearch">' + icon('search') +
        '<input type="text" autocomplete="off" spellcheck="false" ' +
        'placeholder="Píš názov alebo kód… (aj bez diakritiky)"></div>' +
        '<div class="cblist" role="listbox"></div>' +
        '<div class="cbfoot"><span class="kbd">↑ ↓</span> výber ' +
        '<span class="kbd">Enter</span> potvrdí <span class="kbd">Esc</span> zavrie</div>';
      document.body.appendChild(pop);
      OPEN = { sel: sel, pop: pop, items: [], active: -1, q: '', chip: {}, msg: {} };
      c.btn.setAttribute('aria-expanded', 'true');

      var inp = pop.querySelector('input');
      // Pri pisani skoc na PRVU zhodu; pri otvoreni stoj na aktualnej hodnote.
      inp.addEventListener('input', function(){ render(inp.value.trim(), true); });
      inp.addEventListener('keydown', onKey);
      // Vyber MOUSEDOWN-om (D-67 FIX 4) — blur by popup zavrel skor, nez klik dopadne.
      pop.addEventListener('mousedown', function(ev){
        // PICKER-2: klik na čip je ZÚŽENIE VÝBERU, nie výber — ponuka ostáva
        // otvorená, aby sa dalo porovnávať ďalej.
        var chip = ev.target && ev.target.closest ? ev.target.closest('.cbchip') : null;
        if (chip){
          ev.preventDefault();
          ev.stopPropagation();
          pickChip(parseInt(chip.getAttribute('data-chiprow'), 10),
                   parseInt(chip.getAttribute('data-chip'), 10));
          return;
        }
        var row = ev.target && ev.target.closest ? ev.target.closest('.cbopt') : null;
        if (!row) return;   // klik do hladania / paticky nesmie nic vybrat
        ev.preventDefault();
        if (row.getAttribute('data-off') === '1') return;
        pick(parseInt(row.getAttribute('data-i'), 10));
      });
      render('', false); // render sam dopocita poziciu (vyska sa filtrom meni)
      // Codex #167 P2: „Použité v projekte" sa meni pri KAZDOM zapise materialu,
      // ale CITA sa len pri otvoreni ponuky. Preto sa cerstvy zoznam PYTA az tu
      // (par desiatok krat za sedenie) namiesto toho, aby ho server tlacil pri
      // kazdom kliku v modeli — plny scan modelu do cesty vyberu nepatri.
      // Odpoved dobehne asynchronne a prekresli uz otvoreny zoznam (rerender()).
      if (usedRefresher){ try { usedRefresher(); } catch (e){} }
      setTimeout(function(){ try { inp.focus(); } catch (e){} }, 0);
      return true;
    }

    // Prekresli OTVORENY zoznam novymi datami (napr. po dobehnuti used_ids).
    // Rozpisany dotaz aj kurzor sa zachovaju — kurzor podla HODNOTY, nie indexu
    // (polozka sa presunutim do inej sekcie posunie).
    function rerender(){
      if (!OPEN) return;
      var active = (OPEN.active >= 0 && OPEN.items[OPEN.active]) ? OPEN.items[OPEN.active].value : null;
      render(OPEN.q, false);
      if (active === null) return;
      for (var i = 0; i < OPEN.items.length; i++){
        if (OPEN.items[i].value === active && !OPEN.items[i].disabled){ OPEN.active = i; paintActive(); return; }
      }
    }

    function onKey(ev){
      if (!OPEN) return;
      if (ev.key === 'ArrowDown'){ ev.preventDefault(); move(1); }
      else if (ev.key === 'ArrowUp'){ ev.preventDefault(); move(-1); }
      // Cipy su tlacidla, ale fokus zostava v poli hladania (Tab ponuku
      // zatvara), takze bez tohto by sa k nim clovek od klavesnice nedostal
      // vobec (review #231 P2). Sipky VLAVO/VPRAVO prepinaju hrubku
      // v aktivnom riadku — Enter potom vlozi prave ju.
      else if (ev.key === 'ArrowLeft'){ ev.preventDefault(); moveChip(-1); }
      else if (ev.key === 'ArrowRight'){ ev.preventDefault(); moveChip(1); }
      else if (ev.key === 'Enter'){ ev.preventDefault(); if (OPEN.active >= 0) pick(OPEN.active); }
      else if (ev.key === 'Escape'){ ev.preventDefault(); var s = OPEN.sel; close(); focusTrigger(s); }
      else if (ev.key === 'Tab'){ close(); }
    }

    function focusTrigger(sel){
      if (sel && sel.__nxc){ try { sel.__nxc.btn.focus(); } catch (e){} }
    }

    // Krok po cipoch aktivneho riadku. Nedostupne varianty sa preskakuju
    // a na koncoch sa NEcykluje — inak by sa slepym stlacanim dalo skoncit
    // na dupláku bez toho, aby to clovek zbadal.
    function moveChip(dir){
      if (!OPEN || OPEN.active < 0) return;
      var row = OPEN.items[OPEN.active];
      if (!row || !row.decorRow || !row.variants || row.variants.length < 2) return;
      var i = -1, k;
      for (k = 0; k < row.variants.length; k++){ if (row.variants[k].value === row.value) i = k; }
      if (i < 0) i = 0;
      for (k = i + dir; k >= 0 && k < row.variants.length; k += dir){
        if (row.variants[k].disabled) continue;
        pickChip(OPEN.active, k);
        return;
      }
    }

    function move(dir){
      OPEN.active = nxComboStep(OPEN.items, OPEN.active, dir);
      paintActive();
    }

    function paintActive(){
      var rows = OPEN.pop.querySelectorAll('.cbopt');
      for (var i = 0; i < rows.length; i++){
        var on = (parseInt(rows[i].getAttribute('data-i'), 10) === OPEN.active);
        rows[i].className = 'cbopt' + (rows[i].getAttribute('data-off') === '1' ? ' off' : '') + (on ? ' act' : '');
        rows[i].setAttribute('aria-selected', on ? 'true' : 'false');
        if (on && rows[i].scrollIntoView) rows[i].scrollIntoView({ block: 'nearest' });
      }
    }

    // `jumpFirst` = pisanie (kurzor skoci na prvu zhodu); false = otvorenie
    // (kurzor stoji na AKTUALNEJ hodnote, aby Enter nic nezmenil omylom).
    function render(q, jumpFirst){
      if (!OPEN) return;
      var sel = OPEN.sel, kind = sel.__nxc.kind;
      // PICKER-2: z položiek sa najprv stanú DEKOROVÉ RIADKY (varianty toho
      // istého dekoru a typu dosky sa zlúčia do jedného riadku s čipmi), až
      // potom sa delia na sekcie. Poradie je dôležité: sekcie „Použité"
      // a „Naposledy" tak dostanú riadok, nie tri varianty za sebou.
      var rows = nxComboDecorRows(readItems(sel), function(v){ return variantMetaOf(kind, v); });
      applyContextDefaults(sel, rows, q);
      var secs = nxComboSections(rows, q, kind, usedOf(kind), loadRecent(kind));
      OPEN.items = nxComboFlatten(secs);
      OPEN.q = q;
      var list = OPEN.pop.querySelector('.cblist');
      if (!OPEN.items.length){
        list.innerHTML = '<div class="cbempty">Nič nesedí — hľadá sa aj bez diakritiky.</div>';
        OPEN.active = -1;
        position();
        return;
      }
      var n = 0, html = '';
      secs.forEach(function(s){
        if (s.title) html += '<div class="cbsec">' + esc(s.title) + '</div>';
        s.items.forEach(function(it){
          var col = colorOf(kind, it.value);
          // PICKER-1: cely nazov aj v tooltipe — pri velmi dlhych dekoroch
          // (a v uzkom okne) sa riadok aj tak moze orezat a pouzivatel musi
          // mat ako zistit, co tam naozaj stoji.
          var tip = it.label + (it.group ? ' · ' + it.group : '');
          html += '<div class="cbopt' + (it.disabled ? ' off' : '') + '" role="option" aria-selected="false"' +
            ' title="' + esc(tip) + '"' +
            ' data-i="' + n + '"' + (it.disabled ? ' data-off="1"' : '') + '>' +
            (col ? '<i class="sw" style="background:' + esc(col) + '"></i>' : '<i class="sw nosw"></i>') +
            '<span class="t"><b>' + markup(it.label, q) + '</b>' +
            (it.group ? '<i>' + esc(it.group) + '</i>' : '') + '</span>' +
            chipsHtml(it, n) + '</div>';
          n++;
        });
      });
      list.innerHTML = html;
      OPEN.active = jumpFirst ? nxComboFirst(OPEN.items) : currentIndex(sel);
      if (OPEN.active < 0) OPEN.active = nxComboFirst(OPEN.items);
      paintActive();
      position();
    }

    // Kontext výberu (`data-nx-combo-ctx`): korpus/čelá → najtenšia
    // konštrukčná, chrbát → HDF 3, pracovná doska → 38. Dotaz má prednosť:
    // keď človek píše „36", chce 36 — aj v korpuse.
    //
    // Voľba, ktorú už select NESIE, má prednosť pred oboma: prepnutý čip ani
    // uložená hodnota sa nesmú stratiť pri prekreslení po písmene.
    function applyContextDefaults(sel, rows, q){
      var ctx = sel.getAttribute(CTX_ATTR) || null;
      var cur = sel.value;
      var picked = (OPEN && OPEN.chip) ? OPEN.chip : {};
      rows.forEach(function(r){
        if (!r.decorRow) return;
        // Poradie je kontrakt, nie detail:
        // 1. DOTAZ, KTORÝ MENUJE KONKRÉTNY VARIANT (jeho ID alebo label),
        //    je najsilnejší: hľadanie ho vie nájsť, takže Enter musí vložiť
        //    práve jeho — nie predvolenú hrúbku rodiny.
        var byId = nxComboVariantFromQuery(q, r.variants);
        if (byId >= 0){ r.value = r.variants[byId].value; return; }
        // 2. VÝSLOVNÝ DOTAZ O HRÚBKE má prednosť pred zvyškom (review #231 P2):
        //    kto po kliku na 18 napíše „36", chce 36. Sľub „dotaz preselektuje
        //    to, čo Enter vloží" platí aj vtedy, keď predtým klikol na iný čip
        //    — inak by ponuka ukazovala jedno a vložila druhé.
        var byQ = nxComboChipFromQuery(q, r.variants);
        if (byQ >= 0 && !r.variants[byQ].disabled){ r.value = r.variants[byQ].value; return; }
        // 3. VEDOMÁ voľba čipu — dotaz o hrúbke nič nehovorí, takže voľba
        //    platí ďalej; inak by ju zahodilo najbližšie písmeno v hľadaní
        //    (render beží po každom vstupe).
        if (picked[r.key]){
          var kept = null;
          r.variants.forEach(function(v){ if (v.value === picked[r.key]) kept = v; });
          if (kept){ r.value = kept.value; return; }
        }
        // 4. Inak platí to, čo select NESIE (otvorenie ponuky nič nemení).
        var mine = null;
        r.variants.forEach(function(v){ if (v.value === cur) mine = v; });
        if (mine){ r.value = mine.value; return; }
        // 5. A nakoniec predvoľba podľa kontextu (chrbát 3 · PD 38 · inak
        //    najtenšia konštrukčná; duplák nikdy).
        var def = nxComboDefaultVariant(r.variants, ctx);
        if (def) r.value = def.value;
      });
    }

    function currentIndex(sel){
      var v = sel.value;
      for (var i = 0; i < OPEN.items.length; i++){
        if (OPEN.items[i].value === v && !OPEN.items[i].disabled) return i;
      }
      return -1;
    }

    // PICKER-2: čipy hrúbok. Kreslia sa LEN keď má riadok viac variantov —
    // jediná hrúbka žiadnu voľbu neponúka a čip by bol ozdoba. Aktívny čip je
    // ten, ktorý riadok práve vloží (Enter/klik).
    function chipsHtml(row, rowIndex){
      if (!row.decorRow || !row.variants || row.variants.length < 2) return '';
      var out = '<span class="cbchips">';
      row.variants.forEach(function(v, i){
        var on = (v.value === row.value);
        // NATIVNY `disabled` by cip vyhodil z klavesnice a klik by nemal co
        // povedat — vzor D-78 (repo zasada „ziadne mrtve tlacidlo bez
        // dovodu"): tlacidlo ostava fokusovatelne, len sa nim neda prepnut
        // a klik dopise DOVOD (server ho ma v labeli varianta).
        out += '<button type="button" class="cbchip' + (on ? ' on' : '') +
          (v.disabled ? ' off' : '') + '" data-chip="' + i + '" data-chiprow="' + rowIndex + '"' +
          ' title="' + esc(v.label) + '"' +
          (v.disabled ? ' aria-disabled="true"' : '') + '>' +
          esc(chipLabel(v)) + '</button>';
      });
      out += '</span><span class="cbchipmsg" data-chipmsg="' + rowIndex + '">' +
        esc(chipMsgOf(row)) + '</span>';
      return out;
    }

    // Popis čipu: hrúbka číslom, duplák slovom — „36" a „duplák 36" sú dve
    // rôzne veci a musí to byť vidieť bez tooltipu.
    function chipLabel(v){
      // Rodina moze mat duplak ×2 aj ×3 (36 aj 54 mm). Samotne slovo „duplák"
      // by dalo DVA nerozlisitelne cipy, takze nesie aj hrubku (review #231
      // kolo 2) — cislo je zo servera, slovo je jazyk komponentu.
      var th = (v.thickness == null) ? '?' : String(v.thickness);
      return v.duplak ? (th + ' duplák') : th;
    }

    function markup(text, q){
      return nxComboHighlight(text, q).map(function(seg){
        return seg.hit ? '<mark>' + esc(seg.text) + '</mark>' : esc(seg.text);
      }).join('');
    }

    // PICKER-1: sirka ponuky. Pravidlo (cista funkcia, aby sa dala overit bez
    // DOM): ponuka je taka siroka, ako je OBSAHOVA OBLAST okna (viewport minus
    // okraje), orezana stropom citatelnosti — a NIKDY nie uzsia nez pole, nad
    // ktorym stoji. Dovod: dnesna sirka (max(pole, 270)) v paneli orezavala
    // dlhe nazvy dekorov na „Egger H1234 ST9 Dub…" a rozlisit dve podobne
    // varianty sa dalo len tipovanim. Konstanta „sirka panela" by bola zla:
    // to iste UI bezi aj v Studiu, kde je miesta viac.
    function nxComboPopWidth(fieldW, viewportW, opts){
      var o = opts || {};
      var margin = (o.margin == null) ? POP_MARGIN : o.margin;
      var minW = (o.min == null) ? POP_MIN_W : o.min;
      var maxW = (o.max == null) ? POP_MAX_W : o.max;
      var field = Number(fieldW) || 0;
      var avail = (Number(viewportW) || 0) - 2 * margin;
      if (avail < 0) avail = 0;
      var w = Math.min(avail, maxW);          // kolko sa zmesti, ale citatelne
      if (w < minW) w = Math.min(minW, avail); // uzke okno: radsej cele, nez nic
      if (w < field) w = field;                // NIKDY uzsie nez pole
      return Math.round(w);
    }

    // Popup je `position: fixed` nad body — ziadny `overflow:auto` predok ho
    // neoreze (poucenie D-67 FIX 7 a D-105). Otvara sa DOLAVA (prava hrana lici
    // s triggerom, mockup), pri malo mieste dole sa preklopi nahor.
    function position(){
      if (!OPEN) return;
      var btn = OPEN.sel.__nxc.btn, pop = OPEN.pop;
      var r = btn.getBoundingClientRect();
      var w = nxComboPopWidth(r.width, global.innerWidth);
      pop.style.width = w + 'px';
      var left = r.right - w;
      if (left < POP_MARGIN) left = POP_MARGIN;
      if (left + w > global.innerWidth - POP_MARGIN) left = Math.max(POP_MARGIN, global.innerWidth - POP_MARGIN - w);
      pop.style.left = Math.round(left) + 'px';
      var h = pop.offsetHeight;
      var below = global.innerHeight - r.bottom - POP_MARGIN;
      var top;
      if (h + 3 <= below || r.top < global.innerHeight - r.bottom){
        top = r.bottom + 3;
      } else {
        top = Math.max(POP_MARGIN, r.top - 3 - h);
      }
      pop.style.top = Math.round(top) + 'px';
    }

    // Prepnutie čipu v riadku: mení sa LEN to, čo riadok vloží. Zapisuje sa
    // do `OPEN.items`, takže ďalší Enter/klik ide na zvolený variant.
    // Dovod, preco sa cip neda pouzit — drzi sa pod klucom riadku, takze
    // prezije prekreslenie po pismene v hladani (rovnako ako vybrany cip).
    function chipMsgOf(row){
      return (OPEN && OPEN.msg && row && row.key && OPEN.msg[row.key]) || '';
    }

    function pickChip(rowIndex, chipIndex){
      if (!OPEN) return;
      var row = OPEN.items[rowIndex];
      if (!row || !row.decorRow) return;
      var v = row.variants[chipIndex];
      if (!v) return;
      OPEN.msg = OPEN.msg || {};
      if (v.disabled){
        // Klik na nedostupny cip NEPREPINA, ale ani nemlci: text pise SERVER
        // (label varianta uz nesie dovod, napr. „(nekompatibilné)").
        if (row.key) OPEN.msg[row.key] = v.label;
        redrawRow(rowIndex);
        return;
      }
      if (row.key) delete OPEN.msg[row.key];
      row.value = v.value;
      OPEN.chip = OPEN.chip || {};
      if (row.key) OPEN.chip[row.key] = v.value;   // prežije prekreslenie po písmene
      OPEN.active = rowIndex;
      redrawRow(rowIndex);
    }

    // Prekreslí JEDEN riadok (čipy + zvýraznenie) — celý render by zahodil
    // pozíciu scrollu aj rozpísaný dotaz.
    function redrawRow(rowIndex){
      if (!OPEN || !OPEN.pop) return;
      var nodes = OPEN.pop.querySelectorAll('.cbopt');
      for (var i = 0; i < nodes.length; i++){
        if (parseInt(nodes[i].getAttribute('data-i'), 10) !== rowIndex) continue;
        var chips = nodes[i].querySelectorAll('.cbchip');
        var row = OPEN.items[rowIndex];
        for (var c = 0; c < chips.length; c++){
          var v = row.variants[parseInt(chips[c].getAttribute('data-chip'), 10)];
          var on = !!(v && v.value === row.value);
          chips[c].className = 'cbchip' + (on ? ' on' : '') + (v && v.disabled ? ' off' : '');
        }
        var msg = nodes[i].querySelector('.cbchipmsg');
        if (msg) msg.textContent = chipMsgOf(row);
        break;
      }
      paintActive();
    }

    function pick(i){
      if (!OPEN) return;
      var it = OPEN.items[i];
      if (!it || it.disabled) return;
      var sel = OPEN.sel, kind = sel.__nxc.kind;
      close();
      if (sel.value === it.value){ focusTrigger(sel); return; } // bez zmeny ziadny change
      sel.value = it.value;
      if (sel.value !== it.value) { refresh(sel); return; }     // volba medzitym zmizla z katalogu
      saveRecent(kind, nxRecentPush(loadRecent(kind), it.value, RECENT_MAX));
      refresh(sel);
      // IDENTICKA cesta ako nativny vyber — na `change` visia vsetky guardy
      // (onCabinetMaterial / onPartMaterial / onBoardMaterial / onEdgeChange /
      //  onInsertBoardMaterial s E-03 + D-86).
      sel.dispatchEvent(new Event('change', { bubbles: true }));
      focusTrigger(sel);
    }

    // --- globalne zatvaranie ---------------------------------------------------

    function bindDocument(){
      if (docBound) return;
      docBound = true;
      document.addEventListener('mousedown', function(ev){
        if (!OPEN) return;
        if (OPEN.pop.contains(ev.target)) return;
        if (OPEN.sel.__nxc.wrap.contains(ev.target)) return;
        close();
      }, true);
      // Scroll MIMO popupu rozhodi fixnu poziciu — radsej zavriet (vzor D-67).
      // Scroll vnutri zoznamu je legitimny a popup nezatvara.
      global.addEventListener('scroll', function(ev){
        if (!OPEN) return;
        if (ev.target && OPEN.pop.contains(ev.target)) return;
        close();
      }, true);
      global.addEventListener('resize', function(){ if (OPEN) close(); });
      // Codex #167 P2: odchod z okna (klik do modelu, prepnutie okna) popup zavrie —
      // nativna rozbalovacka sa sprava rovnako a visiaci popup nad SketchUpom by
      // po navrate potvrdzoval volbu do medzicasom zmeneneho kontextu.
      global.addEventListener('blur', function(){ if (OPEN) close(); });
    }

    // ---------------------------------------------------------------- verejne API
    var API = {
      attach: attach,
      scan: scan,
      refresh: refresh,
      open: open,
      close: close,
      isOpen: isOpen,
      // Hooky panela: farba stvorceka a zoznam "pouzite v projekte". Komponent
      // sam ZIADNY katalog nepozna — data mu dodava panel z MATERIALS payloadu.
      setColorResolver: function(fn){ colorResolver = fn; },
      // PICKER-2: metadáta variantu (dekor · typ dosky · hrúbka · duplák).
      // Bez neho sa nič nezoskupuje — ponuka vyzerá ako pred PICKER-2.
      setVariantResolver: function(fn){ variantResolver = fn; },
      setUsedResolver: function(fn){ usedResolver = fn; },
      // Volitelny hook: ako si vypytat CERSTVE „Použité v projekte" pri otvoreni
      // ponuky. Bez neho komponent funguje ďalej — len s tym, co uz v pameti ma.
      setUsedRefresher: function(fn){ usedRefresher = fn; },
      rerender: rerender,
      // PICKER-1: prekreslenie JEDNEHO pola po PROGRAMOVEJ zmene hodnoty.
      // `change` sa vtedy nespusti (a nesmie — D-46 vracia predvolbu na
      // povodnu hodnotu bez toho, aby to vyzeralo ako nova volba pouzivatela),
      // takze bez tohto mostu by trigger ukazoval hodnotu, ktora uz neplati.
      // Rovnaky most ako `sync`, len opacny: hostitel, ktory uzol vedome
      // odpaja (perzistentne telo sekcie), ho moze rozbalit sam.
      detach: function(sel){ return detach(sel); },
      sync: function(sel){
        if (!sel || !sel.__nxc) return false;
        refresh(sel);
        return true;
      },
      recentOf: loadRecent,
      RECENT_MAX: RECENT_MAX,
      // ciste funkcie (Node testy)
      nxNormText: nxNormText, nxComboSections: nxComboSections, nxComboHighlight: nxComboHighlight,
      nxComboStep: nxComboStep, nxComboFirst: nxComboFirst, nxComboFlatten: nxComboFlatten,
      nxRecentPush: nxRecentPush, nxComboIsFixed: nxComboIsFixed, nxComboHit: nxComboHit,
      nxComboDecorRows: nxComboDecorRows, nxComboDefaultVariant: nxComboDefaultVariant,
      nxComboChipFromQuery: nxComboChipFromQuery, nxComboVariantCmp: nxComboVariantCmp,
      nxComboPopWidth: nxComboPopWidth, nxComboRowIds: nxComboRowIds,
      nxComboVariantFromQuery: nxComboVariantFromQuery
    };
    global.NXCombo = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
