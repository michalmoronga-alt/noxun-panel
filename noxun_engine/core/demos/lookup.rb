# frozen_string_literal: true
# Noxun Engine — V0.6 B-2a: orchestrator Demos lookupu dekorovej skupiny
# (sitemap -> slug match -> fetch KAZDEHO variantu -> verify -> proposal).
#
# Kontrakty z auditu B-2 (1.8.2026):
#   - related riadky stranky NIE SU autorita zapisu (BLOCKER 3) — kod a cena
#     sa navrhuju VYHRADNE z fetchnutej a overenej stranky KONKRETNEHO zaznamu;
#     related sa zbiera len ako informacne "prislusenstvo" (ziadne auto-create).
#   - verify (BLOCKER 2) = slug score FINALNEJ URL (typ prefix, poradie
#     dekorov zasteny, ABS sirka+hrubka) A ZAROVEN identity_match? parametrov.
#   - alive.call PRED kazdym dalsim async krokom (BLOCKER 5 / FIX 7): cancel
#     alebo zatvorene okno zastavi buduce fetchy (bezaci request dobehne do
#     prazdna) a MRTVY volajuci nedostane uz ZIADEN event, ani complete.
#   - terminalny event {'type'=>'complete'} presne RAZ + watchdog (FIX 9) —
#     klient nema HTTP timeout, visiaci request nesmie visiet aj v UI.
#   - sitemap single-flight (FIX 8): stale cache sa pouzije HNED + bezi max
#     jeden zdielany background refresh; bez cache sa caka na jediny refresh.
#   - manualna URL NEZAVISI od sitemap (FIX 13) — priama cesta fetch+verify.
#   - lookup NIC nezapisuje — navrhy aplikuje az Materials.apply_demos_batch.
#
# Eventy (emit.call(hash), vsetko string kluce):
#   {'type'=>'sitemap','state'=>'refreshing'}
#   {'type'=>'proposal','proposal'=>{...}}
#   {'type'=>'progress','done'=>i,'total'=>n}
#   {'type'=>'complete','ok'=>bool,'error'=>String|nil,'warnings'=>[],
#    'accessories'=>[{'name','code','url','unit','price_vat'}]}
#
# Proposal statusy: match | miss | ambiguous | identity_fail | fetch_error |
# skipped_duplak | no_width | unsupported.

module Noxun
  module Engine
    module DemosLookup
      # Watchdog medzi async krokmi (fetch + throttle 3 s je bezne ~5-10 s;
      # 45 s bez pohybu = nieco visi a UI potrebuje terminalny stav).
      WATCHDOG_S = 45

      module_function

      # records: pole katalogovych zaznamov skupiny (sheets aj edges).
      # alive: proc -> bool (session token okna — autorita zivotnosti).
      # emit: proc(event) — vola sa LEN kym alive vracia true.
      def run(records, alive:, emit:)
        ctx = new_ctx(alive, emit)
        # GH #97 P1: vyrobca je sucast identity skupiny (standard 7.1 — skupina
        # = vyrobca + cislo dekoru). Odvodi sa zo sheet zaznamov skupiny (ABS
        # pasky pole nemaju) a overuje sa proti itemprop brand stranky.
        ctx['manufacturer'] = Array(records).map { |r| r['manufacturer'].to_s.strip }
                                            .find { |m| !m.empty? }
        pre = []
        work = []
        Array(records).each do |rec|
          kind = rec['abs_id'].to_s.empty? ? 'sheet' : 'edge'
          if (skip = skip_reason(rec, kind))
            pre << base_proposal(rec, kind).merge('status' => skip[0], 'warnings' => [skip[1]])
          else
            work << [rec, kind]
          end
        end
        # GH #97 P2: vsetko preskocene = ziadna URL netreba — complete HNED,
        # bez sitemap (fresh install by zbytocne stahoval 9,5 MB a pripadny
        # nesuvisiaci fail refreshu by zhodil ok=false).
        if work.empty?
          pre.each { |p| deliver_proposal(ctx, p) }
          return complete(ctx, true, nil)
        end
        ensure_urls(ctx) do |urls, stale_warning, err|
          next unless ctx['alive'].call
          ctx['warnings'] << stale_warning if stale_warning
          pre.each { |p| deliver_proposal(ctx, p) }
          next complete(ctx, false, err || 'zoznam produktov Demosu nie je k dispozícii') unless urls
          queue = []
          work.each do |rec, kind|
            m = DemosSlugMatcher.match(rec, urls)
            case m['status']
            when 'match'
              queue << [rec, kind, m['url']]
            when 'ambiguous'
              deliver_proposal(ctx, base_proposal(rec, kind)
                .merge('status' => 'ambiguous', 'candidates' => Array(m['candidates'])))
            else
              deliver_proposal(ctx, base_proposal(rec, kind).merge('status' => 'miss'))
            end
          end
          ctx['total'] = queue.length
          fetch_chain(ctx, queue)
        end
        true
      end

      # Manualna URL pre JEDEN zaznam (fallback pri miss/ambiguous). Ziadna
      # sitemap — sanitize + fetch + PLNE verify (slug finalnej URL musi sediet
      # s identitou zaznamu rovnako tvrdo ako pri automatickom matchi).
      # manufacturer: vyrobca SKUPINY (ABS zaznam ho nenesie — dodava volajuci,
      # ktory skupinu pozna); nil = zaznam/skupina bez vyrobcu, brand sa neoveri.
      def manual(rec, url, alive:, emit:, manufacturer: nil)
        ctx = new_ctx(alive, emit)
        ctx['manufacturer'] = manufacturer.to_s.strip.empty? ? rec['manufacturer'].to_s.strip : manufacturer.to_s.strip
        ctx['manufacturer'] = nil if ctx['manufacturer'].empty?
        kind = rec['abs_id'].to_s.empty? ? 'sheet' : 'edge'
        if (skip = skip_reason(rec, kind))
          deliver_proposal(ctx, base_proposal(rec, kind).merge('status' => skip[0], 'warnings' => [skip[1]]))
          return complete(ctx, true, nil)
        end
        clean, err = Demos.sanitize_url(url)
        unless clean
          deliver_proposal(ctx, base_proposal(rec, kind).merge('status' => 'fetch_error', 'warnings' => [err.to_s]))
          return complete(ctx, true, nil)
        end
        ctx['total'] = 1
        fetch_chain(ctx, [[rec, kind, clean]])
        true
      end

      # --- pre-guardy zaznamov -------------------------------------------------

      # [status, hlaska] alebo nil (zaznam sa spracuje). Duplak sa nenakupuje;
      # ABS bez sirky nema jednoznacny Demos variant (BLOCKER 2 — ziadne auto
      # parovanie legacy pasok); typ mimo TYPE_PREFIXES sa neda dokazat v slugu
      # (BLOCKER 2/3 — plati aj pre manualnu URL).
      def skip_reason(rec, kind)
        if kind == 'sheet' && Materials.duplak?(rec)
          ['skipped_duplak', 'duplák — nakupuje a oceňuje sa zdrojová doska']
        elsif kind == 'edge' && rec['width'].to_f <= 0
          ['no_width', 'ABS páska bez šírky sa nedá bezpečne spárovať — doplň šírku variantu']
        elsif kind == 'sheet' && DemosSlugMatcher::TYPE_PREFIXES[Materials.identity_norm(rec['type'])].nil?
          ['unsupported', "typ „#{rec['type']}“ sa nedá overiť voči Demosu"]
        end
      end

      # --- sitemap (single-flight) --------------------------------------------

      # yield(urls|nil, stale_warning|nil, error|nil)
      def ensure_urls(ctx)
        cache = DemosSitemapCache.load
        if cache
          warning = nil
          if DemosSitemapCache.stale?
            warning = 'zoznam produktov Demosu je starší ako 7 dní — obnovuje sa na pozadí'
            start_refresh { |_ok, _err| } # background; vysledok pouzije dalsi lookup
          end
          yield(cache['urls'], warning, nil)
          return
        end
        deliver(ctx, 'type' => 'sitemap', 'state' => 'refreshing')
        reset_watchdog(ctx)
        start_refresh do |ok, err|
          reset_watchdog(ctx)
          if ok
            yield(DemosSitemapCache.urls, nil, nil)
          else
            yield(nil, nil, "sitemap Demosu: #{err}")
          end
        end
      end

      # Jediny zdielany refresh — dalsi zaujemca sa PRIPOJI k bezajucemu
      # (FIX 8: rychle opakovanie lookupu nesmie spustit paralelne retaze
      # child sitemapov; throttle by ich zbytocne serializoval na minuty).
      def start_refresh(&done)
        @refresh_waiters ||= []
        @refresh_waiters << done
        return true if @refreshing
        @refreshing = true
        DemosSitemapCache.refresh! do |res|
          @refreshing = false
          waiters = @refresh_waiters || []
          @refresh_waiters = []
          waiters.each do |w|
            begin
              w.call(res['ok'] == true, res['error'])
            rescue StandardError => e
              Engine.log_error(e, 'DemosLookup.refresh waiter') if defined?(Engine)
            end
          end
        end
        true
      end

      # Test-only reset zdielaneho refresh stavu (module premenne preziju
      # medzi testami — bez resetu by druhy test cakal na neexistujuci beh).
      def refresh_state_reset!
        @refreshing = false
        @refresh_waiters = []
      end

      # --- fetch retaz ---------------------------------------------------------

      # Sekvencne (throttle 3 s ma zmysel len v rade); alive sa kontroluje PRED
      # kazdym dalsim fetchom — cancel znamena ziadne dalsie requesty.
      # GH #97 P2: 'completed' (watchdog timeout uz ohlasil koniec) zastavuje
      # retaz ROVNAKO ako mrtvy alive — neskoro dosla odpoved visiaceho
      # requestu nesmie potichu rozbehnut zvysne fetche popri novom pokuse.
      def fetch_chain(ctx, queue)
        return if ctx['completed']
        return complete(ctx, true, nil) if queue.empty?
        return unless ctx['alive'].call
        rec, kind, url = queue.shift
        reset_watchdog(ctx)
        Demos.fetch(url) do |res|
          next if ctx['completed']
          next unless ctx['alive'].call
          reset_watchdog(ctx)
          deliver_proposal(ctx, proposal_from_fetch(ctx, rec, kind, res))
          ctx['done'] += 1
          deliver(ctx, 'type' => 'progress', 'done' => ctx['done'], 'total' => ctx['total'])
          fetch_chain(ctx, queue)
        end
      end

      def proposal_from_fetch(ctx, rec, kind, res)
        p = base_proposal(rec, kind)
        unless res['ok']
          return p.merge('status' => 'fetch_error', 'warnings' => [res['error'].to_s])
        end
        parsed = DemosProductParser.parse(res['body'])
        final_url = res['url'].to_s
        unless parsed['ok'] && verified?(ctx, rec, kind, parsed, final_url)
          return p.merge('status' => 'identity_fail', 'url' => final_url,
                         'warnings' => Array(parsed['warnings']) +
                                       ['stránka nesedí s identitou záznamu — kód a cena sa nepreberajú'])
        end
        collect_accessories(ctx, parsed)
        build_proposal(ctx, p, rec, kind, parsed, final_url)
      end

      # BLOCKER 2: kind-aware plna identita. Slug FINALNEJ URL (po redirectoch)
      # dokazuje typ prefix, poradie dekorov zasteny, format v identite a ABS
      # sirku+hrubku; identity_match? dokazuje parametre stranky (dekor,
      # struktura, hrubka, format). Pri ABS sa navyse porovna sirka z tabulky
      # parametrov, ak ju stranka uvadza (slug ostava autoritou).
      # GH #97 P1: vyrobca — skupina S vyrobcom vyzaduje ZHODNY brand stranky
      # (H3303 existuje u Eggera aj inde; cislo dekoru bez vyrobcu nie je
      # identita, standard 7.1). Chybajuci brand pri zaznamenom vyrobcovi =
      # NIE zhoda (vzor identity_match? — chybajuci komponent nie je dokaz).
      def verified?(ctx, rec, kind, parsed, final_url)
        slug = DemosSlugMatcher.slug_of(final_url)
        toks = DemosSlugMatcher.record_tokens(rec)
        return false unless DemosSlugMatcher.score(slug, toks)
        return false unless DemosProductParser.identity_match?(parsed, rec)
        if ctx['manufacturer']
          brand = parsed['brand'].to_s
          return false if brand.strip.empty?
          return false unless Materials.identity_norm(brand) == Materials.identity_norm(ctx['manufacturer'])
        end
        if kind == 'edge'
          pw = parsed['params'] && parsed['params']['width']
          return false if pw && (pw.to_f - rec['width'].to_f).abs > 0.011
        end
        true
      end

      def build_proposal(ctx, p, rec, kind, parsed, final_url)
        warnings = Array(parsed['warnings']).dup
        new_price = nil
        if parsed['price_vat']
          fmt = parsed['params'] && parsed['params']['format']
          new_price = DemosProductParser.price_for_catalog(parsed['price_vat'], parsed['unit'], kind, fmt)
          warnings << "cenu v jednotke „#{parsed['unit']}“ sa nepodarilo prepočítať" if new_price.nil?
        elsif parsed['price_no_vat']
          # F9: VAT fallback disabled — prepocet z bez-DPH sa NEROBI.
          warnings << 'stránka má len cenu bez DPH — cena sa nepreberá (katalóg eviduje s DPH)'
        end
        old_price = kind == 'edge' ? rec['price_per_bm'] : rec['price_per_m2']
        code_new = parsed['code'].to_s
        ctx['proposed_codes'][code_new] = true unless code_new.empty?
        p.merge(
          'status' => 'match', 'url' => final_url, 'title' => parsed['title'],
          'code' => { 'old' => rec['code'], 'new' => parsed['code'] },
          'supplier' => { 'old' => rec['supplier'], 'new' => 'Demos' },
          'price' => { 'old' => old_price, 'new' => new_price,
                       'unit_src' => parsed['unit'],
                       'unchanged' => (!new_price.nil? && !old_price.nil? &&
                                       (new_price - old_price.to_f).abs < 0.005) },
          'warnings' => warnings
        )
      end

      # Prislusenstvo = related riadky, ktore NEpatria ziadnemu navrhnutemu
      # zaznamu — LEN informacny zoznam (B7: ziadne auto-create). Dedup kodom.
      def collect_accessories(ctx, parsed)
        Array(parsed['related']).each do |r|
          code = r['code'].to_s
          next if code.empty? || ctx['accessories'].key?(code)
          ctx['accessories'][code] = { 'name' => r['name'], 'code' => code, 'url' => r['url'],
                                       'unit' => r['unit'], 'price_vat' => r['price_vat'] }
        end
      end

      # --- eventy a zivotny cyklus --------------------------------------------

      def new_ctx(alive, emit)
        { 'alive' => alive, 'emit' => emit, 'completed' => false,
          'warnings' => [], 'accessories' => {}, 'proposed_codes' => {},
          'done' => 0, 'total' => 0 }
      end

      def base_proposal(rec, kind)
        id = kind == 'edge' ? rec['abs_id'] : rec['material_id']
        { 'record_id' => id.to_s, 'kind' => kind, 'warnings' => [] }
      end

      def deliver_proposal(ctx, proposal)
        deliver(ctx, 'type' => 'proposal', 'proposal' => proposal)
      end

      def deliver(ctx, event)
        return if ctx['completed']
        return unless ctx['alive'].call
        ctx['emit'].call(event)
      end

      # Presne RAZ; mrtvemu volajucemu sa uz NIC neposiela (return bez emitu
      # completed flag aj tak nastavi — druhy complete je no-op).
      def complete(ctx, ok, error)
        return if ctx['completed']
        ctx['completed'] = true
        stop_watchdog(ctx)
        return unless ctx['alive'].call
        acc = ctx['accessories'].reject { |code, _| ctx['proposed_codes'].key?(code) }
        ctx['emit'].call('type' => 'complete', 'ok' => ok, 'error' => error,
                         'warnings' => ctx['warnings'], 'accessories' => acc.values)
        nil
      end

      # FIX 9: klient nema HTTP timeout — visiaci request by nechal UI bez
      # terminalneho stavu. Timer sa resetuje pri kazdom async kroku; headless
      # testy bezia synchronne (timers_available? false), watchdog sa preskoci.
      def reset_watchdog(ctx)
        stop_watchdog(ctx)
        return if ctx['completed'] || !Demos.timers_available?
        ctx['watchdog'] = UI.start_timer(WATCHDOG_S, false) do
          complete(ctx, false, 'Demos neodpovedá — skús znova o chvíľu')
        end
      end

      def stop_watchdog(ctx)
        id = ctx.delete('watchdog')
        UI.stop_timer(id) if id && defined?(UI) && UI.respond_to?(:stop_timer)
      rescue StandardError
        nil
      end
    end
  end
end
