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
# kovania (dlzka rezu) aj buduci vizual (PR 2) citaju VYHRADNE tento registry.
# Registry je rozsiritelny — dalsi profil = novy zaznam, ziadna zmena logiky.
#
# PR 1 (engine) drzi len `reduction` + `name`. Geometricky obrys (outline,
# depth, height) pribudne v PR 2 (vizual) — engine ho nepotrebuje.
#
# Hodnota 'none' NIE JE v registry: je to explicitna neutralna volba
# ("bez profilu") a plati ako default vsade, kde config kluc chyba
# (starsi korpus bez kluca 'profile' = ziadna migracia).
module Noxun
  module Engine
    module FrontProfiles
      NONE = 'none'

      # id => { reduction: skratenie cela v mm, name: slovensky nazov }
      REGISTRY = {
        'ukw7' => { reduction: 36.0, name: 'Profil UKW-7' }
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
