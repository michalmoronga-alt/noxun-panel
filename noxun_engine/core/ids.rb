# frozen_string_literal: true
# Noxun Engine — ids. Generator cabinet_id a part_id (standard sekcia 2.3).
module Noxun
  module Engine
    module Ids
      # Nasledujuce volne cabinet_id (CAB-001, CAB-002 ...) podla existujucich
      # korpusov v modeli. Neresetuje sa po zmazani — berie max + 1.
      def self.next_cabinet_id(model)
        max = 0
        each_cabinet(model) do |inst|
          cid = Store.get(inst, 'cabinet_id') || Store.get(inst, 'id')
          if cid.is_a?(String) && cid =~ /CAB-(\d+)/
            n = Regexp.last_match(1).to_i
            max = n if n > max
          end
        end
        format('CAB-%03d', max + 1)
      end

      # Prejde vsetky korpusove instancie (kind == 'cabinet') v modeli.
      def self.each_cabinet(model)
        model.definitions.each do |dfn|
          next if dfn.image? || dfn.group?
          dfn.instances.each do |inst|
            yield inst if Store.kind(inst) == 'cabinet'
          end
        end
      end

      # part_id = <cabinet_id>-<ROLE_SUFFIX>, napr. CAB-001-SIDE-L, CAB-001-SHELF-2.
      def self.part_id(cabinet_id, role_suffix)
        "#{cabinet_id}-#{role_suffix}"
      end
    end
  end
end
