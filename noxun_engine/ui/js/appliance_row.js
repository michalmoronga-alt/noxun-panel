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

  // Čistá funkcia (Node test): riadok payloadu -> HTML.
  function aprRowHtml(row){
    var r = row || {};
    var bound = r.state === 'bound';
    var tone = String(r.tone || '');
    var id = aprEsc(r.item_id || '');
    var h = '<div class="aprow ' + aprEsc(tone) + '" data-apr-row="' + id + '">' +
      aprIco(bound && tone === 'ok' ? 'check' : (bound ? 'alert' : 'appliance')) +
      '<span class="aplbl">Spotrebič</span><span class="apsel">';
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

  // Vykreslenie do uzla sekcie. Prázdny zoznam = riadok sa SCHOVÁ: skrinka,
  // ktorá spotrebič nemá a ani ho neočakáva, o ňom nemá čo hovoriť
  // (vertikálny priestor panela je vzácny).
  function renderApplianceRows(rows, ctx, nodeId){
    var box = aprEl(nodeId || 'applRows');
    if (!box) return false;
    var list = rows || [];
    var c = ctx || {};
    box.setAttribute('data-apr-kind', String(c.kind || 'cabinet'));
    box.setAttribute('data-apr-id', String(c.id || ''));
    box.innerHTML = aprRowsHtml(list);
    box.hidden = list.length === 0;
    return list.length > 0;
  }

  // Payload zápisu. Identitu VLASTNÍKA skladá SERVER z označenej entity —
  // klient posiela len to, čo priradiť, a nad čím bol riadok vykreslený
  // (echo ID, GH #127 P2).
  function aprPayload(extra, ctx){
    var e = extra || {};
    var c = ctx || {};
    if (String(c.kind) === 'board') e.board_id = String(c.id || '');
    else e.cabinet_id = String(c.id || '');
    return e;
  }

  // Kontext riadku Z DOM — z kontajnera, v ktorom kliknutý prvok naozaj leží.
  function aprCtxOf(node){
    var box = (node && node.closest) ? node.closest('[data-apr-kind]') : null;
    if (!box) return null;

    return { kind: box.getAttribute('data-apr-kind'), id: box.getAttribute('data-apr-id') };
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
      if (a === 'studio'){ aprStudio(b.getAttribute('data-id')); }
    });

    // Zápis až na `change` (nie `input`): každé prebehnutie klávesnicou cez
    // ponuku by inak spustilo prestavbu skrinky a krok Späť.
    document.addEventListener('change', function(ev){
      var t = ev.target;
      if (!t || !t.getAttribute || t.getAttribute('data-apr') !== 'pick') return;
      aprPick(t.value, aprCtxOf(t));
    });
  }

  // Node testy (tests/js/test_s1b2_pohlad.js) — ČISTÉ funkcie + vykreslenie,
  // ktoré sa inak overiť nedá.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { aprRowHtml: aprRowHtml, aprRowsHtml: aprRowsHtml,
                       aprSelectHtml: aprSelectHtml, aprPayload: aprPayload,
                       renderApplianceRows: renderApplianceRows, aprCtxOf: aprCtxOf };
  }
