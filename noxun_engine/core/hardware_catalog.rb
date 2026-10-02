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
require 'uri'
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
      SCHEMA_PRODUCT_URL = 3
      SCHEMA_MANUAL_CHECK = 4
      SCHEMA_CURRENT = SCHEMA_MANUAL_CHECK
      # H15b: SEED_SET_VERSION a jeho historia su v hardware_catalog_seed.rb.
      FILE = 'hardware_catalog.json'

      CATEGORIES = %w[ZAVESY VYSUVY VYKLOPY NOHY UCHYTKY SPOJOVACI_MATERIAL
                      VESIAKY OSVETLENIE OSTATNE].freeze
      # KOV-B2: SK popisky kategorii — JEDINY zdroj (strom katalogu, filter
      # v liste sekcie aj select v modale polozky). Kod ostava identitou
      # (uklada sa on), popisok je LEN to, co pouzivatel cita; guard test
      # strazi, ze mapa pokryva `CATEGORIES` presne (ziadny kod bez popisku
      # a ziadny popisok bez kodu — inak by strom kreslil holy „SPOJOVACI_
      # MATERIAL" alebo prazdnu hlavicku).
      CATEGORY_LABELS = {
        'ZAVESY' => 'Závesy',
        'VYSUVY' => 'Výsuvy',
        'VYKLOPY' => 'Výklopy',
        'NOHY' => 'Nohy a montáž',
        'UCHYTKY' => 'Úchytky',
        'SPOJOVACI_MATERIAL' => 'Spojovací materiál',
        'VESIAKY' => 'Vešiaky',
        'OSVETLENIE' => 'Osvetlenie',
        'OSTATNE' => 'Ostatné'
      }.freeze
      UNITS = %w[ks set par bal m].freeze

      # KOV-B2: strom Kategoria -> Vyrobca -> Rada. STRANKUJE SA LIST (rada),
      # nie cely zoznam: „ziadne tiche stropy" (TEST-1) plati aj tu, takze
      # kazda uroven nesie `total` (kolko ich je) aj `shown` (kolko ich prislo)
      # a list, ktoremu sa nezmestili vsetky kody, to prizna `more`.
      LEAF_PAGE = 50
      # Synteticke uzly pre polozky bez klasifikacie. Su POSLEDNE vo svojej
      # urovni — skrutky a podperky vyrobcu mat nemusia (KOV-B1) a nesmu
      # zatlacit skutocnych vyrobcov pod zlom stranky.
      TREE_NO_MANUFACTURER = '— bez výrobcu'
      TREE_NO_SERIES = '— bez rady'
      # Vyrobca DOSLOVNE menom „Ostatné" (seed taxonomie) patri na koniec
      # zoznamu vyrobcov — je to zberna kategoria, nie znacka.
      TREE_OTHER_MANUFACTURER = 'Ostatné'
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
                     demos_url manufacturer series product_url].freeze

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
          %w[manufacturer series].all? { |k| item[k].nil? || item[k].is_a?(String) } &&
          (!item.key?('product_url') || item['product_url'].is_a?(String)) &&
          (!item.key?('price_check_method') || item['price_check_method'] == 'manual')
      end

      # load filtruje necitatelne riadky. Pred zapisom treba overit aj cudzie B,
      # inak ho edit citatelneho A zahodi z katalogu.
      def stored_document_issue(data)
        return 'katalóg kovania je poškodený' unless data.is_a?(Hash) && data['items'].is_a?(Array)
        return 'katalóg kovania patrí inému systému (std)' unless data['std'].to_s == STD
        return 'katalóg kovania je v novšej verzii — aktualizuj plugin' if data['schema'].to_i > SCHEMA_CURRENT
        return 'katalóg kovania obsahuje nečitateľné položky' unless data['items'].all? { |i| valid_stored_item?(i) }
        codes = data['items'].map { |i| i['item_code'].to_s.strip.downcase }
        return 'katalóg kovania obsahuje duplicitné kódy' unless codes.uniq.length == codes.length
        nil
      end

      def sanitize_product_url(raw)
        return nil unless raw.is_a?(String)
        s = raw.strip
        return nil if s.empty? || s.match?(/[\s"'<>\\]/)
        uri = begin
          URI.parse(s)
        rescue URI::InvalidURIError
          nil
        end
        return nil unless uri.is_a?(URI::HTTP) && !uri.host.to_s.strip.empty?
        uri.to_s
      end

      # Ulozena Demos vazba ma prednost; druhy odkaz nesmie predstierat zdroj.
      def product_link(rec)
        return nil unless rec.is_a?(Hash)
        source = rec['demos_url'].to_s.strip.empty? ? rec['product_url'] : rec['demos_url']
        sanitize_product_url(source)
      end

      # Cisto citacia cesta: bez assess!/seed migracie, cerstvo z disku.
      def product_record(code)
        JsonFileStore.invalidate(path)
        doc = JsonFileStore.read(path)
        rows = doc.is_a?(Hash) && doc['items'].is_a?(Array) ? doc['items'] : []
        rows.find { |i| valid_stored_item?(i) && i['item_code'].to_s.strip.casecmp?(code.to_s.strip) }
      rescue StandardError
        nil
      end

      def product_edit_reason
        fresh = begin
          JSON.parse(File.binread(path))
        rescue StandardError
          nil
        end
        stored_document_issue(fresh) || (@state == :read_only ? @state_reason : nil)
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
        return [nil, 'položka bez kódu', 'item_code'] if code.empty?
        name = (a['name_sk'] || a[:name_sk]).to_s.strip
        return [nil, 'položka bez názvu', 'name_sk'] if name.empty?
        category = (a['category'] || a[:category]).to_s.strip.upcase
        return [nil, "neznáma kategória „#{category}“", 'category'] unless CATEGORIES.include?(category)
        unit = canonical_unit((a['unit'] || a[:unit]).to_s)
        return [nil, "neznáma merná jednotka „#{a['unit'] || a[:unit]}“", 'unit'] unless unit
        out = { 'item_code' => code, 'name_sk' => name,
                'category' => category, 'unit' => unit }
        price = Materials.normalize_price(a['price_eur_vat'] || a[:price_eur_vat])
        # GH #99 P2: zaporna cena by presla do cenotvorby, nekonecno (1e999)
        # by zhodilo JSON serializaciu — cena musi byt konecna a nezaporna
        # (0 je legalna; nil = nezadana, kluc chyba).
        if !price.nil? && (!price.finite? || price.negative?)
          return [nil, 'cena musí byť nezáporné číslo', 'price_eur_vat']
        end
        out['price_eur_vat'] = price unless price.nil?
        put_opt(out, 'supplier', a['supplier'] || a[:supplier])
        put_opt(out, 'notes', a['notes'] || a[:notes])
        raw_url = a.key?('product_url') ? a['product_url'] : a[:product_url]
        if a.key?('product_url') || a.key?(:product_url)
          return [nil, 'odkaz musí byť text', 'product_url'] unless raw_url.is_a?(String)
          unless raw_url.strip.empty?
            url = sanitize_product_url(raw_url)
            return [nil, 'vlož platný odkaz http:// alebo https://', 'product_url'] unless url
            out['product_url'] = url
          end
        end
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
        if a.key?('price_check_method') || a.key?(:price_check_method)
          method = a.key?('price_check_method') ? a['price_check_method'] : a[:price_check_method]
          return [nil, 'neznámy spôsob overenia ceny', 'price_check_method'] unless method == 'manual'
          out['price_check_method'] = method
        end
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
        return SCHEMA_MANUAL_CHECK if Array(items).any? { |i| i.is_a?(Hash) && i.key?('price_check_method') }
        return SCHEMA_PRODUCT_URL if Array(items).any? { |i| i.is_a?(Hash) && !i['product_url'].to_s.strip.empty? }
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
      # Vracia AJ KANONICKU dvojicu: kontrola je case-insensitive (aby „hettich"
      # nasiel „Hettich"), ale ulozit sa smie vyhradne kanonicky zapis zo
      # zoznamu — inak by v katalogu vyrastlo „hettich" vedla „Hettich"
      # a zoskupenie (KOV-B2) ani filtre (KOV-D) by na tom nesadli.
      # KOV-B2: odmietnutie nesie AJ POLE, ktoreho sa tyka (`manufacturer` /
      # `series`) — modal polozky (D-15) kresli chybu PRI POLI a bez neho by
      # „rada nepatri vyrobcovi" pristala v zbernom pase nad formularom, kde
      # ju pouzivatel k radu nepriradi. Pole dava `resolve_classification`,
      # ktore ho uz vracia pre set (jedna autorita).
      # -> [refusal|nil, canon_manufacturer|nil, canon_series|nil]
      def taxonomy_refusal(manufacturer, series)
        man = manufacturer.to_s.strip
        ser = series.to_s.strip
        return [nil, nil, nil] if man.empty? && ser.empty?
        # FAIL-CLOSED: nad nekompatibilnou taxonomiou `load` nic nevyda, takze
        # kontrola by hlasila „vyrobca nie je v zozname" namiesto skutocneho
        # dovodu. Polozka BEZ vyrobcu sa uklada dalej.
        return [[:invalid, HardwareTaxonomy.state_reason], nil, nil] if HardwareTaxonomy.read_only?

        canon_man, canon_ser, errs = HardwareTaxonomy.resolve_classification(man, ser)
        unless errs.empty?
          return [[:invalid, errs.first['msg'], errs.first['field']], nil, nil]
        end

        [nil, canon_man, canon_ser]
      end

      def put_opt(out, key, raw)
        v = raw.to_s.strip
        out[key] = v unless v.empty?
      end

      # --- mutacie (vsetko pod zamkom, fresh load, revision guardy) -----------

      # CREATE — kod nesmie existovat (CI); patch existujuceho = patch_item.
      # KOV-B2: odmietnutie nesie TRETIM prvkom POLE, ktoreho sa tyka (modal
      # D-15 kresli chybu pri poli). Volajuci, ktory pole nepotrebuje, dalej
      # rozbaluje len `status, info` — tvar je spatne kompatibilny.
      # -> [:ok, rec] | [:exists|:invalid|:read_only|:write_failed, info, field]
      def create_item(attrs)
        return [:read_only, state_reason] if read_only?
        attrs = attrs.reject { |k, _| k.to_s == 'price_check_method' }
        rec, err, field = normalize_item(attrs)
        return [:invalid, err, field] if rec.nil?
        # create NIKDY nepreberie cache polia z klienta (F7) — vznikaju len
        # proposal flowom; seed ma vlastnu cestu (seed_write!).
        rec.delete('demos_url')
        rec.delete('price_checked_at')
        rec.delete('use_count')
        refusal, canon_man, canon_ser = taxonomy_refusal(rec['manufacturer'], rec['series'])
        return refusal if refusal

        # Kluce sa LEN prepisuju (`normalize_item` ich zaklada iba pri neprazdnej
        # hodnote), takze polozke bez vyrobcu sa nic nedoplna.
        rec['manufacturer'] = canon_man if canon_man
        rec['series'] = canon_ser if canon_ser
        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          if data['items'].any? { |i| i['item_code'].to_s.strip.downcase == rec['item_code'].downcase }
            return [:exists, rec['item_code'], 'item_code']
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
      # KOV-B2: `:invalid` nesie TRETIM prvkom pole (vzor `create_item`).
      # -> [:ok, rec] | [:not_found|:conflict|:invalid|:read_only|:write_failed, info, field]
      def patch_item(code, patch, row_rev:)
        return [:read_only, state_reason] if read_only?
        clean = patch.is_a?(Hash) ? patch.select { |k, _| PATCHABLE.include?(k) } : {}
        return [:invalid, 'žiadne editovateľné pole'] if clean.empty?
        if !clean['demos_url'].to_s.strip.empty?
          return [:invalid, 'adresu produktu nastavuje overenie ceny — vlož ju tam', 'demos_url']
        end
        # Necislo v cene = ODMIETNUT (prazdne = vedome vymazanie ceny);
        # normalize by necislo ticho zahodil a cena by zmizla bez varovania.
        if clean.key?('price_eur_vat') && !clean['price_eur_vat'].to_s.strip.empty? &&
           Materials.normalize_price(clean['price_eur_vat']).nil?
          return [:invalid, 'cena musí byť číslo (alebo prázdna = nezadaná)', 'price_eur_vat']
        end
        # KOV-B1: taxonomia sa overuje nad EFEKTIVNOU dvojicou (patch prebija
        # ulozene hodnoty) a MIMO zamku — viz `taxonomy_refusal`.
        base = find(code) || {}
        refusal, canon_man, canon_ser = taxonomy_refusal(
          clean.key?('manufacturer') ? clean['manufacturer'] : base['manufacturer'],
          clean.key?('series') ? clean['series'] : base['series']
        )
        return refusal if refusal

        # Kanonicky tvar sa dosadzuje LEN do klucov, ktore patch NAOZAJ nesie —
        # ulozena hodnota, ktorej sa patch nedotyka, sa nesmie prepisat (patch
        # je uzavrety whitelist zmien, nie prepis celeho zaznamu).
        clean['manufacturer'] = canon_man if clean.key?('manufacturer') && canon_man
        clean['series'] = canon_ser if clean.key?('series') && canon_ser
        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          existing = data['items'].find { |i| i['item_code'].to_s.strip.downcase == code.to_s.strip.downcase }
          return [:not_found, nil] unless existing
          if row_rev.to_s.empty? || row_rev.to_s != record_rev(existing)
            return [:conflict, nil]
          end
          merged = existing.merge(clean)
          if clean.key?('product_url') && !clean['product_url'].to_s.strip.empty? &&
             !existing['demos_url'].to_s.strip.empty? && !clean.key?('demos_url')
            return [:invalid, 'najprv zruš väzbu Demos v detaile položky', 'product_url']
          end
          # F5: datum overenia patri konkretnej vazbe (URL) + cene + MJ —
          # manualna zmena ktorehokolvek ho zneplatni.
          if existing['price_check_method'] != 'manual' &&
             (clean.key?('price_eur_vat') || clean.key?('unit') || clean.key?('demos_url'))
            merged.delete('price_checked_at')
          end
          merged.delete('demos_url') if clean.key?('demos_url') # prazdna = vymazat vazbu
          rec, err, field = normalize_item(merged)
          return [:invalid, err, field] if rec.nil?
          if existing['price_check_method'] == 'manual'
            old_values = { 'price_eur_vat' => Materials.normalize_price(existing['price_eur_vat']),
                           'unit' => canonical_unit(existing['unit']),
                           'product_url' => sanitize_product_url(existing['product_url']),
                           'supplier' => existing['supplier'].to_s.strip }
            changed = old_values.any? do |key, value|
              clean.key?(key) && (key == 'supplier' ? rec[key].to_s : rec[key]) != value
            end
            clear_manual_check!(rec) if changed || clean.key?('demos_url')
          end
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
        if JsonFileStore.available?(path)
          fresh = begin
            JSON.parse(File.binread(File.exist?(path) ? path : "#{path}.bak"))
          rescue StandardError
            nil
          end
          if (issue = stored_document_issue(fresh))
            set_read_only(issue)
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

      # --- KOV-B2: strom Kategoria -> Vyrobca -> Rada -------------------------

      # SK popisok kategorie. Neznamy kod (starsi katalog, cudzi zapis) sa
      # NEPREKLADA — vratime jeho kod, aby bolo VIDNO, co v katalogu je.
      def category_label(code)
        CATEGORY_LABELS[code.to_s] || code.to_s
      end

      # Poradie vyrobcov: kanonicke mena abecedne (bez diakritiky), zberna
      # znacka „Ostatné" predposledna a polozky BEZ vyrobcu uplne posledne.
      def tree_manufacturer_order(name)
        n = name.to_s.strip
        return [2, ''] if n.empty?
        slug = norm_text(n)
        return [1, slug] if slug == norm_text(TREE_OTHER_MANUFACTURER)

        [0, slug]
      end

      # Poradie rad: abecedne, „bez rady" posledna.
      def tree_series_order(name)
        n = name.to_s.strip
        n.empty? ? [1, ''] : [0, norm_text(n)]
      end

      # SERVEROVY strom katalogu (kontrakt „JS poradie nikdy nedoplna" —
      # GH #100 P2): klient posiela dotaz, filter, rozbalene uzly a ziadost
      # o dalsiu stranku listu; vykresli PRESNE to, co pride, vratane poradia.
      #
      # Preco strom a nie plochy zoznam (D-110): katalog realnej dielne ma
      # stovky kodov a plochy zoznam s TICHYM stropom znamenal, ze polozka za
      # poradim `SEARCH_TOP` sa dala najst uz LEN hladanim. Zasada „no silent
      # caps" (TEST-1) preto plati na KAZDEJ urovni: `total` = kolko ich tam
      # je, `shown` = kolko ich naozaj prislo, a list, ktoremu sa nezmestili
      # vsetky kody, to prizna `more`.
      #
      #   `expand` = { kluc uzla => true } — pamat rozbalenia klienta. Plati
      #              LEN pri prazdnom dotaze; hladanie roztvara VYHRADNE
      #              skupiny so zhodami (inak by dotaz „tipon" nechal
      #              najdenu polozku schovanu v zabalenej kategorii).
      #   `more`   = { kluc listu => kolko kodov klient chce } (nasobky
      #              `LEAF_PAGE`); strankuje sa LIST, nie cely strom.
      #   `pin`    = kod prave zalozenej polozky — je v odpovedi VZDY (aj ked
      #              filtru nevyhovuje), navrchu SVOJHO listu, a jeho kategoria
      #              sa rozbali. Bez toho nova polozka zmizne bez slova.
      #
      # Kluc uzla je CESTA `KATEGORIA|Vyrobca|Rada` (kategoria = sam kod).
      # -> { 'groups', 'total', 'shown', 'pin', 'leaf_page', 'q' }
      def build_tree(list, query, category: nil, include_inactive: false,
                     pin: nil, expand: nil, more: nil)
        exp = expand.is_a?(Hash) ? expand : {}
        want_more = more.is_a?(Hash) ? more : {}
        q = query.to_s
        searching = !q.strip.empty?
        # Review #290/2 P2: kategoriu filtrujeme TOU ISTOU mapou, akou strom
        # polozky zaraduje (`tree_category_of`). `search_with_total` porovnava
        # ULOZENU hodnotu doslovne, takze polozka s neznamou kategoriou (starsi
        # alebo cudzi zapis) bola v skupine „Ostatné" vidiet, ale po zapnuti
        # filtra „Ostatné" ZMIZLA — a to je presne ta polozka, ktoru pouzivatel
        # hlada, ked filtruje.
        matched, = search_with_total(list, q, category: nil, top: list.length,
                                              include_inactive: include_inactive)
        cat_filter = category.to_s.strip.upcase
        matched = matched.select { |i| tree_category_of(i) == cat_filter } unless cat_filter.empty?
        # Poradie zhod (score) si drzime ako RANK — v liste sa radi presne
        # podla neho, aby strom vracal to iste poradie ako ploche hladanie.
        rank = {}
        matched.each_with_index { |i, idx| rank[i['item_code'].to_s] = idx }

        pin_code = pin.to_s.strip
        pin_item = pin_code.empty? ? nil : list.find { |i| i['item_code'].to_s == pin_code }
        pin_code = '' if pin_item.nil?
        pool = matched
        pool += [pin_item] if pin_item && !rank.key?(pin_code)

        by_cat = {}
        pool.each do |item|
          cat = tree_category_of(item)
          man = item['manufacturer'].to_s.strip
          ser = item['series'].to_s.strip
          (((by_cat[cat] ||= {})[man] ||= {})[ser] ||= []) << item
        end

        pin_cat = pin_item ? tree_category_of(pin_item) : nil
        groups = []
        CATEGORIES.each do |cat|
          mans = by_cat[cat]
          next if mans.nil? || mans.empty?

          open = searching || exp[cat] == true || cat == pin_cat
          groups << tree_group(cat, mans, open: open, searching: searching,
                                          rank: rank, pin_code: pin_code,
                                          want_more: want_more)
        end
        { 'q' => q, 'groups' => groups,
          'total' => groups.sum { |g| g['total'].to_i },
          'shown' => groups.sum { |g| g['shown'].to_i },
          'pin' => (pin_code.empty? ? nil : pin_code),
          'leaf_page' => LEAF_PAGE }
      end

      # Kategoria, pod ktorou sa polozka v strome objavi. Neznamy kod (cudzi
      # zapis, starsi katalog) padne do „Ostatné" — inak by polozka v strome
      # NEBOLA VOBEC, hoci v katalogu je.
      def tree_category_of(item)
        cat = item['category'].to_s
        CATEGORIES.include?(cat) ? cat : 'OSTATNE'
      end

      def tree_group(cat, mans, open:, searching:, rank:, pin_code:, want_more:)
        nodes = mans.keys.sort_by { |m| tree_manufacturer_order(m) }.map do |man|
          tree_manufacturer(cat, man, mans[man], open: open, searching: searching,
                                                 rank: rank, pin_code: pin_code,
                                                 want_more: want_more)
        end
        { 'key' => cat, 'label' => category_label(cat), 'open' => open,
          'total' => nodes.sum { |n| n['total'].to_i },
          'shown' => nodes.sum { |n| n['shown'].to_i },
          'manufacturers' => nodes }
      end

      def tree_manufacturer(cat, man, sers, open:, searching:, rank:, pin_code:, want_more:)
        nodes = sers.keys.sort_by { |s| tree_series_order(s) }.map do |ser|
          tree_series(cat, man, ser, sers[ser], open: open, searching: searching,
                                                rank: rank, pin_code: pin_code,
                                                want_more: want_more)
        end
        { 'key' => "#{cat}|#{man}",
          'label' => man.strip.empty? ? TREE_NO_MANUFACTURER : man,
          'total' => nodes.sum { |n| n['total'].to_i },
          'shown' => nodes.sum { |n| n['shown'].to_i },
          'series' => nodes }
      end

      def tree_series(cat, man, ser, items, open:, searching:, rank:, pin_code:, want_more:)
        sorted = if searching
                   items.sort_by { |i| [rank[i['item_code'].to_s] || rank.length, i['item_code'].to_s] }
                 else
                   items.sort_by { |i| [norm_text(i['name_sk']), i['item_code'].to_s] }
                 end
        unless pin_code.empty?
          pinned = sorted.find { |i| i['item_code'].to_s == pin_code }
          sorted = [pinned] + sorted.reject { |i| i.equal?(pinned) } if pinned
        end
        key = "#{cat}|#{man}|#{ser}"
        asked = want_more[key].to_i
        limit = asked > LEAF_PAGE ? asked : LEAF_PAGE
        codes = open ? sorted.first(limit).map { |i| i['item_code'].to_s } : []
        { 'key' => key, 'label' => ser.strip.empty? ? TREE_NO_SERIES : ser,
          'total' => sorted.length, 'shown' => codes.length, 'codes' => codes,
          'more' => open && sorted.length > codes.length }
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
          merged.delete('product_url') # explicitne potvrdena Demos vazba nahradi rucny zdroj
          merged.delete('price_check_method')
          rec, err = normalize_item(merged)
          return [:invalid, err] if rec.nil?
          data['items'] = data['items'].map { |i| i.equal?(existing) ? rec : i }
          return [:write_failed, nil] unless write_unlocked(data)
          price_proposals.delete(key)
          [:ok, rec]
        end
      end

      # CENY-KOV-B: jedina cesta, ktora smie zalozit rucne potvrdenie. Cena je
      # uzivatelsky vstup; datum a metoda patria serveru, nie klientskemu echu.
      def confirm_manual_price!(code, price:, row_rev:)
        return [:read_only, state_reason] if read_only?
        amount = (price.is_a?(String) || price.is_a?(Numeric)) ? Materials.normalize_price(price) : nil
        if amount.nil? || !amount.finite? || amount.negative?
          return [:invalid, 'vlož nezápornú cenu s DPH; prázdna cena sa nedá potvrdiť', 'price']
        end
        with_lock do
          JsonFileStore.invalidate(path)
          data = load
          existing = data['items'].find { |i| i['item_code'].to_s.strip.casecmp?(code.to_s.strip) }
          return [:not_found, 'Položka už v katalógu nie je.'] unless existing
          return [:conflict, 'Položka sa medzitým zmenila — skontroluj aktuálne údaje.'] if
            row_rev.to_s.empty? || record_rev(existing) != row_rev.to_s
          return [:invalid, 'Položka je viazaná na Demos — použi overenie z Demosu.'] unless existing['demos_url'].to_s.strip.empty?
          return [:invalid, 'Najprv doplň platný odkaz na produkt.'] unless sanitize_product_url(existing['product_url'])
          return [:invalid, 'Položka nemá platnú mernú jednotku.'] unless canonical_unit(existing['unit'])
          rec, err, field = normalize_item(existing.merge('price_eur_vat' => amount,
            'price_checked_at' => Time.now.utc.iso8601, 'price_check_method' => 'manual'))
          return [:invalid, err, field] unless rec
          data['items'] = data['items'].map { |i| i.equal?(existing) ? rec : i }
          return [:write_failed, 'Cenu sa nepodarilo uložiť.'] unless write_unlocked(data)
          [:ok, rec]
        end
      end

      def clear_manual_check!(rec)
        rec.delete('price_check_method')
        rec.delete('price_checked_at')
        rec
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

      # KOV-B2: znacka z Demosu -> KANONICKY vyrobca z taxonomie (alebo nil).
      # Fail-closed: nad nekompatibilnou taxonomiou `load` nic nevyda, takze
      # navrh by bol vzdy prazdny — vratime nil a modal necha pole na
      # pouzivatelovi (nikdy nenavrhne meno, ktore by sa nedalo ulozit).
      def manufacturer_guess(brand)
        b = brand.to_s.strip
        return nil if b.empty?
        return nil if HardwareTaxonomy.read_only?

        canon, = HardwareTaxonomy.resolve_classification(b, nil)
        canon
      rescue StandardError => e
        Engine.log_error(e, 'HardwareCatalog.manufacturer_guess') if defined?(Engine)
        nil
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
                 'category_guess' => category_guess("#{final_url} #{name}"),
                 # KOV-B2: znacka zo stranky (`itemprop="brand"`) prelozena cez
                 # TAXONOMIU na kanonicke meno. Je to NAVRH, nie zapis: keby sa
                 # ukladal surovy text zo stranky, vyrastol by v katalogu
                 # „HETTICH" vedla „Hettich" a zoskupenie by na tom nesadlo.
                 # Neznama znacka aj nekompatibilna taxonomia = nil (radu
                 # NEHADAME vobec — inferencia z breadcrumbu je mimo B2).
                 'manufacturer_guess' => manufacturer_guess(parsed['brand']) }
        create_proposals.clear if create_proposals.length > 8 # bounded pamat
        create_proposals[pid] = prop
        related = Array(parsed['related']).first(10).map do |r|
          { 'code' => r['code'].to_s, 'name' => r['name'].to_s }
        end
        prop.merge('ok' => true, 'exists' => !find(code).nil?, 'related' => related)
      end

      # Zapis z proposalu (pid = navrh, ktory pouzivatel VIDEL). Kategoriu,
      # poznamku a od KOV-B2 aj VYROBCU a RADU smie klient nastavit; kod,
      # nazov, cena a MJ pochadzaju VZDY z proposalu — klientske hodnoty tychto
      # poli sa IGNORUJU (FIX 12 z KOV-H1: klientovi sa veri len to, co si
      # nemohol vymysliet). Ked pouzivatel niektory z nich v modale prepise,
      # nie je to uz overena polozka z Demosu a klient ju posiela BEZNOU cestou
      # `create_item` — teda bez `demos_url` a bez `price_checked_at`.
      # Vyrobca a rada sa overuju cez taxonomiu presne ako v `create_item`.
      # -> [:ok, rec] | [:no_proposal|:exists|:invalid|:read_only|:write_failed, info, field]
      def create_from_demos!(pid, category: nil, notes: nil, manufacturer: nil, series: nil)
        prop = create_proposals[pid.to_s]
        return [:no_proposal, nil] unless prop
        attrs = { 'item_code' => prop['code'], 'name_sk' => prop['name_sk'],
                  'category' => (category.to_s.strip.empty? ? prop['category_guess'] : category),
                  'unit' => prop['unit'], 'supplier' => 'Demos' }
        attrs['price_eur_vat'] = prop['price_vat'] unless prop['price_vat'].nil?
        n = notes.to_s.strip
        attrs['notes'] = n unless n.empty?
        put_opt(attrs, 'manufacturer', manufacturer)
        put_opt(attrs, 'series', series)
        rec, err, field = normalize_item(attrs)
        return [:invalid, err, field] if rec.nil?

        refusal, canon_man, canon_ser = taxonomy_refusal(rec['manufacturer'], rec['series'])
        return refusal if refusal

        rec['manufacturer'] = canon_man if canon_man
        rec['series'] = canon_ser if canon_ser
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

      # H15b: seed manifest SEED_ROWS a jeho sprievodne zoznamy su v hardware_catalog_seed.rb.
      SEED_PRODUCT_LINKS = SEED_ROWS.each_with_object({}) do |row, links|
        next unless SEED_PRODUCT_CODES.include?(row[0])
        links[row[0]] = { 'notes' => row[5], 'product_url' => row[5].split(' · ').last }
      end.freeze

      SEED_ITEMS = SEED_ROWS.map do |code, name, category, unit, price, note, man, series, url, sup|
        item = { 'item_code' => code, 'name_sk' => name, 'category' => category,
                 'unit' => unit, 'supplier' => sup || 'Demos' }
        item['price_eur_vat'] = price unless price.nil?
        item['notes'] = note unless note.nil?
        item['manufacturer'] = man unless man.nil?
        item['series'] = series unless series.nil?
        item['demos_url'] = url unless url.nil?
        item['product_url'] = SEED_PRODUCT_LINKS[code]['product_url'] if SEED_PRODUCT_LINKS.key?(code)
        # Datum overenia patri VAZBE: bez URL alebo bez ceny sa nezapisuje.
        if url && !price.nil?
          item['price_checked_at'] =
            SEED_AVENTOS_V4.include?(code) ? SEED_PRICE_CHECKED_AT_V4 : SEED_PRICE_CHECKED_AT
        end
        item['active'] = false if SEED_INACTIVE.include?(code)
        item
      end.freeze

      # H15b: v2 tvar manifestu SEED_ROWS_V2 je v hardware_catalog_seed.rb.

      SEED_ITEMS_V2 = SEED_ROWS_V2.map do |code, name, category, unit, price, note|
        item = { 'item_code' => code, 'name_sk' => name, 'category' => category,
                 'unit' => unit, 'supplier' => 'Demos' }
        item['price_eur_vat'] = price unless price.nil?
        item['notes'] = note unless note.nil?
        item
      end.freeze

      # Klasifikacia seed riadku sa NEZAPISUJE „nasucho": prejde ZIVOU taxonomiou
      # (Codex #320 P2). Pouzivatel v nej uz moze mat to iste meno inak zapisane
      # alebo — a to je horsie — RADU POD INYM VYROBCOM (taxonomia cudzie mena
      # zamerne zachovava, seed dopĺňa len chybajuce). Bez tohto kroku by seed
      # vyrobil riadok, ktory kontrakt taxonomie porusuje: strom by rozdelil
      # ekvivalentnych vyrobcov a najblizsia uprava riadku by skoncila
      # „rada patri vyrobcovi X". Co sa nedá vyriešiť, sa VYNECHA — polozka bez
      # vyrobcu je legalna (rovnaka fail-closed uvaha ako `taxonomy_refusal`).
      #
      # Bezi ZAMERNE MIMO katalogoveho zamku (taxonomia ma vlastny sidecar;
      # vnorenie by vyrobilo PORADIE zamkov — ta ista uvaha ako pri create/patch).
      def seed_items_resolved(items = SEED_ITEMS)
        HardwareTaxonomy.ensure_seeded
        items.map do |a|
          next a if a['manufacturer'].nil? && a['series'].nil?

          out = a.dup
          if HardwareTaxonomy.read_only?
            out.delete('manufacturer')
            out.delete('series')
            next out
          end
          man, ser, = HardwareTaxonomy.resolve_classification(a['manufacturer'], a['series'])
          man.nil? ? out.delete('manufacturer') : out['manufacturer'] = man
          ser.nil? ? out.delete('series') : out['series'] = ser
          out
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareCatalog.seed_items_resolved') if defined?(Engine)
        items.map do |a|
          a['manufacturer'].nil? && a['series'].nil? ? a : a.reject { |k, _| %w[manufacturer series].include?(k) }
        end
      end

      def seed!
        resolved = seed_items_resolved
        with_lock do
          recs = resolved.map { |a| normalize_item(a)[0] }.compact
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
      # H15b: SEED_PATCH_V2_ADD a LEGACY_SEED_93240 su v hardware_catalog_seed.rb.
      SEED_MATCH_FIELDS = %w[name_sk category unit price_eur_vat notes supplier].freeze

      def apply_seed_patches!
        # Taxonomia sa pyta PRED katalogovym zamkom (vzor create_item/patch_item,
        # zdrojovy guard v testoch). Bezi len ked upgrade naozaj caka — `assess!`
        # sem chodi az po lacnej kontrole `seed_version`.
        resolved = seed_items_resolved
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
            # Aj legacy v1 -> v2 dopĺňanie berie riadky z UZ ROZLISENEJ sady
            # (Codex #320 kolo 2 P2): z `SEED_ITEMS` by krytky 105408/105425
            # dostali klasifikaciu mimo zivej taxonomie a nasledny v3 prechod
            # by ich uz povazoval za pouzivatelsku upravu a nechal tak.
            seed_by_code = {}
            resolved.each { |s| seed_by_code[s['item_code']] = s }
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
                          cur['demos_url'].to_s.empty? && cur['price_check_method'] != 'manual'
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
          changed.concat(apply_seed_patch_v3(items, resolved)) if from < 3
          changed.concat(apply_seed_patch_v4(items, resolved)) if from < 4
          changed.concat(apply_seed_patch_v5(items, resolved)) if from < 5
          if from < 6
            items.map! do |cur|
              seed = SEED_PRODUCT_LINKS[cur['item_code']]
              if seed && cur['notes'] == seed['notes'] &&
                 cur['product_url'].to_s.strip.empty? && cur['demos_url'].to_s.strip.empty?
                changed << "URL:#{cur['item_code']}"
                enriched = cur.merge('product_url' => seed['product_url'])
                clear_manual_check!(enriched) if cur['price_check_method'] == 'manual'
                enriched
              else
                cur
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

      # v2 -> v3 (D-118): 54 NOVYCH kodov, ktore pouzivaju seed sety zasuviek
      # (vratane PTOs modulov a opravy 357889), + OSVIEZENIE povodnych 60 riadkov
      # o overeny nazov, cenu s DPH, MJ, vyrobcu, radu a Demos URL.
      #
      # PLNY SEED SA DO EXISTUJUCEHO KATALOGU NELEJE (kontrakt z v1 -> v2):
      # doplna sa LEN vymenovany `SEED_PATCH_V3_ADD`. Kto si seed polozku zmazal,
      # dostane spat iba to, co je na tomto zozname — nic ine sa nevzkriesi.
      #
      # Prepisat existujuci riadok sa smie LEN ked je este preukazatelne NAS
      # (rovnaka uvaha ako pri 93240 v patchi v1 -> v2):
      #   * vsetky `SEED_MATCH_FIELDS` sedia s v2 seed tvarom, A ZAROVEN
      #   * riadok nema vlastnu Demos vazbu (`demos_url`), A ZAROVEN
      #   * riadok nema vlastnu klasifikaciu (`manufacturer` / `series`) —
      #     tie v `SEED_MATCH_FIELDS` NIE SU, takze bez tejto podmienky by sme
      #     prepisali vyrobcu, ktoreho tam dal pouzivatel (Astra #21 BLOCKER 1).
      # `merge` nad existujucim zaznamom drzi `use_count` aj rucne vypnutu
      # aktivnost: v3 riadok nesie `active` LEN pre `SEED_INACTIVE` (a to `false`),
      # takze polozku NIKDY nezapne spat.
      #
      # POZOR: doplnenim vyrobcov sa katalog bez klasifikacie stampuje na
      # `SCHEMA_CLASSIFIED` — starsi plugin ho odteraz cita ako read-only
      # („aktualizuj plugin"), nikdy ticho neoreze. To je zamer, nie vedlajsi
      # ucinok: v3 riadky bez vyrobcu by boli polovicna praca.
      # H15b: SEED_PATCH_V3_ADD je v hardware_catalog_seed.rb.

      def apply_seed_patch_v3(items, resolved = seed_items_resolved)
        v2_by_code = {}
        SEED_ITEMS_V2.each do |a|
          rec, = normalize_item(a)
          v2_by_code[rec['item_code'].downcase] = rec if rec
        end
        add_keys = SEED_PATCH_V3_ADD.map(&:downcase)
        idx_by_code = {}
        items.each_with_index { |i, n| idx_by_code[i['item_code'].to_s.strip.downcase] ||= n }
        added = []
        updated = []
        kept = []
        resolved.each do |seed|
          rec, = normalize_item(seed)
          next unless rec
          key = rec['item_code'].downcase
          idx = idx_by_code[key]
          if idx.nil?
            next unless add_keys.include?(key)

            idx_by_code[key] = items.length
            items << rec
            added << rec['item_code']
            next
          end
          cur = items[idx]
          v2 = v2_by_code[key]
          untouched = v2 &&
                      SEED_MATCH_FIELDS.all? { |k| cur[k] == v2[k] } &&
                      cur['demos_url'].to_s.empty? &&
                      cur['manufacturer'].to_s.empty? &&
                      cur['series'].to_s.empty?
          untouched &&= cur['price_check_method'] != 'manual'
          unless untouched
            kept << rec['item_code']
            next
          end
          items[idx] = cur.merge(rec)
          updated << rec['item_code']
        end
        if defined?(Engine) && kept.any?
          Engine.log("kovanie katalog: v3 seed nechal bez zmeny #{kept.length} pouzivatelskych poloziek (#{kept.first(12).join(', ')}#{kept.length > 12 ? ', …' : ''})")
        end
        ["v3 +#{added.length}", "v3 ~#{updated.length}", "v3 =#{kept.length}"]
      end

      # v3 -> v4 (KOV-E1a): 23 NOVYCH kodov AVENTOS HK top / HL top. Patch je
      # LEN DOPLNAJUCI — na rozdiel od v3 NEOSVIEZUJE ziadny existujuci riadok:
      # 347827, 13781 a 250831 v katalogu uz su a ich obsah (vratane rucnych
      # uprav a kategorie 250831 = ZAVESY) sa NEMENI. Kto si niektory z 23 kodov
      # medzitym zalozil sam, ostava mu jeho vlastny zaznam.
      # H15b: SEED_PATCH_V4_ADD je v hardware_catalog_seed.rb.

      def apply_seed_patch_v4(items, resolved = seed_items_resolved)
        add_keys = SEED_PATCH_V4_ADD.map(&:downcase)
        have = {}
        items.each { |i| have[i['item_code'].to_s.strip.downcase] = true }
        added = []
        resolved.each do |seed|
          rec, = normalize_item(seed)
          next unless rec

          key = rec['item_code'].downcase
          next unless add_keys.include?(key)
          next if have[key]

          have[key] = true
          items << rec
          added << rec['item_code']
        end
        ["v4 +#{added.length}"]
      end

      # v4 -> v5 (KOV-G1a): NOHY 17-220 mm + prichyt sokla. Tri kroky a kazdy
      # ma vlastnu, uzku podmienku „ruky prec od pouzivatelskej upravy":
      #
      #   1) ADD-IF-ABSENT devat kodov (`SEED_PATCH_V5_ADD`) — kto si niektory
      #      z nich medzitym zalozil sam, ostava mu jeho vlastny zaznam
      #      (rovnaky kontrakt ako v4).
      #   2) ENRICHMENT riadku 367823 (noha AXILO 150 z Demosu): doplni sa
      #      vyrobca a rada, ale LEN ked su OBE PRAZDNE. Ked si klasifikaciu
      #      zapisal pouzivatel, patch sa jej nedotkne (vzor v3, Astra #21
      #      BLOCKER 1) — a nedotkne sa ani nicoho ineho na riadku (nazov,
      #      cena, poznamka, `use_count`, vypnuta aktivnost).
      #   3) OPRAVA DVOJICE Hettich+AXILO: radu AXILO presunula spod Hettichu
      #      pod Häfele migracia taxonomie (`HardwareTaxonomy.migrate_axilo_owner!`),
      #      takze polozka s tou dvojicou by sa uz NEDALA ULOZIT („rada nepatri
      #      výrobcovi") — modal by pri vyrobcovi Hettich radu AXILO ani
      #      neponukol. Je to naprava nekonzistencie, ktoru sposobila NASA
      #      zmena, nie prepisanie cudzieho rozhodnutia: meni sa VYHRADNE
      #      vyrobca, VYHRADNE pri presnej zhode oboch mien a VYHRADNE vtedy,
      #      ked ZIVA taxonomia naozaj hovori, ze AXILO patri Häfele
      #      (Codex #337 N2 — pri cudzej vazbe rady sa krok NEVYKONA).
      # H15b: SEED_PATCH_V5_ADD a SEED_PATCH_V5_CLASSIFY su v hardware_catalog_seed.rb.

      def apply_seed_patch_v5(items, resolved = seed_items_resolved)
        by_code = {}
        resolved.each do |seed|
          rec, = normalize_item(seed)
          by_code[rec['item_code'].downcase] = rec if rec
        end
        have = {}
        items.each_with_index { |i, n| have[i['item_code'].to_s.strip.downcase] ||= n }

        added = []
        SEED_PATCH_V5_ADD.each do |code|
          key = code.downcase
          next if have.key?(key)

          rec = by_code[key]
          next unless rec

          have[key] = items.length
          items << rec
          added << code
        end

        enriched = enrich_axilo_150(items, have, by_code)
        fixed = fix_axilo_manufacturer(items)
        ["v5 +#{added.length}", "v5 ~#{enriched + fixed}"]
      end

      # Krok 2 — enrichment-if-empty (viz komentar `apply_seed_patch_v5`).
      def enrich_axilo_150(items, have, by_code)
        idx = have[SEED_PATCH_V5_CLASSIFY.downcase]
        return 0 if idx.nil?

        seed = by_code[SEED_PATCH_V5_CLASSIFY.downcase]
        # Ked taxonomia klasifikaciu nerozlisila (read-only / cudzi vlastnik
        # rady), `seed_items_resolved` ju z riadku ODOBRALA — nemame co doplnit.
        return 0 if seed.nil? || seed['manufacturer'].to_s.strip.empty?

        cur = items[idx]
        unless cur['manufacturer'].to_s.strip.empty? && cur['series'].to_s.strip.empty?
          if defined?(Engine)
            Engine.log("kovanie katalog: #{SEED_PATCH_V5_CLASSIFY} ma vlastnu klasifikaciu — nechavam")
          end
          return 0
        end
        patch = { 'manufacturer' => seed['manufacturer'] }
        patch['series'] = seed['series'] unless seed['series'].to_s.strip.empty?
        items[idx] = cur.merge(patch)
        1
      end

      # Krok 3 — presun vlastnika rady AXILO (viz komentar `apply_seed_patch_v5`).
      #
      # Codex #337 N2: vlastnik sa pyta ZIVEJ TAXONOMIE, NIKDY sa neodvodzuje
      # z resolvnuteho seedu. Ked si pouzivatel naviazal AXILO na vlastneho
      # vyrobcu, migracia taxonomie mu to (spravne) necha — ale seed riadok
      # 367823 sa vtedy resolvne na „Häfele BEZ rady", takze stara podmienka
      # (neprazdny vyrobca ineho mena nez Hettich) by presla a prepisala by
      # jeho polozky na dvojicu Häfele+AXILO, ktora v JEHO taxonomii
      # NEEXISTUJE — a v modale by ju uz neulozil. Oprava preto bezi VYHRADNE
      # vtedy, ked taxonomia naozaj hovori „AXILO patri Häfele", a zapisuje sa
      # jej ULOZENY zapis mena (JS filtruje presnym retazcom).
      def fix_axilo_manufacturer(items)
        owner = HardwareTaxonomy.series_owner(HardwareTaxonomy::AXILO_SERIES)
        return 0 if owner.nil?
        return 0 unless HardwareTaxonomy.same_name?(owner, HardwareTaxonomy::AXILO_OWNER)

        n = 0
        items.each_with_index do |cur, i|
          next unless HardwareTaxonomy.same_name?(cur['series'], HardwareTaxonomy::AXILO_SERIES)
          next unless HardwareTaxonomy.same_name?(cur['manufacturer'],
                                                  HardwareTaxonomy::AXILO_LEGACY_OWNER)

          items[i] = cur.merge('manufacturer' => owner)
          n += 1
        end
        if n.positive? && defined?(Engine)
          Engine.log("kovanie katalog: #{n} poloziek AXILO presunutych pod '#{owner}'")
        end
        n
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
