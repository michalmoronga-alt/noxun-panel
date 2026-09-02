# frozen_string_literal: true
# Noxun Engine — V0.6 C-1: katalog kovania (ploche polozky s Demos kodmi).
#
# Koncepty prevzate z pluginu KOVANIE, infrastruktura ENGINE (JsonFileStore
# atomicky zapis + .bak + cache; flock zamok; revision guardy vzor Materials).
# Vedome NEPREBRATE z KOVANIE: use_count increment (odlozene do davky D —
# audit C Q3: nevyjasneny kontrakt), inkrementalna search cache (bug),
# full-replace CSV import bez guardov.
#
# Kontrakty (audit C 1.8.2026):
#   - item_code = IDENTITA polozky, unique case-insensitive, NEMENNA
#     (create_item / patch_item su ODDELENE — patch nikdy neprepadne do
#     create, klient nikdy nezapisuje use_count ani price_checked_at).
#   - ceny S DPH (standard §7.1); nil = nezadana (kluc chyba) != 0.
#   - pohybliva cenova cache: demos_url + price_checked_at ZAPISUJE VYHRADNE
#     serverovy proposal flow (check_price! -> apply_price_proposal!) — cena
#     z klienta sa NIKDY neprijima (BLOCKER 1); manualny patch ceny/MJ alebo
#     vymazanie URL datum overenia ZMAZE (F5 — datum patri konkretnej vazbe).
#   - sety NIE SU polozky katalogu — set = mapovacie pravidlo davky D.
#   - read-only rezim pri poskodeni/novsej scheme — matica v assess! (F3).

require 'digest'
require 'time'
require 'json'
require 'fileutils'

module Noxun
  module Engine
    module HardwareCatalog
      STD = 'noxun-hardware-catalog'
      # KOV-B1: polozka moze niest `manufacturer`/`series` z taxonomie
      # (`HardwareTaxonomy`) — starsi plugin ich nepozna a jeho `normalize_item`
      # by ich pri prvom zapise TICHO zahodil. Marker je preto LAZY PODLA
      # OBSAHU (`schema_for`, vzor `HardwareSets.snapshot_std` a materialov):
      # katalog BEZ vyrobcov ostava na schema 1 a starsie verzie ho citaju dalej;
      # akonahle ma cokolvek vyrobcu ci radu, stampuje sa 2 a starsi plugin ho
      # odmietne ako read-only („aktualizuj plugin"), nikdy ticho neoreze.
      SCHEMA_BASE = 1
      SCHEMA_CLASSIFIED = 2
      SCHEMA_CURRENT = SCHEMA_CLASSIFIED
      # Verzia SEED sady (nezavisla od SCHEMA — tvar zaznamov sa nemeni).
      # Upgrade existujuceho katalogu robi apply_seed_patches! (audit D1 F8):
      # merge-safe backfill novych kodov + oprava LEN preukazatelne
      # nezmenenych povodnych seed riadkov; pouzivatelske upravy sa NIKDY
      # neprepisuju. v2 (D1): +105408/105425 (krytky Sensys, debata 2.8.),
      # 93240 NOHY -> SPOJOVACI_MATERIAL (Bystrica nie je noha).
      SEED_SET_VERSION = 2
      FILE = 'hardware_catalog.json'

      CATEGORIES = %w[ZAVESY VYSUVY VYKLOPY NOHY UCHYTKY SPOJOVACI_MATERIAL
                      VESIAKY OSVETLENIE OSTATNE].freeze
      UNITS = %w[ks set par bal m].freeze
      # Kanonizacia jednotky zo stranky Demosu / CSV (F6): cena sa navrhne LEN
      # pri zhode KANONICKEJ jednotky zaznamu a stranky — ziadne ks<->bal
      # prepocty. K-sada predavana za kus = 'ks'.
      UNIT_ALIASES = {
        'ks' => 'ks', 'set' => 'set', 'sada' => 'set', 'sady' => 'set',
        'par' => 'par', 'pár' => 'par', 'bal' => 'bal', 'balenie' => 'bal',
        'm' => 'm', 'bm' => 'm'
      }.freeze

      # Polia editovatelne patchom (F7 whitelist). demos_url je tu LEN pre
      # VYMAZANIE vazby (prazdna hodnota); neprazdnu URL zapisuje vyhradne
      # proposal flow. use_count/price_checked_at NIKDY z klienta.
      PATCHABLE = %w[name_sk price_eur_vat supplier notes category unit active
                     demos_url manufacturer series].freeze

      PRICE_TOLERANCE = 0.005
      WATCHDOG_S = 45

      module_function

      # --- ulozisko -----------------------------------------------------------

      def dir
        Materials.dir # zdielany %APPDATA%/NOXUN/Engine (+ test_dir_override)
      end

      def path
        File.join(dir, FILE)
      end

      def lock_path
        File.join(dir, 'hardware_catalog.lock')
      end

      # Reentrantny medziprocesovy zamok (vzor Materials.with_catalog_lock).
      def with_lock
        depth = @lock_depth.to_i
        if depth.positive?
          @lock_depth = depth + 1
          begin
            return yield
          ensure
            @lock_depth -= 1
          end
        end
        FileUtils.mkdir_p(dir)
        File.open(lock_path, 'a') do |f|
          f.flock(File::LOCK_EX)
          @lock_depth = 1
          begin
            yield
          ensure
            @lock_depth = 0
            f.flock(File::LOCK_UN)
          end
        end
      end

      # --- stav katalogu (F3 matica) ------------------------------------------
      # :ok | :read_only; dovod v state_reason. Chybajuci subor (ani .bak) =
      # cisty stav -> seed. Poskodeny/nevalidny/novsi = READ-ONLY (mutacie
      # odmietnute priamo v zapisovej ceste), citanie bezi dalej z toho, co
      # sa da (JsonFileStore .bak recovery).
      def assess!
        @state = :ok
        @state_reason = ''
        unless JsonFileStore.available?(path)
          seed!
          return @state
        end
        # GH #99 P1: poskodeny PRIMAR s platnou .bak = READ-ONLY, nie ticha
        # zaloha — mutacia nad fallbackom by prepisala primar STARSIM obsahom
        # a znicila by opravitelne zmeny od poslednej zalohy. Citanie dalej
        # bezi z .bak (JsonFileStore recovery), zapisy stoja.
        if File.exist?(path)
          begin
            JSON.parse(File.binread(path))
          rescue StandardError
            return set_read_only('katalóg kovania je poškodený — číta sa záloha, zápisy sú vypnuté (oprav/zmaž súbor)')
          end
        end
        data = begin
          JsonFileStore.read(path)
        rescue StandardError
          nil
        end
        if data.nil?
          set_read_only('katalóg kovania je poškodený (JSON sa nedá prečítať)')
        elsif !data.is_a?(Hash) || !data['items'].is_a?(Array)
          set_read_only('katalóg kovania má neznámy tvar (chýba items)')
        elsif data['std'].to_s != STD
          set_read_only('katalóg kovania patrí inému systému (std)')
        elsif data['schema'].to_i > SCHEMA_CURRENT
          set_read_only('katalóg kovania je v novšej verzii — aktualizuj plugin')
        elsif data['items'].any? { |i| !valid_stored_item?(i) }
          set_read_only('katalóg kovania obsahuje nečitateľné položky')
        elsif duplicate_codes?(data['items'])
          # GH #99 P2: dva kody lisiace sa len velkostou/medzerami = nejednoznacna
          # identita (find/patch/delete by operovali len s jednym riadkom).
          set_read_only('katalóg kovania má duplicitné kódy — oprav súbor')
        end
        # D1 F8: upgrade seed sady bezi az nad ZDRAVYM katalogom (:ok) —
        # read-only stavy sa nikdy nemutuju. Zlyhanie patchu nezhadzuje boot.
        if @state == :ok && data.is_a?(Hash) && data['seed_version'].to_i < SEED_SET_VERSION
          begin
            apply_seed_patches!
          rescue StandardError => e
            Engine.log_error(e, 'HardwareCatalog.apply_seed_patches!') if defined?(Engine)
          end
        end
        @state
      end

      def duplicate_codes?(items)
        seen = {}
        items.each do |i|
          key = i['item_code'].to_s.strip.downcase
          return true if seen[key]
          seen[key] = true
        end
        false
      end

      def set_read_only(reason)
        @state = :read_only
        @state_reason = reason
        Engine.log("kovanie katalog: READ-ONLY — #{reason}") if defined?(Engine)
        @state
      end

      def read_only?
        assess! if @state.nil?
        @state == :read_only
      end

      def state
        assess! if @state.nil?
        @state
      end

      def state_reason
        @state_reason.to_s
      end

      # Test-only reset modulovych stavov (state, proposaly, zamok).
      def reset_state!
        @state = nil
        @state_reason = ''
        @price_proposals = {}
        @lock_depth = 0
        true
      end

      # Minimalna citatelnost ulozeneho riadku — tvrdsie veci strazi
      # normalize/validate pri zapise; tu len to, co by zhodilo citacie cesty.
      # KOV-B1: `manufacturer`/`series` musia byt Stringy — novsia verzia im
      # moze dat iny TVAR (objekt s id a nazvom) a nase citanie by ho ticho
      # zmenilo na nezmyselny retazec. Ne-String = „necitatelne polozky"
      # (assess! -> read-only), nikdy tichy prepis.
      def valid_stored_item?(item)
        item.is_a?(Hash) && !item['item_code'].to_s.strip.empty? &&
          !item['name_sk'].to_s.strip.empty? &&
          %w[manufacturer series].all? { |k| item[k].nil? || item[k].is_a?(String) }
      end

      # --- citanie ------------------------------------------------------------

      def load
        assess! if @state.nil?
        data = begin
          JsonFileStore.read(path)
        rescue StandardError
          nil
        end
        items = data.is_a?(Hash) && data['items'].is_a?(Array) ? data['items'] : []
        { 'items' => items.select { |i| valid_stored_item?(i) } }
      end

      def items
        load['items']
      end

      def find(code)
        c = code.to_s.strip.downcase
        return nil if c.empty?
        items.find { |i| i['item_code'].to_s.strip.downcase == c }
      end

      def catalog_revision
        Digest::SHA1.hexdigest(JSON.generate(load))[0, 12]
      end

      def record_rev(rec)
        Digest::SHA1.hexdigest(JSON.generate(rec))[0, 12]
      end

      # --- normalizacia + validacia -------------------------------------------

      # -> [rec, nil] | [nil, chyba]. Identita a povinne polia; enum kategorie
      # a MJ; cena cez Materials.normalize_price (jedna autorita nil!=0).
      def normalize_item(a)
        code = (a['item_code'] || a[:item_code]).to_s.strip
        return [nil, 'položka bez kódu'] if code.empty?
        name = (a['name_sk'] || a[:name_sk]).to_s.strip
        return [nil, 'položka bez názvu'] if name.empty?
        category = (a['category'] || a[:category]).to_s.strip.upcase
        return [nil, "neznáma kategória „#{category}“"] unless CATEGORIES.include?(category)
        unit = canonical_unit((a['unit'] || a[:unit]).to_s)
        return [nil, "neznáma merná jednotka „#{a['unit'] || a[:unit]}“"] unless unit
        out = { 'item_code' => code, 'name_sk' => name,
                'category' => category, 'unit' => unit }
        price = Materials.normalize_price(a['price_eur_vat'] || a[:price_eur_vat])
        # GH #99 P2: zaporna cena by presla do cenotvorby, nekonecno (1e999)
        # by zhodilo JSON serializaciu — cena musi byt konecna a nezaporna
        # (0 je legalna; nil = nezadana, kluc chyba).
        if !price.nil? && (!price.finite? || price.negative?)
          return [nil, 'cena musí byť nezáporné číslo']
        end
        out['price_eur_vat'] = price unless price.nil?
        put_opt(out, 'supplier', a['supplier'] || a[:supplier])
        put_opt(out, 'notes', a['notes'] || a[:notes])
        # KOV-B1: vyrobca a rada z TAXONOMIE (`HardwareTaxonomy`) — obe
        # VOLITELNE (podperky ani skrutky ziadneho vyrobcu mat nemusia).
        # Ulozeny je KANONICKY NAZOV, nie id — cestuje medzi PC bez joinu.
        # Clenstvo v taxonomii tu NEOVERUJEME: `normalize_item` je cista
        # funkcia a bezi aj v citacich cestach nad datami z inych PC.
        put_opt(out, 'manufacturer', a['manufacturer'] || a[:manufacturer])
        put_opt(out, 'series', a['series'] || a[:series])
        # active: default true, kluc sa uklada LEN pri false (sparse, Q1).
        raw_active = a.key?('active') ? a['active'] : a[:active]
        out['active'] = false if raw_active == false || raw_active.to_s.strip.downcase == 'false'
        # Pohybliva cenova cache — polia sa NESU (merge-safe), zapisuje ich
        # vyhradne proposal flow / seed s vedomym povodom.
        put_opt(out, 'demos_url', a['demos_url'] || a[:demos_url])
        put_opt(out, 'price_checked_at', a['price_checked_at'] || a[:price_checked_at])
        uc = (a['use_count'] || a[:use_count]).to_i
        out['use_count'] = uc if uc.positive?
        [out, nil]
      end

      def canonical_unit(raw)
        UNIT_ALIASES[raw.to_s.strip.downcase]
      end

      # KOV-B1: LAZY marker schemy podla obsahu. `SCHEMA_CLASSIFIED` dostane LEN
      # katalog, ktory bez novych poli citat NEJDE — teda ten, kde ma aspon
      # jedna polozka vyrobcu alebo radu.
      def schema_for(items)
        classified = Array(items).any? do |i|
          i.is_a?(Hash) &&
            (!i['manufacturer'].to_s.strip.empty? || !i['series'].to_s.strip.empty?)
        end
        classified ? SCHEMA_CLASSIFIED : SCHEMA_BASE
      end

      # KOV-B1: patri vyrobca (a pripadna rada) polozky do TAXONOMIE?
      # Rovnake pravidlo ako pri sete (`HardwareSets.taxonomy_refusal`):
      # bez vyrobcu sa nekontroluje nic, s vyrobcom musi meno v zozname EXISTOVAT
      # a rada mu musi patrit — inak by v katalogu za mesiac boli „Hettich",
      # „hettich" aj „Hettch" a strom (KOV-B2) ani filtre (KOV-D) by na nich
      # nesadli.
      #
      # Bezi ZAMERNE MIMO `with_lock`: taxonomia ma svoj vlastny zamok
      # (`materials.lock`) a vnorit ho do katalogoveho by vyrobilo PORADIE
      # zamkov — presne to riziko, kvoli ktoremu maju vsetky katalogy jeden
      # spolocny sidecar. Kontroluje sa HODNOTA, ktoru pouzivatel nastavuje;
      # identitu riadku strazi `row_rev` uz pod zamkom.
      # -> nil (v poriadku) | [:invalid, dovod] | [:read_only, dovod]
      def taxonomy_refusal(manufacturer, series)
        man = manufacturer.to_s.strip
        ser = series.to_s.strip
        return nil if man.empty? && ser.empty?
        # FAIL-CLOSED: nad nekompatibilnou taxonomiou `load` nic nevyda, takze
        # kontrola by hlasila „vyrobca nie je v zozname" namiesto skutocneho
        # dovodu. Polozka BEZ vyrobcu sa uklada dalej.
        return [:invalid, HardwareTaxonomy.state_reason] if HardwareTaxonomy.read_only?

        errs = HardwareTaxonomy.check_classification(man, ser)
        errs.empty? ? nil : [:invalid, errs.first['msg']]
      end

      def put_opt(out, key, raw)
        v = raw.to_s.strip
        out[key] = v unless v.empty?
      end

      # --- mutacie (vsetko pod zamkom, fresh load, revision guardy) -----------

      # CREATE — kod nesmie existovat (CI); patch existujuceho = patch_item.
      # -> [:ok, rec] | [:exists|:invalid|:read_only|:write_failed, info]
      def create_item(attrs)
        return [:read_only, state_reason] if read_only?
        rec, err = normalize_item(attrs)
        return [:invalid, err] if rec.nil?
        # create NIKDY nepreberie cache polia z klienta (F7) — vznikaju len
        # proposal flowom; seed ma vlastnu cestu (seed_write!).
        rec.delete('demos_url')
        rec.delete('price_checked_at')
        rec.delete('use_count')
        refusal = taxonomy_refusal(rec['manufacturer'], rec['series'])
        return refusal if refusal

        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          if data['items'].any? { |i| i['item_code'].to_s.strip.downcase == rec['item_code'].downcase }
            return [:exists, rec['item_code']]
          end
          data['items'] = data['items'] + [rec]
          return [:write_failed, nil] unless write_unlocked(data)
          [:ok, rec]
        end
      end

      # PATCH — whitelist poli, identita nemenna, row_rev baseline povinny.
      # Zmena ceny/MJ alebo vymazanie URL zmaze price_checked_at (F5); prazdna
      # hodnota demos_url vymaze vazbu, neprazdna sa patchom ODMIETNE
      # (URL zapisuje vyhradne proposal flow so sanitize).
      # -> [:ok, rec] | [:not_found|:conflict|:invalid|:read_only|:write_failed, info]
      def patch_item(code, patch, row_rev:)
        return [:read_only, state_reason] if read_only?
        clean = patch.is_a?(Hash) ? patch.select { |k, _| PATCHABLE.include?(k) } : {}
        return [:invalid, 'žiadne editovateľné pole'] if clean.empty?
        if !clean['demos_url'].to_s.strip.empty?
          return [:invalid, 'adresu produktu nastavuje overenie ceny — vlož ju tam']
        end
        # Necislo v cene = ODMIETNUT (prazdne = vedome vymazanie ceny);
        # normalize by necislo ticho zahodil a cena by zmizla bez varovania.
        if clean.key?('price_eur_vat') && !clean['price_eur_vat'].to_s.strip.empty? &&
           Materials.normalize_price(clean['price_eur_vat']).nil?
          return [:invalid, 'cena musí byť číslo (alebo prázdna = nezadaná)']
        end
        # KOV-B1: taxonomia sa overuje nad EFEKTIVNOU dvojicou (patch prebija
        # ulozene hodnoty) a MIMO zamku — viz `taxonomy_refusal`.
        base = find(code) || {}
        refusal = taxonomy_refusal(
          clean.key?('manufacturer') ? clean['manufacturer'] : base['manufacturer'],
          clean.key?('series') ? clean['series'] : base['series']
        )
        return refusal if refusal

        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          existing = data['items'].find { |i| i['item_code'].to_s.strip.downcase == code.to_s.strip.downcase }
          return [:not_found, nil] unless existing
          if row_rev.to_s.empty? || row_rev.to_s != record_rev(existing)
            return [:conflict, nil]
          end
          merged = existing.merge(clean)
          # F5: datum overenia patri konkretnej vazbe (URL) + cene + MJ —
          # manualna zmena ktorehokolvek ho zneplatni.
          if clean.key?('price_eur_vat') || clean.key?('unit') || clean.key?('demos_url')
            merged.delete('price_checked_at')
          end
          merged.delete('demos_url') if clean.key?('demos_url') # prazdna = vymazat vazbu
          rec, err = normalize_item(merged)
          return [:invalid, err] if rec.nil?
          data['items'] = data['items'].map { |i| i.equal?(existing) ? rec : i }
          return [:write_failed, nil] unless write_unlocked(data)
          [:ok, rec]
        end
      end

      # DELETE — usage guard mapovani pride v davke D (audit N13).
      def delete_item(code, row_rev:)
        return [:read_only, state_reason] if read_only?
        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          existing = data['items'].find { |i| i['item_code'].to_s.strip.downcase == code.to_s.strip.downcase }
          return [:not_found, nil] unless existing
          if row_rev.to_s.empty? || row_rev.to_s != record_rev(existing)
            return [:conflict, nil]
          end
          data['items'] = data['items'].reject { |i| i.equal?(existing) }
          price_proposals.delete(existing['item_code'].to_s)
          return [:write_failed, nil] unless write_unlocked(data)
          [:ok, nil]
        end
      end

      def write_unlocked(data)
        if read_only?
          Engine.log("kovanie katalog: zapis odmietnuty — #{state_reason}") if defined?(Engine)
          return false
        end
        # GH #99 P1: cached :ok NIE JE dokaz aktualneho stavu — iny proces /
        # novsi plugin mohol subor medzitym nahradit novsou schemou a tento
        # zapis by ju ticho zhodil na 1 (zahodil by novsie polia). Marker sa
        # cita CERSTVO z disku pod zamkom pred KAZDYM zapisom.
        if File.exist?(path)
          fresh = begin
            JSON.parse(File.binread(path))
          rescue StandardError
            nil
          end
          if fresh.is_a?(Hash) &&
             (fresh['std'].to_s != STD || fresh['schema'].to_i > SCHEMA_CURRENT)
            set_read_only(fresh['std'].to_s != STD ? 'katalóg kovania patrí inému systému (std)' : 'katalóg kovania je v novšej verzii — aktualizuj plugin')
            return false
          end
        end
        # seed_version cestuje s dokumentom (F8): explicitna hodnota z patch
        # cesty > cerstva hodnota z disku > 1 (legacy subor pred D1). Bezne
        # mutacie (create/patch/delete) ju tak zachovaju bez vlastnej rezie.
        stored_sv = fresh.is_a?(Hash) ? fresh['seed_version'].to_i : 0
        sv = (data['seed_version'] || (stored_sv.positive? ? stored_sv : 1)).to_i
        # KOV-B1: marker sa stampuje podla OBSAHU, nie konstantou — katalog bez
        # vyrobcov ostava citatelny pre starsie verzie (vzor `snapshot_std`).
        payload = { 'std' => STD, 'schema' => schema_for(data['items']),
                    'seed_version' => sv, 'items' => data['items'] }
        JsonFileStore.write(path, payload)
      rescue StandardError => e
        # GH #99 P2: plny disk / nezapisovatelny priecinok / zlyhany rename
        # RAISNE z JsonFileStore — volajuci ma dostat :write_failed, nie
        # vynimku bez normalnej odpovede.
        Engine.log_error(e, 'HardwareCatalog.write') if defined?(Engine)
        false
      end

      # --- vyhladavanie (JEDINA autorita — UI len renderuje, F12) -------------

      # Tokenizovane skore s diakritickou normalizaciou (autorita Materials.slug).
      # KAZDY token dotazu musi matchnut; skore aditivne, use_count LEN
      # tie-break (vedome nie skore), potom item_code. Neaktivne polozky sa
      # vracaju IBA na presnu zhodu kodu — alebo s include_inactive (C-2
      # filter "zobrazit neaktivne", audit F10: inak sa nedaju najst a ozivit).
      def search(list, query, category: nil, top: 20, include_inactive: false)
        search_with_total(list, query, category: category, top: top,
                                       include_inactive: include_inactive).first
      end

      # TEST-1: to iste hladanie, ale vracia AJ CELKOVY POCET zhod pred
      # orezanim (`[items, total]`). Bez neho sa nedalo poctivo povedat, ze
      # zoznam nie je cely — a prave to zhorelo pri prvom teste v0.8.0:
      # NOVA polozka ma `use_count` 0, takze pri radeni score -> -use_count
      # skoncila za prvou pädesiatkou a z UI ZMIZLA BEZ SLOVA (zasada
      # „no silent caps": kazde orezanie sa musi priznat).
      def search_with_total(list, query, category: nil, top: 20, include_inactive: false)
        q = norm_text(query)
        cat = category.to_s.strip.upcase
        pool = list.select { |i| cat.empty? || i['category'].to_s == cat }
        exact_code = pool.find { |i| norm_text(i['item_code']) == q && !q.empty? }
        scored = []
        pool.each do |i|
          active = i['active'] != false
          next unless active || include_inactive || i.equal?(exact_code)
          s = score_item(i, q)
          scored << [s, -i['use_count'].to_i, i['item_code'].to_s, i] if s
        end
        sorted = scored.sort_by { |s, uc, code, _| [-s, uc, code] }
        [sorted.first(top).map(&:last), sorted.length]
      end

      def score_item(item, q)
        return 1 if q.empty? # prazdny dotaz = zoznam (score konstantne, sort tie-breakmi)
        code = norm_text(item['item_code'])
        name = norm_text(item['name_sk'])
        # KOV-B1: hladanie indexuje AJ vyrobcu a radu — bez toho by sa polozka
        # „hettich" ci „atira" nedala najst inak nez presnym kodom (a strom
        # KOV-B2 by mal filter, ktory hladanie nevie zopakovat).
        extra = "#{norm_text(item['supplier'])} #{norm_text(item['notes'])} " \
                "#{norm_text(item['manufacturer'])} #{norm_text(item['series'])}"
        total = 0
        q.split(' ').each do |tok|
          t = 0
          if code.start_with?(tok) then t = 100
          elsif code.include?(tok) then t = 25
          elsif name.start_with?(tok) then t = 50
          elsif name.include?(tok) then t = 10
          elsif extra.include?(tok) then t = 5
          end
          return nil if t.zero? # kazdy token musi matchnut
          total += t
        end
        total
      end

      # Diakriticka normalizacia cez Materials.slug (jedina translit autorita)
      # -> lowercase slova oddelene medzerou.
      def norm_text(value)
        v = value.to_s.strip
        return '' if v.empty?
        Materials.slug(v).downcase.tr('_', ' ')
      end

      # --- pohybliva cenova cache (BLOCKER 1: serverovy proposal store) -------

      def price_proposals
        @price_proposals ||= {}
      end

      # Zivy check ceny JEDNEJ polozky. url: nova adresa (prva vazba / zmena),
      # inak sa pouzije ulozena demos_url. Vysledok ide callbackom; navrh sa
      # NEUKLADA do katalogu — vznikne proposal v pamati servera a zapis robi
      # az apply_price_proposal! (klientska cena sa NIKDY neprijima).
      # result: {'ok'=>bool,'status'=>'proposal'|'unchanged'|'error',
      #          'error'=>..,'old'=>..,'new'=>..,'url'=>..}
      def check_price!(code, url: nil, &callback)
        rec = find(code)
        return finish_check(callback, 'ok' => false, 'status' => 'error',
                            'error' => 'položka sa nenašla') unless rec
        raw_url = url.to_s.strip.empty? ? rec['demos_url'].to_s : url.to_s
        clean, err = Demos.sanitize_url(raw_url)
        return finish_check(callback, 'ok' => false, 'status' => 'error',
                            'error' => err || 'položka nemá adresu produktu — vlož URL z Demosu') unless clean
        ctx = { 'done' => false, 'callback' => callback, 'code' => rec['item_code'].to_s }
        start_check_watchdog(ctx)
        Demos.fetch(clean) do |res|
          next if ctx['done']
          handle_check_response(ctx, rec, res)
        end
        true
      end

      # F8: navrh vznika LEN pri kompletnom preflighte — res ok, parser ok,
      # kod stranky == item_code (identita — kovanie MA kod priamo na stranke),
      # kanonicka MJ sedi (ziadne prepocty), cena S DPH kladna a konecna.
      def handle_check_response(ctx, rec, res)
        code = ctx['code']
        unless res['ok']
          return finish_check_ctx(ctx, 'ok' => false, 'status' => 'error', 'error' => res['error'].to_s)
        end
        parsed = DemosProductParser.parse(res['body'])
        unless parsed['ok']
          return finish_check_ctx(ctx, 'ok' => false, 'status' => 'error',
                                  'error' => 'stránka nie je produktový detail')
        end
        unless parsed['code'].to_s == code
          return finish_check_ctx(ctx, 'ok' => false, 'status' => 'error',
                                  'error' => "stránka patrí kódu #{parsed['code']} — nesedí s položkou #{code}")
        end
        page_unit = canonical_unit(parsed['unit'])
        unless page_unit && page_unit == rec['unit'].to_s
          return finish_check_ctx(ctx, 'ok' => false, 'status' => 'error',
                                  'error' => "jednotka stránky „#{parsed['unit']}“ nesedí s katalógovou „#{rec['unit']}“")
        end
        price = parsed['price_vat']
        unless price.is_a?(Numeric) && price.positive? && price.to_f.finite?
          # F8: cena LEN bez DPH sa NIKDY nenavrhuje (standard §7.1).
          return finish_check_ctx(ctx, 'ok' => false, 'status' => 'error',
                                  'error' => 'stránka nemá použiteľnú cenu s DPH')
        end
        old = rec['price_eur_vat']
        unchanged = !old.nil? && (price.to_f - old.to_f).abs < PRICE_TOLERANCE
        # GH #99 P2: pid = identita KONKRETNEHO navrhu — dva prekryvajuce sa
        # checky tej istej polozky by inak zdielali slot a apply by mohol
        # zapisat neskorsi navrh, ktory pouzivatel nevidel.
        pid = next_proposal_id
        price_proposals[code] = {
          'pid' => pid, 'price_vat' => price.to_f.round(4),
          'final_url' => res['url'].to_s,
          'base_row_rev' => record_rev(rec), 'unchanged' => unchanged
        }
        finish_check_ctx(ctx, 'ok' => true,
                              'status' => unchanged ? 'unchanged' : 'proposal',
                              'old' => old, 'new' => price.to_f.round(4),
                              'url' => res['url'].to_s, 'pid' => pid)
      end

      def next_proposal_id
        @proposal_seq = @proposal_seq.to_i + 1
        "p#{@proposal_seq}"
      end

      # Zapis navrhu — VYHRADNE zo serveroveho proposalu (accept flag, ziadna
      # hodnota z klienta). pid viaze zapis na navrh, ktory pouzivatel VIDEL
      # (GH #99 P2 — prekryvajuce sa checky); baseline = row_rev z CASU checku,
      # zaznam zmeneny medzitym = :conflict a proposal sa zahodi (novy check).
      # GH #99 P2: 'unchanged' navrh ZACHOVA ulozenu cenu (4.18 vs 4.184 na
      # stranke je "nezmenene" — katalogova hodnota sa nesmie posunut) a
      # obnovi len vazbu URL + datum overenia.
      # -> [:ok, rec] | [:no_proposal|:not_found|:conflict|:read_only|:write_failed, info]
      def apply_price_proposal!(code, pid: nil)
        return [:read_only, state_reason] if read_only?
        key = code.to_s.strip
        proposal = price_proposals[key]
        return [:no_proposal, nil] unless proposal
        return [:no_proposal, nil] if pid.to_s != proposal['pid'].to_s
        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          existing = data['items'].find { |i| i['item_code'].to_s == key }
          unless existing
            price_proposals.delete(key)
            return [:not_found, nil]
          end
          if record_rev(existing) != proposal['base_row_rev']
            price_proposals.delete(key)
            return [:conflict, nil]
          end
          patch = {
            'demos_url' => proposal['final_url'],
            'price_checked_at' => Time.now.utc.iso8601 # server stamp (F5/FIX 10 vzor B)
          }
          patch['price_eur_vat'] = proposal['price_vat'] unless proposal['unchanged']
          merged = existing.merge(patch)
          rec, err = normalize_item(merged)
          return [:invalid, err] if rec.nil?
          data['items'] = data['items'].map { |i| i.equal?(existing) ? rec : i }
          return [:write_failed, nil] unless write_unlocked(data)
          price_proposals.delete(key)
          [:ok, rec]
        end
      end

      # --- V0.6 D2: "Pridat z Demosu" (novy zaznam z produktovej stranky) -----
      # Vzor M-A + check_price!: fetch/parse VYHRADNE server, klient posiela
      # len URL a potvrdenie; hodnoty (kod/nazov/cena/MJ) sa z klienta NIKDY
      # neprijimaju — zapisuje sa serverovy proposal (pid). Kategoria je len
      # NAVRH (heuristika zo slugu/nazvu) — pouzivatel ju moze zmenit; notes
      # volitelne. Vazba demos_url + price_checked_at = server stamp.

      # Navrh kategorie z URL slugu + nazvu (diakritika von cez Materials.slug).
      # Poradie zalezi: specifickejsie vzory skor (podperka je SPOJOVACI, nie
      # NOHY; uholnik "Bystrica" = SPOJOVACI_MATERIAL — debata 2.8.).
      CATEGORY_GUESS = [
        ['SPOJOVACI_MATERIAL', /skrutk|konfirmat|podperk|kolik|vrut|spojk|excentr|uholnik|zavesne-kovanie|rektifik/],
        ['ZAVESY',   /zaves|sensys|intermat|klip-top|clip-top|tipon|tip-on|podlozk/],
        ['VYSUVY',   /vysuv|zasuvk|atira|strongmax|strongbox|legrabox|quadro|innotech|reling|celovysuv/],
        ['VYKLOPY',  /vyklop|aventos|vzper/],
        ['NOHY',     /noha|nozk|klzak|sokl|axilo|podnoz/],
        ['UCHYTKY',  /uchytk|knopk|madlo/],
        ['VESIAKY',  /vesiak|hacik/],
        ['OSVETLENIE', /led-|led$|-led|svietidl|trafo|napajac|profil/]
      ].freeze

      def category_guess(text)
        t = Materials.slug(text.to_s).downcase.tr('_', '-')
        CATEGORY_GUESS.each { |(cat, re)| return cat if t.match?(re) }
        'OSTATNE'
      end

      def create_proposals
        @create_proposals ||= {}
      end

      # Async preview: URL -> fetch -> parse -> proposal (server pamat, pid).
      # result: {'ok'=>bool, 'error'=>.., pid/code/name_sk/unit/price_vat/
      #          category_guess/url/exists/related[]}
      def demos_preview!(url, &callback)
        clean, err = Demos.sanitize_url(url.to_s)
        unless clean
          return finish_check(callback, 'ok' => false,
                                        'error' => err || 'vlož adresu produktu z demos-trade.sk')
        end
        ctx = { 'done' => false, 'callback' => callback }
        start_check_watchdog(ctx)
        Demos.fetch(clean) do |res|
          next if ctx['done']
          finish_check_ctx(ctx, build_create_proposal(clean, res))
        end
        true
      end

      # Cista stavba proposalu z parsovanej stranky (testovatelne bez siete).
      def build_create_proposal(url, res)
        return { 'ok' => false, 'error' => res['error'].to_s } unless res['ok']
        # GH #128 P2: po presmerovani je autoritou KONECNA adresa (vzor
        # check_price!) — stara/presunuta URL by sa ulozila ako mrtva vazba
        # a buduce obnovenie ceny by na nej padlo.
        final_url = res['url'].to_s.strip.empty? ? url : res['url'].to_s
        # GH #128 P2: vlozena MATERIALOVA adresa sa do katalogu kovania
        # nedostane (parsuje sa rovnako dobre — kod, MJ ks, cena) — inak by
        # doska skoncila ako kovanie 'OSTATNE' a dala sa vybrat do setu.
        mat_type = DemosNameSearch.type_of(DemosSlugMatcher.slug_of(final_url))
        if mat_type
          return { 'ok' => false,
                   'error' => "toto je materiál (#{mat_type}), nie kovanie — zakladá sa v sekcii Materiály (Štúdio)" }
        end
        parsed = DemosProductParser.parse(res['body'])
        return { 'ok' => false, 'error' => 'stránka nie je produktový detail' } unless parsed['ok']
        code = parsed['code'].to_s.strip
        return { 'ok' => false, 'error' => 'stránka nemá kód sortimentu' } if code.empty?
        name = parsed['title'].to_s.strip
        return { 'ok' => false, 'error' => 'stránka nemá názov produktu' } if name.empty?
        unit = canonical_unit(parsed['unit'])
        return { 'ok' => false, 'error' => "neznáma merná jednotka „#{parsed['unit']}“" } unless unit
        price = parsed['price_vat']
        price = nil unless price.is_a?(Numeric) && price.positive? && price.to_f.finite?
        pid = next_proposal_id
        # GH #128 P2: datum overenia patri CASU FETCHU, nie kliku na Vytvorit —
        # nahlad otvoreny cez noc by inak staru cenu oznacil za overenu dnes.
        prop = { 'pid' => pid, 'url' => final_url, 'code' => code, 'name_sk' => name,
                 'unit' => unit, 'price_vat' => price,
                 'fetched_at' => Time.now.utc.iso8601,
                 'category_guess' => category_guess("#{final_url} #{name}") }
        create_proposals.clear if create_proposals.length > 8 # bounded pamat
        create_proposals[pid] = prop
        related = Array(parsed['related']).first(10).map do |r|
          { 'code' => r['code'].to_s, 'name' => r['name'].to_s }
        end
        prop.merge('ok' => true, 'exists' => !find(code).nil?, 'related' => related)
      end

      # Zapis z proposalu (pid = navrh, ktory pouzivatel VIDEL). Kategoriu
      # smie klient zmenit (enum gardi normalize_item), notes volitelne.
      # -> [:ok, rec] | [:no_proposal|:exists|:invalid|:read_only|:write_failed, info]
      def create_from_demos!(pid, category: nil, notes: nil)
        prop = create_proposals[pid.to_s]
        return [:no_proposal, nil] unless prop
        attrs = { 'item_code' => prop['code'], 'name_sk' => prop['name_sk'],
                  'category' => (category.to_s.strip.empty? ? prop['category_guess'] : category),
                  'unit' => prop['unit'], 'supplier' => 'Demos' }
        attrs['price_eur_vat'] = prop['price_vat'] unless prop['price_vat'].nil?
        n = notes.to_s.strip
        attrs['notes'] = n unless n.empty?
        rec, err = normalize_item(attrs)
        return [:invalid, err] if rec.nil?
        # Server-stamped vazba: URL aj cena pochadzaju z FETCHU (nie z kliku) —
        # datum overenia patri cene (bez ceny sa neuklada; "Overit" ho doplni).
        rec['demos_url'] = prop['url']
        if rec.key?('price_eur_vat')
          rec['price_checked_at'] = prop['fetched_at'].to_s.empty? ? Time.now.utc.iso8601
                                                                  : prop['fetched_at']
        end
        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          if data['items'].any? { |i| i['item_code'].to_s.strip.downcase == rec['item_code'].downcase }
            return [:exists, rec['item_code']]
          end
          data['items'] = data['items'] + [rec]
          return [:write_failed, nil] unless write_unlocked(data)
          create_proposals.delete(pid.to_s)
          [:ok, rec]
        end
      end

      # --- seed ---------------------------------------------------------------
      # Deterministicky manifest (audit BLOCKER 2) — 1 riadok = 1 item_code,
      # presny nazov/kategoria/MJ/cena S DPH z DEMOS CSV (autorita nazvov a
      # cien) + Gmail/Disk sond (SYSTEM/zdroje/SEED_KATALOG_2026-07.md).
      # nil cena = nezadana (sondy maju len ceny zostav). Krytky Sensys
      # 105408/105425 doplnil Michal pri debate 2.8. (predtym kod chybal vo
      # vsetkych zdrojoch); nazvy su opisne — spresni ich Demos vazba (D2).
      # Sety NIE SU polozky — mapovanie flag->zoznam kodov robi HardwareSets (D1).
      # Zmrazene rozhodnutia manifestu (1.8.2026): TipOn = 250831/250834
      # (CSV riadok 25031 je preklep — Gmail 2x nezavisle plny kod); LED
      # profily = 'ks' s poznamkou "4 m profil" (ziadne prepocty na meter);
      # Aventos HL sa seeduje po PREDAJNYCH komponentoch, nie ako zostava.
      # [kod, nazov, kategoria, MJ, cena|nil, poznamka|nil]
      SEED_ROWS = [
        ['104717', 'HETTICH 9071205 Sensys 8645i 110° TH52, naložený, SiSy', 'ZAVESY', 'ks', 4.18, 'záves „KLASIK"'],
        ['104718', 'HETTICH 9071206 Sensys 8645i 110° TH52, polonaložený, SiSy', 'ZAVESY', 'ks', 5.42, nil],
        ['104719', 'HETTICH 9071207 Sensys 8645i 110° TH52, vložený, SiSy', 'ZAVESY', 'ks', 5.75, nil],
        ['245723', 'HETTICH 9071313 Sensys 8675 110° TH52 P2O (k tip-onu)', 'ZAVESY', 'ks', 4.00, 'bez tlmenia, k tip-onu'],
        ['421309', 'HETTICH 9073673 Sensys 8675 vložený 110° P2O', 'ZAVESY', 'ks', 4.41, 'vložený P2O k tip-onu'],
        ['264246', 'HETTICH 9099540 Sensys 8657i TH52 165°, naložený, SiSy', 'ZAVESY', 'ks', nil, nil],
        ['106412', 'HETTICH 9071656 podložka 8099 s excentrom D=1,5', 'ZAVESY', 'ks', 0.97, '1:1 ku každému závesu'],
        ['105408', 'HETTICH krytka misky Sensys', 'ZAVESY', 'ks', nil, '1:1 ku každému závesu (SET ZÁVES — debata 2.8.)'],
        ['105425', 'HETTICH krytka ramienka Sensys', 'ZAVESY', 'ks', nil, '1:1 ku každému závesu (SET ZÁVES — debata 2.8.)'],
        ['104454', 'Záves chladničkový HETTICH + platničky (komplet)', 'ZAVESY', 'ks', 10.12, nil],
        ['104802', 'HETTICH 9088021 Sensys uhlový W90 TH52', 'ZAVESY', 'ks', nil, 'rohové skrinky'],
        ['250831', 'BLUM 956A1004 TipOn pre záves 76 mm s magnetom, biely', 'ZAVESY', 'ks', nil, 'kód overiť (CSV šablóna má preklep 25031)'],
        ['250834', 'BLUM 956A1004 TipOn pre záves 76 mm s magnetom, čierny', 'ZAVESY', 'ks', nil, nil],
        ['35000', 'Strong tip-on s magnetom (protikus v balení)', 'ZAVESY', 'ks', nil, 'lacná alternatíva'],
        ['357695', 'K-InnoTech Atira čelný biely 420/70, 30 kg, SiSy', 'VYSUVY', 'set', nil, 'K-sada'],
        ['357696', 'K-InnoTech Atira čelný biely 470/70, 30 kg, SiSy', 'VYSUVY', 'set', nil, 'K-sada'],
        ['357775', 'K-InnoTech Atira čelný biely 470/70/176 vr. relingu, 30 kg', 'VYSUVY', 'set', nil, 'K-sada'],
        ['357970', 'K-InnoTech Atira čelný antracit 470/70/176 vr. relingu', 'VYSUVY', 'set', nil, 'K-sada'],
        ['357819', 'K-InnoTech Atira vnútorný biely 470/70', 'VYSUVY', 'set', nil, 'K-sada; + čelo 294940 + príchyt 295276'],
        ['358009', 'K-InnoTech Atira vnútorný antracit 420/70', 'VYSUVY', 'set', nil, 'K-sada; + čelo 294941 + príchyt 295277'],
        ['294940', 'Čelo vnútornej zásuvky 2000/70 biela (Atira)', 'VYSUVY', 'ks', nil, 'profil 2000 mm, reže sa'],
        ['294941', 'Čelo vnútornej zásuvky 2000/70 antracit (Atira)', 'VYSUVY', 'ks', nil, 'profil 2000 mm, reže sa'],
        ['295276', 'Príchyt čela 70 biely, pár (Atira)', 'VYSUVY', 'par', nil, nil],
        ['295277', 'Príchyt čela 70 antracit, pár (Atira)', 'VYSUVY', 'par', nil, nil],
        ['502978', 'K-StrongMax 16 121/350 mm 40 kg, biela', 'VYSUVY', 'set', 30.76, 'K-sada'],
        ['502993', 'K-StrongMax 16 249/450 mm 40 kg, biela', 'VYSUVY', 'set', 42.03, 'K-sada'],
        ['179252', 'StrongBox H86/270 mm biely', 'VYSUVY', 'set', 16.91, nil],
        ['179253', 'StrongBox H86/300 mm biely', 'VYSUVY', 'set', 17.50, nil],
        ['179256', 'StrongBox H86/450 mm biely', 'VYSUVY', 'set', 17.95, nil],
        ['179259', 'StrongBox H140/270 mm biely', 'VYSUVY', 'set', 18.16, nil],
        ['402578', 'K-StrongBox H140/350 s hranatým relingom, biela', 'VYSUVY', 'set', nil, 'K-sada'],
        ['317642', 'K-HETTICH Quadro V6 skrytý celovýsuv 450 mm/30 kg (18 mm)', 'VYSUVY', 'set', nil, 'K-sada'],
        ['499013', 'K-BLUM Legrabox M 450 mm/40 kg Blumotion/TOB, karbón čierna CS-M', 'VYSUVY', 'set', nil, 'K-sada, prémium'],
        ['499307', 'K-BLUM Legrabox K 450 mm/40 kg Tip-on, karbón čierna CS-M, vnútorná', 'VYSUVY', 'set', nil, 'K-sada; + čelný plech 491360 + reling 491359'],
        ['507336', 'BLUM 22F2800 Aventos HF Top silný, skrutky', 'VYKLOPY', 'set', nil, 'krytky NIE sú v balení'],
        ['347827', 'BLUM 22K2700T Aventos HK Top silný, Tip-on', 'VYKLOPY', 'par', nil, 'krytky 347834 zvlášť'],
        ['23792', 'BLUM Aventos HL stredný', 'VYKLOPY', 'ks', nil, 'komponent zostavy HL'],
        ['197611', 'BLUM Aventos HL ramená 450–580', 'VYKLOPY', 'ks', nil, 'komponent zostavy HL'],
        ['13781', 'BLUM čelný príchyt 20S4200 (Aventos HL/HK)', 'VYKLOPY', 'ks', nil, 'komponent zostavy'],
        ['461804', 'BLUM Aventos HL krytky 20L8020', 'VYKLOPY', 'ks', nil, 'krytky vždy zvlášť'],
        ['13799', 'BLUM Aventos HL stabilizačná tyč 20Q1061UA', 'VYKLOPY', 'ks', nil, 'komponent zostavy HL'],
        ['282474', 'IF K12 244 plynokvapalinová vzpera 120 N automatická', 'VYKLOPY', 'ks', nil, 'lacná alternatíva výklopu'],
        ['82744', 'STRONG klzák s rektifikáciou, výška 17 mm, čierny', 'NOHY', 'ks', 0.48, 'najpoužívanejšia „noha"'],
        ['367823', 'Häfele 637.76.355 noha AXILO v. 150 mm + podložka', 'NOHY', 'ks', 1.38, '4 ks na spodnú skrinku'],
        ['93240', 'Rektifikačný uholník „Bystrica" (zavesenie skrinky na stenu)', 'SPOJOVACI_MATERIAL', 'ks', nil, '2 ks na hornú skrinku; NIE noha (debata 2.8.)'],
        ['146993', 'Strong Big rektifikačná noha 100 mm', 'NOHY', 'ks', nil, nil],
        ['360281', 'Skrutka SPAX 3,5×16 záp. hl. (bal 1000 ks)', 'SPOJOVACI_MATERIAL', 'ks', nil, 'predaj v bal 1000'],
        ['228922', 'Skrutka PZ ZH 3,5×30 biely Zn (bal 1000)', 'SPOJOVACI_MATERIAL', 'ks', nil, 'predaj v bal 1000'],
        ['228924', 'Skrutka PZ ZH 3,5×35 biely Zn (bal 1000)', 'SPOJOVACI_MATERIAL', 'ks', nil, 'predaj v bal 1000'],
        ['11090', 'Konfirmát 5/50 Zn biely (bal 2400 ks)', 'SPOJOVACI_MATERIAL', 'ks', 0.07, 'cena za ks'],
        ['11135', 'Skrutka PZ ZH 5×100/60 žltý Zn PZ2 čiastočný závit', 'SPOJOVACI_MATERIAL', 'ks', 0.06, nil],
        ['306125', 'Podperka policová s návlekom 7/5 Zn biela', 'SPOJOVACI_MATERIAL', 'ks', nil, '4 ks na policu'],
        ['402395', 'TULIP úchytka Bastone 320 čierna matná', 'UCHYTKY', 'ks', 4.05, nil],
        ['398095', 'TULIP úchytka zápustná Shellby čierna matná', 'UCHYTKY', 'ks', 12.66, nil],
        ['303211', 'TULIP úchytka Cana 128 biela', 'UCHYTKY', 'ks', 1.97, nil],
        ['401555', 'TULIP úchytka Knop Conic čierna matná', 'UCHYTKY', 'ks', 2.54, nil],
        ['355730', 'TULIP vešiak Kara L čierna matná', 'VESIAKY', 'ks', 13.10, nil],
        ['355731', 'TULIP vešiak Kara M čierna matná', 'VESIAKY', 'ks', 9.27, nil],
        ['252278', 'TM-profil LED Corner alu anodovaný 4000 mm', 'OSVETLENIE', 'ks', 30.79, '4 m profil — cena za kus'],
        ['359426', 'TM-profil LED úchytkový Lucera narážací 4000 + tesnenie', 'OSVETLENIE', 'ks', nil, '4 m profil']
      ].freeze

      SEED_ITEMS = SEED_ROWS.map do |code, name, category, unit, price, note|
        item = { 'item_code' => code, 'name_sk' => name, 'category' => category,
                 'unit' => unit, 'supplier' => 'Demos' }
        item['price_eur_vat'] = price unless price.nil?
        item['notes'] = note unless note.nil?
        item
      end.freeze

      def seed!
        with_lock do
          recs = SEED_ITEMS.map { |a| normalize_item(a)[0] }.compact
          # Cerstvy seed je natívne v aktualnej sade — patch sa ho uz nedotkne.
          write_unlocked('items' => recs, 'seed_version' => SEED_SET_VERSION)
        end
      end

      # --- seed patch existujuceho katalogu (audit D1 F8) ----------------------
      # Bezi z assess! LEN pri stave :ok. Merge-safe: nove kody sa doplnia iba
      # ak item_code neexistuje; oprava povodneho riadku iba ak je bajtovo
      # zhodny s v1 seedom v identitnych poliach a nema Demos vazbu (inak sa
      # nechava + info log). Bump seed_version sa zapise aj bez zmien poloziek
      # (patch sa nabuduce uz neskusa).
      SEED_PATCH_V2_ADD = %w[105408 105425].freeze
      LEGACY_SEED_93240 = { 'item_code' => '93240',
                            'name_sk' => 'Závesné kovanie Bystrica (rektifikát hornej skrinky)',
                            'category' => 'NOHY', 'unit' => 'ks',
                            'supplier' => 'Demos',
                            'notes' => '2 ks na hornú skrinku' }.freeze
      SEED_MATCH_FIELDS = %w[name_sk category unit price_eur_vat notes supplier].freeze

      def apply_seed_patches!
        with_lock do
          JsonFileStore.invalidate(path)
          doc = begin
            JsonFileStore.read(path)
          rescue StandardError
            nil
          end
          return false unless doc.is_a?(Hash) && doc['items'].is_a?(Array)
          from = doc['seed_version'].to_i
          from = 1 if from < 1
          return false if from >= SEED_SET_VERSION
          items = doc['items'].dup
          changed = []
          if from < 2
            seed_by_code = {}
            SEED_ITEMS.each { |s| seed_by_code[s['item_code']] = s }
            SEED_PATCH_V2_ADD.each do |code|
              next if items.any? { |i| i['item_code'].to_s.strip.downcase == code.downcase }
              rec, = normalize_item(seed_by_code[code])
              next unless rec
              items << rec
              changed << "+#{code}"
            end
            idx = items.index { |i| i['item_code'].to_s.strip == '93240' }
            if idx
              legacy, = normalize_item(LEGACY_SEED_93240)
              cur = items[idx]
              untouched = legacy &&
                          SEED_MATCH_FIELDS.all? { |k| cur[k] == legacy[k] } &&
                          cur['demos_url'].to_s.empty?
              if untouched
                fixed, = normalize_item(seed_by_code['93240'])
                if fixed
                  # use_count/active preziju — patch meni len seed polia.
                  items[idx] = cur.merge(fixed)
                  changed << '93240->SPOJOVACI_MATERIAL'
                end
              else
                Engine.log('kovanie katalog: 93240 je upravene pouzivatelom — kategoriu nechavam (patri do SPOJOVACI_MATERIAL)') if defined?(Engine)
              end
            end
          end
          ok = write_unlocked('items' => items, 'seed_version' => SEED_SET_VERSION)
          if ok && defined?(Engine)
            Engine.log("kovanie katalog: seed patch v#{from} -> v#{SEED_SET_VERSION}#{changed.any? ? " (#{changed.join(', ')})" : ''}")
          end
          ok
        end
      end

      def finish_check(callback, result)
        callback.call(result) if callback
        false
      end

      def finish_check_ctx(ctx, result)
        return if ctx['done']
        ctx['done'] = true
        stop_check_watchdog(ctx)
        ctx['callback'].call(result) if ctx['callback']
        nil
      end

      # F8: klient nema HTTP timeout — visiaci request nesmie nechat UI bez
      # odpovede. Headless testy (bez UI timera) watchdog preskocia.
      def start_check_watchdog(ctx)
        return unless Demos.timers_available?
        ctx['watchdog'] = UI.start_timer(WATCHDOG_S, false) do
          finish_check_ctx(ctx, 'ok' => false, 'status' => 'error',
                                'error' => 'Demos neodpovedá — skús znova o chvíľu')
        end
      end

      def stop_check_watchdog(ctx)
        id = ctx.delete('watchdog')
        UI.stop_timer(id) if id && defined?(UI) && UI.respond_to?(:stop_timer)
      rescue StandardError
        nil
      end
    end
  end
end
