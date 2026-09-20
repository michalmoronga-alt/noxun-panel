# frozen_string_literal: true
# Noxun Engine — S1-A1: katalog spotrebicov (per PC).
#
# TRETI per-PC katalog vedla materialov a kovania: `%APPDATA%\NOXUN\Engine\
# appliances.json` cez `JsonFileStore` (atomicky zapis + `.bak` + cache) a
# VLASTNY sidecar zamok `appliances.json.lock`. Zamok sa NIKDY nevnara do
# ineho katalogoveho zamku (poradie zamkov = deadlock; rovnaka zasada ako
# `HardwareCatalog.taxonomy_refusal`).
#
# KONTRAKTY (package S1-A1 + Codex audit 20.9.2026):
#   - ZAZNAM je jediny model spotrebica. Identita = serverove UUID `id`;
#     `category` sa nastavuje LEN pri `create!` (patch ju odmietne) — inak by
#     sa zmenou kategorie zmenil aj vyznam poli v `dims` a ulozene cisla by
#     zostali v zaznamoch, ktore ich uz nevaliduju.
#   - NEZNAME POLE = PRAZDNE. Ziadny tichy default: chybajuci kluc znamena
#     „list to nekotuje", `nil` sa NIKDY neuklada (04A invariant, debata §5).
#   - `rev` je ODTLACOK OBSAHU (SHA1 ulozeneho zaznamu), nie pocitadlo, a do
#     suboru sa NEUKLADA — po obnove z `.bak` sa revizia pre iny obsah
#     nezopakuje. KAZDA mutacia ho vyzaduje (`rev:`) a server ho NIKDY
#     nedosadi za volajuceho: stale okno musi dostat `:conflict`.
#   - PRILOHY ziju v `%APPDATA%\NOXUN\Engine\appliances\<id>\` — teda MIMO
#     stromu `Plugins/noxun_engine`, ktory `Updater.swap!` cely vymiena.
#     Nazov suboru je NEMENNY (`<uuid prilohy>_<sanitized>.<ext>`) a nikdy sa
#     nerecykluje: uz obsadeny ciel sa NEPREPISE ani vtedy, ked je to sirota
#     po zmazanej prilohe — zakazkovy snapshot na nu moze stale odkazovat.
#   - `delete!` je TOMBSTONE (`deleted_at`), nie mazanie: zakazky, ktore model
#     pouzili, nesmu prist o jeho rozmery ani prilohy.
#   - SEED je MARKEROVY (`SEED_VERSION`, vzor `TemplateStore`): seje sa
#     VYHRADNE pri prvej instalacii (chyba primar AJ `.bak`), NIKDY opakovane —
#     zmazany seed zaznam sa uz nevrati a pouzivatelska uprava sa neprepise.
#     Marker cestuje s dokumentom; doplnenie modelov v buducej davke pobezi ako
#     SEED PATCH pri prechode markera (vzor `HardwareCatalog.apply_seed_patches!`)
#     — dnes ziadny taky patch neexistuje, lebo sada je prva.
#   - VSETKO vracia DVOJICU `[status, info]`, kde `info` je Hash so symbolovymi
#     klucmi (`:record`, `:records`, `:snapshot`, `:message`, `:field`).
#
# S1-B (zakazka) si z modulu berie VYHRADNE `snapshot_for` — ciste citanie bez
# vazby na zivy katalog. Cena, Demos, UI ani vazba do zakazky sem NEPATRIA.
require 'digest'
require 'fileutils'
require 'json'
require 'securerandom'
require 'time'
require 'uri'

module Noxun
  module Engine
    module ApplianceCatalog
      # Marker suboru. Vyssia hodnota = subor z NOVSIEHO pluginu -> READ-ONLY
      # (forward guard, vzor `TemplateStore` / `usage_stats`): starsi kod nesmie
      # degradovat data, ktorym nerozumie.
      STD = 1
      # Verzia SEED sady. Tvar zaznamov je nezavisly (menil by sa cez STD).
      SEED_VERSION = 1
      FILE = 'appliances.json'
      # Priecinok priloh — SUROVODNY k `appliances.json`, nie v strome pluginu.
      ATTACH_ROOT = 'appliances'

      # Kanonicke kody kategorii pre CELY engine (S1-B na ne migruje legacy
      # slovenske kody rozpoctu). Kod je identita, popisok je len to, co
      # pouzivatel cita — guard test strazi, ze mapa pokryva `CATEGORIES`
      # presne (ziadny kod bez popisku a ziadny popisok bez kodu).
      CATEGORIES = %w[fridge oven microwave dishwasher hob sink hood other].freeze
      CATEGORY_LABELS = {
        'fridge' => 'Chladnička',
        'oven' => 'Rúra',
        'microwave' => 'Mikrovlnka',
        'dishwasher' => 'Umývačka',
        'hob' => 'Varná doska',
        'sink' => 'Drez',
        'hood' => 'Digestor',
        'other' => 'Iné'
      }.freeze

      # Polia, ktore smie menit KLIENT (vzor `HardwareCatalog::PATCHABLE`).
      # `category` chyba zamerne — nastavuje sa len pri `create!`.
      # `id`, `rev`, `seed`, `attachments`, `created_at`, `updated_at`,
      # `deleted_at` sa z klienta NEPREBERAJU NIKDY.
      PATCHABLE = %w[manufacturer name shop_urls sheet_urls note dims derived].freeze

      MAX_NAME = 200
      MAX_MANUFACTURER = 200
      MAX_NOTE = 1000
      MAX_URLS = 20
      MAX_URL = 500
      MAX_DERIVED = 40
      # Rozmery su mm Float (STANDARD §3); 5000 je strop, nad ktorym uz nejde
      # o nabytkarsky rozmer, ale o preklep (napr. m namiesto mm).
      MAX_MM = 5000.0
      MAX_KG = 100.0

      # Styri bloky zaznamu (jazyk listov: Geratemase · Nischenmase ·
      # Uberstande · Montage). Poradie je aj poradim v UI (S1-A2).
      DIM_BLOCKS = %w[body niche front install].freeze
      # `body` a `niche` su pre vsetky kategorie rovnake.
      BODY_FIELDS = %w[width height depth].freeze
      NICHE_FIELDS = %w[width_min width_max height_min height_max depth_min depth_max].freeze
      # `front` = celo a presahy; obsah je PER KATEGORIA (vyrobcovia kotuju
      # inac — Whirlpool presah voci TELU, Bosch voci NIKE, preto sa referencia
      # uklada ako pole `overhang_ref`, nie ako domienka).
      FRONT_FIELDS = {
        'oven' => %w[width height thickness overhang_top overhang_bottom overhang_ref vent_gap_below],
        'microwave' => %w[width height thickness overhang_top overhang_bottom overhang_ref vent_gap_below],
        'fridge' => %w[door_bottom_offset door_lower door_gap door_upper furniture_doors],
        'dishwasher' => %w[width height_max weight_min weight_max],
        'hob' => %w[outer_width outer_depth cutout_width cutout_depth cutout_depth_max mount_depth worktop_min],
        'sink' => %w[outer_width outer_depth cutout_width cutout_depth radius mount min_cabinet_width bowl_depth],
        'hood' => %w[min_cabinet_width cutout_width cutout_depth duct_diameter],
        'other' => [].freeze
      }.freeze
      # Volitelny vnoreny blok chladnicky: nabytkove dvere PRIAMO Z VYKRESU
      # vyrobcu (Bosch KIV38X20 taky vykres dava). Ked je vyplneny, ma vo
      # S1-F prednost pred vzorcom pasiem. `gap_ref` je REFERENCNA SKARA
      # v mm z toho vykresu (cislo), nie enum.
      FURNITURE_DOOR_FIELDS = %w[lower_min lower_max gap_ref].freeze
      INSTALL_FIELDS = %w[door_system hinge_side door_weight_max door_thickness_max
                          dishwasher_class plinth_min plinth_max
                          body_height_min body_height_max].freeze
      # Enumy. `dishwasher_class` sa uklada ako RETAZEC ('600'/'450') — trieda
      # je kod, nie rozmer; Integer zo starsieho klienta sa kanonizuje.
      ENUM_FIELDS = {
        'overhang_ref' => %w[body niche].freeze,
        'mount' => %w[top under].freeze,
        'door_system' => %w[sliding door_on_door].freeze,
        'hinge_side' => %w[left right reversible].freeze,
        'dishwasher_class' => %w[600 450].freeze
      }.freeze
      # Pola v kilogramoch (evidencia z listu — vo V1 sa nekontroluju).
      KG_FIELDS = %w[weight_min weight_max door_weight_max].freeze
      # Dvojice, ktorych poradie sa vynucuje. Vacsinu odvodi nazov
      # (`*_min` ma sesterske `*_max`); vynimku kotuje vyrobca inac
      # (vyrez dosky: „min 480 – max 492").
      EXTRA_MIN_MAX = [%w[cutout_depth cutout_depth_max]].freeze

      ATTACHMENT_KINDS = %w[sheet image thumbnail].freeze
      ATTACHMENT_EXTS = %w[pdf jpg jpeg png webp].freeze
      # Nazov ulozenej kopie je VZDY jediny segment `<uuid>_<slug>.<ext>` —
      # ziadne `..`, `/`, `\` ani absolutna cesta. Ten isty vzor plati pre
      # kontrolu dokumentu (`valid_stored_attachment?`) aj pre resolver
      # referencie zo zakazkoveho snapshotu (jedna autorita).
      ATTACH_FILE_RE = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,120}\.[A-Za-z0-9]{1,5}\z/.freeze
      # Druh prilohy urcuje, ktore pripony su preň pripustne: PDF je LIST,
      # nikdy obrazok ani nahlad — nahlad z PDF by UI nevykreslilo a dlazdica
      # by ostala prazdna bez jedineho dovodu. `ATTACHMENT_EXTS` ostava
      # zjednotenim (pozna ho resolver ciest).
      KIND_EXTS = {
        'sheet' => %w[pdf jpg jpeg png webp].freeze,
        'image' => %w[jpg jpeg png webp].freeze,
        'thumbnail' => %w[jpg jpeg png webp].freeze
      }.freeze
      MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024
      MAX_ATTACH_SLUG = 60
      MAX_ATTACHMENTS = 50

      DEGRADED_MSG = 'katalóg spotrebičov je poškodený — číta sa záloha, zápisy sú vypnuté (oprav/zmaž súbor)'
      SEED_FAILED_MSG = 'katalóg spotrebičov sa nepodarilo založiť — skontroluj miesto na disku a práva k %APPDATA%'

      module_function

      # --- ulozisko ------------------------------------------------------------

      # VYHRADNE TESTY (in-SketchUp sekcia `run_s1a1`): presmeruje cely katalog
      # aj priecinok priloh do izolovaneho priecinka. Runner ho VZDY vracia na
      # nil (aj vo FAIL vetve) — inak by dalsie sekcie citali cudzi katalog.
      def test_dir_override
        @test_dir_override
      end

      def test_dir_override=(value)
        @test_dir_override = value
      end

      def dir
        override = test_dir_override
        return override.to_s if override && !override.to_s.empty?

        Materials.dir # zdielany %APPDATA%\NOXUN\Engine
      end

      def path
        File.join(dir, FILE)
      end

      def lock_path
        "#{path}.lock"
      end

      def attachments_root
        File.join(dir, ATTACH_ROOT)
      end

      # Priecinok priloh JEDNEHO zaznamu. `id` je serverove UUID, takze do
      # cesty nemoze uniknut nic z pouzivatelskeho vstupu; containment sa
      # napriek tomu overuje (posledna poistka, vzor `TemplatePreviews`).
      def record_dir(id)
        safe = id.to_s
        return nil unless safe.match?(/\A[A-Za-z0-9._-]{1,64}\z/)

        base = File.expand_path(attachments_root)
        full = File.expand_path(File.join(base, safe))
        return nil unless full.start_with?("#{base}/") || full.start_with?("#{base}#{File::SEPARATOR}")

        full
      end

      # Reentrantny medziprocesovy zamok na SIDECAR subore (drzany handle by na
      # Windows zablokoval atomicky rename `JsonFileStore`). Vynimku VEDOME
      # NEPREHLTA — volajuci ju mapuje na `[:locked, …]`; holy `false` z vnutra
      # by sa inak dostal von ako navratova hodnota mutacie.
      def with_lock
        return yield if @lock_held

        FileUtils.mkdir_p(dir)
        File.open(lock_path, File::RDWR | File::CREAT) do |f|
          f.flock(File::LOCK_EX)
          begin
            @lock_held = true
            JsonFileStore.invalidate(path) # pod zamkom sa cita CERSTVY stav disku
            yield
          ensure
            @lock_held = false
            f.flock(File::LOCK_UN)
          end
        end
      end

      # --- stav katalogu (matica assess!) --------------------------------------
      #
      #   chyba primar AJ .bak            -> prva instalacia = SEED, stav :ok
      #   chyba primar, .bak existuje     -> NIE JE prva instalacia (cita sa
      #                                      zaloha, ziadny seed; prvy zapis
      #                                      primar obnovi), stav :ok
      #   poskodeny primar + platna .bak  -> :degraded (citanie zo zalohy,
      #                                      zapisy stoja)
      #   poskodeny primar + .bak, ktora
      #     sa SICE parsuje, ale je cudzia
      #     / novsia / necitatelna        -> :read_only (nie :degraded — nie je
      #                                      z coho citat, nieto este snapshotovat)
      #   poskodeny primar bez .bak       -> :read_only
      #   cudzi/novsi/necitatelny obsah   -> :read_only s dovodom
      #
      # `TemplateStore.read_only?` (pri chybe vracia `false`) sa VEDOME
      # neprebera — tichy „smies zapisat" je presne to, co tu nesmie nastat.
      def assess!
        set_state(:ok, '')
        unless JsonFileStore.available?(path)
          # ZLYHANY SEED nie je zdravy prazdny katalog: nezapisovatelny
          # `%APPDATA%` alebo plny disk by inak vydali stav `:ok` nad
          # neexistujucim suborom a kazdy dalsi zapis by tisko padal.
          return set_state(:read_only, SEED_FAILED_MSG) unless seed!

          return @state
        end
        if JsonFileStore.degraded?(path)
          # `degraded?` hovori LEN to, ze zaloha sa PARSUJE — nie ze sa da
          # pouzit. Zaloha z novsej verzie (`std` > STD) alebo s necitatelnym
          # zaznamom nie je „citaj zalohu, zapisy stoja", ale READ-ONLY bez
          # pouzitelneho obsahu (Codex #377 kolo 2 P1).
          issue = stored_document_issue(backup_document)
          return set_state(:read_only, issue) if issue

          return set_state(:degraded, DEGRADED_MSG)
        end

        issue = stored_document_issue(raw_document)
        return set_state(:read_only, issue) if issue

        @state
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceCatalog.assess!') if defined?(Engine)
        set_state(:read_only, 'katalóg spotrebičov sa nedá prečítať (oprav/zmaž súbor)')
      end

      def set_state(state, reason)
        @state = state
        @state_reason = reason.to_s
        if state != :ok && defined?(Engine)
          Engine.log("katalog spotrebicov: #{state} — #{@state_reason}")
        end
        @state
      end

      def state
        assess! if @state.nil?
        @state
      end

      def state_reason
        state
        @state_reason.to_s
      end

      def read_only?
        state == :read_only
      end

      def degraded?
        state == :degraded
      end

      # Test-only reset modulovych stavov.
      def reset_state!
        @state = nil
        @state_reason = ''
        @lock_held = false
        true
      end

      # CERSTVY dokument z disku bez sekundovej cache `JsonFileStore.read`
      # (cache by pod zamkom vratila stav spred cudzieho zapisu).
      def raw_document
        JSON.parse(File.binread(File.exist?(path) ? path : "#{path}.bak"))
      rescue StandardError
        nil
      end

      # VYHRADNE zaloha — pouziva ju degradovany stav, kde primar nie je
      # citatelny a `raw_document` by ho aj tak skusil ako prvy.
      def backup_document
        JSON.parse(File.binread("#{path}.bak"))
      rescue StandardError
        nil
      end

      # Dovod, preco sa do dokumentu NESMIE zapisat (nil = smie sa).
      # Bezi nad CERSTVYM dokumentom pod zamkom pred KAZDYM zapisom.
      def stored_document_issue(data)
        return 'katalóg spotrebičov je poškodený (JSON sa nedá prečítať)' unless data.is_a?(Hash)
        return 'katalóg spotrebičov má neznámy tvar (chýba zoznam záznamov)' unless data['records'].is_a?(Array)
        return 'katalóg spotrebičov nemá značku verzie (std)' unless data['std'].is_a?(Integer)
        return 'katalóg spotrebičov je v novšej verzii — aktualizuj plugin' if data['std'] > STD
        unless data['records'].all? { |r| valid_stored_record?(r) }
          return 'katalóg spotrebičov obsahuje nečitateľný záznam (identita, rozmery alebo príloha)'
        end

        ids = data['records'].map { |r| r['id'].to_s }
        return 'katalóg spotrebičov má duplicitné identity — oprav súbor' unless ids.uniq.length == ids.length

        nil
      end

      # Minimalna citatelnost ULOZENEHO zaznamu. Identita musi byt neprazdny
      # retazec (UUID zo servera); tvrdsie veci strazi validacia pri zapise.
      def valid_stored_record?(rec)
        rec.is_a?(Hash) && !rec['id'].to_s.strip.empty? &&
          (rec['dims'].nil? || rec['dims'].is_a?(Hash)) &&
          (rec['attachments'].nil? ||
            (rec['attachments'].is_a?(Array) && rec['attachments'].all? { |it| valid_stored_attachment?(it) }))
      end

      # Polozka `attachments[]` musi byt CITATELNA uz pri kontrole dokumentu.
      # `[null]` alebo polozka bez `file` by inak presla ako zdravy katalog
      # a rozbila sa az v `snapshot_for` / mutacii ako NoMethodError — teda
      # hlaskou o zlyhanom zapise namiesto pravdy „subor je poskodeny".
      def valid_stored_attachment?(item)
        return false unless item.is_a?(Hash)
        return false if item['id'].to_s.strip.empty?
        return false unless ATTACHMENT_KINDS.include?(item['kind'].to_s)
        return false unless item['name'].is_a?(String)

        file = item['file'].to_s
        file.match?(ATTACH_FILE_RE) && ATTACHMENT_EXTS.include?(attach_ext(file))
      end

      # --- citanie -------------------------------------------------------------

      def ensure_state
        assess! if @state.nil?
        @state
      end

      # Zaznamy z aktualneho dokumentu (bez `rev` — ten pridava `decorate`).
      def stored_records(doc = nil)
        data = doc || begin
          JsonFileStore.read(path)
        rescue StandardError
          nil
        end
        return [] unless data.is_a?(Hash) && data['records'].is_a?(Array)

        data['records'].select { |r| valid_stored_record?(r) }
      end

      # `rev` = ODTLACOK OBSAHU ulozeneho zaznamu (A6). Pocita sa pri citani
      # a do suboru sa nikdy nezapisuje.
      def record_rev(rec)
        clean = rec.is_a?(Hash) ? rec.reject { |k, _| k == 'rev' } : {}
        Digest::SHA1.hexdigest(JSON.generate(clean))[0, 12]
      end

      def decorate(rec)
        rec.merge('rev' => record_rev(rec))
      end

      # -> [:ok, { records: [...] }] | [:read_only, { message:, records: [] }]
      def list(include_deleted: false)
        ensure_state
        doc = begin
          JsonFileStore.read(path)
        rescue StandardError
          nil
        end
        if doc.nil? && read_only?
          return [:read_only, { message: state_reason, records: [] }]
        end

        rows = stored_records(doc)
        rows = rows.reject { |r| deleted?(r) } unless include_deleted
        [:ok, { records: sort_records(rows).map { |r| decorate(r) } }]
      end

      # -> [:ok, { record: }] | [:not_found, { message: }]
      def find(id)
        ensure_state
        rec = stored_records.find { |r| r['id'].to_s == id.to_s }
        return [:not_found, { message: 'spotrebič sa nenašiel' }] unless rec

        [:ok, { record: decorate(rec) }]
      end

      def deleted?(rec)
        !rec['deleted_at'].to_s.strip.empty?
      end

      # Hladanie bez diakritiky nad nazvom, vyrobcom, kodom kategorie AJ jej SK
      # popiskom („umyvacka" najde `dishwasher`). Poradie je DETERMINISTICKE:
      # nazov -> vyrobca -> id (dva rovnomenne zaznamy nesmu striedat poradie).
      # -> [:ok, { records: [...] }]
      def search(query, category: nil, include_deleted: false)
        ensure_state
        rows = stored_records
        rows = rows.reject { |r| deleted?(r) } unless include_deleted
        cat = category.to_s.strip
        rows = rows.select { |r| r['category'].to_s == cat } unless cat.empty?
        tokens = fold(query).split(/\s+/).reject(&:empty?)
        unless tokens.empty?
          rows = rows.select do |r|
            hay = search_haystack(r)
            tokens.all? { |t| hay.include?(t) }
          end
        end
        [:ok, { records: sort_records(rows).map { |r| decorate(r) } }]
      end

      def search_haystack(rec)
        parts = [rec['name'], rec['manufacturer'], rec['category'],
                 CATEGORY_LABELS[rec['category'].to_s]]
        fold(parts.compact.join(' '))
      end

      def sort_records(rows)
        rows.sort_by { |r| [fold(r['name']), fold(r['manufacturer']), r['id'].to_s] }
      end

      # Diakritika von cez NFD (autorita tvaru: `TemplatePreviews.slug`).
      def fold(value)
        value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase
      rescue StandardError
        value.to_s.downcase
      end

      def category_label(code)
        CATEGORY_LABELS[code.to_s] || code.to_s
      end

      # --- normalizacia a validacia zaznamu ------------------------------------

      def stringify(attrs)
        return {} unless attrs.is_a?(Hash)

        attrs.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end

      def invalid(message, field)
        [:invalid, { message: message, field: field }]
      end

      def deep_copy(value)
        JsonFileStore.deep_copy(value)
      end

      # Zlozi ULOZENY tvar zaznamu z (a) uz ulozeneho zaznamu a (b) vstupu
      # klienta uz PREFILTROVANEHO whitelistom. Nezname kluce sa preberaju
      # VYHRADNE z `stored` — nikdy zo vstupu.
      # -> [rec, nil, nil] | [nil, sprava, pole]
      def build_record(stored, input, category)
        rec = deep_copy(stored)
        rec['category'] = category

        if input.key?('name') || !stored.key?('name')
          name = input.key?('name') ? input['name'].to_s.strip : stored['name'].to_s.strip
          return [nil, 'zadaj názov modelu', 'name'] if name.empty?
          return [nil, "názov je príliš dlhý (max #{MAX_NAME} znakov)", 'name'] if name.length > MAX_NAME

          rec['name'] = name
        end

        if input.key?('manufacturer')
          man = input['manufacturer'].to_s.strip
          return [nil, "výrobca je príliš dlhý (max #{MAX_MANUFACTURER} znakov)", 'manufacturer'] if man.length > MAX_MANUFACTURER

          man.empty? ? rec.delete('manufacturer') : rec['manufacturer'] = man
        end

        if input.key?('note')
          note = input['note'].to_s.strip
          return [nil, "poznámka je príliš dlhá (max #{MAX_NOTE} znakov)", 'note'] if note.length > MAX_NOTE

          note.empty? ? rec.delete('note') : rec['note'] = note
        end

        %w[shop_urls sheet_urls].each do |key|
          next unless input.key?(key)

          urls, msg = normalize_urls(input[key])
          return [nil, msg, key] if urls.nil?

          urls.empty? ? rec.delete(key) : rec[key] = urls
        end

        if input.key?('derived')
          derived, msg = normalize_derived(input['derived'])
          return [nil, msg, 'derived'] if derived.nil?

          derived.empty? ? rec.delete('derived') : rec['derived'] = derived
        end

        if input.key?('dims')
          return [nil, 'rozmery musia byť objekt', 'dims'] unless input['dims'].nil? || input['dims'].is_a?(Hash)

          stored_dims = rec['dims'].is_a?(Hash) ? rec['dims'] : {}
          # Doprednost plati pre SUBOR, nie pre klienta: neznamy kluc sa
          # zachova len vtedy, ked uz v ulozenom zazname JE. Preklep zo
          # vstupu (`cutout_dept`) sa musi ozvat, inak by sa mutacia tvarila
          # ako ulozena a cislo by ticho zmizlo (Codex #377 P2).
          msg, field = unknown_input_issue(input['dims'], stored_dims, category)
          return [nil, msg, field] if msg

          merged = merge_dims(stored_dims, input['dims'])
          dims, msg, field = normalize_dims(merged, category)
          return [nil, msg, field] if dims.nil?

          dims.empty? ? rec.delete('dims') : rec['dims'] = dims
        elsif rec['dims'].is_a?(Hash)
          # Aj bez patchu `dims` musi VYSLEDOK prejst validaciou — inak by sa
          # chybny zaznam z cudzieho zapisu „opravil" jedinou zmenou nazvu.
          dims, msg, field = normalize_dims(rec['dims'], category)
          return [nil, msg, field] if dims.nil?

          dims.empty? ? rec.delete('dims') : rec['dims'] = dims
        end

        [rec, nil, nil]
      end

      # -> [pole URL, nil] | [nil, sprava]
      def normalize_urls(raw)
        list = raw.is_a?(Array) ? raw : [raw]
        out = []
        list.each do |item|
          s = item.to_s.strip
          next if s.empty?
          return [nil, "odkaz je príliš dlhý (max #{MAX_URL} znakov)"] if s.length > MAX_URL

          uri = begin
            URI.parse(s)
          rescue URI::InvalidURIError
            nil
          end
          unless uri.is_a?(URI::HTTP) && !uri.host.to_s.strip.empty?
            return [nil, 'vlož platný odkaz http:// alebo https://']
          end

          out << uri.to_s
        end
        return [nil, "odkazov je priveľa (max #{MAX_URLS})"] if out.length > MAX_URLS

        [out.uniq, nil]
      end

      # `derived` = zoznam CIEST poli, ktorych hodnota je odvodena (list ju
      # nekotuje), napr. „body.width". Prvy segment musi byt znamy blok, inak
      # by v zozname skoncila lubovolna veta a UI by ju kreslila ako pole.
      def normalize_derived(raw)
        list = raw.is_a?(Array) ? raw : [raw]
        out = []
        list.each do |item|
          s = item.to_s.strip
          next if s.empty?

          block = s.split('.').first.to_s
          unless DIM_BLOCKS.include?(block) && s.match?(/\A[a-z_]+(\.[a-z_0-9]+)+\z/)
            return [nil, "neznáma cesta odvodeného poľa „#{s}“"]
          end

          out << s
        end
        return [nil, "odvodených polí je priveľa (max #{MAX_DERIVED})"] if out.length > MAX_DERIVED

        [out.uniq, nil]
      end

      # Kluc, ktory prinasa VSTUP KLIENTA a nie je ani vo whiteliste kategorie,
      # ani v ULOZENOM zazname -> `:invalid` s cestou pola. Neznamy kluc, ktory
      # v subore uz je (zapis novsej verzie), sa dalej zachovava — ten prisiel
      # od pluginu, nie z formulara (Codex #377 P2).
      # -> [nil, nil] | [sprava, cesta_pola]
      def unknown_input_issue(patch, stored, category, block = nil, prefix = 'dims', known = nil)
        return [nil, nil] unless patch.is_a?(Hash)

        patch.each do |key, value|
          k = key.to_s
          path = "#{prefix}.#{k}"
          base = stored.is_a?(Hash) ? stored[k] : nil
          if block.nil? # uroven BLOKOV
            return ["neznámy blok rozmerov „#{k}“", path] unless DIM_BLOCKS.include?(k) || !base.nil?
            next unless value.is_a?(Hash)

            msg, field = unknown_input_issue(value, base, category, k, path)
            return [msg, field] if msg

            next
          end
          allowed = known || block_fields(block, category)
          return ["neznáme pole „#{k}“", path] unless allowed.include?(k) || !base.nil?
          next unless k == 'furniture_doors' && value.is_a?(Hash)

          msg, field = unknown_input_issue(value, base, category, block, path, FURNITURE_DOOR_FIELDS)
          return [msg, field] if msg
        end
        [nil, nil]
      end

      # CIASTOCNY patch `dims` po LISTOCH: nepritomne pole = zachovat,
      # explicitne `nil` (JSON `null`) = ZMAZAT konkretny kluc. Nezname
      # vnorene kluce preziju (doprednost) — ale LEN tie, ktore uz su
      # v ULOZENOM zazname; vstup klienta ich cez `unknown_input_issue`
      # neprepasuje.
      def merge_dims(stored, patch)
        out = deep_copy(stored)
        return out unless patch.is_a?(Hash)

        patch.each do |block, value|
          if value.nil?
            out.delete(block.to_s)
            next
          end
          unless value.is_a?(Hash)
            out[block.to_s] = value # nevalidny tvar chyti normalize_dims
            next
          end
          base = out[block.to_s].is_a?(Hash) ? out[block.to_s] : {}
          out[block.to_s] = merge_leaves(base, value)
        end
        out
      end

      def merge_leaves(base, patch)
        out = base.dup
        patch.each do |key, value|
          k = key.to_s
          if value.nil?
            out.delete(k)
          elsif value.is_a?(Hash) && out[k].is_a?(Hash)
            out[k] = merge_leaves(out[k], value)
          else
            out[k] = value
          end
        end
        out
      end

      # -> [dims, nil, nil] | [nil, sprava, cesta_pola]
      def normalize_dims(dims, category)
        return [{}, nil, nil] unless dims.is_a?(Hash)

        out = {}
        dims.each do |block, fields|
          b = block.to_s
          unless DIM_BLOCKS.include?(b)
            out[b] = deep_copy(fields) # blok z novsej verzie prezije nedotknuty
            next
          end
          return [nil, "blok #{b} musí byť objekt", "dims.#{b}"] unless fields.is_a?(Hash)

          norm, msg, field = normalize_block(b, fields, category)
          return [nil, msg, field] if norm.nil?

          out[b] = norm unless norm.empty?
        end
        [out, nil, nil]
      end

      def block_fields(block, category)
        case block
        when 'body' then BODY_FIELDS
        when 'niche' then NICHE_FIELDS
        when 'install' then INSTALL_FIELDS
        when 'front' then FRONT_FIELDS[category.to_s] || []
        else []
        end
      end

      def normalize_block(block, fields, category, prefix = "dims.#{block}", known = nil)
        allowed = known || block_fields(block, category)
        out = {}
        fields.each do |key, raw|
          k = key.to_s
          path = "#{prefix}.#{k}"
          # Kluc MIMO whitelistu kategorie sa ZACHOVA, ale NEVALIDUJE — subor
          # z novsej verzie nesmieme ticho orezat.
          unless allowed.include?(k)
            out[k] = deep_copy(raw)
            next
          end
          if k == 'furniture_doors'
            return [nil, 'nábytkové dvere musia byť objekt', path] unless raw.is_a?(Hash)

            nested, msg, field = normalize_block(block, raw, category, path, FURNITURE_DOOR_FIELDS)
            return [nil, msg, field] if nested.nil?

            out[k] = nested unless nested.empty?
            next
          end
          if ENUM_FIELDS.key?(k)
            value = raw.to_s.strip
            unless ENUM_FIELDS[k].include?(value)
              return [nil, "neznáma hodnota „#{value}“ pre #{k}", path]
            end

            out[k] = value
            next
          end
          num = normalize_number(raw)
          return [nil, 'zadaj číslo (prázdne pole = neznáme)', path] if num.nil?

          limit = KG_FIELDS.include?(k) ? MAX_KG : MAX_MM
          if num.negative? || num > limit
            return [nil, "hodnota musí byť v rozsahu 0 – #{limit.round}", path]
          end

          out[k] = num
        end
        msg, field = min_max_issue(out, prefix)
        return [nil, msg, field] if msg

        [out, nil, nil]
      end

      # mm/kg Float. Prazdna hodnota = nil (kluc sa neulozi) — riesi volajuci
      # cez `merge_dims` (explicitne `null` maze kluc).
      def normalize_number(raw)
        return nil if raw.nil?
        return nil if raw.is_a?(String) && raw.strip.empty?

        value = if raw.is_a?(Numeric)
                  raw.to_f
                else
                  s = raw.to_s.strip.tr(',', '.')
                  return nil unless s.match?(/\A-?\d+(\.\d+)?\z/)

                  s.to_f
                end
        return nil unless value.finite?

        value
      end

      # `*_min` nesmie byt vacsie nez sesterske `*_max`; chyba nesie cestu
      # POLA (modal D-15 ju kresli pri poli).
      def min_max_issue(fields, prefix)
        pairs = fields.keys.filter_map do |k|
          next unless k.end_with?('_min')

          twin = "#{k[0..-5]}_max"
          [k, twin] if fields.key?(twin)
        end
        pairs += EXTRA_MIN_MAX.select { |(lo, hi)| fields.key?(lo) && fields.key?(hi) }
        pairs.each do |(lo, hi)|
          next unless fields[lo].is_a?(Numeric) && fields[hi].is_a?(Numeric)
          next if fields[lo] <= fields[hi]

          return ['minimum nesmie byť väčšie než maximum', "#{prefix}.#{lo}"]
        end
        [nil, nil]
      end

      # --- mutacie (vsetky pod zamkom, nad CERSTVYM dokumentom) ----------------

      def now_iso
        Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      end

      # Spolocny vstup KAZDEJ mutacie: zamok -> invalidacia cache -> cerstvy
      # dokument -> brany (degraded / read-only / novsia schema) -> blok.
      def with_fresh_document(op)
        # Stav z `assess!` plati AJ ked subor neexistuje: po zlyhanom seede
        # (nezapisovatelny `%APPDATA%`) by inak prvy zapis zalozil katalog BEZ
        # devatich modelov a marker `seed_version` by ich uz nikdy nedosial
        # (Codex #377 P2). Vzor `HardwareCatalog.create_item`.
        ensure_state
        return [:read_only, { message: state_reason }] if read_only?

        with_lock do
          JsonFileStore.invalidate(path)
          if JsonFileStore.available?(path)
            if JsonFileStore.degraded?(path)
              set_state(:degraded, DEGRADED_MSG)
              next [:degraded, { message: DEGRADED_MSG }]
            end
            fresh = raw_document
            if (issue = stored_document_issue(fresh))
              set_state(:read_only, issue)
              next [:read_only, { message: issue }]
            end
          else
            fresh = nil
          end
          yield(fresh, stored_records(fresh))
        end
      # Realne sem doletia LEN chyby zo zamku (`mkdir_p` / `File.open` /
      # `flock`) — zapis aj kopia priloh maju vlastny rescue. Preto sa chyby
      # SUBOROVEHO povodu hlasia ako `:locked` („skus o chvilu"), ale
      # cokolvek ine (teda nas bug) dostane `:write_failed`; jedna hlaska pre
      # oboje by klamala o pricine.
      rescue IOError, SystemCallError => e
        Engine.log_error(e, "ApplianceCatalog.#{op}") if defined?(Engine)
        [:locked, { message: 'katalóg spotrebičov sa práve nedá zamknúť — skús o chvíľu znova' }]
      rescue StandardError => e
        Engine.log_error(e, "ApplianceCatalog.#{op}") if defined?(Engine)
        write_failed
      end

      # Zapis dokumentu (BEZI LEN POD ZAMKOM). Nezname top-level kluce
      # existujuceho suboru PREZIJU (forward kontrakt ako `TemplateStore`).
      def write_unlocked(records, fresh, seed_version: nil)
        extras = fresh.is_a?(Hash) ? fresh.reject { |k, _| %w[std seed_version records].include?(k) } : {}
        stored_sv = fresh.is_a?(Hash) ? fresh['seed_version'].to_i : 0
        sv = (seed_version || (stored_sv.positive? ? stored_sv : SEED_VERSION)).to_i
        payload = { 'std' => STD, 'seed_version' => sv, 'records' => records }.merge(extras)
        JsonFileStore.write(path, payload)
        true
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceCatalog.write') if defined?(Engine)
        false
      end

      def write_failed
        [:write_failed, { message: 'katalóg spotrebičov sa nepodarilo uložiť (skontroluj miesto na disku a práva)' }]
      end

      def conflict
        [:conflict, { message: 'záznam sa medzitým zmenil — otvor ho znova' }]
      end

      def not_found
        [:not_found, { message: 'spotrebič sa nenašiel' }]
      end

      def rev_ok?(stored, rev)
        !rev.to_s.strip.empty? && rev.to_s == record_rev(stored)
      end

      # CREATE — `category` sa nastavuje VYHRADNE tu.
      # -> [:ok, { record: }] | [:invalid|:read_only|:degraded|:write_failed|:locked, …]
      def create!(attrs)
        ensure_state
        a = stringify(attrs)
        cat = a['category'].to_s.strip
        return invalid('vyber kategóriu spotrebiča', 'category') unless CATEGORIES.include?(cat)

        input = a.select { |k, _| PATCHABLE.include?(k) }
        rec, msg, field = build_record({}, input, cat)
        return invalid(msg, field) if rec.nil?

        with_fresh_document('create') do |fresh, records|
          stamp = now_iso
          rec = { 'id' => SecureRandom.uuid, 'category' => cat }.merge(rec)
          rec['created_at'] = stamp
          rec['updated_at'] = stamp
          next write_failed unless write_unlocked(records + [rec], fresh)

          [:ok, { record: decorate(rec) }]
        end
      end

      # PATCH — whitelist vstupu, `rev` guard, hlboke zlucenie `dims`.
      def patch!(id, attrs, rev:)
        ensure_state
        a = stringify(attrs)
        return invalid('kategóriu záznamu už nie je možné zmeniť', 'category') if a.key?('category')

        input = a.select { |k, _| PATCHABLE.include?(k) }
        return invalid('nie je čo uložiť', nil) if input.empty?

        with_fresh_document('patch') do |fresh, records|
          idx = records.index { |r| r['id'].to_s == id.to_s }
          next not_found unless idx

          stored = records[idx]
          next conflict unless rev_ok?(stored, rev)

          rec, msg, field = build_record(stored, input, stored['category'].to_s)
          next invalid(msg, field) if rec.nil?

          rec['updated_at'] = now_iso
          updated = records.dup
          updated[idx] = rec
          next write_failed unless write_unlocked(updated, fresh)

          [:ok, { record: decorate(rec) }]
        end
      end

      # DELETE = TOMBSTONE. Subory priloh ostavaju — zakazka, ktora model uz
      # pouzila, ich musi vediet otvorit aj po vyradeni.
      def delete!(id, rev:)
        ensure_state
        with_fresh_document('delete') do |fresh, records|
          idx = records.index { |r| r['id'].to_s == id.to_s }
          next not_found unless idx

          stored = records[idx]
          next conflict unless rev_ok?(stored, rev)

          stamp = now_iso
          rec = stored.merge('deleted_at' => stamp, 'updated_at' => stamp)
          updated = records.dup
          updated[idx] = rec
          next write_failed unless write_unlocked(updated, fresh)

          [:ok, { record: decorate(rec) }]
        end
      end

      # RESTORE — rovnaky `rev` guard ako delete (A1): stare okno nesmie
      # obnovit zaznam, ktory medzitym niekto zmenil alebo znova vyradil.
      def restore!(id, rev:)
        ensure_state
        with_fresh_document('restore') do |fresh, records|
          idx = records.index { |r| r['id'].to_s == id.to_s }
          next not_found unless idx

          stored = records[idx]
          next conflict unless rev_ok?(stored, rev)

          rec = stored.reject { |k, _| k == 'deleted_at' }
          rec['updated_at'] = now_iso
          updated = records.dup
          updated[idx] = rec
          next write_failed unless write_unlocked(updated, fresh)

          [:ok, { record: decorate(rec) }]
        end
      end

      # --- prilohy -------------------------------------------------------------

      # ASCII slug povodneho mena (citatelnost; identitu drzi UUID prilohy).
      def attach_slug(value)
        s = File.basename(value.to_s, '.*')
        s = s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
        s = s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
        s = s[0, MAX_ATTACH_SLUG].to_s.gsub(/\A_+|_+\z/, '')
        s.empty? ? 'x' : s
      rescue StandardError
        'x'
      end

      def attach_ext(value)
        File.extname(value.to_s).sub('.', '').downcase
      end

      # PRILOHA: kopia zdroja do `appliances\<id>\<uuid>_<slug>.<ext>`.
      # Poradie (A5): staging v CIELOVOM priecinku -> kontrola velkosti ->
      # `File.rename` na NEMENNY nazov -> az potom zapis JSON pod TYM ISTYM
      # zamkom. Zlyhanie zapisu = sirota sa best-effort zmaze a vracia sa
      # `:write_failed` (nikdy „uspech" s odkazom na neexistujuci subor).
      def attach!(id, source_path, kind:, rev:)
        ensure_state
        k = kind.to_s.strip
        return invalid('neznámy druh prílohy', 'kind') unless ATTACHMENT_KINDS.include?(k)

        src = source_path.to_s
        ext = attach_ext(src)
        unless ATTACHMENT_EXTS.include?(ext)
          return invalid("príloha musí byť #{ATTACHMENT_EXTS.join(', ')}", 'file')
        end
        # Pripustna pripona zavisi od DRUHU (PDF je list, nikdy obrazok ani
        # nahlad) — chyba patri k polu `kind`, lebo subor je v poriadku.
        unless KIND_EXTS[k].include?(ext)
          return invalid("ako #{k == 'thumbnail' ? 'náhľad' : 'obrázok'} sa dá priložiť len #{KIND_EXTS[k].join(', ')}", 'kind')
        end
        return [:copy_failed, { message: 'súbor sa nenašiel' }] unless File.file?(src)

        size = begin
          File.size(src)
        rescue StandardError
          nil
        end
        return [:copy_failed, { message: 'veľkosť súboru sa nedá zistiť' }] if size.nil?
        return too_large if size > MAX_ATTACHMENT_BYTES

        with_fresh_document('attach') do |fresh, records|
          idx = records.index { |r| r['id'].to_s == id.to_s }
          next not_found unless idx

          stored = records[idx]
          next conflict unless rev_ok?(stored, rev)

          items = stored['attachments'].is_a?(Array) ? stored['attachments'] : []
          next invalid("prílohy sú plné (max #{MAX_ATTACHMENTS})", 'file') if items.length >= MAX_ATTACHMENTS
          if k == 'thumbnail' && items.any? { |it| it['kind'].to_s == 'thumbnail' }
            next invalid('záznam už má náhľad — najprv ho zruš', 'kind')
          end

          target_dir = record_dir(stored['id'])
          next [:copy_failed, { message: 'priečinok príloh sa nedá určiť' }] unless target_dir

          att_id = SecureRandom.uuid
          file = "#{att_id}_#{attach_slug(src)}.#{ext}"
          staged, copy_err = stage_attachment(src, target_dir, att_id, file)
          next copy_err if staged.nil?

          bytes = File.size(staged)
          item = { 'id' => att_id, 'kind' => k, 'file' => file,
                   'name' => File.basename(src), 'bytes' => bytes, 'added_at' => now_iso }
          rec = stored.merge('attachments' => items + [item], 'updated_at' => now_iso)
          updated = records.dup
          updated[idx] = rec
          unless write_unlocked(updated, fresh)
            discard_file(target_dir, file) # sirota po zlyhanom zapise JSON
            next write_failed
          end

          [:ok, { record: decorate(rec) }]
        end
      end

      def too_large
        [:too_large, { message: "príloha je väčšia než #{MAX_ATTACHMENT_BYTES / (1024 * 1024)} MB" }]
      end

      # Staging + premenovanie. -> [cesta, nil] | [nil, odpoved]
      def stage_attachment(src, target_dir, att_id, file)
        FileUtils.mkdir_p(target_dir)
        target = File.join(target_dir, file)
        # NEMENNY nazov sa NIKDY neprepise — ani sirota mimo JSON (zakazkovy
        # snapshot na nu moze odkazovat).
        return [nil, [:copy_failed, { message: 'cieľový súbor už existuje' }]] if File.exist?(target)

        staging = File.join(target_dir, "#{att_id}.tmp")
        FileUtils.rm_f(staging)
        FileUtils.cp(src, staging)
        # Velkost sa overuje AJ na STAGINGU: zdroj sa medzi kontrolou a kopiou
        # mohol zvacsit (vzor `template_previews`).
        if File.size(staging) > MAX_ATTACHMENT_BYTES
          FileUtils.rm_f(staging)
          return [nil, too_large]
        end

        File.rename(staging, target)
        raise IOError, "presun prilohy na #{target} sa neprejavil" unless File.file?(target)

        [target, nil]
      rescue Errno::EACCES, Errno::EBUSY, IOError, SystemCallError => e
        begin
          FileUtils.rm_f(File.join(target_dir, "#{att_id}.tmp"))
        rescue StandardError
          nil
        end
        Engine.log_error(e, 'ApplianceCatalog.stage_attachment') if defined?(Engine)
        [nil, [:copy_failed, { message: 'súbor sa nepodarilo skopírovať (môže byť otvorený v inom programe)' }]]
      end

      def discard_file(target_dir, file)
        FileUtils.rm_f(File.join(target_dir, file))
        true
      rescue StandardError
        false
      end

      # Prepnutie `image` <-> `thumbnail`. Nahlad je najviac JEDEN.
      def set_thumbnail!(id, attachment_id, rev:)
        ensure_state
        with_fresh_document('set_thumbnail') do |fresh, records|
          idx = records.index { |r| r['id'].to_s == id.to_s }
          next not_found unless idx

          stored = records[idx]
          next conflict unless rev_ok?(stored, rev)

          items = stored['attachments'].is_a?(Array) ? stored['attachments'] : []
          target = items.find { |it| it['id'].to_s == attachment_id.to_s }
          next [:not_found, { message: 'príloha sa nenašla' }] unless target
          # Rozhoduje PRIPONA suboru, nie len dnesny druh: zaznam z cudzieho
          # alebo starsieho zapisu moze mat `kind: image` nad PDF a nahlad by
          # sa z neho stal jedinym kliknutim.
          if target['kind'].to_s == 'sheet' || !KIND_EXTS['thumbnail'].include?(attach_ext(target['file']))
            next invalid('náhľad sa dá nastaviť len z obrázka', 'kind')
          end

          swapped = items.map do |it|
            if it['id'].to_s == attachment_id.to_s
              it.merge('kind' => 'thumbnail')
            elsif it['kind'].to_s == 'thumbnail'
              it.merge('kind' => 'image')
            else
              it
            end
          end
          rec = stored.merge('attachments' => swapped, 'updated_at' => now_iso)
          updated = records.dup
          updated[idx] = rec
          next write_failed unless write_unlocked(updated, fresh)

          [:ok, { record: decorate(rec) }]
        end
      end

      # Odobratie prilohy ZO ZOZNAMU. Subor VEDOME ostava: bez indexu zakaziek
      # nevieme overit, ci nan neodkazuje uz ulozeny snapshot. Jeho nazov tym
      # ostava navzdy obsadeny (A2).
      def remove_attachment!(id, attachment_id, rev:)
        ensure_state
        with_fresh_document('remove_attachment') do |fresh, records|
          idx = records.index { |r| r['id'].to_s == id.to_s }
          next not_found unless idx

          stored = records[idx]
          next conflict unless rev_ok?(stored, rev)

          items = stored['attachments'].is_a?(Array) ? stored['attachments'] : []
          next [:not_found, { message: 'príloha sa nenašla' }] unless items.any? { |it| it['id'].to_s == attachment_id.to_s }

          kept = items.reject { |it| it['id'].to_s == attachment_id.to_s }
          rec = stored.merge('updated_at' => now_iso)
          kept.empty? ? rec.delete('attachments') : rec['attachments'] = kept
          updated = records.dup
          updated[idx] = rec
          next write_failed unless write_unlocked(updated, fresh)

          [:ok, { record: decorate(rec) }]
        end
      end

      # --- otvorenie prilohy (zivy zaznam AJ zakazkovy snapshot) ---------------

      # RESOLVER nad referenciou `{id, kind, file, name}` — NEZAVISLY od
      # aktualneho zoznamu priloh (po `remove_attachment!` zivy zaznam
      # mapovanie uz nema, ale snapshot zakazky ano).
      # -> [:ok, { path: }] | [:invalid|:missing_file, …]
      def attachment_path_for(ref)
        r = stringify(ref.is_a?(Hash) ? ref : {})
        rid = (r['id'] || r['catalog_id']).to_s
        file = r['file'].to_s
        return invalid('neplatná referencia na prílohu', 'id') if rid.empty?
        # Jediny segment podla vzoru `<uuid>_<slug>.<ext>` — ziadne `..`, `/`,
        # `\` ani absolutna cesta.
        unless file.match?(ATTACH_FILE_RE) && ATTACHMENT_EXTS.include?(attach_ext(file))
          return invalid('neplatný názov súboru prílohy', 'file')
        end

        base = record_dir(rid)
        return invalid('neplatná referencia na prílohu', 'id') unless base

        full = File.expand_path(File.join(base, file))
        unless full.start_with?("#{base}/") || full.start_with?("#{base}#{File::SEPARATOR}")
          return invalid('neplatná referencia na prílohu', 'file')
        end
        return [:missing_file, { message: 'súbor prílohy už neexistuje', path: full }] unless File.file?(full)

        [:ok, { path: full }]
      end

      # Cesta prilohy ZIVEHO zaznamu (deleguje na ten isty resolver).
      def attachment_path(id, attachment_id)
        ensure_state
        rec = stored_records.find { |r| r['id'].to_s == id.to_s }
        return not_found unless rec

        items = rec['attachments'].is_a?(Array) ? rec['attachments'] : []
        item = items.find { |it| it['id'].to_s == attachment_id.to_s }
        return [:not_found, { message: 'príloha sa nenašla' }] unless item

        attachment_path_for('id' => rec['id'], 'file' => item['file'])
      end

      # `file:///` + URI kodovanie s DOPREDNYMI lomkami — hola Windows cesta
      # s medzerami a diakritikou sa systemovemu prehliadacu neodovzda spolahlivo.
      # Nezakodovane ostavaju LEN `/` a `:` (oddelovace a pismeno disku);
      # predvoleny vzor `URI::DEFAULT_PARSER.escape` necha prejst aj `#` a `?`,
      # ktore by prehliadac precital ako fragment ci dotaz a subor by neotvoril.
      URL_SAFE = %r{[^A-Za-z0-9\-_.!~*'()/:]}.freeze

      # UNC cesta (`\\server\share\…`, teda po vymene lomiek `//server/share/…`)
      # ma HOSTITELA. Orezanie vsetkych uvodnych lomiek by z neho vyrobilo
      # `file:///server/share/…` — teda LOKALNU cestu na disk, ktora neexistuje;
      # spravny tvar je `file://server/share/…` (Codex #377 P2). Michal moze
      # mat `%APPDATA%` presmerovany na sietovy disk, takze to nie je teoria.
      def file_url(abs)
        p = abs.to_s.tr('\\', '/')
        return "file://#{URI::DEFAULT_PARSER.escape(p.sub(%r{\A/+}, ''), URL_SAFE)}" if p.start_with?('//')

        "file:///#{URI::DEFAULT_PARSER.escape(p.sub(%r{\A/+}, ''), URL_SAFE)}"
      end

      def open_attachment(id, attachment_id)
        status, info = attachment_path(id, attachment_id)
        return [status, info] unless status == :ok

        open_path(info[:path])
      end

      def open_attachment_ref(ref)
        status, info = attachment_path_for(ref)
        return [status, info] unless status == :ok

        open_path(info[:path])
      end

      # -> [:ok, {}] | [:open_failed, { message:, path: }]
      def open_path(abs)
        url = file_url(abs)
        unless defined?(UI) && UI.respond_to?(:openURL)
          return [:open_failed, { message: 'otvorenie súboru je dostupné len v SketchUpe', path: abs }]
        end

        ok = UI.openURL(url)
        return [:ok, {}] if ok

        [:open_failed, { message: 'súbor sa nepodarilo otvoriť', path: abs }]
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceCatalog.open_path') if defined?(Engine)
        [:open_failed, { message: 'súbor sa nepodarilo otvoriť', path: abs }]
      end

      # --- snapshot pre zakazku (S1-B) -----------------------------------------

      # Kluce, ktore ide snapshot zakazky NIEST. Explicitny whitelist —
      # zakazka nesmie zdedit stav katalogu (`updated_at`, `deleted_at`, `rev`).
      SNAPSHOT_KEYS = %w[category manufacturer name shop_urls sheet_urls note dims derived seed].freeze

      # CISTE citanie: hlboka kopia, takze neskorsia zmena katalogu snapshot
      # nikdy nezmeni. Prilohy cestuju ako NEMENNE referencie do katalogoveho
      # priecinka (subory pri tombstone ostavaju, zakazka ich otvori).
      # -> [:ok, { snapshot: }] | [:not_found|:deleted|:unsupported, …]
      def snapshot_for(id)
        ensure_state
        # Zdroj sa overuje CERSTVO, nie z cachovaneho stavu sedenia: zakazka si
        # snapshot ODLOZI a cachovane `:ok` nie je dokaz, ze subor medzitym
        # neprepisala NOVSIA instancia pluginu (updater bezi popri otvorenom
        # SketchUpe). Degradovany katalog (platna `.bak`) snapshot DOVOLI, ale
        # LEN ked zaloha prejde TOU ISTOU maticou ako primar (tvar, `std`,
        # identity, prilohy, rozmery) — zaloha z novsej verzie by inak odisla
        # do zakazky oznacena nasim `catalog_std` (Codex #377 kolo 2 P1).
        return [:unsupported, { message: state_reason }] unless JsonFileStore.available?(path)

        fresh = JsonFileStore.degraded?(path) ? backup_document : raw_document
        if (issue = stored_document_issue(fresh))
          # Pri degradovanom stave sa stav NEPREPISUJE na read-only — o tom
          # rozhoduje `assess!`; tu staci, ze snapshot NEVZNIKNE.
          set_state(:read_only, issue) unless degraded?
          return [:unsupported, { message: issue }]
        end

        # PRAVE OVERENY dokument ide do vyberu PRIAMO (a nikdy nie `nil`).
        # Druhe citanie cez `JsonFileStore.read` by v okne `CHECK_INTERVAL`
        # (1 s) vratilo CACHOVANY stav, takze by sa do zakazky mohol dostat
        # zaznam, ktory druha instancia SketchUpu prave zmenila alebo
        # vyradila (Codex #377 kolo 1 P1).
        rec = stored_records(fresh).find { |r| r['id'].to_s == id.to_s }
        return [:not_found, { message: 'spotrebič sa nenašiel' }] unless rec
        return [:deleted, { message: 'vyradený spotrebič sa nedá priradiť' }] if deleted?(rec)

        snap = { 'catalog_id' => rec['id'].to_s }
        SNAPSHOT_KEYS.each do |key|
          next unless rec.key?(key)

          snap[key] = deep_copy(rec[key])
        end
        items = rec['attachments'].is_a?(Array) ? rec['attachments'] : []
        refs = items.map do |it|
          { 'id' => rec['id'].to_s, 'kind' => it['kind'].to_s,
            'file' => it['file'].to_s, 'name' => it['name'].to_s }
        end
        snap['attachments'] = refs unless refs.empty?
        snap['catalog_std'] = STD
        snap['snapshot_at'] = now_iso
        [:ok, { snapshot: snap }]
      end

      # --- seed ----------------------------------------------------------------

      # MARKEROVY seed (vzor `TemplateStore`): seje sa VYHRADNE nad prazdnym
      # stavom (chyba primar aj `.bak`), NIKDY opakovane — zmazany seed zaznam
      # sa uz nevrati a pouzivatelska uprava sa neprepise. Doplnenie sady
      # v buducej davke = seed patch pri prechode `SEED_VERSION`.
      def seed!
        with_lock do
          next true if JsonFileStore.available?(path)

          stamp = now_iso
          records = seed_records.map do |rec|
            rec.merge('id' => SecureRandom.uuid, 'seed' => true,
                      'created_at' => stamp, 'updated_at' => stamp)
          end
          write_unlocked(records, nil, seed_version: SEED_VERSION)
        end
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceCatalog.seed!') if defined?(Engine)
        false
      end

      # DEVAT OVERENYCH modelov. Hodnoty a odkazy pochadzaju VYHRADNE
      # z `SYSTEM/zdroje/next_sessions/SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md`
      # (§1–§7 verdikty, §9 doplnenia z praxe, §11 URL listov). Co list
      # nekotuje, v seede NIE JE (ziadny tichy default); odvodene hodnoty su
      # vymenovane v `derived`.
      # Drez Blanco Legra XL 6 S sa VEDOME NESEEDUJE — list vyrobcu nie je
      # overeny (OVERENIE §12); Michal ho prida rucne. Kategoria `sink`
      # aj jej polia existuju od tejto davky.
      # Whirlpool ART 97101 2 vypadol tiez (list nedostupny, predaj skoncil).
      def seed_records
        [seed_oven_whirlpool, seed_micro_whirlpool, seed_micro_bosch, seed_oven_bosch,
         seed_fridge_beko, seed_dishwasher_whirlpool, seed_dishwasher_bosch,
         seed_hob_whirlpool, seed_hood_whirlpool]
      end

      def seed_oven_whirlpool
        { 'category' => 'oven', 'manufacturer' => 'Whirlpool', 'name' => 'OMSR58RU1SB',
          'dims' => {
            'body' => { 'width' => 548.0, 'height' => 570.0, 'depth' => 558.0 },
            # Nika STLPA; varianta pod pracovnou doskou (600–601) je v poznamke —
            # zaznam nesie jednu niku a dve varianty sa nesmu zliat do jedneho rozsahu.
            'niche' => { 'width_min' => 560.0, 'width_max' => 568.0,
                         'height_min' => 583.0, 'height_max' => 585.0, 'depth_min' => 560.0 },
            'front' => { 'width' => 595.0, 'height' => 595.0, 'thickness' => 20.0,
                         'overhang_top' => 20.0, 'overhang_bottom' => 5.0,
                         'overhang_ref' => 'body', 'vent_gap_below' => 9.0 }
          },
          'note' => 'Nika pod pracovnou doskou je 600–601 mm (v zázname je nika do stĺpa 583–585). Telo je vzadu 525 mm. ' \
                    'Kóta 9 je povinná medzera pod čelom (horúci výduch) — minimálny rozstup čiel 595 + 9 = 604 mm, v praxi 605. ' \
                    'Spodný presah čela je podľa výkresu 5 mm, detail otvorených dvierok pripúšťa 0 mm (ovplyvní len policu pod rúrou). ' \
                    'Odvetranie: výrez zadnej hrany police 35 mm. Korpus odolný 90 °C, 2 + 2 skrutky a lišta.',
          'sheet_urls' => [
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-98e6a4dd-cd45-4afb-991e-f8850c742cbb/pdf/W20036783_A.pdf',
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-de7f707a-b55c-4a8a-b60f-565c085299ae/pdf/PR859991660260sk.pdf'
          ] }
      end

      def seed_micro_whirlpool
        { 'category' => 'microwave', 'manufacturer' => 'Whirlpool', 'name' => 'MBNA900B',
          'dims' => {
            'body' => { 'width' => 544.0, 'height' => 348.0, 'depth' => 299.0 },
            'niche' => { 'width_min' => 560.0, 'width_max' => 568.0,
                         'height_min' => 360.0, 'height_max' => 363.0, 'depth_min' => 300.0 },
            'front' => { 'width' => 595.0, 'height' => 382.0, 'thickness' => 21.0,
                         'overhang_top' => 20.0, 'overhang_bottom' => 13.0, 'overhang_ref' => 'body' }
          },
          'note' => 'Spodný presah: list uvádza 13 mm, výkres 14 mm (14 + 348 + 20 = 382 sedí s výškou čela). ' \
                    'Telo má podľa listu šírku 540, podľa výkresu 544; celková hĺbka so dvierkami 316–319. ' \
                    'Alternatívna nika do stĺpa 560 × 380 × 550 s kitom AVM 105 (4801-310-00222). ' \
                    '4 skrutky do bokov, korpus 90 °C, dvierka 85°, vôľa 2 mm.',
          'sheet_urls' => [
            'https://mc-static.fast.eu/other/40/40046680/40046680-other.pdf',
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-94f27ca5-604a-4a2a-b1c0-27c8ec28ba1b/pdf/400011661025SK.pdf',
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-c1090179-f21f-4a98-8169-2e58a734e041/pdf/PR859991659350sk.pdf'
          ] }
      end

      def seed_micro_bosch
        { 'category' => 'microwave', 'manufacturer' => 'Bosch', 'name' => 'BFL7221B1',
          'dims' => {
            # Sirku a vysku tela list NEKOTUJE — 550 x 340 su odvodene (derived).
            'body' => { 'width' => 550.0, 'height' => 340.0, 'depth' => 299.0 },
            'niche' => { 'width_min' => 560.0, 'width_max' => 568.0,
                         'height_min' => 362.0, 'height_max' => 365.0, 'depth_min' => 300.0 },
            # Bosch kotuje presah voci NIKE, nie voci telu.
            'front' => { 'width' => 594.0, 'height' => 382.0, 'thickness' => 19.5,
                         'overhang_top' => 6.0, 'overhang_bottom' => 14.0, 'overhang_ref' => 'niche' }
          },
          'derived' => %w[body.width body.height],
          'note' => 'Šírku a výšku tela list nekótuje — 550 × 340 sú odvodené, neoverené. ' \
                    'Presah hore je 6 mm pri nike 362 a 3 mm pri nike 365. Celkový rozmer spotrebiča 382 × 594 × 318. ' \
                    'Alternatívna nika do stĺpa 560⁺⁸ × 380⁺² × min 550 (35 mm vzadu, zadná stena voľná). ' \
                    'Bočná vôľa 16 mm od steny, šírka skrinky 600.',
          'sheet_urls' => ['https://media3.bsh-group.com/Documents/specsheet/sk-SK/BFL7221B1.pdf'] }
      end

      def seed_oven_bosch
        { 'category' => 'oven', 'manufacturer' => 'Bosch', 'name' => 'HBG774KB1',
          'dims' => {
            # Sirku tela list nekotuje (kluc preto CHYBA); hlbka 548 je odvodena.
            'body' => { 'height' => 577.0, 'depth' => 548.0 },
            'niche' => { 'width_min' => 560.0, 'width_max' => 568.0,
                         'height_min' => 585.0, 'height_max' => 595.0, 'depth_min' => 550.0 },
            'front' => { 'width' => 594.0, 'height' => 595.0, 'thickness' => 19.5,
                         'overhang_top' => 18.0, 'overhang_bottom' => 0.0,
                         'overhang_ref' => 'body', 'vent_gap_below' => 0.0 }
          },
          'derived' => %w[body.depth],
          'note' => 'Hĺbka tela nie je overená — list uvádza 548 mm ako „rozmer spotrebiča" a nerozlišuje ju od niky min 550. Šírku tela nekótuje. ' \
                    'Nika pod pracovnou doskou: min 600⁺⁴ × 560⁺⁸ × min 550, medzera 20 pod doskou, miesto na prípojku 320 × 115. ' \
                    'Kóta 7,5 je odvetranie už v rozmere čela, nie presah. Odvetranie pri dvoch spotrebičoch nad sebou: otvor min 200 cm² v sokli, 35 mm vzadu. ' \
                    'Hrúbka pracovnej dosky nad rúrou podľa listu: indukčná ≥ 37/38, celopovrchová ≥ 47/48, plynová ≥ 30/38, elektrická ≥ 27/30.',
          'sheet_urls' => ['https://media3.bsh-group.com/Documents/specsheet/sk-SK/HBG774KB1.pdf'] }
      end

      def seed_fridge_beko
        { 'category' => 'fridge', 'manufacturer' => 'Beko', 'name' => 'BCNA306E5ZSN',
          'dims' => {
            'body' => { 'width' => 540.0, 'height' => 1935.0, 'depth' => 545.0 },
            'niche' => { 'width_min' => 560.0, 'height_min' => 1940.0, 'height_max' => 1950.0,
                         'depth_min' => 555.0 },
            # Dvere SPOTREBICA zhora: horne 1159 · medzera 71 · dolne 629 · spodok 40.
            'front' => { 'door_bottom_offset' => 40.0, 'door_lower' => 629.0,
                         'door_gap' => 71.0, 'door_upper' => 1159.0 },
            'install' => { 'door_system' => 'sliding' }
          },
          'note' => 'Pásma dverí sú viazané ZDOLA: 40 + 629 = 669 je presné, horné pásmo je zvyšok do výšky niky ' \
                    '(spolu 1899, s horným držiakom 32 = 1931 — zvyšné 4 mm list nekótuje). ' \
                    'Nábytkové dvere: škáry 2 mm, posuvné lišty (X < 10 mm). ' \
                    'Odvetranie min 200 cm² dole aj hore a zadná stena skrinky úplne otvorená ku stene kuchyne (nie kanál 50). ' \
                    'Nosnosť dna list nekótuje.',
          'sheet_urls' => [
            'https://www.beko.com/content/dam/poland-pl-aem/poland-pl-aemProductCatalog/product-documents/7522520024-BCNA306E5ZSN/en-US-7522520024-202308210830197-Installation-Diagramtr-TR.pdf',
            'https://www.manualslib.com/manual/1873435/Beko-Bcna306e3s.html?page=4',
            'https://www.beko.com/content/dam/slovakia-sk-aem/slovakia-sk-aemProductCatalog/product-documents/7522520024-BCNA306E5ZSN/en-US-7522520024-202308281605655-Product-Information-Sheet-EU-2021-EPen-US.pdf'
          ] }
      end

      def seed_dishwasher_whirlpool
        { 'category' => 'dishwasher', 'manufacturer' => 'Whirlpool', 'name' => 'WIO 3O540 PELG',
          'dims' => {
            # Vyska tela je ROZSAH (nastavitelne nohy) — patri do `install`.
            'body' => { 'width' => 598.0, 'depth' => 555.0 },
            'niche' => { 'width_min' => 600.0, 'height_min' => 820.0, 'height_max' => 900.0,
                         'depth_min' => 560.0 },
            'front' => { 'width' => 594.0, 'height_max' => 720.0,
                         'weight_min' => 2.0, 'weight_max' => 10.0 },
            'install' => { 'dishwasher_class' => '600',
                           'body_height_min' => 820.0, 'body_height_max' => 900.0 }
          },
          'note' => 'Výška čela a hmotnosť sú EVIDENCIA z listu, nekontrolujú sa (minimum výšky list nedáva). ' \
                    'V praxi sa umývačka umiestni takmer na minimálnu výšku a zvyšok po líniu linky vyplní blenda. ' \
                    'Lišta k = 585 mm; prípojky ~1300 el. / ~1500 voda a odpad, odpad 400–800 nad podlahou, Ø min 25. ' \
                    'Ten istý list platí aj pre 45 cm verziu (telo 448, čelo 444, hmotnosť 2–7,5 kg).',
          'sheet_urls' => [
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-7be584ca-2037-45fc-9588-934b9946ea10/pdf/W11401540_E.pdf'
          ] }
      end

      def seed_dishwasher_bosch
        { 'category' => 'dishwasher', 'manufacturer' => 'Bosch', 'name' => 'SPV6EMX05E',
          'dims' => {
            'body' => { 'width' => 448.0, 'depth' => 550.0 },
            'niche' => { 'width_min' => 450.0, 'height_min' => 815.0, 'height_max' => 875.0,
                         'depth_min' => 550.0 },
            'front' => { 'height_max' => 725.0 },
            'install' => { 'dishwasher_class' => '450', 'plinth_min' => 90.0, 'plinth_max' => 220.0,
                           'body_height_min' => 815.0, 'body_height_max' => 875.0 }
          },
          'note' => 'Nábytkové čelo 655–725 mm (v zázname je maximum; minimum 655 je evidencia z listu). ' \
                    'Šírku nábytkového čela ani hmotnosť list neuvádza. Výkres kótuje šírku niky len 450 (bez +8). ' \
                    'Nastavenie výšky max 60 mm, hĺbka s otvorenými dverami 1150.',
          'sheet_urls' => ['https://media3.bsh-group.com/Documents/specsheet/de-DE/SPV6EMX05E.pdf'] }
      end

      def seed_hob_whirlpool
        { 'category' => 'hob', 'manufacturer' => 'Whirlpool', 'name' => 'WL B1160 BF',
          'dims' => {
            # Telo = vana pod sklom (551 x 479 x 50).
            'body' => { 'width' => 551.0, 'height' => 50.0, 'depth' => 479.0 },
            'front' => { 'outer_width' => 590.0, 'outer_depth' => 510.0,
                         'cutout_width' => 560.0, 'cutout_depth' => 480.0,
                         'cutout_depth_max' => 492.0, 'mount_depth' => 50.0,
                         'worktop_min' => 12.0 }
          },
          'note' => 'Sklo 590 × 510 × 4 mm, vaňa (telo) 551 × 479 × 50. Výrez 560 (+0/+2) × 480–492, rádius rohu max 10 mm. ' \
                    'Hrúbka pracovnej dosky min 12 mm, nad rúrou min 28. ' \
                    'Odstupy: min 35 od zadnej hrany, min 100 od bočnej steny alebo vysokej skrinky, min 400 nad doskou k hornej skrinke. ' \
                    'Spodná medzera min 10 nad deliacou doskou; deliaca doska nad zásuvkami je povinná (min 20 od zadnej steny). ' \
                    'Digestor nad doskou sa tu nerieši.',
          'sheet_urls' => [
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-68d37b84-f29b-4808-a8a8-d39dc3330b93/pdf/W20027062_A.pdf',
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-d8ada554-2c49-44a5-85f0-f15004a0a5dd/pdf/PR859991572120sk.pdf'
          ] }
      end

      def seed_hood_whirlpool
        { 'category' => 'hood', 'manufacturer' => 'Whirlpool', 'name' => 'WCT3 63F LTK',
          'dims' => {
            'body' => { 'width' => 514.0, 'height' => 334.0, 'depth' => 283.0 },
            'front' => { 'min_cabinet_width' => 600.0, 'cutout_width' => 437.0,
                         'cutout_depth' => 216.0, 'duct_diameter' => 149.0 }
          },
          'note' => 'Výrez do dna skrinky 437 × 216 mm; od výrezu k hrane spotrebiča 44 mm, svetlá 381. ' \
                    'Telo 514 × 334 (min 307) × 283, vnútorné 493 × 260, výstup 19. Stred odvodu 93 mm od zadnej steny, Ø 149 (redukcia 120). ' \
                    'V praxi býva výrez odsadený 20 mm od prednej hrany dna kvôli krycej doske. ' \
                    'Výška nad doskou (min 500 elektrická / 650 plynová) sa vo V1 nerieši.',
          'sheet_urls' => [
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-d3874dda-a288-4a4b-976d-1238c4e8e2a0/pdf/ETD859991672930EN.pdf',
            'https://digitalassets-cdn.thron.com/api/v1/content-delivery/shares/ivq4cm/contents/do-0c7835b6-8356-4169-9334-3bcf89152306/pdf/LIB0195104A.pdf'
          ] }
      end
    end
  end
end
