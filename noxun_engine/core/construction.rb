# frozen_string_literal: true
# Noxun Engine — construction planner. cfg (mm Float) -> BuildPlan (zavazny kontrakt).
# CISTO vypoctovy modul: ziadna SketchUp geometria, ziadne .mm. Testovatelny bez modelu.
# Kazdy dielec = { suffix, part_key, role, name, material:, box:[sx,sy,sz], origin:[x,y,z],
#                  prod:{length,width,thickness} } — plny kontrakt viz core/build_plan.rb.
#
# V0.2b: vnutro riesi ZoneTree (strom zon + priecky + police per-zona),
#        cela riesi Fronts (fixed+auto s lockmi). Hrubka chrbta je konfigurovatelna.
#
# Konstrukcne varianty (standard sekcia 4.4 + domenova korekcia Michal 2026-07):
#   dno:    under_sides (default dolna) / between_sides (default horna)
#   vrch:   full / two_rails / none
#   chrbat: overlay / inset / groove   (hrubka = cfg[:back_thickness], napr. 3 HDF / 18 pevny)
#   sokel:  none (nohy) / front (predny zapusteny panel)
module Noxun
  module Engine
    module Construction
      BACK_THICKNESS_DEFAULT = 3.0    # default hrubka chrbta (HDF), ak cfg neuvedie
      GROOVE_OFFSET          = 10.0   # odsadenie chrbta v drazke od zadnej hrany

      module_function

      # Hlavny vstup: cfg (symbolove kluce, mm Float) + cabinet_id (pre ID zon) -> plan.
      # Vystup MUSI prejst BuildPlan.validate! — chybny plan nikdy neopusti planovac.
      # hardware_rules: normalizovane pole pravidiel kovania. Builder posiela PROJEKTOVY
      # snapshot (HardwareRules.ensure_project_rules!); nil = globalna kniznica (headless
      # testy a pomocne volania bez modelu — migracia identity, panel resolvery).
      def build_plan(cfg, cabinet_id = 'CAB-000', hardware_rules: nil)
        w = cfg[:width]; h = cfg[:height]; t = cfg[:thickness]

        interior = interior_dims(cfg)
        validate!(cfg, interior)
        warnings = []

        parts = []
        parts.concat(side_parts(cfg))
        parts << bottom_part(cfg)
        parts.concat(top_parts(cfg, warnings))
        bk = back_part(cfg, interior)
        parts << bk if bk
        parts.concat(plinth_parts(cfg))

        # Vnutro = strom zon nad vnutornym boxom (3D). Priecky + police su dielce korpusu.
        zbox = { x0: t, x1: w - t, y0: 0.0, y1: interior[:back_front_y],
                 z0: interior[:z_lo], z1: interior[:z_hi] }
        zres = ZoneTree.compute(cfg[:zone_tree], zbox, t, cabinet_id)
        parts.concat(zres[:dividers])
        parts.concat(zres[:shelves])
        warnings.concat(zres[:warnings] || [])

        # Cela pred korpusom (fixed + auto s lockmi).
        fr = Fronts.layout(cfg[:fronts], w, h, cfg[:floor_height], t)
        parts.concat(fr[:parts])

        # Kontrakt: parts = realne postavitelne dielce. Degenerovane (rozmer <= MIN_DIM)
        # sa vyradia UZ TU s warningom — kusovnik/VEPO nikdy neuvidia dielec,
        # ktory builder nepostavi (predtym ich ticho preskakoval az positive_box?).
        # Prah MUSI byt zhodny s builderom (BuildPlan::MIN_DIM) — inak vznikne pasmo,
        # kde plan dielec deklaruje a builder ho preskoci.
        parts, degenerate = parts.partition { |pd| pd[:box].all? { |v| v.to_f > BuildPlan::MIN_DIM } }
        degenerate.each do |pd|
          warnings << BuildPlan.warning('part_skipped_degenerate',
                                        "Dielec #{pd[:name]} (#{pd[:suffix]}) ma nekladny rozmer — preskoceny.",
                                        part_key: pd[:part_key].to_s,
                                        data: { 'box' => pd[:box].map(&:to_f) })
        end

        # Kovanie z pravidiel — az PO vyradeni degenerovanych dielcov (na dielec,
        # ktory v modeli nestoji, nesmie vzniknut polozka). Kontext string-keyed.
        hw_ctx = {
          'width' => w, 'height' => h, 'depth' => cfg[:depth],
          'floor_height' => cfg[:floor_height],
          'available_width' => (w - 2 * t),
          'available_height' => interior[:avail_h],
          'available_depth' => interior[:back_front_y],
          'support' => support_type(cfg)
        }
        hw = HardwareRules.evaluate(cfg, parts, hw_ctx, rules: hardware_rules || HardwareRules.load)
        warnings.concat(hw[:warnings])

        plan = {
          schema: BuildPlan::SCHEMA,
          parts: parts,
          hardware: hw[:items],
          warnings: warnings,
          zones: zres[:zones],
          zone_tree: ZoneTree.sanitize(cfg[:zone_tree]),
          front_items: fr[:items],
          available: {
            width:  (w - 2 * t),
            height: interior[:avail_h],
            depth:  interior[:back_front_y]
          },
          wings: fr[:wings],
          interior: interior
        }
        BuildPlan.validate!(plan)
      end

      # Typ podopretia korpusu (JEDEN zdroj pravdy — builder support_descriptor aj
      # pravidla kovania citaju tuto funkciu): horna/na zemi = none, predny sokel =
      # plinth (nohy pod nim aj tak su — pravidlo noh berie legs AJ plinth), inak legs.
      def support_type(cfg)
        return 'none' if cfg[:type] == 'upper' || cfg[:floor_height].to_f <= 0
        cfg[:plinth_mode] == 'front' ? 'plinth' : 'legs'
      end

      # Vnutorne rozmery (svetle) + poloha celnej hrany chrbta. Hrubka chrbta z configu.
      def interior_dims(cfg)
        h = cfg[:height]; d = cfg[:depth]
        t = cfg[:thickness]; s = cfg[:floor_height]
        bt = back_thickness(cfg)
        z_lo = s + t
        z_hi = cfg[:top_mode] == 'none' ? h : h - t
        back_front_y =
          case cfg[:back_mode]
          when 'inset'  then d - bt
          when 'groove' then d - GROOVE_OFFSET - bt
          else d # overlay — chrbat je za korpusom, vnutro po zadnu stenu
          end
        { z_lo: z_lo, z_hi: z_hi, avail_h: (z_hi - z_lo), back_front_y: back_front_y, back_thickness: bt }
      end

      def back_thickness(cfg)
        v = cfg[:back_thickness].to_f
        v.positive? ? v : BACK_THICKNESS_DEFAULT
      end

      # Boky — plna hlbka. Z-start podla variantu dna.
      def side_parts(cfg)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; s = cfg[:floor_height]; h = cfg[:height]
        z0 = cfg[:bottom_mode] == 'under_sides' ? (s + t) : 0.0
        sh = h - z0
        [
          { suffix: 'SIDE-L', part_key: PartKeys.cabinet('side', 'left'),
            role: 'side_left', name: 'Bok lavy', material: :korpus,
            box: [t, d, sh], origin: [0, 0, z0], prod: { length: sh, width: d, thickness: t } },
          { suffix: 'SIDE-R', part_key: PartKeys.cabinet('side', 'right'),
            role: 'side_right', name: 'Bok pravy', material: :korpus,
            box: [t, d, sh], origin: [w - t, 0, z0], prod: { length: sh, width: d, thickness: t } }
        ]
      end

      # Dno — vzdy na urovni Z = floor_height (priestor pod nim = nohy / sokel).
      def bottom_part(cfg)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; s = cfg[:floor_height]
        if cfg[:bottom_mode] == 'under_sides'
          { suffix: 'BOTTOM', part_key: PartKeys.cabinet('bottom'), role: 'bottom', name: 'Dno', material: :korpus,
            box: [w, d, t], origin: [0, 0, s], prod: { length: w, width: d, thickness: t } }
        else
          { suffix: 'BOTTOM', part_key: PartKeys.cabinet('bottom'), role: 'bottom', name: 'Dno', material: :korpus,
            box: [w - 2 * t, d, t], origin: [t, 0, s], prod: { length: w - 2 * t, width: d, thickness: t } }
        end
      end

      # Vrch — full / two_rails / none. warnings: volitelny kolektor (BuildPlan kontrakt).
      def top_parts(cfg, warnings = nil)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; h = cfg[:height]
        case cfg[:top_mode]
        when 'none'
          []
        when 'two_rails'
          rail_parts(cfg, warnings)
        else # full
          [{ suffix: 'TOP', part_key: PartKeys.cabinet('top'), role: 'top', name: 'Vrch', material: :korpus,
             box: [w - 2 * t, d, t], origin: [t, 0, h - t], prod: { length: w - 2 * t, width: d, thickness: t } }]
        end
      end

      # Dve horne vystuhy (rail_front / rail_back). flat = naplocho, upright = na hranu.
      # Orezanie hlbky/vysky vystuhy uz nie je tiche — hlasi sa do warnings (ak je kolektor).
      def rail_parts(cfg, warnings = nil)
        w = cfg[:width]; d = cfg[:depth]; t = cfg[:thickness]; h = cfg[:height]; s = cfg[:floor_height]
        off = cfg[:rails_top_offset].to_f
        z_top = h - off
        if cfg[:rails_orientation] == 'upright'
          rdp = [cfg[:rail_depth], (h - s - t - 10.0)].min
          rdp = 20.0 if rdp < 20.0
          rail_clamp_warning(warnings, cfg[:rail_depth], rdp, 'vyska')
          z0 = z_top - rdp
          prod = { length: w - 2 * t, width: rdp, thickness: t }
          [
            { suffix: 'TOP-RAIL-F', part_key: PartKeys.cabinet('rail', 'front'),
              role: 'rail_front', name: 'Vystuha predna', material: :korpus,
              box: [w - 2 * t, t, rdp], origin: [t, 0, z0], prod: prod },
            { suffix: 'TOP-RAIL-B', part_key: PartKeys.cabinet('rail', 'back'),
              role: 'rail_back', name: 'Vystuha zadna', material: :korpus,
              box: [w - 2 * t, t, rdp], origin: [t, d - t, z0], prod: prod }
          ]
        else # flat
          rd = [cfg[:rail_depth], (d / 2.0 - 10.0)].min
          rd = 20.0 if rd < 20.0
          rail_clamp_warning(warnings, cfg[:rail_depth], rd, 'hlbka')
          z0 = z_top - t
          prod = { length: w - 2 * t, width: rd, thickness: t }
          [
            { suffix: 'TOP-RAIL-F', part_key: PartKeys.cabinet('rail', 'front'),
              role: 'rail_front', name: 'Vystuha predna', material: :korpus,
              box: [w - 2 * t, rd, t], origin: [t, 0, z0], prod: prod },
            { suffix: 'TOP-RAIL-B', part_key: PartKeys.cabinet('rail', 'back'),
              role: 'rail_back', name: 'Vystuha zadna', material: :korpus,
              box: [w - 2 * t, rd, t], origin: [t, d - rd, z0], prod: prod }
          ]
        end
      end

      # Chrbat — overlay / inset / groove; hrubka z configu (interior[:back_thickness]).
      def back_part(cfg, interior)
        w = cfg[:width]; d = cfg[:depth]; h = cfg[:height]; t = cfg[:thickness]; s = cfg[:floor_height]
        bt = interior[:back_thickness]
        case cfg[:back_mode]
        when 'inset'
          z0 = interior[:z_lo]; bh = interior[:z_hi] - z0
          { suffix: 'BACK', part_key: PartKeys.cabinet('back'), role: 'back', name: 'Chrbat', material: :korpus,
            box: [w - 2 * t, bt, bh], origin: [t, d - bt, z0], prod: { length: w - 2 * t, width: bh, thickness: bt } }
        when 'groove'
          z0 = interior[:z_lo]; bh = interior[:z_hi] - z0
          y0 = d - GROOVE_OFFSET - bt
          { suffix: 'BACK', part_key: PartKeys.cabinet('back'), role: 'back', name: 'Chrbat', material: :korpus,
            box: [w - 2 * t, bt, bh], origin: [t, y0, z0], prod: { length: w - 2 * t, width: bh, thickness: bt } }
        else # overlay
          { suffix: 'BACK', part_key: PartKeys.cabinet('back'), role: 'back', name: 'Chrbat', material: :korpus,
            box: [w, bt, h - s], origin: [0, d, s], prod: { length: w, width: h - s, thickness: bt } }
        end
      end

      # Sokel — len variant 'front' (predny zapusteny panel).
      def plinth_parts(cfg)
        return [] unless cfg[:plinth_mode] == 'front'
        s = cfg[:floor_height]
        return [] if s <= 0
        w = cfg[:width]; t = cfg[:thickness]; recess = cfg[:plinth_recess]
        [{ suffix: 'PLINTH', part_key: PartKeys.cabinet('plinth', 'front'),
           role: 'plinth', name: 'Sokel predny', material: :korpus,
           box: [w - 2 * t, t, s], origin: [t, recess, 0], prod: { length: w - 2 * t, width: s, thickness: t } }]
      end

      # Prida warning o orezani rozmeru vystuhy (ziadany != pouzity).
      def rail_clamp_warning(warnings, wanted, used, label)
        return if warnings.nil? || (wanted.to_f - used.to_f).abs < 0.01
        warnings << BuildPlan.warning('rail_depth_clamped',
                                      "Vystuha: #{label} orezana z #{wanted.to_f.round(1)} na #{used.to_f.round(1)} mm (limit korpusu).",
                                      data: { 'wanted' => wanted.to_f, 'used' => used.to_f })
      end

      def validate!(cfg, interior)
        w = cfg[:width]; h = cfg[:height]; t = cfg[:thickness]; s = cfg[:floor_height]
        raise 'Sirka je prilis mala vzhladom na hrubku materialu.' if w <= 2 * t + 10
        raise 'Hlbka je prilis mala.' if interior[:back_front_y] <= 10
        raise 'Podstavec/sokel nesmie byt vyssi nez korpus.' if s >= h
        raise 'Vnutorna vyska je nulova alebo zaporna (skontroluj vysku, podstavec a hrubky).' if interior[:avail_h] <= 10
      end
    end
  end
end
