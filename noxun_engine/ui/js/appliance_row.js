  // ===================== S1-B2: RIADOK „SPOTREBIČ" v Inspectore =============
  //
  // JEDEN riadok cez oba stĺpce Základných (vzor riadku Nôh, mockup R9) —
  // a TEN ISTÝ komponent v karte dosky. Skrinka môže mať viac riadkov naraz
  // (rúra + mikrovlnka), doska tiež (varná doska + drez).
  //
  // ČO JE ČIE:
  //   * SERVER (`ui/panel/payloads.rb`, kľúč `appliance_rows`) skladá riadky,
  //     ich poradie, texty, tón aj PONUKU modelov (filter podľa niky). Tento
  //     súbor kreslí presne to, čo dostal — nič nedopočítava a nič nefiltruje.
  //   * KLIENT vlastní len dve veci: KAM riadky kreslí (skrinka vs doska)
  //     a ČO pošle po kliknutí (`set_appliance_owner`).
  //
  // Riadok je VÝSTUP, nie pole formulára: nič z neho sa nikdy nedostane do
  // `collectAll()` ani do vkladacieho payloadu (rovnaké pravidlo ako riadok
  // Nôh). Zápis ide vlastným callbackom a vracia sa čerstvou kartou.

  // KOMU riadky patria (skrinka/slot vs doska) NEDRŽÍ globálna premenná, ale
  // samotný kontajner v DOM: panel vie mať vykreslenú kartu dosky aj kartu
  // skrinky (jedna je skrytá) a echo katalógu materiálov prekresľuje kartu
  // dosky aj vtedy, keď je označená skrinka. Globál by sa tak dal prepísať
  // pod rukami a zápis by odišiel na cudzieho vlastníka.
  function aprEl(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }

  function aprEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function aprIco(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

  // Ponuka modelov. PRVÁ VOĽBA je vždy neutrálna („vyber model…") — `<select>`
  // bez vyslovenej hodnoty vyberie prvú možnosť, a keby ňou bol model, jediné
  // kliknutie do riadku by spotrebič naviazalo (aj s prestavbou skrinky).
  // Modely, ktoré sa do niky nezmestia, v ponuke OSTÁVAJÚ s dôvodom — filter
  // je pomoc, nie brána (mockup R11).
  function aprSelectHtml(row){
    var opts = row.options || [];
    var h = '<select class="aprsel" data-apr="pick" aria-label="Vybrať spotrebič">' +
            '<option value="">' + aprEsc(row.placeholder || 'vyber model…') + '</option>';
    opts.forEach(function(o){
      h += '<option value="' + aprEsc(o.item_id) + '">' + aprEsc(o.text) + '</option>';
    });
    if (row.all && row.all_note){
      h += '<option value="" disabled>' + aprEsc(row.all_note) + '</option>';
    }
    return h + '</select>';
  }

  // S1-C: PONUKA OČAKÁVANÍ. Prvá voľba je neutrálny SÚHRN („očakáva: rúra"),
  // takže `<select>` bez vyslovenej hodnoty nikdy nič nezapíše; ďalšie voľby
  // sú PRÍKAZY `add:<kód>` / `del:<kód>`. Viazanú kategóriu sa odobrať nedá —
  // voľba ostáva viditeľná s dôvodom (`disabled`), aby bolo vidieť PREČO.
  function aprExpectsHtml(row){
    var opts = row.options || [];
    var h = '<select class="aprsel" data-apr="expects" aria-label="Očakávaný spotrebič">' +
            '<option value="">' + aprEsc(row.placeholder || 'očakáva: —') + '</option>';
    opts.forEach(function(o){
      h += '<option value="' + aprEsc(o.value) + '"' + (o.disabled ? ' disabled' : '') + '>' +
           aprEsc(o.text) + '</option>';
    });
    return h + '</select>';
  }

  // Nový ÚPLNÝ zoznam očakávaní (čistá funkcia — Node test). Klient nikdy
  // neposiela „pridaj/odober", ale celý zoznam: server tak porovnáva stav so
  // stavom a nemusí hádať, z čoho klient vychádzal (Codex C13).
  function aprExpectsNext(current, value){
    var list = (current || []).map(String);
    var v = String(value || '');
    var i = v.indexOf(':');
    if (i < 0) return null;
    var op = v.slice(0, i), code = v.slice(i + 1);
    if (!code) return null;
    if (op === 'add') return list.indexOf(code) >= 0 ? list.slice() : list.concat([code]);
    if (op === 'del') return list.filter(function(c){ return c !== code; });
    return null;
  }

  // Čistá funkcia (Node test): riadok payloadu -> HTML.
  function aprRowHtml(row){
    var r = row || {};
    if (r.state === 'expects'){
      // ÚPLNY aktuálny zoznam ide do DOM (nie len do pamäte): riadok sa
      // prekresľuje celou kartou, takže jediné miesto, kde stav naozaj žije,
      // je posledný payload servera.
      return '<div class="aprow expects" data-apr-row="expects" data-apr-expects="' +
        aprEsc((r.expects || []).join(',')) + '">' + aprIco('appliance') +
        '<span class="aplbl">Spotrebič</span><span class="apsel">' + aprExpectsHtml(r) +
        '</span><span class="aptxt soft">' + aprEsc(r.text) + '</span></div>';
    }
    var bound = r.state === 'bound';
    var tone = String(r.tone || '');
    var id = aprEsc(r.item_id || '');
    var h = '<div class="aprow ' + aprEsc(tone) + '" data-apr-row="' + id + '">' +
      aprIco(bound && tone === 'ok' ? 'check' : (bound ? 'alert' : 'appliance')) +
      '<span class="aplbl">Spotrebič</span><span class="apsel">';
    // D-140: VYSKA OSADENIA (len chladnicka v skrinke — posiela ju server).
    // Tlacidlo, nie pole: zapis ide VYHRADNE cez popover s „Použiť".
    if (bound && r.mount){
      h += '<button type="button" class="apmount" data-apr="mount" data-id="' + id + '"' +
        ' data-v="' + aprEsc(r.mount.value) + '" aria-haspopup="dialog" aria-controls="aprMountPop"' +
        ' title="Výška osadenia od hornej plochy dna (napr. vrch police) — klik = zmeniť">' +
        aprEsc(r.mount.text) + '</button>';
    }
    h += bound
      ? '<button type="button" class="ibtn" data-apr="unbind" data-id="' + id + '"' +
        ' title="Odpojiť spotrebič od tohto kusu — v zákazke ostáva" aria-label="Odpojiť">' +
        aprIco('unlink') + '</button>'
      : aprSelectHtml(r);
    h += '<button type="button" class="ibtn" data-apr="studio" data-id="' + id + '"' +
      ' title="Otvoriť Štúdio → Spotrebiče" aria-label="Otvoriť Štúdio">' +
      aprIco('external-link') + '</button></span>';
    h += '<span class="aptxt">' + aprEsc(r.text) +
      (r.sub ? '<span class="apsub">' + aprEsc(r.sub) + '</span>' : '') + '</span></div>';
    return h;
  }

  function aprRowsHtml(rows){
    var list = rows || [];
    var h = '';
    list.forEach(function(r){ h += aprRowHtml(r); });
    return h;
  }

  // Vykreslenie do uzla sekcie. Prázdny zoznam = blok sa SCHOVÁ (o čom
  // rozhoduje VÝHRADNE server). S1-C: skrinka a doska dostávajú aspoň riadok
  // VOĽBY „očakáva", takže prázdno ostáva len tam, kde sa očakávať nedá nič.
  function renderApplianceRows(rows, ctx, nodeId){
    var box = aprEl(nodeId || 'applRows');
    if (!box) return false;
    var list = rows || [];
    var c = ctx || {};
    box.setAttribute('data-apr-kind', String(c.kind || 'cabinet'));
    box.setAttribute('data-apr-id', String(c.id || ''));
    // S1-C: `persistent_id` kusu — jediný údaj, ktorý prežije recykláciu
    // výrobného ID, takže server ním overuje, že zápis mieri na TEN kus,
    // nad ktorým bol riadok vykreslený.
    box.setAttribute('data-apr-pid', (c.pid == null ? '' : String(c.pid)));
    box.innerHTML = aprRowsHtml(list);
    box.hidden = list.length === 0;
    if ((nodeId || 'applRows') === 'applRows') aprMountSync(list, c);
    return list.length > 0;
  }

  // === D-140: POPOVER VYSKY OSADENIA =======================================
  //
  // STATICKY uzol `#aprMountPop` ZA `#applRows` — prekreslenie riadkov (echo
  // prestavby, novy payload) ho nezmaze, takze rozpisana hodnota prezije
  // (Astra C FIX 8). Pri OTVORENI sa ZACHYTI dokument, vlastnik (druh, ID,
  // PID), `item_id` a POVODNA hodnota; odosiela sa PRESNE to (BLOCKER 2) —
  // nikdy stav okna v case odoslania a nikdy pri `blur`. Zmena dokumentu,
  // kusu alebo zanik riadku popover ZAVRIE BEZ ZAPISU.
  var APR_MOUNT = null;

  function aprMountFmt(v){
    var n = Number(v) || 0;
    return String(Math.round(n * 10) / 10).replace('.', ',');
  }
  // Cislo z pola: desatinna ciarka aj bodka; NaN = neplatne (nezapise sa).
  function aprMountParse(s){
    var t = String(s == null ? '' : s).trim().replace(',', '.');
    if (!/^-?\d+(\.\d+)?$/.test(t)) return NaN;
    return parseFloat(t);
  }
  function aprMountDoc(){ return (typeof nxDocGuid === 'function') ? nxDocGuid() : ''; }

  function aprMountOpen(btn){
    var ctx = aprCtxOf(btn);
    var pop = aprEl('aprMountPop'), inp = aprEl('aprMountVal');
    if (!ctx || !pop || !inp) return false;
    var prev = Number(btn.getAttribute('data-v')) || 0;
    APR_MOUNT = { guid: aprMountDoc(), ctx: ctx, item: String(btn.getAttribute('data-id') || ''), prev: prev };
    inp.value = aprMountFmt(prev);
    inp.classList.remove('bad');
    pop.hidden = false;
    if (inp.focus) inp.focus();
    if (inp.select) inp.select();
    return true;
  }

  // `restore` = pouzivatel popover SAM zrusil alebo potvrdil (Escape, Zrušiť,
  // Použiť): fokus sa vrati na cip — ale LEN ked bol V POPOVERI (vzor
  // `closeFrontBulk`; pri kliku mimo patri tomu, na co pouzivatel klikol).
  // Upratovanie pri zmene dokumentu ci kusu (`aprMountSync`, `clearApplianceRows`,
  // `nxDropDocState`) fokus NEPRESUVA (Codex #389 kolo 3, P2).
  function aprMountClose(restore){
    var s = APR_MOUNT;
    APR_MOUNT = null;
    var inside = false;
    if (restore === true){
      try {
        var ae = (typeof document === 'undefined') ? null : document.activeElement;
        inside = !!(ae && typeof ae.closest === 'function' && ae.closest('#aprMountPop'));
      } catch (e) { inside = false; }
    }
    var pop = aprEl('aprMountPop');
    if (pop) pop.hidden = true;
    var chip = (inside && s) ? aprMountChip(s.item) : null;
    if (chip && chip.focus) chip.focus();
    return true;
  }

  // Cip TOHO kusu v aktualnom DOM — riadky sa prekresluju cez innerHTML, takze
  // uzol z casu otvorenia uz nemusi zit; hlada sa podla `data-id`.
  function aprMountChip(item){
    var box = aprEl('applRows');
    if (!box || !box.querySelectorAll) return null;
    var list = box.querySelectorAll('[data-apr="mount"]');
    for (var i = 0; i < list.length; i++){
      if (String(list[i].getAttribute('data-id') || '') === String(item)) return list[i];
    }
    return null;
  }

  // Payload zapisu — z ZACHYTENEHO stavu (cista funkcia, Node test).
  function aprMountPayload(state, value){
    var s = state || {};
    return aprPayload({ item_id: s.item, value: value, prev: s.prev }, s.ctx);
  }

  function aprMountApply(){
    if (!APR_MOUNT) return false;
    var inp = aprEl('aprMountVal');
    var v = aprMountParse(inp ? inp.value : '');
    if (!isFinite(v) || v < 0){
      if (inp) inp.classList.add('bad');
      return false;
    }
    var s = APR_MOUNT;
    aprMountClose(true);
    if (Math.abs(v - s.prev) < 0.05) return false; // bez zmeny — ziadna prestavba
    if (typeof window === 'undefined' || !window.sketchup || !sketchup.set_appliance_mount) return false;

    sketchup.set_appliance_mount(nxDocPayload(aprMountPayload(s, v), s.guid));
    return true;
  }

  // Po KAZDOM vykresleni riadkov: popover zije dalej LEN nad tym istym
  // dokumentom, tym istym kusom (ID + PID) a riadkom, ktory osadenie stale ma.
  function aprMountSync(rows, ctx){
    if (!APR_MOUNT) return false;
    var s = APR_MOUNT, c = ctx || {};
    var same = s.guid === aprMountDoc() && String(s.ctx.id) === String(c.id || '') &&
               String(s.ctx.pid == null ? '' : s.ctx.pid) === String(c.pid == null ? '' : c.pid) &&
               (rows || []).some(function(r){ return r && r.mount && String(r.item_id) === s.item; });
    if (!same) aprMountClose();
    return same;
  }

  // Odchod z kontextu (odznačenie, prechod na dosku) — riadky PATRIA označenému
  // kusu, takže s ním musia zmiznúť. Nestačí ich skryť: s kontajnerom odchádza
  // aj KONTEXT vlastníka (`data-apr-*`), inak by klik do zvyšného DOM poslal
  // zápis na kus, ktorý už nikto nevidí (Codex #383 kolo 1 P2).
  function clearApplianceRows(nodeId){
    var box = aprEl(nodeId || 'applRows');
    if (!box) return false;
    if ((nodeId || 'applRows') === 'applRows') aprMountClose(); // D-140: kus zmizol z okna
    box.innerHTML = '';
    box.hidden = true;
    box.removeAttribute('data-apr-kind');
    box.removeAttribute('data-apr-id');
    box.removeAttribute('data-apr-pid');
    return true;
  }

  // Payload zápisu. Identitu VLASTNÍKA skladá SERVER z označenej entity —
  // klient posiela len to, čo priradiť, a nad čím bol riadok vykreslený
  // (echo ID, GH #127 P2).
  function aprPayload(extra, ctx){
    var e = extra || {};
    var c = ctx || {};
    if (String(c.kind) === 'board') e.board_id = String(c.id || '');
    else e.cabinet_id = String(c.id || '');
    if (c.pid != null && c.pid !== '') e.pid = c.pid;
    return e;
  }

  // Kontext riadku Z DOM — z kontajnera, v ktorom kliknutý prvok naozaj leží.
  function aprCtxOf(node){
    var box = (node && node.closest) ? node.closest('[data-apr-kind]') : null;
    if (!box) return null;

    return { kind: box.getAttribute('data-apr-kind'), id: box.getAttribute('data-apr-id'),
             pid: box.getAttribute('data-apr-pid') };
  }

  function aprSend(extra, ctx){
    if (!ctx) return false;
    if (typeof window === 'undefined' || !window.sketchup || !sketchup.set_appliance_owner) return false;

    sketchup.set_appliance_owner(nxDocPayload(aprPayload(extra, ctx)));
    return true;
  }

  function aprPick(id, ctx){
    if (!id) return false;

    return aprSend({ item_id: id }, ctx);
  }

  function aprUnbind(id, ctx){
    if (!id) return false;

    return aprSend({ item_id: id, unbind: true }, ctx);
  }

  // S1-C: zápis očakávaní. Vlastný callback (nie `set_appliance_owner`) —
  // je to iná vec: žiadna položka zákazky sa nemení, len config kusu.
  //
  // DVE POISTKY PROTI RÝCHLEMU DRUHÉMU PRÍKAZU (Codex #385 kolo 1, P2). Zápis
  // je asynchrónny a pravdu prinesie až čerstvá karta, takže dve voľby za sebou
  // by sa obe počítali z TOHO ISTÉHO zastaraného zoznamu a druhá by prvú
  // prepísala („pridaj rúru" + „pridaj mikrovlnku" = zostane len mikrovlnka):
  //   1. **ovládač sa zamkne** (`disabled`), kým nepríde nový payload — server
  //      posiela čerstvú kartu aj pri KAŽDOM odmietnutí, takže sa vždy odomkne,
  //   2. **lokálny snapshot sa aktualizuje optimisticky** — príkaz, ktorý sa
  //      napriek zámku dostane cez (klávesnica, oneskorená udalosť, druhý
  //      ovládač v tom istom riadku), vychádza z AKTUÁLNEHO zoznamu.
  // Klient si pritom nič nedopočítava: posiela ÚPLNY zoznam a server ho aj tak
  // validuje a porovnáva so stavom modelu.
  function aprSetExpects(select, ctx){
    if (!ctx || !select) return false;
    var row = (select.closest) ? select.closest('[data-apr-expects]') : null;
    var raw = row ? String(row.getAttribute('data-apr-expects') || '') : '';
    var cur = raw ? raw.split(',') : [];
    var next = aprExpectsNext(cur, select.value);
    select.value = ''; // späť na neutrálny súhrn; pravdu prinesie čerstvá karta
    if (!next) return false;
    if (typeof window === 'undefined' || !window.sketchup || !sketchup.set_appliance_expects) return false;

    if (row) row.setAttribute('data-apr-expects', next.join(','));
    select.disabled = true;
    sketchup.set_appliance_expects(nxDocPayload(aprPayload({ expects: next }, ctx)));
    return true;
  }

  // Ikona odkazu vedie do Štúdia na sekciu Spotrebiče; pri viazanom riadku
  // rovno na JEHO riadok (kotva `appliance:<uuid>` — tá istá adresa, akú
  // používa nález Kontroly).
  function aprStudio(id){
    if (typeof openStudio !== 'function') return false;

    openStudio('appl', id ? ('appliance:' + id) : '');
    return true;
  }

  if (typeof document !== 'undefined'){
    document.addEventListener('click', function(ev){
      var t = ev.target;
      var b = (t && t.closest) ? t.closest('[data-apr]') : null;
      if (!b || b.tagName === 'SELECT') return;
      var a = b.getAttribute('data-apr');
      if (a === 'unbind'){ aprUnbind(b.getAttribute('data-id'), aprCtxOf(b)); return; }
      if (a === 'studio'){ aprStudio(b.getAttribute('data-id')); return; }
      if (a === 'mount'){ aprMountOpen(b); return; }
      if (a === 'mount-ok'){ aprMountApply(); return; }
      if (a === 'mount-cancel'){ aprMountClose(true); }
    });

    // D-140: popover sa zatvara klikom MIMO (bez zapisu), Escape; Enter = Použiť.
    document.addEventListener('mousedown', function(ev){
      if (!APR_MOUNT) return;
      var t = ev.target;
      if (t && t.closest && (t.closest('#aprMountPop') || t.closest('[data-apr="mount"]'))) return;
      aprMountClose();
    }, true);
    // Escape zatvara z KAZDEHO prvku (Tab na Pomoc/Použiť/Zrušiť — Codex #389
    // P2) a udalost sa spotrebuje: otvoreny popover je najvyssia vrstva
    // Inspectora (modaly obsluzi `nx_esc.js`, ktory je nacitany PRED nami).
    // Enter ostava viazany na pole — na tlacidle ho vybavi jeho vlastny klik.
    document.addEventListener('keydown', function(ev){
      if (!APR_MOUNT) return;
      if (ev.key === 'Escape'){
        ev.preventDefault();
        if (typeof ev.stopImmediatePropagation === 'function') ev.stopImmediatePropagation();
        aprMountClose(true);
        return;
      }
      var t = ev.target;
      if (!t || t.id !== 'aprMountVal') return;
      if (ev.key === 'Enter'){ ev.preventDefault(); aprMountApply(); }
    });

    // Zápis až na `change` (nie `input`): každé prebehnutie klávesnicou cez
    // ponuku by inak spustilo prestavbu skrinky a krok Späť.
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute) return;
      var a = t.getAttribute('data-apr');
      if (a === 'pick'){ aprPick(t.value, aprCtxOf(t)); return; }
      if (a === 'expects'){ aprSetExpects(t, aprCtxOf(t)); }
    });
  }

  // Node testy (tests/js/test_s1b2_pohlad.js, test_s1c_expects.js) — ČISTÉ
  // funkcie + vykreslenie, ktoré sa inak overiť nedá.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { aprRowHtml: aprRowHtml, aprRowsHtml: aprRowsHtml,
                       aprSelectHtml: aprSelectHtml, aprPayload: aprPayload,
                       renderApplianceRows: renderApplianceRows, aprCtxOf: aprCtxOf,
                       clearApplianceRows: clearApplianceRows,
                       aprExpectsHtml: aprExpectsHtml, aprExpectsNext: aprExpectsNext,
                       aprSetExpects: aprSetExpects,
                       // D-140: popover vysky osadenia.
                       aprMountOpen: aprMountOpen, aprMountClose: aprMountClose,
                       aprMountApply: aprMountApply, aprMountSync: aprMountSync,
                       aprMountParse: aprMountParse, aprMountFmt: aprMountFmt,
                       aprMountPayload: aprMountPayload,
                       aprMountState: function(){ return APR_MOUNT; } };
  }
