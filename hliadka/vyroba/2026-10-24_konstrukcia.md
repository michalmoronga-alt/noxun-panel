# Hliadka výroby 2026-10-24 · konštrukcia (výpočty)

- Oblasť: So — construction, zone_tree, zones, shelves, dim_series, units, modules/fronts (výbery), STANDARD §3 (3.1–3.4), §4, §5
- Prečítané: STANDARD §3–5, units.rb, shelves.rb, zones.rb, zone_tree.rb (split/fields/shelves/dividers), fronts.rb (layout, panels_for, validate_*), dim_series.rb (to_mm)
- run_all: `ruby tests/run_all.rb` (LC_ALL=C.UTF-8) → failures: [] (bez pádov)

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Jednotky: mm↔palce len v units.rb (×25.4 na jedinom mieste).
- Fuzz 3000 náhodných korpusov (rozmery, hrúbky, režimy dna/stropu/chrbta, komín, zapustenie, výstuhy, zónový strom, police): 2868 plánov, 132 oprávnene odmietnutých; vo všetkých prod (dĺžka/šírka/hrúbka) = box, žiadny rozmer ≤ 0, žiadny korpusový dielec mimo obrysu skrinky.
- Fuzz 2500 konfigurácií čiel (dvere 1–4 krídla, zásuvky, výklop, sklop, blenda, bez čela, fixná/auto výška, medzery): 2353 plánov; prod = box, žiadne krídlo mimo šírky, nad výškou korpusu ani prekryv krídel v rade.
- zone_tree: kumulatívny clamp zamknutých polí, rezerva MIN_FIELD, výška police n*t+(n+1)*MIN_FIELD, priečky v rozsahu rodiča.
- dim_series.to_mm: zaokrúhlenie je zámerné (rad bežných rozmerov, nie výrobné číslo).
