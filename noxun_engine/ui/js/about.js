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
  //
  // D-52b: k spoločnému obsahu pribudol UPDATER (pole distribučného priečinka,
  // stavový riadok, tlačidlo „Aktualizovať"). Renderuje sa VÝHRADNE pre
  // ŠTÚDIOVÝ vstup — volajúci ho vypýta tým, že podá stav updatera druhým
  // argumentom; koliesko Inspectora ho nepodáva a prvky sa v ňom neobjavia.
  // Je to VEDOMÁ ODCHÝLKA od zapísaného „sup/about sú čítanie" (dôvod aj
  // hranice sú v docs/architecture/ui-lifecycle.md): tlačidlo, ktoré zatvorí
  // obe okná a prepíše súbory pluginu, patrí do jedného miesta — a mŕtve
  // tlačidlo v druhom vstupe by bolo D-78.

  function nxAboutEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // Stavový riadok updatera. TROJSTAV z jadra D-52a (`Updater.classify`) plus
  // dva prevádzkové stavy: `checking` (beží dotaz na zdroj) a `error`
  // (zdroj sa nedá prečítať — hláška MUSÍ niesť cestu aj dôvod).
  // Texty skladá klient, server posiela čistý stav a čísla.
  function nxUpdaterText(u){
    var d = u || {};
    var cur = d.current ? ('V' + d.current) : '—';
    var av = d.available ? ('V' + d.available) : 'novšia verzia';
    var dir = d.source_dir || '';
    if (d.enabled === false) return 'Aktualizátor nie je načítaný — reštartuj SketchUp.';
    if (d.locked) return 'Plugin je už aktualizovaný — reštartuj SketchUp.';
    // ROZPÍSANÁ, NEULOŽENÁ cesta: stav v riadku patrí ešte tomu, čo je uložené,
    // a aktualizovalo by sa z NEHO — nie z toho, čo je práve v poli. Klik by
    // teda spravil niečo iné, než čo človek vidí, takže sa najprv ukladá.
    if (d.dirty){
      // Uložená cesta sa MENUJE: kontrola aj prípadné aktualizovanie patria
      // JEJ, nie tomu, čo je práve rozpísané v poli.
      return 'Cesta nie je uložená — ulož ju (Enter alebo tlačidlo Uložiť), potom sa overí verzia.' +
             (d.saved_dir ? ' Uložená je „' + d.saved_dir + '".' : '');
    }
    switch (String(d.state || 'idle')){
      case 'checking':
        return 'Kontrolujem priečinok ' + dir + '…';
      case 'newer':
        return 'K dispozícii je ' + av + ' (beží ' + cur + ').';
      case 'same':
        return 'Máš aktuálnu verziu (' + cur + ').';
      case 'older':
        // B4: downgrade je vo V1 zakázaný — samotné VERSION nehovorí nič
        // o tom, či staršia verzia rozumie dátam, ktoré nová už zapísala.
        return 'V priečinku je staršia verzia ' + av + ' (beží ' + cur +
               ') — staršiu verziu nainštaluj ručne cez INSTALL.';
      case 'error':
        return 'Zdroj sa nedá prečítať (' + dir + '): ' + (d.reason || 'neznámy dôvod') + '.';
      default:
        return dir
          ? 'Priečinok je uložený — otvor sekciu znova alebo ulož cestu, nech sa overí verzia.'
          : 'Zadaj priečinok s kópiou pluginu (noxun_engine.rb + noxun_engine\\) a ulož ho.';
    }
  }

  // Tlačidlo je AKTÍVNE výhradne pri `newer`. Ostatné stavy ho nechávajú
  // `aria-disabled` (nikdy HTML `disabled`, vzor D-78) — ostáva zamerateľné
  // a klik povie dôvod.
  function nxUpdaterEnabled(u){
    var d = u || {};
    return d.enabled !== false && !d.locked && !d.dirty && String(d.state) === 'newer';
  }

  function nxUpdaterHtml(u){
    var d = u || {};
    var dir = nxAboutEsc(d.source_dir || '');
    var on = nxUpdaterEnabled(d);
    return '<div class="updbox">' +
      '<div class="updrow">' +
        '<label class="updlbl" for="updDir">Distribučný priečinok</label>' +
        '<input id="updDir" type="text" class="updinp" data-updater-edit="source_dir"' +
          ' value="' + dir + '" spellcheck="false"' +
          ' placeholder="napr. \\\\server\\noxun\\dist"' +
          ' title="Priečinok s kópiou pluginu (noxun_engine.rb + noxun_engine\\).' +
          ' Ulož Enterom alebo tlačidlom vedľa." />' +
        '<button type="button" class="ghostbtn" data-updater-act="save-dir"' +
          ' title="Uložiť cestu (rovnako ako Enter v poli)">' +
          '<svg class="ic" aria-hidden="true"><use href="#i-check"/></svg> Uložiť</button>' +
      '</div>' +
      '<div class="updrow">' +
        '<span class="updstate" id="updState">' + nxAboutEsc(nxUpdaterText(d)) + '</span>' +
        '<button type="button" class="primary" id="updBtn" data-updater-act="apply"' +
          (on ? '' : ' aria-disabled="true"') +
          ' title="' + nxAboutEsc(on ? 'Zatvorí Inspector aj Štúdio a nasadí novú verziu'
                                     : nxUpdaterText(d)) + '">' +
          '<svg class="ic" aria-hidden="true"><use href="#i-cloud-download"/></svg> Aktualizovať</button>' +
      '</div></div>';
  }

  // `info` = { version, dir }. Chýbajúci priečinok padne na kontraktovú cestu
  // (to, čo v koliesku stálo natvrdo do ŠT-4a) — obsah tak nikdy nezmizne.
  // `updater` = stav updatera; keď chýba (koliesko Inspectora), updater sa
  // NEKRESLÍ vôbec.
  function nxAboutHtml(info, updater){
    var d = info || {};
    var ver = d.version ? ('V' + nxAboutEsc(d.version)) : '…';
    var dir = d.dir ? nxAboutEsc(d.dir) : '%APPDATA%\\NOXUN\\Engine';
    return '<div class="aboutrow">' +
      '<svg class="nx-logo aboutlogo" viewBox="0 0 100 100" aria-hidden="true"><use href="#i-logo"/></svg>' +
      '<div><div class="aboutname">Noxun Engine <span id="cfgVersion">' + ver + '</span></div>' +
      '<div class="hint">Parametrický nábytkársky systém pre SketchUp. ' +
      'Nastavenia tohto počítača žijú v <b>' + dir + '</b>.</div></div></div>' +
      (updater ? nxUpdaterHtml(updater) : '');
  }

  // Vloží obsah do uzla (id alebo element). Vracia true, keď sa naozaj kreslilo
  // — volajúci vie, či uzol vôbec existuje.
  function nxAboutFill(node, info, updater){
    var n = (typeof node === 'string' && typeof document !== 'undefined')
      ? document.getElementById(node) : node;
    if (!n) return false;
    n.innerHTML = nxAboutHtml(info, updater);
    return true;
  }

  if (typeof window !== 'undefined'){
    window.nxAboutHtml = nxAboutHtml;
    window.nxAboutFill = nxAboutFill;
    window.nxUpdaterText = nxUpdaterText;
    window.nxUpdaterEnabled = nxUpdaterEnabled;
  }

  // Node testy (tests/js/test_st4a_settings.js, tests/js/test_d52b_updater_ui.js).
  if (typeof module !== 'undefined' && module.exports){
    module.exports = { nxAboutHtml: nxAboutHtml, nxAboutFill: nxAboutFill, nxAboutEsc: nxAboutEsc,
                       nxUpdaterHtml: nxUpdaterHtml, nxUpdaterText: nxUpdaterText,
                       nxUpdaterEnabled: nxUpdaterEnabled };
  }
