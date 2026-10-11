# frozen_string_literal: true
# Porovnavac vystupov exportov K (stary strom) a P (aktualny checkout) — nastroj
# `scripts/export_test.ps1` (davka H19, blok 9 HARDENING, PACKAGE_H17 R9.3).
# NIE JE sucast pluginu; len cita, nic nezapisuje (okrem volitelneho --out).
#
# Pravidla (R9.3, ziadne masky — vynimky su menovite):
#   * povoleny rozdiel v OBSAHU: riadky `Verzia:` a `Datum:` vo VEPO LOGu (export.log)
#     a cas zapisu (`RRRR-MM-DD HH:MM`, pripadne datum `9.10.2026`) v 1. riadku CSV kovania;
#   * povoleny rozdiel v NAZVE: datum (`9.10.2026`, `9_10_2026`);
#   * XLSX = rozbalene casti ZIPu (`xl/**`, `[Content_Types].xml`, `_rels`...) porovnane
#     bajtovo; ZIP hlavicky (cas zapisu) sa neporovnavaju; vynimka: vygenerovane datum
#     v titulku harka (`- AKT. 9.10. 2026`), ine rozdiely v tom istom XML ostavaju rozdielom;
#   * vsetko ostatne (kazdy dielec VEPO, kazdy bajt XML harka, meno VEPO skupiny,
#     chybajuci/nadbytocny subor) = rozdiel;
#   * vstupny model v priecinku vystupu sa vyluci MENOVITE (`--exclude-input meno`).
# Pouzitie: ruby scripts/export_compare.rb K P [--exclude-input meno]...
#           [--log-k log] [--log-p log] [--out subor]      exit 0 = zhodne, 1 = rozdiel
require 'json'
require 'zlib'

module ExportCompare
  VERZIA = 'Verzia:'.b.freeze
  DATUM  = "Dátum:".b.freeze
  ALLOWED_MARK = "«ALLOWED»".b.freeze
  STAMP = /\d{4}-\d{2}-\d{2} \d{2}:\d{2}/n
  DATE_DOT = /(?<!\d)\d{1,2}\.\s?\d{1,2}\.\s?\d{4}(?!\d)/
  SHEET_TITLE_DATE = /(- AKT\. )\d{1,2}\.\d{1,2}\.\s?\d{4}/n
  DATE_UND =/(?<!\d)\d{1,2}_\d{1,2}_\d{4}(?!\d)/
  METHODS = %w[do_export do_hw_csv do_budget_xlsx do_cp_xlsx].freeze
  MAX_DIFFS = 8

  Item = Struct.new(:key, :path, :name)
  Row = Struct.new(:verdict, :key, :note, :details)

  module_function

  # Datum v nazve suboru/vete nie je rozdiel (K a P bezia v inych minutach, pri
  # polnoci aj v inych dnoch).
  def norm_name(name)
    name.to_s.gsub(DATE_DOT, '<DATUM>').gsub(DATE_UND, '<DATUM>')
  end

  # Strom vystupov -> { kluc => Item }. Kluce: hw_csv, budget_xlsx, offer_xlsx,
  # `vepo/<meno bez slugu priecinka>`, `other/<relativna cesta>`.
  def classify(root, exclude: [])
    out = {}
    Dir.glob('**/*', File::FNM_DOTMATCH, base: root).sort.each do |rel|
      p = File.join(root, rel)
      next unless File.file?(p)

      parts = rel.split('/')
      base = parts.last
      next if parts.length == 1 && exclude.include?(base)

      key =
        if parts.length > 1
          slug = parts.first
          rest = parts[1..].join('/')
          rest = rest[(slug.length + 1)..] if rest.start_with?("#{slug}_")
          "vepo/#{rest}"
        elsif base.start_with?('kovanie_') && base.end_with?('.csv') then 'hw_csv'
        elsif base.start_with?('Rozpocet') && base.end_with?('.xlsx') then 'budget_xlsx'
        elsif base.start_with?('Cenova') && base.end_with?('.xlsx') then 'offer_xlsx'
        else "other/#{rel}"
        end
      key = "#{key}##{out.keys.count { |k| k.start_with?(key) } + 1}" if out.key?(key)
      out[key] = Item.new(key, p, rel)
    end
    out
  end

  # --- ZIP (centralny adresar; STORE aj DEFLATE) --------------------------------
  def zip_entries(bytes)
    bytes = bytes.b
    eocd = bytes.rindex([0x06054b50].pack('V'))
    raise 'ZIP nema EOCD' unless eocd

    _sig, _d1, _d2, count, _total, _size, cd_off, _cl = bytes[eocd, 22].unpack('VvvvvVVv')
    out = {}
    pos = cd_off
    count.times do
      raise 'ZIP: zly zaznam centralneho adresara' unless bytes[pos, 4] == [0x02014b50].pack('V')

      f = bytes[pos, 46].unpack('VvvvvvvVVVvvvvvVV')
      method, csize = f[4], f[8]
      nlen, xlen, clen, local = f[10], f[11], f[12], f[16]
      name = bytes[pos + 46, nlen].force_encoding('UTF-8')
      l = bytes[local, 30].unpack('VvvvvvVVVvv')
      data = bytes[local + 30 + l[9] + l[10], csize]
      data = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data) if method == 8
      raise "ZIP: nepodporovana metoda #{method}" unless [0, 8].include?(method)

      out[name] = data.b
      pos += 46 + nlen + xlen + clen
    end
    out
  end

  # --- text (VEPO CSV/LOG, CSV kovania) ----------------------------------------
  def norm_text(key, data)
    lines = data.b.split("\n", -1)
    allowed = []
    if key == 'vepo/export.log'
      lines.each_with_index do |l, i|
        next unless l.start_with?(VERZIA) || l.start_with?(DATUM)

        allowed << l.strip
        lines[i] = ALLOWED_MARK
      end
    elsif key == 'hw_csv' && !lines.empty?
      n = lines[0].gsub(STAMP, '<TS>'.b).gsub(DATE_DOT, '<DATUM>'.b)
      allowed << lines[0].strip if n != lines[0]
      lines[0] = n
    end
    [lines, allowed]
  end

  def show(s, n = 160)
    s.to_s.dup.force_encoding('UTF-8').scrub('?').gsub(/[\r\n]+/, ' ').strip[0, n]
  end

  def cmp_text(key, a, b)
    da = File.binread(a)
    db = File.binread(b)
    return [:ok, 'bajtovo zhodne', []] if da == db

    la, aa = norm_text(key, da)
    lb, ab = norm_text(key, db)
    if la == lb
      return [:ok, "povolene: K [#{show(aa.join(' | '))}] -> P [#{show(ab.join(' | '))}]", []]
    end

    diffs = []
    [la.length, lb.length].max.times do |i|
      next if la[i] == lb[i]

      diffs << "riadok #{i + 1}: K [#{show(la[i])}] != P [#{show(lb[i])}]"
    end
    diffs << "pocet riadkov: K #{la.length} != P #{lb.length}" if la.length != lb.length
    [:diff, 'text sa lisi', diffs.first(MAX_DIFFS)]
  end

  def cmp_xlsx(a, b)
    ba = File.binread(a)
    bb = File.binread(b)
    return [:ok, 'bajtovo zhodne', []] if ba == bb

    za = zip_entries(ba)
    zb = zip_entries(bb)
    diffs = []
    (za.keys - zb.keys).each { |n| diffs << "cast #{n} chyba v P" }
    (zb.keys - za.keys).each { |n| diffs << "cast #{n} chyba v K" }
    allowed = []
    (za.keys & zb.keys).each do |n|
      x = za[n]
      y = zb[n]
      next if x == y

      if n.start_with?('xl/worksheets/')
        # Povolene LEN vygenerovane datum v titulku harka (`BudgetXlsx.title` / `CpXlsx.title`:
        # "... - AKT. d.m. rrrr" / "... - AKT. d.m.rrrr" z Time.now) — beh cez polnoc.
        x = x.gsub(SHEET_TITLE_DATE, '\1<DATUM>'.b)
        y = y.gsub(SHEET_TITLE_DATE, '\1<DATUM>'.b)
        if x == y
          allowed << n
          next
        end
      end
      i = (0...[x.length, y.length].min).find { |k| x.getbyte(k) != y.getbyte(k) } || [x.length, y.length].min
      diffs << "#{n}: bajt #{i} K [#{show(x[[i - 30, 0].max, 70])}] != P [#{show(y[[i - 30, 0].max, 70])}]"
    end
    return [:diff, 'obsah XLSX sa lisi', diffs.first(MAX_DIFFS)] unless diffs.empty?

    return [:ok, "casti XLSX zhodne; povolene: datum v titulku harka (#{allowed.join(', ')})", []] unless allowed.empty?

    [:ok, 'casti XLSX zhodne (ZIP hlavicky = cas zapisu)', []]
  rescue StandardError => e
    [:diff, 'XLSX sa neda precitat', ["#{e.class}: #{e.message}"]]
  end

  # --- porovnanie stromov -----------------------------------------------------------
  # -> [Row, ...]; zhoda = ziadny Row s verdictom :diff.
  def compare_trees(k_root, p_root, exclude: [])
    k = classify(k_root, exclude: exclude)
    p = classify(p_root, exclude: exclude)
    rows = []
    (k.keys | p.keys).sort.each do |key|
      unless k.key?(key) && p.key?(key)
        rows << Row.new(:diff, key, "chyba v #{k.key?(key) ? 'P' : 'K'}", [])
        next
      end
      v, note, details = k[key].name.end_with?('.xlsx') ? cmp_xlsx(k[key].path, p[key].path) : cmp_text(key, k[key].path, p[key].path)
      if norm_name(k[key].name) != norm_name(p[key].name)
        v = :diff
        details = ["nazov suboru: K [#{show(k[key].name)}] != P [#{show(p[key].name)}]"] + details
      end
      rows << Row.new(v, key, note, details)
    end
    rows << Row.new(:diff, '(prazdne)', 'ani K ani P nevytvorili ziadny subor', []) if k.empty? && p.empty?
    rows
  end

  # --- log sondy (STATUS / REPUSH / PICKER / FAIL) ----------------------------------
  # -> { 'do_export' => [ [druh, hodnota...], ... ] } v poradi, ako udalosti nastali.
  def parse_log(text)
    ev = Hash.new { |h, m| h[m] = [] }
    text.to_s.dup.force_encoding('UTF-8').each_line do |line|
      kind, json = line.chomp.split(' ', 2)
      next unless %w[STATUS REPUSH PICKER].include?(kind)

      d = JSON.parse(json)
      case kind
      when 'STATUS' then ev[d['m']] << ['status', d['err'] ? 'CERVENA' : 'bezna', d['msg'].to_s]
      when 'REPUSH' then ev[d['m']] << ['repush']
      when 'PICKER' then ev[d['m']] << ['picker', d['api'].to_s, "start=#{d['start'].inspect}", "meno=#{d['name'].inspect}"]
      end
    rescue JSON::ParserError
      next
    end
    ev
  end

  def log_failures(text)
    text.to_s.dup.force_encoding('UTF-8').lines.map(&:chomp).select { |l| l.start_with?('FAIL:') }
  end

  def norm_event(ev, dirs)
    ev.map do |part|
      s = part.to_s
      dirs.sort_by { |d| -d.to_s.length }.each do |d|
        next if d.to_s.empty?

        [d.to_s, d.to_s.tr('/', '\\'), d.to_s.tr('\\', '/')].uniq.each { |v| s = s.gsub(v, '<DIR>') }
      end
      norm_name(s)
    end
  end

  # Vety statusu (a volania pickera/repush) 4 exportov, cesty sa normalizuju.
  # `k_dirs`/`p_dirs` = priecinky, ktorych cesty sa v vetach nahradia (vystup, praca).
  def compare_status(k_text, p_text, k_dirs, p_dirs)
    ke = parse_log(k_text)
    pe = parse_log(p_text)
    METHODS.map do |m|
      kn = (ke[m] || []).map { |e| norm_event(e, k_dirs) }
      pn = (pe[m] || []).map { |e| norm_event(e, p_dirs) }
      shown = kn.map { |e| e.join(' | ') }
      if kn.empty? && pn.empty?
        Row.new(:diff, m, 'ziadna udalost v K ani v P (export nebezal)', [])
      elsif kn == pn
        Row.new(:ok, m, "#{kn.length} udalost(i) zhodne", shown.map { |s| "K=P: #{show(s)}" })
      else
        d = ["K: #{kn.map { |e| e.join(' | ') }.join(' // ')}", "P: #{pn.map { |e| e.join(' | ') }.join(' // ')}"]
        Row.new(:diff, m, 'vety/udalosti sa lisia', d.map { |s| show(s, 600) })
      end
    end
  end

  def format_rows(rows, title)
    out = ["--- #{title} ---"]
    rows.each do |r|
      out << format('%-5s %-34s %s', r.verdict == :ok ? 'OK' : 'DIFF', r.key, r.note)
      r.details.each { |d| out << "        #{d}" }
    end
    out
  end

  def ok?(rows)
    rows.none? { |r| r.verdict == :diff }
  end

  def main(argv)
    a = argv.dup
    exclude = []
    opts = {}
    while (i = a.index { |x| x.start_with?('--') })
      flag = a.delete_at(i)
      val = a.delete_at(i)
      if flag == '--exclude-input' then exclude << val
      else opts[flag] = val
      end
    end
    k_root, p_root = a
    abort 'Pouzitie: ruby export_compare.rb K P [--exclude-input meno] [--log-k f --log-p f] [--out f]' unless k_root && p_root

    lines = []
    rows = compare_trees(k_root, p_root, exclude: exclude)
    lines.concat(format_rows(rows, 'subory vystupov'))
    all_ok = ok?(rows)
    if opts['--log-k'] && opts['--log-p']
      srows = compare_status(File.binread(opts['--log-k']), File.binread(opts['--log-p']),
                             [k_root, File.dirname(opts['--log-k'])], [p_root, File.dirname(opts['--log-p'])])
      lines.concat(format_rows(srows, 'vety statusu a volania pickera'))
      all_ok &&= ok?(srows)
    end
    lines << "VERDIKT: #{all_ok ? 'P == K' : 'P != K'}"
    text = lines.join("\n") + "\n"
    File.binwrite(opts['--out'], text) if opts['--out']
    $stdout.binmode
    $stdout.write(text)
    all_ok ? 0 : 1
  end
end

exit(ExportCompare.main(ARGV)) if $PROGRAM_NAME == __FILE__
