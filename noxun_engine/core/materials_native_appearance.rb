# frozen_string_literal: true
# MR-1B1: nativny kontajner vzhladu. Bez geometrie, UI a zapisov katalogu.
require 'json'

module Noxun
  module Engine
    module NativeAppearance
      DICT = 'NOXUN'
      SCOPE_KEY = 'appearance_scope'
      REVISION_KEY = 'appearance_id'
      class IdentityError < Materials::AppearanceError; end
      class LoadError < Materials::AppearanceError; end
      class OperationError < Materials::AppearanceError; end

      module_function

      # Meno je iba nativny hint. Autorita je jednoznacny scope + UUID na handle.
      def lookup(model, scope, revision)
        scope = valid_scope!(scope)
        valid_revision!(revision)
        matches = model.materials.to_a.select do |material|
          raw_scope = material.get_attribute(DICT, SCOPE_KEY)
          raw_revision = material.get_attribute(DICT, REVISION_KEY)
          next false unless raw_revision == revision || parse_scope(raw_scope) == scope

          own_material!(model, material)
          actual_scope, actual_revision = identity!(material)
          if actual_revision == revision && actual_scope != scope
            raise IdentityError, 'Revízia vzhľadu patrí inej skupine materiálov.'
          end
          actual_scope == scope && actual_revision == revision
        end
        raise IdentityError, 'Viac materiálov v modeli má tú istú revíziu vzhľadu.' if matches.length > 1
        matches.first
      end

      # Overi presnu identitu dodaneho handle; sam nevybera najnovsiu reviziu.
      # Pri rebuild volajuci navyse dokazuje povodny dielec a nezmenene vyrobne ID.
      def preferred(model, scope, material)
        scope = valid_scope!(scope)
        own_material!(model, material)
        actual_scope, revision = identity!(material)
        raise IdentityError, 'Pôvodný vzhľad patrí inej skupine materiálov.' unless actual_scope == scope
        raise IdentityError, 'Pôvodná revízia vzhľadu nie je jednoznačná.' unless lookup(model, scope, revision) == material
        material
      end

      # Mutujuci volajuci vlastni guarded operaciu aj rollback pri IdentityError.
      # Nil = chybajuci/necitately lokalny subor; LoadError = native load zlyhal.
      # IdentityError sa NESMIE spracovat ako tichy navrat ku katalogovej farbe.
      def load(model, scope, descriptor)
        descriptor = native_descriptor!(descriptor)
        scope = valid_scope!(scope)
        found = lookup(model, scope, descriptor['id'])
        return found if found

        path = Materials.appearance_file(descriptor['id'])
        return nil unless File.file?(path) && File.readable?(path)
        load_verified(model, path, scope, descriptor['id'])
      end

      # Doverihodny pracovny archiv, nie cesta z JS. Caller vlastni guarded
      # operaciu a rollback; pracovny cyklus nikdy nesmie reuse stary handle.
      def import_working(model, path, scope:, revision:)
        scope = working_identity!(model, scope, revision)
        unless path.is_a?(String) && File.file?(path) && File.readable?(path)
          raise LoadError, 'Pracovný súbor vzhľadu nie je dostupný.'
        end
        before = model.materials.to_a.dup
        material = load_verified(model, path, scope, revision)
        new_material!(model, material, before)
        material
      end

      # Prvy Pick/Edit nepouziteho RGB dekoru nepotrebuje zdrojovy SKM.
      # Scope/UNI overuje caller v cerstvom katalogu pred pripravnym blokom.
      def create_working(model, scope:, color:, revision:)
        scope = working_identity!(model, scope, revision)
        unless color.is_a?(Array) && color.length == 3 && color.all? { |value| value.is_a?(Integer) && value.between?(0, 255) }
          raise IdentityError, 'Farba musí obsahovať tri celé RGB hodnoty 0–255.'
        end
        rgb = Sketchup::Color.new(*color)
        before = model.materials.to_a.dup
        material = model.materials.add("NOXUN_APPEARANCE_#{revision}_NATIVE")
        new_material!(model, material, before)
        material.color = rgb
        material.set_attribute(DICT, SCOPE_KEY, JSON.generate(scope))
        material.set_attribute(DICT, REVISION_KEY, revision)
        preferred(model, scope, material)
      end

      # Interny exporter pre Materials.publish_appearance. Nikdy v cudzej operacii.
      # Zdroj sa obnovi PRED verifikacnym loadom; oba aborty musia vratit true.
      def export(model, source, staging_path, descriptor, scope, source_descriptor: nil)
        if source.nil? == source_descriptor.nil?
          raise IdentityError, 'Zadaj práve jeden živý alebo knižničný zdroj vzhľadu.'
        end
        descriptor = native_descriptor!(descriptor)
        source_descriptor = native_descriptor!(source_descriptor) unless source_descriptor.nil?
        scope = valid_scope!(scope)
        own_material!(model, source) unless source.nil?
        active_model!(model)
        raise OperationError, 'Prebieha zmena modelu — ulož vzhľad po jej dokončení.' if ScaleWatch.rebuilding?
        raise OperationError, 'Dočasný súbor vzhľadu už existuje.' if File.exist?(staging_path)

        originals = model.materials.to_a.dup
        actual = source
        before = source_state(source) if source
        begin
          aborted_operation(model, 'NOXUN: príprava vzhľadu') do
            actual ||= load(model, scope, source_descriptor)
            raise LoadError, 'Knižničný zdroj vzhľadu nie je dostupný.' unless actual
            own_material!(model, actual)
            before ||= source_state(actual) if originals.include?(actual)
            actual.name = "NOXUN_APPEARANCE_#{descriptor['id']}_NATIVE"
            actual.set_attribute(DICT, SCOPE_KEY, JSON.generate(scope))
            actual.set_attribute(DICT, REVISION_KEY, descriptor['id'])
            raise LoadError, 'Natívny vzhľad sa nepodarilo uložiť.' unless actual.save_as(staging_path) == true
          end
          restored_collection!(model, originals)
          restored_source!(model, actual, before) if before
          aborted_operation(model, 'NOXUN: overenie vzhľadu') do
            # Bez lookup skratky: overujeme prave ulozeny subor, nie lokalnu cache.
            load_verified(model, staging_path, scope, descriptor['id'])
          end
        ensure
          restored_collection!(model, originals)
          restored_source!(model, actual, before) if before
        end
        true
      end

      def active_model!(model)
        raise OperationError, 'Model už nie je aktívny.' unless model && Sketchup.active_model == model
      end

      def working_identity!(model, scope, revision)
        active_model!(model)
        scope = valid_scope!(scope)
        raise IdentityError, 'Pracovná revízia vzhľadu už v modeli existuje.' if lookup(model, scope, revision)
        scope
      end

      def new_material!(model, material, before)
        own_material!(model, material)
        raise IdentityError, 'Pracovný vzhľad opätovne použil pôvodný materiál.' if before.include?(material)
      end

      def restored_collection!(model, before)
        unless model.materials.to_a.tally == before.tally && before.all? { |material| material.valid? && material.model == model }
          raise OperationError, 'Pôvodná kolekcia materiálov sa po overení vzhľadu neobnovila.'
        end
      end

      def valid_scope!(scope)
        valid = scope.is_a?(Array) && scope.length == 2 && scope.all? { |part| part.is_a?(String) } &&
                !scope.first.empty? && scope.all? { |part| Materials.identity_norm(part) == part }
        raise IdentityError, 'Neplatná identita skupiny vzhľadu.' unless valid
        scope
      end

      def valid_revision!(revision)
        raise IdentityError, 'Neplatné ID natívneho vzhľadu.' unless
          revision.is_a?(String) && Materials::APPEARANCE_UUID.match?(revision)
        revision
      end

      def native_descriptor!(descriptor)
        out = Materials.normalize_appearance(descriptor)
        raise IdentityError, 'Vzhľad nie je v natívnom režime.' unless out['mode'] == 'native'
        out
      end

      def parse_scope(value)
        value.is_a?(String) ? JSON.parse(value) : nil
      rescue JSON::ParserError
        nil # Len vyber relevantnych kandidatov. identity! chybny tuple odmietne.
      end

      def identity!(material)
        [valid_scope!(parse_scope(material.get_attribute(DICT, SCOPE_KEY))),
         valid_revision!(material.get_attribute(DICT, REVISION_KEY))]
      end

      def own_material!(model, material)
        raise IdentityError, 'Materiál už nie je platný alebo patrí inému modelu.' unless
          material && material.valid? && material.model == model && model.materials.to_a.include?(material)
        material
      end

      def load_verified(model, path, scope, revision)
        begin
          material = model.materials.load(path)
        rescue StandardError => e
          raise LoadError, "Natívny súbor vzhľadu sa nedá načítať: #{e.message}"
        end
        raise LoadError, 'Natívny súbor nevrátil materiál.' unless material
        own_material!(model, material)
        raise IdentityError, 'Načítaný materiál má inú identitu vzhľadu.' unless identity!(material) == [scope, revision]
        raise IdentityError, 'Načítaná revízia vzhľadu nie je jednoznačná.' unless lookup(model, scope, revision) == material
        material
      end

      def source_state(source)
        [source.name, source.attribute_dictionaries&.map { |dict| [dict.name, dict.to_h] }&.to_h]
      end

      def restored_source!(model, source, before)
        own_material!(model, source)
        raise OperationError, 'Pôvodný materiál sa nepodarilo obnoviť — vzhľad sa neuložil.' unless source_state(source) == before
      end

      def aborted_operation(model, title)
        ScaleWatch.guard do
          started = false
          begin
            raise OperationError, 'Operácia vzhľadu sa nedá otvoriť.' unless model.start_operation(title, true) == true
            started = true
            yield
          ensure
            if started
              begin
                aborted = model.abort_operation
              rescue StandardError => e
                raise OperationError, "Obnova modelu po overení vzhľadu zlyhala: #{e.message}"
              end
              raise OperationError, 'Model nepotvrdil obnovu po overení vzhľadu.' unless aborted == true
            end
          end
        end
      end

      private_class_method :valid_scope!, :valid_revision!, :native_descriptor!, :parse_scope,
                           :identity!, :own_material!, :load_verified, :source_state,
                           :restored_source!, :aborted_operation, :active_model!, :working_identity!,
                           :new_material!, :restored_collection!
    end
  end
end
