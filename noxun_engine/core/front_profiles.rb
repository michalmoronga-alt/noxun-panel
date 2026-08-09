# frozen_string_literal: true
# Noxun Engine — D-90: uchytkove PROFILY na hrane cela. CISTO Ruby (ziadne
# SketchUp API) — headless testovatelne.
#
# ============================ CO TO JE ============================
# Uchytkovy profil (UKW-7) = hlinikovy profil nalepeny na HORNU hranu cela.
# Celo sa kvoli nemu SKRACUJE o konstantu profilu (`reduction`); riadok cela
# v rade si drzi povodnu vysku — profil je jeho sucastou (fronts.rb §3).
#
# JEDINY ZDROJ PRAVDY konstant profilu. Fronts (matematika panelu), pravidla
# kovania (dlzka rezu), vizual v modeli (CabinetBuilder) aj UI/nahlad panela
# citaju VYHRADNE tento registry. Registry je rozsiritelny — dalsi profil =
# novy zaznam, ziadna zmena logiky.
#
# ROZSIRITELNOST (Michal 9.8.): neskor pribudnu dalsie profily a VOLBA HRANY
# osadenia (dolna hrana sa pouziva casto, existuju aj bocne). Tvar configu to
# uz unesie — riadok cela drzi JEDEN string kluc 'profile' a vsetko ostatne
# (skratenie, nazov, buduca hrana) zije TU v registry. Dnesna implementacia
# rata s hornou hranou, ale je to vlastnost KODU fronts, nie ulozenych dat:
# pridanie hrany nebude vyzadovat migraciu configov ani sablon.
#
# Hodnota 'none' NIE JE v registry: je to explicitna neutralna volba
# ("bez profilu") a plati ako default vsade, kde config kluc chyba
# (starsi korpus bez kluca 'profile' = ziadna migracia).
module Noxun
  module Engine
    module FrontProfiles
      NONE = 'none'

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
