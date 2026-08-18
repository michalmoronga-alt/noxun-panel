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
    // D-105: pravá polovica split tlačidla „Zvýrazniť hrany" — otvára nastavenie
    // stavov (rozbaľovacie okno pod tlačidlom).
    'chevron-down': '<path d="m6 9 6 6 6-6"/>',
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
    // UI-C2: dlazdice delenia zony (2/3 stlpce, 2/3 riadky) + pocet polic.
    // Ikona JE odpoved na otazku „co sa stane" — text je len potvrdenie.
    'columns-3': '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 3v18"/><path d="M15 3v18"/>',
    'rows-2': '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 12h18"/>',
    'rows-3': '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M3 15h18"/>',
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
    'profile': '<rect x="2" y="3" width="20" height="5" rx="1.5"/><path d="M6 8v13h12V8"/>',
    // ===== UI-B1: rail Inspectora (kontexty + funkcie) =========================
    // Prevzate 1:1 z mockupu SYSTEM/zdroje/ui20/mockup_inspector_c.html — rovnaky
    // Lucide styl (24x24, stroke-2). 'cabinet'/'front'/'slab' su vlastne symboly
    // (Lucide nema nabytkarske tvary), 'hammer' a 'shell' su Lucide originaly.
    'cabinet': '<rect x="4" y="3" width="16" height="15" rx="1"/><path d="M12 3v15"/><path d="M6 21v-3"/><path d="M18 21v-3"/><path d="M9.5 10h.01"/><path d="M14.5 10h.01"/>',
    'front': '<rect x="4" y="3" width="16" height="18" rx="1"/><rect x="8" y="7" width="8" height="2" rx="1"/>',
    'hammer': '<path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18.5 14.5"/>',
    'shell': '<path d="M14 11a2 2 0 1 1-4 0 4 4 0 0 1 8 0 6 6 0 0 1-12 0 8 8 0 0 1 16 0 10 10 0 1 1-20 0 11.93 11.93 0 0 1 2.42-7.22 2 2 0 1 1 3.16 2.44"/>',
    'slab': '<rect x="2" y="6" width="20" height="12" rx="1.5"/><path d="M2 10h20"/>',
    // UI-B2: kamera N7 v spodnom pase nahladu — zarovna pohlad SketchUpu na skrinku
    'camera': '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>',
    // ===== UI-B3: rozmery Zakladnych + ikony skupin Korpusu ====================
    // Prevzate 1:1 z mockupu SYSTEM/zdroje/ui20/mockup_inspector_c.html. Sipky
    // su smerove (sirka/vyska/hlbka), 'plinth' a 'p-*' su VLASTNE nabytkarske
    // symboly (Lucide ich nema) — panel dielca vo svojej polohe.
    'arr-h': '<path d="M8 8 4 12l4 4"/><path d="m16 8 4 4-4 4"/><path d="M4 12h16"/>',
    'arr-v': '<path d="m8 8 4-4 4 4"/><path d="m8 16 4 4 4-4"/><path d="M12 4v16"/>',
    'arr-d': '<path d="M18 6 6 18"/><path d="M6 11v7h7"/><path d="M18 13V6h-7"/>',
    // Sokel: korpus so soklovym pasom dole (pas je PLNY — je to jediny prvok,
    // ktory ikona meria).
    'plinth': '<rect x="4" y="3" width="16" height="13" rx="2"/><rect x="6" y="19" width="12" height="3" rx="1" fill="currentColor" stroke="none"/>',
    // Skupiny Nastaveni (N3b): zvyrazneny je dielec, o ktorom skupina hovori.
    'p-top': '<rect x="3" y="4" width="18" height="4"/><path d="M5 8v12"/><path d="M19 8v12"/>',
    'p-bottom': '<rect x="3" y="16" width="18" height="4"/><path d="M5 4v12"/><path d="M19 4v12"/>',
    'p-side': '<rect x="3" y="4" width="4" height="16"/><rect x="17" y="4" width="4" height="16"/><path d="M7 6h10"/><path d="M7 18h10"/>',
    'p-back': '<rect x="4" y="4" width="16" height="16"/><path d="m4 20 16-16"/>',
    // Koliesko -> sekcia Vzhlad (prepinac temy NOXUN / Lucia).
    'palette': '<path d="M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z"/><circle cx="13.5" cy="6.5" r=".5"/><circle cx="17.5" cy="10.5" r=".5"/><circle cx="6.5" cy="12.5" r=".5"/><circle cx="8.5" cy="7.5" r=".5"/>',
    // 'brace' (vystuhy) patri skupine, ktora vznikne az pri rozdeleni Korpusu
    // v bloku UI-C — symbol je tu, aby sa mapa GRPICON z mockupu nemusela
    // dopisovat po castiach.
    'brace': '<rect x="4" y="5" width="16" height="3"/><rect x="4" y="11" width="16" height="3"/><path d="M4 20h16"/>',
    // ===== UI-C1b: typ vkladaneho objektu (3 segmentove tlacidla) =============
    // Prevzate 1:1 z mockupu SYSTEM/zdroje/ui20/mockup_inspector_c.html. Ikona
    // ukazuje, KDE objekt stoji: 'cab-low' = skrinka na sokli (nohy/sokel pod
    // korpusom), 'cab-high' = zavesena skrinka (zavesna lista nad korpusom).
    // Tretim typom je doska — ta ma uz vlastny symbol 'slab' (rail UI-B1).
    'cab-low': '<rect x="4" y="4" width="16" height="12" rx="1"/><path d="M12 4v12"/><path d="M9.5 9h.01"/><path d="M14.5 9h.01"/><rect x="6" y="18" width="12" height="3" rx="1" fill="currentColor" stroke="none"/>',
    'cab-high': '<path d="M3 3h18"/><path d="M7 3v3"/><path d="M17 3v3"/><rect x="4" y="6" width="16" height="12" rx="1"/><path d="M12 6v12"/><path d="M9.5 15h.01"/><path d="M14.5 15h.01"/>',
    // ===== UI-C1c: orientacia dosky (3 segmentove tlacidla) ==================
    // Vlastne symboly (Lucide nabytkarske polohy nema) — vzdy je v nich PODLAHA
    // (vodorovna ciara dole), aby bolo vidno, ako doska v modeli stoji:
    //   ori-lying = doska lezi naplocho · ori-stand = stoji na dlhej hrane ·
    //   ori-wall  = stoji pri stene (zvisla ciara vzadu = stena).
    'ori-lying': '<rect x="3" y="12" width="18" height="5" rx="1"/><path d="M2 21h20"/>',
    'ori-stand': '<rect x="9" y="5" width="6" height="16" rx="1"/><path d="M2 21h20"/>',
    'ori-wall': '<path d="M5 2v19"/><rect x="8" y="5" width="6" height="16" rx="1"/><path d="M2 21h20"/>'
  };

  // Firemne logo — ZROLOVANA ZNACKA z ORIGINALNYCH kriviek webu (pismena
  // posunute do spolocneho stredu, X rotovane o 45°). Krivky su TIE ISTE ako
  // v ui/icons/noxun_logo.svg (toolbar) — zhodu strazi test_ui02_toolbar.rb;
  // lisi sa LEN viewBox: toolbarova ikona ma navyse ~12 % vnutorny okraj, aby
  // v tlacidle nelicovala s jeho hranou, sprite v HTML ho nepotrebuje.
  // Renderuje sa FILL-om (.nx-logo), NEdedi stroke-only pravidla .ic ikon.
  var LOGO = '<symbol id="i-logo" viewBox="7071.5 11779.5 6054 6054">' +
    '<g fill="currentColor">' +
    '<g transform="translate(6842.5 56)"><path d="M4814 14749c0,521 0,1041 0,1561 -145,0 -291,0 -436,0 0,-517 0,-1035 0,-1552l436 -9zm0 3c-12,-788 -622,-1561 -1566,-1556 -944,6 -1549,792 -1550,1556l0 100 0 1458 433 0 0 -1474 0 -84c21,-630 497,-1124 1124,-1136 577,-12 1127,493 1123,1146l436 -10z"/></g>' +
    '<g transform="translate(3466.5 59.5)"><path d="M8203 14742c0,-9 0,-7 -1,-16 -25,-784 -637,-1547 -1578,-1542 -951,6 -1562,787 -1563,1558l437 -1c21,-635 501,-1121 1133,-1134 569,-11 1113,476 1132,1114 0,14 0,5 0,19l440 2zm-3142 -1c12,794 627,1574 1579,1569 951,-5 1562,-798 1563,-1568l-437 0c-21,634 -501,1132 -1133,1145 -568,12 -1112,-473 -1134,-1107 0,-16 -2,-23 -2,-39l-436 0z"/></g>' +
    '<g transform="rotate(45 10098.5 14806.5) translate(222 0)"><polygon points="7673,12911 8290,12911 9876,14498 11463,12911 12080,12911 10185,14806 12080,16702 11464,16702 9876,15114 8289,16702 7673,16702 9568,14806"/></g>' +
    '<g transform="translate(-3489.5 -25)"><path d="M12030 14746c0,-520 0,-868 0,-1388 145,0 290,0 436,0 0,517 0,863 0,1380l-436 8zm0 -2c12,787 622,1561 1565,1555 944,-5 1550,-791 1551,-1555l0 -100 0 -1286 -433 0 0 1302 0 84c-21,630 -497,1123 -1124,1136 -577,12 -1128,-493 -1123,-1146l-436 10z"/></g>' +
    '<g transform="translate(-6842.5 61)"><path d="M18499 14744c0,520 0,1040 0,1561 -145,0 -291,0 -436,0 0,-518 0,-1035 0,-1553l436 -8zm0 2c-12,-787 -622,-1560 -1566,-1555 -943,5 -1549,791 -1550,1555l0 100 0 1459 433 0 0 -1475 0 -84c21,-629 497,-1123 1124,-1136 577,-12 1127,494 1123,1146l436 -10z"/></g>' +
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
