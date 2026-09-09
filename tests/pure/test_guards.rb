# frozen_string_literal: true
# Guard testy nad zdrojakmi (citaju subory ako text — invarianty repa).
require_relative '../helper' unless defined?(NxTest)

NxTest.test('guard: VERSION v loaderi a main.rb su synchronne') do
  main_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'))
  main_version = main_src[/VERSION\s*=\s*'([^']+)'/, 1].to_s
  NxTest.refute(NxTest::LOADER_VERSION.empty?, 'loader VERSION sa nenasla')
  NxTest.assert_equal(NxTest::LOADER_VERSION, main_version,
                      "VERSION drift: loader '#{NxTest::LOADER_VERSION}' vs main.rb '#{main_version}' — bump treba na oboch miestach")
end

NxTest.test('guard: kazdy ?v= cache-bust v ui/*.html sedi s VERSION') do
  # Konvencia od v0.5.0: jednotny suffix = verzia pluginu. Zmena css/js po
  # vydani = bump patch VERSION (loader + main.rb) — tym sa bumpne aj ?v=.
  offenders = []
  Dir[File.join(NxTest::ROOT, 'noxun_engine', 'ui', '*.html')].sort.each do |path|
    File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
      line.scan(/\?v=([0-9A-Za-z.]+)/).each do |(ver)|
        next if ver == NxTest::LOADER_VERSION

        offenders << "#{File.basename(path)}:#{i + 1} (?v=#{ver})"
      end
    end
  end
  NxTest.assert(offenders.empty?,
                "?v= cache-bust nesedi s VERSION '#{NxTest::LOADER_VERSION}': #{offenders.join(', ')}")
end

NxTest.test('guard: MD_CLIENT_SCHEMA v proj_materials.js sedi so SCHEMA_CURRENT') do
  # Klient sekcie Materialy posiela PEVNU konstantu (schema, ktorej rozumie) —
  # server ju porovnava v schema_write_allowed? (client >= server). Pri bumpe
  # SCHEMA_CURRENT bez bumpu JS konstanty by cela sprava katalogu v UI spadla
  # do read-only ("Katalog je v novom formate...") a nic by to nechytilo.
  js = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'proj_materials.js'),
                 encoding: 'UTF-8')
  n = js[/MD_CLIENT_SCHEMA\s*=\s*(\d+)/, 1]
  NxTest.refute(n.nil?, 'MD_CLIENT_SCHEMA sa v proj_materials.js nenasla')
  NxTest.assert_equal(Noxun::Engine::Materials::SCHEMA_CURRENT, n.to_i,
                      "klientska schema (#{n}) nesedi so SCHEMA_CURRENT " \
                      "(#{Noxun::Engine::Materials::SCHEMA_CURRENT}) — pri novom markeri bumpni OBE")
end

NxTest.test('guard: Numeric#mm sa nepouziva mimo units.rb') do
  offenders = []
  Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')].sort.each do |path|
    next if File.basename(path) == 'units.rb'

    File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
      code = line.sub(/#.*$/, '') # komentare ignorujeme
      next unless code =~ /\.mm\b/
      next if code.include?('Units.mm') && code.scan(/\.mm\b/).length == code.scan(/Units\.mm\b/).length

      offenders << "#{File.basename(path)}:#{i + 1}"
    end
  end
  NxTest.assert(offenders.empty?, "Numeric#mm mimo units.rb (mm<->Length prevadza VYHRADNE Units): #{offenders.join(', ')}")
end

NxTest.test('guard: ziadna metoda nie je v tom istom module/triede definovana dvakrat (AST)') do
  # Ruby druhu definiciu ticho prijme a ta VYHRA — prva (aj konstanty, ktore
  # cita) sa stane mrtvym kodom bez jedineho varovania. Presne to sa stalo
  # `HardwareSets.incompatible_detail_sk` (fix v0.9.56): `height_selector` sa
  # nikdy nepreložil a KOV-F1/E1a dopisovali kazdy detail na DVE miesta.
  # Kontrola ide cez AST, nie regex — rovnake mena v ROZNYCH triedach
  # (`initialize`, `to_h`) nie su duplicita; vnoreny module/class = vlastny scope.
  NxTest.skip!('RubyVM::AbstractSyntaxTree nie je k dispozicii') unless defined?(RubyVM::AbstractSyntaxTree)

  offenders = []
  scan = nil
  scan = lambda do |node, file|
    return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

    unless %i[MODULE CLASS SCLASS].include?(node.type)
      node.children.each { |ch| scan.call(ch, file) }
      return
    end
    seen = Hash.new { |h, k| h[k] = [] }
    collect = nil
    collect = lambda do |n|
      return unless n.is_a?(RubyVM::AbstractSyntaxTree::Node)

      case n.type
      when :DEFN then seen[n.children[0].to_s] << n.first_lineno
      when :DEFS then seen["self.#{n.children[1]}"] << n.first_lineno
      when :MODULE, :CLASS, :SCLASS then scan.call(n, file)
      else n.children.each { |ch| collect.call(ch) }
      end
    end
    collect.call(node.children.last)
    seen.each do |name, lines|
      offenders << "#{file}: #{name} (riadky #{lines.join(', ')})" if lines.length > 1
    end
  end

  files = Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')] +
          [File.join(NxTest::ROOT, 'noxun_engine.rb')]
  files.sort.each do |path|
    scan.call(RubyVM::AbstractSyntaxTree.parse_file(path), path.sub("#{NxTest::ROOT}/", ''))
  end
  NxTest.assert(offenders.empty?,
                "duplicitna definicia metody v jednom scope (druha ticho vyhrava): #{offenders.join(', ')}")
end
