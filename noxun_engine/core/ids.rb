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
      # D-133/D-134: HROMADNE ZAPISOVE akcie zakazky sem NEPATRIA — vsetkych
      # PAT stoji na `top_level_scan` nizsie (D-134 cez `Panel.job_cabinets`),
      # lebo ich rozsah sa nesmie rozist s rozsahom vystupov. Citacie cesty
      # (katalogovy usage/delete guard, observery, dedup, resolvery vyberu)
      # globalny prechod NAOPAK potrebuju — tie sa nemenia.
      # D-34 (audit B4a): pocas erase okna mozu kolekcie niest NEPLATNE entity —
      # citanie atributov zmazanej entity pada (TypeError). valid? guard na
      # definicii aj instancii; headless fakes maju valid? v tests/helper.rb.
      def self.each_of_kind(model, kind)
        want = kind.to_s
        model.definitions.each do |dfn|
          next unless dfn.valid?
          next if dfn.image? || dfn.group?
          dfn.instances.each do |inst|
            yield inst if inst.valid? && Store.kind(inst) == want
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

      # D-133: PRECO je dovod odpojeneho dielca KONSTANTA a nie dve vety —
      # pytaju sa nan dve hromadne akcie („Kresba čiel" cez
      # `ProductionCore.front_grain_skip_reason` a „Nahradiť UNI…" cez
      # `Materials.ru_blocked_line`) a dve kopie tej istej vety by sa casom
      # rozisli. Pouzivatel by potom pri tom istom probleme cital raz jednu
      # a raz druhu napravu.
      DETACHED_PART_REASON = 'má odpojený dielec — vráť ho do skrinky alebo skrinku prestav'

      # D-133: JEDEN prechod KORENOM modelu pre hromadne ZAPISOVE akcie zakazky.
      # Vrati { 'cabinets' => [inst…], 'boards' => [inst…],
      #         'detached' => { cabinet_id => pocet } }.
      #
      # KTO HO POUZIVA (D-134 — vsetkych PAT hromadnych ZAPISOVYCH ciest):
      #   1) „Kresba čiel"            — `ProductionCore.front_grain_scan`
      #   2) „Nahradiť UNI…"          — `Materials.replace_uni_scan`
      #   3) pravidla kovania          \
      #   4) projektova predvolba mat.  > cez `Panel.job_cabinets` (D-134)
      #   5) „aj na podobné v projekte"/
      # PRAVIDLO: hromadny ZAPIS zakazky = TOP-LEVEL + skip (nastavenie projektu)
      # alebo blokada (all-or-nothing nahrada dekoru) pri odpojenom dielci;
      # CITANIE ostava globalne (`each_of_kind`).
      #
      # PRECO top-level a nie `each_of_kind`: kusovnik, VEPO aj Studio pracuju
      # s `model.entities` (vid `Bom.collect`) — to je „zákazka". Globalny
      # prechod cez `model.definitions` by nasiel aj korpus VNORENY v cudzom
      # komponente: ten vo vystupoch nie je a hromadna prestavba by ho zmenila
      # vo VSETKYCH vyskytoch zdielanej definicie.
      #
      # `detached` = vyrobne dielce vytiahnute na koren modelu. Taky dielec je
      # k vlastnikovi viazany uz len atributom `cabinet_id` a do kusovnika ide
      # PO SVOJOM (`Bom.collect`, vetva `part`), kym prestavba korpusu siaha len
      # na VNORENE dielce — zapis by teda vyrobil DVOJNIKA. Mapa sa stavia
      # v TOM ISTOM prechode ako korpusy (raz na zber, nie pri kazdej skrinke).
      # Filter je zamerne LEN `manufactured` (bez `production_class`) — presne
      # tak sa pytal D-131 scan, ktory sem prisiel; sirsia otazka („je tu nieco
      # odpojene?") je pre BRANU spravnejsia nez uzsia.
      # D-34 (rovnaka pasca ako v `each_of_kind`): pocas erase okna moze
      # `model.entities` niest NEPLATNE entity a citanie ich atributov pada
      # (TypeError). `valid?` guard je preto POVINNY aj tu — hromadna akcia by
      # inak spadla uprostred zberu a pouzivatel by videl len vynimku.
      def self.top_level_scan(model)
        out = { 'cabinets' => [], 'boards' => [], 'detached' => Hash.new(0) }
        return out unless model

        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          next unless inst.valid?

          case Store.kind(inst)
          when 'cabinet' then out['cabinets'] << inst
          when 'board'   then out['boards'] << inst
          when 'part'
            next unless Store.get(inst, 'manufactured') == true

            cid = Store.get(inst, 'cabinet_id').to_s
            out['detached'][cid] += 1 unless cid.empty?
          end
        end
        out
      end

      # part_id = <cabinet_id>-<ROLE_SUFFIX>, napr. CAB-001-SIDE-L, CAB-001-SHELF-2.
      def self.part_id(cabinet_id, role_suffix)
        "#{cabinet_id}-#{role_suffix}"
      end
    end
  end
end
