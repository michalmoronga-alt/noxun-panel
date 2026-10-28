# Hliadka výroby 2026-10-28 · ceny a rozpočet

- Oblasť: St — ceny a rozpočet
- Prečítané: core/budget.rb (services_section, standard_rows, custom_section, totals_and_rounding, ceil_to), hliadka/vyroba/2026-10-21_ceny_rozpocet.md; `git log` pre budget, budget_store, price_refresh, supplier_settings, sheet_estimate: od 2026-10-21 žiadny commit
- `ruby tests/run_all.rb` (LANG=C.UTF-8): 5449 passed, 1 failed, 21 skipped. Spadol len časový test "NP-3 limit" (push_state 271,4 ms proti limitu 250 ms), čo je zaťaženie cloudového stroja, nie výrobné číslo. Bez LANG=C.UTF-8 padá helper.rb na kódovaní US-ASCII.

## Nálezy
Žiadne (0).

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Kód oblasti sa od hliadky 2026-10-21 nezmenil, jej závery platia.
- Zaokrúhlenie ponuky: ceil_to s round(6) pred ceil, DPH len zobrazenie (÷ VAT_DIVISOR), neplatný krok → 1.
- Služby: porez a montáž berú estimate_qty pri riadku "podľa plochy", montáž m² = platne × m²/platňa (round 2).
- Štandardné riadky per_m2: chýbajúce m² z meračky → price_missing, nie tichá 0 €; násobok 0 → nulový viditeľný riadok.
- Vlastné položky: počet < 1 → 1, neznáma cena zostáva nil.
