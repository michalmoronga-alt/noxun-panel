// Noxun Engine — D-77: okno sa nesmie otvorit odseknute.
//
// PRICINA: HtmlDialog si pamata poslednu velkost per `preferences_key`. Ked
// zostala z minula mensia, nez obsah potrebuje (alebo okno vzniklo v starsej
// verzii pluginu s mensimi rozmermi), otvori sa orezane a pouzivatel ho musi
// rucne zvacsovat. `width`/`height` v konstruktore su LEN prve otvorenie —
// zapamatanu velkost nikdy neprepisu; `min_width`/`min_height` chrania len
// rucne zmensovanie.
//
// RIESENIE: kazde okno po nacitani HTML ohlasi svoj VIEWPORT a Ruby ho cez
// `set_size` dorovna. Pravidla su zamerne konzervativne:
//   - LEN smerom NAHOR (okno sa nikdy samo nezmensi — vacsie okno je vedoma
//     volba pouzivatela a musi prezit),
//   - LEN po deklarovane minimum okna (`window.NX_FIT_MIN`, obsahove px),
//   - NIKDY nad dostupnu plochu obrazovky (maly monitor rozhoduje),
//   - LEN RAZ pri nacitani (nie pri zmene obsahu — okno by pod rukami skakalo).
// Ramik a titulok okna sa dopocitaju z rozdielu outer/inner, aby `set_size`
// (vonkajsi rozmer) skutocne dal ziadany obsahovy priestor — inak by sa fit
// pri kazdom otvoreni opakoval a k minimu by sa nikdy nedostal.
'use strict';

// Tolerancia zaokruhlenia (CEF vracia inner rozmery aj s desatinami pri DPI
// skalovani) — bez nej by fit bezal aj pri rozdiele 1 px.
var NX_FIT_TOL = 2;
// Zaloha, ked prehliadac outer rozmery neposkytne (typicky ramik + titulok
// okna na Windows). Radsej o par px vacsie okno nez trvale odseknute.
var NX_FIT_CHROME_FALLBACK = { w: 16, h: 40 };

// Ciste jadro (testovane v tests/js/test_d77_okno_fit.js).
// cur/min/avail/chrome = { w, h }; vracia VONKAJSI rozmer okna alebo null,
// ked netreba nic robit.
function nxFitTarget(cur, min, avail, chrome){
  if (!cur || !min) return null;
  var cw = Number(cur.w), ch = Number(cur.h);
  var mw = Number(min.w), mh = Number(min.h);
  // Nemerany viewport (0, NaN) = nevieme nic — do velkosti okna sa nesiaha.
  if (!(cw > 0) || !(ch > 0)) return null;
  if (!(mw > 0) || !(mh > 0)) return null;

  var kw = chrome && Number(chrome.w) > 0 ? Number(chrome.w) : 0;
  var kh = chrome && Number(chrome.h) > 0 ? Number(chrome.h) : 0;
  var aw = avail && Number(avail.w) > 0 ? Number(avail.w) : 0;
  var ah = avail && Number(avail.h) > 0 ? Number(avail.h) : 0;

  // Ciel = minimum, ale nikdy viac, nez sa zmesti na obrazovku.
  var wantW = aw > 0 ? Math.min(mw, Math.max(1, aw - kw)) : mw;
  var wantH = ah > 0 ? Math.min(mh, Math.max(1, ah - kh)) : mh;

  if (cw + NX_FIT_TOL >= wantW && ch + NX_FIT_TOL >= wantH) return null;

  return {
    w: Math.round(Math.max(cw, wantW) + kw),
    h: Math.round(Math.max(ch, wantH) + kh)
  };
}

// Ramik okna z rozdielu outer/inner; ked hodnoty nedavaju zmysel, zaloha.
function nxFitChrome(win){
  var w = win && Number(win.outerWidth) - Number(win.innerWidth);
  var h = win && Number(win.outerHeight) - Number(win.innerHeight);
  return {
    w: (w > 0 && w < 200) ? w : NX_FIT_CHROME_FALLBACK.w,
    h: (h > 0 && h < 300) ? h : NX_FIT_CHROME_FALLBACK.h
  };
}

function nxFitRun(){
  try {
    if (typeof window === 'undefined' || !window.NX_FIT_MIN) return;
    if (typeof sketchup === 'undefined' || !sketchup.nx_fit) return;
    var scr = window.screen || {};
    var target = nxFitTarget(
      { w: window.innerWidth, h: window.innerHeight },
      window.NX_FIT_MIN,
      { w: scr.availWidth, h: scr.availHeight },
      nxFitChrome(window)
    );
    if (target) sketchup.nx_fit(target.w, target.h);
  } catch (e) {
    // Velkost okna nesmie zhodit obsah — chyba ide do konzoly a koniec.
    if (typeof console !== 'undefined' && console.log) console.log('nx_fit: ' + e);
  }
}

if (typeof document !== 'undefined'){
  if (document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', nxFitRun);
  } else {
    nxFitRun();
  }
}

// Node testy — v CEF je module undefined, vetva sa preskoci.
if (typeof module !== 'undefined' && module.exports){
  module.exports = { nxFitTarget: nxFitTarget, nxFitChrome: nxFitChrome };
}
