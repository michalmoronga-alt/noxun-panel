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
  // REVÍZIA, NAD KTOROU POUŽÍVATEĽ ZAČAL PÍSAŤ (review #227 P1). Plný push
  // chodí pri každej zmene modelu a `SS_STATE.revision` s ním omladne — keby
  // sa uložením poslala TÁ ČERSTVÁ, optimistický zámok servera by prešiel
  // a cudziu zmenu (druhá inštancia, ručný zásah do súboru) by rozpísaný
  // formulár TICHO PREPÍSAL. Presne to má zámok chytiť, takže sa posiela
  // revízia PRIPNUTÁ pri fokuse poľa; uvoľní ju odpoveď servera (`SS.saved()`
  // — potvrdenie, odmietnutie aj „Načítať nanovo") a KAŽDÉ prekreslenie tela
  // z čerstvého stavu nad nerozpísaným formulárom (`ssRenderBody`, dlh 1b-A).
  var SS_BASE_REV = null;
  // Posledný payload NEDORAZIL (server ho nevedel zostaviť — chyba disku,
  // poškodený súbor). Sekcia to MUSÍ povedať: formulár, ktorý vyzerá aktuálne,
  // ale aktuálny nie je, je horší než hláška (review #227 P2).
  var SS_FAILED = false;

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
  //
  // D-52b: updater sa podáva DRUHÝM argumentom, takže prvky vzniknú LEN tu —
  // koliesko Inspectora `nxAboutFill(host, info)` volá bez neho.
  function ssRenderAboutInto(box){
    var fs = ssMk('fieldset');
    fs.appendChild(ssMk('legend', null, 'O plugine'));
    var host = ssMk('div');
    fs.appendChild(host);
    box.appendChild(fs);
    if (typeof nxAboutFill === 'function'){
      nxAboutFill(host, SS_STATE ? SS_STATE.about : null, updMerged());
    } else {
      host.appendChild(ssMk('div', 'muted', 'Obsah sa nenačítal (js/about.js).'));
    }
    box.appendChild(ssMk('div', 'sshint',
      'Obsah „O plugine" nájdeš aj v koliesku Inspectora — je to jeden obsah s dvoma vstupmi. ' +
      'Aktualizácia je LEN tu: zatvára obe okná a prepisuje súbory pluginu, preto do ' +
      'rozklikávacieho panela nepatrí. Po aktualizácii vždy reštartuj SketchUp.'));
  }

  // ============ D-52b: UPDATER (sekcia `about`) =============================
  //
  // Cesta k distribučnému priečinku má VLASTNÝ namespace `data-updater-edit`
  // (F7) — NIE `data-ss`. Dôvod je vecný, nie kozmetický: `data-ss` nesie
  // revíznu mechaniku dodávateľa (`SS_DIRTY`, pripnutá `SS_BASE_REV`,
  // optimistický zámok pri ukladaní) a cesta pod ňu nepatrí — nemá revíziu,
  // neukladá sa cez `ss_save` a jej uloženie nesmie vyzerať ako zápis sadzieb.
  // Zdieľaná mechanika je tu ale JEDNA: rozpísaná hodnota PREŽIJE plný push
  // (chodí pri každej zmene modelu) a zaniká výhradne na potvrdenie servera.
  var UPD = null;         // posledný stav zo servera (`SS.updater`)
  var UPD_DIRTY = null;   // ROZPÍSANÁ cesta (null = nič sa nepíše)
  // POSLEDNÉ uloženie: jeho poradové číslo a odoslaná hodnota. Potvrdenie
  // servera smie zahodiť rozpis LEN vtedy, keď (a) patrí TOMUTO uloženiu
  // (`req`, Codex #278 kolo 3) a (b) v poli je stále odoslaná hodnota
  // (Codex #278 kolo 2). Dve uloženia rýchlo za sebou tak nemôžu skončiť tak,
  // že ack toho prvého zahodí rozpis patriaci druhému.
  var UPD_REQ = 0;      // rastúce číslo požiadavky (0 = žiadna neodoslaná)
  var UPD_SENT = null;  // hodnota, ktorú odoslala požiadavka `UPD_REQ`

  // Stav, z ktorého sa kreslí: základ z payloadu (uložená cesta, bežiaca
  // verzia, latch), navrch živý výsledok checku a úplne navrchu rozpísaná
  // cesta. Payload cestu NIKDY neprepíše — presne to je „prežije push".
  function updMerged(){
    var about = (SS_STATE && SS_STATE.about) ? SS_STATE.about : null;
    var base = (about && about.updater) ? about.updater : {};
    var live = UPD || {};
    var saved = (live.source_dir != null) ? live.source_dir : (base.source_dir || '');
    var dir = (UPD_DIRTY !== null) ? UPD_DIRTY : saved;
    return {
      enabled: (live.enabled !== undefined) ? live.enabled : (base.enabled !== false),
      source_dir: dir,
      // Token POSLEDNEJ kontroly. Klik ho posiela späť a server aktualizuje
      // LEN vtedy, keď sedí s jeho vlastným záznamom aj s uloženou cestou.
      token: (live.token == null) ? null : live.token,
      // ULOŽENÁ cesta (bez rozpisu). Pri rozpísanej ceste ju stavový riadok
      // MENUJE — inak by človek nevedel, čo je naozaj v nastavení.
      saved_dir: saved,
      // Rozpísaná a NEULOŽENÁ cesta zamyká tlačidlo: aktualizovalo by sa
      // z ULOŽENEJ cesty, nie z tej v poli — klik by spravil niečo iné, než
      // čo má človek pred očami.
      dirty: dir !== saved,
      current: live.current || base.current || '',
      locked: !!(live.locked || base.locked),
      state: live.state || 'idle',
      available: live.available || '',
      reason: live.reason || ''
    };
  }

  // CUDZIA ZMENA CESTY (Codex #278 P1). `updater_settings.json` je súbor
  // POČÍTAČA — uložiť doň môže aj druhá inštancia SketchUpu alebo človek
  // ručne. Plný push potom nesie NOVÚ cestu, ale živý výsledok kontroly
  // (`UPD`) patrí tej STAREJ: tlačidlo by ostalo aktívne, potvrdenie by
  // menovalo cestu A a aktualizovalo by sa z B. Preto sa výsledok ZAHODÍ
  // a — ak je sekcia otvorená — rovno beží nová kontrola.
  function updOnPayload(){
    if (!UPD) return false;
    var about = (SS_STATE && SS_STATE.about) ? SS_STATE.about : null;
    var base = (about && about.updater) ? about.updater : null;
    if (!base || base.source_dir === undefined) return false;
    if (String(UPD.source_dir == null ? '' : UPD.source_dir) === String(base.source_dir || '')) return false;
    UPD = null;
    if (ssActive() === 'about') updSend('updater_check', {});
    return true;
  }

  // POLE IDE ZA ULOŽENOU CESTOU (Codex #278/b1 P2). `SS.updater` prekresľuje
  // len stavový riadok a tlačidlo (telo sa počas písania nesmie prepísať) —
  // lenže cesta sa môže zmeniť ZVONKA (druhá inštancia, ručný zásah do
  // `updater_settings.json`) a prísť aj BEZ plného payloadu. Bez tohto by
  // sekcia hlásila kontrolu priečinka B, v poli by stálo A — a „Uložiť" by
  // B prepísalo späť na A. Rozpísaná cesta má prednosť vždy: tá sa nechá
  // a stavový riadok povie, čo je uložené.
  function updSyncField(u){
    if (!u || u.source_dir == null) return false;
    if (UPD_DIRTY !== null) return false;
    var inp = ssEl('updDir');
    if (!inp) return false;
    var next = String(u.source_dir);
    if (String(inp.value == null ? '' : inp.value) === next) return false;
    inp.value = next;
    return true;
  }

  // Píše používateľ práve do poľa CESTY? Vtedy sa telo sekcie neprekresľuje
  // (vzor `ssTyping`) — re-render by vzal fokus aj rozpísanú cestu.
  function updTyping(){
    if (typeof document === 'undefined') return false;
    var a = document.activeElement;
    return !!(a && a.getAttribute && a.getAttribute('data-updater-edit'));
  }

  function updSend(name, payload){
    if (typeof window === 'undefined' || !window.sketchup || !sketchup[name]) return false;
    sketchup[name](JSON.stringify(payload || {}));
    return true;
  }

  // VSTUP DO SEKCIE = PRESNE JEDEN check. Volajú ho OBA vstupy do `about`
  // (navigácia aj deep-link — `studio.js`), nikdy nie príchod payloadu:
  // plný push chodí pri každej zmene modelu a kontrola verzie siaha na
  // sieťový share (F5).
  function ssOnAboutEnter(){
    UPD = null;   // starý výsledok patril inému vstupu do sekcie
    updSend('updater_check', {});
  }

  // Cielená obnova stavového riadku. Telo sekcie sa NEPREKRESĽUJE: používateľ
  // môže mať kurzor v poli cesty a re-render by mu ho zobral (a s ním aj
  // rozpísanú cestu). Mení sa preto LEN text stavu a stav tlačidla.
  function updPaint(){
    if (typeof document === 'undefined') return false;
    if (ssActive() !== 'about') return false;
    var st = ssEl('updState');
    var btn = ssEl('updBtn');
    if (!st || !btn) return false;
    var u = updMerged();
    var text = (typeof nxUpdaterText === 'function') ? nxUpdaterText(u) : '';
    var on = (typeof nxUpdaterEnabled === 'function') ? nxUpdaterEnabled(u) : false;
    st.textContent = text;
    // `aria-disabled`, nikdy HTML `disabled` (D-78) — tlačidlo ostáva
    // zamerateľné a klik naň povie dôvod.
    if (on && btn.removeAttribute) btn.removeAttribute('aria-disabled');
    else btn.setAttribute('aria-disabled', 'true');
    btn.title = on ? 'Zatvorí Inspector aj Štúdio a nasadí novú verziu' : text;
    return true;
  }

  function updSaveDir(){
    var inp = ssEl('updDir');
    var val = inp ? String(inp.value == null ? '' : inp.value) : (UPD_DIRTY || '');
    UPD_DIRTY = val;
    UPD_SENT = val;   // proti tomuto sa porovná obsah poľa, keď dorazí potvrdenie
    UPD_REQ += 1;     // …a proti tomuto sa porovná, KTORÉMU uloženiu ack patrí
    if (!updSend('updater_set_dir', { source_dir: val, req: UPD_REQ })){
      SS.setStatus('Cestu sa nepodarilo odoslať.', true);
    }
  }

  // Obsah poľa cesty PRÁVE TERAZ (bez DOM padá na rozpísanú hodnotu).
  function updFieldValue(){
    var inp = ssEl('updDir');
    if (inp) return String(inp.value == null ? '' : inp.value);

    return (UPD_DIRTY === null) ? null : UPD_DIRTY;
  }

  // POTVRDENIE PRED SWAPOM (D-15). Bez kostry modalu sa aktualizácia
  // NESPUSTÍ — swap zatvára obe okná a prepisuje súbory pluginu, takže
  // „potvrdenie sa nedalo zobraziť, tak sme to spravili" je neprípustné.
  function updApply(){
    var u = updMerged();
    if (typeof window === 'undefined' || !window.NXModal){
      SS.setStatus('Potvrdenie sa nedá zobraziť (js/nx_modal.js) — aktualizácia sa nespustila.', true);
      return false;
    }
    window.NXModal.open({
      title: 'Aktualizovať Noxun Engine',
      sub: 'Nasadiť ' + (u.available ? ('V' + u.available) : 'novú verziu') + ' z „' + u.source_dir + '"?',
      note: 'Pred výmenou súborov sa ZATVORIA OBE OKNÁ pluginu (Inspector aj Štúdio) — inak ich ' +
            'SketchUp drží otvorené a priečinok sa nedá premenovať. Po dokončení REŠTARTUJ ' +
            'SketchUp; výsledok sa ukáže v okne SketchUpu, nie tu.',
      okLabel: 'Aktualizovať',
      fields: [],
      onSubmit: function(){
        // Modal sa zatvára HNEĎ (výnimka z „zápis nezatvára modal"): okná sa
        // o chvíľu zavrú aj s ním a výsledok chodí natívnou hláškou.
        window.NXModal.close();
        // Klik nesie CESTU A TOKEN kontroly, ktorej vysledok mal clovek pred
        // ocami ? server aktualizuje LEN vtedy, ked mu to sedi s vlastnym
        // zaznamom aj s prave ulozenou cestou (Codex #278 P1).
        updSend('updater_apply', { checked_path: u.source_dir, check_token: u.token });
      }
    });
    return true;
  }

  function updAct(action, btn){
    if (action === 'save-dir'){ updSaveDir(); return; }
    if (action !== 'apply') return;
    if (btn && btn.getAttribute && btn.getAttribute('aria-disabled') === 'true'){
      SS.setStatus((typeof nxUpdaterText === 'function') ? nxUpdaterText(updMerged()) : 'Nedostupné.', true);
      return;
    }
    updApply();
  }

  // --- kreslenie do zdieľaných uzlov --------------------------------------

  // Píše používateľ práve do poľa tejto sekcie? Vtedy sa NEPREKRESĽUJE —
  // re-render by mu zobral fokus aj rozpísané číslo.
  // Pole je pod kurzorom = používateľ ho práve upravuje, takže sa telo
  // NEPREKRESĽUJE (re-render by zobral fokus aj rozpísané číslo). Fokus preto
  // ZMRAZÍ zobrazený obsah — a presne kvôli tomu musí byť revízia pripnutá
  // UŽ VTEDY (review #227 kolo 2): inak by push s cudzou zmenou vymenil
  // `SS_STATE` pod zmrazeným obsahom a prvé písmeno by pripnulo NOVÚ revíziu
  // k STARÝM hodnotám — uloženie by prešlo zámkom a cudziu zmenu ticho
  // prepísalo. S pripnutím pri fokuse sa taký zápis ODMIETNE.
  function ssTyping(){
    if (typeof document === 'undefined') return false;
    var a = document.activeElement;
    return !!(a && a.getAttribute && a.getAttribute('data-ss'));
  }

  function ssDirty(){
    for (var k in SS_DIRTY){ if (Object.prototype.hasOwnProperty.call(SS_DIRTY, k)) return true; }
    return false;
  }

  function ssRenderBody(){
    var sec = ssActive();
    var box = ssEl('secbody');
    if (!sec || !box) return;
    // Zlyhaný payload NESMIE nechať na obrazovke formulár, ktorý vyzerá
    // aktuálne (review #227 P2) — vrátane toho, čo tam bolo pred zlyhaním.
    if (SS_FAILED){
      box.innerHTML = '<div class="err ssfail">Nastavenia sa nepodarilo načítať ' +
        '(chyba pri čítaní súboru). Hodnoty by nemuseli platiť, preto sa nezobrazujú — ' +
        'skús <b>Načítať nanovo</b> v lište sekcie.</div>';
      return;
    }
    if (!SS_STATE){ box.innerHTML = '<div class="muted">Načítavam…</div>'; return; }
    if (ssTyping()) return;
    // PIN ŽIJE PRESNE TAK DLHO, AKO OBSAH, NAD KTORÝM VZNIKOL (dlh 1b-A).
    // Tento riadok je JEDINÉ miesto, kde sa nevyužitý pin uvoľňuje, lebo
    // hneď pod ním je JEDINÉ miesto, kde sa telo prekresľuje z čerstvého
    // `SS_STATE` — a to platí pre OBE cesty: plný push (`ssApplyState`)
    // aj prekreslenie z NAVIGÁCIE (`studioGoSection` → `render` →
    // `renderBody`), ktoré nový push neprináša. Kým bola kontrola len
    // v `ssApplyState`, prežil zastaraný pin odchod zo sekcie a návrat do
    // nej: sekcia ukázala čerstvé hodnoty, ale uloženie skončilo FALOŠNÝM
    // konfliktom a `SS.saved()` rozpísanú prácu zahodil.
    // Podmienka je LEN `!ssDirty()`, a je to zámerné: sme UŽ ZA strážou
    // `ssTyping()` o riadok vyššie (pod kurzorom sa sem nedôjde, obsah
    // ostáva zmrazený a pin sa drží — kontrakt review #227 kolo 2). Keby
    // niekto tú stráž presunul alebo zrušil, uvoľní sa pin pod kurzorom
    // a padne test „pod kurzorom pin ostáva".
    if (!ssDirty()) SS_BASE_REV = null;
    // D-52b: rozpísaná CESTA sa chráni rovnako ako rozpísané sadzby — telo sa
    // neprekresľuje, kým do jej poľa niekto píše. Stráž je AŽ TU (za uvoľnením
    // pinu), aby sa revíznej mechaniky `bset` vôbec nedotkla.
    if (sec === 'about' && updTyping()) return;
    box.innerHTML = '';
    if (sec === 'bset') ssRenderBsetInto(box);
    else if (sec === 'sup') ssRenderSupInto(box);
    else ssRenderAboutInto(box);
  }

  // Lišta: len sekcia `bset` má čo ukladať. `sup` a `about` sú čítanie —
  // prázdna lišta je poctivejšia než tlačidlá, ktoré nič nerobia (D-78).
  // `failed` = posledný payload nedorazil. Lišta vtedy NESMIE ponúkať
  // „Uložiť" (patch proti revízii, ktorú sa práve nedá prečítať), ale MUSÍ
  // nechať „Načítať nanovo" — je to jediná cesta, ako sa z prechodnej chyby
  // disku zotaviť bez zatvorenia Štúdia, a hláška v tele na ňu odkazuje
  // (review #227 kolo 2).
  function ssToolsHtml(sec, failed){
    if (sec !== 'bset') return '';
    if (failed){
      return '<span class="spacer"></span>' +
        '<button type="button" class="ghostbtn" data-action="ss-reload"' +
        ' title="Skúsi znova načítať súbor nastavení">' +
        '<svg class="ic" aria-hidden="true"><use href="#i-rotate-ccw"/></svg> Načítať nanovo</button>';
    }
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
    // Nad neznámym stavom sa NEUKLADÁ — tlačidlo „Uložiť" by poslalo patch
    // proti revízii, ktorá sa práve nedá prečítať.
    box.innerHTML = ssToolsHtml(sec, SS_FAILED);
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
      // NIE `SS_STATE.revision` (tá medzitým omladla plným pushom), ale tá,
      // nad ktorou používateľ písal — inak by zámok servera prešiel a cudzia
      // zmena by zmizla bez slova (review #227 P1).
      var rev = (SS_BASE_REV === null) ? SS_STATE.revision : SS_BASE_REV;
      sketchup.ss_save(JSON.stringify({ revision: rev, patch: built.patch }));
    }
  }

  function ssReload(){
    SS_DIRTY = {};
    SS_BASE_REV = null;
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
    // POTVRDENÝ zápis, načítanie nanovo — a ODMIETNUTIE pre cudziu zmenu:
    // rozpísané hodnoty zanikajú AŽ TU. Pri odmietnutí je to podstatné, nie
    // detail: hláška hovorí „formulár je načítaný nanovo", takže rozpísané
    // čísla nesmú prekryť tie čerstvé a druhým klikom ich ticho prepísať
    // (review #227 P1-2). Čerstvý stav dorazí samostatne plným pushom.
    saved: function(){
      SS_DIRTY = {};
      SS_BASE_REV = null;   // rozpis skončil — ďalší začne od čerstvej revízie
      ssRenderBody();
    },
    // D-52b: stav updatera (výsledok checku, potvrdené uloženie cesty).
    // `saved` je JEDINÉ miesto, kde zaniká rozpísaná cesta — presne ako
    // `SS.saved()` pre sadzby.
    updater: function(u){
      UPD = u || null;
      if (u && u.saved){
        // Potvrdenie patrí TOMU, čo sa odoslalo — a to sa overuje DVAKRÁT:
        // podľa čísla požiadavky (ack staršieho uloženia sa zahodí celý) a
        // podľa obsahu poľa (používateľ mohol medzitým písať ďalej).
        var stale = (u.req != null) && (Number(u.req) !== UPD_REQ);
        var now = updFieldValue();
        if (!stale && (UPD_SENT === null || now === null || now === UPD_SENT)){
          UPD_DIRTY = null;
          UPD_SENT = null;
          var inp = ssEl('updDir');
          // Server cestu NORMALIZUJE (lomítka, koncový oddeľovač) — pole musí
          // ukázať to, čo je naozaj uložené, nie to, čo používateľ napísal.
          if (inp) inp.value = (u.source_dir == null) ? '' : u.source_dir;
        }
      }
      updSyncField(u);
      if (updPaint()) return;
      if (ssActive() === 'about') ssRenderBody();
    }
  };
  if (typeof window !== 'undefined') window.SS = SS;

  // Stav sekcií z payloadu Štúdia (`ST.settings`). Rozpísané hodnoty push
  // NEZAHADZUJE (dôvod v hlavičke súboru) — ale revízia, s ktorou sa bude
  // ukladať, ostáva PRIPNUTÁ na stav, nad ktorým sa začalo písať.
  //
  // `null` = server payload NEVEDEL zostaviť (`settings_payload` spadol na
  // chybe disku a poslal `nil`). Vtedy sa formulár NESMIE tváriť aktuálne:
  // sekcia prejde do chybového stavu a povie to.
  function ssApplyState(s){
    if (s === null || s === undefined){
      SS_FAILED = true;
      if (!ssActive()) return;
      ssRenderBody();
      ssRenderTools();
      return;
    }
    SS_FAILED = false;
    // Review #227 kolo 3: pin, ktorý NIKTO NEVYUŽIL, sa nesmie držať —
    // uvoľňuje ho ale `ssRenderBody` (dlh 1b-A), lebo pin patrí k OBSAHU
    // NA OBRAZOVKE, nie k príchodu payloadu. Tu by kontrola pokryla len
    // cestu pushu; prekreslenie z navigácie by jej ušlo a zastaraný pin by
    // prežil návrat do sekcie (falošný konflikt → zahodená editácia).
    SS_STATE = s;
    // D-52b (Codex #278 P1): cudzia zmena distribucnej cesty zneplatni zivy
    // vysledok kontroly ? musi to bezat AJ ked sekcia  prave otvorena
    // nie je, inak by sa do nej clovek vratil so stavom o inom priecinku.
    updOnPayload();
    if (!ssActive()) return;
    ssRenderBody();
    ssRenderTools();
  }

  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var ssPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      // Kľúč `settings` posiela `push_state` VŽDY — jeho `null` je teda
      // SIGNÁL („nepodarilo sa"), nie „nič nové". Rozlišuje sa preto
      // prítomnosť kľúča, nie pravdivosť hodnoty.
      if (data && Object.prototype.hasOwnProperty.call(data, 'settings')) ssApplyState(data.settings);
      ssPrevSetStudio(data);
    };
  }

  if (typeof document !== 'undefined'){
    // Pin sa berie UŽ PRI FOKUSE — v okamihu, keď sa pole stane cieľom písania.
    // Prvé písmeno je neskoro: medzi fokusom a ním môže doraziť push s cudzou
    // zmenou. (Nad nerozpísaným formulárom ho pri najbližšom prekreslení tela
    // zase uvoľní `ssRenderBody`, takže sa pin a zobrazený obsah nemôžu rozísť
    // — ani po odchode zo sekcie a návrate do nej.)
    document.addEventListener('focusin', function(ev){
      var t = ev && ev.target;
      if (!t || !t.getAttribute || !t.getAttribute('data-ss')) return;
      if (SS_BASE_REV === null && SS_STATE) SS_BASE_REV = SS_STATE.revision;
    });
    document.addEventListener('input', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      // D-52b: VLASTNÝ namespace updatera. Vetva končí `return` ešte PRED
      // celou revíznou mechanikou — písanie cesty sa nesmie dotknúť ani
      // `SS_DIRTY`, ani pripnutej revízie dodávateľa (F7).
      if (t.getAttribute('data-updater-edit')){
        UPD_DIRTY = String(t.value == null ? '' : t.value);
        // Codex #278 kolo 2 (P2): rozpísaná cesta MENÍ STAV tlačidla (kontrola
        // patrí ULOŽENEJ ceste), ale telo sa počas písania neprekresľuje —
        // tlačidlo by ostalo aktívne a klik by aktualizoval z inej cesty, než
        // akú má človek pred očami. Preto sa stavový riadok obnoví CIELENE.
        updPaint();
        return;
      }
      var key = t.getAttribute('data-ss');
      if (!key) return;
      // Prvé písmeno PRIPNE revíziu, nad ktorou sa formulár rozpisuje.
      if (SS_BASE_REV === null && SS_STATE) SS_BASE_REV = SS_STATE.revision;
      SS_DIRTY[key] = t.value;
      var v = ssParse(t.value);
      t.classList.toggle('bad', typeof v === 'number' && isNaN(v));
    });
    // D-52b: Enter v poli cesty = uloženie (druhá cesta je mini-tlačidlo).
    // Pole žije mimo formulára, takže Enter by inak neurobil nič.
    document.addEventListener('keydown', function(ev){
      if (!ev || ev.key !== 'Enter') return;
      var t = ev.target;
      if (!t || !t.getAttribute || !t.getAttribute('data-updater-edit')) return;
      if (ev.preventDefault) ev.preventDefault();
      updSaveDir();
    });
    document.addEventListener('click', function(ev){
      var b = ev.target && ev.target.closest
        ? ev.target.closest('[data-action],[data-ssgo],[data-updater-act]') : null;
      if (!b) return;
      var ua = b.getAttribute('data-updater-act');
      if (ua){ updAct(ua, b); return; }
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
                       ssBaseRev: function(){ return SS_BASE_REV; },
                       ssTyping: ssTyping,
                       ssFailed: function(){ return SS_FAILED; },
                       // D-52b (tests/js/test_d52b_updater_ui.js)
                       ssOnAboutEnter: ssOnAboutEnter, updMerged: updMerged,
                       updOnPayload: updOnPayload,
                       updPaint: updPaint, updSaveDir: updSaveDir, updApply: updApply,
                       updAct: updAct, updTyping: updTyping,
                       updDirty: function(){ return UPD_DIRTY; },
                       updSent: function(){ return UPD_SENT; },
                       updReq: function(){ return UPD_REQ; },
                       SS_SECTIONS: SS_SECTIONS, SS: SS };
  }
