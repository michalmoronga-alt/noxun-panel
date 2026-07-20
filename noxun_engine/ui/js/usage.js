  // D-25: Merac pouzivania panela — LOKALNE pocitadla interakcii s prvkami
  // Inspectora (podklad pre buduci rezim Jednoduchy/Rozsireny). Zbiera VYLUCNE
  // identifikatory prvkov (id / predok-s-id + tag / nazov inline funkcie /
  // allowlist tried delegovanych prvkov) a pocty — NIKDY hodnoty poli, nazvy
  // projektov ani suborov; z inline atributov sa berie LEN nazov funkcie pred
  // zatvorkou, argumenty nikdy (mozu niest identifikatory dat, napr. material).
  // INVARIANT do buducna (Codex audit D-25): id prvkov panela musia ostat
  // staticke identifikatory — id odvodene z dat by potichu poslalo data do
  // pocitadiel. Novy dynamicky prvok = pridat triedu do HIT_CLASSES, nie id z dat.
  // Flush do Ruby cez callback usage_flush kazdych ~30 s (len ak je co) + pri
  // skryti/zatvarani panela; uklada sa do %APPDATA%\NOXUN\Engine\usage_stats.json.
  // Cely modul je IIFE (ziadne globaly) a defenzivny: kazdy handler v try/catch
  // — chyba meraca NIKDY nesmie rozbit panel, zlyhania sa ticho ignoruju.
(function(){
  var counts = {};
  var FLUSH_MS = 30000;
  // Delegovane klikatelne prvky panela BEZ <button>/onclick atributu (lockbtn a
  // znode maju click cez delegaciu/property; zrect/divh/ehit/behit/fgrp su SVG
  // hit plochy — fgrp je celo v nahlade, D-23 klik-sync na riadok zoznamu).
  // Prazdna plocha SVG (pan/zoom) sa NEpocita — nie je to pouzitie prvku.
  var HIT_CLASSES = ['zrect', 'divh', 'ehit', 'behit', 'lockbtn', 'znode', 'fgrp'];

  // --- klasifikacia (cista logika, testovatelna v Node cez module.exports) ---

  function tagOf(el){
    return el && el.tagName ? String(el.tagName).toUpperCase() : '';
  }
  function attrOf(el, name){
    try { return el && el.getAttribute ? el.getAttribute(name) : null; } catch(e){ return null; }
  }
  // SVG-safe test triedy (className je tam SVGAnimatedString — preto atribut).
  function hasClass(el, cls){
    var c = ' ' + (attrOf(el, 'class') || '') + ' ';
    return c.indexOf(' ' + cls + ' ') >= 0;
  }
  function hitClass(el){
    for (var i = 0; i < HIT_CLASSES.length; i++){
      if (hasClass(el, HIT_CLASSES[i])) return HIT_CLASSES[i];
    }
    return null;
  }
  // Nazov funkcie z inline handlera ("splitZone('v')" -> "splitZone").
  // LEN identifikator pred zatvorkou — argumenty mozu niest identifikatory dat.
  function fnName(attr){
    var m = /^\s*([A-Za-z_$][\w$]*)\s*\(/.exec(String(attr || ''));
    return m ? m[1] : null;
  }
  function nearestId(el){
    var n = el;
    while (n){
      if (n.id) return String(n.id);
      n = n.parentNode;
    }
    return null;
  }
  // Najblizsi klikatelny prvok smerom hore: button/a/summary, atribut onclick,
  // alebo allowlist trieda delegovaneho prvku. Nic z toho = klik sa nepocita.
  function clickTargetOf(el){
    var n = el;
    while (n && n.tagName){
      var tag = tagOf(n);
      if (tag === 'BUTTON' || tag === 'A' || tag === 'SUMMARY') return n;
      if (attrOf(n, 'onclick')) return n;
      if (hitClass(n)) return n;
      n = n.parentNode;
    }
    return null;
  }
  // Kluc prvku: id | "<predok-s-id|?>/<tag>[.typ][:funkcia]". Typ inputu a nazov
  // inline funkcie rozlisuju dynamicke prvky bez id (riadky ciel, kovanie...).
  function keyFor(el){
    if (!el || !el.tagName) return null;
    if (el.id) return String(el.id);
    var tag = String(el.tagName).toLowerCase();
    if (tag === 'input') tag += '.' + String(el.type || 'text').toLowerCase();
    var base = (nearestId(el.parentNode) || '?') + '/' + tag;
    var fn = fnName(attrOf(el, 'onclick') || attrOf(el, 'onchange') || attrOf(el, 'oninput'));
    return fn ? base + ':' + fn : base;
  }
  // Kluc kliknutia (null = nepocitat). bodyTab = aktualny data-cab-tab na <body>
  // (delegovany listener bezi az PO inline handleri, atribut je uz prepnuty).
  function clickKey(target, bodyTab){
    var c = clickTargetOf(target);
    if (!c) return null;
    var tag = tagOf(c);
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return null; // tika 'change'
    if (hasClass(c, 'cabtab')) return 'tab:' + (bodyTab || '?'); // rezimove taby
    if (tag === 'SUMMARY'){
      var dk = attrOf(c.parentNode, 'data-key');
      if (dk) return 'sec:' + dk; // akordeony sekcii
    }
    var hc = hitClass(c);
    if (hc) return (nearestId(c) || '?') + '/' + hc; // napr. preview/zrect
    return keyFor(c);
  }
  // Kluc zmeny pola (null = nepocitat): len formularove prvky.
  function changeKey(target){
    var tag = tagOf(target);
    if (tag !== 'INPUT' && tag !== 'SELECT' && tag !== 'TEXTAREA') return null;
    return keyFor(target);
  }

  // Node testy (tests/js/test_usage.js) — v CEF je module undefined, vetva spi.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { fnName: fnName, keyFor: keyFor, clickKey: clickKey,
                       changeKey: changeKey, clickTargetOf: clickTargetOf };
    return;
  }

  // --- DOM cast (len v paneli) ----------------------------------------------

  function tick(key){
    try {
      if (!key) return;
      counts[key] = (counts[key] || 0) + 1;
    } catch(e){}
  }

  // isTrusted guard: synteticke eventy (expr.js dispatchne 'change' pri Enter /
  // sipkach) sa NEpocitaju — nativny change pri blur da 1 tick na jednu upravu
  // pola (Codex audit D-25: ziadne dvojite pocitanie tej istej upravy).
  function onClick(e){
    try {
      if (!e || e.isTrusted === false) return;
      tick(clickKey(e.target, document.body.getAttribute('data-cab-tab')));
    } catch(err){}
  }
  function onChange(e){
    try {
      if (!e || e.isTrusted === false) return;
      tick(changeKey(e.target));
    } catch(err){}
  }

  // Flush: stringify -> POSLAT -> az po uspesnom odovzdani vycistit. Ked bridge
  // chyba alebo volanie zlyha, pocitadla OSTAVAJU a skusi sa o 30 s (ziadna
  // tichá strata davky — Codex audit D-25 blocker). Jedina neodstranitelna
  // strata: davka odovzdana CEF tesne pred zanikom okna sa uz nemusi dorucit —
  // pre statisticky merac prijatelne (max posledna neflushnuta cast relacie).
  function flush(){
    try {
      var has = false;
      for (var k in counts){ if (Object.prototype.hasOwnProperty.call(counts, k)){ has = true; break; } }
      if (!has) return;
      if (!(window.sketchup && sketchup.usage_flush)) return; // akumuluj dalej
      sketchup.usage_flush(JSON.stringify({ counts: counts }));
      counts = {}; // az PO uspesnom volani — vynimka vyssie necha davku na retry
    } catch(e){}
  }

  try {
    document.addEventListener('click', onClick, false);
    document.addEventListener('change', onChange, false);
    setInterval(flush, FLUSH_MS);
    // Zatvaranie/skrytie panela: CEF negarantuje beforeunload — flushuje sa aj
    // pri pagehide a skryti okna (visibilitychange), dvojity flush je no-op.
    window.addEventListener('beforeunload', flush, false);
    window.addEventListener('pagehide', flush, false);
    document.addEventListener('visibilitychange', function(){
      try { if (document.visibilityState === 'hidden') flush(); } catch(e){}
    }, false);
  } catch(e){}
})();
