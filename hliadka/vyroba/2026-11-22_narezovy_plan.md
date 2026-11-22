# Hliadka výroby 2026-11-22 · nárezový plán a kontroly

- Oblasť: Ne — validation.rb (check_oversize, invalid_dims, layout_context), sheet_layout.rb (purchase_rect, fits_rect?, rotation_allowed?, unplaced_reason); STANDARD §10
- Prečítané: NAHLASENE.md, správa 2026-11-15, STANDARD §10–11.2, uvedené úseky validation.rb a sheet_layout.rb
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → passed 5450, failed 0

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Kontrola nadrozmeru berie obdĺžnik z `SheetLayout.purchase_rect` (jedna príprava s plánom, §10 „jednu prípravu").
- Otáčanie: `rotation_allowed?` len pre dielec bez smeru dekoru, `grain` sa berie pôvodný — zhodné so §10.
- Neplatný rozmer → samostatný RED `invalid_dims`; `invalid_params` nehlási falošný nález.
- fallback/UNI bez formátu = bez nálezu, v súlade so štandardom.
- Kód v oblasti sa od 2026-11-15 nemenil (len verzie a export dir).
- Nepokryté: grain_check.rb, direction_check.rb, appliance_checks.rb (UI overlaye), zvyšok validation.rb.
