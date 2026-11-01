# Hliadka výroby 2026-11-01 · nárezový plán a kontroly

- Oblasť: Ne — validation.rb (check_record, check_thickness, check_oversize, invalid_dims, check_abs, layout settings), sheet_layout.rb (purchase_rect, fits_rect?, rotation_allowed?), STANDARD §10
- Prečítané: validation.rb (riadky 355–740), sheet_layout.rb (132–195), STANDARD §10, grafické zoznamy grain_check.rb a direction_check.rb (len prehľad funkcií; sú to UI overlaye, bez výrobných čísel)
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → passed 5450, failed 0, skipped 21

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Oversize: jedna príprava s plánom (purchase_rect), rotácia len bez smeru, duplák zo zdrojového materiálu, UNI/fallback bez nálezu zhodne s §10.
- invalid_dims: nula, záporné, nečíslo a rozmer < 0,5 mm dávajú samostatný RED.
- Hrúbka: pravidlo cez CabinetBuilder.thickness_ok_for? (jedno pravidlo).
- ABS: PD postforming a kompakt sa nehlásia; čelo a voľná doska bez ABS = ORANGE raz na dielec.
- Nastavenia orezu: nečitateľné aj poškodené hodnoty sa priznajú ORANGE.
- Nepokryté: appliance_checks.rb a zvyšok validation.rb (kovanie, duplicity) nečítané.
