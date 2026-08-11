# frozen_string_literal: true
# Guard navigacie dokumentacie (davka U1, 11.8.2026).
# STAV.md je vstupny bod kazdeho sedenia — musi ostat KRATKY a musi mat stabilnu
# kostru, aby agent vedel, kde hladat. PLAN.md drzi bloky prac.
# Guard kontroluje VYHRADNE STRUKTURU (existencia, limit riadkov, povinne nadpisy,
# platnost lokalnych odkazov) — ZNENIE textu nikdy: obsah sa prepisuje pri kazdom
# uzavere davky a test ho nesmie blokovat.
require_relative '../helper' unless defined?(NxTest)

NX_STAV_MAX_LINES = 80
NX_STAV_SECTIONS = ['## Stav', '## Robí sa', '## Ďalší krok',
                    '## Posledné uzávery', '## Kam sa pozrieť'].freeze

NxTest.test('docs: SYSTEM/STAV.md existuje a ma najviac 80 riadkov') do
  path = File.join(NxTest::ROOT, 'SYSTEM', 'STAV.md')
  NxTest.assert(File.exist?(path), 'SYSTEM/STAV.md chyba — je to vstupny bod kazdeho sedenia')
  lines = File.readlines(path, encoding: 'UTF-8').length
  NxTest.assert(lines <= NX_STAV_MAX_LINES,
                "STAV.md ma #{lines} riadkov (limit #{NX_STAV_MAX_LINES}) — presun detaily do PLAN.md alebo archiv/KRONIKA.md")
end

NxTest.test('docs: STAV.md ma vsetkych 5 povinnych sekcii') do
  src = File.read(File.join(NxTest::ROOT, 'SYSTEM', 'STAV.md'), encoding: 'UTF-8')
  headings = src.lines.map(&:rstrip).select { |l| l.start_with?('## ') }
  missing = NX_STAV_SECTIONS.reject { |h| headings.include?(h) }
  NxTest.assert(missing.empty?,
                "STAV.md nema povinne sekcie: #{missing.join(' · ')} (najdene: #{headings.join(' · ')})")
end

NxTest.test('docs: relativne odkazy v STAV.md a PLAN.md ukazuju na existujuce subory') do
  broken = []
  %w[STAV.md PLAN.md].each do |name|
    path = File.join(NxTest::ROOT, 'SYSTEM', name)
    NxTest.assert(File.exist?(path), "SYSTEM/#{name} chyba")
    dir = File.dirname(path)
    File.read(path, encoding: 'UTF-8').scan(/\]\(([^)\s]+)\)/).each do |(target)|
      next if target.start_with?('http://', 'https://', 'mailto:', '#')

      rel = target.split('#').first
      next if rel.nil? || rel.empty?

      full = File.expand_path(rel, dir)
      broken << "#{name} → #{target}" unless File.exist?(full)
    end
  end
  NxTest.assert(broken.empty?, "Rozbite odkazy v navigacii docs: #{broken.join(', ')}")
end
