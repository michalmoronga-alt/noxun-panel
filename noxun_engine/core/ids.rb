# frozen_string_literal: true
# Noxun Engine — ids. Generator sekvencnych identit (standard sekcia 2.3).
# V0.4.7: generalizovane pre viac druhov entit (cabinet CAB-, board BRD-);
# povodne cabinet metody ostavaju ako wrappery (kontrakt pre existujuci kod/testy).
module Noxun
  module Engine
    module Ids
      # id_keys: ploche NOXUN kluce, z ktorych sa cita identita (v poradi priority).
      # Korpusy historicky nosia identitu v 'cabinet_id' (a 'id' ako fallback);
      # dosky maju len 'id'.
      KIND_ID_KEYS = {
        'cabinet' => %w[cabinet_id id],
        'board'   => %w[id]
      }.freeze

      # Nasledujuce volne sekvencne id (napr. CAB-001, BRD-007) podla ZIVYCH entit
      # daneho kind v modeli — berie max existujucich + 1. POZOR na semantiku:
      # id je unikatne medzi zivymi entitami; po zmazani entity s najvyssim cislom
      # sa cislo moze pouzit znova (plati od V0.1 aj pre korpusy — vedome).
      def self.next_id(model, kind:, prefix:)
        pattern = /\A#{Regexp.escape(prefix)}-(\d+)\z/
        max = 0
        each_of_kind(model, kind) do |inst|
          cid = read_id(inst, kind)
          if cid.is_a?(String) && (m = cid.match(pattern))
            n = m[1].to_i
            max = n if n > max
          end
        end
        format('%s-%03d', prefix, max + 1)
      end

      def self.next_cabinet_id(model)
        next_id(model, kind: 'cabinet', prefix: 'CAB')
      end

      def self.next_board_id(model)
        next_id(model, kind: 'board', prefix: 'BRD')
      end

      # Identita entity podla kind (legacy poradie klucov — korpus cita cabinet_id||id).
      def self.read_id(inst, kind)
        keys = KIND_ID_KEYS[kind.to_s] || %w[id]
        keys.each do |k|
          v = Store.get(inst, k)
          return v unless v.nil?
        end
        nil
      end

      # Prejde vsetky instancie daneho kind v MODELI — GLOBALNE hladanie cez
      # model.definitions (najde aj instancie vnorene v cudzich komponentoch;
      # preskoci definicie group/image). Ci vnorene entity patria do vystupov,
      # rozhodne kusovnik (V0.5) — tu sa nefiltruje.
      def self.each_of_kind(model, kind)
        want = kind.to_s
        model.definitions.each do |dfn|
          next if dfn.image? || dfn.group?
          dfn.instances.each do |inst|
            yield inst if Store.kind(inst) == want
          end
        end
      end

      def self.each_cabinet(model, &block)
        each_of_kind(model, 'cabinet', &block)
      end

      def self.each_board(model, &block)
        each_of_kind(model, 'board', &block)
      end

      # Najde instancie daneho kind zdielajuce rovnaku identitu (kopie). Vrati NOVSIE
      # instancie (vyssi entityID) — tie dostanu nove id; povodna (najnizsi entityID)
      # si identitu podrzi. Standard 2.3/9.3: kopia dostane nove id (korpus aj doska).
      def self.duplicates_of(model, kind)
        seen = {}
        dups = []
        each_of_kind(model, kind) do |inst|
          cid = read_id(inst, kind)
          next unless cid
          prev = seen[cid]
          if prev.nil?
            seen[cid] = inst
          elsif inst.entityID > prev.entityID
            dups << inst
          else
            dups << prev
            seen[cid] = inst
          end
        end
        dups
      end

      # V0.2c fix #6 — povodne API pre korpusy (observer/panel ho volaju).
      def self.duplicate_cabinets(model)
        duplicates_of(model, 'cabinet')
      end

      def self.duplicate_boards(model)
        duplicates_of(model, 'board')
      end

      # part_id = <cabinet_id>-<ROLE_SUFFIX>, napr. CAB-001-SIDE-L, CAB-001-SHELF-2.
      def self.part_id(cabinet_id, role_suffix)
        "#{cabinet_id}-#{role_suffix}"
      end
    end
  end
end
