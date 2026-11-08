# Hliadka výroby 2026-11-08 · nárezový plán a kontroly

- Oblasť: Ne — appliance_checks.rb (celý; nepokryté v kole 2026-11-01), STANDARD §10 nečítaný znova
- Prečítané: appliance_checks.rb (1–600), predchádzajúca správa 2026-11-01, NAHLASENE.md
- run_all: `LC_ALL=C.UTF-8 ruby tests/run_all.rb` → passed 5450, failed 0

## Nálezy
Žiadne.

## Podozrenia
Žiadne.

## Skontrolované bez nálezu
- Tolerancie (AXIS_TOL 0,5 / EPS 0,01) jedno porovnanie osi (`axis_state`) pre verdikt aj ponuku.
- Nula/záporné/nil vnútro = „unknown", nie falošné „ok"; chýbajúce údaje niky nezhodia kontrolu.
- Výška s osadením: vyčerpaný priestor (≤ 0) = clash; viac zón len skip + kontrola celého vnútra.
- Delenie čiel: pásmo `[D+10, D+G−s−10]`, prevod cez z_lo a osadenie konzistentný s kódom; unsatisfiable pri G < s+20.
- Modul je čisto verdiktový (semafor/Inspector), nemení rozmery, počty ani ceny.
- Nepokryté: zvyšok validation.rb (kovanie, duplicity), grain_check/direction_check (UI overlaye).
