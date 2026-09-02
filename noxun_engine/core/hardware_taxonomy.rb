# frozen_string_literal: true
# Noxun Engine — KOV-B1: TAXONOMIA VYROBCOV A RAD KOVANIA.
#
# PRECO SAMOSTATNY SUBOR: set kovania aj polozka katalogu od KOV-B1 nesu
# `manufacturer` a (nepovinne) `series`. Keby si kazdy z nich pisal vlastny
# retazec, vznikla by za mesiac zbierka „Hettich" / „hettich" / „HETTICH " /
# „Hettch" a strom katalogu (KOV-B2) ani filtre (KOV-D) by sa nedali postavit.
# Taxonomia je preto JEDINY zoznam pripustnych mien — set aj polozka ukladaju
# KANONICKY NAZOV odtialto (nie id: nazov cestuje medzi PC bez joinu).
#
# ULOZISKO: %APPDATA%\NOXUN\Engine\hardware_taxonomy.json (+ `.bak`), teda
# GLOBALNE — zdielaju ho vsetky verzie pluginu na profile. Kontrakt je preto
# rovnaky ako u kniznice setov (R-07/R-08/R-11) a katalogu kovania (GH #99):
#   { "std": "noxun-hardware-taxonomy", "schema": 1, "seed_version": 1,
#     "manufacturers": [ { "name": "Hettich" }, ... ],
#     "series":        [ { "name": "Sensys", "manufacturer": "Hettich" }, ... ] }
#
# IDENTITA MENA je `Materials.slug` — teda case-insensitive a bez diakritiky
# („Hettich" == „hettich" == „HETTICH"). `name` je KANONICKY ZOBRAZOVANY tvar
# (prve zapisane znenie); do setov a poloziek sa uklada prave on.
#
# RADA PATRI PRESNE JEDNEMU VYROBCOVI (audit #17 BLOCKER 4). Slug rady je preto
# GLOBALNE unikatny — „Sensys" nemoze byt zaroven pod Blumom, inak by sa z ulozeneho
# retazca „Sensys" nedalo zistit, ci je to Hettich alebo Blum.
#
# API JE LEN CREATE (audit #17 FIX 10, register R-35): `create_manufacturer!` a
# `create_series!`. Premenovanie a mazanie NIE SU vo V1 — obe by museli prejst
# vsetky sety, polozky, snapshoty v .skp aj sablony a bez toho by za sebou
# nechali osirele retazce. „Uplna nahrada" obsahu (vzor pravidiel kovania) sa
# tu vedome NEZAVADZA: dve otvorene okna by si ju prebili.
#
# STAVY (matica ako `HardwareSets`): `:ok` · `:degraded` (poskodeny primar +
# platna `.bak` — CITA sa, do SUBORU sa nezapisuje) · `:read_only` (cudzi std,
# novsia schema, neznamy tvar, duplicita — nesmie sa ani citat, `load` vrati
# PRAZDNO a NIKDY seed). Stav sa NECACHUJE: subor moze medzitym vymenit druha
# instancia, takze zapamatane `:ok` nie je dokaz. `@state_*` su len VYSLEDOK
# poslednej kontroly pre volajuceho, ktory sa uz spytal.
require 'digest'
require 'json'

module Noxun
  module Engine
    module HardwareTaxonomy
      STD            = 'noxun-hardware-taxonomy'
      SCHEMA_CURRENT = 1
      SEED_VERSION   = 1
      FILE           = 'hardware_taxonomy.json'

      # Whitelisty klucov (KONTRAKT — vzor HardwareSets::SET_KEYS): kluc mimo
      # nich znamena obsah novsej verzie a subor sa smie uz len CITAT. Nove pole
      # sa musi doplnit SEM, inak si vlastny zapis vyrobi read-only stav.
      MANUFACTURER_KEYS = %w[name].freeze
      SERIES_KEYS       = %w[name manufacturer].freeze

      # Horna hranica dlzky mena (obrana proti poskodenemu vstupu; zobrazuje sa
      # v chipoch a stromoch, kde by 5000 znakov rozbilo layout).
      MAX_NAME = 60

      # SEED (v1). Zdroj: SYSTEM/zdroje/SEED_KATALOG_2026-07.md + debata 2.8.2026.
      # Doplna sa LEN to, co v subore CHYBA — pouzivatelske mena sa nikdy
      # neprepisuju a nic sa nemaze.
      SEED_MANUFACTURERS = ['Hettich', 'Blum', 'Grass', 'Strong', 'Ostatné'].freeze
      SEED_SERIES = [
        ['Sensys', 'Hettich'], ['InnoTech Atira', 'Hettich'], ['Quadro', 'Hettich'],
        ['AvanTech YOU', 'Hettich'], ['AXILO', 'Hettich'],
        ['CLIP top', 'Blum'], ['AVENTOS', 'Blum'], ['TANDEMBOX', 'Blum'],
        ['LEGRABOX', 'Blum'], ['MERIVOBOX', 'Blum'], ['TIP-ON', 'Blum'],
        ['Nova Pro', 'Grass'], ['Tiomos', 'Grass'],
        ['StrongMax', 'Strong']
      ].freeze

      module_function

      # --- ulozisko -----------------------------------------------------------

      def dir
        Materials.dir # zdielany %APPDATA%/NOXUN/Engine (+ test_dir_override)
      end

      def path
        File.join(dir, FILE)
      end

      # JEDEN sidecar zamok pre VSETKY globalne katalogy (`materials.lock`,
      # vzor 1b-6c/R-08) — vlastny zamok per subor by vyrobil PORADIE zamkov.
      # Je reentrantny; zlyhany `flock` vyhodi IOError a kazda zapisova cesta
      # ho rescue-uje do svojho NEUSPESNEHO vysledku, nikdy do ticheho uspechu.
      def with_catalog_lock(&blk)
        Materials.with_catalog_lock(&blk)
      end

      # --- identita mena ------------------------------------------------------

      # Kanonicky kluc mena: `Materials.slug` je JEDINA translit autorita v repe
      # (NFD + odstranenie diakritiky + upcase + nealfanumericke znaky na '_').
      def key_of(name)
        Materials.slug(name)
      end

      def same_name?(a, b)
        k = key_of(a)
        !k.empty? && k == key_of(b)
      end

      # --- stav ---------------------------------------------------------------

      def state
        apply_state(*assess(read_doc))
      end

      def state_code
        @state_code
      end

      def state_reason
        @state_reason.to_s
      end

      def read_only?
        state == :read_only
      end

      # Smie sa zapisat do SUBORU? `:read_only` zakazuje vsetko, `:degraded` LEN
      # zapis (obsah zalohy je platny a da sa citat aj pouzit).
      def write_blocked?
        [:read_only, :degraded].include?(state)
      end

      # Test-only reset (stav je modulova pamat nad globalnym suborom).
      def reset_state!
        @state = nil
        @state_code = nil
        @state_reason = ''
        true
      end

      # JEDNA matica: dokument (`assess_doc`, ciste) + stav SUBOROV na disku
      # (degraded). Poradie je zamerne — nad nezrozumitelnym dokumentom sa
      # degraded uz neriesi (`:read_only` je prisnejsi aj dolezitejsi).
      def assess(doc)
        state, code, reason = assess_doc(doc)
        return [state, code, reason] unless state == :ok
        return [:degraded, :degraded, degraded_sk] if degraded_file?

        [:ok, nil, '']
      end

      # R-11 vzor: poskodeny primar + platna `.bak`. Cita PRIAMO z disku (bez
      # sekundovej cache) — cache by vratila hodnotu spred poskodenia. I/O chyby
      # sa TU nerescue-uju: vyletia do rescue vetiev volajucich ako NEUSPECH.
      def degraded_file?
        JsonFileStore.degraded?(path)
      end

      # CISTA matica stavu nad DOKUMENTOM (ziadne IO).
      # doc = nil (subor neexistuje = cisty stav, seed) | Hash | cokolvek ine.
      # -> [:ok, nil, ''] | [:read_only, kod, SK dovod]
      def assess_doc(doc)
        return [:ok, nil, ''] if doc.nil?
        return [:read_only, :unreadable, unreadable_sk] unless doc.is_a?(Hash)
        return [:read_only, :foreign, foreign_sk] if doc['std'].to_s != STD
        return [:read_only, :newer, newer_sk] if doc['schema'].to_i > SCHEMA_CURRENT

        mans = doc['manufacturers']
        sers = doc['series']
        unless (mans.nil? || mans.is_a?(Array)) && (sers.nil? || sers.is_a?(Array))
          return [:read_only, :unreadable, unreadable_sk]
        end

        assess_records(Array(mans), Array(sers))
      rescue StandardError => e
        # BRANA MUSI ZLYHAT ZATVORENE (vzor HardwareSets.assess_library_doc):
        # sem padne aj PROGRAMATORSKA chyba nad zdravym suborom, preto vlastny
        # kod a hlaska, ktora NENAVADZA subor zmazat.
        Engine.log_error(e, 'HardwareTaxonomy.assess_doc') if defined?(Engine)
        [:read_only, :unexpected_shape, unexpected_sk]
      end

      # Tvar a integrita zaznamov. Vracia tu istu trojicu ako `assess_doc`.
      def assess_records(mans, sers)
        return [:read_only, :unknown_shape, unknown_shape_sk] if mans.any? { |m| bad_record?(m, MANUFACTURER_KEYS) }
        return [:read_only, :unknown_shape, unknown_shape_sk] if sers.any? { |s| bad_record?(s, SERIES_KEYS) }

        mkeys = mans.map { |m| key_of(m['name']) }
        return [:read_only, :duplicate, duplicate_sk] if mkeys.length != mkeys.uniq.length

        skeys = sers.map { |s| key_of(s['name']) }
        # Rada patri PRESNE jednemu vyrobcovi -> slug rady je globalne unikatny.
        # Ten isty slug dvakrat (aj pod dvoma vyrobcami) = nejednoznacna identita.
        return [:read_only, :duplicate, duplicate_sk] if skeys.length != skeys.uniq.length

        # Rada bez existujuceho vyrobcu = rozbita integrita (nie „novsia verzia").
        orphan = sers.any? { |s| !mkeys.include?(key_of(s['manufacturer'])) }
        return [:read_only, :unknown_shape, orphan_sk] if orphan

        [:ok, nil, '']
      end

      # Zaznam je Hash so ZNAMYMI klucmi a NEPRAZDNYMI String hodnotami.
      def bad_record?(rec, keys)
        return true unless rec.is_a?(Hash)
        return true unless (rec.keys.map(&:to_s) - keys).empty?

        keys.any? { |k| !rec[k].is_a?(String) || rec[k].strip.empty? || key_of(rec[k]).empty? }
      end

      # --- SK dovody (jedno znenie pre banner, status aj log) ------------------

      def unreadable_sk
        "Zoznam výrobcov a rád kovania sa nedá prečítať — oprav alebo zmaž súbor #{path}"
      end

      def foreign_sk
        'Zoznam výrobcov a rád kovania patrí inému systému (marker std)'
      end

      def newer_sk
        'Zoznam výrobcov a rád kovania je z novšej verzie Noxun — aktualizuj plugin'
      end

      def unknown_shape_sk
        'Zoznam výrobcov a rád kovania obsahuje údaje, ktoré táto verzia Noxun nepozná — aktualizuj plugin'
      end

      def orphan_sk
        'Zoznam výrobcov a rád kovania má radu bez výrobcu — oprav súbor'
      end

      def duplicate_sk
        'Zoznam výrobcov a rád kovania má duplicitné mená — oprav súbor'
      end

      def degraded_sk
        'Zoznam výrobcov a rád kovania je poškodený — číta sa záloha, zápisy sú vypnuté ' \
          "(oprav alebo zmaž súbor #{path})"
      end

      def unexpected_sk
        'Zoznam výrobcov a rád kovania má neočakávaný tvar alebo nastala interná chyba — ' \
          'nič sa nezapisuje. Súbor NEMAŽ, nahlás problém.'
      end

      def apply_state(state, code, reason)
        changed = @state != state || @state_code != code
        @state = state
        @state_code = code
        @state_reason = reason.to_s
        # Log LEN pri ZMENE stavu — brana sa vyhodnocuje pri KAZDOM pouziti,
        # takze bezpodmienecny zapis by zaplavil Ruby konzolu.
        if changed && state != :ok && defined?(Engine) && Engine.respond_to?(:log)
          Engine.log("hardware taxonomy: #{state == :degraded ? 'DEGRADOVANA' : 'READ-ONLY'} — #{reason}")
        end
        state
      end

      # --- citanie ------------------------------------------------------------

      # Dokument na posudenie. Chybajuci subor = CISTY stav (nil). Poskodeny
      # primar BEZ zalohy je tiez cisty stav (nie je z coho co stratit a prvy
      # zapis subor SAMOOPRAVI) — so zalohou konci ako `:unreadable`.
      def read_doc
        return nil unless JsonFileStore.available?(path)

        JsonFileStore.read(path, copy: false)
      rescue StandardError
        File.exist?("#{path}.bak") ? :unreadable : nil
      end

      def blank
        { 'manufacturers' => [], 'series' => [] }
      end

      # Zoznam vyrobcov a rad. Z NEKOMPATIBILNEHO suboru NIKDY nevyda obsah ani
      # seed (cudzie defaulty by prvy zapis zvecnil — lekcia R-07 P1-1).
      # Poradie je deterministicke (podla kanonickeho kluca).
      def load
        ensure_seeded
        doc = read_doc
        return blank if apply_state(*assess(doc)) == :read_only
        return blank unless doc.is_a?(Hash)

        { 'manufacturers' => norm_records(doc['manufacturers'], MANUFACTURER_KEYS),
          'series' => norm_records(doc['series'], SERIES_KEYS) }
      rescue StandardError => e
        Engine.log_error(e, 'HardwareTaxonomy.load') if defined?(Engine)
        blank
      end

      def norm_records(list, keys)
        seen = {}
        Array(list).filter_map do |rec|
          next nil if bad_record?(rec, keys)

          k = key_of(rec['name'])
          next nil if seen[k]

          seen[k] = true
          keys.each_with_object({}) { |f, out| out[f] = rec[f].to_s.strip }
        end.sort_by { |rec| key_of(rec['name']) }
      end

      def manufacturers
        load['manufacturers']
      end

      def find_manufacturer(name)
        return nil if key_of(name).empty?

        load['manufacturers'].find { |m| same_name?(m['name'], name) }
      end

      # Rada podla mena (slug rady je globalne unikatny — vlastnika nesie zaznam).
      def find_series(name)
        return nil if key_of(name).empty?

        load['series'].find { |s| same_name?(s['name'], name) }
      end

      def series_of(manufacturer)
        return [] if key_of(manufacturer).empty?

        load['series'].select { |s| same_name?(s['manufacturer'], manufacturer) }
      end

      # Odtlacok suboru — baseline guard okna (vzor HardwareSets.revision).
      # Pocita sa z KANONICKEHO JSONu obsahu, nie zo surovych bajtov: preformatovanie
      # suboru (odsadenie) nie je zmena obsahu a nesmie vyrobit falosny konflikt.
      def revision
        Digest::SHA1.hexdigest(JSON.generate(load))[0, 12]
      end

      # KOHERENTNA dvojica pre payload okna (vzor R-08 #4): obsah aj revizia
      # pochadzaju z JEDNEHO stavu suboru. Zlyhany zamok = revizia sa berie PRED
      # obsahom, takze neskorsi nesulad vyrobi nanajvys FALOSNY konflikt.
      def load_with_revision
        with_catalog_lock do
          JsonFileStore.reload!(path)
          doc = load
          [doc, revision]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareTaxonomy.load_with_revision') if defined?(Engine)
        rev = revision
        [load, rev]
      end

      # --- kontrola klasifikacie (pouziva ju set aj polozka katalogu) ---------

      # Patri dvojica (vyrobca, rada) do taxonomie? -> [] | [{ 'field', 'msg' }].
      # Prazdna dvojica = nic sa nekontroluje (nezaradeny set/polozka).
      # POZOR: volajuci si musi NAJPRV overit `read_only?` — nad nekompatibilnou
      # taxonomiou vracia `load` prazdno a kontrola by hlasila „vyrobca nie je
      # v zozname", hoci skutocny dovod je uplne iny.
      def check_classification(manufacturer, series = nil)
        resolve_classification(manufacturer, series)[2]
      end

      # KANONICKA PODOBA dvojice (vyrobca, rada) + chyby. Kontrola je
      # case-insensitive a bez diakritiky, takze „hettich" NAJDE „Hettich" —
      # ale ulozit sa smie VYHRADNE kanonicky zapis zo zoznamu. Keby si volajuci
      # ulozil svoj vstup, vzniklo by v kniznici „hettich" VEDLA „Hettich"
      # a padol by invariant JEDINEHO mena, na ktorom stoji zoskupenie katalogu
      # (KOV-B2) aj filtre (KOV-D) — teda presne to, kvoli comu taxonomia vznikla.
      # Zapisove cesty setu aj polozky preto beru mena ODTIALTO.
      # -> [canon_manufacturer|nil, canon_series|nil, errors]
      def resolve_classification(manufacturer, series = nil)
        man = manufacturer.to_s.strip
        ser = series.to_s.strip
        return [nil, nil, []] if man.empty? && ser.empty?
        if man.empty?
          return [nil, nil, [{ 'field' => 'manufacturer',
                               'msg' => "rada „#{ser}“ sa nedá priradiť bez výrobcu" }]]
        end

        doc = load
        m = doc['manufacturers'].find { |x| same_name?(x['name'], man) }
        if m.nil?
          return [nil, nil, [{ 'field' => 'manufacturer',
                               'msg' => "výrobca „#{man}“ nie je v zozname — najprv ho pridaj" }]]
        end
        return [m['name'], nil, []] if ser.empty?

        s = doc['series'].find { |x| same_name?(x['name'], ser) }
        if s.nil?
          [m['name'], nil,
           [{ 'field' => 'series',
              'msg' => "rada „#{ser}“ nie je v zozname — najprv ju pridaj k výrobcovi „#{m['name']}“" }]]
        elsif !same_name?(s['manufacturer'], m['name'])
          [m['name'], nil,
           [{ 'field' => 'series',
              'msg' => "rada „#{ser}“ patrí výrobcovi „#{s['manufacturer']}“" }]]
        else
          [m['name'], s['name'], []]
        end
      end

      # --- zapis --------------------------------------------------------------

      # JEDINY zapis do suboru. Berie zamok, cita CERSTVO a ZNOVU posudi branu —
      # cachovane `:ok` nie je dokaz (druha instancia mohla subor medzitym
      # nahradit novsim tvarom a nas zapis by ho zhodil na ten, ktoremu rozumieme).
      def write(manufacturers, series, seed_version = SEED_VERSION)
        with_catalog_lock do
          JsonFileStore.reload!(path)
          before = @state
          if [:read_only, :degraded].include?(apply_state(*assess(read_doc)))
            if before != @state && defined?(Engine)
              Engine.log("hardware taxonomy: zapis odmietnuty — #{state_reason}")
            end
            next false
          end
          JsonFileStore.write(path, { 'std' => STD, 'schema' => SCHEMA_CURRENT,
                                      'seed_version' => seed_version.to_i,
                                      'manufacturers' => manufacturers,
                                      'series' => series })
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareTaxonomy.write') if defined?(Engine)
        false
      end

      # --- seed ---------------------------------------------------------------

      def stored_seed_version
        doc = read_doc
        doc.is_a?(Hash) ? doc['seed_version'].to_i : 0
      end

      def seed_needed?(doc)
        return true if doc.nil?
        return false unless doc.is_a?(Hash)

        doc['seed_version'].to_i < SEED_VERSION
      end

      # CHECK-BEFORE-LOCK by sa dal predbehnut (R-08 #1): rychla kontrola ostava
      # (je to hot cesta), ale ZAPIS ide az po DRUHOM checku POD zamkom nad
      # cerstvo precitanym suborom. Nad read-only ani degradovanou taxonomiou sa
      # seed NEROBI — do cudzieho/poskodeneho suboru by sme primiesali svoje mena.
      def ensure_seeded
        return true unless seed_needed?(read_doc)

        with_catalog_lock do
          JsonFileStore.reload!(path)
          fresh = read_doc
          next false unless apply_state(*assess(fresh)) == :ok
          next true unless seed_needed?(fresh)

          mans, sers = merge_seed(fresh)
          write(mans, sers, SEED_VERSION)
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareTaxonomy.ensure_seeded') if defined?(Engine)
        false
      end

      # Doplni LEN CHYBAJUCE mena (podla kanonickeho kluca) — pouzivatelske
      # zaznamy sa NIKDY neprepisuju a nic sa nemaze. -> [manufacturers, series]
      def merge_seed(doc)
        mans = doc.is_a?(Hash) ? norm_records(doc['manufacturers'], MANUFACTURER_KEYS) : []
        sers = doc.is_a?(Hash) ? norm_records(doc['series'], SERIES_KEYS) : []
        have_m = mans.map { |m| key_of(m['name']) }
        SEED_MANUFACTURERS.each do |name|
          next if have_m.include?(key_of(name))

          mans << { 'name' => name }
          have_m << key_of(name)
        end
        have_s = sers.map { |s| key_of(s['name']) }
        SEED_SERIES.each do |(name, man)|
          next if have_s.include?(key_of(name))

          sers << { 'name' => name, 'manufacturer' => man }
          have_s << key_of(name)
        end
        [mans.sort_by { |m| key_of(m['name']) }, sers.sort_by { |s| key_of(s['name']) }]
      end

      # --- API (LEN create — R-35 / audit #17 FIX 10) -------------------------

      # Novy vyrobca. revision = baseline z casu nacitania okna (cudzia zmena
      # medzitym = `:conflict`, okno sa obnovi). Revizia sa porovnava AZ POD
      # ZAMKOM nad cerstvym suborom (R-08 TOCTOU).
      # -> [:ok, rec] | [:exists, rec] | [:invalid, msg] | [:conflict, nil] |
      #    [:write_failed, reason|nil]
      def create_manufacturer!(name, revision: nil)
        nm, err = clean_name(name, 'výrobcu')
        return [:invalid, err] if nm.nil?

        with_catalog_lock do
          JsonFileStore.reload!(path)
          next [:write_failed, state_reason] if write_blocked?
          next [:conflict, nil] if revision && revision != self.revision

          doc = load
          exist = doc['manufacturers'].find { |m| same_name?(m['name'], nm) }
          next [:exists, exist] if exist

          rec = { 'name' => nm }
          mans = (doc['manufacturers'] + [rec]).sort_by { |m| key_of(m['name']) }
          next [:write_failed, nil] unless write(mans, doc['series'], stored_seed_version)

          [:ok, rec]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareTaxonomy.create_manufacturer!') if defined?(Engine)
        [:write_failed, nil]
      end

      # Nova rada POD KONKRETNYM vyrobcom. Rada patri presne jednemu vyrobcovi:
      # rovnaky slug pod TYM ISTYM = `:exists`, pod INYM = `:invalid`.
      # -> [:ok, rec] | [:exists, rec] | [:invalid, msg] | [:conflict, nil] |
      #    [:write_failed, reason|nil]
      def create_series!(name, manufacturer, revision: nil)
        nm, err = clean_name(name, 'radu')
        return [:invalid, err] if nm.nil?

        man = manufacturer.to_s.strip
        return [:invalid, 'rada sa nedá pridať bez výrobcu'] if key_of(man).empty?

        with_catalog_lock do
          JsonFileStore.reload!(path)
          next [:write_failed, state_reason] if write_blocked?
          next [:conflict, nil] if revision && revision != self.revision

          doc = load
          owner = doc['manufacturers'].find { |m| same_name?(m['name'], man) }
          next [:invalid, "výrobca „#{man}“ nie je v zozname — najprv ho pridaj"] if owner.nil?

          exist = doc['series'].find { |s| same_name?(s['name'], nm) }
          if exist
            next [:exists, exist] if same_name?(exist['manufacturer'], owner['name'])

            next [:invalid, "rada „#{nm}“ už patrí výrobcovi „#{exist['manufacturer']}“"]
          end
          rec = { 'name' => nm, 'manufacturer' => owner['name'] }
          sers = (doc['series'] + [rec]).sort_by { |s| key_of(s['name']) }
          next [:write_failed, nil] unless write(doc['manufacturers'], sers, stored_seed_version)

          [:ok, rec]
        end
      rescue StandardError => e
        Engine.log_error(e, 'HardwareTaxonomy.create_series!') if defined?(Engine)
        [:write_failed, nil]
      end

      # -> [ocisteny nazov, nil] | [nil, SK chyba]
      def clean_name(raw, what)
        nm = raw.to_s.strip
        return [nil, "názov #{what} nesmie byť prázdny"] if nm.empty?
        return [nil, "názov #{what} je pridlhý (najviac #{MAX_NAME} znakov)"] if nm.length > MAX_NAME
        return [nil, "názov #{what} musí obsahovať písmeno alebo číslicu"] if key_of(nm).empty?

        [nm, nil]
      end
    end
  end
end
