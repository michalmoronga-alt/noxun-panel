# frozen_string_literal: true
# H14a — register sekcii Studia `ui/js/studio_sections.js` (package
# `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H14.md`, R4 parita a R5 guardy a–c, e).
#
# Sekcia Studia sa prihlasuje NA JEDNOM MIESTE: riadkom JS registra
# `NXStudioSections`. Ruby `StudioDialog::SECTIONS` ostava serverovym
# whitelistom (bezpecnostna hranica). Most medzi nimi je NEZAVISLA fixtura
# `tests/fixtures/h14_studio_sections.json` — JS test (`test_h14a_register.js`)
# overi register == fixtura, tento test Ruby stranu == fixtura. Ziadny regex nad
# zdrojom druhej strany.
#
# Guardy proti novemu prihlaseniu „natvrdo":
#   a) v JS pluginu (okrem registra) nie je pole s >= 2 id sekcii ani objekt
#      s >= 3 klucmi = id sekcii; v Ruby ziadne %w[]/pole s >= 2 id okrem SECTIONS,
#   b) kazde literalove id vo volani studioGoSection/openStudio/ssLinkBtn,
#      v data-ssgo, open_section: a ROUTE_SECTIONS je zname,
#   c) parita: SECTIONS = fixtura (aj poradie), fotky Studia = nazvy, ikony
#      v spritu, jedinecne a v inventari UI_DIZAJN §4, kluce `data` v pushi,
#   e) poradie skriptov: register pred studio.js (studio.html) a pred shell.js
#      (panel.html), inde sa nenacitava.
require_relative '../helper' unless defined?(NxTest)
require 'json'
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog') unless defined?(Noxun::Engine::StudioDialog)
end
require_relative 'test_h14_studio_sekcie' unless defined?(NxH14Push)

# Spolocny citac kontraktu sekcii pre Ruby testy (aj starsie sady ST-1a…S1-A2,
# ktore do H14a citali zoznamy regexom zo studio.js / shell.js).
module NxH14Reg
  ROOT = NxTest::ROOT
  FIXTURE = File.join(ROOT, 'tests', 'fixtures', 'h14_studio_sections.json')
  UI = File.join(ROOT, 'noxun_engine', 'ui')
  # Pole/objekt so sekciami smie byt LEN tu (obsah riadka => dovod). Dnes prazdne.
  ALLOW_JS = {}.freeze

  module_function

  def contract
    @contract ||= JSON.parse(File.read(FIXTURE, encoding: 'UTF-8'))
  end

  def rows
    contract['sections']
  end

  def ids
    rows.map { |r| r['id'] }
  end

  def row(id)
    rows.find { |r| r['id'] == id }
  end

  # Id sekcii skupiny navigacie (`job`, `catalogs`, `settings`) v poradi.
  def group_ids(grp)
    rows.select { |r| r['grp'] == grp }.map { |r| r['id'] }
  end

  def src(*parts)
    File.read(File.join(ROOT, *parts), encoding: 'UTF-8')
  end

  # Studio, Inspector aj sekcie Nastaveni filtruju sekcie REGISTROM — ziadne
  # vlastne zrkadlo zoznamu (do H14a tri kopie). Prazdne pole = v poriadku.
  def mirror_problems
    st = src('noxun_engine', 'ui', 'js', 'studio.js')
    sh = src('noxun_engine', 'ui', 'js', 'shell.js')
    ss = src('noxun_engine', 'ui', 'js', 'studio_settings.js')
    out = []
    out << 'studio.js drzi vlastne STUDIO_SECTIONS' if st.include?('STUDIO_SECTIONS')
    unless st.include?("require('./studio_sections.js')") && st.include?('SECREG.has(id)') &&
           st.include?('SECREG.has(ST.open_section)')
      out << 'studio.js nefiltruje navigaciu a deep-link registrom'
    end
    out << 'shell.js drzi vlastne STUDIO_SECTIONS' if sh.include?('STUDIO_SECTIONS')
    out << 'shell.js nefiltruje deep-link registrom' unless sh.include?('SECREG.has(v)')
    out << 'studio_settings.js drzi vlastne SS_SECTIONS' if ss.include?('SS_SECTIONS')
    out << 'studio_settings.js nepyta svoje sekcie registra' unless ss.include?("SS_REG.inModule('studio_settings.js')")
    out
  end

  def alt
    ids.map { |i| Regexp.escape(i) }.join('|')
  end

  def line_of(src, idx)
    src[0, idx].count("\n") + 1
  end

  # Guard a (JS): pole s >= 2 id alebo objekt s >= 3 klucmi = id sekcii.
  def js_list_problems
    out = []
    Dir.glob(File.join(UI, 'js', '*.js')).sort.each do |f|
      next if File.basename(f) == 'studio_sections.js'

      s = File.read(f, encoding: 'UTF-8')
      code = s.gsub(%r{^\s*//.*$}) { |m| ' ' * m.length }
      code.to_enum(:scan, /\[[^\[\]]*\]/m).each do
        m = Regexp.last_match
        hits = m[0].scan(/'(#{alt})'/).flatten.uniq
        next if hits.length < 2

        ln = line_of(code, m.begin(0))
        txt = s.lines[ln - 1].to_s.strip
        out << "#{File.basename(f)}:#{ln} pole #{hits.inspect}" unless ALLOW_JS.key?(txt)
      end
      code.to_enum(:scan, /\{[^{}]*\}/m).each do
        m = Regexp.last_match
        keys = m[0].scan(/(?:^|[\s,{])(#{alt})\s*:/).flatten.uniq
        next if keys.length < 3

        ln = line_of(code, m.begin(0))
        txt = s.lines[ln - 1].to_s.strip
        out << "#{File.basename(f)}:#{ln} objekt #{keys.inspect}" unless ALLOW_JS.key?(txt)
      end
    end
    out
  end

  # Guard a (Ruby): %w[] alebo riadok s >= 2 id sekcii mimo `StudioDialog::SECTIONS`.
  def rb_list_problems
    out = []
    Dir.glob(File.join(ROOT, 'noxun_engine', '**', '*.rb')).sort.each do |f|
      File.readlines(f, encoding: 'UTF-8').each_with_index do |l, i|
        next if l.strip.start_with?('#')
        next if l.include?('SECTIONS = %w[') && f.end_with?('studio_dialog.rb')

        if (m = l.match(/%w\[([^\]]*)\]/)) && (m[1].split & ids).length >= 2
          out << "#{f.sub("#{ROOT}/", '')}:#{i + 1} %w #{(m[1].split & ids).inspect}"
        end
        hits = l.scan(/['"](#{alt})['"]/).flatten.uniq
        out << "#{f.sub("#{ROOT}/", '')}:#{i + 1} #{hits.inspect}" if hits.length >= 2
      end
    end
    out
  end

  # Guard b: literalove id vo volaniach, ktore otvaraju sekciu.
  PATTERNS = [
    /studioGoSection\(\s*'([A-Za-z_]+)'/,
    /openStudio\(\s*'([A-Za-z_]+)'/,
    /ssLinkBtn\([^,()]+,\s*'([A-Za-z_]+)'/,
    /data-ssgo="([A-Za-z_]+)"/,
    /open_section:\s*'([A-Za-z_]+)'/
  ].freeze

  def literal_uses
    out = []
    files = Dir.glob(File.join(UI, 'js', '*.js')) + Dir.glob(File.join(UI, '*.html')) +
            Dir.glob(File.join(ROOT, 'noxun_engine', '**', '*.rb'))
    files.sort.each do |f|
      File.readlines(f, encoding: 'UTF-8').each_with_index do |l, i|
        PATTERNS.each do |re|
          l.scan(re).flatten.each { |id| out << [f.sub("#{ROOT}/", ''), i + 1, id] }
        end
      end
    end
    out
  end

  def script_order(page)
    File.read(File.join(UI, page), encoding: 'UTF-8').scan(%r{<script src="js/([a-z_0-9]+\.js)\?v=[^"]*"></script>}).flatten
  end
end

NxTest.test('H14a R4.1: StudioDialog::SECTIONS = fixtura kontraktu (aj poradie)') do
  NxTest.assert_equal(NxH14Reg.ids, Noxun::Engine::StudioDialog::SECTIONS,
                      'doplň id do StudioDialog::SECTIONS, riadok do NXStudioSections (js/studio_sections.js) ' \
                      'aj do fixtúry tests/fixtures/h14_studio_sections.json — v rovnakom poradí')
  NxTest.assert_equal(14, NxH14Reg.ids.length, 'kontrakt nesie 14 sekcii')
  NxTest.assert_equal(%w[job catalogs settings], NxH14Reg.contract['groups'].map { |g| g['grp'] }, 'skupiny navigacie')
  NxH14Reg.rows.each do |r|
    NxTest.assert(%w[id grp ic t head module data].all? { |k| r[k].is_a?(String) && !r[k].empty? },
                  "riadok #{r['id']} ma povinne kluce")
    NxTest.assert(NxH14Reg.contract['groups'].any? { |g| g['grp'] == r['grp'] }, "skupina riadka #{r['id']} existuje")
    NxTest.assert(File.exist?(File.join(NxH14Reg::UI, 'js', r['module'])), "modul #{r['module']} existuje")
  end
end

NxTest.test('H14a R4.2: fotky Studia = sekcie a popis = „Štúdio · " + nazov z kontraktu') do
  shots = JSON.parse(NxH14Reg.src('scripts', 'ui_foto', 'shots.json'))['shots'].select { |s| s['kind'] == 'studio' }
  NxTest.assert_equal(NxH14Reg.ids.map { |i| "studio_#{i}" }, shots.map { |s| s['id'] }, 'fotka pre kazdu sekciu v poradi')
  NxTest.assert_equal(NxH14Reg.rows.map { |r| "Štúdio · #{r['t']}" }, shots.map { |s| s['label'] },
                      'popis fotky = nazov sekcie v navigacii')
end

NxTest.test('H14a R4.3: ikony navigacie su v spritu, jedinecne a v inventari UI_DIZAJN §4') do
  ics = NxH14Reg.rows.map { |r| r['ic'] }
  NxTest.assert_equal([], ics.select { |i| ics.count(i) > 1 }.uniq,
                      'ziadne dve polozky navigacie s rovnakou ikonou (zbalena navigacia)')
  icons = NxH14Reg.src('noxun_engine', 'ui', 'js', 'icons.js')
  ics.each { |i| NxTest.assert(icons.include?("'#{i}':"), "ikona `#{i}` je v spritu icons.js") }
  doc = NxH14Reg.src('docs', 'UI_DIZAJN.md')
  para = doc[/\*\*Navigácia Štúdia\*\*.*?(?=\n\n)/m].to_s
  NxTest.refute(para.empty?, 'odsek „Navigácia Štúdia" v UI_DIZAJN §4')
  NxH14Reg.rows.each do |r|
    NxTest.assert(para.include?("`#{r['ic']}` (#{r['t']}"), "inventar ikon pozna `#{r['ic']}` (#{r['t']})")
  end
end

NxTest.test('H14a R4.4: kluc `data` kazdej sekcie skutocne sklada StudioDialog.push_state') do
  NxTest.skip!('headless: stub Sketchup') unless NxTest.headless?
  keys = NxH14Push.snapshot['keys']
  NxH14Reg.rows.each do |r|
    NxTest.assert(keys.include?(r['data']), "sekcia #{r['id']}: kluc `#{r['data']}` je v NX.setStudio")
  end
  routes = Noxun::Engine::ProductionCore::ROUTE_SECTIONS
  NxTest.assert(routes.values.all? { |v| Noxun::Engine::StudioDialog::SECTIONS.include?(v) },
                "ROUTE_SECTIONS vedie len do znamych sekcii: #{routes.inspect}")
end

NxTest.test('H14a R5 a: zoznam sekcii zije len v registri (JS) a v StudioDialog::SECTIONS (Ruby)') do
  js = NxH14Reg.js_list_problems
  NxTest.assert(js.empty?, "zoznam/mapa sekcii mimo registra js/studio_sections.js — pridaj riadok do registra: #{js.join(' · ')}")
  rb = NxH14Reg.rb_list_problems
  NxTest.assert(rb.empty?, "zoznam sekcii v Ruby mimo StudioDialog::SECTIONS: #{rb.join(' · ')}")
end

NxTest.test('H14a R5 b: kazde literalove id sekcie vo volaniach a deep-linkoch je zname') do
  uses = NxH14Reg.literal_uses
  NxTest.assert(uses.length >= 20, "volania sa nasli (#{uses.length})")
  bad = uses.reject { |(_f, _l, id)| NxH14Reg.ids.include?(id) }
  NxTest.assert(bad.empty?, "nezname id sekcie: #{bad.map { |a| "#{a[0]}:#{a[1]}=#{a[2]}" }.join(' · ')}")
  # `data-ssgo` dnes literal nema (nastavuje ho `ssLinkBtn`) — vzor ostava pre buduci markup.
  %w[studioGoSection openStudio ssLinkBtn open_section].each do |kind|
    NxTest.assert(uses.any? { |(f, l, _id)| File.readlines(File.join(NxH14Reg::ROOT, f), encoding: 'UTF-8')[l - 1].include?(kind) },
                  "vzor #{kind} nieco nasiel (inak guard nic nestrazi)")
  end
end

NxTest.test('H14a R5 e: register sa nacitava pred studio.js (Studio) a pred shell.js (Inspector), inde nie') do
  st = NxH14Reg.script_order('studio.html')
  NxTest.assert_equal(1, st.count('studio_sections.js'), 'studio.html nacita register prave raz')
  NxTest.assert(st.index('studio_sections.js') > st.index('icons.js'), 'register za icons.js')
  NxTest.assert(st.index('studio_sections.js') < st.index('studio.js'), 'register PRED studio.js')
  NxTest.assert(st.index('studio_sections.js') < st.index('studio_settings.js'), 'register PRED studio_settings.js')
  NxH14Reg.rows.map { |r| r['module'] }.uniq.each do |m|
    NxTest.assert(st.include?(m), "modul sekcie #{m} je v studio.html")
    NxTest.assert(st.index(m) >= st.index('studio.js'), "modul sekcie #{m} je v studio.html za studio.js")
  end
  pn = NxH14Reg.script_order('panel.html')
  NxTest.assert_equal(1, pn.count('studio_sections.js'), 'panel.html nacita register prave raz')
  NxTest.assert(pn.index('studio_sections.js') < pn.index('shell.js'), 'register PRED shell.js')
  others = Dir.glob(File.join(NxH14Reg::UI, '*.html')).reject { |f| %w[studio.html panel.html].include?(File.basename(f)) }
  others.each do |f|
    NxTest.refute(File.read(f, encoding: 'UTF-8').include?('studio_sections.js'), "#{File.basename(f)} register nenacitava")
  end
end
