# Hliadka výroby 2026-10-31 · konštrukcia (výpočty)

- Oblasť: So — construction (rohová zostava), STANDARD §4.2
- Prečítané: STANDARD §4 (4.1–4.5), construction.rb:560-780 (corner_parts, corner_error, corner_fit_width), hliadka/vyroba/2026-10-24_konstrukcia.md
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → failures: [] (21 skipped). Bez LC_ALL sa helper.rb v US-ASCII prostredí zrúti na načítaní noxun_engine.rb (prostredie, nie chyba pluginu).

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Rohová zostava: súradnice CR 1 / CR 2 / rohová výstuha na seba nadväzujú (d+gC, d+c1, d+c1+th2) a sedia so vzorcami §4.2.
- corner_fit_width = D + c1 + th2 + 2t, čo je rovnaká nerovnosť ako v §4.2 (D + c1 + th2 + t ≤ W − t).
- Zrkadlo pre pravú stranu: x' = W − x − box[0] podľa §4.2.
- Výška CR = obrys riadku dverí, nie panelu; účinná hrúbka th1/th2 má návrat na 18 pri chýbajúcom kľúči.
- Zvyšok oblasti: pozri správu 2026-10-24 (fuzz bez nálezu); dnes bez nového kódu na kontrolu.
