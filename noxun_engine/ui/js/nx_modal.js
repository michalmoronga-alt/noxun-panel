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
  // KOV-H2 pridala typ `lookup` (naseptavac nad SERVEROVYM hladanim) — je
  // GENERICKY: kostra nevie, ci hlada polozku katalogu kovania alebo cokolvek
  // ine, dostane len funkciu `search` a kresli, co jej vrati.
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
    // Otvoreny modal: { base, spec, trigger, busy, memSkip, flags }.
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
    //
    // PAMATA SA PO BUNKACH, NIE PO CELYCH RIADKOCH (1b-7, sweep #8/#9). Riadok
    // nesie aj hodnoty, ktorych sa pouzivatel NEDOTKOL; keby ich pamat drzala
    // a pri dalsom otvoreni vliala do CERSTVEHO riadku, vratila by cenu, ktoru
    // medzitym zmenil katalog (napr. „Aktualizovať z Demosu") — a to potichu,
    // lebo `row_rev` by pritom ostal cerstvy a optimisticky zamok by prekazku
    // nevidel. Zapamata sa preto LEN bunka, ktora sa lisi od VYCHODISKOVEHO
    // riadku, a k nej `_base` = hodnota, proti ktorej ju pouzivatel pisal.
    // Podla `_base` sa pri dalsom otvoreni pozna KOLIZIA (katalog zmenil tu
    // istu bunku) — tá sa pouzivatelovi UKAZE a pyta rozhodnutie.
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
    //   'rows' (opakovatelne riadky, hodnota je POLE HASHOV) ·
    //   'lookup' (KOV-H2: naseptavac so SERVEROVYM hladanim — nizsie).
    // `cls` je doplnkova trieda vstupu (napr. `mshort`).
    function fieldHtml(f){
      var d = f || {};
      if (d.type === 'group'){
        return '<div class="mgroup"><h4>' + esc(d.label) + '</h4>' +
               (d.hint ? '<span>' + esc(d.hint) + '</span>' : '') + '</div>';
      }
      if (d.type === 'rows') return rowsHtml(d, d.value);
      if (d.type === 'lookup') return lookupHtml(d);
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

    // --- POLE `lookup` (KOV-H2) ----------------------------------------------
    // Naseptavac nad ZOZNAMOM, ktory drzi SERVER: textove pole + ponuka
    // vysledkov. Kostra o obsahu nevie NIC — volajuci dodava `search`, ktory
    // si vysledky vypyta (v Inspectorovi callbackom `hw_manual_search`) a
    // zavola `done(items, total)`. Polozka ma tvar `{ value, text, hint }`;
    // `render`/`hint` su volitelne prepisy pre surovejsi tvar.
    //
    // TRI VECI, KTORE SU KONTRAKT (a preto ziju TU, nie u volajuceho):
    //   1. `values()` vracia LEN `value` (kod) — NIKDY nazov ani cenu. Server
    //      si nazov aj cenu dopĺňa sam z katalogu (KOV-H1 FIX 12: klientovi sa
    //      veri len kod), takze poslat mu text z obrazovky by bola cesta, ako
    //      dostat do zakazky cenu, ktora uz neplati.
    //   2. PISANIE ZAHADZUJE VYBER. Ked pouzivatel po vybere do pola dopise
    //      znak, skryta hodnota sa vycisti — inak by odoslal STARY kod pod
    //      NOVYM textom a na obrazovke by o tom nebolo ani slovo.
    //   3. STARSIA ODPOVED SA IGNORUJE (`seq`). Odpovede chodia asynchronne,
    //      takze pomalsie kolo by inak prepisalo cerstvejsie vysledky.
    //
    // Ponuka je VLASTNA VRSTVA: Escape zatvara JU, nie modal (vzor naseptavaca
    // `#mdSgBox`), a Enter v poli hladania formular NIKDY neodosle.
    function lookupHtml(f){
      var d = f || {};
      var key = esc(d.key);
      var id = 'nxm_' + key;
      // Ked volajuci nema ulozeny popis vybraneho zaznamu, ukaze sa HODNOTA
      // (kod). Prazdne pole nad neprazdnou hodnotou by klamalo.
      var qval = (d.valueText == null || d.valueText === '')
        ? (d.value == null ? '' : d.value) : d.valueText;
      return '<div class="mrow mlookup" data-nxm-lkrow="' + key + '">' +
        '<label for="' + id + '_q">' + esc(d.label) + '</label>' +
        '<input id="' + id + '_q" type="text" class="mlkq" data-nxm-lkq="' + key + '"' +
        ' autocomplete="off" role="combobox" aria-autocomplete="list" aria-expanded="false"' +
        ' aria-controls="nxmlk_' + key + '" value="' + esc(qval) + '"' +
        (d.placeholder ? ' placeholder="' + esc(d.placeholder) + '"' : '') + '>' +
        // Skryte pole je JEDINA odosielana hodnota (`values()` cita `nxm_<key>`).
        '<input type="hidden" id="' + id + '" data-nxm="' + key + '"' +
        ' value="' + esc(d.value == null ? '' : d.value) + '">' +
        '<div class="mlkhint" data-nxm-lkhint="' + key + '">' +
        esc(lookupInitialHint(d)) + '</div>' +
        '<div class="mlklist" id="nxmlk_' + key + '" data-nxm-lklist="' + key + '"' +
        ' role="listbox"></div></div>';
    }

    // `hint` smie byt FUNKCIA (popis vybranej polozky) alebo TEXT (staticka
    // vysvetlivka pod polom) — pri funkcii sa na zaciatku nekresli nic.
    function lookupInitialHint(d){
      if (typeof d.hint === 'function') return d.hintText == null ? '' : d.hintText;
      return d.hint == null ? (d.hintText == null ? '' : d.hintText) : d.hint;
    }

    function lookupSpec(key){
      var found = null;
      ((OPEN && OPEN.spec && OPEN.spec.fields) || []).forEach(function(f){
        if (f && f.type === 'lookup' && String(f.key) === String(key)) found = f;
      });
      return found;
    }

    function lookupState(key){
      if (!OPEN) return null;
      OPEN.lookup = OPEN.lookup || {};
      if (!OPEN.lookup[key]){
        OPEN.lookup[key] = { seq: 0, items: [], total: 0, active: -1, open: false };
      }
      return OPEN.lookup[key];
    }

    function lkNode(attr, key){
      if (typeof document === 'undefined') return null;
      var r = document.getElementById(ROOT_ID);
      return (r && r.querySelector) ? r.querySelector('[' + attr + '="' + key + '"]') : null;
    }

    function lookupText(f, it){
      if (f && typeof f.render === 'function'){
        var t = f.render(it);
        return String(t == null ? '' : t);
      }
      if (it && it.text != null) return String(it.text);
      return String(it == null ? '' : it);
    }

    function lookupHintOf(f, it){
      if (f && typeof f.hint === 'function'){
        var h = f.hint(it);
        return String(h == null ? '' : h);
      }
      return String((it && it.hint != null) ? it.hint : '');
    }

    function lookupValueOf(it){
      if (it && it.value != null) return String(it.value);
      return String(it == null ? '' : it);
    }

    function lookupExpanded(key, on){
      var q = lkNode('data-nxm-lkq', key);
      if (q && q.setAttribute) q.setAttribute('aria-expanded', on ? 'true' : 'false');
    }

    function lookupRender(key){
      var box = lkNode('data-nxm-lklist', key);
      if (!box) return;
      var f = lookupSpec(key);
      var s = lookupState(key);
      if (!s || !s.open){ box.innerHTML = ''; lookupExpanded(key, false); return; }
      var h = '';
      s.items.forEach(function(it, i){
        var on = i === s.active;
        h += '<button type="button" class="mlkitem' + (on ? ' on' : '') + '" role="option"' +
             ' aria-selected="' + (on ? 'true' : 'false') + '"' +
             ' data-nxm-act="lookuppick" data-nxm-lk="' + esc(key) + '"' +
             ' data-nxm-idx="' + i + '">' + esc(lookupText(f, it)) + '</button>';
      });
      if (!s.items.length){
        h += '<div class="mlkempty">Nič sa nenašlo — skús iné slovo alebo kód.</div>';
      } else if (s.total > s.items.length){
        // ZIADNE TICHE OREZANIE (zasada „no silent caps"): kolko sa nezmestilo,
        // musi byt vidno — inak pouzivatel hlada polozku, ktora „tam nie je".
        h += '<div class="mlkmore">… ďalších ' + (s.total - s.items.length) +
             ' — spresni hľadanie</div>';
      }
      box.innerHTML = h;
      lookupExpanded(key, true);
    }

    function lookupClose(key){
      var s = lookupState(key);
      if (!s) return;
      s.open = false;
      s.active = -1;
      lookupRender(key);
    }

    // Zatvori ponuky VSETKYCH lookupov okrem `keep` (klik mimo).
    function lookupCloseOthers(keep){
      if (!OPEN || !OPEN.lookup) return;
      Object.keys(OPEN.lookup).forEach(function(k){
        if (String(k) === String(keep)) return;
        if (OPEN.lookup[k].open) lookupClose(k);
      });
    }

    function lookupSearch(key){
      var f = lookupSpec(key);
      var s = lookupState(key);
      if (!f || !s || typeof f.search !== 'function') return;
      var q = lkNode('data-nxm-lkq', key);
      var seq = ++s.seq;
      f.search(q ? String(q.value == null ? '' : q.value) : '', function(items, total){
        // Odpoved patri TOMUTO otvoreniu a TOMUTO kolu — inak sa zahadzuje.
        if (!OPEN || !OPEN.lookup || OPEN.lookup[key] !== s) return;
        if (seq !== s.seq) return;
        s.items = items || [];
        s.total = (total == null) ? s.items.length : total;
        s.active = s.items.length ? 0 : -1;
        s.open = true;
        lookupRender(key);
      });
    }

    function lookupMove(key, delta){
      var s = lookupState(key);
      if (!s || !s.open || !s.items.length) return;
      var n = s.items.length;
      s.active = ((s.active < 0 ? 0 : s.active) + delta + n) % n;
      lookupRender(key);
    }

    function lookupPick(key, idx){
      var f = lookupSpec(key);
      var s = lookupState(key);
      if (!f || !s || typeof document === 'undefined') return;
      var it = s.items[Number(idx)];
      if (!it) return;
      var val = document.getElementById('nxm_' + key);
      var q = lkNode('data-nxm-lkq', key);
      var hint = lkNode('data-nxm-lkhint', key);
      if (val) val.value = lookupValueOf(it);
      if (q) q.value = lookupText(f, it);
      if (hint) hint.textContent = lookupHintOf(f, it);
      lookupClose(key);
      if (OPEN) OPEN.memSkip = false;   // vyber je zasah do formulara
      if (q && q.focus){ try { q.focus(); } catch (e) { /* fokus nie je kriticky */ } }
    }

    // Pisanie ZAHADZUJE predchadzajuci vyber (bod 2 kontraktu vyssie).
    function lookupTyped(key){
      if (typeof document === 'undefined') return;
      var val = document.getElementById('nxm_' + key);
      if (val) val.value = '';
      var f = lookupSpec(key);
      var hint = lkNode('data-nxm-lkhint', key);
      if (hint && typeof f === 'object' && f && typeof f.hint === 'function') hint.textContent = '';
      lookupSearch(key);
    }

    // Klavesnica v poli hladania. -> true = udalost je SPRACOVANA (modal ju uz
    // nesmie dostat).
    function lookupKey(ev){
      if (!OPEN || !ev || !ev.target || !ev.target.getAttribute) return false;
      var key = ev.target.getAttribute('data-nxm-lkq');
      if (!key) return false;
      var s = lookupState(key);
      if (ev.key === 'Escape'){
        if (!s || !s.open) return false;  // zatvorena ponuka = Escape patri modalu
        lookupClose(key);
        if (ev.preventDefault) ev.preventDefault();
        return true;
      }
      if (ev.key === 'ArrowDown' || ev.key === 'ArrowUp'){
        if (!s || !s.open) lookupSearch(key);
        else lookupMove(key, ev.key === 'ArrowDown' ? 1 : -1);
        if (ev.preventDefault) ev.preventDefault();
        return true;
      }
      if (ev.key === 'Enter'){
        // Enter v poli hladania NIKDY neodosiela formular — bud vyberie
        // zvyraznenu polozku, alebo (pri zatvorenej ponuke) spusti hladanie.
        if (s && s.open && s.active >= 0) lookupPick(key, s.active);
        else lookupSearch(key);
        if (ev.preventDefault) ev.preventDefault();
        return true;
      }
      return false;
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
             ' aria-label="Odobrať riadok">' + ico('trash') + '</button>';
        // Pas kolizie je POSLEDNY v riadku a zalamuje sa pod neho — hlavicka
        // stlpcov ani sirky buniek sa tym nemenia (vertikalny priestor mini
        // len tam, kde naozaj treba rozhodnut).
        h += confHtml(d, row);
        h += '</div>';
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

    // --- KOLIZIA BUNKY (1b-7) -------------------------------------------------
    // `_conflict` = { stlpec: hodnota, ktora je DNES v katalogu }. Rozdiel proti
    // `_note` je zasadny: `_note` len HLASI, ze sa riadok zmenil, kolizia PYTA
    // ROZHODNUTIE — a kym ho nedostane, `submit` zapis NEPUSTI. Bez toho by
    // pouzivatel ulozil svoju starsiu hodnotu cez cerstvu cenu z katalogu a nikde
    // by to nesvietilo (sweep #8/#9 — cenove P2).
    function hasConf(row, key){
      return !!(row && row._conflict &&
                Object.prototype.hasOwnProperty.call(row._conflict, key));
    }

    // Hodnota bunky do VETY (nie do inputu): boolean je „áno/nie", prazdno je
    // pomlcka — „× v katalógu „"" by pouzivatelovi nepovedalo nic.
    function cellText(c, v){
      if (v === true) return 'áno';
      if (v === false) return 'nie';
      var s = String(v == null ? '' : v);
      return s === '' ? '—' : s;
    }

    function rawVal(v){
      if (v === true) return 'true';
      if (v === false) return 'false';
      return String(v == null ? '' : v);
    }

    function confHtml(f, row){
      var conf = row && row._conflict;
      if (!conf) return '';
      var items = '';
      (f.cols || []).forEach(function(c){
        if (!Object.prototype.hasOwnProperty.call(conf, c.key)) return;
        // POZOR: NIE `data-nxm-col` — `readRows` cita VSETKY uzly s tym
        // atributom v riadku a tlacidlo (s prazdnou `value`) by prepisalo
        // hodnotu bunky na prazdno. Rozhodovacie tlacidlo ma vlastne meno.
        var cat = ' data-nxm-confcol="' + esc(c.key) + '" data-nxm-val="' + esc(rawVal(conf[c.key])) + '"';
        items += '<span class="mrconfitem"><b>' + esc(c.label || c.key) + '</b> ' +
                 'tvoja „' + esc(cellText(c, row[c.key])) + '" × ' +
                 'v katalógu „' + esc(cellText(c, conf[c.key])) + '"' +
                 '<button type="button" class="linkbtn" data-nxm-act="conftake"' + cat +
                 '>Prevziať z katalógu</button>' +
                 '<button type="button" class="linkbtn" data-nxm-act="confkeep"' + cat +
                 '>Ponechať moju</button></span>';
      });
      if (!items) return '';
      return '<div class="mrconf" role="status"><span class="mrconfmsg">' +
             'Zmenené v katalógu, kým si písal — rozhodni, ktorá hodnota platí:</span>' +
             items + '</div>';
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
      // 1b-7: bunka v KOLIZII (pouzivatel ju zmenil a katalog tiez) nesie
      // vlastnu triedu `conf` — NIE `bad`. `bad` patri serverovym chybam
      // a `clearErrors` ho pri kazdom novom kole validacie zmaze; kolizia
      // musi svietit dovtedy, kym ju pouzivatel NEROZHODNE.
      var conf = hasConf(row, d.key);
      var cls = ' class="' + esc(colCls(c) + (conf ? ' conf' : '')) + '"';
      // Bunky nemaju `<label>` (nadpis je nad stlpcom, nie pri poli) — bez
      // `aria-label` by citacka obrazovky hlasila len „textové pole".
      var lbl = ' aria-label="' + esc(d.label || d.key) + '"';
      var locked = !!(d.roWhen && row && row[d.roWhen] != null && row[d.roWhen] !== '');
      // Kolizna bunka MUSI povedat dovod aj citacke obrazovky (review P3-4):
      // farebny okraj je informacia len pre toho, kto ho vidi. `title` aj
      // `aria-invalid` preto idu do KAZDEJ vetvy, nielen do zamknutych.
      var conft = conf ? ' title="Hodnota sa medzitým zmenila v katalógu — rozhodni pod riadkom."' +
                         ' aria-invalid="true"' : '';
      var title = locked && d.roTitle ? ' title="' + esc(d.roTitle) + '"' + (conf ? ' aria-invalid="true"' : '')
                : conft;
      if (locked && d.type === 'checkbox')
        return '<input type="checkbox" data-nxm-col="' + k + '"' + cls + lbl + title +
               ' disabled' + (v === true ? ' checked' : '') + '>';
      if (locked)
        return '<input type="text" data-nxm-col="' + k + '"' + cls + lbl + title +
               ' readonly value="' + esc(v == null ? '' : v) + '">';
      if (d.type === 'select')
        return '<select data-nxm-col="' + k + '"' + cls + lbl + conft + '>' +
               optionsHtml(d.options, v) + '</select>';
      if (d.type === 'checkbox')
        return '<input type="checkbox" data-nxm-col="' + k + '"' + cls + lbl + conft +
               (v === true ? ' checked' : '') + '>';
      return '<input type="text" data-nxm-col="' + k + '"' + cls + lbl + conft +
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
          // KOV-H2: pri `lookup` je `nxm_<key>` SKRYTE pole — cerveny okraj by
          // nebolo vidno. Chyba preto sadne na pole HLADANIA (`_q`), ktore
          // existuje vyhradne pri naseptavaci.
          input = document.getElementById('nxm_' + e.field + '_q') ||
                  document.getElementById('nxm_' + e.field);
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

    // VYCHODISKOVE riadky repeatera — to, proti comu pouzivatel pisal. Volajuci
    // ich potrebuje pri zotaveni z konfliktu, aby vedel odlisit bunku, ktorej sa
    // dotkol, od bunky, ktora len nesie katalogovú hodnotu (1b-7).
    function baseRows(key){
      var b = baseFieldByKey(key);
      return (b && b.value) ? b.value : [];
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
      if (OPEN) OPEN.flags[key] = flagsOfRows(f, f.value);
      renderRows(f, f.value);
    }

    // --- STITKY RIADKOV ZIJU V STAVE, NIE LEN V DOM (1b-7) --------------------
    // `_note` („zmenené mimo editora") a `_conflict` (rozhodnutie o bunke) sa
    // vykresluju z riadku, ale kontajner sa prekresluje z `readRows` — a ten
    // cita LEN bunky. Bez tohto registra by kazde „+ riadok", odobranie riadku
    // alebo rozhodnutie o jednej bunke ZHASLO stitky vsetkych ostatnych: pas
    // kolizie by zmizol a zapis by prebehol bez rozhodnutia.
    // Kluc je HODNOTA `rowKey` (identita zaznamu), nie poradie — katalog radi
    // varianty podla hrubky a poradie sa medzi echami mení.
    // `wrote` = hodnota, PROTI KTOREJ pouzivatel bunku pisal. Nie je to hodnota
    // formulara (tou je jeho vlastna) ani katalogu (tou je `conflict`) — je to
    // baseline optimistickeho zamku pre pamat, a preto zije v stave, nie v
    // riadku (P1 interneho review: v riadku by ju „Začať odznova" nakreslilo).
    function flagsOfRows(f, rows){
      var m = {};
      if (!f || !f.rowKey) return m;
      (rows || []).forEach(function(r){
        if (!r) return;
        var k = r[f.rowKey];
        if (k == null || k === '') return;
        var e = null;
        if (r._note){ e = e || {}; e.note = r._note; }
        if (r._conflict && Object.keys(r._conflict).length){
          e = e || {};
          e.conflict = r._conflict;
          if (r._wrote) e.wrote = r._wrote;
        }
        if (e) m[String(k)] = e;
      });
      return m;
    }

    // `flagsOfRows` sa NIKDY nesmie volať nad výstupom `applyFlags`/`readRows` —
    // `applyFlags` maže `_wrote`, conflict by prežil bez baseline a tichý prepis
    // by sa vrátil.
    function applyFlags(f, rows){
      var st = (OPEN && OPEN.flags && OPEN.flags[f.key]) || null;
      return (rows || []).map(function(r){
        var g = shallow(r);
        delete g._note;
        delete g._conflict;
        delete g._wrote;                 // stav sa do markupu nevykresluje
        var k = f.rowKey ? (r || {})[f.rowKey] : null;
        var e = (st && k != null && k !== '') ? st[String(k)] : null;
        if (e && e.note) g._note = e.note;
        if (e && e.conflict) g._conflict = e.conflict;
        return g;
      });
    }

    // Zosynchronizovanie stitkov s tym, co je NA OBRAZOVKE. Odobranie riadku
    // prekresluje kontajner z `readRows`, takze stitok zmazaneho riadku by
    // v stave ostal visiet — a `submit` by blokoval zapis kvoli „označenej
    // bunke", ktora uz neexistuje (P2 interneho review: slepa ulicka, z ktorej
    // vedie len zatvorenie okna).
    function syncFlags(key){
      if (!OPEN || !OPEN.flags || !OPEN.flags[key]) return;
      var f = fieldByKey(key);
      if (!f || !f.rowKey) return;
      var live = {};
      readRows(key).forEach(function(r){
        var k = r[f.rowKey];
        if (k != null && k !== '') live[String(k)] = true;
      });
      var m = OPEN.flags[key];
      Object.keys(m).forEach(function(rk){ if (!live[rk]) delete m[rk]; });
    }

    // Pocet NEROZHODNUTYCH koliznych buniek. Rata sa VYHRADNE nad riadkami,
    // ktore su naozaj na obrazovke — zamok zapisu nesmie drzat stitok, ktory
    // pouzivatel nema ako rozhodnut.
    function conflictCount(){
      if (!OPEN) return 0;
      var n = 0;
      ((OPEN.spec && OPEN.spec.fields) || []).forEach(function(f){
        if (!f || f.type !== 'rows' || !f.rowKey) return;
        var m = (OPEN.flags && OPEN.flags[f.key]) || null;
        if (!m) return;
        readRows(f.key).forEach(function(r){
          var k = r[f.rowKey];
          if (k == null || k === '') return;
          var e = m[String(k)];
          if (e && e.conflict) n += Object.keys(e.conflict).length;
        });
      });
      return n;
    }

    function renderRows(f, data){
      var box = rowsBox(f.key);
      if (!box) return;
      box.innerHTML = rowsInnerHtml(f, applyFlags(f, data));
    }

    // Rozhodnutie o jednej koliznej bunke. OBE cesty posuvaju VYCHODISKOVU
    // hodnotu na tú, ktorú pouzivatel prave videl — inak by sa tá istá kolizia
    // po zatvoreni a otvoreni vratila donekonecna.
    //   „Prevziať z katalógu" -> do pola ide katalogova hodnota,
    //   „Ponechať moju"       -> pole ostava, ale uz je to VEDOME rozhodnutie.
    function confResolve(btn, take){
      if (!OPEN || typeof document === 'undefined' || !btn || !btn.closest) return;
      var line = btn.closest('[data-nxm-row]');
      if (!line) return;
      var key = line.getAttribute('data-nxm-row');
      var col = btn.getAttribute('data-nxm-confcol');
      var cat = btn.getAttribute('data-nxm-val');
      var f = fieldByKey(key);
      if (!f || !col) return;
      var idNode = f.rowKey && line.querySelector
        ? line.querySelector('[data-nxm-col="' + f.rowKey + '"]') : null;
      var rk = idNode ? String(idNode.value == null ? '' : idNode.value) : '';
      var cell = line.querySelector ? line.querySelector('[data-nxm-col="' + col + '"]') : null;
      var isCheck = !!(cell && cell.getAttribute('type') === 'checkbox');
      var catVal = isCheck ? (cat === 'true') : String(cat == null ? '' : cat);
      if (take && cell){
        if (isCheck) cell.checked = catVal === true;
        else cell.value = catVal;
      }
      // Rozhodnutie ZAHADZUJE stary baseline (`wrote`): odteraz pouzivatel
      // pisal proti hodnote, ktorú prave videl — a tou je cerstva katalogova,
      // teda uz to, co drzi `base`. Do `base` sa preto nic nezapisuje (bola by
      // to tá istá P1 — reset by z neho kreslil starú hodnotu).
      var m = OPEN.flags[key];
      var e = m ? m[rk] : null;
      if (e){
        if (e.conflict){
          delete e.conflict[col];
          if (!Object.keys(e.conflict).length) delete e.conflict;
        }
        if (e.wrote){
          delete e.wrote[col];
          if (!Object.keys(e.wrote).length) delete e.wrote;
        }
        if (!e.note && !e.conflict) delete m[rk];
      }
      OPEN.memSkip = false; // rozhodnutie je zásah do formulara, nie cudzi zapis
      renderRows(f, readRows(key));
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
      // Stitok zmazaneho riadku nesmie prezit v stave — inak by zapis ostal
      // zamknuty kvoli kolizii, ktora na obrazovke uz nie je (P2).
      syncFlags(key);
    }

    // Hodnoty poli -> objekt. Cita sa VZDY z DOM, aby to, co pouzivatel vidi,
    // bolo presne to, co sa odosle. TVAR (audit ŠT-2c #14):
    //   text/select -> RETAZEC (nezmenene — drafty rozpoctu na tom stoja),
    //   checkbox    -> BOOLEAN,
    //   rows        -> POLE HASHOV,
    //   group       -> v hodnotach VOBEC NIE JE (je to nadpis, nie pole).
    //   lookup      -> RETAZEC, a to LEN `value` (kod) zo skryteho pola
    //                  `nxm_<key>` — nikdy text ani cena z obrazovky.
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

    // Porovnanie JEDNEJ bunky. `readRows` vracia pri zaskrtavatku BOOLEAN
    // a inde RETAZEC; vychodiskovy riadok podava volajuci — porovnavat sa musia
    // oba tvary, inak by sa kazda bunka javila ako zmenena.
    function sameCell(a, b){
      if (a === true || a === false || b === true || b === false) return (a === true) === (b === true);
      return String(a == null ? '' : a) === String(b == null ? '' : b);
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
    //
    // A z tych stlpcov uz LEN TIE, KTORE POUZIVATEL NAOZAJ ZMENIL (1b-7, sweep
    // #9). Predtym sa po prvej zmene v ktoromkolvek riadku zapamatala CELA
    // tabulka a pri dalsom otvoreni sa vliala do cerstveho katalogu — cena,
    // ktora medzitym prisla zvonku, tak zmizla bez slova. Ku kazdej zapamatanej
    // bunke ide `_base` = hodnota, proti ktorej ju pouzivatel pisal; podla nej
    // sa neskor pozna KOLIZIA. `_base` sa nikdy nevykresluje ani neodosiela —
    // `readRows` cita vyhradne uzly s `data-nxm-col`.
    //
    // Pri NEROZHODNUTEJ kolizii je „proti comu pisal" STARSIA hodnota nez to,
    // co drzi `base` (v tom uz je cerstvy katalog) — berie sa preto zo stavu
    // (`flags[...].wrote`). Bez toho by jeden Escape koliziu „zahojil".
    function trimRowsValue(f, rows, baseRows, wrote){
      var cols = (f.cols || []).map(function(c){ return c.key; });
      var keyName = f.rowKey;
      var byKey = {};
      if (keyName){
        (baseRows || []).forEach(function(r){
          var k = r && r[keyName];
          if (k != null && k !== '') byKey[String(k)] = r;
        });
      }
      var out = [];
      (rows || []).forEach(function(r){
        var k = keyName ? (r || {})[keyName] : null;
        var isNew = (k == null || k === '');
        var b = isNew ? null : byKey[String(k)];
        // NOVY riadok (bez identity) je cely pouzivatelov — a rovnako riadok,
        // ku ktoremu vychodisko chyba: tam sa dirty urcit NEDA, takze radsej
        // drzime vsetko (strata rozpisu je horsia nez zbytocne vliatie).
        if (isNew || !b){
          var whole = {};
          cols.forEach(function(c){
            if (Object.prototype.hasOwnProperty.call(r, c)) whole[c] = r[c];
          });
          if (keyName && !isNew) whole[keyName] = k;
          out.push(whole);
          return;
        }
        var w = (wrote && wrote[String(k)] && wrote[String(k)].wrote) || null;
        var val = null, bas = null;
        cols.forEach(function(c){
          if (sameCell((r || {})[c], b[c])) return;
          val = val || {};
          bas = bas || {};
          val[c] = r[c];
          bas[c] = (w && Object.prototype.hasOwnProperty.call(w, c)) ? w[c] : b[c];
        });
        if (!val) return;              // riadok bez zmeny sa NEPAMATA vobec
        val[keyName] = k;
        val._base = bas;
        out.push(val);
      });
      return out;
    }

    // Vliatie pamate do CERSTVYCH riadkov: parovanie podla `rowKey`.
    //   riadok, ktory v cerstvom katalogu JE   -> prepisu sa mu LEN ZMENENE bunky,
    //   riadok z pamate BEZ identity            -> je to novy, rozpisany riadok,
    //   riadok z pamate, ktory uz neexistuje    -> ZAHODI sa (zaznam je prec).
    //
    // VYCHODISKOVE riadky (`f.value` = `base`) ostavaju VZDY CERSTVYM KATALOGOM
    // (interne review 1b-7, P1). Skorsia verzia do nich pri kolizii vratila
    // STARU hodnotu, aby kolizia prezila Escape — lenze z `base` kresli aj
    // „Začať odznova", takze reset nakreslil STARU cenu s CERSTVYM `row_rev`
    // a zapis presiel cez oba zamky. „Proti comu pouzivatel pisal" preto zije
    // v STAVE (`_wrote` -> `OPEN.flags[...].wrote`), nie v hodnotach formulara.
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
        var g = shallow(r);
        var conf = null;
        var wrote = null;
        var mb = m._base || {};
        (f.cols || []).forEach(function(c){
          if (!Object.prototype.hasOwnProperty.call(m, c.key)) return;
          g[c.key] = m[c.key];
          if (!Object.prototype.hasOwnProperty.call(mb, c.key)) return;
          if (sameCell(mb[c.key], r[c.key])) return;
          // Zhodny vysledok NIE JE kolizia (review P3-3): pytat sa „tvoja 22,5
          // × v katalogu 22,5" je otazka bez obsahu.
          if (sameCell(m[c.key], r[c.key])) return;
          // Katalog zmenil TU ISTU bunku — pouzivatel musi rozhodnut.
          conf = conf || {};
          conf[c.key] = r[c.key];
          wrote = wrote || {};
          wrote[c.key] = mb[c.key];
        });
        if (conf){ g._conflict = conf; g._wrote = wrote; }
        delete byKey[String(k)];
        return g;
      });
      rows.forEach(function(r){
        var k = r && r[keyName];
        if (k != null && k !== '') return;
        var n = shallow(r);              // rozpisany NOVY riadok
        delete n._base;
        out.push(n);
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
        if (f && f.type === 'rows'){
          var trimmed = trimRowsValue(f, v[k], f.value || [],
                                      (OPEN.flags && OPEN.flags[k]) || null);
          // Prazdny vysledok znamena „ziadna bunka sa nelisi" — pamat by potom
          // len rozsvietila pas „predvyplnené z konceptu" bez jedineho rozpisu.
          if (!trimmed.length) return;
          out[k] = trimmed;
        } else {
          out[k] = v[k];
        }
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
    //
    // Vracia `{ base, spec }`: `base` je VZDY to, co podal volajuci (cerstvy
    // katalog) — kresli sa z neho „Začať odznova" a porovnava sa proti nemu
    // dirty stav. Kolizia sa v nom NEUKLADA (to bola P1 interneho review):
    // „proti comu pouzivatel pisal" nesie stav `OPEN.flags[...].wrote`.
    function withMemory(s){
      dropForeign(s.memoryKey);
      var mem = memory(s.memoryKey);
      if (!mem) return { base: s, spec: s };
      var out = shallow(s);
      out.fromMemory = true;
      out.fields = (s.fields || []).map(function(f){
        if (!f || f.type === 'group') return f;
        if (!Object.prototype.hasOwnProperty.call(mem, f.key)) return f;
        var g = shallow(f);
        // Riadky sa NEPREPISUJU cele — pamat nesie len ZMENENE bunky,
        // identita a odtlacok zaznamu prichadzaju CERSTVE z katalogu
        // (audit 2c-2a #1a + 1b-7).
        g.value = (f.type === 'rows') ? mergeRowsMemory(f, mem[f.key]) : mem[f.key];
        return g;
      });
      return { base: s, spec: out };
    }

    // „Začať odznova" — pas z pamate ponuka CESTU VON: formular sa prekresli
    // z VYCHODISKOVYCH hodnot a pamat zanikne.
    function memReset(){
      if (!OPEN || typeof document === 'undefined') return;
      clearMemory(OPEN.base ? OPEN.base.memoryKey : null);
      // Kresli sa z `base`, ktory je VZDY cerstvy katalog — vratane riadkov,
      // ktore doniesol `setRows` po zotaveni z konfliktu. Snimka z casu
      // otvorenia by vratila stary `row_rev` a dalsie „Uložiť" by skoncilo
      // zase na konflikte (interne review P1).
      OPEN.spec = OPEN.base;
      OPEN.memSkip = true;
      // Vychodiskove hodnoty su cerstvy katalog — niet co rozhodovat.
      OPEN.flags = {};
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
      OPEN = { base: eff.base, spec: eff.spec, trigger: trigger,
               busy: false, memSkip: false, flags: {}, lookup: {} };
      // Stitky (kolizie z pamate) musia zit v STAVE — prekreslenie kontajnera
      // ich z DOM neprecita spat.
      (eff.spec.fields || []).forEach(function(f){
        if (f && f.type === 'rows') OPEN.flags[f.key] = flagsOfRows(f, f.value);
      });
      r.innerHTML = modalHtml(eff.spec);
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
      // 1b-7: NEROZHODNUTA KOLIZIA ZAPIS NEPUSTI. Tichy prepis cerstvej ceny
      // starou hodnotou z formulara je cenova chyba, ktora sa v katalogu
      // realnych objednavok uz nijak neprejavi — tu je jedine miesto, kde sa
      // da zastavit.
      if (conflictCount() > 0){
        showErrors([{ msg: 'Niektoré hodnoty sa medzitým zmenili v katalógu. ' +
                           'Pri každej označenej bunke rozhodni „Prevziať z katalógu" alebo ' +
                           '„Ponechať moju" — až potom sa dá uložiť.' }]);
        return;
      }
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
        // KOV-H2: klik MIMO ponuky naseptavaca ju zatvara (klik do jeho riadku
        // nie — inak by zmizla skor, nez by sa dala vybrat polozka).
        var lkrow = t.closest('[data-nxm-lkrow]');
        lookupCloseOthers(lkrow ? lkrow.getAttribute('data-nxm-lkrow') : null);
        var act = t.closest('[data-nxm-act]');
        if (act){
          var a = act.getAttribute('data-nxm-act');
          if (a === 'submit') submit();
          else if (a === 'lookuppick') lookupPick(act.getAttribute('data-nxm-lk'),
                                                  act.getAttribute('data-nxm-idx'));
          else if (a === 'rowadd') rowAdd(act.getAttribute('data-nxm-rows'));
          else if (a === 'rowdel') rowDel(act);
          else if (a === 'conftake') confResolve(act, true);
          else if (a === 'confkeep') confResolve(act, false);
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
        if (!t.getAttribute('data-nxm') && !t.getAttribute('data-nxm-col') &&
            !t.getAttribute('data-nxm-lkq')) return;
        OPEN.memSkip = false;
      }
      document.addEventListener('change', touched);

      // Vzorka farby ide za textom — pouzivatel musi vidiet, co si prave napisal.
      document.addEventListener('input', function(ev){
        touched(ev);
        if (!OPEN) return;
        var t = ev.target;
        if (!t || !t.getAttribute) return;
        // KOV-H2: pisanie do naseptavaca zahodi predchadzajuci vyber a spusti
        // nove hladanie (bod 2 kontraktu `lookup`).
        var lk = t.getAttribute('data-nxm-lkq');
        if (lk){ lookupTyped(lk); return; }
        if (t.getAttribute('data-nxm-color') !== '1') return;
        var sw = document.getElementById('nxm_' + t.getAttribute('data-nxm') + '_sw');
        if (sw && sw.style) sw.style.background = isHex(t.value) ? String(t.value) : '';
      });

      document.addEventListener('keydown', function(ev){
        if (!OPEN) return;
        // KOV-H2: otvorena ponuka naseptavaca je VLASTNA VRSTVA — Escape,
        // sipky a Enter patria najprv jej (vzor `#mdSgBox`). Az ked ju
        // udalost nespotrebuje, rozhoduje modal.
        if (lookupKey(ev)) return;
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
                rowsHtml: rowsHtml, lookupHtml: lookupHtml, cardCls: cardCls,
                open: open, close: close, submit: submit,
                isOpen: isOpen, isBusy: isBusy, setBusy: setBusy,
                values: values, spec: spec, setRows: setRows,
                showErrors: showErrors, clearErrors: clearErrors,
                memory: memory, clearMemory: clearMemory,
                // 1b-7: volajuci potrebuje vediet, PROTI COMU pouzivatel pisal
                // (zotavenie z konfliktu prelieva len ZMENENE bunky), a ci
                // este ostava nerozhodnuta kolizia.
                baseRows: baseRows, conflicts: conflictCount };
    global.NXModal = API;
    if (typeof module !== 'undefined' && module.exports) module.exports = API;
  })(typeof window !== 'undefined' ? window : globalThis);
