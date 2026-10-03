# frozen_string_literal: true
# Nezavisla kopia predzmenovej retaze z main 2640f47b, core/hardware_sets.rb.
# SHA256 povodneho def (vratane odsadenia): ad8ebb4f2cfbfcdb8ac97371c2547e59550e84bbb5790e7156c91014427ebd67.
# Nesmie volat novy resolve_mapping_source ani item_mapping_source.
require_relative 'cases'
module NxH18OldResolver
  module_function
  def class_key_for(*args) = NxH18::HS.class_key_for(*args)
  def door_item?(*args) = NxH18::HS.door_item?(*args)
  def present_mapping_value?(*args) = NxH18::HS.present_mapping_value?(*args)
  def resolve_mapping_value(generic_type, it, cabinet_overrides, mapping)
    # KOV-C2a/KOV-D1a: klasifikovana polozka ma VLASTNU, TROJUROVNOVU
    # precedenciu — OWNER triedny override skrinky -> triedny override
    # skrinky -> projektovy snapshot. Nizsia uroven sa berie LEN vtedy, ked
    # kluc na vyssej NEEXISTUJE (pritomna, ale nepouzitelna hodnota konci
    # ako `unmapped` s dovodom — nikdy tichy fallback). Genericky `slide`
    # ani `slide@owner` pre nu NEEXISTUJU: H70 set k zasuvke H176 by bol
    # zly kit, a mlcky.
    ck = class_key_for(it, generic_type)
    # === KOV-F1: PRECEDENCIA ZAVESU (PATSTUPNOVA) ========================
    #
    #   override VLASTNIKA (`hinge@front:F1/wing:left`)
    #   > TRIEDNY override skrinky (`class:hinge|tipon`)
    #   > GENERICKY override skrinky (`hinge`)
    #   > TRIEDNY kluc projektu
    #   > LEGACY `hinge` projektu
    #
    # Dva rozdiely oproti zasuvke a oba su vecne:
    #   * vlastny set NA SKRINKE (genericky `hinge`) NIKDY ticho nespadne
    #     na projektovy default (Codex #327 kolo 2) — preto stoji NAD
    #     triednym klucom projektu;
    #   * na konci retaze je LEGACY `hinge`. Bez neho by KAZDA existujuca
    #     zakazka po prestavbe stratila zavesy (polozky su odteraz
    #     klasifikovane, ale projektovy snapshot triedny kluc este nema).
    #     „Vedome bez setu" sa preto zapisuje SENTINELOM, nie zmazanim.
    if ck && door_item?(it)
      ov = cabinet_overrides[it['owner_id'].to_s]
      if ov.is_a?(Hash)
        opk = it['owner_part_key'].to_s
        unless opk.empty?
          v = ov["#{generic_type}@#{opk}"]
          return v if present_mapping_value?(v)
        end
        v = ov[ck]
        return v if present_mapping_value?(v)

        v = ov[generic_type]
        return v if present_mapping_value?(v)
      end
      v = mapping[ck]
      return v if present_mapping_value?(v)

      v = mapping[generic_type]
      return present_mapping_value?(v) ? v : nil
    end
    if ck
      ov = cabinet_overrides[it['owner_id'].to_s]
      if ov.is_a?(Hash)
        opk = it['owner_part_key'].to_s
        unless opk.empty?
          v = ov["#{ck}@#{opk}"]
          return v if present_mapping_value?(v)
        end
        v = ov[ck]
        return v if present_mapping_value?(v)
      end
      v = mapping[ck]
      return present_mapping_value?(v) ? v : nil
    end

    ov = cabinet_overrides[it['owner_id'].to_s]
    if ov.is_a?(Hash)
      opk = it['owner_part_key'].to_s
      unless opk.empty?
        v = ov["#{generic_type}@#{opk}"]
        return v if present_mapping_value?(v)
      end
      v = ov[generic_type]
      return v if present_mapping_value?(v)
    end
    v = mapping[generic_type]
    present_mapping_value?(v) ? v : nil
  end
end
