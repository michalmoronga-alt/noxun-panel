  // ============ NÁREZOVÝ PLÁN — sekcia `cut` Štúdia (NP-3, blok 2) ============
  //
  // Mockup A (prehľad: súhrn, karty materiálov, malé platne, upozornenia) a B
  // (detail jednej platne) v `SYSTEM/zdroje/bloky/NAREZ/MOCKUP_NAREZ_2026-09-28.html`.
  //
  // ZÁSADY:
  //   * SERVER je autorita čísel AJ viet: počet platní, využitie, polohy dielcov,
  //     najväčší zvyšok, veta o počte (`phrase` — tá istá ide do poznámky
  //     Rozpočtu a XLSX) aj dôvody nezaradenia (`t`). JS nič neprepočítava,
  //     len kreslí a jediné, čo si odvodzuje, je upozornenie na poslednú
  //     platňu (O2: aspoň 2 platne a posledná pod 20 % alebo najviac 2 dielce).
  //   * Klient si pamätá VÝHRADNE zobrazovacie veci tohto počítača/okna:
  //     zbalené karty (localStorage, vzor skupín Kusovníka) a otvorený detail
  //     platne (len pamäť okna).
  //   * Farby SVG sú VÝHRADNE triedy s tokenmi `--nx-*` (obe témy). Jediná
  //     dátová farba je vzorka dekoru (`rgbHex` z katalógu) — a tá je v HTML
  //     štvorčeku mimo SVG.
  //   * Výber v modeli ide existujúcou cestou `nx_select` s NATÍVNYM kľúčom
  //     riadku (`parts_key`) — nikdy pids. Označia sa VŠETKY rovnaké kusy (O3).
  //   * Všetky globálne mená majú prefix `np` — súbor zdieľa globálny priestor
  //     so studio.js, budget.js a ďalšími sekciami (nový kód sa nepomenúva
  //     `cut_*`, Codex C13).
  //
  // Súbor sa načítava AŽ ZA studio.js — lištu a telo sekcie volá studio.js cez
  // `typeof npRenderTools / npRenderBody` (vzor ostatných sekcií).

  var NP_STUDIO = (typeof module !== 'undefined' && module.exports) ? require('./studio.js') : null;
  var NP_CLOSED_KEY = 'nx_np_closed';
  var npClosed = null;   // { material_id: true|false } — výslovná voľba používateľa
  var npDetail = null;   // { mid, pi } — otvorený detail platne (stav okna)
  var npState = null;    // posledný `ST.sheet_layout` (Node testy ho nastavujú)

  // O2 (schválené 28.9.): upozornenie na poslednú platňu — využitie POD 20 %
  // alebo NAJVIAC 2 dielce, len keď má materiál aspoň 2 platne.
  var NP_WARN_UTIL = 20;
  var NP_WARN_PARTS = 2;
  var NP_THUMB_W = 164;
  var NP_DETAIL_W = 780;

  var NP_TIP_SUM = 'Horná hranica = s týmto rozložením (pásy zľava doprava) stačí N platní — len pri úplnom ' +
    'pláne so skutočným formátom z katalógu. VEPO optimalizuje sám a jeho počet sa môže líšiť.\n' +
    'Neúplný = niektorý dielec sa nezmestí alebo ho VEPO odmietne (neznáma ABS páska, chybná hrúbka, ' +
    'nulový rozmer) — počet platí len pre zaradené dielce, celkový je neznámy.\n' +
    'Orientačne = materiál bez formátu v katalógu alebo UNI (počítané na formáte 2800 × 2070), alebo ' +
    'nastavenia prerezu a orezu, ktoré sa nepodarilo načítať.\n' +
    'Odhad z m² je dnešný výpočet (+10 až 25 %) — toľko platní dnes počíta rozpočet.';
  var NP_TIP_ROT = 'Dielce sa neotáčajú — ako vo VEPO súbore. Počet je preto opatrnejší — nanajvýš o niečo ' +
    'vyšší, než keby sa dielce otáčali; počet VEPO sa môže líšiť.';

  // ------------------------------------------------------------- pomocníci
  function npEsc(s){
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function npIco(n, cls){
    return '<svg class="ic' + (cls ? ' ' + cls : '') + '" aria-hidden="true"><use href="#i-' + n + '"/></svg>';
  }
  function npTip(text, cls){
    return '<button type="button" class="nxtip' + (cls ? ' ' + cls : '') + '" data-tip="' + npEsc(text) +
      '" aria-label="' + npEsc(text) + '">' + npIco('help-circle') + '</button>';
  }
  // mm s desatinnou čiarkou: celé číslo bez desatín, inak jedno desatinné miesto.
  function npNf(v){
    var r = Math.round(Number(v) * 10) / 10;
    if (!isFinite(r)) return '—';
    return (r === Math.round(r) ? String(Math.round(r)) : r.toFixed(1)).replace('.', ',');
  }
  // Rozmer sa nesmie zalomiť na dva riadky (nezalomiteľné medzery ako escape).
  function npDim(a, b){ return npNf(a) + '\u00A0×\u00A0' + npNf(b); }
  function npPct(v){ return (v == null || isNaN(v)) ? '—' : Math.round(Number(v)) + ' %'; }
  function npPl(n, one, few, many){ var a = Math.abs(n); return a === 1 ? one : (a >= 2 && a <= 4 ? few : many); }
  function npSheets(n){ return n + ' ' + npPl(n, 'platňa', 'platne', 'platní'); }
  function npParts(n){ return n + ' ' + npPl(n, 'dielec', 'dielce', 'dielcov'); }
  function npMats(n){ return n + ' ' + npPl(n, 'materiál', 'materiály', 'materiálov'); }
  function npRects(n){ return n + ' ' + npPl(n, 'prírez', 'prírezy', 'prírezov'); }
  function npRgb(rgb){
    if (typeof rgbHex === 'function') return rgbHex(rgb);
    return (NP_STUDIO && NP_STUDIO.rgbHex) ? NP_STUDIO.rgbHex(rgb) : '';
  }
  function npR(v){ return Math.round(Number(v) * 10) / 10; }
  function npKeyAttr(k){ return k ? ' data-np-key="' + npEsc(JSON.stringify(k)) + '"' : ''; }
  function npMatById(sl, mid){
    var list = (sl && sl.materials) || [];
    for (var i = 0; i < list.length; i++) if (list[i].id === mid) return list[i];
    return null;
  }

  // ---------------------------------------------------------- čisté funkcie

  // O2: upozornenie na poslednú platňu, alebo null.
  function npLastWarn(mat){
    var pl = (mat && mat.plates) || [];
    if (pl.length < 2) return null;
    var last = pl[pl.length - 1];
    var n = (last.p || []).length;
    if (!(Number(last.u) < NP_WARN_UTIL || n <= NP_WARN_PARTS)) return null;
    return { pi: pl.length - 1, plate: last, parts: n };
  }

  // Karta s problémom je predvolene OTVORENÁ (audit F11): neúplný plán,
  // upozornenie na poslednú platňu alebo nezaradené; inak len prvá karta.
  function npProblem(mat){
    return !!(mat && (mat.incomplete || npLastWarn(mat) || (mat.unplaced || []).length ||
              (mat.rejected || []).length || (mat.conflicts || []).length));
  }
  function npIsClosed(mat, idx, closed){
    var c = closed || {};
    if (Object.prototype.hasOwnProperty.call(c, mat.id)) return c[mat.id] === true;
    return !(idx === 0 || npProblem(mat));
  }

  // Chip parametrov (O7): hodnoty z Nastavení rozpočtu; klik ich otvorí.
  // Pri predvolených hodnotách (nastavenia sa nenačítali) je jantárový.
  function npParamChipHtml(sl){
    var p = (sl && sl.params) || {};
    var warn = !!(sl && sl.unreliable);
    var t = 'prerez ' + npNf(p.kerf) + ' mm · orez ' + npNf(p.trim) + ' mm · duplák +' + npNf(p.dup_allowance) + ' mm';
    if (warn) t += ' — nastavenia sa nepodarilo načítať, predvolené hodnoty';
    return '<button type="button" class="npparam' + (warn ? ' warn' : '') + '" data-np-param' +
      ' title="Parametre plánu z Nastavení rozpočtu — platia pre všetky zákazky. Klik otvorí nastavenia.">' +
      npIco(warn ? 'alert' : 'settings') + npEsc(t) + '</button>';
  }

  function npRefreshHtml(stale){
    var f = (typeof refreshBtnHtml === 'function') ? refreshBtnHtml : (NP_STUDIO && NP_STUDIO.refreshBtnHtml);
    return f ? f(stale === true, 'Prepočítať nárezový plán z aktuálneho modelu') : '';
  }

  // Lišta sekcie: prehľad (A) alebo detail platne (B).
  function npToolsHtml(sl, stale, detail){
    if (!sl || !sl.ok) return npRefreshHtml(stale);
    if (detail){
      var mat = npMatById(sl, detail.mid);
      var n = mat ? mat.plates.length : 0;
      return '<button type="button" class="ghostbtn" data-np-back title="Späť na karty materiálov">' +
        npIco('arrow-left') + ' Prehľad</button>' +
        '<span class="npbar"><button type="button" data-np-pg="-1" title="Predošlá platňa" aria-label="Predošlá platňa">' +
        npIco('chevron-right', 'flipx') + '</button><span class="pg">Platňa ' + (detail.pi + 1) + ' z ' + n + '</span>' +
        '<button type="button" data-np-pg="1" title="Ďalšia platňa" aria-label="Ďalšia platňa">' +
        npIco('chevron-right') + '</button></span>' +
        '<span class="spacer"></span>' + npRefreshHtml(stale) + npParamChipHtml(sl);
    }
    return npRefreshHtml(stale) + npParamChipHtml(sl) + '<span class="spacer"></span>' +
      '<span class="sechint">klik na platňu otvorí jej detail</span>';
  }

  // ------------------------------------------------------------- kreslenie
  // SVG ako reťazec (vzor preview.js); farby VÝHRADNE triedy s tokenmi.
  // opts: { w: šírka px, detail: bool, hl: index riadku, lone: bool }
  function npPlateSvg(mat, plate, idx, opts){
    var o = opts || {};
    var L = Number(mat.size[0]), W = Number(mat.size[1]);
    var s = o.w / L;
    var grain = mat.grain && mat.grain !== 'none';
    var top = o.detail ? 24 : (grain ? 10 : 0);
    var ph = npR(W * s), Wd = o.w, H = npR(ph + top + (o.detail ? 2 : 0));
    var X = function(v){ return npR(Number(v) * s); };
    var t = Number(mat.trim) || 0;
    var rows = mat.rows || [];
    var parts = plate.p || [];
    var S = [];
    S.push('<svg xmlns="http://www.w3.org/2000/svg"' + (o.detail ? ' class="npdsvg"' : '') + ' width="' + Wd +
           '" height="' + H + '" viewBox="0 0 ' + Wd + ' ' + H + '" role="img" aria-label="' +
           npEsc('Platňa ' + (idx + 1) + ' — ' + npParts(parts.length) + ', využitie ' + npPct(plate.u)) + '">');
    if (grain){
      if (o.detail){
        S.push('<path class="np-grain" d="M4 11H104M98 6l6 5-6 5"/>');
        S.push('<text class="np-cap" x="112" y="15">smer kresby — po dĺžke platne</text>');
      } else {
        S.push('<path class="np-grain" d="M3 5H27M23 2l4 3-4 3"/>');
      }
    } else if (o.detail){
      S.push('<text class="np-cap" x="2" y="15">bez smeru kresby — dielce sa neotáčajú (ako vo VEPO súbore)</text>');
    }
    if (o.detail){
      S.push('<text class="np-cap" x="' + (Wd - 2) + '" y="15" text-anchor="end">' +
             npEsc('platňa ' + npDim(L, W) + ' mm · ' + (t > 0 ? 'orez ' + npNf(t) + ' mm (šrafovaný okraj)' :
                   'bez orezu — hrany hotové')) + '</text>');
    }
    S.push('<rect class="np-sheet" x="0" y="' + top + '" width="' + Wd + '" height="' + ph + '"/>');
    S.push('<rect class="np-waste ' + (o.detail ? 'l' : 's') + '" x="0" y="' + top + '" width="' + Wd +
           '" height="' + ph + '"/>');
    if (o.detail && t > 0){
      var tw = Math.max(X(t), 2.2);
      S.push('<g><title>' + npEsc('orez ' + npNf(t) + ' mm z každej hrany') + '</title>' +
             '<rect class="np-trim" x="0" y="' + top + '" width="' + Wd + '" height="' + tw + '"/>' +
             '<rect class="np-trim" x="0" y="' + npR(top + ph - tw) + '" width="' + Wd + '" height="' + tw + '"/>' +
             '<rect class="np-trim" x="0" y="' + top + '" width="' + tw + '" height="' + ph + '"/>' +
             '<rect class="np-trim" x="' + npR(Wd - tw) + '" y="' + top + '" width="' + tw + '" height="' + ph + '"/></g>');
    }
    // najväčší zvyšok (len detail) — súradnice sú v použiteľnej ploche (+ orez)
    if (o.detail && plate.o){
      var lf = plate.o, lx = X(lf[0] + t), ly = npR(top + X(lf[1] + t)), lw = X(lf[2]), lh = X(lf[3]);
      S.push('<rect class="np-left" x="' + npR(lx + 1) + '" y="' + npR(ly + 1) + '" width="' + Math.max(npR(lw - 2), 1) +
             '" height="' + Math.max(npR(lh - 2), 1) + '"><title>' + npEsc('najväčší zvyšok ' + npDim(lf[2], lf[3]) + ' mm') +
             '</title></rect>');
      var lt = 'zvyšok ' + npDim(lf[2], lf[3]);
      if (lh >= 16 && lw >= lt.length * 6.2 + 8){
        S.push('<text class="np-leftlbl" x="' + npR(lx + lw / 2) + '" y="' + npR(ly + lh / 2 + 4) +
               '" text-anchor="middle">' + npEsc(lt) + '</text>');
      }
    }
    parts.forEach(function(pp){
      var r = rows[pp[0]] || {};
      var x = X(Number(pp[1]) + t), y = npR(top + X(Number(pp[2]) + t)), w = X(r.l), h = X(r.w);
      var cls = 'np-part' + (o.detail ? ' d' : '') + (r.d ? ' dup' : '') + (o.lone ? ' lone' : '') +
                (o.hl === pp[0] ? ' hl' : '');
      var real = npDim(r.l, r.w);
      var ttl = (r.n || '') + (r.d ? ' — prírez dupláku ' + real + ' (hotový ' + npDim(r.fl, r.fw) + ')' : ' — ' + real) +
                (r.o ? ' · ' + r.o : '');
      S.push('<g data-np-ri="' + pp[0] + '"><title>' + npEsc(ttl) + '</title><rect class="' + cls + '" x="' + x +
             '" y="' + y + '" width="' + w + '" height="' + h + '"/>');
      if (o.detail){
        var name = r.d ? 'Duplák' : (r.s || ''), cx = npR(x + w / 2), cy = npR(y + h / 2);
        var need = Math.max(name.length * 6.7, real.length * 6.2) + 8;
        if (w >= need && h >= 34){
          S.push('<text class="np-lbl" x="' + cx + '" y="' + npR(cy - 3) + '" text-anchor="middle">' + npEsc(name) + '</text>' +
                 '<text class="np-dim" x="' + cx + '" y="' + npR(cy + 12) + '" text-anchor="middle">' + npEsc(real) + '</text>');
        } else if (h >= need && w >= 34){
          S.push('<g transform="rotate(-90 ' + cx + ' ' + cy + ')"><text class="np-lbl" x="' + cx + '" y="' + npR(cy - 3) +
                 '" text-anchor="middle">' + npEsc(name) + '</text><text class="np-dim" x="' + cx + '" y="' + npR(cy + 12) +
                 '" text-anchor="middle">' + npEsc(real) + '</text></g>');
        } else if (w >= real.length * 6.2 + 6 && h >= 14){
          S.push('<text class="np-dim" x="' + cx + '" y="' + npR(cy + 4) + '" text-anchor="middle">' + npEsc(real) + '</text>');
        }
      }
      S.push('</g>');
    });
    S.push('<rect class="np-edge" x=".5" y="' + npR(top + 0.5) + '" width="' + (Wd - 1) + '" height="' + npR(ph - 1) + '"/>');
    S.push('</svg>');
    return S.join('');
  }

  // ------------------------------------------------------------- prehľad (A)
  function npCountHtml(mat){
    var p = mat.phrase || {};
    return '<span class="npcount' + (p.cls ? ' ' + p.cls : '') + '">' + npEsc(p.pre || '') + '<b>' + npEsc(p.n || '') +
      '</b> <small>' + npEsc(p.post || '') + '</small></span>';
  }

  function npSummaryHtml(sl){
    var mats = sl.materials || [];
    var cPl = 0, cN = 0, est = 0, inc = 0, ori = 0;
    mats.forEach(function(m){
      est += Number(m.est_budget) || 0;
      if (m.incomplete) inc++;
      if (m.orient || sl.unreliable) ori++;
      if (m.upper_bound && !sl.unreliable){ cN++; cPl += m.sheets; }
    });
    return '<div class="npsum"><span><b>' + npMats(mats.length) + '</b> · úplný plán: <b>' + npSheets(cPl) +
      '</b> (horná hranica) pri ' + cN + ' ' + npPl(cN, 'materiáli', 'materiáloch', 'materiáloch') + '</span>' +
      (inc ? '<span class="npchip err">' + npIco('alert') + inc + ' neúplný</span>' : '') +
      (ori ? '<span class="npchip warn">' + ori + ' orientačne</span>' : '') +
      '<span class="tmuted">· odhad z m² spolu: ' + npSheets(est) + '</span><span class="spacer"></span>' +
      npTip(NP_TIP_SUM, 'r') + '</div>';
  }

  // Banner celej zákazky (audit B4): stav, ktorý nepatrí jednému materiálu,
  // musí byť vidno aj pri prázdnom zozname kariet.
  function npBannersHtml(sl){
    var h = '';
    if (sl.blocked){
      h += '<div class="npbanner err">' + npIco('alert') + '<span><b>Plán je neúplný pre celú zákazku</b> — ' +
        npEsc(sl.blocked) + '</span></div>';
    }
    var wm = sl.without_material || {};
    if (wm.pieces){
      var names = (wm.items || []).map(function(it){ return it.n; }).filter(Boolean).join(', ');
      h += '<div class="npbanner warn" title="' + npEsc(names) + '">' + npIco('alert') + '<span><b>' +
        npParts(wm.pieces) + ' bez materiálu</b> — nie sú v pláne; priraď im materiál (dielce: ' +
        npEsc(names || '—') + ')</span></div>';
    }
    return h;
  }

  function npEyeHtml(k){
    if (!k) return '';
    return '<button type="button" class="eyebtn"' + npKeyAttr(k) + ' title="Označiť v modeli všetky rovnaké kusy"' +
      ' aria-label="Označiť v modeli">' + npIco('eye') + '</button>';
  }

  // Nezaradené a vyradené (O11) — červený zoznam; dôvody skladá server.
  function npMissHtml(mat){
    var un = mat.unplaced || [], rj = (mat.rejected || []).concat(mat.conflicts || []);
    if (!un.length && !rj.length) return '';
    var hasMiss = un.length > 0, hasRej = rj.length > 0;
    var u = mat.usable || [0, 0];
    var h = '<div class="npmiss"><div class="npmisshd">' + npIco('alert') + '<b>' +
      (hasMiss && hasRej ? 'Nezmestí sa alebo ho VEPO odmietne' : hasMiss ? 'Nezmestí sa' : 'VEPO odmietne') +
      ' — plán neúplný</b><span class="why">' + (hasMiss && Number(mat.trim) > 0
        ? 'platňa po oreze má ' + npDim(u[0], u[1]) + ' (' + npDim(mat.size[0], mat.size[1]) + ' mínus ' + npNf(mat.trim) +
          ' mm z každej hrany) · ' : '') + 'počet platní platí len pre zaradené dielce</span></div>';
    un.forEach(function(g){
      var r = (mat.rows || [])[g.r] || {};
      h += '<div class="npmissrow"><span>' + npEsc(r.n) + '<span class="npwhy">' + npEsc(g.t) + '</span></span>' +
        '<span class="own" title="' + npEsc(r.o) + '">' + npEsc(r.o) + '</span><span class="num">' +
        npDim(r.d ? r.fl : r.l, r.d ? r.fw : r.w) + '</span><span class="num">' + g.q + ' ks</span>' + npEyeHtml(r.k) + '</div>';
    });
    rj.forEach(function(e){
      h += '<div class="npmissrow"><span>' + npEsc(e.n || '—') + '<span class="npwhy">' + npEsc(e.t) + '</span></span>' +
        '<span class="own" title="' + npEsc(e.o) + '">' + npEsc(e.o) + '</span><span class="num">' +
        (e.l != null ? npDim(e.l, e.w) : '—') + '</span><span class="num">' + (e.q != null ? e.q + ' ks' : '') + '</span>' +
        npEyeHtml(e.k) + '</div>';
    });
    return h + '</div>';
  }

  function npWarnHtml(mat, warn){
    var rows = mat.rows || [];
    var k = warn.parts;
    var what;
    if (k === 1){
      var one = rows[warn.plate.p[0][0]] || {};
      what = npEsc(one.n) + ' ' + npDim(one.l, one.w);
    } else {
      what = npEsc(warn.plate.p.map(function(pp){ return (rows[pp[0]] || {}).s || ''; }).join(', '));
    }
    var prev = mat.plates[mat.plates.length - 2];
    var left = warn.plate.o;
    var tip = 'Kvôli ' + (k === 1 ? 'jednému dielcu' : k + ' dielcom') + ' kupuješ celú platňu (VEPO účtuje celé tabule). Čo s tým:\n' +
      '• zmenšiť alebo rozdeliť dielec, aby sa zmestil do zvyšku predošlej platne' +
      (prev && prev.o ? ' (najväčší ' + npDim(prev.o[2], prev.o[3]) + ')' : '') + '\n' +
      '• vyrobiť ho z iného materiálu, ktorý má na platni miesto\n' +
      (left ? '• platňu kúpiť a zvyšok (tu ' + npDim(left[2], left[3]) + ') použiť na ďalšiu zákazku — zvyšky sú tvoje'
            : '• bez využiteľného zvyšku — dielce vyplnia platňu celú');
    return '<div class="npwarn">' + npIco('alert') + '<span><b>Posledná platňa:</b> ' + npParts(k) + ' — ' + what +
      ' · využitie ' + npPct(warn.plate.u) + '</span>' + npTip(tip) +
      '<button type="button" class="linkbtn" data-np-open="' + npEsc(mat.id) + ':' + warn.pi + '">Ukázať platňu ' +
      (warn.pi + 1) + '</button></div>';
  }

  function npCardHtml(mat, idx, closed){
    var warn = npLastWarn(mat);
    var hex = npRgb(mat.rgb);
    var state = '';
    if (warn) state += '<span class="npstate" title="Posledná platňa je takmer prázdna">' + npIco('alert', 'w') + '</span>';
    if (mat.incomplete) state += '<span class="npstate" title="Plán je neúplný">' + npIco('alert', 'e') + '</span>';
    var sub = [];
    sub.push('formát ' + npDim(mat.size[0], mat.size[1]) +
             (mat.fallback ? ' <span class="bfnt">(náhradný)</span>' : mat.uni ? ' <span class="bfnt">(pracovný)</span>' : ''));
    var grain = mat.grain && mat.grain !== 'none';
    sub.push((grain ? npIco('grain') + ' kresba po dĺžke platne' : 'bez smeru kresby') +
             npTip(NP_TIP_ROT + (grain ? '\nKresba platne beží po jej dĺžke (' + npNf(mat.size[0]) + ' mm).' : '')));
    if (mat.util != null) sub.push('využitie <b>' + npPct(mat.util) + '</b>');
    if (mat.est){
      var a = npNf(mat.est[0]), b = npNf(mat.est[1]);
      sub.push('odhad z m²: <b>' + (a === b ? a : a + '–' + b) + '</b> <span class="bfnt">(v rozpočte dnes ' +
               npEsc(mat.est_budget) + ')</span>');
    }
    var chips = '';
    var dups = (mat.rows || []).filter(function(r){ return r.d; });
    if (dups.length){
      var dq = 0, dn = 0;
      dups.forEach(function(r){ dq += r.q; dn += r.c; });
      var ex = dups[0];
      chips += '<span class="npchip info" title="Duplák sa lepí z prírezov zdrojového materiálu — toľko, koľko má vrstiev (2 alebo 3); ' +
        'každý prírez má prídavok na každú stranu. VEPO ich zlepí a oreže na hotový rozmer.">vrátane ' + dq + ' ' +
        npPl(dq, 'dupláku', 'duplákov', 'duplákov') + ' = ' + npRects(dn) + ' s prídavkom (' + npDim(ex.fl, ex.fw) + ' → ' +
        npDim(ex.l, ex.w) + ')</span>';
    }
    if (mat.no_trim) chips += '<span class="npchip info">bez orezu — hrany hotové</span>';
    if (mat.fallback) chips += '<span class="npchip warn">' + npIco('alert') + 'formát chýba — plán len orientačný</span>';
    if (mat.uni) chips += '<span class="npchip warn">materiál neurčený — orientačné</span>';
    if (mat.incomplete) chips += '<span class="npchip err">' + npIco('alert') + 'plán neúplný</span>';
    if (!mat.trim && !mat.no_trim && !mat.orient) chips += '<span class="npchip info">bez orezu</span>';
    var h = '<div class="npcard' + (closed ? ' closed' : '') + '" data-mid="' + npEsc(mat.id) + '"><div class="nphead">' +
      '<button type="button" class="nptog" data-np-card="' + npEsc(mat.id) + '" aria-expanded="' + (!closed) +
      '" title="Klik zbalí / rozbalí kartu"><span class="chev"></span>' +
      '<span class="sw"' + (hex ? ' style="background:' + hex + '"' : '') + '></span>' +
      '<span class="npname">' + npEsc(mat.label || mat.id) + '</span><span class="npman">' +
      npEsc([mat.manufacturer, mat.th ? npNf(mat.th) + ' mm' : ''].filter(Boolean).join(' · ')) + '</span>' +
      '<span class="spacer"></span>' + state + npCountHtml(mat) + '</button>' +
      '<div class="npl2">' + sub.join('<span class="sep">·</span>') + (chips ? '<span class="sep">·</span>' + chips : '') +
      '</div></div>';
    // Zbalená karta SVG VÔBEC nevytvára (audit F11).
    if (closed) return h + '</div>';
    h += '<div class="npbody"><div class="npgrid">';
    (mat.plates || []).forEach(function(pl, i){
      var wr = !!(warn && warn.pi === i);
      h += '<button type="button" class="npthumb' + (wr ? ' warn' : '') + (mat.orient ? ' orient' : '') +
        '" data-np-thumb="' + npEsc(mat.id) + ':' + i + '" title="' +
        npEsc('Platňa ' + (i + 1) + ' — ' + npParts((pl.p || []).length) + ' · využitie ' + npPct(pl.u) + ' · klik otvorí detail') +
        '"><span class="npthd">' + (wr ? npIco('alert') : '') + 'Platňa ' + (i + 1) + (mat.orient ? ' · orientačne' : '') +
        '<span class="u">' + npPct(pl.u) + '</span></span>' +
        npPlateSvg(mat, pl, i, { w: mat.no_trim && Number(mat.size[0]) / Number(mat.size[1]) > 4 ? 344 : NP_THUMB_W,
                                 lone: wr && warn.parts <= NP_WARN_PARTS }) + '</button>';
    });
    if (!(mat.plates || []).length) h += '<span class="muted">Žiadna platňa — do plánu sa nezaradil žiadny dielec.</span>';
    h += '</div>';
    if (warn) h += npWarnHtml(mat, warn);
    h += npMissHtml(mat);
    return h + '</div></div>';
  }

  // ------------------------------------------------------------- detail (B)
  function npDetailHtml(sl, detail, hl){
    var mat = npMatById(sl, detail.mid);
    if (!mat || !(mat.plates || []).length) return '';
    var pi = Math.min(Math.max(detail.pi, 0), mat.plates.length - 1);
    var pl = mat.plates[pi];
    var warn = npLastWarn(mat);
    var hex = npRgb(mat.rgb);
    var dupOn = 0;
    (pl.p || []).forEach(function(pp){ if ((mat.rows[pp[0]] || {}).d) dupOn++; });
    var h = '<div class="npdhd"><span class="sw"' + (hex ? ' style="background:' + hex + '"' : '') + '></span><b>' +
      npEsc(mat.label || mat.id) + '</b><span>' + npEsc([mat.manufacturer, mat.th ? npNf(mat.th) + ' mm' : ''].filter(Boolean).join(' · ')) +
      '</span><span class="sep">·</span><span><b>' + npParts((pl.p || []).length) + '</b>' +
      (dupOn ? ' (z toho ' + npRects(dupOn) + ' dupláku)' : '') + '</span><span class="sep">·</span><span>využitie <b>' +
      npPct(pl.u) + '</b></span>' + (pl.o ? '<span class="sep">·</span><span>najväčší zvyšok <b>' + npDim(pl.o[2], pl.o[3]) +
      '</b></span>' : '') + (mat.orient ? '<span class="npchip warn">orientačne pri formáte ' + npDim(mat.size[0], mat.size[1]) +
      '</span>' : '') + (mat.incomplete ? '<span class="npchip err">' + npIco('alert') + 'plán neúplný</span>' : '') + '</div>';
    h += npPlateSvg(mat, pl, pi, { w: NP_DETAIL_W, detail: true, hl: hl,
                                   lone: !!(warn && warn.pi === pi && warn.parts <= NP_WARN_PARTS) });
    if (warn && warn.pi === pi){
      h += '<div class="npwarn">' + npIco('alert') + '<span><b>Posledná platňa:</b> ' + npParts(warn.parts) +
        ' · využitie ' + npPct(pl.u) + ' — pozri radu v karte materiálu</span></div>';
    }
    // zoznam dielcov na platni (po riadkoch kusovníka)
    var grp = [], at = {};
    (pl.p || []).forEach(function(pp){
      var i = pp[0];
      if (!(i in at)){ at[i] = grp.length; grp.push({ i: i, n: 0 }); }
      grp[at[i]].n++;
    });
    h += '<table class="nplist"><thead><tr><th>Dielec</th><th>Skrinka</th><th class="num">Rozmer</th>' +
      '<th class="num">Na platni</th><th></th></tr></thead><tbody>';
    grp.forEach(function(g){
      var r = mat.rows[g.i] || {};
      var dims = r.d ? npDim(r.l, r.w) + ' <span class="sub">prírez · hotový ' + npDim(r.fl, r.fw) + '</span>' : npDim(r.l, r.w);
      var cnt = r.d ? npRects(g.n) + ' <span class="sub">(' + npNf(g.n / (r.m || 1)) + ' ks × ' + r.m + ')</span>' : g.n + ' ks';
      h += '<tr data-np-ri="' + g.i + '"' + (hl === g.i ? ' class="hl"' : '') + '><td>' + npEsc(r.n) +
        (r.d ? ' <span class="npchip info">Duplák</span>' : '') + '</td><td class="own" title="' + npEsc(r.o) + '">' +
        npEsc(r.o) + '</td><td class="num">' + dims + '</td><td class="num">' + cnt + '</td><td class="act">' +
        npEyeHtml(r.k) + '</td></tr>';
    });
    return h + '</tbody></table>';
  }

  // Celé telo sekcie (čistá funkcia — testuje ju tests/js/test_np3_sekcia.js).
  // st: { closed: {mid: bool}, detail: {mid, pi} | null, hl }
  function npBodyHtml(sl, st){
    var s = st || {};
    if (!sl) return '<div class="muted">Načítavam…</div>';
    if (!sl.ok){
      return '<div class="npbanner err">' + npIco('alert') + '<span><b>Nárezový plán sa nepodarilo spočítať</b> — ' +
        'pozri Ruby konzolu. Rozpočet a exporty to neovplyvnilo.</span></div>';
    }
    if (s.detail){
      var d = npDetailHtml(sl, s.detail, s.hl);
      if (d) return d;
    }
    var mats = sl.materials || [];
    var h = npBannersHtml(sl);
    if (!mats.length) return h + '<div class="muted">Zákazka nemá žiadne dielce na platne.</div>';
    h += npSummaryHtml(sl);
    mats.forEach(function(m, i){ h += npCardHtml(m, i, npIsClosed(m, i, s.closed)); });
    return h;
  }

  // Detail, ktorý po novom pushi už neexistuje (materiál zmizol, menej
  // platní), sa zatvorí alebo skráti — nikdy neukáže cudziu platňu.
  function npValidDetail(sl, detail){
    if (!detail || !sl || !sl.ok) return null;
    var mat = npMatById(sl, detail.mid);
    if (!mat || !(mat.plates || []).length) return null;
    return { mid: detail.mid, pi: Math.min(Math.max(detail.pi, 0), mat.plates.length - 1) };
  }

  // ------------------------------------------------------ DOM a udalosti
  function npEl(id){ return (typeof document === 'undefined') ? null : document.getElementById(id); }
  function npActive(){
    var sec = null;
    if (typeof studioActiveSection === 'function') sec = studioActiveSection();
    else if (NP_STUDIO && typeof NP_STUDIO.studioActiveSection === 'function') sec = NP_STUDIO.studioActiveSection();
    return sec === 'cut';
  }
  function npData(){
    if (typeof ST !== 'undefined' && ST) return ST.sheet_layout || null;
    return npState;
  }
  function npLoadClosed(){
    if (npClosed) return npClosed;
    npClosed = {};
    try {
      var raw = window.localStorage.getItem(NP_CLOSED_KEY);
      var v = raw ? JSON.parse(raw) : null;
      if (v && typeof v === 'object') npClosed = v;
    } catch (e){ npClosed = {}; }
    return npClosed;
  }
  function npSaveClosed(){
    try { window.localStorage.setItem(NP_CLOSED_KEY, JSON.stringify(npClosed || {})); } catch (e){ /* privátny režim */ }
  }

  var npHl = null;
  function npRenderTools(stale){
    var box = npEl('sectools');
    if (!box || !npActive()) return;
    var sl = npData();
    npDetail = npValidDetail(sl, npDetail);
    box.innerHTML = npToolsHtml(sl, stale === true, npDetail);
  }
  function npRenderBody(){
    var box = npEl('secbody');
    if (!box || !npActive()) return;
    var sl = npData();
    npDetail = npValidDetail(sl, npDetail);
    if (!npDetail) npHl = null;
    box.innerHTML = npBodyHtml(sl, { closed: npLoadClosed(), detail: npDetail, hl: npHl });
  }
  function npRerender(){
    var stale = (typeof staleFlag !== 'undefined') ? staleFlag : false;
    npRenderTools(stale);
    npRenderBody();
  }

  // Oko: TÁ ISTÁ cesta ako riadok Kusovníka (`nx_select` s natívnym kľúčom).
  // `origin: 'cut'` len vyberie vlastnú vetu statusu (všetky rovnaké kusy).
  function npSelect(key){
    if (!key || typeof window === 'undefined' || !window.sketchup || !sketchup.nx_select) return false;
    var gen = (typeof ST !== 'undefined' && ST) ? ST.gen : (npState ? npState.gen : null);
    sketchup.nx_select(JSON.stringify({ gen: gen, parts_key: key, origin: 'cut' }));
    return true;
  }

  function npOpenPlate(mid, pi){
    npDetail = { mid: mid, pi: pi };
    npHl = null;
    npRerender();
    var box = npEl('secbody');
    if (box) box.scrollTop = 0;
  }

  // Zvýraznenie riadku ↔ dielca v detaile BEZ prekreslenia (lekcia D-23).
  function npHighlight(ri){
    if (npHl === ri) return;
    npHl = ri;
    var box = npEl('secbody');
    if (!box || !box.querySelectorAll) return;
    var list = box.querySelectorAll('[data-np-ri]');
    for (var i = 0; i < list.length; i++){
      var n = list[i];
      var on = ri != null && String(n.getAttribute('data-np-ri')) === String(ri);
      var target = (n.tagName && n.tagName.toLowerCase() === 'g') ? n.querySelector('rect') : n;
      if (target && target.classList) target.classList.toggle('hl', on);
    }
  }

  function npOnClick(t){
    if (!t || !t.closest || !npActive()) return false;
    var b;
    if ((b = t.closest('[data-np-key]'))){
      try { npSelect(JSON.parse(b.getAttribute('data-np-key'))); } catch (e){ /* poškodený kľúč = nič */ }
      return true;
    }
    if ((b = t.closest('[data-np-card]'))){
      var id = b.getAttribute('data-np-card');
      var sl = npData();
      var mats = (sl && sl.materials) || [];
      var idx = -1;
      for (var i = 0; i < mats.length; i++) if (mats[i].id === id) idx = i;
      var closed = npLoadClosed();
      var now = idx >= 0 ? npIsClosed(mats[idx], idx, closed) : !!closed[id];
      closed[id] = !now;
      npSaveClosed();
      npRenderBody();
      return true;
    }
    if ((b = t.closest('[data-np-thumb]')) || (b = t.closest('[data-np-open]'))){
      var v = (b.getAttribute('data-np-thumb') || b.getAttribute('data-np-open')).split(':');
      var pi = parseInt(v.pop(), 10);
      npOpenPlate(v.join(':'), isNaN(pi) ? 0 : pi);
      return true;
    }
    if (t.closest('[data-np-back]')){ npDetail = null; npHl = null; npRerender(); return true; }
    if ((b = t.closest('[data-np-pg]'))){
      var s2 = npData();
      var mat = npDetail ? npMatById(s2, npDetail.mid) : null;
      if (!mat) return true;
      var n = mat.plates.length;
      npDetail = { mid: npDetail.mid, pi: (npDetail.pi + parseInt(b.getAttribute('data-np-pg'), 10) + n) % n };
      npHl = null;
      npRerender();
      return true;
    }
    if (t.closest('[data-np-param]')){
      if (typeof studioGoSection === 'function') studioGoSection('bset');
      return true;
    }
    return false;
  }

  if (typeof document !== 'undefined' && document.addEventListener){
    document.addEventListener('click', function(ev){ npOnClick(ev.target); });
    document.addEventListener('mouseover', function(ev){
      if (!npActive() || !npDetail) return;
      var t = ev.target && ev.target.closest ? ev.target.closest('[data-np-ri]') : null;
      npHighlight(t ? parseInt(t.getAttribute('data-np-ri'), 10) : null);
    });
  }

  // Node testy (tests/js/test_np3_sekcia.js) — čisté funkcie + stav okna.
  if (typeof module !== 'undefined' && module.exports){
    module.exports = {
      NP_WARN_UTIL: NP_WARN_UTIL, NP_WARN_PARTS: NP_WARN_PARTS, NP_CLOSED_KEY: NP_CLOSED_KEY,
      npNf: npNf, npDim: npDim, npPct: npPct, npSheets: npSheets, npParts: npParts,
      npLastWarn: npLastWarn, npProblem: npProblem, npIsClosed: npIsClosed,
      npParamChipHtml: npParamChipHtml, npToolsHtml: npToolsHtml, npPlateSvg: npPlateSvg,
      npSummaryHtml: npSummaryHtml, npBannersHtml: npBannersHtml, npCardHtml: npCardHtml,
      npDetailHtml: npDetailHtml, npBodyHtml: npBodyHtml, npValidDetail: npValidDetail,
      npMissHtml: npMissHtml, npSelect: npSelect, npOnClick: npOnClick,
      npRenderBody: npRenderBody, npRenderTools: npRenderTools,
      npSetState: function(sl){ npState = sl; },
      npGetDetail: function(){ return npDetail; },
      npSetDetail: function(d){ npDetail = d; },
      npResetClosed: function(){ npClosed = null; }
    };
  }
