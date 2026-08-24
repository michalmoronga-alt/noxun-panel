  // ============ NASTAVENIA — sekcie `sup` · `bset` · `about` (ŠT-4a) ========
  //
  // Obsah ZANIKNUTÉHO okna „Nastavenia rozpočtu" (posledný satelit). Presun je
  // 1:1: SERVER je autorita — JS zbiera hodnoty do PATCHU (len zmenené polia),
  // validáciu aj all-or-nothing zápis robí `SupplierSettings.patch_active!`.
  // Baseline `revision` cestuje tam aj späť — cudzia zmena medzitým = odmietnutie.
  //
  // ČO SA OPROTI OKNU ZMENILO (a prečo):
  //   1. `SS.init` reštartoval formulár pri KAŽDOM pushi (v okne prišiel push
  //      len pri otvorení a po uložení). V Štúdiu chodí plný push pri každej
  //      zmene modelu, takže rovnaké správanie by ticho zahodilo rozpísané
  //      sadzby. Rozpísané hodnoty (`SS_DIRTY`) preto pushe PREŽIJÚ a zanikajú
  //      VÝHRADNE na potvrdenie servera (`SS.saved`) — vzor rozpísaného
  //      formulára sekcie Pravidlá.
  //   2. Telo sekcie sa NEPREKRESĽUJE, kým používateľ píše do jej poľa
  //      (re-render by zobral fokus aj rozpísané číslo) — vzor `proj_materials`.
  //   3. Kresliť sa smie LEN do PRÁVE OTVORENEJ sekcie: `#secbody`/`#sectools`
  //      sú zdieľané uzly celého okna (lekcia review #225 P1).
  //
  // XSS kontrakt (vzor hw_catalog.js): obsah VÝHRADNE createElement +
  // textContent; ovládanie cez data-action delegáciou; žiadne innerHTML s dátami.

  var SS_STATE = null;   // posledný push zo servera (`ST.settings`)
  var SS_DIRTY = {};     // zmenené polia: "rate:olep" -> "0,95" (surový text)

  // Sekcie, ktoré tento súbor kreslí. Autoritou zoznamu je Ruby
  // (`StudioDialog::SECTIONS`) — tu je len to, čo patrí NASTAVENIAM.
  var SS_SECTIONS = ['sup', 'bset', 'about'];

  function ssEl(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }

  // Je niektorá z NAŠICH sekcií práve otvorená? Autoritou je `studio.js`.
  // Keď sa to zistiť nedá, odpoveď je NIE — nekresliť je vždy bezpečnejšie
  // než prepísať cudziu sekciu.
  function ssActive(){
    var sec = null;
    if (typeof studioActiveSection === 'function') sec = studioActiveSection();
    else if (SS_STUDIO && typeof SS_STUDIO.studioActiveSection === 'function') sec = SS_STUDIO.studioActiveSection();
    return (sec && SS_SECTIONS.indexOf(sec) >= 0) ? sec : null;
  }

  var SS_STUDIO = (typeof module !== 'undefined' && module.exports) ? require('./studio.js') : null;

  function ssMk(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  // Číslo -> text formulára (desatinná ČIARKA, slovenské UI). null/undefined =
  // prázdne pole („nezadané"), NIKDY nula.
  function ssNumText(v){
    if (v === null || v === undefined || v === '') return '';
    var f = Number(v);
    if (isNaN(f)) return '';
    return (Math.round(f * 100) / 100).toString().replace('.', ',');
  }

  // Text formulára -> hodnota do patchu. Prázdne pole má pri REŽIMOVEJ hodnote
  // význam „zmaž — použi základnú sadzbu" (null), pri ostatných „nemeň".
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

  // --- render sekcie `bset` ----------------------------------------------

  function ssHeadRow(table, cols){
    var tr = document.createElement('tr');
    cols.forEach(function(c){ tr.appendChild(ssMk('th', null, c)); });
    table.appendChild(tr);
  }

  // Sadzby služieb: základ + 3 režimové stĺpce. Režimová hodnota VYHRÁVA nad
  // základom (SupplierSettings.rate) — keby sekcia ukazovala len základ, úprava
  // by sa navonok „neprejavila" (pd_opracovanie má režimy už v seede).
  function ssRenderRates(t){
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

  function ssRenderRows(t){
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

  // Skaláre — zvlášť, lebo nemajú režimy (sú to parametre výpočtu, nie ceny).
  var SS_SCALARS = [
    ['abs_reserve_pct', 'ABS rezerva', '%'],
    ['montaz_m2_per_plate', 'm² na jednu platňu (montáž)', 'm²'],
    ['rounding_step', 'Zaokrúhlenie ponuky nahor na', '€'],
    ['stale_days', 'Upozorniť na cenu staršiu ako', 'dní'],
    // E-b2: od akej sumy navrhne cenová ponuka SAMOSTATNÝ riadok (rozhodnutie
    // per položka ostáva v zákazke — toto je len návrh).
    ['cp_highlight_threshold', 'Samostatný riadok v cenovej ponuke od', '€']
  ];

  function ssRenderScalars(t){
    SS_SCALARS.forEach(function(s){
      var tr = document.createElement('tr');
      tr.appendChild(ssMk('td', null, s[1]));
      ssCell(tr, 'n', ssInput('scalar:' + s[0], SS_STATE.supplier[s[0]]));
      ssCell(tr, 'u', ssMk('span', null, s[2]));
      t.appendChild(tr);
    });
  }

  // Fieldset s nadpisom a hintom — presne to, čo malo okno v HTML. Stavia sa
  // v JS, lebo telo sekcie je jeden zdieľaný uzol (`#secbody`).
  function ssFieldset(parent, legend, hint){
    var fs = ssMk('fieldset');
    fs.appendChild(ssMk('legend', null, legend));
    if (hint) fs.appendChild(ssMk('div', 'sshint', hint));
    var t = ssMk('table', 'ssgrid');
    fs.appendChild(t);
    parent.appendChild(fs);
    return t;
  }

  function ssRenderBsetInto(box){
    box.appendChild(ssMk('div', 'sshead', 'dodávateľ: ' + (SS_STATE.supplier.name || '—') +
      ' · globálne pre všetky zákazky · v' + SS_STATE.version));
    ssRenderRates(ssFieldset(box, 'Sadzby služieb',
      'Automatické služby — množstvo počíta engine z dát zákazky (bm olepu, počet platní, kusy ' +
      'duplákov, m² montáže). Stĺpce € / €€ / €€€ sú režimové hodnoty: prázdne = použije sa základná sadzba.'));
    ssRenderRows(ssFieldset(box, 'Štandardné riadky — sadzby per režim',
      'Fixné koncové položky ponuky. Násobok (koeficient veľkosti zákazky) sa nastavuje priamo ' +
      'v riadku rozpočtu — tu žije len sadzba.'));
    ssRenderScalars(ssFieldset(box, 'Výpočet a upozornenia', null));
    box.appendChild(ssMk('div', 'sshint',
      'Režim je sada predvolieb, nie zámok — v zákazke sa dá každý riadok prepísať a ručný prepis ' +
      'prežije zmenu režimu. Prah cenovej ponuky je len NÁVRH: každú položku vieš v sekcii Rozpočet ' +
      'prepnúť medzi „samostatne v ponuke" a „v zostave".'));
  }

  // --- render sekcie `sup` -------------------------------------------------
  //
  // POCTIVO: väzba na Demos NEMÁ dnes žiadne nastavenia — Demos je verejný
  // cenník (žiadne prihlásenie, žiadne cenové pásmo, žiadna DPH: firma je
  // neplatca a katalógové ceny sú konečné). Jediná „nastaviteľná" vec je
  // odstup dotazov, a ten je KONŠTANTA slušného správania voči serveru.
  // Sekcia preto ukazuje STAV a vedie tam, kde väzba naozaj žije — vymyslené
  // polia by sľubovali nastavenia, ktoré neexistujú.
  function ssRow(box, label, value){
    var r = ssMk('div', 'ssrow');
    r.appendChild(ssMk('span', 'sslbl', label));
    r.appendChild(ssMk('span', 'ssval', value));
    box.appendChild(r);
    return r;
  }

  function ssLinkBtn(box, section, label, title){
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'ghostbtn';
    b.setAttribute('data-ssgo', section);
    if (title) b.title = title;
    b.textContent = label;
    box.appendChild(b);
    return b;
  }

  function ssRenderSupInto(box){
    var d = SS_STATE.demos || {};
    var fs = ssMk('fieldset');
    fs.appendChild(ssMk('legend', null, 'Dodávateľ'));
    ssRow(fs, 'Aktívny dodávateľ', SS_STATE.supplier.name || '—');
    ssRow(fs, 'Súbor nastavení', SS_STATE.path || '—');
    fs.appendChild(ssMk('div', 'sshint',
      'Sadzby a prahy tohto dodávateľa sú GLOBÁLNE (platia pre všetky zákazky) a upravujú sa ' +
      'v sekcii Nastavenia rozpočtu. Do zákazky sa nemrazia — rozpočet je pohyblivý obraz cien.'));
    box.appendChild(fs);

    var fd = ssMk('fieldset');
    fd.appendChild(ssMk('legend', null, 'Väzba na Demos'));
    fd.appendChild(ssMk('div', 'sshint',
      'Demos je verejný cenník — plugin sa neprihlasuje a nemá cenové pásmo ani sadzbu DPH ' +
      '(firma je neplatca, katalógové ceny sú konečné). Väzba je vlastnosť KONKRÉTNEHO dekoru ' +
      'alebo kovania (odkaz + dátum overenia ceny), preto sa nastavuje pri ňom, nie tu.'));
    ssRow(fd, 'Odstup dotazov', (d.crawl_delay_s ? (ssNumText(d.crawl_delay_s) + ' s') : '—') +
      ' · pevné (slušné správanie voči serveru, nedá sa skrátiť)');
    ssRow(fd, 'Cena je stará od', (d.stale_days == null ? '—' : (String(d.stale_days) + ' dní')) +
      ' · mení sa v Nastaveniach rozpočtu');
    var bar = ssMk('div', 'ssbar');
    ssLinkBtn(bar, 'mat', 'Otvoriť Materiály', 'Väzba dekoru na Demos, hľadanie a hromadné pridanie');
    ssLinkBtn(bar, 'budget', 'Prepočítať ceny (Rozpočet)', 'Hromadná aktualizácia cien beží v sekcii Rozpočet');
    ssLinkBtn(bar, 'bset', 'Nastavenia rozpočtu', 'Sadzby, režimy a prahy');
    fd.appendChild(bar);
    box.appendChild(fd);
  }

  // --- render sekcie `about` ----------------------------------------------
  // JEDEN OBSAH, DVA VSTUPY: markup stavia zdieľaný `js/about.js` (ten istý,
  // ktorý plní koliesko Inspectora). Kópia by sa pri prvej úprave rozišla.
  function ssRenderAboutInto(box){
    var fs = ssMk('fieldset');
    fs.appendChild(ssMk('legend', null, 'O plugine'));
    var host = ssMk('div');
    fs.appendChild(host);
    box.appendChild(fs);
    if (typeof nxAboutFill === 'function') nxAboutFill(host, SS_STATE ? SS_STATE.about : null);
    else host.appendChild(ssMk('div', 'muted', 'Obsah sa nenačítal (js/about.js).'));
    box.appendChild(ssMk('div', 'sshint',
      'To isté nájdeš v koliesku Inspectora — je to jeden obsah s dvoma vstupmi.'));
  }

  // --- kreslenie do zdieľaných uzlov --------------------------------------

  // Píše používateľ práve do poľa tejto sekcie? Vtedy sa NEPREKRESĽUJE —
  // re-render by mu zobral fokus aj rozpísané číslo.
  function ssTyping(){
    if (typeof document === 'undefined') return false;
    var a = document.activeElement;
    return !!(a && a.getAttribute && a.getAttribute('data-ss'));
  }

  function ssRenderBody(){
    var sec = ssActive();
    var box = ssEl('secbody');
    if (!sec || !box) return;
    if (!SS_STATE){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (ssTyping()) return;
    box.innerHTML = '';
    if (sec === 'bset') ssRenderBsetInto(box);
    else if (sec === 'sup') ssRenderSupInto(box);
    else ssRenderAboutInto(box);
  }

  // Lišta: len sekcia `bset` má čo ukladať. `sup` a `about` sú čítanie —
  // prázdna lišta je poctivejšia než tlačidlá, ktoré nič nerobia (D-78).
  function ssToolsHtml(sec){
    if (sec !== 'bset') return '';
    return '<button type="button" class="ghostbtn" data-action="ss-reload"' +
      ' title="Zahodí neuložené zmeny a načíta súbor nanovo">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-rotate-ccw"/></svg> Načítať nanovo</button>' +
      '<span class="spacer"></span>' +
      '<button type="button" class="primary" data-action="ss-save">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-check"/></svg> Uložiť</button>';
  }

  function ssRenderTools(){
    var sec = ssActive();
    var box = ssEl('sectools');
    if (!sec || !box) return;
    box.innerHTML = ssToolsHtml(sec);
  }

  // --- patch ---------------------------------------------------------------

  // Zbiera LEN zmenené polia (SS_DIRTY) — nikdy sa neposiela celý dokument
  // (audit 10: klient nesmie prepisovať, čo nevidel).
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
    if (typeof window !== 'undefined' && window.sketchup && sketchup.ss_save){
      sketchup.ss_save(JSON.stringify({ revision: SS_STATE.revision, patch: built.patch }));
    }
  }

  function ssReload(){
    SS_DIRTY = {};
    if (typeof window !== 'undefined' && window.sketchup && sketchup.ss_reload) sketchup.ss_reload('');
    else ssRenderBody();
  }

  // --- prijímače zo servera -----------------------------------------------

  var SS = {
    setStatus: function(msg, err){
      var e = ssEl('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    },
    // POTVRDENÝ zápis (alebo načítanie nanovo): rozpísané hodnoty zanikajú AŽ
    // TU. Čerstvý stav dorazí samostatne plným pushom Štúdia.
    saved: function(){
      SS_DIRTY = {};
      ssRenderBody();
    }
  };
  if (typeof window !== 'undefined') window.SS = SS;

  // Stav sekcií z payloadu Štúdia (`ST.settings`). Rozpísané hodnoty push
  // NEZAHADZUJE (dôvod v hlavičke súboru).
  function ssApplyState(s){
    if (!s) return;
    SS_STATE = s;
    if (!ssActive()) return;
    ssRenderBody();
    ssRenderTools();
  }

  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var ssPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      ssApplyState(data && data.settings);
      ssPrevSetStudio(data);
    };
  }

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
      var b = ev.target && ev.target.closest ? ev.target.closest('[data-action],[data-ssgo]') : null;
      if (!b) return;
      var go = b.getAttribute('data-ssgo');
      // Deep-link vnútri okna je ČISTO klientsky — server o prepnutí sekcie
      // nevie a vedieť nemusí (vzor `studioGoSection` z Rozpočtu).
      if (go){ if (typeof studioGoSection === 'function') studioGoSection(go); return; }
      var a = b.getAttribute('data-action');
      if (a === 'ss-save') ssSave();
      else if (a === 'ss-reload') ssReload();
    });
  }

  // Node testy (tests/js/test_st4a_settings.js, tests/js/test_budget_ui.js) —
  // čisté funkcie bez DOM + `ssApplyState`/`ssRenderBody`, ktoré DOM potrebujú
  // (scopovanie do otvorenej sekcie sa inak overiť nedá).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { ssBuildPatch: ssBuildPatch, ssParse: ssParse, ssNumText: ssNumText,
                       ssToolsHtml: ssToolsHtml, ssApplyState: ssApplyState,
                       ssRenderBody: ssRenderBody, ssRenderTools: ssRenderTools,
                       ssActive: ssActive, ssSave: ssSave, ssReload: ssReload,
                       SS_SECTIONS: SS_SECTIONS, SS: SS };
  }
