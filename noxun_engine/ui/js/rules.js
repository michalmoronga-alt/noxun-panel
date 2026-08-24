  // ===================== Pravidla kovania — sekcia `rules` =====================
  // RD_RULES drzi PLNE objekty pravidiel (vratane neznamych klucov buducich
  // verzii); formular edituje len zname polia (enabled/quantity/bands/series/
  // clearance), `rdCollectRules()` ich prepise na kopii — nic sa nestrati.
  // Normalizaciu (sort pasiem, clamp poctov) robi Ruby po Ulozit.
  //
  // ŠT-3b-1: subor sa PRESUNUL z okna „Pravidlá kovania" (zaniklo) do sekcie
  // Studia. Presun NEMOHOL byt 1:1 — subor definoval globalne `el` a `esc`,
  // teda PRESNE tie, ktore uz ma `studio.js`. V spolocnom okne by si prepisali
  // cudzie funkcie a padlo by nieco uplne ine nez pravidla. Vsetko je preto
  // prefixovane `rd*`/`RD_*` (vzor `bud*` v budget.js, `mdh*` v hw_catalog.js);
  // PRIJIMACE `RD.init`/`RD.setRules`/`RD.setStatus` si mena PONECHALI — server
  // posiela presne to, co posielal doteraz (jedna pravda o mene kanala).

  var RD_RULES = [];
  // Odtlacok pravidiel, ktorymi bol formular NAPLNENY. Sluzi na rozhodnutie,
  // ci push zo servera ma formular prekreslit — viz `rdApplyState`.
  var RD_SEED = null;
  var RD_META = { version: '', source: '', cabinets: 0 };
  // ŠT-3b-2a: READ-ONLY casti sekcie (ABS pravidla podla roly + jantarove riadky
  // rucnych zasahov). Ziju MIMO `RD_RULES` a mimo zapadky `RD_NEEDS_RENDER`:
  // nie je v nich co rozpisat, takze sa prekresluju pri KAZDOM pushi zo servera
  // (vzor `rdSrcLine`). Formulara pravidiel kovania sa nedotykaju.
  var RD_ABS = null;
  var RD_OVR = null;
  // Review #220 P1: „formular je vykresleny a jeho hodnoty ziju v DOM".
  // Kym plati, prekreslit ho smie UZ LEN zmena pravidiel NA MODELI — nie
  // pripojenie tela pri navrate do sekcie. Rucne hodnoty (`.rqty`, `.bmax`,
  // `.bqty`, `.rseries`, `.rclr`) ziju totiz LEN v DOM: do `RD_RULES` sa
  // preberaju az cez `rdSyncFromForm` pri „+ pásmo"/„✕". Uzol sa pri odchode
  // zo sekcie IBA ODPOJI (hodnoty v nom ostanu), takze staci ho neprekreslit.
  var RD_NEEDS_RENDER = true;

  function rdEl(id){ return document.getElementById(id); }
  function rdEsc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function rdLabel(t){
    return { leg:'Nohy', hinge:'Závesy', slide:'Výsuvy', handle:'Úchytky',
             shelf_pin:'Podperky', connector:'Spojky',
             wall_hanger:'Zavesenie na stenu' }[t] || t;
  }
  function rdRoleDesc(r){
    // GH #126 P2: popis podla SKUTOCNYCH filtrov pravidla — cabinet pravidlo
    // moze cielit podla podopretia (nohy) ALEBO typu korpusu (Bystrica).
    var ap = (r.applies_to || {}); var role = ap.role || '';
    if (role === 'cabinet'){
      var kinds = ap.cabinet_type || [];
      var hasU = kinds.indexOf('upper') >= 0, hasL = kinds.indexOf('lower') >= 0;
      if (hasU && !hasL) return 'na hornú skrinku';
      if (hasL && !hasU) return 'na spodnú skrinku';
      if ((ap.support || []).length) return 'na skrinku s podstavcom';
      return 'na každú skrinku';
    }
    if (role === 'front_door') return 'na každé krídlo dvierok';
    if (role === 'drawer_front') return 'na každé zásuvkové čelo';
    if (role === 'shelf') return 'na každú policu';
    return role;
  }

  // Prijimace zo servera. Mena su ZAMERNE nezmenene (`RD.*`) — Ruby posiela
  // presne to, co posielal oknu.
  var RD = {
    init: function(data){
      rdSetState(data);
      RD_NEEDS_RENDER = true;
      rdRender();
      rdRenderExtra();
    },
    setRules: function(rules, _source){
      RD_RULES = rules || [];
      // „Načítať globálne predvoľby" je ZAMERNE zmena formulara, ktora este
      // NEPLATI — odtlacok sa preto NEobnovuje: najblizsi push zo servera
      // (s pravidlami projektu) by inak formular potichu prepisal spat.
      RD_NEEDS_RENDER = true;
      rdRender();
    },
    setStatus: function(msg, err){
      var e = rdEl('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    }
  };
  if (typeof window !== 'undefined') window.RD = RD;

  function rdSetState(data){
    var d = data || {};
    RD_RULES = d.rules || [];
    RD_SEED = JSON.stringify(RD_RULES);
    RD_META = { version: d.version || '', source: d.source || '',
                cabinets: d.cabinets || 0, model_guid: d.model_guid || '' };
    rdSetExtra(d);
  }

  // ŠT-3b-2a: read-only casti sa nasadzuju ZVLAST od formulara — chodia
  // s KAZDYM pushom a nemaju odtlacok (nie je v nich co rozpisat).
  function rdSetExtra(d){
    RD_ABS = (d && d.abs) || null;
    RD_OVR = (d && d.overrides) || null;
  }

  // ---------- ŠT-3b-2a: ABS podla roly + jantarove riadky (len citanie) ------
  //
  // VSETKY texty (nazvy rol, popisy pravidiel, zhrnutia overridov, hlaska
  // o skratenom zozname) sklada SERVER — tu sa uz iba escapuju a ukladaju do
  // riadkov. Klient nema ziadnu vlastnu tabulku prekladov, takze sa nema s cim
  // rozist (rovnaky kontrakt ako `role_label` v Kusovniku).
  function rdIco(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

  // Argument do `onclick` — VZDY cez JSON.stringify + escape (vzor
  // `mdWhereEyeHtml`): nazvy skriniek a kluce dielcov su text z modelu, ktory
  // pise pouzivatel, a surovo vlozeny by rozbil atribut aj celu sekciu.
  function rdArg(v){ return rdEsc(JSON.stringify(String(v == null ? '' : v))); }

  // Jeden riadok: nazov · popis · hodnota (+ oko pri override riadku).
  function rdRowHtml(r, over){
    var h = '<div class="rdrow' + (over ? ' rdovr' : '') + '">' +
      '<span class="rdnm">' + rdEsc(r.label) +
      (over ? ' <span class="rdchip">override</span>' : '') + '</span>' +
      '<span class="rddesc">' + rdEsc(r.desc) + '</span>' +
      '<span class="rdval">' + rdEsc(r.value) + '</span>';
    if (over){
      // Mockup oko v override riadku NEMA — je to vedome doplnenie: bez neho
      // sa riadok „Polica v CAB-004" v modeli nedá nájsť. Adresa je dvojica
      // (owner_id, part_key), server si dielce dohladá v ČERSTVOM zbere.
      h += '<span class="rdact"><button type="button" class="rdeye" title="Označiť v modeli"' +
        ' aria-label="Označiť v modeli" onclick="rdSelectOverride(' +
        rdArg(r.owner_id) + ', ' + rdArg(r.part_key) + ')">' +
        rdIco('eye') + '</button>' +
        // ŠT-3b-2b: „vrátiť na pravidlo" (mockup Š17). Potvrdenie sa NEPYTA —
        // poistkou je JEDEN krok Spat; otazka pred kazdym klikom by z opravy
        // urobila obrad. Adresa riadku ide na server, ktory si skrinku dohlada
        // podla identity (ziadne pids ani zavislost na oznaceni v modeli).
        '<button type="button" class="rdundo" title="Vrátiť na pravidlo — jeden krok Späť to vráti"' +
        ' aria-label="Vrátiť na pravidlo" onclick="rdResetOverride(' +
        rdArg(r.kind) + ', ' + rdArg(r.owner_id) + ', ' + rdArg(r.part_key) + ', ' +
        rdArg(r.generic_type) + ', ' + rdArg(r.rule_id) + ')">' +
        rdIco('rotate-ccw') + '</button></span>';
    }
    return h + '</div>';
  }

  // Zoznam rucnych zasahov: zoskupeny po skrinkach, so stropom a suhrnom (F15).
  // Prazdny zoznam nekresli NIC — vertikalny priestor sekcie je vzacny a
  // „ziadne rucne zasahy" je normalny stav, nie informacia.
  function rdOvrHtml(g){
    if (!g || !g.total) return '';
    // Ikona je CERUZKA, nie vystrazny trojuholnik (F11): riadok hovorí, že tu rozhodol človek —
    // nie že je niečo zle. Stavy olepu hlási KONTROLA a nič z tohto zoznamu
    // do jej počtov nevstupuje.
    var h = '<div class="rdovrbox"><div class="rdovrh">' + rdIco('pencil') + ' ' + rdEsc(g.title) + '</div>';
    (g.groups || []).forEach(function(grp){
      h += '<div class="rdgrp"><div class="rdgrph">' + rdEsc(grp.title) + '</div>';
      (grp.rows || []).forEach(function(r){ h += rdRowHtml(r, true); });
      h += '</div>';
    });
    if (g.more_text) h += '<div class="rdmore">' + rdEsc(g.more_text) + '</div>';
    if (g.note) h += '<div class="hint">' + rdEsc(g.note) + '</div>';
    return h + '</div>';
  }

  function rdAbsRulesHtml(abs){
    var rows = (abs && abs.rows) || [];
    if (!rows.length) return '<div class="muted">Žiadne ABS pravidlá.</div>';
    var h = '';
    rows.forEach(function(r){ h += rdRowHtml(r, false); });
    return h;
  }

  // Kresli sa pri KAZDOM pushi. Ked je telo sekcie odpojene, `rdEl` vrati null
  // a funkcia je no-op — obsah dobehne pri navrate (`rulesRenderBody`).
  function rdRenderExtra(){
    var box = rdEl('rdAbsBox');
    if (box) box.innerHTML = rdAbsRulesHtml(RD_ABS);
    var src = rdEl('rdAbsSrc');
    if (src) src.textContent = (RD_ABS && RD_ABS.source) || '';
    var hint = rdEl('rdAbsHint');
    if (hint) hint.textContent = (RD_ABS && RD_ABS.hint) || '';
    var abs = rdEl('rdAbsOvr');
    if (abs) abs.innerHTML = rdOvrHtml(RD_OVR && RD_OVR.abs);
    var hw = rdEl('rdHwOvr');
    if (hw) hw.innerHTML = rdOvrHtml(RD_OVR && RD_OVR.hardware);
  }

  // Klik na oko. Ide TOU ISTOU cestou ako vyber v Kusovniku (`nx_select` cez
  // relay panela) a nesie generaciu okna — ziadne pids z DOM.
  function rdSelectOverride(ownerId, partKey){
    var st = (typeof ST === 'undefined') ? null : ST;
    if (!st || typeof window === 'undefined' || !window.sketchup || !sketchup.nx_select) return;
    sketchup.nx_select(JSON.stringify({ gen: st.gen || 0,
                                        rule_ref: { owner_id: String(ownerId || ''),
                                                    part_key: String(partKey || '') } }));
  }
  if (typeof window !== 'undefined') window.rdSelectOverride = rdSelectOverride;

  // ŠT-3b-2b: „vrátiť na pravidlo". Mena callbackov su KANALOVE konstanty
  // (nie preklad ani domenovy text) — klient ich nesklada z dat servera,
  // aby sa z payloadu nedalo zavolat nic ine; co sa smie zavolat, aj tak
  // rozhoduje uzavrety whitelist na serveri.
  var RD_RESET_ACTION = { abs: 'reset_abs_override', hw: 'reset_hw_override' };

  function rdResetOverride(kind, ownerId, partKey, genericType, ruleId){
    var name = RD_RESET_ACTION[String(kind)];
    var st = (typeof ST === 'undefined') ? null : ST;
    if (!name || !st || typeof window === 'undefined' || !window.sketchup || !sketchup[name]) return;
    // Zapis nesie OBE identity: generaciu okna (klik zo zastaraneho zoznamu
    // sa nesmie vykonat) a dokument (panel/sekcia z ineho .skp nesmie zapisat).
    sketchup[name](JSON.stringify({ gen: st.gen || 0,
                                    model_guid: (RD_META && RD_META.model_guid) || '',
                                    owner_id: String(ownerId || ''),
                                    part_key: String(partKey || ''),
                                    generic_type: String(genericType || ''),
                                    rule_id: String(ruleId || '') }));
    RD.setStatus('Vraciam na pravidlo…', false);
  }
  if (typeof window !== 'undefined') window.rdResetOverride = rdResetOverride;

  function rdSrcLine(){
    return 'zdroj: ' + (RD_META.source === 'project'
      ? 'tento projekt'
      : 'globálne predvoľby (projekt ešte nemá vlastné)') +
      ' · skriniek v modeli: ' + (RD_META.cabinets || 0);
  }

  function rdRender(){
    var line = rdEl('rdSrcLine');
    if (line) line.textContent = rdSrcLine();
    var box = rdEl('rulesBox');
    if (!box) return;
    var html = '';
    RD_RULES.forEach(function(r, i){
      html += '<div class="rrule" data-i="'+i+'">';
      html += '<div class="rhead"><label><input type="checkbox" class="ren" '+(r.enabled!==false?'checked':'')+'> '
            + '<b>'+rdEsc(rdLabel(r.output))+'</b></label> <span class="rid">'+rdEsc(rdRoleDesc(r))+'</span></div>';
      if (r.kind === 'fixed'){
        html += '<div class="rrow"><label>Počet</label><input class="rqty rnum" type="number" min="1" max="999" step="1" value="'+rdEsc(r.quantity!=null?r.quantity:1)+'"><span class="unit">ks</span></div>';
      } else if (r.kind === 'bands'){
        html += '<div class="rbands">';
        (r.bands || []).forEach(function(b, bi){
          var last = (b.max === null || b.max === undefined);
          html += '<div class="rrow rband" data-bi="'+bi+'">'
                + (last ? '<label>všetko nad</label><span class="bmaxfill"></span>'
                        : '<label>do</label><input class="bmax rnum" type="number" min="1" step="1" value="'+rdEsc(b.max)+'"><span class="unit">mm</span>')
                + '<span class="arrow">→</span><input class="bqty rnum" type="number" min="1" max="999" step="1" value="'+rdEsc(b.quantity)+'"><span class="unit">ks</span>'
                + (last ? '<span class="bdel"></span>' : '<button class="ghostbtn bdel" title="Odstrániť pásmo" onclick="rdDelBand(this)">✕</button>')
                + '</div>';
        });
        html += '<div class="btnrow"><button class="ghostbtn" onclick="rdAddBand(this)">+ pásmo</button></div>';
        html += '</div>';
      } else if (r.kind === 'fit_series'){
        html += '<div class="rrow"><label>Rad dĺžok</label><input class="rseries" type="text" value="'+rdEsc((r.series||[]).join(', '))+'"><span class="unit">mm</span></div>';
        html += '<div class="rrow"><label>Rezerva</label><input class="rclr rnum" type="number" min="0" step="1" value="'+rdEsc(r.clearance!=null?r.clearance:10)+'"><span class="unit">mm</span></div>';
        html += '<div class="rrow"><label>Počet</label><input class="rqty rnum" type="number" min="1" max="999" step="1" value="'+rdEsc(r.quantity!=null?r.quantity:1)+'"><span class="unit">sád</span></div>';
        html += '<div class="hint">Vyberie sa najväčšia dĺžka z radu, ktorá sa zmestí do svetlej hĺbky mínus rezerva.</div>';
      } else if (r.kind === 'part_flag_length'){
        // D-90: pravidlo bez nastavení — reaguje na príznak profilu na čele.
        html += '<div class="hint">Platí len pre čelá so zapnutým úchytkovým profilom — 1 kus na čelo, dĺžka rezu = šírka krídla. Vypnutím vyššie sa profil prestane počítať.</div>';
      } else {
        html += '<div class="hint">Pravidlo novšej verzie („'+rdEsc(r.kind)+'“) — tu sa needituje, zostáva zachované.</div>';
      }
      html += '</div>';
    });
    if (!html) html = '<div class="muted">Žiadne pravidlá — načítaj globálne predvoľby.</div>';
    box.innerHTML = html;
    // Vykreslene: od tejto chvile su hodnoty formulara v DOM a pripojenie
    // tela pri navrate do sekcie ich uz NESMIE prepisat.
    RD_NEEDS_RENDER = false;
  }

  function rdRuleNode(node){ return node.closest('.rrule'); }

  // Pred KAZDYM re-renderom prevezmi CELY formular do RD_RULES — inak by
  // pridanie/odobratie pasma zahodilo rozeditovane hodnoty ostatnych pravidiel
  // (pocty, checkboxy, series/rezervu) este pred Ulozit (Codex review PR #25).
  function rdSyncFromForm(){ RD_RULES = rdCollectRules(); }

  function rdAddBand(btn){
    var i = parseInt(rdRuleNode(btn).dataset.i, 10);
    rdSyncFromForm();
    var r = RD_RULES[i];
    // nove pasmo pred "vsetko nad": max = posledny konkretny max + 500 (orientacne)
    var maxes = (r.bands || []).filter(function(b){ return b.max != null; }).map(function(b){ return b.max; });
    var nm = maxes.length ? Math.max.apply(null, maxes) + 500 : 900;
    r.bands.splice(Math.max(r.bands.length - 1, 0), 0, { max: nm, quantity: 1 });
    rdRender();
  }
  function rdDelBand(btn){
    var i = parseInt(rdRuleNode(btn).dataset.i, 10);
    var bi = parseInt(btn.closest('.rband').dataset.bi, 10);
    rdSyncFromForm();
    RD_RULES[i].bands.splice(bi, 1);
    rdRender();
  }
  function rdCollectBands(ruleEl){
    var out = [];
    ruleEl.querySelectorAll('.rband').forEach(function(row){
      var maxInp = row.querySelector('.bmax');
      var q = parseInt(row.querySelector('.bqty').value, 10);
      out.push({ max: maxInp ? (parseFloat(maxInp.value) || null) : null,
                 quantity: (isNaN(q) || q < 1) ? 1 : q });
    });
    return out;
  }

  // Zozbiera formular do kopii povodnych pravidiel (nezname kluce ostavaju).
  function rdCollectRules(){
    var out = [];
    document.querySelectorAll('.rrule').forEach(function(ruleEl){
      var src = RD_RULES[parseInt(ruleEl.dataset.i, 10)];
      var r = JSON.parse(JSON.stringify(src));
      r.enabled = ruleEl.querySelector('.ren').checked;
      var qty = ruleEl.querySelector('.rqty');
      if (qty){ var q = parseInt(qty.value, 10); r.quantity = (isNaN(q) || q < 1) ? 1 : q; }
      if (r.kind === 'bands') r.bands = rdCollectBands(ruleEl);
      if (r.kind === 'fit_series'){
        r.series = ruleEl.querySelector('.rseries').value.split(/[,;\s]+/)
          .map(function(s){ return parseFloat(s); })
          .filter(function(v){ return !isNaN(v) && v > 0; });
        var c = parseFloat(ruleEl.querySelector('.rclr').value);
        r.clearance = isNaN(c) ? 10 : Math.max(0, c);
      }
      out.push(r);
    });
    return out;
  }

  // Klientska kontrola pred odoslanim — CISTA funkcia (Node test). Vracia
  // hlasku, alebo null ked je formular v poriadku. Server validuje znova;
  // toto je len to, co sa da povedat BEZ neho.
  function rdValidate(rules){
    for (var i = 0; i < (rules || []).length; i++){
      var r = rules[i];
      if (r.kind === 'bands' && r.enabled !== false){
        var hasCatchAll = (r.bands || []).some(function(b){ return b.max == null; });
        if (!(r.bands || []).length || !hasCatchAll){
          return 'Pravidlo „' + rdLabel(r.output) + '“ potrebuje aspoň pásmo „všetko nad“.';
        }
      }
      if (r.kind === 'fit_series' && r.enabled !== false && !(r.series || []).length){
        return 'Pravidlo „' + rdLabel(r.output) + '“ potrebuje aspoň jednu dĺžku v rade.';
      }
    }
    return null;
  }

  function rdSaveRules(){
    var rules = rdCollectRules();
    var bad = rdValidate(rules);
    if (bad){ RD.setStatus(bad, true); return; }
    var chk = rdEl('alsoGlobal');
    if (window.sketchup && sketchup.save_rules){
      sketchup.save_rules(JSON.stringify({ rules: rules,
                                           also_global: !!(chk && chk.checked),
                                           model_guid: RD_META.model_guid || '' }));
    }
  }
  function rdLoadGlobal(){
    if (window.sketchup && sketchup.load_global) sketchup.load_global('');
  }

  // V0.6 D1b (audit F4): vedome doplnenie novych seed pravidiel do projektu.
  function rdMergeSeed(){
    if (window.sketchup && sketchup.merge_seed) sketchup.merge_seed('');
  }

  // ================= ŠT-3b-1: SEKCIA `rules` v okne Studio =====================
  //
  // Bezi TU, nie v `studio.js`: obsah sekcie je presun formulara a jeho jedina
  // autorita je tento subor (vzor `js/hw_catalog.js` a `js/proj_materials.js`).

  // Zdielany markup jantaroveho „Obnoviť" zo `studio.js`. V prehliadaci je to
  // global suboru, ktory sa nacitava PRED tymto; v Node testoch pride requirom.
  var RD_STUDIO = (typeof module !== 'undefined' && module.exports)
    ? require('./studio.js')
    : null;

  // LISTA sekcie — CISTA funkcia (Node test). Stav chodi ARGUMENTOM (vzor
  // `matToolsHtml`/`hwToolsHtml`), takze sa da testovat bez DOM.
  // Poradie je vzor listy Studia: PRIMARNA akcia vlavo, nastroje vpravo.
  function rulesToolsHtml(st){
    var s = st || {};
    var ico = function(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; };
    var h = '<button type="button" class="primary" id="rdSaveBtn" onclick="rdSaveRules()"' +
      ' title="Uloží pravidlá do projektu a prestaví všetky skrinky — 1 krok Späť">' +
      ico('check') + ' Uložiť a prestavať skrinky</button>' +
      '<label class="rdchk" title="Zapíše pravidlá aj do globálnych predvolieb — platia pre NOVÉ projekty">' +
      '<input type="checkbox" id="alsoGlobal"' + (s.also_global ? ' checked' : '') +
      '> aj ako globálnu predvoľbu</label>' +
      '<button type="button" class="ghostbtn" id="rdLoadBtn" onclick="rdLoadGlobal()"' +
      ' title="Naplní formulár globálnymi predvoľbami — platia až po Uložiť">' +
      ico('download') + ' Načítať globálne</button>' +
      // V0.6 D1b (audit F4): nove seed pravidla sa do projektu dostanu LEN
      // touto vedomou akciou (snapshot sa nikdy nemerguje sam).
      '<button type="button" class="ghostbtn" id="rdSeedBtn" onclick="rdMergeSeed()"' +
      ' title="Doplní do projektu nové predvolené pravidlá (napr. zavesenie hornej skrinky,' +
      ' podperky) a obnoví nezmenené na aktuálny tvar — tvoje úpravy nechá.">' +
      ico('plus') + ' Doplniť nové predvolené</button>' +
      '<span class="spacer"></span>';
    var refresh = (typeof refreshBtnHtml === 'function')
      ? refreshBtnHtml
      : (RD_STUDIO ? RD_STUDIO.refreshBtnHtml : null);
    if (refresh) h += refresh(s.stale === true, 'Načítať pravidlá z aktuálneho modelu');
    return h;
  }

  function rulesToolsState(stale){
    var chk = rdEl('alsoGlobal');
    return { also_global: !!(chk && chk.checked), stale: stale === true };
  }

  function rulesRenderTools(stale){
    var box = rdEl('sectools');
    if (box) box.innerHTML = rulesToolsHtml(rulesToolsState(stale));
  }

  // TELO sekcie. Je to JEDEN uzol naklonovany RAZ zo sablony v studio.html
  // a potom uz LEN putuje: prepnutie sekcie ho z `#secbody` vyberie, navrat
  // ho vrati aj s ROZPISANYM formularom. Bez toho by kazdy odchod do
  // Kusovnika zmazal rozrobene pravidla.
  var RD_BODY = null;
  function rdBodyNode(){
    if (RD_BODY) return RD_BODY;
    var tpl = rdEl('rulesBodyTpl');
    RD_BODY = document.createElement('div');
    RD_BODY.id = 'rulesBody';
    if (tpl && tpl.content) RD_BODY.appendChild(tpl.content.cloneNode(true));
    else if (tpl) RD_BODY.innerHTML = tpl.innerHTML;
    return RD_BODY;
  }

  function rulesRenderBody(){
    var box = rdEl('secbody');
    if (!box) return;
    var node = rdBodyNode();
    if (node.parentNode !== box){
      box.innerHTML = '';
      box.appendChild(node);
    }
    // Formular sa kresli LEN ked to naozaj treba (prvy vstup do sekcie,
    // alebo zmena pravidiel NA MODELI, ktora prisla, kym bolo telo
    // odpojene). Pri NAVRATE do sekcie sa NEDOTYKA — rucne hodnoty ziju
    // v DOM uzla, ktory odchodom iba vypadol z `#secbody` (review #220 P1;
    // predtym ich kazdy navrat ticho zahodil).
    // ŠT-3b-2a: read-only casti (ABS pravidla, jantarove riadky) sa kreslia
    // VZDY — su to cisla a texty zo servera, nie rozpisane hodnoty.
    rdRenderExtra();
    if (RD_NEEDS_RENDER){
      rdRender();
      return;
    }
    // Meta riadok (zdroj, pocet skriniek) sa obnovuje VZDY — je to cislo
    // zo servera, nie rozpisana hodnota.
    var line = rdEl('rdSrcLine');
    if (line) line.textContent = rdSrcLine();
  }

  // Modelovy kontext sekcie z payloadu Studia (`ST.rules`).
  //
  // KONTRAKT: rozpisany formular NESMIE zmiznut pri kazdom pushi — a pushov
  // chodi vela (prepocet kusovnika, zapis rozpoctu, zmena katalogu). Formular
  // sa preto prekresluje LEN vtedy, ked sa pravidla NA MODELI naozaj zmenili
  // (odtlacok `RD_SEED`): vlastne ulozenie, „Doplniť nové predvolené",
  // prepnutie dokumentu, Spat/Znova alebo odmietnuty zapis (server posle
  // cerstvy stav). Inak sa nasadi len meta (zdroj, pocet skriniek).
  function rdApplyState(r){
    if (!r) return;
    var seed = JSON.stringify(r.rules || []);
    if (seed === RD_SEED){
      RD_META = { version: r.version || '', source: r.source || '',
                  cabinets: r.cabinets || 0, model_guid: r.model_guid || '' };
      // ŠT-3b-2a: read-only casti sa obnovuju AJ TU — rucny zasah v Inspectore
      // (novy override) pravidla NEMENI, takze odtlacok formulara je ten isty
      // a riadok by sa bez tohto objavil az po prepnuti sekcie.
      rdSetExtra(r);
      rdRenderExtra();
      return;
    }
    rdSetState(r);
    rdRenderExtra();
    // Pravidla NA MODELI sa zmenili — formular UZ neplati a musi sa
    // prekreslit. Ked je telo sekcie odpojene, `rdRender` je no-op
    // (`rdEl` vrati null) a priznak ostane zdvihnuty, takze prekreslenie
    // dobehne pri NAVRATE do sekcie.
    RD_NEEDS_RENDER = true;
    rdRender();
  }

  // Napojenie na kanal Studia. `studio.js` (a za nim `budget.js`,
  // `proj_materials.js`, `hw_catalog.js`) uz `window.NX` vytvorili — tento
  // subor sa nacitava AZ ZA nimi, takze obal je bezpecny.
  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var rdPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      // Stav sa nasadi PRED renderom Studia — `rulesRenderBody` uz kresli
      // z cerstvych dat a nikto nekresli dvakrat.
      rdApplyState(data && data.rules);
      rdPrevSetStudio(data);
    };
  }

  // Node testy (tests/js/test_st3b_rules.js) — CISTE funkcie bez DOM
  // (`rulesToolsHtml`, `rdValidate`, `rdLabel`, `rdRoleDesc`) + `rulesRenderBody`
  // a `rdApplyState`, ktore DOM potrebuju a exportuju sa ZAMERNE: kontrakt
  // „push zo servera nezmaze rozpisany formular" sa inak nedal overit nicim
  // nez klikanim (rovnaky dovod ako pri `matRenderBody`).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { rulesToolsHtml: rulesToolsHtml, rdValidate: rdValidate,
                       rdLabel: rdLabel, rdRoleDesc: rdRoleDesc,
                       rulesRenderBody: rulesRenderBody, rdApplyState: rdApplyState,
                       rdCollectRules: rdCollectRules, RD: RD,
                       // ŠT-3b-2a: read-only bloky — `rdOvrHtml`/`rdAbsRulesHtml` su
                       // ciste funkcie (kontrola escapovania a stropu zoznamu),
                       // `rdRenderExtra` + `rdSelectOverride` potrebuju DOM a
                       // exportuju sa ZAMERNE: „push nezmaze rozpisany formular,
                       // ale jantarove riadky obnovi" sa inak overit neda.
                       rdOvrHtml: rdOvrHtml, rdAbsRulesHtml: rdAbsRulesHtml,
                       rdRenderExtra: rdRenderExtra, rdSelectOverride: rdSelectOverride,
                       // ŠT-3b-2b: zapisovy klik — testuje sa, ze nesie OBE
                       // identity (generacia okna + dokument) a ze meno akcie
                       // vybera KLIENT z uzavretej mapy, nie payload servera.
                       rdResetOverride: rdResetOverride };
  }
  // ŠT-3b-1: `sketchup.ready('')` tu ZANIKLO. V okne „Pravidlá kovania" bol
  // tento subor POSLEDNY a jeho `ready` znamenal „HTML je nacitane"; okno
  // zaniklo a v Studiu `ready` posiela `studio.js` (`window.onload`) — druhe
  // volanie by prinutilo okno poslat CELY payload dvakrat.
