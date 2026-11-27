# Hliadka výroby 2026-11-27 · oblasť: materiály, ABS a hrany (Pi)

Prečítané: STANDARD §7 (7.1, ABS odseky 7.5), NAHLASENE.md, materials_abs.rb (resolver, abs_for_sheet, pick_edge_variant, remap_edges_v2), abs_rules.rb (thicknesses_for, resolve_edges), edge_check.rb (classify_edges), materials.rb (WIDTH_MARGIN, whitelist).
run_all: 5450 passed, 0 failed, 21 skipped (LANG=C.UTF-8; bez neho helper.rb padá na kódovaní US-ASCII — prostredie, nie chyba pluginu).

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Preferencie hrúbky ABS: jednotka 0,8→1,0→1,2, dvojka 2,0→1,5, 0,4 sa nikdy nevolí automaticky — zhoda s §7.5.
- Výber šírky pásky: najmenšia ≥ hrúbka+2 mm → bez šírky → nič, nikdy užšia — zhoda.
- Štruktúra: dve prázdne štruktúry nie sú zhoda, universal len pri explicitnom príznaku — zhoda.
- Remap pri zmene materiálu: ručná 0,4 → bez ABS + abs_04_manual; zmena hrúbky variantu pre-resolvuje úzku pásku — zhoda.
- edge_check: MISSING/EXTRA/TAPED, quantity min. 1, preskočenie UNI/nelepiteľných — bez nálezu.
- Jednotky (25,4), zaokrúhľovanie: v týchto súboroch sa nevyskytujú.
