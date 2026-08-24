  // ============ D-15: ZDIELANA KOSTRA MODALOV („pridavaciek") ================
  // Schvaleny vzor kontraktu UI 2.0 (`SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`,
  // sekcia „D-15 pridavacky ako modal"): JEDNA kostra pre vsetky okna typu
  // „pridaj nieco" — titulok s podtitulom a krizikom (`mhead`) · polia (`mbody`)
  // · Zrusit + ZELENE potvrdenie (`mfoot`); Esc aj klik na scrim zatvaraju;
  // fokus ide do PRVEHO pola a pri zatvoreni sa vracia na spustac.
  //
  // Vzor je `edge_menu.js`: markup, texty aj spravanie ziju na JEDNOM mieste,
  // instancie sa lisia LEN poliami. Prvu kodovu instanciu priniesla ŠT-1c PR B2
  // (drafty rozpoctu — vlastny riadok + spotrebic); ŠT-2c PR 2c-1 kostru
  // rozsirila o to, co potrebuje D-69 editor materialu: typy poli `group`
  // (nadpis sekcie formulara), `rows` (opakovatelne riadky), `checkbox`,
  // `color`, sirkove varianty karty a PAMAT ROZPISANYCH HODNOT v komponente.
  //
  // KONTRAKT (audit #9): komponent spravuje VYHRADNE modaly, ktore si ho
  // vyziadaju cez `NXModal.open`. Fazove okno prepoctu cien (`#budPrModal`
  // v budget.js) ho NEPREBERA — ma vlastny zivotny cyklus riadeny SERVEROM
  // a vo faze `run` sa Escapom zatvorit NESMIE (beh by zostal visiet bez okna).
  // Preto:
  //   * Escape handler tohto komponentu zatvara LEN jeho vlastny modal,
  //   * okno, ktore ma vlastny Escape handler (Studio, ecMenu), sa musi
  //     podmienit `NXModal.isOpen() === false` — listenery visia na
  //     `document` a `stopPropagation` medzi nimi NEFUNGUJE (lekcia
  //     studio.js: dva listenery na tom istom uzle).
  //
  // ZAPIS NEZATVARA MODAL. `open` len posle hodnoty cez `onSubmit`; zavriet ho
  // musi volajuci az vtedy, ked SERVER zapis POTVRDI (GH #138 P2 / audit #10):
  // odmietnuty zapis musi pouzivatel najst s rozpisanymi hodnotami na mieste,
  // nie ako prazdny formular.
  (function(global){
    'use strict';

    var ROOT_ID = 'nxModalRoot';
    // Otvoreny modal: { base, spec, trigger, busy, memSkip }.
    //   `base` = specifikacia, ako ju PODAL volajuci (cize VYCHODISKOVE hodnoty),
    //   `spec` = to iste, ale s vliatou pamatou rozpisanych hodnot.
    // `trigger` je uzol, na ktory sa vracia fokus po zatvoreni. Naraz zije
    // NAJVIAC JEDEN modal (dve „pridavacky" na obrazovke naraz su vzdy chyba
    // navrhu, nie stav).
    var OPEN = null;

    // --- PAMAT ROZPISANYCH HODNOT (audit ŠT-2c #12) --------------------------
    // Do ŠT-2c ju drzal KAZDY volajuci sam (rozpocet cez `BUD_DRAFT_VALUES`).
    // Teraz je v komponente, lebo je to sucast kontraktu D-15 („Esc nesmie byt
    // ticha strata rozpisaneho riadku" — ŠT-1c PR B2) — nie vlastnost rozpoctu.
    //
    // KONVENCIA KLUCA: `<okno/domena>:<mode>[:<ciel>]` — napr. `bud:custom`,
    // `mat:create`, `mat:edit:H3303`. Slot (co sa navzajom PREPISUJE) je vsetko
    // okrem posledneho segmentu, ked je segmentov aspon TRI; inak cely kluc.
    // Dosledok: `bud:custom` a `bud:appliance` su NEZAVISLE, ale `mat:edit:A`
    // a `mat:edit:B` sa delia o jeden slot — otvorenie editora INEHO dekoru je
    // iny ciel, takze stary rozpis zanika a formular je cisty. Bez toho by sa
    // do dekoru B predvyplnili hodnoty pisane do dekoru A a ulozili by sa do
    // nespravneho zaznamu.
    //
    // Pamataju sa LEN polia, ktore sa lisia od VYCHODISKOVYCH hodnot (`base`):
    // predvolba v rozbalovacom poli ani „Počet = 1" nie su nic, co by
    // pouzivatel rozpisal, takze pamat nezakladaju.
    var MEM = {};

    function esc(s){
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function warn(msg){
      if (typeof console !== 'undefined' && console && console.warn) console.warn('NXModal: ' + msg);
    }

    function ico(n){ return '<svg class="ic" aria-hidden="true"><use href="#i-' + n + '"/></svg>'; }

    function optionsHtml(options, value){
      var h = '';
      (options || []).forEach(function(o){
        h += '<option value="' + esc(o[0]) + '"' +
             (String(o[0]) === String(value == null ? '' : value) ? ' selected' : '') +
             '>' + esc(o[1]) + '</option>';
      });
      return h;
    }

    function isHex(v){ return /^#[0-9a-fA-F]{6}$/.test(String(v == null ? '' : v)); }

    // Jedno pole. `type`:
    //   'text' (default) · 'select' (`options` = [hodnota, popis]) ·
    //   'checkbox' (hodnota je BOOLEAN) · 'color' (vzorka + textovy #RRGGBB) ·
    //   'group' (NADPIS sekcie formulara, hodnotu nema) ·
    //   'rows' (opakovatelne riadky, hodnota je POLE HASHOV).
    // `cls` je doplnkova trieda vstupu (napr. `mshort`).
    function fieldHtml(f){
      var d = f || {};
      if (d.type === 'group'){
        return '<div class="mgroup"><h4>' + esc(d.label) + '</h4>' +
               (d.hint ? '<span>' + esc(d.hint) + '</span>' : '') + '</div>';
      }
      if (d.type === 'rows') return rowsHtml(d, d.value);
      var key = esc(d.key);
      var id = 'nxm_' + key;
      var lbl = '<label for="' + id + '">' + esc(d.label) + '</label>';
      var cls = d.cls ? ' class="' + esc(d.cls) + '"' : '';
      var hint = d.hint ? '<span class="munit">' + esc(d.hint) + '</span>' : '';
      var input;
      if (d.type === 'select'){
        input = '<select id="' + id + '" data-nxm="' + key + '"' + cls + '>' +
                optionsHtml(d.options, d.value) + '</select>';
      } else if (d.type === 'checkbox'){
        // Zaskrtavatko ma popis VEDLA seba, nie pod stlpcom vstupov — inak by
        // sa v dlhom formulari citalo ako prazdny riadok.
        input = '<input id="' + id + '" type="checkbox" data-nxm="' + key + '"' + cls +
                (d.value === true ? ' checked' : '') + '>';
        return '<div class="mrow mcheck">' + lbl + input + hint + '</div>';
      } else if (d.type === 'color'){
        // Vzorka + text: farba sa v katalogu zapisuje ako #RRGGBB, takze
        // pouzivatel musi vediet hodnotu aj PRECITAT a skopirovat, nie iba
        // kliknut do palety.
        var col = String(d.value == null ? '' : d.value);
        input = '<span class="mswatch" id="' + id + '_sw" data-nxm-swatch="' + key + '"' +
                (isHex(col) ? ' style="background:' + esc(col) + '"' : '') + '></span>' +
                '<input id="' + id + '" type="text" data-nxm="' + key + '" data-nxm-color="1"' +
                ' class="' + esc(d.cls || 'mshort') + '" value="' + esc(col) + '"' +
                ' placeholder="#RRGGBB" maxlength="7">';
      } else {
        input = '<input id="' + id + '" type="text" data-nxm="' + key + '"' + cls +
                ' value="' + esc(d.value == null ? '' : d.value) + '"' +
                (d.placeholder ? ' placeholder="' + esc(d.placeholder) + '"' : '') + '>';
      }
      return '<div class="mrow">' + lbl + input + hint + '</div>';
    }

    // --- REPEATER `rows` (audit ŠT-2c #14) -----------------------------------
    // `cols` je definicia POD-poli jedneho riadku, hodnota pola je POLE HASHOV
    // (`values()` ho tak aj vracia — ploche polia ostavaju retazcami, aby sa
    // draftom rozpoctu nic nezmenilo).
    //
    // `hidden` su kluce, ktore riadok NESIE, ale nezobrazuje — typicky
    // `material_id`/`row_rev`. Podla nich server odlisi UPRAVU existujuceho
    // variantu od NOVEHO: riadok pridany tlacidlom „+" ich nema, takze je novy.
    // Identita variantu sa tym padom NIKDY neodvodzuje od kodu, ktory
    // pouzivatel prave prepisuje.
    //
    // Kontajner ma VLASTNY prefix id (`nxmr_`, audit #6): kluc repeatera a kluc
    // plocheho pola sa tak nemozu zrazit o ten isty `id`.
    function rowsInnerHtml(f, data){
      var d = f || {};
      var key = esc(d.key);
      var arr = (data && data.length) ? data : [];
      var min = Number(d.min || 0);
      var locked = arr.length <= min;
      var note = d.minNote || (min === 1 ? 'Musí zostať aspoň jeden riadok.'
                                         : 'Riadkov musí zostať aspoň ' + min + '.');
      var h = '';
      if (d.label) h += '<div class="mrhead">' + esc(d.label) + '</div>';
      if (arr.length && (d.cols || []).length){
        // Hlavicka MUSI niest TU ISTU sirkovu triedu ako bunka pod nou (review
        // 2c-1 #8) — inak stlpec „Cena" (uzky `mshort`) sedi pod nadpisom
        // sirokym na celu volnu sirku a tabulka sa cita krivo. Zaskrtavatko
        // ma vlastnu (uzku) triedu z rovnakeho dovodu.
        h += '<div class="mrcols">';
        (d.cols || []).forEach(function(c){
          h += '<span class="' + esc(colCls(c)) + '">' + esc(c.label) + '</span>';
        });
        h += '<span class="mrgap"></span></div>';
      }
      h += '<div class="mrlist" data-nxm-list="' + key + '">';
      if (!arr.length && d.empty) h += '<div class="mrempty">' + esc(d.empty) + '</div>';
      arr.forEach(function(row){
        h += '<div class="mrline" data-nxm-row="' + key + '">';
        // `_note` = STITOK riadku (nie hodnota — `readRows` ho necita, lebo
        // nema `data-nxm-col`). Nesie ho zotavenie z konfliktu: riadok, ktory
        // sa medzitym zmenil ZVONKU, musi byt VIDNO — inak by pouzivatel
        // potvrdil zapis nad cudzou zmenou, o ktorej nevie.
        if (row && row._note){
          h += '<span class="mrflag" title="' + esc(row._note) + '">' + esc(row._note) + '</span>';
        }
        (d.hidden || []).forEach(function(hk){
          var hv = row ? row[hk] : null;
          if (hv == null || hv === '') return;
          h += '<input type="hidden" data-nxm-col="' + esc(hk) + '" value="' + esc(hv) + '">';
        });
        (d.cols || []).forEach(function(c){ h += rowCellHtml(c, row ? row[c.key] : '', row); });
        // D-78: ziadne MRTVE tlacidlo. Posledny riadok sa odobrat neda, ale
        // tlacidlo ostava zameratelne a klik POVIE DOVOD — HTML `disabled` by
        // ho vyhodilo z Tab poradia a mlcalo by.
        h += '<button type="button" class="mrdel' + (locked ? ' off' : '') + '"' +
             ' data-nxm-act="rowdel"' + (locked ? ' aria-disabled="true"' : '') +
             ' title="' + esc(locked ? note : 'Odobrať riadok') + '"' +
             ' aria-label="Odobrať riadok">' + ico('trash') + '</button>' +
             '</div>';
      });
      h += '</div>';
      h += '<div class="mrnote" role="status"></div>';
      h += '<div class="mradd"><button type="button" class="ghostbtn mrbtn"' +
           ' data-nxm-act="rowadd" data-nxm-rows="' + key + '">' + ico('plus') + ' ' +
           esc(d.addLabel || 'Pridať riadok') + '</button></div>';
      return h;
    }

    function rowsHtml(f, data){
      var key = esc((f || {}).key);
      return '<div class="mrows" id="nxmr_' + key + '" data-nxm-rows="' + key + '">' +
             rowsInnerHtml(f, data) + '</div>';
    }

    // Sirkova trieda stlpca — zdiela ju HLAVICKA aj bunka (review 2c-1 #8).
    function colCls(c){
      var d = c || {};
      var base = d.cls || 'mrcell';
      return d.type === 'checkbox' ? base + ' mcheckcol' : base;
    }

    // Bunka riadku. `row` je CELY riadok, lebo o tom, ci sa bunka smie
    // editovat, rozhoduje riadok, nie stlpec: `roWhen: 'material_id'` znamena
    // „ked riadok uz nesie ID variantu, je toto pole jeho IDENTITA a needituje
    // sa". Server takú zmenu aj tak odmietne — UI ju len nema PROVOKOVAT
    // (a `roTitle` povie DOVOD, vzor D-78).
    //
    // Zamknuta bunka je `readonly` TEXT, nie `disabled`: disabled prvok zmizne
    // z klavesnice aj z citacky obrazovky, takze pouzivatel by sa k hodnote
    // hrubky/sirky nedostal ani precitat. `readonly` ostava zameratelny
    // a kopirovatelny — a `readRows` ho cita rovnako, takze server dostane
    // nezmenenu identitu.
    function rowCellHtml(c, v, row){
      var d = c || {};
      var k = esc(d.key);
      var cls = ' class="' + esc(colCls(c)) + '"';
      // Bunky nemaju `<label>` (nadpis je nad stlpcom, nie pri poli) — bez
      // `aria-label` by citacka obrazovky hlasila len „textové pole".
      var lbl = ' aria-label="' + esc(d.label || d.key) + '"';
      var locked = !!(d.roWhen && row && row[d.roWhen] != null && row[d.roWhen] !== '');
      var title = locked && d.roTitle ? ' title="' + esc(d.roTitle) + '"' : '';
      if (locked && d.type === 'checkbox')
        return '<input type="checkbox" data-nxm-col="' + k + '"' + cls + lbl + title +
               ' disabled' + (v === true ? ' checked' : '') + '>';
      if (locked)
        return '<input type="text" data-nxm-col="' + k + '"' + cls + lbl + title +
               ' readonly value="' + esc(v == null ? '' : v) + '">';
      if (d.type === 'select')
        return '<select data-nxm-col="' + k + '"' + cls + lbl + '>' + optionsHtml(d.options, v) + '</select>';
      if (d.type === 'checkbox')
        return '<input type="checkbox" data-nxm-col="' + k + '"' + cls + lbl +
               (v === true ? ' checked' : '') + '>';
      return '<input type="text" data-nxm-col="' + k + '"' + cls + lbl +
             ' value="' + esc(v == null ? '' : v) + '"' +
             (d.placeholder ? ' placeholder="' + esc(d.placeholder) + '"' : '') + '>';
    }

    // Sirka karty. `size`: 'sm' (420, default a `small` je jeho alias) ·
    // 'md' (560) · 'wide' (~640 — editor s opakovatelnymi riadkami). Stary
    // prepinac `small: false` (= md) ostava funkcny, aby sa existujuce
    // pridavacky nemuseli prepisovat.
    function cardCls(s){
      var d = s || {};
      var sz = d.size;
      if (sz == null) sz = (d.small === false) ? 'md' : 'sm';
      sz = String(sz);
      if (sz === 'small') sz = 'sm';
      if (sz === 'wide') return ' wide';
      if (sz === 'md') return '';
      return ' sm';
    }

    // CISTY markup modalu (testovatelny bez DOM). Scrim je SURODENEC karty,
    // nie jej rodic v zmysle klikov: klik na scrim zatvara len vtedy, ked
    // `event.target` je PRAVE on (klik do karty nesmie okno zavriet).
    // POZOR na mena tried: mockup kresli scrim ako `.nxscrim` a KARTU ako
    // `.nxmodal` — lenze `panel.css` (nacitava ho aj Studio) uz meno `.nxmodal`
    // pouziva pre SCRIM starsich modalov. Karta sa tu preto vola `.nxmcard`;
    // `mhead`/`mbody`/`mfoot`/`mrow` z mockupu ostavaju doslovne.
    //
    // `fromMemory: true` prida navrch tela INFO PAS (audit ŠT-2c #1): rozpis
    // z pamate je pohodlie, ale pouzivatel MUSI vidiet, ze pozera na svoj stary
    // koncept — inak by pri editore materialu ulozil cenu, ktoru pisal minule.
    function modalHtml(spec){
      var s = spec || {};
      var h = '<div class="nxscrim" data-nxm-scrim="1"><div class="nxmcard' +
              cardCls(s) + '" role="dialog" aria-modal="true"' +
              ' aria-label="' + esc(s.title) + '">' +
        '<div class="mhead"><h3>' + esc(s.title) + '</h3>' +
        (s.sub ? '<span class="msub">' + esc(s.sub) + '</span>' : '') +
        '<button type="button" class="mx" data-nxm-act="close"' +
        ' title="Zavrieť (Esc)" aria-label="Zavrieť">' + ico('x') + '</button></div>' +
        '<div class="mbody">';
      if (s.fromMemory === true){
        h += '<div class="mmemo" role="status"><span>Predvyplnené z rozpísaného konceptu</span>' +
             '<button type="button" class="linkbtn" data-nxm-act="memreset">Začať odznova</button></div>';
      }
      // Zberna hlaska pre chyby, ktore sa NEDAJU priradit k poľu (celoriadkove
      // validacie servera, chyby bez `field`). Prazdna sa nekresli (`:empty`) —
      // markup je tu VZDY, aby `showErrors` nemusel nic vkladat pred iné uzly.
      h += '<div class="merrtop" data-nxm-errtop="1" role="status"></div>';
      (s.fields || []).forEach(function(f){ h += fieldHtml(f); });
      if (s.note) h += '<div class="hint">' + esc(s.note) + '</div>';
      // ŠT-3c-1: `danger: true` = DESTRUKTIVNE potvrdenie (mazanie). UI_DIZAJN:
      // destruktivna akcia je `.danger`, nie zelena `.primary` — zelena hovori
      // „pokracuj", cervena „toto uz nevratis". Default sa NEMENI: bez priznaku
      // ostava kostra presne taka, aka bola.
      var okCls = s.danger === true ? 'danger' : 'primary';
      var okIco = s.danger === true ? 'trash' : 'check';
      h += '</div><div class="mfoot"><span class="spacer"></span>' +
        '<button type="button" class="ghostbtn" data-nxm-act="close">Zrušiť</button>' +
        '<button type="button" class="' + okCls + '" data-nxm-act="submit">' +
        ico(okIco) + ' ' + esc(s.okLabel || 'Pridať') + '</button></div>';
      return h + '</div></div>';
    }

    function root(){
      if (typeof document === 'undefined') return null;
      var r = document.getElementById(ROOT_ID);
      if (r) return r;
      // Kotva sa vytvori na poziadanie — okno ju v HTML mat nemusi.
      r = document.createElement('div');
      r.id = ROOT_ID;
      if (document.body) document.body.appendChild(r);
      return r;
    }

    function isOpen(){ return OPEN !== null; }

    function spec(){ return OPEN ? OPEN.spec : null; }

    // --- ZAMOK ODOSLANIA (review #2) -----------------------------------------
    // `sketchup.*` je ASYNCHRONNE. Bez zamku by dvojity Enter (alebo dvojklik na
    // „Pridať") odoslal DVE mutacie: prva ide na server, druha padne do fronty
    // klienta (BUD_BUSY/BUD_QUEUE) a odosle sa AZ s cerstvou generaciou — cize
    // ju server PRIJME. Vysledok: polozka v rozpocte DVAKRAT a dva kroky Spat.
    // Zamok patri do KOMPONENTU, nie do rozpoctu: je to zdielana kostra a tu
    // istu pascu by inak zdedila kazda dalsia „pridavacka" (D-69 editor
    // materialu, polozka/set kovania).
    //
    // Odomyka VYHRADNE volajuci — az ked vie, ako zapis dopadol (`setBusy(false)`
    // v OBOCH vetvach vysledku). Modal si to sam odhadnut nevie.
    function isBusy(){ return !!(OPEN && OPEN.busy); }

    // `opts.clear === true` navyse ZAHODI pamat rozpisanych hodnot — je to
    // signal „server zapis POTVRDIL". Rovnaka vec sa da povedat aj priamo cez
    // `clearMemory(key)`; volajuci si vyberie podla toho, ci pri uspechu okno
    // zaroven zatvara.
    function setBusy(flag, opts){
      if (!OPEN) return;
      OPEN.busy = flag === true;
      if (opts && opts.clear === true) clearMemory(OPEN.base ? OPEN.base.memoryKey : null);
      if (typeof document === 'undefined') return;
      var r = document.getElementById(ROOT_ID);
      var btn = r && r.querySelector ? r.querySelector('[data-nxm-act="submit"]') : null;
      if (!btn) return;
      // Zosednute tlacidlo je JEDINY viditelny znak, ze zapis prave bezi —
      // bez neho by pouzivatel klikal dalej do zamknuteho okna.
      if (OPEN.busy){
        btn.setAttribute('disabled', 'disabled');
        btn.setAttribute('aria-busy', 'true');
      } else {
        btn.removeAttribute('disabled');
        btn.removeAttribute('aria-busy');
      }
    }

    // Riadky repeatera sa citaju z DOM (nie z drzaneho pola) — pridanie
    // a odobranie riadku prekresluje LEN kontajner, takze rozpisane hodnoty
    // ostatnych riadkov musia prezit prave cez tento zapis.
    function rowsBox(key){
      if (typeof document === 'undefined') return null;
      return document.getElementById('nxmr_' + key);
    }

    function readRows(key){
      var out = [];
      var box = rowsBox(key);
      if (!box || !box.querySelectorAll) return out;
      var lines = box.querySelectorAll('[data-nxm-row]');
      for (var i = 0; i < lines.length; i++){
        var row = {};
        var cells = lines[i].querySelectorAll ? lines[i].querySelectorAll('[data-nxm-col]') : [];
        for (var j = 0; j < cells.length; j++){
          var c = cells[j];
          var ck = c.getAttribute('data-nxm-col');
          if (c.getAttribute('type') === 'checkbox') row[ck] = !!c.checked;
          else row[ck] = String(c.value == null ? '' : c.value);
        }
        out.push(row);
      }
      return out;
    }

    // --- CHYBY PRI POLIACH (ŠT-2c 2c-2a) ------------------------------------
    // Server validuje CELY formular naraz a vracia [{row, field, msg}]. Modal
    // sa pri odmietnutom zapise NEZATVARA (kontrakt D-15), takze chyba musi
    // pristat PRI TOM POLI, ktoreho sa tyka — inak pouzivatel v dlhom
    // formulari s desiatimi riadkami hlada, ktora cena je zla.
    //   `row` = null    -> ploche pole (`#nxm_<field>`), hlaska pod jeho `.mrow`,
    //   `row` = "k:idx" -> RIADOK repeatera (`k` = kluc pola), hlaska pod riadkom,
    //   nezaraditelna   -> zberny pas navrchu tela.
    function classHas(node, cls){
      return String((node && node.className) || '').split(/\s+/).indexOf(cls) >= 0;
    }

    function markBad(node){
      if (!node || !node.setAttribute) return;
      if (!classHas(node, 'bad')) node.className = String(node.className || '') ? (node.className + ' bad') : 'bad';
      node.setAttribute('aria-invalid', 'true');
    }

    function errNode(host){
      if (!host || typeof document === 'undefined') return null;
      var n = host.querySelector ? host.querySelector('.merr') : null;
      if (n) return n;
      n = document.createElement('div');
      n.className = 'merr';
      n.setAttribute('role', 'status');
      host.appendChild(n);
      return n;
    }

    function clearErrors(){
      if (typeof document === 'undefined') return;
      var r = document.getElementById(ROOT_ID);
      if (!r || !r.querySelectorAll) return;
      var errs = r.querySelectorAll('.merr');
      for (var i = 0; i < errs.length; i++) errs[i].textContent = '';
      var bad = r.querySelectorAll('.bad');
      for (var j = 0; j < bad.length; j++){
        bad[j].className = String(bad[j].className || '').split(/\s+/)
          .filter(function(c){ return c && c !== 'bad'; }).join(' ');
        if (bad[j].removeAttribute) bad[j].removeAttribute('aria-invalid');
      }
      var top = r.querySelector ? r.querySelector('[data-nxm-errtop]') : null;
      if (top) top.textContent = '';
    }

    function showErrors(list){
      if (typeof document === 'undefined') return;
      clearErrors();
      var r = document.getElementById(ROOT_ID);
      if (!r) return;
      var rest = [];
      (list || []).forEach(function(e){
        if (!e) return;
        var msg = String(e.msg == null ? '' : e.msg);
        var host = null;
        var input = null;
        var rowKey = (e.row == null) ? '' : String(e.row);
        if (rowKey){
          var parts = rowKey.split(':');
          var box = rowsBox(parts[0]);
          var lines = (box && box.querySelectorAll) ? box.querySelectorAll('[data-nxm-row]') : [];
          var line = lines[Number(parts[1])];
          if (line){
            host = line;
            if (e.field && line.querySelector) input = line.querySelector('[data-nxm-col="' + e.field + '"]');
          }
        } else if (e.field){
          input = document.getElementById('nxm_' + e.field);
          host = (input && input.closest) ? input.closest('.mrow') : null;
        }
        if (!host){ rest.push(msg); return; }
        markBad(input);
        var n = errNode(host);
        if (n) n.textContent = n.textContent ? (n.textContent + ' · ' + msg) : msg;
      });
      var top = r.querySelector ? r.querySelector('[data-nxm-errtop]') : null;
      if (top) top.textContent = rest.join(' · ');
    }

    function fieldByKey(key){
      var found = null;
      ((OPEN && OPEN.spec && OPEN.spec.fields) || []).forEach(function(f){
        if (f && f.type === 'rows' && String(f.key) === String(key)) found = f;
      });
      return found;
    }

    // Pole VYCHODISKOVEJ specifikacie (to, co podal volajuci) — proti nemu sa
    // porovnava pamat a dopĺňa sa obsah po zotaveni z konfliktu.
    function baseFieldByKey(key){
      var found = null;
      ((OPEN && OPEN.base && OPEN.base.fields) || []).forEach(function(f){
        if (f && String(f.key) === String(key)) found = f;
      });
      return found;
    }

    function shallow(o){
      var out = {};
      var k;
      for (k in o){ if (Object.prototype.hasOwnProperty.call(o, k)) out[k] = o[k]; }
      return out;
    }

    // POZOR: `withMemory` vracia pri prazdnej pamati TEN ISTY objekt, takze
    // `OPEN.spec === OPEN.base` a rovnako aj ich POLIA su jeden a ten isty
    // objekt. Zapis do „specifikacie" by potom prepisal aj VYCHODISKOVE
    // hodnoty (a naopak) — pamat by prestala vidiet, co pouzivatel rozpisal.
    // Pred zmenou obsahu za behu si preto spec rozdvojime.
    function ownSpecField(key){
      if (!OPEN) return null;
      var f = fieldByKey(key);
      var b = baseFieldByKey(key);
      if (!f || f !== b) return f;
      if (OPEN.spec === OPEN.base){
        var copy = shallow(OPEN.base);
        copy.fields = (OPEN.base.fields || []).slice();
        OPEN.spec = copy;
      }
      var own = shallow(f);
      OPEN.spec.fields = (OPEN.spec.fields || []).map(function(x){ return x === f ? own : x; });
      return own;
    }

    // Vymena OBSAHU repeatera za behu (zotavenie z konfliktu — audit 2c-2a #1b):
    // volajuci podá riadky uz zlucene (cerstvy katalog + hodnoty pouzivatela)
    // a `opts.base` = CISTY stav zo servera, aby pamat rozpisu porovnavala
    // proti tomu, co dnes naozaj je v katalogu, nie proti stavu spred konfliktu.
    function setRows(key, data, opts){
      var f = ownSpecField(key);
      if (!f) return;
      var b = baseFieldByKey(key);
      if (b && opts && opts.base) b.value = opts.base;
      f.value = data || [];
      renderRows(f, f.value);
    }

    function renderRows(f, data){
      var box = rowsBox(f.key);
      if (!box) return;
      box.innerHTML = rowsInnerHtml(f, data);
    }

    // Vysvetlenie pri zamknutom „−" (D-78: dovod patri na obrazovku, nie do
    // ticha). Prezije do najblizsieho prekreslenia kontajnera.
    function rowNote(key, msg){
      var box = rowsBox(key);
      var n = box && box.querySelector ? box.querySelector('.mrnote') : null;
      if (n) n.textContent = msg;
    }

    function rowAdd(key){
      var f = fieldByKey(key);
      if (!f || typeof document === 'undefined') return;
      var cur = readRows(key);
      cur.push({});
      renderRows(f, cur);
      // Fokus do prveho pola PRAVE pridaneho riadku — pridanie riadku je
      // zaciatok pisania, nie samoucelne kliknutie.
      var box = rowsBox(key);
      var lines = box && box.querySelectorAll ? box.querySelectorAll('[data-nxm-row]') : [];
      var last = lines.length ? lines[lines.length - 1] : null;
      var cells = last && last.querySelectorAll ? last.querySelectorAll('[data-nxm-col]') : [];
      for (var i = 0; i < cells.length; i++){
        if (cells[i].getAttribute('type') === 'hidden') continue;
        try { cells[i].focus(); } catch (e) { /* fokus nie je kriticky */ }
        break;
      }
    }

    function rowDel(btn){
      if (typeof document === 'undefined') return;
      var line = btn && btn.closest ? btn.closest('[data-nxm-row]') : null;
      if (!line) return;
      var key = line.getAttribute('data-nxm-row');
      var f = fieldByKey(key);
      if (!f) return;
      if (btn.getAttribute && btn.getAttribute('aria-disabled') === 'true'){
        rowNote(key, btn.getAttribute('title') || 'Tento riadok sa odobrať nedá.');
        return;
      }
      var box = rowsBox(key);
      var lines = box && box.querySelectorAll ? box.querySelectorAll('[data-nxm-row]') : [];
      var idx = -1;
      for (var i = 0; i < lines.length; i++){ if (lines[i] === line) idx = i; }
      if (idx < 0) return;
      var cur = readRows(key);
      cur.splice(idx, 1);
      renderRows(f, cur);
    }

    // Hodnoty poli -> objekt. Cita sa VZDY z DOM, aby to, co pouzivatel vidi,
    // bolo presne to, co sa odosle. TVAR (audit ŠT-2c #14):
    //   text/select -> RETAZEC (nezmenene — drafty rozpoctu na tom stoja),
    //   checkbox    -> BOOLEAN,
    //   rows        -> POLE HASHOV,
    //   group       -> v hodnotach VOBEC NIE JE (je to nadpis, nie pole).
    function values(){
      var out = {};
      if (!OPEN || typeof document === 'undefined') return out;
      (OPEN.spec.fields || []).forEach(function(f){
        if (!f || f.type === 'group') return;
        if (f.type === 'rows'){ out[f.key] = readRows(f.key); return; }
        var node = document.getElementById('nxm_' + f.key);
        if (f.type === 'checkbox'){ out[f.key] = !!(node && node.checked); return; }
        out[f.key] = node ? String(node.value == null ? '' : node.value) : '';
      });
      return out;
    }

    // --- pamat: kluc, citanie, mazanie, zapis --------------------------------
    // Slot = kluc bez posledneho segmentu, ked su segmenty aspon TRI
    // (`mat:edit:H3303` -> `mat:edit`); inak cely kluc (`bud:custom`).
    function memSlot(key){
      var parts = String(key).split(':');
      return parts.length >= 3 ? parts.slice(0, -1).join(':') : String(key);
    }

    function memory(key){
      if (key == null || key === '') return null;
      var slot = MEM[memSlot(key)];
      return (slot && slot.key === String(key)) ? slot.values : null;
    }

    function clearMemory(key){
      if (key == null || key === '') return;
      var s = memSlot(key);
      if (MEM[s] && MEM[s].key === String(key)) delete MEM[s];
      // Zatvorenie modalu hodnoty zapamätáva — keby sa pamat mazala PRED nim,
      // close() by ju hned zapisal spat. Preto sa zaroven zhasina zapis.
      // Zhasnutie je DOCASNE: prve pisanie do karty ho zapali spat (#3), aby
      // scenar „ulozil som a pisem dalej" nebol tichou stratou.
      if (OPEN && OPEN.base && String(OPEN.base.memoryKey) === String(key)) OPEN.memSkip = true;
    }

    // VYCHODISKOVE hodnoty (to, co podal volajuci) — proti nim sa porovnava,
    // ci pouzivatel vobec nieco rozpisal.
    function defaultsOf(){
      var d = {};
      ((OPEN && OPEN.base && OPEN.base.fields) || []).forEach(function(f){
        if (!f || f.type === 'group') return;
        if (f.type === 'rows'){ d[f.key] = f.value || []; return; }
        if (f.type === 'checkbox'){ d[f.key] = f.value === true; return; }
        if (f.type === 'select'){
          var dv = f.value == null ? '' : String(f.value);
          // Bez `value` ukaze prehliadac PRVU moznost — to je default, nie zapis.
          if (dv === '' && (f.options || []).length) dv = String(f.options[0][0]);
          d[f.key] = dv;
          return;
        }
        d[f.key] = String(f.value == null ? '' : f.value);
      });
      return d;
    }

    // Porovnanie hodnoty pola s jeho defaultom. Riadky su pole hashov, takze
    // sa porovnavaju po prvkoch a poradie klucov nesmie rozhodovat; prazdne
    // hodnoty sa na OBOCH stranach ignoruju (skryte pole s prazdnou hodnotou
    // sa vobec nevykresli).
    function sameRow(a, b){
      var ka = Object.keys(a || {}).filter(function(k){ return a[k] !== '' && a[k] !== false; });
      var kb = Object.keys(b || {}).filter(function(k){ return b[k] !== '' && b[k] !== false; });
      if (ka.length !== kb.length) return false;
      for (var i = 0; i < ka.length; i++){
        var k = ka[i];
        if (!Object.prototype.hasOwnProperty.call(b || {}, k)) return false;
        if (String(a[k]) !== String(b[k])) return false;
      }
      return true;
    }

    function sameValue(a, b){
      var aArr = a && typeof a.forEach === 'function';
      var bArr = b && typeof b.forEach === 'function';
      if (aArr || bArr){
        if (!aArr || !bArr) return false;
        if (a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++){ if (!sameRow(a[i], b[i])) return false; }
        return true;
      }
      if (a === true || b === true || a === false || b === false) return a === b;
      return String(a == null ? '' : a) === String(b == null ? '' : b);
    }

    // Zapamätanie prebieha pri ODOSLANI aj pri ZATVORENI — Escape ani klik
    // vedla nesmie byt ticha strata rozpisaneho formulara (kontrakt D-15 z PR
    // B2). Ukladaju sa VYHRADNE polia, ktore sa lisia od defaultov (#2), takze
    // „nic som nepisal, len som okno otvoril a zavrel" pamat nezaklada.
    // --- PAMAT RIADKOV: LEN to, co pouzivatel napisal (audit 2c-2a #1a) ------
    // Riadok nesie aj SERVER-OWNED skryte polia (`row_rev` = odtlacok zaznamu
    // v case otvorenia). Keby ich pamat drzala a pri dalsom otvoreni vliala
    // spat, formular by odosielal ZASTARANY odtlacok a server by ho odmietol
    // ako konflikt — pamat by sa stala pascou, z ktorej niet cesty von.
    // Pamataju sa preto LEN editovatelne stlpce + `rowKey` (identita riadku,
    // podla ktorej sa hodnoty priradia k CERSTVYM riadkom).
    function trimRowsValue(f, rows){
      var keep = {};
      (f.cols || []).forEach(function(c){ keep[c.key] = true; });
      if (f.rowKey) keep[f.rowKey] = true;
      return (rows || []).map(function(r){
        var out = {};
        var k;
        for (k in r){
          if (Object.prototype.hasOwnProperty.call(r, k) && keep[k]) out[k] = r[k];
        }
        return out;
      });
    }

    // Vliatie pamate do CERSTVYCH riadkov: parovanie podla `rowKey`.
    //   riadok, ktory v cerstvom katalogu JE   -> prepisu sa mu LEN stlpce,
    //   riadok z pamate BEZ identity            -> je to novy, rozpisany riadok,
    //   riadok z pamate, ktory uz neexistuje    -> ZAHODI sa (zaznam je prec).
    function mergeRowsMemory(f, mem){
      var base = f.value || [];
      var rows = mem || [];
      var keyName = f.rowKey;
      if (!keyName) return rows.length ? rows : base;
      var byKey = {};
      rows.forEach(function(r){
        var k = r && r[keyName];
        if (k != null && k !== '') byKey[String(k)] = r;
      });
      var out = base.map(function(r){
        var k = r && r[keyName];
        var m = (k != null && k !== '') ? byKey[String(k)] : null;
        if (!m) return r;
        var g = {};
        var kk;
        for (kk in r){ if (Object.prototype.hasOwnProperty.call(r, kk)) g[kk] = r[kk]; }
        (f.cols || []).forEach(function(c){
          if (Object.prototype.hasOwnProperty.call(m, c.key)) g[c.key] = m[c.key];
        });
        delete byKey[String(k)];
        return g;
      });
      rows.forEach(function(r){
        var k = r && r[keyName];
        if (k == null || k === '') out.push(r); // rozpisany NOVY riadok
      });
      return out;
    }

    function remember(){
      if (!OPEN || OPEN.memSkip) return;
      var key = OPEN.base ? OPEN.base.memoryKey : null;
      if (key == null || key === '') return;
      var v = values();
      var def = defaultsOf();
      var out = {};
      var any = false;
      Object.keys(v).forEach(function(k){
        if (sameValue(v[k], def[k])) return;
        var f = baseFieldByKey(k);
        out[k] = (f && f.type === 'rows') ? trimRowsValue(f, v[k]) : v[k];
        any = true;
      });
      var s = memSlot(key);
      if (!any){
        if (MEM[s] && MEM[s].key === String(key)) delete MEM[s];
        return;
      }
      MEM[s] = { key: String(key), values: out };
    }

    // Otvorenie INEHO ciela v tom istom rezime stary rozpis ZAHADZUJE — nie
    // az pri najblizsom zapise, ale HNED. Inak by rozpisana verzia dekoru A
    // zila dalej a po zavreti editora dekoru B by sa vratila na obrazovku.
    function dropForeign(key){
      if (key == null || key === '') return;
      var s = memSlot(key);
      if (MEM[s] && MEM[s].key !== String(key)) delete MEM[s];
    }

    // Zapamätane hodnoty sa vlievaju do POLI specifikacie — volajuci teda
    // nemusi o pamati vediet vobec. `fromMemory` rozsvieti info pas.
    function withMemory(s){
      dropForeign(s.memoryKey);
      var mem = memory(s.memoryKey);
      if (!mem) return s;
      var out = {}, k;
      for (k in s){ if (Object.prototype.hasOwnProperty.call(s, k)) out[k] = s[k]; }
      out.fromMemory = true;
      out.fields = (s.fields || []).map(function(f){
        if (!f || f.type === 'group') return f;
        if (!Object.prototype.hasOwnProperty.call(mem, f.key)) return f;
        var g = {}, kk;
        for (kk in f){ if (Object.prototype.hasOwnProperty.call(f, kk)) g[kk] = f[kk]; }
        // Riadky sa NEPREPISUJU cele — pamat nesie len stlpce, identita a
        // odtlacok zaznamu prichadzaju CERSTVE z katalogu (audit 2c-2a #1a).
        g.value = (f.type === 'rows') ? mergeRowsMemory(f, mem[f.key]) : mem[f.key];
        return g;
      });
      return out;
    }

    // „Začať odznova" — pas z pamate ponuka CESTU VON: formular sa prekresli
    // z VYCHODISKOVYCH hodnot a pamat zanikne.
    function memReset(){
      if (!OPEN || typeof document === 'undefined') return;
      clearMemory(OPEN.base ? OPEN.base.memoryKey : null);
      OPEN.spec = OPEN.base;
      OPEN.memSkip = true;
      var r = document.getElementById(ROOT_ID);
      if (!r) return;
      r.innerHTML = modalHtml(OPEN.base);
      focusFirst(r);
    }

    // Prve pole na fokus. Skryte polia riadkov (`type="hidden"`) sa preskakuju
    // — fokus v nich by nebolo vidno.
    function firstField(r){
      var list = r.querySelectorAll ? r.querySelectorAll('.mbody input, .mbody select') : null;
      if (list && list.length){
        for (var i = 0; i < list.length; i++){
          if (list[i].getAttribute && list[i].getAttribute('type') === 'hidden') continue;
          return list[i];
        }
        return null;
      }
      return r.querySelector ? r.querySelector('.mbody input, .mbody select') : null;
    }

    function focusFirst(r){
      // Fokus do PRVEHO pola (kontrakt D-15). `setTimeout` preto, ze CEF
      // priradi fokus az po dokresleni — okamzity `focus()` by sa stratil.
      //
      // ŠT-3c-1 (review #225): modal BEZ POLI (ciste potvrdenie, napr. mazanie
      // sablony) nema kam dat fokus a ten ostane na tlacidle, ktore modal
      // otvorilo — Enter za scrimom by ho otvoril ZNOVA. Fokus vtedy dostane
      // POTVRDZOVACIE tlacidlo v patke: klavesnicova cesta pokracuje tam, kde
      // pouzivatel prave je.
      var first = firstField(r) ||
                  (r.querySelector ? r.querySelector('.mfoot [data-nxm-act="submit"]') : null);
      if (!first) return;
      try { first.focus(); } catch (e) { /* fokus nie je kriticky */ }
      setTimeout(function(){ try { first.focus(); } catch (e) {} }, 20);
    }

    function warnDupKeys(s){
      var seen = {};
      ((s || {}).fields || []).forEach(function(f){
        if (!f || f.type === 'group' || f.key == null) return;
        var k = String(f.key);
        if (seen[k]) warn('duplicitný kľúč poľa „' + k + '" — hodnoty sa navzájom prepíšu.');
        seen[k] = true;
      });
    }

    function open(s){
      if (!s || typeof document === 'undefined') return;
      var r = root();
      if (!r) return;
      var trigger = document.activeElement || null;
      close(); // dva modaly naraz su vzdy chyba navrhu
      warnDupKeys(s);
      var eff = withMemory(s);
      OPEN = { base: s, spec: eff, trigger: trigger, busy: false, memSkip: false };
      r.innerHTML = modalHtml(eff);
      focusFirst(r);
    }

    function close(){
      if (typeof document === 'undefined'){ OPEN = null; return; }
      remember();                       // Esc nesmie byt ticha strata hodnot
      var r = document.getElementById(ROOT_ID);
      if (r) r.innerHTML = '';
      var back = OPEN && OPEN.trigger;
      OPEN = null;
      // Fokus patri spat na spustac — inak by po zatvoreni skoncil na <body>
      // a klavesnicova cesta by sa prerusila presne tam, kde zacala.
      if (back && back.focus){
        try { back.focus(); } catch (e) { /* uzol uz nemusi zit */ }
      }
    }

    function submit(){
      var s = OPEN && OPEN.spec;
      if (!s) return;
      if (OPEN.busy) return; // review #2: druhy Enter/klik sa ZAHADZUJE
      var v = values();
      remember();            // hodnoty su zapamatane PRED odoslanim
      setBusy(true);
      // Zatvorenie je na volajucom (audit #10) — server moze zapis odmietnut
      // a modal musi ostat otvoreny s hodnotami. Odomknutie tiez: volajuci
      // vola `setBusy(false)` v OBOCH vetvach vysledku.
      if (typeof s.onSubmit === 'function') s.onSubmit(v);
    }

    // --- FOKUS ZOSTAVA V KARTE (review #7) -----------------------------------
    // Tab z posledneho prvku modalu by inak skocil do okna ZA nim — do tabulky
    // rozpoctu, ktoru pouzivatel prave nemoze ovladat. Je to vzor pre VSETKY
    // buduce pridavacky, preto to zije v komponente.
    function focusables(){
      if (typeof document === 'undefined') return [];
      var r = document.getElementById(ROOT_ID);
      var card = r && r.querySelector ? r.querySelector('.nxmcard') : null;
      if (!card || !card.querySelectorAll) return [];
      // POZOR na `[href]`: ikony su inline SVG a `<use href="#i-…">` ten
      // selektor SPLNA — posledny „zameratelny" prvok karty by tak bol kus
      // ikony vnutri potvrdzovacieho tlacidla a Tab by cyklil do prazdna.
      // Odkaz je `a[href]`, nic ine.
      var all = card.querySelectorAll('input, select, textarea, button, a[href], [tabindex]');
      var out = [];
      for (var i = 0; i < all.length; i++){
        var n = all[i];
        // `aria-disabled` prvky sa NEVYHADZUJU (D-78): su zameratelne a klik
        // povie dovod. Vyhadzuje sa len tvrdy `disabled` a `tabindex="-1"`.
        if (n.hasAttribute && n.hasAttribute('disabled')) continue;
        if (n.getAttribute && n.getAttribute('tabindex') === '-1') continue;
        // Skryte polia riadkov (id/rev variantu) nie su ovladacie prvky.
        if (n.getAttribute && n.getAttribute('type') === 'hidden') continue;
        out.push(n);
      }
      return out;
    }

    function trapTab(ev){
      var list = focusables();
      if (!list.length) return;           // prazdna karta = niet co cyklit
      var first = list[0];
      var last = list[list.length - 1];
      var at = document.activeElement;
      if (ev.shiftKey){
        if (at !== first && list.indexOf(at) >= 0) return;
        ev.preventDefault();
        try { last.focus(); } catch (e) { /* fokus nie je kriticky */ }
        return;
      }
      if (at !== last && list.indexOf(at) >= 0) return;
      ev.preventDefault();
      try { first.focus(); } catch (e) { /* fokus nie je kriticky */ }
    }

    if (typeof document !== 'undefined'){
      document.addEventListener('click', function(ev){
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.closest) return;
        var act = t.closest('[data-nxm-act]');
        if (act){
          var a = act.getAttribute('data-nxm-act');
          if (a === 'submit') submit();
          else if (a === 'rowadd') rowAdd(act.getAttribute('data-nxm-rows'));
          else if (a === 'rowdel') rowDel(act);
          else if (a === 'memreset') memReset();
          else if (a === 'close') close();
          // Ziadny catch-all: neznama akcia MLCKY ZATVARALA modal a rozpisany
          // formular by zmizol po kliku na tlacidlo, ktore malo robit nieco ine.
          else warn('neznáma akcia „' + a + '" — modal ostáva otvorený.');
          return;
        }
        // Klik VEDLA karty (priamo na scrim) zatvara; klik dovnutra nie.
        if (t.getAttribute && t.getAttribute('data-nxm-scrim') === '1') close();
      });

      // Prve pisanie do karty PO signale „server potvrdil" pamat opat zapina
      // (#3): scenar „ulozil som a pisem dalsiu polozku" nesmie byt ticha
      // strata len preto, ze predchadzajuci zapis presiel.
      function touched(ev){
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.getAttribute) return;
        if (!t.getAttribute('data-nxm') && !t.getAttribute('data-nxm-col')) return;
        OPEN.memSkip = false;
      }
      document.addEventListener('change', touched);

      // Vzorka farby ide za textom — pouzivatel musi vidiet, co si prave napisal.
      document.addEventListener('input', function(ev){
        touched(ev);
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.getAttribute || t.getAttribute('data-nxm-color') !== '1') return;
        var sw = document.getElementById('nxm_' + t.getAttribute('data-nxm') + '_sw');
        if (sw && sw.style) sw.style.background = isHex(t.value) ? String(t.value) : '';
      });

      document.addEventListener('keydown', function(ev){
        if (!OPEN) return;
        if (ev.key === 'Escape'){
          close();
          // Escape SPOTREBUJE modal — okno za nim (Studio zatvara Escapom svoje
          // rozbalovacie nastavenie hran) ho uz vidiet nesmie, inak by jedno
          // stlacenie zavrelo OBOJE. `stopPropagation` by nestacilo: oba
          // listenery visia na TOM ISTOM uzle (`document`) a ten ich nezastavi
          // — musi to byt `stopImmediatePropagation`, ktore zastavi aj dalsich
          // poslucháčov toho isteho uzla. Funguje to preto, ze `nx_modal.js` sa
          // nacitava PRED `studio.js` (stráži guard test), takze jeho listener
          // je v poradi prvy; podmienka `!nxModalOpen()` v Studiu ostava ako
          // druha poistka pre pripad opacneho poradia.
          if (ev.stopImmediatePropagation) ev.stopImmediatePropagation();
          return;
        }
        if (ev.key === 'Tab'){ trapTab(ev); return; }
        // Enter v poli = potvrdenie (vzor formulara). Do <select> nezasahuje —
        // tam Enter otvara/potvrdzuje vlastnu ponuku prehliadaca. Plati aj pre
        // bunky opakovatelnych riadkov (`data-nxm-col`), aby sa formular
        // nespraval inak podla toho, v ktorom poli pouzivatel stoji.
        if (ev.key !== 'Enter') return;
        var t = ev.target;
        if (!t || !t.getAttribute) return;
        if (!t.getAttribute('data-nxm') && !t.getAttribute('data-nxm-col')) return;
        if (t.tagName === 'SELECT') return;
        ev.preventDefault();
        submit();
      });
    }

    var API = { ROOT_ID: ROOT_ID, modalHtml: modalHtml, fieldHtml: fieldHtml,
                rowsHtml: rowsHtml, cardCls: cardCls,
                open: open, close: close, submit: submit,
                isOpen: isOpen, isBusy: isBusy, setBusy: setBusy,
                values: values, spec: spec, setRows: setRows,
                showErrors: showErrors, clearErrors: clearErrors,
                memory: memory, clearMemory: clearMemory };
    global.NXModal = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
