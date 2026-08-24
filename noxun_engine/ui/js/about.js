  // ================= „O PLUGINE" — JEDEN OBSAH, DVA VSTUPY =================
  //
  // Kontrakt Š19: „O plugine = zrkadlo obsahu kolieska Inspectora (jeden
  // obsah, dva vstupy)." ZRKADLO sa nedá dosiahnuť kópiou markupu do druhého
  // okna — dve kópie sa pri prvej úprave rozídu a používateľ uvidí dva rôzne
  // „O plugine". Markup preto stavia TENTO súbor a načítavajú si ho OBA
  // vstupy: koliesko Inspectora (`panel.html`) aj sekcia `about` Štúdia.
  //
  // Dáta dáva VÝHRADNE server (verzia, priečinok nastavení) — žiadny hardcode
  // verzie v HTML (zásada UI-B3: verzia má jediný zdroj, `Engine::VERSION`).
  //
  // XSS: hodnoty idú cez `nxAboutEsc` — priečinok je síce cesta zo servera,
  // ale do HTML sa NIKDY nevkladá surový reťazec.

  function nxAboutEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // `info` = { version, dir }. Chýbajúci priečinok padne na kontraktovú cestu
  // (to, čo v koliesku stálo natvrdo do ŠT-4a) — obsah tak nikdy nezmizne.
  function nxAboutHtml(info){
    var d = info || {};
    var ver = d.version ? ('V' + nxAboutEsc(d.version)) : '…';
    var dir = d.dir ? nxAboutEsc(d.dir) : '%APPDATA%\\NOXUN\\Engine';
    return '<div class="aboutrow">' +
      '<svg class="nx-logo aboutlogo" viewBox="0 0 100 100" aria-hidden="true"><use href="#i-logo"/></svg>' +
      '<div><div class="aboutname">Noxun Engine <span id="cfgVersion">' + ver + '</span></div>' +
      '<div class="hint">Parametrický nábytkársky systém pre SketchUp. ' +
      'Nastavenia tohto počítača žijú v <b>' + dir + '</b>.</div></div></div>';
  }

  // Vloží obsah do uzla (id alebo element). Vracia true, keď sa naozaj kreslilo
  // — volajúci vie, či uzol vôbec existuje.
  function nxAboutFill(node, info){
    var n = (typeof node === 'string' && typeof document !== 'undefined')
      ? document.getElementById(node) : node;
    if (!n) return false;
    n.innerHTML = nxAboutHtml(info);
    return true;
  }

  if (typeof window !== 'undefined'){
    window.nxAboutHtml = nxAboutHtml;
    window.nxAboutFill = nxAboutFill;
  }

  // Node testy (tests/js/test_st4a_settings.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { nxAboutHtml: nxAboutHtml, nxAboutFill: nxAboutFill, nxAboutEsc: nxAboutEsc };
  }
