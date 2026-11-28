# Hliadka výroby 2026-11-28 · konštrukcia (výpočty)

- Oblasť: So — construction, cabinet_types, zones, zone_tree, front_profiles, dim_series, units, modules/fronts, modules/shelves
- Prečítané: NAHLASENE.md, POSLEDNE_VYROBA.md, hliadka/vyroba/2026-11-21_konstrukcia.md, zones.rb (grep), dim_series.rb:80-100, zone_tree.rb (grep delení)
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → 5450 passed, 0 failed (bez LC_ALL padá helper.rb:33 na US-ASCII v prostredí hliadky — prostredie, nie chyba kódu)

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- git log: od 2026-11-21 sa žiadny súbor oblasti nezmenil.
- dim_series.to_mm: čiarka sa neberie ako desatinná, nefinite hodnoty → nil, zaokrúhlenie len pri vstupe radu rozmerov.
- zone_tree: delenia sú Float (`free / [n,1].max`, `weight_sum`), ochrana proti deleniu nulou; MIN_FIELD 20.0 mm.
- zones.rb: žiadne zaokrúhľovanie ani celočíselné delenie rozmerov.
- units.rb, shelves.rb, cabinet_types.rb: bez zmeny oproti minulej kontrole.
