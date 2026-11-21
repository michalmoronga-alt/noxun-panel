# Hliadka výroby 2026-11-21 · konštrukcia (výpočty)

- Oblasť: So — construction, cabinet_types, zones, zone_tree, front_profiles, dim_series, units, modules/fronts, modules/shelves
- Prečítané: NAHLASENE.md, hliadka/vyroba/2026-11-14_konstrukcia.md, STANDARD §3 (3.1–3.4), units.rb, shelves.rb, cabinet_types.rb
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → 5450 passed, 0 failed

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Od hliadky 2026-11-14 sa žiadny súbor oblasti nezmenil (git log bez commitov) — nový kód na kontrolu nie je.
- units.rb: jediný prevod ×25.4 na hranici, bez celočíselného delenia.
- shelves.rb: `gap = (clear − n·t)/(n+1).to_f` je Float, počet orezaný na 0–6.
- cabinet_types.rb: neznámy typ → dolná, limity umývačky v mm Float.
- Testová sada zelená.
