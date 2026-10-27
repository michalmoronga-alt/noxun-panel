# Hliadka výroby 2026-10-27 · VEPO a exporty

- Oblasť: Ut — VEPO a exporty
- Prečítané: SYSTEM/VEPO_KONTRAKT.md, hliadka/NAHLASENE.md, hliadka/vyroba/2026-10-20_vepo_exporty.md; `git log` súborov oblasti (vepo_export, cp_export, xlsx_writer, export_prep, production_core)
- Kód oblasti sa od hliadky 2026-10-20 nezmenil (posledná zmena vepo_export.rb 2026-10-01, bez zmeny správania), preto sa hĺbková kontrola nezopakovala.
- `LANG=C.UTF-8 ruby tests/run_all.rb`: 5442 passed, 0 failed.

## Nálezy
Žiadne (0).

## Podozrenia
Žiadne nové. Platia 2 podozrenia z 2026-10-20 (rozmer < 0,5 mm → `0` v CSV; `int_qty` v cp_export) — stále bez dôkazu.

## Skontrolované bez nálezu
- Zmeny kódu oblasti od poslednej hliadky: žiadne.
- Celá sada testov zelená (+23 testov oproti 2026-10-20).
- Kontrakt VEPO v1.2 (9 stĺpcov, `;`, NAME_MAX 20, kódy hrán, obchodné hrúbky) — bez zmeny oproti predošlej kontrole.
