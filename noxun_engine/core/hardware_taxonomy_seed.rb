# frozen_string_literal: true
# Noxun Engine — H15b: SEED DATA taxonomie kovania (LEN data, ziadna logika).
#
# CO TU ZIJE: `SEED_VERSION`, `SEED_MANUFACTURERS` a `SEED_SERIES` (+ historia
# v1..v3). Mechaniku (`merge_seed`, `migrate_axilo_owner!`, zamky, API) ma
# `hardware_taxonomy.rb`; parametre jednorazovej migracie vlastnika rady
# (`AXILO_*`) ostavaju pri nej.
#
# PRAVIDLA (guard `tests/pure/test_h15_seed_data.rb`):
#   * subor obsahuje LEN deklaracie konstant s literalmi (retazec, cislo,
#     nil/true/false, pole, hash, `%w[]`) a `.freeze` — ziadne `def`, volania
#     ani odkazy na konstanty logiky;
#   * nacitava sa PRED `hardware_taxonomy.rb` (`main.rb` a `tests/helper.rb`);
#   * ZMENA SEEDU = zmena tu + `SEED_VERSION` + VEDOMA regeneracia goldenu
#     `tests/fixtures/h15_golden/generate.rb` zdovodnena v PR. Bez bumpu sa
#     zmena do existujucich instalacii nedostane (STANDARD §13.1).
module Noxun
  module Engine
    module HardwareTaxonomy
      SEED_VERSION   = 3

      # SEED (v1). Zdroj: SYSTEM/zdroje/SEED_KATALOG_2026-07.md + debata 2.8.2026.
      # Doplna sa LEN to, co v subore CHYBA — pouzivatelske mena sa nikdy
      # neprepisuju a nic sa nemaze.
      # v2 (D-118, 7.9.2026): Tulip (uchytky a vesiaky, 6 seed poloziek) a rada
      # StrongBox (5 poloziek) — bez nich by ich katalogovy riadok nemal
      # vyrobcu a strom katalogu by ich zhodil pod „— bez vyrobcu".
      # v3 (KOV-G1a, 9.9.2026): vyrobca **Häfele** a rada **AXILO** presunuta
      # pod neho. AXILO je Häfele program, nie Hettich — seed v1 to mal ZLE
      # a od tejto davky ma set nôh aj devat katalogovych riadkov spravneho
      # vyrobcu. Presun existujucich suborov robi `migrate_axilo_owner!` nizsie.
      SEED_MANUFACTURERS = ['Hettich', 'Blum', 'Grass', 'Strong', 'Häfele',
                            'Tulip', 'Ostatné'].freeze
      SEED_SERIES = [
        ['Sensys', 'Hettich'], ['InnoTech Atira', 'Hettich'], ['Quadro', 'Hettich'],
        ['AvanTech YOU', 'Hettich'], ['AXILO', 'Häfele'],
        ['CLIP top', 'Blum'], ['AVENTOS', 'Blum'], ['TANDEMBOX', 'Blum'],
        ['LEGRABOX', 'Blum'], ['MERIVOBOX', 'Blum'], ['TIP-ON', 'Blum'],
        ['Nova Pro', 'Grass'], ['Tiomos', 'Grass'],
        ['StrongMax', 'Strong'], ['StrongBox', 'Strong']
      ].freeze
    end
  end
end
