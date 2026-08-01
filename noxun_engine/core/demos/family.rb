# frozen_string_literal: true
# Noxun Engine — V0.6 M-A: rodina dekoru z produktovej stranky Demosu
# (1 fetch -> hlavicka + klasifikovane polozky) a orchestrator zalozenia
# skupiny (sekvencne fetche vybranych poloziek -> 1 atomicky zapis).
#
# Kontrakty (audit M-A 1.8.2026):
#   - BLOCKER 2: polozky drzi SERVER (family store v dialogu) — klient posiela
#     len iid vybranych poloziek; URL sa nikdy neberie z klienta.
#   - FIX 7: slug je LEN kandidat na klasifikaciu/zobrazenie. Zapisovane
#     parametre sa beru z PARSOVANEJ finalnej stranky kazdej polozky; vynimkou
#     je sirka+hrubka ABS zo slugu FINALNEJ URL (autorita sirky ako v B-2a,
#     tabulkova sirka ju musi potvrdit, ak na stranke je).
#   - FIX 5: all-or-nothing — akykolvek fail polozky = ZIADNY zapis, UI dostane
#     zoznam vinnikov (odskrtnut a skusit znova).
#   - FIX 10: alive sa kontroluje pred kazdym async krokom AJ pred zapisom;
#     cancel/zatvorene okno/zmena modelu = ziadny zapis, ziadne dalsie eventy.
#   - BLOCKER 1: obrazok dekoru sa stahuje cez DemosImageCache (throttle,
#     guardy) AZ PO uspesnom zapise — best effort, neblokuje zalozenie.
#
# Eventy load_family (emit.call(hash), string kluce):
#   {'type'=>'family','header'=>{...},'items'=>[...],'warnings'=>[]}
#   {'type'=>'complete','ok'=>bool,'error'=>String|nil}
# Eventy create:
#   {'type'=>'progress','done'=>i,'total'=>n,'label'=>String}
#   {'type'=>'complete','ok'=>true,'result'=>{'group_id','sheets','edges',
#    'skipped','image'=>bool}}
#   {'type'=>'complete','ok'=>false,'error'=>...,'failed'=>[{'iid','name','reason'}]}
#
# Polozka rodiny: {'iid','kind'=>'sheet'|'edge'|'other','type'=>DTDL|...,
#   'name','code','url','unit','price_vat','reason'=>String|nil,
#   'thickness_hint','width_hint'} — *_hint su zo slugu, LEN na zobrazenie
# a auto-navrh pasky v UI (ziadny zapis).

module Noxun
  module Engine
    module DemosFamily
      WATCHDOG_S = DemosLookup::WATCHDOG_S

      module_function

      # --- nacitanie rodiny (1 fetch) -----------------------------------------

      def load_family(url, alive:, emit:)
        ctx = new_ctx(alive, emit)
        clean, err = Demos.sanitize_url(url)
        return complete(ctx, false, err) unless clean
        reset_watchdog(ctx)
        Demos.fetch(clean) do |res|
          next if ctx['completed']
          next unless ctx['alive'].call
          reset_watchdog(ctx)
          unless res['ok']
            complete(ctx, false, res['error'].to_s)
            next
          end
          parsed = DemosProductParser.parse(res['body'])
          header, items, herr = family_from(parsed, res['url'].to_s)
          unless header
            complete(ctx, false, herr)
            next
          end
          deliver(ctx, 'type' => 'family', 'header' => header, 'items' => items,
                  'warnings' => Array(parsed['warnings']))
          complete(ctx, true, nil)
        end
        true
      end

      # Hlavicka skupiny + klasifikovane polozky (hlavny produkt + related).
      # Identita skupiny podla standardu 7.1 = vyrobca + cislo dekoru — obe
      # POVINNE zo stranky (chybajuce = nie je to produktova stranka dekoru).
      def family_from(parsed, final_url)
        unless parsed['ok']
          return [nil, nil, 'stránka nie je produktový detail Demosu — vlož adresu produktu']
        end
        params = parsed['params'] || {}
        decor = params['decor'].to_s.strip
        brand = parsed['brand'].to_s.strip
        if decor.empty? || brand.empty?
          return [nil, nil, 'stránka nemá číslo dekoru alebo výrobcu — pre založenie skupiny vlož stránku dosky/pásky dekoru']
        end
        header = {
          'manufacturer' => brand, 'decor' => decor,
          'decor_name' => params['decor_name'].to_s.strip,
          'structure' => params['structure'].to_s.strip,
          'title' => parsed['title'].to_s, 'url' => final_url,
          'image_url' => parsed['image_url'].to_s
        }
        items = []
        main = classify_item(parsed['title'].to_s, parsed['code'].to_s, final_url,
                             parsed['unit'], parsed['price_vat'])
        items << main
        Array(parsed['related']).each do |r|
          items << classify_item(r['name'].to_s, r['code'].to_s, r['url'].to_s,
                                 r['unit'], r['price_vat'])
        end
        # Dedup podla kodu (hlavny produkt byva aj v related bloku).
        seen = {}
        items = items.select do |it|
          key = it['code']
          next false if key.empty? || seen[key]
          seen[key] = true
        end
        items.each_with_index { |it, i| it['iid'] = "i#{i}" }
        [header, items, nil]
      end

      # Klasifikacia polozky podla slugu jej URL — LEN kandidat (FIX 7):
      # sheet typ / ABS / 'other' s dovodom. Hints zo slugu su na zobrazenie
      # a auto-navrh pasky, nikdy na zapis.
      def classify_item(name, code, url, unit, price_vat)
        slug = DemosSlugMatcher.slug_of(url)
        item = { 'name' => name, 'code' => code, 'url' => url,
                 'unit' => unit, 'price_vat' => price_vat,
                 'kind' => 'other', 'type' => nil, 'reason' => nil,
                 'thickness_hint' => nil, 'width_hint' => nil }
        if slug.split('-').include?('vzorka')
          item['reason'] = 'vzorka — nie je materiál'
          return item
        end
        if DemosSlugMatcher.edge_slug?(slug)
          w, th = edge_dims_from_slug(slug)
          item['width_hint'] = w
          item['thickness_hint'] = th
          if th && !Materials.supported_edge_thickness?(th, Materials::SCHEMA_GROUPS)
            item['reason'] = "ABS hrúbka #{Materials.fmt_mm(th)} mm je mimo podporovaných"
          else
            item['kind'] = 'edge'
          end
          return item
        end
        type = sheet_type_of(slug)
        if type.nil?
          # D-65: povodne "(prislusenstvo)" klamalo pri doskach s nepokrytym
          # prefixom (dtd-laminovana…) — po rozsireni prefixov su tu uz naozaj
          # len listy/kovanie/vzorky, text ostava neutralny.
          item['reason'] = 'mimo podporovaných typov materiálu'
        elsif type == 'ZASTENA'
          # Zastena nesie obojstranny dekor (rub) — zakladanie z Demosu ju
          # zatial nepodporuje (rub by sa musel citat zo slugu, FIX 7 zakazuje).
          item['reason'] = 'zástena (obojstranný dekor) — založ ručne'
        else
          item['kind'] = 'sheet'
          item['type'] = type
          item['thickness_hint'] = sheet_thickness_from_slug(slug)
        end
        item
      end

      # D-65: klasifikacia slugu ma JEDNU autoritu (DemosSlugMatcher) — family,
      # name_search aj score pouzivaju tie iste prefixy s tou istou semantikou.
      def sheet_type_of(slug)
        DemosSlugMatcher.sheet_type_of(slug)
      end

      # ABS slug konci sirka-hrubka (absb-...-23-1, ...-43-2) alebo pri
      # desatinnej hrubke sirka-cele-desatina (...-23-0-8 = 23x0,8;
      # ...-43-1-5 = 43x1,5). Vrati [width, thickness] alebo [nil, nil].
      def edge_dims_from_slug(slug)
        nums = trailing_numbers(slug)
        return [nil, nil] if nums.length < 2
        # Kandidat 1: posledne DVA tokeny ako desatinna hrubka (X-Y = X.Y) —
        # plati len pre realne obchodne desatinne hrubky (0,4/0,8/1,2/1,5).
        if nums.length >= 3
          dec = "#{nums[-2]}.#{nums[-1]}".to_f
          if decimal_edge_thickness?(dec)
            return [nums[-3].to_f, dec]
          end
        end
        [nums[-2].to_f, nums[-1].to_f]
      end

      # Cela hrubka dosky byva posledny token (…-2800-2070-18); desatinna ma
      # dva tokeny (…-9-2). Best-effort hint — NIKDY sa nezapisuje.
      def sheet_thickness_from_slug(slug)
        nums = trailing_numbers(slug)
        return nil if nums.empty?
        if nums.length >= 2 && nums[-1].length == 1 && nums[-2].length <= 2
          dec = "#{nums[-2]}.#{nums[-1]}".to_f
          return dec if dec.positive? && dec < 100
        end
        v = nums[-1].to_f
        v.positive? && v < 100 ? v : nil
      end

      # Neprerusene ciselne tokeny z KONCA slugu.
      def trailing_numbers(slug)
        out = []
        slug.split('-').reverse_each do |t|
          break unless t.match?(/\A\d+\z/)
          out.unshift(t)
        end
        out
      end

      def decimal_edge_thickness?(value)
        Materials::SUPPORTED_EDGE_THICKNESSES_V2.include?(value) && value != value.round
      end

      # --- zalozenie skupiny (sekvencne fetche + 1 zapis) ----------------------

      # header/items = zo SERVEROVEHO family store (dialog), iids = vyber.
      def create(header, items, iids, alive:, emit:)
        ctx = new_ctx(alive, emit)
        by_iid = {}
        Array(items).each { |it| by_iid[it['iid'].to_s] = it }
        # GH #101 P1: opakovany iid vo vybere = jedna polozka (duplicitny
        # fetch aj zapis by inak siel dvakrat).
        chosen = Array(iids).map(&:to_s).uniq.map { |x| by_iid[x] }.compact
        return complete_create_fail(ctx, 'nie je vybraná žiadna položka', []) if chosen.empty?
        if (bad = chosen.find { |it| !%w[sheet edge].include?(it['kind'].to_s) })
          reason = bad['reason'].to_s.empty? ? 'mimo systému' : bad['reason']
          return complete_create_fail(ctx, "položka „#{bad['name']}“ sa nedá založiť (#{reason})", [])
        end
        ctx['header'] = header
        ctx['total'] = chosen.length
        ctx['results'] = []
        ctx['failed'] = []
        create_chain(ctx, chosen.dup)
        true
      end

      # Sekvencne (throttle 3 s ma zmysel len v rade); alive pred kazdym dalsim
      # fetchom — cancel = ziadne dalsie requesty a ZIADNY zapis (vzor lookup).
      def create_chain(ctx, queue)
        return if ctx['completed']
        return unless ctx['alive'].call
        return finalize_create(ctx) if queue.empty?
        it = queue.shift
        reset_watchdog(ctx)
        Demos.fetch(it['url']) do |res|
          next if ctx['completed']
          next unless ctx['alive'].call
          reset_watchdog(ctx)
          outcome = verify_item(ctx['header'], it, res)
          if outcome['reason']
            ctx['failed'] << { 'iid' => it['iid'], 'name' => it['name'],
                               'reason' => outcome['reason'] }
          else
            ctx['results'] << outcome
          end
          ctx['done'] += 1
          deliver(ctx, 'type' => 'progress', 'done' => ctx['done'],
                  'total' => ctx['total'], 'label' => it['name'].to_s)
          create_chain(ctx, queue)
        end
      end

      # Fetch vysledok polozky -> overene polia na zapis | {'reason'=>...}.
      # FIX 7: typ zo slugu FINALNEJ URL, parametre z PARSOVANEJ stranky;
      # chybajuci/nesediaci parameter = fail polozky (nie tichy odhad).
      # D-64: brand + params-decor dokaz identity plati LEN pre dosky (GH #97
      # P1 — Egger vs Kronospan zdielaju cisla dekorov). Pasky vyrabaju tretie
      # strany (Rehau…): ich stranka nesie VLASTNU znacku aj VLASTNE "Cislo
      # dekoru" (79098/LPE05), dekor dosky je len v slugu — overuje verify_edge.
      def verify_item(header, it, res)
        return { 'reason' => "sieť: #{res['error']}" } unless res['ok']
        parsed = DemosProductParser.parse(res['body'])
        return { 'reason' => 'stránka nie je produktový detail' } unless parsed['ok']
        final_url = res['url'].to_s
        params = parsed['params'] || {}
        code = parsed['code'].to_s
        slug = DemosSlugMatcher.slug_of(final_url)
        return verify_edge(header, parsed, params, slug, code, final_url) if it['kind'] == 'edge'
        brand = parsed['brand'].to_s
        unless !brand.strip.empty? &&
               Materials.identity_norm(brand) == Materials.identity_norm(header['manufacturer'])
          return { 'reason' => 'výrobca stránky nesedí s rodinou — položka sa nezakladá' }
        end
        unless params['decor'] &&
               Materials.identity_norm(params['decor']) == Materials.identity_norm(header['decor'])
          return { 'reason' => 'číslo dekoru stránky nesedí s rodinou' }
        end
        verify_sheet(parsed, params, slug, code, final_url, it)
      end

      def verify_sheet(parsed, params, slug, code, final_url, it)
        type = sheet_type_of(slug)
        return { 'reason' => 'finálna adresa nie je podporovaný typ dosky' } if type.nil? || type == 'ZASTENA'
        if it['type'] && type != it['type']
          return { 'reason' => "typ sa po presmerovaní zmenil (#{it['type']} → #{type})" }
        end
        th = params['thickness']
        return { 'reason' => 'stránka neuvádza hrúbku materiálu' } unless th.is_a?(Numeric) && th.positive?
        fmt = params['format']
        if Materials.format_in_identity?(type) && fmt.nil?
          return { 'reason' => 'stránka neuvádza formát (pri tomto type je súčasťou identity)' }
        end
        {
          'kind' => 'sheet', 'type' => type, 'thickness' => th,
          'structure' => params['structure'].to_s.strip,
          'sheet_size' => fmt, 'code' => code,
          'price' => DemosProductParser.price_for_catalog(parsed['price_vat'], parsed['unit'], 'sheet', fmt),
          'demos_url' => final_url, 'image_url' => parsed['image_url'].to_s,
          'reason' => nil
        }
      end

      # D-64: dekor rodiny dokazuje bud parameter stranky (Kronospan si pasky
      # znaci spravne), alebo slug finalnej URL v useku PRED koncovymi rozmermi
      # (dekor '23' nesmie matchnut sirku 23). Brand sa pri paske neoveruje —
      # ABS zaznam vyrobcu ani nenesie (standard 7.5).
      def verify_edge(header, parsed, params, slug, code, final_url)
        return { 'reason' => 'finálna adresa nie je ABS páska' } unless DemosSlugMatcher.edge_slug?(slug)
        page_decor_ok = params['decor'] &&
                        Materials.identity_norm(params['decor']) == Materials.identity_norm(header['decor'])
        unless page_decor_ok || edge_slug_decor?(slug, header['decor'])
          return { 'reason' => 'adresa pásky nenesie číslo dekoru rodiny — položka sa nezakladá' }
        end
        w, th = edge_dims_from_slug(slug)
        unless w && w.positive? && th && th.positive?
          return { 'reason' => 'z adresy pásky sa nedá určiť šírka×hrúbka' }
        end
        # Tabulkova sirka (ak ju stranka uvadza) musi slug potvrdit — B-2a vzor.
        pw = params['width']
        if pw.is_a?(Numeric) && (pw.to_f - w).abs > 0.011
          return { 'reason' => 'šírka pásky na stránke nesedí s adresou' }
        end
        pt = params['thickness']
        if pt.is_a?(Numeric) && (pt.to_f - th).abs > 0.011
          return { 'reason' => 'hrúbka pásky na stránke nesedí s adresou' }
        end
        # D-58: stranky pasok strukturu POVRCHU neuvadzaju (maju len "Struktura
        # hran" vyrobcu pasky — vedome sa NECITA, bola by zla autorita); prazdna
        # struktura dedi strukturu rodiny, aby picker (skupina + presna
        # struktura) pasku nachadzal a banner "bez struktury" nestrasil.
        structure = params['structure'].to_s.strip
        structure = header['structure'].to_s.strip if structure.empty?
        {
          'kind' => 'edge', 'width' => w, 'thickness' => th,
          'structure' => structure, 'code' => code,
          'price' => DemosProductParser.price_for_catalog(parsed['price_vat'], parsed['unit'], 'edge', nil),
          'demos_url' => final_url, 'reason' => nil
        }
      end

      # Dekor rodiny ako suvisla sekvencia tokenov slugu PRED koncovymi
      # rozmermi (absb-79098-ohne-lpe05-cashmere-5981-bs-5981-pd-23-0-8 ma
      # dekor 5981 v tele; koncove 23-0-8 su sirka×hrubka a do dokazu nepatria).
      def edge_slug_decor?(slug, decor)
        seq = DemosSlugMatcher.norm_token(decor)
        return false if seq.nil? || seq.empty?
        parts = slug.split('-')
        tail = trailing_numbers(slug).length
        body = tail.positive? ? parts[0...-tail] : parts
        DemosSlugMatcher.contains_seq?(body, seq)
      end

      # Po dobehnuti vsetkych fetchov: all-or-nothing zapis + obrazok.
      def finalize_create(ctx)
        return if ctx['completed']
        unless ctx['failed'].empty?
          return complete_create_fail(ctx,
                                      'niektoré položky sa nepodarilo overiť — nič sa nezaložilo',
                                      ctx['failed'])
        end
        # FIX 10: posledna alive kontrola tesne pred zapisom (cancel počas
        # posledneho fetchu nesmie skoncit zapisom).
        return unless ctx['alive'].call
        header = ctx['header'] || {}
        sheet_results = ctx['results'].select { |r| r['kind'] == 'sheet' }
        # GH #101 P2: obrazok skupiny = JEDNA URL — ta ista sa zapisuje na
        # vsetky dosky AJ stahuje do cache (path_for hashuje presnu URL;
        # header vs per-variant URL by dali cache miss). Header ma prednost,
        # fallback je prvy variant s obrazkom.
        group_img = header['image_url'].to_s
        group_img = sheet_results.map { |r| r['image_url'].to_s }.find { |u| !u.empty? }.to_s if group_img.empty?
        sheet_results.each { |r| r['image_url'] = group_img }
        status, info = Materials.create_group_from_demos(
          'manufacturer' => header['manufacturer'], 'decor' => header['decor'],
          'decor_name' => header['decor_name'],
          'sheet_items' => sheet_results,
          'edge_items' => ctx['results'].select { |r| r['kind'] == 'edge' }
        )
        unless status == :ok
          detail = info.is_a?(Hash) ? info['detail'] : nil
          return complete_create_fail(ctx, create_error_text(status, detail), [])
        end
        # GH #102 P1: katalog je ZAPISANY — od tejto chvile sa complete doruci
        # VZDY (aj ked cancel/zatvorenie medzitym zhodilo alive): mutacia sa
        # nesmie zatajit, volajuci musi spravit katalogovy refresh.
        ctx['committed'] = true
        fetch_group_image(ctx, group_img, info)
      end

      # BLOCKER 1: obrazok az PO zapise, cez klienta (throttle) do lokalnej
      # cache — best effort (false = dlazdica ma fallback farbu).
      def fetch_group_image(ctx, url, result)
        finish = proc do |local|
          complete_create_ok(ctx, result.merge('image' => !local.nil?))
        end
        return finish.call(nil) if url.to_s.empty? || result['sheets'].empty?
        arm_image_watchdog(ctx, result)
        DemosImageCache.ensure(url) do |local|
          next if ctx['completed']
          finish.call(local)
        end
      rescue StandardError => e
        Engine.log_error(e, 'DemosFamily.fetch_group_image') if defined?(Engine)
        complete_create_ok(ctx, result.merge('image' => false))
      end

      # GH #101 P2: katalog je v tejto chvili UZ zapisany — visiaci/pomaly
      # obrazok NESMIE ohlasit fail (UI by klamalo, ze zalozenie zlyhalo, a
      # zvadzalo na retry). Timeout obrazka = uspech s image=false.
      def arm_image_watchdog(ctx, result)
        stop_watchdog(ctx)
        return if ctx['completed'] || !Demos.timers_available?
        ctx['watchdog'] = UI.start_timer(WATCHDOG_S, false) do
          complete_create_ok(ctx, result.merge('image' => false))
        end
      end

      def create_error_text(status, detail)
        case status
        when :catalog_read_only then detail.to_s
        when :code_conflict then "kód už v katalógu je (#{Array(detail).join(', ')}) — skupina sa nezaložila"
        when :write_failed then 'zápis katalógu zlyhal'
        else detail.to_s.empty? ? 'založenie skupiny zlyhalo' : detail.to_s
        end
      end

      # --- zivotny cyklus (vzor DemosLookup) -----------------------------------

      def new_ctx(alive, emit)
        { 'alive' => alive, 'emit' => emit, 'completed' => false,
          'done' => 0, 'total' => 0 }
      end

      def deliver(ctx, event)
        return if ctx['completed']
        return unless ctx['alive'].call
        ctx['emit'].call(event)
      end

      def complete(ctx, ok, error)
        return if ctx['completed']
        ctx['completed'] = true
        stop_watchdog(ctx)
        return unless ctx['alive'].call
        ctx['emit'].call('type' => 'complete', 'ok' => ok, 'error' => error)
        nil
      end

      def complete_create_ok(ctx, result)
        return if ctx['completed']
        ctx['completed'] = true
        stop_watchdog(ctx)
        # GH #102 P1: po commite katalogu sa uspesny complete doruci aj mrtvej
        # session — neskory cancel nesmie zatajit realne zalozenu skupinu
        # (emit lambda dialogu si okno/refresh guarduje sama).
        return unless ctx['committed'] || ctx['alive'].call
        ctx['emit'].call('type' => 'complete', 'ok' => true, 'result' => result)
        nil
      end

      def complete_create_fail(ctx, error, failed)
        return if ctx['completed']
        ctx['completed'] = true
        stop_watchdog(ctx)
        return unless ctx['alive'].call
        ctx['emit'].call('type' => 'complete', 'ok' => false, 'error' => error,
                         'failed' => Array(failed))
        nil
      end

      def reset_watchdog(ctx)
        stop_watchdog(ctx)
        return if ctx['completed'] || !Demos.timers_available?
        ctx['watchdog'] = UI.start_timer(WATCHDOG_S, false) do
          if ctx['results']
            complete_create_fail(ctx, 'Demos neodpovedá — skús znova o chvíľu', ctx['failed'] || [])
          else
            complete(ctx, false, 'Demos neodpovedá — skús znova o chvíľu')
          end
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
