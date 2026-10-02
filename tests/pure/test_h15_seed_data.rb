# frozen_string_literal: true
# H15 (blok 9 HARDENING, C-03) — GUARD „DATA KOVANIA NIE SU V LOGIKE" (package
# H15, R5). H15a: sety (`core/hardware_sets_seed.rb`); H15b ho rozsiri o katalog
# a taxonomiu (tabulka `SEED_MODULES`).
#
# CO PLATI:
#   a) datovy subor = LEN literaly (AST): deklaracie konstant s retazcom,
#      cislom, nil/true/false, polom, hashom a `%w[]`, `.freeze` bez argumentov
#      a odkaz na konstantu deklarovanu VYSSIE v tom istom subore — ziadne
#      `def`, volanie (`map`), cudzia konstanta (`SKIP_CODE`) ani `A::B`;
#   b) presunute konstanty su v plugine deklarovane PRAVE RAZ — vo svojom
#      seed subore;
#   c) logicky subor nedeklaruje `SEED_*` ani `LEGACY_SEED_*` (okrem allowlistu
#      s dovodom — v H15a prazdny);
#   d) v `main.rb` aj `tests/helper.rb` je seed subor PRAVE RAZ a TESNE PRED
#      svojim logickym suborom; subor existuje;
#   e) seed subor otvara len svoj modul (`Noxun` › `Engine` › modul).
#
# Guardy su CISTE funkcie nad textom — negativne testy nizsie ich spustaju nad
# SYNTETICKYMI zdrojmi (vzor H13): `def` v datach, volanie `map`, odkaz na
# `SKIP_CODE`, novy `SEED_X =` v logike, zle poradie v `main.rb`.
require_relative '../helper' unless defined?(NxTest)

module NxH15Data
  # { logicky subor => [modul, presunute konstanty, allowlist logiky { meno => dovod }] }
  SEED_MODULES = {
    'hardware_sets' => ['HardwareSets',
                        %w[SEED_VERSION SEED_SETS SEED_MAPPING LEGACY_SEED_SHAPES MAPPING_MIGRATIONS
                           MAPPING_ADDITIONS],
                        {}]
  }.freeze

  # Uzly, ktore smie mat datovy subor (Ruby 3.2; 3.3+ pridava INTEGER/FLOAT/STR
  # varianty literalov).
  TOP_NODES = %i[SCOPE BLOCK BEGIN MODULE COLON2 CDECL].freeze
  VALUE_NODES = %i[LIST ZLIST HASH STR LIT INTEGER FLOAT NIL TRUE FALSE CONST CALL].freeze
  WRAPPERS = %w[Noxun Engine].freeze

  module_function

  def ast?
    defined?(RubyVM::AbstractSyntaxTree) ? true : false
  end

  def core(rel)
    File.join(NxTest::ROOT, 'noxun_engine', 'core', "#{rel}.rb")
  end

  def src(path)
    File.read(path, encoding: 'UTF-8')
  end

  # a) + e): -> [deklarovane konstanty v poradi, otvorene moduly, problemy]
  def literal_report(text)
    ast = RubyVM::AbstractSyntaxTree.parse(text)
    declared = []
    modules = []
    probs = []
    walk = lambda do |node, ctx|
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      line = node.first_lineno
      if ctx == :value
        case node.type
        when :CALL
          recv, mid, args = node.children
          probs << "riadok #{line}: volanie `#{mid}`" unless mid == :freeze && args.nil?
          walk.call(recv, :value)
          return
        when :LIT
          v = node.children[0]
          probs << "riadok #{line}: literal #{v.class}" unless [String, Integer, Float].any? { |c| v.is_a?(c) }
        when :CONST
          name = node.children[0]
          probs << "riadok #{line}: odkaz na konstantu `#{name}` mimo tohto suboru" unless declared.include?(name)
        else
          probs << "riadok #{line}: uzol #{node.type}" unless VALUE_NODES.include?(node.type)
        end
        node.children.each { |c| walk.call(c, :value) }
        return
      end

      case node.type
      when :MODULE
        cpath = node.children[0]
        if cpath.is_a?(RubyVM::AbstractSyntaxTree::Node) && cpath.type == :COLON2 && cpath.children[0].nil?
          modules << cpath.children[1].to_s
        else
          probs << "riadok #{line}: modul s kvalifikovanou cestou"
        end
        walk.call(node.children[1], :top)
      when :CDECL
        name, value = node.children
        unless name.is_a?(Symbol)
          probs << "riadok #{line}: kvalifikovana deklaracia konstanty"
          return
        end
        walk.call(value, :value)
        declared << name
      when *TOP_NODES
        node.children.each { |c| walk.call(c, :top) }
      else
        probs << "riadok #{line}: uzol #{node.type} (len deklaracie konstant)"
      end
    end
    walk.call(ast, :top)
    [declared, modules, probs.uniq]
  end

  # b) deklaracie konstanty `mod::name` v plugine (subory, ktore modul otvaraju,
  # + kvalifikovane priradenie odkialkolvek) -> zoznam „subor:riadok".
  def declarations(mod, name)
    Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')].sort.flat_map do |f|
      text = src(f)
      rel = f.sub("#{NxTest::ROOT}/", '')
      hits = []
      text.lines.each_with_index do |l, i|
        code = l.sub(/#.*$/, '')
        hits << "#{rel}:#{i + 1}" if code =~ /\b#{mod}::#{name}\s*=(?![=~>])/
      end
      if text =~ /^\s*module #{mod}\b/ && ast?
        @cdecl_cache ||= {}
        found = (@cdecl_cache[[f, mod]] ||= cdecls(text, mod))
        found.each { |(n, line)| hits << "#{rel}:#{line}" if n == name.to_sym }
      end
      hits
    end
  end

  # CDECL priamo v tele modulu `mod` (nie vo vnorenych triedach/moduloch).
  def cdecls(text, mod)
    out = []
    walk = lambda do |node, inside|
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      case node.type
      when :MODULE, :CLASS
        cpath = node.children[0]
        nm = cpath.is_a?(RubyVM::AbstractSyntaxTree::Node) ? cpath.children.last.to_s : ''
        node.children[1..].each { |c| walk.call(c, nm == mod) } if node.type == :MODULE
        node.children[1..].each { |c| walk.call(c, false) } if node.type == :CLASS
        return
      when :CDECL
        out << [node.children[0], node.first_lineno] if inside && node.children[0].is_a?(Symbol)
      when :DEFN, :DEFS
        return
      end
      node.children.each { |c| walk.call(c, inside) }
    end
    walk.call(RubyVM::AbstractSyntaxTree.parse(text), false)
    out
  end

  # c) `SEED_*` / `LEGACY_SEED_*` deklarovane v logike mimo allowlistu.
  def logic_seed_decls(text, mod, allow = {})
    cdecls(text, mod).map(&:first).map(&:to_s)
                     .select { |n| n =~ /\A(LEGACY_)?SEED_/ }
                     .reject { |n| allow.key?(n) }
  end

  # d) poradie: seed tesne pred logikou, kazdy prave raz.
  def order_problems(parts, pairs)
    pairs.flat_map do |seed, logic|
      si = parts.each_index.select { |i| parts[i] == seed }
      li = parts.each_index.select { |i| parts[i] == logic }
      next ["#{seed}: #{si.length}x (ma byt prave raz)"] unless si.length == 1
      next ["#{logic}: #{li.length}x"] unless li.length == 1
      next ["#{seed} nie je TESNE pred #{logic} (#{si[0]} vs #{li[0]})"] unless si[0] + 1 == li[0]

      []
    end
  end

  def main_parts(text)
    text.scan(/AppLifecycle\.require_part '([^']+)'/).flatten
  end

  def helper_parts(text)
    text.lines.map(&:strip).select { |l| l =~ %r{\A(core|modules|tools|ui)/[\w/]+\z} }
  end

  def pairs(prefix)
    SEED_MODULES.keys.map { |logic| ["#{prefix}#{logic}_seed", "#{prefix}#{logic}"] }
  end
end

# ============================================================================
# a) + e) datovy subor = len literaly, otvara len svoj modul
# ============================================================================

NxH15Data::SEED_MODULES.each do |logic, (mod, moved, _allow)|
  NxTest.test("H15 R5 a/e: #{logic}_seed.rb = LEN literaly a otvara len modul #{mod}") do
    NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
    path = NxH15Data.core("#{logic}_seed")
    NxTest.assert(File.file?(path), "chyba #{path}")
    text = NxH15Data.src(path)
    NxTest.assert(text.start_with?('# frozen_string_literal: true'), 'povinne `# frozen_string_literal: true` (G1)')
    declared, modules, probs = NxH15Data.literal_report(text)
    NxTest.assert(probs.empty?, "#{logic}_seed.rb nie je len data: #{probs.first(5).inspect}")
    NxTest.assert_equal(NxH15Data::WRAPPERS + [mod], modules, 'seed subor otvara Noxun › Engine › svoj modul')
    NxTest.assert_equal(moved.sort, declared.map(&:to_s).sort, 'seed subor deklaruje PRESNE presunute konstanty')
  end
end

# ============================================================================
# b) + c) presunute konstanty prave raz; logika bez SEED_*
# ============================================================================

NxH15Data::SEED_MODULES.each do |logic, (mod, moved, allow)|
  NxTest.test("H15 R5 b: presunute konstanty #{mod} su v plugine deklarovane PRAVE RAZ, v #{logic}_seed.rb") do
    NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
    moved.each do |name|
      hits = NxH15Data.declarations(mod, name)
      NxTest.assert_equal(1, hits.length, "#{mod}::#{name}: #{hits.inspect}")
      NxTest.assert(hits.first.start_with?("noxun_engine/core/#{logic}_seed.rb:"), "#{mod}::#{name}: #{hits.inspect}")
    end
  end

  NxTest.test("H15 R5 c: #{logic}.rb nedeklaruje SEED_* ani LEGACY_SEED_* (allowlist #{allow.keys.inspect})") do
    NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
    allow.each_value { |why| NxTest.refute(why.to_s.strip.empty?, 'vynimka allowlistu bez dovodu') }
    bad = NxH15Data.logic_seed_decls(NxH15Data.src(NxH15Data.core(logic)), mod, allow)
    NxTest.assert(bad.empty?, "#{logic}.rb: seed data patria do #{logic}_seed.rb — #{bad.inspect}")
  end
end

# ============================================================================
# d) poradie nacitania v main.rb a v helperi
# ============================================================================

NxTest.test('H15 R5 d: main.rb aj tests/helper.rb nacitavaju seed PRAVE RAZ a TESNE PRED logikou') do
  main = NxH15Data.src(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'))
  helper = NxH15Data.src(File.join(NxTest::ROOT, 'tests', 'helper.rb'))
  probs = NxH15Data.order_problems(NxH15Data.main_parts(main), NxH15Data.pairs('noxun_engine/core/'))
  NxTest.assert(probs.empty?, "main.rb: #{probs.inspect}")
  probs = NxH15Data.order_problems(NxH15Data.helper_parts(helper), NxH15Data.pairs('core/'))
  NxTest.assert(probs.empty?, "tests/helper.rb: #{probs.inspect}")
  NxH15Data::SEED_MODULES.each_key do |logic|
    NxTest.assert(File.file?(NxH15Data.core("#{logic}_seed")), "chyba subor #{logic}_seed.rb")
  end
end

# ============================================================================
# Negativne testy nad SYNTETICKYMI zdrojmi
# ============================================================================

module NxH15Data
  SYN_OK = <<~RUBY
    # frozen_string_literal: true
    module Noxun
      module Engine
        module HardwareSets
          SEED_VERSION = 8
          SEED_SETS = [{ 'set_id' => 'x', 'qty' => 1, 'min' => 17.0, 'code' => 'none', 'a' => nil }].freeze
          SEED_MAPPING = { 'hinge' => 'x' }.freeze
          CODES = %w[a b].freeze
          ALIAS = CODES
        end
      end
    end
  RUBY

  module_function

  def syn(body)
    SYN_OK.sub("      SEED_VERSION = 8\n", "      SEED_VERSION = 8\n#{body}")
  end
end

NxTest.test('H15 R5 a (negativne): straz chyti def, volanie, cudziu konstantu, A::B, symbol aj druhy modul') do
  NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
  d = NxH15Data
  _decl, mods, ok = d.literal_report(d::SYN_OK)
  NxTest.assert_equal([], ok, 'syntetické OK data = bez nálezu')
  NxTest.assert_equal(%w[Noxun Engine HardwareSets], mods)
  {
    'def' => "      def self.x; 1; end\n",
    'map' => "      ITEMS = SEED_SETS.map { |s| s }.freeze\n",
    'SKIP_CODE' => "      BAND = { 'code' => SKIP_CODE }.freeze\n",
    'A::B' => "      SKIP = HardwareSets::SKIP_CODE\n",
    'symbol' => "      KEY = :hinge\n",
    'interpolacia' => "      NAME = \"x\#{SEED_VERSION}\"\n",
    'odkaz dopredu' => "      EARLY = LATER\n      LATER = 1\n",
    'freeze s argumentom' => "      X = [1].freeze(true)\n"
  }.each do |what, body|
    _d, _m, probs = d.literal_report(d.syn(body))
    NxTest.refute(probs.empty?, "straz musi chytit: #{what}")
  end
  _d, mods2, = d.literal_report(d::SYN_OK.sub('module HardwareSets', "module HardwareSets\n      module Ine; end"))
  NxTest.refute(mods2 == %w[Noxun Engine HardwareSets], 'druhy modul v seed subore sa musi prejavit')
end

NxTest.test('H15 R5 c (negativne): novy SEED_X = v logike zhodi straz; konstanta vo vnorenej triede nie') do
  NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
  logic = <<~RUBY
    module Noxun
      module Engine
        module HardwareSets
          SKIP_CODE = 'none'
          SEED_X = [1].freeze
          LEGACY_SEED_Y = {}.freeze
          class Ine
            SEED_Z = 1
          end
        end
      end
    end
  RUBY
  NxTest.assert_equal(%w[SEED_X LEGACY_SEED_Y], NxH15Data.logic_seed_decls(logic, 'HardwareSets'))
  NxTest.assert_equal(%w[LEGACY_SEED_Y],
                      NxH15Data.logic_seed_decls(logic, 'HardwareSets', 'SEED_X' => 'odvodene pri nacitani'))
end

NxTest.test('H15 R5 d (negativne): seed za logikou, dvakrat alebo chybajuci = nalez') do
  pairs = [%w[core/hardware_sets_seed core/hardware_sets]]
  NxTest.assert_equal([], NxH15Data.order_problems(%w[core/a core/hardware_sets_seed core/hardware_sets], pairs))
  [%w[core/hardware_sets core/hardware_sets_seed],
   %w[core/hardware_sets_seed core/a core/hardware_sets],
   %w[core/hardware_sets_seed core/hardware_sets_seed core/hardware_sets],
   %w[core/hardware_sets]].each do |parts|
    NxTest.assert_equal(1, NxH15Data.order_problems(parts, pairs).length, "musi chytit: #{parts.inspect}")
  end
  main = "      AppLifecycle.require_part 'noxun_engine/core/hardware_sets' # x\n" \
         "      AppLifecycle.require_part 'noxun_engine/core/hardware_sets_seed' # y\n"
  NxTest.refute(NxH15Data.order_problems(NxH15Data.main_parts(main), NxH15Data.pairs('noxun_engine/core/')).empty?,
                'main.rb so seedom ZA logikou musi zhodit straz')
end
