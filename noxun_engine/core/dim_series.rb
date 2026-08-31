# frozen_string_literal: true
# Noxun Engine — UI-B3 (N6): ROZMEROVE RADY.
#
# Bezne hodnoty ponukane pri rozmerovych poliach panela (sipka pri poli ->
# ponuka hodnot). Je to nastavenie POCITACA, nie zakazky — zije v
# %APPDATA%\NOXUN\Engine\dim_series.json a NIKDY v .skp (rovnaky dovod ako
# tema UI-01: Michal a Lucia otvaraju tie iste zakazky, ale kazdy ma vlastne
# zvyklosti). Zapisuje JsonFileStore (atomicky + .bak).
#
# ZELEZNE PRAVIDLO: rad je len PONUKA. Vyber hodnoty ide EXISTUJUCOU zapisovou
# cestou pola (JS zapise hodnotu a vystreli povodnu udalost) — tento modul
# nikdy nesiaha na model ani na config korpusu.
module Noxun
  module Engine
    module DimSeries
      FILE = 'dim_series.json'
      STD = 1 # verzia formatu suboru (buduce migracie)

      # Kluce = rozmery, ktore ponuku maju. 'vyska_cela' pouzije az UI-C3
      # (vyskovy rad ciel N25) — je tu, aby sa subor nemusel migrovat.
      KEYS = %w[sirka vyska hlbka sokel vyska_cela].freeze

      DEFAULTS = {
        'sirka' => [400, 450, 500, 600, 800, 900],
        'vyska' => [720, 820, 900],
        'hlbka' => [320, 510, 560],
        'sokel' => [100, 120, 150],
        'vyska_cela' => [140, 180, 280, 356]
      }.freeze

      # Rozsah je FILTER, nie clamp (Codex audit FIX 4): hodnota mimo rozsahu sa
      # ZAHODI. Orezanie -50 na 1 by do ponuky vlozilo cislo, ktore pouzivatel
      # nikdy nenapisal — a ponuka musi obsahovat len to, co si tam dal.
      # Spodna hranica je 10 mm zamerne: rad ponuka ROZMERY nabytku (najmensi
      # zmysluplny je rad vysok ciel), takze jednociferna hodnota je vzdy
      # preklep — typicky „140,5" napisane s desatinnou ciarkou, ktoru editor
      # berie ako oddelovac.
      MIN_MM = 10
      MAX_MM = 3000 # strop rozmerov panela (LIMITS vo form.js) + rezerva
      MAX_VALUES = 24 # dlhsia ponuka sa uz neda prehliadnut ocami

      module_function

      # Rovnaka zlozka ako ostatne nastavenia pocitaca (tema, prepinace hran).
      def dir
        return Materials.dir if defined?(Materials) && Materials.respond_to?(:dir)

        File.join(ENV['APPDATA'].to_s, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Jeden rad: cisla v rozsahu, cele mm, bez duplicit, vzostupne, orezany
      # poctom. Nie je to pole => nil (volajuci dosadi default).
      # PRAZDNE pole je PLATNY vysledok — pouzivatel smie rad vypnut.
      def normalize_list(raw)
        return nil unless raw.is_a?(Array)

        out = []
        raw.each do |v|
          n = to_mm(v)
          next if n.nil?
          next if n < MIN_MM || n > MAX_MM
          out << n
        end
        out.uniq.sort.first(MAX_VALUES)
      end

      # Cislo z JSON/JS vstupu. Vysledok su VZDY CELE mm (rad je ponuka beznych
      # rozmerov, nie presny vypocet).
      #
      # Codex audit FIX 5: ciarka je v editore ODDELOVAC hodnot, takze sa tu
      # NESMIE brat ako desatinna — inak by sa „140,5" rozpadlo na 140 a 5.
      # Desatinna bodka je tolerovana a zaokruhli sa.
      def to_mm(value)
        return nil if value.is_a?(TrueClass) || value.is_a?(FalseClass) || value.nil?

        n = if value.is_a?(Numeric)
              value.to_f
            else
              s = value.to_s.strip
              return nil unless s =~ /\A-?\d+(\.\d+)?\z/

              s.to_f
            end
        return nil unless n.finite?

        n.round
      end

      # Cely kontrakt pre UI: KAZDY kluc ma pole. Chybajuci alebo poskodeny
      # kluc = DEFAULT (tolerantne citanie, vzor Engine.get_ui_theme).
      def normalize(raw)
        src = raw.is_a?(Hash) ? raw : {}
        KEYS.each_with_object({}) do |key, out|
          list = normalize_list(src[key])
          out[key] = list || DEFAULTS[key].dup
        end
      end

      # Ulozene rady. Chybajuci ani poskodeny subor NIKDY nezhodi panel —
      # vrati sa predvolena sada.
      def get
        raw = JsonFileStore.available?(path) ? JsonFileStore.read(path) : nil
        normalize(raw.is_a?(Hash) ? raw['series'] : nil)
      rescue StandardError => e
        Engine.log_error(e, 'DimSeries.get')
        normalize(nil)
      end

      # Zapis radov. Vstup sa VZDY normalizuje (autorita je tu, nie HTML) a
      # vracia sa presne to, co sa ulozilo — panel tym prekresli ponuky.
      #
      # Codex audit FIX 6: zlyhanie zapisu (disk, prava) vracia NIL — volajuci
      # to MUSI povedat nahlas. Tichy fallback na stare hodnoty by pouzivatelovi
      # ohlasil uspech, ktory sa nestal.
      # R-08: zapis bezi pod tym istym medziprocesovym zamkom ako ostatne
      # katalogy priecinka (`Materials.with_catalog_lock`, sidecar
      # `materials.lock`, vzor 1b-6c). Zamok, ktory sa nepodari vziat, vyhodi
      # IOError — rescue nizsie z neho spravi NIL, takze zlyhanie sa nikdy
      # nevydava za uspech.
      #
      # PRIZNANY ZVYSOK (audit 1d #6): rad je UPLNA NAHRADA — panel posiela
      # cely objekt a subor ziadnu reviziu nema, takze dve otvorene okna sa
      # stale prebijaju „posledny vyhrava". Zamok tu teda zapisy len
      # SERIALIZUJE. Doriesenie vedie register ako R-35 (revizia + konfliktova
      # vetva su UI kontrakt, nie zamok).
      #
      # 1d/R-11: poskodeny primar s platnou `.bak` sa cita zo ZALOHY, takze
      # zapis by rady prepisal STARSIM obsahom. Brana bezi POD ZAMKOM tesne
      # pred zapisom a odmietnutie konci ako kazde ine zlyhanie — `nil`;
      # KONKRETNY dovod si volajuci vezme z `write_block_reason`.
      def set(raw)
        series = normalize(raw)
        stored = with_catalog_lock do
          next false if degraded_write_blocked?

          JsonFileStore.write(path, 'std' => STD, 'series' => series)
        end
        stored ? series : nil
      rescue StandardError => e
        Engine.log_error(e, 'DimSeries.set')
        nil
      end

      # Dovod odmietnutia POSLEDNEHO zapisu (prazdny = nic sa neodmietlo).
      # `set` si drzi navratovy tvar (rady/`nil`) — dvojica `[nil, dovod]` by
      # rozbila vsetkych volajucich a `[false, dovod]` by bola pravdiva.
      def write_block_reason
        @write_block_reason.to_s
      end

      # I/O chyba z `degraded?` sa NEchyta — vyleti do rescue vetvy `set`
      # a skonci ako `nil` (neuspesny zapis), nie ako povolenie zapisovat.
      def degraded_write_blocked?
        prev = @write_block_reason
        @write_block_reason = ''
        return false unless JsonFileStore.degraded?(path)

        @write_block_reason = 'Rozmerové rady sú poškodené — číta sa záloha, zápisy sú vypnuté ' \
                              "(oprav alebo zmaž súbor #{path})"
        # Log LEN pri ZMENE stavu — seed-merge sa o zapis pokusa pri kazdom
        # nacitani, takze bezpodmienecny zapis by zaplavil Ruby konzolu.
        if prev.to_s != @write_block_reason && defined?(Engine)
          Engine.log("dim series: zapis odmietnuty — #{@write_block_reason}")
        end
        true
      end

      def with_catalog_lock(&blk)
        Materials.with_catalog_lock(&blk)
      end
    end
  end
end
