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
    'trash': '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6"/><path d="M14 11v6"/>',
    'pencil': '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>'
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
