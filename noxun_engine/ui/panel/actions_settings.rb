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
        def handle_set_dim_series(payload)
          data = parse(payload)
          stored = DimSeries.set(data['series'])
          # Codex #170 P2: `refill_editor` = prepis polia editora NORMALIZOVANOU
          # podobou. Bez neho by v otvorenom modale ostal text, ktory pouzivatel
          # napisal (neusporiadany, s duplicitami, s nezmyslami), hoci ulozilo sa
          # nieco ine — a status by pritom hlasil uspech. Priznak nesie LEN tato
          # cesta, aby iny push (tema) rozpisany draft neprepisal.
          push_ui_settings(refill_editor: true)
          return set_status('Rozmerové rady sa nepodarilo uložiť (disk/práva).', true) if stored.nil?

          set_status('Rozmerové rady uložené.')
        end

        # Nastavenia pocitaca do panela (rady + tema). Chodia aj v push_init;
        # tento maly push ich obnovi po zmene BEZ prekreslenia formulara.
        def push_ui_settings(refill_editor: false)
          return unless dialog_alive?

          js("if (window.NX && NX.setUiSettings) NX.setUiSettings(#{ui_settings_payload(refill_editor: refill_editor).to_json});")
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
