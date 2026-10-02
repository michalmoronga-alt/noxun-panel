# frozen_string_literal: true
# H15 (blok 9 HARDENING, C-03) — GUARD „DATA KOVANIA NIE SU V LOGIKE" (package
# H15, R5). H15a: sety (`core/hardware_sets_seed.rb`); H15b: katalog
# (`core/hardware_catalog_seed.rb`) a taxonomia (`core/hardware_taxonomy_seed.rb`)
# — tabulka `SEED_MODULES`.
#
# CO PLATI:
#   a) datovy subor = LEN literaly (AST): deklaracie konstant s retazcom,
#      cislom, nil/true/false, polom, hashom a `%w[]`, `.freeze` bez argumentov
#      a odkaz na konstantu deklarovanu VYSSIE v tom istom subore — ziadne
#      `def`, volanie (`map`), cudzia konstanta (`SKIP_CODE`) ani `A::B`;
#   b) presunute konstanty su v plugine deklarovane PRAVE RAZ — vo svojom
#      seed subore;
#   c) logicky subor nedeklaruje datove mena — `SEED_*`, `LEGACY_SEED_*`,
#      `MAPPING_ADDITIONS*`, `MAPPING_MIGRATIONS*`, `DEFAULT_SETS*`,
#      `DEFAULT_MAPPING*` ani ziadnu z presunutych konstant (okrem allowlistu
#      s dovodom — len katalog: tri odvodeniny a kontrakt porovnania patchu);
#   c2) (§15 A2) allowlist nesmie vratit produktove data do logiky:
#      odvodenina (`SEED_ITEMS`, `SEED_ITEMS_V2`, `SEED_PRODUCT_LINKS`) MUSI
#      odkazovat na svoju seed konstantu, smie odkazovat len na seed konstanty
#      a ine odvodeniny a nesmie obsahovat literal produktu — retazec len meno
#      pola polozky (alebo predvoleny dodavatel / oddelovac s dovodom), cele
#      cislo len ako index `row[n]`, desatinne cislo vobec; kontrakt
#      `SEED_MATCH_FIELDS` = len zoznam mien poli;
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
                        {}],
    'hardware_catalog' => ['HardwareCatalog',
                           %w[SEED_SET_VERSION SEED_ROWS SEED_PRICE_CHECKED_AT SEED_PRICE_CHECKED_AT_V4
                              SEED_INACTIVE SEED_AVENTOS_V4 SEED_PRODUCT_CODES SEED_ROWS_V2 SEED_PATCH_V2_ADD
                              LEGACY_SEED_93240 SEED_PATCH_V3_ADD SEED_PATCH_V4_ADD SEED_PATCH_V5_ADD
                              SEED_PATCH_V5_CLASSIFY],
                           { 'SEED_PRODUCT_LINKS' => 'odvodene pri nacitani zo SEED_ROWS (poznamka a odkaz produktu)',
                             'SEED_ITEMS' => 'odvodene pri nacitani zo SEED_ROWS (zaznamy poloziek)',
                             'SEED_ITEMS_V2' => 'odvodene pri nacitani zo SEED_ROWS_V2 (v2 tvar pre patch v3)',
                             'SEED_MATCH_FIELDS' => 'kontrakt porovnania patchu v3 (mena poli, nie data)' }],
    'hardware_taxonomy' => ['HardwareTaxonomy', %w[SEED_VERSION SEED_MANUFACTURERS SEED_SERIES], {}]
  }.freeze

  # c2) §15 A2: KAZDA vynimka allowlistu je bud odvodenina (+ seed konstanty,
  # z ktorych MUSI vychadzat), alebo kontrakt mien poli. Vynimka, ktora nie
  # je ani jedno, guard zhodi — allowlist sa nesmie stat zadnymi dverami.
  DERIVED = {
    'hardware_catalog' => { 'SEED_PRODUCT_LINKS' => %w[SEED_ROWS SEED_PRODUCT_CODES],
                            'SEED_ITEMS' => %w[SEED_ROWS],
                            'SEED_ITEMS_V2' => %w[SEED_ROWS_V2] }
  }.freeze
  FIELD_CONTRACTS = { 'hardware_catalog' => %w[SEED_MATCH_FIELDS] }.freeze
  # Mena poli zaznamu polozky katalogu (`normalize_item`) — jedine retazce,
  # ktore odvodenina smie mat, okrem `FORMAT_STRINGS` s dovodom.
  FIELD_KEYS = %w[item_code name_sk category unit supplier price_eur_vat notes manufacturer series
                  demos_url product_url price_checked_at active].freeze
  FORMAT_STRINGS = { 'Demos' => 'predvoleny dodavatel riadku s nil v manifeste',
                     ' · ' => 'oddelovac odkazu produktu v poznamke riadku' }.freeze

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

  # c) Datove mena, ktore v logike nemaju co hladat (predrecenzia H15a P3:
  # presunute `MAPPING_*` prefix `SEED_` nemaju). `MAPPING_NONE*` logiky (sentinel
  # mapovania) vzor zamerne nechyti.
  DATA_NAME_RE = /\A(LEGACY_)?SEED_|\AMAPPING_(ADDITIONS|MIGRATIONS)|\ADEFAULT_(SETS|MAPPING)/.freeze

  # c) datove mena (vzor + presunute konstanty) deklarovane v logike mimo allowlistu.
  def logic_seed_decls(text, mod, allow = {}, moved = [])
    names = moved.map(&:to_s)
    cdecls(text, mod).map(&:first).map(&:to_s)
                     .select { |n| n =~ DATA_NAME_RE || names.include?(n) }
                     .reject { |n| allow.key?(n) }
  end

  # c2) Vynimky allowlistu, ktore nie su ani odvodeninou, ani kontraktom mien poli.
  def unclassified(logic, allow)
    allow.keys - DERIVED.fetch(logic, {}).keys - FIELD_CONTRACTS.fetch(logic, [])
  end

  # c2) Hodnota (AST uzol) deklaracie `name` priamo v tele modulu `mod`; nil = chyba.
  def cdecl_value(text, mod, name)
    found = nil
    walk = lambda do |node, inside|
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      case node.type
      when :MODULE, :CLASS
        cpath = node.children[0]
        nm = cpath.is_a?(RubyVM::AbstractSyntaxTree::Node) ? cpath.children.last.to_s : ''
        node.children[1..].each { |c| walk.call(c, node.type == :MODULE && nm == mod) }
        return
      when :CDECL
        found ||= node.children[1] if inside && node.children[0] == name.to_sym
      when :DEFN, :DEFS
        return
      end
      node.children.each { |c| walk.call(c, inside) }
    end
    walk.call(RubyVM::AbstractSyntaxTree.parse(text), false)
    found
  end

  # Retazec literalu (Ruby 3.2 s `frozen_string_literal` = LIT, inak STR); nil = nie je retazec.
  def str_of(node)
    v = node.children[0]
    %i[LIT STR].include?(node.type) && v.is_a?(String) ? v : nil
  end

  # Identita uzla podla pozicie (`children` vracia zakazdym nove objekty).
  def pos(node)
    [node.type, node.first_lineno, node.first_column, node.last_lineno, node.last_column]
  end

  def num_node?(node)
    v = node.children[0]
    %i[INTEGER FLOAT].include?(node.type) || (node.type == :LIT && v.is_a?(Numeric))
  end

  # c2) Odvodenina `name` v logike: -> problemy. `sources` = seed konstanty,
  # na ktore MUSI odkazovat; `seed_names` = co seed subor deklaruje;
  # `derived_names` = ine odvodeniny toho isteho modulu.
  def derived_problems(text, mod, name, sources, seed_names, derived_names)
    value = cdecl_value(text, mod, name)
    return ["#{name}: v logike chyba deklaracia (odvodenina allowlistu)"] if value.nil?

    probs = []
    refs = []
    index_ok = {}
    allowed_strings = FIELD_KEYS + FORMAT_STRINGS.keys
    walk = lambda do |node|
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      line = node.first_lineno
      if node.type == :CALL && node.children[1] == :[] && node.children[2].is_a?(RubyVM::AbstractSyntaxTree::Node)
        args = node.children[2].children.compact
        index_ok[pos(args[0])] = true if args.length == 1 && num_node?(args[0]) && args[0].children[0].is_a?(Integer)
      end
      case node.type
      when :CONST
        cn = node.children[0].to_s
        refs << cn
        unless seed_names.include?(cn) || derived_names.include?(cn)
          probs << "#{name} (riadok #{line}): odkaz na `#{cn}` — odvodenina smie citat len seed konstanty"
        end
      when :COLON2, :COLON3
        probs << "#{name} (riadok #{line}): kvalifikovany odkaz na konstantu"
      when :DSTR, :DSYM, :XSTR, :DXSTR, :DREGX
        probs << "#{name} (riadok #{line}): skladany literal #{node.type}"
      else
        s = str_of(node)
        if s
          probs << "#{name} (riadok #{line}): literal #{s.inspect} (produktove data patria do seedu)" unless allowed_strings.include?(s)
        elsif num_node?(node)
          v = node.children[0]
          unless v.is_a?(Integer) && index_ok[pos(node)]
            probs << "#{name} (riadok #{line}): cislo #{v.inspect} mimo indexu `row[n]` (produktove data patria do seedu)"
          end
        elsif node.type == :LIT
          probs << "#{name} (riadok #{line}): literal #{node.children[0].class}"
        end
      end
      node.children.each { |c| walk.call(c) }
    end
    walk.call(value)
    (sources - refs).each { |src| probs << "#{name}: neodkazuje na seed konstantu `#{src}` — nie je odvodenina" }
    probs.uniq
  end

  # c2) Kontrakt `name` = len zoznam mien poli zaznamu (`%w[]` + `.freeze`).
  def contract_problems(text, mod, name)
    value = cdecl_value(text, mod, name)
    return ["#{name}: v logike chyba deklaracia (kontrakt allowlistu)"] if value.nil?

    probs = []
    walk = lambda do |node|
      return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

      if node.type == :CALL
        probs << "#{name}: volanie `#{node.children[1]}`" unless node.children[1] == :freeze && node.children[2].nil?
      elsif !%i[LIST ZLIST].include?(node.type)
        s = str_of(node)
        probs << "#{name}: #{s ? s.inspect : node.type} nie je meno pola polozky" unless s && FIELD_KEYS.include?(s)
      end
      node.children.each { |c| walk.call(c) }
    end
    walk.call(value)
    probs.uniq
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
# b) + c) presunute konstanty prave raz; logika bez datovych mien
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

  NxTest.test("H15 R5 c: #{logic}.rb nedeklaruje datove mena (SEED_*, MAPPING_ADDITIONS…, presunute; allowlist #{allow.keys.inspect})") do
    NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
    allow.each_value { |why| NxTest.refute(why.to_s.strip.empty?, 'vynimka allowlistu bez dovodu') }
    bad = NxH15Data.logic_seed_decls(NxH15Data.src(NxH15Data.core(logic)), mod, allow, moved)
    NxTest.assert(bad.empty?, "#{logic}.rb: seed data patria do #{logic}_seed.rb — #{bad.inspect}")
  end

  NxTest.test("H15 R5 c2 (§15 A2): allowlist #{logic}.rb = len odvodeniny zo seedu a kontrakt mien poli") do
    NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
    derived = NxH15Data::DERIVED.fetch(logic, {})
    contracts = NxH15Data::FIELD_CONTRACTS.fetch(logic, [])
    NxTest.assert_equal([], NxH15Data.unclassified(logic, allow),
                        'kazda vynimka allowlistu je odvodenina so zdrojom alebo kontrakt mien poli')
    NxTest.assert_equal([], (derived.keys + contracts) - allow.keys, 'DERIVED/FIELD_CONTRACTS mimo allowlistu')
    text = NxH15Data.src(NxH15Data.core(logic))
    seed_names = moved.map(&:to_s)
    probs = derived.flat_map do |name, sources|
      NxH15Data.derived_problems(text, mod, name, sources, seed_names, derived.keys)
    end
    probs += contracts.flat_map { |name| NxH15Data.contract_problems(text, mod, name) }
    NxTest.assert(probs.empty?, "#{logic}.rb: #{probs.first(6).inspect}")
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

NxTest.test('H15 R5 c (negativne): SEED_X, MAPPING_ADDITIONS_V9, DEFAULT_SETS aj presunute meno v logike zhodia straz') do
  NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
  logic = <<~RUBY
    module Noxun
      module Engine
        module HardwareSets
          SKIP_CODE = 'none'
          SEED_X = [1].freeze
          LEGACY_SEED_Y = {}.freeze
          MAPPING_NONE = { '__none__' => true }.freeze
          MAPPING_ADDITIONS_V9 = { 'class:x' => 'y' }.freeze
          MAPPING_MIGRATIONS = {}.freeze
          DEFAULT_SETS = [{ 'set_id' => 'x' }].freeze
          DEFAULT_MAPPING = {}.freeze
          SETS_LIKE_TABLE = [].freeze
          SETS_TABLE = [].freeze
          class Ine
            SEED_Z = 1
          end
        end
      end
    end
  RUBY
  base = %w[SEED_X LEGACY_SEED_Y MAPPING_ADDITIONS_V9 MAPPING_MIGRATIONS DEFAULT_SETS DEFAULT_MAPPING]
  NxTest.assert_equal(base, NxH15Data.logic_seed_decls(logic, 'HardwareSets'),
                      'MAPPING_NONE (sentinel logiky) a SETS_LIKE_TABLE/SETS_TABLE bez datoveho mena vzor nechyti')
  NxTest.assert_equal(base - %w[SEED_X],
                      NxH15Data.logic_seed_decls(logic, 'HardwareSets', 'SEED_X' => 'odvodene pri nacitani'))
  NxTest.assert_equal(base + %w[SETS_TABLE],
                      NxH15Data.logic_seed_decls(logic, 'HardwareSets', {}, %w[SETS_TABLE]),
                      'presunute meno v logike zhodi straz aj bez datoveho prefixu')
end

module NxH15Data
  # Synteticka logika katalogu: odvodeniny v tvare ako v `hardware_catalog.rb`.
  SYN_CAT = <<~RUBY
    # frozen_string_literal: true
    module Noxun
      module Engine
        module HardwareCatalog
          SEED_PRODUCT_LINKS = SEED_ROWS.each_with_object({}) do |row, links|
            next unless SEED_PRODUCT_CODES.include?(row[0])
            links[row[0]] = { 'notes' => row[5], 'product_url' => row[5].split(' · ').last }
          end.freeze
          SEED_ITEMS = SEED_ROWS.map do |code, name, price, sup|
            item = { 'item_code' => code, 'name_sk' => name, 'supplier' => sup || 'Demos' }
            item['price_eur_vat'] = price unless price.nil?
            item['active'] = false if SEED_INACTIVE.include?(code)
            item['product_url'] = SEED_PRODUCT_LINKS[code]['product_url'] if SEED_PRODUCT_LINKS.key?(code)
            item
          end.freeze
          SEED_MATCH_FIELDS = %w[name_sk category unit price_eur_vat notes supplier].freeze
          class Ine
            SEED_X = [{ 'item_code' => '1' }].freeze
          end
        end
      end
    end
  RUBY
  SYN_SEED_NAMES = %w[SEED_ROWS SEED_PRODUCT_CODES SEED_INACTIVE].freeze
  SYN_DERIVED = %w[SEED_PRODUCT_LINKS SEED_ITEMS].freeze

  module_function

  def syn_items(text)
    derived_problems(text, 'HardwareCatalog', 'SEED_ITEMS', %w[SEED_ROWS], SYN_SEED_NAMES, SYN_DERIVED)
  end
end

NxTest.test('H15 R5 c2 (negativne, §15 A2): literal produktu namiesto odvodenia zhodi straz') do
  NxTest.skip!('bez RubyVM::AbstractSyntaxTree') unless NxH15Data.ast?
  d = NxH15Data
  syn = d::SYN_CAT
  NxTest.assert_equal([], d.syn_items(syn), 'syntetická odvodenina = bez nálezu')
  NxTest.assert_equal([], d.derived_problems(syn, 'HardwareCatalog', 'SEED_PRODUCT_LINKS',
                                             %w[SEED_ROWS SEED_PRODUCT_CODES], d::SYN_SEED_NAMES, d::SYN_DERIVED))
  NxTest.assert_equal([], d.contract_problems(syn, 'HardwareCatalog', 'SEED_MATCH_FIELDS'))
  items_re = /^      SEED_ITEMS = SEED_ROWS\.map do .*?^      end\.freeze\n/m
  NxTest.assert(syn.match?(items_re), 'syntetický zdroj má odvodeninu SEED_ITEMS')
  {
    # ekvivalentny literal (pole hashov s kodom a cenou) — golden by sa nezmenil
    'pole hashov s kodom a cenou' =>
      "      SEED_ITEMS = [{ 'item_code' => '104717', 'name_sk' => 'Záves', 'supplier' => 'Demos', " \
      "'price_eur_vat' => 4.18 }].freeze\n",
    'odvodenie + prilepeny literal' =>
      "      SEED_ITEMS = (SEED_ROWS.map { |c| { 'item_code' => c } } + [{ 'item_code' => '999999' }]).freeze\n",
    'cena ako cele cislo' =>
      "      SEED_ITEMS = SEED_ROWS.map { |c| { 'item_code' => c, 'price_eur_vat' => 4 } }.freeze\n",
    'zly zdroj' => "      SEED_ITEMS = SEED_INACTIVE.map { |c| { 'item_code' => c } }.freeze\n",
    'cudzia tabulka v logike' => "      SEED_ITEMS = SEED_ROWS.map { |c| PRICE_TABLE[c] }.freeze\n",
    'kvalifikovany odkaz' => "      SEED_ITEMS = SEED_ROWS.map { |c| HardwareSets::SEED_SETS[c] }.freeze\n",
    'interpolacia' => "      SEED_ITEMS = SEED_ROWS.map { |c| \"x\#{c}\" }.freeze\n"
  }.each do |what, body|
    NxTest.refute(d.syn_items(syn.sub(items_re, body)).empty?, "straz musi chytit: #{what}")
  end
  NxTest.refute(d.syn_items(syn.sub(items_re, '')).empty?, 'chybajuca odvodenina = nalez')
  NxTest.refute(d.contract_problems(syn.sub("price_eur_vat notes supplier].freeze", "price_eur_vat notes 104717].freeze"),
                                    'HardwareCatalog', 'SEED_MATCH_FIELDS').empty?,
                'kontrakt mien poli s kodom produktu = nalez')
  NxTest.refute(d.contract_problems(syn.sub('%w[name_sk category unit price_eur_vat notes supplier].freeze',
                                            "SEED_ROWS.map(&:first).freeze"),
                                    'HardwareCatalog', 'SEED_MATCH_FIELDS').empty?,
                'kontrakt ako odvodenie = nalez')
  # deklaracia vo vnorenej triede (nie v tele modulu) sa za odvodeninu nepocita
  NxTest.assert_equal(nil, d.cdecl_value(d::SYN_CAT, 'HardwareCatalog', 'SEED_X'))
end

NxTest.test('H15 R5 c2 (negativne): vynimka allowlistu bez odvodenia ci kontraktu = nalez') do
  d = NxH15Data
  allow = d::SEED_MODULES['hardware_catalog'][2]
  NxTest.assert_equal([], d.unclassified('hardware_catalog', allow))
  NxTest.assert_equal(['SEED_PRICES'],
                      d.unclassified('hardware_catalog', allow.merge('SEED_PRICES' => 'ceny pre rozpocet')))
  NxTest.assert_equal(['SEED_X'], d.unclassified('hardware_taxonomy', { 'SEED_X' => 'dovod' }))
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
