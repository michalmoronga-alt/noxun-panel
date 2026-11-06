# Hliadka výroby 2026-11-06 · materiály, ABS a hrany

- Oblasť: Pi — materiály, ABS, hrany (STANDARD §7)
- Prečítané: STANDARD §7.1, core/materials_abs.rb (30-150), grep číselných operácií v abs_rules.rb a materials_project.rb
- run_all: 5450 passed, 0 failed (LANG=C.UTF-8 nutné)

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Od 2026-10-30 žiadny commit v materials_catalog/abs/project, abs_rules, edge_check.
- Hrúbkové triedy ABS a porovnania s toleranciou 0,01; výber šírky pásky (nikdy užšia), bez zaokrúhľovania.
- abs_for_sheet: hierarchia group_id → presná štruktúra → universal; prázdna štruktúra nie je zhoda.
- Žiadne ×/÷ 25.4 ani round/floor/ceil na rozmeroch v abs_rules/materials_abs/materials_project.
