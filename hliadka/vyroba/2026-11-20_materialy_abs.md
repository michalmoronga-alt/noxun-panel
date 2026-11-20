# Hliadka výroby 2026-11-20 · materiály, ABS a hrany

- Oblasť: Pi — materiály, ABS, hrany (STANDARD §7)
- Prečítané: správa 2026-11-13, grep číselných operácií v abs_rules.rb, materials_abs.rb, materials_project.rb
- run_all: 5450 passed, 0 failed (LANG=C.UTF-8 nutné)

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Od 2026-11-13 žiadna zmena v core/ materiálov (main stále z 27.10.).
- Žiadne ×/÷ 25.4 ani round/floor/ceil na rozmeroch či cenách; jediné .to_i je quantity (materials_project.rb:119) a verzie schém.
