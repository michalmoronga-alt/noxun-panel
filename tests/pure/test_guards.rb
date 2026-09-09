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

# --- duplicitne definicie metod (AST) ----------------------------------------
#
# Ruby druhu definiciu ticho prijme a ta VYHRA — prva (aj konstanty, ktore
# cita) sa stane mrtvym kodom bez jedineho varovania. Presne to sa stalo
# `HardwareSets.incompatible_detail_sk` (fix v0.9.56): `height_selector` sa
# nikdy nepreložil a KOV-F1/E1a dopisovali kazdy detail na DVE miesta.
#
# Scanner ide cez AST (nie regex) a klucuje PLNOU cestou konstanty + menom
# metody, takze:
#   - rovnake mena v ROZNYCH triedach (`initialize`, `to_h`) nie su duplicita,
#   - znovuotvoreny modul (v tom istom aj v INOM subore) duplicitu neschova —
#     `module Noxun::Engine::X` a vnorene `module Noxun; module Engine; module X`
#     su ten isty scope,
#   - `class << self` a `def self.x` zdielaju singleton scope (`X.x`),
#   - `def` v tele metody sa neskenuje (lokalna zvlastnost, nie redefinicia),
#   - `def` v roznych vetvach `if`/`unless`/`case` nie je duplicita (vedoma
#     podmienena definicia, napr. podla verzie Ruby).
# Self-test nizsie drzi presne tieto hranice.
module NxTest
  module DupDefs
    module_function

    BRANCHING = %i[IF UNLESS CASE CASE2 CASE3 WHEN IN].freeze

    # -> seen: { 'Noxun::Engine::X#y' => ['subor:riadok', …] }; duplicita = >1 zaznam
    def scan(ast, file, seen = Hash.new { |h, k| h[k] = [] })
      walk(ast, [], file, seen, nil)
      seen
    end

    def duplicates(seen)
      seen.select { |_, where| where.length > 1 }.map { |key, where| "#{key} (#{where.join(', ')})" }
    end

    def cpath_name(node)
      return '?' unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      # `module M` je (COLON2 nil :M), `module A::B` je (COLON2 (CONST :A) :B),
      # `module ::M` je (COLON3 :M) — bez rodica sa meno neuvadza s `::`, aby
      # vnorene moduly a `Noxun::Engine::X` dali ten isty kluc.
      case node.type
      when :CONST  then node.children[0].to_s
      when :COLON2
        parent = node.children[0]
        parent ? "#{cpath_name(parent)}::#{node.children[1]}" : node.children[1].to_s
      when :COLON3 then node.children[0].to_s
      else '?'
      end
    end

    def walk(node, scope, file, seen, branch)
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      case node.type
      when :MODULE, :CLASS
        walk(node.children.last, scope + [cpath_name(node.children[0])], file, seen, nil)
      when :SCLASS
        walk(node.children.last, scope + ['self'], file, seen, nil)
      when :DEFN
        record(seen, scope, node.children[0].to_s, branch, file, node.first_lineno)
      when :DEFS
        record(seen, scope + ['self'], node.children[1].to_s, branch, file, node.first_lineno)
      when *BRANCHING
        node.children.each_with_index do |ch, i|
          walk(ch, scope, file, seen, "#{branch}#{node.first_lineno}/#{i};")
        end
      else
        node.children.each { |ch| walk(ch, scope, file, seen, branch) }
      end
    end

    def record(seen, scope, name, branch, file, line)
      singleton = scope.last == 'self'
      path = (singleton ? scope[0..-2] : scope).join('::')
      key = "#{path}#{singleton ? '.' : '#'}#{name}"
      key += " [vetva #{branch}]" if branch
      seen[key] << "#{file}:#{line}"
    end
  end
end

NxTest.test('guard: self-test scannera duplicitnych definicii (hranice AST)') do
  NxTest.skip!('RubyVM::AbstractSyntaxTree nie je k dispozicii') unless defined?(RubyVM::AbstractSyntaxTree)

  dups = lambda do |*sources|
    seen = Hash.new { |h, k| h[k] = [] }
    sources.each_with_index { |src, i| NxTest::DupDefs.scan(RubyVM::AbstractSyntaxTree.parse(src), "f#{i}", seen) }
    NxTest::DupDefs.duplicates(seen)
  end
  # A) `class << self` + rovnomenna instancna metoda = dva rozne scope
  NxTest.assert_equal([], dups.call("module M\n  class << self\n    def a; end\n  end\n  def a; end\nend\n"))
  # B) znovuotvoreny modul v tom istom subore = duplicita
  NxTest.assert_equal(['M#b (f0:2, f0:5)'],
                      dups.call("module M\n  def b; end\nend\nmodule M\n  def b; end\nend\n"))
  # B2) …aj v INOM subore, aj cez `Noxun::Engine::X` vs. vnorene moduly
  NxTest.assert_equal(['Noxun::Engine::X#g (f0:2, f1:4)'],
                      dups.call("module Noxun::Engine::X\n  def g; end\nend\n",
                                "module Noxun\n  module Engine\n    module X\n      def g; end\n    end\n  end\nend\n"))
  # C) rovnake meno v roznych triedach nie je duplicita
  NxTest.assert_equal([], dups.call("class A\n  def c; end\nend\nclass B\n  def c; end\nend\n"))
  # D) vedoma podmienena definicia (vetvy `if`) nie je duplicita
  NxTest.assert_equal([], dups.call("module M\n  if RUBY_VERSION > '3'\n    def d; end\n  else\n    def d; end\n  end\nend\n"))
  # E) `def self.e` dvakrat = duplicita; H) `class << self` + `def self.h` = ten isty singleton scope
  NxTest.assert_equal(['M.e (f0:2, f0:3)'], dups.call("module M\n  def self.e; end\n  def self.e; end\nend\n"))
  NxTest.assert_equal(['M.h (f0:3, f0:5)'],
                      dups.call("module M\n  class << self\n    def h; end\n  end\n  def self.h; end\nend\n"))
  # F) `def` v tele metody sa neskenuje
  NxTest.assert_equal([], dups.call("module M\n  def f\n    def g; end\n  end\n  def g; end\nend\n"))
end

NxTest.test('guard: ziadna metoda nie je v tom istom module/triede definovana dvakrat (AST, cely plugin)') do
  NxTest.skip!('RubyVM::AbstractSyntaxTree nie je k dispozicii') unless defined?(RubyVM::AbstractSyntaxTree)

  seen = Hash.new { |h, k| h[k] = [] }
  broken = []
  files = Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')] +
          [File.join(NxTest::ROOT, 'noxun_engine.rb')]
  files.sort.each do |path|
    rel = path.sub("#{NxTest::ROOT}/", '')
    begin
      NxTest::DupDefs.scan(RubyVM::AbstractSyntaxTree.parse_file(path), rel, seen)
    rescue ScriptError => e
      # SyntaxError je ScriptError, nie StandardError — bez rescue by zhodil
      # cely runner namiesto jedneho FAIL.
      broken << "#{rel}: #{e.class}: #{e.message[0, 120]}"
    end
  end
  NxTest.assert(broken.empty?, "subor sa neda parsovat: #{broken.join(' | ')}")
  offenders = NxTest::DupDefs.duplicates(seen)
  NxTest.assert(offenders.empty?,
                "duplicitna definicia metody v jednom scope (druha ticho vyhrava): #{offenders.join(', ')}")
end
