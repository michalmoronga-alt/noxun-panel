# Hliadka výroby 2026-10-30 · materiály, ABS a hrany

- Oblasť: Pi — materiály, ABS, hrany (STANDARD §7)
- Prečítané: STANDARD §7.1, core/abs_rules.rb (thicknesses_for, normalize_rules), core/materials_abs.rb (grep číselných operácií), core/edge_check.rb (grep funkcií)
- run_all: 5450 passed, 0 failed, 21 skipped (nutné LANG=C.UTF-8; pod US-ASCII padá tests/helper.rb:33 — vlastnosť prostredia)

## Nálezy
Žiadne.

## Podozrenia
Žiadne dokázateľné.

## Skontrolované bez nálezu
- Porovnania hrúbky ABS používajú toleranciu 0,01 (materials_abs.rb:62,136), šírka pásky + WIDTH_MARGIN bez zaokrúhlenia.
- abs_rules.normalize_rules prijíma len 1,0/2,0; thicknesses_for filtruje cez supported_edge_thickness? — bez tichej zmeny hrúbky.
- Identita variantu (STANDARD §7.1) a quantity v edge_check naposledy overené 2026-10-23; súbory od vtedy bez zmeny commitom nekontrolované hlbšie.
- edge_check.rb je z väčšej časti UI/overlay; výpočtová časť (classify_edges) bez nálezu.
