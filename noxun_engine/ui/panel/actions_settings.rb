# frozen_string_literal: true
# Noxun Engine - Panel: NASTAVENIA INSPECTORA (koliesko v raile, UI-B3).
#
# Dve veci, obe su nastavenie POCITACA (%APPDATA%), nie zakazky — do modelu sa
# odtialto NIKDY nezapisuje a ziadna z ciest neotvara operaciu (ziadny krok Spat):
#   * tema UI (NOXUN / Lucia) — zapis + ZIVE nasadenie vsetkym otvorenym oknam,
#   * rozmerove rady (N6) — hodnoty ponukane pri rozmerovych poliach.
# Cast modulu Panel (reopen) - zdiela ivary cez class << self.
module Noxun
  module Engine
    module Panel
      class << self
        # Prepnutie temy z kolieska. Autorita whitelistu je Ruby
        # (Engine.normalize_ui_theme) — HTML nie je ochrana. Odpoved sa NEPOSIELA
        # zvlast: `apply_ui_theme` rozposle `nxThemeApply` VSETKYM zivym oknam
        # vratane tohto panela, takze prepnutie vidno hned a bez restartu.
        # Codex audit FIX 6: zlyhanie zapisu sa NEsmie hlasit ako uspech —
        # apply_ui_theme vracia nil, ked sa tema neulozila (disk, prava).
        # Okna aj tak dostanu PLATNU temu (rozposiela sa ta ulozena), takze
        # panel nikdy neukazuje farbu, ktora nie je zapisana.
        def handle_set_ui_theme(payload)
          data = parse(payload)
          theme = Engine.apply_ui_theme(data['theme'])
          push_ui_settings
          if theme.nil?
            return set_status('Tému sa nepodarilo uložiť (disk/práva) — ostáva pôvodná.', true)
          end

          set_status(theme == 'lucia' ? 'Téma: Lucia (ružová).' : 'Téma: NOXUN (teal).')
        end

        # Ulozenie rozmerovych radov z editora. Normalizaciu (cisla, rozsah,
        # duplicity, poradie, pocet) robi VYHRADNE DimSeries — panel posle, co
        # pouzivatel napisal, a spat dostane presne to, co sa ulozilo.
        #
        # H10b/R-35: panel posiela LEN zmenene rady (`series`) a ku kazdemu
        # hodnotu, ktoru editor ukazal pri otvoreni (`base`). Dve okna SketchUpu
        # sa tak pri ROZNYCH radoch zlucia; ten isty rad zmeneny inde = konflikt
        # a nezapise sa nic (`DimSeries.update!`). Status vyhodnocuje `case`,
        # nikdy pravdivost (`:conflict` je v Ruby pravdive).
        def handle_set_dim_series(payload)
          data = parse(payload)
          status, _series, keys = DimSeries.update!(data['series'], data['base'])
          # Codex #170 P2: `refill_editor` = prepis polia editora NORMALIZOVANOU
          # podobou. Bez neho by v otvorenom modale ostal text, ktory pouzivatel
          # napisal (neusporiadany, s duplicitami, s nezmyslami), hoci ulozilo sa
          # nieco ine — a status by pritom hlasil uspech. Priznak nesie LEN tato
          # cesta, aby iny push (tema) rozpisany draft neprepisal. H10b: chodi
          # pri KAZDOM vysledku — editor tym znova pripne povodne hodnoty
          # (po konflikte ukaze aktualne ulozene rady, rozpis sa strati).
          msg, err =
            case status
            when :ok
              [keys.empty? ? 'Rozmerové rady sa nezmenili.' : 'Rozmerové rady uložené.', false]
            when :conflict
              ["Rozmerové rady (#{DimSeries.labels(keys)}) medzitým zmenilo iné okno SketchUpu — " \
               'nič sa neuložilo. Editor ukazuje aktuálne uložené rady, zmenu zadaj znova.', true]
            when :stale_client
              ['Okno je z predošlej verzie pluginu — rozmerové rady sa neuložili. ' \
               'Zavri a otvor panel znova.', true]
            when :blocked
              # 1d/R-11: poskodeny primar s platnou `.bak` = zapis ODMIETLA brana,
              # nie disk. Vseobecna hlaska „disk/prava" by pouzivatela poslala
              # hladat nespravnu pricinu — naprava je oprava/zmazanie suboru.
              reason = DimSeries.write_block_reason
              [reason.empty? ? 'Rozmerové rady sa nepodarilo uložiť (disk/práva).' : reason, true]
            else
              ['Rozmerové rady sa nepodarilo uložiť (disk/práva).', true]
            end
          # Predrecenzia H10b (P3): modal kolieska PREKRYVA `#status` panela —
          # veta ide aj do riadku priamo v sekcii Rozmerove rady (`series_status`),
          # inak by pouzivatel nevidel, preco sa mu rozpisany text prepisal.
          push_ui_settings(refill_editor: true, series_status: { 'text' => msg, 'error' => err })
          set_status(msg, err)
        end

        # Nastavenia pocitaca do panela (rady + tema). Chodia aj v push_init;
        # tento maly push ich obnovi po zmene BEZ prekreslenia formulara.
        def push_ui_settings(refill_editor: false, series_status: nil)
          return unless dialog_alive?

          data = ui_settings_payload(refill_editor: refill_editor)
          # H10b: veta vysledku ulozenia radov pre riadok v modale — nesie ju
          # LEN odpoved na ulozenie (spolu s `refill_editor`).
          data['series_status'] = series_status if series_status
          js("if (window.NX && NX.setUiSettings) NX.setUiSettings(#{data.to_json});")
        rescue StandardError => e
          Engine.log_error(e, 'Panel.push_ui_settings')
        end

        # TEMA V TOMTO PAYLOADE NIE JE — a nesmie pribudnut. Farby nasadzuje
        # VYHRADNE `nxThemeApply` cez kanal `win_fit.js` (jediny skript, ktory
        # nacitavaju vsetky okna), panel si temu nedrzi a JS len cita
        # `data-nx-theme` z korena, aby vedel, ktore tlacidlo je aktivne. Druhy
        # kanal temy by znamenal dva zdroje pravdy o farbe okna.
        def ui_settings_payload(refill_editor: false)
          { 'dim_series' => DimSeries.get, 'refill_editor' => refill_editor }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.ui_settings_payload')
          { 'dim_series' => DimSeries::DEFAULTS, 'refill_editor' => false }
        end
      end
    end
  end
end
