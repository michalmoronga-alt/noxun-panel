# Hliadka výroby 2026-10-25 · nárezový plán a kontroly

- Oblasť: Ne — sheet_layout.rb (frame, prepare_rect, collect_row, material_result, pack, offcut, rotácia), STANDARD §10 (oversize, orez, duplák)
- Prečítané: sheet_layout.rb (väčšina), STANDARD §10, tests/pure/test_sheet_layout.rb (hlavička), helper.rb
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → failures: [] (bez LC_ALL padá helper.rb:33 na US-ASCII — len prostredie, nie nález)
- Nedostatok času/rozpočtu: validation.rb, grain_check.rb, direction_check.rb, appliance_checks.rb tentoraz nečítané.

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Orez: NO_TRIM_TYPES (pracovná doska, kompakt, zástena) = 0, ostatné 2×trim na os; zhodné s §10.
- Duplák: prídavok po zaokrúhlení, count = qty × násobok.
- Fuzz 300 náhodných plánov (kerf 4, orez 10, grain length/width/none): 5935 dvojíc dielcov, žiadny prekryv, žiadny dielec mimo použiteľnej plochy.
- Riadky s rovnakým key_text+rozmerom sa zlučujú správne (count sa sčíta).
