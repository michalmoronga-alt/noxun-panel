  // ===================== TAB ROZPOCET (V0.6 E-b) =====================
  // Zobrazuje payload z Budget.compute (Ruby). ZELEZNE PRAVIDLO: JS NEPOCITA
  // ZIADNE SUMY — vsetky medzisucty, zaokruhlenie aj SPOLU su hotove cisla zo
  // servera (vzor KONTROLA counts). JEDINA povolena aritmetika je delenie
  // `vat_divisor` pri prepnuti na "bez DPH" — cisto ZOBRAZOVACI prepocet
  // (firma je neplatca DPH, katalogove ceny su konecne), oznaceny nizsie.
  //
  // Mutacie (rezim, prepis sumy, nasobok, m2, vlastne polozky, spotrebice) idu
  // cez JEDEN callback `budget_mutate` s gen + model_guid; server ich overi,
  // zapise (1 undo krok) a posle CERSTVY payload. Klient si stav nedopocitava.

  var BUD_VAT = true;          // prepinac zobrazenia (localStorage, len UX)
  var BUD_OPEN = null;         // { sekcia -> otvorena? } — prezije re-render
  var BUD_STALE_OPEN = false;
  var BUD_WARN_OPEN = false;
  var BUD_DRAFT = null;        // rozpisany novy riadok: 'custom' | 'appliance'
  var BUD_DRAFT_VALUES = null; // GH #138 P2: hodnoty draftu prezijú odmietnutý zápis
  var BUD_MODAL = null;        // { kind, id } — otvoreny ⋯ modal
  var BUD_FOCUS = null;        // obnova fokusu/hodnoty cez re-render

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
    // Zvysok upozorneni rozpoctu (bez spotrebicoveho — ten ma vlastny chip).
    var rest = (b.budget_check || []).filter(function(w){
      return w.stable_key !== 'budget|appliances|not_included';
    });
    if (rest.length){
      out.push({ id: 'check', count: rest.length, list: rest,
                 text: rest.length + ' ' + budPluralSk(rest.length,
                   ['upozornenie rozpočtu', 'upozornenia rozpočtu', 'upozornení rozpočtu']) });
    }
    return out;
  }

  // Payload mutacie — jedno miesto, kde sa sklada identita zapisu.
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
      BUD_OPEN = { materials: true, abs: false, hardware: false, services: true,
                   standard_rows: true, custom: true, appliances: true, cp: true };
    }
    return BUD_OPEN[key] !== false;
  }

  function budSub(value, divisor){
    return budFmtEur(budDisplay(value, BUD_VAT, divisor));
  }

  function renderBudget(box){
    var b = (BOM && BOM.budget) ? BOM.budget : null;
    if (!b){
      box.innerHTML = '<div class="muted">Rozpočet sa nepodarilo zostaviť (pozri Ruby konzolu).</div>';
      return;
    }
    budCaptureFocus();
    var d = b.vat_divisor;
    var h = budSummaryHtml(b, d);
    (b.sections || []).forEach(function(sec){
      if (sec.key === 'rounding') h += budRoundingHtml(sec, b, d);
      else h += budSectionHtml(sec, b, d);
    });
    h += budCpHtml(b, d);
    h += budFootHtml();
    box.innerHTML = h;
    budRestoreFocus();
  }

  function budSummaryHtml(b, d){
    var t = b.totals || {};
    var total = BUD_VAT ? t.total : t.total_novat; // OBE cisla nesie server
    var h = '<div class="bsum">' +
      '<div><div class="blbl">Spolu za zákazku</div>' +
      '<div class="btotal">' + bEsc(budFmtEur(total)) +
      ' <small>' + (BUD_VAT ? 's DPH' : 'bez DPH') + '</small></div></div>' +
      '<div class="bswitch">' +
      '<div class="bseg" role="group" aria-label="Zobrazenie DPH">' +
      '<button type="button" class="' + (BUD_VAT ? 'on' : '') + '" data-bud="vat" data-v="1">s DPH</button>' +
      '<button type="button" class="' + (BUD_VAT ? '' : 'on') + '" data-bud="vat" data-v="0">bez DPH</button>' +
      '</div>' + budModeSegHtml(b) + '</div>';
    h += '<div class="bwarns">';
    budWarnChips(b).forEach(function(c){ h += budChipHtml(c, b, d); });
    h += '</div></div>';
    h += budStaleListHtml(b);
    h += budWarnListHtml(b);
    return h;
  }

  var BUD_MODE_SEG = [['nizky', '€', 'Nízky režim — stáli zákazníci, lepšie ceny'],
                      ['standard', '€€', 'Štandardný režim'],
                      ['vysoky', '€€€', 'Vysoký režim — kde vieme pridať']];

  function budModeSegHtml(b){
    var h = '<div class="bseg bmode" role="group" aria-label="Cenový režim zákazky">';
    BUD_MODE_SEG.forEach(function(m){
      h += '<button type="button" class="' + (b.mode === m[0] ? 'on' : '') + '"' +
           ' data-bud="mode" data-v="' + m[0] + '" title="' + bEsc(m[2]) + '">' + m[1] + '</button>';
    });
    return h + '</div>';
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
    return '<button type="button" class="bchip' + (BUD_WARN_OPEN ? ' open' : '') + '" data-bud="warns">' +
           '<svg class="ic" aria-hidden="true"><use href="#i-chevron-right"/></svg> ' + bEsc(c.text) + '</button>';
  }

  function budStaleListHtml(b){
    if (!BUD_STALE_OPEN) return '';
    var items = (b.stale && b.stale.items) || [];
    if (!items.length) return '';
    var h = '<div class="blist">';
    items.forEach(function(it){
      var age = it.state === 'stale' ? ('overené pred ' + it.age_days + ' dňami')
              : (it.state === 'unverified' ? 'cena nikdy neoverená' : 'ručná položka');
      h += '<div><span>' + bEsc(it.label) + '</span><span class="bage">' + bEsc(age) + '</span></div>';
    });
    return h + '</div>';
  }

  function budWarnListHtml(b){
    if (!BUD_WARN_OPEN) return '';
    var items = (b.budget_check || []).filter(function(w){
      return w.stable_key !== 'budget|appliances|not_included';
    });
    if (!items.length) return '';
    var h = '<div class="blist">';
    items.forEach(function(w){
      h += '<div class="bwrow" data-bud="goto" data-section="' + bEsc(w.section) + '"' +
           ' title="Prejsť na sekciu rozpočtu"><span>' + bEsc(w.message) + '</span></div>';
    });
    return h + '</div>';
  }

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
    if (sec.key === 'custom'){
      h += budDraftHtml('custom') +
        '<button type="button" class="baddbig" data-bud="draft" data-kind="custom">' +
        '<svg class="ic" aria-hidden="true"><use href="#i-plus"/></svg> Pridať položku</button>';
    }
    if (sec.key === 'appliances'){
      h += budDraftHtml('appliance') +
        '<button type="button" class="baddbig" data-bud="draft" data-kind="appliance">' +
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

  // Rozpisany novy riadok — zije LEN v prehliadaci, kym ho pouzivatel nepotvrdi
  // (prazdna polozka by inak hned vyrobila upozornenie „bez popisu").
  function budDraftHtml(kind){
    if (BUD_DRAFT !== kind) return '';
    var v = BUD_DRAFT_VALUES || {};
    var h = '<div class="bdraft">';
    if (kind === 'custom'){
      h += budTypeless('Popis položky…', 'dpopis', 'bwide', v.popis) +
           budTypeless('1', 'dpocet', 'bshort', v.pocet) +
           budTypeless('0,00', 'dcena', 'bshort', v.cena);
    } else {
      h += budTypeSelect('id="bud_dtyp"', v.typ || 'chladnicka') +
           budTypeless('Názov / model…', 'dnazov', 'bwide', v.nazov) +
           budTypeless('Dodávateľ', 'ddod', '', v.dodavatel) +
           budTypeless('0,00', 'dcena', 'bshort', v.cena);
    }
    h += '<button type="button" class="primary bdraftok" data-bud="draft_ok" data-kind="' + kind + '">' +
         '<svg class="ic" aria-hidden="true"><use href="#i-check"/></svg> Pridať</button>' +
         '<button type="button" class="ghostbtn" data-bud="draft_cancel">Zrušiť</button></div>';
    return h;
  }

  function budTypeless(ph, id, cls, value){
    return '<input class="bedit ' + cls + '" type="text" id="bud_' + id + '" placeholder="' + bEsc(ph) + '"' +
           ' value="' + bEsc(value == null ? '' : value) + '" aria-label="' + bEsc(ph) + '">';
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

  // ================= CENOVA PONUKA — NAHLAD (E-b2) =========================
  // CP je VIEW nad rozpoctom: vsetky riadky, sumy aj navrhy pocita SERVER
  // (payload.cp_preview). JS ich LEN zobrazuje a posiela prepnutie zaradenia.
  // Riadok „Nábytková zostava" je automaticky zvysok — dorovnanie nikdy nerobi
  // pouzivatel a nikdy sa nezabudne.

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

  function budCpHtml(b, d){
    var cp = b ? b.cp_preview : null;
    if (!cp) return '';
    var open = budSectionOpen('cp');
    var band = budCpBand(cp);
    var h = '<details class="bsec" data-section="cp"' + (open ? ' open' : '') + '>' +
      '<summary><h3>Cenová ponuka — náhľad</h3>' +
      '<span class="bcnt">' + bEsc((cp.rows || []).length + ' ' +
        budPluralSk((cp.rows || []).length, ['riadok', 'riadky', 'riadkov']) +
        ' · samostatne od ' + budFmtEur(cp.threshold)) + '</span>' +
      '<span class="bsubt">' + bEsc(budSub(cp.total, d)) + '</span></summary>';
    h += '<div class="bcpband' + (band.ok ? ' ok' : '') + '">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-' + (band.ok ? 'check' : 'alert') + '"/></svg> ' +
      bEsc(band.text) + '</div>';
    h += budCpTableHtml(cp, d);
    h += budCpMergedHtml(cp, d);
    h += '<div class="bnote">Zákaznícky pohľad na ten istý rozpočet — suma sa nikdy nelíši. ' +
      'Zameranie a Vizualizácie sú v ponuke vždy 0 € (náklad je rozpustený v zostave). ' +
      'Významné položky vieš dať samostatne, ostatné sa zlúčia do nábytkovej zostavy. ' +
      'Export je vždy s DPH (ceny sú konečné).</div>';
    return h + '</details>';
  }

  function budCpTableHtml(cp, d){
    var rows = cp.rows || [];
    if (!rows.length) return '<div class="muted" style="padding:6px 12px">Zatiaľ prázdne.</div>';
    var h = '<table class="btab"><thead><tr><th>Položka</th><th class="bnum">Cena</th>' +
      '<th class="bnum">Množstvo</th><th class="bnum">MJ</th><th class="bnum"></th></tr></thead><tbody>';
    rows.forEach(function(r){
      var act = '';
      if (r.source_key){
        act = '<button type="button" class="bact" data-bud="cp_group" data-source="' + bEsc(r.source_key) + '"' +
          ' data-group="zostava" title="Zlúčiť do nábytkovej zostavy" aria-label="Zlúčiť do zostavy">' +
          '<svg class="ic" aria-hidden="true"><use href="#i-arrow-left-right"/></svg></button>';
      }
      h += '<tr class="' + (r.kind === 'assembly' ? 'bcpasm' : '') + '"><td>' + bEsc(r.polozka) + '</td>' +
        '<td class="bnum">' + bEsc(budSub(r.cena, d)) + '</td>' +
        '<td class="bnum">' + bEsc(budFmtNum(r.mnozstvo, 0)) + '</td>' +
        '<td class="bnum">' + bEsc(r.mj) + '</td>' +
        '<td class="bnum bacts">' + act + '</td></tr>';
    });
    h += '<tr class="bcptotal"><td>' + bEsc(cp.total_label || 'SPOLU') + '</td>' +
      '<td class="bnum">' + bEsc(budSub(cp.total, d)) + '</td><td></td><td></td><td></td></tr>';
    return h + '</tbody></table>';
  }

  // Zbalene (vertikalny priestor!) — otvara sa len ked chce Michal nieco
  // vytiahnut zo zostavy. Zoznam pocita a zoradi server.
  function budCpMergedHtml(cp, d){
    var merged = (cp.candidates || []).filter(function(c){ return c.state !== 'samostatne'; });
    if (!merged.length) return '';
    var h = '<details class="bcpmerged"><summary>Zlúčené v zostave (' + merged.length + ')</summary>';
    merged.forEach(function(c){
      h += '<div class="bcpmrow"><span>' + bEsc(c.label) +
        (c.overridden ? ' <span class="bfnt">· ručne v zostave</span>' : '') + '</span>' +
        '<span class="bnum">' + bEsc(budSub(c.amount, d)) + '</span>' +
        '<button type="button" class="bact" data-bud="cp_group" data-source="' + bEsc(c.source_key) + '"' +
        ' data-group="samostatne" title="Ukázať v cenovej ponuke samostatne" aria-label="Samostatne v ponuke">' +
        '<svg class="ic" aria-hidden="true"><use href="#i-arrow-left-right"/></svg></button></div>';
    });
    return h + '</details>';
  }

  function budCpExport(){
    if (!BOM || !window.sketchup || !sketchup.cp_xlsx) return;
    NX.setStatus('Pripravujem cenovú ponuku…', false);
    sketchup.cp_xlsx(JSON.stringify({
      gen: BOM.gen,
      project: (budEl('vepoProject') ? budEl('vepoProject').value : '').trim()
    }));
  }

  // Disabled tlacidlo nedostava mouse eventy, takze `title` na nom tooltip
  // NEUKAZE — obal ho nesie namiesto neho (pouzivatel musi vidiet PRECO je sive).
  function budSoonBtn(icon, label, why){
    return '<span title="' + bEsc(why) + '"><button type="button" class="ghostbtn" disabled>' +
      '<svg class="ic" aria-hidden="true"><use href="#i-' + icon + '"/></svg> ' + bEsc(label) + '</button></span>';
  }

  function budFootHtml(){
    return '<div class="bfoot">' +
      budSoonBtn('refresh-cw', 'Prepočítať ceny', 'Príde v ďalšej časti dávky E (E-c) — overenie cien u dodávateľa.') +
      '<button type="button" class="primary" data-bud="xlsx" title="Interný rozpočet v presnom formáte tvojich hárkov">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-download"/></svg> XLSX rozpočet</button>' +
      '<button type="button" class="primary" data-bud="cp"' +
      ' title="Zákaznícky dokument: cenová tabuľka + špecifikácia (bez interných pojmov a kódov)">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-download"/></svg> Cenová ponuka (zákazník)</button>' +
      '<button type="button" class="ghostbtn bgear" data-bud="settings" title="Sadzby, režimy a prahy — globálne">' +
      '<svg class="ic" aria-hidden="true"><use href="#i-settings"/></svg> Nastavenia</button></div>';
  }

  // --- ⋯ modal (kód / adresa / poznámka) -----------------------------------

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
    var b = (BOM && BOM.budget) ? BOM.budget : null;
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
    if (!BOM || !window.sketchup || !sketchup.budget_mutate) return;
    if (BUD_BUSY){ BUD_QUEUE.push([op, extra]); return; }
    BUD_BUSY = true;
    if (budBusyTimer) clearTimeout(budBusyTimer);
    budBusyTimer = setTimeout(budAfterPush, BUD_BUSY_MS);
    sketchup.budget_mutate(JSON.stringify(budMutation(BOM, op, extra)));
  }

  // Vola sa po KAZDOM prichode payloadu (aj po odmietnutom zapise — server
  // vzdy re-pushne) a z poistneho timera.
  function budAfterPush(){
    if (budBusyTimer){ clearTimeout(budBusyTimer); budBusyTimer = null; }
    BUD_BUSY = false;
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
    if (!BOM || !window.sketchup || !sketchup.budget_xlsx) return;
    NX.setStatus('Pripravujem XLSX rozpočet…', false);
    sketchup.budget_xlsx(JSON.stringify({
      gen: BOM.gen,
      project: (budEl('vepoProject') ? budEl('vepoProject').value : '').trim()
    }));
  }

  // GH #138 P2: draft sa NEZAHADZUJE pri odoslani. Server moze zapis odmietnut
  // (necislo, cena mimo rozsahu, pridlhy text) — vtedy musi pouzivatel najst
  // svoje hodnoty na mieste, nie prazdny formular. Zavrie ho az POTVRDENIE
  // zo servera (NX.budgetResult).
  function budDraftCommit(kind){
    var attrs = budDraftAttrs(kind, {
      popis: (budEl('bud_dpopis') || {}).value, pocet: (budEl('bud_dpocet') || {}).value,
      nazov: (budEl('bud_dnazov') || {}).value, typ: (budEl('bud_dtyp') || {}).value,
      dodavatel: (budEl('bud_ddod') || {}).value, cena: (budEl('bud_dcena') || {}).value
    });
    BUD_DRAFT_VALUES = attrs; // hodnoty su zapamatane PRED odoslanim
    var missing = budDraftMissing(kind, attrs);
    if (missing){ NX.setStatus(missing, true); return; }
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

  // GH #138 P2: napojenie na zivotny cyklus payloadu. budget.js sa nacitava AZ
  // ZA production.js, takze NX uz existuje — obalime setBom (uvolnenie fronty
  // po prichode novej generacie) a doplnime budgetResult (vysledok zapisu).
  if (typeof window !== 'undefined' && window.NX && typeof NX.setBom === 'function'){
    var budPrevSetBom = NX.setBom;
    NX.setBom = function(data){
      budPrevSetBom(data);
      budAfterPush(); // fronta sa odosiela AZ s cerstvou gen z tohto payloadu
    };
    // Server hlasi vysledok mutacie PRED push_state — draft sa zavrie LEN pri
    // uspechu, inak ostane aj s rozpisanymi hodnotami.
    NX.budgetResult = function(op, ok){
      if (ok && (op === 'custom_add' || op === 'appliance_add')){
        BUD_DRAFT = null;
        BUD_DRAFT_VALUES = null;
      }
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
        renderBody();
      } else if (a === 'mode'){
        budSend('mode', { mode: b.getAttribute('data-v') });
      } else if (a === 'stale'){
        BUD_STALE_OPEN = !BUD_STALE_OPEN; renderBody();
      } else if (a === 'warns'){
        BUD_WARN_OPEN = !BUD_WARN_OPEN; renderBody();
      } else if (a === 'goto'){
        budGoto(b.getAttribute('data-section'));
      } else if (a === 'draft'){
        BUD_DRAFT = b.getAttribute('data-kind'); BUD_DRAFT_VALUES = null; renderBody();
      } else if (a === 'draft_cancel'){
        BUD_DRAFT = null; BUD_DRAFT_VALUES = null; renderBody();
      } else if (a === 'draft_ok'){
        budDraftCommit(b.getAttribute('data-kind'));
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
      } else if (a === 'cp_group'){
        budSend('cp_group', { source_key: b.getAttribute('data-source'), group: b.getAttribute('data-group') });
      } else if (a === 'settings'){
        if (window.sketchup && sketchup.budget_settings) sketchup.budget_settings('');
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

    document.addEventListener('keydown', function(ev){
      if (ev.key !== 'Enter') return;
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      if (t.id && t.id.indexOf('bud_d') === 0){
        ev.preventDefault();
        budDraftCommit(BUD_DRAFT);
      } else if (t.getAttribute('data-bud')){
        t.blur(); // vyvola `change` -> zapis
      }
    });

    // Stav rozbalenia sekcii prezije prekreslenie (payload chodi po kazdom zapise).
    document.addEventListener('toggle', function(ev){
      var d = ev.target;
      if (!d || !d.classList || !d.classList.contains('bsec')) return;
      var key = d.getAttribute('data-section');
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
      budDraftAttrs: budDraftAttrs, budDraftMissing: budDraftMissing,
      budCpBand: budCpBand, budCpHtml: budCpHtml };
  }
