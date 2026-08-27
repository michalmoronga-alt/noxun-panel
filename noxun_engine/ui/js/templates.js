  // ===================== Šablóny — sekcia `tpl` v okne Štúdio =================
  //
  // ŠT-3c-1: obsah zaniknutého okna „Šablóny" (Š18). Presun NEMOHOL byť 1:1 —
  // súbor okna definoval globálne `el`/`esc`, teda PRESNE tie, ktoré už má
  // `studio.js`. Všetko je preto prefixované `tpl*`/`TPL_*` (vzor `rd*`
  // v rules.js); PRIJÍMAČE sú nové (`TPL.*`), lebo okno malo `TD.*` a sekcia
  // má vlastný payload aj vlastný PNG kanál.
  //
  // ČO SEKCIA ROBÍ: spravuje uložené šablóny — použiť na označenú skrinku,
  // odfotiť/prefotiť náhľad, zmazať. UKLADANIE novej šablóny ostáva v mini-modale
  // Inspectora (má po ruke označenú skrinku); tlačidlo zo starého okna sa sem
  // NEPRENÁŠA a hint sekcie to hovorí.
  //
  // VÝBER: sekcia ho NESLEDUJE (žiadny observer). Tlačidlá sú VŽDY aktívne
  // a verdikt („nič nie je označené", „iný typ") povie SERVER pri kliku —
  // pravidlo D-78: nikdy mŕtve tlačidlo bez vysvetlenia.

  var TPL_DATA = null;
  // Cache PNG náhľadov per (kind, name, rev). Obrázok je radovo väčší než celý
  // zoznam, takže sa pýta LEN raz na revíziu; `null` = server povedal „náhľad
  // nemá" a znovu sa už nepýtame (vzor UI-D2 vo vkladacej karte).
  var TPL_PNG = {};
  // ROZPRACOVANÉ dotazy: kľúč revízie -> čas odoslania (ms). NIE `true` —
  // dávka 1b-4 (B1): jednosmerná značka znamenala, že STRATENÁ odpoveď
  // (výnimka v handleri, zavreté okno v okamihu odpovede) nechala dlaždicu
  // NAVŽDY na schéme; po `TPL_ASK_TIMEOUT_MS` sa dotaz smie zopakovať.
  // Značka vzniká VÝHRADNE vtedy, keď dotaz naozaj odišiel (bez mosta do Ruby
  // by revízia ostala „vypýtaná" a nikto by o ňu nepožiadal — vzor
  // `refreshTemplatePreviews` v `form.js`).
  var TPL_ASKED = {};
  var TPL_ASK_TIMEOUT_MS = 8000;
  // Dávkovanie (1b-4, B2): pri vstupe do sekcie išiel dotaz na KAŽDÚ šablónu
  // naraz (data URI má strop 64 kB × počet šablón v jednom nádychu). Ide preto
  // najviac `TPL_ASK_BATCH` dotazov na prechod a zvyšok si vypýta ďalšia dávka.
  // Vzhľad sa tým NEMENÍ — dlaždica bez obrázka kreslí schému, presne ako
  // predtým, len sa fotka doplní o chvíľu neskôr.
  var TPL_ASK_BATCH = 4;
  var TPL_ASK_GAP_MS = 120;
  var TPL_ASK_TIMER = null;
  // identita šablóny -> { id: DOM id, rev: revízia práve vykreslenej dlaždice }
  // (review #225 P2 + 1b-4 B1: revízia je tu preto, aby sa oneskorená odpoveď
  // nenasadila na dlaždicu, ktorá už ukazuje NOVŠIU verziu šablóny).
  var TPL_DOM = {};
  // BEŽIACI požiadavok premenovania (review #226 P2). Odpoveď servera smie
  // siahnuť na modal LEN vtedy, keď je na obrazovke stále TEN, ktorý ju
  // vyvolal: kým sa čaká na zámok súboru, používateľ stihne modal zavrieť
  // (Esc) a otvoriť iný — a `renameSaved` by mu ten cudzí rozpísaný
  // formulár ZAVREL. Token sa nastavuje pri odoslaní a KAŽDÉ otvorenie
  // ľubovoľného modalu ho zahadzuje.
  var TPL_REN = null;

  function tplEl(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }
  // Je sekcia Šablóny práve otvorená? Autoritou je `studio.js` (`studioSec`).
  // Keď sa to zistiť nedá, odpoveď je NIE — nekresliť je vždy bezpečnejšie než
  // prepísať cudziu sekciu; obsah aj tak dokreslí `renderBody` pri vstupe.
  function tplIsActive(){
    if (typeof studioActiveSection === 'function') return studioActiveSection() === 'tpl';
    if (TPL_STUDIO && typeof TPL_STUDIO.studioActiveSection === 'function'){
      return TPL_STUDIO.studioActiveSection() === 'tpl';
    }
    return false;
  }
  function tplEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function tplArg(v){ return tplEsc(JSON.stringify(String(v == null ? '' : v))); }
  function tplIco(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }
  function tplTypeLabel(t){ return t === 'upper' ? 'horná' : 'dolná'; }
  // Kľúč cache náhľadov. Oddeľovač NESMIE byť znak, ktorý sa môže objaviť
  // v mene šablóny — a už vôbec nie NUL bajt: ten spraví z celého súboru
  // BINÁRNY (git ho prestane diffovať a review ho nevidí — review #225 P1).
  // `JSON.stringify` je jednoznačný a čisto ASCII.
  function tplKey(kind, name, rev){
    return JSON.stringify([String(kind || ''), String(name || ''), String(rev || '')]);
  }

  // Prijímače zo servera.
  var TPL = {
    // ECHO knižnice (uloženie šablóny z Inspectora, zmazanie, nový náhľad).
    // Review #225 P1: `#secbody` a `#sectools` sú ZDIELANÉ uzly celého okna —
    // kresliť do nich smie LEN sekcia, ktorá je práve otvorená. Bez tejto
    // poistky by uloženie šablóny z Inspectora prepísalo rozpísaný formulár
    // Rozpočtu (a navigácia by pritom stále ukazovala Rozpočet).
    // Keď sekcia otvorená nie je, stav sa iba ULOŽÍ — vykreslí ho `renderBody`
    // pri najbližšom vstupe do sekcie.
    init: function(data){
      TPL_DATA = data || null;
      if (!tplIsActive()) return;
      tplRenderBody();
      tplRenderTools(false);
    },
    setStatus: function(msg, err){
      var e = tplEl('status');
      if (!e) return;
      e.textContent = msg;
      e.className = err ? 'err' : 'ok';
    },
    // PNG odpoveď na `tpl_preview`. `rev` sa vracia nezmenené, takže sa dá
    // priradiť k správnej verzii — medzitým mohol prísť nový náhľad.
    setPreview: function(d){
      if (!d || !d.name) return;
      var key = tplKey(d.kind, d.name, d.rev);
      TPL_PNG[key] = d.png || null;
      // Odpoveď dorazila — záznam „beží" je vybavený. Ďalej rozhoduje CACHE
      // (aj záporná), takže sa o tú istú revíziu už nikto nepýta.
      delete TPL_ASKED[key];
      tplApplyPreview(d);
    },
    // --- výsledok premenovania (ŠT-3c-2) ---------------------------------
    // Zatvára VÝHRADNE potvrdený zápis. Zoznam dlaždíc dorazí SAMOSTATNE
    // (`TPL.init` echom po zmene knižnice), takže tu sa nič neprekresľuje.
    renameSaved: function(){
      if (!TPL_REN) return;      // odpoveď na požiadavok, ktorý už nikto nečaká
      TPL_REN = null;
      var m = (typeof window !== 'undefined') ? window.NXModal : null;
      if (!m || !m.isOpen()) return;
      m.setBusy(false, { clear: true });
      m.close();
    },
    // Šablóna medzitým zmizla (review #226 NOTE 3): modal sa ZAVRIE — meno
    // neexistujúcej šablóny nie je čo opravovať. Rozpísané sa NEZABÚDA
    // (`clear` sa nedáva): nebol to potvrdený zápis, len zánik cieľa.
    renameClosed: function(){
      if (!TPL_REN) return;
      TPL_REN = null;
      var m = (typeof window !== 'undefined') ? window.NXModal : null;
      if (!m || !m.isOpen()) return;
      m.setBusy(false);
      m.close();
    },
    // Odmietnuté premenovanie: modal OSTÁVA otvorený s rozpísaným menom,
    // odomkne sa a chyba sedí pri poli. Bez `setBusy(false)` by po prvom
    // odmietnutí ostalo „Premenovať" navždy zosednuté (isBusy).
    renameError: function(msg, field){
      // Cudzi modal sa NEOZNACUJE chybou — hláška aj tak dorazí do stavového
      // riadku sekcie (server ju posiela oboma kanálmi).
      if (!TPL_REN) return;
      TPL_REN = null;
      var m = (typeof window !== 'undefined') ? window.NXModal : null;
      if (!m || !m.isOpen()) return;
      m.setBusy(false);
      m.showErrors([{ field: field || 'name', msg: msg }]);
    }
  };
  if (typeof window !== 'undefined') window.TPL = TPL;

  // Náhľad sa nasadí do UŽ VYKRESLENEJ dlaždice (nevymieňa sa uzol — klik by
  // stratil cieľ). Bez náhľadu ostáva schéma, presne ako vo vkladacej karte.
  //
  // 1b-4 (B1): odpoveď patrí REVÍZII, ktorú si dlaždica vypýtala. Kým sa čakalo
  // na disk, mohla prísť nová knižnica (prefotená šablóna = nová `preview_rev`)
  // — nasadiť starý obrázok by znamenalo, že používateľ vidí fotku tvaru, ktorý
  // šablóna už nepostaví. Nesúlad revízie = odpoveď sa zahodí (v cache ostáva
  // pod svojím kľúčom, takže sa o ňu nikto nepýta znova).
  function tplApplyPreview(d){
    var rec = tplDomFor(d.kind, d.name);
    if (!rec) return;
    if (String(d.rev == null ? '' : d.rev) !== String(rec.rev == null ? '' : rec.rev)) return;
    var box = tplEl('tplpic-' + rec.id);
    if (!box) return;
    var img = box.querySelector ? box.querySelector('img') : null;
    if (!d.png || !img){ return; }
    img.src = d.png;
    box.className = 'stplpic has';
  }

  // DOM id dlaždice. Review #225 P2: NESMIE vzniknúť z mena „očistením"
  // znakov — „Dolná 600" aj „Dolné 600" by dali `cabinet-Doln__600`, dve
  // dlaždice by mali TO ISTÉ id a náhľad by sa nakreslil na prvú z nich.
  // Používateľ by potom vyberal šablónu podľa cudzej fotky. Id je preto
  // PORADOVÉ a mapa `TPL_DOM` (plnená pri kreslení) drží presné priradenie
  // identity → uzol (a od 1b-4 aj jeho revíziu).
  function tplDomIdAt(kind, idx){ return String(kind || '') + '-' + idx; }
  function tplDomFor(kind, name){ return TPL_DOM[tplKey(kind, name, '')] || null; }
  function tplDomIdFor(kind, name){
    var rec = tplDomFor(kind, name);
    return rec ? rec.id : null;
  }

  // --- LIŠTA sekcie — čistá funkcia (Node test) ------------------------------
  // Okno malo v lište „Uložiť označený korpus ako šablónu"; sem sa NEPRENÁŠA
  // (Inspector je jediný vstup na ukladanie). Hľadanie okno nemalo a sekcia ho
  // nepridáva — presun je 1:1.
  function tplToolsHtml(st){
    var s = st || {};
    var h = '<span class="stplinfo">' + tplEsc(s.info || '') + '</span><span class="spacer"></span>';
    var refresh = (typeof refreshBtnHtml === 'function')
      ? refreshBtnHtml
      : (TPL_STUDIO ? TPL_STUDIO.refreshBtnHtml : null);
    if (refresh) h += refresh(s.stale === true, 'Načítať knižnicu šablón nanovo');
    return h;
  }

  // Zdielaný markup jantárového „Obnoviť" zo `studio.js` (v prehliadači global,
  // v Node testoch príde requirom).
  var TPL_STUDIO = (typeof module !== 'undefined' && module.exports)
    ? require('./studio.js')
    : null;

  function tplCounts(){
    var c = (TPL_DATA && TPL_DATA.cabinet) ? TPL_DATA.cabinet.length : 0;
    var b = (TPL_DATA && TPL_DATA.board) ? TPL_DATA.board.length : 0;
    return { cabinet: c, board: b };
  }

  function tplToolsState(stale){
    var n = tplCounts();
    return { stale: stale === true,
             info: 'korpusových: ' + n.cabinet + ' · doskových: ' + n.board };
  }

  function tplRenderTools(stale){
    var box = tplEl('sectools');
    if (box) box.innerHTML = tplToolsHtml(tplToolsState(stale));
  }

  // --- TELO sekcie -----------------------------------------------------------
  //
  // Dlaždice v dvoch skupinách (mockup Š18): Korpusové · Doskové. Doskové sa
  // ZOBRAZUJÚ a od ŠT-3c-1/3c-2 sa dajú aj PREMENOVAŤ a ZMAZAŤ (dovtedy ich
  // nespravovalo nič), ale akcie „použiť"/„odfotiť" NEMAJÚ —
  // apply je typová operácia nad skrinkou a fotka dosky by bola fotka ničoho.
  // Nezobrazujú sa ako `disabled`, ale VÔBEC (D-78: mŕtve tlačidlo bez blízkeho
  // sľubu je horšie než jeho absencia) — vedomá odchýlka od mockupu, ktorý
  // kreslí 4 akcie všade.
  function tplTileHtml(tp, kind, idx){
    var cfg = tp.config || {};
    var isCab = kind === 'cabinet';
    var type = cfg.type || 'lower';
    var dims = tplDims(cfg);
    var id = tplDomIdAt(kind, idx == null ? 0 : idx);
    TPL_DOM[tplKey(kind, tp.name, '')] = { id: id, rev: tp.preview_rev };
    var h = '<div class="stpltile" data-kind="' + tplEsc(kind) + '" data-name="' + tplEsc(tp.name) + '">' +
      '<div class="stplpic" id="tplpic-' + tplEsc(id) + '">' +
      (tp.preview_rev ? '<img alt="">' : '') +
      '<span class="stplph">' + (tp.preview_rev ? '' : 'schéma') + '</span></div>' +
      '<b class="stplname">' + tplEsc(tp.name) + '</b>' +
      '<span class="stplmeta">' + tplEsc(isCab ? tplTypeLabel(type) : 'doska') +
      (dims ? ' · ' + tplEsc(dims) : '') + '</span>' +
      '<span class="stplact">';
    if (isCab){
      h += '<button type="button" class="stplbtn" title="Prestaví označenú skrinku podľa šablóny' +
        ' — jeden krok Späť to vráti" aria-label="Použiť na označenú skrinku"' +
        ' onclick="tplApply(' + tplArg(tp.name) + ')">' + tplIco('box') + '</button>' +
        '<button type="button" class="stplbtn" title="' + tplEsc(tplCaptureTitle(tp)) + '"' +
        ' aria-label="' + tplEsc(tplCaptureLabel(tp)) + '"' +
        ' onclick="tplCapture(' + tplArg(tp.name) + ')">' + tplIco('camera') + '</button>';
    }
    // Ceruzka je MIMO vetvy `isCab` (audit N6): premenovať sa dá OBOJE —
    // doskovú šablónu dnes nepremenuje nič iné.
    h += '<button type="button" class="stplbtn" title="Premenovať šablónu"' +
      ' aria-label="Premenovať šablónu" onclick="tplRename(' + tplArg(kind) + ', ' +
      tplArg(tp.name) + ')">' + tplIco('pencil') + '</button>';
    h += '<button type="button" class="stplbtn stpldel" title="Zmazať šablónu"' +
      ' aria-label="Zmazať šablónu" onclick="tplDelete(' + tplArg(kind) + ', ' + tplArg(tp.name) + ')">' +
      tplIco('trash') + '</button></span></div>';
    return h;
  }

  // Rozmery z uloženej konfigurácie — to, čo šablóna postaví (nie to, čo je
  // práve označené). Chýbajúce údaje sa NEDOMÝŠĽAJÚ.
  function tplDims(cfg){
    var w = cfg.width, h = cfg.height, d = cfg.depth;
    var out = [];
    if (w) out.push(Math.round(w));
    if (h) out.push(Math.round(h));
    if (d) out.push(Math.round(d));
    return out.length ? out.join('×') : '';
  }

  function tplCaptureLabel(tp){ return tp && tp.preview_rev ? 'Prefotiť' : 'Odfotiť'; }
  function tplCaptureTitle(tp){
    return (tp && tp.preview_rev)
      ? 'Prepíše náhľad tejto šablóny fotkou označenej skrinky (dáta šablóny sa nemenia)'
      : 'Pridá náhľad tejto šablóne z označenej skrinky (dáta šablóny sa nemenia)';
  }

  function tplGroupHtml(title, list, kind, empty){
    var h = '<div class="subhead">' + tplEsc(title) + '</div>';
    if (!list || !list.length) return h + '<div class="muted stplempty">' + tplEsc(empty) + '</div>';

    h += '<div class="stpltiles">';
    list.forEach(function(tp, i){ h += tplTileHtml(tp, kind, i); });
    return h + '</div>';
  }

  function tplBodyHtml(){
    if (!TPL_DATA) return '<div class="muted">Načítavam…</div>';

    TPL_DOM = {}; // mapa platí pre PRÁVE kreslený obsah

    var h = tplGroupHtml('Korpusové šablóny', TPL_DATA.cabinet, 'cabinet',
                         'Žiadne korpusové šablóny — ulož označenú skrinku v Inspectore (sektor Šablóna).');
    h += tplGroupHtml('Doskové šablóny', TPL_DATA.board, 'board',
                      'Žiadne doskové šablóny.');
    h += '<div class="hint">Šablóny sú spoločné pre všetky zákazky. NOVÚ šablónu ukladáš ' +
      'v Inspectore z označenej skrinky; tu ich spravuješ. Premenovať a zmazať sa dá každá; ' +
      'použiť a odfotiť sa dá len korpusová (fotka dosky by bola fotka ničoho).</div>';
    return h;
  }

  function tplRenderBody(){
    var box = tplEl('secbody');
    if (!box) return;
    box.innerHTML = tplBodyHtml();
    tplRequestPreviews();
  }

  // ČISTÉ JADRO rozhodovania (Node testy, vzor `nxTplPreviewPlan` vo `form.js`):
  // z knižnice, cache a mapy rozpracovaných dotazov povie, ktorým dlaždiciam sa
  // dá nasadiť už známy obrázok (`apply`), na ktoré sa má TERAZ poslať dotaz
  // (`ask`, najviac `limit`), koľko ich ostalo na ďalšiu dávku (`rest`) a na
  // koľko odpovedí sa práve čaká (`pending`). Pravidlá:
  //   * dlaždica bez `preview_rev` = šablóna náhľad NEMÁ -> nič (ani dotaz),
  //   * kľúč v cache (aj s hodnotou `null` = záporná odpoveď) -> žiadny dotaz,
  //   * dotaz odoslaný pred menej než `TPL_ASK_TIMEOUT_MS` -> beží, počká sa;
  //     starší sa považuje za STRATENÝ a pýta sa znova (1b-4 B1).
  // `asked` sa TU NEPLNÍ — značku smie zapísať len ten, kto dotaz naozaj odoslal.
  function tplPreviewPlan(data, cache, asked, now, limit){
    var out = { apply: [], ask: [], rest: 0, pending: 0 };
    ['cabinet', 'board'].forEach(function(kind){
      ((data && data[kind]) || []).forEach(function(tp){
        if (!tp || !tp.name || !tp.preview_rev) return;
        var key = tplKey(kind, tp.name, tp.preview_rev);
        if (Object.prototype.hasOwnProperty.call(cache, key)){
          out.apply.push({ kind: kind, name: tp.name, rev: tp.preview_rev, png: cache[key] });
          return;
        }
        var sent = asked[key];
        if (typeof sent === 'number' && (now - sent) < TPL_ASK_TIMEOUT_MS){ out.pending++; return; }
        if (out.ask.length >= limit){ out.rest++; return; }
        out.ask.push({ kind: kind, name: tp.name, rev: tp.preview_rev, key: key });
      });
    });
    return out;
  }

  function tplNow(){
    return (typeof Date !== 'undefined' && Date.now) ? Date.now() : 0;
  }

  function tplCancelAsk(){
    if (TPL_ASK_TIMER == null) return;
    if (typeof clearTimeout === 'function') clearTimeout(TPL_ASK_TIMER);
    TPL_ASK_TIMER = null;
  }

  // Ďalší prechod. Krátka pauza = ešte je čo pýtať (dávkovanie), dlhá = čaká sa
  // len na odpovede a je to POISTKA proti stratenej odpovedi. V Node testoch by
  // čakajúci časovač držal proces nažive — `unref` je preto povinný (v prehliadači
  // metóda neexistuje a vetva sa preskočí).
  //
  // Review #241 P3-1: časovač sa pri odchode zo sekcie ZASTAVÍ. Bez tejto brány
  // by dávkovanie bežalo ďalej aj potom, čo je používateľ v Rozpočte — pri veľkej
  // knižnici je to niekoľko sekúnd cudzej prevádzky na moste popri jeho práci
  // (odpovede by sa síce bezpečne zahodili, ale platiť za ne netreba). Reťaz sa
  // NEOBNOVUJE tu: návrat do sekcie kreslí `tplRenderBody`, ktorý si
  // `tplRequestPreviews` zavolá sám — a rozpracované dotazy medzitým vypršia
  // timeoutom, takže sa o ne sekcia prihlási znova.
  function tplScheduleAsk(ms){
    if (typeof setTimeout !== 'function') return;
    tplCancelAsk();
    TPL_ASK_TIMER = setTimeout(function(){
      TPL_ASK_TIMER = null;
      if (!tplIsActive()) return;
      tplRequestPreviews();
    }, ms);
    if (TPL_ASK_TIMER && typeof TPL_ASK_TIMER.unref === 'function') TPL_ASK_TIMER.unref();
  }

  // PNG sa pýta AŽ PO vykreslení a LEN pre dlaždice, ktoré náhľad majú a ešte
  // ho v cache nemajú. Odpoveď sa nasadí do už existujúceho uzla.
  function tplRequestPreviews(){
    tplCancelAsk();
    if (!TPL_DATA) return;
    var plan = tplPreviewPlan(TPL_DATA, TPL_PNG, TPL_ASKED, tplNow(), TPL_ASK_BATCH);
    plan.apply.forEach(tplApplyPreview);
    // Bez mosta do Ruby sa do `TPL_ASKED` NESMIE nič zapísať — záznam by ostal
    // navždy „vypýtaný" a žiadosť by neodišla nikdy (vzor `form.js`).
    if (typeof window === 'undefined' || !window.sketchup || !sketchup.tpl_preview) return;
    plan.ask.forEach(function(d){
      TPL_ASKED[d.key] = tplNow();
      sketchup.tpl_preview(JSON.stringify({ kind: d.kind, name: d.name, rev: d.rev }));
    });
    if (plan.rest > 0) return tplScheduleAsk(TPL_ASK_GAP_MS);
    if (plan.ask.length + plan.pending > 0) tplScheduleAsk(TPL_ASK_TIMEOUT_MS);
  }

  // --- akcie -> Ruby ---------------------------------------------------------

  function tplSend(name, payload){
    if (typeof window === 'undefined' || !window.sketchup || !sketchup[name]){
      TPL.setStatus('Okno stratilo spojenie so SketchUpom — zavri a otvor Štúdio znova.', true);
      return;
    }
    sketchup[name](JSON.stringify(payload));
  }

  function tplApply(name){ tplSend('tpl_apply', { template: name }); }
  function tplCapture(name){ tplSend('tpl_capture', { kind: 'cabinet', template: name }); }

  // Mazanie sa POTVRDZUJE — a to v D-15 modáli (`nx_modal.js`), NIE natívnym
  // `UI.messagebox` ako v zaniknutom okne: natívny modál v callbacku HtmlDialogu
  // blokuje celý kanál okna. Text doskovej šablóny hovorí navyše to, čo z nej
  // nevidno: doskové šablóny NEMAJÚ seed, takže zmazaná sa nikdy nevráti.
  function tplDelete(kind, name){
    if (typeof window === 'undefined' || !window.NXModal){
      tplSend('tpl_delete', { kind: kind, template: name });
      return;
    }
    window.NXModal.open({
      title: 'Zmazať šablónu',
      sub: tplDeleteSub(kind, name),
      note: tplDeleteNote(kind),
      okLabel: 'Zmazať',
      danger: true,
      fields: [],
      onSubmit: function(){
        window.NXModal.close();
        tplSend('tpl_delete', { kind: kind, template: name });
      }
    });
  }

  function tplDeleteSub(kind, name){
    return (kind === 'board' ? 'Doskovú šablónu' : 'Šablónu') + ' „' + name + '" zmazať z knižnice?';
  }

  function tplDeleteNote(kind){
    return kind === 'board'
      ? 'Doskové šablóny sa neobnovujú — knižnica ich sama nedoplní, takže zmazaná sa už NIKDY nevráti. ' +
        'Skrinky ani dosky v projektoch sa tým nemenia.'
      : 'Knižnica je spoločná pre všetky zákazky. Skrinky, ktoré zo šablóny vznikli, sa tým NEMENIA.';
  }

  // Premenovanie (ŠT-3c-2). Modal má JEDINÉ pole — predvyplnené súčasným
  // menom, takže „preklep v mene" je oprava dvoch znakov, nie prepisovanie.
  //
  // KĽÚČ POĽA je `name`, ale na server ide ako `new_name`: v ostatných akciách
  // sekcie znamená `template` meno SÚČASNÉ, a poslať nové meno pod kľúčom
  // `name` by bola pasca na prvého, kto sa v handleri pomýli.
  //
  // Modal sa po odoslaní NEZATVÁRA — zatvorí ho až `TPL.renameSaved` (kontrakt
  // D-15: o výsledku zápisu rozhoduje server). Pri odmietnutí (obsadené meno)
  // ostáva otvorený s rozpísaným menom a chybou pri poli.
  //
  // Pamäť rozpísaného mena sa ZÁMERNE nepoužíva (`memoryKey` chýba): Esc je
  // pri jednom poli jednoznačné „nechaj to tak" a pri ďalšom otvorení má
  // používateľ vidieť meno, ktoré šablóna NAOZAJ má.
  function tplRename(kind, name){
    if (typeof window === 'undefined' || !window.NXModal){
      TPL.setStatus('Premenovanie potrebuje dialóg Štúdia — zavri a otvor Štúdio znova.', true);
      return;
    }
    tplWatchModal(window.NXModal);
    TPL_REN = null;            // nové otvorenie ruší predchádzajúci požiadavok
    window.NXModal.open({
      title: 'Premenovať šablónu',
      sub: tplRenameSub(kind, name),
      note: tplRenameNote(kind),
      okLabel: 'Premenovať',
      fields: [{ key: 'name', label: 'Názov', value: name }],
      onSubmit: function(v){
        TPL_REN = { kind: kind, name: name };
        tplSend('tpl_rename', { kind: kind, template: name,
                                new_name: (v && v.name != null) ? v.name : '' });
      }
    });
  }

  // Každé otvorenie ĽUBOVOĽNÉHO modalu zahadzuje bežiaci požiadavok — vrátane
  // znovuotvorenia toho istého premenovania (token vzniká až odoslaním).
  // Obal sa nasadzuje LENIVO (pri prvom premenovaní), nie pri načítaní súboru:
  // v Node testoch je `NXModal` stub, ktorý v tej chvíli ešte neexistuje.
  function tplWatchModal(m){
    if (!m || m.tplWatch === true || typeof m.open !== 'function') return;
    var orig = m.open;
    m.open = function(){ TPL_REN = null; return orig.apply(m, arguments); };
    m.tplWatch = true;
  }

  function tplRenameSub(kind, name){
    return (kind === 'board' ? 'Doskovú šablónu' : 'Šablónu') + ' „' + name + '" premenovať:';
  }

  // Premenovanie NIE JE zmena projektov — a pri doskových šablónach navyše
  // platí to isté ako pri mazaní: knižnica pôvodné meno sama nedoplní.
  function tplRenameNote(kind){
    return kind === 'board'
      ? 'Doskové šablóny sa neobnovujú — pôvodné meno sa už NIKDY nevráti. ' +
        'Skrinky ani dosky v projektoch sa tým nemenia.'
      : 'Mení sa len meno v knižnici. Skrinky, ktoré zo šablóny vznikli, sa tým NEMENIA.';
  }

  if (typeof window !== 'undefined'){
    window.tplApply = tplApply;
    window.tplCapture = tplCapture;
    window.tplDelete = tplDelete;
    window.tplRename = tplRename;
  }

  // Modelový kontext sekcie z payloadu Štúdia (`ST.tpl`). Knižnica je globálna,
  // takže sa pri každom pushi jednoducho nasadí — nie je v nej nič rozpísané,
  // čo by sa dalo stratiť (na rozdiel od formulára pravidiel).
  function tplApplyState(t){
    if (!t) return;
    TPL_DATA = t;
  }

  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var tplPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      tplApplyState(data && data.tpl);
      tplPrevSetStudio(data);
    };
  }

  // Node testy (tests/js/test_st3c_tpl.js) — ČISTÉ funkcie bez DOM
  // (`tplToolsHtml`, `tplTileHtml`, `tplBodyHtml`, `tplDeleteNote`,
  // `tplPreviewPlan`) + `tplRenderBody`/`TPL`, ktoré DOM potrebujú a exportujú
  // sa ZÁMERNE: „doskám sa akcie nezobrazujú" a „PNG sa pýta raz na revíziu" sa
  // inak overiť nedá ničím než klikaním. `tplCancelAsk` je pre testy povinný —
  // bez zrušenia časovača dávky by sada nedobehla.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { tplPreviewPlan: tplPreviewPlan, tplCancelAsk: tplCancelAsk,
                       tplToolsHtml: tplToolsHtml, tplTileHtml: tplTileHtml,
                       tplBodyHtml: tplBodyHtml, tplDeleteNote: tplDeleteNote,
                       tplDeleteSub: tplDeleteSub, tplRenderBody: tplRenderBody,
                       tplRenderTools: tplRenderTools, tplApplyState: tplApplyState,
                       tplIsActive: tplIsActive, tplDomIdFor: tplDomIdFor,
                       tplDelete: tplDelete, tplApply: tplApply, tplCapture: tplCapture,
                       tplRename: tplRename, tplRenameSub: tplRenameSub,
                       tplRenPending: function(){ return TPL_REN; },
                       tplRenameNote: tplRenameNote,
                       TPL: TPL };
  }
