# frozen_string_literal: true
# Noxun Engine — H16 (C-04, priprava D-48): SUPIS KNIZNIC A ULOZISK MIMO MODELU.
# Autorita supisu = `Noxun::Engine::LibraryRegistry` (`core/library_registry.rb`),
# zrkadlo pre ludi = `docs/architecture/kniznice.md`.
#
#   T0  golden prveho behu — bezec `tests/h16_first_use.rb` v SAMOSTATNOM procese
#       (cerstvy sandbox + pamat modulov; package §15 A5), DVA behy = opakovatelnost;
#       fixtura `tests/fixtures/h16_golden/first_use.json` vznikla na kode PRED
#       zasahom a v davke sa NEREGENERUJE (rozdiel = nalez)
#   T1  tvar registra (kluce, mnoziny, zamok <-> rezim, prilohy, verzie, zmrazenie, API)
#   T2  parita ciest pod `Materials.test_dir_override` (v bezci); T11 bez override
#   T2b zamok DRZANY pri zapise kazdeho suboru prveho behu = `lock` riadku
#   T3  jediny koren — ziadna metoda `*dir` si nepocita %APPDATA% sama
#   T4  kazdy literal mena uloziska v plugine je v supise
#   T5  kazdy subor so zapisom je v supise a naopak; T5b pocet zapisovych miest
#   T6  ziadny neznamy subor po prvom behu; T6b triedenie mien (finalne / docasne)
#   T7  verzie <-> STANDARD §13.1 „Subory na pocitaci" (bijekcia)
#   T8  `kniznice.md` <-> register
#   T9  pamat okien (localStorage) a zakaz inej perzistencie v JS/HTML
#   T10 zdielana mnozina pripnuta (zmena = rozhodnutie Michala)
# Kazdy guard je cista funkcia nad textom/datami a ma negativ nad syntetickym zdrojom.
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'rbconfig'

module NxH16
  E = Noxun::Engine
  R = Noxun::Engine::LibraryRegistry
  RUNNER = File.join(NxTest::ROOT, 'tests', 'h16_first_use.rb')
  GOLDEN = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h16_golden', 'first_use.json')
  DOC = File.join('docs', 'architecture', 'kniznice.md')
  STANDARD = File.join('SYSTEM', 'STANDARD.md')

  # Zdielana mnozina — zmena = rozhodnutie Michala (D-48), nie implementatora.
  SHARED = %w[materials appearances abs_rules hardware_rules hardware_catalog hardware_taxonomy hardware_sets
              templates template_previews supplier_settings appliances appliance_files].freeze

  # Resolver, ktory headless nie je k dispozicii (zije v `main.rb`) — kontroluje sa staticky.
  STATIC_RESOLVERS = %w[Engine.ui_theme_path].freeze

  NAME_RE = /\A[\w.\-]+\.(?:json|lock|done|skm|png|jpe?g|lease|bak|tmp|staging)\z/.freeze
  STR_RE = /'([^'\\]{1,80})'|"([^"\\#]{1,80})"/.freeze
  DIR_CONST_RE = /\b(?:DIR_NAME|ATTACH_ROOT|TMP_NAME|LEASES_DIR)\s*=\s*['"]([^'"]+)['"]/.freeze
  JOIN_RE = /File\.join\(\s*(?:dir|Materials\.dir|TemplateStore\.dir)\s*,\s*['"]([\w.\-]+)['"]/.freeze
  STAMP_RE = /timestamped_free_path\(\s*['"]([^'"]+)['"]/.freeze
  # Zapisove PRIMITIVA Ruby: zapis, vytvorenie, presun, kopia, mazanie suboru ci priecinka.
  WRITE_PRIM = /JsonFileStore\.write\(|\b(?:File|IO)\.(?:binwrite|write|rename|delete|unlink|copy_stream)\(|\bFile\.(?:open|new)\([^)]*(?:'[wa]|"[wa]|File::CREAT)|\bDir\.mkdir\(|\bFileUtils\.(?:mkdir_p|mkdir|cp|cp_r|mv|move|rm|rm_f|rm_r|rm_rf|copy|copy_file|touch|remove_entry|remove_entry_secure|remove_file|remove_dir|ln_s|install)\b|\.save_as\(|write_image\(|write_thumbnail\(/.freeze
  # Zapisovi POMOCNICI pluginu, ktori dostanu CIELOVU CESTU v parametri — ich volanie je
  # zapisove miesto v subore volania (novy cielovy priecinok cez existujuceho pomocnika
  # zmeni pocet). Novy taky pomocnik = doplnit sem (test overi, ze kazdy je v plugine definovany).
  WRITE_HELPERS = %w[deploy_bytes stage_attachment discard_file stage_then_rename write_temp copy_file! try_rename
                     rm_quiet write_book].freeze
  HELPER_RE = /(?:\A|[^\w.]|\b[A-Z]\w*\.)(?:#{WRITE_HELPERS.map { |h| Regexp.escape(h) }.join('|')})\(/.freeze
  WRITE_RE = Regexp.union(WRITE_PRIM, HELPER_RE).freeze
  FNM = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH

  # R6.2b (§15 A1): POCET riadkov so zapisovym primitivom alebo volanim znameho
  # zapisoveho pomocnika (WRITE_HELPERS) v kazdom Ruby subore pluginu a CO tie
  # zapisy pisu. Nie je to parser — refaktor, ktory pocet zachova, test nehybe;
  # nove miesto zapisu (aj dynamicke meno v uz znamom subore alebo novy ciel cez
  # znameho pomocnika) pocet zmeni a test ho zastavi. Novy pomocnik s cestou
  # v parametri sa doplni do WRITE_HELPERS.
  WRITE_SITES = {
    'noxun_engine.rb' => [28, 'instalacia: recovery aktualizacie v Plugins (lease, zamok, swap stromu, rm_quiet)'],
    'noxun_engine/main.rb' => [1, 'ui_theme.json'],
    'noxun_engine/core/abs_rules.rb' => [1, 'abs_rules.json'],
    'noxun_engine/core/appliance_catalog.rb' => [14, 'appliances.json, zamok, prilohy appliances/ a ich staging (stage_attachment, discard_file)'],
    'noxun_engine/core/demos/client.rb' => [2, 'demos_throttle.lock'],
    'noxun_engine/core/demos/image_cache.rb' => [4, 'textures/ (obrazok cez docasne meno)'],
    'noxun_engine/core/demos/sitemap_cache.rb' => [1, 'demos_sitemap.json'],
    'noxun_engine/core/dim_series.rb' => [1, 'dim_series.json'],
    'noxun_engine/core/direction_check.rb' => [1, 'direction_check.json'],
    'noxun_engine/core/edge_check.rb' => [1, 'edge_check.json'],
    'noxun_engine/core/export_settings.rb' => [1, 'vepo_settings.json'],
    'noxun_engine/core/grain_check.rb' => [1, 'grain_check.json'],
    'noxun_engine/core/hardware_catalog.rb' => [3, 'hardware_catalog.json a hardware_catalog.lock'],
    'noxun_engine/core/hardware_rules.rb' => [1, 'hardware_rules.json'],
    'noxun_engine/core/hardware_sets.rb' => [1, 'hardware_sets.json'],
    'noxun_engine/core/hardware_taxonomy.rb' => [1, 'hardware_taxonomy.json'],
    'noxun_engine/core/json_file_store.rb' => [9, 'primitivum: atomicky zapis a .bak za volajuceho (write_temp)'],
    'noxun_engine/core/materials.rb' => [7, 'materials.json, materials.lock, materials.pre-schema-2.json'],
    'noxun_engine/core/materials_appearance.rb' => [3, 'appearances/ (publikacia staging -> <uuid>.skm)'],
    'noxun_engine/core/materials_catalog.rb' => [2, 'uni_seed.done a drawer_uni_seed.done'],
    'noxun_engine/core/materials_health.rb' => [14, 'obnova/rollback materials.json, migration_hold.json, forenzne kopie, uni_seed.done'],
    'noxun_engine/core/materials_native_appearance.rb' => [1, 'appearances/ staging (.skm)'],
    'noxun_engine/core/supplier_settings.rb' => [1, 'supplier_settings.json'],
    'noxun_engine/core/template_previews.rb' => [14, 'template_previews/ (capture v tmp/, .png.new cez stage_then_rename, upratanie)'],
    'noxun_engine/core/templates.rb' => [6, 'templates.json, template_usage.json a ich zamky'],
    'noxun_engine/core/updater.rb' => [31, 'updater_settings.json + instalacia v Plugins (staging, swap, lease, copy_file!, try_rename)'],
    'noxun_engine/core/usage_stats.rb' => [3, 'usage_stats.json a jeho zamok'],
    'noxun_engine/core/vepo_export.rb' => [8, 'export: priecinok VEPO, ktory vybral pouzivatel'],
    'noxun_engine/core/xlsx_writer.rb' => [3, 'export: subor XLSX, ktory vybral pouzivatel (write_book)'],
    'noxun_engine/tools/legacy_cleanup.rb' => [2, 'legacy_cleanup.json + mazanie starych pluginov v Plugins'],
    'noxun_engine/ui/appliance_dialog.rb' => [1, 'temp: miniatura prilohy'],
    'noxun_engine/ui/materials_appearance_dialog.rb' => [1, 'temp: nahlad vzhladu v Dir.mktmpdir'],
    'noxun_engine/ui/production_core.rb' => [2, 'export: CSV a XLSX (XlsxWriter.write_book), ktore vybral pouzivatel']
  }.freeze

  KIND_SK = { 'library' => 'knižnica', 'attachments' => 'prílohy', 'setting' => 'nastavenie',
              'cache' => 'cache', 'marker' => 'značka', 'backup' => 'záloha' }.freeze
  LOCK_MODE_SK = { 'caller' => 'drží volajúci', 'mixed' => 'zmiešaný' }.freeze

  module_function

  # --- bezec prveho behu (samostatny proces) -----------------------------------

  def run_once
    out = IO.popen([RbConfig.ruby, RUNNER], err: File::NULL, &:read).to_s
    line = out.lines.find { |l| l.start_with?('NXH16_JSON=') }
    raise "bezec H16 nevratil vysledok:\n#{out[0, 2000]}" unless line

    JSON.parse(line.sub('NXH16_JSON=', ''))
  end

  # Dva behy bezca (memo) — volaju ich vsetky testy nad prvym behom.
  def runs
    @runs ||= [run_once, run_once]
  end

  def golden
    @golden ||= JSON.parse(File.read(GOLDEN, encoding: 'UTF-8'))
  end

  def golden_problems(run, gold)
    probs = []
    extra = run['files'] - gold['files']
    gone = gold['files'] - run['files']
    probs << "novy subor po prvom behu: #{extra.join(', ')}" unless extra.empty?
    probs << "chyba subor po prvom behu: #{gone.join(', ')}" unless gone.empty?
    gold['sha'].each do |f, sha|
      probs << "#{f}: obsah sa zmenil (SHA-256)" unless run['sha'][f] == sha
    end
    probs << "zamky pri zapise sa zmenili: #{run['locks_at_write'].inspect}" unless run['locks_at_write'] == gold['locks_at_write']
    probs
  end

  # --- zdroje -------------------------------------------------------------------

  def read(rel)
    File.binread(File.join(NxTest::ROOT, rel)).force_encoding(Encoding::UTF_8).gsub("\r\n", "\n")
  end

  # Ruby zdroje pluginu: rel (od korena repa) -> text.
  def plugin_sources
    files = Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')).sort
    files << File.join(NxTest::ROOT, 'noxun_engine.rb')
    files.to_h { |p| rel = p.sub("#{NxTest::ROOT}/", ''); [rel, read(rel)] }
  end

  # Riadky kodu bez komentarov: [[kod, cislo_riadku], ...].
  def code_lines(src)
    src.each_line.with_index(1).reject { |l, _| l.strip.start_with?('#') }.map { |l, n| [l.sub(/\s#\s.*\z/, ''), n] }
  end

  # --- T4: literaly mien uloziska -------------------------------------------------

  def storage_literals(sources)
    out = Hash.new { |h, k| h[k] = [] }
    sources.each do |rel, src|
      code_lines(src).each do |code, no|
        at = "#{rel}:#{no}"
        code.scan(STR_RE).each { |a, b| s = a || b; out[s] << at if s.match?(NAME_RE) }
        code.scan(DIR_CONST_RE).flatten.each { |v| out[v] << at }
        code.scan(JOIN_RE).flatten.each { |v| out[v] << at }
        code.scan(STAMP_RE).flatten.each { |v| out["#{v}-20260101-000000.json"] << at }
      end
    end
    out
  end

  # Mena, ktore supis pozna: subory, zamky, priecinky a ich prve segmenty,
  # vzory (glob, children, transient) a mena skupin OUTSIDE.
  def known_name?(name, entries = R::ENTRIES, outside = R::OUTSIDE)
    exact = R::LOCKS.keys.dup
    globs = []
    entries.each do |r|
      f = r['file']
      if f.match?(/[*?{\[]/)
        globs << f
      else
        exact << f.chomp('/')
      end
      exact << r['lock'] if r['lock']
      (r['children'] + r['transient']).each do |pat|
        globs << pat
        seg = pat.split('/').first
        exact << seg unless seg.match?(/[*?{\[]/)
      end
    end
    outside.each { |g| globs.concat(g['names']) }
    exact.include?(name) || globs.any? { |g| File.fnmatch(g, name, FNM) }
  end

  def literal_problems(lits, entries = R::ENTRIES, outside = R::OUTSIDE)
    lits.reject { |name, _| known_name?(name, entries, outside) }.map do |name, where|
      "#{name} (#{where.first}) nie je v supise — dopln riadok LibraryRegistry::ENTRIES (sync rozhodne Michal) " \
        'alebo OUTSIDE s dovodom'
    end
  end

  # --- T5 / T5b: zapisovatelia a zapisove miesta ----------------------------------

  def write_counts(sources)
    sources.to_h { |rel, src| [rel, code_lines(src).count { |code, _| code.match?(WRITE_RE) }] }.reject { |_, n| n.zero? }
  end

  def declared_writers(entries = R::ENTRIES, outside = R::OUTSIDE)
    (entries.flat_map { |r| r['writers'] } + outside.flat_map { |g| g['writers'] } + R::PRIMITIVES).uniq
  end

  def writer_problems(sources, entries = R::ENTRIES, outside = R::OUTSIDE)
    found = write_counts(sources).keys
    declared = declared_writers(entries, outside).select { |w| w.end_with?('.rb') }
    missing = (found - declared).map do |f|
      "#{f} zapisuje na disk, ale nie je v supise — dopln writers riadku LibraryRegistry alebo OUTSIDE s dovodom"
    end
    stale = (declared - found).map { |f| "#{f} je v supise ako zapisovatel, ale nezapisuje — zastaraly riadok" }
    missing + stale
  end

  def write_site_problems(sources, table = WRITE_SITES)
    counts = write_counts(sources)
    probs = counts.filter_map do |rel, n|
      want = table[rel]
      next "#{rel}: #{n} zapisovych miest, supis ich nepozna — zarad ich a dopln NX WRITE_SITES" if want.nil?
      next if want[0] == n

      "#{rel}: #{n} zapisovych miest, supis pozna #{want[0]} — nove miesto zarad (riadok LibraryRegistry/OUTSIDE " \
        'alebo vynimka s dovodom) a uprav pocet'
    end
    probs + (table.keys - counts.keys).map { |rel| "#{rel}: v WRITE_SITES, ale nezapisuje — odstran riadok" } +
      table.select { |_, (_, why)| why.to_s.strip.empty? }.keys.map { |rel| "#{rel}: chyba dovod" }
  end

  # --- T3: jediny koren -------------------------------------------------------------

  # Kazde citanie premennej APPDATA (ENV['…'], ENV["…"], ENV.fetch) v kode pluginu.
  APPDATA_RE = /\bENV\s*(?:\[\s*['"]APPDATA['"]\s*\]|\.fetch\(\s*['"]APPDATA['"])/.freeze

  # Rozsahy metod (riadky) a ich tela: [[meno, od, do, telo], ...].
  def method_ranges(src)
    lines = src.lines
    out = []
    lines.each_with_index do |l, i|
      m = l.match(/\A([ \t]*)def (?:self\.)?([a-z_]\w*[?!=]?)/)
      next unless m

      stop = ((i + 1)...lines.length).find { |j| lines[j].match?(/\A#{m[1]}end\b/) }
      next if stop.nil?

      out << [m[2], i + 1, stop + 1, lines[(i + 1)...stop].join]
    end
    out
  end

  # Jediny koren: %APPDATA% smie citat LEN `Materials.dir` a zalozna vetva metody,
  # ktora NAJPRV deleguje na `Materials.dir` (vzor `AbsRules.dir`) — v akejkolvek
  # metode a v akomkolvek zapise; citanie mimo metody (konstanta) je chyba.
  def root_problems(sources)
    probs = []
    sources.each do |rel, src|
      ranges = method_ranges(src)
      code_lines(src).each do |code, no|
        next unless code.match?(APPDATA_RE)

        inner = ranges.select { |_n, a, b, _| a < no && no < b }.min_by { |_n, a, b, _| b - a }
        if inner.nil?
          probs << "#{rel}:#{no}: %APPDATA% mimo metody — koren ber z Materials.dir"
          next
        end
        name, _a, _b, body = inner
        next if rel == 'noxun_engine/core/materials.rb' && name == 'dir'
        next if body.match?(/\breturn Materials\.dir\b/)

        probs << "#{rel}:#{no} #{name}: koren si pocita z %APPDATA% sam — deleguj na Materials.dir (vzor AbsRules.dir)"
      end
    end
    probs
  end

  # --- T6 / T6b: triedenie mien v koreni --------------------------------------------
  #   :final      subor knizice/nastavenia alebo FINALNY subor priecinka (D-48 prenasa len tieto)
  #   :technical  `.bak` a zamky (nikdy sa neprenasaju)
  #   :transient  docasne meno zapisu (nikdy sa neprenasa)
  #   :unknown    nic zo supisu — chyba
  def classify(rel, entries = R::ENTRIES, locks = R::LOCKS)
    return :technical if locks.key?(rel)

    entries.each do |r|
      f = r['file']
      if f.end_with?('/')
        next unless rel.start_with?(f)

        sub = rel[f.length..]
        return :transient if r['transient'].any? { |p| File.fnmatch(p, sub, FNM) }
        return :final if r['children'].any? { |p| File.fnmatch(p, sub, FNM) }
      else
        return :transient if r['transient'].any? { |p| File.fnmatch(p, rel, FNM) }
        return :final if f.match?(/[*?{\[]/) ? File.fnmatch(f, rel, FNM) : rel == f
        return :technical if r['bak'] && rel == "#{f}.bak"
      end
    end
    :unknown
  end

  # --- T2 / T11: cesty resolverov z bezca ---------------------------------------------

  def path_problems(run, root_key, paths_key)
    root = run[root_key]
    probs = []
    R::ENTRIES.each do |r|
      spec = r['resolver']
      next if spec.nil?

      got = run[paths_key][spec]
      if got == 'nedostupny'
        probs << "#{r['key']}: resolver #{spec} nie je headless dostupny" unless STATIC_RESOLVERS.include?(spec)
        next
      end
      want = File.expand_path(File.join(root, r['file'].chomp('/')))
      probs << "#{r['key']}: #{spec} = #{got}, cakane #{want}" unless got == want
    end
    R::LOCKS.each do |name, spec|
      want = File.expand_path(File.join(root, name))
      got = run[paths_key][spec]
      probs << "zamok #{name}: #{spec} = #{got}, cakane #{want}" unless got == want
    end
    probs
  end

  # --- T2b: drzany zamok pri zapise -------------------------------------------------

  def lock_binding_problems(locks_at_write, entries = R::ENTRIES)
    locks_at_write.filter_map do |rel, held|
      r = entries.find { |e| e['file'] == rel }
      next "#{rel}: zapisany cez JsonFileStore, ale nie je riadkom supisu" if r.nil?

      want = r['lock'].to_s
      next if held == [want]

      "#{rel}: pri zapise drzany zamok #{held.inspect}, supis hovori #{want.empty? ? 'bez zamku' : want}"
    end
  end

  # --- T7: verzie <-> STANDARD §13.1 -----------------------------------------------

  def standard_file_versions(std_text)
    sec = std_text[/\*\*Súbory na počítači[^\n]*\n(.*?)(?=^###? )/m, 1].to_s
    sec.lines.select { |l| l.start_with?('|') }.filter_map do |l|
      cells = l.strip.sub(/\A\|/, '').sub(/\|\z/, '').split('|').map(&:strip)
      cells[1].to_s.scan(/`([^`]+)`/).flatten.find { |t| t.include?('::') }
    end
  end

  def version_problems(std_names, entries = R::ENTRIES)
    reg = entries.flat_map { |r| r['versions'] }
    dup = reg.group_by(&:itself).select { |_, v| v.length > 1 }.keys
    (std_names - reg).map { |n| "STANDARD §13.1 menuje #{n}, supis ho pri ziadnom subore nema" } +
      (reg - std_names).map { |n| "supis menuje verziu #{n}, ktora nie je v STANDARD §13.1 „Súbory na počítači“" } +
      dup.map { |n| "verzia #{n} je v supise dvakrat" }
  end

  # 'Mod::CONST' -> hodnota v kode (aj `LegacyCleanup` pod `Tools`); nil = nenajdena.
  def const_value(name)
    mod, const = name.split('::', 2)
    if mod == 'Engine'
      return read('noxun_engine/main.rb')[/^\s*#{Regexp.escape(const)}\s*=\s*(\d+)\b/, 1]&.to_i
    end

    [E, E::Tools].each do |ns|
      next unless ns.const_defined?(mod, false)

      owner = ns.const_get(mod, false)
      return owner.const_get(const, false) if owner.const_defined?(const, false)
    end
    nil
  end

  # --- T8: kniznice.md <-> register --------------------------------------------------

  def cell_versions(r)
    r['versions'].empty? ? '—' : r['versions'].map { |v| "`#{v}`" }.join(' · ')
  end

  def cell_lock(r)
    case r['lock_mode']
    when 'module' then "`#{r['lock']}`"
    when 'caller', 'mixed' then "`#{r['lock']}` · #{LOCK_MODE_SK[r['lock_mode']]}"
    when 'self' then 'sám seba'
    else '—'
    end
  end

  def doc_row(r)
    ["`#{r['file']}`", KIND_SK[r['kind']], r['sync'] == 'shared' ? 'áno' : 'nie', cell_lock(r), cell_versions(r)]
  end

  # { '## 2' => [[bunky...]], ... } — riadky tabuliek, ktorych prva bunka je kod.
  def doc_tables(text)
    section = nil
    text.lines.each_with_object(Hash.new { |h, k| h[k] = [] }) do |line, out|
      section = line[/\A(## \d+)/, 1] if line.start_with?('## ')
      next unless line.start_with?('|') && section

      cells = line.strip.sub(/\A\|/, '').sub(/\|\z/, '').split('|').map(&:strip)
      out[section] << cells if cells[0].to_s.match?(/\A`[^`]+`\z/)
    end
  end

  def doc_problems(text, entries = R::ENTRIES, outside = R::OUTSIDE)
    t = doc_tables(text)
    probs = []
    { '## 2' => 'shared', '## 3' => 'local' }.each do |sec, sync|
      want = entries.select { |r| r['sync'] == sync }.map { |r| doc_row(r) }
      have = t[sec].map { |c| c[0, 5] }
      (want - have).each { |w| probs << "#{DOC} #{sec}: chyba alebo nesedi riadok #{w.join(' | ')}" }
      (have - want).each { |h| probs << "#{DOC} #{sec}: riadok #{h.join(' | ')} nezodpoveda registru" }
    end
    have4 = t['## 4'].map { |c| c[0].delete('`') }
    want4 = outside.map { |g| g['key'] }
    probs << "#{DOC} ## 4: skupiny #{have4.sort.inspect} != OUTSIDE #{want4.sort.inspect}" unless have4.sort == want4.sort
    probs
  end

  # --- T9: pamat okien -----------------------------------------------------------------

  # Literal v ', " alebo ` (sablona JS) — skupina 2 = obsah.
  Q = %q{(['"`])((?:(?!\1).){1,120}?)\1}
  LS_KEY_RES = [/localStorage\.(?:get|set|remove)Item\(\s*#{Q}/, /\bls(?:Get|Set)\(\s*#{Q}/,
                /\b\w*_KEY\s*=\s*#{Q}/].freeze
  FORBIDDEN_RE = /\bsessionStorage\b|\bindexedDB\b|document\.cookie|\bopenDatabase\b|caches\.open|navigator\.storage/.freeze
  # Supis sam menuje localStorage v datach — nie je pouzivatelom pamate okna.
  MEMORY_SKIP = %w[noxun_engine/core/library_registry.rb].freeze

  # Kod bez komentarov podla typu: JS (//, /* */), HTML (<!-- --> + inline JS), Ruby (#).
  def web_code(rel, src)
    return code_lines(src).map(&:first).join if rel.end_with?('.rb')

    s = rel.end_with?('.html') ? src.gsub(/<!--.*?-->/m, '') : src
    s = s.gsub(%r{/\*.*?\*/}m, '')
    s.lines.reject { |l| l.strip.start_with?('//') }.map { |l| l.sub(%r{\s//\s.*\z}, '') }.join
  end

  def literals(text)
    text.scan(Regexp.new(Q)).map(&:last)
  end

  # sources = { rel => text } — ui/**/*.{js,html} a Ruby pluginu (aj HTML skladane v Ruby).
  def js_memory_problems(sources, outside = R::OUTSIDE)
    mem = outside.find { |g| g['key'] == 'ui_memory' }
    probs = []
    users = []
    sources.each do |rel, src|
      next if MEMORY_SKIP.include?(rel)

      code = web_code(rel, src)
      probs << "#{rel}: nova perzistencia okna (#{code[FORBIDDEN_RE]}) — zarad ju do supisu" if code.match?(FORBIDDEN_RE)
      next unless code.include?('localStorage') || code.match?(/\bsecKey\b.*\{/)

      users << rel if code.include?('localStorage')
      keys = LS_KEY_RES.flat_map { |re| code.scan(re).map(&:last) }
      code.scan(/RECENT_KEYS\s*=\s*\{([^}]*)\}/).flatten.each { |b| keys.concat(literals(b)) }
      # secKey sklada kluc z prefixu a casti ('nxsec_s4.' + ctx + '.' + key) — prefixy su literaly s pismenom.
      code.scan(/function secKey\([^)]*\)\s*\{(.*?)\n\s*\}/m).flatten.each do |b|
        keys.concat(literals(b).grep(/\A[a-z]/i))
      end
      keys.uniq.each do |k|
        next if mem['names'].any? { |n| File.fnmatch(n, k) }

        probs << "#{rel}: kluc localStorage '#{k}' nie je v OUTSIDE ui_memory — dopln ho s dovodom"
      end
    end
    (users - mem['writers']).each { |f| probs << "#{f} pouziva localStorage, ale nie je v writers ui_memory" }
    (mem['writers'] - users).each { |f| probs << "#{f} je v writers ui_memory, ale localStorage nepouziva" }
    probs
  end

  def memory_sources
    web = Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', 'ui', '**', '*.{js,html}')).sort.to_h do |p|
      rel = p.sub("#{NxTest::ROOT}/", '')
      [rel, read(rel)]
    end
    web.merge(plugin_sources)
  end

  # --- T1: zmrazenie ------------------------------------------------------------------

  def deep_frozen?(obj)
    return false unless obj.frozen?

    case obj
    when Hash then obj.all? { |k, v| deep_frozen?(k) && deep_frozen?(v) }
    when Array then obj.all? { |v| deep_frozen?(v) }
    else true
    end
  end

  def shape_problems(entries = R::ENTRIES)
    probs = []
    keys = entries.map { |r| r['key'] }
    files = entries.map { |r| r['file'] }
    probs << "duplicitne kluce #{keys.tally.select { |_, n| n > 1 }.keys}" unless keys.uniq == keys
    probs << "duplicitne subory #{files.tally.select { |_, n| n > 1 }.keys}" unless files.uniq == files
    by = entries.to_h { |r| [r['key'], r] }
    entries.each do |r|
      k = r['key']
      probs << "#{k}: kluc nie je snake_case" unless k.match?(/\A[a-z][a-z0-9_]*\z/)
      probs << "#{k}: kind #{r['kind']}" unless R::KINDS.include?(r['kind'])
      probs << "#{k}: sync #{r['sync']}" unless R::SYNCS.include?(r['sync'])
      probs << "#{k}: lock_mode #{r['lock_mode']}" unless R::LOCK_MODES.include?(r['lock_mode'])
      needs_lock = %w[module caller mixed].include?(r['lock_mode'])
      if needs_lock
        probs << "#{k}: lock #{r['lock'].inspect} nie je v LOCKS" unless R::LOCKS.key?(r['lock'])
      elsif !r['lock'].nil?
        probs << "#{k}: lock_mode #{r['lock_mode']} nesmie mat zamok #{r['lock']}"
      end
      dir = r['file'].end_with?('/')
      probs << "#{k}: priecinok bez children (vzory finalnych suborov)" if dir && r['children'].empty?
      probs << "#{k}: children ma len priecinok" if !dir && !r['children'].empty?
      if r['kind'] == 'attachments'
        lib = by[r['of']]
        probs << "#{k}: prilohy bez of" if lib.nil?
        probs << "#{k}: of #{r['of']} nie je knizica" if lib && lib['kind'] != 'library'
        probs << "#{k}: knizica #{r['of']} neuvadza prilohy #{k}" if lib && !lib['attachments'].include?(k)
      elsif r['of']
        probs << "#{k}: of ma len riadok druhu attachments"
      end
      r['attachments'].each do |a|
        probs << "#{k}: prilohy #{a} neukazuju spat (of)" unless by[a] && by[a]['of'] == k
      end
      if r['kind'] == 'library'
        probs << "#{k}: knizica bez verzie" if r['versions'].empty?
        probs << "#{k}: knizica bez .bak (JsonFileStore.write)" unless r['bak']
      end
      probs << "#{k}: bez zapisovatela" if r['writers'].empty?
      r['writers'].each { |w| probs << "#{k}: zapisovatel #{w} neexistuje" unless File.file?(File.join(NxTest::ROOT, w)) }
      probs << "#{k}: outputs + local bez poznamky (preco ostava na PC)" if r['outputs'] && r['sync'] == 'local' && r['note'].to_s.strip.empty?
    end
    probs
  end
end

# --- T0 ---------------------------------------------------------------------------------

NxTest.test('H16 T0: golden prveho behu — dva behy v samostatnych procesoch = fixtura (subory, SHA, zamky)') do
  NxTest.skip!('bezec potrebuje samostatny Ruby interpreter (len headless)') unless NxTest.headless?
  a, b = NxH16.runs
  [a, b].each_with_index do |run, i|
    probs = NxH16.golden_problems(run, NxH16.golden)
    NxTest.assert(probs.empty?, "beh #{i + 1}: #{probs.join(' · ')} — golden sa v H16 NEREGENERUJE (nalez)")
  end
  NxTest.assert_equal(a['files'], b['files'], 'dva behy vyrobili inu mnozinu suborov')
  NxTest.assert(NxH16.golden['files'].length >= 25, 'golden ma podozrivo malo suborov')
end

NxTest.test('H16 T0: negativ — iny subor, iny obsah alebo iny zamok golden zhodi') do
  gold = { 'files' => %w[a.json b.lock], 'sha' => { 'a.json' => 'x' }, 'locks_at_write' => { 'a.json' => ['b.lock'] } }
  ok = { 'files' => %w[a.json b.lock], 'sha' => { 'a.json' => 'x' }, 'locks_at_write' => { 'a.json' => ['b.lock'] } }
  NxTest.assert(NxH16.golden_problems(ok, gold).empty?)
  NxTest.refute(NxH16.golden_problems(ok.merge('files' => %w[a.json b.lock presets.json]), gold).empty?)
  NxTest.refute(NxH16.golden_problems(ok.merge('sha' => { 'a.json' => 'y' }), gold).empty?)
  NxTest.refute(NxH16.golden_problems(ok.merge('locks_at_write' => { 'a.json' => [''] }), gold).empty?)
end

# --- T1 ---------------------------------------------------------------------------------

NxTest.test('H16 T1: tvar registra — kluce, mnoziny, zamok <-> rezim, prilohy, verzie, zapisovatelia') do
  probs = NxH16.shape_problems
  NxTest.assert(probs.empty?, probs.join("\n"))
  NxTest.assert(NxH16::R::ENTRIES.length >= 30, "supis ma len #{NxH16::R::ENTRIES.length} riadkov")
end

NxTest.test('H16 T1: negativy tvaru — zly zamok, prilohy bez of, knizica bez verzie, outputs+local bez poznamky') do
  base = NxH16::R::ENTRIES.map { |r| JSON.parse(JSON.generate(r)) }
  mutate = lambda do |key, changes|
    base.map { |r| r['key'] == key ? r.merge(changes) : r }
  end
  NxTest.assert(NxH16.shape_problems(base).empty?, 'kopia registra musi prejst')
  NxTest.refute(NxH16.shape_problems(mutate.call('materials', 'lock' => 'material.lock')).empty?, 'neznamy zamok')
  NxTest.refute(NxH16.shape_problems(mutate.call('uni_seed', 'lock_mode' => 'none')).empty?, 'none so zamkom')
  NxTest.refute(NxH16.shape_problems(mutate.call('appearances', 'of' => nil)).empty?, 'prilohy bez of')
  NxTest.refute(NxH16.shape_problems(mutate.call('abs_rules', 'versions' => [])).empty?, 'knizica bez verzie')
  NxTest.refute(NxH16.shape_problems(mutate.call('export_settings', 'note' => '')).empty?, 'outputs + local bez note')
  NxTest.refute(NxH16.shape_problems(mutate.call('textures', 'children' => [])).empty?, 'priecinok bez children')
  NxTest.refute(NxH16.shape_problems(mutate.call('dim_series', 'writers' => ['noxun_engine/core/nie.rb'])).empty?)
end

NxTest.test('H16 T1: register je hlboko zmrazeny a API vracia riadky bez citania disku') do
  r = NxH16::R
  [r::ENTRIES, r::OUTSIDE, r::LOCKS, r::KINDS, r::SYNCS, r::LOCK_MODES, r::PRIMITIVES].each do |obj|
    NxTest.assert(NxH16.deep_frozen?(obj), "nezmrazene: #{obj.inspect[0, 80]}")
  end
  NxTest.refute(NxH16.deep_frozen?([{ 'a' => [+'x'] }.freeze].freeze), 'negativ: vnorene pole nezmrazene')
  NxTest.assert_equal(r::ENTRIES, r.entries)
  NxTest.assert_equal(r::ENTRIES.map { |e| e['key'] }, r.keys)
  NxTest.assert_equal('materials.json', r.get(:materials)['file'])
  NxTest.assert_equal('materials.json', r.get('materials')['file'])
  NxTest.assert(r.get('presets').nil? && r.get(nil).nil?, 'neznamy kluc = nil')
  NxTest.assert_equal(NxH16::SHARED.sort, r.shared.map { |e| e['key'] }.sort)
  NxTest.assert_equal(File.join(r.root, 'templates.json'), r.path('templates'))
  NxTest.assert_equal(File.join(r.root, 'template_previews'), r.path('template_previews'))
  NxTest.assert(r.path('materials_forensic').nil?, 'glob nema jednu cestu')
  NxTest.assert_equal(NxH16::E::Materials.dir, r.root)
end

# --- T2 / T2b / T11 (bezec) ----------------------------------------------------------------

NxTest.test('H16 T2: cesta kazdeho riadku a zamku = koren + subor aj pod test_dir_override (jediny koren)') do
  NxTest.skip!('bezec len headless') unless NxTest.headless?
  probs = NxH16.path_problems(NxH16.runs[0], 'override_root', 'paths_override')
  NxTest.assert(probs.empty?, probs.join("\n"))
  main = NxH16.read('noxun_engine/main.rb')
  NxTest.assert(main.include?("UI_THEME_FILE = 'ui_theme.json'"), 'ui_theme.json: meno v main.rb sa zmenilo')
  body = main[/def self\.ui_theme_dir\n(.*?)\n    end/m, 1].to_s
  NxTest.assert(body.include?('return Materials.dir'), 'Engine.ui_theme_dir uz nedeleguje na Materials.dir')
end

NxTest.test('H16 T11: produkcne cesty bez override = %APPDATA%\\NOXUN\\Engine + subor (bez zmeny)') do
  NxTest.skip!('bezec len headless') unless NxTest.headless?
  probs = NxH16.path_problems(NxH16.runs[0], 'env_root', 'paths_env')
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T2b: zamok drzany pri zapise kazdeho suboru prveho behu = lock riadku') do
  NxTest.skip!('bezec len headless') unless NxTest.headless?
  law = NxH16.runs[0]['locks_at_write']
  NxTest.assert(law.length >= 19, "prvy beh zapisal cez JsonFileStore len #{law.length} suborov")
  probs = NxH16.lock_binding_problems(law)
  NxTest.assert(probs.empty?, probs.join("\n"))
  bad = NxH16::R::ENTRIES.map { |r| r['key'] == 'hardware_catalog' ? r.merge('lock' => 'materials.lock') : r }
  NxTest.refute(NxH16.lock_binding_problems(law, bad).empty?, 'negativ: iny platny zamok musi padnut')
  bad2 = NxH16::R::ENTRIES.map { |r| r['key'] == 'uni_seed' ? r.merge('lock' => nil) : r }
  NxTest.refute(NxH16.lock_binding_problems(law, bad2).empty?, 'negativ: znacka bez zamku musi padnut')
end

# --- T3 -------------------------------------------------------------------------------------

NxTest.test('H16 T3: jediny koren — %APPDATA% cita len Materials.dir a zalozne vetvy delegujuce na neho') do
  probs = NxH16.root_problems(NxH16.plugin_sources)
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T3: negativy — vlastny ENV v *_dir, ENV["APPDATA"], ENV.fetch v inej metode, konstanta') do
  wrap = ->(body) { { 'noxun_engine/core/novy.rb' => "module X\n#{body}end\n" } }
  NxTest.refute(NxH16.root_problems(wrap.call("  def self.presets_dir\n    File.join(ENV['APPDATA'], 'NOXUN')\n  end\n")).empty?)
  NxTest.refute(NxH16.root_problems(wrap.call("  def root_path\n    File.join(ENV[\"APPDATA\"], 'NOXUN')\n  end\n")).empty?)
  NxTest.refute(NxH16.root_problems(wrap.call("  def base\n    ENV.fetch('APPDATA', '.')\n  end\n")).empty?)
  NxTest.refute(NxH16.root_problems(wrap.call("  ROOT = ENV['APPDATA'].to_s\n")).empty?)
  ok = "  def dir\n    return Materials.dir if defined?(Materials)\n\n    File.join(ENV['APPDATA'], 'NOXUN')\n  end\n"
  NxTest.assert(NxH16.root_problems(wrap.call(ok)).empty?, 'zalozna vetva za Materials.dir je povolena')
end

NxTest.test('H16 T4: kazdy literal mena uloziska v plugine je v supise') do
  lits = NxH16.storage_literals(NxH16.plugin_sources)
  NxTest.assert(lits.length >= 30, "sken nasiel len #{lits.length} mien — zmenil sa tvar kodu?")
  probs = NxH16.literal_problems(lits)
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T4: negativ — novy subor kniznice v zdroji zhodi guard') do
  fake = { 'noxun_engine/core/novy.rb' => "module X\n  FILE = 'presets.json'\n  DIR_NAME = 'presets'\n" \
                                          "  def p\n    File.join(dir, 'other.lock')\n  end\nend\n" }
  probs = NxH16.literal_problems(NxH16.storage_literals(fake))
  %w[presets.json presets other.lock].each do |n|
    NxTest.assert(probs.any? { |p| p.start_with?("#{n} ") }, "guard nevidel #{n}: #{probs.inspect}")
  end
  less = NxH16::R::ENTRIES.reject { |r| r['key'] == 'hardware_taxonomy' }
  NxTest.refute(NxH16.literal_problems({ 'hardware_taxonomy.json' => ['x:1'] }, less).empty?)
end

# --- T5 / T5b ---------------------------------------------------------------------------------

NxTest.test('H16 T5: kazdy subor so zapisom na disk je v supise a naopak') do
  probs = NxH16.writer_problems(NxH16.plugin_sources)
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T5: negativy — novy zapisovatel mimo supisu, zapisovatel v supise bez zapisu') do
  src = NxH16.plugin_sources
  extra = src.merge('noxun_engine/ui/rules_dialog.rb' => "#{src['noxun_engine/ui/rules_dialog.rb']}\nFile.binwrite(p, x)\n")
  NxTest.assert(NxH16.writer_problems(extra).any? { |p| p.include?('ui/rules_dialog.rb zapisuje') })
  stale = NxH16::R::ENTRIES.map { |r| r['key'] == 'dim_series' ? r.merge('writers' => %w[noxun_engine/core/units.rb]) : r }
  NxTest.assert(NxH16.writer_problems(src, stale).any? { |p| p.include?('core/units.rb je v supise') })
end

NxTest.test('H16 T5b: pocet zapisovych miest v kazdom subore = supis (nove miesto v znamom subore zastavi)') do
  probs = NxH16.write_site_problems(NxH16.plugin_sources)
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T5b: negativy — druhy zapis v znamom subore, pomocnik deploy_bytes, zmazany zapis') do
  src = NxH16.plugin_sources
  dim = 'noxun_engine/core/dim_series.rb'
  two = src.merge(dim => "#{src[dim]}\nJsonFileStore.write(File.join(Materials.dir, \"\#{name}.json\"), {})\n")
  NxTest.assert(NxH16.write_site_problems(two).any? { |p| p.start_with?("#{dim}: 2 ") })
  cat = 'noxun_engine/core/materials_catalog.rb'
  helper = src.merge(cat => "#{src[cat]}\ndeploy_bytes(File.join(dir, x), b)\n")
  NxTest.assert(NxH16.write_site_problems(helper).any? { |p| p.start_with?("#{cat}: 3 ") })
  less = src.merge(dim => src[dim].gsub('JsonFileStore.write(', 'JsonFileStore.nic('))
  NxTest.assert(NxH16.write_site_problems(less).any? { |p| p.include?(dim) })
end

NxTest.test('H16 T5b: negativy — novy ciel cez znameho pomocnika a dalsie zapisove primitiva') do
  src = NxH16.plugin_sources
  app = 'noxun_engine/core/appliance_catalog.rb'
  thumbs = src.merge(app => "#{src[app]}\nstage_attachment(src, File.join(dir, THUMBS_DIR), att_id, file)\n")
  NxTest.assert(NxH16.write_site_problems(thumbs).any? { |p| p.start_with?("#{app}: 15 ") }, 'pomocnik s novym cielom')
  ["IO.binwrite(p, x)", "IO.copy_stream(a, b)", "File.new(p, 'w')", "Dir.mkdir(p)", "FileUtils.touch(p)", 'FileUtils.rm(p)',
   'FileUtils.move(a, b)', 'File.unlink(p)', 'File.delete(p)', 'Materials.deploy_bytes(p, b)'].each do |line|
    NxTest.assert(line.match?(NxH16::WRITE_RE), "zapis nechyteny: #{line}")
  end
  ['File.read(p)', "File.open(p, 'rb')", 'stats.copy_file(x)', 'obj.rm(p)', 'File.exist?(p)'].each do |line|
    NxTest.refute(line.match?(NxH16::WRITE_RE), "citanie hlasene ako zapis: #{line}")
  end
end

NxTest.test('H16 T5b: kazdy zapisovy pomocnik z WRITE_HELPERS je v plugine definovany') do
  all = NxH16.plugin_sources.values.join
  missing = NxH16::WRITE_HELPERS.reject { |h| all.match?(/\bdef (?:self\.)?#{Regexp.escape(h)}[(\s]/) }
  NxTest.assert(missing.empty?, "pomocnik premenovany alebo zruseny: #{missing.join(', ')} — uprav WRITE_HELPERS")
end

# --- T6 / T6b -----------------------------------------------------------------------------------

NxTest.test('H16 T6: po prvom behu ziadny subor mimo supisu (subor, .bak, zamok, children, transient)') do
  NxTest.skip!('bezec len headless') unless NxTest.headless?
  files = NxH16.runs[0]['files']
  NxTest.assert(files.length >= 25, "prvy beh vyrobil len #{files.length} suborov — beh nic nevyrobil?")
  bad = files.select { |f| NxH16.classify(f) == :unknown }
  NxTest.assert(bad.empty?, "mimo supisu: #{bad.inspect}")
  NxTest.assert_equal(:unknown, NxH16.classify('presets.json'), 'negativ: neznamy subor')
end

NxTest.test('H16 T6b: triedenie mien — D-48 prenasa len finalne subory') do
  hex16 = '0123456789abcdef'
  uuid = '1b2c3d4e-0000-4000-8000-123456789abc'
  {
    'materials.json' => :final, 'materials.json.bak' => :technical, 'materials.lock' => :technical,
    'materials.json.tmp-12-345' => :transient, 'materials.corrupted-20260101-000000.json' => :final,
    "template_previews/cabinet-dolna-#{hex16}.png" => :final,
    "template_previews/cabinet-dolna-#{hex16}.png.new" => :transient,
    'template_previews/tmp/capture-1-2-ab.png' => :transient, 'template_previews/x.txt' => :unknown,
    'textures/0123456789_a.jpg' => :final, 'textures/0123456789_a.jpg.tmp1234' => :transient,
    "appearances/#{uuid}.skm" => :final, "appearances/#{uuid}.skm.staging" => :transient,
    "appliances/#{uuid}/#{uuid}_list.pdf" => :final, "appliances/#{uuid}/#{uuid}.tmp" => :transient,
    'presets.json' => :unknown, 'agent_register_videne.txt' => :unknown
  }.each { |name, want| NxTest.assert_equal(want, NxH16.classify(name), "classify(#{name})") }
  no_new = NxH16::R::ENTRIES.map do |r|
    r['key'] == 'template_previews' ? r.merge('transient' => r['transient'] - ['*.png.new']) : r
  end
  NxTest.assert_equal(:unknown, NxH16.classify("template_previews/cabinet-dolna-#{hex16}.png.new", no_new))
end

# --- T7 ---------------------------------------------------------------------------------------------

NxTest.test('H16 T7: verzie riadkov = presne konstanty STANDARD §13.1 „Súbory na počítači“ (bijekcia, Integer v kode)') do
  std = NxH16.standard_file_versions(NxH16.read(NxH16::STANDARD))
  NxTest.assert(std.length >= 20, "tabulka §13.1 ma len #{std.length} riadkov — zmenil sa tvar?")
  probs = NxH16.version_problems(std)
  NxTest.assert(probs.empty?, probs.join("\n"))
  NxH16::R::ENTRIES.flat_map { |r| r['versions'] }.each do |name|
    NxTest.assert(NxH16.const_value(name).is_a?(Integer), "verzia #{name} nie je Integer v kode")
  end
end

NxTest.test('H16 T7: negativy — riadok §13.1 bez riadku supisu a verzia supisu mimo §13.1') do
  std = NxH16.standard_file_versions(NxH16.read(NxH16::STANDARD))
  NxTest.refute(NxH16.version_problems(std + ['Presets::STD']).empty?)
  bad = NxH16::R::ENTRIES.map { |r| r['key'] == 'dim_series' ? r.merge('versions' => %w[DimSeries::NIE]) : r }
  NxTest.refute(NxH16.version_problems(std, bad).empty?)
  NxTest.assert(NxH16.const_value('DimSeries::NIE').nil?, 'neexistujuca konstanta = nil')
end

# --- T8 ---------------------------------------------------------------------------------------------

NxTest.test('H16 T8: kniznice.md §2–§3 = riadky registra (subor, druh, zdiela, zamok, verzie), §4 = OUTSIDE') do
  probs = NxH16.doc_problems(NxH16.read(NxH16::DOC))
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T8: negativ — iny sync v riadku kniznice.md zhodi guard') do
  text = NxH16.read(NxH16::DOC)
  bad = text.sub(/^(\| `dim_series\.json` \| [^|]+\| )nie( \|)/, '\1áno\2')
  NxTest.refute(bad == text, 'negativ sa neaplikoval (zmenil sa tvar riadku dim_series)')
  NxTest.refute(NxH16.doc_problems(bad).empty?)
end

# --- T9 ---------------------------------------------------------------------------------------------

NxTest.test('H16 T9: kluce localStorage (JS, HTML, Ruby) su v OUTSIDE ui_memory a ina perzistencia okna nie je') do
  probs = NxH16.js_memory_problems(NxH16.memory_sources)
  NxTest.assert(probs.empty?, probs.join("\n"))
end

NxTest.test('H16 T9: negativy — lsSet, dvojite uvodzovky, sablona, inline HTML, Ruby, sessionStorage, indexedDB') do
  src = NxH16.memory_sources
  st = 'noxun_engine/ui/js/studio.js'
  bo = 'noxun_engine/ui/js/boot.js'
  [[st, "lsSet('nx_foo', 1);"], [st, "localStorage.setItem(\"nx_foo\", '1');"], [st, 'localStorage.getItem(`nx_foo`);'],
   [st, "sessionStorage.setItem('nx_x', 1);"], [st, "indexedDB.open('nx');"]].each do |rel, line|
    NxTest.refute(NxH16.js_memory_problems(src.merge(rel => "#{src[rel]}\n#{line}\n")).empty?, "nezachytene: #{line}")
  end
  html = 'noxun_engine/ui/panel.html'
  NxTest.refute(NxH16.js_memory_problems(src.merge(html => "#{src[html]}\n<script>localStorage.setItem('nx_foo','1')</script>\n")).empty?,
                'inline skript v HTML')
  rb = 'noxun_engine/tools/mower.rb'
  NxTest.refute(NxH16.js_memory_problems(src.merge(rb => "#{src[rb]}\nHTML = \"<script>localStorage.setItem('nx_foo','1')</script>\"\n")).empty?,
                'HTML skladane v Ruby')
  NxTest.refute(NxH16.js_memory_problems(src.merge(bo => '')).empty?, 'zapisovatel v supise bez localStorage')
  NxTest.assert(NxH16.js_memory_problems(src.merge(st => "#{src[st]}\n// sessionStorage len v komentari\n")).empty?, 'komentar')
end

# --- T10 --------------------------------------------------------------------------------------------

NxTest.test('H16 T10: zdielana mnozina pripnuta — zmena = rozhodnutie Michala (D-48)') do
  shared = NxH16::R.shared.map { |r| r['key'] }
  NxTest.assert_equal(NxH16::SHARED.sort, shared.sort,
                      'zmena zdielania = rozhodnutie Michala (D-48) — uprav SHARED az po jeho slove')
  libs = NxH16::R::ENTRIES.select { |r| r['kind'] == 'library' }.map { |r| r['key'] }
  NxTest.assert((libs - shared).empty?, "knizica, ktora sa nezdiela: #{(libs - shared).inspect}")
end
