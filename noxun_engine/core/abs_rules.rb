# frozen_string_literal: true
# Noxun Engine — ABS pravidla + mapovanie hran (standard sekcia 7.5). Perzistencia JSON
# v %APPDATA%\NOXUN\Engine\abs_rules.json + .bak (pattern z templates.rb / materials.rb).
#
# ================== KONVENCIA HRAN L1/L2/W1/W2 (znamy pain point) ==================
# Kazdy plosny (sheet) dielec nesie 4 hrany:
#   L1/L2 = dvojica POZDLZNYCH hran (bezia v smere prod[:length]; ich dlzka = length)
#   W1/W2 = dvojica PRIECNYCH  hran (bezia v smere prod[:width];  ich dlzka = width)
# Hrany su per STRANA a su NEZAVISLE od rotacie skrinky v modeli (standard 3.3, 7.5).
#
# Preklad L/W -> predna/zadna/lava/prava/horna/dolna ZAVISI od ROLY (orientacie dielca v korpuse).
# Odvodene z Construction (box + prod) — jeden zdroj pravdy je EDGE_LABELS nizsie:
#
#   side_left/right, divider_v : zvisla doska (length=vyska Z, width=hlbka Y)
#       L1=Predna(Y=0)  L2=Zadna(Y=d)   W1=Dolna(Z=0)  W2=Horna(Z=max)
#   bottom/top/shelf, divider_h: vodorovna doska (length=sirka X, width=hlbka Y)
#       L1=Predna(Y=0)  L2=Zadna(Y=d)   W1=Lava(X=0)   W2=Prava(X=max)
#   front_door/drawer_front    : celo pred korpusom (length=vyska Z, width=sirka X)
#       L1=Lava(X=0)    L2=Prava(X=max) W1=Dolna(Z=0)  W2=Horna(Z=max)
#   back/plinth/rail           : ABS sa neaplikuje (pravidlo prazdne) — labely best-effort
#
# DOSLEDOK: pravidlo "predna hrana" = L1 pre boky/police/dna/priecky (viditelna celna hrana).
# Pre celo su vsetky 4 hrany rovnocenne (hranovanie dookola), preto pravidlo plni L1+L2+W1+W2.
# ==================================================================================
require 'json'
require 'fileutils'

module Noxun
  module Engine
    module AbsRules
      STD  = 1
      # Verzia seed sady (vzor hardware_rules): subor vzniknuty pod starsim SEED_VERSION
      # dostane pri loade NOVE default roly (seed-merge) — bez toho by sa nova rola
      # (free_panel, V0.4.7) na existujucich instalaciach nikdy neobjavila
      # (ensure_seeded zapisuje len ked subor chyba). Uz ulozene roly sa NEPREPISUJU.
      SEED_VERSION = 1
      FILE = 'abs_rules.json'

      EDGE_ORDER = %w[L1 L2 W1 W2].freeze

      # Mapovanie hrana -> slovensky label per rola (UI karta dielca zobrazuje tieto nazvy).
      # Poradie v poli editora (1=predna/2=zadna/3=lava/4=prava alebo horna/dolna) riesi UI z toho.
      EDGE_LABELS = {
        'side_left'    => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Dolná', 'W2' => 'Horná' },
        'side_right'   => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Dolná', 'W2' => 'Horná' },
        'divider_v'    => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Dolná', 'W2' => 'Horná' },
        'bottom'       => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'top'          => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'shelf'        => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'divider_h'    => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'front_door'   => { 'L1' => 'Ľavá',   'L2' => 'Pravá',  'W1' => 'Dolná', 'W2' => 'Horná' },
        'drawer_front' => { 'L1' => 'Ľavá',   'L2' => 'Pravá',  'W1' => 'Dolná', 'W2' => 'Horná' },
        'back'         => { 'L1' => 'Dolná',  'L2' => 'Horná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'plinth'       => { 'L1' => 'Dolná',  'L2' => 'Horná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'rail_front'   => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        'rail_back'    => { 'L1' => 'Predná', 'L2' => 'Zadná',  'W1' => 'Ľavá',  'W2' => 'Pravá' },
        # Samostatna doska (V0.4.7): nema prirodzene predna/zadna — neutralne labely,
        # orientaciu ukazuje 2D karta (edge_sides -> lying mapa).
        'free_panel'   => { 'L1' => 'Pozdĺžna 1', 'L2' => 'Pozdĺžna 2', 'W1' => 'Priečna 1', 'W2' => 'Priečna 2' }
      }.freeze
      EDGE_LABELS_DEFAULT = { 'L1' => 'Hrana 1', 'L2' => 'Hrana 2', 'W1' => 'Hrana 3', 'W2' => 'Hrana 4' }.freeze

      # Mapovanie hrana -> STRANA v 2D karte dielca (top/bottom/left/right). JEDEN ZDROJ PRAVDY pre
      # SVG kreslenie, labely aj klik-targety (UI si ho vytiahne cez edge_sides, neduplikuje v JS).
      # Orientacia je odvodena z toho, kadial bezi dlzka (prod[:length]) v ramci roly:
      #   lezace dielce (police/boky/dna/priecky/chrbat/vystuhy): dlzka VODOROVNE ->
      #       L1/L2 (pozdlzne) su vodorovne hrany (dole/hore), W1/W2 (priecne) zvisle (vlavo/vpravo).
      #   cela (front_door/drawer_front): dlzka = vyska cela ZVISLE ->
      #       L1/L2 (pozdlzne) su zvisle strany (lava/prava), W1/W2 (priecne) vodorovne (dole/hore).
      # Priradenie strany SEDI s EDGE_LABELS (napr. celo L1='Ľavá' -> 'left', W2='Horná' -> 'top').
      EDGE_SIDES_LYING = { 'L1' => 'bottom', 'L2' => 'top', 'W1' => 'left', 'W2' => 'right' }.freeze
      EDGE_SIDES_FRONT = { 'L1' => 'left', 'L2' => 'right', 'W1' => 'bottom', 'W2' => 'top' }.freeze

      # Pravidlove defaulty ABS podla roly (hodnota = HRUBKA ABS v mm; dekor sa dopocita z materialu
      # dielca). Prazdna mapa = ziadne ABS. Standard 7.5 + zadanie V0.3:
      #   celo (front_door/drawer_front) -> vsetky 4 hrany 1.0
      #   polica (shelf)                 -> predna 1.0 (viditelna celna hrana police)
      #   boky (side_left/right)         -> predna 1.0
      #   dno/vrch (bottom/top)          -> predna 1.0
      #   priecky (divider_v/h)          -> predna 1.0
      #   chrbat/sokel/vystuhy           -> nic
      SEED_RULES = {
        'front_door'   => { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 },
        'drawer_front' => { 'L1' => 1.0, 'L2' => 1.0, 'W1' => 1.0, 'W2' => 1.0 },
        'shelf'        => { 'L1' => 1.0 },
        'side_left'    => { 'L1' => 1.0 },
        'side_right'   => { 'L1' => 1.0 },
        'bottom'       => { 'L1' => 1.0 },
        'top'          => { 'L1' => 1.0 },
        'divider_v'    => { 'L1' => 1.0 },
        'divider_h'    => { 'L1' => 1.0 },
        'back'         => {},
        'plinth'       => {},
        'rail_front'   => {},
        'rail_back'    => {},
        'free_panel'   => { 'L1' => 1.0 } # doska: 1 pozdlzna hrana 1.0 (Michal 18.7.2026)
      }.freeze

      module_function

      # --- cesty / perzistencia (pattern templates.rb) -------------------------

      def dir
        base = ENV['APPDATA'] || Dir.tmpdir
        File.join(base, 'NOXUN', 'Engine')
      end

      def path
        File.join(dir, FILE)
      end

      # Nacita pravidla { role => {L1:th,...} }. Pri prvom spusteni seedne SEED_RULES.
      def load
        JsonFileStore.deep_copy(rules)
      end

      # Interny read-only pohlad; pocas generovania dielcov sa JSON neparsuje opakovane.
      # Seed-merge (vzor hardware_rules): pri starsom seed_version sa doplnia CHYBAJUCE
      # default roly; existujuce roly (aj vedome prazdne = "bez ABS") sa nikdy neprepisu.
      def rules
        ensure_seeded
        data = JsonFileStore.read(path, copy: false)
        value = data['rules']
        return deep_copy(SEED_RULES) unless value.is_a?(Hash)

        normalized = normalize_rules(value)
        merged, seed_stale = merge_seed_roles(normalized, data['seed_version'].to_i)
        if merged != value || seed_stale
          if write(merged)
            Engine.log('abs rules: pravidla znormalizovane / doplnene nove default roly') if defined?(Engine)
            return JsonFileStore.read(path, copy: false)['rules']
          end
          return merged
        end
        value
      rescue StandardError => e
        Engine.log_error(e, 'AbsRules.load') if defined?(Engine)
        deep_copy(SEED_RULES)
      end

      # Dopln CHYBAJUCE roly zo SEED_RULES, ak subor vznikol pod starsim SEED_VERSION.
      # Vrati [pravidla, seed_stale] — seed_stale=true si vynuti zapis (bump verzie
      # v subore), aj ked ziadna rola nepribudla, aby sa merge nespustal pri kazdom loade.
      def merge_seed_roles(rules, file_version)
        return [rules, false] if file_version >= SEED_VERSION
        out = deep_copy(rules)
        SEED_RULES.each do |role, edges|
          out[role] = deep_copy(edges) unless out.key?(role)
        end
        [out, true]
      end

      def ensure_seeded
        return if JsonFileStore.available?(path)
        write(deep_copy(SEED_RULES))
      end

      def write(rules)
        JsonFileStore.write(path, { 'std' => STD, 'seed_version' => SEED_VERSION, 'rules' => rules })
      rescue StandardError => e
        Engine.log_error(e, 'AbsRules.write') if defined?(Engine)
        false
      end

      def reload!
        JsonFileStore.reload!(path)
        load
      end

      # --- resolve edges pre dielec -------------------------------------------

      # Hrubky ABS pre rolu (z pravidiel). Vrati mapu {L1:th,...} (len hrany s pravidlom).
      def thicknesses_for(role)
        raw = rules[role.to_s] || {}
        EDGE_ORDER.each_with_object({}) do |code, out|
          value = raw[code]
          next if value.nil?
          th = value.to_f
          next unless defined?(Materials) && Materials.supported_edge_thickness?(th)
          out[code] = th
        end
      end

      # Vyrieši ABS hrany konkretneho sheet dielca:
      #   role  — rola dielca (pravidlo urci KTORE hrany a AKA hrubka ABS)
      #   decor — dekor materialu dielca (urci KTORY dekor ABS pasky)
      # Vrati VZDY kompletnu mapu {L1,L2,W1,W2} kde hodnota = abs_id alebo nil.
      # Ak pravidlo ziada hrubku, pre ktoru dekor nema ABS variant -> nil + info log (standard 7.5).
      def resolve_edges(role, decor)
        th = thicknesses_for(role)
        out = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
        EDGE_ORDER.each do |code|
          want = th[code]
          next if want.nil?
          abs_id = Materials.abs_for_decor(decor, want) if defined?(Materials)
          if abs_id
            out[code] = abs_id
          elsif defined?(Engine)
            Engine.log("abs_rules: rola #{role} ziada ABS #{want} mm dekoru '#{decor}', " \
                       "ale variant neexistuje v katalogu — hrana #{code} bez ABS")
          end
        end
        out
      end

      # Prazdne hrany (non-sheet dielce, alebo ziadne pravidlo) — kompletna nil mapa.
      def empty_edges
        { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
      end

      # --- labely hran (UI) ----------------------------------------------------

      # Mapa hrana -> slovensky label pre rolu (fallback genericke Hrana 1..4).
      def edge_labels(role)
        EDGE_LABELS[role.to_s] || EDGE_LABELS_DEFAULT
      end

      # Mapa hrana -> strana v 2D karte (top/bottom/left/right) pre rolu. Cela maju L na zvislych
      # stranach; ostatne (lezace) L na vodorovnych. UI (SVG) kresli hrany + labely + klik podla tejto mapy.
      def edge_sides(role)
        case role.to_s
        when 'front_door', 'drawer_front' then EDGE_SIDES_FRONT
        else EDGE_SIDES_LYING
        end
      end

      def deep_copy(h)
        JsonFileStore.deep_copy(h)
      end

      def normalize_rules(source)
        source.each_with_object({}) do |(role, edge_map), out|
          out[role.to_s] = {}
          next unless edge_map.is_a?(Hash)

          EDGE_ORDER.each do |code|
            next unless edge_map.key?(code)
            thickness = edge_map[code].to_f
            next unless [1.0, 2.0].include?(thickness)
            out[role.to_s][code] = thickness
          end
        end
      end
    end
  end
end
