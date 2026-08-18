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
    var RECENT_MAX  = 5;
    var RECENT_KEYS = { decor: 'nx_recent_decor', abs: 'nx_recent_abs' };
    // Volby, ktore NIE SU katalogove id — dedenie / "podla pravidla" / "Bez ABS".
    // Nikdy sa nedostanu do "naposledy pouzite" a v ponuke stoja navrchu bez hlavicky.
    var FIXED_VALUES = ['', '__inherit__'];
    var POP_MIN_W    = 270;
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
      return nxNormText(item.label).indexOf(n) >= 0 || nxNormText(item.value).indexOf(n) >= 0;
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
    function nxComboSections(items, q, kind, usedIds, recentIds){
      items = items || [];
      var used = {}, recent = {}, i;
      for (i = 0; i < (usedIds || []).length; i++) used[String(usedIds[i])] = true;
      for (i = 0; i < (recentIds || []).length; i++) recent[String(recentIds[i])] = true;

      var fixed = [], inProject = [], recents = [], rest = [];
      items.forEach(function(it){
        if (!nxComboHit(it, q)) return;
        if (nxComboIsFixed(it.value)) { fixed.push(it); return; }
        if (used[it.value]) { inProject.push(it); return; }
        if (recent[it.value]) { recents.push(it); return; }
        rest.push(it);
      });
      // Naposledy pouzite drzia poradie POUZITIA (najnovsie hore), nie katalogu.
      recents.sort(function(a, b){
        return (usedIndex(recentIds, a.value) - usedIndex(recentIds, b.value));
      });

      var out = [];
      if (fixed.length)     out.push({ title: null, items: fixed });
      if (inProject.length) out.push({ title: 'Použité v projekte', items: inProject });
      if (recents.length)   out.push({ title: 'Naposledy použité', items: recents });
      if (rest.length)      out.push.apply(out, nxComboRestSections(rest, kind));
      return out;
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
    var colorResolver = null;       // fn(kind, value) -> css farba | ''
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
    function scan(root){
      var scope = root || document;
      var list = scope.querySelectorAll ? scope.querySelectorAll('select[' + KIND_ATTR + ']') : [];
      for (var i = 0; i < list.length; i++) attach(list[i]);
      for (var j = ATTACHED.length - 1; j >= 0; j--){
        var sel = ATTACHED[j];
        if (!document.body.contains(sel)){
          if (sel.__nxc && sel.__nxc.mo) sel.__nxc.mo.disconnect();
          if (OPEN && OPEN.sel === sel) close();
          sel.__nxc = null;
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
      OPEN = { sel: sel, pop: pop, items: [], active: -1, q: '' };
      c.btn.setAttribute('aria-expanded', 'true');

      var inp = pop.querySelector('input');
      // Pri pisani skoc na PRVU zhodu; pri otvoreni stoj na aktualnej hodnote.
      inp.addEventListener('input', function(){ render(inp.value.trim(), true); });
      inp.addEventListener('keydown', onKey);
      // Vyber MOUSEDOWN-om (D-67 FIX 4) — blur by popup zavrel skor, nez klik dopadne.
      pop.addEventListener('mousedown', function(ev){
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
      else if (ev.key === 'Enter'){ ev.preventDefault(); if (OPEN.active >= 0) pick(OPEN.active); }
      else if (ev.key === 'Escape'){ ev.preventDefault(); var s = OPEN.sel; close(); focusTrigger(s); }
      else if (ev.key === 'Tab'){ close(); }
    }

    function focusTrigger(sel){
      if (sel && sel.__nxc){ try { sel.__nxc.btn.focus(); } catch (e){} }
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
      var secs = nxComboSections(readItems(sel), q, kind, usedOf(kind), loadRecent(kind));
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
          html += '<div class="cbopt' + (it.disabled ? ' off' : '') + '" role="option" aria-selected="false"' +
            ' data-i="' + n + '"' + (it.disabled ? ' data-off="1"' : '') + '>' +
            (col ? '<i class="sw" style="background:' + esc(col) + '"></i>' : '<i class="sw nosw"></i>') +
            '<span class="t"><b>' + markup(it.label, q) + '</b>' +
            (it.group ? '<i>' + esc(it.group) + '</i>' : '') + '</span></div>';
          n++;
        });
      });
      list.innerHTML = html;
      OPEN.active = jumpFirst ? nxComboFirst(OPEN.items) : currentIndex(sel);
      if (OPEN.active < 0) OPEN.active = nxComboFirst(OPEN.items);
      paintActive();
      position();
    }

    function currentIndex(sel){
      var v = sel.value;
      for (var i = 0; i < OPEN.items.length; i++){
        if (OPEN.items[i].value === v && !OPEN.items[i].disabled) return i;
      }
      return -1;
    }

    function markup(text, q){
      return nxComboHighlight(text, q).map(function(seg){
        return seg.hit ? '<mark>' + esc(seg.text) + '</mark>' : esc(seg.text);
      }).join('');
    }

    // Popup je `position: fixed` nad body — ziadny `overflow:auto` predok ho
    // neoreze (poucenie D-67 FIX 7 a D-105). Otvara sa DOLAVA (prava hrana lici
    // s triggerom, mockup), pri malo mieste dole sa preklopi nahor.
    function position(){
      if (!OPEN) return;
      var btn = OPEN.sel.__nxc.btn, pop = OPEN.pop;
      var r = btn.getBoundingClientRect();
      var w = Math.max(r.width, POP_MIN_W);
      var maxW = Math.max(160, global.innerWidth - 2 * POP_MARGIN);
      if (w > maxW) w = maxW;
      pop.style.width = Math.round(w) + 'px';
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
      setUsedResolver: function(fn){ usedResolver = fn; },
      // Volitelny hook: ako si vypytat CERSTVE „Použité v projekte" pri otvoreni
      // ponuky. Bez neho komponent funguje ďalej — len s tym, co uz v pameti ma.
      setUsedRefresher: function(fn){ usedRefresher = fn; },
      rerender: rerender,
      recentOf: loadRecent,
      RECENT_MAX: RECENT_MAX,
      // ciste funkcie (Node testy)
      nxNormText: nxNormText, nxComboSections: nxComboSections, nxComboHighlight: nxComboHighlight,
      nxComboStep: nxComboStep, nxComboFirst: nxComboFirst, nxComboFlatten: nxComboFlatten,
      nxRecentPush: nxRecentPush, nxComboIsFixed: nxComboIsFixed, nxComboHit: nxComboHit
    };
    global.NXCombo = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
