/*!
 * Noxun Engine — icons.js — inline SVG ikonovy sprite (UI chrome panela).
 * Synchronny script v retazci panel.html: pri parse injektuje skryty sprite
 * kontajner na zaciatok <body> (VLASTNY div, insertAdjacentElement — NIKDY
 * document.body.innerHTML +=), takze <use href="#i-…"> funguje pred prvym
 * renderom aj pred sketchup.ready() (boot.js). Helper zije v samostatnom
 * globali window.NXIcons (NEmiesa sa s window.NX z bridge.js).
 *
 * Ikony su prekreslene v style Lucide (24x24, stroke-2, currentColor). Logo
 * (#i-logo) je vlastny firemny symbol renderovany FILL-om (trieda .nx-logo).
 *
 * ---------------------------------------------------------------------------
 * Ikonovy podklad: Lucide (https://lucide.dev) — fork Feather Icons.
 * Plne znenia licencii su aj v THIRD_PARTY_NOTICES.md v koreni repozitara.
 *
 * Lucide — ISC License
 *
 *   ISC License
 *
 *   Copyright (c) 2020, Lucide Contributors
 *
 *   Permission to use, copy, modify, and/or distribute this software for any
 *   purpose with or without fee is hereby granted, provided that the above
 *   copyright notice and this permission notice appear in all copies.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Feather (podiel na fork-u) — MIT License
 *
 *   MIT License
 *
 *   Copyright (c) 2013-2023 Cole Bemis
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in all
 *   copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *   SOFTWARE.
 * ---------------------------------------------------------------------------
 */
(function () {
  // Lucide-style symboly (viewBox 24x24, stroke-2, currentColor cez .ic).
  // Kazdy symbol drzi LEN geometriu — farbu/hrubku dava .ic (stroke) v CSS.
  var LUCIDE = {
    'maximize': '<path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M21 8V5a2 2 0 0 0-2-2h-3"/><path d="M3 16v3a2 2 0 0 0 2 2h3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/>',
    'alert': '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    'lock': '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    'lock-open': '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/>',
    'eye': '<path d="M2.06 12.35a1 1 0 0 1 0-.7 10.75 10.75 0 0 1 19.88 0 1 1 0 0 1 0 .7 10.75 10.75 0 0 1-19.88 0"/><circle cx="12" cy="12" r="3"/>',
    'eye-off': '<path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 11 7 11 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.53 13.53 0 0 0 1 12s4 7 11 7a9.74 9.74 0 0 0 5.39-1.61"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/><path d="m2 2 20 20"/>',
    'copy': '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    'factory': '<path d="M2 20a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8l-7 5V8l-7 5V4a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/><path d="M17 18h1"/><path d="M12 18h1"/><path d="M7 18h1"/>',
    'settings': '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2Z"/><circle cx="12" cy="12" r="3"/>',
    'star': '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
    'rotate-ccw': '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
    'x': '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    'plus': '<path d="M5 12h14"/><path d="M12 5v14"/>',
    'check': '<path d="M20 6 9 17l-5-5"/>',
    'chevron-right': '<path d="m9 18 6-6-6-6"/>',
    'link': '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
    'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    'arrow-left': '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
    // D-83: „Nahradiť UNI…" priamo z riadku KONTROLY (okno Vyroba) —
    // vymena jedneho materialu za iny.
    'arrow-left-right': '<path d="m8 3-4 4 4 4"/><path d="M4 7h16"/><path d="m16 21 4-4-4-4"/><path d="M20 17H4"/>',
    'trash': '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6"/><path d="M14 11v6"/>',
    'pencil': '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>',
    // 2A-4b (D-47): rezimove taby + satelitne akcie hlavicky panela
    'box': '<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
    'layout-grid': '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/>',
    'columns-2': '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M12 3v18"/>',
    'layers': '<path d="M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/><path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/><path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/>',
    // D-91: satelitna akcia "Kovanie" v hlavicke panela (otvara Katalog kovania)
    'wrench': '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
    // 2A-4b (okno Materialy): universal toggle ABS pasky + info banner
    'globe': '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
    'info': '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    // V0.6 B-2b (okno Materialy): tlacidlo "Aktualizovat z Demosu" v detaile dekoru
    'refresh-cw': '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
    // V0.6 M-A2 (okno Materialy): primarne tlacidlo "Pridat z Demosu"
    'cloud-download': '<path d="M12 13v8l-4-4"/><path d="m12 21 4-4"/><path d="M4.393 15.269A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.436 8.284"/>',
    // M-A3b (D-60): vazba na Demos v riadku variantu — "Otvorit u dodavatela"
    'external-link': '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
    // V0.6 E-b (tab Rozpocet): "⋯" dalsie udaje riadku (kod/URL/poznamka)
    // a "⬇" export suboru — nahradzaju glyfy z mocku (ziadne emoji v UI chrome).
    'more-horizontal': '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
    'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M7 10l5 5 5-5"/><path d="M12 15V3"/>',
    // V0.6 D-90: uchytkovy profil na hornej hrane cela (vlastny symbol) —
    // lista profilu cez celu sirku + celo pod nou.
    'profile': '<rect x="2" y="3" width="20" height="5" rx="1.5"/><path d="M6 8v13h12V8"/>'
  };

  // Firemne logo — prstenec + krizove ramena. Renderuje sa FILL-om (.nx-logo),
  // NEdedi stroke-only pravidla .ic ikon.
  var LOGO = '<symbol id="i-logo" viewBox="0 0 100 100">' +
    '<g fill="currentColor">' +
    '<rect x="46.5" y="10" width="7" height="80"/>' +
    '<polygon points="50,0 58,9 50,18 42,9"/>' +
    '<polygon points="50,82 58,91 50,100 42,91"/>' +
    '<rect x="10" y="46.5" width="80" height="7"/>' +
    '<polygon points="0,50 14,41 14,59"/>' +
    '<polygon points="100,50 86,41 86,59"/>' +
    '<path d="M50 31a19 19 0 1 0 0 38a19 19 0 1 0 0-38Zm0 9a10 10 0 1 1 0 20a10 10 0 1 1 0-20Z" fill-rule="evenodd"/>' +
    '</g></symbol>';

  function buildSprite() {
    var s = '';
    for (var id in LUCIDE) {
      if (Object.prototype.hasOwnProperty.call(LUCIDE, id)) {
        s += '<symbol id="i-' + id + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
             'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + LUCIDE[id] + '</symbol>';
      }
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" style="position:absolute" aria-hidden="true">' +
           s + LOGO + '</svg>';
  }

  function inject() {
    if (document.getElementById('nx-icon-sprite')) return;
    var box = document.createElement('div');
    box.id = 'nx-icon-sprite';
    box.setAttribute('aria-hidden', 'true');
    box.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden';
    box.innerHTML = buildSprite();
    document.body.insertAdjacentElement('afterbegin', box);
  }

  // Skripty su na konci <body> — document.body existuje pri parse. Guard pre istotu.
  if (document.body) inject();
  else document.addEventListener('DOMContentLoaded', inject);

  // Helper — samostatny globalny namespace (Codex B8).
  window.NXIcons = {
    // Inline SVG markup pre symbol spritu. cls prida dalsie triedy. VRACIA len
    // staticky retazec (ziadne pouzivatelske data) — bezpecne do innerHTML.
    svg: function (id, cls) {
      return '<svg class="ic' + (cls ? ' ' + cls : '') + '" aria-hidden="true"><use href="#i-' + id + '"/></svg>';
    },
    // Prepne symbol v EXISTUJUCOM <use> (alebo v kontajneri s <use>) — meni len
    // href, nie cely element (Codex B3 — nemenit textContent tlacidiel).
    set: function (node, id) {
      if (!node) return;
      var u = (node.tagName && node.tagName.toLowerCase() === 'use') ? node : node.querySelector('use');
      if (u) u.setAttribute('href', '#i-' + id);
    }
  };
})();
