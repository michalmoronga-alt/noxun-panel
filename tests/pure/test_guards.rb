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
#     su ten isty scope; `module ::M` je koren namespace, nie vnorenie,
#   - `class << self` a `def self.x` zdielaju singleton scope (`X.x`); `class
#     << KONST` / `def KONST.x` je INY scope (`X::self<KONST>.x`),
#   - `module_function` (bez argumentov, s menami aj `module_function def x`)
#     vytvara AJ singleton kopiu (`X.x`), takze neskorsi `def self.x` je
#     duplicita; `private def x` / `public def x` sa skenuje ako holy `def`,
#   - `def` v tele metody sa neskenuje (lokalna zvlastnost, nie redefinicia),
#   - dve definicie vo VZAJOMNE VYLUCNYCH vetvach `if`/`unless`/`case` nie su
#     duplicita (vedoma podmienena definicia, napr. podla verzie Ruby) — aj
#     ked su vo vetvach zabalene do `class << self`; nepodmienena + podmienena,
#     dve v TEJ ISTEJ vetve alebo pod NEZAVISLYMI `if` duplicita SU — druha
#     prvu prekryje.
# Priznane limity: `define_method`/`alias_method` scanner nesleduje; vetvy
# rozlisuje riadkom uzla `if`/`case` (dva nezavisle `if` na JEDNOM riadku
# s definiciami v ROZNYCH vetvach — then vs. else — by sa brali ako vylucne).
# Self-test nizsie drzi presne tieto hranice.
module NxTest
  module DupDefs
    module_function

    BRANCHING = %i[IF UNLESS CASE CASE2 CASE3 WHEN IN].freeze

    # -> seen: { 'Noxun::Engine::X#y' => [['subor:riadok', cesta_vetvenia], …] }
    def scan(ast, file, seen = Hash.new { |h, k| h[k] = [] })
      walk(ast, [], file, seen, [], { mf: false })
      seen
    end

    # Dve definicie su vylucne LEN ked sa ich cesty vetvenia rozidu v tom
    # istom uzle (rovnaky riadok `if`/`when`, ina vetva). Prazdna cesta
    # (nepodmienena) proti hocijakej, alebo ta ista cesta, = duplicita.
    def exclusive?(a, b)
      a.zip(b).any? { |x, y| x && y && x != y && x.split('/')[0] == y.split('/')[0] }
    end

    def duplicates(seen)
      seen.filter_map do |key, entries|
        next if entries.length < 2

        hits = entries.each_index.select do |i|
          entries.each_index.any? { |j| i != j && !exclusive?(entries[i][1], entries[j][1]) }
        end
        next if hits.empty?
        # Singleton kopie z `module_function` su ODVODENE od instancnych `def`:
        # dva `def x` v takom module uz hlasi instancny kluc `M#x` — hlasit aj
        # `M.x` by bol ten isty nalez dvakrat. Odvodena kopia sa hlasi len
        # proti SKUTOCNEJ singleton definicii (`def self.x`, `class << self`).
        next if hits.all? { |i| entries[i][2] }

        "#{key} (#{hits.map { |i| entries[i][0] }.join(', ')})"
      end
    end

    def node?(n)
      n.is_a?(RubyVM::AbstractSyntaxTree::Node)
    end

    def cpath_name(node)
      return '?' unless node?(node)

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

    # `module ::M` / `module ::A::B` = koren namespace bez ohladu na vnorenie.
    def absolute_cpath?(node)
      return false unless node?(node)
      return true if node.type == :COLON3

      node.type == :COLON2 && absolute_cpath?(node.children[0])
    end

    # `class << self` / `def self.x` -> 'self'; `class << KONST` / `def KONST.x`
    # -> 'self<KONST>' (iny objekt = iny scope, nie falosna duplicita).
    def singleton_tag(receiver)
      node?(receiver) && receiver.type == :SELF ? 'self' : "self<#{cpath_name(receiver)}>"
    end

    # Mena symbolov v argumentoch (`module_function :a, :b`).
    def symbols(args)
      out = []
      collect = nil
      collect = lambda do |n|
        return unless node?(n)

        if (n.type == :LIT && n.children[0].is_a?(Symbol)) || n.type == :SYM
          out << n.children[0].to_s
        else
          n.children.each { |c| collect.call(c) }
        end
      end
      collect.call(args)
      out
    end

    def walk(node, scope, file, seen, branch, ctx)
      return unless node?(node)

      case node.type
      when :MODULE, :CLASS
        cpath = node.children[0]
        inner = (absolute_cpath?(cpath) ? [] : scope) + [cpath_name(cpath)]
        walk(node.children.last, inner, file, seen, branch, { mf: false })
      when :SCLASS
        walk(node.children.last, scope + [singleton_tag(node.children[0])], file, seen, branch, { mf: false })
      when :DEFN
        name = node.children[0].to_s
        record(seen, scope, name, branch, file, node.first_lineno)
        record(seen, scope + ['self'], name, branch, file, node.first_lineno, true) if ctx[:mf]
      when :DEFS
        record(seen, scope + [singleton_tag(node.children[0])], node.children[1].to_s, branch, file, node.first_lineno)
      when :VCALL, :FCALL
        if node.children[0] == :module_function
          args = node.type == :FCALL ? node.children[1] : nil
          if args.nil?
            ctx[:mf] = true
          else
            # `module_function :a, :b` — odvodena singleton kopia menovanych
            # metod; `module_function def a … end` — argumentom je sam `def`,
            # ktory sa zaznamena s kopiou (mf plati len pre neho).
            # Symboly sa beru len z PRIAMYCH argumentov — telo `def` v argumente
            # moze volat `x(:sym)` a to nie je meno metody na kopirovanie.
            args.children.each do |ch|
              next if node?(ch) && %i[DEFN DEFS].include?(ch.type)

              symbols(ch).each { |n| record(seen, scope + ['self'], n, branch, file, node.first_lineno, true) }
            end
            args.children.each { |ch| walk(ch, scope, file, seen, branch, { mf: true }) }
          end
        else
          # `private def a … end`, `public def …` — `def` je argument volania
          # a musi sa zaznamenat rovnako ako holy `def`.
          node.children.each { |ch| walk(ch, scope, file, seen, branch, ctx) }
        end
      when *BRANCHING
        node.children.each_with_index do |ch, i|
          walk(ch, scope, file, seen, branch + ["#{node.first_lineno}/#{i}"], ctx)
        end
      else
        node.children.each { |ch| walk(ch, scope, file, seen, branch, ctx) }
      end
    end

    def record(seen, scope, name, branch, file, line, derived = false)
      last = scope.last.to_s
      key = if last == 'self'
              "#{scope[0..-2].join('::')}.#{name}"
            elsif last.start_with?('self<')
              "#{scope.join('::')}.#{name}"
            else
              "#{scope.join('::')}##{name}"
            end
      seen[key] << ["#{file}:#{line}", branch, derived]
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
  # B3) `module ::M` vnutri ineho modulu je KOREN, nie `O::M`
  NxTest.assert_equal(['M#a (f0:2, f0:6)'],
                      dups.call("module M\n  def a; end\nend\nmodule O\n  module ::M\n    def a; end\n  end\nend\n"))
  # C) rovnake meno v roznych triedach nie je duplicita
  NxTest.assert_equal([], dups.call("class A\n  def c; end\nend\nclass B\n  def c; end\nend\n"))
  # D) vedoma podmienena definicia (vylucne vetvy `if` / `case`) nie je duplicita…
  NxTest.assert_equal([], dups.call("module M\n  if RUBY_VERSION > '3'\n    def d; end\n  else\n    def d; end\n  end\nend\n"))
  NxTest.assert_equal([], dups.call("module M\n  case RUBY_VERSION\n  when '3' then def d; end\n  else def d; end\n  end\nend\n"))
  # D1) …ani ked su vetvy zabalene do `class << self`
  NxTest.assert_equal([], dups.call("module M\n  if x\n    class << self\n      def a; end\n    end\n  else\n    class << self\n      def a; end\n    end\n  end\nend\n"))
  # D2) …ale nepodmienena + podmienena JE (druha prekryje prvu) — v oboch poradiach, rovnako dve
  #     v tej istej vetve a dve pod NEZAVISLYMI `if` (obe podmienky mozu platit naraz; Codex #335 P2)
  NxTest.assert_equal(['M#d (f0:2, f0:4)'], dups.call("module M\n  def d; end\n  if x\n    def d; end\n  end\nend\n"))
  NxTest.assert_equal(['M#d (f0:3, f0:5)'], dups.call("module M\n  if x\n    def d; end\n  end\n  def d; end\nend\n"))
  NxTest.assert_equal(['M#d (f0:3, f0:4)'], dups.call("module M\n  if x\n    def d; end\n    def d; end\n  end\nend\n"))
  NxTest.assert_equal(['M#d (f0:3, f0:6)'],
                      dups.call("module M\n  if x\n    def d; end\n  end\n  if y\n    def d; end\n  end\nend\n"))
  # E) `def self.e` dvakrat = duplicita; H) `class << self` + `def self.h` = ten isty singleton scope
  NxTest.assert_equal(['M.e (f0:2, f0:3)'], dups.call("module M\n  def self.e; end\n  def self.e; end\nend\n"))
  NxTest.assert_equal(['M.h (f0:3, f0:5)'],
                      dups.call("module M\n  class << self\n    def h; end\n  end\n  def self.h; end\nend\n"))
  # F) `def` v tele metody sa neskenuje
  NxTest.assert_equal([], dups.call("module M\n  def f\n    def g; end\n  end\n  def g; end\nend\n"))
  # MF) `module_function` vytvara aj singleton kopiu — neskorsi `def self.a` ju prekryje
  NxTest.assert_equal(['M.a (f0:3, f0:4)'],
                      dups.call("module M\n  module_function\n  def a; end\n  def self.a; end\nend\n"))
  NxTest.assert_equal(['M.a (f0:2, f0:4)'],
                      dups.call("module M\n  module_function :a\n  def a; end\n  def self.a; end\nend\n"))
  NxTest.assert_equal([], dups.call("module M\n  module_function\n  def a; end\n  def b; end\nend\n"))
  # MF3) dva `def a` v module_function module = JEDEN nalez (instancny), nie aj odvodeny singleton
  NxTest.assert_equal(['M#a (f0:3, f0:4)'], dups.call("module M\n  module_function\n  def a; end\n  def a; end\nend\n"))
  # MF4) hole `module_function` + neskorsie `module_function :a` tej istej metody = ziadna duplicita
  NxTest.assert_equal([], dups.call("module M\n  module_function\n  def a; end\n  module_function :a\nend\n"))
  # MF5) `module_function def a` = def s odvodenou kopiou -> neskorsi `def self.a` je duplicita
  NxTest.assert_equal(['M.a (f0:2, f0:3)'], dups.call("module M\n  module_function def a; end\n  def self.a; end\nend\n"))
  # MF6) symbol volany v TELE takeho `def` (`x(:b)`) nie je meno metody — ziadna falosna kopia `M.b`
  NxTest.assert_equal([], dups.call("module M\n  module_function def a; x(:b); end\n  def self.b; end\nend\n"))
  # V) `def` ako argument volania (`private def a`) sa skenuje ako holy `def`
  NxTest.assert_equal(['M#a (f0:2, f0:3)'], dups.call("module M\n  private def a; end\n  private def a; end\nend\n"))
  # X) `class << KONST` / `def A.a` je iny scope nez `class << self` / `def B.a` — ziadna falosna duplicita
  NxTest.assert_equal([], dups.call("module M\n  class << K\n    def a; end\n  end\n  class << self\n    def a; end\n  end\nend\n"))
  NxTest.assert_equal([], dups.call("module M\n  def A.a; end\n  def B.a; end\nend\n"))
  NxTest.assert_equal(['M::self<K>.a (f0:3, f0:5)'],
                      dups.call("module M\n  class << K\n    def a; end\n  end\n  def K.a; end\nend\n"))
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
