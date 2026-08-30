# frozen_string_literal: true
# Noxun Engine - DocKey: STABILNA identita dokumentu pre identity guardy.
#
# PRECO EXISTUJE (davka 1d/R-02b, priznany zvysok R-02/#264): vsetky identity
# guardy (Panel.foreign_document?, zony, tagy, Studio, Rules baseline, okno
# kovania) aj JS zrkadlo (nxModelGuid) stali na Sketchup::Model#guid — lenze
# SketchUp guid MENI pri KAZDOM ulozeni (dokumentovane pri PROJECT_NAMES_KEY
# v production_core.rb a v AUDIT_REGISTER R-04). Ctrl+S do ~400 ms po uprave
# pola panela tak vyzeral ako prepnutie dokumentu: debounced edit sa zahodil
# a nxDropDocState zmazal rozpisany stav. Tento modul je JEDINY zdroj hodnoty
# `model_guid` v payloadoch — meno pola na drote ostava (kontrakt R-02 sa
# nemeni), meni sa len hodnota.
#
# KONTRAKT IDENTITY: token zije PRESNE tak dlho ako OBJEKT modelu — File >
# New/Open vyrobi novy objekt (Windows SketchUp stary ZNICI, dokumentovane pri
# SESSION_KEY_BRIDGE; macOS ma pre kazdy dokument vlastny), takze novy dokument
# = novy token. Ulozenie, PRVE ulozenie aj Save As identitu NEMENIA — je to
# stale ten isty rozrobeny dokument a rozpisana praca ho musi prezit.
# (Codex audit R-02b, BLOCKER 3: rotacia tokenu pocas zivota okna nema
# spolahlivu resync cestu ku klientom — napr. sekcia Materialy drzi identitu
# az do plneho payloadu, takze by sa po rotacii odmietala donekonecna.
# Kopia .skp suboru nebezpeci nie je: jej otvorenie vytvori novy objekt.)
#
# NIKDY sa NEZAPISUJE do modelu ani .skp (zamietnuta alternativa "token v
# NOXUN dictionary"): zapis pri otvoreni panela by zaspinil cisty dokument
# (dirty flag + undo krok + zakaz zapisov z push ciest, lekcia D-103) a token
# v subore by prezil kopiu zakazky — dve kopie by niesli TU ISTU identitu
# a guard by ich nerozoznal. Runtime token zije len v pamati procesu, co
# nevadi: panel po starte SketchUpu aj tak zacina cerstvym NX.init.
#
# Registry drzi SILNU referenciu na model (presny vzor SESSION_KEY_BRIDGE,
# production_core.rb): `equal?` odzbrojuje recyklaciu object_id po GC. Ziadny
# strop na ZIVE dokumenty (Codex audit R-02b, BLOCKER 2: vytlaceny zivy
# dokument by po navrate dostal novy token a nxSetModelGuid by zahodil drafty)
# — uprace sa VYHRADNE preukazatelne zaniknuty zaznam (`valid?` == false),
# a to pri kazdom vzniku noveho tokenu (prirodzeny okamih: novy token vznika
# prave pri otvoreni/vymene dokumentu).
require 'securerandom'

module Noxun
  module Engine
    module DocKey
      TOKEN_PREFIX = 'nxdoc-'

      class << self
        # Stabilny kluc dokumentu. Prazdny retazec = "ziadna identita":
        # PRISNE guardy taky payload odmietnu a `foreign_document?` odmieta
        # aj zapis, ked prazdny kluc vyda SERVER (fail-closed, Codex audit
        # R-02b BLOCKER 1) - preto sa '' vracia pri nil/ne-modelovom objekte
        # aj pri akejkolvek chybe, a NIKDY sa nesmie vyrobit token pre
        # objekt, ktory sa nepodarilo precitat.
        def key(model)
          return '' unless model && model.respond_to?(:path)

          oid = model.object_id
          entry = registry[oid]
          unless entry && entry[:ref].equal?(model)
            prune_dead
            entry = { ref: model, token: fresh_token }
            registry[oid] = entry
          end
          entry[:token]
        rescue StandardError => e
          Engine.log_error(e, 'DocKey.key') if Engine.respond_to?(:log_error)
          ''
        end

        # Test-only: cisty stav medzi testami (registry je process-wide).
        def reset!
          @registry = {}
        end

        private

        def registry
          @registry ||= {}
        end

        # Uprace zaznamy zaniknutych dokumentov. Mazat sa smie LEN istota:
        # chyba/absencia `valid?` znamena "radsej podrzat" - omylom zmazany
        # ZIVY zaznam by dokument po navrate prekrstil (presne pasca, ktorej
        # sa vyhybame); podrzany mrtvy je len par bajtov do konca sedenia.
        def prune_dead
          registry.delete_if { |_oid, entry| dead?(entry[:ref]) }
        end

        def dead?(ref)
          ref.respond_to?(:valid?) && ref.valid? == false
        rescue StandardError
          false
        end

        # Globalne unikatny aj NAPRIEC sedeniami: ProductionCore persistuje
        # `guid:<hodnota>` kluce neulozenych zakaziek do vepo_settings.json
        # (project_names) - deterministicky citac by po restarte kolidoval
        # a nazov cudzieho neulozeneho projektu by sa objavil na dnesnom.
        def fresh_token
          "#{TOKEN_PREFIX}#{SecureRandom.hex(12)}"
        end
      end
    end
  end
end
