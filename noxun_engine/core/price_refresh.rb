# frozen_string_literal: true
# Noxun Engine — V0.6 E-c: PREPOCITAT CENY (hromadne obnovenie cien z Demosu).
#
# Vstup = polozky POUZITE v aktualnom rozpocte, ktore maju vazbu na Demos
# (budget['stale']['items'] s demos_url — dosky, ABS pasky aj kovanie). Rucne
# polozky (bez vazby) sa NIKDY nefetchuju; UI ich len vymenuje s odporucanim.
#
# ============================ ZAVAZNE KONTRAKTY ========================
# 1) ZIADNA NOVA ZAPISOVA CESTA. Cena sa zapisuje VYHRADNE cez uz overene
#    cesty: materialy = DemosLookup (fetch + PLNE verify identity) ->
#    Materials.demos_items_from_accepts -> Materials.apply_demos_batch;
#    kovanie = HardwareCatalog.check_price! -> apply_price_proposal!.
#    Hodnoty pochadzaju VYHRADNE zo serveroveho proposalu (klient posiela len
#    "spusti"), price_checked_at stampuje server, katalogovy zapis je MIMO
#    undo (katalog nie je model — existujuci kontrakt).
# 2) PER ZAZNAM, NIE ALL-OR-NOTHING. Kazda polozka sa zapisuje samostatne
#    (jednopolozkova davka) — co sa stiahlo, to sa zapise; zvysok skonci v
#    reporte ako chyba s dovodom. Ciastocny uspech je NORMALNY vysledok.
# 3) SEKVENCNE. Demos.fetch drzi medziprocesovy Crawl-delay 3 s sam — retaz
#    ide polozka po polozke (paralelny beh by throttle aj tak serializoval,
#    len by rozbil progres a poradie). Ziadny sleep na UI vlakne.
# 4) ZRUSIT = "dokonci rozbehnutu, zvysok preskoc". Cancel NEROLLBACKUJE uz
#    zapisane ceny (su platne — realne sa overili) ani nezahadzuje polozku,
#    ktora prave visi v sieti; report ju vykaze a nesie cancelled=true.
# 5) BEZI LEN JEDEN. Druhe spustenie je NO-OP (run vrati nil) — dva behy by
#    si liezli do throttle slotov aj do row_rev baseline.
# 6) KATALOG NIE JE MODEL. Prepnutie/zavretie okna zastavi DALSIE fetche
#    (alive), ale rozbehnuta polozka dobehne a zapise sa — cena v katalogu
#    je globalna a na zakazke nezavisi.

module Noxun
  module Engine
    module PriceRefresh
      KINDS = %w[sheet edge hardware].freeze

      # Odhad casu na polozku: Crawl-delay 3 s (Demos::CRAWL_DELAY_S) + ~1 s na
      # fetch a parse. Sluzi VYHRADNE na potvrdzovaciu hlasku ("~X"), nikdy na
      # riadenie behu (o tempo sa stara throttle klienta).
      SECONDS_PER_ITEM = 4

      # Preklad statusov DemosLookup proposalu na ludsky dovod (pouzije sa az
      # ked proposal nenesie vlastne warningy — tie su konkretnejsie).
      PROPOSAL_ERRORS = {
        'fetch_error' => 'stránku sa nepodarilo načítať',
        'identity_fail' => 'stránka nesedí so záznamom — over väzbu v katalógu',
        'miss' => 'produkt sa na Demose nenašiel',
        'ambiguous' => 'viac možných produktov — over väzbu v katalógu',
        'skipped_duplak' => 'duplák sa nenakupuje — cenu drží zdrojová doska',
        'no_width' => 'páska bez šírky sa nedá jednoznačne overiť',
        'unsupported' => 'typ materiálu sa voči Demosu overiť nedá'
      }.freeze

      MATERIAL_WRITE_ERRORS = {
        conflict: 'záznam sa medzitým zmenil — spusti prepočet znova',
        stale_catalog: 'katalóg sa medzitým zmenil — spusti prepočet znova',
        not_found: 'záznam sa v katalógu nenašiel',
        duplak: 'duplák nemá nákupné polia',
        code_conflict: 'kód by sa zdvojil s inou položkou',
        write_failed: 'zápis do katalógu zlyhal'
      }.freeze

      HARDWARE_WRITE_ERRORS = {
        conflict: 'položka sa medzitým zmenila — spusti prepočet znova',
        not_found: 'položka sa v katalógu nenašla',
        no_proposal: 'návrh ceny sa medzitým stratil — skús znova',
        write_failed: 'zápis do katalógu zlyhal'
      }.freeze

      module_function

      # --- ciste funkcie (headless testovatelne) -------------------------------

      # Payload rozpoctu -> zoznam VIAZANYCH poloziek na obnovenie.
      # Scan rozpoctu (Budget.stale_scan) uz drzi presne to, co treba: LEN
      # polozky POUZITE v tejto zakazke a LEN tie, ktore nie su cerstve
      # (fresh sa do items nedostane — cena overena v prahu sa nestahuje znova).
      # Rucne polozky (state 'manual') vazbu nemaju a vypadnu na demos_url.
      def targets_from_budget(budget)
        b = budget.is_a?(Hash) ? budget : {}
        stale = b['stale'].is_a?(Hash) ? b['stale'] : {}
        seen = {}
        out = []
        Array(stale['items']).each do |it|
          next unless it.is_a?(Hash)
          kind = it['kind'].to_s
          next unless KINDS.include?(kind)
          id = it['id'].to_s.strip
          next if id.empty?
          url = it['demos_url'].to_s.strip
          next if url.empty? # rucna polozka — nikdy sa nefetchuje
          key = "#{kind}|#{id}"
          next if seen[key]
          seen[key] = true
          out << { 'kind' => kind, 'id' => id, 'label' => it['label'].to_s,
                   'url' => url, 'state' => it['state'].to_s }
        end
        out
      end

      # Polozky BEZ vazby (rucne) — UI ich vymenuje s odporucanim "over v
      # katalogu rucne". Ziadny fetch, ziadny zapis.
      def manual_from_budget(budget)
        b = budget.is_a?(Hash) ? budget : {}
        stale = b['stale'].is_a?(Hash) ? b['stale'] : {}
        Array(stale['items']).select do |it|
          it.is_a?(Hash) && it['demos_url'].to_s.strip.empty?
        end
      end

      def estimate_seconds(count)
        n = count.to_i
        n.positive? ? n * SECONDS_PER_ITEM : 0
      end

      # --- zivotny cyklus behu -------------------------------------------------

      # Mrtvy kontext (zavrete okno) lock NEDRZI — inak by sa prepocet uz nikdy
      # nedal spustit. Kontrola je lenivá: stav sa cisti pri kazdej otazke.
      def running?
        ctx = @ctx
        return false unless ctx
        if ctx['completed'] || !safe_alive(ctx)
          @ctx = nil
          return false
        end
        true
      end

      def running_pid
        running? ? @ctx['pid'] : nil
      end

      def safe_alive(ctx)
        ctx['alive'].call == true
      rescue StandardError
        false
      end

      # targets: [{'kind','id','label','url'}]; alive: proc -> bool (zivotnost
      # okna); emit: proc(event) — eventy nesu 'pid' behu.
      # Eventy: start | progress (pred fetchom polozky) | item (vysledok) |
      #         complete (presne RAZ, s reportom).
      # -> pid (Integer) | nil (uz bezi / nie je co robit)
      def run(targets, alive:, emit:)
        return nil if running?
        list = Array(targets).select { |t| t.is_a?(Hash) && KINDS.include?(t['kind'].to_s) }
        return nil if list.empty?
        @seq = @seq.to_i + 1
        ctx = { 'pid' => @seq, 'alive' => alive, 'emit' => emit,
                'queue' => list.dup, 'total' => list.length, 'done' => 0,
                'items' => [], 'cancelled' => false, 'completed' => false }
        @ctx = ctx
        deliver(ctx, 'type' => 'start', 'total' => ctx['total'])
        step(ctx)
        ctx['pid']
      end

      # Zrusenie: dalsie polozky sa uz nestiahnu, rozbehnuta dobehne (a zapise
      # sa — cena je realne overena). pid nil = zrus bezaci beh.
      def cancel!(pid = nil)
        ctx = @ctx
        return false unless ctx
        return false if !pid.nil? && pid.to_i != ctx['pid'].to_i
        ctx['cancelled'] = true
        true
      end

      # VYHRADNE testy — module premenne preziju medzi testami.
      def reset_state!
        @ctx = nil
        true
      end

      # --- retaz ---------------------------------------------------------------

      def step(ctx)
        return if ctx['completed']
        return abandon(ctx) unless safe_alive(ctx)
        return complete(ctx) if ctx['cancelled'] || ctx['queue'].empty?
        target = ctx['queue'].shift
        deliver(ctx, 'type' => 'progress', 'done' => ctx['done'], 'total' => ctx['total'],
                     'label' => target['label'].to_s, 'kind' => target['kind'].to_s)
        refresh_one(ctx, target) do |result|
          # Pokracovanie retaze bezi v ASYNC callbacku (HTTP odpoved) — mimo
          # ramca step/refresh_one. Vynimka odtialto by skoncila v sieti a beh
          # by ostal bez terminalneho eventu (zamknuty progres + drziaci lock);
          # preto sa kazda chyba retaze prelozi na KONIEC behu s reportom.
          begin
            record(ctx, result)
            step(ctx)
          rescue StandardError => e
            Engine.log_error(e, 'PriceRefresh.step chain') if defined?(Engine)
            complete(ctx)
          end
        end
      end

      def record(ctx, result)
        ctx['done'] += 1
        ctx['items'] << result
        deliver(ctx, 'type' => 'item', 'item' => result,
                     'done' => ctx['done'], 'total' => ctx['total'])
      end

      # `done` sa smie ozvat PRESNE RAZ. Headless (a chybove skratky) bezia
      # synchronne — zvysok retaze teda dobehne VNUTRI tohto ramca a vynimka
      # spod neho by cez rescue posunula druhy vysledok tej istej polozky
      # (rozbity pocet done/total). Guard je tu, nie v jednotlivych vetvach.
      def refresh_one(ctx, target, &done)
        fired = false
        once = lambda do |result|
          next if fired
          fired = true
          done.call(result)
        end
        if target['kind'].to_s == 'hardware'
          refresh_hardware(ctx, target, &once)
        else
          refresh_material(ctx, target, &once)
        end
      rescue StandardError => e
        Engine.log_error(e, 'PriceRefresh.refresh_one') if defined?(Engine)
        once.call(result_for(target, 'error', 'error' => "chyba: #{e.message}"))
      end

      # --- materialy (dosky + ABS) ---------------------------------------------

      # Vazba (URL) sa berie z KATALOGU, nie z payloadu okna — payload je len
      # zoznam "co obnovit". DemosLookup.run so ZVIAZANYM zaznamom ide priamo
      # na ulozenu adresu (D-70: ziadna sitemap) a robi PLNE verify identity;
      # zastarana vazba tak nikdy nepretlaci cudziu cenu do zaznamu.
      def refresh_material(ctx, target, &done)
        kind = target['kind'].to_s == 'edge' ? 'edge' : 'sheet'
        rec = find_material(kind, target['id'])
        return done.call(result_for(target, 'error', 'error' => 'záznam sa v katalógu nenašiel')) unless rec
        if rec['demos_url'].to_s.strip.empty?
          return done.call(result_for(target, 'error', 'error' => 'záznam nemá uloženú adresu produktu'))
        end
        # POVINNÝ guard: DemosLookup pri NEPLATNEJ väzbe spadne na sitemap cestu
        # (match podľa slugu) — a tá vie stiahnuť 9,5 MB zoznam produktov.
        # Prepočet cien ide VÝHRADNE po uloženej väzbe; neplatná = chyba riadku.
        clean, err = Demos.sanitize_url(rec['demos_url'])
        unless clean
          return done.call(result_for(target, 'error',
                                      'error' => "uložená adresa produktu je neplatná (#{err}) — over väzbu v katalógu"))
        end
        base_rev = Materials.record_rev(rec)
        proposal = nil
        fired = false
        emit = lambda do |event|
          case event['type']
          when 'proposal' then proposal = event['proposal']
          when 'complete'
            next if fired
            fired = true
            # GH #140 P2: tento callback bezi AZ po navrate refresh_one — jeho
            # rescue uz nechyta. Zlyhanie zapisu (zamok katalogu, IO) musi
            # skoncit ako CHYBA POLOZKY, nie ako beh bez terminalneho eventu.
            done.call(safe_result(target, 'PriceRefresh.apply_material') do
              apply_material(target, kind, base_rev, proposal, event)
            end)
          end
        end
        # alive vnutorneho lookupu NIE JE zivotnost okna: rozbehnuta polozka
        # musi dobehnut aj po zavreti okna, inak by retaz ostala visiet bez
        # terminalneho eventu (a lock by drzal navzdy).
        DemosLookup.run([rec], alive: -> { !ctx['completed'] }, emit: emit)
      end

      def find_material(kind, id)
        key = id.to_s
        if kind == 'edge'
          Materials.edges.find { |e| e['abs_id'].to_s == key }
        else
          Materials.sheets.find { |s| s['material_id'].to_s == key }
        end
      end

      def apply_material(target, kind, base_rev, proposal, complete_event)
        unless proposal.is_a?(Hash)
          why = complete_event['error'].to_s
          return result_for(target, 'error',
                            'error' => (why.empty? ? 'stránku sa nepodarilo načítať' : why))
        end
        status = proposal['status'].to_s
        unless status == 'match'
          return result_for(target, 'error', 'url' => proposal['url'],
                            'error' => proposal_error(status, proposal))
        end
        price = proposal['price'].is_a?(Hash) ? proposal['price'] : {}
        if price['new'].nil? && price['unchanged'] != true
          warn = Array(proposal['warnings']).first.to_s
          return result_for(target, 'error', 'url' => proposal['url'], 'old_price' => price['old'],
                            'error' => (warn.empty? ? 'stránka nemá použiteľnú cenu s DPH' : warn))
        end
        write_material(target, kind, base_rev, proposal, price)
      end

      def write_material(target, kind, base_rev, proposal, price)
        key = [kind, target['id'].to_s]
        items = Materials.demos_items_from_accepts(
          [{ 'kind' => kind, 'id' => target['id'].to_s, 'price' => true }],
          { key => proposal }, { key => base_rev }
        )
        if items.empty?
          return result_for(target, 'error', 'url' => proposal['url'],
                            'error' => 'z návrhu nie je čo zapísať')
        end
        status, info = Materials.apply_demos_batch(items, catalog_rev: Materials.catalog_revision)
        case status
        when :ok
          unchanged = price['unchanged'] == true
          result_for(target, unchanged ? 'unchanged' : 'changed', 'url' => proposal['url'],
                     'old_price' => price['old'],
                     'new_price' => (unchanged ? price['old'] : price['new']))
        when :catalog_read_only
          result_for(target, 'error', 'error' => Materials.catalog_read_only_message)
        else
          detail = info.is_a?(Hash) ? info['detail'] : nil
          why = MATERIAL_WRITE_ERRORS[status] ||
                (detail.is_a?(String) && !detail.empty? ? detail : 'záznam sa nedá zapísať')
          result_for(target, 'error', 'url' => proposal['url'], 'old_price' => price['old'], 'error' => why)
        end
      end

      def proposal_error(status, proposal)
        warn = Array(proposal['warnings']).reject { |w| w.to_s.strip.empty? }.first.to_s
        return warn unless warn.empty?
        PROPOSAL_ERRORS[status] || 'stránku sa nepodarilo overiť'
      end

      # --- kovanie -------------------------------------------------------------

      # Presne cesta tlacidla "Over cenu" (D2): check_price! overi kod, MJ a
      # cenu s DPH a odlozi SERVEROVY proposal (pid); zapis berie hodnoty
      # vyhradne z neho a strazi base_row_rev.
      def refresh_hardware(ctx, target, &done)
        code = target['id'].to_s
        return done.call(result_for(target, 'error', 'error' => 'položka bez kódu')) if code.empty?
        fired = false
        HardwareCatalog.check_price!(code) do |res|
          next if fired
          fired = true
          done.call(safe_result(target, 'PriceRefresh.apply_hardware') do
            apply_hardware(target, code, res)
          end)
        end
        nil
      end

      def apply_hardware(target, code, res)
        r = res.is_a?(Hash) ? res : {}
        unless r['ok'] == true
          why = r['error'].to_s
          return result_for(target, 'error', 'error' => (why.empty? ? 'cenu sa nepodarilo overiť' : why))
        end
        status, info = HardwareCatalog.apply_price_proposal!(code, pid: r['pid'])
        case status
        when :ok
          unchanged = r['status'].to_s == 'unchanged'
          result_for(target, unchanged ? 'unchanged' : 'changed', 'url' => r['url'],
                     'old_price' => r['old'], 'new_price' => (unchanged ? r['old'] : r['new']))
        when :read_only
          result_for(target, 'error', 'error' => "katalóg kovania je len na čítanie — #{info}")
        else
          why = HARDWARE_WRITE_ERRORS[status] ||
                (info.is_a?(String) && !info.empty? ? info : 'položka sa nedá zapísať')
          result_for(target, 'error', 'url' => r['url'], 'old_price' => r['old'], 'error' => why)
        end
      end

      # --- report + eventy -----------------------------------------------------

      # Vyhodnotenie vysledku polozky, ktore NESMIE vyhodit vynimku von: volaju
      # ho ASYNC callbacky (sietova odpoved), kde uz ziadny rescue retaze nie je.
      def safe_result(target, context)
        yield
      rescue StandardError => e
        Engine.log_error(e, context) if defined?(Engine)
        result_for(target, 'error', 'error' => "zápis zlyhal: #{e.message}")
      end

      def result_for(target, status, extra = {})
        out = { 'kind' => target['kind'].to_s, 'id' => target['id'].to_s,
                'label' => target['label'].to_s, 'status' => status,
                'old_price' => nil, 'new_price' => nil, 'diff' => nil,
                'url' => nil, 'error' => nil }
        out.merge!(extra)
        out['old_price'] = num(out['old_price'])
        out['new_price'] = num(out['new_price'])
        if out['status'] == 'changed' && out['old_price'] && out['new_price']
          out['diff'] = (out['new_price'] - out['old_price']).round(4)
        end
        out
      end

      def num(value)
        return nil unless value.is_a?(Numeric)
        f = value.to_f
        f.finite? ? f : nil
      end

      def build_report(ctx)
        items = ctx['items']
        counts = { 'changed' => 0, 'unchanged' => 0, 'error' => 0 }
        items.each { |i| counts[i['status']] = counts[i['status']].to_i + 1 }
        { 'total' => ctx['total'], 'done' => ctx['done'],
          'skipped' => [ctx['total'] - ctx['done'], 0].max,
          'cancelled' => ctx['cancelled'] == true,
          'changed' => counts['changed'], 'unchanged' => counts['unchanged'],
          'errors' => counts['error'], 'items' => items }
      end

      def deliver(ctx, event)
        return if ctx['completed'] && event['type'] != 'complete'
        return unless safe_alive(ctx)
        ctx['emit'].call(event.merge('pid' => ctx['pid']))
      rescue StandardError => e
        Engine.log_error(e, 'PriceRefresh.deliver') if defined?(Engine)
      end

      # Terminalny event presne RAZ; report sa vrati aj mrtvemu volajucemu
      # (testy), ale emit uz nedostane nic.
      def complete(ctx)
        return nil if ctx['completed']
        ctx['completed'] = true
        release(ctx)
        report = build_report(ctx)
        deliver(ctx, 'type' => 'complete', 'report' => report)
        report
      end

      # Okno zomrelo — beh koncime TICHO (ziadny event, ziadny report).
      def abandon(ctx)
        return nil if ctx['completed']
        ctx['completed'] = true
        release(ctx)
        nil
      end

      def release(ctx)
        @ctx = nil if @ctx && @ctx['pid'] == ctx['pid']
      end
    end
  end
end
