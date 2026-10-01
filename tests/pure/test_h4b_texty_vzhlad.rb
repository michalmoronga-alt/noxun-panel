# frozen_string_literal: true
# H4b (blok 9 HARDENING) — texty a vzhlad: GUARD nad zdrojmi UI. Polozky
# triedenia HARDENING D-06 · D-07 · D-08 · D-09 (NIE D-cisla DOGFOODING.md).
#
# Co tato sada strazi (a preco to klikanim neoveris):
#   1. ZARGON v UI textoch (D-07) — „ghost", „seed", „legacy", „server",
#      „engine" a VELKE pismena sa do okien vratia ticho, jednym novym retazcom.
#      Kontroluju sa RETAZCE (JS literaly, HTML mimo komentarov), nie komentare
#      — v komentaroch su to legitimne vyvojarske pojmy.
#   2. JEDNO SLOVO = JEDNA AKCIA (D-06): „Obnoviť zálohu" ani „Načítať nanovo"
#      sa nevratia; nudzove vratenie katalogu zije v ponuke „⋯".
#   3. Verzia jednotne malym „v" (about, paticka Inspectora, updater, katalog).
#   4. Ziadny glyf ako obsah mazacieho tlacidla, ziadne HTML `disabled` na
#      „Zapísať vybrané" (UI_DIZAJN §1, vzor D-78).
#   5. Ikony navigacie Studia su JEDINECNE a `sliders-horizontal` je v spritu
#      aj v inventari UI_DIZAJN §4 (D-09).
#   6. Zakladny `select` v panel.css a pevne rozlozenie tabulky Dielce (D-08).
#   7. Ruby zmeny su LEN zobrazovacie texty (popisok tagu, statusy).
require_relative '../helper' unless defined?(NxTest)

module NxH4b
  ROOT = File.join(NxTest::ROOT, 'noxun_engine')

  def self.src(rel)
    File.read(File.join(ROOT, rel), encoding: 'UTF-8')
  end

  # JS: retazcove literaly mimo riadkov, ktore su cele komentarom.
  def self.js_strings(code)
    out = []
    code.each_line do |ln|
      t = ln.strip
      next if t.start_with?('//', '*', '/*')

      ln.scan(/'((?:[^'\\\n]|\\.)*)'/) { |m| out << m[0] }
    end
    out
  end

  # HTML: obsah bez komentarov, <style> a <script> blokov.
  def self.html_text(html)
    html.gsub(/<!--.*?-->/m, '').gsub(%r{<style>.*?</style>}m, '').gsub(%r{<script>.*?</script>}m, '')
  end

  def self.ui_texts
    texts = {}
    Dir[File.join(ROOT, 'ui', 'js', '*.js')].sort.each do |f|
      texts["ui/js/#{File.basename(f)}"] = js_strings(File.read(f, encoding: 'UTF-8')).join("\n")
    end
    Dir[File.join(ROOT, 'ui', '*.html')].sort.each do |f|
      texts["ui/#{File.basename(f)}"] = html_text(File.read(f, encoding: 'UTF-8'))
    end
    tags = src('core/tags.rb')
    texts['core/tags.rb'] = tags.scan(/'((?:[^'\\\n]|\\.)*)'/).flatten.join("\n")
    texts
  end

  JARGON = [
    '(legacy)', ' seed)', '>seed<', '(ghost)', 'ghostu', 'ghost sedí', 'ghost sadne',
    'poradie určuje server', 'počíta ich server', '(počíta server)', 'jeden obsah, dva vstupy',
    'zatiaľ v okne', 'počíta engine', 'voči serveru', 'vyberie server', 'server mazanie',
    'server ich zoradí', 'Server pre túto os', 'dormantný', '= ORANGE', '(ORANGE)',
    'per REŽIM', 'per režim', 'v KONTROLE', 'Obnoviť zálohu', 'Načítať nanovo', 'Obnoviť predmigračnú'
  ].freeze
end

NxTest.test('H4b · D-07: UI texty bez vyvojarskeho zargonu (ghost, seed, legacy, server, engine)') do
  NxH4b.ui_texts.each do |file, text|
    NxH4b::JARGON.each do |phrase|
      NxTest.refute(text.include?(phrase), "#{file}: UI text obsahuje „#{phrase}“")
    end
  end
  # Kontrola, ze extrakcia nieco nasla (inak by guard predstieral pokrytie).
  all = NxH4b.ui_texts
  NxTest.assert(all['ui/js/studio.js'].include?('Zoradené podľa závažnosti.'), 'extrakcia JS retazcov funguje')
  NxTest.assert(all['ui/panel.html'].include?('Zobraziť obrysy zón v modeli'), 'extrakcia HTML funguje')
  NxTest.assert(all['core/tags.rb'].include?('Zóny (obrysy)'), 'popisok tagu zon v raile: „Zóny (obrysy)"')
end

NxTest.test('H4b · D-07: zdoraznenie bez VELKYCH pismen v doteraz kriciacich vetach') do
  shouting = %w[ZAPNUTÁ ZAPNUTÝ PODHODNOTENÁ NEMAŽÚ SAMÉ POSLEDNÁ NEPATRÍ OBOCH ZAMKNUTÁ
                TEJTO ZOBRAZENIE GLOBÁLNE KONKRÉTNEHO REŠTARTUJ NÁVRH NIKDY NEMENIA TENTO VŠETKY]
  NxH4b.ui_texts.each do |file, text|
    shouting.each do |w|
      NxTest.refute(text.match?(/(?<![\p{L}\d_-])#{w}(?![\p{L}\d_-])/), "#{file}: kričí „#{w}“")
    end
  end
  NxTest.refute(NxH4b.ui_texts['ui/js/bridge.js'].include?('ŠTÚDIO'), 'Štúdio sa píše ako meno okna')
  NxTest.refute(NxH4b.ui_texts['ui/panel.html'].include?('ŠTÚDIO'), 'aj v paneli')
end

NxTest.test('H4b · D-07: verzia jednotne malym „v"') do
  { 'ui/js/about.js' => 3, 'ui/js/bridge.js' => 1, 'ui/js/studio_settings.js' => 1,
    'ui/js/hw_catalog.js' => 1 }.each do |rel, min|
    code = NxH4b.src(rel)
    NxTest.refute(code.match?(/'V' \+/), "#{rel}: verzia s velkym „V“")
    NxTest.assert(code.scan(/'v' \+/).size >= min, "#{rel}: verzia s malym „v“ (#{min}×)")
  end
end

NxTest.test('H4b · D-06: „Obnoviť" = bezna obnova, iny vyznam = „Vrátiť…", nudzove vratenie v „⋯"') do
  ss = NxH4b.src('ui/js/studio_settings.js')
  tools = ss[/function ssToolsHtml\(sec, failed(?:, blocked)?\).*?\n  \}/m].to_s
  NxTest.assert(tools.scan('#i-refresh-cw"/></svg> Obnoviť</button>').size == 2,
                'Nastavenia rozpoctu: „Obnoviť" s refresh-cw v oboch vetvach listy')
  NxTest.refute(tools.include?('rotate-ccw'), 'rotate-ccw (vratenie) uz nie je ikonou obnovy')
  ap = NxH4b.src('ui/js/appliances.js')
  NxTest.assert(ap.include?("apIco('rotate-ccw') + ' Vrátiť</button>'"), 'Spotrebice: vyradeny model sa VRACIA')
  NxTest.assert(NxH4b.src('ui/js/hw_sets.js').include?("'Vrátiť na globálne predvoľby'"), 'Sety: vratenie predvolieb')
  NxTest.assert(NxH4b.src('ui/js/hardware.js').include?("' vrátiť</button>'"), 'Inspector kovanie: vratit polozku')
  pm = NxH4b.src('ui/js/proj_materials.js')
  NxTest.refute(pm.include?('id="mdRestoreBtn"'), 'samostatne tlacidlo zalohy v liste zaniklo')
  NxTest.assert(pm.include?('aria-haspopup="menu"') && pm.include?('Vrátiť katalóg pred migráciou…'),
                'nudzova akcia je polozka ponuky „⋯"')
  NxTest.assert(NxH4b.src('ui/js/nx_esc.js').include?("'mdMoreOpen'"), 'ponuka je v Escape retazi ako flyout')
  html = NxH4b.src('ui/studio.html')
  NxTest.assert(html.include?('<div class="nxmodal-title">Vrátiť katalóg pred migráciou</div>'), 'nadpis potvrdenia')
  NxTest.assert(html.include?('onclick="mdRestoreConfirm()">Vrátiť katalóg</button>'), 'potvrdzovacie tlacidlo')
  NxTest.assert(html.include?('onclick="mdRestoreOpen()">Vrátiť katalóg pred migráciou…</button>'),
                'banner nudzoveho rezimu ostava (rovnaky text ako polozka)')
end

NxTest.test('H4b · D-08: mazanie ikonou, ziadne HTML disabled na „Zapísať vybrané"') do
  rules = NxH4b.src('ui/js/rules.js')
  NxTest.refute(rules.include?('>✕</button>') || rules.include?("'(this)\">✕"), 'Pravidla: ziadny glyf ✕ v tlacidle')
  NxTest.assert(rules.scan('rdDelIco()').size >= 3, 'tri mazacie tlacidla Pravidiel nesu ikonu x')
  sets = NxH4b.src('ui/js/hw_sets.js')
  NxTest.refute(sets.match?(/hwsMk\('button',[^)]*'×'\)/), 'Sety: ziadny glyf × ako obsah tlacidla')
  %w[člena dĺžku triedu pásmo].each do |what|
    NxTest.assert(sets.include?("hwsDelBtn('ghostbtn") && sets.include?("'Odobrať #{what}'"),
                  "Sety: mazanie „Odobrať #{what}“ ma aria-label/title")
  end
  html = NxH4b.src('ui/studio.html')
  tag = html[/<button[^>]*id="mddApplyBtn"[^>]*>/].to_s
  NxTest.refute(tag.match?(/\sdisabled[\s>]/), '„Zapísať vybrané" bez HTML disabled')
  NxTest.assert(tag.include?('aria-disabled="true"'), 'nedostupnost cez aria-disabled')
end

NxTest.test('H4b · D-08: zakladny select, kratke hladanie, pevne stlpce Kusovnika') do
  css = NxH4b.src('ui/css/panel.css')
  rule = css[/^  select \{[^}]*\}/m].to_s
  NxTest.assert(!rule.empty?, 'zakladne pravidlo `select` v zdielanom panel.css (obe okna)')
  %w[var(--nx-border-strong) var(--nx-surface) var(--nx-ink) max-width min-width border-radius].each do |d|
    NxTest.assert(rule.include?(d), "select: #{d}")
  end
  NxTest.refute(rule.include?('#'), 'select: ziadny hex (len tokeny)')
  NxTest.refute(css.include?('.legsrow .hwsetsel { max-width: 150px'), 'vyber noh uz nema pevnych 150 px')
  { 'ui/js/proj_materials.js' => 'mdSearch', 'ui/js/hw_catalog.js' => 'hwSearch',
    'ui/js/studio.js' => 'bomSearch', 'ui/js/appliances.js' => 'apQ' }.each do |rel, id|
    code = NxH4b.src(rel)
    tag = code[/id="#{id}"[^>]*>/].to_s + code[/id="#{id}"[^\n]*/].to_s
    NxTest.assert(tag.include?('placeholder="Hľadať…"'), "#{id}: kratky hint „Hľadať…“")
    NxTest.assert(tag.include?('aria-label="Hľadať '), "#{id}: rozsah hladania v aria-label")
  end
  NxTest.assert(NxH4b.src('ui/js/appliances.js').include?('id="apJobQ" placeholder="Hľadať…"'), 'apJobQ: kratky hint')
  st = NxH4b.src('ui/studio.html')
  NxTest.assert(st.include?('.bomtab.parts.fixed { table-layout: fixed; }'), 'tabulka Dielce ma pevne rozlozenie (pri predvolenych stlpcoch)')
  NxTest.assert(st.include?('.bomtab.parts.fixed td { white-space: normal; overflow-wrap: anywhere; }'),
                'textove bunky sa pri pevnom rozlozeni zalamuju — nic sa neoreze')
  NxTest.refute(st.include?('.bomtab.parts { table-layout'), 'predrecenzia P2: pevne rozlozenie NIE bezpodmienecne')
  js = NxH4b.src('ui/js/studio.js')
  NxTest.assert(js.include?("'c-' + c.k") && js.include?("'bomtab parts' + (fixed ? ' fixed' : '')"),
                'partsTable nesie triedu stlpca c-<kluc> a tabulka triedu parts')
end

NxTest.test('H4b · D-09: ikony navigacie jedinecne, sliders-horizontal v spritu aj v inventari') do
  js = NxH4b.src('ui/js/studio.js')
  nav = js[/var NAV = \[.*?\n  \];/m].to_s
  ics = nav.scan(/ic: '([^']+)'/).flatten
  NxTest.assert(ics.size >= 14, "NAV ma vsetky polozky (#{ics.size})")
  NxTest.assert_equal([], ics.select { |i| ics.count(i) > 1 }.uniq, 'ziadne dve polozky navigacie s rovnakou ikonou')
  NxTest.assert(nav.include?("{ id: 'bset',   ic: 'sliders-horizontal'"), 'Nastavenia rozpoctu = posuvniky')
  NxTest.assert(NxH4b.src('ui/js/icons.js').include?("'sliders-horizontal':"), 'symbol je v spritu')
  doc = File.read(File.join(NxTest::ROOT, 'docs', 'UI_DIZAJN.md'), encoding: 'UTF-8')
  sec4 = doc[/^## 4\. Ikony.*?(?=^## 5\.)/m].to_s
  NxTest.assert(sec4.include?('`sliders-horizontal`'), 'inventar UI_DIZAJN §4 pozna sliders-horizontal')
end

# Predrecenzia P3: stavove hlasky z Ruby (status okna, nalezy Kontroly) su tiez
# UI texty. Rozsah = retazce v hovore `set_status(`, `warn_item(`, `err_item(`,
# `ok_item(`, `refresh_and_report(` a v riadkoch s `message_sk` (vratane
# pokracovacich riadkov viacriadkoveho hovoru). Interpolacia `#{...}` sa
# vyhodi (je to kod, nie text); katalogove a logovacie texty sa neskenuju.
module NxH4bRuby
  TRIG = /set_status\(|warn_item\(|err_item\(|ok_item\(|refresh_and_report\(|message_sk/.freeze
  CAPS_OK = %w[ABS UNI VEPO NOXUN XLSX CSV DPH SPOLU MAX DTDL MDF HDF RGB RRGGBB].freeze
  # Codex #438 P2: hlasky predavane cez PREMENNU do `set_status(result, true)` —
  # chybove n-tice `[false, '...']` (napr. `Materials.restore_pre_schema2!`)
  # a priame `status.call('...')` zdielaneho jadra okien.
  TUPLE = /\[false, (?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")|status\.call\((?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")/.freeze

  def self.tuple_strings
    out = []
    Dir[File.join(NxH4b::ROOT, '**', '*.rb')].sort.each do |f|
      File.readlines(f, encoding: 'UTF-8').each_with_index do |ln, i|
        next if ln.strip.start_with?('#')

        ln.scan(TUPLE).each do |m|
          s = m.compact.first.to_s.gsub(/#\{[^}]*\}/, ' ')
          out << ["#{f.sub("#{NxH4b::ROOT}/", '')}:#{i + 1}", s] if s =~ /\p{Ll}/
        end
      end
    end
    out
  end

  def self.status_strings
    out = []
    Dir[File.join(NxH4b::ROOT, '**', '*.rb')].sort.each do |f|
      lines = File.readlines(f, encoding: 'UTF-8')
      lines.each_with_index do |ln, i|
        next if ln.strip.start_with?('#') || ln !~ TRIG

        j = i
        loop do
          l = lines[j].to_s
          break if j > i && l.strip.start_with?('#')

          l.scan(/'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"/).each do |a, b|
            s = (a || b).gsub(/#\{[^}]*\}/, ' ')
            out << ["#{f.sub("#{NxH4b::ROOT}/", '')}:#{j + 1}", s] if s =~ /\p{Ll}/
          end
          break unless l.rstrip.end_with?('\\', ',', '(', '+') && j < i + 5

          j += 1
        end
      end
    end
    out
  end
end

NxTest.test('H4b (predrecenzia P3, Codex #438): stavove hlasky z Ruby bez zargonu a VELKYCH pismen') do
  tuples = NxH4bRuby.tuple_strings
  NxTest.assert(tuples.size > 100, "sken nasiel chybove n-tice a status.call (#{tuples.size})")
  NxTest.assert(tuples.any? { |_w, s| s.include?('Záloha katalógu pred migráciou je poškodená') },
                'sken vidi aj navratove texty restore_pre_schema2!')
  strs = NxH4bRuby.status_strings + tuples
  NxTest.assert(strs.size > 300, "sken nasiel stavove hlasky (#{strs.size})")
  NxTest.assert(strs.any? { |_w, s| s.include?('vkladaná skrinka sadne na túto výšku') }, 'sken vidi aj viacriadkove hovory')
  strs.each do |where, s|
    NxTest.refute(s.match?(/\bghost\w*|\bseed\b|\blegacy\b|\bserver\w*/i), "#{where}: zargon v hlaske „#{s[0, 80]}“")
    NxTest.refute(s.include?('Načítať nanovo'), "#{where}: „Načítať nanovo“ je od H4b „Obnoviť“")
    loud = s.scan(/(?<![\p{L}\d_-])(\p{Lu}{3,})(?![\p{L}\d_-])/).flatten - NxH4bRuby::CAPS_OK
    NxTest.assert(loud.empty?, "#{where}: kričí #{loud.inspect} v „#{s[0, 80]}“")
  end
  NxTest.refute(NxH4b.src('core/supplier_settings.rb').include?('Načítať nanovo'),
                'veta nečitateľného súboru nastavení radí „Obnoviť“')
end

NxTest.test('H4b: Ruby zmeny su LEN zobrazovacie texty') do
  NxTest.assert(NxH4b.src('core/tags.rb').include?("'label' => 'Zóny (obrysy)'"), 'popisok tagu')
  NxTest.assert(NxH4b.src('core/tags.rb').include?("'key' => 'zony'"), 'KLUC tagu sa nemeni (identita v modeli)')
  ac = NxH4b.src('ui/panel/actions_cabinet.rb')
  NxTest.assert(ac.include?('mm — vkladaná skrinka sadne na túto výšku.'), 'status zamku vysky')
  NxTest.refute(ac.match?(/set_status\([^)]*ghost/), 'ziadny status s „ghost"')
  NxTest.assert(NxH4b.src('ui/materials_dialog.rb').include?('Katalóg vrátený do stavu pred migráciou.'),
                'status po vrateni katalogu')
  NxTest.assert(NxH4b.src('ui/appliance_dialog.rb').include?("rec['seed'] == true ? 'z pluginu' : 'ručný'"),
                'podtitul stromu spotrebicov bez „seed" (kluc `seed` v datach ostava)')
end

# Codex #438 P2: stavova hlaska po prepnuti „Smer otvárania" ide cestou
# `do_direction_check` -> `status.call(direction_check_status(state))` do
# zdielaneho jadra okien — tiez bez „legacy". Prepinac v modeli sa tu nespusta:
# Overlay API, identita kliku a toggle su na cas testu nahradene.
def h4b_with_stub(obj, name, impl)
  had = obj.respond_to?(name)
  orig = had ? obj.method(name) : nil
  obj.define_singleton_method(name, &impl)
  yield
ensure
  if had
    obj.define_singleton_method(name, orig)
  else
    obj.singleton_class.send(:remove_method, name)
  end
end

NxTest.test('H4b (Codex #438): hlaska Smeru otvarania cez status.call bez „legacy"') do
  NxTest.skip!('zdielane jadro okien je len v headless sade') unless NxTest.headless?
  unless defined?(Noxun::Engine::ProductionCore)
    require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  end
  e = Noxun::Engine
  pc = e::ProductionCore
  got = []
  h4b_with_stub(e::DirectionCheck, :available?, ->(*_a) { true }) do
    h4b_with_stub(pc, :identity_guard, ->(*_a, **_k) { true }) do
      h4b_with_stub(e, :toggle_direction_check,
                    ->(*_a) { { 'active' => true, 'wings' => 4, 'unknown' => 1, 'legacy' => 2 } }) do
        pc.do_direction_check(nil, {}, generation: 1, status: ->(msg, _err = false) { got << msg },
                                       repush: -> {}, direction_echo: -> {})
      end
    end
  end
  NxTest.assert_equal(1, got.size, "jedna stavova hlaska: #{got.inspect}")
  NxTest.assert(got.first.to_s.include?('2 bez smeru (staršie čelá)'), got.first.to_s)
  NxTest.refute(got.first.to_s.include?('legacy'), got.first.to_s)
end
