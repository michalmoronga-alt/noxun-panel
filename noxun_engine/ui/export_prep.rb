# frozen_string_literal: true
# H17 (C-06, prvy rez R-15): SPOLOCNA PRIPRAVA EXPORTOV.
#
# Styri exporty Studia (VEPO, CSV kovania, XLSX rozpoctu a cenovej ponuky)
# zacinali tym istym uvodom opisanym styrikrat — generacia okna, cervene polia,
# cerstve nastavenia, brana `expect`, cerstvy zber, brana novsej schemy a chrbta.
# Uvod zije odteraz TU, v jednom `start`; data zakazky (overeny nazov, kusovnik,
# kovanie, rozpocet, kontrola) dava export z jedneho lenivého `Context`, ktory
# kazdy udaj spocita najviac raz. BRANY DRUHU VYSTUPU (kit zasuviek, duplicity,
# `budget_std`, potvrdenie cien, firewall ponuky…) ostavaju v exportoch v dnesnom
# poradi — jedno nerozlisene „export povoleny" by spravanie zmenilo (CX R-15).
#
# NOVY VYSTUP (vykresy, etikety, CNC) = riadok v `KINDS` + telo, ktore zacne
# `ctx = ExportPrep.start(...)` / `return unless ctx` — ziadna kopia uvodu
# (strazca `test_h17_export_prep.rb` R4 b ho bez toho nepusti).
#
# PRECO `ui/`: uvod vola `ProductionCore` (okno, vety statusu, `repush`) a `core/`
# nesmie volat `ui/`; pamat kontextu v `production_core.rb` by narazila na zakaz
# instancnych premennych modulu. Modul je BEZSTAVOVY — `Context` zije len pocas
# jedneho volania exportu a nikdy sa nezdiela s oknom ani medzi exportmi.
module Noxun
  module Engine
    module ExportPrep
      # Inventar exportov: kluc -> vstup `ProductionCore`. Mnozina funkcii
      # pluginu s `UI.savepanel`/`UI.select_directory` == hodnoty (strazca R4 b).
      KINDS = { vepo: 'do_export', hw_csv: 'do_hw_csv', budget: 'do_budget_xlsx', offer: 'do_cp_xlsx' }.freeze

      GEN_MSG = 'Dáta okna sa medzitým zmenili — skús export znova.'
      FLUSH_MSG = 'V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.'

      # Lenive data JEDNEHO exportu. Kazda citacka sa vyhodnoti najviac raz
      # a pamata si aj `nil` (expanzia, ktora sa nedala zostavit, sa v tom
      # istom exporte nepocita znova). Volania idu cez PRIJIMAC modulu
      # (`ProductionCore.<meno>`), takze ich stuby testov zachytia.
      #
      # POZOR — pamat `nil` plati pre CITACKU, nie pre `budget_payload`: ked
      # `hw_exp` vrati `nil`, rozpocet dostane TEN ISTY `nil` a jeho dnesny
      # fallback (`hw_exp || hardware_expansion(...)`) expanziu zopakuje — ako
      # pred H17 (§15 A2). Kontext ho NESMIE obist (podat `{}` alebo expanziu
      # z inej cesty) — to by bola zmena spravania, nie presun.
      #
      # PORADIE PRVYCH CITANI je kontrakt EXPORTU, nie kontextu (§15 A3): export
      # cita citacky v dnesnom poradi (ponuka `bom` -> `smap` -> `budget`, VEPO
      # `hw_exp` pred vyberom priecinka a `bom`/`control` az po nom). Ziadna
      # citacka nema `rescue`, cas ani picker — vynimka ide do `rescue` exportu.
      class Context
        attr_reader :model, :kind, :gate

        def initialize(model, kind, gate)
          @model = model
          @kind = kind
          @gate = gate.dup.freeze
          @memo = {}
        end

        # Overeny nazov zakazky (normalizovany, H7b review #457) — JEDINY zdroj
        # mena suboru a obsahu exportu.
        def project
          @gate[:project]
        end

        # Overene 18 + 36 (pouziva len VEPO).
        def merge
          @gate[:merge]
        end

        # Veta na koniec statusu (automaticky -> automaticky nazov), inak ''.
        def name_note
          @gate[:note]
        end

        # VEDOMA ZMENA (audit #15) plati aj tu: zber je CERSTVY az v exporte, nie
        # z toho, co drzi DOM — poistka proti prestavbe skrinky z Inspectora,
        # ktora generaciu okna nezdviha.
        def collected
          memo(:collected) { ProductionCore.fresh_collect(@model) }
        end

        def bom
          memo(:bom) { Bom.compute(collected) }
        end

        def smap
          memo(:smap) { ProductionCore.sheets_map }
        end

        def hw_exp
          memo(:hw_exp) { ProductionCore.hardware_expansion(@model, collected) }
        end

        # Bez `estimate`/`layout` — rozpocet si ich spocita sam z TOHO ISTEHO
        # zberu (vysledok zhodny, S8); odhad sa tu nepocita, lebo jeho vynimka
        # patri do `rescue` rozpoctu (-> `nil`), nie exportu (S9).
        def budget
          memo(:budget) { ProductionCore.budget_payload(@model, bom, collected, nil, hw_exp, smap) }
        end

        # Kontrola VRATANE upozorneni rozpoctu (ST-1b review #1) — LOG a status
        # VEPO hovoria to iste cislo ako sekcia Kontrola.
        def control
          memo(:control) do
            ProductionCore.control_payload(collected, hardware_expansion: hw_exp, budget: budget, sheets: smap)
          end
        end

        private

        def memo(key)
          return @memo[key] if @memo.key?(key)

          @memo[key] = yield
        end
      end

      module_function

      # Spolocny uvod exportu `kind` (kluc `KINDS`). -> `Context`, alebo `nil`,
      # ked sa export zastavil (veta uz odisla cez `status`). Poradie je ZAVAZNE:
      #
      #  1. generacia okna — klik z okna, ktoreho payload uz neplati (medzitym
      #     prepnuty dokument alebo push z ineho miesta) -> okno sa obnovi
      #     (`repush`) a povie to. VEDOMA ZMENA (audit #15): CSV kovania tento
      #     guard predtym NEMAL — zosuladenie, nie nova ochrana. CO NECHYTA:
      #     prestavbu skrinky z Inspectora (generaciu nezdviha); na tu je
      #     poistkou CERSTVY zber nizsie, nie DOM.
      #  2. cervene polia panela (`flush_blocked`).
      #  3. `ExportSettings.refresh` (1b-6c): nazov aj 18 + 36 z CERSTVEHO suboru.
      #  4. brana `expect` (H7b §16 B2, §17 C1): okno musi vidiet to, co plati —
      #     nazov, a vo VEPO aj 18 + 36 (`merge: true`). Nesulad alebo stary
      #     klient = export sa nespusti. Vola sa PRAVE RAZ — citanie nazvu ho
      #     moze preniest k suboru (`adopt_session_name`), druhe volanie by
      #     videlo iny stav. Jej `:project`/`:merge`/`:note` nesie kontext:
      #     hodnoty OVERENE pred vyberom suboru (druha instancia SketchUpu ich
      #     pocas modalneho vyberu mohla zmenit).
      #  5. CERSTVY zber celej zakazky.
      #  6. brana NOVSEJ SCHEMY (KOV-H1 / review #283 P2-B, GHOST-D1) HNED po
      #     zbere — pred expanziou, rozpoctom aj „niet co exportovat", ktore by
      #     nekompatibilnu zakazku prekryli inou hlaskou. Plati aj pre VEPO:
      #     skrinka ci doska z novsej verzie moze niest VYROBNE pole, ktore tento
      #     plugin nevidi, takze aj rezaci vystup by bol ticho neuplny.
      #  7. vyrobna brana CHRBTA v drazke (D-143, KON-0) — VSETKY exporty.
      # Picker sa pri ktorejkolvek blokade ani neotvori.
      #
      # Ziadny `rescue` (vynimka ide do `rescue` exportu s jeho vetou), ziadny
      # picker ani zapis suboru; neznamy `kind` = chyba programu (ArgumentError).
      def start(model, data, kind, generation:, status:, repush:)
        raise ArgumentError, "ExportPrep: neznámy druh exportu #{kind.inspect}" unless KINDS.key?(kind)

        unless data['gen'].to_i == generation.to_i
          repush.call
          status.call(GEN_MSG, true)
          return nil
        end
        if data['flush_blocked']
          status.call(FLUSH_MSG, true)
          return nil
        end

        ExportSettings.refresh
        gate = ProductionCore.export_expect_check(model, data, merge: kind == :vepo)
        if gate[:stop]
          status.call(gate[:stop], true)
          return nil
        end

        ctx = Context.new(model, kind, gate)
        newer_stop = ProductionCore.newer_config_stop(ctx.collected)
        if newer_stop
          status.call(newer_stop, true)
          return nil
        end
        cut_msg = ProductionCore.cut_stop(ctx.collected)
        if cut_msg
          status.call(cut_msg, true)
          return nil
        end
        ctx
      end
    end
  end
end
