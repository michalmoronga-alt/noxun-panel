# Hliadka výroby 2026-11-18 · ceny a rozpočet

- Oblasť: St — ceny a rozpočet
- Prečítané: core/sheet_estimate.rb (celé), grep zaokrúhľovania v supplier_settings.rb, hliadka/NAHLASENE.md, report 2026-11-11; `git log` ceny-súborov: žiadna zmena od 2026-11-04
- `LANG=C.UTF-8 ruby tests/run_all.rb`: 5450 passed, 0 failed (bez LANG=C.UTF-8 helper spadne na US-ASCII — prostredie, nie kód)

## Nálezy
Žiadne (0).

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- sheet_estimate: plocha = length×width×quantity/1e6 (mm→m², bez palcov); duplak pripočítaný zdrojovému materiálu ×multiplier, quantity len vlastné dielce; m2_exact bez dvojitého zaokrúhlenia; ceil_tenth s round(6); delenie nulou nemožné (sheet_size_for fallback na kladné hodnoty); neplatné koeficienty → defaulty.
- supplier_settings: rounding_step cez num_in s rozsahom a defaultom; ďalšie zaokrúhlenia len formátovanie zobrazenia.
- budget/budget_store/price_refresh: kód nezmenený od 2026-11-04, predošlé kontroly bez nálezu.
