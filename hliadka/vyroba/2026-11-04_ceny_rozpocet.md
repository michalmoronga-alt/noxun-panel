# Hliadka výroby 2026-11-04 · ceny a rozpočet

- Oblasť: St — ceny a rozpočet
- Prečítané: core/sheet_estimate.rb (celý), core/budget.rb (abs_section, hardware_section, unit_label, price_per_plate, plates_of, ceil_to), hliadka/vyroba/2026-10-21 a 2026-10-28, hliadka/NAHLASENE.md; `git log` ceny-súborov: žiadna zmena výpočtov od 2026-10-21
- `LANG=C.UTF-8 ruby tests/run_all.rb`: 5450 passed, 0 failed, 21 skipped

## Nálezy
Žiadne (0).

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- sheet_estimate: duplák pripočítaný zdroju, ceil_tenth s round(6), fallback formátu platne, neplatné koeficienty → defaulty.
- budget: cena za platňu z presnej plochy formátu, plates_of s round(6) pred ceil, ceil_to s round(6), ABS rezerva %, neznáma cena → nil (nie 0 €).
- Kovanie: množstvá sú celé počty (to_i zodpovedá hardware_sets), jednotka bal/m sa zachová, kľúč riadku case-insensitive.
