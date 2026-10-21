# Hliadka výroby 2026-10-21 · ceny a rozpočet

- Oblasť: St — ceny a rozpočet
- Prečítané: STANDARD §11.3, outputs.md (sheet_estimate, budget, budget_store, price_refresh), core/sheet_estimate.rb (celý), core/budget.rb (materials/area/abs/services/standard/custom/appliances/totals/base_row/section/normalize_state), core/budget_store.rb (override, násobky, množstvá, ceny, numeric_map), core/supplier_settings.rb (rate, row_rate, scalar), core/price_refresh.rb (refresh/apply/write_material)
- `ruby tests/run_all.rb` (LANG=C.UTF-8): 5419 passed, 0 failed

## Nálezy
Žiadne (0).

## Podozrenia (bez dôkazu, nepočítajú sa)
Žiadne.

## Skontrolované bez nálezu
- Odhad platní: duplák sa pripočíta zdroju (m², nie quantity), ceil na desatinu bez float driftu, nulová plocha preskočená, fallback formátu pri neplatnej dvojici.
- Cena platne z presnej plochy formátu (4100×635 → 26,04 pri 10 €/m²), `plates_of` round(6) pred ceil.
- Riadok „podľa plochy": min 0,01 m², m2_exact bez dvojitého zaokrúhlenia, služby berú estimate_qty.
- ABS: rezerva %, neznáma cena → price_missing (nie 0).
- Neznáma cena sa nenahrádza nulou (base_row, section.unknown_count); „dodáva zákazník" = 0 v súčte bez zápisu 0.
- Zaokrúhlenie ponuky len na konečnú sumu, ceil_to s round(6); DPH iba zobrazenie (÷1,23).
- Vstupy rozpočtu: ceny, násobky, prepisy, množstvá validované rozsahom, neplatné čísla sú chyba, nie 0; desatinná čiarka.
- Sadzby služieb: fallback na SEED_RATES, všetky kľúče pokryté.
