  // ===================== V0.4.7e VYRAZOVE ROZMEROVE POLIA =====================
  // Rozmerove pole prijme zakladnu matematiku: 650-36, 3*600+2*18, (2070-3*18)/4.
  // Podpora: + - * / ( ), unarne minus, desatinna CIARKA aj bodka. ZIADNE eval —
  // vlastny rekurzivny parser. Ziadne jednotky, percenta ani tisicove oddelovace
  // (1.500,5 sa ODMIETNE — pri slovenskom vstupe je bezpecnejsie odmietnutie nez
  // nespravny rozmer). Delenie nulou / nespotrebovany zvysok vstupu -> NaN.
  //
  // POLITIKA APLIKOVANIA (Codex audit expr, schvalene Michalom 18.7.):
  //   - ciste cislo: sprava sa ako doteraz (debounce auto-apply)
  //   - VYRAZ: pocas pisania LEN sivy zivy nahlad "= 614" (ziadny apply — medzistav
  //     "650-3" je validny vyraz s inou hodnotou!); APLIKUJE sa az Enter/blur,
  //     ktory pole PREPISE vysledkom a spusti normalny tok s cistym cislom.
  //   - surovy vyrazovy string NIKDY neopusta JS (parseFloat aj Ruby to_f by ho
  //     ticho orezali na prve cislo) — zbery citaju evalDim.

  function evalDim(str){
    if (str === null || str === undefined) return NaN;
    var s = String(str).trim();
    if (!s) return NaN;
    var pos = 0;
    function skipWs(){ while (pos < s.length && s[pos] === ' ') pos++; }
    function number(){
      skipWs();
      var m = /^[0-9]+([.,][0-9]+)?/.exec(s.slice(pos));
      if (!m) return NaN;
      pos += m[0].length;
      return parseFloat(m[0].replace(',', '.'));
    }
    function factor(){
      skipWs();
      var c = s[pos];
      if (c === '-'){ pos++; return -factor(); }
      if (c === '+'){ pos++; return factor(); }
      if (c === '('){
        pos++;
        var v = expr();
        skipWs();
        if (s[pos] !== ')') return NaN;
        pos++;
        return v;
      }
      return number();
    }
    function term(){
      var v = factor();
      for (;;){
        skipWs();
        var c = s[pos];
        if (c === '*'){ pos++; v *= factor(); }
        else if (c === '/'){ pos++; v /= factor(); }
        else return v;
      }
    }
    function expr(){
      var v = term();
      for (;;){
        skipWs();
        var c = s[pos];
        if (c === '+'){ pos++; v += term(); }
        else if (c === '-'){ pos++; v -= term(); }
        else return v;
      }
    }
    var out = expr();
    skipWs();
    if (pos !== s.length) return NaN; // cely vstup musi byt spotrebovany
    return (typeof out === 'number' && isFinite(out)) ? out : NaN;
  }

  // Je retazec VYRAZ (nie len ciste cislo)? Operator/zatvorka, alebo minus
  // inde nez na zaciatku (unarne -36 je este "cislo").
  function isExprStr(str){
    var s = String(str == null ? '' : str);
    return /[+*/()]/.test(s) || s.indexOf('-', 1) > 0;
  }

  // Ma element zapnutu vyrazovu podporu? (attachExprField znaci data-expr)
  function isExprInput(elm){
    return !!(elm && elm.getAttribute && elm.getAttribute('data-expr') === '1');
  }

  // Zaokruhlenie commitnutej hodnoty (2 des. miesta — mm Float kontrakt drzi).
  function roundDim(v){ return Math.round(v * 100) / 100; }

  // Vyhodnot a PREPIS pole vysledkom. true = pole nesie platne cislo.
  function commitExprEl(elm){
    var v = evalDim(elm.value);
    if (isNaN(v)){
      if (String(elm.value).trim() !== '') elm.classList.add('bad');
      return false;
    }
    elm.classList.remove('bad');
    elm.value = String(roundDim(v));
    updateExprHint(elm);
    return true;
  }

  // Zivy nahlad "= 614" — sivy span hned za inputom (injektuje sa raz, ziadne HTML upravy).
  function updateExprHint(elm){
    var hint = elm.nextElementSibling;
    if (!hint || !hint.classList || !hint.classList.contains('exprhint')){
      hint = document.createElement('span');
      hint.className = 'exprhint';
      elm.insertAdjacentElement('afterend', hint);
    }
    var s = elm.value;
    if (isExprStr(s)){
      var v = evalDim(s);
      hint.textContent = isNaN(v) ? '= ?' : '= ' + roundDim(v);
      hint.style.display = '';
    } else {
      hint.textContent = '';
      hint.style.display = 'none';
    }
  }

  // Sipky na textovom poli: +-1 mm (Shift +-10). Zmenu ohlasi SYNTETICKY event
  // (kazde pole ma vlastny tok: onField / onBoardField inline, zony change delegaciu).
  function stepExprField(elm, delta, evName){
    var v = evalDim(elm.value);
    if (isNaN(v)) v = 0;
    elm.value = String(roundDim(v + delta));
    updateExprHint(elm);
    elm.dispatchEvent(new Event(evName || 'input', { bubbles: true }));
  }

  // Pripoji vyrazove spravanie: hint pri pisani, Enter/blur commit, sipky.
  // commitEv: event po commite ('input' pre onField/onBoardField polia,
  // 'change' pre delegovane zonove polia). flushFn: okamzity apply po Enter.
  function attachExprField(elm, opts){
    if (!elm || elm.getAttribute('data-expr') === '1') return;
    opts = opts || {};
    elm.setAttribute('data-expr', '1');
    if (elm.getAttribute('type') === 'number') elm.setAttribute('type', 'text');
    elm.addEventListener('input', function(){ updateExprHint(elm); });
    elm.addEventListener('blur', function(){
      if (isExprStr(elm.value) && commitExprEl(elm)){
        elm.dispatchEvent(new Event(opts.commitEv || 'input', { bubbles: true }));
      }
    });
    elm.addEventListener('keydown', function(ev){
      if (ev.key === 'Enter'){
        ev.preventDefault();
        if (commitExprEl(elm)){
          elm.dispatchEvent(new Event(opts.commitEv || 'input', { bubbles: true }));
          if (opts.flushFn) opts.flushFn();
        }
      } else if (ev.key === 'ArrowUp'){
        ev.preventDefault();
        stepExprField(elm, ev.shiftKey ? 10 : 1, opts.commitEv || 'input');
      } else if (ev.key === 'ArrowDown'){
        ev.preventDefault();
        stepExprField(elm, ev.shiftKey ? -10 : -1, opts.commitEv || 'input');
      }
    });
  }

  // Node testy (tests/js/test_expr.js) — v CEF je module undefined, vetva sa preskoci.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { evalDim: evalDim, isExprStr: isExprStr, roundDim: roundDim };
  }
