# Brief — dávky H11b · H11a (blok 9 HARDENING) — SketchUp 2026 minimum a príprava na 2026.2

Orchestrátor ti povie, ktorú dávku robíš. Pracuj z **čerstvého `origin/main`**. Package (autorita):
`C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\0d0c7070-cda8-4433-abd5-db481a11fb59\scratchpad\HARDENING\PACKAGE_H11.md` —
**prednosť majú §16 (delta audit + potvrdenie orchestrátora) a §15**; surové audity `AUDIT_H11_raw.md`, `AUDIT_H11_delta_raw.md`, sondy `h11_probe/`,
prototyp `h11_proto/` v tom istom priečinku.

| Dávka | Vetva | Rozsah | Brány |
|---|---|---|---|
| **H11b** · minimum SketchUp 2026 (F-02) | `fix/h11b-minimum-2026` | kontrola minima v loaderi (`Sketchup.version_number`, fail-open pri chybe — §16 N6), jedna slovenská hláška pri staršom SketchUpe a nenačítanie (Q2 predvoľba, vratná), odstránenie mŕtvych poistiek **len s dôkazom**, inštalátor odmietne SketchUp < 2026 + `-ResolveOnly` bez vedľajších účinkov (§16 D4), `docs/SKETCHUP_PRAVIDLA.md` minimum 2026 | trieda podľa package (pravdepodobne bežná/loader — ak audit-povinná, predrecenzia); in-SU podľa package |
| **H11a** · príprava na 2026.2 (F-01) | `fix/h11a-priprava-2026-2` | len po mergi H11b a po odpovedi Michala na Q1 (alebo s predvoľbou označenou v PR); package §16 D1–D3, N5; sonda P1 je **brána** (pri FAIL obal načítania odložiť); F-01 v registri ostáva otvorené → nový riadok **H11c** v PLAN | audit-povinná, predrecenzia, in-SU + samostatný quit test |

## Spoločné pravidlá
- **Krok 0:** over čísla riadkov a API z package proti aktuálnemu mainu; rozdiel meniaci zámer/kontrakt → STOP a otázka.
- Skopíruj tento brief do `SYSTEM/zdroje/bloky/HARDENING/briefy/BRIEF_H11.md` (ak tam nie je) a package + oba surové audity do `SYSTEM/zdroje/bloky/HARDENING/`.
- Testy: celá headless sada + každá JS sada zvlášť + encoding guard; in-SU runner `scripts\run_su_tests.ps1 -CloseWhenDone` (nikdy nezabíjať SketchUp;
  `exit 2` = počkať a znova; worktree nemá `_dev\ENGINEtests.skp` — skopíruj z hlavného checkoutu `C:\APP DEV\RUBY\ENGINE\_dev\`). Nikdy nemeň živé Plugins
  mimo deploy runnera; test „chybný súbor" len v izolovanej kópii.
- Uzáver: checklist kódovej dávky (bump patch 2× + `?v=`, architektúra na mieste — odsek loadera/updatera v `ui-lifecycle.md`, STAV prepis — STAV má limit 80 riadkov,
  KRONIKA, PLAN riadok dávky ✅ + `PR #?`, AUDIT_REGISTER ak sa týka).
- Ak dávka spadá pod predrecenziu → po pushi STOP a report; inak PR sám (kvótová brána; exit 4 neblokuje), commit s číslom PR, report. **Nemerguj.**
- Michal môže byť nedostupný — pri nejasnosti vratná voľba len ak nemení dáta ani čísla (označ), inak otázka v reporte.
