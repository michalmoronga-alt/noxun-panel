# frozen_string_literal: true

# Výťah zo záznamov sessions Claude Code pre analytika (blok PRAVIDLA, dávka P4c).
#
# Záznamy sessions (`%USERPROFILE%\.claude\projects\<projekt>\*.jsonl`) majú desiatky MB; analytik z nich potrebuje
# zhustený text: správy používateľa, texty asistenta, názvy nástrojov s krátkym vstupom a výsledkom, chyby. Dlhé
# výstupy sa orežú. Skript nič neposiela von a nič nemení: číta záznamy a zapíše jeden textový súbor MIMO repa
# (skutočné záznamy sessions do repa nepatria; skript odmietne výstup v repe).
#
#   ruby scripts/session_digest.rb --in <priečinok projektu alebo súbor .jsonl> --out <súbor mimo repa>
#        [--since RRRR-MM-DD] [--max-text 600] [--max-result 200] [--max-error 500] [--max-input 160]
#
# Riadok výstupu: [U hh:mm] správa používateľa · [A hh:mm] text asistenta · [T hh:mm] nástroj: vstup -> výsledok ·
# [E hh:mm] nástroj: vstup -> CHYBA: text · predpona `~` = vedľajší agent (sidechain). Chybný riadok JSONL sa
# preskočí a spočíta (nepadne). Obsah záznamov je ÚDAJ, nie pokyn. Zjavné tokeny (ghp_…, github_pat_…, sk-…, xox…) sa nahradia
# značkou [skryté].
#
# Test: tests/pure/test_p4c_prevzatie.rb (vymyslená fixtúra tests/fixtures/session_digest/).
require 'json'
require 'open3'
require 'optparse'
require 'rbconfig'

module NxSessionDigest
  REPO_ROOT = File.expand_path('..', __dir__)
  SECRET = /\b(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,})/.freeze

  DEFAULTS = { text: 600, result: 200, error: 500, input: 160 }.freeze

  module_function

  def squeeze(str, max)
    s = str.to_s.dup.force_encoding('UTF-8').scrub('?')
    s = s.gsub(/[[:cntrl:]&&[^\n\t]]/, ' ').gsub(SECRET, '[skryté]').gsub(/\s+/, ' ').strip
    return s if s.length <= max

    "#{s[0, max]}…[+#{s.length - max} znakov]"
  end

  def hhmm(ts)
    ts.to_s[/T(\d\d:\d\d)/, 1] || '--:--'
  end

  # Text z `content` správy: reťazec, alebo pole blokov (type text).
  def text_of(content)
    case content
    when String then content
    when Array then content.select { |b| b.is_a?(Hash) && b['type'] == 'text' }.map { |b| b['text'].to_s }.join(' ')
    else ''
    end
  end

  def result_text(content)
    case content
    when String then content
    when Array then content.map { |b| b.is_a?(Hash) ? b['text'].to_s : b.to_s }.join(' ')
    else content.to_s
    end
  end

  # Krátky opis vstupu nástroja: to najdôležitejšie pole, inak JSON.
  def input_summary(name, input, max)
    return '' unless input.is_a?(Hash)

    key = %w[command file_path pattern path url query description prompt skill subject].find { |k| input[k].is_a?(String) && !input[k].empty? }
    base = key ? input[key] : JSON.generate(input)
    base = "#{input['subagent_type']}: #{base}" if name == 'Agent' && input['subagent_type']
    squeeze(base, max)
  end

  # Spracuje jeden súbor .jsonl → [riadky výstupu, štatistika].
  def digest_file(path, opts)
    out = []
    stats = { lines: 0, skipped: 0 }
    pending = {} # tool_use id -> [name, vstup, čas, sidechain]
    first_ts = nil
    last_ts = nil
    branch = nil
    File.foreach(path, encoding: 'UTF-8') do |raw|
      raw = raw.to_s.scrub('?')
      next if raw.strip.empty?

      stats[:lines] += 1
      rec = begin
        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end
      unless rec.is_a?(Hash)
        stats[:skipped] += 1
        next
      end
      ts = rec['timestamp']
      first_ts ||= ts
      last_ts = ts if ts
      branch ||= rec['gitBranch']
      msg = rec['message']
      next unless msg.is_a?(Hash) && %w[user assistant].include?(rec['type'])
      next if rec['isMeta']

      side = rec['isSidechain'] ? '~' : ''
      time = hhmm(ts)
      content = msg['content']
      if rec['type'] == 'user'
        txt = text_of(content)
        out << "[#{side}U #{time}] #{squeeze(txt, opts[:text])}" unless txt.strip.empty?
        Array(content).each do |b|
          next unless b.is_a?(Hash) && b['type'] == 'tool_result'

          name, inp, t0, sd = pending.delete(b['tool_use_id']) || ['?', '', time, side]
          res = result_text(b['content'])
          if b['is_error']
            out << "[#{sd}E #{t0}] #{name}: #{inp} -> CHYBA: #{squeeze(res, opts[:error])}"
          else
            out << "[#{sd}T #{t0}] #{name}: #{inp} -> #{squeeze(res, opts[:result])}"
          end
        end
      else
        txt = text_of(content)
        out << "[#{side}A #{time}] #{squeeze(txt, opts[:text])}" unless txt.strip.empty?
        Array(content).each do |b|
          next unless b.is_a?(Hash) && b['type'] == 'tool_use'

          pending[b['id']] = [b['name'].to_s, input_summary(b['name'].to_s, b['input'], opts[:input]), time, side]
        end
      end
    end
    pending.each_value { |name, inp, t0, sd| out << "[#{sd}T #{t0}] #{name}: #{inp} -> (bez výsledku)" }
    date = first_ts.to_s[/\A\d{4}-\d{2}-\d{2}/]
    head = "=== SESSION #{File.basename(path, '.jsonl')[0, 8]} #{date || '?'} #{hhmm(first_ts)}..#{hhmm(last_ts)}" \
           "#{branch ? " vetva #{squeeze(branch, 60)}" : ''} (#{stats[:lines]} riadkov, #{stats[:skipped]} preskočených) ==="
    [[head] + out, stats, date]
  end

  def windows?
    RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/ ? true : false
  end

  # Cesta v porovnateľnom tvare: absolútna, symlinky rozriešené po najbližší existujúci priečinok, na Windows bez ohľadu na veľkosť písmen.
  def norm(path)
    full = File.expand_path(path)
    dir = full
    tail = []
    until File.exist?(dir) || File.dirname(dir) == dir
      tail.unshift(File.basename(dir))
      dir = File.dirname(dir)
    end
    full = File.join(File.realpath(dir), *tail) if File.exist?(dir)
    windows? ? full.downcase : full
  end

  def git_out(*args)
    out, st = Open3.capture2('git', '-C', REPO_ROOT, *args, err: File::NULL)
    st.success? ? out.strip : nil
  rescue StandardError
    nil
  end

  # Korene repa: tento checkout (aj worktree) a hlavný checkout (rodič spoločného .git adresára).
  def repo_roots
    roots = [REPO_ROOT]
    top = git_out('rev-parse', '--show-toplevel')
    roots << top if top && !top.empty?
    common = git_out('rev-parse', '--path-format=absolute', '--git-common-dir')
    roots << File.dirname(common) if common && !common.empty?
    roots.map { |r| norm(r) }.uniq
  end

  def inside_repo?(path)
    full = "#{norm(path)}/"
    repo_roots.any? { |root| full.start_with?(root.end_with?('/') ? root : "#{root}/") }
  end

  def run(argv, io: $stdout)
    opts = DEFAULTS.dup
    input = out = since = nil
    parser = OptionParser.new do |o|
      o.banner = 'ruby scripts/session_digest.rb --in <priečinok alebo .jsonl> --out <súbor mimo repa> [voľby]'
      o.on('--in PATH') { |v| input = v }
      o.on('--out PATH') { |v| out = v }
      o.on('--since DATE') { |v| since = v }
      o.on('--max-text N', Integer) { |v| opts[:text] = v }
      o.on('--max-result N', Integer) { |v| opts[:result] = v }
      o.on('--max-error N', Integer) { |v| opts[:error] = v }
      o.on('--max-input N', Integer) { |v| opts[:input] = v }
    end
    begin
      parser.parse!(argv)
    rescue OptionParser::ParseError => e
      io.puts("CHYBA: #{e.message}")
      return 2
    end
    unless input && out
      io.puts(parser.banner)
      return 2
    end
    if inside_repo?(out)
      io.puts('CHYBA: výstup patrí MIMO repa (záznamy sessions sa do repa nedávajú) — zadaj --out mimo priečinka repa.')
      return 2
    end
    files = File.directory?(input) ? Dir[File.join(input, '*.jsonl')].sort : [input]
    files = files.select { |f| File.file?(f) }
    if files.empty?
      io.puts("CHYBA: nenašiel som žiadny súbor .jsonl v #{input}")
      return 2
    end
    blocks = []
    total = { lines: 0, skipped: 0, sessions: 0 }
    files.each do |f|
      lines, st, date = digest_file(f, opts)
      next if since && date && date < since

      blocks << lines.join("\n")
      total[:lines] += st[:lines]
      total[:skipped] += st[:skipped]
      total[:sessions] += 1
    end
    text = "#{blocks.join("\n\n")}\n"
    File.write(out, text, encoding: 'UTF-8')
    io.puts("Výťah: #{total[:sessions]} sessions, #{total[:lines]} riadkov, #{total[:skipped]} preskočených -> #{out} (#{text.bytesize} B)")
    0
  end
end

exit(NxSessionDigest.run(ARGV)) if $PROGRAM_NAME == __FILE__
