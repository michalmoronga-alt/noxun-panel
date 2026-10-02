> Kópia zadania zo scratchpadu (2.10.2026); autorita = súbory v priečinku bloku.

# Brief — dávka H16 · súpis knižníc (C-04, príprava D-48) — blok 9 HARDENING

Si implementátor dávky **H16**. Pracuj z **čerstvého `origin/main`** (musí obsahovať H7a, H7b, H15a, H15b — over v `git log`; ak nie, STOP a otázka).
Vetva **`feat/h16-supis-kniznic`**, verzia = ďalší patch po aktuálnom maine.

## Zdroj (autorita v tomto poradí)
1. [`../PACKAGE_H16.md`](../PACKAGE_H16.md) — **§15 (audit zapracovaný) a potvrdenie orchestrátora na konci majú prednosť**, potom §6 požiadavky, §7 testy
   (T0–T11 + T2b, T6b, M1–M23), §11 uzáver. Surový audit [`../AUDIT_H16_raw.md`](../AUDIT_H16_raw.md); prototyp (`proto_h16`) a sondy `sonda_h16*.rb`
   autora package ostali v scratchpade orchestrátora mimo repa — pomôcka, nie autorita.
2. Package je z mainu `5e0ffb90` — **krok 0 (§5.1):** over presun `vepo_settings.json` do `core/export_settings.rb` (H7a — zapisovateľ, zámok, `.bak`), nové seed
   súbory H15 (`*_seed.rb` nie sú úložiská používateľa), číslo ďalšieho scenára v mape `docs/architecture/rozsirovacie-body.md` (H15b pridal scenár 6) a guard
   H13 (≥ 4 kontrolované riadky na scenár). Rozdiel meniaci zámer → STOP a otázka.
3. Q1 (rozmerové rady zdieľať?) a Q2 (18 + 36 rovnaké na oboch PC?) — **rozhodnuté Michalom 2.10.2026: každý PC svoje (4A, 5A)**, v registri `local`.

## Prenesenie do repa
- `PACKAGE_H16.md` + `AUDIT_H16_raw.md` → `SYSTEM/zdroje/bloky/HARDENING/`; tento brief → `briefy/BRIEF_H16.md` s úvodným riadkom „> Kópia zadania zo
  scratchpadu (2.10.2026); autorita = súbory v priečinku bloku." a relatívnymi odkazmi.

## Trieda, testy, uzáver
- Audit-povinná (nový modul `core/library_registry.rb`), **nie výrobná/cenová** (produkcia bajtovo rovnaká; R2 mení len testovací override koreňa) ·
  **predrecenzia povinná** · in-SU nie je brána, **1 beh odporúčaný** (R2 mení, kam píšu KOV-B1/KOV-I) — `scripts\run_su_tests.ps1 -CloseWhenDone` (worktree nemá
  `_dev\ENGINEtests.skp` — skopíruj z hlavného checkoutu; `exit 2` = počkaj; nikdy nezabíjaj SketchUp).
- `ruby tests/run_all.rb`, **každá JS sada zvlášť**, encoding guard; golden prvého behu (T0) v samostatnom procese podľa §15 A5, v 1. commite na starom kóde.
  Nikdy nezapisuj do živého `%APPDATA%\NOXUN\Engine\` — len sandbox/ENV override.
- Uzáver podľa CLAUDE.md: bump patch (VERSION 2×) + všetky `?v=` · nový súbor `docs/architecture/kniznice.md` + riadok v `docs/ARCHITEKTURA.md` (guard) · odsek
  modulu · STANDARD §13 veta · scenár mapy · STAV prepísať (max 80 riadkov / 12 kB, prepisuj, nepridávaj) · KRONIKA navrch · PLAN riadok H16 ✅ + `PR #?`.
- Commity selektívne, trailer `Co-Authored-By` so **skutočným modelom tvojej session**. Na CRLF súbory nepoužívaj `sed -i` (Edit alebo Python `newline=''`).
- **Po pushi STOP** — PR neotváraj; vráť report (hlava, riadky kódu bez testov/docs, testy, mutácie, in-SU, odchýlky). PR na pokyn orchestrátora po predrecenzii.
  **Nemerguj.** Nemeň CLAUDE.md.
