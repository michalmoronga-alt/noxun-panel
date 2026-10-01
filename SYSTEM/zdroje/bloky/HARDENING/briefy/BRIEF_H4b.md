> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H4b · texty a vzhľad (D-06, D-07, D-08, D-09) — blok 9 HARDENING

Si implementátor dávky **H4b**. Pracuj z **čerstvého `origin/main`** (obsahuje H4a — spoločný formátovač `nxf*` v `studio.js`). Vetva **`feat/h4b-texty-vzhlad`**.

## Zadanie (autorita)
- **Package:** `C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\0d0c7070-cda8-4433-abd5-db481a11fb59\scratchpad\HARDENING\PACKAGE_H4.md` —
  **len časť H4b** (D-06 „Obnoviť zálohu" preč od „Obnoviť" + jednotné „Obnoviť", D-07 texty bez žargónu a VEĽKÝCH písmen, D-08 rozbaľovačky/hľadanie/stĺpce
  Kusovníka/ikony, D-09 ikona Nastavení rozpočtu). D-04/D-11 sú hotové v H4a (#437) — nerob.
- **Krok 0:** zlaď package s aktuálnym mainom (H3a a H4a zmenili texty a formátovanie v rovnakých sekciách; v repe je kópia
  `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H4.md` s poznámkou §5.1 z H4a). Ak by zladenie menilo zámer, dáta alebo čísla → zastav a vráť otázku.
- **Otázky Michala (zatiaľ bez odpovede) — platí predvolená vratná voľba, v PR a reporte ju označ:**
  - **Q1:** „vrátiť katalóg pred migráciou" (núdzová akcia) → **menu „⋯" v hlavičke Materiálov** (alternatíva O plugine).
  - **Q2:** ikona Nastavení rozpočtu → **posuvníky**; Pravidlá si nechajú ozubené koleso.
- Slovník náhrad textov z package (seed → „dodané s pluginom", ghost → „obrysy zón", legacy …); zdôraznenie tučným namiesto VEĽKÝCH písmen; verzia jednotne „v0.17.x".
- **D-08:** fotky auditu sú z Chrome, nie CEF — rozbaľovačky a výber nôh v Inspectore pred opravou over v SketchUpe, ak to package §9 predpisuje
  (fotky `scripts\ui_foto.ps1` sú Chrome; ak overenie v CEF nie je možné bez interaktívneho SketchUpu, oprav podľa CSS a uveď v PR „vzhľad v CEF neoverený").
- Povinné čítanie podľa `CLAUDE.md` (UI riadok po H1: UI_DIZAJN §1–§3 + odseky dotknutých sekcií/modulov, cache-bust).

## Testy a DoD
- Package §7 pre H4b: JS testy textov a ikon, guard na žargón v UI textoch (ak package predpisuje), test menu „⋯" (otvorenie, klávesnica, Escape, akcia
  ide cez existujúce potvrdenie), charakterizácia že payload/XLSX/CSV/VEPO sa nemenia, mutácie. Celá headless sada + **každá** JS sada zvlášť + encoding guard
  (pozor: escape sekvencie typu `\u00a0` vkladaj tak, aby v súbore ostali ako escape, nie ako neviditeľný znak). In-SU nie.
- **Fotky okien** `scripts\ui_foto.ps1 -Shoot` pred/po (Inspector aj Štúdio); cesty k 4–5 fotkám „po" do reportu.

## Uzáver
- Checklist kódovej dávky: bump patch (2×) + všetky `?v=` · architektúra na mieste · STAV prepis · KRONIKA · PLAN riadok **H4b** ✅ + `PR #?`.
- Nový ovládací prvok (menu „⋯") → **predrecenzia povinná: po pushi STOP**, PR neotváraj, vráť report (vetva, plný SHA, hranica, fotky).
- Michal spí — pri nejasnosti vratná voľba len ak nemení dáta ani čísla (označ), inak otázka. **Nemerguj.**
