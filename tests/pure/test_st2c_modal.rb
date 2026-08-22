# frozen_string_literal: true
# ŠT-2c PR 2c-1 — rozsirena zdielana kostra modalov (`ui/js/nx_modal.js`).
#
# Toto su ZDROJOVE guardy kontraktu, nie scenare (tie su v
# tests/js/test_st2c_modal.js). Strazia tri veci, ktore sa daju rozbit jednym
# riadkom a ktorych nasledok vidno az pri ZAPISE dekoru — teda po tom, co uz
# pouzivatel formular vyplnil:
#   1. TVAR `values()`. Ploche polia MUSIA ostat retazcami (drafty rozpoctu na
#      tom stoja), `rows` MUSIA byt pole hashov, nadpis sekcie hodnotu NEMA.
#   2. API pamate (`memoryKey` / `memory` / `clearMemory`) je JEDINY sklad
#      rozpisanych hodnot — volajuci si vlastny drzat nesmie, inak sa kontrakt
#      D-15 „Esc nie je ticha strata" rozpadne na kopie s inym spravanim.
#   3. Prekrytie nasepkavaca nad scrimom sa odvodzuje z JEDNEJ definicie
#      (`--nx-z-suggest` pri `.nxscrim`) — magicke cislo v `panel.css` by pri
#      prvej zmene scrimu poslalo dropdown pod modal.
require_relative '../helper' unless defined?(NxTest)

S2C1_MODAL_JS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'nx_modal.js'),
                          encoding: 'UTF-8')
S2C1_MAT_JS   = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'proj_materials.js'),
                          encoding: 'UTF-8')
S2C1_PANEL_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'),
                           encoding: 'UTF-8')
S2C1_STUDIO_HTML = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'),
                             encoding: 'UTF-8')

NxTest.test('ŠT-2c 2c-1: kostra pozna nove typy poli (group / rows / checkbox / color)') do
  %w[group rows checkbox color].each do |t|
    NxTest.assert(S2C1_MODAL_JS.include?("d.type === '#{t}'"),
                  "typ pola `#{t}` je sucastou kostry, nie kopie u volajuceho")
  end
  NxTest.assert(S2C1_MODAL_JS.include?('function rowsInnerHtml') &&
                S2C1_MODAL_JS.include?('function rowCellHtml'),
                'repeater ma vlastne cisté generatory markupu (prekresluje sa pri kazdom +/−)')
  NxTest.assert(S2C1_MODAL_JS.include?("data-nxm-act=\"rowadd\"") &&
                S2C1_MODAL_JS.include?("data-nxm-act=\"rowdel\""),
                'pridanie aj odobranie riadku ide cez akcie kostry (jeden delegovany listener)')
  NxTest.assert(S2C1_MODAL_JS.include?('<input type="hidden" data-nxm-col='),
                'existujuci riadok nesie SKRYTE id/rev — identita variantu sa neodvodzuje od kodu')
  NxTest.assert(S2C1_MODAL_JS.include?("id=\"nxmr_") &&
                S2C1_MODAL_JS.include?("return document.getElementById('nxmr_' + key);"),
                'kontajner repeatera ma VLASTNY prefix id — kluce sa nezrazia s plochymi polami')
  NxTest.assert(S2C1_MODAL_JS.include?('function warnDupKeys'),
                'a duplicitny kluc v specifikacii sa OHLASI (inak by sa hodnoty ticho prepisali)')
  # D-78: ziadne mrtve tlacidlo. `aria-disabled` ostava v Tab poradi
  # (`focusables` ho NEVYHADZUJE) a klik povie dovod.
  NxTest.assert(S2C1_MODAL_JS.include?("(locked ? ' aria-disabled=\"true\"' : '')"),
                'zamknute „−" je aria-disabled, nie HTML disabled')
  NxTest.refute(S2C1_MODAL_JS.include?("(arr.length <= min ? ' disabled' : '')"),
                'tvrdy `disabled` by tlacidlo vyhodil z klavesnice a mlcal by')
  NxTest.assert(S2C1_MODAL_JS[/function rowDel.*?\n    \}/m].to_s.include?("aria-disabled") &&
                S2C1_MODAL_JS.include?('function rowNote'),
                'klik na zamknute „−" napise DOVOD')
end

NxTest.test('ŠT-2c 2c-1 (audit #5): neznama akcia modal NEZATVARA') do
  NxTest.assert(S2C1_MODAL_JS.include?("else if (a === 'close') close();"),
                'zatvara VYSLOVNE `close`, nie catch-all vetva')
  NxTest.assert(S2C1_MODAL_JS.include?("else warn('neznáma akcia"),
                'neznama akcia je no-op s hlaskou do konzoly — nie tiche zmiznutie formulara')
end

NxTest.test('ŠT-2c 2c-1 (audit #14): TVAR values() je kontrakt') do
  body = S2C1_MODAL_JS[/function values\(\).*?\n    \}/m].to_s
  NxTest.refute(body.empty?, 'funkcia sa nasla')
  NxTest.assert(body.include?("f.type === 'group'") && body.include?('return;'),
                'nadpis sekcie v hodnotach VOBEC nie je')
  NxTest.assert(body.include?("if (f.type === 'rows'){ out[f.key] = readRows(f.key); return; }"),
                '`rows` vracaju POLE HASHOV z DOM (nie drzany stav)')
  NxTest.assert(body.include?("out[f.key] = !!(node && node.checked)"),
                '`checkbox` je BOOLEAN')
  NxTest.assert(body.include?("out[f.key] = node ? String(node.value == null ? '' : node.value) : '';"),
                'ploche polia ostavaju RETAZCAMI — spatna kompatibilita draftov rozpoctu')
end

NxTest.test('ŠT-2c 2c-1 (audit #12): pamat hodnot je v kostre a kluc je mode+ciel') do
  NxTest.assert(S2C1_MODAL_JS.include?('memory: memory, clearMemory: clearMemory'),
                'API pamate je sucastou verejneho rozhrania komponentu')
  NxTest.assert(S2C1_MODAL_JS.include?('function memSlot(key)') &&
                S2C1_MODAL_JS.include?("return parts.length >= 3 ? parts.slice(0, -1).join(':') : String(key);"),
                'konvencia `<okno>:<mode>[:<ciel>]` — `mat:edit:H3303` a `mat:edit:H1180` ' \
                'zdielaju slot, `bud:custom` a `bud:appliance` NIE')
  NxTest.assert(S2C1_MODAL_JS.include?('function dropForeign'),
                'zmena ciela stary rozpis zahadzuje HNED (nie az pri zapise)')
  NxTest.assert(S2C1_MODAL_JS.include?('function defaultsOf') &&
                S2C1_MODAL_JS[/function remember.*?\n    \}/m].to_s.include?('sameValue(v[k], def[k])'),
                'pamataju sa LEN polia odlisne od VYCHODISKOVYCH (predvolba selectu ju nezaklada)')
  NxTest.assert(S2C1_MODAL_JS.include?('OPEN.memSkip = false;'),
                'prve pisanie po „server potvrdil" pamat opat zapina (scenar „ulozil som a pisem dalej")')
  NxTest.assert(S2C1_MODAL_JS.include?('data-nxm-act="memreset"') &&
                S2C1_MODAL_JS.include?('function memReset'),
                'predvyplnenie z pamate je VIDNO a ma cestu von („Začať odznova")')
  NxTest.assert(S2C1_MODAL_JS[/function close\(\).*?\n    \}/m].to_s.include?('remember();'),
                'zatvorenie hodnoty zapamätáva — Esc nesmie byt ticha strata')
  NxTest.assert(S2C1_MODAL_JS[/function submit\(\).*?\n    \}/m].to_s.include?('remember();'),
                'a odoslanie tiez (odmietnuty zapis necha hodnoty na mieste)')
  NxTest.assert(S2C1_MODAL_JS.include?('if (opts && opts.clear === true) clearMemory('),
                'mazanie signalizuje VOLAJUCI — kostra nevie, ci server zapis prijal')
end

NxTest.test('ŠT-2c 2c-1: sirkove varianty karty maju styl pri svojej definicii') do
  NxTest.assert(S2C1_MODAL_JS.include?('function cardCls'), 'sirka je jedno miesto v kostre')
  NxTest.assert(S2C1_MODAL_JS.include?("if (sz === 'small') sz = 'sm';"),
                '`small` je alias `sm` — stare volania sa prepisovat nemusia')
  %w[.nxmcard.sm .nxmcard.wide].each do |cls|
    NxTest.assert(S2C1_STUDIO_HTML.include?("#{cls} { width:"),
                  "sirka `#{cls}` je definovana v studio.html")
  end
end

NxTest.test('ŠT-2c 2c-1 (audit #10/#11): nasepkavac vs D-15 modal') do
  bind = S2C1_MAT_JS[/function mdSgBind.*?\n  \}/m].to_s
  NxTest.refute(bind.empty?, 'bind sa nasiel')
  NxTest.assert(bind.include?("else if (ev.key === 'Escape'){ ev.stopPropagation(); mdSgClose(); }"),
                'Escape nasepkavaca zastavi BUBLANIE na inpute — modal pod nim sa zavriet nesmie')
  NxTest.refute(bind.include?('ev.stopImmediatePropagation()'),
                'a `stopImmediatePropagation` by nepomohol: dokumentovy poslucháč je na INOM uzle')
  NxTest.assert(bind.include?('mdSg.input = inp; mdSg.getList = inp._sgList; mdSg.onPick = inp._sgPick;') &&
                bind[/addEventListener\('input'.*?\}\);/m].to_s.include?('mdSg.input = inp;'),
                'pisanie do pola nasepkavac VZDY obnovi — Escape nesmie pole „vypnut" na celu editaciu')
  NxTest.assert(S2C1_MAT_JS.include?("window.addEventListener('scroll', mdSgClose, true);"),
                'scroll listener je v CAPTURE faze — scroll vnutri karty modalu NEBUBLA')
  NxTest.assert(S2C1_PANEL_CSS.include?('z-index: var(--nx-z-suggest, 80)'),
                'panel.css nema vlastne cislo vrstvy — cita premennu')
  m = S2C1_STUDIO_HTML[/--nx-z-scrim:\s*(\d+);\s*--nx-z-suggest:\s*(\d+);/]
  NxTest.assert(!m.nil?, 'obe vrstvy su definovane na jednom mieste pri `.nxscrim`')
  NxTest.assert(Regexp.last_match(2).to_i > Regexp.last_match(1).to_i,
                'nasepkavac je NAD scrimom (inak by bol viditelny, ale neklikatelny)')
end
