# Hliadka výroby 2026-11-15 · nárezový plán a kontroly

- Oblasť: Ne — core/sheet_layout.rb (celý, 815 r.); STANDARD §10 (odsek „Nezmestí sa na platňu")
- Prečítané: sheet_layout.rb, STANDARD §10–§11.2, predchádzajúca správa 2026-11-08, NAHLASENE.md
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → passed 5450, failed 0 (bez LC_ALL sa helper.rb nenačíta — prostredie, nie chyba kódu)

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Orez: NO_TRIM_TYPES (PD, KOMPAKT, ZASTENA) bez orezu, ostatné `size - 2*trim` na oboch osiach, v súlade s §10.
- Duplák: prídavok `2*dup_allowance` až po zaokrúhlení, počet = quantity × multiplier; pri chýbajúcej väzbe sa nedomýšľa.
- Otáčanie: plán neotáča (N8), Kontrola len dielec bez smeru dekoru (`rotation_allowed?`) — zhodné so §10.
- Tolerancia: jediná `DIM_TOL` vo `fits_rect?`, `place_in_strip`, `place_new_strip`; prerez len medzi dielcami a pásmi.
- Počty: `count` sa pripočíta k jednému riadku (key_text, l, w), rects sa rozbalia 1..count — bez dvojitého ani vynechaného započítania.
- Parametre: nil/záporné/NaN → `invalid_params`, plán nevznikne; neplatný vstup nehodí výnimku.
- Cena podľa plánu: `price_reasons` vyžaduje úplný a spoľahlivý plán, inak odhad z m² — žiadna tichá 0.
- Nepokryté: validation.rb (okrem odseku oversize), grain_check.rb, direction_check.rb (UI overlaye); kód sa od 2026-11-08 menil len v šírke skrinky (v0.17.28).
