> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H3b · chyba v logu po otvorení nového súboru (A-06) — blok 9 HARDENING

Si implementátor dávky **H3b**. Pracuj z **čerstvého `origin/main`** (obsahuje H3a). Vetva **`fix/h3b-overlay-log`**.

## Zadanie (autorita)
- **Package:** `…\scratchpad\HARDENING\PACKAGE_H3.md` (`C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\0d0c7070-cda8-4433-abd5-db481a11fb59\scratchpad\HARDENING\`)
  — **len §6.6 A-06** + testy/in-SU/uzáver pre H3b; sekcia „Potvrdenie orchestrátora" na konci má prednosť.
- Problém: po `Sketchup.file_new` a otvorení Štúdia plugin zapíše do logu chybu kontroly smeru otvárania (`DirectionCheck.remove_overlay` → RuntimeError
  „invalid overlay"); package našiel rovnaký vzor aj v `EdgeCheck` a `GrainCheck`.
- **Krok 0 = sonda v SketchUpe** (príčinu package neoveril — MCP bridge bol nedostupný): jednorazový skript cez overenú slučku `-RubyStartup` nad kópiou
  `_dev\ENGINEtests.skp` (vzor `scripts\run_su_tests.ps1`; zámok `deploy.lock`, nikdy nezabíjať proces) — reprodukuj file_new → otvorenie Štúdia → log.
  Zapíš príčinu (súbor:riadok).
- **Hranica triedy:** oprava = **stráž v `remove_overlay`** (a rovnaké dve miesta v Edge/GrainCheck), ktorá nepadne na overlayi iného/zaniknutého modelu
  a **nezamlčí** chyby živého dokumentu. Ak by oprava musela zmeniť postup `disable!` alebo `on_model_changed` (lifecycle observera/overlayov) → **zastav
  a vráť orchestrátorovi** (audit-povinné).
- Povinné čítanie: `docs/SKETCHUP_PRAVIDLA.md` (overlaye, observery), odseky `DirectionCheck`/`EdgeCheck`/`GrainCheck` v `docs/architecture/` (Grep).

## Testy a DoD
- Headless test stráže (fake overlay/model, ak sa dá) + mutácie (min. 3).
- **In-SU je brána mergu** (overlay lifecycle): scenár v `tests/sketchup/su_runner.rb` — file_new (alebo ekvivalent v runneri) → otvorenie Štúdia/kontrol →
  v logu žiadna „invalid overlay" chyba; kresby kontrol na novom modeli fungujú. Runner **vždy `-CloseWhenDone`**, výsledkový grep až po dobehu; PR uvedie
  hlavu, na ktorej in-SU bežal. Max 2 pokusy o opravu pri zlyhaní, potom stop a report.
- Celá headless sada + každá JS sada zvlášť + encoding guard.

## Uzáver
- Checklist kódovej dávky: bump patch (2×) + `?v=` (ak sa menia UI súbory; inak len VERSION — guard `?v=` = VERSION aj tak vyžaduje prepísať všetky `?v=`),
  architektúra na mieste, STAV prepis, KRONIKA, PLAN riadok **H3b** ✅ + `PR #?`.
- Predrecenzia: **nie je povinná** (bežná dávka, < 300 riadkov, bez nového UI prvku, nie výrobná/cenová) — ak by sa ukázalo inak, STOP a report.
  Inak po pushi rovno PR (kvótová brána; exit 4 neblokuje) → commit s číslom PR → report. **Nemerguj.**
