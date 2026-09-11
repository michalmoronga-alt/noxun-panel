# frozen_string_literal: true
# Noxun Engine — D-90: uchytkove PROFILY na hrane cela. CISTO Ruby (ziadne
# SketchUp API) — headless testovatelne.
#
# ============================ CO TO JE ============================
# Uchytkovy profil (UKW-7) = hlinikovy profil osadeny na zvolenej hrane cela.
# Celo sa kvoli nemu SKRACUJE o konstantu profilu (`reduction`); riadok cela
# v rade si drzi povodnu vysku — profil je jeho sucastou (fronts.rb §3).
#
# JEDINY ZDROJ PRAVDY konstant profilu. Fronts (matematika panelu), pravidla
# kovania (dlzka rezu), vizual v modeli (CabinetBuilder) aj UI/nahlad panela
# citaju VYHRADNE tento registry. Registry je rozsiritelny — dalsi profil =
# novy zaznam, ziadna zmena logiky.
#
# D-120: profile_edge zije na riadku cela (CONFIG_SCHEMA 13). Fronts vyriesi
# semanticke `free` oproti pantom; tento modul pozna len FYZICKE hrany.
# Stary profil bez anotacie ma hornu hranu. Prítomna neplatna hrana sa nehada.
#
# Hodnota 'none' NIE JE v registry: je to explicitna neutralna volba
# ("bez profilu") a plati ako default vsade, kde config kluc chyba
# (starsi korpus bez kluca 'profile' = ziadna migracia).
module Noxun
  module Engine
    module FrontProfiles
      NONE = 'none'
      EDGES = %w[top bottom left right].freeze

      # D-90 PR 2 — PRIEREZ UKW-7 (83 bodov, mm) presne z Michalovho modelu
      # (extrakcia 9.8.2026, `_dev/UKW7_prierez.json`; `_dev` je gitignore, preto
      # je obrys zakodovany TU ako jediny zdroj pravdy tvaru).
      # Suradnica bodu = [hlbka, vyska] — ZAVAZNA KONVENCIA pre VSETKY profily
      # registry (GH #146 P2 — renderer aj registry MUSIA citat hlbku rovnako):
      #   hlbka  0 .. depth — 0 je PREDNA strana profilu (nos/uchyt), depth je
      #                       CHRBAT (= zadna rovina cela). Renderer mapuje
      #                       [d, v] -> Y = d - depth, cize chrbat lici so
      #                       zadnou rovinou cela a nos konci na Y = -depth.
      #                       (Povodny text tu tvrdil opak a kreslenie podla
      #                       neho vykreslilo UKW-7 zrkadlovo — nalez Michala
      #                       na realnej zakazke 9.8.2026.)
      #   vyska  0 .. 37,419 — 37,419 je VRCH profilu (= horna hrana POVODNEHO
      #                        cela pred skratenim o 36 mm)
      # Body sa NEZAOKRUHLUJU ani neredukuju — tvar „nosa" nad licom cela vznikne
      # len z presnych hodnot. Obrys je UZAVRETY implicitne (posledny bod sa spaja
      # s prvym; zaverecna hrana je zvisla na hlbke 19,181).
      UKW7_OUTLINE = [
        [19.181, 37.419], [0.241, 37.419], [0.0, 36.802], [0.0, 30.887],
        [0.004, 30.838], [0.016, 30.791], [0.036, 30.745], [0.064, 30.701],
        [0.099, 30.661], [0.14, 30.624], [0.187, 30.592], [0.239, 30.565],
        [0.296, 30.544], [0.355, 30.528], [0.416, 30.519], [0.479, 30.516],
        [0.558, 30.519], [0.636, 30.53], [0.711, 30.548], [0.783, 30.572],
        [0.852, 30.603], [0.915, 30.64], [0.971, 30.683], [1.022, 30.73],
        [1.064, 30.782], [1.098, 30.837], [1.124, 30.895], [1.141, 30.955],
        [1.203, 31.262], [1.471, 31.989], [1.853, 32.684], [2.341, 33.338],
        [2.929, 33.941], [3.609, 34.483], [4.369, 34.956], [5.198, 35.354],
        [6.084, 35.669], [7.013, 35.898], [7.971, 36.037], [8.944, 36.083],
        [14.607, 36.083], [15.035, 36.062], [15.456, 35.997], [15.863, 35.89],
        [16.248, 35.743], [16.604, 35.558], [16.927, 35.338], [17.21, 35.088],
        [17.449, 34.812], [17.638, 34.513], [17.776, 34.198], [17.86, 33.872],
        [17.888, 33.54], [17.888, 15.713], [17.732, 14.137], [17.269, 12.598],
        [16.507, 11.132], [15.467, 9.772], [14.171, 8.552], [12.651, 7.499],
        [10.941, 6.638], [9.082, 5.989], [7.117, 5.567], [5.092, 5.383],
        [1.052, 5.383], [0.915, 5.376], [0.78, 5.355], [0.65, 5.321],
        [0.526, 5.273], [0.412, 5.214], [0.308, 5.144], [0.217, 5.063],
        [0.141, 4.975], [0.08, 4.879], [0.036, 4.778], [0.009, 4.673],
        [0.0, 4.567], [0.0, 3.024], [0.241, 0.0], [1.293, 0.0],
        [1.293, 1.419], [18.129, 1.419], [19.181, 1.419]
      ].map(&:freeze).freeze

      # id => {
      #   reduction: skratenie cela v mm, name: slovensky nazov,
      #   short:     kratky label do tesneho radu UI (riadok cela),
      #   outline:   prierez [[hlbka, vyska], ...] v mm (vizual),
      #   depth:     hlbka prierezu v mm, height: vyska prierezu v mm
      # }
      REGISTRY = {
        'ukw7' => { reduction: 36.0, name: 'Profil UKW-7', short: 'UKW-7',
                    outline: UKW7_OUTLINE, depth: 19.181, height: 37.419 }
      }.freeze

      module_function

      # Rozlisuje CHYBAJUCI kluc (legacy top) od pritomneho poskodeneho.
      def edge_of(source)
        return nil unless source.is_a?(Hash)
        raw = if source.key?(:profile_edge)
                source[:profile_edge]
              elsif source.key?('profile_edge')
                source['profile_edge']
              else
                'top'
              end
        EDGES.include?(raw) ? raw : nil
      end

      def vertical?(edge)
        %w[left right].include?(edge)
      end

      # Z celkoveho obrysu vznikne fyzicky panel. Osi dekoru/ABS sa nemenia.
      # Volat az po per-kridlo validacii vo Fronts, pred emission plánu.
      def fit_panel!(pd, edge)
        red = reduction(of(pd))
        return pd unless red.positive?
        raise 'Neplatná hrana úchytkového profilu.' unless EDGES.include?(edge)

        axis = vertical?(edge) ? 0 : 2
        pd[:box][axis] -= red
        pd[:origin][axis] += red if %w[bottom left].include?(edge)
        pd[:prod][:length] = pd[:box][2].round(2)
        pd[:prod][:width] = pd[:box][0].round(2)
        pd[:profile_edge] = edge
        # Povodny top kontrakt a presnost ostavaju nedotknute.
        if edge == 'top'
          pd[:profile_band] = { z: (pd[:origin][2] + pd[:box][2]).round(2), h: red }
        end
        pd
      end

      # Jedina interpretacia fyzickeho panela: celkovy obrys + pasmo + rez.
      # Rozmery sa odvodzuju, NEUKLADAJU sa ako druhy snapshot.
      def panel_geometry(pd)
        return nil unless of(pd) && (edge = edge_of(pd))
        box = pd[:box]; org = pd[:origin]
        return nil unless box.is_a?(Array) && org.is_a?(Array) && box.size == 3 && org.size == 3
        return nil unless (box + org).all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
        return nil unless box.all? { |v| v > 0.0 }

        red = reduction(of(pd))
        x, z, w, h = org[0].to_f, org[2].to_f, box[0].to_f, box[2].to_f
        w += red if vertical?(edge)
        h += red unless vertical?(edge)
        x -= red if edge == 'left'
        z -= red if edge == 'bottom'
        band = case edge
               when 'top' then { x: x, z: z + h - red, w: w, h: red }
               when 'bottom' then { x: x, z: z, w: w, h: red }
               when 'left' then { x: x, z: z, w: red, h: h }
               when 'right' then { x: x + w - red, z: z, w: red, h: h }
               end
        # Legacy top renderer sa kotvil na zaokruhlene profile_band.z.
        old_band = pd[:profile_band]
        if edge == 'top' && old_band.is_a?(Hash)
          band[:z] = old_band[:z].to_f
          h = band[:z] + red - z
        end
        { edge: edge, x: x, z: z, w: w, h: h, band: band,
          length: vertical?(edge) ? box[2].to_f : box[0].to_f }
      end

      # Nakup cita vyrobny rozmer v osi hrany. Neplatna anotacia nic nevyrobi.
      # Bez anotacie je dovolena povodna top sirka aj na legacy deskriptore.
      def cut_length(pd)
        return nil unless of(pd) && (edge = edge_of(pd)) && pd[:prod].is_a?(Hash)
        v = pd[:prod][vertical?(edge) ? :length : :width]
        return nil unless v.is_a?(Numeric) && v.to_f.finite? && v.positive?
        if pd.key?(:box)
          g = panel_geometry(pd)
          return nil unless g && (g[:length].round(2) - v.to_f.round(2)).abs < 0.000001
        end

        v.to_f.round(2)
      end

      # Kanonicka extruzia ide +X, otaca sa okolo Y. Nos zostava v -Y.
      def placement(pd)
        g = panel_geometry(pd)
        geo = geometry(of(pd))
        return nil unless g && geo
        x, z, w, h, gh = g.values_at(:x, :z, :w, :h) + [geo[:height]]
        anchor, angle = case g[:edge]
                        when 'top' then [[x, 0.0, z + h - gh], 0.0]
                        when 'bottom' then [[x + w, 0.0, z + gh], Math::PI]
                        when 'left' then [[x + gh, 0.0, z], -Math::PI / 2.0]
                        when 'right' then [[x + w - gh, 0.0, z + h], Math::PI / 2.0]
                        end
        g.merge(anchor: anchor, angle: angle, geometry: geo)
      end

      # Zna engine tento profil? ('none' NIE — to nie je profil, ale jeho absencia)
      def known?(id)
        REGISTRY.key?(id.to_s)
      end

      # Kanonicka hodnota kluca 'profile': znamy profil alebo 'none'.
      # Neznamy/prazdny/nil vstup (aj config z novsej verzie) = 'none'.
      def normalize(id)
        known?(id) ? id.to_s : NONE
      end

      # Skratenie cela v mm (0.0 pri 'none' / neznamom profile).
      def reduction(id)
        known?(id) ? REGISTRY[id.to_s][:reduction].to_f : 0.0
      end

      # Slovensky nazov pre UI/hlasky (nil pri 'none').
      def name(id)
        known?(id) ? REGISTRY[id.to_s][:name].to_s : nil
      end

      # Geometria prierezu pre vizual: { outline:, depth:, height: } alebo nil
      # ('none' / neznamy profil / zaznam bez obrysu). Volajuci nekontroluje nic
      # dalsie — co je tu, da sa nakreslit.
      def geometry(id)
        rec = known?(id) ? REGISTRY[id.to_s] : nil
        return nil unless rec && rec[:outline].is_a?(Array) && rec[:outline].length >= 3
        { outline: rec[:outline], depth: rec[:depth].to_f, height: rec[:height].to_f }
      end

      # Ponuka pre UI (riadok cela v paneli) — poradie registry, 'none' NIE je
      # sucastou (neutral si drzi UI samo). JEDINY zdroj labelov aj skratenia:
      # panel z toho kresli volbu profilu aj pasmo v 2D nahlade.
      def options
        REGISTRY.map do |id, rec|
          { 'id' => id, 'name' => rec[:name].to_s, 'short' => (rec[:short] || rec[:name]).to_s,
            'reduction' => rec[:reduction].to_f }
        end
      end

      # Ma dielec/polozka zapnuty profil? -> id profilu alebo nil.
      # Prijma deskriptor dielca (symbolovy kluc :profile) aj string-keyed hash.
      def of(source)
        return nil unless source.is_a?(Hash)
        raw = source.key?(:profile) ? source[:profile] : source['profile']
        id = normalize(raw)
        id == NONE ? nil : id
      end
    end
  end
end
