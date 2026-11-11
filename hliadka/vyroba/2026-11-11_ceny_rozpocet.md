# Hliadka výroby 2026-11-11 · ceny a rozpočet

- Oblasť: St — ceny a rozpočet
- Prečítané: core/budget.rb (totals_and_rounding, ceil_to, stale_scan, section, apply_override, normalize_state), grep zaokrúhľovania v price_refresh.rb, STANDARD §11.3, hliadka/NAHLASENE.md, report 2026-11-04; `git log` ceny-súborov: žiadna zmena od 2026-11-04
- `LANG=C.UTF-8 ruby tests/run_all.rb`: 5450 passed, 0 failed (bez LANG=C.UTF-8 helper spadne na US-ASCII — prostredie, nie kód)

## Nálezy
Žiadne (0).

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- totals_and_rounding: súčet len sekcií counts_in_total, ceil_to s round(6), rozdiel zaokrúhlenia round(2), DPH len zobrazenie (§11.3).
- section: neznáma cena → medzisúčet len zo známych, unknown_count sa hlási (nie tichá 0 €).
- apply_override a normalize_state: whitelisty, plan_prices len pri `true`.
- price_refresh: jediné zaokrúhlenie diff round(4), bez vplyvu na výslednú cenu.
