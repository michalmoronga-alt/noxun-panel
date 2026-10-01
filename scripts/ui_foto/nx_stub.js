// Noxun Engine — prehravac nahravky pre fotenie okien (scripts/ui_foto.ps1 -Shoot).
// NIE je sucast pluginu: vklada sa LEN do docasnej kopie `noxun_engine/ui/` v %TEMP%
// (nikdy do repa — strazi to tests/pure/test_ui_foto.rb). Robi tri veci:
//   1. stub mostika `window.sketchup` (kazde volanie sa len zapise do __nxCalls),
//   2. prehra nahrate Ruby->JS skripty (NNNN_<panel|studio>.js) od zaciatku az po
//      znacku ZA cielovou sekciou (`?upto=studio_cut` = vsetko do sekcie Narezovy plan
//      vratane), volitelne prepne kontext Inspectora (`&ctx=zony|cela|kovanie`),
//   3. zmeria vysku obsahu (pre „long" fotku) a posle report serveru
//      (POST /__nx_report) — chyby prehravania sa NAVYSE ukazu cervenym pasom priamo
//      vo fotke, aby po zmene UI nevznikla ticha prazdna fotka.
// Vyber suborov (`select`) je cista funkcia — testuje ju tests/js/test_ui_foto_stub.js.
(function () {
  'use strict';

  function parseMark(name) {
    var m = /^\d+_mark_(.+)\.txt$/.exec(String(name));
    return m ? m[1] : null;
  }

  // list = nazvy suborov nahravky (index.json), upto = cielova znacka, kind = panel|studio.
  // Vrati { files, found, marks }: skripty daneho okna od zaciatku nahravky az po
  // DALSIU znacku za cielovou (stav sa kumuluje ako v zivom okne); found=false =
  // cielova znacka v nahravke nie je (prehravac to ohlasi ako chybu, nie tichu fotku).
  function select(list, upto, kind) {
    var names = (Array.isArray(list) ? list : []).map(String).slice().sort();
    var suffix = '_' + kind + '.js';
    var files = [], marks = [], found = false;
    for (var i = 0; i < names.length; i++) {
      var f = names[i];
      var mk = parseMark(f);
      if (mk !== null) {
        marks.push(mk);
        if (found) break;
        if (mk === upto) found = true;
        continue;
      }
      if (!/^\d+_/.test(f)) continue;
      if (f.length > suffix.length && f.slice(-suffix.length) === suffix) files.push(f);
    }
    return { files: files, found: found, marks: marks };
  }

  // Report prehravania (Codex #434 P2): chyby sa zbieraju CELY cas az po fotku. Stav
  // sa posiela trikrat-plus: po prehrani (`replay`), po ustaleni (`settled`, SETTLE_MS
  // po prehrani — UI ma 500 ms aj viacsekundove casovace) a pri KAZDEJ neskorej chybe
  // (`late`). Pas v okne sa pri kazdom odoslani prekresli, takze chyba z odlozeneho
  // callbacku sa do fotky dostane, aj keby prisla az po ustaleni (fotka sa robi az na
  // konci --virtual-time-budget v ui_foto.ps1, ktory je dlhsi nez ustalenie).
  // io = { post(report), banner(errors) } — v teste falosne, v okne fetch + DOM.
  function makeReporter(base, io) {
    var errors = [];
    var stage = null;
    function flush(st) {
      stage = st;
      var rep = {};
      for (var k in base) if (Object.prototype.hasOwnProperty.call(base, k)) rep[k] = base[k];
      rep.errors = errors.slice();
      rep.stage = st;
      if (errors.length) io.banner(errors.slice());
      io.post(rep);
      return rep;
    }
    return {
      errors: errors,
      stage: function () { return stage; },
      add: function (msg) {
        errors.push(String(msg));
        if (stage !== null) flush('late');
      },
      replayed: function (height) { base.height = height; return flush('replay'); },
      settled: function (height) {
        base.height = Math.max(base.height || 0, height || 0);
        return flush('settled');
      }
    };
  }

  var SETTLE_MS = 6000;

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { select: select, parseMark: parseMark, makeReporter: makeReporter, SETTLE_MS: SETTLE_MS };
  }
  if (typeof window === 'undefined') return;

  window.__nxCalls = [];
  window.sketchup = new Proxy({}, {
    get: function (_t, k) { return function () { window.__nxCalls.push(String(k)); }; }
  });

  var params = new URLSearchParams(location.search);
  var upto = params.get('upto');
  var kind = params.get('kind') || 'studio';
  var ctx = params.get('ctx');
  var shot = params.get('shot') || upto || 'x';
  if (!upto) return;

  function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  // Vyska celeho obsahu: dokument + najvacsi „schovany" zvysok vnutornych
  // posuvnych oblasti (Studio aj Inspector rolluju vo vnutri, nie cele okno).
  function measure() {
    var de = document.documentElement;
    var h = Math.max(de ? de.scrollHeight : 0, document.body ? document.body.scrollHeight : 0, window.innerHeight);
    var extra = 0;
    var all = document.querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (el.clientHeight <= 0 || el.scrollHeight <= el.clientHeight + 2) continue;
      var oy = getComputedStyle(el).overflowY;
      if (oy !== 'auto' && oy !== 'scroll') continue;
      extra = Math.max(extra, el.scrollHeight - el.clientHeight);
    }
    return Math.ceil(Math.max(h, window.innerHeight + extra));
  }

  function banner(list) {
    var div = document.querySelector('[data-nx-replay-banner]');
    if (!div) {
      div = document.createElement('div');
      div.setAttribute('data-nx-replay-banner', '1');
      div.style.cssText = 'position:fixed;left:0;right:0;top:0;z-index:2147483647;background:#b3261e;color:#fff;' +
        'font:600 13px/1.35 Segoe UI,Arial,sans-serif;padding:8px 10px;white-space:pre-wrap;box-shadow:0 2px 6px rgba(0,0,0,.4)';
      (document.body || document.documentElement).appendChild(div);
    }
    div.textContent = 'PREHRÁVANIE ZLYHALO (' + list.length + '× chyba) — fotka nemusí zodpovedať oknu:\n' +
      list.slice(0, 4).join('\n') + (list.length > 4 ? '\n…' : '');
  }

  // Odoslania idu za sebou (retaz), aby neskorsi stav nikdy neprepisal starsi report.
  var postChain = Promise.resolve();
  function post(rep) {
    var body = JSON.stringify(rep);
    postChain = postChain.then(function () {
      return fetch('/__nx_report?shot=' + encodeURIComponent(shot), { method: 'POST', body: body });
    }).catch(function () { /* bez servera (rucne otvorenie) — pas vo fotke ostava */ });
  }

  var base = { shot: shot, upto: upto, kind: kind, ctx: ctx || null, replayed: [], height: 0,
               width: window.innerWidth, viewport_height: window.innerHeight };
  var reporter = makeReporter(base, { post: post, banner: banner });
  window.__nxReporter = reporter;
  window.addEventListener('error', function (ev) {
    reporter.add('JS chyba: ' + (ev && ev.message ? ev.message : String(ev)));
  });
  window.addEventListener('unhandledrejection', function (ev) {
    reporter.add('JS chyba (promise): ' + (ev && ev.reason ? (ev.reason.message || ev.reason) : '?'));
  });

  async function run() {
    var list = [];
    try {
      list = await (await fetch('rec/index.json', { cache: 'no-store' })).json();
    } catch (e) {
      reporter.errors.push('nahrávka: rec/index.json sa nedá načítať (' + e.message + ')');
    }
    var plan = select(list, upto, kind);
    if (!plan.found) reporter.errors.push('nahrávka: značka „' + upto + '" v nahrávke chýba — treba -Record');
    if (plan.found && plan.files.length === 0) reporter.errors.push('nahrávka: pre „' + upto + '" nie je ani jeden skript okna ' + kind);
    var done = [];
    for (var i = 0; i < plan.files.length; i++) {
      var f = plan.files[i];
      try {
        var buf = await (await fetch('rec/' + f, { cache: 'no-store' })).arrayBuffer();
        var src = new TextDecoder('utf-8').decode(buf);
        (0, eval)(src);
        done.push(f);
      } catch (e) {
        reporter.errors.push(f + ': ' + (e && e.message ? e.message : String(e)));
      }
    }
    if (ctx) {
      if (typeof window.setViewContext === 'function') {
        try { window.setViewContext(ctx); } catch (e) { reporter.errors.push('kontext ' + ctx + ': ' + e.message); }
      } else {
        reporter.errors.push('kontext ' + ctx + ': setViewContext v okne nie je');
      }
    }
    base.replayed = done;
    await wait(400);
    document.title = 'REPLAY ' + upto;
    reporter.replayed(measure());
    await wait(SETTLE_MS);
    reporter.settled(measure());
  }

  window.addEventListener('load', function () { setTimeout(run, 400); });
})();
