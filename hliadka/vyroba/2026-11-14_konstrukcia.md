# Hliadka výroby 2026-11-14 · konštrukcia (výpočty)

- Oblasť: So — construction, cabinet_types, zones, zone_tree, front_profiles, dim_series, units, modules/fronts, modules/shelves
- Prečítané: hliadka/vyroba/2026-11-07_konstrukcia.md, NAHLASENE.md; git log kódu oblasti
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → 5450 passed, 0 failed

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Žiadny súbor oblasti sa od hliadky 2026-11-07 nezmenil (git log: bez commitov), nový kód na kontrolu nie je.
- Testová sada zelená.
- Poznámka: bez LC_ALL=C.UTF-8 run_all padá na kódovaní (tests/helper.rb:33, US-ASCII) — len prostredie, nie chyba kódu.
