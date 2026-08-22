  // ====== SEKCIE ROZPOCET + CENOVA PONUKA okna STUDIO (ŠT-1c PR B1/B2) ======
  // Do ŠT-1c to bol TAB zaniknuteho okna Vyroba; od PR B1 je to SEKCIA `budget` okna
  // Studio. Presun je 1:1 v OBSAHU (Š12) — nie v kode: render sa rozrezal na
  // LISTU sekcie (`budToolsHtml` — DPH, rezim, prepocet cien, export, ⚙) a
  // TELO (`budDrawBody`), lebo v Studiu su to dve rozne miesta v DOM.
  //
  // PR B2 pridal DRUHU sekciu — `offer` (Cenova ponuka, Š14–Š15). Kresli ju
  // TENTO ISTY subor zamerne: je to PROJEKCIA toho isteho payloadu (`cp_preview`)
  // a tie iste mutacie (`cp_group`) — druhy subor by znamenal druhu kopiu
  // formatovania sum a druhy kanal na server.
  //
  // Subor sa nacitava AZ ZA `studio.js` (studio.html): cita jeho globalny
  // payload `ST` (pole `ST.budget`) a OBALUJE `NX.setStudio`.
  //
  // ZELEZNE PRAVIDLO: JS NEPOCITA ZIADNE SUMY — vsetky medzisucty, zaokruhlenie
  // aj SPOLU su hotove cisla zo servera (vzor KONTROLA counts). JEDINA povolena
  // aritmetika je delenie `vat_divisor` pri prepnuti na "bez DPH" — cisto
  // ZOBRAZOVACI prepocet (firma je neplatca DPH, katalogove ceny su konecne),
  // oznaceny nizsie.
  //
  // Mutacie (rezim, prepis sumy, nasobok, m2, vlastne polozky, spotrebice) idu
  // cez JEDEN callback `budget_mutate` s gen + model_guid; server ich overi,
  // zapise (1 undo krok) a posle CERSTVY payload. Klient si stav nedopocitava.
  // Tento payload chodi s `bump: false` (StudioDialog) — generacia okna sa
  // NEDVIHA, lebo mutacia rozpoctu nemeni riadky kusovnika ani ich refs.

  var BUD_VAT = true;          // prepinac zobrazenia (localStorage, len UX)
  var BUD_OPEN = null;         // { sekcia -> otvorena? } — prezije re-render
  var BUD_STALE_OPEN = false;
  // ŠT-1c PR B2: rozpisany novy riadok uz nie je INLINE draft v tele sekcie —
  // je to D-15 modal (`js/nx_modal.js`). `BUD_DRAFT` = ktora „pridavacka" je
  // prave otvorena ('custom' | 'appliance').
  var BUD_DRAFT = null;
  // ROZPISANE HODNOTY PER DRUH (review #3+#4). Dva dovody, preco to nie je
  // jednorazova premenna:
  //   1. ODMIETNUTY ZAPIS (audit #10) — modal ostava otvoreny s tym, co
  //      pouzivatel napisal, a opravuje sa JEDNO cislo;
  //   2. ZATVORENIE Escapom alebo klikom vedla — dovtedy to bola TICHA STRATA
  //      rozpisaneho riadku. Hodnoty prezijú v pamati a najblizsie otvorenie
  //      TEJ ISTEJ pridavacky ich predvyplni; zmaze ich az USPESNY zapis
  //      (`budCloseDraft`), lebo vtedy uz riadok v rozpocte naozaj je.
  // Per DRUH preto, ze polia vlastnej polozky a spotrebica su ine — spolocna
  // pamat by ich miesala.
  var BUD_DRAFT_VALUES = { custom: null, appliance: null };
  var BUD_MODAL = null;        // { kind, id } — otvoreny ⋯ modal
  var BUD_FOCUS = null;        // obnova fokusu/hodnoty cez re-render
  // E-c „Prepočítať ceny": { phase:'confirm'|'run'|'report', pid, total, done,
  // label, report, single, cancelling }. Beh riadi SERVER — toto je len okno.
  var BUD_PR = null;

  // GH #138 P2: zapisy sa SERIALIZUJU. `sketchup.*` je asynchronne — pri
  // rychlom slede (blur poľa + hneď klik na režim) by sa druhy zapis poslal
  // este so STAROU `gen` a server by ho odmietol ako zastaraly, hoci je
  // uplne v poriadku. Kym nedorazi cerstvy payload, dalsie mutacie cakaju
  // vo fronte a odosielaju sa AZ s novou generaciou.
  var BUD_BUSY = false;
  var BUD_QUEUE = [];
  var budBusyTimer = null;
  var BUD_BUSY_MS = 6000; // poistka, keby Ruby callback spadol pred push_state

  var BUD_VAT_KEY = 'nx_budget_vat';

  // --- ciste pomocne funkcie (testovane v tests/js/test_budget_ui.js) -------

  function bEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // Suma -> text. null/undefined = "—" (nezadana cena sa NIKDY nezobrazi ako 0).
  function budFmtEur(v){
    if (v === null || v === undefined || v === '' || isNaN(v)) return '—';
    var f = Math.round(Number(v) * 100) / 100;
    var neg = f < 0;
    var s = Math.abs(f).toFixed(2);
    var parts = s.split('.');
    // Oddelovac tisicov = NEZALOMITELNA medzera (slovenska typografia).
    // Escape sekvencia, nie neviditelny znak v zdrojaku.
    var whole = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '\u00A0');
    return (neg ? '−' : '') + whole + ',' + parts[1] + ' €';
  }

  function budFmtNum(v, dec){
    if (v === null || v === undefined || v === '' || isNaN(v)) return '—';
    return Number(v).toFixed(dec == null ? 0 : dec).replace('.', ',');
  }

  // JEDINA aritmetika v tomto subore: prepocet ZOBRAZENIA na "bez DPH".
  // Vypocet rozpoctu bezi VYHRADNE v brutto (server) — toto je len okno na to
  // iste cislo, nikdy nie zaklad dalsieho vypoctu.
  function budDisplay(value, withVat, divisor){
    if (value === null || value === undefined || value === '' || isNaN(value)) return null;
    var f = Number(value);
    if (withVat) return f;
    var d = Number(divisor);
    if (!d || isNaN(d) || d <= 0) return f;
    return f / d;
  }

  // Slovenske sklonovanie poctov (1 / 2-4 / 5+).
  function budPluralSk(n, forms){
    var i = Math.abs(Number(n) || 0);
    if (i === 1) return forms[0];
    if (i >= 2 && i <= 4) return forms[1];
    return forms[2];
  }

  function budStaleLabel(stale){
    var s = stale || {};
    var c = s.counts || {};
    var n = Number(c.stale || 0);
    if (!n) return null;
    return n + ' ' + budPluralSk(n, ['cena staršia', 'ceny staršie', 'cien starších']) +
           ' ako ' + (s.stale_days || 30) + ' dní';
  }

  // Tri oranzove upozornenia z mocku v4 — VSETKY z payloadu (texty pre riadky
  // sklada SERVER v Budget.check; tu sa len triedia a pocitaju polozky pola).
  function budWarnChips(budget){
    var out = [];
    var b = budget || {};
    var stale = budStaleLabel(b.stale);
    if (stale) out.push({ id: 'stale', text: stale, list: (b.stale && b.stale.items) || [] });
    var t = b.totals || {};
    var appl = Number(t.appliances_subtotal || 0);
    if (appl > 0){
      out.push({ id: 'appl', included: t.appliances_included === true, amount: appl });
    }
    // Upozornenia rozpoctu. Do ŠT-1c PR B1 sa spotrebicove upozornenie ODPOCITALO
    // (chip pod sebou rozbaloval vlastny zoznam, v ktorom uz malo vlastny chip
    // vyssie). Odkedy chip VEDIE DO KONTROLY, musi ukazovat TO ISTE cislo, ake
    // tam pouzivatel uvidi — a Kontrola nesie VSETKY rozpoctove nalezy vratane
    // spotrebicoveho (`Validation.with_budget`, kontrakt counts z ŠT-1b sa
    // nemeni). Chip spotrebicov ostava ako SPECIFICKA skratka na ich sekciu.
    var all = b.budget_check || [];
    if (all.length){
      out.push({ id: 'check', count: all.length, list: all,
                 text: all.length + ' ' + budPluralSk(all.length,
                   ['upozornenie rozpočtu', 'upozornenia rozpočtu', 'upozornení rozpočtu']) });
    }
    return out;
  }

  // Payload mutacie — jedno miesto, kde sa sklada identita zapisu.
  // (Argument sa vola `bom` z historickych dovodov; od ŠT-1c PR B1 do neho
  // chodi payload OKNA STUDIO `ST` — tvar `gen` + `model_guid` je ten isty.)
  function budMutation(bom, op, extra){
    var p = { op: op, gen: bom ? bom.gen : 0, model_guid: (bom && bom.model_guid) || '' };
    for (var k in (extra || {})){
      if (Object.prototype.hasOwnProperty.call(extra, k)) p[k] = extra[k];
    }
    return p;
  }

  // Text pola -> hodnota mutacie. Prazdne pole = null (= zrus prepis / vrat
  // default), necislo = NaN (klient nic neposle, pole sa oznaci ako chybne).
  function budParse(text){
    var s = String(text == null ? '' : text).trim().replace(/\s/g, '').replace(',', '.');
    if (s === '') return null;
    var f = Number(s);
    return isNaN(f) ? NaN : f;
  }

  function budNumText(v){
    if (v === null || v === undefined || v === '') return '';
    var f = Number(v);
    if (isNaN(f)) return '';
    return (Math.round(f * 1000) / 1000).toString().replace('.', ',');
  }

  // --- render --------------------------------------------------------------

  function budEl(id){ return document.getElementById(id); }

  function budSectionOpen(key){
    if (BUD_OPEN === null){
      // Predvolene otvorene sekcie = mock v4 (materiál, služby, štandardné
      // riadky, vlastné položky, spotrebiče); ABS a kovanie sú zbalené.
      // `cp_merged` = zoznam „Zlúčené v zostave" v sekcii Ponuka. Standardne
      // ZBALENY (vertikalny priestor), ale ked ho pouzivatel raz otvori, ostane
      // otvoreny aj cez prekreslenia po prepnuti „samostatne" (review #8).
      BUD_OPEN = { materials: true, abs: false, hardware: false, services: true,
                   standard_rows: true, custom: true, appliances: true,
                   cp_merged: false };
    }
    return BUD_OPEN[key] !== false;
  }

  function budSub(value, divisor){
    return budFmtEur(budDisplay(value, BUD_VAT, divisor));
  }

  // Payload sekcie. Cita sa VYHRADNE cez tuto funkciu — `ST` je globál okna
  // Studio (studio.js) a v Node testoch neexistuje.
  function budData(){
    if (typeof ST === 'undefined' || !ST) return null;
    return ST;
  }

  function budBudget(){
    var st = budData();
    return (st && st.budget) ? st.budget : null;
  }

  // Aktivna sekcia okna. Rozpocet aj Cenova ponuka citaju TEN ISTY payload —
  // ponuka je jeho zakaznicka PROJEKCIA, nie druhy vypocet.
  function budSec(){
    return (typeof studioSec === 'undefined') ? 'budget' : studioSec;
  }

  // --- kreslenie BEZ fokusu ------------------------------------------------
  // Review PR #198 #5: obnova fokusu patri na JEDNO miesto na prekreslenie.
  // Kym mala kazda z tychto funkcii vlastnu dvojicu capture/restore, jedno
  // prekreslenie sekcie ju spravilo DVAKRAT — a keby prvy restore uzol
  // nenasiel (lista sa prave prepisala), druhy capture uz snimal <body> a
  // rozpisana hodnota v poli by sa stratila. Preto: `budDraw*` LEN kresli,
  // fokus riesia obalky nizsie.

  function budDrawBody(){
    var box = budEl('secbody');
    if (!box) return;
    var b = budBudget();
    if (!b){
      box.innerHTML = '<div class="muted">Rozpočet sa nepodarilo zostaviť (pozri Ruby konzolu).</div>';
      return;
    }
    var d = b.vat_divisor;
    var h = budSummaryHtml(b, d);
    (b.sections || []).forEach(function(sec){
      if (sec.key === 'rounding') h += budRoundingHtml(sec, b, d);
      else h += budSectionHtml(sec, b, d);
    });
    // ŠT-1c PR B2: nahlad cenovej ponuky sa odstahoval do VLASTNEJ sekcie
    // `offer`. Tu ostava len TENKY PREKLIK — zadarmo (jeden riadok) a bez
    // druhej kopie tabulky, ktora by sa casom rozisla.
    h += budCpLinkHtml(b, d);
    box.innerHTML = h;
  }

  function budDrawTools(){
    var box = budEl('sectools');
    if (!box) return;
    box.innerHTML = budToolsHtml(budBudget());
  }

  // TELO sekcie (#secbody). Lista sekcie ma vlastnu funkciu — v Studiu su to
  // dve rozne miesta v DOM (kontrakt §3: akcie sekcie patria do listy).
  // Tieto dve obalky volá studio.js pri plnom renderi okna.
  function budRenderBody(){
    budCaptureFocus();
    budDrawBody();
    budRestoreFocus();
  }

  // LISTA sekcie (#sectools): prepinace DPH a rezimu, prepocet cien, obnovenie,
  // export XLSX a ⚙. Prekresluje sa pri KAZDOM prekresleni tela (rezim aj DPH
  // menia jej stav) a navyse pri fazovom okne prepoctu cien (tlacidlo pocas
  // behu zosedne). Tlacidla nesu `data-bkey`, takze klavesnicovy fokus
  // prekreslenie prezije.
  function budRenderTools(){
    budCaptureFocus();
    budDrawTools();
    budRestoreFocus();
  }

  // Prekreslenie CELEJ aktivnej sekcie (lista + telo) — JEDEN capture na
  // zaciatku, JEDEN restore na konci (review #5). Ked pouzivatel medzitym
  // prepol na sekciu, ktora rozpocet nekresli, nerobi NIC (do cudzieho tela
  // sa nikdy nepise).
  function budRerender(){
    var sec = budSec();
    if (sec !== 'budget' && sec !== 'offer') return;
    budCaptureFocus();
    if (sec === 'offer'){
      budDrawOfferTools();
      budDrawOfferBody();
    } else {
      budDrawTools();
      budDrawBody();
    }
    budRestoreFocus();
  }

  function budSummaryHtml(b, d){
    var t = b.totals || {};
    var total = BUD_VAT ? t.total : t.total_novat; // OBE cisla nesie server
    var h = '<div class="bsum">' +
      '<div><div class="blbl">Spolu za zákazku</div>' +
      '<div class="btotal">' + bEsc(budFmtEur(total)) +
      ' <small>' + (BUD_VAT ? 's DPH' : 'bez DPH') +
      (b.mode_label ? ' · režim ' + bEsc(b.mode_label) : '') + '</small></div></div>';
    h += '<div class="bwarns">';
    budWarnChips(b).forEach(function(c){ h += budChipHtml(c, b, d); });
    h += '</div></div>';
    h += budStaleListHtml(b);
    return h;
  }

  var BUD_MODE_SEG = [['nizky', '€', 'Nízky režim — stáli zákazníci, lepšie ceny'],
                      ['standard', '€€', 'Štandardný režim'],
                      ['vysoky', '€€€', 'Vysoký režim — kde vieme pridať']];

  function budModeSegHtml(b){
    var mode = (b || {}).mode;
    var h = '<div class="bseg bmode" role="group" aria-label="Cenový režim zákazky">';
    BUD_MODE_SEG.forEach(function(m){
      h += '<button type="button" class="' + (mode === m[0] ? 'on' : '') + '"' +
           ' data-bud="mode" data-v="' + m[0] + '" data-bkey="mode:' + m[0] + '"' +
           ' title="' + bEsc(m[2]) + '">' + m[1] + '</button>';
    });
    return h + '</div>';
  }

  // LISTA sekcie — cisty HTML (testuje ju tests/js/test_budget_ui.js).
  // Poradie: prepinace zobrazenia · prepocet a obnovenie · exporty · ⚙.
  // ⚙ OSTAVA (#20) ako KONTEXTOVA skratka: sadzby a prahy rozpocet pocitaju,
  // takze cesta k nim patri sem — polozka navigacie „Nastavenia rozpočtu"
  // otvara TO ISTE okno, len z iného miesta.
  //
  // KAZDE tlacidlo listy nesie `data-bkey` — lista sa prekresluje aj vtedy, ked
  // ju pouzivatel prave ovlada (prepnutie DPH, dobehnutie prepoctu cien), a bez
  // kluca by mu fokus po prekresleni spadol na <body>. Klavesnicova cesta by sa
  // tym prerusila presne v momente, ked na nej zalezi najviac (Tab z „Prepočítať
  // ceny" na export).
  function budToolsHtml(b){
    var running = !!(BUD_PR && BUD_PR.phase === 'run');
    var h = '<div class="bseg" role="group" aria-label="Zobrazenie DPH">' +
      '<button type="button" class="' + (BUD_VAT ? 'on' : '') + '" data-bud="vat" data-v="1"' +
      ' data-bkey="vat:1" title="Ceny s DPH — katalógové ceny sú konečné">s DPH</button>' +
      '<button type="button" class="' + (BUD_VAT ? '' : 'on') + '" data-bud="vat" data-v="0"' +
      ' data-bkey="vat:0" title="Len ZOBRAZENIE bez DPH — rozpočet sa počíta v brutto">bez DPH</button>' +
      '</div>' + budModeSegHtml(b) +
      budPriceBtnHtml(b, running) +
      // Prestavba skrinky z Inspectora sem sama nedorazi — bez „Obnoviť" by sa
      // dal exportovať rozpočet zo starých rozmerov (rovnaký dôvod ako v lište
      // Kusovníka a Nákupu; handler je zdieľaný `#refreshBtn` v studio.js).
      '<button type="button" class="ghostbtn" id="refreshBtn" data-bkey="refresh"' +
      ' title="Prepočítať rozpočet z aktuálneho modelu">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-refresh-cw"/></svg> Obnoviť</button>' +
      '<span class="spacer"></span>' +
      // ŠT-1c PR B2: export „Cenová ponuka (zákazník)" sa PRESUNUL do lišty
      // sekcie Cenová ponuka — patrí k dokumentu, ktorý vyrába. Lišta Rozpočtu
      // tým zároveň schudla o najdlhší popisok (review PR #198 #4: pri šírke
      // okna 1060 px sa lámala do druhého riadku).
      '<button type="button" class="primary" data-bud="xlsx" data-bkey="xlsx"' +
      ' title="Interný rozpočet v presnom formáte tvojich hárkov">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-download"/></svg> XLSX rozpočet</button>' +
      '<button type="button" class="ghostbtn" data-bud="settings" data-bkey="settings"' +
      ' title="Sadzby, režimy a prahy — globálne nastavenie, platí pre každú zákazku">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-settings"/></svg> Nastavenia</button>';
    return h;
  }

  // SMOKE 22.8. (schválené): „Prepočítať ceny" je JANTÁROVÉ, keď zákazka nesie
  // staré ceny — inak neutrálne. Je to ČISTÁ PROJEKCIA payloadu (`b.stale`,
  // ten istý zdroj, z ktorého sa kreslí jantárový chip pri súčte aj zoznam
  // starých riadkov): ŽIADEN nový výpočet a nič sa nikam neposiela.
  // Dôvod: rozpočet vyzeral rovnako s čerstvými aj s polročnými cenami, takže
  // sa dalo objednávať zo starých čísel bez toho, aby to čokoľvek povedalo.
  // ZELENÁ tu vedome NIE JE — významové farby ostávajú semaforu Kontroly.
  // Počas behu prepočtu tlačidlo zošedne (disabled) a jantár sa nekreslí:
  // dve signalizácie naraz by si protirečili.
  function budPriceBtnHtml(b, running){
    var stale = budStaleLabel(b && b.stale);
    var warn = !!stale && !running;
    return '<button type="button" class="ghostbtn' + (warn ? ' bstalebtn' : '') + '"' +
      ' data-bud="refresh" data-bkey="pr"' + (running ? ' disabled' : '') +
      ' title="' + (stale ? bEsc(stale) + ' — ' : '') +
      'Stiahne aktuálne ceny všetkých položiek zákazky viazaných na Demos' +
      ' (medzi položkami je 3 s pauza — pravidlo Demosu)">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-refresh-cw"/></svg> Prepočítať ceny</button>';
  }

  function budChipHtml(c, b, d){
    if (c.id === 'stale'){
      return '<button type="button" class="bchip' + (BUD_STALE_OPEN ? ' open' : '') + '" data-bud="stale">' +
             '<svg class="ic" aria-hidden="true"><use href="#i-chevron-right"/></svg> ' + bEsc(c.text) + '</button>';
    }
    if (c.id === 'appl'){
      var amt = bEsc(budFmtEur(budDisplay(c.amount, BUD_VAT, d)));
      var txt = c.included ? ('Spotrebiče (' + amt + ') sú započítané v SPOLU')
                           : ('Spotrebiče (' + amt + ') NIE SÚ v súčte — platia sa osobitne?');
      return '<button type="button" class="bchip" data-bud="goto" data-section="appliances"' +
             ' title="Prejdi na sekciu Spotrebiče">' + txt + '</button>';
    }
    // ŠT-1c PR B1: rozpoctove upozornenia su TIE ISTE nalezy, ake ukazuje
    // sekcia KONTROLA toho isteho okna — chip preto VEDIE TAM namiesto toho,
    // aby pod sebou rozbalil DRUHU kopiu zoznamu (jedna pravda, jedno miesto).
    return '<button type="button" class="bchip" data-bud="ctrl"' +
           ' title="Ten istý nález ako v Kontrole — klik prejde na jeho zoznam">' +
           '<svg class="ic" aria-hidden="true"><use href="#i-alert"/></svg> ' + bEsc(c.text) + '</button>';
  }

  function budStaleListHtml(b){
    if (!BUD_STALE_OPEN) return '';
    var items = (b.stale && b.stale.items) || [];
    if (!items.length) return '';
    var h = '<div class="blist">';
    items.forEach(function(it){
      var age = it.state === 'stale' ? ('overené pred ' + it.age_days + ' dňami')
              : (it.state === 'unverified' ? 'cena nikdy neoverená' : 'ručná položka');
      // Akcia/poznámka je SÚRODENEC veku, nie jeho súčasť — .bage je nowrap
      // (dátum sa nesmie zalomiť), dôvod „bez väzby" sa zalomiť SMIE.
      h += '<div><span>' + bEsc(it.label) + '</span><span class="bage">' + bEsc(age) + '</span>' +
           budStaleActionHtml(it) + '</div>';
    });
    return h + '</div>';
  }

  // E-c: VIAZANÝ riadok (má demos_url) dostane mini akciu „obnoviť túto" —
  // ide TOU ISTOU cestou ako hromadný prepočet, len s jednou položkou.
  // Riadok BEZ väzby sa nefetchuje NIKDY (server ho ani nedostane) — len
  // povie, čo s ním: over cenu v katalógu ručne.
  function budStaleActionHtml(it){
    var i = it || {};
    if (!i.demos_url) return ' <span class="bprwhy">· bez Demos väzby — over v katalógu ručne</span>';
    return ' <button type="button" class="bact" data-bud="refresh_one" data-kind="' + bEsc(i.kind) +
      '" data-id="' + bEsc(i.id) + '" data-label="' + bEsc(i.label) +
      '" title="Obnoviť cenu tejto položky z Demosu" aria-label="Obnoviť túto cenu">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-refresh-cw"/></svg></button>';
  }

  // ŠT-1c PR B1: `budWarnListHtml` ZANIKOL — bola to druha kopia zoznamu
  // nalezov, ktory od ŠT-1b zije v sekcii KONTROLA toho isteho okna. Chip
  // vyssie tam vedie a Kontrola naopak vie preklikom otvorit prislusnu sekciu
  // rozpoctu (`budget_section` v naleze).

  // --- sekcie --------------------------------------------------------------

  var BUD_SECTION_NOTE = {
    services: 'Riadky vznikajú SAMÉ z dát zákazky. Prečiarknutý = automatický výpočet, ✎ = ručný prepis. ' +
              'Sadzby žijú v ⚙ Nastaveniach; nulový riadok ostáva ako kontrola.',
    standard_rows: 'Násobok = tvoj koeficient veľkosti zákazky. Sadzby per REŽIM (€ / €€ / €€€ hore) — ' +
                   'režim predvyplní, všetko sa dá prepísať.',
    custom: 'Popis + cena stačia (kód, URL a poznámka cez ⋯). Riadok bez ceny sa nezapočíta a svieti ' +
            'v upozornení hore aj v KONTROLE. Ukladá sa do zákazky (.skp).',
    appliances: 'Sekcia je POSLEDNÁ a do súčtu vstupuje LEN so zapnutým „sčítať do rozpočtu" — spotrebiče ' +
                'často nie sú v ponuke alebo sa platia osobitne. Vyplnené a nezapočítané = oranžové ' +
                'upozornenie hore (nikdy neblokuje).'
  };

  function budSectionCount(sec, b){
    var n = (sec.rows || []).length;
    var base = n + ' ' + budPluralSk(n, ['položka', 'položky', 'položiek']);
    if (sec.key === 'standard_rows') return base + ' · režim ' + (b.mode_label || '');
    if (sec.key === 'custom') return 'len táto zákazka';
    if (sec.key === 'appliances') return 'manuálne · katalóg príde v S1';
    return base;
  }

  function budSectionHtml(sec, b, d){
    var open = budSectionOpen(sec.key);
    var off = (sec.counts_in_total === false);
    var h = '<details class="bsec" data-section="' + bEsc(sec.key) + '"' + (open ? ' open' : '') + '>' +
      '<summary><h3>' + bEsc(sec.name) + '</h3>' +
      '<span class="bcnt">' + bEsc(budSectionCount(sec, b)) + '</span>';
    if (sec.key === 'appliances'){
      // Prepinac zije v <summary> (mock v4) — bez stopPropagation by klik na
      // checkbox ZAROVEN zbalil sekciu. Inline handler BEZ dat (konvencia repa);
      // delegovany listener na document by bezal az po default akcii summary.
      h += '<label class="bappl" onclick="event.stopPropagation()">' +
           '<input type="checkbox" data-bud="appl_included"' +
           (sec.included ? ' checked' : '') + '> sčítať do rozpočtu</label>';
    }
    h += '<span class="bsubt' + (off ? ' off' : '') + '">' + bEsc(budSub(sec.subtotal, d)) + '</span></summary>';
    h += budTableHtml(sec, b, d);
    // ŠT-1c PR B2 (Š13): „pridávačky" su od tejto davky D-15 MODAL — inline
    // draft v tele sekcie zanikol. Tlacidlo ostava presne tam, kde bolo.
    if (sec.key === 'custom'){
      h += '<button type="button" class="baddbig" data-bud="draft" data-kind="custom"' +
        ' data-bkey="add:custom">' +
        '<svg class="ic" aria-hidden="true"><use href="#i-plus"/></svg> Pridať položku</button>';
    }
    if (sec.key === 'appliances'){
      h += '<button type="button" class="baddbig" data-bud="draft" data-kind="appliance"' +
        ' data-bkey="add:appliance">' +
        '<svg class="ic" aria-hidden="true"><use href="#i-plus"/></svg> Pridať spotrebič</button>';
    }
    if (BUD_SECTION_NOTE[sec.key]) h += '<div class="bnote">' + bEsc(BUD_SECTION_NOTE[sec.key]) + '</div>';
    return h + '</details>';
  }

  function budTableHtml(sec, b, d){
    var rows = sec.rows || [];
    if (!rows.length) return '<div class="muted" style="padding:6px 12px">Zatiaľ prázdne.</div>';
    var head, body = '';
    switch (sec.key){
      case 'materials':
        head = ['Materiál', 'Množstvo', 'MJ', '€ / MJ', 'Overená', 'Medzisúčet'];
        rows.forEach(function(r){ body += budMaterialRow(r, b, d); });
        break;
      case 'abs':
        head = ['Páska', 'Dĺžka s rezervou', 'MJ', '€ / bm', 'Overená', 'Medzisúčet'];
        rows.forEach(function(r){ body += budSimpleRow(r, b, d); });
        break;
      case 'hardware':
        head = ['Kód', 'Názov', 'Počet', 'MJ', '€ / MJ', 'Medzisúčet'];
        rows.forEach(function(r){ body += budHardwareRow(r, d); });
        break;
      case 'services':
        head = ['Položka', 'Výpočet', 'Medzisúčet'];
        rows.forEach(function(r){ body += budServiceRow(r, d); });
        break;
      case 'standard_rows':
        head = ['Položka', 'Násobok', 'Sadzba', 'Medzisúčet'];
        rows.forEach(function(r){ body += budStandardRow(r, b, d); });
        break;
      case 'custom':
        head = ['Popis', 'Počet', '€ / j.', '', 'Medzisúčet'];
        rows.forEach(function(r){ body += budCustomRow(r, d); });
        break;
      case 'appliances':
        head = ['Typ', 'Názov', 'Dodávateľ', 'Cena', '', 'Medzisúčet'];
        rows.forEach(function(r){ body += budApplianceRow(r, d); });
        break;
      default:
        head = ['Položka', 'Medzisúčet'];
        rows.forEach(function(r){
          body += '<tr><td>' + bEsc(r.nazov) + '</td><td class="bnum">' + bEsc(budSub(r.spolu, d)) + '</td></tr>';
        });
    }
    var h = '<table class="btab"><thead><tr>';
    head.forEach(function(c, i){ h += '<th' + (i ? ' class="bnum"' : '') + '>' + bEsc(c) + '</th>'; });
    return h + '</tr></thead><tbody>' + body + '</tbody></table>';
  }

  function budRowClass(r){
    var cls = [];
    if (r.price_missing) cls.push('bmiss');
    else if (!r.spolu) cls.push('bzero');
    return cls.length ? ' class="' + cls.join(' ') + '"' : '';
  }

  function budPriceCell(r, d){
    if (r.price_missing) return '<td class="bnum bmisslbl">chýba cena</td>';
    return '<td class="bnum">' + bEsc(budSub(r.cena_mj, d)) + '</td>';
  }

  function budNoteHtml(r){
    var n = (r.poznamka || '').toString();
    return n ? ' <span class="bfnt">· ' + bEsc(n) + '</span>' : '';
  }

  function budMaterialRow(r, b, d){
    var fresh = budFreshCell(r.material_id, 'sheet', b);
    var perM2 = (r.price_per_m2 != null)
      ? ' <span class="bfnt">(' + bEsc(budFmtEur(budDisplay(r.price_per_m2, BUD_VAT, d))) + '/m²)</span>' : '';
    return '<tr' + budRowClass(r) + '><td>' + bEsc(r.nazov) + budNoteHtml(r) + '</td>' +
      '<td class="bnum">' + bEsc(budFmtNum(r.mnozstvo, 0)) + '</td>' +
      '<td class="bnum">' + bEsc(r.mj) + '</td>' +
      '<td class="bnum">' + (r.price_missing ? '<span class="bmisslbl">chýba cena</span>'
        : bEsc(budSub(r.cena_mj, d)) + perM2) + '</td>' +
      '<td class="bnum">' + fresh + '</td>' +
      '<td class="bnum">' + bEsc(budSub(r.spolu, d)) + '</td></tr>';
  }

  // Vek ceny per riadok — stav aj vek počíta SERVER (stale.items), tu sa len
  // páruje podľa identity záznamu.
  function budFreshCell(id, kind, b){
    var items = (b.stale && b.stale.items) || [];
    for (var i = 0; i < items.length; i++){
      if (items[i].kind !== kind || items[i].id !== id) continue;
      if (items[i].state === 'stale'){
        return '<span class="bold-price" title="Cena je staršia než prah v Nastaveniach">' +
               bEsc(items[i].age_days + ' dní') + '</span>';
      }
      if (items[i].state === 'unverified') return '<span class="bfnt" title="Cena nebola nikdy overená">?</span>';
      return '<span class="bfnt">—</span>';
    }
    return '<span class="bfnt">—</span>';
  }

  function budSimpleRow(r, b, d){
    return '<tr' + budRowClass(r) + '><td>' + bEsc(r.nazov) + budNoteHtml(r) + '</td>' +
      '<td class="bnum">' + bEsc(budFmtNum(r.mnozstvo, 1)) + '</td>' +
      '<td class="bnum">' + bEsc(r.mj) + '</td>' +
      budPriceCell(r, d) +
      '<td class="bnum">' + budFreshCell(r.abs_id, 'edge', b) + '</td>' +
      '<td class="bnum">' + bEsc(budSub(r.spolu, d)) + '</td></tr>';
  }

  function budHardwareRow(r, d){
    return '<tr' + budRowClass(r) + '><td class="bmut">' + bEsc(r.kod) + '</td>' +
      '<td>' + bEsc(r.nazov) + budNoteHtml(r) + '</td>' +
      '<td class="bnum">' + bEsc(budFmtNum(r.mnozstvo, 0)) + '</td>' +
      '<td class="bnum">' + bEsc(r.mj) + '</td>' +
      budPriceCell(r, d) +
      '<td class="bnum">' + bEsc(budSub(r.spolu, d)) + '</td></tr>';
  }

  // Automaticka sluzba: vypocet vlavo, vpravo EDITOVATELNA suma. Prepis
  // (override) sa ukaze precarknutym automatom + ceruzkou; prazdne pole = navrat
  // na automaticky vypocet.
  function budOverrideCell(r, d){
    var over = r.zdroj === 'override';
    var auto = over ? '<span class="bstrike">' + bEsc(budSub(r.spolu_auto, d)) + '</span>' : '';
    // Prepis sa zadava VZDY v brutto (server pocita v brutto) — v rezime
    // "bez DPH" je pole preto len na citanie, aby sa cislo neulozilo /1,23.
    if (!BUD_VAT){
      return '<td class="bnum">' + auto + bEsc(budSub(r.spolu, d)) +
             (over ? ' <svg class="ic bpen" aria-hidden="true"><use href="#i-pencil"/></svg>' : '') +
             '<div class="bfnt">prepis len v režime s DPH</div></td>';
    }
    return '<td class="bnum">' + auto +
      '<input class="bedit" type="text" data-bud="override" data-key="' + bEsc(r.key) + '"' +
      ' data-bkey="ov:' + bEsc(r.key) + '" value="' + bEsc(budNumText(r.spolu)) + '"' +
      ' title="Ručný prepis sumy — prázdne pole vráti automatický výpočet" aria-label="Suma riadku">' +
      (over ? ' <svg class="ic bpen" aria-hidden="true"><use href="#i-pencil"/></svg>' : '') + '</td>';
  }

  function budServiceRow(r, d){
    var calc = budFmtNum(r.mnozstvo, 2) + ' ' + bEsc(r.mj) + ' × ' +
               bEsc(budSub(r.cena_mj, d)) + (r.poznamka ? ' <span class="bfnt">· ' + bEsc(r.poznamka) + '</span>' : '');
    return '<tr' + budRowClass(r) + '><td>' + bEsc(r.nazov) + '</td>' +
      '<td class="bnum bmut">' + calc + '</td>' + budOverrideCell(r, d) + '</tr>';
  }

  function budStandardRow(r, b, d){
    var mult;
    if (r.kind === 'per_m2'){
      mult = '<input class="bedit bshort" type="text" data-bud="viz_m2" data-bkey="viz"' +
        ' value="' + bEsc(budNumText(b.viz_m2)) + '" title="m² z meračky — ručný vstup"' +
        ' aria-label="m² z meračky"> <span class="bfnt">m² ×</span> ';
    } else {
      mult = '';
    }
    mult += '<input class="bedit bshort" type="text" data-bud="multiplier" data-key="' + bEsc(r.key) + '"' +
      ' data-bkey="mult:' + bEsc(r.key) + '" value="' + bEsc(budNumText(r.multiplier)) + '"' +
      ' title="Násobok — koeficient veľkosti zákazky (prázdne = predvolený)" aria-label="Násobok">';
    return '<tr' + budRowClass(r) + '><td>' + bEsc(r.nazov) + budNoteHtml(r) + '</td>' +
      '<td class="bnum bmcell">' + mult + '</td>' +
      '<td class="bnum bmut">' + bEsc(budSub(r.rate, d)) + '</td>' +
      budOverrideCell(r, d) + '</tr>';
  }

  function budActionsCell(kind, r){
    var h = '<td class="bnum bacts">';
    if (r.url){
      h += '<button type="button" class="bact" data-bud="url" data-kind="' + kind + '" data-id="' + bEsc(r.id) + '"' +
           ' title="Otvoriť adresu v prehliadači" aria-label="Otvoriť adresu">' +
           '<svg class="ic" aria-hidden="true"><use href="#i-external-link"/></svg></button>';
    }
    h += '<button type="button" class="bact" data-bud="more" data-kind="' + kind + '" data-id="' + bEsc(r.id) + '"' +
         ' title="Kód, adresa, poznámka…" aria-label="Ďalšie údaje">' +
         '<svg class="ic" aria-hidden="true"><use href="#i-more-horizontal"/></svg></button>';
    h += '<button type="button" class="bact bdel" data-bud="remove" data-kind="' + kind + '" data-id="' + bEsc(r.id) + '"' +
         ' title="Zmazať riadok" aria-label="Zmazať riadok">' +
         '<svg class="ic" aria-hidden="true"><use href="#i-x"/></svg></button></td>';
    return h;
  }

  function budCustomRow(r, d){
    var miss = r.missing_name ? ' <span class="bmisslbl">chýba popis</span>' : '';
    return '<tr' + budRowClass(r) + '>' +
      '<td><input class="bedit bwide" type="text" data-bud="custom_field" data-field="popis" data-id="' + bEsc(r.id) + '"' +
      ' data-bkey="c:popis:' + bEsc(r.id) + '" value="' + bEsc(r.nazov) + '" placeholder="Popis položky…"' +
      ' aria-label="Popis">' + miss + budNoteHtml(r) + '</td>' +
      '<td class="bnum"><input class="bedit bshort" type="text" data-bud="custom_field" data-field="pocet"' +
      ' data-id="' + bEsc(r.id) + '" data-bkey="c:pocet:' + bEsc(r.id) + '" value="' + bEsc(budNumText(r.mnozstvo)) + '"' +
      ' aria-label="Počet"></td>' +
      '<td class="bnum"><input class="bedit bshort" type="text" data-bud="custom_field" data-field="cena"' +
      ' data-id="' + bEsc(r.id) + '" data-bkey="c:cena:' + bEsc(r.id) + '" value="' + bEsc(budNumText(r.cena_mj)) + '"' +
      ' placeholder="0,00" aria-label="Cena"></td>' +
      budActionsCell('custom', r) +
      '<td class="bnum">' + bEsc(budSub(r.spolu, d)) + '</td></tr>';
  }

  var BUD_APPL_TYPES = [['chladnicka', 'Chladnička'], ['rura', 'Rúra'], ['mikrovlnka', 'Mikrovlnka'],
                        ['umyvacka', 'Umývačka'], ['digestor', 'Digestor'], ['varna_doska', 'Varná doska'],
                        ['ine', 'Iné']];

  function budTypeSelect(attrs, current){
    var h = '<select class="bedit" ' + attrs + ' aria-label="Typ spotrebiča">';
    BUD_APPL_TYPES.forEach(function(t){
      h += '<option value="' + t[0] + '"' + (t[0] === current ? ' selected' : '') + '>' + bEsc(t[1]) + '</option>';
    });
    return h + '</select>';
  }

  function budApplianceRow(r, d){
    var base = ' data-bud="appl_field" data-id="' + bEsc(r.id) + '"';
    return '<tr' + budRowClass(r) + '>' +
      '<td>' + budTypeSelect(base + ' data-field="typ" data-bkey="a:typ:' + bEsc(r.id) + '"', r.typ) + '</td>' +
      '<td><input class="bedit bwide" type="text"' + base + ' data-field="nazov" data-bkey="a:nazov:' + bEsc(r.id) + '"' +
      ' value="' + bEsc(r.nazov) + '" placeholder="Názov / model…" aria-label="Názov"></td>' +
      '<td><input class="bedit" type="text"' + base + ' data-field="dodavatel" data-bkey="a:dod:' + bEsc(r.id) + '"' +
      ' value="' + bEsc(r.dodavatel || '') + '" placeholder="Dodávateľ" aria-label="Dodávateľ"></td>' +
      '<td class="bnum"><input class="bedit bshort" type="text"' + base + ' data-field="cena"' +
      ' data-bkey="a:cena:' + bEsc(r.id) + '" value="' + bEsc(budNumText(r.cena_mj)) + '" placeholder="0,00"' +
      ' aria-label="Cena"></td>' +
      budActionsCell('appliance', r) +
      '<td class="bnum">' + bEsc(budSub(r.spolu, d)) + '</td></tr>';
  }

  // --- D-15 modal „pridávačky" (ŠT-1c PR B2) --------------------------------
  // Kostru kresli ZDIELANY komponent `js/nx_modal.js` (titulok · polia ·
  // zelene potvrdenie · Esc/klik vedla · fokus v prvom poli) — tu su LEN
  // polia. Su to TIE ISTE polia, ake mal inline draft, vratane defaultov
  // (`budDraftAttrs`) a serverovej validacie (klient stráži iba povinne pole).
  //
  // CISTE (testuje tests/js/test_st1c_ponuka.js): kind + zapamatane hodnoty
  // -> zoznam poli. Ziadny DOM.
  function budDraftFields(kind, values){
    var v = values || {};
    if (kind === 'custom'){
      return [
        { key: 'popis', label: 'Popis', value: v.popis, placeholder: 'napr. Likvidácia starej kuchyne' },
        { key: 'pocet', label: 'Počet', value: (v.pocet == null || v.pocet === '') ? '1' : v.pocet,
          cls: 'mshort' },
        { key: 'cena', label: 'Cena / j.', value: v.cena, placeholder: '0,00', cls: 'mshort' }
      ];
    }
    return [
      { key: 'typ', label: 'Typ', type: 'select', value: v.typ || 'chladnicka', options: BUD_APPL_TYPES },
      { key: 'nazov', label: 'Názov / model', value: v.nazov, placeholder: 'napr. Bosch SMV4HVX00E' },
      { key: 'dodavatel', label: 'Dodávateľ', value: v.dodavatel, placeholder: 'nepovinné' },
      { key: 'cena', label: 'Cena', value: v.cena, placeholder: '0,00', cls: 'mshort' }
    ];
  }

  var BUD_DRAFT_META = {
    custom: { title: 'Pridať položku rozpočtu', sub: 'len táto zákazka · uloží sa do .skp',
              note: 'Riadok bez ceny sa nezapočíta a svieti v upozornení hore aj v KONTROLE. ' +
                    'Kód, adresu a poznámku doplníš potom cez ⋯ v riadku.' },
    appliance: { title: 'Pridať spotrebič', sub: 'sekcia Spotrebiče · do súčtu vstupuje len so „sčítať do rozpočtu"',
                 note: 'Spotrebiče sa často platia osobitne — preto má sekcia vlastný prepínač ' +
                       'a nezapočítaná suma svieti oranžovo hore.' }
  };

  // Zapamatane hodnoty tej istej pridavacky (null = este sa nic nepisalo).
  function budDraftMemory(kind){
    return BUD_DRAFT_VALUES[kind] || null;
  }

  // Otvorenie modalu. Polia sa predvyplnia tym, co v tejto pridavacke naposledy
  // ostalo nedokoncene — ci uz preto, ze server zapis ODMIETOL (audit #10),
  // alebo preto, ze pouzivatel okno zavrel Escapom (review #3+#4).
  function budOpenDraft(kind){
    if (typeof window === 'undefined' || !window.NXModal) return;
    var meta = BUD_DRAFT_META[kind];
    if (!meta) return;
    BUD_DRAFT = kind;
    NXModal.open({
      title: meta.title, sub: meta.sub, note: meta.note, okLabel: 'Pridať',
      fields: budDraftFields(kind, budDraftMemory(kind)),
      onSubmit: function(v){ budDraftCommit(kind, v); }
    });
  }

  // Zatvorenie PO USPESNOM zapise — riadok uz v rozpocte je, takze pamat
  // rozpisanych hodnot sa zahadzuje (inak by sa pri dalsom „Pridať položku"
  // predvyplnila polozka, ktora uz existuje).
  function budCloseDraft(){
    if (BUD_DRAFT) BUD_DRAFT_VALUES[BUD_DRAFT] = null;
    BUD_DRAFT = null;
    if (typeof window !== 'undefined' && window.NXModal) NXModal.close();
  }

  // Odomknutie potvrdzovacieho tlacidla po odmietnutom zapise (review #2).
  function budUnlockDraft(){
    if (typeof window !== 'undefined' && window.NXModal) NXModal.setBusy(false);
  }

  function budRoundingHtml(sec, b, d){
    var t = b.totals || {};
    var row = (sec.rows || [])[0] || {};
    // total/total_novat su HOTOVE cisla zo servera — uz sa neprepocitavaju.
    var total = budFmtEur(BUD_VAT ? t.total : t.total_novat);
    return '<div class="broundrow"><span>Zaokrúhlenie ponuky <span class="bfnt">(' +
      bEsc(row.poznamka || '') + ')</span></span><span class="bsubt">' +
      bEsc(budSub(t.rounding, d)) + ' → ' + bEsc(total) + '</span></div>';
  }

  // ============ SEKCIA CENOVA PONUKA (ŠT-1c PR B2, Š14–Š15) ================
  // Do ŠT-1c to bol zbalitelny NAHLAD vnutri Rozpoctu (E-b2); od tejto davky
  // je to VLASTNA sekcia `offer` okna Studio.
  //
  // CP je VIEW nad rozpoctom: vsetky riadky, sumy aj navrhy pocita SERVER
  // (payload.cp_preview). JS ich LEN zobrazuje a posiela prepnutie zaradenia.
  // Riadok „Nábytková zostava" je automaticky zvysok — dorovnanie nikdy nerobi
  // pouzivatel a nikdy sa nezabudne. ZELEZNE PRAVIDLO platí aj tu: ziadna suma
  // sa v prehliadaci nepocita.
  //
  // Š15 „upravuj pri zdroji": ponuka sa needituje — chybajuca cena je jantarovy
  // guard s preklikom do ROZPOCTU (ponuka sa nikdy potichu nepodhodnoti).

  // Ciste: kontrolny pas CP vs rozpocet. `consistent` pocita server; keby sa
  // niekedy rozisli, pas to povie nahlas namiesto ticheho rozdielu.
  function budCpBand(cp){
    var c = cp || {};
    if (c.consistent === false){
      return { ok: false, text: 'CP nesedí s rozpočtom o ' + budFmtEur(c.diff) };
    }
    if (c.assembly_negative){
      return { ok: false, text: 'Samostatné riadky prevyšujú rozpočet — zostava je záporná' };
    }
    // GH #139 P1: riadok bez ceny do súčtu nevstupuje — ponuka by bola
    // podhodnotená, hoci položka v špecifikácii ostáva. Počet ráta server.
    if (c.complete === false){
      return { ok: false, text: 'Suma ponuky je podhodnotená — ' + (c.unknown_count || 0) + ' ' +
                                budPluralSk(c.unknown_count || 0,
                                  ['riadok rozpočtu nemá cenu', 'riadky rozpočtu nemajú cenu',
                                   'riadkov rozpočtu nemá cenu']) };
    }
    return { ok: true, text: 'CP = Rozpočet' };
  }

  // TENKY PREKLIK v tele Rozpoctu (Š15). Ziadna druha kopia tabulky — len
  // riadok, ktory povie sumu ponuky a otvori jej sekciu.
  function budCpLinkHtml(b, d){
    var cp = b ? b.cp_preview : null;
    if (!cp) return '';
    var band = budCpBand(cp);
    return '<button type="button" class="bcplink' + (band.ok ? '' : ' warn') + '" data-bud="offer"' +
      ' data-bkey="offer" title="Zákaznícky pohľad na ten istý rozpočet — položky rečou zákazníka">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-file-text"/></svg>' +
      '<span>Cenová ponuka</span>' +
      '<span class="bfnt">' + bEsc(band.ok ? 'sedí s rozpočtom' : band.text) + '</span>' +
      '<span class="bsubt">' + bEsc(budSub(cp.total, d)) + '</span>' +
      '<span class="bcpgo" aria-hidden="true">→</span></button>';
  }

  // LISTA sekcie Cenová ponuka: export zakazníckeho dokumentu + Obnoviť.
  // Prepínač DPH tu ZAMERNE nie je — ponuka je projekcia rozpočtu a prepínať
  // to isté číslo na dvoch miestach by bolo mätúce; v akom režime sa práve
  // zobrazuje, priznáva `<small>` pri sume.
  function budOfferToolsHtml(){
    // Popisok je ZAMERNE ten isty, aky mal v mockupe aj v lište Rozpočtu
    // („Cenová ponuka (zákazník)") — je to to isté tlačidlo, len sa presťahovalo
    // k dokumentu, ktorý vyrába; premenovať ho by znamenalo, že si používateľ
    // hľadá nový ovládač namiesto známeho.
    return '<button type="button" class="primary" data-bud="cp" data-bkey="cp"' +
      ' title="Zákaznícky dokument: cenová tabuľka + špecifikácia (bez interných pojmov a kódov)">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-download"/></svg> Cenová ponuka (zákazník)</button>' +
      // Prestavba skrinky z Inspectora sem sama nedorazí — bez „Obnoviť" by sa
      // dala poslať zákazníkovi ponuka zo starých rozmerov (rovnaký dôvod ako
      // v lište Kusovníka, Nákupu aj Rozpočtu; handler je zdieľaný `#refreshBtn`).
      '<button type="button" class="ghostbtn" id="refreshBtn" data-bkey="refresh"' +
      ' title="Prepočítať ponuku z aktuálneho modelu">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-refresh-cw"/></svg> Obnoviť</button>' +
      '<span class="spacer"></span>' +
      // Text je doslovne z kontraktu UI 2.0 (Š14–Š15) — hovorí OBE veci naraz:
      // odkiaľ suma je a že podhodnotenie nie je tiché.
      '<span class="sechint">Súčet preberá z Rozpočtu — riadok bez ceny do ponuky ' +
      'nevstúpi potichu.</span>';
  }

  function budDrawOfferTools(){
    var box = budEl('sectools');
    if (!box) return;
    box.innerHTML = budOfferToolsHtml();
  }

  function budDrawOfferBody(){
    var box = budEl('secbody');
    if (!box) return;
    var b = budBudget();
    box.innerHTML = budOfferHtml(b, b ? b.vat_divisor : null);
  }

  function budRenderOfferTools(){
    budCaptureFocus();
    budDrawOfferTools();
    budRestoreFocus();
  }

  function budRenderOfferBody(){
    budCaptureFocus();
    budDrawOfferBody();
    budRestoreFocus();
  }

  // TELO sekcie `offer`. Poradie podla mockupu: sucet z Rozpoctu (+ guard) ·
  // polozky dokumentu · zlucene v zostave · zaokruhlenie · placeholder DOCX/PDF.
  function budOfferHtml(b, d){
    var cp = b ? b.cp_preview : null;
    if (!cp){
      return '<div class="muted">Cenová ponuka sa nepodarilo zostaviť — otvor sekciu Rozpočet ' +
             '(bez rozpočtu nie je z čoho robiť ponuku).</div>';
    }
    var band = budCpBand(cp);
    // Review #1: varovny pas patri AJ SEM. Export zakazníckeho dokumentu je od
    // tejto davky JEDINE v tejto sekcii — keby tu chipy neboli, dala by sa
    // ponuka poslat zakaznikovi zo starych cien alebo s nedoriesenymi nalezmi
    // bez toho, aby o tom okno cokolvek povedalo. Su to TIE ISTE chipy ako
    // v Rozpocte (`budWarnChips` = jedno miesto, jedno cislo) — lisia sa LEN
    // klikom: v ponuke sa nic needituje, takze KAZDY vedie tam, kde sa to rieši.
    var h = '<div class="bsum">' +
      '<div><div class="blbl">Suma ponuky</div>' +
      '<div class="btotal">' + bEsc(budSub(cp.total, d)) +
      ' <small>' + (BUD_VAT ? 's DPH' : 'bez DPH') + ' · z Rozpočtu</small></div></div>' +
      '<div class="bwarns">' + budOfferGuardHtml(band);
    budWarnChips(b).forEach(function(c){ h += budOfferChipHtml(c, b, d); });
    h += '</div></div>';
    h += '<div class="subhead">Položky dokumentu (rečou zákazníka)</div>';
    h += budCpTableHtml(cp, d);
    h += budCpMergedHtml(cp, d);
    h += budOfferRoundingHtml(b, d);
    h += '<div class="bnote">Zákaznícky pohľad na ten istý rozpočet — suma sa nikdy nelíši. ' +
      'Zameranie a Vizualizácie sú v ponuke vždy 0 € (náklad je rozpustený v zostave). ' +
      'Významné položky vieš dať samostatne, ostatné sa zlúčia do nábytkovej zostavy ' +
      '(hranica je ' + bEsc(budFmtEur(cp.threshold)) + '). Export je vždy s DPH (ceny sú konečné).</div>';
    h += budOfferWireHtml();
    return h;
  }

  // Chip varovného pásu v PONUKE. Text aj počty su tie iste, co v Rozpocte
  // (`budWarnChips` — server ich sklada raz); ZMENENY je LEN cieľ kliku, lebo
  // v ponuke sa needituje nic (Š15 „upravuj pri zdroji"):
  //   · staré ceny  -> Rozpočet (tam je „Prepočítať ceny" aj zoznam riadkov),
  //   · spotrebiče  -> Rozpočet, rovno na ich sekciu,
  //   · upozornenia -> Kontrola (to isté miesto ako z Rozpočtu — jeden zoznam).
  function budOfferChipHtml(c, b, d){
    if (c.id === 'stale'){
      return '<button type="button" class="bchip" data-bud="to_budget" data-bkey="ostale"' +
        ' title="Staré ceny sa obnovujú v Rozpočte tlačidlom „Prepočítať ceny" —' +
        ' ponuka by inak išla zákazníkovi z neaktuálnych cien.">' +
        '<svg class="ic" aria-hidden="true"><use href="#i-alert"/></svg> ' + bEsc(c.text) + '</button>';
    }
    if (c.id === 'appl'){
      var amt = bEsc(budFmtEur(budDisplay(c.amount, BUD_VAT, d)));
      var txt = c.included ? ('Spotrebiče (' + amt + ') sú započítané v SPOLU')
                           : ('Spotrebiče (' + amt + ') NIE SÚ v súčte — platia sa osobitne?');
      return '<button type="button" class="bchip" data-bud="to_budget" data-section="appliances"' +
        ' data-bkey="oappl" title="Prejdi na sekciu Spotrebiče v Rozpočte">' + txt + '</button>';
    }
    return '<button type="button" class="bchip" data-bud="ctrl" data-bkey="octrl"' +
      ' title="Ten istý nález ako v Kontrole — klik prejde na jeho zoznam">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-alert"/></svg> ' + bEsc(c.text) + '</button>';
  }

  // Š15: podhodnotená ponuka NIE JE tichá — jantárový chip s preklikom do
  // Rozpočtu (tam sa cena aj dopĺňa; ponuka sa needituje).
  function budOfferGuardHtml(band){
    if (band.ok){
      return '<span class="bcpband ok"><svg class="ic" aria-hidden="true"><use href="#i-check"/></svg> ' +
             bEsc(band.text) + '</span>';
    }
    return '<button type="button" class="bchip" data-bud="to_budget" data-bkey="tobud"' +
      ' title="Chýbajúca cena sa dopĺňa v Rozpočte — klik prejde tam (Š15: upravuj pri zdroji).">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-alert"/></svg> ' + bEsc(band.text) + '</button>';
  }

  // Zaokruhlenie je SERVEROVE cislo zo sekcie `rounding` rozpoctu; v ponuke je
  // to riadok dokumentu („Zaokrúhlenie ponuky"), v Rozpocte vysvetluje, ako sa
  // sucet stal konecnou sumou. JEDNO cislo v dvoch uloha, nie dve pravdy.
  function budOfferRoundingHtml(b, d){
    var sec = ((b || {}).sections || []).filter(function(s){ return s.key === 'rounding'; })[0];
    if (!sec) return '';
    return budRoundingHtml(sec, b, d);
  }

  // Priznany WIREFRAME (Š14): generator dokumentu je vedome odlozeny za V1 —
  // sekcia s nim pocita, ale nesmie predstierat, ze uz existuje (D-78: ziadne
  // mrtve tlacidlo bez dovodu).
  function budOfferWireHtml(){
    return '<div class="bwire"><span class="wtag">po V1 — vedomý placeholder</span>' +
      '<h3>Dokument ponuky (DOCX / PDF)</h3>' +
      '<p>Šablóna s logom, platnosťou, poznámkou a vizualizáciami. Plný generátor je vedome ' +
      'odložený (PLAN, blok V1) — dnes je výstupom XLSX z lišty hore.</p></div>';
  }

  function budCpTableHtml(cp, d){
    var rows = cp.rows || [];
    if (!rows.length) return '<div class="muted" style="padding:6px 12px">Zatiaľ prázdne.</div>';
    var h = '<table class="btab flat"><thead><tr><th>Položka</th><th class="bnum">Cena</th>' +
      '<th class="bnum">Množstvo</th><th class="bnum">MJ</th><th>V ponuke</th></tr></thead><tbody>';
    rows.forEach(function(r){
      h += '<tr class="' + (r.kind === 'assembly' ? 'bcpasm' : '') + '"><td>' + bEsc(r.polozka) + '</td>' +
        '<td class="bnum">' + bEsc(budSub(r.cena, d)) + '</td>' +
        '<td class="bnum">' + bEsc(budFmtNum(r.mnozstvo, 0)) + '</td>' +
        '<td class="bnum">' + bEsc(r.mj) + '</td>' +
        '<td>' + budCpSepHtml(r.source_key, true) + '</td></tr>';
    });
    h += '<tr class="bcptotal"><td>' + bEsc(cp.total_label || 'SPOLU') + '</td>' +
      '<td class="bnum">' + bEsc(budSub(cp.total, d)) + '</td><td></td><td></td><td></td></tr>';
    return h + '</tbody></table>';
  }

  // Š14: per-riadok prepinac „samostatne". Je to TA ISTA mutacia `cp_group`,
  // aku mala sipka v nahlade — len rec pouzivatela namiesto ikony. Riadok bez
  // `source_key` (zostava, fixne nulove polozky) sa prepinat neda: zostava je
  // automaticky ZVYSOK a nulove polozky su dohodnute.
  function budCpSepHtml(sourceKey, on){
    if (!sourceKey) return '<span class="bfnt">—</span>';
    return '<label class="bcpsep" title="Zapnuté = položka je v dokumente vlastným riadkom; ' +
      'vypnuté = zlúči sa do nábytkovej zostavy (suma ponuky sa nemení).">' +
      '<input type="checkbox" data-bud="cp_sep" data-source="' + bEsc(sourceKey) + '"' +
      ' data-bkey="sep:' + bEsc(sourceKey) + '"' + (on ? ' checked' : '') + '> samostatne</label>';
  }

  // Zbalene (vertikalny priestor!) — otvara sa len ked chce Michal nieco
  // vytiahnut zo zostavy. Zoznam pocita a zoradi server.
  //
  // Review #8: stav rozbalenia PREZIJE prekreslenie (`BUD_OPEN`, rovnako ako
  // sekcie rozpoctu). Bez toho by sa zoznam po KAZDOM prepnuti „samostatne"
  // sam zabalil — a fokus, ktory na prepinaci stal (`data-bkey="sep:…"`), by
  // sa nemal kam vratit a spadol by na <body>. Prave tu sa pritom kliká
  // najviac: polozka sa vytiahne zo zostavy a hned sa rieši dalšia.
  function budCpMergedHtml(cp, d){
    var merged = (cp.candidates || []).filter(function(c){ return c.state !== 'samostatne'; });
    if (!merged.length) return '';
    var open = budSectionOpen('cp_merged');
    var h = '<details class="bcpmerged" data-section="cp_merged"' + (open ? ' open' : '') +
      '><summary>Zlúčené v zostave (' + merged.length + ')</summary>';
    merged.forEach(function(c){
      h += '<div class="bcpmrow"><span>' + bEsc(c.label) +
        (c.overridden ? ' <span class="bfnt">· ručne v zostave</span>' : '') + '</span>' +
        '<span class="bnum">' + bEsc(budSub(c.amount, d)) + '</span>' +
        budCpSepHtml(c.source_key, false) + '</div>';
    });
    return h + '</details>';
  }

  function budCpExport(){
    var st = budData();
    if (!st || !window.sketchup || !sketchup.cp_xlsx) return;
    NX.setStatus('Pripravujem cenovú ponuku…', false);
    // ST-1a (audit #1): nazov projektu je SERVEROVY udaj — z DOM sa uz
    // neposiela (input zije v liste Kusovnika v okne Studio).
    sketchup.cp_xlsx(JSON.stringify({ gen: st.gen }));
  }

  // --- E-c: PREPOČÍTAŤ CENY ------------------------------------------------
  // Beh riadi SERVER (core/price_refresh.rb): sekvenčný fetch s 3 s pauzou a
  // zápis po JEDNEJ položke (čiastočný úspech je normálny výsledok). Tu žije
  // len stav okna — potvrdenie, progres so Zrušiť a report. Klient NEPOSIELA
  // ani adresy, ani ceny: len „spusti" (prípadne kind+id jedného riadku).

  function budPrCopy(state, over){
    var out = {};
    var s = state || {};
    var k;
    for (k in s){ if (Object.prototype.hasOwnProperty.call(s, k)) out[k] = s[k]; }
    for (k in (over || {})){ if (Object.prototype.hasOwnProperty.call(over, k)) out[k] = over[k]; }
    return out;
  }

  // Zrkadlo serverového výberu (PriceRefresh.targets_from_budget) — slúži LEN
  // na počet a potvrdenie. Autorita zoznamu je server: klik posiela „spusti",
  // ciele si skladá z čerstvého rozpočtu sám.
  function budPrTargets(budget){
    var items = (budget && budget.stale && budget.stale.items) || [];
    var kinds = { sheet: 1, edge: 1, hardware: 1 };
    var seen = {};
    var out = [];
    items.forEach(function(it){
      if (!it || !it.demos_url) return;                 // ručná položka = nikdy fetch
      var id = String(it.id == null ? '' : it.id);
      if (!kinds[it.kind] || !id) return;
      var key = it.kind + '|' + id;
      if (seen[key]) return;
      seen[key] = true;
      out.push(it);
    });
    return out;
  }

  // Odhad času: 3 s crawl-delay + ~1 s fetch na položku (rovnaká konštanta ako
  // PriceRefresh::SECONDS_PER_ITEM — je to len text pre používateľa).
  function budPrEta(n){
    var s = Math.max(0, Number(n) || 0) * 4;
    if (s < 60) return 'približne ' + s + ' s';
    var m = Math.round(s / 60);
    return 'približne ' + m + ' ' + budPluralSk(m, ['minútu', 'minúty', 'minút']);
  }

  function budPrConfirmText(st){
    var s = st || {};
    var n = Number(s.total || 0);
    if (s.single){
      return 'Stiahnem aktuálnu cenu položky „' + (s.single.label || '') + '“ z Demosu — ' +
             budPrEta(1) + '.';
    }
    return 'Obnoviť ' + n + ' ' + budPluralSk(n, ['cenu', 'ceny', 'cien']) + ' z Demosu? Potrvá to ' +
           budPrEta(n) + ' — medzi položkami je povinná 3 s pauza. Priebeh sa dá kedykoľvek zrušiť.';
  }

  function budPrTitle(st){
    var s = st || {};
    if (s.phase === 'report') return 'Prepočet cien — výsledok';
    if (s.phase === 'run') return 'Sťahujem ceny z Demosu';
    return 'Prepočítať ceny';
  }

  // Event zo servera -> nový stav. „Pending pid guard": kým nepríde `start`,
  // stav pid nemá a eventy sa neaplikujú; po ňom sa berú LEN eventy TOHO behu
  // (oneskorená odpoveď starého behu nesmie prepísať nový).
  function budPrEvent(state, ev){
    var e = ev || {};
    var s = state;
    if (e.type === 'start'){
      return { phase: 'run', pid: e.pid, total: Number(e.total || 0), done: 0, label: '',
               report: null, single: (s && s.single) || null, cancelling: false };
    }
    if (e.type === 'rejected'){
      // Server beh VÔBEC NEZAČAL (staré okno, iný model, už beží, nie je čo
      // obnoviť) — modal sa zavrie a tlačidlo sa odomkne. Ruší sa LEN čakajúci
      // štart: bežiaci prepočet (ten už má pid) sa tým nesmie dať zabiť.
      return (s && s.pid) ? s : null;
    }
    if (s && s.pid && e.pid !== s.pid) return s; // event CUDZIEHO (staršieho) behu
    if (e.type === 'complete'){
      // Report sa ukáže aj vtedy, keď okno stav medzitým stratilo — je to
      // jediný terminálny stav a používateľ musí vidieť, čo sa zapísalo.
      var base = s || { phase: 'run', pid: e.pid, total: 0, done: 0, label: '', single: null };
      return budPrCopy(base, { phase: 'report', pid: e.pid, report: e.report || null,
                               label: '', cancelling: false });
    }
    if (!s || !s.pid) return s; // pending: kým nepríde `start`, pid nepoznám
    if (e.type === 'progress'){
      return budPrCopy(s, { done: Number(e.done || 0), total: Number(e.total || s.total),
                            label: String(e.label || '') });
    }
    if (e.type === 'item'){
      return budPrCopy(s, { done: Number(e.done || s.done), total: Number(e.total || s.total) });
    }
    return s;
  }

  // Report -> podklad pre zobrazenie. Počty NEPREPOČÍTAVAM — čísla nesie server;
  // tu sa riadky len triedia do troch skupín.
  function budPrSummary(report){
    var r = report || {};
    var changed = [];
    var errors = [];
    (r.items || []).forEach(function(i){
      if (i.status === 'changed') changed.push(i);
      else if (i.status === 'error') errors.push(i);
    });
    return { changed: changed, errors: errors,
             unchanged: Number(r.unchanged || 0), skipped: Number(r.skipped || 0),
             cancelled: r.cancelled === true, total: Number(r.total || 0),
             text: budPrSummaryText(r) };
  }

  function budPrSummaryText(report){
    var r = report || {};
    var ch = Number(r.changed || 0);
    var un = Number(r.unchanged || 0);
    var er = Number(r.errors || 0);
    var out = [ch + ' ' + budPluralSk(ch, ['cena zmenená', 'ceny zmenené', 'cien zmenených'])];
    if (un) out.push(un + ' bez zmeny');
    if (er) out.push(er + ' ' + budPluralSk(er, ['chyba', 'chyby', 'chýb']));
    if (r.cancelled) out.push('zrušené — ' + Number(r.skipped || 0) + ' preskočených');
    return out.join(' · ');
  }

  function budPrDiffText(item){
    var i = item || {};
    if (i.diff === null || i.diff === undefined || isNaN(i.diff)) return '';
    var v = Number(i.diff);
    var sign = v > 0 ? '+' : (v < 0 ? '−' : '');
    return sign + budFmtEur(Math.abs(v));
  }

  function budPrProgressText(st){
    var s = st || {};
    var total = Number(s.total || 0);
    var done = Number(s.done || 0);
    if (s.cancelling) return 'Ukončujem — dobehne ešte rozbehnutá položka…';
    var at = done + 1 > total ? total : done + 1;
    return 'Sťahujem ' + at + ' z ' + total + (s.label ? ' · ' + s.label : '');
  }

  function budPrProgressHtml(st){
    var total = Number(st.total || 0);
    var done = Number(st.done || 0);
    var pct = total ? Math.round((done / total) * 100) : 0;
    return '<div class="bprog"><i style="width:' + pct + '%"></i></div>' +
           '<div class="hint">' + bEsc(budPrProgressText(st)) + '</div>';
  }

  function budPrReportHtml(report){
    var s = budPrSummary(report);
    var h = '<div class="hint">' + bEsc(s.text) + '</div><div class="nxmodal-body">';
    if (s.changed.length){
      h += '<table class="btab"><tbody>';
      s.changed.forEach(function(i){
        h += '<tr><td>' + bEsc(i.label) + '</td><td class="bnum">' +
          bEsc(budFmtEur(i.old_price)) + ' → ' + bEsc(budFmtEur(i.new_price)) +
          '</td><td class="bnum">' + bEsc(budPrDiffText(i)) + '</td></tr>';
      });
      h += '</tbody></table>';
    }
    if (s.errors.length){
      h += '<div class="blist">';
      s.errors.forEach(function(i){
        h += '<div><span>' + bEsc(i.label) + '</span>' +
             '<span class="bprwhy">' + bEsc(i.error || 'nepodarilo sa overiť') + '</span></div>';
      });
      h += '</div>';
    }
    if (!s.changed.length && !s.errors.length){
      h += '<div class="bnote">Ceny sedia s Demosom — v katalógu sa obnovil len dátum overenia.</div>';
    }
    return h + '</div>';
  }

  function budPrModalHtml(){
    var st = BUD_PR;
    if (!st) return '';
    var body;
    var foot;
    if (st.phase === 'confirm'){
      body = '<div class="hint">' + bEsc(budPrConfirmText(st)) + '</div>';
      foot = '<button class="primary" data-bud="pr_go">Prepočítať</button>' +
             '<button class="ghostbtn" data-bud="pr_close">Zrušiť</button>';
    } else if (st.phase === 'run'){
      body = budPrProgressHtml(st);
      foot = '<button class="ghostbtn" data-bud="pr_cancel"' + (st.cancelling ? ' disabled' : '') +
             '>Zrušiť</button>';
    } else {
      body = budPrReportHtml(st.report);
      foot = '<button class="primary" data-bud="pr_close">Zavrieť</button>';
    }
    return '<div class="nxmodal" id="budPrModal"><div class="nxmodal-card nxmodal-scroll">' +
      '<div class="nxmodal-title">' + bEsc(budPrTitle(st)) + '</div>' + body +
      '<div class="btnrow">' + foot + '</div></div></div>';
  }

  // Modal žije MIMO tela tabu (document.body) — prežije prekreslenie rozpočtu,
  // ktoré príde hneď po dobehnutí prepočtu (čerstvé ceny za modalom).
  function budPrRenderModal(){
    var old = budEl('budPrModal');
    if (old && old.parentNode) old.parentNode.removeChild(old);
    if (!BUD_PR) return;
    var box = document.createElement('div');
    box.innerHTML = budPrModalHtml();
    var node = box.firstChild;
    if (node) document.body.appendChild(node);
  }

  function budPrStart(single){
    if (BUD_PR && BUD_PR.phase === 'run') return;
    var targets = budPrTargets(budBudget());
    if (single){
      targets = targets.filter(function(t){
        return t.kind === single.kind && String(t.id) === String(single.id);
      });
      if (!targets.length){
        NX.setStatus('Položka už nie je v zozname starých cien — obnov okno.', true);
        return;
      }
    }
    if (!targets.length){
      NX.setStatus('Všetky ceny viazané na Demos sú čerstvé — netreba nič sťahovať.', false);
      return;
    }
    BUD_PR = { phase: 'confirm', pid: null, total: targets.length, done: 0, label: '',
               report: null, single: single || null, cancelling: false };
    budPrRenderModal();
  }

  function budPrSend(){
    if (!BUD_PR || BUD_PR.phase !== 'confirm') return;
    var st = budData();
    if (!st || !window.sketchup || !sketchup.price_refresh) return;
    var single = BUD_PR.single;
    var extra = single ? { kind: single.kind, id: single.id } : {};
    BUD_PR = { phase: 'run', pid: null, total: BUD_PR.total, done: 0, label: '',
               report: null, single: single, cancelling: false };
    budPrRenderModal();
    budRerender(); // tlačidlo „Prepočítať ceny" v lište počas behu zošedne
    sketchup.price_refresh(JSON.stringify(budMutation(st, 'price_refresh', extra)));
  }

  function budPrCancel(){
    if (!BUD_PR || BUD_PR.phase !== 'run' || BUD_PR.cancelling) return;
    BUD_PR = budPrCopy(BUD_PR, { cancelling: true });
    budPrRenderModal();
    if (window.sketchup && sketchup.price_refresh_cancel) sketchup.price_refresh_cancel('');
  }

  // --- ⋯ modal (kód / adresa / poznámka) -----------------------------------
  // VEDOME NEMIGROVANY na D-15 kostru (ŠT-1c PR B2): nie je to „pridávačka",
  // ale editor uz existujuceho riadku — a jeho polia sa lisia podla typu
  // polozky. Patri k D-69 rodine editorov, ktoru prinesie ŠT-2; presuvat ho
  // teraz by znamenalo dvakrat prerabat to iste okno.

  function budModalHtml(){
    if (!BUD_MODAL) return '';
    var it = budFindItem(BUD_MODAL.kind, BUD_MODAL.id);
    if (!it) return '';
    var isAppl = BUD_MODAL.kind === 'appliance';
    var h = '<div class="nxmodal" id="budModal"><div class="nxmodal-card">' +
      '<div class="nxmodal-title">' + bEsc(it.nazov || 'Detail položky') + '</div>' +
      '<div class="hint">Voliteľné údaje — v tabuľke sa nezobrazujú.</div>';
    if (!isAppl){
      h += '<div class="row"><label>Kód</label><input id="budm_kod" type="text" value="' + bEsc(it.kod || '') + '"><span class="unit"></span></div>';
    }
    h += '<div class="row"><label>Adresa</label><input id="budm_url" type="text" placeholder="https://…" value="' +
      bEsc(it.url || '') + '"><span class="unit"></span></div>';
    if (!isAppl){
      h += '<div class="row"><label>Poznámka</label><input id="budm_pozn" type="text" value="' +
        bEsc(it.poznamka || '') + '"><span class="unit"></span></div>';
    }
    h += '<div class="btnrow"><button class="primary" data-bud="modal_save">Uložiť</button>' +
      '<button class="ghostbtn" data-bud="modal_close">Zrušiť</button></div></div></div>';
    return h;
  }

  function budFindItem(kind, id){
    var b = budBudget();
    if (!b) return null;
    var key = kind === 'appliance' ? 'appliances' : 'custom';
    var sec = (b.sections || []).filter(function(s){ return s.key === key; })[0];
    if (!sec) return null;
    return (sec.rows || []).filter(function(r){ return r.id === id; })[0] || null;
  }

  function budRenderModal(){
    var old = budEl('budModal');
    if (old && old.parentNode) old.parentNode.removeChild(old);
    if (!BUD_MODAL) return;
    var box = document.createElement('div');
    box.innerHTML = budModalHtml();
    var node = box.firstChild;
    if (node) document.body.appendChild(node);
  }

  // --- fokus cez re-render -------------------------------------------------
  // Zapis vyvola cerstvy payload a prekreslenie celeho tabu. Bez tohto by
  // pouzivatel po tabulatore do dalsieho pola prisiel o fokus AJ o rozpisanu
  // hodnotu (vzor materials_dialog: „re-render neprepise aktivny input").

  function budCaptureFocus(){
    BUD_FOCUS = null;
    var a = document.activeElement;
    if (!a || !a.getAttribute) return;
    var key = a.getAttribute('data-bkey');
    if (!key) return;
    BUD_FOCUS = { key: key, value: a.value,
                  start: (a.selectionStart == null ? -1 : a.selectionStart) };
  }

  function budRestoreFocus(){
    if (!BUD_FOCUS) return;
    var node = document.querySelector('[data-bkey="' + BUD_FOCUS.key.replace(/"/g, '\\"') + '"]');
    var f = BUD_FOCUS;
    BUD_FOCUS = null;
    if (!node) return;
    try {
      node.focus();
      if (node.value !== f.value && f.value !== undefined) node.value = f.value;
      if (f.start >= 0 && node.setSelectionRange) node.setSelectionRange(f.start, f.start);
    } catch (e) { /* fokus nie je kriticky */ }
  }

  // --- akcie ---------------------------------------------------------------

  // GH #138 P2: kym bezi predchadzajuci zapis, dalsi ide DO FRONTY (nie do
  // koša) — odosle sa hned po prichode cerstveho payloadu, uz s novou `gen`.
  function budSend(op, extra){
    var st = budData();
    if (!st || !window.sketchup || !sketchup.budget_mutate) return;
    if (BUD_BUSY){ BUD_QUEUE.push([op, extra]); return; }
    BUD_BUSY = true;
    if (budBusyTimer) clearTimeout(budBusyTimer);
    budBusyTimer = setTimeout(budAfterPush, BUD_BUSY_MS);
    sketchup.budget_mutate(JSON.stringify(budMutation(st, op, extra)));
  }

  // Vola sa po KAZDOM prichode payloadu (aj po odmietnutom zapise — server
  // vzdy re-pushne) a z poistneho timera.
  function budAfterPush(){
    if (budBusyTimer){ clearTimeout(budBusyTimer); budBusyTimer = null; }
    BUD_BUSY = false;
    // Poistka k zamku modalu (review #2): keby Ruby callback spadol EST PRED
    // `budgetResult`, zostal by modal zosednuty navzdy. Cerstvy payload (alebo
    // 6 s timer) je posledny bod, v ktorom sa to da odomknut. Pri normalnom
    // behu je uz odomknute — `setBusy(false)` na odomknutom modale nic nerobi.
    budUnlockDraft();
    if (!BUD_QUEUE.length) return;
    var next = BUD_QUEUE.shift();
    budSend(next[0], next[1]);
  }

  function budNumericSend(input, op, extra){
    var v = budParse(input.value);
    if (typeof v === 'number' && isNaN(v)){
      input.classList.add('bad');
      NX.setStatus('Hodnota musí byť číslo.', true);
      return;
    }
    input.classList.remove('bad');
    budSend(op, extra(v));
  }

  function budGoto(section){
    if (!section) return;
    var el = document.querySelector('details.bsec[data-section="' + section + '"]');
    if (!el) return;
    budSectionOpen(section); // inicializuje mapu, ak sa este nerenderovalo
    el.open = true;
    BUD_OPEN[section] = true;
    if (el.scrollIntoView) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  function budXlsx(){
    var st = budData();
    if (!st || !window.sketchup || !sketchup.budget_xlsx) return;
    NX.setStatus('Pripravujem XLSX rozpočet…', false);
    // ST-1a (audit #1): nazov projektu cita SERVER — z DOM uz nechodi.
    sketchup.budget_xlsx(JSON.stringify({ gen: st.gen }));
  }

  // GH #138 P2 + audit #10: modal sa NEZAVIERA pri odoslani. Server moze zapis
  // odmietnut (necislo, cena mimo rozsahu, pridlhy text) — vtedy musi
  // pouzivatel najst svoje hodnoty na mieste, nie prazdny formular. Zavrie ho
  // az POTVRDENIE zo servera (`NX.budgetResult(op, true)`).
  function budDraftCommit(kind, values){
    var attrs = budDraftAttrs(kind, values || {});
    BUD_DRAFT_VALUES[kind] = attrs; // hodnoty su zapamatane PRED odoslanim
    var missing = budDraftMissing(kind, attrs);
    // Klientske odmietnutie (chyba povinne pole) — na server sa nic neposlalo,
    // takze zamok treba pustit HNED, inak by okno ostalo zosednute navzdy.
    if (missing){ NX.setStatus(missing, true); budUnlockDraft(); return; }
    budSend(kind === 'custom' ? 'custom_add' : 'appliance_add', { attrs: attrs });
  }

  // Ciste: polia formulara -> atributy pre server (default pocet 1, typ „iné").
  function budDraftAttrs(kind, f){
    var g = f || {};
    if (kind === 'custom'){
      return { popis: g.popis || '', pocet: (g.pocet == null || g.pocet === '') ? '1' : g.pocet,
               cena: g.cena || '' };
    }
    return { typ: g.typ || 'ine', nazov: g.nazov || '',
             dodavatel: g.dodavatel || '', cena: g.cena || '' };
  }

  // Ciste: co este chyba, aby sa dalo odoslat (null = mozeme). Rozsahy a typy
  // stráži SERVER — tu je len povinne pole, aby sa zbytocne nechodilo do Ruby.
  function budDraftMissing(kind, attrs){
    var a = attrs || {};
    if (kind === 'custom') return String(a.popis || '').trim() ? null : 'Popis položky je povinný.';
    return String(a.nazov || '').trim() ? null : 'Názov spotrebiča je povinný.';
  }

  function budModalSave(){
    if (!BUD_MODAL) return;
    var attrs = { url: (budEl('budm_url') || {}).value || '' };
    if (BUD_MODAL.kind === 'custom'){
      attrs.kod = (budEl('budm_kod') || {}).value || '';
      attrs.poznamka = (budEl('budm_pozn') || {}).value || '';
    }
    var op = BUD_MODAL.kind === 'appliance' ? 'appliance_update' : 'custom_update';
    var id = BUD_MODAL.id;
    BUD_MODAL = null;
    budRenderModal();
    budSend(op, { id: id, attrs: attrs });
  }

  // GH #138 P2 + ŠT-1c PR B1 (audit #6): napojenie na zivotny cyklus payloadu.
  // budget.js sa nacitava AZ ZA studio.js, takze `NX` uz existuje — obalime
  // `NX.setStudio` (uvolnenie fronty zapisov po prichode cerstveho payloadu)
  // a doplnime `budgetResult` + `priceRefresh`.
  //
  // Fronta sa uvolnuje VYHRADNE tu. Okno ma aj MALE ECHA (`setVepoBar`,
  // `setEdgeCheck`, `setGrainCheck`), ktore NENESU cerstvu generaciu — keby sa
  // fronta uvolnovala na nich, dalsi zapis by odisiel so STAROU `gen` a server
  // by ho odmietol ako zastaraly (hoci je uplne v poriadku).
  if (typeof window !== 'undefined' && window.NX && typeof NX.setStudio === 'function'){
    var budPrevSetStudio = NX.setStudio;
    NX.setStudio = function(data){
      budPrevSetStudio(data);
      budAfterPush(); // fronta sa odosiela AZ s cerstvou gen z tohto payloadu
    };
    // Server hlasi vysledok mutacie PRED push_state — D-15 modal sa zavrie LEN
    // pri uspechu (audit #10). Odmietnuty zapis ho NECHAVA otvoreny aj
    // s rozpisanymi hodnotami: pouzivatel ma opravit svoje cislo, nie ho
    // hladat a pisat znova.
    NX.budgetResult = function(op, ok){
      if (op !== 'custom_add' && op !== 'appliance_add') return;
      // Review #2: zamok odoslania sa pusta v OBOCH vetvach. Pri uspechu to
      // spravi uz `budCloseDraft` (zavrety modal zamok nema), pri odmietnuti
      // musi tlacidlo ozit — inak by pouzivatel videl svoje hodnoty, ale
      // nemohol ich znova odoslat.
      if (ok) budCloseDraft();
      else budUnlockDraft();
    };
    // E-c: eventy prepočtu cien (start/progress/item/complete). Po `complete`
    // príde zo servera aj čerstvý payload — re-render odblokuje tlačidlo
    // v lište a ukáže nové ceny AJ obnovený pás cenovej čerstvosti za modalom.
    NX.priceRefresh = function(ev){
      var wasRunning = !!(BUD_PR && BUD_PR.phase === 'run');
      BUD_PR = budPrEvent(BUD_PR, ev);
      budPrRenderModal();
      // Sekcia sa prekresľuje LEN pri prechode z behu (dobehnutie AJ odmietnutý
      // štart) — tlačidlo „Prepočítať ceny" sa musí odomknúť. Počas behu sa
      // prekresľuje iba modal (progres by inak trhal celú sekciu).
      if (wasRunning && !(BUD_PR && BUD_PR.phase === 'run')) budRerender();
    };
  }

  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(ev){
      var b = ev.target && ev.target.closest ? ev.target.closest('[data-bud]') : null;
      if (!b || b.tagName === 'INPUT' || b.tagName === 'SELECT') return;
      var a = b.getAttribute('data-bud');
      if (a === 'vat'){
        BUD_VAT = b.getAttribute('data-v') === '1';
        try { window.localStorage.setItem(BUD_VAT_KEY, BUD_VAT ? '1' : '0'); } catch (e) { /* len UX */ }
        budRerender();
      } else if (a === 'mode'){
        budSend('mode', { mode: b.getAttribute('data-v') });
      } else if (a === 'stale'){
        BUD_STALE_OPEN = !BUD_STALE_OPEN; budRerender();
      } else if (a === 'ctrl'){
        // ŠT-1c PR B1: jantárový chip súčtu = nález KONTROLY. Sme v tom istom
        // okne, takže sa len prepne sekcia (žiadne premostenie, žiadny server).
        if (typeof studioGoSection === 'function') studioGoSection('ctrl');
      } else if (a === 'goto'){
        budGoto(b.getAttribute('data-section'));
      } else if (a === 'offer'){
        // ŠT-1c PR B2: Cenová ponuka je SEKCIA toho istého okna — len prepnutie.
        if (typeof studioGoSection === 'function') studioGoSection('offer');
      } else if (a === 'to_budget'){
        // Š15 „upravuj pri zdroji": ponuka sa needituje — každý jej chip vedie
        // do Rozpočtu (voliteľne rovno na sekciu, ktorej sa nález týka).
        // `studioGoSection` prekreslí okno SYNCHRÓNNE, takže `budGoto` už nájde
        // rozbaľovacie sekcie rozpočtu v DOM.
        if (typeof studioGoSection === 'function') studioGoSection('budget');
        var toSec = b.getAttribute('data-section');
        if (toSec) budGoto(toSec);
      } else if (a === 'draft'){
        budOpenDraft(b.getAttribute('data-kind'));
      } else if (a === 'remove'){
        budSend(b.getAttribute('data-kind') === 'appliance' ? 'appliance_remove' : 'custom_remove',
                { id: b.getAttribute('data-id') });
      } else if (a === 'url'){
        if (window.sketchup && sketchup.budget_open_url){
          sketchup.budget_open_url(JSON.stringify({ kind: b.getAttribute('data-kind'), id: b.getAttribute('data-id') }));
        }
      } else if (a === 'more'){
        BUD_MODAL = { kind: b.getAttribute('data-kind'), id: b.getAttribute('data-id') };
        budRenderModal();
      } else if (a === 'modal_close'){
        BUD_MODAL = null; budRenderModal();
      } else if (a === 'modal_save'){
        budModalSave();
      } else if (a === 'xlsx'){
        budXlsx();
      } else if (a === 'cp'){
        budCpExport();
      // ŠT-1c PR B2: `cp_group` uz nie je KLIK (sipka v nahlade) ale PREPINAC
      // „samostatne" — jeho vetva zije v listeneri `change` nizsie.
      } else if (a === 'settings'){
        if (window.sketchup && sketchup.budget_settings) sketchup.budget_settings('');
      } else if (a === 'refresh'){
        budPrStart(null);
      } else if (a === 'refresh_one'){
        budPrStart({ kind: b.getAttribute('data-kind'), id: b.getAttribute('data-id'),
                     label: b.getAttribute('data-label') });
      } else if (a === 'pr_go'){
        budPrSend();
      } else if (a === 'pr_cancel'){
        budPrCancel();
      } else if (a === 'pr_close'){
        BUD_PR = null;
        budPrRenderModal();
        budRerender();
      }
    });

    // Zapis az na `change` (blur / Enter) — pri kazdom stlaceni klavesy by sa
    // model zapisoval do undo zasobnika a okno prekreslovalo.
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      var a = t.getAttribute('data-bud');
      if (!a) return;
      if (a === 'override'){
        budNumericSend(t, 'override', function(v){ return { row_key: t.getAttribute('data-key'), amount: v }; });
      } else if (a === 'multiplier'){
        budNumericSend(t, 'multiplier', function(v){ return { row_key: t.getAttribute('data-key'), multiplier: v }; });
      } else if (a === 'viz_m2'){
        budNumericSend(t, 'viz_m2', function(v){ return { value: v }; });
      } else if (a === 'appl_included'){
        budSend('appl_included', { included: t.checked === true });
      } else if (a === 'cp_sep'){
        // Š14: per-riadok prepínač „samostatne" v sekcii Cenová ponuka. TÁ ISTÁ
        // mutácia `cp_group` ako predtým šípka v náhľade (1 zmena = 1 krok Späť).
        budSend('cp_group', { source_key: t.getAttribute('data-source'),
                              group: t.checked === true ? 'samostatne' : 'zostava' });
      } else if (a === 'custom_field'){
        var attrs = {};
        attrs[t.getAttribute('data-field')] = t.value;
        budSend('custom_update', { id: t.getAttribute('data-id'), attrs: attrs });
      } else if (a === 'appl_field'){
        var aattrs = {};
        aattrs[t.getAttribute('data-field')] = t.value;
        budSend('appliance_update', { id: t.getAttribute('data-id'), attrs: aattrs });
      }
    });

    // Enter v poli tabulky = zapis (blur vyvola `change`). Enter v D-15 modale
    // riesi ZDIELANY komponent (`nx_modal.js`) — tu sa nan uz nesiaha.
    document.addEventListener('keydown', function(ev){
      if (ev.key !== 'Enter') return;
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.getAttribute('data-bud')) t.blur();
    });

    // Stav rozbalenia sekcii prezije prekreslenie (payload chodi po kazdom zapise).
    // Stav rozbalenia si pamataju sekcie rozpoctu (`.bsec`) AJ zoznam
    // zlucenych polozek ponuky (`.bcpmerged`, review #8) — obidve nesu
    // `data-section` a obidve sa prekresluju po kazdom zapise.
    document.addEventListener('toggle', function(ev){
      var d = ev.target;
      if (!d || !d.classList) return;
      if (!d.classList.contains('bsec') && !d.classList.contains('bcpmerged')) return;
      var key = d.getAttribute('data-section');
      if (!key) return;
      budSectionOpen(key); // prvy pristup inicializuje BUD_OPEN default mapou
      BUD_OPEN[key] = d.open;
    }, true);

    try {
      var stored = window.localStorage.getItem(BUD_VAT_KEY);
      if (stored !== null) BUD_VAT = stored === '1';
    } catch (e) { /* localStorage nemusi byt dostupny */ }
  }

  // Node testy (tests/js/test_budget_ui.js) — LEN ciste funkcie bez DOM.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { budFmtEur: budFmtEur, budFmtNum: budFmtNum, budDisplay: budDisplay,
      budPluralSk: budPluralSk, budStaleLabel: budStaleLabel, budWarnChips: budWarnChips,
      budMutation: budMutation, budParse: budParse, budNumText: budNumText,
      budSectionCount: budSectionCount, budEsc: bEsc,
      // ŠT-1c PR B1: rozrezany render — LISTA sekcie vs TELO (Š12 „1:1" je
      // 1:1 OBSAH, nie kod). Obe funkcie su ciste (HTML z payloadu).
      budToolsHtml: budToolsHtml, budPriceBtnHtml: budPriceBtnHtml, budSummaryHtml: budSummaryHtml,
      budModeSegHtml: budModeSegHtml, budChipHtml: budChipHtml,
      budDraftAttrs: budDraftAttrs, budDraftMissing: budDraftMissing,
      // ŠT-1c PR B2: sekcia CENOVA PONUKA (Š14–Š15) + D-15 modal pridavaciek
      budCpBand: budCpBand, budOfferHtml: budOfferHtml,
      budOfferToolsHtml: budOfferToolsHtml, budOfferGuardHtml: budOfferGuardHtml,
      budCpTableHtml: budCpTableHtml, budCpMergedHtml: budCpMergedHtml,
      budCpSepHtml: budCpSepHtml, budCpLinkHtml: budCpLinkHtml,
      budOfferWireHtml: budOfferWireHtml, budDraftFields: budDraftFields,
      budOfferChipHtml: budOfferChipHtml, budDraftMemory: budDraftMemory,
      // E-c „Prepočítať ceny"
      budPrTargets: budPrTargets, budPrEta: budPrEta, budPrConfirmText: budPrConfirmText,
      budPrEvent: budPrEvent, budPrSummary: budPrSummary, budPrSummaryText: budPrSummaryText,
      budPrDiffText: budPrDiffText, budPrProgressText: budPrProgressText,
      budPrProgressHtml: budPrProgressHtml, budPrReportHtml: budPrReportHtml,
      budPrTitle: budPrTitle, budStaleActionHtml: budStaleActionHtml };
  }
