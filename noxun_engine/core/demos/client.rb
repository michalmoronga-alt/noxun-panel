# frozen_string_literal: true
# Noxun Engine — V0.6-B: siet ovy klient pre demos-trade.sk.
#
# ASYNC kontrakt (audit B1): fetch() NIKDY neblokuje — vysledok pride
# callbackom. V SketchUpe jazdi na Sketchup::Http (jedine povolene API,
# SKETCHUP_PRAVIDLA "Siet a system"; request drzime v registri — GC pasca)
# + UI.start_timer na throttle cakanie. Headless testy dodaju vlastny
# transport (fake) cez Demos.transport= — cista logika guardov/redirectov
# sa testuje bez siete.
#
# Guardy (audit B2/F12):
#   - allowlist hostov {demos-trade.sk, www.demos-trade.sk}, VYHRADNE https
#   - /vyhledavani je ZAKAZANA cesta (robots.txt) — kontrola na vstupe AJ po
#     kazdom redirecte, po normalizacii a percent-decode cesty
#   - redirect max 3, kazdy znovu cez plny guard
#   - Crawl-delay 3 s MEDZIPROCESOVO (flock timestamp subor — 2 SketchUpy
#     nesmu strielat naraz); cakanie async cez timer, nie sleep
#   - limit velkosti odpovede, HTTP status handling (429/5xx bez retry burst)

require 'uri'
require 'fileutils'

module Noxun
  module Engine
    module Demos
      ALLOWED_HOSTS = %w[demos-trade.sk www.demos-trade.sk].freeze
      FORBIDDEN_PATHS = %w[/vyhledavani].freeze
      MAX_REDIRECTS = 3
      CRAWL_DELAY_S = 3.0
      # Produktova stranka ma ~400 kB — 6 MB strop je stedra rezerva; sitemap
      # (realne ~9,5 MB / 48k URL) ma vlastny vyssi strop.
      MAX_BODY_BYTES = 6_000_000
      MAX_SITEMAP_BYTES = 20_000_000

      module_function

      # --- URL guardy (ciste, headless testovatelne) --------------------------

      # Vrati normalizovanu URL (String) alebo [nil, dovod].
      def sanitize_url(raw)
        s = raw.to_s.strip
        return [nil, 'prázdna adresa'] if s.empty?
        begin
          uri = URI.parse(s)
        rescue StandardError
          return [nil, 'neplatná adresa']
        end
        return [nil, 'povolené je len https'] unless uri.is_a?(URI::HTTPS)
        host = uri.host.to_s.downcase
        return [nil, 'adresa nie je z demos-trade.sk'] unless ALLOWED_HOSTS.include?(host)
        path = decoded_path(uri)
        if FORBIDDEN_PATHS.any? { |p| path == p || path.start_with?("#{p}/") || path.start_with?("#{p}?") }
          return [nil, 'vyhľadávanie Demosu sa nesmie volať (robots.txt) — vlož adresu produktu']
        end
        [uri.to_s, nil]
      end

      # Percent-decode + kolaps lomiek + ROZLISENIE dot segmentov (GH #96 P2:
      # /a/../vyhledavani by po normalizacii na origine skoncil na zakazanom
      # endpointe) — guard nesmie obist %2F/%76/%2e zapisy ani "..".
      def decoded_path(uri)
        path = uri.path.to_s
        decoded = path.gsub(/%([0-9a-fA-F]{2})/) { [Regexp.last_match(1)].pack('H2') }
        stack = []
        decoded.squeeze('/').split('/').each do |seg|
          case seg
          when '', '.' then next
          when '..' then stack.pop
          else stack << seg
          end
        end
        "/#{stack.join('/')}".downcase
      end

      # Redirect location -> absolutna URL (relativne dopln z povodnej).
      def resolve_redirect(base_url, location)
        loc = location.to_s.strip
        return nil if loc.empty?
        return loc if loc.match?(%r{\Ahttps?://})
        base = URI.parse(base_url)
        if loc.start_with?('/')
          "#{base.scheme}://#{base.host}#{loc}"
        else
          "#{base.scheme}://#{base.host}#{File.dirname(base.path)}/#{loc}"
        end
      rescue StandardError
        nil
      end

      # --- transport (SketchUp vs test) ---------------------------------------
      # transport = objekt s #start(url, limit_bytes) { |status, headers, body, err| }
      # (async; callback pride na main threade). V testoch fake.

      def transport=(t)
        @transport = t
      end

      def transport
        @transport ||= sketchup_transport
      end

      def sketchup_transport
        return nil unless defined?(Sketchup::Http)
        SketchupTransport.new
      end

      # Drzi referencie requestov (GC pasca) a mapuje na Sketchup::Http.
      class SketchupTransport
        def initialize
          @live = {}
          @seq = 0
        end

        def start(url, limit_bytes)
          @seq += 1
          id = @seq
          req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
          req.headers = { 'User-Agent' => Demos.user_agent }
          @live[id] = req
          req.start do |request, response|
            @live.delete(id)
            body = response ? response.body.to_s : ''
            if limit_bytes && body.bytesize > limit_bytes
              yield(nil, {}, nil, 'odpoveď je príliš veľká')
            else
              yield(response&.status_code, response_headers(response), body, nil)
            end
          rescue StandardError => e
            Engine.log_error(e, 'Demos.transport') if defined?(Engine)
          end
          true
        rescue StandardError => e
          @live.delete(id)
          yield(nil, {}, nil, "request zlyhal: #{e.message}")
          false
        end

        def response_headers(response)
          h = {}
          return h unless response.respond_to?(:headers) && response.headers
          response.headers.each { |k, v| h[k.to_s.downcase] = v.to_s }
          h
        end
      end

      def user_agent
        "NoxunEngine/#{defined?(Engine::VERSION) ? Engine::VERSION : 'dev'} (SketchUp plugin; kontakt: michalmoronga@gmail.com)"
      end

      # --- throttle (medziprocesovy, flock vzor katalogu) ---------------------

      def throttle_path
        File.join(Materials.dir, 'demos_throttle.lock')
      end

      # Vrati 0.0 (mozes hned) alebo pocet sekund, kolko treba pockat.
      # Zapise CAS PLANOVANEHO requestu uz teraz (rezervacia slotu) — dve okna/
      # procesy tak dostanu po sebe iduce sloty.
      def reserve_slot!(now = monotonic_now)
        FileUtils.mkdir_p(File.dirname(throttle_path))
        File.open(throttle_path, File::RDWR | File::CREAT, 0o644) do |f|
          f.flock(File::LOCK_EX)
          last = f.read.to_s.strip.to_f
          slot = [now, last + CRAWL_DELAY_S].max
          f.rewind
          f.truncate(0)
          f.write(format('%.3f', slot))
          f.flush
          [slot - now, 0.0].max
        end
      rescue StandardError => e
        Engine.log_error(e, 'Demos.reserve_slot!') if defined?(Engine)
        0.0
      end

      # Wall-clock (zdielany medzi procesmi — monotonic nie je medziprocesovo
      # porovnatelny; NTP skoky su pri 3 s tolerancii prijatelne).
      def monotonic_now
        Time.now.to_f
      end

      # --- fetch (async, redirecty, guardy) -----------------------------------

      # fetch(url) { |result| } — result: {'ok'=>bool, 'status'=>Int|nil,
      # 'body'=>String|nil, 'url'=>final, 'error'=>String|nil}
      # limit: :page | :sitemap (velkostny strop).
      def fetch(url, limit: :page, redirects_left: MAX_REDIRECTS, &block)
        clean, err = sanitize_url(url)
        return finish(block, 'ok' => false, 'url' => url.to_s, 'error' => err) unless clean
        t = transport
        return finish(block, 'ok' => false, 'url' => clean, 'error' => 'sieťový transport nie je dostupný') unless t
        start_when_slot_free(t, clean, limit, redirects_left, block)
        true
      end

      # GH #96 P2: rezervovany slot sa pri ODPALENI timera znovu overi — busy
      # UI thread vie nahromadene timery vystrelit naraz a bez re-checku by
      # requesty isli burstom pod crawl-delay. Realny start caka, kym nadide
      # JEHO slot (wall clock), pripadne sa preplanuje o zvysok.
      def start_when_slot_free(t, url, limit, redirects_left, block, slot_at = nil)
        now = monotonic_now
        slot_at ||= now + reserve_slot!(now)
        remaining = slot_at - now
        # Cakat sa da len s UI timerom (SketchUp); headless testy startuju hned
        # (fake transport, throttle aritmetiku kryje vlastny test).
        if remaining > 0.05 && timers_available?
          run_after(remaining) { start_when_slot_free(t, url, limit, redirects_left, block, slot_at) }
          return
        end
        bytes = limit == :sitemap ? MAX_SITEMAP_BYTES : MAX_BODY_BYTES
        t.start(url, bytes) do |status, headers, body, terr|
          handle_response(url, status, headers, body, terr, limit, redirects_left, block)
        end
      end

      def timers_available?
        defined?(UI) && UI.respond_to?(:start_timer)
      end

      def handle_response(url, status, headers, body, terr, limit, redirects_left, block)
        return finish(block, 'ok' => false, 'url' => url, 'error' => terr) if terr
        case status
        when 200
          finish(block, 'ok' => true, 'status' => status, 'url' => url, 'body' => body)
        when 301, 302, 303, 307, 308
          if redirects_left <= 0
            return finish(block, 'ok' => false, 'status' => status, 'url' => url, 'error' => 'priveľa presmerovaní')
          end
          loc = resolve_redirect(url, headers['location'])
          return finish(block, 'ok' => false, 'status' => status, 'url' => url, 'error' => 'presmerovanie bez cieľa') unless loc
          fetch(loc, limit: limit, redirects_left: redirects_left - 1, &block)
        when 429
          finish(block, 'ok' => false, 'status' => status, 'url' => url,
                 'error' => 'server žiada spomaliť (429) — skús o chvíľu')
        when nil
          finish(block, 'ok' => false, 'url' => url, 'error' => 'bez odpovede')
        else
          finish(block, 'ok' => false, 'status' => status, 'url' => url, 'error' => "HTTP #{status}")
        end
      end

      def finish(block, result)
        block.call(result)
        nil
      end

      # Async cakanie: SketchUp UI.start_timer; headless (testy) synchronne.
      def run_after(seconds)
        if seconds.positive? && timers_available?
          UI.start_timer(seconds, false) { yield }
        else
          yield
        end
      end
    end
  end
end
