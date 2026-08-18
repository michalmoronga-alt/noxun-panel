# frozen_string_literal: true
# Noxun Engine — sklad sablon. Perzistencia JSON v %APPDATA%\NOXUN\Engine\
# + .bak zaloha pri zapise (JsonFileStore). Sablona = IDENTITA (kind, name)
# + konstrukcny config (BEZ id/cabinet_id).
#
# UI-C1a: sablona ma DRUH (`kind`) na urovni ZAZNAMU — 'cabinet' (korpus)
# alebo 'board' (samostatna doska). Identita je DVOJICA (kind, name): doskova
# „Zastena" a korpusova „Zastena" su dve rozne sablony a nikdy sa neprepisu.
# Doskove zaznamy nesu navyse REDUNDANTNE `config['type'] = 'board'` — starsi
# klient (panel pred UI-C1) filtruje ponuku podla `config.type`, takze doskovu
# sablonu neponukne ako korpusovu a serverovy merge ju odmietne.
#
# Marker suboru `std`:
#   1 = pred UI-C1a (len korpusove sablony, bez `kind`)
#   2 = `kind` na zazname + seed 3 doskovych sablon
# Migracia je LAZY (pri prvom `load`): zaznam bez `kind` dostane 'cabinet'
# a prechod std<2 -> 2 doseje doskove sablony — VSETKO JEDNYM atomickym
# zapisom. Seed je MARKEROVY, nie obsahovy: viaze sa na prechod markera, nie
# na pritomnost zaznamov, takze sa uz nikdy neopakuje (zmazanu doskovu
# sablonu plugin nevrati).
#
# FORWARD GUARD (vzor usage_stats.rb): subor s `std` VYSSIM nez STD pochadza
# z novsej verzie pluginu -> store prejde do REZIMU LEN NA CITANIE
# (upsert/delete/touch_used odmietnu zapis a zalogujú). Starsi kod nesmie
# degradovat data, ktorym nerozumie.
#
# POUZITIE (recency) zije v INOM subore — `template_usage.json` (TemplateUsage
# na konci suboru). Preto je subor sablon po vlozeni zo sablony BYTE-NEZMENENY
# (invariant N11) a poradie „naposledy pouzite" je udaj TOHTO pocitaca.
require 'json'
require 'fileutils'
require 'tmpdir'

module Noxun
  module Engine
    module TemplateStore
      STD  = 2
      FILE = 'templates.json'
      KINDS = %w[cabinet board].freeze
      DEFAULT_KIND = 'cabinet'
      MANAGED_KEYS = %w[std templates].freeze

      module_function

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Neznamy druh = 'cabinet' (legacy zaznamy ho nemaju vobec).
      def normalize_kind(kind)
        k = kind.to_s
        KINDS.include?(k) ? k : DEFAULT_KIND
      end

      # Nacita pole { 'name' => ..., 'kind' => ..., 'config' => {...} }.
      # migrate: false = CISTE CITANIE bez akehokolvek zapisu — scany katalogu
      # (Materials.used_material_ids) a dry-run migracie materialov bezia v
      # horucich cestach a NESMU siahnut na produkcny subor sablon.
      def load(migrate: true)
        ensure_current if migrate
        unless JsonFileStore.available?(path)
          return migrate ? normalize_list(build_predefined) : []
        end

        data = JsonFileStore.read(path, copy: false)
        list = data.is_a?(Hash) ? data['templates'] : nil
        normalize_list(list.is_a?(Array) ? list : build_predefined)
      rescue StandardError => e
        Engine.log_error(e, 'TemplateStore.load')
        normalize_list(build_predefined)
      end

      def find(kind, name)
        k = normalize_kind(kind)
        n = name.to_s
        load.find { |t| t['kind'] == k && t['name'] == n }
      end

      # Prida/prepise sablonu podla DVOJICE (kind, name). Vrati true/false.
      def upsert(kind, name, config)
        k = normalize_kind(kind)
        n = name.to_s
        return false if refuse_write('upsert')

        list = load.reject { |t| t['kind'] == k && t['name'] == n }
        list << record(k, n, config)
        write_list(list)
      end

      def delete(kind, name)
        k = normalize_kind(kind)
        n = name.to_s
        return false if refuse_write('delete')

        write_list(load.reject { |t| t['kind'] == k && t['name'] == n })
      end

      # Peciatka pouzitia sablony pre poradie „Naposledy pouzite". Zapisuje do
      # INEHO suboru (template_usage.json) — subor sablon ostava po vlozeni
      # byte-nezmeneny (N11). Vola sa PO uspesnom vlozeni a MIMO model
      # operacie; zlyhanie NIKDY nemeni vysledok vkladania.
      def touch_used(kind, name)
        return false if refuse_write('touch_used')

        TemplateUsage.stamp(normalize_kind(kind), name.to_s)
      end

      # --- perzistencia --------------------------------------------------------

      # Subor z NOVSEJ verzie pluginu — zapis by ho degradoval (vzor usage_stats).
      def read_only?
        return false unless JsonFileStore.available?(path)

        data = JsonFileStore.read(path, copy: false)
        std = data.is_a?(Hash) ? data['std'] : nil
        std.is_a?(Integer) && std > STD
      rescue StandardError => e
        Engine.log_error(e, 'TemplateStore.read_only?')
        false
      end

      def refuse_write(op)
        return false unless read_only?

        Engine.log("TemplateStore: subor sablon ma novsiu schemu nez #{STD} — #{op} preskoceny")
        true
      end

      # Chybajuci subor = cerstva instalacia (korpusovy aj doskovy seed naraz).
      # std < STD = migracia: doplnenie `kind` + doseje doskovych sablon
      # JEDNYM atomickym zapisom (ziadny medzistav na disku).
      def ensure_current
        return write_list(build_predefined + build_predefined_boards) unless JsonFileStore.available?(path)

        data = JsonFileStore.read(path, copy: false)
        std = data.is_a?(Hash) ? data['std'] : nil
        return true if std.is_a?(Integer) && std >= STD

        raw = data.is_a?(Hash) ? data['templates'] : nil
        list = normalize_list(raw.is_a?(Array) ? raw : build_predefined)
        write_list(list + missing_board_seed(list))
      rescue StandardError => e
        Engine.log_error(e, 'TemplateStore.ensure_current')
        false
      end

      # Zapis so zalohou (JsonFileStore: .bak + .tmp + atomicky rename).
      # Nezname top-level kluce existujuceho suboru PREZIJU zapis (forward
      # kompatibilita — rovnaky kontrakt ako UsageStats.merge).
      def write_list(list)
        JsonFileStore.write(path, { 'std' => STD, 'templates' => list }.merge(extras))
      rescue StandardError => e
        Engine.log_error(e, 'TemplateStore.write_list')
        false
      end

      def extras
        return {} unless JsonFileStore.available?(path)

        data = JsonFileStore.read(path, copy: false)
        return {} unless data.is_a?(Hash)

        JsonFileStore.deep_copy(data.reject { |k, _| MANAGED_KEYS.include?(k) })
      rescue StandardError
        {}
      end

      def reload!
        JsonFileStore.reload!(path)
        JsonFileStore.reload!(TemplateUsage.path)
        load
      end

      # --- normalizacia zaznamov ----------------------------------------------

      def normalize_list(list)
        out = []
        Array(list).each do |raw|
          next unless raw.is_a?(Hash)

          name = raw['name'].to_s
          next if name.empty?

          cfg = raw['config'].is_a?(Hash) ? raw['config'] : {}
          out << { 'name' => name, 'kind' => kind_of_record(raw), 'config' => JsonFileStore.deep_copy(cfg) }
        end
        out
      end

      # Druh zaznamu: explicitny `kind` vyhrava. Legacy zaznam (std 1) ho nema —
      # 'board' sa da odvodit uz len z redundantneho `config.type` (rucne
      # upraveny subor); vsetko ostatne je korpus.
      def kind_of_record(raw)
        k = raw['kind'].to_s
        return k if KINDS.include?(k)

        cfg = raw['config']
        cfg.is_a?(Hash) && cfg['type'].to_s == 'board' ? 'board' : DEFAULT_KIND
      end

      # Doskovy zaznam nesie `config['type'] = 'board'` REDUNDANTNE (ochrana
      # starsieho klienta — viz hlavicka suboru).
      def record(kind, name, config)
        cfg = config.is_a?(Hash) ? config : {}
        cfg = cfg.merge('type' => 'board') if kind == 'board'
        { 'name' => name.to_s, 'kind' => kind, 'config' => cfg }
      end

      # Seed sa nikdy nepretlaci cez existujucu DOSKOVU sablonu rovnakeho mena;
      # korpusovej sablony rovnakeho mena sa netyka vobec (ina identita).
      def missing_board_seed(list)
        build_predefined_boards.reject do |seed|
          list.any? { |t| t['kind'] == 'board' && t['name'] == seed['name'] }
        end
      end

      # --- predvolene sablony (konstrukcne presety) ---------------------------

      def build_predefined
        [
          tpl('Dolna klasik', lower_base('top_mode' => 'two_rails', 'rails_orientation' => 'flat')),
          tpl('Drezova',      lower_base('top_mode' => 'two_rails', 'rails_orientation' => 'upright')),
          tpl('Varna doska',  lower_base('top_mode' => 'two_rails', 'rails_orientation' => 'flat',
                                         'rails_top_offset' => 20.0)),
          tpl('Horna klasik', upper_base('back_mode' => 'groove'))
        ]
      end

      # Doskovy seed (UI-C1a). Rozmery su KANONICKE polia dosky podla
      # SYSTEM/STANDARD.md 8.3 — `length`/`width`/`thickness`/`grain_direction`;
      # ziadny material (doplni ho projektovy default pri vlozeni) a ZIADNA
      # orientacia (umiestnenie dosky riesi az UI-C1c).
      def build_predefined_boards
        [
          board_tpl('Diel', 18.0, 800.0, 600.0),
          board_tpl('Pracovná doska', 38.0, 2600.0, 600.0),
          board_tpl('Zástena', 10.0, 2600.0, 580.0)
        ]
      end

      def tpl(name, config)
        record('cabinet', name, config)
      end

      def board_tpl(name, thickness, length, width)
        record('board', name, 'length' => length, 'width' => width,
                              'thickness' => thickness, 'grain_direction' => 'length')
      end

      def lower_base(overrides = {})
        base = {
          'type' => 'lower', 'width' => 600.0, 'height' => 720.0, 'depth' => 510.0, 'thickness' => 18.0,
          'floor_height' => 100.0, 'bottom_mode' => 'under_sides', 'top_mode' => 'full',
          'back_mode' => 'overlay', 'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 40.0,
          'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
          'zone_tree' => ZoneTree.default_tree(0), 'fronts' => Fronts.empty_config
        }
        base.merge(overrides)
      end

      def upper_base(overrides = {})
        base = {
          'type' => 'upper', 'width' => 600.0, 'height' => 720.0, 'depth' => 320.0, 'thickness' => 18.0,
          'floor_height' => 0.0, 'bottom_mode' => 'between_sides', 'top_mode' => 'full',
          'back_mode' => 'groove', 'back_thickness' => 3.0, 'plinth_mode' => 'none', 'plinth_recess' => 40.0,
          'rail_depth' => 100.0, 'rails_orientation' => 'flat', 'rails_top_offset' => 0.0,
          'zone_tree' => ZoneTree.default_tree(0), 'fronts' => Fronts.empty_config
        }
        base.merge(overrides)
      end
    end

    # Poradie „naposledy pouzite" pre vkladaciu kartu (UI-C1a). VLASTNY subor
    # %APPDATA%\NOXUN\Engine\template_usage.json:
    #   { "std": 1, "seq": N, "entries": { "kind:name": poradove_cislo } }
    #
    # Preco MONOTONNE POCITADLO a nie casova peciatka: cislo `seq` rastie o 1
    # pri kazdom pouziti, takze poradie nezavisi od systemovych hodin ani od
    # rozlisenia casu (dve vlozenia v tej istej sekunde maju jasne poradie).
    #
    # Preco VLASTNY subor: subor sablon musi ostat po vlozeni byte-nezmeneny
    # (N11) a pouzitie je udaj TOHTO POCITACA — do buducej zdielanej kniznice
    # sablon (D-48) nepatri.
    #
    # Zapis je read-modify-write pod flockom na sidecar zamku (dve instancie
    # SketchUpu si nesmu prepisat peciatky) a subor s NOVSOU schemou sa
    # NEPREPISUJE (vzor usage_stats.rb).
    module TemplateUsage
      STD = 1
      FILE = 'template_usage.json'
      MANAGED_KEYS = %w[std seq entries].freeze
      MAX_ENTRIES = 300      # strop zaznamov (najstarsie peciatky vypadnu)
      MAX_KEY_LENGTH = 200   # kluc je „kind:nazov" — dlhsie = vadny payload
      MAX_SEQ = 1_000_000_000

      module_function

      def dir
        TemplateStore.dir
      end

      def path
        File.join(dir, FILE)
      end

      def lock_path
        "#{path}.lock"
      end

      def key_for(kind, name)
        n = name.to_s
        return nil if n.empty?

        key = "#{kind}:#{n}"
        key.length > MAX_KEY_LENGTH ? nil : key
      end

      # Opeciatkuje pouzitie sablony. Vrati true/false; NIKDY nevyhadzuje —
      # peciatka nesmie rusit pracu (chyba sa len zaloguje).
      def stamp(kind, name)
        key = key_for(kind, name)
        return false if key.nil?

        ok = false
        with_lock do
          data = read_existing
          std = data['std']
          if std.is_a?(Integer) && std > STD
            Engine.log("TemplateUsage: subor ma novsiu schemu #{std} — peciatka preskocena")
          else
            entries = sanitize_entries(data['entries'])
            seq = next_seq(data['seq'], entries)
            entries[key] = seq
            extras = data.reject { |k, _| MANAGED_KEYS.include?(k) }
            ok = JsonFileStore.write(path, { 'std' => STD, 'seq' => seq,
                                             'entries' => prune(entries) }.merge(extras))
          end
        end
        ok
      rescue StandardError => e
        Engine.log_error(e, 'TemplateUsage.stamp')
        false
      end

      # Mapa { "kind:name" => poradove_cislo } — CISTE CITANIE (nikdy nezapisuje).
      def map
        sanitize_entries(read_existing['entries'])
      rescue StandardError => e
        Engine.log_error(e, 'TemplateUsage.map')
        {}
      end

      def seq_for(kind, name)
        key = key_for(kind, name)
        key ? map[key] : nil
      end

      # --- cista logika (bez IO — testovatelna headless) ----------------------

      # Vzdy o 1 viac nez najvyssie zname cislo (ulozene `seq` AJ najvyssia
      # peciatka) — rucne upraveny alebo skrateny subor nemoze poradie zvratit.
      def next_seq(raw, entries)
        base = raw.is_a?(Integer) && raw.positive? ? raw : 0
        top = entries.values.max || 0
        [[base, top].max + 1, MAX_SEQ].min
      end

      # Kluc = neprazdny String rozumnej dlzky, hodnota = kladne cele cislo.
      # Vsetko ostatne sa TICHO zahodi (vadny payload nesmie zhodit peciatku).
      def sanitize_entries(raw)
        return {} unless raw.is_a?(Hash)

        out = {}
        raw.each do |k, v|
          key = k.to_s
          next if key.empty? || key.length > MAX_KEY_LENGTH

          n = to_seq(v)
          next if n.nil? || n <= 0

          out[key] = [n, MAX_SEQ].min
        end
        out
      end

      def to_seq(value)
        case value
        when Integer then value
        when Float then value.finite? ? value.round : nil
        when String then value.match?(/\A\d+\z/) ? value.to_i : nil
        end
      end

      # Strop zaznamov: drzi MAX_ENTRIES najnovsich (najvyssie `seq`).
      def prune(entries)
        return entries if entries.size <= MAX_ENTRIES

        entries.sort_by { |_, v| -v }.first(MAX_ENTRIES).to_h
      end

      # --- IO helpery ---------------------------------------------------------

      # Exkluzivny zamok na SIDECAR subore (drzany handle by na Windows
      # zablokoval atomicky rename JsonFileStore) — vzor UsageStats.with_lock.
      def with_lock
        FileUtils.mkdir_p(dir)
        File.open(lock_path, File::RDWR | File::CREAT) do |f|
          f.flock(File::LOCK_EX)
          begin
            JsonFileStore.invalidate(path)
            yield
          ensure
            f.flock(File::LOCK_UN)
          end
        end
      end

      def read_existing
        return {} unless JsonFileStore.available?(path)

        data = JsonFileStore.read(path)
        data.is_a?(Hash) ? data : {}
      rescue StandardError => e
        Engine.log_error(e, 'TemplateUsage.read_existing')
        {}
      end
    end
  end
end
