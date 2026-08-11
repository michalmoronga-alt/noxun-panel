# frozen_string_literal: true
# Guard navigacie dokumentacie (davka U1, 11.8.2026; rozsirene davkou U3).
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

NxTest.test('docs: docs/ARCHITEKTURA.md existuje a je jedinym miestom architektury') do
  arch = File.join(NxTest::ROOT, 'docs', 'ARCHITEKTURA.md')
  NxTest.assert(File.exist?(arch),
                'docs/ARCHITEKTURA.md chyba — je to referencna mapa modulov (davka U3)')
  src = File.read(arch, encoding: 'UTF-8')
  %w[Core Modules].each do |sec|
    NxTest.assert(src.include?("### #{sec}"), "docs/ARCHITEKTURA.md nema sekciu ### #{sec}")
  end
end

# CLAUDE.md sa nacitava AUTOMATICKY kazde sedenie — architektura sa don nesmie vratit
# (davka U3 ju presunula do docs/ARCHITEKTURA.md). Guard proti recidive.
NxTest.test('docs: CLAUDE.md neobsahuje nadpis sekcie Architektura') do
  path = File.join(NxTest::ROOT, 'CLAUDE.md')
  NxTest.assert(File.exist?(path), 'CLAUDE.md chyba')
  offenders = File.read(path, encoding: 'UTF-8').lines.map(&:rstrip).select do |l|
    l.start_with?('## ') && l.downcase.include?('architekt')
  end
  NxTest.assert(offenders.empty?,
                "CLAUDE.md ma nadpis architektury (#{offenders.join(' · ')}) — patri do docs/ARCHITEKTURA.md")
end

NxTest.test('docs: CLAUDE.md odkazuje na docs/ARCHITEKTURA.md') do
  src = File.read(File.join(NxTest::ROOT, 'CLAUDE.md'), encoding: 'UTF-8')
  NxTest.assert(src.include?('docs/ARCHITEKTURA.md'),
                'CLAUDE.md neodkazuje na docs/ARCHITEKTURA.md — agent by mapu modulov nenasiel')
end

NxTest.test('docs: relativne odkazy v navigacnych suboroch ukazuju na existujuce subory') do
  broken = []
  %w[CLAUDE.md docs/ARCHITEKTURA.md SYSTEM/STAV.md SYSTEM/PLAN.md SYSTEM/DOGFOODING.md].each do |name|
    path = File.join(NxTest::ROOT, name)
    NxTest.assert(File.exist?(path), "#{name} chyba")
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
