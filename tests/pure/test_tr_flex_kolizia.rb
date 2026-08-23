# frozen_string_literal: true
# GUARD — TABULKOVY RIADOK NESMIE DOSTAT FLEX Z panel.css.
#
# Pripad (hlásenie 23.8.): riadok generiky v sekcii NAKUP KOVANIA Studia sa
# volal `<tr class="hwrow">` — lenze `.hwrow` je v ZDIELANOM panel.css flex
# riadok kovania Inspectora a okna Katalog kovania (`display: flex`). Na `<tr>`
# flex zrusi `table-row` layout: bunky sa stanu flex polozkami a stlpce sa
# ROZIDU s hlavickou tabulky (overene: 2. bunka na x=89 px, jej <th> na 224 px).
# Riadok sa preto premenoval na `tr.hwgen`.
#
# Tento test je POISTKA: ziadna trieda, ktorej panel.css da display flex/grid
# holym selektorom (`.trieda { ... }` — plati pre KAZDY element), sa nesmie
# objavit na `<tr>` v markupe ziadneho okna. Ked sa to stane, treba <tr> dat
# vlastnu triedu (vzor hwgen) alebo selektor v CSS zuzit na `div.trieda`.
require_relative '../helper' unless defined?(NxTest)

TRFLEX_CSS = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'css', 'panel.css'), encoding: 'UTF-8')
                 .gsub(%r{/\*.*?\*/}m, ' ')

# Triedy, ktorym panel.css nastavuje flex/grid HOLYM selektorom `.trieda`
# (bez elementu a bez kontextu) — prave tie chytia aj <tr>.
def trflex_classes
  out = []
  TRFLEX_CSS.scan(/(^|\})\s*([^{}]+?)\s*\{([^{}]*)\}/m) do |_pre, sel, body|
    next unless body.match?(/(?:\A|;)\s*display\s*:\s*(?:inline-)?(?:flex|grid)\b/)

    sel.split(',').map(&:strip).each do |s|
      out << s[1..] if s.match?(/\A\.[A-Za-z0-9_-]+\z/)
    end
  end
  out.uniq
end

# Triedy pouzite na <tr> v markupe okien. Dva vzory generovania:
#   a) suvisly retazec  '<tr class="hwgen" data-i="...'  (aj staticke HTML)
#   b) podmienena trieda '<tr' + (cond ? ' class="hwmiss"' : '')
def trflex_tr_classes(src)
  out = []
  src.scan(/<tr[^>]*?class="([^"]+)"/) { |m| out.concat(m[0].split) }
  src.scan(/<tr'\s*\+\s*\([^;]*?class="([^"]+)"/m) { |m| out.concat(m[0].split) }
  out.uniq
end

NxTest.test('tr-flex: ziadny <tr> nenesie triedu, ktorej panel.css dava flex/grid') do
  flex = trflex_classes
  # Poistka poistky: `.hwrow` flex riadok kovania MUSI v zozname byt — keby
  # parser CSS nic nenasiel, test by mlcky prestal chranit.
  NxTest.assert(flex.include?('hwrow'), "parser vidi flex triedy (naslo: #{flex.length})")

  ui = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
  (Dir[File.join(ui, 'js', '*.js')] + Dir[File.join(ui, '*.html')]).sort.each do |f|
    src = File.read(f, encoding: 'UTF-8')
    zle = trflex_tr_classes(src) & flex
    NxTest.assert_equal([], zle,
                        "#{File.basename(f)}: <tr class=\"#{zle.join(' ')}\"> dostane z panel.css " \
                        'display flex/grid a stlpce sa rozidu s hlavickou — premenuj triedu ' \
                        '(vzor hwgen) alebo zuz selektor v CSS na div.trieda')
  end
end

NxTest.test('tr-flex: riadok generiky Studia je tr.hwgen (klik-select aj afordancia)') do
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js'), encoding: 'UTF-8')
  NxTest.assert(js.include?('<tr class="hwgen" data-i="'), 'markup riadku generiky')
  NxTest.assert(js.include?("t.closest('tr.hwgen')"), 'klik-select hlada TU ISTU triedu')
  html = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio.html'), encoding: 'UTF-8')
  NxTest.assert(html.include?('.bomtab.hwtab tbody tr.hwgen { cursor: pointer; }'),
                'ruka afordancie sedi na novej triede')
end
