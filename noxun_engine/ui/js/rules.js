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
  // ŠT-3b-2c2: ODTLAČOK pravidiel zo servera (`rules_rev`). Klient ho NIKDY
  // nepočíta — iba drží a pri uložení vracia. Vlastný výpočet by ani nemohol
  // sedieť: Ruby serializuje `900.0`, JS `900`, takže bajtové porovnanie by
  // zlyhalo vždy.
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
  // Codex #330 kolo 1 (P2): pole zo snapshotu NEMUSI byt pole. Cudzi alebo
  // pokazeny zaznam moze niest `bands`/`weight_bands`/`series` ako hash alebo
  // retazec — serverova `normalize_rules` cisti LEN polia, takze taky tvar
  // dojde az sem. Sekcia Pravidla sa kresli JEDNYM `innerHTML`, takze jediny
  // `.forEach` nad hashom by zhodil CELU sekciu (a s nou aj moznost chybu
  // opravit) skor, nez by o nej stihla povedat validacia pri ulozeni.
  // KAZDE pole zo snapshotu preto ide cez tuto branu.
  function rdArr(v){ return Array.isArray(v) ? v : []; }
  // Review #223 (NOTE 2): názvy MUSIA byť tie isté ako serverové
  // `HardwareRules.label_for` — tá istá hláška o tom istom pravidle chodí raz
  // z klienta (`rdValidate`) a raz zo servera (`rules_problems`), takže „Výsuvy"
  // tu a „Výsuv" tam by bola jedna vec s dvoma menami. Zhodu stráži guard test.
  function rdLabel(t){
    return { leg:'Nohy', hinge:'Závesy', slide:'Výsuv', handle:'Úchytky',
             shelf_pin:'Podperky', connector:'Spojky',
             wall_hanger:'Zavesenie na stenu',
             lift:'Výklop / sklop' }[t] || t;
  }
  // TEST-1 (Michalov test v0.8.0): pravidlá „Úchytky" sú DVE — jedno pre
  // dvierka (`front_door`), druhé pre zásuvkové čelá (`drawer_front`) — a mali
  // JEDNU spoločnú vysvetlivku o „šírke krídla". Pri zásuvkách to KLAMALO
  // (zásuvka nemá krídlo) a obe pravidlá potom vyzerali ako duplicita, ktorú
  // niekto zabudol zmazať. Hint je preto per rola; podnadpis pravidla
  // (`rdRoleDesc`) ich rozlišoval už predtým.
  function rdHandleHint(role){
    var what = (role === 'drawer_front')
      ? '1 kus na čelo, dĺžka rezu = šírka čela'
      : '1 kus na krídlo, dĺžka rezu = šírka krídla';
    return 'Platí len pre čelá so zapnutým úchytkovým profilom — ' + what +
      '. Vypnutím vyššie sa profil prestane počítať.';
  }

  // D-118b: pravidlo `vysuvy-nl-podla-hlbky` beží od KOV-C2b UŽ LEN na
  // zásuvkových čelách BEZ systému zásuvky (staré zákazky) — čelo so systémom
  // Atira/Quadro dostane kód z receptu a toto pravidlo sa naň nevzťahuje.
  // Nemažeme ho (starým zákazkám by ticho vypadli výsuvy z nákupu), ale
  // v zozname sa musí priznať, čím je. `rdLabel` sa NEMENÍ — je to spoločný
  // slovník typov kovania so serverom (guard test) a tu ide o titulok RIADKU.
  var RD_LEGACY_SLIDE_ID = 'vysuvy-nl-podla-hlbky';
  var RD_LEGACY_SLIDE_HINT = 'Použije sa len na zásuvkové čelo bez systému zásuvky '
    + '(staré zákazky); čelo so systémom Atira alebo Quadro dostane kód z receptu.';
  function rdIsLegacySlide(r){
    return !!r && String(r.rule_id || '') === RD_LEGACY_SLIDE_ID;
  }
  // KOV-E2: SÚHRN výklopového pravidla do ZBALENEJ lišty editora — „HK 4 triedy ·
  // HL 2 mechanizmy + 4 ramená · tyč od 1100 mm · rezerva 0,5 kg". Zbalený blok
  // musí povedať, čo skrýva (UI_DIZAJN §1). Číta LEN to, čo naozaj existuje —
  // pravidlo z poškodeného snapshotu alebo z novšej verzie nesmie zhodiť render
  // celej sekcie (Codex #330 lekcia). ČISTÁ funkcia (Node test).
  // Slovenske tvary poctu — „1 trieda · 2 triedy · 5 tried · 0 tried".
  // NULA ide do genitivu (`many`), nie do „2-4" tvaru.
  function rdCount(n, one, few, many){
    return n + ' ' + (n === 1 ? one : (n >= 2 && n <= 4 ? few : many));
  }
  function rdLiftSummary(r){
    var cls = rdArr(r && r.classes).length;
    var mech = rdArr(r && r.mechanisms).length;
    var arms = rdArr(r && r.arms).length;
    var kg = (r && typeof r.handle_allowance_kg === 'number') ? r.handle_allowance_kg : null;
    var rod = (r && typeof r.rod_double_from_kb_mm === 'number') ? r.rod_double_from_kb_mm : null;
    var parts = ['HK ' + rdCount(cls, 'trieda', 'triedy', 'tried'),
                 'HL ' + mech + ' + ' + rdCount(arms, 'rameno', 'ramená', 'ramien')];
    if (rod !== null) parts.push('tyč od ' + rod + ' mm');
    if (kg !== null) parts.push('rezerva ' + kg + ' kg');
    return parts.join(' · ');
  }
  if (typeof window !== 'undefined') window.rdLiftSummary = rdLiftSummary;

  // ============ KOV-E2: EDITOR PRAVIDLA VÝKLOPOV (`lift_class`) =============
  //
  // E1b vedela pravidlo len PREČÍTAŤ (jedna veta). E2 z neho robí formulár —
  // rovnakým vzorom ako F2 „Kontroly dvierok": celý editor je ZBALENÝ
  // `<details>`, jeho stav si pamätá `RD_LIFT_OPEN` (kľúč = `rule_id`, nie
  // index — pravidlá sa môžu preskupiť) a v lište stojí SÚHRN.
  //
  // Mená kľúčov sú ZRKADLOM servera (`HardwareRules::LIFT_SCALARS`,
  // `normalize_lift_*`, `ELIGIBILITY_KEYS`) — klient si ich neopisuje vlastným
  // slovníkom a guard test zhodu stráži.
  var RD_LIFT_KEYS = ['handle_allowance_kg', 'rod_double_from_kb_mm',
                      'classes', 'mechanisms', 'arms', 'eligibility'];
  var RD_LIFT_ELIG = [['kh_min', 'výška od', 'mm'], ['kh_max', 'výška do', 'mm'],
                      ['kb_max', 'šírka do', 'mm'], ['depth_min', 'hĺbka od', 'mm']];
  var RD_LIFT_OPEN = {};

  function rdLiftKey(r, i){ return String((r && r.rule_id) || ('#' + i)); }

  // Číselné pole tabuľky. `cls` nesie údaj, ktorý sa z riadku číta späť.
  function rdLiftNumInput(cls, v, title){
    return '<input class="' + cls + ' rnum" type="number" step="0.1" value="' +
      rdEsc(rdNumAttr(v)) + '"' + (title ? ' title="' + rdEsc(title) + '"' : '') + '>';
  }
  function rdLiftCodeInput(v){
    return '<input class="lfcode" type="text" value="' + rdEsc(v == null ? '' : v) +
      '" placeholder="kód">';
  }
  // BEZSTRATOVÝ prenos `max_exclusive` (Blum: 300–339 a 340–389 sú SPOJITÉ, teda
  // horná hranica do pásma NEPATRÍ). Nie je to pole formulára — je to vlastnosť
  // pásma, ktorú by zber inak zahodil a dve pásma by sa začali prekrývať.
  // Nesie ju `data-mx` na riadku a hovorí o nej tooltip hornej hranice.
  function rdLiftMxAttr(row){
    return (row && row.max_exclusive === true) ? ' data-mx="1"' : '';
  }
  function rdLiftMxTitle(row){
    return (row && row.max_exclusive === true)
      ? 'Horná hranica do pásma NEPATRÍ (spojité pásmo — hodnota už patrí ďalšiemu).'
      : 'Horná hranica do pásma patrí.';
  }
  function rdLiftDel(action, title){
    return '<button class="ghostbtn bdel" title="' + rdEsc(title) + '" onclick="' + action +
      '(this)">✕</button>';
  }

  // HTML editora. ČISTÁ funkcia (Node test) — stav otvorenia chodí z modulu.
  function rdLiftHtml(r, i){
    var open = RD_LIFT_OPEN[rdLiftKey(r, i)] === true;
    var h = '<details class="rlift" data-rid="' + rdEsc(rdLiftKey(r, i)) + '"' + (open ? ' open' : '') +
      ' ontoggle="rdLiftToggle(this)">' +
      '<summary>Výklopy AVENTOS <span class="rgsum">' + rdEsc(rdLiftSummary(r)) + '</span></summary>' +
      '<div class="rgbody">' +
      '<div class="rrow"><label>Rezerva na úchytku</label>' +
      rdLiftNumInput('lallow', r && r.handle_allowance_kg,
                     'Pripočíta sa k hmotnosti čela pri OBOCH systémoch (Blum ráta s úchytkou).') +
      '<span class="unit">kg</span></div>' +
      '<div class="rrow"><label>Druhá tyč od šírky</label>' +
      rdLiftNumInput('lrod', r && r.rod_double_from_kb_mm,
                     'Od tejto šírky korpusu ide 2× stabilizačná tyč + predlžovací diel. Prázdne = vždy jedna.') +
      '<span class="unit">mm</span></div>';
    // --- HK top: triedy podla LF -------------------------------------------
    h += '<div class="lfgrp"><div class="lfgrph">HK top — triedy podľa LF</div>';
    rdArr(r && r.classes).forEach(function(c, ci){
      h += '<div class="rrow lfrow lcls" data-ci="' + ci + '">' + rdLiftCodeInput(c && c.code) +
        '<label>LF</label>' + rdLiftNumInput('lmin', c && c.min, 'LF od (vrátane)') +
        '<span class="arrow">–</span>' + rdLiftNumInput('lmax', c && c.max, 'LF do (vrátane)') +
        rdLiftDel('rdDelLiftClass', 'Odstrániť triedu') + '</div>';
    });
    h += '<div class="btnrow"><button class="ghostbtn" onclick="rdAddLiftClass(this)">' +
      '+ trieda</button></div></div>';
    // --- HL top: mechanizmy podla KH ---------------------------------------
    h += '<div class="lfgrp"><div class="lfgrph">HL top — mechanizmy podľa výšky korpusu</div>';
    rdArr(r && r.mechanisms).forEach(function(m, mi){
      h += '<div class="rrow lfrow lmech" data-mi="' + mi + '"' + rdLiftMxAttr(m) + '>' +
        rdLiftCodeInput(m && m.code) + '<label>výška do</label>' +
        rdLiftNumInput('lmmax', m && m.max, rdLiftMxTitle(m)) + '<span class="unit">mm</span>' +
        rdLiftDel('rdDelLiftMech', 'Odstrániť mechanizmus') + '</div>';
    });
    h += '<div class="btnrow"><button class="ghostbtn" onclick="rdAddLiftMech(this)">' +
      '+ mechanizmus</button></div></div>';
    // --- HL top: ramena ----------------------------------------------------
    h += '<div class="lfgrp"><div class="lfgrph">HL top — ramená podľa výšky a hmotnosti</div>';
    rdArr(r && r.arms).forEach(function(a, ai){
      h += '<div class="rrow lfrow larm" data-ai="' + ai + '"' + rdLiftMxAttr(a) + '>' +
        rdLiftCodeInput(a && a.code) + '<label>výška</label>' +
        rdLiftNumInput('lkhmin', a && a.kh_min, 'Výška korpusu od (vrátane)') +
        '<span class="arrow">–</span>' +
        rdLiftNumInput('lkhmax', a && a.kh_max, rdLiftMxTitle(a)) + '<span class="unit">mm</span>' +
        '<label>hmotnosť</label>' + rdLiftNumInput('lkgmin', a && a.kg_min, 'Hmotnosť od (vrátane)') +
        '<span class="arrow">–</span>' +
        rdLiftNumInput('lkgmax', a && a.kg_max, 'Hmotnosť do (vrátane)') + '<span class="unit">kg</span>' +
        rdLiftDel('rdDelLiftArm', 'Odstrániť ramená') + '</div>';
    });
    h += '<div class="btnrow"><button class="ghostbtn" onclick="rdAddLiftArm(this)">' +
      '+ ramená</button></div></div>';
    // --- sposobilost per system --------------------------------------------
    var el = (r && r.eligibility && typeof r.eligibility === 'object') ? r.eligibility : {};
    h += '<div class="lfgrp"><div class="lfgrph">Kedy sa systém dá použiť</div>';
    RD_LIFT_SYSTEMS.forEach(function(sys){
      var rec = (el[sys[0]] && typeof el[sys[0]] === 'object') ? el[sys[0]] : {};
      h += '<div class="rrow lfrow lelig" data-sys="' + rdEsc(sys[0]) + '"><label>' +
        rdEsc(sys[1]) + '</label>';
      RD_LIFT_ELIG.forEach(function(f){
        h += '<span class="lfsub">' + rdEsc(f[1]) + '</span>' +
          rdLiftNumInput('le_' + f[0], rec[f[0]], null) + '<span class="unit">' + f[2] + '</span>';
      });
      h += '</div>';
    });
    h += '</div>';
    return h + '<div class="hint">Prázdne pole = kritérium sa nepoužije. Pásma sa nemusia písať ' +
      'v poradí — server ich zoradí sám. Po uložení skrinky NEPRESTAVÍ automaticky: ' +
      'prestav ich (zmeň a vráť rozmer alebo klikni Prestavať).</div></div></details>';
  }

  // Zbalenie bloku = formulár zmizne z očí a hovoriť zaň začne SÚHRN v lište.
  // Hodnoty žijú LEN v DOM, preto sa najprv preberú TÝM ISTÝM zberom ako pri
  // ukladaní (vzor `rdGuardRefresh` z F2). PREKRESLIŤ sa NESMIE — `rdRender` by
  // zahodil `<details>`, nad ktorým práve beží udalosť.
  function rdLiftRefresh(det){
    var host = det.closest ? det.closest('.rrule') : null;
    var sum = det.querySelector ? det.querySelector('.rgsum') : null;
    if (!host || !sum) return;
    var i = parseInt(host.dataset ? host.dataset.i : '', 10);
    rdSyncFromForm();
    var r = RD_RULES[i];
    if (r) sum.textContent = rdLiftSummary(r);
  }
  function rdLiftToggle(det){
    if (!det) return;
    var open = (typeof det.open === 'boolean')
      ? det.open
      : !!(det.hasAttribute && det.hasAttribute('open'));
    RD_LIFT_OPEN[String(det.dataset ? (det.dataset.rid || '') : '')] = open;
    if (!open) rdLiftRefresh(det);
  }
  if (typeof window !== 'undefined') window.rdLiftToggle = rdLiftToggle;

  function rdRuleTitle(r){
    var base = rdLabel(r && r.output);
    return rdIsLegacySlide(r) ? (base + ' — staré zákazky bez systému zásuvky') : base;
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
    // KOV-E1b: rola `flap` je SPOLOČNÁ pre výklop aj sklop — rozlišuje ich až
    // filter smeru, takže bez neho by dve pravidlá vyzerali rovnako.
    if (role === 'flap'){
      if (ap.flap_dir === 'up') return 'na každý výklop';
      if (ap.flap_dir === 'down') return 'na každý sklop';
      return 'na každý výklop aj sklop';
    }
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
      //
      // ŠT-3b-2c2: a z TOHO ISTEHO dovodu sa NEPREPISUJE ani `RD_META.rules_rev`.
      // Globalne predvolby NIE SU stav projektu — keby si klient prevzal ich
      // odtlacok, ulozenie po „Načítať globálne" by serveru tvrdilo, ze formular
      // vznikol z aktualnych pravidiel projektu, a prepisalo by cudziu zmenu,
      // ktora medzitym prisla. Rev ostava ten, s ktorym bol formular NAPLNENY.
      RD_NEEDS_RENDER = true;
      rdRender();
    },
    setStatus: function(msg, err){
      var e = rdEl('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    },
    // ŠT-3b-2b (review #222 P1): LACNE ECHO sekcie. Odmietnutý zápis nič
    // nezmenil, takže si nepýta plný prepočet okna — ten totiž beží cez zber
    // modelu, a ten deduplikuje ID kópií, čiže by odmietnutý klik ZAPÍSAL do
    // modelu (a pridal krok Späť) presne v scenári, kde hláška tvrdí opak.
    // Kanál je ten istý payload sekcie, len bez zdvihu generácie okna.
    // `force` = server hovorí, že rozpísané hodnoty UŽ NEPLATIA (pravidlá na
    // modeli sa medzitým zmenili) — formulár sa MUSÍ prekresliť a odtlačok
    // omladiť, inak by najbližšie „Uložiť" zapísalo hodnoty nad cudziu zmenu,
    // ktorú používateľ nikdy nevidel. Bez `force` platí bežný kontrakt:
    // rozpísaný formulár push prežije.
    setSection: function(r, force){
      // Prázdny payload (server zlyhal pri zostavovaní) NESMIE vyprázdniť
      // sekciu — vetva `force` by inak formulár prekreslila z ničoho.
      if (!r) return;
      if (force){
        rdSetState(r);
        RD_NEEDS_RENDER = true;
        rdRender();
        rdRenderExtra();
        return;
      }
      rdApplyState(r);
    }
  };
  if (typeof window !== 'undefined') window.RD = RD;

  function rdSetState(data){
    var d = data || {};
    RD_RULES = d.rules || [];
    RD_SEED = JSON.stringify(RD_RULES);
    RD_META = { version: d.version || '', source: d.source || '',
                cabinets: d.cabinets || 0, model_guid: d.model_guid || '',
                rules_rev: d.rules_rev || '' };
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
    // Klik, ktorý sa nemá kam poslať, NESMIE mlčať (review #222 NOTE): riadok
    // by ostal jantárový a používateľ by veril, že sa niečo stalo. Rozlišujú
    // sa DVE veci — neznámy druh riadku (chyba dát) a nedostupný kanál okna.
    if (!name){
      RD.setStatus('Tento riadok sa vrátiť na pravidlo nedá — obnov sekciu a skús znova.', true);
      return;
    }
    if (!st || typeof window === 'undefined' || !window.sketchup || !sketchup[name]){
      RD.setStatus('Okno stratilo spojenie so SketchUpom — zavri a otvor Štúdio znova.', true);
      return;
    }
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

  // ============== KOV-F2: EDITOR DOOR GUARDOV PRAVIDLA `bands` ===============
  //
  // F1 pridala pravidlu `bands` VOLITEĽNÉ kľúče (`width_plus`,
  // `width_warn_over`, `weight_bands`, `finite`) a sekcia ich vedela len
  // PREČÍTAŤ jednou vetou. F2 z nej robí formulár — veta zanikla, aby ten istý
  // údaj nebol na obrazovke dvakrát; jej rolu prevzal SÚHRN v zbalenej lište
  // (`rdGuardSummary`), takže blok povie, čo skrýva, aj keď je zavretý.
  //
  // VERTIKÁLNY PRIESTOR: celý editor je `<details>` a je ZBALENÝ — otvorený
  // stav si pamätá `RD_GUARD_OPEN` (kľúč = `rule_id`), inak by ho každé
  // pridanie hmotnostného pásma (prekreslenie formulára) zavrelo.
  //
  // Mená kľúčov sú ZRKADLOM serverovej `HardwareRules::DOOR_GUARD_KEYS`
  // (guard test na zhodu) — klient si ich neopisuje vlastným slovníkom.
  var RD_GUARD_KEYS = ['finite', 'width_plus', 'width_warn_over', 'weight_bands'];
  var RD_GUARD_OPEN = {};

  function rdGuardKey(r, i){ return String((r && r.rule_id) || ('#' + i)); }

  // Editor sa kreslí pri pravidle závesov (`bands` + výstup `hinge`) a pri
  // KAŽDOM pravidle `bands`, ktoré už niektorý guard nesie — inak by sa
  // hodnota z cudzieho/novšieho snapshotu nedala ani vidieť, ani opraviť.
  function rdHasGuardEditor(r){
    if (!r || r.kind !== 'bands') return false;
    if (r.output === 'hinge') return true;
    return RD_GUARD_KEYS.some(function(k){
      return Object.prototype.hasOwnProperty.call(r, k);
    });
  }

  // Slovenské tvary počtu — „1 pásmo · 2 pásma · 5 pásiem".
  function rdWeightCount(n){
    if (n === 1) return '1 hmotnostné pásmo';
    return n < 5 ? (n + ' hmotnostné pásma') : (n + ' hmotnostných pásiem');
  }

  // Kľúč `weight_bands`, ktorý NIE JE pole (hash/reťazec z cudzieho alebo
  // pokazeného snapshotu). Editor taký stav ukáže ako PRÁZDNU tabuľku a prizná
  // sa k nemu — uložením sa pokazený kľúč z pravidla odstráni (zber píše len
  // to, čo je vo formulári). ČISTÁ funkcia (Node test).
  function rdWeightBroken(r){
    return !!r && Object.prototype.hasOwnProperty.call(r, 'weight_bands') &&
           !Array.isArray(r.weight_bands);
  }

  // SÚHRN do zbalenej lišty. ČISTÁ funkcia (Node test).
  function rdGuardSummary(r){
    var out = [];
    var wp = r && r.width_plus;
    if (wp && wp.over != null && wp.add != null) out.push('+' + wp.add + ' nad ' + wp.over + ' mm');
    if (r && r.width_warn_over != null) out.push('varovanie nad ' + r.width_warn_over + ' mm');
    // Pozor na `.length` nad NE-poľom: reťazec ho má tiež a lišta by hlásila
    // „3 hmotnostné pásma" nad tvarom, ktorý žiadne pásmo nemá.
    var wb = rdArr(r && r.weight_bands);
    if (rdWeightBroken(r)) out.push('hmotnostné pásma: neplatný tvar');
    else if (wb.length) out.push(rdWeightCount(wb.length));
    if (r && r.finite === true) out.push('konečná tabuľka');
    return out.length ? out.join(' · ') : 'zatiaľ nič';
  }

  // Hodnota do `value=""`: chýbajúci guard = PRÁZDNE pole (a prázdne pole je
  // zároveň jediný spôsob, ako guard vypnúť — vzor „prázdne pole je AUTO").
  function rdNumAttr(v){
    return (typeof v === 'number' && isFinite(v)) ? String(v) : '';
  }

  // HTML editora. ČISTÁ funkcia (Node test) — stav otvorenia chodí z modulu.
  function rdGuardHtml(r, i){
    var wp = (r && r.width_plus && typeof r.width_plus === 'object') ? r.width_plus : {};
    var open = RD_GUARD_OPEN[rdGuardKey(r, i)] === true;
    var h = '<details class="rgrd" data-rid="' + rdEsc(rdGuardKey(r, i)) + '"' + (open ? ' open' : '') +
      ' ontoggle="rdGuardToggle(this)">' +
      '<summary>Kontroly dvierok <span class="rgsum">' + rdEsc(rdGuardSummary(r)) + '</span></summary>' +
      '<div class="rgbody">' +
      '<div class="rrow"><label>Šírka nad</label>' +
      '<input class="rgover rnum" type="number" min="1" step="1" value="' + rdEsc(rdNumAttr(wp.over)) + '">' +
      '<span class="unit">mm</span><span class="arrow">→</span><span class="rgplus">+</span>' +
      '<input class="rgadd rnum" type="number" min="1" max="999" step="1" value="' + rdEsc(rdNumAttr(wp.add)) + '">' +
      '<span class="unit">ks</span></div>' +
      '<div class="rrow"><label>Varovanie nad</label>' +
      '<input class="rgwarn rnum" type="number" min="1" step="1" value="' +
      rdEsc(rdNumAttr(r && r.width_warn_over)) + '"><span class="unit">mm</span></div>' +
      '<div class="rgwbox">';
    rdArr(r && r.weight_bands).forEach(function(b, wi){
      h += '<div class="rrow rgwb" data-wi="' + wi + '"><label>Hmotnosť do</label>' +
        '<input class="wmax rnum" type="number" min="0.1" step="0.1" value="' + rdEsc(rdNumAttr(b && b.max)) +
        '"><span class="unit">kg</span><span class="arrow">→</span>' +
        '<input class="wqty rnum" type="number" min="1" max="999" step="1" value="' +
        rdEsc(rdNumAttr(b && b.quantity)) + '"><span class="unit">ks</span>' +
        '<button class="ghostbtn bdel" title="Odstrániť hmotnostné pásmo" onclick="rdDelWeight(this)">✕</button></div>';
    });
    return h + '</div><div class="btnrow"><button class="ghostbtn" onclick="rdAddWeight(this)">' +
      '+ hmotnostné pásmo</button></div>' +
      '<label class="rgchk"><input type="checkbox" class="rgfin"' + (r && r.finite === true ? ' checked' : '') +
      '> tabuľka výšok je konečná — nad ňou hlási Kontrola chybu</label>' +
      // Pokazený tvar sa NESKRÝVA a NEOPRAVUJE potichu: povie sa, čo je zle,
      // a formulár ostáva editovateľný — Uložiť taký kľúč z pravidla odstráni.
      (rdWeightBroken(r)
        ? '<div class="hint rgbad">Hmotnostné pásma sú v uložených dátach v nesprávnom tvare, ' +
          'preto je tabuľka prázdna. Uložením sa pokazený údaj z pravidla odstráni; ' +
          'pásma potom môžeš zadať nanovo.</div>'
        : '') +
      '<div class="hint">Platí pre dvierka. Hmotnostné pásma iba upozorňujú — počet závesov riadi tabuľka ' +
      'výšok. Prázdne pole = kontrola je vypnutá.</div></div></details>';
  }

  // Codex #330 kolo 1 (P2): ZBALENIE bloku je okamih, keď formulár zmizne
  // z očí a hovoriť zaň začne SÚHRN v lište. Hodnoty polí ale žijú LEN v DOM
  // (do `RD_RULES` sa preberajú až pri „+ pásmo" / „✕" / Uložiť), takže bez
  // tohto kroku by lišta ukazovala stav SPRED úpravy — a používateľ by veril,
  // že sa jeho zmena stratila (alebo naopak, že tam ešte je).
  //
  // Preberá sa TÝM ISTÝM zberom ako pri ukladaní (`rdSyncFromForm`), aby
  // súhrn a uložené dáta nemohli povedať dve rôzne veci. PREKRESLIŤ sa
  // NESMIE: `rdRender` by zahodil `<details>`, nad ktorým práve beží udalosť
  // (a s ním zameranie) — mení sa preto len text lišty.
  function rdGuardRefresh(det){
    var host = det.closest ? det.closest('.rrule') : null;
    var sum = det.querySelector ? det.querySelector('.rgsum') : null;
    if (!host || !sum) return;
    var i = parseInt(host.dataset ? host.dataset.i : '', 10);
    rdSyncFromForm();
    var r = RD_RULES[i];
    if (r) sum.textContent = rdGuardSummary(r);
  }

  // Zapamätanie otvoreného bloku. Kľúčom je `rule_id` (nie index) — pravidlá
  // sa môžu preskupiť a index by po prekreslení ukazoval na cudzí blok.
  function rdGuardToggle(det){
    if (!det) return;
    var open = (typeof det.open === 'boolean')
      ? det.open
      : !!(det.hasAttribute && det.hasAttribute('open'));
    RD_GUARD_OPEN[String(det.dataset ? (det.dataset.rid || '') : '')] = open;
    if (!open) rdGuardRefresh(det);
  }
  if (typeof window !== 'undefined') window.rdGuardToggle = rdGuardToggle;

  function rdRender(){
    var line = rdEl('rdSrcLine');
    if (line) line.textContent = rdSrcLine();
    var box = rdEl('rulesBox');
    if (!box) return;
    var html = '';
    RD_RULES.forEach(function(r, i){
      html += '<div class="rrule" data-i="'+i+'">';
      html += '<div class="rhead"><label><input type="checkbox" class="ren" '+(r.enabled!==false?'checked':'')+'> '
            + '<b>'+rdEsc(rdRuleTitle(r))+'</b></label> <span class="rid">'+rdEsc(rdRoleDesc(r))+'</span></div>';
      if (r.kind === 'fixed'){
        html += '<div class="rrow"><label>Počet</label><input class="rqty rnum" type="number" min="1" max="999" step="1" value="'+rdEsc(r.quantity!=null?r.quantity:1)+'"><span class="unit">ks</span></div>';
      } else if (r.kind === 'bands'){
        html += '<div class="rbands">';
        rdArr(r.bands).forEach(function(b, bi){
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
        // KOV-F2: voliteľné kontroly dvierok (+1 nad šírku, varovanie šírky,
        // hmotnostné pásma, konečná tabuľka) sú od F2 EDITOR — zbalený blok
        // so súhrnom. Pravidlo `bands`, ktoré sa ich netýka (iný výstup a
        // žiadny guard), vyzerá presne ako doteraz.
        if (rdHasGuardEditor(r)) html += rdGuardHtml(r, i);
      } else if (r.kind === 'fit_series'){
        html += '<div class="rrow"><label>Rad dĺžok</label><input class="rseries" type="text" value="'+rdEsc(rdArr(r.series).join(', '))+'"><span class="unit">mm</span></div>';
        html += '<div class="rrow"><label>Rezerva</label><input class="rclr rnum" type="number" min="0" step="1" value="'+rdEsc(r.clearance!=null?r.clearance:10)+'"><span class="unit">mm</span></div>';
        html += '<div class="rrow"><label>Počet</label><input class="rqty rnum" type="number" min="1" max="999" step="1" value="'+rdEsc(r.quantity!=null?r.quantity:1)+'"><span class="unit">sád</span></div>';
        html += '<div class="hint">Vyberie sa najväčšia dĺžka z radu, ktorá sa zmestí do svetlej hĺbky mínus rezerva.'
              + (rdIsLegacySlide(r) ? ' ' + rdEsc(RD_LEGACY_SLIDE_HINT) : '') + '</div>';
      } else if (r.kind === 'lift_class'){
        // KOV-E2: výklopy majú EDITOR (skaláre, tri tabuľky, spôsobilosť) —
        // zbalený blok so súhrnom v lište, presne ako door guardy z F2.
        html += rdLiftHtml(r, i);
      } else if (r.kind === 'part_flag_length'){
        // D-90: pravidlo bez nastavení — reaguje na príznak profilu na čele.
        // TEST-1: text sa líši podľa roly (dvierka vs. zásuvkové čelo).
        html += '<div class="hint">' + rdEsc(rdHandleHint((r.applies_to || {}).role)) + '</div>';
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
  // KOV-F2: pridanie/odobranie HMOTNOSTNÉHO pásma. Rovnaký postup ako pri
  // výškových pásmach — najprv `rdSyncFromForm` (inak by prekreslenie zahodilo
  // rozpísané hodnoty ostatných pravidiel), potom zmena a render.
  function rdAddWeight(btn){
    var i = parseInt(rdRuleNode(btn).dataset.i, 10);
    rdSyncFromForm();
    var r = RD_RULES[i];
    var wb = Array.isArray(r.weight_bands) ? r.weight_bands : [];
    // Nové pásmo nadväzuje na NAJŤAŽŠIE existujúce (server pásma aj tak zoradí):
    // +5 kg a o jeden záves viac — presne rytmus tabuľky výrobcu.
    var last = null;
    wb.forEach(function(b){
      if (b && typeof b.max === 'number' && (last === null || b.max > last.max)) last = b;
    });
    wb.push({ max: last ? (last.max + 5) : 10,
              quantity: last ? Math.min((parseInt(last.quantity, 10) || 1) + 1, 999) : 2 });
    r.weight_bands = wb;
    rdRender();
  }
  function rdDelWeight(btn){
    var i = parseInt(rdRuleNode(btn).dataset.i, 10);
    var wi = parseInt(btn.closest('.rgwb').dataset.wi, 10);
    rdSyncFromForm();
    var wb = RD_RULES[i].weight_bands || [];
    wb.splice(wi, 1);
    // Posledné zmazané pásmo = kontrola je VYPNUTÁ, teda kľúč v pravidle
    // nemá čo hľadať (vzor „prázdne pole = guard preč“).
    if (wb.length) RD_RULES[i].weight_bands = wb; else delete RD_RULES[i].weight_bands;
    rdRender();
  }
  if (typeof window !== 'undefined'){
    window.rdAddWeight = rdAddWeight;
    window.rdDelWeight = rdDelWeight;
  }

  // Zber door guardov z formulára do KÓPIE pravidla. Kľúč, ktorý používateľ
  // nevyplnil, sa NEZAPÍŠE — pravidlo bez guardov teda ostáva bez guardov aj
  // po uložení (a to je zároveň jediný spôsob, ako guard vypnúť).
  //
  // Klient hodnoty NEHÁDŽE serveru „ako sú": prázdna alebo nekladná hranica =
  // kontrola vypnutá (rovnaký výsledok, aký by dala serverová
  // `normalize_width_plus!`), chýbajúci počet = 1 (rovnaký clamp ako pri
  // výškových pásmach). Vďaka tomu neexistuje tvar, ktorý by klient poslal
  // a server ticho zahodil.
  //
  // VÝNIMKA sú HMOTNOSTNÉ pásma: riadok, ktorý používateľ vedome pridal, sa
  // nezahadzuje — prázdne kilogramy idú na server ako `null` a uloženie sa
  // ODMIETNE vetou (server rovnako, viď `HardwareRules.weight_bands_problem`).
  function rdCollectGuards(ruleEl, r){
    var box = ruleEl.querySelector('.rgrd');
    if (!box) return; // blok sa nekreslí -> kľúčov pravidla sa nedotýkame
    var over = parseFloat((box.querySelector('.rgover') || {}).value);
    var add = parseInt((box.querySelector('.rgadd') || {}).value, 10);
    if (!isNaN(over) && over > 0) r.width_plus = { over: over, add: (isNaN(add) || add < 1) ? 1 : add };
    else delete r.width_plus;
    var warn = parseFloat((box.querySelector('.rgwarn') || {}).value);
    if (!isNaN(warn) && warn > 0) r.width_warn_over = warn; else delete r.width_warn_over;
    var rows = box.querySelectorAll('.rgwb');
    if (rows.length){
      var wb = [];
      rows.forEach(function(row){
        var m = parseFloat(row.querySelector('.wmax').value);
        var q = parseInt(row.querySelector('.wqty').value, 10);
        wb.push({ max: isNaN(m) ? null : m, quantity: (isNaN(q) || q < 1) ? 1 : q });
      });
      r.weight_bands = wb;
    } else {
      delete r.weight_bands;
    }
    var fin = box.querySelector('.rgfin');
    if (fin && fin.checked) r.finite = true; else delete r.finite;
  }

  // ============ KOV-E2: PRIDANIE/ODOBRANIE riadku výklopového pravidla =======
  //
  // Rovnaký postup ako pri pásmach závesov: najprv `rdSyncFromForm` (inak by
  // prekreslenie zahodilo rozpísané hodnoty ostatných pravidiel), potom zmena
  // a render. Nový riadok je PRÁZDNY — server aj klient ho zahodia, kým ho
  // používateľ nevyplní (`rdLiftRows` / `HardwareRules.lift_row?`), takže
  // „+ trieda" nikdy nevyrobí pásmo, ktoré by niečo pokrývalo omylom.
  function rdLiftList(btn, key){
    var i = parseInt(rdRuleNode(btn).dataset.i, 10);
    rdSyncFromForm();
    var r = RD_RULES[i];
    if (!Array.isArray(r[key])) r[key] = [];
    return r[key];
  }
  function rdLiftDrop(btn, key, sel, attr){
    var i = parseInt(rdRuleNode(btn).dataset.i, 10);
    var row = btn.closest(sel);
    var at = row ? parseInt(row.dataset[attr], 10) : -1;
    rdSyncFromForm();
    var list = RD_RULES[i][key];
    if (Array.isArray(list) && at >= 0) list.splice(at, 1);
    rdRender();
  }
  function rdAddLiftClass(btn){ rdLiftList(btn, 'classes').push({ code: '', min: null, max: null }); rdRender(); }
  function rdDelLiftClass(btn){ rdLiftDrop(btn, 'classes', '.lcls', 'ci'); }
  function rdAddLiftMech(btn){ rdLiftList(btn, 'mechanisms').push({ code: '', max: null }); rdRender(); }
  function rdDelLiftMech(btn){ rdLiftDrop(btn, 'mechanisms', '.lmech', 'mi'); }
  function rdAddLiftArm(btn){
    rdLiftList(btn, 'arms').push({ code: '', kh_min: null, kh_max: null,
                                   kg_min: null, kg_max: null });
    rdRender();
  }
  function rdDelLiftArm(btn){ rdLiftDrop(btn, 'arms', '.larm', 'ai'); }
  if (typeof window !== 'undefined'){
    window.rdAddLiftClass = rdAddLiftClass; window.rdDelLiftClass = rdDelLiftClass;
    window.rdAddLiftMech = rdAddLiftMech;   window.rdDelLiftMech = rdDelLiftMech;
    window.rdAddLiftArm = rdAddLiftArm;     window.rdDelLiftArm = rdDelLiftArm;
  }

  // Hodnota číselného poľa editora výklopu: prázdne pole = `null` (server ho
  // v tabuľke ZAHODÍ ako neúplný riadok, v skalári ho odstráni ako vypnuté
  // kritérium). NIKDY sa nehádže nula — „rezerva 0 kg" a „rezerva nie je" sú
  // dve rôzne veci a obe sú legitímne.
  function rdLiftVal(box, cls){
    var el = box.querySelector('.' + cls);
    if (!el) return null;
    var v = parseFloat(el.value);
    return isNaN(v) ? null : v;
  }
  function rdLiftText(box, cls){
    var el = box.querySelector('.' + cls);
    return el ? String(el.value == null ? '' : el.value).trim() : '';
  }
  // Zber editora výklopu do KÓPIE pravidla. Kľúč, ktorý používateľ vyprázdnil,
  // sa NEZAPÍŠE (vzor „prázdne pole = kritérium vypnuté" z F2); tabuľky idú
  // celé, aj s nedopísanými riadkami — obe strany ich zahadzujú ROVNAKO
  // (`rdLiftRows` / `lift_row?`), takže tvar „klient pošle, server ticho zahodí"
  // tu nevzniká.
  function rdCollectLift(ruleEl, r){
    var box = ruleEl.querySelector('.rlift');
    if (!box) return; // blok sa nekreslí -> kľúčov pravidla sa nedotýkame
    var allow = rdLiftVal(box, 'lallow');
    if (allow === null) delete r.handle_allowance_kg; else r.handle_allowance_kg = allow;
    var rod = rdLiftVal(box, 'lrod');
    if (rod === null) delete r.rod_double_from_kb_mm; else r.rod_double_from_kb_mm = rod;
    var classes = [];
    box.querySelectorAll('.lcls').forEach(function(row){
      classes.push({ code: rdLiftText(row, 'lfcode'), min: rdLiftVal(row, 'lmin'),
                     max: rdLiftVal(row, 'lmax') });
    });
    r.classes = classes;
    var mechs = [];
    box.querySelectorAll('.lmech').forEach(function(row){
      var m = { code: rdLiftText(row, 'lfcode'), max: rdLiftVal(row, 'lmmax') };
      // BEZSTRATOVO: `max_exclusive` nie je pole formulára, ale vlastnosť pásma.
      if (row.dataset && row.dataset.mx === '1') m.max_exclusive = true;
      mechs.push(m);
    });
    r.mechanisms = mechs;
    var arms = [];
    box.querySelectorAll('.larm').forEach(function(row){
      var a = { code: rdLiftText(row, 'lfcode'), kh_min: rdLiftVal(row, 'lkhmin'),
                kh_max: rdLiftVal(row, 'lkhmax'), kg_min: rdLiftVal(row, 'lkgmin'),
                kg_max: rdLiftVal(row, 'lkgmax') };
      if (row.dataset && row.dataset.mx === '1') a.max_exclusive = true;
      arms.push(a);
    });
    r.arms = arms;
    var elig = {};
    box.querySelectorAll('.lelig').forEach(function(row){
      var sys = row.dataset ? row.dataset.sys : '';
      if (!sys) return;
      var rec = {}, any = false;
      RD_LIFT_ELIG.forEach(function(f){
        var v = rdLiftVal(row, 'le_' + f[0]);
        // Server drží LEN kladné hodnoty (`normalize_lift_eligibility`) —
        // klient posiela to isté, aby sa tvary nerozišli.
        if (v === null || !(v > 0)) return;
        rec[f[0]] = v; any = true;
      });
      if (any) elig[sys] = rec;
    });
    r.eligibility = elig;
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
      if (r.kind === 'bands'){
        r.bands = rdCollectBands(ruleEl);
        rdCollectGuards(ruleEl, r); // KOV-F2: voliteľné kontroly dvierok
      }
      if (r.kind === 'fit_series'){
        r.series = ruleEl.querySelector('.rseries').value.split(/[,;\s]+/)
          .map(function(s){ return parseFloat(s); })
          .filter(function(v){ return !isNaN(v) && v > 0; });
        var c = parseFloat(ruleEl.querySelector('.rclr').value);
        r.clearance = isNaN(c) ? 10 : Math.max(0, c);
      }
      if (r.kind === 'lift_class') rdCollectLift(ruleEl, r); // KOV-E2
      out.push(r);
    });
    return out;
  }

  // KOV-F2: ZRKADLO serverovej `HardwareRules.weight_bands_problem`. Tri
  // kritériá, a to PRESNE tie, ktoré serverová normalizácia nechá tak:
  // prázdna tabuľka · pásmo bez kilogramov · dve pásma s rovnakou hmotnosťou.
  //
  // Riadky, ktoré by normalizácia ZAHODILA (počet < 1), sa nepočítajú — inak
  // by klient odmietol tvar, ktorý server ticho opraví (a fixtúra parity by
  // padla). Poradie sa NEKONTROLUJE: pásma zoraďuje server podľa `max`.
  function rdWeightNum(v){
    if (v === null || v === undefined) return null;
    if (typeof v === 'number') return isFinite(v) ? v : null;
    var n = parseFloat(v);
    return isNaN(n) ? 0 : n; // Ruby `'x'.to_f` je 0.0 — teda tiež neplatné
  }
  function rdWeightQtyOk(v){
    if (v === null || v === undefined || String(v).trim() === '') return false;
    var n = parseInt(v, 10);
    return !isNaN(n) && n >= 1;
  }
  function rdWeightProblem(r){
    if (!Object.prototype.hasOwnProperty.call(r, 'weight_bands')) return null;
    var name = 'Pravidlo „' + rdLabel(r.output) + '“';
    var raw = Array.isArray(r.weight_bands) ? r.weight_bands : [];
    var rows = raw.filter(function(b){ return b && rdWeightQtyOk(b.quantity); });
    if (!rows.length) return name + ': hmotnostné pásma sú prázdne — vyplň kg aj počet, alebo tabuľku zmaž.';
    var maxes = [];
    for (var i = 0; i < rows.length; i++){
      var m = rdWeightNum(rows[i].max);
      if (m === null || !(m > 0)) return name + ': pásmo hmotnosti potrebuje kilogramy — číslo väčšie ako 0.';
      if (maxes.indexOf(m) >= 0) return name + ': dve hmotnostné pásma majú rovnakú hmotnosť — každé musí mať inú.';
      maxes.push(m);
    }
    return null;
  }

  // Klientska kontrola pred odoslanim — CISTA funkcia (Node test). Vracia
  // hlasku, alebo null ked je formular v poriadku. Server validuje znova;
  // toto je len to, co sa da povedat BEZ neho.
  // === KOV-E1b (Codex #333 kolo 1 P2): PARITA VALIDÁCIE VÝKLOPOV ===========
  //
  // Zrkadlo serverovej `HardwareRules.lift_problem`. Kritériá sú definované
  // nad tvarom PO normalizácii, preto sa riadky najprv PREFILTRUJÚ rovnako
  // ako v `HardwareRules.lift_row?` (riadok bez kódu alebo s nečíselným
  // rozsahom server ZAHODÍ, takže ho nesmieme počítať ani tu).
  // Spoločný kontrakt = `tests/fixtures/rules_validation_parity.json`.
  function rdLiftNum(v){ return (typeof v === 'number' && isFinite(v)) ? v : null; }
  // Zrkadlo serverovej mapy `HardwareRules::LIFT_SCALARS` — kľúč + ĽUDSKÝ
  // názov do hlášky. Poradie je to isté ako na serveri, takže pri dvoch
  // pokazených skalároch naraz obe strany menujú TEN ISTÝ.
  var RD_LIFT_SCALARS = [['handle_allowance_kg', 'rezerva na úchytku'],
                         ['rod_double_from_kb_mm', 'šírka pre druhú stabilizačnú tyč']];
  function rdLiftRows(raw, keys){
    return rdArr(raw).filter(function(row){
      if (!row || String(row.code == null ? '' : row.code).trim() === '') return false;
      return keys.every(function(k){ return rdLiftNum(row[k]) !== null; });
    });
  }
  function rdLiftProblem(r){
    var name = 'Pravidlo „' + rdLabel(r.output) + '“';
    var classes = rdLiftRows(r.classes, ['min', 'max']);
    var mechs   = rdLiftRows(r.mechanisms, ['max']);
    var arms    = rdLiftRows(r.arms, ['kh_min', 'kh_max', 'kg_min', 'kg_max']);
    if (!classes.length) return name + ': tabuľka tried HK top je prázdna — doplň aspoň jednu triedu.';
    if (!mechs.length) return name + ': tabuľka mechanizmov HL top je prázdna — doplň aspoň jeden.';
    if (!arms.length) return name + ': tabuľka ramien HL top je prázdna — doplň aspoň jedny.';
    for (var i = 0; i < classes.length; i++){
      if (classes[i].min > classes[i].max){
        return name + ': trieda ' + classes[i].code + ' má LF od väčšie než do.';
      }
    }
    for (var j = 0; j < arms.length; j++){
      if (arms[j].kh_min > arms[j].kh_max || arms[j].kg_min > arms[j].kg_max){
        return name + ': ramená ' + arms[j].code + ' majú od väčšie než do.';
      }
    }
    // Codex #333 kolo 3 P2: NEČÍSELNÝ skalár (poškodený alebo cudzí snapshot)
    // musí padnúť aj TU. Server ho normalizáciou nechá ako `null` a `lift_problem`
    // ho odmietne — klient ho predtým bral cez `|| 0` ako nulu (rezerva ticho
    // zmizla) a prah tyče netypoval vôbec, takže Save prešiel a server ho
    // zamietol nad pravidlom, ktoré sa v tejto obrazovke needituje.
    for (var s = 0; s < RD_LIFT_SCALARS.length; s++){
      var key = RD_LIFT_SCALARS[s][0];
      if (Object.prototype.hasOwnProperty.call(r, key) && rdLiftNum(r[key]) === null){
        return name + ': ' + RD_LIFT_SCALARS[s][1] + ' musí byť číslo.';
      }
    }
    // Za predošlou slučkou je hodnota (ak kľúč je) ISTOTNE konečné číslo.
    if (Object.prototype.hasOwnProperty.call(r, 'handle_allowance_kg')
        && r.handle_allowance_kg < 0){
      return name + ': rezerva na úchytku nesmie byť záporná.';
    }
    // KOV-E2: ZÁPORNÝ prah druhej tyče — `lift_rod_count` ho zahodí, takže by
    // pravidlo ticho tvrdilo „druhá tyč nikdy".
    if (Object.prototype.hasOwnProperty.call(r, 'rod_double_from_kb_mm')
        && r.rod_double_from_kb_mm < 0){
      return name + ': šírka pre druhú stabilizačnú tyč nesmie byť záporná.';
    }
    // KOV-E2: ZÁPORNÁ hodnota v tabuľke (rozmery, sily aj hmotnosti sú kladné).
    var neg = rdLiftNegative(classes, ['min', 'max'])
           || rdLiftNegative(mechs, ['max'])
           || rdLiftNegative(arms, ['kh_min', 'kh_max', 'kg_min', 'kg_max']);
    if (neg) return name + ': riadok ' + neg + ' má zápornú hodnotu — rozmery aj hmotnosti sú kladné.';
    var elig = rdLiftEligProblem(name, r.eligibility);
    if (elig) return elig;
    return rdLiftGapProblem(name, arms);
  }
  function rdLiftNegative(rows, keys){
    for (var i = 0; i < rows.length; i++){
      for (var k = 0; k < keys.length; k++){
        if (rows[i][keys[k]] < 0) return String(rows[i].code);
      }
    }
    return null;
  }
  // KOV-E2: spôsobilosť s OBRÁTENÝM rozsahom výšky — taký systém by nebol
  // použiteľný nikdy (každé čelo RED) a nikto by nevedel prečo. Zrkadlo
  // serverovej `lift_eligibility_problem` vrátane PORADIA systémov.
  var RD_LIFT_SYSTEMS = [['hk_top', 'HK top'], ['hl_top', 'HL top']];
  function rdLiftEligProblem(name, raw){
    if (!raw || typeof raw !== 'object') return null;
    for (var i = 0; i < RD_LIFT_SYSTEMS.length; i++){
      var rec = raw[RD_LIFT_SYSTEMS[i][0]];
      if (!rec || typeof rec !== 'object') continue;
      var lo = rdLiftNum(rec.kh_min), hi = rdLiftNum(rec.kh_max);
      if (lo === null || hi === null || lo <= hi) continue;
      return name + ': spôsobilosť ' + RD_LIFT_SYSTEMS[i][1] + ' má výšku od väčšiu než do.';
    }
    return null;
  }
  // DIERA medzi pásmami ramien: ďalšie pásmo sa musí začínať najneskôr tam,
  // kde predošlé končí — výška v diere by nedostala žiadne ramená.
  function rdLiftGapProblem(name, arms){
    var sorted = arms.slice().sort(function(a, b){ return a.kh_min - b.kh_min; });
    var reach = null;
    for (var i = 0; i < sorted.length; i++){
      if (reach !== null && sorted[i].kh_min > reach){
        return name + ': medzi pásmami ramien je medzera pri výške ' + reach
             + ' mm — výklop tej výšky by nedostal žiadne ramená.';
      }
      var top = sorted[i].kh_max;
      if (reach === null || top > reach) reach = top;
    }
    return null;
  }
  if (typeof window !== 'undefined') window.rdLiftProblem = rdLiftProblem;

  function rdValidate(rules){
    for (var i = 0; i < (rules || []).length; i++){
      var r = rules[i];
      if (r.kind === 'bands' && r.enabled !== false){
        var bands = rdArr(r.bands);
        var hasCatchAll = bands.some(function(b){ return b.max == null; });
        if (!bands.length || !hasCatchAll){
          return 'Pravidlo „' + rdLabel(r.output) + '“ potrebuje aspoň pásmo „všetko nad“.';
        }
        // Codex #329 kolo 3 P2: KONEČNÁ tabuľka („nad poslednou hodnotou =
        // chyba") bez jediného číselného pásma by dala catch-all počet každému
        // čelu a každé by zároveň bolo mimo tabuľky. Server ju odmieta —
        // klient musí povedať to isté (spoločný kontrakt je fixtúra parity).
        if (r.finite === true && !bands.some(function(b){ return b.max != null; })){
          return 'Pravidlo „' + rdLabel(r.output) + '“: konečná tabuľka potrebuje aspoň jedno číselné pásmo.';
        }
        // KOV-F2: hmotnostné pásma (voliteľný guard).
        var wmsg = rdWeightProblem(r);
        if (wmsg) return wmsg;
      }
      if (r.kind === 'fit_series' && r.enabled !== false && !rdArr(r.series).length){
        return 'Pravidlo „' + rdLabel(r.output) + '“ potrebuje aspoň jednu dĺžku v rade.';
      }
      // KOV-E1b (Codex #333 kolo 1 P2): výklopové pravidlo sa tu zatiaľ
      // needituje, ale ULOŽIŤ sa dá (sekcia ukladá VŠETKY pravidlá naraz) —
      // a server pokazené tabuľky odmieta. Bez tejto vetvy by klient uloženie
      // pustil, server ho zamietol a používateľ by nemal kde chybu opraviť.
      if (r.kind === 'lift_class' && r.enabled !== false){
        var lmsg = rdLiftProblem(r);
        if (lmsg) return lmsg;
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
                                           model_guid: RD_META.model_guid || '',
                                           // ŠT-3b-2c2: odtlačok sa iba VRACIA
                                           // — je to ten, ktorý prišiel s dátami,
                                           // z ktorých je formulár naplnený.
                                           rules_rev: RD_META.rules_rev || '' }));
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
                  cabinets: r.cabinets || 0, model_guid: r.model_guid || '',
                  rules_rev: r.rules_rev || '' };
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
    module.exports = { rdHandleHint: rdHandleHint, rdRuleTitle: rdRuleTitle,
                       rdIsLegacySlide: rdIsLegacySlide, RD_LEGACY_SLIDE_HINT: RD_LEGACY_SLIDE_HINT,
                       rulesToolsHtml: rulesToolsHtml, rdValidate: rdValidate,
                       rdLabel: rdLabel, rdRoleDesc: rdRoleDesc,
                       // KOV-E1b: súhrn výklopového pravidla (read-only do E2) —
                       // ČISTÁ funkcia, testuje sa aj bez DOM.
                       rdLiftSummary: rdLiftSummary,
                       rulesRenderBody: rulesRenderBody, rdApplyState: rdApplyState,
                       rdCollectRules: rdCollectRules, RD: RD,
                       // KOV-F2: editor door guardov. `rdGuardHtml`/`rdGuardSummary`/
                       // `rdHasGuardEditor` sú ČISTÉ (kreslenie a súhrn),
                       // `rdCollectGuards`, `rdAddWeight`, `rdDelWeight` a
                       // `rdGuardToggle` potrebujú DOM a exportujú sa ZÁMERNE:
                       // „prázdne pole = guard preč" a „pridanie pásma nezhodí
                       // rozpísané hodnoty" sa inak overiť nedá.
                       // `rdWeightBroken` je export ZAMERNY: „kľúč v nesprávnom
                       // tvare nezhodí sekciu" je kontrakt, ktorý sa inak dá
                       // overiť len tým, že sa taký snapshot naozaj vykreslí.
                       rdWeightBroken: rdWeightBroken,
                       rdHasGuardEditor: rdHasGuardEditor, rdGuardSummary: rdGuardSummary,
                       rdGuardHtml: rdGuardHtml, rdCollectGuards: rdCollectGuards,
                       rdAddWeight: rdAddWeight, rdDelWeight: rdDelWeight,
                       rdGuardToggle: rdGuardToggle, RD_GUARD_KEYS: RD_GUARD_KEYS,
                       // KOV-E2: editor pravidla výklopov. `rdLiftHtml`/`rdLiftSummary`
                       // sú čisté funkcie; `rdCollectLift` + tlačidlá riadkov
                       // potrebujú DOM a exportujú sa ZÁMERNE — „prázdne pole =
                       // kritérium preč", „`max_exclusive` prežije zber" a
                       // „pridanie riadku nezhodí rozpísané hodnoty" sa inak
                       // overiť nedá.
                       rdLiftSummary: rdLiftSummary, rdLiftHtml: rdLiftHtml,
                       rdCollectLift: rdCollectLift, rdLiftToggle: rdLiftToggle,
                       rdAddLiftClass: rdAddLiftClass, rdDelLiftClass: rdDelLiftClass,
                       rdAddLiftMech: rdAddLiftMech, rdDelLiftMech: rdDelLiftMech,
                       rdAddLiftArm: rdAddLiftArm, rdDelLiftArm: rdDelLiftArm,
                       RD_LIFT_KEYS: RD_LIFT_KEYS, RD_LIFT_ELIG: RD_LIFT_ELIG,
                       rdLiftProblem: rdLiftProblem,
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
                       rdResetOverride: rdResetOverride,
                       // ŠT-3b-2c2: ulozenie sa exportuje ZAMERNE — odtlacok
                       // („drzim ho, nepocitam, vraciam ho spat") sa da overit
                       // jedine tym, ze sa pozrieme, CO odchadza na server.
                       rdSaveRules: rdSaveRules };
  }
  // ŠT-3b-1: `sketchup.ready('')` tu ZANIKLO. V okne „Pravidlá kovania" bol
  // tento subor POSLEDNY a jeho `ready` znamenal „HTML je nacitane"; okno
  // zaniklo a v Studiu `ready` posiela `studio.js` (`window.onload`) — druhe
  // volanie by prinutilo okno poslat CELY payload dvakrat.
