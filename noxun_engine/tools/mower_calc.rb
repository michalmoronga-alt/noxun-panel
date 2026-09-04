# frozen_string_literal: true
# Noxun Engine — NASTROJE-1: CISTE jadro nastroja Mower (rotacie, Z, kopia).
#
# Ziadne `UI::*`, ziadne `Sketchup::*`, ziadny pristup do modelu — vsetko su
# funkcie nad cislami a retazcami, aby ich vedela overit headless sada.
# Vsetky rozmery su mm Float (standard §1); prevod na palce robi VYHRADNE
# `Units` az v SketchUp vrstve (`tools/mower.rb`).
module Noxun
  module Engine
    module Tools
      module MowerCalc
        # Zrkadlo `CabinetBuilder::NAME_MAX_LEN` — jadro sa nesmie viazat na
        # builder (nacita sa aj samostatne v headless sade), preto vlastna
        # konstanta a guard test, ktory ich drzi v synchro.
        NAME_MAX_LEN = 80
        LETTERS = ('a'..'z').to_a.freeze
        # Po vycerpani pismen pokracuju CISLA — prve je 27 (26 pismen + 1).
        FIRST_NUMBER_SUFFIX = LETTERS.length + 1
        # Poistka proti nekonecnemu hladaniu volnej pripony (poskodene data).
        MAX_SUFFIX_TRIES = 5000

        # Pripona, ktoru vyrobila TATO cesta: jedno male ASCII pismeno alebo
        # cislo od 27 vyssie. Vsetko ostatne je sucast pouzivatelovho nazvu.
        COPY_SUFFIX_RE = /\A(.*\S)[ ](?:([a-z])|([0-9]+))\z/.freeze

        module_function

        # Smer kopie/prisunutia -> znamienko po LOKALNEJ osi X objektu.
        # `:left` = -X, `:right` = +X. Ziadne hadanie osi ani uhla (legacy Mower
        # ho odvodzoval z RotZ a pri parametrickej skrinke je zbytocne).
        def sign(dir)
          dir.to_sym == :left ? -1.0 : 1.0
        end

        # Posun kopie v mm po lokalnej osi X = SIRKA KORPUSU z configu.
        # Sirka korpusu (nie bbox instancie): celo so zapornym `gap_sides`
        # alebo uchytka smie sirku korpusu presahovat, takze susednost sa
        # meria na OBALKACH KORPUSOV (Codex #288).
        def copy_offset_mm(width_mm, dir)
          sign(dir) * width_mm.to_f
        end

        # Posun po svetovej osi Z (Z = 0 aj Z posun na hodnotu).
        def z_delta_mm(current_z_mm, target_z_mm)
          target_z_mm.to_f - current_z_mm.to_f
        end

        # Ktorou cestou ma nastroj ist. Poradie odmietnuti je sucast kontraktu:
        # otvoreny edit kontext sa hlasi PRED typom objektu (nastroj musi
        # odmietnut EST PRED `CabinetBuilder.build`, ktory si edit kontext
        # zatvara sam).
        #   :edit_context — v modeli je otvoreny komponent/skupina
        #   :nested       — objekt nie je na root urovni
        #   :cabinet      — NOXUN korpus (cesta cez sev enginu)
        #   :board        — NOXUN doska (kopia zatial nie, poloha ano)
        #   :legacy       — cudzi objekt (stare DC komponenty)
        def route(kind:, root_context:, top_level:)
          return :edit_context unless root_context
          return :nested unless top_level

          case kind.to_s
          when 'cabinet' then :cabinet
          when 'board' then :board
          else :legacy
          end
        end

        # --- nazov kopie (FIX 10) --------------------------------------------
        # Zaklad nazvu = rucny nazov zdroja BEZ pripony, ktoru vyrobila kopia.
        # Bez tohto by retaz „Skrinka" -> „Skrinka a" -> „Skrinka a a" rastla;
        # takto ide „Skrinka a" -> „Skrinka b".
        # PRIZNANY DOSLEDOK: rucny nazov koniaci na jedno male pismeno alebo na
        # cislo >= 27 sa berie ako pripona a v kopii sa nahradi. Nazov nema
        # ziadny vyrobny dosah (D-100), takze je to lacnejsie nez rastuci chvost.
        def copy_base_name(name)
          s = squeeze(name)
          return s if s.empty?

          m = COPY_SUFFIX_RE.match(s)
          return s if m.nil?
          return m[1] if m[2]
          return m[1] if m[3] && m[3].to_i >= FIRST_NUMBER_SUFFIX

          s
        end

        # Nazov kopie: zaklad + NAJBLIZSIA VOLNA pripona v celom modeli.
        # `taken` = rucne nazvy vsetkych korpusov dokumentu. `nil` na vstupe
        # (skrinka bez rucneho nazvu) vracia `nil` — kopia si necha AUTOMATICKY
        # nazov, ktory sa dopocitava z rozmerov.
        def copy_name(source_name, taken = [])
          base = copy_base_name(source_name)
          return nil if base.empty?

          used = Array(taken).compact.map { |n| squeeze(n) }.reject(&:empty?)
          i = 0
          while i < MAX_SUFFIX_TRIES
            candidate = with_suffix(base, suffix_for(i))
            return candidate unless used.include?(candidate)

            i += 1
          end
          with_suffix(base, suffix_for(i))
        end

        # i = 0..25 -> 'a'..'z'; i = 26 -> '27', 27 -> '28' …
        def suffix_for(index)
          i = index.to_i
          return LETTERS[i] if i < LETTERS.length

          (i + 1).to_s
        end

        # Zaklad sa oreze tak, aby pripona VZDY prezila `sanitize_name`
        # (limit 80 znakov) — inak by sa dve kopie zliali na ten isty nazov.
        def with_suffix(base, suffix)
          tail = " #{suffix}"
          room = NAME_MAX_LEN - tail.length
          room = 0 if room.negative?
          trimmed = base.length > room ? base[0, room].to_s.rstrip : base
          return suffix.to_s if trimmed.empty?

          "#{trimmed}#{tail}"
        end

        def squeeze(value)
          value.to_s.gsub(/\s+/, ' ').strip
        end
      end
    end
  end
end
