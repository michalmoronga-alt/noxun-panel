# frozen_string_literal: true
# Noxun Engine — V0.6-B: cache sitemap URL demos-trade.sk.
#
# Sitemap je jedina robots-friendly cesta k produktovym URL (48k zaznamov,
# ~9,5 MB XML). Cache zije v %APPDATA%/NOXUN/Engine/demos_sitemap.json
# (JsonFileStore — atomicky zapis + .bak) a obnovuje sa VYHRADNE na pokyn
# (tlacidlo / lookup miss so suhlasom) — ziadne fetch-e pri boote.
#
# Audit F11: novy cache sa PUBLIKUJE az po uspesnom stiahnuti indexu AJ
# VSETKYCH child sitemap a neprazdnom zozname URL — ciastocny/prazdny
# vysledok stary cache NIKDY neprepise.

module Noxun
  module Engine
    module DemosSitemapCache
      INDEX_URL = 'https://www.demos-trade.sk/content/sitemaps/domain_8_sitemap.xml'
      STALE_AFTER_S = 7 * 24 * 3600
      FILE = 'demos_sitemap.json'

      module_function

      def path
        File.join(Materials.dir, FILE)
      end

      # {'fetched_at' => epoch, 'urls' => [...]} alebo nil (cache neexistuje/vadna).
      def load
        data = JsonFileStore.read(path)
        return nil unless data.is_a?(Hash) && data['urls'].is_a?(Array) && !data['urls'].empty?
        data
      rescue StandardError
        nil
      end

      def urls
        (load || {})['urls'] || []
      end

      def stale?(now = Time.now.to_f)
        data = load
        return true unless data
        (now - data['fetched_at'].to_f) > STALE_AFTER_S
      end

      # Parse <loc> zo sitemap XML (index aj urlset — regex, ziadne XML gemy).
      def locs(xml)
        xml.to_s.scan(%r{<loc>\s*([^<\s][^<]*?)\s*</loc>}).flatten
      end

      # Child sitemapy z indexu (subory .../domain_8_sitemap.N.xml).
      def child_sitemaps(index_xml)
        locs(index_xml).select { |u| u.include?('sitemap') && u.end_with?('.xml') }
      end

      # ASYNC refresh: index -> vsetky child sitemapy -> atomicky publish.
      # done.call('ok' => true, 'count' => n) | ('ok' => false, 'error' => ...)
      # Audit F11: zlyhanie KTOREHOKOLVEK kroku = stary cache ostava.
      # V0.6 M-A (audit F6): progress sa vola po KAZDOM stiahnutom kroku
      # (index aj child) — cely refresh s throttle 3 s/child vie trvat dlhsie
      # nez watchdog lookupu (falosne "Demos neodpoveda" zo zive ho testu 1.8.);
      # volajuci si nim rearmuje watchdog kazdeho cakajuceho kontextu.
      def refresh!(now: Time.now.to_f, progress: nil, &done)
        Demos.fetch(INDEX_URL, limit: :sitemap) do |res|
          unless res['ok']
            next done.call('ok' => false, 'error' => "sitemap index: #{res['error']}")
          end
          children = child_sitemaps(res['body'])
          direct = locs(res['body']) - children
          if children.empty? && direct.empty?
            next done.call('ok' => false, 'error' => 'sitemap index je prázdny — cache ostáva pôvodná')
          end
          safe_progress(progress, 0, children.length)
          collect_children(children, direct, now, done, progress, children.length)
        end
      end

      def safe_progress(progress, done_n, total)
        progress&.call('done' => done_n, 'total' => total)
      rescue StandardError => e
        Engine.log_error(e, 'DemosSitemapCache.progress') if defined?(Engine)
      end

      # Postupne (throttle poradi klient) stiahne child sitemapy; az ked su
      # VSETKY ok, publish. Rekurzia cez async callbacky — ziadne cakanie.
      def collect_children(remaining, urls_acc, now, done, progress = nil, total = nil)
        if remaining.empty?
          products = urls_acc.uniq
          if products.empty?
            return done.call('ok' => false, 'error' => 'sitemap bez URL — cache ostáva pôvodná')
          end
          # GH #96 P2: zapisova chyba (read-only profil, plny disk) RAISNE — bez
          # rescue by ju spolkol HTTP callback wrapper a done by sa NIKDY
          # nezavolal (visiaci refresh bez hlasky).
          ok = begin
            JsonFileStore.write(path, 'fetched_at' => now, 'urls' => products)
          rescue StandardError => e
            Engine.log_error(e, 'DemosSitemapCache.write') if defined?(Engine)
            false
          end
          return done.call('ok' => false, 'error' => 'zápis cache zlyhal — stará cache ostáva') unless ok
          return done.call('ok' => true, 'count' => products.length)
        end
        current = remaining.first
        rest = remaining[1..]
        Demos.fetch(current, limit: :sitemap) do |res|
          unless res['ok']
            next done.call('ok' => false, 'error' => "sitemap #{current}: #{res['error']} — cache ostáva pôvodná")
          end
          if total
            safe_progress(progress, total - rest.length, total)
          end
          collect_children(rest, urls_acc + locs(res['body']), now, done, progress, total)
        end
      end
    end
  end
end
